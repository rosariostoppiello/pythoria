class_name House
extends StaticBody2D
## Casita del mapa de sección. Su estado (locked/open/done) define el sprite.

var house_id: String
var kind: String
var state: String = "locked"
var label_text: String = ""
var door_point: Vector2   # en coordenadas globales

var _sprite: Sprite2D
var _tag: Label
var _glow: Tween


func setup(id: String, house_kind: String, tile: Vector2i, title: String) -> void:
	house_id = id
	kind = house_kind
	label_text = title
	var c := SectionLayout.tile_center(tile)
	position = c + Vector2(0, 30)
	door_point = c + Vector2(-14, 34)


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(2, 2)
	_sprite.position = Vector2(0, -46)
	add_child(_sprite)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(76, 44)
	shape.shape = rect
	shape.position = Vector2(0, -26)
	add_child(shape)
	_tag = UI.label(label_text, "HeaderLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_tag.add_theme_font_size_override("font_size", 18)
	_tag.size = Vector2(120, 24)
	_tag.position = Vector2(-60, -122)
	add_child(_tag)
	refresh()


func refresh() -> void:
	state = GameState.house_state(house_id)
	_sprite.texture = UI.tex("house_" + state)
	# Los bosses llevan techo rojizo (criatura del Caos adentro).
	_sprite.modulate = Color.WHITE
	if kind == "boss" and state != "locked":
		_sprite.self_modulate = ThemeColors.ROJO.lightened(0.55)
	_tag.modulate = Color(1, 1, 1, 0.55 if state == "locked" else 1.0)
	if _glow:
		_glow.kill()
	if state == "open":
		_glow = create_tween().set_loops()
		_glow.tween_property(_sprite, "modulate", Color(1.15, 1.1, 1.25), 0.7)
		_glow.tween_property(_sprite, "modulate", Color.WHITE, 0.7)
