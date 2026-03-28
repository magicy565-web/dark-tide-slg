class_name CombatSystem
## Core battle resolution engine for a Sengoku Rance-style tactical strategy game.
## v2.0 — SR07+TW:W数值对齐

const FactionData = preload("res://systems/faction/faction_data.gd")
##
## Usage:
##   var combat = CombatSystem.new()
##   var result = combat.resolve_battle(attacker_army, defender_army, node_data)
##
## The returned Dictionary contains:
##   "winner"           – "attacker" or "defender"
##   "attacker_losses"  – { unit_id: soldiers_lost, ... }
##   "defender_losses"  – { unit_id: soldiers_lost, ... }
##   "captured_heroes"  – Array of commander_ids captured
##   "log"              – Array[Dictionary] of every action that occurred

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const MAX_ROUNDS := 12
const MAX_FRONT_SLOTS := 3
const MAX_BACK_SLOTS := 3
const MAX_SLOTS := 6  # front(3) + back(3), SR07 formation

# Terrain enum mirrors FactionData.TerrainType.  We reference FactionData at runtime but
# keep local copies so the file is self-documenting.
enum Terrain {
	PLAINS    = 0,
	FOREST    = 1,
	MOUNTAIN  = 2,
	SWAMP     = 3,
	COASTAL   = 4,
	FORTRESS  = 5,
	RIVER     = 6,
	RUINS     = 7,
	WASTELAND = 8,
	VOLCANIC  = 9,
}

# ---------------------------------------------------------------------------
# BattleUnit – represents one unit slot in battle
# ---------------------------------------------------------------------------

class BattleUnit:
	var id: String              ## Unique per-battle identifier
	var commander_id: String    ## Hero id or "generic"
	var troop_id: String        ## Key in GameData.TROOPS
	var atk: int
	var def_stat: int
	var spd: int
	var int_stat: int
	var soldiers: int
	var max_soldiers: int
	var row: int                ## 0 = front, 1 = back
	var slot: int               ## 0-4
	var passive: String         ## Passive effect key (may be comma-separated)
	var is_attacker: bool
	var has_acted: bool
	var first_attack: bool      ## True until the unit's first attack resolves
	var mana: int
	var hp: int = 0                  ## 当前总HP (soldiers × hp_per_soldier)
	var max_hp: int = 0              ## 最大总HP
	var hp_per_soldier: int = 5      ## 单兵HP (来自troop定义)
	var hero_hp: int = 0             ## 英雄个人HP池
	var hero_max_hp: int = 0
	var hero_mp: int = 0             ## 英雄MP池
	var hero_max_mp: int = 0
	var hero_id: String = ""         ## 英雄ID (空=无英雄指挥)
	var hero_knocked_out: bool = false  ## 英雄被击倒 (失去被动加成)
	var morale: int = 100               ## 士气 (0 = rout)
	var is_routed: bool = false          ## 已溃败
	var exp: int = 0                     ## 累积经验值 (老兵/精锐判定用)
	var _death_resist_used: bool = false  ## v4.5: death_resist one-time trigger flag
	var _ghost_shield_active: bool = false ## v4.5: ghost_shield first-hit immunity flag
	var _dragon_slayer_bonus: int = 0     ## v4.5: dragon_slayer accumulated ATK bonus

	## Convenience: unit is alive if it has HP remaining.
	func is_alive() -> bool:
		return hp > 0

	## Check whether the unit possesses a specific passive tag.
	func has_passive(p: String) -> bool:
		for tag in passive.split(","):
			if tag.strip_edges() == p:
				return true
		return false

# ---------------------------------------------------------------------------
# BattleState – full battle context for the current engagement
# ---------------------------------------------------------------------------

class BattleState:
	var attacker_units: Array[BattleUnit] = []
	var defender_units: Array[BattleUnit] = []
	var terrain: int            ## One of the Terrain enum values
	var round_number: int = 0
	var action_log: Array[Dictionary] = []
	var is_siege: bool = false
	var city_def: int = 0
	var mana_attacker: int = 0
	var mana_defender: int = 0

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
	var _fs := FormationSystem.new()
	var atk_unit_dicts: Array = _build_formation_dicts(state.attacker_units)
	var def_unit_dicts: Array = _build_formation_dicts(state.defender_units)
	var terrain_str: String = FactionData.TERRAIN_DATA.get(state.terrain, {}).get("name", "plains")
	var atk_formations: Array = _fs.detect_formations(atk_unit_dicts, terrain_str)
	var def_formations: Array = _fs.detect_formations(def_unit_dicts, terrain_str)
	if not atk_formations.is_empty():
		var atk_bonuses: Dictionary = _fs.get_formation_bonuses(atk_formations)
		_fs.apply_formation_to_units(atk_unit_dicts, atk_bonuses)
		_sync_formation_to_battle_units(state.attacker_units, atk_unit_dicts)
		_fs.emit_formation_detected("attacker", atk_formations)
	if not def_formations.is_empty():
		var def_bonuses: Dictionary = _fs.get_formation_bonuses(def_formations)
		_fs.apply_formation_to_units(def_unit_dicts, def_bonuses)
		_sync_formation_to_battle_units(state.defender_units, def_unit_dicts)
		_fs.emit_formation_detected("defender", def_formations)
	# Check formation clashes
	var clashes: Dictionary = _fs.check_formation_clash(atk_formations, def_formations)
	if not clashes.is_empty():
		_fs.emit_formation_clashes(clashes)

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
		bu.exp = d.get("exp", 0)

		# Pull troop base stats from GameData autoload if available.
		# NOTE: Skipped — input atk/def already includes base stats from
		# recruit_manager.get_combat_units(). Adding them again would double-dip.

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
		if bu.exp >= BalanceConfig.ELITE_EXP_THRESHOLD:
			bu.atk += BalanceConfig.ELITE_ATK_BONUS
			bu.def_stat += BalanceConfig.ELITE_DEF_BONUS
			bu.morale = mini(100, bu.morale + BalanceConfig.ELITE_MORALE_BONUS)
		elif bu.exp >= BalanceConfig.VETERAN_EXP_THRESHOLD:
			bu.atk += BalanceConfig.VETERAN_ATK_BONUS
			bu.morale = mini(100, bu.morale + BalanceConfig.VETERAN_MORALE_BONUS)

		# v4.3: Tile development combat bonuses (military tiles buff garrison)
		if tile_bonuses.get("atk", 0) > 0:
			bu.atk += tile_bonuses["atk"]
		if tile_bonuses.get("morale", 0) > 0:
			bu.morale = mini(100, bu.morale + tile_bonuses["morale"])

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
			"hp": u.hp,
			"max_hp": u.max_hp,
			"hp_per_soldier": u.hp_per_soldier,
			"hero_hp": u.hero_hp,
			"hero_max_hp": u.hero_max_hp,
			"hero_id": u.hero_id,
			"row": u.row,
			"slot": u.slot,
			"passive": u.passive,
			"class": _infer_unit_class(u.troop_id),
			"morale": u.morale,
			"is_routed": u.is_routed,
		})
	return snap


## Build a dict-based state that CommanderIntervention.execute() can work with.
## This bridges BattleState (objects) <-> intervention system (dicts).
func _build_intervention_state(state: BattleState) -> Dictionary:
	var atk_units: Array = []
	for u in state.attacker_units:
		atk_units.append({
			"slot": u.slot, "row": "front" if u.row == 0 else "back",
			"unit_type": u.troop_id, "soldiers": u.soldiers, "max_soldiers": u.max_soldiers,
			"atk": u.atk, "def": u.def_stat, "spd": u.spd,
			"is_alive": u.is_alive(), "morale": u.morale, "is_routed": u.is_routed,
			"hero_id": u.hero_id, "active_skill": {},
			"buffs": [], "passives": u.passive.split(","),
		})
	var def_units: Array = []
	for u in state.defender_units:
		def_units.append({
			"slot": u.slot, "row": "front" if u.row == 0 else "back",
			"unit_type": u.troop_id, "soldiers": u.soldiers, "max_soldiers": u.max_soldiers,
			"atk": u.atk, "def": u.def_stat, "spd": u.spd,
			"is_alive": u.is_alive(), "morale": u.morale, "is_routed": u.is_routed,
			"hero_id": u.hero_id,
			"buffs": [], "passives": u.passive.split(","),
		})
	return {"atk_units": atk_units, "def_units": def_units, "_intervention_log_ref": []}


## Apply intervention results (mutations to the bridge dict) back to BattleUnit objects.
func _apply_intervention_results(state: BattleState, istate: Dictionary) -> void:
	# Sync attacker units
	for d in istate["atk_units"]:
		for u in state.attacker_units:
			if u.slot == d["slot"]:
				u.soldiers = d["soldiers"]
				u.hp = u.soldiers * u.hp_per_soldier
				if d["soldiers"] <= 0:
					u.soldiers = 0
					u.hp = 0
				u.row = 0 if d["row"] == "front" else 1
				# Sync morale from intervention (rally can restore morale)
				if d.has("morale"):
					u.morale = clampi(d["morale"], 0, 100)
					if u.is_routed and u.morale > 0:
						u.is_routed = false  # Rally un-routs the unit
				# Apply ATK/DEF buffs as flat modifications
				for buff in d.get("buffs", []):
					if buff.get("mult_atk", false):
						u.atk = int(float(u.atk) * (1.0 + buff.get("value", 0.0)))
					if buff.get("mult_def", false):
						u.def_stat = int(float(u.def_stat) * (1.0 + buff.get("value", 0.0)))
				break


## Infer a display class from troop_id for color coding in combat view.
func _infer_unit_class(troop_id: String) -> String:
	if troop_id.find("ashigaru") != -1: return "ashigaru"
	if troop_id.find("samurai") != -1: return "samurai"
	if troop_id.find("cavalry") != -1 or troop_id.find("rider") != -1: return "cavalry"
	if troop_id.find("archer") != -1 or troop_id.find("ranger") != -1: return "archer"
	if troop_id.find("cannon") != -1 or troop_id.find("bombardier") != -1: return "cannon"
	if troop_id.find("ninja") != -1 or troop_id.find("assassin") != -1: return "ninja"
	if troop_id.find("mage") != -1 or troop_id.find("apprentice") != -1: return "mage"
	return "special"

# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------

## Apply permanent terrain modifiers to all units at battle start.
func _apply_terrain_modifiers(state: BattleState) -> void:
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(state.terrain, {})
	var unit_mods_map: Dictionary = terrain_data.get("unit_mods", {})
	var all_units: Array = []
	all_units.append_array(state.attacker_units)
	all_units.append_array(state.defender_units)
	for u in all_units:
		var ignore: bool = u.has_passive("ignore_terrain")
		# Determine troop class from troop_id field
		var tclass: String = _get_unit_terrain_class(u)
		var mods: Dictionary = unit_mods_map.get(tclass, {})
		if mods.get("ban", false) and not ignore:
			u.soldiers = 0
			u.hp = 0
			_recalc_soldiers(u)
			continue
		if not ignore:
			u.atk += mods.get("atk", 0)
			u.def_stat += mods.get("def", 0)
			u.spd += mods.get("spd", 0)
		else:
			# ignore_terrain: only apply positive mods
			if mods.get("atk", 0) > 0: u.atk += mods["atk"]
			if mods.get("def", 0) > 0: u.def_stat += mods["def"]
			if mods.get("spd", 0) > 0: u.spd += mods["spd"]


## Map a BattleUnit's troop_id to a terrain modifier class key.
func _get_unit_terrain_class(u: BattleUnit) -> String:
	var troop := u.troop_id.to_lower()
	if troop.find("cavalry") != -1 or troop.find("rider") != -1: return "cavalry"
	if troop.find("archer") != -1 or troop.find("ranger") != -1: return "archer"
	if troop.find("ninja") != -1 or troop.find("assassin") != -1: return "ninja"
	if troop.find("cannon") != -1 or troop.find("bombardier") != -1: return "cannon"
	if troop.find("mage") != -1 or troop.find("apprentice") != -1: return "mage_unit"
	if troop.find("priest") != -1: return "priest"
	if troop.find("samurai") != -1: return "samurai"
	if troop.find("ashigaru") != -1: return "ashigaru"
	return "ashigaru"

# ---------------------------------------------------------------------------
# Siege Phase
# ---------------------------------------------------------------------------

## If the node has city defenses, the attacker chips at walls before melee.
## Units with siege_x2 do double damage to the wall.
func _resolve_siege_phase(state: BattleState) -> void:
	for u in state.attacker_units:
		if not u.is_alive():
			continue
		var siege_dmg: int = u.atk
		if u.has_passive("siege_x2"):
			siege_dmg *= 2
		# v4.6: siege_bonus — extra flat siege damage from equipment
		if u.has_passive("siege_bonus"):
			siege_dmg += 10
		state.city_def = max(0, state.city_def - siege_dmg)

		state.action_log.append({
			"action": "siege",
			"phase": "siege",
			"unit": u.id,
			"side": "attacker",
			"slot": u.slot,
			"damage_to_wall": siege_dmg,
			"wall_remaining": state.city_def,
			"desc": "%s 攻城，对城墙造成%d伤害（剩余%d）" % [u.troop_id, siege_dmg, state.city_def],
		})

		if state.city_def <= 0:
			break

	# If walls still stand, defender gets a scaled DEF bonus for remaining wall HP.
	# Cap the bonus to avoid absurd values (e.g. 50HP wall giving +50 DEF).
	if state.city_def > 0:
		var wall_bonus: int = mini(state.city_def / 5, 10)
		for u in state.defender_units:
			u.def_stat += wall_bonus

# ---------------------------------------------------------------------------
# Preemptive Phase
# ---------------------------------------------------------------------------

## Units with "preemptive" or "preemptive_1_3" attack before the main queue.
func _resolve_preemptive_phase(state: BattleState) -> void:
	var pre_units: Array[BattleUnit] = []

	var all_units: Array[BattleUnit] = []
	all_units.append_array(state.attacker_units)
	all_units.append_array(state.defender_units)

	for u in all_units:
		if u.is_alive() and (u.has_passive("preemptive") or u.has_passive("preemptive_1_3")):
			pre_units.append(u)

	# Sort preemptive units by SPD descending; assign random tiebreak keys first
	# so the comparator is consistent (randi() inside sort_custom is non-deterministic
	# and can cause infinite loops or incorrect ordering — Bug fix Round 3).
	var _pre_tiebreak: Dictionary = {}
	for u in pre_units:
		_pre_tiebreak[u.id] = randi()
	pre_units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.spd != b.spd:
			return a.spd > b.spd
		return _pre_tiebreak[a.id] > _pre_tiebreak[b.id]
	)

	for u in pre_units:
		if not u.is_alive():
			continue
		var enemies := _get_enemies(u, state)
		if enemies.is_empty():
			continue
		var target := _select_target(u, enemies)
		if target == null:
			continue

		var mult := 1.3 if u.has_passive("preemptive_1_3") else 1.0
		var dmg := _calculate_damage(u, target, state, mult)
		_apply_damage(target, dmg, state, u)

		var _pre_side := "attacker" if u.is_attacker else "defender"
		var _pre_tgt_side := "attacker" if target.is_attacker else "defender"
		state.action_log.append({
			"action": "attack",
			"phase": "preemptive",
			"unit": u.id,
			"side": _pre_side,
			"slot": u.slot,
			"target": target.id,
			"target_side": _pre_tgt_side,
			"target_slot": target.slot,
			"target_name": target.troop_id,
			"damage": dmg,
			"remaining_soldiers": target.soldiers,
			"max_soldiers": target.max_soldiers,
			"round": state.round_number,
			"desc": "%s 先制攻击 %s" % [u.troop_id, target.troop_id],
		})

		# On-hit passives (counter, etc.)
		_apply_passive_on_hit(u, target, dmg, state)

# ---------------------------------------------------------------------------
# Round Start Passives
# ---------------------------------------------------------------------------

func _apply_round_start_passives(state: BattleState) -> void:
	var all_units: Array[BattleUnit] = []
	all_units.append_array(state.attacker_units)
	all_units.append_array(state.defender_units)

	for u in all_units:
		if not u.is_alive():
			continue

		# regen_1: restore 1 soldier worth of HP at start of round (up to max)
		if u.has_passive("regen_1"):
			u.hp = mini(u.hp + u.hp_per_soldier, u.max_hp)
			_recalc_soldiers(u)

		# charge_mana_1: gain 1 mana per round
		if u.has_passive("charge_mana_1"):
			u.mana += 1
			# Also contribute to the team pool
			var current := state.get_mana(u.is_attacker)
			state.set_mana(u.is_attacker, current + 1)

		# v4.6: mana_regen — +2 mana to team pool per round
		if u.has_passive("mana_regen"):
			var mr_current := state.get_mana(u.is_attacker)
			state.set_mana(u.is_attacker, mr_current + 2)

		# v4.6: regen_aura — heal 1 soldier (1 hp_per_soldier HP) to most damaged friendly unit
		if u.has_passive("regen_aura"):
			var ra_allies: Array[BattleUnit] = state.attacker_units if u.is_attacker else state.defender_units
			var ra_best: BattleUnit = null
			var ra_best_ratio: float = 1.0
			for ra_ally in ra_allies:
				if not ra_ally.is_alive() or ra_ally.hp >= ra_ally.max_hp:
					continue
				var ra_ratio: float = float(ra_ally.hp) / float(maxi(ra_ally.max_hp, 1))
				if ra_ratio < ra_best_ratio:
					ra_best_ratio = ra_ratio
					ra_best = ra_ally
			if ra_best != null:
				ra_best.hp = mini(ra_best.hp + ra_best.hp_per_soldier, ra_best.max_hp)
				_recalc_soldiers(ra_best)
				var _ra_side := "attacker" if u.is_attacker else "defender"
				state.action_log.append({
					"action": "passive",
					"event": "regen_aura",
					"unit": u.id,
					"side": _ra_side,
					"slot": u.slot,
					"desc": "%s 再生光环: %s +1兵" % [u.troop_id, ra_best.troop_id],
				})

		# v4.6: poisoned_2 / poisoned_1 — poison DOT tick (1 hp_per_soldier damage/round)
		if u.has_passive("poisoned_2") or u.has_passive("poisoned_1"):
			var poison_dmg: int = u.hp_per_soldier  # 1 soldier worth of HP
			u.hp = maxi(0, u.hp - poison_dmg)
			_recalc_soldiers(u)
			var _poison_side := "attacker" if u.is_attacker else "defender"
			state.action_log.append({
				"action": "passive",
				"event": "poison_dot",
				"unit": u.id,
				"side": _poison_side,
				"slot": u.slot,
				"desc": "%s 中毒! -%d HP" % [u.troop_id, poison_dmg],
			})
			# Decrement poison duration: poisoned_2 -> poisoned_1 -> remove
			if u.has_passive("poisoned_2"):
				var _new_passive: String = u.passive.replace("poisoned_2", "poisoned_1")
				u.passive = _new_passive
			elif u.has_passive("poisoned_1"):
				var _new_passive2: String = u.passive.replace("poisoned_1", "")
				# Clean up trailing/leading commas
				_new_passive2 = _new_passive2.replace(",,", ",").strip_edges()
				if _new_passive2.begins_with(","):
					_new_passive2 = _new_passive2.substr(1)
				if _new_passive2.ends_with(","):
					_new_passive2 = _new_passive2.substr(0, _new_passive2.length() - 1)
				u.passive = _new_passive2

# ---------------------------------------------------------------------------
# Action Queue
# ---------------------------------------------------------------------------

## Build the action queue for the current round.  All living units sorted by
## SPD descending.  Preemptive units are NOT given priority here – they already
## acted in the preemptive phase (only relevant in round 0/pre-battle).
func _get_action_queue(state: BattleState) -> Array[BattleUnit]:
	var queue: Array[BattleUnit] = []

	for u in state.attacker_units:
		if u.is_alive() and not u.is_routed:
			queue.append(u)
	for u in state.defender_units:
		if u.is_alive() and not u.is_routed:
			queue.append(u)

	# Sort by SPD descending; assign random tiebreak keys before sorting so the
	# comparator is consistent (randi() inside sort_custom is non-deterministic
	# and can cause infinite loops or incorrect ordering — Bug fix Round 3).
	var _tiebreak: Dictionary = {}
	for u in queue:
		_tiebreak[u.id] = randi()
	queue.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.spd != b.spd:
			return a.spd > b.spd
		return _tiebreak[a.id] > _tiebreak[b.id]
	)

	return queue

# ---------------------------------------------------------------------------
# Execute Action
# ---------------------------------------------------------------------------

## A unit performs its action for this round.  Currently all AI-controlled
## units simply attack (or use AoE if they have mana and the passive).
func _execute_action(unit: BattleUnit, state: BattleState) -> Dictionary:
	unit.has_acted = true

	var _unit_side := "attacker" if unit.is_attacker else "defender"

	var enemies := _get_enemies(unit, state)
	if enemies.is_empty():
		return { "action": "idle", "unit": unit.id, "side": _unit_side, "slot": unit.slot, "reason": "no_targets", "desc": "%s 无目标" % unit.troop_id }

	# ---- Decide whether to use AoE skill ---------------------------------
	var use_aoe := false
	var aoe_mult := 1.0
	var aoe_cost := 0

	if unit.has_passive("aoe_mana"):
		aoe_cost = 5
		aoe_mult = 1.0
		if state.get_mana(unit.is_attacker) >= aoe_cost:
			use_aoe = true

	if unit.has_passive("aoe_1_5_cost5"):
		aoe_cost = 5
		aoe_mult = 1.5
		if state.get_mana(unit.is_attacker) >= aoe_cost:
			use_aoe = true

	# ---- AoE path ---------------------------------------------------------
	if use_aoe:
		state.set_mana(unit.is_attacker, state.get_mana(unit.is_attacker) - aoe_cost)
		# Determine target row – prefer front if it has living units.
		var target_row := _pick_aoe_target_row(unit, enemies)
		var row_targets: Array[BattleUnit] = []
		for e in enemies:
			if e.row == target_row:
				row_targets.append(e)
		if row_targets.is_empty():
			# Fallback: hit any living enemies
			row_targets = enemies

		var total_dmg := 0
		var sub_log: Array[Dictionary] = []
		for t in row_targets:
			var skill_mult := aoe_mult
			# charge_1_5 bonus on first attack
			if unit.first_attack and unit.has_passive("charge_1_5"):
				skill_mult *= 1.5
			var dmg := _calculate_damage(unit, t, state, skill_mult)
			_apply_damage(t, dmg, state, unit)
			total_dmg += dmg
			var _aoe_tgt_side := "attacker" if t.is_attacker else "defender"
			sub_log.append({ "target": t.id, "damage": dmg, "remaining_soldiers": t.soldiers, "target_side": _aoe_tgt_side, "target_slot": t.slot, "target_name": t.troop_id, "max_soldiers": t.max_soldiers })
			_apply_passive_on_hit(unit, t, dmg, state)
			# Emit death entry if target died
			if t.soldiers <= 0:
				state.action_log.append({
					"action": "death",
					"unit": t.id,
					"side": _aoe_tgt_side,
					"slot": t.slot,
					"round": state.round_number,
					"desc": "%s 被歼灭" % t.troop_id,
				})
				# Allies lose morale when a comrade is eliminated
				_apply_ally_death_morale(t, state)
				# v4.4: kill_heal — attacker restores 1 soldier on kill (blood_moon_blade)
				_apply_kill_heal(unit, state)
				# v4.5: dragon_slayer — on kill, ATK+1 permanently for battle
				_apply_dragon_slayer(unit, state)

		unit.first_attack = false
		# Emit one attack entry per AoE target for combat_view compatibility
		for _aoe_entry in sub_log:
			state.action_log.append({
				"action": "attack",
				"unit": unit.id,
				"side": _unit_side,
				"slot": unit.slot,
				"target": _aoe_entry["target"],
				"target_side": _aoe_entry["target_side"],
				"target_slot": _aoe_entry["target_slot"],
				"target_name": _aoe_entry["target_name"],
				"damage": _aoe_entry["damage"],
				"remaining_soldiers": _aoe_entry["remaining_soldiers"],
				"max_soldiers": _aoe_entry["max_soldiers"],
				"round": state.round_number,
				"desc": "%s 范围攻击 %s" % [unit.troop_id, _aoe_entry["target_name"]],
			})
		return { "action": "_already_logged" }

	# ---- Normal single-target attack --------------------------------------
	var target := _select_target(unit, enemies)
	if target == null:
		return { "action": "idle", "unit": unit.id, "side": _unit_side, "slot": unit.slot, "reason": "no_valid_target", "desc": "%s 无有效目标" % unit.troop_id }

	var skill_mult := 1.0
	# charge_1_5: first attack deals x1.5 damage
	if unit.first_attack and unit.has_passive("charge_1_5"):
		skill_mult = 1.5

	var dmg := _calculate_damage(unit, target, state, skill_mult)
	_apply_damage(target, dmg, state, unit)
	unit.first_attack = false

	var _target_side := "attacker" if target.is_attacker else "defender"
	var entry := {
		"action": "attack",
		"unit": unit.id,
		"side": _unit_side,
		"slot": unit.slot,
		"target": target.id,
		"target_side": _target_side,
		"target_slot": target.slot,
		"target_name": target.troop_id,
		"damage": dmg,
		"remaining_soldiers": target.soldiers,
		"max_soldiers": target.max_soldiers,
		"round": state.round_number,
		"desc": "%s 攻击 %s" % [unit.troop_id, target.troop_id],
	}

	# On-hit passives (counter, death_burst, etc.)
	_apply_passive_on_hit(unit, target, dmg, state)

	# Emit death entry if target died
	if target.soldiers <= 0:
		state.action_log.append(entry)
		state.action_log.append({
			"action": "death",
			"unit": target.id,
			"side": _target_side,
			"slot": target.slot,
			"round": state.round_number,
			"desc": "%s 被歼灭" % target.troop_id,
		})
		# Allies lose morale when a comrade is eliminated
		_apply_ally_death_morale(target, state)
		# v4.4: kill_heal — attacker restores 1 soldier on kill (blood_moon_blade)
		_apply_kill_heal(unit, state)
		# v4.5: dragon_slayer — on kill, ATK+1 permanently for battle
		_apply_dragon_slayer(unit, state)
		return { "action": "_already_logged" }

	return entry

# ---------------------------------------------------------------------------
# Damage Calculation
# ---------------------------------------------------------------------------

## Core damage formula (SR07-style percentage-based).
## base_damage = adjusted_soldiers * max(10, ATK - DEF) / 100.0
## final_damage = base_damage * skill_multiplier
## Result is HP damage (soldiers_killed equivalent × target hp_per_soldier).
##
## SR07 diminishing returns on troop count:
##   0-8 troops: value = troops (1:1)
##   9-15 troops: value = 8 + (troops-8)*0.5
##   16+: value = 11.5 + (troops-15)*0.25
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
	# def_mult < 1.0 means attacker takes less damage; > 1.0 means more.
	# Translate to defender effectiveness: scale defender's contribution inversely.
	if _counter["def_mult"] != 1.0:
		base_damage /= _counter["def_mult"]

	# v4.5: light_slayer (rin_sacred_blade) — +15% damage vs light faction units
	if attacker.has_passive("light_slayer"):
		var def_troop: String = defender.troop_id.to_lower()
		if def_troop.begins_with("elf_") or def_troop.begins_with("knight_") or def_troop.begins_with("human_") or def_troop.begins_with("temple_") or def_troop.begins_with("priest") or def_troop.begins_with("treant") or def_troop.begins_with("alliance_"):
			base_damage *= 1.15

	# v4.5: blood_oath — when unit is <50% soldiers, ATK×2 for damage calc
	if attacker.has_passive("blood_oath"):
		if float(attacker.soldiers) < float(attacker.max_soldiers) * 0.5:
			base_damage *= 2.0

	# v4.5: dragon_slayer — ATK bonus already applied permanently in _apply_dragon_slayer().
	# _dragon_slayer_bonus is tracked for logging only; no extra damage calc needed here.

	# v4.6: desert_mastery — ATK doubled on WASTELAND terrain
	if attacker.has_passive("desert_mastery"):
		if state.terrain == Terrain.WASTELAND:
			base_damage *= 2.0

	var final_damage: float = base_damage * skill_mult

	# Convert from "equivalent soldiers killed" to HP damage
	var soldiers_killed_equiv: int = int(floor(final_damage))
	if soldiers_killed_equiv < 1 and attacker.soldiers > 0:
		soldiers_killed_equiv = 1

	var hp_damage: int = soldiers_killed_equiv * defender.hp_per_soldier

	# Minimum 1 HP damage if the attacker is alive
	if hp_damage < 1 and attacker.soldiers > 0:
		hp_damage = 1

	return hp_damage

# ---------------------------------------------------------------------------
# Damage Application
# ---------------------------------------------------------------------------

## Apply damage (HP loss) to a unit, respecting escape_30 passive.
func _apply_damage(target: BattleUnit, damage: int, state: BattleState, attacker: BattleUnit = null) -> void:
	if damage <= 0:
		return

	# v4.5: ghost_shield — first hit immunity (absorb full damage once)
	if target._ghost_shield_active and target.has_passive("ghost_shield"):
		target._ghost_shield_active = false
		var _gs_side := "attacker" if target.is_attacker else "defender"
		state.action_log.append({
			"action": "passive",
			"event": "ghost_shield",
			"unit": target.id,
			"side": _gs_side,
			"slot": target.slot,
			"desc": "%s 幽灵护盾吸收了首次攻击!" % target.troop_id,
		})
		return

	# v4.5: ranged_dodge (pirate_ghost_ship_coat) — 30% dodge vs ranged attacks
	if attacker != null and target.has_passive("ranged_dodge"):
		var atk_troop: String = attacker.troop_id.to_lower()
		var is_ranged: bool = atk_troop.find("archer") != -1 or atk_troop.find("ranger") != -1 or atk_troop.find("mage") != -1 or atk_troop.find("cannon") != -1 or atk_troop.find("bombardier") != -1 or atk_troop.find("gunner") != -1
		if is_ranged and randf() < 0.30:
			var _rd_side := "attacker" if target.is_attacker else "defender"
			state.action_log.append({
				"action": "passive",
				"event": "ranged_dodge",
				"unit": target.id,
				"side": _rd_side,
				"slot": target.slot,
				"desc": "%s 闪避了远程攻击!" % target.troop_id,
			})
			return

	var new_hp: int = target.hp - damage

	# v4.6: damage_reduce — reduce incoming damage by 20%
	if target.has_passive("damage_reduce"):
		damage = maxi(1, int(float(damage) * 0.80))
		new_hp = target.hp - damage

	# escape_30: 30% chance to survive lethal damage (kept at 1 soldier / hp_per_soldier HP)
	if new_hp <= 0 and target.has_passive("escape_30"):
		if randf() < 0.30:
			target.hp = target.hp_per_soldier
			target.soldiers = 1
			var _esc_side := "attacker" if target.is_attacker else "defender"
			state.action_log.append({
				"action": "passive",
				"event": "escape_30_triggered",
				"unit": target.id,
				"side": _esc_side,
				"slot": target.slot,
				"remaining_soldiers": 1,
				"max_soldiers": target.max_soldiers,
				"hp": target.hp,
				"max_hp": target.max_hp,
				"desc": "%s 触发逃脱被动，保留1兵" % target.troop_id,
			})
			return

	# v4.5: death_resist (orc_iron_jaw_plate) — 100% survive lethal with 1 soldier, once per battle
	if new_hp <= 0 and target.has_passive("death_resist") and not target._death_resist_used:
		target._death_resist_used = true
		target.hp = target.hp_per_soldier
		target.soldiers = 1
		var _dr_side := "attacker" if target.is_attacker else "defender"
		state.action_log.append({
			"action": "passive",
			"event": "death_resist_triggered",
			"unit": target.id,
			"side": _dr_side,
			"slot": target.slot,
			"remaining_soldiers": 1,
			"max_soldiers": target.max_soldiers,
			"hp": target.hp,
			"max_hp": target.max_hp,
			"desc": "%s 铁颚板甲: 抵抗致命伤害，保留1兵!" % target.troop_id,
		})
		return

	target.hp = maxi(0, new_hp)
	_recalc_soldiers(target)

	# Morale loss on significant hit (5+ HP damage = significant)
	if damage >= 5 and target.is_alive() and not target.is_routed:
		_reduce_morale(target, 5, state)

	# death_burst: on death, deal ATK*2 HP to all living enemies
	if target.hp <= 0 and target.has_passive("death_burst"):
		_trigger_death_burst(target, state)

## death_burst: deal ATK*2 HP damage to every living enemy unit.
func _trigger_death_burst(dead_unit: BattleUnit, state: BattleState) -> void:
	var burst_dmg: int = dead_unit.atk * 2
	var enemies := _get_enemies(dead_unit, state)

	for e in enemies:
		e.hp = maxi(0, e.hp - burst_dmg)
		_recalc_soldiers(e)

	var _db_side := "attacker" if dead_unit.is_attacker else "defender"
	state.action_log.append({
		"action": "passive",
		"event": "death_burst",
		"unit": dead_unit.id,
		"side": _db_side,
		"slot": dead_unit.slot,
		"damage_each": burst_dmg,
		"targets_hit": enemies.size(),
		"desc": "%s 死亡爆发，对%d个敌方各造成%d伤害" % [dead_unit.troop_id, enemies.size(), burst_dmg],
	})

# ---------------------------------------------------------------------------
# Targeting
# ---------------------------------------------------------------------------

## Select the best target for a given attacker from the list of living enemies.
##
## Rules:
##   1. Taunt units must be targeted first.
##   2. Front-row melee units target enemy front row first.
##   3. Back-row ranged (archer/mage/cannon) can target any row.
##   4. Ninja / assassinate_back bypasses front row to hit back row.
##   5. If the front row is empty, back row becomes targetable by melee.
func _select_target(attacker: BattleUnit, enemies: Array[BattleUnit]) -> BattleUnit:
	if enemies.is_empty():
		return null

	# --- 1. Taunt check: if any living enemy has taunt, must target them ---
	var taunt_targets: Array[BattleUnit] = []
	for e in enemies:
		if e.is_alive() and e.has_passive("taunt"):
			taunt_targets.append(e)
	if not taunt_targets.is_empty():
		return taunt_targets[randi() % taunt_targets.size()]

	# --- Determine which rows the attacker can reach -----------------------
	var can_hit_back_directly := false
	var troop := attacker.troop_id.to_lower()

	# Back-row ranged types can hit any row (use .find() to match partial troop_ids
	# like "archer_elite", "mage_apprentice", "cannon_heavy" — Bug fix Round 3)
	if troop.find("archer") != -1 or troop.find("ranger") != -1 or troop.find("mage") != -1 or troop.find("cannon") != -1 or troop.find("bombardier") != -1:
		can_hit_back_directly = true
	# Ninja or assassinate_back passive bypasses front
	if troop.find("ninja") != -1 or troop.find("assassin") != -1 or attacker.has_passive("assassinate_back"):
		can_hit_back_directly = true
	# v4.5: assassinate_bonus (de_shadow_fang) — treat as assassinate_back
	if attacker.has_passive("assassinate_bonus"):
		can_hit_back_directly = true

	# Separate enemies into front and back
	var front: Array[BattleUnit] = []
	var back: Array[BattleUnit] = []
	for e in enemies:
		if not e.is_alive():
			continue
		if e.row == 0:
			front.append(e)
		else:
			back.append(e)

	# --- 2. Ninja / assassinate: prefer back row --------------------------
	if (troop.find("ninja") != -1 or troop.find("assassin") != -1 or attacker.has_passive("assassinate_back") or attacker.has_passive("assassinate_bonus")) and not back.is_empty():
		return back[randi() % back.size()]

	# --- 3. Front-row attacker: target enemy front first ------------------
	if attacker.row == 0:
		if not front.is_empty():
			return front[randi() % front.size()]
		# Front empty – back row is now reachable
		if not back.is_empty():
			return back[randi() % back.size()]

	# --- 4. Back-row attacker (ranged): can hit anyone --------------------
	if can_hit_back_directly:
		# Prefer front row to peel for own front line
		if not front.is_empty():
			return front[randi() % front.size()]
		if not back.is_empty():
			return back[randi() % back.size()]

	# --- 5. Fallback: any living enemy ------------------------------------
	var alive: Array[BattleUnit] = []
	for e in enemies:
		if e.is_alive():
			alive.append(e)
	if alive.is_empty():
		return null
	return alive[randi() % alive.size()]

## Pick the target row for an AoE attack.  Prefer front if it has enemies.
func _pick_aoe_target_row(attacker: BattleUnit, enemies: Array[BattleUnit]) -> int:
	var has_front := false
	var has_back := false
	for e in enemies:
		if e.row == 0:
			has_front = true
		else:
			has_back = true

	# Ninja / assassinate_back prefers back row for AoE too (use .find() for partial
	# troop_id matching, consistent with targeting — Bug fix Round 3)
	var _aoe_troop := attacker.troop_id.to_lower()
	if (_aoe_troop.find("ninja") != -1 or _aoe_troop.find("assassin") != -1 or attacker.has_passive("assassinate_back") or attacker.has_passive("assassinate_bonus")) and has_back:
		return 1

	return 0 if has_front else 1

# ---------------------------------------------------------------------------
# On-Hit Passives
# ---------------------------------------------------------------------------

## Apply reactive passives after damage is dealt.
func _apply_passive_on_hit(attacker: BattleUnit, defender: BattleUnit, damage: int, state: BattleState) -> void:
	# counter_1_2: defender counterattacks at x1.2 when hit
	if defender.is_alive() and defender.has_passive("counter_1_2"):
		# v4.5: counter_damage_bonus (homura_flame_gauntlet) — boost counter from x1.2 to x1.5
		var counter_mult: float = 1.5 if defender.has_passive("counter_damage_bonus") else 1.2
		var counter_dmg := _calculate_damage(defender, attacker, state, counter_mult)
		_apply_damage(attacker, counter_dmg, state, defender)
		var _ctr_side := "attacker" if defender.is_attacker else "defender"
		var _ctr_tgt_side := "attacker" if attacker.is_attacker else "defender"
		state.action_log.append({
			"action": "passive",
			"event": "counter_1_2",
			"unit": defender.id,
			"side": _ctr_side,
			"slot": defender.slot,
			"target": attacker.id,
			"target_side": _ctr_tgt_side,
			"target_slot": attacker.slot,
			"target_name": attacker.troop_id,
			"damage": counter_dmg,
			"remaining_soldiers": attacker.soldiers,
			"max_soldiers": attacker.max_soldiers,
			"desc": "%s 反击 %s，造成%d伤害" % [defender.troop_id, attacker.troop_id, counter_dmg],
		})

	# v4.6: poison_attack — on hit, apply poison DOT (2 rounds, 1 HP damage/round)
	if attacker.has_passive("poison_attack") and damage > 0 and defender.is_alive():
		# Apply 1 HP damage per round for 2 rounds via direct HP reduction in round start
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
	if unit.hp <= 0 or unit.hp_per_soldier <= 0:
		unit.soldiers = 0
	else:
		unit.soldiers = ceili(float(unit.hp) / float(unit.hp_per_soldier))

# ---------------------------------------------------------------------------
# Morale System
# ---------------------------------------------------------------------------

## Reduce a unit's morale by the given amount. If morale reaches 0, the unit routs.
func _reduce_morale(unit: BattleUnit, amount: int, state: BattleState) -> void:
	if unit.is_routed or not unit.is_alive():
		return
	unit.morale = maxi(0, unit.morale - amount)
	EventBus.unit_morale_changed.emit(unit.troop_id, "attacker" if unit.is_attacker else "defender", unit.morale)
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
		"desc": "%s 击杀回复%d兵" % [killer.troop_id, heal_soldiers],
	})

## v4.5: dragon_slayer — on kill, gain ATK+1 permanently for this battle (like bloodlust).
func _apply_dragon_slayer(killer: BattleUnit, state: BattleState) -> void:
	if not killer.has_passive("dragon_slayer") or not killer.is_alive():
		return
	killer._dragon_slayer_bonus += 1
	killer.atk += 1
	var side_str: String = "attacker" if killer.is_attacker else "defender"
	state.action_log.append({
		"action": "passive",
		"event": "dragon_slayer",
		"unit": killer.id,
		"side": side_str,
		"slot": killer.slot,
		"desc": "%s 龙杀! 击杀后ATK+1(累积:%d)" % [killer.troop_id, killer._dragon_slayer_bonus],
	})

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
