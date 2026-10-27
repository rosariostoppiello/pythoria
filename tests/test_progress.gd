extends TestCase
## Desbloqueo de casitas y mundos.


func before_each() -> void:
	SaveSystem.save_path = "user://test_save.json"
	GameState.reset()


func after_each() -> void:
	SaveSystem.delete_save()
	SaveSystem.save_path = SaveSystem.DEFAULT_PATH
	GameState.load_from_save()


func test_casitas_en_orden() -> void:
	var ids := ContentDB.house_ids(1)
	check_eq(ids.size(), 7, "mundo 1 tiene 7 casitas")
	check_eq(GameState.house_state(ids[0]), "open", "la primera arranca abierta")
	for i in range(1, ids.size()):
		check_eq(GameState.house_state(ids[i]), "locked", "%s arranca bloqueada" % ids[i])
	for i in range(0, 5):
		GameState.complete_house(ids[i], "2026-10-26")
		check_eq(GameState.house_state(ids[i]), "done", "%s completada" % ids[i])
		check_eq(GameState.house_state(ids[i + 1]), "open", "%s se abre" % ids[i + 1])
	check_eq(GameState.house_state("w1_boss"), "locked", "boss bloqueado sin minijuego")
	GameState.complete_house("w1_mini", "2026-10-26")
	check_eq(GameState.house_state("w1_boss"), "open", "boss abierto")


func test_boss_pide_todas() -> void:
	# Aunque el minijuego esté hecho, el boss pide los 5 niveles.
	GameState.completed.assign(["w1_l1", "w1_l2", "w1_mini"])
	check(not GameState.is_house_unlocked("w1_boss"), "boss no debería abrirse")


func test_mundos() -> void:
	check(GameState.is_world_unlocked(1), "mundo 1 abierto")
	check(not GameState.is_world_unlocked(2), "mundo 2 cerrado")
	check_eq(GameState.house_state("w2_l1"), "locked", "casitas de mundo cerrado")
	check_eq(GameState.frontier_world(), 1, "frontera inicial")
	GameState.complete_house("w1_boss", "2026-10-26")
	check(GameState.is_world_unlocked(2), "boss 1 abre mundo 2")
	check_eq(GameState.house_state("w2_l1"), "open", "primera casita del mundo 2")
	check_eq(GameState.frontier_world(), 2, "frontera en mundo 2")
	GameState.completed.append("w3_boss")
	check(GameState.is_world_unlocked(4), "mundo 4 desbloqueado por datos")
	check_eq(GameState.frontier_world(), 2, "mundo 4 sin casitas no es frontera (falta w2_boss)")
