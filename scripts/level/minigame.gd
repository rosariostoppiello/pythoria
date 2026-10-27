extends Control
## Minijuego "Completa el hechizo": se arrastran fichas de código a los huecos ____.

var house_id: String
var content: Dictionary
var round_idx := 0
## Ficha elegida para cada hueco de la ronda actual ("" = vacío).
var choices: Array = []

var blanks: Array[DropSlot] = []
var _code_box: VBoxContainer
var _chip_row: HFlowContainer
var _round_label: Label
var _expected_label: Label
var _output_label: Label
var _progress: ProgressBar


func _ready() -> void:
	SceneManager.set_state(SceneManager.State.LEVEL)
	house_id = SceneManager.house_id
	content = ContentDB.get_content(house_id)
	UI.background(self)
	add_child(TopBar.new("Mundo %d · %s" % [ContentDB.world_of(house_id), content.get("title", "Minijuego")]))

	var main := UI.hbox(16)
	main.position = Vector2(16, 70)
	main.size = Vector2(1248, 640)
	add_child(main)

	var left := UI.vbox(12)
	left.custom_minimum_size = Vector2(370, 0)
	main.add_child(left)
	var mission := UI.panel()
	left.add_child(mission)
	var mbox := UI.vbox(8)
	mission.add_child(mbox)
	mbox.add_child(UI.label(str(content.get("title", "")), "InkTitle"))
	var how := UI.label("Arrastrá (o tocá) una ficha para completar cada hueco del hechizo. Después lanzalo y fijate qué imprime.", "InkLabel")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(330, 0)
	mbox.add_child(how)
	_expected_label = UI.label("", "InkLabel")
	mbox.add_child(_expected_label)
	var side := UI.panel("DarkPanel")
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(side)
	var sbox := UI.vbox(10)
	sbox.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_child(sbox)
	sbox.add_child(UI.sprite_rect("owl", 3.0))
	_round_label = UI.label("", "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	sbox.add_child(_round_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(300, 18)
	_progress.show_percentage = false
	_progress.max_value = (content["rounds"] as Array).size()
	sbox.add_child(_progress)

	var right := UI.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	var code_panel := UI.panel("CodePanel")
	right.add_child(code_panel)
	_code_box = UI.vbox(10)
	code_panel.add_child(_code_box)

	var tray := UI.panel("DarkPanel")
	right.add_child(tray)
	var tbox := UI.vbox(6)
	tray.add_child(tbox)
	tbox.add_child(UI.label("Fichas", "MutedLabel"))
	_chip_row = HFlowContainer.new()
	_chip_row.add_theme_constant_override("h_separation", 12)
	tbox.add_child(_chip_row)

	var out_panel := UI.panel("CodePanel")
	right.add_child(out_panel)
	var obox := UI.vbox(4)
	out_panel.add_child(obox)
	obox.add_child(UI.label("Salida", "MutedLabel"))
	_output_label = UI.label("", "CodeLabel")
	obox.add_child(_output_label)

	right.add_child(UI.spacer())
	var actions := UI.hbox(12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(actions)
	var launch_btn := UI.button("Lanzar", "", 220)
	launch_btn.name = "Lanzar"
	launch_btn.focus_mode = Control.FOCUS_NONE
	launch_btn.pressed.connect(launch)
	actions.add_child(launch_btn)
	var clear_btn := UI.button("Vaciar huecos", "OutlineButton")
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.pressed.connect(func() -> void:
		for i in choices.size():
			choices[i] = ""
		_refresh())
	actions.add_child(clear_btn)
	_load_round()


func current_round() -> Dictionary:
	return content["rounds"][round_idx]


func _load_round() -> void:
	var r := current_round()
	for c in _code_box.get_children():
		c.queue_free()
	for c in _chip_row.get_children():
		c.queue_free()
	blanks.clear()
	choices.clear()
	for line: String in r["code"]:
		var row := UI.hbox(4)
		_code_box.add_child(row)
		var parts := line.split(MinigameLogic.BLANK)
		for i in parts.size():
			if parts[i] != "":
				row.add_child(UI.label(parts[i], "CodeLabel"))
			if i < parts.size() - 1:
				var idx := blanks.size()
				var slot := DropSlot.new("____", Vector2(110, 40))
				slot.name = "Blank%d" % idx
				slot.accepts = func(d: Dictionary) -> bool: return d.has("code")
				slot.dropped.connect(func(d: Dictionary) -> void: set_choice(idx, str(d["code"])))
				slot.clicked.connect(set_choice.bind(idx, ""))
				blanks.append(slot)
				choices.append("")
				row.add_child(slot)
	for t: Variant in r["tokens"]:
		var text := str(t)
		var chip := TokenChip.new(text, TokenChip.color_for_code(text), {"code": text})
		chip.clicked.connect(_on_chip_clicked.bind(text))
		_chip_row.add_child(chip)
	_round_label.text = "Ronda %d de %d" % [round_idx + 1, (content["rounds"] as Array).size()]
	_progress.value = round_idx
	_expected_label.text = "Tiene que imprimir: %s" % r["output"]
	_output_label.text = ""
	_refresh()


func set_choice(idx: int, code: String) -> void:
	if idx >= 0 and idx < choices.size():
		choices[idx] = code
		_refresh()


## Tocar una ficha la pone en el primer hueco vacío.
func _on_chip_clicked(code: String) -> void:
	var empty := choices.find("")
	if empty >= 0:
		set_choice(empty, code)


func _refresh() -> void:
	for i in blanks.size():
		var c: String = choices[i]
		blanks[i].show_token(c, TokenChip.color_for_code(c) if c != "" else null)


func launch() -> Dictionary:
	var r := MinigameLogic.check(current_round(), choices)
	_output_label.text = r["output"] if r["output"] != "" else ("(error)" if r["status"] != "success" else "")
	if r["status"] != "success":
		SceneManager.show_result({"success": false, "title": r["title"], "message": r["message"], "detail": r["detail"], "creature": r["creature"]})
		return r
	round_idx += 1
	_progress.value = round_idx
	await get_tree().create_timer(0.6).timeout
	if round_idx < (content["rounds"] as Array).size():
		_load_round()
		return r
	var gained := GameState.complete_house(house_id)
	SceneManager.show_result({"success": true, "xp": gained, "title": "¡Hechizo completo!", "message": "Completaste las %d rondas." % round_idx})
	return r
