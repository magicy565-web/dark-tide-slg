## ngplus_shop.gd - NG+ Score Shop (v1.0)
## Allows players to spend their previous clear score for starting bonuses.
extends Node

const BalanceConfig = preload("res://systems/balance/balance_config.gd")

var AVAILABLE_BONUSES: Dictionary = {
	"inherit_legendary": {
		"name": "传说传承",
		"desc": "开局获得一件随机传说装备",
		"cost": 500,
		"max": 2
	},
	"unlock_neutral_hanabi": {
		"name": "地精的效忠",
		"desc": "开局直接获得中立英雄'爆破女王·花火'的效忠",
		"cost": 800,
		"max": 1
	},
	"starting_ap_plus_1": {
		"name": "先发制人",
		"desc": "开局行动点(AP)上限+1",
		"cost": 1000,
		"max": 1
	},
	"what_if_hard_mode": {
		"name": "挑战剧本：殊死抵抗",
		"desc": "光明方开局即处于最高威胁等级(80+)，但通关得分+50%",
		"cost": 1500,
		"max": 1
	}
}

var _selected_bonuses: Dictionary = {}  # bonus_id -> count
var _available_score: int = 0

func initialize(score: int) -> void:
	_available_score = score
	_selected_bonuses.clear()

func get_available_score() -> int:
	return _available_score

func get_spent_score() -> int:
	var total: int = 0
	for bonus_id in _selected_bonuses:
		var count: int = _selected_bonuses[bonus_id]
		total += count * AVAILABLE_BONUSES[bonus_id]["cost"]
	return total

func get_remaining_score() -> int:
	return _available_score - get_spent_score()

func can_select(bonus_id: String) -> bool:
	if not AVAILABLE_BONUSES.has(bonus_id):
		return false
	
	var bonus: Dictionary = AVAILABLE_BONUSES[bonus_id]
	var count: int = _selected_bonuses.get(bonus_id, 0)
	
	if count >= bonus.get("max", 1):
		return false
		
	return get_remaining_score() >= bonus["cost"]

func select_bonus(bonus_id: String) -> bool:
	if not can_select(bonus_id):
		return false
		
	var count: int = _selected_bonuses.get(bonus_id, 0)
	_selected_bonuses[bonus_id] = count + 1
	return true

func deselect_bonus(bonus_id: String) -> void:
	var count: int = _selected_bonuses.get(bonus_id, 0)
	if count > 0:
		_selected_bonuses[bonus_id] = count - 1
		if _selected_bonuses[bonus_id] == 0:
			_selected_bonuses.erase(bonus_id)

func apply_selected_bonuses(player_id: int) -> void:
	for bonus_id in _selected_bonuses:
		var count: int = _selected_bonuses[bonus_id]
		for i in range(count):
			_apply_bonus(player_id, bonus_id)
			
	EventBus.message_log.emit("[color=gold]NG+ 起始奖励已生效 (共消耗 %d 得分)[/color]" % get_spent_score())

func _apply_bonus(player_id: int, bonus_id: String) -> void:
	match bonus_id:
		"inherit_legendary":
			# Handled by ItemManager in full implementation
			EventBus.message_log.emit("[color=purple]获得传说传承装备！[/color]")
		"unlock_neutral_hanabi":
			# Handled by QuestManager / HeroSystem
			EventBus.message_log.emit("[color=green]爆破女王·花火 已加入麾下！[/color]")
		"starting_ap_plus_1":
			# Handled by GameManager
			EventBus.message_log.emit("[color=green]初始行动点+1[/color]")
		"what_if_hard_mode":
			# Set threat level to 80
			EventBus.threat_changed.emit(80)
			EventBus.message_log.emit("[color=red]挑战剧本：光明方进入殊死抵抗状态！[/color]")

func reset() -> void:
	_selected_bonuses.clear()
	_available_score = 0
