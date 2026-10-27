extends TestCase
## Mapas de sección generados desde el JSON y casitas placeholder.


func before_each() -> void:
	SaveSystem.save_path = "user://test_save.json"
	GameState.reset()


func after_each() -> void:
	SaveSystem.delete_save()
	SaveSystem.save_path = SaveSystem.DEFAULT_PATH
	GameState.load_from_save()


func test_mapas_de_mundos_jugables() -> void:
	for id in [1, 2, 3]:
		SceneManager.world_id = id
		var map: Node2D = load("res://scenes/section_map/section_map.tscn").instantiate()
		tree.root.add_child(map)
		await tree.process_frame
		check_eq(map.houses.size(), 7, "mundo %d tiene 7 casitas" % id)
		var expected := ContentDB.house_ids(id)
		for i in map.houses.size():
			var h: House = map.houses[i]
			check_eq(h.house_id, expected[i], "orden de casitas en mundo %d" % id)
			var cell: Vector2i = map.layout.houses[i]["tile"]
			var pos: Array = ContentDB.get_house(h.house_id)["pos"]
			check_eq(cell, Vector2i(int(pos[0]), int(pos[1])), "posición de %s" % h.house_id)
		map.queue_free()
	await tree.process_frame


func test_estados_visuales() -> void:
	GameState.completed.assign(["w1_l1"])
	SceneManager.world_id = 1
	var map: Node2D = load("res://scenes/section_map/section_map.tscn").instantiate()
	tree.root.add_child(map)
	await tree.process_frame
	check_eq(map.houses[0].state, "done", "casita 1 completada")
	check_eq(map.houses[1].state, "open", "casita 2 disponible")
	check_eq(map.houses[2].state, "locked", "casita 3 bloqueada")
	check(map.houses[0]._sprite.texture == UI.tex("house_done"), "sprite con estrella")
	check(map.houses[1]._sprite.texture == UI.tex("house_open"), "sprite con luz")
	check(map.houses[2]._sprite.texture == UI.tex("house_locked"), "sprite con candado")
	map.queue_free()
	await tree.process_frame


func test_placeholder_proximamente() -> void:
	GameState.completed.append("w1_boss")
	SceneManager.world_id = 2
	SceneManager.house_id = "w2_l1"
	check(ContentDB.get_content("w2_l1").is_empty(), "mundo 2 no tiene contenido todavía")
	var scene: Control = load("res://scenes/level/coming_soon.tscn").instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var debug_btn := scene.find_child("CompletarDebug", true, false)
	check_eq(debug_btn != null, OS.is_debug_build(), "botón debug solo en builds de debug")
	if debug_btn:
		(debug_btn as Button).pressed.emit()
		check(GameState.is_completed("w2_l1"), "el botón debug completa la casita")
		check_eq(GameState.house_state("w2_l2"), "open", "y abre la siguiente")
	scene.queue_free()
	await tree.process_frame
	await tree.create_timer(0.5).timeout
	# El botón debug cambia de escena: limpiar la escena que quedó cargada.
	if tree.current_scene:
		tree.current_scene.queue_free()
	await tree.process_frame
