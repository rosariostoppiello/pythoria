extends TestCase
## worlds.json: estructura válida y todos los niveles resolubles con sus soluciones.


func _frasco_puzzles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in ContentDB.worlds():
		for lvl: Dictionary in w.get("levels", []):
			out.append(lvl)
		for r: Dictionary in w.get("boss_fight", {}).get("rounds", []):
			out.append(r)
	return out


func test_json_carga() -> void:
	check(ContentDB.load_error == "", "error al cargar: " + ContentDB.load_error)
	check_eq(ContentDB.world_count(), 8, "8 mundos")
	check_eq(ContentDB.world_map_nodes().size(), 8, "8 nodos en el mapa")
	var w1 := ContentDB.get_world(1)
	check_eq((w1["levels"] as Array).size(), 5, "mundo 1 tiene 5 niveles")
	check(w1.has("minigame") and w1.has("boss_fight"), "mundo 1 tiene minijuego y boss")


func test_ids_de_casitas_tienen_contenido() -> void:
	for id: String in ContentDB.house_ids(1):
		check(not ContentDB.get_content(id).is_empty(), "%s no tiene contenido" % id)
	for id: String in ContentDB.house_ids(2):
		check(not ContentDB.get_content(id).is_empty(), "%s no tiene contenido" % id)
	check(ContentDB.get_content("w3_l1").is_empty(), "w3_l1 es placeholder")


func test_niveles_bien_formados() -> void:
	for p: Dictionary in _frasco_puzzles():
		var name := str(p.get("id", "ronda"))
		check(p.has("goal") and p.has("jars") and p.has("tokens"), "%s: faltan campos" % name)
		check(not FrascoLogic.solutions(p).is_empty(), "%s: no tiene solution ni solution_any" % name)
		for j: Dictionary in p.get("jars", []):
			check(FrascoLogic.expression(p).contains(str(j["name"])), "%s: la expresión no usa el frasco %s" % [name, j["name"]])
		if p.has("hints"):
			check_eq((p["hints"] as Array).size(), 3, "%s: 3 pistas" % name)


func test_niveles_resolubles() -> void:
	var count := 0
	for p: Dictionary in _frasco_puzzles():
		var name := str(p.get("id", "ronda de boss"))
		for s: Dictionary in FrascoLogic.solutions(p):
			count += 1
			check(FrascoLogic.tokens_cover(p, s["values"]), "%s: las fichas no alcanzan para %s" % [name, s])
			if FrascoLogic.needs_operator_choice(p):
				check(FrascoLogic.operators(p).has(s["op"]), "%s: el operador %s no está disponible" % [name, s["op"]])
			var r := FrascoLogic.check(p, s["values"], s["op"])
			check_eq(r["status"], "success", "%s con %s" % [name, s])
	check(count >= 12, "se probaron todas las soluciones (%d)" % count)


func test_resultado_correcto_aunque_no_sea_la_solucion_listada() -> void:
	# w1_l1: 9 + ... no; pero en w1_l3 8 + 4 sirve aunque no se liste 4 * 3 en ese orden.
	var l3 := ContentDB.get_content("w1_l3")
	check_eq(FrascoLogic.check(l3, {"a": 4, "b": 3}, "*")["status"], "success", "4 * 3")
	check_eq(FrascoLogic.check(l3, {"a": 2, "b": 8}, "+")["status"], "wrong", "2 + 8 = 10")


func test_errores_del_frasco() -> void:
	var l1 := ContentDB.get_content("w1_l1")
	var r := FrascoLogic.check(l1, {"poder": 5}, "+")
	check_eq(r["status"], "name_error", "frasco vacío")
	check_eq(r["creature"], "fantasma_sin_nombre", "aparece el fantasma")
	r = FrascoLogic.check(l1, {"poder": 5, "bonus": 9}, "+")
	check_eq(r["status"], "wrong", "resultado distinto")
	check_eq(r["message"], "Obtuviste 14, pero el caldero pedía 8.", "mensaje de resultado distinto")
	var l2 := ContentDB.get_content("w1_l2")
	r = FrascoLogic.check(l2, {"saludo": "Hola ", "nombre": 7}, "+")
	check_eq(r["status"], "type_error", "texto + número")
	check_eq(r["creature"], "quimera_tipos", "aparece la quimera")
	check_eq(r["detail"], "TypeError: no se puede sumar str y int", "detalle del TypeError")
	var l4 := ContentDB.get_content("w1_l4")
	r = FrascoLogic.check(l4, {"izquierda": 7, "derecha": 7}, "+")
	check_eq(r["message"], "Obtuviste 14, pero el caldero pedía True.", "int en vez de bool")
	r = FrascoLogic.check(l4, {"izquierda": 7, "derecha": 7}, "")
	check_eq(r["status"], "syntax_error", "sin operador elegido")


func test_codigo_en_vivo() -> void:
	var l1 := ContentDB.get_content("w1_l1")
	var lines := FrascoLogic.code_lines(l1, {"poder": 5}, "+")
	check_eq(Array(lines), ["poder = 5", "# bonus está vacío", "poder + bonus"], "código parcial")
	var l5 := ContentDB.get_content("w1_l5")
	lines = FrascoLogic.code_lines(l5, {"nombre": "Ada"}, "")
	check_eq(Array(lines), ["nombre = 'Ada'", "f\"Bienvenido, {nombre}\""], "código con f-string")
	var boss_round: Dictionary = ContentDB.get_content("w1_boss")["rounds"][0]
	check_eq(FrascoLogic.expression(boss_round), "x OP y", "expresión por defecto en el boss")


func test_minijuego_resoluble() -> void:
	var mini := ContentDB.get_content("w1_mini")
	check_eq((mini["rounds"] as Array).size(), 3, "3 rondas")
	for r: Dictionary in mini["rounds"]:
		var blanks: Array = r["blanks"]
		for b: String in blanks:
			check((r["tokens"] as Array).has(b), "la ficha %s está disponible" % b)
		var res := PyEval.run(MinigameLogic.fill(r["code"], blanks))
		check(res["ok"], "ronda %s: %s" % [r["code"], res["message"]])
		check_eq(res["output"], str(r["output"]), "salida de la ronda %s" % [r["code"]])


func test_encrucijada() -> void:
	var l4 := ContentDB.get_content("w2_l4")
	check(FrascoLogic.is_crossroads(l4), "w2_l4 es una encrucijada")
	var cases := {7: ["wrong", "puente"], 4: ["success", "cueva"], 1: ["wrong", "río"]}
	for p: int in cases:
		var r := FrascoLogic.check(l4, {"poder": p}, "")
		check_eq(r["status"], cases[p][0], "estado con poder=%d" % p)
		check_eq(r["path"], cases[p][1], "camino con poder=%d" % p)
	check_eq(FrascoLogic.check(l4, {"poder": 7}, "")["message"], "El Guardián te mandó a puente, pero tenías que llegar a cueva.", "mensaje de camino equivocado")
	check_eq(FrascoLogic.check(l4, {}, "")["status"], "name_error", "frasco vacío en la encrucijada")
	check_eq(FrascoLogic.check(l4, {"poder": "7"}, "")["status"], "type_error", "texto comparado con número")
	var lines := FrascoLogic.code_lines(l4, {"poder": 4}, "")
	check_eq(Array(lines), ["poder = 4", "if poder > 5:", "    camino = 'puente'", "elif poder > 2:", "    camino = 'cueva'", "else:", "    camino = 'río'"], "código de la encrucijada")
	var l5 := ContentDB.get_content("w2_l5")
	check_eq(FrascoLogic.check(l5, {"edad": 15, "tiene_mapa": true}, "")["path"], "bosque profundo", "con mapa va al bosque")
	check_eq(FrascoLogic.check(l5, {"edad": 9, "tiene_mapa": true}, "")["path"], "casa", "chico va a casa")


func test_bola_de_cristal_resoluble() -> void:
	var mini := ContentDB.get_content("w2_mini")
	check_eq(mini["kind"], "bola_de_cristal", "tipo de minijuego")
	for r: Dictionary in mini["rounds"]:
		var answer := MinigameLogic.prediction_answer(r)
		var matches := 0
		for opt: Variant in r["options"]:
			if str(opt) == answer:
				matches += 1
		check_eq(matches, 1, "exactamente una opción correcta en %s (imprime %s)" % [r["code"], answer])
		check_eq(MinigameLogic.check_prediction(r, answer)["status"], "success", "la respuesta correcta gana")
	var r0: Dictionary = mini["rounds"][0]
	check_eq(MinigameLogic.check_prediction(r0, "débil")["status"], "wrong", "predicción equivocada")
