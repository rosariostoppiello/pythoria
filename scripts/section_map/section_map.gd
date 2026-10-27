extends Node2D
## Mapa de sección de un mundo: el aprendiz camina entre las casitas y entra con Espacio/Enter.

const INTERACT_DIST := 64.0

var layout: SectionLayout
var player: Player
var houses: Array[House] = []
var world_id: int = 1

var _prompt: Label
var _message: Label
var _near: House


func _ready() -> void:
	SceneManager.set_state(SceneManager.State.SECTION_MAP)
	world_id = SceneManager.world_id
	var world := ContentDB.get_world(world_id)
	layout = SectionLayout.build(world)

	var ground := Ground.new()
	ground.layout = layout
	add_child(ground)

	var ysort := Node2D.new()
	ysort.name = "Objects"
	ysort.y_sort_enabled = true
	add_child(ysort)
	_build_bounds()
	for t: Vector2i in layout.water:
		_add_block(SectionLayout.tile_center(t), Vector2(64, 64), "Water")
	var tree_tex := UI.tex("tree")
	for t: Vector2i in layout.trees:
		var tree := StaticBody2D.new()
		tree.name = "Tree_%d_%d" % [t.x, t.y]
		tree.add_to_group("trees")
		tree.position = SectionLayout.tile_center(t) + Vector2(0, 20)
		var spr := Sprite2D.new()
		spr.texture = tree_tex
		spr.scale = Vector2(2, 2)
		spr.position = Vector2(0, -20)
		tree.add_child(spr)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(48, 36)
		shape.shape = rect
		shape.position = Vector2(0, -10)
		tree.add_child(shape)
		ysort.add_child(tree)

	var idx := 0
	for h: Dictionary in layout.houses:
		idx += 1
		var house := House.new()
		var title := str(idx)
		if h["kind"] == "minigame":
			title = "Minijuego"
		elif h["kind"] == "boss":
			title = "Boss"
		house.setup(h["id"], h["kind"], h["tile"], title)
		house.name = "House_" + str(h["id"])
		ysort.add_child(house)
		houses.append(house)

	player = Player.new()
	player.name = "Player"
	player.position = _spawn_point()
	ysort.add_child(player)
	var cam := Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = -56
	cam.limit_right = int(layout.size_px().x)
	cam.limit_bottom = int(layout.size_px().y)
	cam.position_smoothing_enabled = true
	player.add_child(cam)
	_build_ui(world)


func _spawn_point() -> Vector2:
	var from := SceneManager.return_house
	for h: Dictionary in layout.houses:
		if h["id"] == from:
			return SectionLayout.tile_center(h["door"]) + Vector2(0, 8)
	return SectionLayout.tile_center(layout.start)


func _build_bounds() -> void:
	var s := layout.size_px()
	_add_block(Vector2(s.x / 2, -16), Vector2(s.x, 32), "Wall")
	_add_block(Vector2(s.x / 2, s.y + 16), Vector2(s.x, 32), "Wall")
	_add_block(Vector2(-16, s.y / 2), Vector2(32, s.y), "Wall")
	_add_block(Vector2(s.x + 16, s.y / 2), Vector2(32, s.y), "Wall")


func _add_block(center: Vector2, size: Vector2, group: String) -> void:
	var body := StaticBody2D.new()
	body.position = center
	body.add_to_group(group.to_lower())
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


func _build_ui(world: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var bar := TopBar.new("Mundo %d · %s" % [world_id, world.get("name", "")])
	layer.add_child(bar)
	var back := bar.add_left_button("‹ Mundos")
	back.pressed.connect(SceneManager.goto_world_map)

	var foot := CenterContainer.new()
	layer.add_child(foot)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -64
	foot.offset_bottom = -12
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bottom := UI.panel("DarkPanel")
	foot.add_child(bottom)
	_message = UI.label("Flechas/WASD para moverte · Espacio o Enter para entrar · Esc pausa", "MutedLabel", HORIZONTAL_ALIGNMENT_CENTER)
	bottom.add_child(_message)

	_prompt = UI.label("", "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.size = Vector2(320, 30)
	_prompt.visible = false
	add_child(_prompt)
	_prompt.z_index = 20


func nearest_house() -> House:
	var best: House = null
	var best_d := INTERACT_DIST
	for h: House in houses:
		var d := player.global_position.distance_to(h.door_point)
		if d < best_d:
			best_d = d
			best = h
	return best


func _process(_delta: float) -> void:
	_near = nearest_house()
	if _near == null:
		_prompt.visible = false
		return
	_prompt.visible = true
	_prompt.position = _near.global_position + Vector2(-160, -150)
	match _near.state:
		"locked":
			_prompt.text = "Bloqueada"
		"done":
			_prompt.text = "Espacio: repetir"
		_:
			_prompt.text = "Espacio: entrar"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		try_enter(nearest_house())


## Entra a la casita si está desbloqueada. Devuelve true si entró.
func try_enter(h: House) -> bool:
	if h == null:
		return false
	if h.state == "locked":
		_message.text = "Esa casita está cerrada: primero completá la anterior." if h.kind != "boss" else "El boss espera a que completes los 5 niveles y el minijuego."
		return false
	SceneManager.goto_house(h.house_id)
	return true


## Suelo: pasto, camino y agua dibujados con los tiles x2.
## Las texturas se cargan en _ready y se redibuja un frame después: si se cargan
## dentro del primer _draw, el renderer de compatibilidad las pinta blancas.
class Ground extends Node2D:
	var layout: SectionLayout
	var grass: Texture2D
	var path: Texture2D
	var water: Texture2D

	func _ready() -> void:
		grass = UI.tex("tile_grass")
		path = UI.tex("tile_path")
		water = UI.tex("tile_water")
		await get_tree().process_frame
		queue_redraw()

	func _draw() -> void:
		var size := Vector2(SectionLayout.TILE, SectionLayout.TILE)
		for y in layout.rows:
			for x in layout.cols:
				var t := Vector2i(x, y)
				var tex := grass
				if layout.water.has(t):
					tex = water
				elif layout.path.has(t) or layout.is_house(t):
					tex = path
				draw_texture_rect(tex, Rect2(Vector2(x, y) * size, size), false)
