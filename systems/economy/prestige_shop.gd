## prestige_shop.gd - Prestige Shop (Abyssal Council) System (v1.1)
## Allows players to spend prestige for global bonuses and powerful items.
## v1.1: Fixed ap_cap_plus_1 and recruit_discount_10 to actually apply effects.
extends Node

const BalanceConfig = preload("res://systems/balance/balance_config.gd")

# ── Available Upgrades ──
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
# v1.1: AP cap bonus from prestige shop (added to calculate_action_points)
var _ap_cap_bonus: int = 0

func _ready() -> void:
	pass

func get_available_upgrades() -> Dictionary:
	return PRESTIGE_UPGRADES.duplicate()

func get_purchase_count(upgrade_id: String) -> int:
	return _purchased_upgrades.get(upgrade_id, 0)

## v1.1: Returns the AP cap bonus granted by prestige upgrades.
## Called by GameManager.calculate_action_points().
func get_ap_cap_bonus() -> int:
	return _ap_cap_bonus

## v1.1: Returns the recruit cost multiplier from prestige upgrades.
## Called by RecruitManager._get_recruit_discount().
func get_recruit_discount() -> float:
	var count: int = get_purchase_count("recruit_discount_10")
	return count * 0.10  # Each purchase = 10% discount

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

func _apply_upgrade_effect(player_id: int, upgrade_id: String, _upg: Dictionary) -> void:
	match upgrade_id:
		"ap_cap_plus_1":
			# v1.1: Actually increment the AP cap bonus tracked by this singleton.
			# GameManager.calculate_action_points() reads PrestigeShop.get_ap_cap_bonus().
			_ap_cap_bonus += 1
			EventBus.message_log.emit("[color=green]行动点上限永久+1 (当前加成: +%d)[/color]" % _ap_cap_bonus)
		"recruit_discount_10":
			# v1.1: Discount is read by RecruitManager._get_recruit_discount() via
			# PrestigeShop.get_recruit_discount(). No extra state needed here.
			var total_discount: float = get_recruit_discount() * 100.0
			EventBus.message_log.emit("[color=green]招募费用永久-10%% (当前总折扣: %.0f%%)[/color]" % total_discount)
		"legendary_weapon":
			# Give a random legendary item via ItemManager if available
			if ItemManager != null and ItemManager.has_method("grant_random_legendary"):
				ItemManager.grant_random_legendary(player_id)
			else:
				# Fallback: grant gold equivalent
				ResourceManager.apply_delta(player_id, {"gold": 200})
				EventBus.message_log.emit("[color=purple]获得传说装备补偿金 200 金币[/color]")
		"gold_infusion":
			ResourceManager.apply_delta(player_id, {"gold": 500})
			EventBus.message_log.emit("[color=gold]获得 500 金币[/color]")

func reset() -> void:
	_purchased_upgrades.clear()
	_ap_cap_bonus = 0

# ── Save / Load ──
func to_save_data() -> Dictionary:
	return {
		"purchased_upgrades": _purchased_upgrades.duplicate(),
		"ap_cap_bonus": _ap_cap_bonus,
	}

func from_save_data(data: Dictionary) -> void:
	_purchased_upgrades = data.get("purchased_upgrades", {})
	_ap_cap_bonus = int(data.get("ap_cap_bonus", 0))
