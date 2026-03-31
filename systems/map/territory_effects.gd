## territory_effects.gd
## Comprehensive territory depth system — unique effects, production, strategic value,
## and random events for all 55 fixed-map territories.

class_name TerritoryEffects
extends RefCounted

# ---------------------------------------------------------------------------
# 1. TERRITORY_SPECIAL_EFFECTS — unique passive effect for every territory
# ---------------------------------------------------------------------------

const TERRITORY_SPECIAL_EFFECTS: Dictionary = {
	# === HUMAN KINGDOM (0-8) ===
	0: {
		"effect_id": "holy_city_aura",
		"effect_name": "圣城光环",
		"effect_name_en": "Holy City Aura",
		"category": "strategic",
		"description": "天城王都散发神圣光辉，相邻2格据点DEF+20%，全人类据点秩序+5，每回合自动训练1骑士增援。",
		"modifiers": {
			"adjacent_def_pct": 0.2,
			"aura_order_bonus": 5,
			"auto_recruit_knight": 1,
		},
		"requires_control": true,
		"aura_range": 2,
	},
	1: {
		"effect_id": "silver_crown_wall",
		"effect_name": "银冠之壁",
		"effect_name_en": "Silver Crown Bulwark",
		"category": "military",
		"description": "银冠要塞坚不可摧，驻军上限+10，骑兵ATK+2，每回合增援王都1兵。",
		"modifiers": {
			"garrison_cap_bonus": 10,
			"cavalry_atk_bonus": 2,
			"reinforce_capital": 1,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	2: {
		"effect_id": "one_man_pass",
		"effect_name": "一夫当关",
		"effect_name_en": "One Man Pass",
		"category": "military",
		"description": "铁壁关易守难攻，攻方ATK-15%，城防恢复+5/回合，关隘地形加成翻倍。",
		"modifiers": {
			"attacker_atk_pct": -0.15,
			"wall_regen_per_turn": 5,
			"terrain_bonus_multiplier": 2.0,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	3: {
		"effect_id": "harvest_land",
		"effect_name": "丰收之地",
		"effect_name_en": "Bountiful Harvest",
		"category": "economic",
		"description": "枫叶村沃土千里，粮食产出+50%，秋季额外金币+10。",
		"modifiers": {
			"food_pct": 0.5,
			"autumn_gold_bonus": 10,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	4: {
		"effect_id": "trade_hub",
		"effect_name": "贸易枢纽",
		"effect_name_en": "Trade Hub",
		"category": "economic",
		"description": "晨曦镇商旅云集，金币+15/回合，相邻据点贸易收入+10%。",
		"modifiers": {
			"gold_per_turn": 15,
			"adjacent_trade_pct": 0.1,
		},
		"requires_control": true,
		"aura_range": 1,
	},
	5: {
		"effect_id": "fishing_prosperity",
		"effect_name": "渔港富庶",
		"effect_name_en": "Prosperous Fishing Port",
		"category": "economic",
		"description": "柳河庄依河而建，粮食+8/回合，水域移动速度+20%。",
		"modifiers": {
			"food_per_turn": 8,
			"water_move_speed_pct": 0.2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	6: {
		"effect_id": "frontline_bastion",
		"effect_name": "前线堡垒",
		"effect_name_en": "Frontline Bastion",
		"category": "military",
		"description": "铁壁堡驻守前线，驻军自动恢复+2/回合，新招募部队DEF+1。",
		"modifiers": {
			"garrison_regen_per_turn": 2,
			"recruit_def_bonus": 1,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	7: {
		"effect_id": "griffin_nest",
		"effect_name": "狮鹫巢穴",
		"effect_name_en": "Griffin Nest",
		"category": "military",
		"description": "狮鹫堡可训练狮鹫骑士，骑兵训练费-20%，解锁特殊兵种'狮鹫骑士'。",
		"modifiers": {
			"cavalry_cost_pct": -0.2,
			"unlock_unit": "griffin_knight",
		},
		"requires_control": true,
		"aura_range": 0,
	},
	8: {
		"effect_id": "thunder_wrath",
		"effect_name": "雷霆之怒",
		"effect_name_en": "Thunder's Wrath",
		"category": "magical",
		"description": "雷鸣关雷电汇聚，守方法术伤害+25%，攻方骑兵冲锋无效。",
		"modifiers": {
			"defender_spell_dmg_pct": 0.25,
			"negate_cavalry_charge": true,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	# === ELVEN DOMAIN (9-13) ===
	9: {
		"effect_id": "world_tree_blessing",
		"effect_name": "世界树祝福",
		"effect_name_en": "World Tree Blessing",
		"category": "magical",
		"description": "世界树灵脉恢复全领地单位1HP/回合，屏障+40，精灵单位ATK+2。",
		"modifiers": {
			"global_hp_regen": 1,
			"barrier_bonus": 40,
			"elf_atk_bonus": 2,
		},
		"requires_control": true,
		"aura_range": 2,
	},
	10: {
		"effect_id": "moonlight_heal",
		"effect_name": "月光治愈",
		"effect_name_en": "Moonlight Healing",
		"category": "magical",
		"description": "白石村月华洒落，夜间战斗治愈1兵/回合，草药产出+2。",
		"modifiers": {
			"night_heal_per_turn": 1,
			"herb_production": 2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	11: {
		"effect_id": "hunter_eye",
		"effect_name": "猎手之眼",
		"effect_name_en": "Hunter's Eye",
		"category": "military",
		"description": "鹿角镇猎手聚居，视野+2格，远程单位暴击+10%。",
		"modifiers": {
			"vision_bonus": 2,
			"ranged_crit_pct": 0.1,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	12: {
		"effect_id": "frost_barrier",
		"effect_name": "冰霜结界",
		"effect_name_en": "Frost Barrier",
		"category": "military",
		"description": "霜风哨寒气逼人，冬季DEF+30%，敌方行军速度-30%。",
		"modifiers": {
			"winter_def_pct": 0.3,
			"enemy_march_speed_pct": -0.3,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	13: {
		"effect_id": "phantom_maze",
		"effect_name": "幻影迷阵",
		"effect_name_en": "Phantom Maze",
		"category": "magical",
		"description": "月影关布满幻阵，20%几率敌方进攻时迷路(浪费1AP)，忍者伤害+15%。",
		"modifiers": {
			"enemy_lost_chance": 0.2,
			"ninja_dmg_pct": 0.15,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	# === MAGE ALLIANCE (14-18) ===
	14: {
		"effect_id": "mana_nexus",
		"effect_name": "法力中枢",
		"effect_name_en": "Mana Nexus",
		"category": "magical",
		"description": "奥术堡垒法力汇聚，法力产出x3，法术伤害+20%，可研究禁术。",
		"modifiers": {
			"mana_multiplier": 3,
			"spell_dmg_pct": 0.2,
			"unlock_forbidden_magic": true,
		},
		"requires_control": true,
		"aura_range": 1,
	},
	15: {
		"effect_id": "teleport_gate",
		"effect_name": "传送门",
		"effect_name_en": "Teleport Gate",
		"category": "strategic",
		"description": "翡翠尖塔开启传送门，可传送军团到任意己方法师据点(2AP)，法力+2/回合。",
		"modifiers": {
			"teleport_to_mage_outpost": true,
			"teleport_ap_cost": 2,
			"mana_per_turn": 2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	16: {
		"effect_id": "spirit_spring",
		"effect_name": "灵泉",
		"effect_name_en": "Spirit Spring",
		"category": "cultural",
		"description": "云雾庄灵泉涌动，英雄经验+25%，法师部队每战后恢复2兵。",
		"modifiers": {
			"hero_exp_pct": 0.25,
			"mage_post_battle_heal": 2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	17: {
		"effect_id": "dragon_spine_power",
		"effect_name": "龙骨之力",
		"effect_name_en": "Dragon Spine Power",
		"category": "military",
		"description": "龙脊要塞蕴含古龙之力，所有部队ATK+1/DEF+1，攻城伤害+15%。",
		"modifiers": {
			"all_atk_bonus": 1,
			"all_def_bonus": 1,
			"siege_dmg_pct": 0.15,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	18: {
		"effect_id": "stellar_power",
		"effect_name": "星辰之力",
		"effect_name_en": "Stellar Power",
		"category": "magical",
		"description": "星落堡承接星辰之力，夜间全属性+10%，拥有占卜能力(可查看敌方军团组成)。",
		"modifiers": {
			"night_all_stats_pct": 0.1,
			"divination": true,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	# === ORC HORDE (19-23) ===
	19: {
		"effect_id": "waaagh_center",
		"effect_name": "WAAAGH!中心",
		"effect_name_en": "WAAAGH! Center",
		"category": "military",
		"description": "碎骨王座激发战意，WAAAGH上限+30，可招募巨魔和战猪，兽人全国ATK+1。",
		"modifiers": {
			"waaagh_cap_bonus": 30,
			"unlock_unit_troll": true,
			"unlock_unit_war_boar": true,
			"global_orc_atk_bonus": 1,
		},
		"requires_control": true,
		"aura_range": 2,
	},
	20: {
		"effect_id": "plunder_camp",
		"effect_name": "掠夺营地",
		"effect_name_en": "Plunder Camp",
		"category": "economic",
		"description": "红叶镇以战养战，战斗胜利额外金币+20，俘虏转化率+15%。",
		"modifiers": {
			"battle_gold_bonus": 20,
			"captive_convert_pct": 0.15,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	21: {
		"effect_id": "scorched_earth",
		"effect_name": "焦土战术",
		"effect_name_en": "Scorched Earth",
		"category": "strategic",
		"description": "焦土堡失守时烧毁50%建筑和资源(敌方获得减半)，驻军死战不退。",
		"modifiers": {
			"on_loss_destroy_pct": 0.5,
			"garrison_no_rout": true,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	22: {
		"effect_id": "blood_sacrifice",
		"effect_name": "血祭",
		"effect_name_en": "Blood Sacrifice",
		"category": "military",
		"description": "血牙关嗜血如狂，每阵亡1兵全军ATK+0.5(上限+5)，关隘DEF+10。",
		"modifiers": {
			"death_atk_bonus_per_unit": 0.5,
			"death_atk_bonus_cap": 5,
			"pass_def_bonus": 10,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	23: {
		"effect_id": "lava_forge",
		"effect_name": "熔火锻造",
		"effect_name_en": "Lava Forge",
		"category": "economic",
		"description": "熔岩裂隙暗影涌动，暗影精华+1/回合，火焰伤害+20%，可锻造熔岩武器。",
		"modifiers": {
			"shadow_essence_per_turn": 1,
			"fire_dmg_pct": 0.2,
			"unlock_craft_lava_weapon": true,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	# === PIRATE COALITION (24-27) ===
	24: {
		"effect_id": "black_port",
		"effect_name": "黑港",
		"effect_name_en": "Black Port",
		"category": "economic",
		"description": "深渊港黑帆如云，掠夺值x2，黑市自动刷新，可招募炮击手，海域通行。",
		"modifiers": {
			"plunder_multiplier": 2,
			"black_market_auto_refresh": true,
			"unlock_unit_cannoneer": true,
			"sea_passage": true,
		},
		"requires_control": true,
		"aura_range": 1,
	},
	25: {
		"effect_id": "smuggle_network",
		"effect_name": "走私网络",
		"effect_name_en": "Smuggle Network",
		"category": "economic",
		"description": "碧水村走私猖獗，黑市物品价格-15%，情报收集+20%。",
		"modifiers": {
			"black_market_discount_pct": 0.15,
			"intel_bonus_pct": 0.2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	26: {
		"effect_id": "reef_defense",
		"effect_name": "暗礁防线",
		"effect_name_en": "Reef Defense Line",
		"category": "military",
		"description": "暗礁塔暗礁密布，海上来犯敌方ATK-20%，炮台每回合自动对攻方造成伤害。",
		"modifiers": {
			"sea_attacker_atk_pct": -0.2,
			"turret_auto_dmg": 3,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	27: {
		"effect_id": "ice_port_fortress",
		"effect_name": "冰港要塞",
		"effect_name_en": "Ice Port Fortress",
		"category": "military",
		"description": "霜牙港坚冰护城，冬季DEF+25%，海盗单位补给消耗-30%。",
		"modifiers": {
			"winter_def_pct": 0.25,
			"pirate_supply_cost_pct": -0.3,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	# === DARK ELF CLAN (28-30) ===
	28: {
		"effect_id": "eternal_night",
		"effect_name": "永夜降临",
		"effect_name_en": "Eternal Night",
		"category": "magical",
		"description": "永夜暗城笼罩无尽黑暗，奴隶上限+10，神殿Lv2，暗精灵全国DEF+2，启用影行术。",
		"modifiers": {
			"slave_cap_bonus": 10,
			"temple_level": 2,
			"global_dark_elf_def_bonus": 2,
			"shadow_walk": true,
		},
		"requires_control": true,
		"aura_range": 2,
	},
	29: {
		"effect_id": "poison_fog_forest",
		"effect_name": "毒雾森林",
		"effect_name_en": "Poison Fog Forest",
		"category": "military",
		"description": "松风庄瘴气弥漫，进攻方中毒(-1兵/回合持续3回合)，忍者单位隐蔽。",
		"modifiers": {
			"attacker_poison_dmg": 1,
			"attacker_poison_duration": 3,
			"ninja_stealth": true,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	30: {
		"effect_id": "shadow_ritual",
		"effect_name": "暗影仪式",
		"effect_name_en": "Shadow Ritual",
		"category": "magical",
		"description": "月影祭坛举行暗影仪式，暗影精华+1/回合，可牺牲奴隶获得临时全属性加成。",
		"modifiers": {
			"shadow_essence_per_turn": 1,
			"ritual_sacrifice_enabled": true,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	# === NEUTRAL SETTLEMENTS (31-36) ===
	31: {
		"effect_id": "waystation_trade",
		"effect_name": "驿站贸易",
		"effect_name_en": "Waystation Trade",
		"category": "economic",
		"description": "行商驿站四通八达，金币+10/回合，首次占领获得随机物品。",
		"modifiers": {
			"gold_per_turn": 10,
			"first_capture_random_item": true,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	32: {
		"effect_id": "undead_curse",
		"effect_name": "亡灵诅咒",
		"effect_name_en": "Undead Curse",
		"category": "magical",
		"description": "枯骨墓穴亡灵不息，可招募骷髅兵(低成本)，夜间DEF+15%。",
		"modifiers": {
			"unlock_unit_skeleton": true,
			"night_def_pct": 0.15,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	33: {
		"effect_id": "ranger_home",
		"effect_name": "游侠之家",
		"effect_name_en": "Ranger's Home",
		"category": "military",
		"description": "绿影营地游侠栖息，可招募游侠(远程特殊兵种)，视野+1。",
		"modifiers": {
			"unlock_unit_ranger": true,
			"vision_bonus": 1,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	34: {
		"effect_id": "artisan_spirit",
		"effect_name": "工匠精神",
		"effect_name_en": "Artisan Spirit",
		"category": "economic",
		"description": "地精工坊能工巧匠，装备锻造速度+30%，铁+5/回合。",
		"modifiers": {
			"craft_speed_pct": 0.3,
			"iron_per_turn": 5,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	35: {
		"effect_id": "show_income",
		"effect_name": "表演收入",
		"effect_name_en": "Show Income",
		"category": "cultural",
		"description": "流浪马戏团精彩绝伦，金币+8/回合，秩序+10，英雄好感+2/回合。",
		"modifiers": {
			"gold_per_turn": 8,
			"order_bonus": 10,
			"hero_favor_per_turn": 2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	36: {
		"effect_id": "bounty_board",
		"effect_name": "悬赏任务",
		"effect_name_en": "Bounty Board",
		"category": "strategic",
		"description": "赏金猎人公会发布悬赏，每回合可消耗金币削弱敌方英雄。",
		"modifiers": {
			"bounty_mission_enabled": true,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	# === BANDIT LAIRS (37-46) ===
	37: {
		"effect_id": "bandit_chief",
		"effect_name": "山贼头目",
		"effect_name_en": "Bandit Chief",
		"category": "economic",
		"description": "黑风寨占领后匪兵可雇佣，每回合金+5(收保护费)。",
		"modifiers": {
			"unlock_unit_bandit": true,
			"gold_per_turn": 5,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	38: {
		"effect_id": "tunnel_network",
		"effect_name": "地道网络",
		"effect_name_en": "Tunnel Network",
		"category": "strategic",
		"description": "落日盗窟暗道纵横，可从此据点秘密行军(不被拦截)。",
		"modifiers": {
			"stealth_march": true,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	39: {
		"effect_id": "venom_trap",
		"effect_name": "毒液陷阱",
		"effect_name_en": "Venom Trap",
		"category": "military",
		"description": "毒蛇谷毒液遍布，进攻方首回合全军中毒，毒伤害2/回合。",
		"modifiers": {
			"attacker_poison_first_round": true,
			"poison_dmg_per_turn": 2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	40: {
		"effect_id": "assassin_den",
		"effect_name": "刺客据点",
		"effect_name_en": "Assassin Den",
		"category": "strategic",
		"description": "暗影巢穴藏匿刺客，可雇佣刺客(暗杀敌方英雄)，间谍效率+20%。",
		"modifiers": {
			"unlock_unit_assassin": true,
			"spy_efficiency_pct": 0.2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	41: {
		"effect_id": "mountain_stronghold",
		"effect_name": "山地要塞",
		"effect_name_en": "Mountain Stronghold",
		"category": "military",
		"description": "断牙山寨据险而守，山地DEF加成翻倍，居高临下远程+15%。",
		"modifiers": {
			"mountain_def_multiplier": 2.0,
			"ranged_dmg_pct": 0.15,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	42: {
		"effect_id": "swamp_miasma",
		"effect_name": "沼泽瘴气",
		"effect_name_en": "Swamp Miasma",
		"category": "military",
		"description": "腐沼堡瘴气弥漫，进攻方士气-10，骑兵不可使用。",
		"modifiers": {
			"attacker_morale_penalty": -10,
			"disable_cavalry": true,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	43: {
		"effect_id": "death_warning",
		"effect_name": "死亡警告",
		"effect_name_en": "Death Warning",
		"category": "strategic",
		"description": "秃鹫岭秃鹫盘旋，敌方靠近时提前预警(1回合)，侦察范围+2。",
		"modifiers": {
			"early_warning_turns": 1,
			"scout_range_bonus": 2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	44: {
		"effect_id": "river_waterway",
		"effect_name": "内河航道",
		"effect_name_en": "River Waterway",
		"category": "economic",
		"description": "海盗湾连接河流网络，船运补给+30%。",
		"modifiers": {
			"river_network": true,
			"supply_by_ship_pct": 0.3,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	45: {
		"effect_id": "lost_forest",
		"effect_name": "迷失森林",
		"effect_name_en": "Lost Forest",
		"category": "magical",
		"description": "鬼火林鬼气森森，25%敌方行军迷路，忍者/刺客ATK+2。",
		"modifiers": {
			"enemy_lost_chance": 0.25,
			"ninja_assassin_atk_bonus": 2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	46: {
		"effect_id": "undead_vein",
		"effect_name": "亡灵矿脉",
		"effect_name_en": "Undead Vein",
		"category": "magical",
		"description": "噬骨洞亡灵涌动，暗影精华+1/回合，每战后骷髅复活1-2兵。",
		"modifiers": {
			"shadow_essence_per_turn": 1,
			"skeleton_revive_min": 1,
			"skeleton_revive_max": 2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	# === RESOURCE STATIONS (47-54) ===
	47: {
		"effect_id": "crystal_resonance",
		"effect_name": "魔晶共鸣",
		"effect_name_en": "Crystal Resonance",
		"category": "economic",
		"description": "魔晶矿脉共鸣不绝，魔晶+2/回合，法师据点相邻时法力+1。",
		"modifiers": {
			"crystal_per_turn": 2,
			"adjacent_mage_mana_bonus": 1,
		},
		"requires_control": true,
		"aura_range": 1,
	},
	48: {
		"effect_id": "fine_steeds",
		"effect_name": "良驹辈出",
		"effect_name_en": "Fine Steeds",
		"category": "economic",
		"description": "战马牧场良驹辈出，战马+1/回合，骑兵招募时间-1回合。",
		"modifiers": {
			"horse_per_turn": 1,
			"cavalry_recruit_time_reduction": 1,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	49: {
		"effect_id": "fine_iron_output",
		"effect_name": "精铁产出",
		"effect_name_en": "Fine Iron Output",
		"category": "economic",
		"description": "铁矿场产出精铁，铁+8/回合，武器锻造成本-15%。",
		"modifiers": {
			"iron_per_turn": 8,
			"weapon_craft_cost_pct": -0.15,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	50: {
		"effect_id": "rejuvenation_herbs",
		"effect_name": "回春草药",
		"effect_name_en": "Rejuvenation Herbs",
		"category": "cultural",
		"description": "药草园回春妙药，战后恢复+2兵，英雄伤势恢复加快。",
		"modifiers": {
			"post_battle_heal": 2,
			"hero_wound_recovery_speed": 2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	51: {
		"effect_id": "shadow_spirit_wood",
		"effect_name": "暗影灵木",
		"effect_name_en": "Shadow Spirit Wood",
		"category": "economic",
		"description": "灵木林场生长暗影灵木，暗影精华+1/回合，暗精灵装备材料来源。",
		"modifiers": {
			"shadow_essence_per_turn": 1,
			"dark_elf_craft_material": true,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	52: {
		"effect_id": "gunpowder_source",
		"effect_name": "火药原料",
		"effect_name_en": "Gunpowder Source",
		"category": "economic",
		"description": "硫磺泉产出火药原料，火药+1/回合，火炮伤害+10%。",
		"modifiers": {
			"gunpowder_per_turn": 1,
			"cannon_dmg_pct": 0.1,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	53: {
		"effect_id": "gem_vein",
		"effect_name": "宝石矿脉",
		"effect_name_en": "Gem Vein",
		"category": "economic",
		"description": "宝石洞蕴藏珍宝，魔晶+1/回合，金+8/回合(宝石贸易)。",
		"modifiers": {
			"crystal_per_turn": 1,
			"gold_per_turn": 8,
		},
		"requires_control": true,
		"aura_range": 0,
	},
	54: {
		"effect_id": "magic_iron_forge",
		"effect_name": "魔铁锻造",
		"effect_name_en": "Magic Iron Forge",
		"category": "economic",
		"description": "魔铁锻炉以地热锻铁，火药+1/回合，可锻造魔铁装备(ATK+2)。",
		"modifiers": {
			"gunpowder_per_turn": 1,
			"unlock_craft_magic_iron": true,
			"magic_iron_atk_bonus": 2,
		},
		"requires_control": true,
		"aura_range": 0,
	},
}

# ---------------------------------------------------------------------------
# 2. TERRITORY_PRODUCTION — base resource output per turn
# ---------------------------------------------------------------------------

const TERRITORY_PRODUCTION: Dictionary = {
	# --- Human Kingdom (0-8) ---
	0:  {"gold": 40, "food": 20, "iron": 10, "prestige": 8},   # 天城王都 — capital fortress
	1:  {"gold": 30, "food": 12, "iron": 15, "prestige": 5},   # 银冠要塞 — fortress
	2:  {"gold": 25, "food": 10, "iron": 12, "prestige": 4},   # 铁壁关 — fortress
	3:  {"gold": 12, "food": 25, "iron": 2,  "prestige": 1},   # 枫叶村 — farming village
	4:  {"gold": 20, "food": 10, "iron": 3,  "prestige": 2},   # 晨曦镇 — trade village
	5:  {"gold": 10, "food": 20, "iron": 1,  "prestige": 1},   # 柳河庄 — fishing village
	6:  {"gold": 18, "food": 8,  "iron": 10, "prestige": 3},   # 铁壁堡 — outpost
	7:  {"gold": 18, "food": 8,  "iron": 8,  "prestige": 3},   # 狮鹫堡 — outpost
	8:  {"gold": 18, "food": 8,  "iron": 8,  "prestige": 3},   # 雷鸣关 — outpost
	# --- Elven Domain (9-13) ---
	9:  {"gold": 35, "food": 18, "iron": 5,  "prestige": 10},  # 世界树圣地 — capital
	10: {"gold": 10, "food": 15, "iron": 2,  "prestige": 2},   # 白石村
	11: {"gold": 10, "food": 12, "iron": 3,  "prestige": 1},   # 鹿角镇
	12: {"gold": 15, "food": 8,  "iron": 5,  "prestige": 2},   # 霜风哨 — outpost
	13: {"gold": 15, "food": 8,  "iron": 5,  "prestige": 3},   # 月影关 — outpost
	# --- Mage Alliance (14-18) ---
	14: {"gold": 35, "food": 10, "iron": 8,  "prestige": 8},   # 奥术堡垒 — capital
	15: {"gold": 30, "food": 8,  "iron": 6,  "prestige": 5},   # 翡翠尖塔 — fortress
	16: {"gold": 10, "food": 12, "iron": 2,  "prestige": 2},   # 云雾庄 — village
	17: {"gold": 20, "food": 8,  "iron": 10, "prestige": 3},   # 龙脊要塞 — outpost
	18: {"gold": 18, "food": 6,  "iron": 5,  "prestige": 3},   # 星落堡 — outpost
	# --- Orc Horde (19-23) ---
	19: {"gold": 30, "food": 15, "iron": 12, "prestige": 6},   # 碎骨王座 — capital
	20: {"gold": 12, "food": 10, "iron": 5,  "prestige": 1},   # 红叶镇 — village
	21: {"gold": 15, "food": 8,  "iron": 8,  "prestige": 2},   # 焦土堡 — outpost
	22: {"gold": 18, "food": 8,  "iron": 10, "prestige": 3},   # 血牙关 — outpost
	23: {"gold": 12, "food": 5,  "iron": 6,  "prestige": 2},   # 熔岩裂隙 — outpost
	# --- Pirate Coalition (24-27) ---
	24: {"gold": 35, "food": 12, "iron": 8,  "prestige": 5},   # 深渊港 — capital
	25: {"gold": 12, "food": 15, "iron": 2,  "prestige": 1},   # 碧水村 — village
	26: {"gold": 18, "food": 6,  "iron": 8,  "prestige": 2},   # 暗礁塔 — outpost
	27: {"gold": 18, "food": 8,  "iron": 8,  "prestige": 3},   # 霜牙港 — outpost
	# --- Dark Elf Clan (28-30) ---
	28: {"gold": 35, "food": 12, "iron": 10, "prestige": 7},   # 永夜暗城 — capital
	29: {"gold": 10, "food": 10, "iron": 3,  "prestige": 1},   # 松风庄 — village
	30: {"gold": 15, "food": 6,  "iron": 5,  "prestige": 4},   # 月影祭坛 — outpost
	# --- Neutral Settlements (31-36) ---
	31: {"gold": 15, "food": 8,  "iron": 3,  "prestige": 1},   # 行商驿站
	32: {"gold": 8,  "food": 3,  "iron": 5,  "prestige": 1},   # 枯骨墓穴
	33: {"gold": 10, "food": 10, "iron": 3,  "prestige": 1},   # 绿影营地
	34: {"gold": 12, "food": 5,  "iron": 10, "prestige": 1},   # 地精工坊
	35: {"gold": 15, "food": 5,  "iron": 2,  "prestige": 2},   # 流浪马戏团
	36: {"gold": 12, "food": 5,  "iron": 5,  "prestige": 2},   # 赏金猎人公会
	# --- Bandit Lairs (37-46) ---
	37: {"gold": 8,  "food": 5,  "iron": 3,  "prestige": 0},   # 黑风寨
	38: {"gold": 8,  "food": 5,  "iron": 3,  "prestige": 0},   # 落日盗窟
	39: {"gold": 6,  "food": 3,  "iron": 2,  "prestige": 0},   # 毒蛇谷
	40: {"gold": 8,  "food": 3,  "iron": 5,  "prestige": 0},   # 暗影巢穴
	41: {"gold": 6,  "food": 3,  "iron": 5,  "prestige": 0},   # 断牙山寨
	42: {"gold": 5,  "food": 5,  "iron": 2,  "prestige": 0},   # 腐沼堡
	43: {"gold": 6,  "food": 3,  "iron": 3,  "prestige": 0},   # 秃鹫岭
	44: {"gold": 10, "food": 8,  "iron": 2,  "prestige": 0},   # 海盗湾
	45: {"gold": 5,  "food": 3,  "iron": 2,  "prestige": 0},   # 鬼火林
	46: {"gold": 5,  "food": 2,  "iron": 5,  "prestige": 0},   # 噬骨洞
	# --- Resource Stations (47-54) ---
	47: {"gold": 8,  "food": 2,  "iron": 3,  "prestige": 1},   # 魔晶矿脉
	48: {"gold": 10, "food": 10, "iron": 2,  "prestige": 1},   # 战马牧场
	49: {"gold": 10, "food": 2,  "iron": 15, "prestige": 1},   # 铁矿场
	50: {"gold": 8,  "food": 8,  "iron": 1,  "prestige": 1},   # 药草园
	51: {"gold": 8,  "food": 5,  "iron": 2,  "prestige": 1},   # 灵木林场
	52: {"gold": 8,  "food": 2,  "iron": 5,  "prestige": 1},   # 硫磺泉
	53: {"gold": 15, "food": 2,  "iron": 3,  "prestige": 2},   # 宝石洞
	54: {"gold": 10, "food": 2,  "iron": 10, "prestige": 1},   # 魔铁锻炉
}

# ---------------------------------------------------------------------------
# 3. TERRITORY_STRATEGIC_VALUE — AI importance score 1-10
# ---------------------------------------------------------------------------

const TERRITORY_STRATEGIC_VALUE: Dictionary = {
	# Human Kingdom — capitals and chokepoints score high
	0:  10,  # 天城王都 — capital, 4 connections, aura
	1:  8,   # 银冠要塞 — chokepoint, 6 connections, borders elves
	2:  9,   # 铁壁关 — chokepoint, borders dark elves + neutrals
	3:  4,   # 枫叶村 — food production village
	4:  5,   # 晨曦镇 — trade hub, central village
	5:  3,   # 柳河庄 — peripheral fishing village
	6:  7,   # 铁壁堡 — chokepoint, borders mages + neutrals
	7:  6,   # 狮鹫堡 — special unit unlock
	8:  7,   # 雷鸣关 — chokepoint, spell defense
	# Elven Domain
	9:  10,  # 世界树圣地 — capital, global heal aura
	10: 4,   # 白石村 — support village
	11: 4,   # 鹿角镇 — vision/scout village
	12: 7,   # 霜风哨 — chokepoint, borders neutrals
	13: 8,   # 月影关 — chokepoint, borders dark elves
	# Mage Alliance
	14: 10,  # 奥术堡垒 — capital, mana nexus
	15: 8,   # 翡翠尖塔 — chokepoint, teleport
	16: 4,   # 云雾庄 — support village
	17: 7,   # 龙脊要塞 — chokepoint, borders orcs
	18: 7,   # 星落堡 — chokepoint, divination
	# Orc Horde
	19: 10,  # 碎骨王座 — capital, WAAAGH center
	20: 4,   # 红叶镇 — plunder village
	21: 5,   # 焦土堡 — scorched earth defense
	22: 8,   # 血牙关 — chokepoint, borders mages + dark elves
	23: 5,   # 熔岩裂隙 — shadow resource
	# Pirate Coalition
	24: 9,   # 深渊港 — capital, black market
	25: 4,   # 碧水村 — smuggle support
	26: 6,   # 暗礁塔 — naval defense
	27: 6,   # 霜牙港 — chokepoint
	# Dark Elf Clan
	28: 10,  # 永夜暗城 — capital, global buff
	29: 5,   # 松风庄 — poison defense
	30: 7,   # 月影祭坛 — chokepoint, ritual site
	# Neutral Settlements
	31: 5,   # 行商驿站 — trade crossroads
	32: 4,   # 枯骨墓穴 — undead recruit
	33: 6,   # 绿影营地 — chokepoint, ranger recruit
	34: 5,   # 地精工坊 — crafting hub
	35: 3,   # 流浪马戏团 — morale support
	36: 5,   # 赏金猎人公会 — bounty missions
	# Bandit Lairs
	37: 3,   # 黑风寨
	38: 4,   # 落日盗窟 — stealth march
	39: 4,   # 毒蛇谷 — poison defense
	40: 5,   # 暗影巢穴 — assassin recruit
	41: 4,   # 断牙山寨 — mountain defense
	42: 4,   # 腐沼堡 — anti-cavalry
	43: 4,   # 秃鹫岭 — early warning
	44: 5,   # 海盗湾 — river network
	45: 3,   # 鬼火林 — maze defense
	46: 4,   # 噬骨洞 — shadow resource
	# Resource Stations
	47: 7,   # 魔晶矿脉 — crystal, contested
	48: 6,   # 战马牧场 — cavalry resource
	49: 6,   # 铁矿场 — iron output
	50: 5,   # 药草园 — healing
	51: 5,   # 灵木林场 — shadow resource
	52: 5,   # 硫磺泉 — gunpowder
	53: 6,   # 宝石洞 — gold + crystal
	54: 6,   # 魔铁锻炉 — magic equipment
}

# ---------------------------------------------------------------------------
# 4. TERRITORY_EVENTS — random events per territory
# ---------------------------------------------------------------------------

const TERRITORY_EVENTS: Dictionary = {
	# ===================================================================
	# HUMAN KINGDOM EVENTS
	# ===================================================================
	0: [
		{
			"event_id": "royal_parade",
			"name": "王室阅兵",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "王都举行盛大阅兵式，全城士气高涨。",
			"choices": [
				{"text": "大规模阅兵(花费20金)", "effects": {"gold": -20, "all_morale": 10, "prestige": 3}},
				{"text": "低调举行", "effects": {"prestige": 1}},
			],
		},
		{
			"event_id": "holy_relic_discovered",
			"name": "圣物出土",
			"trigger_chance": 0.05,
			"condition": "owned",
			"description": "工人在王都地下发掘出一件古老圣物。",
			"choices": [
				{"text": "公开展示(秩序+5)", "effects": {"order": 5, "prestige": 2}},
				{"text": "交给教会研究(DEF+2持续5回合)", "effects": {"temp_def_bonus": 2, "temp_duration": 5}},
			],
		},
	],
	1: [
		{
			"event_id": "silver_crown_refugees",
			"name": "难民涌入",
			"trigger_chance": 0.1,
			"condition": "enemy_adjacent",
			"description": "周边战事导致大量难民涌向银冠要塞。",
			"choices": [
				{"text": "接纳难民(粮食-5,驻军+3)", "effects": {"food": -5, "garrison": 3}},
				{"text": "关闭城门(秩序-3)", "effects": {"order": -3}},
			],
		},
	],
	2: [
		{
			"event_id": "iron_wall_challenge",
			"name": "铁壁挑战",
			"trigger_chance": 0.07,
			"condition": "owned",
			"description": "一位神秘武者前来挑战铁壁关守将。",
			"choices": [
				{"text": "接受挑战", "effects": {"hero_exp": 15, "prestige": 2}},
				{"text": "婉拒挑战", "effects": {"order": 1}},
			],
		},
	],
	3: [
		{
			"event_id": "bumper_harvest",
			"name": "大丰收",
			"trigger_chance": 0.12,
			"condition": "owned",
			"description": "今年风调雨顺，枫叶村迎来大丰收！",
			"choices": [
				{"text": "举办丰收节(粮+15,金-5)", "effects": {"food": 15, "gold": -5, "order": 3}},
				{"text": "储存粮食", "effects": {"food": 10}},
			],
		},
	],
	4: [
		{
			"event_id": "merchant_caravan",
			"name": "商队到来",
			"trigger_chance": 0.15,
			"condition": "owned",
			"description": "一支远方商队途经晨曦镇，带来稀有货物。",
			"choices": [
				{"text": "购买货物(金-15,获得随机装备)", "effects": {"gold": -15, "random_item": true}},
				{"text": "收取过路费(金+8)", "effects": {"gold": 8}},
			],
		},
	],
	7: [
		{
			"event_id": "griffin_egg",
			"name": "狮鹫蛋",
			"trigger_chance": 0.06,
			"condition": "owned",
			"description": "巡逻队在山上发现了一枚罕见的狮鹫蛋。",
			"choices": [
				{"text": "孵化培育(3回合后获得狮鹫骑士1)", "effects": {"delayed_unit": "griffin_knight", "delay_turns": 3}},
				{"text": "出售(金+25)", "effects": {"gold": 25}},
			],
		},
	],
	8: [
		{
			"event_id": "lightning_storm",
			"name": "雷暴来袭",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "剧烈雷暴笼罩雷鸣关，雷电击中城墙。",
			"choices": [
				{"text": "引导雷电充能法阵(法术伤害+10%持续3回合)", "effects": {"temp_spell_dmg_pct": 0.1, "temp_duration": 3}},
				{"text": "加固城墙(城防+5)", "effects": {"wall_repair": 5}},
			],
		},
	],
	# ===================================================================
	# ELVEN DOMAIN EVENTS
	# ===================================================================
	9: [
		{
			"event_id": "world_tree_bloom",
			"name": "世界树开花",
			"trigger_chance": 0.05,
			"condition": "owned",
			"description": "世界树百年一度地绽放花朵，灵力充盈大地。",
			"choices": [
				{"text": "举行祈福仪式(全领地HP+3)", "effects": {"global_heal": 3, "prestige": 5}},
				{"text": "收集花粉炼药(获得3瓶治愈药水)", "effects": {"item_heal_potion": 3}},
			],
		},
	],
	10: [
		{
			"event_id": "moonlit_visitor",
			"name": "月下访客",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "一位神秘的月光精灵造访白石村。",
			"choices": [
				{"text": "热情款待(获得月光祝福：夜间ATK+1持续5回合)", "effects": {"temp_night_atk": 1, "temp_duration": 5}},
				{"text": "请求指引(视野+1持续3回合)", "effects": {"temp_vision": 1, "temp_duration": 3}},
			],
		},
	],
	12: [
		{
			"event_id": "frost_wind_blizzard",
			"name": "暴风雪",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "突如其来的暴风雪席卷霜风哨。",
			"choices": [
				{"text": "利用暴雪设伏(下次防守战DEF+20%)", "effects": {"next_battle_def_pct": 0.2}},
				{"text": "紧急转移物资(损失食物3,保全军队)", "effects": {"food": -3}},
			],
		},
	],
	13: [
		{
			"event_id": "phantom_sighting",
			"name": "幻影目击",
			"trigger_chance": 0.08,
			"condition": "enemy_adjacent",
			"description": "巡逻队报告在月影关附近看到敌方斥候的幻影。",
			"choices": [
				{"text": "加强幻阵(迷路概率+10%持续3回合)", "effects": {"temp_lost_chance": 0.1, "temp_duration": 3}},
				{"text": "派出侦察(获取敌方情报)", "effects": {"intel_reveal": true}},
			],
		},
	],
	# ===================================================================
	# MAGE ALLIANCE EVENTS
	# ===================================================================
	14: [
		{
			"event_id": "arcane_surge",
			"name": "奥术涌动",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "奥术堡垒地脉异动，法力激增但不稳定。",
			"choices": [
				{"text": "尝试驾驭(法力+10,5%失控导致城防-5)", "effects": {"mana": 10, "risk_wall_dmg": 5, "risk_chance": 0.05}},
				{"text": "安全疏导(法力+3)", "effects": {"mana": 3}},
			],
		},
	],
	15: [
		{
			"event_id": "portal_fluctuation",
			"name": "传送门波动",
			"trigger_chance": 0.07,
			"condition": "owned",
			"description": "翡翠尖塔的传送门出现异常波动，连接到未知空间。",
			"choices": [
				{"text": "探索未知空间(获得随机法术卷轴)", "effects": {"random_spell_scroll": true}},
				{"text": "关闭稳定(传送门安全性+)", "effects": {"portal_stable": true}},
			],
		},
	],
	17: [
		{
			"event_id": "dragon_bone_resonance",
			"name": "龙骨共鸣",
			"trigger_chance": 0.06,
			"condition": "owned",
			"description": "龙脊要塞地下的远古龙骨发出低沉共鸣。",
			"choices": [
				{"text": "提取龙骨精华(全军ATK+1持续3回合)", "effects": {"temp_all_atk": 1, "temp_duration": 3}},
				{"text": "封印龙骨(城防+8永久)", "effects": {"wall_bonus": 8}},
			],
		},
	],
	18: [
		{
			"event_id": "falling_star",
			"name": "流星坠落",
			"trigger_chance": 0.05,
			"condition": "owned",
			"description": "一颗流星坠落在星落堡附近，蕴含神秘力量。",
			"choices": [
				{"text": "收集陨石(获得星铁材料x2)", "effects": {"star_iron": 2}},
				{"text": "研究星能(占卜范围扩大1格持续5回合)", "effects": {"temp_divination_range": 1, "temp_duration": 5}},
			],
		},
	],
	# ===================================================================
	# ORC HORDE EVENTS
	# ===================================================================
	19: [
		{
			"event_id": "waaagh_frenzy",
			"name": "WAAAGH狂潮",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "碎骨王座的兽人陷入战斗狂热！",
			"choices": [
				{"text": "引导狂热(WAAAGH+15,消耗粮食10)", "effects": {"waaagh": 15, "food": -10}},
				{"text": "压制狂热(秩序+5)", "effects": {"order": 5}},
			],
		},
		{
			"event_id": "pit_fight",
			"name": "角斗场",
			"trigger_chance": 0.12,
			"condition": "owned",
			"description": "兽人要求举办角斗大赛。",
			"choices": [
				{"text": "举办角斗(金+10,可能损失1兵)", "effects": {"gold": 10, "risk_garrison_loss": 1, "risk_chance": 0.3}},
				{"text": "禁止角斗(士气-3)", "effects": {"morale": -3}},
			],
		},
	],
	20: [
		{
			"event_id": "raiding_party_return",
			"name": "劫掠队归来",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "一支劫掠小队满载而归。",
			"choices": [
				{"text": "接收战利品(金+12,铁+3)", "effects": {"gold": 12, "iron": 3}},
				{"text": "犒赏战士(驻军+2)", "effects": {"garrison": 2}},
			],
		},
	],
	22: [
		{
			"event_id": "blood_moon",
			"name": "血月升起",
			"trigger_chance": 0.07,
			"condition": "owned",
			"description": "血红色的月亮高悬血牙关上空，兽人血性大发。",
			"choices": [
				{"text": "举行血祭(阵亡加成上限+2持续5回合)", "effects": {"temp_death_atk_cap_bonus": 2, "temp_duration": 5}},
				{"text": "冷静备战(DEF+3持续3回合)", "effects": {"temp_def": 3, "temp_duration": 3}},
			],
		},
	],
	23: [
		{
			"event_id": "lava_eruption",
			"name": "熔岩喷发",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "熔岩裂隙活动加剧，岩浆涌出地表。",
			"choices": [
				{"text": "引导岩浆锻造(获得熔岩武器1件)", "effects": {"item_lava_weapon": 1}},
				{"text": "紧急撤离(损失驻军1)", "effects": {"garrison": -1}},
			],
		},
	],
	# ===================================================================
	# PIRATE COALITION EVENTS
	# ===================================================================
	24: [
		{
			"event_id": "smuggler_ship",
			"name": "走私船靠港",
			"trigger_chance": 0.12,
			"condition": "owned",
			"description": "一艘满载违禁品的走私船停靠深渊港。",
			"choices": [
				{"text": "收购货物(金-20,获得稀有物品)", "effects": {"gold": -20, "random_rare_item": true}},
				{"text": "扣押船只(金+15,铁+5)", "effects": {"gold": 15, "iron": 5}},
			],
		},
	],
	25: [
		{
			"event_id": "informant_tip",
			"name": "线人密报",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "碧水村的线人带来了敌方动向的情报。",
			"choices": [
				{"text": "购买情报(金-8,揭示敌方行动)", "effects": {"gold": -8, "intel_reveal": true}},
				{"text": "忽略情报", "effects": {}},
			],
		},
	],
	26: [
		{
			"event_id": "reef_shipwreck",
			"name": "暗礁沉船",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "一艘商船在暗礁搁浅，货物散落。",
			"choices": [
				{"text": "打捞货物(金+12)", "effects": {"gold": 12}},
				{"text": "救助船员(获得2名水手兵)", "effects": {"garrison": 2}},
			],
		},
	],
	# ===================================================================
	# DARK ELF CLAN EVENTS
	# ===================================================================
	28: [
		{
			"event_id": "shadow_convergence",
			"name": "暗影汇聚",
			"trigger_chance": 0.07,
			"condition": "owned",
			"description": "永夜暗城的暗影能量异常汇聚。",
			"choices": [
				{"text": "吸收暗影(暗影精华+3)", "effects": {"shadow_essence": 3}},
				{"text": "释放暗影冲击(相邻敌方驻军-2)", "effects": {"adjacent_enemy_garrison": -2}},
			],
		},
	],
	29: [
		{
			"event_id": "poison_bloom",
			"name": "毒花盛开",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "松风庄的剧毒花卉迎来盛放季节。",
			"choices": [
				{"text": "采集毒素(毒伤害+1持续5回合)", "effects": {"temp_poison_bonus": 1, "temp_duration": 5}},
				{"text": "制作解毒剂(获得解毒药水x3)", "effects": {"item_antidote": 3}},
			],
		},
	],
	30: [
		{
			"event_id": "dark_ritual_opportunity",
			"name": "仪式良机",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "月影祭坛的星象显示暗影仪式将获得双倍效果。",
			"choices": [
				{"text": "执行强化仪式(消耗奴隶2,全属性+2持续3回合)", "effects": {"slave_cost": 2, "temp_all_stats": 2, "temp_duration": 3}},
				{"text": "蓄积力量(暗影精华+2)", "effects": {"shadow_essence": 2}},
			],
		},
	],
	# ===================================================================
	# NEUTRAL SETTLEMENT EVENTS
	# ===================================================================
	31: [
		{
			"event_id": "trade_fair",
			"name": "集市繁荣",
			"trigger_chance": 0.12,
			"condition": "owned",
			"description": "行商驿站迎来大型集市，商贾云集。",
			"choices": [
				{"text": "征收商税(金+15)", "effects": {"gold": 15}},
				{"text": "免税招商(下3回合金+5/回合)", "effects": {"temp_gold_per_turn": 5, "temp_duration": 3}},
			],
		},
	],
	32: [
		{
			"event_id": "undead_rising",
			"name": "亡灵复苏",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "枯骨墓穴深处传来异响，亡灵开始躁动。",
			"choices": [
				{"text": "驱使亡灵(骷髅兵+3)", "effects": {"skeleton_recruit": 3}},
				{"text": "封印墓穴(秩序+5,暗影精华+1)", "effects": {"order": 5, "shadow_essence": 1}},
			],
		},
	],
	33: [
		{
			"event_id": "ranger_gathering",
			"name": "游侠聚会",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "四方游侠齐聚绿影营地，交流见闻。",
			"choices": [
				{"text": "请求协助(视野+2持续3回合)", "effects": {"temp_vision": 2, "temp_duration": 3}},
				{"text": "招募游侠(游侠+1,金-10)", "effects": {"recruit_ranger": 1, "gold": -10}},
			],
		},
	],
	34: [
		{
			"event_id": "goblin_invention",
			"name": "地精发明",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "地精工匠声称发明了一种新型武器。",
			"choices": [
				{"text": "资助研发(金-15,50%获得攻城器械)", "effects": {"gold": -15, "chance_siege_weapon": 0.5}},
				{"text": "购买成品(铁+8)", "effects": {"iron": 8}},
			],
		},
	],
	35: [
		{
			"event_id": "circus_performance",
			"name": "盛大演出",
			"trigger_chance": 0.15,
			"condition": "owned",
			"description": "马戏团准备了一场空前绝后的演出。",
			"choices": [
				{"text": "售票观赏(金+12,秩序+3)", "effects": {"gold": 12, "order": 3}},
				{"text": "邀请英雄观赏(英雄好感+5)", "effects": {"hero_favor": 5}},
			],
		},
	],
	36: [
		{
			"event_id": "bounty_target",
			"name": "高价悬赏",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "赏金猎人公会发布了一份高价悬赏令。",
			"choices": [
				{"text": "接取悬赏(派遣英雄,获得金+25和声望+3)", "effects": {"gold": 25, "prestige": 3, "hero_unavailable_turns": 2}},
				{"text": "发布自己的悬赏(金-20,削弱敌方英雄)", "effects": {"gold": -20, "enemy_hero_debuff": true}},
			],
		},
	],
	# ===================================================================
	# BANDIT LAIR EVENTS
	# ===================================================================
	37: [
		{
			"event_id": "bandit_infighting",
			"name": "匪寨内讧",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "黑风寨的匪徒因分赃不均发生内讧。",
			"choices": [
				{"text": "调解纠纷(秩序+3)", "effects": {"order": 3}},
				{"text": "坐收渔利(金+8,驻军-1)", "effects": {"gold": 8, "garrison": -1}},
			],
		},
	],
	38: [
		{
			"event_id": "tunnel_discovery",
			"name": "发现新通道",
			"trigger_chance": 0.07,
			"condition": "owned",
			"description": "落日盗窟发现了一条通往远方的秘密通道。",
			"choices": [
				{"text": "探索通道(获得秘密路线,首次使用免费)", "effects": {"secret_route": true}},
				{"text": "封闭通道(防止敌方利用,DEF+3)", "effects": {"def_bonus": 3}},
			],
		},
	],
	39: [
		{
			"event_id": "venom_harvest",
			"name": "毒液丰收",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "毒蛇谷的毒蛇异常活跃，毒液产量大增。",
			"choices": [
				{"text": "收集毒液(淬毒武器:ATK+1持续5回合)", "effects": {"temp_poison_atk": 1, "temp_duration": 5}},
				{"text": "驱赶毒蛇(安全性提升,秩序+5)", "effects": {"order": 5}},
			],
		},
	],
	40: [
		{
			"event_id": "assassin_contract",
			"name": "暗杀委托",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "有人向暗影巢穴提交了一份暗杀委托。",
			"choices": [
				{"text": "接受委托(金+20,声望-2)", "effects": {"gold": 20, "prestige": -2}},
				{"text": "拒绝委托(声望+1)", "effects": {"prestige": 1}},
			],
		},
	],
	42: [
		{
			"event_id": "swamp_gas",
			"name": "沼气爆发",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "腐沼堡附近沼气异常聚集。",
			"choices": [
				{"text": "引燃沼气(对相邻敌方造成伤害)", "effects": {"adjacent_enemy_dmg": 3}},
				{"text": "疏散人员(驻军暂时-1,避免损失)", "effects": {"garrison": -1}},
			],
		},
	],
	43: [
		{
			"event_id": "vulture_omen",
			"name": "秃鹫预兆",
			"trigger_chance": 0.1,
			"condition": "enemy_adjacent",
			"description": "秃鹫大量聚集在秃鹫岭上空，预示着战争临近。",
			"choices": [
				{"text": "加强警戒(侦察范围+1持续3回合)", "effects": {"temp_scout_range": 1, "temp_duration": 3}},
				{"text": "散布谣言(敌方士气-5)", "effects": {"enemy_morale": -5}},
			],
		},
	],
	44: [
		{
			"event_id": "river_flood",
			"name": "河水暴涨",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "连日暴雨导致河水暴涨，海盗湾受到影响。",
			"choices": [
				{"text": "抢修堤坝(金-5,保全设施)", "effects": {"gold": -5}},
				{"text": "趁乱捕鱼(粮食+8)", "effects": {"food": 8}},
			],
		},
	],
	45: [
		{
			"event_id": "ghost_fire_surge",
			"name": "鬼火暴走",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "鬼火林中的鬼火突然增多，迷幻效果增强。",
			"choices": [
				{"text": "收集鬼火(暗影精华+1)", "effects": {"shadow_essence": 1}},
				{"text": "利用鬼火布阵(迷路概率+15%持续3回合)", "effects": {"temp_lost_chance": 0.15, "temp_duration": 3}},
			],
		},
	],
	46: [
		{
			"event_id": "bone_cave_tremor",
			"name": "洞穴震动",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "噬骨洞深处传来震动，似有古物松动。",
			"choices": [
				{"text": "深入探索(获得暗影精华+2,5%驻军-1)", "effects": {"shadow_essence": 2, "risk_garrison_loss": 1, "risk_chance": 0.05}},
				{"text": "加固洞穴(DEF+2)", "effects": {"def_bonus": 2}},
			],
		},
	],
	# ===================================================================
	# RESOURCE STATION EVENTS
	# ===================================================================
	47: [
		{
			"event_id": "crystal_overload",
			"name": "魔晶过载",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "魔晶矿脉能量异常集中，矿石品质飙升。",
			"choices": [
				{"text": "加速开采(魔晶+3,矿场损耗加剧)", "effects": {"crystal": 3, "temp_production_penalty": -1, "temp_duration": 2}},
				{"text": "稳定开采(魔晶+1)", "effects": {"crystal": 1}},
			],
		},
	],
	48: [
		{
			"event_id": "wild_stallion",
			"name": "野马群出现",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "一群野马出现在战马牧场附近。",
			"choices": [
				{"text": "捕捉驯化(战马+2)", "effects": {"horse": 2}},
				{"text": "驱赶保护牧场(防止牧场损坏)", "effects": {"order": 2}},
			],
		},
	],
	49: [
		{
			"event_id": "rich_vein",
			"name": "发现富矿",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "矿工在铁矿场深处发现了一条品质极高的矿脉。",
			"choices": [
				{"text": "集中开采(铁+10)", "effects": {"iron": 10}},
				{"text": "稳步开发(铁+3/回合持续3回合)", "effects": {"temp_iron_per_turn": 3, "temp_duration": 3}},
			],
		},
	],
	50: [
		{
			"event_id": "rare_herb",
			"name": "珍稀药草",
			"trigger_chance": 0.1,
			"condition": "owned",
			"description": "药草园中发现了一株极其珍稀的药草。",
			"choices": [
				{"text": "制作灵药(英雄全恢复)", "effects": {"hero_full_heal": true}},
				{"text": "培育扩种(药草产出+1/回合永久)", "effects": {"herb_production_permanent": 1}},
			],
		},
	],
	53: [
		{
			"event_id": "gem_cache",
			"name": "宝石矿室",
			"trigger_chance": 0.07,
			"condition": "owned",
			"description": "矿工挖通了一个天然宝石矿室，光彩夺目。",
			"choices": [
				{"text": "全部开采(金+25)", "effects": {"gold": 25}},
				{"text": "分批开采(金+5/回合持续5回合)", "effects": {"temp_gold_per_turn": 5, "temp_duration": 5}},
			],
		},
	],
	54: [
		{
			"event_id": "geothermal_surge",
			"name": "地热涌动",
			"trigger_chance": 0.08,
			"condition": "owned",
			"description": "魔铁锻炉下方地热活动加剧，锻造温度升高。",
			"choices": [
				{"text": "趁热锻造(获得魔铁装备1件)", "effects": {"item_magic_iron_gear": 1}},
				{"text": "收集火药原料(火药+3)", "effects": {"gunpowder": 3}},
			],
		},
	],
}

# ---------------------------------------------------------------------------
# 5. Helper functions
# ---------------------------------------------------------------------------

static func get_effect(territory_id: int) -> Dictionary:
	return TERRITORY_SPECIAL_EFFECTS.get(territory_id, {})


static func get_production(territory_id: int) -> Dictionary:
	return TERRITORY_PRODUCTION.get(territory_id, {"gold": 0, "food": 0, "iron": 0, "prestige": 0})


static func get_strategic_value(territory_id: int) -> int:
	return TERRITORY_STRATEGIC_VALUE.get(territory_id, 1)


static func get_events(territory_id: int) -> Array:
	return TERRITORY_EVENTS.get(territory_id, [])


## Return all effects that belong to a given category.
static func get_effects_by_category(category: String) -> Array:
	var results: Array = []
	for tid in TERRITORY_SPECIAL_EFFECTS:
		var eff: Dictionary = TERRITORY_SPECIAL_EFFECTS[tid]
		if eff.get("category", "") == category:
			results.append({"territory_id": tid, "effect": eff})
	return results


## Return aura effects from neighboring territories whose aura_range >= 1.
static func get_aura_effects(territory_id: int, adjacency: Dictionary) -> Array:
	var results: Array = []
	var neighbors: Array = adjacency.get(territory_id, [])
	for nid in neighbors:
		var eff: Dictionary = TERRITORY_SPECIAL_EFFECTS.get(nid, {})
		if eff.is_empty():
			continue
		var aura: int = eff.get("aura_range", 0)
		if aura >= 1:
			results.append({"source_territory": nid, "effect": eff})
	return results


## Calculate total production after applying nation bonuses and local effect modifiers.
static func calculate_total_production(territory_id: int, owner_bonuses: Dictionary) -> Dictionary:
	var base: Dictionary = get_production(territory_id).duplicate()
	# Apply owner-level flat bonuses
	for key in ["gold", "food", "iron", "prestige"]:
		base[key] = base.get(key, 0) + owner_bonuses.get(key + "_flat", 0)
	# Apply owner-level percentage bonuses
	for key in ["gold", "food", "iron", "prestige"]:
		var pct: float = owner_bonuses.get(key + "_pct", 0.0)
		if pct != 0.0:
			base[key] = int(base[key] * (1.0 + pct))
	# Apply territory special effect modifiers
	var eff: Dictionary = get_effect(territory_id)
	var mods: Dictionary = eff.get("modifiers", {})
	if mods.has("gold_per_turn"):
		base["gold"] += mods["gold_per_turn"]
	if mods.has("food_per_turn"):
		base["food"] += mods["food_per_turn"]
	if mods.has("iron_per_turn"):
		base["iron"] += mods["iron_per_turn"]
	if mods.has("prestige_per_turn"):
		base["prestige"] += mods["prestige_per_turn"]
	if mods.has("food_pct"):
		base["food"] = int(base["food"] * (1.0 + mods["food_pct"]))
	if mods.has("gold_pct"):
		base["gold"] = int(base["gold"] * (1.0 + mods["gold_pct"]))
	return base
