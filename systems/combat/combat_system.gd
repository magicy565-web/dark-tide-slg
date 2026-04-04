## combat_system.gd — Core Battle Engine (v10.0)
## Handles army-vs-army resolution, formation detection, and hero skill execution.
## Integrated with EventBus for UI/audio hooks.
class_name CombatSystem
extends RefCounted

# ---------------------------------------------------------------------------
# Constants & Enums
# ---------------------------------------------------------------------------

const MAX_ROUNDS := 12
const MAX_FRONT_SLOTS := 3
const MAX_BACK_SLOTS := 3

enum Terrain { PLAINS, FOREST, MOUNTAIN, WASTELAND, COASTAL, CITY }
enum UnitCommand { AUTO, GUARD, CHARGE, RETREAT }

# ---------------------------------------------------------------------------
# Battle State Classes
# ---------------------------------------------------------------------------

## Represents a single unit in the battle.
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
	
	# HP model: soldiers * hp_per_soldier = total HP
	var hp: int
	var max_hp: int
	var hp_per_soldier: int = 5
	
	# Hero-specific (if applicable)
	var hero_hp: int = 0
	var hero_max_hp: int = 0
	var hero_mp: int = 0
	var hero_max_mp: int = 0

	# v4.5: death_resist — one-time flag (orc_iron_jaw_plate)
	var _death_resist_used: bool = false
	# v4.5: ghost_shield — first hit immunity flag
	var _ghost_shield_active: bool = false

	func is_alive() -> bool:
		return soldiers > 0

	func has_passive(pname: String) -> bool:
		if passive == "": return false
		var plist := passive.split(",")
		for p in plist:
			if p.strip_edges() == pname:
				return true
		return false

## Holds the entire state of an ongoing battle.
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
	var atk_formations: Array = []   ## Active attacker formations (FormationID values)
	var def_formations: Array = []   ## Active defender formations (FormationID values)
	var terrain_str: String = ""     ## Terrain string for formation revalidation

	## Return all living units for a side.
	func living_attackers() -> Array[BattleUnit]:
		var out: Array[BattleUnit] = []
		for u in attacker_units:
			if u.is_alive():
				out.append(u)
		return out

	func living_defenders() -> Array[BattleUnit]:
		var out: Array[BattleUnit] = []
		for u in defender_units:
			if u.is_alive():
				out.append(u)
		return out

	## Total soldiers on each side.
	func total_attacker_soldiers() -> int:
		var s := 0
		for u in attacker_units:
			s += u.soldiers
		return s

	func total_defender_soldiers() -> int:
		var s := 0
		for u in defender_units:
			s += u.soldiers
		return s

	## Get the side's current mana pool reference.
	func get_mana(is_attacker_side: bool) -> int:
		return mana_attacker if is_attacker_side else mana_defender

	func set_mana(is_attacker_side: bool, value: int) -> void:
		if is_attacker_side:
			mana_attacker = value
		else:
			mana_defender = value

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Main entry point.  Pass in army dictionaries and the node (map tile) data.
##
## attacker_army / defender_army format:
##   { "units": [ { "id", "commander_id", "troop_id", "atk", "def", "spd",
##                   "int", "soldiers", "max_soldiers", "row", "slot",
##                   "passive" }, ... ] }
##
## node_data format:
##   { "terrain": int, "is_siege": bool, "city_def": int }
## When true, the battle loop will pause each round to await player intervention
## decisions via EventBus signals.  Set by the caller before invoking resolve_battle.
var player_controlled: bool = false

func resolve_battle(attacker_army: Dictionary, defender_army: Dictionary, node_data: Dictionary) -> Dictionary:
	# -- Build state --------------------------------------------------------
	var state := BattleState.new()

	# v6.0: Reset hero skill systems for this battle
	HeroSkillsAdvanced.reset_battle()

	state.attacker_units = _build_battle_units(attacker_army, true)
	state.defender_units = _build_battle_units(defender_army, false)
	state.terrain = node_data.get("terrain", Terrain.PLAINS)
	state.is_siege = node_data.get("is_siege", false)
	state.city_def = node_data.get("city_def", 0)
	state.mana_attacker = 0
	state.mana_defender = 0

	# v4.4: mana_bonus — equipment passive contributes to team mana pool at battle start
	for u in state.attacker_units:
		if u.mana > 0:
			state.mana_attacker += u.mana
			u.mana = 0  # Individual mana transferred to team pool
	for u in state.defender_units:
		if u.mana > 0:
			state.mana_defender += u.mana
			u.mana = 0

	# -- Apply terrain penalties that persist for the whole battle ----------
	_apply_terrain_modifiers(state)

	# v4.6: time_slow — if any unit on one side has time_slow, enemy SPD-3 first round
	var _time_slow_atk_on_def: bool = false
	for _ts_check in state.attacker_units:
		if _ts_check.has_passive("time_slow"):
			_time_slow_atk_on_def = true
			break
	if _time_slow_atk_on_def:
		for _ts_d in state.defender_units:
			_ts_d.spd = maxi(1, _ts_d.spd - 3)
	var _time_slow_def_on_atk: bool = false
	for _ts_check2 in state.defender_units:
		if _ts_check2.has_passive("time_slow"):
			_time_slow_def_on_atk = true
			break
	if _time_slow_def_on_atk:
		for _ts_a in state.attacker_units:
			_ts_a.spd = maxi(1, _ts_a.spd - 3)

	# ── Formation Detection & Synergy ──
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
			var _fkey: String = FormationSystem.FORMATION_NAMES.get(_fid, "Unknown").to_lower().replace(" ", "_")
			var _fname_cn: String = FormationSystem.FORMATION_NAMES_CN.get(_fid, "")
			state.action_log.append({
				"action": "formation",
				"side": "attacker",
				"formation": _fkey,
				"name_cn": _fname_cn,
				"desc": "攻方阵型: %s" % _fname_cn,
			})
	if not def_formations.is_empty():
		var def_bonuses: Dictionary = FormationSystem.get_formation_bonuses(def_formations)
		FormationSystem.apply_formation_to_units(def_unit_dicts, def_bonuses)
		_sync_formation_to_battle_units(state.defender_units, def_unit_dicts)
		FormationSystem.emit_formation_detected("defender", def_formations)
		for _fid in def_formations:
			var _fkey: String = FormationSystem.FORMATION_NAMES.get(_fid, "Unknown").to_lower().replace(" ", "_")
			var _fname_cn: String = FormationSystem.FORMATION_NAMES_CN.get(_fid, "")
			state.action_log.append({
				"action": "formation",
				"side": "defender",
				"formation": _fkey,
				"name_cn": _fname_cn,
				"desc": "守方阵型: %s" % _fname_cn,
			})
	# Check formation clashes
	var clashes: Dictionary = FormationSystem.check_formation_clash(atk_formations, def_formations)
	if not clashes.is_empty():
		FormationSystem.emit_formation_clashes(clashes)

	# Snapshot initial unit states for combat visualization
	var attacker_units_initial: Array = _snapshot_units(state.attacker_units)
	var defender_units_initial: Array = _snapshot_units(state.defender_units)

	# Record starting soldier counts so we can compute losses later.
	var start_att: Dictionary = {}
	for u in state.attacker_units:
		start_att[u.id] = u.soldiers
	var start_def: Dictionary = {}
	for u in state.defender_units:
		start_def[u.id] = u.soldiers

	# -- Siege phase (attacker chips at city walls before combat) -----------
	if state.is_siege and state.city_def > 0:
		# v4.4: node_wall_bonus — defender hero equipment adds to wall HP
		for u in state.defender_units:
			if u.has_passive("node_wall_bonus"):
				state.city_def += 5  # iron_wall_shield: +5 wall HP
				state.action_log.append({
					"action": "passive",
					"event": "node_wall_bonus",
					"unit": u.id,
					"side": "defender",
					"slot": u.slot,
					"desc": "%s 的铁壁之盾强化城防 +5" % u.troop_id,
				})
				break  # Only apply once
		_resolve_siege_phase(state)

	# -- Pre-battle: preemptive strikes ------------------------------------
	_resolve_preemptive_phase(state)

	# -- Main battle loop ---------------------------------------------------
	var winner := _check_battle_end(state)
	while winner == "" and state.round_number < MAX_ROUNDS:
		state.round_number += 1

		# Emit round_start log entry
		state.action_log.append({
			"action": "round_start",
			"round": state.round_number,
			"desc": "第%d回合开始" % state.round_number,
		})

		# Start-of-round passives (regen, mana charge)
		_apply_round_start_passives(state)

		# v10.0: Consume formation bonuses (cavalry_atk_mult_r1, ranged_double_attack_rounds, heal_per_round)
		_consume_formation_bonuses(state)

		# -- v6.0: Ultimate charge, awakening check, ultimate execution --
		_tick_hero_skills(state)

		# v4.6: time_slow — restore SPD after round 1
		if state.round_number == 2:
			if _time_slow_atk_on_def:
				for _ts_restore in state.defender_units:
					_ts_restore.spd += 3
			if _time_slow_def_on_atk:
				for _ts_restore2 in state.attacker_units:
					_ts_restore2.spd += 3

		# -- Commander Intervention Phase (human player only) --
		if player_controlled:
			# v8.0 BUG FIX: CP regen was never called — regenerate at rounds 4 and 8
			CommanderIntervention.check_cp_regen(state.round_number)
			CommanderIntervention.tick_cooldowns()
			if CommanderIntervention.get_current_cp() > 0:
				var available: Array = CommanderIntervention.get_available_interventions()
				if not available.is_empty():
					var intervention_state: Dictionary = _build_intervention_state(state)
					intervention_state["round"] = state.round_number
					intervention_state["intervention_options"] = available
					intervention_state["intervention_cp"] = CommanderIntervention.get_current_cp()
					EventBus.combat_intervention_phase.emit(intervention_state)
					# Await player decision (panel emits one of these)
					var result: Array = await EventBus.combat_intervention_chosen
					var chosen_type: int = result[0] if result.size() > 0 else -1
					var chosen_target: Variant = result[1] if result.size() > 1 else null
					if chosen_type >= 0:
						var log_lines: Array = []
						CommanderIntervention.execute(chosen_type, intervention_state, chosen_target, log_lines)
						# Apply intervention effects back to BattleState
						_apply_intervention_results(state, intervention_state)
						# Add intervention to action_log for combat view display
						var idata: Dictionary = CommanderIntervention.INTERVENTION_DATA.get(chosen_type, {})
						state.action_log.append({
							"action": "intervention",
							"round": state.round_number,
							"desc": log_lines[0] if not log_lines.is_empty() else idata.get("name", "干预"),
						})

		# Build action queue for this round
		var queue := _get_action_queue(state)

		for unit in queue:
			# Unit may have died during this round
			if not unit.is_alive():
				continue
			if unit.has_acted:
				continue

			var entry := _execute_action(unit, state)
			if entry.get("action", "") != "_already_logged":
				state.action_log.append(entry)

			# extra_action: unit acts twice per round
			if unit.has_passive("extra_action") and unit.is_alive():
				unit.has_acted = false  # allow a second action
				var entry2 := _execute_action(unit, state)
				if entry2.get("action", "") != "_already_logged":
					state.action_log.append(entry2)

			# v4.6: double_shot — unit attacks twice in round 1 only
			if state.round_number == 1 and unit.has_passive("double_shot") and unit.is_alive() and not unit.has_passive("extra_action"):
				unit.has_acted = false
				var entry_ds := _execute_action(unit, state)
				if entry_ds.get("action", "") != "_already_logged":
					state.action_log.append(entry_ds)

			winner = _check_battle_end(state)
			if winner != "":
				break

		# Reset acted flags for next round
		for u in state.attacker_units:
			u.has_acted = false
		for u in state.defender_units:
			u.has_acted = false

		# v9.0 BUG FIX: Decrement intervention targeting durations at end-of-round
		# (mirrors combat_resolver.gd _end_of_round() behavior)
		_tick_intervention_durations(state)

		if winner == "":
			winner = _check_battle_end(state)

	# Timeout: defender wins
	if winner == "":
		winner = "defender"

	# -- Build result -------------------------------------------------------
	var attacker_losses: Dictionary = {}
	for u in state.attacker_units:
		var lost: int = start_att[u.id] - u.soldiers
		if lost > 0:
			attacker_losses[u.id] = lost

	var defender_losses: Dictionary = {}
	for u in state.defender_units:
		var lost: int = start_def[u.id] - u.soldiers
		if lost > 0:
			defender_losses[u.id] = lost

	# Captured heroes: commanders on the losing side whose soldiers hit 0.
	var captured: Array = []
	var losing_units: Array[BattleUnit] = state.defender_units if winner == "attacker" else state.attacker_units
	for u in losing_units:
		if u.soldiers <= 0 and u.commander_id != "generic":
			captured.append(u.commander_id)

	# BUG FIX: compute enemy_troops_killed so _grant_hero_combat_exp can award kill EXP.
	# attacker_losses is a Dict{unit_id: soldiers_lost}; sum defender_losses for attacker's kills.
	var _att_killed: int = 0
	for _dk in defender_losses.values():
		_att_killed += _dk
	var _def_killed: int = 0
	for _ak in attacker_losses.values():
		_def_killed += _ak

	return {
		"winner": winner,
		"attacker_losses": attacker_losses,
		"defender_losses": defender_losses,
		"captured_heroes": captured,
		"log": state.action_log,
		"terrain": state.terrain,
		"rounds": state.round_number,
		"attacker_units_initial": attacker_units_initial,
		"defender_units_initial": defender_units_initial,
		"attacker_units_final": _snapshot_units(state.attacker_units),
		"defender_units_final": _snapshot_units(state.defender_units),
		"player_controlled": player_controlled,
		# BUG FIX: provide kill counts for hero EXP calculation in game_manager
		"enemy_troops_killed": _att_killed,
		"defender_troops_killed": _def_killed,
	}

# ---------------------------------------------------------------------------
# Unit Construction
# ---------------------------------------------------------------------------

## Build BattleUnit array from an army dictionary.
func _build_battle_units(army: Dictionary, is_attacker: bool) -> Array[BattleUnit]:
	var units: Array[BattleUnit] = []
	var raw_units: Array = army.get("units", [])

	# v4.3: Tile development combat bonuses (defender gets home-tile bonus)
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

		# HP model: initialize per-soldier HP and total HP pool
		bu.hp_per_soldier = d.get("hp_per_soldier", 5)
		bu.max_hp = bu.soldiers * bu.hp_per_soldier
		bu.hp = bu.max_hp

		# Hero data (if present)
		var hero_data: Dictionary = d.get("hero_data", {})
		if not hero_data.is_empty():
			bu.hero_id = hero_data.get("id", "")
			bu.hero_hp = hero_data.get("hp", 0)
			bu.hero_max_hp = bu.hero_hp
			bu.hero_mp = hero_data.get("mp", 0)
			bu.hero_max_mp = bu.hero_mp

			# v4.4: Equipment passives — merge into BattleUnit.passive for has_passive() checks
			var eq_passives: Array = hero_data.get("equipment_passives", [])
			for ep in eq_passives:
				if ep != "" and ep != "none":
					if bu.passive == "":
						bu.passive = ep
					else:
						bu.passive += "," + ep

			# BUG FIX: level_passives (hero level-unlocked passives) were never merged
			# into BattleUnit.passive, so they had zero effect in combat.
			var lv_passives: Array = hero_data.get("level_passives", [])
			for lp in lv_passives:
				var lp_id: String = ""
				if lp is String:
					lp_id = lp
				elif lp is Dictionary:
					lp_id = lp.get("passive_id", lp.get("id", ""))
				if lp_id != "" and lp_id != "none":
					if bu.passive == "":
						bu.passive = lp_id
					elif lp_id not in bu.passive.split(","):
						bu.passive += "," + lp_id

			# v4.4: mana_bonus — increase team mana pool start value
			if bu.has_passive("mana_bonus"):
				bu.mana += 3  # mana_orb: +3 mana

			# v4.4: one_battle_power — +30% ATK for this battle (war_totem)
			if bu.has_passive("one_battle_power"):
				bu.atk = int(ceil(float(bu.atk) * 1.3))

			# v4.5: preemptive_bonus / preemptive_shot — boost SPD by +10 for first-strike priority
			if bu.has_passive("preemptive_bonus") or bu.has_passive("preemptive_shot"):
				bu.spd += 10

		# v4.5: death_resist — initialize one-time flag (orc_iron_jaw_plate)
		if bu.has_passive("death_resist"):
			bu._death_resist_used = false

		# v4.5: ghost_shield — first hit immunity flag
		if bu.has_passive("ghost_shield"):
			bu._ghost_shield_active = true

		# v4.3: Hero-Troop Synergy — hero commanding matching troop type
		if bu.hero_id != "" and not hero_data.is_empty():
			var hero_specialty: String = hero_data.get("troop_specialty", "")
			if hero_specialty != "" and bu.troop_id.find(hero_specialty) >= 0:
				bu.atk += BalanceConfig.HERO_TROOP_SYNERGY_ATK
				bu.def_stat += BalanceConfig.HERO_TROOP_SYNERGY_DEF
				bu.morale = mini(100, bu.morale + BalanceConfig.HERO_TROOP_SYNERGY_MORALE)

		# v4.3: Veteran / Elite bonuses based on accumulated EXP
		if bu.xp >= BalanceConfig.ELITE_EXP_THRESHOLD:
			bu.atk += BalanceConfig.ELITE_ATK_BONUS
			bu.def_stat += BalanceConfig.ELITE_DEF_BONUS
			bu.morale = mini(100, bu.morale + BalanceConfig.ELITE_MORALE_BONUS)
		elif bu.xp >= BalanceConfig.VETERAN_EXP_THRESHOLD:
			bu.atk += BalanceConfig.VETERAN_ATK_BONUS
			bu.morale = mini(100, bu.morale + BalanceConfig.VETERAN_MORALE_BONUS)

		# v4.3: Tile development combat bonuses (military tiles buff garrison)
		if tile_bonuses.get("atk", 0) > 0:
			bu.atk += tile_bonuses["atk"]
		if tile_bonuses.get("morale", 0) > 0:
			bu.morale = mini(100, bu.morale + tile_bonuses["morale"])

		# v5.1: Difficulty player_atk_mult — scale player unit ATK by difficulty
		var _is_player_side: bool = army.get("is_player", false)
		if _is_player_side and _has_autoload("BalanceManager"):
			var _bm: Node = _get_autoload("BalanceManager")
			if _bm != null and _bm.has_method("get_player_atk_mult"):
				var _p_atk_mult: float = _bm.get_player_atk_mult()
				if _p_atk_mult != 1.0:
					bu.atk = maxi(1, int(float(bu.atk) * _p_atk_mult))

		units.append(bu)

	# v4.6: command_bonus — if any unit has command_bonus, SPD+2 to all same-side units
	var _has_command_bonus: bool = false
	for _cb_u in units:
		if _cb_u.has_passive("command_bonus"):
			_has_command_bonus = true
			break
	if _has_command_bonus:
		for _cb_u2 in units:
			_cb_u2.spd += 2

	return units


## Snapshot current unit states to serializable dictionaries (for combat view).
func _snapshot_units(units: Array[BattleUnit]) -> Array:
	var snap: Array = []
	for u in units:
		snap.append({
			"id": u.id,
			"commander_id": u.commander_id,
			"troop_id": u.troop_id,
			"atk": u.atk,
			"def": u.def_stat,
			"spd": u.spd,
			"int_stat": u.int_stat,
			"soldiers": u.soldiers,
			"max_soldiers": u.max_soldiers,
			"row": u.row,
			"slot": u.slot,
			"passive": u.passive,
			"is_attacker": u.is_attacker,
			"mana": u.mana,
			"xp": u.xp,
			"morale": u.morale,
			"is_routed": u.is_routed,
			"hp": u.hp,
			"max_hp": u.max_hp,
			"hp_per_soldier": u.hp_per_soldier,
			"hero_id": u.hero_id,
			"hero_hp": u.hero_hp,
			"hero_max_hp": u.hero_max_hp,
			"hero_mp": u.hero_mp,
			"hero_max_mp": u.hero_max_mp,
		})
	return snap

# ---------------------------------------------------------------------------
# Phase Resolvers
# ---------------------------------------------------------------------------

func _resolve_siege_phase(state: BattleState) -> void:
	# Attacker units with siege_bonus deal damage to city walls
	var total_siege_dmg: int = 0
	for u in state.attacker_units:
		if u.has_passive("siege_bonus"):
			total_siege_dmg += 2
	
	# v4.6: PIRATE_BROADSIDE formation doubles siege damage
	var atk_bonuses: Dictionary = FormationSystem.get_formation_bonuses(state.atk_formations)
	if atk_bonuses.get("siege_damage_mult", 1.0) > 1.0:
		total_siege_dmg = int(float(total_siege_dmg) * atk_bonuses["siege_damage_mult"])

	if total_siege_dmg > 0:
		state.city_def = maxi(0, state.city_def - total_siege_dmg)
		state.action_log.append({
			"action": "siege",
			"damage": total_siege_dmg,
			"remaining_def": state.city_def,
			"desc": "攻城阶段: 城防损失 %d, 剩余 %d" % [total_siege_dmg, state.city_def],
		})

func _resolve_preemptive_phase(state: BattleState) -> void:
	# Units with preemptive_shot act before the main loop
	var preemptive_units: Array[BattleUnit] = []
	for u in state.attacker_units + state.defender_units:
		if u.is_alive() and u.has_passive("preemptive_shot"):
			preemptive_units.append(u)
	
	# Sort by speed
	preemptive_units.sort_custom(func(a, b): return a.spd > b.spd)
	
	for u in preemptive_units:
		if u.is_alive():
			var entry := _execute_action(u, state)
			state.action_log.append(entry)
			u.has_acted = true

# ---------------------------------------------------------------------------
# Core Action Logic
# ---------------------------------------------------------------------------

func _get_action_queue(state: BattleState) -> Array[BattleUnit]:
	var queue: Array[BattleUnit] = []
	for u in state.attacker_units + state.defender_units:
		if u.is_alive() and not u.is_routed:
			queue.append(u)
	
	# Sort by speed (descending)
	queue.sort_custom(func(a, b):
		if a.spd != b.spd:
			return a.spd > b.spd
		# If speed is equal, attacker goes first
		return a.is_attacker and not b.is_attacker
	)
	return queue

func _execute_action(unit: BattleUnit, state: BattleState) -> Dictionary:
	unit.has_acted = true
	
	# 1) Check for active skills
	var skill := _get_active_skill(unit)
	if not skill.is_empty():
		# Mana check
		var side_mana: int = state.get_mana(unit.is_attacker)
		if side_mana >= skill.get("mana_cost", 0):
			state.set_mana(unit.is_attacker, side_mana - skill.get("mana_cost", 0))
			return _execute_skill(unit, skill, state)
	
	# 2) Default: Basic Attack
	var targets := _get_enemies(unit, state)
	if targets.is_empty():
		return {"action": "idle", "unit": unit.id, "desc": "%s 待机" % unit.troop_id}
	
	# v4.6: shadow_bypass_chance — Shadow Strike formation can bypass front row
	var bonuses: Dictionary = FormationSystem.get_formation_bonuses(state.atk_formations if unit.is_attacker else state.def_formations)
	var bypass_chance: float = 0.0
	if state.round_number <= bonuses.get("shadow_bypass_rounds", 0):
		bypass_chance = bonuses.get("shadow_bypass_chance", 0.0)
	
	var target: BattleUnit = null
	if bypass_chance > 0.0 and randf() < bypass_chance:
		# Try to find a back-row target
		var back_targets: Array[BattleUnit] = []
		for t in targets:
			if t.row == 1:
				back_targets.append(t)
		if not back_targets.is_empty():
			target = back_targets[randi() % back_targets.size()]
			state.action_log.append({
				"action": "passive",
				"event": "shadow_bypass",
				"unit": unit.id,
				"side": "attacker" if unit.is_attacker else "defender",
				"slot": unit.slot,
				"desc": "%s 影袭绕后!" % unit.troop_id,
			})
	
	if target == null:
		# Standard targeting: pick a random front-row enemy if any, else random back-row
		var front_targets: Array[BattleUnit] = []
		var back_targets: Array[BattleUnit] = []
		for t in targets:
			if t.row == 0:
				front_targets.append(t)
			else:
				back_targets.append(t)
		
		if not front_targets.is_empty():
			target = front_targets[randi() % front_targets.size()]
		elif not back_targets.is_empty():
			target = back_targets[randi() % back_targets.size()]
	
	if target == null:
		return {"action": "idle", "unit": unit.id}

	# v4.6: ARROW_STORM — ranged units attack twice in rounds 1-2
	var mult := 1.0
	var is_double_shot: bool = false
	if state.round_number <= bonuses.get("ranged_double_attack_rounds", []).size():
		if FormationSystem._is_ranged({"troop_id": unit.troop_id}):
			is_double_shot = true

	var dmg := _calculate_damage(unit, target, state, mult)
	var was_alive := target.is_alive()
	
	# Apply damage through HP system
	var hp_dmg: int = dmg * target.hp_per_soldier
	
	# v4.5: ghost_shield — first hit immunity
	if target._ghost_shield_active:
		target._ghost_shield_active = false
		hp_dmg = 0
		state.action_log.append({
			"action": "passive",
			"event": "ghost_shield",
			"unit": target.id,
			"side": "attacker" if target.is_attacker else "defender",
			"slot": target.slot,
			"desc": "%s 的幽灵护盾抵挡了攻击" % target.troop_id,
		})

	target.hp = maxi(0, target.hp - hp_dmg)
	var old_soldiers := target.soldiers
	_recalc_soldiers(target)
	var actual_lost := old_soldiers - target.soldiers
	
	# v4.5: death_resist — orc_iron_jaw_plate: survive fatal hit with 1 soldier once
	if was_alive and not target.is_alive() and target.has_passive("death_resist") and not target._death_resist_used:
		target._death_resist_used = true
		target.soldiers = 1
		target.hp = target.hp_per_soldier
		state.action_log.append({
			"action": "passive",
			"event": "death_resist",
			"unit": target.id,
			"side": "attacker" if target.is_attacker else "defender",
			"slot": target.slot,
			"desc": "%s 触发不屈，保留1兵力" % target.troop_id,
		})

	var entry := {
		"action": "attack",
		"unit": unit.id,
		"side": "attacker" if unit.is_attacker else "defender",
		"slot": unit.slot,
		"target": target.id,
		"target_side": "attacker" if target.is_attacker else "defender",
		"target_slot": target.slot,
		"damage": actual_lost,
		"remaining_soldiers": target.soldiers,
		"desc": "%s 攻击 %s，造成 %d 伤害" % [unit.troop_id, target.troop_id, actual_lost],
	}
	
	# v4.4: kill_heal — restore HP on kill
	if was_alive and not target.is_alive():
		_apply_kill_heal(unit, state)
		_apply_kill_morale_boost(unit, target, state)
		state.action_log.append({
			"action": "death",
			"unit": target.id,
			"side": "attacker" if target.is_attacker else "defender",
			"slot": target.slot,
			"round": state.round_number,
			"desc": "%s 阵亡!" % target.troop_id,
		})
		_apply_ally_death_morale(target, state)
		_revalidate_formations_for_side(target, state)
	
	# v4.3: Counter-attack logic
	if target.is_alive() and not is_double_shot:
		# Only front-row units counter-attack by default, or units with counter_bonus
		if target.row == 0 or target.has_passive("counter_bonus"):
			_resolve_counter_attack(target, unit, state)

	# v4.5: poison_attack — apply poison debuff
	if unit.has_passive("poison_attack") and target.is_alive():
		_apply_poison(unit, target, state)

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
			var dmg := _calculate_damage(unit, target, state, skill_mult)
			var old_soldiers := target.soldiers
			target.hp = maxi(0, target.hp - dmg * target.hp_per_soldier)
			_recalc_soldiers(target)
			var actual_lost := old_soldiers - target.soldiers
			return {
				"action": "skill",
				"unit": unit.id,
				"side": side_str,
				"slot": unit.slot,
				"skill_name": skill.get("name", "技能"),
				"target": target.id,
				"damage": actual_lost,
				"desc": "%s 发动 %s，造成 %d 伤害" % [unit.troop_id, skill.get("name"), actual_lost],
			}
		"heal":
			var allies := state.attacker_units if unit.is_attacker else state.defender_units
			var target: BattleUnit = null
			var min_hp_ratio := 1.1
			for a in allies:
				if a.is_alive() and a.soldiers < a.max_soldiers:
					var ratio := float(a.soldiers) / float(a.max_soldiers)
					if ratio < min_hp_ratio:
						min_hp_ratio = ratio
						target = a
			if target:
				var heal_amt := int(float(target.max_soldiers) * 0.2)
				target.hp = mini(target.max_hp, target.hp + heal_amt * target.hp_per_soldier)
				_recalc_soldiers(target)
				return {
					"action": "skill",
					"unit": unit.id,
					"side": side_str,
					"slot": unit.slot,
					"skill_name": skill.get("name", "技能"),
					"target": target.id,
					"healed": heal_amt,
					"desc": "%s 发动 %s，回复 %d 兵力" % [unit.troop_id, skill.get("name"), heal_amt],
				}
	return {"action": "skill", "unit": unit.id, "skill_name": skill.get("name", "技能")}

func _resolve_counter_attack(defender: BattleUnit, attacker: BattleUnit, state: BattleState) -> void:
	# Counter-attack deals 50% damage
	var counter_mult := 0.5
	# v4.4: counter_bonus — equipment passive increases counter damage
	if defender.has_passive("counter_bonus"):
		counter_mult = 0.8
	
	var counter_dmg := _calculate_damage(defender, attacker, state, counter_mult)
	var old_soldiers := attacker.soldiers
	attacker.hp = maxi(0, attacker.hp - counter_dmg * attacker.hp_per_soldier)
	_recalc_soldiers(attacker)
	var actual_lost := old_soldiers - attacker.soldiers
	
	if actual_lost > 0:
		state.action_log.append({
			"action": "counter",
			"unit": defender.id,
			"side": "attacker" if defender.is_attacker else "defender",
			"slot": defender.slot,
			"target": attacker.id,
			"damage": actual_lost,
			"desc": "%s 反击造成 %d 伤害" % [defender.troop_id, actual_lost],
		})
		if attacker.soldiers <= 0:
			state.action_log.append({
				"action": "death",
				"unit": attacker.id,
				"side": "attacker" if attacker.is_attacker else "defender",
				"slot": attacker.slot,
				"desc": "%s 被反击歼灭!" % attacker.troop_id,
			})
			_apply_ally_death_morale(attacker, state)
			_revalidate_formations_for_side(attacker, state)

func _apply_poison(attacker: BattleUnit, defender: BattleUnit, state: BattleState) -> void:
	# We track this by adding a tag; since BattleUnit doesn't have debuffs array,
	# we apply immediate damage of 2 soldiers worth over time by reducing HP directly
	# for simplicity, deal 1 hp_per_soldier damage now and tag for 1 more next round
	var _pa_side := "attacker" if attacker.is_attacker else "defender"
	var _pa_tgt_side := "attacker" if defender.is_attacker else "defender"
	# Mark as poisoned using passive tag (checked in round start)
	if not defender.has_passive("poisoned_2"):
		if defender.passive == "":
			defender.passive = "poisoned_2"
		else:
			defender.passive += ",poisoned_2"
		state.action_log.append({
			"action": "passive",
			"event": "poison_attack",
			"unit": attacker.id,
			"side": _pa_side,
			"slot": attacker.slot,
			"target": defender.id,
			"target_side": _pa_tgt_side,
			"desc": "%s 毒击! %s 中毒(2回合)" % [attacker.troop_id, defender.troop_id],
		})
		state.action_log.append({
			"action": "debuff",
			"side": _pa_tgt_side,
			"slot": defender.slot,
			"debuff_type": "poison",
			"desc": "%s 中毒!" % defender.troop_id,
		})

# ---------------------------------------------------------------------------
# Battle End Check
# ---------------------------------------------------------------------------

## Returns "attacker" if defenders are wiped, "defender" if attackers are
## wiped, or "" if the battle should continue.
## v4.3: Also checks for total rout (all surviving units routed = defeat).
func _check_battle_end(state: BattleState) -> String:
	if state.total_attacker_soldiers() <= 0:
		return "defender"
	if state.total_defender_soldiers() <= 0:
		return "attacker"
	# v4.3: Total rout check — if all living units on a side are routed, they lose
	var atk_all_routed: bool = true
	for u in state.attacker_units:
		if u.is_alive() and not u.is_routed:
			atk_all_routed = false
			break
	if atk_all_routed and state.total_attacker_soldiers() > 0:
		return "defender"
	var def_all_routed: bool = true
	for u in state.defender_units:
		if u.is_alive() and not u.is_routed:
			def_all_routed = false
			break
	if def_all_routed and state.total_defender_soldiers() > 0:
		return "attacker"
	return ""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Get all living enemy units for a given unit.
func _get_enemies(unit: BattleUnit, state: BattleState) -> Array[BattleUnit]:
	if unit.is_attacker:
		return state.living_defenders()
	else:
		return state.living_attackers()

## Recalculate soldier count from current HP.
func _recalc_soldiers(unit: BattleUnit) -> void:
	if unit.hp <= 0:
		unit.soldiers = 0
	else:
		unit.soldiers = ceili(float(unit.hp) / maxf(1.0, float(unit.hp_per_soldier)))

# ---------------------------------------------------------------------------
# Morale System
# ---------------------------------------------------------------------------

## Reduce a unit's morale by the given amount. If morale reaches 0, the unit routs.
func _reduce_morale(unit: BattleUnit, amount: int, state: BattleState) -> void:
	if unit.is_routed or not unit.is_alive():
		return
	var old_morale: int = unit.morale
	unit.morale = maxi(0, unit.morale - amount)
	EventBus.unit_morale_changed.emit(unit.troop_id, "attacker" if unit.is_attacker else "defender", unit.morale)
	# Log morale waver when morale drops below 50 but unit doesn't rout
	if unit.morale > 0 and unit.morale <= 50 and old_morale > 50:
		var _m_side := "attacker" if unit.is_attacker else "defender"
		state.action_log.append({
			"action": "morale",
			"side": _m_side,
			"slot": unit.slot,
			"morale_type": "waver",
			"desc": "%s 士气动摇! (%d)" % [unit.troop_id, unit.morale],
		})
	if unit.morale <= 0:
		_rout_unit(unit, state)

## Rout a unit: lose 30% soldiers, mark as routed (removed from action queue).
## v4.3: Morale cascade — routing triggers morale loss on adjacent allies.
func _rout_unit(unit: BattleUnit, state: BattleState) -> void:
	unit.is_routed = true
	var loss: int = int(ceil(float(unit.soldiers) * 0.30))
	var hp_loss: int = loss * unit.hp_per_soldier
	unit.hp = maxi(0, unit.hp - hp_loss)
	_recalc_soldiers(unit)
	var side_str: String = "attacker" if unit.is_attacker else "defender"
	state.action_log.append({
		"action": "rout",
		"unit": unit.id,
		"side": side_str,
		"slot": unit.slot,
		"soldiers_lost": loss,
		"remaining_soldiers": unit.soldiers,
		"round": state.round_number,
		"desc": "%s 士气崩溃，溃败！损失%d兵" % [unit.troop_id, loss],
	})
	state.action_log.append({
		"action": "morale",
		"side": side_str,
		"slot": unit.slot,
		"morale_type": "rout",
		"desc": "%s 溃败!" % unit.troop_id,
	})
	EventBus.unit_routed.emit(unit.troop_id, side_str)
	# v4.3: Morale cascade — same-row allies lose extra morale when neighbor routs
	var allies: Array[BattleUnit] = state.attacker_units if unit.is_attacker else state.defender_units
	for u in allies:
		if u == unit or not u.is_alive() or u.is_routed:
			continue
		if u.row == unit.row:
			# Same row: -10 morale (panic spreads through the line)
			_reduce_morale(u, 10, state)
		else:
			# Other row: -5 morale (distant concern)
			_reduce_morale(u, 5, state)

## v7.0: When a unit kills an enemy, surviving same-side units gain morale.
## Killing a unit with a hero grants extra morale (hero kill bonus).
func _apply_kill_morale_boost(killer: BattleUnit, dead_unit: BattleUnit, state: BattleState) -> void:
	var allies: Array[BattleUnit] = state.attacker_units if killer.is_attacker else state.defender_units
	# Hero kill grants +10 morale to all allies; regular kill grants +5
	var boost: int = 10 if dead_unit.hero_id != "" else 5
	for u in allies:
		if u == killer or not u.is_alive() or u.is_routed:
			continue
		u.morale = mini(100, u.morale + boost)
		EventBus.unit_morale_changed.emit(u.troop_id, "attacker" if u.is_attacker else "defender", u.morale)
	var side_str: String = "attacker" if killer.is_attacker else "defender"
	state.action_log.append({
		"action": "morale",
		"side": side_str,
		"slot": killer.slot,
		"morale_type": "rally",
		"source": "kill",  # v7.0: tag so presentation can show golden rally burst
		"boost": boost,
		"desc": "%s 歼灭敌军，我方士气提升+%d!" % [killer.troop_id, boost],
	})


## When an ally dies, all surviving same-side units lose 15 morale.
## v4.3: If 50%+ of side's starting units are dead, remaining units lose extra morale.
func _apply_ally_death_morale(dead_unit: BattleUnit, state: BattleState) -> void:
	var allies: Array[BattleUnit] = state.attacker_units if dead_unit.is_attacker else state.defender_units
	var total_units: int = allies.size()
	var dead_count: int = 0
	for u in allies:
		if not u.is_alive():
			dead_count += 1
	# Base morale loss
	var base_loss: int = 15
	# v4.3: Escalating morale loss when heavy casualties taken
	if total_units > 0 and float(dead_count) / float(total_units) >= 0.5:
		base_loss = 25  # Heavy casualties: panic
	for u in allies:
		if u == dead_unit or not u.is_alive() or u.is_routed:
			continue
		_reduce_morale(u, base_loss, state)

## v4.4: kill_heal — when a unit with kill_heal passive kills an enemy, restore 1 soldier worth of HP.
## v4.5: kill_heal_2 — same but heals 2 soldiers.
func _apply_kill_heal(killer: BattleUnit, state: BattleState) -> void:
	var heal_soldiers: int = 0
	if killer.has_passive("kill_heal_2"):
		heal_soldiers = 2
	elif killer.has_passive("kill_heal"):
		heal_soldiers = 1
	if heal_soldiers == 0 or not killer.is_alive():
		return
	if killer.hp >= killer.max_hp:
		return
	var heal: int = killer.hp_per_soldier * heal_soldiers
	killer.hp = mini(killer.hp + heal, killer.max_hp)
	_recalc_soldiers(killer)
	var side_str: String = "attacker" if killer.is_attacker else "defender"
	state.action_log.append({
		"action": "passive",
		"event": "kill_heal",
		"unit": killer.id,
		"side": side_str,
		"slot": killer.slot,
		"healed": heal_soldiers,
		"desc": "%s 击杀回复 +%d兵" % [killer.troop_id, heal_soldiers],
	})

# ---------------------------------------------------------------------------
# Passive & Round Start Logic
# ---------------------------------------------------------------------------

func _apply_round_start_passives(state: BattleState) -> void:
	for u in state.attacker_units + state.defender_units:
		if not u.is_alive():
			continue
		
		# v4.4: regen_1 / deep_regen — restore soldiers each round
		var regen_amt := 0
		if u.has_passive("deep_regen"):
			regen_amt = 2
		elif u.has_passive("regen_1"):
			regen_amt = 1
		
		if regen_amt > 0 and u.soldiers < u.max_soldiers:
			u.hp = mini(u.max_hp, u.hp + regen_amt * u.hp_per_soldier)
			_recalc_soldiers(u)
			var side_str: String = "attacker" if u.is_attacker else "defender"
			state.action_log.append({
				"action": "heal",
				"unit": u.id,
				"side": side_str,
				"slot": u.slot,
				"healed": regen_amt,
				"desc": "%s 再生 +%d兵" % [u.troop_id, regen_amt],
			})

		# v4.5: poisoned_2 — take damage each round
		if u.has_passive("poisoned_2"):
			var poison_dmg := 1 * u.hp_per_soldier
			u.hp = maxi(0, u.hp - poison_dmg)
			_recalc_soldiers(u)
			var side_str: String = "attacker" if u.is_attacker else "defender"
			state.action_log.append({
				"action": "damage",
				"unit": u.id,
				"side": side_str,
				"slot": u.slot,
				"damage": 1,
				"desc": "%s 毒发损失 1兵" % u.troop_id,
			})
			# Check if unit died from poison
			if not u.is_alive():
				state.action_log.append({
					"action": "death",
					"unit": u.id,
					"side": side_str,
					"slot": u.slot,
					"desc": "%s 毒发身亡!" % u.troop_id,
				})
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
# Hero Skill Logic (v6.0)
# ---------------------------------------------------------------------------

func _tick_hero_skills(state: BattleState) -> void:
	# 1) Tick charges for all living heroes
	var atk_heroes: Array = []
	for u in state.attacker_units:
		if u.is_alive() and not u.hero_id.is_empty():
			HeroSkillsAdvanced.tick_charge(u.hero_id)
			atk_heroes.append(u.hero_id)
	
	var def_heroes: Array = []
	for u in state.defender_units:
		if u.is_alive() and not u.hero_id.is_empty():
			HeroSkillsAdvanced.tick_charge(u.hero_id)
			def_heroes.append(u.hero_id)

	# 2) Check awakening for all living heroes
	for u in state.attacker_units + state.defender_units:
		if not u.is_alive() or u.hero_id.is_empty():
			continue
		
		var hid: String = u.hero_id
		var side: String = "attacker" if u.is_attacker else "defender"
		
		if not HeroSkillsAdvanced.is_awakened(hid):
			var hp_ratio := float(u.soldiers) / float(u.max_soldiers)
			if HeroSkillsAdvanced.check_awakening(hid, hp_ratio):
				var awk: Dictionary = HeroSkillsAdvanced.trigger_awakening(hid)
				if not awk.is_empty():
					# Store pre-awakening stats
					u.set_meta("pre_awaken_atk", u.atk)
					u.set_meta("pre_awaken_def", u.def_stat)
					u.set_meta("pre_awaken_spd", u.spd)
					# Apply multipliers
					u.atk = int(float(u.atk) * awk.get("atk_mult", 1.0))
					u.def_stat = int(float(u.def_stat) * awk.get("def_mult", 1.0))
					u.spd = int(float(u.spd) * awk.get("spd_mult", 1.0))
					
					state.action_log.append({
						"action": "awakening",
						"hero_id": hid,
						"side": side,
						"slot": u.slot,
						"desc": "%s — %s!" % [u.troop_id, awk.get("name", "覚醒")],
					})

			# 3) Tick awakening duration
			if HeroSkillsAdvanced.is_awakened(hid):
				if not HeroSkillsAdvanced.tick_awakening(hid):
					# Revert to stored pre-awakening stats to avoid float drift
					if u.has_meta("pre_awaken_atk"):
						u.atk = u.get_meta("pre_awaken_atk")
						u.def_stat = u.get_meta("pre_awaken_def")
						u.spd = u.get_meta("pre_awaken_spd")
					else:
						var awk_data: Dictionary = HeroSkillsAdvanced.awakening_data.get(hid, {})
						if not awk_data.is_empty():
							u.atk /= awk_data.get("atk_mult", 1.0)
							u.def_stat /= awk_data.get("def_mult", 1.0)
							u.spd /= awk_data.get("spd_mult", 1.0)

			# 4) Execute charged ultimate
			if HeroSkillsAdvanced.is_charged(hid):
				var battle_dict: Dictionary = _state_to_resolver_dict(state)
				var ult_result: Dictionary = HeroSkillsAdvanced.execute_ultimate(hid, battle_dict)
				if ult_result.get("ok", false):
					ult_result["hero_id"] = hid
					_apply_ultimate_damage(state, ult_result, side)
					state.action_log.append({
						"action": "ultimate",
						"hero_id": hid,
						"side": side,
						"slot": u.slot,
						"desc": "%s 发动 %s!" % [u.troop_id, ult_result.get("name", "必杀技")],
						"damage": ult_result.get("total_damage", 0),
					})
					# Log buff/heal/freeze sub-effects from ultimates
					var ult_skill: Dictionary = HeroSkillsAdvanced.ultimate_skills.get(hid, {})
					var ult_effect: String = ult_skill.get("effect", "")
					if ult_effect == "buff_all":
						var allies: Array[BattleUnit] = state.attacker_units if side == "attacker" else state.defender_units
						for si in range(allies.size()):
							if allies[si].is_alive():
								state.action_log.append({"action": "buff", "side": side, "slot": si, "buff_type": "team_buff", "desc": "全体增益!"})
					elif ult_effect == "heal_all":
						var allies: Array[BattleUnit] = state.attacker_units if side == "attacker" else state.defender_units
						for si in range(allies.size()):
							if allies[si].is_alive():
								state.action_log.append({"action": "heal", "side": side, "slot": si, "is_mass": true, "desc": "全体治疗!"})
					elif ult_effect == "aoe_damage_freeze":
						var enemy_side: String = "defender" if side == "attacker" else "attacker"
						var enemies: Array[BattleUnit] = state.defender_units if side == "attacker" else state.attacker_units
						for si in range(enemies.size()):
							if enemies[si].is_alive():
								state.action_log.append({"action": "debuff", "side": enemy_side, "slot": si, "debuff_type": "freeze", "desc": "冻结!"})

		# 5) Tick and execute combo skills
		var army_heroes: Array = []
		for u2 in state.attacker_units:
			if u2.is_alive() and not u2.hero_id.is_empty():
				army_heroes.append(u2.hero_id)
		if not army_heroes.is_empty():
			HeroSkillsAdvanced.tick_combo_charges(army_heroes)
			var available_combos: Array = HeroSkillsAdvanced.check_available_combos(army_heroes)
			for combo_info in available_combos:
				if combo_info.get("charged", false):
					var cid: int = combo_info.get("combo_id", -1)
					var battle_dict: Dictionary = _state_to_resolver_dict(state)
					var combo_result: Dictionary = HeroSkillsAdvanced.execute_combo(cid, battle_dict)
					if combo_result.get("ok", false):
						_apply_ultimate_damage(state, combo_result, "attacker")
						state.action_log.append({
							"action": "combo",
							"combo_index": cid,
							"combo_name": combo_result.get("name", ""),
							"side": "attacker",
							"slot": 0,
							"desc": "连携技 %s 发动!" % combo_result.get("name", ""),
							"damage": combo_result.get("total_damage", 0),
						})
		# Same for defender combos
		var def_heroes: Array = []
		for u2 in state.defender_units:
			if u2.is_alive() and not u2.hero_id.is_empty():
				def_heroes.append(u2.hero_id)
		if not def_heroes.is_empty():
			HeroSkillsAdvanced.tick_combo_charges(def_heroes)
			var available_combos_d: Array = HeroSkillsAdvanced.check_available_combos(def_heroes)
			for combo_info in available_combos_d:
				if combo_info.get("charged", false):
					var cid: int = combo_info.get("combo_id", -1)
					var battle_dict: Dictionary = _state_to_resolver_dict(state)
					var combo_result: Dictionary = HeroSkillsAdvanced.execute_combo(cid, battle_dict)
					if combo_result.get("ok", false):
						_apply_ultimate_damage(state, combo_result, "defender")
						state.action_log.append({
							"action": "combo",
							"combo_index": cid,
							"combo_name": combo_result.get("name", ""),
							"side": "defender",
							"slot": 0,
							"desc": "连携技 %s 发动!" % combo_result.get("name", ""),
							"damage": combo_result.get("total_damage", 0),
						})


func _apply_ultimate_damage(state: BattleState, ult_result: Dictionary, caster_side: String) -> void:
	var targets_hit: Array = ult_result.get("targets_hit", [])
	var enemy_units: Array[BattleUnit] = state.defender_units if caster_side == "attacker" else state.attacker_units
	var ally_units: Array[BattleUnit] = state.attacker_units if caster_side == "attacker" else state.defender_units
	var enemy_side: String = "defender" if caster_side == "attacker" else "attacker"

	# v8.0 BUG FIX: build a shuffled living-enemy list so each targets_hit entry
	# hits a DISTINCT unit (round-robin) instead of re-picking randomly each time.
	var _ult_living: Array[BattleUnit] = []
	for eu in enemy_units:
		if eu.is_alive():
			_ult_living.append(eu)
	# Shuffle for random distribution
	_ult_living.shuffle()
	var _ult_hit_idx: int = 0

	# v10.0: drain_damage support
	var total_dmg_dealt: int = 0

	for hit in targets_hit:
		var dmg: int = hit.get("damage", 0)
		var healed: int = hit.get("healed", 0)
		if dmg > 0:
			# Refresh living list if we've cycled through all
			if _ult_hit_idx >= _ult_living.size():
				_ult_living.clear()
				for eu in enemy_units:
					if eu.is_alive():
						_ult_living.append(eu)
				_ult_living.shuffle()
				_ult_hit_idx = 0
			if not _ult_living.is_empty():
				var target: BattleUnit = _ult_living[_ult_hit_idx]
				_ult_hit_idx += 1
				# Apply damage through HP system to keep soldiers and HP in sync
				var hp_dmg: int = dmg * target.hp_per_soldier
				var was_alive: bool = target.is_alive()
				
				# v10.0: formation clash magic_damage_resist
				var clashes: Dictionary = FormationSystem.check_formation_clash(state.atk_formations, state.def_formations)
				var clash_key: String = "arcane_vs_holy_def" if caster_side == "attacker" else "arcane_vs_holy_atk"
				if clashes.has(clash_key):
					var resist: float = clashes[clash_key].get("magic_damage_resist", 0.0)
					if resist > 0:
						hp_dmg = int(float(hp_dmg) * (1.0 - resist))
				
				target.hp = maxi(0, target.hp - hp_dmg)
				var old_soldiers: int = target.soldiers
				_recalc_soldiers(target)
				var actual_lost: int = old_soldiers - target.soldiers
				total_dmg_dealt += actual_lost

				# Trigger death logging and morale cascades when ultimate kills a unit
				if was_alive and not target.is_alive():
					state.action_log.append({
						"action": "death",
						"unit": target.id,
						"side": enemy_side,
						"slot": target.slot,
						"round": state.round_number,
						"desc": "%s 被必杀技歼灭" % target.troop_id,
					})
					_apply_ally_death_morale(target, state)
					_revalidate_formations_for_side(target, state)
		elif healed > 0:
			# v8.0: heal logic for ultimates (e.g. akane)
			for au in ally_units:
				if au.is_alive() and au.soldiers < au.max_soldiers:
					var heal_hp: int = healed * au.hp_per_soldier
					au.hp = mini(au.hp + heal_hp, au.max_hp)
					_recalc_soldiers(au)
					state.action_log.append({
						"action": "heal",
						"unit": au.id,
						"side": caster_side,
						"slot": au.slot,
						"healed": healed,
						"remaining_soldiers": au.soldiers,
						"max_soldiers": au.max_soldiers,
						"desc": "%s 恢复了 %d 兵力" % [au.troop_id, healed],
					})

	# v10.0: drain_damage heal sync
	if total_dmg_dealt > 0:
		# Check if this was a drain_damage skill (e.g. mei, soul_binder)
		var ult_skill: Dictionary = HeroSkillsAdvanced.ultimate_skills.get(ult_result.get("hero_id", ""), {})
		if ult_skill.get("effect", "") == "drain_damage":
			var heal_per_unit: int = maxi(1, int(float(total_dmg_dealt) / float(maxi(1, ally_units.size()))))
			for au in ally_units:
				if au.is_alive() and au.soldiers < au.max_soldiers:
					var actual_heal: int = mini(heal_per_unit, au.max_soldiers - au.soldiers)
					au.hp = mini(au.max_hp, au.hp + actual_heal * au.hp_per_soldier)
					_recalc_soldiers(au)
					state.action_log.append({
						"action": "heal",
						"unit": au.id,
						"side": caster_side,
						"slot": au.slot,
						"healed": actual_heal,
						"remaining_soldiers": au.soldiers,
						"max_soldiers": au.max_soldiers,
						"desc": "%s 灵魂吸取回复 +%d兵" % [au.troop_id, actual_heal],
					})


func _state_to_resolver_dict(state: BattleState) -> Dictionary:
	var atk_units: Array = []
	for u in state.attacker_units:
		atk_units.append({
			"hero_id": u.hero_id, 
			"unit_type": u.troop_id,
			"soldiers": u.soldiers, 
			"max_soldiers": u.max_soldiers,
			"atk": u.atk, 
			"def": u.def_stat, 
			"mana": u.mana,
			"is_alive": u.is_alive(), 
			"side": "attacker"
		})
	var def_units: Array = []
	for u in state.defender_units:
		def_units.append({
			"hero_id": u.hero_id, 
			"unit_type": u.troop_id,
			"soldiers": u.soldiers, 
			"max_soldiers": u.max_soldiers,
			"atk": u.atk, 
			"def": u.def_stat, 
			"mana": u.mana,
			"is_alive": u.is_alive(), 
			"side": "defender"
		})
	return {
		"atk_units": atk_units, 
		"def_units": def_units, 
		"round": state.round_number,
		"atk_mana": state.mana_attacker,
		"def_mana": state.mana_defender
	}


func _calculate_damage(attacker: BattleUnit, defender: BattleUnit, state: BattleState, skill_mult: float = 1.0) -> int:
	var atk_val: int = attacker.atk
	var def_val: int = defender.def_stat

	# fort_def_3: +3 DEF when defending in owned node
	if defender.has_passive("fort_def_3") and not defender.is_attacker:
		def_val += 3

	# Terrain defense multiplier
	var terrain_def_mult := 1.0
	var tdata_dmg: Dictionary = FactionData.TERRAIN_DATA.get(state.terrain, {})
	if not defender.is_attacker:
		terrain_def_mult = tdata_dmg.get("def_mult", 1.0)
	def_val = int(float(def_val) * terrain_def_mult)

	# Design doc formula: max(1, ATK - DEF) — was incorrectly max(10, ...) which
	# made heavily-armored units take far too much damage (Bug fix Round 3).
	var raw_diff: int = maxi(1, atk_val - def_val)

	# SR07-style diminishing returns on troop count
	var troops := float(attacker.soldiers)
	var adjusted: float
	if troops <= 8.0:
		adjusted = troops
	elif troops <= 15.0:
		adjusted = 8.0 + (troops - 8.0) * 0.5
	else:
		adjusted = 11.5 + (troops - 15.0) * 0.25

	var base_damage: float = adjusted * float(raw_diff) / 100.0

	# Apply unit counter matrix multipliers (CounterMatrix)
	var _counter: Dictionary = CounterMatrix.get_counter(attacker.troop_id, defender.troop_id)
	if _counter["atk_mult"] != 1.0:
		var counter_atk: float = _counter["atk_mult"]
		# v4.4: rps_bonus — equipment passive enhances counter advantage
		if attacker.has_passive("rps_bonus") and counter_atk > 1.0:
			counter_atk += 0.15  # counter_tactics: +15% to counter multiplier
		base_damage *= counter_atk
	# BUG FIX: def_mult should multiply, not divide. def_mult < 1.0 reduces damage taken.
	if _counter["def_mult"] != 1.0:
		base_damage *= _counter["def_mult"]

	# v4.5: light_slayer (rin_sacred_blade) — +15% damage vs light faction units
	if attacker.has_passive("light_slayer"):
		var def_troop: String = defender.troop_id.to_lower()
		if def_troop.begins_with("elf_") or def_troop.begins_with("knight_") or def_troop.begins_with("human_") or def_troop.begins_with("temple_") or def_troop.begins_with("priest") or def_troop.begins_with("treant") or def_troop.begins_with("alliance_"):
			base_damage *= 1.15

	# v4.5: blood_oath — when unit is <50% soldiers, ATK×2 for damage calc
	if attacker.has_passive("blood_oath"):
		if float(attacker.soldiers) < float(attacker.max_soldiers) * 0.5:
			base_damage *= 2.0

	# v4.6: desert_mastery — ATK doubled on WASTELAND terrain
	if attacker.has_passive("desert_mastery"):
		if state.terrain == Terrain.WASTELAND:
			base_damage *= 2.0

	# v7.0: flanking_bonus — +20% damage when attacking back-row unit with no front-row cover
	# Simulates a collapsed frontline where back-row units are exposed and vulnerable.
	var _flanking_applied: bool = false
	if defender.row == 1:
		var enemy_units: Array[BattleUnit] = state.living_attackers() if defender.is_attacker else state.living_defenders()
		var has_front_cover: bool = false
		for eu in enemy_units:
			if eu.row == 0 and eu != defender:
				has_front_cover = true
				break
		if not has_front_cover:
			base_damage *= 1.20
			_flanking_applied = true

	# v10.0: shadow_ranged_dodge (Clash)
	if FormationSystem._is_ranged({"troop_id": attacker.troop_id}):
		var clashes: Dictionary = FormationSystem.check_formation_clash(state.atk_formations, state.def_formations)
		var clash_key: String = "arrow_vs_shadow_def" if attacker.is_attacker else "arrow_vs_shadow_atk"
		if clashes.has(clash_key):
			var dodge: float = clashes[clash_key].get("shadow_ranged_dodge", 0.0)
			if randf() < dodge:
				state.action_log.append({
					"action": "passive", "event": "shadow_dodge", "unit": defender.id,
					"side": "attacker" if defender.is_attacker else "defender", "slot": defender.slot,
					"desc": "%s 影袭闪避!" % defender.troop_id
				})
				return 0

	var final_damage: float = base_damage * skill_mult

	# Convert from "equivalent soldiers killed" to HP damage
	var soldiers_killed_equiv: int = int(floor(final_damage))
	if soldiers_killed_equiv < 1 and attacker.soldiers > 0:
		soldiers_killed_equiv = 1
	
	return soldiers_killed_equiv


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

	# 2) Ranged Double Attack (Round 1 & 2)
	# Handled in _execute_action by checking state.round_number and bonuses

	# 3) Heal per round
	var atk_heal: int = atk_bonuses.get("heal_per_round", 0)
	if atk_heal > 0:
		for u in state.attacker_units:
			if u.is_alive() and u.soldiers < u.max_soldiers:
				u.hp = mini(u.max_hp, u.hp + atk_heal * u.hp_per_soldier)
				_recalc_soldiers(u)
				state.action_log.append({
					"action": "heal", "unit": u.id, "side": "attacker", "slot": u.slot,
					"healed": atk_heal, "remaining_soldiers": u.soldiers, "max_soldiers": u.max_soldiers,
					"desc": "阵型回复: %s +%d兵" % [u.troop_id, atk_heal]
				})
	var def_heal: int = def_bonuses.get("heal_per_round", 0)
	if def_heal > 0:
		for u in state.defender_units:
			if u.is_alive() and u.soldiers < u.max_soldiers:
				u.hp = mini(u.max_hp, u.hp + def_heal * u.hp_per_soldier)
				_recalc_soldiers(u)
				state.action_log.append({
					"action": "heal", "unit": u.id, "side": "defender", "slot": u.slot,
					"healed": def_heal, "remaining_soldiers": u.soldiers, "max_soldiers": u.max_soldiers,
					"desc": "阵型回复: %s +%d兵" % [u.troop_id, def_heal]
				})

	# 4) Shadow Ranged Dodge (Clash)
	# Handled in _calculate_damage


func _apply_kill_heal(killer: BattleUnit, state: BattleState) -> void:
	var heal_soldiers: int = 0
	if killer.has_passive("kill_heal_2"):
		heal_soldiers = 2
	elif killer.has_passive("kill_heal"):
		heal_soldiers = 1
	if heal_soldiers == 0 or not killer.is_alive():
		return
	if killer.hp >= killer.max_hp:
		return
	var heal: int = killer.hp_per_soldier * heal_soldiers
	killer.hp = mini(killer.hp + heal, killer.max_hp)
	_recalc_soldiers(killer)
	var side_str: String = "attacker" if killer.is_attacker else "defender"
	state.action_log.append({
		"action": "passive",
		"event": "kill_heal",
		"unit": killer.id,
		"side": side_str,
		"slot": killer.slot,
		"healed": heal_soldiers,
		"desc": "%s 击杀回复 +%d兵" % [killer.troop_id, heal_soldiers],
	})


# ---------------------------------------------------------------------------
# Commander Intervention Helpers
# ---------------------------------------------------------------------------

func _build_intervention_state(state: BattleState) -> Dictionary:
	var res := _state_to_resolver_dict(state)
	res["is_siege"] = state.is_siege
	res["city_def"] = state.city_def
	return res

func _apply_intervention_results(state: BattleState, istate: Dictionary) -> void:
	# Sync units back
	for i in range(state.attacker_units.size()):
		var u := state.attacker_units[i]
		var d: Dictionary = istate["atk_units"][i]
		u.soldiers = d["soldiers"]
		u.hp = u.soldiers * u.hp_per_soldier
	for i in range(state.defender_units.size()):
		var u := state.defender_units[i]
		var d: Dictionary = istate["def_units"][i]
		u.soldiers = d["soldiers"]
		u.hp = u.soldiers * u.hp_per_soldier
	state.mana_attacker = istate.get("atk_mana", state.mana_attacker)
	state.mana_defender = istate.get("def_mana", state.mana_defender)
	state.city_def = istate.get("city_def", state.city_def)

func _tick_intervention_durations(state: BattleState) -> void:
	# Mirrors combat_resolver.gd _end_of_round()
	if _has_autoload("CommanderIntervention"):
		var ci := _get_autoload("CommanderIntervention")
		if ci and ci.has_method("tick_durations"):
			ci.tick_durations()

# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _get_active_skill(unit: BattleUnit) -> Dictionary:
	# Simplified skill lookup
	var hdata: Dictionary = FactionData.HEROES.get(unit.hero_id, {})
	if hdata.is_empty():
		return {}
	var skill_name: String = hdata.get("active", "")
	if skill_name == "":
		return {}
	# Map skill names to type/cost/cooldown (mirrors combat_resolver.gd)
	match skill_name:
		"圣光斩": return {"name": skill_name, "type": "damage", "mana_cost": 0, "cooldown": 2}
		"治愈之光": return {"name": skill_name, "type": "heal", "mana_cost": 0, "cooldown": 2}
		"突击号令": return {"name": skill_name, "type": "buff", "mana_cost": 0, "cooldown": 3}
		"不动如山": return {"name": skill_name, "type": "buff", "mana_cost": 0, "cooldown": 3}
		"箭雨": return {"name": skill_name, "type": "aoe", "mana_cost": 0, "cooldown": 3}
		"月光护盾": return {"name": skill_name, "type": "buff", "mana_cost": 3, "cooldown": 3}
		"影步": return {"name": skill_name, "type": "damage", "mana_cost": 0, "cooldown": 2}
		"流星火雨": return {"name": skill_name, "type": "aoe", "mana_cost": 8, "cooldown": 4}
		"时间减速": return {"name": skill_name, "type": "debuff", "mana_cost": 3, "cooldown": 3}
		"爆裂火球": return {"name": skill_name, "type": "damage", "mana_cost": 3, "cooldown": 2}
		"连射": return {"name": skill_name, "type": "damage", "mana_cost": 0, "cooldown": 2}
		"致命一击": return {"name": skill_name, "type": "damage", "mana_cost": 0, "cooldown": 2}
		"铁壁": return {"name": skill_name, "type": "buff", "mana_cost": 0, "cooldown": 2}
		"沙暴": return {"name": skill_name, "type": "debuff", "mana_cost": 0, "cooldown": 3}
		"亡灵召唤": return {"name": skill_name, "type": "summon", "mana_cost": 3, "cooldown": 4}
		"分身": return {"name": skill_name, "type": "buff", "mana_cost": 0, "cooldown": 3}
		"净化": return {"name": skill_name, "type": "heal", "mana_cost": 0, "cooldown": 2}
		"集中轰炸": return {"name": skill_name, "type": "damage", "mana_cost": 0, "cooldown": 3}
	return {"name": skill_name, "type": "damage", "mana_cost": 0, "cooldown": 3}


## Try to fetch an autoload node by name at runtime.
func _has_autoload(aname: String) -> bool:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var root: Node = (tree as SceneTree).root
		return root.has_node(aname)
	return false

func _get_autoload(aname: String) -> Node:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var root: Node = (tree as SceneTree).root
		if root.has_node(aname):
			return root.get_node(aname)
	return null


## Convert BattleUnit array to plain dictionaries for FormationSystem.
func _build_formation_dicts(units: Array[BattleUnit]) -> Array:
	var result: Array = []
	for u in units:
		if not u.is_alive():
			continue
		result.append({
			"id": u.id,
			"troop_id": u.troop_id,
			"unit_type": u.troop_id,
			"row": u.row,
			"slot": u.slot,
			"atk": u.atk,
			"def": u.def_stat,
			"spd": u.spd,
			"soldiers": u.soldiers,
			"max_soldiers": u.max_soldiers,
		})
	return result


## Sync formation bonus changes from plain dicts back to BattleUnit objects.
func _sync_formation_to_battle_units(units: Array[BattleUnit], dicts: Array) -> void:
	var dict_map: Dictionary = {}
	for d in dicts:
		dict_map[d["id"]] = d
	for u in units:
		if not u.is_alive():
			continue
		var d: Dictionary = dict_map.get(u.id, {})
		if d.is_empty():
			continue
		u.atk = d.get("atk", u.atk)
		u.def_stat = d.get("def", u.def_stat)
		u.spd = d.get("spd", u.spd)


## Revalidate formation bonuses after a unit dies.  If the side no longer
## qualifies for a formation it had at battle start, revert the stat bonuses
## that formation granted.
func _revalidate_formations_for_side(dead_unit: BattleUnit, state: BattleState) -> void:
	var is_atk: bool = dead_unit.is_attacker
	var side_units: Array[BattleUnit] = state.attacker_units if is_atk else state.defender_units
	var prev_formations: Array = state.atk_formations if is_atk else state.def_formations
	if prev_formations.is_empty():
		return
	var living_dicts: Array = _build_formation_dicts(side_units)
	var result: Dictionary = FormationSystem.revalidate_formations(
		living_dicts, state.terrain_str, prev_formations
	)
	var lost: Array = result["lost"]
	if lost.is_empty():
		return
	# Revert stat bonuses on the living unit dicts, then sync back
	FormationSystem.revert_formation_bonuses(living_dicts, lost)
	_sync_formation_to_battle_units(side_units, living_dicts)
