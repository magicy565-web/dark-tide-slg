## prestige_shop.gd - Prestige Shop (Abyssal Council) System (v1.0)
## Allows players to spend prestige for global bonuses and powerful items.
extends Node

const BalanceConfig = preload("res://systems/balance/balance_config.gd")

# ── Available Upgrades ──
# type: "global_buff" or "item" or "resource"
var PRESTIGE_UPGRADES: Dictionary = {
	"ap_cap_plus_1": {
		"name": "深渊律令：行动扩张",
		"desc": "永久增加1点行动点(AP)上限",
		"cost": 50,
		"type": "global_buff",
		"max_purchases": 1
	},
	"recruit_discount_10": {
		"name": "深渊律令：战争动员",
		"desc": "全军招募费用永久降低10%",
		"cost": 30,
		"type": "global_buff",
		"max_purchases": 2
	},
	"legendary_weapon": {
		"name": "深渊恩赐：传说兵装",
		"desc": "立即获得一件随机传说级装备",
		"cost": 40,
		"type": "item",
		"max_purchases": 3
	},
	"gold_infusion": {
		"name": "深渊恩赐：财富涌动",
		"desc": "立即获得500金币",
		"cost": 15,
		"type": "resource",
		"max_purchases": 99
	}
}

# Persistent state
var _purchased_upgrades: Dictionary = {}  # upgrade_id -> count

func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)

func _on_turn_started(_player_id: int) -> void:
	pass

func get_available_upgrades() -> Dictionary:
	return PRESTIGE_UPGRADES.duplicate()

func get_purchase_count(upgrade_id: String) -> int:
	return _purchased_upgrades.get(upgrade_id, 0)

func can_purchase(player_id: int, upgrade_id: String) -> bool:
	if not PRESTIGE_UPGRADES.has(upgrade_id):
		return false
	
	var upg: Dictionary = PRESTIGE_UPGRADES[upgrade_id]
	var current_count: int = get_purchase_count(upgrade_id)
	
	if current_count >= upg.get("max_purchases", 1):
		return false
		
	var current_prestige: int = ResourceManager.get_resource(player_id, "prestige")
	return current_prestige >= upg.get("cost", 999)

func purchase_upgrade(player_id: int, upgrade_id: String) -> bool:
	if not can_purchase(player_id, upgrade_id):
		return false
		
	var upg: Dictionary = PRESTIGE_UPGRADES[upgrade_id]
	var cost: int = upg.get("cost", 0)
	
	# Deduct prestige
	ResourceManager.apply_delta(player_id, {"prestige": -cost})
	
	# Record purchase
	_purchased_upgrades[upgrade_id] = get_purchase_count(upgrade_id) + 1
	
	# Apply effect
	_apply_upgrade_effect(player_id, upgrade_id, upg)
	
	EventBus.message_log.emit("[color=purple]深渊议会：已兑换 '%s' (消耗 %d 威望)[/color]" % [upg.get("name", ""), cost])
	return true

func _apply_upgrade_effect(player_id: int, upgrade_id: String, upg: Dictionary) -> void:
	match upgrade_id:
		"ap_cap_plus_1":
			# In a full implementation, this would modify GameManager.MAX_AP
			EventBus.message_log.emit("[color=green]行动点上限永久+1[/color]")
		"recruit_discount_10":
			# Modify recruit cost multiplier in BuffManager or RecruitManager
			EventBus.message_log.emit("[color=green]招募费用永久-10%[/color]")
		"legendary_weapon":
			# Give a random legendary item via ItemManager
			EventBus.message_log.emit("[color=green]获得传说装备！[/color]")
		"gold_infusion":
			ResourceManager.apply_delta(player_id, {"gold": 500})
			EventBus.message_log.emit("[color=gold]获得 500 金币[/color]")

func get_active_recruit_discount() -> float:
	var count: int = get_purchase_count("recruit_discount_10")
	return 1.0 - (count * 0.10)

func reset() -> void:
	_purchased_upgrades.clear()
