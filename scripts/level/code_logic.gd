class_name CodeLogic
extends RefCounted
## "Escribí el hechizo": el jugador escribe un programa y se prueba con varios casos,
## como un corrector automático. Cada caso tiene entradas para input() y la salida esperada.
##
## Campos del JSON: task, starter (líneas), tests [{inputs, output, files, vars,
## files_out}], solution (líneas, solo para tests), require y forbid
## [{any: [textos], message}] (opcionales).
## files: archivos que existen al empezar (nombre -> texto); files_out: cómo tienen que
## quedar; vars: variables que ya existen (valores del JSON, los objetos son dicts).

const CREATURES := {
	"TypeError": "quimera_tipos",
	"ValueError": "quimera_tipos",
	"NameError": "fantasma_sin_nombre",
	"AttributeError": "fantasma_sin_nombre",
	"UnboundLocalError": "fantasma_sin_nombre",
	"BucleInfinito": "ouroboros",
	"IndexError": "espectro_indice",
	"KeyError": "archivista_caos",
	"RecursionError": "espejo_infinito",
	"FileNotFoundError": "hechizo_rebotado",
	"UnsupportedOperation": "hechizo_rebotado",
	"ZeroDivisionError": "hechizo_rebotado",
	"AssertionError": "hechizo_rebotado",
	"EOFError": "hechizo_rebotado",
	"ModuleNotFoundError": "hechizo_rebotado",
	"RuntimeError": "hechizo_rebotado",
}
const TITLES := {
	"quimera_tipos": "¡La Quimera Tipos!",
	"fantasma_sin_nombre": "¡El Fantasma Sin Nombre!",
	"gremlin_sintaxis": "¡El Gremlin Sintaxis!",
	"ouroboros": "¡El Ouroboros!",
	"espectro_indice": "¡El Espectro del Índice!",
	"archivista_caos": "¡El Archivista del Caos!",
	"hechicero_espagueti": "¡El Hechicero Espagueti!",
	"hechizo_rebotado": "¡El Hechizo Rebotado!",
	"espejo_infinito": "¡El Espejo Infinito!",
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
	"BucleInfinito": "El hechizo no termina nunca: revisá que algo cambie en cada vuelta para que el bucle se corte.",
	"IndexError": "Pediste una posición que no existe. Las posiciones van de 0 a len - 1 (y de -1 a -len desde el final).",
	"KeyError": "Esa clave no está en el diccionario. Fijate cómo está escrita, o usá .get() con un valor por defecto.",
	"UnboundLocalError": "Adentro de la función asignás esa variable, así que Python la trata como local aunque afuera exista. Pasala como parámetro o devolvé el valor con return.",
	"RecursionError": "La función se llama a sí misma sin parar: le falta un caso base que corte, o el paso recursivo no se acerca a él.",
	"FileNotFoundError": "Ese archivo no existe. Revisá el nombre, o atrapá el error con try/except FileNotFoundError.",
	"UnsupportedOperation": "Abriste el archivo en un modo que no permite eso: 'r' es para leer, 'w' y 'a' para escribir.",
	"AssertionError": "Un assert encontró una condición falsa.",
	"ModuleNotFoundError": "En Pythoria no hace falta importar nada: todo lo que necesitás ya está.",
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
	return PyEval.run(Array(code.split("\n")), case_vars(test), test.get("inputs", []), test.get("files", {}))


## Variables del caso convertidas a valores de Python.
static func case_vars(test: Dictionary) -> Dictionary:
	var out := {}
	var raw: Dictionary = test.get("vars", {})
	for k: String in raw:
		out[k] = PyEval.from_json(raw[k])
	return out


## "notas.txt = «Ada,9 / Linus,7»" para mostrar los archivos y variables de un caso.
static func describe_setup(test: Dictionary) -> String:
	var parts: PackedStringArray = []
	var vars := case_vars(test)
	for k: String in vars:
		parts.append("%s = %s" % [k, PyEval.repr(vars[k])])
	var files: Dictionary = test.get("files", {})
	if test.has("files") and files.is_empty():
		parts.append("(no hay ningún archivo)")
	for name: String in files:
		parts.append("archivo %s: «%s»" % [name, one_line(str(files[name]).trim_suffix("\n"))])
	return "   ".join(parts)


## "Ada, 20" para mostrar las entradas de un caso (una por cada input()).
static func describe_inputs(test: Dictionary) -> String:
	var parts: PackedStringArray = []
	for v: Variant in test.get("inputs", []):
		parts.append(str(v))
	return ", ".join(parts) if not parts.is_empty() else "(ninguna)"


## "" si los archivos quedaron como pide files_out; si no, qué está mal.
static func _file_problem(test: Dictionary, r: Dictionary) -> String:
	var want: Dictionary = test.get("files_out", {})
	for name: String in want:
		var files: Dictionary = r.get("files", {})
		if not files.has(name):
			return "el archivo %s no se creó." % name
		var got := normalize(str(files[name]))
		if got != normalize(str(want[name])):
			return "el archivo %s tenía que quedar «%s» y quedó «%s»." % [name, one_line(normalize(str(want[name]))), one_line(got)]
	return ""


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
	for rule: Dictionary in puzzle.get("forbid", []):
		for text: String in rule.get("any", []):
			if code.contains(text):
				out["status"] = "missing"
				out["title"] = "Eso no vale en este hechizo"
				out["creature"] = "owl"
				out["message"] = str(rule.get("message", "La consigna no deja usar %s." % text.strip_edges()))
				return out
	var cases: Array = []
	for t: Dictionary in tests(puzzle):
		var r := run_case(code, t)
		var got := normalize(str(r["output"]))
		var expected := normalize(str(t.get("output", "")))
		var file_problem := _file_problem(t, r)
		cases.append({"passed": r["ok"] and got == expected and file_problem == "", "got": got, "expected": expected,
			"error": r["error"], "message": r["message"], "inputs": describe_inputs(t), "file_problem": file_problem})
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
		elif c["got"] != c["expected"]:
			out["status"] = "wrong"
			out["creature"] = "cauldron"
			out["title"] = "El hechizo no hizo lo esperado"
			out["message"] = "Caso %d (entrada: %s): esperaba «%s» y tu programa imprimió «%s»." % [
				i + 1, c["inputs"], one_line(c["expected"]), one_line(c["got"]) if c["got"] != "" else "nada"]
		else:
			out["status"] = "wrong"
			out["creature"] = "cauldron"
			out["title"] = "El archivo no quedó bien"
			out["message"] = "Caso %d: %s" % [i + 1, c["file_problem"]]
		return out
	out["status"] = "success"
	out["title"] = "¡Hechizo logrado!"
	out["message"] = "Tu programa pasó los %d casos de prueba." % cases.size()
	return out
