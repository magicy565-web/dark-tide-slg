extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## combat_resolver.gd - Turn-based Sengoku Rance-style combat (v1.0 rewrite)
## Front row (3 slots) + Back row (3 slots), SPD-based action queue, 12-round max.
## Damage formula: soldiers × max(1, ATK - DEF) / 10 × skill_mult × terrain_mult
## Defender wins on timeout (12 rounds).

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
const MAX_ROUNDS: int = 12
const FRONT_SLOTS: int = 3       # indices 0, 1, 2
const BACK_SLOTS: int = 3        # indices 3, 4, 5
const TOTAL_SLOTS: int = 6
const SIEGE_DAMAGE_MULT: float = 0.5
const CANNON_SIEGE_MULT: float = 2.0
const WALL_DAMAGE_MULTIPLIER: float = 0.5
const SLAVE_BASE_CAPTURE: int = 1
const MORALE_START: int = 100
const MORALE_PER_SOLDIER_KILLED: int = 5
const MORALE_ALLY_ELIMINATED: int = 15
const MORALE_ROUT_THRESHOLD: int = 0
const MORALE_ROUT_LOSS_PCT: float = 0.30
const MORALE_ORDER_DEBUFF: int = 20
const MORALE_ORDER_THRESHOLD: int = 76

# ── Commander Tactical Orders ──
enum TacticalDirective { NONE, ALL_OUT, HOLD_LINE, GUERRILLA, FOCUS_FIRE, AMBUSH, DUEL, RETREAT }

# Per-unit battle commands (個別指令 — SR07 aligned)
enum UnitCommand { AUTO, ATTACK, GUARD, CHARGE }

const UNIT_COMMAND_DATA: Dictionary = {
	UnitCommand.AUTO: {"name": "自動", "desc": "AI自動行動"},
	UnitCommand.ATTACK: {"name": "攻撃", "desc": "通常攻撃", "atk_mult": 1.0, "def_mult": 1.0},
	UnitCommand.GUARD: {"name": "防御", "desc": "DEF+50%, ATK-50%, 士気回復+10", "atk_mult": 0.5, "def_mult": 1.5, "morale_regen": 10},
	UnitCommand.CHARGE: {"name": "突撃", "desc": "ATK+40%, DEF-30%, 必ず先制", "atk_mult": 1.4, "def_mult": 0.7, "preemptive": true},
}

const DIRECTIVE_DATA: Dictionary = {
	TacticalDirective.NONE: {"name": "无", "atk_mult": 1.0, "def_mult": 1.0},
	TacticalDirective.ALL_OUT: {
		"name": "猛攻", "desc": "全军ATK+25%, DEF-15%, 最速单位获得先制攻击",
		"atk_mult": 1.25, "def_mult": 0.85, "first_strike": true,
	},
	TacticalDirective.HOLD_LINE: {
		"name": "坚守", "desc": "全军DEF+25%, ATK-15%, 超时判定改为进攻方胜",
		"atk_mult": 0.85, "def_mult": 1.25, "timeout_attacker_wins": true,
	},
	TacticalDirective.GUERRILLA: {
		"name": "游击", "desc": "后排ATK+30%, 前排DEF+15%, 前排存活时后排不可被选为目标",
		"back_atk_mult": 1.30, "front_def_mult": 1.15, "protect_back_row": true,
	},
	TacticalDirective.FOCUS_FIRE: {
		"name": "集火", "desc": "全军ATK+10%, 所有单位集中攻击敌方最低HP目标",
		"atk_mult": 1.10, "def_mult": 1.0, "focus_lowest_hp": true,
	},
	TacticalDirective.AMBUSH: {
		"name": "奇袭", "desc": "第1回合ATK+40%, 之后ATK-10%, 首回合全军先制",
		"round1_atk_mult": 1.40, "after_atk_mult": 0.90, "def_mult": 1.0, "round1_preemptive": true,
	},
	TacticalDirective.DUEL: {
		"name": "一骑打", "desc": "英雄单挑, 胜者全军ATK+20%",
		"atk_mult": 1.0, "def_mult": 1.0, "duel_mode": true,
	},
	TacticalDirective.RETREAT: {
		"name": "撤退", "desc": "全军撤退: 后卫承受伤害, 主力保全(损失20%兵力)",
		"atk_mult": 0.5, "def_mult": 0.5, "retreat_mode": true,
	},
}

# Skill timing constants for hero active skills
const SKILL_TIMING_AUTO: int = 0
const SKILL_TIMING_ROUND1: int = 1
const SKILL_TIMING_ROUND4: int = 4
const SKILL_TIMING_ROUND8: int = 8

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

	# v4.6: time_slow — if any unit on one side has time_slow, enemy SPD-3 first round
	var _ts_atk_on_def: bool = false
	for _ts_u in state["atk_units"]:
		if "time_slow" in _ts_u["passives"]:
			_ts_atk_on_def = true
			break
	if _ts_atk_on_def:
		for _ts_d in state["def_units"]:
			_ts_d["spd"] = maxf(_ts_d["spd"] - 3.0, 1.0)
		log.append("时间减速! 敌方SPD-3(首回合)")
	var _ts_def_on_atk: bool = false
	for _ts_u2 in state["def_units"]:
		if "time_slow" in _ts_u2["passives"]:
			_ts_def_on_atk = true
			break
	if _ts_def_on_atk:
		for _ts_a in state["atk_units"]:
			_ts_a["spd"] = maxf(_ts_a["spd"] - 3.0, 1.0)
		log.append("时间减速! 进攻方SPD-3(首回合)")

	# -- Apply Commander Tactical Orders --
	_apply_directive_modifiers(state)

	# -- Initialize Commander Intervention System --
	var interventions_enabled: bool = attacker.get("player_controlled", false)
	if interventions_enabled:
		CommanderIntervention.initialize_for_battle(
			state["atk_units"],
			_get_hero_list(state["atk_units"])
		)
		state["interventions_enabled"] = true
		log.append("[color=cyan]指挥点数: %d/%d — 战斗中可使用指挥干预![/color]" % [
			CommanderIntervention.get_current_cp(), CommanderIntervention.get_max_cp()])
	else:
		state["interventions_enabled"] = false

	# Log directive choice
	var atk_dir: int = state.get("atk_directive", TacticalDirective.NONE)
	if atk_dir != TacticalDirective.NONE:
		var dir_data: Dictionary = DIRECTIVE_DATA.get(atk_dir, {})
		log.append("[color=cyan]战术指令: %s — %s[/color]" % [dir_data.get("name", ""), dir_data.get("desc", "")])
	var def_dir: int = state.get("def_directive", TacticalDirective.NONE)
	if def_dir != TacticalDirective.NONE:
		var dir_data_d: Dictionary = DIRECTIVE_DATA.get(def_dir, {})
		log.append("[color=orange]防守方指令: %s[/color]" % dir_data_d.get("name", ""))

	# -- Check for full retreat (全軍撤退, Rance 07 RETREAT) --
	var atk_retreat: bool = (state.get("atk_directive", TacticalDirective.NONE) == TacticalDirective.RETREAT)
	var def_retreat: bool = (state.get("def_directive", TacticalDirective.NONE) == TacticalDirective.RETREAT)

	if atk_retreat:
		log.append("[color=yellow]进攻方下令全军撤退![/color]")
		# Rearguard takes heavy damage, main force escapes
		var total_atk_soldiers: int = 0
		for u in state["atk_units"]:
			total_atk_soldiers += u["soldiers"]
		var retreat_loss: int = maxi(1, int(float(total_atk_soldiers) * 0.20))
		# Slowest unit is rearguard — takes most losses
		var sorted_units: Array = state["atk_units"].duplicate()
		sorted_units.sort_custom(func(a, b): return a["spd"] < b["spd"])
		var remaining_loss: int = retreat_loss
		for u in sorted_units:
			if remaining_loss <= 0:
				break
			var unit_loss: int = mini(remaining_loss, u["soldiers"])
			u["soldiers"] -= unit_loss
			remaining_loss -= unit_loss
			if u["soldiers"] <= 0:
				u["is_alive"] = false
			log.append("  %s 殿后: 损失 %d 兵" % [u["unit_type"], unit_loss])
		# Defender takes no losses in a retreat
		log.append("主力成功撤退! 总损失 %d 兵" % retreat_loss)
		return _finalize_result(state, "defender", false, log, tile)

	if def_retreat:
		log.append("[color=yellow]防守方下令全军撤退![/color]")
		var total_def_soldiers: int = 0
		for u in state["def_units"]:
			total_def_soldiers += u["soldiers"]
		var def_retreat_loss: int = maxi(1, int(float(total_def_soldiers) * 0.20))
		var def_sorted: Array = state["def_units"].duplicate()
		def_sorted.sort_custom(func(a, b): return a["spd"] < b["spd"])
		var def_remaining_loss: int = def_retreat_loss
		for u in def_sorted:
			if def_remaining_loss <= 0:
				break
			var unit_loss: int = mini(def_remaining_loss, u["soldiers"])
			u["soldiers"] -= unit_loss
			def_remaining_loss -= unit_loss
			if u["soldiers"] <= 0:
				u["is_alive"] = false
			log.append("  %s 殿后: 损失 %d 兵" % [u["unit_type"], unit_loss])
		log.append("防守方撤退! 总损失 %d 兵" % def_retreat_loss)
		return _finalize_result(state, "attacker", false, log, tile)

	# Morale: Order debuff on enemies
	if OrderManager.get_order() >= MORALE_ORDER_THRESHOLD:
		for u in state["def_units"]:
			if "morale_immune" not in u["passives"] and not u["immovable"]:
				u["morale"] = maxi(u["morale"] - MORALE_ORDER_DEBUFF, 0)

	log.append("=== 战斗开始 === 进攻方 %d 单位 vs 防守方 %d 单位" % [
		state["atk_units"].size(), state["def_units"].size()])

	# Log counter matchup analysis
	var _has_counter_info: bool = false
	for atk_u in state["atk_units"]:
		if not atk_u["is_alive"]:
			continue
		for def_u in state["def_units"]:
			if not def_u["is_alive"]:
				continue
			var c: Dictionary = CounterMatrix.get_counter(atk_u["unit_type"], def_u["unit_type"])
			if c["advantage"] == "hard_counter":
				if not _has_counter_info:
					log.append("=== 兵种克制分析 ===")
					_has_counter_info = true
				log.append("[color=green]★ %s 硬克 %s: %s[/color]" % [atk_u["unit_type"], def_u["unit_type"], c["label"]])
			elif c["advantage"] == "weak":
				if not _has_counter_info:
					log.append("=== 兵种克制分析 ===")
					_has_counter_info = true
				log.append("[color=red]✗ %s 被克 %s: %s[/color]" % [atk_u["unit_type"], def_u["unit_type"], c["label"]])
	# Also check defender-side counters
	for def_u in state["def_units"]:
		if not def_u["is_alive"]:
			continue
		for atk_u in state["atk_units"]:
			if not atk_u["is_alive"]:
				continue
			var c2: Dictionary = CounterMatrix.get_counter(def_u["unit_type"], atk_u["unit_type"])
			if c2["advantage"] == "hard_counter":
				if not _has_counter_info:
					log.append("=== 兵种克制分析 ===")
					_has_counter_info = true
				log.append("[color=green]★ %s 硬克 %s: %s[/color]" % [def_u["unit_type"], atk_u["unit_type"], c2["label"]])
			elif c2["advantage"] == "weak":
				if not _has_counter_info:
					log.append("=== 兵种克制分析 ===")
					_has_counter_info = true
				log.append("[color=red]✗ %s 被克 %s: %s[/color]" % [def_u["unit_type"], atk_u["unit_type"], c2["label"]])

	# -- Phase 1: Wall / Siege --
	var tile_idx: int = tile.get("index", -1)
	var wall_hp: float = 0.0
	if tile_idx >= 0 and tile_idx < GameManager.tiles.size():
		wall_hp = float(LightFactionAI.get_wall_hp(tile_idx))
	# Terrain wall bonus
	var tile_terrain: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_info: Dictionary = FactionData.TERRAIN_DATA.get(tile_terrain, {})
	wall_hp += float(terrain_info.get("wall_hp_bonus", 0))
	# Equipment wall bonus (only check defender's heroes)
	if def_pid >= 0:
		for hero in HeroSystem.get_heroes_for_player(def_pid):
			if HeroSystem.has_equipment_passive(hero["id"], "node_wall_bonus"):
				var bonus: float = HeroSystem.get_equipment_passive_value(hero["id"], "node_wall_bonus")
				wall_hp += bonus
				log.append("装备: 城防+%.0f" % bonus)
	# Blast barrel
	var blast_barrel_dmg: Variant = BuffManager.get_buff_value(atk_pid, "wall_damage")
	if blast_barrel_dmg != null and blast_barrel_dmg > 0:
		wall_hp = maxf(wall_hp - float(blast_barrel_dmg), 0.0)
		log.append("爆破桶: 城防-%.0f" % float(blast_barrel_dmg))

	# v4.6: siege_bonus — equipment passive reduces wall HP by 10
	if atk_pid >= 0:
		for _sb_hero in HeroSystem.get_heroes_for_player(atk_pid):
			if HeroSystem.has_equipment_passive(_sb_hero["id"], "siege_bonus"):
				wall_hp = maxf(wall_hp - 10.0, 0.0)
				log.append("装备: 攻城加成 城防-10")
				break

	# Passive: siege_ignore — if ANY attacker unit has siege_ignore, skip wall phase entirely
	var _has_siege_ignore: bool = false
	for _si_unit in state["atk_units"]:
		if "siege_ignore" in _si_unit["passives"]:
			_has_siege_ignore = true
			break

	if wall_hp > 0.0 and _has_siege_ignore:
		log.append("无视城防! 攻城部队直接突入!")
	elif wall_hp > 0.0 and StrategicResourceManager.ignores_walls(atk_pid):
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

	# Reset per-battle state
	for u in state["atk_units"]:
		u["bloodlust_bonus"] = 0
	for u in state["def_units"]:
		u["bloodlust_bonus"] = 0

	# -- Phase 3: Main battle loop (up to 12 rounds) --
	var winner: String = ""
	for round_num in range(1, MAX_ROUNDS + 1):
		state["round"] = round_num
		log.append("--- 第 %d 回合 ---" % round_num)

		_start_of_round(state, log)

		# v4.6: time_slow — restore SPD after round 1
		if round_num == 2:
			if _ts_atk_on_def:
				for _ts_r in state["def_units"]:
					_ts_r["spd"] = _ts_r["spd"] + 3.0
			if _ts_def_on_atk:
				for _ts_r2 in state["atk_units"]:
					_ts_r2["spd"] = _ts_r2["spd"] + 3.0

		# -- Commander Intervention Phase --
		if state.get("interventions_enabled", false):
			CommanderIntervention.tick_cooldowns()
			CommanderIntervention.check_cp_regen(round_num)
			var pending: Array = state.get("pending_interventions", [])
			for intervention in pending:
				if intervention.get("round", -1) == round_num:
					CommanderIntervention.execute(
						intervention["type"], state, intervention.get("target", null), log)
			# Emit signal for UI to collect player decisions
			if CommanderIntervention.get_current_cp() > 0:
				var available: Array = CommanderIntervention.get_available_interventions()
				if not available.is_empty():
					state["intervention_options"] = available
					state["intervention_cp"] = CommanderIntervention.get_current_cp()
					EventBus.combat_intervention_phase.emit(state)

		var queue: Array = _build_action_queue(state)

		for unit in queue:
			if not unit.get("is_alive", true):
				continue
			if unit.get("is_routed", false):
				continue
			if unit["actions_this_round"] >= unit["max_actions"]:
				continue
			_execute_action(state, unit, log)

		var result: String = _end_of_round(state, log)
		if result != "continue":
			winner = result
			break

	# 12 rounds elapsed → defender wins (unless HOLD_LINE directive)
	if winner == "":
		if state.get("atk_directive", TacticalDirective.NONE) == TacticalDirective.HOLD_LINE:
			winner = "attacker"
			log.append("坚守指令: 超时判定 — 进攻方胜!")
		elif state.get("def_directive", TacticalDirective.NONE) == TacticalDirective.HOLD_LINE:
			winner = "defender"
			log.append("坚守指令: 超时判定 — 防守方坚守成功!")
		else:
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

	# Apply player slot preferences to attacker units if provided
	var slot_prefs: Dictionary = attacker.get("slot_preferences", {})
	if not slot_prefs.is_empty():
		_apply_slot_preferences(atk_units, slot_prefs)

	# Territory effect bonuses: apply flat ATK/DEF/SPD to all attacker units
	var _te_atk_b: int = attacker.get("territory_atk_bonus", 0)
	var _te_def_b: int = attacker.get("territory_def_bonus", 0)
	var _te_spd_b: int = attacker.get("territory_spd_bonus", 0)
	if _te_atk_b > 0 or _te_def_b > 0 or _te_spd_b > 0:
		for _te_u in atk_units:
			_te_u["atk"] = _te_u["atk"] + float(_te_atk_b)
			_te_u["def"] = _te_u["def"] + float(_te_def_b)
			_te_u["spd"] = _te_u["spd"] + float(_te_spd_b)

	# v4.6: command_bonus — if any unit has command_bonus, SPD+2 to all same-side units
	var _atk_has_cmd: bool = false
	for _cmd_u in atk_units:
		if "command_bonus" in _cmd_u["passives"]:
			_atk_has_cmd = true
			break
	if _atk_has_cmd:
		for _cmd_u2 in atk_units:
			_cmd_u2["spd"] = _cmd_u2["spd"] + 2.0
	var _def_has_cmd: bool = false
	for _cmd_u3 in def_units:
		if "command_bonus" in _cmd_u3["passives"]:
			_def_has_cmd = true
			break
	if _def_has_cmd:
		for _cmd_u4 in def_units:
			_cmd_u4["spd"] = _cmd_u4["spd"] + 2.0

	# Mana pools: max = 10 + highest INT × 2
	var atk_max_int: int = _get_highest_int(atk_units)
	var def_max_int: int = _get_highest_int(def_units)

	# Compute synergy special effects from troop composition
	var atk_fake_army: Array = []
	for raw in raw_atk:
		atk_fake_army.append({"troop_id": raw.get("troop_id", raw.get("type", ""))})
	var def_fake_army: Array = []
	for raw in raw_def:
		def_fake_army.append({"troop_id": raw.get("troop_id", raw.get("type", ""))})
	var atk_synergy_specials: Dictionary = GameData.compute_synergy_specials(atk_fake_army)
	var def_synergy_specials: Dictionary = GameData.compute_synergy_specials(def_fake_army)

	# Apply per-unit commands
	var unit_cmds: Dictionary = attacker.get("unit_commands", {})
	for i in range(atk_units.size()):
		if unit_cmds.has(i):
			atk_units[i]["unit_command"] = unit_cmds[i]
		else:
			atk_units[i]["unit_command"] = UnitCommand.AUTO
	for i in range(def_units.size()):
		def_units[i]["unit_command"] = UnitCommand.AUTO

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
		"atk_synergy_specials": atk_synergy_specials,
		"def_synergy_specials": def_synergy_specials,
		# Commander Tactical Orders
		"atk_directive": attacker.get("tactical_directive", TacticalDirective.NONE),
		"def_directive": defender.get("tactical_directive", TacticalDirective.NONE),
		"atk_skill_timing": attacker.get("skill_timing", {}),  # hero_id -> round_number
		"def_skill_timing": defender.get("skill_timing", {}),
		"atk_protected_slot": attacker.get("protected_slot", -1),
		"atk_decoy_slot": attacker.get("decoy_slot", -1),
		"def_protected_slot": defender.get("protected_slot", -1),
		"def_decoy_slot": defender.get("decoy_slot", -1),
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


func _apply_slot_preferences(units: Array, prefs: Dictionary) -> void:
	## Re-assign slot positions based on player preferences.
	## prefs: { troop_index(int) : preferred_slot(int 0-5) }
	if units.is_empty() or prefs.is_empty():
		return
	var pref_assignments: Dictionary = {}  # slot -> unit
	var unassigned: Array = []
	for i in range(units.size()):
		if prefs.has(i):
			var desired_slot: int = prefs[i]
			if not pref_assignments.has(desired_slot):
				pref_assignments[desired_slot] = units[i]
				units[i]["slot"] = desired_slot
				units[i]["row"] = "front" if desired_slot < FRONT_SLOTS else "back"
			else:
				unassigned.append(units[i])
		else:
			unassigned.append(units[i])
	# Assign remaining units to empty slots
	var used_slots: Dictionary = {}
	for slot in pref_assignments:
		used_slots[slot] = true
	for unit in unassigned:
		var default_row: String = TROOP_DEFAULT_ROW.get(unit["unit_type"], "front")
		var start: int = 0 if default_row == "front" else FRONT_SLOTS
		var end_slot: int = FRONT_SLOTS if default_row == "front" else TOTAL_SLOTS
		var assigned: bool = false
		for s in range(start, end_slot):
			if not used_slots.has(s):
				unit["slot"] = s
				unit["row"] = "front" if s < FRONT_SLOTS else "back"
				used_slots[s] = true
				assigned = true
				break
		if not assigned:
			for s in range(TOTAL_SLOTS):
				if not used_slots.has(s):
					unit["slot"] = s
					unit["row"] = "front" if s < FRONT_SLOTS else "back"
					used_slots[s] = true
					break


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

	# Troop registry uses singular "passive" key — merge it in
	var troop_passive: String = raw.get("passive", "")
	if troop_passive != "" and troop_passive not in passives:
		passives.append(troop_passive)

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

		# Affection combat bonuses
		var aff: int = HeroSystem.hero_affection.get(hero_id, 0)
		if aff >= 10:
			base_atk += 4; base_def += 3
		elif aff >= 8:
			base_atk += 3; base_def += 2
		elif aff >= 5:
			base_atk += 2; base_def += 1
		elif aff >= 3:
			base_atk += 1

		# Story choice combat effects — apply stat modifiers from branching story flags
		var story_flags: Dictionary = StoryEventSystem.get_hero_flags(hero_id)
		# Rin (凛) — path bonuses
		if story_flags.get("rin_pure_love", false):
			base_atk += 2; base_def += 2
		elif story_flags.get("rin_redemption", false):
			base_def += 4
		elif story_flags.get("rin_dark", false):
			base_atk += 4
			if randf() < 0.15:
				passives.append("refuse_orders")  # 15% skip action
		elif story_flags.get("rin_puppet", false):
			base_atk += 3; base_def += 1
		# Suirei (翠玲) — path bonuses
		if story_flags.get("suirei_guardian", false):
			base_def += 4
		elif story_flags.get("suirei_conqueror", false):
			base_atk += 4
		elif story_flags.get("suirei_ambassador", false):
			base_def += 2; base_atk += 2
		# Sou (蒼) — path bonuses
		if story_flags.get("sou_scholar", false):
			int_stat += 6
		elif story_flags.get("sou_power", false):
			base_atk += 4
		elif story_flags.get("sou_forbidden", false):
			base_atk += 5; base_def -= 1
			if randf() < 0.10:
				passives.append("wild_aoe")  # 10% random AoE hitting both sides
		# Formation bonuses (endgame)
		if story_flags.get("rin_dual_blade_formation", false):
			base_atk *= 1.5
		if story_flags.get("suirei_forest_formation", false):
			base_def *= 1.3
		if story_flags.get("sou_arcane_formation", false):
			int_stat *= 1.4

		# Yukino (雪乃) — path bonuses
		if story_flags.get("yukino_redemption", false):
			base_def += 4
			passives.append("yukino_heal_2")  # +2 heal per round (lowest unit)
		elif story_flags.get("yukino_corruption", false):
			base_atk += 4
			passives.append("yukino_curse")  # curse enemies -1 DEF per round
		elif story_flags.get("yukino_devotion", false):
			base_atk += 3; base_def += 3
			if randf() < 0.10:
				passives.append("refuse_orders")  # 10% skip action "拒绝非战斗命令"
		# Momiji (紅葉) — path bonuses
		if story_flags.get("momiji_partner", false):
			base_def += 2
			passives.append("momiji_gold_bonus_20")  # +20% gold bonus on victory
		elif story_flags.get("momiji_asset", false):
			base_atk += 3; base_def += 3
		elif story_flags.get("momiji_rival", false):
			base_atk += 4
			passives.append("momiji_gold_bonus_15")  # 15% chance bonus gold
		# Gekka (月華) — path bonuses
		if story_flags.get("gekka_harmony", false):
			base_def += 5
			passives.append("earth_shield")  # first hit deals 0 damage (one-time)
		elif story_flags.get("gekka_severance", false):
			base_atk += 5
			passives.append("gekka_drain")  # drain 1 soldier from random enemy per round
		elif story_flags.get("gekka_resonance", false):
			base_atk += 3; base_def += 3
			passives.append("gekka_aoe_10")  # 10% chance AoE 1 damage to all enemies
		# Hakagure (葉隠) — path bonuses
		if story_flags.get("hakagure_freedom", false):
			base_atk += 4; spd += 2
			passives.append("hakagure_first_strike")  # acts first regardless of SPD
		elif story_flags.get("hakagure_reforge", false):
			base_atk += 3; base_def += 4
			passives.append("hakagure_nullify_crit")  # 20% nullify enemy crit
		elif story_flags.get("hakagure_unleash", false):
			base_atk += 6; base_def -= 2
			passives.append("hakagure_instant_kill")  # 25% instant kill on ≤2 soldiers
		# Akane (茜/朱音) — path bonuses
		if story_flags.get("akane_atonement", false):
			base_def += 5
			passives.append("akane_heal_ally_3")  # heal nearest ally 3 HP per round
		elif story_flags.get("akane_weapon", false):
			base_atk += 5
			passives.append("akane_blood_sacrifice")  # consume 2 own HP for +3 ATK per round
		elif story_flags.get("akane_freewill", false):
			base_atk += 3; base_def += 2
			passives.append("akane_faith_shield")  # 20% chance negate lethal damage once
		elif story_flags.get("akane_duty_first", false):
			base_def += 4; base_atk += 1
		elif story_flags.get("akane_love_first", false):
			base_atk += 4; base_def += 1
		# Hanabi (花火) — path bonuses
		if story_flags.get("hanabi_devoted_flame", false):
			base_atk += 5
			passives.append("hanabi_protect_explosion")  # if ally takes lethal hit, 30% counter-explode
		elif story_flags.get("hanabi_arsenal_path", false):
			base_atk += 3; base_def += 3
			passives.append("hanabi_siege_bonus_50")  # +50% siege damage
		elif story_flags.get("hanabi_mature_path", false):
			base_atk += 3; base_def += 2
			passives.append("hanabi_stable_cannon")  # cannon self-destruct rate halved
		elif story_flags.get("hanabi_engineer_bond", false):
			base_atk += 4; base_def += 1
		elif story_flags.get("hanabi_protected", false):
			base_def += 4; base_atk += 1
			passives.append("hanabi_workshop_output")  # +25% equipment production
		# Hibiki (響) — path bonuses
		if story_flags.get("hibiki_reforge_path", false):
			base_def += 5
			passives.append("hibiki_iron_wall")  # reduce first 2 damage taken each round to 0
		elif story_flags.get("hibiki_balance_path", false):
			base_atk += 3; base_def += 3
			passives.append("hibiki_tempered_steel")  # +1 ATK and +1 DEF each round (max 3 stacks)
		elif story_flags.get("hibiki_broken_anvil", false):
			base_atk += 6; base_def -= 1
			if randf() < 0.10:
				passives.append("refuse_orders")  # 10% skip action from rage
		elif story_flags.get("hibiki_master_smith", false):
			base_def += 4; base_atk += 2
			passives.append("hibiki_equipment_bonus")  # all allies +1 DEF from superior gear
		elif story_flags.get("hibiki_frontline", false):
			base_atk += 5; base_def += 1
			passives.append("hibiki_hammer_stun")  # 15% stun on attack
		# Kaede (楓) — path bonuses
		if story_flags.get("kaede_righteous_bond", false):
			base_def += 4; spd += 2
			passives.append("kaede_shadow_guard")  # intercept first attack on lowest HP ally
		elif story_flags.get("kaede_pragmatic_bond", false):
			base_atk += 5; spd += 1
			passives.append("kaede_assassinate")  # 20% chance to bypass DEF on attack
		elif story_flags.get("kaede_shared_pain", false):
			base_atk += 3; base_def += 2; spd += 1
			passives.append("kaede_intel_bonus")  # reveal enemy stats at battle start
		elif story_flags.get("kaede_solo_mission", false):
			base_atk += 4; spd += 3
			passives.append("kaede_lone_wolf")  # +2 ATK when no adjacent allies
		elif story_flags.get("kaede_team_mission", false):
			base_atk += 3; base_def += 2; spd += 1
			passives.append("kaede_coordinated_strike")  # adjacent allies +1 ATK
		# Mei (冥) — path bonuses
		if story_flags.get("mei_past_seeker", false):
			base_def += 4; int_stat += 3
			passives.append("mei_soul_mend")  # heal all allies 1 HP per round
		elif story_flags.get("mei_embrace_death", false):
			base_atk += 5; int_stat += 3
			passives.append("mei_death_aura")  # enemies in range take 1 damage per round
		elif story_flags.get("mei_dual_existence", false):
			base_atk += 3; base_def += 2; int_stat += 2
			passives.append("mei_life_death_cycle")  # 15% chance revive 1 fallen ally as skeleton
		elif story_flags.get("mei_sacrifice_bond", false):
			base_def += 5; int_stat += 2
			passives.append("mei_eternal_guard")  # take lethal damage for master once per battle
		elif story_flags.get("mei_sealed_heart", false):
			base_atk += 3; base_def += 3; int_stat += 1
		elif story_flags.get("mei_legion_anchor", false):
			base_atk += 5; int_stat += 2
			passives.append("mei_undead_surge")  # summon 2 skeleton soldiers per round
			if randf() < 0.10:
				passives.append("mei_berserk_undead")  # 10% chance skeletons attack both sides

		# Homura (焔) — path bonuses
		if story_flags.get("homura_unleashed_flame", false):
			base_atk += 4; int_stat += 2
			passives.append("homura_wildfire")  # 15% chance AoE splash to adjacent enemies
		elif story_flags.get("homura_precision_flame", false):
			base_atk += 2; int_stat += 3
			passives.append("homura_focused_burn")  # +30% single-target damage
		elif story_flags.get("homura_tactical_flame_final", false):
			int_stat += 4; base_atk -= 1
			passives.append("homura_precision_blaze")  # single-target high damage, no friendly fire
		elif story_flags.get("homura_hybrid_flame_final", false):
			base_atk += 2; int_stat += 2
			passives.append("homura_chaos_flame")  # random single-target or AoE each round
		elif story_flags.get("homura_ashes_final", false):
			base_atk += 5
			if randf() < 0.10:
				passives.append("wild_aoe")  # 10% random AoE hitting both sides
		elif story_flags.get("homura_ember_reborn", false):
			base_atk += 2; base_def += 3
			passives.append("homura_undying_ember")  # survive lethal once per battle

		# Hyouka (冰華) — path bonuses
		if story_flags.get("hyouka_guardian_bond", false):
			base_def += 4; base_atk += 1
			passives.append("hyouka_bodyguard")  # intercept damage to adjacent commander
		elif story_flags.get("hyouka_voice_training", false):
			base_def += 3; base_atk += 2
			passives.append("hyouka_rally_cry")  # adjacent allies +1 DEF
		elif story_flags.get("hyouka_absolute_guardian", false):
			base_def += 5
			passives.append("hyouka_absolute_guard")  # halve damage to adjacent commander
		elif story_flags.get("hyouka_army_wall", false):
			base_def += 3
			passives.append("hyouka_iron_wall_formation")  # all allies +2 DEF for 3 rounds (active)
		elif story_flags.get("hyouka_full_guardian", false):
			base_def += 5; base_atk += 1
		elif story_flags.get("hyouka_hollow_final", false):
			base_def += 4; base_atk += 2
		elif story_flags.get("hyouka_rebuild_final", false):
			base_def += 3; base_atk += 1
			passives.append("hyouka_reforged_shield")  # 20% survive lethal (1 HP)

		# Sara (沙罗) — path bonuses
		if story_flags.get("sara_trade_bond", false):
			base_atk += 2; base_def += 2
			passives.append("sara_trade_profit")  # gain gold each round
		elif story_flags.get("sara_desert_strategist", false):
			int_stat += 4
			passives.append("sara_sandstorm_tactics")  # reduce target hit rate 3 rounds
		elif story_flags.get("sara_pure_business", false):
			base_atk += 3; base_def += 1
			passives.append("sara_precise_calc")  # bonus resources on victory
		elif story_flags.get("sara_chained_homeland", false):
			base_atk += 4
			passives.append("sara_desperate_blade")  # ATK increases as HP decreases
		elif story_flags.get("sara_stripped_final", false):
			base_atk += 5; base_def -= 2
			passives.append("sara_desert_fury")  # AoE burst, self-stun 1 round
		elif story_flags.get("sara_trade_partner", false):
			base_atk += 1; base_def += 1
			passives.append("sara_trade_bonus_10")  # +10% gold bonus
		elif story_flags.get("sara_leverage_homeland", false):
			base_atk += 3

		# Shion (紫苑) — path bonuses
		if story_flags.get("shion_prophet", false):
			int_stat += 6
			passives.append("shion_timeline_intervention")  # predict enemy next action
			if randf() < 0.05:
				passives.append("shion_foresight_terror")  # 5% freeze from visions
		elif story_flags.get("shion_peaceful_scholar", false):
			int_stat += 3; base_def += 2
			passives.append("shion_observer_calm")  # immune to fear/confusion
		elif story_flags.get("shion_ordinary_final", false):
			base_atk += 2; base_def += 2; int_stat += 1
			passives.append("shion_carefree_heart")  # immune to mental debuffs, adj ally morale+1
		elif story_flags.get("shion_rebuilt_genius", false):
			int_stat += 4; base_atk += 1
			passives.append("shion_probability_correction")  # grant 30% evasion to 1 ally, 2 rounds
		elif story_flags.get("shion_emotion_research", false):
			int_stat += 3; base_atk += 1
		elif story_flags.get("shion_gut_choice", false):
			int_stat += 2; base_atk += 2
			passives.append("shion_intuition_dodge")  # 10% dodge any attack
		elif story_flags.get("shion_full_foresight", false):
			int_stat += 5
			if randf() < 0.05:
				passives.append("shion_foresight_terror")
		elif story_flags.get("shion_slow_rebuild", false):
			int_stat += 3; base_def += 1

	# ── Terrain modifiers (data-driven from TERRAIN_DATA) ──
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
	var is_attacker: bool = (side == "attacker")

	var has_ignore_terrain: bool = "ignore_terrain" in passives or "shadow_flight" in passives
	if not has_ignore_terrain:
		if is_attacker:
			base_atk *= terrain_data.get("atk_mult", 1.0)
		else:
			base_def *= terrain_data.get("def_mult", 1.0)
		var troop_base: String = _get_troop_base_type(unit_type)
		var um: Dictionary = terrain_data.get("unit_mods", {}).get(troop_base, {})
		if um.get("ban", false):
			base_atk = 0
			soldiers = 0
		else:
			base_atk += um.get("atk", 0)
			base_def += um.get("def", 0)
			spd += um.get("spd", 0)
	else:
		var troop_base_ign: String = _get_troop_base_type(unit_type)
		var um_ign: Dictionary = terrain_data.get("unit_mods", {}).get(troop_base_ign, {})
		if um_ign.get("atk", 0) > 0: base_atk += um_ign["atk"]
		if um_ign.get("def", 0) > 0: base_def += um_ign["def"]
		if um_ign.get("spd", 0) > 0: spd += um_ign["spd"]

	# Fort defense passive: DEF+3 when defending own node
	if "fort_def_3" in passives and not is_attacker:
		base_def += 3

	# Passive: counter_defend — DEF+2 when on defender side
	if "counter_defend" in passives and not is_attacker:
		base_def += 2

	# Chokepoint combat modifier
	if tile.get("is_chokepoint", false):
		var cp_data: Dictionary = FactionData.CHOKEPOINT_DATA
		if is_attacker:
			base_atk *= (1.0 - cp_data.get("atk_penalty", 0.10))  # -10% ATK
		else:
			base_def *= (1.0 + cp_data.get("def_mult_bonus", 0.20))  # +20% DEF

	# Strategic resource bonuses
	if player_id >= 0:
		base_atk += StrategicResourceManager.get_permanent_atk_bonus(player_id)

	# Training system bonuses (batched lookup)
	if player_id >= 0:
		var train_bonus: Dictionary = ResearchManager.get_unit_stat_bonuses(player_id, unit_type)
		base_atk += train_bonus.get("atk", 0)
		base_def += train_bonus.get("def", 0)
		soldiers += train_bonus.get("hp", 0)  # Training HP bonus → extra soldiers

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
			# Apply difficulty scaling on top of AI threat scaling
			ai_atk *= BalanceManager.get_ai_atk_mult()
			ai_def *= BalanceManager.get_ai_def_mult()
			base_atk *= ai_atk
			base_def *= ai_def

	# Building combat bonuses
	if player_id >= 0:
		var bld: Dictionary = BuildingRegistry.get_all_player_building_effects(player_id)
		if is_attacker:
			base_atk += float(bld.get("atk_bonus", 0))
		else:
			base_def += float(bld.get("def_bonus", 0))
		# Mage building ATK bonus (arcane_institute)
		var troop_base2: String = _get_troop_base_type(unit_type)
		if troop_base2 in ["mage_unit", "priest"]:
			base_atk += float(bld.get("mage_atk_bonus", 0))
		# Elite training (War College Lv3): +1 ATK and +1 DEF to all units
		if bld.get("elite_training", false):
			base_atk += 1.0
			base_def += 1.0
		# Tactical simulation (War College Lv2): +1 SPD to all units
		if bld.get("tactical_sim", false):
			spd += 1.0

	# Determine max actions
	var max_actions: int = 1
	if "extra_action" in passives:
		max_actions = 2

	# Passive: immovable / aoe_immobile — flag to prevent row-swap effects
	var is_immovable: bool = "immovable" in passives or "aoe_immobile" in passives

	# Determine default row
	var row: String = raw.get("row", TROOP_DEFAULT_ROW.get(unit_type, "front"))

	return {
		"slot": -1,  # assigned later
		"row": row,
		"side": side,
		"hero_id": hero_id,
		"unit_type": unit_type,
		"soldiers": soldiers,
		"max_soldiers": raw.get("max_soldiers", soldiers),
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
		"overload_count": 0,
		"bloodlust_bonus": 0,
		"war_cry_used": false,
		"root_bind_used": false,
		"trade_hire_used": false,
		"blood_ritual_used": false,
		"immovable": is_immovable,
		"morale": MORALE_START,
		"is_routed": false,
	}


# ---------------------------------------------------------------------------
# Commander Tactical Orders — Directive Stat Modifiers
# ---------------------------------------------------------------------------

func _apply_directive_modifiers(state: Dictionary) -> void:
	## Apply stat multipliers from tactical directives to all units on each side.
	## AMBUSH is handled per-round in _start_of_round, not here.
	## FOCUS_FIRE targeting is handled in _select_target.
	for side_key in ["atk", "def"]:
		var directive: int = state.get(side_key + "_directive", TacticalDirective.NONE)
		if directive == TacticalDirective.NONE:
			continue
		var units_key: String = side_key + "_units"
		var units: Array = state[units_key]

		match directive:
			TacticalDirective.ALL_OUT:
				for unit in units:
					unit["atk"] = maxf(unit["atk"] * 1.25, 0.0)
					unit["def"] = maxf(unit["def"] * 0.85, 0.0)
			TacticalDirective.HOLD_LINE:
				for unit in units:
					unit["atk"] = maxf(unit["atk"] * 0.85, 0.0)
					unit["def"] = maxf(unit["def"] * 1.25, 0.0)
			TacticalDirective.GUERRILLA:
				for unit in units:
					if unit["row"] == "back":
						unit["atk"] = maxf(unit["atk"] * 1.30, 0.0)
					elif unit["row"] == "front":
						unit["def"] = maxf(unit["def"] * 1.15, 0.0)
			TacticalDirective.FOCUS_FIRE:
				for unit in units:
					unit["atk"] = maxf(unit["atk"] * 1.10, 0.0)
			TacticalDirective.AMBUSH:
				pass  # Handled per-round in _start_of_round


# ---------------------------------------------------------------------------
# Siege Phase
# ---------------------------------------------------------------------------

func _resolve_siege_phase(state: Dictionary, wall_hp: float, tile: Dictionary) -> Dictionary:
	var log: Array = []
	var remaining: float = wall_hp

	# Cache siege buff outside loop — constant for entire siege phase
	var _siege_buff: Variant = BuffManager.get_buff_value(state["atk_pid"], "siege_mult")
	var _siege_mult: float = float(_siege_buff) if _siege_buff != null and _siege_buff > 1.0 else 1.0

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
		# Passive: siege_x3 — siege damage ×3
		if "siege_x3" in unit["passives"]:
			siege_dmg *= 3.0
		# Passive: dwarf_siege_t3 — siege damage ×3 (AoE splash handled after loop)
		if "dwarf_siege_t3" in unit["passives"]:
			siege_dmg *= 3.0
		# v4.6: siege_bonus — extra flat siege damage from equipment
		if "siege_bonus" in unit["passives"]:
			siege_dmg += 10.0
		# Siege buff (cached)
		if _siege_mult > 1.0:
			siege_dmg *= _siege_mult
		remaining -= siege_dmg
		log.append("%s 攻城伤害 %.0f" % [unit["unit_type"], siege_dmg])

	# Passive: dwarf_siege_t3 — after siege phase, deal ATK×0.5 splash to all defenders
	for unit in state["atk_units"]:
		if not unit["is_alive"]:
			continue
		if "dwarf_siege_t3" in unit["passives"]:
			var splash_dmg: int = maxi(1, int(unit["atk"] * 0.5))
			for def_unit in state["def_units"]:
				if def_unit["is_alive"]:
					def_unit["soldiers"] = maxi(0, def_unit["soldiers"] - splash_dmg)
					if def_unit["soldiers"] <= 0:
						def_unit["is_alive"] = false
					log.append("%s 矮人炮术溅射! %s -%d兵" % [unit["unit_type"], def_unit["unit_type"], splash_dmg])

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

	# v4.6: double_shot — unit attacks twice in round 1 (set max_actions=2)
	if state["round"] == 1:
		for _ds_unit in state["atk_units"] + state["def_units"]:
			if _ds_unit["is_alive"] and "double_shot" in _ds_unit["passives"]:
				_ds_unit["max_actions"] = 2
				log.append("%s [%s] 连射准备! 首回合攻击两次" % [_ds_unit["unit_type"], _ds_unit["side"]])
	elif state["round"] == 2:
		# Reset double_shot units back to normal
		for _ds_unit2 in state["atk_units"] + state["def_units"]:
			if "double_shot" in _ds_unit2["passives"] and "extra_action" not in _ds_unit2["passives"]:
				_ds_unit2["max_actions"] = 1

	# ── Commander Tactical Orders: per-round effects ──
	for side_key in ["atk", "def"]:
		var directive: int = state.get(side_key + "_directive", TacticalDirective.NONE)
		var units: Array = state[side_key + "_units"]

		if directive == TacticalDirective.AMBUSH:
			if state["round"] == 1:
				for unit in units:
					if unit["is_alive"]:
						unit["buffs"].append({"id": "ambush_r1", "duration": 1, "value": 0.40})
				var side_name: String = "进攻方" if side_key == "atk" else "防守方"
				log.append("%s 奇袭指令: 第1回合ATK+40%%!" % side_name)
			elif state["round"] == 2:
				# Remove round 1 buff and apply permanent debuff for rest of battle
				for unit in units:
					if unit["is_alive"]:
						unit["buffs"].append({"id": "ambush_after", "duration": 99, "value": -0.10})
				var side_name2: String = "进攻方" if side_key == "atk" else "防守方"
				log.append("%s 奇袭指令: 后续回合ATK-10%%..." % side_name2)

	# Slave fodder dissolution: after round 1, dissolve all slave_fodder units
	if state["round"] >= 2:
		for units_key in ["atk_units", "def_units"]:
			for unit in state[units_key]:
				if unit["is_alive"] and "slave_fodder" in unit["passives"]:
					unit["soldiers"] = 0
					unit["is_alive"] = false
					log.append("%s [%s] 奴隶肉盾溃散! (首轮消耗品)" % [unit["unit_type"], unit["side"]])

	# Mana regen: +1 per side per round
	state["atk_mana"] = mini(state["atk_mana"] + 1, state["atk_mana_max"])
	state["def_mana"] = mini(state["def_mana"] + 1, state["def_mana_max"])

	for unit in state["atk_units"] + state["def_units"]:
		if not unit["is_alive"]:
			continue
		unit["actions_this_round"] = 0

		# Apply per-unit command modifiers
		var cmd: int = unit.get("unit_command", UnitCommand.AUTO)
		if cmd == UnitCommand.GUARD:
			# Guard: regen morale
			unit["morale"] = mini(unit.get("morale", MORALE_START) + 10, MORALE_START)
		elif cmd == UnitCommand.CHARGE:
			# Charge units always act first (handled in action queue)
			pass

		# Passive: regen_1 — restore 1 soldier per round
		if "regen_1" in unit["passives"]:
			if unit["soldiers"] < unit["max_soldiers"]:
				unit["soldiers"] += 1
				log.append("%s [%s] 再生+1兵" % [unit["unit_type"], unit["side"]])

		# Passive: regen_2 — restore 2 soldiers per round
		if "regen_2" in unit["passives"]:
			if unit["soldiers"] < unit["max_soldiers"]:
				var heal_amt: int = mini(2, unit["max_soldiers"] - unit["soldiers"])
				unit["soldiers"] += heal_amt
				log.append("%s [%s] 深根再生+%d兵" % [unit["unit_type"], unit["side"], heal_amt])

		# Passive: necro_summon — spawn a skeleton squad each round
		if "necro_summon" in unit["passives"]:
			var skeleton: Dictionary = {
				"slot": -1, "row": "front", "side": unit["side"],
				"hero_id": "", "unit_type": "skeleton_legion",
				"soldiers": 2, "max_soldiers": 2,
				"atk": 5.0, "def": 3.0, "spd": 3.0, "int_stat": 0.0,
				"passives": [], "active_skill": {},
				"skill_cooldown": 0, "has_charged": false,
				"actions_this_round": 0, "max_actions": 1,
				"is_alive": true, "player_id": unit["player_id"],
				"buffs": [], "debuffs": [],
				"overload_count": 0, "bloodlust_bonus": 0,
				"war_cry_used": false, "root_bind_used": false,
				"trade_hire_used": false, "blood_ritual_used": false,
				"immovable": false,
			}
			if unit["side"] == "attacker":
				skeleton["slot"] = state["atk_units"].size()
				state["atk_units"].append(skeleton)
			else:
				skeleton["slot"] = state["def_units"].size()
				state["def_units"].append(skeleton)
			log.append("%s [%s] 亡灵召唤! 召唤骷髅小队(2兵)" % [unit["unit_type"], unit["side"]])

		# Passive: forest_stealth — round 1 only: unit is invisible (can't be targeted)
		if "forest_stealth" in unit["passives"] and state["round"] == 1:
			var stealth_dur: int = 1
			var syn_specials: Dictionary = state.get("atk_synergy_specials", {}) if unit["side"] == "attacker" else state.get("def_synergy_specials", {})
			stealth_dur += syn_specials.get("stealth_extra_round", 0)
			unit["buffs"].append({"id": "stealth", "duration": stealth_dur, "value": 1})
			log.append("%s [%s] 林间潜行! 隐身%d回合" % [unit["unit_type"], unit["side"], stealth_dur])

		# Passive: leadership — all adjacent friendly units get ATK+2 (aura)
		if "leadership" in unit["passives"]:
			var allies: Array = state["atk_units"] if unit["side"] == "attacker" else state["def_units"]
			for ally in allies:
				if ally == unit or not ally["is_alive"]:
					continue
				# Adjacent = same row or neighboring slot
				if abs(ally["slot"] - unit["slot"]) <= 1:
					ally["buffs"].append({"id": "leadership_aura", "duration": 1, "value": 2})
					log.append("%s [%s] 统帅光环: %s ATK+2" % [unit["unit_type"], unit["side"], ally["unit_type"]])

		# Passive: war_cry — all friendly units ATK+2 for 3 rounds (activate once, round 1)
		if "war_cry" in unit["passives"] and state["round"] == 1 and not unit.get("war_cry_used", false):
			unit["war_cry_used"] = true
			var allies: Array = state["atk_units"] if unit["side"] == "attacker" else state["def_units"]
			for ally in allies:
				if ally["is_alive"]:
					ally["buffs"].append({"id": "war_cry", "duration": 3, "value": 2})
			log.append("%s [%s] 战吼! 全友军ATK+2(3回合)" % [unit["unit_type"], unit["side"]])

		# Passive: root_bind — stun 1 enemy for 2 rounds (activate round 1 or 2)
		if "root_bind" in unit["passives"] and state["round"] <= 2 and not unit.get("root_bind_used", false):
			unit["root_bind_used"] = true
			var enemies: Array = state["def_units"] if unit["side"] == "attacker" else state["atk_units"]
			var alive_enemies: Array = _get_all_alive(enemies)
			if not alive_enemies.is_empty():
				var stun_target: Dictionary = alive_enemies[randi() % alive_enemies.size()]
				stun_target["debuffs"].append({"id": "stun", "duration": 2, "value": 1})
				log.append("%s [%s] 根缚! %s 被定身2回合" % [unit["unit_type"], unit["side"], stun_target["unit_type"]])

		# Passive: blood_ritual — sacrifice 2 soldiers from self, heal all friendly units +2 soldiers each
		if "blood_ritual" in unit["passives"] and not unit.get("blood_ritual_used", false):
			if unit["soldiers"] > 2:
				unit["blood_ritual_used"] = true
				unit["soldiers"] -= 2
				var allies: Array = state["atk_units"] if unit["side"] == "attacker" else state["def_units"]
				for ally in allies:
					if ally["is_alive"] and ally != unit:
						var heal_amt: int = mini(2, ally["max_soldiers"] - ally["soldiers"])
						ally["soldiers"] += heal_amt
				log.append("%s [%s] 血祭! 牺牲2兵，治愈全军+2兵" % [unit["unit_type"], unit["side"]])

		# Passive: trade_hire — summon 1 random T2 mercenary unit mid-battle (once per battle)
		if "trade_hire" in unit["passives"] and not unit.get("trade_hire_used", false):
			unit["trade_hire_used"] = true
			var merc_types: Array = ["pirate_ashigaru", "human_ashigaru", "orc_ashigaru"]
			var merc_type: String = merc_types[randi() % merc_types.size()]
			var merc: Dictionary = {
				"slot": -1, "row": "front", "side": unit["side"],
				"hero_id": "", "unit_type": merc_type,
				"soldiers": 4, "max_soldiers": 4,
				"atk": 6.0, "def": 4.0, "spd": 5.0, "int_stat": 0.0,
				"passives": [], "active_skill": {},
				"skill_cooldown": 0, "has_charged": false,
				"actions_this_round": 0, "max_actions": 1,
				"is_alive": true, "player_id": unit["player_id"],
				"buffs": [], "debuffs": [],
				"overload_count": 0, "bloodlust_bonus": 0,
				"war_cry_used": false, "root_bind_used": false,
				"trade_hire_used": false, "blood_ritual_used": false,
				"immovable": false,
			}
			if unit["side"] == "attacker":
				merc["slot"] = state["atk_units"].size()
				state["atk_units"].append(merc)
			else:
				merc["slot"] = state["def_units"].size()
				state["def_units"].append(merc)
			log.append("%s [%s] 佣兵雇佣! 召唤 %s(4兵)" % [unit["unit_type"], unit["side"], merc_type])

		# Passive: charge_mana_1 — +1 mana
		if "charge_mana_1" in unit["passives"]:
			var mana_key: String = "atk_mana" if unit["side"] == "attacker" else "def_mana"
			var max_key: String = "atk_mana_max" if unit["side"] == "attacker" else "def_mana_max"
			state[mana_key] = mini(state[mana_key] + 1, state[max_key])

		# v4.6: mana_regen — +2 mana to team pool per round
		if "mana_regen" in unit["passives"]:
			var mr_mana_key: String = "atk_mana" if unit["side"] == "attacker" else "def_mana"
			var mr_max_key: String = "atk_mana_max" if unit["side"] == "attacker" else "def_mana_max"
			state[mr_mana_key] = mini(state[mr_mana_key] + 2, state[mr_max_key])

		# v4.6: regen_aura — heal 1 soldier to most damaged friendly unit per round
		if "regen_aura" in unit["passives"]:
			var ra_allies: Array = state["atk_units"] if unit["side"] == "attacker" else state["def_units"]
			var ra_lowest: Dictionary = {}
			var ra_lowest_pct: float = 2.0
			for ra_ally in ra_allies:
				if ra_ally["is_alive"] and ra_ally["soldiers"] < ra_ally["max_soldiers"]:
					var ra_pct: float = float(ra_ally["soldiers"]) / float(ra_ally["max_soldiers"])
					if ra_pct < ra_lowest_pct:
						ra_lowest_pct = ra_pct
						ra_lowest = ra_ally
			if not ra_lowest.is_empty():
				var ra_heal: int = mini(1, ra_lowest["max_soldiers"] - ra_lowest["soldiers"])
				ra_lowest["soldiers"] += ra_heal
				log.append("%s [%s] 再生光环: %s +%d兵" % [unit["unit_type"], unit["side"], ra_lowest["unit_type"], ra_heal])

		# Passive: scatter — if soldiers < 30% of max, unit retreats (survives but leaves battle)
		if "scatter" in unit["passives"]:
			if float(unit["soldiers"]) < float(unit["max_soldiers"]) * 0.3:
				unit["is_alive"] = false
				unit["soldiers"] = 0  # BUG FIX: zero soldiers so loss tracking is accurate
				log.append("%s [%s] 溃散撤退!" % [unit["unit_type"], unit["side"]])
				continue

		# Passive: reload_shot — on even rounds (2,4,6...), unit skips action (reloading)
		if "reload_shot" in unit["passives"]:
			if state["round"] % 2 == 0:
				unit["actions_this_round"] = unit["max_actions"]  # Skip action this round
				log.append("%s [%s] 装填中..." % [unit["unit_type"], unit["side"]])

		# BUG FIX: zero_food — undead units lose 1 soldier per combat round
		if "zero_food" in unit["passives"]:
			unit["soldiers"] -= 1
			if unit["soldiers"] <= 0:
				unit["soldiers"] = 0
				unit["is_alive"] = false
				log.append("%s [%s] 不死之军 兵力归零!" % [unit["unit_type"], unit["side"]])
				continue
			else:
				log.append("%s [%s] 不死之军 -1兵 (剩余%d)" % [unit["unit_type"], unit["side"], unit["soldiers"]])

		# BUG FIX: DoT debuff processing — apply poison_dot damage
		var dot_damage: int = 0
		for d in unit["debuffs"]:
			if d["id"] == "poison_dot" and d["duration"] > 0:
				dot_damage += 1
		if dot_damage > 0:
			unit["soldiers"] -= dot_damage
			log.append("%s [%s] 中毒! -%d兵" % [unit["unit_type"], unit["side"], dot_damage])
			if unit["soldiers"] <= 0:
				unit["soldiers"] = 0
				unit["is_alive"] = false
				log.append("%s [%s] 中毒身亡!" % [unit["unit_type"], unit["side"]])
				continue

		# Passive: yukino_heal_2 — heal +2 soldiers to lowest allied unit each round
		if "yukino_heal_2" in unit["passives"]:
			var allies: Array = state["atk_units"] if unit["side"] == "attacker" else state["def_units"]
			var lowest: Dictionary = {}
			var lowest_pct: float = 2.0
			for ally in allies:
				if ally["is_alive"] and ally["soldiers"] < ally["max_soldiers"]:
					var pct: float = float(ally["soldiers"]) / float(ally["max_soldiers"])
					if pct < lowest_pct:
						lowest_pct = pct
						lowest = ally
			if not lowest.is_empty():
				var heal_amt: int = mini(2, lowest["max_soldiers"] - lowest["soldiers"])
				lowest["soldiers"] += heal_amt
				log.append("%s [%s] 雪乃治愈: %s +%d兵" % [unit["unit_type"], unit["side"], lowest["unit_type"], heal_amt])

		# Passive: yukino_curse — curse all enemies -1 DEF per round
		if "yukino_curse" in unit["passives"]:
			var enemies: Array = state["def_units"] if unit["side"] == "attacker" else state["atk_units"]
			for enemy in enemies:
				if enemy["is_alive"]:
					enemy["def"] = maxf(enemy["def"] - 1.0, 0.0)
			log.append("%s [%s] 雪乃诅咒: 全敌军DEF-1" % [unit["unit_type"], unit["side"]])

		# Passive: gekka_drain — drain 1 soldier from random enemy unit per round
		if "gekka_drain" in unit["passives"]:
			var enemies: Array = state["def_units"] if unit["side"] == "attacker" else state["atk_units"]
			var alive_enemies: Array = _get_all_alive(enemies)
			if not alive_enemies.is_empty():
				var drain_target: Dictionary = alive_enemies[randi() % alive_enemies.size()]
				drain_target["soldiers"] -= 1
				log.append("%s [%s] 月華吸血: %s -1兵" % [unit["unit_type"], unit["side"], drain_target["unit_type"]])
				if drain_target["soldiers"] <= 0:
					drain_target["soldiers"] = 0
					drain_target["is_alive"] = false
					log.append("%s [%s] 被吸尽消灭!" % [drain_target["unit_type"], drain_target["side"]])

		# Passive: gekka_aoe_10 — 10% chance to deal 1 damage to all enemy units
		if "gekka_aoe_10" in unit["passives"]:
			if randf() < 0.10:
				var enemies: Array = state["def_units"] if unit["side"] == "attacker" else state["atk_units"]
				log.append("%s [%s] 月華共鸣! 全敌军受到1点伤害" % [unit["unit_type"], unit["side"]])
				for enemy in enemies:
					if enemy["is_alive"]:
						enemy["soldiers"] -= 1
						if enemy["soldiers"] <= 0:
							enemy["soldiers"] = 0
							enemy["is_alive"] = false
							log.append("  → %s [%s] 被共鸣消灭!" % [enemy["unit_type"], enemy["side"]])

		# Tick down skill cooldown
		if unit["skill_cooldown"] > 0:
			unit["skill_cooldown"] -= 1


func _build_action_queue(state: Dictionary) -> Array:
	var all_units: Array = []
	for unit in state["atk_units"] + state["def_units"]:
		if unit["is_alive"]:
			all_units.append(unit)

	# Separate preemptive units
	var preemptive: Array = []
	var normal: Array = []

	# Determine which sides have first-strike / preemptive directives this round
	var atk_dir: int = state.get("atk_directive", TacticalDirective.NONE)
	var def_dir: int = state.get("def_directive", TacticalDirective.NONE)
	var atk_first_strike: bool = (atk_dir == TacticalDirective.ALL_OUT)
	var atk_ambush_r1: bool = (atk_dir == TacticalDirective.AMBUSH and state["round"] == 1)
	var def_first_strike: bool = (def_dir == TacticalDirective.ALL_OUT)
	var def_ambush_r1: bool = (def_dir == TacticalDirective.AMBUSH and state["round"] == 1)

	for unit in all_units:
		var is_preemptive: bool = false
		if "preemptive" in unit["passives"] or "preemptive_1_3" in unit["passives"]:
			is_preemptive = true
		elif "reload_shot" in unit["passives"] and state["round"] == 1:
			is_preemptive = true  # reload_shot gets preemptive priority round 1
		# v4.5: preemptive_bonus / preemptive_shot — equipment passives grant preemptive
		elif "preemptive_bonus" in unit["passives"] or "preemptive_shot" in unit["passives"]:
			is_preemptive = true

		# ALL_OUT first strike: fastest unit on that side gets preemptive
		if not is_preemptive and unit["side"] == "attacker" and atk_first_strike:
			var fastest: Dictionary = _get_fastest_unit(state["atk_units"])
			if not fastest.is_empty() and fastest == unit:
				is_preemptive = true

		if not is_preemptive and unit["side"] == "defender" and def_first_strike:
			var fastest_d: Dictionary = _get_fastest_unit(state["def_units"])
			if not fastest_d.is_empty() and fastest_d == unit:
				is_preemptive = true

		# AMBUSH round 1: all units on that side get preemptive
		if not is_preemptive and unit["side"] == "attacker" and atk_ambush_r1:
			is_preemptive = true
		if not is_preemptive and unit["side"] == "defender" and def_ambush_r1:
			is_preemptive = true

		# Hakagure first strike: acts first in round regardless of SPD
		if not is_preemptive and "hakagure_first_strike" in unit["passives"]:
			is_preemptive = true

		# Charge command grants preemptive
		if not is_preemptive and unit.get("unit_command", UnitCommand.AUTO) == UnitCommand.CHARGE:
			is_preemptive = true

		if is_preemptive:
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
	var spd_a: float = a["spd"]
	var spd_b: float = b["spd"]
	# Apply slow debuffs dynamically (not stored in spd field)
	for d in a.get("debuffs", []):
		if d["id"] == "slow" and d["duration"] > 0:
			spd_a = maxf(spd_a - d["value"], 1.0)
	for d in b.get("debuffs", []):
		if d["id"] == "slow" and d["duration"] > 0:
			spd_b = maxf(spd_b - d["value"], 1.0)
	if spd_a != spd_b:
		return spd_a > spd_b
	# Use hash-based tiebreaker for fairness instead of alphabetic ordering
	return hash(a.get("unit_type", "") + str(a.get("slot", 0))) > hash(b.get("unit_type", "") + str(b.get("slot", 0)))


# ---------------------------------------------------------------------------
# Action Execution
# ---------------------------------------------------------------------------

func _execute_action(state: Dictionary, unit: Dictionary, log: Array) -> void:
	if not unit["is_alive"] or unit["soldiers"] <= 0:
		return
	if unit["actions_this_round"] >= unit["max_actions"]:
		return

	# Guard command: skip attack action (unit only defends this round)
	if unit.get("unit_command", UnitCommand.AUTO) == UnitCommand.GUARD:
		unit["actions_this_round"] += 1
		return

	# Check stun debuff: stunned units cannot act
	for d in unit["debuffs"]:
		if d["id"] == "stun" and d["duration"] > 0:
			log.append("%s [%s] 被定身，无法行动" % [unit["unit_type"], unit["side"]])
			unit["actions_this_round"] += 1
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

	# Passive: aoe_immobile — free AoE attack at 0.5x damage (no mana cost)
	if "aoe_immobile" in unit["passives"]:
		_execute_aoe_attack_half(state, unit, log)
		return

	# Check hero active skill (if ready and has mana) — with skill timing orders
	if unit["hero_id"] != "" and unit["skill_cooldown"] <= 0:
		var skill: Dictionary = unit["active_skill"]
		if not skill.is_empty():
			var timing_key: String = "atk_skill_timing" if unit["side"] == "attacker" else "def_skill_timing"
			var timing: Dictionary = state.get(timing_key, {})
			var scheduled_round: int = timing.get(unit["hero_id"], 0)  # 0 = auto
			var should_fire: bool = false
			if scheduled_round <= 0:
				should_fire = true  # Auto: original behavior
			elif state["round"] == scheduled_round:
				should_fire = true  # Scheduled round
			if should_fire:
				var used: bool = _execute_active_skill(state, unit, skill, log)
				if used:
					return

	# Normal single-target attack
	var target: Dictionary = _select_target(state, unit)
	if target.is_empty():
		return

	var damage: int = _calculate_damage(unit, target, state)

	# Log unit counter advantage/disadvantage
	var _action_counter: Dictionary = CounterMatrix.get_counter(unit["unit_type"], target["unit_type"])
	if _action_counter["advantage"] != "neutral":
		log.append("  克制: %s (%s, 伤害x%.0f%%)" % [_action_counter["label"], _action_counter["advantage"], _action_counter["atk_mult"] * 100])

	# Charge bonus: first attack ×1.5
	if "charge_1_5" in unit["passives"] and not unit["has_charged"]:
		damage = int(float(damage) * 1.5)
		unit["has_charged"] = true
		log.append("%s [%s] 冲锋! 伤害×1.5" % [unit["unit_type"], unit["side"]])

	# Passive: charge_stun — first attack ×1.5 + 30% chance to stun for 1 round
	elif "charge_stun" in unit["passives"] and not unit["has_charged"]:
		damage = int(float(damage) * 1.5)
		unit["has_charged"] = true
		log.append("%s [%s] 冲锋! 伤害×1.5" % [unit["unit_type"], unit["side"]])
		if randf() < 0.3:
			target["debuffs"].append({"id": "stun", "duration": 1, "value": 1})
			log.append("%s [%s] 被冲锋眩晕1回合!" % [target["unit_type"], target["side"]])

	# Preemptive ×1.3 multiplier (round 1 only for preemptive_1_3)
	if "preemptive_1_3" in unit["passives"] and state["round"] == 1:
		damage = int(float(damage) * 1.3)

	# Passive: assassin_crit — 30% chance for ×2 damage
	if "assassin_crit" in unit["passives"]:
		# Hakagure reforge: 20% chance to nullify enemy crit
		var crit_nullified: bool = false
		if "hakagure_nullify_crit" in target["passives"]:
			if randf() < 0.20:
				crit_nullified = true
				log.append("%s [%s] 葉隠鍛直: 暴击被无效化!" % [target["unit_type"], target["side"]])
		if not crit_nullified and randf() < 0.3:
			damage = int(float(damage) * 2.0)
			log.append("%s [%s] 暴击! 伤害×2" % [unit["unit_type"], unit["side"]])

	# Barrier absorption (defender side, first use per round)
	if state.get("barrier_active", false) and not state.get("barrier_used_this_round", false):
		if unit["side"] == "attacker":  # Attacker hitting defender
			var absorbed: float = LightFactionAI.apply_barrier_absorption(
				state.get("barrier_tile_index", -1), float(damage))
			damage = int(absorbed)
			state["barrier_used_this_round"] = true
			log.append("精灵屏障吸收! 伤害降至 %d" % damage)

	# Store target soldiers before damage for kill detection
	var target_soldiers_before: int = target["soldiers"]

	# Apply damage
	_apply_damage_to_unit(state, target, damage, unit, log)

	# Hakagure unleash: 25% instant kill on units with ≤2 soldiers
	if "hakagure_instant_kill" in unit["passives"] and target["is_alive"] and target["soldiers"] <= 2:
		if randf() < 0.25:
			target["soldiers"] = 0
			target["is_alive"] = false
			log.append("%s [%s] 葉隠解放! %s 即死!" % [unit["unit_type"], unit["side"], target["unit_type"]])

	# Passive: bloodlust — on kill, gain ATK+1 permanently for this battle
	if "bloodlust" in unit["passives"] and target_soldiers_before > 0 and not target["is_alive"]:
		unit["bloodlust_bonus"] = unit.get("bloodlust_bonus", 0) + 1
		log.append("%s [%s] 嗜血! 击杀后ATK+1(累积:%d)" % [unit["unit_type"], unit["side"], unit["bloodlust_bonus"]])

	# v4.5: dragon_slayer — on kill, gain ATK+1 permanently for this battle (like bloodlust)
	if "dragon_slayer" in unit["passives"] and target_soldiers_before > 0 and not target["is_alive"]:
		unit["bloodlust_bonus"] = unit.get("bloodlust_bonus", 0) + 1
		log.append("%s [%s] 龙杀! 击杀后ATK+1(累积:%d)" % [unit["unit_type"], unit["side"], unit["bloodlust_bonus"]])

	# Passive: mana_drain — on hit, drain 2 mana from enemy side
	if "mana_drain" in unit["passives"] and damage > 0:
		var enemy_mana_key: String = "def_mana" if unit["side"] == "attacker" else "atk_mana"
		var drained: int = mini(2, state[enemy_mana_key])
		state[enemy_mana_key] -= drained
		if drained > 0:
			log.append("%s [%s] 法力吸取! 吸取%d法力" % [unit["unit_type"], unit["side"], drained])

	# Passive: poison_slow — on hit, apply DoT (1 dmg/round for 2 rounds) + SPD-2 for 2 rounds
	if "poison_slow" in unit["passives"] and damage > 0 and target["is_alive"]:
		target["debuffs"].append({"id": "poison_dot", "duration": 2, "value": 1})
		target["debuffs"].append({"id": "slow", "duration": 2, "value": 2.0})
		# SPD penalty applied dynamically via debuff in action queue, not direct mod
		log.append("%s [%s] 寒霜毒液! %s 中毒+减速2回合" % [unit["unit_type"], unit["side"], target["unit_type"]])

	# v4.6: poison_attack — on hit, apply poison DOT (2 rounds, 1 damage/round)
	if "poison_attack" in unit["passives"] and damage > 0 and target["is_alive"]:
		target["debuffs"].append({"id": "poison_dot", "duration": 2, "value": 1})
		log.append("%s [%s] 毒击! %s 中毒2回合" % [unit["unit_type"], unit["side"], target["unit_type"]])

	# Passive: gold_on_hit — on hit, player gains 2 gold
	if "gold_on_hit" in unit["passives"] and damage > 0:
		if unit["player_id"] >= 0:
			var gold_hit_amount: int = 2
			# Synergy special: gold_income_bonus multiplier
			var syn_sp: Dictionary = state.get("atk_synergy_specials", {}) if unit["side"] == "attacker" else state.get("def_synergy_specials", {})
			var gold_bonus: float = syn_sp.get("gold_income_bonus", 0.0)
			if gold_bonus > 0.0:
				gold_hit_amount = int(float(gold_hit_amount) * (1.0 + gold_bonus))
			ResourceManager.apply_delta(unit["player_id"], {"gold": gold_hit_amount})
			log.append("%s [%s] 生财有道! +%d金" % [unit["unit_type"], unit["side"], gold_hit_amount])

	# Passive: overload — track usage count; after 3 attacks, self-destruct dealing ATK×2 AoE
	if "overload" in unit["passives"]:
		unit["overload_count"] = unit.get("overload_count", 0) + 1
		if unit["overload_count"] >= 3:
			var burst_dmg: int = int(unit["atk"] * 2.0)
			var burst_enemies: Array = state["def_units"] if unit["side"] == "attacker" else state["atk_units"]
			log.append("%s [%s] 过载自爆! 对敌全体造成%d伤害!" % [unit["unit_type"], unit["side"], burst_dmg])
			for enemy in burst_enemies:
				if enemy["is_alive"]:
					enemy["soldiers"] -= burst_dmg
					if enemy["soldiers"] <= 0:
						enemy["soldiers"] = 0
						enemy["is_alive"] = false
						log.append("  → %s [%s] 被过载爆发消灭!" % [enemy["unit_type"], enemy["side"]])
			# Self-destruct
			unit["soldiers"] = 0
			unit["is_alive"] = false
			log.append("%s [%s] 过载自毁!" % [unit["unit_type"], unit["side"]])

	# Counter-attack: counter_1_2 or counter_defend passive
	if target["is_alive"] and ("counter_1_2" in target["passives"] or "counter_defend" in target["passives"]):
		var counter_dmg: int = _calculate_damage(target, unit, state)
		# v4.5: counter_damage_bonus (homura_flame_gauntlet) — boost counter from x1.2 to x1.5
		var counter_mult: float = 1.5 if "counter_damage_bonus" in target["passives"] else 1.2
		counter_dmg = int(float(counter_dmg) * counter_mult)
		# Counter matrix defense modifier: original attacker may take less/more counter damage
		var _ca_counter: Dictionary = CounterMatrix.get_counter(unit["unit_type"], target["unit_type"])
		if _ca_counter["def_mult"] != 1.0:
			counter_dmg = int(float(counter_dmg) * _ca_counter["def_mult"])
		log.append("%s [%s] 反击! 伤害 %d" % [target["unit_type"], target["side"], counter_dmg])
		_apply_damage_to_unit(state, unit, counter_dmg, target, log)

	# Passive: double_forest — in forest terrain, attack a second random target
	if "double_forest" in unit["passives"] and unit["is_alive"]:
		var terrain_type: int = state.get("terrain", FactionData.TerrainType.PLAINS)
		if terrain_type == FactionData.TerrainType.FOREST:
			var second_target: Dictionary = _select_target(state, unit)
			if not second_target.is_empty():
				var second_dmg: int = _calculate_damage(unit, second_target, state)
				log.append("%s [%s] 森林双击! 追加攻击 %s" % [unit["unit_type"], unit["side"], second_target["unit_type"]])
				_apply_damage_to_unit(state, second_target, second_dmg, unit, log)


func _execute_heal(state: Dictionary, healer: Dictionary, log: Array) -> void:
	# Find friendliest unit with lowest soldiers ratio
	var allies: Array = state["atk_units"] if healer["side"] == "attacker" else state["def_units"]
	var best_target: Dictionary = {}
	var best_ratio: float = 1.0
	for ally in allies:
		if not ally["is_alive"] or ally == healer:
			continue
		var ratio: float = float(ally["soldiers"]) / float(maxi(ally["max_soldiers"], 1))  # BUG FIX: prevent division by zero
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
	# v4.6: heal_bonus — +30% healing from equipment passive
	if "heal_bonus" in healer["passives"]:
		heal_amount = int(float(heal_amount) * 1.3)
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
		# FIX(CRITICAL): damage为0表示miss，跳过AoE处理，避免miss变为1点伤害
		if damage == 0:
			continue
		damage = int(float(damage) * mult)
		# AoE reduces per-target damage slightly
		damage = maxi(1, int(float(damage) * 0.6))
		_apply_damage_to_unit(state, enemy, damage, unit, log)
		hit_count += 1

	log.append("%s [%s] AoE攻击! 命中 %d 个目标 (×%.1f)" % [
		unit["unit_type"], unit["side"], hit_count, mult])


## AoE attack at half damage (aoe_immobile passive, no mana cost)
func _execute_aoe_attack_half(state: Dictionary, unit: Dictionary, log: Array) -> void:
	var enemies: Array = state["def_units"] if unit["side"] == "attacker" else state["atk_units"]
	var hit_count: int = 0
	for enemy in enemies:
		if not enemy["is_alive"]:
			continue
		var damage: int = _calculate_damage(unit, enemy, state)
		if damage == 0:
			continue
		# BUG FIX: only apply 0.5x reduction (was double-applying 0.5 * 0.6 = 0.3x)
		damage = maxi(1, int(float(damage) * 0.5))
		_apply_damage_to_unit(state, enemy, damage, unit, log)
		hit_count += 1
	log.append("%s [%s] AoE攻击(固定)! 命中 %d 个目标 (×0.5)" % [
		unit["unit_type"], unit["side"], hit_count])


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
				# v4.6: heal_bonus — +30% healing
				if "heal_bonus" in unit["passives"]:
					heal = int(float(heal) * 1.3)
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

		"时间减速":  # 敌全体SPD-3, 2回合 (debuff-based, no direct stat mod)
			for enemy in enemies:
				if enemy["is_alive"]:
					enemy["debuffs"].append({"id": "slow", "duration": 2, "value": 3.0})
			log.append("【%s】时间减速! 敌方SPD-3" % unit["hero_id"])

		"突击号令":  # 己方全体骑兵ATK+2, 1回合
			for ally in allies:
				if ally["is_alive"] and _get_troop_base_type(ally["unit_type"]) == "cavalry":
					# FIX(MAJOR): 移除直接修改atk的代码，ATK加成由buff系统通过charge_cmd处理
					# 原代码 ally["atk"] += 2 会永久叠加，buff过期后ATK不会恢复
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

		"铁壁":  # DEF+3, 1回合 (buff-based, no direct stat mod)
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
				"overload_count": 0, "bloodlust_bonus": 0,
				"war_cry_used": false, "root_bind_used": false,
				"trade_hire_used": false, "blood_ritual_used": false,
				"immovable": false,
			}
			if unit["side"] == "attacker":
				summon["slot"] = state["atk_units"].size()
				state["atk_units"].append(summon)
			else:
				summon["slot"] = state["def_units"].size()
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

	# Commander Intervention: forced target override
	var forced: int = state.get("forced_target", -1)
	if forced >= 0 and state.get("forced_target_duration", 0) > 0:
		var enemies_list: Array = state["def_units"] if unit["side"] == "attacker" else state["atk_units"]
		if forced < enemies_list.size() and enemies_list[forced]["is_alive"]:
			return enemies_list[forced]
	# Commander Intervention: bait target override (for enemy targeting)
	var bait: int = state.get("bait_target", -1)
	if bait >= 0 and state.get("bait_duration", 0) > 0 and unit["side"] == "defender":
		var atk_units_list: Array = state["atk_units"]
		if bait < atk_units_list.size() and atk_units_list[bait]["is_alive"]:
			return atk_units_list[bait]

	# ── Commander Tactical Orders: FOCUS_FIRE ──
	# If the ATTACKING unit's side has FOCUS_FIRE, target the enemy with lowest soldiers
	var unit_side_dir: int = state.get("atk_directive", TacticalDirective.NONE) if unit["side"] == "attacker" else state.get("def_directive", TacticalDirective.NONE)
	if unit_side_dir == TacticalDirective.FOCUS_FIRE:
		# Still respect stealth/taunt
		var focus_targetable: Array = []
		for enemy in alive_enemies:
			var is_stealthed: bool = false
			for b in enemy["buffs"]:
				if b["id"] == "stealth" and b["duration"] > 0:
					is_stealthed = true
					break
			if is_stealthed:
				continue
			focus_targetable.append(enemy)
		if focus_targetable.is_empty():
			focus_targetable = alive_enemies
		focus_targetable.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["soldiers"] < b["soldiers"])
		return focus_targetable[0]

	# ── Commander Tactical Orders: GUERRILLA back-row protection ──
	# If the ENEMY side has GUERRILLA, their back row cannot be targeted while front row lives
	var enemy_side_dir: int = state.get("def_directive", TacticalDirective.NONE) if unit["side"] == "attacker" else state.get("atk_directive", TacticalDirective.NONE)
	if enemy_side_dir == TacticalDirective.GUERRILLA:
		var enemy_front_alive: Array = _get_alive_in_row(enemies, "front")
		if not enemy_front_alive.is_empty():
			# Remove back row from alive_enemies
			var front_only: Array = []
			for enemy in alive_enemies:
				if enemy["row"] == "front":
					front_only.append(enemy)
			if not front_only.is_empty():
				alive_enemies = front_only

	# 1. Taunt check: must target taunter (unless unit has assassin_crit)
	if "assassin_crit" not in unit["passives"]:
		for enemy in alive_enemies:
			if "taunt" in enemy["passives"]:
				return enemy

	# 2. Stealth check: round 1, units with 隐匿 can't be targeted; also check stealth buff
	var targetable: Array = []
	for enemy in alive_enemies:
		if state["round"] == 1 and "隐匿" in enemy["passives"]:
			continue
		# forest_stealth stealth buff: unit cannot be targeted
		var is_stealthed: bool = false
		for b in enemy["buffs"]:
			if b["id"] == "stealth" and b["duration"] > 0:
				is_stealthed = true
				break
		if is_stealthed:
			continue
		# dodge_next is consumed when damage is applied (_apply_damage_to_unit),
		# not during target selection — units with dodge_next remain targetable.
		targetable.append(enemy)

	if targetable.is_empty():
		targetable = alive_enemies  # Fallback: target anyone

	# 3. Targeting based on troop type
	var troop_base: String = _get_troop_base_type(unit["unit_type"])
	var target_mode: int = TROOP_TARGET_MODE.get(troop_base, TargetMode.FRONT_ONLY)

	# Assassinate_back passive overrides to back priority
	if "assassinate_back" in unit["passives"]:
		target_mode = TargetMode.BACK_PRIORITY
	# v4.5: assassinate_bonus (de_shadow_fang) — +25% chance to target back row
	elif "assassinate_bonus" in unit["passives"]:
		if randf() < 0.25:
			target_mode = TargetMode.BACK_PRIORITY

	# Assassin_crit: ignore taunt, can target back row directly
	if "assassin_crit" in unit["passives"]:
		target_mode = TargetMode.BACK_PRIORITY

	# Pistol_shot: front row unit can attack back row
	if "pistol_shot" in unit["passives"] and unit["row"] == "front":
		target_mode = TargetMode.ANY

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

	# FIX(CRITICAL): 候选数组为空时返回空字典，调用方可安全使用 target.is_empty() 判定
	if candidates.is_empty():
		return {}

	# ── Commander Tactical Orders: Protected / Decoy slot weighting ──
	var enemy_side_key: String = "def" if unit["side"] == "attacker" else "atk"
	var protected_slot: int = state.get(enemy_side_key + "_protected_slot", -1)
	var decoy_slot: int = state.get(enemy_side_key + "_decoy_slot", -1)

	if protected_slot >= 0 or decoy_slot >= 0:
		# Use weighted random selection instead of pure lowest-soldiers
		var weights: Array = []
		var total_weight: float = 0.0
		for c in candidates:
			var w: float = 1.0
			if c["slot"] == protected_slot:
				w *= 0.5  # 50% reduced targeting weight
			if c["slot"] == decoy_slot:
				w *= 2.0  # +100% targeting weight
			weights.append(w)
			total_weight += w

		# Weighted random pick
		var roll: float = randf() * total_weight
		var cumulative: float = 0.0
		for i in range(candidates.size()):
			cumulative += weights[i]
			if roll <= cumulative:
				return candidates[i]
		return candidates[candidates.size() - 1]

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

	# FIX(MAJOR): charge_cmd buff加成ATK（配合突击号令修复，不再直接修改atk字段）
	for b in attacker_unit["buffs"]:
		if b["id"] == "charge_cmd":
			atk += b["value"]
		# war_cry buff: ATK+value
		if b["id"] == "war_cry":
			atk += b["value"]
		# leadership_aura buff: ATK+value
		if b["id"] == "leadership_aura":
			atk += b["value"]
		# Ambush round 1 buff: ATK × (1 + value)
		if b["id"] == "ambush_r1" and b["duration"] > 0:
			atk *= (1.0 + b["value"])
		# Ambush after round 1 debuff: ATK × (1 + value) where value is negative
		if b["id"] == "ambush_after" and b["duration"] > 0:
			atk *= (1.0 + b["value"])

	# Iron Wall buff: DEF bonus from defender's buff list
	for b in defender_unit["buffs"]:
		if b["id"] == "iron_wall":
			def_val += b["value"]

	# Passive: bloodlust — accumulated ATK bonus from kills
	atk += float(attacker_unit.get("bloodlust_bonus", 0))

	# Passive: low_hp_double — when unit is <50% soldiers, ATK is doubled
	if "low_hp_double" in attacker_unit["passives"]:
		if float(attacker_unit["soldiers"]) < float(attacker_unit["max_soldiers"]) * 0.5:
			atk *= 2.0

	# Passive: berserker_rage — when <50% soldiers, ATK×2 and DEF becomes 0
	# BUG FIX: use elif to prevent stacking with low_hp_double (was 4x ATK)
	elif "berserker_rage" in attacker_unit["passives"]:
		if float(attacker_unit["soldiers"]) < float(attacker_unit["max_soldiers"]) * 0.5:
			atk *= 2.0

	# Passive: berserker_rage (defender) — when <50% soldiers, DEF becomes 0
	if "berserker_rage" in defender_unit["passives"]:
		if float(defender_unit["soldiers"]) < float(defender_unit["max_soldiers"]) * 0.5:
			def_val = 0.0

	# Passive: blood_triple — when unit is <30% soldiers, ATK is tripled
	# BUG FIX: use elif to prevent stacking with berserker_rage (was 6x ATK)
	if "blood_triple" in attacker_unit["passives"] and not ("berserker_rage" in attacker_unit["passives"] or "low_hp_double" in attacker_unit["passives"]):
		if float(attacker_unit["soldiers"]) < float(attacker_unit["max_soldiers"]) * 0.3:
			atk *= 3.0

	# Passive: desperate — when surrounded (only unit alive on its side), ATK+2
	if "desperate" in attacker_unit["passives"]:
		var own_units: Array = state["atk_units"] if attacker_unit["side"] == "attacker" else state["def_units"]
		var alive_count: int = 0
		for u in own_units:
			if u["is_alive"]:
				alive_count += 1
		if alive_count <= 1:
			atk += 2.0

	# Passive: waaagh_triple — if WAAAGH >= 80, ATK×3
	if "waaagh_triple" in attacker_unit["passives"]:
		var _waaagh_pid: int = attacker_unit.get("player_id", -1)
		if _waaagh_pid >= 0 and OrcMechanic.get_waaagh(_waaagh_pid) >= 80:
			atk *= 3.0

	# Passive: horde_bonus — if 3+ orc units on same side, ATK+2
	if "horde_bonus" in attacker_unit["passives"]:
		var own_units: Array = state["atk_units"] if attacker_unit["side"] == "attacker" else state["def_units"]
		var orc_count: int = 0
		for u in own_units:
			if u["is_alive"] and u["unit_type"].begins_with("orc_"):
				orc_count += 1
		if orc_count >= 3:
			atk += 2.0

	# Passive: guerrilla — in forest/swamp terrain, ATK+2 DEF+1
	if "guerrilla" in attacker_unit["passives"]:
		var terrain_type: int = state.get("terrain", FactionData.TerrainType.PLAINS)
		if terrain_type == FactionData.TerrainType.FOREST or terrain_type == FactionData.TerrainType.SWAMP:
			atk += 2.0
			# DEF bonus applied to defender side handled separately below

	# Passive: guerrilla — DEF bonus when being attacked in forest/swamp
	if "guerrilla" in defender_unit["passives"]:
		var terrain_type: int = state.get("terrain", FactionData.TerrainType.PLAINS)
		if terrain_type == FactionData.TerrainType.FOREST or terrain_type == FactionData.TerrainType.SWAMP:
			def_val += 1.0

	# Apply debuffs to attacker/defender
	for d in defender_unit["debuffs"]:
		if d["id"] == "sandstorm":
			# 30% miss chance per sandstorm stack
			if randf() < d["value"]:
				return 0  # Miss!

	# FIX(GAME-BREAKING): 兽人阵营被动"蛮力碾压"——无视敌方30%DEF
	var attacker_pid: int = attacker_unit.get("player_id", -1)
	var is_orc_faction: bool = attacker_unit["unit_type"].begins_with("orc_")
	if not is_orc_faction and attacker_pid >= 0:
		is_orc_faction = GameManager._get_faction_tag_for_player(attacker_pid) == "orc"
	if is_orc_faction:
		def_val *= (1.0 - GameData.FACTION_PASSIVES["orc"]["def_ignore_pct"])

	# Per-unit command modifiers
	var attacker_cmd: int = attacker_unit.get("unit_command", UnitCommand.AUTO)
	if attacker_cmd != UnitCommand.AUTO:
		var cmd_data: Dictionary = UNIT_COMMAND_DATA.get(attacker_cmd, {})
		atk *= cmd_data.get("atk_mult", 1.0)
	var target_cmd: int = defender_unit.get("unit_command", UnitCommand.AUTO)
	if target_cmd != UnitCommand.AUTO:
		var target_cmd_data: Dictionary = UNIT_COMMAND_DATA.get(target_cmd, {})
		def_val *= target_cmd_data.get("def_mult", 1.0)

	# Core formula from design doc
	var base_damage: float = float(soldiers) * maxf(1.0, atk - def_val) / 10.0

	# Apply unit counter matrix (atk_mult: attacker deals more/less damage)
	var _counter_info: Dictionary = CounterMatrix.get_counter(attacker_unit["unit_type"], defender_unit["unit_type"])
	if _counter_info["atk_mult"] != 1.0:
		base_damage *= _counter_info["atk_mult"]

	# v4.5: light_slayer (rin_sacred_blade) — +15% damage vs light faction units
	if "light_slayer" in attacker_unit["passives"]:
		var def_type: String = defender_unit["unit_type"].to_lower()
		if def_type.begins_with("elf_") or def_type.begins_with("knight_") or def_type.begins_with("human_") or def_type.begins_with("temple_") or def_type.begins_with("priest") or def_type.begins_with("treant") or def_type.begins_with("alliance_"):
			base_damage *= 1.15

	# v4.5: blood_oath — when unit is <50% soldiers, ATK×2 (stacks with other ATK mults)
	if "blood_oath" in attacker_unit["passives"]:
		if float(attacker_unit["soldiers"]) < float(attacker_unit["max_soldiers"]) * 0.5:
			base_damage *= 2.0

	# v4.5: spell_damage_bonus / spell_power_bonus — handled in hero_system.gd apply_skill_in_combat

	# v4.6: desert_mastery — ATK doubled on WASTELAND terrain
	if "desert_mastery" in attacker_unit["passives"]:
		var _dm_terrain: int = state.get("terrain", FactionData.TerrainType.PLAINS)
		if _dm_terrain == FactionData.TerrainType.WASTELAND:
			base_damage *= 2.0

	# Apply weather/season combat modifiers
	if Engine.get_main_loop() is SceneTree:
		var _wr: Node = (Engine.get_main_loop() as SceneTree).root
		if _wr.has_node("WeatherSystem"):
			var _ws: Node = _wr.get_node("WeatherSystem")
			var _wm: Dictionary = _ws.get_combat_modifiers()
			var _weather_atk_mod: float = float(_wm.get("atk_mod", 0))
			# Check if attacker is ranged
			var _is_ranged: bool = attacker_unit["unit_type"].find("archer") != -1 or attacker_unit["unit_type"].find("cannon") != -1 or attacker_unit["unit_type"].find("mage") != -1 or attacker_unit["unit_type"].find("gunner") != -1
			if _is_ranged:
				_weather_atk_mod += float(_wm.get("ranged_atk_mod", 0))
			var _is_cav: bool = attacker_unit["unit_type"].find("cavalry") != -1 or attacker_unit["unit_type"].find("rider") != -1
			if _is_cav:
				_weather_atk_mod += float(_wm.get("cavalry_atk_mod", 0))
			if _weather_atk_mod != 0:
				base_damage = maxf(base_damage + _weather_atk_mod, 0.0)

	# Terrain-based damage modifiers (not captured by passives)
	var _terrain_type: int = state.get("terrain", FactionData.TerrainType.PLAINS)
	var _atk_base_type: String = CounterMatrix.TYPE_MAP.get(attacker_unit["unit_type"], "infantry")
	var _def_base_type: String = CounterMatrix.TYPE_MAP.get(defender_unit["unit_type"], "infantry")
	# Cavalry penalized in rough terrain (forest/swamp): effective ATK-2 applied to damage
	if _atk_base_type == "cavalry" and (_terrain_type == FactionData.TerrainType.FOREST or _terrain_type == FactionData.TerrainType.SWAMP):
		base_damage = maxf(base_damage - 2.0, 0.0)
	# Archer high ground advantage on mountain: effective ATK+1 applied to damage
	if _atk_base_type == "archer" and _terrain_type == FactionData.TerrainType.MOUNTAIN:
		base_damage += 1.0
	# Fortress bonus for defender on owned tile: effective DEF+3 baked into damage reduction
	if _terrain_type == FactionData.TerrainType.FORTRESS_WALL:
		var _tile: Dictionary = state.get("tile", {})
		var _tile_faction: int = _tile.get("light_faction", _tile.get("original_faction", -1))
		var _def_pid: int = defender_unit.get("player_id", state.get("def_pid", -1))
		# Defender is on their own fortress tile
		if _tile_faction >= 0 and _def_pid >= 0 and _tile_faction == _def_pid:
			# DEF+3 equivalent: reduce damage by soldiers * 3 / 10 (matching core formula scale)
			base_damage = maxf(base_damage - float(soldiers) * 3.0 / 10.0, 0.0)

	# Flanking bonus: if attacker's side has no front row alive, back row attacks get +15% damage
	var _own_units: Array = state["atk_units"] if attacker_unit["side"] == "attacker" else state["def_units"]
	if attacker_unit["row"] == "back" and _count_alive_in_row(_own_units, "front") == 0:
		base_damage *= 1.15

	# FIX(MAJOR): 护盾buff改为取最强护盾生效，不再乘法叠加；使用后标记移除
	var best_shield_idx: int = -1
	var best_shield_val: float = 0.0
	for idx in range(defender_unit["buffs"].size()):
		var b: Dictionary = defender_unit["buffs"][idx]
		if b["id"] == "shield" and b["value"] > best_shield_val:
			best_shield_val = b["value"]
			best_shield_idx = idx
		if b["id"] == "invulnerable":
			return 0  # Immune
	if best_shield_idx >= 0:
		base_damage *= (1.0 - best_shield_val)
		base_damage = maxf(0.0, base_damage)
		# 护盾使用后消耗，标记duration为0使其在回合结束时移除
		defender_unit["buffs"][best_shield_idx]["duration"] = 0

	# FIX(MAJOR): 基础伤害最低为0；仅在实际命中时保证至少1点伤害
	var soldiers_killed: int = maxi(0, int(base_damage))
	if base_damage > 0.0 and soldiers_killed == 0:
		soldiers_killed = 1

	# Passive: shadow_flight — 30% chance to double final damage
	if "shadow_flight" in attacker_unit["passives"]:
		if randf() < 0.3:
			soldiers_killed *= 2

	return soldiers_killed


# ---------------------------------------------------------------------------
# Damage Application
# ---------------------------------------------------------------------------

func _apply_damage_to_unit(state: Dictionary, target: Dictionary, damage: int, source: Dictionary, log: Array, _death_burst_recursion: bool = false) -> void:
	if damage <= 0:
		return

	# v4.6: damage_reduce — reduce incoming damage by 20%
	if "damage_reduce" in target["passives"]:
		damage = maxi(1, int(float(damage) * 0.80))

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

	# Earth shield (gekka_harmony): first hit this battle deals 0 damage to target
	if "earth_shield" in target["passives"]:
		target["passives"].erase("earth_shield")  # one-time use
		log.append("%s [%s] 大地之盾! 伤害被完全吸收!" % [target["unit_type"], target["side"]])
		return

	# v4.5: ghost_shield — first hit immunity (absorb full damage once)
	if "ghost_shield" in target["passives"]:
		target["passives"].erase("ghost_shield")  # one-time use
		log.append("%s [%s] 幽灵护盾吸收了首次攻击!" % [target["unit_type"], target["side"]])
		return

	# v4.5: ranged_dodge (pirate_ghost_ship_coat) — 30% dodge vs ranged attacks
	if "ranged_dodge" in target["passives"]:
		var src_type: String = source["unit_type"].to_lower()
		var _is_src_ranged: bool = src_type.find("archer") != -1 or src_type.find("ranger") != -1 or src_type.find("mage") != -1 or src_type.find("cannon") != -1 or src_type.find("bombardier") != -1 or src_type.find("gunner") != -1
		if _is_src_ranged and randf() < 0.30:
			log.append("%s [%s] 闪避了远程攻击!" % [target["unit_type"], target["side"]])
			return

	# Escape_30: 30% chance to survive lethal damage (soldiers would drop to 0)
	if target["soldiers"] - damage <= 0 and "escape_30" in target["passives"]:
		if randf() < 0.3:
			target["soldiers"] = 1
			log.append("%s [%s] 逃脱致命一击! 残存1兵" % [target["unit_type"], target["side"]])
			return

	# v4.5: death_resist (orc_iron_jaw_plate) — 100% survive lethal with 1 soldier, once per battle
	if target["soldiers"] - damage <= 0 and "death_resist" in target["passives"] and not target.get("_death_resist_used", false):
		target["_death_resist_used"] = true
		target["soldiers"] = 1
		log.append("%s [%s] 铁颚板甲: 抵抗致命伤害，保留1兵!" % [target["unit_type"], target["side"]])
		return

	target["soldiers"] -= damage
	log.append("%s [%s] 受到 %d 伤害 (剩余 %d 兵)" % [
		target["unit_type"], target["side"], damage, maxi(target["soldiers"], 0)])

	# Morale: reduce for damage taken
	if "morale_immune" not in target["passives"] and not target.get("immovable", false) and not target.get("is_routed", false):
		var soldiers_lost: int = mini(damage, target["soldiers"] + damage)  # actual soldiers killed
		var morale_loss: int = soldiers_lost * MORALE_PER_SOLDIER_KILLED
		# Fodder morale resist: fodder units take reduced morale damage when routed (thematic)
		var _target_base_type: String = CounterMatrix.TYPE_MAP.get(target["unit_type"], "infantry")
		if _target_base_type == "fodder":
			var _fodder_data: Dictionary = CounterMatrix.COUNTER_TABLE.get("fodder", {}).get("_default", {})
			var _morale_resist: float = _fodder_data.get("morale_resist", 0.0)
			if _morale_resist > 0.0:
				morale_loss = int(float(morale_loss) * (1.0 - _morale_resist))
		target["morale"] = maxi(target.get("morale", MORALE_START) - morale_loss, 0)
		EventBus.unit_morale_changed.emit(target["unit_type"], target["side"], target["morale"])

	# Pirate faction passive: gold_per_kill — +1 gold per soldier killed
	var source_pid: int = source.get("player_id", -1)
	if source_pid >= 0 and damage > 0:
		var _is_pirate: bool = source["unit_type"].begins_with("pirate_")
		if not _is_pirate:
			_is_pirate = GameManager._get_faction_tag_for_player(source_pid) == "pirate"
		if _is_pirate:
			var gold_per_kill: int = GameData.FACTION_PASSIVES.get("pirate", {}).get("gold_per_kill", 0)
			if gold_per_kill > 0:
				# Actual soldiers killed: reconstruct pre-damage count since damage was already applied
				var soldiers_before: int = target["soldiers"] + damage
				var soldiers_killed: int = soldiers_before - maxi(target["soldiers"], 0)
				var gold_gain: int = soldiers_killed * gold_per_kill
				# Synergy special: gold_income_bonus multiplier
				var syn_specials: Dictionary = state.get("atk_synergy_specials", {}) if source["side"] == "attacker" else state.get("def_synergy_specials", {})
				var gold_bonus_pct: float = syn_specials.get("gold_income_bonus", 0.0)
				if gold_bonus_pct > 0.0:
					gold_gain = int(float(gold_gain) * (1.0 + gold_bonus_pct))
				ResourceManager.apply_delta(source_pid, {"gold": gold_gain})
				log.append("%s [%s] 掠夺经济! 击杀%d兵 +%d金" % [source["unit_type"], source["side"], soldiers_killed, gold_gain])

	if target["soldiers"] <= 0:
		target["soldiers"] = 0
		target["is_alive"] = false
		log.append("%s [%s] 被消灭!" % [target["unit_type"], target["side"]])

		# Morale cascade: allies lose morale when a unit is eliminated
		var allied_units: Array = state["atk_units"] if target["side"] == "attacker" else state["def_units"]
		for ally in allied_units:
			if ally["is_alive"] and ally != target and "morale_immune" not in ally["passives"] and not ally.get("immovable", false):
				ally["morale"] = maxi(ally.get("morale", MORALE_START) - MORALE_ALLY_ELIMINATED, 0)

		# Death burst: on death, deal ATK × 2 to all enemies
		# FIX(HIGH): 清理冗余赋值，死亡爆发伤害对方阵营（即杀死自己的一方）
		if "death_burst" in target["passives"] and not _death_burst_recursion:
			var burst_enemies: Array
			if target["side"] == "attacker":
				burst_enemies = state["def_units"]
			else:
				burst_enemies = state["atk_units"]
			var burst_dmg: int = int(target["atk"] * 2.0)
			log.append("%s 死亡爆发! 对敌全体造成 %d 伤害!" % [target["unit_type"], burst_dmg])
			for enemy in burst_enemies:
				if enemy["is_alive"]:
					_apply_damage_to_unit(state, enemy, burst_dmg, target, log, true)


# ---------------------------------------------------------------------------
# End of Round
# ---------------------------------------------------------------------------

func _end_of_round(state: Dictionary, log: Array) -> String:
	# Decrement intervention effect durations
	if state.get("forced_target_duration", 0) > 0:
		state["forced_target_duration"] -= 1
		if state["forced_target_duration"] <= 0:
			state.erase("forced_target")
	if state.get("bait_duration", 0) > 0:
		state["bait_duration"] -= 1
		if state["bait_duration"] <= 0:
			state.erase("bait_target")

	# Tick down buffs/debuffs at end of round so duration=1 buffs last the full round
	for unit in state["atk_units"] + state["def_units"]:
		if not unit["is_alive"]:
			continue

		# Check summon_decay BEFORE filtering expired buffs, so we can detect
		# buffs that are about to expire (duration == 1 -> will be 0 after tick).
		for b in unit["buffs"]:
			if b["id"] == "summon_decay" and b["duration"] <= 1:
				unit["is_alive"] = false
				unit["soldiers"] = 0
				log.append("%s [%s] 召唤物消散" % [unit["unit_type"], unit["side"]])
				break

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

	# Morale: rout check
	for unit in state["atk_units"] + state["def_units"]:
		if not unit["is_alive"] or unit.get("is_routed", false):
			continue
		if unit.get("morale", MORALE_START) <= MORALE_ROUT_THRESHOLD:
			if "morale_immune" not in unit["passives"] and not unit.get("immovable", false):
				var rout_loss: int = int(float(unit["soldiers"]) * MORALE_ROUT_LOSS_PCT)
				unit["soldiers"] = maxi(unit["soldiers"] - rout_loss, 0)
				unit["is_routed"] = true
				log.append("[color=yellow]%s [%s] 士气崩溃! 溃逃损失 %d 兵[/color]" % [unit["unit_type"], unit["side"], rout_loss])
				EventBus.unit_routed.emit(unit["unit_type"], unit["side"])
				if unit["soldiers"] <= 0:
					unit["is_alive"] = false
					log.append("%s [%s] 溃逃后全灭!" % [unit["unit_type"], unit["side"]])

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

	# Equipment: kill_heal (blood_moon_blade) — only check winner's heroes
	# v4.5: kill_heal_2 — heals 2 soldiers instead of 1
	var winner_pid: int = atk_pid if winner == "attacker" else def_pid
	if winner_pid >= 0:
		for hero in HeroSystem.get_heroes_for_player(winner_pid):
			var heal_amount: int = 0
			if HeroSystem.has_equipment_passive(hero["id"], "kill_heal_2"):
				heal_amount = 2
			elif HeroSystem.has_equipment_passive(hero["id"], "kill_heal"):
				heal_amount = 1
			if heal_amount > 0:
				if winner == "attacker":
					attacker_losses = maxi(attacker_losses - heal_amount, 0)
				else:
					defender_losses = maxi(defender_losses - heal_amount, 0)
				log.append("装备: 胜利回复%d兵" % heal_amount)
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

	# Passive: pillage — winning side gains +10 gold per unit with pillage
	var winner_units: Array = state["atk_units"] if winner == "attacker" else state["def_units"]
	var pillage_gold: int = 0
	for unit in winner_units:
		if unit["is_alive"] and "pillage" in unit["passives"]:
			pillage_gold += 10
	if pillage_gold > 0 and winner_pid >= 0:
		ResourceManager.apply_delta(winner_pid, {"gold": pillage_gold})
		log.append("劫掠! 胜利方获得 +%d 金" % pillage_gold)

	# v4.5: plunder_gold_bonus — +50% plunder gold on victory (equipment passive)
	if winner_pid >= 0 and pillage_gold > 0:
		for hero in HeroSystem.get_heroes_for_player(winner_pid):
			if HeroSystem.has_equipment_passive(hero["id"], "plunder_gold_bonus"):
				var bonus_gold: int = int(float(pillage_gold) * 0.5)
				ResourceManager.apply_delta(winner_pid, {"gold": bonus_gold})
				log.append("装备: 掠夺金币加成 +%d 金 (50%%)" % bonus_gold)
				break

	# v4.5: victory_waaagh_bonus — +5 WAAAGH on victory (equipment passive)
	if winner_pid >= 0:
		for hero in HeroSystem.get_heroes_for_player(winner_pid):
			if HeroSystem.has_equipment_passive(hero["id"], "victory_waaagh_bonus"):
				OrcMechanic.add_waaagh(winner_pid, 5)
				log.append("装备: 胜利WAAAGH +5!")
				break

	# v4.5: waaagh_gain_bonus — +25% WAAAGH gain post-battle (equipment passive)
	if winner_pid >= 0:
		for hero in HeroSystem.get_heroes_for_player(winner_pid):
			if HeroSystem.has_equipment_passive(hero["id"], "waaagh_gain_bonus"):
				var base_waaagh: int = 10  # standard post-battle WAAAGH gain
				var bonus_waaagh: int = int(float(base_waaagh) * 0.25)
				OrcMechanic.add_waaagh(winner_pid, bonus_waaagh)
				log.append("装备: WAAAGH增益加成 +%d (25%%)" % bonus_waaagh)
				break

	# v4.5: iron_income_bonus — post-battle iron grant (equipment passive)
	if winner_pid >= 0:
		for hero in HeroSystem.get_heroes_for_player(winner_pid):
			if HeroSystem.has_equipment_passive(hero["id"], "iron_income_bonus"):
				var iron_amount: int = 5
				ResourceManager.apply_delta(winner_pid, {"iron": iron_amount})
				log.append("装备: 战后获得 +%d 铁" % iron_amount)
				break

	# Story flag gold bonuses: momiji paths
	var gold_bonus_flags: Dictionary = {}
	for unit in winner_units:
		if unit["is_alive"]:
			# momiji_partner: +20% gold bonus on victory
			if "momiji_gold_bonus_20" in unit["passives"]:
				gold_bonus_flags["momiji_gold_bonus_20"] = true
				log.append("%s [%s] 紅葉伙伴: 胜利金币+20%%!" % [unit["unit_type"], unit["side"]])
			# momiji_rival: 15% chance bonus gold
			if "momiji_gold_bonus_15" in unit["passives"]:
				if randf() < 0.15:
					gold_bonus_flags["momiji_gold_bonus_15"] = true
					log.append("%s [%s] 紅葉竞争: 触发额外金币奖励!" % [unit["unit_type"], unit["side"]])

	var combat_result := {
		"winner": winner,
		"attacker_losses": attacker_losses,
		"defender_losses": defender_losses,
		"slaves_captured": slaves_captured,
		"wall_destroyed": wall_destroyed,
		"details": log,
		"gold_bonus_flags": gold_bonus_flags,
	}

	# Restore retreated units (they survive with their soldiers intact)
	if state.get("interventions_enabled", false):
		combat_result["retreated_units"] = CommanderIntervention.get_retreated_units()
		combat_result["interventions_used"] = CommanderIntervention.get_battle_report()

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
		for hero in HeroSystem.get_heroes_for_player(winner_id):
			if HeroSystem.has_equipment_passive(hero["id"], "capture_bonus"):
				var bonus: float = HeroSystem.get_equipment_passive_value(hero["id"], "capture_bonus")
				if randf() < bonus:
					count += 1
				break
		# v4.5: slave_chain_bonus — +15% capture chance + extra slave
		for hero in HeroSystem.get_heroes_for_player(winner_id):
			if HeroSystem.has_equipment_passive(hero["id"], "slave_chain_bonus"):
				if randf() < 0.15:
					count += 1
				break
		# v4.5: capture_essence_bonus — +20% capture chance + extra shadow essence
		for hero in HeroSystem.get_heroes_for_player(winner_id):
			if HeroSystem.has_equipment_passive(hero["id"], "capture_essence_bonus"):
				if randf() < 0.20:
					count += 1
				# Grant extra shadow essence
				ResourceManager.apply_delta(winner_id, {"shadow_essence": 1})
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
		"bombardier", "goblin_artillery", "pirate_cannon":
			return "cannon"
		"pirate_ultimate":
			return "samurai"  # BUG FIX: pirate_ultimate is TC_SAMURAI, not cannon
		"orc_ultimate":
			return "samurai"
		"de_ultimate":
			return "mage_unit"  # BUG FIX: de_ultimate is TC_MAGE_UNIT, was falling through to ashigaru
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


func _get_hero_list(units: Array) -> Array:
	var heroes: Array = []
	for unit in units:
		if unit["hero_id"] != "":
			heroes.append({"id": unit["hero_id"], "passives": unit["passives"]})
	return heroes


func _get_all_alive(units: Array) -> Array:
	var result: Array = []
	for unit in units:
		if unit["is_alive"] and unit["soldiers"] > 0:
			result.append(unit)
	return result


func _get_fastest_unit(units: Array) -> Dictionary:
	## Returns the alive unit with the highest SPD on the given side.
	var fastest: Dictionary = {}
	var best_spd: float = -1.0
	for unit in units:
		if unit["is_alive"] and unit["soldiers"] > 0 and unit["spd"] > best_spd:
			best_spd = unit["spd"]
			fastest = unit
	return fastest


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
		if unit["is_alive"] and not unit.get("is_routed", false):
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
