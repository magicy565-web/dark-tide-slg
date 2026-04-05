## quest_chain_branch_dialog.gd — 任务链分支选择弹窗 (v1.0)
## 当任务链遇到 branch_choice 节点时，弹出此对话框让玩家选择分支方向。
## 与 EventBus.quest_chain_branch_requested 信号绑定。
extends CanvasLayer

# ── 状态 ──
var _visible: bool = false
var _current_chain_id: String = ""
var _current_node_id: String = ""
var _current_options: Array = []

# ── UI 引用 ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var title_label: Label
var chain_name_label: Label
var desc_label: RichTextLabel
var options_container: VBoxContainer
var option_buttons: Array = []

# ── 动画 ──
var _tween: Tween = null

# ═══════════════════════════════════════════════════════════════
#                          生命周期
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	layer = UILayerRegistry.LAYER_EVENT_POPUP + 1  # 比事件弹窗高一层
	_build_ui()
	_connect_signals()
	_hide_dialog()

func _connect_signals() -> void:
	EventBus.quest_chain_branch_requested.connect(_on_branch_requested)

func _unhandled_input(event: InputEvent) -> void:
	if _visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			# 分支选择不可取消，忽略 ESC
			get_viewport().set_input_as_handled()

# ═══════════════════════════════════════════════════════════════
#                          构建 UI
# ═══════════════════════════════════════════════════════════════
func _build_ui() -> void:
	root = Control.new()
	root.name = "ChainBranchRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# 半透明遮罩
	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.7)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim_bg)

	# 主面板
	main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -300
	main_panel.offset_right = 300
	main_panel.offset_top = -250
	main_panel.offset_bottom = 250
	var sf := StyleBoxFlat.new()
	sf.bg_color = Color(0.08, 0.08, 0.14, 0.98)
	sf.border_color = Color(0.4, 0.7, 1.0, 0.9)
	sf.set_border_width_all(2)
	sf.set_corner_radius_all(10)
	sf.set_content_margin_all(20)
	main_panel.add_theme_stylebox_override("panel", sf)
	root.add_child(main_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(vbox)

	# 标题
	title_label = Label.new()
	title_label.text = "任务链分支选择"
	title_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	# 链名称
	chain_name_label = Label.new()
	chain_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	chain_name_label.add_theme_font_size_override("font_size", 15)
	chain_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(chain_name_label)

	# 分隔线
	vbox.add_child(HSeparator.new())

	# 描述文本
	desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.custom_minimum_size = Vector2(0, 60)
	desc_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	desc_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	desc_label.add_theme_font_size_override("normal_font_size", 14)
	vbox.add_child(desc_label)

	# 提示文字
	var hint_lbl := Label.new()
	hint_lbl.text = "请选择一个方向（选择后无法更改）："
	hint_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint_lbl)

	# 选项容器
	options_container = VBoxContainer.new()
	options_container.add_theme_constant_override("separation", 8)
	options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(options_container)

# ═══════════════════════════════════════════════════════════════
#                          显示/隐藏
# ═══════════════════════════════════════════════════════════════
func _show_dialog() -> void:
	_visible = true
	root.visible = true
	root.modulate = Color(1, 1, 1, 0)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(root, "modulate", Color(1, 1, 1, 1), 0.25)

func _hide_dialog() -> void:
	_visible = false
	root.visible = false

# ═══════════════════════════════════════════════════════════════
#                          信号处理
# ═══════════════════════════════════════════════════════════════
func _on_branch_requested(chain_id: String, node_id: String, options: Array) -> void:
	_current_chain_id = chain_id
	_current_node_id = node_id
	_current_options = options

	# 获取链名称
	var chain_name: String = chain_id
	if Engine.has_singleton("QuestChainManager"):
		var chains = QuestChainManager.get_all_chains_summary()
		for c in chains:
			if c.get("id", "") == chain_id:
				chain_name = c.get("name", chain_id)
				break
	chain_name_label.text = "【%s】" % chain_name

	# 清除旧选项
	for child in options_container.get_children():
		child.queue_free()
	option_buttons.clear()

	# 构建选项按钮
	for i in options.size():
		var opt: Dictionary = options[i]
		var btn_panel := PanelContainer.new()
		var btn_sf := StyleBoxFlat.new()
		btn_sf.bg_color = Color(0.12, 0.18, 0.28, 0.95)
		btn_sf.border_color = Color(0.3, 0.55, 0.85, 0.8)
		btn_sf.set_border_width_all(1)
		btn_sf.set_corner_radius_all(6)
		btn_sf.set_content_margin_all(10)
		btn_panel.add_theme_stylebox_override("panel", btn_sf)
		btn_panel.mouse_filter = Control.MOUSE_FILTER_STOP

		var btn_vbox := VBoxContainer.new()
		btn_vbox.add_theme_constant_override("separation", 4)
		btn_panel.add_child(btn_vbox)

		var btn_name := Label.new()
		btn_name.text = opt.get("text", "选项 %d" % (i + 1))
		btn_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		btn_name.add_theme_font_size_override("font_size", 15)
		btn_vbox.add_child(btn_name)

		var btn_desc := Label.new()
		btn_desc.text = opt.get("desc", "")
		btn_desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		btn_desc.add_theme_font_size_override("font_size", 13)
		btn_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn_vbox.add_child(btn_desc)

		# 点击事件
		var chosen_node_id: String = opt.get("node_id", "")
		btn_panel.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_option_chosen(chosen_node_id)
		)

		# Hover 效果
		btn_panel.mouse_entered.connect(func():
			btn_sf.bg_color = Color(0.18, 0.28, 0.42, 0.98)
			btn_sf.border_color = Color(0.5, 0.75, 1.0)
		)
		btn_panel.mouse_exited.connect(func():
			btn_sf.bg_color = Color(0.12, 0.18, 0.28, 0.95)
			btn_sf.border_color = Color(0.3, 0.55, 0.85, 0.8)
		)

		options_container.add_child(btn_panel)
		option_buttons.append(btn_panel)

	# 设置描述（使用第一个选项的父节点描述，如果有的话）
	desc_label.text = "面对这个关键时刻，你的选择将决定任务链的走向。每个分支都有不同的结果和奖励。"

	_show_dialog()

func _on_option_chosen(chosen_node_id: String) -> void:
	if _current_chain_id == "" or _current_node_id == "" or chosen_node_id == "":
		return
	EventBus.quest_chain_branch_chosen.emit(
		_current_chain_id,
		_current_node_id,
		chosen_node_id
	)
	_current_chain_id = ""
	_current_node_id = ""
	_current_options = []
	_hide_dialog()
