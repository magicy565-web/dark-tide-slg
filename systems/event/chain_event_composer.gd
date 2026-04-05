## chain_event_composer.gd — 事件组合器 (v1.0)
## Autoload 单例。提供复杂事件逻辑的组合与编排能力。
##
## 核心功能:
##   1. 条件门（Condition Gates）: 支持 AND/OR/NOT 逻辑表达式
##   2. 全局变量标记（Global Flags）: 跨回合、跨事件的状态追踪
##   3. 事件序列（Event Sequences）: 定义多步骤事件流程
##   4. 延迟触发（Delayed Triggers）: 在指定回合后触发后续事件
##   5. 条件效果（Conditional Effects）: 根据标记状态应用不同效果
##   6. 事件监听器（Event Listeners）: 监听游戏事件并触发响应
extends Node

# ═══════════════ 状态存储 ═══════════════
## 全局事件标记: flag_id -> value (bool/int/String)
var _event_flags: Dictionary = {}
## 延迟事件队列: [{ "event_id": String, "trigger_turn": int, "data": Dictionary }]
var _delayed_events: Array = []
## 事件序列状态: sequence_id -> { "step": int, "active": bool, "data": Dictionary }
var _sequence_states: Dictionary = {}
## 事件监听器: event_signal_name -> [{ "condition": Callable, "handler": Callable }]
var _listeners: Dictionary = {}
## 已触发的一次性序列 ID
var _triggered_sequences: Dictionary = {}
## 条件效果规则: rule_id -> { "condition": Dictionary, "effects": Dictionary }
var _conditional_rules: Array = []

# ═══════════════ 生命周期 ═══════════════
func _ready() -> void:
	_register_default_listeners()
	_register_conditional_rules()
	if EventBus:
		EventBus.turn_started.connect(_on_turn_started)
		EventBus.event_choice_made.connect(_on_event_choice_made)
		EventBus.quest_chain_flag_set.connect(_on_chain_flag_set)

func reset() -> void:
	_event_flags.clear()
	_delayed_events.clear()
	_sequence_states.clear()
	_triggered_sequences.clear()
	_conditional_rules.clear()
	_register_conditional_rules()

# ═══════════════ 每回合驱动 ═══════════════
func _on_turn_started(_player_id: int) -> void:
	_process_delayed_events()
	_evaluate_conditional_rules()

func _process_delayed_events() -> void:
	## 处理到期的延迟事件
	var current_turn: int = GameManager.turn_number if GameManager else 0
	var to_fire: Array = []
	var remaining: Array = []
	for entry in _delayed_events:
		if current_turn >= entry.get("trigger_turn", 0):
			to_fire.append(entry)
		else:
			remaining.append(entry)
	_delayed_events = remaining
	for entry in to_fire:
		_fire_delayed_event(entry)

func _fire_delayed_event(entry: Dictionary) -> void:
	## 触发一个延迟事件
	var event_id: String = entry.get("event_id", "")
	var data: Dictionary = entry.get("data", {})
	# 检查条件
	var condition: Dictionary = entry.get("condition", {})
	if not condition.is_empty():
		var player_id: int = GameManager.get_human_player_id() if GameManager else 0
		if not evaluate_condition(condition, player_id):
			return
	# 通过 EventScheduler 提交
	if EventScheduler:
		EventScheduler.submit_candidate(
			event_id,
			"chain_composer",
			EventScheduler.PRIORITY_HIGH,
			1.5,
			data
		)
	EventBus.message_log.emit("[color=cyan][事件组合器] 延迟事件触发: %s[/color]" % event_id)

# ═══════════════ 条件门系统 ═══════════════
func evaluate_condition(condition: Dictionary, player_id: int) -> bool:
	## 评估一个条件字典（支持 AND/OR/NOT 嵌套）
	if condition.is_empty():
		return true
	# 处理逻辑运算符
	if condition.has("AND"):
		for sub_cond in condition["AND"]:
			if not evaluate_condition(sub_cond, player_id):
				return false
		return true
	if condition.has("OR"):
		for sub_cond in condition["OR"]:
			if evaluate_condition(sub_cond, player_id):
				return true
		return false
	if condition.has("NOT"):
		return not evaluate_condition(condition["NOT"], player_id)
	# 处理原子条件
	return _evaluate_atomic_condition(condition, player_id)

func _evaluate_atomic_condition(condition: Dictionary, player_id: int) -> bool:
	## 评估原子条件（单个键值对）
	for key in condition:
		match key:
			# 资源条件
			"gold_min":
				if ResourceManager and ResourceManager.get_resource(player_id, "gold") < condition[key]:
					return false
			"gold_max":
				if ResourceManager and ResourceManager.get_resource(player_id, "gold") > condition[key]:
					return false
			"food_min":
				if ResourceManager and ResourceManager.get_resource(player_id, "food") < condition[key]:
					return false
			"iron_min":
				if ResourceManager and ResourceManager.get_resource(player_id, "iron") < condition[key]:
					return false
			"prestige_min":
				if ResourceManager and ResourceManager.get_resource(player_id, "prestige") < condition[key]:
					return false
			"shadow_essence_min":
				if ResourceManager and ResourceManager.get_resource(player_id, "shadow_essence") < condition[key]:
					return false
			# 游戏状态条件
			"turn_min":
				if GameManager and GameManager.turn_number < condition[key]:
					return false
			"turn_max":
				if GameManager and GameManager.turn_number > condition[key]:
					return false
			"tiles_min":
				if GameManager and GameManager.count_tiles_owned(player_id) < condition[key]:
					return false
			"threat_min":
				if ThreatManager and ThreatManager.get_threat() < condition[key]:
					return false
			"threat_max":
				if ThreatManager and ThreatManager.get_threat() > condition[key]:
					return false
			"order_min":
				if OrderManager and OrderManager.get_order() < condition[key]:
					return false
			"order_max":
				if OrderManager and OrderManager.get_order() > condition[key]:
					return false
			"heroes_min":
				if HeroSystem and HeroSystem.recruited_heroes.size() < condition[key]:
					return false
			"battles_won_min":
				if QuestJournal:
					var stats: Dictionary = QuestJournal.get_stats()
					if stats.get("battles_won", 0) < condition[key]:
						return false
			# 任务条件
			"quest_completed":
				if QuestJournal:
					var q: Dictionary = QuestJournal.get_quest_by_id(condition[key])
					if q.get("status", -1) != preload("res://systems/quest/quest_definitions.gd").QuestStatus.COMPLETED:
						return false
			# 标记条件
			"flag_set":
				if not get_flag(condition[key]):
					return false
			"flag_not_set":
				if get_flag(condition[key]):
					return false
			"flag_value_min":
				var flag_data: Dictionary = condition[key]
				var flag_val = get_flag_value(flag_data.get("flag", ""))
				if not (flag_val is int or flag_val is float):
					return false
				if flag_val < flag_data.get("min", 0):
					return false
			# 链标记条件
			"chain_flag_set":
				if QuestChainManager:
					if not QuestChainManager.get_global_flag(condition[key]):
						return false
			"chain_completed":
				if QuestChainManager:
					if condition[key] not in QuestChainManager.get_completed_chains():
						return false
			# 随机条件
			"random_chance":
				if randf() > condition[key]:
					return false
	return true

# ═══════════════ 全局标记系统 ═══════════════
func set_flag(flag_id: String, value: Variant = true) -> void:
	## 设置一个全局事件标记
	var old_value = _event_flags.get(flag_id, null)
	_event_flags[flag_id] = value
	if old_value != value:
		EventBus.chain_event_flag_changed.emit(flag_id, value)
		# 触发监听该标记的监听器
		_notify_listeners("flag_changed:" + flag_id, {"flag_id": flag_id, "value": value})

func get_flag(flag_id: String) -> bool:
	## 获取一个布尔标记的值
	var val = _event_flags.get(flag_id, false)
	if val is bool:
		return val
	return bool(val)

func get_flag_value(flag_id: String) -> Variant:
	## 获取标记的原始值
	return _event_flags.get(flag_id, null)

func increment_flag(flag_id: String, amount: int = 1) -> void:
	## 递增一个整数标记
	var current = _event_flags.get(flag_id, 0)
	if not (current is int or current is float):
		current = 0
	set_flag(flag_id, int(current) + amount)

func clear_flag(flag_id: String) -> void:
	## 清除一个标记
	_event_flags.erase(flag_id)

func get_all_flags() -> Dictionary:
	return _event_flags.duplicate()

# ═══════════════ 延迟触发系统 ═══════════════
func schedule_event(event_id: String, delay_turns: int, data: Dictionary = {}, condition: Dictionary = {}) -> void:
	## 在 delay_turns 回合后触发一个事件
	var current_turn: int = GameManager.turn_number if GameManager else 0
	_delayed_events.append({
		"event_id": event_id,
		"trigger_turn": current_turn + delay_turns,
		"data": data.duplicate(true),
		"condition": condition.duplicate(true),
	})

func cancel_scheduled_event(event_id: String) -> void:
	## 取消一个已调度的延迟事件
	_delayed_events = _delayed_events.filter(func(e): return e.get("event_id", "") != event_id)

func get_scheduled_events() -> Array:
	return _delayed_events.duplicate(true)

# ═══════════════ 事件序列系统 ═══════════════
func start_sequence(sequence_id: String, sequence_def: Dictionary) -> void:
	## 开始一个事件序列
	if _triggered_sequences.get(sequence_id, false) and not sequence_def.get("repeatable", false):
		return
	_sequence_states[sequence_id] = {
		"step": 0,
		"active": true,
		"data": sequence_def.duplicate(true),
		"context": {},
	}
	_triggered_sequences[sequence_id] = true
	_advance_sequence(sequence_id)

func _advance_sequence(sequence_id: String) -> void:
	## 推进序列到下一步
	if not _sequence_states.has(sequence_id):
		return
	var state: Dictionary = _sequence_states[sequence_id]
	if not state.get("active", false):
		return
	var steps: Array = state["data"].get("steps", [])
	var step_idx: int = state["step"]
	if step_idx >= steps.size():
		# 序列完成
		state["active"] = false
		EventBus.chain_event_sequence_completed.emit(sequence_id)
		return
	var step: Dictionary = steps[step_idx]
	_execute_sequence_step(sequence_id, step)

func _execute_sequence_step(sequence_id: String, step: Dictionary) -> void:
	## 执行序列中的一个步骤
	var step_type: String = step.get("type", "event")
	match step_type:
		"event":
			# 触发一个事件弹窗
			var title: String = step.get("title", "")
			var desc: String = step.get("desc", "")
			var choices: Array = step.get("choices", [])
			EventBus.show_event_popup.emit(title, desc, choices)
		"flag":
			# 设置一个标记
			set_flag(step.get("flag_id", ""), step.get("value", true))
			_on_sequence_step_done(sequence_id)
		"delay":
			# 延迟后继续
			var delay: int = step.get("turns", 1)
			schedule_event("__seq_%s_continue" % sequence_id, delay, {"sequence_id": sequence_id})
		"effect":
			# 应用效果
			var player_id: int = GameManager.get_human_player_id() if GameManager else 0
			var effects: Dictionary = step.get("effects", {})
			if EffectResolver:
				EffectResolver.resolve(effects, {"player_id": player_id, "source": "sequence"})
			_on_sequence_step_done(sequence_id)
		"message":
			# 显示消息
			EventBus.message_log.emit(step.get("text", ""))
			_on_sequence_step_done(sequence_id)

func _on_sequence_step_done(sequence_id: String) -> void:
	## 序列步骤完成，推进到下一步
	if not _sequence_states.has(sequence_id):
		return
	_sequence_states[sequence_id]["step"] += 1
	_advance_sequence(sequence_id)

# ═══════════════ 条件效果规则 ═══════════════
func _register_conditional_rules() -> void:
	## 注册全局条件效果规则（每回合自动评估）
	# 规则1: 叛乱被镇压后，秩序每回合额外+2（持续5回合）
	_conditional_rules.append({
		"id": "rebellion_suppressed_bonus",
		"condition": {"flag_set": "rebellion_suppressed"},
		"effect_type": "per_turn_bonus",
		"effects": {"order": 2},
		"duration": 5,
		"remaining": 5,
	})
	# 规则2: 海盗同盟建立后，每回合额外+30金
	_conditional_rules.append({
		"id": "pirate_alliance_income",
		"condition": {"flag_set": "pirate_allied"},
		"effect_type": "per_turn_bonus",
		"effects": {"gold": 30},
		"duration": -1,  # 永久
		"remaining": -1,
	})
	# 规则3: 古老诅咒破解后，威胁值每回合-1（持续10回合）
	_conditional_rules.append({
		"id": "curse_broken_threat_reduction",
		"condition": {"flag_set": "ancient_curse_broken"},
		"effect_type": "per_turn_bonus",
		"effects": {"threat": -1},
		"duration": 10,
		"remaining": 10,
	})
	# 规则4: 暗影精英成就后，暗影精华产出+1/回合
	_conditional_rules.append({
		"id": "shadow_elite_essence_bonus",
		"condition": {"flag_set": "shadow_elite_achieved"},
		"effect_type": "per_turn_bonus",
		"effects": {"shadow_essence": 1},
		"duration": -1,
		"remaining": -1,
	})

func _evaluate_conditional_rules() -> void:
	## 每回合评估所有条件效果规则
	var player_id: int = GameManager.get_human_player_id() if GameManager else 0
	for rule in _conditional_rules:
		if rule.get("remaining", 0) == 0:
			continue
		var condition: Dictionary = rule.get("condition", {})
		if not evaluate_condition(condition, player_id):
			continue
		# 应用效果
		var effects: Dictionary = rule.get("effects", {})
		if not effects.is_empty() and ResourceManager:
			var res_delta: Dictionary = {}
			for key in ["gold", "food", "iron", "prestige", "shadow_essence"]:
				if effects.has(key):
					res_delta[key] = effects[key]
			if not res_delta.is_empty():
				ResourceManager.apply_delta(player_id, res_delta)
			if effects.has("order") and OrderManager:
				OrderManager.change_order(effects["order"])
			if effects.has("threat") and ThreatManager:
				ThreatManager.change_threat(effects["threat"])
		# 减少持续时间
		if rule["remaining"] > 0:
			rule["remaining"] -= 1

# ═══════════════ 事件监听器 ═══════════════
func _register_default_listeners() -> void:
	## 注册默认的事件监听器
	# 监听战斗胜利，递增计数器
	if EventBus.has_signal("combat_result"):
		EventBus.combat_result.connect(_on_combat_result_for_flags)
	# 监听领地占领，检查链条件
	if EventBus.has_signal("tile_captured"):
		EventBus.tile_captured.connect(_on_tile_captured_for_flags)

func _on_combat_result_for_flags(attacker_id: int, _desc: String, won: bool) -> void:
	if not GameManager:
		return
	var player_id: int = GameManager.get_human_player_id()
	if attacker_id == player_id and won:
		increment_flag("total_battles_won")

func _on_tile_captured_for_flags(player_id: int, _tile_index: int) -> void:
	if not GameManager:
		return
	if player_id == GameManager.get_human_player_id():
		increment_flag("total_tiles_captured")

func _on_event_choice_made(event_id: String, choice_index: int) -> void:
	## 记录事件选择历史
	set_flag("event_choice_%s" % event_id, choice_index)

func _on_chain_flag_set(flag_id: String) -> void:
	## 同步链标记到事件标记系统
	set_flag("chain_" + flag_id, true)

func _notify_listeners(event_name: String, data: Dictionary) -> void:
	## 通知监听特定事件的监听器
	if not _listeners.has(event_name):
		return
	for listener in _listeners[event_name]:
		var condition: Callable = listener.get("condition", Callable())
		if condition.is_valid() and not condition.call(data):
			continue
		var handler: Callable = listener.get("handler", Callable())
		if handler.is_valid():
			handler.call(data)

func add_listener(event_name: String, handler: Callable, condition: Callable = Callable()) -> void:
	## 添加一个事件监听器
	if not _listeners.has(event_name):
		_listeners[event_name] = []
	_listeners[event_name].append({
		"handler": handler,
		"condition": condition,
	})

# ═══════════════ 复合效果 API ═══════════════
func apply_composite_effect(effects: Dictionary, context: Dictionary = {}) -> void:
	## 应用一个复合效果（支持条件分支）
	var player_id: int = context.get("player_id", GameManager.get_human_player_id() if GameManager else 0)
	# 条件效果
	if effects.has("if"):
		var if_block: Dictionary = effects["if"]
		var condition: Dictionary = if_block.get("condition", {})
		if evaluate_condition(condition, player_id):
			apply_composite_effect(if_block.get("then", {}), context)
		elif if_block.has("else"):
			apply_composite_effect(if_block["else"], context)
		return
	# 标记效果
	if effects.has("set_flag"):
		set_flag(effects["set_flag"], effects.get("flag_value", true))
	if effects.has("increment_flag"):
		increment_flag(effects["increment_flag"])
	# 延迟事件
	if effects.has("schedule_event"):
		var sched: Dictionary = effects["schedule_event"]
		schedule_event(
			sched.get("event_id", ""),
			sched.get("delay", 1),
			sched.get("data", {}),
			sched.get("condition", {})
		)
	# 序列触发
	if effects.has("start_sequence"):
		var seq_id: String = effects["start_sequence"]
		if BUILTIN_SEQUENCES.has(seq_id):
			start_sequence(seq_id, BUILTIN_SEQUENCES[seq_id])
	# 通过 EffectResolver 处理标准效果
	if EffectResolver:
		EffectResolver.resolve(effects, context)

# ═══════════════ 内置事件序列 ═══════════════
const BUILTIN_SEQUENCES: Dictionary = {
	"rebellion_aftermath_sequence": {
		"name": "叛乱余波",
		"repeatable": false,
		"steps": [
			{
				"type": "message",
				"text": "[color=yellow][事件序列] 叛乱的余波开始显现……[/color]",
			},
			{
				"type": "delay",
				"turns": 2,
			},
			{
				"type": "event",
				"title": "叛乱余波",
				"desc": "叛乱虽已平息，但遗留问题仍需处理。民众的情绪依然不稳定。",
				"choices": [
					{"text": "颁布安抚令 (-50金, 秩序+10)", "effects": {"gold": -50, "order": 10}},
					{"text": "加强巡逻 (威胁+5, 秩序+5)", "effects": {"threat": 5, "order": 5}},
				],
			},
		],
	},
	"shadow_corruption_sequence": {
		"name": "暗影腐化进程",
		"repeatable": false,
		"steps": [
			{
				"type": "flag",
				"flag_id": "shadow_corruption_started",
				"value": true,
			},
			{
				"type": "message",
				"text": "[color=purple][事件序列] 暗影腐化的力量开始在英雄身上蔓延……[/color]",
			},
			{
				"type": "delay",
				"turns": 3,
			},
			{
				"type": "event",
				"title": "腐化深化",
				"desc": "暗影力量的腐化已经深入骨髓，英雄的眼神变得更加冷酷。",
				"choices": [
					{"text": "接受腐化 (暗影精华+10, 威胁+10)", "effects": {"shadow_essence": 10, "threat": 10}},
					{"text": "抵抗腐化 (秩序+5, 暗影精华-5)", "effects": {"order": 5, "shadow_essence": -5}},
				],
			},
		],
	},
}

# ═══════════════ 存档/读档 ═══════════════
func to_save_data() -> Dictionary:
	return {
		"event_flags": _event_flags.duplicate(true),
		"delayed_events": _delayed_events.duplicate(true),
		"sequence_states": _sequence_states.duplicate(true),
		"triggered_sequences": _triggered_sequences.duplicate(true),
		"conditional_rules": _conditional_rules.duplicate(true),
	}

func from_save_data(data: Dictionary) -> void:
	_event_flags = data.get("event_flags", {}).duplicate(true)
	_delayed_events = data.get("delayed_events", []).duplicate(true)
	_sequence_states = data.get("sequence_states", {}).duplicate(true)
	_triggered_sequences = data.get("triggered_sequences", {}).duplicate(true)
	_conditional_rules = data.get("conditional_rules", []).duplicate(true)
