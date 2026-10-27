extends Control
## Casita de un mundo placeholder: "Próximamente". En debug se puede marcar como completada.


func _ready() -> void:
	SceneManager.set_state(SceneManager.State.LEVEL)
	UI.background(self)
	var house_id := SceneManager.house_id
	var world := ContentDB.get_world(SceneManager.world_id)
	add_child(TopBar.new("Mundo %d · %s" % [SceneManager.world_id, ContentDB.house_label(house_id)]))
	var center := CenterContainer.new()
	add_child(UI.full_rect(center))
	var panel := UI.panel()
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var box := UI.vbox(16)
	panel.add_child(box)
	box.add_child(UI.sprite_rect("owl", 3.0))
	box.add_child(UI.label("Próximamente", "InkTitle", HORIZONTAL_ALIGNMENT_CENTER))
	var msg := UI.label("Ada todavía está escribiendo los hechizos de %s.\nTemas: %s." % [world.get("name", ""), ", ".join(world.get("topics", []))], "InkLabel", HORIZONTAL_ALIGNMENT_CENTER)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(msg)
	var row := UI.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	var back := UI.button("Volver al mapa")
	back.pressed.connect(SceneManager.back_to_section)
	row.add_child(back)
	back.grab_focus.call_deferred()
	if OS.is_debug_build():
		var done := UI.button("Completar (debug)", "OutlineButton")
		done.name = "CompletarDebug"
		done.pressed.connect(_debug_complete)
		row.add_child(done)


func _debug_complete() -> void:
	GameState.complete_house(SceneManager.house_id)
	if ContentDB.house_kind(SceneManager.house_id) == "boss":
		SceneManager.goto_world_map()
	else:
		SceneManager.back_to_section()
