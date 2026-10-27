extends TestCase
## worlds.json: estructura válida, todo resoluble, y las reglas de cada mecánica.

## Puzzle fijo para probar la mecánica sin depender del contenido.
const FRASCO := {
	"goal": {"value": 8, "type": "int"},
	"jars": [{"name": "poder", "accepts": "int"}, {"name": "bonus", "accepts": "int"}],
	"tokens": [{"value": 5, "type": "int"}, {"value": 3, "type": "int"}, {"value": 9, "type": "int"}, {"value": "7", "type": "str"}],
	"operators": ["+", "-"],
	"expression": "poder OP bonus",
}
const CRUCE := {
	"mechanic": "encrucijada",
	"goal": {"value": "cueva", "type": "str"},
	"variable": "camino",
	"jars": [{"name": "poder", "accepts": "int"}],
	"tokens": [{"value": 7, "type": "int"}, {"value": 4, "type": "int"}, {"value": 1, "type": "int"}],
	"operators": [],
	"branches": [{"cond": "poder > 5", "path": "puente"}, {"cond": "poder > 2", "path": "cueva"}, {"path": "río"}],
}


## Niveles y rondas de boss de todos los mundos.
func _puzzles() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for w: Dictionary in ContentDB.worlds():
		for lvl: Dictionary in w.get("levels", []):
			out.append(lvl)
		for r: Dictionary in w.get("boss_fight", {}).get("rounds", []):
			out.append(r)
	return out


func _name(p: Dictionary) -> String:
	return str(p.get("id", "ronda de boss: " + str(p.get("task", p.get("expression", "")))).left(60))


func test_json_carga() -> void:
	check(ContentDB.load_error == "", "error al cargar: " + ContentDB.load_error)
	check_eq(ContentDB.world_count(), 8, "8 mundos")
	check_eq(ContentDB.world_map_nodes().size(), 8, "8 nodos en el mapa")
	for id in [1, 2]:
		var w := ContentDB.get_world(id)
		check_eq((w["levels"] as Array).size(), 5, "mundo %d tiene 5 niveles" % id)
		check(w.has("minigame") and w.has("boss_fight"), "mundo %d tiene minijuego y boss" % id)


func test_ids_de_casitas_tienen_contenido() -> void:
	for world in [1, 2]:
		for id: String in ContentDB.house_ids(world):
			check(not ContentDB.get_content(id).is_empty(), "%s no tiene contenido" % id)
	check(ContentDB.get_content("w3_l1").is_empty(), "w3_l1 es placeholder")


func test_niveles_bien_formados() -> void:
	for p: Dictionary in _puzzles():
		var name := _name(p)
		if p.has("hints"):
			check_eq((p["hints"] as Array).size(), 3, "%s: 3 pistas" % name)
		if CodeLogic.is_code(p):
			check(str(p.get("task", "")) != "", "%s: falta la consigna" % name)
			check(p.has("starter") and p.has("solution"), "%s: falta starter o solution" % name)
			check(CodeLogic.tests(p).size() >= 2, "%s: al menos 2 casos de prueba" % name)
			continue
		check(p.has("goal") and p.has("jars") and p.has("tokens"), "%s: faltan campos" % name)
		check(not FrascoLogic.solutions(p).is_empty(), "%s: no tiene solution ni solution_any" % name)
		for j: Dictionary in p.get("jars", []):
			check(FrascoLogic.expression(p).contains(str(j["name"])), "%s: la expresión no usa el frasco %s" % [name, j["name"]])


func test_frascos_y_cruces_resolubles() -> void:
	var count := 0
	for p: Dictionary in _puzzles():
		if CodeLogic.is_code(p):
			continue
		var name := _name(p)
		for s: Dictionary in FrascoLogic.solutions(p):
			count += 1
			check(FrascoLogic.tokens_cover(p, s["values"]), "%s: las fichas no alcanzan para %s" % [name, s])
			if FrascoLogic.needs_operator_choice(p):
				check(FrascoLogic.operators(p).has(s["op"]), "%s: el operador %s no está disponible" % [name, s["op"]])
			check_eq(FrascoLogic.check(p, s["values"], s["op"])["status"], "success", "%s con %s" % [name, s])
	check(count >= 14, "se probaron las soluciones (%d)" % count)


func test_programas_resolubles() -> void:
	var count := 0
	for p: Dictionary in _puzzles():
		if not CodeLogic.is_code(p):
			continue
		count += 1
		var name := _name(p)
		var solution := "\n".join(PackedStringArray(p["solution"]))
		var r := CodeLogic.check(p, solution)
		check_eq(r["status"], "success", "%s: la solución pasa (%s)" % [name, r["message"]])
		var starter := CodeLogic.check(p, CodeLogic.starter(p))
		check(starter["status"] != "success", "%s: el código inicial no debería pasar solo" % name)
	check(count >= 9, "hay ejercicios de escribir código (%d)" % count)


## Regla de diseño: en cada mundo jugable, alrededor de la mitad de los desafíos es escribir código.
func test_mitad_escribir_codigo() -> void:
	for id in [1, 2]:
		var w := ContentDB.get_world(id)
		var total := 0
		var code := 0
		for p: Dictionary in (w["levels"] as Array) + (w["boss_fight"]["rounds"] as Array):
			total += 1
			if CodeLogic.is_code(p):
				code += 1
		total += 1  # el minijuego
		check(code * 2 >= total - 1, "mundo %d: %d de %d desafíos son de escribir código" % [id, code, total])


func test_frasco_errores() -> void:
	var r := FrascoLogic.check(FRASCO, {"poder": 5}, "+")
	check_eq(r["status"], "name_error", "frasco vacío")
	check_eq(r["creature"], "fantasma_sin_nombre", "aparece el fantasma")
	r = FrascoLogic.check(FRASCO, {"poder": 5, "bonus": 9}, "+")
	check_eq(r["message"], "Obtuviste 14, pero el caldero pedía 8.", "resultado distinto")
	r = FrascoLogic.check(FRASCO, {"poder": 5, "bonus": "7"}, "+")
	check_eq(r["status"], "type_error", "número + texto")
	check_eq(r["detail"], "TypeError: no se puede sumar int y str", "detalle del TypeError")
	check_eq(FrascoLogic.check(FRASCO, {"poder": 5, "bonus": 3}, "")["status"], "syntax_error", "sin operador elegido")
	check_eq(FrascoLogic.check(FRASCO, {"poder": 5, "bonus": 3}, "+")["status"], "success", "5 + 3")


func test_mismo_valor_distinto_tipo() -> void:
	var l2 := ContentDB.get_content("w1_l2")
	var r := FrascoLogic.check(l2, {"total": 6, "partes": 2}, "/")
	check_eq(r["status"], "wrong", "6 / 2 da float")
	check_eq(r["message"], "Obtuviste 3.0 (float), pero el caldero pedía 3 (int): mismo valor, distinto tipo.", "mensaje de tipo")
	check_eq(FrascoLogic.check(l2, {"total": 6, "partes": 2}, "//")["status"], "success", "6 // 2")


func test_trampas_del_contenido() -> void:
	var l1 := ContentDB.get_content("w1_l1")
	check_eq(FrascoLogic.check(l1, {"a": 2, "b": 3, "c": "4"}, "")["status"], "type_error", "w1_l1: 3 * '4' + 2")
	check_eq(FrascoLogic.check(l1, {"a": 4, "b": 5, "c": 2}, "")["status"], "success", "w1_l1: otra solución válida")
	var boss: Dictionary = ContentDB.get_content("w1_boss")["rounds"][0]
	check_eq(FrascoLogic.check(boss, {"a": 1, "b": 3, "c": "5"}, "")["message"], "Obtuviste '5555', pero el caldero pedía 20.", "texto por número repite")
	var w2l1 := ContentDB.get_content("w2_l1")
	check_eq(FrascoLogic.check(w2l1, {"x": "4"}, "")["status"], "type_error", "w2_l1: comparar texto con número")
	check_eq(FrascoLogic.check(w2l1, {"x": 10}, "")["status"], "wrong", "w2_l1: 10 queda afuera")
	var w2l2 := ContentDB.get_content("w2_l2")
	check_eq(FrascoLogic.check(w2l2, {"a": 5, "b": "Ada"}, "or")["message"], "Obtuviste 5, pero el caldero pedía 'Ada'.", "5 or 'Ada' devuelve 5")
	check_eq(FrascoLogic.check(w2l2, {"a": 0, "b": "Ada"}, "and")["status"], "wrong", "0 and 'Ada' devuelve 0")


func test_codigo_en_vivo() -> void:
	var lines := FrascoLogic.code_lines(FRASCO, {"poder": 5}, "+")
	check_eq(Array(lines), ["poder = 5", "# bonus está vacío", "poder + bonus"], "código parcial")
	lines = FrascoLogic.code_lines(FRASCO, {}, "")
	check_eq(lines[2], "poder ? bonus", "operador sin elegir")
	var boss_round := {"jars": [{"name": "x"}, {"name": "y"}], "operators": ["+", "-"]}
	check_eq(FrascoLogic.expression(boss_round), "x OP y", "expresión por defecto")


func test_encrucijada() -> void:
	var cases := {7: ["wrong", "puente"], 4: ["success", "cueva"], 1: ["wrong", "río"]}
	for p: int in cases:
		var r := FrascoLogic.check(CRUCE, {"poder": p}, "")
		check_eq(r["status"], cases[p][0], "estado con poder=%d" % p)
		check_eq(r["path"], cases[p][1], "camino con poder=%d" % p)
	check_eq(FrascoLogic.check(CRUCE, {"poder": 7}, "")["message"], "El Guardián te mandó a puente, pero tenías que llegar a cueva.", "mensaje")
	check_eq(FrascoLogic.check(CRUCE, {}, "")["status"], "name_error", "frasco vacío")
	check_eq(FrascoLogic.check(CRUCE, {"poder": "7"}, "")["status"], "type_error", "texto comparado con número")
	var lines := FrascoLogic.code_lines(CRUCE, {"poder": 4}, "")
	check_eq(Array(lines), ["poder = 4", "if poder > 5:", "    camino = 'puente'", "elif poder > 2:", "    camino = 'cueva'", "else:", "    camino = 'río'"], "código")
	var l3 := ContentDB.get_content("w2_l3")
	check_eq(FrascoLogic.check(l3, {"nota": 8, "asistencia": 60}, "")["path"], "recursa", "sin asistencia recursa")


func test_corrector_de_codigo() -> void:
	var l3 := ContentDB.get_content("w1_l3")
	var r := CodeLogic.check(l3, "nombre = input()\nedad = input()\nprint(f'{nombre} cumple {edad + 1} el año que viene')")
	check_eq(r["status"], "error", "edad sin convertir")
	check_eq(r["creature"], "quimera_tipos", "TypeError -> Quimera")
	check(str(r["message"]).contains("input() siempre devuelve texto"), "el mensaje explica el error típico")
	r = CodeLogic.check(l3, "nombre = input()\nedad = int(input())\nprint(nombre, 'cumple', edad + 1, 'el año que viene')")
	check_eq(r["status"], "missing", "pide f-string")
	r = CodeLogic.check(l3, "nombre = input()\nedad = input()\nprint(f'Ada cumple 21 el año que viene')")
	check_eq(r["status"], "wrong", "respuesta fija")
	check_eq(r["failed_case"], 1, "pasa el caso 1 pero no el 2")
	check_eq(r["message"], "Caso 2 (entrada: Linus / 35): esperaba «Linus cumple 36 el año que viene» y tu programa imprimió «Ada cumple 21 el año que viene».", "mensaje del caso")
	r = CodeLogic.check(l3, "nombre = input()\nedad = int(input())\nx = input()\nprint(f'{nombre}')")
	check_eq(r["status"], "error", "pide input de más")
	check(str(r["message"]).contains("más input()"), "explica el EOFError")
	var cases: Array = CodeLogic.check(l3, "nombre = input()\nedad = int(input())\nprint(f\"{nombre} cumple {edad + 1} el año que viene\")  ")["cases"]
	check_eq(cases.size(), 3, "tres casos")
	check(cases.all(func(c: Dictionary) -> bool: return c["passed"]), "espacios al final no importan")


func test_minijuego_resoluble() -> void:
	var mini := ContentDB.get_content("w1_mini")
	check(not (mini["rounds"] as Array).is_empty(), "tiene rondas")
	for r: Dictionary in mini["rounds"]:
		var blanks: Array = r["blanks"]
		check_eq(blanks.size(), MinigameLogic.blank_count(r["code"]), "una ficha por hueco en %s" % [r["code"]])
		for b: String in blanks:
			check((r["tokens"] as Array).has(b), "la ficha %s está disponible" % b)
		var res := MinigameLogic.check(r, blanks)
		check_eq(res["status"], "success", "ronda %s: %s" % [r["code"], res["message"]])


func test_bola_de_cristal_resoluble() -> void:
	var mini := ContentDB.get_content("w2_mini")
	check_eq(mini["kind"], "bola_de_cristal", "tipo de minijuego")
	for r: Dictionary in mini["rounds"]:
		var answer := MinigameLogic.prediction_answer(r)
		var matches := 0
		for opt: Variant in r["options"]:
			if str(opt) == answer:
				matches += 1
		check_eq(matches, 1, "exactamente una opción correcta en %s (pasa: %s)" % [r["code"], answer])
	var rounds: Array = mini["rounds"]
	check_eq(MinigameLogic.prediction_answer(rounds[0]), "cero", "cortocircuito: no evalúa y")
	check_eq(MinigameLogic.prediction_answer(rounds[2]), "TypeError", "input() es texto")
	check_eq(MinigameLogic.prediction_answer(rounds[3]), "Fizz", "el orden de los elif importa")
	check_eq(MinigameLogic.check_prediction(rounds[2], "mayor")["status"], "wrong", "predicción equivocada")


func test_minijuego_errores() -> void:
	var rounds: Array = ContentDB.get_content("w1_mini")["rounds"]
	check_eq(MinigameLogic.check(rounds[0], ["float"])["message"], "Tu hechizo imprimió 42.0, pero tenía que imprimir 42.", "float da 42.0")
	check_eq(MinigameLogic.check(rounds[1], ["*", "d"])["creature"], "quimera_tipos", "'d' con un float")
	check_eq(MinigameLogic.check(rounds[2], ["%", "//"])["status"], "wrong", "orden de // y %")
	check_eq(MinigameLogic.check(rounds[3], ["title", "strip"])["status"], "success", "title y strip en cualquier orden")
	check_eq(MinigameLogic.check(rounds[0], [""])["status"], "incomplete", "hueco vacío")
