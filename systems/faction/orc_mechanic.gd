## orc_mechanic.gd - Complete Orc faction mechanics (v2.1 — 兽人完整游戏性)
##
## Graduated WAAAGH! thresholds:
##   0-29:  No bonus
##   30-59: ATK+1 to all orc units
##   60-89: ATK+2, immune to morale collapse
##   90-100: WAAAGH! Explosion — ATK+4, first-round charge bonus, frenzy state
##
## WAAAGH! gain:  +5 per orc unit in combat, +10 per enemy squad destroyed
## WAAAGH! decay: -10 per non-combat turn
##
## v2.0 additions:
##   - Orc Breeding / Reproduction system (兽人繁衍机制)
##   - WAAAGH! Roar active ability (怒吼技能)
##   - Tribe Momentum / combat streak system (部落势头)
##   - apply_waaagh_bonus_to_units() for CombatSystem integration
##
## v2.1 changes:
##   - Sex-slave-driven reproduction (性奴隶繁殖机制)
##   - Territory slave penalty (领地掠夺惩罚)
##   - Warrior pool replaces population pool
##   - Advanced units consume sex slaves
##   - War impact on enemy slave production
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ══════════════════════════════════════════════════════════════════════════════
# WAAAGH! STATE (per player, only used by Orc faction)
# ══════════════════════════════════════════════════════════════════════════════
var _waaagh: Dictionary = {}           # player_id -> int (0-100)
var _frenzy_turns: Dictionary = {}     # player_id -> int remaining frenzy turns
var _idle_turns: Dictionary = {}       # player_id -> int turns without combat
var _frenzy_count: int = 0

# ══════════════════════════════════════════════════════════════════════════════
# SEX SLAVE REPRODUCTION STATE (性奴隶繁殖机制)
# ══════════════════════════════════════════════════════════════════════════════
var _brood_pits: Dictionary = {}       # player_id -> int (number of brood pits)
var _sex_slaves: Dictionary = {}       # player_id -> int (性奴隶数量)
var _warrior_pool: Dictionary = {}     # player_id -> int (unassigned warriors for recruitment)
var _breed_rate: Dictionary = {}       # player_id -> float (繁殖效率, last calculated)
var _total_warriors: Dictionary = {}   # player_id -> int (总兵力, synced from army)

# Sex slave cost constants for advanced unit training
const SLAVE_COST_TIER2: int = 1        # orc_samurai, orc_cavalry
const SLAVE_COST_TIER3: int = 2        # shadow_walker
const SLAVE_COST_ULTIMATE: int = 3     # ultimate units

# ══════════════════════════════════════════════════════════════════════════════
# WAAAGH! ROAR ABILITY STATE (怒吼技能)
# ══════════════════════════════════════════════════════════════════════════════
var _roar_cooldown: Dictionary = {}    # player_id -> int (turns remaining)
var _roar_active: Dictionary = {}      # player_id -> bool (active this turn)
const ROAR_WAAAGH_COST: int = 20
const ROAR_COOLDOWN: int = 5
const ROAR_ATK_MULT: float = 1.5

# ══════════════════════════════════════════════════════════════════════════════
# TRIBE MOMENTUM STATE (部落势头 — 连续战斗加成)
# ══════════════════════════════════════════════════════════════════════════════
var _combat_streak: Dictionary = {}    # player_id -> int (consecutive combat turns)


# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	pass


func reset() -> void:
	_waaagh.clear()
	_frenzy_turns.clear()
	_idle_turns.clear()
	_frenzy_count = 0
	# Sex slave / reproduction state
	_brood_pits.clear()
	_sex_slaves.clear()
	_warrior_pool.clear()
	_breed_rate.clear()
	_total_warriors.clear()
	# Roar state
	_roar_cooldown.clear()
	_roar_active.clear()
	# Momentum state
	_combat_streak.clear()


func init_player(player_id: int) -> void:
	_waaagh[player_id] = 0
	_frenzy_turns[player_id] = 0
	_idle_turns[player_id] = 0
	# Sex slave / reproduction defaults
	_brood_pits[player_id] = 0
	_sex_slaves[player_id] = 3       # Start with 3 sex slaves (性奴隶初始数量)
	_warrior_pool[player_id] = 0     # No free warriors at start
	_breed_rate[player_id] = 0.0
	_total_warriors[player_id] = 0
	# Roar defaults
	_roar_cooldown[player_id] = 0
	_roar_active[player_id] = false
	# Momentum defaults
	_combat_streak[player_id] = 0


# ══════════════════════════════════════════════════════════════════════════════
# WAAAGH! QUERIES (original API)
# ══════════════════════════════════════════════════════════════════════════════

func get_waaagh(player_id: int) -> int:
	return _waaagh.get(player_id, 0)


func is_in_frenzy(player_id: int) -> bool:
	return _frenzy_turns.get(player_id, 0) > 0


## Returns the WAAAGH! tier label string for UI display.
func get_waaagh_tier_name(player_id: int) -> String:
	var w: int = get_waaagh(player_id)
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	if w >= params["waaagh_tier_3_threshold"]:
		return "WAAAGH!爆发"
	elif w >= params["waaagh_tier_2_threshold"]:
		return "狂热"
	elif w >= params["waaagh_tier_1_threshold"]:
		return "亢奋"
	return "平静"


## Returns graduated ATK bonus from WAAAGH! thresholds (applied to all orc units).
func get_waaagh_atk_bonus(player_id: int) -> int:
	var w: int = get_waaagh(player_id)
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	if w >= params["waaagh_tier_3_threshold"]:
		return params["waaagh_tier_3_atk"]  # +4
	elif w >= params["waaagh_tier_2_threshold"]:
		return params["waaagh_tier_2_atk"]  # +2
	elif w >= params["waaagh_tier_1_threshold"]:
		return params["waaagh_tier_1_atk"]  # +1
	return 0


## Returns frenzy damage multiplier (2.0 during frenzy, else 1.0).
func get_damage_multiplier(player_id: int) -> float:
	if is_in_frenzy(player_id):
		return FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]["waaagh_frenzy_damage_mult"]
	return 1.0


# ══════════════════════════════════════════════════════════════════════════════
# NEW: WAAAGH! ATK BONUS APPLIED TO COMBAT UNITS
# ══════════════════════════════════════════════════════════════════════════════

## Called by CombatSystem before battle to apply WAAAGH ATK bonus to all orc units.
## Also applies WAAAGH! Roar multiplier if active this turn.
func apply_waaagh_bonus_to_units(player_id: int, units: Array) -> void:
	var bonus: int = get_waaagh_atk_bonus(player_id)
	var roar: bool = is_roar_active(player_id)
	if bonus <= 0 and not roar:
		return
	for unit in units:
		if unit is Dictionary:
			var base_atk: int = unit.get("atk", 0)
			# Apply flat WAAAGH tier bonus first
			base_atk += bonus
			# Apply roar multiplier on top if active
			if roar:
				base_atk = int(float(base_atk) * ROAR_ATK_MULT)
			unit["atk"] = base_atk
		# If BattleUnit class, handled by CombatSystem directly


# ══════════════════════════════════════════════════════════════════════════════
# TURN TICK (main entry point per turn)
# ══════════════════════════════════════════════════════════════════════════════

func tick(player_id: int, had_combat: bool) -> void:
	## Called at the START of each Orc player's turn.
	if not _waaagh.has(player_id):
		return

	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]

	# ── Clear roar active flag from previous turn ──
	_roar_active[player_id] = false

	# ── Tick roar cooldown ──
	if _roar_cooldown.get(player_id, 0) > 0:
		_roar_cooldown[player_id] -= 1

	# ── Tribe Momentum: update combat streak ──
	_tick_momentum(player_id, had_combat)

	# ── Totem Pole bonus ──
	var totem_bonus: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id and tile.get("building_id", "") == "totem_pole":
			var lvl: int = tile.get("building_level", 1)
			var level_data: Dictionary = FactionData.BUILDING_LEVELS.get("totem_pole", {}).get(lvl, {})
			totem_bonus += level_data.get("waaagh_per_turn", 5)
	if totem_bonus > 0:
		_add_waaagh(player_id, totem_bonus)
		EventBus.waaagh_changed.emit(player_id, _waaagh[player_id])
		EventBus.message_log.emit("[color=red]图腾柱效果: WAAAGH! +%d[/color]" % totem_bonus)

	# ── T4 蛮牛酋长 aura: +15 WAAAGH!/turn (map_effect.waaagh_per_turn) ──
	var army: Array = RecruitManager.get_army(player_id)
	for troop in army:
		var aura: Dictionary = GameData.AURA_DEFS.get(troop.get("troop_id", ""), {})
		var map_eff: Dictionary = aura.get("map_effect", {})
		if map_eff.has("waaagh_per_turn"):
			var waaagh_gain: int = map_eff["waaagh_per_turn"]
			_add_waaagh(player_id, waaagh_gain)
			EventBus.waaagh_changed.emit(player_id, _waaagh[player_id])
			EventBus.message_log.emit("[color=red]蛮牛酋长光环: WAAAGH! +%d[/color]" % waaagh_gain)

	# ── Momentum bonus: Blood Tide (3+ streak) gives +50% WAAAGH gain ──
	# (Already applied inside on_combat_result; streak itself tracked above)

	# ── Idle decay (doc: -10 per non-combat turn) ──
	if not had_combat:
		_idle_turns[player_id] = _idle_turns.get(player_id, 0) + 1
		var decay: int = params["waaagh_idle_decay"]
		_add_waaagh(player_id, -decay)
		EventBus.waaagh_changed.emit(player_id, _waaagh[player_id])
		EventBus.message_log.emit("无战斗回合, WAAAGH! -%d (当前: %d)" % [decay, _waaagh[player_id]])
	else:
		_idle_turns[player_id] = 0

	# ── Frenzy handling ──
	if _frenzy_turns.get(player_id, 0) > 0:
		_frenzy_turns[player_id] -= 1
		EventBus.message_log.emit("[color=red]WAAAGH! 狂暴中! 剩余%d回合 (伤害x%.1f)[/color]" % [
			_frenzy_turns[player_id], params["waaagh_frenzy_damage_mult"]])
		if _frenzy_turns[player_id] <= 0:
			_end_frenzy(player_id)
		# Run reproduction even during frenzy (frenzy boosts breeding)
		_tick_reproduction(player_id)
		return

	# ── Threshold check: 90+ triggers frenzy explosion ──
	if _waaagh[player_id] >= params["waaagh_tier_3_threshold"]:
		_start_frenzy(player_id)
	elif _waaagh[player_id] <= 0:
		_trigger_infighting(player_id)
	elif _waaagh[player_id] <= params.get("waaagh_infighting_threshold", 20):
		# BUG修复: WAAAGH!<=20时有概率内讧(faction_data定义了阈值20和10%概率)
		var infight_chance: float = params.get("waaagh_infighting_chance", 0.10)
		if randf() < infight_chance:
			_trigger_infighting(player_id)

	# ── Report graduated bonus ──
	var atk_bonus: int = get_waaagh_atk_bonus(player_id)
	if atk_bonus > 0:
		EventBus.message_log.emit("[color=red]WAAAGH! %s: 全军ATK+%d (当前: %d)[/color]" % [
			get_waaagh_tier_name(player_id), atk_bonus, _waaagh[player_id]])

	# ── Reproduction tick (at end of turn processing) ──
	_tick_reproduction(player_id)


# ══════════════════════════════════════════════════════════════════════════════
# COMBAT CALLBACKS
# ══════════════════════════════════════════════════════════════════════════════

## Called after combat. Gains WAAAGH! based on orc_unit_count and enemy_kills.
func on_combat_result(player_id: int, orc_unit_count: int, enemy_squads_destroyed: int) -> void:
	if not _waaagh.has(player_id):
		return
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	var unit_gain: int = orc_unit_count * params["waaagh_per_unit_in_combat"]
	var kill_gain: int = enemy_squads_destroyed * params["waaagh_per_kill"]
	var total: int = unit_gain + kill_gain

	# Blood Tide: 3+ combat streak grants +50% WAAAGH gain
	var streak: int = _combat_streak.get(player_id, 0)
	if streak >= 3:
		var streak_bonus: int = int(float(total) * 0.5)
		total += streak_bonus
		EventBus.message_log.emit("[color=red]血潮加成! WAAAGH额外 +%d (连续战斗%d回合)[/color]" % [streak_bonus, streak])

	_add_waaagh(player_id, total)
	EventBus.waaagh_changed.emit(player_id, _waaagh[player_id])
	EventBus.message_log.emit("[color=red]战斗! WAAAGH! +%d (%d兵×5 + %d击杀×10) 当前: %d[/color]" % [
		total, orc_unit_count, enemy_squads_destroyed, _waaagh[player_id]])


## Legacy: simple flat gain (for backward compat with non-detailed combat calls).
func on_combat_win(player_id: int) -> void:
	on_combat_result(player_id, 3, 1)  # Approximate: 3 units, 1 squad kill


# ══════════════════════════════════════════════════════════════════════════════
# WAR PIT (updated to use sex slaves as source)
# ══════════════════════════════════════════════════════════════════════════════

## War Pit: captures sex slaves instead of converting generic slaves.
## 1 captured slave -> 1 sex slave (added to sex slave pool, subject to capacity).
func convert_slave_to_army(player_id: int) -> bool:
	var slaves: int = ResourceManager.get_slaves(player_id)
	if slaves <= 0:
		EventBus.message_log.emit("没有奴隶可以转换!")
		return false
	# Check sex slave capacity
	var capacity: int = get_sex_slave_capacity(player_id)
	var current: int = _sex_slaves.get(player_id, 0)
	if current >= capacity:
		EventBus.message_log.emit("[color=red]性奴隶已达上限 (%d/%d)! 无法转换更多![/color]" % [current, capacity])
		return false
	SlaveManager.remove_slaves(player_id, 1)
	_sex_slaves[player_id] = current + 1
	EventBus.message_log.emit("[color=red]战争深坑: 1奴隶 -> 1性奴隶! (当前: %d/%d)[/color]" % [
		_sex_slaves[player_id], capacity])
	return true


# ══════════════════════════════════════════════════════════════════════════════
# WAAAGH! ROAR ACTIVE ABILITY (怒吼技能)
# ══════════════════════════════════════════════════════════════════════════════

## Check whether the player can activate WAAAGH! Roar this turn.
func can_use_waaagh_roar(player_id: int) -> bool:
	return get_waaagh(player_id) >= ROAR_WAAAGH_COST and _roar_cooldown.get(player_id, 0) <= 0


## Activate WAAAGH! Roar: costs WAAAGH, sets cooldown, buffs ATK this turn.
## Returns true on success.
func use_waaagh_roar(player_id: int) -> bool:
	if not can_use_waaagh_roar(player_id):
		return false
	_add_waaagh(player_id, -ROAR_WAAAGH_COST)
	_roar_cooldown[player_id] = ROAR_COOLDOWN
	_roar_active[player_id] = true
	EventBus.waaagh_changed.emit(player_id, _waaagh[player_id])
	EventBus.message_log.emit("[color=red]>>> WAAAGH!怒吼! 本回合全军ATK×%.1f! <<<[/color]" % ROAR_ATK_MULT)
	return true


## Returns whether WAAAGH! Roar buff is active for this turn's combat.
func is_roar_active(player_id: int) -> bool:
	return _roar_active.get(player_id, false)


# ══════════════════════════════════════════════════════════════════════════════
# SEX SLAVE REPRODUCTION SYSTEM (性奴隶繁殖机制)
# ══════════════════════════════════════════════════════════════════════════════

## Returns the warrior pool available for recruitment.
func get_warrior_pool(player_id: int) -> int:
	return _warrior_pool.get(player_id, 0)


## Returns the total warrior count (army + warrior pool).
func get_total_warriors(player_id: int) -> int:
	return _total_warriors.get(player_id, 0)


## Returns the last calculated breed rate multiplier for display.
func get_breed_rate(player_id: int) -> float:
	return _breed_rate.get(player_id, 0.0)


## Returns the current sex slave count for the player.
func get_sex_slaves(player_id: int) -> int:
	return _sex_slaves.get(player_id, 0)


## Returns the maximum sex slave capacity for the player.
## Formula: 5 + territory_count * 2 + brood_pits * 3
func get_sex_slave_capacity(player_id: int) -> int:
	var territory_count: int = _count_territory(player_id)
	var brood_pits: int = _brood_pits.get(player_id, 0)
	return 5 + territory_count * 2 + brood_pits * 3


## Add captured sex slaves (applies territory penalty and capacity cap).
## Returns the actual number of sex slaves added.
func add_sex_slaves(player_id: int, count: int) -> int:
	var penalty: float = _get_territory_slave_penalty(player_id)
	var effective: int = maxi(int(float(count) * penalty), 0)
	var capacity: int = get_sex_slave_capacity(player_id)
	var current: int = _sex_slaves.get(player_id, 0)
	var space: int = maxi(capacity - current, 0)
	var added: int = mini(effective, space)
	if added > 0:
		_sex_slaves[player_id] = current + added
		EventBus.message_log.emit("[color=red]捕获性奴隶 +%d (领地惩罚: x%.1f, 容量: %d/%d)[/color]" % [
			added, penalty, _sex_slaves[player_id], capacity])
	elif effective > 0 and space <= 0:
		EventBus.message_log.emit("[color=red]性奴隶已满! 无法容纳更多 (%d/%d)[/color]" % [current, capacity])
	return added


## Consume sex slaves for advanced unit training.
## Returns true if enough sex slaves were available, false otherwise.
func consume_sex_slaves(player_id: int, count: int) -> bool:
	var current: int = _sex_slaves.get(player_id, 0)
	if current < count:
		EventBus.message_log.emit("[color=red]性奴隶不足! 需要%d, 仅有%d[/color]" % [count, current])
		return false
	_sex_slaves[player_id] = current - count
	EventBus.message_log.emit("[color=red]消耗性奴隶 -%d (剩余: %d)[/color]" % [count, _sex_slaves[player_id]])
	return true


## Returns the sex slave cost for training a specific unit type.
func get_slave_cost_for_unit(troop_id: String) -> int:
	match troop_id:
		"orc_ashigaru": return 0  # basic unit, free
		"orc_samurai", "orc_cavalry": return SLAVE_COST_TIER2
		"shadow_walker": return SLAVE_COST_TIER3
		_: return SLAVE_COST_ULTIMATE  # ultimate units


## Called after a battle to capture sex slaves (applies territory penalty).
## Returns the actual number of sex slaves captured.
func on_battle_capture_slaves(player_id: int, base_count: int) -> int:
	return add_sex_slaves(player_id, base_count)


## Consume warriors from the pool for recruitment purposes.
## Returns true if there were enough warriors, false otherwise.
func consume_warriors(player_id: int, amount: int) -> bool:
	var pool: int = _warrior_pool.get(player_id, 0)
	if pool < amount:
		EventBus.message_log.emit("[color=red]战士不足! 需要%d, 仅有%d[/color]" % [amount, pool])
		return false
	_warrior_pool[player_id] = pool - amount
	# Total warriors does NOT decrease — soldiers are still part of the army
	EventBus.message_log.emit("[color=red]征召%d战士入伍! 剩余战士池: %d[/color]" % [amount, _warrior_pool[player_id]])
	return true


## Check if the warrior pool is large enough to auto-spawn a free unit.
func can_auto_spawn(player_id: int) -> bool:
	return _warrior_pool.get(player_id, 0) >= 15


## Auto-spawn a free basic unit from the warrior pool.
## Consumes 15 warriors from pool and returns a dictionary with unit info.
## Returns {} if not enough warriors.
func auto_spawn_unit(player_id: int) -> Dictionary:
	if not can_auto_spawn(player_id):
		return {}
	_warrior_pool[player_id] -= 15
	# Total warriors stays the same (unit is part of army)
	var unit_info: Dictionary = {
		"troop_id": "orc_ashigaru",
		"count": 15,
		"atk": 3,
		"hp": 40,
		"source": "sex_slave_breeding",
	}
	EventBus.message_log.emit("[color=red]性奴隶繁殖成功! 15名新生战士自动编入战队![/color]")
	return unit_info


## Territory slave penalty (核心机制): the more territory orcs control, the LESS
## slaves they can capture. Represents "plundering the land dry".
func _get_territory_slave_penalty(player_id: int) -> float:
	var territory_count: int = _count_territory(player_id)
	# 1-5 tiles: no penalty (1.0x)
	# 6-10 tiles: 0.8x
	# 11-15 tiles: 0.6x
	# 16-20 tiles: 0.4x
	# 21+: 0.2x (almost no slaves from new conquests)
	if territory_count <= 5: return 1.0
	elif territory_count <= 10: return 0.8
	elif territory_count <= 15: return 0.6
	elif territory_count <= 20: return 0.4
	else: return 0.2


## Internal: count territories owned by player.
func _count_territory(player_id: int) -> int:
	var count: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			count += 1
	return count


## Internal: check if two players are at war.
func _is_at_war_with(player_a: int, player_b: int) -> bool:
	# Delegate to DiplomacyManager if available
	# DiplomacyManager tracks hostility per faction, not per player.
	# Check if player_a's faction is hostile toward player_b (via player_b's relations).
	if DiplomacyManager != null and DiplomacyManager.has_method("get_all_relations"):
		var faction_a: int = GameManager.get_player_faction(player_a)
		var relations_b: Dictionary = DiplomacyManager.get_all_relations(player_b)
		if relations_b.has(faction_a) and relations_b[faction_a].get("hostile", false):
			return true
		var faction_b: int = GameManager.get_player_faction(player_b)
		var relations_a: Dictionary = DiplomacyManager.get_all_relations(player_a)
		if relations_a.has(faction_b) and relations_a[faction_b].get("hostile", false):
			return true
	return false


## Returns the slave production penalty for factions at war with orcs.
## Called by other faction mechanics to reduce their slave production.
func get_war_slave_penalty(target_player_id: int) -> float:
	# Check if any orc player is at war with target
	# If so, return a penalty multiplier based on orc territory size
	for pid in _waaagh:
		if pid == target_player_id:
			continue
		# Check if orc player is at war with target
		if _is_at_war_with(pid, target_player_id):
			var orc_territory: int = _count_territory(pid)
			# More orc territory = bigger penalty on enemies
			if orc_territory >= 15:
				return 0.3  # -70% slave production
			elif orc_territory >= 10:
				return 0.5  # -50%
			elif orc_territory >= 5:
				return 0.7  # -30%
	return 1.0  # No penalty


## Internal: calculate new warrior output from sex slave breeding for this turn.
func _calculate_breed_output(player_id: int) -> int:
	# Count brood pits from tiles
	var brood_pits: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			var bid: String = tile.get("building_id", "")
			if bid == "brood_pit":
				brood_pits += 1
	_brood_pits[player_id] = brood_pits

	var sex_slaves: int = _sex_slaves.get(player_id, 0)
	if sex_slaves <= 0:
		_breed_rate[player_id] = 0.0
		return 0

	# Base breed: each sex slave produces 2 warriors per turn
	var base_breed: int = sex_slaves * 2

	# WAAAGH multiplier: 0 WAAAGH = x1.0, 100 WAAAGH = x2.0
	var waaagh_mult: float = 1.0 + float(get_waaagh(player_id)) * 0.01

	# Brood pit multiplier: each brood pit +25% efficiency
	var brood_pit_mult: float = 1.0 + float(brood_pits) * 0.25

	# Frenzy bonus: frenzy doubles breeding output (adds sex_slaves extra warriors)
	var frenzy_bonus: int = sex_slaves if is_in_frenzy(player_id) else 0

	# Momentum: Unstoppable Horde (5+ streak) doubles breeding output
	var momentum_mult: float = 1.0
	var streak: int = _combat_streak.get(player_id, 0)
	if streak >= 5:
		momentum_mult = 2.0
		EventBus.message_log.emit("[color=red]势不可挡! 连续战斗%d回合, 繁殖产出翻倍![/color]" % streak)

	var new_warriors: int = int(float(base_breed) * waaagh_mult * brood_pit_mult * momentum_mult) + frenzy_bonus

	# Store computed breed rate for UI queries
	_breed_rate[player_id] = waaagh_mult * brood_pit_mult * momentum_mult

	return maxi(new_warriors, 0)


## Internal: run the reproduction phase at end of turn tick.
func _tick_reproduction(player_id: int) -> void:
	# Sync total warriors with current army + warrior pool
	var army_count: int = ResourceManager.get_army(player_id)
	var pool: int = _warrior_pool.get(player_id, 0)
	_total_warriors[player_id] = army_count + pool

	# Calculate and apply breeding output
	var new_warriors: int = _calculate_breed_output(player_id)
	if new_warriors > 0:
		_warrior_pool[player_id] = _warrior_pool.get(player_id, 0) + new_warriors
		_total_warriors[player_id] += new_warriors
		var slaves: int = _sex_slaves.get(player_id, 0)
		var capacity: int = get_sex_slave_capacity(player_id)
		EventBus.message_log.emit("[color=red]性奴隶繁殖: 战士 +%d (战士池: %d, 性奴隶: %d/%d, 总兵力: %d)[/color]" % [
			new_warriors, _warrior_pool[player_id], slaves, capacity, _total_warriors[player_id]])

	# Food consumption: total warriors eat total_warriors * 0.3 food per turn
	var total_w: int = _total_warriors.get(player_id, 0)
	var food_cost: int = ceili(float(total_w) * 0.3)
	if food_cost > 0:
		ResourceManager.apply_delta(player_id, {"food": -food_cost})
		EventBus.message_log.emit("[color=red]兽人食物消耗: -%d (总兵力: %d)[/color]" % [food_cost, total_w])

	# Auto-spawn check: notify player if they can spawn
	if can_auto_spawn(player_id):
		EventBus.message_log.emit("[color=yellow]战士池已达%d! 可以自动编成新战队![/color]" % _warrior_pool[player_id])


# ══════════════════════════════════════════════════════════════════════════════
# TRIBE MOMENTUM SYSTEM (部落势头)
# ══════════════════════════════════════════════════════════════════════════════

## Internal: update the combat streak tracker.
func _tick_momentum(player_id: int, had_combat: bool) -> void:
	if had_combat:
		_combat_streak[player_id] = _combat_streak.get(player_id, 0) + 1
		var streak: int = _combat_streak[player_id]
		if streak == 3:
			EventBus.message_log.emit("[color=red]血潮降临! 连续战斗%d回合, WAAAGH获取+50%%![/color]" % streak)
		elif streak == 5:
			EventBus.message_log.emit("[color=red]势不可挡的部落! 连续战斗%d回合, 繁殖产出翻倍![/color]" % streak)
		elif streak > 5 and streak % 5 == 0:
			EventBus.message_log.emit("[color=red]战斗狂潮持续! 连续%d回合![/color]" % streak)
	else:
		var prev: int = _combat_streak.get(player_id, 0)
		if prev >= 3:
			EventBus.message_log.emit("[color=gray]战斗中断, 部落势头消散 (此前连续%d回合)[/color]" % prev)
		_combat_streak[player_id] = 0


# ══════════════════════════════════════════════════════════════════════════════
# WAAAGH! INTERNAL HELPERS
# ══════════════════════════════════════════════════════════════════════════════

## Public add_waaagh: clamps and emits signal.
func add_waaagh(player_id: int, amount: int) -> void:
	_waaagh[player_id] = clampi(_waaagh.get(player_id, 0) + amount, 0, 100)
	EventBus.waaagh_changed.emit(player_id, _waaagh[player_id])


## Internal add_waaagh: clamps but does NOT emit signal (caller emits if needed).
func _add_waaagh(player_id: int, amount: int) -> void:
	_waaagh[player_id] = clampi(_waaagh.get(player_id, 0) + amount, 0, 100)


func get_frenzy_count() -> int:
	return _frenzy_count


func _start_frenzy(player_id: int) -> void:
	_frenzy_count += 1
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	_frenzy_turns[player_id] = params["waaagh_frenzy_turns"]
	EventBus.frenzy_started.emit(player_id)
	EventBus.message_log.emit("[color=red]>>> WAAAGH! 狂暴爆发! %d回合内伤害x%.1f! <<<[/color]" % [
		params["waaagh_frenzy_turns"], params["waaagh_frenzy_damage_mult"]])


func _end_frenzy(player_id: int) -> void:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	var army: int = ResourceManager.get_army(player_id)
	var loss: int = ceili(float(army) * params["waaagh_frenzy_army_loss_pct"])
	if loss > 0:
		RecruitManager.apply_combat_losses(player_id, loss)
		EventBus.message_log.emit("[color=red]WAAAGH! 狂暴结束! 军队损失%d (疲劳)[/color]" % loss)
	_waaagh[player_id] = 0
	EventBus.frenzy_ended.emit(player_id)
	EventBus.waaagh_changed.emit(player_id, _waaagh[player_id])


func _trigger_infighting(player_id: int) -> void:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	var army: int = ResourceManager.get_army(player_id)
	var loss: int = ceili(float(army) * params["waaagh_zero_infighting_loss_pct"])
	if loss > 0:
		RecruitManager.apply_combat_losses(player_id, loss)
		EventBus.message_log.emit("[color=red]WAAAGH! 耗尽! 内讧导致%d军队损失![/color]" % loss)
	_waaagh[player_id] = 25  # Reset above infighting threshold to prevent repeat triggers


# ══════════════════════════════════════════════════════════════════════════════
# BACKWARD COMPATIBILITY (deprecated wrappers)
# ══════════════════════════════════════════════════════════════════════════════

## Deprecated: use get_warrior_pool() instead.
func get_population_pool(player_id: int) -> int:
	return get_warrior_pool(player_id)


## Deprecated: use get_total_warriors() instead.
func get_tribe_size(player_id: int) -> int:
	return get_total_warriors(player_id)


## Deprecated: use get_breed_rate() instead.
func get_growth_rate(player_id: int) -> float:
	return get_breed_rate(player_id)


## Deprecated: use consume_warriors() instead.
func consume_population(player_id: int, amount: int) -> bool:
	return consume_warriors(player_id, amount)


# ══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD
# ══════════════════════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	return {
		# Original WAAAGH state
		"waaagh": _waaagh.duplicate(),
		"frenzy_turns": _frenzy_turns.duplicate(),
		"idle_turns": _idle_turns.duplicate(),
		"frenzy_count": _frenzy_count,
		# Sex slave / reproduction state
		"brood_pits": _brood_pits.duplicate(),
		"sex_slaves": _sex_slaves.duplicate(),
		"warrior_pool": _warrior_pool.duplicate(),
		"breed_rate": _breed_rate.duplicate(),
		"total_warriors": _total_warriors.duplicate(),
		# Roar state
		"roar_cooldown": _roar_cooldown.duplicate(),
		"roar_active": _roar_active.duplicate(),
		# Momentum state
		"combat_streak": _combat_streak.duplicate(),
	}


static func _fix_int_keys(dict: Dictionary) -> void:
	var fix_keys = []
	for k in dict.keys():
		if k is String and k.is_valid_int():
			fix_keys.append(k)
	for k in fix_keys:
		dict[int(k)] = dict[k]
		dict.erase(k)


func from_save_data(data: Dictionary) -> void:
	# Original WAAAGH state
	_waaagh = data.get("waaagh", {}).duplicate()
	_fix_int_keys(_waaagh)
	_frenzy_turns = data.get("frenzy_turns", {}).duplicate()
	_fix_int_keys(_frenzy_turns)
	_idle_turns = data.get("idle_turns", {}).duplicate()
	_fix_int_keys(_idle_turns)
	_frenzy_count = int(data.get("frenzy_count", 0))
	# Sex slave / reproduction state (with backward compatibility)
	_brood_pits = data.get("brood_pits", {}).duplicate()
	_fix_int_keys(_brood_pits)
	if data.has("sex_slaves"):
		_sex_slaves = data.get("sex_slaves", {}).duplicate()
	else:
		_sex_slaves = {}  # Old save: no sex slaves, start fresh
	_fix_int_keys(_sex_slaves)
	if data.has("warrior_pool"):
		_warrior_pool = data.get("warrior_pool", {}).duplicate()
	elif data.has("population_pool"):
		# Backward compat: migrate population_pool -> warrior_pool
		_warrior_pool = data.get("population_pool", {}).duplicate()
	else:
		_warrior_pool = {}
	_fix_int_keys(_warrior_pool)
	if data.has("breed_rate"):
		_breed_rate = data.get("breed_rate", {}).duplicate()
	elif data.has("growth_rate"):
		# Backward compat: migrate growth_rate -> breed_rate
		_breed_rate = data.get("growth_rate", {}).duplicate()
	else:
		_breed_rate = {}
	_fix_int_keys(_breed_rate)
	if data.has("total_warriors"):
		_total_warriors = data.get("total_warriors", {}).duplicate()
	elif data.has("tribe_size"):
		# Backward compat: migrate tribe_size -> total_warriors
		_total_warriors = data.get("tribe_size", {}).duplicate()
	else:
		_total_warriors = {}
	_fix_int_keys(_total_warriors)
	# Roar state
	_roar_cooldown = data.get("roar_cooldown", {}).duplicate()
	_fix_int_keys(_roar_cooldown)
	_roar_active = data.get("roar_active", {}).duplicate()
	_fix_int_keys(_roar_active)
	# Momentum state
	_combat_streak = data.get("combat_streak", {}).duplicate()
	_fix_int_keys(_combat_streak)
