class_name Player
extends CharacterBody2D
## El aprendiz: se mueve con flechas/WASD y respira cuando está quieto.

const SPEED := 220.0

## Si no es cero, reemplaza la entrada del teclado (lo usan los tests).
var input_override := Vector2.ZERO
var facing := Vector2.DOWN

var _sprite: Sprite2D
var _t := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = UI.tex("player")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -16)
	add_child(_sprite)
	# Colisión solo en los pies, para poder pasar "por delante" de las cosas.
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(24, 14)
	shape.shape = rect
	shape.position = Vector2(0, 2)
	add_child(shape)


func read_direction() -> Vector2:
	if input_override != Vector2.ZERO:
		return input_override.normalized()
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _physics_process(delta: float) -> void:
	var dir := read_direction()
	velocity = dir * SPEED
	move_and_slide()
	_animate(dir, delta)


func _animate(dir: Vector2, delta: float) -> void:
	_t += delta
	if dir != Vector2.ZERO:
		facing = dir
		if absf(dir.x) > 0.1:
			_sprite.flip_h = dir.x < 0
		# Caminar: saltito de 2 frames.
		var step := int(_t * 8.0) % 2
		_sprite.position.y = -3.0 * step
		_sprite.scale = Vector2.ONE
	else:
		# Respirar.
		_sprite.position.y = 0.0
		var s := 1.0 + 0.035 * sin(_t * 3.0)
		_sprite.scale = Vector2(1.0, s)
