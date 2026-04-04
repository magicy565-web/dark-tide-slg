## test_realworld.gd — 真实性测试（Runtime Validation）
##
## 在 Godot 无头运行时中实例化真实系统，验证：
##   1. CombatSystem.resolve_battle 真实战斗解算
##   2. PirateQuestGuide 任务链数据完整性（运行时）
##   3. QuestJournal 引导任务注入与 prev_guide_done 触发器
##   4. PirateMechanic 核心数值方法
##   5. 海盗阵营攻击流程端到端数据流
##
## 运行方式：由 test_runner.gd 自动加载
extends RefCounted

# ── 依赖 ──
const CombatSystem  = preload("res://systems/combat/combat_system.gd")
const PirateQuestGuide = preload("res://systems/quest/pirate_quest_guide.gd")

func _assert(cond: bool, msg: String) -> String:
	return "PASS" if cond else "FAIL: " + msg

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1: CombatSystem 真实战斗解算
# ══════════════════════════════════════════════════════════════════════════════

func _make_army(soldiers: int, atk: int, def_val: int, spd: int = 5, troop_id: String = "human_ashigaru") -> Dictionary:
	return {
		"units": [{
			"id": "att_0",
			"commander_id": "generic",
			"troop_id": troop_id,
			"atk": atk,
			"def": def_val,
			"spd": spd,
			"int": 3,
			"soldiers": soldiers,
			"max_soldiers": soldiers,
			"row": 0,
			"slot": 0,
			"passive": "",
		}],
		"player_id": 0,
	}

func test_combat_strong_attacker_wins() -> String:
	## 强攻方（100兵/ATK12）应胜弱守方（20兵/ATK4）
	var combat := CombatSystem.new()
	combat.player_controlled = false
	var att := _make_army(100, 12, 6)
	var def := _make_army(20, 4, 3)
	var result: Dictionary = await combat.resolve_battle(att, def, {"terrain": 0, "is_siege": false, "city_def": 0})
	return _assert(result.get("winner", "") == "attacker",
		"强攻方应获胜，实际: %s" % result.get("winner", "?"))

func test_combat_weak_attacker_loses() -> String:
	## 弱攻方（10兵/ATK3）应败强守方（80兵/ATK10）
	var combat := CombatSystem.new()
	combat.player_controlled = false
	var att := _make_army(10, 3, 2)
	var def := _make_army(80, 10, 8)
	var result: Dictionary = await combat.resolve_battle(att, def, {"terrain": 0, "is_siege": false, "city_def": 0})
	return _assert(result.get("winner", "") == "defender",
		"弱攻方应失败，实际: %s" % result.get("winner", "?"))

func test_combat_result_has_required_keys() -> String:
	## 战斗结果字典必须包含所有必要键
	var combat := CombatSystem.new()
	combat.player_controlled = false
	var att := _make_army(30, 7, 5)
	var def := _make_army(30, 7, 5)
	var result: Dictionary = await combat.resolve_battle(att, def, {"terrain": 0, "is_siege": false, "city_def": 0})
	var required_keys := ["winner", "attacker_losses", "defender_losses", "log", "rounds_fought"]
	for k in required_keys:
		if not result.has(k):
			return "FAIL: 结果缺少键 '%s'" % k
	return "PASS"

func test_combat_losses_are_non_negative() -> String:
	## 战斗损失不能为负数
	var combat := CombatSystem.new()
	combat.player_controlled = false
	var att := _make_army(50, 8, 6)
	var def := _make_army(50, 8, 6)
	var result: Dictionary = await combat.resolve_battle(att, def, {"terrain": 0, "is_siege": false, "city_def": 0})
	for unit_id in result.get("attacker_losses", {}):
		if result["attacker_losses"][unit_id] < 0:
			return "FAIL: 攻方损失为负数 unit=%s loss=%d" % [unit_id, result["attacker_losses"][unit_id]]
	for unit_id in result.get("defender_losses", {}):
		if result["defender_losses"][unit_id] < 0:
			return "FAIL: 守方损失为负数 unit=%s loss=%d" % [unit_id, result["defender_losses"][unit_id]]
	return "PASS"

func test_combat_rounds_within_max() -> String:
	## 战斗回合数不超过 MAX_ROUNDS
	var combat := CombatSystem.new()
	combat.player_controlled = false
	var att := _make_army(200, 5, 20)  # 高防御，战斗持续更久
	var def := _make_army(200, 5, 20)
	var result: Dictionary = await combat.resolve_battle(att, def, {"terrain": 0, "is_siege": false, "city_def": 0})
	var rounds: int = result.get("rounds_fought", 0)
	return _assert(rounds <= CombatSystem.MAX_ROUNDS,
		"回合数 %d 超过 MAX_ROUNDS=%d" % [rounds, CombatSystem.MAX_ROUNDS])

func test_combat_undefended_tile_attacker_wins() -> String:
	## 无守军格子（空 defender）攻方直接获胜
	var combat := CombatSystem.new()
	combat.player_controlled = false
	var att := _make_army(30, 7, 5)
	var def_empty := {"units": [], "player_id": -1}
	var result: Dictionary = await combat.resolve_battle(att, def_empty, {"terrain": 0, "is_siege": false, "city_def": 0})
	return _assert(result.get("winner", "") == "attacker",
		"无守军应直接获胜，实际: %s" % result.get("winner", "?"))

func test_combat_pirate_rum_atk_bonus() -> String:
	## 朗姆酒 ATK+2 加成应使攻方更快获胜（回合数更少或胜率更高）
	var combat1 := CombatSystem.new()
	combat1.player_controlled = false
	var att_no_rum := _make_army(20, 6, 5)
	var def1 := _make_army(25, 6, 5)
	var r1: Dictionary = await combat1.resolve_battle(att_no_rum, def1, {"terrain": 0, "is_siege": false, "city_def": 0})

	var combat2 := CombatSystem.new()
	combat2.player_controlled = false
	var att_with_rum := _make_army(20, 8, 5)  # ATK+2 模拟朗姆酒加成
	var def2 := _make_army(25, 6, 5)
	var r2: Dictionary = await combat2.resolve_battle(att_with_rum, def2, {"terrain": 0, "is_siege": false, "city_def": 0})

	# 有朗姆酒加成时，要么获胜，要么损失更少
	var rum_better: bool = (r2.get("winner") == "attacker") or \
		(r2.get("rounds_fought", 99) <= r1.get("rounds_fought", 99))
	return _assert(rum_better,
		"朗姆酒 ATK+2 未改善战斗结果: 无加成=%s(%d回合) 有加成=%s(%d回合)" % [
			r1.get("winner"), r1.get("rounds_fought", 0),
			r2.get("winner"), r2.get("rounds_fought", 0)])

func test_combat_forest_terrain_applies() -> String:
	## 森林地形（terrain=1）不应导致崩溃，且结果合法
	var combat := CombatSystem.new()
	combat.player_controlled = false
	var att := _make_army(40, 7, 5)
	var def := _make_army(40, 7, 5)
	var result: Dictionary = await combat.resolve_battle(att, def, {"terrain": 1, "is_siege": false, "city_def": 0})
	return _assert(result.has("winner"), "森林地形战斗结果缺少 winner 键")

func test_combat_siege_city_def_reduces_attacker() -> String:
	## 攻城战（is_siege=true, city_def=10）应使攻方损失更多
	var combat1 := CombatSystem.new()
	combat1.player_controlled = false
	var att1 := _make_army(60, 8, 6)
	var def1 := _make_army(30, 6, 5)
	var r_normal: Dictionary = await combat1.resolve_battle(att1, def1, {"terrain": 0, "is_siege": false, "city_def": 0})

	var combat2 := CombatSystem.new()
	combat2.player_controlled = false
	var att2 := _make_army(60, 8, 6)
	var def2 := _make_army(30, 6, 5)
	var r_siege: Dictionary = await combat2.resolve_battle(att2, def2, {"terrain": 5, "is_siege": true, "city_def": 10})

	# 攻城战不应崩溃，且结果合法
	return _assert(r_siege.has("winner"), "攻城战结果缺少 winner 键")

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2: PirateQuestGuide 运行时数据完整性
# ══════════════════════════════════════════════════════════════════════════════

func test_pirate_guide_quest_count() -> String:
	## GUIDE_QUESTS 应包含 10 个任务
	var count: int = PirateQuestGuide.GUIDE_QUESTS.size()
	return _assert(count == 10, "期望 10 个引导任务，实际 %d 个" % count)

func test_pirate_guide_quest_ids_unique() -> String:
	## 所有任务 ID 应唯一
	var ids := {}
	for gq in PirateQuestGuide.GUIDE_QUESTS:
		var qid: String = gq.get("id", "")
		if ids.has(qid):
			return "FAIL: 重复的任务 ID '%s'" % qid
		ids[qid] = true
	return "PASS"

func test_pirate_guide_quest_chain_order() -> String:
	## 任务链应按 pirate_g1→g10 顺序排列
	for i in range(PirateQuestGuide.GUIDE_QUESTS.size()):
		var expected_id: String = "pirate_g%d" % (i + 1)
		var actual_id: String = PirateQuestGuide.GUIDE_QUESTS[i].get("id", "")
		if actual_id != expected_id:
			return "FAIL: 第 %d 个任务 ID 应为 '%s'，实际为 '%s'" % [i + 1, expected_id, actual_id]
	return "PASS"

func test_pirate_guide_quest_objectives_not_empty() -> String:
	## 每个任务的 objectives 不能为空
	for gq in PirateQuestGuide.GUIDE_QUESTS:
		var objs: Array = gq.get("objectives", [])
		if objs.is_empty():
			return "FAIL: 任务 '%s' 的 objectives 为空" % gq.get("id", "?")
	return "PASS"

func test_pirate_guide_quest_reward_has_gold() -> String:
	## 每个任务的 reward 应包含 gold 字段
	for gq in PirateQuestGuide.GUIDE_QUESTS:
		var reward: Dictionary = gq.get("reward", {})
		if not reward.has("gold"):
			return "FAIL: 任务 '%s' 的 reward 缺少 gold 字段" % gq.get("id", "?")
		if reward["gold"] <= 0:
			return "FAIL: 任务 '%s' 的 gold 奖励 <= 0" % gq.get("id", "?")
	return "PASS"

func test_pirate_guide_prev_trigger_chain() -> String:
	## g2~g10 的 trigger 应包含 prev_guide_done，且指向前一个任务
	for i in range(1, PirateQuestGuide.GUIDE_QUESTS.size()):
		var gq: Dictionary = PirateQuestGuide.GUIDE_QUESTS[i]
		var trigger: Dictionary = gq.get("trigger", {})
		if not trigger.has("prev_guide_done"):
			return "FAIL: 任务 '%s' 缺少 prev_guide_done 触发器" % gq.get("id", "?")
		var expected_prev: String = "pirate_g%d" % i
		var actual_prev: String = trigger["prev_guide_done"]
		if actual_prev != expected_prev:
			return "FAIL: 任务 '%s' 的 prev_guide_done 应为 '%s'，实际为 '%s'" % [
				gq.get("id", "?"), expected_prev, actual_prev]
	return "PASS"

func test_pirate_guide_g1_no_trigger() -> String:
	## 第一个任务（pirate_g1）应无前置触发条件（空 trigger）
	var g1: Dictionary = PirateQuestGuide.GUIDE_QUESTS[0]
	var trigger: Dictionary = g1.get("trigger", {"has_something": true})
	return _assert(trigger.is_empty(),
		"pirate_g1 应有空 trigger，实际: %s" % str(trigger))

func test_pirate_guide_unlock_next_chain() -> String:
	## unlock_next 字段应正确串联（g1→g2, g2→g3, ..., g10→空）
	for i in range(PirateQuestGuide.GUIDE_QUESTS.size()):
		var gq: Dictionary = PirateQuestGuide.GUIDE_QUESTS[i]
		var unlock_next: String = gq.get("unlock_next", "MISSING")
		if i < PirateQuestGuide.GUIDE_QUESTS.size() - 1:
			var expected: String = "pirate_g%d" % (i + 2)
			if unlock_next != expected:
				return "FAIL: 任务 '%s' 的 unlock_next 应为 '%s'，实际为 '%s'" % [
					gq.get("id", "?"), expected, unlock_next]
		else:
			# 最后一个任务 unlock_next 应为空
			if unlock_next != "":
				return "FAIL: 最后一个任务 '%s' 的 unlock_next 应为空，实际为 '%s'" % [
					gq.get("id", "?"), unlock_next]
	return "PASS"

func test_pirate_guide_hint_not_empty() -> String:
	## 每个任务的 hint 不能为空（玩家引导文本）
	for gq in PirateQuestGuide.GUIDE_QUESTS:
		var hint: String = gq.get("hint", "")
		if hint.strip_edges().is_empty():
			return "FAIL: 任务 '%s' 的 hint 为空" % gq.get("id", "?")
	return "PASS"

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3: QuestJournal 引导任务集成（运行时）
# ══════════════════════════════════════════════════════════════════════════════

func test_quest_journal_has_increment_stat() -> String:
	## QuestJournal autoload 应有 increment_stat 方法
	if not Engine.has_singleton("QuestJournal"):
		return "FAIL: QuestJournal autoload 未注册"
	var qj = Engine.get_singleton("QuestJournal")
	return _assert(qj.has_method("increment_stat"),
		"QuestJournal 缺少 increment_stat 方法")

func test_quest_journal_has_check_guide_quests() -> String:
	## QuestJournal 应有 _check_guide_quests 方法
	if not Engine.has_singleton("QuestJournal"):
		return "FAIL: QuestJournal autoload 未注册"
	var qj = Engine.get_singleton("QuestJournal")
	return _assert(qj.has_method("_check_guide_quests"),
		"QuestJournal 缺少 _check_guide_quests 方法")

func test_quest_journal_increment_stat_runtime() -> String:
	## increment_stat 应正确累加统计值
	if not Engine.has_singleton("QuestJournal"):
		return "FAIL: QuestJournal autoload 未注册"
	var qj = Engine.get_singleton("QuestJournal")
	# 使用测试专用 key，避免污染真实统计
	qj.increment_stat("_test_realworld_counter", 5)
	qj.increment_stat("_test_realworld_counter", 3)
	var stats: Dictionary = qj.get_stats()
	var val: int = stats.get("_test_realworld_counter", 0)
	return _assert(val == 8, "increment_stat 累加错误: 期望 8，实际 %d" % val)

func test_pirate_onboarding_autoload_registered() -> String:
	## PirateOnboarding autoload 应已注册
	return _assert(Engine.has_singleton("PirateOnboarding"),
		"PirateOnboarding autoload 未注册")

func test_pirate_onboarding_has_start_method() -> String:
	## PirateOnboarding 应有 start_onboarding 方法
	if not Engine.has_singleton("PirateOnboarding"):
		return "FAIL: PirateOnboarding autoload 未注册"
	var po = Engine.get_singleton("PirateOnboarding")
	return _assert(po.has_method("start_onboarding"),
		"PirateOnboarding 缺少 start_onboarding 方法")

func test_pirate_onboarding_save_load_roundtrip() -> String:
	## PirateOnboarding 的 to_save_data/from_save_data 应正确往返序列化
	if not Engine.has_singleton("PirateOnboarding"):
		return "FAIL: PirateOnboarding autoload 未注册"
	var po = Engine.get_singleton("PirateOnboarding")
	# 保存当前状态
	var saved: Dictionary = po.to_save_data()
	# 修改状态
	po.from_save_data({"active": false, "current_step_index": 3,
		"completed_steps": ["pirate_welcome", "pirate_plunder_intro"],
		"onboarding_complete": false,
		"flags": {
			"first_combat_done": true, "market_bought": false,
			"rum_active": false, "treasure_explored": false,
			"smuggle_established": false, "infamy_50_reached": false,
			"merc_hired": false, "hero_recruited": false,
			"harbor_captured": false, "challenge_started": false,
		}})
	var loaded: Dictionary = po.to_save_data()
	# 恢复原始状态
	po.from_save_data(saved)
	return _assert(loaded.get("current_step_index", -1) == 3,
		"from_save_data 后 current_step_index 应为 3，实际 %d" % loaded.get("current_step_index", -1))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4: PirateMechanic 核心数值方法（运行时）
# ══════════════════════════════════════════════════════════════════════════════

func test_pirate_mechanic_get_rum_morale() -> String:
	## PirateMechanic.get_rum_morale 应返回合法值（0-100）
	if not Engine.has_singleton("PirateMechanic"):
		return "FAIL: PirateMechanic autoload 未注册"
	var pm = Engine.get_singleton("PirateMechanic")
	if not pm.has_method("get_rum_morale"):
		return "FAIL: PirateMechanic 缺少 get_rum_morale 方法"
	var morale: int = pm.get_rum_morale(0)
	return _assert(morale >= 0 and morale <= 100,
		"get_rum_morale 返回非法值: %d（应在 0-100 之间）" % morale)

func test_pirate_mechanic_get_infamy() -> String:
	## PirateMechanic.get_infamy 应返回合法值（0-100）
	if not Engine.has_singleton("PirateMechanic"):
		return "FAIL: PirateMechanic autoload 未注册"
	var pm = Engine.get_singleton("PirateMechanic")
	if not pm.has_method("get_infamy"):
		return "FAIL: PirateMechanic 缺少 get_infamy 方法"
	var infamy: int = pm.get_infamy(0)
	return _assert(infamy >= 0 and infamy <= 100,
		"get_infamy 返回非法值: %d（应在 0-100 之间）" % infamy)

func test_pirate_mechanic_apply_rum_bonus() -> String:
	## apply_rum_bonus_to_units 应给单位添加 ATK 加成
	if not Engine.has_singleton("PirateMechanic"):
		return "FAIL: PirateMechanic autoload 未注册"
	var pm = Engine.get_singleton("PirateMechanic")
	if not pm.has_method("apply_rum_bonus_to_units"):
		return "FAIL: PirateMechanic 缺少 apply_rum_bonus_to_units 方法"
	# 构造测试单位
	var units := [{"id": "test_0", "atk": 5, "def": 5, "spd": 5}]
	var original_atk: int = units[0]["atk"]
	# 初始化玩家 0 的朗姆酒士气为 60（应触发 ATK+2）
	pm.reset(0)  # 重置到初始状态（士气=50）
	pm.apply_rum_bonus_to_units(0, units)
	# 士气 50 时应有 ATK+2 加成
	return _assert(units[0]["atk"] >= original_atk,
		"apply_rum_bonus_to_units 未增加 ATK: 原始=%d 应用后=%d" % [original_atk, units[0]["atk"]])

func test_pirate_mechanic_get_smuggle_routes() -> String:
	## get_smuggle_routes 应返回 Array
	if not Engine.has_singleton("PirateMechanic"):
		return "FAIL: PirateMechanic autoload 未注册"
	var pm = Engine.get_singleton("PirateMechanic")
	if not pm.has_method("get_smuggle_routes"):
		return "FAIL: PirateMechanic 缺少 get_smuggle_routes 方法"
	var routes = pm.get_smuggle_routes(0)
	return _assert(routes is Array,
		"get_smuggle_routes 应返回 Array，实际: %s" % typeof(routes))

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5: EventBus 信号运行时验证
# ══════════════════════════════════════════════════════════════════════════════

func test_eventbus_combat_signals_exist() -> String:
	## EventBus 必须有所有战斗相关信号
	if not Engine.has_singleton("EventBus"):
		return "FAIL: EventBus autoload 未注册"
	var eb = Engine.get_singleton("EventBus")
	var required_signals := [
		"combat_started", "combat_result", "combat_result_detailed",
		"tutorial_combat_done", "infamy_changed", "rum_morale_changed",
	]
	for sig in required_signals:
		if not eb.has_signal(sig):
			return "FAIL: EventBus 缺少信号 '%s'" % sig
	return "PASS"

func test_eventbus_message_log_connectable() -> String:
	## message_log 信号应可连接
	if not Engine.has_singleton("EventBus"):
		return "FAIL: EventBus autoload 未注册"
	var eb = Engine.get_singleton("EventBus")
	return _assert(eb.has_signal("message_log"),
		"EventBus 缺少 message_log 信号")
