extends TestCase

const PATH := "user://test_save.json"


func before_each() -> void:
	SaveSystem.save_path = PATH
	SaveSystem.delete_save()
	GameState.reset()


func after_each() -> void:
	SaveSystem.delete_save()
	SaveSystem.save_path = SaveSystem.DEFAULT_PATH
	GameState.load_from_save()


func _write(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_guardar_y_cargar() -> void:
	GameState.xp = 120
	GameState.streak = 3
	GameState.last_played_day = "2026-10-20"
	GameState.completed.assign(["w1_l1", "w1_l2"])
	GameState.hints_used = {"w1_l2": 1}
	GameState.current_world = 1
	GameState.save()
	check(SaveSystem.has_save(), "no se creó el archivo")
	GameState.reset()
	GameState.load_from_save()
	check_eq(GameState.xp, 120, "xp")
	check_eq(GameState.streak, 3, "racha")
	check_eq(GameState.last_played_day, "2026-10-20", "último día")
	check_eq(GameState.completed.size(), 2, "completados")
	check_eq(GameState.hints_for("w1_l2"), 1, "pistas")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	check_eq(int(raw["version"]), SaveSystem.VERSION, "versión guardada")


func test_claves_faltantes() -> void:
	_write('{"xp": 75}')
	var d := SaveSystem.load_data()
	check_eq(d["xp"], 75, "xp presente")
	check_eq(d["streak"], 0, "racha por defecto")
	check_eq(d["completed"], [], "completados por defecto")
	check_eq(d["hints_used"], {}, "pistas por defecto")
	check_eq(d["current_world"], 1, "mundo por defecto")
	check_eq(d["version"], SaveSystem.VERSION, "versión por defecto")


func test_tipos_invalidos_y_json_roto() -> void:
	_write('{"xp": "mucho", "completed": "w1_l1", "hints_used": [1], "streak": -4}')
	var d := SaveSystem.load_data()
	check_eq(d["xp"], 0, "xp inválido")
	check_eq(d["completed"], [], "completed inválido")
	check_eq(d["hints_used"], {}, "hints inválido")
	check_eq(d["streak"], 0, "racha negativa")
	_write("{esto no es json")
	check_eq(SaveSystem.load_data(), SaveSystem.defaults(), "json roto devuelve defaults")


func test_sin_archivo() -> void:
	check(not SaveSystem.has_save(), "no debería haber guardado")
	check_eq(SaveSystem.load_data(), SaveSystem.defaults(), "sin archivo devuelve defaults")


func test_xp_no_se_duplica() -> void:
	var first := GameState.complete_house("w1_l1", "2026-10-26")
	var again := GameState.complete_house("w1_l1", "2026-10-26")
	check_eq(first, 50, "xp primera vez")
	check_eq(again, 0, "xp al repetir")
	check_eq(GameState.xp, 50, "xp total")
	GameState.load_from_save()
	check_eq(GameState.completed.count("w1_l1"), 1, "sin duplicados en completed")


func test_pistas_bajan_la_recompensa() -> void:
	GameState.use_hint("w1_l1")
	GameState.use_hint("w1_l1")
	check_eq(GameState.reward_for("w1_l1"), 30, "50 - 2 pistas")
	for i in 5:
		GameState.use_hint("w1_l2")
	check_eq(GameState.hints_for("w1_l2"), 3, "tope de 3 pistas")
	check_eq(GameState.reward_for("w1_l2"), 20, "50 - 3 pistas")
	check_eq(GameState.reward_for("w1_mini"), 100, "minijuego")
	check_eq(GameState.reward_for("w1_boss"), 200, "boss")


func test_formula_de_nivel() -> void:
	var cases := {0: 1, 49: 1, 50: 2, 199: 2, 200: 3, 450: 4, 1000: 5, 1250: 6}
	for xp: int in cases:
		check_eq(GameState.level_for_xp(xp), cases[xp], "nivel con %d xp" % xp)
	for lvl in range(1, 8):
		check_eq(GameState.level_for_xp(GameState.xp_for_level(lvl)), lvl, "inversa nivel %d" % lvl)
	GameState.xp = 125
	check(absf(GameState.level_progress() - 0.5) < 0.001, "progreso a mitad de nivel 2")


func test_racha() -> void:
	GameState.update_streak("2026-10-24")
	check_eq(GameState.streak, 1, "primer día")
	GameState.update_streak("2026-10-24")
	check_eq(GameState.streak, 1, "mismo día")
	GameState.update_streak("2026-10-25")
	check_eq(GameState.streak, 2, "día siguiente")
	GameState.update_streak("2026-10-28")
	check_eq(GameState.streak, 1, "se cortó la racha")
	GameState.update_streak("2026-10-31")
	GameState.update_streak("2026-11-01")
	check_eq(GameState.streak, 2, "cambio de mes")
