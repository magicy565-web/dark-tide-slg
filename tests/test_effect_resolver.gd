## test_effect_resolver.gd — Tests for EffectResolver centralized effect pipeline
extends RefCounted

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg


## Minimal stand-in that replicates the handler dispatch logic of EffectResolver
## without requiring Node tree, autoloads, or signals.
class FakeEffectResolver extends RefCounted:
	var _handlers: Dictionary = {}
	var _last_resolved: Array = []
	var _applied_resources: Dictionary = {}  # resource_key -> total delta

	func _init() -> void:
		_register_handlers()

	func _register_handlers() -> void:
		_handlers["gold"] = _apply_resource.bind("gold")
		_handlers["food"] = _apply_resource.bind("food")
		_handlers["iron"] = _apply_resource.bind("iron")
		_handlers["slaves"] = _apply_resource.bind("slaves")
		_handlers["prestige"] = _apply_resource.bind("prestige")
		# Meta keys (no-ops)
		for meta_key in ["type", "success_rate", "success", "fail", "duration"]:
			_handlers[meta_key] = _noop

	func resolve(effects: Dictionary, context: Dictionary = {}) -> Array:
		_last_resolved.clear()
		if effects.is_empty():
			return _last_resolved
		for key in effects:
			if _handlers.has(key):
				var result_msg: String = _handlers[key].call(effects[key], context)
				_last_resolved.append({
					"key": key, "value": effects[key],
					"success": true, "message": result_msg,
				})
			else:
				_last_resolved.append({
					"key": key, "value": effects[key],
					"success": false, "message": "no handler",
				})
		return _last_resolved

	func get_last_resolved() -> Array:
		return _last_resolved

	func _apply_resource(value, _context, res_key: String) -> String:
		_applied_resources[res_key] = _applied_resources.get(res_key, 0) + int(value)
		return "%s %+d" % [res_key, value]

	func _noop(_value, _context) -> String:
		return ""


var resolver: RefCounted

func setup() -> void:
	resolver = FakeEffectResolver.new()


func test_resolve_resource_gold() -> String:
	setup()
	resolver.resolve({"gold": 50}, {})
	return _assert(resolver._applied_resources.get("gold", 0) == 50,
		"resolve gold should apply +50")


func test_resolve_resource_food_iron() -> String:
	setup()
	resolver.resolve({"food": -10, "iron": 25}, {})
	var food_ok: bool = resolver._applied_resources.get("food", 0) == -10
	var iron_ok: bool = resolver._applied_resources.get("iron", 0) == 25
	return _assert(food_ok and iron_ok, "resolve should apply food and iron deltas")


func test_resolve_multiple_resources() -> String:
	setup()
	resolver.resolve({"gold": 100, "food": 50, "iron": 30}, {})
	var results: Array = resolver.get_last_resolved()
	var keys: Array = []
	for r in results:
		keys.append(r["key"])
	return _assert("gold" in keys and "food" in keys and "iron" in keys,
		"All three resource keys should appear in results")


func test_resolve_unknown_effect_no_crash() -> String:
	setup()
	var results: Array = resolver.resolve({"totally_unknown_key": 99}, {})
	return _assert(results.size() == 1 and results[0]["success"] == false,
		"Unknown effect key should not crash, should return success=false")


func test_get_last_resolved_returns_results() -> String:
	setup()
	resolver.resolve({"gold": 10}, {})
	var last: Array = resolver.get_last_resolved()
	return _assert(last.size() == 1 and last[0]["key"] == "gold" and last[0]["success"] == true,
		"get_last_resolved should return the most recent resolve results")


func test_resolve_empty_effects() -> String:
	setup()
	var results: Array = resolver.resolve({}, {})
	return _assert(results.is_empty(), "Empty effects should return empty results")


func test_resolve_meta_keys_are_noop() -> String:
	setup()
	var results: Array = resolver.resolve({"type": "gamble", "success_rate": 0.5}, {})
	# Meta keys are handled but produce no resource changes
	return _assert(resolver._applied_resources.is_empty(),
		"Meta keys should not produce resource changes")


func test_resolve_accumulates_across_calls() -> String:
	setup()
	resolver.resolve({"gold": 30}, {})
	resolver.resolve({"gold": 20}, {})
	return _assert(resolver._applied_resources.get("gold", 0) == 50,
		"Resource deltas should accumulate across resolve calls")
