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

const EXP_COMBAT_WIN: int = 15   ## 战斗胜利 — v4.2: 10→15, 与 BalanceConfig.HERO_EXP_COMBAT_WIN 对齐
const EXP_COMBAT_LOSS: int = 3   ## 战斗失败
const EXP_PER_KILL: int = 3      ## 每击杀一个部队 — v4.2: 2→3, 与 BalanceConfig.HERO_EXP_PER_KILL 对齐
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
		"name": "焔", "role": "炎舞法師",
		"base_hp": 22, "base_mp": 10,
		"atk": 8, "def": 3, "int_stat": 7, "spd": 8,
	},
	# --- Pirate / Dark Elf Heroes ---
	"shion_pirate": {
		"name": "潮音", "role": "海風射手",
		"base_hp": 24, "base_mp": 8,
		"atk": 7, "def": 4, "int_stat": 5, "spd": 7,
	},
	"youya": {
		"name": "妖夜", "role": "夜行暗殺者",
		"base_hp": 20, "base_mp": 8,
		"atk": 6, "def": 3, "int_stat": 4, "spd": 9,
	},
	# --- Neutral Leaders ---
	"hibiki": {
		"name": "響", "role": "山岳守護者",
		"base_hp": 28, "base_mp": 8,
		"atk": 5, "def": 7, "int_stat": 4, "spd": 5,
	},
	"sara": {
		"name": "沙罗", "role": "砂漠狙撃手",
		"base_hp": 22, "base_mp": 10,
		"atk": 7, "def": 3, "int_stat": 6, "spd": 6,
	},
	"mei": {
		"name": "冥", "role": "冥界召喚師",
		"base_hp": 18, "base_mp": 12,
		"atk": 8, "def": 2, "int_stat": 8, "spd": 4,
	},
	"kaede": {
		"name": "枫", "role": "幻影忍者",
		"base_hp": 20, "base_mp": 8,
		"atk": 6, "def": 4, "int_stat": 5, "spd": 9,
	},
	"akane": {
		"name": "朱音", "role": "古代巫女",
		"base_hp": 20, "base_mp": 14,
		"atk": 3, "def": 5, "int_stat": 7, "spd": 5,
	},
	"hanabi": {
		"name": "花火", "role": "砲撃手",
		"base_hp": 18, "base_mp": 8,
		"atk": 9, "def": 2, "int_stat": 5, "spd": 3,
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
	# --- Pirate / Dark Elf Heroes ---
	"shion_pirate": { "hp": 7, "mp": 3, "atk": 8, "def": 4, "int_stat": 4, "spd": 8 },
	"youya":        { "hp": 5, "mp": 3, "atk": 7, "def": 2, "int_stat": 3, "spd": 10 },
	# --- Neutral Leaders ---
	"hibiki":  { "hp": 10, "mp": 2, "atk": 4, "def": 9, "int_stat": 3, "spd": 4 },
	"sara":    { "hp": 6,  "mp": 4, "atk": 8, "def": 3, "int_stat": 5, "spd": 7 },
	"mei":     { "hp": 5,  "mp": 8, "atk": 7, "def": 2, "int_stat": 9, "spd": 3 },
	"kaede":   { "hp": 5,  "mp": 3, "atk": 7, "def": 3, "int_stat": 4, "spd": 10 },
	"akane":   { "hp": 6,  "mp": 9, "atk": 2, "def": 5, "int_stat": 8, "spd": 4 },
	"hanabi":  { "hp": 5,  "mp": 3, "atk": 10, "def": 2, "int_stat": 4, "spd": 2 },
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

	# ── 潮音（海風射手）───────────────────────────────────
	"shion_pirate": [
		{
			"level": 3, "passive_id": "shion_p_sea_breeze",
			"name": "海風の加護", "desc": "SPD+2, 弓兵射程+1",
			"type": "stat_bonus",
			"stat": "spd", "value": 2, "range_bonus": 1,
		},
		{
			"level": 7, "passive_id": "shion_p_rapid_fire",
			"name": "速射", "desc": "25%概率攻撃两次",
			"type": "special",
			"chance_pct": 25, "extra_attacks": 1,
		},
		{
			"level": 12, "passive_id": "shion_p_tidal_arrow",
			"name": "潮流矢", "desc": "攻撃附帯1回合减速(敌SPD-2)",
			"type": "on_hit",
			"debuff_stat": "spd", "debuff_value": -2, "duration": 1,
		},
		{
			"level": 18, "passive_id": "shion_p_corsair_instinct",
			"name": "海賊の勘", "desc": "闪避率+20%, 回避后ATK+3持続1回合",
			"type": "on_hit",
			"dodge_chance_pct": 20, "post_dodge_atk_bonus": 3, "bonus_duration": 1,
		},
		# ── Lv25-50 新増被動 ──
		{
			"level": 25, "passive_id": "shion_p_storm_volley",
			"name": "暴風連射", "desc": "40%概率攻撃两次; 攻撃後排ATK+3",
			"type": "special",
			"chance_pct": 40, "extra_attacks": 1,
			"back_row_atk_bonus": 3,
		},
		{
			"level": 30, "passive_id": "shion_p_ocean_current",
			"name": "海流操作", "desc": "全軍SPD+2; 敵全軍SPD-1",
			"type": "aura",
			"ally_spd": 2, "enemy_spd": -1,
		},
		{
			"level": 35, "passive_id": "shion_p_piercing_tide",
			"name": "貫潮矢", "desc": "無視目標40%DEF; 減速効果提升至SPD-3",
			"type": "special",
			"def_ignore_pct": 40, "slow_value": -3,
		},
		{
			"level": 40, "passive_id": "shion_p_maelstrom",
			"name": "大渦", "desc": "先制階段攻撃全後排(ATK×0.5); 附帯減速",
			"type": "priority",
			"target": "all_back_row", "damage_mult": 0.5, "apply_slow": true,
		},
		{
			"level": 45, "passive_id": "shion_p_phantom_fleet",
			"name": "幽霊艦隊", "desc": "闪避率+35%; 50%概率攻撃三次",
			"type": "special",
			"dodge_chance_pct": 35, "triple_shot_pct": 50,
		},
		{
			"level": 50, "passive_id": "shion_p_sovereign_tide",
			"name": "潮王·極", "desc": "全軍SPD+4; 敵SPD-3; 先制AoE(ATK×0.7); 60%三連射",
			"type": "special",
			"ally_spd": 4, "enemy_spd": -3,
			"priority_aoe_mult": 0.7, "triple_shot_pct": 60,
		},
	],

	# ── 妖夜（夜行暗殺者）─────────────────────────────────
	"youya": [
		{
			"level": 3, "passive_id": "youya_night_prowl",
			"name": "夜行", "desc": "夜間戦闘時ATK+3, SPD+2",
			"type": "conditional_stat",
			"condition": "night_battle",
			"stats": { "atk": 3, "spd": 2 },
		},
		{
			"level": 7, "passive_id": "youya_poison_blade",
			"name": "毒刃", "desc": "攻撃附帯2回合毒(毎回合ATK×0.2傷害)",
			"type": "on_hit",
			"dot_rounds": 2, "dot_atk_mult": 0.2,
		},
		{
			"level": 12, "passive_id": "youya_shadow_meld",
			"name": "影潜", "desc": "首回合隐身; 解除隐身時首撃×2.0",
			"type": "stealth",
			"duration_rounds": 1, "first_attack_mult": 2.0,
		},
		{
			"level": 18, "passive_id": "youya_lethal_dance",
			"name": "致命舞踏", "desc": "暴撃率+20%; 暴撃時追加攻撃1次",
			"type": "special",
			"crit_bonus_pct": 20, "crit_extra_attack": 1,
		},
		# ── Lv25-50 新増被動 ──
		{
			"level": 25, "passive_id": "youya_dark_venom",
			"name": "闇毒", "desc": "毒DoT提升至ATK×0.35; 中毒目標DEF-3",
			"type": "on_hit",
			"dot_atk_mult": 0.35, "poison_def_reduction": 3,
		},
		{
			"level": 30, "passive_id": "youya_elven_agility",
			"name": "精灵敏捷", "desc": "闪避率+30%; SPD+3",
			"type": "special",
			"dodge_chance_pct": 30, "stat_bonus": { "spd": 3 },
		},
		{
			"level": 35, "passive_id": "youya_death_mark",
			"name": "死之刻印", "desc": "攻撃標記目標; 被標記者受全軍傷害+25%",
			"type": "on_hit",
			"mark_damage_taken_bonus_pct": 25,
		},
		{
			"level": 40, "passive_id": "youya_shadow_dance",
			"name": "影之舞", "desc": "2回合隐身; 解除時首撃×2.5; 暴撃率+30%",
			"type": "stealth",
			"duration_rounds": 2, "first_attack_mult": 2.5, "crit_bonus_pct": 30,
		},
		{
			"level": 45, "passive_id": "youya_assassin_creed",
			"name": "暗殺信条", "desc": "対HP<40%目標傷害×2.5; 撃殺時隐身1回合",
			"type": "conditional_stat",
			"condition": "target_hp_below_pct", "threshold": 40,
			"damage_mult": 2.5, "kill_stealth_rounds": 1,
		},
		{
			"level": 50, "passive_id": "youya_phantom_sovereign",
			"name": "夜帝", "desc": "3回合隐身; 暴撃率+40%; 闪避45%; 毒DoT(ATK×0.5)無法驅散",
			"type": "special",
			"stealth_rounds": 3, "crit_bonus_pct": 40,
			"dodge_chance_pct": 45, "dot_atk_mult": 0.5, "dot_undispellable": true,
		},
	],

	# ── 響（山岳守護者）───────────────────────────────────
	"hibiki": [
		{
			"level": 3, "passive_id": "hibiki_iron_wall",
			"name": "鉄壁の構え", "desc": "據點防守時DEF+3",
			"type": "conditional_stat",
			"condition": "defending_stronghold",
			"stat": "def", "value": 3,
		},
		{
			"level": 7, "passive_id": "hibiki_mountain_vigor",
			"name": "山岳の活力", "desc": "毎回合回復1兵HP",
			"type": "per_round",
			"heal_target": "self", "heal_amount": 1,
		},
		{
			"level": 12, "passive_id": "hibiki_shield_wall",
			"name": "盾壁陣", "desc": "前排友軍DEF+3",
			"type": "aura_row",
			"row": "front", "stat": "def", "value": 3,
		},
		{
			"level": 18, "passive_id": "hibiki_unbreakable",
			"name": "不壊の体", "desc": "HP帰零時60%保留1兵(毎場1次)",
			"type": "on_death",
			"survive_chance_pct": 60, "uses_per_battle": 1,
		},
		# ── Lv25-50 新増被動 ──
		{
			"level": 25, "passive_id": "hibiki_earthquake",
			"name": "地震", "desc": "被攻撃時25%使攻撃者眩暈1回合",
			"type": "on_hit",
			"chance_pct": 25, "effect": "stun_attacker", "duration": 1,
		},
		{
			"level": 30, "passive_id": "hibiki_fortress",
			"name": "山城堅守", "desc": "據點防守時全軍DEF+4; 城防削減-30%",
			"type": "conditional_stat",
			"condition": "defending_stronghold",
			"stat": "def", "value": 4, "siege_reduction_pct": 30,
		},
		{
			"level": 35, "passive_id": "hibiki_taunt",
			"name": "挑発", "desc": "強制敵方優先攻撃響所在部隊",
			"type": "targeting",
			"force_target": true,
		},
		{
			"level": 40, "passive_id": "hibiki_avalanche",
			"name": "雪崩", "desc": "反弾受到傷害的25%給攻撃者",
			"type": "on_hit",
			"reflect_damage_pct": 25,
		},
		{
			"level": 45, "passive_id": "hibiki_immovable",
			"name": "不動明王", "desc": "HP<50%時DEF翻倍; 免疫全部控制効果",
			"type": "conditional_stat",
			"condition": "hp_below_pct", "threshold": 50,
			"def_mult": 2.0, "cc_immune": true,
		},
		{
			"level": 50, "passive_id": "hibiki_mountain_god",
			"name": "山神", "desc": "全軍DEF+5; HP帰零時100%保留1兵(毎場2次); 反射30%",
			"type": "aura",
			"stat": "def", "value": 5,
			"on_death_survive_pct": 100, "uses_per_battle": 2,
			"reflect_damage_pct": 30,
		},
	],

	# ── 沙罗（砂漠狙撃手）─────────────────────────────────
	"sara": [
		{
			"level": 3, "passive_id": "sara_desert_eye",
			"name": "砂漠の眼", "desc": "攻撃後排ATK+2",
			"type": "conditional_stat",
			"condition": "target_back_row",
			"stat": "atk", "value": 2,
		},
		{
			"level": 7, "passive_id": "sara_sandstorm_veil",
			"name": "砂嵐の帳", "desc": "闪避率+15%",
			"type": "special",
			"dodge_chance_pct": 15,
		},
		{
			"level": 12, "passive_id": "sara_heat_arrow",
			"name": "灼熱矢", "desc": "攻撃附帯1回合灼焼(ATK×0.2)",
			"type": "on_hit",
			"dot_rounds": 1, "dot_atk_mult": 0.2,
		},
		{
			"level": 18, "passive_id": "sara_mirage",
			"name": "蜃気楼", "desc": "敵軍遠程攻撃命中率-20%",
			"type": "aura_enemy",
			"ranged_accuracy_reduction_pct": 20,
		},
		# ── Lv25-50 新増被動 ──
		{
			"level": 25, "passive_id": "sara_scorching_wind",
			"name": "熱砂の風", "desc": "攻撃後排ATK+4; 30%概率攻撃两次",
			"type": "conditional_stat",
			"condition": "target_back_row",
			"stat": "atk", "value": 4, "double_shot_pct": 30,
		},
		{
			"level": 30, "passive_id": "sara_sandstorm",
			"name": "大砂嵐", "desc": "先制階段攻撃全後排(ATK×0.4); 附帯命中率低下",
			"type": "priority",
			"target": "all_back_row", "damage_mult": 0.4, "accuracy_debuff": true,
		},
		{
			"level": 35, "passive_id": "sara_oasis_blessing",
			"name": "緑洲祝福", "desc": "全軍毎回合回復1兵HP; +1法力/回合",
			"type": "per_round",
			"heal_target": "all_allies", "heal_amount": 1, "mp_regen": 1,
		},
		{
			"level": 40, "passive_id": "sara_piercing_heat",
			"name": "灼穿矢", "desc": "無視目標45%DEF; 灼焼提升至ATK×0.35",
			"type": "special",
			"def_ignore_pct": 45, "dot_atk_mult": 0.35,
		},
		{
			"level": 45, "passive_id": "sara_desert_phantom",
			"name": "砂漠幻影", "desc": "闪避率+30%; 暴撃率+20%; 暴撃傷害×2.0",
			"type": "special",
			"dodge_chance_pct": 30, "crit_bonus_pct": 20, "crit_mult": 2.0,
		},
		{
			"level": 50, "passive_id": "sara_sun_queen",
			"name": "太陽女王", "desc": "全軍ATK+4; 先制AoE(ATK×0.6); 50%三連射; 閃避35%",
			"type": "special",
			"aura_atk": 4, "priority_aoe_mult": 0.6,
			"triple_shot_pct": 50, "dodge_chance_pct": 35,
		},
	],

	# ── 冥（冥界召喚師）───────────────────────────────────
	"mei": [
		{
			"level": 3, "passive_id": "mei_dark_focus",
			"name": "冥界集中", "desc": "法術傷害+10%",
			"type": "special",
			"spell_damage_bonus_pct": 10,
		},
		{
			"level": 7, "passive_id": "mei_soul_drain",
			"name": "魂吸", "desc": "攻撃時回復MP1",
			"type": "on_hit",
			"mp_drain": 1,
		},
		{
			"level": 12, "passive_id": "mei_summon_wraith",
			"name": "亡霊召喚", "desc": "毎5回合召喚亡霊兵1隊(3兵力)",
			"type": "per_round",
			"interval": 5, "summon": "wraith", "summon_hp": 3,
		},
		{
			"level": 18, "passive_id": "mei_death_curse",
			"name": "死之呪詛", "desc": "攻撃附帯呪詛: 目標受治療効果-50%, 持続2回合",
			"type": "on_hit",
			"heal_reduction_pct": 50, "debuff_duration": 2,
		},
		# ── Lv25-50 新増被動 ──
		{
			"level": 25, "passive_id": "mei_necrotic_surge",
			"name": "死霊奔流", "desc": "法術傷害+25%; AoE額外命中2目標",
			"type": "special",
			"spell_damage_bonus_pct": 25, "aoe_extra_targets": 2,
		},
		{
			"level": 30, "passive_id": "mei_soul_harvest",
			"name": "魂魄収穫", "desc": "毎撃殺1個部隊回復MP3且ATK+2(本場永久)",
			"type": "on_kill",
			"mp_restore": 3, "stat_bonus": { "atk": 2 }, "permanent": true,
		},
		{
			"level": 35, "passive_id": "mei_undead_legion",
			"name": "不死軍団", "desc": "毎3回合召喚亡霊兵(5兵力); 亡霊ATK+2",
			"type": "per_round",
			"interval": 3, "summon": "wraith", "summon_hp": 5, "summon_atk_bonus": 2,
		},
		{
			"level": 40, "passive_id": "mei_void_rift",
			"name": "虚空裂隙", "desc": "毎4回合対全敵造成INT×2傷害; 附帯呪詛",
			"type": "per_round",
			"interval": 4, "aoe_damage_int_mult": 2, "apply_curse": true,
		},
		{
			"level": 45, "passive_id": "mei_reaper_aura",
			"name": "死神領域", "desc": "敵全軍DEF-3; 受治療効果-30%",
			"type": "aura_enemy",
			"stat": "def", "value": -3, "heal_reduction_pct": 30,
		},
		{
			"level": 50, "passive_id": "mei_lord_of_death",
			"name": "冥王", "desc": "法術傷害+50%; 毎2回合召喚亡霊(7兵力); 全敵DEF-5; INT+6",
			"type": "special",
			"spell_damage_bonus_pct": 50,
			"summon_interval": 2, "summon_hp": 7,
			"enemy_def_reduction": 5, "aura_int": 6,
		},
	],

	# ── 枫（幻影忍者）─────────────────────────────────────
	"kaede": [
		{
			"level": 3, "passive_id": "kaede_forest_stealth",
			"name": "森隠れ", "desc": "首回合隐身",
			"type": "stealth",
			"duration_rounds": 1,
		},
		{
			"level": 7, "passive_id": "kaede_clone_strike",
			"name": "分身撃", "desc": "20%概率攻撃两次",
			"type": "special",
			"chance_pct": 20, "extra_attacks": 1,
		},
		{
			"level": 12, "passive_id": "kaede_leaf_blade",
			"name": "木葉刃", "desc": "暴撃率+15%; 攻撃後排ATK+2",
			"type": "special",
			"crit_bonus_pct": 15, "back_row_atk_bonus": 2,
		},
		{
			"level": 18, "passive_id": "kaede_phantom_clone",
			"name": "幻影分身", "desc": "闪避率+25%; 分身概率提升至35%",
			"type": "special",
			"dodge_chance_pct": 25, "clone_attack_pct": 35,
		},
		# ── Lv25-50 新増被動 ──
		{
			"level": 25, "passive_id": "kaede_wind_step",
			"name": "風歩", "desc": "SPD+3; 隐身延長至2回合",
			"type": "stealth",
			"duration_rounds": 2, "stat_bonus": { "spd": 3 },
		},
		{
			"level": 30, "passive_id": "kaede_binding_vine",
			"name": "縛り蔓", "desc": "攻撃時25%使目標無法行動1回合",
			"type": "on_hit",
			"chance_pct": 25, "effect": "root_target", "duration": 1,
		},
		{
			"level": 35, "passive_id": "kaede_leaf_storm",
			"name": "木葉嵐", "desc": "先制階段攻撃全後排(ATK×0.4); 暴撃率+25%",
			"type": "priority",
			"target": "all_back_row", "damage_mult": 0.4, "crit_bonus_pct": 25,
		},
		{
			"level": 40, "passive_id": "kaede_mirror_image",
			"name": "鏡像", "desc": "闪避率+40%; 闪避後下次攻撃ATK+5",
			"type": "on_hit",
			"dodge_chance_pct": 40, "post_dodge_atk_bonus": 5,
		},
		{
			"level": 45, "passive_id": "kaede_thousand_leaves",
			"name": "千葉乱舞", "desc": "50%概率攻撃三次; 暴撃率+30%",
			"type": "special",
			"triple_shot_pct": 50, "crit_bonus_pct": 30,
		},
		{
			"level": 50, "passive_id": "kaede_forest_sovereign",
			"name": "森羅万象", "desc": "3回合隐身; 暴撃率+40%; 闪避50%; 60%三連撃; SPD+5",
			"type": "special",
			"stealth_rounds": 3, "crit_bonus_pct": 40,
			"dodge_chance_pct": 50, "triple_shot_pct": 60,
			"stat_bonus": { "spd": 5 },
		},
	],

	# ── 朱音（古代巫女）───────────────────────────────────
	"akane": [
		{
			"level": 3, "passive_id": "akane_prayer",
			"name": "祈りの力", "desc": "毎回合回復最傷部隊1兵HP",
			"type": "per_round",
			"heal_target": "most_injured", "heal_amount": 1,
		},
		{
			"level": 7, "passive_id": "akane_holy_spring",
			"name": "聖泉", "desc": "+2法力/回合",
			"type": "per_round",
			"mp_regen": 2,
		},
		{
			"level": 12, "passive_id": "akane_purify",
			"name": "浄化", "desc": "毎3回合移除全軍1個負面状態",
			"type": "per_round",
			"interval": 3, "effect": "remove_ally_debuff", "count": 1,
		},
		{
			"level": 18, "passive_id": "akane_sacred_barrier",
			"name": "聖域結界", "desc": "全軍法術傷害減免20%",
			"type": "aura",
			"magic_damage_reduction_pct": 20,
		},
		# ── Lv25-50 新増被動 ──
		{
			"level": 25, "passive_id": "akane_divine_grace",
			"name": "神恩", "desc": "全軍毎回合回復2兵HP; INT+2",
			"type": "per_round",
			"heal_target": "all_allies", "heal_amount": 2,
			"aura_int": 2,
		},
		{
			"level": 30, "passive_id": "akane_spirit_link",
			"name": "霊魂鏈接", "desc": "全軍受傷平摊(防止集火秒殺)",
			"type": "special",
			"damage_distribution": true,
		},
		{
			"level": 35, "passive_id": "akane_resurrection",
			"name": "蘇生の儀", "desc": "首個被殲滅部隊回復50%兵力(毎場1次)",
			"type": "special",
			"revive_hp_pct": 50, "uses_per_battle": 1,
		},
		{
			"level": 40, "passive_id": "akane_ancient_ward",
			"name": "古代結界", "desc": "全軍法術減免35%; 毎2回合驅散敵方2個増益",
			"type": "aura",
			"magic_damage_reduction_pct": 35,
			"dispel_interval": 2, "dispel_count": 2,
		},
		{
			"level": 45, "passive_id": "akane_miracle",
			"name": "奇跡", "desc": "+3法力/回合; 治療技能消耗-2; 蘇生次数+1",
			"type": "per_round",
			"mp_regen": 3, "heal_mp_reduction": 2, "revive_extra_uses": 1,
		},
		{
			"level": 50, "passive_id": "akane_eternal_priestess",
			"name": "永遠の巫女", "desc": "全軍毎回合回復3兵HP; INT+5; 法術減免50%; 蘇生2次/場",
			"type": "per_round",
			"heal_target": "all_allies", "heal_amount": 3,
			"aura_int": 5, "magic_damage_reduction_pct": 50,
			"revive_uses_per_battle": 2,
		},
	],

	# ── 花火（砲撃手）─────────────────────────────────────
	"hanabi": [
		{
			"level": 3, "passive_id": "hanabi_heavy_shell",
			"name": "重砲弾", "desc": "攻撃附帯濺射(周囲敵軍受20%傷害)",
			"type": "on_hit",
			"splash_damage_pct": 20,
		},
		{
			"level": 7, "passive_id": "hanabi_demolition",
			"name": "破壊工作", "desc": "対建築/城防傷害+30%",
			"type": "special",
			"siege_damage_bonus_pct": 30,
		},
		{
			"level": 12, "passive_id": "hanabi_incendiary",
			"name": "焼夷弾", "desc": "攻撃附帯2回合灼焼(ATK×0.25)",
			"type": "on_hit",
			"dot_rounds": 2, "dot_atk_mult": 0.25,
		},
		{
			"level": 18, "passive_id": "hanabi_barrage",
			"name": "一斉砲撃", "desc": "先制階段攻撃全後排(ATK×0.4)",
			"type": "priority",
			"target": "all_back_row", "damage_mult": 0.4,
		},
		# ── Lv25-50 新増被動 ──
		{
			"level": 25, "passive_id": "hanabi_armor_piercing",
			"name": "徹甲弾", "desc": "無視目標40%DEF; 濺射提升至30%",
			"type": "special",
			"def_ignore_pct": 40, "splash_damage_pct": 30,
		},
		{
			"level": 30, "passive_id": "hanabi_carpet_bomb",
			"name": "絨毯爆撃", "desc": "先制階段攻撃全敵(ATK×0.3); 附帯灼焼",
			"type": "priority",
			"target": "all_enemies", "damage_mult": 0.3, "apply_burn": true,
		},
		{
			"level": 35, "passive_id": "hanabi_explosive_chain",
			"name": "連鎖爆発", "desc": "灼焼中敵人受傷+25%; 撃殺時爆発傷害波及周囲",
			"type": "special",
			"burn_damage_bonus_pct": 25, "kill_explosion": true,
		},
		{
			"level": 40, "passive_id": "hanabi_siege_master",
			"name": "攻城達人", "desc": "対建築傷害+60%; ATK+4対城防戦",
			"type": "special",
			"siege_damage_bonus_pct": 60, "siege_atk_bonus": 4,
		},
		{
			"level": 45, "passive_id": "hanabi_napalm",
			"name": "業火弾", "desc": "灼焼DoT提升至ATK×0.5; 無法驅散; 無視50%DEF",
			"type": "on_hit",
			"dot_atk_mult": 0.5, "dot_undispellable": true, "def_ignore_pct": 50,
		},
		{
			"level": 50, "passive_id": "hanabi_fire_goddess",
			"name": "花火之神", "desc": "全軍ATK+5; 先制AoE全敵(ATK×0.6); 濺射40%; 灼焼5回合",
			"type": "special",
			"aura_atk": 5, "priority_aoe_mult": 0.6,
			"splash_damage_pct": 40, "dot_rounds": 5,
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
	@warning_ignore("integer_division")
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
