class_name FrascoLogic
extends RefCounted
## Reglas de la mecánica del Frasco, sin interfaz (las usan la escena y los tests).
## Un "puzzle" es un nivel o una ronda de boss: goal, jars, tokens, operators, expression.
## La Encrucijada (mechanic = "encrucijada") usa los mismos frascos, pero en vez de un
## caldero tiene ramas if/elif/else ("branches") y gana si `variable` termina en goal.
## `given` (opcional) son líneas de Python que se corren antes, por ejemplo una lista
## o una función que el caldero usa; se muestran arriba del código en vivo.
## El tipo "expr" en goal o en una ficha es código Python ("[50, 30]", "('a', 1)").

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
		"expr":
			var r := PyEval.evaluate(str(value))
			if not r["ok"]:
				push_error("Valor 'expr' inválido en el JSON: %s (%s)" % [value, r["message"]])
			return r["value"]
	return value


static func token_value(token: Dictionary) -> Variant:
	return typed(token.get("value"), str(token.get("type", "")))


static func goal_value(puzzle: Dictionary) -> Variant:
	var g: Dictionary = puzzle.get("goal", {})
	return typed(g.get("value"), str(g.get("type", "")))


static func goal_type(puzzle: Dictionary) -> String:
	var t := str(puzzle.get("goal", {}).get("type", ""))
	return PyEval.type_name(goal_value(puzzle)) if t == "expr" else t


## Líneas fijas que se corren antes del caldero (listas, diccionarios, funciones).
static func given(puzzle: Dictionary) -> Array:
	return puzzle.get("given", [])


## Variables que dejan las líneas fijas (se calculan de nuevo cada vez: así una lista
## que el hechizo modifica no queda cambiada para el próximo intento).
static func given_env(puzzle: Dictionary) -> Dictionary:
	if given(puzzle).is_empty():
		return {}
	var r := PyEval.run(given(puzzle))
	if not r["ok"]:
		push_error("given inválido: %s" % r["message"])
	return r["env"]


static func jar_names(puzzle: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for j: Dictionary in puzzle.get("jars", []):
		names.append(str(j["name"]))
	return names


static func operators(puzzle: Dictionary) -> Array:
	return puzzle.get("operators", [])


static func is_crossroads(puzzle: Dictionary) -> bool:
	return str(puzzle.get("mechanic", "")) == "encrucijada"


## Variable que asignan las ramas de la Encrucijada.
static func variable(puzzle: Dictionary) -> String:
	return str(puzzle.get("variable", "camino"))


static func branches(puzzle: Dictionary) -> Array:
	return puzzle.get("branches", [])


## Código if/elif/else de la Encrucijada (op reemplaza a OP en las condiciones).
static func branch_lines(puzzle: Dictionary, op: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	var bs := branches(puzzle)
	for i in bs.size():
		var b: Dictionary = bs[i]
		var assign := "    %s = %s" % [variable(puzzle), PyEval.repr(str(b["path"]))]
		if not b.has("cond"):
			lines.append("else:")
		else:
			var cond := str(b["cond"]).replace(OP_PLACEHOLDER, op if op != "" else "?")
			lines.append("%s %s:" % ["if" if i == 0 else "elif", cond])
		lines.append(assign)
	return lines


## Expresión del caldero. Si el JSON no la trae: "a OP b" (o solo el frasco).
## En la Encrucijada son todas las condiciones juntas.
static func expression(puzzle: Dictionary) -> String:
	if is_crossroads(puzzle):
		var conds: PackedStringArray = []
		for b: Dictionary in branches(puzzle):
			if b.has("cond"):
				conds.append(str(b["cond"]))
		return " ; ".join(conds)
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
	var env := given_env(puzzle)
	env.merge(values, true)
	return PyEval.evaluate(resolve(puzzle, op), env)


## Código Python equivalente, línea por línea.
static func code_lines(puzzle: Dictionary, values: Dictionary, op: String) -> PackedStringArray:
	var lines: PackedStringArray = []
	for g: Variant in given(puzzle):
		lines.append(str(g))
	for name: String in jar_names(puzzle):
		if values.has(name):
			lines.append("%s = %s" % [name, PyEval.repr(values[name])])
		else:
			lines.append("# %s está vacío" % name)
	if is_crossroads(puzzle):
		lines.append_array(branch_lines(puzzle, op))
		return lines
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
	var r: Dictionary
	if is_crossroads(puzzle):
		var env := given_env(puzzle)
		env.merge(values, true)
		r = PyEval.run(Array(branch_lines(puzzle, op)), env)
		if r["ok"]:
			r["value"] = r["env"].get(variable(puzzle))
	else:
		r = evaluate(puzzle, values, op)
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
			"SyntaxError", "IndentationError":
				out["status"] = "syntax_error"
				out["title"] = "¡El Gremlin Sintaxis!"
				out["creature"] = "gremlin_sintaxis"
				out["message"] = "El hechizo está mal escrito."
			_:
				out["status"] = "error"
				out["creature"] = CodeLogic.CREATURES.get(r["error"], "hechizo_rebotado")
				out["title"] = CodeLogic.TITLES.get(out["creature"], "¡El hechizo rebotó!")
				out["message"] = CodeLogic.ERROR_TIPS.get(r["error"], "Algo salió mal al lanzar.")
		out["detail"] = r["message"]
		return out
	out["value"] = r["value"]
	if is_crossroads(puzzle):
		out["path"] = r["value"]
		if r["value"] == null:
			out["status"] = "wrong"
			out["title"] = "Ningún camino se abrió"
			out["creature"] = "guardian_puerta"
			out["message"] = "Ninguna condición fue verdadera y no hay else: el Guardián no te deja pasar."
			return out
		if matches_goal(r["value"], puzzle):
			out["status"] = "success"
			out["title"] = "¡Llegaste!"
			out["message"] = "El Guardián te abrió el camino a %s." % PyEval.to_str(r["value"])
		else:
			out["status"] = "wrong"
			out["title"] = "Camino equivocado"
			out["creature"] = "guardian_puerta"
			out["message"] = "El Guardián te mandó a %s, pero tenías que llegar a %s." % [PyEval.to_str(r["value"]), PyEval.to_str(expected)]
		return out
	if matches_goal(r["value"], puzzle):
		out["status"] = "success"
		out["title"] = "¡Hechizo logrado!"
		out["message"] = "El caldero brilla turquesa: %s" % PyEval.repr(r["value"])
	else:
		out["status"] = "wrong"
		out["title"] = "El caldero no reaccionó"
		out["creature"] = "cauldron"
		if PyEval.type_name(r["value"]) != PyEval.type_name(expected) and PyEval.py_equal(r["value"], expected):
			out["message"] = "Obtuviste %s (%s), pero el caldero pedía %s (%s): mismo valor, distinto tipo." % [
				PyEval.repr(r["value"]), PyEval.type_name(r["value"]), PyEval.repr(expected), PyEval.type_name(expected)]
		else:
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
				values[j["name"]] = _solution_value(puzzle, s[j["name"]], str(j.get("accepts", "")))
		out.append({"values": values, "op": str(s.get("op", default_op))})
	return out


## Valor de una solución con su tipo. Si el frasco acepta "any", el tipo sale de la ficha
## que tiene ese mismo valor en el JSON (5 es int, "" es str).
static func _solution_value(puzzle: Dictionary, raw: Variant, accepts: String) -> Variant:
	if accepts in ["int", "float", "str", "bool"]:
		return typed(raw, accepts)
	for t: Dictionary in puzzle.get("tokens", []):
		if typeof(t.get("value")) == typeof(raw) and t.get("value") == raw:
			return token_value(t)
	return raw


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
