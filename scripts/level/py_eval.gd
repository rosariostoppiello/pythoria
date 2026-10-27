class_name PyEval
extends RefCounted
## Evaluador de un subconjunto de Python con semántica de Python (no de GDScript).
##
## Soporta: enteros, decimales, textos ('...' y "..."), True/False/None, f-strings
## con {expresión}, + - * / // %, comparaciones (== != < > <= >=, encadenadas),
## and/or/not, paréntesis, menos unario, nombres, asignación simple (x = expr),
## bloques if/elif/else con sangría y llamadas a print/str/int/len.
## Errores como en Python: TypeError, NameError, SyntaxError, IndentationError,
## ZeroDivisionError.
##
## Resultado de evaluate/run: {ok, value, output, error, message, env}.

const OPS := ["==", "!=", "<=", ">=", "//", "<", ">", "+", "-", "*", "/", "%", "(", ")", "=", ","]
const COMPARE_OPS := ["==", "!=", "<", ">", "<=", ">="]
const BUILTINS := ["print", "str", "int", "len"]

var env: Dictionary = {}
var output: PackedStringArray = []
var _err: Dictionary = {}
var _toks: Array = []
var _pos := 0


## Evalúa una expresión con las variables de `variables` (nombre -> valor).
static func evaluate(src: String, variables: Dictionary = {}) -> Dictionary:
	var e := PyEval.new()
	e.env = variables.duplicate()
	var ast: Variant = e._parse_line(src)
	var value: Variant = null
	if e._err.is_empty():
		if typeof(ast) == TYPE_DICTIONARY and ast.get("k") == "assign":
			e._fail("SyntaxError", "se esperaba una expresión, no una asignación")
		else:
			value = e._eval(ast)
	return e._result(value)


## Ejecuta varias líneas (asignaciones, print, expresiones, if/elif/else).
## output = lo impreso; env = variables al terminar.
static func run(lines: Array, variables: Dictionary = {}) -> Dictionary:
	var e := PyEval.new()
	e.env = variables.duplicate()
	var prog: Array[Dictionary] = []
	for line: String in lines:
		var clean := line.replace("\t", "    ")
		if clean.strip_edges() == "" or clean.strip_edges().begins_with("#"):
			continue
		var stripped := clean.strip_edges(true, false)
		prog.append({"indent": clean.length() - stripped.length(), "text": stripped.strip_edges()})
	if not prog.is_empty():
		e._exec_block(prog, 0, prog.size(), int(prog[0]["indent"]))
	return e._result(null)


## Verdad de Python: 0, "", None y False son falsos.
static func truthy(v: Variant) -> bool:
	match typeof(v):
		TYPE_BOOL:
			return v
		TYPE_INT, TYPE_FLOAT:
			return v != 0
		TYPE_STRING:
			return v != ""
		TYPE_NIL:
			return false
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
	return "object"


## str(v) de Python.
static func to_str(v: Variant) -> String:
	match typeof(v):
		TYPE_BOOL:
			return "True" if v else "False"
		TYPE_NIL:
			return "None"
		TYPE_FLOAT:
			var f: float = v
			if is_inf(f):
				return "inf" if f > 0 else "-inf"
			if f == floorf(f) and absf(f) < 1e16:
				return "%d.0" % int(f)
			return str(f)
	return str(v)


## repr(v) de Python: los textos van entre comillas.
static func repr(v: Variant) -> String:
	if typeof(v) == TYPE_STRING:
		var s: String = v
		if s.contains("'") and not s.contains('"'):
			return '"' + s + '"'
		return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"
	return to_str(v)


## Igualdad de Python: 1 == True, 1 == 1.0, '1' != 1.
static func py_equal(a: Variant, b: Variant) -> bool:
	if _is_num(a) and _is_num(b):
		return _num(a) == _num(b)
	if type_name(a) != type_name(b):
		return false
	return a == b


static func _is_num(v: Variant) -> bool:
	return typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]


static func _num(v: Variant) -> Variant:
	if typeof(v) == TYPE_BOOL:
		return 1 if v else 0
	return v


# --- Resultado y errores ----------------------------------------------------

func _fail(kind: String, msg: String) -> void:
	if _err.is_empty():
		_err = {"error": kind, "message": "%s: %s" % [kind, msg]}


func _result(value: Variant) -> Dictionary:
	if not _err.is_empty():
		return {"ok": false, "value": null, "output": "\n".join(output), "error": _err["error"], "message": _err["message"], "env": env}
	return {"ok": true, "value": value, "output": "\n".join(output), "error": "", "message": "", "env": env}


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
			toks.append({"t": "STR", "v": src.substr(i + 1, end2 - i - 1).replace("\\'", "'").replace('\\"', '"')})
			i = end2 + 1
			continue
		if c.is_valid_int():
			var j := i
			var is_float := false
			while j < n and (src[j].is_valid_int() or src[j] == "_" or (src[j] == "." and not is_float)):
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


# --- Parser ------------------------------------------------------------------

func _peek() -> Dictionary:
	return _toks[_pos]


func _next() -> Dictionary:
	var t: Dictionary = _toks[_pos]
	if _pos < _toks.size() - 1:
		_pos += 1
	return t


func _is_op(v: String) -> bool:
	return _peek()["t"] == "OP" and _peek()["v"] == v


func _parse_line(src: String) -> Variant:
	_toks = _tokenize(src)
	_pos = 0
	if not _err.is_empty():
		return null
	if _peek()["t"] == "EOF":
		_fail("SyntaxError", "línea vacía")
		return null
	var ast: Variant = _parse_expr()
	if not _err.is_empty():
		return null
	if _is_op("="):
		_next()
		if typeof(ast) != TYPE_DICTIONARY or ast.get("k") != "name":
			_fail("SyntaxError", "no se puede asignar a un valor; a la izquierda del = va un nombre")
			return null
		var value: Variant = _parse_expr()
		if not _err.is_empty():
			return null
		ast = {"k": "assign", "name": ast["v"], "value": value}
	if _peek()["t"] != "EOF":
		_fail("SyntaxError", "sintaxis inválida cerca de '%s'" % _peek()["v"])
		return null
	return ast


func _is_word(w: String) -> bool:
	return _peek()["t"] == "NAME" and _peek()["v"] == w


func _parse_expr() -> Variant:
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
	var first: Variant = _parse_arith()
	var ops: Array = []
	var operands: Array = [first]
	while _err.is_empty() and _peek()["t"] == "OP" and COMPARE_OPS.has(_peek()["v"]):
		ops.append(_next()["v"])
		operands.append(_parse_arith())
	if ops.is_empty():
		return first
	return {"k": "cmp", "ops": ops, "operands": operands}


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
	return _parse_primary()


func _parse_primary() -> Variant:
	var t := _next()
	match t["t"]:
		"NUM":
			return {"k": "lit", "v": t["v"]}
		"STR":
			return {"k": "lit", "v": t["v"]}
		"FSTR":
			return _parse_fstring(t["v"])
		"NAME":
			match t["v"]:
				"and", "or", "not", "if", "elif", "else":
					_fail("SyntaxError", "'%s' no puede ir acá" % t["v"])
					return null
				"True":
					return {"k": "lit", "v": true}
				"False":
					return {"k": "lit", "v": false}
				"None":
					return {"k": "lit", "v": null}
			if _is_op("("):
				_next()
				var args: Array = []
				if not _is_op(")"):
					args.append(_parse_expr())
					while _err.is_empty() and _is_op(","):
						_next()
						args.append(_parse_expr())
				if not _is_op(")"):
					_fail("SyntaxError", "falta cerrar el paréntesis")
					return null
				_next()
				return {"k": "call", "name": t["v"], "args": args}
			return {"k": "name", "v": t["v"]}
		"OP":
			if t["v"] == "(":
				var inner: Variant = _parse_expr()
				if not _is_op(")"):
					_fail("SyntaxError", "falta cerrar el paréntesis")
					return null
				_next()
				return inner
	_fail("SyntaxError", "sintaxis inválida" if t["t"] != "EOF" else "falta algo al final de la línea")
	return null


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
			var close := body.find("}", i)
			if close < 0:
				_fail("SyntaxError", "f-string: falta cerrar la llave }")
				return null
			if lit != "":
				parts.append({"k": "lit", "v": lit})
				lit = ""
			var sub := PyEval.new()
			var ast: Variant = sub._parse_line(body.substr(i + 1, close - i - 1))
			if not sub._err.is_empty():
				_err = sub._err
				return null
			parts.append({"k": "fmt", "v": ast})
			i = close + 1
			continue
		lit += c
		i += 1
	if lit != "":
		parts.append({"k": "lit", "v": lit})
	return {"k": "fstr", "parts": parts}


# --- Evaluación ----------------------------------------------------------------

## Ejecuta las líneas [start, end) que tienen sangría `indent`, con if/elif/else.
func _exec_block(prog: Array[Dictionary], start: int, end: int, indent: int) -> void:
	var i := start
	while i < end and _err.is_empty():
		var line: Dictionary = prog[i]
		var text: String = line["text"]
		if int(line["indent"]) != indent:
			_fail("IndentationError", "sangría inesperada en: %s" % text)
			return
		if _starts_with_word(text, "elif") or _starts_with_word(text, "else"):
			_fail("SyntaxError", "'%s' sin un if antes" % text.split(" ")[0].trim_suffix(":"))
			return
		if not _starts_with_word(text, "if"):
			var ast: Variant = _parse_line(text)
			if _err.is_empty():
				_exec(ast)
			i += 1
			continue
		# Cadena if / elif / else: se junta cada encabezado con su bloque.
		var branches: Array[Dictionary] = []
		var keyword := "if"
		while true:
			var header: String = prog[i]["text"]
			if not header.ends_with(":"):
				_fail("SyntaxError", "falta ':' al final de: %s" % header)
				return
			var cond := header.substr(keyword.length(), header.length() - keyword.length() - 1).strip_edges()
			if keyword != "else" and cond == "":
				_fail("SyntaxError", "falta la condición después de '%s'" % keyword)
				return
			if keyword == "else" and cond != "":
				_fail("SyntaxError", "else no lleva condición")
				return
			var body_start := i + 1
			var body_end := body_start
			while body_end < end and int(prog[body_end]["indent"]) > indent:
				body_end += 1
			if body_end == body_start:
				_fail("IndentationError", "falta el bloque con sangría después de: %s" % header)
				return
			branches.append({"cond": cond, "kw": keyword, "start": body_start, "end": body_end})
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
				var cond_ast: Variant = _parse_line(b["cond"])
				if not _err.is_empty():
					return
				take = truthy(_eval(cond_ast))
				if not _err.is_empty():
					return
			if take:
				var s: int = b["start"]
				_exec_block(prog, s, b["end"], int(prog[s]["indent"]))
				break


static func _starts_with_word(text: String, word: String) -> bool:
	if not text.begins_with(word):
		return false
	var rest := text.substr(word.length())
	return rest == "" or rest[0] == " " or rest[0] == ":" or rest[0] == "("


func _exec(ast: Variant) -> void:
	if typeof(ast) == TYPE_DICTIONARY and ast.get("k") == "assign":
		var v: Variant = _eval(ast["value"])
		if _err.is_empty():
			env[ast["name"]] = v
		return
	_eval(ast)


func _eval(node: Variant) -> Variant:
	if not _err.is_empty() or typeof(node) != TYPE_DICTIONARY:
		return null
	match node["k"]:
		"lit":
			return node["v"]
		"name":
			if not env.has(node["v"]):
				_fail("NameError", "name '%s' is not defined" % node["v"])
				return null
			return env[node["v"]]
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
					s += to_str(pv)
			return s
		"call":
			return _call(node)
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


func _call(node: Dictionary) -> Variant:
	var name: String = node["name"]
	if not BUILTINS.has(name):
		if env.has(name):
			_fail("TypeError", "'%s' object is not callable" % type_name(env[name]))
		else:
			_fail("NameError", "name '%s' is not defined" % name)
		return null
	var args: Array = []
	for a: Variant in node["args"]:
		args.append(_eval(a))
		if not _err.is_empty():
			return null
	match name:
		"print":
			var texts: PackedStringArray = []
			for a: Variant in args:
				texts.append(to_str(a))
			output.append(" ".join(texts))
			return null
		"str":
			return to_str(args[0]) if args.size() > 0 else ""
		"len":
			if args.size() != 1 or type_name(args[0]) != "str":
				_fail("TypeError", "len() necesita un texto")
				return null
			return (args[0] as String).length()
		"int":
			if args.size() != 1:
				return 0
			var x: Variant = args[0]
			if _is_num(x):
				return int(_num(x))
			if type_name(x) == "str" and (x as String).strip_edges().is_valid_int():
				return (x as String).strip_edges().to_int()
			_fail("ValueError", "invalid literal for int(): %s" % repr(x))
			return null
	return null


const VERBS := {"+": "sumar", "-": "restar", "*": "multiplicar", "/": "dividir", "//": "dividir", "%": "dividir",
	"<": "comparar", ">": "comparar", "<=": "comparar", ">=": "comparar"}


func _binary(op: String, a: Variant, b: Variant) -> Variant:
	match op:
		"==":
			return py_equal(a, b)
		"!=":
			return not py_equal(a, b)
	var na := _is_num(a)
	var nb := _is_num(b)
	if op in ["<", ">", "<=", ">="]:
		var comparable := (na and nb) or (type_name(a) == "str" and type_name(b) == "str")
		if not comparable:
			_fail("TypeError", "no se puede comparar %s y %s con %s" % [type_name(a), type_name(b), op])
			return null
		var x2: Variant = _num(a) if na else a
		var y2: Variant = _num(b) if nb else b
		match op:
			"<":
				return x2 < y2
			">":
				return x2 > y2
			"<=":
				return x2 <= y2
			">=":
				return x2 >= y2
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
					_fail("ZeroDivisionError", "división por cero")
					return null
				return float(x) / float(y)
			"//", "%":
				if float(y) == 0.0:
					_fail("ZeroDivisionError", "división por cero")
					return null
				if typeof(x) == TYPE_INT and typeof(y) == TYPE_INT:
					var q: int = floori(float(x) / float(y))
					return q if op == "//" else x - q * y
				var qf := floorf(float(x) / float(y))
				return qf if op == "//" else float(x) - qf * float(y)
	if op == "+" and type_name(a) == "str" and type_name(b) == "str":
		return (a as String) + (b as String)
	if op == "*":
		if type_name(a) == "str" and typeof(b) in [TYPE_INT, TYPE_BOOL]:
			return (a as String).repeat(maxi(0, int(_num(b))))
		if type_name(b) == "str" and typeof(a) in [TYPE_INT, TYPE_BOOL]:
			return (b as String).repeat(maxi(0, int(_num(a))))
	_fail("TypeError", "no se puede %s %s y %s" % [VERBS.get(op, "operar"), type_name(a), type_name(b)])
	return null
