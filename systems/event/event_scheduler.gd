extends Node
## EventScheduler — Weighted event selection and turn-level scheduling (v1.0)
## Collects event candidates from all systems each turn, weights them by
## rarity/priority, selects up to MAX_EVENTS_PER_TURN using weighted random,
## and prevents event flooding.

# ═══════════════ CONSTANTS ═══════════════

const MAX_EVENTS_PER_TURN: int = 2
const PRIORITY_CRITICAL: int = 100  # Crisis, story milestones — always fire
const PRIORITY_HIGH: int = 50       # Grand events, faction destruction
const PRIORITY_NORMAL: int = 20     # Regular events
const PRIORITY_LOW: int = 10        # Flavor/random events

# ═══════════════ STATE ═══════════════

# Candidate pool for current turn
var _candidates: Array = []  # [{id, source, priority, weight, data}]

# Selected events for this turn
var _scheduled: Array = []

# Gate counter: how many events have actually fired this turn
var _events_fired_this_turn: int = 0

# History for cooldown / anti-repeat: event_id -> last_turn_fired
var _event_history: Dictionary = {}

# Current turn number (set by begin_turn)
var _current_turn: int = 0

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	pass  # No auto-connect; game_manager calls begin_turn/resolve_turn directly


# ═══════════════ TURN FLOW ═══════════════

func begin_turn() -> void:
	## Called at the START of begin_turn() in game_manager.
	## Resets the candidate pool and scheduled list for the new turn.
	_candidates.clear()
	_scheduled.clear()
	_events_fired_this_turn = 0
	_current_turn = GameManager.turn_number if GameManager else _current_turn + 1


func submit_candidate(id: String, source: String, priority: int, weight: float, data: Dictionary) -> void:
	## Event systems call this instead of firing directly.
	## id: unique event identifier
	## source: originating system name (e.g. "seasonal_events", "grand_event_director")
	## priority: use PRIORITY_* constants
	## weight: relative weight for weighted random selection (higher = more likely)
	## data: event payload (title, desc, choices, effects, etc.)
	_candidates.append({
		"id": id,
		"source": source,
		"priority": priority,
		"weight": weight,
		"data": data,
	})


func resolve_turn() -> Array:
	## Called AFTER all event systems have submitted candidates.
	## Returns array of selected events to fire this turn.
	if _candidates.is_empty():
		return []

	# Sort by priority descending (critical events first)
	_candidates.sort_custom(func(a, b): return a["priority"] > b["priority"])

	# Critical events always fire (bypass the limit)
	for c in _candidates:
		if c["priority"] >= PRIORITY_CRITICAL:
			_scheduled.append(c)
			_record_fired(c["id"])

	# Weighted random selection for remaining slots
	var remaining_slots: int = MAX_EVENTS_PER_TURN - _scheduled.size()
	var non_critical: Array = _candidates.filter(func(c): return c["priority"] < PRIORITY_CRITICAL)

	# Filter out events that fired too recently (anti-repeat: min 2 turn gap)
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


func request_fire() -> bool:
	## Gate: can another event fire this turn?
	## Legacy event systems that fire directly can call this to check.
	if _events_fired_this_turn >= MAX_EVENTS_PER_TURN:
		return false
	_events_fired_this_turn += 1
	return true


func get_remaining_slots() -> int:
	## How many more events can fire this turn.
	return maxi(0, MAX_EVENTS_PER_TURN - _events_fired_this_turn)


func get_candidates() -> Array:
	## Debug: return current candidate pool.
	return _candidates


func get_scheduled() -> Array:
	## Debug: return events scheduled for this turn.
	return _scheduled


# ═══════════════ INTERNAL ═══════════════

func _weighted_pick(pool: Array) -> Dictionary:
	## Select one item from pool using weighted random.
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


# ═══════════════ HISTORY QUERY ═══════════════

func get_last_fired_turn(event_id: String) -> int:
	## Returns the turn number when event_id last fired, or -1 if never.
	return _event_history.get(event_id, -1)


func get_events_fired_this_turn() -> int:
	return _events_fired_this_turn


# ═══════════════ SAVE / LOAD ═══════════════

func serialize() -> Dictionary:
	return {
		"event_history": _event_history.duplicate(true),
		"current_turn": _current_turn,
	}


func deserialize(data: Dictionary) -> void:
	_event_history = data.get("event_history", {}).duplicate(true)
	_current_turn = int(data.get("current_turn", 0))
	# Fix int keys after JSON round-trip
	var fix_keys: Array = []
	for k in _event_history:
		if _event_history[k] is float:
			_event_history[k] = int(_event_history[k])


## Aliases for SaveManager compatibility
func to_save_data() -> Dictionary:
	return serialize()


func from_save_data(data: Dictionary) -> void:
	deserialize(data)
