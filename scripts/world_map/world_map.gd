extends Control
## Mapa de mundos: 8 nodos unidos por una línea punteada. El aprendiz está en el
## mundo actual y, al vencer un boss, camina por la línea hasta el siguiente.

const NODE_RADIUS := 38.0
const WALK_TIME := 0.9

var positions: Dictionary = {}       # world_id -> Vector2
var node_views: Dictionary = {}      # world_id -> Control
var player_sprite: TextureRect
var info_title: Label
var info_body: Label
var enter_button: Button
var selected: int = 1
var walking := false

var _line: DottedPath


func _ready() -> void:
	SceneManager.set_state(SceneManager.State.WORLD_MAP)
	UI.background(self)
	var sky: Control = load("res://scripts/ui/star_field.gd").new()
	add_child(UI.full_rect(sky))
	for n: Dictionary in ContentDB.world_map_nodes():
		positions[int(n["world"])] = Vector2(float(n["pos"][0]), float(n["pos"][1]))

	_line = DottedPath.new()
	_line.map = self
	add_child(UI.full_rect(_line))
	for w: Dictionary in ContentDB.worlds():
		_add_node(w)

	player_sprite = UI.sprite_rect("player", 1.5)
	player_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(player_sprite)
	var bob := player_sprite.create_tween().set_loops()
	bob.tween_property(player_sprite, "scale", Vector2(1.0, 1.06), 0.8).set_trans(Tween.TRANS_SINE)
	bob.tween_property(player_sprite, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)

	var bar := TopBar.new("Mapa de Pythoria")
	add_child(bar)
	bar.add_left_button("‹ Menú").pressed.connect(SceneManager.goto_menu)
	_build_info()

	var start := clampi(GameState.current_world, 1, GameState.frontier_world())
	_place_player(start)
	_select(GameState.frontier_world())
	if start < GameState.frontier_world():
		advance_to(GameState.frontier_world(), start)


## "done", "current", "open", "soon" (desbloqueado pero sin contenido) o "locked".
func node_state(world_id: int) -> String:
	if GameState.is_world_completed(world_id):
		return "done"
	if not GameState.is_world_unlocked(world_id):
		return "locked"
	if not ContentDB.world_has_section(world_id):
		return "soon"
	return "current" if world_id == GameState.frontier_world() else "open"


func _add_node(w: Dictionary) -> void:
	var id := int(w["id"])
	if not positions.has(id):
		return
	var view := Button.new()
	view.name = "World%d" % id
	view.flat = true
	view.custom_minimum_size = Vector2(NODE_RADIUS * 2, NODE_RADIUS * 2)
	view.size = view.custom_minimum_size
	view.position = positions[id] - view.size / 2
	view.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	view.pressed.connect(_on_node_pressed.bind(id))
	view.focus_entered.connect(_select.bind(id))
	view.mouse_entered.connect(_select.bind(id))
	add_child(view)
	node_views[id] = view

	var disc := Disc.new()
	disc.color = ThemeColors.world_color(w)
	disc.radius = NODE_RADIUS
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.position = view.size / 2
	view.add_child(disc)
	var icon := UI.sprite_rect("map_node", 1.0)
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = view.size / 2 - icon.custom_minimum_size / 2
	icon.pivot_offset = icon.custom_minimum_size / 2
	view.add_child(icon)

	var name_label := UI.label("%d. %s" % [id, w["name"]], "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.size = Vector2(260, 24)
	name_label.position = Vector2(view.size.x / 2 - 130, view.size.y + 2)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.add_child(name_label)
	_refresh_node(id)


func _refresh_node(id: int) -> void:
	var view: Button = node_views[id]
	var icon: TextureRect = view.get_node("Icon")
	var disc: Disc = view.get_child(0)
	var state := node_state(id)
	match state:
		"done":
			icon.texture = UI.tex("map_node_done")
		"locked", "soon":
			icon.texture = UI.tex("map_node_locked")
		_:
			icon.texture = UI.tex("map_node")
	disc.dimmed = state == "locked" or state == "soon"
	disc.queue_redraw()
	view.focus_mode = Control.FOCUS_ALL if state != "locked" else Control.FOCUS_NONE
	if state == "current":
		var pulse := icon.create_tween().set_loops()
		pulse.tween_property(icon, "scale", Vector2(1.15, 1.15), 0.6).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(icon, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)


func _build_info() -> void:
	var panel := UI.panel()
	panel.position = Vector2(20, 72)
	panel.custom_minimum_size = Vector2(400, 0)
	add_child(panel)
	var box := UI.vbox(4)
	panel.add_child(box)
	info_title = UI.label("", "InkTitle")
	info_title.add_theme_font_size_override("font_size", 21)
	box.add_child(info_title)
	info_body = UI.label("", "InkLabel")
	info_body.add_theme_font_size_override("font_size", 15)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.custom_minimum_size = Vector2(368, 0)
	box.add_child(info_body)
	enter_button = UI.button("Entrar")
	enter_button.add_theme_font_size_override("font_size", 20)
	enter_button.focus_mode = Control.FOCUS_NONE
	enter_button.pressed.connect(func() -> void: _on_node_pressed(selected))
	box.add_child(enter_button)


func _select(id: int) -> void:
	if walking:
		return
	selected = id
	var w := ContentDB.get_world(id)
	var state := node_state(id)
	info_title.text = "Mundo %d · %s" % [id, w.get("name", "")]
	var status: String = {
		"done": "Completado",
		"current": "Mundo actual",
		"open": "Disponible",
		"soon": "Próximamente",
		"locked": "Bloqueado: vencé al boss del mundo anterior",
	}[state]
	info_body.text = "%s\nTemas: %s.\n%s" % [w.get("story", ""), ", ".join(w.get("topics", [])), status]
	enter_button.disabled = not can_enter(id)
	var view: Button = node_views.get(id)
	if view and not view.has_focus() and view.focus_mode != Control.FOCUS_NONE:
		view.grab_focus()


func can_enter(id: int) -> bool:
	return GameState.is_world_unlocked(id) and ContentDB.world_has_section(id)


func _on_node_pressed(id: int) -> void:
	if walking or not can_enter(id):
		return
	SceneManager.goto_section(id)


func _place_player(id: int) -> void:
	player_sprite.position = _player_spot(id)


func _player_spot(id: int) -> Vector2:
	return positions.get(id, Vector2.ZERO) + Vector2(-36, -NODE_RADIUS - 66)


## Camina por la línea punteada desde `from` hasta `to` y desbloquea el nodo.
func advance_to(to: int, from: int) -> void:
	walking = true
	enter_button.disabled = true
	var tw := create_tween()
	for id in range(from + 1, to + 1):
		tw.tween_property(player_sprite, "position", _player_spot(id), WALK_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	var view: Button = node_views[to]
	view.scale = Vector2(0.4, 0.4)
	view.pivot_offset = view.size / 2
	var pop := create_tween()
	pop.tween_property(view, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await pop.finished
	GameState.current_world = to
	GameState.save()
	walking = false
	_select(to)


## Línea punteada entre nodos consecutivos.
class DottedPath extends Control:
	var map: Control

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var ids: Array = map.positions.keys()
		ids.sort()
		for i in range(ids.size() - 1):
			var a: Vector2 = map.positions[ids[i]]
			var b: Vector2 = map.positions[ids[i + 1]]
			var reached := GameState.is_world_unlocked(int(ids[i + 1]))
			var color := ThemeColors.LAVANDA if reached else ThemeColors.GRIS_BLOQUEADO
			var length := a.distance_to(b)
			var steps := int(length / 18.0)
			for s in range(1, steps):
				var p := a.lerp(b, float(s) / steps)
				if p.distance_to(a) > 40 and p.distance_to(b) > 40:
					draw_circle(p, 4.0, color)


## Círculo del color del mundo detrás del ícono del nodo.
class Disc extends Control:
	var color: Color
	var radius: float
	var dimmed := false

	func _draw() -> void:
		var c := color.darkened(0.55) if dimmed else color
		draw_circle(Vector2.ZERO, radius, ThemeColors.TINTA)
		draw_circle(Vector2.ZERO, radius - 4, c)
