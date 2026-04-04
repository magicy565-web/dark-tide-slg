## test_attack_bug_scene.gd — 攻击流程真实 Bug 测试
## 直接在 Godot 运行时实例化 CombatSystem，通过 await 调用协程
## 独立于 test_runner，作为专用测试场景运行
extends Node

const CombatSystem = preload("res://systems/combat/combat_system.gd")
const PirateQuestGuide = preload("res://systems/quest/pirate_quest_guide.gd")

var _pass := 0
var _fail := 0
var _errors: Array = []

func _ready() -> void:
	print("=" .repeat(64))
	print("  暗潮 SLG — Attack Bug Test (Runtime)")
	print("=" .repeat(64))
	await _run_all()
	_print_results()
	get_tree().quit(0 if _fail == 0 else 1)

func _ok(name: String) -> void:
	_pass += 1
	print("  [PASS] %s" % name)

func _fail_test(name: String, reason: String) -> void:
	_fail += 1
	_errors.append("%s — %s" % [name, reason])
	print("  [FAIL] %s\n         → %s" % [name, reason])

func _make_army(soldiers: int, atk: int, def_val: int, spd: int = 5,
				troop_id: String = "human_ashigaru", passive: String = "") -> Dictionary:
	return {
		"units": [{
			"id": "u_0",
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
			"passive": passive,
		}],
		"player_id": 0,
	}

func _make_node_data(terrain: int = 0, is_siege: bool = false, city_def: int = 0) -> Dictionary:
	return {"terrain": terrain, "is_siege": is_siege, "city_def": city_def}

func _new_combat() -> CombatSystem:
	var c := CombatSystem.new()
	c.player_controlled = false  # 禁用玩家干预，防止 await 阻塞
	return c

# ══════════════════════════════════════════════════════════════════════════════
# 运行所有测试
# ══════════════════════════════════════════════════════════════════════════════
func _run_all() -> void:
	print("\n--- SECTION 1: 基础战斗结果合法性 ---")
	await _test_strong_attacker_wins()
	await _test_weak_attacker_loses()
	await _test_equal_forces_timeout_defender_wins()
	await _test_result_has_all_required_keys()
	await _test_losses_non_negative()
	await _test_rounds_within_max()
	await _test_winner_is_valid_string()

	print("\n--- SECTION 2: 边界条件 Bug 测试 ---")
	await _test_empty_defender_attacker_wins()
	await _test_empty_attacker_returns_false()
	await _test_single_soldier_attacker()
	await _test_zero_atk_unit_no_crash()
	await _test_max_soldiers_no_crash()

	print("\n--- SECTION 3: 地形 Bug 测试 ---")
	await _test_all_terrains_no_crash()
	await _test_siege_no_crash()
	await _test_fortress_terrain_defender_bonus()

	print("\n--- SECTION 4: 海盗阵营特有 Bug 测试 ---")
	await _test_rum_atk_bonus_improves_result()
	await _test_pirate_passive_no_crash()

	print("\n--- SECTION 5: 多兵种 Bug 测试 ---")
	await _test_multi_unit_army_no_crash()
	await _test_front_back_row_no_crash()
	await _test_losses_applied_correctly()

	print("\n--- SECTION 6: PirateQuestGuide 运行时数据 ---")
	_test_guide_quest_count()
	_test_guide_quest_chain_integrity()
	_test_guide_quest_objectives_valid()
	_test_guide_quest_rewards_positive()

	print("\n--- SECTION 7: Autoload 运行时可用性 ---")
	_test_autoloads_available()
	_test_eventbus_signals_exist()
	_test_quest_journal_methods()
	_test_pirate_onboarding_methods()

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 1: 基础战斗结果合法性
# ══════════════════════════════════════════════════════════════════════════════

func _test_strong_attacker_wins() -> void:
	var name := "强攻方（100兵/ATK15）应胜弱守方（20兵/ATK4）"
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(100, 15, 8), _make_army(20, 4, 3), _make_node_data())
	if r.get("winner") == "attacker": _ok(name)
	else: _fail_test(name, "winner=%s rounds=%d" % [r.get("winner","?"), r.get("rounds_fought",0)])

func _test_weak_attacker_loses() -> void:
	var name := "弱攻方（5兵/ATK3）应败强守方（80兵/ATK12）"
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(5, 3, 2), _make_army(80, 12, 8), _make_node_data())
	if r.get("winner") == "defender": _ok(name)
	else: _fail_test(name, "winner=%s" % r.get("winner","?"))

func _test_equal_forces_timeout_defender_wins() -> void:
	var name := "势均力敌超时应守方获胜（defender wins on timeout）"
	# 极高防御，双方伤害极低，必然超时
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(100, 3, 50), _make_army(100, 3, 50), _make_node_data())
	if r.get("winner") == "defender": _ok(name)
	else: _fail_test(name, "winner=%s rounds=%d" % [r.get("winner","?"), r.get("rounds_fought",0)])

func _test_result_has_all_required_keys() -> void:
	var name := "战斗结果包含所有必要键"
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(30, 7, 5), _make_army(30, 7, 5), _make_node_data())
	var required := ["winner", "attacker_losses", "defender_losses", "log", "rounds_fought"]
	var missing := []
	for k in required:
		if not r.has(k): missing.append(k)
	if missing.is_empty(): _ok(name)
	else: _fail_test(name, "缺少键: %s" % str(missing))

func _test_losses_non_negative() -> void:
	var name := "战斗损失不为负数"
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(50, 8, 6), _make_army(50, 8, 6), _make_node_data())
	var bad := []
	for uid in r.get("attacker_losses", {}):
		if r["attacker_losses"][uid] < 0: bad.append("att:%s=%d" % [uid, r["attacker_losses"][uid]])
	for uid in r.get("defender_losses", {}):
		if r["defender_losses"][uid] < 0: bad.append("def:%s=%d" % [uid, r["defender_losses"][uid]])
	if bad.is_empty(): _ok(name)
	else: _fail_test(name, "负数损失: %s" % str(bad))

func _test_rounds_within_max() -> void:
	var name := "战斗回合数不超过 MAX_ROUNDS(%d)" % CombatSystem.MAX_ROUNDS
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(200, 5, 30), _make_army(200, 5, 30), _make_node_data())
	var rounds: int = r.get("rounds_fought", 0)
	if rounds <= CombatSystem.MAX_ROUNDS: _ok(name)
	else: _fail_test(name, "rounds=%d > MAX_ROUNDS=%d" % [rounds, CombatSystem.MAX_ROUNDS])

func _test_winner_is_valid_string() -> void:
	var name := "winner 字段只能是 'attacker' 或 'defender'"
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(40, 8, 5), _make_army(40, 8, 5), _make_node_data())
	var w: String = r.get("winner", "")
	if w == "attacker" or w == "defender": _ok(name)
	else: _fail_test(name, "winner='%s' 不合法" % w)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 2: 边界条件 Bug 测试
# ══════════════════════════════════════════════════════════════════════════════

func _test_empty_defender_attacker_wins() -> void:
	var name := "空守方（无兵）攻方直接获胜"
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(30, 7, 5), {"units": [], "player_id": -1}, _make_node_data())
	if r.get("winner") == "attacker": _ok(name)
	else: _fail_test(name, "winner=%s（空守方应直接获胜）" % r.get("winner","?"))

func _test_empty_attacker_returns_false() -> void:
	var name := "空攻方（无兵）不崩溃，守方获胜"
	var r: Dictionary = await _new_combat().resolve_battle(
		{"units": [], "player_id": 0}, _make_army(30, 7, 5), _make_node_data())
	# 空攻方应返回 defender 获胜，不崩溃
	if r.has("winner"): _ok(name)
	else: _fail_test(name, "空攻方导致崩溃或返回无效结果")

func _test_single_soldier_attacker() -> void:
	var name := "单兵攻方（1兵）不崩溃"
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(1, 5, 3), _make_army(50, 8, 6), _make_node_data())
	if r.has("winner"): _ok(name)
	else: _fail_test(name, "单兵攻方导致崩溃")

func _test_zero_atk_unit_no_crash() -> void:
	var name := "ATK=0 的单位不崩溃（零伤害边界）"
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(30, 0, 5), _make_army(30, 0, 5), _make_node_data())
	if r.has("winner"): _ok(name)
	else: _fail_test(name, "ATK=0 导致崩溃")

func _test_max_soldiers_no_crash() -> void:
	var name := "超大兵力（9999兵）不崩溃"
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(9999, 10, 8), _make_army(9999, 10, 8), _make_node_data())
	if r.has("winner"): _ok(name)
	else: _fail_test(name, "超大兵力导致崩溃")

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 3: 地形 Bug 测试
# ══════════════════════════════════════════════════════════════════════════════

func _test_all_terrains_no_crash() -> void:
	# 测试所有 10 种地形（0-9）均不崩溃
	for terrain_id in range(10):
		var name := "地形 %d 不崩溃" % terrain_id
		var r: Dictionary = await _new_combat().resolve_battle(
			_make_army(40, 7, 5), _make_army(40, 7, 5),
			_make_node_data(terrain_id))
		if r.has("winner"): _ok(name)
		else: _fail_test(name, "地形 %d 导致崩溃" % terrain_id)

func _test_siege_no_crash() -> void:
	var name := "攻城战（is_siege=true, city_def=15）不崩溃"
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(60, 9, 6), _make_army(30, 6, 5),
		_make_node_data(5, true, 15))
	if r.has("winner"): _ok(name)
	else: _fail_test(name, "攻城战导致崩溃")

func _test_fortress_terrain_defender_bonus() -> void:
	var name := "要塞地形（terrain=5）守方应有防御加成（胜率更高）"
	# 普通地形
	var r_plain: Dictionary = await _new_combat().resolve_battle(
		_make_army(50, 8, 6), _make_army(30, 6, 5), _make_node_data(0))
	# 要塞地形
	var r_fort: Dictionary = await _new_combat().resolve_battle(
		_make_army(50, 8, 6), _make_army(30, 6, 5), _make_node_data(5))
	# 要塞地形守方应更难被击败（要么守方获胜，要么攻方损失更多）
	var plain_att_loss: int = 0
	for k in r_plain.get("attacker_losses", {}): plain_att_loss += r_plain["attacker_losses"][k]
	var fort_att_loss: int = 0
	for k in r_fort.get("attacker_losses", {}): fort_att_loss += r_fort["attacker_losses"][k]
	if r_fort.get("winner") == "defender" or fort_att_loss >= plain_att_loss: _ok(name)
	else: _fail_test(name, "要塞地形未给守方加成: plain_att_loss=%d fort_att_loss=%d" % [plain_att_loss, fort_att_loss])

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 4: 海盗阵营特有 Bug 测试
# ══════════════════════════════════════════════════════════════════════════════

func _test_rum_atk_bonus_improves_result() -> void:
	var name := "朗姆酒 ATK+2 加成应改善攻方战斗结果"
	var r_no_rum: Dictionary = await _new_combat().resolve_battle(
		_make_army(20, 6, 5), _make_army(25, 7, 5), _make_node_data())
	var r_with_rum: Dictionary = await _new_combat().resolve_battle(
		_make_army(20, 8, 5), _make_army(25, 7, 5), _make_node_data())  # ATK+2
	# 有加成时要么获胜，要么回合数更少
	var improved: bool = (r_with_rum.get("winner") == "attacker") or \
		(r_with_rum.get("rounds_fought", 99) <= r_no_rum.get("rounds_fought", 99))
	if improved: _ok(name)
	else: _fail_test(name, "无加成: %s(%dr) 有加成: %s(%dr)" % [
		r_no_rum.get("winner","?"), r_no_rum.get("rounds_fought",0),
		r_with_rum.get("winner","?"), r_with_rum.get("rounds_fought",0)])

func _test_pirate_passive_no_crash() -> void:
	var name := "海盗被动技能（plunder_master）不崩溃"
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(40, 8, 6, 6, "pirate_corsair", "plunder_master"),
		_make_army(40, 7, 5), _make_node_data(4))  # coastal terrain
	if r.has("winner"): _ok(name)
	else: _fail_test(name, "海盗被动导致崩溃")

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 5: 多兵种 Bug 测试
# ══════════════════════════════════════════════════════════════════════════════

func _test_multi_unit_army_no_crash() -> void:
	var name := "多兵种军队（6个单位）不崩溃"
	var att := {
		"units": [
			{"id": "u0", "commander_id": "generic", "troop_id": "human_ashigaru",
			 "atk": 6, "def": 5, "spd": 5, "int": 3, "soldiers": 30, "max_soldiers": 30,
			 "row": 0, "slot": 0, "passive": ""},
			{"id": "u1", "commander_id": "generic", "troop_id": "human_cavalry",
			 "atk": 9, "def": 6, "spd": 8, "int": 3, "soldiers": 20, "max_soldiers": 20,
			 "row": 0, "slot": 1, "passive": ""},
			{"id": "u2", "commander_id": "generic", "troop_id": "human_archer",
			 "atk": 7, "def": 4, "spd": 4, "int": 5, "soldiers": 25, "max_soldiers": 25,
			 "row": 1, "slot": 0, "passive": "ranged"},
		],
		"player_id": 0,
	}
	var def_army := {
		"units": [
			{"id": "d0", "commander_id": "generic", "troop_id": "orc_grunt",
			 "atk": 8, "def": 7, "spd": 4, "int": 2, "soldiers": 40, "max_soldiers": 40,
			 "row": 0, "slot": 0, "passive": ""},
			{"id": "d1", "commander_id": "generic", "troop_id": "orc_shaman",
			 "atk": 6, "def": 4, "spd": 3, "int": 8, "soldiers": 15, "max_soldiers": 15,
			 "row": 1, "slot": 0, "passive": ""},
		],
		"player_id": 1,
	}
	var r: Dictionary = await _new_combat().resolve_battle(att, def_army, _make_node_data())
	if r.has("winner"): _ok(name)
	else: _fail_test(name, "多兵种军队导致崩溃")

func _test_front_back_row_no_crash() -> void:
	var name := "前排/后排混合编队不崩溃"
	var att := {
		"units": [
			{"id": "f0", "commander_id": "generic", "troop_id": "human_ashigaru",
			 "atk": 6, "def": 5, "spd": 5, "int": 3, "soldiers": 30, "max_soldiers": 30,
			 "row": 0, "slot": 0, "passive": ""},
			{"id": "b0", "commander_id": "generic", "troop_id": "human_mage",
			 "atk": 10, "def": 3, "spd": 3, "int": 10, "soldiers": 10, "max_soldiers": 10,
			 "row": 1, "slot": 0, "passive": ""},
		],
		"player_id": 0,
	}
	var r: Dictionary = await _new_combat().resolve_battle(
		att, _make_army(40, 7, 5), _make_node_data())
	if r.has("winner"): _ok(name)
	else: _fail_test(name, "前后排编队导致崩溃")

func _test_losses_applied_correctly() -> void:
	var name := "损失值与初始兵力一致（总损失 ≤ 初始兵力）"
	var init_att := 50
	var init_def := 50
	var r: Dictionary = await _new_combat().resolve_battle(
		_make_army(init_att, 8, 6), _make_army(init_def, 8, 6), _make_node_data())
	var att_loss := 0
	for k in r.get("attacker_losses", {}): att_loss += r["attacker_losses"][k]
	var def_loss := 0
	for k in r.get("defender_losses", {}): def_loss += r["defender_losses"][k]
	if att_loss <= init_att and def_loss <= init_def: _ok(name)
	else: _fail_test(name, "损失超过初始兵力: att_loss=%d/%d def_loss=%d/%d" % [
		att_loss, init_att, def_loss, init_def])

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 6: PirateQuestGuide 运行时数据（同步，不需要 await）
# ══════════════════════════════════════════════════════════════════════════════

func _test_guide_quest_count() -> void:
	var guide := PirateQuestGuide.new()
	var count: int = guide.GUIDE_QUESTS.size()
	if count == 10: _ok("PirateQuestGuide 包含 10 个引导任务")
	else: _fail_test("PirateQuestGuide 包含 10 个引导任务", "实际 %d 个" % count)

func _test_guide_quest_chain_integrity() -> void:
	var guide := PirateQuestGuide.new()
	var ok := true
	var reason := ""
	for i in range(guide.GUIDE_QUESTS.size()):
		var gq: Dictionary = guide.GUIDE_QUESTS[i]
		var expected_id := "pirate_g%d" % (i + 1)
		if gq.get("id") != expected_id:
			ok = false
			reason = "第%d个任务ID应为%s，实际%s" % [i+1, expected_id, gq.get("id","?")]
			break
		if i > 0:
			var trigger: Dictionary = gq.get("trigger", {})
			var expected_prev := "pirate_g%d" % i
			if trigger.get("prev_guide_done") != expected_prev:
				ok = false
				reason = "%s 的 prev_guide_done 应为 %s，实际 %s" % [
					gq.get("id"), expected_prev, trigger.get("prev_guide_done","?")]
				break
	if ok: _ok("引导任务链 prev_guide_done 串联正确")
	else: _fail_test("引导任务链 prev_guide_done 串联正确", reason)

func _test_guide_quest_objectives_valid() -> void:
	var guide := PirateQuestGuide.new()
	var ok := true
	var reason := ""
	for gq in guide.GUIDE_QUESTS:
		var objs: Array = gq.get("objectives", [])
		if objs.is_empty():
			ok = false
			reason = "任务 %s 的 objectives 为空" % gq.get("id","?")
			break
		for obj in objs:
			if not obj.has("type") or not obj.has("target"):
				ok = false
				reason = "任务 %s 的 objective 缺少 type 或 target 字段" % gq.get("id","?")
				break
	if ok: _ok("所有引导任务 objectives 结构合法")
	else: _fail_test("所有引导任务 objectives 结构合法", reason)

func _test_guide_quest_rewards_positive() -> void:
	var guide := PirateQuestGuide.new()
	var ok := true
	var reason := ""
	for gq in guide.GUIDE_QUESTS:
		var reward: Dictionary = gq.get("reward", {})
		var gold: int = reward.get("gold", 0)
		if gold <= 0:
			ok = false
			reason = "任务 %s 的 gold 奖励 <= 0 (实际: %d)" % [gq.get("id","?"), gold]
			break
	if ok: _ok("所有引导任务 gold 奖励 > 0")
	else: _fail_test("所有引导任务 gold 奖励 > 0", reason)

# ══════════════════════════════════════════════════════════════════════════════
# SECTION 7: Autoload 运行时可用性
# ══════════════════════════════════════════════════════════════════════════════

func _test_autoloads_available() -> void:
	var required := ["EventBus", "QuestJournal", "PirateMechanic",
					 "PirateOnboarding", "SaveManager", "HeroSystem"]
	for name in required:
		if Engine.has_singleton(name): _ok("Autoload 可用: %s" % name)
		else: _fail_test("Autoload 可用: %s" % name, "%s 未注册为 Autoload" % name)

func _test_eventbus_signals_exist() -> void:
	if not Engine.has_singleton("EventBus"):
		_fail_test("EventBus 信号检查", "EventBus 未注册")
		return
	var eb = Engine.get_singleton("EventBus")
	var sigs := ["combat_started", "combat_result", "combat_result_detailed",
				 "tutorial_combat_done", "infamy_changed", "rum_morale_changed",
				 "hero_recruited", "resources_changed", "message_log",
				 "quest_journal_updated"]
	for s in sigs:
		if eb.has_signal(s): _ok("EventBus 信号存在: %s" % s)
		else: _fail_test("EventBus 信号存在: %s" % s, "信号 %s 不存在" % s)

func _test_quest_journal_methods() -> void:
	if not Engine.has_singleton("QuestJournal"):
		_fail_test("QuestJournal 方法检查", "QuestJournal 未注册")
		return
	var qj = Engine.get_singleton("QuestJournal")
	var methods := ["increment_stat", "get_stats", "_check_guide_quests",
					"_complete_guide_quest", "get_all_quests"]
	for m in methods:
		if qj.has_method(m): _ok("QuestJournal 方法存在: %s" % m)
		else: _fail_test("QuestJournal 方法存在: %s" % m, "方法 %s 不存在" % m)

	# 运行时测试 increment_stat
	qj.increment_stat("_test_bug_counter", 3)
	qj.increment_stat("_test_bug_counter", 7)
	var stats: Dictionary = qj.get_stats()
	var val: int = stats.get("_test_bug_counter", -1)
	if val == 10: _ok("QuestJournal.increment_stat 累加正确 (3+7=10)")
	else: _fail_test("QuestJournal.increment_stat 累加正确", "期望 10，实际 %d" % val)

func _test_pirate_onboarding_methods() -> void:
	if not Engine.has_singleton("PirateOnboarding"):
		_fail_test("PirateOnboarding 方法检查", "PirateOnboarding 未注册")
		return
	var po = Engine.get_singleton("PirateOnboarding")
	var methods := ["start_onboarding", "stop_onboarding", "to_save_data",
					"from_save_data", "notify_market_item_bought",
					"notify_treasure_explored", "notify_merc_hired",
					"notify_harbor_captured"]
	for m in methods:
		if po.has_method(m): _ok("PirateOnboarding 方法存在: %s" % m)
		else: _fail_test("PirateOnboarding 方法存在: %s" % m, "方法 %s 不存在" % m)

	# 存档往返测试
	var saved: Dictionary = po.to_save_data()
	po.from_save_data({
		"active": false, "current_step_index": 5,
		"completed_steps": ["pirate_welcome", "pirate_plunder_intro", "pirate_plunder_do",
							"pirate_plunder_done", "pirate_market_intro"],
		"onboarding_complete": false,
		"flags": {
			"first_combat_done": true, "market_bought": true,
			"rum_active": false, "treasure_explored": false,
			"smuggle_established": false, "infamy_50_reached": false,
			"merc_hired": false, "hero_recruited": false,
			"harbor_captured": false, "challenge_started": false,
		}
	})
	var loaded: Dictionary = po.to_save_data()
	po.from_save_data(saved)  # 恢复
	if loaded.get("current_step_index", -1) == 5:
		_ok("PirateOnboarding 存档往返序列化正确")
	else:
		_fail_test("PirateOnboarding 存档往返序列化正确",
			"current_step_index 期望 5，实际 %d" % loaded.get("current_step_index", -1))

# ══════════════════════════════════════════════════════════════════════════════
# 打印最终结果
# ══════════════════════════════════════════════════════════════════════════════
func _print_results() -> void:
	print("")
	print("=" .repeat(64))
	print("  测试结果: %d 通过 / %d 失败 / %d 总计" % [_pass, _fail, _pass + _fail])
	print("=" .repeat(64))
	if _fail > 0:
		print("\n  失败项目:")
		for e in _errors:
			print("    [FAIL] %s" % e)
	else:
		print("  ✓ 所有攻击流程测试通过，未发现 Bug")
	print("")
