class_name TopBar
extends PanelContainer
## Barra superior: "Mundo N · Nivel M", nivel de jugador con barra de XP y racha.

var title_label: Label
var level_label: Label
var xp_bar: ProgressBar
var xp_label: Label
var streak_label: Label
var row: HBoxContainer


func _init(title: String = "") -> void:
	theme_type_variation = "TopBar"
	set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	custom_minimum_size = Vector2(0, 56)
	row = UI.hbox(14)
	add_child(row)
	title_label = UI.label(title, "HeaderLabel")
	title_label.add_theme_font_size_override("font_size", 26)
	row.add_child(title_label)
	row.add_child(UI.spacer(false))
	level_label = UI.label("", "RewardLabel")
	level_label.add_theme_font_size_override("font_size", 22)
	row.add_child(level_label)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(200, 18)
	xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp_bar.show_percentage = false
	xp_bar.max_value = 1.0
	xp_bar.step = 0.0
	row.add_child(xp_bar)
	xp_label = UI.label("", "MutedLabel")
	row.add_child(xp_label)
	row.add_child(UI.sprite_rect("teacup", 0.75))
	streak_label = UI.label("")
	row.add_child(streak_label)


func _ready() -> void:
	GameState.changed.connect(refresh)
	refresh()


func set_title(t: String) -> void:
	title_label.text = t


func refresh() -> void:
	level_label.text = "Nv %d" % GameState.player_level()
	xp_bar.value = GameState.level_progress()
	xp_label.text = "%d XP" % GameState.xp
	var days := GameState.streak
	streak_label.text = "Racha: %d %s" % [days, "día" if days == 1 else "días"]


## Botón a la izquierda del título. No toma foco para no robar Espacio/Enter.
func add_left_button(text: String) -> Button:
	var b := UI.button(text, "OutlineButton")
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_constant_override("content_margin_top", 4)
	row.add_child(b)
	row.move_child(b, 0)
	return b
