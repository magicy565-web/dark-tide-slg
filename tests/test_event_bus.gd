## test_event_bus.gd — Tests for EventBus signal existence
extends RefCounted

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg

func test_combat_started_signal() -> String:
	return _assert(EventBus.has_signal("combat_started"), "Missing combat_started signal")

func test_combat_result_signal() -> String:
	return _assert(EventBus.has_signal("combat_result"), "Missing combat_result signal")

func test_message_log_signal() -> String:
	return _assert(EventBus.has_signal("message_log"), "Missing message_log signal")

func test_turn_started_signal() -> String:
	return _assert(EventBus.has_signal("turn_started"), "Missing turn_started signal")

func test_turn_ended_signal() -> String:
	return _assert(EventBus.has_signal("turn_ended"), "Missing turn_ended signal")

func test_quest_journal_updated_signal() -> String:
	return _assert(EventBus.has_signal("quest_journal_updated"), "Missing quest_journal_updated signal")
