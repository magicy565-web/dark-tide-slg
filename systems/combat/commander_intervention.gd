## Commander Intervention System — Mid-battle player decisions
## Gives players limited Command Points (CP) to spend on tactical interventions
## during combat rounds. Each intervention changes the battle flow.
extends Node

# Command Points: base 3 + hero_leadership_bonus
const CP_BASE: int = 3
const CP_PER_HERO_LEADERSHIP: int = 1  # heroes with "leadership" passive grant +1 CP
const CP_MAX: int = 8

# Intervention types and their costs
enum InterventionType {
	REDIRECT_FIRE,      # Force all units to target a specific enemy unit (1 round)
	RALLY,              # Restore 20 morale to all units + cure rout on 1 unit
	HERO_SKILL_NOW,     # Immediately trigger a hero's active skill (ignore cooldown)
	FORMATION_SHIFT,    # Swap a front-row unit with a back-row unit
	TACTICAL_RETREAT,   # Pull one unit from combat (saves it but removes from battle)
	INSPIRE,            # All units ATK+15% for 2 rounds
	SHIELD_WALL,        # All front-row units DEF+30% for 1 round, but ATK-20%
	FOCUS_VOLLEY,       # All back-row ranged units attack same target this round, damage +25%
	SACRIFICE_PAWN,     # Destroy your weakest unit to fully heal your strongest
	BAIT_AND_SWITCH,    # Swap targeting: enemies attack your highest-DEF unit for 1 round
}

const INTERVENTION_DATA: Dictionary = {
	InterventionType.REDIRECT_FIRE: {
		"name": "集火指令", "desc": "指定一个敌方单位, 全军集中攻击(1回合)",
		"cp_cost": 1, "cooldown": 3, "requires_target": true,
	},
	InterventionType.RALLY: {
		"name": "鼓舞士气", "desc": "全军士气+20, 解除1个溃逃单位",
		"cp_cost": 2, "cooldown": 4, "requires_target": false,
	},
	InterventionType.HERO_SKILL_NOW: {
		"name": "强令发动", "desc": "立即发动一名英雄的主动技能(无视冷却)",
		"cp_cost": 3, "cooldown": 0, "requires_target": true,  # target = hero_id
	},
	InterventionType.FORMATION_SHIFT: {
		"name": "阵型变换", "desc": "交换一个前排与后排单位的位置",
		"cp_cost": 1, "cooldown": 2, "requires_target": true,  # target = [slot_a, slot_b]
	},
	InterventionType.TACTICAL_RETREAT: {
		"name": "战术撤退", "desc": "撤出一个单位(保存兵力但退出战斗)",
		"cp_cost": 2, "cooldown": 0, "requires_target": true,
	},
	InterventionType.INSPIRE: {
		"name": "激励号令", "desc": "全军ATK+15%, 持续2回合",
		"cp_cost": 2, "cooldown": 5, "requires_target": false,
	},
	InterventionType.SHIELD_WALL: {
		"name": "盾墙", "desc": "前排DEF+30%, ATK-20%, 持续1回合",
		"cp_cost": 1, "cooldown": 3, "requires_target": false,
	},
	InterventionType.FOCUS_VOLLEY: {
		"name": "齐射", "desc": "后排远程单位集中攻击同一目标, 伤害+25%",
		"cp_cost": 2, "cooldown": 3, "requires_target": true,
	},
	InterventionType.SACRIFICE_PAWN: {
		"name": "弃子", "desc": "牺牲最弱单位, 完全治愈最强单位",
		"cp_cost": 2, "cooldown": 0, "requires_target": false,
	},
	InterventionType.BAIT_AND_SWITCH: {
		"name": "诱敌", "desc": "敌方本回合只能攻击你DEF最高的单位",
		"cp_cost": 1, "cooldown": 4, "requires_target": false,
	},
}

# Track state during a battle
var _current_cp: int = 0
var _max_cp: int = 0
var _cooldowns: Dictionary = {}  # InterventionType -> rounds remaining
var _interventions_used: Array = []  # log of interventions for battle report
var _retreated_units: Array = []  # units pulled from combat

func initialize_for_battle(attacker_units: Array, attacker_heroes: Array) -> void:
	# Calculate starting CP
	_current_cp = CP_BASE
	for hero in attacker_heroes:
		if hero.get("passive", "") == "leadership" or "leadership" in hero.get("passives", []):
			_current_cp += CP_PER_HERO_LEADERSHIP
	_current_cp = mini(_current_cp, CP_MAX)
	_max_cp = _current_cp
	_cooldowns.clear()
	_interventions_used.clear()
	_retreated_units.clear()

func get_current_cp() -> int:
	return _current_cp

func get_max_cp() -> int:
	return _max_cp

func get_available_interventions() -> Array:
	var available: Array = []
	for type_key in INTERVENTION_DATA:
		var data: Dictionary = INTERVENTION_DATA[type_key]
		if _current_cp >= data["cp_cost"] and _cooldowns.get(type_key, 0) <= 0:
			available.append({"type": type_key, "data": data})
	return available

func can_use(intervention_type: int) -> bool:
	var data: Dictionary = INTERVENTION_DATA.get(intervention_type, {})
	if data.is_empty():
		return false
	return _current_cp >= data["cp_cost"] and _cooldowns.get(intervention_type, 0) <= 0

func execute(intervention_type: int, state: Dictionary, target: Variant, log: Array) -> bool:
	if not can_use(intervention_type):
		return false
	var data: Dictionary = INTERVENTION_DATA[intervention_type]
	_current_cp -= data["cp_cost"]
	if data["cooldown"] > 0:
		_cooldowns[intervention_type] = data["cooldown"]
	_interventions_used.append({"type": intervention_type, "round": state.get("round", 0)})

	match intervention_type:
		InterventionType.REDIRECT_FIRE:
			_execute_redirect_fire(state, target, log)
		InterventionType.RALLY:
			_execute_rally(state, log)
		InterventionType.HERO_SKILL_NOW:
			_execute_hero_skill_now(state, target, log)
		InterventionType.FORMATION_SHIFT:
			_execute_formation_shift(state, target, log)
		InterventionType.TACTICAL_RETREAT:
			_execute_tactical_retreat(state, target, log)
		InterventionType.INSPIRE:
			_execute_inspire(state, log)
		InterventionType.SHIELD_WALL:
			_execute_shield_wall(state, log)
		InterventionType.FOCUS_VOLLEY:
			_execute_focus_volley(state, target, log)
		InterventionType.SACRIFICE_PAWN:
			_execute_sacrifice_pawn(state, log)
		InterventionType.BAIT_AND_SWITCH:
			_execute_bait_and_switch(state, log)
	return true

func tick_cooldowns() -> void:
	for key in _cooldowns.keys():
		_cooldowns[key] = maxi(_cooldowns[key] - 1, 0)

func get_retreated_units() -> Array:
	return _retreated_units

func get_battle_report() -> Array:
	return _interventions_used

# --- Intervention implementations ---

func _execute_redirect_fire(state: Dictionary, target_slot: Variant, log: Array) -> void:
	# Force all attacker units to target a specific enemy slot this round
	var target_idx: int = int(target_slot) if target_slot != null else 0
	var enemies: Array = state["def_units"]
	if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx]["is_alive"]:
		state["forced_target"] = target_idx
		state["forced_target_duration"] = 1
		log.append("[color=gold]【指挥】集火指令! 全军锁定 %s![/color]" % enemies[target_idx]["unit_type"])

func _execute_rally(state: Dictionary, log: Array) -> void:
	var rallied_rout: bool = false
	for unit in state["atk_units"]:
		if not unit["is_alive"]:
			continue
		unit["morale"] = mini(unit["morale"] + 20, 100)
		if unit.get("is_routed", false) and not rallied_rout:
			unit["is_routed"] = false
			unit["morale"] = 30  # recovered but fragile
			rallied_rout = true
			log.append("[color=gold]【指挥】鼓舞! %s 从溃逃中恢复![/color]" % unit["unit_type"])
	log.append("[color=gold]【指挥】鼓舞士气! 全军士气+20[/color]")

func _execute_hero_skill_now(state: Dictionary, hero_id: Variant, log: Array) -> void:
	# Force-trigger a hero skill immediately
	var target_hero: String = str(hero_id) if hero_id != null else ""
	for unit in state["atk_units"]:
		if unit["hero_id"] == target_hero and unit["is_alive"]:
			var skill: Dictionary = unit.get("active_skill", {})
			if not skill.is_empty():
				unit["skill_cooldown"] = 0  # reset cooldown to allow immediate use
				state["force_skill_hero"] = target_hero
				log.append("[color=gold]【指挥】强令发动! %s 立即使用 %s![/color]" % [target_hero, skill.get("name", "技能")])
			break

func _execute_formation_shift(state: Dictionary, slots: Variant, log: Array) -> void:
	# Swap two units between front and back row
	if slots == null or not (slots is Array) or slots.size() < 2:
		return
	var slot_a: int = int(slots[0])
	var slot_b: int = int(slots[1])
	var units: Array = state["atk_units"]
	var unit_a: Dictionary = {}
	var unit_b: Dictionary = {}
	for u in units:
		if u["slot"] == slot_a and u["is_alive"]:
			unit_a = u
		if u["slot"] == slot_b and u["is_alive"]:
			unit_b = u
	if unit_a.is_empty() or unit_b.is_empty():
		return
	if unit_a.get("immovable", false) or unit_b.get("immovable", false):
		log.append("[color=red]不可移动单位无法交换位置![/color]")
		return
	# Swap slots and rows
	var temp_slot: int = unit_a["slot"]
	var temp_row: String = unit_a["row"]
	unit_a["slot"] = unit_b["slot"]
	unit_a["row"] = unit_b["row"]
	unit_b["slot"] = temp_slot
	unit_b["row"] = temp_row
	log.append("[color=gold]【指挥】阵型变换! %s ⇄ %s[/color]" % [unit_a["unit_type"], unit_b["unit_type"]])

func _execute_tactical_retreat(state: Dictionary, target_slot: Variant, log: Array) -> void:
	var slot: int = int(target_slot) if target_slot != null else -1
	for unit in state["atk_units"]:
		if unit["slot"] == slot and unit["is_alive"]:
			unit["is_alive"] = false
			_retreated_units.append(unit.duplicate())  # save for post-battle recovery
			log.append("[color=gold]【指挥】战术撤退! %s 撤出战场(保留%d兵)[/color]" % [unit["unit_type"], unit["soldiers"]])
			break

func _execute_inspire(state: Dictionary, log: Array) -> void:
	for unit in state["atk_units"]:
		if unit["is_alive"]:
			unit["buffs"].append({"id": "inspire", "duration": 2, "value": 0.15, "mult_atk": true})
	log.append("[color=gold]【指挥】激励号令! 全军ATK+15%%(2回合)[/color]")

func _execute_shield_wall(state: Dictionary, log: Array) -> void:
	for unit in state["atk_units"]:
		if unit["is_alive"] and unit["row"] == "front":
			unit["buffs"].append({"id": "shield_wall_def", "duration": 1, "value": 0.30, "mult_def": true})
			unit["buffs"].append({"id": "shield_wall_atk", "duration": 1, "value": -0.20, "mult_atk": true})
	log.append("[color=gold]【指挥】盾墙! 前排DEF+30%%, ATK-20%%(1回合)[/color]")

func _execute_focus_volley(state: Dictionary, target_slot: Variant, log: Array) -> void:
	var slot: int = int(target_slot) if target_slot != null else 0
	for unit in state["atk_units"]:
		if unit["is_alive"] and unit["row"] == "back":
			unit["buffs"].append({"id": "focus_volley", "duration": 1, "value": 0.25, "mult_atk": true})
	state["forced_target"] = slot
	state["forced_target_duration"] = 1
	var enemies: Array = state["def_units"]
	var target_name: String = "目标"
	if slot >= 0 and slot < enemies.size():
		target_name = enemies[slot]["unit_type"]
	log.append("[color=gold]【指挥】齐射! 后排远程集中攻击 %s, 伤害+25%%![/color]" % target_name)

func _execute_sacrifice_pawn(state: Dictionary, log: Array) -> void:
	var alive: Array = []
	for unit in state["atk_units"]:
		if unit["is_alive"]:
			alive.append(unit)
	if alive.size() < 2:
		return
	# Find weakest (lowest soldiers * atk) and strongest (highest soldiers * atk)
	alive.sort_custom(func(a, b): return (a["soldiers"] * a["atk"]) < (b["soldiers"] * b["atk"]))
	var weakest: Dictionary = alive[0]
	var strongest: Dictionary = alive[alive.size() - 1]
	log.append("[color=gold]【指挥】弃子! 牺牲 %s, 完全治愈 %s![/color]" % [weakest["unit_type"], strongest["unit_type"]])
	weakest["soldiers"] = 0
	weakest["is_alive"] = false
	strongest["soldiers"] = strongest["max_soldiers"]
	strongest["morale"] = 100

func _execute_bait_and_switch(state: Dictionary, log: Array) -> void:
	# Find highest-DEF attacker unit
	var best_def: float = -1.0
	var tank_slot: int = -1
	for unit in state["atk_units"]:
		if unit["is_alive"] and unit["def"] > best_def:
			best_def = unit["def"]
			tank_slot = unit["slot"]
	if tank_slot >= 0:
		state["bait_target"] = tank_slot
		state["bait_duration"] = 1
		log.append("[color=gold]【指挥】诱敌! 敌方本回合只能攻击最高DEF单位![/color]")
