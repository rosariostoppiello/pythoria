extends SceneTree
## Herramienta de desarrollo: corre programas de un JSON con PyEval y escribe lo que
## imprimen, para compararlo con Python real (tools/py_diff.py).
## Uso: godot --headless --path . -s tools/py_diff_runner.gd -- entrada.json salida.json


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var progs: Array = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var out: Array = []
	for p: Dictionary in progs:
		var r := PyEval.run(p["code"].split("\n"), {}, p.get("inputs", []), p.get("files", {}))
		out.append({"output": r["output"], "error": r["error"], "message": r["message"]})
	var f := FileAccess.open(args[1], FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	quit()
