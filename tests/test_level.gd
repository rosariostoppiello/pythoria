extends TestCase
## Escenas de nivel, boss y minijuegos jugadas de punta a punta.

var scene: Node


func before_each() -> void:
	SaveSystem.save_path = "user://test_save.json"
	GameState.reset()


func after_each() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
	tree.current_scene = null
	SaveSystem.delete_save()
	SaveSystem.save_path = SaveSystem.DEFAULT_PATH
	GameState.load_from_save()


func _open(house: String, path: String = "res://scenes/level/level.tscn") -> Node:
	SceneManager.house_id = house
	SceneManager.world_id = ContentDB.world_of(house)
	scene = load(path).instantiate()
	tree.root.add_child(scene)
	tree.current_scene = scene
	await tree.process_frame
	return scene


func _result() -> Node:
	return scene.get_node_or_null("ResultOverlay")


func _retry() -> void:
	_result()._retry_now()
	await tree.process_frame


func _solution(p: Dictionary) -> String:
	return "\n".join(PackedStringArray(p["solution"]))


func test_frasco_exito() -> void:
	await _open("w1_l1")
	var board: FrascoBoard = scene.board
	board.place(0, 0)  # a = 2
	board.place(1, 1)  # b = 3
	board.place(2, 2)  # c = 4
	check_eq(board.code_label.text, "a = 2\nb = 3\nc = 4\na + b * c", "código en vivo")
	var r: Dictionary = await scene.launch()
	check_eq(r["status"], "success", "2 + 3 * 4 = 14")
	check(GameState.is_completed("w1_l1"), "nivel completado")
	check_eq(GameState.xp, 50, "50 XP")
	check(_result() != null and _result().info["success"], "pantalla de resultado con éxito")


func test_quimera_y_reintento_inmediato() -> void:
	await _open("w1_l1")
	var board: FrascoBoard = scene.board
	board.place(0, 0)  # 2
	board.place(1, 1)  # 3
	board.place(4, 2)  # '4'
	var r: Dictionary = await scene.launch()
	check_eq(r["status"], "type_error", "3 * '4' + 2")
	check_eq(_result().info["creature"], "quimera_tipos", "criatura de TypeError")
	await _retry()
	check_eq(board.values(), {"a": 2, "b": 3, "c": "4"}, "el tablero queda como estaba")
	board.place(2, 2)  # el 4 reemplaza al '4', que vuelve a la bandeja
	check(board.chips[4].visible, "el '4' volvió a la bandeja")
	r = await scene.launch()
	check_eq(r["status"], "success", "segundo intento sin penalización")
	check_eq(GameState.xp, 50, "XP completo tras reintentar")


func test_fantasma_con_frasco_vacio() -> void:
	await _open("w1_l1")
	scene.board.place(0, 0)
	var r: Dictionary = await scene.launch()
	check_eq(r["status"], "name_error", "frascos vacíos")
	check_eq(_result().info["creature"], "fantasma_sin_nombre", "aparece el fantasma")


func test_division_da_float() -> void:
	await _open("w1_l2")
	var board: FrascoBoard = scene.board
	board.place(2, 0)  # 6
	board.place(3, 1)  # 2
	board.set_operator("/")
	var r: Dictionary = await scene.launch()
	check(str(r["message"]).contains("mismo valor, distinto tipo"), "6 / 2 es 3.0")
	await _retry()
	board.set_operator("//")
	r = await scene.launch()
	check_eq(r["status"], "success", "6 // 2")


func test_escribir_codigo() -> void:
	await _open("w1_l4")
	check(scene.board is CodeBoard, "el nivel 4 es de escribir código")
	check(scene._try.visible, "se ve el botón Probar")
	var board: CodeBoard = scene.board
	check(board.editor.text.contains("total = int(input())"), "arranca con el código inicial")
	var r: Dictionary = await scene.launch()
	check_eq(r["creature"], "fantasma_sin_nombre", "el código inicial usa variables sin definir")
	await _retry()
	var p := ContentDB.get_content("w1_l4")
	board.editor.text = _solution(p)
	var sample: Dictionary = board.run_sample()
	check(sample["ok"], "Probar corre el caso 1")
	check_eq(board.console.text, "1h 2m 5s", "la consola muestra la salida")
	r = await scene.launch()
	check_eq(r["status"], "success", "pasa todos los casos")
	check(board.case_rows[0].text.begins_with("✓"), "el caso 1 queda marcado")
	check_eq(GameState.xp, 80, "los niveles de código valen 80 XP")


func test_codigo_que_falla_un_caso() -> void:
	await _open("w2_l4")
	var board: CodeBoard = scene.board
	# Orden equivocado de los elif: nota 9 cae en "Aprobado".
	board.editor.text = "nota = int(input())\nif nota >= 6:\n    print('Aprobado')\nelif nota >= 8:\n    print('Promoción')\nelif nota >= 4:\n    print('Examen')\nelse:\n    print('Recursa')"
	var r: Dictionary = await scene.launch()
	check_eq(r["status"], "wrong", "el orden de los elif importa")
	check_eq(r["failed_case"], 0, "falla el caso 1 (nota 9)")
	check(board.case_rows[0].text.begins_with("x"), "el caso 1 se marca con x")
	check(board.console.text.contains("Aprobado"), "la consola muestra lo que imprimió")
	board.clear()
	check_eq(board.editor.text, CodeLogic.starter(ContentDB.get_content("w2_l4")), "Restaurar vuelve al código inicial")


func test_pistas_de_ada() -> void:
	await _open("w1_l3")
	check(scene._candle.texture == UI.tex("candle_books"), "vela apagada al empezar")
	scene.request_hint()
	check_eq(GameState.hints_for("w1_l3"), 1, "una pista usada")
	check(scene._candle.texture == UI.tex("candle_books_lit"), "la vela se enciende")
	check(scene._reward_label.text.contains("70"), "la recompensa baja a 70")
	scene.request_hint()
	scene.request_hint()
	scene.request_hint()
	check_eq(GameState.hints_for("w1_l3"), 3, "máximo 3 pistas")
	check(scene._hint_button.disabled, "no hay más pistas")
	check(scene._hint_label.text.contains("Pista 3 de 3"), "se ve la última pista")
	scene._on_bubble_input(_click())
	check(scene._hint_label.text.contains("Pista 1 de 3"), "tocando el globo se repasa la primera")
	scene.queue_free()
	await _open("w1_l3")
	check_eq(scene._shown_hints, 3, "las pistas pagadas se vuelven a mostrar")
	check_eq(GameState.hints_for("w1_l3"), 3, "sin cobrar de nuevo")
	scene.board.editor.text = _solution(ContentDB.get_content("w1_l3"))
	await scene.launch()
	check_eq(GameState.xp, 50, "80 - 3 pistas")


func _click() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e


func test_drag_and_drop() -> void:
	await _open("w1_l2")
	var board: FrascoBoard = scene.board
	var chip: TokenChip = board.chips[1]
	var data: Dictionary = chip._get_drag_data(Vector2.ZERO)
	check(board.slots[0]._can_drop_data(Vector2.ZERO, data), "el frasco acepta la ficha")
	board.slots[0]._drop_data(Vector2.ZERO, data)
	check_eq(board.values(), {"total": 5}, "la ficha cayó en total")
	check(not chip.visible, "la ficha salió de la bandeja")
	var back: Dictionary = board.slots[0]._get_drag_data(Vector2.ZERO)
	check(board.tray._can_drop_data(Vector2.ZERO, back), "la bandeja acepta fichas de un frasco")
	board.tray._drop_data(Vector2.ZERO, back)
	check_eq(board.values(), {}, "la ficha volvió")
	check(chip.visible, "y se ve en la bandeja")
	check(not board.tray._can_drop_data(Vector2.ZERO, data), "la bandeja no acepta fichas que ya están ahí")


func _play_boss(world: int) -> void:
	for id: String in ContentDB.house_ids(world):
		if not id.ends_with("_boss"):
			GameState.completed.append(id)
	if world > 1:
		GameState.completed.append("w%d_boss" % (world - 1))
	var xp_before := GameState.xp
	await _open("w%d_boss" % world)
	check(scene.is_boss, "modo boss")
	var rounds: Array = scene.content["rounds"]
	for i in rounds.size():
		check_eq(scene.round_idx, i, "ronda %d" % (i + 1))
		var p: Dictionary = rounds[i]
		if CodeLogic.is_code(p):
			scene.board.editor.text = _solution(p)
		else:
			var sol: Dictionary = FrascoLogic.solutions(p)[0]
			var board: FrascoBoard = scene.board
			var used: Array[int] = []
			var names := FrascoLogic.jar_names(p)
			for j in names.size():
				for t in board.tokens.size():
					if t in used:
						continue
					if PyEval.repr(FrascoLogic.token_value(board.tokens[t])) == PyEval.repr(sol["values"][names[j]]):
						board.place(t, j)
						used.append(t)
						break
			if sol["op"] != "":
				board.set_operator(sol["op"])
		var r: Dictionary = await scene.launch()
		check_eq(r["status"], "success", "mundo %d, ronda %d resuelta" % [world, i + 1])
		await tree.process_frame
	check_eq(scene._health.value, 0.0, "el boss se quedó sin vida")
	check(GameState.is_completed("w%d_boss" % world), "boss completado")
	check_eq(GameState.xp - xp_before, 200, "200 XP del boss")
	check(_result() != null and _result().info.get("is_boss", false), "resultado de boss (vuelve al mapa de mundos)")
	check(GameState.is_world_unlocked(world + 1), "se abre el mundo siguiente")


func test_boss_gremlin() -> void:
	await _play_boss(1)


func test_boss_guardian() -> void:
	await _play_boss(2)
	check_eq(_result().info["message"], ContentDB.get_content("w2_boss")["victory"], "mensaje de victoria del JSON")


func test_boss_ronda_de_codigo_falla() -> void:
	GameState.completed.assign(["w1_l1", "w1_l2", "w1_l3", "w1_l4", "w1_l5", "w1_mini"])
	await _open("w1_boss")
	scene.round_idx = 1
	scene._load_board()
	await tree.process_frame
	check(scene.board is CodeBoard, "la ronda 2 del Gremlin es de código")
	var r: Dictionary = await scene.launch()
	check_eq(r["creature"], "quimera_tipos", "el código roto del Gremlin suma texto y número")
	check_eq(scene._health.value, 3.0, "un fallo no baja la vida")


func test_encrucijada_en_escena() -> void:
	GameState.completed.assign(["w1_boss", "w2_l1", "w2_l2"])
	await _open("w2_l3")
	var board: FrascoBoard = scene.board
	check(board.crossroads != null, "se ve la encrucijada en vez del caldero")
	check_eq(board.crossroads.rows.size(), 3, "tres caminos")
	board.place(0, 0)  # nota 8
	board.place(3, 1)  # asistencia 80
	var r: Dictionary = await scene.launch()
	check_eq(r["path"], "aprobado", "8 y 80 aprueba directo")
	check_eq(_result().info["creature"], "guardian_puerta", "aparece el Guardián")
	check_eq(board.crossroads._chosen, 0, "se ilumina el primer camino")
	await _retry()
	board.place(1, 0)  # nota 5
	r = await scene.launch()
	check_eq(r["status"], "success", "5 y 80 va al examen final")


func test_minijuego_completa() -> void:
	GameState.completed.assign(["w1_l1", "w1_l2", "w1_l3", "w1_l4", "w1_l5"])
	await _open("w1_mini", "res://scenes/level/minigame.tscn")
	check(scene._expected_label.text.contains("Entrada para input(): 21"), "muestra la entrada")
	scene.set_choice(0, "str")
	var r: Dictionary = await scene.launch()
	check_eq(r["status"], "wrong", "str(input()) * 2 repite el texto")
	check(str(r["message"]).contains("2121"), "muestra lo que imprimió")
	await _retry()
	var rounds: Array = scene.content["rounds"]
	for i in rounds.size():
		var blanks: Array = rounds[i]["blanks"]
		for b in blanks.size():
			scene.set_choice(b, blanks[b])
		r = await scene.launch()
		check_eq(r["status"], "success", "ronda %d" % (i + 1))
	check(GameState.is_completed("w1_mini"), "minijuego completado")
	check_eq(GameState.xp, 100, "100 XP del minijuego")
	check_eq(GameState.house_state("w1_boss"), "open", "se abre el boss")


func test_bola_de_cristal() -> void:
	GameState.completed.assign(["w1_boss", "w2_l1", "w2_l2", "w2_l3", "w2_l4", "w2_l5"])
	await _open("w2_mini", "res://scenes/level/crystal_ball.tscn")
	var r: Dictionary = await scene.choose("NameError")
	check_eq(r["status"], "wrong", "y nunca se evalúa")
	await _retry()
	var rounds: Array = scene.content["rounds"]
	for i in rounds.size():
		check_eq(scene.option_buttons.size(), (rounds[i]["options"] as Array).size(), "botones de la ronda %d" % (i + 1))
		r = await scene.choose(MinigameLogic.prediction_answer(rounds[i]))
		check_eq(r["status"], "success", "ronda %d" % (i + 1))
	check(GameState.is_completed("w2_mini"), "minijuego completado")
	check_eq(GameState.house_state("w2_boss"), "open", "se abre el Guardián")


## Ningún nivel ni ronda de boss puede empujar el botón Lanzar fuera de la pantalla.
func test_lanzar_siempre_visible() -> void:
	for world in [1, 2]:
		for id: String in ContentDB.house_ids(world):
			var content := ContentDB.get_content(id)
			if content.has("kind"):
				continue  # minijuegos: otra escena
			await _open(id)
			var rounds: int = (content["rounds"] as Array).size() if scene.is_boss else 1
			for i in rounds:
				if scene.is_boss:
					scene.round_idx = i
					scene._load_board()
				# Peor caso: todos los frascos llenos (el código en vivo es más largo).
				if scene.board is FrascoBoard:
					var b: FrascoBoard = scene.board
					for j in b.jar_token.size():
						b.place(j, j)
				for f in 3:
					await tree.process_frame
				var bottom: float = scene._launch.get_global_rect().end.y
				check(bottom <= 720.0, "%s ronda %d: Lanzar queda en y=%.0f, fuera de la pantalla" % [id, i + 1, bottom])
			scene.queue_free()
			await tree.process_frame
