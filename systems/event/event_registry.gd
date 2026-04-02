## event_registry.gd — Single source of truth for ALL events in the game.
## Auto-discovers and indexes events from all 9 subsystems at startup.
## Provides cross-system deduplication, cooldown tracking, and weighted selection.
extends Node

# Master index: event_id -> {source, category, data, weight, fired_count, last_fired_turn}
var _registry: Dictionary = {}

# Category indices for fast lookup
var _by_category: Dictionary = {}   # category_name -> [event_ids]
var _by_source: Dictionary = {}     # source_system_name -> [event_ids]

# Cross-system deduplication: tracks which events fired this turn
var _fired_this_turn: Array = []

# Global fired history (persisted across turns, used for non-repeatable events)
var _fired_history: Dictionary = {}  # event_id -> {count: int, last_turn: int}

# Max events that can fire per turn via request_fire()
const MAX_EVENTS_PER_TURN: int = 2

# Event weight/rarity system
const WEIGHT_COMMON: float = 1.0
const WEIGHT_UNCOMMON: float = 0.6
const WEIGHT_RARE: float = 0.3
const WEIGHT_EPIC: float = 0.1
const WEIGHT_LEGENDARY: float = 0.05

# Default cooldown for request_fire coordination (turns)
const DEFAULT_COOLDOWN: int = 3

# Per-event cooldowns managed by this registry
var _cooldowns: Dictionary = {}  # event_id -> turns_remaining

# Default weight per category
const CATEGORY_DEFAULT_WEIGHT: Dictionary = {
	"base": WEIGHT_COMMON,
	"seasonal": WEIGHT_UNCOMMON,
	"crisis": WEIGHT_RARE,
	"destruction_chain": WEIGHT_RARE,
	"character_interaction": WEIGHT_UNCOMMON,
	"grand": WEIGHT_EPIC,
	"dynamic": WEIGHT_UNCOMMON,
	"expanded": WEIGHT_COMMON,
	"chain_v5": WEIGHT_UNCOMMON,
}


func _ready() -> void:
	_auto_discover_all()
	print("[EventRegistry] Indexed %d events from %d sources across %d categories." % [
		_registry.size(), _by_source.size(), _by_category.size()])


# ═══════════════ AUTO-DISCOVERY ═══════════════

func _auto_discover_all() -> void:
	_discover_event_system()
	_discover_seasonal_events()
	_discover_crisis_countdown()
	_discover_faction_destruction_events()
	_discover_character_interaction_events()
	_discover_grand_event_director()
	_discover_dynamic_situation_events()
	_discover_expanded_random_events()
	_discover_extra_events_v5()


func _discover_event_system() -> void:
	if not EventSystem:
		return
	# EventSystem._events may not be populated yet at our _ready if it inits
	# in its own _ready. Use call_deferred to also try later.
	if EventSystem._events.size() > 0:
		_register_source("event_system", EventSystem._events, "base")
	else:
		call_deferred("_deferred_discover_event_system")


func _deferred_discover_event_system() -> void:
	if EventSystem and EventSystem._events.size() > 0:
		_register_source("event_system", EventSystem._events, "base")


func _discover_seasonal_events() -> void:
	if not SeasonalEvents:
		return
	var all_events: Array = []
	for season_key in SeasonalEvents._season_events:
		var season_arr: Array = SeasonalEvents._season_events[season_key]
		for evt in season_arr:
			all_events.append(evt)
	_register_source("seasonal_events", all_events, "seasonal")


func _discover_crisis_countdown() -> void:
	if not CrisisCountdown:
		return
	var crisis_events: Array = []
	for crisis_id in CrisisCountdown.CRISIS_TYPES:
		var ct: Dictionary = CrisisCountdown.CRISIS_TYPES[crisis_id].duplicate()
		ct["id"] = crisis_id
		crisis_events.append(ct)
	_register_source("crisis_countdown", crisis_events, "crisis")


func _discover_faction_destruction_events() -> void:
	if not FactionDestructionEvents:
		return
	var all_events: Array = []
	for faction_key in FactionDestructionEvents._chain_defs:
		var chain: Array = FactionDestructionEvents._chain_defs[faction_key]
		for evt in chain:
			all_events.append(evt)
	_register_source("faction_destruction_events", all_events, "destruction_chain")


func _discover_character_interaction_events() -> void:
	if not CharacterInteractionEvents:
		return
	_register_source("character_interaction_events",
		CharacterInteractionEvents._interactions, "character_interaction")


func _discover_grand_event_director() -> void:
	if not GrandEventDirector:
		return
	_register_source("grand_event_director",
		GrandEventDirector._grand_events, "grand")


func _discover_dynamic_situation_events() -> void:
	if not DynamicSituationEvents:
		return
	_register_source("dynamic_situation_events",
		DynamicSituationEvents._dynamic_events, "dynamic")


func _discover_expanded_random_events() -> void:
	if not ExpandedRandomEvents:
		return
	if ExpandedRandomEvents.has_method("get_expanded_events"):
		var events: Array = ExpandedRandomEvents.get_expanded_events()
		_register_source("expanded_random_events", events, "expanded")


func _discover_extra_events_v5() -> void:
	if not ExtraEventsV5:
		return
	if ExtraEventsV5.has_method("get_events"):
		var events: Array = ExtraEventsV5.get_events()
		_register_source("extra_events_v5", events, "chain_v5")


# ═══════════════ REGISTRATION ═══════════════

## Register a batch of events from a named source.
func _register_source(source_name: String, events: Array, category: String) -> void:
	for evt in events:
		var eid: String = _extract_id(evt, source_name, category)
		var weight: float = CATEGORY_DEFAULT_WEIGHT.get(category, WEIGHT_COMMON)
		register_event(eid, source_name, category, evt, weight)


## Register a single event into the master index.
func register_event(id: String, source: String, category: String, data: Dictionary, weight: float = WEIGHT_COMMON) -> void:
	# Dedup: warn and suffix if id already exists
	var final_id: String = id
	if _registry.has(final_id):
		var suffix: int = 2
		while _registry.has(final_id + "_" + str(suffix)):
			suffix += 1
		final_id = final_id + "_" + str(suffix)
		print("[EventRegistry] WARNING: Duplicate id '%s' from source '%s'. Renamed to '%s'." % [id, source, final_id])

	_registry[final_id] = {
		"source": source,
		"category": category,
		"data": data,
		"weight": weight,
		"fired_count": 0,
		"last_fired_turn": -1,
	}

	# Category index
	if not _by_category.has(category):
		_by_category[category] = []
	_by_category[category].append(final_id)

	# Source index
	if not _by_source.has(source):
		_by_source[source] = []
	_by_source[source].append(final_id)


## Extract or generate an event id from an event dict.
func _extract_id(evt: Dictionary, source: String, _category: String) -> String:
	if evt.has("id") and evt["id"] is String and evt["id"] != "":
		return evt["id"]
	# Generate a deterministic id from source + name or index
	var name_part: String = evt.get("name", "")
	if name_part != "":
		return "%s_%s" % [source, name_part]
	# Fallback: use hash
	return "%s_%d" % [source, evt.hash()]


# ═══════════════ LOOKUP ═══════════════

## Get event entry by id, or empty dict if not found.
func get_event(id: String) -> Dictionary:
	return _registry.get(id, {})


## Get all event ids in a category.
func get_events_by_category(category: String) -> Array:
	return _by_category.get(category, [])


## Get all event ids from a specific source system.
func get_events_by_source(source: String) -> Array:
	return _by_source.get(source, [])


## Get total registered event count.
func get_total_count() -> int:
	return _registry.size()


## Get all registered event ids.
func get_all_ids() -> Array:
	return _registry.keys()


## Return a weighted list of events eligible to fire this turn.
## Filters by repeatable status, cooldowns, and fired history.
func get_available_events(_turn: int, _player_state: Dictionary = {}) -> Array:
	var available: Array = []
	for eid in _registry:
		if not can_fire(eid):
			continue
		var entry: Dictionary = _registry[eid]
		available.append({
			"id": eid,
			"weight": entry["weight"],
			"category": entry["category"],
			"source": entry["source"],
		})
	return available


# ═══════════════ FIRING / HISTORY ═══════════════

## Record that an event was triggered.
func mark_fired(id: String, turn: int) -> void:
	_fired_this_turn.append(id)

	if not _fired_history.has(id):
		_fired_history[id] = {"count": 0, "last_turn": -1}
	_fired_history[id]["count"] += 1
	_fired_history[id]["last_turn"] = turn

	if _registry.has(id):
		_registry[id]["fired_count"] += 1
		_registry[id]["last_fired_turn"] = turn

	# Set cooldown
	_cooldowns[id] = DEFAULT_COOLDOWN


## Check if event ever fired.
func has_fired(id: String) -> bool:
	return _fired_history.has(id)


## Get how many times an event has fired.
func get_fire_count(id: String) -> int:
	if _fired_history.has(id):
		return _fired_history[id]["count"]
	return 0


## Check if an event can currently fire (cooldowns, repeatable flag, etc.)
func can_fire(id: String) -> bool:
	# Cooldown check
	if _cooldowns.has(id) and _cooldowns[id] > 0:
		return false

	# Already fired this turn
	if id in _fired_this_turn:
		return false

	# Non-repeatable check
	var entry: Dictionary = _registry.get(id, {})
	if entry.is_empty():
		return false

	var data: Dictionary = entry.get("data", {})
	var repeatable: bool = data.get("repeatable", true)
	if not repeatable and has_fired(id):
		return false

	return true


# ═══════════════ CROSS-SYSTEM COORDINATION ═══════════════

## Called at the start of each turn to reset per-turn state and tick cooldowns.
func begin_turn() -> void:
	_fired_this_turn.clear()
	# Tick cooldowns
	var expired: Array = []
	for eid in _cooldowns:
		_cooldowns[eid] -= 1
		if _cooldowns[eid] <= 0:
			expired.append(eid)
	for eid in expired:
		_cooldowns.erase(eid)


## Cross-system coordination: request permission to fire an event.
## Returns true if allowed (and automatically marks it as fired).
## Returns false if blocked (max per turn reached, cooldown, etc.)
func request_fire(id: String, _source: String = "") -> bool:
	# Check max events per turn
	if _fired_this_turn.size() >= MAX_EVENTS_PER_TURN:
		return false

	# Check if this event can fire
	if not can_fire(id):
		return false

	# Get current turn
	var turn: int = 0
	if GameManager and "current_turn" in GameManager:
		turn = GameManager.current_turn

	mark_fired(id, turn)
	return true


# ═══════════════ SAVE / LOAD ═══════════════

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

	# Restore counts into registry entries
	for eid in _fired_history:
		if _registry.has(eid):
			_registry[eid]["fired_count"] = _fired_history[eid].get("count", 0)
			_registry[eid]["last_fired_turn"] = _fired_history[eid].get("last_turn", -1)
