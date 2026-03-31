## fixed_map_data.gd
## Hand-designed fixed map with 55 territories organized into 7 nations.
## Each territory has fixed positions, adjacency, and metadata.
## Used by MapGenerator.generate_fixed() as an alternative to procedural generation.

class_name FixedMapData
extends RefCounted

const FactionData = preload("res://systems/faction/faction_data.gd")

# ---------------------------------------------------------------------------
# Nation definitions
# ---------------------------------------------------------------------------

const NATION_IDS: Array = [
	"human_kingdom",
	"elven_domain",
	"mage_alliance",
	"orc_horde",
	"pirate_coalition",
	"dark_elf_clan",
	"neutral",
]

const NATION_NAMES: Dictionary = {
	"human_kingdom": "人类王国",
	"elven_domain": "精灵领地",
	"mage_alliance": "法师联盟",
	"orc_horde": "兽人部落",
	"pirate_coalition": "海盗联盟",
	"dark_elf_clan": "暗精灵一族",
	"neutral": "中立地带",
}

# ---------------------------------------------------------------------------
# Territory data — 55 entries total
# ---------------------------------------------------------------------------
# IDs 0-8: Human Kingdom (9)
# IDs 9-13: Elven Domain (5)
# IDs 14-18: Mage Alliance (5)
# IDs 19-23: Orc Horde (5)
# IDs 24-27: Pirate Coalition (4)
# IDs 28-30: Dark Elf Clan (3)
# IDs 31-54: Neutral Lands (24)

# placeholder — filled below
static func get_territories() -> Array:
	return TERRITORIES

const TERRITORIES: Array = [
	# =====================================================================
	# HUMAN KINGDOM (IDs 0–8) — northeast area
	# =====================================================================
	# 0: 天城王都 (capital)
	{
		"id": 0,
		"name": "天城王都",
		"nation_id": "human_kingdom",
		"nation_name": "人类王国",
		"position": Vector2(1350, 150),
		"type": "FORTRESS",
		"terrain": "WALL",
		"faction": "HUMAN",
		"garrison_base": 15,
		"city_def": 50,
		"level": 3,
		"connections": [1, 2, 3, 4],
		"is_capital": true,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "人类王国的辉煌首都，高墙环绕的雄伟都城",
	},
	# 1: 银冠要塞
	{
		"id": 1,
		"name": "银冠要塞",
		"nation_id": "human_kingdom",
		"nation_name": "人类王国",
		"position": Vector2(1550, 250),
		"type": "FORTRESS",
		"terrain": "WALL",
		"faction": "HUMAN",
		"garrison_base": 10,
		"city_def": 35,
		"level": 3,
		"connections": [0, 4, 5, 7, 8, 9],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "守护王国北方的银色要塞",
	},
	# 2: 铁壁关
	{
		"id": 2,
		"name": "铁壁关",
		"nation_id": "human_kingdom",
		"nation_name": "人类王国",
		"position": Vector2(1150, 280),
		"type": "FORTRESS",
		"terrain": "WALL",
		"faction": "HUMAN",
		"garrison_base": 12,
		"city_def": 40,
		"level": 3,
		"connections": [0, 3, 6, 31, 28],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "扼守王国西面通道的铁壁要塞",
	},
	# 3: 枫叶村
	{
		"id": 3,
		"name": "枫叶村",
		"nation_id": "human_kingdom",
		"nation_name": "人类王国",
		"position": Vector2(1280, 220),
		"type": "VILLAGE",
		"terrain": "PLAINS",
		"faction": "HUMAN",
		"garrison_base": 4,
		"city_def": 5,
		"level": 1,
		"connections": [0, 2, 4],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "宁静的枫叶村，秋日红叶如火",
	},
	# 4: 晨曦镇
	{
		"id": 4,
		"name": "晨曦镇",
		"nation_id": "human_kingdom",
		"nation_name": "人类王国",
		"position": Vector2(1450, 200),
		"type": "VILLAGE",
		"terrain": "PLAINS",
		"faction": "HUMAN",
		"garrison_base": 4,
		"city_def": 5,
		"level": 1,
		"connections": [0, 1, 3, 5],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "沐浴在晨光中的繁华市镇",
	},
	# 5: 柳河庄
	{
		"id": 5,
		"name": "柳河庄",
		"nation_id": "human_kingdom",
		"nation_name": "人类王国",
		"position": Vector2(1600, 180),
		"type": "VILLAGE",
		"terrain": "RIVER",
		"faction": "HUMAN",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [1, 4, 9],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "依河而建的富庶村庄",
	},
	# 6: 铁壁堡
	{
		"id": 6,
		"name": "铁壁堡",
		"nation_id": "human_kingdom",
		"nation_name": "人类王国",
		"position": Vector2(1200, 380),
		"type": "OUTPOST",
		"terrain": "WALL",
		"faction": "HUMAN",
		"garrison_base": 8,
		"city_def": 25,
		"level": 2,
		"connections": [2, 7, 14, 33],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "人类王国南方防线的前哨据点",
	},
	# 7: 狮鹫堡
	{
		"id": 7,
		"name": "狮鹫堡",
		"nation_id": "human_kingdom",
		"nation_name": "人类王国",
		"position": Vector2(1400, 340),
		"type": "OUTPOST",
		"terrain": "MOUNTAIN",
		"faction": "HUMAN",
		"garrison_base": 8,
		"city_def": 20,
		"level": 2,
		"connections": [6, 8, 1, 34],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "狮鹫骑士团驻扎的山地堡垒",
	},
	# 8: 雷鸣关
	{
		"id": 8,
		"name": "雷鸣关",
		"nation_id": "human_kingdom",
		"nation_name": "人类王国",
		"position": Vector2(1550, 370),
		"type": "OUTPOST",
		"terrain": "MOUNTAIN",
		"faction": "HUMAN",
		"garrison_base": 8,
		"city_def": 25,
		"level": 2,
		"connections": [1, 7, 10, 35],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "雷电交加的险峻山关",
	},

	# =====================================================================
	# ELVEN DOMAIN (IDs 9–13) — northwest area
	# =====================================================================
	# 9: 世界树圣地 (capital)
	{
		"id": 9,
		"name": "世界树圣地",
		"nation_id": "elven_domain",
		"nation_name": "精灵领地",
		"position": Vector2(250, 120),
		"type": "FORTRESS",
		"terrain": "FOREST",
		"faction": "HIGH_ELF",
		"garrison_base": 12,
		"city_def": 30,
		"level": 3,
		"connections": [10, 11, 5, 1],
		"is_capital": true,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "高等精灵的神圣世界树所在地",
	},
	# 10: 白石村
	{
		"id": 10,
		"name": "白石村",
		"nation_id": "elven_domain",
		"nation_name": "精灵领地",
		"position": Vector2(350, 210),
		"type": "VILLAGE",
		"terrain": "FOREST",
		"faction": "HIGH_ELF",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [9, 11, 12, 8],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "以白色岩石闻名的精灵小村",
	},
	# 11: 鹿角镇
	{
		"id": 11,
		"name": "鹿角镇",
		"nation_id": "elven_domain",
		"nation_name": "精灵领地",
		"position": Vector2(180, 230),
		"type": "VILLAGE",
		"terrain": "FOREST",
		"faction": "HIGH_ELF",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [9, 10, 13, 36],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "精灵猎手聚居的林间市镇",
	},
	# 12: 霜风哨
	{
		"id": 12,
		"name": "霜风哨",
		"nation_id": "elven_domain",
		"nation_name": "精灵领地",
		"position": Vector2(420, 160),
		"type": "OUTPOST",
		"terrain": "FOREST",
		"faction": "HIGH_ELF",
		"garrison_base": 7,
		"city_def": 15,
		"level": 2,
		"connections": [10, 31, 37],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "精灵领地东部边境的哨塔",
	},
	# 13: 月影关
	{
		"id": 13,
		"name": "月影关",
		"nation_id": "elven_domain",
		"nation_name": "精灵领地",
		"position": Vector2(130, 340),
		"type": "OUTPOST",
		"terrain": "FOREST",
		"faction": "HIGH_ELF",
		"garrison_base": 7,
		"city_def": 15,
		"level": 2,
		"connections": [11, 28, 36, 38],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "通往暗精灵领地的月影要关",
	},

	# =====================================================================
	# MAGE ALLIANCE (IDs 14–18) — south-center area
	# =====================================================================
	# 14: 奥术堡垒 (capital)
	{
		"id": 14,
		"name": "奥术堡垒",
		"nation_id": "mage_alliance",
		"nation_name": "法师联盟",
		"position": Vector2(960, 680),
		"type": "FORTRESS",
		"terrain": "MOUNTAIN",
		"faction": "MAGE",
		"garrison_base": 12,
		"city_def": 30,
		"level": 3,
		"connections": [6, 15, 16, 17, 39],
		"is_capital": true,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "法师联盟的魔法堡垒，奥术能量汇聚之所",
	},
	# 15: 翡翠尖塔
	{
		"id": 15,
		"name": "翡翠尖塔",
		"nation_id": "mage_alliance",
		"nation_name": "法师联盟",
		"position": Vector2(1100, 750),
		"type": "FORTRESS",
		"terrain": "MOUNTAIN",
		"faction": "MAGE",
		"garrison_base": 8,
		"city_def": 25,
		"level": 3,
		"connections": [14, 18, 40, 24],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "散发翠绿光芒的法师高塔",
	},
	# 16: 云雾庄
	{
		"id": 16,
		"name": "云雾庄",
		"nation_id": "mage_alliance",
		"nation_name": "法师联盟",
		"position": Vector2(880, 760),
		"type": "VILLAGE",
		"terrain": "MOUNTAIN",
		"faction": "MAGE",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [14, 17, 41],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "常年被云雾笼罩的宁静村庄",
	},
	# 17: 龙脊要塞
	{
		"id": 17,
		"name": "龙脊要塞",
		"nation_id": "mage_alliance",
		"nation_name": "法师联盟",
		"position": Vector2(800, 680),
		"type": "OUTPOST",
		"terrain": "MOUNTAIN",
		"faction": "MAGE",
		"garrison_base": 8,
		"city_def": 20,
		"level": 2,
		"connections": [14, 16, 42, 22],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "建于龙脊山上的要塞，扼守西方通路",
	},
	# 18: 星落堡
	{
		"id": 18,
		"name": "星落堡",
		"nation_id": "mage_alliance",
		"nation_name": "法师联盟",
		"position": Vector2(1200, 820),
		"type": "OUTPOST",
		"terrain": "MOUNTAIN",
		"faction": "MAGE",
		"garrison_base": 7,
		"city_def": 15,
		"level": 2,
		"connections": [15, 43, 25],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "传说中星辰坠落之处修建的堡垒",
	},

	# =====================================================================
	# ORC HORDE (IDs 19–23) — west-center area
	# =====================================================================
	# 19: 碎骨王座 (capital)
	{
		"id": 19,
		"name": "碎骨王座",
		"nation_id": "orc_horde",
		"nation_name": "兽人部落",
		"position": Vector2(280, 580),
		"type": "FORTRESS",
		"terrain": "WASTELAND",
		"faction": "ORC",
		"garrison_base": 12,
		"city_def": 35,
		"level": 3,
		"connections": [20, 21, 22, 44],
		"is_capital": true,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "兽人部落的血腥王座，由无数战利品堆砌",
	},
	# 20: 红叶镇
	{
		"id": 20,
		"name": "红叶镇",
		"nation_id": "orc_horde",
		"nation_name": "兽人部落",
		"position": Vector2(350, 650),
		"type": "VILLAGE",
		"terrain": "WASTELAND",
		"faction": "ORC",
		"garrison_base": 4,
		"city_def": 5,
		"level": 1,
		"connections": [19, 21, 23],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "兽人占领的边境小镇",
	},
	# 21: 焦土堡
	{
		"id": 21,
		"name": "焦土堡",
		"nation_id": "orc_horde",
		"nation_name": "兽人部落",
		"position": Vector2(200, 680),
		"type": "OUTPOST",
		"terrain": "WASTELAND",
		"faction": "ORC",
		"garrison_base": 7,
		"city_def": 15,
		"level": 2,
		"connections": [19, 20, 23, 45],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "焦黑土地上的兽人据点",
	},
	# 22: 血牙关
	{
		"id": 22,
		"name": "血牙关",
		"nation_id": "orc_horde",
		"nation_name": "兽人部落",
		"position": Vector2(450, 560),
		"type": "OUTPOST",
		"terrain": "MOUNTAIN",
		"faction": "ORC",
		"garrison_base": 8,
		"city_def": 20,
		"level": 2,
		"connections": [19, 17, 29, 46],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "兽人与其他势力交界的血腥关隘",
	},
	# 23: 熔岩裂隙
	{
		"id": 23,
		"name": "熔岩裂隙",
		"nation_id": "orc_horde",
		"nation_name": "兽人部落",
		"position": Vector2(300, 760),
		"type": "OUTPOST",
		"terrain": "VOLCANIC",
		"faction": "ORC",
		"garrison_base": 6,
		"city_def": 10,
		"level": 1,
		"connections": [20, 21, 47],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "shadow",
		"description": "涌出熔岩的大地裂缝，暗影能量丰富",
	},

	# =====================================================================
	# PIRATE COALITION (IDs 24–27) — southeast area
	# =====================================================================
	# 24: 深渊港 (capital)
	{
		"id": 24,
		"name": "深渊港",
		"nation_id": "pirate_coalition",
		"nation_name": "海盗联盟",
		"position": Vector2(1500, 880),
		"type": "FORTRESS",
		"terrain": "RIVER",
		"faction": "PIRATE",
		"garrison_base": 10,
		"city_def": 25,
		"level": 3,
		"connections": [15, 25, 26, 48],
		"is_capital": true,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "海盗势力的深水港口，黑帆遮天蔽日",
	},
	# 25: 碧水村
	{
		"id": 25,
		"name": "碧水村",
		"nation_id": "pirate_coalition",
		"nation_name": "海盗联盟",
		"position": Vector2(1400, 950),
		"type": "VILLAGE",
		"terrain": "RIVER",
		"faction": "PIRATE",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [24, 18, 27],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "靠水吃水的渔村，暗地里走私猖獗",
	},
	# 26: 暗礁塔
	{
		"id": 26,
		"name": "暗礁塔",
		"nation_id": "pirate_coalition",
		"nation_name": "海盗联盟",
		"position": Vector2(1650, 830),
		"type": "OUTPOST",
		"terrain": "RIVER",
		"faction": "PIRATE",
		"garrison_base": 7,
		"city_def": 15,
		"level": 2,
		"connections": [24, 27, 49],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "暗礁密布的海域中矗立的灯塔据点",
	},
	# 27: 霜牙港
	{
		"id": 27,
		"name": "霜牙港",
		"nation_id": "pirate_coalition",
		"nation_name": "海盗联盟",
		"position": Vector2(1600, 970),
		"type": "OUTPOST",
		"terrain": "RIVER",
		"faction": "PIRATE",
		"garrison_base": 8,
		"city_def": 20,
		"level": 2,
		"connections": [25, 26, 50],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "寒冷海域中的海盗据点",
	},

	# =====================================================================
	# DARK ELF CLAN (IDs 28–30) — north-center area
	# =====================================================================
	# 28: 永夜暗城 (capital)
	{
		"id": 28,
		"name": "永夜暗城",
		"nation_id": "dark_elf_clan",
		"nation_name": "暗精灵一族",
		"position": Vector2(550, 350),
		"type": "FORTRESS",
		"terrain": "SWAMP",
		"faction": "DARK_ELF",
		"garrison_base": 14,
		"city_def": 40,
		"level": 3,
		"connections": [2, 13, 29, 30, 51],
		"is_capital": true,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "暗精灵的黑暗城堡，永远笼罩在夜幕之中",
	},
	# 29: 松风庄
	{
		"id": 29,
		"name": "松风庄",
		"nation_id": "dark_elf_clan",
		"nation_name": "暗精灵一族",
		"position": Vector2(500, 450),
		"type": "VILLAGE",
		"terrain": "SWAMP",
		"faction": "DARK_ELF",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [28, 22, 30, 46],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "暗精灵的隐秘村落",
	},
	# 30: 月影祭坛
	{
		"id": 30,
		"name": "月影祭坛",
		"nation_id": "dark_elf_clan",
		"nation_name": "暗精灵一族",
		"position": Vector2(650, 420),
		"type": "OUTPOST",
		"terrain": "SWAMP",
		"faction": "DARK_ELF",
		"garrison_base": 7,
		"city_def": 15,
		"level": 2,
		"connections": [28, 29, 33, 52],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "暗精灵举行秘仪的月影祭坛",
	},

	# =====================================================================
	# NEUTRAL LANDS (IDs 31–54) — 24 territories scattered across map
	# =====================================================================

	# --- 6 Neutral Settlements (31-36) ---
	# 31: 行商驿站
	{
		"id": 31,
		"name": "行商驿站",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(700, 180),
		"type": "VILLAGE",
		"terrain": "PLAINS",
		"faction": "NEUTRAL",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [2, 12, 37],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "南来北往的行商歇脚之地",
	},
	# 32: 枯骨墓穴
	{
		"id": 32,
		"name": "枯骨墓穴",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(750, 520),
		"type": "VILLAGE",
		"terrain": "WASTELAND",
		"faction": "NEUTRAL",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [42, 46, 52],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "满是枯骨的古老墓穴",
	},
	# 33: 绿影营地
	{
		"id": 33,
		"name": "绿影营地",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(850, 420),
		"type": "VILLAGE",
		"terrain": "FOREST",
		"faction": "NEUTRAL",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [6, 30, 34, 39],
		"is_capital": false,
		"is_chokepoint": true,
		"resource_type": "",
		"description": "游侠和冒险者的临时营地",
	},
	# 34: 地精工坊
	{
		"id": 34,
		"name": "地精工坊",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(1100, 450),
		"type": "VILLAGE",
		"terrain": "MOUNTAIN",
		"faction": "NEUTRAL",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [7, 33, 35, 40],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "地精工匠聚集的作坊",
	},
	# 35: 流浪马戏团
	{
		"id": 35,
		"name": "流浪马戏团",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(1350, 480),
		"type": "VILLAGE",
		"terrain": "PLAINS",
		"faction": "NEUTRAL",
		"garrison_base": 2,
		"city_def": 5,
		"level": 1,
		"connections": [8, 34, 49],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "四处流浪的马戏团驻扎地",
	},
	# 36: 赏金猎人公会
	{
		"id": 36,
		"name": "赏金猎人公会",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(150, 450),
		"type": "VILLAGE",
		"terrain": "WALL",
		"faction": "NEUTRAL",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [11, 13, 38, 44],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "赏金猎人接取任务的公会大厅",
	},

	# --- 10 Bandit Lairs (37-46) ---
	# 37: 黑风寨
	{
		"id": 37,
		"name": "黑风寨",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(580, 180),
		"type": "BANDIT",
		"terrain": "MOUNTAIN",
		"faction": "NEUTRAL",
		"garrison_base": 5,
		"city_def": 10,
		"level": 1,
		"connections": [12, 31, 51],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "山间巨匪的老巢",
	},
	# 38: 落日盗窟
	{
		"id": 38,
		"name": "落日盗窟",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(200, 400),
		"type": "BANDIT",
		"terrain": "WASTELAND",
		"faction": "NEUTRAL",
		"garrison_base": 5,
		"city_def": 10,
		"level": 1,
		"connections": [13, 36, 44],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "落日余晖下的盗贼窝点",
	},
	# 39: 毒蛇谷
	{
		"id": 39,
		"name": "毒蛇谷",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(900, 550),
		"type": "BANDIT",
		"terrain": "SWAMP",
		"faction": "NEUTRAL",
		"garrison_base": 5,
		"city_def": 10,
		"level": 1,
		"connections": [14, 33, 42],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "毒蛇出没的危险山谷",
	},
	# 40: 暗影巢穴
	{
		"id": 40,
		"name": "暗影巢穴",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(1200, 580),
		"type": "BANDIT",
		"terrain": "FOREST",
		"faction": "NEUTRAL",
		"garrison_base": 5,
		"city_def": 10,
		"level": 1,
		"connections": [15, 34, 43],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "藏在暗影中的盗贼巢穴",
	},
	# 41: 断牙山寨
	{
		"id": 41,
		"name": "断牙山寨",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(750, 850),
		"type": "BANDIT",
		"terrain": "MOUNTAIN",
		"faction": "NEUTRAL",
		"garrison_base": 5,
		"city_def": 10,
		"level": 1,
		"connections": [16, 47, 53],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "山间匪寨，守险据要",
	},
	# 42: 腐沼堡
	{
		"id": 42,
		"name": "腐沼堡",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(700, 600),
		"type": "BANDIT",
		"terrain": "SWAMP",
		"faction": "NEUTRAL",
		"garrison_base": 5,
		"city_def": 10,
		"level": 1,
		"connections": [17, 32, 39],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "建在腐烂沼泽上的匪寨",
	},
	# 43: 秃鹫岭
	{
		"id": 43,
		"name": "秃鹫岭",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(1300, 700),
		"type": "BANDIT",
		"terrain": "WASTELAND",
		"faction": "NEUTRAL",
		"garrison_base": 5,
		"city_def": 10,
		"level": 1,
		"connections": [18, 40, 48],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "秃鹫盘旋的荒凉山岭",
	},
	# 44: 海盗湾
	{
		"id": 44,
		"name": "海盗湾",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(250, 480),
		"type": "BANDIT",
		"terrain": "RIVER",
		"faction": "NEUTRAL",
		"garrison_base": 5,
		"city_def": 10,
		"level": 1,
		"connections": [19, 36, 38],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "内河海盗的秘密港湾",
	},
	# 45: 鬼火林
	{
		"id": 45,
		"name": "鬼火林",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(150, 750),
		"type": "BANDIT",
		"terrain": "FOREST",
		"faction": "NEUTRAL",
		"garrison_base": 5,
		"city_def": 10,
		"level": 1,
		"connections": [21, 47, 54],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "鬼火飘忽不定的阴森树林",
	},
	# 46: 噬骨洞
	{
		"id": 46,
		"name": "噬骨洞",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(600, 530),
		"type": "BANDIT",
		"terrain": "MOUNTAIN",
		"faction": "NEUTRAL",
		"garrison_base": 5,
		"city_def": 10,
		"level": 1,
		"connections": [22, 29, 32],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "",
		"description": "传说能吞噬骸骨的恐怖洞穴",
	},

	# --- 9 Resource Stations (47-54) + 1 Event (the 9th resource fills 54) ---
	# 47: 魔晶矿脉
	{
		"id": 47,
		"name": "魔晶矿脉",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(450, 850),
		"type": "RESOURCE",
		"terrain": "MOUNTAIN",
		"faction": "NEUTRAL",
		"garrison_base": 4,
		"city_def": 5,
		"level": 1,
		"connections": [23, 41, 45, 53],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "crystal",
		"description": "蕴含丰富魔晶的矿脉",
	},
	# 48: 战马牧场
	{
		"id": 48,
		"name": "战马牧场",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(1400, 750),
		"type": "RESOURCE",
		"terrain": "PLAINS",
		"faction": "NEUTRAL",
		"garrison_base": 4,
		"city_def": 5,
		"level": 1,
		"connections": [24, 43, 50],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "horse",
		"description": "培育优良战马的广阔牧场",
	},
	# 49: 铁矿场
	{
		"id": 49,
		"name": "铁矿场",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(1550, 550),
		"type": "RESOURCE",
		"terrain": "MOUNTAIN",
		"faction": "NEUTRAL",
		"garrison_base": 4,
		"city_def": 5,
		"level": 1,
		"connections": [26, 35, 50],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "crystal",
		"description": "产出精铁的矿场",
	},
	# 50: 药草园
	{
		"id": 50,
		"name": "药草园",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(1650, 700),
		"type": "RESOURCE",
		"terrain": "FOREST",
		"faction": "NEUTRAL",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [27, 48, 49],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "horse",
		"description": "种植珍稀药材的园圃",
	},
	# 51: 灵木林场
	{
		"id": 51,
		"name": "灵木林场",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(550, 250),
		"type": "RESOURCE",
		"terrain": "FOREST",
		"faction": "NEUTRAL",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [28, 37, 52],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "shadow",
		"description": "生长灵木的古老林场",
	},
	# 52: 硫磺泉
	{
		"id": 52,
		"name": "硫磺泉",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(700, 450),
		"type": "RESOURCE",
		"terrain": "SWAMP",
		"faction": "NEUTRAL",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [30, 32, 51],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "gunpowder",
		"description": "散发硫磺气味的温泉",
	},
	# 53: 宝石洞
	{
		"id": 53,
		"name": "宝石洞",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(600, 900),
		"type": "RESOURCE",
		"terrain": "MOUNTAIN",
		"faction": "NEUTRAL",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [41, 47, 54],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "crystal",
		"description": "蕴藏宝石的天然洞穴",
	},
	# 54: 魔铁锻炉
	{
		"id": 54,
		"name": "魔铁锻炉",
		"nation_id": "neutral",
		"nation_name": "中立地带",
		"position": Vector2(250, 880),
		"type": "RESOURCE",
		"terrain": "VOLCANIC",
		"faction": "NEUTRAL",
		"garrison_base": 3,
		"city_def": 5,
		"level": 1,
		"connections": [45, 53],
		"is_capital": false,
		"is_chokepoint": false,
		"resource_type": "gunpowder",
		"description": "利用地热锻造魔铁的锻炉",
	},
]

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Return all territory IDs belonging to a given nation.
static func get_nation_territory_ids(nation_id: String) -> Array:
	var result: Array = []
	for t in TERRITORIES:
		if t["nation_id"] == nation_id:
			result.append(t["id"])
	return result

## Return the capital territory for a given nation, or null.
static func get_nation_capital(nation_id: String) -> Variant:
	for t in TERRITORIES:
		if t["nation_id"] == nation_id and t["is_capital"]:
			return t
	return null

## Return all chokepoint territories.
static func get_chokepoints() -> Array:
	var result: Array = []
	for t in TERRITORIES:
		if t["is_chokepoint"]:
			result.append(t)
	return result

## Build the full adjacency dictionary {id: [connected_ids]}.
static func build_adjacency() -> Dictionary:
	var adj: Dictionary = {}
	for t in TERRITORIES:
		adj[t["id"]] = t["connections"].duplicate()
	return adj

## Validate the map data: check 55 territories, connectivity, and symmetry.
static func validate() -> Array:
	var errors: Array = []
	# Check count
	if TERRITORIES.size() != 55:
		errors.append("Expected 55 territories, got %d" % TERRITORIES.size())
	# Check IDs are 0..54
	var id_set: Dictionary = {}
	for t in TERRITORIES:
		if id_set.has(t["id"]):
			errors.append("Duplicate ID: %d" % t["id"])
		id_set[t["id"]] = true
	for i in range(55):
		if not id_set.has(i):
			errors.append("Missing ID: %d" % i)
	# Check symmetric adjacency
	for t in TERRITORIES:
		for conn_id in t["connections"]:
			if conn_id < 0 or conn_id >= 55:
				errors.append("Territory %d has invalid connection %d" % [t["id"], conn_id])
				continue
			var found: bool = false
			for t2 in TERRITORIES:
				if t2["id"] == conn_id:
					if t["id"] in t2["connections"]:
						found = true
					break
			if not found:
				errors.append("Asymmetric connection: %d -> %d" % [t["id"], conn_id])
	# Check full connectivity via BFS
	if TERRITORIES.size() > 0:
		var adj: Dictionary = build_adjacency()
		var visited: Dictionary = {}
		var queue: Array = [0]
		visited[0] = true
		while queue.size() > 0:
			var current: int = queue.pop_front()
			for nb in adj.get(current, []):
				if not visited.has(nb):
					visited[nb] = true
					queue.append(nb)
		if visited.size() != 55:
			errors.append("Graph not fully connected: only %d / 55 reachable from node 0" % visited.size())
	return errors
