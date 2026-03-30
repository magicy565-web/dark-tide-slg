## equipment_forge.gd — Equipment Crafting & Legendary Item Creation for 暗潮 SLG
## Manages forge queue, recipe prerequisites, legendary uniqueness, and item completion.
class_name EquipmentForge
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# CRAFTING RECIPES
# ═══════════════════════════════════════════════════════════════════════════════

const RECIPES: Dictionary = {
	# ── Weapons ──
	"iron_sword": {
		"name": "鉄の剣", "type": "weapon", "slot": "weapon",
		"cost": {"gold": 50, "iron": 3}, "turns": 1,
		"stats": {"atk": 3}, "desc": "基本的な鉄の武器",
	},
	"steel_blade": {
		"name": "鋼の刃", "type": "weapon", "slot": "weapon",
		"cost": {"gold": 120, "iron": 6}, "turns": 2, "prereq": "iron_sword",
		"stats": {"atk": 6, "spd": 1}, "desc": "精錬された鋼の武器",
	},
	"dark_flame_sword": {
		"name": "暗炎の剣", "type": "weapon", "slot": "weapon",
		"cost": {"gold": 300, "iron": 8, "shadow": 3}, "turns": 3, "prereq": "steel_blade",
		"stats": {"atk": 10, "spd": 2}, "passive": "burn_on_hit", "desc": "闇の炎を纏う魔剣",
	},
	# ── Armor ──
	"leather_armor": {
		"name": "革鎧", "type": "armor", "slot": "body",
		"cost": {"gold": 40, "iron": 2}, "turns": 1,
		"stats": {"def": 3}, "desc": "基本的な革鎧",
	},
	"plate_armor": {
		"name": "鉄壁の鎧", "type": "armor", "slot": "body",
		"cost": {"gold": 150, "iron": 8}, "turns": 2, "prereq": "leather_armor",
		"stats": {"def": 7, "spd": -1}, "desc": "重厚な板金鎧",
	},
	"shadow_cloak": {
		"name": "影隠しの外套", "type": "armor", "slot": "body",
		"cost": {"gold": 200, "shadow": 4}, "turns": 2,
		"stats": {"def": 4, "spd": 3}, "passive": "stealth_first_turn", "desc": "初回合ステルス",
	},
	# ── Accessories ──
	"war_drum": {
		"name": "戦太鼓", "type": "accessory", "slot": "accessory",
		"cost": {"gold": 80, "iron": 2}, "turns": 1,
		"stats": {"morale": 10}, "desc": "全軍士気+10",
	},
	"crystal_orb": {
		"name": "水晶球", "type": "accessory", "slot": "accessory",
		"cost": {"gold": 150, "crystal": 3}, "turns": 2,
		"stats": {"int": 5, "mana": 3}, "desc": "魔法強化",
	},
	"phoenix_feather": {
		"name": "不死鳥の羽", "type": "accessory", "slot": "accessory",
		"cost": {"gold": 300, "crystal": 5, "shadow": 2}, "turns": 3,
		"stats": {"hp_regen": 3}, "passive": "revive_once", "desc": "一度だけ復活",
	},
	# ── Legendary (unique, one per game) ──
	"gork_cleaver": {
		"name": "ゴルクの肉断ち", "type": "weapon", "slot": "weapon",
		"cost": {"gold": 500, "iron": 15, "shadow": 5}, "turns": 4, "legendary": true,
		"stats": {"atk": 15, "spd": -2}, "passive": "cleave_aoe", "desc": "WAAAGH! AoE打撃",
	},
	"black_flag": {
		"name": "黒旗", "type": "accessory", "slot": "accessory",
		"cost": {"gold": 400, "gunpowder": 8}, "turns": 3, "legendary": true,
		"stats": {"morale": 20}, "passive": "fear_aura", "desc": "敵ATK-20%",
	},
	"void_crown": {
		"name": "虚無の冠", "type": "accessory", "slot": "accessory",
		"cost": {"gold": 600, "shadow": 10, "crystal": 5}, "turns": 5, "legendary": true,
		"stats": {"int": 10, "def": 5}, "passive": "mind_control", "desc": "1敵ユニット支配",
	},
}

# Forge level requirements: recipe_id -> minimum forge level needed
const RECIPE_LEVEL_REQS: Dictionary = {
	# Level 1 — basic items
	"iron_sword": 1, "leather_armor": 1, "war_drum": 1,
	# Level 2 — intermediate + shadow items
	"steel_blade": 2, "plate_armor": 2, "shadow_cloak": 2,
	"crystal_orb": 2, "phoenix_feather": 2,
	# Level 3 — legendary + advanced
	"dark_flame_sword": 3, "gork_cleaver": 3, "black_flag": 3, "void_crown": 3,
}

# Forge upgrade costs per target level
const FORGE_UPGRADE_COST: Dictionary = {
	2: {"gold": 200, "iron": 10},
	3: {"gold": 500, "iron": 20, "crystal": 5},
}

const MAX_FORGE_LEVEL: int = 3
const MAX_QUEUE_SIZE: int = 3
const CANCEL_REFUND_RATE: float = 0.5


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

# [{recipe_id: String, player_id: int, progress: int, total_turns: int}]
var _forge_queue: Array = []
# player_id -> [recipe_id strings that have been completed]
var _crafted_items: Dictionary = {}
# Globally tracked legendary items already crafted (one per game)
var _legendary_crafted: Array = []
# player_id -> int (1–3)
var _forge_level: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func reset() -> void:
	_forge_queue.clear()
	_crafted_items.clear()
	_legendary_crafted.clear()
	_forge_level.clear()


func init_player(player_id: int) -> void:
	if not _crafted_items.has(player_id):
		_crafted_items[player_id] = []
	if not _forge_level.has(player_id):
		_forge_level[player_id] = 1


# ═══════════════════════════════════════════════════════════════════════════════
# FORGE LEVEL
# ═══════════════════════════════════════════════════════════════════════════════

func get_forge_level(player_id: int) -> int:
	return _forge_level.get(player_id, 1)


func upgrade_forge(player_id: int) -> bool:
	var current: int = get_forge_level(player_id)
	if current >= MAX_FORGE_LEVEL:
		EventBus.message_log.emit("[鍛冶場] レベル最大です")
		return false
	var target: int = current + 1
	var cost: Dictionary = FORGE_UPGRADE_COST.get(target, {})
	if cost.is_empty():
		return false
	if not ResourceManager.can_afford(player_id, cost):
		EventBus.message_log.emit("[鍛冶場] 資源不足でアップグレードできません")
		return false
	ResourceManager.spend(player_id, cost)
	_forge_level[player_id] = target
	EventBus.message_log.emit("[鍛冶場] レベル%dにアップグレード!" % target)
	EventBus.debug_log.emit("info", "Forge upgraded to level %d for player %d" % [target, player_id])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RECIPE AVAILABILITY
# ═══════════════════════════════════════════════════════════════════════════════

func get_available_recipes(player_id: int) -> Array:
	## Returns array of recipe_id strings the player can see (unlocked by forge level,
	## prerequisites met, and legendary not already claimed).
	var level: int = get_forge_level(player_id)
	var crafted: Array = _crafted_items.get(player_id, [])
	var result: Array = []
	for recipe_id in RECIPES:
		var recipe: Dictionary = RECIPES[recipe_id]
		# Forge level gate
		var req_level: int = RECIPE_LEVEL_REQS.get(recipe_id, 1)
		if level < req_level:
			continue
		# Prerequisite check — player must have crafted the prereq at some point
		var prereq: String = recipe.get("prereq", "")
		if prereq != "" and prereq not in crafted:
			continue
		# Legendary uniqueness — globally one per game
		if recipe.get("legendary", false) and recipe_id in _legendary_crafted:
			continue
		result.append(recipe_id)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# CRAFTING VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

func can_craft(player_id: int, recipe_id: String) -> Dictionary:
	## Returns {can_craft: bool, reason: String, missing_resources: Dictionary}.
	var result: Dictionary = {"can_craft": false, "reason": "", "missing_resources": {}}

	# Recipe existence
	if not RECIPES.has(recipe_id):
		result["reason"] = "不明なレシピ: %s" % recipe_id
		return result

	var recipe: Dictionary = RECIPES[recipe_id]

	# Forge level
	var req_level: int = RECIPE_LEVEL_REQS.get(recipe_id, 1)
	var level: int = get_forge_level(player_id)
	if level < req_level:
		result["reason"] = "鍛冶場レベル%d必要 (現在: %d)" % [req_level, level]
		return result

	# Prerequisite
	var prereq: String = recipe.get("prereq", "")
	var crafted: Array = _crafted_items.get(player_id, [])
	if prereq != "" and prereq not in crafted:
		var prereq_name: String = RECIPES.get(prereq, {}).get("name", prereq)
		result["reason"] = "前提アイテム未作成: %s" % prereq_name
		return result

	# Legendary uniqueness
	if recipe.get("legendary", false) and recipe_id in _legendary_crafted:
		result["reason"] = "伝説装備は一度しか作成できません"
		return result

	# Queue capacity
	var player_queue: Array = _get_player_queue(player_id)
	if player_queue.size() >= MAX_QUEUE_SIZE:
		result["reason"] = "鍛冶キューが満杯です (最大%d)" % MAX_QUEUE_SIZE
		return result

	# Already crafting same legendary
	if recipe.get("legendary", false):
		for entry in _forge_queue:
			if entry["recipe_id"] == recipe_id:
				result["reason"] = "この伝説装備は既に鍛造中です"
				return result

	# Resource check
	var cost: Dictionary = recipe.get("cost", {})
	var missing: Dictionary = {}
	for res_key in cost:
		var have: int = ResourceManager.get_resource(player_id, res_key)
		var need: int = cost[res_key]
		if have < need:
			missing[res_key] = need - have
	if not missing.is_empty():
		result["reason"] = "資源不足"
		result["missing_resources"] = missing
		return result

	result["can_craft"] = true
	result["reason"] = "作成可能"
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# CRAFTING — START / CANCEL
# ═══════════════════════════════════════════════════════════════════════════════

func start_crafting(player_id: int, recipe_id: String) -> bool:
	## Deducts resources and adds recipe to the forge queue. Returns true on success.
	var check: Dictionary = can_craft(player_id, recipe_id)
	if not check["can_craft"]:
		EventBus.message_log.emit("[鍛冶場] 作成不可: %s" % check["reason"])
		return false

	var recipe: Dictionary = RECIPES[recipe_id]
	var cost: Dictionary = recipe.get("cost", {})

	# Spend resources
	if not ResourceManager.spend(player_id, cost):
		EventBus.message_log.emit("[鍛冶場] 資源不足")
		return false

	# Reserve legendary slot immediately
	if recipe.get("legendary", false):
		_legendary_crafted.append(recipe_id)

	# Add to queue
	var entry: Dictionary = {
		"recipe_id": recipe_id,
		"player_id": player_id,
		"progress": 0,
		"total_turns": recipe.get("turns", 1),
	}
	_forge_queue.append(entry)

	var recipe_name: String = recipe.get("name", recipe_id)
	EventBus.message_log.emit("[鍛冶場] %s の鍛造を開始 (%dターン)" % [recipe_name, entry["total_turns"]])
	EventBus.debug_log.emit("info", "Crafting started: %s for player %d (%d turns)" % [recipe_id, player_id, entry["total_turns"]])
	return true


func cancel_crafting(player_id: int, queue_index: int) -> bool:
	## Cancel an in-progress craft. Refunds 50% of the cost. Returns true on success.
	var player_queue: Array = _get_player_queue(player_id)
	if queue_index < 0 or queue_index >= player_queue.size():
		EventBus.message_log.emit("[鍛冶場] 無効なキューインデックス")
		return false

	var entry: Dictionary = player_queue[queue_index]
	var recipe_id: String = entry["recipe_id"]
	var recipe: Dictionary = RECIPES.get(recipe_id, {})
	if recipe.is_empty():
		return false

	# Remove from global queue
	var global_idx: int = _forge_queue.find(entry)
	if global_idx >= 0:
		_forge_queue.remove_at(global_idx)

	# Un-reserve legendary slot if cancelled
	if recipe.get("legendary", false):
		var leg_idx: int = _legendary_crafted.find(recipe_id)
		if leg_idx >= 0:
			_legendary_crafted.remove_at(leg_idx)

	# Refund 50%
	var cost: Dictionary = recipe.get("cost", {})
	var refund: Dictionary = {}
	for res_key in cost:
		var amount: int = int(float(cost[res_key]) * CANCEL_REFUND_RATE)
		if amount > 0:
			refund[res_key] = amount
	if not refund.is_empty():
		ResourceManager.apply_delta(player_id, refund)

	var recipe_name: String = recipe.get("name", recipe_id)
	EventBus.message_log.emit("[鍛冶場] %s の鍛造をキャンセル (50%%返金)" % recipe_name)
	EventBus.debug_log.emit("info", "Crafting cancelled: %s for player %d" % [recipe_id, player_id])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TURN PROCESSING
# ═══════════════════════════════════════════════════════════════════════════════

func process_turn(player_id: int) -> void:
	## Advance crafting progress for all of this player's queue entries.
	## Complete any items that reach their turn requirement.
	var completed: Array = []
	for entry in _forge_queue:
		if entry["player_id"] != player_id:
			continue
		entry["progress"] += 1
		if entry["progress"] >= entry["total_turns"]:
			completed.append(entry)

	for entry in completed:
		_complete_crafting(entry["player_id"], entry["recipe_id"])
		_forge_queue.erase(entry)


func _complete_crafting(player_id: int, recipe_id: String) -> void:
	## Finalize a crafted item: register it, add to inventory, emit signals.
	var recipe: Dictionary = RECIPES.get(recipe_id, {})
	if recipe.is_empty():
		push_warning("EquipmentForge: Unknown recipe_id in _complete_crafting: %s" % recipe_id)
		return

	# Track as crafted for this player (prerequisite chain)
	if not _crafted_items.has(player_id):
		_crafted_items[player_id] = []
	_crafted_items[player_id].append(recipe_id)

	# Add to player inventory via ItemManager
	var added: bool = ItemManager.add_item(player_id, recipe_id)
	if not added:
		# Inventory full — item is still tracked as crafted but player needs to free space
		EventBus.message_log.emit("[鍛冶場] %s 完成! しかし背包が満杯です — 空きを作ってください" % recipe.get("name", recipe_id))
		# Re-attempt add via a holding pattern: store in a completion buffer
		_store_unclaimed_item(player_id, recipe_id)
		return

	var recipe_name: String = recipe.get("name", recipe_id)
	var is_legendary: bool = recipe.get("legendary", false)

	if is_legendary:
		EventBus.message_log.emit("[color=orange][鍛冶場] ★伝説装備完成★ %s[/color]" % recipe_name)
	else:
		EventBus.message_log.emit("[鍛冶場] %s の鍛造が完了しました!" % recipe_name)

	EventBus.item_acquired.emit(player_id, recipe_name)
	EventBus.debug_log.emit("info", "Crafting complete: %s for player %d" % [recipe_name, player_id])


# ═══════════════════════════════════════════════════════════════════════════════
# UNCLAIMED ITEM BUFFER (inventory-full fallback)
# ═══════════════════════════════════════════════════════════════════════════════

# player_id -> [recipe_id] items waiting to be claimed
var _unclaimed_items: Dictionary = {}

func _store_unclaimed_item(player_id: int, recipe_id: String) -> void:
	if not _unclaimed_items.has(player_id):
		_unclaimed_items[player_id] = []
	_unclaimed_items[player_id].append(recipe_id)


func claim_unclaimed_items(player_id: int) -> int:
	## Try to move unclaimed crafted items into inventory. Returns count claimed.
	if not _unclaimed_items.has(player_id):
		return 0
	var pending: Array = _unclaimed_items[player_id].duplicate()
	var claimed: int = 0
	for recipe_id in pending:
		if ItemManager.add_item(player_id, recipe_id):
			_unclaimed_items[player_id].erase(recipe_id)
			var recipe: Dictionary = RECIPES.get(recipe_id, {})
			var recipe_name: String = recipe.get("name", recipe_id)
			EventBus.item_acquired.emit(player_id, recipe_name)
			EventBus.message_log.emit("[鍛冶場] 未受取アイテム受領: %s" % recipe_name)
			claimed += 1
		else:
			break  # Inventory still full
	if _unclaimed_items[player_id].is_empty():
		_unclaimed_items.erase(player_id)
	return claimed


func get_unclaimed_count(player_id: int) -> int:
	return _unclaimed_items.get(player_id, []).size()


# ═══════════════════════════════════════════════════════════════════════════════
# QUEUE QUERIES
# ═══════════════════════════════════════════════════════════════════════════════

func get_forge_queue(player_id: int) -> Array:
	## Returns array of queue entry dicts for UI display.
	var result: Array = []
	for entry in _forge_queue:
		if entry["player_id"] != player_id:
			continue
		var recipe: Dictionary = RECIPES.get(entry["recipe_id"], {})
		result.append({
			"recipe_id": entry["recipe_id"],
			"name": recipe.get("name", entry["recipe_id"]),
			"progress": entry["progress"],
			"total_turns": entry["total_turns"],
			"remaining": entry["total_turns"] - entry["progress"],
			"type": recipe.get("type", ""),
			"legendary": recipe.get("legendary", false),
		})
	return result


func _get_player_queue(player_id: int) -> Array:
	## Internal: returns raw queue entries for a specific player.
	var result: Array = []
	for entry in _forge_queue:
		if entry["player_id"] == player_id:
			result.append(entry)
	return result


func is_recipe_in_queue(player_id: int, recipe_id: String) -> bool:
	## Check if a specific recipe is already being crafted by this player.
	for entry in _forge_queue:
		if entry["player_id"] == player_id and entry["recipe_id"] == recipe_id:
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# RECIPE DISPLAY HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func get_recipe_display(recipe_id: String) -> Dictionary:
	## Returns a UI-friendly dict describing a recipe.
	var recipe: Dictionary = RECIPES.get(recipe_id, {})
	if recipe.is_empty():
		return {}
	return {
		"id": recipe_id,
		"name": recipe.get("name", recipe_id),
		"type": recipe.get("type", ""),
		"slot": recipe.get("slot", ""),
		"cost": recipe.get("cost", {}),
		"turns": recipe.get("turns", 1),
		"stats": recipe.get("stats", {}),
		"passive": recipe.get("passive", ""),
		"desc": recipe.get("desc", ""),
		"legendary": recipe.get("legendary", false),
		"prereq": recipe.get("prereq", ""),
		"prereq_name": RECIPES.get(recipe.get("prereq", ""), {}).get("name", ""),
		"forge_level_req": RECIPE_LEVEL_REQS.get(recipe_id, 1),
	}


func get_all_recipe_displays(player_id: int) -> Array:
	## Returns display data for all recipes, with availability status.
	var result: Array = []
	var available: Array = get_available_recipes(player_id)
	for recipe_id in RECIPES:
		var display: Dictionary = get_recipe_display(recipe_id)
		display["available"] = recipe_id in available
		display["check"] = can_craft(player_id, recipe_id)
		display["in_queue"] = is_recipe_in_queue(player_id, recipe_id)
		result.append(display)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# CRAFTED ITEM QUERIES
# ═══════════════════════════════════════════════════════════════════════════════

func get_crafted_items(player_id: int) -> Array:
	## Returns list of recipe_ids this player has ever crafted.
	return _crafted_items.get(player_id, []).duplicate()


func has_crafted(player_id: int, recipe_id: String) -> bool:
	return recipe_id in _crafted_items.get(player_id, [])


func is_legendary_available(recipe_id: String) -> bool:
	## Returns true if this legendary recipe has not been crafted by anyone this game.
	var recipe: Dictionary = RECIPES.get(recipe_id, {})
	if not recipe.get("legendary", false):
		return true  # Not legendary, always "available" in this sense
	return recipe_id not in _legendary_crafted


# ═══════════════════════════════════════════════════════════════════════════════
# ITEM STAT HELPERS (for combat / equip integration)
# ═══════════════════════════════════════════════════════════════════════════════

func get_item_stats(recipe_id: String) -> Dictionary:
	## Returns the stat bonuses dict for a crafted item.
	var recipe: Dictionary = RECIPES.get(recipe_id, {})
	return recipe.get("stats", {}).duplicate()


func get_item_passive(recipe_id: String) -> String:
	## Returns the passive ability key for a crafted item, or "".
	var recipe: Dictionary = RECIPES.get(recipe_id, {})
	return recipe.get("passive", "")


func is_legendary_item(recipe_id: String) -> bool:
	var recipe: Dictionary = RECIPES.get(recipe_id, {})
	return recipe.get("legendary", false)


# ═══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD
# ═══════════════════════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	return {
		"forge_queue": _forge_queue.duplicate(true),
		"crafted_items": _crafted_items.duplicate(true),
		"legendary_crafted": _legendary_crafted.duplicate(),
		"forge_level": _forge_level.duplicate(),
		"unclaimed_items": _unclaimed_items.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_forge_queue = data.get("forge_queue", []).duplicate(true)
	_crafted_items = data.get("crafted_items", {}).duplicate(true)
	_legendary_crafted = data.get("legendary_crafted", []).duplicate()
	_forge_level = data.get("forge_level", {}).duplicate()
	_unclaimed_items = data.get("unclaimed_items", {}).duplicate(true)
	# Validate loaded legendary entries still match existing recipes
	var valid_legendary: Array = []
	for rid in _legendary_crafted:
		if RECIPES.has(rid) and RECIPES[rid].get("legendary", false):
			valid_legendary.append(rid)
	_legendary_crafted = valid_legendary
