class_name CodeLogic
extends RefCounted
## "Escribí el hechizo": el jugador escribe un programa y se prueba con varios casos,
## como un corrector automático. Cada caso tiene entradas para input() y la salida esperada.
##
## Campos del JSON: task, starter (líneas), tests [{inputs, output}], solution (líneas,
## solo para tests), require [{any: [textos], message}] (opcional).

const CREATURES := {
	"TypeError": "quimera_tipos",
	"ValueError": "quimera_tipos",
	"NameError": "fantasma_sin_nombre",
	"AttributeError": "fantasma_sin_nombre",
}
const TITLES := {
	"quimera_tipos": "¡La Quimera Tipos!",
	"fantasma_sin_nombre": "¡El Fantasma Sin Nombre!",
	"gremlin_sintaxis": "¡El Gremlin Sintaxis!",
}
const ERROR_TIPS := {
	"TypeError": "Estás mezclando tipos. Ojo: input() siempre devuelve texto (str).",
	"ValueError": "Una conversión falló: ¿el texto que convertís es realmente un número?",
	"NameError": "Usaste un nombre que no existe. ¿Está bien escrito? ¿Le faltan comillas?",
	"AttributeError": "Ese método no existe para ese tipo de valor.",
	"SyntaxError": "El hechizo está mal escrito: revisá comillas, paréntesis y los ':'.",
	"IndentationError": "Revisá la sangría: lo que va adentro de un if lleva 4 espacios.",
	"EOFError": "Tu programa pide más input() de los que hay en el caso de prueba.",
	"ZeroDivisionError": "Dividiste por cero.",
}


static func is_code(puzzle: Dictionary) -> bool:
	return str(puzzle.get("mechanic", "")) == "codigo"


static func starter(puzzle: Dictionary) -> String:
	return "\n".join(PackedStringArray(puzzle.get("starter", [])))


static func tests(puzzle: Dictionary) -> Array:
	return puzzle.get("tests", [])


## Salida comparable: sin espacios al final de cada línea ni líneas vacías al final.
static func normalize(text: String) -> String:
	var lines := text.split("\n")
	for i in lines.size():
		lines[i] = lines[i].strip_edges(false, true)
	return "\n".join(lines).strip_edges(false, true)


static func run_case(code: String, test: Dictionary) -> Dictionary:
	return PyEval.run(Array(code.split("\n")), test.get("vars", {}), test.get("inputs", []))


## "Ada, 20" para mostrar las entradas de un caso (una por cada input()).
static func describe_inputs(test: Dictionary) -> String:
	var parts: PackedStringArray = []
	for v: Variant in test.get("inputs", []):
		parts.append(str(v))
	return ", ".join(parts) if not parts.is_empty() else "(ninguna)"


static func one_line(text: String) -> String:
	return text.replace("\n", " / ")


static func check(puzzle: Dictionary, code: String) -> Dictionary:
	var out := {"status": "", "title": "", "message": "", "detail": "", "creature": "", "cases": [], "failed_case": -1}
	for req: Dictionary in puzzle.get("require", []):
		var found := false
		for text: String in req.get("any", []):
			if code.contains(text):
				found = true
		if not found:
			out["status"] = "missing"
			out["title"] = "Falta algo en el hechizo"
			out["creature"] = "owl"
			out["message"] = str(req.get("message", "Al hechizo le falta algo que pide la consigna."))
			return out
	var cases: Array = []
	for t: Dictionary in tests(puzzle):
		var r := run_case(code, t)
		var got := normalize(str(r["output"]))
		var expected := normalize(str(t.get("output", "")))
		cases.append({"passed": r["ok"] and got == expected, "got": got, "expected": expected,
			"error": r["error"], "message": r["message"], "inputs": describe_inputs(t)})
	out["cases"] = cases
	for i in cases.size():
		var c: Dictionary = cases[i]
		if c["passed"]:
			continue
		out["failed_case"] = i
		if c["error"] != "":
			var creature: String = CREATURES.get(c["error"], "gremlin_sintaxis")
			out["status"] = "error"
			out["creature"] = creature
			out["title"] = TITLES[creature]
			out["detail"] = c["message"]
			out["message"] = "Caso %d (entrada: %s). %s" % [i + 1, c["inputs"], ERROR_TIPS.get(c["error"], "")]
		else:
			out["status"] = "wrong"
			out["creature"] = "cauldron"
			out["title"] = "El hechizo no hizo lo esperado"
			out["message"] = "Caso %d (entrada: %s): esperaba «%s» y tu programa imprimió «%s»." % [
				i + 1, c["inputs"], one_line(c["expected"]), one_line(c["got"]) if c["got"] != "" else "nada"]
		return out
	out["status"] = "success"
	out["title"] = "¡Hechizo logrado!"
	out["message"] = "Tu programa pasó los %d casos de prueba." % cases.size()
	return out
