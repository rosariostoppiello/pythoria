extends TestCase
## Transiciones reales entre escenas con SceneManager, pausa y estados.


func before_each() -> void:
	SaveSystem.save_path = "user://test_save.json"
	GameState.reset()


func after_each() -> void:
	tree.paused = false
	if tree.current_scene:
		tree.current_scene.queue_free()
		tree.current_scene = null
	await tree.process_frame
	SaveSystem.delete_save()
	SaveSystem.save_path = SaveSystem.DEFAULT_PATH
	GameState.load_from_save()


func _settle() -> void:
	while SceneManager._busy:
		await tree.process_frame
	await tree.process_frame


func _scene_file() -> String:
	return tree.current_scene.scene_file_path if tree.current_scene else ""


func test_flujo_menu_mapa_casita() -> void:
	SceneManager.goto_menu()
	await _settle()
	check_eq(_scene_file(), SceneManager.SCENES["menu"], "menú")
	check_eq(SceneManager.state, SceneManager.State.MENU, "estado MENU")
	SceneManager.goto_world_map()
	await _settle()
	check_eq(SceneManager.state, SceneManager.State.WORLD_MAP, "estado WORLD_MAP")
	SceneManager.goto_section(1)
	await _settle()
	check_eq(_scene_file(), SceneManager.SCENES["section_map"], "mapa de sección")
	check_eq(SceneManager.state, SceneManager.State.SECTION_MAP, "estado SECTION_MAP")
	var cases := {"w1_l1": "level", "w1_mini": "minigame", "w1_boss": "level", "w2_l1": "coming_soon"}
	for house: String in cases:
		SceneManager.goto_house(house)
		await _settle()
		check_eq(_scene_file(), SceneManager.SCENES[cases[house]], "escena de " + house)
		check_eq(SceneManager.state, SceneManager.State.LEVEL, "estado LEVEL en " + house)


func test_pausa_con_escape() -> void:
	SceneManager.goto_house("w1_l1")
	await _settle()
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	SceneManager._unhandled_input(esc)
	check(tree.paused, "Esc pausa el juego")
	check_eq(SceneManager.state, SceneManager.State.PAUSED, "estado PAUSED")
	check(tree.current_scene.has_node("PauseOverlay"), "se ve el menú de pausa")
	SceneManager._unhandled_input(esc)
	check(not tree.paused, "Esc de nuevo continúa")
	check_eq(SceneManager.state, SceneManager.State.LEVEL, "vuelve a LEVEL")


func test_volver_al_mapa_deja_al_aprendiz_en_la_casita() -> void:
	SceneManager.goto_house("w1_l3")
	await _settle()
	SceneManager.back_to_section()
	await _settle()
	var map: Node = tree.current_scene
	var door: Vector2i = map.layout.houses[2]["door"]
	check(map.player.global_position.distance_to(SectionLayout.tile_center(door)) < 20, "aparece frente a la casita 3")


func test_teclas_registradas() -> void:
	for a: String in ["move_left", "move_right", "move_up", "move_down", "interact", "pause"]:
		check(InputMap.has_action(a), "falta la acción " + a)
	var w := InputEventKey.new()
	w.physical_keycode = KEY_W
	check(InputMap.event_is_action(w, "move_up"), "W mueve arriba")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	check(InputMap.event_is_action(space, "interact"), "Espacio interactúa")
