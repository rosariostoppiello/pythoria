extends TestCase

const IDS := ["player", "ada", "owl", "byte_cat", "gremlin_sintaxis", "fantasma_sin_nombre",
	"quimera_tipos", "ouroboros", "jar", "cauldron", "grimoire", "teacup", "candle_books",
	"house_locked", "house_open", "house_done", "tile_grass", "tile_path", "tile_water", "tree",
	"map_node", "map_node_done", "map_node_locked"]


func test_todos_los_sprites_existen() -> void:
	for id: String in IDS:
		var t := UI.tex(id)
		check(t != null, "falta el sprite " + id)
		if t:
			check(t.get_width() >= 32 and t.get_width() <= 48, "tamaño raro en " + id)


func test_filtro_nearest_global() -> void:
	check_eq(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")), 0, "filtro de texturas")
