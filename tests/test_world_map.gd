extends TestCase
## Mapa de mundos: estados de los nodos y avance del aprendiz tras vencer un boss.


func before_each() -> void:
	SaveSystem.save_path = "user://test_save.json"
	GameState.reset()


func after_each() -> void:
	SaveSystem.delete_save()
	SaveSystem.save_path = SaveSystem.DEFAULT_PATH
	GameState.load_from_save()


func _open() -> Control:
	var map: Control = load("res://scenes/world_map/world_map.tscn").instantiate()
	tree.root.add_child(map)
	await tree.process_frame
	return map


func test_ocho_nodos_y_estados_iniciales() -> void:
	var map: Control = await _open()
	check_eq(map.node_views.size(), 8, "nodos dibujados")
	check_eq(map.node_state(1), "current", "mundo 1 actual")
	for id in range(2, 9):
		check_eq(map.node_state(id), "locked", "mundo %d bloqueado" % id)
	check(map.can_enter(1), "se puede entrar al mundo 1")
	check(not map.can_enter(2), "no se puede entrar al mundo 2")
	map.queue_free()


func test_avance_al_vencer_boss() -> void:
	GameState.completed.assign(ContentDB.house_ids(1))
	GameState.current_world = 1
	var map: Control = await _open()
	check(map.walking, "debería estar caminando hacia el mundo 2")
	check_eq(map.node_state(1), "done", "mundo 1 completado")
	check_eq(map.node_state(2), "current", "mundo 2 actual")
	var target: Vector2 = map._player_spot(2)
	var t := 0
	while map.walking and t < 300:
		await tree.process_frame
		t += 1
	check(not map.walking, "terminó de caminar")
	check(map.player_sprite.position.distance_to(target) < 1.0, "el aprendiz llegó al nodo 2")
	check_eq(GameState.current_world, 2, "current_world guardado")
	check(map.can_enter(2), "mundo 2 desbloqueado")
	check(not map.enter_button.disabled, "botón Entrar habilitado")
	map.queue_free()


func test_mundos_sin_contenido() -> void:
	for id in range(1, 4):
		GameState.completed.append("w%d_boss" % id)
	var map: Control = await _open()
	check_eq(map.node_state(4), "soon", "mundo 4 desbloqueado pero sin casitas")
	check(not map.can_enter(4), "no se entra a un mundo sin casitas")
	map.queue_free()
