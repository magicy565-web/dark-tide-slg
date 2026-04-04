## test_attack_bugs.gd — 攻击流程 Bug 测试
## 在 test_runner 框架中运行（同步），通过源码分析 + 数据验证检测真实 Bug
## 覆盖：CombatSystem 结构、GameManager 攻击路径、PirateQuestGuide 数据、
##        PirateOnboarding 集成、QuestJournal 引导任务、Autoload 运行时可用性
extends RefCounted

const CombatSystem   = preload("res://systems/combat/combat_system.gd")
const PirateQuestGuide = preload("res://systems/quest/pirate_quest_guide.gd")

func _assert(cond: bool, msg: String) -> String:
	return "PASS" if cond else "FAIL: " + msg

func _src(path: String) -> String:
	var s = load(path)
	return s.source_code if s != null else ""

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1: CombatSystem 源码 Bug 检测
# ══════════════════════════════════════════════════════════════════════════════

func test_combat_player_controlled_flag_exists() -> String:
	## player_controlled=false 时不会触发 await，防止测试/AI战斗阻塞
	var src := _src("res://systems/combat/combat_system.gd")
	return _assert(src.contains("player_controlled"),
		"player_controlled 标志缺失，AI 战斗会因 await 阻塞")

func test_combat_max_rounds_prevents_infinite_loop() -> String:
	## MAX_ROUNDS 必须存在且合理（防止无限循环 Bug）
	var src := _src("res://systems/combat/combat_system.gd")
	var has_max := src.contains("MAX_ROUNDS")
	var val_ok := src.contains("MAX_ROUNDS := 8") or src.contains("MAX_ROUNDS = 8")
	return _assert(has_max and val_ok,
		"MAX_ROUNDS 缺失或值异常（应为 8）")

func test_combat_empty_defender_handled() -> String:
	## 空守方（无兵）应直接返回 attacker 获胜，不进入战斗循环
	var src := _src("res://systems/combat/combat_system.gd")
	return _assert(src.contains("defender_units.is_empty()"),
		"未处理空守方情况，可能导致除零或空数组访问 Bug")

func test_combat_zero_soldiers_guard() -> String:
	## 战斗中应有 soldiers <= 0 的判断，防止负兵力 Bug
	var src := _src("res://systems/combat/combat_system.gd")
	return _assert(src.contains("soldiers") and src.contains("<= 0"),
		"缺少 soldiers <= 0 守卫，可能产生负兵力 Bug")

func test_combat_winner_assigned_on_timeout() -> String:
	## 超时时必须明确赋值 winner = "defender"，不能返回空字符串
	var src := _src("res://systems/combat/combat_system.gd")
	return _assert(src.contains("\"defender\""),
		"超时时未赋值 winner=defender，可能返回空 winner Bug")

func test_combat_losses_dict_initialized() -> String:
	## attacker_losses / defender_losses 字典必须初始化，防止 null 访问 Bug
	var src := _src("res://systems/combat/combat_system.gd")
	return _assert(src.contains("attacker_losses") and src.contains("defender_losses"),
		"损失字典未初始化，可能导致 null 访问 Bug")

func test_combat_no_direct_def_modification() -> String:
	## 防御值不应在战斗循环中被直接修改（应通过 buff 系统）
	## 已知 Bug：iron_wall 曾直接修改 unit["def"]
	var src := _src("res://systems/combat/combat_system.gd")
	var bad_pattern := "unit[\"def\"] += 3\n\t\t\tunit[\"buffs\"].append({\"id\": \"iron_wall\""
	return _assert(not src.contains(bad_pattern),
		"iron_wall 直接修改 unit[def] Bug 未修复")

func test_combat_rounds_fought_in_result() -> String:
	## 结果字典必须包含 rounds_fought，供 UI 和统计使用
	var src := _src("res://systems/combat/combat_system.gd")
	return _assert(src.contains("rounds_fought"),
		"结果缺少 rounds_fought 键，战斗日志无法显示回合数")

func test_combat_log_array_in_result() -> String:
	## 结果字典必须包含 log 数组，供战斗回放使用
	var src := _src("res://systems/combat/combat_system.gd")
	return _assert(src.contains("action_log") or src.contains("\"log\""),
		"结果缺少 log 数组，战斗回放功能失效")

func test_combat_hp_per_soldier_initialized() -> String:
	## hp_per_soldier 必须初始化，防止除零 Bug
	var src := _src("res://systems/combat/combat_system.gd")
	return _assert(src.contains("hp_per_soldier"),
		"hp_per_soldier 未初始化，可能导致除零 Bug")

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2: GameManager 攻击路径 Bug 检测
# ══════════════════════════════════════════════════════════════════════════════

func test_attack_ap_check_before_combat() -> String:
	## 攻击前必须检查 AP >= 1，防止无限攻击 Bug
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("player[\"ap\"] < 1") or src.contains("ap\"] < 1"),
		"攻击前未检查 AP，玩家可无限攻击（AP Bug）")

func test_attack_adjacency_check() -> String:
	## 必须检查目标格子是否相邻，防止跨地图攻击 Bug
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("get_army_attackable_tiles") or src.contains("attackable_tiles"),
		"缺少邻接检查，玩家可攻击任意格子（跨图攻击 Bug）")

func test_attack_ap_consumed_after_combat() -> String:
	## 战斗后必须消耗 1 AP
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("player[\"ap\"] -= 1") or src.contains("ap\"] -= 1"),
		"战斗后未消耗 AP（AP 不扣除 Bug）")

func test_attack_zombie_troops_cleaned() -> String:
	## 战斗后必须清理 soldiers=0 的僵尸部队
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("surviving_troops") or src.contains("_cleanup_army_troops"),
		"战斗后未清理零兵力部队（僵尸部队 Bug）")

func test_attack_garrison_zeroed_on_win() -> String:
	## 攻方获胜后守方 garrison 必须归零
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("tile[\"garrison\"] = 0"),
		"攻方获胜后守方 garrison 未归零（幽灵驻军 Bug）")

func test_attack_wall_hp_zeroed_on_win() -> String:
	## 攻方获胜后城墙 HP 必须归零
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("tile[\"wall_hp\"] = 0"),
		"攻方获胜后 wall_hp 未归零（城墙不倒 Bug）")

func test_attack_capture_tile_called_on_win() -> String:
	## 攻方获胜后必须调用 _capture_tile 转移所有权
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("_capture_tile("),
		"攻方获胜后未调用 _capture_tile（格子所有权不转移 Bug）")

func test_attack_hero_exp_granted() -> String:
	## 战斗后必须给英雄授予经验值
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("_grant_hero_combat_exp"),
		"战斗后未授予英雄经验（英雄不升级 Bug）")

func test_attack_combat_result_signal_emitted() -> String:
	## 战斗结束必须发射 combat_result 信号，供 UI 更新
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("EventBus.combat_result.emit"),
		"战斗结束未发射 combat_result 信号（UI 不更新 Bug）")

func test_attack_detailed_result_signal_emitted() -> String:
	## 必须发射 combat_result_detailed 信号，供战报面板使用
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("EventBus.combat_result_detailed.emit"),
		"缺少 combat_result_detailed 信号（战报面板空白 Bug）")

func test_attack_tutorial_signal_emitted() -> String:
	## 必须发射 tutorial_combat_done 信号，供引导系统感知战斗
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("EventBus.tutorial_combat_done.emit"),
		"缺少 tutorial_combat_done 信号（引导系统无法感知战斗 Bug）")

func test_attack_pirate_rum_applied() -> String:
	## 海盗阵营必须在战斗前应用朗姆酒 ATK 加成
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("PirateMechanic.apply_rum_bonus_to_units"),
		"海盗阵营未应用朗姆酒加成（朗姆酒无效 Bug）")

func test_attack_pirate_harbor_notifies_onboarding() -> String:
	## 海盗占领港口后必须通知 PirateOnboarding
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("notify_harbor_captured"),
		"港口占领后未通知 PirateOnboarding（引导步骤卡住 Bug）")

func test_attack_record_battle_stat_called() -> String:
	## 战斗后必须记录统计（battles_won），供任务日志使用
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("_record_battle_stat"),
		"战斗后未记录统计（任务日志 battles_won 不更新 Bug）")

func test_attack_disband_empty_army() -> String:
	## 全军覆没后必须解散军队，防止空壳军队 Bug
	var src := _src("res://autoloads/game_manager.gd")
	return _assert(src.contains("disband_army"),
		"全军覆没后未解散军队（空壳军队 Bug）")

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3: PirateQuestGuide 运行时数据 Bug 检测
# ══════════════════════════════════════════════════════════════════════════════

func test_guide_quest_count_is_ten() -> String:
	var guide := PirateQuestGuide.new()
	var count := guide.GUIDE_QUESTS.size()
	return _assert(count == 10, "期望 10 个引导任务，实际 %d 个" % count)

func test_guide_quest_ids_sequential() -> String:
	var guide := PirateQuestGuide.new()
	for i in range(guide.GUIDE_QUESTS.size()):
		var expected := "pirate_g%d" % (i + 1)
		var actual: String = guide.GUIDE_QUESTS[i].get("id", "")
		if actual != expected:
			return "FAIL: 第%d个任务ID应为%s，实际%s" % [i+1, expected, actual]
	return "PASS"

func test_guide_quest_ids_unique() -> String:
	var guide := PirateQuestGuide.new()
	var seen := {}
	for gq in guide.GUIDE_QUESTS:
		var qid: String = gq.get("id", "")
		if seen.has(qid):
			return "FAIL: 重复任务ID '%s'" % qid
		seen[qid] = true
	return "PASS"

func test_guide_quest_prev_trigger_chain() -> String:
	var guide := PirateQuestGuide.new()
	for i in range(1, guide.GUIDE_QUESTS.size()):
		var gq: Dictionary = guide.GUIDE_QUESTS[i]
		var trigger: Dictionary = gq.get("trigger", {})
		var expected_prev := "pirate_g%d" % i
		if trigger.get("prev_guide_done", "") != expected_prev:
			return "FAIL: %s 的 prev_guide_done 应为 %s，实际 %s" % [
				gq.get("id","?"), expected_prev, trigger.get("prev_guide_done","?")]
	return "PASS"

func test_guide_quest_g1_no_trigger() -> String:
	var guide := PirateQuestGuide.new()
	var g1: Dictionary = guide.GUIDE_QUESTS[0]
	var trigger: Dictionary = g1.get("trigger", {"x": 1})
	return _assert(trigger.is_empty(),
		"pirate_g1 应无前置触发器，实际: %s" % str(trigger))

func test_guide_quest_objectives_not_empty() -> String:
	var guide := PirateQuestGuide.new()
	for gq in guide.GUIDE_QUESTS:
		var objs: Array = gq.get("objectives", [])
		if objs.is_empty():
			return "FAIL: 任务 %s objectives 为空" % gq.get("id","?")
	return "PASS"

func test_guide_quest_objectives_have_type_and_target() -> String:
	var guide := PirateQuestGuide.new()
	for gq in guide.GUIDE_QUESTS:
		for obj in gq.get("objectives", []):
			if not obj.has("type"):
				return "FAIL: 任务 %s 的 objective 缺少 type 字段" % gq.get("id","?")
			if not obj.has("target"):
				return "FAIL: 任务 %s 的 objective 缺少 target 字段" % gq.get("id","?")
	return "PASS"

func test_guide_quest_rewards_gold_positive() -> String:
	var guide := PirateQuestGuide.new()
	for gq in guide.GUIDE_QUESTS:
		var gold: int = gq.get("reward", {}).get("gold", 0)
		if gold <= 0:
			return "FAIL: 任务 %s gold 奖励 <= 0 (实际: %d)" % [gq.get("id","?"), gold]
	return "PASS"

func test_guide_quest_hints_not_empty() -> String:
	var guide := PirateQuestGuide.new()
	for gq in guide.GUIDE_QUESTS:
		var hint: String = gq.get("hint", "")
		if hint.strip_edges().is_empty():
			return "FAIL: 任务 %s hint 为空（玩家无引导文本）" % gq.get("id","?")
	return "PASS"

func test_guide_quest_unlock_next_chain() -> String:
	var guide := PirateQuestGuide.new()
	for i in range(guide.GUIDE_QUESTS.size()):
		var gq: Dictionary = guide.GUIDE_QUESTS[i]
		var unlock: String = gq.get("unlock_next", "MISSING")
		if i < guide.GUIDE_QUESTS.size() - 1:
			var expected := "pirate_g%d" % (i + 2)
			if unlock != expected:
				return "FAIL: %s 的 unlock_next 应为 %s，实际 %s" % [
					gq.get("id","?"), expected, unlock]
		else:
			if unlock != "":
				return "FAIL: 最后任务 %s 的 unlock_next 应为空，实际 '%s'" % [
					gq.get("id","?"), unlock]
	return "PASS"

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4: QuestJournal 引导任务集成 Bug 检测
# ══════════════════════════════════════════════════════════════════════════════

func test_quest_journal_increment_stat_exists() -> String:
	if not Engine.has_singleton("QuestJournal"):
		return "FAIL: QuestJournal autoload 未注册"
	return _assert(Engine.get_singleton("QuestJournal").has_method("increment_stat"),
		"QuestJournal 缺少 increment_stat（统计无法更新 Bug）")

func test_quest_journal_increment_stat_runtime() -> String:
	if not Engine.has_singleton("QuestJournal"):
		return "FAIL: QuestJournal autoload 未注册"
	var qj = Engine.get_singleton("QuestJournal")
	qj.increment_stat("_bug_test_a", 4)
	qj.increment_stat("_bug_test_a", 6)
	var val: int = qj.get_stats().get("_bug_test_a", -1)
	return _assert(val == 10, "increment_stat 累加错误: 4+6 应=10，实际=%d" % val)

func test_quest_journal_check_guide_quests_exists() -> String:
	if not Engine.has_singleton("QuestJournal"):
		return "FAIL: QuestJournal autoload 未注册"
	return _assert(Engine.get_singleton("QuestJournal").has_method("_check_guide_quests"),
		"QuestJournal 缺少 _check_guide_quests（引导任务不推进 Bug）")

func test_quest_journal_complete_guide_quest_exists() -> String:
	if not Engine.has_singleton("QuestJournal"):
		return "FAIL: QuestJournal autoload 未注册"
	return _assert(Engine.get_singleton("QuestJournal").has_method("_complete_guide_quest"),
		"QuestJournal 缺少 _complete_guide_quest（任务无法完成 Bug）")

func test_quest_journal_get_all_quests_exists() -> String:
	if not Engine.has_singleton("QuestJournal"):
		return "FAIL: QuestJournal autoload 未注册"
	return _assert(Engine.get_singleton("QuestJournal").has_method("get_all_quests"),
		"QuestJournal 缺少 get_all_quests（任务日志空白 Bug）")

func test_quest_journal_guide_progress_in_source() -> String:
	var src := _src("res://systems/quest/quest_journal.gd")
	return _assert(src.contains("_guide_progress"),
		"QuestJournal 缺少 _guide_progress（引导任务无法追踪 Bug）")

func test_quest_journal_prev_guide_done_trigger() -> String:
	var src := _src("res://systems/quest/quest_journal.gd")
	return _assert(src.contains("prev_guide_done"),
		"QuestJournal 缺少 prev_guide_done 触发器支持（任务链断裂 Bug）")

func test_quest_journal_guide_in_save_data() -> String:
	var src := _src("res://systems/quest/quest_journal.gd")
	return _assert(src.contains("guide_progress"),
		"QuestJournal 存档未包含 guide_progress（引导进度不持久化 Bug）")

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5: PirateOnboarding 集成 Bug 检测
# ══════════════════════════════════════════════════════════════════════════════

func test_pirate_onboarding_registered() -> String:
	return _assert(Engine.has_singleton("PirateOnboarding"),
		"PirateOnboarding 未注册为 Autoload（引导系统完全失效 Bug）")

func test_pirate_onboarding_extends_canvas_layer() -> String:
	var src := _src("res://systems/tutorial/pirate_onboarding.gd")
	return _assert(src.begins_with("extends CanvasLayer") or src.contains("extends CanvasLayer"),
		"PirateOnboarding extends Node 而非 CanvasLayer（layer 属性赋值崩溃 Bug）")

func test_pirate_onboarding_start_method() -> String:
	if not Engine.has_singleton("PirateOnboarding"):
		return "FAIL: PirateOnboarding 未注册"
	return _assert(Engine.get_singleton("PirateOnboarding").has_method("start_onboarding"),
		"PirateOnboarding 缺少 start_onboarding（引导无法启动 Bug）")

func test_pirate_onboarding_save_load() -> String:
	if not Engine.has_singleton("PirateOnboarding"):
		return "FAIL: PirateOnboarding 未注册"
	var po = Engine.get_singleton("PirateOnboarding")
	if not po.has_method("to_save_data") or not po.has_method("from_save_data"):
		return "FAIL: 缺少 to_save_data 或 from_save_data（存档不持久化 Bug）"
	var saved: Dictionary = po.to_save_data()
	po.from_save_data({
		"active": false, "current_step_index": 7,
		"completed_steps": [], "onboarding_complete": false,
		"flags": {
			"first_combat_done": true, "market_bought": true,
			"rum_active": true, "treasure_explored": true,
			"smuggle_established": true, "infamy_50_reached": true,
			"merc_hired": false, "hero_recruited": false,
			"harbor_captured": false, "challenge_started": false,
		}
	})
	var loaded: Dictionary = po.to_save_data()
	po.from_save_data(saved)
	return _assert(loaded.get("current_step_index", -1) == 7,
		"存档往返后 current_step_index 错误: 期望7，实际%d" % loaded.get("current_step_index",-1))

func test_pirate_onboarding_notify_methods() -> String:
	if not Engine.has_singleton("PirateOnboarding"):
		return "FAIL: PirateOnboarding 未注册"
	var po = Engine.get_singleton("PirateOnboarding")
	var methods := ["notify_market_item_bought", "notify_treasure_explored",
					"notify_merc_hired", "notify_harbor_captured"]
	for m in methods:
		if not po.has_method(m):
			return "FAIL: 缺少 %s（引导步骤无法推进 Bug）" % m
	return "PASS"

func test_pirate_onboarding_combat_signal_handler() -> String:
	var src := _src("res://systems/tutorial/pirate_onboarding.gd")
	return _assert(src.contains("_on_combat_result"),
		"PirateOnboarding 缺少 _on_combat_result 处理（战斗胜利不推进引导 Bug）")

func test_pirate_onboarding_steps_count() -> String:
	var src := _src("res://systems/tutorial/pirate_onboarding.gd")
	var count := src.split("\"id\": \"pirate_").size() - 1
	return _assert(count >= 11,
		"STEPS 只有 %d 个步骤，期望 >= 11（引导不完整 Bug）" % count)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 6: Autoload 运行时可用性 + EventBus 信号
# ══════════════════════════════════════════════════════════════════════════════

func test_autoload_eventbus() -> String:
	return _assert(Engine.has_singleton("EventBus"), "EventBus 未注册")

func test_autoload_game_manager() -> String:
	return _assert(Engine.has_singleton("GameManager"), "GameManager 未注册")

func test_autoload_pirate_mechanic() -> String:
	return _assert(Engine.has_singleton("PirateMechanic"), "PirateMechanic 未注册")

func test_autoload_hero_system() -> String:
	return _assert(Engine.has_singleton("HeroSystem"), "HeroSystem 未注册")

func test_autoload_save_manager() -> String:
	return _assert(Engine.has_singleton("SaveManager"), "SaveManager 未注册")

func test_eventbus_combat_started_signal() -> String:
	if not Engine.has_singleton("EventBus"): return "FAIL: EventBus 未注册"
	return _assert(Engine.get_singleton("EventBus").has_signal("combat_started"),
		"EventBus 缺少 combat_started 信号")

func test_eventbus_combat_result_signal() -> String:
	if not Engine.has_singleton("EventBus"): return "FAIL: EventBus 未注册"
	return _assert(Engine.get_singleton("EventBus").has_signal("combat_result"),
		"EventBus 缺少 combat_result 信号（UI 无法收到战斗结果 Bug）")

func test_eventbus_combat_result_detailed_signal() -> String:
	if not Engine.has_singleton("EventBus"): return "FAIL: EventBus 未注册"
	return _assert(Engine.get_singleton("EventBus").has_signal("combat_result_detailed"),
		"EventBus 缺少 combat_result_detailed 信号（战报面板失效 Bug）")

func test_eventbus_tutorial_combat_done_signal() -> String:
	if not Engine.has_singleton("EventBus"): return "FAIL: EventBus 未注册"
	return _assert(Engine.get_singleton("EventBus").has_signal("tutorial_combat_done"),
		"EventBus 缺少 tutorial_combat_done 信号（引导感知战斗失效 Bug）")

func test_eventbus_infamy_changed_signal() -> String:
	if not Engine.has_singleton("EventBus"): return "FAIL: EventBus 未注册"
	return _assert(Engine.get_singleton("EventBus").has_signal("infamy_changed"),
		"EventBus 缺少 infamy_changed 信号（恶名引导步骤失效 Bug）")

func test_eventbus_rum_morale_changed_signal() -> String:
	if not Engine.has_singleton("EventBus"): return "FAIL: EventBus 未注册"
	return _assert(Engine.get_singleton("EventBus").has_signal("rum_morale_changed"),
		"EventBus 缺少 rum_morale_changed 信号（朗姆酒引导步骤失效 Bug）")

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 7: pirate_panel.gd 集成 Bug 检测
# ══════════════════════════════════════════════════════════════════════════════

func test_pirate_panel_market_notifies_onboarding() -> String:
	var src := _src("res://scenes/ui/panels/pirate_panel.gd")
	return _assert(src.contains("notify_market_item_bought"),
		"pirate_panel 购买黑市后未通知引导（黑市引导步骤卡住 Bug）")

func test_pirate_panel_market_updates_stat() -> String:
	var src := _src("res://scenes/ui/panels/pirate_panel.gd")
	return _assert(src.contains("black_market_trades"),
		"pirate_panel 购买黑市后未更新 black_market_trades 统计（任务日志不更新 Bug）")

func test_pirate_panel_treasure_notifies_onboarding() -> String:
	var src := _src("res://scenes/ui/panels/pirate_panel.gd")
	return _assert(src.contains("notify_treasure_explored"),
		"pirate_panel 探索宝藏后未通知引导（藏宝图引导步骤卡住 Bug）")

func test_pirate_panel_merc_notifies_onboarding() -> String:
	var src := _src("res://scenes/ui/panels/pirate_panel.gd")
	return _assert(src.contains("notify_merc_hired"),
		"pirate_panel 雇佣佣兵后未通知引导（雇佣兵引导步骤卡住 Bug）")

func test_pirate_panel_merc_updates_stat() -> String:
	var src := _src("res://scenes/ui/panels/pirate_panel.gd")
	return _assert(src.contains("mercenary_hired"),
		"pirate_panel 雇佣佣兵后未更新 mercenary_hired 统计（任务日志不更新 Bug）")

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 8: SaveManager 存档 Bug 检测
# ══════════════════════════════════════════════════════════════════════════════

func test_save_manager_pirate_onboarding_saved() -> String:
	var src := _src("res://autoloads/save_manager.gd")
	return _assert(src.contains("pirate_onboarding"),
		"SaveManager 未序列化 PirateOnboarding（引导进度不持久化 Bug）")

func test_save_manager_pirate_onboarding_loaded() -> String:
	var src := _src("res://autoloads/save_manager.gd")
	var count := src.split("pirate_onboarding").size() - 1
	return _assert(count >= 2,
		"SaveManager 只有单向序列化（存档或读档之一缺失 Bug）")
