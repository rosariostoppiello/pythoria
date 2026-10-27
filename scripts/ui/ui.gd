class_name UI
extends RefCounted
## Atajos para armar interfaz en código usando siempre el tema central.

const SPRITES_DIR := "res://assets/sprites/"


static func tex(id: String) -> Texture2D:
	var path := SPRITES_DIR + id + ".png"
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("Falta el sprite " + path)
	return null


static func label(text: String, variation: String = "", align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = align
	return l


static func button(text: String, variation: String = "", min_width: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(min_width, 0)
	return b


## TextureRect con escalado entero y filtro nearest para el pixel art.
static func sprite_rect(id: String, scale: float = 1.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(id)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if r.texture:
		r.custom_minimum_size = r.texture.get_size() * scale
	return r


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func panel(variation: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	return p


static func spacer(vertical: bool = true) -> Control:
	var c := Control.new()
	if vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


## Fondo de pantalla completa con el color de noche.
static func background(parent: Node) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = ThemeColors.NOCHE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(bg)
	parent.add_child(bg)
	return bg
