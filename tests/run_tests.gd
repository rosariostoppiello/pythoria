extends SceneTree
## Ejecuta todos los tests/test_*.gd. Sale con código 1 si algo falla.
## Uso: godot --headless --path . -s tests/run_tests.gd

const TESTS_DIR := "res://tests/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var total := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at(TESTS_DIR))
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		var script: GDScript = load(TESTS_DIR + file)
		for m: Dictionary in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t.tree = self
			t.before_each()
			await t.call(name)
			t.after_each()
			total += 1
			if t.failures.is_empty():
				print("  ok    %s::%s" % [file, name])
			else:
				failed += 1
				print("  FALLA %s::%s" % [file, name])
				for f: String in t.failures:
					print("        - ", f)
	for i in 3:
		await process_frame
	print("\n%d tests, %d fallaron" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)
