extends CanvasLayer
## Pausa (Esc): Continuar, Reintentar, Volver al mapa, Menú.


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = ThemeColors.SOMBRA
	add_child(UI.full_rect(dim))
	var center := CenterContainer.new()
	add_child(UI.full_rect(center))
	var panel := UI.panel("DarkPanel")
	panel.custom_minimum_size = Vector2(380, 0)
	center.add_child(panel)
	var box := UI.vbox(14)
	panel.add_child(box)
	box.add_child(UI.label("Pausa", "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var in_level := SceneManager._state_before_pause == SceneManager.State.LEVEL
	var cont := _add(box, "Continuar", "", SceneManager.resume)
	if in_level:
		_add(box, "Reintentar", "OutlineButton", SceneManager.retry)
		_add(box, "Volver al mapa", "OutlineButton", SceneManager.back_to_section)
	else:
		_add(box, "Mapa de mundos", "OutlineButton", SceneManager.goto_world_map)
	_add(box, "Menú", "OutlineButton", SceneManager.goto_menu)
	cont.grab_focus.call_deferred()


func _add(box: Container, text: String, variation: String, action: Callable) -> Button:
	var b := UI.button(text, variation)
	b.name = text.replace(" ", "")
	b.pressed.connect(action)
	box.add_child(b)
	return b
