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


func test_comparaciones() -> void:
	_ok("8 > 5", true)
	_ok("3 >= 3", true)
	_ok("2 < 1", false)
	_ok("4 <= 6", true)
	_ok("poder > limite", true, {"poder": 8, "limite": 5})
	_ok("1 < 2 < 3", true)
	_ok("1 < 3 < 2", false)
	_ok("'abc' < 'abd'", true)
	_ok("True > 0", true)
	var r := _err("10 > '5'", "TypeError")
	check_eq(r["message"], "TypeError: no se puede comparar int y str con >", "mensaje al comparar tipos distintos")


func test_and_or_not() -> void:
	_ok("True and False", false)
	_ok("True or False", true)
	_ok("not True", false)
	_ok("not 0", true)
	_ok("llave and mapa", false, {"llave": true, "mapa": false})
	_ok("not abierto and llave", true, {"abierto": false, "llave": true})
	_ok("edad >= 12 and tiene_mapa", false, {"edad": 15, "tiene_mapa": false})
	_ok("1 + 1 == 2 and not 3 > 4", true)
	# Como en Python: devuelven un operando y cortan antes de evaluar el resto.
	_ok("0 or 'hola'", "hola")
	_ok("'' and nadie", "")
	_ok("True or nadie", true)
	_err("False or nadie", "NameError")
	_err("True and", "SyntaxError")


func test_if_elif_else() -> void:
	var code := ["if poder > 5:", "    camino = 'puente'", "elif poder > 2:", "    camino = 'cueva'", "else:", "    camino = 'río'"]
	var cases := {7: "puente", 4: "cueva", 1: "río", 5: "cueva"}
	for p: int in cases:
		var r := PyEval.run(code, {"poder": p})
		check(r["ok"], "if con poder=%d: %s" % [p, r["message"]])
		check_eq(r["env"].get("camino"), cases[p], "camino con poder=%d" % p)
	var r2 := PyEval.run(["x = 3", "if x == 5:", "    print('cinco')", "elif x < 5:", "    print('menos')", "    print('listo')", "else:", "    print('más')", "print('fin')"])
	check_eq(r2["output"], "menos\nlisto\nfin", "solo corre la rama elegida")
	r2 = PyEval.run(["if True:", "    if False:", "        print('a')", "    else:", "        print('b')"])
	check_eq(r2["output"], "b", "if anidado")
	r2 = PyEval.run(["if 0:", "    print('no')"])
	check_eq(r2["output"], "", "if sin else que no entra")


func test_errores_de_if() -> void:
	check_eq(PyEval.run(["if 1 > 0", "    print('x')"])["error"], "SyntaxError", "falta ':'")
	check_eq(PyEval.run(["if 1 > 0:", "print('x')"])["error"], "IndentationError", "falta la sangría")
	check_eq(PyEval.run(["print('a')", "    print('b')"])["error"], "IndentationError", "sangría inesperada")
	check_eq(PyEval.run(["else:", "    print('x')"])["error"], "SyntaxError", "else suelto")
	check_eq(PyEval.run(["if x > 1:", "    print('x')"])["error"], "NameError", "variable sin definir en la condición")
	check_eq(PyEval.run(["if 'a' > 1:", "    print('x')"])["error"], "TypeError", "comparar tipos distintos")
