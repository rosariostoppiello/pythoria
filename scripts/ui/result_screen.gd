extends CanvasLayer
## Resultado de una casita, encima del nivel.
## info: success, xp, already_done, title, message, detail, creature, is_boss.

signal retry_requested

var info: Dictionary = {}


func _ready() -> void:
	layer = 40
	var success := bool(info.get("success", false))
	var dim := ColorRect.new()
	dim.color = Color(ThemeColors.NOCHE, 0.8)
	add_child(UI.full_rect(dim))
	var center := CenterContainer.new()
	add_child(UI.full_rect(center))
	var panel := UI.panel("DarkPanel")
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := UI.vbox(14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	var art := UI.sprite_rect("star" if success else str(info.get("creature", "gremlin_sintaxis")), 4.0 if success else 3.0)
	box.add_child(art)
	if success:
		var tw := art.create_tween().set_loops()
		tw.tween_property(art, "rotation", 0.08, 0.6)
		tw.tween_property(art, "rotation", -0.08, 0.6)
		art.pivot_offset = art.custom_minimum_size / 2

	var title_text := str(info.get("title", "¡Hechizo logrado!" if success else "El hechizo falló"))
	box.add_child(UI.label(title_text, "SuccessLabel" if success else "ErrorLabel", HORIZONTAL_ALIGNMENT_CENTER))
	if str(info.get("detail", "")) != "":
		var code := UI.panel("CodePanel")
		code.add_child(UI.label(str(info["detail"]), "CodeLabel"))
		box.add_child(code)
	if str(info.get("message", "")) != "":
		var msg := UI.label(str(info["message"]), "", HORIZONTAL_ALIGNMENT_CENTER)
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg.custom_minimum_size = Vector2(500, 0)
		box.add_child(msg)
	if success:
		var gained := int(info.get("xp", 0))
		if gained > 0:
			box.add_child(UI.label("+%d XP" % gained, "RewardLabel", HORIZONTAL_ALIGNMENT_CENTER))
		else:
			box.add_child(UI.label("Ya habías resuelto esta casita: no suma XP de nuevo.", "MutedLabel", HORIZONTAL_ALIGNMENT_CENTER))

	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var first: Button
	if success:
		var is_boss := bool(info.get("is_boss", false))
		first = _add(row, "Continuar", "", SceneManager.goto_world_map if is_boss else SceneManager.back_to_section)
		_add(row, "Repetir", "OutlineButton", SceneManager.retry)
	else:
		first = _add(row, "Reintentar", "", _retry_now)
		_add(row, "Volver al mapa", "OutlineButton", SceneManager.back_to_section)
	first.grab_focus.call_deferred()


## Reintento inmediato: se cierra el resultado y el tablero queda como estaba.
func _retry_now() -> void:
	retry_requested.emit()
	SceneManager.close_result()


func _add(row: Container, text: String, variation: String, action: Callable) -> Button:
	var b := UI.button(text, variation, 180)
	b.name = text.replace(" ", "")
	b.pressed.connect(action)
	row.add_child(b)
	return b
