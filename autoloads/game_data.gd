## game_data.gd — Central troop & military data registry for 暗潮 SLG
##
## Autoload singleton holding all troop type definitions, passive skills,
## recruit formulas, and army/garrison helpers. Design-doc-aligned (v3.0).
##
## Categories:
##   faction   — 3 evil + 3 light faction troops (18 total)
##   neutral   — 5 neutral leader troops + 2 alliance troops
##   rebel     — 2 rebel army types (from low-order revolts)
##   wanderer  — 3 wandering refugee/bandit types
##   ultimate  — 3 faction ultimate troops (require shadow essence)
extends Node

const TroopRegistry = preload("res://systems/combat/troop_registry.gd")

# ─── Enums ────────────────────────────────────────────────────────────────────

enum TroopClass { ASHIGARU, SAMURAI, ARCHER, CAVALRY, NINJA, PRIEST, MAGE_UNIT, CANNON }
enum Row { FRONT, BACK }
enum TroopCategory { FACTION, NEUTRAL, REBEL, WANDERER, ALLIANCE, ULTIMATE, HERO_BOUND }

const TROOP_CLASS_NAMES: Dictionary = {
	TroopClass.ASHIGARU: "足轻", TroopClass.SAMURAI: "武士",
	TroopClass.ARCHER: "弓兵", TroopClass.CAVALRY: "骑兵",
	TroopClass.NINJA: "忍者", TroopClass.PRIEST: "祭司",
	TroopClass.MAGE_UNIT: "術師", TroopClass.CANNON: "砲兵",
}

const CLASS_ROW_DEFAULT: Dictionary = {
	TroopClass.ASHIGARU: Row.FRONT, TroopClass.SAMURAI: Row.FRONT,
	TroopClass.ARCHER: Row.BACK, TroopClass.CAVALRY: Row.FRONT,
	TroopClass.NINJA: Row.BACK, TroopClass.PRIEST: Row.BACK,
	TroopClass.MAGE_UNIT: Row.BACK, TroopClass.CANNON: Row.BACK,
}

## Recruit cost multiplier per troop class (base = soldiers × 2g × multiplier)
const CLASS_COST_MULT: Dictionary = {
	TroopClass.ASHIGARU: 1.0, TroopClass.SAMURAI: 1.5,
	TroopClass.ARCHER: 1.2, TroopClass.CAVALRY: 2.0,
	TroopClass.NINJA: 1.8, TroopClass.PRIEST: 1.5,
	TroopClass.MAGE_UNIT: 2.0, TroopClass.CANNON: 2.5,
}

# ─── Passive Skill Definitions ────────────────────────────────────────────────

var PASSIVE_DEFS: Dictionary = {
	"regen_1":          {"name": "再生",     "desc": "每回合恢复1兵",            "type": "per_round"},
	"bloodlust":        {"name": "嗜血",     "desc": "击杀后ATK+1(本场累积)",    "type": "on_kill"},
	"charge_1_5":       {"name": "冲锋",     "desc": "首次攻击×1.5",             "type": "first_attack", "mult": 1.5},
	"escape_30":        {"name": "逃跑",     "desc": "30%免致死",                "type": "on_death", "chance": 0.3},
	"preemptive":       {"name": "先制",     "desc": "行动队列前攻击",           "type": "priority"},
	"preemptive_1_3":   {"name": "精准先制", "desc": "先制×1.3",                 "type": "priority", "mult": 1.3},
	"siege_x2":         {"name": "攻城",     "desc": "城防削减×2",               "type": "siege", "mult": 2.0},
	"extra_action":     {"name": "额外行动", "desc": "每回合+1行动",             "type": "action_bonus"},
	"assassinate_back": {"name": "暗杀",     "desc": "可攻后排",                 "type": "targeting"},
	"ignore_terrain":   {"name": "无视地形", "desc": "免疫地形减益",             "type": "terrain"},
	"fort_def_3":       {"name": "要塞防守", "desc": "己方据点DEF+3",            "type": "conditional_stat", "stat": "def", "value": 3},
	"counter_1_2":      {"name": "反击",     "desc": "被攻击时×1.2反击",         "type": "on_hit", "mult": 1.2},
	"immobile":         {"name": "不可移动", "desc": "无法节点间移动",           "type": "restriction"},
	"taunt":            {"name": "嘲讽",     "desc": "强制被攻击",               "type": "targeting"},
	"aoe_mana":         {"name": "法术AoE",  "desc": "AoE攻击消耗5法力",         "type": "attack_mode", "mana_cost": 5},
	"charge_mana_1":    {"name": "法力充能", "desc": "每回合+1法力",             "type": "per_round"},
	"aoe_1_5_cost5":    {"name": "强化AoE",  "desc": "AoE×1.5消耗5法力",         "type": "attack_mode", "mult": 1.5, "mana_cost": 5},
	"death_burst":      {"name": "死亡爆发", "desc": "死亡时ATK×2全体伤害",      "type": "on_death"},
	# ── Neutral / special passives ──
	"zero_food":        {"name": "不死之军", "desc": "不消耗粮食,-1兵/回合,胜利+2兵", "type": "special"},
	"low_hp_double":    {"name": "血怒",     "desc": "<50%血ATK翻倍",            "type": "conditional_stat", "stat": "atk", "mult": 2.0},
	"self_destruct_20": {"name": "自爆",     "desc": "20%概率自损1兵",           "type": "per_round", "chance": 0.2},
	"siege_x3":         {"name": "超级攻城", "desc": "城防削减×3",               "type": "siege", "mult": 3.0},
	# ── Rebel / wanderer passives ──
	"desperate":        {"name": "困兽之斗", "desc": "被围时ATK+2",              "type": "conditional_stat", "stat": "atk", "value": 2},
	"pillage":          {"name": "劫掠",     "desc": "胜利后+10金",              "type": "on_victory"},
	"scatter":          {"name": "溃散",     "desc": "兵力<30%自动撤退",         "type": "retreat", "threshold": 0.3},
	"guerrilla":        {"name": "游击",     "desc": "森林/沼泽ATK+2, DEF+1",   "type": "terrain_bonus"},
	"conscript":        {"name": "征召",     "desc": "经过友方据点时+1兵",       "type": "movement"},
	# ── Ultimate passives ──
	"waaagh_triple":    {"name": "WAAAGH暴怒", "desc": "WAAAGH>=80时ATK×3",      "type": "conditional_stat", "stat": "atk", "mult": 3.0},
	"siege_ignore":     {"name": "无视城防",   "desc": "无视城防直接进入战斗",    "type": "siege"},
	"shadow_flight":    {"name": "暗影飞行",   "desc": "无视地形+30%双倍伤害",    "type": "special"},
	# ── Faction-specific passives (design doc) ──
	"horde_bonus":      {"name": "兽群之力",   "desc": "同军3+兽人时ATK+2",       "type": "conditional_stat", "stat": "atk", "value": 2, "min_orc_count": 3},
	"berserker_rage":   {"name": "狂暴化",     "desc": "<50%HP时ATK翻倍失DEF",    "type": "conditional_stat", "stat": "atk", "mult": 2.0, "def_penalty": true},
	"charge_stun":      {"name": "冲锋震荡",   "desc": "首击×1.5且30%眩晕1回合",  "type": "first_attack", "mult": 1.5, "stun_chance": 0.3},
	"pistol_shot":      {"name": "手枪射击",   "desc": "前排可攻后排(手枪)",       "type": "targeting"},
	"reload_shot":      {"name": "火枪齐射",   "desc": "先手射击后需1回合装填",    "type": "priority", "reload_turns": 1},
	"aoe_immobile":     {"name": "定点炮击",   "desc": "AoE+攻城×2+不可移动",     "type": "attack_mode"},
	"counter_defend":   {"name": "防御反击",   "desc": "防守时反击×1.2+DEF+2",     "type": "on_hit", "mult": 1.2, "def_bonus_defending": 2},
	"assassin_crit":    {"name": "暗杀致命",   "desc": "无视嘲讽攻后排+30%暴击×2", "type": "targeting", "crit_chance": 0.3, "crit_mult": 2.0},
	"poison_slow":      {"name": "寒霜毒液",   "desc": "命中附毒DoT+降SPD",        "type": "on_hit", "dot": 1, "spd_debuff": -2},
	"slave_fodder":     {"name": "消耗品",     "desc": "0费肉盾吸收首轮伤害后溃散", "type": "special"},
	# ── Neutral T3 advanced passives ──
	"dwarf_siege_t3":   {"name": "矮人炮术",   "desc": "城防×3+AoE",              "type": "siege", "mult": 3.0},
	"immovable":        {"name": "坚如磐石",   "desc": "不可被强制移至后排",       "type": "restriction"},
	"necro_summon":     {"name": "亡灵召唤",   "desc": "每回合召唤1骷髅小队",     "type": "per_round"},
	"mana_drain":       {"name": "法力吸取",   "desc": "攻击吸取2法力",           "type": "on_hit"},
	"forest_stealth":   {"name": "林间潜行",   "desc": "首回合隐身不可被攻击",     "type": "stealth", "duration": 1},
	"double_forest":    {"name": "森林双击",   "desc": "森林地形攻击两次",         "type": "terrain_bonus"},
	"root_bind":        {"name": "根缚",       "desc": "定身1敌2回合",             "type": "active", "stun_duration": 2},
	"regen_2":          {"name": "深根再生",   "desc": "每回合回复2兵",            "type": "per_round"},
	"blood_triple":     {"name": "血怒三倍",   "desc": "<30%HP时ATK×3不可撤退",    "type": "conditional_stat", "stat": "atk", "mult": 3.0, "no_retreat": true},
	"blood_ritual":     {"name": "血祭",       "desc": "牺牲2兵治愈全军",          "type": "active"},
	"war_cry":          {"name": "战吼",       "desc": "全友军ATK+2持续3回合",     "type": "active"},
	"misfire":          {"name": "不稳定",     "desc": "15%概率自伤",              "type": "per_round", "chance": 0.15},
	"overload":         {"name": "过载",       "desc": "3次攻击后自爆(双倍伤害)",  "type": "special", "max_uses": 3},
	"gold_on_hit":      {"name": "生财有道",   "desc": "每次攻击+2金",             "type": "on_hit"},
	"leadership":       {"name": "统帅",       "desc": "邻近部队ATK+2",            "type": "aura_local"},
	"trade_hire":       {"name": "佣兵雇佣",   "desc": "战中可招募1随机佣兵",      "type": "active"},
	# ── v5.0: Missing passive definitions for new troop types ──
	"flanking_charge":  {"name": "侧翼冲锋",   "desc": "无视前排嘲讽攻击后排",      "type": "targeting"},
	"siege_bombard":    {"name": "高爆轰炸",   "desc": "攻城×3+AoE溅射",           "type": "siege", "mult": 3.0},
	"shadow_stealth":   {"name": "暗影潜行",   "desc": "首回合隐身+反击×1.5",       "type": "stealth", "duration": 1, "counter_mult": 1.5},
	"veteran_resolve":  {"name": "老兵意志",   "desc": "永不溃逃, 士气不低于30",     "type": "special", "min_morale": 30},
}

# ─── Tier Mechanic Constants ────────────────────────────────────────────────
## Each tier unlocks new functional layers beyond raw stats.
## T1: passive only, 0 upkeep, fast to field
## T2: passive + synergy combo, 1 food/turn upkeep
## T3: passive + active ability (1/battle), 2 food/turn, needs strategic resource
## T4: passive + active + aura (buff all allies), 3 food/turn, needs shadow essence

const TIER_UPKEEP: Dictionary = { 0: 0, 1: 0, 2: 1, 3: 2, 4: 3 }
const TIER_MOVE_RANGE: Dictionary = { 0: 1, 1: 2, 2: 2, 3: 3, 4: 4 }
const TIER_EXP_CAP: Dictionary = { 0: 0, 1: 30, 2: 60, 3: 100, 4: 150 }

## Veterancy thresholds: at each exp milestone, troops gain permanent bonuses
## v3.0: Increased bonuses to make veterancy meaningful vs hero stat additions
const VETERANCY_THRESHOLDS: Array = [
	{"exp": 10, "label": "历战", "atk_bonus": 1, "def_bonus": 1},
	{"exp": 25, "label": "精锐", "atk_bonus": 2, "def_bonus": 1, "soldiers_bonus": 1},
	{"exp": 50, "label": "百战", "atk_bonus": 3, "def_bonus": 2, "soldiers_bonus": 1},
	{"exp": 80, "label": "无双", "atk_bonus": 4, "def_bonus": 3, "soldiers_bonus": 2},
]

# ─── Faction Passive Constants ─────────────────────────────────────────────
## Faction-wide combat modifiers (applied to all troops of this faction)
const FACTION_PASSIVES: Dictionary = {
	"orc": {
		"name": "蛮力碾压",
		"desc": "所有兽人部队无视敌方30%DEF",
		"def_ignore_pct": 0.3,
		"recruit_currency": "food_waaagh",
	},
	"pirate": {
		"name": "掠夺经济",
		"desc": "战斗中每击杀1敌兵+1金币; 可雇佣任意阵营T1-T2佣兵(2倍价格)",
		"gold_per_kill": 1,
		"mercenary_hiring": true,
		"mercenary_cost_mult": 2.0,
	},
	"dark_elf": {
		"name": "奴隶先锋",
		"desc": "可部署T0奴隶肉盾(0费); 俘虏可转化为T1部队",
		"slave_deploy": true,
		"slave_conversion_turns": 3,
	},
}

# ─── Synergy Definitions (T2+ unlock) ──────────────────────────────────────
## When two synergy-compatible troops are in the same army, both get a bonus.
## Key = troop_id, value = { partner: troop_id, bonus: {stat: value} }
const SYNERGY_DEFS: Dictionary = {
	# ── Same-faction synergies (T2) ──
	"orc_samurai": {"partner": "orc_ashigaru", "self_bonus": {"def": 1}, "partner_bonus": {"atk": 2}, "name": "战吼"},
	"pirate_archer": {"partner": "pirate_ashigaru", "self_bonus": {"atk": 1}, "partner_bonus": {"def": 2}, "name": "火力掩护"},
	"de_ninja": {"partner": "de_samurai", "self_bonus": {"atk": 1}, "partner_bonus": {"atk": 1, "def": 1}, "name": "暗影协同"},
	"human_cavalry": {"partner": "human_ashigaru", "self_bonus": {"atk": 1}, "partner_bonus": {"def": 3}, "name": "骑士号令"},
	"elf_mage": {"partner": "elf_archer", "self_bonus": {"def": 1}, "partner_bonus": {"atk": 2}, "name": "附魔箭"},
	"mage_battle": {"partner": "mage_apprentice", "self_bonus": {"atk": 1}, "partner_bonus": {"atk": 3}, "name": "法术共鸣"},
	# ── Cross-faction synergies (neutral × player, unlocked after taming >= 5) ──
	# Doc §6.1: functional synergy effects + stat bonuses
	"neutral_dwarf_guard": {"partner": "orc_ashigaru", "self_bonus": {"def": 1}, "partner_bonus": {"atk": 1}, "name": "铁与血",
		"special": {"charge_ignore_block": true, "desc": "冲锋不会被矮人阻挡"}},
	"neutral_blood_berserker": {"partner": "orc_samurai", "self_bonus": {"atk": 2}, "partner_bonus": {"atk": 1}, "name": "双重狂潮",
		"special": {"waaagh_double": true, "desc": "WAAAGH!积累速度翻倍"}},
	"neutral_goblin_cannon": {"partner": "pirate_cannon", "self_bonus": {"atk": 1, "misfire_reduction": 0.07}, "partner_bonus": {"atk": 1}, "name": "火药狂热",
		"special": {"aoe_extra_target": 1, "desc": "AoE+1目标, 走火降至8%"}},
	"neutral_caravan_guard": {"partner": "pirate_ashigaru", "self_bonus": {"atk": 1, "gold_on_hit_bonus": 1}, "partner_bonus": {"def": 1}, "name": "黑市垄断",
		"special": {"gold_income_bonus": 0.5, "desc": "战斗金币+50%"}},
	"neutral_skeleton": {"partner": "de_samurai", "self_bonus": {"atk": 1, "regen_bonus": 1}, "partner_bonus": {"def": 1}, "name": "暗影亡灵",
		"special": {"slave_conversion_speed": 0.5, "desc": "奴隶转化+50%(2回合), 骷髅回复+1"}},
	"neutral_green_archer": {"partner": "de_ninja", "self_bonus": {"atk": 1}, "partner_bonus": {"atk": 2, "crit_bonus": 0.10}, "name": "暗夜猎手",
		"special": {"stealth_extra_round": 1, "desc": "全体隐匿+1回合, 刺客暴击+10%"}},
}

# ─── Taming Level Thresholds ──────────────────────────────────────────────
## Taming level 0-10 determines relationship with neutral factions
const TAMING_THRESHOLDS: Dictionary = {
	"hostile":   {"min": 0, "max": 2, "desc": "敌对 — 挑衅会被攻击"},
	"neutral":   {"min": 3, "max": 4, "desc": "中立 — 基础交易可用"},
	"friendly":  {"min": 5, "max": 6, "desc": "友好 — T2兵种解锁招募"},
	"allied":    {"min": 7, "max": 8, "desc": "同盟 — T3兵种+高级加成解锁"},
	"tamed":     {"min": 9, "max": 10, "desc": "完全驯服 — 阵营联携激活+英雄招募"},
}

## Taming change factors
const TAMING_CHANGES: Dictionary = {
	"quest_step_complete": 2,
	"gift_resources": 1,
	"gift_cooldown_turns": 3,
	"quest_fail_or_attack": -3,
	"ignore_10_turns": -1,
	"defend_neutral_territory": 1,
	"abandon_neutral_territory": -2,
}

# ─── Neutral Faction Troop Unlock Map ────────────────────────────────────
## Maps neutral faction tag → { t2: troop_id (taming 5+), t3: troop_id (taming 7+) }
const NEUTRAL_TROOP_UNLOCK: Dictionary = {
	"neutral_dwarf":  {"t2": "neutral_dwarf_guard",   "t3": "neutral_dwarf_cannon",  "synergy_bonus": {"def": 1, "desc": "全军DEF+1"}},
	"neutral_necro":  {"t2": "neutral_skeleton",       "t3": "neutral_necromancer",   "synergy_bonus": {"resurrect_pct": 0.2, "desc": "战后20%亡兵复活为骷髅"}},
	"neutral_ranger": {"t2": "neutral_green_archer",   "t3": "neutral_treant",        "synergy_bonus": {"forest_atk": 3, "desc": "森林地形全军ATK+3"}},
	"neutral_blood":  {"t2": "neutral_blood_berserker", "t3": "neutral_blood_shaman", "synergy_bonus": {"waaagh_double": true, "desc": "兽人玩家WAAAGH获取翻倍"}},
	"neutral_goblin": {"t2": "neutral_goblin_cannon",  "t3": "neutral_goblin_mech",   "synergy_bonus": {"siege_bonus": 0.3, "build_discount": 0.2, "desc": "攻城+30%/建造-20%"}},
	"neutral_caravan": {"t2": "neutral_caravan_guard",  "t3": "neutral_merc_captain",  "synergy_bonus": {"gold_income": 0.3, "desc": "全领地金币+30%"}},
}

# ─── Active Ability Definitions (T3+ unlock) ───────────────────────────────
## Once per battle, the commander can activate this ability.
## Trigger conditions vary; all have a cooldown of 1 battle.
var ACTIVE_ABILITY_DEFS: Dictionary = {
	# Orc T3: 战猪骑兵 — 猪突猛进: 全前排ATK+3持续1回合
	"orc_cavalry": {
		"name": "猪突猛进", "desc": "全前排友军ATK+3(1回合)",
		"target": "row_front", "effect": {"atk": 3}, "duration": 1,
	},
	# Pirate T3: 炮击手 — 集中炮击: 对守军全体造成ATK×2伤害(无视前后排)
	"pirate_cannon": {
		"name": "集中炮击", "desc": "全体敌军受ATK×2伤害(无视排位)",
		"target": "all_enemy", "effect": {"damage_mult": 2.0}, "duration": 0,
	},
	# Dark Elf T3: 冷蜥骑兵 — 寒霜突袭: 敌全体DEF-2持续2回合
	"de_cavalry": {
		"name": "寒霜突袭", "desc": "全体敌军DEF-2(2回合)",
		"target": "all_enemy", "effect": {"def": -2}, "duration": 2,
	},
	# Human T3: 圣殿女卫 — 圣盾结界: 全军受到伤害-40%(1回合)
	"human_samurai": {
		"name": "圣盾结界", "desc": "全军受伤-40%(1回合)",
		"target": "all_ally", "effect": {"damage_reduction": 0.4}, "duration": 1,
	},
	# Elf T3: 树人 — 根缚: 敌前排无法行动1回合
	"elf_ashigaru": {
		"name": "根缚", "desc": "敌前排无法行动(1回合)",
		"target": "row_front_enemy", "effect": {"stun": true}, "duration": 1,
	},
	# Mage T3: 大法师 — 时间扭曲: 友军全体额外行动1次
	"mage_grand": {
		"name": "时间扭曲", "desc": "友军全体本回合额外行动1次",
		"target": "all_ally", "effect": {"extra_action": 1}, "duration": 0,
	},
	# ── Neutral T3 Active Abilities ──
	"neutral_dwarf_cannon": {
		"name": "矮人齐射", "desc": "城防削减×5(单次)+全敌AoE",
		"target": "all_enemy", "effect": {"siege_mult": 5.0, "damage_mult": 1.5}, "duration": 0,
	},
	"neutral_necromancer": {
		"name": "亡灵潮汐", "desc": "召唤3支骷髅小队加入战斗",
		"target": "summon", "effect": {"summon_id": "neutral_skeleton", "summon_count": 3, "summon_soldiers": 4}, "duration": 0,
	},
	"neutral_treant": {
		"name": "盘根错节", "desc": "敌全体无法行动1回合+受伤+15%",
		"target": "all_enemy", "effect": {"stun": true, "damage_taken_mult": 1.15}, "duration": 1,
	},
	"neutral_blood_shaman": {
		"name": "血月仪式", "desc": "牺牲2兵, 全友军ATK+3/DEF+1持续3回合",
		"target": "all_ally", "effect": {"atk": 3, "def": 1, "sacrifice_soldiers": 2}, "duration": 3,
	},
	"neutral_goblin_mech": {
		"name": "蒸汽超载", "desc": "本回合ATK×3, 之后自爆造成全场AoE",
		"target": "self", "effect": {"atk_mult": 3.0, "self_destruct": true}, "duration": 1,
	},
	"neutral_merc_captain": {
		"name": "紧急征召", "desc": "战中招募1支随机T2佣兵部队",
		"target": "summon", "effect": {"summon_random_t2": true, "summon_count": 1}, "duration": 0,
	},
	# ── T4 Active Abilities (design doc §3.1-3.3) ──
	"orc_ultimate": {
		"name": "WAAAGH!战吼", "desc": "全友军首回合DEF+3, WAAAGH!+20",
		"target": "all_ally", "effect": {"def": 3, "waaagh_gain": 20}, "duration": 1,
	},
	"pirate_ultimate": {
		"name": "激励射击", "desc": "所有后排射击单位立即额外射击一次(无视装填)",
		"target": "row_back_ally", "effect": {"extra_attack": true, "damage_mult": 1.5}, "duration": 0,
	},
	"de_ultimate": {
		"name": "支配", "desc": "令1支敌方T1-T2部队本回合攻击自己队友",
		"target": "single_enemy", "effect": {"dominate": true, "max_tier": 2}, "duration": 1,
	},
}

# ─── Aura Definitions (T4 unlock) ──────────────────────────────────────────
## Permanent buff to all friendly troops while this T4 unit is alive.
## Also has a map-level passive effect outside combat.
const AURA_DEFS: Dictionary = {
	"orc_ultimate": {
		"name": "WAAAGH!光环",
		"combat_aura": {"atk": 2, "def": 3, "desc": "全军ATK+2, 首回合DEF+3(战吼)"},
		"map_effect": {"waaagh_per_turn": 15, "desc": "每回合+15 WAAAGH!"},
	},
	"pirate_ultimate": {
		"name": "掠夺之王",
		"combat_aura": {"atk": 1, "desc": "全军ATK+1"},
		"map_effect": {"gold_plunder_mult": 1.5, "desc": "战斗掠夺金币+50%"},
	},
	"de_ultimate": {
		"name": "暗影笼罩",
		"combat_aura": {"stealth_rounds": 1, "desc": "战斗首回合全体隐匿(免远程)"},
		"map_effect": {"stealth": true, "desc": "军团对敌隐形(迷雾穿透无效)"},
	},
}

# ─── Troop Type Registry ─────────────────────────────────────────────────────
## Each entry: { name, faction, troop_class, row, base_atk, base_def,
##               max_soldiers, recruit_cost, passive, category, tier, desc,
##               [synergy], [active_ability], [aura], [strategic_cost] }
## Tier unlocks: T1=passive, T2+=synergy, T3+=active, T4+=aura

## PLACEHOLDER: troop registry
var TROOP_TYPES: Dictionary = {}

# ─── Garrison Templates ──────────────────────────────────────────────────────

## PLACEHOLDER: garrison templates
const GARRISON_TEMPLATES: Dictionary = {
	# Light faction default garrisons by tile importance
	"human_village": [
		{"troop_id": "human_ashigaru", "soldiers": 6},
	],
	"human_stronghold": [
		{"troop_id": "human_ashigaru", "soldiers": 8},
		{"troop_id": "human_cavalry", "soldiers": 4},
	],
	"human_fortress": [
		{"troop_id": "human_ashigaru", "soldiers": 8},
		{"troop_id": "human_cavalry", "soldiers": 6},
		{"troop_id": "human_samurai", "soldiers": 10},
	],
	"elf_village": [
		{"troop_id": "elf_archer", "soldiers": 4},
	],
	"elf_stronghold": [
		{"troop_id": "elf_archer", "soldiers": 5},
		{"troop_id": "elf_mage", "soldiers": 3},
	],
	"elf_fortress": [
		{"troop_id": "elf_archer", "soldiers": 5},
		{"troop_id": "elf_mage", "soldiers": 4},
		{"troop_id": "elf_ashigaru", "soldiers": 15},
	],
	"mage_village": [
		{"troop_id": "mage_apprentice", "soldiers": 3},
	],
	"mage_stronghold": [
		{"troop_id": "mage_apprentice", "soldiers": 4},
		{"troop_id": "mage_battle", "soldiers": 3},
	],
	"mage_fortress": [
		{"troop_id": "mage_apprentice", "soldiers": 4},
		{"troop_id": "mage_battle", "soldiers": 5},
		{"troop_id": "mage_grand", "soldiers": 8},
	],
	# Neutral bases
	"neutral_dwarf": [
		{"troop_id": "neutral_dwarf_guard", "soldiers": 6},
	],
	"neutral_necro": [
		{"troop_id": "neutral_skeleton", "soldiers": 8},
	],
	"neutral_ranger": [
		{"troop_id": "neutral_green_archer", "soldiers": 5},
	],
	"neutral_blood": [
		{"troop_id": "neutral_blood_berserker", "soldiers": 6},
	],
	"neutral_goblin": [
		{"troop_id": "neutral_goblin_cannon", "soldiers": 3},
	],
	"neutral_caravan": [
		{"troop_id": "neutral_caravan_guard", "soldiers": 5},
	],
	# Bandit camps
	"bandit_weak": [
		{"troop_id": "wanderer_bandit", "soldiers": 3},
	],
	"bandit_strong": [
		{"troop_id": "wanderer_bandit", "soldiers": 4},
		{"troop_id": "wanderer_deserter", "soldiers": 4},
	],
	# Rebel uprising
	"rebel_small": [
		{"troop_id": "rebel_militia", "soldiers": 4},
	],
	"rebel_large": [
		{"troop_id": "rebel_militia", "soldiers": 6},
		{"troop_id": "rebel_archer", "soldiers": 4},
	],
	# Alliance expeditions (threat >= 60)
	"alliance_strike": [
		{"troop_id": "alliance_vanguard", "soldiers": 7},
		{"troop_id": "alliance_arcane_battery", "soldiers": 4},
	],
	"alliance_full": [
		{"troop_id": "alliance_vanguard", "soldiers": 7},
		{"troop_id": "alliance_arcane_battery", "soldiers": 6},
		{"troop_id": "human_cavalry", "soldiers": 6},
	],
}

# ─── Wanderer Templates ──────────────────────────────────────────────────────

## PLACEHOLDER: wanderer templates — spawned on unclaimed tiles
const WANDERER_TEMPLATES: Array = [
	{"troop_id": "wanderer_deserter", "soldiers_range": [3, 5], "weight": 40},
	{"troop_id": "wanderer_bandit", "soldiers_range": [2, 4], "weight": 35},
	{"troop_id": "wanderer_refugee", "soldiers_range": [5, 10], "weight": 25},
]

# ─── Rebel Templates ─────────────────────────────────────────────────────────

## PLACEHOLDER: rebel templates — spawned at low-order tiles
const REBEL_TEMPLATES: Array = [
	{"template": "rebel_small", "order_threshold": 25, "weight": 70},
	{"template": "rebel_large", "order_threshold": 15, "weight": 30},
]

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_troop_registry()


func _build_troop_registry() -> void:
	TROOP_TYPES = TroopRegistry.get_all_troop_definitions()
	# Merge hero-bound passives into main passive defs
	for pid in TroopRegistry.HERO_BOUND_PASSIVES:
		if not PASSIVE_DEFS.has(pid):
			PASSIVE_DEFS[pid] = TroopRegistry.HERO_BOUND_PASSIVES[pid]
	# Merge hero-bound active abilities into main ability defs
	for tid in TroopRegistry.HERO_BOUND_ABILITIES:
		if not ACTIVE_ABILITY_DEFS.has(tid):
			ACTIVE_ABILITY_DEFS[tid] = TroopRegistry.HERO_BOUND_ABILITIES[tid]



# ─── Query API ────────────────────────────────────────────────────────────────

func get_faction_passive(faction_tag: String) -> Dictionary:
	return FACTION_PASSIVES.get(faction_tag, {})

func get_troop_def(troop_id: String) -> Dictionary:
	return TROOP_TYPES.get(troop_id, {})

func get_troops_by_faction(faction_tag: String) -> Array:
	var result: Array = []
	for tid in TROOP_TYPES:
		if TROOP_TYPES[tid].get("faction", "") == faction_tag:
			result.append(tid)
	return result

func get_troops_by_category(cat: int) -> Array:
	var result: Array = []
	for tid in TROOP_TYPES:
		if TROOP_TYPES[tid].get("category", -1) == cat:
			result.append(tid)
	return result

func get_hero_bound_troop(hero_id: String) -> String:
	## Returns the troop_id of the hero-bound exclusive troop for this hero, or "".
	for tid in TROOP_TYPES:
		if TROOP_TYPES[tid].get("hero_bound", "") == hero_id:
			return tid
	return ""

func get_hero_bound_troops_for_player() -> Array:
	## Returns all hero-bound troop_ids where the bound hero is recruited.
	var result: Array = []
	for tid in TROOP_TYPES:
		var td: Dictionary = TROOP_TYPES[tid]
		if td.get("category", -1) != TroopCategory.HERO_BOUND:
			continue
		var hero_id: String = td.get("hero_bound", "")
		if hero_id != "" and HeroSystem.recruited_heroes.has(hero_id):
			result.append(tid)
	return result

func get_recruit_cost(troop_id: String) -> int:
	var td: Dictionary = get_troop_def(troop_id)
	if td.is_empty():
		return -1  # Invalid troop — caller must check for -1 before using
	return td.get("recruit_cost", -1)

func get_class_name(tc: int) -> String:
	return TROOP_CLASS_NAMES.get(tc, "未知")

# ─── Troop Instance Factory ──────────────────────────────────────────────────

func create_troop_instance(troop_id: String, soldiers_override: int = -1) -> Dictionary:
	var td: Dictionary = get_troop_def(troop_id)
	if td.is_empty():
		return {}
	if not td.has("max_soldiers"):
		push_warning("GameData: troop '%s' missing 'max_soldiers' key" % troop_id)
		return {}
	var soldiers: int = soldiers_override if soldiers_override > 0 else td["max_soldiers"]
	var hpp: int = td.get("hp_per_soldier", 5)
	return {
		"troop_id": troop_id,
		"soldiers": soldiers,
		"max_soldiers": td["max_soldiers"],
		"hp_per_soldier": hpp,
		"total_hp": soldiers * hpp,
		"max_hp": td["max_soldiers"] * hpp,
		"commander_id": "",
		"experience": 0,
		"ability_used": false,  # Reset each battle for T3+ active abilities
	}

func create_garrison_from_template(template_id: String) -> Array:
	if not GARRISON_TEMPLATES.has(template_id):
		return []
	var result: Array = []
	for entry in GARRISON_TEMPLATES[template_id]:
		var inst: Dictionary = create_troop_instance(entry["troop_id"], entry.get("soldiers", -1))
		if not inst.is_empty():
			result.append(inst)
	return result


# ─── Army Helpers ─────────────────────────────────────────────────────────────

## Returns total soldier count across an army (Array of troop instances).
func get_army_total_soldiers(army: Array) -> int:
	var total: int = 0
	for troop in army:
		total += troop.get("soldiers", 0)
	return total


## Returns total HP across an army (Array of troop instances).
func get_army_total_hp(army: Array) -> int:
	var total: int = 0
	for troop in army:
		total += troop.get("total_hp", troop.get("soldiers", 0) * troop.get("hp_per_soldier", 5))
	return total


## Returns total combat power estimate for an army.
func get_army_combat_power(army: Array) -> int:
	var power: int = 0
	for troop in army:
		var tid: String = troop.get("troop_id", "")
		if tid == "":
			continue
		var td: Dictionary = get_troop_def(tid)
		if td.is_empty():
			continue
		power += troop.get("soldiers", 0) * (td.get("base_atk", 0) + td.get("base_def", 0))
	return power


## Apply casualties to an army. Distributes losses proportionally via HP.
## total_losses is in soldier units for backward compatibility; converted to HP internally.
## Returns actual total soldiers lost.
func apply_army_losses(army: Array, total_losses: int) -> int:
	if army.is_empty() or total_losses <= 0:
		return 0
	var total_soldiers: int = get_army_total_soldiers(army)
	if total_soldiers <= 0:
		return 0
	var remaining_loss: int = mini(total_losses, total_soldiers)
	var soldiers_before: int = total_soldiers
	# Convert soldier losses to HP damage using average hp_per_soldier across the army
	var total_hp: int = get_army_total_hp(army)
	var avg_hpp: float = float(total_hp) / float(total_soldiers) if total_soldiers > 0 else 5.0
	if avg_hpp <= 0.0:
		avg_hpp = 5.0  # Guard against zero/negative avg_hpp when total_hp is 0
	var hp_damage: int = int(float(remaining_loss) * avg_hpp)
	# Proportional HP distribution — compute shares first, then distribute remainder
	var shares: Array = []
	var floor_total: int = 0
	for troop in army:
		var troop_hp: int = troop.get("total_hp", troop.get("soldiers", 0) * troop.get("hp_per_soldier", 5))
		var share_f: float = float(troop_hp) / float(total_hp) * float(hp_damage) if total_hp > 0 else 0.0
		var floored: int = int(share_f)
		shares.append({"troop": troop, "floor": floored, "frac": share_f - float(floored)})
		floor_total += floored
	# Sort by fractional remainder descending to assign leftover
	var leftover: int = hp_damage - floor_total
	shares.sort_custom(func(a, b): return a["frac"] > b["frac"])
	for entry in shares:
		var hp_loss: int = entry["floor"]
		if leftover > 0:
			hp_loss += 1
			leftover -= 1
		var troop: Dictionary = entry["troop"]
		var troop_hp: int = troop.get("total_hp", troop.get("soldiers", 0) * troop.get("hp_per_soldier", 5))
		hp_loss = mini(hp_loss, troop_hp)
		var hpp: int = troop.get("hp_per_soldier", 5)
		troop["total_hp"] = maxi(0, troop_hp - hp_loss)
		if troop["total_hp"] > 0:
			troop["soldiers"] = ceili(float(troop["total_hp"]) / float(hpp))
		else:
			troop["soldiers"] = 0
	# Remove dead troops
	var i: int = army.size() - 1
	while i >= 0:
		if army[i]["soldiers"] <= 0:
			army.remove_at(i)
		i -= 1
	var actual_lost: int = soldiers_before - get_army_total_soldiers(army)
	return actual_lost


## Merge reinforcements into an existing army. Same troop_id stacks soldiers up
## to max_soldiers; excess creates new instances. Updates total_hp accordingly.
func merge_into_army(army: Array, reinforcements: Array) -> void:
	for reinf in reinforcements:
		var merged := false
		for troop in army:
			if troop["troop_id"] == reinf["troop_id"] and troop["soldiers"] < troop["max_soldiers"]:
				var space: int = troop["max_soldiers"] - troop["soldiers"]
				var add: int = mini(reinf["soldiers"], space)
				troop["soldiers"] += add
				var hpp: int = troop.get("hp_per_soldier", 5)
				troop["total_hp"] = troop["soldiers"] * hpp
				reinf["soldiers"] -= add
				if reinf["soldiers"] <= 0:
					merged = true
					break
		if not merged and reinf["soldiers"] > 0:
			var dup: Dictionary = reinf.duplicate()
			var hpp: int = dup.get("hp_per_soldier", 5)
			dup["total_hp"] = dup["soldiers"] * hpp
			army.append(dup)


## Returns a display-friendly summary of an army.
func get_army_summary(army: Array) -> Array:
	var result: Array = []
	var syn_bonuses: Dictionary = compute_synergy_bonuses(army)
	var aura: Dictionary = compute_aura_bonuses(army)
	for idx in range(army.size()):
		var troop: Dictionary = army[idx]
		var td: Dictionary = get_troop_def(troop["troop_id"])
		var vet: Dictionary = get_veterancy_bonuses(troop.get("experience", 0))
		var syn: Dictionary = syn_bonuses.get(idx, {"atk": 0, "def": 0, "synergy_name": ""})
		var tier: int = td.get("tier", 1)
		var total_atk: int = td.get("base_atk", 0) + vet["atk_bonus"] + syn["atk"] + aura["atk"]
		var total_def: int = td.get("base_def", 0) + vet["def_bonus"] + syn["def"] + aura["def"]
		var ability: Dictionary = get_active_ability(troop["troop_id"])
		result.append({
			"troop_id": troop["troop_id"],
			"name": td.get("name", troop["troop_id"]),
			"class_name": get_class_name(td.get("troop_class", TroopClass.ASHIGARU)),
			"soldiers": troop["soldiers"],
			"max_soldiers": troop["max_soldiers"],
			"hp_per_soldier": troop.get("hp_per_soldier", td.get("hp_per_soldier", 5)),
			"total_hp": troop.get("total_hp", troop.get("soldiers", 0) * troop.get("hp_per_soldier", 5)),
			"max_hp": troop.get("max_hp", troop.get("max_soldiers", td.get("max_soldiers", 1)) * troop.get("hp_per_soldier", 5)),
			"row": "前排" if td.get("row", Row.FRONT) == Row.FRONT else "后排",
			"passive": td.get("passive", ""),
			"tier": tier,
			"atk": total_atk,
			"def": total_def,
			"experience": troop.get("experience", 0),
			"veterancy": vet["label"],
			"synergy": syn["synergy_name"],
			"ability": ability.get("name", ""),
			"ability_used": troop.get("ability_used", false),
			"upkeep": TIER_UPKEEP.get(tier, 0),
		})
	return result


## Returns recruitable troop IDs for a faction at a given tile level.
func get_recruitable_troops(faction_tag: String, tile_level: int) -> Array:
	var result: Array = []
	for tid in TROOP_TYPES:
		var td: Dictionary = TROOP_TYPES[tid]
		if td.get("faction", "") != faction_tag:
			continue
		var cat: int = td.get("category", -1)
		# Hero-bound troops: only available if bound hero is recruited
		if cat == TroopCategory.HERO_BOUND:
			var hero_id: String = td.get("hero_bound", "")
			if hero_id == "" or not HeroSystem.recruited_heroes.has(hero_id):
				continue
			if td.get("tier", 1) > tile_level:
				continue
			result.append(tid)
			continue
		if cat != TroopCategory.FACTION and cat != TroopCategory.ULTIMATE:
			continue
		if td.get("tier", 1) > tile_level and td.get("tier", 1) != 4:
			continue
		if td.get("tier", 1) == 4:
			# Ultimate requires tile level 3+
			if tile_level < 3:
				continue
		result.append(tid)
	return result


## Calculates actual recruit cost with discount modifiers.
func calculate_recruit_cost(troop_id: String, discount_pct: float = 0.0, cost_mult: float = 1.0) -> Dictionary:
	var td: Dictionary = get_troop_def(troop_id)
	if td.is_empty():
		return {"gold": -1}  # Invalid troop — caller must check for negative cost
	var base_gold: int = td["recruit_cost"]
	var faction: String = td.get("faction", "")
	var tier: int = td.get("tier", 1)

	# ── Orc: food + WAAAGH! instead of gold (doc §3.1) ──
	if faction == "orc" and td.get("category", 0) == TroopCategory.FACTION:
		var food_cost: int = 20 * tier  # T1:20, T2:40, T3:60
		var waaagh_cost: int = maxi(0, (tier - 1) * 20)  # T1:0, T2:20, T3:40
		var result: Dictionary = {"food": maxi(1, int(float(food_cost) * (1.0 - discount_pct / 100.0) * cost_mult))}
		if waaagh_cost > 0:
			result["waaagh"] = waaagh_cost
		var strat: Dictionary = td.get("strategic_cost", {})
		for key in strat:
			result[key] = strat[key]
		return result

	# ── Dark Elf: 1.5x gold + iron cost (doc §3.3) ──
	if faction == "dark_elf" and td.get("category", 0) == TroopCategory.FACTION and troop_id != "slave_fodder":
		var de_gold: int = maxi(1, int(float(base_gold) * 1.5 * (1.0 - discount_pct / 100.0) * cost_mult))
		var de_iron: int = maxi(1, int(float(tier) * 15.0))  # T1:15, T2:30, T3:45
		var result: Dictionary = {"gold": de_gold, "iron": de_iron}
		var strat: Dictionary = td.get("strategic_cost", {})
		for key in strat:
			result[key] = strat[key]
		return result

	# ── Default: gold-based ──
	var gold: int = maxi(1, int(float(base_gold) * (1.0 - discount_pct / 100.0) * cost_mult))
	var result: Dictionary = {"gold": gold}
	# Strategic resource costs
	var strat: Dictionary = td.get("strategic_cost", {})
	for key in strat:
		result[key] = strat[key]
	return result


# ─── Wanderer / Rebel Spawning ────────────────────────────────────────────────

## Creates a random wanderer army for an unclaimed tile.
func spawn_wanderer_army() -> Array:
	var total_weight: int = 0
	for t in WANDERER_TEMPLATES:
		total_weight += t["weight"]
	var roll: int = randi() % total_weight
	var cum: int = 0
	for t in WANDERER_TEMPLATES:
		cum += t["weight"]
		if roll < cum:
			var soldiers: int = randi_range(t["soldiers_range"][0], t["soldiers_range"][1])
			return [create_troop_instance(t["troop_id"], soldiers)]
	return []


## Creates a rebel army based on current order value.
func spawn_rebel_army(order_value: int) -> Array:
	for t in REBEL_TEMPLATES:
		if order_value <= t["order_threshold"]:
			var roll: int = randi() % 100
			if roll < t["weight"]:
				return create_garrison_from_template(t["template"])
	return []


# ─── Tier Mechanic Queries ───────────────────────────────────────────────────

## Returns food upkeep per turn for a troop instance.
func get_troop_upkeep(troop_id: String) -> int:
	var td: Dictionary = get_troop_def(troop_id)
	var tier: int = td.get("tier", 1)
	return TIER_UPKEEP.get(tier, 0)


## Returns total food upkeep for an army.
func get_army_upkeep(army: Array) -> int:
	var total: int = 0
	for troop in army:
		total += get_troop_upkeep(troop["troop_id"])
	return total


## Returns movement range for a troop.
func get_troop_move_range(troop_id: String) -> int:
	var td: Dictionary = get_troop_def(troop_id)
	var tier: int = td.get("tier", 1)
	return TIER_MOVE_RANGE.get(tier, 2)


## Returns veterancy bonuses based on experience.
func get_veterancy_bonuses(experience: int) -> Dictionary:
	var result: Dictionary = {"atk_bonus": 0, "def_bonus": 0, "soldiers_bonus": 0, "label": ""}
	for threshold in VETERANCY_THRESHOLDS:
		if experience >= threshold["exp"]:
			result["atk_bonus"] = threshold["atk_bonus"]
			result["def_bonus"] = threshold["def_bonus"]
			result["soldiers_bonus"] = threshold.get("soldiers_bonus", 0)
			result["label"] = threshold["label"]
	return result


## Calculates combat ATK for a troop instance (base + veterancy).
func get_effective_atk(troop: Dictionary) -> int:
	var td: Dictionary = get_troop_def(troop["troop_id"])
	var base: int = td.get("base_atk", 0)
	var vet: Dictionary = get_veterancy_bonuses(troop.get("experience", 0))
	return base + vet["atk_bonus"]


## Calculates combat DEF for a troop instance (base + veterancy).
func get_effective_def(troop: Dictionary) -> int:
	var td: Dictionary = get_troop_def(troop["troop_id"])
	var base: int = td.get("base_def", 0)
	var vet: Dictionary = get_veterancy_bonuses(troop.get("experience", 0))
	return base + vet["def_bonus"]


## Grants experience to a troop instance (capped by tier).
func grant_experience(troop: Dictionary, amount: int) -> void:
	var td: Dictionary = get_troop_def(troop["troop_id"])
	var tier: int = td.get("tier", 1)
	var cap: int = TIER_EXP_CAP.get(tier, 30)
	troop["experience"] = mini(troop.get("experience", 0) + amount, cap)


# ─── Synergy System (T2+) ───────────────────────────────────────────────────

## Calculates synergy stat bonuses for each troop in an army.
## Returns { troop_index: { "atk": bonus, "def": bonus, "synergy_name": name } }
func compute_synergy_bonuses(army: Array) -> Dictionary:
	var result: Dictionary = {}
	# Build a set of troop_ids present in this army
	var present_ids: Dictionary = {}
	for idx in range(army.size()):
		var tid: String = army[idx]["troop_id"]
		if not present_ids.has(tid):
			present_ids[tid] = []
		present_ids[tid].append(idx)

	for idx in range(army.size()):
		var tid: String = army[idx]["troop_id"]
		if not SYNERGY_DEFS.has(tid):
			continue
		var syn: Dictionary = SYNERGY_DEFS[tid]
		var partner_id: String = syn["partner"]
		if not present_ids.has(partner_id):
			continue
		# Self gets self_bonus
		if not result.has(idx):
			result[idx] = {"atk": 0, "def": 0, "synergy_name": ""}
		result[idx]["atk"] += syn["self_bonus"].get("atk", 0)
		result[idx]["def"] += syn["self_bonus"].get("def", 0)
		result[idx]["synergy_name"] = syn["name"]
		# Partner(s) get partner_bonus
		for pidx in present_ids[partner_id]:
			if not result.has(pidx):
				result[pidx] = {"atk": 0, "def": 0, "synergy_name": ""}
			result[pidx]["atk"] += syn["partner_bonus"].get("atk", 0)
			result[pidx]["def"] += syn["partner_bonus"].get("def", 0)
			if result[pidx]["synergy_name"] == "":
				result[pidx]["synergy_name"] = syn["name"]
	return result


## Returns all active synergy "special" effects for an army.
## Checks if both synergy partners are present; if so, collects the "special" dict.
## Returns a merged Dictionary of all active special effects.
func compute_synergy_specials(army: Array) -> Dictionary:
	var result: Dictionary = {}
	var present_ids: Dictionary = {}
	for troop in army:
		var tid: String = troop["troop_id"]
		present_ids[tid] = true
	for tid in present_ids:
		if not SYNERGY_DEFS.has(tid):
			continue
		var syn: Dictionary = SYNERGY_DEFS[tid]
		var partner_id: String = syn["partner"]
		if not present_ids.has(partner_id):
			continue
		var special: Dictionary = syn.get("special", {})
		for key in special:
			if key == "desc":
				continue
			result[key] = special[key]
	return result



## Returns the active ability definition for a troop (empty if none).
func get_active_ability(troop_id: String) -> Dictionary:
	return ACTIVE_ABILITY_DEFS.get(troop_id, {})


## Checks if army has any T3+ troops with unused active abilities.
func get_available_abilities(army: Array) -> Array:
	var result: Array = []
	for idx in range(army.size()):
		var troop: Dictionary = army[idx]
		var ability: Dictionary = get_active_ability(troop["troop_id"])
		if ability.is_empty():
			continue
		if troop.get("ability_used", false):
			continue
		result.append({
			"index": idx,
			"troop_id": troop["troop_id"],
			"ability": ability,
		})
	return result


# ─── Aura Queries (T4) ──────────────────────────────────────────────────────

## Returns combined aura bonuses from all T4 troops in an army.
## { "atk": total, "def": total, "map_effects": Array }
func compute_aura_bonuses(army: Array) -> Dictionary:
	var result: Dictionary = {"atk": 0, "def": 0, "map_effects": []}
	for troop in army:
		var tid: String = troop["troop_id"]
		if not AURA_DEFS.has(tid):
			continue
		if troop.get("soldiers", 0) <= 0:
			continue
		var aura: Dictionary = AURA_DEFS[tid]
		var combat: Dictionary = aura.get("combat_aura", {})
		result["atk"] += combat.get("atk", 0)
		result["def"] += combat.get("def", 0)
		result["map_effects"].append(aura.get("map_effect", {}))
	return result


# ─── Internal ─────────────────────────────────────────────────────────────────
