class_name FrascoBoard
extends VBoxContainer
## Tablero del Frasco: frascos con nombre, fichas arrastrables, operador, caldero
## y el código Python equivalente en vivo.

signal changed

var puzzle: Dictionary = {}
var tokens: Array = []
var jar_token: Array[int] = []      # por frasco: índice de ficha o -1
var op: String = ""

var chips: Array[TokenChip] = []
var slots: Array[DropSlot] = []
var op_buttons: Dictionary = {}     # op -> Button
var cauldron: TextureRect
var cauldron_expr: Label
var cauldron_result: Label
var code_label: Label
var tray: DropSlot
var crossroads: CrossroadsView
var _op_label: Label
var _chip_row: HFlowContainer


func _init(p: Dictionary) -> void:
	puzzle = p
	tokens = p.get("tokens", [])
	for j in FrascoLogic.jar_names(p):
		jar_token.append(-1)
	var ops := FrascoLogic.operators(p)
	if not FrascoLogic.needs_operator_choice(p) and ops.size() == 1:
		op = str(ops[0])
	add_theme_constant_override("separation", 14)
	_build()
	refresh()


func _build() -> void:
	# Frascos -> caldero
	var row := UI.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	var names := FrascoLogic.jar_names(puzzle)
	for i in names.size():
		row.add_child(_jar_view(i))
		if i == 0 and names.size() == 2 and not FrascoLogic.is_crossroads(puzzle):
			_op_label = UI.label("", "CodeLabel", HORIZONTAL_ALIGNMENT_CENTER)
			_op_label.custom_minimum_size = Vector2(48, 0)
			_op_label.add_theme_font_size_override("font_size", 40)
			row.add_child(_op_label)
	var arrow := UI.label("→", "CodeLabel")
	arrow.add_theme_font_size_override("font_size", 40)
	row.add_child(arrow)
	if FrascoLogic.is_crossroads(puzzle):
		crossroads = CrossroadsView.new(puzzle)
		row.add_child(crossroads)
	else:
		row.add_child(_cauldron_view())

	# Selector de operador
	if FrascoLogic.needs_operator_choice(puzzle):
		var ops_row := UI.hbox(10)
		ops_row.alignment = BoxContainer.ALIGNMENT_CENTER
		ops_row.add_child(UI.label("Operador:"))
		var group := ButtonGroup.new()
		group.allow_unpress = false
		for o: Variant in FrascoLogic.operators(puzzle):
			var b := UI.button(str(o), "OperatorButton", 64)
			b.toggle_mode = true
			b.button_group = group
			b.focus_mode = Control.FOCUS_NONE
			b.name = "Op_" + {"+": "suma", "-": "resta", "*": "por", "==": "igual", "!=": "distinto",
				"<": "menor", ">": "mayor", "<=": "menor_igual", ">=": "mayor_igual",
				"and": "and", "or": "or"}.get(str(o), "otro")
			b.pressed.connect(set_operator.bind(str(o)))
			ops_row.add_child(b)
			op_buttons[str(o)] = b
		add_child(ops_row)

	# Bandeja de fichas (también recibe fichas que vuelven de un frasco)
	tray = DropSlot.new("", Vector2(0, 64))
	tray.accepts = func(d: Dictionary) -> bool: return d.get("from_jar", -1) >= 0
	tray.dropped.connect(func(d: Dictionary) -> void: remove_from_jar(int(d["from_jar"])))
	add_child(tray)
	var tray_box := UI.vbox(6)
	tray.add_child(tray_box)
	var tray_title := UI.label("Fichas de esencia: arrastralas a un frasco (o tocalas)", "MutedLabel")
	tray_title.add_theme_font_size_override("font_size", 15)
	tray_box.add_child(tray_title)
	_chip_row = HFlowContainer.new()
	_chip_row.add_theme_constant_override("h_separation", 12)
	_chip_row.add_theme_constant_override("v_separation", 8)
	tray_box.add_child(_chip_row)
	for i in tokens.size():
		var t: Dictionary = tokens[i]
		var chip := TokenChip.new(PyEval.repr(FrascoLogic.token_value(t)), ThemeColors.essence(str(t["type"])), {"token": i, "from_jar": -1})
		chip.name = "Token%d" % i
		chip.clicked.connect(_on_chip_clicked.bind(i))
		chip.tooltip_text = _type_hint(str(t["type"]))
		chips.append(chip)
		_chip_row.add_child(chip)

	# Código Python en vivo
	var code_panel := UI.panel("CodePanel")
	var code_box := UI.vbox(4)
	code_panel.add_child(code_box)
	var code_title := UI.label("Tu hechizo en Python", "MutedLabel")
	code_title.add_theme_font_size_override("font_size", 14)
	code_box.add_child(code_title)
	code_label = UI.label("", "CodeLabel")
	code_box.add_child(code_label)
	add_child(code_panel)


func _jar_view(i: int) -> Control:
	var jar: Dictionary = puzzle["jars"][i]
	var box := UI.vbox(4)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var name_label := UI.label(str(jar["name"]), "CodeLabel", HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_font_size_override("font_size", 22)
	box.add_child(name_label)
	var sprite := UI.sprite_rect("jar", 2.0)
	sprite.self_modulate = ThemeColors.essence(str(jar.get("accepts", ""))).lerp(Color.WHITE, 0.4)
	box.add_child(sprite)
	var slot := DropSlot.new("vacío", Vector2(130, 46))
	slot.name = "Jar_" + str(jar["name"])
	slot.accepts = func(d: Dictionary) -> bool: return d.has("token")
	slot.dropped.connect(func(d: Dictionary) -> void: place(int(d["token"]), i))
	slot.clicked.connect(remove_from_jar.bind(i))
	slot.tooltip_text = "Soltá una ficha acá. Tocá para vaciar."
	slots.append(slot)
	box.add_child(slot)
	var accepts := UI.label("esencia: %s" % _type_hint(str(jar.get("accepts", ""))), "MutedLabel", HORIZONTAL_ALIGNMENT_CENTER)
	accepts.add_theme_font_size_override("font_size", 14)
	box.add_child(accepts)
	return box


func _cauldron_view() -> Control:
	var box := UI.vbox(2)
	box.custom_minimum_size = Vector2(240, 0)
	cauldron = UI.sprite_rect("cauldron", 2.0)
	cauldron.pivot_offset = cauldron.custom_minimum_size / 2
	box.add_child(cauldron)
	cauldron_expr = UI.label("", "CodeLabel", HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(cauldron_expr)
	cauldron_result = UI.label("", "CodeLabel", HORIZONTAL_ALIGNMENT_CENTER)
	cauldron_result.add_theme_font_size_override("font_size", 24)
	box.add_child(cauldron_result)
	return box


static func _type_hint(t: String) -> String:
	return {"int": "int (número)", "str": "str (texto)", "bool": "bool (verdadero/falso)"}.get(t, t)


# --- Estado -------------------------------------------------------------------

func token_jar(token_idx: int) -> int:
	return jar_token.find(token_idx)


## Pone una ficha en un frasco. Si el frasco tenía otra, esa vuelve a la bandeja.
func place(token_idx: int, jar_idx: int) -> void:
	if token_idx < 0 or token_idx >= tokens.size() or jar_idx < 0 or jar_idx >= jar_token.size():
		return
	var prev := token_jar(token_idx)
	if prev >= 0:
		jar_token[prev] = -1
	jar_token[jar_idx] = token_idx
	refresh()


func remove_from_jar(jar_idx: int) -> void:
	if jar_idx >= 0 and jar_idx < jar_token.size():
		jar_token[jar_idx] = -1
		refresh()


func set_operator(o: String) -> void:
	op = o
	if op_buttons.has(o):
		(op_buttons[o] as Button).set_pressed_no_signal(true)
	refresh()


func clear() -> void:
	for i in jar_token.size():
		jar_token[i] = -1
	refresh()


## Tocar una ficha la pone en el primer frasco vacío.
func _on_chip_clicked(token_idx: int) -> void:
	var empty := jar_token.find(-1)
	if empty >= 0:
		place(token_idx, empty)


## Valores de los frascos llenos (nombre -> valor).
func values() -> Dictionary:
	var out := {}
	var names := FrascoLogic.jar_names(puzzle)
	for i in names.size():
		if jar_token[i] >= 0:
			out[names[i]] = FrascoLogic.token_value(tokens[jar_token[i]])
	return out


func cast() -> Dictionary:
	var r := FrascoLogic.check(puzzle, values(), op)
	if crossroads:
		crossroads.highlight(r.get("path"), r["status"] == "success")
		return r
	if r["value"] != null or r["status"] == "success":
		cauldron_result.text = "= " + PyEval.repr(r["value"])
	else:
		cauldron_result.text = "= ¡error!"
	var color := ThemeColors.TURQUESA if r["status"] == "success" else ThemeColors.ROJO
	cauldron_result.add_theme_color_override("font_color", color)
	var tw := create_tween()
	tw.tween_property(cauldron, "modulate", color.lightened(0.3), 0.15)
	tw.parallel().tween_property(cauldron, "scale", Vector2(1.12, 1.12), 0.15)
	tw.tween_property(cauldron, "modulate", Color.WHITE, 0.35)
	tw.parallel().tween_property(cauldron, "scale", Vector2.ONE, 0.35)
	return r


func refresh() -> void:
	var names := FrascoLogic.jar_names(puzzle)
	for i in chips.size():
		chips[i].visible = token_jar(i) < 0
	for i in slots.size():
		var t := jar_token[i]
		if t >= 0:
			var tok: Dictionary = tokens[t]
			slots[i].show_token(PyEval.repr(FrascoLogic.token_value(tok)), ThemeColors.essence(str(tok["type"])))
			slots[i].drag_payload = {"token": t, "from_jar": i}
		else:
			slots[i].show_token("")
			slots[i].drag_payload = {}
	if crossroads:
		crossroads.set_operator(op)
	else:
		cauldron_expr.text = FrascoLogic.resolve(puzzle, op if op != "" else "?")
		cauldron_result.text = ""
	var expr := FrascoLogic.resolve(puzzle, op if op != "" else "?")
	# Entre los dos frascos se ve el operador si la expresión es "a op b".
	if _op_label and names.size() == 2:
		var parts := expr.split(" ")
		_op_label.text = parts[1] if parts.size() == 3 and parts[0] == names[0] and parts[2] == names[1] else ""
	code_label.text = "\n".join(FrascoLogic.code_lines(puzzle, values(), op))
	changed.emit()
