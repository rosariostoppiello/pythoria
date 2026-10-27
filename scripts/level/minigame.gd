extends Control
## Nivel (versión básica; la mecánica del Frasco llega en la fase H).


func _ready() -> void:
	SceneManager.set_state(SceneManager.State.LEVEL)
	UI.background(self)
	var id := SceneManager.house_id
	add_child(TopBar.new("Mundo %d · %s" % [SceneManager.world_id, ContentDB.house_label(id)]))
	var center := CenterContainer.new()
	add_child(UI.full_rect(center))
	var b := UI.button("Lanzar (prueba)")
	b.pressed.connect(func() -> void:
		var gained := GameState.complete_house(id)
		SceneManager.show_result({"success": true, "xp": gained}))
	center.add_child(b)
