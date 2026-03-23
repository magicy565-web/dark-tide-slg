## faction_data.gd - Static data definitions for all factions (v2.0 — SR07+TW:W数值对齐)
## No .tres needed; everything is const dictionaries.
extends RefCounted
class_name FactionData

# ── Faction IDs ──
enum FactionID { ORC, PIRATE, DARK_ELF }

# ── Hero System Constants ──
const PRISON_CAPACITY: int = 3
const CORRUPTION_TO_RECRUIT: int = 5
const AFFECTION_MAX: int = 10
const MANA_BASE_MAX: int = 10

# ── Pirate Harem Victory (海盗后宫收集胜利) ──
const HAREM_VICTORY_SUBMISSION_MIN: int = 7    # 所有角色服从度≥7即可触发
const PIRATE_PRISON_CAPACITY: int = 6          # 海盗牢房容量翻倍
const PIRATE_CORRUPTION_SPEED: float = 1.5     # 海盗腐化速度×1.5
const PIRATE_CAPTURE_BONUS: float = 0.15       # 海盗捕获概率+15%
const SUBMISSION_PER_TRAINING: int = 1          # 每次调教+1服从度
const SUBMISSION_PER_GIFT: int = 2              # 每次赠礼+2服从度
const SUBMISSION_MAX: int = 10                  # 服从度上限

# ── Territory Distribution (v0.8.3) ──
# Evil factions combined = 20% of total map (55 nodes)
# Hierarchy: Orc > Pirate > Dark Elf
const ORC_TERRITORY: int = 5          # 碎骨王座 + 4 outposts (largest evil faction)
const PIRATE_TERRITORY: int = 4       # 深渊港 + 3 outposts (medium evil faction)
const DARK_ELF_TERRITORY: int = 2     # 永夜暗城 + 1 outpost (smallest, relies on intrigue)
const EVIL_TERRITORY_TOTAL: int = 11  # 5+4+2 = 11 ≈ 20% of 55

# Evil fortress indices in CORE_FORTRESS_DEFS (game_manager.gd)
const EVIL_FORTRESS_IDX: Dictionary = {
	"orc": 5,       # 碎骨王座
	"pirate": 6,    # 深渊港
	"dark_elf": 7,  # 永夜暗城
}

# ── Hero Roster (18 heroes from design doc 02_角色设定) ──
const HEROES: Dictionary = {
	# --- Light Faction Heroes (capturable) ---
	"rin": {"name": "凛", "faction": "human", "troop": "samurai", "atk": 7, "def": 8, "int": 5, "spd": 4,
		"capture_chance": 0.5, "active": "圣光斩", "passive": "守护决心"},
	"yukino": {"name": "雪乃", "faction": "human", "troop": "priest", "atk": 3, "def": 4, "int": 8, "spd": 5,
		"capture_chance": 0.0, "join_condition": "rin_captured", "active": "治愈之光", "passive": "祝福"},
	"momiji": {"name": "红叶", "faction": "human", "troop": "cavalry", "atk": 5, "def": 5, "int": 7, "spd": 6,
		"capture_chance": 0.0, "join_condition": "prestige_gte_30", "active": "突击号令", "passive": "指挥官"},
	"hyouka": {"name": "冰华", "faction": "human", "troop": "samurai", "atk": 6, "def": 9, "int": 4, "spd": 3,
		"capture_chance": 1.0, "join_condition": "temple_fortress_fall", "active": "不动如山", "passive": "圣殿之盾"},
	"suirei": {"name": "翠玲", "faction": "high_elf", "troop": "archer", "atk": 8, "def": 3, "int": 6, "spd": 7,
		"capture_chance": 0.3, "active": "箭雨", "passive": "精灵之眼"},
	"gekka": {"name": "月华", "faction": "high_elf", "troop": "priest", "atk": 4, "def": 5, "int": 9, "spd": 4,
		"capture_chance": 0.0, "join_condition": "suirei_affection_3", "active": "月光护盾", "passive": "法力涌泉"},
	"hakagure": {"name": "叶隐", "faction": "high_elf", "troop": "ninja", "atk": 6, "def": 4, "int": 5, "spd": 8,
		"capture_chance": 0.0, "join_condition": "assassin_quest_success", "active": "影步", "passive": "隐匿"},
	"sou": {"name": "蒼", "faction": "mage", "troop": "mage_unit", "atk": 9, "def": 6, "int": 9, "spd": 3,
		"capture_chance": 1.0, "join_condition": "mage_hq_fall", "active": "流星火雨", "passive": "大贤者"},
	"shion": {"name": "紫苑", "faction": "mage", "troop": "mage_unit", "atk": 5, "def": 4, "int": 9, "spd": 7,
		"capture_chance": 0.0, "join_condition": "sou_captured", "active": "时间减速", "passive": "时空感知"},
	"homura": {"name": "焔", "faction": "mage", "troop": "mage_unit", "atk": 8, "def": 3, "int": 7, "spd": 8,
		"capture_chance": 0.4, "active": "爆裂火球", "passive": "火焰亲和"},
	# --- Pirate / Dark Elf Heroes ---
	"shion_pirate": {"name": "潮音", "faction": "pirate", "troop": "archer", "atk": 7, "def": 4, "int": 5, "spd": 7,
		"capture_chance": 0.0, "join_condition": "turn_gte_15", "active": "连射", "passive": "海风", "pirate_native": true},
	"youya": {"name": "妖夜", "faction": "dark_elf", "troop": "ninja", "atk": 6, "def": 3, "int": 4, "spd": 9,
		"capture_chance": 0.0, "join_condition": "turn_gte_10", "active": "致命一击", "passive": "夜行者"},
	# --- Neutral Leaders (6, guard neutral bases) ---
	"hibiki": {"name": "響", "faction": "neutral", "troop": "ashigaru", "atk": 5, "def": 7, "int": 4, "spd": 5,
		"capture_chance": 1.0, "location": "山岳要塞", "active": "铁壁", "passive": ""},
	"sara": {"name": "沙罗", "faction": "neutral", "troop": "archer", "atk": 7, "def": 3, "int": 6, "spd": 6,
		"capture_chance": 1.0, "location": "沙漠绿洲", "active": "沙暴", "passive": ""},
	"mei": {"name": "冥", "faction": "neutral", "troop": "mage_unit", "atk": 8, "def": 2, "int": 8, "spd": 4,
		"capture_chance": 1.0, "location": "废墟神殿", "active": "亡灵召唤", "passive": ""},
	"kaede": {"name": "枫", "faction": "neutral", "troop": "ninja", "atk": 6, "def": 4, "int": 5, "spd": 9,
		"capture_chance": 1.0, "location": "隐秘森林", "active": "分身", "passive": ""},
	"akane": {"name": "朱音", "faction": "neutral", "troop": "priest", "atk": 3, "def": 5, "int": 7, "spd": 5,
		"capture_chance": 1.0, "location": "古代圣地", "active": "净化", "passive": ""},
	"hanabi": {"name": "花火", "faction": "neutral", "troop": "cannon", "atk": 9, "def": 2, "int": 5, "spd": 3,
		"capture_chance": 1.0, "location": "废弃矿山", "active": "集中轰炸", "passive": ""},
}

const FACTION_NAMES: Dictionary = {
	FactionID.ORC: "兽人部落",
	FactionID.PIRATE: "暗黑海盗",
	FactionID.DARK_ELF: "黑暗精灵议会",
}

const FACTION_COLORS: Dictionary = {
	FactionID.ORC: Color(0.6, 0.2, 0.1),
	FactionID.PIRATE: Color(0.15, 0.15, 0.4),
	FactionID.DARK_ELF: Color(0.35, 0.1, 0.45),
}

# ── Strategic Resources ──
const STRATEGIC_RESOURCES: Array = ["magic_crystal", "war_horse", "gunpowder", "shadow_essence"]

# ── Starting resources per faction (TW:W aligned: 500g/150f/80i base) ──
const STARTING_RESOURCES: Dictionary = {
	FactionID.ORC: {
		"gold": 500, "food": 150, "iron": 80, "slaves": 2, "prestige": 0, "army": 5,
		"magic_crystal": 0, "war_horse": 0, "gunpowder": 0, "shadow_essence": 0,
	},
	FactionID.PIRATE: {
		"gold": 600, "food": 100, "iron": 40, "slaves": 2, "prestige": 0, "army": 3,
		"magic_crystal": 0, "war_horse": 0, "gunpowder": 0, "shadow_essence": 0,
	},
	FactionID.DARK_ELF: {
		"gold": 500, "food": 150, "iron": 80, "slaves": 5, "prestige": 0, "army": 3,
		"magic_crystal": 0, "war_horse": 0, "gunpowder": 0, "shadow_essence": 0,
	},
}

# ── Faction-specific balance constants ──
const FACTION_PARAMS: Dictionary = {
	FactionID.ORC: {
		"food_per_soldier": 0.5,
		"recruit_cost_gold": 60,
		"recruit_cost_iron": 8,
		"slave_capture_bonus": 1.5,      # +50% slave capture
		"base_production_mult": 1.0,
		"gold_income_mult": 0.8,          # v0.7: gold x0.8
		"iron_income_mult": 0.8,          # v0.7: iron x0.8
		"food_production_mult": 1.0,
		# WAAAGH! graduated thresholds (per orc_mechanic.gd §3.1)
		"waaagh_tier_1_threshold": 30,
		"waaagh_tier_2_threshold": 60,
		"waaagh_tier_3_threshold": 90,
		"waaagh_tier_1_atk": 1,
		"waaagh_tier_2_atk": 2,
		"waaagh_tier_3_atk": 4,
		"waaagh_per_unit_in_combat": 5,
		"waaagh_per_kill": 10,
		"waaagh_idle_decay": 10,
		"waaagh_frenzy_turns": 3,
		"waaagh_frenzy_damage_mult": 1.5,
		"waaagh_frenzy_army_loss_pct": 0.15,
		"waaagh_zero_infighting_loss_pct": 0.10,
		"waaagh_infighting_threshold": 20,
		"waaagh_infighting_chance": 0.10,
		# 兽人繁衍机制 (orc_mechanic.gd v2.0)
		"breed_base_per_territory": 2,      # 每块领地每回合基础人口增长
		"breed_food_consumption": 0.3,      # 每族人每回合消耗粮食
		"breed_auto_spawn_threshold": 20,   # 人口池≥此值可自动征召
		"breed_desperate_territory": 3,     # 领地<此值触发绝望繁衍(双倍增长)
		"breed_desperate_tribe_size": 10,   # 族群<此值触发绝望繁衍
		# 兽人外交限制 (纯征服路线)
		"diplomacy_type": "conquest_only",     # 仅征服
		"ceasefire_cost_gold": 100,            # 停战贡品费用
		"ceasefire_duration": 5,               # 停战持续回合
		"war_slave_penalty_base": 0.5,         # 与兽人开战时敌方奴隶产出-50%
		"threat_increase_per_war": 5,          # 每场战争额外增加威胁值
	},
	FactionID.PIRATE: {
		"food_per_soldier": 1.0,
		"recruit_cost_gold": 60,
		"recruit_cost_iron": 5,
		"slave_capture_bonus": 1.0,
		"base_production_mult": 0.6,       # v2.0: 基础产出大幅降低 (掠夺为主)
		"gold_income_mult": 1.5,           # v2.0: 掠夺金币系数提升至1.5x
		"iron_income_mult": 0.5,           # v2.0: 铁矿产出极低 (需要掠夺)
		"food_production_mult": 0.7,       # v2.0: 粮食产出降低 (靠掠夺补充)
		# 黑市
		"slave_sell_price": 25,
		"slave_buy_price": 40,
		# 掠夺
		"plunder_base_per_tile": 3,        # v2.0: 每据点掠夺值+3 (原2)
		"plunder_combat_mult": 1.8,        # v2.0: 战斗掠夺金币系数×1.8
		"stronghold_capture_plunder_mult": 12,  # v2.0: 要塞掠夺×12 (原10)
		# 性奴隶系统
		"sex_slave_base_capacity": 3,
		"sex_slave_per_territory": 2,
		"sex_slave_per_black_market": 3,
		"slave_training_per_turn": 10,
		"slave_training_max": 100,
		"slave_ransom_base": 50,
		"slave_ransom_relation_mult": 2.0,
		# 恶名系统
		"infamy_per_plunder": 5,
		"infamy_per_ransom": -3,
		"infamy_decay_per_turn": 2,
		"infamy_high_threshold": 70,
		"infamy_low_threshold": 30,
		# 朗姆酒士气
		"rum_morale_per_barrel": 15,
		"rum_decay_per_turn": 5,
		"rum_atk_threshold": 50,
		"rum_high_atk": 2,
		"rum_drunk_threshold": 90,
		"rum_drunk_atk": 4,
		"rum_drunk_def_penalty": -2,
		# 走私航线
		"smuggle_income_per_route": 8,
		"max_smuggle_routes": 3,
		# 雇佣兵
		"mercenary_cost_mult": 2.0,
		"mercenary_stat_penalty": 0.8,     # 雇佣兵属性仅为本系80%
		# AI海盗
		"ai_raid_spawn_chance": 0.25,
		"ai_raid_min_strength": 4,
		"ai_raid_max_strength": 10,
		"ai_raid_duration": 3,
		"ai_raid_loot_on_defeat": 40,
		"ai_max_raid_parties": 4,
	},
	FactionID.DARK_ELF: {
		"food_per_soldier": 1.0,
		"recruit_cost_gold": 60,
		"recruit_cost_iron": 5,
		"slave_capture_bonus": 2.0,       # v0.7: +100% slave capture
		"base_production_mult": 0.7,
		"gold_income_mult": 0.9,
		"iron_income_mult": 1.0,          # v0.7: iron x1.0
		"food_production_mult": 1.0,
		"combat_slave_bonus": 1,
		# Slave allocation yields
		"slave_mine_iron_per_turn": 1,
		"slave_farm_food_per_turn": 2,
		"slave_altar_atk_per_slave": 1,
		"slave_altar_sacrifice_interval": 3,
	},
}

# ── Shared Unit Definitions (v2.0: SR07 ratio-aligned, base scale Ashigaru ATK=8) ──
# Recruit cost = soldiers × 2金 × cost_mult (per 04_经济设定.md §七)
# Row and targeting per 11_兵种数据包.md §一
const RECRUIT_COST_MULT: Dictionary = {
	"ashigaru": 1.0, "samurai": 2.0, "archer": 1.5, "cavalry": 2.5,
	"ninja": 2.5, "priest": 3.0, "mage_unit": 3.0, "cannon": 5.0,
}
const SHARED_UNIT_DEFS: Dictionary = {
	"ashigaru": {"name": "足軽", "atk": 8, "def": 6, "soldiers": 12, "spd": 5, "row": "front", "food_per_soldier": 0.5, "cost_mult": 1.0, "special": "none", "tier": 1, "class": "infantry"},
	"samurai": {"name": "武士", "atk": 11, "def": 9, "soldiers": 8, "spd": 5, "row": "front", "food_per_soldier": 0.5, "cost_mult": 2.0, "special": "counter_1_2", "tier": 2, "class": "infantry"},
	"archer": {"name": "弓兵", "atk": 7, "def": 4, "soldiers": 10, "spd": 4, "row": "back", "food_per_soldier": 0.5, "cost_mult": 1.5, "special": "preemptive", "tier": 1, "class": "ranged"},
	"cannon": {"name": "砲兵", "atk": 20, "def": 1, "soldiers": 6, "spd": 2, "row": "back", "food_per_soldier": 0.5, "cost_mult": 5.0, "special": "siege_x2", "tier": 2, "class": "ranged"},
	"cavalry": {"name": "騎兵", "atk": 14, "def": 8, "soldiers": 7, "spd": 8, "row": "front", "food_per_soldier": 0.5, "cost_mult": 2.5, "special": "charge_1_5", "tier": 2, "class": "cavalry"},
	"ninja": {"name": "忍者", "atk": 7, "def": 4, "soldiers": 5, "spd": 9, "row": "back", "food_per_soldier": 0.5, "cost_mult": 2.5, "special": "assassinate_back", "tier": 1, "class": "infantry"},
	"priest": {"name": "祭司", "atk": 5, "def": 3, "soldiers": 5, "spd": 4, "row": "back", "food_per_soldier": 0.5, "cost_mult": 3.0, "special": "charge_mana_1", "tier": 1, "class": "special"},
	"mage_unit": {"name": "術師", "atk": 6, "def": 3, "soldiers": 6, "spd": 4, "row": "back", "food_per_soldier": 0.5, "cost_mult": 3.0, "special": "aoe_mana", "tier": 2, "class": "ranged"},
	"shadow_walker": {"name": "暗影行者", "atk": 12, "def": 7, "soldiers": 5, "spd": 9, "row": "back", "food_per_soldier": 0.5, "cost_mult": 4.0, "special": "assassinate_back", "tier": 3, "class": "infantry", "requires_unlock": true},
}

# ── Unit Definitions (evil factions) — SR07 ratio-aligned ──
const UNIT_DEFS: Dictionary = {
	FactionID.ORC: {
		"orc_ashigaru": {"name": "兽人足軽", "atk": 9, "def": 4, "soldiers": 12, "spd": 5, "row": "front", "food_per_soldier": 0.5, "recruit_gold": 24, "special": "none", "tier": 1, "class": "infantry"},
		"orc_samurai": {"name": "巨魔", "atk": 13, "def": 8, "soldiers": 8, "spd": 4, "row": "front", "food_per_soldier": 0.5, "recruit_gold": 48, "special": "regen_1", "tier": 2, "class": "infantry"},
		"orc_cavalry": {"name": "战猪骑兵", "atk": 15, "def": 5, "soldiers": 6, "spd": 7, "row": "front", "food_per_soldier": 0.5, "recruit_gold": 60, "special": "charge_1_5", "tier": 2, "class": "cavalry"},
	},
	FactionID.PIRATE: {
		"pirate_ashigaru": {"name": "海盗散兵", "atk": 7, "def": 5, "soldiers": 10, "spd": 5, "row": "front", "food_per_soldier": 0.5, "recruit_gold": 20, "special": "escape_30", "tier": 1, "class": "infantry"},
		"pirate_archer": {"name": "火枪手", "atk": 18, "def": 1, "soldiers": 5, "spd": 6, "row": "back", "food_per_soldier": 0.5, "recruit_gold": 60, "special": "preemptive", "tier": 1, "class": "ranged"},
		"pirate_cannon": {"name": "炮击手", "atk": 22, "def": 1, "soldiers": 5, "spd": 2, "row": "back", "food_per_soldier": 0.5, "recruit_gold": 80, "special": "siege_x2", "tier": 2, "class": "ranged"},
	},
	FactionID.DARK_ELF: {
		"de_samurai": {"name": "暗精灵战士", "atk": 11, "def": 7, "soldiers": 7, "spd": 6, "row": "front", "food_per_soldier": 0.5, "recruit_gold": 36, "special": "extra_action", "tier": 1, "class": "infantry"},
		"de_ninja": {"name": "暗影刺客", "atk": 7, "def": 3, "soldiers": 5, "spd": 9, "row": "back", "food_per_soldier": 0.5, "recruit_gold": 40, "special": "assassinate_back", "tier": 1, "class": "infantry"},
		"de_cavalry": {"name": "冷蜥骑兵", "atk": 14, "def": 7, "soldiers": 6, "spd": 8, "row": "front", "food_per_soldier": 0.5, "recruit_gold": 55, "special": "ignore_terrain", "tier": 2, "class": "cavalry"},
	},
}

# ── Ultimate Units (require shadow_essence) — SR07 ratio-aligned §六 ──
const ULTIMATE_UNITS: Dictionary = {
	FactionID.ORC: {
		"name": "狂暴巨兽", "atk": 22, "def": 12, "soldiers": 15, "spd": 3, "row": "front",
		"recruit_gold": 200, "shadow_essence_cost": 8,
		"special": "waaagh_triple", "class": "infantry",
	},
	FactionID.PIRATE: {
		"name": "深海利维坦", "atk": 20, "def": 14, "soldiers": 12, "spd": 2, "row": "back",
		"recruit_gold": 180, "shadow_essence_cost": 8,
		"special": "siege_ignore", "class": "ranged",
	},
	FactionID.DARK_ELF: {
		"name": "暗影龙骑", "atk": 24, "def": 10, "soldiers": 10, "spd": 9, "row": "front",
		"recruit_gold": 220, "shadow_essence_cost": 8,
		"special": "shadow_flight", "class": "cavalry",
	},
}

# ── Building Level Data (3 levels each, TW:W economy scaled) ──
const BUILDING_LEVELS: Dictionary = {
	# Common buildings
	"slave_market": {
		1: {"name": "奴隶市场 Lv1", "cost_gold": 300, "cost_iron": 24, "slaves_per_turn": 2, "desc": "+2奴隶/回合"},
		2: {"name": "奴隶市场 Lv2", "cost_gold": 500, "cost_iron": 40, "slaves_per_turn": 3, "desc": "+3奴隶/回合，开放交易"},
		3: {"name": "奴隶市场 Lv3", "cost_gold": 800, "cost_iron": 60, "slaves_per_turn": 5, "desc": "+5奴隶/回合"},
	},
	"labor_camp": {
		1: {"name": "苦役营 Lv1", "cost_gold": 450, "cost_iron": 45, "food_bonus": 1.0, "iron_bonus": 0.5, "desc": "奴隶劳动+1粮+0.5铁"},
		2: {"name": "苦役营 Lv2", "cost_gold": 700, "cost_iron": 65, "food_bonus": 1.5, "iron_bonus": 0.75, "desc": "+50%产出"},
		3: {"name": "苦役营 Lv3", "cost_gold": 1000, "cost_iron": 85, "food_bonus": 2.0, "iron_bonus": 1.0, "desc": "双倍产出+物品"},
	},
	"arena": {
		1: {"name": "竞技场 Lv1", "cost_gold": 400, "cost_iron": 36, "slave_consume": 1, "atk_bonus": 3, "def_bonus": 0, "desc": "消耗1奴隶/回合 +3攻"},
		2: {"name": "竞技场 Lv2", "cost_gold": 650, "cost_iron": 55, "slave_consume": 1, "atk_bonus": 5, "def_bonus": 2, "desc": "+5攻 +2防"},
		3: {"name": "竞技场 Lv3", "cost_gold": 1000, "cost_iron": 80, "slave_consume": 1, "atk_bonus": 8, "def_bonus": 8, "desc": "+8攻+防"},
	},
	"training_ground": {
		1: {"name": "训练场 Lv1", "cost_gold": 350, "cost_iron": 45, "recruit_discount": 10, "atk_bonus": 3, "def_bonus": 0, "desc": "招募-10金 +3攻"},
		2: {"name": "训练场 Lv2", "cost_gold": 600, "cost_iron": 65, "recruit_discount": 20, "atk_bonus": 5, "def_bonus": 5, "desc": "-20金 +5攻/防"},
		3: {"name": "训练场 Lv3", "cost_gold": 900, "cost_iron": 90, "recruit_discount": 30, "atk_bonus": 8, "def_bonus": 8, "desc": "-30金 +8攻/防"},
	},
	# Faction buildings
	"totem_pole": {
		1: {"name": "图腾柱 Lv1", "cost_gold": 300, "cost_iron": 30, "waaagh_per_turn": 5, "desc": "+5 WAAAGH!/回合"},
		2: {"name": "图腾柱 Lv2", "cost_gold": 500, "cost_iron": 50, "waaagh_per_turn": 8, "extra_turn": 1, "desc": "+8 WAAAGH! 狂暴+1回合"},
		3: {"name": "图腾柱 Lv3", "cost_gold": 800, "cost_iron": 75, "waaagh_per_turn": 12, "loss_reduction": 0.10, "desc": "+12 WAAAGH! 损失→10%"},
	},
	"brood_pit": {
		1: {"name": "繁衍坑 Lv1", "cost_gold": 250, "cost_iron": 20, "growth_bonus": 3, "desc": "+3人口/回合, 兽人独有繁衍设施"},
		2: {"name": "繁衍坑 Lv2", "cost_gold": 450, "cost_iron": 40, "growth_bonus": 5, "food_efficiency": 0.15, "desc": "+5人口/回合, 粮食消耗-15%"},
		3: {"name": "繁衍坑 Lv3", "cost_gold": 750, "cost_iron": 65, "growth_bonus": 8, "food_efficiency": 0.25, "auto_spawn_threshold": -5, "desc": "+8人口/回合, 自动征召阈值降低5"},
	},
	"black_market": {
		1: {"name": "黑市 Lv1", "cost_gold": 300, "cost_iron": 20, "trade_bonus": true, "items_per_turn": 1, "desc": "交易+1物品/回合"},
		2: {"name": "黑市 Lv2", "cost_gold": 500, "cost_iron": 35, "trade_bonus": true, "items_per_turn": 2, "desc": "更好价格+2物品"},
		3: {"name": "黑市 Lv3", "cost_gold": 800, "cost_iron": 55, "trade_bonus": true, "items_per_turn": 3, "desc": "最佳价格+遗物"},
	},
	"rum_distillery": {
		1: {"name": "朗姆酒坊 Lv1", "cost_gold": 80, "cost_iron": 4, "rum_per_turn": 1, "desc": "+1朗姆酒/回合"},
		2: {"name": "朗姆酒坊 Lv2", "cost_gold": 150, "cost_iron": 8, "rum_per_turn": 2, "desc": "+2朗姆酒/回合, 解锁烈酒"},
		3: {"name": "朗姆酒坊 Lv3", "cost_gold": 250, "cost_iron": 14, "rum_per_turn": 3, "desc": "+3朗姆酒/回合, 士气衰减减半"},
	},
	"slave_training_pen": {
		1: {"name": "调教所 Lv1", "cost_gold": 120, "cost_iron": 10, "training_mult": 2.0, "desc": "调教速度×2"},
		2: {"name": "调教所 Lv2", "cost_gold": 220, "cost_iron": 18, "training_mult": 3.0, "desc": "调教速度×3, 解锁特殊调教"},
	},
	"temple_of_agony": {
		1: {"name": "痛苦神殿 Lv1", "cost_gold": 350, "cost_iron": 40, "altar_mult": 1.0, "desc": "开启祭坛"},
		2: {"name": "痛苦神殿 Lv2", "cost_gold": 600, "cost_iron": 60, "altar_mult": 1.5, "desc": "+50%祭坛效果"},
		3: {"name": "痛苦神殿 Lv3", "cost_gold": 900, "cost_iron": 80, "altar_mult": 2.0, "desc": "双倍祭坛+痛苦仪式"},
	},
}

# ── Light Alliance factions (NPC enemies on the map) ──
enum LightFaction { HUMAN_KINGDOM, HIGH_ELVES, MAGE_TOWER }

const LIGHT_FACTION_NAMES: Dictionary = {
	LightFaction.HUMAN_KINGDOM: "人类王国",
	LightFaction.HIGH_ELVES: "精灵族",
	LightFaction.MAGE_TOWER: "法师塔",
}

const LIGHT_TILE_COUNTS: Dictionary = {
	LightFaction.HUMAN_KINGDOM: [8, 10],
	LightFaction.HIGH_ELVES: [4, 6],
	LightFaction.MAGE_TOWER: [4, 6],
}

# ── Light Faction Mechanics ──
const LIGHT_FACTION_DATA: Dictionary = {
	LightFaction.HUMAN_KINGDOM: {
		"name": "人类王国",
		"mechanic": "city_defense",
		"wall_hp_base": 100,
		"wall_regen_per_turn": 5,
		"desc": "城防系统: 城墙HP必须先消耗完才能进入战斗，每回合回复+5",
	},
	LightFaction.HIGH_ELVES: {
		"name": "精灵族",
		"mechanic": "magic_barrier",
		"barrier_absorb_pct": 0.30,
		"ley_line_bonus_per_adj": 5,
		"desc": "魔法屏障: 首次攻击吸收30%伤害，相邻精灵领地提供灵脉加成",
	},
	LightFaction.MAGE_TOWER: {
		"name": "法师塔",
		"mechanic": "mana_pool",
		"mana_pool_base": 100,
		"mana_regen_per_turn": 8,
		"spells": {
			"teleport": {"cost": 15, "desc": "传送部队"},
			"barrier": {"cost": 10, "desc": "护盾"},
			"barrage": {"cost": 20, "desc": "魔法弹幕"},
		},
		"desc": "共享法力池: 传送15法力, 屏障10法力, 弹幕20法力",
	},
}

# ── Light Unit Definitions — SR07 ratio-aligned §三 ──
const LIGHT_UNIT_DEFS: Dictionary = {
	LightFaction.HUMAN_KINGDOM: {
		"human_ashigaru": {"name": "民兵", "atk": 6, "def": 9, "soldiers": 15, "spd": 4, "row": "front", "special": "fort_def_3", "class": "infantry"},
		"human_cavalry": {"name": "骑士", "atk": 14, "def": 8, "soldiers": 7, "spd": 7, "row": "front", "special": "counter_1_2", "class": "cavalry"},
		"human_samurai": {"name": "圣殿女卫", "atk": 10, "def": 12, "soldiers": 10, "spd": 3, "row": "front", "special": "immobile", "class": "infantry"},
	},
	LightFaction.HIGH_ELVES: {
		"elf_archer": {"name": "精灵游侠", "atk": 9, "def": 4, "soldiers": 8, "spd": 6, "row": "back", "special": "preemptive_1_3", "class": "ranged"},
		"elf_mage": {"name": "法师", "atk": 6, "def": 2, "soldiers": 5, "spd": 5, "row": "back", "special": "aoe_mana", "class": "ranged"},
		"elf_ashigaru": {"name": "树人", "atk": 6, "def": 14, "soldiers": 18, "spd": 1, "row": "front", "special": "taunt", "class": "infantry"},
	},
	LightFaction.MAGE_TOWER: {
		"mage_apprentice": {"name": "学徒法师", "atk": 5, "def": 3, "soldiers": 5, "spd": 5, "row": "back", "special": "charge_mana_1", "class": "ranged"},
		"mage_battle": {"name": "战斗法师", "atk": 12, "def": 4, "soldiers": 6, "spd": 4, "row": "back", "special": "aoe_1_5_cost5", "class": "ranged"},
		"mage_grand": {"name": "大法师", "atk": 15, "def": 8, "soldiers": 8, "spd": 3, "row": "back", "special": "death_burst", "class": "ranged"},
	},
}

# ── Alliance Unit Definitions — SR07 ratio-aligned §五 ──
const ALLIANCE_UNIT_DEFS: Dictionary = {
	"alliance_vanguard": {"name": "联军先锋", "atk": 14, "def": 8, "soldiers": 8, "spd": 7, "row": "front", "special": "first_strike_counter", "class": "cavalry", "desc": "先手射击+反击加成"},
	"arcane_artillery": {"name": "奥术炮台", "atk": 18, "def": 3, "soldiers": 7, "spd": 4, "row": "back", "special": "pre_combat_aoe", "class": "ranged", "desc": "AoE×1.5+法力爆发"},
}

# ── Strategic Resource Costs ──
const STRATEGIC_RESOURCE_COSTS: Dictionary = {
	"magic_crystal": {
		"unit_upgrade_lv3": {"cost": 3, "desc": "兵种升级Lv2→Lv3额外需要"},
		"mana_jammer": {"cost": 5, "desc": "制造法力干扰器(魔法师屏障/法术效果减半)"},
		"arcane_enhance": {"cost": 10, "desc": "全军攻击永久+5"},
	},
	"war_horse": {
		"cavalry_recruit": {"cost": 2, "desc": "招募骑兵类兵种额外需要"},
		"forced_march": {"cost": 3, "desc": "本回合骰子+3"},
		"iron_charge": {"cost": 8, "desc": "骑兵首轮攻击×2"},
	},
	"gunpowder": {
		"siege_boost": {"cost": 2, "desc": "攻城时城防削减×2"},
		"blast_barrel": {"cost": 3, "desc": "制造爆破桶(-15城防)"},
		"gun_enhance": {"cost": 5, "desc": "炮击手/火枪手攻击永久+5"},
		"gunpowder_assault": {"cost": 10, "desc": "攻打据点无视城防"},
	},
	"shadow_essence": {
		"altar_boost": {"cost": 3, "desc": "暗精灵祭坛效果×2"},
		"relic_upgrade": {"cost": 5, "desc": "永久遗物效果翻倍"},
		"ultimate_unlock": {"cost": 8, "desc": "解锁终极兵种招募"},
		"shadow_dominion": {"cost": 15, "desc": "所有奴隶NPC服从度+30"},
	},
}

# ── Neutral Factions ──
enum NeutralFaction { IRONHAMMER_DWARF, WANDERING_CARAVAN, NECROMANCER, FOREST_RANGER, BLOOD_MOON_CULT, GOBLIN_ENGINEER }

const NEUTRAL_FACTION_NAMES: Dictionary = {
	NeutralFaction.IRONHAMMER_DWARF: "铁锤矮人",
	NeutralFaction.WANDERING_CARAVAN: "流浪商队",
	NeutralFaction.NECROMANCER: "亡灵巫师",
	NeutralFaction.FOREST_RANGER: "森林游侠",
	NeutralFaction.BLOOD_MOON_CULT: "血月教团",
	NeutralFaction.GOBLIN_ENGINEER: "地精工匠",
}

const NEUTRAL_FACTION_DATA: Dictionary = {
	# ── 铁锤矮人·響 (doc 06 §1) ──
	NeutralFaction.IRONHAMMER_DWARF: {
		"name": "铁锤矮人",
		"leader_name": "響",
		"stronghold_name": "铁锤熔炉",
		"quest_chain": [
			{"step": 1, "trigger": "discover", "task": "初遇: 提供15铁矿换精铁武器",
			 "cost": {"iron": 15}, "reward": {"item": "refined_iron_weapon"}},
			{"step": 2, "trigger": {"strongholds_min": 2, "combat": 6}, "task": "护送矿石 (敌6兵)",
			 "reward": {"prestige": 5}},
			{"step": 3, "trigger": {"gold_cost": 50, "iron_cost": 10}, "task": "花费50金+10铁收编",
			 "reward": {"prestige": 10}},
		],
		"recruitment_reward": {
			"unique_unit": {"name": "矮人铁卫", "atk": 8, "def": 14, "hp": 10, "special": "armor_halve_damage"},
			"iron_per_turn_bonus": 0.2,
			"iron_flat_per_turn": 3,
			"bonus": "铁矿产出+20%全局, 据点+3铁/回合",
			"abilities": ["矮人锻造"],
		},
	},
	# ── 流浪商队·沙罗 (doc 06 §2) ──
	NeutralFaction.WANDERING_CARAVAN: {
		"name": "流浪商队",
		"leader_name": "沙罗",
		"stronghold_name": "行商驿站",
		"quest_chain": [
			{"step": 1, "trigger": {"gold_cost": 40}, "task": "花40金揭示3个迷雾格",
			 "reward": {"reveal": 3}},
			{"step": 2, "trigger": {"tiles_min": 5, "combat": 5}, "task": "清剿匪巢 (敌5兵)",
			 "reward": {"prestige": 5}},
			{"step": 3, "trigger": {"prestige_min": 20}, "task": "威望>=20后结盟",
			 "reward": {"prestige": 10}},
		],
		"recruitment_reward": {
			"unique_unit": {"name": "商队护卫", "atk": 7, "def": 7, "hp": 6, "special": "trade_discount_20"},
			"gold_per_turn": 20,
			"free_item_interval": 3,
			"bonus": "每回合揭示1迷雾+交易费减半, 每3回合免费道具",
			"abilities": ["商队网络", "折扣交易"],
		},
	},
	# ── 亡灵巫师·冥 (doc 06 §3) ──
	NeutralFaction.NECROMANCER: {
		"name": "亡灵巫师",
		"leader_name": "冥",
		"stronghold_name": "枯骨墓穴",
		"quest_chain": [
			{"step": 1, "trigger": {"slaves_cost": 3}, "task": "提供3奴隶作实验材料",
			 "reward": {"shadow_essence": 2}},
			{"step": 2, "trigger": "auto", "task": "获得骷髅小队(+3临时兵5回合), 巫师提出合作",
			 "reward": {"temp_soldiers": 3, "temp_duration": 5}},
			{"step": 3, "trigger": {"magic_crystal_cost": 2}, "task": "带回2魔晶",
			 "reward": {"prestige": 10}},
		],
		"recruitment_reward": {
			"unique_unit": {"name": "骷髅军团", "atk": 6, "def": 4, "hp": 5, "special": "undead_no_food_decay_replenish"},
			"bonus": "骷髅军团(0粮耗, 每回合-1兵, 胜利+2兵) + 亡灵瘟疫瓶制造",
			"abilities": ["亡灵召唤", "瘟疫瓶制造"],
		},
	},
	# ── 森林游侠·枫 (doc 06 §4) ──
	NeutralFaction.FOREST_RANGER: {
		"name": "森林游侠",
		"leader_name": "枫",
		"stronghold_name": "绿影营地",
		"quest_chain": [
			{"step": 1, "trigger": {"combat": 4}, "task": "证明实力: 击败4精灵游侠",
			 "reward": {"prestige": 3}},
			{"step": 2, "trigger": {"slaves_cost": 2}, "task": "释放2奴隶表示善意",
			 "reward": {"prestige": 5}},
			{"step": 3, "trigger": {"order_min": 40}, "task": "秩序值>=40后结盟",
			 "reward": {"prestige": 10}},
		],
		"recruitment_reward": {
			"unique_unit": {"name": "绿影射手", "atk": 10, "def": 5, "hp": 5, "special": "first_strike_ignore_terrain"},
			"vision_bonus": 2,
			"bonus": "视野+2格 + 伏击战术(防守ATK+30%)",
			"abilities": ["绿影伏击", "森林穿行"],
		},
	},
	# ── 血月教团·朱音 (doc 06 §5) ──
	NeutralFaction.BLOOD_MOON_CULT: {
		"name": "血月教团",
		"leader_name": "朱音",
		"stronghold_name": "血月祭坛",
		"quest_chain": [
			{"step": 1, "trigger": {"combat": 8}, "task": "3回合内赢2场战斗(击败8守军)",
			 "reward": {"prestige": 5, "shadow_essence": 3}},
			{"step": 2, "trigger": {"slaves_cost": 3}, "task": "献祭3奴隶",
			 "reward": {"prestige": 7}},
			{"step": 3, "trigger": "auto", "task": "自动收编(秩序-5)",
			 "reward": {"order_change": -5, "prestige": 10}},
		],
		"recruitment_reward": {
			"unique_unit": {"name": "血月狂战士", "atk": 14, "def": 1, "hp": 6, "special": "blood_frenzy_below_50"},
			"bonus": "全军攻击+3(永久) + 血月祝福(2奴隶→全军ATK+10% 3回合) + 胜利+1威望",
			"atk_bonus_permanent": 3,
			"victory_prestige": 1,
			"abilities": ["血月祝福", "血月狂化"],
		},
	},
	# ── 地精工匠·花火 (doc 06 §6) ──
	NeutralFaction.GOBLIN_ENGINEER: {
		"name": "地精工匠",
		"leader_name": "花火",
		"stronghold_name": "地精工坊",
		"quest_chain": [
			{"step": 1, "trigger": "discover", "task": "免费获得1个爆破桶",
			 "reward": {"item": "bomb_barrel"}},
			{"step": 2, "trigger": {"gunpowder_cost": 3, "gold_cost": 30}, "task": "提供3火药+30金",
			 "reward": {"prestige": 4}},
			{"step": 3, "trigger": {"gunpowder_cost": 5, "iron_cost": 5}, "task": "提供5火药+5铁矿",
			 "reward": {"prestige": 10}},
		],
		"recruitment_reward": {
			"unique_unit": {"name": "地精炮兵", "atk": 16, "def": 0, "hp": 4, "special": "siege_triple_self_destruct_20"},
			"gunpowder_per_turn": 1,
			"bonus": "城防×3伤害 + 20%自爆-1兵 + 据点+1火药/回合 + 地精炸弹制造",
			"abilities": ["地精炸弹制造", "攻城专家"],
		},
	},
}

# ── Faction Recruitment Costs (diplomatic) ──
const FACTION_RECRUITMENT_COSTS: Dictionary = {
	NeutralFaction.IRONHAMMER_DWARF: {"prestige": 15, "gold": 100, "order_req": 30},
	NeutralFaction.WANDERING_CARAVAN: {"prestige": 10, "gold": 80, "order_req": 35},
	NeutralFaction.NECROMANCER: {"prestige": 20, "gold": 150, "order_req": 25},
	NeutralFaction.FOREST_RANGER: {"prestige": 15, "gold": 120, "order_req": 30},
	NeutralFaction.BLOOD_MOON_CULT: {"prestige": 25, "gold": 200, "order_req": 20},
	NeutralFaction.GOBLIN_ENGINEER: {"prestige": 12, "gold": 90, "order_req": 30},
}

# ── Resource Station Types ──
const RESOURCE_STATION_TYPES: Array = [
	{"type": "magic_crystal", "name": "魔晶矿", "output_key": "magic_crystal", "base_output": 2},
	{"type": "war_horse", "name": "战马牧场", "output_key": "war_horse", "base_output": 1},
	{"type": "gunpowder", "name": "火药工坊", "output_key": "gunpowder", "base_output": 1},
	{"type": "shadow_essence", "name": "暗影裂隙", "output_key": "shadow_essence", "base_output": 1},
]

# ── Unique buildings per faction ──
# key = building_id string, value = cost + effect data
const UNIQUE_BUILDINGS: Dictionary = {
	FactionID.ORC: {
		"totem_pole": {
			"name": "图腾柱",
			"cost_gold": 80, "cost_iron": 10, "cost_slaves": 0,
			"desc": "+5 WAAAGH!/回合",
			"effect": "waaagh_per_turn",
			"effect_value": 5,
			"max_level": 3,
		},
		"war_pit": {
			"name": "战争深坑",
			"cost_gold": 80, "cost_iron": 15, "cost_slaves": 0,
			"desc": "消耗1奴隶 -> 获得3军队",
			"effect": "slave_to_army",
			"effect_value": 3,
		},
	},
	FactionID.PIRATE: {
		"black_market": {
			"name": "海盗黑市",
			"cost_gold": 90, "cost_iron": 6, "cost_slaves": 0,
			"desc": "解锁黑市交易, 可买卖性奴隶和消耗品",
			"effect": "black_market",
			"effect_value": 0,
			"max_level": 3,
		},
		"smugglers_den": {
			"name": "走私者巢穴",
			"cost_gold": 100, "cost_iron": 8, "cost_slaves": 0,
			"desc": "+5金/回合, 战利品+50%, 解锁走私航线",
			"effect": "smuggler_income",
			"effect_value": 5,
		},
		"rum_distillery": {
			"name": "朗姆酒酿造坊",
			"cost_gold": 80, "cost_iron": 4, "cost_slaves": 0,
			"desc": "每回合产出1桶朗姆酒, 提升船员士气",
			"effect": "rum_production",
			"effect_value": 1,
			"max_level": 3,
		},
		"slave_training_pen": {
			"name": "奴隶调教所",
			"cost_gold": 120, "cost_iron": 10, "cost_slaves": 0,
			"desc": "性奴隶调教速度翻倍, 解锁高级调教",
			"effect": "training_boost",
			"effect_value": 2,
			"max_level": 2,
		},
	},
	FactionID.DARK_ELF: {
		"temple_of_agony": {
			"name": "痛苦神殿",
			"cost_gold": 100, "cost_iron": 12, "cost_slaves": 2,
			"desc": "开启祭坛奴隶分配",
			"effect": "altar_unlock",
			"effect_value": 0,
			"max_level": 3,
		},
		"slave_pit": {
			"name": "奴隶深坑",
			"cost_gold": 80, "cost_iron": 10, "cost_slaves": 0,
			"desc": "奴隶工作效率+50%",
			"effect": "slave_efficiency",
			"effect_value": 1.5,
		},
	},
}

# ── Prestige costs ──
const PRESTIGE_COSTS: Dictionary = {
	"recruit_faction": 30,
	"elite_troops": 15,
	"reduce_threat": 20,    # costs 20 prestige -> -10 threat
	"boost_order": 15,       # costs 15 prestige -> +10 order
}

# ── Prestige sources ──
const PRESTIGE_SOURCES: Dictionary = {
	"own_stronghold_per_turn": 1,
	"capture_stronghold": 5,
	"win_combat": 2,
	"conquer_faction": 10,
}

# ── Item Definitions (consumables) ──
const ITEM_DEFS: Dictionary = {
	"attack_totem": {"name": "攻击图腾", "desc": "下次战斗攻击+30%", "type": "consumable", "effect": {"atk_mult": 1.3}},
	"iron_shield": {"name": "铁壁盾牌", "desc": "下次战斗防御+30%", "type": "consumable", "effect": {"def_mult": 1.3}},
	"march_order": {"name": "急行军令", "desc": "本回合骰子+2", "type": "consumable", "effect": {"dice_bonus": 2}},
	"gold_pouch": {"name": "金币袋", "desc": "立即+50金币", "type": "consumable", "effect": {"gold": 50}},
	"ration_pack": {"name": "军粮包", "desc": "立即+10粮草", "type": "consumable", "effect": {"food": 10}},
	"iron_ore": {"name": "铁矿石", "desc": "立即+8铁矿", "type": "consumable", "effect": {"iron": 8}},
	"heal_potion": {"name": "治愈药剂", "desc": "恢复3兵力", "type": "consumable", "effect": {"heal": 3}},
	"slave_shackle": {"name": "奴隶枷锁", "desc": "下次战斗必定俘获1奴隶", "type": "consumable", "effect": {"guaranteed_slave": 1}},
	"mana_jammer_crafted": {"name": "法力干扰器", "desc": "魔法师屏障/法术效果减半(5回合)", "type": "consumable", "effect": {"mage_weaken": 0.5}, "weight": 0},
	"blast_barrel_crafted": {"name": "爆破桶", "desc": "攻城时直接削减15城防", "type": "consumable", "effect": {"wall_damage": 15}, "weight": 0},
	# v0.8.9: Quest reward items
	"refined_iron_weapon": {"name": "精铁武器", "desc": "下次战斗攻击+20%", "type": "consumable", "effect": {"atk_mult": 1.2}, "weight": 0},
	"bomb_barrel": {"name": "地精爆破桶", "desc": "攻城时削减20城防", "type": "consumable", "effect": {"wall_damage": 20}, "weight": 0},
}

# ── Equipment Definitions (v0.8.7) ──
# Slot types: "weapon", "armor", "accessory"
# Rarity: "common" (60% drop), "rare" (30% drop), "legendary" (10% drop)
enum EquipSlot { WEAPON, ARMOR, ACCESSORY }

const EQUIP_SLOT_NAMES: Dictionary = {
	EquipSlot.WEAPON: "武器",
	EquipSlot.ARMOR: "防具",
	EquipSlot.ACCESSORY: "饰品",
}

const EQUIPMENT_DEFS: Dictionary = {
	"blood_moon_blade": {
		"name": "血月之刃", "slot": EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+3, 击杀恢复1兵",
		"stats": {"atk": 3},
		"passive": "kill_heal",  # On kill: restore 1 soldier
		"drop_weight": 10,
	},
	"iron_wall_shield": {
		"name": "铁壁之盾", "slot": EquipSlot.ARMOR, "rarity": "rare",
		"desc": "DEF+2, 本节点城防+5",
		"stats": {"def": 2},
		"passive": "node_wall_bonus",  # +5 wall HP at hero's node
		"passive_value": 5,
		"drop_weight": 30,
	},
	"gale_boots": {
		"name": "疾风之靴", "slot": EquipSlot.ACCESSORY, "rarity": "rare",
		"desc": "SPD+2",
		"stats": {"spd": 2},
		"passive": "none",
		"drop_weight": 30,
	},
	"slave_shackle_equip": {
		"name": "奴隶枷锁", "slot": EquipSlot.ACCESSORY, "rarity": "common",
		"desc": "俘获率+10%",
		"stats": {},
		"passive": "capture_bonus",  # +10% capture rate
		"passive_value": 0.1,
		"drop_weight": 60,
	},
	"mana_orb": {
		"name": "法力宝珠", "slot": EquipSlot.ACCESSORY, "rarity": "rare",
		"desc": "法力上限+3",
		"stats": {},
		"passive": "mana_bonus",  # +3 max mana (for mage interactions)
		"passive_value": 3,
		"drop_weight": 30,
	},
	"war_totem": {
		"name": "战力图腾", "slot": EquipSlot.WEAPON, "rarity": "rare",
		"desc": "全军战力+30% 1战",
		"stats": {"atk": 1},
		"passive": "one_battle_power",  # +30% army power for 1 battle
		"passive_value": 0.3,
		"drop_weight": 30,
	},
	"garrison_banner": {
		"name": "驻军旗帜", "slot": EquipSlot.ACCESSORY, "rarity": "rare",
		"desc": "所有据点驻军上限+1",
		"stats": {},
		"passive": "garrison_bonus",  # All nodes +1 garrison cap
		"passive_value": 1,
		"drop_weight": 30,
	},
	"counter_tactics": {
		"name": "克制战术", "slot": EquipSlot.ACCESSORY, "rarity": "legendary",
		"desc": "兵种克制系数+15%",
		"stats": {},
		"passive": "rps_bonus",  # Unit type advantage +15%
		"passive_value": 0.15,
		"drop_weight": 10,
	},
}

# Rarity drop weights (cumulative thresholds for random equipment generation)
const EQUIP_RARITY_WEIGHTS: Dictionary = {
	"common": 60,
	"rare": 30,
	"legendary": 10,
}

# ── Hero Active Skill Definitions (v0.9.0) ──
# Each skill has: type (damage/heal/buff/debuff/aoe), power (base value), int_scale (INT multiplier),
# cooldown (turns between uses), desc (display text).
# Damage skills deal (power + INT * int_scale) * army_count_factor damage to enemy effective power.
# Heal skills restore soldiers. Buff/debuff apply multipliers.
const HERO_SKILL_DEFS: Dictionary = {
	# --- Light heroes (captured/recruited) ---
	"圣光斩": {"type": "damage", "power": 40, "int_scale": 5.0, "target": "enemy",
		"desc": "对敌军造成光属性伤害", "cooldown": 2},
	"治愈之光": {"type": "heal", "power": 2, "int_scale": 0.3, "target": "ally",
		"desc": "恢复己方士兵", "cooldown": 3},
	"突击号令": {"type": "buff", "power": 0.2, "int_scale": 0.02, "target": "ally",
		"buff_type": "atk_mult", "duration": 1, "desc": "全军攻击力提升", "cooldown": 3},
	"不动如山": {"type": "buff", "power": 0.3, "int_scale": 0.02, "target": "ally",
		"buff_type": "def_mult", "duration": 1, "desc": "全军防御力大幅提升", "cooldown": 4},
	"箭雨": {"type": "aoe", "power": 30, "int_scale": 4.0, "target": "enemy",
		"desc": "对全体敌军造成范围伤害", "cooldown": 2},
	"月光护盾": {"type": "buff", "power": 0.25, "int_scale": 0.03, "target": "ally",
		"buff_type": "def_mult", "duration": 2, "desc": "持续防御增强护盾", "cooldown": 4},
	"影步": {"type": "damage", "power": 60, "int_scale": 3.0, "target": "enemy",
		"desc": "暗杀: 对敌军造成高额单体伤害", "cooldown": 3},
	"流星火雨": {"type": "aoe", "power": 50, "int_scale": 8.0, "target": "enemy",
		"desc": "强力范围魔法攻击", "cooldown": 4},
	"时间减速": {"type": "debuff", "power": 0.25, "int_scale": 0.02, "target": "enemy",
		"buff_type": "atk_mult", "duration": 2, "desc": "降低敌军攻击力", "cooldown": 3},
	"爆裂火球": {"type": "damage", "power": 45, "int_scale": 6.0, "target": "enemy",
		"desc": "爆炸性火焰伤害", "cooldown": 2},
	# --- Pirate/Dark Elf heroes ---
	"连射": {"type": "damage", "power": 35, "int_scale": 4.0, "target": "enemy",
		"desc": "连续射击造成多段伤害", "cooldown": 2},
	"致命一击": {"type": "damage", "power": 70, "int_scale": 2.0, "target": "enemy",
		"desc": "致命暗杀, 极高单体伤害", "cooldown": 4},
	# --- Neutral leaders ---
	"铁壁": {"type": "buff", "power": 0.35, "int_scale": 0.01, "target": "ally",
		"buff_type": "def_mult", "duration": 2, "desc": "铁壁防御, 大幅提升防御", "cooldown": 4},
	"沙暴": {"type": "debuff", "power": 0.2, "int_scale": 0.02, "target": "enemy",
		"buff_type": "atk_mult", "duration": 1, "desc": "沙暴削弱敌军攻击", "cooldown": 3},
	"亡灵召唤": {"type": "summon", "power": 3, "int_scale": 0.5, "target": "ally",
		"desc": "召唤骷髅兵增援", "cooldown": 4},
	"分身": {"type": "buff", "power": 0.15, "int_scale": 0.01, "target": "ally",
		"buff_type": "dodge", "duration": 2, "desc": "分身术, 降低己方受到的伤害", "cooldown": 3},
	"净化": {"type": "heal", "power": 3, "int_scale": 0.4, "target": "ally",
		"desc": "净化治愈, 恢复士兵并清除减益", "cooldown": 3},
	"集中轰炸": {"type": "aoe", "power": 55, "int_scale": 4.0, "target": "enemy",
		"desc": "炮击! 对敌军全体造成高额伤害", "cooldown": 4},
}
const RELIC_DEFS: Dictionary = {
	"bloody_banner": {"name": "血腥战旗", "desc": "战斗胜利额外+1奴隶", "effect": {"victory_slave_bonus": 1}},
	"shadow_cloak": {"name": "暗影斗篷", "desc": "每局首次被攻击免伤", "effect": {"first_hit_immune": true}},
	"ancient_totem": {"name": "远古图腾", "desc": "WAAAGH!/掠夺值/奴隶产出+25%", "effect": {"faction_resource_mult": 1.25}},
	"greed_crown": {"name": "贪婪之冠", "desc": "所有金币收入+20%", "effect": {"gold_income_mult": 1.2}},
	"iron_banner": {"name": "铁血令旗", "desc": "招募费用-20%", "effect": {"recruit_cost_mult": 0.8}},
	"chaos_amulet": {"name": "混沌护符", "desc": "负面事件概率减半", "effect": {"negative_event_mult": 0.5}},
}

# ── Evil Faction Diplomacy Costs ──
const EVIL_FACTION_DIPLOMACY_COSTS: Dictionary = {
	FactionID.ORC: {"prestige": 30, "gold": 200, "order_min": 40},
	FactionID.PIRATE: {"prestige": 40, "gold": 300, "order_min": 40},
	FactionID.DARK_ELF: {"prestige": 50, "gold": 250, "order_min": 40},
}

# ── Outpost Upgrade Requirements ──
const OUTPOST_UPGRADE_REQUIREMENTS: Dictionary = {
	2: {"order_min": 30, "min_owned_turns": 3, "cost": {"gold": 100, "iron": 10}},
	3: {"order_min": 60, "min_owned_turns": 3, "cost": {"gold": 200, "iron": 20}},
}

# ══════════════════════════════════════════════════════════════════════════════
# ── TERRAIN SYSTEM (v0.8.3) ──
# Terrain is orthogonal to TileType: TileType = function, TerrainType = geography
# Every tile has both. Terrain affects combat, movement, production, visibility.
# ══════════════════════════════════════════════════════════════════════════════

enum TerrainType { PLAINS, FOREST, MOUNTAIN, SWAMP, COASTAL, FORTRESS_WALL }

const TERRAIN_DATA: Dictionary = {
	TerrainType.PLAINS: {
		"name": "平原", "icon": "🌾",
		"move_cost": 1,
		"atk_mult": 1.0,        # no modifier
		"def_mult": 1.0,
		"production_mult": 1.0,
		"visibility_range": 2,
		"desc": "标准地形，无特殊加成，适合大规模正面交战",
	},
	TerrainType.FOREST: {
		"name": "森林", "icon": "🌲",
		"move_cost": 2,
		"atk_mult": 0.85,       # attacker -15% (difficult to coordinate assault)
		"def_mult": 1.25,       # defender +25% (tree cover, ambush advantage)
		"production_mult": 0.9,
		"visibility_range": 1,  # low visibility
		"desc": "防御方+25%防御，攻击方-15%攻击，视野缩减",
		"special_flags": ["ambush_terrain"],  # ninja/ranger units get bonus here
	},
	TerrainType.MOUNTAIN: {
		"name": "山地", "icon": "⛰️",
		"move_cost": 3,
		"atk_mult": 0.75,       # very hard to assault uphill
		"def_mult": 1.40,       # high ground advantage
		"production_mult": 0.7,
		"visibility_range": 3,  # high ground = far sight
		"desc": "防御方+40%防御，攻击方-25%攻击，视野增加，骑兵减效",
		"special_flags": ["cavalry_penalty"],  # cavalry charge reduced
	},
	TerrainType.SWAMP: {
		"name": "沼泽", "icon": "🏚️",
		"move_cost": 3,
		"atk_mult": 0.80,       # both sides suffer
		"def_mult": 0.90,       # defenders also hampered
		"production_mult": 0.6,
		"visibility_range": 1,
		"desc": "双方战斗力下降，骑兵无法冲锋，忍者不受影响",
		"special_flags": ["disable_charge", "ninja_immune"],
	},
	TerrainType.COASTAL: {
		"name": "沿海", "icon": "🌊",
		"move_cost": 1,
		"atk_mult": 1.0,
		"def_mult": 1.0,
		"production_mult": 1.1,  # trade bonus
		"visibility_range": 2,
		"desc": "产出+10%，海盗单位ATK+15%，可建港口",
		"special_flags": ["pirate_bonus", "harbor_eligible"],
	},
	TerrainType.FORTRESS_WALL: {
		"name": "城墙", "icon": "🏰",
		"move_cost": 2,
		"atk_mult": 0.70,       # attackers heavily penalized
		"def_mult": 1.50,       # massive defense bonus
		"production_mult": 0.8,
		"visibility_range": 3,
		"desc": "防御方+50%防御，攻击方-30%攻击，城防HP+20",
		"special_flags": ["wall_hp_bonus"],
		"wall_hp_bonus": 20,
	},
}

# ── Chokepoint (关隘) Data ──
# Chokepoints are topological (few connections) not geographic.
# A tile can be MOUNTAIN + chokepoint, or FORTRESS_WALL + chokepoint.
const CHOKEPOINT_DATA: Dictionary = {
	"name": "关隘",
	"garrison_bonus": 5,          # extra starting garrison
	"def_mult_bonus": 0.20,       # +20% DEF on top of terrain DEF
	"atk_penalty": 0.10,          # additional -10% ATK for attacker
	"max_chokepoints": 6,         # max chokepoints per map
	"min_degree": 1,              # adjacency degree range for candidates
	"max_degree": 3,
	"desc": "战略要冲：防御方额外+20%，攻击方额外-10%，驻军+5",
}

# ── Terrain Zone Distribution Weights ──
# [PLAINS, FOREST, MOUNTAIN, SWAMP, COASTAL, FORTRESS_WALL]
const TERRAIN_ZONE_WEIGHTS: Dictionary = {
	"human":    [0.30, 0.15, 0.10, 0.05, 0.10, 0.30],  # fortified kingdom, plains + walls
	"elf":      [0.10, 0.55, 0.20, 0.10, 0.05, 0.00],  # ancient forests + highlands
	"mage":     [0.35, 0.10, 0.30, 0.05, 0.10, 0.10],  # arcane mountain towers
	"orc":      [0.45, 0.10, 0.25, 0.10, 0.00, 0.10],  # wasteland plains + crags
	"pirate":   [0.15, 0.05, 0.05, 0.20, 0.40, 0.15],  # coastal + swamp coves
	"dark_elf": [0.15, 0.40, 0.15, 0.20, 0.00, 0.10],  # shadowy forests + swamps
	"neutral":  [0.40, 0.25, 0.15, 0.10, 0.05, 0.05],  # follows design doc global ratios
}

# ── Named Outpost Definitions (v0.8.3) ──
# Pre-designed notable locations that get placed during map generation.
# Each has a fixed name, preferred terrain, and special properties.
const NAMED_OUTPOSTS: Array = [
	# ── Trading Posts (交易站) ──
	{"id": "silk_road_bazaar", "name": "丝路集市", "tile_type": "TRADING_POST",
		"terrain": TerrainType.PLAINS, "garrison": 4,
		"gold_bonus": 5, "desc": "繁忙的商路交汇点",
		"prod": {"gold": 10, "food": 3, "iron": 1, "pop": 2}},
	{"id": "shadowmarket", "name": "暗巷黑市", "tile_type": "TRADING_POST",
		"terrain": TerrainType.COASTAL, "garrison": 6,
		"gold_bonus": 8, "desc": "走私者的秘密贸易点",
		"prod": {"gold": 12, "food": 1, "iron": 2, "pop": 1}},

	# ── Watchtowers (瞭望塔) ──
	{"id": "eagles_perch", "name": "鹰眼哨", "tile_type": "WATCHTOWER",
		"terrain": TerrainType.MOUNTAIN, "garrison": 3,
		"visibility_bonus": 2, "desc": "高山瞭望哨，视野覆盖3格",
		"prod": {"gold": 2, "food": 1, "iron": 1, "pop": 1}},
	{"id": "border_beacon", "name": "边境烽火台", "tile_type": "WATCHTOWER",
		"terrain": TerrainType.MOUNTAIN, "garrison": 5,
		"visibility_bonus": 2, "desc": "点燃烽火可警示全境",
		"prod": {"gold": 3, "food": 1, "iron": 2, "pop": 1}},

	# ── Ruins (遗迹) ──
	{"id": "ancient_library", "name": "远古图书馆", "tile_type": "RUINS",
		"terrain": TerrainType.FOREST, "garrison": 8,
		"relic_chance": 0.20, "desc": "残存的上古文明知识库",
		"prod": {"gold": 5, "food": 0, "iron": 0, "pop": 1}},
	{"id": "fallen_temple", "name": "堕落神殿", "tile_type": "RUINS",
		"terrain": TerrainType.SWAMP, "garrison": 10,
		"relic_chance": 0.25, "desc": "被遗弃的邪神祭坛，蕴含危险力量",
		"prod": {"gold": 3, "food": 0, "iron": 2, "pop": 1}},

	# ── Harbors (港口) ──
	{"id": "smugglers_cove", "name": "走私者湾", "tile_type": "HARBOR",
		"terrain": TerrainType.COASTAL, "garrison": 5,
		"gold_bonus": 3, "food_bonus": 2, "desc": "隐蔽的海湾港口",
		"prod": {"gold": 8, "food": 4, "iron": 1, "pop": 2}},
	{"id": "fishermans_wharf", "name": "渔人码头", "tile_type": "HARBOR",
		"terrain": TerrainType.COASTAL, "garrison": 3,
		"food_bonus": 5, "desc": "繁忙的渔港，粮食充裕",
		"prod": {"gold": 5, "food": 7, "iron": 0, "pop": 3}},

	# ── Chokepoint Passes (关隘) ──
	{"id": "iron_gate_pass", "name": "铁门关", "tile_type": "CHOKEPOINT",
		"terrain": TerrainType.MOUNTAIN, "garrison": 12,
		"is_chokepoint": true, "desc": "一夫当关万夫莫开的险要隘口",
		"prod": {"gold": 3, "food": 1, "iron": 5, "pop": 2}},
	{"id": "serpent_gorge", "name": "蛇腹峡", "tile_type": "CHOKEPOINT",
		"terrain": TerrainType.MOUNTAIN, "garrison": 10,
		"is_chokepoint": true, "desc": "蜿蜒狭窄的山间峡谷",
		"prod": {"gold": 2, "food": 1, "iron": 3, "pop": 1}},
	{"id": "mist_bridge", "name": "雾桥", "tile_type": "CHOKEPOINT",
		"terrain": TerrainType.SWAMP, "garrison": 8,
		"is_chokepoint": true, "desc": "沼泽上唯一的通行桥梁",
		"prod": {"gold": 1, "food": 2, "iron": 1, "pop": 1}},
	{"id": "shadow_pass", "name": "暗影隘口", "tile_type": "CHOKEPOINT",
		"terrain": TerrainType.FOREST, "garrison": 9,
		"is_chokepoint": true, "desc": "幽暗密林中的狭窄小道",
		"prod": {"gold": 2, "food": 2, "iron": 2, "pop": 1}},
]

# ── Training System (v0.8.5 - Per-Faction Training) ──
# Training is PLAYER-ONLY. AI factions scale via threat value instead.
# Each evil faction has its own complete training tree covering their available units.
# Research requires Academy building.

enum TechBranch { VANGUARD, RANGED, MOBILE, MAGIC, FACTION_SPECIAL }
enum TechTier { BASIC, ADVANCED, ULTIMATE }

const RESEARCH_BASE_SPEED: float = 1.0

# ── Faction Unit Availability ──
# Each faction can only recruit and train these unit types:
const FACTION_AVAILABLE_UNITS: Dictionary = {
	FactionID.ORC: ["ashigaru", "samurai", "priest", "mage_unit", "orc_ashigaru", "orc_samurai", "orc_cavalry"],
	FactionID.PIRATE: ["archer", "cannon", "cavalry", "ninja", "pirate_ashigaru", "pirate_archer", "pirate_cannon"],
	FactionID.DARK_ELF: ["ninja", "priest", "mage_unit", "shadow_walker", "de_ninja", "de_cavalry", "de_samurai"],
}

# ── Per-Faction Training Trees ──
# Replaces old SHARED_TECH_TREE + FACTION_TECH_TREE
# Each faction has ~9 nodes: 4×T1 + 4×T2 + 1×T3
const FACTION_TRAINING_TREE: Dictionary = {
	# ═══ 兽人训练树 — WAAAGH!蛮力路线 ═══
	# Units: 足轻/武士 (前卫) + 祭司/術師 (后排) + orc_ashigaru/orc_samurai/orc_cavalry (阵营)
	FactionID.ORC: {
		"orc_vanguard_basic": {
			"name": "蛮力操练",
			"branch": TechBranch.VANGUARD,
			"tier": TechTier.BASIC,
			"cost": {"gold": 200},
			"turns": 1,
			"prereqs": [],
			"desc": "足軽ATK+15%",
			"effects": {"unit_buff": {"types": ["ashigaru", "orc_ashigaru"], "atk_pct": 0.15}},
		},
		"orc_support_basic": {
			"name": "重甲锻造",
			"branch": TechBranch.VANGUARD,
			"tier": TechTier.BASIC,
			"cost": {"gold": 200},
			"turns": 1,
			"prereqs": [],
			"desc": "武士DEF+15%",
			"effects": {"unit_buff": {"types": ["samurai", "orc_samurai"], "def_pct": 0.15}},
		},
		"orc_warcry_basic": {
			"name": "战吼鼓舞",
			"branch": TechBranch.FACTION_SPECIAL,
			"tier": TechTier.BASIC,
			"cost": {"gold": 250},
			"turns": 1,
			"prereqs": [],
			"desc": "全军士气上限+10",
			"effects": {"morale_cap_bonus": 10},
		},
		"orc_morale_basic": {
			"name": "祭祀祈福",
			"branch": TechBranch.MAGIC,
			"tier": TechTier.BASIC,
			"cost": {"gold": 200},
			"turns": 1,
			"prereqs": [],
			"desc": "祭司治疗量+20%",
			"effects": {"unit_buff": {"types": ["priest"], "heal_pct": 0.20}},
		},
		"orc_berserker": {
			"name": "狂暴突击",
			"branch": TechBranch.VANGUARD,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 400},
			"turns": 2,
			"prereqs": ["orc_vanguard_basic", "orc_support_basic"],
			"desc": "[被动] 足轻/武士·狂暴: HP<50%时ATK+25%",
			"effects": {"unit_passive": {"type": "ashigaru", "id": "berserker", "low_hp_atk_mult": 1.25}, "unit_passive_2": {"type": "samurai", "id": "berserker", "low_hp_atk_mult": 1.25}},
		},
		"orc_troll_regen": {
			"name": "战场嚎叫",
			"branch": TechBranch.FACTION_SPECIAL,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 350},
			"turns": 2,
			"prereqs": ["orc_warcry_basic"],
			"desc": "[被动] 每回合开始敌方前排士气-5",
			"effects": {"unit_passive": {"type": "all_orc", "id": "war_howl", "enemy_front_morale_debuff": 5}},
		},
		"orc_blood_ritual": {
			"name": "血祭术",
			"branch": TechBranch.MAGIC,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 400},
			"turns": 2,
			"prereqs": ["orc_morale_basic"],
			"desc": "[被动] 術師·血祭: 消耗10%己方HP, 法术伤害×1.8",
			"effects": {"unit_passive": {"type": "mage_unit", "id": "blood_ritual", "hp_cost_pct": 0.10, "spell_mult": 1.8}},
		},
		"orc_warg_charge": {
			"name": "铁壁方阵",
			"branch": TechBranch.VANGUARD,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 350},
			"turns": 2,
			"prereqs": ["orc_support_basic"],
			"desc": "[被动] 武士·铁壁: 相邻友军受伤-15%",
			"effects": {"unit_passive": {"type": "samurai", "id": "iron_wall", "adjacent_dmg_reduction": 0.15}},
		},
		"orc_ultimate": {
			"name": "WAAAGH!怒吼",
			"branch": TechBranch.FACTION_SPECIAL,
			"tier": TechTier.ULTIMATE,
			"cost": {"gold": 800},
			"turns": 3,
			"prereqs": ["orc_berserker", "orc_troll_regen"],
			"desc": "[主动] 消耗20 WAAAGH!→全军ATK×1.5(1回合)+免士气下降 (CD:5)",
			"effects": {"unit_active": {"type": "all_orc", "id": "waaagh_roar", "atk_mult": 1.5, "duration": 1, "morale_immune": true, "waaagh_cost": 20, "cooldown": 5}},
		},
	},

	# ═══ 海盗训练树 — 掠夺机动路线 ═══
	# Units: 弓兵/砲兵 (远程) + 骑兵/忍者 (机动) + pirate_ashigaru/pirate_archer/pirate_cannon (阵营)
	FactionID.PIRATE: {
		"pirate_ranged_basic": {
			"name": "精准射击",
			"branch": TechBranch.RANGED,
			"tier": TechTier.BASIC,
			"cost": {"gold": 200},
			"turns": 1,
			"prereqs": [],
			"desc": "弓兵ATK+15%",
			"effects": {"unit_buff": {"types": ["archer", "pirate_archer"], "atk_pct": 0.15}},
		},
		"pirate_mobile_basic": {
			"name": "火药改良",
			"branch": TechBranch.RANGED,
			"tier": TechTier.BASIC,
			"cost": {"gold": 250},
			"turns": 1,
			"prereqs": [],
			"desc": "砲兵攻城伤害+20%",
			"effects": {"unit_buff": {"types": ["cannon", "pirate_cannon"], "siege_pct": 0.20}},
		},
		"pirate_crew_basic": {
			"name": "轻骑突袭",
			"branch": TechBranch.MOBILE,
			"tier": TechTier.BASIC,
			"cost": {"gold": 200},
			"turns": 1,
			"prereqs": [],
			"desc": "騎兵移动力+1",
			"effects": {"unit_buff": {"types": ["cavalry"], "move": 1}},
		},
		"pirate_plunder_basic": {
			"name": "暗杀训练",
			"branch": TechBranch.MOBILE,
			"tier": TechTier.BASIC,
			"cost": {"gold": 200},
			"turns": 1,
			"prereqs": [],
			"desc": "忍者暴击率+10%",
			"effects": {"unit_buff": {"types": ["ninja"], "crit_pct": 0.10}},
		},
		"pirate_volley": {
			"name": "齐射战术",
			"branch": TechBranch.RANGED,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 400},
			"turns": 2,
			"prereqs": ["pirate_ranged_basic"],
			"desc": "[被动] 弓兵·齐射: 集火伤害+30%",
			"effects": {"unit_passive": {"type": "archer", "id": "volley", "focus_fire_bonus": 0.30}},
		},
		"pirate_gunner_dualshot": {
			"name": "连环炮",
			"branch": TechBranch.RANGED,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 400},
			"turns": 2,
			"prereqs": ["pirate_mobile_basic"],
			"desc": "[被动] 砲兵·连环炮: 25%概率追加半伤射击",
			"effects": {"unit_passive": {"type": "cannon", "id": "chain_shot", "extra_shot_chance": 0.25, "extra_shot_mult": 0.50}},
		},
		"pirate_bombardier_ap": {
			"name": "劫掠之风",
			"branch": TechBranch.FACTION_SPECIAL,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 350},
			"turns": 2,
			"prereqs": ["pirate_crew_basic"],
			"desc": "[被动] 占领城池时额外获得50%金币掠夺",
			"effects": {"capture_plunder_bonus": 0.50},
		},
		"pirate_smoke": {
			"name": "烟雾弹",
			"branch": TechBranch.MOBILE,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 350},
			"turns": 2,
			"prereqs": ["pirate_plunder_basic"],
			"desc": "[被动] 忍者·烟雾弹: 自身所在列全体1回合闪避+30%",
			"effects": {"unit_passive": {"type": "ninja", "id": "smoke_bomb", "column_evasion": 0.30, "evasion_turns": 1}},
		},
		"pirate_ultimate": {
			"name": "黑旗恐惧",
			"branch": TechBranch.FACTION_SPECIAL,
			"tier": TechTier.ULTIMATE,
			"cost": {"gold": 800},
			"turns": 3,
			"prereqs": ["pirate_volley", "pirate_bombardier_ap"],
			"desc": "[主动] 敌方ATK-20%/DEF-10%(2回合)+25%逃兵 (CD:5)",
			"effects": {"unit_active": {"type": "all_pirate", "id": "black_flag_terror", "enemy_atk_debuff": 0.20, "enemy_def_debuff": 0.10, "duration": 2, "desert_chance": 0.25, "cooldown": 5}},
		},
	},

	# ═══ 暗精灵训练树 — 暗影诡计路线 ═══
	# Units: 忍者/祭司/術師 (共用) + shadow_walker/de_ninja/de_cavalry/de_samurai (阵营)
	FactionID.DARK_ELF: {
		"delf_stealth_basic": {
			"name": "暗影潜行",
			"branch": TechBranch.MOBILE,
			"tier": TechTier.BASIC,
			"cost": {"gold": 200},
			"turns": 1,
			"prereqs": [],
			"desc": "忍者首回合不可被选为目标",
			"effects": {"unit_passive": {"type": "ninja", "id": "stealth_basic", "first_turn_untargetable": true}},
		},
		"delf_magic_basic": {
			"name": "月之祝福",
			"branch": TechBranch.MAGIC,
			"tier": TechTier.BASIC,
			"cost": {"gold": 250},
			"turns": 1,
			"prereqs": [],
			"desc": "祭司治疗同时附加护盾(治疗量×30%)",
			"effects": {"unit_passive": {"type": "priest", "id": "moon_blessing", "shield_pct": 0.30}},
		},
		"delf_warrior_basic": {
			"name": "黑魔研习",
			"branch": TechBranch.MAGIC,
			"tier": TechTier.BASIC,
			"cost": {"gold": 200},
			"turns": 1,
			"prereqs": [],
			"desc": "術師法术伤害+15%",
			"effects": {"unit_buff": {"types": ["mage_unit"], "spell_pct": 0.15}},
		},
		"delf_shadow_walker": {
			"name": "暗影行者训练",
			"branch": TechBranch.FACTION_SPECIAL,
			"tier": TechTier.BASIC,
			"cost": {"gold": 300},
			"turns": 1,
			"prereqs": [],
			"desc": "解锁专属单位'暗影行者'(隐匿型近战刺客)",
			"effects": {"unlock_unit": "shadow_walker"},
		},
		"delf_erosion": {
			"name": "精神侵蚀",
			"branch": TechBranch.MAGIC,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 400},
			"turns": 2,
			"prereqs": ["delf_warrior_basic"],
			"desc": "[被动] 術師攻击附带2回合持续伤害(8%ATK/回合)",
			"effects": {"unit_passive": {"type": "mage_unit", "id": "erosion", "dot_pct": 0.08, "dot_turns": 2}},
		},
		"delf_assassin_venom": {
			"name": "幽影分身",
			"branch": TechBranch.FACTION_SPECIAL,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 400},
			"turns": 2,
			"prereqs": ["delf_shadow_walker"],
			"desc": "[被动] 暗影行者被攻击25%闪避",
			"effects": {"unit_passive": {"type": "shadow_walker", "id": "shadow_clone", "dodge_chance": 0.25}},
		},
		"delf_shadow_clone": {
			"name": "暗之治愈",
			"branch": TechBranch.MAGIC,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 350},
			"turns": 2,
			"prereqs": ["delf_magic_basic"],
			"desc": "[被动] 祭司治疗时20%概率净化1个负面状态",
			"effects": {"unit_passive": {"type": "priest", "id": "dark_heal", "cleanse_chance": 0.20}},
		},
		"delf_intel_net": {
			"name": "情报网络",
			"branch": TechBranch.MOBILE,
			"tier": TechTier.ADVANCED,
			"cost": {"gold": 350},
			"turns": 2,
			"prereqs": ["delf_stealth_basic"],
			"desc": "[被动] 战前可查看敌军完整编制与站位",
			"effects": {"intel_reveal": true},
		},
		"delf_ultimate": {
			"name": "暗影支配",
			"branch": TechBranch.FACTION_SPECIAL,
			"tier": TechTier.ULTIMATE,
			"cost": {"gold": 800},
			"turns": 3,
			"prereqs": ["delf_erosion", "delf_intel_net"],
			"desc": "[主动] 控制1敌方单位1回合+全军隐匿(首击免伤) (CD:6)",
			"effects": {"unit_active": {"type": "all_dark_elf", "id": "shadow_domination", "mind_control_targets": 1, "mind_control_turns": 1, "team_stealth": true, "cooldown": 6}},
		},
	},
}

# ── AI Threat Scaling Data (replaces AI tech tree) ──
# AI factions (both evil and light) do NOT use training.
# Their combat stats scale with threat value tiers.
const AI_THREAT_SCALING: Dictionary = {
	# Base stat multipliers per tier
	"tiers": {
		0: {"name": "常态", "atk_mult": 1.0, "def_mult": 1.0, "hp_mult": 1.0, "garrison_regen_bonus": 0, "wall_bonus": 0.0},
		1: {"name": "防御态势", "atk_mult": 1.10, "def_mult": 1.15, "hp_mult": 1.0, "garrison_regen_bonus": 1, "wall_bonus": 0.20},
		2: {"name": "军事动员", "atk_mult": 1.20, "def_mult": 1.25, "hp_mult": 1.0, "garrison_regen_bonus": 2, "wall_bonus": 0.30},
		3: {"name": "绝境反击", "atk_mult": 1.35, "def_mult": 1.40, "hp_mult": 1.20, "garrison_regen_bonus": 3, "wall_bonus": 0.50},
	},
	# Per-faction passives unlocked at tier 2
	"tier2_passives": {
		"human": {"id": "steadfast_will", "name": "坚守意志", "def_bonus_pct": 0.10, "morale_floor": 1},
		"elf": {"id": "nature_grace", "name": "自然恩赐", "hp_regen_pct": 0.05},
		"mage": {"id": "mana_overflow", "name": "魔力涌流", "spell_atk_bonus_pct": 0.15},
		"orc_ai": {"id": "war_fervor", "name": "战意高涨", "atk_bonus_pct": 0.10, "morale_immune": true},
		"pirate_ai": {"id": "plunder_wind", "name": "劫掠之风", "resource_bonus_pct": 0.25},
		"dark_elf_ai": {"id": "intel_network", "name": "情报网络", "full_map_vision": true},
	},
	# Per-faction ultimates unlocked at tier 3
	"tier3_ultimates": {
		"human": {"id": "kings_decree", "name": "王之号令", "all_atk_def_pct": 0.20, "duration": 3, "summon_elite": true},
		"elf": {"id": "ancient_awakening", "name": "古树觉醒", "summon_boss": {"hp": 300, "atk": 60, "def": 50}, "team_heal_pct": 0.30},
		"mage": {"id": "forbidden_judgment", "name": "禁咒·天罚", "aoe_damage": 80, "silence_turns": 2},
		"orc_ai": {"id": "waaagh_roar", "name": "WAAAGH!怒吼", "atk_mult": 1.5, "duration": 1, "morale_immune": true},
		"pirate_ai": {"id": "black_flag_terror", "name": "黑旗恐惧", "enemy_atk_debuff": 0.20, "enemy_def_debuff": 0.10, "duration": 2, "desert_chance": 0.25},
		"dark_elf_ai": {"id": "shadow_domination", "name": "暗影支配", "mind_control": 1, "team_stealth": true},
	},
	# Expedition & Boss spawn rules
	"expedition": {"min_tier": 2, "interval_turns": 3, "unit_count_range": [3, 5]},
	"boss": {"min_tier": 3, "interval_turns": 5, "hp_mult": 3.0, "atk_mult": 2.0},
}
