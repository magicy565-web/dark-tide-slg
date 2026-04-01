## espionage_system.gd - Espionage & Intelligence Network system
## Information is a resource, deception is a weapon.
extends Node

# ── Operation type enum ──
enum OpType {
	SCOUT,
	SABOTAGE,
	ASSASSINATE,
	STEAL_TECH,
	INCITE_REVOLT,
	SPREAD_RUMORS,
	INTERCEPT_ORDERS,
	PLANT_EVIDENCE,
}

# ── Operation definitions: gold, intel, success%, cooldown, description ──
const OPERATION_DEFS: Dictionary = {
	OpType.SCOUT:             { "gold": 5,  "intel": 10, "success": 90, "cooldown": 1, "name": "侦察" },
	OpType.SABOTAGE:          { "gold": 15, "intel": 25, "success": 60, "cooldown": 3, "name": "破坏" },
	OpType.ASSASSINATE:       { "gold": 25, "intel": 40, "success": 40, "cooldown": 5, "name": "暗杀" },
	OpType.STEAL_TECH:        { "gold": 25, "intel": 30, "success": 50, "cooldown": 4, "name": "窃取科技" },
	OpType.INCITE_REVOLT:     { "gold": 30, "intel": 35, "success": 45, "cooldown": 6, "name": "煽动叛乱" },
	OpType.SPREAD_RUMORS:     { "gold": 10, "intel": 15, "success": 75, "cooldown": 2, "name": "散布谣言" },
	OpType.INTERCEPT_ORDERS:  { "gold": 15, "intel": 20, "success": 65, "cooldown": 2, "name": "截获命令" },
	OpType.PLANT_EVIDENCE:    { "gold": 20, "intel": 35, "success": 55, "cooldown": 4, "name": "栽赃嫁祸" },
}

# ── Constants ──
const INTEL_MAX_BASE: int = 100
const INTEL_DECAY_DEFAULT: int = 3
const INTEL_DECAY_SHADOW: int = 2
const INTEL_COST_PER_POINT: int = 10
const COUNTER_INTEL_MAX: int = 100
const COUNTER_INTEL_CAPTURE_THRESHOLD: int = 30
const COUNTER_INTEL_CAPTURE_BONUS: int = 10
const INTERROGATION_COST: int = 5
const INTERROGATION_SUCCESS_CHANCE: int = 50
const SPY_MASTER_INTEL_BONUS: int = 10
const SPY_MASTER_SUCCESS_BONUS: int = 10
const SCOUT_REVEAL_DURATION: int = 3
const COUNTER_INTEL_COST_PER_POINT: int = 15
const COUNTER_INTEL_INVEST_MAX: int = 50
const SCOUT_SYNERGY_BONUS: int = 15
const SCOUT_SYNERGY_WINDOW: int = 3
const BLOWN_COVER_FAIL_THRESHOLD: int = 3
const BLOWN_COVER_INTEL_LOSS: int = 20
const BLOWN_COVER_CI_GAIN: int = 10

# ── Per-player state ──
# { player_id: int_value }
var _intel: Dictionary = {}
var _counter_intel: Dictionary = {}
# { player_id: { OpType: turns_remaining } }
var _cooldowns: Dictionary = {}
# { player_id: [ { "tile": int, "turns_left": int } ] }
var _revealed_tiles: Dictionary = {}
# { player_id: [ { "target_id": int, "turns_left": int, "moves": Array } ] }
var _intercepted_orders: Dictionary = {}
# { player_id: [ { "tile": int, "turns_left": int, "production_penalty": float } ] }
var _sabotaged_tiles: Dictionary = {}
# { player_id: [ { "hero_id": String, "turns_left": int, "atk_penalty": int, "def_penalty": int } ] }
var _wounded_heroes: Dictionary = {}
# { player_id: { target_id: int -> consecutive_failures: int } }
var _consecutive_failures: Dictionary = {}
# { player_id: [ { "tile": int, "turn": int } ] }  — records successful scout ops for synergy
var _scout_history: Dictionary = {}

# ═══════════════ INIT / RESET ═══════════════

func _ready() -> void:
	pass


func reset() -> void:
	_intel.clear()
	_counter_intel.clear()
	_cooldowns.clear()
	_revealed_tiles.clear()
	_intercepted_orders.clear()
	_sabotaged_tiles.clear()
	_wounded_heroes.clear()
	_consecutive_failures.clear()
	_scout_history.clear()


func init_player(player_id: int) -> void:
	_intel[player_id] = 0
	_counter_intel[player_id] = 0
	_cooldowns[player_id] = {}
	_revealed_tiles[player_id] = []
	_intercepted_orders[player_id] = []
	_sabotaged_tiles[player_id] = []
	_wounded_heroes[player_id] = []
	_consecutive_failures[player_id] = {}
	_scout_history[player_id] = []


# ═══════════════ INTEL GETTERS / SETTERS ═══════════════

func get_intel(player_id: int) -> int:
	return _intel.get(player_id, 0)


func get_counter_intel(player_id: int) -> int:
	return _counter_intel.get(player_id, 0)


func _set_intel(player_id: int, value: int) -> void:
	var max_intel: int = _get_max_intel(player_id)
	_intel[player_id] = clampi(value, 0, max_intel)
	EventBus.intel_changed.emit(player_id, _intel[player_id])


func set_counter_intel(player_id: int, value: int) -> void:
	_counter_intel[player_id] = clampi(value, 0, COUNTER_INTEL_MAX)


# ═══════════════ INVEST IN INTEL ═══════════════

func invest_in_intel(player_id: int, gold_amount: int) -> int:
	## Spend gold to increase intel. Returns new intel level.
	if gold_amount <= 0:
		return get_intel(player_id)
	var affordable: int = mini(gold_amount, ResourceManager.get_resource(player_id, "gold"))
	if affordable < INTEL_COST_PER_POINT:
		return get_intel(player_id)
	var points: int = affordable / INTEL_COST_PER_POINT
	var max_intel: int = _get_max_intel(player_id)
	var current: int = get_intel(player_id)
	var room: int = maxi(0, max_intel - current)
	points = mini(points, room)
	if points <= 0:
		return current
	var actual_cost: int = points * INTEL_COST_PER_POINT
	if not ResourceManager.spend(player_id, {"gold": actual_cost}):
		return current  # BUG FIX: check spend() return value
	_set_intel(player_id, current + points)
	EventBus.message_log.emit("[谍报] 投资%d金, 情报+%d (当前%d/%d)" % [
		actual_cost, points, get_intel(player_id), max_intel])
	return get_intel(player_id)


func invest_in_counter_intel(player_id: int, gold_amount: int) -> int:
	## Spend gold to increase counter-intel at 15 gold per point (max 50).
	if gold_amount <= 0:
		return get_counter_intel(player_id)
	var affordable: int = mini(gold_amount, ResourceManager.get_resource(player_id, "gold"))
	if affordable < COUNTER_INTEL_COST_PER_POINT:
		return get_counter_intel(player_id)
	var points: int = affordable / COUNTER_INTEL_COST_PER_POINT
	var current: int = get_counter_intel(player_id)
	var room: int = maxi(0, COUNTER_INTEL_INVEST_MAX - current)
	points = mini(points, room)
	if points <= 0:
		return current
	var actual_cost: int = points * COUNTER_INTEL_COST_PER_POINT
	# BUG FIX R7: check spend() return value like invest_in_intel does
	if not ResourceManager.spend(player_id, {"gold": actual_cost}):
		return current
	set_counter_intel(player_id, current + points)
	EventBus.message_log.emit("[反谍] 投资%d金, 反情报+%d (当前%d/%d)" % [
		actual_cost, points, get_counter_intel(player_id), COUNTER_INTEL_INVEST_MAX])
	return get_counter_intel(player_id)


# ═══════════════ EXECUTE OPERATION ═══════════════

func execute_operation(player_id: int, operation_type: int, target) -> Dictionary:
	## Execute a spy operation. target is faction_id (int) or tile_index (int) depending on op.
	## Returns { "success": bool, "message": String, "details": Dictionary }
	var result: Dictionary = {"success": false, "message": "", "details": {}}
	if not OPERATION_DEFS.has(operation_type):
		result["message"] = "未知的间谍行动"
		return result
	var op_def: Dictionary = OPERATION_DEFS[operation_type]

	# Check cooldown
	var cd: int = _get_cooldown(player_id, operation_type)
	if cd > 0:
		result["message"] = "%s 冷却中 (%d回合)" % [op_def["name"], cd]
		return result

	# Check gold
	if not ResourceManager.can_afford(player_id, {"gold": op_def["gold"]}):
		result["message"] = "金币不足 (需要%d)" % op_def["gold"]
		return result

	# Check intel
	if get_intel(player_id) < op_def["intel"]:
		result["message"] = "情报不足 (需要%d, 当前%d)" % [op_def["intel"], get_intel(player_id)]
		return result

	# Deduct costs
	ResourceManager.spend(player_id, {"gold": op_def["gold"]})
	_set_intel(player_id, get_intel(player_id) - op_def["intel"])

	# Set cooldown
	_set_cooldown(player_id, operation_type, op_def["cooldown"])

	# Calculate success chance (base + spy_master bonus - target counter_intel)
	var success_chance: int = op_def["success"]
	success_chance += _get_spy_master_bonus(player_id)
	if target is int and target >= 0:
		# BUG FIX: for tile-targeted ops, look up tile owner for counter-intel
		var target_pid: int = target
		if operation_type in [OpType.SCOUT, OpType.SABOTAGE, OpType.INCITE_REVOLT]:
			if target < GameManager.tiles.size() and GameManager.tiles[target] != null:
				target_pid = GameManager.tiles[target].get("owner_id", -1)
		if target_pid >= 0:
			var target_counter: int = get_counter_intel(target_pid)
			@warning_ignore("integer_division")
			success_chance -= target_counter / 2

	# Scout synergy: if SABOTAGE or INCITE_REVOLT on a tile scouted within last 3 turns
	if operation_type in [OpType.SABOTAGE, OpType.INCITE_REVOLT] and target is int:
		if _has_scout_synergy(player_id, target):
			success_chance += SCOUT_SYNERGY_BONUS

	success_chance = clampi(success_chance, 5, 99)

	var roll: int = randi() % 100
	var succeeded: bool = roll < success_chance

	# Apply operation effect
	match operation_type:
		OpType.SCOUT:
			result = _handle_scout(player_id, target, succeeded)
		OpType.SABOTAGE:
			result = _handle_sabotage(player_id, target, succeeded)
		OpType.ASSASSINATE:
			result = _handle_assassinate(player_id, target, succeeded, roll, success_chance)
		OpType.STEAL_TECH:
			result = _handle_steal_tech(player_id, target, succeeded)
		OpType.INCITE_REVOLT:
			result = _handle_incite_revolt(player_id, target, succeeded)
		OpType.SPREAD_RUMORS:
			result = _handle_spread_rumors(player_id, target, succeeded)
		OpType.INTERCEPT_ORDERS:
			result = _handle_intercept_orders(player_id, target, succeeded)
		OpType.PLANT_EVIDENCE:
			result = _handle_plant_evidence(player_id, target, succeeded)

	# Counter-intelligence: if failed, target may capture spy
	if not result["success"] and target is int:
		_check_counter_intel_capture(player_id, target, op_def["name"])

	# Track scout history for synergy
	if operation_type == OpType.SCOUT and result["success"] and target is int:
		_record_scout(player_id, target)

	# Blown cover: track consecutive failures per target
	if target is int:
		_track_consecutive_failure(player_id, target, result["success"])

	EventBus.spy_operation_result.emit(player_id, operation_type, result["success"], result["details"])
	EventBus.message_log.emit("[谍报] %s" % result["message"])
	return result


# ═══════════════ OPERATION HANDLERS ═══════════════

func _handle_scout(player_id: int, tile_idx: int, succeeded: bool) -> Dictionary:
	if succeeded:
		_add_revealed_tile(player_id, tile_idx, SCOUT_REVEAL_DURATION)
		if EventBus.has_signal("intel_tile_scouted"):
			EventBus.intel_tile_scouted.emit(player_id, tile_idx, 3)
		return {"success": true, "message": "侦察成功! 目标格#%d军情已揭露 (持续%d回合)" % [tile_idx, SCOUT_REVEAL_DURATION],
			"details": {"tile": tile_idx, "duration": SCOUT_REVEAL_DURATION}}
	return {"success": false, "message": "侦察失败! 间谍未能接近目标", "details": {}}


func _handle_sabotage(player_id: int, tile_idx: int, succeeded: bool) -> Dictionary:
	if succeeded:
		_sabotaged_tiles[player_id].append({"tile": tile_idx, "turns_left": 2, "production_penalty": 0.20})
		if EventBus.has_signal("intel_tile_sabotaged"):
			EventBus.intel_tile_sabotaged.emit(player_id, tile_idx, 2)
		return {"success": true, "message": "破坏成功! 目标格#%d建筑瘫痪2回合, 产出-20%%" % tile_idx,
			"details": {"tile": tile_idx, "disabled_turns": 2, "production_penalty": 0.20}}
	return {"success": false, "message": "破坏行动失败! 间谍被发现", "details": {}}


func _handle_assassinate(player_id: int, target_faction: int, succeeded: bool, roll: int, threshold: int) -> Dictionary:
	if not succeeded:
		return {"success": false, "message": "暗杀行动失败! 目标警觉逃脱", "details": {"outcome": "fail"}}
	# Within success range: 25% kill, 50% wound, 25% fail (relative to success threshold)
	# Remap: roll is 0..threshold-1. Split into sub-outcomes.
	var sub_roll: int = randi() % 100
	if sub_roll < 25:
		# Kill
		return {"success": true, "message": "暗杀成功! 目标英雄已被击杀",
			"details": {"outcome": "kill", "target_faction": target_faction}}
	elif sub_roll < 75:
		# Wound: ATK/DEF -3 for 5 turns
		if EventBus.has_signal("intel_hero_wounded"):
			EventBus.intel_hero_wounded.emit(player_id, target_faction, 5)
		return {"success": true, "message": "暗杀部分成功! 目标英雄负伤 (ATK/DEF-3, 5回合)",
			"details": {"outcome": "wound", "target_faction": target_faction, "atk_penalty": 3, "def_penalty": 3, "duration": 5}}
	else:
		# Fail within success — treated as near miss
		return {"success": false, "message": "暗杀失败! 刺客险些得手但被击退", "details": {"outcome": "near_miss"}}


func _handle_steal_tech(player_id: int, target_faction: int, succeeded: bool) -> Dictionary:
	if succeeded:
		return {"success": true, "message": "窃取科技成功! 从目标阵营获得一项随机科技",
			"details": {"target_faction": target_faction, "tech_stolen": true}}
	return {"success": false, "message": "窃取科技失败! 对方反间谍阻止了渗透", "details": {}}


func _handle_incite_revolt(player_id: int, tile_idx: int, succeeded: bool) -> Dictionary:
	if succeeded:
		var garrison_revolted: bool = (randi() % 100) < 30
		var details: Dictionary = {"tile": tile_idx, "order_loss": 40, "garrison_revolted": garrison_revolted}
		var msg: String = "煽动叛乱成功! 目标格#%d 民心-40" % tile_idx
		if garrison_revolted:
			msg += ", 守军哗变(减半)!"
			details["garrison_halved"] = true
		return {"success": true, "message": msg, "details": details}
	return {"success": false, "message": "煽动叛乱失败! 当地民众未被煽动", "details": {}}


func _handle_spread_rumors(player_id: int, target_faction: int, succeeded: bool) -> Dictionary:
	if succeeded:
		return {"success": true, "message": "散布谣言成功! 目标阵营英雄好感-2, 外交声望-10",
			"details": {"target_faction": target_faction, "affection_loss": 2, "reputation_loss": 10}}
	return {"success": false, "message": "散布谣言失败! 谣言未能传播", "details": {}}


func _handle_intercept_orders(player_id: int, target_faction: int, succeeded: bool) -> Dictionary:
	if succeeded:
		_intercepted_orders[player_id].append({"target_id": target_faction, "turns_left": 1, "moves": []})
		if EventBus.has_signal("intel_orders_intercepted"):
			var orders_array: Array = []
			EventBus.intel_orders_intercepted.emit(player_id, target_faction, orders_array)
		return {"success": true, "message": "截获命令成功! 下回合可查看目标阵营行动计划",
			"details": {"target_faction": target_faction, "duration": 1}}
	return {"success": false, "message": "截获命令失败! 信使未被拦截", "details": {}}


func _handle_plant_evidence(player_id: int, target_faction: int, succeeded: bool) -> Dictionary:
	if succeeded:
		# target_faction is the faction being framed; third party is determined by caller or random
		return {"success": true, "message": "栽赃嫁祸成功! 目标阵营与第三方外交-15",
			"details": {"target_faction": target_faction, "diplomacy_loss": 15}}
	return {"success": false, "message": "栽赃嫁祸失败! 伪证被识破", "details": {}}


# ═══════════════ COUNTER-INTELLIGENCE ═══════════════

func _check_counter_intel_capture(attacker_id: int, target_id: int, op_name: String) -> void:
	## When an operation fails, check if the target captures the spy.
	# BUG FIX R7: target_id may be a tile_index for tile-targeted ops;
	# resolve to the tile owner so we check/award counter-intel to the correct player.
	var defender_pid: int = target_id
	if target_id >= 0 and target_id < GameManager.tiles.size():
		# BUG FIX R13: null check on tile before .get()
		if GameManager.tiles[target_id] != null:
			var tile_owner: int = GameManager.tiles[target_id].get("owner_id", -1)
			if tile_owner >= 0:
				defender_pid = tile_owner
	var target_ci: int = get_counter_intel(defender_pid)
	if target_ci > COUNTER_INTEL_CAPTURE_THRESHOLD:
		# Spy captured
		_set_intel(defender_pid, get_intel(defender_pid) + COUNTER_INTEL_CAPTURE_BONUS)
		EventBus.spy_captured.emit(attacker_id, defender_pid)
		EventBus.message_log.emit("[反谍] %s行动失败, 间谍被俘! 对方情报+%d" % [
			op_name, COUNTER_INTEL_CAPTURE_BONUS])


func interrogate_spy(player_id: int) -> Dictionary:
	## Spend gold to interrogate a captured spy. 50% chance to reveal enemy spy network level.
	if not ResourceManager.can_afford(player_id, {"gold": INTERROGATION_COST}):
		return {"success": false, "message": "金币不足 (需要%d)" % INTERROGATION_COST}
	ResourceManager.spend(player_id, {"gold": INTERROGATION_COST})
	var roll: int = randi() % 100
	if roll < INTERROGATION_SUCCESS_CHANCE:
		return {"success": true, "message": "审讯成功! 获取敌方间谍网络情报",
			"revealed": true}
	return {"success": false, "message": "审讯失败! 间谍拒不开口", "revealed": false}


# ═══════════════ HERO PASSIVE HELPERS ═══════════════

func _get_max_intel(player_id: int) -> int:
	## Base 100 + spy_master bonuses from recruited heroes.
	var max_val: int = INTEL_MAX_BASE
	max_val += _count_hero_passive(player_id, "spy_master") * SPY_MASTER_INTEL_BONUS
	return max_val


func _get_spy_master_bonus(player_id: int) -> int:
	## +10% operation success per spy_master hero.
	return _count_hero_passive(player_id, "spy_master") * SPY_MASTER_SUCCESS_BONUS


func _get_intel_decay(player_id: int) -> int:
	## 5/turn default, reduced to 2/turn if any hero has shadow_network.
	if _count_hero_passive(player_id, "shadow_network") > 0:
		return INTEL_DECAY_SHADOW
	return INTEL_DECAY_DEFAULT


func _count_hero_passive(player_id: int, passive_name: String) -> int:
	## Count recruited heroes with the given passive. Checks base passive + level passives.
	## BUG FIX: only count heroes belonging to the specified player
	var count: int = 0
	if not HeroSystem:
		return count
	for hero_id in HeroSystem.recruited_heroes:
		var info: Dictionary = HeroSystem.get_hero_info(hero_id)
		if info.is_empty():
			continue
		if info.get("owner_id", -1) != player_id:
			continue
		if info.get("passive", "") == passive_name:
			count += 1
			continue
		var level_passives: Array = info.get("level_passives", [])
		if passive_name in level_passives:
			count += 1
	return count


# ═══════════════ PROCESS TURN ═══════════════

func process_turn(player_id: int) -> Array:
	## Called each turn. Decays intel, ticks cooldowns, expires reveals/sabotage.
	## Returns array of intel event strings.
	var events: Array = []

	# ── Intel decay ──
	var old_intel: int = get_intel(player_id)
	if old_intel > 0:
		var decay: int = _get_intel_decay(player_id)
		_set_intel(player_id, maxi(0, old_intel - decay))
		if get_intel(player_id) != old_intel:
			events.append("情报衰减 -%d (当前%d)" % [decay, get_intel(player_id)])

	# ── Tick cooldowns ──
	if _cooldowns.has(player_id):
		for op_type in _cooldowns[player_id]:
			if _cooldowns[player_id][op_type] > 0:
				_cooldowns[player_id][op_type] -= 1

	# ── Tick revealed tiles ──
	if _revealed_tiles.has(player_id):
		var still_active: Array = []
		for entry in _revealed_tiles[player_id]:
			entry["turns_left"] -= 1
			if entry["turns_left"] > 0:
				still_active.append(entry)
			else:
				events.append("目标格#%d情报过期" % entry["tile"])
		_revealed_tiles[player_id] = still_active

	# ── Tick intercepted orders ──
	if _intercepted_orders.has(player_id):
		var active_intercepts: Array = []
		for entry in _intercepted_orders[player_id]:
			entry["turns_left"] -= 1
			if entry["turns_left"] > 0:
				active_intercepts.append(entry)
		_intercepted_orders[player_id] = active_intercepts

	# ── Tick sabotaged tiles ──
	if _sabotaged_tiles.has(player_id):
		var active_sab: Array = []
		for entry in _sabotaged_tiles[player_id]:
			entry["turns_left"] -= 1
			if entry["turns_left"] > 0:
				active_sab.append(entry)
			else:
				events.append("目标格#%d破坏效果结束" % entry["tile"])
		_sabotaged_tiles[player_id] = active_sab

	# ── Tick wounded heroes ──
	if _wounded_heroes.has(player_id):
		var active_wounds: Array = []
		for entry in _wounded_heroes[player_id]:
			entry["turns_left"] -= 1
			if entry["turns_left"] > 0:
				active_wounds.append(entry)
			else:
				events.append("英雄 %s 伤势痊愈" % entry["hero_id"])
		_wounded_heroes[player_id] = active_wounds

	if EventBus.has_signal("tile_indicator_refresh"):
		EventBus.tile_indicator_refresh.emit(-1)

	return events


# ═══════════════ QUERY HELPERS ═══════════════

func get_revealed_tiles(player_id: int) -> Array:
	## Returns array of tile indices currently revealed by spy operations.
	var tiles: Array = []
	for entry in _revealed_tiles.get(player_id, []):
		if entry["turns_left"] > 0:
			tiles.append(entry["tile"])
	return tiles


func get_operation_cooldowns(player_id: int) -> Dictionary:
	## Returns { OpType: turns_remaining } for all operations.
	var result: Dictionary = {}
	for op_type in OPERATION_DEFS:
		result[op_type] = _get_cooldown(player_id, op_type)
	return result


func get_sabotaged_tiles(player_id: int) -> Array:
	## Returns array of { "tile": int, "turns_left": int, "production_penalty": float }.
	return _sabotaged_tiles.get(player_id, []).duplicate(true)


func get_wounded_heroes(player_id: int) -> Array:
	## Returns array of { "hero_id": String, "turns_left": int, ... }.
	return _wounded_heroes.get(player_id, []).duplicate(true)


func get_intercepted_factions(player_id: int) -> Array:
	## Returns array of faction/player ids whose orders are currently intercepted.
	var factions: Array = []
	for entry in _intercepted_orders.get(player_id, []):
		if entry["turns_left"] > 0:
			factions.append(entry["target_id"])
	return factions


func is_tile_sabotaged(tile_idx: int) -> bool:
	## Check if any player has sabotaged this tile (for production calc integration).
	for pid in _sabotaged_tiles:
		for entry in _sabotaged_tiles[pid]:
			if entry["tile"] == tile_idx and entry["turns_left"] > 0:
				return true
	return false


func get_sabotage_penalty(tile_idx: int) -> float:
	## Returns the production penalty (0.0 to 1.0) for a sabotaged tile.
	for pid in _sabotaged_tiles:
		for entry in _sabotaged_tiles[pid]:
			if entry["tile"] == tile_idx and entry["turns_left"] > 0:
				return entry["production_penalty"]
	return 0.0


# ═══════════════ COOLDOWN HELPERS ═══════════════

func _get_cooldown(player_id: int, op_type: int) -> int:
	if not _cooldowns.has(player_id):
		return 0
	return _cooldowns[player_id].get(op_type, 0)


func _set_cooldown(player_id: int, op_type: int, turns: int) -> void:
	if not _cooldowns.has(player_id):
		_cooldowns[player_id] = {}
	_cooldowns[player_id][op_type] = turns


# ═══════════════ SCOUT SYNERGY & BLOWN COVER ═══════════════

func _record_scout(player_id: int, tile_idx: int) -> void:
	## Record a successful scout for synergy tracking.
	if not _scout_history.has(player_id):
		_scout_history[player_id] = []
	_scout_history[player_id].append({"tile": tile_idx, "turn": _get_current_turn()})


func _has_scout_synergy(player_id: int, tile_idx: int) -> bool:
	## Check if tile was scouted within the last SCOUT_SYNERGY_WINDOW turns.
	if not _scout_history.has(player_id):
		return false
	var cur_turn: int = _get_current_turn()
	for entry in _scout_history[player_id]:
		if entry["tile"] == tile_idx and (cur_turn - entry["turn"]) <= SCOUT_SYNERGY_WINDOW:
			return true
	return false


func _track_consecutive_failure(player_id: int, target_id: int, succeeded: bool) -> void:
	## Track consecutive failures per target. After 3 in a row, blown cover penalty.
	if not _consecutive_failures.has(player_id):
		_consecutive_failures[player_id] = {}
	if succeeded:
		_consecutive_failures[player_id][target_id] = 0
		return
	var prev: int = _consecutive_failures[player_id].get(target_id, 0)
	prev += 1
	_consecutive_failures[player_id][target_id] = prev
	if prev >= BLOWN_COVER_FAIL_THRESHOLD:
		# Blown cover: intel network exposed
		_set_intel(player_id, maxi(0, get_intel(player_id) - BLOWN_COVER_INTEL_LOSS))
		# Resolve the owning player from tile index to apply counter-intel correctly
		var _bc_owner: int = -1
		if target_id >= 0 and target_id < GameManager.tiles.size():
			# BUG FIX R13: null check on tile before .get()
			if GameManager.tiles[target_id] != null:
				_bc_owner = GameManager.tiles[target_id].get("owner_id", -1)
		if _bc_owner < 0:
			_bc_owner = target_id  # fallback: treat target_id as player_id
		set_counter_intel(_bc_owner, get_counter_intel(_bc_owner) + BLOWN_COVER_CI_GAIN)
		_consecutive_failures[player_id][target_id] = 0
		EventBus.message_log.emit("[谍报] 情报网暴露! 连续%d次失败, 情报-%d, 对方反情报+%d" % [
			BLOWN_COVER_FAIL_THRESHOLD, BLOWN_COVER_INTEL_LOSS, BLOWN_COVER_CI_GAIN])


func _get_current_turn() -> int:
	## Helper to get current game turn from GameManager or fallback.
	if GameManager and GameManager.has_method("get_current_turn"):
		return GameManager.get_current_turn()
	return 0


# ═══════════════ REVEALED TILE HELPERS ═══════════════

func _add_revealed_tile(player_id: int, tile_idx: int, duration: int) -> void:
	if not _revealed_tiles.has(player_id):
		_revealed_tiles[player_id] = []
	# Refresh if already revealed
	for entry in _revealed_tiles[player_id]:
		if entry["tile"] == tile_idx:
			entry["turns_left"] = maxi(entry["turns_left"], duration)
			return
	_revealed_tiles[player_id].append({"tile": tile_idx, "turns_left": duration})


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"intel": _intel.duplicate(),
		"counter_intel": _counter_intel.duplicate(),
		"cooldowns": _cooldowns.duplicate(true),
		"revealed_tiles": _revealed_tiles.duplicate(true),
		"intercepted_orders": _intercepted_orders.duplicate(true),
		"sabotaged_tiles": _sabotaged_tiles.duplicate(true),
		"wounded_heroes": _wounded_heroes.duplicate(true),
		"consecutive_failures": _consecutive_failures.duplicate(true),
		"scout_history": _scout_history.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_intel = data.get("intel", {}).duplicate()
	_counter_intel = data.get("counter_intel", {}).duplicate()
	_cooldowns = data.get("cooldowns", {}).duplicate(true)
	_revealed_tiles = data.get("revealed_tiles", {}).duplicate(true)
	_intercepted_orders = data.get("intercepted_orders", {}).duplicate(true)
	_sabotaged_tiles = data.get("sabotaged_tiles", {}).duplicate(true)
	_wounded_heroes = data.get("wounded_heroes", {}).duplicate(true)
	_consecutive_failures = data.get("consecutive_failures", {}).duplicate(true)
	_scout_history = data.get("scout_history", {}).duplicate(true)
	# Fix int keys after JSON round-trip
	_fix_int_keys(_intel)
	_fix_int_keys(_counter_intel)
	_fix_int_keys(_cooldowns)
	# BUG FIX: fix inner dict keys for cooldowns and consecutive_failures
	for pid in _cooldowns:
		if _cooldowns[pid] is Dictionary:
			_fix_int_keys(_cooldowns[pid])
	_fix_int_keys(_revealed_tiles)
	_fix_int_keys(_intercepted_orders)
	_fix_int_keys(_sabotaged_tiles)
	_fix_int_keys(_wounded_heroes)
	_fix_int_keys(_consecutive_failures)
	for pid in _consecutive_failures:
		if _consecutive_failures[pid] is Dictionary:
			_fix_int_keys(_consecutive_failures[pid])
	_fix_int_keys(_scout_history)


func _fix_int_keys(dict: Dictionary) -> void:
	var fix_keys: Array = []
	for k in dict.keys():
		if k is String and k.is_valid_int():
			fix_keys.append(k)
	for k in fix_keys:
		dict[int(k)] = dict[k]
		dict.erase(k)
