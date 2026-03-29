## building_registry.gd - Central registry for common + faction-unique + terrain buildings (v0.8.3)
## All buildings now support 3 levels. Terrain/tile-type requirements added.
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Common buildings (available to all factions, 3 levels each) ──
const COMMON_BUILDINGS: Dictionary = {
	"slave_market": {
		"name": "奴隶市场",
		"max_level": 3,
		"levels": {
			1: {"cost": {"gold": 100, "iron": 8}, "desc": "+2奴隶/回合", "effects": {"slaves_per_turn": 2}},
			2: {"cost": {"gold": 150, "iron": 12}, "desc": "+3奴隶/回合 + 交易", "effects": {"slaves_per_turn": 3, "trade_unlock": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 200, "iron": 18}, "desc": "+5奴隶/回合", "effects": {"slaves_per_turn": 5}, "upgrade_req": {"tile_level": 3, "order_min": 60}},
		},
	},
	"labor_camp": {
		"name": "苦役营",
		"max_level": 3,
		"levels": {
			1: {"cost": {"gold": 150, "iron": 15}, "desc": "奴隶劳动+1粮+0.5铁", "effects": {"food_bonus": 1.0, "iron_bonus": 0.5}},
			2: {"cost": {"gold": 200, "iron": 20}, "desc": "+50%产出", "effects": {"food_bonus": 1.5, "iron_bonus": 0.75}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 250, "iron": 25}, "desc": "双倍产出+物品", "effects": {"food_bonus": 2.0, "iron_bonus": 1.0, "item_drop": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"arena": {
		"name": "竞技场",
		"max_level": 3,
		"levels": {
			1: {"cost": {"gold": 120, "iron": 12}, "desc": "消耗1奴隶/回合 +3攻", "effects": {"slave_consume": 1, "atk_bonus": 3, "def_bonus": 0}},
			2: {"cost": {"gold": 180, "iron": 18}, "desc": "+5攻 +2防", "effects": {"slave_consume": 1, "atk_bonus": 5, "def_bonus": 2}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 240, "iron": 24}, "desc": "+8攻+防", "effects": {"slave_consume": 2, "atk_bonus": 8, "def_bonus": 8}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"training_ground": {
		"name": "训练场",
		"max_level": 3,
		"levels": {
			1: {"cost": {"gold": 100, "iron": 15}, "desc": "招募-10金 +3攻", "effects": {"recruit_discount": 10, "atk_bonus": 3, "def_bonus": 0}},
			2: {"cost": {"gold": 160, "iron": 20}, "desc": "-20金 +5攻/防", "effects": {"recruit_discount": 20, "atk_bonus": 5, "def_bonus": 5}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 220, "iron": 28}, "desc": "-30金 +8攻/防", "effects": {"recruit_discount": 30, "atk_bonus": 8, "def_bonus": 8, "free_troop_interval": 3}, "upgrade_req": {"tile_level": 3}},
		},
	},
	# v0.8.3: New common buildings
	"fortification": {
		"name": "城防工事",
		"max_level": 3,
		"levels": {
			1: {"cost": {"gold": 80, "iron": 20}, "desc": "驻军DEF+3, 城防+10", "effects": {"def_bonus": 3, "wall_hp_bonus": 10}},
			2: {"cost": {"gold": 140, "iron": 30}, "desc": "DEF+5, 城防+20, 修复+2/回合", "effects": {"def_bonus": 5, "wall_hp_bonus": 20, "wall_repair_per_turn": 2}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 220, "iron": 45}, "desc": "DEF+8, 城防+35, 修复+5/回合", "effects": {"def_bonus": 8, "wall_hp_bonus": 35, "wall_repair_per_turn": 5}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"warehouse": {
		"name": "仓库",
		"max_level": 3,
		"levels": {
			1: {"cost": {"gold": 80, "iron": 10}, "desc": "补给线惩罚-1, 储备粮+10", "effects": {"supply_penalty_reduction": 1, "food_storage": 10}},
			2: {"cost": {"gold": 130, "iron": 15}, "desc": "补给线惩罚-2, 储备粮+25", "effects": {"supply_penalty_reduction": 2, "food_storage": 25}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 200, "iron": 22}, "desc": "免补给惩罚, 储备粮+50, 贸易折扣10%", "effects": {"supply_penalty_reduction": 99, "food_storage": 50, "trade_discount": 0.10}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"merchant_guild": {
		"name": "商会",
		"max_level": 3,
		"levels": {
			1: {"cost": {"gold": 120, "iron": 5}, "desc": "+5金/回合", "effects": {"gold_per_turn": 5}},
			2: {"cost": {"gold": 180, "iron": 8}, "desc": "+10金/回合, 贸易折扣15%", "effects": {"gold_per_turn": 10, "trade_discount": 0.15}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 260, "iron": 12}, "desc": "+18金/回合, 折扣25%, 可交易战略资源", "effects": {"gold_per_turn": 18, "trade_discount": 0.25, "strategic_trade": true}, "upgrade_req": {"tile_level": 3, "order_min": 50}},
		},
	},
	# v0.8.3: Research buildings
	"academy": {
		"name": "学院",
		"max_level": 3,
		"levels": {
			1: {"cost": {"gold": 200, "iron": 20}, "desc": "解锁研究, 研究速度+25%", "effects": {"research_unlock": true, "research_speed": 0.25}},
			2: {"cost": {"gold": 350, "iron": 35}, "desc": "速度+50%, 可排队2项", "effects": {"research_speed": 0.50, "queue_size": 2}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 500, "iron": 50}, "desc": "速度+100%, 排队3项, 研究费-10%", "effects": {"research_speed": 1.0, "queue_size": 3, "research_discount": 0.10}, "upgrade_req": {"tile_level": 3, "order_min": 40}},
		},
	},
	"war_college": {
		"name": "兵法研究所",
		"max_level": 3,
		"levels": {
			1: {"cost": {"gold": 180, "iron": 25}, "desc": "军事科技速度+15%, 驻军经验+10%", "effects": {"military_research_speed": 0.15, "garrison_exp_bonus": 0.10}},
			2: {"cost": {"gold": 300, "iron": 40}, "desc": "军事速度+30%, 经验+20%, 战术模拟", "effects": {"military_research_speed": 0.30, "garrison_exp_bonus": 0.20, "tactical_sim": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 450, "iron": 55}, "desc": "军事速度+50%, 经验+30%, 精锐训练", "effects": {"military_research_speed": 0.50, "garrison_exp_bonus": 0.30, "elite_training": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"arcane_institute": {
		"name": "魔导研究院",
		"max_level": 3,
		"levels": {
			1: {"cost": {"gold": 200, "iron": 15, "magic_crystal": 1}, "desc": "奥术科技速度+15%, 术师ATK+2", "effects": {"arcane_research_speed": 0.15, "mage_atk_bonus": 2}},
			2: {"cost": {"gold": 350, "iron": 25, "magic_crystal": 2}, "desc": "奥术速度+30%, 术师ATK+4, 魔晶效率+20%", "effects": {"arcane_research_speed": 0.30, "mage_atk_bonus": 4, "crystal_efficiency": 1.20}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 500, "iron": 35, "magic_crystal": 3}, "desc": "奥术速度+50%, 术师ATK+6, 法力再生+2/回合", "effects": {"arcane_research_speed": 0.50, "mage_atk_bonus": 6, "mana_regen": 2}, "upgrade_req": {"tile_level": 3}},
		},
	},
	# v5.0: Strategic depth buildings
	"supply_depot": {
		"name": "兵站",
		"max_level": 2,
		"levels": {
			1: {"cost": {"gold": 200, "iron": 50}, "desc": "补给范围+2格, 驻军恢复+5/回合", "effects": {"supply_range": 2, "garrison_recovery": 5}},
			2: {"cost": {"gold": 350, "iron": 80}, "desc": "补给范围+3格, 驻军恢复+10/回合", "effects": {"supply_range": 3, "garrison_recovery": 10}, "upgrade_req": {"tile_level": 2}},
		},
	},
	"watchtower": {
		"name": "望楼",
		"max_level": 2,
		"levels": {
			1: {"cost": {"gold": 100, "iron": 30}, "desc": "视野+3格, 拦截率+15%", "effects": {"vision_range": 3, "interception_bonus": 15}},
			2: {"cost": {"gold": 180, "iron": 50}, "desc": "视野+4格, 拦截率+25%, 预警", "effects": {"vision_range": 4, "interception_bonus": 25, "early_warning": true}, "upgrade_req": {"tile_level": 2}},
		},
	},
}

# ── Faction-specific buildings (3 levels each, 2 per faction) ──
static var FACTION_BUILDINGS: Dictionary = {
	FactionData.FactionID.ORC: {
		"totem_pole": {
			"name": "图腾柱",
			"max_level": 3,
			"levels": {
				1: {"cost": {"gold": 80, "iron": 10}, "desc": "+5 WAAAGH!/回合", "effects": {"waaagh_per_turn": 5}},
				2: {"cost": {"gold": 130, "iron": 16}, "desc": "+8 WAAAGH! 狂暴+1回合", "effects": {"waaagh_per_turn": 8, "extra_frenzy_turn": 1}, "upgrade_req": {"tile_level": 2}},
				3: {"cost": {"gold": 200, "iron": 24}, "desc": "+12 WAAAGH! 损失→10%", "effects": {"waaagh_per_turn": 12, "loss_reduction": 0.10}, "upgrade_req": {"tile_level": 3, "waaagh_triggers_min": 3}},
			},
		},
		"war_pit": {
			"name": "战争深坑",
			"max_level": 3,
			"levels": {
				1: {"cost": {"gold": 80, "iron": 15}, "desc": "消耗1奴隶→3军队", "effects": {"slave_to_army": 3, "slave_consume": 1}},
				2: {"cost": {"gold": 140, "iron": 22}, "desc": "1奴隶→4军队, ATK+2", "effects": {"slave_to_army": 4, "slave_consume": 1, "atk_bonus": 2}, "upgrade_req": {"tile_level": 2}},
				3: {"cost": {"gold": 200, "iron": 30}, "desc": "1奴隶→5军队, ATK+4, 巨魔解锁", "effects": {"slave_to_army": 5, "slave_consume": 1, "atk_bonus": 4, "unlock_troll": true}, "upgrade_req": {"tile_level": 3}},
			},
		},
	},
	FactionData.FactionID.PIRATE: {
		"black_market": {
			"name": "黑市",
			"max_level": 3,
			"levels": {
				1: {"cost": {"gold": 90, "iron": 6}, "desc": "交易+1物品/回合", "effects": {"trade_bonus": true, "items_per_turn": 1}},
				2: {"cost": {"gold": 140, "iron": 10}, "desc": "更好价格+2物品", "effects": {"trade_bonus": true, "items_per_turn": 2, "better_rates": true}, "upgrade_req": {"tile_level": 2}},
				3: {"cost": {"gold": 200, "iron": 16}, "desc": "最佳价格+遗物", "effects": {"trade_bonus": true, "items_per_turn": 3, "relic_drop": true}, "upgrade_req": {"tile_level": 3, "plunder_min": 30}},
			},
		},
		"smugglers_den": {
			"name": "走私者巢穴",
			"max_level": 3,
			"levels": {
				1: {"cost": {"gold": 70, "iron": 5}, "desc": "+5金/回合, 战利品+30%", "effects": {"gold_per_turn": 5, "loot_mult": 1.3}},
				2: {"cost": {"gold": 160, "iron": 14}, "desc": "+10金/回合, 战利品+60%, 走私路线", "effects": {"gold_per_turn": 10, "loot_mult": 1.6, "smuggle_route": true}, "upgrade_req": {"tile_level": 2}},
				3: {"cost": {"gold": 230, "iron": 20}, "desc": "+18金/回合, 战利品×2, 掠夺值×1.5", "effects": {"gold_per_turn": 18, "loot_mult": 2.0, "plunder_mult": 1.5}, "upgrade_req": {"tile_level": 3, "plunder_min": 50}},
			},
		},
	},
	FactionData.FactionID.DARK_ELF: {
		"temple_of_agony": {
			"name": "痛苦神殿",
			"max_level": 3,
			"levels": {
				1: {"cost": {"gold": 100, "iron": 12}, "desc": "开启祭坛", "effects": {"altar_unlock": true, "altar_mult": 1.0}},
				2: {"cost": {"gold": 160, "iron": 18}, "desc": "+50%祭坛效果", "effects": {"altar_mult": 1.5}, "upgrade_req": {"tile_level": 2}},
				3: {"cost": {"gold": 220, "iron": 25}, "desc": "双倍祭坛+痛苦仪式", "effects": {"altar_mult": 2.0, "pain_ritual": true}, "upgrade_req": {"tile_level": 3, "slaves_min": 10}},
			},
		},
		"slave_pit": {
			"name": "奴隶深坑",
			"max_level": 3,
			"levels": {
				1: {"cost": {"gold": 80, "iron": 10}, "desc": "奴隶效率+50%, 容量+3", "effects": {"slave_efficiency": 1.5, "slave_capacity": 3}},
				2: {"cost": {"gold": 140, "iron": 16}, "desc": "效率+80%, 容量+5, 暗影精华+1/回合", "effects": {"slave_efficiency": 1.8, "slave_capacity": 5, "shadow_essence_per_turn": 1}, "upgrade_req": {"tile_level": 2}},
				3: {"cost": {"gold": 210, "iron": 24}, "desc": "效率×2, 容量+8, 精华+2, 冷蜥解锁", "effects": {"slave_efficiency": 2.0, "slave_capacity": 8, "shadow_essence_per_turn": 2, "unlock_cold_lizard": true}, "upgrade_req": {"tile_level": 3, "slaves_min": 15}},
			},
		},
	},
}

# ── Terrain-specific buildings (v0.8.3, require matching terrain type) ──
static var TERRAIN_BUILDINGS: Dictionary = {
	"port_facility": {
		"name": "港口设施",
		"max_level": 3,
		"terrain_req": FactionData.TerrainType.COASTAL,
		"levels": {
			1: {"cost": {"gold": 100, "iron": 10}, "desc": "+3金+2粮/回合, 海路连接", "effects": {"gold_per_turn": 3, "food_per_turn": 2, "sea_route": true}},
			2: {"cost": {"gold": 160, "iron": 16}, "desc": "+6金+4粮, 海路贸易折扣", "effects": {"gold_per_turn": 6, "food_per_turn": 4, "trade_discount": 0.15}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 240, "iron": 24}, "desc": "+10金+6粮, 海军召唤", "effects": {"gold_per_turn": 10, "food_per_turn": 6, "naval_unit": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"mountain_fortress": {
		"name": "山寨",
		"max_level": 3,
		"terrain_req": FactionData.TerrainType.MOUNTAIN,
		"levels": {
			1: {"cost": {"gold": 90, "iron": 25}, "desc": "DEF+5, 驻军+3, 视野+1", "effects": {"def_bonus": 5, "garrison_bonus": 3, "visibility_bonus": 1}},
			2: {"cost": {"gold": 150, "iron": 35}, "desc": "DEF+8, 驻军+5, 攻击者ATK-10%", "effects": {"def_bonus": 8, "garrison_bonus": 5, "attacker_atk_penalty": 0.10}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 220, "iron": 50}, "desc": "DEF+12, 驻军+8, 攻击者ATK-20%, 投石", "effects": {"def_bonus": 12, "garrison_bonus": 8, "attacker_atk_penalty": 0.20, "siege_defense": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"forest_trap": {
		"name": "林中陷阱",
		"max_level": 3,
		"terrain_req": FactionData.TerrainType.FOREST,
		"levels": {
			1: {"cost": {"gold": 60, "iron": 8}, "desc": "攻击者首轮损2兵", "effects": {"ambush_damage": 2}},
			2: {"cost": {"gold": 100, "iron": 14}, "desc": "首轮损3兵, 忍者ATK+20%", "effects": {"ambush_damage": 3, "ninja_atk_mult": 1.2}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 160, "iron": 20}, "desc": "首轮损5兵, 忍者ATK+40%, 20%混乱", "effects": {"ambush_damage": 5, "ninja_atk_mult": 1.4, "confusion_chance": 0.20}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"swamp_distillery": {
		"name": "瘴气炼金坊",
		"max_level": 3,
		"terrain_req": FactionData.TerrainType.SWAMP,
		"levels": {
			1: {"cost": {"gold": 70, "iron": 10}, "desc": "攻击方中毒-1兵/回合x2", "effects": {"poison_dot": 1, "poison_duration": 2}},
			2: {"cost": {"gold": 120, "iron": 16}, "desc": "毒-2兵/回合x2, 暗影精华+1/回合", "effects": {"poison_dot": 2, "poison_duration": 2, "shadow_essence_per_turn": 1}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 180, "iron": 24}, "desc": "毒-3兵/回合x3, 精华+2, 瘟疫扩散", "effects": {"poison_dot": 3, "poison_duration": 3, "shadow_essence_per_turn": 2, "plague_spread": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
}

# ── Tile-type-specific buildings (v0.8.3, require matching tile type) ──
const TILE_TYPE_BUILDINGS: Dictionary = {
	"watchtower_upgrade": {
		"name": "望远镜台",
		"max_level": 3,
		"tile_type_req": "WATCHTOWER",  # GameManager.TileType.WATCHTOWER
		"levels": {
			1: {"cost": {"gold": 60, "iron": 8}, "desc": "视野+1格, 揭示移动", "effects": {"visibility_bonus": 1, "detect_movement": true}},
			2: {"cost": {"gold": 100, "iron": 12}, "desc": "视野+2格, 揭示驻军", "effects": {"visibility_bonus": 2, "detect_garrison": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 160, "iron": 18}, "desc": "视野+3格, 全揭示, 预警1回合", "effects": {"visibility_bonus": 3, "full_reveal": true, "early_warning": 1}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"ruin_excavation": {
		"name": "遗迹发掘场",
		"max_level": 3,
		"tile_type_req": "RUINS",
		"levels": {
			1: {"cost": {"gold": 80, "iron": 5}, "desc": "每3回合发掘1次(道具/遗物)", "effects": {"excavate_interval": 3, "relic_chance": 0.10}},
			2: {"cost": {"gold": 130, "iron": 10}, "desc": "每2回合1次, 遗物率15%", "effects": {"excavate_interval": 2, "relic_chance": 0.15}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 200, "iron": 18}, "desc": "每回合1次, 遗物率25%, INT+2全军", "effects": {"excavate_interval": 1, "relic_chance": 0.25, "global_int_bonus": 2}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"chokepoint_bastion": {
		"name": "关隘要塞",
		"max_level": 3,
		"tile_type_req": "CHOKEPOINT",
		"levels": {
			1: {"cost": {"gold": 100, "iron": 30}, "desc": "DEF+6, 城防+15, 驻军+3", "effects": {"def_bonus": 6, "wall_hp_bonus": 15, "garrison_bonus": 3}},
			2: {"cost": {"gold": 170, "iron": 40}, "desc": "DEF+10, 城防+30, 驻军+5, 投石", "effects": {"def_bonus": 10, "wall_hp_bonus": 30, "garrison_bonus": 5, "siege_defense": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 250, "iron": 55}, "desc": "DEF+15, 城防+50, 驻军+8, 铁壁", "effects": {"def_bonus": 15, "wall_hp_bonus": 50, "garrison_bonus": 8, "iron_wall": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"harbor_market": {
		"name": "港口贸易所",
		"max_level": 3,
		"tile_type_req": "HARBOR",
		"levels": {
			1: {"cost": {"gold": 90, "iron": 5}, "desc": "+5金+3粮/回合", "effects": {"gold_per_turn": 5, "food_per_turn": 3}},
			2: {"cost": {"gold": 150, "iron": 10}, "desc": "+10金+5粮, 海盗兵种可招", "effects": {"gold_per_turn": 10, "food_per_turn": 5, "recruit_pirate_units": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 220, "iron": 16}, "desc": "+18金+8粮, 走私路线, 掠夺+5/回合", "effects": {"gold_per_turn": 18, "food_per_turn": 8, "plunder_per_turn": 5}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"trading_post_upgrade": {
		"name": "贸易站升级",
		"max_level": 3,
		"tile_type_req": "TRADING_POST",
		"levels": {
			1: {"cost": {"gold": 70, "iron": 5}, "desc": "+3金/回合, 物品折扣10%", "effects": {"gold_per_turn": 3, "item_discount": 0.10}},
			2: {"cost": {"gold": 120, "iron": 8}, "desc": "+6金, 折扣20%, 稀有商品", "effects": {"gold_per_turn": 6, "item_discount": 0.20, "rare_items": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 180, "iron": 12}, "desc": "+10金, 折扣30%, 黑市渠道, +1道具/回合", "effects": {"gold_per_turn": 10, "item_discount": 0.30, "items_per_turn": 1}, "upgrade_req": {"tile_level": 3}},
		},
	},
}

# ── Neutral faction buildings (v0.8.3, require recruited neutral faction) ──
static var NEUTRAL_BUILDINGS: Dictionary = {
	"dwarven_forge": {
		"name": "矮人锻造炉",
		"max_level": 3,
		"neutral_req": FactionData.NeutralFaction.IRONHAMMER_DWARF,
		"levels": {
			1: {"cost": {"gold": 120, "iron": 30}, "desc": "铁矿+2/回合, 装备质量+10%", "effects": {"iron_per_turn": 2, "equip_quality": 0.10}},
			2: {"cost": {"gold": 200, "iron": 45}, "desc": "铁矿+4, 质量+20%, 精锻武器", "effects": {"iron_per_turn": 4, "equip_quality": 0.20, "masterwork_arms": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 300, "iron": 60}, "desc": "铁矿+6, 质量+30%, 符文锻造", "effects": {"iron_per_turn": 6, "equip_quality": 0.30, "rune_forging": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"caravan_bazaar": {
		"name": "商队集市",
		"max_level": 3,
		"neutral_req": FactionData.NeutralFaction.WANDERING_CARAVAN,
		"levels": {
			1: {"cost": {"gold": 100, "iron": 5}, "desc": "+8金/回合, 每3回合免费道具", "effects": {"gold_per_turn": 8, "free_item_interval": 3}},
			2: {"cost": {"gold": 170, "iron": 8}, "desc": "+15金, 每2回合道具, 稀有商品", "effects": {"gold_per_turn": 15, "free_item_interval": 2, "rare_items": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 250, "iron": 12}, "desc": "+22金, 每回合道具, 战略资源交易", "effects": {"gold_per_turn": 22, "free_item_interval": 1, "strategic_trade": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"bone_tower": {
		"name": "亡骨高塔",
		"max_level": 3,
		"neutral_req": FactionData.NeutralFaction.NECROMANCER,
		"levels": {
			1: {"cost": {"gold": 110, "iron": 15}, "desc": "战后20%阵亡→骷髅兵, 暗影精华+1", "effects": {"reanimate_chance": 0.20, "shadow_per_turn": 1}},
			2: {"cost": {"gold": 180, "iron": 22}, "desc": "35%复活, 精华+2, 亡灵不消耗粮食", "effects": {"reanimate_chance": 0.35, "shadow_per_turn": 2, "undead_no_food": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 260, "iron": 30}, "desc": "50%复活, 精华+3, 死灵领域(DEF+5)", "effects": {"reanimate_chance": 0.50, "shadow_per_turn": 3, "necro_aura_def": 5}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"ranger_lodge": {
		"name": "游侠营地",
		"max_level": 3,
		"neutral_req": FactionData.NeutralFaction.FOREST_RANGER,
		"levels": {
			1: {"cost": {"gold": 80, "iron": 10}, "desc": "视野+2, 森林移动消耗-1AP", "effects": {"visibility_bonus": 2, "forest_move_discount": 1}},
			2: {"cost": {"gold": 140, "iron": 16}, "desc": "视野+3, 伏击成功率+20%, 游侠招募", "effects": {"visibility_bonus": 3, "ambush_bonus": 0.20, "recruit_ranger": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 210, "iron": 24}, "desc": "视野+4, 伏击+40%, 密林隐匿(敌侦查无效)", "effects": {"visibility_bonus": 4, "ambush_bonus": 0.40, "stealth_zone": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"blood_altar": {
		"name": "血月祭坛",
		"max_level": 3,
		"neutral_req": FactionData.NeutralFaction.BLOOD_MOON_CULT,
		"levels": {
			1: {"cost": {"gold": 100, "iron": 12}, "desc": "献祭1奴隶→全军ATK+2(1回合)", "effects": {"sacrifice_atk": 2, "sacrifice_duration": 1, "slave_consume": 1}},
			2: {"cost": {"gold": 170, "iron": 20}, "desc": "ATK+4持续2回合, 血月狂热(暴击+10%)", "effects": {"sacrifice_atk": 4, "sacrifice_duration": 2, "crit_bonus": 0.10, "slave_consume": 1}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 250, "iron": 28}, "desc": "ATK+6持续3回合, 暴击+20%, 血月降临(全图)", "effects": {"sacrifice_atk": 6, "sacrifice_duration": 3, "crit_bonus": 0.20, "blood_moon_global": true, "slave_consume": 2}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"gear_workshop": {
		"name": "齿轮工坊",
		"max_level": 3,
		"neutral_req": FactionData.NeutralFaction.GOBLIN_ENGINEER,
		"levels": {
			1: {"cost": {"gold": 110, "iron": 20}, "desc": "火药+1/回合, 攻城器械可造", "effects": {"gunpowder_per_turn": 1, "siege_engine_unlock": true}},
			2: {"cost": {"gold": 180, "iron": 30}, "desc": "火药+2, 城防破坏+30%, 地精炸弹", "effects": {"gunpowder_per_turn": 2, "wall_damage_bonus": 0.30, "goblin_bomb": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 260, "iron": 45}, "desc": "火药+3, 破坏+50%, 蒸汽巨像解锁", "effects": {"gunpowder_per_turn": 3, "wall_damage_bonus": 0.50, "steam_golem_unlock": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
}

# ── Resource station buildings (v0.8.3, require matching resource_station_type) ──
const RESOURCE_STATION_BUILDINGS: Dictionary = {
	"crystal_amplifier": {
		"name": "魔晶增幅器",
		"max_level": 3,
		"station_type_req": "magic_crystal",
		"levels": {
			1: {"cost": {"gold": 100, "iron": 15}, "desc": "魔晶+1/回合, 法术研究+10%", "effects": {"crystal_bonus": 1, "spell_research": 0.10}},
			2: {"cost": {"gold": 180, "iron": 25}, "desc": "魔晶+2, 研究+20%, 法力护盾", "effects": {"crystal_bonus": 2, "spell_research": 0.20, "mana_shield": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 280, "iron": 40}, "desc": "魔晶+3, 研究+30%, 魔晶共鸣(全据点)", "effects": {"crystal_bonus": 3, "spell_research": 0.30, "crystal_resonance": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"horse_breeder": {
		"name": "良种马场",
		"max_level": 3,
		"station_type_req": "war_horse",
		"levels": {
			1: {"cost": {"gold": 90, "iron": 10}, "desc": "战马+1/回合, 骑兵招募-20%费用", "effects": {"horse_bonus": 1, "cavalry_discount": 0.20}},
			2: {"cost": {"gold": 160, "iron": 18}, "desc": "战马+2, 折扣-40%, 骑兵ATK+2", "effects": {"horse_bonus": 2, "cavalry_discount": 0.40, "cavalry_atk": 2}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 240, "iron": 28}, "desc": "战马+3, 免费骑兵, 冲锋伤害+30%", "effects": {"horse_bonus": 3, "free_cavalry_interval": 3, "charge_bonus": 0.30}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"powder_mill": {
		"name": "火药精炼厂",
		"max_level": 3,
		"station_type_req": "gunpowder",
		"levels": {
			1: {"cost": {"gold": 120, "iron": 20}, "desc": "火药+1/回合, 城防破坏+15%", "effects": {"gunpowder_bonus": 1, "wall_damage_bonus": 0.15}},
			2: {"cost": {"gold": 200, "iron": 32}, "desc": "火药+2, 破坏+30%, 炮兵ATK+3", "effects": {"gunpowder_bonus": 2, "wall_damage_bonus": 0.30, "artillery_atk": 3}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 300, "iron": 48}, "desc": "火药+3, 破坏+50%, 爆破专家(首轮城防-20)", "effects": {"gunpowder_bonus": 3, "wall_damage_bonus": 0.50, "first_round_wall_damage": 20}, "upgrade_req": {"tile_level": 3}},
		},
	},
	"shadow_conduit": {
		"name": "暗影导管",
		"max_level": 3,
		"station_type_req": "shadow_essence",
		"levels": {
			1: {"cost": {"gold": 130, "iron": 15}, "desc": "暗影精华+1/回合, 暗影视野+1格", "effects": {"shadow_bonus": 1, "shadow_visibility": 1}},
			2: {"cost": {"gold": 210, "iron": 24}, "desc": "精华+2, 暗影步(移动无视地形1次/回合)", "effects": {"shadow_bonus": 2, "shadow_step": true}, "upgrade_req": {"tile_level": 2}},
			3: {"cost": {"gold": 310, "iron": 36}, "desc": "精华+3, 暗影传送(任意暗影裂隙间), 恐惧光环", "effects": {"shadow_bonus": 3, "shadow_teleport": true, "fear_aura": true}, "upgrade_req": {"tile_level": 3}},
		},
	},
}


func _ready() -> void:
	pass


## Get level data for a building definition, with fallback to level 1.
func _get_level_data(bld: Dictionary, level: int) -> Dictionary:
	var levels: Dictionary = bld.get("levels", {})
	if levels.has(level):
		return levels[level]
	if levels.has(1):
		return levels[1]
	return {}


## Look up a building definition across all registries (without duplicating).
func _find_building_def(building_id: String) -> Dictionary:
	if COMMON_BUILDINGS.has(building_id): return COMMON_BUILDINGS[building_id]
	for fid in FACTION_BUILDINGS:
		if FACTION_BUILDINGS[fid].has(building_id): return FACTION_BUILDINGS[fid][building_id]
	if TERRAIN_BUILDINGS.has(building_id): return TERRAIN_BUILDINGS[building_id]
	if TILE_TYPE_BUILDINGS.has(building_id): return TILE_TYPE_BUILDINGS[building_id]
	if NEUTRAL_BUILDINGS.has(building_id): return NEUTRAL_BUILDINGS[building_id]
	if RESOURCE_STATION_BUILDINGS.has(building_id): return RESOURCE_STATION_BUILDINGS[building_id]
	return {}


func get_building_data(building_id: String, level: int = 1) -> Dictionary:
	## Look up building in common list first, then faction-specific, then terrain/tile-type.
	var def: Dictionary = _find_building_def(building_id)
	if not def.is_empty():
		var bld: Dictionary = def.duplicate(true)
		bld["current_level_data"] = _get_level_data(bld, level)
		return bld
	# Fallback to legacy unique buildings in FactionData
	for faction_id in FactionData.UNIQUE_BUILDINGS:
		var uniques: Dictionary = FactionData.UNIQUE_BUILDINGS[faction_id]
		if uniques.has(building_id):
			return uniques[building_id]
	return {}


func get_building_name(building_id: String, level: int = 1) -> String:
	var data: Dictionary = get_building_data(building_id, level)
	var base_name: String = data.get("name", building_id)
	if level > 1:
		return "%s Lv%d" % [base_name, level]
	return base_name


func get_building_cost(building_id: String, level: int = 1) -> Dictionary:
	var data: Dictionary = get_building_data(building_id, level)
	# New 3-level format
	var lvl_data: Dictionary = data.get("current_level_data", {})
	if lvl_data.has("cost"):
		return lvl_data["cost"]
	# Legacy format
	if data.has("cost"):
		return data["cost"]
	return {
		"gold": data.get("cost_gold", 0),
		"iron": data.get("cost_iron", 0),
		"slaves": data.get("cost_slaves", 0),
	}


func get_building_max_level(building_id: String) -> int:
	var def: Dictionary = _find_building_def(building_id)
	return def.get("max_level", 1)


func get_building_effects(building_id: String, level: int = 1) -> Dictionary:
	var data: Dictionary = get_building_data(building_id, level)
	var lvl_data: Dictionary = data.get("current_level_data", {})
	return lvl_data.get("effects", data.get("effects", {}))


func get_all_player_building_effects(player_id: int) -> Dictionary:
	## Aggregates all building effects across all tiles owned by the player.
	## Returns a dictionary of summed effect values.
	var totals := {
		"atk_bonus": 0, "def_bonus": 0, "gold_per_turn": 0,
		"wall_hp_bonus": 0, "wall_repair_per_turn": 0,
		"garrison_regen": 0, "recruit_discount": 0,
		"research_speed": 0.0, "military_research_speed": 0.0, "arcane_research_speed": 0.0,
		"mage_atk_bonus": 0, "reanimate_chance": 0.0, "shadow_per_turn": 0,
		"supply_penalty_reduction": 0, "food_storage": 0,
		"free_troop_interval": 0,
		"elite_training": false, "tactical_sim": false,
		"crystal_efficiency": 1.0, "mana_regen": 0,
	}
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) != player_id:
			continue
		var bld: String = tile.get("building_id", "")
		if bld == "":
			continue
		var bld_level: int = tile.get("building_level", 1)
		var effects: Dictionary = get_building_effects(bld, bld_level)
		for key in effects:
			if totals.has(key):
				if totals[key] is bool:
					totals[key] = totals[key] or bool(effects[key])
				elif key == "crystal_efficiency":
					# Take the highest crystal_efficiency multiplier
					totals[key] = maxf(totals[key], float(effects[key]))
				elif totals[key] is float:
					totals[key] += float(effects[key])
				elif totals[key] is int:
					totals[key] += int(effects[key])
	return totals


func get_tile_building_effects(tile: Dictionary) -> Dictionary:
	## Returns building effects for a specific tile.
	var bld: String = tile.get("building_id", "")
	if bld == "":
		return {}
	return get_building_effects(bld, tile.get("building_level", 1))


func can_build_at(player_id: int, tile: Dictionary, building_id: String) -> bool:
	if tile.get("owner_id", -1) != player_id:
		return false
	# v0.8.3: Check terrain requirement
	if not _meets_terrain_requirement(tile, building_id):
		return false
	# v0.8.3: Check tile type requirement
	if not _meets_tile_type_requirement(tile, building_id):
		return false
	# v0.8.3: Check neutral faction requirement
	if not _meets_neutral_requirement(player_id, building_id):
		return false
	# v0.8.3: Check resource station requirement
	if not _meets_station_requirement(tile, building_id):
		return false
	var existing_bld: String = tile.get("building_id", "")
	if existing_bld != "" and existing_bld != building_id:
		return false
	# If same building, check if upgradeable
	if existing_bld == building_id:
		var current_level: int = tile.get("building_level", 1)
		var max_level: int = get_building_max_level(building_id)
		if current_level >= max_level:
			return false
		if not _meets_upgrade_requirements(player_id, tile, building_id, current_level + 1):
			return false
		var cost: Dictionary = get_building_cost(building_id, current_level + 1)
		return ResourceManager.can_afford(player_id, cost)
	# New build
	var cost: Dictionary = get_building_cost(building_id, 1)
	return ResourceManager.can_afford(player_id, cost)


func can_upgrade_building(player_id: int, tile: Dictionary) -> bool:
	var bld: String = tile.get("building_id", "")
	if bld == "":
		return false
	var current_level: int = tile.get("building_level", 1)
	var max_level: int = get_building_max_level(bld)
	if current_level >= max_level:
		return false
	if not _meets_upgrade_requirements(player_id, tile, bld, current_level + 1):
		return false
	var cost: Dictionary = get_building_cost(bld, current_level + 1)
	return ResourceManager.can_afford(player_id, cost)


func get_available_buildings_for(player_id: int, tile: Dictionary) -> Array:
	## Returns list of { "id": String, "name": String, "cost": Dict, "can_build": bool, "level": int }
	var result: Array = []
	if tile.get("owner_id", -1) != player_id:
		return result

	var existing_bld: String = tile.get("building_id", "")
	var existing_level: int = tile.get("building_level", 1)

	# If building exists, only show upgrade option
	if existing_bld != "":
		var max_level: int = get_building_max_level(existing_bld)
		if existing_level < max_level:
			var next_level: int = existing_level + 1
			var cost: Dictionary = get_building_cost(existing_bld, next_level)
			var data: Dictionary = get_building_data(existing_bld, next_level)
			var lvl_data: Dictionary = data.get("current_level_data", {})
			result.append({
				"id": existing_bld,
				"name": "升级 %s → Lv%d" % [get_building_name(existing_bld), next_level],
				"desc": lvl_data.get("desc", ""),
				"cost": cost,
				"can_build": ResourceManager.can_afford(player_id, cost) and _meets_upgrade_requirements(player_id, tile, existing_bld, next_level),
				"level": next_level,
				"is_upgrade": true,
				"meets_requirements": _meets_upgrade_requirements(player_id, tile, existing_bld, next_level),
			})
		return result

	# Common buildings
	for bid in COMMON_BUILDINGS:
		var bdata: Dictionary = COMMON_BUILDINGS[bid]
		var lvl1: Dictionary = _get_level_data(bdata, 1)
		var cost: Dictionary = lvl1.get("cost", {})
		result.append({
			"id": bid,
			"name": bdata["name"],
			"desc": lvl1.get("desc", ""),
			"cost": cost,
			"can_build": ResourceManager.can_afford(player_id, cost),
			"level": 1,
			"is_upgrade": false,
		})

	# Faction-specific buildings
	var faction_id: int = GameManager.get_player_faction(player_id)
	if FACTION_BUILDINGS.has(faction_id):
		var faction_blds: Dictionary = FACTION_BUILDINGS[faction_id]
		for bid in faction_blds:
			var bdata: Dictionary = faction_blds[bid]
			var lvl1: Dictionary = _get_level_data(bdata, 1)
			var cost: Dictionary = lvl1.get("cost", {})
			result.append({
				"id": bid,
				"name": bdata["name"],
				"desc": lvl1.get("desc", ""),
				"cost": cost,
				"can_build": ResourceManager.can_afford(player_id, cost),
				"level": 1,
				"is_upgrade": false,
			})

	# Legacy unique buildings (war_pit, smugglers_den, slave_pit)
	if FactionData.UNIQUE_BUILDINGS.has(faction_id):
		var uniques: Dictionary = FactionData.UNIQUE_BUILDINGS[faction_id]
		for bid in uniques:
			# Skip buildings already in FACTION_BUILDINGS
			if FACTION_BUILDINGS.has(faction_id) and FACTION_BUILDINGS[faction_id].has(bid):
				continue
			var bdata: Dictionary = uniques[bid]
			var cost: Dictionary = {
				"gold": bdata.get("cost_gold", 0),
				"iron": bdata.get("cost_iron", 0),
				"slaves": bdata.get("cost_slaves", 0),
			}
			result.append({
				"id": bid,
				"name": bdata["name"],
				"desc": bdata["desc"],
				"cost": cost,
				"can_build": ResourceManager.can_afford(player_id, cost),
				"level": 1,
				"is_upgrade": false,
			})

	# v0.8.3: Terrain-specific buildings (only show if terrain matches)
	for bid in TERRAIN_BUILDINGS:
		if not _meets_terrain_requirement(tile, bid):
			continue
		var bdata: Dictionary = TERRAIN_BUILDINGS[bid]
		var lvl1: Dictionary = _get_level_data(bdata, 1)
		var cost: Dictionary = lvl1.get("cost", {})
		result.append({
			"id": bid,
			"name": bdata["name"] + " [地形]",
			"desc": lvl1.get("desc", ""),
			"cost": cost,
			"can_build": ResourceManager.can_afford(player_id, cost),
			"level": 1,
			"is_upgrade": false,
			"category": "terrain",
		})

	# v0.8.3: Tile-type-specific buildings (only show if tile type matches)
	for bid in TILE_TYPE_BUILDINGS:
		if not _meets_tile_type_requirement(tile, bid):
			continue
		var bdata: Dictionary = TILE_TYPE_BUILDINGS[bid]
		var lvl1: Dictionary = _get_level_data(bdata, 1)
		var cost: Dictionary = lvl1.get("cost", {})
		result.append({
			"id": bid,
			"name": bdata["name"] + " [专属]",
			"desc": lvl1.get("desc", ""),
			"cost": cost,
			"can_build": ResourceManager.can_afford(player_id, cost),
			"level": 1,
			"is_upgrade": false,
			"category": "tile_type",
		})

	# v0.8.3: Neutral faction buildings (only show if faction recruited)
	for bid in NEUTRAL_BUILDINGS:
		if not _meets_neutral_requirement(player_id, bid):
			continue
		var bdata: Dictionary = NEUTRAL_BUILDINGS[bid]
		var lvl1: Dictionary = _get_level_data(bdata, 1)
		var cost: Dictionary = lvl1.get("cost", {})
		result.append({
			"id": bid,
			"name": bdata["name"] + " [中立]",
			"desc": lvl1.get("desc", ""),
			"cost": cost,
			"can_build": ResourceManager.can_afford(player_id, cost),
			"level": 1,
			"is_upgrade": false,
			"category": "neutral",
		})

	# v0.8.3: Resource station buildings (only show if on matching resource station)
	for bid in RESOURCE_STATION_BUILDINGS:
		if not _meets_station_requirement(tile, bid):
			continue
		var bdata: Dictionary = RESOURCE_STATION_BUILDINGS[bid]
		var lvl1: Dictionary = _get_level_data(bdata, 1)
		var cost: Dictionary = lvl1.get("cost", {})
		result.append({
			"id": bid,
			"name": bdata["name"] + " [资源]",
			"desc": lvl1.get("desc", ""),
			"cost": cost,
			"can_build": ResourceManager.can_afford(player_id, cost),
			"level": 1,
			"is_upgrade": false,
			"category": "resource_station",
		})

	return result


func apply_building_effects(player_id: int, building_id: String, tile: Dictionary) -> void:
	## Apply immediate on-build effects.
	var level: int = tile.get("building_level", 1)
	var effects: Dictionary = get_building_effects(building_id, level)

	if effects.has("slave_capacity"):
		ResourceManager.add_slave_capacity(player_id, effects["slave_capacity"])
		EventBus.message_log.emit("奴隶容量 +%d" % effects["slave_capacity"])

	if effects.has("garrison_bonus"):
		tile["garrison"] += effects["garrison_bonus"]
		EventBus.message_log.emit("驻军 +%d" % effects["garrison_bonus"])

	if effects.has("reveal_range"):
		var reveal_depth: int = effects["reveal_range"]
		_reveal_extended(tile["index"], player_id, reveal_depth)

	# Faction unique on-build
	if building_id == "slave_pit":
		var eff: float = effects.get("slave_efficiency", 1.5)
		SlaveManager.set_efficiency_mult(player_id, eff)
		EventBus.message_log.emit("奴隶工作效率提升至%d%%!" % int(eff * 100))

	if building_id == "temple_of_agony":
		EventBus.message_log.emit("痛苦神殿 Lv%d 已建成!" % level)

	OrderManager.on_building_constructed()
	EventBus.building_upgraded.emit(player_id, tile["index"], building_id, level)


func _reveal_extended(tile_index: int, player_id: int, depth: int) -> void:
	var visited: Dictionary = {tile_index: 0}
	var queue: Array = [tile_index]
	while queue.size() > 0:
		var current: int = queue.pop_front()
		var d: int = visited[current]
		GameManager.tiles[current]["revealed"][player_id] = true
		if d >= depth:
			continue
		if GameManager.adjacency.has(current):
			for nb in GameManager.adjacency[current]:
				if not visited.has(nb):
					visited[nb] = d + 1
					queue.append(nb)
	EventBus.fog_updated.emit(player_id)


func _meets_terrain_requirement(tile: Dictionary, building_id: String) -> bool:
	if not TERRAIN_BUILDINGS.has(building_id):
		return true  # not a terrain building, no requirement
	var req_terrain: int = TERRAIN_BUILDINGS[building_id].get("terrain_req", -1)
	if req_terrain < 0:
		return true
	return tile.get("terrain", FactionData.TerrainType.PLAINS) == req_terrain


func _meets_tile_type_requirement(tile: Dictionary, building_id: String) -> bool:
	if not TILE_TYPE_BUILDINGS.has(building_id):
		return true  # not a tile-type building, no requirement
	var req_type: String = TILE_TYPE_BUILDINGS[building_id].get("tile_type_req", "")
	if req_type == "":
		return true
	# Map string to TileType enum
	var tile_type: int = tile.get("type", -1)
	match req_type:
		"WATCHTOWER": return tile_type == GameManager.TileType.WATCHTOWER
		"RUINS": return tile_type == GameManager.TileType.RUINS
		"CHOKEPOINT": return tile_type == GameManager.TileType.CHOKEPOINT
		"HARBOR": return tile_type == GameManager.TileType.HARBOR
		"TRADING_POST": return tile_type == GameManager.TileType.TRADING_POST
	return false


func _meets_neutral_requirement(player_id: int, building_id: String) -> bool:
	if not NEUTRAL_BUILDINGS.has(building_id):
		return true  # not a neutral building, no requirement
	var req_faction: int = NEUTRAL_BUILDINGS[building_id].get("neutral_req", -1)
	if req_faction < 0:
		return true
	# Check if player has recruited this neutral faction via QuestManager
	if not QuestManager:
		return false
	return QuestManager.is_faction_recruited(player_id, req_faction)


func _meets_station_requirement(tile: Dictionary, building_id: String) -> bool:
	if not RESOURCE_STATION_BUILDINGS.has(building_id):
		return true  # not a station building, no requirement
	var req_station: String = RESOURCE_STATION_BUILDINGS[building_id].get("station_type_req", "")
	if req_station == "":
		return true
	# Tile must be a RESOURCE_STATION with matching station_type
	var tile_type: int = tile.get("type", -1)
	if tile_type != GameManager.TileType.RESOURCE_STATION:
		return false
	return tile.get("resource_station_type", "") == req_station


func _meets_upgrade_requirements(player_id: int, tile: Dictionary, building_id: String, level: int) -> bool:
	var data: Dictionary = get_building_data(building_id, level)
	var lvl_data: Dictionary = data.get("current_level_data", {})
	var req: Dictionary = lvl_data.get("upgrade_req", {})
	if req.is_empty():
		return true
	if req.has("tile_level") and tile.get("level", 1) < req["tile_level"]:
		return false
	if req.has("order_min") and OrderManager.get_order() < req["order_min"]:
		return false
	if req.has("slaves_min") and ResourceManager.get_slaves(player_id) < req["slaves_min"]:
		return false
	if req.has("plunder_min"):
		if PirateMechanic.get_plunder_value(player_id) < req["plunder_min"]:
			return false
	if req.has("waaagh_triggers_min"):
		if OrcMechanic.get_frenzy_count() < req["waaagh_triggers_min"]:
			return false
	return true
