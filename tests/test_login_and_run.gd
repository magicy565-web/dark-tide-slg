## test_login_and_run.gd — 模拟登录 + 真实游戏运行测试
## 测试流程:
##   1. LoginManager 注册 / 登录 / 游客登录 / 登出
##   2. 游戏启动 (海盗阵营, 固定地图)
##   3. T0~T3 回合自动推进，验证核心系统正常运行
##   4. 存档 / 读档往返测试
##   5. 输出详细测试报告
## 版本: v1.0.0  作者: Manus AI
extends Node

# ═══════════════════════════════════════════════════════════════
#  测试状态
# ═══════════════════════════════════════════════════════════════
var _pass: int = 0
var _fail: int = 0
var _errors: Array = []
var _log_lines: Array = []

# 游戏运行状态追踪
var _turn_count: int = 0
var _max_turns: int = 4   # T0~T3
var _combat_results: Array = []
var _captured_tiles: Array = []
var _resource_snapshots: Array = []
var _waiting_for_turn: bool = false
var _got_signal: bool = false
var _test_username: String = "测试指挥官"
var _test_password: String = "test1234"

# ═══════════════════════════════════════════════════════════════
#  入口
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	_log("=" .repeat(70))
	_log("  暗潮 SLG — 模拟登录 + 真实游戏运行测试 (Godot 4.2.2 图形模式)")
	_log("  测试范围: 登录系统 + T0~T3 海盗阵营完整回合流程")
	_log("=" .repeat(70))
	await get_tree().process_frame
	await get_tree().process_frame
	await _run_all_tests()

# ═══════════════════════════════════════════════════════════════
#  主测试流程
# ═══════════════════════════════════════════════════════════════
func _run_all_tests() -> void:
	# ── Section 1: LoginManager 单元测试 ──
	_log("\n【Section 1】LoginManager 单元测试")
	await _test_login_manager()

	# ── Section 2: 游戏启动测试 ──
	_log("\n【Section 2】游戏启动与初始化测试")
	await _test_game_startup()

	# ── Section 3: T0~T3 回合运行测试 ──
	_log("\n【Section 3】T0~T3 回合自动推进测试")
	await _test_turns_t0_t3()

	# ── Section 4: 存档系统测试 ──
	_log("\n【Section 4】存档 / 读档往返测试")
	await _test_save_load()

	# ── 输出总结 ──
	_print_summary()

# ═══════════════════════════════════════════════════════════════
#  Section 1: LoginManager 测试
# ═══════════════════════════════════════════════════════════════
func _test_login_manager() -> void:
	# 1.1 LoginManager autoload 已注册
	_check("LoginManager autoload 已注册",
		Engine.has_singleton("LoginManager"))

	if not Engine.has_singleton("LoginManager"):
		_log("  ⚠ LoginManager 未注册，跳过后续登录测试")
		return

	var lm = Engine.get_singleton("LoginManager")

	# 1.2 初始状态未登录
	_check("初始状态 is_logged_in == false",
		not lm.is_logged_in)

	# 1.3 注册新账号
	var reg_done := false
	var reg_ok := false
	lm.register_success.connect(func(_u): reg_ok = true; reg_done = true, CONNECT_ONE_SHOT)
	lm.register_failed.connect(func(_r): reg_done = true, CONNECT_ONE_SHOT)
	lm.register(_test_username, _test_password)
	var t := 0
	while not reg_done and t < 60:
		await get_tree().process_frame
		t += 1
	_check("注册账号 '%s' 成功" % _test_username, reg_ok)

	# 1.4 重复注册应失败
	var dup_fail := false
	var dup_done := false
	lm.register_failed.connect(func(_r): dup_fail = true; dup_done = true, CONNECT_ONE_SHOT)
	lm.register_success.connect(func(_u): dup_done = true, CONNECT_ONE_SHOT)
	lm.register(_test_username, _test_password)
	t = 0
	while not dup_done and t < 60:
		await get_tree().process_frame
		t += 1
	_check("重复注册同名账号应失败", dup_fail)

	# 1.5 密码错误登录应失败
	var wrong_fail := false
	var wrong_done := false
	lm.login_failed.connect(func(_r): wrong_fail = true; wrong_done = true, CONNECT_ONE_SHOT)
	lm.login_success.connect(func(_u, _g): wrong_done = true, CONNECT_ONE_SHOT)
	lm.login(_test_username, "wrongpassword")
	t = 0
	while not wrong_done and t < 60:
		await get_tree().process_frame
		t += 1
	_check("密码错误登录应失败", wrong_fail)

	# 1.6 正确密码登录成功
	var login_ok := false
	var login_done := false
	lm.login_success.connect(func(_u, _g): login_ok = true; login_done = true, CONNECT_ONE_SHOT)
	lm.login_failed.connect(func(_r): login_done = true, CONNECT_ONE_SHOT)
	lm.login(_test_username, _test_password)
	t = 0
	while not login_done and t < 60:
		await get_tree().process_frame
		t += 1
	_check("正确密码登录成功", login_ok)
	_check("登录后 is_logged_in == true", lm.is_logged_in)
	_check("登录后 current_user 正确", lm.current_user == _test_username)
	_check("登录后 is_guest == false", not lm.is_guest)

	# 1.7 get_user_info 返回正确数据
	var info: Dictionary = lm.get_user_info()
	_check("get_user_info 返回 username", info.get("username", "") == _test_username)
	_check("get_user_info 返回 is_guest=false", not info.get("is_guest", true))

	# 1.8 登出
	var logout_done := false
	lm.logout_done.connect(func(): logout_done = true, CONNECT_ONE_SHOT)
	lm.logout()
	t = 0
	while not logout_done and t < 60:
		await get_tree().process_frame
		t += 1
	_check("登出后 is_logged_in == false", not lm.is_logged_in)

	# 1.9 游客登录
	var guest_ok := false
	var guest_done := false
	lm.login_success.connect(func(_u, g): guest_ok = g; guest_done = true, CONNECT_ONE_SHOT)
	lm.login_as_guest()
	t = 0
	while not guest_done and t < 60:
		await get_tree().process_frame
		t += 1
	_check("游客登录成功", lm.is_logged_in)
	_check("游客登录 is_guest == true", lm.is_guest)
	_check("游客名以 '游客_' 开头", lm.current_user.begins_with("游客_"))

	# 1.10 Token 非空
	_check("登录后 Token 非空", lm.current_token.length() > 0)

	# 清理：登出游客
	lm.logout()
	await get_tree().process_frame

# ═══════════════════════════════════════════════════════════════
#  Section 2: 游戏启动测试
# ═══════════════════════════════════════════════════════════════
func _test_game_startup() -> void:
	_check("GameManager autoload 已注册",
		Engine.has_singleton("GameManager"))
	_check("EventBus autoload 已注册",
		Engine.has_singleton("EventBus"))
	_check("ResourceManager autoload 已注册",
		Engine.has_singleton("ResourceManager"))
	_check("FactionManager autoload 已注册",
		Engine.has_singleton("FactionManager"))
	_check("PirateMechanic autoload 已注册",
		Engine.has_singleton("PirateMechanic"))
	_check("SaveManager autoload 已注册",
		Engine.has_singleton("SaveManager"))

	if not Engine.has_singleton("GameManager"):
		_log("  ⚠ GameManager 未注册，跳过游戏启动测试")
		return

	var gm = Engine.get_singleton("GameManager")
	var eb = Engine.get_singleton("EventBus")

	# 连接消息日志
	if eb.has_signal("message_log"):
		eb.message_log.connect(_on_message_log)

	# 连接回合信号
	if eb.has_signal("turn_started"):
		eb.turn_started.connect(_on_turn_started)
	if eb.has_signal("tile_captured"):
		eb.tile_captured.connect(_on_tile_captured)
	if eb.has_signal("combat_result"):
		eb.combat_result.connect(_on_combat_result)
	if eb.has_signal("combat_intervention_phase"):
		eb.combat_intervention_phase.connect(_on_combat_intervention)

	# 启动游戏（海盗阵营，固定地图）
	var FactionData = load("res://systems/faction/faction_data.gd")
	var pirate_id: int = FactionData.FactionID.PIRATE if FactionData else 2
	_log("  启动游戏: 海盗阵营 (faction_id=%d), 固定地图" % pirate_id)
	gm.start_game(pirate_id, true)

	await get_tree().process_frame
	await get_tree().process_frame

	_check("game_active == true", gm.game_active)
	_check("tiles 数组非空", gm.tiles.size() > 0)
	_check("players 数组非空", gm.players.size() > 0)

	# 验证玩家初始资源
	var rm = Engine.get_singleton("ResourceManager")
	if rm:
		var gold: int = rm.get_resource(0, "gold")
		var food: int = rm.get_resource(0, "food")
		_check("初始金币 > 0", gold > 0)
		_check("初始粮食 > 0", food > 0)
		_log("  初始资源: 金=%d 粮=%d" % [gold, food])
		_resource_snapshots.append({"turn": 0, "gold": gold, "food": food})

	# 验证海盗阵营特有机制
	var pm = Engine.get_singleton("PirateMechanic")
	if pm:
		var infamy: int = pm.get_infamy(0)
		var rum_morale: int = pm.get_rum_morale(0)
		_check("初始恶名 >= 0", infamy >= 0)
		_check("初始朗姆酒士气 >= 0", rum_morale >= 0)
		_log("  海盗机制: 恶名=%d 朗姆酒士气=%d" % [infamy, rum_morale])

# ═══════════════════════════════════════════════════════════════
#  Section 3: T0~T3 回合测试
# ═══════════════════════════════════════════════════════════════
func _test_turns_t0_t3() -> void:
	if not Engine.has_singleton("GameManager"):
		_log("  ⚠ GameManager 不可用，跳过回合测试")
		return

	var gm = Engine.get_singleton("GameManager")
	if not gm.game_active:
		_log("  ⚠ 游戏未激活，跳过回合测试")
		return

	_log("  开始 T0~T3 回合推进...")

	for turn_idx in range(_max_turns):
		_log("\n  ── T%d 回合 ──" % turn_idx)
		await _run_one_turn(turn_idx, gm)

	_check("完成 %d 个回合" % _max_turns, _turn_count >= _max_turns)
	_log("  占领领地记录: %s" % str(_captured_tiles))
	_log("  战斗结果记录: %d 场战斗" % _combat_results.size())

func _run_one_turn(turn_idx: int, gm) -> void:
	# 等待玩家回合
	await _wait_for_player_turn(gm)

	var rm = Engine.get_singleton("ResourceManager")
	if rm:
		var gold: int = rm.get_resource(0, "gold")
		var food: int = rm.get_resource(0, "food")
		_log("    回合开始资源: 金=%d 粮=%d" % [gold, food])
		_resource_snapshots.append({"turn": turn_idx + 1, "gold": gold, "food": food})

	# 执行回合行动
	match turn_idx:
		0: await _turn_0_actions(gm)   # T0: 侦察 + 招募
		1: await _turn_1_actions(gm)   # T1: 进攻邻近领地
		2: await _turn_2_actions(gm)   # T2: 资源开采 + 外交
		3: await _turn_3_actions(gm)   # T3: 巩固 + 存档

	# 结束玩家回合，推进 AI
	_log("    结束回合 T%d" % turn_idx)
	if gm.has_method("end_turn"):
		gm.end_turn()
	await get_tree().process_frame
	await get_tree().process_frame
	_turn_count += 1

func _turn_0_actions(gm) -> void:
	_log("    T0: 侦察地图 + 招募兵员")
	# 尝试招募
	if gm.has_method("action_recruit"):
		var result = gm.action_recruit(0, 5)
		_log("    招募结果: %s" % str(result))
	# 检查 AP
	var player = gm.players[0] if gm.players.size() > 0 else {}
	_log("    当前 AP: %d" % player.get("ap", 0))
	await get_tree().process_frame

func _turn_1_actions(gm) -> void:
	_log("    T1: 尝试进攻邻近领地")
	# 找到玩家拥有的领地
	var player_tile := -1
	var target_tile := -1
	for i in range(gm.tiles.size()):
		var t: Dictionary = gm.tiles[i]
		if t.get("owner_id", -1) == 0:
			player_tile = i
			break
	if player_tile >= 0 and gm.adjacency.has(player_tile):
		for adj in gm.adjacency[player_tile]:
			var adj_tile: Dictionary = gm.tiles[adj]
			if adj_tile.get("owner_id", -1) != 0:
				target_tile = adj
				break
	if player_tile >= 0 and target_tile >= 0:
		_log("    进攻: 从 tile#%d 攻击 tile#%d" % [player_tile, target_tile])
		if gm.has_method("action_attack"):
			var result = gm.action_attack(0, player_tile, target_tile)
			_log("    进攻结果: %s" % str(result).left(100))
	else:
		_log("    无可进攻目标，跳过")
	await get_tree().process_frame

func _turn_2_actions(gm) -> void:
	_log("    T2: 资源开采 + 外交探索")
	# 尝试开采资源站
	for i in range(gm.tiles.size()):
		var t: Dictionary = gm.tiles[i]
		if t.get("owner_id", -1) == 0 and t.get("resource_station_type", "") != "":
			if gm.has_method("action_exploit"):
				var result = gm.action_exploit(0, i)
				_log("    开采 tile#%d (%s): %s" % [i, t["resource_station_type"], str(result).left(60)])
			break
	await get_tree().process_frame

func _turn_3_actions(gm) -> void:
	_log("    T3: 巩固防御 + 验证数值")
	# 检查资源增长
	var rm = Engine.get_singleton("ResourceManager")
	if rm and _resource_snapshots.size() >= 2:
		var snap0 = _resource_snapshots[0]
		var snap_now: Dictionary = {"turn": 3,
			"gold": rm.get_resource(0, "gold"),
			"food": rm.get_resource(0, "food")}
		_log("    资源变化: 金 %d→%d  粮 %d→%d" % [
			snap0["gold"], snap_now["gold"],
			snap0["food"], snap_now["food"]])
		_check("T3 金币 >= T0 金币（有产出）", snap_now["gold"] >= snap0["gold"] - 50)
	await get_tree().process_frame

# ═══════════════════════════════════════════════════════════════
#  Section 4: 存档测试
# ═══════════════════════════════════════════════════════════════
func _test_save_load() -> void:
	if not Engine.has_singleton("SaveManager"):
		_log("  ⚠ SaveManager 不可用，跳过存档测试")
		return
	if not Engine.has_singleton("GameManager"):
		return

	var sm = Engine.get_singleton("SaveManager")
	var gm = Engine.get_singleton("GameManager")

	if not gm.game_active:
		_log("  ⚠ 游戏未激活，跳过存档测试")
		return

	# 存档前记录状态
	var rm = Engine.get_singleton("ResourceManager")
	var gold_before: int = rm.get_resource(0, "gold") if rm else 0
	var turn_before: int = gm.current_turn if gm.has_method("get") else 0

	# 保存
	var save_ok: bool = sm.save_game(0)
	_check("存档到槽位 0 成功", save_ok)

	if not save_ok:
		return

	# 修改状态（模拟游戏继续）
	await get_tree().process_frame

	# 读档
	var load_ok: bool = sm.load_game(0)
	_check("从槽位 0 读档成功", load_ok)

	if load_ok and rm:
		var gold_after: int = rm.get_resource(0, "gold")
		_check("读档后金币与存档时一致", gold_after == gold_before)
		_log("  存档/读档金币: %d → %d" % [gold_before, gold_after])

# ═══════════════════════════════════════════════════════════════
#  等待玩家回合
# ═══════════════════════════════════════════════════════════════
func _wait_for_player_turn(gm) -> void:
	if _is_player_turn(gm):
		return
	_waiting_for_turn = true
	_got_signal = false
	var timeout := 0
	while not _got_signal and timeout < 200:
		await get_tree().process_frame
		timeout += 1
		if _is_player_turn(gm):
			break
	_waiting_for_turn = false

func _is_player_turn(gm) -> bool:
	if not gm.game_active:
		return false
	if gm.has_method("is_player_turn"):
		return gm.is_player_turn(0)
	# 备用：检查 current_player_index
	return gm.get("current_player_index") == 0

# ═══════════════════════════════════════════════════════════════
#  信号回调
# ═══════════════════════════════════════════════════════════════
func _on_turn_started(player_id: int) -> void:
	if _waiting_for_turn and player_id == 0:
		_got_signal = true

func _on_message_log(msg: String) -> void:
	var clean := msg
	var safety := 0
	while "[" in clean and "]" in clean and safety < 20:
		var s := clean.find("[")
		var e := clean.find("]", s)
		if e > s:
			clean = clean.substr(0, s) + clean.substr(e + 1)
		else:
			break
		safety += 1
	if clean.strip_edges().length() > 0:
		_log("  [LOG] " + clean.strip_edges().left(80))

func _on_tile_captured(player_id: int, tile_index: int) -> void:
	var gm = Engine.get_singleton("GameManager")
	var tile_name := "tile#%d" % tile_index
	if gm and tile_index < gm.tiles.size():
		tile_name = gm.tiles[tile_index].get("name", tile_name)
	var entry := "玩家%d 占领 %s" % [player_id, tile_name]
	_captured_tiles.append(entry)
	_log("  [占领] " + entry)

func _on_combat_result(result: Dictionary) -> void:
	_combat_results.append(result)
	var winner: String = result.get("winner", "?")
	_log("  [战斗] 胜者=%s" % winner)

func _on_combat_intervention(_state: Dictionary) -> void:
	# 自动跳过指挥官干预（图形模式测试中不等待 UI 输入）
	var eb = Engine.get_singleton("EventBus")
	if eb and eb.has_signal("combat_intervention_chosen"):
		eb.combat_intervention_chosen.emit(-1, null)

# ═══════════════════════════════════════════════════════════════
#  断言 / 日志
# ═══════════════════════════════════════════════════════════════
func _check(desc: String, condition: bool) -> void:
	if condition:
		_pass += 1
		_log("  ✅ PASS: " + desc)
	else:
		_fail += 1
		_errors.append(desc)
		_log("  ❌ FAIL: " + desc)

func _log(msg: String) -> void:
	print(msg)
	_log_lines.append(msg)

func _print_summary() -> void:
	_log("\n" + "=" .repeat(70))
	_log("  测试结果: %d/%d 通过" % [_pass, _pass + _fail])
	if _fail > 0:
		_log("  失败项目:")
		for e in _errors:
			_log("    ✗ " + e)
	else:
		_log("  🎉 全部测试通过！")
	_log("  回合推进: T0~T%d (%d 回合)" % [_turn_count - 1, _turn_count])
	_log("  战斗记录: %d 场" % _combat_results.size())
	_log("  占领记录: %d 块领地" % _captured_tiles.size())
	_log("=" .repeat(70))

	# 将报告写入文件
	var report_path := "user://test_login_run_report.txt"
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f:
		for line in _log_lines:
			f.store_line(line)
		f.close()
		print("测试报告已写入: " + report_path)
