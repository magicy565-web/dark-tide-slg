## pirate_mechanic.gd - Black Market, Plunder, and Pirate-specific logic
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Black Market inventory (refreshes each turn) ──
var _market_item: Dictionary = {}  # current random item for sale
var _bonus_plunder: Dictionary = {}  # player_id -> int (accumulated bonus plunder)

# ── Item pool for Black Market random stock ──
const MARKET_ITEMS: Array = [
	{"name": "走私军火", "desc": "战力+15", "effect": "atk_boost", "value": 15, "price": 60},
	{"name": "海盗旗", "desc": "威望+3", "effect": "prestige", "value": 3, "price": 40},
	{"name": "朗姆酒桶", "desc": "粮草+8", "effect": "food", "value": 8, "price": 30},
	{"name": "黑火药", "desc": "下次攻击伤害+25", "effect": "atk_boost", "value": 25, "price": 80},
	{"name": "藏宝图", "desc": "金币+80", "effect": "gold", "value": 80, "price": 50},
	{"name": "铁锚碎片", "desc": "铁矿+5", "effect": "iron", "value": 5, "price": 35},
]


func _ready() -> void:
	pass


func reset() -> void:
	_market_item = {}
	_bonus_plunder.clear()


# ═══════════════ TURN TICK ═══════════════

func tick(player_id: int) -> void:
	## Called each turn for Pirate players. Refreshes black market.
	_refresh_market()

	# Smuggler's Den loot bonus is handled in production_calculator
	# Plunder value displayed in UI


func _refresh_market() -> void:
	_market_item = MARKET_ITEMS[randi_range(0, MARKET_ITEMS.size() - 1)].duplicate()
	EventBus.message_log.emit("黑市今日商品: %s (%s) - %d金" % [
		_market_item["name"], _market_item["desc"], _market_item["price"]])


# ═══════════════ BLACK MARKET ═══════════════

func get_market_item() -> Dictionary:
	return _market_item.duplicate()


func buy_market_item(player_id: int) -> bool:
	if _market_item.is_empty():
		EventBus.message_log.emit("黑市暂无商品")
		return false
	var price: int = _market_item["price"]
	if not ResourceManager.spend(player_id, {"gold": price}):
		EventBus.message_log.emit("金币不足! 需要%d金" % price)
		return false

	_apply_market_effect(player_id, _market_item)
	EventBus.message_log.emit("购买了 %s!" % _market_item["name"])
	_market_item = {}  # Sold out
	return true


func sell_slave(player_id: int) -> bool:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.PIRATE]
	var slaves: int = ResourceManager.get_slaves(player_id)
	if slaves <= 0:
		EventBus.message_log.emit("没有奴隶可出售!")
		return false
	ResourceManager.apply_delta(player_id, {"slaves": -1, "gold": params["slave_sell_price"]})
	SlaveManager.remove_slaves(player_id, 1)
	EventBus.message_log.emit("出售1名奴隶，获得%d金" % params["slave_sell_price"])
	return true


func buy_slave(player_id: int) -> bool:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.PIRATE]
	var price: int = params["slave_buy_price"]
	if not ResourceManager.can_afford(player_id, {"gold": price}):
		EventBus.message_log.emit("金币不足! 购买奴隶需要%d金" % price)
		return false
	var cap: int = ResourceManager.get_slave_capacity(player_id)
	var current: int = ResourceManager.get_slaves(player_id)
	if current >= cap:
		EventBus.message_log.emit("奴隶容量已满!")
		return false
	ResourceManager.spend(player_id, {"gold": price})
	ResourceManager.apply_delta(player_id, {"slaves": 1})
	SlaveManager.add_slaves(player_id, 1)
	EventBus.message_log.emit("购买1名奴隶，花费%d金" % price)
	return true


# ═══════════════ PLUNDER ═══════════════

func add_plunder_bonus(player_id: int, amount: int) -> void:
	_bonus_plunder[player_id] = _bonus_plunder.get(player_id, 0) + amount


func get_plunder_value(player_id: int) -> int:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.PIRATE]
	var owned: int = GameManager.count_tiles_owned(player_id)
	return params["plunder_base_per_tile"] * owned + _bonus_plunder.get(player_id, 0)


func on_stronghold_captured(player_id: int) -> void:
	## Pirate bonus: plunder * 10 gold on stronghold capture.
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.PIRATE]
	var plunder: int = get_plunder_value(player_id)
	var bonus_gold: int = plunder * params["stronghold_capture_plunder_mult"]
	ResourceManager.apply_delta(player_id, {"gold": bonus_gold})
	EventBus.message_log.emit("[color=gold]海盗掠夺! 攻占要塞奖励%d金 (掠夺值%d x %d)[/color]" % [
		bonus_gold, plunder, params["stronghold_capture_plunder_mult"]])


# ═══════════════ LOOT BONUS ═══════════════

func get_loot_multiplier(player_id: int) -> float:
	## Returns loot multiplier (1.0 base, +0.5 from Smuggler's Den).
	var mult: float = 1.0
	for tile in GameManager.tiles:
		if tile["owner_id"] == player_id and tile.get("building_id", "") == "smugglers_den":
			mult += 0.5
			break  # Only one bonus
	return mult


# ═══════════════ INTERNAL ═══════════════

func _apply_market_effect(player_id: int, item: Dictionary) -> void:
	match item["effect"]:
		"atk_boost":
			# Store as temporary bonus in GameManager player data
			var player: Dictionary = GameManager.get_player_by_id(player_id)
			player["atk_bonus"] = player.get("atk_bonus", 0) + item["value"]
		"prestige":
			ResourceManager.apply_delta(player_id, {"prestige": item["value"]})
		"food":
			ResourceManager.apply_delta(player_id, {"food": item["value"]})
		"gold":
			ResourceManager.apply_delta(player_id, {"gold": item["value"]})
		"iron":
			ResourceManager.apply_delta(player_id, {"iron": item["value"]})


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"market_item": _market_item.duplicate(true),
		"bonus_plunder": _bonus_plunder.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_market_item = data.get("market_item", {}).duplicate(true)
	_bonus_plunder = data.get("bonus_plunder", {}).duplicate(true)
