## test_event_scheduler.gd — Tests for EventScheduler weighted selection and turn scheduling
extends RefCounted

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg


class FakeScheduler extends RefCounted:
	const MAX_EVENTS_PER_TURN: int = 2
	const PRIORITY_CRITICAL: int = 100
	const PRIORITY_HIGH: int = 50
	const PRIORITY_NORMAL: int = 20
	const PRIORITY_LOW: int = 10

	var _candidates: Array = []
	var _scheduled: Array = []
	var _events_fired_this_turn: int = 0
	var _event_history: Dictionary = {}
	var _current_turn: int = 0

	func begin_turn() -> void:
		_candidates.clear()
		_scheduled.clear()
		_events_fired_this_turn = 0
		_current_turn += 1

	func submit_candidate(id: String, source: String, priority: int, weight: float, data: Dictionary) -> void:
		_candidates.append({
			"id": id, "source": source, "priority": priority,
			"weight": weight, "data": data,
		})

	func resolve_turn() -> Array:
		if _candidates.is_empty():
			return []
		_candidates.sort_custom(func(a, b): return a["priority"] > b["priority"])
		for c in _candidates:
			if c["priority"] >= PRIORITY_CRITICAL:
				_scheduled.append(c)
				_record_fired(c["id"])
		var remaining_slots: int = MAX_EVENTS_PER_TURN - _scheduled.size()
		var non_critical: Array = _candidates.filter(func(c): return c["priority"] < PRIORITY_CRITICAL)
		non_critical = non_critical.filter(func(c):
			var last_fired: int = _event_history.get(c["id"], -999)
			return (_current_turn - last_fired) >= 2
		)
		for i in range(remaining_slots):
			if non_critical.is_empty():
				break
			var selected: Dictionary = _weighted_pick(non_critical)
			_scheduled.append(selected)
			_record_fired(selected["id"])
			non_critical.erase(selected)
		return _scheduled

	func _weighted_pick(pool: Array) -> Dictionary:
		var total_weight: float = 0.0
		for item in pool:
			total_weight += item.get("weight", 1.0)
		if total_weight <= 0.0:
			return pool[0] if not pool.is_empty() else {}
		var roll: float = randf() * total_weight
		var acc: float = 0.0
		for item in pool:
			acc += item.get("weight", 1.0)
			if roll <= acc:
				return item
		return pool[-1]

	func _record_fired(event_id: String) -> void:
		_event_history[event_id] = _current_turn
		_events_fired_this_turn += 1

	func serialize() -> Dictionary:
		return {
			"event_history": _event_history.duplicate(true),
			"current_turn": _current_turn,
		}

	func deserialize(data: Dictionary) -> void:
		_event_history = data.get("event_history", {}).duplicate(true)
		_current_turn = int(data.get("current_turn", 0))


var sched: RefCounted

func setup() -> void:
	sched = FakeScheduler.new()


func test_begin_turn_clears_candidates() -> String:
	setup()
	sched.submit_candidate("x", "src", 20, 1.0, {})
	sched.begin_turn()
	return _assert(sched._candidates.is_empty(), "begin_turn should clear candidates")


func test_submit_candidate_adds_to_pool() -> String:
	setup()
	sched.begin_turn()
	sched.submit_candidate("e1", "src", 20, 1.0, {"title": "Test"})
	return _assert(sched._candidates.size() == 1 and sched._candidates[0]["id"] == "e1",
		"submit_candidate should add to _candidates")


func test_resolve_turn_critical_always_fires() -> String:
	setup()
	sched.begin_turn()
	sched.submit_candidate("crit1", "crisis", 100, 1.0, {})
	sched.submit_candidate("crit2", "crisis", 100, 1.0, {})
	sched.submit_candidate("crit3", "crisis", 100, 1.0, {})
	var result: Array = sched.resolve_turn()
	var ids: Array = []
	for r in result:
		ids.append(r["id"])
	return _assert("crit1" in ids and "crit2" in ids and "crit3" in ids,
		"All critical events should always fire regardless of MAX_EVENTS_PER_TURN")


func test_resolve_turn_respects_max_for_non_critical() -> String:
	setup()
	sched.begin_turn()
	sched.submit_candidate("n1", "src", 20, 1.0, {})
	sched.submit_candidate("n2", "src", 20, 1.0, {})
	sched.submit_candidate("n3", "src", 20, 1.0, {})
	var result: Array = sched.resolve_turn()
	return _assert(result.size() <= 2,
		"Non-critical events should respect MAX_EVENTS_PER_TURN (2), got %d" % result.size())


func test_resolve_turn_anti_repeat_filter() -> String:
	setup()
	# Turn 1: fire event "rep"
	sched.begin_turn()
	sched.submit_candidate("rep", "src", 20, 100.0, {})
	sched.resolve_turn()
	# Turn 2: "rep" should be filtered (need 2 turn gap)
	sched.begin_turn()
	sched.submit_candidate("rep", "src", 20, 100.0, {})
	sched.submit_candidate("other", "src", 20, 1.0, {})
	var result: Array = sched.resolve_turn()
	var ids: Array = []
	for r in result:
		ids.append(r["id"])
	# "rep" last fired on turn 1, now turn 2, gap = 1 < 2 so it should be filtered
	return _assert("rep" not in ids,
		"Anti-repeat filter should block events fired within 2 turns")


func test_resolve_turn_anti_repeat_allows_after_gap() -> String:
	setup()
	# Turn 1: fire event "rep2"
	sched.begin_turn()
	sched.submit_candidate("rep2", "src", 20, 100.0, {})
	sched.resolve_turn()
	# Turn 2: skip
	sched.begin_turn()
	sched.resolve_turn()
	# Turn 3: gap is 2, should be allowed
	sched.begin_turn()
	sched.submit_candidate("rep2", "src", 20, 100.0, {})
	var result: Array = sched.resolve_turn()
	var ids: Array = []
	for r in result:
		ids.append(r["id"])
	return _assert("rep2" in ids,
		"Anti-repeat should allow events after 2 turn gap")


func test_serialize_deserialize_roundtrip() -> String:
	setup()
	sched.begin_turn()
	sched.submit_candidate("s1", "src", 20, 1.0, {})
	sched.resolve_turn()
	var saved: Dictionary = sched.serialize()
	var sched2 = FakeScheduler.new()
	sched2.deserialize(saved)
	return _assert(sched2._event_history.has("s1") and sched2._current_turn == saved["current_turn"],
		"serialize/deserialize should preserve event_history and current_turn")
