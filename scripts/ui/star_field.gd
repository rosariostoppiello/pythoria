extends Control
## Cielo nocturno con estrellitas que titilan (fondo del menú y del mapa de mundos).

@export var count: int = 70

var _stars: Array[Dictionary] = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in count:
		_stars.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"s": rng.randi_range(1, 2) * 2,
			"phase": rng.randf() * TAU,
			"c": ThemeColors.LAVANDA if rng.randf() < 0.6 else ThemeColors.PERGAMINO,
		})


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	for s: Dictionary in _stars:
		var a := 0.35 + 0.65 * (0.5 + 0.5 * sin(_t * 1.5 + float(s["phase"])))
		var pos: Vector2 = (s["p"] as Vector2) * size
		draw_rect(Rect2(pos.floor(), Vector2(s["s"], s["s"])), Color(s["c"], a))
