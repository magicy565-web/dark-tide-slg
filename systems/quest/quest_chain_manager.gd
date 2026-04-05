## quest_chain_manager.gd — 任务链管理器 (v1.0)
## Autoload 单例。负责解析、管理和驱动所有复杂任务链（Graph-Driven Quest Chains）。
##
## 核心职责:
##   1. 加载 QuestChainData.CHAINS 中定义的所有任务链
##   2. 每回合评估链的触发条件，自动激活符合条件的链
##   3. 管理链内各节点的状态机（LOCKED → AVAILABLE → ACTIVE → COMPLETED/FAILED/SKIPPED）
##   4. 处理分支选择（branch_choice），锁定互斥分支
##   5. 通过 EventBus 发射任务链信号，驱动 UI 更新
##   6. 与 QuestJournal、EventSystem 深度集成
##   7. 支持存档/读档
extends Node

const QuestChainData = preload("res://systems/quest/quest_chain_data.gd")
const QuestDefs = preload("res://systems/quest/quest_definitions.gd")

# ═══════════════ 状态枚举 ═══════════════
enum NodeStatus {
	LOCKED    = 0,
	AVAILABLE = 1,
	ACTIVE    = 2,
	COMPLETED = 3,
	FAILED    = 4,
	SKIPPED   = 5,
}

# ═══════════════ 状态存储 ═══════════════
## 链状态: chain_id -> { "active": bool, "started_turn": int, "completed": bool }
var _chain_states: Dictionary = {}
## 节点状态: chain_id -> { node_id -> NodeStatus }
var _node_states: Dictionary = {}
## 全局标记: flag_id -> bool (跨链共享)
var _global_flags: Dictionary = {}
## 分支选择历史: chain_id -> { parent_node_id -> chosen_node_id }
var _branch_choices: Dictionary = {}
## 待处理的分支选择请求: { chain_id, node_id, options: [node_id, ...] }
var _pending_branch_request: Dictionary = {}
## 已激活的链 ID 列表（用于 UI 显示）
var _active_chain_ids: Array = []
## 已完成的链 ID 列表
var _completed_chain_ids: Array = []

# ═══════════════ 生命周期 ═══════════════
func _ready() -> void:
	_init_all_chains()
	if EventBus:
		EventBus.turn_started.connect(_on_turn_started)
		EventBus.quest_chain_branch_chosen.connect(_on_branch_chosen)

func _init_all_chains() -> void:
	## 初始化所有链的状态（所有节点从 LOCKED 开始）
	for chain_id in QuestChainData.CHAINS:
		_chain_states[chain_id] = {
			"active": false,
			"started_turn": -1,
			"completed": false,
		}
		_node_states[chain_id] = {}
		_branch_choices[chain_id] = {}
		var chain: Dictionary = QuestChainData.CHAINS[chain_id]
		for node_id in chain.get("nodes", {}):
			_node_states[chain_id][node_id] = NodeStatus.LOCKED

func reset() -> void:
	_chain_states.clear()
	_node_states.clear()
	_global_flags.clear()
	_branch_choices.clear()
	_pending_branch_request.clear()
	_active_chain_ids.clear()
	_completed_chain_ids.clear()
	_init_all_chains()

# ═══════════════ 每回合驱动 ═══════════════
func _on_turn_started(player_id: int) -> void:
	tick(player_id)

func tick(player_id: int) -> void:
	## 每回合调用：检查链触发、推进节点状态
	# 1. 检查未激活的链是否满足触发条件
	for chain_id in QuestChainData.CHAINS:
		if _chain_states[chain_id]["active"] or _chain_states[chain_id]["completed"]:
			continue
		var chain: Dictionary = QuestChainData.CHAINS[chain_id]
		if _check_chain_trigger(chain.get("trigger", {}), player_id):
			_activate_chain(chain_id, player_id)

	# 2. 推进已激活的链
	for chain_id in _active_chain_ids.duplicate():
		_tick_chain(chain_id, player_id)

func _activate_chain(chain_id: String, player_id: int) -> void:
	## 激活一条任务链
	_chain_states[chain_id]["active"] = true
	_chain_states[chain_id]["started_turn"] = GameManager.turn_number if GameManager else 0
	_active_chain_ids.append(chain_id)
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var start_node: String = chain.get("start_node", "")
	if start_node != "":
		_unlock_node(chain_id, start_node, player_id)
	EventBus.quest_chain_started.emit(chain_id)
	EventBus.message_log.emit("[color=cyan][任务链] 新任务链开始: %s[/color]" % chain.get("name", chain_id))

func _tick_chain(chain_id: String, player_id: int) -> void:
	## 推进链内节点状态
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var nodes: Dictionary = chain.get("nodes", {})
	for node_id in nodes:
		var status: int = _node_states[chain_id].get(node_id, NodeStatus.LOCKED)
		if status == NodeStatus.ACTIVE:
			_check_node_completion(chain_id, node_id, player_id)
		elif status == NodeStatus.AVAILABLE:
			# 自动激活非 branch_choice 节点
			var node: Dictionary = nodes[node_id]
			if not node.get("branch_choice", false):
				_activate_node(chain_id, node_id, player_id)

	# 检查链是否全部完成
	_check_chain_completion(chain_id)

# ═══════════════ 节点状态机 ═══════════════
func _unlock_node(chain_id: String, node_id: String, player_id: int) -> void:
	## 将节点从 LOCKED 变为 AVAILABLE
	if _node_states[chain_id].get(node_id, NodeStatus.LOCKED) != NodeStatus.LOCKED:
		return
	_node_states[chain_id][node_id] = NodeStatus.AVAILABLE
	EventBus.quest_chain_node_unlocked.emit(chain_id, node_id)
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var node: Dictionary = chain.get("nodes", {}).get(node_id, {})
	var node_name: String = node.get("name", node_id)
	EventBus.message_log.emit("[color=yellow][任务链] %s — 节点解锁: %s[/color]" % [
		chain.get("name", chain_id), node_name])
	# 如果是 branch_choice 节点，发起分支选择请求
	if node.get("branch_choice", false):
		_request_branch_choice(chain_id, node_id, player_id)

func _activate_node(chain_id: String, node_id: String, player_id: int) -> void:
	## 将节点从 AVAILABLE 变为 ACTIVE
	if _node_states[chain_id].get(node_id, NodeStatus.LOCKED) != NodeStatus.AVAILABLE:
		return
	_node_states[chain_id][node_id] = NodeStatus.ACTIVE
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var node: Dictionary = chain.get("nodes", {}).get(node_id, {})
	var node_type: String = node.get("type", "quest")
	match node_type:
		"event":
			_trigger_node_event(chain_id, node_id, node, player_id)
		"quest":
			_register_node_quest(chain_id, node_id, node, player_id)
		"gate":
			# Gate 节点：立即检查条件
			_check_node_completion(chain_id, node_id, player_id)
		"reward":
			# Reward 节点：立即发放奖励并完成
			_apply_node_reward(chain_id, node_id, node, player_id)
			_complete_node(chain_id, node_id, player_id)

func _complete_node(chain_id: String, node_id: String, player_id: int) -> void:
	## 将节点标记为 COMPLETED，并解锁后续节点
	if _node_states[chain_id].get(node_id, NodeStatus.LOCKED) == NodeStatus.COMPLETED:
		return
	_node_states[chain_id][node_id] = NodeStatus.COMPLETED
	EventBus.quest_chain_node_completed.emit(chain_id, node_id)
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var node: Dictionary = chain.get("nodes", {}).get(node_id, {})
	var node_name: String = node.get("name", node_id)
	EventBus.message_log.emit("[color=green][任务链] %s — 节点完成: %s[/color]" % [
		chain.get("name", chain_id), node_name])
	# 解锁后续节点
	var next_nodes: Array = node.get("next", [])
	for next_id in next_nodes:
		if _can_unlock_node(chain_id, next_id):
			_unlock_node(chain_id, next_id, player_id)

func _fail_node(chain_id: String, node_id: String) -> void:
	## 将节点标记为 FAILED
	_node_states[chain_id][node_id] = NodeStatus.FAILED
	EventBus.quest_chain_node_failed.emit(chain_id, node_id)
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var node: Dictionary = chain.get("nodes", {}).get(node_id, {})
	EventBus.message_log.emit("[color=red][任务链] %s — 节点失败: %s[/color]" % [
		chain.get("name", chain_id), node.get("name", node_id)])

func _skip_node(chain_id: String, node_id: String) -> void:
	## 将节点标记为 SKIPPED（因互斥分支被选择）
	if _node_states[chain_id].get(node_id, NodeStatus.LOCKED) in [NodeStatus.COMPLETED, NodeStatus.FAILED]:
		return
	_node_states[chain_id][node_id] = NodeStatus.SKIPPED

# ═══════════════ 条件检查 ═══════════════
func _can_unlock_node(chain_id: String, node_id: String) -> bool:
	## 检查节点的所有前置条件是否满足
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var node: Dictionary = chain.get("nodes", {}).get(node_id, {})
	# 检查 requires（所有前置均需完成）
	var requires: Array = node.get("requires", [])
	for req_id in requires:
		if _node_states[chain_id].get(req_id, NodeStatus.LOCKED) != NodeStatus.COMPLETED:
			return false
	# 检查 requires_any（任意一个前置完成即可）
	var requires_any: Array = node.get("requires_any", [])
	if not requires_any.is_empty():
		var any_done: bool = false
		for req_id in requires_any:
			if _node_states[chain_id].get(req_id, NodeStatus.LOCKED) == NodeStatus.COMPLETED:
				any_done = true
				break
		if not any_done:
			return false
	return true

func _check_node_completion(chain_id: String, node_id: String, player_id: int) -> void:
	## 检查 ACTIVE 节点是否已完成
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var node: Dictionary = chain.get("nodes", {}).get(node_id, {})
	var node_type: String = node.get("type", "quest")
	match node_type:
		"quest":
			# 检查对应的 QuestJournal 任务是否完成
			var quest_id: String = node.get("quest_id", "")
			if quest_id != "" and QuestJournal:
				if _is_chain_quest_completed(quest_id, player_id):
					_complete_node(chain_id, node_id, player_id)
		"event":
			# 事件节点：等待玩家选择（通过 _on_branch_chosen 触发）
			pass
		"gate":
			# 检查 gate 条件
			var condition: Dictionary = node.get("condition", {})
			if _check_gate_condition(condition, chain_id, player_id):
				_complete_node(chain_id, node_id, player_id)
		"reward":
			# Reward 节点在 _activate_node 中立即完成
			pass

func _check_gate_condition(condition: Dictionary, chain_id: String, player_id: int) -> bool:
	## 检查 gate 节点的条件
	for key in condition:
		match key:
			"quest_completed":
				if QuestJournal:
					if not _is_chain_quest_completed(condition[key], player_id):
						return false
			"all_completed":
				for node_id in condition[key]:
					if _node_states[chain_id].get(node_id, NodeStatus.LOCKED) != NodeStatus.COMPLETED:
						return false
			"flag_set":
				if not _global_flags.get(condition[key], false):
					return false
			"flag_set_any":
				var any_set: bool = false
				for flag_id in condition[key]:
					if _global_flags.get(flag_id, false):
						any_set = true
						break
				if not any_set:
					return false
	return true

func _check_chain_trigger(trigger: Dictionary, player_id: int) -> bool:
	## 检查任务链的触发条件
	for key in trigger:
		match key:
			"quest_completed":
				if QuestJournal:
					var q: Dictionary = QuestJournal.get_quest_by_id(trigger[key])
					if q.get("status", -1) != QuestDefs.QuestStatus.COMPLETED:
						return false
			"turn_min":
				if GameManager and GameManager.turn_number < trigger[key]:
					return false
			"tiles_min":
				if GameManager and GameManager.count_tiles_owned(player_id) < trigger[key]:
					return false
			"gold_min":
				if ResourceManager and ResourceManager.get_resource(player_id, "gold") < trigger[key]:
					return false
			"threat_min":
				if ThreatManager and ThreatManager.get_threat() < trigger[key]:
					return false
			"order_below":
				if OrderManager and OrderManager.get_order() >= trigger[key]:
					return false
			"heroes_min":
				if HeroSystem and HeroSystem.recruited_heroes.size() < trigger[key]:
					return false
			"shadow_essence_min":
				if ResourceManager and ResourceManager.get_resource(player_id, "shadow_essence") < trigger[key]:
					return false
			"prestige_min":
				if ResourceManager and ResourceManager.get_resource(player_id, "prestige") < trigger[key]:
					return false
			"neutral_recruited_min":
				if QuestManager and QuestManager.get_recruited_factions(player_id).size() < trigger[key]:
					return false
			"pirate_faction_exists":
				if trigger[key] and FactionManager:
					if not FactionManager.is_faction_alive(preload("res://systems/faction/faction_data.gd").FactionID.PIRATE):
						return false
			"event_triggered":
				if EventSystem and not EventSystem._triggered_ids.has(trigger[key]):
					return false
			"flag_set":
				if not _global_flags.get(trigger[key], false):
					return false
	return true

# ═══════════════ 节点类型处理 ═══════════════
func _trigger_node_event(chain_id: String, node_id: String, node: Dictionary, _player_id: int) -> void:
	## 触发事件节点（通过 EventBus 显示弹窗）
	var event_id: String = node.get("event_id", "")
	var choices: Array = node.get("choices", [])
	# 如果是 branch_choice 节点，从 next 节点生成选项
	if node.get("branch_choice", false):
		var next_nodes: Array = node.get("next", [])
		var chain: Dictionary = QuestChainData.CHAINS[chain_id]
		for next_id in next_nodes:
			var next_node: Dictionary = chain.get("nodes", {}).get(next_id, {})
			choices.append({
				"text": next_node.get("name", next_id),
				"desc": next_node.get("desc", ""),
				"node_id": next_id,
			})
	# 通过 EventBus 发送事件弹窗
	var popup_data: Dictionary = {
		"title": node.get("name", ""),
		"desc": node.get("desc", ""),
		"choices": choices,
		"source_type": "quest_chain",
		"chain_id": chain_id,
		"node_id": node_id,
	}
	EventBus.show_event_popup.emit(
		popup_data["title"],
		popup_data["desc"],
		choices
	)
	EventBus.quest_chain_event_triggered.emit(chain_id, node_id, popup_data)

func _register_node_quest(chain_id: String, node_id: String, node: Dictionary, player_id: int) -> void:
	## 将任务链节点的任务注册到 QuestJournal
	var quest_id: String = node.get("quest_id", "")
	if quest_id == "" or not QuestJournal:
		return
	# 检查 CHAIN_QUESTS 中是否有对应定义
	if QuestChainData.CHAIN_QUESTS.has(quest_id):
		var quest_def: Dictionary = QuestChainData.CHAIN_QUESTS[quest_id]
		QuestJournal.register_chain_quest(quest_id, quest_def, player_id, chain_id, node_id)
	EventBus.message_log.emit("[color=yellow][任务链] 新任务: %s[/color]" % node.get("name", quest_id))

func _apply_node_reward(chain_id: String, node_id: String, node: Dictionary, player_id: int) -> void:
	## 发放节点奖励
	var reward: Dictionary = node.get("reward", {})
	if reward.is_empty():
		return
	# 资源奖励
	var res_delta: Dictionary = {}
	for key in ["gold", "food", "iron", "prestige", "shadow_essence"]:
		if reward.has(key):
			res_delta[key] = reward[key]
	if not res_delta.is_empty() and ResourceManager:
		ResourceManager.apply_delta(player_id, res_delta)
	# 秩序/威胁变化
	if reward.has("order_delta") and OrderManager:
		OrderManager.change_order(reward["order_delta"])
	if reward.has("threat_delta") and ThreatManager:
		ThreatManager.change_threat(reward["threat_delta"])
	# 全局标记
	if reward.has("flag_set"):
		_global_flags[reward["flag_set"]] = true
		EventBus.quest_chain_flag_set.emit(reward["flag_set"])
	# 终局解锁
	if reward.get("unlock_endgame", false):
		EventBus.quest_chain_endgame_unlocked.emit(chain_id)
	# 奖励消息
	var msg: String = reward.get("message", "")
	if msg != "":
		EventBus.message_log.emit("[color=gold][任务链奖励] %s[/color]" % msg)
	EventBus.quest_chain_reward_applied.emit(chain_id, node_id, reward)

func _is_chain_quest_completed(quest_id: String, _player_id: int) -> bool:
	## 检查链内任务是否完成（通过 QuestJournal 的链任务注册表）
	if not QuestJournal:
		return false
	return QuestJournal.is_chain_quest_completed(quest_id)

# ═══════════════ 分支选择 ═══════════════
func _request_branch_choice(chain_id: String, node_id: String, _player_id: int) -> void:
	## 向玩家请求分支选择
	_pending_branch_request = {
		"chain_id": chain_id,
		"node_id": node_id,
	}
	# 事件节点会通过 _trigger_node_event 显示弹窗，此处仅记录
	# 非事件节点（如 gate 的 branch_choice）需要单独处理
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var node: Dictionary = chain.get("nodes", {}).get(node_id, {})
	if node.get("type", "quest") != "event":
		var next_nodes: Array = node.get("next", [])
		var choices: Array = []
		for next_id in next_nodes:
			var next_node: Dictionary = chain.get("nodes", {}).get(next_id, {})
			choices.append({
				"text": next_node.get("name", next_id),
				"desc": next_node.get("desc", ""),
				"node_id": next_id,
			})
		EventBus.quest_chain_branch_requested.emit(chain_id, node_id, choices)

func _on_branch_chosen(chain_id: String, parent_node_id: String, chosen_node_id: String) -> void:
	## 玩家选择了分支
	if not _chain_states.has(chain_id):
		return
	_branch_choices[chain_id][parent_node_id] = chosen_node_id
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var parent_node: Dictionary = chain.get("nodes", {}).get(parent_node_id, {})
	# 锁定互斥分支
	var next_nodes: Array = parent_node.get("next", [])
	for next_id in next_nodes:
		if next_id != chosen_node_id:
			_skip_node(chain_id, next_id)
			# 递归跳过互斥节点的后续节点
			_skip_subtree(chain_id, next_id)
	# 完成父节点（事件节点在选择后完成）
	if _node_states[chain_id].get(parent_node_id, NodeStatus.LOCKED) == NodeStatus.ACTIVE:
		_node_states[chain_id][parent_node_id] = NodeStatus.COMPLETED
	# 解锁选择的分支
	var player_id: int = GameManager.get_human_player_id() if GameManager else 0
	_unlock_node(chain_id, chosen_node_id, player_id)
	EventBus.quest_chain_branched.emit(chain_id, parent_node_id, chosen_node_id)
	var chosen_node: Dictionary = chain.get("nodes", {}).get(chosen_node_id, {})
	EventBus.message_log.emit("[color=cyan][任务链] 选择分支: %s[/color]" % chosen_node.get("name", chosen_node_id))

func _skip_subtree(chain_id: String, node_id: String) -> void:
	## 递归跳过节点及其所有后续节点
	_skip_node(chain_id, node_id)
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var node: Dictionary = chain.get("nodes", {}).get(node_id, {})
	for next_id in node.get("next", []):
		# 只跳过仍为 LOCKED 或 AVAILABLE 的节点
		var status: int = _node_states[chain_id].get(next_id, NodeStatus.LOCKED)
		if status in [NodeStatus.LOCKED, NodeStatus.AVAILABLE]:
			_skip_subtree(chain_id, next_id)

# ═══════════════ 链完成检查 ═══════════════
func _check_chain_completion(chain_id: String) -> void:
	## 检查整条链是否完成（所有终端节点均为 COMPLETED 或 SKIPPED）
	if _chain_states[chain_id].get("completed", false):
		return
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var nodes: Dictionary = chain.get("nodes", {})
	# 找出所有终端节点（next 为空的节点）
	var terminal_nodes: Array = []
	for node_id in nodes:
		if nodes[node_id].get("next", []).is_empty():
			terminal_nodes.append(node_id)
	if terminal_nodes.is_empty():
		return
	# 检查所有终端节点是否均已完成或跳过
	for node_id in terminal_nodes:
		var status: int = _node_states[chain_id].get(node_id, NodeStatus.LOCKED)
		if status not in [NodeStatus.COMPLETED, NodeStatus.SKIPPED]:
			return
	# 链完成
	_chain_states[chain_id]["completed"] = true
	_chain_states[chain_id]["active"] = false
	_active_chain_ids.erase(chain_id)
	_completed_chain_ids.append(chain_id)
	EventBus.quest_chain_completed.emit(chain_id)
	EventBus.message_log.emit("[color=gold][b][任务链完成] %s[/b][/color]" % chain.get("name", chain_id))

# ═══════════════ 公开 API ═══════════════
func get_chain_state(chain_id: String) -> Dictionary:
	return _chain_states.get(chain_id, {})

func get_node_status(chain_id: String, node_id: String) -> int:
	return _node_states.get(chain_id, {}).get(node_id, NodeStatus.LOCKED)

func get_active_chains() -> Array:
	var result: Array = []
	for chain_id in _active_chain_ids:
		var chain: Dictionary = QuestChainData.CHAINS.get(chain_id, {})
		result.append({
			"id": chain_id,
			"name": chain.get("name", chain_id),
			"desc": chain.get("desc", ""),
			"category": chain.get("category", ""),
			"nodes": _get_chain_node_summary(chain_id),
		})
	return result

func get_completed_chains() -> Array:
	return _completed_chain_ids.duplicate()

func get_all_chains_summary() -> Array:
	## 返回所有链的摘要（用于 UI 显示）
	var result: Array = []
	for chain_id in QuestChainData.CHAINS:
		var chain: Dictionary = QuestChainData.CHAINS[chain_id]
		var state: Dictionary = _chain_states.get(chain_id, {})
		result.append({
			"id": chain_id,
			"name": chain.get("name", chain_id),
			"desc": chain.get("desc", ""),
			"category": chain.get("category", ""),
			"active": state.get("active", false),
			"completed": state.get("completed", false),
			"nodes": _get_chain_node_summary(chain_id),
		})
	return result

func _get_chain_node_summary(chain_id: String) -> Array:
	## 返回链内所有节点的摘要
	var result: Array = []
	var chain: Dictionary = QuestChainData.CHAINS.get(chain_id, {})
	var nodes: Dictionary = chain.get("nodes", {})
	for node_id in nodes:
		var node: Dictionary = nodes[node_id]
		result.append({
			"id": node_id,
			"name": node.get("name", node_id),
			"type": node.get("type", "quest"),
			"status": _node_states.get(chain_id, {}).get(node_id, NodeStatus.LOCKED),
			"requires": node.get("requires", []),
			"requires_any": node.get("requires_any", []),
			"next": node.get("next", []),
			"mutually_exclusive": node.get("mutually_exclusive", []),
			"branch_choice": node.get("branch_choice", false),
		})
	return result

func get_global_flag(flag_id: String) -> bool:
	return _global_flags.get(flag_id, false)

func set_global_flag(flag_id: String, value: bool) -> void:
	_global_flags[flag_id] = value
	if value:
		EventBus.quest_chain_flag_set.emit(flag_id)

func force_complete_node(chain_id: String, node_id: String) -> void:
	## 调试用：强制完成一个节点
	var player_id: int = GameManager.get_human_player_id() if GameManager else 0
	_node_states[chain_id][node_id] = NodeStatus.ACTIVE
	_complete_node(chain_id, node_id, player_id)

func force_activate_chain(chain_id: String) -> void:
	## 调试用：强制激活一条链
	var player_id: int = GameManager.get_human_player_id() if GameManager else 0
	if not _chain_states.has(chain_id):
		return
	if not _chain_states[chain_id]["active"]:
		_activate_chain(chain_id, player_id)

# ═══════════════ 存档/读档 ═══════════════
func to_save_data() -> Dictionary:
	return {
		"chain_states": _chain_states.duplicate(true),
		"node_states": _node_states.duplicate(true),
		"global_flags": _global_flags.duplicate(true),
		"branch_choices": _branch_choices.duplicate(true),
		"active_chain_ids": _active_chain_ids.duplicate(),
		"completed_chain_ids": _completed_chain_ids.duplicate(),
	}

func from_save_data(data: Dictionary) -> void:
	_chain_states = data.get("chain_states", {}).duplicate(true)
	_node_states = data.get("node_states", {}).duplicate(true)
	_global_flags = data.get("global_flags", {}).duplicate(true)
	_branch_choices = data.get("branch_choices", {}).duplicate(true)
	_active_chain_ids = data.get("active_chain_ids", []).duplicate()
	_completed_chain_ids = data.get("completed_chain_ids", []).duplicate()
	# 修复 JSON 读档后 int 值变为 float 的问题
	for chain_id in _node_states:
		for node_id in _node_states[chain_id]:
			_node_states[chain_id][node_id] = int(_node_states[chain_id][node_id])
