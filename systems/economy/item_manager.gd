extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## item_manager.gd - Inventory management for consumables and equipment (v0.8.7)
## Handles both ITEM_DEFS (consumables) and EQUIPMENT_DEFS (equippable gear).
## Equipment items live in inventory until equipped on a hero via HeroSystem.

const MAX_ITEMS: int = 8  # Increased from 4 to accommodate equipment

# Per-player inventories: { player_id: Array of item_id strings }
# Contains both consumable IDs (from ITEM_DEFS) and equipment IDs (from EQUIPMENT_DEFS)
var _inventories: Dictionary = {}
var _national_items: Dictionary = {}  # player_id -> Array of equip_id strings (max 3)
const MAX_NATIONAL_ITEMS: int = 3

func _ready() -> void:
	pass

func reset() -> void:
	_inventories.clear()
	_national_items.clear()

func init_player(player_id: int) -> void:
	_inventories[player_id] = []


# ═══════════════ INVENTORY MANAGEMENT ═══════════════

func add_item(player_id: int, item_id: String) -> bool:
	## Add item (consumable or equipment) to inventory. Returns false if full.
	if not _inventories.has(player_id):
		init_player(player_id)
	if _inventories[player_id].size() >= MAX_ITEMS:
		EventBus.message_log.emit("[color=orange]背包已满! 无法获得道具[/color]")
		return false
	# Validate item exists in either consumables or equipment
	var item_name: String = _get_item_name(item_id)
	if item_name == "":
		return false
	_inventories[player_id].append(item_id)
	EventBus.message_log.emit("获得道具: %s" % item_name)
	return true


func remove_item(player_id: int, item_id: String) -> bool:
	## Remove one instance of item.
	if not _inventories.has(player_id):
		return false
	var idx: int = _inventories[player_id].find(item_id)
	if idx < 0:
		return false
	_inventories[player_id].remove_at(idx)
	return true


func use_item(player_id: int, item_id: String) -> bool:
	## Use a consumable item. Applies effect immediately or sets up buff.
	## Equipment items cannot be "used" - they must be equipped via HeroSystem.
	if not has_item(player_id, item_id):
		return false
	# Block equipment from being "used"
	if is_equipment(item_id):
		EventBus.message_log.emit("[color=yellow]装备需要通过英雄界面装备, 不能直接使用[/color]")
		return false
	var item_data: Dictionary = FactionData.ITEM_DEFS.get(item_id, {})
	if item_data.is_empty():
		EventBus.message_log.emit("[color=red]未知道具: %s[/color]" % item_id)
		return false
	var effect: Dictionary = item_data.get("effect", {})

	# Validate effect values before applying
	if effect.is_empty():
		EventBus.message_log.emit("[color=red]道具 %s 无有效效果![/color]" % item_data.get("name", item_id))
		return false

	# Immediate resource effects
	if effect.has("gold"):
		var val: int = int(effect["gold"])
		# 防止负值道具效果消耗玩家资源
		if val < 0:
			push_warning("ItemManager: 道具 '%s' 的gold效果值为负(%d)，已拦截" % [item_id, val])
			return false
		if val == 0:
			return false
		ResourceManager.apply_delta(player_id, {"gold": val})
		EventBus.message_log.emit("使用 %s: +%d金币" % [item_data["name"], val])
	elif effect.has("food"):
		var val: int = int(effect["food"])
		if val < 0:
			push_warning("ItemManager: 道具 '%s' 的food效果值为负(%d)，已拦截" % [item_id, val])
			return false
		if val == 0:
			return false
		ResourceManager.apply_delta(player_id, {"food": val})
		EventBus.message_log.emit("使用 %s: +%d粮草" % [item_data["name"], val])
	elif effect.has("iron"):
		var val: int = int(effect["iron"])
		if val < 0:
			push_warning("ItemManager: 道具 '%s' 的iron效果值为负(%d)，已拦截" % [item_id, val])
			return false
		if val == 0:
			return false
		ResourceManager.apply_delta(player_id, {"iron": val})
		EventBus.message_log.emit("使用 %s: +%d铁矿" % [item_data["name"], val])
	elif effect.has("heal"):
		var val: int = int(effect["heal"])
		if val <= 0:
			return false
		# v4.4: Squad-level healing — distribute to most damaged squads first
		var healed: int = 0
		if RecruitManager.has_method("heal_army_squads"):
			healed = RecruitManager.heal_army_squads(player_id, val)
		if healed == 0:
			# Fallback: pool-level heal if squad system unavailable
			ResourceManager.add_army(player_id, val)
			healed = val
		EventBus.message_log.emit("使用 %s: 恢复%d兵力" % [item_data["name"], healed])
	elif effect.has("dice_bonus"):
		var val: int = int(effect["dice_bonus"])
		if val == 0:
			return false
		BuffManager.add_buff(player_id, "item_dice", "dice_bonus", val, 1, "item")
		EventBus.message_log.emit("使用 %s: 本回合骰子+%d" % [item_data["name"], val])
	elif effect.has("atk_mult"):
		var val: float = float(effect["atk_mult"])
		if val <= 0.0:
			return false
		BuffManager.add_buff(player_id, "item_atk", "atk_mult", val, 1, "item")
		EventBus.message_log.emit("使用 %s: 下次战斗攻击+%d%%" % [item_data["name"], int((val - 1.0) * 100)])
	elif effect.has("def_mult"):
		var val: float = float(effect["def_mult"])
		if val <= 0.0:
			return false
		BuffManager.add_buff(player_id, "item_def", "def_mult", val, 1, "item")
		EventBus.message_log.emit("使用 %s: 下次战斗防御+%d%%" % [item_data["name"], int((val - 1.0) * 100)])
	elif effect.has("guaranteed_slave"):
		BuffManager.add_buff(player_id, "item_slave", "guaranteed_slave", true, 1, "item")
		EventBus.message_log.emit("使用 %s: 下次战斗必定俘获奴隶" % item_data["name"])
	elif effect.has("mage_weaken"):
		var val: float = float(effect["mage_weaken"])
		if val <= 0.0:
			return false
		BuffManager.add_buff(player_id, "item_mage_weak", "mage_weaken", val, 5, "item")
		EventBus.message_log.emit("使用 %s: 法师效果减半(5回合)" % item_data["name"])
	elif effect.has("wall_damage"):
		var val: int = int(effect["wall_damage"])
		if val <= 0:
			return false
		# Stored as buff; applied at next siege combat
		BuffManager.add_buff(player_id, "item_wall_dmg", "wall_damage", val, 1, "item")
		EventBus.message_log.emit("使用 %s: 下次攻城削减%d城防" % [item_data["name"], val])
	elif effect.has("grant_legendary"):
		# legendary_random: grant a random legendary equipment
		var legendary_ids: Array = []
		for eid in FactionData.EQUIPMENT_DEFS:
			if FactionData.EQUIPMENT_DEFS[eid].get("rarity", "") == "legendary":
				legendary_ids.append(eid)
		if legendary_ids.is_empty():
			EventBus.message_log.emit("[color=red]没有可用的传奇装备![/color]")
			return false
		var chosen: String = legendary_ids[randi() % legendary_ids.size()]
		var chosen_name: String = FactionData.EQUIPMENT_DEFS[chosen].get("name", chosen)
		if not add_item(player_id, chosen):
			EventBus.message_log.emit("[color=orange]背包已满! 无法获得传奇装备[/color]")
			return false
		EventBus.message_log.emit("使用 %s: 获得传奇装备 [color=orange]%s[/color]!" % [item_data["name"], chosen_name])
	else:
		EventBus.message_log.emit("[color=red]道具 %s 效果类型未识别![/color]" % item_data.get("name", item_id))
		return false

	remove_item(player_id, item_id)
	return true


func has_item(player_id: int, item_id: String) -> bool:
	## Check if player has at least one of the given item.
	if not _inventories.has(player_id):
		return false
	return _inventories[player_id].has(item_id)


# ═══════════════ INVENTORY QUERY ═══════════════

func get_inventory(player_id: int) -> Array:
	## Returns array of item detail dicts for UI display (both consumables and equipment).
	if not _inventories.has(player_id):
		return []
	var result: Array = []
	for item_id in _inventories[player_id]:
		result.append(_get_item_display(item_id))
	return result


func get_consumables(player_id: int) -> Array:
	## Returns only consumable items from inventory.
	if not _inventories.has(player_id):
		return []
	var result: Array = []
	for item_id in _inventories[player_id]:
		if not is_equipment(item_id):
			result.append(_get_item_display(item_id))
	return result


func get_equipment_items(player_id: int) -> Array:
	## Returns only equipment items from inventory (not yet equipped on any hero).
	if not _inventories.has(player_id):
		return []
	var result: Array = []
	for item_id in _inventories[player_id]:
		if is_equipment(item_id):
			result.append(_get_item_display(item_id))
	return result


func get_inventory_size(player_id: int) -> int:
	if not _inventories.has(player_id):
		return 0
	return _inventories[player_id].size()


func is_full(player_id: int) -> bool:
	return get_inventory_size(player_id) >= MAX_ITEMS


func is_equipment(item_id: String) -> bool:
	return FactionData.EQUIPMENT_DEFS.has(item_id)


func is_consumable(item_id: String) -> bool:
	return FactionData.ITEM_DEFS.has(item_id)


# ═══════════════ NATIONAL ITEMS (SR07 style) ═══════════════

func set_national_item(player_id: int, equip_id: String) -> bool:
	## Equip an item from inventory as a national item (faction-wide bonus).
	if not _inventories.has(player_id):
		return false
	if equip_id not in _inventories[player_id]:
		return false
	if not is_equipment(equip_id):
		return false
	if not _national_items.has(player_id):
		_national_items[player_id] = []
	if _national_items[player_id].size() >= MAX_NATIONAL_ITEMS:
		return false
	if equip_id in _national_items[player_id]:
		return false
	_inventories[player_id].erase(equip_id)
	_national_items[player_id].append(equip_id)
	EventBus.item_used.emit(player_id, equip_id)
	return true


func remove_national_item(player_id: int, equip_id: String) -> bool:
	## Unequip a national item back to inventory.
	if not _national_items.has(player_id):
		return false
	if equip_id not in _national_items[player_id]:
		return false
	if is_full(player_id):
		return false
	_national_items[player_id].erase(equip_id)
	_inventories[player_id].append(equip_id)
	EventBus.item_acquired.emit(player_id, equip_id)
	return true


func get_national_items(player_id: int) -> Array:
	## Returns array of equipped national item IDs.
	if not _national_items.has(player_id):
		return []
	return _national_items[player_id].duplicate()


func get_national_item_details(player_id: int) -> Array:
	## Returns array of dicts with full item info for display.
	var result: Array = []
	for eid in get_national_items(player_id):
		var edef: Dictionary = FactionData.EQUIPMENT_DEFS.get(eid, {})
		result.append({
			"item_id": eid,
			"name": edef.get("name", eid),
			"desc": edef.get("desc", ""),
			"icon": edef.get("icon", ""),
			"rarity": edef.get("rarity", "common"),
			"stats": edef.get("stats", {}),
			"passive": edef.get("passive", "none"),
			"passive_value": edef.get("passive_value", 0),
		})
	return result


func get_national_stat_bonus(player_id: int, stat_key: String) -> int:
	## Get total stat bonus from all national items for a given stat.
	var total: int = 0
	for eid in get_national_items(player_id):
		var edef: Dictionary = FactionData.EQUIPMENT_DEFS.get(eid, {})
		total += edef.get("stats", {}).get(stat_key, 0)
	return total


func has_national_passive(player_id: int, passive_name: String) -> bool:
	## Check if any national item provides a specific passive.
	for eid in get_national_items(player_id):
		var edef: Dictionary = FactionData.EQUIPMENT_DEFS.get(eid, {})
		if edef.get("passive", "none") == passive_name:
			return true
	return false


# ═══════════════ LOOT TABLE (v0.8.7) ═══════════════

func get_random_item() -> String:
	## Weighted random selection from consumable ITEM_DEFS.
	var total_weight: float = 0.0
	for item_id in FactionData.ITEM_DEFS:
		total_weight += FactionData.ITEM_DEFS[item_id].get("weight", 1.0)

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for item_id in FactionData.ITEM_DEFS:
		cumulative += FactionData.ITEM_DEFS[item_id].get("weight", 1.0)
		if roll <= cumulative:
			return item_id

	return FactionData.ITEM_DEFS.keys().back()


func get_random_equipment() -> String:
	## Rarity-weighted random selection from EQUIPMENT_DEFS.
	## Uses drop_weight from each equipment definition.
	var total_weight: float = 0.0
	for equip_id in FactionData.EQUIPMENT_DEFS:
		total_weight += FactionData.EQUIPMENT_DEFS[equip_id].get("drop_weight", 10.0)

	var roll: float = randf() * total_weight
	var cumulative: float = 0.0
	for equip_id in FactionData.EQUIPMENT_DEFS:
		cumulative += FactionData.EQUIPMENT_DEFS[equip_id].get("drop_weight", 10.0)
		if roll <= cumulative:
			return equip_id

	return FactionData.EQUIPMENT_DEFS.keys().back()


func get_random_loot() -> String:
	## Roll for either consumable (70%) or equipment (30%).
	if randf() < 0.7:
		return get_random_item()
	else:
		return get_random_equipment()


func grant_random_loot(player_id: int) -> String:
	## Roll loot and add to player inventory. Returns item_id or "" if full.
	if is_full(player_id):
		EventBus.message_log.emit("[color=orange]背包已满, 战利品丢失![/color]")
		return ""
	var item_id: String = get_random_loot()
	add_item(player_id, item_id)
	return item_id


# ═══════════════ INTERNAL HELPERS ═══════════════

const ITEM_ICON_DIR: String = "res://assets/icons/items/"

static func get_icon_path(icon_name: String) -> String:
	## Resolve icon name to full path. Returns "" if no icon asset exists.
	if icon_name == "":
		return ""
	var path: String = ITEM_ICON_DIR + icon_name + ".png"
	if ResourceLoader.exists(path):
		return path
	return ""

func _get_item_name(item_id: String) -> String:
	if FactionData.ITEM_DEFS.has(item_id):
		return FactionData.ITEM_DEFS[item_id].get("name", item_id)
	if FactionData.EQUIPMENT_DEFS.has(item_id):
		return FactionData.EQUIPMENT_DEFS[item_id].get("name", item_id)
	return ""


func _get_item_display(item_id: String) -> Dictionary:
	## Build display dict for any item type.
	if FactionData.ITEM_DEFS.has(item_id):
		var def_data: Dictionary = FactionData.ITEM_DEFS[item_id]
		return {
			"item_id": item_id,
			"name": def_data.get("name", item_id),
			"desc": def_data.get("desc", ""),
			"type": "consumable",
			"icon": def_data.get("icon", ""),
		}
	elif FactionData.EQUIPMENT_DEFS.has(item_id):
		var def_data: Dictionary = FactionData.EQUIPMENT_DEFS[item_id]
		return {
			"item_id": item_id,
			"name": def_data.get("name", item_id),
			"desc": def_data.get("desc", ""),
			"type": "equipment",
			"rarity": def_data.get("rarity", "common"),
			"icon": def_data.get("icon", ""),
		}
	return {"item_id": item_id, "name": item_id, "desc": "", "type": "unknown", "icon": ""}


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"inventories": _inventories.duplicate(true),
		"national_items": _national_items.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_inventories = data.get("inventories", {}).duplicate(true)
	# Fix int keys after JSON round-trip (player_id keys become strings)
	var keys_to_fix: Array = []
	for k in _inventories:
		if k is String and k.is_valid_int():
			keys_to_fix.append(k)
	for k in keys_to_fix:
		_inventories[int(k)] = _inventories[k]
		_inventories.erase(k)
	_national_items = data.get("national_items", {}).duplicate(true)
	# BUG FIX R18: Fix int keys for national items (safe conversion with is_valid_int check)
	var fixed_nat := {}
	for key in _national_items:
		if key is String and key.is_valid_int():
			fixed_nat[int(key)] = _national_items[key]
		else:
			fixed_nat[key] = _national_items[key]
	_national_items = fixed_nat
