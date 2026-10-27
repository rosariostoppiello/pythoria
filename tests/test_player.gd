extends TestCase
## Colisión del aprendiz en el mapa de sección (headless, con física real).

var map: Node2D


func before_each() -> void:
	SaveSystem.save_path = "user://test_save.json"
	GameState.reset()
	SceneManager.world_id = 1
	SceneManager.return_house = ""
	map = load("res://scenes/section_map/section_map.tscn").instantiate()
	tree.root.add_child(map)


func after_each() -> void:
	map.queue_free()
	SaveSystem.delete_save()
	SaveSystem.save_path = SaveSystem.DEFAULT_PATH
	GameState.load_from_save()


func _walk(from: Vector2, dir: Vector2, frames: int = 60) -> Vector2:
	var p: Player = map.player
	p.global_position = from
	p.input_override = dir
	for i in frames:
		await tree.physics_frame
	p.input_override = Vector2.ZERO
	return p.global_position


func test_camina_en_espacio_libre() -> void:
	await tree.physics_frame
	var l: SectionLayout = map.layout
	for t: Vector2i in l.path:
		if l.is_walkable(t + Vector2i.RIGHT) and l.is_walkable(t + Vector2i(2, 0)):
			var from := SectionLayout.tile_center(t)
			var to: Vector2 = await _walk(from, Vector2.RIGHT, 12)
			check(to.x > from.x + 20, "debería avanzar a la derecha (%s -> %s)" % [from, to])
			return
	check(false, "no encontré un tramo libre para probar")


func test_arbol_bloquea() -> void:
	await tree.physics_frame
	# Columna 0 es todo árboles: caminar a la izquierda desde la columna 1.
	var l: SectionLayout = map.layout
	var row := -1
	for y in range(1, l.rows - 1):
		if l.is_walkable(Vector2i(1, y)):
			row = y
			break
	check(row > 0, "no hay celda libre en la columna 1")
	var to: Vector2 = await _walk(SectionLayout.tile_center(Vector2i(1, row)), Vector2.LEFT)
	check(to.x >= 64.0, "el árbol del borde no frenó al aprendiz (x=%.1f)" % to.x)


func test_casita_bloquea() -> void:
	await tree.physics_frame
	var house: House = map.houses[0]
	var door: Vector2i = map.layout.houses[0]["door"]
	var from := SectionLayout.tile_center(door)
	var to: Vector2 = await _walk(from, Vector2.UP)
	check(to.y < from.y - 5, "debería acercarse a la casita")
	check(to.y > house.global_position.y, "atravesó la casita (y=%.1f, base=%.1f)" % [to.y, house.global_position.y])


func test_agua_bloquea() -> void:
	await tree.physics_frame
	var l: SectionLayout = map.layout
	check(not l.water.is_empty(), "el mapa debería tener agua")
	for t: Vector2i in l.water:
		var below := t + Vector2i.DOWN
		if l.is_walkable(below):
			var to: Vector2 = await _walk(SectionLayout.tile_center(below), Vector2.UP)
			var water_bottom := float((t.y + 1) * SectionLayout.TILE)
			check(to.y > water_bottom, "entró al agua (y=%.1f, borde=%.1f)" % [to.y, water_bottom])
			return
	check(false, "no hay agua con una celda libre abajo")


func test_puertas_alcanzables() -> void:
	for w: Dictionary in ContentDB.worlds():
		if not ContentDB.world_has_section(int(w["id"])):
			continue
		var l := SectionLayout.build(w)
		var reach := l.reachable_from_start()
		for h: Dictionary in l.houses:
			check(reach.has(h["door"]), "mundo %s: la puerta de %s no es alcanzable" % [w["id"], h["id"]])


func test_entrar_a_casita_bloqueada() -> void:
	await tree.physics_frame
	var locked: House = map.houses[3]
	check_eq(locked.state, "locked", "la casita 4 arranca bloqueada")
	check(not map.try_enter(locked), "no debería entrar a una casita bloqueada")
	map.player.global_position = map.houses[0].door_point
	check(map.nearest_house() == map.houses[0], "debería detectar la casita cercana")
