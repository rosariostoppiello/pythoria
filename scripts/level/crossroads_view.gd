class_name CrossroadsView
extends HBoxContainer
## Encrucijada: el aprendiz frente a un camino que se divide en una rama por
## cada if/elif/else. Al lanzar, se ilumina el camino que tomó.

var puzzle: Dictionary
var rows: Array[PanelContainer] = []
var _conds: Array[Label] = []
var _lines: Control
var _walker: TextureRect
var _chosen := -1
var _chosen_color := ThemeColors.LAVANDA


func _init(p: Dictionary) -> void:
	puzzle = p
	add_theme_constant_override("separation", 0)
	var start := CenterContainer.new()
	_walker = UI.sprite_rect("player", 1.0)
	start.add_child(_walker)
	add_child(start)
	_lines = Control.new()
	_lines.custom_minimum_size = Vector2(56, 0)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines.draw.connect(_draw_lines)
	add_child(_lines)
	var col := UI.vbox(8)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(col)
	var bs := FrascoLogic.branches(p)
	for i in bs.size():
		var b: Dictionary = bs[i]
		var row := PanelContainer.new()
		row.name = "Path_%d" % i
		row.add_theme_stylebox_override("panel", _style(ThemeColors.VIOLETA, 0.25))
		var box := UI.vbox(0)
		row.add_child(box)
		var path := UI.label(str(b["path"]), "HeaderLabel")
		path.add_theme_font_size_override("font_size", 20)
		box.add_child(path)
		var cond := UI.label("", "CodeLabel")
		cond.add_theme_font_size_override("font_size", 14)
		cond.add_theme_color_override("font_color", ThemeColors.LAVANDA)
		box.add_child(cond)
		_conds.append(cond)
		rows.append(row)
		col.add_child(row)
	set_operator("")


static func _style(border: Color, bg_alpha: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(ThemeColors.NOCHE_CLARA, 0.9).lerp(Color(border, 1.0), bg_alpha)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func set_operator(op: String) -> void:
	var bs := FrascoLogic.branches(puzzle)
	for i in bs.size():
		var b: Dictionary = bs[i]
		if b.has("cond"):
			var cond := str(b["cond"]).replace(FrascoLogic.OP_PLACEHOLDER, op if op != "" else "?")
			_conds[i].text = "%s %s" % ["if" if i == 0 else "elif", cond]
		else:
			_conds[i].text = "else"
	reset()


## Vuelve todos los caminos a su color normal.
func reset() -> void:
	_chosen = -1
	for r in rows:
		r.add_theme_stylebox_override("panel", _style(ThemeColors.VIOLETA, 0.25))
		r.modulate = Color.WHITE
	_lines.queue_redraw()


## Ilumina el camino tomado (turquesa si era el correcto, rojo si no).
func highlight(path: Variant, success: bool) -> void:
	reset()
	if path == null:
		return
	var bs := FrascoLogic.branches(puzzle)
	for i in bs.size():
		if str(bs[i]["path"]) == str(path):
			_chosen = i
	_chosen_color = ThemeColors.TURQUESA if success else ThemeColors.ROJO
	for i in rows.size():
		if i == _chosen:
			rows[i].add_theme_stylebox_override("panel", _style(_chosen_color, 0.35))
		else:
			rows[i].modulate = Color(1, 1, 1, 0.45)
	_lines.queue_redraw()


func _draw_lines() -> void:
	var origin := Vector2(0, _lines.size.y / 2)
	for i in rows.size():
		var r := rows[i]
		var target := Vector2(_lines.size.x, r.get_global_rect().get_center().y - _lines.get_global_rect().position.y)
		var color := ThemeColors.LAVANDA if _chosen < 0 else (_chosen_color if i == _chosen else Color(ThemeColors.LAVANDA, 0.3))
		var width := 4.0 if i == _chosen else 2.0
		var steps := 10
		for s in steps:
			if s % 2 == 0:
				draw_line_on(origin.lerp(target, float(s) / steps), origin.lerp(target, float(s + 1) / steps), color, width)


func draw_line_on(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	_lines.draw_line(a, b, color, width)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_SORT_CHILDREN:
		if _lines:
			_lines.queue_redraw.call_deferred()
