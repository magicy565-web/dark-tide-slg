## governance_panel.gd — 据点治理与政策 UI 面板
## 允许玩家在据点激活政策、执行治理行动。
extends CanvasLayer

const GovernanceSystem = preload("res://systems/strategic/governance_system.gd")

# ── 状态 ──
var _visible: bool = false
var _tile_idx: int = -1

# ── UI 引用 ──
var root: Control
var main_panel: PanelContainer
var content_vbox: VBoxContainer
var header_label: Label

func _ready() -> void:
	layer = UILayerRegistry.LAYER_DETAIL_PANELS
	_build_ui()
	hide_panel()

func _build_ui() -> void:
	root = Control.new()
	root.anchor_right = 1.0; root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	
	var dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0; dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0, 0, 0, 0.6)
	dim_bg.gui_input.connect(func(event): if event is InputEventMouseButton and event.pressed: hide_panel())
	root.add_child(dim_bg)
	
	main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.25; main_panel.anchor_right = 0.75
	main_panel.anchor_top = 0.2; main_panel.anchor_bottom = 0.8
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.12, 0.95)
	style.border_color = Color(0.4, 0.6, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	main_panel.add_theme_stylebox_override("panel", style)
	root.add_child(main_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	main_panel.add_child(vbox)
	
	var header_row = HBoxContainer.new()
	vbox.add_child(header_row)
	header_label = Label.new()
	header_label.text = "据点治理"
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)
	
	var btn_dev = Button.new()
	btn_dev.text = "🏗 发展地块"
	btn_dev.pressed.connect(func():
		hide_panel()
		if get_parent().has_method("_ensure_tile_dev_panel"):
			get_parent()._ensure_tile_dev_panel()
		var dev_panel = get_tree().root.find_child("TileDevRoot", true, false)
		if dev_panel and dev_panel.get_parent().has_method("show_panel"):
			dev_panel.get_parent().show_panel(_tile_idx)
	)
	header_row.add_child(btn_dev)

	var btn_close = Button.new()
	btn_close.text = "✕"
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_vbox)

func show_panel(tile_idx: int) -> void:
	_tile_idx = tile_idx
	_visible = true
	root.visible = true
	_refresh()

func hide_panel() -> void:
	_visible = false
	root.visible = false

func _refresh() -> void:
	for c in content_vbox.get_children(): c.queue_free()
	
	var tile = GameManager.tiles[_tile_idx]
	header_label.text = "治理 - %s" % tile.get("name", "据点")
	
	# ── 民心与腐败数值 ──
	if GameManager.morale_corruption_system:
		var morale = GameManager.morale_corruption_system.get_morale(_tile_idx)
		var corruption = GameManager.morale_corruption_system.get_corruption(_tile_idx)
		content_vbox.add_child(_make_stat_bar("民心", morale, Color.GREEN))
		content_vbox.add_child(_make_stat_bar("腐败", corruption, Color.RED))
		content_vbox.add_child(HSeparator.new())
	
	# ── 政策部分 ──
	content_vbox.add_child(_make_section_header("可用政策"))
	for p_id in GovernanceSystem.POLICIES:
		content_vbox.add_child(_make_policy_row(p_id))
	
	content_vbox.add_child(HSeparator.new())
	
	# ── 治理行动部分 ──
	content_vbox.add_child(_make_section_header("治理行动"))
	for a_id in GovernanceSystem.GOVERNANCE_ACTIONS:
		content_vbox.add_child(_make_action_row(a_id))
		
	content_vbox.add_child(HSeparator.new())
	
	# ── 防御策略部分 ──
	content_vbox.add_child(_make_section_header("防御策略"))
	for s_id in GovernanceSystem.DEFENSE_STRATEGIES:
		content_vbox.add_child(_make_strategy_row(s_id))

func _make_stat_bar(label: String, value: float, color: Color) -> PanelContainer:
	var pc = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", style)
	
	var vb = VBoxContainer.new()
	pc.add_child(vb)
	
	var lbl = Label.new()
	lbl.text = "%s: %.0f/100" % [label, value]
	lbl.add_theme_font_size_override("font_size", 12)
	vb.add_child(lbl)
	
	var bar = ProgressBar.new()
	bar.value = value
	bar.max_value = 100
	bar.custom_minimum_size = Vector2(0, 20)
	bar.add_theme_color_override("font_color", color)
	vb.add_child(bar)
	
	return pc

func _make_section_header(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	l.add_theme_font_size_override("font_size", 16)
	return l

func _make_policy_row(p_id: String) -> PanelContainer:
	var p = GovernanceSystem.POLICIES[p_id]
	var pc = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", style)
	
	var hb = HBoxContainer.new()
	pc.add_child(hb)
	
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	
	var name_lbl = Label.new()
	name_lbl.text = p["name"]
	name_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = p["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vb.add_child(desc_lbl)
	
	var btn = Button.new()
	btn.text = "激活"
	btn.custom_minimum_size = Vector2(80, 30)
	btn.pressed.connect(func(): 
		if GameManager.governance_system.activate_policy(_tile_idx, p_id):
			_refresh()
	)
	hb.add_child(btn)
	
	return pc

func _make_strategy_row(s_id: String) -> PanelContainer:
	var s = GovernanceSystem.DEFENSE_STRATEGIES[s_id]
	var pc = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", style)
	
	var hb = HBoxContainer.new()
	pc.add_child(hb)
	
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	
	var name_lbl = Label.new()
	name_lbl.text = s["name"]
	name_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = s["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vb.add_child(desc_lbl)
	
	var btn = Button.new()
	btn.text = "部署"
	btn.custom_minimum_size = Vector2(80, 30)
	btn.pressed.connect(func(): 
		if GameManager.governance_system.has_method("activate_strategy"):
			if GameManager.governance_system.activate_strategy(_tile_idx, s_id):
				_refresh()
	)
	hb.add_child(btn)
	
	return pc

func _make_action_row(a_id: String) -> PanelContainer:
	var a = GovernanceSystem.GOVERNANCE_ACTIONS[a_id]
	var pc = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(1, 1, 1, 0.05)
	style.set_content_margin_all(8)
	pc.add_theme_stylebox_override("panel", style)
	
	var hb = HBoxContainer.new()
	pc.add_child(hb)
	
	var vb = VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	
	var name_lbl = Label.new()
	name_lbl.text = a["name"]
	name_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = a["desc"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vb.add_child(desc_lbl)
	
	var btn = Button.new()
	btn.text = "执行"
	btn.custom_minimum_size = Vector2(80, 30)
	btn.pressed.connect(func(): 
		if GameManager.governance_system.execute_action(_tile_idx, a_id):
			_refresh()
	)
	hb.add_child(btn)
	
	return pc
