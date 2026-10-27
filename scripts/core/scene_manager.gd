extends Node
## Cambia de escena con un fundido y lleva el estado del juego.

enum State { MENU, WORLD_MAP, SECTION_MAP, LEVEL, PAUSED, RESULT }

signal state_changed(state: State)

const SCENES := {
	"menu": "res://scenes/main_menu/main_menu.tscn",
	"world_map": "res://scenes/world_map/world_map.tscn",
	"section_map": "res://scenes/section_map/section_map.tscn",
	"level": "res://scenes/level/level.tscn",
	"minigame": "res://scenes/level/minigame.tscn",
	"coming_soon": "res://scenes/level/coming_soon.tscn",
}
const PAUSE_SCENE := "res://scenes/pause/pause.tscn"
const RESULT_SCENE := "res://scenes/result/result.tscn"
const FADE_TIME := 0.2

var state: State = State.MENU
## Mundo y casita activos (los leen las escenas al cargar).
var world_id: int = 1
var house_id: String = ""
## Casita frente a la que aparece el aprendiz al volver al mapa de sección.
var return_house: String = ""

var _state_before_pause: State = State.MENU
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(ThemeColors.NOCHE, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade)


## Acciones de entrada (se registran en código para no depender del editor).
func _setup_inputs() -> void:
	var actions := {
		"move_left": [KEY_LEFT, KEY_A],
		"move_right": [KEY_RIGHT, KEY_D],
		"move_up": [KEY_UP, KEY_W],
		"move_down": [KEY_DOWN, KEY_S],
		"interact": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
		"pause": [KEY_ESCAPE],
	}
	for action: String in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _busy:
		toggle_pause()
		get_viewport().set_input_as_handled()


func set_state(s: State) -> void:
	state = s
	state_changed.emit(s)


func goto_menu() -> void:
	_change("menu", State.MENU)


func goto_world_map() -> void:
	_change("world_map", State.WORLD_MAP)


func goto_section(id: int, from_house: String = "") -> void:
	world_id = id
	return_house = from_house
	_change("section_map", State.SECTION_MAP)


## Entra a una casita: nivel del Frasco, boss, minijuego o "Próximamente".
func goto_house(id: String) -> void:
	house_id = id
	world_id = ContentDB.world_of(id)
	var content := ContentDB.get_content(id)
	var key := "coming_soon"
	if content.has("rounds") and content.has("enemy"):
		key = "level"  # boss: rondas de Frasco
	elif str(content.get("kind", "")) == "completa_el_hechizo":
		key = "minigame"
	elif str(content.get("mechanic", "")) == "frasco":
		key = "level"
	_change(key, State.LEVEL)


func back_to_section() -> void:
	goto_section(world_id, house_id)


func retry() -> void:
	goto_house(house_id)


func toggle_pause() -> void:
	if state == State.PAUSED:
		resume()
	elif state == State.LEVEL or state == State.SECTION_MAP:
		pause()


func pause() -> void:
	if get_tree().paused or _busy:
		return
	_state_before_pause = state
	var overlay: Node = load(PAUSE_SCENE).instantiate()
	overlay.name = "PauseOverlay"
	get_tree().current_scene.add_child(overlay)
	get_tree().paused = true
	set_state(State.PAUSED)


func resume() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_node("PauseOverlay"):
		scene.get_node("PauseOverlay").queue_free()
	get_tree().paused = false
	set_state(_state_before_pause)


## Muestra el resultado encima del nivel. info: {success, xp, title, message, creature, is_boss}.
func show_result(info: Dictionary) -> Node:
	var overlay: Node = load(RESULT_SCENE).instantiate()
	overlay.name = "ResultOverlay"
	overlay.set("info", info)
	get_tree().current_scene.add_child(overlay)
	set_state(State.RESULT)
	return overlay


func close_result() -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_node("ResultOverlay"):
		scene.get_node("ResultOverlay").queue_free()
	set_state(State.LEVEL)


func _change(key: String, new_state: State) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await tw.finished
	get_tree().change_scene_to_file(SCENES[key])
	set_state(new_state)
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await tw2.finished
	_busy = false
