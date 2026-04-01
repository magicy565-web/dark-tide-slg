extends Node
## QuestProgressTracker — Unified quest progress coordinator (v1.0)
## Aggregates progress from QuestJournal, QuestManager, StoryEventSystem, and HeroSystem
## into a single status dashboard. Provides a unified tick_all() entry point and
## tracks cross-system milestones.

const FactionData = preload("res://systems/faction/faction_data.gd")
const QuestDefs = preload("res://systems/quest/quest_definitions.gd")

# ═══════════════ SIGNALS ═══════════════

signal quest_updated(quest_id: String, status: String)
signal quest_completed(quest_id: String, rewards: Dictionary)
signal milestone_reached(milestone_name: String)

# ═══════════════ STATE ═══════════════

# Aggregated quest status: quest_id -> {source, type, status, progress, objectives}
var _quest_status: Dictionary = {}

# Milestone tracking: milestone_name -> {reached: bool, turn: int}
var _milestones: Dictionary = {}

# Cross-system dependency rules: quest_id -> [{require_quest: String, require_status: String}]
var _dependencies: Dictionary = {}

# Turn of last sync
var _last_sync_turn: int = -1

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	if EventBus:
		EventBus.turn_started.connect(_on_turn_started)
	_init_dependencies()


func _on_turn_started(player_id: int) -> void:
	var turn: int = GameManager.turn_number if GameManager else 0
	tick_all(player_id, turn)


# ═══════════════ DEPENDENCY DEFINITIONS ═══════════════

func _init_dependencies() -> void:
	## Define cross-system quest dependencies here.
	## Format: quest_id -> Array of {require_quest, require_status}
	## These are checked during _check_milestones and can gate quest unlocks.
	_dependencies = {
		# Example: side_quest_economist requires main_quest_3 completion
		"side_economist": [{"require_quest": "main_3", "require_status": "completed"}],
		# Example: character quest chain requires neutral faction recruited
		"cq_neutral_hero": [{"require_quest": "neutral_recruited_any", "require_status": "completed"}],
	}


# ═══════════════ UNIFIED TICK ═══════════════

func tick_all(player_id: int, turn: int) -> void:
	## Single entry point that coordinates all quest sources each turn.
	## 1. Tick quest journal (main/side/challenge/character)
	if QuestJournal:
		QuestJournal.tick(player_id)

	## 2. Neutral faction quests (QuestManager already ticks via game_manager,
	##    but we sync its state here)

	## 3. Story event progression
	if StoryEventSystem:
		StoryEventSystem.process_story_turn()

	## 4. Sync all quest states into unified _quest_status
	_sync_quest_states(player_id)

	## 5. Check milestones
	_check_milestones(player_id)

	_last_sync_turn = turn


# ═══════════════ STATE SYNCHRONIZATION ═══════════════

func _sync_quest_states(player_id: int) -> void:
	## Pull quest data from all sources and merge into _quest_status.
	var old_status: Dictionary = _quest_status.duplicate(true)
	_quest_status.clear()

	# ── Pull from QuestJournal (main/side/challenge/character) ──
	if QuestJournal:
		_sync_journal_quests(player_id)

	# ── Pull from QuestManager (neutral faction quests) ──
	if QuestManager:
		_sync_neutral_quests(player_id)

	# ── Pull from StoryEventSystem (hero story progression) ──
	if StoryEventSystem:
		_sync_story_quests()

	# ── Pull from HeroSystem (affection-gated CG/VN triggers) ──
	if HeroSystem:
		_sync_hero_affection_quests()

	# ── Emit signals for changed quests ──
	for qid in _quest_status:
		var new_st: String = _quest_status[qid].get("status", "")
		var old_st: String = old_status.get(qid, {}).get("status", "")
		if new_st != old_st:
			quest_updated.emit(qid, new_st)
			if new_st == "completed":
				quest_completed.emit(qid, _quest_status[qid].get("rewards", {}))


func _sync_journal_quests(player_id: int) -> void:
	## Sync all quests from QuestJournal's get_all_quests().
	var all_quests: Array = QuestJournal.get_all_quests(player_id)
	for q in all_quests:
		var qid: String = q.get("id", "")
		if qid == "":
			continue
		var raw_status = q.get("status", -1)
		var status_str: String = _journal_status_to_string(raw_status)
		_quest_status[qid] = {
			"source": "quest_journal",
			"type": q.get("category", "unknown"),
			"status": status_str,
			"name": q.get("name", ""),
			"objectives": q.get("objectives", []),
			"rewards": {},
		}


func _sync_neutral_quests(player_id: int) -> void:
	## Sync neutral faction quest chains from QuestManager.
	var all_nq: Array = QuestManager.get_all_quest_status(player_id)
	for nq in all_nq:
		var faction_id = nq.get("faction_id", -1)
		var qid: String = "neutral_%s" % str(faction_id)
		var step: int = nq.get("step", 0)
		var max_steps: int = nq.get("max_steps", 3)
		var recruited: bool = nq.get("recruited", false)
		var status_str: String = "locked"
		if recruited:
			status_str = "completed"
		elif step > 0:
			status_str = "active"
		_quest_status[qid] = {
			"source": "quest_manager",
			"type": "neutral_faction",
			"status": status_str,
			"name": nq.get("name", ""),
			"progress": {"step": step, "max_steps": max_steps},
			"objectives": [{"label": nq.get("current_task", ""), "done": recruited}],
			"rewards": {},
		}


func _sync_story_quests() -> void:
	## Sync hero story progression from StoryEventSystem.
	for hero_id in StoryEventSystem.story_progress:
		var prog: Dictionary = StoryEventSystem.story_progress[hero_id]
		var route: String = prog.get("route", "")
		var current_idx: int = prog.get("current_event", 0)
		var completed: Array = prog.get("completed_events", [])
		var events: Array = StoryEventSystem.get_route_events(hero_id, route)
		var total: int = events.size()
		var status_str: String = "active"
		if total > 0 and current_idx >= total:
			status_str = "completed"
		elif total == 0:
			status_str = "locked"
		var qid: String = "story_%s_%s" % [hero_id, route]
		_quest_status[qid] = {
			"source": "story_event_system",
			"type": "story",
			"status": status_str,
			"name": "%s (%s)" % [hero_id, route],
			"progress": {"current": current_idx, "total": total, "completed_events": completed},
			"objectives": [],
			"rewards": {},
		}


func _sync_hero_affection_quests() -> void:
	## Track hero affection milestones as quest-like entries.
	for hero_id in HeroSystem.recruited_heroes:
		var aff: int = HeroSystem.hero_affection.get(hero_id, 0)
		var qid: String = "hero_affection_%s" % hero_id
		var status_str: String = "active"
		# Consider "completed" at max affection (10)
		if aff >= 10:
			status_str = "completed"
		_quest_status[qid] = {
			"source": "hero_system",
			"type": "affection",
			"status": status_str,
			"name": "%s Affection" % hero_id,
			"progress": {"affection": aff, "max": 10},
			"objectives": [],
			"rewards": {},
		}


func _journal_status_to_string(status_int: int) -> String:
	## Convert QuestDefs.QuestStatus int to a readable string.
	if not QuestDefs:
		return "unknown"
	match int(status_int):
		QuestDefs.QuestStatus.LOCKED:
			return "locked"
		QuestDefs.QuestStatus.ACTIVE:
			return "active"
		QuestDefs.QuestStatus.COMPLETED:
			return "completed"
		_:
			return "unknown"


# ═══════════════ MILESTONE TRACKING ═══════════════

func _check_milestones(player_id: int) -> void:
	## Check and emit milestones based on aggregated quest state.
	_check_milestone("first_main_quest", func():
		for qid in _quest_status:
			var q: Dictionary = _quest_status[qid]
			if q.get("type") == "main" and q.get("status") == "completed":
				return true
		return false)

	_check_milestone("first_faction_conquered", func():
		if GameManager:
			for p in GameManager.players:
				if p.get("is_ai", false) and p.get("eliminated", false):
					return true
		return false)

	_check_milestone("half_map_controlled", func():
		if GameManager:
			var total: int = GameManager.tiles.size()
			var owned: int = GameManager.count_tiles_owned(player_id)
			return total > 0 and owned >= total / 2
		return false)

	_check_milestone("all_heroes_recruited", func():
		if HeroSystem:
			var total_heroes: int = FactionData.HEROES.size()
			return HeroSystem.recruited_heroes.size() >= total_heroes
		return false)

	_check_milestone("all_neutrals_recruited", func():
		if QuestManager:
			var total: int = FactionData.NEUTRAL_FACTION_DATA.size()
			return QuestManager.get_recruited_factions(player_id).size() >= total
		return false)

	_check_milestone("first_neutral_recruited", func():
		if QuestManager:
			return QuestManager.get_recruited_factions(player_id).size() >= 1
		return false)

	_check_milestone("first_story_complete", func():
		for qid in _quest_status:
			var q: Dictionary = _quest_status[qid]
			if q.get("type") == "story" and q.get("status") == "completed":
				return true
		return false)


func _check_milestone(name: String, condition: Callable) -> void:
	if _milestones.get(name, {}).get("reached", false):
		return
	if condition.call():
		_milestones[name] = {"reached": true, "turn": GameManager.turn_number if GameManager else 0}
		milestone_reached.emit(name)
		if EventBus and EventBus.has_signal("message_log"):
			EventBus.message_log.emit("[color=gold][里程碑] %s[/color]" % name)


# ═══════════════ DEPENDENCY CHECKING ═══════════════

func check_dependency(quest_id: String) -> bool:
	## Returns true if all dependencies for quest_id are satisfied.
	if not _dependencies.has(quest_id):
		return true
	for dep in _dependencies[quest_id]:
		var req_quest: String = dep.get("require_quest", "")
		var req_status: String = dep.get("require_status", "completed")
		var q: Dictionary = _quest_status.get(req_quest, {})
		if q.get("status", "") != req_status:
			return false
	return true


func get_blocking_dependencies(quest_id: String) -> Array:
	## Returns array of unmet dependency quest IDs.
	var blocking: Array = []
	if not _dependencies.has(quest_id):
		return blocking
	for dep in _dependencies[quest_id]:
		var req_quest: String = dep.get("require_quest", "")
		var req_status: String = dep.get("require_status", "completed")
		var q: Dictionary = _quest_status.get(req_quest, {})
		if q.get("status", "") != req_status:
			blocking.append(req_quest)
	return blocking


# ═══════════════ PUBLIC QUERY API ═══════════════

func get_all_quests() -> Dictionary:
	return _quest_status


func get_active_quests() -> Array:
	return _quest_status.values().filter(func(q): return q.get("status") == "active")


func get_completed_quests() -> Array:
	return _quest_status.values().filter(func(q): return q.get("status") == "completed")


func get_quest(id: String) -> Dictionary:
	return _quest_status.get(id, {})


func get_quests_by_source(source: String) -> Array:
	return _quest_status.values().filter(func(q): return q.get("source") == source)


func get_quests_by_type(type: String) -> Array:
	return _quest_status.values().filter(func(q): return q.get("type") == type)


func get_milestones() -> Dictionary:
	return _milestones


func is_milestone_reached(name: String) -> bool:
	return _milestones.get(name, {}).get("reached", false)


func get_completion_summary() -> Dictionary:
	## Returns a summary of overall quest completion.
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
		"total": total,
		"completed": completed,
		"active": active,
		"locked": locked,
		"milestones_reached": _milestones.values().filter(func(m): return m.get("reached", false)).size(),
		"milestones_total": _milestones.size(),
	}


# ═══════════════ SAVE / LOAD ═══════════════

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


## Aliases for SaveManager compatibility
func to_save_data() -> Dictionary:
	return serialize()


func from_save_data(data: Dictionary) -> void:
	deserialize(data)
