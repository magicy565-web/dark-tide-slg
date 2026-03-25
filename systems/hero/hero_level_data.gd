## 暗潮 Dark Tide SLG — 英雄等级静态数据
## 纯常量文件，不含任何运行时状态。
class_name HeroLevelData
extends RefCounted

# =============================================================================
#  1. 经验值表 (累计经验, Lv1-50)
#     Lv1-20: 原始数据不变，保证存档向下兼容
#     Lv21-50: 平滑递增的多项式增长曲线
# =============================================================================

const MAX_LEVEL: int = 50

## 索引 0 = Lv1 所需累计经验(0), 索引 49 = Lv50
const EXP_TABLE: Array[int] = [
	# Lv 1-10
	0, 15, 35, 60, 90, 125, 165, 210, 260, 315,
	# Lv 11-20（原始数据，未修改）
	380, 455, 540, 635, 740, 860, 995, 1145, 1310, 1500,
	# Lv 21-30（新增：中期成长区间）
	1708, 1935, 2182, 2450, 2740, 3053, 3390, 3752, 4140, 4555,
	# Lv 31-40（新增：后期加速区间）
	4998, 5471, 5976, 6515, 7090, 7703, 8356, 9051, 9790, 10575,
	# Lv 41-50（新增：终末冲刺区间）
	11408, 12292, 13230, 14225, 15280, 16398, 17582, 18835, 20160, 21560,
]

# =============================================================================
#  2. 经验值奖励常量
# =============================================================================

const EXP_COMBAT_WIN: int = 10   ## 战斗胜利
const EXP_COMBAT_LOSS: int = 3   ## 战斗失败
const EXP_PER_KILL: int = 2      ## 每击杀一个部队
const EXP_BOSS_BONUS: int = 15   ## 击败Boss额外奖励

# =============================================================================
#  3. 英雄基础属性 (Lv1)
# =============================================================================

## hero_id -> { name, role, base_hp, base_mp, atk, def, int_stat, spd }
const HERO_BASE_STATS: Dictionary = {
	"rin": {
		"name": "凛", "role": "圣剑骑士",
		"base_hp": 30, "base_mp": 10,
		"atk": 7, "def": 8, "int_stat": 5, "spd": 4,
	},
	"yukino": {
		"name": "雪乃", "role": "治愈祭司",
		"base_hp": 20, "base_mp": 15,
		"atk": 3, "def": 4, "int_stat": 8, "spd": 5,
	},
	"momiji": {
		"name": "红叶", "role": "枫将军",
		"base_hp": 25, "base_mp": 10,
		"atk": 5, "def": 5, "int_stat": 7, "spd": 6,
	},
	"hyouka": {
		"name": "冰华", "role": "圣殿守护",
		"base_hp": 35, "base_mp": 8,
		"atk": 6, "def": 9, "int_stat": 4, "spd": 3,
	},
	"suirei": {
		"name": "翠玲", "role": "精灵射手",
		"base_hp": 22, "base_mp": 10,
		"atk": 8, "def": 3, "int_stat": 6, "spd": 7,
	},
	"gekka": {
		"name": "月华", "role": "月神巫女",
		"base_hp": 18, "base_mp": 15,
		"atk": 4, "def": 5, "int_stat": 9, "spd": 4,
	},
	"hakagure": {
		"name": "叶隐", "role": "影忍",
		"base_hp": 22, "base_mp": 8,
		"atk": 6, "def": 4, "int_stat": 5, "spd": 8,
	},
	"sou": {
		"name": "蒼", "role": "大贤者",
		"base_hp": 25, "base_mp": 12,
		"atk": 9, "def": 6, "int_stat": 9, "spd": 3,
	},
	"shion": {
		"name": "紫苑", "role": "时空法师",
		"base_hp": 18, "base_mp": 12,
		"atk": 5, "def": 4, "int_stat": 9, "spd": 7,
	},
	"homura": {
		"name": "焔", "role": "炎舞法师",
		"base_hp": 22, "base_mp": 10,
		"atk": 8, "def": 3, "int_stat": 7, "spd": 8,
	},
}

# =============================================================================
#  4. 成长率 (单位: 十分之一, 7 = +0.7/级)
#     公式: stat_at_level = base + floor(rate * (level - 1) / 10)
# =============================================================================

const GROWTH_RATES: Dictionary = {
	"rin":      { "hp": 9,  "mp": 3, "atk": 7, "def": 8, "int_stat": 4,  "spd": 4  },
	"yukino":   { "hp": 6,  "mp": 8, "atk": 2, "def": 4, "int_stat": 9,  "spd": 4  },
	"momiji":   { "hp": 7,  "mp": 5, "atk": 5, "def": 5, "int_stat": 7,  "spd": 7  },
	"hyouka":   { "hp": 10, "mp": 2, "atk": 5, "def": 9, "int_stat": 3,  "spd": 2  },
	"suirei":   { "hp": 6,  "mp": 4, "atk": 9, "def": 3, "int_stat": 5,  "spd": 8  },
	"gekka":    { "hp": 5,  "mp": 9, "atk": 3, "def": 4, "int_stat": 10, "spd": 3  },
	"hakagure": { "hp": 6,  "mp": 3, "atk": 7, "def": 3, "int_stat": 4,  "spd": 10 },
	"sou":      { "hp": 7,  "mp": 7, "atk": 8, "def": 5, "int_stat": 9,  "spd": 2  },
	"shion":    { "hp": 5,  "mp": 8, "atk": 4, "def": 3, "int_stat": 9,  "spd": 8  },
	"homura":   { "hp": 6,  "mp": 5, "atk": 8, "def": 2, "int_stat": 7,  "spd": 8  },
}

# =============================================================================
#  5. 被动技能解锁树
#     Lv3 / 7 / 12 / 18: 原始4个被动（未修改，保证存档兼容）
#     Lv25 / 30 / 35 / 40 / 45 / 50: 新增6个高阶被动
# =============================================================================

const PASSIVE_UNLOCK_TREE: Dictionary = {
	# ── 凛（圣剑骑士）─────────────────────────────────────
	"rin": [
		{
			"level": 3, "passive_id": "rin_resolve",
			"name": "不屈意志", "desc": "HP<30%时DEF+3",
			"type": "conditional_stat",
			"condition": "hp_below_pct", "threshold": 30,
			"stat": "def", "value": 3,
		},
		{
			"level": 7, "passive_id": "rin_inspire",
			"name": "鼓舞士气", "desc": "全军ATK+1(存活时)",
			"type": "aura",
			"stat": "atk", "value": 1,
		},
		{
			"level": 12, "passive_id": "rin_counter_master",
			"name": "反击达人", "desc": "反击伤害×1.5",
			"type": "on_hit",
			"counter_mult": 1.5,
		},
		{
			"level": 18, "passive_id": "rin_holy_blade",
			"name": "圣剑觉醒", "desc": "首击×2.0, 无视30%DEF",
			"type": "first_attack",
			"damage_mult": 2.0, "def_ignore_pct": 30,
		},
		# ── Lv25-50 新增被动 ──
		{
			"level": 25, "passive_id": "rin_oath_of_light",
			"name": "光之誓约", "desc": "全军DEF+2, 受治疗效果+20%",
			"type": "aura",
			"stats": { "def": 2 }, "heal_received_bonus_pct": 20,
		},
		{
			"level": 30, "passive_id": "rin_blade_aura",
			"name": "剑气纵横", "desc": "普攻附带溅射(周围敌军受30%伤害)",
			"type": "on_hit",
			"splash_damage_pct": 30,
		},
		{
			"level": 35, "passive_id": "rin_guardian_vow",
			"name": "守护之誓", "desc": "友军被致命攻击时25%替其承受(每回合1次)",
			"type": "special",
			"intercept_chance_pct": 25, "uses_per_round": 1,
		},
		{
			"level": 40, "passive_id": "rin_holy_shield",
			"name": "圣盾", "desc": "每场战斗首次受致命伤害时保留1HP并免疫1回合",
			"type": "on_death",
			"survive_guaranteed": true, "immunity_rounds": 1, "uses_per_battle": 1,
		},
		{
			"level": 45, "passive_id": "rin_radiant_edge",
			"name": "辉光斩", "desc": "暴击时额外造成ATK×0.5圣属性伤害(无视DEF)",
			"type": "on_crit",
			"bonus_damage_atk_mult": 0.5, "ignore_def": true,
		},
		{
			"level": 50, "passive_id": "rin_excalibur",
			"name": "圣剑·终焉", "desc": "全军ATK+3, DEF+3; 首击×2.5无视50%DEF",
			"type": "aura",
			"stats": { "atk": 3, "def": 3 },
			"first_attack_mult": 2.5, "def_ignore_pct": 50,
		},
	],

	# ── 雪乃（治愈祭司）───────────────────────────────────
	"yukino": [
		{
			"level": 3, "passive_id": "yukino_gentle_heal",
			"name": "慈爱之手", "desc": "每回合恢复最伤部队1兵HP",
			"type": "per_round",
			"heal_target": "most_injured", "heal_amount": 1,
		},
		{
			"level": 7, "passive_id": "yukino_mana_spring",
			"name": "法力涌泉", "desc": "+2法力/回合",
			"type": "per_round",
			"mp_regen": 2,
		},
		{
			"level": 12, "passive_id": "yukino_aegis",
			"name": "守护结界", "desc": "全军首次受击-20%",
			"type": "special",
			"first_hit_reduction_pct": 20,
		},
		{
			"level": 18, "passive_id": "yukino_resurrection",
			"name": "复活奇迹", "desc": "首个被歼灭部队恢复50%兵力(每场1次)",
			"type": "special",
			"revive_hp_pct": 50, "uses_per_battle": 1,
		},
		# ── Lv25-50 新增被动 ──
		{
			"level": 25, "passive_id": "yukino_purify",
			"name": "净化之光", "desc": "每2回合移除全军1个负面状态",
			"type": "per_round",
			"interval": 2, "effect": "remove_ally_debuff", "count": 1,
		},
		{
			"level": 30, "passive_id": "yukino_healing_wave",
			"name": "治愈波动", "desc": "治疗技能额外恢复相邻友军50%治疗量",
			"type": "special",
			"splash_heal_pct": 50, "range": "adjacent",
		},
		{
			"level": 35, "passive_id": "yukino_divine_shield",
			"name": "神圣护盾", "desc": "全军每场战斗可吸收一次等于INT×3的伤害",
			"type": "special",
			"shield_int_mult": 3, "uses_per_battle": 1,
		},
		{
			"level": 40, "passive_id": "yukino_life_link",
			"name": "生命链接", "desc": "全军受伤平摊(单个部队不会被集火秒杀)",
			"type": "special",
			"damage_distribution": true,
		},
		{
			"level": 45, "passive_id": "yukino_miracle_bloom",
			"name": "奇迹绽放", "desc": "+3法力/回合, 治疗技能法力消耗-2",
			"type": "per_round",
			"mp_regen": 3, "heal_mp_reduction": 2,
		},
		{
			"level": 50, "passive_id": "yukino_eternal_grace",
			"name": "永恒慈悲", "desc": "每回合恢复全军2兵HP; 复活次数+1(共2次/场)",
			"type": "per_round",
			"heal_target": "all_allies", "heal_amount": 2,
			"revive_extra_uses": 1,
		},
	],

	# ── 红叶（枫将军）─────────────────────────────────────
	"momiji": [
		{
			"level": 3, "passive_id": "momiji_swift_command",
			"name": "迅捷指挥", "desc": "全军SPD+1",
			"type": "aura",
			"stat": "spd", "value": 1,
		},
		{
			"level": 7, "passive_id": "momiji_tactical_eye",
			"name": "战术之眼", "desc": "首回合全军ATK+2",
			"type": "conditional_stat",
			"condition": "first_round",
			"stat": "atk", "value": 2,
		},
		{
			"level": 12, "passive_id": "momiji_rally",
			"name": "集结号令", "desc": "友军被歼灭时全军ATK+2(本场永久)",
			"type": "on_ally_death",
			"stat": "atk", "value": 2, "permanent": true,
		},
		{
			"level": 18, "passive_id": "momiji_supreme_command",
			"name": "统帅之极", "desc": "全军ATK+2, DEF+2, SPD+1",
			"type": "aura",
			"stats": { "atk": 2, "def": 2, "spd": 1 },
		},
		# ── Lv25-50 新增被动 ──
		{
			"level": 25, "passive_id": "momiji_war_drums",
			"name": "战鼓激励", "desc": "全军暴击率+10%",
			"type": "aura",
			"crit_bonus_pct": 10,
		},
		{
			"level": 30, "passive_id": "momiji_pincer_attack",
			"name": "钳形攻势", "desc": "前后排同时有友军时全军ATK+3",
			"type": "conditional_stat",
			"condition": "both_rows_occupied",
			"stat": "atk", "value": 3,
		},
		{
			"level": 35, "passive_id": "momiji_iron_discipline",
			"name": "铁血纪律", "desc": "全军DEF+3, 免疫士气崩溃",
			"type": "aura",
			"stat": "def", "value": 3, "morale_immune": true,
		},
		{
			"level": 40, "passive_id": "momiji_decisive_strike",
			"name": "决战号令", "desc": "每场战斗可发动1次: 全军本回合ATK×1.5",
			"type": "active_passive",
			"atk_mult": 1.5, "duration": 1, "uses_per_battle": 1,
		},
		{
			"level": 45, "passive_id": "momiji_unyielding_banner",
			"name": "不倒战旗", "desc": "友军被歼灭时全军ATK+3, DEF+1(本场永久)",
			"type": "on_ally_death",
			"stats": { "atk": 3, "def": 1 }, "permanent": true,
		},
		{
			"level": 50, "passive_id": "momiji_conqueror",
			"name": "天下布武", "desc": "全军ATK+4, DEF+3, SPD+2; 首回合全军额外行动1次",
			"type": "aura",
			"stats": { "atk": 4, "def": 3, "spd": 2 },
			"first_round_extra_action": 1,
		},
	],

	# ── 冰华（圣殿守护）───────────────────────────────────
	"hyouka": [
		{
			"level": 3, "passive_id": "hyouka_iron_wall",
			"name": "铁壁", "desc": "据点防守时DEF+2",
			"type": "conditional_stat",
			"condition": "defending_stronghold",
			"stat": "def", "value": 2,
		},
		{
			"level": 7, "passive_id": "hyouka_shield_bash",
			"name": "盾击", "desc": "被攻击时20%跳过敌方下次行动",
			"type": "on_hit",
			"chance_pct": 20, "effect": "skip_enemy_action",
		},
		{
			"level": 12, "passive_id": "hyouka_phalanx",
			"name": "方阵防御", "desc": "前排友军DEF+3",
			"type": "aura_row",
			"row": "front", "stat": "def", "value": 3,
		},
		{
			"level": 18, "passive_id": "hyouka_immortal_guard",
			"name": "不死守卫", "desc": "HP归零时50%保留1兵(每场1次)",
			"type": "on_death",
			"survive_chance_pct": 50, "uses_per_battle": 1,
		},
		# ── Lv25-50 新增被动 ──
		{
			"level": 25, "passive_id": "hyouka_frost_armor",
			"name": "霜甲", "desc": "受到物理攻击时20%冻结攻击者1回合",
			"type": "on_hit",
			"chance_pct": 20, "effect": "freeze_attacker", "duration": 1,
		},
		{
			"level": 30, "passive_id": "hyouka_fortified_wall",
			"name": "城墙坚守", "desc": "据点防守时全军DEF+4, 城防削减-30%",
			"type": "conditional_stat",
			"condition": "defending_stronghold",
			"stat": "def", "value": 4, "siege_reduction_pct": 30,
		},
		{
			"level": 35, "passive_id": "hyouka_taunt_aura",
			"name": "挑衅光环", "desc": "强制敌方优先攻击冰华所在部队",
			"type": "targeting",
			"force_target": true,
		},
		{
			"level": 40, "passive_id": "hyouka_damage_reflection",
			"name": "伤害反射", "desc": "反弹受到伤害的20%给攻击者",
			"type": "on_hit",
			"reflect_damage_pct": 20,
		},
		{
			"level": 45, "passive_id": "hyouka_unbreakable",
			"name": "不破之盾", "desc": "HP<50%时DEF翻倍, 受治疗效果+30%",
			"type": "conditional_stat",
			"condition": "hp_below_pct", "threshold": 50,
			"def_mult": 2.0, "heal_received_bonus_pct": 30,
		},
		{
			"level": 50, "passive_id": "hyouka_absolute_defense",
			"name": "绝对防御", "desc": "全军DEF+5; HP归零时100%保留1兵(每场2次)",
			"type": "aura",
			"stat": "def", "value": 5,
			"on_death_survive_pct": 100, "uses_per_battle": 2,
		},
	],

	# ── 翠玲（精灵射手）───────────────────────────────────
	"suirei": [
		{
			"level": 3, "passive_id": "suirei_eagle_eye",
			"name": "鹰眼", "desc": "攻击后排ATK+2",
			"type": "conditional_stat",
			"condition": "target_back_row",
			"stat": "atk", "value": 2,
		},
		{
			"level": 7, "passive_id": "suirei_double_shot",
			"name": "连射", "desc": "20%概率攻击两次",
			"type": "special",
			"chance_pct": 20, "extra_attacks": 1,
		},
		{
			"level": 12, "passive_id": "suirei_armor_pierce",
			"name": "穿甲箭", "desc": "无视目标30%DEF",
			"type": "special",
			"def_ignore_pct": 30,
		},
		{
			"level": 18, "passive_id": "suirei_moonlit_barrage",
			"name": "月下乱箭", "desc": "先制阶段额外攻击全后排(ATK×0.5)",
			"type": "priority",
			"target": "all_back_row", "damage_mult": 0.5,
		},
		# ── Lv25-50 新增被动 ──
		{
			"level": 25, "passive_id": "suirei_wind_arrow",
			"name": "风之箭", "desc": "攻击后排ATK+4(替代鹰眼), 35%概率攻击两次",
			"type": "conditional_stat",
			"condition": "target_back_row",
			"stat": "atk", "value": 4, "double_shot_pct": 35,
		},
		{
			"level": 30, "passive_id": "suirei_heart_seeker",
			"name": "追心箭", "desc": "暴击率+20%, 暴击伤害×2.0",
			"type": "special",
			"crit_bonus_pct": 20, "crit_mult": 2.0,
		},
		{
			"level": 35, "passive_id": "suirei_suppressive_fire",
			"name": "压制射击", "desc": "先制阶段被翠玲攻击的目标本回合ATK-3",
			"type": "priority",
			"debuff_stat": "atk", "debuff_value": -3, "duration": 1,
		},
		{
			"level": 40, "passive_id": "suirei_phantom_arrow",
			"name": "幻影箭", "desc": "无视目标50%DEF(替代穿甲箭)",
			"type": "special",
			"def_ignore_pct": 50,
		},
		{
			"level": 45, "passive_id": "suirei_arrow_rain",
			"name": "箭雨", "desc": "先制阶段额外攻击全体敌军(ATK×0.3)",
			"type": "priority",
			"target": "all_enemies", "damage_mult": 0.3,
		},
		{
			"level": 50, "passive_id": "suirei_divine_marksman",
			"name": "神射·极", "desc": "50%概率攻击三次; 先制AoE伤害(ATK×0.6)",
			"type": "special",
			"triple_shot_pct": 50,
			"priority_aoe_mult": 0.6,
		},
	],

	# ── 月华（月神巫女）───────────────────────────────────
	"gekka": [
		{
			"level": 3, "passive_id": "gekka_mana_flow",
			"name": "法力流动", "desc": "+1法力/回合",
			"type": "per_round",
			"mp_regen": 1,
		},
		{
			"level": 7, "passive_id": "gekka_moonlight_heal",
			"name": "月光治愈", "desc": "全军每回合恢复1兵HP",
			"type": "per_round",
			"heal_target": "all_allies", "heal_amount": 1,
		},
		{
			"level": 12, "passive_id": "gekka_dispel",
			"name": "驱散", "desc": "每3回合移除敌方1个增益",
			"type": "per_round",
			"interval": 3, "effect": "remove_enemy_buff", "count": 1,
		},
		{
			"level": 18, "passive_id": "gekka_lunar_blessing",
			"name": "月神祝福", "desc": "友军INT+3, 技能冷却-1",
			"type": "aura",
			"stat": "int_stat", "value": 3, "cooldown_reduction": 1,
		},
		# ── Lv25-50 新增被动 ──
		{
			"level": 25, "passive_id": "gekka_crescent_ward",
			"name": "新月结界", "desc": "全军每回合恢复2兵HP(替代月光治愈)",
			"type": "per_round",
			"heal_target": "all_allies", "heal_amount": 2,
		},
		{
			"level": 30, "passive_id": "gekka_moonbeam",
			"name": "月光束", "desc": "每2回合对HP最高敌军造成INT×2伤害",
			"type": "per_round",
			"interval": 2, "target": "enemy_max_hp", "damage_int_mult": 2,
		},
		{
			"level": 35, "passive_id": "gekka_lunar_tide",
			"name": "月潮", "desc": "+2法力/回合, 每2回合移除敌方2个增益",
			"type": "per_round",
			"mp_regen": 2, "interval": 2, "remove_buff_count": 2,
		},
		{
			"level": 40, "passive_id": "gekka_astral_barrier",
			"name": "星界屏障", "desc": "全军法术伤害减免30%",
			"type": "aura",
			"magic_damage_reduction_pct": 30,
		},
		{
			"level": 45, "passive_id": "gekka_full_moon_grace",
			"name": "满月恩赐", "desc": "友军INT+5, 技能冷却-2(替代月神祝福)",
			"type": "aura",
			"stat": "int_stat", "value": 5, "cooldown_reduction": 2,
		},
		{
			"level": 50, "passive_id": "gekka_eternal_moonlight",
			"name": "永夜月华", "desc": "全军每回合恢复3兵HP; 每回合驱散全部敌方增益; INT+6",
			"type": "per_round",
			"heal_target": "all_allies", "heal_amount": 3,
			"dispel_all_enemy_buffs": true,
			"aura_int": 6,
		},
	],

	# ── 叶隐（影忍）───────────────────────────────────────
	"hakagure": [
		{
			"level": 3, "passive_id": "hakagure_stealth",
			"name": "隐身术", "desc": "首回合不可被攻击",
			"type": "stealth",
			"duration_rounds": 1,
		},
		{
			"level": 7, "passive_id": "hakagure_backstab",
			"name": "背刺", "desc": "攻击后排ATK+3",
			"type": "conditional_stat",
			"condition": "target_back_row",
			"stat": "atk", "value": 3,
		},
		{
			"level": 12, "passive_id": "hakagure_lethal",
			"name": "致命打击", "desc": "暴击率+15%",
			"type": "special",
			"crit_bonus_pct": 15,
		},
		{
			"level": 18, "passive_id": "hakagure_phantom",
			"name": "幻影分身", "desc": "30%闪避率",
			"type": "on_hit",
			"dodge_chance_pct": 30,
		},
		# ── Lv25-50 新增被动 ──
		{
			"level": 25, "passive_id": "hakagure_shadow_step",
			"name": "影步", "desc": "隐身延长至2回合; SPD+3",
			"type": "stealth",
			"duration_rounds": 2, "stat_bonus": { "spd": 3 },
		},
		{
			"level": 30, "passive_id": "hakagure_assassinate",
			"name": "暗杀", "desc": "对HP<30%的目标伤害×2.5",
			"type": "conditional_stat",
			"condition": "target_hp_below_pct", "threshold": 30,
			"damage_mult": 2.5,
		},
		{
			"level": 35, "passive_id": "hakagure_smoke_bomb",
			"name": "烟雾弹", "desc": "被攻击时20%使全队获得隐身1回合(每场2次)",
			"type": "on_hit",
			"chance_pct": 20, "effect": "team_stealth", "duration": 1,
			"uses_per_battle": 2,
		},
		{
			"level": 40, "passive_id": "hakagure_vital_strike",
			"name": "要害一击", "desc": "暴击率+30%(替代致命打击); 暴击伤害×2.5",
			"type": "special",
			"crit_bonus_pct": 30, "crit_mult": 2.5,
		},
		{
			"level": 45, "passive_id": "hakagure_vanish",
			"name": "消失", "desc": "45%闪避率(替代幻影分身); 闪避后下次攻击ATK+5",
			"type": "on_hit",
			"dodge_chance_pct": 45, "post_dodge_atk_bonus": 5,
		},
		{
			"level": 50, "passive_id": "hakagure_shadow_sovereign",
			"name": "影之主宰", "desc": "3回合隐身; 暴击率+40%; 闪避50%; 首击×3.0",
			"type": "special",
			"stealth_rounds": 3, "crit_bonus_pct": 40,
			"dodge_chance_pct": 50, "first_attack_mult": 3.0,
		},
	],

	# ── 蒼（大贤者）───────────────────────────────────────
	"sou": [
		{
			"level": 3, "passive_id": "sou_arcane_focus",
			"name": "奥术聚焦", "desc": "法术伤害+10%",
			"type": "special",
			"spell_damage_bonus_pct": 10,
		},
		{
			"level": 7, "passive_id": "sou_mana_surge",
			"name": "法力奔涌", "desc": "+2法力/回合",
			"type": "per_round",
			"mp_regen": 2,
		},
		{
			"level": 12, "passive_id": "sou_spell_mastery",
			"name": "法术精通", "desc": "AoE法术额外命中后排1个目标",
			"type": "special",
			"aoe_extra_targets": 1, "target": "back_row",
		},
		{
			"level": 18, "passive_id": "sou_archmage",
			"name": "大魔导师", "desc": "法术伤害+30%, AoE法力消耗-3",
			"type": "special",
			"spell_damage_bonus_pct": 30, "aoe_mp_reduction": 3,
		},
		# ── Lv25-50 新增被动 ──
		{
			"level": 25, "passive_id": "sou_elemental_mastery",
			"name": "元素精通", "desc": "法术伤害+20%(叠加); AoE额外命中2目标",
			"type": "special",
			"spell_damage_bonus_pct": 20, "aoe_extra_targets": 2,
		},
		{
			"level": 30, "passive_id": "sou_mana_overflow",
			"name": "魔力溢出", "desc": "+3法力/回合; MP满时法术伤害额外+15%",
			"type": "per_round",
			"mp_regen": 3, "full_mp_spell_bonus_pct": 15,
		},
		{
			"level": 35, "passive_id": "sou_spell_penetration",
			"name": "法术穿透", "desc": "法术攻击无视目标40%魔抗",
			"type": "special",
			"magic_resist_ignore_pct": 40,
		},
		{
			"level": 40, "passive_id": "sou_arcane_explosion",
			"name": "奥术爆发", "desc": "每5回合自动释放全体AoE(INT×3伤害)",
			"type": "per_round",
			"interval": 5, "aoe_damage_int_mult": 3,
		},
		{
			"level": 45, "passive_id": "sou_sage_wisdom",
			"name": "贤者慧眼", "desc": "全军INT+4; 法术冷却-2",
			"type": "aura",
			"stat": "int_stat", "value": 4, "cooldown_reduction": 2,
		},
		{
			"level": 50, "passive_id": "sou_grand_archmage",
			"name": "大魔导·极", "desc": "法术伤害+50%; AoE命中全体; 法力消耗-5; +4法力/回合",
			"type": "special",
			"spell_damage_bonus_pct": 50, "aoe_target_all": true,
			"aoe_mp_reduction": 5, "mp_regen": 4,
		},
	],

	# ── 紫苑（时空法师）───────────────────────────────────
	"shion": [
		{
			"level": 3, "passive_id": "shion_time_sense",
			"name": "时间感知", "desc": "SPD+2",
			"type": "stat_bonus",
			"stat": "spd", "value": 2,
		},
		{
			"level": 7, "passive_id": "shion_slow_field",
			"name": "减速领域", "desc": "敌全军SPD-1",
			"type": "aura_enemy",
			"stat": "spd", "value": -1,
		},
		{
			"level": 12, "passive_id": "shion_temporal_dodge",
			"name": "时空闪避", "desc": "每回合首次被攻击25%免伤",
			"type": "on_hit",
			"first_hit_dodge_pct": 25,
		},
		{
			"level": 18, "passive_id": "shion_time_lord",
			"name": "时空之主", "desc": "每3回合全军额外行动1次",
			"type": "special",
			"interval": 3, "effect": "extra_team_action",
		},
		# ── Lv25-50 新增被动 ──
		{
			"level": 25, "passive_id": "shion_haste",
			"name": "加速术", "desc": "全军SPD+2; 敌全军SPD-2",
			"type": "aura",
			"ally_spd": 2, "enemy_spd": -2,
		},
		{
			"level": 30, "passive_id": "shion_time_rewind",
			"name": "时光倒流", "desc": "每场战斗可撤销最近1次友军伤亡(每场1次)",
			"type": "special",
			"undo_last_casualty": true, "uses_per_battle": 1,
		},
		{
			"level": 35, "passive_id": "shion_temporal_cage",
			"name": "时空牢笼", "desc": "每4回合冻结1个敌方单位2回合",
			"type": "per_round",
			"interval": 4, "effect": "freeze_enemy", "duration": 2,
		},
		{
			"level": 40, "passive_id": "shion_chrono_shift",
			"name": "时空跃迁", "desc": "每2回合全军额外行动1次(替代时空之主)",
			"type": "special",
			"interval": 2, "effect": "extra_team_action",
		},
		{
			"level": 45, "passive_id": "shion_parallel_timeline",
			"name": "平行时间线", "desc": "40%免伤(替代时空闪避); SPD+4",
			"type": "on_hit",
			"first_hit_dodge_pct": 40, "stat_bonus": { "spd": 4 },
		},
		{
			"level": 50, "passive_id": "shion_time_sovereign",
			"name": "时空支配者", "desc": "全军SPD+4; 敌军SPD-3; 每回合全军额外行动1次",
			"type": "aura",
			"ally_spd": 4, "enemy_spd": -3,
			"extra_team_action_per_round": 1,
		},
	],

	# ── 焔（炎舞法师）─────────────────────────────────────
	"homura": [
		{
			"level": 3, "passive_id": "homura_burn",
			"name": "灼烧", "desc": "攻击附带1回合DoT(ATK×0.2)",
			"type": "on_hit",
			"dot_rounds": 1, "dot_atk_mult": 0.2,
		},
		{
			"level": 7, "passive_id": "homura_fire_aura",
			"name": "火焰光环", "desc": "相邻友军ATK+2",
			"type": "aura",
			"stat": "atk", "value": 2, "range": "adjacent",
		},
		{
			"level": 12, "passive_id": "homura_explosion",
			"name": "引爆", "desc": "灼烧中敌人受伤+20%",
			"type": "special",
			"condition": "target_burning",
			"damage_bonus_pct": 20,
		},
		{
			"level": 18, "passive_id": "homura_inferno",
			"name": "炼狱", "desc": "AoE附加3回合灼烧+敌方治疗-50%",
			"type": "special",
			"dot_rounds": 3, "heal_reduction_pct": 50,
		},
		# ── Lv25-50 新增被动 ──
		{
			"level": 25, "passive_id": "homura_wildfire",
			"name": "野火蔓延", "desc": "灼烧扩散至相邻敌军; DoT伤害提升至ATK×0.3",
			"type": "on_hit",
			"dot_spread": true, "dot_atk_mult": 0.3,
		},
		{
			"level": 30, "passive_id": "homura_fire_storm",
			"name": "火焰风暴", "desc": "全军ATK+3(替代火焰光环); 敌方受火属性伤害+25%",
			"type": "aura",
			"stat": "atk", "value": 3,
			"fire_damage_taken_bonus_pct": 25,
		},
		{
			"level": 35, "passive_id": "homura_melt_armor",
			"name": "熔甲", "desc": "灼烧中敌人DEF-4; 受伤+30%(替代引爆)",
			"type": "special",
			"condition": "target_burning",
			"def_reduction": 4, "damage_bonus_pct": 30,
		},
		{
			"level": 40, "passive_id": "homura_phoenix_flame",
			"name": "凤凰之焰", "desc": "被击倒时对全体敌军造成ATK×3伤害(每场1次)",
			"type": "on_death",
			"aoe_damage_atk_mult": 3, "uses_per_battle": 1,
		},
		{
			"level": 45, "passive_id": "homura_eternal_flame",
			"name": "永恒之焰", "desc": "灼烧DoT提升至ATK×0.5; 灼烧无法被驱散",
			"type": "on_hit",
			"dot_atk_mult": 0.5, "dot_undispellable": true,
		},
		{
			"level": 50, "passive_id": "homura_hellfire_lord",
			"name": "炎帝", "desc": "全军ATK+5; AoE附加5回合灼烧; 敌方治疗-80%; 火伤+50%",
			"type": "special",
			"aura_atk": 5, "dot_rounds": 5,
			"heal_reduction_pct": 80, "fire_damage_bonus_pct": 50,
		},
	],
}

# =============================================================================
#  6. 静态辅助函数
# =============================================================================


## 返回指定等级所需的累计经验值
static func get_exp_for_level(level: int) -> int:
	var clamped: int = clampi(level, 1, MAX_LEVEL)
	return EXP_TABLE[clamped - 1]


## Alias for get_exp_for_level — used by hero_leveling.gd
static func get_cumulative_exp_for_level(level: int) -> int:
	return get_exp_for_level(level)


## 根据累计经验值返回当前等级
static func get_level_for_exp(exp: int) -> int:
	for i in range(MAX_LEVEL - 1, -1, -1):
		if exp >= EXP_TABLE[i]:
			return i + 1
	return 1


## 计算某属性在指定等级时的数值
## stat_at_level = base + floor(growth_rate * (level - 1) / 10)
static func calc_stat(base: int, growth_rate: int, level: int) -> int:
	return base + (growth_rate * (level - 1)) / 10


## 返回英雄在指定等级的完整属性字典
static func get_hero_stats_at_level(hero_id: String, level: int) -> Dictionary:
	if not HERO_BASE_STATS.has(hero_id) or not GROWTH_RATES.has(hero_id):
		# Fallback for heroes without leveling data (pirate/dark_elf/neutral heroes):
		# Pull base stats from FactionData.HEROES and return them without growth.
		var fd_hero: Dictionary = preload("res://systems/faction/faction_data.gd").HEROES.get(hero_id, {})
		if fd_hero.is_empty():
			push_warning("HeroLevelData: 未知的英雄ID且无FactionData条目: " + hero_id)
			return {"name": hero_id, "role": "", "level": 1, "hp": 20, "mp": 8, "atk": 5, "def": 5, "int_stat": 5, "spd": 5}
		return {
			"name": fd_hero.get("name", hero_id),
			"role": "",
			"level": clampi(level, 1, MAX_LEVEL),
			"hp": fd_hero.get("base_hp", 20),
			"mp": fd_hero.get("base_mp", 8),
			"atk": fd_hero.get("atk", 5),
			"def": fd_hero.get("def", 5),
			"int_stat": fd_hero.get("int", 5),
			"spd": fd_hero.get("spd", 5),
		}

	var base: Dictionary = HERO_BASE_STATS[hero_id]
	var growth: Dictionary = GROWTH_RATES[hero_id]
	var clamped: int = clampi(level, 1, MAX_LEVEL)

	return {
		"name": base["name"],
		"role": base["role"],
		"level": clamped,
		"hp": calc_stat(base["base_hp"], growth["hp"], clamped),
		"mp": calc_stat(base["base_mp"], growth["mp"], clamped),
		"atk": calc_stat(base["atk"], growth["atk"], clamped),
		"def": calc_stat(base["def"], growth["def"], clamped),
		"int_stat": calc_stat(base["int_stat"], growth["int_stat"], clamped),
		"spd": calc_stat(base["spd"], growth["spd"], clamped),
	}


## 返回英雄在指定等级及以下已解锁的所有被动技能
static func get_passives_at_level(hero_id: String, level: int) -> Array:
	if not PASSIVE_UNLOCK_TREE.has(hero_id):
		return []

	var result: Array = []
	var clamped: int = clampi(level, 1, MAX_LEVEL)
	for passive: Dictionary in PASSIVE_UNLOCK_TREE[hero_id]:
		if passive["level"] <= clamped:
			result.append(passive)
	return result
