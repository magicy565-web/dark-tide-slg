## fortress_system.gd — 要塞地块专属系统
## 管理要塞的城防升级、驻军管理、攻城机制、特殊防御工事与战略价值。
## 版本: v1.0.0
extends Node

# ═══════════════════════════════════════════════════════════════
#                    要塞等级
# ═══════════════════════════════════════════════════════════════
const FORTRESS_LEVELS: Dictionary = {
	1: {"name": "木栅寨",   "wall_hp": 30,  "def_bonus": 5,  "garrison_cap": 20, "siege_turns": 3},
	2: {"name": "石砌堡垒", "wall_hp": 60,  "def_bonus": 12, "garrison_cap": 35, "siege_turns": 4},
	3: {"name": "军事要塞", "wall_hp": 100, "def_bonus": 20, "garrison_cap": 55, "siege_turns": 6},
	4: {"name": "铁血城堡", "wall_hp": 160, "def_bonus": 30, "garrison_cap": 80, "siege_turns": 8},
	5: {"name": "天堑雄关", "wall_hp": 250, "def_bonus": 45, "garrison_cap": 120,"siege_turns": 12},
}

# ═══════════════════════════════════════════════════════════════
#                    防御工事（建筑）
# ═══════════════════════════════════════════════════════════════
const FORTIFICATION_BUILDINGS: Dictionary = {
	"watchtower": {
		"name": "瞭望塔", "icon": "🗼",
		"desc": "扩大视野范围，提前发现来袭敌军",
		"cost": {"gold": 40, "iron": 15},
		"effects": {"vision_range": 2, "ambush_defense": 0.2},
		"max_level": 2,
	},
	"arrow_tower": {
		"name": "箭楼", "icon": "🏹",
		"desc": "对攻城敌军造成额外伤害",
		"cost": {"gold": 60, "iron": 30},
		"effects": {"siege_damage_per_turn": 5, "def_bonus": 3},
		"max_level": 3,
		"level_scaling": {"siege_damage_per_turn": 3},
	},
	"moat": {
		"name": "护城河", "icon": "💧",
		"desc": "减缓攻城速度，增加攻城方的损耗",
		"cost": {"gold": 80, "iron": 10},
		"effects": {"siege_slow": 1, "assault_penalty": 0.15},
		"max_level": 1,
	},
	"armory": {
		"name": "军械库", "icon": "⚔",
		"desc": "储备武器装备，提升驻军战斗力",
		"cost": {"gold": 70, "iron": 40},
		"effects": {"garrison_atk": 5, "garrison_def": 3},
		"max_level": 3,
		"level_scaling": {"garrison_atk": 3, "garrison_def": 2},
	},
	"barracks_fort": {
		"name": "要塞兵营", "icon": "🪖",
		"desc": "快速训练精锐士兵，每回合自动补充驻军",
		"cost": {"gold": 90, "iron": 35},
		"effects": {"auto_recruit": 3, "garrison_cap": 15},
		"max_level": 3,
		"level_scaling": {"auto_recruit": 2, "garrison_cap": 10},
	},
	"supply_depot": {
		"name": "补给仓库", "icon": "📦",
		"desc": "储备粮食和物资，延长围城抵抗时间",
		"cost": {"gold": 50, "iron": 20},
		"effects": {"siege_supply_turns": 3, "food_storage": 60},
		"max_level": 3,
		"level_scaling": {"siege_supply_turns": 2},
	},
	"command_center": {
		"name": "指挥中心", "icon": "🎯",
		"desc": "提升指挥效率，驻守英雄获得额外加成",
		"cost": {"gold": 120, "iron": 50},
		"effects": {"general_def_bonus": 8, "general_atk_bonus": 5},
		"max_level": 2,
		"level_scaling": {"general_def_bonus": 5, "general_atk_bonus": 3},
		"requires": "armory",
	},
}

# ═══════════════════════════════════════════════════════════════
#                    驻军命令
# ═══════════════════════════════════════════════════════════════
const GARRISON_ORDERS: Dictionary = {
	"hold_position": {
		"name": "坚守阵地", "icon": "🛡",
		"desc": "全力防守，防御+20%，但无法主动出击",
		"effects": {"def_mult": 1.2, "can_attack": false},
		"duration": -1,  # 持续直到取消
	},
	"active_defense": {
		"name": "积极防御", "icon": "⚔",
		"desc": "主动出击骚扰攻城方，每回合对攻城方造成额外伤害",
		"effects": {"siege_counter_damage": 8, "def_mult": 0.9},
		"duration": -1,
	},
	"emergency_repair": {
		"name": "紧急修缮", "icon": "🔨",
		"desc": "动员驻军修缮城墙，每回合恢复城墙耐久",
		"cost_per_turn": {"gold": 10, "iron": 5},
		"effects": {"wall_repair_per_turn": 15},
		"duration": -1,
	},
	"sortie": {
		"name": "出城突袭", "icon": "⚡",
		"desc": "派遣精锐出城突袭攻城方，一次性造成大量伤害",
		"cost": {"garrison": 5, "ap": 1},
		"effects": {"siege_damage_instant": 25},
		"cooldown": 3,
	},
	"call_reinforcement": {
		"name": "请求援军", "icon": "📯",
		"desc": "向友方势力请求援军，有概率获得驻军补充",
		"cost": {"gold": 50, "ap": 1},
		"effects": {"garrison_reinforce": 10},
		"cooldown": 5,
	},
}

# ═══════════════════════════════════════════════════════════════
#                    攻城机制参数
# ═══════════════════════════════════════════════════════════════
const SIEGE_PARAMS: Dictionary = {
	"base_damage_per_turn": 8,    # 攻城方每回合基础伤害
	"wall_block_ratio": 0.6,      # 城墙吸收伤害比例
	"garrison_counter_ratio": 0.3, # 驻军反击比例
	"supply_loss_per_turn": 5,    # 围城每回合粮食消耗
	"morale_loss_per_turn": 3,    # 围城每回合士气损失
}

# ═══════════════════════════════════════════════════════════════
#                    状态数据
# ═══════════════════════════════════════════════════════════════
var _fortress_data: Dictionary = {}

func reset() -> void:
	_fortress_data.clear()

func get_fortress_data(tile_idx: int) -> Dictionary:
	if not _fortress_data.has(tile_idx):
		var tile = GameManager.tiles[tile_idx] if tile_idx < GameManager.tiles.size() else {}
		var base_level: int = 1
		# 核心要塞初始为3级
		if tile.get("type", -1) == 9:  # CORE_FORTRESS
			base_level = 3
		var level_data = FORTRESS_LEVELS.get(base_level, FORTRESS_LEVELS[1])
		_fortress_data[tile_idx] = {
			"level": base_level,
			"wall_hp": tile.get("wall_hp", level_data["wall_hp"]),
			"wall_hp_max": level_data["wall_hp"],
			"buildings": {},
			"garrison_order": "hold_position",
			"order_cooldowns": {},
			"siege_supply_bonus": 0,  # 来自补给仓库的额外围城回合
			"total_battles_defended": 0,
			"prestige": 0,  # 要塞声望，影响周边士气
		}
	return _fortress_data[tile_idx]

# ═══════════════════════════════════════════════════════════════
#                    城墙管理
# ═══════════════════════════════════════════════════════════════
func repair_walls(tile_idx: int, amount: int = -1) -> Dictionary:
	var data = get_fortress_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()
	var level_data = FORTRESS_LEVELS.get(data["level"], FORTRESS_LEVELS[1])
	var max_hp: int = data["wall_hp_max"]

	if data["wall_hp"] >= max_hp:
		return {"success": false, "reason": "城墙已满血"}

	if amount < 0:
		# 完全修复
		var repair_needed: int = max_hp - data["wall_hp"]
		var cost: Dictionary = {"gold": int(repair_needed * 0.5), "iron": int(repair_needed * 0.3)}
		if not ResourceManager.can_afford(pid, cost):
			return {"success": false, "reason": "资源不足（需要 %d 金币，%d 铁矿）" % [cost["gold"], cost["iron"]]}
		ResourceManager.spend(pid, cost)
		data["wall_hp"] = max_hp
		EventBus.message_log.emit("[color=lime]【要塞】城墙完全修复（%d/%d）[/color]" % [max_hp, max_hp])
	else:
		var actual_repair: int = mini(amount, max_hp - data["wall_hp"])
		data["wall_hp"] += actual_repair

	if EventBus.has_signal("fortress_wall_repaired"):
		EventBus.fortress_wall_repaired.emit(tile_idx, data["wall_hp"], max_hp)

	return {"success": true, "wall_hp": data["wall_hp"]}

## 城墙受到攻击
func damage_walls(tile_idx: int, damage: int) -> Dictionary:
	var data = get_fortress_data(tile_idx)
	var level_data = FORTRESS_LEVELS.get(data["level"], FORTRESS_LEVELS[1])
	var def_bonus: int = level_data["def_bonus"]

	# 建筑防御加成
	var bld_effects = get_fortification_effects(tile_idx)
	def_bonus += bld_effects.get("def_bonus", 0)

	# 驻军命令加成
	var order = GARRISON_ORDERS.get(data["garrison_order"], {})
	var def_mult: float = order.get("effects", {}).get("def_mult", 1.0)

	# 实际伤害 = 伤害 × 城墙吸收 × 防御倍率
	var wall_block: float = SIEGE_PARAMS["wall_block_ratio"]
	if data["wall_hp"] <= 0:
		wall_block = 0.0  # 城墙破损后不再吸收伤害
	var actual_damage: int = int(damage * (1.0 - wall_block) / def_mult)
	var wall_damage: int = int(damage * wall_block)

	data["wall_hp"] = maxi(data["wall_hp"] - wall_damage, 0)

	if EventBus.has_signal("fortress_wall_damaged"):
		EventBus.fortress_wall_damaged.emit(tile_idx, wall_damage, data["wall_hp"])

	return {"wall_damage": wall_damage, "garrison_damage": actual_damage, "wall_hp": data["wall_hp"]}

# ═══════════════════════════════════════════════════════════════
#                    防御工事建造
# ═══════════════════════════════════════════════════════════════
func build_fortification(tile_idx: int, building_id: String) -> Dictionary:
	var data = get_fortress_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()

	if not FORTIFICATION_BUILDINGS.has(building_id):
		return {"success": false, "reason": "未知防御工事"}

	var bld = FORTIFICATION_BUILDINGS[building_id]

	# 检查前置
	if bld.has("requires") and not data["buildings"].has(bld["requires"]):
		return {"success": false, "reason": "需要先建造 %s" % FORTIFICATION_BUILDINGS[bld["requires"]]["name"]}

	var current_level: int = data["buildings"].get(building_id, 0)
	if current_level >= bld["max_level"]:
		return {"success": false, "reason": "已达最高等级"}

	var cost: Dictionary = {}
	for k in bld["cost"]:
		cost[k] = int(bld["cost"][k] * (1.0 + current_level * 0.6))

	if not ResourceManager.can_afford(pid, cost):
		return {"success": false, "reason": "资源不足"}

	ResourceManager.spend(pid, cost)
	data["buildings"][building_id] = current_level + 1

	var action_str: String = "建造" if current_level == 0 else "升级"
	EventBus.message_log.emit("[color=lime]【要塞】%s %s（Lv%d）完成！[/color]" % [action_str, bld["name"], current_level + 1])
	if EventBus.has_signal("fortress_building_built"):
		EventBus.fortress_building_built.emit(tile_idx, building_id, current_level + 1)

	return {"success": true, "building": building_id, "new_level": current_level + 1}

func get_fortification_effects(tile_idx: int) -> Dictionary:
	var data = get_fortress_data(tile_idx)
	var effects: Dictionary = {}
	for bld_id in data["buildings"]:
		var bld_level: int = data["buildings"][bld_id]
		if not FORTIFICATION_BUILDINGS.has(bld_id):
			continue
		var bld = FORTIFICATION_BUILDINGS[bld_id]
		for key in bld["effects"]:
			var base_val = bld["effects"][key]
			var scaling = bld.get("level_scaling", {}).get(key, 0)
			var total_val = base_val + scaling * (bld_level - 1)
			if effects.has(key):
				effects[key] += total_val
			else:
				effects[key] = total_val
	return effects

# ═══════════════════════════════════════════════════════════════
#                    驻军命令
# ═══════════════════════════════════════════════════════════════
func issue_garrison_order(tile_idx: int, order_id: String) -> Dictionary:
	var data = get_fortress_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()

	if not GARRISON_ORDERS.has(order_id):
		return {"success": false, "reason": "未知命令"}

	var order = GARRISON_ORDERS[order_id]

	# 检查冷却
	var cooldown: int = data["order_cooldowns"].get(order_id, 0)
	if cooldown > 0:
		return {"success": false, "reason": "命令冷却中（%d 回合）" % cooldown}

	# 一次性行动（有 cost 字段）
	if order.has("cost"):
		var cost = order["cost"]
		var ap_cost: int = cost.get("ap", 0)
		if GameManager.current_ap < ap_cost:
			return {"success": false, "reason": "行动力不足"}
		var garrison_cost: int = cost.get("garrison", 0)
		var tile = GameManager.tiles[tile_idx]
		if tile.get("garrison", 0) < garrison_cost:
			return {"success": false, "reason": "驻军不足"}
		var res_cost: Dictionary = {}
		for k in cost:
			if k not in ["ap", "garrison"]:
				res_cost[k] = cost[k]
		if not res_cost.is_empty() and not ResourceManager.can_afford(pid, res_cost):
			return {"success": false, "reason": "资源不足"}

		if ap_cost > 0:
			GameManager.current_ap -= ap_cost
			EventBus.ap_changed.emit(pid, GameManager.current_ap)
		if garrison_cost > 0:
			tile["garrison"] -= garrison_cost
		if not res_cost.is_empty():
			ResourceManager.spend(pid, res_cost)

		# 应用即时效果
		var effects = order.get("effects", {})
		if effects.get("siege_damage_instant", 0) > 0:
			EventBus.message_log.emit("[color=lime]【要塞突袭】出城突袭造成 %d 点攻城伤害！[/color]" % effects["siege_damage_instant"])
			if EventBus.has_signal("fortress_sortie_executed"):
				EventBus.fortress_sortie_executed.emit(tile_idx, effects["siege_damage_instant"])
		if effects.get("garrison_reinforce", 0) > 0:
			tile["garrison"] = tile.get("garrison", 0) + effects["garrison_reinforce"]
			EventBus.message_log.emit("[color=lime]【要塞援军】获得 %d 援军！[/color]" % effects["garrison_reinforce"])

		data["order_cooldowns"][order_id] = order.get("cooldown", 3)
	else:
		# 持续命令
		data["garrison_order"] = order_id
		EventBus.message_log.emit("[color=cyan]【要塞命令】切换为 %s[/color]" % order["name"])

	if EventBus.has_signal("fortress_order_issued"):
		EventBus.fortress_order_issued.emit(tile_idx, order_id)

	return {"success": true, "order": order_id}

# ═══════════════════════════════════════════════════════════════
#                    要塞升级
# ═══════════════════════════════════════════════════════════════
func upgrade_fortress(tile_idx: int) -> Dictionary:
	var data = get_fortress_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()
	var current_level: int = data["level"]

	if current_level >= 5:
		return {"success": false, "reason": "已达最高等级（天堑雄关）"}

	var upgrade_cost: Dictionary = {
		"gold": 100 * current_level,
		"iron": 50 * current_level,
	}

	if not ResourceManager.can_afford(pid, upgrade_cost):
		return {"success": false, "reason": "资源不足（需要 %d 金币，%d 铁矿）" % [upgrade_cost["gold"], upgrade_cost["iron"]]}

	ResourceManager.spend(pid, upgrade_cost)
	data["level"] += 1

	var new_level_data = FORTRESS_LEVELS[data["level"]]
	# 升级后城墙恢复满血
	data["wall_hp_max"] = new_level_data["wall_hp"]
	data["wall_hp"] = new_level_data["wall_hp"]

	# 更新地块数据
	var tile = GameManager.tiles[tile_idx]
	tile["wall_hp"] = new_level_data["wall_hp"]
	tile["def_bonus"] = tile.get("def_bonus", 0) + (new_level_data["def_bonus"] - FORTRESS_LEVELS[current_level]["def_bonus"])

	EventBus.message_log.emit("[color=gold]【要塞升级】升级为 %s！城墙耐久 %d，防御加成 +%d[/color]" % [
		new_level_data["name"], new_level_data["wall_hp"], new_level_data["def_bonus"]
	])
	if EventBus.has_signal("fortress_level_up"):
		EventBus.fortress_level_up.emit(tile_idx, data["level"])

	return {"success": true, "new_level": data["level"], "level_name": new_level_data["name"]}

# ═══════════════════════════════════════════════════════════════
#                    回合处理
# ═══════════════════════════════════════════════════════════════
func process_turn() -> void:
	for tile_idx in _fortress_data:
		var data = _fortress_data[tile_idx]
		var tile = GameManager.tiles[tile_idx] if tile_idx < GameManager.tiles.size() else null
		if tile == null:
			continue
		var pid: int = tile.get("owner_id", -1)

		# 命令冷却递减
		for order_id in data["order_cooldowns"]:
			if data["order_cooldowns"][order_id] > 0:
				data["order_cooldowns"][order_id] -= 1

		# 自动征兵（兵营效果）
		var bld_effects = get_fortification_effects(tile_idx)
		var auto_recruit: int = bld_effects.get("auto_recruit", 0)
		if auto_recruit > 0:
			var level_data = FORTRESS_LEVELS.get(data["level"], FORTRESS_LEVELS[1])
			var garrison_cap: int = level_data["garrison_cap"] + bld_effects.get("garrison_cap", 0)
			var current_garrison: int = tile.get("garrison", 0)
			if current_garrison < garrison_cap:
				var actual_recruit: int = mini(auto_recruit, garrison_cap - current_garrison)
				tile["garrison"] = current_garrison + actual_recruit

		# 紧急修缮命令：每回合修复城墙
		if data["garrison_order"] == "emergency_repair":
			var repair_cost_per_turn: Dictionary = {"gold": 10, "iron": 5}
			if pid >= 0 and ResourceManager.can_afford(pid, repair_cost_per_turn):
				ResourceManager.spend(pid, repair_cost_per_turn)
				repair_walls(tile_idx, bld_effects.get("wall_repair_per_turn", 15))

		# 声望：每次成功防守+1
		# （在 CombatResolver 中调用 record_defense_victory）

		# 声望辐射：提升周边友方士气
		if data["prestige"] > 0 and GameManager.morale_corruption_system:
			var morale_bonus: float = float(data["prestige"]) * 0.5
			if GameManager.adjacency.has(tile_idx):
				for adj_idx in GameManager.adjacency[tile_idx]:
					if adj_idx >= GameManager.tiles.size():
						continue
					var adj_tile = GameManager.tiles[adj_idx]
					if adj_tile.get("owner_id", -1) == pid:
						GameManager.morale_corruption_system.change_morale(adj_idx, morale_bonus * 0.3)

func record_defense_victory(tile_idx: int) -> void:
	var data = get_fortress_data(tile_idx)
	data["total_battles_defended"] += 1
	data["prestige"] = mini(data["prestige"] + 1, 10)
	EventBus.message_log.emit("[color=gold]【要塞声望】成功防守，声望提升至 %d！[/color]" % data["prestige"])

# ═══════════════════════════════════════════════════════════════
#                    存档
# ═══════════════════════════════════════════════════════════════
func to_save_data() -> Dictionary:
	return {"fortress_data": _fortress_data.duplicate(true)}

func from_save_data(data: Dictionary) -> void:
	_fortress_data = data.get("fortress_data", {}).duplicate(true)
