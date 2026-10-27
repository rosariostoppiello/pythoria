extends Node
## Progreso del jugador: XP, nivel, racha, casitas completadas y pistas usadas.

signal changed

const MAX_HINTS := 3

var xp: int = 0
var streak: int = 0
var last_played_day: String = ""
var completed: Array[String] = []
var hints_used: Dictionary = {}
var current_world: int = 1


func _ready() -> void:
	load_from_save()


func reset() -> void:
	apply(SaveSystem.defaults())


func load_from_save() -> void:
	apply(SaveSystem.load_data())


func apply(d: Dictionary) -> void:
	var clean := SaveSystem.sanitize(d)
	xp = clean["xp"]
	streak = clean["streak"]
	last_played_day = clean["last_played_day"]
	completed.clear()
	for id: String in clean["completed"]:
		completed.append(id)
	hints_used = clean["hints_used"]
	current_world = clean["current_world"]
	changed.emit()


func to_dict() -> Dictionary:
	return {
		"version": SaveSystem.VERSION,
		"xp": xp,
		"streak": streak,
		"last_played_day": last_played_day,
		"completed": completed.duplicate(),
		"hints_used": hints_used.duplicate(),
		"current_world": current_world,
	}


func save() -> void:
	SaveSystem.save_data(to_dict())


# --- Nivel y XP -------------------------------------------------------------

static func level_for_xp(amount: int) -> int:
	return int(floor(sqrt(amount / 50.0))) + 1


## XP mínimo para alcanzar un nivel de jugador (inversa de level_for_xp).
static func xp_for_level(level: int) -> int:
	return 50 * (level - 1) * (level - 1)


func player_level() -> int:
	return level_for_xp(xp)


## Fracción 0..1 del camino entre el nivel actual y el siguiente.
func level_progress() -> float:
	var lvl := player_level()
	var lo := xp_for_level(lvl)
	var hi := xp_for_level(lvl + 1)
	return float(xp - lo) / float(hi - lo)


# --- Desbloqueo -------------------------------------------------------------

func is_completed(house_id: String) -> bool:
	return completed.has(house_id)


func is_world_unlocked(world_id: int) -> bool:
	if world_id <= 1:
		return true
	return is_completed("w%d_boss" % (world_id - 1))


func is_world_completed(world_id: int) -> bool:
	return is_completed("w%d_boss" % world_id)


## Una casita se desbloquea si la anterior está completada; el boss pide todas las demás.
func is_house_unlocked(house_id: String) -> bool:
	var world_id := ContentDB.world_of(house_id)
	if world_id < 0 or not is_world_unlocked(world_id):
		return false
	var ids := ContentDB.house_ids(world_id)
	var idx := ids.find(house_id)
	if ContentDB.house_kind(house_id) == "boss":
		for other: String in ids:
			if other != house_id and not is_completed(other):
				return false
		return true
	return idx == 0 or is_completed(ids[idx - 1])


## "locked", "open" o "done".
func house_state(house_id: String) -> String:
	if is_completed(house_id):
		return "done"
	return "open" if is_house_unlocked(house_id) else "locked"


## Último mundo desbloqueado que tiene mapa de sección (donde se para el aprendiz).
func frontier_world() -> int:
	var best := 1
	for w: Dictionary in ContentDB.worlds():
		var id := int(w["id"])
		if is_world_unlocked(id) and ContentDB.world_has_section(id):
			best = maxi(best, id)
	return best


# --- Recompensas ------------------------------------------------------------

func hints_for(house_id: String) -> int:
	return int(hints_used.get(house_id, 0))


func reward_for(house_id: String) -> int:
	var cfg := ContentDB.xp_config()
	match ContentDB.house_kind(house_id):
		"minigame":
			return int(cfg["minigame"])
		"boss":
			return int(cfg["boss"])
	var base := int(cfg["per_level"]) - int(cfg["hint_cost"]) * hints_for(house_id)
	return maxi(int(cfg["min_per_level"]), base)


## Registra una pista usada. Devuelve cuántas lleva en esa casita.
func use_hint(house_id: String) -> int:
	var n := mini(MAX_HINTS, hints_for(house_id) + 1)
	hints_used[house_id] = n
	save()
	changed.emit()
	return n


## Marca una casita como completada. Devuelve el XP ganado (0 si ya estaba completada).
func complete_house(house_id: String, today: String = "") -> int:
	update_streak(today if today != "" else today_string())
	var gained := 0
	if not is_completed(house_id):
		gained = reward_for(house_id)
		xp += gained
		completed.append(house_id)
	save()
	changed.emit()
	return gained


# --- Racha ------------------------------------------------------------------

static func today_string() -> String:
	return Time.get_date_string_from_system()


static func days_between(a: String, b: String) -> int:
	var ta := Time.get_unix_time_from_datetime_string(a + "T00:00:00")
	var tb := Time.get_unix_time_from_datetime_string(b + "T00:00:00")
	return int(round((tb - ta) / 86400.0))


## Racha = días consecutivos con al menos una casita resuelta.
func update_streak(today: String) -> void:
	if last_played_day == today:
		return
	if last_played_day != "" and days_between(last_played_day, today) == 1:
		streak += 1
	else:
		streak = 1
	last_played_day = today
