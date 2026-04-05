## cave_system.gd — 洞穴地块专属系统
## 管理洞穴/遗迹/盗贼巢穴的探索、资源采集、怪物刷新、黑市交易。
## 版本: v1.0.0
extends Node

# ═══════════════════════════════════════════════════════════════
#                    洞穴等级与基础属性
# ═══════════════════════════════════════════════════════════════
const CAVE_LEVELS: Dictionary = {
	1: {"name": "浅层洞穴", "explore_slots": 1, "monster_power": 10, "resource_mult": 1.0, "black_market": false},
	2: {"name": "深层洞穴", "explore_slots": 2, "monster_power": 20, "resource_mult": 1.5, "black_market": false},
	3: {"name": "古代遗迹", "explore_slots": 3, "monster_power": 35, "resource_mult": 2.0, "black_market": true},
	4: {"name": "禁忌深渊", "explore_slots": 4, "monster_power": 55, "resource_mult": 3.0, "black_market": true},
}

# ═══════════════════════════════════════════════════════════════
#                    探索事件表
# ═══════════════════════════════════════════════════════════════
const EXPLORE_EVENTS: Array = [
	{"id": "gold_vein",      "name": "发现金矿脉",    "weight": 20, "reward": {"gold": 40},           "desc": "洞穴深处闪烁着金色光芒，发现了一处隐藏的金矿脉！"},
	{"id": "iron_cache",     "name": "铁矿储藏",      "weight": 20, "reward": {"iron": 30},           "desc": "一处被遗忘的铁矿储藏，锈迹斑斑但仍有价值。"},
	{"id": "ancient_relic",  "name": "上古遗物",      "weight": 10, "reward": {"gold": 20, "iron": 15, "research": 2}, "desc": "发现了上古文明的遗物，蕴含珍贵的知识与材料。"},
	{"id": "monster_lair",   "name": "怪物巢穴",      "weight": 15, "reward": {"gold": 60},           "desc": "深处潜伏着怪物！击败后获得大量战利品。", "combat": true, "monster_power": 15},
	{"id": "trap",           "name": "古老陷阱",      "weight": 10, "reward": {"gold": -10},          "desc": "触发了古老的陷阱，损失了一些资源。", "negative": true},
	{"id": "hidden_spring",  "name": "隐秘水源",      "weight": 10, "reward": {"food": 25},           "desc": "发现了隐秘的地下水源，可以补充粮食。"},
	{"id": "cursed_altar",   "name": "诅咒祭坛",      "weight": 5,  "reward": {"morale": -10},        "desc": "触碰了诅咒祭坛，士气受到打击。", "negative": true},
	{"id": "treasure_chest", "name": "宝箱",          "weight": 5,  "reward": {"gold": 80, "iron": 20}, "desc": "发现了一口古老的宝箱，里面装满了财富！"},
	{"id": "crystal_node",   "name": "水晶矿节",      "weight": 5,  "reward": {"iron": 20, "research": 3}, "desc": "发现了罕见的水晶矿节，蕴含强大的魔法能量。"},
]

# ═══════════════════════════════════════════════════════════════
#                    怪物类型表
# ═══════════════════════════════════════════════════════════════
const MONSTER_TYPES: Array = [
	{"id": "cave_spider",   "name": "洞穴蜘蛛",  "power": 8,  "reward": {"gold": 15, "iron": 5}},
	{"id": "stone_golem",   "name": "石像鬼",    "power": 20, "reward": {"gold": 30, "iron": 15}},
	{"id": "shadow_beast",  "name": "暗影兽",    "power": 35, "reward": {"gold": 50, "iron": 20}},
	{"id": "ancient_guard", "name": "上古守卫",  "power": 55, "reward": {"gold": 80, "iron": 30, "research": 5}},
	{"id": "cave_dragon",   "name": "洞穴龙",    "power": 80, "reward": {"gold": 150, "iron": 50, "research": 10}},
]

# ═══════════════════════════════════════════════════════════════
#                    黑市商品表
# ═══════════════════════════════════════════════════════════════
const BLACK_MARKET_ITEMS: Array = [
	{"id": "stolen_gold",    "name": "赃款",        "cost": {"iron": 20},  "reward": {"gold": 60},  "desc": "来路不明的金币，价格低廉。"},
	{"id": "rare_iron",      "name": "精炼铁锭",    "cost": {"gold": 30},  "reward": {"iron": 40},  "desc": "品质极佳的铁锭，适合锻造武器。"},
	{"id": "spy_info",       "name": "情报",        "cost": {"gold": 50},  "reward": {"espionage": 1}, "desc": "关于敌方据点的详细情报。"},
	{"id": "mercenary",      "name": "雇佣兵",      "cost": {"gold": 80},  "reward": {"garrison": 5}, "desc": "经验丰富的雇佣兵，立即加入驻军。"},
	{"id": "poison_supply",  "name": "毒药",        "cost": {"gold": 40},  "reward": {"offensive_bonus": 15}, "desc": "可用于削弱敌方据点的神秘毒药。"},
	{"id": "ancient_map",    "name": "上古地图",    "cost": {"gold": 60},  "reward": {"explore_bonus": 2, "research": 3}, "desc": "标注了未知遗迹位置的古老地图。"},
]

# ═══════════════════════════════════════════════════════════════
#                    升级路径（洞穴改造）
# ═══════════════════════════════════════════════════════════════
const UPGRADE_PATHS: Dictionary = {
	"outpost": {
		"name": "改造为前哨站",
		"desc": "清剿洞穴后将其改造为军事前哨，获得驻军+5和防御+10",
		"cost": {"gold": 80, "iron": 30},
		"effects": {"garrison": 5, "def_bonus": 10, "type_change": "WILDERNESS"},
		"requires_cleared": true,
	},
	"mine": {
		"name": "开发为矿场",
		"desc": "利用洞穴的矿脉开发为专业矿场，每回合产出铁矿+8",
		"cost": {"gold": 60, "iron": 20},
		"effects": {"iron_per_turn": 8, "type_change": "RESOURCE"},
		"requires_cleared": true,
	},
	"dungeon": {
		"name": "建造地下城",
		"desc": "将洞穴改造为地下城，可关押战俘并获得奴隶产出",
		"cost": {"gold": 100, "iron": 40},
		"effects": {"slaves_per_turn": 3, "prisoner_capacity": 10},
		"requires_cleared": false,
	},
}

# ═══════════════════════════════════════════════════════════════
#                    状态数据
# ═══════════════════════════════════════════════════════════════
# { tile_idx: { "level": int, "cleared": bool, "explore_cooldown": int,
#               "monster_hp": int, "monster_id": str, "black_market_refresh": int,
#               "total_explored": int, "upgrades": Array[str] } }
var _cave_data: Dictionary = {}

# ═══════════════════════════════════════════════════════════════
#                    初始化
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	pass

func reset() -> void:
	_cave_data.clear()

func get_cave_data(tile_idx: int) -> Dictionary:
	if not _cave_data.has(tile_idx):
		var tile = GameManager.tiles[tile_idx] if tile_idx < GameManager.tiles.size() else {}
		var base_level: int = 1
		# 根据地块类型决定初始等级
		var tile_type: int = tile.get("type", -1)
		if tile_type == 13:  # RUINS
			base_level = 3
		elif tile_type == 10:  # NEUTRAL_BASE
			base_level = 2
		_cave_data[tile_idx] = {
			"level": base_level,
			"cleared": false,
			"explore_cooldown": 0,
			"monster_hp": _get_initial_monster_hp(base_level),
			"monster_id": _pick_monster_for_level(base_level),
			"black_market_refresh": 0,
			"total_explored": 0,
			"upgrades": [],
			"black_market_stock": _generate_black_market_stock(),
		}
	return _cave_data[tile_idx]

func _get_initial_monster_hp(level: int) -> int:
	return CAVE_LEVELS.get(level, CAVE_LEVELS[1])["monster_power"]

func _pick_monster_for_level(level: int) -> String:
	var power_threshold: int = CAVE_LEVELS.get(level, CAVE_LEVELS[1])["monster_power"]
	var candidates: Array = []
	for m in MONSTER_TYPES:
		if m["power"] <= power_threshold + 10:
			candidates.append(m["id"])
	if candidates.is_empty():
		return MONSTER_TYPES[0]["id"]
	return candidates[randi() % candidates.size()]

func _generate_black_market_stock() -> Array:
	var stock: Array = []
	var pool = BLACK_MARKET_ITEMS.duplicate()
	pool.shuffle()
	for i in range(mini(3, pool.size())):
		stock.append(pool[i]["id"])
	return stock

# ═══════════════════════════════════════════════════════════════
#                    核心行动
# ═══════════════════════════════════════════════════════════════

## 探索洞穴 — 消耗行动力，触发随机事件
func explore(tile_idx: int) -> Dictionary:
	var data = get_cave_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()

	# 检查冷却
	if data["explore_cooldown"] > 0:
		return {"success": false, "reason": "探索冷却中（%d 回合）" % data["explore_cooldown"]}

	# 检查行动力
	if GameManager.current_ap < 1:
		return {"success": false, "reason": "行动力不足"}

	# 消耗行动力
	GameManager.current_ap -= 1
	EventBus.ap_changed.emit(pid, GameManager.current_ap)

	# 触发随机事件
	var event = _pick_explore_event(data["level"])
	var result: Dictionary = {"success": true, "event": event, "rewards": {}}

	# 应用奖励
	var rewards: Dictionary = event.get("reward", {})
	_apply_rewards(pid, tile_idx, rewards)
	result["rewards"] = rewards

	# 更新状态
	data["total_explored"] += 1
	data["explore_cooldown"] = 2  # 2 回合冷却

	# 怪物战斗
	if event.get("combat", false):
		var combat_result = _handle_monster_combat(tile_idx, event.get("monster_power", 10), pid)
		result["combat"] = combat_result

	# 消息日志
	var log_color: String = "red" if event.get("negative", false) else "cyan"
	EventBus.message_log.emit("[color=%s]【洞穴探索】%s[/color]" % [log_color, event["desc"]])

	# 发射信号
	if EventBus.has_signal("cave_explored"):
		EventBus.cave_explored.emit(tile_idx, event["id"], rewards)

	return result

func _pick_explore_event(level: int) -> Dictionary:
	# 加权随机选取事件
	var total_weight: int = 0
	for e in EXPLORE_EVENTS:
		total_weight += e["weight"]
	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for e in EXPLORE_EVENTS:
		cumulative += e["weight"]
		if roll < cumulative:
			# 根据等级缩放奖励
			var scaled = e.duplicate(true)
			var mult: float = CAVE_LEVELS.get(level, CAVE_LEVELS[1])["resource_mult"]
			for key in scaled.get("reward", {}):
				if scaled["reward"][key] is int or scaled["reward"][key] is float:
					scaled["reward"][key] = int(scaled["reward"][key] * mult)
			return scaled
	return EXPLORE_EVENTS[0]

func _apply_rewards(pid: int, tile_idx: int, rewards: Dictionary) -> void:
	var res_rewards: Dictionary = {}
	if rewards.get("gold", 0) != 0:
		res_rewards["gold"] = rewards["gold"]
	if rewards.get("iron", 0) != 0:
		res_rewards["iron"] = rewards["iron"]
	if rewards.get("food", 0) != 0:
		res_rewards["food"] = rewards["food"]

	if not res_rewards.is_empty():
		for key in res_rewards:
			if res_rewards[key] > 0:
				ResourceManager.gain(pid, {key: res_rewards[key]})
			elif res_rewards[key] < 0:
				ResourceManager.spend(pid, {key: -res_rewards[key]})

	if rewards.get("morale", 0) != 0 and GameManager.morale_corruption_system:
		GameManager.morale_corruption_system.change_morale(tile_idx, float(rewards["morale"]))

	if rewards.get("garrison", 0) > 0:
		if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
			return
		var tile = GameManager.tiles[tile_idx]
		tile["garrison"] = tile.get("garrison", 0) + rewards["garrison"]

## 清剿怪物 — 消耗驻军，清除洞穴怪物
func clear_monsters(tile_idx: int) -> Dictionary:
	var data = get_cave_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[tile_idx]

	if data["cleared"]:
		return {"success": false, "reason": "洞穴已清剿"}

	var monster_power: int = data["monster_hp"]
	var garrison: int = tile.get("garrison", 0)

	if garrison < 5:
		return {"success": false, "reason": "驻军不足（需要至少 5 人）"}

	# 战斗结算：驻军 vs 怪物
	var garrison_power: int = garrison * 2
	if garrison_power >= monster_power:
		# 胜利
		var casualties: int = int(monster_power * 0.3)
		tile["garrison"] = max(garrison - casualties, 1)
		data["cleared"] = true
		data["monster_hp"] = 0

		# 清剿奖励
		var reward_gold: int = 30 + data["level"] * 20
		var reward_iron: int = 10 + data["level"] * 10
		ResourceManager.gain(pid, {"gold": reward_gold, "iron": reward_iron})
		EventBus.message_log.emit("[color=lime]【洞穴清剖】成功！获得 %d 金币，%d 铁矿，损失 %d 驻军[/color]" % [reward_gold, reward_iron, casualties])
		if EventBus.has_signal("cave_cleared"):
			var monster_id: String = data.get("monster_type", "unknown")
			EventBus.cave_cleared.emit(tile_idx, monster_id, {"gold": reward_gold, "iron": reward_iron})
		return {"success": true, "reward": {"gold": reward_gold, "iron": reward_iron}, "casualties": casualties}
	else:
		# 失败
		var casualties: int = int(garrison * 0.4)
		tile["garrison"] = max(garrison - casualties, 0)
		EventBus.message_log.emit("[color=red]【洞穴清剿】失败！损失 %d 驻军，怪物仍在洞穴中[/color]" % casualties)
		return {"success": false, "reason": "驻军战力不足", "casualties": casualties}

## 黑市交易
func buy_black_market(tile_idx: int, item_id: String) -> Dictionary:
	var data = get_cave_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()
	var level_data = CAVE_LEVELS.get(data["level"], CAVE_LEVELS[1])

	if not level_data["black_market"]:
		return {"success": false, "reason": "当前洞穴等级不支持黑市"}

	if item_id not in data["black_market_stock"]:
		return {"success": false, "reason": "该商品当前不在货架上"}

	# 找到商品定义
	var item: Dictionary = {}
	for bm in BLACK_MARKET_ITEMS:
		if bm["id"] == item_id:
			item = bm
			break
	if item.is_empty():
		return {"success": false, "reason": "未知商品"}

	# 检查费用
	if not ResourceManager.can_afford(pid, item["cost"]):
		return {"success": false, "reason": "资源不足"}

	# 扣除费用并给予奖励
	ResourceManager.spend(pid, item["cost"])
	_apply_rewards(pid, tile_idx, item["reward"])

	# 从货架移除
	data["black_market_stock"].erase(item_id)

	EventBus.message_log.emit("[color=yellow]【黑市】购买了 %s[/color]" % item["name"])
	if EventBus.has_signal("cave_black_market_purchased"):
		EventBus.cave_black_market_purchased.emit(tile_idx, item_id)

	return {"success": true, "item": item}

## 升级/改造洞穴
func upgrade_cave(tile_idx: int, upgrade_id: String) -> Dictionary:
	var data = get_cave_data(tile_idx)
	var pid: int = GameManager.get_human_player_id()

	if not UPGRADE_PATHS.has(upgrade_id):
		return {"success": false, "reason": "未知升级路径"}

	var upgrade = UPGRADE_PATHS[upgrade_id]

	if upgrade.get("requires_cleared", false) and not data["cleared"]:
		return {"success": false, "reason": "需要先清剿洞穴中的怪物"}

	if upgrade_id in data["upgrades"]:
		return {"success": false, "reason": "该升级已完成"}

	if not ResourceManager.can_afford(pid, upgrade["cost"]):
		return {"success": false, "reason": "资源不足"}

	ResourceManager.spend(pid, upgrade["cost"])
	data["upgrades"].append(upgrade_id)

	# 应用效果
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[tile_idx]
	var effects = upgrade["effects"]
	if effects.get("garrison", 0) > 0:
		tile["garrison"] = tile.get("garrison", 0) + effects["garrison"]
	if effects.get("def_bonus", 0) > 0:
		tile["def_bonus"] = tile.get("def_bonus", 0) + effects["def_bonus"]

	EventBus.message_log.emit("[color=cyan]【洞穴改造】%s 完成！[/color]" % upgrade["name"])
	if EventBus.has_signal("cave_upgraded"):
		EventBus.cave_upgraded.emit(tile_idx, upgrade_id)

	return {"success": true, "upgrade": upgrade}

## 洞穴等级提升（通过探索积累）
func try_level_up(tile_idx: int) -> bool:
	var data = get_cave_data(tile_idx)
	var current_level: int = data["level"]
	if current_level >= 4:
		return false
	# 每探索 5 次升一级
	if data["total_explored"] >= current_level * 5:
		data["level"] += 1
		# 刷新怪物
		data["monster_hp"] = _get_initial_monster_hp(data["level"])
		data["monster_id"] = _pick_monster_for_level(data["level"])
		data["cleared"] = false  # 升级后怪物重新出现
		EventBus.message_log.emit("[color=gold]【洞穴】深入探索，洞穴升级为 %s！[/color]" % CAVE_LEVELS[data["level"]]["name"])
		if EventBus.has_signal("cave_level_up"):
			EventBus.cave_level_up.emit(tile_idx, data["level"])
		return true
	return false

func _handle_monster_combat(tile_idx: int, monster_power: int, pid: int) -> Dictionary:
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[tile_idx]
	var garrison: int = tile.get("garrison", 0)
	if garrison * 2 >= monster_power:
		var reward_gold: int = monster_power * 2
		ResourceManager.gain(pid, {"gold": reward_gold})
		return {"victory": true, "reward": {"gold": reward_gold}}
	else:
		var casualties: int = int(garrison * 0.2)
		tile["garrison"] = max(garrison - casualties, 0)
		return {"victory": false, "casualties": casualties}

# ═══════════════════════════════════════════════════════════════
#                    回合处理
# ═══════════════════════════════════════════════════════════════
func process_turn() -> void:
	for tile_idx in _cave_data:
		var data = _cave_data[tile_idx]

		# 探索冷却递减
		if data["explore_cooldown"] > 0:
			data["explore_cooldown"] -= 1

		# 黑市每 5 回合刷新
		data["black_market_refresh"] += 1
		if data["black_market_refresh"] >= 5:
			data["black_market_refresh"] = 0
			data["black_market_stock"] = _generate_black_market_stock()
			EventBus.message_log.emit("[color=gray]【黑市】据点 #%d 的黑市商品已刷新[/color]" % tile_idx)

		# 未清剿的洞穴每回合有概率袭扰相邻据点
		if not data["cleared"]:
			_try_raid_neighbors(tile_idx, data)

		# 检查升级
		try_level_up(tile_idx)

func _try_raid_neighbors(tile_idx: int, data: Dictionary) -> void:
	if randf() > 0.15:  # 15% 概率袭扰
		return
	if not GameManager.adjacency.has(tile_idx):
		return
	for adj_idx in GameManager.adjacency[tile_idx]:
		if adj_idx >= GameManager.tiles.size():
			continue
		if adj_idx < 0 or adj_idx >= GameManager.tiles.size():
			return
		var adj_tile = GameManager.tiles[adj_idx]
		if adj_tile == null:
			continue
		var adj_owner: int = adj_tile.get("owner_id", -1)
		if adj_owner < 0:
			continue
		# 袭扰：减少相邻据点的产出
		var raid_damage: int = data["level"] * 5
		var current_gold = ResourceManager.get_resource(adj_owner, "gold")
		if current_gold > raid_damage:
			ResourceManager.spend(adj_owner, {"gold": raid_damage})
			EventBus.message_log.emit("[color=orange]【洞穴袭扰】据点 #%d 遭到洞穴怪物袭扰，损失 %d 金币！[/color]" % [adj_idx, raid_damage])
		break  # 每回合只袭扰一个相邻据点

# ═══════════════════════════════════════════════════════════════
#                    存档
# ═══════════════════════════════════════════════════════════════
func to_save_data() -> Dictionary:
	return {"cave_data": _cave_data.duplicate(true)}

func from_save_data(data: Dictionary) -> void:
	_cave_data = data.get("cave_data", {}).duplicate(true)
