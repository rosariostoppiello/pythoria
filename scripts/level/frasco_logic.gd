class_name FrascoLogic
extends RefCounted
## Reglas de la mecánica del Frasco, sin interfaz (las usan la escena y los tests).
## Un "puzzle" es un nivel o una ronda de boss: goal, jars, tokens, operators, expression.

const OP_PLACEHOLDER := "OP"


## Convierte un valor del JSON al tipo de Python indicado (JSON da 8 como 8.0).
static func typed(value: Variant, type_name: String) -> Variant:
	match type_name:
		"int":
			return int(value)
		"float":
			return float(value)
		"bool":
			return bool(value)
		"str":
			return str(value)
	return value


static func token_value(token: Dictionary) -> Variant:
	return typed(token.get("value"), str(token.get("type", "")))


static func goal_value(puzzle: Dictionary) -> Variant:
	var g: Dictionary = puzzle.get("goal", {})
	return typed(g.get("value"), str(g.get("type", "")))


static func goal_type(puzzle: Dictionary) -> String:
	return str(puzzle.get("goal", {}).get("type", ""))


static func jar_names(puzzle: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for j: Dictionary in puzzle.get("jars", []):
		names.append(str(j["name"]))
	return names


static func operators(puzzle: Dictionary) -> Array:
	return puzzle.get("operators", [])


## Expresión del caldero. Si el JSON no la trae: "a OP b" (o solo el frasco).
static func expression(puzzle: Dictionary) -> String:
	if puzzle.has("expression"):
		return str(puzzle["expression"])
	var names := jar_names(puzzle)
	if names.size() >= 2 and not operators(puzzle).is_empty():
		return (" %s " % OP_PLACEHOLDER).join(names)
	return names[0] if names.size() > 0 else ""


static func needs_operator_choice(puzzle: Dictionary) -> bool:
	return expression(puzzle).contains(OP_PLACEHOLDER)


static func resolve(puzzle: Dictionary, op: String) -> String:
	return expression(puzzle).replace(OP_PLACEHOLDER, op)


## Evalúa el caldero con los frascos llenos (values: nombre -> valor).
static func evaluate(puzzle: Dictionary, values: Dictionary, op: String) -> Dictionary:
	return PyEval.evaluate(resolve(puzzle, op), values)


## Código Python equivalente, línea por línea.
static func code_lines(puzzle: Dictionary, values: Dictionary, op: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	for name: String in jar_names(puzzle):
		if values.has(name):
			lines.append("%s = %s" % [name, PyEval.repr(values[name])])
		else:
			lines.append("# %s está vacío" % name)
	var expr := resolve(puzzle, op)
	if needs_operator_choice(puzzle) and op == "":
		expr = expression(puzzle).replace(OP_PLACEHOLDER, "?")
	lines.append(expr)
	return lines


## Decide el resultado de lanzar. Lo que da el valor objetivo cuenta como correcto.
## status: success, wrong, type_error, name_error, syntax_error, error.
static func check(puzzle: Dictionary, values: Dictionary, op: String) -> Dictionary:
	var expected: Variant = goal_value(puzzle)
	var out := {"status": "", "value": null, "expected": expected, "title": "", "message": "", "detail": "", "creature": ""}
	if needs_operator_choice(puzzle) and op == "":
		out["status"] = "syntax_error"
		out["title"] = "¡El Gremlin Sintaxis!"
		out["creature"] = "gremlin_sintaxis"
		out["detail"] = "SyntaxError: falta el operador"
		out["message"] = "Elegí un operador para combinar los frascos."
		return out
	var r := evaluate(puzzle, values, op)
	if not r["ok"]:
		match r["error"]:
			"TypeError":
				out["status"] = "type_error"
				out["title"] = "¡La Quimera Tipos!"
				out["creature"] = "quimera_tipos"
				out["message"] = "Las esencias de distinto tipo no se mezclan. Fijate qué tipo tiene cada frasco."
			"NameError":
				out["status"] = "name_error"
				out["title"] = "¡El Fantasma Sin Nombre!"
				out["creature"] = "fantasma_sin_nombre"
				var missing := _missing_jar(puzzle, values)
				out["message"] = "El frasco %s está vacío: poné una ficha antes de lanzar." % missing if missing != "" else "Usaste un nombre que no existe."
			"SyntaxError":
				out["status"] = "syntax_error"
				out["title"] = "¡El Gremlin Sintaxis!"
				out["creature"] = "gremlin_sintaxis"
				out["message"] = "El hechizo está mal escrito."
			_:
				out["status"] = "error"
				out["title"] = "¡El hechizo rebotó!"
				out["creature"] = "gremlin_sintaxis"
				out["message"] = "Algo salió mal al lanzar."
		out["detail"] = r["message"]
		return out
	out["value"] = r["value"]
	if matches_goal(r["value"], puzzle):
		out["status"] = "success"
		out["title"] = "¡Hechizo logrado!"
		out["message"] = "El caldero brilla turquesa: %s" % PyEval.repr(r["value"])
	else:
		out["status"] = "wrong"
		out["title"] = "El caldero no reaccionó"
		out["creature"] = "cauldron"
		out["message"] = "Obtuviste %s, pero el caldero pedía %s." % [PyEval.repr(r["value"]), PyEval.repr(expected)]
	return out


static func matches_goal(value: Variant, puzzle: Dictionary) -> bool:
	var gt := goal_type(puzzle)
	if gt != "" and PyEval.type_name(value) != gt:
		return false
	return PyEval.py_equal(value, goal_value(puzzle))


static func _missing_jar(puzzle: Dictionary, values: Dictionary) -> String:
	for name: String in jar_names(puzzle):
		if not values.has(name):
			return name
	return ""


## Soluciones del JSON como [{values, op}], con los valores tipados según el frasco.
static func solutions(puzzle: Dictionary) -> Array[Dictionary]:
	var raw: Array = []
	if puzzle.has("solution"):
		raw.append(puzzle["solution"])
	raw.append_array(puzzle.get("solution_any", []))
	var out: Array[Dictionary] = []
	var default_op: String = str(operators(puzzle)[0]) if operators(puzzle).size() == 1 else ""
	for s: Dictionary in raw:
		var values := {}
		for j: Dictionary in puzzle.get("jars", []):
			if s.has(j["name"]):
				values[j["name"]] = typed(s[j["name"]], str(j.get("accepts", "")))
		out.append({"values": values, "op": str(s.get("op", default_op))})
	return out


## ¿Las fichas alcanzan para armar esta asignación? (cada ficha se usa una vez)
static func tokens_cover(puzzle: Dictionary, values: Dictionary) -> bool:
	var pool: Array = []
	for t: Dictionary in puzzle.get("tokens", []):
		pool.append(token_value(t))
	for name: String in values:
		var found := -1
		for i in pool.size():
			if PyEval.type_name(pool[i]) == PyEval.type_name(values[name]) and pool[i] == values[name]:
				found = i
				break
		if found < 0:
			return false
		pool.remove_at(found)
	return true
