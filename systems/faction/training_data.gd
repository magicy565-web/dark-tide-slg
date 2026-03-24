## training_data.gd — Per-faction training trees and AI threat scaling data.
## Split from faction_data.gd to reduce file size (design: §7 训练系统).
## Static data only — no state. Referenced by ResearchManager and AIScaling.
class_name TrainingData
extends RefCounted
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Training System (v0.8.5 - Per-Faction Training) ──
# Training is PLAYER-ONLY. AI factions scale via threat value instead.
# Each evil faction has its own complete training tree covering their available units.
# Research requires Academy building.

enum TechBranch { VANGUARD, RANGED, MOBILE, MAGIC, FACTION_SPECIAL }
enum TechTier { BASIC, ADVANCED, ULTIMATE }

const RESEARCH_BASE_SPEED: float = 1.0

# ── Faction Unit Availability ──
static var FACTION_AVAILABLE_UNITS: Dictionary = {
	FactionData.FactionID.ORC: ["ashigaru", "samurai", "priest", "mage_unit", "grunt", "troll", "warg_rider"],
	FactionData.FactionID.PIRATE: ["archer", "cannon", "cavalry", "ninja", "cutthroat", "gunner", "bombardier"],
	FactionData.FactionID.DARK_ELF: ["ninja", "priest", "mage_unit", "shadow_walker", "assassin", "cold_lizard", "warrior"],
}

# ── Per-Faction Training Trees ──
# Each faction has ~9 nodes: 4×T1 + 4×T2 + 1×T3
# PLACEHOLDER: skeleton with ORC tree inline, PIRATE and DARK_ELF follow
static var FACTION_TRAINING_TREE: Dictionary = {
	# ═══ 兽人训练树 — WAAAGH!蛮力路线 ═══
	FactionData.FactionID.ORC: {
		"orc_vanguard_basic": {
			"name": "前卫操练·兽人式", "branch": TechBranch.VANGUARD, "tier": TechTier.BASIC,
			"cost": {"gold": 180, "iron": 25}, "turns": 2, "prereqs": [],
			"desc": "足轻/武士 ATK+3, DEF+3, HP+1",
			"effects": {"unit_buff": {"types": ["ashigaru", "samurai"], "atk": 3, "def": 3, "hp": 1}},
		},
		"orc_support_basic": {
			"name": "祭战一体", "branch": TechBranch.MAGIC, "tier": TechTier.BASIC,
			"cost": {"gold": 160, "iron": 15, "crystal": 1}, "turns": 2, "prereqs": [],
			"desc": "祭司/術師 INT+2, 法力上限+3",
			"effects": {"unit_buff": {"types": ["priest", "mage_unit"], "int": 2, "mana_cap": 3}},
		},
		"orc_warcry_basic": {
			"name": "战吼鼓舞", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.BASIC,
			"cost": {"gold": 200, "iron": 25}, "turns": 2, "prereqs": [],
			"desc": "兽人全单位ATK+3, DEF+1, 粮食消耗-10%",
			"effects": {"unit_buff": {"types": ["grunt", "troll", "warg_rider"], "atk": 3, "def": 1}, "food_consume_reduction": 0.10},
		},
		"orc_morale_basic": {
			"name": "蛮族士气", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.BASIC,
			"cost": {"gold": 150}, "turns": 1, "prereqs": [],
			"desc": "全军士气上限+10, WAAAGH!每回合+1",
			"effects": {"morale_cap_bonus": 10, "waaagh_regen_bonus": 1},
		},
		"orc_berserker": {
			"name": "狂暴突击", "branch": TechBranch.VANGUARD, "tier": TechTier.ADVANCED,
			"cost": {"gold": 350, "iron": 40}, "turns": 3,
			"prereqs": ["orc_vanguard_basic", "orc_warcry_basic"],
			"desc": "[被动] 足轻/武士·狂暴: HP<50%时ATK+25%, 武士反击+20%",
			"effects": {"unit_passive": {"type": "ashigaru", "id": "berserker", "low_hp_atk_mult": 1.25}, "unit_passive_2": {"type": "samurai", "id": "bushido", "low_hp_atk_mult": 1.30, "counter_bonus": 0.20}},
		},
		"orc_troll_regen": {
			"name": "巨魔·暴怒再生", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.ADVANCED,
			"cost": {"gold": 300, "iron": 40}, "turns": 3,
			"prereqs": ["orc_warcry_basic"],
			"desc": "[被动] 巨魔再生+2兵/回合, HP<30%时ATK+40%",
			"effects": {"unit_passive": {"type": "troll", "id": "rage_regen", "regen_bonus": 2, "low_hp_atk_mult": 1.40}},
		},
		"orc_warg_charge": {
			"name": "战猪骑兵·蛮力冲锋", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.ADVANCED,
			"cost": {"gold": 280, "iron": 35}, "turns": 3,
			"prereqs": ["orc_warcry_basic"],
			"desc": "[被动] 战猪冲锋×2.0, 冲锋击退敌方前排1格",
			"effects": {"unit_passive": {"type": "warg_rider", "id": "brutal_charge", "charge_mult": 2.0, "knockback": true}},
		},
		"orc_blood_ritual": {
			"name": "血祭术", "branch": TechBranch.MAGIC, "tier": TechTier.ADVANCED,
			"cost": {"gold": 350, "iron": 25, "crystal": 2}, "turns": 3,
			"prereqs": ["orc_support_basic"],
			"desc": "[被动] 術師·血祭: 消耗10%己方HP, 法术伤害×1.8",
			"effects": {"unit_passive": {"type": "mage_unit", "id": "blood_ritual", "hp_cost_pct": 0.10, "spell_mult": 1.8}},
		},
		"orc_ultimate": {
			"name": "WAAAGH!怒吼", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.ULTIMATE,
			"cost": {"gold": 600, "iron": 55}, "turns": 4,
			"prereqs": ["orc_berserker", "orc_troll_regen"],
			"desc": "[主动] 消耗20 WAAAGH!→全军ATK×1.5(1回合)+免士气下降 (CD:5)",
			"effects": {"unit_active": {"type": "all_orc", "id": "waaagh_roar", "atk_mult": 1.5, "duration": 1, "morale_immune": true, "waaagh_cost": 20, "cooldown": 5}},
		},
		"logistics_mastery": {
			"name": "兵站精通", "branch": TechBranch.VANGUARD, "tier": TechTier.ADVANCED,
			"cost": {"gold": 400, "iron": 40}, "turns": 3,
			"prereqs": ["orc_vanguard_basic"],
			"desc": "军团上限+1, 补给线安全距离+1",
			"effects": {"army_cap_bonus": 1, "supply_range_bonus": 1},
		},
	},

	# ═══ 海盗训练树 — 掠夺机动路线 ═══
	FactionData.FactionID.PIRATE: {
		"pirate_ranged_basic": {
			"name": "射击训练·海盗式", "branch": TechBranch.RANGED, "tier": TechTier.BASIC,
			"cost": {"gold": 180, "iron": 20}, "turns": 2, "prereqs": [],
			"desc": "弓兵/砲兵 ATK+3, 射程+1",
			"effects": {"unit_buff": {"types": ["archer", "cannon"], "atk": 3, "range": 1}},
		},
		"pirate_mobile_basic": {
			"name": "机动训练·海盗式", "branch": TechBranch.MOBILE, "tier": TechTier.BASIC,
			"cost": {"gold": 160, "iron": 20}, "turns": 2, "prereqs": [],
			"desc": "骑兵/忍者 SPD+2, ATK+2",
			"effects": {"unit_buff": {"types": ["cavalry", "ninja"], "spd": 2, "atk": 2}},
		},
		"pirate_crew_basic": {
			"name": "海盗战训", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.BASIC,
			"cost": {"gold": 150, "iron": 15}, "turns": 2, "prereqs": [],
			"desc": "海盗全单位ATK+2, SPD+2, 沿海地形ATK+2",
			"effects": {"unit_buff": {"types": ["cutthroat", "gunner", "bombardier"], "atk": 2, "spd": 2}, "coastal_atk_bonus": 2},
		},
		"pirate_plunder_basic": {
			"name": "掠夺之道", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.BASIC,
			"cost": {"gold": 130}, "turns": 1, "prereqs": [],
			"desc": "战斗胜利后获得额外金币(击杀数×10), 占领掠夺+25%",
			"effects": {"kill_gold_bonus": 10, "capture_plunder_bonus": 0.25},
		},
		"pirate_volley": {
			"name": "齐射战术", "branch": TechBranch.RANGED, "tier": TechTier.ADVANCED,
			"cost": {"gold": 350, "iron": 30}, "turns": 3,
			"prereqs": ["pirate_ranged_basic"],
			"desc": "[被动] 弓兵·齐射: 集火伤害+30%, 砲兵·连环炮: 25%追加半伤射击",
			"effects": {"unit_passive": {"type": "archer", "id": "volley", "focus_fire_bonus": 0.30}, "unit_passive_2": {"type": "cannon", "id": "chain_shot", "extra_shot_chance": 0.25, "extra_shot_mult": 0.50}},
		},
		"pirate_gunner_dualshot": {
			"name": "火枪手·连射", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.ADVANCED,
			"cost": {"gold": 280, "iron": 30}, "turns": 3,
			"prereqs": ["pirate_crew_basic"],
			"desc": "[被动] 火枪手双重射击(×0.7×2次), 先制攻击×1.5",
			"effects": {"unit_passive": {"type": "gunner", "id": "double_shot", "shots": 2, "shot_mult": 0.7, "first_strike_mult": 1.5}},
		},
		"pirate_bombardier_ap": {
			"name": "炮击手·穿甲弹", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.ADVANCED,
			"cost": {"gold": 300, "iron": 40, "gunpowder": 2}, "turns": 3,
			"prereqs": ["pirate_crew_basic"],
			"desc": "[被动] 炮击手无视DEF30%, 对城防×2.5",
			"effects": {"unit_passive": {"type": "bombardier", "id": "armor_piercing", "def_ignore": 0.30, "siege_mult": 2.5}},
		},
		"pirate_smoke": {
			"name": "烟雾弹", "branch": TechBranch.MOBILE, "tier": TechTier.ADVANCED,
			"cost": {"gold": 300, "iron": 25}, "turns": 3,
			"prereqs": ["pirate_mobile_basic"],
			"desc": "[被动] 忍者·烟雾: 己方列全体1回合闪避+30%, 骑兵冲锋×1.8不耗行动",
			"effects": {"unit_passive": {"type": "ninja", "id": "smoke_bomb", "column_evasion": 0.30, "evasion_turns": 1}, "unit_passive_2": {"type": "cavalry", "id": "swift_charge", "first_strike_mult": 1.8, "charge_no_exhaust": true}},
		},
		"pirate_ultimate": {
			"name": "黑旗恐惧", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.ULTIMATE,
			"cost": {"gold": 600, "iron": 45, "gunpowder": 3}, "turns": 4,
			"prereqs": ["pirate_volley", "pirate_gunner_dualshot"],
			"desc": "[主动] 敌方ATK-20%/DEF-10%(2回合)+25%逃兵 (CD:5)",
			"effects": {"unit_active": {"type": "all_pirate", "id": "black_flag_terror", "enemy_atk_debuff": 0.20, "enemy_def_debuff": 0.10, "duration": 2, "desert_chance": 0.25, "cooldown": 5}},
		},
		"logistics_mastery": {
			"name": "兵站精通", "branch": TechBranch.RANGED, "tier": TechTier.ADVANCED,
			"cost": {"gold": 400, "iron": 35}, "turns": 3,
			"prereqs": ["pirate_crew_basic"],
			"desc": "军团上限+1, 补给线安全距离+1",
			"effects": {"army_cap_bonus": 1, "supply_range_bonus": 1},
		},
	},

	# ═══ 暗精灵训练树 — 暗影诡计路线 ═══
	FactionData.FactionID.DARK_ELF: {
		"delf_stealth_basic": {
			"name": "暗影潜行术", "branch": TechBranch.MOBILE, "tier": TechTier.BASIC,
			"cost": {"gold": 180, "iron": 20}, "turns": 2, "prereqs": [],
			"desc": "忍者首回合不可被选为目标, SPD+2",
			"effects": {"unit_buff": {"types": ["ninja"], "spd": 2}, "unit_passive": {"type": "ninja", "id": "stealth_basic", "first_turn_untargetable": true}},
		},
		"delf_magic_basic": {
			"name": "黑魔研习", "branch": TechBranch.MAGIC, "tier": TechTier.BASIC,
			"cost": {"gold": 180, "iron": 15, "crystal": 1}, "turns": 2, "prereqs": [],
			"desc": "祭司/術師 INT+3, 法术伤害+15%",
			"effects": {"unit_buff": {"types": ["priest", "mage_unit"], "int": 3}, "spell_damage_global": 0.15},
		},
		"delf_warrior_basic": {
			"name": "暗精灵战训", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.BASIC,
			"cost": {"gold": 160, "iron": 20}, "turns": 2, "prereqs": [],
			"desc": "暗精灵全单位DEF+2, INT+2, 暗影地形ATK+3",
			"effects": {"unit_buff": {"types": ["warrior", "assassin", "cold_lizard"], "def": 2, "int": 2}, "shadow_terrain_atk": 3},
		},
		"delf_shadow_walker": {
			"name": "暗影行者训练", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.BASIC,
			"cost": {"gold": 250, "iron": 25, "shadow": 1}, "turns": 2, "prereqs": [],
			"desc": "解锁专属单位'暗影行者'(隐匿近战刺客: HP80/ATK45/DEF15/SPD12)",
			"effects": {"unlock_unit": "shadow_walker"},
		},
		"delf_erosion": {
			"name": "精神侵蚀", "branch": TechBranch.MAGIC, "tier": TechTier.ADVANCED,
			"cost": {"gold": 350, "iron": 20, "crystal": 2}, "turns": 3,
			"prereqs": ["delf_magic_basic"],
			"desc": "[被动] 術師攻击附带2回合持续伤害(8%ATK/回合), 祭司治愈附加护盾",
			"effects": {"unit_passive": {"type": "mage_unit", "id": "erosion", "dot_pct": 0.08, "dot_turns": 2}, "unit_passive_2": {"type": "priest", "id": "dark_heal", "shield_pct": 0.30}},
		},
		"delf_assassin_venom": {
			"name": "暗影刺客·致命毒刃", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.ADVANCED,
			"cost": {"gold": 280, "iron": 25, "shadow": 1}, "turns": 3,
			"prereqs": ["delf_warrior_basic"],
			"desc": "[被动] 刺客攻击附带中毒(-1兵/回合×2), 背刺+50%",
			"effects": {"unit_passive": {"type": "assassin", "id": "venom_blade", "poison_dot": 1, "poison_turns": 2, "backstab_bonus": 0.50}},
		},
		"delf_shadow_clone": {
			"name": "幽影分身", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.ADVANCED,
			"cost": {"gold": 300, "iron": 30, "shadow": 1}, "turns": 3,
			"prereqs": ["delf_shadow_walker"],
			"desc": "[被动] 暗影行者被攻击25%闪避, 击杀后可再行动",
			"effects": {"unit_passive": {"type": "shadow_walker", "id": "shadow_clone", "dodge_chance": 0.25, "kill_extra_action": true}},
		},
		"delf_intel_net": {
			"name": "情报网络", "branch": TechBranch.MOBILE, "tier": TechTier.ADVANCED,
			"cost": {"gold": 280, "iron": 15}, "turns": 3,
			"prereqs": ["delf_stealth_basic"],
			"desc": "[被动] 战前可查看敌军完整编制, 忍者地形ATK+25%",
			"effects": {"intel_reveal": true, "unit_passive": {"type": "ninja", "id": "terrain_mastery", "terrain_atk_bonus": 0.25}},
		},
		"delf_ultimate": {
			"name": "暗影支配", "branch": TechBranch.FACTION_SPECIAL, "tier": TechTier.ULTIMATE,
			"cost": {"gold": 600, "iron": 40, "shadow": 3}, "turns": 4,
			"prereqs": ["delf_erosion", "delf_intel_net"],
			"desc": "[主动] 控制1敌方单位1回合+全军隐匿(首击免伤) (CD:6)",
			"effects": {"unit_active": {"type": "all_dark_elf", "id": "shadow_domination", "mind_control_targets": 1, "mind_control_turns": 1, "team_stealth": true, "cooldown": 6}},
		},
		"logistics_mastery": {
			"name": "兵站精通", "branch": TechBranch.MOBILE, "tier": TechTier.ADVANCED,
			"cost": {"gold": 400, "iron": 30, "shadow": 1}, "turns": 3,
			"prereqs": ["delf_warrior_basic"],
			"desc": "军团上限+1, 补给线安全距离+1",
			"effects": {"army_cap_bonus": 1, "supply_range_bonus": 1},
		},
	},
}

# ── AI Threat Scaling Data (replaces AI tech tree) ──
# AI factions do NOT use training. Their combat stats scale with threat tiers.
const AI_THREAT_SCALING: Dictionary = {
	"tiers": {
		0: {"name": "常态", "atk_mult": 1.0, "def_mult": 1.0, "hp_mult": 1.0, "garrison_regen_bonus": 0, "wall_bonus": 0.0},
		1: {"name": "防御态势", "atk_mult": 1.10, "def_mult": 1.15, "hp_mult": 1.0, "garrison_regen_bonus": 1, "wall_bonus": 0.20},
		2: {"name": "军事动员", "atk_mult": 1.20, "def_mult": 1.25, "hp_mult": 1.0, "garrison_regen_bonus": 2, "wall_bonus": 0.30},
		3: {"name": "绝境反击", "atk_mult": 1.35, "def_mult": 1.40, "hp_mult": 1.20, "garrison_regen_bonus": 3, "wall_bonus": 0.50},
	},
	"tier2_passives": {
		"human": {"id": "steadfast_will", "name": "坚守意志", "def_bonus_pct": 0.10, "morale_floor": 1},
		"elf": {"id": "nature_grace", "name": "自然恩赐", "hp_regen_pct": 0.05},
		"mage": {"id": "mana_overflow", "name": "魔力涌流", "spell_atk_bonus_pct": 0.15},
		"orc_ai": {"id": "war_fervor", "name": "战意高涨", "atk_bonus_pct": 0.10, "morale_immune": true},
		"pirate_ai": {"id": "plunder_wind", "name": "劫掠之风", "resource_bonus_pct": 0.25},
		"dark_elf_ai": {"id": "intel_network", "name": "情报网络", "full_map_vision": true},
	},
	"tier3_ultimates": {
		"human": {"id": "kings_decree", "name": "王之号令", "all_atk_def_pct": 0.20, "duration": 3, "summon_elite": true},
		"elf": {"id": "ancient_awakening", "name": "古树觉醒", "summon_boss": {"hp": 300, "atk": 60, "def": 50}, "team_heal_pct": 0.30},
		"mage": {"id": "forbidden_judgment", "name": "禁咒·天罚", "aoe_damage": 80, "silence_turns": 2},
		"orc_ai": {"id": "waaagh_roar", "name": "WAAAGH!怒吼", "atk_mult": 1.5, "duration": 1, "morale_immune": true},
		"pirate_ai": {"id": "black_flag_terror", "name": "黑旗恐惧", "enemy_atk_debuff": 0.20, "enemy_def_debuff": 0.10, "duration": 2, "desert_chance": 0.25},
		"dark_elf_ai": {"id": "shadow_domination", "name": "暗影支配", "mind_control": 1, "team_stealth": true},
	},
	"expedition": {"min_tier": 2, "interval_turns": 3, "unit_count_range": [3, 5]},
	"boss": {"min_tier": 3, "interval_turns": 5, "hp_mult": 3.0, "atk_mult": 2.0},
}
