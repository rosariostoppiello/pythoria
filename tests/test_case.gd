class_name TestCase
extends RefCounted
## Base mínima para tests. Cada método test_* puede ser async (await).

var failures: Array[String] = []
var tree: SceneTree


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)


func check_eq(got: Variant, expected: Variant, msg: String) -> void:
	if typeof(got) != typeof(expected) or got != expected:
		failures.append("%s: obtuve %s (%s), esperaba %s (%s)" % [msg, var_to_str(got), type_string(typeof(got)), var_to_str(expected), type_string(typeof(expected))])


func before_each() -> void:
	pass


func after_each() -> void:
	pass
