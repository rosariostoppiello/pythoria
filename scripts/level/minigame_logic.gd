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
	var r := PyEval.run(lines, {}, round.get("inputs", []))
	out["output"] = r["output"]
	if not r["ok"]:
		var map := {
			"TypeError": ["type_error", "¡La Quimera Tipos!", "quimera_tipos", "Mezclaste esencias de distinto tipo."],
			"ValueError": ["type_error", "¡La Quimera Tipos!", "quimera_tipos", "Ese valor no sirve para esa operación o ese formato."],
			"NameError": ["name_error", "¡El Fantasma Sin Nombre!", "fantasma_sin_nombre", "Usaste un nombre que no existe. ¿Te faltaron comillas?"],
			"SyntaxError": ["syntax_error", "¡El Gremlin Sintaxis!", "gremlin_sintaxis", "El hechizo está mal escrito."],
			"IndentationError": ["syntax_error", "¡El Gremlin Sintaxis!", "gremlin_sintaxis", "Revisá la sangría del hechizo."],
			"BucleInfinito": ["infinite", "¡El Ouroboros!", "ouroboros", "El bucle nunca termina."],
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


# --- Bola de cristal: predecir qué imprime un código --------------------------

## Lo que pasa de verdad al ejecutar el código: lo impreso o, si falla, el nombre
## del error (por ejemplo "TypeError"). La respuesta correcta sale de ejecutarlo.
static func prediction_answer(round: Dictionary) -> String:
	var r := PyEval.run(round["code"], {}, round.get("inputs", []))
	return str(r["output"]) if r["ok"] else str(r["error"])


static func check_prediction(round: Dictionary, choice: String) -> Dictionary:
	var out := {"status": "", "title": "", "message": "", "detail": "", "creature": "", "output": ""}
	var r := PyEval.run(round["code"], {}, round.get("inputs", []))
	var answer := prediction_answer(round)
	out["output"] = r["output"]
	if not r["ok"]:
		out["detail"] = r["message"]
	if choice == answer:
		out["status"] = "success"
		out["title"] = "¡Lo viste venir!"
		out["message"] = "El hechizo imprime: %s" % answer if r["ok"] else "El hechizo falla con %s." % answer
	else:
		out["status"] = "wrong"
		out["title"] = "La bola mostraba otra cosa"
		out["creature"] = "crystal_ball"
		var real := "imprime «%s»" % answer.replace("\n", " / ") if r["ok"] else "falla con %s" % answer
		out["message"] = "Elegiste «%s», pero el hechizo %s. Seguilo línea por línea." % [choice.replace("\n", " / "), real]
	return out


# --- Duelo de Bugs: elegir el arreglo que cura un hechizo con un bug -----------

## Reemplaza una línea del código: fix = {"line": n (desde 1), "text": "nueva línea"}.
static func apply_fix(code: Array, fix: Dictionary) -> Array:
	var out := code.duplicate()
	out[int(fix["line"]) - 1] = str(fix["text"])
	return out


static func run_duel(round: Dictionary, code: Array) -> Dictionary:
	return PyEval.run(code, {}, round.get("inputs", []))


## Primeras líneas de lo que imprime (o del error), para mostrar en pantalla.
static func preview(r: Dictionary, max_lines: int = 6) -> String:
	var lines := str(r["output"]).split("\n")
	var text := "\n".join(lines.slice(0, max_lines))
	if lines.size() > max_lines:
		text += "\n…"
	if not r["ok"]:
		var why := "se repite para siempre" if r["error"] == "BucleInfinito" else str(r["message"])
		text = (text + "\n" if str(r["output"]) != "" else "") + why
	return text if text != "" else "(no imprime nada)"


static func check_fix(round: Dictionary, fix_idx: int) -> Dictionary:
	var out := {"status": "", "title": "", "message": "", "detail": "", "creature": "", "output": ""}
	var fix: Dictionary = round["fixes"][fix_idx]
	var r := run_duel(round, apply_fix(round["code"], fix))
	out["output"] = r["output"]
	var expected := CodeLogic.normalize(str(round["output"]))
	if r["ok"] and CodeLogic.normalize(str(r["output"])) == expected:
		out["status"] = "success"
		out["title"] = "¡Bug derrotado!"
		out["message"] = "Con ese arreglo el hechizo imprime lo que tenía que imprimir."
		return out
	out["status"] = "wrong"
	out["title"] = "El bug sigue ahí"
	out["creature"] = CodeLogic.CREATURES.get(r["error"], "bug") if not r["ok"] else "bug"
	if r["error"] == "BucleInfinito":
		out["creature"] = "ouroboros"
		out["title"] = "¡El Ouroboros!"
	out["detail"] = r["message"] if not r["ok"] else ""
	var got := CodeLogic.one_line(preview(r, 4))
	out["message"] = "Con ese arreglo el hechizo da «%s», pero tenía que imprimir «%s»." % [got.left(90), CodeLogic.one_line(expected).left(90)]
	return out
