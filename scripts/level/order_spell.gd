extends Control
## Minijuego "Ordena el conjuro": las líneas de un programa están mezcladas (y a veces
## sobra alguna). Se tocan en el orden en que tienen que correr; vale cualquier orden
## que imprima lo pedido.

var house_id: String
var content: Dictionary
var round_idx := 0
## Líneas mezcladas de la ronda y cuáles ya están en el conjuro (índices, en orden).
var pool: Array = []
var chosen: Array[int] = []
var pool_buttons: Array[Button] = []

var _pool_box: VBoxContainer
var _spell_box: VBoxContainer
var _expected_label: Label
var _output_label: Label
var _round_label: Label
var _progress: ProgressBar


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
	left.custom_minimum_size = Vector2(320, 0)
	main.add_child(left)
	var mission := UI.panel()
	left.add_child(mission)
	var mbox := UI.vbox(8)
	mission.add_child(mbox)
	mbox.add_child(UI.label(str(content.get("title", "")), "InkTitle"))
	var how := UI.label("Las líneas del conjuro se mezclaron. Tocalas en el orden en que tienen que correr; tocá una del conjuro para devolverla. Puede sobrar alguna.", "InkLabel")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(280, 0)
	mbox.add_child(how)
	var side := UI.panel("DarkPanel")
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(side)
	var sbox := UI.vbox(10)
	sbox.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_child(sbox)
	var scroll_sprite := UI.sprite_rect("scroll", 3.0)
	sbox.add_child(scroll_sprite)
	_round_label = UI.label("", "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	sbox.add_child(_round_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(260, 18)
	_progress.show_percentage = false
	_progress.max_value = (content["rounds"] as Array).size()
	sbox.add_child(_progress)

	var right := UI.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	# Las columnas van en un scroll por si el conjuro es largo.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var columns := UI.hbox(12)
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(columns)
	_pool_box = _column(columns, "Líneas sueltas")
	_spell_box = _column(columns, "Tu conjuro (de arriba hacia abajo)")

	var outs := UI.hbox(12)
	right.add_child(outs)
	_expected_label = _output_panel(outs, "Tiene que imprimir", ThemeColors.TURQUESA)
	_output_label = _output_panel(outs, "Tu conjuro imprime", ThemeColors.LAVANDA)
	var legend := UI.label("Cada · al principio de una línea es un espacio de sangría.", "MutedLabel")
	legend.add_theme_font_size_override("font_size", 14)
	right.add_child(legend)
	var actions := UI.hbox(12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(actions)
	var launch_btn := UI.button("Lanzar", "", 220)
	launch_btn.name = "Lanzar"
	launch_btn.focus_mode = Control.FOCUS_NONE
	launch_btn.pressed.connect(launch)
	actions.add_child(launch_btn)
	var clear_btn := UI.button("Desarmar", "OutlineButton")
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.pressed.connect(func() -> void:
		chosen.clear()
		_refresh())
	actions.add_child(clear_btn)
	_load_round()


func _column(parent: Container, title: String) -> VBoxContainer:
	var panel := UI.panel("CodePanel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	parent.add_child(panel)
	var box := UI.vbox(6)
	panel.add_child(box)
	box.add_child(UI.label(title, "MutedLabel"))
	var lines := UI.vbox(6)
	box.add_child(lines)
	return lines


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


## La sangría es parte del orden: los espacios del principio se ven como "·".
static func show_indent(line: String) -> String:
	var body := line.strip_edges(true, false)
	return "·".repeat(line.length() - body.length()) + body


func current_round() -> Dictionary:
	return content["rounds"][round_idx]


func _load_round() -> void:
	var r := current_round()
	pool = MinigameLogic.shuffled_lines(r)
	chosen.clear()
	_expected_label.text = MinigameLogic.preview({"ok": true, "output": CodeLogic.normalize(str(r["output"]))}, 6)
	var inputs: Array = r.get("inputs", [])
	if not inputs.is_empty():
		_expected_label.text += "\n(input(): %s)" % ", ".join(PackedStringArray(inputs.map(func(v: Variant) -> String: return str(v))))
	_output_label.text = ""
	_round_label.text = "Ronda %d de %d" % [round_idx + 1, (content["rounds"] as Array).size()]
	_progress.value = round_idx
	_refresh()


func _line_button(text: String) -> Button:
	var b := UI.button(show_indent(text), "OperatorButton")
	b.add_theme_font_size_override("font_size", 17)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	return b


func _refresh() -> void:
	for c in _pool_box.get_children():
		c.queue_free()
	for c in _spell_box.get_children():
		c.queue_free()
	pool_buttons.clear()
	for i in pool.size():
		var b := _line_button(str(pool[i]))
		b.name = "Suelta%d" % i
		b.disabled = chosen.has(i)
		b.pressed.connect(pick.bind(i))
		pool_buttons.append(b)
		_pool_box.add_child(b)
	for k in chosen.size():
		var b2 := _line_button(str(pool[chosen[k]]))
		b2.name = "Conjuro%d" % k
		b2.pressed.connect(unpick.bind(k))
		_spell_box.add_child(b2)
	if chosen.is_empty():
		_spell_box.add_child(UI.label("(vacío)", "MutedLabel"))


## Agrega la línea suelta `i` al final del conjuro.
func pick(i: int) -> void:
	if i >= 0 and i < pool.size() and not chosen.has(i):
		chosen.append(i)
		_refresh()


## Devuelve la línea en la posición `k` del conjuro a las sueltas.
func unpick(k: int) -> void:
	if k >= 0 and k < chosen.size():
		chosen.remove_at(k)
		_refresh()


func chosen_lines() -> Array:
	var out: Array = []
	for i in chosen:
		out.append(pool[i])
	return out


func launch() -> Dictionary:
	var r := MinigameLogic.check_order(current_round(), chosen_lines())
	_output_label.text = MinigameLogic.preview(MinigameLogic.run_round(current_round(), chosen_lines()), 6) if not chosen.is_empty() else ""
	if r["status"] != "success":
		SceneManager.show_result({"success": false, "title": r["title"], "message": r["message"], "detail": r["detail"], "creature": r["creature"]})
		return r
	round_idx += 1
	_progress.value = round_idx
	await get_tree().create_timer(0.8).timeout
	if round_idx < (content["rounds"] as Array).size():
		_load_round()
		return r
	var gained := GameState.complete_house(house_id)
	SceneManager.show_result({"success": true, "xp": gained, "title": "¡Conjuro ordenado!", "message": "Ordenaste los %d conjuros." % round_idx})
	return r
