## research_manager.gd - Per-faction training system (v0.8.5)
## PLAYER-ONLY: AI factions use AIScaling instead.
## Each evil faction has its own training tree loaded from TrainingData.FACTION_TRAINING_TREE.
extends Node
const TrainingData = preload("res://systems/faction/training_data.gd")

# ── Signals ──
signal research_started(player_id: int, tech_id: String)
signal research_completed(player_id: int, tech_id: String)
signal research_cancelled(player_id: int, tech_id: String)

# ── Per-player research state ──
# Only one player uses this system (the human player).
# { player_id: { "completed": [tech_id, ...], "current": tech_id_or_empty, "progress": int, "queue": [tech_id, ...] } }
var _research_state: Dictionary = {}

# ── Cached research speed ──
var _speed_cache: Dictionary = {}  # { player_id: float }

# ── Active training tree (loaded based on player faction) ──
var _active_tree: Dictionary = {}  # tech_id -> tech_data

# 学院缺失连续回合计数 { player_id: int }
var _academy_missing_turns: Dictionary = {}
# 学院缺失超过此回合数后自动取消研究并退还50%资源
const ACADEMY_MISSING_CANCEL_TURNS: int = 3


func _ready() -> void:
	pass


# ── Initialization ──
func init_player(player_id: int) -> void:
	_research_state[player_id] = {
		"completed": [],
		"current": "",
		"progress": 0,
		"queue": [],
	}
	_speed_cache[player_id] = TrainingData.RESEARCH_BASE_SPEED
	# Load the training tree for the player's faction
	var faction_id: int = GameManager.get_player_faction(player_id)
	_load_faction_tree(faction_id)


func _load_faction_tree(faction_id: int) -> void:
	## Load the per-faction training tree. Only one tree is active at a time.
	_active_tree.clear()
	if TrainingData.FACTION_TRAINING_TREE.has(faction_id):
		_active_tree = TrainingData.FACTION_TRAINING_TREE[faction_id]
		var count: int = _active_tree.size()
		EventBus.message_log.emit("已加载势力训练树 (%d 项科技)" % count)
	else:
		push_warning("ResearchManager: No training tree found for faction %d" % faction_id)


# ── Queries ──
func get_completed_techs(player_id: int) -> Array:
	if not _research_state.has(player_id):
		return []
	return _research_state[player_id]["completed"]


func has_tech(player_id: int, tech_id: String) -> bool:
	return tech_id in get_completed_techs(player_id)


func is_completed(player_id: int, tech_id: String) -> bool:
	## Alias for has_tech() — used by game_manager army cap check.
	return has_tech(player_id, tech_id)


func get_current_research(player_id: int) -> String:
	if not _research_state.has(player_id):
		return ""
	return _research_state[player_id]["current"]


func get_research_progress(player_id: int) -> int:
	if not _research_state.has(player_id):
		return 0
	return _research_state[player_id]["progress"]


func get_research_queue(player_id: int) -> Array:
	if not _research_state.has(player_id):
		return []
	return _research_state[player_id]["queue"]


func get_research_speed(player_id: int) -> float:
	return _speed_cache.get(player_id, TrainingData.RESEARCH_BASE_SPEED)


# ── Tech Data Lookup ──
func get_tech_data(tech_id: String) -> Dictionary:
	## Look up tech in the active faction training tree only.
	if _active_tree.has(tech_id):
		return _active_tree[tech_id]
	return {}


func get_tech_name(tech_id: String) -> String:
	var data: Dictionary = get_tech_data(tech_id)
	return data.get("name", tech_id)


func get_tech_cost(tech_id: String) -> Dictionary:
	var data: Dictionary = get_tech_data(tech_id)
	return data.get("cost", {})


func get_tech_turns(tech_id: String) -> int:
	var data: Dictionary = get_tech_data(tech_id)
	return data.get("turns", 1)


# ── Available Techs ──
func get_available_techs(player_id: int) -> Array:
	## Returns all techs the player can start researching.
	## Only searches the player's faction training tree.
	var result: Array = []
	if not _research_state.has(player_id):
		return result
	if not _has_academy(player_id):
		return result

	var completed: Array = _research_state[player_id]["completed"]
	var current: String = _research_state[player_id]["current"]
	var queue: Array = _research_state[player_id]["queue"]

	for tech_id in _active_tree:
		if tech_id in completed or tech_id == current or tech_id in queue:
			continue
		if _prereqs_met(player_id, tech_id):
			var data: Dictionary = _active_tree[tech_id]
			var can_afford: bool = _can_afford_tech(player_id, data.get("cost", {}))
			result.append({
				"id": tech_id,
				"name": data["name"],
				"branch": data["branch"],
				"tier": data["tier"],
				"cost": data.get("cost", {}),
				"turns": data.get("turns", 1),
				"desc": data.get("desc", ""),
				"can_afford": can_afford,
			})

	return result


# ── Start / Cancel / Queue ──
func start_research(player_id: int, tech_id: String) -> bool:
	if not _research_state.has(player_id):
		return false
	if not _has_academy(player_id):
		EventBus.message_log.emit("需要建造学院才能开始研究!")
		return false
	var data: Dictionary = get_tech_data(tech_id)
	if data.is_empty():
		return false
	if not _prereqs_met(player_id, tech_id):
		EventBus.message_log.emit("前置科技未完成!")
		return false
	var cost: Dictionary = data.get("cost", {})
	if not _can_afford_tech(player_id, cost):
		EventBus.message_log.emit("资源不足!")
		return false

	var state: Dictionary = _research_state[player_id]
	if state["current"] == "":
		# Deduct cost only after confirming we can set it as current
		_deduct_tech_cost(player_id, cost)
		state["current"] = tech_id
		state["progress"] = 0
		research_started.emit(player_id, tech_id)
		EventBus.message_log.emit("开始研究: %s" % data.get("name", tech_id))
	else:
		# Deduct cost only after confirming we can queue it
		_deduct_tech_cost(player_id, cost)
		# Queue it
		state["queue"].append(tech_id)
		EventBus.message_log.emit("已加入研究队列: %s" % data.get("name", tech_id))
	return true


func cancel_research(player_id: int) -> void:
	if not _research_state.has(player_id):
		return
	var state: Dictionary = _research_state[player_id]
	var tech_id: String = state["current"]
	if tech_id == "":
		return
	# Refund 50% of cost
	var data: Dictionary = get_tech_data(tech_id)
	var cost: Dictionary = data.get("cost", {})
	var refund: Dictionary = {}
	for key in cost:
		refund[key] = int(cost[key] * 0.5)
	_refund_tech_cost(player_id, refund)
	state["current"] = ""
	state["progress"] = 0
	research_cancelled.emit(player_id, tech_id)
	EventBus.message_log.emit("取消研究: %s (退还50%%资源)" % data.get("name", tech_id))
	# Start next in queue
	_advance_queue(player_id)


# ── Turn Processing ──
func process_turn(player_id: int) -> void:
	## Called once per turn for the PLAYER ONLY. AI does not use this.
	if not _research_state.has(player_id):
		return
	var state: Dictionary = _research_state[player_id]
	var tech_id: String = state["current"]
	if tech_id == "":
		return
	if not _has_academy(player_id):
		# 学院缺失计数递增
		_academy_missing_turns[player_id] = _academy_missing_turns.get(player_id, 0) + 1
		var missing: int = _academy_missing_turns[player_id]
		if missing >= ACADEMY_MISSING_CANCEL_TURNS:
			# 连续缺失3回合，自动取消研究并退还50%资源
			var data: Dictionary = get_tech_data(tech_id)
			var cost: Dictionary = data.get("cost", {})
			var refund: Dictionary = {}
			for key in cost:
				refund[key] = int(cost[key] * 0.5)
			_refund_tech_cost(player_id, refund)
			state["current"] = ""
			state["progress"] = 0
			_academy_missing_turns[player_id] = 0
			research_cancelled.emit(player_id, tech_id)
			EventBus.message_log.emit("[color=red]学院连续缺失%d回合! 自动取消研究: %s (退还50%%资源)[/color]" % [ACADEMY_MISSING_CANCEL_TURNS, data.get("name", tech_id)])
			_advance_queue(player_id)
		else:
			EventBus.message_log.emit("无学院! 研究暂停。(连续%d回合)" % missing)
		return

	# 学院存在时重置缺失计数
	_academy_missing_turns[player_id] = 0

	var speed: float = get_research_speed(player_id)
	state["progress"] += int(speed)

	var data: Dictionary = get_tech_data(tech_id)
	var required: int = data.get("turns", 1)

	if state["progress"] >= required:
		_complete_research(player_id, tech_id)


# ── Research Speed Update ──
func update_research_speed(player_id: int) -> void:
	## Recalculate research speed from buildings and effects.
	var speed: float = TrainingData.RESEARCH_BASE_SPEED
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) != player_id:
			continue
		var bld: String = tile.get("building_id", "")
		var bld_level: int = tile.get("building_level", 1)
		if bld == "academy":
			speed += _academy_speed_bonus(bld_level)
		elif bld == "war_college":
			speed += _war_college_speed_bonus(bld_level)
		elif bld == "arcane_institute":
			speed += _arcane_institute_speed_bonus(bld_level)
	_speed_cache[player_id] = speed


# ── Internal Helpers ──
func _complete_research(player_id: int, tech_id: String) -> void:
	var state: Dictionary = _research_state[player_id]
	state["completed"].append(tech_id)
	state["current"] = ""
	state["progress"] = 0
	var data: Dictionary = get_tech_data(tech_id)
	_apply_tech_effects(player_id, data.get("effects", {}))
	research_completed.emit(player_id, tech_id)
	EventBus.message_log.emit("研究完成: %s!" % data.get("name", tech_id))
	_advance_queue(player_id)


func _advance_queue(player_id: int) -> void:
	var state: Dictionary = _research_state[player_id]
	if state["queue"].size() > 0:
		var next_id: String = state["queue"].pop_front()
		state["current"] = next_id
		state["progress"] = 0
		var data: Dictionary = get_tech_data(next_id)
		research_started.emit(player_id, next_id)
		EventBus.message_log.emit("自动开始研究: %s" % data.get("name", next_id))


func _has_academy(player_id: int) -> bool:
	## Check if player owns at least one tile with academy/war_college/arcane_institute.
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) != player_id:
			continue
		var bld: String = tile.get("building_id", "")
		if bld in ["academy", "war_college", "arcane_institute"]:
			return true
	return false


func _prereqs_met(player_id: int, tech_id: String) -> bool:
	var data: Dictionary = get_tech_data(tech_id)
	var prereqs: Array = data.get("prereqs", [])
	var completed: Array = get_completed_techs(player_id)
	for p in prereqs:
		if not p in completed:
			return false
	return true


# ── Strategic resource short-key → full ResourceManager key mapping ──
const _STRATEGIC_KEY_MAP: Dictionary = {
	"crystal": "magic_crystal",
	"horse": "war_horse",
	"shadow": "shadow_essence",
	"gunpowder": "gunpowder",
}

func _can_afford_tech(player_id: int, cost: Dictionary) -> bool:
	for key in cost:
		var res_key: String = _STRATEGIC_KEY_MAP.get(key, key)
		if ResourceManager.get_resource(player_id, res_key) < cost[key]:
			return false
	return true


func _deduct_tech_cost(player_id: int, cost: Dictionary) -> void:
	var delta: Dictionary = {}
	for key in cost:
		var res_key: String = _STRATEGIC_KEY_MAP.get(key, key)
		delta[res_key] = -cost[key]
	if not delta.is_empty():
		ResourceManager.apply_delta(player_id, delta)


func _refund_tech_cost(player_id: int, refund: Dictionary) -> void:
	var delta: Dictionary = {}
	for key in refund:
		var res_key: String = _STRATEGIC_KEY_MAP.get(key, key)
		delta[res_key] = refund[key]
	if not delta.is_empty():
		ResourceManager.apply_delta(player_id, delta)


func _apply_tech_effects(player_id: int, effects: Dictionary) -> void:
	## Apply permanent training effects from completed tech.
	## Three core categories + secondary passive slot + misc effects.

	if effects.has("unit_buff"):
		var buff: Dictionary = effects["unit_buff"]
		var types: Array = buff.get("types", [])
		for unit_type in types:
			for stat in ["atk", "def", "hp", "spd", "int", "mana_cap", "range"]:
				if buff.has(stat):
					var buff_key: String = "train_%s_%s" % [unit_type, stat]
					BuffManager.add_buff(player_id, buff_key, buff[stat])

	if effects.has("unit_passive"):
		var passive: Dictionary = effects["unit_passive"]
		var unit_type: String = passive.get("type", "")
		var passive_id: String = passive.get("id", "")
		if unit_type != "" and passive_id != "":
			var key: String = "passive_%s_%s" % [unit_type, passive_id]
			BuffManager.add_buff(player_id, key, passive)
			EventBus.message_log.emit("[进阶训练] %s 解锁被动: %s" % [unit_type, passive_id])

	# Support secondary passive (unit_passive_2) for dual-passive techs
	if effects.has("unit_passive_2"):
		var passive2: Dictionary = effects["unit_passive_2"]
		var unit_type2: String = passive2.get("type", "")
		var passive_id2: String = passive2.get("id", "")
		if unit_type2 != "" and passive_id2 != "":
			var key2: String = "passive_%s_%s" % [unit_type2, passive_id2]
			BuffManager.add_buff(player_id, key2, passive2)
			EventBus.message_log.emit("[进阶训练] %s 解锁被动: %s" % [unit_type2, passive_id2])

	if effects.has("unit_active"):
		var active: Dictionary = effects["unit_active"]
		var unit_type: String = active.get("type", "")
		var active_id: String = active.get("id", "")
		if unit_type != "" and active_id != "":
			var key: String = "active_%s_%s" % [unit_type, active_id]
			BuffManager.add_buff(player_id, key, active)
			EventBus.message_log.emit("[终极训练] %s 解锁主动技能: %s" % [unit_type, active_id])

	# Handle unit unlock (e.g. shadow_walker for Dark Elf)
	if effects.has("unlock_unit"):
		var unit_id: String = effects["unlock_unit"]
		BuffManager.add_buff(player_id, "unit_unlock_%s" % unit_id, true)
		EventBus.message_log.emit("[训练] 解锁新单位: %s" % unit_id)

	# Handle misc effects (food_consume_reduction, coastal_atk_bonus, etc.)
	for key in effects:
		if key in ["unit_buff", "unit_passive", "unit_passive_2", "unit_active", "unlock_unit"]:
			continue
		BuffManager.add_buff(player_id, "tech_%s" % key, effects[key])

	EventBus.tech_effects_applied.emit(player_id)


## ── Query helpers for combat system integration ──

func get_unit_stat_bonus(player_id: int, unit_type: String, stat: String) -> int:
	## Returns total trained stat bonus for a unit type. Used by combat resolver.
	var key: String = "train_%s_%s" % [unit_type, stat]
	return int(BuffManager.get_buff_value(player_id, key, 0))


func get_unit_stat_bonuses(player_id: int, unit_type: String) -> Dictionary:
	## Batch lookup: returns {"atk":X, "def":X, "hp":X} in one call.
	return {
		"atk": int(BuffManager.get_buff_value(player_id, "train_%s_atk" % unit_type, 0)),
		"def": int(BuffManager.get_buff_value(player_id, "train_%s_def" % unit_type, 0)),
		"hp": int(BuffManager.get_buff_value(player_id, "train_%s_hp" % unit_type, 0)),
	}


func has_passive(player_id: int, unit_type: String, passive_id: String) -> bool:
	var key: String = "passive_%s_%s" % [unit_type, passive_id]
	return BuffManager.has_buff(player_id, key)


func get_passive_data(player_id: int, unit_type: String, passive_id: String) -> Dictionary:
	var key: String = "passive_%s_%s" % [unit_type, passive_id]
	var val = BuffManager.get_buff_value(player_id, key, {})
	if val is Dictionary:
		return val
	return {}


func has_active_skill(player_id: int, unit_type: String, skill_id: String) -> bool:
	var key: String = "active_%s_%s" % [unit_type, skill_id]
	return BuffManager.has_buff(player_id, key)


func get_active_skill_data(player_id: int, unit_type: String, skill_id: String) -> Dictionary:
	var key: String = "active_%s_%s" % [unit_type, skill_id]
	var val = BuffManager.get_buff_value(player_id, key, {})
	if val is Dictionary:
		return val
	return {}


func has_unit_unlocked(player_id: int, unit_id: String) -> bool:
	## Check if a unit type has been unlocked via training (e.g. shadow_walker).
	return BuffManager.has_buff(player_id, "unit_unlock_%s" % unit_id)


func get_all_unlocked_passives(player_id: int) -> Array:
	var result: Array = []
	for tech_id in get_completed_techs(player_id):
		var data: Dictionary = get_tech_data(tech_id)
		var effects: Dictionary = data.get("effects", {})
		if effects.has("unit_passive"):
			result.append(effects["unit_passive"])
		if effects.has("unit_passive_2"):
			result.append(effects["unit_passive_2"])
	return result


func get_all_unlocked_actives(player_id: int) -> Array:
	var result: Array = []
	for tech_id in get_completed_techs(player_id):
		var data: Dictionary = get_tech_data(tech_id)
		var effects: Dictionary = data.get("effects", {})
		if effects.has("unit_active"):
			result.append(effects["unit_active"])
	return result


func _academy_speed_bonus(level: int) -> float:
	match level:
		1: return 0.25
		2: return 0.50
		3: return 1.0
	return 0.25


func _war_college_speed_bonus(level: int) -> float:
	match level:
		1: return 0.15
		2: return 0.30
		3: return 0.50
	return 0.15


func _arcane_institute_speed_bonus(level: int) -> float:
	match level:
		1: return 0.15
		2: return 0.30
		3: return 0.50
	return 0.15


# ── Save / Load ──
func to_save_data() -> Dictionary:
	return {
		"research_state": _research_state.duplicate(true),
		"speed_cache": _speed_cache.duplicate(),
		"academy_missing_turns": _academy_missing_turns.duplicate(),
	}


func from_save_data(data: Dictionary) -> void:
	_research_state = data.get("research_state", {})
	_speed_cache = data.get("speed_cache", {})
	_academy_missing_turns = data.get("academy_missing_turns", {})
	# Reload active tree from each player's faction
	for pid in _research_state:
		var faction_id: int = GameManager.get_player_faction(pid)
		_load_faction_tree(faction_id)
