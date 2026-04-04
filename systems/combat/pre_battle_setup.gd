## pre_battle_setup.gd — 战前布阵阶段与军师付与系统 (v5.0)
##
## 实现《战国兰斯07》"付与"机制的精神：高INT英雄在战斗开始前为全军施加
## 强力的战术付与（Pre-Battle Enchantments），将智将的战略价值从单纯的
## 法术伤害中解放出来。
##
## 付与规则（对照SR07）：
##   - INT 1-3：无付与
##   - INT 4-5：施放1个付与
##   - INT 6-7：施放2个付与
##   - INT 8-9：施放3个付与（最高级军师）
##   - 付与效果不可被普通Debuff驱散（战术级别）
##   - 同一效果不叠加，高INT覆盖低INT
##
## 集成方式：在 combat_resolver.gd 的 resolve_combat() 中，
## Formation Bonuses 之后调用 PreBattleSetup.apply(state, combat_log)
##
extends Node

# ---------------------------------------------------------------------------
# 付与效果定义表（SR07风格）
# ---------------------------------------------------------------------------
## 每个付与效果包含：id, name, desc, effect_type, value, duration(-1=永久)
const ENCHANTMENT_POOL: Array = [
	# ── 攻击型付与 ──
	{
		"id": "tactical_fury",
		"name": "战意高昂",
		"desc": "全军ATK+20%（战前布阵）",
		"effect_type": "atk_pct",
		"value": 0.20,
		"duration": -1,
		"tier": 1,
	},
	{
		"id": "first_strike_enchant",
		"name": "先手之利",
		"desc": "全军首回合ATK+40%（战前布阵）",
		"effect_type": "atk_pct_round1",
		"value": 0.40,
		"duration": 1,
		"tier": 2,
	},
	{
		"id": "pierce_armor",
		"name": "破甲之术",
		"desc": "全军攻击无视敌方DEF的30%（战前布阵）",
		"effect_type": "armor_pierce_pct",
		"value": 0.30,
		"duration": -1,
		"tier": 2,
	},
	# ── 防御型付与 ──
	{
		"id": "iron_will",
		"name": "铁壁意志",
		"desc": "全军DEF+25%（战前布阵）",
		"effect_type": "def_pct",
		"value": 0.25,
		"duration": -1,
		"tier": 1,
	},
	{
		"id": "last_stand",
		"name": "背水一战",
		"desc": "全军HP<30%时ATK+50%（战前布阵）",
		"effect_type": "low_hp_atk_bonus",
		"value": 0.50,
		"duration": -1,
		"tier": 2,
	},
	{
		"id": "absolute_guard",
		"name": "绝对防御",
		"desc": "全军第一次受到致命伤害时以1兵存活（战前布阵）",
		"effect_type": "one_time_survive",
		"value": 1.0,
		"duration": -1,
		"tier": 3,
	},
	# ── 速度/控制型付与 ──
	{
		"id": "swift_march",
		"name": "疾行之令",
		"desc": "全军SPD+3（战前布阵）",
		"effect_type": "spd_flat",
		"value": 3.0,
		"duration": -1,
		"tier": 1,
	},
	{
		"id": "tactical_chaos",
		"name": "扰乱阵型",
		"desc": "敌方全军SPD-3（战前布阵）",
		"effect_type": "enemy_spd_debuff",
		"value": -3.0,
		"duration": -1,
		"tier": 3,
	},
	# ── 特殊型付与 ──
	{
		"id": "morale_surge",
		"name": "士气激励",
		"desc": "全军初始士气+30（战前布阵）",
		"effect_type": "morale_bonus",
		"value": 30.0,
		"duration": -1,
		"tier": 1,
	},
	{
		"id": "death_defiance",
		"name": "不死之志",
		"desc": "全军溃逃阈值降至-30（战前布阵）",
		"effect_type": "rout_threshold_bonus",
		"value": -30.0,
		"duration": -1,
		"tier": 2,
	},
]

# ---------------------------------------------------------------------------
# 付与数量表（INT → 付与数）
# ---------------------------------------------------------------------------
const INT_TO_ENCHANT_COUNT: Dictionary = {
	0: 0, 1: 0, 2: 0, 3: 0,
	4: 1, 5: 1,
	6: 2, 7: 2,
	8: 3, 9: 3,
}

# ---------------------------------------------------------------------------
# 公共接口：在战斗开始前调用
# ---------------------------------------------------------------------------
## 扫描双方所有英雄的INT属性，为各自部队施加战前付与。
## state: 由 combat_resolver._build_battle_state() 生成的战斗状态字典
## combat_log: 战斗日志数组，用于记录付与信息
func apply(state: Dictionary, combat_log: Array) -> void:
	# 进攻方
	var atk_enchants: Array = _collect_enchantments(state["atk_units"])
	if not atk_enchants.is_empty():
		_apply_enchantments_to_side(state["atk_units"], state["def_units"], atk_enchants, combat_log, "攻方")

	# 防守方
	var def_enchants: Array = _collect_enchantments(state["def_units"])
	if not def_enchants.is_empty():
		_apply_enchantments_to_side(state["def_units"], state["atk_units"], def_enchants, combat_log, "守方")

# ---------------------------------------------------------------------------
# 内部：收集该方所有英雄的付与
# ---------------------------------------------------------------------------
func _collect_enchantments(units: Array) -> Array:
	var best_int: int = 0
	var best_hero_id: String = ""

	# 找到INT最高的英雄（SR07规则：高INT军师付与覆盖低INT）
	for unit in units:
		var hero_id: String = unit.get("hero_id", "")
		if hero_id.is_empty():
			continue
		var int_stat: int = int(unit.get("int_stat", 0))
		if int_stat > best_int:
			best_int = int_stat
			best_hero_id = hero_id

	if best_int < 4:
		return []  # INT不足，无付与

	var count: int = INT_TO_ENCHANT_COUNT.get(mini(best_int, 9), 0)
	if count <= 0:
		return []

	# 根据INT等级选择付与池
	var available: Array = []
	if best_int >= 8:
		available = ENCHANTMENT_POOL.duplicate()  # 全部可选
	elif best_int >= 6:
		available = ENCHANTMENT_POOL.filter(func(e): return e["tier"] <= 2)
	else:
		available = ENCHANTMENT_POOL.filter(func(e): return e["tier"] <= 1)

	# 随机选取（不重复）
	available.shuffle()
	var selected: Array = []
	for i in range(mini(count, available.size())):
		selected.append(available[i])

	return selected

# ---------------------------------------------------------------------------
# 内部：将付与效果应用到该方所有单位
# ---------------------------------------------------------------------------
func _apply_enchantments_to_side(
	friendly_units: Array,
	enemy_units: Array,
	enchants: Array,
	combat_log: Array,
	side_label: String
) -> void:
	var names: Array = []
	for enchant in enchants:
		names.append(enchant["name"])
		var etype: String = enchant["effect_type"]
		var val: float = float(enchant["value"])

		match etype:
			"atk_pct":
				for u in friendly_units:
					if u.get("is_alive", false):
						u["atk"] *= (1.0 + val)
			"atk_pct_round1":
				# 标记为buff，由combat_resolver在第1回合开始时应用
				for u in friendly_units:
					if u.get("is_alive", false):
						u["buffs"].append({
							"id": "pre_battle_atk_r1",
							"value": val,
							"duration": 1,
						})
			"armor_pierce_pct":
				# 标记为passive，在_calculate_damage中读取
				for u in friendly_units:
					if u.get("is_alive", false):
						if "armor_pierce" not in u["passives"]:
							u["passives"].append("armor_pierce")
						u["armor_pierce_pct"] = val
			"def_pct":
				for u in friendly_units:
					if u.get("is_alive", false):
						u["def"] *= (1.0 + val)
			"low_hp_atk_bonus":
				for u in friendly_units:
					if u.get("is_alive", false):
						if "low_hp_double" not in u["passives"]:
							u["passives"].append("low_hp_double")
						u["low_hp_atk_bonus"] = val
			"one_time_survive":
				for u in friendly_units:
					if u.get("is_alive", false):
						if "one_time_survive" not in u["passives"]:
							u["passives"].append("one_time_survive")
			"spd_flat":
				for u in friendly_units:
					if u.get("is_alive", false):
						u["spd"] = maxf(u["spd"] + val, 1.0)
			"enemy_spd_debuff":
				for u in enemy_units:
					if u.get("is_alive", false):
						u["spd"] = maxf(u["spd"] + val, 1.0)  # val is negative
			"morale_bonus":
				for u in friendly_units:
					if u.get("is_alive", false):
						u["morale"] = u.get("morale", 100) + int(val)
			"rout_threshold_bonus":
				# 标记在unit上，由morale检查时读取
				for u in friendly_units:
					if u.get("is_alive", false):
						u["rout_threshold_bonus"] = int(val)

	if not names.is_empty():
		combat_log.append("[战前付与] %s军师施放: %s" % [side_label, ", ".join(names)])

# ---------------------------------------------------------------------------
# 辅助：在_calculate_damage中读取armor_pierce_pct（供combat_resolver调用）
# ---------------------------------------------------------------------------
## 返回攻击方单位的破甲百分比（0.0 = 无破甲）
static func get_armor_pierce_pct(attacker_unit: Dictionary) -> float:
	if "armor_pierce" in attacker_unit.get("passives", []):
		return float(attacker_unit.get("armor_pierce_pct", 0.0))
	return 0.0
