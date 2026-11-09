extends TestCase
## Modo revisor: abre todo lo que tiene contenido sin tocar el progreso.


func before_each() -> void:
	SaveSystem.save_path = "user://test_save.json"
	GameState.reset()
	GameState.set_reviewer(false)


func after_each() -> void:
	GameState.set_reviewer(false)
	SaveSystem.delete_save()
	SaveSystem.save_path = SaveSystem.DEFAULT_PATH
	GameState.load_from_save()


func test_parametro_de_la_url() -> void:
	check(GameState.query_wants_reviewer("?revisor=1"), "?revisor=1")
	check(GameState.query_wants_reviewer("?revisor"), "?revisor")
	check(GameState.query_wants_reviewer("?x=2&revisor=si"), "entre otros parámetros")
	check(not GameState.query_wants_reviewer("?revisor=0"), "?revisor=0 lo apaga")
	check(not GameState.query_wants_reviewer(""), "sin parámetros")
	check(not GameState.query_wants_reviewer("?revisores=1"), "otro nombre")


func test_abre_todo_lo_que_tiene_contenido() -> void:
	check_eq(GameState.house_state("w3_boss"), "locked", "sin revisor, el Ouroboros está cerrado")
	GameState.set_reviewer(true)
	for world in [1, 2, 3]:
		check(GameState.is_world_unlocked(world), "mundo %d abierto" % world)
		for id: String in ContentDB.house_ids(world):
			check_eq(GameState.house_state(id), "open", "%s abierta" % id)
	check(not GameState.is_world_unlocked(4), "el mundo 4 sin casitas sigue cerrado")


func test_no_cambia_el_progreso() -> void:
	GameState.complete_house("w1_l1", "2026-11-08")
	GameState.set_reviewer(true)
	check_eq(GameState.frontier_world(), 1, "el aprendiz no se mueve de mundo")
	check_eq(GameState.house_state("w1_l1"), "done", "lo completado sigue completado")
	GameState.set_reviewer(false)
	check_eq(GameState.house_state("w1_l3"), "locked", "al apagarlo vuelve todo como estaba")
	var saved: Dictionary = SaveSystem.load_data()
	check(not saved.has("reviewer"), "el modo revisor no se guarda")


func test_mapa_de_mundos_en_modo_revisor() -> void:
	GameState.set_reviewer(true)
	var map: Control = load("res://scenes/world_map/world_map.tscn").instantiate()
	tree.root.add_child(map)
	await tree.process_frame
	check(not map.walking, "no camina hacia el mundo 3")
	check(map.can_enter(3), "se puede entrar al mundo 3")
	check_eq(map.node_state(3), "open", "el mundo 3 se ve abierto")
	map.queue_free()
	await tree.process_frame
