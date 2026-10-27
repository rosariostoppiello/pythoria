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
	# PY_EXPR: expresiones separadas por ";" que se ejecutan sobre la escena (ej. "board.place(0, 0)").
	var exprs := OS.get_environment("PY_EXPR")
	if exprs != "":
		for src: String in exprs.split(";"):
			var e := Expression.new()
			if e.parse(src.strip_edges()) == OK:
				e.execute([], current_scene)
			else:
				push_error("PY_EXPR inválida: " + src)
		for i in int(OS.get_environment("PY_WAIT")) if OS.get_environment("PY_WAIT") != "" else 20:
			await process_frame
		if OS.get_environment("PY_SECONDS") != "":
			await create_timer(float(OS.get_environment("PY_SECONDS"))).timeout
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("captura: ", out)
	quit()
