## ============================================================================
## hero_leveling.gd — 英雄升级系统（运行时自动加载单例）
## 管理英雄经验值、等级、属性缓存、被动技能解锁及战斗中的HP/MP状态
## ============================================================================
extends Node

# --------------------------------------------------------------------------- #
# 依赖项
# --------------------------------------------------------------------------- #
const HeroLevelData = preload("res://systems/hero/hero_level_data.gd")

# --------------------------------------------------------------------------- #
# 常量
# --------------------------------------------------------------------------- #
const MAX_LEVEL: int = 50  # 等级上限从20提升至50

# --------------------------------------------------------------------------- #
# 持久化状态（需要序列化）
# --------------------------------------------------------------------------- #
var hero_exp: Dictionary = {}                # hero_id -> int（累计经验值）
var hero_level: Dictionary = {}              # hero_id -> int（当前等级 1-50）
var hero_unlocked_passives: Dictionary = {}  # hero_id -> Array[String]（已解锁被动ID）

# --------------------------------------------------------------------------- #
# 战斗状态（不序列化，每场战斗重置）
# --------------------------------------------------------------------------- #
var hero_current_hp: Dictionary = {}         # hero_id -> int
var hero_current_mp: Dictionary = {}         # hero_id -> int

# =========================================================================== #
# 初始化
# =========================================================================== #

## 初始化英雄——设置为1级、0经验值。若已存在则跳过。
func init_hero(hero_id: String) -> void:
	if hero_exp.has(hero_id):
		return
	hero_exp[hero_id] = 0
	hero_level[hero_id] = 1
	hero_unlocked_passives[hero_id] = [] as Array[String]
	# 解锁1级自带的被动技能
	_unlock_passives_for_level(hero_id, 1)

# =========================================================================== #
# 经验值与升级
# =========================================================================== #

## 给予英雄经验值，处理升级和被动解锁，返回结果字典。
func grant_hero_exp(hero_id: String, amount: int) -> Dictionary:
	if not hero_exp.has(hero_id):
		init_hero(hero_id)

	var old_level: int = hero_level[hero_id]

	# 经验值上限——不超过满级所需的累计经验值
	var max_exp: int = HeroLevelData.get_cumulative_exp_for_level(MAX_LEVEL)
	hero_exp[hero_id] = mini(hero_exp[hero_id] + amount, max_exp)

	# 发送经验值获得信号
	EventBus.hero_exp_gained.emit(hero_id, amount, hero_exp[hero_id])

	# 检查升级
	var level_result: Dictionary = _check_level_up(hero_id)

	var result: Dictionary = {
		"leveled_up": level_result.leveled_up,
		"old_level": old_level,
		"new_level": hero_level[hero_id],
		"unlocked_passives": level_result.unlocked_passives,
	}
	return result

## 获取英雄当前等级（默认为1）。
func get_hero_level(hero_id: String) -> int:
	return hero_level.get(hero_id, 1)

## 获取英雄当前累计经验值。
func get_hero_exp(hero_id: String) -> int:
	return hero_exp.get(hero_id, 0)

## 获取升级进度信息：当前经验、下一级所需经验、进度百分比。
func get_exp_to_next_level(hero_id: String) -> Dictionary:
	var current_level: int = get_hero_level(hero_id)
	var current_exp: int = get_hero_exp(hero_id)

	if current_level >= MAX_LEVEL:
		var max_exp: int = HeroLevelData.get_cumulative_exp_for_level(MAX_LEVEL)
		return {
			"current": max_exp,
			"needed": max_exp,
			"progress_pct": 100.0,
		}

	var exp_for_current: int = HeroLevelData.get_cumulative_exp_for_level(current_level)
	var exp_for_next: int = HeroLevelData.get_cumulative_exp_for_level(current_level + 1)
	var exp_in_level: int = current_exp - exp_for_current
	# 防止经验值为负（例如累计经验低于当前等级所需时）
	exp_in_level = maxi(0, exp_in_level)
	var exp_needed_in_level: int = exp_for_next - exp_for_current

	var progress: float = 0.0
	if exp_needed_in_level > 0:
		progress = clampf(float(exp_in_level) / float(exp_needed_in_level) * 100.0, 0.0, 100.0)

	return {
		"current": current_exp,
		"needed": exp_for_next,
		"progress_pct": progress,
	}

# =========================================================================== #
# 属性查询
# =========================================================================== #

## 获取英雄在当前等级的全部属性。
func get_hero_stats(hero_id: String) -> Dictionary:
	var level: int = get_hero_level(hero_id)
	var stats: Dictionary = HeroLevelData.get_hero_stats_at_level(hero_id, level)
	stats["level"] = level
	return stats

## 获取英雄最大HP。
func get_hero_max_hp(hero_id: String) -> int:
	var stats: Dictionary = get_hero_stats(hero_id)
	return stats.get("hp", 0)

## 获取英雄最大MP。
func get_hero_max_mp(hero_id: String) -> int:
	var stats: Dictionary = get_hero_stats(hero_id)
	return stats.get("mp", 0)

# =========================================================================== #
# 被动技能
# =========================================================================== #

## 获取英雄当前等级已解锁的被动技能数据列表。
func get_unlocked_passives(hero_id: String) -> Array:
	var level: int = get_hero_level(hero_id)
	return HeroLevelData.get_passives_at_level(hero_id, level)

## 检查英雄是否拥有指定被动技能。
func has_passive(hero_id: String, passive_id: String) -> bool:
	if not hero_unlocked_passives.has(hero_id):
		return false
	return passive_id in hero_unlocked_passives[hero_id]

# =========================================================================== #
# 战斗状态管理
# =========================================================================== #

## 初始化战斗资源池——将HP/MP设为满值。
func init_combat_pools(hero_id: String) -> void:
	hero_current_hp[hero_id] = get_hero_max_hp(hero_id)
	hero_current_mp[hero_id] = get_hero_max_mp(hero_id)

## 对英雄施加伤害，返回剩余HP和是否被击倒。
func apply_hero_damage(hero_id: String, damage: int) -> Dictionary:
	if damage <= 0:
		return {"hp_remaining": hero_current_hp.get(hero_id, 0), "knocked_out": false}
	var current_hp: int = hero_current_hp.get(hero_id, 0)
	current_hp = maxi(current_hp - damage, 0)
	hero_current_hp[hero_id] = current_hp

	return {
		"hp_remaining": current_hp,
		"knocked_out": current_hp <= 0,
	}

## 消耗MP。成功返回true，MP不足返回false。
func spend_hero_mp(hero_id: String, cost: int) -> bool:
	if cost <= 0:
		return true  # Free skill
	var current_mp: int = hero_current_mp.get(hero_id, 0)
	if current_mp < cost:
		return false
	hero_current_mp[hero_id] = current_mp - cost
	return true

## 恢复英雄HP，不超过最大值。
func restore_hero_hp(hero_id: String, amount: int) -> void:
	var max_hp: int = get_hero_max_hp(hero_id)
	var current_hp: int = hero_current_hp.get(hero_id, 0)
	hero_current_hp[hero_id] = mini(current_hp + amount, max_hp)

## 恢复英雄MP，不超过最大值。
func restore_hero_mp(hero_id: String, amount: int) -> void:
	var max_mp: int = get_hero_max_mp(hero_id)
	var current_mp: int = hero_current_mp.get(hero_id, 0)
	hero_current_mp[hero_id] = mini(current_mp + amount, max_mp)

## 判断英雄是否仍然存活（未被击倒）。
func is_hero_active(hero_id: String) -> bool:
	return hero_current_hp.get(hero_id, 0) > 0

# =========================================================================== #
# 序列化与反序列化
# =========================================================================== #

## 保存所有持久化状态。
func serialize() -> Dictionary:
	return {
		"hero_exp": hero_exp.duplicate(true),
		"hero_level": hero_level.duplicate(true),
		"hero_unlocked_passives": hero_unlocked_passives.duplicate(true),
	}

## 加载持久化状态，并校验等级与经验值的一致性。
func deserialize(data: Dictionary) -> void:
	hero_exp = data.get("hero_exp", {}).duplicate(true)
	hero_level = data.get("hero_level", {}).duplicate(true)
	hero_unlocked_passives = data.get("hero_unlocked_passives", {}).duplicate(true)

	# BUG FIX R7: JSON round-trip turns int values to float; cast back to int
	for hero_id in hero_exp.keys():
		hero_exp[hero_id] = int(hero_exp[hero_id])
	for hero_id in hero_level.keys():
		hero_level[hero_id] = int(hero_level[hero_id])

	# 校验：确保等级与累计经验值匹配
	for hero_id in hero_exp.keys():
		var exp_val: int = hero_exp[hero_id]
		var expected_level: int = _calculate_level_from_exp(exp_val)
		# Clamp level to valid range [1, MAX_LEVEL]
		expected_level = clampi(expected_level, 1, MAX_LEVEL)
		if hero_level.get(hero_id, 1) != expected_level:
			push_warning(
				"HeroLeveling: 英雄 %s 等级不匹配，经验值=%d 期望等级=%d 存档等级=%d，已修正。"
				% [hero_id, exp_val, expected_level, hero_level.get(hero_id, 1)]
			)
			hero_level[hero_id] = expected_level

	# 清空战斗状态
	hero_current_hp.clear()
	hero_current_mp.clear()

# =========================================================================== #
# 内部方法
# =========================================================================== #

## 检查升级——处理可能的多次连续升级，发送信号，返回结果。
func _check_level_up(hero_id: String) -> Dictionary:
	var current_level: int = hero_level.get(hero_id, 1)
	var current_exp: int = hero_exp.get(hero_id, 0)
	var leveled_up: bool = false
	var all_unlocked_passives: Array = []

	while current_level < MAX_LEVEL:
		var exp_for_next: int = HeroLevelData.get_cumulative_exp_for_level(current_level + 1)
		if current_exp < exp_for_next:
			break

		# 升级
		current_level += 1
		hero_level[hero_id] = current_level
		leveled_up = true

		# 发送升级信号
		EventBus.hero_leveled_up.emit(hero_id, current_level)

		# 解锁该等级的被动技能
		var new_passives: Array = _unlock_passives_for_level(hero_id, current_level)
		all_unlocked_passives.append_array(new_passives)

	return {
		"leveled_up": leveled_up,
		"unlocked_passives": all_unlocked_passives,
	}

## 解锁指定等级及以下所有尚未解锁的被动技能。
func _unlock_passives_for_level(hero_id: String, level: int) -> Array:
	if not hero_unlocked_passives.has(hero_id):
		hero_unlocked_passives[hero_id] = [] as Array[String]

	var passives_at_level: Array = HeroLevelData.get_passives_at_level(hero_id, level)
	var newly_unlocked: Array = []

	for passive_data in passives_at_level:
		var passive_id: String = passive_data.get("passive_id", passive_data.get("id", ""))
		if passive_id.is_empty():
			continue
		if passive_id in hero_unlocked_passives[hero_id]:
			continue

		hero_unlocked_passives[hero_id].append(passive_id)
		newly_unlocked.append(passive_data)

		# 发送被动技能解锁信号
		EventBus.hero_passive_unlocked.emit(hero_id, passive_id)

	return newly_unlocked

## 根据累计经验值计算应有的等级。
func _calculate_level_from_exp(exp_val: int) -> int:
	var level: int = 1
	while level < MAX_LEVEL:
		var exp_for_next: int = HeroLevelData.get_cumulative_exp_for_level(level + 1)
		if exp_val < exp_for_next:
			break
		level += 1
	return level
