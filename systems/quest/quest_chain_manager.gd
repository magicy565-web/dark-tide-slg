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
## BUG FIX: 节点激活回合记录: chain_id -> { node_id -> activated_turn }
var _node_activated_turns: Dictionary = {}

# ═══════════════ 生命周期 ═══════════════
func _ready() -> void:
	_init_all_chains()
	if EventBus:
		EventBus.turn_started.connect(_on_turn_started)
		EventBus.quest_chain_branch_chosen.connect(_on_branch_chosen)
		# v12.0: 连接 event_choice_made 信号，将 event_popup 的选择结果路由回任务链
		if EventBus.has_signal("event_choice_made"):
			EventBus.event_choice_made.connect(_on_event_choice_made)

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
		_node_activated_turns[chain_id] = {}  # BUG FIX: init time-limit tracking
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
			# BUG FIX: 先检查时限，再检查完成
			_check_node_time_limit(chain_id, node_id, player_id)
			if _node_states[chain_id].get(node_id, NodeStatus.LOCKED) == NodeStatus.ACTIVE:
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
	# BUG FIX: record activation turn for time-limit tracking
	if not _node_activated_turns.has(chain_id):
		_node_activated_turns[chain_id] = {}
	_node_activated_turns[chain_id][node_id] = GameManager.turn_number if GameManager else 0
	# BUG FIX: emit node_activated signal for UI tracking
	EventBus.quest_chain_node_activated.emit(chain_id, node_id)
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
			# BUG FIX: 处理 gate_type = parallel_join
			var gate_type: String = node.get("gate_type", "condition")
			var gate_passed: bool = false
			if gate_type == "parallel_join":
				gate_passed = _check_parallel_join(chain_id, node_id)
			else:
				var condition: Dictionary = node.get("condition", {})
				gate_passed = _check_gate_condition(condition, chain_id, player_id)
			if gate_passed:
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
			"turn_min":
				if GameManager and GameManager.turn_number < condition[key]:
					return false
			"tiles_min":
				if GameManager and GameManager.count_tiles_owned(player_id) < condition[key]:
					return false
			"gold_min":
				if ResourceManager and ResourceManager.get_resource(player_id, "gold") < condition[key]:
					return false
	return true


func _check_parallel_join(chain_id: String, node_id: String) -> bool:
	## BUG FIX: 检查 parallel_join gate 节点的并行组是否全部完成
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var node: Dictionary = chain.get("nodes", {}).get(node_id, {})
	var group_id: String = node.get("parallel_group", "")
	if group_id == "":
		# 没有并行组标记，回退到普通 requires 检查
		return _can_unlock_node(chain_id, node_id)
	# 找到属于该并行组的所有节点
	var group_nodes: Array = []
	var all_nodes: Dictionary = chain.get("nodes", {})
	for nid in all_nodes:
		if all_nodes[nid].get("parallel_group", "") == group_id and nid != node_id:
			group_nodes.append(nid)
	# 检查并行组内所有非门节点是否均已完成
	for nid in group_nodes:
		var st: int = _node_states[chain_id].get(nid, NodeStatus.LOCKED)
		if st not in [NodeStatus.COMPLETED, NodeStatus.SKIPPED]:
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
				# v12.0 FIX: 使用公开 API has_triggered() 代替直接访问私有变量 _triggered_ids
				var _et_id: String = trigger[key]
				var _et_fired: bool = false
				if EventSystem:
					if EventSystem.has_method("has_triggered"):
						_et_fired = EventSystem.has_triggered(_et_id)
					elif "_triggered_ids" in EventSystem:
						_et_fired = EventSystem._triggered_ids.has(_et_id)
				if not _et_fired:
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
	# v12.0 FIX: 通过 show_event_popup_with_source 传递完整的 event_id + source_type
	# event_id 格式为 "chain_id::node_id"，使 event_popup 能正确发射 event_choice_made
	# 从而让 _on_event_choice_made 路由回 _on_branch_chosen
	var composite_event_id: String = "%s::%s" % [chain_id, node_id]
	var popup_data: Dictionary = {
		"title": node.get("name", ""),
		"desc": node.get("desc", ""),
		"choices": choices,
		"source_type": "quest_chain",
		"chain_id": chain_id,
		"node_id": node_id,
		"event_id": composite_event_id,
	}
	# 优先使用带 source_type + event_id 的信号路径
	if EventBus.has_signal("show_event_popup_full"):
		EventBus.show_event_popup_full.emit(
			popup_data["title"],
			popup_data["desc"],
			choices,
			composite_event_id,
			"quest_chain"
		)
	elif EventBus.has_signal("show_event_popup_with_source"):
		EventBus.show_event_popup_with_source.emit(
			popup_data["title"],
			popup_data["desc"],
			choices,
			"quest_chain"
		)
	else:
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
	## 发放节点奖励 (v12.0 扩展: soldiers/buff/hero_exp/hero_recruit/unlock_skill)
	var reward: Dictionary = node.get("reward", {})
	if reward.is_empty():
		return
	# 资源奖励（扩展支持全部资源键）
	var res_delta: Dictionary = {}
	for key in ["gold", "food", "iron", "prestige", "shadow_essence",
				"magic_crystal", "gunpowder", "war_horse", "slaves", "mana"]:
		if reward.has(key):
			res_delta[key] = reward[key]
	if not res_delta.is_empty() and ResourceManager:
		ResourceManager.apply_delta(player_id, res_delta)
	# 兵力奖励
	if reward.has("soldiers") and ResourceManager:
		var sol_val: int = int(reward["soldiers"])
		if sol_val > 0:
			ResourceManager.add_army(player_id, sol_val)
			EventBus.message_log.emit("[color=#88ff88][任务链奖励] 兵力 +%d[/color]" % sol_val)
		elif sol_val < 0:
			ResourceManager.remove_army(player_id, -sol_val)
	# Buff 奖励
	if reward.has("buff") and BuffManager:
		var buff: Dictionary = reward["buff"]
		var buff_id: String = "chain_%s_%s" % [chain_id, buff.get("type", "bonus")]
		BuffManager.add_buff(player_id, buff_id, buff.get("type", "atk_pct"),
			buff.get("value", 0), buff.get("duration", 3), "quest_chain")
		EventBus.message_log.emit("[color=#aaffcc][任务链奖励] Buff: %s +%d (%d回合)[/color]" % [
			buff.get("type", ""), buff.get("value", 0), buff.get("duration", 3)])
	# 英雄经验奖励
	if reward.has("hero_exp") and HeroSystem:
		var exp_map: Dictionary = reward["hero_exp"]  # {hero_id: exp_amount}
		for hid in exp_map:
			if HeroSystem.has_method("add_hero_exp"):
				HeroSystem.add_hero_exp(hid, int(exp_map[hid]))
				EventBus.message_log.emit("[color=#ffcc44][任务链奖励] %s 获得经验 +%d[/color]" % [hid, int(exp_map[hid])])
	# 英雄招募奖励
	if reward.has("hero_recruit") and HeroSystem:
		var recruit_id: String = str(reward["hero_recruit"])
		if recruit_id != "" and HeroSystem.has_method("recruit_hero"):
			HeroSystem.recruit_hero(recruit_id, player_id)
			EventBus.message_log.emit("[color=gold][任务链奖励] 英雄加入: %s[/color]" % recruit_id)
	# 技能解锁奖励
	if reward.has("unlock_skill"):
		var skill_id: String = str(reward["unlock_skill"])
		set_global_flag("skill_unlocked_%s" % skill_id, true)
		EventBus.message_log.emit("[color=#44ffcc][任务链奖励] 解锁技能: %s[/color]" % skill_id)
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
	# BUG FIX B1: unlock_content → CGManager.unlock_cg
	# 任务链奖励节点中的 unlock_content 字段用于解锁 CG 或特殊内容
	var unlock_id: String = reward.get("unlock_content", "")
	if unlock_id != "":
		if CGManager != null:
			# 尝试推断 hero_id：若 unlock_id 含下划线且前缀匹配已知英雄，则提取
			var inferred_hero: String = ""
			for hero_key in ["rin", "yukino", "momiji", "hyouka", "suirei",
							"gekka", "hakagure", "sou", "shion", "homura",
							"shion_pirate", "youya", "hibiki", "sara",
							"mei", "kaede", "akane", "hanabi"]:
				if unlock_id.begins_with(hero_key + "_"):
					inferred_hero = hero_key
					break
			CGManager.unlock_cg(unlock_id, inferred_hero)
			EventBus.message_log.emit("[color=#ffaaff][任务链] 解锁内容: %s[/color]" % unlock_id)
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

func _on_event_choice_made(event_id: String, choice_index: int) -> void:
	## v12.0: 处理来自 event_popup 的选择结果
	## event_id 格式为 "chain_id::node_id"，解析后路由到对应的分支选择
	if "::" not in event_id:
		return
	var parts: Array = event_id.split("::", false, 1)
	if parts.size() != 2:
		return
	var chain_id: String = parts[0]
	var node_id: String = parts[1]
	if not _chain_states.has(chain_id):
		return
	var chain: Dictionary = QuestChainData.CHAINS.get(chain_id, {})
	var node: Dictionary = chain.get("nodes", {}).get(node_id, {})
	if node.is_empty():
		return
	# 如果是 branch_choice 节点，将 choice_index 转换为对应的 next_node_id
	if node.get("branch_choice", false):
		var next_nodes: Array = node.get("next", [])
		if choice_index >= 0 and choice_index < next_nodes.size():
			var chosen_id: String = next_nodes[choice_index]
			_on_branch_chosen(chain_id, node_id, chosen_id)
			return
	# 非分支节点：应用对应选项的效果并完成节点
	var choices: Array = node.get("choices", [])
	if choice_index >= 0 and choice_index < choices.size():
		var choice_effects: Dictionary = choices[choice_index].get("effects", {})
		if not choice_effects.is_empty():
			var pid: int = GameManager.get_human_player_id() if GameManager else 0
			if EffectResolver:
				EffectResolver.resolve(choice_effects, {"player_id": pid, "source": "quest_chain", "event_id": event_id})
			else:
				_apply_choice_effects_fallback(choice_effects, pid)
	var player_id: int = GameManager.get_human_player_id() if GameManager else 0
	if _node_states.get(chain_id, {}).get(node_id, NodeStatus.LOCKED) == NodeStatus.ACTIVE:
		_complete_node(chain_id, node_id, player_id)


func _apply_choice_effects_fallback(effects: Dictionary, player_id: int) -> void:
	## 无 EffectResolver 时的效果回退处理
	var res_delta: Dictionary = {}
	for key in ["gold", "food", "iron", "prestige", "shadow_essence"]:
		if effects.has(key):
			res_delta[key] = effects[key]
	if not res_delta.is_empty() and ResourceManager:
		ResourceManager.apply_delta(player_id, res_delta)
	if effects.has("order") and OrderManager:
		OrderManager.change_order(effects["order"])
	if effects.has("threat") and ThreatManager:
		ThreatManager.change_threat(effects["threat"])


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

# ═══════════════ 节点时限检查 ═══════════════
func _check_node_time_limit(chain_id: String, node_id: String, player_id: int) -> void:
	## BUG FIX: 检查 ACTIVE 节点是否超过 time_limit_turns，超时则触发 fail_node
	var chain: Dictionary = QuestChainData.CHAINS[chain_id]
	var node: Dictionary = chain.get("nodes", {}).get(node_id, {})
	var time_limit: int = node.get("time_limit_turns", -1)
	if time_limit <= 0:
		return  # 该节点没有时限
	var activated_turn: int = _node_activated_turns.get(chain_id, {}).get(node_id, -1)
	if activated_turn < 0:
		return  # 未记录激活回合，跳过
	var current_turn: int = GameManager.turn_number if GameManager else 0
	var elapsed: int = current_turn - activated_turn
	if elapsed < time_limit:
		return  # 还在时限内
	# 超时处理
	var fail_node_id: String = node.get("fail_node", "")
	EventBus.message_log.emit("[color=red][任务链超时] %s — 节点 %s 超时（已用 %d 回合，限 %d）[/color]" % [
		chain.get("name", chain_id), node.get("name", node_id), elapsed, time_limit])
	_fail_node(chain_id, node_id)
	# 如果有 fail_node，解锁失败跳转节点
	if fail_node_id != "" and chain.get("nodes", {}).has(fail_node_id):
		_unlock_node(chain_id, fail_node_id, player_id)
		_activate_node(chain_id, fail_node_id, player_id)
		EventBus.message_log.emit("[color=orange][任务链] 进入失败分支: %s[/color]" % 
			chain.get("nodes", {}).get(fail_node_id, {}).get("name", fail_node_id))
	# 发射 chain_failed 信号
	EventBus.quest_chain_failed.emit(chain_id, "节点 %s 超时" % node.get("name", node_id))


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
		# BUG FIX: 保存节点激活回合，用于时限恢复
		"node_activated_turns": _node_activated_turns.duplicate(true),
	}

func from_save_data(data: Dictionary) -> void:
	_chain_states = data.get("chain_states", {}).duplicate(true)
	_node_states = data.get("node_states", {}).duplicate(true)
	_global_flags = data.get("global_flags", {}).duplicate(true)
	_branch_choices = data.get("branch_choices", {}).duplicate(true)
	_active_chain_ids = data.get("active_chain_ids", []).duplicate()
	_completed_chain_ids = data.get("completed_chain_ids", []).duplicate()
	# BUG FIX: 恢复节点激活回合
	_node_activated_turns = data.get("node_activated_turns", {}).duplicate(true)
	# 修复 JSON 读档后 int 值变为 float 的问题
	for chain_id in _node_states:
		for node_id in _node_states[chain_id]:
			_node_states[chain_id][node_id] = int(_node_states[chain_id][node_id])
	# 修复激活回合的 int 类型
	for chain_id in _node_activated_turns:
		for node_id in _node_activated_turns[chain_id]:
			_node_activated_turns[chain_id][node_id] = int(_node_activated_turns[chain_id][node_id])
