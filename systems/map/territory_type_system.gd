## territory_type_system.gd
## 据点差异化类型系统 —— 战国兰斯式地域压制重构
## 每种据点类型拥有独特的视觉主题、战略加成和可用行动。
## 作者: Manus AI  版本: v1.0.0
class_name TerritoryTypeSystem
extends RefCounted

# ═══════════════════════════════════════════════════════════════
#                    据点类型枚举
# ═══════════════════════════════════════════════════════════════

enum ProvType {
	FORTRESS,    # 军事要塞 — 高防御、驻守加成、征兵优先
	TOWN,        # 繁荣城镇 — 高金币产出、商业建筑、民心系统
	SANCTUARY,   # 魔法祭坛 — 特殊资源、武将技能加成、神秘事件
	GATE,        # 战略关隘 — 咽喉要道、通行控制、补给线核心
	RESOURCE,    # 资源据点 — 矿场/农场/港口，专项资源产出
	RUINS,       # 古代遗迹 — 探索事件、随机奖励、隐藏剧情
	BANDIT,      # 盗贼巢穴 — 中立敌对、清剿奖励、可改造
	WILDERNESS,  # 荒野前哨 — 基础据点，扩张跳板
}

# ═══════════════════════════════════════════════════════════════
#                    类型元数据定义
# ═══════════════════════════════════════════════════════════════

## 每种据点类型的完整属性定义
const TYPE_DATA: Dictionary = {
	ProvType.FORTRESS: {
		"name": "军事要塞",
		"icon": "🏰",
		"theme_color": Color(0.55, 0.25, 0.15),       # 深红棕 — 铁血
		"header_color": Color(1.0, 0.55, 0.3),         # 橙红
		"border_color": Color(0.8, 0.4, 0.2, 0.9),
		"bg_color": Color(0.12, 0.07, 0.05, 0.95),
		"description": "扼守要道的军事堡垒，驻守武将获得防御加成，每回合自动补充兵力。",
		# 战略加成
		"bonuses": {
			"def_mult": 1.4,          # 防御倍率
			"recruit_bonus": 3,       # 每回合额外补充兵力
			"garrison_slots": 3,      # 最大驻守武将数
			"action_fan_cost": 1,     # 攻占此据点消耗的行动扇子
		},
		# 可用内政行动
		"available_actions": ["recruit", "upgrade_walls", "train_elite", "guard"],
		# 快捷行动（右侧面板直接显示）
		"quick_actions": ["recruit", "guard"],
		# 连携效果（相邻同势力时激活）
		"synergy": {
			"type": "fortress_network",
			"description": "要塞网络: 相邻要塞互相提供+10%防御",
			"def_bonus_pct": 0.10,
		},
		# 将领驻守加成
		"general_bonus": {
			"def": 5,
			"description": "驻守要塞: DEF+5",
		},
	},
	ProvType.TOWN: {
		"name": "繁荣城镇",
		"icon": "🏘",
		"theme_color": Color(0.15, 0.35, 0.15),       # 深绿 — 繁荣
		"header_color": Color(0.6, 1.0, 0.4),          # 亮绿
		"border_color": Color(0.3, 0.7, 0.3, 0.9),
		"bg_color": Color(0.06, 0.12, 0.06, 0.95),
		"description": "商贸繁荣的城镇，每回合产出大量金币，但防御薄弱，需要驻军保护。",
		"bonuses": {
			"gold_mult": 1.5,         # 金币产出倍率
			"food_bonus": 2,          # 额外粮食
			"garrison_slots": 2,
			"action_fan_cost": 1,
		},
		"available_actions": ["domestic", "build_market", "recruit", "diplomacy"],
		"quick_actions": ["domestic", "build_market"],
		"synergy": {
			"type": "trade_route",
			"description": "贸易路线: 相邻城镇互相提供+15%金币",
			"gold_bonus_pct": 0.15,
		},
		"general_bonus": {
			"int": 3,
			"description": "驻守城镇: INT+3（提升内政效率）",
		},
	},
	ProvType.SANCTUARY: {
		"name": "魔法祭坛",
		"icon": "✨",
		"theme_color": Color(0.2, 0.1, 0.4),           # 深紫 — 神秘
		"header_color": Color(0.8, 0.5, 1.0),           # 亮紫
		"border_color": Color(0.6, 0.3, 0.9, 0.9),
		"bg_color": Color(0.08, 0.04, 0.15, 0.95),
		"description": "古老的魔法祭坛，提升范围内武将的技能威力，产出神秘魔晶资源。",
		"bonuses": {
			"skill_power_bonus": 0.20,  # 武将技能威力+20%
			"crystal_per_turn": 2,      # 每回合产出魔晶
			"garrison_slots": 2,
			"action_fan_cost": 1,
		},
		"available_actions": ["explore", "ritual", "recruit", "research"],
		"quick_actions": ["explore", "ritual"],
		"synergy": {
			"type": "arcane_network",
			"description": "秘法网络: 相邻祭坛使范围内武将技能冷却-1",
			"skill_cd_reduction": 1,
		},
		"general_bonus": {
			"int": 5,
			"skill_power": 0.10,
			"description": "驻守祭坛: INT+5，技能威力+10%",
		},
	},
	ProvType.GATE: {
		"name": "战略关隘",
		"icon": "⚔",
		"theme_color": Color(0.35, 0.3, 0.1),           # 深金 — 战略
		"header_color": Color(1.0, 0.85, 0.2),           # 亮金
		"border_color": Color(0.9, 0.75, 0.2, 0.9),
		"bg_color": Color(0.12, 0.1, 0.03, 0.95),
		"description": "扼守交通要道的战略关隘，控制此地可阻断敌方补给线，是必争之地。",
		"bonuses": {
			"def_mult": 1.6,            # 最高防御倍率
			"supply_block": true,       # 可阻断补给线
			"garrison_slots": 2,
			"action_fan_cost": 2,       # 攻占关隘需消耗2个行动扇子
		},
		"available_actions": ["guard", "fortify", "recruit", "block_supply"],
		"quick_actions": ["guard", "fortify"],
		"synergy": {
			"type": "chokepoint_control",
			"description": "要道控制: 相邻关隘形成封锁线，敌方补给效率-30%",
			"enemy_supply_penalty": 0.30,
		},
		"general_bonus": {
			"def": 8,
			"description": "驻守关隘: DEF+8（关隘守将加成）",
		},
	},
	ProvType.RESOURCE: {
		"name": "资源据点",
		"icon": "⛏",
		"theme_color": Color(0.3, 0.2, 0.05),           # 深棕 — 资源
		"header_color": Color(0.9, 0.7, 0.3),            # 金棕
		"border_color": Color(0.7, 0.5, 0.2, 0.9),
		"bg_color": Color(0.1, 0.07, 0.02, 0.95),
		"description": "专项资源产地，包括矿场、农场、港口等，是势力经济的重要支柱。",
		"bonuses": {
			"resource_mult": 2.0,       # 专项资源产出翻倍
			"iron_mult": 2.0,           # 铁矿产出倍率
			"food_mult": 2.0,           # 簮食产出倍率（农场类）
			"garrison_slots": 1,
			"action_fan_cost": 1,
		},
		"available_actions": ["exploit", "upgrade_facility", "recruit"],
		"quick_actions": ["exploit"],
		"synergy": {
			"type": "supply_chain",
			"description": "供应链: 相邻资源据点互相提升10%产出",
			"resource_bonus_pct": 0.10,
		},
		"general_bonus": {
			"description": "驻守资源据点: 产出+15%",
			"resource_pct": 0.15,
		},
	},
	ProvType.RUINS: {
		"name": "古代遗迹",
		"icon": "🗿",
		"theme_color": Color(0.25, 0.22, 0.18),          # 灰棕 — 古老
		"header_color": Color(0.75, 0.7, 0.55),           # 米黄
		"border_color": Color(0.5, 0.45, 0.3, 0.9),
		"bg_color": Color(0.09, 0.08, 0.06, 0.95),
		"description": "上古文明的遗址，探索可获得随机奖励或触发隐藏剧情，充满未知危险。",
		"bonuses": {
			"explore_reward_mult": 1.5, # 探索奖励倍率
			"event_chance": 0.25,       # 每回合触发事件概率
			"garrison_slots": 1,
			"action_fan_cost": 1,
		},
		"available_actions": ["explore", "excavate", "recruit"],
		"quick_actions": ["explore", "excavate"],
		"synergy": {
			"type": "ancient_knowledge",
			"description": "古代知识: 相邻遗迹使探索奖励+20%",
			"explore_bonus_pct": 0.20,
		},
		"general_bonus": {
			"description": "驻守遗迹: 探索行动额外触发一次事件",
			"extra_explore_event": true,
		},
	},
	ProvType.BANDIT: {
		"name": "盗贼巢穴",
		"icon": "💀",
		"theme_color": Color(0.2, 0.2, 0.2),             # 深灰 — 危险
		"header_color": Color(0.7, 0.7, 0.7),             # 浅灰
		"border_color": Color(0.4, 0.4, 0.4, 0.9),
		"bg_color": Color(0.07, 0.07, 0.07, 0.95),
		"description": "盗贼占据的危险巢穴，清剿后可获得大量奖励，并可改造为前哨站。",
		"bonuses": {
			"defeat_reward_gold": 30,   # 清剿奖励金币
			"defeat_reward_iron": 10,   # 清剿奖励铁矿
			"garrison_slots": 1,
			"action_fan_cost": 1,
		},
		"available_actions": ["attack", "recruit"],
		"quick_actions": ["attack"],
		"synergy": {
			"type": "none",
			"description": "无连携效果",
		},
		"general_bonus": {
			"description": "清剿盗贼: 奖励+25%",
			"defeat_reward_pct": 0.25,
		},
	},
	ProvType.WILDERNESS: {
		"name": "荒野前哨",
		"icon": "🌿",
		"theme_color": Color(0.1, 0.2, 0.1),             # 暗绿 — 荒野
		"header_color": Color(0.5, 0.75, 0.4),            # 草绿
		"border_color": Color(0.3, 0.5, 0.25, 0.9),
		"bg_color": Color(0.05, 0.1, 0.04, 0.95),
		"description": "荒野中的简陋前哨，是扩张领土的跳板，可逐步升级为更高级的据点。",
		"bonuses": {
			"garrison_slots": 1,
			"action_fan_cost": 1,
			"upgrade_discount": 0.10,   # 升级费用折扣
		},
		"available_actions": ["recruit", "upgrade_outpost", "explore"],
		"quick_actions": ["recruit"],
		"synergy": {
			"type": "frontier_expansion",
			"description": "边疆扩张: 相邻荒野前哨使探索范围+1",
			"explore_range_bonus": 1,
		},
		"general_bonus": {
			"spd": 2,
			"description": "驻守前哨: SPD+2（便于快速支援）",
		},
	},
}

# ═══════════════════════════════════════════════════════════════
#              GameManager TileType → ProvType 映射
# ═══════════════════════════════════════════════════════════════

## 将现有的 GameManager.TileType 整数映射到新的 ProvType
## 保持向后兼容，无需修改地图数据
static func tile_type_to_prov_type(tile_type: int) -> int:
	# GameManager.TileType 枚举值（按顺序）:
	# 0=LIGHT_STRONGHOLD, 1=LIGHT_VILLAGE, 2=DARK_BASE, 3=MINE_TILE, 4=FARM_TILE,
	# 5=WILDERNESS, 6=EVENT_TILE, 7=START, 8=RESOURCE_STATION, 9=CORE_FORTRESS,
	# 10=NEUTRAL_BASE, 11=TRADING_POST, 12=WATCHTOWER, 13=RUINS, 14=HARBOR, 15=CHOKEPOINT
	match tile_type:
		0:  return ProvType.FORTRESS    # LIGHT_STRONGHOLD → 军事要塞
		1:  return ProvType.TOWN        # LIGHT_VILLAGE → 繁荣城镇
		2:  return ProvType.FORTRESS    # DARK_BASE → 军事要塞（暗黑风格）
		3:  return ProvType.RESOURCE    # MINE_TILE → 资源据点（矿场）
		4:  return ProvType.RESOURCE    # FARM_TILE → 资源据点（农场）
		5:  return ProvType.WILDERNESS  # WILDERNESS → 荒野前哨
		6:  return ProvType.RUINS       # EVENT_TILE → 古代遗迹（事件触发）
		7:  return ProvType.FORTRESS    # START → 军事要塞（起始据点）
		8:  return ProvType.RESOURCE    # RESOURCE_STATION → 资源据点
		9:  return ProvType.FORTRESS    # CORE_FORTRESS → 军事要塞（核心）
		10: return ProvType.BANDIT      # NEUTRAL_BASE → 盗贼巢穴（中立势力）
		11: return ProvType.TOWN        # TRADING_POST → 繁荣城镇（交易站）
		12: return ProvType.GATE        # WATCHTOWER → 战略关隘（瞭望塔控制要道）
		13: return ProvType.RUINS       # RUINS → 古代遗迹
		14: return ProvType.RESOURCE    # HARBOR → 资源据点（港口）
		15: return ProvType.GATE        # CHOKEPOINT → 战略关隘
		_:  return ProvType.WILDERNESS  # 默认荒野

## 从 fixed_map_data 的字符串类型映射到 ProvType
static func string_type_to_prov_type(type_str: String) -> int:
	match type_str.to_upper():
		"FORTRESS":   return ProvType.FORTRESS
		"VILLAGE":    return ProvType.TOWN
		"OUTPOST":    return ProvType.WILDERNESS
		"BANDIT":     return ProvType.BANDIT
		"RESOURCE":   return ProvType.RESOURCE
		"SANCTUARY":  return ProvType.SANCTUARY
		"GATE":       return ProvType.GATE
		"RUINS":      return ProvType.RUINS
		_:            return ProvType.WILDERNESS

# ═══════════════════════════════════════════════════════════════
#                    便捷查询函数
# ═══════════════════════════════════════════════════════════════

## 获取据点类型的完整数据
static func get_type_data(prov_type: int) -> Dictionary:
	return TYPE_DATA.get(prov_type, TYPE_DATA[ProvType.WILDERNESS])

## 获取据点类型名称
static func get_type_name(prov_type: int) -> String:
	return get_type_data(prov_type).get("name", "荒野前哨")

## 获取据点类型图标
static func get_type_icon(prov_type: int) -> String:
	return get_type_data(prov_type).get("icon", "🌿")

## 获取据点主题颜色（用于 UI 背景）
static func get_theme_color(prov_type: int) -> Color:
	return get_type_data(prov_type).get("theme_color", Color(0.1, 0.2, 0.1))

## 获取据点标题颜色
static func get_header_color(prov_type: int) -> Color:
	return get_type_data(prov_type).get("header_color", Color(0.5, 0.75, 0.4))

## 获取据点边框颜色
static func get_border_color(prov_type: int) -> Color:
	return get_type_data(prov_type).get("border_color", Color(0.3, 0.5, 0.25, 0.9))

## 获取据点背景颜色
static func get_bg_color(prov_type: int) -> Color:
	return get_type_data(prov_type).get("bg_color", Color(0.05, 0.1, 0.04, 0.95))

## 获取据点描述
static func get_description(prov_type: int) -> String:
	return get_type_data(prov_type).get("description", "")

## 获取据点战略加成
static func get_bonuses(prov_type: int) -> Dictionary:
	return get_type_data(prov_type).get("bonuses", {})

## 获取据点可用行动列表
static func get_available_actions(prov_type: int) -> Array:
	return get_type_data(prov_type).get("available_actions", ["recruit"])

## 获取据点快捷行动（面板直接显示的按钮）
static func get_quick_actions(prov_type: int) -> Array:
	return get_type_data(prov_type).get("quick_actions", [])

## 获取连携效果
static func get_synergy(prov_type: int) -> Dictionary:
	return get_type_data(prov_type).get("synergy", {})

## 获取武将驻守加成描述
static func get_general_bonus_desc(prov_type: int) -> String:
	return get_type_data(prov_type).get("general_bonus", {}).get("description", "")

## 获取攻占此据点消耗的行动扇子数
static func get_action_fan_cost(prov_type: int) -> int:
	return get_type_data(prov_type).get("bonuses", {}).get("action_fan_cost", 1)

## 获取最大驻守武将数
static func get_garrison_slots(prov_type: int) -> int:
	return get_type_data(prov_type).get("bonuses", {}).get("garrison_slots", 1)

## 从 tile 字典直接获取 ProvType（兼容新旧两种数据格式）
static func get_prov_type_from_tile(tile: Dictionary) -> int:
	# 优先使用新的 prov_type 字段
	if tile.has("prov_type"):
		return tile["prov_type"]
	# 兼容旧格式：从 type 整数映射
	if tile.has("type") and tile["type"] is int:
		return tile_type_to_prov_type(tile["type"])
	# 兼容 fixed_map_data 字符串格式
	if tile.has("type") and tile["type"] is String:
		return string_type_to_prov_type(tile["type"])
	return ProvType.WILDERNESS
