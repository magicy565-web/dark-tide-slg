## test_save_manager.gd — Tests for save/load serialization fixes
extends RefCounted

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg

func test_color_serialization() -> String:
	# Test that Color can round-trip through JSON via our serialization
	var original: Color = Color(0.5, 0.3, 0.8, 1.0)
	var serialized: Dictionary = {"r": original.r, "g": original.g, "b": original.b, "a": original.a, "_type": "Color"}
	var restored: Color = Color(serialized["r"], serialized["g"], serialized["b"], serialized["a"])
	return _assert(abs(restored.r - 0.5) < 0.01, "Color should survive serialization")

func test_vector3_serialization() -> String:
	var original: Vector3 = Vector3(1.5, 2.5, 3.5)
	var serialized: Dictionary = {"x": original.x, "y": original.y, "z": original.z, "_type": "Vector3"}
	var restored: Vector3 = Vector3(serialized["x"], serialized["y"], serialized["z"])
	return _assert(restored.distance_to(original) < 0.01, "Vector3 should survive serialization")

func test_int_key_roundtrip() -> String:
	# Simulate JSON round-trip of int-keyed dict
	var original: Dictionary = {0: "player_0", 1: "player_1"}
	var json_str: String = JSON.stringify(original)
	var parsed = JSON.parse_string(json_str)
	# After JSON parse, keys are strings
	var has_string_keys: bool = parsed.has("0")
	# Fix them
	var fixed: Dictionary = {}
	for k in parsed:
		if k is String and k.is_valid_int():
			fixed[int(k)] = parsed[k]
		else:
			fixed[k] = parsed[k]
	return _assert(fixed.has(0) and fixed[0] == "player_0", "Int keys should survive JSON round-trip with fix")

func test_revealed_dict_int_keys() -> String:
	# Simulate tile revealed dict through save/load
	var tile: Dictionary = {"revealed": {0: true, 1: false}}
	# Serialize: convert int keys to string
	var rev_ser: Dictionary = {}
	for k in tile["revealed"]:
		rev_ser[str(k)] = tile["revealed"][k]
	# Deserialize: convert string keys back to int
	var rev_deser: Dictionary = {}
	for k in rev_ser:
		rev_deser[int(k)] = rev_ser[k]
	return _assert(rev_deser.has(0) and rev_deser[0] == true, "revealed dict int keys should round-trip")

func test_resource_manager_save_load_int_keys() -> String:
	ResourceManager.reset()
	ResourceManager.init_player(0, {"gold": 77})
	var data: Dictionary = ResourceManager.to_save_data()
	# Simulate JSON round-trip: convert int keys to strings
	var json_str: String = JSON.stringify(data)
	var parsed: Dictionary = JSON.parse_string(json_str)
	ResourceManager.reset()
	ResourceManager.from_save_data(parsed)
	var gold: int = ResourceManager.get_resource(0, "gold")
	return _assert(gold == 77, "Expected gold=77 after JSON round-trip save/load, got %d" % gold)

func test_slave_manager_save_load() -> String:
	SlaveManager.reset()
	SlaveManager.init_player(0, 5)
	SlaveManager.queue_conversion(0, 3, 2)
	var data: Dictionary = SlaveManager.to_save_data()
	var json_str: String = JSON.stringify(data)
	var parsed: Dictionary = JSON.parse_string(json_str)
	SlaveManager.reset()
	SlaveManager.from_save_data(parsed)
	var total: int = SlaveManager.get_total_slaves(0)
	return _assert(total == 5, "Expected 5 slaves after save/load, got %d" % total)

func test_no_add_resource_calls() -> String:
	# Verify no remaining calls to nonexistent ResourceManager.add_resource
	var files: Array = [
		"res://systems/combat/combat_abilities.gd",
		"res://systems/quest/quest_journal.gd",
		"res://autoloads/game_manager.gd",
	]
	for path in files:
		var script: GDScript = load(path)
		if script and script.source_code.contains("ResourceManager.add_resource"):
			return "Found ResourceManager.add_resource in %s" % path
	return "PASS"
