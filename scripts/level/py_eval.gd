class_name PyEval
extends RefCounted
## Evaluador de un subconjunto de Python con semántica de Python (no de GDScript).
##
## Valores: int, float, str, bool, None, listas (Array), tuplas, diccionarios, sets,
## range, funciones (def y lambda), excepciones y archivos (en memoria).
## Expresiones: + - * / // % ** | & ^, comparaciones encadenadas, in, is, and/or/not,
## x if c else y, índices y slicing, f-strings con formato, listas/dicts/sets por
## comprensión, llamadas con argumentos por nombre y *lista.
## Sentencias: asignación (con desempaquetado, x[i] = v, +=), if/elif/else, while y for
## (con else, break, continue), def/return/global, lambda, try/except/else/finally,
## raise, with open(...) as f, del, assert y pass.
## input() lee de una lista de entradas fija (no imprime el mensaje); open() usa un
## sistema de archivos en memoria (nombre -> texto).
## Errores como en Python. Además, si un programa da más de MAX_STEPS pasos se corta
## con "BucleInfinito" (Python se colgaría), y la recursión se corta a MAX_DEPTH llamadas.
##
## Resultado de evaluate/run: {ok, value, output, error, message, env, files}.

const OPS := ["//=", "**=", "**", "==", "!=", "<=", ">=", "+=", "-=", "*=", "/=", "%=", "|=", "&=", "//",
	"<", ">", "+", "-", "*", "/", "%", "(", ")", "[", "]", "{", "}", "=", ",", ".", ":", "|", "&", "^"]
const COMPARE_OPS := ["==", "!=", "<", ">", "<=", ">="]
const AUG_OPS := {"+=": "+", "-=": "-", "*=": "*", "/=": "/", "//=": "//", "%=": "%", "**=": "**", "|=": "|", "&=": "&"}
const KEYWORDS := ["and", "or", "not", "if", "elif", "else", "in", "is", "while", "for", "break", "continue",
	"pass", "def", "return", "lambda", "global", "try", "except", "finally", "raise", "with", "as", "del",
	"assert", "import", "from", "class", "nonlocal", "yield"]
const BUILTINS := ["print", "input", "str", "int", "float", "bool", "len", "round", "abs", "max", "min", "range",
	"sum", "list", "tuple", "set", "dict", "sorted", "reversed", "enumerate", "zip", "open", "isinstance",
	"type", "any", "all", "chr", "ord", "map", "filter", "repr"]
const TYPE_NAMES := ["int", "float", "str", "bool", "list", "tuple", "set", "dict", "range", "NoneType"]
## Jerarquía de excepciones: hija -> madre.
const EXC_PARENTS := {
	"Exception": "BaseException",
	"ArithmeticError": "Exception", "ZeroDivisionError": "ArithmeticError",
	"LookupError": "Exception", "IndexError": "LookupError", "KeyError": "LookupError",
	"NameError": "Exception", "UnboundLocalError": "NameError",
	"OSError": "Exception", "FileNotFoundError": "OSError", "UnsupportedOperation": "OSError",
	"RuntimeError": "Exception", "RecursionError": "RuntimeError",
	"ValueError": "Exception", "TypeError": "Exception", "AttributeError": "Exception",
	"EOFError": "Exception", "AssertionError": "Exception", "ModuleNotFoundError": "Exception",
}
## Errores que no se pueden atrapar con except (se detectan antes de correr, o son del juego).
const UNCATCHABLE := ["SyntaxError", "IndentationError", "BucleInfinito"]
## Pasos máximos (líneas ejecutadas, vueltas de bucle y llamadas) antes de cortar.
const MAX_STEPS := 20000
## Llamadas anidadas máximas antes de RecursionError (Python usa 1000).
const MAX_DEPTH := 60
const COMPOUND := ["if", "elif", "else", "while", "for", "def", "try", "except", "finally", "with"]
const STMT_KINDS := ["assign", "augassign", "return", "global", "raise", "del", "assert", "import", "pass"]


## Tupla de Python (inmutable).
class PyTuple extends RefCounted:
	var items: Array = []

	func _init(a: Array = []) -> void:
		items = a


## Diccionario de Python: clave de hash -> [clave, valor]. Respeta el orden de inserción.
class PyDict extends RefCounted:
	var data: Dictionary = {}


## Set de Python: clave de hash -> valor.
class PySet extends RefCounted:
	var data: Dictionary = {}


## Función definida con def o lambda.
class PyFunc extends RefCounted:
	var name := ""
	var params: Array = []
	var defaults: Dictionary = {}
	var prog: Array = []
	var start := 0
	var end := 0
	var indent := 0
	var local_names: Dictionary = {}
	var global_names: Dictionary = {}
	var closure: Array = []
	var expr: Variant = null


## Función o tipo de Python ya incluido (len, int, ValueError, ...).
class PyBuiltin extends RefCounted:
	var name := ""

	func _init(n: String = "") -> void:
		name = n


## Excepción como valor (except ValueError as e).
class PyExc extends RefCounted:
	var kind := ""
	var text := ""

	func _init(k: String = "", t: String = "") -> void:
		kind = k
		text = t


## Archivo abierto con open().
class PyFile extends RefCounted:
	var name := ""
	var mode := "r"
	var pos := 0
	var closed := false


var env: Dictionary = {}
var _globals: Dictionary = {}
## Lo impreso hasta ahora (print agrega su `end`, por defecto un salto de línea).
var output: String = ""
## Entradas que devuelve input(), en orden.
var inputs: Array = []
## Archivos en memoria: nombre -> contenido.
var files: Dictionary = {}
var _err: Dictionary = {}
var _toks: Array = []
var _pos := 0
var _steps := 0
## "break", "continue" o "return" mientras sube hasta quien lo atiende.
var _flow := ""
var _ret: Variant = null
var _loop_depth := 0
## Lo marca _loop_body cuando un break cortó el bucle (para el else del bucle).
var _broke := false
## Líneas ya parseadas (en un bucle la misma línea se ejecuta muchas veces).
var _cache: Dictionary = {}
## Función que se está ejecutando (null en el programa principal).
var _scope: PyFunc = null
var _depth := 0
## Excepciones que se están atendiendo (para un raise sin nada).
var _handling: Array = []


## Evalúa una expresión con las variables de `variables` (nombre -> valor).
static func evaluate(src: String, variables: Dictionary = {}) -> Dictionary:
	var e := PyEval.new()
	e.env = variables.duplicate()
	e._globals = e.env
	var ast: Variant = e._parse_line(src)
	var value: Variant = null
	if e._err.is_empty():
		var k := str(ast.get("k", "")) if typeof(ast) == TYPE_DICTIONARY else ""
		if k == "assign" or k == "augassign":
			e._fail("SyntaxError", "se esperaba una expresión, no una asignación")
		elif k in STMT_KINDS:
			e._fail("SyntaxError", "se esperaba una expresión")
		else:
			value = e._eval(ast)
	return e._result(value)


## Ejecuta un programa (lista de líneas). output = lo impreso; env = variables al terminar;
## files = archivos al terminar.
static func run(lines: Array, variables: Dictionary = {}, input_values: Array = [], file_system: Dictionary = {}) -> Dictionary:
	var e := PyEval.new()
	e.env = variables.duplicate()
	e._globals = e.env
	e.inputs = input_values.duplicate()
	e.files = file_system.duplicate()
	var prog := e._logical_lines(lines)
	if e._err.is_empty():
		e._precheck(prog)
	if e._err.is_empty() and not prog.is_empty():
		e._exec_block(prog, 0, prog.size(), int(prog[0]["indent"]))
	return e._result(null)


## Verdad de Python: 0, "", None, False y los contenedores vacíos son falsos.
static func truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v) != ""
		TYPE_NIL:
			return false
		TYPE_ARRAY:
			return not (v as Array).is_empty()
		TYPE_DICTIONARY:
			if v.has("__range__"):
				return _range_len(v) > 0
	if v is PyTuple:
		return not (v as PyTuple).items.is_empty()
	if v is PyDict:
		return not (v as PyDict).data.is_empty()
	if v is PySet:
		return not (v as PySet).data.is_empty()
	return true


# --- Tipos y conversión a texto ---------------------------------------------

static func type_name(v: Variant) -> String:
	match typeof(v):
		TYPE_BOOL:
			return "bool"
		TYPE_INT:
			return "int"
		TYPE_FLOAT:
			return "float"
		TYPE_STRING, TYPE_STRING_NAME:
			return "str"
		TYPE_NIL:
			return "NoneType"
		TYPE_ARRAY:
			return "list"
		TYPE_DICTIONARY:
			if v.has("__range__"):
				return "range"
			return "object"
	if v is PyTuple:
		return "tuple"
	if v is PyDict:
		return "dict"
	if v is PySet:
		return "set"
	if v is PyFunc:
		return "function"
	if v is PyBuiltin:
		var n: String = (v as PyBuiltin).name
		return "type" if n in TYPE_NAMES or _is_exc_name(n) else "builtin_function_or_method"
	if v is PyExc:
		return (v as PyExc).kind
	if v is PyFile:
		return "TextIOWrapper"
	return "object"


static func _is_exc_name(n: String) -> bool:
	return EXC_PARENTS.has(n) or n == "BaseException"


## str(v) de Python.
static func to_str(v: Variant) -> String:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			return str(v)
		TYPE_BOOL:
			return "True" if v else "False"
		TYPE_NIL:
			return "None"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			var f: float = v
			if is_inf(f):
				return "inf" if f > 0 else "-inf"
			if is_nan(f):
				return "nan"
			if f == floorf(f) and absf(f) < 1e16:
				return "%d.0" % int(f)
			# var_to_str da la representación más corta que vuelve al mismo float, como Python.
			return var_to_str(f)
	if v is PyExc:
		return (v as PyExc).text
	return repr(v)


## repr(v) de Python: los textos van entre comillas, también adentro de listas y dicts.
static func repr(v: Variant) -> String:
	match typeof(v):
		TYPE_STRING, TYPE_STRING_NAME:
			var s := str(v)
			var q := "'"
			if s.contains("'") and not s.contains('"'):
				q = '"'
			var body := s.replace("\\", "\\\\").replace("\n", "\\n").replace("\t", "\\t")
			if q == "'":
				body = body.replace("'", "\\'")
			return q + body + q
		TYPE_ARRAY:
			return "[" + _join_repr(v) + "]"
		TYPE_DICTIONARY:
			if v.has("__range__"):
				if v["step"] == 1:
					return "range(%d, %d)" % [v["start"], v["stop"]]
				return "range(%d, %d, %d)" % [v["start"], v["stop"], v["step"]]
	if v is PyTuple:
		var items: Array = (v as PyTuple).items
		if items.size() == 1:
			return "(" + repr(items[0]) + ",)"
		return "(" + _join_repr(items) + ")"
	if v is PyDict:
		var parts: PackedStringArray = []
		for entry: Array in (v as PyDict).data.values():
			parts.append(repr(entry[0]) + ": " + repr(entry[1]))
		return "{" + ", ".join(parts) + "}"
	if v is PySet:
		if (v as PySet).data.is_empty():
			return "set()"
		return "{" + _join_repr((v as PySet).data.values()) + "}"
	if v is PyBuiltin:
		var n: String = (v as PyBuiltin).name
		if n in TYPE_NAMES or _is_exc_name(n):
			return "<class '%s'>" % n
		return "<built-in function %s>" % n
	if v is PyFunc:
		return "<function %s>" % (v as PyFunc).name
	if v is PyExc:
		var ex: PyExc = v
		return "%s(%s)" % [ex.kind, repr(ex.text) if ex.text != "" else ""]
	if v is PyFile:
		return "<_io.TextIOWrapper name=%s mode=%s>" % [repr((v as PyFile).name), repr((v as PyFile).mode)]
	return to_str(v)


static func _join_repr(items: Array) -> String:
	var parts: PackedStringArray = []
	for x: Variant in items:
		parts.append(repr(x))
	return ", ".join(parts)


## Igualdad de Python: 1 == True, 1 == 1.0, '1' != 1, [1, 2] == [1, 2].
static func py_equal(a: Variant, b: Variant) -> bool:
	if _is_num(a) and _is_num(b):
		return _num(a) == _num(b)
	var ta := type_name(a)
	if ta != type_name(b):
		return false
	match ta:
		"str":
			return str(a) == str(b)
		"NoneType":
			return true
		"list":
			return _seq_equal(a, b)
		"tuple":
			return _seq_equal((a as PyTuple).items, (b as PyTuple).items)
		"range":
			return _range_len(a) == _range_len(b) and (_range_len(a) == 0 or (a["start"] == b["start"] and (_range_len(a) == 1 or a["step"] == b["step"])))
		"dict":
			var da: Dictionary = (a as PyDict).data
			var db: Dictionary = (b as PyDict).data
			if da.size() != db.size():
				return false
			for k: String in da:
				if not db.has(k) or not py_equal(da[k][1], db[k][1]):
					return false
			return true
		"set":
			var sa: Dictionary = (a as PySet).data
			var sb: Dictionary = (b as PySet).data
			if sa.size() != sb.size():
				return false
			for k: String in sa:
				if not sb.has(k):
					return false
			return true
		"type":
			return (a as PyBuiltin).name == (b as PyBuiltin).name
	if typeof(a) == TYPE_OBJECT and typeof(b) == TYPE_OBJECT:
		return is_same(a, b)
	return a == b


static func _seq_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if not py_equal(a[i], b[i]):
			return false
	return true


static func _is_num(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]


static func _num(v: Variant) -> Variant:
	if typeof(v) == TYPE_BOOL:
		return 1 if v else 0
	return v


## Clave de hash para dicts y sets ("" si el valor no se puede usar como clave).
static func hash_key(v: Variant) -> String:
	match typeof(v):
		TYPE_NIL:
			return "N"
		TYPE_BOOL:
			return "n:1" if v else "n:0"
		TYPE_INT:
			return "n:%d" % v
		TYPE_FLOAT:
			var f: float = v
			if f == floorf(f) and absf(f) < 1e18:
				return "n:%d" % int(f)
			return "f:" + var_to_str(f)
		TYPE_STRING, TYPE_STRING_NAME:
			return "s:" + str(v)
		TYPE_DICTIONARY:
			if v.has("__range__"):
				return "r:%d,%d,%d" % [v["start"], v["stop"], v["step"]]
	if v is PyTuple:
		var parts: PackedStringArray = []
		for x: Variant in (v as PyTuple).items:
			var k := hash_key(x)
			if k == "":
				return ""
			parts.append(k)
		return "t(" + ",".join(parts) + ")"
	if v is PyFunc or v is PyBuiltin or v is PyExc or v is PyFile:
		return "o:%d" % (v as Object).get_instance_id()
	return ""


## Crea un dict de Python a partir de pares [clave, valor].
static func make_dict(pairs: Array) -> PyDict:
	var d := PyDict.new()
	for p: Array in pairs:
		d.data[hash_key(p[0])] = [p[0], p[1]]
	return d


static func make_tuple(items: Array) -> PyTuple:
	return PyTuple.new(items)


## Convierte un valor del JSON a Python: objetos a dict, listas a list, 8.0 a 8.
static func from_json(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			var f: float = v
			return int(f) if f == floorf(f) and absf(f) < 1e15 else f
		TYPE_ARRAY:
			var out: Array = []
			for x: Variant in v:
				out.append(from_json(x))
			return out
		TYPE_DICTIONARY:
			var pairs: Array = []
			for k: Variant in v:
				pairs.append([str(k), from_json(v[k])])
			return make_dict(pairs)
	return v


# --- Resultado y errores ----------------------------------------------------

func _fail(kind: String, msg: String) -> void:
	if _err.is_empty():
		_err = {"error": kind, "message": "%s: %s" % [kind, msg] if msg != "" else kind, "text": msg}


func _result(value: Variant) -> Dictionary:
	var text := output.trim_suffix("\n")
	if not _err.is_empty():
		return {"ok": false, "value": null, "output": text, "error": _err["error"], "message": _err["message"], "env": _globals, "files": files}
	return {"ok": true, "value": value, "output": text, "error": "", "message": "", "env": _globals, "files": files}


# --- Líneas lógicas ------------------------------------------------------------

## Junta las líneas que siguen adentro de paréntesis, saca comentarios y separa
## "if x: algo" en dos líneas. Devuelve [{indent, text}].
func _logical_lines(lines: Array) -> Array:
	var out: Array = []
	var buf := ""
	var buf_indent := 0
	for raw: Variant in lines:
		var line := _strip_comment(str(raw).replace("\t", "    "))
		if buf == "":
			if line.strip_edges() == "":
				continue
			var stripped := line.strip_edges(true, false)
			buf_indent = line.length() - stripped.length()
			buf = line.strip_edges()
		else:
			if line.strip_edges() == "":
				continue
			buf += " " + line.strip_edges()
		if _open_brackets(buf) > 0:
			continue
		_split_inline(buf_indent, buf, out)
		buf = ""
	if buf != "":
		_fail("SyntaxError", "falta cerrar un paréntesis o corchete")
	return out


## Saca el comentario (# fuera de comillas).
static func _strip_comment(line: String) -> String:
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if quote != "":
			if c == "\\":
				i += 2
				continue
			if c == quote:
				quote = ""
		elif c == "'" or c == '"':
			quote = c
		elif c == "#":
			return line.substr(0, i).strip_edges(false, true)
		i += 1
	return line.strip_edges(false, true)


## Cuántos paréntesis/corchetes/llaves quedan abiertos (fuera de comillas).
static func _open_brackets(text: String) -> int:
	var depth := 0
	var quote := ""
	var i := 0
	while i < text.length():
		var c := text[i]
		if quote != "":
			if c == "\\":
				i += 2
				continue
			if c == quote:
				quote = ""
		elif c == "'" or c == '"':
			quote = c
		elif c in ["(", "[", "{"]:
			depth += 1
		elif c in [")", "]", "}"]:
			depth -= 1
		i += 1
	return depth


## Posición del primer ':' fuera de comillas y paréntesis (-1 si no hay).
static func _top_colon(text: String) -> int:
	var depth := 0
	var quote := ""
	var i := 0
	while i < text.length():
		var c := text[i]
		if quote != "":
			if c == "\\":
				i += 2
				continue
			if c == quote:
				quote = ""
		elif c == "'" or c == '"':
			quote = c
		elif c in ["(", "[", "{"]:
			depth += 1
		elif c in [")", "]", "}"]:
			depth -= 1
		elif c == ":" and depth == 0:
			return i
		i += 1
	return -1


func _split_inline(indent: int, text: String, out: Array) -> void:
	var first := text.split(" ", true, 1)[0].trim_suffix(":")
	if first in COMPOUND and not text.begins_with("lambda"):
		var colon := _top_colon(text)
		if colon >= 0 and colon < text.length() - 1:
			var rest := text.substr(colon + 1).strip_edges()
			if rest != "":
				out.append({"indent": indent, "text": text.substr(0, colon + 1).strip_edges()})
				_split_inline(indent + 4, rest, out)
				return
	out.append({"indent": indent, "text": text})


## Revisa la sintaxis de todas las líneas antes de correr (como Python).
func _precheck(prog: Array) -> void:
	for line: Dictionary in prog:
		var text: String = line["text"]
		var first := text.split(" ", true, 1)[0].split("(", true, 1)[0].trim_suffix(":")
		match first:
			"if", "elif", "while":
				var cond := _header(text, first)
				if _err.is_empty():
					if cond == "":
						_fail("SyntaxError", "falta la condición después de '%s'" % first)
					else:
						_parsed_expr(cond)
			"for":
				var h := _header(text, "for")
				if _err.is_empty():
					_parse_for(h)
			"def":
				if _def_regex().search(text) == null:
					_fail("SyntaxError", "un def se escribe: def nombre(parámetros):")
			"else", "try", "finally", "except", "with":
				if not text.ends_with(":"):
					_fail("SyntaxError", "falta ':' al final de: %s" % text)
			"break", "continue", "pass":
				pass
			_:
				_parsed(text)
		if not _err.is_empty():
			return


# --- Tokenizador -------------------------------------------------------------

func _tokenize(src: String) -> Array:
	var toks: Array = []
	var i := 0
	var n := src.length()
	while i < n:
		var c := src[i]
		if c == " " or c == "\t":
			i += 1
			continue
		if c == "#":
			break
		# f-strings
		if (c == "f" or c == "F") and i + 1 < n and (src[i + 1] == "'" or src[i + 1] == '"'):
			var end := _string_end(src, i + 1)
			if end < 0:
				_fail("SyntaxError", "texto sin cerrar (falta una comilla)")
				return []
			toks.append({"t": "FSTR", "v": src.substr(i + 2, end - i - 2)})
			i = end + 1
			continue
		if c == "'" or c == '"':
			var end2 := _string_end(src, i)
			if end2 < 0:
				_fail("SyntaxError", "texto sin cerrar (falta una comilla)")
				return []
			toks.append({"t": "STR", "v": _unescape(src.substr(i + 1, end2 - i - 1))})
			i = end2 + 1
			continue
		if c.is_valid_int():
			var j := i
			var is_float := false
			while j < n and (src[j].is_valid_int() or src[j] == "_" or (src[j] == "." and not is_float and j + 1 < n and src[j + 1].is_valid_int()) or (src[j] == "." and not is_float and (j + 1 >= n or not src[j + 1].is_valid_identifier()))):
				if src[j] == ".":
					is_float = true
				j += 1
			var text := src.substr(i, j - i).replace("_", "")
			if j < n and (src[j].is_valid_identifier() and not src[j].is_valid_int()):
				_fail("SyntaxError", "número mal escrito")
				return []
			toks.append({"t": "NUM", "v": text.to_float() if is_float else text.to_int()})
			i = j
			continue
		if c == "_" or c.is_valid_identifier():
			var k := i
			while k < n and (src[k] == "_" or src[k].is_valid_identifier() or src[k].is_valid_int()):
				k += 1
			toks.append({"t": "NAME", "v": src.substr(i, k - i)})
			i = k
			continue
		var matched := false
		for op: String in OPS:
			if src.substr(i, op.length()) == op:
				toks.append({"t": "OP", "v": op})
				i += op.length()
				matched = true
				break
		if not matched:
			_fail("SyntaxError", "símbolo inválido '%s'" % c)
			return []
	toks.append({"t": "EOF", "v": ""})
	return toks


func _string_end(src: String, start: int) -> int:
	var q := src[start]
	var i := start + 1
	while i < src.length():
		if src[i] == "\\":
			i += 2
			continue
		if src[i] == q:
			return i
		i += 1
	return -1


## Secuencias de escape: \n, \t, \\, \', \".
static func _unescape(s: String) -> String:
	if not s.contains("\\"):
		return s
	var out := ""
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "\\" and i + 1 < s.length():
			var nx := s[i + 1]
			match nx:
				"n":
					out += "\n"
				"t":
					out += "\t"
				"\\", "'", '"':
					out += nx
				_:
					out += "\\" + nx
			i += 2
			continue
		out += c
		i += 1
	return out


# --- Parser ------------------------------------------------------------------

func _peek() -> Dictionary:
	return _toks[_pos]


func _peek2() -> Dictionary:
	return _toks[mini(_pos + 1, _toks.size() - 1)]


func _next() -> Dictionary:
	var t: Dictionary = _toks[_pos]
	if _pos < _toks.size() - 1:
		_pos += 1
	return t


func _is_op(v: String) -> bool:
	return _peek()["t"] == "OP" and _peek()["v"] == v


func _is_word(w: String) -> bool:
	return _peek()["t"] == "NAME" and _peek()["v"] == w


func _expect_op(v: String, msg: String) -> bool:
	if not _is_op(v):
		_fail("SyntaxError", msg)
		return false
	_next()
	return true


func _expect_end() -> void:
	if _err.is_empty() and _peek()["t"] != "EOF":
		_fail("SyntaxError", "sintaxis inválida cerca de '%s'" % _peek()["v"])


## Parsea una sentencia simple (asignación, return, raise, ... o una expresión).
func _parse_line(src: String) -> Variant:
	_toks = _tokenize(src)
	_pos = 0
	if not _err.is_empty():
		return null
	if _peek()["t"] == "EOF":
		_fail("SyntaxError", "línea vacía")
		return null
	var ast: Variant = _parse_statement()
	_expect_end()
	return ast if _err.is_empty() else null


func _parse_statement() -> Variant:
	if _peek()["t"] == "NAME":
		match str(_peek()["v"]):
			"return":
				_next()
				if _peek()["t"] == "EOF":
					return {"k": "return", "v": null}
				return {"k": "return", "v": _parse_exprlist()}
			"pass":
				_next()
				return {"k": "pass"}
			"global":
				_next()
				var names: Array = []
				while _err.is_empty():
					if _peek()["t"] != "NAME":
						_fail("SyntaxError", "global va seguido de nombres")
						return null
					names.append(_next()["v"])
					if not _is_op(","):
						break
					_next()
				return {"k": "global", "names": names}
			"raise":
				_next()
				if _peek()["t"] == "EOF":
					return {"k": "raise", "v": null}
				return {"k": "raise", "v": _parse_expr()}
			"del":
				_next()
				var target: Variant = _parse_exprlist()
				if _err.is_empty() and not _valid_target(target, true):
					_fail("SyntaxError", "no se puede borrar eso con del")
				return {"k": "del", "target": target}
			"assert":
				_next()
				var cond: Variant = _parse_expr()
				var msg: Variant = null
				if _is_op(","):
					_next()
					msg = _parse_expr()
				return {"k": "assert", "cond": cond, "msg": msg}
			"import", "from":
				var mod := ""
				_next()
				if _peek()["t"] == "NAME":
					mod = _next()["v"]
				while _peek()["t"] != "EOF":
					_next()
				return {"k": "import", "module": mod}
	var ast: Variant = _parse_exprlist()
	if not _err.is_empty():
		return null
	if _is_op("="):
		var targets: Array = [ast]
		var value: Variant = null
		while _err.is_empty() and _is_op("="):
			_next()
			value = _parse_exprlist()
			if _is_op("="):
				targets.append(value)
		for t: Variant in targets:
			if not _valid_target(t, false):
				_fail("SyntaxError", "no se puede asignar a un valor; a la izquierda del = va un nombre")
				return null
		return {"k": "assign", "targets": targets, "value": value}
	if _peek()["t"] == "OP" and AUG_OPS.has(_peek()["v"]):
		var op: String = _next()["v"]
		if typeof(ast) != TYPE_DICTIONARY or not str(ast.get("k")) in ["name", "index"]:
			_fail("SyntaxError", "no se puede usar %s con eso; a la izquierda va un nombre" % op)
			return null
		return {"k": "augassign", "target": ast, "op": AUG_OPS[op], "value": _parse_exprlist()}
	return ast


func _valid_target(t: Variant, for_del: bool) -> bool:
	if typeof(t) != TYPE_DICTIONARY:
		return false
	match str(t.get("k")):
		"name", "index":
			return true
		"tuple", "list":
			for x: Variant in t["items"]:
				if not _valid_target(x, for_del):
					return false
			return not (t["items"] as Array).is_empty() or for_del
	return false


## Expresión o varias separadas por comas (una tupla sin paréntesis).
func _parse_exprlist() -> Variant:
	var first: Variant = _parse_expr()
	if not _is_op(","):
		return first
	var items: Array = [first]
	while _err.is_empty() and _is_op(","):
		_next()
		if _peek()["t"] == "EOF" or _is_op("=") or _is_op(")") or (_peek()["t"] == "OP" and AUG_OPS.has(_peek()["v"])):
			break
		items.append(_parse_expr())
	return {"k": "tuple", "items": items}


func _parse_expr() -> Variant:
	if _is_word("lambda"):
		return _parse_lambda()
	var a: Variant = _parse_or()
	if _err.is_empty() and _is_word("if"):
		_next()
		var cond: Variant = _parse_or()
		if not _is_word("else"):
			_fail("SyntaxError", "a 'x if condición' le falta el 'else'")
			return null
		_next()
		return {"k": "ternary", "cond": cond, "a": a, "b": _parse_expr()}
	return a


func _parse_lambda() -> Variant:
	_next()
	var params: Array = []
	var defaults := {}
	while _err.is_empty() and not _is_op(":"):
		if _peek()["t"] != "NAME" or _peek()["v"] in KEYWORDS:
			_fail("SyntaxError", "lambda: los parámetros van antes de ':'")
			return null
		var p: String = _next()["v"]
		params.append(p)
		if _is_op("="):
			_next()
			defaults[p] = _parse_expr()
		if _is_op(","):
			_next()
	if not _expect_op(":", "a la lambda le falta ':'"):
		return null
	return {"k": "lambda", "params": params, "defaults": defaults, "body": _parse_expr()}


func _parse_or() -> Variant:
	var left: Variant = _parse_and()
	while _err.is_empty() and _is_word("or"):
		_next()
		left = {"k": "or", "l": left, "r": _parse_and()}
	return left


func _parse_and() -> Variant:
	var left: Variant = _parse_not()
	while _err.is_empty() and _is_word("and"):
		_next()
		left = {"k": "and", "l": left, "r": _parse_not()}
	return left


func _parse_not() -> Variant:
	if _is_word("not"):
		_next()
		return {"k": "not", "v": _parse_not()}
	return _parse_compare()


## Comparaciones encadenadas como en Python: a < b < c es (a < b) and (b < c).
func _parse_compare() -> Variant:
	var first: Variant = _parse_bitor()
	var ops: Array = []
	var operands: Array = [first]
	while _err.is_empty():
		if _peek()["t"] == "OP" and COMPARE_OPS.has(_peek()["v"]):
			ops.append(_next()["v"])
		elif _is_word("in"):
			_next()
			ops.append("in")
		elif _is_word("not") and _peek2()["v"] == "in":
			_next()
			_next()
			ops.append("not in")
		elif _is_word("is"):
			_next()
			if _is_word("not"):
				_next()
				ops.append("is not")
			else:
				ops.append("is")
		else:
			break
		operands.append(_parse_bitor())
	if ops.is_empty():
		return first
	return {"k": "cmp", "ops": ops, "operands": operands}


func _parse_bitor() -> Variant:
	var left: Variant = _parse_bitxor()
	while _err.is_empty() and _is_op("|"):
		_next()
		left = {"k": "bin", "op": "|", "l": left, "r": _parse_bitxor()}
	return left


func _parse_bitxor() -> Variant:
	var left: Variant = _parse_bitand()
	while _err.is_empty() and _is_op("^"):
		_next()
		left = {"k": "bin", "op": "^", "l": left, "r": _parse_bitand()}
	return left


func _parse_bitand() -> Variant:
	var left: Variant = _parse_arith()
	while _err.is_empty() and _is_op("&"):
		_next()
		left = {"k": "bin", "op": "&", "l": left, "r": _parse_arith()}
	return left


func _parse_arith() -> Variant:
	var left: Variant = _parse_term()
	while _err.is_empty() and (_is_op("+") or _is_op("-")):
		var op: String = _next()["v"]
		left = {"k": "bin", "op": op, "l": left, "r": _parse_term()}
	return left


func _parse_term() -> Variant:
	var left: Variant = _parse_unary()
	while _err.is_empty() and (_is_op("*") or _is_op("/") or _is_op("//") or _is_op("%")):
		var op: String = _next()["v"]
		left = {"k": "bin", "op": op, "l": left, "r": _parse_unary()}
	return left


func _parse_unary() -> Variant:
	if _is_op("-") or _is_op("+"):
		var op: String = _next()["v"]
		return {"k": "neg" if op == "-" else "pos", "v": _parse_unary()}
	return _parse_power()


## ** asocia a la derecha y pesa más que el menos unario de la izquierda: -2 ** 2 es -4.
func _parse_power() -> Variant:
	var base: Variant = _parse_postfix()
	if _err.is_empty() and _is_op("**"):
		_next()
		return {"k": "bin", "op": "**", "l": base, "r": _parse_unary()}
	return base


## Llamadas, índices, slicing y métodos: f(x), lista[1:3], texto.upper().
func _parse_postfix() -> Variant:
	var node: Variant = _parse_primary()
	while _err.is_empty():
		if _is_op("("):
			_next()
			var call := _parse_args()
			if not _err.is_empty():
				return null
			node = {"k": "call", "fn": node, "args": call["args"], "kwargs": call["kwargs"]}
		elif _is_op("["):
			_next()
			node = _parse_subscript(node)
		elif _is_op("."):
			_next()
			if _peek()["t"] != "NAME":
				_fail("SyntaxError", "después del punto va el nombre de un método")
				return null
			var method: String = _next()["v"]
			if not _is_op("("):
				node = {"k": "attr", "obj": node, "name": method}
				continue
			_next()
			var mcall := _parse_args()
			if not _err.is_empty():
				return null
			node = {"k": "method", "obj": node, "name": method, "args": mcall["args"], "kwargs": mcall["kwargs"]}
		else:
			break
	return node


func _parse_subscript(obj: Variant) -> Variant:
	var parts: Array = [null]
	var is_slice := false
	if not _is_op(":") and not _is_op("]"):
		parts[0] = _parse_exprlist()
	while _err.is_empty() and _is_op(":") and parts.size() < 3:
		_next()
		is_slice = true
		if _is_op(":") or _is_op("]"):
			parts.append(null)
		else:
			parts.append(_parse_expr())
	if not _expect_op("]", "falta cerrar el corchete ]"):
		return null
	if not is_slice:
		if parts[0] == null:
			_fail("SyntaxError", "entre los corchetes va un índice")
			return null
		return {"k": "index", "obj": obj, "idx": parts[0]}
	while parts.size() < 3:
		parts.append(null)
	return {"k": "slice", "obj": obj, "lo": parts[0], "hi": parts[1], "step": parts[2]}


## Argumentos hasta el ')' (ya consumido el '('). Soporta nombre=valor, *lista y
## un generador como único argumento: sum(x * x for x in xs).
func _parse_args() -> Dictionary:
	var args: Array = []
	var kwargs: Dictionary = {}
	if not _is_op(")"):
		while _err.is_empty():
			var t := _peek()
			var nxt := _peek2()
			if t["t"] == "NAME" and nxt["t"] == "OP" and nxt["v"] == "=":
				_next()
				_next()
				kwargs[t["v"]] = _parse_expr()
			elif _is_op("*"):
				_next()
				args.append({"k": "star", "v": _parse_expr()})
			else:
				if not kwargs.is_empty():
					_fail("SyntaxError", "los argumentos con nombre van al final")
					return {}
				var a: Variant = _parse_expr()
				if _is_word("for") and args.is_empty():
					a = _parse_comp("list", a, null, null)
				args.append(a)
			if _is_op(","):
				_next()
				if _is_op(")"):
					break
				continue
			break
	if not _is_op(")"):
		_fail("SyntaxError", "falta cerrar el paréntesis")
		return {}
	_next()
	return {"args": args, "kwargs": kwargs}


## [elt for x in it if cond] (también sets y dicts).
func _parse_comp(kind: String, elt: Variant, key: Variant, val: Variant) -> Variant:
	var gens: Array = []
	while _err.is_empty() and _is_word("for"):
		_next()
		var target: Variant = _parse_target_list()
		if not _is_word("in"):
			_fail("SyntaxError", "falta 'in' en la comprensión")
			return null
		_next()
		var iter: Variant = _parse_or()
		var conds: Array = []
		while _err.is_empty() and _is_word("if"):
			_next()
			conds.append(_parse_or())
		gens.append({"target": target, "iter": iter, "conds": conds})
	return {"k": "comp", "kind": kind, "elt": elt, "key": key, "val": val, "gens": gens}


## Destino de un for: nombre, o varios separados por comas (con o sin paréntesis).
func _parse_target_list() -> Variant:
	var items: Array = [_parse_target_atom()]
	var comma := false
	while _err.is_empty() and _is_op(","):
		_next()
		comma = true
		if _is_word("in") or _is_op(")"):
			break
		items.append(_parse_target_atom())
	if items.size() == 1 and not comma:
		return items[0]
	return {"k": "tuple", "items": items}


func _parse_target_atom() -> Variant:
	if _peek()["t"] == "NAME" and not _peek()["v"] in KEYWORDS:
		return {"k": "name", "v": _next()["v"]}
	if _is_op("("):
		_next()
		var inner: Variant = _parse_target_list()
		if not _expect_op(")", "falta cerrar el paréntesis"):
			return null
		return inner
	_fail("SyntaxError", "un for se escribe: for nombre in algo:")
	return null


func _parse_primary() -> Variant:
	var t := _next()
	match t["t"]:
		"NUM":
			return {"k": "lit", "v": t["v"]}
		"STR":
			var s: String = t["v"]
			while _peek()["t"] == "STR":
				s += str(_next()["v"])
			return {"k": "lit", "v": s}
		"FSTR":
			return _parse_fstring(t["v"])
		"NAME":
			var w: String = t["v"]
			match w:
				"True":
					return {"k": "lit", "v": true}
				"False":
					return {"k": "lit", "v": false}
				"None":
					return {"k": "lit", "v": null}
			if w in KEYWORDS:
				_fail("SyntaxError", "'%s' no puede ir acá" % w)
				return null
			return {"k": "name", "v": w}
		"OP":
			match str(t["v"]):
				"(":
					if _is_op(")"):
						_next()
						return {"k": "tuple", "items": []}
					var first: Variant = _parse_expr()
					if _is_word("for"):
						var gen: Variant = _parse_comp("list", first, null, null)
						_expect_op(")", "falta cerrar el paréntesis")
						return gen
					if _is_op(","):
						var items: Array = [first]
						while _err.is_empty() and _is_op(","):
							_next()
							if _is_op(")"):
								break
							items.append(_parse_expr())
						_expect_op(")", "falta cerrar el paréntesis")
						return {"k": "tuple", "items": items}
					_expect_op(")", "falta cerrar el paréntesis")
					return first
				"[":
					if _is_op("]"):
						_next()
						return {"k": "list", "items": []}
					var first2: Variant = _parse_item()
					if _is_word("for"):
						var comp: Variant = _parse_comp("list", first2, null, null)
						_expect_op("]", "falta cerrar el corchete ]")
						return comp
					var items2: Array = [first2]
					while _err.is_empty() and _is_op(","):
						_next()
						if _is_op("]"):
							break
						items2.append(_parse_item())
					_expect_op("]", "falta cerrar el corchete ]")
					return {"k": "list", "items": items2}
				"{":
					return _parse_brace()
	_fail("SyntaxError", "sintaxis inválida" if t["t"] != "EOF" else "falta algo al final de la línea")
	return null


## Elemento de una lista literal: una expresión o *algo para desarmarlo.
func _parse_item() -> Variant:
	if _is_op("*"):
		_next()
		return {"k": "star", "v": _parse_expr()}
	return _parse_expr()


## {} es un dict vacío; {a: b} un dict; {a, b} un set.
func _parse_brace() -> Variant:
	if _is_op("}"):
		_next()
		return {"k": "dict", "keys": [], "values": []}
	var first: Variant = _parse_expr()
	if _is_op(":"):
		_next()
		var v: Variant = _parse_expr()
		if _is_word("for"):
			var comp: Variant = _parse_comp("dict", null, first, v)
			_expect_op("}", "falta cerrar la llave }")
			return comp
		var keys: Array = [first]
		var values: Array = [v]
		while _err.is_empty() and _is_op(","):
			_next()
			if _is_op("}"):
				break
			keys.append(_parse_expr())
			if not _expect_op(":", "en un diccionario cada clave lleva ':' y su valor"):
				return null
			values.append(_parse_expr())
		_expect_op("}", "falta cerrar la llave }")
		return {"k": "dict", "keys": keys, "values": values}
	if _is_word("for"):
		var scomp: Variant = _parse_comp("set", first, null, null)
		_expect_op("}", "falta cerrar la llave }")
		return scomp
	var items: Array = [first]
	while _err.is_empty() and _is_op(","):
		_next()
		if _is_op("}"):
			break
		items.append(_parse_expr())
	_expect_op("}", "falta cerrar la llave }")
	return {"k": "set", "items": items}


## Parsea una expresión suelta (condición de un if, iterable de un for, ...).
func _parse_expr_src(src: String) -> Variant:
	_toks = _tokenize(src)
	_pos = 0
	if not _err.is_empty():
		return null
	if _peek()["t"] == "EOF":
		_fail("SyntaxError", "falta una expresión")
		return null
	var ast: Variant = _parse_exprlist()
	_expect_end()
	return ast if _err.is_empty() else null


## f"Hola {nombre}" -> partes de texto y expresiones.
func _parse_fstring(body: String) -> Variant:
	var parts: Array = []
	var i := 0
	var lit := ""
	while i < body.length():
		var c := body[i]
		if c == "{" and i + 1 < body.length() and body[i + 1] == "{":
			lit += "{"
			i += 2
			continue
		if c == "}" and i + 1 < body.length() and body[i + 1] == "}":
			lit += "}"
			i += 2
			continue
		if c == "{":
			var close := _fstring_close(body, i)
			if close < 0:
				_fail("SyntaxError", "f-string: falta cerrar la llave }")
				return null
			if lit != "":
				parts.append({"k": "lit", "v": _unescape(lit)})
				lit = ""
			var inner := body.substr(i + 1, close - i - 1)
			var spec := ""
			var colon := _spec_colon(inner)
			if colon >= 0:
				spec = inner.substr(colon + 1)
				inner = inner.substr(0, colon)
			var sub := PyEval.new()
			var ast: Variant = sub._parse_expr_src(inner)
			if not sub._err.is_empty():
				_err = sub._err
				return null
			parts.append({"k": "fmt", "v": ast, "spec": spec})
			i = close + 1
			continue
		lit += c
		i += 1
	if lit != "":
		parts.append({"k": "lit", "v": _unescape(lit)})
	return {"k": "fstr", "parts": parts}


## La llave } que cierra la { de la posición `open` (salteando llaves y comillas de adentro).
static func _fstring_close(body: String, open: int) -> int:
	var depth := 0
	var quote := ""
	for i in range(open, body.length()):
		var c := body[i]
		if quote != "":
			if c == quote:
				quote = ""
		elif c == "'" or c == '"':
			quote = c
		elif c == "{":
			depth += 1
		elif c == "}":
			depth -= 1
			if depth == 0:
				return i
	return -1


## Posición del ':' que separa la expresión del formato (fuera de comillas y paréntesis).
static func _spec_colon(inner: String) -> int:
	var depth := 0
	var quote := ""
	for i in inner.length():
		var c := inner[i]
		if quote != "":
			if c == quote:
				quote = ""
		elif c == "'" or c == '"':
			quote = c
		elif c in ["(", "[", "{"]:
			depth += 1
		elif c in [")", "]", "}"]:
			depth -= 1
		elif c == ":" and depth == 0:
			return i
	return -1


## format(valor, spec) para lo más común: [<>^][0][ancho][,][.N][f d % s].
func format_spec(v: Variant, spec: String) -> String:
	if spec == "":
		return to_str(v)
	var re := RegEx.create_from_string("^([<>^]?)(0?)(\\d*)(,?)(?:\\.(\\d+))?([fds%]?)$")
	var m := re.search(spec)
	if m == null:
		_fail("ValueError", "formato no soportado: '%s'" % spec)
		return ""
	var align := m.get_string(1)
	var zero := m.get_string(2) == "0"
	var width := m.get_string(3).to_int() if m.get_string(3) != "" else 0
	var commas := m.get_string(4) == ","
	var prec := m.get_string(5)
	var kind := m.get_string(6)
	var text := ""
	if kind == "s":
		if type_name(v) != "str":
			_fail("ValueError", "el formato 's' es para textos, no para %s" % type_name(v))
			return ""
		text = str(v)
		if prec != "":
			text = text.left(prec.to_int())
	elif kind != "" or prec != "" or commas or zero:
		if not _is_num(v):
			_fail("ValueError", "el formato '%s' es para números, no para %s" % [spec, type_name(v)])
			return ""
		var x: Variant = _num(v)
		match kind:
			"d":
				if typeof(x) != TYPE_INT:
					_fail("ValueError", "el formato 'd' es para int, no para float")
					return ""
				text = str(x)
			"%":
				text = ("%." + (prec if prec != "" else "6") + "f") % (float(x) * 100.0) + "%"
			_:
				if prec != "" or kind == "f":
					text = ("%." + (prec if prec != "" else "6") + "f") % float(x)
				else:
					text = to_str(x)
		if commas:
			var neg := text.begins_with("-")
			var digits := text.trim_prefix("-")
			var dot := digits.find(".")
			var int_part := digits if dot < 0 else digits.substr(0, dot)
			var rest := "" if dot < 0 else digits.substr(dot)
			var grouped := ""
			for j in int_part.length():
				if j > 0 and (int_part.length() - j) % 3 == 0:
					grouped += ","
				grouped += int_part[j]
			text = ("-" if neg else "") + grouped + rest
		if zero and align == "" and text.length() < width:
			var sign := "-" if text.begins_with("-") else ""
			text = sign + "0".repeat(width - text.length()) + text.trim_prefix("-")
	else:
		text = to_str(v)
	if text.length() < width:
		var pad := width - text.length()
		if align == "^":
			text = " ".repeat(pad / 2) + text + " ".repeat(pad - pad / 2)
		elif align == "<" or (align == "" and type_name(v) == "str"):
			text = text + " ".repeat(pad)
		else:
			text = " ".repeat(pad) + text
	return text


# --- Ejecución de bloques --------------------------------------------------------

## Sentencia parseada una sola vez (en un bucle se ejecuta muchas veces).
func _parsed(text: String) -> Variant:
	var key := "s:" + text
	if _cache.has(key):
		return _cache[key]
	var ast: Variant = _parse_line(text)
	if _err.is_empty():
		_cache[key] = ast
	return ast


func _parsed_expr(text: String) -> Variant:
	var key := "e:" + text
	if _cache.has(key):
		return _cache[key]
	var ast: Variant = _parse_expr_src(text)
	if _err.is_empty():
		_cache[key] = ast
	return ast


## "for a, b in algo" -> {target, iter}.
func _parse_for(header: String) -> Variant:
	var key := "f:" + header
	if _cache.has(key):
		return _cache[key]
	_toks = _tokenize(header)
	_pos = 0
	if not _err.is_empty():
		return null
	var target: Variant = _parse_target_list()
	if _err.is_empty() and not _is_word("in"):
		_fail("SyntaxError", "un for se escribe: for nombre in algo:")
	if not _err.is_empty():
		return null
	_next()
	var iter: Variant = _parse_exprlist()
	_expect_end()
	if not _err.is_empty():
		return null
	var out := {"target": target, "iter": iter}
	_cache[key] = out
	return out


## Cuenta un paso y corta si el programa no termina nunca.
func _step() -> bool:
	_steps += 1
	if _steps > MAX_STEPS:
		_fail("BucleInfinito", "el hechizo dio más de %d pasos sin terminar: parece un bucle que nunca se corta" % MAX_STEPS)
		return false
	return true


## Fin del bloque con sangría que empieza después del encabezado `header_idx`.
func _block_end(prog: Array, header_idx: int, end: int, indent: int) -> int:
	var body_end := header_idx + 1
	while body_end < end and int(prog[body_end]["indent"]) > indent:
		body_end += 1
	if body_end == header_idx + 1:
		_fail("IndentationError", "falta el bloque con sangría después de: %s" % prog[header_idx]["text"])
	return body_end


## Texto entre la palabra clave y el ':' final ("while n > 0:" -> "n > 0").
func _header(text: String, keyword: String) -> String:
	if not text.ends_with(":"):
		_fail("SyntaxError", "falta ':' al final de: %s" % text)
		return ""
	return text.substr(keyword.length(), text.length() - keyword.length() - 1).strip_edges()


static func _starts_with_word(text: String, word: String) -> bool:
	if not text.begins_with(word):
		return false
	var rest := text.substr(word.length())
	return rest == "" or rest[0] == " " or rest[0] == ":" or rest[0] == "("


## Ejecuta las líneas [start, end) que tienen sangría `indent`.
func _exec_block(prog: Array, start: int, end: int, indent: int) -> void:
	var i := start
	while i < end and _err.is_empty() and _flow == "":
		var line: Dictionary = prog[i]
		var text: String = line["text"]
		if int(line["indent"]) != indent:
			_fail("IndentationError", "sangría inesperada en: %s" % text)
			return
		if not _step():
			return
		if _starts_with_word(text, "elif") or _starts_with_word(text, "else"):
			_fail("SyntaxError", "'%s' sin un if antes" % text.split(" ")[0].trim_suffix(":"))
			return
		if _starts_with_word(text, "except") or _starts_with_word(text, "finally"):
			_fail("SyntaxError", "'%s' sin un try antes" % text.split(" ")[0].trim_suffix(":"))
			return
		if text == "break" or text == "continue":
			if _loop_depth == 0:
				_fail("SyntaxError", "'%s' fuera de un bucle" % text)
				return
			_flow = text
			return
		if text == "pass":
			i += 1
		elif _starts_with_word(text, "if"):
			i = _exec_if(prog, i, end, indent)
		elif _starts_with_word(text, "while"):
			i = _exec_while(prog, i, end, indent)
		elif _starts_with_word(text, "for"):
			i = _exec_for(prog, i, end, indent)
		elif _starts_with_word(text, "def"):
			i = _exec_def(prog, i, end, indent)
		elif _starts_with_word(text, "try"):
			i = _exec_try(prog, i, end, indent)
		elif _starts_with_word(text, "with"):
			i = _exec_with(prog, i, end, indent)
		else:
			var ast: Variant = _parsed(text)
			if _err.is_empty():
				_exec(ast)
			i += 1


## Cadena if / elif / else. Devuelve el índice de la línea siguiente a la cadena.
func _exec_if(prog: Array, i: int, end: int, indent: int) -> int:
	var branches: Array[Dictionary] = []
	var keyword := "if"
	while true:
		var header: String = prog[i]["text"]
		var cond := _header(header, keyword)
		if not _err.is_empty():
			return end
		if keyword != "else" and cond == "":
			_fail("SyntaxError", "falta la condición después de '%s'" % keyword)
			return end
		if keyword == "else" and cond != "":
			_fail("SyntaxError", "else no lleva condición")
			return end
		var body_end := _block_end(prog, i, end, indent)
		if not _err.is_empty():
			return end
		branches.append({"cond": cond, "kw": keyword, "start": i + 1, "end": body_end})
		i = body_end
		if keyword == "else" or i >= end or int(prog[i]["indent"]) != indent:
			break
		var nxt: String = prog[i]["text"]
		if _starts_with_word(nxt, "elif"):
			keyword = "elif"
		elif _starts_with_word(nxt, "else"):
			keyword = "else"
		else:
			break
	for b: Dictionary in branches:
		var take := true
		if b["kw"] != "else":
			var cond_ast: Variant = _parsed_expr(b["cond"])
			if not _err.is_empty():
				return end
			take = truthy(_eval(cond_ast))
			if not _err.is_empty():
				return end
		if take:
			var s: int = b["start"]
			_exec_block(prog, s, b["end"], int(prog[s]["indent"]))
			break
	return i


## Corre el cuerpo de un bucle una vez. Devuelve false si hay que dejar de iterar.
func _loop_body(prog: Array, body_start: int, body_end: int) -> bool:
	_loop_depth += 1
	_exec_block(prog, body_start, body_end, int(prog[body_start]["indent"]))
	_loop_depth -= 1
	if not _err.is_empty():
		return false
	if _flow == "break":
		_flow = ""
		_broke = true
		return false
	if _flow == "return":
		return false
	_flow = ""
	return _step()


func _exec_while(prog: Array, i: int, end: int, indent: int) -> int:
	var cond := _header(prog[i]["text"], "while")
	if _err.is_empty() and cond == "":
		_fail("SyntaxError", "falta la condición del while")
	var body_end := _block_end(prog, i, end, indent)
	if not _err.is_empty():
		return end
	var cond_ast: Variant = _parsed_expr(cond)
	_broke = false
	while _err.is_empty():
		var ok := truthy(_eval(cond_ast))
		if not _err.is_empty() or not ok:
			break
		if not _loop_body(prog, i + 1, body_end):
			break
	return _loop_else(prog, body_end, end, indent)


## else de un bucle: corre solo si el bucle terminó sin break. Devuelve la línea siguiente.
func _loop_else(prog: Array, body_end: int, end: int, indent: int) -> int:
	var broke := _broke
	_broke = false
	if body_end >= end or int(prog[body_end]["indent"]) != indent or not _starts_with_word(prog[body_end]["text"], "else"):
		return body_end
	if _header(prog[body_end]["text"], "else") != "" and _err.is_empty():
		_fail("SyntaxError", "else no lleva condición")
	var else_end := _block_end(prog, body_end, end, indent)
	if not _err.is_empty():
		return end
	if not broke and _flow == "":
		_exec_block(prog, body_end + 1, else_end, int(prog[body_end + 1]["indent"]))
	return else_end


func _exec_for(prog: Array, i: int, end: int, indent: int) -> int:
	var header := _header(prog[i]["text"], "for")
	var parsed: Variant = _parse_for(header) if _err.is_empty() else null
	var body_end := _block_end(prog, i, end, indent)
	if not _err.is_empty():
		return end
	var target: Variant = parsed["target"]
	var iterable: Variant = _eval(parsed["iter"])
	if not _err.is_empty():
		return end
	_broke = false
	if type_name(iterable) == "range":
		var v: int = iterable["start"]
		var stop: int = iterable["stop"]
		var step: int = iterable["step"]
		while (step > 0 and v < stop) or (step < 0 and v > stop):
			_assign(target, v)
			if not _err.is_empty() or not _loop_body(prog, i + 1, body_end):
				break
			v += step
	elif typeof(iterable) == TYPE_ARRAY:
		# Como Python: recorre la lista viva por posición (si la cambiás, se nota).
		var arr: Array = iterable
		var idx := 0
		while idx < arr.size():
			_assign(target, arr[idx])
			if not _err.is_empty() or not _loop_body(prog, i + 1, body_end):
				break
			idx += 1
	else:
		var values: Variant = _iter(iterable)
		if not _err.is_empty():
			return end
		for v: Variant in values:
			_assign(target, v)
			if not _err.is_empty() or not _loop_body(prog, i + 1, body_end):
				break
	return _loop_else(prog, body_end, end, indent)


static var _def_re: RegEx
static var _local_res: Array = []


static func _def_regex() -> RegEx:
	if _def_re == null:
		_def_re = RegEx.create_from_string("^def\\s+([A-Za-z_]\\w*)\\s*\\((.*)\\)\\s*:$")
	return _def_re


func _exec_def(prog: Array, i: int, end: int, indent: int) -> int:
	var text: String = prog[i]["text"]
	var m := _def_regex().search(text)
	if m == null:
		_fail("SyntaxError", "un def se escribe: def nombre(parámetros):")
		return end
	var body_end := _block_end(prog, i, end, indent)
	if not _err.is_empty():
		return end
	var f := PyFunc.new()
	f.name = m.get_string(1)
	for raw: String in _split_top(m.get_string(2)):
		var p := raw.strip_edges()
		if p == "":
			continue
		var pname := p
		var default_src := ""
		var eq := p.find("=")
		if eq >= 0:
			pname = p.substr(0, eq).strip_edges()
			default_src = p.substr(eq + 1).strip_edges()
		if not pname.is_valid_identifier() or pname in KEYWORDS:
			_fail("SyntaxError", "parámetro inválido en %s(): %s" % [f.name, p])
			return end
		if f.params.has(pname):
			_fail("SyntaxError", "el parámetro '%s' está repetido" % pname)
			return end
		if default_src == "" and not f.defaults.is_empty():
			_fail("SyntaxError", "los parámetros con valor por defecto van al final")
			return end
		f.params.append(pname)
		if default_src != "":
			# Como en Python, el valor por defecto se calcula una sola vez, al definir.
			var dv: Variant = _eval(_parsed_expr(default_src))
			if not _err.is_empty():
				return end
			f.defaults[pname] = dv
	f.prog = prog
	f.start = i + 1
	f.end = body_end
	f.indent = int(prog[i + 1]["indent"])
	for p: String in f.params:
		f.local_names[p] = true
	_scan_locals(prog, i + 1, body_end, f)
	if _scope != null:
		f.closure = [env] + _scope.closure
	_set_name(f.name, f)
	return body_end


## Nombres que la función asigna (son locales, salvo que diga global).
static func _scan_locals(prog: Array, start: int, end: int, f: PyFunc) -> void:
	if _local_res.is_empty():
		for pattern: String in [
			"^([A-Za-z_]\\w*(?:\\s*,\\s*[A-Za-z_]\\w*)*)\\s*(?:=(?!=)|\\+=|-=|\\*=|/=|//=|%=|\\*\\*=|\\|=|&=)",
			"^for\\s+(.+?)\\s+in\\s",
			"^except\\b.*\\bas\\s+([A-Za-z_]\\w*)",
			"^with\\b.*\\bas\\s+([A-Za-z_]\\w*)",
			"^def\\s+([A-Za-z_]\\w*)",
		]:
			_local_res.append(RegEx.create_from_string(pattern))
	var word := RegEx.create_from_string("[A-Za-z_]\\w*")
	for k in range(start, end):
		var text: String = prog[k]["text"]
		if text.begins_with("global "):
			for n: String in text.substr(7).split(","):
				f.global_names[n.strip_edges()] = true
			continue
		for re: RegEx in _local_res:
			var m := re.search(text)
			if m != null:
				for w: RegExMatch in word.search_all(m.get_string(1)):
					if not w.get_string() in KEYWORDS:
						f.local_names[w.get_string()] = true
	for g: String in f.global_names:
		f.local_names.erase(g)


## Separa por comas de primer nivel (fuera de paréntesis y comillas).
static func _split_top(text: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var depth := 0
	var quote := ""
	var cur := ""
	for c in text:
		if quote != "":
			if c == quote:
				quote = ""
		elif c == "'" or c == '"':
			quote = c
		elif c in ["(", "[", "{"]:
			depth += 1
		elif c in [")", "]", "}"]:
			depth -= 1
		elif c == "," and depth == 0:
			out.append(cur)
			cur = ""
			continue
		cur += c
	out.append(cur)
	return out


func _exec_try(prog: Array, i: int, end: int, indent: int) -> int:
	if prog[i]["text"] != "try:":
		_fail("SyntaxError", "try se escribe solo: try:")
		return end
	var body_end := _block_end(prog, i, end, indent)
	if not _err.is_empty():
		return end
	var handlers: Array[Dictionary] = []
	var else_part := {}
	var finally_part := {}
	var j := body_end
	while j < end and int(prog[j]["indent"]) == indent:
		var text: String = prog[j]["text"]
		var kw := ""
		for w: String in ["except", "else", "finally"]:
			if _starts_with_word(text, w):
				kw = w
		if kw == "" or (kw == "else" and handlers.is_empty()):
			break
		var spec := _header(text, kw)
		if not _err.is_empty():
			return end
		var part_end := _block_end(prog, j, end, indent)
		if not _err.is_empty():
			return end
		var part := {"spec": spec, "start": j + 1, "end": part_end}
		if kw == "except":
			if not else_part.is_empty() or not finally_part.is_empty():
				_fail("SyntaxError", "except va antes de else y finally")
				return end
			handlers.append(part)
		elif kw == "else":
			if not else_part.is_empty() or not finally_part.is_empty():
				break
			else_part = part
		else:
			finally_part = part
			j = part_end
			break
		j = part_end
	if handlers.is_empty() and finally_part.is_empty():
		_fail("SyntaxError", "un try necesita except o finally")
		return end
	_exec_block(prog, i + 1, body_end, int(prog[i + 1]["indent"]))
	if not _err.is_empty() and not _err["error"] in UNCATCHABLE:
		for h: Dictionary in handlers:
			var spec: String = h["spec"]
			var name := ""
			var as_idx := spec.find(" as ")
			if as_idx >= 0:
				name = spec.substr(as_idx + 4).strip_edges()
				spec = spec.substr(0, as_idx).strip_edges()
			if not _exc_matches(spec, _err["error"]):
				continue
			var exc := PyExc.new(_err["error"], _err.get("text", ""))
			_err = {}
			if name != "":
				_set_name(name, exc)
			_handling.append(exc)
			_exec_block(prog, h["start"], h["end"], int(prog[h["start"]]["indent"]))
			_handling.pop_back()
			break
	elif _err.is_empty() and _flow == "" and not else_part.is_empty():
		_exec_block(prog, else_part["start"], else_part["end"], int(prog[else_part["start"]]["indent"]))
	if not finally_part.is_empty():
		var pending_err := _err
		var pending_flow := _flow
		var pending_ret: Variant = _ret
		if pending_err.is_empty() or not pending_err["error"] in UNCATCHABLE:
			_err = {}
			_flow = ""
			_exec_block(prog, finally_part["start"], finally_part["end"], int(prog[finally_part["start"]]["indent"]))
			if _err.is_empty():
				_err = pending_err
				if _flow == "":
					_flow = pending_flow
					_ret = pending_ret
	return j


## ¿El except `spec` ("ValueError", "(KeyError, IndexError)", "") atrapa `kind`?
static func _exc_matches(spec: String, kind: String) -> bool:
	if spec == "":
		return true
	for raw: String in spec.trim_prefix("(").trim_suffix(")").split(","):
		var want := raw.strip_edges()
		var k := kind
		while k != "":
			if k == want:
				return true
			k = str(EXC_PARENTS.get(k, ""))
	return false


func _exec_with(prog: Array, i: int, end: int, indent: int) -> int:
	var header := _header(prog[i]["text"], "with")
	var body_end := _block_end(prog, i, end, indent)
	if not _err.is_empty():
		return end
	var name := ""
	var as_idx := header.rfind(" as ")
	if as_idx >= 0:
		name = header.substr(as_idx + 4).strip_edges()
		header = header.substr(0, as_idx).strip_edges()
		if not name.is_valid_identifier():
			_fail("SyntaxError", "después de 'as' va un nombre")
			return end
	var v: Variant = _eval(_parsed_expr(header))
	if not _err.is_empty():
		return end
	if name != "":
		_set_name(name, v)
	_exec_block(prog, i + 1, body_end, int(prog[i + 1]["indent"]))
	if v is PyFile:
		(v as PyFile).closed = true
	return body_end


# --- Sentencias simples -------------------------------------------------------------

func _exec(ast: Variant) -> void:
	if typeof(ast) != TYPE_DICTIONARY:
		return
	match str(ast["k"]):
		"assign":
			var v: Variant = _eval(ast["value"])
			if not _err.is_empty():
				return
			for t: Variant in ast["targets"]:
				_assign(t, v)
		"augassign":
			_exec_aug(ast)
		"return":
			if _scope == null:
				_fail("SyntaxError", "'return' fuera de una función")
				return
			var rv: Variant = _eval(ast["v"]) if ast["v"] != null else null
			if _err.is_empty():
				_ret = rv
				_flow = "return"
		"global":
			if _scope == null:
				return
			for n: String in ast["names"]:
				_scope.global_names[n] = true
				_scope.local_names.erase(n)
		"raise":
			_exec_raise(ast)
		"del":
			_del(ast["target"])
		"assert":
			var ok: Variant = _eval(ast["cond"])
			if _err.is_empty() and not truthy(ok):
				var msg := to_str(_eval(ast["msg"])) if ast["msg"] != null else ""
				_fail("AssertionError", msg)
		"import":
			_fail("ModuleNotFoundError", "en Pythoria no se importan módulos (%s): todo lo que necesitás ya está" % ast["module"])
		"pass":
			pass
		_:
			_eval(ast)


func _exec_raise(ast: Dictionary) -> void:
	if ast["v"] == null:
		if _handling.is_empty():
			_fail("RuntimeError", "No active exception to reraise")
			return
		var cur: PyExc = _handling.back()
		_fail(cur.kind, cur.text)
		return
	var v: Variant = _eval(ast["v"])
	if not _err.is_empty():
		return
	if v is PyBuiltin and _is_exc_name((v as PyBuiltin).name):
		_fail((v as PyBuiltin).name, "")
	elif v is PyExc:
		_fail((v as PyExc).kind, (v as PyExc).text)
	else:
		_fail("TypeError", "exceptions must derive from BaseException")


func _exec_aug(ast: Dictionary) -> void:
	var target: Dictionary = ast["target"]
	var obj: Variant = null
	var key: Variant = null
	var cur: Variant
	if target["k"] == "name":
		cur = _lookup(target["v"])
	else:
		obj = _eval(target["obj"])
		key = _eval(target["idx"])
		if not _err.is_empty():
			return
		cur = _getitem(obj, key)
	if not _err.is_empty():
		return
	var val: Variant = _eval(ast["value"])
	if not _err.is_empty():
		return
	var op: String = ast["op"]
	var nv: Variant
	if op == "+" and typeof(cur) == TYPE_ARRAY:
		# lista += algo modifica la misma lista (como extend).
		var extra: Variant = _iter(val)
		if not _err.is_empty():
			return
		(cur as Array).append_array(extra)
		nv = cur
	elif op == "|" and cur is PySet and val is PySet:
		(cur as PySet).data.merge((val as PySet).data)
		nv = cur
	else:
		nv = _binary(op, cur, val)
	if not _err.is_empty():
		return
	if target["k"] == "name":
		_set_name(target["v"], nv)
	else:
		_setitem(obj, key, nv)


func _set_name(name: String, v: Variant) -> void:
	if _scope != null and _scope.global_names.has(name):
		_globals[name] = v
	else:
		env[name] = v


func _assign(target: Variant, value: Variant) -> void:
	match str(target["k"]):
		"name":
			_set_name(target["v"], value)
		"index":
			var obj: Variant = _eval(target["obj"])
			var key: Variant = _eval(target["idx"])
			if _err.is_empty():
				_setitem(obj, key, value)
		"tuple", "list":
			var items: Array = target["items"]
			var values: Variant = _iter(value)
			if not _err.is_empty():
				_err = {}
				_fail("TypeError", "cannot unpack non-iterable %s object" % type_name(value))
				return
			if (values as Array).size() > items.size():
				_fail("ValueError", "too many values to unpack (expected %d)" % items.size())
				return
			if (values as Array).size() < items.size():
				_fail("ValueError", "not enough values to unpack (expected %d, got %d)" % [items.size(), (values as Array).size()])
				return
			for k in items.size():
				_assign(items[k], values[k])
				if not _err.is_empty():
					return
		_:
			_fail("SyntaxError", "no se puede asignar a eso")


func _del(target: Variant) -> void:
	match str(target["k"]):
		"name":
			var n: String = target["v"]
			if env.has(n):
				env.erase(n)
			elif _scope == null and _globals.has(n):
				_globals.erase(n)
			else:
				_fail("NameError", "name '%s' is not defined" % n)
		"index":
			var obj: Variant = _eval(target["obj"])
			var key: Variant = _eval(target["idx"])
			if not _err.is_empty():
				return
			if typeof(obj) == TYPE_ARRAY:
				var i: Variant = _norm_index(obj, key, "list assignment index out of range")
				if _err.is_empty():
					(obj as Array).remove_at(i)
			elif obj is PyDict:
				var hk := _key(key)
				if not _err.is_empty():
					return
				if not (obj as PyDict).data.has(hk):
					_fail("KeyError", repr(key))
					return
				(obj as PyDict).data.erase(hk)
			else:
				_fail("TypeError", "'%s' object doesn't support item deletion" % type_name(obj))
		"tuple", "list":
			for t: Variant in target["items"]:
				_del(t)


# --- Evaluación de expresiones -----------------------------------------------------

func _lookup(name: String) -> Variant:
	if env.has(name):
		return env[name]
	if _scope != null:
		if _scope.local_names.has(name):
			_fail("UnboundLocalError", "cannot access local variable '%s' where it is not associated with a value" % name)
			return null
		for c: Dictionary in _scope.closure:
			if c.has(name):
				return c[name]
		if _globals.has(name):
			return _globals[name]
	if name in BUILTINS or _is_exc_name(name):
		return PyBuiltin.new(name)
	_fail("NameError", "name '%s' is not defined" % name)
	return null


func _eval(node: Variant) -> Variant:
	if not _err.is_empty() or typeof(node) != TYPE_DICTIONARY:
		return null
	match str(node["k"]):
		"lit":
			return node["v"]
		"name":
			return _lookup(node["v"])
		"neg", "pos":
			var v: Variant = _eval(node["v"])
			if not _err.is_empty():
				return null
			if not _is_num(v):
				_fail("TypeError", "no se puede usar %s delante de un %s" % ["-" if node["k"] == "neg" else "+", type_name(v)])
				return null
			return -_num(v) if node["k"] == "neg" else _num(v)
		"fstr":
			var s := ""
			for p: Dictionary in node["parts"]:
				if p["k"] == "lit":
					s += p["v"]
				else:
					var pv: Variant = _eval(p["v"])
					if not _err.is_empty():
						return null
					s += format_spec(pv, str(p.get("spec", "")))
					if not _err.is_empty():
						return null
			return s
		"tuple":
			var titems := _eval_list(node["items"])
			return null if not _err.is_empty() else PyTuple.new(titems)
		"list":
			var litems := _eval_list(node["items"])
			return null if not _err.is_empty() else litems
		"set":
			var sitems := _eval_list(node["items"])
			if not _err.is_empty():
				return null
			return _make_set(sitems)
		"dict":
			var d := PyDict.new()
			for k in (node["keys"] as Array).size():
				var key: Variant = _eval(node["keys"][k])
				var val: Variant = _eval(node["values"][k])
				if not _err.is_empty():
					return null
				_dict_set(d, key, val)
				if not _err.is_empty():
					return null
			return d
		"comp":
			return _eval_comp(node)
		"lambda":
			var f := PyFunc.new()
			f.name = "<lambda>"
			f.params = node["params"]
			for p: String in node["params"]:
				f.local_names[p] = true
			for p: String in node["defaults"]:
				f.defaults[p] = _eval(node["defaults"][p])
			f.expr = node["body"]
			if _scope != null:
				f.closure = [env] + _scope.closure
			return f
		"ternary":
			var c: Variant = _eval(node["cond"])
			if not _err.is_empty():
				return null
			return _eval(node["a"]) if truthy(c) else _eval(node["b"])
		"call":
			var fn: Variant = _eval(node["fn"])
			var args := _eval_list(node["args"])
			var kwargs := _eval_kwargs(node["kwargs"])
			if not _err.is_empty():
				return null
			return _call_value(fn, args, kwargs)
		"method":
			var obj: Variant = _eval(node["obj"])
			var margs := _eval_list(node["args"])
			var mkwargs := _eval_kwargs(node.get("kwargs", {}))
			if not _err.is_empty():
				return null
			return _method(obj, node["name"], margs, mkwargs)
		"attr":
			var aobj: Variant = _eval(node["obj"])
			if not _err.is_empty():
				return null
			if node["name"] == "__name__" and (aobj is PyBuiltin or aobj is PyFunc):
				return (aobj as PyBuiltin).name if aobj is PyBuiltin else (aobj as PyFunc).name
			_fail("AttributeError", "'%s' object has no attribute '%s' (¿te faltaron los paréntesis?)" % [type_name(aobj), node["name"]])
			return null
		"index":
			var iobj: Variant = _eval(node["obj"])
			var idx: Variant = _eval(node["idx"])
			if not _err.is_empty():
				return null
			return _getitem(iobj, idx)
		"slice":
			var sobj: Variant = _eval(node["obj"])
			var lo: Variant = _eval(node["lo"]) if node["lo"] != null else null
			var hi: Variant = _eval(node["hi"]) if node["hi"] != null else null
			var st: Variant = _eval(node["step"]) if node["step"] != null else null
			if not _err.is_empty():
				return null
			return _slice(sobj, lo, hi, st)
		"star":
			_fail("SyntaxError", "el * para desarmar una lista solo va adentro de una llamada")
			return null
		"not":
			var nv: Variant = _eval(node["v"])
			return null if not _err.is_empty() else not truthy(nv)
		"and", "or":
			# Igual que Python: devuelve uno de los operandos y corta apenas sabe el resultado.
			var lv: Variant = _eval(node["l"])
			if not _err.is_empty():
				return null
			if truthy(lv) == (node["k"] == "or"):
				return lv
			return _eval(node["r"])
		"cmp":
			var left: Variant = _eval(node["operands"][0])
			for i in (node["ops"] as Array).size():
				var right: Variant = _eval(node["operands"][i + 1])
				if not _err.is_empty():
					return null
				var ok: Variant = _binary(node["ops"][i], left, right)
				if not _err.is_empty():
					return null
				if not ok:
					return false
				left = right
			return true
		"bin":
			var a: Variant = _eval(node["l"])
			var b: Variant = _eval(node["r"])
			if not _err.is_empty():
				return null
			return _binary(node["op"], a, b)
	return null


## Evalúa una lista de nodos; los *lista se desarman.
func _eval_list(nodes: Array) -> Array:
	var out: Array = []
	for n: Variant in nodes:
		if typeof(n) == TYPE_DICTIONARY and n.get("k") == "star":
			var v: Variant = _eval(n["v"])
			var vals: Variant = _iter(v)
			if not _err.is_empty():
				return []
			out.append_array(vals)
		else:
			out.append(_eval(n))
		if not _err.is_empty():
			return []
	return out


func _eval_kwargs(nodes: Dictionary) -> Dictionary:
	var out := {}
	for k: String in nodes:
		out[k] = _eval(nodes[k])
		if not _err.is_empty():
			return {}
	return out


func _eval_comp(node: Dictionary) -> Variant:
	var kind: String = node["kind"]
	var result: Variant
	match kind:
		"list":
			result = []
		"set":
			result = PySet.new()
		_:
			result = PyDict.new()
	# Las variables de la comprensión no quedan definidas afuera (como en Python 3).
	var names: Array = []
	for g: Dictionary in node["gens"]:
		_target_names(g["target"], names)
	var saved := {}
	for n: String in names:
		if env.has(n):
			saved[n] = env[n]
	_comp_loop(node, 0, result)
	for n: String in names:
		if saved.has(n):
			env[n] = saved[n]
		else:
			env.erase(n)
	return result if _err.is_empty() else null


func _target_names(t: Variant, out: Array) -> void:
	if typeof(t) != TYPE_DICTIONARY:
		return
	if t["k"] == "name":
		out.append(t["v"])
	elif t["k"] in ["tuple", "list"]:
		for x: Variant in t["items"]:
			_target_names(x, out)


func _comp_loop(node: Dictionary, gi: int, result: Variant) -> void:
	var gens: Array = node["gens"]
	if gi == gens.size():
		match str(node["kind"]):
			"list":
				var v: Variant = _eval(node["elt"])
				if _err.is_empty():
					(result as Array).append(v)
			"set":
				var sv: Variant = _eval(node["elt"])
				if _err.is_empty():
					_set_add(result, sv)
			_:
				var k: Variant = _eval(node["key"])
				var dv: Variant = _eval(node["val"])
				if _err.is_empty():
					_dict_set(result, k, dv)
		return
	var g: Dictionary = gens[gi]
	var values: Variant = _iter(_eval(g["iter"]))
	if not _err.is_empty():
		return
	for v: Variant in values:
		if not _step():
			return
		_assign(g["target"], v)
		if not _err.is_empty():
			return
		var ok := true
		for c: Variant in g["conds"]:
			var cv: Variant = _eval(c)
			if not _err.is_empty():
				return
			if not truthy(cv):
				ok = false
				break
		if ok:
			_comp_loop(node, gi + 1, result)
			if not _err.is_empty():
				return


# --- Llamadas ----------------------------------------------------------------------

func _call_value(fn: Variant, args: Array, kwargs: Dictionary) -> Variant:
	if fn is PyFunc:
		return _call_func(fn, args, kwargs)
	if fn is PyBuiltin:
		var n: String = (fn as PyBuiltin).name
		if _is_exc_name(n):
			var text := ""
			if args.size() == 1:
				text = repr(args[0]) if n == "KeyError" else to_str(args[0])
			elif args.size() > 1:
				text = repr(PyTuple.new(args))
			return PyExc.new(n, text)
		return _builtin(n, args, kwargs)
	_fail("TypeError", "'%s' object is not callable" % type_name(fn))
	return null


func _call_func(f: PyFunc, args: Array, kwargs: Dictionary) -> Variant:
	if _depth >= MAX_DEPTH:
		_fail("RecursionError", "maximum recursion depth exceeded (en Pythoria el límite es %d llamadas anidadas)" % MAX_DEPTH)
		return null
	if not _step():
		return null
	var locals := {}
	var n_params := f.params.size()
	if args.size() > n_params:
		var n_req := n_params - f.defaults.size()
		var takes := "%d positional argument%s" % [n_params, "" if n_params == 1 else "s"]
		if n_req < n_params:
			takes = "from %d to %d positional arguments" % [n_req, n_params]
		_fail("TypeError", "%s() takes %s but %d %s given" % [f.name, takes, args.size(), "was" if args.size() == 1 else "were"])
		return null
	for k in args.size():
		locals[f.params[k]] = args[k]
	for kw: String in kwargs:
		if not f.params.has(kw):
			_fail("TypeError", "%s() got an unexpected keyword argument '%s'" % [f.name, kw])
			return null
		if locals.has(kw):
			_fail("TypeError", "%s() got multiple values for argument '%s'" % [f.name, kw])
			return null
		locals[kw] = kwargs[kw]
	var missing: PackedStringArray = []
	for p: String in f.params:
		if not locals.has(p):
			if f.defaults.has(p):
				locals[p] = f.defaults[p]
			else:
				missing.append("'%s'" % p)
	if not missing.is_empty():
		var names := missing[0]
		if missing.size() > 1:
			names = ", ".join(missing.slice(0, missing.size() - 1)) + " and " + missing[missing.size() - 1]
		_fail("TypeError", "%s() missing %d required positional argument%s: %s" % [f.name, missing.size(), "" if missing.size() == 1 else "s", names])
		return null
	var saved_env := env
	var saved_scope := _scope
	var saved_loop := _loop_depth
	env = locals
	_scope = f
	_loop_depth = 0
	_depth += 1
	var result: Variant = null
	if f.expr != null:
		result = _eval(f.expr)
	else:
		_exec_block(f.prog, f.start, f.end, f.indent)
		if _flow == "return":
			result = _ret
		_flow = ""
		_ret = null
	env = saved_env
	_scope = saved_scope
	_loop_depth = saved_loop
	_depth -= 1
	return result if _err.is_empty() else null


## Llama a una función de usuario o incluida con un argumento (para key=).
func _call1(fn: Variant, x: Variant) -> Variant:
	return _call_value(fn, [x], {})


const BUILTIN_KWARGS := {
	"print": ["sep", "end"], "sorted": ["key", "reverse"], "max": ["key", "default"], "min": ["key", "default"],
	"enumerate": ["start"], "open": ["mode", "encoding"], "sum": ["start"],
}


func _builtin(name: String, args: Array, kwargs: Dictionary) -> Variant:
	if not kwargs.is_empty() and name != "dict":
		if not BUILTIN_KWARGS.has(name):
			_fail("TypeError", "%s() no acepta argumentos con nombre" % name)
			return null
		for k: String in kwargs:
			if not k in BUILTIN_KWARGS[name]:
				_fail("TypeError", "%s() no tiene el argumento '%s'" % [name, k])
				return null
	match name:
		"print":
			var texts: PackedStringArray = []
			for a: Variant in args:
				texts.append(to_str(a))
			var sep: Variant = kwargs.get("sep", " ")
			var end_: Variant = kwargs.get("end", "\n")
			output += (" " if sep == null else to_str(sep)).join(texts) + ("\n" if end_ == null else to_str(end_))
			return null
		"input":
			if args.size() > 1:
				_fail("TypeError", "input() recibe a lo sumo un mensaje")
				return null
			if inputs.is_empty():
				_fail("EOFError", "no hay más entradas para input()")
				return null
			return str(inputs.pop_front())
		"str":
			return to_str(args[0]) if args.size() > 0 else ""
		"bool":
			return truthy(args[0]) if args.size() > 0 else false
		"len":
			if args.size() != 1:
				_fail("TypeError", "len() recibe un argumento")
				return null
			return _len(args[0])
		"range":
			return _make_range(args)
		"sum":
			return _sum(args, kwargs)
		"int":
			return _to_int(args)
		"float":
			return _to_float(args)
		"abs":
			if args.size() != 1 or not _is_num(args[0]):
				_fail("TypeError", "abs() necesita un número")
				return null
			var av: Variant = _num(args[0])
			return absi(av) if typeof(av) == TYPE_INT else absf(av)
		"round":
			return _round(args)
		"max", "min":
			return _max_min(name, args, kwargs)
		"list":
			if args.is_empty():
				return []
			var lv: Variant = _iter(args[0])
			return lv if _err.is_empty() else null
		"tuple":
			if args.is_empty():
				return PyTuple.new([])
			var tv: Variant = _iter(args[0])
			return PyTuple.new(tv) if _err.is_empty() else null
		"set":
			if args.is_empty():
				return PySet.new()
			var sv: Variant = _iter(args[0])
			return _make_set(sv) if _err.is_empty() else null
		"dict":
			var d := PyDict.new()
			if args.size() == 1:
				if args[0] is PyDict:
					d.data = (args[0] as PyDict).data.duplicate(true)
				else:
					var pairs: Variant = _iter(args[0])
					if not _err.is_empty():
						return null
					for p: Variant in pairs:
						var kv: Variant = _iter(p)
						if not _err.is_empty() or (kv as Array).size() != 2:
							_err = {}
							_fail("ValueError", "dict() necesita pares (clave, valor)")
							return null
						_dict_set(d, kv[0], kv[1])
			for k: String in kwargs:
				_dict_set(d, k, kwargs[k])
			return d if _err.is_empty() else null
		"sorted":
			if args.size() != 1:
				_fail("TypeError", "sorted() recibe una sola colección")
				return null
			var items: Variant = _iter(args[0])
			if not _err.is_empty():
				return null
			return _sorted(items, kwargs.get("key"), truthy(kwargs.get("reverse", false)))
		"reversed":
			if args.size() != 1 or not type_name(args[0]) in ["list", "tuple", "str", "range"]:
				_fail("TypeError", "reversed() necesita una secuencia (lista, tupla, texto o range)")
				return null
			var rv: Variant = _iter(args[0])
			if not _err.is_empty():
				return null
			(rv as Array).reverse()
			return rv
		"enumerate":
			if args.size() != 1:
				_fail("TypeError", "enumerate() recibe una colección")
				return null
			var ev: Variant = _iter(args[0])
			if not _err.is_empty():
				return null
			var start: Variant = kwargs.get("start", 0)
			var eout: Array = []
			for k in (ev as Array).size():
				eout.append(PyTuple.new([int(_num(start)) + k, ev[k]]))
			return eout
		"zip":
			var lists: Array = []
			var shortest := -1
			for a: Variant in args:
				var zv: Variant = _iter(a)
				if not _err.is_empty():
					return null
				lists.append(zv)
				shortest = (zv as Array).size() if shortest < 0 else mini(shortest, (zv as Array).size())
			var zout: Array = []
			for k in maxi(shortest, 0):
				var row: Array = []
				for l: Array in lists:
					row.append(l[k])
				zout.append(PyTuple.new(row))
			return zout
		"map", "filter":
			if args.size() != 2:
				_fail("TypeError", "%s() recibe una función y una colección" % name)
				return null
			var mv: Variant = _iter(args[1])
			if not _err.is_empty():
				return null
			var mout: Array = []
			for x: Variant in mv:
				var r: Variant = x if args[0] == null else _call1(args[0], x)
				if not _err.is_empty():
					return null
				if name == "map":
					mout.append(r)
				elif truthy(r):
					mout.append(x)
			return mout
		"any", "all":
			if args.size() != 1:
				_fail("TypeError", "%s() recibe una colección" % name)
				return null
			var anyv: Variant = _iter(args[0])
			if not _err.is_empty():
				return null
			for x: Variant in anyv:
				if truthy(x) == (name == "any"):
					return name == "any"
			return name == "all"
		"chr":
			if args.size() != 1 or typeof(args[0]) != TYPE_INT:
				_fail("TypeError", "chr() necesita un entero")
				return null
			return String.chr(args[0])
		"ord":
			if args.size() != 1 or type_name(args[0]) != "str" or str(args[0]).length() != 1:
				_fail("TypeError", "ord() necesita un solo carácter")
				return null
			return str(args[0]).unicode_at(0)
		"isinstance":
			if args.size() != 2:
				_fail("TypeError", "isinstance() recibe un valor y un tipo")
				return null
			var types: Array = (args[1] as PyTuple).items if args[1] is PyTuple else [args[1]]
			for t: Variant in types:
				if not t is PyBuiltin:
					_fail("TypeError", "isinstance() arg 2 must be a type or tuple of types")
					return null
				if _is_instance(args[0], (t as PyBuiltin).name):
					return true
			return false
		"repr":
			if args.size() != 1:
				_fail("TypeError", "repr() recibe un argumento")
				return null
			return repr(args[0])
		"type":
			if args.size() != 1:
				_fail("TypeError", "type() recibe un argumento")
				return null
			return PyBuiltin.new(type_name(args[0]))
		"open":
			return _open(args, kwargs)
	return null


static func _is_instance(v: Variant, t: String) -> bool:
	var tn := type_name(v)
	if tn == t or (t == "int" and tn == "bool"):
		return true
	if v is PyExc:
		var k: String = (v as PyExc).kind
		while k != "":
			if k == t:
				return true
			k = str(EXC_PARENTS.get(k, ""))
	return false


func _len(v: Variant) -> Variant:
	match type_name(v):
		"str":
			return str(v).length()
		"list":
			return (v as Array).size()
		"tuple":
			return (v as PyTuple).items.size()
		"dict":
			return (v as PyDict).data.size()
		"set":
			return (v as PySet).data.size()
		"range":
			return _range_len(v)
	_fail("TypeError", "object of type '%s' has no len()" % type_name(v))
	return null


func _make_range(args: Array) -> Variant:
	if args.is_empty() or args.size() > 3:
		_fail("TypeError", "range() recibe de 1 a 3 números enteros")
		return null
	for a: Variant in args:
		if typeof(a) not in [TYPE_INT, TYPE_BOOL]:
			_fail("TypeError", "'%s' object cannot be interpreted as an integer" % type_name(a))
			return null
	var nums: Array = []
	for a: Variant in args:
		nums.append(int(_num(a)))
	var r := {"__range__": true, "start": 0, "stop": nums[0], "step": 1}
	if nums.size() >= 2:
		r["start"] = nums[0]
		r["stop"] = nums[1]
	if nums.size() == 3:
		if nums[2] == 0:
			_fail("ValueError", "range() arg 3 must not be zero")
			return null
		r["step"] = nums[2]
	return r


func _sum(args: Array, kwargs: Dictionary) -> Variant:
	if args.is_empty() or args.size() > 2:
		_fail("TypeError", "sum() recibe una colección (y opcionalmente un inicio)")
		return null
	var total: Variant = args[1] if args.size() == 2 else kwargs.get("start", 0)
	if type_name(total) == "str":
		_fail("TypeError", "sum() can't sum strings [use ''.join(seq) instead]")
		return null
	if type_name(args[0]) == "range" and typeof(total) == TYPE_INT:
		var rg: Dictionary = args[0]
		var n := _range_len(rg)
		# Suma aritmética: n términos desde start con paso step.
		return total + n * int(rg["start"]) + int(rg["step"]) * n * (n - 1) / 2
	var values: Variant = _iter(args[0])
	if not _err.is_empty():
		return null
	for v: Variant in values:
		total = _binary("+", total, v)
		if not _err.is_empty():
			return null
	return total


func _to_int(args: Array) -> Variant:
	if args.is_empty():
		return 0
	var x: Variant = args[0]
	if _is_num(x):
		return int(_num(x))
	if type_name(x) == "str":
		var s := str(x).strip_edges().replace("_", "")
		if s.is_valid_int() and not s.contains("."):
			return s.to_int()
		_fail("ValueError", "invalid literal for int() with base 10: %s" % repr(x))
		return null
	_fail("TypeError", "int() argument must be a string or a number, not '%s'" % type_name(x))
	return null


func _to_float(args: Array) -> Variant:
	if args.is_empty():
		return 0.0
	var y: Variant = args[0]
	if _is_num(y):
		return float(_num(y))
	if type_name(y) == "str":
		var s := str(y).strip_edges()
		if s.is_valid_float():
			return s.to_float()
		_fail("ValueError", "could not convert string to float: %s" % repr(y))
		return null
	_fail("TypeError", "float() argument must be a string or a number, not '%s'" % type_name(y))
	return null


func _max_min(name: String, args: Array, kwargs: Dictionary) -> Variant:
	var values: Variant
	if args.size() == 1:
		values = _iter(args[0])
		if not _err.is_empty():
			return null
	elif args.size() >= 2:
		values = args
	else:
		_fail("TypeError", "%s() necesita al menos un valor" % name)
		return null
	if (values as Array).is_empty():
		if kwargs.has("default"):
			return kwargs["default"]
		_fail("ValueError", "%s() arg is an empty sequence" % name)
		return null
	var key_fn: Variant = kwargs.get("key")
	var best: Variant = values[0]
	var best_key: Variant = best if key_fn == null else _call1(key_fn, best)
	for v: Variant in (values as Array).slice(1):
		var k: Variant = v if key_fn == null else _call1(key_fn, v)
		if not _err.is_empty():
			return null
		var better: Variant = _binary(">" if name == "max" else "<", k, best_key)
		if not _err.is_empty():
			return null
		if better:
			best = v
			best_key = k
	return best


static func _range_len(r: Dictionary) -> int:
	var start: int = r["start"]
	var stop: int = r["stop"]
	var step: int = r["step"]
	if step > 0:
		return maxi(0, ceili(float(stop - start) / step))
	return maxi(0, ceili(float(start - stop) / -step))


## round(x) redondea al par más cercano como Python (round(2.5) == 2); round(x, n) da float.
func _round(args: Array) -> Variant:
	if args.is_empty() or args.size() > 2 or not _is_num(args[0]):
		_fail("TypeError", "round() necesita un número")
		return null
	var x := float(_num(args[0]))
	if args.size() == 2:
		if typeof(args[1]) != TYPE_INT:
			_fail("TypeError", "la cantidad de decimales de round() tiene que ser int")
			return null
		var r := ("%." + str(maxi(0, args[1])) + "f") % x
		return r.to_float() if typeof(_num(args[0])) == TYPE_FLOAT else int(r.to_float())
	var f := floorf(x)
	var diff := x - f
	var n := int(f)
	if diff > 0.5 or (diff == 0.5 and n % 2 != 0):
		n += 1
	return n


## Ordena de forma estable (como Python) con key y reverse opcionales.
func _sorted(items: Array, key_fn: Variant, reverse: bool) -> Variant:
	var keys: Array = []
	for x: Variant in items:
		keys.append(x if key_fn == null else _call1(key_fn, x))
		if not _err.is_empty():
			return null
	var order: Array = range(items.size())
	order = _merge_sort(order, keys, reverse)
	if not _err.is_empty():
		return null
	var out: Array = []
	for k: int in order:
		out.append(items[k])
	return out


func _merge_sort(idx: Array, keys: Array, reverse: bool) -> Array:
	if idx.size() <= 1 or not _err.is_empty():
		return idx
	var mid := idx.size() / 2
	var left := _merge_sort(idx.slice(0, mid), keys, reverse)
	var right := _merge_sort(idx.slice(mid), keys, reverse)
	var out: Array = []
	var a := 0
	var b := 0
	while a < left.size() and b < right.size():
		var lk: Variant = keys[left[a]]
		var rk: Variant = keys[right[b]]
		# Se toma el de la derecha solo si es estrictamente menor: así es estable.
		var take_right: Variant = _binary("<", lk, rk) if reverse else _binary("<", rk, lk)
		if not _err.is_empty():
			return idx
		if take_right:
			out.append(right[b])
			b += 1
		else:
			out.append(left[a])
			a += 1
	out.append_array(left.slice(a))
	out.append_array(right.slice(b))
	return out


# --- Colecciones -------------------------------------------------------------------

## Valores de algo que se puede recorrer (copia).
func _iter(v: Variant) -> Variant:
	match type_name(v):
		"list":
			return (v as Array).duplicate()
		"tuple":
			return (v as PyTuple).items.duplicate()
		"str":
			var chars: Array = []
			for ch in str(v):
				chars.append(ch)
			return chars
		"dict":
			var keys: Array = []
			for e: Array in (v as PyDict).data.values():
				keys.append(e[0])
			return keys
		"set":
			return (v as PySet).data.values()
		"range":
			var n := _range_len(v)
			if n > MAX_STEPS * 10:
				_fail("BucleInfinito", "ese range es demasiado grande para el hechizo")
				return null
			var out: Array = []
			var x: int = v["start"]
			for _k in n:
				out.append(x)
				x += int(v["step"])
			return out
		"TextIOWrapper":
			var lines: Variant = _file_lines(v)
			return lines
	_fail("TypeError", "'%s' object is not iterable" % type_name(v))
	return null


func _key(k: Variant) -> String:
	var hk := hash_key(k)
	if hk == "":
		_fail("TypeError", "unhashable type: '%s'" % type_name(k))
	return hk


func _dict_set(d: PyDict, k: Variant, v: Variant) -> void:
	var hk := _key(k)
	if hk == "":
		return
	if d.data.has(hk):
		d.data[hk][1] = v
	else:
		d.data[hk] = [k, v]


func _set_add(s: PySet, v: Variant) -> void:
	var hk := _key(v)
	if hk != "" and not s.data.has(hk):
		s.data[hk] = v


func _make_set(values: Array) -> Variant:
	var s := PySet.new()
	for v: Variant in values:
		_set_add(s, v)
		if not _err.is_empty():
			return null
	return s


## Índice entero normalizado (negativos desde el final) o error.
func _norm_index(seq: Variant, i: Variant, msg: String) -> Variant:
	if typeof(i) not in [TYPE_INT, TYPE_BOOL]:
		_fail("TypeError", "%s indices must be integers or slices, not %s" % [type_name(seq), type_name(i)])
		return null
	var n: int = _len(seq)
	var k := int(_num(i))
	if k < 0:
		k += n
	if k < 0 or k >= n:
		_fail("IndexError", msg)
		return null
	return k


func _getitem(obj: Variant, key: Variant) -> Variant:
	match type_name(obj):
		"list":
			var i: Variant = _norm_index(obj, key, "list index out of range")
			return null if i == null else obj[i]
		"tuple":
			var ti: Variant = _norm_index(obj, key, "tuple index out of range")
			return null if ti == null else (obj as PyTuple).items[ti]
		"str":
			var si: Variant = _norm_index(obj, key, "string index out of range")
			return null if si == null else str(obj)[si]
		"range":
			var ri: Variant = _norm_index(obj, key, "range object index out of range")
			return null if ri == null else int(obj["start"]) + int(ri) * int(obj["step"])
		"dict":
			var hk := _key(key)
			if hk == "":
				return null
			var d: Dictionary = (obj as PyDict).data
			if not d.has(hk):
				_fail("KeyError", repr(key))
				return null
			return d[hk][1]
	_fail("TypeError", "'%s' object is not subscriptable" % type_name(obj))
	return null


func _setitem(obj: Variant, key: Variant, value: Variant) -> void:
	match type_name(obj):
		"list":
			var i: Variant = _norm_index(obj, key, "list assignment index out of range")
			if i != null:
				obj[i] = value
		"dict":
			_dict_set(obj, key, value)
		_:
			_fail("TypeError", "'%s' object does not support item assignment" % type_name(obj))


## seq[lo:hi:step] con las reglas de Python (los bordes se recortan, no dan error).
func _slice(obj: Variant, lo: Variant, hi: Variant, step: Variant) -> Variant:
	var tn := type_name(obj)
	if not tn in ["list", "tuple", "str", "range"]:
		_fail("TypeError", "'%s' object is not subscriptable" % tn)
		return null
	for x: Variant in [lo, hi, step]:
		if x != null and typeof(x) not in [TYPE_INT, TYPE_BOOL]:
			_fail("TypeError", "slice indices must be integers or None")
			return null
	var st := 1 if step == null else int(_num(step))
	if st == 0:
		_fail("ValueError", "slice step cannot be zero")
		return null
	var items: Variant = _iter(obj)
	var n: int = (items as Array).size()
	var a: int
	var b: int
	if st > 0:
		a = 0 if lo == null else int(_num(lo))
		b = n if hi == null else int(_num(hi))
		if a < 0:
			a = maxi(a + n, 0)
		if b < 0:
			b = maxi(b + n, 0)
		a = mini(a, n)
		b = mini(b, n)
	else:
		a = n - 1 if lo == null else int(_num(lo))
		b = -1 if hi == null else int(_num(hi))
		if lo != null:
			if a < 0:
				a = maxi(a + n, -1)
			a = mini(a, n - 1)
		if hi != null:
			if b < 0:
				b = maxi(b + n, -1)
			b = mini(b, n - 1)
	var out: Array = []
	var k := a
	while (st > 0 and k < b) or (st < 0 and k > b):
		out.append(items[k])
		k += st
	match tn:
		"str":
			return "".join(PackedStringArray(out))
		"tuple":
			return PyTuple.new(out)
	return out


# --- Archivos ----------------------------------------------------------------------

func _open(args: Array, kwargs: Dictionary) -> Variant:
	if args.is_empty() or type_name(args[0]) != "str":
		_fail("TypeError", "open() necesita el nombre del archivo como texto")
		return null
	var fname := str(args[0])
	var mode := str(args[1]) if args.size() > 1 else str(kwargs.get("mode", "r"))
	mode = mode.replace("t", "")
	if not mode in ["r", "w", "a"]:
		_fail("ValueError", "invalid mode: '%s'" % mode)
		return null
	if mode == "r" and not files.has(fname):
		_fail("FileNotFoundError", "[Errno 2] No such file or directory: %s" % repr(fname))
		return null
	if mode == "w":
		files[fname] = ""
	elif mode == "a" and not files.has(fname):
		files[fname] = ""
	var f := PyFile.new()
	f.name = fname
	f.mode = mode
	return f


func _file_lines(f: PyFile) -> Variant:
	if not _file_can(f, "r"):
		return null
	var text: String = str(files.get(f.name, "")).substr(f.pos)
	f.pos += text.length()
	var out: Array = []
	var start := 0
	while start < text.length():
		var nl := text.find("\n", start)
		if nl < 0:
			out.append(text.substr(start))
			break
		out.append(text.substr(start, nl - start + 1))
		start = nl + 1
	return out


func _file_can(f: PyFile, need: String) -> bool:
	if f.closed:
		_fail("ValueError", "I/O operation on closed file.")
		return false
	if need == "r" and f.mode != "r":
		_fail("UnsupportedOperation", "not readable")
		return false
	if need == "w" and f.mode == "r":
		_fail("UnsupportedOperation", "not writable")
		return false
	return true


# --- Métodos -----------------------------------------------------------------------

func _method(obj: Variant, name: String, args: Array, kwargs: Dictionary) -> Variant:
	var tn := type_name(obj)
	if tn == "str" and name == "format":
		return _str_format(str(obj), args, kwargs)
	if not kwargs.is_empty() and not (tn == "list" and name == "sort"):
		_fail("TypeError", "%s() no acepta argumentos con nombre" % name)
		return null
	match tn:
		"str":
			return _str_method(str(obj), name, args)
		"list":
			return _list_method(obj, name, args, kwargs)
		"tuple":
			match name:
				"count", "index":
					return _seq_count_index((obj as PyTuple).items, name, args, "tuple")
		"dict":
			return _dict_method(obj, name, args)
		"set":
			return _set_method(obj, name, args)
		"TextIOWrapper":
			return _file_method(obj, name, args)
	_fail("AttributeError", "'%s' object has no attribute '%s'" % [tn, name])
	return null


func _need_args(name: String, args: Array, lo: int, hi: int) -> bool:
	if args.size() < lo or args.size() > hi:
		if lo == hi:
			_fail("TypeError", "%s() recibe %d argumento(s)" % [name, lo])
		else:
			_fail("TypeError", "%s() recibe entre %d y %d argumentos" % [name, lo, hi])
		return false
	return true


func _need_str_args(name: String, args: Array) -> bool:
	for a: Variant in args:
		if type_name(a) != "str":
			_fail("TypeError", "%s() necesita textos como argumentos" % name)
			return false
	return true


const STR_ARITY := {
	"upper": [0, 0], "lower": [0, 0], "title": [0, 0], "capitalize": [0, 0], "swapcase": [0, 0],
	"strip": [0, 1], "lstrip": [0, 1], "rstrip": [0, 1], "replace": [2, 2], "count": [1, 1],
	"startswith": [1, 1], "endswith": [1, 1], "isdigit": [0, 0], "isalpha": [0, 0], "isalnum": [0, 0],
	"isspace": [0, 0], "isupper": [0, 0], "islower": [0, 0], "find": [1, 1], "rfind": [1, 1], "index": [1, 1],
	"split": [0, 1], "join": [1, 1], "center": [1, 1], "ljust": [1, 1], "rjust": [1, 1], "zfill": [1, 1],
}


func _str_method(s: String, name: String, args: Array) -> Variant:
	if not STR_ARITY.has(name):
		_fail("AttributeError", "'str' object has no attribute '%s'" % name)
		return null
	if not _need_args(name, args, STR_ARITY[name][0], STR_ARITY[name][1]):
		return null
	if name in ["center", "ljust", "rjust", "zfill"]:
		if typeof(args[0]) != TYPE_INT:
			_fail("TypeError", "%s() necesita un ancho entero" % name)
			return null
		var w: int = args[0]
		var pad := maxi(0, w - s.length())
		match name:
			"center":
				return _center(s, w)
			"ljust":
				return s + " ".repeat(pad)
			"rjust":
				return " ".repeat(pad) + s
			"zfill":
				if s.begins_with("-") or s.begins_with("+"):
					return s[0] + "0".repeat(pad) + s.substr(1)
				return "0".repeat(pad) + s
	if name == "join":
		var parts: Variant = _iter(args[0])
		if not _err.is_empty():
			return null
		for k in (parts as Array).size():
			if type_name(parts[k]) != "str":
				_fail("TypeError", "sequence item %d: expected str instance, %s found" % [k, type_name(parts[k])])
				return null
		return s.join(PackedStringArray(parts))
	if args.size() > 0 and args[0] != null and not _need_str_args(name, args):
		return null
	match name:
		"upper":
			return s.to_upper()
		"lower":
			return s.to_lower()
		"swapcase":
			var sw := ""
			for ch in s:
				sw += ch.to_lower() if ch != ch.to_lower() else ch.to_upper()
			return sw
		"strip", "lstrip", "rstrip":
			if args.is_empty() or args[0] == null:
				return s.strip_edges(name != "rstrip", name != "lstrip")
			var chars: String = args[0]
			var a := 0
			var b := s.length()
			if name != "rstrip":
				while a < b and chars.contains(s[a]):
					a += 1
			if name != "lstrip":
				while b > a and chars.contains(s[b - 1]):
					b -= 1
			return s.substr(a, b - a)
		"title":
			var out := ""
			var prev_letter := false
			for ch in s:
				var is_letter := ch.to_lower() != ch.to_upper()
				out += (ch.to_lower() if prev_letter else ch.to_upper()) if is_letter else ch
				prev_letter = is_letter
			return out
		"capitalize":
			return s.substr(0, 1).to_upper() + s.substr(1).to_lower()
		"replace":
			return s.replace(args[0], args[1])
		"count":
			return s.count(args[0]) if args[0] != "" else s.length() + 1
		"startswith":
			return s.begins_with(args[0])
		"endswith":
			return s.ends_with(args[0])
		"isdigit":
			if s == "":
				return false
			for ch in s:
				if not ch in "0123456789":
					return false
			return true
		"isalpha", "isalnum":
			if s == "":
				return false
			for ch in s:
				var letter := ch.to_lower() != ch.to_upper()
				if not (letter or (name == "isalnum" and ch in "0123456789")):
					return false
			return true
		"isspace":
			return s != "" and s.strip_edges() == ""
		"isupper", "islower":
			var has_letter := false
			for ch in s:
				if ch.to_lower() != ch.to_upper():
					has_letter = true
					if (name == "isupper" and ch != ch.to_upper()) or (name == "islower" and ch != ch.to_lower()):
						return false
			return has_letter
		"find":
			return s.find(args[0])
		"rfind":
			return s.rfind(args[0])
		"index":
			var at := s.find(args[0])
			if at < 0:
				_fail("ValueError", "substring not found")
				return null
			return at
		"split":
			if args.is_empty() or args[0] == null:
				var words: Array = []
				for w: String in s.replace("\t", " ").replace("\n", " ").split(" ", false):
					words.append(w)
				return words
			if args[0] == "":
				_fail("ValueError", "empty separator")
				return null
			return Array(s.split(args[0]))
	return null


## "{} tiene {:.1f}".format(a, b), con {0}, {nombre} y formato.
func _str_format(s: String, args: Array, kwargs: Dictionary) -> Variant:
	var out := ""
	var auto := 0
	var i := 0
	while i < s.length():
		var c := s[i]
		if c == "{" and i + 1 < s.length() and s[i + 1] == "{":
			out += "{"
			i += 2
			continue
		if c == "}" and i + 1 < s.length() and s[i + 1] == "}":
			out += "}"
			i += 2
			continue
		if c == "{":
			var close := s.find("}", i)
			if close < 0:
				_fail("ValueError", "Single '{' encountered in format string")
				return null
			var field := s.substr(i + 1, close - i - 1)
			var spec := ""
			var colon := field.find(":")
			if colon >= 0:
				spec = field.substr(colon + 1)
				field = field.substr(0, colon)
			var v: Variant
			if field == "":
				if auto >= args.size():
					_fail("IndexError", "Replacement index %d out of range for positional args tuple" % auto)
					return null
				v = args[auto]
				auto += 1
			elif field.is_valid_int():
				if field.to_int() >= args.size():
					_fail("IndexError", "Replacement index %s out of range for positional args tuple" % field)
					return null
				v = args[field.to_int()]
			elif kwargs.has(field):
				v = kwargs[field]
			else:
				_fail("KeyError", repr(field))
				return null
			out += format_spec(v, spec)
			if not _err.is_empty():
				return null
			i = close + 1
			continue
		out += c
		i += 1
	return out


static func _center(s: String, w: int) -> String:
	var pad := w - s.length()
	if pad <= 0:
		return s
	# Como CPython: el espacio extra va a la derecha salvo que el ancho sea impar y el largo par.
	var left := pad / 2 + (pad & w & 1)
	return " ".repeat(left) + s + " ".repeat(pad - left)


func _seq_count_index(items: Array, name: String, args: Array, tn: String) -> Variant:
	if not _need_args(name, args, 1, 1):
		return null
	if name == "count":
		var c := 0
		for x: Variant in items:
			if py_equal(x, args[0]):
				c += 1
		return c
	for k in items.size():
		if py_equal(items[k], args[0]):
			return k
	if tn == "list":
		_fail("ValueError", "%s is not in list" % repr(args[0]))
	else:
		_fail("ValueError", "tuple.index(x): x not in tuple")
	return null


func _list_method(lst: Array, name: String, args: Array, kwargs: Dictionary) -> Variant:
	match name:
		"append":
			if _need_args(name, args, 1, 1):
				lst.append(args[0])
			return null
		"extend":
			if _need_args(name, args, 1, 1):
				var more: Variant = _iter(args[0])
				if _err.is_empty():
					lst.append_array(more)
			return null
		"insert":
			if not _need_args(name, args, 2, 2):
				return null
			if typeof(args[0]) not in [TYPE_INT, TYPE_BOOL]:
				_fail("TypeError", "insert() necesita una posición entera")
				return null
			var at := int(_num(args[0]))
			if at < 0:
				at = maxi(0, at + lst.size())
			lst.insert(mini(at, lst.size()), args[1])
			return null
		"pop":
			if not _need_args(name, args, 0, 1):
				return null
			if lst.is_empty():
				_fail("IndexError", "pop from empty list")
				return null
			var i: Variant = lst.size() - 1 if args.is_empty() else _norm_index(lst, args[0], "pop index out of range")
			if i == null:
				return null
			var v: Variant = lst[i]
			lst.remove_at(i)
			return v
		"remove":
			if not _need_args(name, args, 1, 1):
				return null
			for k in lst.size():
				if py_equal(lst[k], args[0]):
					lst.remove_at(k)
					return null
			_fail("ValueError", "list.remove(x): x not in list")
			return null
		"index", "count":
			return _seq_count_index(lst, name, args, "list")
		"sort":
			if not _need_args(name, args, 0, 0):
				return null
			for k: String in kwargs:
				if not k in ["key", "reverse"]:
					_fail("TypeError", "sort() no tiene el argumento '%s'" % k)
					return null
			var sorted_v: Variant = _sorted(lst, kwargs.get("key"), truthy(kwargs.get("reverse", false)))
			if _err.is_empty():
				lst.assign(sorted_v)
			return null
		"reverse":
			if _need_args(name, args, 0, 0):
				lst.reverse()
			return null
		"copy":
			return lst.duplicate() if _need_args(name, args, 0, 0) else null
		"clear":
			if _need_args(name, args, 0, 0):
				lst.clear()
			return null
	_fail("AttributeError", "'list' object has no attribute '%s'" % name)
	return null


func _dict_method(d: PyDict, name: String, args: Array) -> Variant:
	match name:
		"get":
			if not _need_args(name, args, 1, 2):
				return null
			var hk := _key(args[0])
			if hk == "":
				return null
			if d.data.has(hk):
				return d.data[hk][1]
			return args[1] if args.size() == 2 else null
		"keys", "values", "items":
			if not _need_args(name, args, 0, 0):
				return null
			var out: Array = []
			for e: Array in d.data.values():
				if name == "keys":
					out.append(e[0])
				elif name == "values":
					out.append(e[1])
				else:
					out.append(PyTuple.new([e[0], e[1]]))
			return out
		"pop":
			if not _need_args(name, args, 1, 2):
				return null
			var phk := _key(args[0])
			if phk == "":
				return null
			if d.data.has(phk):
				var v: Variant = d.data[phk][1]
				d.data.erase(phk)
				return v
			if args.size() == 2:
				return args[1]
			_fail("KeyError", repr(args[0]))
			return null
		"setdefault":
			if not _need_args(name, args, 1, 2):
				return null
			var shk := _key(args[0])
			if shk == "":
				return null
			if not d.data.has(shk):
				d.data[shk] = [args[0], args[1] if args.size() == 2 else null]
			return d.data[shk][1]
		"update":
			if not _need_args(name, args, 1, 1):
				return null
			if not args[0] is PyDict:
				_fail("TypeError", "update() necesita otro diccionario")
				return null
			for e: Array in (args[0] as PyDict).data.values():
				_dict_set(d, e[0], e[1])
			return null
		"copy":
			var c := PyDict.new()
			c.data = d.data.duplicate(true)
			for hk: String in c.data:
				c.data[hk][1] = d.data[hk][1]
			return c
		"clear":
			d.data.clear()
			return null
	_fail("AttributeError", "'dict' object has no attribute '%s'" % name)
	return null


func _set_method(s: PySet, name: String, args: Array) -> Variant:
	match name:
		"add":
			if _need_args(name, args, 1, 1):
				_set_add(s, args[0])
			return null
		"remove", "discard":
			if not _need_args(name, args, 1, 1):
				return null
			var hk := _key(args[0])
			if hk == "":
				return null
			if s.data.has(hk):
				s.data.erase(hk)
			elif name == "remove":
				_fail("KeyError", repr(args[0]))
			return null
		"union", "intersection", "difference", "symmetric_difference":
			if not _need_args(name, args, 1, 1):
				return null
			var other: Variant = _make_set(_iter(args[0])) if _err.is_empty() else null
			if not _err.is_empty():
				return null
			var op: String = {"union": "|", "intersection": "&", "difference": "-", "symmetric_difference": "^"}[name]
			return _binary(op, s, other)
		"issubset", "issuperset":
			if not _need_args(name, args, 1, 1):
				return null
			var o: Variant = _make_set(_iter(args[0])) if _err.is_empty() else null
			if not _err.is_empty():
				return null
			var small: PySet = s if name == "issubset" else o
			var big: PySet = o if name == "issubset" else s
			for hk2: String in small.data:
				if not big.data.has(hk2):
					return false
			return true
		"copy":
			var c := PySet.new()
			c.data = s.data.duplicate()
			return c
		"clear":
			s.data.clear()
			return null
		"pop":
			if s.data.is_empty():
				_fail("KeyError", "'pop from an empty set'")
				return null
			var first: String = s.data.keys()[0]
			var v: Variant = s.data[first]
			s.data.erase(first)
			return v
	_fail("AttributeError", "'set' object has no attribute '%s'" % name)
	return null


func _file_method(f: PyFile, name: String, args: Array) -> Variant:
	match name:
		"read":
			if not _file_can(f, "r"):
				return null
			var text: String = str(files.get(f.name, "")).substr(f.pos)
			f.pos += text.length()
			return text
		"readline":
			if not _file_can(f, "r"):
				return null
			var all_text: String = str(files.get(f.name, ""))
			var nl := all_text.find("\n", f.pos)
			var line := all_text.substr(f.pos) if nl < 0 else all_text.substr(f.pos, nl - f.pos + 1)
			f.pos += line.length()
			return line
		"readlines":
			return _file_lines(f)
		"write":
			if not _file_can(f, "w") or not _need_args(name, args, 1, 1):
				return null
			if type_name(args[0]) != "str":
				_fail("TypeError", "write() argument must be str, not %s" % type_name(args[0]))
				return null
			files[f.name] = str(files.get(f.name, "")) + str(args[0])
			return str(args[0]).length()
		"close":
			f.closed = true
			return null
	_fail("AttributeError", "'_io.TextIOWrapper' object has no attribute '%s'" % name)
	return null


# --- Operadores --------------------------------------------------------------------

## `item in container` para textos, listas, tuplas, dicts, sets y range.
func _contains(container: Variant, item: Variant) -> Variant:
	match type_name(container):
		"str":
			if type_name(item) != "str":
				_fail("TypeError", "'in <string>' requires string as left operand, not %s" % type_name(item))
				return null
			return str(container).contains(item)
		"list":
			for x: Variant in container:
				if py_equal(x, item):
					return true
			return false
		"tuple":
			for x: Variant in (container as PyTuple).items:
				if py_equal(x, item):
					return true
			return false
		"dict":
			var hk := _key(item)
			return null if hk == "" else (container as PyDict).data.has(hk)
		"set":
			var shk := _key(item)
			return null if shk == "" else (container as PySet).data.has(shk)
		"range":
			if not _is_num(item) or float(_num(item)) != floorf(float(_num(item))):
				return false
			var x := int(_num(item))
			var r: Dictionary = container
			var st: int = r["step"]
			var inside: bool = (st > 0 and x >= r["start"] and x < r["stop"]) or (st < 0 and x <= r["start"] and x > r["stop"])
			return inside and (x - int(r["start"])) % st == 0
	_fail("TypeError", "argument of type '%s' is not iterable" % type_name(container))
	return null


static func _identical(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_OBJECT or typeof(b) == TYPE_OBJECT or typeof(a) == TYPE_ARRAY or typeof(b) == TYPE_ARRAY:
		return typeof(a) == typeof(b) and is_same(a, b)
	if a == null or b == null:
		return a == null and b == null
	return type_name(a) == type_name(b) and py_equal(a, b)


const VERBS := {"+": "sumar", "-": "restar", "*": "multiplicar", "/": "dividir", "//": "dividir", "%": "dividir", "**": "elevar",
	"<": "comparar", ">": "comparar", "<=": "comparar", ">=": "comparar", "|": "unir con |", "&": "cruzar con &", "^": "operar con ^"}


## Compara a con b: -1, 0 o 1 (null si no se pueden comparar).
func _cmp(a: Variant, b: Variant, op: String) -> Variant:
	if _is_num(a) and _is_num(b):
		var x: Variant = _num(a)
		var y: Variant = _num(b)
		return -1 if x < y else (1 if x > y else 0)
	var ta := type_name(a)
	if ta == "str" and type_name(b) == "str":
		var sa := str(a)
		var sb := str(b)
		return -1 if sa < sb else (1 if sa > sb else 0)
	if (ta == "list" and type_name(b) == "list") or (ta == "tuple" and type_name(b) == "tuple"):
		var la: Array = a if ta == "list" else (a as PyTuple).items
		var lb: Array = b if ta == "list" else (b as PyTuple).items
		for k in mini(la.size(), lb.size()):
			if not py_equal(la[k], lb[k]):
				return _cmp(la[k], lb[k], op)
		return -1 if la.size() < lb.size() else (1 if la.size() > lb.size() else 0)
	_fail("TypeError", "no se puede comparar %s y %s con %s" % [type_name(a), type_name(b), op])
	return null


func _binary(op: String, a: Variant, b: Variant) -> Variant:
	match op:
		"==":
			return py_equal(a, b)
		"!=":
			return not py_equal(a, b)
		"is":
			return _identical(a, b)
		"is not":
			return not _identical(a, b)
		"in", "not in":
			var found: Variant = _contains(b, a)
			if not _err.is_empty():
				return null
			return found if op == "in" else not found
		"<", ">", "<=", ">=":
			if a is PySet and b is PySet and op in ["<=", ">="]:
				var small: PySet = a if op == "<=" else b
				var big: PySet = b if op == "<=" else a
				for hk: String in small.data:
					if not big.data.has(hk):
						return false
				return true
			var c: Variant = _cmp(a, b, op)
			if c == null:
				return null
			match op:
				"<":
					return c < 0
				">":
					return c > 0
				"<=":
					return c <= 0
			return c >= 0
	var na := _is_num(a)
	var nb := _is_num(b)
	if na and nb:
		var x: Variant = _num(a)
		var y: Variant = _num(b)
		match op:
			"+":
				return x + y
			"-":
				return x - y
			"*":
				return x * y
			"/":
				if float(y) == 0.0:
					_fail("ZeroDivisionError", "division by zero")
					return null
				return float(x) / float(y)
			"**":
				if typeof(x) == TYPE_INT and typeof(y) == TYPE_INT and y >= 0:
					var result := 1
					var base: int = x
					var e: int = y
					while e > 0:
						if e & 1:
							result *= base
						base *= base
						e >>= 1
					return result
				return pow(float(x), float(y))
			"//", "%":
				if float(y) == 0.0:
					var both_int: bool = typeof(x) == TYPE_INT and typeof(y) == TYPE_INT
					if op == "//":
						_fail("ZeroDivisionError", "integer division or modulo by zero" if both_int else "float floor division by zero")
					else:
						_fail("ZeroDivisionError", "integer modulo by zero" if both_int else "float modulo by zero")
					return null
				if typeof(x) == TYPE_INT and typeof(y) == TYPE_INT:
					var q: int = floori(float(x) / float(y))
					# Corrige el redondeo de float con números grandes.
					while q * y > x if y > 0 else q * y < x:
						q -= 1
					while (q + 1) * y <= x if y > 0 else (q + 1) * y >= x:
						q += 1
					return q if op == "//" else x - q * y
				var qf := floorf(float(x) / float(y))
				return qf if op == "//" else float(x) - qf * float(y)
			"|", "&", "^":
				if typeof(x) == TYPE_INT and typeof(y) == TYPE_INT:
					var bits: int = (x | y) if op == "|" else ((x & y) if op == "&" else (x ^ y))
					if typeof(a) == TYPE_BOOL and typeof(b) == TYPE_BOOL:
						return bits != 0
					return bits
	var ta := type_name(a)
	var tb := type_name(b)
	if op == "+":
		if ta == "str" and tb == "str":
			return str(a) + str(b)
		if ta == "list" and tb == "list":
			return (a as Array) + (b as Array)
		if ta == "tuple" and tb == "tuple":
			return PyTuple.new((a as PyTuple).items + (b as PyTuple).items)
	if op == "*":
		var seq: Variant = a if not na else b
		var times: Variant = b if not na else a
		if typeof(times) in [TYPE_INT, TYPE_BOOL]:
			var count := maxi(0, int(_num(times)))
			match type_name(seq):
				"str":
					return str(seq).repeat(count)
				"list", "tuple":
					var src: Array = seq if type_name(seq) == "list" else (seq as PyTuple).items
					var out: Array = []
					for _k in count:
						out.append_array(src)
					return out if type_name(seq) == "list" else PyTuple.new(out)
	if a is PySet and b is PySet and op in ["|", "&", "-", "^"]:
		var sa: Dictionary = (a as PySet).data
		var sb: Dictionary = (b as PySet).data
		var r := PySet.new()
		match op:
			"|":
				r.data = sa.duplicate()
				r.data.merge(sb)
			"&":
				for hk: String in sa:
					if sb.has(hk):
						r.data[hk] = sa[hk]
			"-":
				for hk: String in sa:
					if not sb.has(hk):
						r.data[hk] = sa[hk]
			"^":
				for hk: String in sa:
					if not sb.has(hk):
						r.data[hk] = sa[hk]
				for hk: String in sb:
					if not sa.has(hk):
						r.data[hk] = sb[hk]
		return r
	_fail("TypeError", "no se puede %s %s y %s" % [VERBS.get(op, "operar"), ta, tb])
	return null
