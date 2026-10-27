extends TestCase
## Escenas de nivel, boss y minijuego jugadas de punta a punta.

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


func test_nivel_1_exito() -> void:
	await _open("w1_l1")
	var board: FrascoBoard = scene.board
	board.place(0, 0)  # 5
	board.place(1, 1)  # 3
	check_eq(board.code_label.text, "poder = 5\nbonus = 3\npoder + bonus", "código en vivo")
	var r: Dictionary = await scene.launch()
	check_eq(r["status"], "success", "5 + 3 = 8")
	check(GameState.is_completed("w1_l1"), "nivel completado")
	check_eq(GameState.xp, 50, "50 XP")
	check(_result() != null and _result().info["success"], "pantalla de resultado con éxito")
	check_eq(int(_result().info["xp"]), 50, "el resultado muestra el XP")


func test_quimera_y_reintento_inmediato() -> void:
	await _open("w1_l2")
	var board: FrascoBoard = scene.board
	board.place(0, 0)  # 'Hola '
	board.place(2, 1)  # 7
	var r: Dictionary = await scene.launch()
	check_eq(r["status"], "type_error", "texto + número")
	var res := _result()
	check(res != null, "aparece el resultado")
	if res:
		check_eq(res.info["creature"], "quimera_tipos", "criatura de TypeError")
		res._retry_now()
		await tree.process_frame
	check(_result() == null or _result().is_queued_for_deletion(), "el reintento cierra el resultado")
	check_eq(board.values(), {"saludo": "Hola ", "nombre": 7}, "el tablero queda como estaba")
	board.place(1, 1)  # 'Ada' reemplaza al 7, que vuelve a la bandeja
	check(board.chips[2].visible, "el 7 volvió a la bandeja")
	r = await scene.launch()
	check_eq(r["status"], "success", "segundo intento sin penalización")
	check_eq(GameState.xp, 50, "XP completo tras reintentar")


func test_fantasma_con_frasco_vacio() -> void:
	await _open("w1_l1")
	scene.board.place(0, 0)
	var r: Dictionary = await scene.launch()
	check_eq(r["status"], "name_error", "frasco vacío")
	check_eq(_result().info["creature"], "fantasma_sin_nombre", "aparece el fantasma")


func test_pistas_de_ada() -> void:
	await _open("w1_l3")
	check(scene._candle.texture == UI.tex("candle_books"), "vela apagada al empezar")
	scene.request_hint()
	check_eq(GameState.hints_for("w1_l3"), 1, "una pista usada")
	check(scene._candle.texture == UI.tex("candle_books_lit"), "la vela se enciende")
	scene.request_hint()
	scene.request_hint()
	scene.request_hint()
	check_eq(GameState.hints_for("w1_l3"), 3, "máximo 3 pistas")
	check(scene._hint_button.disabled, "no hay más pistas")
	check(scene._hint_label.text.contains("3 * 4"), "la tercera pista es la solución parcial")
	scene.queue_free()
	await _open("w1_l3")
	check_eq(scene._shown_hints, 3, "las pistas pagadas se vuelven a mostrar")
	check_eq(GameState.hints_for("w1_l3"), 3, "sin cobrar de nuevo")
	scene.board.place(0, 0)
	scene.board.place(1, 1)
	scene.board.set_operator("*")
	await scene.launch()
	check_eq(GameState.xp, 20, "50 - 3 pistas")


func test_drag_and_drop() -> void:
	await _open("w1_l1")
	var board: FrascoBoard = scene.board
	var chip: TokenChip = board.chips[1]
	var data: Dictionary = chip._get_drag_data(Vector2.ZERO)
	check(board.slots[0]._can_drop_data(Vector2.ZERO, data), "el frasco acepta la ficha")
	board.slots[0]._drop_data(Vector2.ZERO, data)
	check_eq(board.values(), {"poder": 3}, "la ficha cayó en poder")
	check(not chip.visible, "la ficha salió de la bandeja")
	var back: Dictionary = board.slots[0]._get_drag_data(Vector2.ZERO)
	check(board.tray._can_drop_data(Vector2.ZERO, back), "la bandeja acepta fichas de un frasco")
	board.tray._drop_data(Vector2.ZERO, back)
	check_eq(board.values(), {}, "la ficha volvió")
	check(chip.visible, "y se ve en la bandeja")
	check(not board.tray._can_drop_data(Vector2.ZERO, data), "la bandeja no acepta fichas que ya están ahí")


func _play_boss(world: int) -> void:
	var ids := ContentDB.house_ids(world)
	for id: String in ids:
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
		var sol: Dictionary = FrascoLogic.solutions(rounds[i])[0]
		var board: FrascoBoard = scene.board
		var used: Array[int] = []
		var names := FrascoLogic.jar_names(rounds[i])
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


func test_boss_tres_rondas() -> void:
	await _play_boss(1)


func test_boss_guardian() -> void:
	await _play_boss(2)
	check_eq(_result().info["message"], ContentDB.get_content("w2_boss")["victory"], "mensaje de victoria del JSON")


func test_encrucijada_en_escena() -> void:
	GameState.completed.assign(["w1_boss", "w2_l1", "w2_l2", "w2_l3"])
	await _open("w2_l4")
	var board: FrascoBoard = scene.board
	check(board.crossroads != null, "se ve la encrucijada en vez del caldero")
	check_eq(board.crossroads.rows.size(), 3, "tres caminos")
	board.place(0, 0)  # 7 -> puente
	var r: Dictionary = await scene.launch()
	check_eq(r["status"], "wrong", "7 lleva al puente")
	check_eq(_result().info["creature"], "guardian_puerta", "aparece el Guardián")
	check_eq(board.crossroads._chosen, 0, "se ilumina el puente")
	_result()._retry_now()
	await tree.process_frame
	board.place(1, 0)  # 4 -> cueva
	r = await scene.launch()
	check_eq(r["status"], "success", "4 lleva a la cueva")
	check(GameState.is_completed("w2_l4"), "nivel completado")


func test_bola_de_cristal() -> void:
	GameState.completed.assign(["w1_boss", "w2_l1", "w2_l2", "w2_l3", "w2_l4", "w2_l5"])
	await _open("w2_mini", "res://scenes/level/crystal_ball.tscn")
	var r: Dictionary = await scene.choose("débil")
	check_eq(r["status"], "wrong", "predicción equivocada")
	_result()._retry_now()
	await tree.process_frame
	var rounds: Array = scene.content["rounds"]
	for i in rounds.size():
		check_eq(scene.option_buttons.size(), (rounds[i]["options"] as Array).size(), "botones de la ronda %d" % (i + 1))
		r = await scene.choose(MinigameLogic.prediction_answer(rounds[i]))
		check_eq(r["status"], "success", "ronda %d" % (i + 1))
	check(GameState.is_completed("w2_mini"), "minijuego completado")
	check_eq(GameState.house_state("w2_boss"), "open", "se abre el Guardián")


func test_minijuego() -> void:
	GameState.completed.assign(["w1_l1", "w1_l2", "w1_l3", "w1_l4", "w1_l5"])
	await _open("w1_mini", "res://scenes/level/minigame.tscn")
	# Primer intento con un error de sintaxis: '5' a la izquierda del =.
	scene.set_choice(0, "5")
	var r: Dictionary = await scene.launch()
	check_eq(r["status"], "syntax_error", "5 = 5 es SyntaxError")
	check_eq(_result().info["creature"], "gremlin_sintaxis", "aparece el Gremlin")
	_result()._retry_now()
	await tree.process_frame
	var rounds: Array = scene.content["rounds"]
	for i in rounds.size():
		var blanks: Array = rounds[i]["blanks"]
		for b in blanks.size():
			scene.set_choice(b, blanks[b])
		check_eq(scene.blanks[0].get_text(), str(blanks[0]), "el hueco muestra la ficha")
		r = await scene.launch()
		check_eq(r["status"], "success", "ronda %d" % (i + 1))
	check(GameState.is_completed("w1_mini"), "minijuego completado")
	check_eq(GameState.xp, 100, "100 XP del minijuego")
	check_eq(GameState.house_state("w1_boss"), "open", "se abre el boss")


func test_minijuego_errores() -> void:
	var rounds: Array = ContentDB.get_content("w1_mini")["rounds"]
	check_eq(MinigameLogic.check(rounds[1], ["Ada"])["status"], "name_error", "Ada sin comillas")
	check_eq(MinigameLogic.check(rounds[2], ["+"])["status"], "wrong", "4 + 3 no es 12")
	check_eq(MinigameLogic.check(rounds[2], ["+"])["message"], "Tu hechizo imprimió 7, pero tenía que imprimir 12.", "mensaje")
	check_eq(MinigameLogic.check(rounds[0], [""])["status"], "incomplete", "hueco vacío")
