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


## En web no hay fuentes de respaldo: todo carácter de los textos tiene que existir en Nunito/Fredoka.
func test_textos_sin_simbolos_faltantes() -> void:
	var nunito := load(ThemeColors.FONT_BODY) as FontFile
	var text := FileAccess.get_file_as_string(ContentDB.WORLDS_PATH)
	var missing := ""
	for ch in text:
		if ch.unicode_at(0) > 127 and not nunito.has_char(ch.unicode_at(0)) and not missing.contains(ch):
			missing += ch
	check_eq(missing, "", "caracteres de worlds.json que Nunito no tiene")
