extends TestCase
## Evaluador, mundos 4 a 8: listas, tuplas, slicing, diccionarios, sets, funciones,
## excepciones, archivos y recursión. Las salidas esperadas se sacaron de Python real.


func _out(lines: Array, inputs: Array = [], files: Dictionary = {}) -> String:
	var r := PyEval.run(lines, {}, inputs, files)
	check(r["ok"], "%s dio error: %s" % [lines, r["message"]])
	return r["output"]


func _error(lines: Array, files: Dictionary = {}) -> String:
	return str(PyEval.run(lines, {}, [], files)["error"])


func test_listas_y_slicing() -> void:
	check_eq(_out(["l = [3, 1, 2]", "l.append(5)", "print(l, len(l), l[0], l[-1], l[1:3], l[::-1], l[::2])"]), "[3, 1, 2, 5] 4 3 5 [1, 2] [5, 2, 1, 3] [3, 2]", "lista básica")
	check_eq(_out(["s = 'pergamino'", "print(s[3:7], s[-5:], s[:3], s[::-1], s[1:8:2], s[10:20], s[-100:2])"]), "gami amino per onimagrep egmn  pe", "slicing de textos")
	check_eq(_out(["print('abcdef'[-2:-5:-1], 'abcdef'[5:1:-2], [][:5])"]), "edc fd []", "slicing con paso negativo")
	check_eq(_error(["l = [1, 2]", "print(l[5])"]), "IndexError", "índice fuera de rango")
	check_eq(_out(["x = [5, 3, 5, 1]", "x.remove(5)", "print(x, x.index(1), x.count(5), x.pop(), x)", "x.insert(0, 9)", "x.sort()", "print(x)"]), "[3, 5] 2 1 1 [3, 5]\n[3, 5, 9]", "métodos de lista")
	check_eq(_out(["x = [3, 1, 2]", "print(x.sort())", "print(x)"]), "None\n[1, 2, 3]", "sort devuelve None")
	check_eq(_error(["[1].remove(5)"]), "ValueError", "remove de algo que no está")


func test_alias_y_copias() -> void:
	check_eq(_out(["x = [1, 2, 3]", "y = x", "y.append(4)", "z = x[:]", "z.append(9)", "print(x, z, x is y)"]), "[1, 2, 3, 4] [1, 2, 3, 4, 9] True", "alias y copia")
	check_eq(_out(["grid = [[0] * 3] * 3", "grid[0][0] = 1", "print(grid)"]), "[[1, 0, 0], [1, 0, 0], [1, 0, 0]]", "la trampa de [[0] * 3] * 3")
	check_eq(_out(["l = [1, 2, 3, 4]", "for x in l:", "    if x % 2 == 0:", "        l.remove(x)", "print(l)"]), "[1, 3]", "borrar mientras se recorre")


func test_tuplas_y_desempaquetado() -> void:
	check_eq(_out(["t = (1, 'a', True)", "a, b, c = t", "print(t, t[1], (5,), (), a, c)"]), "(1, 'a', True) a (5,) () 1 True", "tuplas")
	check_eq(_out(["a, b = 1, 2", "a, b = b, a", "print(a, b)"]), "2 1", "intercambio")
	check_eq(_error(["t = (1, 2)", "t[0] = 5"]), "TypeError", "las tuplas no cambian")
	check_eq(_error(["s = 'hola'", "s[0] = 'H'"]), "TypeError", "los textos no cambian")
	check_eq(_error(["a, b = [1, 2, 3]"]), "ValueError", "sobran valores")


func test_textos() -> void:
	check_eq(_out(["print('-'.join(['a', 'b']), 'a,b,,c'.split(','), '  x  y '.split())"]), "a-b ['a', 'b', '', 'c'] ['x', 'y']", "split y join")
	check_eq(_error(["print(', '.join([1, 2]))"]), "TypeError", "join con números")
	check_eq(_out(["print(f'{3.14159:08.3f}|{42:05d}|{\"ab\":^6}|', '{} y {:.2f}'.format(1, 2.5))"]), "0003.142|00042|  ab  | 1 y 2.50", "formatos")
	check_eq(_out(["print(repr('a\\nb'), [None, 'x', 1.5, True])"]), "'a\\nb' [None, 'x', 1.5, True]", "repr adentro de listas")


func test_diccionarios() -> void:
	var code := ["d = {'fuego': 3, 'agua': 5}", "d['aire'] = 2", "d['fuego'] += 1",
		"print(d, len(d), d.get('tierra'), d.get('tierra', 0), 'agua' in d)", "for k, v in d.items():", "    print(k, v)"]
	check_eq(_out(code), "{'fuego': 4, 'agua': 5, 'aire': 2} 3 None 0 True\nfuego 4\nagua 5\naire 2", "dict")
	check_eq(_error(["d = {}", "print(d['x'])"]), "KeyError", "clave que no existe")
	check_eq(_error(["conteo = {}", "for c in 'aba':", "    conteo[c] += 1"]), "KeyError", "contar sin inicializar")
	check_eq(_out(["inv = {}", "for i in ['a', 'b', 'a']:", "    inv[i] = inv.get(i, 0) + 1", "print(inv)"]), "{'a': 2, 'b': 1}", "contar con get")
	check_eq(_out(["print({1: 'a', 1.0: 'b', True: 'c'})"]), "{1: 'c'}", "1, 1.0 y True son la misma clave")
	check_eq(_error(["d = {[1]: 2}"]), "TypeError", "una lista no puede ser clave")


func test_sets() -> void:
	check_eq(_out(["a = {1, 2, 3}", "b = {2, 3, 4}", "print(sorted(a | b), sorted(a & b), sorted(a - b), sorted(a ^ b), len({1, 1, 2}))"]), "[1, 2, 3, 4] [2, 3] [1] [1, 4] 2", "operaciones de sets")
	check_eq(_out(["print({}, type({}), set(), {1, 2} == {2, 1})"]), "{} <class 'dict'> set() True", "{} es un dict")
	check_eq(_error(["s = {1}", "s.remove(9)"]), "KeyError", "remove de un set")


func test_comprensiones_y_funciones_incluidas() -> void:
	check_eq(_out(["nums = [int(x) for x in '3 8 1 9'.split()]", "print([n * n for n in nums if n % 2 == 1], {n: n * 2 for n in range(3)})"]), "[9, 1, 81] {0: 0, 1: 2, 2: 4}", "comprensiones")
	check_eq(_out(["notas = [('Ada', 9), ('Linus', 7), ('Grace', 9)]", "print(sorted(notas, key=lambda p: p[1], reverse=True))"]), "[('Ada', 9), ('Grace', 9), ('Linus', 7)]", "sorted estable con key")
	check_eq(_out(["for i, c in enumerate('ab', start=1):", "    print(i, c)", "print(list(zip([1, 2, 3], 'xy')), sum([1, 2]), max([], default=-1))"]), "1 a\n2 b\n[(1, 'x'), (2, 'y')] 3 -1", "enumerate, zip, sum y max")
	check_eq(_out(["print(type(5), isinstance(True, int), type(5) == int, isinstance('x', (int, str)))"]), "<class 'int'> True True True", "tipos")


func test_funciones() -> void:
	check_eq(_out(["def saludar(nombre, saludo='Hola'):", "    return f'{saludo}, {nombre}!'", "print(saludar('Ada'))", "print(saludar(saludo='Hey', nombre='Grace'))"]), "Hola, Ada!\nHey, Grace!", "parámetros por defecto y por nombre")
	check_eq(_out(["def doble(x):", "    print(x * 2)", "r = doble(4)", "print(r)"]), "8\nNone", "sin return devuelve None")
	check_eq(_out(["x = 10", "def cambiar(x):", "    x = x + 5", "    return x", "print(cambiar(3) + x, x)"]), "18 10", "parámetro local")
	check_eq(_error(["contador = 0", "def sumar():", "    contador += 1", "sumar()"]), "UnboundLocalError", "asignar una global sin global")
	check_eq(_out(["contador = 0", "def sumar():", "    global contador", "    contador += 1", "sumar()", "sumar()", "print(contador)"]), "2", "global")
	check_eq(_out(["def agregar(x, lista=[]):", "    lista.append(x)", "    return lista", "print(agregar(1))", "print(agregar(2))"]), "[1]\n[1, 2]", "la lista por defecto se comparte")
	check_eq(_out(["def stats(l):", "    return min(l), max(l)", "lo, hi = stats([4, 8, 6])", "print(lo, hi)"]), "4 8", "devolver una tupla")
	var r := PyEval.run(["def f(a, b):", "    return a + b", "print(f(1))"])
	check_eq(r["message"], "TypeError: f() missing 1 required positional argument: 'b'", "falta un argumento")
	check_eq(_out(["def f(x): return x * 2", "if True: print(f(4))"]), "8", "def y if en una línea")
	check_eq(_out(["def externa():", "    n = 1", "    def interna():", "        return n + 1", "    return interna()", "print(externa())"]), "2", "función adentro de otra")


func test_recursion() -> void:
	check_eq(_out(["def fact(n):", "    if n == 0:", "        return 1", "    return n * fact(n - 1)", "print(fact(5), fact(20))"]), "120 2432902008176640000", "factorial")
	var hanoi := ["def hanoi(n, a, b, c):", "    if n == 0:", "        return", "    hanoi(n - 1, a, c, b)", "    print(f'{a}->{c}')", "    hanoi(n - 1, b, a, c)", "hanoi(2, 'A', 'B', 'C')"]
	check_eq(_out(hanoi), "A->B\nA->C\nB->C", "Hanoi")
	check_eq(_out(["def plano(x):", "    if isinstance(x, list):", "        return sum([plano(e) for e in x])", "    return x", "print(plano([1, [2, [3, 4]], 5]))"]), "15", "listas anidadas")
	check_eq(_out(["memo = {}", "def fib(n):", "    if n in memo:", "        return memo[n]", "    if n < 2:", "        return n", "    memo[n] = fib(n - 1) + fib(n - 2)", "    return memo[n]", "print(fib(50))"]), "12586269025", "memo")
	check_eq(_error(["def f(n):", "    return f(n + 1)", "f(0)"]), "RecursionError", "sin caso base")
	check_eq(_out(["def f(n):", "    if n == 0:", "        return 0", "    return 1 + f(n - 1)", "print(f(55))"]), "55", "55 llamadas anidadas entran")


func test_excepciones() -> void:
	check_eq(_out(["try:", "    x = int('hola')", "except ValueError as e:", "    print('mal:', e)"]), "mal: invalid literal for int() with base 10: 'hola'", "except con as")
	check_eq(_out(["try:", "    print(1 / 0)", "except ZeroDivisionError:", "    print('cero')", "finally:", "    print('fin')"]), "cero\nfin", "finally")
	check_eq(_out(["try:", "    x = 5", "except ValueError:", "    print('no')", "else:", "    print('ok', x)"]), "ok 5", "else del try")
	check_eq(_out(["try:", "    [1][3]", "except (KeyError, IndexError):", "    print('fuera')"]), "fuera", "varias excepciones")
	check_eq(_out(["try:", "    raise KeyError('x')", "except LookupError as e:", "    print(e)"]), "'x'", "jerarquía de excepciones")
	check_eq(_out(["def check(e):", "    if e < 0:", "        raise ValueError('edad negativa')", "try:", "    check(-1)", "except Exception as e:", "    print(type(e).__name__, e)"]), "ValueError edad negativa", "raise propio")
	check_eq(_out(["def f():", "    try:", "        return 'try'", "    finally:", "        print('finally')", "print(f())"]), "finally\ntry", "finally con return")
	check_eq(_error(["try:", "    int('x')", "except TypeError:", "    print('no la atrapa')"]), "ValueError", "except equivocado no atrapa")
	check_eq(_error(["try:", "    while True:", "        pass", "except Exception:", "    print('no')"]), "BucleInfinito", "el bucle infinito no se atrapa")
	check_eq(_error(["print('a'", "try:", "    pass", "except:", "    pass"]), "SyntaxError", "la sintaxis se revisa antes de correr")


func test_archivos() -> void:
	var notas := {"notas.txt": "Ada,9\nLinus,7\n"}
	check_eq(_out(["with open('notas.txt') as f:", "    for linea in f:", "        nombre, nota = linea.strip().split(',')", "        print(nombre, int(nota) + 1)"], [], notas), "Ada 10\nLinus 8", "leer con for")
	check_eq(_out(["with open('a.txt', 'w') as f:", "    f.write('hola\\n')", "with open('a.txt', 'a') as f:", "    f.write('fin\\n')", "print(open('a.txt').readlines())"]), "['hola\\n', 'fin\\n']", "escribir y agregar")
	check_eq(_error(["open('nada.txt')"]), "FileNotFoundError", "archivo que no existe")
	check_eq(_error(["f = open('notas.txt')", "f.close()", "f.read()"], notas), "ValueError", "leer un archivo cerrado")
	var r := PyEval.run(["with open('salida.txt', 'w') as f:", "    f.write('x')"])
	check_eq(r["files"].get("salida.txt"), "x", "el resultado trae los archivos")


func test_valores_del_json() -> void:
	var v: Variant = PyEval.from_json({"docs": {"a.txt": 3.0}, "lista": [1.0, 2.5]})
	check_eq(PyEval.repr(v), "{'docs': {'a.txt': 3}, 'lista': [1, 2.5]}", "objetos del JSON a dict de Python")
