class_name CombatSystem
## Core battle resolution engine for a Sengoku Rance-style tactical strategy game.
## v2.0 — SR07+TW:W数值对齐
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

# Terrain enum mirrors GameData.Terrain.  We reference GameData at runtime but
# keep local copies so the file is self-documenting.
enum Terrain {
	PLAINS   = 0,
	FOREST   = 1,
	MOUNTAIN = 2,
	SWAMP    = 3,
	FORTRESS = 4,
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

	## Convenience: unit is alive if it has HP remaining.
	func is_alive() -> bool:
		return hp > 0

	## Check whether the unit possesses a specific passive tag.
	func has_passive(p: String) -> bool:
		return passive.find(p) != -1

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

	# -- Apply terrain penalties that persist for the whole battle ----------
	_apply_terrain_modifiers(state)

	# -- Siege phase (attacker chips at city walls before combat) -----------
	if state.is_siege and state.city_def > 0:
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
		bu.row = d.get("row", 0 if i < MAX_FRONT_SLOTS else 1)
		bu.slot = d.get("slot", i)
		bu.passive = d.get("passive", "")
		bu.is_attacker = is_attacker
		bu.has_acted = false
		bu.first_attack = true
		bu.mana = 0

		# Pull troop base stats from GameData autoload if available.
		if Engine.has_singleton("GameData") or _has_autoload("GameData"):
			var gd = Engine.get_singleton("GameData")
			if gd == null:
				gd = _get_autoload("GameData")
			if gd and gd.has_method("get_troop_data"):
				var td: Dictionary = gd.get_troop_data(bu.troop_id)
				bu.atk += td.get("base_atk", 0)
				bu.def_stat += td.get("base_def", 0)

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

		units.append(bu)

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
		})
	return snap


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
	var all_units: Array[BattleUnit] = []
	all_units.append_array(state.attacker_units)
	all_units.append_array(state.defender_units)

	for u in all_units:
		# ignore_terrain passive skips penalties (but we still grant bonuses
		# to keep it fair – "immune to penalties" not "immune to all effects").
		var ignore := u.has_passive("ignore_terrain")
		var troop := u.troop_id.to_lower()

		match state.terrain:
			Terrain.PLAINS:
				# Cavalry ATK+3
				if troop == "cavalry":
					u.atk += 3

			Terrain.FOREST:
				# Archer ATK+3, cavalry ATK-3
				if troop == "archer":
					u.atk += 3
				if troop == "cavalry" and not ignore:
					u.atk -= 3

			Terrain.MOUNTAIN:
				# DEF mod x1.2 handled in damage calc; cavalry blocked
				# (we set soldiers to 0 to represent being unable to fight)
				if troop == "cavalry" and not ignore:
					u.soldiers = 0
					u.hp = 0

			Terrain.SWAMP:
				# All SPD-3
				if not ignore:
					u.spd -= 3

			Terrain.FORTRESS:
				# DEF mod x1.5 for defender only – applied in damage calc
				pass

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

	# If walls still stand, defender gets a flat DEF bonus for remaining wall HP.
	if state.city_def > 0:
		for u in state.defender_units:
			u.def_stat += state.city_def

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

	# Sort preemptive units by SPD descending, random tiebreak.
	pre_units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.spd != b.spd:
			return a.spd > b.spd
		return randi() % 2 == 0
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
		_apply_damage(target, dmg, state)

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

# ---------------------------------------------------------------------------
# Action Queue
# ---------------------------------------------------------------------------

## Build the action queue for the current round.  All living units sorted by
## SPD descending.  Preemptive units are NOT given priority here – they already
## acted in the preemptive phase (only relevant in round 0/pre-battle).
func _get_action_queue(state: BattleState) -> Array[BattleUnit]:
	var queue: Array[BattleUnit] = []

	for u in state.attacker_units:
		if u.is_alive():
			queue.append(u)
	for u in state.defender_units:
		if u.is_alive():
			queue.append(u)

	# Sort by SPD descending; ties broken randomly.
	queue.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.spd != b.spd:
			return a.spd > b.spd
		return randi() % 2 == 0
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
			_apply_damage(t, dmg, state)
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
	_apply_damage(target, dmg, state)
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
	match state.terrain:
		Terrain.MOUNTAIN:
			terrain_def_mult = 1.2
		Terrain.FORTRESS:
			if not defender.is_attacker:
				terrain_def_mult = 1.5

	def_val = int(float(def_val) * terrain_def_mult)

	# SR07-style: max(10, ATK - DEF) percentage-based damage
	var raw_diff: int = maxi(10, atk_val - def_val)

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
func _apply_damage(target: BattleUnit, damage: int, state: BattleState) -> void:
	if damage <= 0:
		return

	var new_hp: int = target.hp - damage

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

	target.hp = maxi(0, new_hp)
	_recalc_soldiers(target)

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

	# Back-row ranged types can hit any row
	if troop in ["archer", "mage", "cannon"]:
		can_hit_back_directly = true
	# Ninja or assassinate_back passive bypasses front
	if troop == "ninja" or attacker.has_passive("assassinate_back"):
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
	if (troop == "ninja" or attacker.has_passive("assassinate_back")) and not back.is_empty():
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

	# Ninja / assassinate_back prefers back row for AoE too
	if (attacker.troop_id.to_lower() == "ninja" or attacker.has_passive("assassinate_back")) and has_back:
		return 1

	return 0 if has_front else 1

# ---------------------------------------------------------------------------
# On-Hit Passives
# ---------------------------------------------------------------------------

## Apply reactive passives after damage is dealt.
func _apply_passive_on_hit(attacker: BattleUnit, defender: BattleUnit, damage: int, state: BattleState) -> void:
	# counter_1_2: defender counterattacks at x1.2 when hit
	if defender.is_alive() and defender.has_passive("counter_1_2"):
		var counter_dmg := _calculate_damage(defender, attacker, state, 1.2)
		_apply_damage(attacker, counter_dmg, state)
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

# ---------------------------------------------------------------------------
# Battle End Check
# ---------------------------------------------------------------------------

## Returns "attacker" if defenders are wiped, "defender" if attackers are
## wiped, or "" if the battle should continue.
func _check_battle_end(state: BattleState) -> String:
	if state.total_attacker_soldiers() <= 0:
		return "defender"
	if state.total_defender_soldiers() <= 0:
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
		unit.soldiers = ceili(float(unit.hp) / float(unit.hp_per_soldier))

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
