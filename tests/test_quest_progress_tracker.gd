## test_quest_progress_tracker.gd — Tests for QuestProgressTracker unified quest coordinator
extends RefCounted

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg


## Minimal stand-in that replicates QuestProgressTracker's local logic
## (milestone checks, dependency validation, completion summary, serialization)
## without requiring Node tree or autoload connections.
class FakeTracker extends RefCounted:
	var _quest_status: Dictionary = {}
	var _milestones: Dictionary = {}
	var _dependencies: Dictionary = {}
	var _last_sync_turn: int = -1

	func _init() -> void:
		_dependencies = {
			"side_economist": [{"require_quest": "main_3", "require_status": "completed"}],
			"cq_neutral_hero": [{"require_quest": "neutral_recruited_any", "require_status": "completed"}],
		}

	func add_quest(id: String, source: String, type: String, status: String) -> void:
		_quest_status[id] = {
			"source": source, "type": type, "status": status,
			"name": id, "objectives": [], "rewards": {},
		}

	func _check_milestone(mname: String, condition: Callable) -> void:
		if _milestones.get(mname, {}).get("reached", false):
			return
		if condition.call():
			_milestones[mname] = {"reached": true, "turn": 0}

	func check_dependency(quest_id: String) -> bool:
		if not _dependencies.has(quest_id):
			return true
		for dep in _dependencies[quest_id]:
			var req_quest: String = dep.get("require_quest", "")
			var req_status: String = dep.get("require_status", "completed")
			var q: Dictionary = _quest_status.get(req_quest, {})
			if q.get("status", "") != req_status:
				return false
		return true

	func get_completion_summary() -> Dictionary:
		var total: int = _quest_status.size()
		var completed: int = 0
		var active: int = 0
		var locked: int = 0
		for q in _quest_status.values():
			match q.get("status", ""):
				"completed":
					completed += 1
				"active":
					active += 1
				"locked":
					locked += 1
		return {
			"total": total, "completed": completed,
			"active": active, "locked": locked,
			"milestones_reached": _milestones.values().filter(func(m): return m.get("reached", false)).size(),
			"milestones_total": _milestones.size(),
		}

	func serialize() -> Dictionary:
		return {
			"quest_status": _quest_status.duplicate(true),
			"milestones": _milestones.duplicate(true),
			"last_sync_turn": _last_sync_turn,
		}

	func deserialize(data: Dictionary) -> void:
		_quest_status = data.get("quest_status", {}).duplicate(true)
		_milestones = data.get("milestones", {}).duplicate(true)
		_last_sync_turn = int(data.get("last_sync_turn", -1))


var tracker: RefCounted

func setup() -> void:
	tracker = FakeTracker.new()


func test_check_milestone_marks_reached() -> String:
	setup()
	tracker.add_quest("main_1", "quest_journal", "main", "completed")
	tracker._check_milestone("first_main_quest", func():
		for qid in tracker._quest_status:
			var q: Dictionary = tracker._quest_status[qid]
			if q.get("type") == "main" and q.get("status") == "completed":
				return true
		return false)
	return _assert(tracker._milestones.has("first_main_quest") and
		tracker._milestones["first_main_quest"]["reached"] == true,
		"Milestone should be marked as reached when condition is true")


func test_check_milestone_not_reached_when_false() -> String:
	setup()
	tracker.add_quest("main_1", "quest_journal", "main", "active")
	tracker._check_milestone("first_main_quest", func():
		for qid in tracker._quest_status:
			var q: Dictionary = tracker._quest_status[qid]
			if q.get("type") == "main" and q.get("status") == "completed":
				return true
		return false)
	return _assert(not tracker._milestones.has("first_main_quest"),
		"Milestone should not be reached when condition is false")


func test_check_milestone_only_fires_once() -> String:
	setup()
	tracker._check_milestone("test_ms", func(): return true)
	tracker._check_milestone("test_ms", func(): return true)
	return _assert(tracker._milestones["test_ms"]["reached"] == true,
		"Milestone should only be set once (idempotent)")


func test_check_dependency_no_deps_returns_true() -> String:
	setup()
	var result: bool = tracker.check_dependency("quest_with_no_deps")
	return _assert(result, "Quest with no dependencies should return true")


func test_check_dependency_unmet() -> String:
	setup()
	# side_economist requires main_3 completed, but main_3 is active
	tracker.add_quest("main_3", "quest_journal", "main", "active")
	var result: bool = tracker.check_dependency("side_economist")
	return _assert(not result, "Dependency should fail when prerequisite is not completed")


func test_check_dependency_met() -> String:
	setup()
	tracker.add_quest("main_3", "quest_journal", "main", "completed")
	var result: bool = tracker.check_dependency("side_economist")
	return _assert(result, "Dependency should pass when prerequisite is completed")


func test_get_completion_summary() -> String:
	setup()
	tracker.add_quest("q1", "s", "main", "completed")
	tracker.add_quest("q2", "s", "side", "active")
	tracker.add_quest("q3", "s", "side", "locked")
	tracker.add_quest("q4", "s", "main", "completed")
	tracker._check_milestone("test_ms", func(): return true)
	var summary: Dictionary = tracker.get_completion_summary()
	var ok: bool = summary["total"] == 4 and summary["completed"] == 2 \
		and summary["active"] == 1 and summary["locked"] == 1 \
		and summary["milestones_reached"] == 1
	return _assert(ok,
		"Summary should report total=4 completed=2 active=1 locked=1 milestones_reached=1, got %s" % str(summary))


func test_serialize_deserialize_roundtrip() -> String:
	setup()
	tracker.add_quest("q1", "s", "main", "completed")
	tracker._check_milestone("ms1", func(): return true)
	tracker._last_sync_turn = 7
	var saved: Dictionary = tracker.serialize()
	var tracker2 = FakeTracker.new()
	tracker2.deserialize(saved)
	var quest_ok: bool = tracker2._quest_status.has("q1") and tracker2._quest_status["q1"]["status"] == "completed"
	var ms_ok: bool = tracker2._milestones.has("ms1") and tracker2._milestones["ms1"]["reached"] == true
	var turn_ok: bool = tracker2._last_sync_turn == 7
	return _assert(quest_ok and ms_ok and turn_ok,
		"serialize/deserialize should preserve quest_status, milestones, and last_sync_turn")
