## orc_mechanic.gd - Complete Orc faction mechanics (v2.0 — 兽人完整游戏性)
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
# BREEDING / REPRODUCTION STATE (兽人繁衍机制)
# ══════════════════════════════════════════════════════════════════════════════
var _brood_pits: Dictionary = {}       # player_id -> int (number of brood pits)
var _population_pool: Dictionary = {}  # player_id -> int (unassigned population)
var _growth_rate: Dictionary = {}      # player_id -> float (last calculated growth mult)
var _tribe_size: Dictionary = {}       # player_id -> int (total tribe pop including army)

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
	# Breeding state
	_brood_pits.clear()
	_population_pool.clear()
	_growth_rate.clear()
	_tribe_size.clear()
	# Roar state
	_roar_cooldown.clear()
	_roar_active.clear()
	# Momentum state
	_combat_streak.clear()


func init_player(player_id: int) -> void:
	_waaagh[player_id] = 0
	_frenzy_turns[player_id] = 0
	_idle_turns[player_id] = 0
	# Breeding defaults
	_brood_pits[player_id] = 0
	_population_pool[player_id] = 5  # Start with a small population pool
	_growth_rate[player_id] = 0.0
	_tribe_size[player_id] = 0
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
		if tile["owner_id"] == player_id and tile.get("building_id", "") == "totem_pole":
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
		# Run breeding even during frenzy (frenzy boosts growth)
		_tick_breeding(player_id)
		return

	# ── Threshold check: 90+ triggers frenzy explosion ──
	if _waaagh[player_id] >= params["waaagh_tier_3_threshold"]:
		_start_frenzy(player_id)
	elif _waaagh[player_id] <= 0:
		_trigger_infighting(player_id)

	# ── Report graduated bonus ──
	var atk_bonus: int = get_waaagh_atk_bonus(player_id)
	if atk_bonus > 0:
		EventBus.message_log.emit("[color=red]WAAAGH! %s: 全军ATK+%d (当前: %d)[/color]" % [
			get_waaagh_tier_name(player_id), atk_bonus, _waaagh[player_id]])

	# ── Breeding tick (at end of turn processing) ──
	_tick_breeding(player_id)


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
# WAR PIT (existing feature)
# ══════════════════════════════════════════════════════════════════════════════

func convert_slave_to_army(player_id: int) -> bool:
	## War Pit: 1 slave -> 3 army.
	var slaves: int = ResourceManager.get_slaves(player_id)
	if slaves <= 0:
		EventBus.message_log.emit("没有奴隶可以转换!")
		return false
	ResourceManager.apply_delta(player_id, {"slaves": -1})
	SlaveManager.remove_slaves(player_id, 1)
	var gain: int = FactionData.UNIQUE_BUILDINGS[FactionData.FactionID.ORC]["war_pit"]["effect_value"]
	ResourceManager.add_army(player_id, gain)
	EventBus.message_log.emit("[color=red]战争深坑: 1奴隶 -> %d军队![/color]" % gain)
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
# BREEDING / REPRODUCTION SYSTEM (兽人繁衍机制)
# ══════════════════════════════════════════════════════════════════════════════

## Returns the unassigned orc population available for recruitment.
func get_population_pool(player_id: int) -> int:
	return _population_pool.get(player_id, 0)


## Returns the total tribe size (army + unassigned population).
func get_tribe_size(player_id: int) -> int:
	return _tribe_size.get(player_id, 0)


## Returns the last calculated growth rate multiplier for display.
func get_growth_rate(player_id: int) -> float:
	return _growth_rate.get(player_id, 0.0)


## Consume population from the pool for recruitment purposes.
## Returns true if there was enough population, false otherwise.
func consume_population(player_id: int, amount: int) -> bool:
	var pool: int = _population_pool.get(player_id, 0)
	if pool < amount:
		EventBus.message_log.emit("[color=red]兽人人口不足! 需要%d, 仅有%d[/color]" % [amount, pool])
		return false
	_population_pool[player_id] = pool - amount
	# Tribe size does NOT decrease — soldiers are still part of the tribe
	EventBus.message_log.emit("[color=red]征召%d兽人入伍! 剩余人口池: %d[/color]" % [amount, _population_pool[player_id]])
	return true


## Check if the population pool is large enough to auto-spawn a free unit.
func can_auto_spawn(player_id: int) -> bool:
	return _population_pool.get(player_id, 0) >= 20


## Auto-spawn a free basic unit by splitting the tribe.
## Consumes 20 population from pool and returns a dictionary with unit info.
## Returns {} if not enough population.
func auto_spawn_unit(player_id: int) -> Dictionary:
	if not can_auto_spawn(player_id):
		return {}
	_population_pool[player_id] -= 20
	# Tribe size stays the same (unit is part of tribe)
	var unit_info: Dictionary = {
		"troop_id": "orc_ashigaru",
		"count": 20,
		"atk": 3,
		"hp": 40,
		"source": "tribe_split",
	}
	EventBus.message_log.emit("[color=red]部落分裂! 20名兽人自发组成新战队![/color]")
	return unit_info


## Internal: calculate new population growth for this turn.
func _calculate_growth(player_id: int) -> int:
	# Count controlled territory
	var territory_count: int = 0
	var brood_pits: int = 0
	var totem_growth_bonus: int = 0
	for tile in GameManager.tiles:
		if tile["owner_id"] == player_id:
			territory_count += 1
			var bid: String = tile.get("building_id", "")
			if bid == "brood_pit":
				brood_pits += 1
			elif bid == "totem_pole":
				# Totem poles give +1 growth per level as secondary source
				totem_growth_bonus += tile.get("building_level", 1)
	_brood_pits[player_id] = brood_pits

	# Base growth: 2 per territory
	var base_growth: int = territory_count * 2

	# Food multiplier: clamp food ratio to [0.5, 2.0]
	var tribe_sz: int = _tribe_size.get(player_id, 1)
	var food: float = float(ResourceManager.get_resource(player_id, "food"))
	var food_need: float = maxf(1.0, float(tribe_sz) * 0.5)
	var food_mult: float = clampf(food / food_need, 0.5, 2.0)

	# WAAAGH multiplier: 0 WAAAGH = x1.0, 100 WAAAGH = x2.0
	var waaagh_mult: float = 1.0 + float(get_waaagh(player_id)) * 0.01

	# Brood pit bonus: +3 per pit
	var brood_pit_bonus: int = brood_pits * 3

	# Totem pole secondary bonus
	var extra_bonus: int = totem_growth_bonus

	# Frenzy bonus: +5 during frenzy
	var frenzy_bonus: int = 5 if is_in_frenzy(player_id) else 0

	# Desperate breeding: if tribe is very small and territory scarce, double rate
	var desperate_mult: float = 1.0
	if tribe_sz < 10 and territory_count < 3:
		desperate_mult = 2.0
		EventBus.message_log.emit("[color=red]绝境繁衍! 部落濒临灭亡, 繁殖速度翻倍![/color]")

	# Momentum: Unstoppable Horde (5+ streak) doubles population growth
	var momentum_mult: float = 1.0
	var streak: int = _combat_streak.get(player_id, 0)
	if streak >= 5:
		momentum_mult = 2.0
		EventBus.message_log.emit("[color=red]势不可挡! 连续战斗%d回合, 人口增长翻倍![/color]" % streak)

	var raw_growth: float = float(base_growth + brood_pit_bonus + extra_bonus + frenzy_bonus)
	var new_pop: int = int(raw_growth * food_mult * waaagh_mult * desperate_mult * momentum_mult)

	# Store computed growth rate for UI queries
	_growth_rate[player_id] = food_mult * waaagh_mult * desperate_mult * momentum_mult

	return maxi(new_pop, 0)


## Internal: run the breeding phase at end of turn tick.
func _tick_breeding(player_id: int) -> void:
	# Sync tribe size with current army + population pool
	var army_count: int = ResourceManager.get_army(player_id)
	var pool: int = _population_pool.get(player_id, 0)
	_tribe_size[player_id] = army_count + pool

	# Calculate and apply growth
	var growth: int = _calculate_growth(player_id)
	if growth > 0:
		_population_pool[player_id] = _population_pool.get(player_id, 0) + growth
		_tribe_size[player_id] += growth
		EventBus.message_log.emit("[color=red]兽人繁衍: 人口 +%d (人口池: %d, 部落总数: %d)[/color]" % [
			growth, _population_pool[player_id], _tribe_size[player_id]])

	# Food consumption: tribe eats tribe_size * 0.3 food per turn
	var tribe_sz: int = _tribe_size.get(player_id, 0)
	var food_cost: int = ceili(float(tribe_sz) * 0.3)
	if food_cost > 0:
		ResourceManager.apply_delta(player_id, {"food": -food_cost})
		EventBus.message_log.emit("[color=red]兽人食物消耗: -%d (部落规模: %d)[/color]" % [food_cost, tribe_sz])

	# Auto-spawn check: notify player if they can split
	if can_auto_spawn(player_id):
		EventBus.message_log.emit("[color=yellow]人口池已达%d! 可以执行'部落分裂'获得免费战队![/color]" % _population_pool[player_id])


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
			EventBus.message_log.emit("[color=red]势不可挡的部落! 连续战斗%d回合, 人口增长翻倍![/color]" % streak)
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
		ResourceManager.remove_army(player_id, loss)
		EventBus.message_log.emit("[color=red]WAAAGH! 狂暴结束! 军队损失%d (疲劳)[/color]" % loss)
	_waaagh[player_id] = 0
	EventBus.frenzy_ended.emit(player_id)
	EventBus.waaagh_changed.emit(player_id, _waaagh[player_id])


func _trigger_infighting(player_id: int) -> void:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	var army: int = ResourceManager.get_army(player_id)
	var loss: int = ceili(float(army) * params["waaagh_zero_infighting_loss_pct"])
	if loss > 0:
		ResourceManager.remove_army(player_id, loss)
		EventBus.message_log.emit("[color=red]WAAAGH! 耗尽! 内讧导致%d军队损失![/color]" % loss)
	_waaagh[player_id] = 10  # Reset to small value to prevent infinite loop


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
		# Breeding state
		"brood_pits": _brood_pits.duplicate(),
		"population_pool": _population_pool.duplicate(),
		"growth_rate": _growth_rate.duplicate(),
		"tribe_size": _tribe_size.duplicate(),
		# Roar state
		"roar_cooldown": _roar_cooldown.duplicate(),
		"roar_active": _roar_active.duplicate(),
		# Momentum state
		"combat_streak": _combat_streak.duplicate(),
	}


func from_save_data(data: Dictionary) -> void:
	# Original WAAAGH state
	_waaagh = data.get("waaagh", {}).duplicate()
	_frenzy_turns = data.get("frenzy_turns", {}).duplicate()
	_idle_turns = data.get("idle_turns", {}).duplicate()
	_frenzy_count = int(data.get("frenzy_count", 0))
	# Breeding state
	_brood_pits = data.get("brood_pits", {}).duplicate()
	_population_pool = data.get("population_pool", {}).duplicate()
	_growth_rate = data.get("growth_rate", {}).duplicate()
	_tribe_size = data.get("tribe_size", {}).duplicate()
	# Roar state
	_roar_cooldown = data.get("roar_cooldown", {}).duplicate()
	_roar_active = data.get("roar_active", {}).duplicate()
	# Momentum state
	_combat_streak = data.get("combat_streak", {}).duplicate()
