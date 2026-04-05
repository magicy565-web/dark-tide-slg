## combat_system.gd — Battle Engine v10.3 (Full Merge)
## v11.0 DEEP OPTIMIZATION: Crit system, hit/dodge, buff stack cap, data-driven skills, combo tracking.
class_name CombatSystem
extends RefCounted

const FactionData = preload("res://systems/faction/faction_data.gd")
const CounterMatrix = preload("res://systems/combat/counter_matrix.gd")
const FormationSystem = preload("res://systems/combat/formation_system.gd")
const BalanceConfig = preload("res://systems/balance/balance_config.gd")
# v10.6: Integration with previously disconnected subsystems
const CombatAbilities = preload("res://systems/combat/combat_abilities.gd")
const EnvironmentSystem = preload("res://systems/combat/environment_system.gd")
const SupplySystem = preload("res://systems/combat/supply_system.gd")
# EnchantmentSystem is an autoload singleton — accessed via Engine.get_singleton at runtime
# const EnchantmentSystem = preload("res://systems/hero/enchantment_system.gd")  # removed: non-static call

# ---------------------------------------------------------------------------
# Constants & Enums
# ---------------------------------------------------------------------------

const MAX_ROUNDS := 8
const MAX_FRONT_SLOTS := 3
const MAX_BACK_SLOTS := 3

# ── v11.0: Combat Tuning Constants ──
## Base critical hit chance (5%). Modified by passives and morale.
const BASE_CRIT_CHANCE := 0.05
## Critical hit damage multiplier.
const CRIT_DAMAGE_MULT := 1.8
## Base hit chance (90%). High-DEF units can reduce this.
const BASE_HIT_CHANCE := 0.90
## Maximum number of same-id buff stacks per unit (prevents infinite stacking).
const MAX_BUFF_STACKS := 3
## Combo tracking: minimum kills in one round to trigger combo bonus.
const COMBO_KILL_THRESHOLD := 2
## Combo ATK bonus per kill above threshold.
const COMBO_ATK_BONUS_PER_KILL := 0.05

# ── v11.0: Data-driven skill definitions ──
## Centralised skill registry — keyed by skill name string.
## Fields: type, mana_cost, cooldown, damage_mult, heal_pct, buff_type, buff_value, buff_dur, aoe_mult
const SKILL_DATA: Dictionary = {
	"圣光斩":    {"type": "damage",  "mana_cost": 0, "cooldown": 2, "damage_mult": 1.6},
	"治愈之光":  {"type": "heal",    "mana_cost": 0, "cooldown": 2, "heal_pct": 0.25},
	"突击号令":  {"type": "buff",    "mana_cost": 0, "cooldown": 3, "buff_type": "atk", "buff_value": 0.25, "buff_dur": 2},
	"不动如山":  {"type": "buff",    "mana_cost": 0, "cooldown": 3, "buff_type": "def", "buff_value": 0.30, "buff_dur": 2},
	"箭雨":      {"type": "aoe",     "mana_cost": 0, "cooldown": 3, "damage_mult": 1.2, "aoe_mult": 0.65},
	"月光护盾":  {"type": "buff",    "mana_cost": 3, "cooldown": 3, "buff_type": "def", "buff_value": 0.40, "buff_dur": 3},
	"影步":      {"type": "damage",  "mana_cost": 0, "cooldown": 2, "damage_mult": 1.7, "ignore_def": true},
	"流星火雨":  {"type": "aoe",     "mana_cost": 8, "cooldown": 4, "damage_mult": 2.0, "aoe_mult": 0.80},
	"时间减速":  {"type": "debuff",  "mana_cost": 3, "cooldown": 3, "buff_type": "spd", "buff_value": -0.30, "buff_dur": 2},
	"爆裂火球":  {"type": "damage",  "mana_cost": 3, "cooldown": 2, "damage_mult": 1.9},
	"连射":      {"type": "multi",   "mana_cost": 0, "cooldown": 2, "hit_count": 3, "damage_mult": 0.7},
	"致命一击":  {"type": "damage",  "mana_cost": 0, "cooldown": 2, "damage_mult": 2.0, "guaranteed_crit": true},
	"铁壁":      {"type": "buff",    "mana_cost": 0, "cooldown": 2, "buff_type": "def", "buff_value": 0.35, "buff_dur": 2},
	"沙暴":      {"type": "debuff",  "mana_cost": 0, "cooldown": 3, "buff_type": "atk", "buff_value": -0.25, "buff_dur": 2},
	"亡灵召唤":  {"type": "summon",  "mana_cost": 3, "cooldown": 4, "summon_pct": 0.15},
	"分身":      {"type": "buff",    "mana_cost": 0, "cooldown": 3, "buff_type": "def", "buff_value": 0.20, "buff_dur": 3},
	"净化":      {"type": "cleanse", "mana_cost": 0, "cooldown": 2, "heal_pct": 0.15},
	"集中轰炸":  {"type": "aoe",     "mana_cost": 0, "cooldown": 3, "damage_mult": 1.5, "aoe_mult": 0.70},
}

enum Terrain { PLAINS, FOREST, MOUNTAIN, WASTELAND, COASTAL, CITY }
enum UnitCommand { AUTO, GUARD, CHARGE, RETREAT }

# ---------------------------------------------------------------------------
# Classes
# ---------------------------------------------------------------------------

class BattleUnit:
	var id: String
	var commander_id: String
	var troop_id: String
	var hero_id: String = ""
	var atk: int
	var def_stat: int
	var spd: int
	var int_stat: int
	var soldiers: int
	var max_soldiers: int
	var row: int  # 0 = front, 1 = back
	var slot: int
	var passive: String = ""
	var is_attacker: bool
	var has_acted: bool = false
	var first_attack: bool = true
	var mana: int = 0
	var xp: int = 0
	var morale: int = 100
	var is_routed: bool = false

	# HP model
	var hp: int
	var max_hp: int
	var hp_per_soldier: int = 5

	# Hero-specific
	var hero_hp: int = 0
	var hero_max_hp: int = 0
	var hero_mp: int = 0
	var hero_max_mp: int = 0

	# v10.2: Persistent Buff System
	# Each buff: {id: String, duration: int, type: String ("atk"|"def"|"spd"), value: float}
	var active_buffs: Array = []

	# v4.5: Transient flags
	var _death_resist_used: bool = false
	var _ghost_shield_active: bool = false

	func is_alive() -> bool:
		return soldiers > 0

	func has_passive(pname: String) -> bool:
		if passive == "": return false
		for p in passive.split(","):
			if p.strip_edges() == pname: return true
		return false

	## v10.2: Sum all buff multipliers for a given stat type.
	## Supports both {type:"atk", value:0.2} and {mult_atk:true, value:0.2} formats
	## (the latter is used by CommanderIntervention).
	func get_stat_mult(stat_type: String) -> float:
		var mult := 1.0
		for b in active_buffs:
			var matched := false
			if b.get("type", "") == stat_type:
				matched = true
			elif stat_type == "atk" and b.get("mult_atk", false):
				matched = true
			elif stat_type == "def" and b.get("mult_def", false):
				matched = true
			if matched:
				mult += b.get("value", 0.0)
		return mult

	## v11.0: Count active stacks of a buff by id.
	func count_buff_stacks(buff_id: String) -> int:
		var count := 0
		for b in active_buffs:
			if b.get("id", "") == buff_id: count += 1
		return count

class BattleState:
	var attacker_units: Array[BattleUnit] = []
	var defender_units: Array[BattleUnit] = []
	var terrain: int = Terrain.PLAINS
	var round_number: int = 0
	var action_log: Array[Dictionary] = []
	var is_siege: bool = false
	var city_def: int = 0
	var mana_attacker: int = 0
	var mana_defender: int = 0
	var atk_formations: Array = []
	var def_formations: Array = []
	var terrain_str: String = ""
	# v10.6: army IDs for SupplySystem / EnvironmentSystem lookup
	var attacker_army_id: int = -1
	var defender_army_id: int = -1

	func living_attackers() -> Array[BattleUnit]:
		var out: Array[BattleUnit] = []
		for u in attacker_units:
			if u.is_alive(): out.append(u)
		return out

	func living_defenders() -> Array[BattleUnit]:
		var out: Array[BattleUnit] = []
		for u in defender_units:
			if u.is_alive(): out.append(u)
		return out

	func total_attacker_soldiers() -> int:
		var s := 0
		for u in attacker_units: s += u.soldiers
		return s

	func total_defender_soldiers() -> int:
		var s := 0
		for u in defender_units: s += u.soldiers
		return s

	func get_mana(is_attacker_side: bool) -> int:
		return mana_attacker if is_attacker_side else mana_defender

	func set_mana(is_attacker_side: bool, value: int) -> void:
		if is_attacker_side: mana_attacker = value
		else: mana_defender = value

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

var player_controlled: bool = false

# ── v11.0: Per-battle statistics tracking ──
var _battle_stats: Dictionary = {
	"total_crits": 0,
	"total_misses": 0,
	"max_single_hit": 0,
	"combo_kills": 0,
	"round_kill_counts": {},  # round -> kill count
	"skill_uses": {},         # skill_name -> use count
}

func resolve_battle(attacker_army: Dictionary, defender_army: Dictionary, node_data: Dictionary) -> Dictionary:
	var state := BattleState.new()

	# v11.0: Reset per-battle stats
	_battle_stats = {"total_crits": 0, "total_misses": 0, "max_single_hit": 0, "combo_kills": 0, "round_kill_counts": {}, "skill_uses": {}}

	# v6.0: Reset hero skill systems for this battle
	HeroSkillsAdvanced.reset_battle()

	state.attacker_units = _build_battle_units(attacker_army, true)
	state.defender_units = _build_battle_units(defender_army, false)

	# v10.1: Handle empty defender (instant win)
	if state.defender_units.is_empty():
		return {
			"winner": "attacker", "attacker_losses": {}, "defender_losses": {},
			"captured_heroes": [], "log": [{"action": "victory", "desc": "敌方无驻军，我方直接占领"}],
			"rounds": 0, "rounds_fought": 0, "enemy_troops_killed": 0, "defender_troops_killed": 0
		}

	state.terrain = node_data.get("terrain", Terrain.PLAINS)
	state.is_siege = node_data.get("is_siege", false)
	state.city_def = node_data.get("city_def", 0)
	state.mana_attacker = 0
	state.mana_defender = 0

	# Mana bonus: individual unit mana transferred to team pool
	for u in state.attacker_units:
		if u.mana > 0: state.mana_attacker += u.mana; u.mana = 0
	for u in state.defender_units:
		if u.mana > 0: state.mana_defender += u.mana; u.mana = 0

	_apply_terrain_modifiers(state)

	# v4.6: time_slow — enemy SPD-3 first round
	var _ts_atk_on_def := false
	for u in state.attacker_units:
		if u.has_passive("time_slow"): _ts_atk_on_def = true; break
	if _ts_atk_on_def:
		for u in state.defender_units: u.spd = maxi(1, u.spd - 3)
	var _ts_def_on_atk := false
	for u in state.defender_units:
		if u.has_passive("time_slow"): _ts_def_on_atk = true; break
	if _ts_def_on_atk:
		for u in state.attacker_units: u.spd = maxi(1, u.spd - 3)

	# Formation Detection & Synergy
	var atk_unit_dicts: Array = _build_formation_dicts(state.attacker_units)
	var def_unit_dicts: Array = _build_formation_dicts(state.defender_units)
	var terrain_str: String = FactionData.TERRAIN_DATA.get(state.terrain, {}).get("name", "plains")
	state.terrain_str = terrain_str
	var atk_formations: Array = FormationSystem.detect_formations(atk_unit_dicts, terrain_str)
	var def_formations: Array = FormationSystem.detect_formations(def_unit_dicts, terrain_str)
	state.atk_formations = atk_formations.duplicate()
	state.def_formations = def_formations.duplicate()
	if not atk_formations.is_empty():
		var atk_bonuses: Dictionary = FormationSystem.get_formation_bonuses(atk_formations)
		FormationSystem.apply_formation_to_units(atk_unit_dicts, atk_bonuses)
		_sync_formation_to_battle_units(state.attacker_units, atk_unit_dicts)
		FormationSystem.emit_formation_detected("attacker", atk_formations)
		for _fid in atk_formations:
			state.action_log.append({"action": "formation", "side": "attacker", "formation": FormationSystem.FORMATION_NAMES.get(_fid, "").to_lower().replace(" ", "_"), "name_cn": FormationSystem.FORMATION_NAMES_CN.get(_fid, ""), "desc": "攻方阵型: %s" % FormationSystem.FORMATION_NAMES_CN.get(_fid, "")})
	if not def_formations.is_empty():
		var def_bonuses: Dictionary = FormationSystem.get_formation_bonuses(def_formations)
		FormationSystem.apply_formation_to_units(def_unit_dicts, def_bonuses)
		_sync_formation_to_battle_units(state.defender_units, def_unit_dicts)
		FormationSystem.emit_formation_detected("defender", def_formations)
		for _fid in def_formations:
			state.action_log.append({"action": "formation", "side": "defender", "formation": FormationSystem.FORMATION_NAMES.get(_fid, "").to_lower().replace(" ", "_"), "name_cn": FormationSystem.FORMATION_NAMES_CN.get(_fid, ""), "desc": "守方阵型: %s" % FormationSystem.FORMATION_NAMES_CN.get(_fid, "")})
	var clashes: Dictionary = FormationSystem.check_formation_clash(atk_formations, def_formations)
	if not clashes.is_empty(): FormationSystem.emit_formation_clashes(clashes)

	var attacker_units_initial: Array = _snapshot_units(state.attacker_units)
	var defender_units_initial: Array = _snapshot_units(state.defender_units)

	var start_att: Dictionary = {}
	for u in state.attacker_units: start_att[u.id] = u.soldiers
	var start_def: Dictionary = {}
	for u in state.defender_units: start_def[u.id] = u.soldiers

	# Siege phase
	if state.is_siege and state.city_def > 0:
		for u in state.defender_units:
			if u.has_passive("node_wall_bonus"):
				state.city_def += 5
				state.action_log.append({"action": "passive", "event": "node_wall_bonus", "unit": u.id, "side": "defender", "slot": u.slot, "desc": "%s 的铁壁之盾强化城防 +5" % u.troop_id})
				break
		_resolve_siege_phase(state)

	_resolve_preemptive_phase(state)

	var winner := _check_battle_end(state)
	while winner == "" and state.round_number < MAX_ROUNDS:
		state.round_number += 1
		state.action_log.append({"action": "round_start", "round": state.round_number, "desc": "第%d回合开始" % state.round_number})

			# v10.2: Tick Buff Durations at round start
		_tick_buff_durations(state)
		# v10.6: Tick burn/slow debuffs from CombatAbilities (applied to battle_dict proxy)
		_tick_combat_abilities_debuffs(state)
		_apply_round_start_passives(state)
		_consume_formation_bonuses(state)
		_tick_hero_skills(state)

		# v4.6: time_slow — restore SPD after round 1
		if state.round_number == 2:
			if _ts_atk_on_def:
				for u in state.defender_units: u.spd += 3
			if _ts_def_on_atk:
				for u in state.attacker_units: u.spd += 3

		# Commander Intervention Phase
		if player_controlled and _has_autoload("CommanderIntervention"):
			var ci := _get_autoload("CommanderIntervention")
			if ci:
				ci.check_cp_regen(state.round_number)
				ci.tick_cooldowns()
				if ci.get_current_cp() > 0:
					var available: Array = ci.get_available_interventions()
					if not available.is_empty():
						var intervention_state: Dictionary = _build_intervention_state(state)
						intervention_state["round"] = state.round_number
						intervention_state["intervention_options"] = available
						intervention_state["intervention_cp"] = ci.get_current_cp()
						EventBus.combat_intervention_phase.emit(intervention_state)
						var result: Array = await EventBus.combat_intervention_chosen
						var chosen_type: int = result[0] if result.size() > 0 else -1
						var chosen_target: Variant = result[1] if result.size() > 1 else null
						if chosen_type >= 0:
							var log_lines: Array = []
							ci.execute(chosen_type, intervention_state, chosen_target, log_lines)
							_apply_intervention_results(state, intervention_state)
							var idata: Dictionary = ci.INTERVENTION_DATA.get(chosen_type, {})
							state.action_log.append({"action": "intervention", "round": state.round_number, "desc": log_lines[0] if not log_lines.is_empty() else idata.get("name", "干预")})

		var queue := _get_action_queue(state)
		for unit in queue:
			if not unit.is_alive() or unit.has_acted: continue
			var entry := _execute_action(unit, state)
			if entry.get("action", "") != "_already_logged":
				state.action_log.append(entry)
			if unit.has_passive("extra_action") and unit.is_alive():
				unit.has_acted = false
				var entry2 := _execute_action(unit, state)
				if entry2.get("action", "") != "_already_logged": state.action_log.append(entry2)
			if state.round_number == 1 and unit.has_passive("double_shot") and unit.is_alive() and not unit.has_passive("extra_action"):
				unit.has_acted = false
				var entry_ds := _execute_action(unit, state)
				if entry_ds.get("action", "") != "_already_logged": state.action_log.append(entry_ds)
			winner = _check_battle_end(state)
			if winner != "": break

		for u in state.attacker_units: u.has_acted = false
		for u in state.defender_units: u.has_acted = false
		_tick_intervention_durations(state)
		if winner == "": winner = _check_battle_end(state)

	if winner == "": winner = "defender"

	var attacker_losses: Dictionary = {}
	for u in state.attacker_units:
		var lost: int = start_att[u.id] - u.soldiers
		if lost > 0: attacker_losses[u.id] = lost
	var defender_losses: Dictionary = {}
	for u in state.defender_units:
		var lost: int = start_def[u.id] - u.soldiers
		if lost > 0: defender_losses[u.id] = lost

	var captured: Array = []
	var losing_units: Array[BattleUnit] = state.defender_units if winner == "attacker" else state.attacker_units
	for u in losing_units:
		if u.soldiers <= 0 and u.commander_id != "generic": captured.append(u.commander_id)

	var _att_killed: int = 0
	for _dk in defender_losses.values(): _att_killed += _dk
	var _def_killed: int = 0
	for _ak in attacker_losses.values(): _def_killed += _ak

	return {
		"winner": winner,
		"attacker_losses": attacker_losses,
		"defender_losses": defender_losses,
		"captured_heroes": captured,
		"log": state.action_log,
		"terrain": state.terrain,
		"rounds": state.round_number,
		"rounds_fought": state.round_number,
		"attacker_units_initial": attacker_units_initial,
		"defender_units_initial": defender_units_initial,
		"attacker_units_final": _snapshot_units(state.attacker_units),
		"defender_units_final": _snapshot_units(state.defender_units),
		"player_controlled": player_controlled,
		"enemy_troops_killed": _att_killed,
		"defender_troops_killed": _def_killed,
		# v11.0: Extended battle statistics for settlement rating
		"battle_stats": _battle_stats.duplicate(),
	}

# ---------------------------------------------------------------------------
# Unit Construction
# ---------------------------------------------------------------------------

func _build_battle_units(army: Dictionary, is_attacker: bool) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	var raw_units: Array = army.get("units", [])

	var tile_bonuses: Dictionary = {"atk": 0, "def": 0, "morale": 0}
	var tile_idx: int = army.get("tile_index", -1)
	if tile_idx >= 0 and _has_autoload("DiplomacyManager"):
		var dm: Node = _get_autoload("DiplomacyManager")
		if dm != null and dm.has_method("get_tile_combat_bonuses"):
			tile_bonuses = dm.get_tile_combat_bonuses(tile_idx)

	for i in range(raw_units.size()):
		var d: Dictionary = raw_units[i]
		var bu := BattleUnit.new()
		bu.id = d.get("id", "%s_%d" % ["att" if is_attacker else "def", i])
		bu.commander_id = d.get("commander_id", "generic")
		bu.troop_id = d.get("troop_id", "infantry")
		bu.atk = d.get("atk", 5)
		bu.def_stat = d.get("def", 5)
		bu.spd = d.get("spd", 5)
		bu.int_stat = d.get("int", 5)
		bu.soldiers = d.get("soldiers", 100)
		bu.max_soldiers = d.get("max_soldiers", d.get("soldiers", 100))
		bu.row = d.get("row_int", d.get("row", 0 if i < MAX_FRONT_SLOTS else 1))
		bu.slot = d.get("slot", i)
		bu.passive = d.get("passive", "")
		bu.is_attacker = is_attacker
		bu.has_acted = false
		bu.first_attack = true
		bu.mana = 0
		bu.xp = d.get("exp", 0)
		bu.hp_per_soldier = d.get("hp_per_soldier", 5)
		bu.max_hp = bu.soldiers * bu.hp_per_soldier
		bu.hp = bu.max_hp

		var hero_data: Dictionary = d.get("hero_data", {})
		if not hero_data.is_empty():
			bu.hero_id = hero_data.get("id", "")
			bu.hero_hp = hero_data.get("hp", 0)
			bu.hero_max_hp = bu.hero_hp
			bu.hero_mp = hero_data.get("mp", 0)
			bu.hero_max_mp = bu.hero_mp
			for ep in hero_data.get("equipment_passives", []):
				if ep != "" and ep != "none":
					bu.passive = bu.passive + ("," if bu.passive != "" else "") + ep
			for lp in hero_data.get("level_passives", []):
				var lp_id: String = lp if lp is String else lp.get("passive_id", lp.get("id", ""))
				if lp_id != "" and lp_id != "none" and lp_id not in bu.passive.split(","):
					bu.passive = bu.passive + ("," if bu.passive != "" else "") + lp_id
			if bu.has_passive("mana_bonus"): bu.mana += 3
			if bu.has_passive("one_battle_power"): bu.atk = int(ceil(float(bu.atk) * 1.3))
			if bu.has_passive("preemptive_bonus") or bu.has_passive("preemptive_shot"): bu.spd += 10

		if bu.has_passive("death_resist"): bu._death_resist_used = false
		if bu.has_passive("ghost_shield"): bu._ghost_shield_active = true

		if bu.hero_id != "" and not hero_data.is_empty():
			var hero_specialty: String = hero_data.get("troop_specialty", "")
			if hero_specialty != "" and bu.troop_id.find(hero_specialty) >= 0:
				bu.atk += BalanceConfig.HERO_TROOP_SYNERGY_ATK
				bu.def_stat += BalanceConfig.HERO_TROOP_SYNERGY_DEF
				bu.morale = mini(100, bu.morale + BalanceConfig.HERO_TROOP_SYNERGY_MORALE)

		if bu.xp >= BalanceConfig.ELITE_EXP_THRESHOLD:
			bu.atk += BalanceConfig.ELITE_ATK_BONUS
			bu.def_stat += BalanceConfig.ELITE_DEF_BONUS
			bu.morale = mini(100, bu.morale + BalanceConfig.ELITE_MORALE_BONUS)
		elif bu.xp >= BalanceConfig.VETERAN_EXP_THRESHOLD:
			bu.atk += BalanceConfig.VETERAN_ATK_BONUS
			bu.morale = mini(100, bu.morale + BalanceConfig.VETERAN_MORALE_BONUS)

		if tile_bonuses.get("atk", 0) > 0: bu.atk += tile_bonuses["atk"]
		if tile_bonuses.get("morale", 0) > 0: bu.morale = mini(100, bu.morale + tile_bonuses["morale"])
		# v0.9.3: Apply tech morale_cap_bonus buff — raises the morale ceiling above 100
		var _morale_cap: int = 100
		if army.get("is_player", false) and _has_autoload("BuffManager"):
			var _bm_buf: Node = _get_autoload("BuffManager")
			if _bm_buf != null and _bm_buf.has_method("get_buff_value"):
				var _pid: int = army.get("player_id", -1)
				var _raw_mc = _bm_buf.get_buff_value(_pid, "tech_morale_cap_bonus", 0)
				var _mc_bonus: int = int(_raw_mc) if (_raw_mc is int or _raw_mc is float) else 0
				_morale_cap = 100 + _mc_bonus
		# Re-clamp morale with the (potentially raised) cap
		bu.morale = clampi(bu.morale, 0, _morale_cap)

		if army.get("is_player", false) and _has_autoload("BalanceManager"):
			var _bm: Node = _get_autoload("BalanceManager")
			if _bm != null and _bm.has_method("get_player_atk_mult"):
				var _p_atk_mult: float = _bm.get_player_atk_mult()
				if _p_atk_mult != 1.0: bu.atk = maxi(1, int(float(bu.atk) * _p_atk_mult))

		units.append(bu)

	var _has_cmd: bool = false
	for _cb_u in units:
		if _cb_u.has_passive("command_bonus"): _has_cmd = true; break
	if _has_cmd:
		for _cb_u2 in units: _cb_u2.spd += 2

	return units

func _snapshot_units(units: Array[BattleUnit]) -> Array:
	var snap: Array = []
	for u in units:
		snap.append({"id": u.id, "commander_id": u.commander_id, "troop_id": u.troop_id, "atk": u.atk, "def": u.def_stat, "spd": u.spd, "int_stat": u.int_stat, "soldiers": u.soldiers, "max_soldiers": u.max_soldiers, "row": u.row, "slot": u.slot, "passive": u.passive, "is_attacker": u.is_attacker, "mana": u.mana, "xp": u.xp, "morale": u.morale, "is_routed": u.is_routed, "hp": u.hp, "max_hp": u.max_hp, "hp_per_soldier": u.hp_per_soldier, "hero_id": u.hero_id, "hero_hp": u.hero_hp, "hero_max_hp": u.hero_max_hp, "hero_mp": u.hero_mp, "hero_max_mp": u.hero_max_mp})
	return snap

# ---------------------------------------------------------------------------
# Phase Resolvers
# ---------------------------------------------------------------------------

func _resolve_siege_phase(state: BattleState) -> void:
	var total_siege_dmg: int = 0
	for u in state.attacker_units:
		if u.has_passive("siege_bonus"): total_siege_dmg += 2
	var atk_bonuses: Dictionary = FormationSystem.get_formation_bonuses(state.atk_formations)
	if atk_bonuses.get("siege_damage_mult", 1.0) > 1.0:
		total_siege_dmg = int(float(total_siege_dmg) * atk_bonuses["siege_damage_mult"])
	if total_siege_dmg > 0:
		state.city_def = maxi(0, state.city_def - total_siege_dmg)
		state.action_log.append({"action": "siege", "damage": total_siege_dmg, "remaining_def": state.city_def, "desc": "攻城阶段: 城防损失 %d, 剩余 %d" % [total_siege_dmg, state.city_def]})

func _resolve_preemptive_phase(state: BattleState) -> void:
	var preemptive_units: Array[BattleUnit] = []
	for u in state.attacker_units + state.defender_units:
		if u.is_alive() and u.has_passive("preemptive_shot"): preemptive_units.append(u)
	preemptive_units.sort_custom(func(a, b): return a.spd > b.spd)
	for u in preemptive_units:
		if u.is_alive():
			state.action_log.append(_execute_action(u, state))
			u.has_acted = true

# ---------------------------------------------------------------------------
# Core Action Logic
# ---------------------------------------------------------------------------

func _get_action_queue(state: BattleState) -> Array[BattleUnit]:
	var queue: Array[BattleUnit] = []
	for u in state.attacker_units + state.defender_units:
		if u.is_alive() and not u.is_routed: queue.append(u)
	queue.sort_custom(func(a, b):
		if a.spd != b.spd: return a.spd > b.spd
		return a.is_attacker and not b.is_attacker
	)
	return queue

func _execute_action(unit: BattleUnit, state: BattleState) -> Dictionary:
	unit.has_acted = true

	# 1) Active skills
	var skill := _get_active_skill(unit)
	if not skill.is_empty():
		var side_mana: int = state.get_mana(unit.is_attacker)
		if side_mana >= skill.get("mana_cost", 0):
			state.set_mana(unit.is_attacker, side_mana - skill.get("mana_cost", 0))
			# v11.0: Track skill usage stats
			var sk_name: String = skill.get("name", "")
			if sk_name != "":
				_battle_stats["skill_uses"][sk_name] = _battle_stats["skill_uses"].get(sk_name, 0) + 1
			return _execute_skill(unit, skill, state)

	# 2) Basic Attack
	var targets := _get_enemies(unit, state)
	if targets.is_empty(): return {"action": "idle", "unit": unit.id, "desc": "%s 待机" % unit.troop_id}

	# Shadow bypass
	var bonuses: Dictionary = FormationSystem.get_formation_bonuses(state.atk_formations if unit.is_attacker else state.def_formations)
	var bypass_chance: float = 0.0
	if state.round_number <= bonuses.get("shadow_bypass_rounds", 0):
		bypass_chance = bonuses.get("shadow_bypass_chance", 0.0)

	var target: BattleUnit = null
	if bypass_chance > 0.0 and randf() < bypass_chance:
		var back_targets: Array[BattleUnit] = []
		for t in targets:
			if t.row == 1: back_targets.append(t)
		if not back_targets.is_empty():
			target = back_targets[randi() % back_targets.size()]
			state.action_log.append({"action": "passive", "event": "shadow_bypass", "unit": unit.id, "side": "attacker" if unit.is_attacker else "defender", "slot": unit.slot, "desc": "%s 影袭绕后!" % unit.troop_id})

	# v10.4: forced_target — CommanderIntervention集火指令
	if target == null and state.has_meta("forced_target_slot"):
		var ft_slot: int = state.get_meta("forced_target_slot")
		var ft_dur: int = state.get_meta("forced_target_duration", 0)
		if ft_dur > 0:
			for t in targets:
				if t.slot == ft_slot and t.is_alive(): target = t; break
			# Decrement duration after last unit in queue acts
			state.set_meta("forced_target_duration", ft_dur - 1)
			if ft_dur - 1 <= 0: state.remove_meta("forced_target_slot")

	# v10.4: bait_target — CommanderIntervention诱敌指令（敌方单位优先攻击该槽位）
	if target == null and not unit.is_attacker and state.has_meta("bait_target_slot"):
		var bt_slot: int = state.get_meta("bait_target_slot")
		var bt_dur: int = state.get_meta("bait_duration", 0)
		if bt_dur > 0:
			for t in targets:
				if t.slot == bt_slot and t.is_alive(): target = t; break
			state.set_meta("bait_duration", bt_dur - 1)
			if bt_dur - 1 <= 0: state.remove_meta("bait_target_slot")

	if target == null:
		var front_targets: Array[BattleUnit] = []
		var back_targets2: Array[BattleUnit] = []
		for t in targets:
			if t.row == 0: front_targets.append(t)
			else: back_targets2.append(t)
		if not front_targets.is_empty(): target = front_targets[randi() % front_targets.size()]
		elif not back_targets2.is_empty(): target = back_targets2[randi() % back_targets2.size()]

	if target == null: return {"action": "idle", "unit": unit.id}

	# v4.6: ARROW_STORM — ranged units attack twice in rounds 1-2
	var is_double_shot: bool = false
	if state.round_number <= bonuses.get("ranged_double_attack_rounds", []).size():
		if FormationSystem._is_ranged({"troop_id": unit.troop_id}): is_double_shot = true

	# v11.0: Use extended damage calc with crit/miss
	var dmg_ex := _calculate_damage_ex(unit, target, state)
	var was_alive := target.is_alive()
	var dmg: int = dmg_ex["soldiers"]
	var is_crit: bool = dmg_ex["is_crit"]
	var is_miss: bool = dmg_ex["is_miss"]

	# Miss: log and return early
	if is_miss:
		state.action_log.append({"action": "miss", "unit": unit.id, "side": "attacker" if unit.is_attacker else "defender", "slot": unit.slot, "target": target.id, "target_side": "attacker" if target.is_attacker else "defender", "target_slot": target.slot, "desc": "%s 攻击 %s 未命中!" % [unit.troop_id, target.troop_id]})
		return {"action": "_already_logged"}

	var hp_dmg: int = dmg * target.hp_per_soldier

	if target._ghost_shield_active:
		target._ghost_shield_active = false
		hp_dmg = 0
		state.action_log.append({"action": "passive", "event": "ghost_shield", "unit": target.id, "side": "attacker" if target.is_attacker else "defender", "slot": target.slot, "desc": "%s 的幽灵护盾抵挡了攻击" % target.troop_id})

	target.hp = maxi(0, target.hp - hp_dmg)
	var old_soldiers := target.soldiers
	_recalc_soldiers(target)
	var actual_lost := old_soldiers - target.soldiers

	if was_alive and not target.is_alive() and target.has_passive("death_resist") and not target._death_resist_used:
		target._death_resist_used = true
		target.soldiers = 1
		target.hp = target.hp_per_soldier
		state.action_log.append({"action": "passive", "event": "death_resist", "unit": target.id, "side": "attacker" if target.is_attacker else "defender", "slot": target.slot, "desc": "%s 触发不屈，保留1兵力" % target.troop_id})

	# v11.0: Track round kill count for combo detection
	if was_alive and not target.is_alive():
		var rk: int = state.round_number
		_battle_stats["round_kill_counts"][rk] = _battle_stats["round_kill_counts"].get(rk, 0) + 1
		if _battle_stats["round_kill_counts"][rk] >= COMBO_KILL_THRESHOLD:
			_battle_stats["combo_kills"] += 1

	var entry := {
		"action": "attack", "unit": unit.id,
		"side": "attacker" if unit.is_attacker else "defender", "slot": unit.slot,
		"target": target.id, "target_side": "attacker" if target.is_attacker else "defender",
		"target_slot": target.slot, "damage": actual_lost, "remaining_soldiers": target.soldiers,
		"is_crit": is_crit,
		"desc": "%s %s攻击 %s，造成 %d 伤害" % [unit.troop_id, "暴击! " if is_crit else "", target.troop_id, actual_lost],
	}

	if was_alive and not target.is_alive():
		_apply_kill_heal(unit, state)
		_apply_kill_morale_boost(unit, target, state)
		state.action_log.append({"action": "death", "unit": target.id, "side": "attacker" if target.is_attacker else "defender", "slot": target.slot, "round": state.round_number, "desc": "%s 阵亡!" % target.troop_id})
		_apply_ally_death_morale(target, state)
		_revalidate_formations_for_side(target, state)

	# Counter-attack
	if target.is_alive() and not is_double_shot:
		if target.row == 0 or target.has_passive("counter_bonus"):
			_resolve_counter_attack(target, unit, state)

		# Poison
	if unit.has_passive("poison_attack") and target.is_alive():
		_apply_poison(unit, target, state)
	# v10.6: EnchantmentSystem — apply hero enchantment passive after each attack
	if not unit.hero_id.is_empty():
		var _ench_sys = Engine.get_singleton("EnchantmentSystem") if Engine.has_singleton("EnchantmentSystem") else null
		var ench_result: Dictionary = _ench_sys.apply_enchantment_in_combat(unit.hero_id, entry) if _ench_sys else {}
		var ench_effects: Array = ench_result.get("enchantment_effects", [])
		for eff in ench_effects:
			var eff_type: String = eff.get("type", "")
			if eff_type == "bonus_damage" and target.is_alive():
				var bonus: int = eff.get("value", 0)
				target.hp = maxi(0, target.hp - bonus * target.hp_per_soldier)
				_recalc_soldiers(target)
				state.action_log.append({"action": "enchantment", "unit": unit.id, "side": "attacker" if unit.is_attacker else "defender", "slot": unit.slot, "effect": eff_type, "value": bonus, "desc": "%s 附魔效果: +%d伤害" % [unit.troop_id, bonus]})
			elif eff_type == "heal_self":
				var heal: int = eff.get("value", 0)
				unit.hp = mini(unit.max_hp, unit.hp + heal * unit.hp_per_soldier)
				_recalc_soldiers(unit)
				state.action_log.append({"action": "enchantment", "unit": unit.id, "side": "attacker" if unit.is_attacker else "defender", "slot": unit.slot, "effect": eff_type, "value": heal, "desc": "%s 附魔治疗: +%d兵" % [unit.troop_id, heal]})
	return entry

func _execute_skill(unit: BattleUnit, skill: Dictionary, state: BattleState) -> Dictionary:
	var type: String = skill.get("type", "damage")
	var skill_mult: float = skill.get("damage_mult", 1.5)
	var side_str: String = "attacker" if unit.is_attacker else "defender"

	match type:
		"damage":
			var targets := _get_enemies(unit, state)
			if targets.is_empty(): return {"action": "idle", "unit": unit.id}
			var target := targets[randi() % targets.size()]
			# v11.0: Use extended damage with crit/miss
			var sk_dmg_ex := _calculate_damage_ex(unit, target, state, skill.get("damage_mult", 1.5), skill.get("guaranteed_crit", false))
			if sk_dmg_ex["is_miss"]:
				state.action_log.append({"action": "miss", "unit": unit.id, "side": side_str, "slot": unit.slot, "target": target.id, "target_side": "attacker" if target.is_attacker else "defender", "target_slot": target.slot, "desc": "%s 技能 %s 未命中!" % [unit.troop_id, skill.get("name", "技能")]})
				return {"action": "_already_logged"}
			var dmg: int = sk_dmg_ex["soldiers"]
			var is_crit_sk: bool = sk_dmg_ex["is_crit"]
			var was_alive_sk := target.is_alive()
			var old_soldiers := target.soldiers
			target.hp = maxi(0, target.hp - dmg * target.hp_per_soldier)
			_recalc_soldiers(target)
			var actual_lost := old_soldiers - target.soldiers
			# Trigger death cascades when skill kills a unit
			if was_alive_sk and not target.is_alive():
				state.action_log.append({"action": "death", "unit": target.id, "side": "attacker" if target.is_attacker else "defender", "slot": target.slot, "round": state.round_number, "desc": "%s 被技能击杀!" % target.troop_id})
				_apply_ally_death_morale(target, state)
				_revalidate_formations_for_side(target, state)
			return {"action": "skill", "unit": unit.id, "side": side_str, "slot": unit.slot, "skill_name": skill.get("name", "技能"), "target": target.id, "damage": actual_lost, "remaining_soldiers": target.soldiers, "is_crit": is_crit_sk, "desc": "%s 发动 %s%s，造成 %d 伤害" % [unit.troop_id, skill.get("name", "技能"), " (暴击!" + ")" if is_crit_sk else "", actual_lost]}
		"heal":
			var allies := state.attacker_units if unit.is_attacker else state.defender_units
			var heal_target: BattleUnit = null
			var min_ratio := 1.1
			for a in allies:
				if a.is_alive() and a.soldiers < a.max_soldiers:
					var ratio := float(a.soldiers) / float(a.max_soldiers)
					if ratio < min_ratio: min_ratio = ratio; heal_target = a
			if heal_target:
				var heal_amt := int(float(heal_target.max_soldiers) * 0.2)
				heal_target.hp = mini(heal_target.max_hp, heal_target.hp + heal_amt * heal_target.hp_per_soldier)
				_recalc_soldiers(heal_target)
				return {"action": "skill", "unit": unit.id, "side": side_str, "slot": unit.slot, "skill_name": skill.get("name", "技能"), "target": heal_target.id, "healed": heal_amt, "remaining_soldiers": heal_target.soldiers, "max_soldiers": heal_target.max_soldiers, "desc": "%s 发动 %s，回复 %d 兵力" % [unit.troop_id, skill.get("name", "技能"), heal_amt]}
		"aoe":
			# AOE: hits all living enemies for reduced damage
			var aoe_targets := _get_enemies(unit, state)
			var total_aoe_dmg := 0
			for aoe_t in aoe_targets:
				var aoe_dmg := _calculate_damage(unit, aoe_t, state, skill_mult * 0.6)
				var aoe_was_alive := aoe_t.is_alive()
				var aoe_old := aoe_t.soldiers
				aoe_t.hp = maxi(0, aoe_t.hp - aoe_dmg * aoe_t.hp_per_soldier)
				_recalc_soldiers(aoe_t)
				var aoe_lost := aoe_old - aoe_t.soldiers
				total_aoe_dmg += aoe_lost
				state.action_log.append({"action": "skill_hit", "unit": unit.id, "side": side_str, "slot": unit.slot, "skill_name": skill.get("name", "技能"), "target": aoe_t.id, "damage": aoe_lost, "remaining_soldiers": aoe_t.soldiers, "desc": "%s 被 %s 命中，损失 %d 兵" % [aoe_t.troop_id, skill.get("name", "技能"), aoe_lost]})
				if aoe_was_alive and not aoe_t.is_alive():
					state.action_log.append({"action": "death", "unit": aoe_t.id, "side": "attacker" if aoe_t.is_attacker else "defender", "slot": aoe_t.slot, "round": state.round_number, "desc": "%s 被范围技能歼灭!" % aoe_t.troop_id})
					_apply_ally_death_morale(aoe_t, state)
					_revalidate_formations_for_side(aoe_t, state)
			return {"action": "skill", "unit": unit.id, "side": side_str, "slot": unit.slot, "skill_name": skill.get("name", "技能"), "damage": total_aoe_dmg, "is_aoe": true, "desc": "%s 发动 %s (范围)，共造成 %d 伤害" % [unit.troop_id, skill.get("name", "技能"), total_aoe_dmg]}
		"buff":
			# v11.0: Data-driven buff — reads type/value/dur from skill definition
			var buff_allies := state.attacker_units if unit.is_attacker else state.defender_units
			var buff_count := 0
			var b_type: String = skill.get("buff_type", "atk")
			var b_val: float  = skill.get("buff_value", 0.20)
			var b_dur: int    = skill.get("buff_dur", 2)
			var b_label: String = "+%.0f%% %s" % [b_val * 100.0, b_type.to_upper()]
			for ba in buff_allies:
				if ba.is_alive():
					var applied := _apply_buff_capped(ba, {"id": skill.get("name", "buff"), "duration": b_dur, "type": b_type, "value": b_val}, state)
					if applied:
						buff_count += 1
						state.action_log.append({"action": "buff", "unit": ba.id, "side": side_str, "slot": ba.slot, "buff_type": "%s_up" % b_type, "desc": "%s 获得 %s 增益 (%s, %d回合)" % [ba.troop_id, skill.get("name", "技能"), b_label, b_dur]})
			return {"action": "skill", "unit": unit.id, "side": side_str, "slot": unit.slot, "skill_name": skill.get("name", "技能"), "buffed_count": buff_count, "desc": "%s 发动 %s，为 %d 友军施加增益" % [unit.troop_id, skill.get("name", "技能"), buff_count]}
		"debuff":
			# v11.0: Data-driven debuff — reads type/value/dur from skill definition
			var debuff_targets := _get_enemies(unit, state)
			var debuff_count := 0
			var db_type: String = skill.get("buff_type", "def")
			var db_val: float   = skill.get("buff_value", -0.20)
			var db_dur: int     = skill.get("buff_dur", 2)
			var db_label: String = "%.0f%% %s" % [db_val * 100.0, db_type.to_upper()]
			for dt in debuff_targets:
				if dt.is_alive():
					var applied := _apply_buff_capped(dt, {"id": skill.get("name", "debuff"), "duration": db_dur, "type": db_type, "value": db_val}, state)
					if applied:
						debuff_count += 1
						state.action_log.append({"action": "debuff", "unit": dt.id, "side": "attacker" if dt.is_attacker else "defender", "slot": dt.slot, "debuff_type": "%s_down" % db_type, "desc": "%s 被 %s 削弱 (%s, %d回合)" % [dt.troop_id, skill.get("name", "技能"), db_label, db_dur]})
			return {"action": "skill", "unit": unit.id, "side": side_str, "slot": unit.slot, "skill_name": skill.get("name", "技能"), "debuffed_count": debuff_count, "desc": "%s 发动 %s，为 %d 敌军施加减益" % [unit.troop_id, skill.get("name", "技能"), debuff_count]}
		"cleanse":
			# v11.0: Cleanse — remove all debuffs from allies and heal a small amount
			var cleanse_allies := state.attacker_units if unit.is_attacker else state.defender_units
			var cleansed_count := 0
			var heal_pct: float = skill.get("heal_pct", 0.10)
			for ca in cleanse_allies:
				if not ca.is_alive(): continue
				var before_count := ca.active_buffs.size()
				ca.active_buffs = ca.active_buffs.filter(func(b): return b.get("value", 0.0) >= 0.0)
				if ca.active_buffs.size() < before_count: cleansed_count += 1
				var heal_amt := int(float(ca.max_soldiers) * heal_pct)
				ca.hp = mini(ca.max_hp, ca.hp + heal_amt * ca.hp_per_soldier)
				_recalc_soldiers(ca)
				state.action_log.append({"action": "heal", "unit": ca.id, "side": side_str, "slot": ca.slot, "healed": heal_amt, "remaining_soldiers": ca.soldiers, "max_soldiers": ca.max_soldiers, "desc": "%s 被净化并回复 %d 兵" % [ca.troop_id, heal_amt]})
			return {"action": "skill", "unit": unit.id, "side": side_str, "slot": unit.slot, "skill_name": skill.get("name", "技能"), "desc": "%s 发动 %s，净化 %d 友军" % [unit.troop_id, skill.get("name", "技能"), cleansed_count]}
		"multi":
			# v11.0: Multi-hit — attacks a single target N times for reduced damage each
			var multi_targets := _get_enemies(unit, state)
			if multi_targets.is_empty(): return {"action": "idle", "unit": unit.id}
			var multi_target := multi_targets[randi() % multi_targets.size()]
			var hit_count: int = skill.get("hit_count", 3)
			var total_multi_dmg := 0
			for _h in range(hit_count):
				if not multi_target.is_alive(): break
				var h_dmg_ex := _calculate_damage_ex(unit, multi_target, state, skill.get("damage_mult", 0.7))
				var h_dmg: int = h_dmg_ex["soldiers"]
				var h_old := multi_target.soldiers
				multi_target.hp = maxi(0, multi_target.hp - h_dmg * multi_target.hp_per_soldier)
				_recalc_soldiers(multi_target)
				total_multi_dmg += h_old - multi_target.soldiers
				state.action_log.append({"action": "skill_hit", "unit": unit.id, "side": side_str, "slot": unit.slot, "skill_name": skill.get("name", "技能"), "target": multi_target.id, "damage": h_old - multi_target.soldiers, "remaining_soldiers": multi_target.soldiers, "is_crit": h_dmg_ex["is_crit"], "desc": "%s 连击命中 %s" % [unit.troop_id, multi_target.troop_id]})
			if not multi_target.is_alive():
				state.action_log.append({"action": "death", "unit": multi_target.id, "side": "attacker" if multi_target.is_attacker else "defender", "slot": multi_target.slot, "round": state.round_number, "desc": "%s 被连击歼灭!" % multi_target.troop_id})
				_apply_ally_death_morale(multi_target, state)
				_revalidate_formations_for_side(multi_target, state)
			return {"action": "skill", "unit": unit.id, "side": side_str, "slot": unit.slot, "skill_name": skill.get("name", "技能"), "damage": total_multi_dmg, "hit_count": hit_count, "desc": "%s 发动 %s，%d连击共造成 %d 伤害" % [unit.troop_id, skill.get("name", "技能"), hit_count, total_multi_dmg]}
		"summon":
			# Summon: restore 10% max soldiers to the most injured ally
			var summon_allies := state.attacker_units if unit.is_attacker else state.defender_units
			var summon_target: BattleUnit = null
			var summon_min_ratio := 1.1
			for sa in summon_allies:
				if sa.is_alive() and sa.soldiers < sa.max_soldiers:
					var r := float(sa.soldiers) / float(sa.max_soldiers)
					if r < summon_min_ratio: summon_min_ratio = r; summon_target = sa
			if summon_target:
				var summon_amt := int(float(summon_target.max_soldiers) * 0.10)
				summon_target.hp = mini(summon_target.max_hp, summon_target.hp + summon_amt * summon_target.hp_per_soldier)
				_recalc_soldiers(summon_target)
				state.action_log.append({"action": "summon", "unit": unit.id, "side": side_str, "slot": unit.slot, "skill_name": skill.get("name", "技能"), "target": summon_target.id, "summoned": summon_amt, "remaining_soldiers": summon_target.soldiers, "max_soldiers": summon_target.max_soldiers, "desc": "%s 发动 %s，召唤增援 +%d兵" % [unit.troop_id, skill.get("name", "技能"), summon_amt]})
			return {"action": "skill", "unit": unit.id, "side": side_str, "slot": unit.slot, "skill_name": skill.get("name", "技能"), "desc": "%s 发动 %s" % [unit.troop_id, skill.get("name", "技能")]}
	return {"action": "skill", "unit": unit.id, "skill_name": skill.get("name", "技能")}

func _resolve_counter_attack(defender: BattleUnit, attacker: BattleUnit, state: BattleState) -> void:
	var counter_mult := 0.5
	if defender.has_passive("counter_bonus"): counter_mult = 0.8
	var counter_dmg := _calculate_damage(defender, attacker, state, counter_mult)
	var old_soldiers := attacker.soldiers
	attacker.hp = maxi(0, attacker.hp - counter_dmg * attacker.hp_per_soldier)
	_recalc_soldiers(attacker)
	var actual_lost := old_soldiers - attacker.soldiers
	if actual_lost > 0:
		state.action_log.append({"action": "counter", "unit": defender.id, "side": "attacker" if defender.is_attacker else "defender", "slot": defender.slot, "target": attacker.id, "damage": actual_lost, "desc": "%s 反击造成 %d 伤害" % [defender.troop_id, actual_lost]})
		if attacker.soldiers <= 0:
			state.action_log.append({"action": "death", "unit": attacker.id, "side": "attacker" if attacker.is_attacker else "defender", "slot": attacker.slot, "desc": "%s 被反击歼灭!" % attacker.troop_id})
			_apply_ally_death_morale(attacker, state)
			_revalidate_formations_for_side(attacker, state)

func _apply_poison(attacker: BattleUnit, defender: BattleUnit, state: BattleState) -> void:
	if not defender.has_passive("poisoned_2"):
		defender.passive = defender.passive + ("," if defender.passive != "" else "") + "poisoned_2"
		state.action_log.append({"action": "passive", "event": "poison_attack", "unit": attacker.id, "side": "attacker" if attacker.is_attacker else "defender", "slot": attacker.slot, "target": defender.id, "target_side": "attacker" if defender.is_attacker else "defender", "desc": "%s 毒击! %s 中毒(2回合)" % [attacker.troop_id, defender.troop_id]})
		state.action_log.append({"action": "debuff", "side": "attacker" if defender.is_attacker else "defender", "slot": defender.slot, "debuff_type": "poison", "desc": "%s 中毒!" % defender.troop_id})

# ---------------------------------------------------------------------------
# Battle End Check
# ---------------------------------------------------------------------------

func _check_battle_end(state: BattleState) -> String:
	if state.total_attacker_soldiers() <= 0: return "defender"
	if state.total_defender_soldiers() <= 0: return "attacker"
	var atk_all_routed := true
	for u in state.attacker_units:
		if u.is_alive() and not u.is_routed: atk_all_routed = false; break
	if atk_all_routed and state.total_attacker_soldiers() > 0: return "defender"
	var def_all_routed := true
	for u in state.defender_units:
		if u.is_alive() and not u.is_routed: def_all_routed = false; break
	if def_all_routed and state.total_defender_soldiers() > 0: return "attacker"
	return ""

# ---------------------------------------------------------------------------
# Morale System
# ---------------------------------------------------------------------------

func _reduce_morale(unit: BattleUnit, amount: int, state: BattleState) -> void:
	if unit.is_routed or not unit.is_alive(): return
	var old_morale: int = unit.morale
	unit.morale = maxi(0, unit.morale - amount)
	EventBus.unit_morale_changed.emit(unit.troop_id, "attacker" if unit.is_attacker else "defender", unit.morale)
	if unit.morale > 0 and unit.morale <= 50 and old_morale > 50:
		state.action_log.append({"action": "morale", "side": "attacker" if unit.is_attacker else "defender", "slot": unit.slot, "morale_type": "waver", "desc": "%s 士气动摇! (%d)" % [unit.troop_id, unit.morale]})
	if unit.morale <= 0: _rout_unit(unit, state)

func _rout_unit(unit: BattleUnit, state: BattleState) -> void:
	unit.is_routed = true
	var loss: int = int(ceil(float(unit.soldiers) * 0.30))
	unit.hp = maxi(0, unit.hp - loss * unit.hp_per_soldier)
	_recalc_soldiers(unit)
	var side_str: String = "attacker" if unit.is_attacker else "defender"
	state.action_log.append({"action": "rout", "unit": unit.id, "side": side_str, "slot": unit.slot, "soldiers_lost": loss, "remaining_soldiers": unit.soldiers, "round": state.round_number, "desc": "%s 士气崩溃，溃败！损失%d兵" % [unit.troop_id, loss]})
	state.action_log.append({"action": "morale", "side": side_str, "slot": unit.slot, "morale_type": "rout", "desc": "%s 溃败!" % unit.troop_id})
	EventBus.unit_routed.emit(unit.troop_id, side_str)
	var allies: Array[BattleUnit] = state.attacker_units if unit.is_attacker else state.defender_units
	for u in allies:
		if u == unit or not u.is_alive() or u.is_routed: continue
		_reduce_morale(u, 10 if u.row == unit.row else 5, state)

func _apply_kill_morale_boost(killer: BattleUnit, dead_unit: BattleUnit, state: BattleState) -> void:
	var allies: Array[BattleUnit] = state.attacker_units if killer.is_attacker else state.defender_units
	var boost: int = 10 if dead_unit.hero_id != "" else 5
	for u in allies:
		if u == killer or not u.is_alive() or u.is_routed: continue
		u.morale = mini(100, u.morale + boost)
		EventBus.unit_morale_changed.emit(u.troop_id, "attacker" if u.is_attacker else "defender", u.morale)
	state.action_log.append({"action": "morale", "side": "attacker" if killer.is_attacker else "defender", "slot": killer.slot, "morale_type": "rally", "source": "kill", "boost": boost, "desc": "%s 歼灭敌军，我方士气提升+%d!" % [killer.troop_id, boost]})

func _apply_ally_death_morale(dead_unit: BattleUnit, state: BattleState) -> void:
	var allies: Array[BattleUnit] = state.attacker_units if dead_unit.is_attacker else state.defender_units
	var total_units: int = allies.size()
	var dead_count: int = 0
	for u in allies:
		if not u.is_alive(): dead_count += 1
	var base_loss: int = 15
	# v10.2: Morale Resilience — elite units reduce morale loss
	if dead_unit.xp >= BalanceConfig.ELITE_EXP_THRESHOLD: base_loss = maxi(5, base_loss - 5)
	# v4.3: Escalating morale loss when heavy casualties
	if total_units > 0 and float(dead_count) / float(total_units) >= 0.5: base_loss = 25
	for u in allies:
		if u == dead_unit or not u.is_alive() or u.is_routed: continue
		_reduce_morale(u, base_loss, state)

func _apply_kill_heal(killer: BattleUnit, state: BattleState) -> void:
	var heal_soldiers: int = 0
	if killer.has_passive("kill_heal_2"): heal_soldiers = 2
	elif killer.has_passive("kill_heal"): heal_soldiers = 1
	if heal_soldiers == 0 or not killer.is_alive() or killer.hp >= killer.max_hp: return
	var heal: int = killer.hp_per_soldier * heal_soldiers
	killer.hp = mini(killer.hp + heal, killer.max_hp)
	_recalc_soldiers(killer)
	state.action_log.append({"action": "passive", "event": "kill_heal", "unit": killer.id, "side": "attacker" if killer.is_attacker else "defender", "slot": killer.slot, "healed": heal_soldiers, "desc": "%s 击杀回复 +%d兵" % [killer.troop_id, heal_soldiers]})

# ---------------------------------------------------------------------------
# Passive & Round Start Logic
# ---------------------------------------------------------------------------

func _apply_round_start_passives(state: BattleState) -> void:
	for u in state.attacker_units + state.defender_units:
		if not u.is_alive(): continue
		var regen_amt := 0
		if u.has_passive("deep_regen"): regen_amt = 2
		elif u.has_passive("regen_1"): regen_amt = 1
		if regen_amt > 0 and u.soldiers < u.max_soldiers:
			u.hp = mini(u.max_hp, u.hp + regen_amt * u.hp_per_soldier)
			_recalc_soldiers(u)
			state.action_log.append({"action": "heal", "unit": u.id, "side": "attacker" if u.is_attacker else "defender", "slot": u.slot, "healed": regen_amt, "desc": "%s 再生 +%d兵" % [u.troop_id, regen_amt]})
		if u.has_passive("poisoned_2"):
			var poison_dmg := 1 * u.hp_per_soldier
			u.hp = maxi(0, u.hp - poison_dmg)
			_recalc_soldiers(u)
			state.action_log.append({"action": "damage", "unit": u.id, "side": "attacker" if u.is_attacker else "defender", "slot": u.slot, "damage": 1, "desc": "%s 毒发损失 1兵" % u.troop_id})
			if not u.is_alive():
				state.action_log.append({"action": "death", "unit": u.id, "side": "attacker" if u.is_attacker else "defender", "slot": u.slot, "desc": "%s 毒发身亡!" % u.troop_id})
				_apply_ally_death_morale(u, state)
				_revalidate_formations_for_side(u, state)

func _apply_terrain_modifiers(state: BattleState) -> void:
	var tdata: Dictionary = FactionData.TERRAIN_DATA.get(state.terrain, {})
	var atk_mult: float = tdata.get("atk_mult", 1.0)
	var spd_mult: float = tdata.get("spd_mult", 1.0)
	if atk_mult != 1.0 or spd_mult != 1.0:
		for u in state.attacker_units + state.defender_units:
			u.atk = int(float(u.atk) * atk_mult)
			u.spd = int(float(u.spd) * spd_mult)

# ---------------------------------------------------------------------------
# v10.2: Persistent Buff System
# ---------------------------------------------------------------------------

func _tick_buff_durations(state: BattleState) -> void:
	for u in state.attacker_units + state.defender_units:
		var remaining: Array = []
		for b in u.active_buffs:
			b["duration"] -= 1
			if b["duration"] > 0:
				remaining.append(b)
			else:
				state.action_log.append({"action": "buff_expire", "unit": u.id, "buff_id": b.get("id", "buff"), "desc": "%s 的 %s 效果消失" % [u.troop_id, b.get("id", "buff")]})
		u.active_buffs = remaining

## v11.0: Apply a buff with stack-cap enforcement.
## Prevents more than MAX_BUFF_STACKS of the same buff_id on a single unit.
func _apply_buff_capped(unit: BattleUnit, buff: Dictionary, state: BattleState) -> bool:
	var bid: String = buff.get("id", "")
	if bid != "" and unit.count_buff_stacks(bid) >= MAX_BUFF_STACKS:
		return false  # Stack cap reached
	unit.active_buffs.append(buff)
	return true
# v10.6: Tick burn/slow debuffs from CombatAbilities on BattleUnit.active_buffs
func _tick_combat_abilities_debuffs(state: BattleState) -> void:
	for u in state.attacker_units + state.defender_units:
		if not u.is_alive(): continue
		var side_str: String = "attacker" if u.is_attacker else "defender"
		for b in u.active_buffs:
			var bid: String = b.get("id", "")
			# Burn debuff: -1 soldier per round
			if bid == "burn":
				var burn_dmg: int = b.get("value", 1)
				u.hp = maxi(0, u.hp - burn_dmg * u.hp_per_soldier)
				_recalc_soldiers(u)
				state.action_log.append({"action": "debuff_tick", "unit": u.id, "side": side_str, "slot": u.slot, "debuff": "burn", "damage": burn_dmg, "remaining_soldiers": u.soldiers, "desc": "%s 灼烧 -%d兵" % [u.troop_id, burn_dmg]})
				if not u.is_alive():
					state.action_log.append({"action": "death", "unit": u.id, "side": side_str, "slot": u.slot, "round": state.round_number, "desc": "%s 被灼烧消灭" % u.troop_id})
					_apply_ally_death_morale(u, state)
					_revalidate_formations_for_side(u, state)
					break
			# Slow debuff: reduce SPD (applied once via _applied flag)
			elif bid == "slow" and not b.get("_applied", false):
				u.spd = maxf(u.spd - 2.0, 1.0)
				b["_applied"] = true
				state.action_log.append({"action": "debuff_tick", "unit": u.id, "side": side_str, "slot": u.slot, "debuff": "slow", "desc": "%s 被减速 SPD-2" % u.troop_id})
# ---------------------------------------------------------------------------
# Hero Skill Logic (v6.0)
# ---------------------------------------------------------------------------

func _tick_hero_skills(state: BattleState) -> void:
	for u in state.attacker_units:
		if u.is_alive() and not u.hero_id.is_empty(): HeroSkillsAdvanced.tick_charge(u.hero_id)
	for u in state.defender_units:
		if u.is_alive() and not u.hero_id.is_empty(): HeroSkillsAdvanced.tick_charge(u.hero_id)

	for u in state.attacker_units + state.defender_units:
		if not u.is_alive() or u.hero_id.is_empty(): continue
		var hid: String = u.hero_id
		var side: String = "attacker" if u.is_attacker else "defender"

		if not HeroSkillsAdvanced.is_awakened(hid):
			var hp_ratio := float(u.soldiers) / float(u.max_soldiers)
			if HeroSkillsAdvanced.check_awakening(hid, hp_ratio):
				var awk: Dictionary = HeroSkillsAdvanced.trigger_awakening(hid)
				if not awk.is_empty():
					u.set_meta("pre_awaken_atk", u.atk)
					u.set_meta("pre_awaken_def", u.def_stat)
					u.set_meta("pre_awaken_spd", u.spd)
					u.atk = int(float(u.atk) * awk.get("atk_mult", 1.0))
					u.def_stat = int(float(u.def_stat) * awk.get("def_mult", 1.0))
					u.spd = int(float(u.spd) * awk.get("spd_mult", 1.0))
					state.action_log.append({"action": "awakening", "hero_id": hid, "side": side, "slot": u.slot, "desc": "%s — %s!" % [u.troop_id, awk.get("name", "觉醒")]})

		if HeroSkillsAdvanced.is_awakened(hid):
			if not HeroSkillsAdvanced.tick_awakening(hid):
				if u.has_meta("pre_awaken_atk"):
					u.atk = u.get_meta("pre_awaken_atk")
					u.def_stat = u.get_meta("pre_awaken_def")
					u.spd = u.get_meta("pre_awaken_spd")

		if HeroSkillsAdvanced.is_charged(hid):
			var battle_dict: Dictionary = _state_to_resolver_dict(state)
			var ult_result: Dictionary = HeroSkillsAdvanced.execute_ultimate(hid, battle_dict)
			if ult_result.get("ok", false):
				ult_result["hero_id"] = hid
				_apply_ultimate_damage(state, ult_result, side)
				state.action_log.append({"action": "ultimate", "hero_id": hid, "side": side, "slot": u.slot, "desc": "%s 发动 %s!" % [u.troop_id, ult_result.get("name", "必杀技")], "damage": ult_result.get("total_damage", 0)})
				var ult_skill: Dictionary = HeroSkillsAdvanced.ultimate_skills.get(hid, {})
				var ult_effect: String = ult_skill.get("effect", "")
				if ult_effect == "buff_all":
					var allies: Array[BattleUnit] = state.attacker_units if side == "attacker" else state.defender_units
					for si in range(allies.size()):
						if allies[si].is_alive(): state.action_log.append({"action": "buff", "side": side, "slot": si, "buff_type": "team_buff", "desc": "全体增益!"})
				elif ult_effect == "heal_all":
					var allies: Array[BattleUnit] = state.attacker_units if side == "attacker" else state.defender_units
					for si in range(allies.size()):
						if allies[si].is_alive(): state.action_log.append({"action": "heal", "side": side, "slot": si, "is_mass": true, "desc": "全体治疗!"})
				elif ult_effect == "aoe_damage_freeze":
					var enemy_side: String = "defender" if side == "attacker" else "attacker"
					var enemies: Array[BattleUnit] = state.defender_units if side == "attacker" else state.attacker_units
					for si in range(enemies.size()):
						if enemies[si].is_alive(): state.action_log.append({"action": "debuff", "side": enemy_side, "slot": si, "debuff_type": "freeze", "desc": "冻结!"})

	# Combo skills
	for _combo_side in [["attacker", state.attacker_units], ["defender", state.defender_units]]:
		var _side_str: String = _combo_side[0]
		var _side_units: Array[BattleUnit] = _combo_side[1]
		var army_heroes: Array = []
		for u2 in _side_units:
			if u2.is_alive() and not u2.hero_id.is_empty(): army_heroes.append(u2.hero_id)
		if not army_heroes.is_empty():
			HeroSkillsAdvanced.tick_combo_charges(army_heroes)
			var available_combos: Array = HeroSkillsAdvanced.check_available_combos(army_heroes)
			for combo_info in available_combos:
				if combo_info.get("charged", false):
					var cid: int = combo_info.get("combo_id", -1)
					var combo_result: Dictionary = HeroSkillsAdvanced.execute_combo(cid, _state_to_resolver_dict(state))
					if combo_result.get("ok", false):
						_apply_ultimate_damage(state, combo_result, _side_str)
						state.action_log.append({"action": "combo", "combo_index": cid, "combo_name": combo_result.get("name", ""), "side": _side_str, "slot": 0, "desc": "连携技 %s 发动!" % combo_result.get("name", ""), "damage": combo_result.get("total_damage", 0)})

func _apply_ultimate_damage(state: BattleState, ult_result: Dictionary, caster_side: String) -> void:
	var targets_hit: Array = ult_result.get("targets_hit", [])
	var enemy_units: Array[BattleUnit] = state.defender_units if caster_side == "attacker" else state.attacker_units
	var ally_units: Array[BattleUnit] = state.attacker_units if caster_side == "attacker" else state.defender_units
	var enemy_side: String = "defender" if caster_side == "attacker" else "attacker"

	var _ult_living: Array[BattleUnit] = []
	for eu in enemy_units:
		if eu.is_alive(): _ult_living.append(eu)
	_ult_living.shuffle()
	var _ult_hit_idx: int = 0
	var total_dmg_dealt: int = 0

	for hit in targets_hit:
		var dmg: int = hit.get("damage", 0)
		var healed: int = hit.get("healed", 0)
		if dmg > 0:
			if _ult_hit_idx >= _ult_living.size():
				_ult_living.clear()
				for eu in enemy_units:
					if eu.is_alive(): _ult_living.append(eu)
				_ult_living.shuffle()
				_ult_hit_idx = 0
			if not _ult_living.is_empty():
				var target: BattleUnit = _ult_living[_ult_hit_idx]
				_ult_hit_idx += 1
				var hp_dmg: int = dmg * target.hp_per_soldier
				var was_alive: bool = target.is_alive()
				# v10.0: magic_damage_resist (Clash)
				var clashes: Dictionary = FormationSystem.check_formation_clash(state.atk_formations, state.def_formations)
				var clash_key: String = "arcane_vs_holy_def" if caster_side == "attacker" else "arcane_vs_holy_atk"
				if clashes.has(clash_key):
					var resist: float = clashes[clash_key].get("magic_damage_resist", 0.0)
					if resist > 0: hp_dmg = int(float(hp_dmg) * (1.0 - resist))
				target.hp = maxi(0, target.hp - hp_dmg)
				var old_soldiers: int = target.soldiers
				_recalc_soldiers(target)
				var actual_lost: int = old_soldiers - target.soldiers
				total_dmg_dealt += actual_lost
				if was_alive and not target.is_alive():
					state.action_log.append({"action": "death", "unit": target.id, "side": enemy_side, "slot": target.slot, "round": state.round_number, "desc": "%s 被必杀技歼灭" % target.troop_id})
					_apply_ally_death_morale(target, state)
					_revalidate_formations_for_side(target, state)
		elif healed > 0:
			for au in ally_units:
				if au.is_alive() and au.soldiers < au.max_soldiers:
					au.hp = mini(au.hp + healed * au.hp_per_soldier, au.max_hp)
					_recalc_soldiers(au)
					state.action_log.append({"action": "heal", "unit": au.id, "side": caster_side, "slot": au.slot, "healed": healed, "remaining_soldiers": au.soldiers, "max_soldiers": au.max_soldiers, "desc": "%s 恢复了 %d 兵力" % [au.troop_id, healed]})
		# v10.5: Sync buff_all ultimate buffs from battle_dict back to BattleUnit.active_buffs
		var buffed: bool = hit.get("buffed", false)
		if buffed:
			# The buff was written into battle_dict ally units; find matching BattleUnit by slot order
			for ai in range(ally_units.size()):
				var au: BattleUnit = ally_units[ai]
				if au.is_alive():
					# Sync any new buffs from battle_dict that aren't already in active_buffs
					var dict_units: Array = targets_hit  # use ult_result reference below
					break  # handled via post-loop sync below
	# v10.5: Post-loop: sync battle_dict buffs/debuffs back to BattleUnit.active_buffs
	var battle_dict_ref: Dictionary = _state_to_resolver_dict(state)
	var ally_dict_units: Array = battle_dict_ref.get("atk_units" if caster_side == "attacker" else "def_units", [])
	for ai in range(mini(ally_units.size(), ally_dict_units.size())):
		var au: BattleUnit = ally_units[ai]
		var ad: Dictionary = ally_dict_units[ai]
		var dict_buffs: Array = ad.get("buffs", [])
		for db in dict_buffs:
			var already_has := false
			for existing in au.active_buffs:
				if existing.get("id", "") == db.get("id", ""):
					already_has = true; break
			if not already_has and db.has("id"):
				au.active_buffs.append(db)
				state.action_log.append({"action": "buff", "unit": au.id, "side": caster_side, "slot": au.slot, "buff_type": db.get("id", "buff"), "desc": "%s 获得必杀技增益: %s" % [au.troop_id, db.get("id", "buff")]})
	# v10.5: Sync aoe_damage_freeze debuffs from battle_dict enemy units back to BattleUnit.active_buffs
	var enemy_dict_units: Array = battle_dict_ref.get("def_units" if caster_side == "attacker" else "atk_units", [])
	for ei in range(mini(enemy_units.size(), enemy_dict_units.size())):
		var eu: BattleUnit = enemy_units[ei]
		var ed: Dictionary = enemy_dict_units[ei]
		var dict_debuffs: Array = ed.get("debuffs", [])
		for dd in dict_debuffs:
			var already_has := false
			for existing in eu.active_buffs:
				if existing.get("id", "") == dd.get("id", ""):
					already_has = true; break
			if not already_has and dd.has("id"):
				eu.active_buffs.append(dd)
				state.action_log.append({"action": "debuff", "unit": eu.id, "side": enemy_side, "slot": eu.slot, "debuff_type": dd.get("id", "debuff"), "desc": "%s 被施加 %s" % [eu.troop_id, dd.get("id", "debuff")]})

	# v10.0: drain_damage heal sync
	if total_dmg_dealt > 0:
		var ult_skill: Dictionary = HeroSkillsAdvanced.ultimate_skills.get(ult_result.get("hero_id", ""), {})
		if ult_skill.get("effect", "") == "drain_damage":
			var heal_per_unit: int = maxi(1, int(float(total_dmg_dealt) / float(maxi(1, ally_units.size()))))
			for au in ally_units:
				if au.is_alive() and au.soldiers < au.max_soldiers:
					var actual_heal: int = mini(heal_per_unit, au.max_soldiers - au.soldiers)
					au.hp = mini(au.max_hp, au.hp + actual_heal * au.hp_per_soldier)
					_recalc_soldiers(au)
					state.action_log.append({"action": "heal", "unit": au.id, "side": caster_side, "slot": au.slot, "healed": actual_heal, "remaining_soldiers": au.soldiers, "max_soldiers": au.max_soldiers, "desc": "%s 灵魂吸取回复 +%d兵" % [au.troop_id, actual_heal]})

# ---------------------------------------------------------------------------
# Damage Calculation
# ---------------------------------------------------------------------------

## v11.0: Extended damage calculation with crit, hit/dodge, and combo bonus.
## Returns a Dictionary: {"soldiers": int, "is_crit": bool, "is_miss": bool}
func _calculate_damage_ex(attacker: BattleUnit, defender: BattleUnit, state: BattleState, skill_mult: float = 1.0, guaranteed_crit: bool = false) -> Dictionary:
	var base := _calculate_damage(attacker, defender, state, skill_mult)
	# ── Hit/Dodge check ──
	var hit_chance := BASE_HIT_CHANCE
	if attacker.has_passive("precision"): hit_chance = minf(hit_chance + 0.10, 1.0)
	if defender.has_passive("evasion"):   hit_chance = maxf(hit_chance - 0.12, 0.30)
	if randf() > hit_chance:
		_battle_stats["total_misses"] += 1
		return {"soldiers": 0, "is_crit": false, "is_miss": true}
	# ── Critical hit check ──
	var crit_chance := BASE_CRIT_CHANCE
	if attacker.has_passive("crit_boost"): crit_chance += 0.10
	if attacker.morale >= 80: crit_chance += 0.05
	var is_crit := guaranteed_crit or (randf() < crit_chance)
	if is_crit:
		base = int(float(base) * CRIT_DAMAGE_MULT)
		_battle_stats["total_crits"] += 1
	if base > _battle_stats["max_single_hit"]: _battle_stats["max_single_hit"] = base
	return {"soldiers": base, "is_crit": is_crit, "is_miss": false}

func _calculate_damage(attacker: BattleUnit, defender: BattleUnit, state: BattleState, skill_mult: float = 1.0) -> int:
	# v10.2: Apply Buff Multipliers to ATK and DEF
	var atk_val: int = int(float(attacker.atk) * attacker.get_stat_mult("atk"))
	var def_val: int = int(float(defender.def_stat) * defender.get_stat_mult("def"))
	# v10.6: CombatAbilities morale modifier — 50 morale = 1.0x, 0 = 0.6x, 100 = 1.15x
	var morale_mult: float = clampf(0.6 + float(attacker.morale) * 0.008, 0.6, 1.15)
	atk_val = int(float(atk_val) * morale_mult)
	# v10.6: EnvironmentSystem time-of-day modifiers
	if _has_autoload("EnvironmentSystem"):
		var env: Node = _get_autoload("EnvironmentSystem")
		if env != null and env.has_method("get_time_combat_modifiers"):
			var time_mods: Dictionary = env.get_time_combat_modifiers()
			# Assassin night ATK bonus
			var assassin_bonus: int = time_mods.get("assassin_atk_bonus", 0)
			if assassin_bonus != 0 and attacker.has_passive("assassin"):
				atk_val += assassin_bonus
			# Ranged accuracy modifier (affects ranged units)
			var ranged_acc: float = time_mods.get("ranged_accuracy_mod", 0.0)
			if ranged_acc != 0.0 and FormationSystem._is_ranged({"troop_id": attacker.troop_id}):
				atk_val = int(float(atk_val) * (1.0 + ranged_acc))
			# Undead ATK bonus
			var undead_bonus: int = time_mods.get("undead_atk_bonus", 0)
			if undead_bonus != 0 and attacker.has_passive("undead"):
				atk_val += undead_bonus
	# v10.6: SupplySystem combat modifiers (applied to attacker side only)
	if _has_autoload("SupplySystem"):
		var ss: Node = _get_autoload("SupplySystem")
		if ss != null and ss.has_method("get_combat_modifiers_for_army"):
			var army_id: int = state.attacker_army_id if attacker.is_attacker else state.defender_army_id
			if army_id >= 0:
				var supply_mods: Dictionary = ss.get_combat_modifiers_for_army(army_id)
				var atk_mod: float = supply_mods.get("atk_mod", 0.0)
				var def_mod_s: float = supply_mods.get("def_mod", 0.0)
				if atk_mod != 0.0: atk_val = int(float(atk_val) * (1.0 + atk_mod))
				if def_mod_s != 0.0: def_val = int(float(def_val) * (1.0 + def_mod_s))

	if defender.has_passive("fort_def_3") and not defender.is_attacker: def_val += 3

	var tdata_dmg: Dictionary = FactionData.TERRAIN_DATA.get(state.terrain, {})
	if not defender.is_attacker:
		def_val = int(float(def_val) * tdata_dmg.get("def_mult", 1.0))

	var raw_diff: int = maxi(1, atk_val - def_val)

	var troops := float(attacker.soldiers)
	var adjusted: float
	if troops <= 8.0: adjusted = troops
	elif troops <= 15.0: adjusted = 8.0 + (troops - 8.0) * 0.5
	else: adjusted = 11.5 + (troops - 15.0) * 0.25

	var base_damage: float = adjusted * float(raw_diff) / 100.0

	var _counter: Dictionary = CounterMatrix.get_counter(attacker.troop_id, defender.troop_id)
	if _counter["atk_mult"] != 1.0:
		var counter_atk: float = _counter["atk_mult"]
		if attacker.has_passive("rps_bonus") and counter_atk > 1.0: counter_atk += 0.15
		base_damage *= counter_atk
	if _counter["def_mult"] != 1.0: base_damage *= _counter["def_mult"]

	if attacker.has_passive("light_slayer"):
		var def_troop: String = defender.troop_id.to_lower()
		if def_troop.begins_with("elf_") or def_troop.begins_with("knight_") or def_troop.begins_with("human_") or def_troop.begins_with("temple_") or def_troop.begins_with("priest") or def_troop.begins_with("treant") or def_troop.begins_with("alliance_"):
			base_damage *= 1.15

	if attacker.has_passive("blood_oath") and float(attacker.soldiers) < float(attacker.max_soldiers) * 0.5:
		base_damage *= 2.0

	if attacker.has_passive("desert_mastery") and state.terrain == Terrain.WASTELAND:
		base_damage *= 2.0

	if defender.row == 1:
		var enemy_units: Array[BattleUnit] = state.living_attackers() if defender.is_attacker else state.living_defenders()
		var has_front_cover: bool = false
		for eu in enemy_units:
			if eu.row == 0 and eu != defender: has_front_cover = true; break
		if not has_front_cover: base_damage *= 1.20

	# v10.0: shadow_ranged_dodge (Clash)
	if FormationSystem._is_ranged({"troop_id": attacker.troop_id}):
		var clashes: Dictionary = FormationSystem.check_formation_clash(state.atk_formations, state.def_formations)
		var clash_key: String = "arrow_vs_shadow_def" if attacker.is_attacker else "arrow_vs_shadow_atk"
		if clashes.has(clash_key):
			var dodge: float = clashes[clash_key].get("shadow_ranged_dodge", 0.0)
			if randf() < dodge:
				state.action_log.append({"action": "passive", "event": "shadow_dodge", "unit": defender.id, "side": "attacker" if defender.is_attacker else "defender", "slot": defender.slot, "desc": "%s 影袭闪避!" % defender.troop_id})
				return 0

	var final_damage: float = base_damage * skill_mult

	# v10.2: Minimum Damage Protection (at least 2% of attacker soldiers)
	var soldiers_killed_equiv: int = int(floor(final_damage))
	var min_dmg: int = maxi(1, int(ceil(float(attacker.soldiers) * 0.02)))
	return maxi(min_dmg, soldiers_killed_equiv)

# ---------------------------------------------------------------------------
# Formation Bonuses
# ---------------------------------------------------------------------------

func _consume_formation_bonuses(state: BattleState) -> void:
	var atk_bonuses: Dictionary = FormationSystem.get_formation_bonuses(state.atk_formations)
	var def_bonuses: Dictionary = FormationSystem.get_formation_bonuses(state.def_formations)
	var clashes: Dictionary = FormationSystem.check_formation_clash(state.atk_formations, state.def_formations)

	# 1) Cavalry Charge (Round 1)
	if state.round_number == 1:
		if atk_bonuses.get("cavalry_atk_mult_r1", 1.0) > 1.0:
			var negate: bool = clashes.get("iron_wall_vs_cavalry", {}).get("negate_cavalry_charge", false)
			if not negate:
				for u in state.attacker_units:
					if u.is_alive() and FormationSystem._is_cavalry({"troop_id": u.troop_id}):
						u.atk = int(float(u.atk) * atk_bonuses["cavalry_atk_mult_r1"])
		if def_bonuses.get("cavalry_atk_mult_r1", 1.0) > 1.0:
			var negate: bool = clashes.get("iron_wall_vs_cavalry", {}).get("negate_cavalry_charge", false)
			if not negate:
				for u in state.defender_units:
					if u.is_alive() and FormationSystem._is_cavalry({"troop_id": u.troop_id}):
						u.atk = int(float(u.atk) * def_bonuses["cavalry_atk_mult_r1"])

	# 2) Heal per round
	var atk_heal: int = atk_bonuses.get("heal_per_round", 0)
	if atk_heal > 0:
		for u in state.attacker_units:
			if u.is_alive() and u.soldiers < u.max_soldiers:
				u.hp = mini(u.max_hp, u.hp + atk_heal * u.hp_per_soldier)
				_recalc_soldiers(u)
				state.action_log.append({"action": "heal", "unit": u.id, "side": "attacker", "slot": u.slot, "healed": atk_heal, "remaining_soldiers": u.soldiers, "max_soldiers": u.max_soldiers, "desc": "阵型回复: %s +%d兵" % [u.troop_id, atk_heal]})
	var def_heal: int = def_bonuses.get("heal_per_round", 0)
	if def_heal > 0:
		for u in state.defender_units:
			if u.is_alive() and u.soldiers < u.max_soldiers:
				u.hp = mini(u.max_hp, u.hp + def_heal * u.hp_per_soldier)
				_recalc_soldiers(u)
				state.action_log.append({"action": "heal", "unit": u.id, "side": "defender", "slot": u.slot, "healed": def_heal, "remaining_soldiers": u.soldiers, "max_soldiers": u.max_soldiers, "desc": "阵型回复: %s +%d兵" % [u.troop_id, def_heal]})

# ---------------------------------------------------------------------------
# State Serialization
# ---------------------------------------------------------------------------

func _state_to_resolver_dict(state: BattleState) -> Dictionary:
	var atk_units: Array = []
	for u in state.attacker_units:
		atk_units.append({"hero_id": u.hero_id, "unit_type": u.troop_id, "soldiers": u.soldiers, "max_soldiers": u.max_soldiers, "atk": u.atk, "def": u.def_stat, "mana": u.mana, "morale": u.morale, "is_routed": u.is_routed, "is_alive": u.is_alive(), "side": "attacker", "slot": u.slot, "row": "front" if u.row == 0 else "back", "buffs": u.active_buffs})
	var def_units: Array = []
	for u in state.defender_units:
		def_units.append({"hero_id": u.hero_id, "unit_type": u.troop_id, "soldiers": u.soldiers, "max_soldiers": u.max_soldiers, "atk": u.atk, "def": u.def_stat, "mana": u.mana, "morale": u.morale, "is_routed": u.is_routed, "is_alive": u.is_alive(), "side": "defender", "slot": u.slot, "row": "front" if u.row == 0 else "back", "buffs": u.active_buffs})
	return {"atk_units": atk_units, "def_units": def_units, "round": state.round_number, "atk_mana": state.mana_attacker, "def_mana": state.mana_defender}

func _build_intervention_state(state: BattleState) -> Dictionary:
	var res := _state_to_resolver_dict(state)
	res["is_siege"] = state.is_siege
	res["city_def"] = state.city_def
	return res

func _apply_intervention_results(state: BattleState, istate: Dictionary) -> void:
	for i in range(state.attacker_units.size()):
		var u := state.attacker_units[i]
		var d: Dictionary = istate["atk_units"][i]
		u.soldiers = d["soldiers"]
		u.hp = u.soldiers * u.hp_per_soldier
		u.morale = d.get("morale", u.morale)
		u.is_routed = d.get("is_routed", u.is_routed)
		u.row = 0 if d.get("row", "front") == "front" else 1
		u.slot = d.get("slot", u.slot)
		u.active_buffs = d.get("buffs", [])
	for i in range(state.defender_units.size()):
		var u := state.defender_units[i]
		var d: Dictionary = istate["def_units"][i]
		u.soldiers = d["soldiers"]
		u.hp = u.soldiers * u.hp_per_soldier
		u.morale = d.get("morale", u.morale)
		u.is_routed = d.get("is_routed", u.is_routed)
		u.row = 0 if d.get("row", "front") == "front" else 1
		u.slot = d.get("slot", u.slot)
		u.active_buffs = d.get("buffs", [])
	state.mana_attacker = istate.get("atk_mana", state.mana_attacker)
	state.mana_defender = istate.get("def_mana", state.mana_defender)
	state.city_def = istate.get("city_def", state.city_def)
	# v10.4: Sync forced_target and bait_target from CommanderIntervention
	if istate.has("forced_target") and istate.get("forced_target_duration", 0) > 0:
		state.action_log.append({"action": "intervention_effect", "effect": "forced_target", "target_slot": istate["forced_target"], "duration": istate.get("forced_target_duration", 1), "desc": "指挥官命令: 集火第 %d 号目标" % istate["forced_target"]})
		# Store on state for _execute_action to read
		state.set_meta("forced_target_slot", istate["forced_target"])
		state.set_meta("forced_target_duration", istate.get("forced_target_duration", 1))
	if istate.has("bait_target") and istate.get("bait_duration", 0) > 0:
		state.action_log.append({"action": "intervention_effect", "effect": "bait_target", "target_slot": istate["bait_target"], "duration": istate.get("bait_duration", 1), "desc": "指挥官命令: 诱敌至第 %d 号位" % istate["bait_target"]})
		state.set_meta("bait_target_slot", istate["bait_target"])
		state.set_meta("bait_duration", istate.get("bait_duration", 1))

func _tick_intervention_durations(state: BattleState) -> void:
	if _has_autoload("CommanderIntervention"):
		var ci := _get_autoload("CommanderIntervention")
		if ci and ci.has_method("tick_durations"): ci.tick_durations()

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

## v11.0: Data-driven skill lookup — reads from SKILL_DATA registry.
## Falls back to generic damage skill for unknown names.
func _get_active_skill(unit: BattleUnit) -> Dictionary:
	var hdata: Dictionary = FactionData.HEROES.get(unit.hero_id, {})
	if hdata.is_empty(): return {}
	var skill_name: String = hdata.get("active", "")
	if skill_name == "": return {}
	if SKILL_DATA.has(skill_name):
		var entry: Dictionary = SKILL_DATA[skill_name].duplicate()
		entry["name"] = skill_name
		return entry
	# Fallback for unregistered skills
	return {"name": skill_name, "type": "damage", "mana_cost": 0, "cooldown": 3, "damage_mult": 1.5}

func _get_enemies(unit: BattleUnit, state: BattleState) -> Array[BattleUnit]:
	return state.living_defenders() if unit.is_attacker else state.living_attackers()

func _recalc_soldiers(unit: BattleUnit) -> void:
	if unit.hp <= 0: unit.soldiers = 0
	else: unit.soldiers = ceili(float(unit.hp) / maxf(1.0, float(unit.hp_per_soldier)))

func _has_autoload(aname: String) -> bool:
	var tree := Engine.get_main_loop()
	return tree is SceneTree and (tree as SceneTree).root.has_node(aname)

func _get_autoload(aname: String) -> Variant:
	var tree := Engine.get_main_loop()
	if tree is SceneTree and (tree as SceneTree).root.has_node(aname):
		return (tree as SceneTree).root.get_node(aname)
	return null

func _build_formation_dicts(units: Array[BattleUnit]) -> Array:
	var result: Array = []
	for u in units:
		if u.is_alive():
			result.append({"id": u.id, "troop_id": u.troop_id, "unit_type": u.troop_id, "row": u.row, "slot": u.slot, "atk": u.atk, "def": u.def_stat, "spd": u.spd, "soldiers": u.soldiers, "max_soldiers": u.max_soldiers})
	return result

func _sync_formation_to_battle_units(units: Array[BattleUnit], dicts: Array) -> void:
	var dict_map: Dictionary = {}
	for d in dicts: dict_map[d["id"]] = d
	for u in units:
		if not u.is_alive(): continue
		var d: Dictionary = dict_map.get(u.id, {})
		if d.is_empty(): continue
		u.atk = d.get("atk", u.atk)
		u.def_stat = d.get("def", u.def_stat)
		u.spd = d.get("spd", u.spd)

func _revalidate_formations_for_side(dead_unit: BattleUnit, state: BattleState) -> void:
	var is_atk: bool = dead_unit.is_attacker
	var side_units: Array[BattleUnit] = state.attacker_units if is_atk else state.defender_units
	var prev_formations: Array = state.atk_formations if is_atk else state.def_formations
	if prev_formations.is_empty(): return
	var living_dicts: Array = _build_formation_dicts(side_units)
	var result: Dictionary = FormationSystem.revalidate_formations(living_dicts, state.terrain_str, prev_formations)
	var lost: Array = result["lost"]
	if lost.is_empty(): return
	FormationSystem.revert_formation_bonuses(living_dicts, lost)
	_sync_formation_to_battle_units(side_units, living_dicts)
