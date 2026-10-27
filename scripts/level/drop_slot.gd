class_name DropSlot
extends PanelContainer
## Lugar donde se sueltan fichas (frasco, hueco del minijuego o bandeja).

signal dropped(data: Dictionary)
signal clicked

## Devuelve la ficha que contiene (para arrastrarla afuera). {} si está vacío.
var drag_payload: Dictionary = {}
var accepts: Callable = func(_d: Dictionary) -> bool: return true

var _label: Label
var _empty_text: String
var _base: StyleBoxFlat
var _hover: StyleBoxFlat


func _init(empty_text: String = "", min_size: Vector2 = Vector2(110, 44)) -> void:
	_empty_text = empty_text
	custom_minimum_size = min_size
	_base = slot_style(Color(ThemeColors.TINTA, 0.85), ThemeColors.LAVANDA)
	_hover = slot_style(Color(ThemeColors.VIOLETA, 0.6), ThemeColors.PERGAMINO)
	add_theme_stylebox_override("panel", _base)
	_label = UI.label(empty_text, "CodeLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.modulate.a = 0.6
	add_child(_label)
	mouse_exited.connect(func() -> void: add_theme_stylebox_override("panel", _base))


static func slot_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6)
	return sb


## Muestra una ficha adentro (texto + color de esencia) o vuelve a vacío.
func show_token(text: String, color: Variant = null) -> void:
	if text == "":
		_label.text = _empty_text
		_label.modulate.a = 0.6
		_label.remove_theme_color_override("font_color")
		_base = slot_style(Color(ThemeColors.TINTA, 0.85), ThemeColors.LAVANDA)
	else:
		_label.text = text
		_label.modulate.a = 1.0
		_label.add_theme_color_override("font_color", ThemeColors.TINTA)
		_base = slot_style(color if color != null else ThemeColors.LAVANDA, ThemeColors.TINTA)
	add_theme_stylebox_override("panel", _base)


func get_text() -> String:
	return "" if _label.text == _empty_text else _label.text


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	var ok: bool = typeof(data) == TYPE_DICTIONARY and accepts.call(data)
	if ok:
		add_theme_stylebox_override("panel", _hover)
	return ok


func _drop_data(_at: Vector2, data: Variant) -> void:
	add_theme_stylebox_override("panel", _base)
	dropped.emit(data)


func _get_drag_data(_at: Vector2) -> Variant:
	if drag_payload.is_empty():
		return null
	var preview := TokenChip.new(_label.text, _base.bg_color)
	preview.modulate.a = 0.85
	if get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	else:
		preview.free()
	return drag_payload


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and not get_viewport().gui_is_dragging():
		clicked.emit()
