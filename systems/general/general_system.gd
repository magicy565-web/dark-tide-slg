## general_system.gd
## 武将系统核心框架 —— 战国兰斯式行动扇子（Action Fan）机制
## 每位武将每回合拥有固定数量的行动扇子，消耗完毕后本回合无法再行动。
## 武将可执行：出征、驻守据点、执行内政、外交任务等。
## 作者: Manus AI  版本: v1.0.0
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")
const TerritoryTypeSystem = preload("res://systems/map/territory_type_system.gd")

# ═══════════════════════════════════════════════════════════════
#                    兵种枚举
# ═══════════════════════════════════════════════════════════════

enum TroopClass {
	SAMURAI,    # 武士/重步兵 — 高防，前排肉盾
	CAVALRY,    # 骑兵 — 高速突击，克制弓兵
	ARCHER,     # 弓兵 — 远程输出，克制步兵
	NINJA,      # 忍者 — 高速，可攻击后排
	MAGE,       # 法师 — 高智力，范围技能
	PRIEST,     # 祭司 — 治疗/辅助
	ASHIGARU,   # 足轻 — 廉价炮灰，数量优势
	CANNON,     # 炮兵 — 超高攻击，低速
}

const TROOP_CLASS_NAMES: Dictionary = {
	TroopClass.SAMURAI:  "武士",
	TroopClass.CAVALRY:  "骑兵",
	TroopClass.ARCHER:   "弓兵",
	TroopClass.NINJA:    "忍者",
	TroopClass.MAGE:     "法师",
	TroopClass.PRIEST:   "祭司",
	TroopClass.ASHIGARU: "足轻",
	TroopClass.CANNON:   "炮兵",
}

const TROOP_CLASS_ICONS: Dictionary = {
	TroopClass.SAMURAI:  "⚔",
	TroopClass.CAVALRY:  "🐴",
	TroopClass.ARCHER:   "🏹",
	TroopClass.NINJA:    "🌙",
	TroopClass.MAGE:     "✨",
	TroopClass.PRIEST:   "✚",
	TroopClass.ASHIGARU: "🛡",
	TroopClass.CANNON:   "💣",
}

## FactionData troop 字符串 → TroopClass 枚举映射
const TROOP_STRING_MAP: Dictionary = {
	"samurai":   TroopClass.SAMURAI,
	"cavalry":   TroopClass.CAVALRY,
	"archer":    TroopClass.ARCHER,
	"ninja":     TroopClass.NINJA,
	"mage_unit": TroopClass.MAGE,
	"priest":    TroopClass.PRIEST,
	"ashigaru":  TroopClass.ASHIGARU,
	"cannon":    TroopClass.CANNON,
}

# ═══════════════════════════════════════════════════════════════
#                    行动扇子常量
# ═══════════════════════════════════════════════════════════════

## 每位武将每回合的默认行动扇子数
const DEFAULT_FANS_PER_TURN: int = 1

## 各行动消耗的扇子数
const ACTION_FAN_COSTS: Dictionary = {
	"march":         1,   # 出征（攻打据点）
	"garrison":      1,   # 驻守据点
	"domestic":      1,   # 执行内政
	"diplomacy":     1,   # 外交任务
	"explore":       1,   # 探索
	"ritual":        1,   # 祭坛仪式
	"train":         1,   # 训练部队
	"rest":          0,   # 休息恢复（不消耗扇子）
}

# ═══════════════════════════════════════════════════════════════
#                    运行时状态
# ═══════════════════════════════════════════════════════════════

## 武将本回合剩余扇子数  hero_id -> int
var _fans_remaining: Dictionary = {}

## 武将本回合已执行的行动记录  hero_id -> Array[String]
var _actions_this_turn: Dictionary = {}

## 武将当前驻守的据点  hero_id -> tile_index
var _garrison_assignments: Dictionary = {}

## 据点当前驻守的武将列表  tile_index -> Array[hero_id]
var _tile_generals: Dictionary = {}

## 武将战斗状态（是否在出征中）  hero_id -> bool
var _on_march: Dictionary = {}

# ═══════════════════════════════════════════════════════════════
#                    回合管理
# ═══════════════════════════════════════════════════════════════

## 回合开始时重置所有武将的行动扇子
func reset_fans_for_new_turn(recruited_heroes: Array) -> void:
	_fans_remaining.clear()
	_actions_this_turn.clear()
	_on_march.clear()
	for hero_id in recruited_heroes:
		var max_fans: int = get_max_fans(hero_id)
		_fans_remaining[hero_id] = max_fans

## 获取武将的最大行动扇子数（基础值 + 速度加成）
func get_max_fans(hero_id: String) -> int:
	var hero_data: Dictionary = _get_hero_data(hero_id)
	var spd: int = hero_data.get("spd", 4)
	# 速度≥8 的武将获得额外1个扇子（高速武将更灵活）
	var bonus: int = 1 if spd >= 8 else 0
	return DEFAULT_FANS_PER_TURN + bonus

## 获取武将当前剩余扇子数
func get_fans_remaining(hero_id: String) -> int:
	return _fans_remaining.get(hero_id, 0)

## 检查武将是否还有行动扇子
func has_fans(hero_id: String) -> bool:
	return get_fans_remaining(hero_id) > 0

## 消耗武将的行动扇子
## 返回 true 表示成功消耗，false 表示扇子不足
func consume_fan(hero_id: String, action: String = "march") -> bool:
	var cost: int = ACTION_FAN_COSTS.get(action, 1)
	var remaining: int = get_fans_remaining(hero_id)
	if remaining < cost:
		return false
	_fans_remaining[hero_id] = remaining - cost
	if not _actions_this_turn.has(hero_id):
		_actions_this_turn[hero_id] = []
	_actions_this_turn[hero_id].append(action)
	return true

## 获取武将本回合已执行的行动列表
func get_actions_this_turn(hero_id: String) -> Array:
	return _actions_this_turn.get(hero_id, [])

# ═══════════════════════════════════════════════════════════════
#                    驻守系统
# ═══════════════════════════════════════════════════════════════

## 将武将分配到据点驻守
## 返回 true 表示成功，false 表示据点已满或武将无扇子
func assign_garrison(hero_id: String, tile_index: int) -> bool:
	# 检查扇子
	if not has_fans(hero_id):
		push_warning("GeneralSystem: %s 行动扇子不足，无法驻守" % hero_id)
		return false
	# 检查据点驻守上限
	var tile: Dictionary = _get_tile(tile_index)
	if tile.is_empty():
		return false
	var prov_type: int = TerritoryTypeSystem.get_prov_type_from_tile(tile)
	var max_slots: int = TerritoryTypeSystem.get_garrison_slots(prov_type)
	var current_generals: Array = _tile_generals.get(tile_index, [])
	if current_generals.size() >= max_slots:
		push_warning("GeneralSystem: 据点 %d 驻守位已满（上限 %d）" % [tile_index, max_slots])
		return false
	# 解除旧驻守
	_remove_garrison(hero_id)
	# 分配新驻守
	_garrison_assignments[hero_id] = tile_index
	if not _tile_generals.has(tile_index):
		_tile_generals[tile_index] = []
	_tile_generals[tile_index].append(hero_id)
	# 消耗扇子
	consume_fan(hero_id, "garrison")
	return true

## 解除武将的驻守
func _remove_garrison(hero_id: String) -> void:
	if _garrison_assignments.has(hero_id):
		var old_tile: int = _garrison_assignments[hero_id]
		if _tile_generals.has(old_tile):
			_tile_generals[old_tile].erase(hero_id)
		_garrison_assignments.erase(hero_id)

## 获取武将当前驻守的据点索引（-1 表示未驻守）
func get_garrison_tile(hero_id: String) -> int:
	return _garrison_assignments.get(hero_id, -1)

## 获取据点当前驻守的武将列表
func get_tile_generals(tile_index: int) -> Array:
	return _tile_generals.get(tile_index, [])

## 获取据点驻守武将的战斗加成（汇总所有驻守武将的加成）
func get_garrison_combat_bonus(tile_index: int) -> Dictionary:
	var bonus: Dictionary = {"atk": 0, "def": 0, "int": 0, "spd": 0}
	var generals: Array = get_tile_generals(tile_index)
	for hero_id in generals:
		var hero_data: Dictionary = _get_hero_data(hero_id)
		# 驻守武将提供其 def 值的 50% 作为据点防御加成
		bonus["def"] += int(hero_data.get("def", 0) * 0.5)
		bonus["atk"] += int(hero_data.get("atk", 0) * 0.3)
	return bonus

# ═══════════════════════════════════════════════════════════════
#                    武将属性查询
# ═══════════════════════════════════════════════════════════════

## 获取武将的兵种枚举值
func get_troop_class(hero_id: String) -> int:
	var hero_data: Dictionary = _get_hero_data(hero_id)
	var troop_str: String = hero_data.get("troop", "ashigaru")
	return TROOP_STRING_MAP.get(troop_str, TroopClass.ASHIGARU)

## 获取武将兵种名称
func get_troop_class_name(hero_id: String) -> String:
	return TROOP_CLASS_NAMES.get(get_troop_class(hero_id), "足轻")

## 获取武将兵种图标
func get_troop_class_icon(hero_id: String) -> String:
	return TROOP_CLASS_ICONS.get(get_troop_class(hero_id), "🛡")

## 获取武将显示名称
func get_general_name(hero_id: String) -> String:
	var hero_data: Dictionary = _get_hero_data(hero_id)
	return hero_data.get("name", hero_id)

## 获取武将完整属性摘要（用于 UI 显示）
func get_general_summary(hero_id: String) -> Dictionary:
	var hero_data: Dictionary = _get_hero_data(hero_id)
	return {
		"id": hero_id,
		"name": hero_data.get("name", hero_id),
		"faction": hero_data.get("faction", "neutral"),
		"troop_class": get_troop_class(hero_id),
		"troop_class_name": get_troop_class_name(hero_id),
		"troop_icon": get_troop_class_icon(hero_id),
		"atk": hero_data.get("atk", 5),
		"def": hero_data.get("def", 5),
		"int": hero_data.get("int", 5),
		"spd": hero_data.get("spd", 5),
		"fans_remaining": get_fans_remaining(hero_id),
		"fans_max": get_max_fans(hero_id),
		"is_available": has_fans(hero_id),
		"garrison_tile": get_garrison_tile(hero_id),
		"on_march": _on_march.get(hero_id, false),
		"active_skill": hero_data.get("active", ""),
		"passive_skill": hero_data.get("passive", ""),
	}

## 获取所有已招募武将的摘要列表（按行动扇子可用性排序）
func get_all_general_summaries(recruited_heroes: Array) -> Array:
	var summaries: Array = []
	for hero_id in recruited_heroes:
		summaries.append(get_general_summary(hero_id))
	# 有扇子的武将排在前面
	summaries.sort_custom(func(a, b): return a["is_available"] and not b["is_available"])
	return summaries

# ═══════════════════════════════════════════════════════════════
#                    据点驻守加成（结合据点类型）
# ═══════════════════════════════════════════════════════════════

## 计算武将在特定类型据点的驻守加成描述
func get_garrison_bonus_for_tile(hero_id: String, tile_index: int) -> String:
	var tile: Dictionary = _get_tile(tile_index)
	if tile.is_empty():
		return ""
	var prov_type: int = TerritoryTypeSystem.get_prov_type_from_tile(tile)
	var base_desc: String = TerritoryTypeSystem.get_general_bonus_desc(prov_type)
	var troop_class: int = get_troop_class(hero_id)
	# 特殊兵种与据点类型的协同加成
	var synergy_desc: String = ""
	match prov_type:
		TerritoryTypeSystem.ProvType.FORTRESS:
			if troop_class == TroopClass.SAMURAI:
				synergy_desc = "武士×要塞: 额外 DEF+3"
		TerritoryTypeSystem.ProvType.SANCTUARY:
			if troop_class in [TroopClass.MAGE, TroopClass.PRIEST]:
				synergy_desc = "法师×祭坛: 技能威力额外+15%"
		TerritoryTypeSystem.ProvType.GATE:
			if troop_class == TroopClass.CAVALRY:
				synergy_desc = "骑兵×关隘: 反击速度+2"
		TerritoryTypeSystem.ProvType.RUINS:
			if troop_class == TroopClass.NINJA:
				synergy_desc = "忍者×遗迹: 探索触发率+20%"
	if synergy_desc != "":
		return "%s\n%s" % [base_desc, synergy_desc]
	return base_desc

# ═══════════════════════════════════════════════════════════════
#                    存档 / 读档
# ═══════════════════════════════════════════════════════════════

func serialize() -> Dictionary:
	return {
		"fans_remaining": _fans_remaining.duplicate(),
		"actions_this_turn": _actions_this_turn.duplicate(),
		"garrison_assignments": _garrison_assignments.duplicate(),
		"tile_generals": _tile_generals.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	_fans_remaining = data.get("fans_remaining", {})
	_actions_this_turn = data.get("actions_this_turn", {})
	_garrison_assignments = data.get("garrison_assignments", {})
	_tile_generals = data.get("tile_generals", {})

func reset() -> void:
	_fans_remaining.clear()
	_actions_this_turn.clear()
	_garrison_assignments.clear()
	_tile_generals.clear()
	_on_march.clear()

# ═══════════════════════════════════════════════════════════════
#                    内部辅助函数
# ═══════════════════════════════════════════════════════════════

func _get_hero_data(hero_id: String) -> Dictionary:
	return FactionData.HEROES.get(hero_id, {})

func _get_tile(tile_index: int) -> Dictionary:
	if not is_instance_valid(GameManager):
		return {}
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return {}
	return GameManager.tiles[tile_index]

# ═══════════════════════════════════════════════════════════════
#                    Autoload 生命周期（接入 EventBus）
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	## 作为 Autoload 节点，在游戏启动时自动连接回合信号
	if EventBus.has_signal("turn_started"):
		EventBus.turn_started.connect(_on_turn_started)
	if EventBus.has_signal("turn_ended"):
		EventBus.turn_ended.connect(_on_turn_ended)

func _on_turn_started(player_id: int) -> void:
	## 每回合开始时，重置该玩家所有已招募武将的行动扇子
	if not is_instance_valid(GameManager):
		return
	if not GameManager.game_active:
		return
	# 获取该玩家已招募的武将列表（通过 HeroSystem）
	var recruited: Array = []
	if is_instance_valid(HeroSystem):
		recruited = HeroSystem.get_recruited_heroes(player_id)
	reset_fans_for_new_turn(recruited)

func _on_turn_ended(_player_id: int) -> void:
	## 回合结束时，将驻守武将的加成应用到据点防御（供战斗系统读取）
	pass  # 当前版本通过 get_garrison_combat_bonus() 实时查询，无需缓存
