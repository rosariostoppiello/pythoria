extends Node2D
## Mapa de sección (versión básica; el aprendiz caminando llega en la fase E).


func _ready() -> void:
	SceneManager.set_state(SceneManager.State.SECTION_MAP)
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	ui.add_child(UI.full_rect(root))
	UI.background(root)
	var world_id := SceneManager.world_id
	root.add_child(TopBar.new("Mundo %d · %s" % [world_id, ContentDB.get_world(world_id).get("name", "")]))
	var box := UI.vbox(10)
	box.position = Vector2(80, 100)
	root.add_child(box)
	for id: String in ContentDB.house_ids(world_id):
		var b := UI.button("%s (%s)" % [ContentDB.house_label(id), GameState.house_state(id)], "OutlineButton", 360)
		b.disabled = GameState.house_state(id) == "locked"
		b.pressed.connect(SceneManager.goto_house.bind(id))
		box.add_child(b)
