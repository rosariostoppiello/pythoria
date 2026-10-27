extends Control
## Menú principal: Jugar / Continuar, Opciones, Salir. Byte duerme sobre los libros.

var _modal: Control


func _ready() -> void:
	SceneManager.set_state(SceneManager.State.MENU)
	UI.background(self)
	var sky: Control = load("res://scripts/ui/star_field.gd").new()
	add_child(UI.full_rect(sky))

	# Byte durmiendo sobre la pila de libros con la vela.
	var nook := Control.new()
	nook.position = Vector2(930, 430)
	add_child(nook)
	var books := UI.sprite_rect("candle_books_lit", 4.0)
	nook.add_child(books)
	var cat := UI.sprite_rect("byte_cat", 2.0)
	cat.position = Vector2(-28, -6)
	nook.add_child(cat)

	var wizard := UI.sprite_rect("player", 4.0)
	wizard.position = Vector2(150, 420)
	add_child(wizard)
	var tw := wizard.create_tween().set_loops()
	tw.tween_property(wizard, "position:y", 410.0, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(wizard, "position:y", 420.0, 1.2).set_trans(Tween.TRANS_SINE)

	var center := CenterContainer.new()
	add_child(UI.full_rect(center))
	var box := UI.vbox(14)
	box.custom_minimum_size = Vector2(360, 0)
	center.add_child(box)
	box.add_child(UI.label("PyMancer", "TitleLabel", HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("La Academia del Grimorio", "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UI.label("Aprendé Python como un aprendiz de magia", "MutedLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 24)
	box.add_child(gap)

	if SaveSystem.has_save():
		var cont := UI.button("Continuar")
		cont.name = "Continuar"
		cont.pressed.connect(_on_continue)
		box.add_child(cont)
		cont.grab_focus.call_deferred()
	var play := UI.button("Jugar", "OutlineButton" if SaveSystem.has_save() else "")
	play.name = "Jugar"
	play.pressed.connect(_on_play)
	box.add_child(play)
	if not SaveSystem.has_save():
		play.grab_focus.call_deferred()
	var opts := UI.button("Opciones", "OutlineButton")
	opts.pressed.connect(_show_options)
	box.add_child(opts)
	if not OS.has_feature("web"):
		var quit := UI.button("Salir", "OutlineButton")
		quit.pressed.connect(get_tree().quit)
		box.add_child(quit)


func _on_continue() -> void:
	GameState.load_from_save()
	SceneManager.goto_world_map()


func _on_play() -> void:
	if SaveSystem.has_save():
		_confirm_new_game()
		return
	_start_new_game()


func _start_new_game() -> void:
	GameState.reset()
	GameState.save()
	SceneManager.goto_world_map()


func _confirm_new_game() -> void:
	var box := _open_modal("¿Empezar de cero?")
	box.add_child(UI.label("Ya tenés una partida guardada.\nSi empezás de nuevo se borra tu progreso.", "", HORIZONTAL_ALIGNMENT_CENTER))
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var yes := UI.button("Sí, empezar")
	yes.pressed.connect(_start_new_game)
	var no := UI.button("Cancelar", "OutlineButton")
	no.pressed.connect(_close_modal)
	row.add_child(yes)
	row.add_child(no)
	box.add_child(row)
	no.grab_focus.call_deferred()


func _show_options() -> void:
	var box := _open_modal("Opciones")
	box.add_child(UI.label("Volumen (todavía no hay sonidos)"))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = db_to_linear(AudioServer.get_bus_volume_db(0))
	slider.custom_minimum_size = Vector2(320, 24)
	slider.value_changed.connect(func(v: float) -> void: AudioServer.set_bus_volume_db(0, linear_to_db(v)))
	box.add_child(slider)
	var close := UI.button("Cerrar")
	close.pressed.connect(_close_modal)
	box.add_child(close)
	close.grab_focus.call_deferred()


func _open_modal(title: String) -> VBoxContainer:
	_close_modal()
	_modal = ColorRect.new()
	(_modal as ColorRect).color = ThemeColors.SOMBRA
	add_child(UI.full_rect(_modal))
	var center := CenterContainer.new()
	_modal.add_child(UI.full_rect(center))
	var panel := UI.panel("DarkPanel")
	center.add_child(panel)
	var box := UI.vbox(16)
	panel.add_child(box)
	box.add_child(UI.label(title, "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER))
	return box


func _close_modal() -> void:
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
