## test_runner.gd — Lightweight test runner for 暗潮 SLG
## Runs all test_*.gd files and reports results.
extends Node

var _pass: int = 0
var _fail: int = 0
var _errors: Array = []

func _ready() -> void:
	print("=" .repeat(60))
	print("  暗潮 SLG — Test Suite")
	print("=" .repeat(60))

	_run_test_file("res://tests/test_balance_config.gd")
	_run_test_file("res://tests/test_resource_manager.gd")
	_run_test_file("res://tests/test_event_bus.gd")
	_run_test_file("res://tests/test_faction_data.gd")
	_run_test_file("res://tests/test_hero_leveling.gd")
	_run_test_file("res://tests/test_combat_resolver.gd")
	_run_test_file("res://tests/test_save_manager.gd")

	print("")
	print("=" .repeat(60))
	print("  RESULTS: %d/%d passed" % [_pass, _pass + _fail])
	if _fail > 0:
		print("  FAILURES:")
		for e in _errors:
			print("    - %s" % e)
	else:
		print("  ALL TESTS PASSED")
	print("=" .repeat(60))
	get_tree().quit(0 if _fail == 0 else 1)


func _run_test_file(path: String) -> void:
	var script = load(path)
	if script == null:
		print("SKIP: %s (not found)" % path)
		return
	var test_obj = script.new()
	print("\n--- %s ---" % path.get_file())
	for method in test_obj.get_method_list():
		var mname: String = method["name"]
		if not mname.begins_with("test_"):
			continue
		# Reset state before each test if available
		if test_obj.has_method("setup"):
			test_obj.call("setup")
		var result: String = test_obj.call(mname)
		if result == "PASS":
			_pass += 1
			print("  PASS: %s" % mname)
		else:
			_fail += 1
			_errors.append("%s::%s — %s" % [path.get_file(), mname, result])
			print("  FAIL: %s — %s" % [mname, result])
	if test_obj is RefCounted:
		pass  # Will be freed automatically
	elif test_obj is Node:
		test_obj.queue_free()
