extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## item_manager.gd - Inventory management for consumables and equipment (v0.8.7)
## Handles both ITEM_DEFS (consumables) and EQUIPMENT_DEFS (equippable gear).
## Equipment items live in inventory until equipped on a hero via HeroSystem.

const MAX_ITEMS: int = 8  # Increased from 4 to accommodate equipment

# Per-player inventories: { player_id: Array of item_id strings }
# Contains both consumable IDs (from ITEM_DEFS) and equipment IDs (from EQUIPMENT_DEFS)
var _inventories: Dictionary = {}

func _ready() -> void:
	pass

func reset() -> void:
	_inventories.clear()

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
	var item_data: Dictionary = FactionData.ITEM_DEFS[item_id]
	var effect: Dictionary = item_data.get("effect", {})

	# Immediate resource effects
	if effect.has("gold"):
		ResourceManager.apply_delta(player_id, {"gold": effect["gold"]})
		EventBus.message_log.emit("使用 %s: +%d金币" % [item_data["name"], effect["gold"]])
	elif effect.has("food"):
		ResourceManager.apply_delta(player_id, {"food": effect["food"]})
		EventBus.message_log.emit("使用 %s: +%d粮草" % [item_data["name"], effect["food"]])
	elif effect.has("iron"):
		ResourceManager.apply_delta(player_id, {"iron": effect["iron"]})
		EventBus.message_log.emit("使用 %s: +%d铁矿" % [item_data["name"], effect["iron"]])
	elif effect.has("heal"):
		ResourceManager.add_army(player_id, effect["heal"])
		EventBus.message_log.emit("使用 %s: 恢复%d兵力" % [item_data["name"], effect["heal"]])
	elif effect.has("dice_bonus"):
		BuffManager.add_buff(player_id, "item_dice", "dice_bonus", effect["dice_bonus"], 1, "item")
		EventBus.message_log.emit("使用 %s: 本回合骰子+%d" % [item_data["name"], effect["dice_bonus"]])
	elif effect.has("atk_mult"):
		BuffManager.add_buff(player_id, "item_atk", "atk_mult", effect["atk_mult"], 1, "item")
		EventBus.message_log.emit("使用 %s: 下次战斗攻击+30%%" % item_data["name"])
	elif effect.has("def_mult"):
		BuffManager.add_buff(player_id, "item_def", "def_mult", effect["def_mult"], 1, "item")
		EventBus.message_log.emit("使用 %s: 下次战斗防御+30%%" % item_data["name"])
	elif effect.has("guaranteed_slave"):
		BuffManager.add_buff(player_id, "item_slave", "guaranteed_slave", true, 1, "item")
		EventBus.message_log.emit("使用 %s: 下次战斗必定俘获奴隶" % item_data["name"])
	elif effect.has("mage_weaken"):
		BuffManager.add_buff(player_id, "item_mage_weak", "mage_weaken", effect["mage_weaken"], 5, "item")
		EventBus.message_log.emit("使用 %s: 法师效果减半(5回合)" % item_data["name"])
	elif effect.has("wall_damage"):
		# Stored as buff; applied at next siege combat
		BuffManager.add_buff(player_id, "item_wall_dmg", "wall_damage", effect["wall_damage"], 1, "item")
		EventBus.message_log.emit("使用 %s: 下次攻城削减%d城防" % [item_data["name"], effect["wall_damage"]])

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
		}
	elif FactionData.EQUIPMENT_DEFS.has(item_id):
		var def_data: Dictionary = FactionData.EQUIPMENT_DEFS[item_id]
		var slot_name: String = FactionData.EQUIP_SLOT_NAMES.get(def_data.get("slot", 0), "饰品")
		return {
			"item_id": item_id,
			"name": def_data.get("name", item_id),
			"desc": def_data.get("desc", ""),
			"type": "equipment",
			"slot": slot_name,
			"rarity": def_data.get("rarity", "common"),
		}
	return {"item_id": item_id, "name": item_id, "desc": "", "type": "unknown"}


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"inventories": _inventories.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_inventories = data.get("inventories", {}).duplicate(true)
