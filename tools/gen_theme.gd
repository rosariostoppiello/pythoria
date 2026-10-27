extends SceneTree
## Genera resources/ui_theme.tres a partir de scripts/core/theme_colors.gd.
## Uso: godot --headless --path . -s tools/gen_theme.gd

const TC := preload("res://scripts/core/theme_colors.gd")
const OUT := "res://resources/ui_theme.tres"


func _initialize() -> void:
	var theme := build_theme()
	var err := ResourceSaver.save(theme, OUT)
	if err != OK:
		push_error("No se pudo guardar el tema: %s" % err)
		quit(1)
		return
	print("Tema guardado en ", OUT)
	quit(0)


static func font(path: String, weight: int) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = load(path) as FontFile
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv


static func box(bg: Color, border: Color, border_w: int, radius: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb


static func build_theme() -> Theme:
	var t := Theme.new()
	var body := font(TC.FONT_BODY, 600)
	var title := font(TC.FONT_TITLE, 600)
	var code := font(TC.FONT_CODE, 500)
	t.default_font = body
	t.default_font_size = 20

	# Label base: texto claro sobre la noche.
	t.set_color("font_color", "Label", TC.PERGAMINO)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	_label_variation(t, "TitleLabel", title, 52, TC.PERGAMINO)
	_label_variation(t, "HeaderLabel", title, 30, TC.PERGAMINO)
	_label_variation(t, "InkLabel", body, 20, TC.TINTA)
	_label_variation(t, "InkTitle", title, 28, TC.TINTA)
	_label_variation(t, "CodeLabel", code, 20, TC.PERGAMINO)
	_label_variation(t, "SuccessLabel", title, 34, TC.TURQUESA)
	_label_variation(t, "ErrorLabel", title, 30, TC.ROJO)
	_label_variation(t, "RewardLabel", title, 30, TC.DORADO)
	_label_variation(t, "MutedLabel", body, 18, TC.LAVANDA)
	t.set_color("font_outline_color", "TitleLabel", TC.TINTA)
	t.set_constant("outline_size", "TitleLabel", 8)
	t.set_color("font_outline_color", "HeaderLabel", TC.TINTA)
	t.set_constant("outline_size", "HeaderLabel", 6)

	# RichTextLabel: va sobre pergamino.
	t.set_font("normal_font", "RichTextLabel", body)
	t.set_font("mono_font", "RichTextLabel", code)
	t.set_font_size("normal_font_size", "RichTextLabel", 20)
	t.set_color("default_color", "RichTextLabel", TC.TINTA)

	# Botón primario (violeta).
	t.set_font("font", "Button", title)
	t.set_font_size("font_size", "Button", 24)
	t.set_color("font_color", "Button", TC.PERGAMINO)
	t.set_color("font_hover_color", "Button", TC.PERGAMINO)
	t.set_color("font_pressed_color", "Button", TC.PERGAMINO)
	t.set_color("font_focus_color", "Button", TC.PERGAMINO)
	t.set_color("font_hover_pressed_color", "Button", TC.PERGAMINO)
	t.set_color("font_disabled_color", "Button", TC.LAVANDA.darkened(0.3))
	t.set_stylebox("normal", "Button", box(TC.VIOLETA, TC.VIOLETA.darkened(0.35), 3, 12, 12))
	t.set_stylebox("hover", "Button", box(TC.VIOLETA.lightened(0.15), TC.LAVANDA, 3, 12, 12))
	t.set_stylebox("pressed", "Button", box(TC.VIOLETA.darkened(0.2), TC.LAVANDA, 3, 12, 12))
	t.set_stylebox("hover_pressed", "Button", box(TC.VIOLETA.darkened(0.1), TC.LAVANDA, 3, 12, 12))
	t.set_stylebox("disabled", "Button", box(TC.GRIS_BLOQUEADO, TC.GRIS_BLOQUEADO.darkened(0.3), 3, 12, 12))
	var focus := box(Color(0, 0, 0, 0), TC.LAVANDA, 3, 12, 12)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)

	# Botón de contorno (Pedir pista, acciones secundarias).
	t.add_type("OutlineButton")
	t.set_type_variation("OutlineButton", "Button")
	t.set_color("font_color", "OutlineButton", TC.LAVANDA)
	t.set_color("font_hover_color", "OutlineButton", TC.PERGAMINO)
	t.set_stylebox("normal", "OutlineButton", box(Color(TC.VIOLETA, 0.12), TC.VIOLETA, 3, 12, 12))
	t.set_stylebox("hover", "OutlineButton", box(Color(TC.VIOLETA, 0.4), TC.LAVANDA, 3, 12, 12))
	t.set_stylebox("pressed", "OutlineButton", box(Color(TC.VIOLETA, 0.6), TC.LAVANDA, 3, 12, 12))

	# Selector de operador (toggle).
	t.add_type("OperatorButton")
	t.set_type_variation("OperatorButton", "Button")
	t.set_font("font", "OperatorButton", code)
	t.set_font_size("font_size", "OperatorButton", 28)
	t.set_color("font_color", "OperatorButton", TC.LAVANDA)
	t.set_color("font_pressed_color", "OperatorButton", TC.PERGAMINO)
	t.set_stylebox("normal", "OperatorButton", box(TC.NOCHE_CLARA, TC.VIOLETA, 3, 10, 8))
	t.set_stylebox("hover", "OperatorButton", box(TC.NOCHE_CLARA.lightened(0.1), TC.LAVANDA, 3, 10, 8))
	t.set_stylebox("pressed", "OperatorButton", box(TC.VIOLETA, TC.LAVANDA, 4, 10, 8))
	t.set_stylebox("hover_pressed", "OperatorButton", box(TC.VIOLETA, TC.LAVANDA, 4, 10, 8))

	# Paneles: pergamino por defecto, y variantes oscura y de código.
	t.set_stylebox("panel", "PanelContainer", box(TC.PERGAMINO, TC.VIOLETA, 4, 16, 16))
	t.set_stylebox("panel", "Panel", box(TC.PERGAMINO, TC.VIOLETA, 4, 16, 16))
	t.add_type("DarkPanel")
	t.set_type_variation("DarkPanel", "PanelContainer")
	t.set_stylebox("panel", "DarkPanel", box(Color(TC.NOCHE_CLARA, 0.92), TC.VIOLETA, 3, 14, 12))
	t.add_type("CodePanel")
	t.set_type_variation("CodePanel", "PanelContainer")
	t.set_stylebox("panel", "CodePanel", box(TC.TINTA, TC.LAVANDA, 2, 10, 14))
	t.add_type("TopBar")
	t.set_type_variation("TopBar", "PanelContainer")
	t.set_stylebox("panel", "TopBar", box(Color(TC.TINTA, 0.95), TC.VIOLETA, 0, 0, 8))

	# Barras: XP en dorado, vida del boss en rojo.
	t.set_stylebox("background", "ProgressBar", box(TC.NOCHE_CLARA, TC.VIOLETA, 2, 8, 0))
	t.set_stylebox("fill", "ProgressBar", box(TC.DORADO, TC.DORADO, 0, 8, 0))
	t.set_constant("outline_size", "ProgressBar", 0)
	t.set_color("font_color", "ProgressBar", TC.TINTA)
	t.set_font_size("font_size", "ProgressBar", 14)
	t.add_type("HealthBar")
	t.set_type_variation("HealthBar", "ProgressBar")
	t.set_stylebox("fill", "HealthBar", box(TC.ROJO, TC.ROJO, 0, 8, 0))

	# Popups / tooltips.
	t.set_stylebox("panel", "PopupMenu", box(TC.NOCHE_CLARA, TC.VIOLETA, 2, 8, 8))
	t.set_stylebox("panel", "TooltipPanel", box(TC.PERGAMINO, TC.VIOLETA, 2, 8, 8))
	t.set_color("font_color", "TooltipLabel", TC.TINTA)
	return t


static func _label_variation(t: Theme, name: String, f: Font, size: int, color: Color) -> void:
	t.add_type(name)
	t.set_type_variation(name, "Label")
	t.set_font("font", name, f)
	t.set_font_size("font_size", name, size)
	t.set_color("font_color", name, color)
