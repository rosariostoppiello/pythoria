extends TestCase


func test_autoloads_presentes() -> void:
	for n: String in ["ContentDB", "SaveSystem", "GameState", "SceneManager"]:
		check(tree.root.has_node(n), "falta el autoload " + n)


func test_tema_y_fuentes() -> void:
	var theme := load("res://resources/ui_theme.tres") as Theme
	check(theme != null, "no carga ui_theme.tres")
	if theme:
		check(theme.default_font != null, "el tema no tiene fuente por defecto")
		check(theme.has_stylebox("panel", "PanelContainer"), "falta el panel de pergamino")
	for f: String in [ThemeColors.FONT_TITLE, ThemeColors.FONT_CODE, ThemeColors.FONT_BODY]:
		check(ResourceLoader.exists(f), "falta la fuente " + f)
