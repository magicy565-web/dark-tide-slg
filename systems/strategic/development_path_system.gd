## development_path_system.gd — 发展路径系统 (v1.2.0)
## 管理据点的多条发展路径、分支选择、里程碑系统。
extends Node

# ── 发展路径定义 ──
const DEVELOPMENT_PATHS: Dictionary = {
	"military": {
		"name": "军事",
		"desc": "强化驻军与防御",
		"levels": [
			{"name": "军营建设", "effects": {"garrison": 2, "def_bonus": 0.05}},
			{"name": "城防加固", "effects": {"wall_hp": 10, "def_bonus": 0.10}},
			{"name": "骑兵营地", "effects": {"cavalry_recruit": 1, "movement": 1}, "branch": true},
			{"name": "要塞化", "effects": {"wall_hp": 20, "def_bonus": 0.20, "siege_turns": 1}},
			{"name": "兵工厂", "effects": {"weapon_production": 0.30}},
		],
	},
	"commerce": {
		"name": "商业",
		"desc": "贸易与资源流通",
		"levels": [
			{"name": "商业街", "effects": {"gold_mult": 1.20}},
			{"name": "市集", "effects": {"production_mult": 1.10}},
			{"name": "贸易站", "effects": {"trade_range": 1}, "branch": true},
			{"name": "商业联盟", "effects": {"gold_mult": 1.40, "trade_routes": 1}},
			{"name": "金融中心", "effects": {"gold_mult": 1.60, "interest": 5}},
		],
	},
	"culture": {
		"name": "文化",
		"desc": "文化与民心",
		"levels": [
			{"name": "文化馆", "effects": {"morale": 10, "prestige": 1}},
			{"name": "艺术学院", "effects": {"morale": 20, "skill_points": 1}},
			{"name": "大剧院", "effects": {"morale": 30, "adjacent_morale": 5}, "branch": true},
			{"name": "文化遗产", "effects": {"morale": 50, "prestige": 3}},
			{"name": "文明灯塔", "effects": {"morale": 70, "global_prestige": 2}},
		],
	},
	"technology": {
		"name": "科技",
		"desc": "研究与创新",
		"levels": [
			{"name": "工坊", "effects": {"build_speed": -1}},
			{"name": "研究所", "effects": {"research_speed": 0.50}},
			{"name": "大学", "effects": {"tech_points": 2, "research_speed": 1.0}, "branch": true},
			{"name": "科学院", "effects": {"tech_points": 4, "tech_level": 1}},
			{"name": "知识殿堂", "effects": {"tech_points": 6, "tech_effect_mult": 1.20}},
		],
	},
	"religion": {
		"name": "宗教",
		"desc": "信仰与秩序",
		"levels": [
			{"name": "神殿", "effects": {"order": 5, "morale": 5}},
			{"name": "修道院", "effects": {"order": 10, "morale": 10, "corruption": -5}},
			{"name": "大教堂", "effects": {"order": 15, "morale": 15, "adjacent_order": 3}, "branch": true},
			{"name": "圣地", "effects": {"order": 25, "morale": 25, "corruption": -10}},
			{"name": "信仰中心", "effects": {"order": 40, "morale": 40, "global_corruption": -5}},
		],
	},
}

# ── 里程碑定义 ──
const MILESTONES: Dictionary = {
	"commercial_prosperity": {
		"name": "商业繁荣",
		"condition": "gold_accumulated >= 10000",
		"reward": {"gold_mult": 1.10},
	},
	"cultural_center": {
		"name": "文化中心",
		"condition": "morale_avg > 80 for 5 turns",
		"reward": {"prestige": 1},
	},
	"military_strength": {
		"name": "军事强国",
		"condition": "battles_won >= 10",
		"reward": {"garrison_def": 0.15},
	},
	"tech_progress": {
		"name": "科技进步",
		"condition": "technologies_researched >= 5",
		"reward": {"research_speed": 1.20},
	},
	"faith_stronghold": {
		"name": "信仰堡垒",
		"condition": "order_avg > 75 for 3 turns",
		"reward": {"order": 10},
	},
}

# ── 协同加成表 ──
const SYNERGY_BONUSES: Dictionary = {
	"military_commerce": 0.10,  # 驻军维护费-10%
	"commerce_culture": 0.15,   # 金币产出+15%
	"culture_religion": 0.10,   # 民心+10%
	"religion_military": 0.20,  # 驻军士气+20%
	"technology_all": 0.05,     # 所有效果+5%
}

# ── 状态存储 ──
# { tile_idx: { "paths": {...}, "development_points": int, "milestones": [...] } }
var _development_data: Dictionary = {}

func _ready() -> void:
	pass

func reset() -> void:
	_development_data.clear()

func get_development_data(tile_idx: int) -> Dictionary:
	if not _development_data.has(tile_idx):
		_development_data[tile_idx] = {
			"paths": {},
			"development_points": 0,
			"milestones_unlocked": [],
			"synergy_bonus": 0.0,
		}
		# 初始化所有路径
		for path_id in DEVELOPMENT_PATHS:
			_development_data[tile_idx]["paths"][path_id] = {
				"level": 0,
				"branch": null,
				"progress": 0,
			}
	return _development_data[tile_idx]

func upgrade_path(tile_idx: int, path_id: String) -> bool:
	if not DEVELOPMENT_PATHS.has(path_id):
		return false
	
	var data = get_development_data(tile_idx)
	var path_data = data["paths"][path_id]
	var path = DEVELOPMENT_PATHS[path_id]
	
	# 检查是否已达到最大等级
	if path_data["level"] >= path["levels"].size():
		return false
	
	# 检查发展点数
	var cost = (path_data["level"] + 1) * 10  # 每级升级需要 10-50 发展点
	if data["development_points"] < cost:
		EventBus.message_log.emit("[color=red]发展点数不足![/color]")
		return false
	
	# 升级路径
	data["development_points"] -= cost
	path_data["level"] += 1
	path_data["progress"] = 0
	var new_level: int = path_data["level"]
	
	EventBus.message_log.emit("[color=cyan]据点 #%d %s 升级到 Lv%d[/color]" % [
		tile_idx, path["name"], new_level])
	# 发射 EventBus 信号
	if EventBus.has_signal("development_path_upgraded"):
		EventBus.development_path_upgraded.emit(tile_idx, path_id, new_level)
	
	# 检查分支选择点
	if path["levels"][new_level - 1].get("branch", false):
		EventBus.message_log.emit("[color=yellow]可以选择分支方向![/color]")
	
	# 检查里程碑
	check_milestones(tile_idx)
	
	return true

func choose_branch(tile_idx: int, path_id: String, branch: String) -> bool:
	var data = get_development_data(tile_idx)
	var path_data = data["paths"][path_id]
	
	# 检查是否处于分支选择点
	var path = DEVELOPMENT_PATHS[path_id]
	if path_data["level"] < 3 or not path["levels"][2].get("branch", false):
		return false
	
	path_data["branch"] = branch
	EventBus.message_log.emit("[color=cyan]选择了分支: %s[/color]" % branch)
	if EventBus.has_signal("development_branch_chosen"):
		EventBus.development_branch_chosen.emit(tile_idx, path_id, branch)
	return true

func add_development_points(tile_idx: int, amount: int) -> void:
	var data = get_development_data(tile_idx)
	data["development_points"] += amount
	EventBus.message_log.emit("[color=yellow]据点 #%d 获得 %d 发展点[/color]" % [tile_idx, amount])

func get_path_effects(tile_idx: int, path_id: String) -> Dictionary:
	var data = get_development_data(tile_idx)
	var path_data = data["paths"][path_id]
	
	if path_data["level"] == 0:
		return {}
	
	var path = DEVELOPMENT_PATHS[path_id]
	var level_idx = path_data["level"] - 1
	if level_idx >= path["levels"].size():
		level_idx = path["levels"].size() - 1
	
	return path["levels"][level_idx].get("effects", {}).duplicate()

func get_all_path_effects(tile_idx: int) -> Dictionary:
	var result = {}
	var data = get_development_data(tile_idx)
	
	for path_id in data["paths"]:
		var effects = get_path_effects(tile_idx, path_id)
		for key in effects:
			if not result.has(key):
				result[key] = 0
			result[key] += effects[key]
	
	# 应用协同加成
	var synergy = calculate_synergy_bonus(tile_idx)
	if synergy > 0:
		for key in result:
			if key.ends_with("_mult"):
				result[key] *= (1.0 + synergy)
	
	return result

func calculate_synergy_bonus(tile_idx: int) -> float:
	var data = get_development_data(tile_idx)
	var bonus = 0.0
	
	# 检查路径组合
	var active_paths = []
	for path_id in data["paths"]:
		if data["paths"][path_id]["level"] > 0:
			active_paths.append(path_id)
	
	# 计算协同加成
	for i in range(active_paths.size()):
		for j in range(i + 1, active_paths.size()):
			var key = active_paths[i] + "_" + active_paths[j]
			if SYNERGY_BONUSES.has(key):
				bonus += SYNERGY_BONUSES[key]
	
	# 科技路径与所有路径的协同
	if "technology" in active_paths and active_paths.size() > 1:
		bonus += SYNERGY_BONUSES.get("technology_all", 0.0)
	
	data["synergy_bonus"] = bonus
	return bonus

func check_milestones(tile_idx: int) -> Array:
	var unlocked = []
	var data = get_development_data(tile_idx)
	
	# 这里应该检查各种条件
	# 暂时简化实现
	for milestone_id in MILESTONES:
		if not milestone_id in data["milestones_unlocked"]:
			# 检查条件逻辑
			if _check_milestone_condition(tile_idx, milestone_id):
				data["milestones_unlocked"].append(milestone_id)
				unlocked.append(milestone_id)
				EventBus.message_log.emit("[color=gold]里程碑解锁: %s[/color]" % MILESTONES[milestone_id]["name"])
				if EventBus.has_signal("milestone_unlocked"):
					EventBus.milestone_unlocked.emit(tile_idx, milestone_id)
	
	return unlocked

func _check_milestone_condition(tile_idx: int, milestone_id: String) -> bool:
	# 简化实现：根据发展点数判断
	var data = get_development_data(tile_idx)
	match milestone_id:
		"commercial_prosperity":
			return data["development_points"] >= 100
		"cultural_center":
			return data["paths"]["culture"]["level"] >= 3
		"military_strength":
			return data["paths"]["military"]["level"] >= 3
		"tech_progress":
			return data["paths"]["technology"]["level"] >= 3
		"faith_stronghold":
			return data["paths"]["religion"]["level"] >= 3
	return false

func get_milestone_reward(milestone_id: String) -> Dictionary:
	if MILESTONES.has(milestone_id):
		return MILESTONES[milestone_id].get("reward", {})
	return {}

func process_turn() -> void:
	# 每回合增加发展点数
	for tile_idx in _development_data:
		var data = _development_data[tile_idx]
		if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
			continue
		var tile = GameManager.tiles[tile_idx]
		if tile == null:
			continue
		
		# 基础发展点数
		var base_points: int = 1
		
		# 根据建筑等级增加
		var building_level: int = tile.get("building_level", 1)
		base_points += building_level
		
		var old_pts: int = data["development_points"]
		data["development_points"] += base_points
		
		# 发射变化信号
		if EventBus.has_signal("development_points_changed"):
			EventBus.development_points_changed.emit(tile_idx, old_pts, data["development_points"])
		
		# 检查里程碑
		check_milestones(tile_idx)

func to_save_data() -> Dictionary:
	return {
		"development_data": _development_data.duplicate(true),
	}

func from_save_data(data: Dictionary) -> void:
	_development_data = data.get("development_data", {}).duplicate(true)
