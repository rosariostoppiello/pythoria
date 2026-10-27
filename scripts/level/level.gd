extends Control
## Nivel del Frasco o de la Encrucijada. También corre el boss (varias rondas con barra de vida).

var house_id: String
var content: Dictionary
var is_boss := false
var round_idx := 0
var board: FrascoBoard

var _board_holder: VBoxContainer
var _left: VBoxContainer
var _hint_label: Label
var _hint_button: Button
var _reward_label: Label
var _candle: TextureRect
var _enemy: TextureRect
var _health: ProgressBar
var _round_label: Label
var _launch: Button
var _shown_hints := 0


func _ready() -> void:
	SceneManager.set_state(SceneManager.State.LEVEL)
	house_id = SceneManager.house_id
	content = ContentDB.get_content(house_id)
	is_boss = content.has("rounds")
	UI.background(self)
	var world_id := ContentDB.world_of(house_id)
	add_child(TopBar.new("Mundo %d · %s" % [world_id, ContentDB.house_label(house_id)]))

	var main := UI.hbox(16)
	main.position = Vector2(16, 70)
	main.size = Vector2(1248, 640)
	add_child(main)
	_left = UI.vbox(12)
	_left.custom_minimum_size = Vector2(370, 0)
	main.add_child(_left)
	var right := UI.vbox(12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	_board_holder = UI.vbox(0)
	_board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_board_holder)

	var actions := UI.hbox(12)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(actions)
	_launch = UI.button("Lanzar", "", 220)
	_launch.name = "Lanzar"
	_launch.focus_mode = Control.FOCUS_NONE
	_launch.pressed.connect(launch)
	actions.add_child(_launch)
	var reset := UI.button("Vaciar frascos", "OutlineButton")
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func() -> void: board.clear())
	actions.add_child(reset)

	if is_boss:
		_build_boss_panel()
	else:
		_build_mission_panel(content)
		_build_ada_panel()
	_load_board()


func current_puzzle() -> Dictionary:
	return content["rounds"][round_idx] if is_boss else content


func _load_board() -> void:
	if board:
		board.queue_free()
	board = FrascoBoard.new(current_puzzle())
	_board_holder.add_child(board)
	if is_boss:
		_round_label.text = "Ronda %d de %d" % [round_idx + 1, (content["rounds"] as Array).size()]
		_refresh_boss_goal()


# --- Paneles ------------------------------------------------------------------

func _build_mission_panel(p: Dictionary) -> void:
	var panel := UI.panel()
	_left.add_child(panel)
	var box := UI.vbox(8)
	panel.add_child(box)
	box.add_child(UI.label(str(p.get("title", "")), "InkTitle"))
	var story := UI.label(str(p.get("story", "")), "InkLabel")
	story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story.custom_minimum_size = Vector2(330, 0)
	box.add_child(story)
	box.add_child(_goal_row(p))


func _goal_row(p: Dictionary) -> Control:
	var row := UI.hbox(8)
	row.name = "GoalRow"
	row.add_child(UI.label("Llegá a:" if FrascoLogic.is_crossroads(p) else "El caldero pide:", "InkLabel"))
	var gt := FrascoLogic.goal_type(p)
	var chip := TokenChip.new(PyEval.repr(FrascoLogic.goal_value(p)), ThemeColors.essence(gt))
	chip.draggable = false
	chip.mouse_default_cursor_shape = Control.CURSOR_ARROW
	row.add_child(chip)
	var t := UI.label("(%s)" % gt, "InkLabel")
	t.modulate.a = 0.7
	row.add_child(t)
	return row


func _build_ada_panel() -> void:
	var panel := UI.panel("DarkPanel")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(panel)
	var box := UI.vbox(8)
	panel.add_child(box)
	var row := UI.hbox(6)
	row.add_child(UI.sprite_rect("ada", 2.0))
	row.add_child(UI.sprite_rect("owl", 1.0))
	_candle = UI.sprite_rect("candle_books", 1.5)
	row.add_child(_candle)
	box.add_child(row)
	var bubble := UI.panel()
	box.add_child(bubble)
	_hint_label = UI.label("Ada: \"Si te trabás, el búho tiene una pista. Cada pista cuesta XP, pero nunca te bloquea.\"", "InkLabel")
	_hint_label.add_theme_font_size_override("font_size", 17)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(320, 0)
	bubble.add_child(_hint_label)
	_hint_button = UI.button("Pedir pista", "OutlineButton")
	_hint_button.name = "PedirPista"
	_hint_button.focus_mode = Control.FOCUS_NONE
	_hint_button.pressed.connect(request_hint)
	box.add_child(_hint_button)
	_reward_label = UI.label("", "MutedLabel")
	box.add_child(_reward_label)
	# Las pistas ya pagadas se vuelven a mostrar sin costo.
	_shown_hints = GameState.hints_for(house_id)
	_update_hints()


func _build_boss_panel() -> void:
	var panel := UI.panel("DarkPanel")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(panel)
	var box := UI.vbox(10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	box.add_child(UI.label(str(content.get("title", "Boss")), "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	# El sprite va dentro de un contenedor fijo para que el balanceo no mueva el layout.
	_enemy = UI.sprite_rect(str(content.get("enemy", "gremlin_sintaxis")), 4.0)
	_enemy.pivot_offset = _enemy.custom_minimum_size / 2
	var holder := CenterContainer.new()
	holder.custom_minimum_size = _enemy.custom_minimum_size + Vector2(0, 16)
	var inner := Control.new()
	inner.custom_minimum_size = _enemy.custom_minimum_size
	inner.add_child(_enemy)
	holder.add_child(inner)
	box.add_child(holder)
	var bob := _enemy.create_tween().set_loops()
	bob.tween_property(_enemy, "position:y", -6.0, 0.5).as_relative().set_trans(Tween.TRANS_SINE)
	bob.tween_property(_enemy, "position:y", 6.0, 0.5).as_relative().set_trans(Tween.TRANS_SINE)
	_health = ProgressBar.new()
	_health.theme_type_variation = "HealthBar"
	_health.custom_minimum_size = Vector2(300, 22)
	_health.max_value = (content["rounds"] as Array).size()
	_health.value = _health.max_value
	_health.show_percentage = false
	box.add_child(_health)
	_round_label = UI.label("", "MutedLabel", HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_round_label)
	var goal_panel := UI.panel()
	goal_panel.name = "BossGoal"
	box.add_child(goal_panel)
	var taunt := UI.label(str(content.get("taunt", "Acertá cada hechizo para bajarle la vida.")), "")
	taunt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	taunt.custom_minimum_size = Vector2(320, 0)
	taunt.add_theme_font_size_override("font_size", 16)
	box.add_child(taunt)


func _refresh_boss_goal() -> void:
	var holder: PanelContainer = _left.find_child("BossGoal", true, false)
	for c in holder.get_children():
		c.queue_free()
	holder.add_child(_goal_row(current_puzzle()))


func _update_hints() -> void:
	var hints: Array = content.get("hints", [])
	var shown := mini(_shown_hints, hints.size())
	if shown > 0:
		var lines: PackedStringArray = []
		for i in shown:
			lines.append("%d. %s" % [i + 1, hints[i]])
		_hint_label.text = "\n".join(lines)
	_candle.texture = UI.tex("candle_books_lit" if shown > 0 else "candle_books")
	var cost := int(ContentDB.xp_config()["hint_cost"])
	_hint_button.disabled = shown >= hints.size()
	_hint_button.text = "Pedir pista (-%d XP)" % cost if shown < hints.size() else "No hay más pistas"
	if GameState.is_completed(house_id):
		_reward_label.text = "Ya completaste este nivel"
	else:
		_reward_label.text = "Recompensa: %d XP" % GameState.reward_for(house_id)


## Muestra la siguiente pista de Ada (concepto, estructura, solución parcial).
func request_hint() -> void:
	var hints: Array = content.get("hints", [])
	if _shown_hints >= hints.size():
		return
	_shown_hints += 1
	if _shown_hints > GameState.hints_for(house_id):
		GameState.use_hint(house_id)
	_update_hints()
	var tw := _candle.create_tween()
	_candle.pivot_offset = _candle.custom_minimum_size / 2
	tw.tween_property(_candle, "scale", Vector2(1.2, 1.2), 0.12)
	tw.tween_property(_candle, "scale", Vector2.ONE, 0.2)


# --- Lanzar -------------------------------------------------------------------

func launch() -> Dictionary:
	var r := board.cast()
	if r["status"] != "success":
		await get_tree().create_timer(0.35).timeout
		SceneManager.show_result({
			"success": false,
			"title": r["title"],
			"message": r["message"],
			"detail": r["detail"],
			"creature": r["creature"],
		})
		return r
	if is_boss:
		await _boss_round_won()
		return r
	await get_tree().create_timer(0.5).timeout
	var gained := GameState.complete_house(house_id)
	SceneManager.show_result({"success": true, "xp": gained, "title": r["title"], "message": r["message"]})
	return r


func _boss_round_won() -> void:
	_health.value -= 1
	var shake := create_tween()
	shake.tween_property(_enemy, "modulate", ThemeColors.TURQUESA, 0.1)
	shake.tween_property(_enemy, "rotation", 0.25, 0.08)
	shake.tween_property(_enemy, "rotation", -0.25, 0.08)
	shake.tween_property(_enemy, "rotation", 0.0, 0.08)
	shake.tween_property(_enemy, "modulate", Color.WHITE, 0.2)
	await shake.finished
	round_idx += 1
	if round_idx < (content["rounds"] as Array).size():
		_load_board()
		return
	var fade := create_tween()
	fade.tween_property(_enemy, "modulate:a", 0.0, 0.4)
	await fade.finished
	var gained := GameState.complete_house(house_id)
	SceneManager.show_result({
		"success": true,
		"xp": gained,
		"is_boss": true,
		"title": "¡Venciste al %s!" % str(content.get("title", "boss")).replace("El ", ""),
		"message": str(content.get("victory", "Se abre el camino al siguiente mundo.")),
	})
