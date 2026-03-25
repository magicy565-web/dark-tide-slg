## tutorial_manager.gd - Guided first-game tutorial for 暗潮 SLG (v1.5)
## Tracks tutorial state and shows contextual hints.
extends Node

signal tutorial_step_changed(step_id: String)
signal tutorial_completed()

# ── Tutorial steps ──
const STEPS: Array = [
	{
		"id": "welcome",
		"title": "欢迎来到暗潮世界",
		"text": "你将率领一个暗黑势力征服大陆。\n点击任意位置继续。",
		"trigger": "game_start",
		"highlight": "",
	},
	{
		"id": "faction_intro",
		"title": "阵营特性",
		"text": "你的阵营拥有独特机制。兽人有WAAAGH!战意，海盗靠掠夺致富，暗精灵可用奴隶祭祀。",
		"trigger": "game_start",
		"highlight": "",
	},
	{
		"id": "map_overview",
		"title": "地图导航",
		"text": "用WASD或鼠标边缘滚动地图。\n滚轮缩放。\n你的领地以阵营色标示。",
		"trigger": "board_ready",
		"highlight": "board",
	},
	{
		"id": "select_territory",
		"title": "选择领地",
		"text": "点击你拥有的领地来查看详情。\n有军团的领地会显示盾牌标志。",
		"trigger": "board_ready",
		"highlight": "board",
	},
	{
		"id": "create_army",
		"title": "创建军团",
		"text": "点击左侧「军事」按钮，在你的领地创建军团。\n每支军团最多5个编制。",
		"trigger": "first_turn",
		"highlight": "btn_attack",
	},
	{
		"id": "recruit_troops",
		"title": "招募兵种",
		"text": "点击「内政」→「招募」来补充军力。\n不同兵种有不同属性和被动技能。",
		"trigger": "first_turn",
		"highlight": "btn_domestic",
	},
	{
		"id": "attack_enemy",
		"title": "进攻敌方",
		"text": "选中己方军团后，相邻敌方领地会显示红色高亮。\n点击红色区域发动进攻。",
		"trigger": "army_created",
		"highlight": "board",
	},
	{
		"id": "combat_basics",
		"title": "战斗机制",
		"text": "战斗按速度排序轮流行动，最多12回合。\n地形影响战斗：森林利弓兵，平原利骑兵。",
		"trigger": "first_combat",
		"highlight": "",
	},
	{
		"id": "economy_basics",
		"title": "经济系统",
		"text": "每回合领地产出金币、粮草、铁矿。\n升级领地（内政→升级）可提升产出。\n注意粮食消耗！",
		"trigger": "turn_2",
		"highlight": "resource_bar",
	},
	{
		"id": "order_threat",
		"title": "秩序与威胁",
		"text": "秩序值影响产出和叛乱概率。\n威胁值越高，光明阵营越会联合对抗你。\n释放俘虏可降低威胁。",
		"trigger": "turn_3",
		"highlight": "order_threat_bar",
	},
	{
		"id": "diplomacy_intro",
		"title": "外交系统",
		"text": "点击「外交」与中立势力交涉。\n完成任务提升友好度，最终可招募他们的兵种。",
		"trigger": "turn_5",
		"highlight": "btn_diplomacy",
	},
	{
		"id": "victory_conditions",
		"title": "胜利条件",
		"text": "三种胜利路径：\n征服: 占领所有核心要塞\n支配: 控制60%+领地\n暗影统治: 威胁100+终极兵种",
		"trigger": "turn_5",
		"highlight": "",
	},
	{
		"id": "tutorial_end",
		"title": "教程完成",
		"text": "基础教程已完成！\n按ESC随时查看帮助。\n祝征途顺利！",
		"trigger": "turn_6",
		"highlight": "",
	},
]

# ── State ──
var _active: bool = false
var _current_step_index: int = 0
var _completed_steps: Array = []
var _tutorial_enabled: bool = true
var _pending_triggers: Array = []
var _turn_count: int = 0

# ── UI ──
var _popup: PanelContainer
var _title_label: Label
var _text_label: RichTextLabel
var _btn_next: Button
var _btn_skip: Button
var _overlay: ColorRect
var _step_label: Label

# ── Highlight ──
var _highlight_node: Control = null
var _highlight_tween: Tween = null


func _ready() -> void:
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	# Semi-transparent overlay
	_overlay = ColorRect.new()
	_overlay.name = "TutorialOverlay"
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.color = Color(0, 0, 0, 0.3)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Popup panel
	_popup = PanelContainer.new()
	_popup.name = "TutorialPopup"
	_popup.custom_minimum_size = Vector2(440, 200)
	_popup.anchor_left = 0.5
	_popup.anchor_top = 0.5
	_popup.anchor_right = 0.5
	_popup.anchor_bottom = 0.5
	_popup.offset_left = -220
	_popup.offset_top = -100
	_popup.offset_right = 220
	_popup.offset_bottom = 100

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	style.border_color = Color(0.6, 0.5, 0.2)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_popup.add_child(vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.custom_minimum_size = Vector2(400, 80)
	_text_label.add_theme_font_size_override("normal_font_size", 16)
	vbox.add_child(_text_label)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_btn_skip = Button.new()
	_btn_skip.text = "跳过教程"
	_btn_skip.pressed.connect(_skip_tutorial)
	btn_row.add_child(_btn_skip)

	_btn_next = Button.new()
	_btn_next.text = "继续"
	_btn_next.pressed.connect(_advance_step)
	btn_row.add_child(_btn_next)

	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 13)
	_step_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5, 0.7))
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_step_label)

	_popup.visible = false

	# Add UI nodes to the scene tree so they are actually rendered
	add_child(_overlay)
	add_child(_popup)


func _connect_signals() -> void:
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.board_ready.connect(func(): _trigger("board_ready"))
	EventBus.army_created.connect(func(_a, _b, _c): _trigger("army_created"))
	EventBus.combat_result.connect(func(_a, _b, _c): _trigger("first_combat"))


func start_tutorial() -> void:
	if not _tutorial_enabled:
		return
	_active = true
	_current_step_index = 0
	_completed_steps.clear()
	_turn_count = 0
	_trigger("game_start")


func _trigger(trigger_id: String) -> void:
	if not _active:
		return
	if _current_step_index >= STEPS.size():
		_end_tutorial()
		return

	var step: Dictionary = STEPS[_current_step_index]
	if step["trigger"] == trigger_id:
		_show_step(step)


func _show_step(step: Dictionary) -> void:
	_title_label.text = step["title"]
	_text_label.clear()
	_text_label.append_text(step["text"])
	_step_label.text = "步骤 %d/%d" % [_current_step_index + 1, STEPS.size()]
	_popup.visible = true
	_overlay.visible = true

	# Animate entrance
	_popup.modulate = Color(1, 1, 1, 0)
	var tween := _popup.create_tween()
	tween.tween_property(_popup, "modulate:a", 1.0, 0.3)

	_apply_highlight(step["highlight"])

	tutorial_step_changed.emit(step["id"])


func _advance_step() -> void:
	_completed_steps.append(STEPS[_current_step_index]["id"])
	_current_step_index += 1
	_remove_highlight()
	_popup.visible = false
	_overlay.visible = false

	if _current_step_index >= STEPS.size():
		_end_tutorial()
		return

	# Check if next step triggers immediately
	var next_step: Dictionary = STEPS[_current_step_index]
	var prev_step: Dictionary = STEPS[_current_step_index - 1]
	if next_step["trigger"] == prev_step["trigger"]:
		# Same trigger, show immediately
		_show_step(next_step)


func _skip_tutorial() -> void:
	_active = false
	_remove_highlight()
	_popup.visible = false
	_overlay.visible = false
	_tutorial_enabled = false
	EventBus.message_log.emit("教程已跳过。按ESC查看帮助。")


func _end_tutorial() -> void:
	_active = false
	_remove_highlight()
	_popup.visible = false
	_overlay.visible = false
	tutorial_completed.emit()
	EventBus.message_log.emit("[color=gold]教程完成! 祝征途顺利![/color]")


func _apply_highlight(target_name: String) -> void:
	_remove_highlight()
	if target_name.is_empty():
		return

	# Try finding the target by group first, then by name in the tree
	var target: Control = null
	var group_nodes := get_tree().get_nodes_in_group(target_name)
	if group_nodes.size() > 0 and group_nodes[0] is Control:
		target = group_nodes[0] as Control
	else:
		# Walk the scene tree to find by node name
		target = _find_control_by_name(get_tree().root, target_name)

	if target == null or not is_instance_valid(target):
		return

	# Create a highlight overlay Control
	_highlight_node = Control.new()
	_highlight_node.name = "TutorialHighlight"
	_highlight_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_node.z_index = 100

	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(0, 0, 0, 0)  # No fill
	hl_style.border_color = Color(1.0, 0.84, 0.0, 0.9)  # Gold border
	hl_style.border_width_top = 3
	hl_style.border_width_bottom = 3
	hl_style.border_width_left = 3
	hl_style.border_width_right = 3
	hl_style.corner_radius_top_left = 6
	hl_style.corner_radius_top_right = 6
	hl_style.corner_radius_bottom_left = 6
	hl_style.corner_radius_bottom_right = 6

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", hl_style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_node.add_child(panel)

	# Position over the target
	var target_rect := target.get_global_rect()
	var margin := 4.0
	_highlight_node.global_position = target_rect.position - Vector2(margin, margin)
	_highlight_node.size = target_rect.size + Vector2(margin * 2, margin * 2)
	panel.position = Vector2.ZERO
	panel.size = _highlight_node.size

	# Add to the tree above the overlay
	get_tree().root.add_child(_highlight_node)

	# Pulse animation via tween
	_highlight_node.modulate = Color(1, 1, 1, 0.9)
	_highlight_tween = _highlight_node.create_tween()
	_highlight_tween.set_loops()
	_highlight_tween.tween_property(_highlight_node, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(_highlight_node, "modulate:a", 0.9, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _remove_highlight() -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = null
	if _highlight_node and is_instance_valid(_highlight_node):
		_highlight_node.queue_free()
	_highlight_node = null


func _find_control_by_name(node: Node, node_name: String) -> Control:
	if node.name == node_name and node is Control:
		return node as Control
	for child in node.get_children():
		var result := _find_control_by_name(child, node_name)
		if result != null:
			return result
	return null


func _on_turn_started(_pid: int) -> void:
	_turn_count += 1
	if _active:
		_trigger("first_turn")
		_trigger("turn_%d" % _turn_count)


func get_popup_control() -> PanelContainer:
	return _popup

func get_overlay_control() -> ColorRect:
	return _overlay

func is_active() -> bool:
	return _active


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"active": _active,
		"current_step": _current_step_index,
		"completed_steps": _completed_steps.duplicate(),
		"tutorial_enabled": _tutorial_enabled,
		"turn_count": _turn_count,
	}

func from_save_data(data: Dictionary) -> void:
	_active = data.get("active", false)
	_current_step_index = data.get("current_step", 0)
	_completed_steps = data.get("completed_steps", []).duplicate()
	_tutorial_enabled = data.get("tutorial_enabled", true)
	_turn_count = data.get("turn_count", 0)
