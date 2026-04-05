## eventbus_stronghold_signals.gd — 据点系统信号定义
## 在 EventBus.gd 中添加这些信号定义
## 或在启动时动态添加

extends Node

# ═════════════════════════════════════════════════════════════════
# 治理系统信号
# ═════════════════════════════════════════════════════════════════

## 政策激活信号
## 参数: tile_idx (int), policy_id (String)
signal governance_policy_activated(tile_idx: int, policy_id: String)

## 治理行动执行信号
## 参数: tile_idx (int), action_id (String)
signal governance_action_executed(tile_idx: int, action_id: String)

## 防御策略部署信号
## 参数: tile_idx (int), strategy_id (String)
signal governance_strategy_deployed(tile_idx: int, strategy_id: String)

## 秩序变化信号
## 参数: tile_idx (int), old_order (float), new_order (float)
signal governance_order_changed(tile_idx: int, old_order: float, new_order: float)

# ═════════════════════════════════════════════════════════════════
# 进攻系统信号
# ═════════════════════════════════════════════════════════════════

## 进攻行动执行信号
## 参数: attacker_idx (int), action_id (String), target_idx (int), result (Dictionary)
signal offensive_action_performed(attacker_idx: int, action_id: String, target_idx: int, result: Dictionary)

## 进攻行动失败信号
## 参数: tile_idx (int), action_id (String), reason (String)
signal offensive_action_failed(tile_idx: int, action_id: String, reason: String)

## 进攻冷却更新信号
## 参数: tile_idx (int), action_id (String), cooldown_remaining (int)
signal offensive_cooldown_updated(tile_idx: int, action_id: String, cooldown_remaining: int)

# ═════════════════════════════════════════════════════════════════
# 民心与腐败系统信号
# ═════════════════════════════════════════════════════════════════

## 民心变化信号
## 参数: tile_idx (int), old_morale (float), new_morale (float)
signal morale_changed(tile_idx: int, old_morale: float, new_morale: float)

## 腐败变化信号
## 参数: tile_idx (int), old_corruption (float), new_corruption (float)
signal corruption_changed(tile_idx: int, old_corruption: float, new_corruption: float)

## 叛乱风险信号（民心过低时触发）
## 参数: tile_idx (int), risk_level (String) - "low", "medium", "high"
signal rebellion_risk_changed(tile_idx: int, risk_level: String)

# ═════════════════════════════════════════════════════════════════
# 发展路径系统信号
# ═════════════════════════════════════════════════════════════════

## 发展路径升级信号
## 参数: tile_idx (int), path_id (String), new_level (int)
signal development_path_upgraded(tile_idx: int, path_id: String, new_level: int)

## 分支选择信号
## 参数: tile_idx (int), path_id (String), branch (String)
signal development_branch_chosen(tile_idx: int, path_id: String, branch: String)

## 发展点数变化信号
## 参数: tile_idx (int), old_points (int), new_points (int)
signal development_points_changed(tile_idx: int, old_points: int, new_points: int)

## 里程碑解锁信号
## 参数: tile_idx (int), milestone_id (String)
signal milestone_unlocked(tile_idx: int, milestone_id: String)

## 协同加成变化信号
## 参数: tile_idx (int), synergy_bonus (float)
signal synergy_bonus_changed(tile_idx: int, synergy_bonus: float)

# ═════════════════════════════════════════════════════════════════
# 据点面板信号
# ═════════════════════════════════════════════════════════════════

## 治理面板打开请求信号
## 参数: tile_idx (int)
signal open_governance_panel_requested(tile_idx: int)

## 进攻面板打开请求信号
## 参数: tile_idx (int)
signal open_offensive_panel_requested(tile_idx: int)

## 发展面板打开请求信号
## 参数: tile_idx (int)
signal open_development_panel_requested(tile_idx: int)

# ═════════════════════════════════════════════════════════════════
# 辅助方法
# ═════════════════════════════════════════════════════════════════

## 在 EventBus._ready() 中调用此方法以添加所有信号
func register_stronghold_signals() -> void:
	# 治理系统
	add_user_signal("governance_policy_activated")
	add_user_signal("governance_action_executed")
	add_user_signal("governance_strategy_deployed")
	add_user_signal("governance_order_changed")
	
	# 进攻系统
	add_user_signal("offensive_action_performed")
	add_user_signal("offensive_action_failed")
	add_user_signal("offensive_cooldown_updated")
	
	# 民心腐败系统
	add_user_signal("morale_changed")
	add_user_signal("corruption_changed")
	add_user_signal("rebellion_risk_changed")
	
	# 发展路径系统
	add_user_signal("development_path_upgraded")
	add_user_signal("development_branch_chosen")
	add_user_signal("development_points_changed")
	add_user_signal("milestone_unlocked")
	add_user_signal("synergy_bonus_changed")
	
	# 面板请求
	add_user_signal("open_governance_panel_requested")
	add_user_signal("open_offensive_panel_requested")
	add_user_signal("open_development_panel_requested")
