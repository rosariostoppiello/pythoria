extends Node
## Lee y escribe el progreso en user://save.json (formato en docs/DISENO.md §10).
## Tolera claves faltantes o con tipo incorrecto: siempre devuelve un diccionario completo.

const VERSION := 1
const DEFAULT_PATH := "user://save.json"

var save_path: String = DEFAULT_PATH


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"xp": 0,
		"streak": 0,
		"last_played_day": "",
		"completed": [],
		"hints_used": {},
		"current_world": 1,
	}


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func load_data() -> Dictionary:
	if not has_save():
		return defaults()
	var text := FileAccess.get_file_as_string(save_path)
	return sanitize(JSON.parse_string(text) if not text.is_empty() else null)


func save_data(state: Dictionary) -> bool:
	var clean := sanitize(state)
	clean["version"] = VERSION
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("No se pudo escribir %s: %s" % [save_path, FileAccess.get_open_error()])
		return false
	f.store_string(JSON.stringify(clean, "  "))
	f.close()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


## Completa con valores por defecto y descarta lo que tenga tipo inválido.
static func sanitize(raw: Variant) -> Dictionary:
	var out := defaults()
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = raw
	out["version"] = int(d.get("version", VERSION)) if _is_number(d.get("version")) else VERSION
	if _is_number(d.get("xp")):
		out["xp"] = maxi(0, int(d["xp"]))
	if _is_number(d.get("streak")):
		out["streak"] = maxi(0, int(d["streak"]))
	if typeof(d.get("last_played_day")) == TYPE_STRING:
		out["last_played_day"] = d["last_played_day"]
	if typeof(d.get("completed")) == TYPE_ARRAY:
		var ids: Array = []
		for id: Variant in d["completed"]:
			if typeof(id) == TYPE_STRING and not ids.has(id):
				ids.append(id)
		out["completed"] = ids
	if typeof(d.get("hints_used")) == TYPE_DICTIONARY:
		var hints: Dictionary = {}
		for k: Variant in d["hints_used"]:
			if _is_number(d["hints_used"][k]):
				hints[str(k)] = maxi(0, int(d["hints_used"][k]))
		out["hints_used"] = hints
	if _is_number(d.get("current_world")):
		out["current_world"] = maxi(1, int(d["current_world"]))
	return out


static func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
