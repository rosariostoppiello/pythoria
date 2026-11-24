extends Control
## Minijuego "Bola de cristal": leer un código y predecir qué imprime (o qué error da).
## También corre la "Trivia del aula" (kind = trivia_del_aula): preguntas con una
## respuesta fija en el JSON y, si hace falta, un código para leer.

var house_id: String
var content: Dictionary
var round_idx := 0
var option_buttons: Array[Button] = []

var _code_label: Label
var _options_box: VBoxContainer
var _round_label: Label
var _progress: ProgressBar
var _ball: TextureRect
var _question_label: Label
var _code_panel: PanelContainer
var is_trivia := false


func _ready() -> void:
	SceneManager.set_state(SceneManager.State.LEVEL)
	house_id = SceneManager.house_id
	content = ContentDB.get_content(house_id)
	is_trivia = str(content.get("kind", "")) == "trivia_del_aula"
	UI.background(self)
	add_child(TopBar.for_activity("Mundo %d · %s" % [ContentDB.world_of(house_id), content.get("title", "Minijuego")]))

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
	var how_text := "La bola de cristal muestra un hechizo. Seguilo línea por línea y elegí qué va a pasar: qué imprime, o qué error da."
	if is_trivia:
		how_text = "El búho de Ada toma examen. Leé cada pregunta con calma y elegí la respuesta correcta."
	var how := UI.label(how_text, "InkLabel")
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size = Vector2(330, 0)
	mbox.add_child(how)
	var side := UI.panel("DarkPanel")
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(side)
	var sbox := UI.vbox(10)
	sbox.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_child(sbox)
	_ball = UI.sprite_rect("owl" if is_trivia else "crystal_ball", 3.0)
	_ball.pivot_offset = _ball.custom_minimum_size / 2
	sbox.add_child(_ball)
	var glow := _ball.create_tween().set_loops()
	glow.tween_property(_ball, "modulate", Color(1.15, 1.1, 1.3), 1.0).set_trans(Tween.TRANS_SINE)
	glow.tween_property(_ball, "modulate", Color.WHITE, 1.0).set_trans(Tween.TRANS_SINE)
	_round_label = UI.label("", "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	sbox.add_child(_round_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(300, 18)
	_progress.show_percentage = false
	_progress.max_value = (content["rounds"] as Array).size()
	sbox.add_child(_progress)

	var right := UI.vbox(16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	_question_label = UI.label("", "HeaderLabel")
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_label.visible = is_trivia
	right.add_child(_question_label)
	_code_panel = UI.panel("CodePanel")
	right.add_child(_code_panel)
	var cbox := UI.vbox(6)
	_code_panel.add_child(cbox)
	cbox.add_child(UI.label("El código" if is_trivia else "El hechizo", "MutedLabel"))
	_code_label = UI.label("", "CodeLabel")
	_code_label.add_theme_font_size_override("font_size", 20 if is_trivia else 22)
	cbox.add_child(_code_label)
	if not is_trivia:
		right.add_child(UI.label("¿Qué va a pasar?", "HeaderLabel"))
	_options_box = UI.vbox(10)
	right.add_child(_options_box)
	_load_round()


func current_round() -> Dictionary:
	return content["rounds"][round_idx]


func _load_round() -> void:
	var r := current_round()
	_question_label.text = str(r.get("question", ""))
	_code_panel.visible = r.has("code")
	_code_label.text = "\n".join(r.get("code", []))
	var inputs: Array = r.get("inputs", [])
	if not inputs.is_empty():
		_code_label.text += "\n\n# entrada para input(): %s" % " / ".join(PackedStringArray(inputs.map(func(v: Variant) -> String: return str(v))))
	for b in option_buttons:
		b.queue_free()
	option_buttons.clear()
	for opt: Variant in r["options"]:
		var text := str(opt)
		var b := UI.button(text, "OperatorButton")
		b.add_theme_font_size_override("font_size", 20)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(choose.bind(text))
		option_buttons.append(b)
		_options_box.add_child(b)
	_round_label.text = "Ronda %d de %d" % [round_idx + 1, (content["rounds"] as Array).size()]
	_progress.value = round_idx


func choose(option: String) -> Dictionary:
	var r := MinigameLogic.check_trivia(current_round(), option) if is_trivia else MinigameLogic.check_prediction(current_round(), option)
	if r["status"] != "success":
		SceneManager.show_result({"success": false, "title": r["title"], "message": r["message"], "detail": r["detail"], "creature": r["creature"]})
		return r
	for b in option_buttons:
		b.disabled = b.text != option
	round_idx += 1
	_progress.value = round_idx
	await get_tree().create_timer(0.6).timeout
	if round_idx < (content["rounds"] as Array).size():
		_load_round()
		return r
	var gained := GameState.complete_house(house_id)
	if is_trivia:
		SceneManager.show_result({"success": true, "xp": gained, "title": "¡Examen aprobado!", "message": "Respondiste las %d preguntas." % round_idx})
	else:
		SceneManager.show_result({"success": true, "xp": gained, "title": "¡Lo viste venir!", "message": "Predijiste las %d rondas." % round_idx})
	return r
