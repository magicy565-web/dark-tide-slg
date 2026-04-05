## village_system.gd — 村庄地块专属系统
## 管理村庄的民政、征兵、贸易、建筑发展、民心与人口增长。
## 版本: v1.0.0
extends Node

# ═══════════════════════════════════════════════════════════════
#                    村庄等级
# ═══════════════════════════════════════════════════════════════
const VILLAGE_LEVELS: Dictionary = {
	1: {"name": "小村落",   "pop_cap": 20,  "trade_slots": 1, "building_slots": 2, "gold_base": 8,  "food_base": 5},
	2: {"name": "村庄",     "pop_cap": 40,  "trade_slots": 2, "building_slots": 3, "gold_base": 14, "food_base": 8},
	3: {"name": "城镇",     "pop_cap": 70,  "trade_slots": 3, "building_slots": 4, "gold_base": 22, "food_base": 12},
	4: {"name": "繁荣城市", "pop_cap": 100, "trade_slots": 4, "building_slots": 5, "gold_base": 35, "food_base": 18},
}

# ═══════════════════════════════════════════════════════════════
#                    建筑定义（村庄专属）
# ═══════════════════════════════════════════════════════════════
const VILLAGE_BUILDINGS: Dictionary = {
	"market": {
		"name": "集市", "icon": "🏪",
		"desc": "增加金币产出和贸易槽位",
		"cost": {"gold": 50, "iron": 10},
		"effects": {"gold_per_turn": 8, "trade_slots": 1},
		"max_level": 3,
		"level_scaling": {"gold_per_turn": 5},
	},
	"granary": {
		"name": "粮仓", "icon": "🌾",
		"desc": "增加粮食储存和产出，支撑更大规模的军队",
		"cost": {"gold": 40, "iron": 5},
		"effects": {"food_per_turn": 6, "food_storage": 50},
		"max_level": 3,
		"level_scaling": {"food_per_turn": 4},
	},
	"barracks": {
		"name": "兵营", "icon": "⚔",
		"desc": "提升征兵效率和驻军上限",
		"cost": {"gold": 60, "iron": 20},
		"effects": {"recruit_bonus": 3, "garrison_cap": 10},
		"max_level": 3,
		"level_scaling": {"recruit_bonus": 2, "garrison_cap": 5},
	},
	"inn": {
		"name": "客栈", "icon": "🏠",
		"desc": "吸引流浪英雄，每回合有概率招募到随机英雄",
		"cost": {"gold": 80, "iron": 15},
		"effects": {"hero_attract_chance": 0.15},
		"max_level": 2,
		"level_scaling": {"hero_attract_chance": 0.10},
	},
	"workshop": {
		"name": "工坊", "icon": "🔨",
		"desc": "生产铁矿制品，增加铁矿产出",
		"cost": {"gold": 55, "iron": 25},
		"effects": {"iron_per_turn": 5},
		"max_level": 3,
		"level_scaling": {"iron_per_turn": 3},
	},
	"temple": {
		"name": "神庙", "icon": "⛪",
		"desc": "提升民心和公共秩序，降低叛乱风险",
		"cost": {"gold": 70, "iron": 10},
		"effects": {"morale_per_turn": 3, "order_bonus": 5},
		"max_level": 2,
		"level_scaling": {"morale_per_turn": 2, "order_bonus": 3},
	},
	"guild": {
		"name": "商会", "icon": "💼",
		"desc": "解锁高级贸易协议，大幅提升贸易收益",
		"cost": {"gold": 100, "iron": 20},
		"effects": {"trade_income_mult": 1.3},
		"max_level": 2,
		"level_scaling": {"trade_income_mult": 0.2},
		"requires": "market",
	},
}

# ═══════════════════════════════════════════════════════════════
#                    贸易协议
# ═══════════════════════════════════════════════════════════════
const TRADE_AGREEMENTS: Array = [
	{"id": "grain_trade",   "name": "粮食贸易",   "cost": {"gold": 20}, "income": {"food": 8},  "duration": 5, "desc": "与周边农庄签订粮食供应协议"},
	{"id": "iron_trade",    "name": "铁矿贸易",   "cost": {"gold": 30}, "income": {"iron": 6},  "duration": 5, "desc": "与矿场签订铁矿供应协议"},
	{"id": "luxury_trade",  "name": "奢侈品贸易", "cost": {"gold": 50}, "income": {"gold": 20}, "duration": 4, "desc": "高风险高回报的奢侈品贸易路线"},
	{"id": "slave_trade",   "name": "奴隶贸易",   "cost": {"gold": 40}, "income": {"slaves": 2},"duration": 6, "desc": "灰色地带的奴隶贸易，收益丰厚但影响民心"},
	{"id": "arms_trade",    "name": "武器贸易",   "cost": {"iron": 15}, "income": {"gold": 25}, "duration": 4, "desc": "出售武器装备换取金币"},
	{"id": "knowledge_trade","name": "知识交流",  "cost": {"gold": 35}, "income": {"research": 2}, "duration": 5, "desc": "与学者交流，获得研究加速"},
]

# ═══════════════════════════════════════════════════════════════
#                    民政行动
# ═══════════════════════════════════════════════════════════════
const DOMESTIC_ACTIONS: Dictionary = {
	"tax_collection": {
		"name": "收税",  "icon": "💰",
		"desc": "强制征税，立即获得金币但降低民心",
		"cost": {"ap": 1},
		"effects": {"gold": 30, "morale": -10},
		"cooldown": 3,
	},
	"festival": {
		"name": "举办节日", "icon": "🎉",
		"desc": "举办节日庆典，大幅提升民心和公共秩序",
		"cost": {"gold": 40, "ap": 1},
		"effects": {"morale": 20, "order": 10},
		"cooldown": 4,
	},
	"conscription": {
		"name": "全面征兵", "icon": "🪖",
		"desc": "全面征召村民入伍，大幅增加驻军但降低劳动力",
		"cost": {"gold": 20, "ap": 1},
		"effects": {"garrison": 8, "food_per_turn": -2, "morale": -5},
		"cooldown": 3,
	},
	"infrastructure": {
		"name": "修缮基础设施", "icon": "🔧",
		"desc": "修缮道路和水利，提升产出效率",
		"cost": {"gold": 50, "iron": 10, "ap": 1},
		"effects": {"gold_mult": 0.1, "food_mult": 0.1},
		"cooldown": 5,
	},
	"spy_network": {
		"name": "建立情报网", "icon": "🕵",
		"desc": "在村庄建立情报网络，获取周边敌方信息",
		"cost": {"gold": 60, "ap": 1},
		"effects": {"espionage": 2, "reveal_radius": 2},
		"cooldown": 6,
	},
}

# ═══════════════════════════════════════════════════════════════
#                    状态数据
# ═══════════════════════════════════════════════════════════════
# { tile_idx: { "level": int, "population": int, "buildings": {id: level},
#               "active_trades": [{id, turns_left}], "action_cooldowns": {id: int},
#               "total_income": int, "happiness": float } }
var _village_data: Dictionary = {}

func reset() -> void:
	_village_data.clear()

func get_village_data(tile_idx: int) -> Dictionary:
	if not _village_data.has(tile_idx):
		var tile = GameManager.tiles[tile_idx] if tile_idx < GameManager.tiles.size() else {}
		_village_data[tile_idx] = {
			"level": 1,
			"population": 15,
			"buildings": {},
			"active_trades": [],
			"action_cooldowns": {},
			"total_income": 0,
			"happiness": 70.0,
			"pop_growth_acc": 0.0,
		}
	return _village_data[tile_idx]

# ═══════════════════════════════════════════════════════════════
#                    建筑管理
# ═══════════════════════════════════════════════════════════════
func build(tile_idx: int, building_id: String) -> Dictionary:
	var data = get_village_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()

	if not VILLAGE_BUILDINGS.has(building_id):
		return {"success": false, "reason": "未知建筑"}

	var bld = VILLAGE_BUILDINGS[building_id]

	# 检查前置建筑
	if bld.has("requires") and not data["buildings"].has(bld["requires"]):
		return {"success": false, "reason": "需要先建造 %s" % VILLAGE_BUILDINGS[bld["requires"]]["name"]}

	# 检查建筑槽位
	var level_data = VILLAGE_LEVELS.get(data["level"], VILLAGE_LEVELS[1])
	if data["buildings"].size() >= level_data["building_slots"] and not data["buildings"].has(building_id):
		return {"success": false, "reason": "建筑槽位已满（当前等级最多 %d 个）" % level_data["building_slots"]}

	# 检查最高等级
	var current_level: int = data["buildings"].get(building_id, 0)
	if current_level >= bld["max_level"]:
		return {"success": false, "reason": "已达最高等级"}

	# 计算费用（升级费用 = 基础费用 × 当前等级）
	var cost: Dictionary = {}
	for k in bld["cost"]:
		cost[k] = int(bld["cost"][k] * (1 + current_level * 0.5))

	if not ResourceManager.can_afford(pid, cost):
		return {"success": false, "reason": "资源不足"}

	ResourceManager.spend(pid, cost)
	data["buildings"][building_id] = current_level + 1

	var action: String = "建造" if current_level == 0 else "升级"
	EventBus.message_log.emit("[color=lime]【村庄】%s %s（Lv%d）完成！[/color]" % [action, bld["name"], current_level + 1])
	if EventBus.has_signal("village_building_built"):
		EventBus.village_building_built.emit(tile_idx, building_id, current_level + 1)

	return {"success": true, "building": building_id, "new_level": current_level + 1}

## 计算建筑总效果
func get_building_effects(tile_idx: int) -> Dictionary:
	var data = get_village_data(tile_idx)
	var effects: Dictionary = {}
	for bld_id in data["buildings"]:
		var bld_level: int = data["buildings"][bld_id]
		if not VILLAGE_BUILDINGS.has(bld_id):
			continue
		var bld = VILLAGE_BUILDINGS[bld_id]
		for key in bld["effects"]:
			var base_val = bld["effects"][key]
			var scaling = bld.get("level_scaling", {}).get(key, 0)
			var total_val = base_val + scaling * (bld_level - 1)
			if effects.has(key):
				if base_val is float:
					effects[key] += total_val
				else:
					effects[key] += int(total_val)
			else:
				effects[key] = total_val
	return effects

# ═══════════════════════════════════════════════════════════════
#                    贸易管理
# ═══════════════════════════════════════════════════════════════
func start_trade(tile_idx: int, trade_id: String) -> Dictionary:
	var data = get_village_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()

	if not _find_trade(trade_id):
		return {"success": false, "reason": "未知贸易协议"}

	var trade = _find_trade(trade_id)
	var level_data = VILLAGE_LEVELS.get(data["level"], VILLAGE_LEVELS[1])

	# 检查贸易槽位
	var bld_effects = get_building_effects(tile_idx)
	var max_trades: int = level_data["trade_slots"] + bld_effects.get("trade_slots", 0)
	if data["active_trades"].size() >= max_trades:
		return {"success": false, "reason": "贸易槽位已满（最多 %d 个）" % max_trades}

	# 检查是否已有相同贸易
	for t in data["active_trades"]:
		if t["id"] == trade_id:
			return {"success": false, "reason": "该贸易协议已激活"}

	if not ResourceManager.can_afford(pid, trade["cost"]):
		return {"success": false, "reason": "资源不足"}

	ResourceManager.spend(pid, trade["cost"])
	data["active_trades"].append({"id": trade_id, "turns_left": trade["duration"]})

	EventBus.message_log.emit("[color=cyan]【村庄贸易】签订 %s 协议，持续 %d 回合[/color]" % [trade["name"], trade["duration"]])
	if EventBus.has_signal("village_trade_started"):
		EventBus.village_trade_started.emit(tile_idx, trade_id)

	return {"success": true, "trade": trade}

func _find_trade(trade_id: String) -> Dictionary:
	for t in TRADE_AGREEMENTS:
		if t["id"] == trade_id:
			return t
	return {}

# ═══════════════════════════════════════════════════════════════
#                    民政行动
# ═══════════════════════════════════════════════════════════════
func execute_domestic_action(tile_idx: int, action_id: String) -> Dictionary:
	var data = get_village_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()

	if not DOMESTIC_ACTIONS.has(action_id):
		return {"success": false, "reason": "未知行动"}

	var action = DOMESTIC_ACTIONS[action_id]

	# 检查冷却
	var cooldown: int = data["action_cooldowns"].get(action_id, 0)
	if cooldown > 0:
		return {"success": false, "reason": "行动冷却中（%d 回合）" % cooldown}

	# 检查行动力
	var ap_cost: int = action["cost"].get("ap", 0)
	if GameManager.current_ap < ap_cost:
		return {"success": false, "reason": "行动力不足"}

	# 检查资源费用
	var res_cost: Dictionary = {}
	for k in action["cost"]:
		if k != "ap":
			res_cost[k] = action["cost"][k]
	if not res_cost.is_empty() and not ResourceManager.can_afford(pid, res_cost):
		return {"success": false, "reason": "资源不足"}

	# 扣除费用
	if ap_cost > 0:
		GameManager.current_ap -= ap_cost
		EventBus.ap_changed.emit(pid, GameManager.current_ap)
	if not res_cost.is_empty():
		ResourceManager.spend(pid, res_cost)

	# 应用效果
	var effects = action["effects"]
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[tile_idx]
	if effects.get("gold", 0) != 0:
		if effects["gold"] > 0:
			ResourceManager.gain(pid, {"gold": effects["gold"]})
		else:
			ResourceManager.spend(pid, {"gold": -effects["gold"]})
	if effects.get("garrison", 0) > 0:
		tile["garrison"] = tile.get("garrison", 0) + effects["garrison"]
	if effects.get("morale", 0) != 0 and GameManager.morale_corruption_system:
		GameManager.morale_corruption_system.change_morale(tile_idx, float(effects["morale"]))
	if effects.get("order", 0) != 0:
		var cur_order: float = tile.get("public_order", 0.8)
		tile["public_order"] = clampf(cur_order + effects["order"] / 100.0, 0.0, 1.0)

	# 设置冷却
	data["action_cooldowns"][action_id] = action.get("cooldown", 3)

	EventBus.message_log.emit("[color=lime]【村庄民政】执行 %s 成功[/color]" % action["name"])
	if EventBus.has_signal("village_action_executed"):
		EventBus.village_action_executed.emit(tile_idx, action_id)

	return {"success": true, "effects": effects}

# ═══════════════════════════════════════════════════════════════
#                    村庄升级
# ═══════════════════════════════════════════════════════════════
func upgrade_village(tile_idx: int) -> Dictionary:
	var data = get_village_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()
	var current_level: int = data["level"]

	if current_level >= 4:
		return {"success": false, "reason": "已达最高等级（繁荣城市）"}

	# 升级费用随等级增加
	var upgrade_cost: Dictionary = {"gold": 80 * current_level, "iron": 20 * current_level}
	# 人口要求
	var pop_required: int = VILLAGE_LEVELS[current_level]["pop_cap"] * 8 / 10  # 80% 人口上限

	if data["population"] < pop_required:
		return {"success": false, "reason": "人口不足（需要 %d，当前 %d）" % [pop_required, data["population"]]}

	if not ResourceManager.can_afford(pid, upgrade_cost):
		return {"success": false, "reason": "资源不足"}

	ResourceManager.spend(pid, upgrade_cost)
	data["level"] += 1

	var new_level_data = VILLAGE_LEVELS[data["level"]]
	EventBus.message_log.emit("[color=gold]【村庄升级】升级为 %s！解锁更多建筑槽位和贸易路线[/color]" % new_level_data["name"])
	if EventBus.has_signal("village_level_up"):
		EventBus.village_level_up.emit(tile_idx, data["level"])

	return {"success": true, "new_level": data["level"], "level_name": new_level_data["name"]}

# ═══════════════════════════════════════════════════════════════
#                    回合处理
# ═══════════════════════════════════════════════════════════════
func process_turn() -> void:
	for tile_idx in _village_data:
		var data = _village_data[tile_idx]
		var pid: int = _get_tile_owner(tile_idx)
		if pid < 0:
			continue

		# 贸易收益
		var trades_to_remove: Array = []
		for trade_entry in data["active_trades"]:
			var trade = _find_trade(trade_entry["id"])
			if trade.is_empty():
				trades_to_remove.append(trade_entry)
				continue
			# 应用贸易收益（受商会加成影响）
			var bld_effects = get_building_effects(tile_idx)
			var income_mult: float = bld_effects.get("trade_income_mult", 1.0)
			var income: Dictionary = {}
			for k in trade["income"]:
				income[k] = int(trade["income"][k] * income_mult)
			ResourceManager.gain(pid, income)
			data["total_income"] += income.get("gold", 0)

			trade_entry["turns_left"] -= 1
			if trade_entry["turns_left"] <= 0:
				trades_to_remove.append(trade_entry)
				EventBus.message_log.emit("[color=gray]【村庄贸易】%s 协议已到期[/color]" % trade["name"])

		for t in trades_to_remove:
			data["active_trades"].erase(t)

		# 建筑产出
		var bld_effects = get_building_effects(tile_idx)
		var bld_gold: int = bld_effects.get("gold_per_turn", 0)
		var bld_food: int = bld_effects.get("food_per_turn", 0)
		var bld_iron: int = bld_effects.get("iron_per_turn", 0)
		var bld_morale: float = float(bld_effects.get("morale_per_turn", 0))
		if bld_gold > 0: ResourceManager.gain(pid, {"gold": bld_gold})
		if bld_food > 0: ResourceManager.gain(pid, {"food": bld_food})
		if bld_iron > 0: ResourceManager.gain(pid, {"iron": bld_iron})
		if bld_morale > 0 and GameManager.morale_corruption_system:
			GameManager.morale_corruption_system.change_morale(tile_idx, bld_morale)

		# 人口增长
		var level_data = VILLAGE_LEVELS.get(data["level"], VILLAGE_LEVELS[1])
		var happiness_factor: float = data["happiness"] / 100.0
		var growth_rate: float = 0.5 * happiness_factor
		data["pop_growth_acc"] += growth_rate
		if data["pop_growth_acc"] >= 1.0:
			var growth: int = int(data["pop_growth_acc"])
			data["pop_growth_acc"] -= float(growth)
			data["population"] = mini(data["population"] + growth, level_data["pop_cap"])

		# 行动冷却递减
		for action_id in data["action_cooldowns"]:
			if data["action_cooldowns"][action_id] > 0:
				data["action_cooldowns"][action_id] -= 1

		# 客栈：随机吸引英雄
		if data["buildings"].has("inn") and HeroSystem != null:
			var inn_level: int = data["buildings"]["inn"]
			var attract_chance: float = 0.15 + 0.10 * (inn_level - 1)
			if randf() < attract_chance:
				EventBus.message_log.emit("[color=cyan]【村庄客栈】有英雄在 #%d 的客栈中等待招募！[/color]" % tile_idx)
				if EventBus.has_signal("village_hero_available"):
					EventBus.village_hero_available.emit(tile_idx)

func _get_tile_owner(tile_idx: int) -> int:
	if tile_idx >= GameManager.tiles.size():
		return -1
	return GameManager.tiles[tile_idx].get("owner_id", -1)

# ═══════════════════════════════════════════════════════════════
#                    存档
# ═══════════════════════════════════════════════════════════════
func to_save_data() -> Dictionary:
	return {"village_data": _village_data.duplicate(true)}

func from_save_data(data: Dictionary) -> void:
	# FIX: JSON round-trip converts int keys to strings; normalize them back to int
	var raw: Dictionary = data.get("village_data", {}).duplicate(true)
	_village_data.clear()
	for k in raw:
		var int_key: int = int(k) if typeof(k) == TYPE_STRING else k
		_village_data[int_key] = raw[k]
