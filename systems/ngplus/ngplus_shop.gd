## ngplus_shop.gd - NG+ Score Shop (v1.1)
## Allows players to spend their previous clear score for starting bonuses.
## v1.1: Fixed all bonus effects to actually call real systems.
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
,
	# ── v7.0 新增战略奖励 ──
	"starting_territory_plus_2": {
		"name": "扩张先机",
		"desc": "开局额外占领 2 个随机邻近据点",
		"cost": 600,
		"max": 1
	},
	"starting_research_boost": {
		"name": "先进知识",
		"desc": "开局直接解锁科技树第一层全部节点",
		"cost": 700,
		"max": 1
	},
	"starting_prestige_100": {
		"name": "威名远播",
		"desc": "开局获得 100 威望",
		"cost": 400,
		"max": 2
	},
	"starting_army_elite": {
		"name": "精锐传承",
		"desc": "开局第一支军队的士兵质量提升为精锐（攻防+20%）",
		"cost": 800,
		"max": 1
	},
	"diplomatic_head_start": {
		"name": "外交先机",
		"desc": "开局与一个随机势力建立停战协议（持续5回合）",
		"cost": 500,
		"max": 1
	}
}

var _selected_bonuses: Dictionary = {}  # bonus_id -> count
var _available_score: int = 0
# v1.1: Track AP bonus granted by this shop (read by GameManager.calculate_action_points)
var _ap_bonus: int = 0
# v1.1: Track if hard mode was selected (read by NgPlusManager._calculate_victory_score)
var _hard_mode_active: bool = false

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

## v1.1: Returns AP bonus from this shop. Called by GameManager.calculate_action_points().
func get_ap_bonus() -> int:
	return _ap_bonus

## v1.1: Returns whether hard mode is active. Called by NgPlusManager for score multiplier.
func is_hard_mode_active() -> bool:
	return _hard_mode_active

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
	if _selected_bonuses.is_empty():
		return
	for bonus_id in _selected_bonuses:
		var count: int = _selected_bonuses[bonus_id]
		for i in range(count):
			_apply_bonus(player_id, bonus_id)
	EventBus.message_log.emit("[color=gold]NG+ 起始奖励已生效 (共消耗 %d 得分)[/color]" % get_spent_score())

func _apply_bonus(player_id: int, bonus_id: String) -> void:
	match bonus_id:
		"inherit_legendary":
			# v1.1: Grant via ItemManager if available, else gold fallback
			if ItemManager != null and ItemManager.has_method("grant_random_legendary"):
				ItemManager.grant_random_legendary(player_id)
				EventBus.message_log.emit("[color=purple][NG+] 获得传说传承装备！[/color]")
			else:
				ResourceManager.apply_delta(player_id, {"gold": 300})
				EventBus.message_log.emit("[color=purple][NG+] 传说传承补偿金 +300 金币[/color]")

		"unlock_neutral_hanabi":
			# v1.1: Recruit hero via HeroSystem if "hanabi" is defined
			if HeroSystem != null and HeroSystem.has_method("recruit_hero"):
				var hero_id: String = "hanabi"
				if not HeroSystem.is_hero_recruited(hero_id):
					HeroSystem.recruit_hero(hero_id)
					EventBus.message_log.emit("[color=green][NG+] 爆破女王·花火 已加入麾下！[/color]")
				else:
					EventBus.message_log.emit("[color=yellow][NG+] 花火已在麾下，改为获得 500 金币[/color]")
					ResourceManager.apply_delta(player_id, {"gold": 500})
			else:
				EventBus.message_log.emit("[color=yellow][NG+] 花火招募系统未就绪，改为获得 500 金币[/color]")
				ResourceManager.apply_delta(player_id, {"gold": 500})

		"starting_ap_plus_1":
			# v1.1: Increment tracked AP bonus; GameManager reads get_ap_bonus()
			_ap_bonus += 1
			EventBus.message_log.emit("[color=green][NG+] 初始行动点上限 +1 (当前加成: +%d)[/color]" % _ap_bonus)

		"what_if_hard_mode":
			# v1.1: Actually call ThreatManager.change_threat to set threat to 80
			var current: int = ThreatManager.get_threat()
			if current < 80:
				ThreatManager.change_threat(80 - current)
			_hard_mode_active = true
			EventBus.message_log.emit("[color=red][NG+] 挑战剧本：光明方进入殊死抵抗状态！通关得分×1.5[/color]")
		# ── v7.0 新增战略奖励 ──
		"starting_territory_plus_2":
			# Grant 2 random adjacent tiles to player starting position
			if GameManager != null and GameManager.has_method("grant_starting_territories"):
				GameManager.grant_starting_territories(player_id, 2)
			else:
				ResourceManager.apply_delta(player_id, {"gold": 200})
			EventBus.message_log.emit("[color=green][NG+] 扩张先机：开局额外获得 2 个据点！[/color]")
		"starting_research_boost":
			# Unlock first tier of research tree
			if ResearchManager != null and ResearchManager.has_method("unlock_first_tier"):
				ResearchManager.unlock_first_tier(player_id)
			else:
				ResourceManager.apply_delta(player_id, {"gold": 300})
			EventBus.message_log.emit("[color=green][NG+] 先进知识：科技树第一层已解锁！[/color]")
		"starting_prestige_100":
			ResourceManager.apply_delta(player_id, {"prestige": 100})
			EventBus.message_log.emit("[color=gold][NG+] 威名远播：获得 100 威望！[/color]")
		"starting_army_elite":
			# Mark first army as elite quality
			if GameManager != null:
				var armies: Array = GameManager.get_player_armies(player_id)
				if not armies.is_empty():
					armies[0]["elite_quality"] = true
					armies[0]["atk_bonus"] = armies[0].get("atk_bonus", 0) + 20
					armies[0]["def_bonus"] = armies[0].get("def_bonus", 0) + 20
			EventBus.message_log.emit("[color=purple][NG+] 精锐传承：第一支军队升级为精锐！[/color]")
		"diplomatic_head_start":
			# Create a ceasefire with a random faction
			if DiplomacyManager != null and GameManager != null:
				var factions: Array = []
				for p in GameManager.players:
					if p["id"] != player_id:
						factions.append(p["id"])
				if not factions.is_empty():
					var target_id: int = factions[randi() % factions.size()]
					var treaty := {"type": "ceasefire", "target": target_id, "turns_left": 5}
					DiplomacyManager._get_player_treaties(player_id).append(treaty)
					EventBus.message_log.emit("[color=green][NG+] 外交先机：与一个势力建立停战协议（5回合）！[/color]")

func reset() -> void:
	_selected_bonuses.clear()
	_available_score = 0
	_ap_bonus = 0
	_hard_mode_active = false

# ── Save / Load ──
func to_save_data() -> Dictionary:
	return {
		"selected_bonuses": _selected_bonuses.duplicate(),
		"available_score": _available_score,
		"ap_bonus": _ap_bonus,
		"hard_mode_active": _hard_mode_active,
	}

func from_save_data(data: Dictionary) -> void:
	_selected_bonuses = data.get("selected_bonuses", {})
	_available_score = int(data.get("available_score", 0))
	_ap_bonus = int(data.get("ap_bonus", 0))
	_hard_mode_active = bool(data.get("hard_mode_active", false))
