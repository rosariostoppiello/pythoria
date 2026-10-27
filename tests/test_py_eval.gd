extends TestCase
## Evaluador con semántica de Python.


func _ok(src: String, expected: Variant, env: Dictionary = {}) -> void:
	var r := PyEval.evaluate(src, env)
	check(r["ok"], "%s dio error: %s" % [src, r["message"]])
	if r["ok"]:
		check_eq(r["value"], expected, src)


func _err(src: String, kind: String, env: Dictionary = {}) -> Dictionary:
	var r := PyEval.evaluate(src, env)
	check(not r["ok"], "%s debería fallar con %s" % [src, kind])
	check_eq(r["error"], kind, "tipo de error de " + src)
	return r


func test_suma_de_enteros() -> void:
	_ok("5 + 3", 8)
	_ok("poder + bonus", 8, {"poder": 5, "bonus": 3})
	_ok("10 - 4 - 3", 3)
	_ok("-2 + 5", 3)


func test_multiplicacion_y_precedencia() -> void:
	_ok("3 * 4", 12)
	_ok("2 + 3 * 4", 14)
	_ok("(2 + 3) * 4", 20)
	_ok("7 // 2", 3)
	_ok("-7 // 2", -4)
	_ok("7 % 3", 1)
	_ok("7 / 2", 3.5)
	_err("1 / 0", "ZeroDivisionError")


func test_concatenacion_de_textos() -> void:
	_ok("'Hola ' + 'Ada'", "Hola Ada")
	_ok("saludo + nombre", "Hola Ada", {"saludo": "Hola ", "nombre": "Ada"})
	_ok("\"ja\" * 3", "jajaja")
	_ok("2 * 'ab'", "abab")


func test_type_error_int_mas_str() -> void:
	var r := _err("7 + 'Ada'", "TypeError")
	check_eq(r["message"], "TypeError: no se puede sumar int y str", "mensaje de TypeError")
	_err("'Hola ' + 7", "TypeError")
	_err("x + y", "TypeError", {"x": 6, "y": "6"})
	_err("'a' - 'b'", "TypeError")
	_err("'a' * 'b'", "TypeError")


func test_igualdad_devuelve_bool() -> void:
	_ok("7 == 7", true)
	_ok("7 == 5", false)
	_ok("izquierda == derecha", true, {"izquierda": 7, "derecha": 7})
	_ok("'7' == 7", false)
	_ok("1 == True", true)
	_ok("3 != 4", true)
	var r := PyEval.evaluate("2 == 2")
	check_eq(PyEval.type_name(r["value"]), "bool", "== da bool")
	_ok("True + True", 2)


func test_f_string() -> void:
	_ok("f\"Bienvenido, {nombre}\"", "Bienvenido, Ada", {"nombre": "Ada"})
	_ok("f'{a} + {b} = {a + b}'", "2 + 3 = 5", {"a": 2, "b": 3})
	_ok("f'{ok}'", "True", {"ok": true})
	_ok("f'{{literal}}'", "{literal}")
	_err("f'Hola {nadie}'", "NameError")


func test_name_error() -> void:
	var r := _err("poder + bonus", "NameError", {"poder": 5})
	check_eq(r["message"], "NameError: name 'bonus' is not defined", "mensaje de NameError")


func test_syntax_error() -> void:
	_err("5 +", "SyntaxError")
	_err("(1 + 2", "SyntaxError")
	_err("'sin cerrar", "SyntaxError")
	_err("3 $ 4", "SyntaxError")


func test_programa_con_print() -> void:
	var r := PyEval.run(["poder = 5", "print(poder)"])
	check(r["ok"], "programa simple")
	check_eq(r["output"], "5", "salida de print")
	r = PyEval.run(["nombre = 'Ada'", "print(f\"Hola, {nombre}\")"])
	check_eq(r["output"], "Hola, Ada", "print con f-string")
	r = PyEval.run(["a = 4", "b = 3", "print(a * b)"])
	check_eq(r["output"], "12", "print de multiplicación")
	r = PyEval.run(["5 = 5", "print(poder)"])
	check_eq(r["error"], "SyntaxError", "asignar a un literal")
	r = PyEval.run(["nombre = Ada"])
	check_eq(r["error"], "NameError", "texto sin comillas")
	r = PyEval.run(["print('a', 1, True)"])
	check_eq(r["output"], "a 1 True", "print con varios argumentos")


func test_repr() -> void:
	check_eq(PyEval.repr("Hola "), "'Hola '", "repr de texto")
	check_eq(PyEval.repr(5), "5", "repr de int")
	check_eq(PyEval.repr(true), "True", "repr de bool")
	check_eq(PyEval.repr(2.0), "2.0", "repr de float")
	check_eq(PyEval.repr("it's"), "\"it's\"", "repr con comilla simple")
