extends Node
## Carga data/worlds.json y responde preguntas sobre el contenido.
## Todo el contenido vive en JSON: agregar un nivel no requiere tocar scripts.

const WORLDS_PATH := "res://data/worlds.json"

var data: Dictionary = {}
var load_error: String = ""


func _ready() -> void:
	load_content(WORLDS_PATH)


func load_content(path: String) -> bool:
	load_error = ""
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		load_error = "No se pudo leer %s" % path
		push_error(load_error)
		data = {"worlds": []}
		return false
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_error = "JSON inválido en %s" % path
		push_error(load_error)
		data = {"worlds": []}
		return false
	data = parsed
	return true


func worlds() -> Array:
	return data.get("worlds", [])


func world_count() -> int:
	return worlds().size()


func get_world(world_id: int) -> Dictionary:
	for w: Dictionary in worlds():
		if int(w.get("id", -1)) == world_id:
			return w
	return {}


## Un mundo es "jugable" (se puede entrar a su mapa de sección) si tiene casitas.
func world_has_section(world_id: int) -> bool:
	var w := get_world(world_id)
	return w.has("section_map") and not (w["section_map"].get("houses", []) as Array).is_empty()


func world_map_nodes() -> Array:
	return data.get("world_map", {}).get("nodes", [])


func houses(world_id: int) -> Array:
	return get_world(world_id).get("section_map", {}).get("houses", [])


func house_ids(world_id: int) -> Array[String]:
	var ids: Array[String] = []
	for h: Dictionary in houses(world_id):
		ids.append(str(h["id"]))
	return ids


func get_house(house_id: String) -> Dictionary:
	for w: Dictionary in worlds():
		for h: Dictionary in w.get("section_map", {}).get("houses", []):
			if str(h["id"]) == house_id:
				return h
	return {}


## Mundo al que pertenece una casita (w1_l3 -> 1). -1 si no existe.
func world_of(house_id: String) -> int:
	for w: Dictionary in worlds():
		for h: Dictionary in w.get("section_map", {}).get("houses", []):
			if str(h["id"]) == house_id:
				return int(w["id"])
	return -1


## Contenido jugable de una casita: un nivel, el minijuego o el boss. {} si es placeholder.
func get_content(house_id: String) -> Dictionary:
	var w := get_world(world_of(house_id))
	if w.is_empty():
		return {}
	for lvl: Dictionary in w.get("levels", []):
		if str(lvl["id"]) == house_id:
			return lvl
	var mini: Dictionary = w.get("minigame", {})
	if str(mini.get("id", "")) == house_id:
		return mini
	var boss: Dictionary = w.get("boss_fight", {})
	if str(boss.get("id", "")) == house_id:
		return boss
	return {}


func house_kind(house_id: String) -> String:
	return str(get_house(house_id).get("kind", "level"))


## Número de nivel para la barra superior ("Mundo 1 · Nivel 3"). Minijuego y boss usan su título.
func house_label(house_id: String) -> String:
	var kind := house_kind(house_id)
	if kind == "minigame":
		return "Minijuego"
	if kind == "boss":
		return "Boss"
	var idx := house_ids(world_of(house_id)).find(house_id)
	return "Nivel %d" % (idx + 1)


func xp_config() -> Dictionary:
	var defaults := {"per_level": 50, "hint_cost": 10, "min_per_level": 10, "minigame": 100, "boss": 200}
	var cfg: Dictionary = data.get("xp", {})
	for k: String in defaults:
		if not cfg.has(k):
			cfg[k] = defaults[k]
	return cfg
