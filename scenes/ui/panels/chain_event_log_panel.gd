## chain_event_log_panel.gd — 任务链事件历史日志面板 (v1.0)
## 记录并展示所有任务链节点的完成历史、分支选择和奖励发放记录。
## 快捷键: L 键切换显示/隐藏
extends CanvasLayer

# ── 日志条目结构 ──
## { "turn": int, "type": String, "chain_name": String, "node_name": String, "detail": String, "color": Color }
var _log_entries: Array = []
const MAX_LOG_ENTRIES: int = 200

# ── 状态 ──
var _visible: bool = false

# ── UI 引用 ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var filter_container: HBoxContainer
var btn_filter_all: Button
var btn_filter_active: Button
var btn_filter_completed: Button
var log_scroll: ScrollContainer
var log_container: VBoxContainer
var entry_count_label: Label

# ── 过滤器 ──
var _current_filter: String = "all"  # "all", "active", "completed"

# ═══════════════════════════════════════════════════════════════
#                          生命周期
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	layer = UILayerRegistry.LAYER_INFO_PANELS
	_build_ui()
	_connect_signals()
	_hide_panel()

func _connect_signals() -> void:
	EventBus.quest_chain_started.connect(_on_chain_started)
	EventBus.quest_chain_node_unlocked.connect(_on_node_unlocked)
	EventBus.quest_chain_node_completed.connect(_on_node_completed)
	EventBus.quest_chain_node_failed.connect(_on_node_failed)
	EventBus.quest_chain_branched.connect(_on_chain_branched)
	EventBus.quest_chain_completed.connect(_on_chain_completed)
	EventBus.quest_chain_reward_applied.connect(_on_reward_applied)
	EventBus.quest_chain_flag_set.connect(_on_flag_set)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_L:
			if _visible:
				_hide_panel()
			else:
				_show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			_hide_panel()
			get_viewport().set_input_as_handled()

# ═══════════════════════════════════════════════════════════════
#                          构建 UI
# ═══════════════════════════════════════════════════════════════
func _build_ui() -> void:
	root = Control.new()
	root.name = "ChainEventLogRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_hide_panel()
	)
	root.add_child(dim_bg)

	main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -340
	main_panel.offset_right = 340
	main_panel.offset_top = -280
	main_panel.offset_bottom = 280
	var sf := StyleBoxFlat.new()
	sf.bg_color = Color(0.07, 0.07, 0.12, 0.97)
	sf.border_color = Color(0.3, 0.5, 0.8, 0.8)
	sf.set_border_width_all(2)
	sf.set_corner_radius_all(10)
	sf.set_content_margin_all(16)
	main_panel.add_theme_stylebox_override("panel", sf)
	root.add_child(main_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	main_panel.add_child(outer_vbox)

	# 标题行
	var title_row := HBoxContainer.new()
	outer_vbox.add_child(title_row)
	header_label = Label.new()
	header_label.text = "任务链事件日志"
	header_label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	header_label.add_theme_font_size_override("font_size", 17)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(header_label)
	entry_count_label = Label.new()
	entry_count_label.text = "0 条记录"
	entry_count_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	entry_count_label.add_theme_font_size_override("font_size", 12)
	title_row.add_child(entry_count_label)
	btn_close = Button.new()
	btn_close.text = "✕"
	btn_close.custom_minimum_size = Vector2(28, 28)
	btn_close.pressed.connect(_hide_panel)
	title_row.add_child(btn_close)

	# 过滤器按钮行
	filter_container = HBoxContainer.new()
	filter_container.add_theme_constant_override("separation", 6)
	outer_vbox.add_child(filter_container)
	btn_filter_all = _make_filter_btn("全部")
	btn_filter_all.pressed.connect(func(): _set_filter("all"))
	filter_container.add_child(btn_filter_all)
	btn_filter_active = _make_filter_btn("进行中")
	btn_filter_active.pressed.connect(func(): _set_filter("active"))
	filter_container.add_child(btn_filter_active)
	btn_filter_completed = _make_filter_btn("已完成")
	btn_filter_completed.pressed.connect(func(): _set_filter("completed"))
	filter_container.add_child(btn_filter_completed)

	outer_vbox.add_child(HSeparator.new())

	# 日志滚动区域
	log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(log_scroll)

	log_container = VBoxContainer.new()
	log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_container.add_theme_constant_override("separation", 4)
	log_scroll.add_child(log_container)

	# 快捷键提示
	var hint := Label.new()
	hint.text = "[L] 切换显示"
	hint.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	hint.add_theme_font_size_override("font_size", 11)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	outer_vbox.add_child(hint)

func _make_filter_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 26)
	btn.add_theme_font_size_override("font_size", 13)
	return btn

# ═══════════════════════════════════════════════════════════════
#                          显示/隐藏
# ═══════════════════════════════════════════════════════════════
func _show_panel() -> void:
	_visible = true
	root.visible = true
	_refresh_log()

func _hide_panel() -> void:
	_visible = false
	root.visible = false

# ═══════════════════════════════════════════════════════════════
#                          过滤器
# ═══════════════════════════════════════════════════════════════
func _set_filter(filter: String) -> void:
	_current_filter = filter
	_update_filter_highlight()
	if _visible:
		_refresh_log()

func _update_filter_highlight() -> void:
	var btns: Dictionary = {
		"all": btn_filter_all,
		"active": btn_filter_active,
		"completed": btn_filter_completed,
	}
	for key in btns:
		var btn: Button = btns[key]
		if key == _current_filter:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		else:
			btn.remove_theme_color_override("font_color")

# ═══════════════════════════════════════════════════════════════
#                          日志刷新
# ═══════════════════════════════════════════════════════════════
func _refresh_log() -> void:
	for child in log_container.get_children():
		child.queue_free()

	var filtered: Array = _get_filtered_entries()
	entry_count_label.text = "%d 条记录" % filtered.size()

	if filtered.is_empty():
		var lbl := Label.new()
		lbl.text = "暂无记录"
		lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		log_container.add_child(lbl)
		return

	# 从最新到最旧显示
	var reversed_entries: Array = filtered.duplicate()
	reversed_entries.reverse()
	for entry in reversed_entries:
		_add_log_entry_widget(entry)

func _get_filtered_entries() -> Array:
	match _current_filter:
		"active":
			return _log_entries.filter(func(e): return e.get("type", "") in ["chain_started", "node_unlocked", "node_active"])
		"completed":
			return _log_entries.filter(func(e): return e.get("type", "") in ["node_completed", "chain_completed", "reward_applied"])
		_:
			return _log_entries

func _add_log_entry_widget(entry: Dictionary) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# 回合标签
	var turn_lbl := Label.new()
	turn_lbl.text = "T%d" % entry.get("turn", 0)
	turn_lbl.custom_minimum_size = Vector2(36, 0)
	turn_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	turn_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(turn_lbl)

	# 类型图标
	var type_lbl := Label.new()
	var type_icons: Dictionary = {
		"chain_started": "[开始]",
		"node_unlocked": "[解锁]",
		"node_active": "[激活]",
		"node_completed": "[完成]",
		"node_failed": "[失败]",
		"chain_branched": "[分支]",
		"chain_completed": "[链完]",
		"reward_applied": "[奖励]",
		"flag_set": "[标记]",
	}
	type_lbl.text = type_icons.get(entry.get("type", ""), "[?]")
	type_lbl.custom_minimum_size = Vector2(52, 0)
	type_lbl.add_theme_color_override("font_color", entry.get("color", Color(0.7, 0.7, 0.7)))
	type_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(type_lbl)

	# 内容
	var content_lbl := Label.new()
	var chain_name: String = entry.get("chain_name", "")
	var node_name: String = entry.get("node_name", "")
	var detail: String = entry.get("detail", "")
	var content_parts: Array = []
	if chain_name != "":
		content_parts.append("[%s]" % chain_name)
	if node_name != "":
		content_parts.append(node_name)
	if detail != "":
		content_parts.append("— " + detail)
	content_lbl.text = " ".join(content_parts)
	content_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	content_lbl.add_theme_font_size_override("font_size", 13)
	content_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(content_lbl)

	log_container.add_child(hbox)

# ═══════════════════════════════════════════════════════════════
#                          日志记录
# ═══════════════════════════════════════════════════════════════
func _add_entry(type: String, chain_id: String, node_id: String, detail: String, color: Color) -> void:
	var chain_name: String = _get_chain_name(chain_id)
	var node_name: String = _get_node_name(chain_id, node_id)
	var turn: int = GameManager.turn_number if GameManager else 0
	_log_entries.append({
		"turn": turn,
		"type": type,
		"chain_id": chain_id,
		"chain_name": chain_name,
		"node_id": node_id,
		"node_name": node_name,
		"detail": detail,
		"color": color,
	})
	# 限制最大条目数
	if _log_entries.size() > MAX_LOG_ENTRIES:
		_log_entries = _log_entries.slice(_log_entries.size() - MAX_LOG_ENTRIES)
	if _visible:
		_refresh_log()

func _get_chain_name(chain_id: String) -> String:
	if not Engine.has_singleton("QuestChainManager"):
		return chain_id
	var chains: Array = QuestChainManager.get_all_chains_summary()
	for c in chains:
		if c.get("id", "") == chain_id:
			return c.get("name", chain_id)
	return chain_id

func _get_node_name(chain_id: String, node_id: String) -> String:
	if not Engine.has_singleton("QuestChainManager"):
		return node_id
	var chains: Array = QuestChainManager.get_all_chains_summary()
	for c in chains:
		if c.get("id", "") == chain_id:
			for n in c.get("nodes", []):
				if n.get("id", "") == node_id:
					return n.get("name", node_id)
	return node_id

# ═══════════════════════════════════════════════════════════════
#                          信号处理
# ═══════════════════════════════════════════════════════════════
func _on_chain_started(chain_id: String) -> void:
	_add_entry("chain_started", chain_id, "", "任务链已激活", Color(0.4, 0.8, 1.0))

func _on_node_unlocked(chain_id: String, node_id: String) -> void:
	_add_entry("node_unlocked", chain_id, node_id, "节点已解锁", Color(0.6, 0.8, 1.0))

func _on_node_completed(chain_id: String, node_id: String) -> void:
	_add_entry("node_completed", chain_id, node_id, "节点已完成", Color(0.4, 0.9, 0.4))

func _on_node_failed(chain_id: String, node_id: String) -> void:
	_add_entry("node_failed", chain_id, node_id, "节点已失败", Color(0.9, 0.3, 0.3))

func _on_chain_branched(chain_id: String, parent_node_id: String, chosen_branch: String) -> void:
	var chosen_name: String = _get_node_name(chain_id, chosen_branch)
	_add_entry("chain_branched", chain_id, parent_node_id, "选择分支: %s" % chosen_name, Color(1.0, 0.85, 0.3))

func _on_chain_completed(chain_id: String) -> void:
	_add_entry("chain_completed", chain_id, "", "任务链已完成！", Color(1.0, 0.9, 0.2))

func _on_reward_applied(chain_id: String, node_id: String, reward: Dictionary) -> void:
	var reward_parts: Array = []
	for key in ["gold", "food", "iron", "prestige", "shadow_essence"]:
		if reward.has(key):
			var val: int = reward[key]
			if val > 0:
				reward_parts.append("+%d %s" % [val, key])
			elif val < 0:
				reward_parts.append("%d %s" % [val, key])
	var reward_str: String = ", ".join(reward_parts) if not reward_parts.is_empty() else "特殊奖励"
	_add_entry("reward_applied", chain_id, node_id, reward_str, Color(1.0, 0.75, 0.2))

func _on_flag_set(flag_id: String) -> void:
	_add_entry("flag_set", "", "", "全局标记设置: %s" % flag_id, Color(0.7, 0.5, 0.9))

# ═══════════════════════════════════════════════════════════════
#                          存档/读档
# ═══════════════════════════════════════════════════════════════
func to_save_data() -> Dictionary:
	# 只保存最近 50 条
	var recent: Array = _log_entries.slice(max(0, _log_entries.size() - 50))
	# Color 不能直接序列化，转为 Array
	var serialized: Array = []
	for entry in recent:
		var e: Dictionary = entry.duplicate()
		var c: Color = e.get("color", Color.WHITE)
		e["color"] = [c.r, c.g, c.b, c.a]
		serialized.append(e)
	return {"log_entries": serialized}

func from_save_data(data: Dictionary) -> void:
	_log_entries.clear()
	for entry in data.get("log_entries", []):
		var e: Dictionary = entry.duplicate()
		var c_arr = e.get("color", [0.7, 0.7, 0.7, 1.0])
		if c_arr is Array and c_arr.size() >= 3:
			e["color"] = Color(c_arr[0], c_arr[1], c_arr[2], c_arr[3] if c_arr.size() > 3 else 1.0)
		else:
			e["color"] = Color(0.7, 0.7, 0.7)
		_log_entries.append(e)
