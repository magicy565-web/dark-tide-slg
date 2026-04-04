## faction_config.gd - 势力配置文件 (战国兰斯风格)
## 定义5个主要AI势力的完整属性、特性、AI行为参数
extends Node
## NOTE: Registered as autoload "FactionConfig" - do not add class_name

# ═══════════════════════════════════════════════════════════
# 势力ID枚举 (与FactionData保持兼容)
# ═══════════════════════════════════════════════════════════
enum FactionType {
	ORC = 0,         # 兽人部落 (玩家可选)
	PIRATE = 1,      # 暗黑海盗 (玩家可选)
	DARK_ELF = 2,    # 黑暗精灵议会 (玩家可选)
	HUMAN = 3,       # 人类王国 (AI)
	HIGH_ELF = 4,    # 精灵族 (AI)
}

# ═══════════════════════════════════════════════════════════
# 势力完整配置数据
# ═══════════════════════════════════════════════════════════
const FACTION_CONFIGS: Dictionary = {
	FactionType.ORC: {
		"id": FactionType.ORC,
		"name": "兽人部落",
		"key": "orc",
		"color": Color(0.6, 0.2, 0.1),
		"leader": "大酋长·碎骨",
		"capital": "碎骨王座",
		"lore": "野蛮而强大的兽人部落，以WAAAGH!战争狂热著称。数量优势和近战爆发力是其核心战力。",
		
		# 起始资源
		"start_gold": 200,
		"start_food": 50,
		"start_iron": 40,
		"start_army": 12,
		"start_prestige": 0,
		
		# 经济特性
		"gold_income_mult": 0.75,   # 金币收入倍率 (低，依赖掠夺)
		"food_per_soldier": 0.8,    # 每士兵粮食消耗
		"iron_per_recruit": 12,     # 招募消耗铁矿
		"gold_per_recruit": 45,     # 招募消耗金币
		"recruit_cap_bonus": 5,     # 额外招募上限
		
		# 战斗特性
		"atk_bonus": 3,             # 基础攻击加成
		"def_bonus": 0,             # 基础防御加成
		"combat_style": "aggressive", # 战斗风格
		"special_mechanic": "waaagh", # 特殊机制
		
		# AI行为参数
		"ai_aggression": 0.85,      # 进攻倾向 (0-1)
		"ai_expansion_priority": 0.9, # 扩张优先级
		"ai_economy_priority": 0.3,  # 经济优先级
		"ai_diplomacy_priority": 0.1, # 外交优先级
		"ai_defense_threshold": 0.3,  # 防御触发阈值 (兵力比)
		
		# 内政优先级 (建筑建造顺序)
		"building_priority": ["arena", "training_ground", "labor_camp", "slave_market", "fortification"],
		
		# 特殊单位
		"unique_units": ["orc_ashigaru", "orc_samurai", "orc_cavalry"],
		"elite_unit": "orc_berserker",
		
		# 外交倾向
		"diplomacy_bias": {
			"human": "hostile",    # 对人类王国：敌对
			"high_elf": "hostile", # 对精灵族：敌对
			"pirate": "neutral",   # 对海盗：中立
			"dark_elf": "neutral", # 对暗精灵：中立
		},
		
		# 特殊事件触发条件
		"special_events": {
			"waaagh_rally": {"waaagh_min": 50, "desc": "WAAAGH!大集结"},
			"blood_feast": {"turn_interval": 10, "desc": "血祭仪式"},
		},
	},
	
	FactionType.PIRATE: {
		"id": FactionType.PIRATE,
		"name": "暗黑海盗",
		"key": "pirate",
		"color": Color(0.15, 0.15, 0.4),
		"leader": "船长·深渊",
		"capital": "深渊港",
		"lore": "横行海上的海盗联盟，以掠夺和贸易为生。炮击手和海上机动是其核心优势。",
		
		# 起始资源
		"start_gold": 300,
		"start_food": 40,
		"start_iron": 30,
		"start_army": 10,
		"start_prestige": 0,
		
		# 经济特性
		"gold_income_mult": 1.2,    # 金币收入倍率 (高，贸易/掠夺)
		"food_per_soldier": 0.9,
		"iron_per_recruit": 15,
		"gold_per_recruit": 55,
		"plunder_bonus": 1.5,       # 掠夺收益倍率
		
		# 战斗特性
		"atk_bonus": 2,
		"def_bonus": -1,
		"combat_style": "raiding",
		"special_mechanic": "rum_morale",
		
		# AI行为参数
		"ai_aggression": 0.65,
		"ai_expansion_priority": 0.7,
		"ai_economy_priority": 0.7,
		"ai_diplomacy_priority": 0.3,
		"ai_defense_threshold": 0.4,
		
		# 内政优先级
		"building_priority": ["merchant_guild", "warehouse", "slave_market", "training_ground", "fortification"],
		
		# 特殊单位
		"unique_units": ["pirate_ashigaru", "pirate_archer", "pirate_cannon"],
		"elite_unit": "pirate_captain",
		
		# 外交倾向
		"diplomacy_bias": {
			"human": "hostile",
			"high_elf": "neutral",
			"orc": "neutral",
			"dark_elf": "friendly",
		},
		
		# 特殊事件
		"special_events": {
			"black_market": {"gold_min": 200, "desc": "黑市交易"},
			"mutiny": {"morale_min": 80, "desc": "船员哗变"},
		},
	},
	
	FactionType.DARK_ELF: {
		"id": FactionType.DARK_ELF,
		"name": "黑暗精灵议会",
		"key": "dark_elf",
		"color": Color(0.35, 0.1, 0.45),
		"leader": "议长·永夜",
		"capital": "永夜暗城",
		"lore": "神秘的黑暗精灵，精通魔法与暗杀。情报网络和奴隶经济是其独特优势。",
		
		# 起始资源
		"start_gold": 250,
		"start_food": 35,
		"start_iron": 35,
		"start_army": 8,
		"start_prestige": 0,
		
		# 经济特性
		"gold_income_mult": 1.0,
		"food_per_soldier": 0.7,    # 低粮食消耗
		"iron_per_recruit": 10,
		"gold_per_recruit": 60,
		"slave_bonus": 2.0,         # 奴隶产出倍率
		
		# 战斗特性
		"atk_bonus": 1,
		"def_bonus": 2,
		"combat_style": "tactical",
		"special_mechanic": "intel_network",
		
		# AI行为参数
		"ai_aggression": 0.5,
		"ai_expansion_priority": 0.6,
		"ai_economy_priority": 0.6,
		"ai_diplomacy_priority": 0.5,
		"ai_defense_threshold": 0.5,
		
		# 内政优先级
		"building_priority": ["academy", "slave_market", "fortification", "labor_camp", "training_ground"],
		
		# 特殊单位
		"unique_units": ["de_samurai", "de_cavalry", "de_ninja"],
		"elite_unit": "shadow_walker",
		
		# 外交倾向
		"diplomacy_bias": {
			"human": "hostile",
			"high_elf": "hostile",
			"orc": "neutral",
			"pirate": "friendly",
		},
		
		# 特殊事件
		"special_events": {
			"shadow_ritual": {"slaves_min": 5, "desc": "暗影仪式"},
			"intel_breach": {"intel_min": 30, "desc": "情报泄露"},
		},
	},
	
	FactionType.HUMAN: {
		"id": FactionType.HUMAN,
		"name": "人类王国",
		"key": "human",
		"color": Color(0.8, 0.7, 0.2),
		"leader": "女王·凛",
		"capital": "奥德里安城",
		"lore": "古老而强大的人类王国，以坚固的城防和均衡的军队著称。守护光明是其使命。",
		
		# 起始资源 (AI势力，资源较多)
		"start_gold": 400,
		"start_food": 80,
		"start_iron": 60,
		"start_army": 15,
		"start_prestige": 10,
		
		# 经济特性
		"gold_income_mult": 1.1,
		"food_per_soldier": 1.0,
		"iron_per_recruit": 12,
		"gold_per_recruit": 50,
		"wall_bonus": 1.3,          # 城防加成
		
		# 战斗特性
		"atk_bonus": 1,
		"def_bonus": 4,
		"combat_style": "defensive",
		"special_mechanic": "city_walls",
		
		# AI行为参数
		"ai_aggression": 0.4,
		"ai_expansion_priority": 0.5,
		"ai_economy_priority": 0.6,
		"ai_diplomacy_priority": 0.7,
		"ai_defense_threshold": 0.6,
		
		# 内政优先级
		"building_priority": ["fortification", "merchant_guild", "training_ground", "labor_camp", "academy"],
		
		# 特殊单位
		"unique_units": ["human_ashigaru", "human_cavalry", "human_samurai"],
		"elite_unit": "royal_guard",
		
		# 外交倾向
		"diplomacy_bias": {
			"high_elf": "friendly",
			"orc": "hostile",
			"pirate": "hostile",
			"dark_elf": "hostile",
		},
		
		# 特殊事件
		"special_events": {
			"royal_decree": {"prestige_min": 20, "desc": "王室诏令"},
			"alliance_summit": {"turn_min": 15, "desc": "光明联盟峰会"},
		},
	},
	
	FactionType.HIGH_ELF: {
		"id": FactionType.HIGH_ELF,
		"name": "精灵族",
		"key": "high_elf",
		"color": Color(0.2, 0.7, 0.3),
		"leader": "女王·翠玲",
		"capital": "世界树圣地",
		"lore": "古老的精灵族，与自然共生。魔法屏障和远程打击是其核心战力，极度厌恶侵略。",
		
		# 起始资源
		"start_gold": 350,
		"start_food": 70,
		"start_iron": 40,
		"start_army": 12,
		"start_prestige": 5,
		
		# 经济特性
		"gold_income_mult": 1.0,
		"food_per_soldier": 0.8,
		"iron_per_recruit": 8,
		"gold_per_recruit": 55,
		"magic_barrier_pct": 0.3,   # 魔法屏障吸收率
		
		# 战斗特性
		"atk_bonus": 2,
		"def_bonus": 2,
		"combat_style": "ranged",
		"special_mechanic": "magic_barrier",
		
		# AI行为参数
		"ai_aggression": 0.25,
		"ai_expansion_priority": 0.3,
		"ai_economy_priority": 0.7,
		"ai_diplomacy_priority": 0.8,
		"ai_defense_threshold": 0.7,
		
		# 内政优先级
		"building_priority": ["academy", "fortification", "training_ground", "merchant_guild", "warehouse"],
		
		# 特殊单位
		"unique_units": ["elf_archer", "elf_mage", "elf_ashigaru"],
		"elite_unit": "ancient_treant",
		
		# 外交倾向
		"diplomacy_bias": {
			"human": "friendly",
			"orc": "hostile",
			"pirate": "neutral",
			"dark_elf": "hostile",
		},
		
		# 特殊事件
		"special_events": {
			"world_tree_blessing": {"turn_interval": 20, "desc": "世界树祝福"},
			"nature_wrath": {"threat_min": 60, "desc": "自然之怒"},
		},
	},
}

# ═══════════════════════════════════════════════════════════
# 势力关系矩阵 (战国兰斯风格：势力间互动)
# ═══════════════════════════════════════════════════════════
const FACTION_RELATIONS: Dictionary = {
	# 格式: [faction_a][faction_b] = 初始关系值 (-100到100)
	FactionType.ORC: {
		FactionType.PIRATE: 10,     # 轻微友好
		FactionType.DARK_ELF: 0,    # 中立
		FactionType.HUMAN: -60,     # 敌对
		FactionType.HIGH_ELF: -70,  # 强烈敌对
	},
	FactionType.PIRATE: {
		FactionType.ORC: 10,
		FactionType.DARK_ELF: 20,   # 友好
		FactionType.HUMAN: -50,
		FactionType.HIGH_ELF: -20,
	},
	FactionType.DARK_ELF: {
		FactionType.ORC: 0,
		FactionType.PIRATE: 20,
		FactionType.HUMAN: -70,
		FactionType.HIGH_ELF: -80,  # 强烈敌对
	},
	FactionType.HUMAN: {
		FactionType.ORC: -60,
		FactionType.PIRATE: -50,
		FactionType.DARK_ELF: -70,
		FactionType.HIGH_ELF: 50,   # 同盟
	},
	FactionType.HIGH_ELF: {
		FactionType.ORC: -70,
		FactionType.PIRATE: -20,
		FactionType.DARK_ELF: -80,
		FactionType.HUMAN: 50,
	},
}

# ═══════════════════════════════════════════════════════════
# 势力征服奖励 (战国兰斯风格)
# ═══════════════════════════════════════════════════════════
const CONQUEST_REWARDS: Dictionary = {
	FactionType.ORC: {
		"prestige": 30,
		"gold": 200,
		"iron": 50,
		"unlock_unit": "orc_elite",
		"special_event": "orc_subjugated",
	},
	FactionType.PIRATE: {
		"prestige": 40,
		"gold": 400,
		"iron": 30,
		"unlock_unit": "pirate_elite",
		"special_event": "pirate_fleet_captured",
	},
	FactionType.DARK_ELF: {
		"prestige": 50,
		"gold": 250,
		"iron": 40,
		"unlock_unit": "dark_elf_elite",
		"special_event": "dark_council_dissolved",
	},
	FactionType.HUMAN: {
		"prestige": 60,
		"gold": 500,
		"iron": 80,
		"unlock_unit": "royal_guard",
		"special_event": "kingdom_falls",
	},
	FactionType.HIGH_ELF: {
		"prestige": 55,
		"gold": 300,
		"iron": 60,
		"unlock_unit": "ancient_treant",
		"special_event": "world_tree_falls",
	},
}

# ═══════════════════════════════════════════════════════════
# 工具函数
# ═══════════════════════════════════════════════════════════
static func get_config(faction_type: int) -> Dictionary:
	return FACTION_CONFIGS.get(faction_type, {})

static func get_initial_relation(faction_a: int, faction_b: int) -> int:
	if FACTION_RELATIONS.has(faction_a):
		return FACTION_RELATIONS[faction_a].get(faction_b, 0)
	return 0

static func get_conquest_reward(faction_type: int) -> Dictionary:
	return CONQUEST_REWARDS.get(faction_type, {})

static func get_building_priority(faction_type: int) -> Array:
	var config: Dictionary = get_config(faction_type)
	return config.get("building_priority", ["training_ground", "merchant_guild"])

static func get_ai_param(faction_type: int, param: String, default_val: float = 0.5) -> float:
	var config: Dictionary = get_config(faction_type)
	return config.get(param, default_val)
