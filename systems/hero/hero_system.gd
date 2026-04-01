## hero_system.gd - Hero capture, prison, recruitment, affection, equipment, and active skills (v0.9.0)
## Uses v0.8.1 API: ResourceManager, ThreatManager, GameManager.get_human_player_id()
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")
const HeroLevelData = preload("res://systems/hero/hero_level_data.gd")

# ── State (per-session, will be serialized by save system) ──
var captured_heroes: Array = []        # hero_id strings in prison
var recruited_heroes: Array = []       # hero_id strings recruited
var hero_corruption: Dictionary = {}   # hero_id -> int (prison corruption counter)
var hero_affection: Dictionary = {}    # hero_id -> int (0-10)

# ── Equipment state (v0.8.7) ──
# hero_id -> equip_id (String, "" if empty) — SR07-style single item slot per hero
var hero_equipment: Dictionary = {}

# ── Territory Commander (SR07 garrison commander) ──
var stationed_heroes: Dictionary = {}  # tile_index -> hero_id (SR07 garrison commander)
var hero_stations: Dictionary = {}     # hero_id -> tile_index (reverse lookup)

# ── Active skill cooldowns (v0.9.0) ──
# hero_id -> int (remaining cooldown turns, 0 = ready)
var _skill_cooldowns: Dictionary = {}

# ── Pirate Harem System (v2.0 → Lance 07 rework) ──
var hero_submission: Dictionary = {}       # hero_id -> int (服从度, uncapped)
var _pirate_mode: bool = false             # true if player is pirate faction
var _harem_cooldowns: Dictionary = {}      # hero_id -> {train: int, bed: int}
var _harem_unlocked: Dictionary = {}       # hero_id -> bool (final story completed)


# ── Unlocked second active skills (好感度7解锁) ──
# hero_id -> skill_name string
var _second_skills: Dictionary = {}

# ── Gift cooldowns (per hero, 1/turn) ──
var _gift_cooldowns: Dictionary = {}  # hero_id -> int (remaining turns)

# ── Hidden Heroes (秘密英雄) state ──
var _discovered_hidden_heroes: Array = []     # hero_id strings already discovered
var _hidden_hero_notifications: Array = []    # pending reveal notifications
var _battles_won_count: int = 0               # total battles won (for iron_general unlock)
var _hidden_hero_data: Dictionary = {}        # hero_id -> hero data dict (runtime registry)
var _hero_stat_bonuses: Dictionary = {}       # hero_id -> {stat_key: int} permanent bonuses from events

# ── Exiled Heroes (流放后归还计时) ──
var _exiled_heroes: Dictionary = {}           # hero_id -> int (remaining turns until return to enemy pool)

# ── SR07-style Recruitment Events ──
var _recruitment_event_cooldown: int = 0      # turns remaining before next recruitment event can fire
var _recruitment_event_counter: int = 0       # unique event ID counter
var _mercenary_loyalty: Dictionary = {}       # hero_id -> int (remaining loyalty turns)
var _wandering_hero_pool: Array = []          # hero_ids that were rejected and may return later


func reset() -> void:
	captured_heroes.clear()
	recruited_heroes.clear()
	hero_corruption.clear()
	hero_affection.clear()
	hero_equipment.clear()
	stationed_heroes.clear()
	hero_stations.clear()
	_skill_cooldowns.clear()
	hero_submission.clear()
	_pirate_mode = false
	_harem_cooldowns.clear()
	_harem_unlocked.clear()
	_capture_in_progress.clear()
	_second_skills.clear()
	_gift_cooldowns.clear()
	_discovered_hidden_heroes.clear()
	_hidden_hero_notifications.clear()
	_battles_won_count = 0
	_hidden_hero_data.clear()
	_hero_stat_bonuses.clear()
	_exiled_heroes.clear()
	_recruitment_event_cooldown = 0
	_recruitment_event_counter = 0
	_mercenary_loyalty.clear()
	_wandering_hero_pool.clear()


## Called when pirate faction is selected. Enables harem mechanics.
func init_pirate_mode() -> void:
	_pirate_mode = true


func is_pirate_mode() -> bool:
	return _pirate_mode


# ═══════════════ CAPTURE ═══════════════

## Attempt to capture a hero after battle (called by combat resolution)
var _capture_in_progress: Dictionary = {}  # hero_id -> true (guard against double capture)
func attempt_capture(hero_id: String, capture_chance: float = -1.0) -> bool:
	if _capture_in_progress.get(hero_id, false):
		return false
	if hero_id in captured_heroes or hero_id in recruited_heroes:
		_capture_in_progress.erase(hero_id)
		return false
	_capture_in_progress[hero_id] = true
	var max_prison: int = FactionData.PIRATE_PRISON_CAPACITY if _pirate_mode else FactionData.PRISON_CAPACITY
	if captured_heroes.size() >= max_prison:
		_capture_in_progress.erase(hero_id)
		return false
	# Use hero's default capture chance if not overridden
	if capture_chance < 0.0:
		var hero_data: Dictionary = _get_hero_data(hero_id)
		capture_chance = hero_data.get("capture_chance", 0.5)
	# Pirate capture bonus
	if _pirate_mode:
		capture_chance = minf(capture_chance + FactionData.PIRATE_CAPTURE_BONUS, 1.0)
	# v4.4: Equipment capture_bonus — any recruited hero with slave_shackle_equip
	for hid in recruited_heroes:
		if has_equipment_passive(hid, "capture_bonus"):
			capture_chance = minf(capture_chance + get_equipment_passive_value(hid, "capture_bonus"), 1.0)
			break  # Only apply once
	if randf() <= capture_chance:
		captured_heroes.append(hero_id)
		hero_corruption[hero_id] = 0
		_capture_in_progress.erase(hero_id)
		EventBus.hero_captured.emit(hero_id)
		EventBus.message_log.emit("捕获英雄: %s" % _get_hero_name(hero_id))
		# 03_战略设定: 俘英雄+20威胁
		ThreatManager.on_hero_captured()
		return true
	_capture_in_progress.erase(hero_id)
	return false


# ═══════════════ PRISON ═══════════════

## Process prison each turn: increase corruption
func process_prison_turn() -> void:
	for hero_id in captured_heroes:
		var increment: int = 1
		if _pirate_mode:
			increment = ceili(float(increment) * FactionData.PIRATE_CORRUPTION_SPEED)
		hero_corruption[hero_id] = mini(hero_corruption.get(hero_id, 0) + increment, 100)
	# Also tick exile return timers
	process_exile_turn()


## Attempt to recruit a captured hero
func attempt_recruit(hero_id: String) -> Dictionary:
	if hero_id not in captured_heroes:
		return {"ok": false, "reason": "未被俘虏"}
	var corruption: int = hero_corruption.get(hero_id, 0)
	if corruption < FactionData.CORRUPTION_TO_RECRUIT:
		# 提供明确的招募条件提示，包含当前进度和所需值
		var remaining: int = FactionData.CORRUPTION_TO_RECRUIT - corruption
		return {
			"ok": false,
			"reason": "腐化不足 (%d/%d)" % [corruption, FactionData.CORRUPTION_TO_RECRUIT],
			"hint": "需要继续关押 %d 回合以达到腐化要求 (%d/%d)。腐化每回合+1，当前还差 %d 点。" % [
				remaining, corruption, FactionData.CORRUPTION_TO_RECRUIT, remaining],
		}
	# 50% base success, +10% per corruption above threshold
	var success_chance: float = 0.5 + (corruption - FactionData.CORRUPTION_TO_RECRUIT) * 0.1
	if randf() <= success_chance:
		captured_heroes.erase(hero_id)
		recruited_heroes.append(hero_id)
		hero_affection[hero_id] = 0
		hero_corruption.erase(hero_id)
		HeroLeveling.init_hero(hero_id)
		EventBus.hero_recruited.emit(hero_id)
		EventBus.message_log.emit("招募英雄: %s" % _get_hero_name(hero_id))
		return {"ok": true, "reason": "招募成功"}
	return {"ok": false, "reason": "招募失败（抵抗）", "hint": "招募被抵抗，可继续关押提高腐化值以增加成功率。当前成功率约 %d%%。" % int(success_chance * 100)}


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


## Execute a prisoner permanently. +threat, -faction reputation, +prestige (SR07 処刑)
func execute_prisoner(hero_id: String) -> bool:
	if hero_id not in captured_heroes:
		return false
	var hero_data: Dictionary = _get_hero_data(hero_id)
	var hero_name: String = _get_hero_name(hero_id)
	var faction_key: String = hero_data.get("faction", "")

	captured_heroes.erase(hero_id)
	hero_corruption.erase(hero_id)

	# Threat gain
	ThreatManager.change_threat(BalanceConfig.EXECUTE_THREAT_GAIN)
	# Reputation penalty with hero's faction
	if faction_key != "":
		DiplomacyManager.change_reputation(faction_key, BalanceConfig.EXECUTE_REP_PENALTY)
	# Prestige gain
	var pid: int = GameManager.get_human_player_id()
	ResourceManager.apply_delta(pid, {"prestige": BalanceConfig.EXECUTE_PRESTIGE_GAIN})

	EventBus.hero_executed.emit(hero_id)
	EventBus.message_log.emit("[color=red]処刑英雄: %s (威胁+%d, %s声望%d, 威望+%d)[/color]" % [
		hero_name, BalanceConfig.EXECUTE_THREAT_GAIN, faction_key,
		BalanceConfig.EXECUTE_REP_PENALTY, BalanceConfig.EXECUTE_PRESTIGE_GAIN])
	return true


## Ransom a prisoner back to their faction for gold. +reputation (SR07 身代金)
func ransom_prisoner(hero_id: String) -> bool:
	if hero_id not in captured_heroes:
		return false
	var hero_data: Dictionary = _get_hero_data(hero_id)
	var hero_name: String = _get_hero_name(hero_id)
	var faction_key: String = hero_data.get("faction", "")

	# Gold reward = hero_level * per_level + base
	var hero_level: int = HeroLeveling.get_hero_level(hero_id) if HeroLeveling.has_method("get_hero_level") else 1
	var gold_reward: int = hero_level * BalanceConfig.RANSOM_GOLD_PER_LEVEL + BalanceConfig.RANSOM_GOLD_BASE

	captured_heroes.erase(hero_id)
	hero_corruption.erase(hero_id)

	var pid: int = GameManager.get_human_player_id()
	ResourceManager.apply_delta(pid, {"gold": gold_reward})
	# Reputation bonus with hero's faction
	if faction_key != "":
		DiplomacyManager.change_reputation(faction_key, BalanceConfig.RANSOM_REP_BONUS)

	EventBus.hero_ransomed.emit(hero_id)
	EventBus.message_log.emit("[color=yellow]身代金: %s を身代金で解放 (金+%d, %s声望+%d)[/color]" % [
		hero_name, gold_reward, faction_key, BalanceConfig.RANSOM_REP_BONUS])
	return true


## Exile a prisoner. No reward, -threat, hero returns to enemy pool after N turns (SR07 追放)
func exile_prisoner(hero_id: String) -> bool:
	if hero_id not in captured_heroes:
		return false
	var hero_name: String = _get_hero_name(hero_id)

	captured_heroes.erase(hero_id)
	hero_corruption.erase(hero_id)

	# Threat reduction
	ThreatManager.change_threat(-BalanceConfig.EXILE_THREAT_REDUCTION)
	# Track exile return timer
	_exiled_heroes[hero_id] = BalanceConfig.EXILE_RETURN_TURNS

	EventBus.hero_exiled.emit(hero_id)
	EventBus.message_log.emit("追放英雄: %s (威胁-%d, %d回合後帰還敵陣営)" % [
		hero_name, BalanceConfig.EXILE_THREAT_REDUCTION, BalanceConfig.EXILE_RETURN_TURNS])
	return true


## Process exiled heroes each turn: decrement return timer, return to enemy pool when done.
func process_exile_turn() -> void:
	var returned: Array = []
	for hero_id in _exiled_heroes.keys():
		_exiled_heroes[hero_id] -= 1
		if _exiled_heroes[hero_id] <= 0:
			returned.append(hero_id)
	for hero_id in returned:
		_exiled_heroes.erase(hero_id)
		EventBus.message_log.emit("[color=gray]追放された %s が敵陣営に帰還した[/color]" % _get_hero_name(hero_id))


## Interrogate a captured hero for resources/intel (消耗1AP, Rance 07 尋問)
## Returns: { "ok": bool, "result": String, "rewards": Dictionary }
func interrogate_hero(hero_id: String) -> Dictionary:
	if hero_id not in captured_heroes:
		return {"ok": false, "result": "未被俘虏"}
	var hero_data: Dictionary = _get_hero_data(hero_id)
	var corruption: int = hero_corruption.get(hero_id, 0)

	# Interrogation outcomes based on corruption level
	var rewards: Dictionary = {}
	var result_text: String = ""
	var roll: float = randf()

	if corruption < 20:
		# Low corruption — hero resists, small reward
		if roll < 0.4:
			rewards = {"gold": randi_range(10, 30)}
			result_text = "%s 勉强透露了一些情报 (金+%d)" % [_get_hero_name(hero_id), rewards["gold"]]
		elif roll < 0.7:
			result_text = "%s 紧咬牙关,什么都不说" % _get_hero_name(hero_id)
		else:
			# Backfire: hero gets defiant, corruption -5
			hero_corruption[hero_id] = maxi(corruption - 5, 0)
			result_text = "[color=red]%s 顽强抵抗! 意志反而更坚定了 (腐化-5)[/color]" % _get_hero_name(hero_id)
	elif corruption < 50:
		# Medium corruption — decent chance of intel
		if roll < 0.3:
			rewards = {"gold": randi_range(20, 50), "iron": randi_range(5, 15)}
			result_text = "%s 供出了资源藏匿点 (金+%d, 铁+%d)" % [_get_hero_name(hero_id), rewards["gold"], rewards["iron"]]
		elif roll < 0.6:
			# Intel: reveal a random hidden tile
			rewards = {"reveal_tiles": 2}
			result_text = "%s 透露了敌方据点信息 (揭示2个区域)" % _get_hero_name(hero_id)
		elif roll < 0.85:
			rewards = {"prestige": randi_range(2, 5)}
			result_text = "%s 供认了战略情报 (威望+%d)" % [_get_hero_name(hero_id), rewards["prestige"]]
		else:
			result_text = "%s 尝试误导你的审讯" % _get_hero_name(hero_id)
	else:
		# High corruption — hero is broken, always gives something
		if roll < 0.35:
			rewards = {"gold": randi_range(40, 80), "food": randi_range(20, 40)}
			result_text = "%s 全盘招供: 资源坐标 (金+%d, 粮+%d)" % [_get_hero_name(hero_id), rewards["gold"], rewards["food"]]
		elif roll < 0.65:
			rewards = {"soldiers": randi_range(3, 8)}
			result_text = "%s 说服部下投降 (+%d兵)" % [_get_hero_name(hero_id), rewards["soldiers"]]
		else:
			rewards = {"prestige": randi_range(3, 8), "gold": randi_range(20, 40)}
			result_text = "%s 已完全屈服, 提供一切情报 (威望+%d, 金+%d)" % [_get_hero_name(hero_id), rewards["prestige"], rewards["gold"]]

	# Interrogation always increases corruption slightly (+3)
	hero_corruption[hero_id] = mini(corruption + 3, 100)

	EventBus.message_log.emit("[尋問] " + result_text)
	return {"ok": true, "result": result_text, "rewards": rewards}


# ═══════════════ AFFECTION ═══════════════

## Add affection after shared battle
func add_affection(hero_id: String, amount: int = 1) -> void:
	if hero_id not in recruited_heroes:
		return
	var old_val: int = hero_affection.get(hero_id, 0)
	var new_val: int = clampi(old_val + amount, 0, FactionData.AFFECTION_MAX)
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


## Universal affection stat bonuses (all factions).
## Returns {atk_pct, def_pct, all_pct, loyal, title, tier_desc} based on affection level.
func get_affection_bonus(hero_id: String) -> Dictionary:
	var aff: int = hero_affection.get(hero_id, 0)
	var bonus := {
		"atk_pct": 0.0,
		"def_pct": 0.0,
		"all_pct": 0.0,
		"loyal": false,
		"second_skill": false,
		"title": "",
		"tier_desc": "",
	}
	if aff >= 3:
		bonus["atk_pct"] = 0.05
		bonus["tier_desc"] = "ATK+5%"
	if aff >= 5:
		bonus["def_pct"] = 0.05
		bonus["loyal"] = true
		bonus["tier_desc"] = "ATK+5%, DEF+5%, Loyal"
	if aff >= 7:
		bonus["second_skill"] = true
		bonus["tier_desc"] = "ATK+5%, DEF+5%, Loyal, 2nd Skill"
	if aff >= 10:
		bonus["all_pct"] = 0.10
		bonus["title"] = "Sworn Companion"
		bonus["tier_desc"] = "All Stats+10%, Sworn Companion"
	return bonus


## Apply affection-based percentage bonuses to a combat stats dictionary.
## Modifies atk, def, spd, int_stat, hp, mp keys in-place and returns the result.
func apply_affection_combat_bonus(hero_id: String, stats: Dictionary) -> Dictionary:
	var bonus: Dictionary = get_affection_bonus(hero_id)
	var atk_mult: float = 1.0 + bonus["atk_pct"] + bonus["all_pct"]
	var def_mult: float = 1.0 + bonus["def_pct"] + bonus["all_pct"]
	var other_mult: float = 1.0 + bonus["all_pct"]
	if atk_mult != 1.0 and stats.has("atk"):
		stats["atk"] = int(float(stats["atk"]) * atk_mult)
	if def_mult != 1.0 and stats.has("def"):
		stats["def"] = int(float(stats["def"]) * def_mult)
	if other_mult != 1.0:
		if stats.has("spd"):
			stats["spd"] = int(float(stats["spd"]) * other_mult)
		if stats.has("int_stat"):
			stats["int_stat"] = int(float(stats["int_stat"]) * other_mult)
		if stats.has("hp"):
			stats["hp"] = int(float(stats["hp"]) * other_mult)
		if stats.has("mp"):
			stats["mp"] = int(float(stats["mp"]) * other_mult)
	return stats


# ═══════════════ PUBLIC API (hero_panel.gd) ═══════════════

func get_recruited_heroes(_player_id: int) -> Array:
	## Returns array of hero_id strings recruited by this player.
	## Note: In current single-player design, all recruited heroes belong to the human player.
	## The _player_id parameter is kept for API compatibility.
	var result: Array = []
	for hid in recruited_heroes:
		var hero: Dictionary = _get_hero_data(hid)
		if not hero.is_empty():
			result.append(hid)
	return result


func get_prison_heroes(_player_id: int) -> Array:
	## Returns array of hero_id strings currently in prison.
	var result: Array = []
	for hid in captured_heroes:
		if not hid in recruited_heroes:
			result.append(hid)
	return result


func get_affection(hero_id: String) -> int:
	return hero_affection.get(hero_id, 0)


func get_corruption(hero_id: String) -> int:
	return hero_corruption.get(hero_id, 0)


func can_recruit(hero_id: String) -> bool:
	## Check if hero meets recruitment criteria.
	if hero_id in recruited_heroes:
		return false
	if hero_id not in captured_heroes:
		return false
	var corruption: int = hero_corruption.get(hero_id, 0)
	return corruption >= FactionData.CORRUPTION_TO_RECRUIT


func increase_affection(hero_id: String, amount: int) -> void:
	add_affection(hero_id, amount)


func recruit_hero(hero_id: String) -> bool:
	var result: Dictionary = attempt_recruit(hero_id)
	return result.get("ok", false)


# ═══════════════ COMBAT STATS ═══════════════

## Get hero battle stats (commander stats for combat system)
func get_hero_combat_stats(hero_id: String) -> Dictionary:
	var hero_data: Dictionary = _get_hero_data(hero_id)
	if hero_data.is_empty():
		push_warning("HeroSystem: get_hero_combat_stats called with unknown hero_id='%s'" % hero_id)
		return {}

	# Get level-scaled base stats from HeroLeveling autoload
	var leveled: Dictionary = HeroLeveling.get_hero_stats(hero_id)

	# Equipment stat bonuses (v0.8.7)
	var equip_stats: Dictionary = get_equipment_stat_totals(hero_id)

	var result := {
		"name": hero_data.get("name", hero_id),
		"troop": hero_data.get("troop", ""),
		"atk": leveled.get("atk", hero_data.get("atk", 0)) + equip_stats.get("atk", 0),
		"def": leveled.get("def", hero_data.get("def", 0)) + equip_stats.get("def", 0),
		"int_stat": leveled.get("int_stat", hero_data.get("int", 0)) + equip_stats.get("int_stat", 0),
		"spd": leveled.get("spd", hero_data.get("spd", 0)) + equip_stats.get("spd", 0),
		"hp": leveled.get("hp", hero_data.get("base_hp", 20)),
		"mp": leveled.get("mp", hero_data.get("base_mp", 10)),
		"level": leveled.get("level", 1),
		"active": hero_data.get("active", ""),
		"active_2": _second_skills.get(hero_id, ""),  # 好感度7解锁的第二主动技能
		"passive": hero_data.get("passive", ""),
		"level_passives": HeroLeveling.get_unlocked_passives(hero_id),
		"equipment_passives": get_equipment_passives(hero_id),
	}

	# Apply universal affection percentage bonuses (all factions)
	result = apply_affection_combat_bonus(hero_id, result)

	return result


## Get all recruited heroes as a list of combat-ready data
func get_available_heroes() -> Array:
	var result := []
	for hero_id in recruited_heroes:
		var stats: Dictionary = get_hero_combat_stats(hero_id)
		if not stats.is_empty():
			stats["id"] = hero_id
			result.append(stats)
	return result


## Get heroes belonging to a specific player (heroes are human-player only)
func get_heroes_for_player(player_id: int) -> Array:
	if player_id != GameManager.get_human_player_id():
		return []
	return get_available_heroes()


# ═══════════════ EQUIPMENT (v0.8.7) ═══════════════

func _ensure_equip_slots(hero_id: String) -> void:
	if not hero_equipment.has(hero_id):
		hero_equipment[hero_id] = ""


func equip_item(hero_id: String, equip_id: String) -> Dictionary:
	## Equip an item on a hero (1 slot per hero, SR07-style).
	if hero_id not in recruited_heroes:
		return {"ok": false, "reason": "英雄未招募"}
	if not FactionData.EQUIPMENT_DEFS.has(equip_id):
		return {"ok": false, "reason": "装备不存在"}
	var pid: int = GameManager.get_human_player_id()
	if not ItemManager.has_item(pid, equip_id):
		return {"ok": false, "reason": "背包中无此装备"}

	_ensure_equip_slots(hero_id)
	var old_equip: String = hero_equipment[hero_id]

	# Remove from inventory
	ItemManager.remove_item(pid, equip_id)

	# Return old equipment to inventory if slot was occupied
	if old_equip != "":
		ItemManager.add_item(pid, old_equip)

	hero_equipment[hero_id] = equip_id
	var equip_data: Dictionary = FactionData.EQUIPMENT_DEFS[equip_id]
	EventBus.message_log.emit("%s 装备了 %s" % [_get_hero_name(hero_id), equip_data["name"]])
	return {"ok": true, "reason": "装备成功", "unequipped_id": old_equip}


func unequip_item(hero_id: String, _slot_key: String = "") -> Dictionary:
	## Unequip the item from a hero. _slot_key kept for API compat but ignored.
	if hero_id not in recruited_heroes:
		return {"ok": false, "reason": "英雄未招募"}
	_ensure_equip_slots(hero_id)
	var equip_id: String = hero_equipment[hero_id]
	if equip_id == "":
		return {"ok": false, "reason": "该英雄无装备"}

	var pid: int = GameManager.get_human_player_id()
	if ItemManager.is_full(pid):
		return {"ok": false, "reason": "背包已满, 无法卸下装备"}

	hero_equipment[hero_id] = ""
	ItemManager.add_item(pid, equip_id)
	var equip_data: Dictionary = FactionData.EQUIPMENT_DEFS.get(equip_id, {})
	EventBus.message_log.emit("%s 卸下了 %s" % [_get_hero_name(hero_id), equip_data.get("name", equip_id)])
	return {"ok": true, "reason": "卸下成功", "equip_id": equip_id}


func get_hero_equipment(hero_id: String) -> Dictionary:
	## Returns {"item": equip_id} for SR07 compat. Legacy callers still work.
	_ensure_equip_slots(hero_id)
	return {"item": hero_equipment[hero_id]}


func get_hero_equipment_details(hero_id: String) -> Array:
	## Returns array with single equipped item detail dict for UI display.
	_ensure_equip_slots(hero_id)
	var equip_id: String = hero_equipment[hero_id]
	if equip_id != "" and FactionData.EQUIPMENT_DEFS.has(equip_id):
		var data: Dictionary = FactionData.EQUIPMENT_DEFS[equip_id].duplicate()
		data["equip_id"] = equip_id
		data["slot_key"] = "item"
		return [data]
	return [{"equip_id": "", "slot_key": "item", "name": "空", "desc": ""}]


func get_equipment_stat_totals(hero_id: String) -> Dictionary:
	## Get stat bonuses from the hero's equipped item.
	var totals := {"atk": 0, "def": 0, "spd": 0, "int_stat": 0}
	_ensure_equip_slots(hero_id)
	var equip_id: String = hero_equipment[hero_id]
	if equip_id == "":
		return totals
	var data: Dictionary = FactionData.EQUIPMENT_DEFS.get(equip_id, {})
	var stats: Dictionary = data.get("stats", {})
	for key in stats:
		totals[key] = totals.get(key, 0) + stats[key]
	return totals


func get_equipment_passives(hero_id: String) -> Array:
	## Returns array of passive strings from equipped item.
	_ensure_equip_slots(hero_id)
	var equip_id: String = hero_equipment[hero_id]
	if equip_id == "":
		return []
	var data: Dictionary = FactionData.EQUIPMENT_DEFS.get(equip_id, {})
	var passive: String = data.get("passive", "none")
	if passive != "none":
		return [passive]
	return []


func has_equipment_passive(hero_id: String, passive_name: String) -> bool:
	return passive_name in get_equipment_passives(hero_id)


func get_equipment_passive_value(hero_id: String, passive_name: String) -> float:
	## Get the value of a specific equipment passive.
	_ensure_equip_slots(hero_id)
	var equip_id: String = hero_equipment[hero_id]
	if equip_id == "":
		return 0.0
	var data: Dictionary = FactionData.EQUIPMENT_DEFS.get(equip_id, {})
	if data.get("passive", "none") == passive_name:
		return data.get("passive_value", 0.0)
	return 0.0


# ═══════════════ TERRITORY COMMANDER (SR07) ═══════════════

func station_hero(hero_id: String, tile_index: int) -> bool:
	## Assign a hero as garrison commander to a territory.
	if hero_id not in recruited_heroes:
		return false
	# Can't station a hero that's in an army
	for army in GameManager.armies.values():
		if hero_id in army.get("heroes", []):
			return false
	# Remove from previous station if any
	unstation_hero_by_id(hero_id)
	# Remove existing commander at this tile
	if stationed_heroes.has(tile_index):
		var old_hero: String = stationed_heroes[tile_index]
		hero_stations.erase(old_hero)
	stationed_heroes[tile_index] = hero_id
	hero_stations[hero_id] = tile_index
	EventBus.hero_stationed.emit(hero_id, tile_index)
	return true


func unstation_hero(tile_index: int) -> String:
	## Remove garrison commander from a territory. Returns hero_id or "".
	if not stationed_heroes.has(tile_index):
		return ""
	var hero_id: String = stationed_heroes[tile_index]
	stationed_heroes.erase(tile_index)
	hero_stations.erase(hero_id)
	EventBus.hero_unstationed.emit(hero_id, tile_index)
	return hero_id


func unstation_hero_by_id(hero_id: String) -> void:
	## Remove a hero from their stationed territory.
	if hero_stations.has(hero_id):
		var tile_idx: int = hero_stations[hero_id]
		stationed_heroes.erase(tile_idx)
		hero_stations.erase(hero_id)


func get_stationed_hero(tile_index: int) -> String:
	## Get the hero_id stationed at a tile, or "" if none.
	return stationed_heroes.get(tile_index, "")


func get_hero_station(hero_id: String) -> int:
	## Get the tile_index where a hero is stationed, or -1 if not stationed.
	return hero_stations.get(hero_id, -1)


func is_hero_stationed(hero_id: String) -> bool:
	return hero_stations.has(hero_id)


func is_hero_available(hero_id: String) -> bool:
	## Check if hero is free (not in army, not stationed, not captured).
	if hero_id not in recruited_heroes:
		return false
	if hero_stations.has(hero_id):
		return false
	for army in GameManager.armies.values():
		if hero_id in army.get("heroes", []):
			return false
	return true


func get_garrison_commander_bonus(tile_index: int) -> Dictionary:
	## Returns stat bonuses from the garrison commander at a tile.
	var hero_id: String = get_stationed_hero(tile_index)
	if hero_id == "":
		return {"def_mult": 1.0, "prod_mult": 1.0, "order_bonus": 0, "garrison_add": 0}
	var stats: Dictionary = get_hero_combat_stats(hero_id)
	return {
		"def_mult": 1.25,           # +25% garrison DEF
		"prod_mult": 1.15,          # +15% territory production
		"order_bonus": 10,           # +10 public order per turn
		"garrison_add": maxi(int(stats.get("atk", 0)) / 3, 1),  # ATK/3 extra garrison
		"hero_name": _get_hero_name(hero_id),
	}


# ═══════════════ ACTIVE SKILLS (v0.9.0) ═══════════════

func tick_cooldowns() -> void:
	## Called each turn. Decrements all skill cooldowns by 1.
	for hero_id in _skill_cooldowns:
		if _skill_cooldowns[hero_id] > 0:
			_skill_cooldowns[hero_id] -= 1


func tick_harem_cooldowns() -> void:
	## Called each turn for the human player. Decrements harem action cooldowns.
	for hero_id in _harem_cooldowns:
		var cd: Dictionary = _harem_cooldowns[hero_id]
		if cd.get("train", 0) > 0:
			cd["train"] -= 1
		if cd.get("bed", 0) > 0:
			cd["bed"] -= 1

func get_skill_cooldown(hero_id: String) -> int:
	return _skill_cooldowns.get(hero_id, 0)


func is_skill_ready(hero_id: String) -> bool:
	return hero_id in recruited_heroes and get_skill_cooldown(hero_id) <= 0


func use_skill(hero_id: String) -> void:
	## Mark a skill as used, putting it on cooldown.
	var hero_data: Dictionary = _get_hero_data(hero_id)
	var skill_name: String = hero_data.get("active", "")
	var skill_def: Dictionary = FactionData.HERO_SKILL_DEFS.get(skill_name, {})
	var cooldown: int = skill_def.get("cooldown", 3)
	_skill_cooldowns[hero_id] = cooldown


func get_hero_skill_data(hero_id: String) -> Dictionary:
	## Returns full skill data for a recruited hero, including readiness.
	var hero_data: Dictionary = _get_hero_data(hero_id)
	var skill_name: String = hero_data.get("active", "")
	if skill_name == "":
		return {}
	var skill_def: Dictionary = FactionData.HERO_SKILL_DEFS.get(skill_name, {})
	if skill_def.is_empty():
		push_warning("HeroSystem: get_hero_skill_data unknown skill '%s' for hero '%s'" % [skill_name, hero_id])
		return {}
	var result: Dictionary = skill_def.duplicate()
	result["name"] = skill_name
	result["hero_id"] = hero_id
	result["hero_name"] = hero_data.get("name", hero_id)
	result["hero_int"] = HeroLeveling.get_hero_stats(hero_id).get("int_stat", hero_data.get("int", 5))
	result["ready"] = is_skill_ready(hero_id)
	result["cooldown_remaining"] = get_skill_cooldown(hero_id)
	# Calculate effective power
	var base_power: float = skill_def.get("power", 0)
	var int_scale: float = skill_def.get("int_scale", 0.0)
	result["effective_power"] = base_power + float(HeroLeveling.get_hero_stats(hero_id).get("int_stat", hero_data.get("int", 5))) * int_scale
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
	var hero_data: Dictionary = _get_hero_data(hero_id)
	var skill_name: String = hero_data.get("active", "")
	var skill_def: Dictionary = FactionData.HERO_SKILL_DEFS.get(skill_name, {})
	if skill_def.is_empty():
		return {}

	var hero_int: int = HeroLeveling.get_hero_stats(hero_id).get("int_stat", hero_data.get("int", 5))
	# Affection bonus: +10% skill power per 5 affection
	var aff: int = hero_affection.get(hero_id, 0)
	var aff_mult: float = 1.0 + float(aff) / 5.0 * 0.1

	var skill_type: String = skill_def.get("type", "damage")
	var base_power: float = skill_def.get("power", 0)
	var int_scale: float = skill_def.get("int_scale", 0.0)
	var effective_value: float = (base_power + float(hero_int) * int_scale) * aff_mult

	# v4.5: spell_damage_bonus / spell_power_bonus — equipment passives boost skill damage
	if has_equipment_passive(hero_id, "spell_damage_bonus"):
		effective_value *= 1.2  # +20% spell damage
	if has_equipment_passive(hero_id, "spell_power_bonus"):
		effective_value *= 1.15  # +15% spell power

	# Put skill on cooldown
	use_skill(hero_id)

	var hero_name: String = hero_data.get("name", hero_id)
	match skill_type:
		"damage", "aoe":
			return {"type": skill_type, "value": effective_value,
				"desc": "%s 使用 [%s]: 造成 %.0f 伤害!" % [hero_name, skill_name, effective_value]}
		"heal":
			var heal_amount: int = int(effective_value)
			# v4.6: heal_bonus — +30% healing from equipment passive
			if has_equipment_passive(hero_id, "heal_bonus"):
				heal_amount = int(float(heal_amount) * 1.3)
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

	push_warning("HeroSystem: apply_skill_in_combat unhandled skill_type='%s' for hero='%s'" % [skill_type, hero_id])
	return {}


# ═══════════════ PIRATE HAREM SYSTEM (海盗后宫) ═══════════════

## 获取角色服从度 (uncapped — train caps at 5, bed pushes beyond)
func get_submission(hero_id: String) -> int:
	return hero_submission.get(hero_id, 0)


## 调教 — costs 1 AP, 3-turn cooldown, caps submission at 5.
func train_heroine(hero_id: String) -> Dictionary:
	var pid: int = GameManager.get_human_player_id()
	var player: Dictionary = GameManager.get_player_by_id(pid)
	if player.is_empty():
		return {"success": false, "reason": "无效玩家"}
	if hero_id not in recruited_heroes:
		return {"success": false, "reason": "英雄未招募"}
	# Check AP
	if player.get("ap", 0) < 1:
		return {"success": false, "reason": "行动力不足"}
	# Check cooldown
	var cd: Dictionary = _harem_cooldowns.get(hero_id, {"train": 0, "bed": 0})
	if cd["train"] > 0:
		return {"success": false, "reason": "冷却中 (剩余%d回合)" % cd["train"]}
	# Check submission cap for training
	var current_sub: int = hero_submission.get(hero_id, 0)
	if current_sub >= 5:
		return {"success": false, "reason": "调教无法再提升服从度 (需要侍寝)"}
	# Execute
	player["ap"] -= 1
	hero_submission[hero_id] = mini(current_sub + 1, 5)
	cd["train"] = 3  # 3-turn cooldown
	_harem_cooldowns[hero_id] = cd
	EventBus.heroine_submission_changed.emit(hero_id, hero_submission[hero_id])
	if hero_submission.get(hero_id, 0) >= FactionData.HAREM_VICTORY_SUBMISSION_MIN:
		_harem_unlocked[hero_id] = true
	EventBus.message_log.emit("[color=pink]%s 的调教完成，服从度 %d/10+[/color]" % [_get_hero_name(hero_id), hero_submission[hero_id]])
	_check_harem_progress()
	return {"success": true, "submission": hero_submission[hero_id]}


## [LEGACY] 赠礼提升服从度 — kept for backward compatibility, no longer part of core loop.
func gift_heroine(hero_id: String, gold_cost: int = 30) -> Dictionary:
	if hero_id not in recruited_heroes:
		return {"ok": false, "desc": "角色未招募"}
	var pid: int = GameManager.get_human_player_id()
	if not ResourceManager.can_afford(pid, {"gold": gold_cost}):
		return {"ok": false, "desc": "金币不足 (需要%d金)" % gold_cost}
	var current: int = hero_submission.get(hero_id, 0)
	ResourceManager.spend(pid, {"gold": gold_cost})
	hero_submission[hero_id] = current + FactionData.SUBMISSION_PER_GIFT
	var hero_name: String = _get_hero_name(hero_id)
	EventBus.heroine_submission_changed.emit(hero_id, hero_submission[hero_id])
	EventBus.message_log.emit("[color=pink]赠礼 %s! 服从度 +%d (当前: %d)[/color]" % [
		hero_name, FactionData.SUBMISSION_PER_GIFT, hero_submission[hero_id]])
	_check_harem_progress()
	return {"ok": true, "desc": "赠礼成功", "submission": hero_submission[hero_id]}


# ═══════════════ GIFT SYSTEM (好感度赠礼 v3.5) ═══════════════

func can_give_gift(hero_id: String) -> bool:
	if hero_id not in recruited_heroes:
		return false
	if _gift_cooldowns.get(hero_id, 0) > 0:
		return false
	if hero_affection.get(hero_id, 0) >= FactionData.AFFECTION_MAX:
		return false
	return true


func get_gift_options(hero_id: String) -> Array:
	## Returns available gifts with cost and whether preferred.
	var options: Array = []
	var pid: int = GameManager.get_human_player_id()
	var preferred: String = _get_hero_data(hero_id).get("preferred_gift", "")
	for gift_id in FactionData.GIFT_TYPES:
		var gt: Dictionary = FactionData.GIFT_TYPES[gift_id]
		var can_afford: bool = ResourceManager.can_afford(pid, {"gold": gt["cost"]})
		var affection_gain: int = gt["affection"]
		if gift_id == preferred:
			affection_gain += FactionData.GIFT_PREFERRED_BONUS
		options.append({
			"id": gift_id,
			"name": gt["name"],
			"cost": gt["cost"],
			"affection": affection_gain,
			"is_preferred": gift_id == preferred,
			"can_afford": can_afford,
		})
	return options


func give_gift(hero_id: String, gift_id: String) -> Dictionary:
	## Give a gift to a hero. Returns {ok, desc, affection}.
	if not can_give_gift(hero_id):
		return {"ok": false, "desc": "无法赠礼"}
	if not FactionData.GIFT_TYPES.has(gift_id):
		return {"ok": false, "desc": "无效礼物"}
	var gt: Dictionary = FactionData.GIFT_TYPES[gift_id]
	var pid: int = GameManager.get_human_player_id()
	if not ResourceManager.can_afford(pid, {"gold": gt["cost"]}):
		return {"ok": false, "desc": "金币不足 (需要%d金)" % gt["cost"]}

	ResourceManager.spend(pid, {"gold": gt["cost"]})
	var gain: int = gt["affection"]
	var preferred: String = _get_hero_data(hero_id).get("preferred_gift", "")
	if gift_id == preferred:
		gain += FactionData.GIFT_PREFERRED_BONUS

	var current: int = hero_affection.get(hero_id, 0)
	hero_affection[hero_id] = mini(current + gain, FactionData.AFFECTION_MAX)
	_gift_cooldowns[hero_id] = FactionData.GIFT_COOLDOWN_TURNS

	var hero_name: String = _get_hero_name(hero_id)
	var is_pref: String = " (偏好!)" if gift_id == preferred else ""
	EventBus.hero_affection_changed.emit(hero_id, hero_affection[hero_id])
	EventBus.message_log.emit("[color=pink]赠礼 %s → %s%s 好感+%d (当前: %d)[/color]" % [
		gt["name"], hero_name, is_pref, gain, hero_affection[hero_id]])
	return {"ok": true, "desc": "赠礼成功", "affection": hero_affection[hero_id]}


func is_preferred_gift(hero_id: String, gift_id: String) -> bool:
	return _get_hero_data(hero_id).get("preferred_gift", "") == gift_id


func tick_gift_cooldowns() -> void:
	## Called once per turn to decrement gift cooldowns.
	var keys_to_erase: Array = []
	for hero_id in _gift_cooldowns:
		_gift_cooldowns[hero_id] -= 1
		if _gift_cooldowns[hero_id] <= 0:
			keys_to_erase.append(hero_id)
	for key in keys_to_erase:
		_gift_cooldowns.erase(key)


## 侍寝 — unlocks at submission >= 5, costs 1 AP, 2-turn cooldown, heals player HP.
func bed_heroine(hero_id: String) -> Dictionary:
	var pid: int = GameManager.get_human_player_id()
	var player: Dictionary = GameManager.get_player_by_id(pid)
	if player.is_empty():
		return {"success": false, "reason": "无效玩家"}
	if hero_id not in recruited_heroes:
		return {"success": false, "reason": "英雄未招募"}
	var current_sub: int = hero_submission.get(hero_id, 0)
	if current_sub < 5:
		return {"success": false, "reason": "服从度不足 (需要≥5)"}
	if player.get("ap", 0) < 1:
		return {"success": false, "reason": "行动力不足"}
	var cd: Dictionary = _harem_cooldowns.get(hero_id, {"train": 0, "bed": 0})
	if cd["bed"] > 0:
		return {"success": false, "reason": "冷却中 (剩余%d回合)" % cd["bed"]}
	# Execute
	player["ap"] -= 1
	hero_submission[hero_id] = current_sub + 1
	cd["bed"] = 2  # 2-turn cooldown
	_harem_cooldowns[hero_id] = cd
	# Heal hero HP via HeroLeveling combat state
	var heal_amount: int = 5
	HeroLeveling.restore_hero_hp(hero_id, heal_amount)
	EventBus.heroine_submission_changed.emit(hero_id, hero_submission[hero_id])
	if hero_submission.get(hero_id, 0) >= FactionData.HAREM_VICTORY_SUBMISSION_MIN:
		_harem_unlocked[hero_id] = true
	EventBus.message_log.emit("[color=pink]与%s侍寝，服从度 %d，HP回复 +%d[/color]" % [_get_hero_name(hero_id), hero_submission[hero_id], heal_amount])
	_check_harem_progress()
	return {"success": true, "submission": hero_submission[hero_id], "healed": heal_amount}


## 最終剧情 — submission >= 10, costs 1 AP, unlocks heroine permanently.
func trigger_final_story(hero_id: String) -> Dictionary:
	var pid: int = GameManager.get_human_player_id()
	var player: Dictionary = GameManager.get_player_by_id(pid)
	if player.is_empty():
		return {"success": false, "reason": "无效玩家"}
	if hero_id not in recruited_heroes:
		return {"success": false, "reason": "英雄未招募"}
	if _harem_unlocked.get(hero_id, false):
		return {"success": false, "reason": "已解锁"}
	var current_sub: int = hero_submission.get(hero_id, 0)
	if current_sub < 10:
		return {"success": false, "reason": "服从度不足 (需要≥10)"}
	if player.get("ap", 0) < 1:
		return {"success": false, "reason": "行动力不足"}
	# Execute
	player["ap"] -= 1
	_harem_unlocked[hero_id] = true
	EventBus.heroine_submission_changed.emit(hero_id, hero_submission[hero_id])
	EventBus.message_log.emit("[color=gold]═══ %s 最终剧情完成! 角色已解锁! ═══[/color]" % _get_hero_name(hero_id))
	_check_harem_progress()
	return {"success": true}


func is_heroine_unlocked(hero_id: String) -> bool:
	return _harem_unlocked.get(hero_id, false)


func get_harem_cooldowns(hero_id: String) -> Dictionary:
	return _harem_cooldowns.get(hero_id, {"train": 0, "bed": 0})


func get_unlocked_count() -> int:
	var count: int = 0
	for hid in _harem_unlocked:
		if _harem_unlocked[hid]: count += 1
	return count


## 获取后宫收集进度 { "total": int, "recruited": int, "unlocked": int, "complete": bool }
func get_harem_progress() -> Dictionary:
	var total: int = FactionData.HEROES.size()
	var recruited: int = recruited_heroes.size()
	var unlocked: int = get_unlocked_count()
	return {
		"total": total,
		"recruited": recruited,
		"unlocked": unlocked,
		"complete": unlocked >= recruited and recruited > 0,
	}


## 检查后宫收集进度并输出提示
func _check_harem_progress() -> void:
	if not _pirate_mode:
		return
	var progress: Dictionary = get_harem_progress()
	var total: int = progress["total"]
	var unlocked: int = progress["unlocked"]
	EventBus.harem_progress_updated.emit(progress["recruited"], unlocked, total)
	if unlocked > 0 and unlocked % 3 == 0 and unlocked < total:
		EventBus.message_log.emit("[color=gold]后宫进度: %d/%d 角色已解锁! 继续收集...[/color]" % [unlocked, total])
	if progress["complete"]:
		EventBus.message_log.emit("[color=gold]═══ 所有角色已完全解锁! 后宫胜利条件达成! ═══[/color]")
		EventBus.harem_victory_achieved.emit()


## 检查是否达成后宫胜利条件 (pirate_mode + at least 5 recruited + all recruited unlocked)
func check_harem_victory() -> bool:
	if not _pirate_mode: return false
	if recruited_heroes.size() < 5: return false
	for hid in recruited_heroes:
		if not _harem_unlocked.get(hid, false):
			return false
	return true


## 内部: 计算海盗建筑数量
func _count_pirate_building(building_id: String) -> int:
	var pid: int = GameManager.get_human_player_id()
	var count: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == pid and tile.get("building_id", "") == building_id:
			count += 1
	return count


# ═══════════════ HIDDEN HEROES (秘密英雄) ═══════════════

## Record a battle victory for hidden hero unlock tracking.
func record_battle_victory() -> void:
	_battles_won_count += 1


## Check all hidden hero conditions against current game state.
## Newly discovered heroes are added to the player's roster directly.
func check_hidden_hero_conditions(player_id: int) -> void:
	for entry in BalanceConfig.HIDDEN_HEROES:
		var hero_id: String = entry["id"]
		if hero_id in _discovered_hidden_heroes:
			continue
		if _check_single_hidden_hero(player_id, entry):
			_discover_hidden_hero(player_id, entry)


## Returns and clears pending hidden hero notifications.
func get_pending_hidden_hero_notifications() -> Array:
	var result: Array = _hidden_hero_notifications.duplicate()
	_hidden_hero_notifications.clear()
	return result


## Check if a specific hidden hero has been discovered.
func is_hidden_hero_discovered(hero_id: String) -> bool:
	return hero_id in _discovered_hidden_heroes


## Returns vague hints about undiscovered hidden heroes (no exact conditions).
func get_hidden_heroes_progress() -> Array:
	var progress: Array = []
	for entry in BalanceConfig.HIDDEN_HEROES:
		var hero_id: String = entry["id"]
		var discovered: bool = hero_id in _discovered_hidden_heroes
		progress.append({
			"id": hero_id,
			"discovered": discovered,
			"name": entry["name"] if discovered else "???",
			"hint": "" if discovered else entry.get("hint", "条件未知"),
		})
	return progress


## Internal: check a single hidden hero's unlock condition.
func _check_single_hidden_hero(player_id: int, entry: Dictionary) -> bool:
	var unlock_type: String = entry["unlock_type"]
	var params: Dictionary = entry["unlock_params"]

	match unlock_type:
		"tile_capture":
			var tile_idx: int = params["tile_index"]
			if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
				return false
			return GameManager.tiles[tile_idx].get("owner_id", -1) == player_id

		"turn_and_tiles":
			var min_turn: int = params["min_turn"]
			var min_tiles: int = params["min_tiles"]
			if GameManager.turn_number < min_turn:
				return false
			return GameManager.count_tiles_owned(player_id) >= min_tiles

		"corruption_check":
			var min_corruption: int = params["min_corruption"]
			for hid in recruited_heroes:
				var corruption_val: int = hero_corruption.get(hid, 0)
				if corruption_val >= min_corruption:
					return true
			# Also check captured heroes in prison
			for hid in captured_heroes:
				var corruption_val: int = hero_corruption.get(hid, 0)
				if corruption_val >= min_corruption:
					return true
			return false

		"tile_type_count":
			var tile_type: int = params["tile_type"]
			var min_count: int = params["min_count"]
			var count: int = 0
			for tile in GameManager.tiles:
				if tile.get("owner_id", -1) == player_id and tile.get("type", -1) == tile_type:
					count += 1
			return count >= min_count

		"battle_count":
			var min_battles: int = params["min_battles_won"]
			return _battles_won_count >= min_battles

		"prestige":
			var min_prestige: int = params["min_prestige"]
			return ResourceManager.get_resource(player_id, "prestige") >= min_prestige

		"compound":
			# Requires both intel level AND tile ownership
			var min_intel: int = params.get("min_intel", 0)
			var tile_idx: int = params.get("tile_index", -1)
			var intel_ok: bool = true
			if min_intel > 0:
				var espionage_node: Node = get_node_or_null("/root/EspionageSystem")
				if espionage_node and espionage_node.has_method("get_intel"):
					intel_ok = espionage_node.get_intel(player_id) >= min_intel
				else:
					intel_ok = false
			var tile_ok: bool = true
			if tile_idx >= 0 and tile_idx < GameManager.tiles.size():
				tile_ok = GameManager.tiles[tile_idx].get("owner_id", -1) == player_id
			elif tile_idx >= 0:
				tile_ok = false
			return intel_ok and tile_ok

		"tile_set":
			# Requires controlling N tiles with a specific terrain type
			var terrain_type: int = params.get("terrain_type", -1)
			var min_count: int = params.get("min_count", 1)
			var count: int = 0
			for tile in GameManager.tiles:
				if tile.get("owner_id", -1) == player_id and tile.get("terrain", -1) == terrain_type:
					count += 1
			return count >= min_count

	return false


## Internal: discover a hidden hero and add them to roster.
func _discover_hidden_hero(player_id: int, entry: Dictionary) -> void:
	var hero_id: String = entry["id"]
	_discovered_hidden_heroes.append(hero_id)
	recruited_heroes.append(hero_id)
	hero_affection[hero_id] = 0
	_ensure_equip_slots(hero_id)

	# Register hero template into runtime registry so combat stats resolve
	var template: Dictionary = entry["hero_template"]
	_hidden_hero_data[hero_id] = {
		"name": entry["name"],
		"atk": template.get("atk", 5),
		"def": template.get("def", 5),
		"spd": template.get("spd", 5),
		"base_hp": template.get("hp", 20),
		"int": template.get("int", 5),
		"troop": template.get("troop_type", "infantry"),
		"active": template.get("active", ""),
		"passive": template.get("passive", ""),
		"capture_chance": template.get("capture_chance", 0.0),
	}

	# Initialize hero leveling
	HeroLeveling.init_hero(hero_id)

	# Create notification
	var notification: Dictionary = {
		"hero_id": hero_id,
		"hero_name": entry["name"],
		"message": entry.get("reveal_message", "%s 加入了你的阵营!" % entry["name"]),
	}
	_hidden_hero_notifications.append(notification)

	# Emit events
	EventBus.hero_recruited.emit(hero_id)
	EventBus.hidden_hero_discovered.emit(hero_id, entry["name"], notification["message"])
	EventBus.message_log.emit("[color=gold]═══ 秘密英雄发现: %s ═══[/color]" % entry["name"])
	EventBus.message_log.emit("[color=yellow]%s[/color]" % notification["message"])


# ═══════════════ SERIALIZATION ═══════════════

func to_save_data() -> Dictionary:
	var data: Dictionary = {
		"captured_heroes": captured_heroes.duplicate(),
		"recruited_heroes": recruited_heroes.duplicate(),
		"hero_corruption": hero_corruption.duplicate(),
		"hero_affection": hero_affection.duplicate(),
		"hero_equipment": hero_equipment.duplicate(true),
		"stationed_heroes": stationed_heroes.duplicate(true),
		"skill_cooldowns": _skill_cooldowns.duplicate(),
		"hero_submission": hero_submission.duplicate(),
		"pirate_mode": _pirate_mode,
		"second_skills": _second_skills.duplicate(),
		"harem_cooldowns": _harem_cooldowns.duplicate(true),
		"harem_unlocked": _harem_unlocked.duplicate(),
		"gift_cooldowns": _gift_cooldowns.duplicate(),
		"discovered_hidden_heroes": _discovered_hidden_heroes.duplicate(),
		"battles_won_count": _battles_won_count,
		"recruitment_event_cooldown": _recruitment_event_cooldown,
		"recruitment_event_counter": _recruitment_event_counter,
		"mercenary_loyalty": _mercenary_loyalty.duplicate(),
		"wandering_hero_pool": _wandering_hero_pool.duplicate(),
		# BUG FIX R17: save missing fields that were declared but not serialized
		"exiled_heroes": _exiled_heroes.duplicate(),
		"hero_stat_bonuses": _hero_stat_bonuses.duplicate(true),
		"hidden_hero_notifications": _hidden_hero_notifications.duplicate(),
	}
	data["hero_leveling"] = HeroLeveling.serialize()
	return data


func from_save_data(data: Dictionary) -> void:
	captured_heroes = data.get("captured_heroes", []).duplicate()
	recruited_heroes = data.get("recruited_heroes", []).duplicate()
	hero_corruption = data.get("hero_corruption", {}).duplicate()
	hero_affection = data.get("hero_affection", {}).duplicate()
	hero_equipment = data.get("hero_equipment", {}).duplicate(true)
	# Migrate legacy 3-slot format to SR07 single-slot format
	for hid in hero_equipment.keys():
		if hero_equipment[hid] is Dictionary:
			# Pick the best equipped item from old slots (prefer weapon > armor > accessory)
			var old_slots: Dictionary = hero_equipment[hid]
			var migrated: String = ""
			for old_key in ["weapon", "armor", "accessory"]:
				var old_id: String = old_slots.get(old_key, "")
				if old_id != "":
					if migrated == "":
						migrated = old_id
					else:
						# Return extra items to inventory
						ItemManager.add_item(GameManager.get_human_player_id(), old_id)
			hero_equipment[hid] = migrated
	# 确保所有英雄（已招募+被俘）的装备槽都正确初始化
	for hid in recruited_heroes + captured_heroes:
		_ensure_equip_slots(hid)
	_skill_cooldowns = data.get("skill_cooldowns", {}).duplicate()
	hero_submission = data.get("hero_submission", {}).duplicate()
	_pirate_mode = data.get("pirate_mode", false)
	_second_skills = data.get("second_skills", {}).duplicate()
	_harem_cooldowns = data.get("harem_cooldowns", {}).duplicate(true)
	_harem_unlocked = data.get("harem_unlocked", {}).duplicate()
	_gift_cooldowns = data.get("gift_cooldowns", {}).duplicate()
	_discovered_hidden_heroes = data.get("discovered_hidden_heroes", []).duplicate()
	_battles_won_count = data.get("battles_won_count", 0)
	_recruitment_event_cooldown = data.get("recruitment_event_cooldown", 0)
	_recruitment_event_counter = data.get("recruitment_event_counter", 0)
	_mercenary_loyalty = data.get("mercenary_loyalty", {}).duplicate()
	_wandering_hero_pool = data.get("wandering_hero_pool", []).duplicate()
	# BUG FIX R17: restore missing fields
	_exiled_heroes = data.get("exiled_heroes", {}).duplicate()
	_hero_stat_bonuses = data.get("hero_stat_bonuses", {}).duplicate(true)
	_hidden_hero_notifications = data.get("hidden_hero_notifications", []).duplicate()
	# Fix int keys in exiled_heroes after JSON round-trip (hero_id is String, value is int)
	for hid in _exiled_heroes:
		_exiled_heroes[hid] = int(_exiled_heroes[hid])
	# Fix int values in hero_stat_bonuses
	for hid in _hero_stat_bonuses:
		if _hero_stat_bonuses[hid] is Dictionary:
			for stat_key in _hero_stat_bonuses[hid]:
				_hero_stat_bonuses[hid][stat_key] = int(_hero_stat_bonuses[hid][stat_key])
	# Re-register discovered hidden hero templates into runtime registry
	_hidden_hero_data.clear()
	for entry in BalanceConfig.HIDDEN_HEROES:
		if entry["id"] in _discovered_hidden_heroes:
			var template: Dictionary = entry["hero_template"]
			_hidden_hero_data[entry["id"]] = {
				"name": entry["name"],
				"atk": template.get("atk", 5),
				"def": template.get("def", 5),
				"spd": template.get("spd", 5),
				"base_hp": template.get("hp", 20),
				"int": template.get("int", 5),
				"troop": template.get("troop_type", "infantry"),
				"active": template.get("active", ""),
				"passive": template.get("passive", ""),
				"capture_chance": template.get("capture_chance", 0.0),
			}
	if data.has("hero_leveling"):
		HeroLeveling.deserialize(data["hero_leveling"])
	stationed_heroes.clear()
	hero_stations.clear()
	var sh: Dictionary = data.get("stationed_heroes", {})
	for key in sh:
		var tidx: int = int(key)
		var hid: String = sh[key]
		stationed_heroes[tidx] = hid
		hero_stations[hid] = tidx


# ═══════════════ INTERNAL ═══════════════

func _unlock_second_skill(hero_id: String) -> void:
	## 好感度达到7时，解锁英雄的第二主动技能并加入可用技能列表
	var hero_data: Dictionary = _get_hero_data(hero_id)
	# NOTE: FactionData.HEROES does not currently define a secondary skill key.
	# This is a placeholder for future implementation. When secondary skills are
	# added to FactionData.HEROES, use the appropriate key here (e.g., "active_2").
	var second_skill: String = hero_data.get("active_2", "")
	if second_skill == "":
		return
	# 避免重复解锁
	if _second_skills.has(hero_id):
		return
	# 验证技能定义存在
	if not FactionData.HERO_SKILL_DEFS.has(second_skill):
		push_warning("HeroSystem: 第二技能 '%s' 在 HERO_SKILL_DEFS 中未定义 (hero='%s')" % [second_skill, hero_id])
		return
	# 存储已解锁的第二技能
	_second_skills[hero_id] = second_skill
	EventBus.message_log.emit("[技能] %s 解锁第二主动技能: %s" % [_get_hero_name(hero_id), second_skill])


func _get_hero_data(hero_id: String) -> Dictionary:
	## Lookup hero data from FactionData.HEROES or hidden hero runtime registry.
	# BUG FIX: was calling itself recursively (infinite recursion crash)
	var data: Dictionary = FactionData.HEROES.get(hero_id, {})
	if data.is_empty():
		data = _hidden_hero_data.get(hero_id, {})
	return data


func _get_hero_name(hero_id: String) -> String:
	return _get_hero_data(hero_id).get("name", hero_id)


## Apply a permanent stat modification to a hero (from events, chain rewards, etc.)
func modify_hero_stat(hero_id: String, stat_key: String, value: int) -> void:
	if not HeroLeveling:
		return
	# Store permanent stat bonuses in HeroLeveling's stat override system
	var current: int = 0
	if HeroLeveling.has_method("get_stat_bonus"):
		current = HeroLeveling.get_stat_bonus(hero_id, stat_key)
	if HeroLeveling.has_method("set_stat_bonus"):
		HeroLeveling.set_stat_bonus(hero_id, stat_key, current + value)
	else:
		# Fallback: store in a local dict if HeroLeveling doesn't support it
		if not _hero_stat_bonuses.has(hero_id):
			_hero_stat_bonuses[hero_id] = {}
		_hero_stat_bonuses[hero_id][stat_key] = _hero_stat_bonuses[hero_id].get(stat_key, 0) + value
	EventBus.hero_stat_changed.emit(hero_id, stat_key, value)


# ═══════════════ SR07-STYLE RECRUITMENT EVENTS ═══════════════

const _RECRUIT_EVT_WANDERING  := "recruit_wandering_hero"
const _RECRUIT_EVT_DESERTER   := "recruit_deserter"
const _RECRUIT_EVT_MERCENARY  := "recruit_mercenary_band"
const _RECRUIT_EVT_LEGENDARY  := "recruit_legendary_hero"
const _RECRUIT_COOLDOWN_TURNS := 3


## Called each turn by GameManager. Rolls for at most one recruitment event.
func process_recruitment_events(player_id: int) -> void:
	# Tick mercenary loyalty — remove heroes whose loyalty expired
	_tick_mercenary_loyalty(player_id)

	# Tick cooldown
	if _recruitment_event_cooldown > 0:
		_recruitment_event_cooldown -= 1
		return

	# Only fire for human player
	if player_id != GameManager.get_human_player_id():
		return

	# Collect eligible events and shuffle for fair priority
	var candidates: Array = []

	# Legendary hero: 2% chance
	if randf() < 0.02:
		candidates.append(_RECRUIT_EVT_LEGENDARY)

	# Wandering hero: 10% chance
	if randf() < 0.10:
		candidates.append(_RECRUIT_EVT_WANDERING)

	# Deserter: 10% chance
	if randf() < 0.10:
		candidates.append(_RECRUIT_EVT_DESERTER)

	# Mercenary band: 10% chance
	if randf() < 0.10:
		candidates.append(_RECRUIT_EVT_MERCENARY)

	if candidates.is_empty():
		return

	# Pick one at random (max 1 event per turn)
	candidates.shuffle()
	var chosen: String = candidates[0]

	match chosen:
		_RECRUIT_EVT_LEGENDARY:
			_event_legendary_hero(player_id)
		_RECRUIT_EVT_WANDERING:
			_event_wandering_hero(player_id)
		_RECRUIT_EVT_DESERTER:
			_event_deserter(player_id)
		_RECRUIT_EVT_MERCENARY:
			_event_mercenary_band(player_id)


## Tick down mercenary loyalty each turn. Remove heroes whose loyalty expires.
func _tick_mercenary_loyalty(player_id: int) -> void:
	var expired: Array = []
	for hid in _mercenary_loyalty.keys():
		_mercenary_loyalty[hid] -= 1
		if _mercenary_loyalty[hid] <= 0:
			# Check affection — if >= 5, mercenary stays permanently
			var aff: int = hero_affection.get(hid, 0)
			if aff >= 5:
				_mercenary_loyalty.erase(hid)
				EventBus.message_log.emit("[color=green]佣兵 %s 对你忠心耿耿，决定永久留下！[/color]" % _get_hero_name(hid))
			else:
				expired.append(hid)
	for hid in expired:
		_mercenary_loyalty.erase(hid)
		recruited_heroes.erase(hid)
		# Unstation if stationed
		if hero_stations.has(hid):
			var tidx: int = hero_stations[hid]
			stationed_heroes.erase(tidx)
			hero_stations.erase(hid)
		hero_affection.erase(hid)
		hero_equipment[hid] = ""
		EventBus.message_log.emit("[color=orange]佣兵 %s 的合约到期，离开了你的队伍。[/color]" % _get_hero_name(hid))


func _next_recruit_event_id() -> String:
	_recruitment_event_counter += 1
	return "recruit_%d" % _recruitment_event_counter


## Get all hero_ids that are not captured, not recruited, not exiled — available for recruitment events.
func _get_unrecruited_hero_ids() -> Array:
	var result: Array = []
	for hid in FactionData.HEROES.keys():
		if hid in recruited_heroes or hid in captured_heroes or hid in _exiled_heroes:
			continue
		result.append(hid)
	return result


## ── Event: Wandering Hero ──
func _event_wandering_hero(player_id: int) -> void:
	# Pick a random unrecruited hero (prefer wandering pool if available)
	var pool: Array = _wandering_hero_pool.duplicate()
	if pool.is_empty():
		pool = _get_unrecruited_hero_ids()
	if pool.is_empty():
		return

	pool.shuffle()
	var hero_id: String = pool[0]
	var hero: Dictionary = _get_hero_data(hero_id)
	if hero.is_empty():
		return

	var level: int = HeroLeveling.get_hero_stats(hero_id).get("level", 1)
	var cost: int = level * 30
	var hero_name: String = hero.get("name", hero_id)

	var eid: String = _next_recruit_event_id()
	var event_data: Dictionary = {
		"type": _RECRUIT_EVT_WANDERING,
		"event_id": eid,
		"hero_id": hero_id,
		"cost": cost,
		"title": "流浪武将",
		"description": "一位名叫[color=cyan]%s[/color]的武将在你的领地边境游荡，提出愿意为你效力。\n招募费用: [color=gold]%d金[/color]" % [hero_name, cost],
		"choices": [
			{"text": "招募 (-%d金)" % cost, "callback": "wandering_accept"},
			{"text": "拒绝 (可能日后再来)", "callback": "wandering_reject"},
		],
	}
	_recruitment_event_cooldown = _RECRUIT_COOLDOWN_TURNS
	EventBus.recruitment_event_triggered.emit(event_data)


## ── Event: Deserter ──
func _event_deserter(player_id: int) -> void:
	# Find an enemy hero from a faction where player reputation > 40
	var eligible: Array = []
	var faction_keys: Array = ["orc_ai", "pirate_ai", "dark_elf_ai"]
	var faction_names: Dictionary = {
		"orc_ai": "兽人部落", "pirate_ai": "暗黑海盗", "dark_elf_ai": "黑暗精灵议会"
	}
	var faction_tag_map: Dictionary = {
		"orc_ai": "orc", "pirate_ai": "pirate", "dark_elf_ai": "dark_elf"
	}
	for fkey in faction_keys:
		var rep: int = DiplomacyManager.get_reputation(fkey) if DiplomacyManager else 0
		if rep > 40:
			var ftag: String = faction_tag_map[fkey]
			for hid in _get_unrecruited_hero_ids():
				var hdata: Dictionary = _get_hero_data(hid)
				if hdata.get("faction", "") == ftag:
					eligible.append({"hero_id": hid, "faction_key": fkey, "faction_name": faction_names[fkey]})
	if eligible.is_empty():
		return

	eligible.shuffle()
	var pick: Dictionary = eligible[0]
	var hero_id: String = pick["hero_id"]
	var hero_name: String = _get_hero_name(hero_id)

	var eid: String = _next_recruit_event_id()
	var event_data: Dictionary = {
		"type": _RECRUIT_EVT_DESERTER,
		"event_id": eid,
		"hero_id": hero_id,
		"faction_key": pick["faction_key"],
		"title": "叛逃武将",
		"description": "[color=cyan]%s[/color]对[color=red]%s[/color]心生不满，秘密来投。\n免费加入，但原阵营声望[color=red]-10[/color]。" % [hero_name, pick["faction_name"]],
		"choices": [
			{"text": "接纳 (免费, 声望-10)", "callback": "deserter_accept"},
			{"text": "拒绝", "callback": "deserter_reject"},
		],
	}
	_recruitment_event_cooldown = _RECRUIT_COOLDOWN_TURNS
	EventBus.recruitment_event_triggered.emit(event_data)


## ── Event: Mercenary Band ──
func _event_mercenary_band(player_id: int) -> void:
	var pool: Array = _get_unrecruited_hero_ids()
	if pool.is_empty():
		return

	pool.shuffle()
	var hero_id: String = pool[0]
	var hero: Dictionary = _get_hero_data(hero_id)
	if hero.is_empty():
		return

	var hero_name: String = hero.get("name", hero_id)
	var gold_cost: int = 80
	var troop_bonus: int = randi_range(20, 40)

	var eid: String = _next_recruit_event_id()
	var event_data: Dictionary = {
		"type": _RECRUIT_EVT_MERCENARY,
		"event_id": eid,
		"hero_id": hero_id,
		"cost": gold_cost,
		"troop_bonus": troop_bonus,
		"title": "佣兵团",
		"description": "佣兵[color=cyan]%s[/color]率领一支%d人的佣兵队前来投靠。\n费用: [color=gold]%d金[/color]。佣兵合约持续[color=yellow]10回合[/color]，好感度≥5则永久留下。" % [hero_name, troop_bonus, gold_cost],
		"choices": [
			{"text": "雇佣 (-%d金, +%d兵)" % [gold_cost, troop_bonus], "callback": "mercenary_accept"},
			{"text": "拒绝", "callback": "mercenary_reject"},
		],
	}
	_recruitment_event_cooldown = _RECRUIT_COOLDOWN_TURNS
	EventBus.recruitment_event_triggered.emit(event_data)


## ── Event: Legendary Hero ──
func _event_legendary_hero(player_id: int) -> void:
	# Pick a high-stat unrecruited hero (prefer atk+def+int >= 18)
	var pool: Array = _get_unrecruited_hero_ids()
	var legendary: Array = []
	for hid in pool:
		var hd: Dictionary = _get_hero_data(hid)
		var total: int = hd.get("atk", 0) + hd.get("def", 0) + hd.get("int", 0)
		if total >= 18:
			legendary.append(hid)
	if legendary.is_empty():
		# Fallback: any unrecruited hero
		if pool.is_empty():
			return
		legendary = pool
	legendary.shuffle()
	var hero_id: String = legendary[0]
	var hero_name: String = _get_hero_name(hero_id)

	var eid: String = _next_recruit_event_id()
	var event_data: Dictionary = {
		"type": _RECRUIT_EVT_LEGENDARY,
		"event_id": eid,
		"hero_id": hero_id,
		"ap_cost": 2,
		"gold_cost": 100,
		"title": "传说武将",
		"description": "传说中的武将[color=gold]%s[/color]出现了！\n完成挑战即可招募: 消耗[color=yellow]2 AP[/color] + [color=gold]100金[/color]。" % hero_name,
		"choices": [
			{"text": "接受挑战 (-2AP, -100金)", "callback": "legendary_accept"},
			{"text": "放弃 (传说消散)", "callback": "legendary_reject"},
		],
	}
	_recruitment_event_cooldown = _RECRUIT_COOLDOWN_TURNS
	EventBus.recruitment_event_triggered.emit(event_data)


## Resolve a recruitment event choice from the UI popup.
func resolve_recruitment_event(event_data: Dictionary, choice_index: int) -> void:
	var player_id: int = GameManager.get_human_player_id()
	var choices: Array = event_data.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var callback: String = choices[choice_index].get("callback", "")
	var hero_id: String = event_data.get("hero_id", "")

	match event_data.get("type", ""):
		_RECRUIT_EVT_WANDERING:
			_resolve_wandering(player_id, hero_id, event_data, callback)
		_RECRUIT_EVT_DESERTER:
			_resolve_deserter(player_id, hero_id, event_data, callback)
		_RECRUIT_EVT_MERCENARY:
			_resolve_mercenary(player_id, hero_id, event_data, callback)
		_RECRUIT_EVT_LEGENDARY:
			_resolve_legendary(player_id, hero_id, event_data, callback)


func _resolve_wandering(player_id: int, hero_id: String, event_data: Dictionary, callback: String) -> void:
	if callback == "wandering_accept":
		var cost: int = event_data.get("cost", 0)
		var gold: int = ResourceManager.get_resource(player_id, "gold")
		if gold < cost:
			EventBus.message_log.emit("[color=red]金币不足，无法招募流浪武将。[/color]")
			return
		ResourceManager.apply_delta(player_id, {"gold": -cost})
		_directly_recruit_hero(hero_id)
		_wandering_hero_pool.erase(hero_id)
		EventBus.message_log.emit("[color=green]流浪武将 %s 加入了你的队伍！(-%d金)[/color]" % [_get_hero_name(hero_id), cost])
	else:
		# Rejected — add to wandering pool so they may return
		if hero_id not in _wandering_hero_pool:
			_wandering_hero_pool.append(hero_id)
		EventBus.message_log.emit("[color=gray]你拒绝了 %s 的投靠，也许日后还会再见。[/color]" % _get_hero_name(hero_id))


func _resolve_deserter(player_id: int, hero_id: String, event_data: Dictionary, callback: String) -> void:
	if callback == "deserter_accept":
		var fkey: String = event_data.get("faction_key", "")
		_directly_recruit_hero(hero_id)
		if DiplomacyManager and fkey != "":
			DiplomacyManager.change_reputation(fkey, -10)
		EventBus.message_log.emit("[color=green]叛逃武将 %s 加入了你的队伍！(原阵营声望-10)[/color]" % _get_hero_name(hero_id))
	else:
		EventBus.message_log.emit("[color=gray]你拒绝了叛逃武将的投靠。[/color]")


func _resolve_mercenary(player_id: int, hero_id: String, event_data: Dictionary, callback: String) -> void:
	if callback == "mercenary_accept":
		var cost: int = event_data.get("cost", 80)
		var troop_bonus: int = event_data.get("troop_bonus", 0)
		var gold: int = ResourceManager.get_resource(player_id, "gold")
		if gold < cost:
			EventBus.message_log.emit("[color=red]金币不足，无法雇佣佣兵团。[/color]")
			return
		ResourceManager.apply_delta(player_id, {"gold": -cost, "soldiers": troop_bonus})
		_directly_recruit_hero(hero_id)
		_mercenary_loyalty[hero_id] = 10  # 10 turn contract
		EventBus.message_log.emit("[color=green]佣兵 %s 带领%d士兵加入！(-%d金, 合约10回合)[/color]" % [_get_hero_name(hero_id), troop_bonus, cost])
	else:
		EventBus.message_log.emit("[color=gray]你拒绝了佣兵团的服务。[/color]")


func _resolve_legendary(player_id: int, hero_id: String, event_data: Dictionary, callback: String) -> void:
	if callback == "legendary_accept":
		var ap_cost: int = event_data.get("ap_cost", 2)
		var gold_cost: int = event_data.get("gold_cost", 100)
		var gold: int = ResourceManager.get_resource(player_id, "gold")
		var player: Dictionary = GameManager.players[player_id] if player_id < GameManager.players.size() else {}
		var ap: int = player.get("ap", 0)
		if gold < gold_cost:
			EventBus.message_log.emit("[color=red]金币不足，无法挑战传说武将。[/color]")
			return
		if ap < ap_cost:
			EventBus.message_log.emit("[color=red]行动力不足，无法挑战传说武将。(需要%d AP)[/color]" % ap_cost)
			return
		ResourceManager.apply_delta(player_id, {"gold": -gold_cost})
		player["ap"] -= ap_cost
		EventBus.ap_changed.emit(player_id, player["ap"])
		_directly_recruit_hero(hero_id)
		EventBus.message_log.emit("[color=gold]传说武将 %s 被你的实力折服，加入了队伍！(-2AP, -100金)[/color]" % _get_hero_name(hero_id))
	else:
		EventBus.message_log.emit("[color=gray]传说武将消失在迷雾中……[/color]")


## Direct recruitment bypassing the prison system (for event-based recruitment).
func _directly_recruit_hero(hero_id: String) -> void:
	if hero_id in recruited_heroes:
		return
	# Remove from captured/exiled if somehow present
	captured_heroes.erase(hero_id)
	_exiled_heroes.erase(hero_id)
	recruited_heroes.append(hero_id)
	hero_affection[hero_id] = 0
	_ensure_equip_slots(hero_id)
	HeroLeveling.init_hero(hero_id)
	EventBus.hero_recruited.emit(hero_id)
