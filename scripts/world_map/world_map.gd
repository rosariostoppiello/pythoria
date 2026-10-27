extends Control
## Mapa de mundos (versión básica; el mapa con línea punteada llega en la fase F).


func _ready() -> void:
	SceneManager.set_state(SceneManager.State.WORLD_MAP)
	UI.background(self)
	add_child(TopBar.new("Mapa de Pythoria"))
	var box := UI.vbox(10)
	box.position = Vector2(80, 100)
	add_child(box)
	for w: Dictionary in ContentDB.worlds():
		var id := int(w["id"])
		var b := UI.button("%d. %s" % [id, w["name"]], "OutlineButton", 420)
		b.disabled = not (GameState.is_world_unlocked(id) and ContentDB.world_has_section(id))
		b.pressed.connect(SceneManager.goto_section.bind(id))
		box.add_child(b)
