## combat_system.gd — Optimized Battle Engine (v10.2)
## Handles turn-based combat, hero skills, formations, morale, and persistent buffs.
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")
const CounterMatrix = preload("res://systems/combat/counter_matrix.gd")
const FormationSystem = preload("res://systems/combat/formation_system.gd")
const BalanceConfig = preload("res://systems/combat/balance_config.gd")

# ---------------------------------------------------------------------------
# Constants & Enums
# ---------------------------------------------------------------------------

const MAX_ROUNDS := 8
const MAX_FRONT_SLOTS := 3
const MAX_BACK_SLOTS := 3

enum Terrain { PLAINS, FOREST, MOUNTAIN, WASTELAND, COASTAL, CITY }

# ---------------------------------------------------------------------------
# Classes
# ---------------------------------------------------------------------------

class BattleUnit:
	var id: String
	var commander_id: String
	var troop_id: String
	var atk: int
	var def_stat: int
	var spd: int
	var int_stat: int
	var soldiers: int
	var max_soldiers: int
	var row: int # 0: front, 1: back
	var slot: int # 0-2
	var passive: String
	var is_attacker: bool
	var mana: int = 0
	var xp: int = 0
	var morale: int = 100
	var is_routed: bool = false
	var has_acted: bool = false
	
	# HP System (v4.3)
	var hp: int
	var max_hp: int
	var hp_per_soldier: int = 10
	
	# Hero Link (v6.0)
	var hero_id: String = ""
	var hero_hp: int = 0
	var hero_max_hp: int = 0
	var hero_mp: int = 0
	var hero_max_mp: int = 0

	# v10.2: Persistent Buff System
	var active_buffs: Array = [] # Array of {id: String, duration: int, value: float, type: String}

	# v4.5: Transient flags
	var _death_resist_used: bool = false
	var _ghost_shield_active: bool = false

	func is_alive() -> bool:
		return soldiers > 0 and not is_routed

	func has_passive(pname: String) -> bool:
		return passive.find(pname) >= 0
	
	func get_stat_mult(stat_type: String) -> float:
		var mult := 1.0
		for b in active_buffs:
			if b.get("type", "") == stat_type:
				mult += b.get("value", 0.0)
		return mult

class BattleState:
	var attacker_units: Array[BattleUnit] = []
	var defender_units: Array[BattleUnit] = []
	var round_number: int = 1
	var action_log: Array = []
	var terrain: int = Terrain.PLAINS
	var is_siege: bool = false
	var city_def: int = 0
	var mana_attacker: int = 0
	var mana_defender: int = 0
	
	# Formation cache
	var atk_formations: Array = []
	var def_formations: Array = []

	func get_mana(is_attacker: bool) -> int:
		return mana_attacker if is_attacker else mana_defender
	
	func set_mana(is_attacker: bool, val: int) -> void:
		if is_attacker: mana_attacker = val
		else: mana_defender = val

	func living_attackers() -> Array[BattleUnit]:
		var res: Array[BattleUnit] = []
		for u in attacker_units:
			if u.is_alive(): res.append(u)
		return res

	func living_defenders() -> Array[BattleUnit]:
		var res: Array[BattleUnit] = []
		for u in defender_units:
			if u.is_alive(): res.append(u)
		return res

# ---------------------------------------------------------------------------
# Main Entry
# ---------------------------------------------------------------------------

var player_controlled: bool = false

func resolve_battle(attacker_army: Dictionary, defender_army: Dictionary, node_data: Dictionary) -> Dictionary:
	var state := BattleState.new()
	HeroSkillsAdvanced.reset_battle()

	state.attacker_units = _build_battle_units(attacker_army, true)
	state.defender_units = _build_battle_units(defender_army, false)

	if state.defender_units.is_empty():
		return {
			"winner": "attacker", "attacker_losses": {}, "defender_losses": {},
			"captured_heroes": [], "log": [{"action": "victory", "desc": "敌方无驻军，我方直接占领"}],
			"rounds": 0, "rounds_fought": 0, "enemy_troops_killed": 0, "defender_troops_killed": 0
		}

	state.terrain = node_data.get("terrain", Terrain.PLAINS)
	state.is_siege = node_data.get("is_siege", false)
	state.city_def = node_data.get("city_def", 0)

	var attacker_units_initial := _snapshot_units(state.attacker_units)
	var defender_units_initial := _snapshot_units(state.defender_units)

	_apply_terrain_modifiers(state)
	state.atk_formations = FormationSystem.detect_formations(_build_formation_dicts(state.attacker_units))
	state.def_formations = FormationSystem.detect_formations(_build_formation_dicts(state.defender_units))

	while state.round_number <= MAX_ROUNDS:
		if state.living_attackers().is_empty() or state.living_defenders().is_empty():
			break
		
		state.action_log.append({"action": "round_start", "round": state.round_number})
		
		# v10.2: Tick Buff Durations at round start
		_tick_buff_durations(state)

		if player_controlled and _has_autoload("CommanderIntervention"):
			var ci := _get_autoload("CommanderIntervention")
			if ci:
				ci.check_cp_regen(state.round_number)
				var istate := _build_intervention_state(state)
				_apply_intervention_results(state, istate)

		_apply_round_start_passives(state)
		_consume_formation_bonuses(state)
		_tick_hero_skills(state)

		if state.round_number == 1 and state.is_siege:
			_resolve_siege_phase(state)

		_resolve_preemptive_phase(state)

		var queue := _get_action_queue(state)
		for unit in queue:
			if unit.is_alive() and not unit.has_acted:
				var entry := _execute_action(unit, state)
				state.action_log.append(entry)
				if state.living_attackers().is_empty() or state.living_defenders().is_empty():
					break
		
		for u in state.attacker_units + state.defender_units:
			u.has_acted = false
		
		_tick_intervention_durations(state)
		state.round_number += 1

	var winner := "defender"
	if state.living_defenders().is_empty() and not state.living_attackers().is_empty():
		winner = "attacker"
	
	var attacker_losses := {}
	for i in range(state.attacker_units.size()):
		var u := state.attacker_units[i]
		var lost := attacker_units_initial[i]["soldiers"] - u.soldiers
		if lost > 0: attacker_losses[u.id] = lost
	
	var defender_losses := {}
	for i in range(state.defender_units.size()):
		var u := state.defender_units[i]
		var lost := defender_units_initial[i]["soldiers"] - u.soldiers
		if lost > 0: defender_losses[u.id] = lost

	var captured := []
	if winner == "attacker":
		for u in state.defender_units:
			if not u.hero_id.is_empty() and randf() < 0.3:
				captured.append(u.hero_id)

	var _att_killed: int = 0
	for _dk in defender_losses.values(): _att_killed += _dk
	var _def_killed: int = 0
	for _ak in attacker_losses.values(): _def_killed += _ak

	return {
		"winner": winner, "attacker_losses": attacker_losses, "defender_losses": defender_losses,
		"captured_heroes": captured, "log": state.action_log, "terrain": state.terrain,
		"rounds": state.round_number - 1, "rounds_fought": state.round_number - 1,
		"attacker_units_initial": attacker_units_initial, "defender_units_initial": defender_units_initial,
		"attacker_units_final": _snapshot_units(state.attacker_units),
		"defender_units_final": _snapshot_units(state.defender_units),
		"player_controlled": player_controlled,
		"enemy_troops_killed": _att_killed, "defender_troops_killed": _def_killed,
	}

# ---------------------------------------------------------------------------
# Core Logic
# ---------------------------------------------------------------------------

func _build_battle_units(army: Dictionary, is_attacker: bool) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	var troops: Array = army.get("troops", [])
	var hero_data: Dictionary = army.get("hero", {})

	for i in range(troops.size()):
		var t := troops[i]
		var bu := BattleUnit.new()
		bu.id = t.get("id", "u_%d" % i)
		bu.commander_id = army.get("commander_id", "generic")
		bu.troop_id = t.get("troop_id", "militia")
		bu.atk = t.get("atk", 10)
		bu.def_stat = t.get("def", 5)
		bu.spd = t.get("spd", 5)
		bu.int_stat = t.get("int", 5)
		bu.soldiers = t.get("soldiers", 100)
		bu.max_soldiers = t.get("max_soldiers", bu.soldiers)
		bu.row = t.get("row", 0)
		bu.slot = t.get("slot", i % 3)
		bu.passive = t.get("passive", "")
		bu.is_attacker = is_attacker
		bu.mana = t.get("mana", 0)
		bu.xp = t.get("xp", 0)
		bu.morale = t.get("morale", 100)
		bu.hp_per_soldier = t.get("hp_per_soldier", 10)
		bu.hp = bu.soldiers * bu.hp_per_soldier
		bu.max_hp = bu.max_soldiers * bu.hp_per_soldier
		bu.hero_id = t.get("hero_id", "")
		
		if bu.has_passive("death_resist"): bu._death_resist_used = false
		if bu.has_passive("ghost_shield"): bu._ghost_shield_active = true

		if bu.hero_id != "" and not hero_data.is_empty():
			var hero_specialty: String = hero_data.get("troop_specialty", "")
			if hero_specialty != "" and bu.troop_id.find(hero_specialty) >= 0:
				bu.atk += BalanceConfig.HERO_TROOP_SYNERGY_ATK
				bu.def_stat += BalanceConfig.HERO_TROOP_SYNERGY_DEF
				bu.morale = mini(100, bu.morale + BalanceConfig.HERO_TROOP_SYNERGY_MORALE)

		units.append(bu)
	return units

func _calculate_damage(attacker: BattleUnit, defender: BattleUnit, state: BattleState) -> int:
	# v10.2: Apply Buff Multipliers
	var atk_val := float(attacker.atk) * attacker.get_stat_mult("atk")
	var def_val := float(defender.def_stat) * defender.get_stat_mult("def")
	
	# v10.2: Damage Formula with Edge Case Protection
	var raw_diff := maxi(1, int(atk_val - def_val))
	
	# SR07-style diminishing returns on troop count
	var troops := float(attacker.soldiers)
	var adjusted: float
	if troops <= 8.0: adjusted = troops
	elif troops <= 15.0: adjusted = 8.0 + (troops - 8.0) * 0.5
	else: adjusted = 11.5 + (troops - 15.0) * 0.25
	
	var base_damage := adjusted * float(raw_diff) / 100.0
	
	var counter := CounterMatrix.get_counter(attacker.troop_id, defender.troop_id)
	base_damage *= counter.get("atk_mult", 1.0)
	base_damage *= counter.get("def_mult", 1.0)
	
	# v10.2: Minimum Damage Protection (at least 2% of current soldiers if attacker has soldiers)
	var min_dmg := ceil(float(attacker.soldiers) * 0.02)
	return maxi(int(min_dmg), int(base_damage))

func _apply_kill_morale_boost(killer: BattleUnit, dead_unit: BattleUnit, state: BattleState) -> void:
	var allies := state.attacker_units if killer.is_attacker else state.defender_units
	var boost := 10 if dead_unit.hero_id != "" else 5
	for u in allies:
		if u.is_alive():
			u.morale = mini(100, u.morale + boost)

func _apply_ally_death_morale(dead_unit: BattleUnit, state: BattleState) -> void:
	var allies := state.attacker_units if dead_unit.is_attacker else state.defender_units
	
	# v10.2: Morale Resilience Mechanism
	# High XP or Leadership reduces morale loss
	var loss_reduction := 0
	if dead_unit.xp >= BalanceConfig.ELITE_EXP_THRESHOLD: loss_reduction = 5
	
	var base_loss := maxi(5, 15 - loss_reduction)
	
	for u in allies:
		if u.is_alive():
			u.morale = maxi(0, u.morale - base_loss)
			if u.morale <= 0 and not u.is_routed:
				_rout_unit(u, state)

func _rout_unit(unit: BattleUnit, state: BattleState) -> void:
	unit.is_routed = true
	state.action_log.append({
		"action": "morale", "morale_type": "rout", "unit": unit.id,
		"desc": "%s 士气崩溃，溃败！" % unit.troop_id
	})

func _tick_buff_durations(state: BattleState) -> void:
	for u in state.attacker_units + state.defender_units:
		var remaining := []
		for b in u.active_buffs:
			b["duration"] -= 1
			if b["duration"] > 0:
				remaining.append(b)
			else:
				state.action_log.append({
					"action": "buff_expire", "unit": u.id, "buff_id": b["id"],
					"desc": "%s 的 %s 效果消失" % [u.troop_id, b["id"]]
				})
		u.active_buffs = remaining

# ---------------------------------------------------------------------------
# Helpers (Preserved from v10.1)
# ---------------------------------------------------------------------------

func _snapshot_units(units: Array[BattleUnit]) -> Array:
	var snap: Array = []
	for u in units:
		snap.append({"id": u.id, "troop_id": u.troop_id, "atk": u.atk, "def": u.def_stat, "soldiers": u.soldiers, "max_soldiers": u.max_soldiers, "row": u.row, "slot": u.slot, "morale": u.morale, "hp": u.hp, "mana": u.mana, "hero_id": u.hero_id})
	return snap

func _resolve_siege_phase(state: BattleState) -> void:
	var total_siege_dmg: int = 0
	for u in state.attacker_units:
		if u.has_passive("siege_bonus"): total_siege_dmg += 2
	var atk_bonuses: Dictionary = FormationSystem.get_formation_bonuses(state.atk_formations)
	if atk_bonuses.get("siege_damage_mult", 1.0) > 1.0:
		total_siege_dmg = int(float(total_siege_dmg) * atk_bonuses["siege_damage_mult"])
	if total_siege_dmg > 0:
		state.city_def = maxi(0, state.city_def - total_siege_dmg)
		state.action_log.append({"action": "siege", "damage": total_siege_dmg, "remaining_def": state.city_def, "desc": "攻城阶段: 城防损失 %d" % total_siege_dmg})

func _resolve_preemptive_phase(state: BattleState) -> void:
	var preemptive_units: Array[BattleUnit] = []
	for u in state.attacker_units + state.defender_units:
		if u.is_alive() and u.has_passive("preemptive_shot"): preemptive_units.append(u)
	preemptive_units.sort_custom(func(a, b): return a.spd > b.spd)
	for u in preemptive_units:
		if u.is_alive():
			state.action_log.append(_execute_action(u, state))

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
	var targets := _get_enemies(unit, state)
	if targets.is_empty(): return {"action": "idle", "unit": unit.id}
	var target: BattleUnit = targets[randi() % targets.size()]
	var dmg := _calculate_damage(unit, target, state)
	var was_alive := target.is_alive()
	if target._ghost_shield_active:
		target._ghost_shield_active = false
		dmg = 0
	target.hp = maxi(0, target.hp - dmg * target.hp_per_soldier)
	var old_s := target.soldiers
	_recalc_soldiers(target)
	var actual_lost := old_s - target.soldiers
	if was_alive and not target.is_alive():
		_apply_kill_morale_boost(unit, target, state)
		_apply_ally_death_morale(target, state)
		_revalidate_formations_for_side(target, state)
	return {"action": "attack", "unit": unit.id, "target": target.id, "damage": actual_lost, "desc": "%s 攻击 %s" % [unit.troop_id, target.troop_id]}

func _tick_hero_skills(state: BattleState) -> void:
	for u in state.attacker_units + state.defender_units:
		if u.is_alive() and not u.hero_id.is_empty():
			HeroSkillsAdvanced.tick_charge(u.hero_id)
			if HeroSkillsAdvanced.is_charged(u.hero_id):
				var res := HeroSkillsAdvanced.execute_ultimate(u.hero_id, _state_to_resolver_dict(state))
				if res.get("ok", false): _apply_ultimate_damage(state, res, "attacker" if u.is_attacker else "defender", u.hero_id)

func _apply_ultimate_damage(state: BattleState, result: Dictionary, side: String, hero_id: String) -> void:
	var targets: Array = result.get("targets_hit", [])
	for t in targets:
		for u in state.attacker_units + state.defender_units:
			if u.troop_id == t.get("unit", "") and u.is_alive():
				if t.has("damage"):
					u.hp = maxi(0, u.hp - int(t["damage"]) * u.hp_per_soldier)
					_recalc_soldiers(u)
				elif t.has("healed"):
					u.hp = mini(u.max_hp, u.hp + int(t["healed"]) * u.hp_per_soldier)
					_recalc_soldiers(u)

func _recalc_soldiers(unit: BattleUnit) -> void:
	unit.soldiers = int(ceil(float(unit.hp) / float(unit.hp_per_soldier)))
	if unit.hp <= 0: unit.soldiers = 0

func _get_enemies(unit: BattleUnit, state: BattleState) -> Array[BattleUnit]:
	return state.living_defenders() if unit.is_attacker else state.living_attackers()

func _revalidate_formations_for_side(unit: BattleUnit, state: BattleState) -> void:
	if unit.is_attacker: state.atk_formations = FormationSystem.detect_formations(_build_formation_dicts(state.attacker_units))
	else: state.def_formations = FormationSystem.detect_formations(_build_formation_dicts(state.defender_units))

func _apply_round_start_passives(state: BattleState) -> void:
	for u in state.attacker_units + state.defender_units:
		if u.is_alive() and u.has_passive("regen_1"):
			u.hp = mini(u.max_hp, u.hp + u.hp_per_soldier)
			_recalc_soldiers(u)

func _consume_formation_bonuses(state: BattleState) -> void:
	var atk_bonuses := FormationSystem.get_formation_bonuses(state.atk_formations)
	if state.round_number == 1 and atk_bonuses.get("cavalry_atk_mult_r1", 1.0) > 1.0:
		for u in state.attacker_units:
			if u.troop_id.find("cavalry") >= 0: u.atk = int(u.atk * atk_bonuses["cavalry_atk_mult_r1"])

func _apply_terrain_modifiers(state: BattleState) -> void: pass

func _state_to_resolver_dict(state: BattleState) -> Dictionary:
	var atk_units := []
	for u in state.attacker_units:
		atk_units.append({"id": u.id, "hero_id": u.hero_id, "unit_type": u.troop_id, "soldiers": u.soldiers, "max_soldiers": u.max_soldiers, "atk": u.atk, "def": u.def_stat, "mana": u.mana, "morale": u.morale, "is_routed": u.is_routed, "is_alive": u.is_alive(), "side": "attacker", "slot": u.slot, "row": "front" if u.row == 0 else "back", "buffs": u.active_buffs})
	var def_units := []
	for u in state.defender_units:
		def_units.append({"id": u.id, "hero_id": u.hero_id, "unit_type": u.troop_id, "soldiers": u.soldiers, "max_soldiers": u.max_soldiers, "atk": u.atk, "def": u.def_stat, "mana": u.mana, "morale": u.morale, "is_routed": u.is_routed, "is_alive": u.is_alive(), "side": "defender", "slot": u.slot, "row": "front" if u.row == 0 else "back", "buffs": u.active_buffs})
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

func _tick_intervention_durations(state: BattleState) -> void:
	if _has_autoload("CommanderIntervention"):
		var ci := _get_autoload("CommanderIntervention")
		if ci and ci.has_method("tick_cooldowns"): ci.tick_cooldowns()

func _has_autoload(aname: String) -> bool:
	var tree := Engine.get_main_loop()
	return tree is SceneTree and (tree as SceneTree).root.has_node(aname)

func _get_autoload(aname: String) -> Node:
	var tree := Engine.get_main_loop()
	return (tree as SceneTree).root.get_node(aname) if tree is SceneTree and (tree as SceneTree).root.has_node(aname) else null

func _build_formation_dicts(units: Array[BattleUnit]) -> Array:
	var result: Array = []
	for u in units:
		if u.is_alive(): result.append({"id": u.id, "troop_id": u.troop_id, "row": u.row, "slot": u.slot})
	return result
