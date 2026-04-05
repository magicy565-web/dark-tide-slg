## hud_stronghold_integration.gd — HUD 与据点系统集成模块
## 负责 HUD 与治理、进攻、发展、民心腐败系统的信号注册与交互。
## 应在 HUD._ready() 中调用 setup_stronghold_integration()
extends Node

class_name HUDStrongholdIntegration

# ── 引用 ──
var hud: CanvasLayer  # 父 HUD 对象
var offensive_panel: Node = null
var morale_display: Control = null

# ── 信号定义 ──
signal governance_policy_activated(tile_idx: int, policy_id: String)
signal offensive_action_performed(attacker_idx: int, action_id: String, target_idx: int)
signal development_path_upgraded(tile_idx: int, path_id: String)
signal morale_changed(tile_idx: int, new_morale: float)
signal corruption_changed(tile_idx: int, new_corruption: float)

func _ready() -> void:
	pass

## 在 HUD._ready() 中调用此方法以完成据点系统集成
func setup_stronghold_integration(parent_hud: CanvasLayer) -> void:
	hud = parent_hud
	_register_eventbus_signals()
	_setup_ui_references()
	_connect_system_callbacks()

## 注册所有 EventBus 信号
func _register_eventbus_signals() -> void:
	# ── 治理系统信号 ──
	if EventBus.has_signal("governance_policy_activated"):
		EventBus.governance_policy_activated.connect(_on_governance_policy_activated)
	if EventBus.has_signal("governance_action_executed"):
		EventBus.governance_action_executed.connect(_on_governance_action_executed)
	if EventBus.has_signal("governance_strategy_deployed"):
		EventBus.governance_strategy_deployed.connect(_on_governance_strategy_deployed)
	
	# ── 进攻系统信号 ──
	if EventBus.has_signal("offensive_action_performed"):
		EventBus.offensive_action_performed.connect(_on_offensive_action_performed)
	if EventBus.has_signal("offensive_action_failed"):
		EventBus.offensive_action_failed.connect(_on_offensive_action_failed)
	
	# ── 民心腐败系统信号 ──
	if EventBus.has_signal("morale_changed"):
		EventBus.morale_changed.connect(_on_morale_changed)
	if EventBus.has_signal("corruption_changed"):
		EventBus.corruption_changed.connect(_on_corruption_changed)
	
	# ── 发展路径系统信号 ──
	if EventBus.has_signal("development_path_upgraded"):
		EventBus.development_path_upgraded.connect(_on_development_path_upgraded)
	if EventBus.has_signal("milestone_unlocked"):
		EventBus.milestone_unlocked.connect(_on_milestone_unlocked)
	
	# ── 秩序系统信号 ──
	if EventBus.has_signal("order_changed"):
		EventBus.order_changed.connect(_on_order_changed)

## 设置 UI 引用
func _setup_ui_references() -> void:
	# 创建进攻面板
	if offensive_panel == null:
		var offensive_panel_script = load("res://scenes/ui/panels/offensive_panel.gd")
		if offensive_panel_script:
			offensive_panel = offensive_panel_script.new()
			hud.add_child(offensive_panel)
	
	# 创建民心腐败显示（可选）
	_setup_morale_display()

## 设置民心腐败显示
func _setup_morale_display() -> void:
	# 这可以是一个小的 HUD 指示器，显示当前据点的民心和腐败
	# 暂时留空，可在后续扩展
	pass

## 连接系统回调
func _connect_system_callbacks() -> void:
	# 确保 GameManager 的系统已初始化
	if GameManager and GameManager.governance_system:
		# 可以在这里添加额外的系统级回调
		pass

# ═════════════════════════════════════════════════════════════════

## 治理系统回调

func _on_governance_policy_activated(tile_idx: int, policy_id: String) -> void:
	var tile = GameManager.tiles[tile_idx]
	var policy_name = GameManager.governance_system.POLICIES.get(policy_id, {}).get("name", policy_id)
	
	# 显示消息
	EventBus.message_log.emit("[color=cyan]据点 %s: 激活政策 %s[/color]" % [
		tile.get("name", "据点#%d" % tile_idx), policy_name])
	
	# 刷新 HUD 显示
	_refresh_tile_info(tile_idx)
	
	# 发出信号
	governance_policy_activated.emit(tile_idx, policy_id)

func _on_governance_action_executed(tile_idx: int, action_id: String) -> void:
	var tile = GameManager.tiles[tile_idx]
	var action_name = GameManager.governance_system.GOVERNANCE_ACTIONS.get(action_id, {}).get("name", action_id)
	
	EventBus.message_log.emit("[color=yellow]据点 %s: 执行行动 %s[/color]" % [
		tile.get("name", "据点#%d" % tile_idx), action_name])
	
	_refresh_tile_info(tile_idx)

func _on_governance_strategy_deployed(tile_idx: int, strategy_id: String) -> void:
	var tile = GameManager.tiles[tile_idx]
	var strategy_name = GameManager.governance_system.DEFENSE_STRATEGIES.get(strategy_id, {}).get("name", strategy_id)
	
	EventBus.message_log.emit("[color=green]据点 %s: 部署防御策略 %s[/color]" % [
		tile.get("name", "据点#%d" % tile_idx), strategy_name])
	
	_refresh_tile_info(tile_idx)

# ═════════════════════════════════════════════════════════════════

## 进攻系统回调

func _on_offensive_action_performed(attacker_idx: int, action_id: String, target_idx: int, result: Dictionary) -> void:
	var attacker = GameManager.tiles[attacker_idx]
	var target = GameManager.tiles[target_idx]
	var action = GameManager.offensive_system.OFFENSIVE_ACTIONS.get(action_id, {})
	
	if result.get("success", false):
		EventBus.message_log.emit("[color=lime]%s 对 %s 执行 %s 成功![/color]" % [
			attacker.get("name", "据点#%d" % attacker_idx),
			target.get("name", "据点#%d" % target_idx),
			action.get("name", action_id)])
	else:
		EventBus.message_log.emit("[color=red]%s 对 %s 执行 %s 失败: %s[/color]" % [
			attacker.get("name", "据点#%d" % attacker_idx),
			target.get("name", "据点#%d" % target_idx),
			action.get("name", action_id),
			result.get("reason", "未知原因")])
	
	_refresh_tile_info(attacker_idx)
	_refresh_tile_info(target_idx)
	
	offensive_action_performed.emit(attacker_idx, action_id, target_idx)

func _on_offensive_action_failed(tile_idx: int, action_id: String, reason: String) -> void:
	EventBus.message_log.emit("[color=orange]进攻失败: %s[/color]" % reason)

# ═════════════════════════════════════════════════════════════════

## 民心腐败系统回调

func _on_morale_changed(tile_idx: int, old_morale: float, new_morale: float) -> void:
	var delta = new_morale - old_morale
	var color = "lime" if delta > 0 else "red"
	
	EventBus.message_log.emit("[color=%s]据点 #%d 民心变化: %.0f → %.0f[/color]" % [
		color, tile_idx, old_morale, new_morale])
	
	_refresh_tile_info(tile_idx)
	morale_changed.emit(tile_idx, new_morale)

func _on_corruption_changed(tile_idx: int, old_corruption: float, new_corruption: float) -> void:
	var delta = new_corruption - old_corruption
	var color = "red" if delta > 0 else "lime"
	
	EventBus.message_log.emit("[color=%s]据点 #%d 腐败变化: %.0f → %.0f[/color]" % [
		color, tile_idx, old_corruption, new_corruption])
	
	_refresh_tile_info(tile_idx)
	corruption_changed.emit(tile_idx, new_corruption)

# ═════════════════════════════════════════════════════════════════

## 发展路径系统回调

func _on_development_path_upgraded(tile_idx: int, path_id: String, new_level: int) -> void:
	var path = GameManager.development_path_system.DEVELOPMENT_PATHS.get(path_id, {})
	
	EventBus.message_log.emit("[color=cyan]据点 #%d %s 升级到 Lv%d[/color]" % [
		tile_idx, path.get("name", path_id), new_level])
	
	_refresh_tile_info(tile_idx)
	development_path_upgraded.emit(tile_idx, path_id)

func _on_milestone_unlocked(tile_idx: int, milestone_id: String) -> void:
	var milestone = GameManager.development_path_system.MILESTONES.get(milestone_id, {})
	
	EventBus.message_log.emit("[color=gold]里程碑解锁: %s[/color]" % milestone.get("name", milestone_id))
	
	_refresh_tile_info(tile_idx)

# ═════════════════════════════════════════════════════════════════

## 秩序系统回调

## v13.0: 修复信号签名——EventBus.order_changed 发射单参数 (new_value: int)
## 原三参数版本与信号定义不匹配会导致连接失败
func _on_order_changed(new_value: int) -> void:
	EventBus.message_log.emit("[color=cyan]全局秩序更新: %d[/color]" % new_value)

# ═════════════════════════════════════════════════════════════════

## 辅助方法

func _refresh_tile_info(tile_idx: int) -> void:
	# 刷新 HUD 显示的据点信息
	# 这应该触发 HUD 的更新逻辑
	if hud and hud.has_method("_update_player_info"):
		hud._update_player_info()

func show_offensive_panel(tile_idx: int) -> void:
	if offensive_panel and offensive_panel.has_method("show_panel"):
		offensive_panel.show_panel(tile_idx)

func hide_offensive_panel() -> void:
	if offensive_panel and offensive_panel.has_method("hide_panel"):
		offensive_panel.hide_panel()

func get_morale_display() -> Control:
	return morale_display
