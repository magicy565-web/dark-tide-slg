## hero_system.gd - Hero capture, prison, recruitment, affection, equipment, and active skills (v0.9.0)
## Uses v0.8.1 API: ResourceManager, ThreatManager, GameManager.get_human_player_id()
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── State (per-session, will be serialized by save system) ──
var captured_heroes: Array = []        # hero_id strings in prison
var recruited_heroes: Array = []       # hero_id strings recruited
var hero_corruption: Dictionary = {}   # hero_id -> int (prison corruption counter)
var hero_affection: Dictionary = {}    # hero_id -> int (0-10)

# ── Equipment state (v0.8.7) ──
# hero_id -> { "weapon": equip_id or "", "armor": equip_id or "", "accessory": equip_id or "" }
var hero_equipment: Dictionary = {}

# ── Active skill cooldowns (v0.9.0) ──
# hero_id -> int (remaining cooldown turns, 0 = ready)
var _skill_cooldowns: Dictionary = {}


func reset() -> void:
	captured_heroes.clear()
	recruited_heroes.clear()
	hero_corruption.clear()
	hero_affection.clear()
	hero_equipment.clear()
	_skill_cooldowns.clear()


# ═══════════════ CAPTURE ═══════════════

## Attempt to capture a hero after battle (called by combat resolution)
func attempt_capture(hero_id: String, capture_chance: float = -1.0) -> bool:
	if hero_id in captured_heroes or hero_id in recruited_heroes:
		return false
	if captured_heroes.size() >= FactionData.PRISON_CAPACITY:
		return false
	# Use hero's default capture chance if not overridden
	if capture_chance < 0.0:
		var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
		capture_chance = hero_data.get("capture_chance", 0.5)
	if randf() <= capture_chance:
		captured_heroes.append(hero_id)
		hero_corruption[hero_id] = 0
		EventBus.hero_captured.emit(hero_id)
		EventBus.message_log.emit("捕获英雄: %s" % _get_hero_name(hero_id))
		# 03_战略设定: 俘英雄+20威胁
		ThreatManager.on_hero_captured()
		return true
	return false


# ═══════════════ PRISON ═══════════════

## Process prison each turn: increase corruption
func process_prison_turn() -> void:
	for hero_id in captured_heroes:
		hero_corruption[hero_id] = hero_corruption.get(hero_id, 0) + 1


## Attempt to recruit a captured hero
func attempt_recruit(hero_id: String) -> Dictionary:
	if hero_id not in captured_heroes:
		return {"ok": false, "reason": "未被俘虏"}
	var corruption: int = hero_corruption.get(hero_id, 0)
	if corruption < FactionData.CORRUPTION_TO_RECRUIT:
		return {"ok": false, "reason": "腐化不足 (%d/%d)" % [corruption, FactionData.CORRUPTION_TO_RECRUIT]}
	# 50% base success, +10% per corruption above threshold
	var success_chance: float = 0.5 + (corruption - FactionData.CORRUPTION_TO_RECRUIT) * 0.1
	if randf() <= success_chance:
		captured_heroes.erase(hero_id)
		recruited_heroes.append(hero_id)
		hero_affection[hero_id] = 0
		hero_corruption.erase(hero_id)
		EventBus.hero_recruited.emit(hero_id)
		EventBus.message_log.emit("招募英雄: %s" % _get_hero_name(hero_id))
		return {"ok": true, "reason": "招募成功"}
	return {"ok": false, "reason": "招募失败（抵抗）"}


## Release a captured hero (reduces threat, gains prestige)
func release_hero(hero_id: String) -> bool:
	if hero_id not in captured_heroes:
		return false
	captured_heroes.erase(hero_id)
	hero_corruption.erase(hero_id)
	# 03_战略设定: 释放英雄 威胁-10, 威望+5
	ThreatManager.on_hero_released()
	var pid: int = GameManager.get_human_player_id()
	ResourceManager.apply_delta(pid, {"prestige": 5})
	EventBus.hero_released.emit(hero_id)
	EventBus.message_log.emit("释放英雄: %s (威胁-10, 威望+5)" % _get_hero_name(hero_id))
	return true


# ═══════════════ AFFECTION ═══════════════

## Add affection after shared battle
func add_affection(hero_id: String, amount: int = 1) -> void:
	if hero_id not in recruited_heroes:
		return
	var old_val: int = hero_affection.get(hero_id, 0)
	var new_val: int = mini(old_val + amount, FactionData.AFFECTION_MAX)
	if new_val == old_val:
		return
	hero_affection[hero_id] = new_val
	EventBus.hero_affection_changed.emit(hero_id, new_val)

	var hero_name: String = _get_hero_name(hero_id)

	# Check threshold crossings
	if old_val < 3 and new_val >= 3:
		EventBus.message_log.emit("[color=green][好感度] %s 好感达到3: 被动技能强化![/color]" % hero_name)
	if old_val < 5 and new_val >= 5:
		EventBus.message_log.emit("[color=green][好感度] %s 好感达到5: 专属事件开放![/color]" % hero_name)
	if old_val < 7 and new_val >= 7:
		EventBus.message_log.emit("[color=yellow][好感度] %s 好感达到7: 解锁第二主动技能![/color]" % hero_name)
		_unlock_second_skill(hero_id)
	if old_val < 10 and new_val >= 10:
		EventBus.message_log.emit("[color=cyan][好感度] %s 好感达到10: 专属结局路线开放![/color]" % hero_name)


## Check affection unlocks
func get_affection_unlocks(hero_id: String) -> Array:
	var aff: int = hero_affection.get(hero_id, 0)
	var unlocks := []
	if aff >= 3: unlocks.append("passive_upgrade")
	if aff >= 5: unlocks.append("unique_event")
	if aff >= 7: unlocks.append("second_active_skill")
	if aff >= 10: unlocks.append("exclusive_ending")
	return unlocks


# ═══════════════ COMBAT STATS ═══════════════

## Get hero battle stats (commander stats for combat system)
func get_hero_combat_stats(hero_id: String) -> Dictionary:
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	if hero_data.is_empty():
		return {}
	var affection: int = hero_affection.get(hero_id, 0)
	# Affection bonuses
	var atk_bonus: int = 0
	var def_bonus: int = 0
	if affection >= 5: atk_bonus += 1
	if affection >= 7: def_bonus += 1
	if affection >= 10: atk_bonus += 1; def_bonus += 1
	# Equipment stat bonuses (v0.8.7)
	var equip_stats: Dictionary = get_equipment_stat_totals(hero_id)
	atk_bonus += equip_stats.get("atk", 0)
	def_bonus += equip_stats.get("def", 0)
	return {
		"name": hero_data["name"],
		"troop": hero_data["troop"],
		"atk": hero_data["atk"] + atk_bonus,
		"def": hero_data["def"] + def_bonus,
		"int": hero_data["int"],
		"spd": hero_data["spd"] + equip_stats.get("spd", 0),
		"active": hero_data["active"],
		"passive": hero_data["passive"],
		"equipment_passives": get_equipment_passives(hero_id),
	}


## Get all recruited heroes as a list of combat-ready data
func get_available_heroes() -> Array:
	var result := []
	for hero_id in recruited_heroes:
		var stats: Dictionary = get_hero_combat_stats(hero_id)
		if not stats.is_empty():
			stats["id"] = hero_id
			result.append(stats)
	return result


# ═══════════════ EQUIPMENT (v0.8.7) ═══════════════

func _ensure_equip_slots(hero_id: String) -> void:
	if not hero_equipment.has(hero_id):
		hero_equipment[hero_id] = {"weapon": "", "armor": "", "accessory": ""}


func equip_item(hero_id: String, equip_id: String) -> Dictionary:
	## Equip an equipment item on a hero. Returns {ok, reason, unequipped_id}.
	if hero_id not in recruited_heroes:
		return {"ok": false, "reason": "英雄未招募"}
	if not FactionData.EQUIPMENT_DEFS.has(equip_id):
		return {"ok": false, "reason": "装备不存在"}
	var pid: int = GameManager.get_human_player_id()
	if not ItemManager.has_item(pid, equip_id):
		return {"ok": false, "reason": "背包中无此装备"}

	var equip_data: Dictionary = FactionData.EQUIPMENT_DEFS[equip_id]
	var slot_enum: int = equip_data["slot"]
	var slot_key: String = _slot_enum_to_key(slot_enum)

	_ensure_equip_slots(hero_id)
	var old_equip: String = hero_equipment[hero_id][slot_key]

	# Remove from inventory
	ItemManager.remove_item(pid, equip_id)

	# Return old equipment to inventory if slot was occupied
	if old_equip != "":
		ItemManager.add_item(pid, old_equip)

	hero_equipment[hero_id][slot_key] = equip_id
	EventBus.message_log.emit("%s 装备了 %s" % [_get_hero_name(hero_id), equip_data["name"]])
	return {"ok": true, "reason": "装备成功", "unequipped_id": old_equip}


func unequip_item(hero_id: String, slot_key: String) -> Dictionary:
	## Unequip an item from a hero's slot. Returns {ok, reason, equip_id}.
	if hero_id not in recruited_heroes:
		return {"ok": false, "reason": "英雄未招募"}
	_ensure_equip_slots(hero_id)
	var equip_id: String = hero_equipment[hero_id].get(slot_key, "")
	if equip_id == "":
		return {"ok": false, "reason": "该槽位无装备"}

	var pid: int = GameManager.get_human_player_id()
	if ItemManager.is_full(pid):
		return {"ok": false, "reason": "背包已满, 无法卸下装备"}

	hero_equipment[hero_id][slot_key] = ""
	ItemManager.add_item(pid, equip_id)
	var equip_data: Dictionary = FactionData.EQUIPMENT_DEFS.get(equip_id, {})
	EventBus.message_log.emit("%s 卸下了 %s" % [_get_hero_name(hero_id), equip_data.get("name", equip_id)])
	return {"ok": true, "reason": "卸下成功", "equip_id": equip_id}


func get_hero_equipment(hero_id: String) -> Dictionary:
	## Returns { "weapon": equip_id, "armor": equip_id, "accessory": equip_id }
	_ensure_equip_slots(hero_id)
	return hero_equipment[hero_id].duplicate()


func get_hero_equipment_details(hero_id: String) -> Array:
	## Returns array of equipped item detail dicts for UI display.
	_ensure_equip_slots(hero_id)
	var result: Array = []
	for slot_key in ["weapon", "armor", "accessory"]:
		var equip_id: String = hero_equipment[hero_id][slot_key]
		if equip_id != "" and FactionData.EQUIPMENT_DEFS.has(equip_id):
			var data: Dictionary = FactionData.EQUIPMENT_DEFS[equip_id].duplicate()
			data["equip_id"] = equip_id
			data["slot_key"] = slot_key
			result.append(data)
		else:
			result.append({"equip_id": "", "slot_key": slot_key, "name": "空", "desc": ""})
	return result


func get_equipment_stat_totals(hero_id: String) -> Dictionary:
	## Sum all stat bonuses from equipped items.
	var totals := {"atk": 0, "def": 0, "spd": 0}
	_ensure_equip_slots(hero_id)
	for slot_key in ["weapon", "armor", "accessory"]:
		var equip_id: String = hero_equipment[hero_id][slot_key]
		if equip_id == "":
			continue
		var data: Dictionary = FactionData.EQUIPMENT_DEFS.get(equip_id, {})
		var stats: Dictionary = data.get("stats", {})
		for key in stats:
			totals[key] = totals.get(key, 0) + stats[key]
	return totals


func get_equipment_passives(hero_id: String) -> Array:
	## Returns array of passive strings from equipped items (for combat resolver).
	var passives: Array = []
	_ensure_equip_slots(hero_id)
	for slot_key in ["weapon", "armor", "accessory"]:
		var equip_id: String = hero_equipment[hero_id][slot_key]
		if equip_id == "":
			continue
		var data: Dictionary = FactionData.EQUIPMENT_DEFS.get(equip_id, {})
		var passive: String = data.get("passive", "none")
		if passive != "none":
			passives.append(passive)
	return passives


func has_equipment_passive(hero_id: String, passive_name: String) -> bool:
	return passive_name in get_equipment_passives(hero_id)


func get_equipment_passive_value(hero_id: String, passive_name: String) -> float:
	## Get the value of a specific equipment passive (e.g., capture_bonus -> 0.1).
	_ensure_equip_slots(hero_id)
	for slot_key in ["weapon", "armor", "accessory"]:
		var equip_id: String = hero_equipment[hero_id][slot_key]
		if equip_id == "":
			continue
		var data: Dictionary = FactionData.EQUIPMENT_DEFS.get(equip_id, {})
		if data.get("passive", "none") == passive_name:
			return data.get("passive_value", 0.0)
	return 0.0


func _slot_enum_to_key(slot_enum: int) -> String:
	match slot_enum:
		FactionData.EquipSlot.WEAPON: return "weapon"
		FactionData.EquipSlot.ARMOR: return "armor"
		FactionData.EquipSlot.ACCESSORY: return "accessory"
	return "accessory"


# ═══════════════ ACTIVE SKILLS (v0.9.0) ═══════════════

func tick_cooldowns() -> void:
	## Called each turn. Decrements all cooldowns by 1.
	for hero_id in _skill_cooldowns:
		if _skill_cooldowns[hero_id] > 0:
			_skill_cooldowns[hero_id] -= 1


func get_skill_cooldown(hero_id: String) -> int:
	return _skill_cooldowns.get(hero_id, 0)


func is_skill_ready(hero_id: String) -> bool:
	return hero_id in recruited_heroes and get_skill_cooldown(hero_id) <= 0


func use_skill(hero_id: String) -> void:
	## Mark a skill as used, putting it on cooldown.
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	var skill_name: String = hero_data.get("active", "")
	var skill_def: Dictionary = FactionData.HERO_SKILL_DEFS.get(skill_name, {})
	var cooldown: int = skill_def.get("cooldown", 3)
	_skill_cooldowns[hero_id] = cooldown


func get_hero_skill_data(hero_id: String) -> Dictionary:
	## Returns full skill data for a recruited hero, including readiness.
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	var skill_name: String = hero_data.get("active", "")
	if skill_name == "":
		return {}
	var skill_def: Dictionary = FactionData.HERO_SKILL_DEFS.get(skill_name, {})
	if skill_def.is_empty():
		return {}
	var result: Dictionary = skill_def.duplicate()
	result["name"] = skill_name
	result["hero_id"] = hero_id
	result["hero_name"] = hero_data.get("name", hero_id)
	result["hero_int"] = hero_data.get("int", 5)
	result["ready"] = is_skill_ready(hero_id)
	result["cooldown_remaining"] = get_skill_cooldown(hero_id)
	# Calculate effective power
	var base_power: float = skill_def.get("power", 0)
	var int_scale: float = skill_def.get("int_scale", 0.0)
	result["effective_power"] = base_power + float(hero_data.get("int", 5)) * int_scale
	return result


func get_all_ready_skills() -> Array:
	## Returns array of skill data for all recruited heroes with ready skills.
	var result: Array = []
	for hero_id in recruited_heroes:
		if is_skill_ready(hero_id):
			var skill_data: Dictionary = get_hero_skill_data(hero_id)
			if not skill_data.is_empty():
				result.append(skill_data)
	return result


func apply_skill_in_combat(hero_id: String) -> Dictionary:
	## Calculates and returns the combat effect of using this hero's active skill.
	## Returns { "type": str, "value": float, "buff_type": str, "duration": int, "desc": str }
	## Caller is responsible for applying the effect to combat state.
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	var skill_name: String = hero_data.get("active", "")
	var skill_def: Dictionary = FactionData.HERO_SKILL_DEFS.get(skill_name, {})
	if skill_def.is_empty():
		return {}

	var hero_int: int = hero_data.get("int", 5)
	# Affection bonus: +10% skill power per 5 affection
	var aff: int = hero_affection.get(hero_id, 0)
	var aff_mult: float = 1.0 + float(aff / 5) * 0.1

	var skill_type: String = skill_def.get("type", "damage")
	var base_power: float = skill_def.get("power", 0)
	var int_scale: float = skill_def.get("int_scale", 0.0)
	var effective_value: float = (base_power + float(hero_int) * int_scale) * aff_mult

	# Put skill on cooldown
	use_skill(hero_id)

	var hero_name: String = hero_data.get("name", hero_id)
	match skill_type:
		"damage", "aoe":
			return {"type": skill_type, "value": effective_value,
				"desc": "%s 使用 [%s]: 造成 %.0f 伤害!" % [hero_name, skill_name, effective_value]}
		"heal":
			var heal_amount: int = int(effective_value)
			return {"type": "heal", "value": heal_amount,
				"desc": "%s 使用 [%s]: 恢复 %d 兵力!" % [hero_name, skill_name, heal_amount]}
		"buff":
			var buff_type: String = skill_def.get("buff_type", "atk_mult")
			var duration: int = skill_def.get("duration", 1)
			return {"type": "buff", "value": effective_value, "buff_type": buff_type,
				"duration": duration,
				"desc": "%s 使用 [%s]: 全军增益 +%.0f%%(%d回合)!" % [hero_name, skill_name, effective_value * 100, duration]}
		"debuff":
			var buff_type: String = skill_def.get("buff_type", "atk_mult")
			var duration: int = skill_def.get("duration", 1)
			return {"type": "debuff", "value": effective_value, "buff_type": buff_type,
				"duration": duration,
				"desc": "%s 使用 [%s]: 削弱敌军 -%.0f%%(%d回合)!" % [hero_name, skill_name, effective_value * 100, duration]}
		"summon":
			var summon_count: int = int(effective_value)
			return {"type": "summon", "value": summon_count,
				"desc": "%s 使用 [%s]: 召唤 %d 骷髅兵增援!" % [hero_name, skill_name, summon_count]}

	return {}


# ═══════════════ SERIALIZATION ═══════════════

func to_save_data() -> Dictionary:
	return {
		"captured_heroes": captured_heroes.duplicate(),
		"recruited_heroes": recruited_heroes.duplicate(),
		"hero_corruption": hero_corruption.duplicate(),
		"hero_affection": hero_affection.duplicate(),
		"hero_equipment": hero_equipment.duplicate(true),
		"skill_cooldowns": _skill_cooldowns.duplicate(),
	}


func from_save_data(data: Dictionary) -> void:
	captured_heroes = data.get("captured_heroes", [])
	recruited_heroes = data.get("recruited_heroes", [])
	hero_corruption = data.get("hero_corruption", {})
	hero_affection = data.get("hero_affection", {})
	hero_equipment = data.get("hero_equipment", {}).duplicate(true)
	_skill_cooldowns = data.get("skill_cooldowns", {})


# ═══════════════ INTERNAL ═══════════════

func _unlock_second_skill(hero_id: String) -> void:
	## At affection 7, unlock the hero's second active skill.
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	var second_skill: String = hero_data.get("active_2", "")
	if second_skill != "":
		EventBus.message_log.emit("[技能] %s 解锁技能: %s" % [_get_hero_name(hero_id), second_skill])


func _get_hero_name(hero_id: String) -> String:
	return FactionData.HEROES.get(hero_id, {}).get("name", hero_id)
