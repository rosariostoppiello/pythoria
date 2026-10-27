class_name CodeBoard
extends VBoxContainer
## Tablero de "Escribí el hechizo": editor de código, casos de prueba y consola.

signal changed

var puzzle: Dictionary = {}
var editor: CodeEdit
var case_rows: Array[Label] = []
var console: Label


func _init(p: Dictionary) -> void:
	puzzle = p
	add_theme_constant_override("separation", 10)
	var title := UI.label("Escribí tu hechizo en Python", "MutedLabel")
	add_child(title)
	editor = CodeEdit.new()
	editor.name = "Editor"
	editor.text = CodeLogic.starter(p)
	editor.custom_minimum_size = Vector2(0, 230)
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.gutters_draw_line_numbers = true
	editor.indent_use_spaces = true
	editor.indent_size = 4
	editor.indent_automatic = true
	editor.auto_brace_completion_enabled = true
	editor.auto_brace_completion_highlight_matching = true
	editor.scroll_fit_content_height = false
	editor.syntax_highlighter = highlighter()
	editor.text_changed.connect(func() -> void: changed.emit())
	add_child(editor)

	var cases_panel := UI.panel("DarkPanel")
	add_child(cases_panel)
	var cbox := UI.vbox(4)
	cases_panel.add_child(cbox)
	var ct := UI.label("Casos de prueba: con esas entradas para input(), tu programa tiene que imprimir exactamente lo que está después de «imprime:»", "MutedLabel")
	ct.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ct.add_theme_font_size_override("font_size", 14)
	cbox.add_child(ct)
	var ts := CodeLogic.tests(p)
	for i in ts.size():
		var row := UI.label("", "CodeLabel")
		row.add_theme_font_size_override("font_size", 15)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		case_rows.append(row)
		cbox.add_child(row)

	var console_panel := UI.panel("CodePanel")
	add_child(console_panel)
	var obox := UI.vbox(2)
	console_panel.add_child(obox)
	var ot := UI.label("Salida", "MutedLabel")
	ot.add_theme_font_size_override("font_size", 14)
	obox.add_child(ot)
	console = UI.label("Apretá «Probar» para ver qué imprime tu programa con el caso 1.", "CodeLabel")
	console.add_theme_font_size_override("font_size", 15)
	console.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obox.add_child(console)
	_show_cases([])


## Colores de sintaxis a partir de la paleta.
static func highlighter() -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = ThemeColors.LAVANDA.lightened(0.25)
	h.symbol_color = ThemeColors.LAVANDA
	h.function_color = ThemeColors.TURQUESA.lightened(0.2)
	h.member_variable_color = ThemeColors.PERGAMINO
	for kw: String in ["if", "elif", "else", "and", "or", "not", "True", "False", "None", "in", "while", "for", "def", "return"]:
		h.add_keyword_color(kw, ThemeColors.VIOLETA.lightened(0.45))
	h.add_color_region("#", "", ThemeColors.GRIS_BLOQUEADO.lightened(0.35), true)
	h.add_color_region("'", "'", ThemeColors.PERGAMINO.darkened(0.15))
	h.add_color_region("\"", "\"", ThemeColors.PERGAMINO.darkened(0.15))
	return h


func code() -> String:
	return editor.text


func _show_cases(results: Array) -> void:
	var ts := CodeLogic.tests(puzzle)
	for i in ts.size():
		var t: Dictionary = ts[i]
		var mark := "·"
		var color := ThemeColors.PERGAMINO
		if i < results.size():
			mark = "✓" if results[i]["passed"] else "x"
			color = ThemeColors.TURQUESA if results[i]["passed"] else ThemeColors.ROJO
		case_rows[i].text = "%s Caso %d   input(): %s   imprime: %s" % [mark, i + 1, CodeLogic.describe_inputs(t), CodeLogic.one_line(CodeLogic.normalize(str(t.get("output", ""))))]
		case_rows[i].add_theme_color_override("font_color", color)


## Corre el programa con el caso 1 y muestra la salida (sin juzgar).
func run_sample() -> Dictionary:
	var ts := CodeLogic.tests(puzzle)
	var r := CodeLogic.run_case(code(), ts[0] if not ts.is_empty() else {})
	var text := str(r["output"])
	if not r["ok"]:
		text = (text + "\n" if text != "" else "") + str(r["message"])
	console.text = text if text != "" else "(tu programa no imprimió nada)"
	console.add_theme_color_override("font_color", ThemeColors.ROJO if not r["ok"] else ThemeColors.PERGAMINO)
	return r


func cast() -> Dictionary:
	var r := CodeLogic.check(puzzle, code())
	_show_cases(r["cases"])
	var idx: int = r["failed_case"]
	if idx >= 0:
		var c: Dictionary = r["cases"][idx]
		var text: String = c["got"]
		if c["error"] != "":
			text = (text + "\n" if text != "" else "") + str(c["message"])
		console.text = "Caso %d:\n%s" % [idx + 1, text if text != "" else "(no imprimió nada)"]
		console.add_theme_color_override("font_color", ThemeColors.ROJO)
	elif r["status"] == "success":
		console.text = "Todos los casos pasaron."
		console.add_theme_color_override("font_color", ThemeColors.TURQUESA)
	return r


## Vuelve al código inicial de la consigna.
func clear() -> void:
	editor.text = CodeLogic.starter(puzzle)
	_show_cases([])
	changed.emit()
