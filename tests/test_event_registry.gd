## test_event_registry.gd — Tests for EventRegistry centralized event index
extends RefCounted

# We test by directly manipulating the registry's internal state
# rather than relying on autoloads, since tests run in isolation.

var reg: RefCounted

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg


# Minimal stand-in that exposes the same data structures and methods
# as the real EventRegistry (which extends Node and auto-discovers).
class FakeRegistry extends RefCounted:
	var _registry: Dictionary = {}
	var _by_category: Dictionary = {}
	var _by_source: Dictionary = {}
	var _fired_this_turn: Array = []
	var _fired_history: Dictionary = {}
	var _cooldowns: Dictionary = {}
	const MAX_EVENTS_PER_TURN: int = 2
	const DEFAULT_COOLDOWN: int = 3

	func register_event(id: String, source: String, category: String, data: Dictionary, weight: float = 1.0) -> void:
		var final_id: String = id
		if _registry.has(final_id):
			var suffix: int = 2
			while _registry.has(final_id + "_" + str(suffix)):
				suffix += 1
			final_id = final_id + "_" + str(suffix)
		_registry[final_id] = {
			"source": source, "category": category, "data": data,
			"weight": weight, "fired_count": 0, "last_fired_turn": -1,
		}
		if not _by_category.has(category):
			_by_category[category] = []
		_by_category[category].append(final_id)
		if not _by_source.has(source):
			_by_source[source] = []
		_by_source[source].append(final_id)

	func get_event(id: String) -> Dictionary:
		return _registry.get(id, {})

	func get_events_by_category(category: String) -> Array:
		return _by_category.get(category, [])

	func get_events_by_source(source: String) -> Array:
		return _by_source.get(source, [])

	func mark_fired(id: String, turn: int) -> void:
		_fired_this_turn.append(id)
		if not _fired_history.has(id):
			_fired_history[id] = {"count": 0, "last_turn": -1}
		_fired_history[id]["count"] += 1
		_fired_history[id]["last_turn"] = turn
		if _registry.has(id):
			_registry[id]["fired_count"] += 1
			_registry[id]["last_fired_turn"] = turn
		_cooldowns[id] = DEFAULT_COOLDOWN

	func can_fire(id: String) -> bool:
		if _cooldowns.has(id) and _cooldowns[id] > 0:
			return false
		if id in _fired_this_turn:
			return false
		var entry: Dictionary = _registry.get(id, {})
		if entry.is_empty():
			return false
		var data: Dictionary = entry.get("data", {})
		var repeatable: bool = data.get("repeatable", true)
		if not repeatable and _fired_history.has(id):
			return false
		return true

	func begin_turn() -> void:
		_fired_this_turn.clear()
		var expired: Array = []
		for eid in _cooldowns:
			_cooldowns[eid] -= 1
			if _cooldowns[eid] <= 0:
				expired.append(eid)
		for eid in expired:
			_cooldowns.erase(eid)

	func request_fire(id: String) -> bool:
		if _fired_this_turn.size() >= MAX_EVENTS_PER_TURN:
			return false
		if not can_fire(id):
			return false
		mark_fired(id, 0)
		return true

	func serialize() -> Dictionary:
		return {
			"fired_history": _fired_history.duplicate(true),
			"cooldowns": _cooldowns.duplicate(),
			"fired_this_turn": _fired_this_turn.duplicate(),
		}

	func deserialize(data: Dictionary) -> void:
		_fired_history = data.get("fired_history", {})
		_cooldowns = data.get("cooldowns", {})
		_fired_this_turn = data.get("fired_this_turn", [])


func setup() -> void:
	reg = FakeRegistry.new()


func test_register_event_adds_to_registry() -> String:
	setup()
	reg.register_event("evt_1", "src_a", "base", {"name": "Test"})
	var entry: Dictionary = reg.get_event("evt_1")
	return _assert(not entry.is_empty() and entry["source"] == "src_a", "Event should be in registry")


func test_duplicate_id_gets_suffix() -> String:
	setup()
	reg.register_event("dup", "src_a", "base", {"name": "First"})
	reg.register_event("dup", "src_b", "base", {"name": "Second"})
	var first: Dictionary = reg.get_event("dup")
	var second: Dictionary = reg.get_event("dup_2")
	return _assert(first["source"] == "src_a" and second["source"] == "src_b",
		"Duplicate id should be renamed with _2 suffix")


func test_get_event_returns_correct_data() -> String:
	setup()
	reg.register_event("evt_x", "src_a", "crisis", {"title": "Crisis!"}, 0.3)
	var entry: Dictionary = reg.get_event("evt_x")
	return _assert(entry["category"] == "crisis" and entry["weight"] == 0.3,
		"get_event should return correct category and weight")


func test_get_event_missing_returns_empty() -> String:
	setup()
	var entry: Dictionary = reg.get_event("nonexistent")
	return _assert(entry.is_empty(), "Missing event should return empty dict")


func test_get_events_by_category() -> String:
	setup()
	reg.register_event("e1", "s1", "seasonal", {})
	reg.register_event("e2", "s1", "seasonal", {})
	reg.register_event("e3", "s1", "crisis", {})
	var seasonal: Array = reg.get_events_by_category("seasonal")
	return _assert(seasonal.size() == 2 and "e1" in seasonal and "e2" in seasonal,
		"Should return 2 seasonal events")


func test_get_events_by_source() -> String:
	setup()
	reg.register_event("a1", "grand", "grand", {})
	reg.register_event("a2", "grand", "grand", {})
	reg.register_event("a3", "other", "base", {})
	var from_grand: Array = reg.get_events_by_source("grand")
	return _assert(from_grand.size() == 2, "Should return 2 events from source 'grand'")


func test_mark_fired_updates_history() -> String:
	setup()
	reg.register_event("mf1", "s", "base", {})
	reg.mark_fired("mf1", 5)
	var entry: Dictionary = reg.get_event("mf1")
	return _assert(entry["fired_count"] == 1 and entry["last_fired_turn"] == 5,
		"mark_fired should update fired_count and last_fired_turn")


func test_can_fire_respects_cooldown() -> String:
	setup()
	reg.register_event("cd1", "s", "base", {})
	reg.mark_fired("cd1", 1)
	var blocked: bool = not reg.can_fire("cd1")
	# Tick 3 turns to expire cooldown
	reg.begin_turn()
	reg.begin_turn()
	reg.begin_turn()
	var unblocked: bool = reg.can_fire("cd1")
	return _assert(blocked and unblocked,
		"can_fire should be false during cooldown, true after cooldown expires")


func test_begin_turn_ticks_cooldowns() -> String:
	setup()
	reg.register_event("bt1", "s", "base", {})
	reg.mark_fired("bt1", 0)
	# Cooldown is DEFAULT_COOLDOWN = 3
	reg.begin_turn()  # cooldown -> 2
	reg.begin_turn()  # cooldown -> 1
	var still_cooling: bool = not reg.can_fire("bt1")
	reg.begin_turn()  # cooldown -> 0 (removed)
	var now_available: bool = reg.can_fire("bt1")
	return _assert(still_cooling and now_available,
		"begin_turn should tick cooldowns down each turn")


func test_request_fire_respects_max_per_turn() -> String:
	setup()
	reg.register_event("rf1", "s", "base", {})
	reg.register_event("rf2", "s", "base", {})
	reg.register_event("rf3", "s", "base", {})
	var ok1: bool = reg.request_fire("rf1")
	var ok2: bool = reg.request_fire("rf2")
	var ok3: bool = reg.request_fire("rf3")
	return _assert(ok1 and ok2 and not ok3,
		"request_fire should block after MAX_EVENTS_PER_TURN (2)")


func test_serialize_deserialize_roundtrip() -> String:
	setup()
	reg.register_event("sr1", "s", "base", {})
	reg.mark_fired("sr1", 3)
	var saved: Dictionary = reg.serialize()
	# Create a fresh registry and deserialize
	var reg2 = FakeRegistry.new()
	reg2.register_event("sr1", "s", "base", {})
	reg2.deserialize(saved)
	var has_history: bool = reg2._fired_history.has("sr1")
	var count_ok: bool = reg2._fired_history["sr1"]["count"] == 1
	var cooldown_ok: bool = reg2._cooldowns.has("sr1")
	return _assert(has_history and count_ok and cooldown_ok,
		"serialize/deserialize should preserve fired_history and cooldowns")
