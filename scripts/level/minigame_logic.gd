class_name MinigameLogic
extends RefCounted
## "Completa el hechizo": reemplaza los huecos ____ por fichas y ejecuta el código.

const BLANK := "____"


static func blank_count(code: Array) -> int:
	var n := 0
	for line: String in code:
		n += line.count(BLANK)
	return n


## Rellena los huecos en orden con las fichas elegidas ("" deja el hueco).
static func fill(code: Array, choices: Array) -> Array[String]:
	var out: Array[String] = []
	var k := 0
	for line: String in code:
		var parts := line.split(BLANK)
		var s := parts[0]
		for i in range(1, parts.size()):
			s += (str(choices[k]) if k < choices.size() and str(choices[k]) != "" else BLANK) + parts[i]
			k += 1
		out.append(s)
	return out


## status: success, wrong, type_error, name_error, syntax_error, error, incomplete.
static func check(round: Dictionary, choices: Array) -> Dictionary:
	var out := {"status": "", "title": "", "message": "", "detail": "", "creature": "", "output": ""}
	var needed := blank_count(round["code"])
	var filled := 0
	for c: Variant in choices:
		if str(c) != "":
			filled += 1
	if filled < needed:
		out["status"] = "incomplete"
		out["title"] = "¡El Fantasma Sin Nombre!"
		out["creature"] = "fantasma_sin_nombre"
		out["message"] = "Todavía hay huecos vacíos en el hechizo."
		return out
	var lines := fill(round["code"], choices)
	var r := PyEval.run(lines)
	out["output"] = r["output"]
	if not r["ok"]:
		var map := {
			"TypeError": ["type_error", "¡La Quimera Tipos!", "quimera_tipos", "Mezclaste esencias de distinto tipo."],
			"NameError": ["name_error", "¡El Fantasma Sin Nombre!", "fantasma_sin_nombre", "Usaste un nombre que no existe. ¿Te faltaron comillas?"],
			"SyntaxError": ["syntax_error", "¡El Gremlin Sintaxis!", "gremlin_sintaxis", "El hechizo está mal escrito."],
		}
		var info: Array = map.get(r["error"], ["error", "¡El hechizo rebotó!", "gremlin_sintaxis", "Algo salió mal."])
		out["status"] = info[0]
		out["title"] = info[1]
		out["creature"] = info[2]
		out["message"] = info[3]
		out["detail"] = r["message"]
		return out
	if r["output"] == str(round["output"]):
		out["status"] = "success"
		out["title"] = "¡Hechizo completo!"
		out["message"] = "Imprimió: %s" % r["output"]
	else:
		out["status"] = "wrong"
		out["title"] = "El hechizo no hizo lo esperado"
		out["creature"] = "cauldron"
		out["message"] = "Tu hechizo imprimió %s, pero tenía que imprimir %s." % [r["output"] if r["output"] != "" else "nada", round["output"]]
	return out
