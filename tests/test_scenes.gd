extends TestCase
## Humo: cada escena carga y corre unos frames sin romperse.


func _smoke(path: String, frames: int = 5) -> Node:
	var packed := load(path) as PackedScene
	check(packed != null, "no carga " + path)
	if packed == null:
		return null
	var node := packed.instantiate()
	tree.root.add_child(node)
	for i in frames:
		await tree.process_frame
	check(node.is_inside_tree(), "la escena se cayó: " + path)
	return node


func before_each() -> void:
	SaveSystem.save_path = "user://test_save.json"
	GameState.reset()
	SceneManager.world_id = 1
	SceneManager.house_id = "w1_l1"


func after_each() -> void:
	SaveSystem.delete_save()
	SaveSystem.save_path = SaveSystem.DEFAULT_PATH
	GameState.load_from_save()


func test_escenas_principales() -> void:
	for key: String in SceneManager.SCENES:
		var node: Node = await _smoke(SceneManager.SCENES[key])
		if node:
			node.queue_free()
	await tree.process_frame


func test_overlays() -> void:
	for path: String in [SceneManager.PAUSE_SCENE, SceneManager.RESULT_SCENE]:
		var node: Node = await _smoke(path)
		if node:
			node.queue_free()
	await tree.process_frame
