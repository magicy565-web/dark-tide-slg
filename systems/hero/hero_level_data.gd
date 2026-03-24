## 暗潮 Dark Tide SLG — 英雄等级静态数据
## 纯常量文件，不含任何运行时状态。
class_name HeroLevelData
extends RefCounted

# =============================================================================
#  1. 经验值表 (累计经验, Lv1-20)
# =============================================================================

const MAX_LEVEL: int = 20

## 索引 0 = Lv1 所需累计经验(0), 索引 19 = Lv20
const EXP_TABLE: Array[int] = [
	0, 15, 35, 60, 90, 125, 165, 210, 260, 315,
	380, 455, 540, 635, 740, 860, 995, 1145, 1310, 1500,
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
#  5. 被动技能解锁树 (每个英雄4个被动, 分别在 Lv3 / 7 / 12 / 18 解锁)
# =============================================================================

const PASSIVE_UNLOCK_TREE: Dictionary = {
	# ── 凛 ──────────────────────────────────────────────
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
	],

	# ── 雪乃 ────────────────────────────────────────────
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
	],

	# ── 红叶 ────────────────────────────────────────────
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
	],

	# ── 冰华 ────────────────────────────────────────────
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
	],

	# ── 翠玲 ────────────────────────────────────────────
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
	],

	# ── 月华 ────────────────────────────────────────────
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
	],

	# ── 叶隐 ────────────────────────────────────────────
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
	],

	# ── 蒼 ──────────────────────────────────────────────
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
	],

	# ── 紫苑 ────────────────────────────────────────────
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
	],

	# ── 焔 ──────────────────────────────────────────────
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
	],
}

# =============================================================================
#  6. 静态辅助函数
# =============================================================================


## 返回指定等级所需的累计经验值
static func get_exp_for_level(level: int) -> int:
	var clamped: int = clampi(level, 1, MAX_LEVEL)
	return EXP_TABLE[clamped - 1]


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
	assert(HERO_BASE_STATS.has(hero_id), "未知的英雄ID: " + hero_id)
	assert(GROWTH_RATES.has(hero_id), "缺少成长率数据: " + hero_id)

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
