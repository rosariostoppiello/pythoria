extends SceneTree
## Captura de pantalla de una escena (necesita ventana, no headless).
## Uso: godot --path . -s tools/screenshot.gd -- <escena.tscn> <salida.png> [world_id] [house_id] [frames]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0]
	var out: String = args[1]
	var save := root.get_node("SaveSystem")
	save.save_path = "user://screenshot_save.json"
	if args.size() > 2:
		root.get_node("SceneManager").world_id = int(args[2])
	if args.size() > 3:
		root.get_node("SceneManager").house_id = args[3]
	var frames := int(args[4]) if args.size() > 4 else 30
	var gs := root.get_node("GameState")
	gs.reset()
	var progress := OS.get_environment("PY_COMPLETED")
	if progress != "":
		for id: String in progress.split(","):
			gs.completed.append(id)
	gs.xp = int(OS.get_environment("PY_XP")) if OS.get_environment("PY_XP") != "" else 0
	change_scene_to_file(scene_path)
	for i in frames:
		await process_frame
	var hook := OS.get_environment("PY_HOOK")
	if hook != "" and current_scene.has_method(hook):
		await current_scene.call(hook)
		for i in 10:
			await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("captura: ", out)
	quit()
