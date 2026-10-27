class_name TokenChip
extends PanelContainer
## Ficha de valor: se arrastra a un frasco o a un hueco, o se toca para colocarla.

signal clicked

var payload: Dictionary = {}
var draggable := true
var _label: Label


func _init(text: String = "", color: Color = ThemeColors.LAVANDA, data: Dictionary = {}) -> void:
	payload = data
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", chip_style(color))
	_label = UI.label(text, "CodeLabel", HORIZONTAL_ALIGNMENT_CENTER)
	_label.add_theme_color_override("font_color", ThemeColors.TINTA)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


static func chip_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = ThemeColors.TINTA
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.shadow_color = ThemeColors.SOMBRA
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 2)
	return sb


## Color de ficha para un fragmento de código del minijuego.
static func color_for_code(text: String) -> Color:
	if text.is_valid_int() or text.is_valid_float():
		return ThemeColors.essence("int")
	if text.begins_with("'") or text.begins_with('"'):
		return ThemeColors.essence("str")
	if text == "True" or text == "False":
		return ThemeColors.essence("bool")
	return ThemeColors.LAVANDA.lerp(ThemeColors.PERGAMINO, 0.5)


func get_text() -> String:
	return _label.text


func _get_drag_data(_at: Vector2) -> Variant:
	if not draggable:
		return null
	var preview := TokenChip.new(_label.text, (get_theme_stylebox("panel") as StyleBoxFlat).bg_color)
	preview.modulate.a = 0.85
	if get_viewport().gui_is_dragging():
		set_drag_preview(preview)
	else:
		preview.free()
	return payload


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and not get_viewport().gui_is_dragging():
		clicked.emit()
