extends Control
## Minijuego "Duelo de Bugs": un hechizo con un bug, lo que debería imprimir y lo que
## imprime de verdad. Hay que elegir el arreglo de una línea que lo cura.

var house_id: String
var content: Dictionary
var round_idx := 0
var option_buttons: Array[Button] = []

var _code_label: Label
var _expected_label: Label
var _actual_label: Label
var _options_box: VBoxContainer
var _round_label: Label
var _progress: ProgressBar
var _bug: TextureRect


func _ready() -> void:
	SceneManager.set_state(SceneManager.State.LEVEL)
	house_id = SceneManager.house_id
	content = ContentDB.get_content(house_id)
	UI.background(self)
	add_child(TopBar.for_activity("Mundo %d · %s" % [ContentDB.world_of(house_id), content.get("title", "Minijuego")]))

	var main := UI.hbox(16)
	main.position = Vector2(16, 70)
	main.size = Vector2(1248, 640)
	add_child(main)

	var left := UI.vbox(12)
	left.custom_minimum_size = Vector2(340, 0)
	main.add_child(left)
	var mission := UI.panel()
	left.add_child(mission)
	var mbox := UI.vbox(8)
	mission.add_child(mbox)
	mbox.add_child(UI.label(str(content.get("title", "")), "InkTitle"))
	var how := UI.label("Este hechizo tiene un bug: no imprime lo que debería. Compará las dos salidas y elegí el arreglo de una línea que lo cura.", "InkLabel")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(300, 0)
	mbox.add_child(how)
	var side := UI.panel("DarkPanel")
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(side)
	var sbox := UI.vbox(10)
	sbox.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_child(sbox)
	_bug = UI.sprite_rect("bug", 3.0)
	_bug.pivot_offset = _bug.custom_minimum_size / 2
	sbox.add_child(_bug)
	var wiggle := _bug.create_tween().set_loops()
	wiggle.tween_property(_bug, "rotation", 0.12, 0.25)
	wiggle.tween_property(_bug, "rotation", -0.12, 0.25)
	_round_label = UI.label("", "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	sbox.add_child(_round_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(280, 18)
	_progress.show_percentage = false
	_progress.max_value = (content["rounds"] as Array).size()
	sbox.add_child(_progress)

	# Columna derecha con scroll por si un código largo no entra.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(right)
	# Arriba: el código a la izquierda y las dos salidas apiladas a la derecha.
	var top := UI.hbox(10)
	right.add_child(top)
	var code_panel := UI.panel("CodePanel")
	code_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(code_panel)
	var cbox := UI.vbox(4)
	code_panel.add_child(cbox)
	cbox.add_child(UI.label("El hechizo con el bug", "MutedLabel"))
	_code_label = UI.label("", "CodeLabel")
	_code_label.add_theme_font_size_override("font_size", 16)
	cbox.add_child(_code_label)

	var outs := UI.vbox(10)
	outs.custom_minimum_size = Vector2(290, 0)
	top.add_child(outs)
	_expected_label = _output_panel(outs, "Debería imprimir", ThemeColors.TURQUESA)
	_actual_label = _output_panel(outs, "Ahora imprime", ThemeColors.ROJO)

	right.add_child(UI.label("¿Qué arreglo lo cura?", "HeaderLabel"))
	var legend := UI.label("Cada · al principio es un espacio de sangría.", "MutedLabel")
	legend.add_theme_font_size_override("font_size", 14)
	right.add_child(legend)
	_options_box = UI.vbox(8)
	right.add_child(_options_box)
	_load_round()


func _output_panel(parent: Container, title: String, color: Color) -> Label:
	var panel := UI.panel("CodePanel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := UI.vbox(2)
	panel.add_child(box)
	var t := UI.label(title, "MutedLabel")
	t.add_theme_color_override("font_color", color)
	box.add_child(t)
	var l := UI.label("", "CodeLabel")
	l.add_theme_font_size_override("font_size", 15)
	box.add_child(l)
	return l


## La sangría es parte del arreglo: los espacios del principio se ven como "·".
static func show_indent(line: String) -> String:
	var body := line.strip_edges(true, false)
	return "·".repeat(line.length() - body.length()) + body


func current_round() -> Dictionary:
	return content["rounds"][round_idx]


func _load_round() -> void:
	var r := current_round()
	var numbered: PackedStringArray = []
	var code: Array = r["code"]
	for i in code.size():
		numbered.append("%d  %s" % [i + 1, code[i]])
	var inputs: Array = r.get("inputs", [])
	if not inputs.is_empty():
		numbered.append("")
		numbered.append("# entrada para input(): %s" % ", ".join(PackedStringArray(inputs.map(func(v: Variant) -> String: return str(v)))))
	_code_label.text = "\n".join(numbered)
	_expected_label.text = MinigameLogic.preview({"ok": true, "output": CodeLogic.normalize(str(r["output"]))}, 4)
	_actual_label.text = MinigameLogic.preview(MinigameLogic.run_duel(r, code), 4)
	for b in option_buttons:
		b.queue_free()
	option_buttons.clear()
	var fixes: Array = r["fixes"]
	for i in fixes.size():
		var fix: Dictionary = fixes[i]
		var b := UI.button("línea %d  →  %s" % [int(fix["line"]), show_indent(str(fix["text"]))], "OperatorButton")
		b.add_theme_font_size_override("font_size", 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(choose.bind(i))
		option_buttons.append(b)
		_options_box.add_child(b)
	_round_label.text = "Ronda %d de %d" % [round_idx + 1, (content["rounds"] as Array).size()]
	_progress.value = round_idx


func choose(fix_idx: int) -> Dictionary:
	var r := MinigameLogic.check_fix(current_round(), fix_idx)
	if r["status"] != "success":
		SceneManager.show_result({"success": false, "title": r["title"], "message": r["message"], "detail": r["detail"], "creature": r["creature"]})
		return r
	for i in option_buttons.size():
		option_buttons[i].disabled = i != fix_idx
	_actual_label.text = MinigameLogic.preview(MinigameLogic.run_duel(current_round(), MinigameLogic.apply_fix(current_round()["code"], current_round()["fixes"][fix_idx])), 4)
	round_idx += 1
	_progress.value = round_idx
	await get_tree().create_timer(0.8).timeout
	if round_idx < (content["rounds"] as Array).size():
		_load_round()
		return r
	var gained := GameState.complete_house(house_id)
	SceneManager.show_result({"success": true, "xp": gained, "title": "¡Ganaste el duelo!", "message": "Curaste los %d hechizos." % round_idx})
	return r
