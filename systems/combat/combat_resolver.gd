extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## combat_resolver.gd - Turn-based Sengoku Rance-style combat (v1.0 rewrite)
## Front row (3 slots) + Back row (2 slots), SPD-based action queue, 12-round max.
## Damage formula: soldiers × max(1, ATK - DEF) / 10 × skill_mult × terrain_mult
## Defender wins on timeout (12 rounds).

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const MAX_ROUNDS: int = 12
const FRONT_SLOTS: int = 3       # indices 0, 1, 2
const BACK_SLOTS: int = 2        # indices 3, 4
const TOTAL_SLOTS: int = 5
const SIEGE_DAMAGE_MULT: float = 0.5
const CANNON_SIEGE_MULT: float = 2.0
const WALL_DAMAGE_MULTIPLIER: float = 0.5
const SLAVE_BASE_CAPTURE: int = 1

# Troop type → default row ("front" or "back")
const TROOP_DEFAULT_ROW: Dictionary = {
	"ashigaru": "front", "samurai": "front", "cavalry": "front",
	"archer": "back", "ninja": "back", "priest": "back",
	"mage_unit": "back", "cannon": "back",
	# Legacy / faction-specific mappings
	"grunt": "front", "troll": "front", "warg_rider": "front",
	"cutthroat": "front", "gunner": "back", "bombardier": "back",
	"warrior": "front", "assassin": "back", "cold_lizard": "front",
	"militia": "front", "knight": "front", "temple_guard": "front",
	"elf_ranger": "back", "elf_mage": "back", "treant": "front",
	"apprentice_mage": "back", "battle_mage": "back", "archmage": "back",
	"dwarf_ironguard": "front", "skeleton_legion": "front",
	"green_archer": "back", "blood_berserker": "front",
	"goblin_artillery": "back",
	"orc_ultimate": "front", "pirate_ultimate": "back", "dark_elf_ultimate": "front",
	"alliance_vanguard": "front", "arcane_artillery": "back",
	"shadow_walker": "front",
	# Troop IDs from 11_兵种数据包
	"orc_ashigaru": "front", "orc_samurai": "front", "orc_cavalry": "front",
	"pirate_ashigaru": "front", "pirate_archer": "back", "pirate_cannon": "back",
	"de_samurai": "front", "de_ninja": "back", "de_cavalry": "front",
	"human_ashigaru": "front", "human_cavalry": "front", "human_samurai": "front",
	"elf_archer": "back", "elf_ashigaru": "front",
	"mage_apprentice": "back", "mage_battle": "back", "mage_grand": "back",
}

# Troop type → target mode
enum TargetMode { FRONT_ONLY, ANY, BACK_PRIORITY, HEAL_FRIENDLY }
const TROOP_TARGET_MODE: Dictionary = {
	"ashigaru": TargetMode.FRONT_ONLY, "samurai": TargetMode.FRONT_ONLY,
	"cavalry": TargetMode.ANY, "archer": TargetMode.ANY,
	"ninja": TargetMode.BACK_PRIORITY, "priest": TargetMode.HEAL_FRIENDLY,
	"mage_unit": TargetMode.ANY, "cannon": TargetMode.ANY,
}

# ---------------------------------------------------------------------------
# Public: Army power estimate (used by AI threat evaluation, unchanged API)
# ---------------------------------------------------------------------------
func calculate_army_power(units: Array, player_id: int) -> float:
	var total: float = 0.0
	for unit in units:
		var atk: float = float(unit.get("atk", 0))
		var soldiers: int = unit.get("count", unit.get("soldiers", 1))
		total += atk * soldiers * 10.0
	var buff_mult: float = BuffManager.get_atk_multiplier(player_id)
	total *= buff_mult
	return total

# ---------------------------------------------------------------------------
# Public: Main entry point (preserves signature and return type)
# ---------------------------------------------------------------------------

## Resolves a full combat encounter using turn-based Sengoku Rance-style system.
## Returns { "winner", "attacker_losses", "defender_losses", "slaves_captured",
##           "wall_destroyed", "details" }
func resolve_combat(attacker: Dictionary, defender: Dictionary, tile: Dictionary) -> Dictionary:
	var log: Array = []
	var wall_destroyed: bool = false
	var atk_pid: int = attacker.get("player_id", -1)
	var def_pid: int = defender.get("player_id", -1)

	# -- Phase 0: Build battle state --
	var state: Dictionary = _build_battle_state(attacker, defender, tile)
	log.append("=== 战斗开始 === 进攻方 %d 单位 vs 防守方 %d 单位" % [
		state["atk_units"].size(), state["def_units"].size()])

	# -- Phase 1: Wall / Siege --
	var wall_hp: float = float(LightFactionAI.get_wall_hp(tile.get("index", -1)))
	# Terrain wall bonus
	var tile_terrain: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_info: Dictionary = FactionData.TERRAIN_DATA.get(tile_terrain, {})
	wall_hp += float(terrain_info.get("wall_hp_bonus", 0))
	# Equipment wall bonus
	if def_pid >= 0:
		for hero in HeroSystem.get_available_heroes():
			if HeroSystem.has_equipment_passive(hero["id"], "node_wall_bonus"):
				var bonus: float = HeroSystem.get_equipment_passive_value(hero["id"], "node_wall_bonus")
				wall_hp += bonus
				log.append("装备: 城防+%.0f" % bonus)
	# Blast barrel
	var blast_barrel_dmg = BuffManager.get_buff_value(atk_pid, "wall_damage")
	if blast_barrel_dmg != null and blast_barrel_dmg > 0:
		wall_hp = maxf(wall_hp - float(blast_barrel_dmg), 0.0)
		log.append("爆破桶: 城防-%.0f" % float(blast_barrel_dmg))

	if wall_hp > 0.0 and StrategicResourceManager.ignores_walls(atk_pid):
		log.append("火药攻势! 无视城防!")
	elif wall_hp > 0.0:
		var siege_result: Dictionary = _resolve_siege_phase(state, wall_hp, tile)
		log.append_array(siege_result["log"])
		if not siege_result["breached"]:
			log.append("城墙未被攻破! 战斗未进行。")
			return {
				"winner": "defender", "attacker_losses": 0, "defender_losses": 0,
				"slaves_captured": 0, "wall_destroyed": false, "details": log,
			}
		else:
			wall_destroyed = true
			log.append("城墙被攻破! 战斗开始!")

	# -- Phase 2: Elf Barrier check --
	var barrier_active: bool = LightFactionAI.is_barrier_active(tile.get("index", -1))
	if barrier_active:
		state["barrier_active"] = true
		state["barrier_tile_index"] = tile.get("index", -1)
		log.append("精灵屏障激活!")

	# -- Phase 3: Main battle loop (up to 12 rounds) --
	var winner: String = ""
	for round_num in range(1, MAX_ROUNDS + 1):
		state["round"] = round_num
		log.append("--- 第 %d 回合 ---" % round_num)

		_start_of_round(state, log)
		var queue: Array = _build_action_queue(state)

		for unit in queue:
			if not unit.get("is_alive", true):
				continue
			if unit["actions_this_round"] >= unit["max_actions"]:
				continue
			_execute_action(state, unit, log)

		var result: String = _end_of_round(state, log)
		if result != "continue":
			winner = result
			break

	# 12 rounds elapsed → defender wins
	if winner == "":
		winner = "defender"
		log.append("12回合结束，防守方胜利!")

	# -- Phase 4: Finalize --
	return _finalize_result(state, winner, wall_destroyed, log, tile)


# ---------------------------------------------------------------------------
# Battle State Construction
# ---------------------------------------------------------------------------

func _build_battle_state(attacker: Dictionary, defender: Dictionary, tile: Dictionary) -> Dictionary:
	var atk_pid: int = attacker.get("player_id", -1)
	var def_pid: int = defender.get("player_id", -1)
	var raw_atk: Array = attacker.get("units", [])
	var raw_def: Array = defender.get("units", [])

	var atk_units: Array = _assign_to_slots(raw_atk, atk_pid, "attacker", tile)
	var def_units: Array = _assign_to_slots(raw_def, def_pid, "defender", tile)

	# Mana pools: max = 10 + highest INT × 2
	var atk_max_int: int = _get_highest_int(atk_units)
	var def_max_int: int = _get_highest_int(def_units)

	return {
		"atk_units": atk_units,
		"def_units": def_units,
		"atk_pid": atk_pid,
		"def_pid": def_pid,
		"atk_mana": 0,
		"def_mana": 0,
		"atk_mana_max": FactionData.MANA_BASE_MAX + atk_max_int * 2,
		"def_mana_max": FactionData.MANA_BASE_MAX + def_max_int * 2,
		"round": 0,
		"tile": tile,
		"terrain": tile.get("terrain", FactionData.TerrainType.PLAINS),
		"barrier_active": false,
		"barrier_tile_index": -1,
		"barrier_used_this_round": false,
	}


func _assign_to_slots(raw_units: Array, player_id: int, side: String, tile: Dictionary) -> Array:
	var front_units: Array = []
	var back_units: Array = []

	for raw in raw_units:
		var unit: Dictionary = _build_battle_unit(raw, player_id, side, tile)
		if unit["row"] == "front":
			front_units.append(unit)
		else:
			back_units.append(unit)

	# Enforce slot limits: front max 3, back max 2
	# Overflow front → back, overflow back → front
	while front_units.size() > FRONT_SLOTS and back_units.size() < BACK_SLOTS:
		back_units.append(front_units.pop_back())
	while back_units.size() > BACK_SLOTS and front_units.size() < FRONT_SLOTS:
		front_units.append(back_units.pop_back())

	# Assign slot indices
	var all_units: Array = []
	for i in range(mini(front_units.size(), FRONT_SLOTS)):
		front_units[i]["slot"] = i
		all_units.append(front_units[i])
	for i in range(mini(back_units.size(), BACK_SLOTS)):
		back_units[i]["slot"] = FRONT_SLOTS + i
		all_units.append(back_units[i])

	return all_units


func _build_battle_unit(raw: Dictionary, player_id: int, side: String, tile: Dictionary) -> Dictionary:
	var unit_type: String = raw.get("type", "orc_ashigaru")
	var soldiers: int = raw.get("count", raw.get("soldiers", 1))
	var base_atk: float = float(raw.get("atk", 5))
	var base_def: float = float(raw.get("def", 3))
	var spd: float = float(raw.get("spd", 5))
	var int_stat: float = float(raw.get("int_stat", raw.get("int", 0)))
	var special: String = raw.get("special", "")
	var hero_id: String = raw.get("hero_id", "")
	var passives: Array = raw.get("passives", [])

	# If special is set but passives is empty, use special as a passive
	if passives.is_empty() and special != "":
		passives = [special]

	# Hero commander stat bonuses
	if hero_id != "" and FactionData.HEROES.has(hero_id):
		var hdata: Dictionary = FactionData.HEROES[hero_id]
		base_atk += float(hdata.get("atk", 0))
		base_def += float(hdata.get("def", 0))
		spd = maxf(spd, float(hdata.get("spd", 0)))  # Use higher SPD
		int_stat = maxf(int_stat, float(hdata.get("int", 0)))
		# Add hero passive to passives if not already there
		var hero_passive: String = hdata.get("passive", "")
		if hero_passive != "" and hero_passive not in passives:
			passives.append(hero_passive)

	# Terrain modifiers
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
	var terrain_flags: Array = terrain_data.get("special_flags", [])
	var is_attacker: bool = (side == "attacker")

	var has_ignore_terrain: bool = "ignore_terrain" in passives
	if not has_ignore_terrain:
		# Per design doc 05:
		# 平原: 骑兵ATK+1
		# 森林: ATK×0.9, DEF×1.1, 弓兵ATK+1, 骑兵ATK-1
		# 山地: ATK×0.8, DEF×1.2, 骑兵不可进入(冷蜥除外)
		# 沼泽: ATK×0.9, DEF×0.9, 全体SPD-2
		# 城墙: ATK×0.7, DEF×1.5
		var troop_base: String = _get_troop_base_type(unit_type)
		match terrain_type:
			FactionData.TerrainType.PLAINS:
				if troop_base == "cavalry":
					base_atk += 1
			FactionData.TerrainType.FOREST:
				if is_attacker:
					base_atk *= 0.9
				else:
					base_def *= 1.1
				if troop_base == "archer":
					base_atk += 1
				if troop_base == "cavalry":
					base_atk -= 1
			FactionData.TerrainType.MOUNTAIN:
				if is_attacker:
					base_atk *= 0.8
				else:
					base_def *= 1.2
				if troop_base == "cavalry":
					base_atk *= 0.85  # Additional cavalry penalty
			FactionData.TerrainType.SWAMP:
				base_atk *= 0.9
				base_def *= 0.9
				if "ninja_immune" not in terrain_flags or troop_base != "ninja":
					spd -= 2
			FactionData.TerrainType.FORTRESS_WALL:
				if is_attacker:
					base_atk *= 0.7
				else:
					base_def *= 1.5

	# Fort defense passive: DEF+3 when defending own node
	if "fort_def_3" in passives and not is_attacker:
		base_def += 3

	# Strategic resource bonuses
	if player_id >= 0:
		base_atk += StrategicResourceManager.get_permanent_atk_bonus(player_id)

	# Training system bonuses
	if player_id >= 0:
		base_atk += ResearchManager.get_unit_stat_bonus(player_id, unit_type, "atk")
		base_def += ResearchManager.get_unit_stat_bonus(player_id, unit_type, "def")
		var train_hp: int = ResearchManager.get_unit_stat_bonus(player_id, unit_type, "hp")
		soldiers += train_hp  # Training HP bonus → extra soldiers

	# Buff multipliers
	if player_id >= 0:
		if is_attacker:
			base_atk *= BuffManager.get_atk_multiplier(player_id)
		else:
			base_def *= BuffManager.get_def_multiplier(player_id)

	# AI scaling for non-player (AI) units
	if player_id < 0:
		var ai_key: String = _tile_to_ai_key(tile)
		if ai_key != "":
			var ai_atk: float = AIScaling.get_atk_multiplier(ai_key)
			var ai_def: float = AIScaling.get_def_multiplier(ai_key)
			base_atk *= ai_atk
			base_def *= ai_def

	# Building combat bonuses
	if player_id >= 0:
		var bld: Dictionary = BuildingRegistry.get_all_player_building_effects(player_id)
		if is_attacker:
			base_atk += float(bld.get("atk_bonus", 0))
		else:
			base_def += float(bld.get("def_bonus", 0))

	# Determine max actions
	var max_actions: int = 1
	if "extra_action" in passives:
		max_actions = 2

	# Determine default row
	var row: String = raw.get("row", TROOP_DEFAULT_ROW.get(unit_type, "front"))

	return {
		"slot": -1,  # assigned later
		"row": row,
		"side": side,
		"hero_id": hero_id,
		"unit_type": unit_type,
		"soldiers": soldiers,
		"max_soldiers": soldiers,
		"atk": maxf(base_atk, 0.0),
		"def": maxf(base_def, 0.0),
		"spd": maxf(spd, 1.0),
		"int_stat": int_stat,
		"passives": passives,
		"active_skill": _get_hero_active_skill(hero_id),
		"skill_cooldown": 0,
		"has_charged": false,
		"actions_this_round": 0,
		"max_actions": max_actions,
		"is_alive": true,
		"player_id": player_id,
		"buffs": [],
		"debuffs": [],
	}


# ---------------------------------------------------------------------------
# Siege Phase
# ---------------------------------------------------------------------------

func _resolve_siege_phase(state: Dictionary, wall_hp: float, tile: Dictionary) -> Dictionary:
	var log: Array = []
	var remaining: float = wall_hp

	for unit in state["atk_units"]:
		if not unit["is_alive"]:
			continue
		var siege_dmg: float = unit["atk"] * SIEGE_DAMAGE_MULT * unit["soldiers"]
		# Cannon/siege units deal double
		var troop_base: String = _get_troop_base_type(unit["unit_type"])
		if troop_base == "cannon":
			siege_dmg *= CANNON_SIEGE_MULT
		if "siege_x2" in unit["passives"]:
			siege_dmg *= 2.0
		# Siege buff
		var siege_buff = BuffManager.get_buff_value(state["atk_pid"], "siege_mult")
		if siege_buff != null and siege_buff > 1.0:
			siege_dmg *= float(siege_buff)
		remaining -= siege_dmg
		log.append("%s 攻城伤害 %.0f" % [unit["unit_type"], siege_dmg])

	var wall_damage_total: int = int(wall_hp - maxf(remaining, 0.0))
	LightFactionAI.damage_wall(tile.get("index", -1), wall_damage_total)
	var new_wall: int = LightFactionAI.get_wall_hp(tile.get("index", -1))
	log.append("城墙受到 %d 点伤害 (剩余: %d)" % [wall_damage_total, new_wall])

	return {"breached": new_wall <= 0, "log": log}


# ---------------------------------------------------------------------------
# Round Phases
# ---------------------------------------------------------------------------

func _start_of_round(state: Dictionary, log: Array) -> void:
	state["barrier_used_this_round"] = false

	# Mana regen: +1 per side per round
	state["atk_mana"] = mini(state["atk_mana"] + 1, state["atk_mana_max"])
	state["def_mana"] = mini(state["def_mana"] + 1, state["def_mana_max"])

	for unit in state["atk_units"] + state["def_units"]:
		if not unit["is_alive"]:
			continue
		unit["actions_this_round"] = 0

		# Passive: regen_1 — restore 1 soldier per round
		if "regen_1" in unit["passives"]:
			if unit["soldiers"] < unit["max_soldiers"]:
				unit["soldiers"] += 1
				log.append("%s [%s] 再生+1兵" % [unit["unit_type"], unit["side"]])

		# Passive: charge_mana_1 — +1 mana
		if "charge_mana_1" in unit["passives"]:
			var mana_key: String = "atk_mana" if unit["side"] == "attacker" else "def_mana"
			var max_key: String = "atk_mana_max" if unit["side"] == "attacker" else "def_mana_max"
			state[mana_key] = mini(state[mana_key] + 1, state[max_key])

		# Tick down skill cooldown
		if unit["skill_cooldown"] > 0:
			unit["skill_cooldown"] -= 1

		# Tick down buffs/debuffs
		var remaining_buffs: Array = []
		for b in unit["buffs"]:
			b["duration"] -= 1
			if b["duration"] > 0:
				remaining_buffs.append(b)
		unit["buffs"] = remaining_buffs

		var remaining_debuffs: Array = []
		for d in unit["debuffs"]:
			d["duration"] -= 1
			if d["duration"] > 0:
				remaining_debuffs.append(d)
		unit["debuffs"] = remaining_debuffs


func _build_action_queue(state: Dictionary) -> Array:
	var all_units: Array = []
	for unit in state["atk_units"] + state["def_units"]:
		if unit["is_alive"]:
			all_units.append(unit)

	# Separate preemptive units
	var preemptive: Array = []
	var normal: Array = []
	for unit in all_units:
		if "preemptive" in unit["passives"] or "preemptive_1_3" in unit["passives"]:
			preemptive.append(unit)
		else:
			normal.append(unit)

	# Sort each group by SPD descending, random tiebreak
	preemptive.sort_custom(_sort_by_spd)
	normal.sort_custom(_sort_by_spd)

	var queue: Array = []
	queue.append_array(preemptive)
	queue.append_array(normal)

	# Extra actions: add duplicates for units with extra_action
	var extra: Array = []
	for unit in queue:
		if unit["max_actions"] > 1:
			extra.append(unit)
	queue.append_array(extra)

	return queue


func _sort_by_spd(a: Dictionary, b: Dictionary) -> bool:
	if a["spd"] != b["spd"]:
		return a["spd"] > b["spd"]
	return randf() > 0.5


# ---------------------------------------------------------------------------
# Action Execution
# ---------------------------------------------------------------------------

func _execute_action(state: Dictionary, unit: Dictionary, log: Array) -> void:
	if not unit["is_alive"] or unit["soldiers"] <= 0:
		return
	if unit["actions_this_round"] >= unit["max_actions"]:
		return
	unit["actions_this_round"] += 1

	var troop_base: String = _get_troop_base_type(unit["unit_type"])

	# Priest heals instead of attacking
	if troop_base == "priest":
		_execute_heal(state, unit, log)
		return

	# Check AoE mana skills
	if "aoe_mana" in unit["passives"] or "aoe_1_5_cost5" in unit["passives"]:
		var mana_key: String = "atk_mana" if unit["side"] == "attacker" else "def_mana"
		if state[mana_key] >= 5:
			state[mana_key] -= 5
			_execute_aoe_attack(state, unit, log)
			return

	# Check hero active skill (if ready and has mana)
	if unit["hero_id"] != "" and unit["skill_cooldown"] <= 0:
		var skill: Dictionary = unit["active_skill"]
		if not skill.is_empty():
			var used: bool = _execute_active_skill(state, unit, skill, log)
			if used:
				return

	# Normal single-target attack
	var target: Dictionary = _select_target(state, unit)
	if target.is_empty():
		return

	var damage: int = _calculate_damage(unit, target, state)

	# Charge bonus: first attack ×1.5
	if "charge_1_5" in unit["passives"] and not unit["has_charged"]:
		damage = int(float(damage) * 1.5)
		unit["has_charged"] = true
		log.append("%s [%s] 冲锋! 伤害×1.5" % [unit["unit_type"], unit["side"]])

	# Preemptive ×1.3 multiplier (round 1 only for preemptive_1_3)
	if "preemptive_1_3" in unit["passives"] and state["round"] == 1:
		damage = int(float(damage) * 1.3)

	# Barrier absorption (defender side, first use per round)
	if state.get("barrier_active", false) and not state.get("barrier_used_this_round", false):
		if unit["side"] == "attacker":  # Attacker hitting defender
			var absorbed: float = LightFactionAI.apply_barrier_absorption(
				state.get("barrier_tile_index", -1), float(damage))
			damage = int(absorbed)
			state["barrier_used_this_round"] = true
			log.append("精灵屏障吸收! 伤害降至 %d" % damage)

	# Apply damage
	_apply_damage_to_unit(state, target, damage, unit, log)

	# Counter-attack: counter_1_2 passive
	if target["is_alive"] and "counter_1_2" in target["passives"]:
		var counter_dmg: int = _calculate_damage(target, unit, state)
		counter_dmg = int(float(counter_dmg) * 1.2)
		log.append("%s [%s] 反击! 伤害 %d" % [target["unit_type"], target["side"], counter_dmg])
		_apply_damage_to_unit(state, unit, counter_dmg, target, log)


func _execute_heal(state: Dictionary, healer: Dictionary, log: Array) -> void:
	# Find friendliest unit with lowest soldiers ratio
	var allies: Array = state["atk_units"] if healer["side"] == "attacker" else state["def_units"]
	var best_target: Dictionary = {}
	var best_ratio: float = 1.0
	for ally in allies:
		if not ally["is_alive"] or ally == healer:
			continue
		var ratio: float = float(ally["soldiers"]) / float(ally["max_soldiers"])
		if ratio < best_ratio:
			best_ratio = ratio
			best_target = ally

	if best_target.is_empty() or best_ratio >= 1.0:
		# No one to heal; do a weak attack instead
		var target: Dictionary = _select_target(state, healer)
		if not target.is_empty():
			var damage: int = _calculate_damage(healer, target, state)
			_apply_damage_to_unit(state, target, damage, healer, log)
		return

	# Heal: restore 2 soldiers (from design doc 02 — 治愈之光 restores 2)
	var heal_amount: int = 2
	# INT scaling: heal × (1 + INT × 0.05)
	heal_amount = int(float(heal_amount) * (1.0 + healer["int_stat"] * 0.05))
	best_target["soldiers"] = mini(best_target["soldiers"] + heal_amount, best_target["max_soldiers"])
	log.append("%s [%s] 治疗 %s +%d兵" % [
		healer["unit_type"], healer["side"], best_target["unit_type"], heal_amount])


func _execute_aoe_attack(state: Dictionary, unit: Dictionary, log: Array) -> void:
	var enemies: Array = state["def_units"] if unit["side"] == "attacker" else state["atk_units"]
	var mult: float = 1.0
	if "aoe_1_5_cost5" in unit["passives"]:
		mult = 1.5

	var hit_count: int = 0
	for enemy in enemies:
		if not enemy["is_alive"]:
			continue
		var damage: int = _calculate_damage(unit, enemy, state)
		damage = int(float(damage) * mult)
		# AoE reduces per-target damage slightly
		damage = maxi(1, int(float(damage) * 0.6))
		_apply_damage_to_unit(state, enemy, damage, unit, log)
		hit_count += 1

	log.append("%s [%s] AoE攻击! 命中 %d 个目标 (×%.1f)" % [
		unit["unit_type"], unit["side"], hit_count, mult])


# ---------------------------------------------------------------------------
# Hero Active Skills
# ---------------------------------------------------------------------------

func _execute_active_skill(state: Dictionary, unit: Dictionary, skill: Dictionary, log: Array) -> bool:
	var skill_name: String = skill.get("name", "")
	var skill_type: String = skill.get("type", "damage")
	var mana_cost: int = skill.get("mana_cost", 0)
	var cooldown: int = skill.get("cooldown", 3)

	# Check mana
	var mana_key: String = "atk_mana" if unit["side"] == "attacker" else "def_mana"
	if mana_cost > 0 and state[mana_key] < mana_cost:
		return false  # Not enough mana, fall through to normal attack

	# Consume mana
	if mana_cost > 0:
		state[mana_key] -= mana_cost

	# Set cooldown
	unit["skill_cooldown"] = cooldown

	var int_mult: float = 1.0 + unit["int_stat"] * 0.05
	var enemies: Array = state["def_units"] if unit["side"] == "attacker" else state["atk_units"]
	var allies: Array = state["atk_units"] if unit["side"] == "attacker" else state["def_units"]

	match skill_name:
		"圣光斩":  # ATK × 1.8 single target
			var target: Dictionary = _select_target(state, unit)
			if not target.is_empty():
				var dmg: int = maxi(1, int(unit["atk"] * 1.8 * int_mult))
				_apply_damage_to_unit(state, target, dmg, unit, log)
				log.append("【%s】圣光斩! 对 %s 造成 %d 伤害" % [unit["hero_id"], target["unit_type"], dmg])

		"箭雨":  # 后排AoE, ATK × 1.2
			for enemy in enemies:
				if not enemy["is_alive"]:
					continue
				if enemy["row"] == "back" or _count_alive_in_row(enemies, "front") == 0:
					var dmg: int = maxi(1, int(unit["atk"] * 1.2 * int_mult * 0.6))
					_apply_damage_to_unit(state, enemy, dmg, unit, log)
			log.append("【%s】箭雨!" % unit["hero_id"])

		"流星火雨":  # 全体AoE, ATK × 2, 8 mana
			for enemy in enemies:
				if not enemy["is_alive"]:
					continue
				var dmg: int = maxi(1, int(unit["atk"] * 2.0 * int_mult * 0.5))
				_apply_damage_to_unit(state, enemy, dmg, unit, log)
			log.append("【%s】流星火雨!" % unit["hero_id"])

		"爆裂火球":  # 单体 ATK × 2.5, 3 mana
			var target: Dictionary = _select_target(state, unit)
			if not target.is_empty():
				var dmg: int = maxi(1, int(unit["atk"] * 2.5 * int_mult))
				_apply_damage_to_unit(state, target, dmg, unit, log)
				log.append("【%s】爆裂火球! %d 伤害" % [unit["hero_id"], dmg])

		"治愈之光":  # 恢复2兵力
			var best: Dictionary = _find_most_wounded_ally(allies, unit)
			if not best.is_empty():
				var heal: int = int(2.0 * int_mult)
				best["soldiers"] = mini(best["soldiers"] + heal, best["max_soldiers"])
				log.append("【%s】治愈之光! %s +%d兵" % [unit["hero_id"], best["unit_type"], heal])

		"不动如山":  # 本回合免疫所有伤害
			unit["buffs"].append({"id": "invulnerable", "duration": 1, "value": 1.0})
			log.append("【%s】不动如山! 本回合免伤" % unit["hero_id"])

		"月光护盾":  # 全队减伤30%, 1回合
			for ally in allies:
				if ally["is_alive"]:
					ally["buffs"].append({"id": "shield", "duration": 1, "value": 0.3})
			log.append("【%s】月光护盾! 全队减伤30%%" % unit["hero_id"])

		"影步":  # 无视前排攻击后排
			var back_enemies: Array = _get_alive_in_row(enemies, "back")
			if back_enemies.is_empty():
				back_enemies = _get_all_alive(enemies)
			if not back_enemies.is_empty():
				var target: Dictionary = back_enemies[randi() % back_enemies.size()]
				var dmg: int = maxi(1, int(unit["atk"] * 2.0 * int_mult))
				_apply_damage_to_unit(state, target, dmg, unit, log)
				log.append("【%s】影步! 直取后排 %s, %d 伤害" % [unit["hero_id"], target["unit_type"], dmg])

		"时间减速":  # 敌全体SPD-3, 2回合
			for enemy in enemies:
				if enemy["is_alive"]:
					enemy["debuffs"].append({"id": "slow", "duration": 2, "value": 3.0})
					enemy["spd"] = maxf(enemy["spd"] - 3, 1.0)
			log.append("【%s】时间减速! 敌方SPD-3" % unit["hero_id"])

		"突击号令":  # 己方全体骑兵ATK+2, 1回合
			for ally in allies:
				if ally["is_alive"] and _get_troop_base_type(ally["unit_type"]) == "cavalry":
					ally["atk"] += 2
					ally["buffs"].append({"id": "charge_cmd", "duration": 1, "value": 2.0})
			log.append("【%s】突击号令!" % unit["hero_id"])

		"致命一击":  # ATK × 3, miss率40%
			if randf() < 0.4:
				log.append("【%s】致命一击 — MISS!" % unit["hero_id"])
			else:
				var target: Dictionary = _select_target(state, unit)
				if not target.is_empty():
					var dmg: int = maxi(1, int(unit["atk"] * 3.0 * int_mult))
					_apply_damage_to_unit(state, target, dmg, unit, log)
					log.append("【%s】致命一击! %d 伤害" % [unit["hero_id"], dmg])

		"连射":  # 攻击2次, 每次 ATK × 0.7
			for i in range(2):
				var target: Dictionary = _select_target(state, unit)
				if not target.is_empty():
					var dmg: int = maxi(1, int(unit["atk"] * 0.7 * int_mult))
					_apply_damage_to_unit(state, target, dmg, unit, log)
			log.append("【%s】连射! 2次攻击" % unit["hero_id"])

		"铁壁":  # DEF+3, 1回合
			unit["def"] += 3
			unit["buffs"].append({"id": "iron_wall", "duration": 1, "value": 3.0})
			log.append("【%s】铁壁! DEF+3" % unit["hero_id"])

		"沙暴":  # 敌全体命中率-30%, 2回合
			for enemy in enemies:
				if enemy["is_alive"]:
					enemy["debuffs"].append({"id": "sandstorm", "duration": 2, "value": 0.3})
			log.append("【%s】沙暴! 敌方命中-30%%" % unit["hero_id"])

		"亡灵召唤":  # 召唤2兵力亡灵, 3回合
			# Add a temporary skeleton unit to allies
			var summon: Dictionary = {
				"slot": -1, "row": "front", "side": unit["side"],
				"hero_id": "", "unit_type": "skeleton_legion",
				"soldiers": 2, "max_soldiers": 2,
				"atk": 6.0, "def": 4.0, "spd": 3.0, "int_stat": 0.0,
				"passives": [], "active_skill": {},
				"skill_cooldown": 0, "has_charged": false,
				"actions_this_round": 1, "max_actions": 1,
				"is_alive": true, "player_id": unit["player_id"],
				"buffs": [{"id": "summon_decay", "duration": 3, "value": 0}],
				"debuffs": [],
			}
			if unit["side"] == "attacker":
				state["atk_units"].append(summon)
			else:
				state["def_units"].append(summon)
			log.append("【%s】亡灵召唤! +2骷髅兵" % unit["hero_id"])

		"分身":  # 回避下一次攻击
			unit["buffs"].append({"id": "dodge_next", "duration": 99, "value": 1.0})
			log.append("【%s】分身! 回避下一次攻击" % unit["hero_id"])

		"净化":  # 移除全部debuff + 恢复1兵
			var best: Dictionary = _find_most_wounded_ally(allies, unit)
			if not best.is_empty():
				best["debuffs"].clear()
				best["soldiers"] = mini(best["soldiers"] + 1, best["max_soldiers"])
				log.append("【%s】净化! %s 净化+回复" % [unit["hero_id"], best["unit_type"]])

		"集中轰炸":  # ATK × 2.2, 对城防×3
			var target: Dictionary = _select_target(state, unit)
			if not target.is_empty():
				var dmg: int = maxi(1, int(unit["atk"] * 2.2 * int_mult))
				_apply_damage_to_unit(state, target, dmg, unit, log)
				log.append("【%s】集中轰炸! %d 伤害" % [unit["hero_id"], dmg])

		_:
			# Unknown skill, do normal attack
			return false

	return true


# ---------------------------------------------------------------------------
# Target Selection (design doc rules)
# ---------------------------------------------------------------------------

func _select_target(state: Dictionary, unit: Dictionary) -> Dictionary:
	var enemies: Array = state["def_units"] if unit["side"] == "attacker" else state["atk_units"]
	var alive_enemies: Array = _get_all_alive(enemies)
	if alive_enemies.is_empty():
		return {}

	# 1. Taunt check: must target taunter
	for enemy in alive_enemies:
		if "taunt" in enemy["passives"]:
			return enemy

	# 2. Stealth check: round 1, units with 隐匿 can't be targeted
	var targetable: Array = []
	for enemy in alive_enemies:
		if state["round"] == 1 and "隐匿" in enemy["passives"]:
			continue
		# dodge_next: skip this unit as target (consume buff)
		var has_dodge: bool = false
		for b in enemy["buffs"]:
			if b["id"] == "dodge_next":
				has_dodge = true
				break
		if has_dodge:
			continue
		targetable.append(enemy)

	if targetable.is_empty():
		targetable = alive_enemies  # Fallback: target anyone

	# 3. Targeting based on troop type
	var troop_base: String = _get_troop_base_type(unit["unit_type"])
	var target_mode: int = TROOP_TARGET_MODE.get(troop_base, TargetMode.FRONT_ONLY)

	# Assassinate_back passive overrides to back priority
	if "assassinate_back" in unit["passives"]:
		target_mode = TargetMode.BACK_PRIORITY

	var front_targets: Array = _filter_by_row(targetable, "front")
	var back_targets: Array = _filter_by_row(targetable, "back")

	var candidates: Array = []
	match target_mode:
		TargetMode.FRONT_ONLY:
			candidates = front_targets if not front_targets.is_empty() else back_targets
		TargetMode.ANY:
			candidates = targetable
		TargetMode.BACK_PRIORITY:
			candidates = back_targets if not back_targets.is_empty() else front_targets

	if candidates.is_empty():
		candidates = targetable

	# Pick lowest-soldiers target (focus fire)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["soldiers"] < b["soldiers"])
	return candidates[0]


# ---------------------------------------------------------------------------
# Damage Calculation (design doc formula)
# ---------------------------------------------------------------------------

## damage = soldiers × max(1, ATK - DEF) / 10 × skill_mult × terrain_mult
## Minimum 1 soldier killed.
func _calculate_damage(attacker_unit: Dictionary, defender_unit: Dictionary, state: Dictionary) -> int:
	var atk: float = attacker_unit["atk"]
	var def_val: float = defender_unit["def"]
	var soldiers: int = attacker_unit["soldiers"]

	# Apply debuffs to attacker/defender
	for d in defender_unit["debuffs"]:
		if d["id"] == "sandstorm":
			# 30% miss chance per sandstorm stack
			if randf() < d["value"]:
				return 0  # Miss!

	# Core formula from design doc
	var base_damage: float = float(soldiers) * maxf(1.0, atk - def_val) / 10.0

	# Shield buff: reduce damage taken
	for b in defender_unit["buffs"]:
		if b["id"] == "shield":
			base_damage *= (1.0 - b["value"])
		if b["id"] == "invulnerable":
			return 0  # Immune

	var soldiers_killed: int = maxi(1, int(base_damage))
	return soldiers_killed


# ---------------------------------------------------------------------------
# Damage Application
# ---------------------------------------------------------------------------

func _apply_damage_to_unit(state: Dictionary, target: Dictionary, damage: int, source: Dictionary, log: Array) -> void:
	if damage <= 0:
		return

	# Consume dodge_next buff
	var dodge_idx: int = -1
	for i in range(target["buffs"].size()):
		if target["buffs"][i]["id"] == "dodge_next":
			dodge_idx = i
			break
	if dodge_idx >= 0:
		target["buffs"].remove_at(dodge_idx)
		log.append("%s [%s] 分身闪避了攻击!" % [target["unit_type"], target["side"]])
		return

	# Escape_30: 30% chance to survive lethal damage (soldiers would drop to 0)
	if target["soldiers"] - damage <= 0 and "escape_30" in target["passives"]:
		if randf() < 0.3:
			target["soldiers"] = 1
			log.append("%s [%s] 逃脱致命一击! 残存1兵" % [target["unit_type"], target["side"]])
			return

	target["soldiers"] -= damage
	log.append("%s [%s] 受到 %d 伤害 (剩余 %d 兵)" % [
		target["unit_type"], target["side"], damage, maxi(target["soldiers"], 0)])

	if target["soldiers"] <= 0:
		target["soldiers"] = 0
		target["is_alive"] = false
		log.append("%s [%s] 被消灭!" % [target["unit_type"], target["side"]])

		# Death burst: on death, deal ATK × 2 to all enemies
		if "death_burst" in target["passives"]:
			var burst_enemies: Array
			if target["side"] == "attacker":
				burst_enemies = state["def_units"]
			else:
				burst_enemies = state["atk_units"]
			# Swap: death_burst damages the killer's side
			burst_enemies = state["atk_units"] if target["side"] == "defender" else state["def_units"]
			# Actually death_burst should hurt the side that killed us (the opposite side)
			if target["side"] == "attacker":
				burst_enemies = state["def_units"]
			else:
				burst_enemies = state["atk_units"]
			var burst_dmg: int = int(target["atk"] * 2.0)
			log.append("%s 死亡爆发! 对敌全体造成 %d 伤害!" % [target["unit_type"], burst_dmg])
			for enemy in burst_enemies:
				if enemy["is_alive"]:
					enemy["soldiers"] -= burst_dmg
					if enemy["soldiers"] <= 0:
						enemy["soldiers"] = 0
						enemy["is_alive"] = false
						log.append("  → %s [%s] 被死亡爆发消灭!" % [enemy["unit_type"], enemy["side"]])


# ---------------------------------------------------------------------------
# End of Round
# ---------------------------------------------------------------------------

func _end_of_round(state: Dictionary, log: Array) -> String:
	# Remove summon-decay units that expired
	for units_key in ["atk_units", "def_units"]:
		for unit in state[units_key]:
			if not unit["is_alive"]:
				continue
			for b in unit["buffs"]:
				if b["id"] == "summon_decay" and b["duration"] <= 0:
					unit["is_alive"] = false
					unit["soldiers"] = 0
					log.append("%s [%s] 召唤物消散" % [unit["unit_type"], unit["side"]])

	var atk_alive: int = _count_total_soldiers(state["atk_units"])
	var def_alive: int = _count_total_soldiers(state["def_units"])

	if atk_alive <= 0 and def_alive <= 0:
		return "defender"  # Mutual destruction → defender wins
	elif atk_alive <= 0:
		return "defender"
	elif def_alive <= 0:
		return "attacker"
	return "continue"


# ---------------------------------------------------------------------------
# Finalize Result
# ---------------------------------------------------------------------------

func _finalize_result(state: Dictionary, winner: String, wall_destroyed: bool, log: Array, tile: Dictionary) -> Dictionary:
	var atk_pid: int = state["atk_pid"]
	var def_pid: int = state["def_pid"]

	# Calculate losses
	var attacker_losses: int = 0
	for unit in state["atk_units"]:
		attacker_losses += maxi(0, unit["max_soldiers"] - unit["soldiers"])
	var defender_losses: int = 0
	for unit in state["def_units"]:
		defender_losses += maxi(0, unit["max_soldiers"] - unit["soldiers"])

	# Relic: first_hit_immune reduces attacker losses by 30%
	if RelicManager.has_first_hit_immune(atk_pid):
		var reduced: int = int(float(attacker_losses) * 0.3)
		attacker_losses = maxi(attacker_losses - reduced, 0)
		log.append("暗影斗篷: 进攻方损失减少 %d" % reduced)

	# Equipment: kill_heal (blood_moon_blade)
	var winner_pid: int = atk_pid if winner == "attacker" else def_pid
	if winner_pid >= 0:
		for hero in HeroSystem.get_available_heroes():
			if HeroSystem.has_equipment_passive(hero["id"], "kill_heal"):
				if winner == "attacker":
					attacker_losses = maxi(attacker_losses - 1, 0)
				else:
					defender_losses = maxi(defender_losses - 1, 0)
				log.append("装备: 胜利回复1兵")
				break

	# Slave capture
	var slaves_captured: int = 0
	if winner == "attacker":
		slaves_captured = _check_slave_capture(atk_pid, state["def_units"])
		var relic_slave_bonus: int = RelicManager.get_victory_slave_bonus(atk_pid)
		if relic_slave_bonus > 0:
			slaves_captured += relic_slave_bonus
			log.append("血旗遗物: 额外俘获 %d 奴隶" % relic_slave_bonus)
	else:
		slaves_captured = _check_slave_capture(def_pid, state["atk_units"])

	log.append("=== 战斗结束 === %s胜 | 攻方损失 %d | 守方损失 %d | 俘获奴隶 %d" % [
		"进攻方" if winner == "attacker" else "防守方",
		attacker_losses, defender_losses, slaves_captured])

	var combat_result := {
		"winner": winner,
		"attacker_losses": attacker_losses,
		"defender_losses": defender_losses,
		"slaves_captured": slaves_captured,
		"wall_destroyed": wall_destroyed,
		"details": log,
	}

	EventBus.combat_result.emit(atk_pid,
		"player_%d" % def_pid if def_pid >= 0 else "ai_defender",
		winner == "attacker")

	return combat_result


# ---------------------------------------------------------------------------
# Slave Capture (preserved from original)
# ---------------------------------------------------------------------------

func _check_slave_capture(winner_id: int, loser_units: Array) -> int:
	if loser_units.is_empty():
		return 0
	var count: int = SLAVE_BASE_CAPTURE
	var faction_id: int = GameManager.get_player_faction(winner_id)
	var params: Dictionary = FactionData.FACTION_PARAMS.get(faction_id, {})
	var capture_mult: float = params.get("slave_capture_bonus", 1.0)
	count = int(ceil(float(count) * capture_mult))
	if BuffManager.has_guaranteed_slave(winner_id):
		count = maxi(count, 2)
		BuffManager.consume_buff(winner_id, "guaranteed_slave")
	if winner_id >= 0:
		for hero in HeroSystem.get_available_heroes():
			if HeroSystem.has_equipment_passive(hero["id"], "capture_bonus"):
				var bonus: float = HeroSystem.get_equipment_passive_value(hero["id"], "capture_bonus")
				if randf() < bonus:
					count += 1
				break
	return count


# ---------------------------------------------------------------------------
# Utility Helpers
# ---------------------------------------------------------------------------

func _tile_to_ai_key(tile: Dictionary) -> String:
	var lf: int = tile.get("light_faction", -1)
	if lf == FactionData.LightFaction.HUMAN_KINGDOM:
		return "human"
	elif lf == FactionData.LightFaction.HIGH_ELVES:
		return "elf"
	elif lf == FactionData.LightFaction.MAGE_TOWER:
		return "mage"
	var of: int = tile.get("original_faction", -1)
	if of == FactionData.FactionID.ORC:
		return "orc_ai"
	elif of == FactionData.FactionID.PIRATE:
		return "pirate_ai"
	elif of == FactionData.FactionID.DARK_ELF:
		return "dark_elf_ai"
	return ""


## Maps any unit type string to one of the 8 base troop types.
func _get_troop_base_type(unit_type: String) -> String:
	# Direct matches
	if unit_type in ["ashigaru", "samurai", "archer", "cavalry", "ninja", "priest", "mage_unit", "cannon"]:
		return unit_type
	# Faction-specific mapping
	match unit_type:
		"grunt", "militia", "dwarf_ironguard", "skeleton_legion", "treant", \
		"orc_ashigaru", "pirate_ashigaru", "human_ashigaru", "elf_ashigaru":
			return "ashigaru"
		"troll", "warrior", "temple_guard", "blood_berserker", \
		"orc_samurai", "de_samurai", "human_samurai":
			return "samurai"
		"elf_ranger", "gunner", "green_archer", "pirate_archer", "elf_archer":
			return "archer"
		"warg_rider", "knight", "cold_lizard", "alliance_vanguard", \
		"orc_cavalry", "de_cavalry", "human_cavalry", "dark_elf_ultimate":
			return "cavalry"
		"assassin", "shadow_walker", "de_ninja":
			return "ninja"
		"cutthroat":
			return "ashigaru"
		"apprentice_mage", "battle_mage", "archmage", "elf_mage", "arcane_artillery", \
		"mage_apprentice", "mage_battle", "mage_grand":
			return "mage_unit"
		"bombardier", "goblin_artillery", "pirate_cannon", "pirate_ultimate":
			return "cannon"
		"orc_ultimate":
			return "samurai"
	return "ashigaru"  # Default fallback


func _get_hero_active_skill(hero_id: String) -> Dictionary:
	if hero_id == "" or not FactionData.HEROES.has(hero_id):
		return {}
	var hdata: Dictionary = FactionData.HEROES[hero_id]
	var skill_name: String = hdata.get("active", "")
	if skill_name == "":
		return {}
	# Map skill names to properties
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


func _get_highest_int(units: Array) -> int:
	var best: int = 0
	for unit in units:
		best = maxi(best, int(unit["int_stat"]))
	return best


func _get_all_alive(units: Array) -> Array:
	var result: Array = []
	for unit in units:
		if unit["is_alive"] and unit["soldiers"] > 0:
			result.append(unit)
	return result


func _get_alive_in_row(units: Array, row: String) -> Array:
	var result: Array = []
	for unit in units:
		if unit["is_alive"] and unit["soldiers"] > 0 and unit["row"] == row:
			result.append(unit)
	return result


func _filter_by_row(units: Array, row: String) -> Array:
	var result: Array = []
	for unit in units:
		if unit["row"] == row:
			result.append(unit)
	return result


func _count_alive_in_row(units: Array, row: String) -> int:
	var count: int = 0
	for unit in units:
		if unit["is_alive"] and unit["soldiers"] > 0 and unit["row"] == row:
			count += 1
	return count


func _count_total_soldiers(units: Array) -> int:
	var total: int = 0
	for unit in units:
		if unit["is_alive"]:
			total += unit["soldiers"]
	return total


func _find_most_wounded_ally(allies: Array, self_unit: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_ratio: float = 1.0
	for ally in allies:
		if not ally["is_alive"] or ally == self_unit:
			continue
		var ratio: float = float(ally["soldiers"]) / float(maxi(ally["max_soldiers"], 1))
		if ratio < best_ratio:
			best_ratio = ratio
			best = ally
	return best
