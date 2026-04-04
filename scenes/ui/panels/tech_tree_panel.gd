## tech_tree_panel.gd - Research Tree Panel UI for Dark Tide SLG (v2.0)
## Node-graph tech tree with interconnected cards, animated connections, and detail panel.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")
const TrainingData = preload("res://systems/faction/training_data.gd")

# ── Layout constants ──
const CARD_W: float = 160.0
const CARD_H: float = 100.0
const TIER_GAP_X: float = 220.0
const CARD_GAP_Y: float = 120.0
const GRAPH_MARGIN: Vector2 = Vector2(60, 40)
const TIER_LABELS: Array = ["T1", "T2", "T3"]
const BRANCH_COLORS: Dictionary = {
	TrainingData.TechBranch.VANGUARD: Color(0.95, 0.3, 0.25),
	TrainingData.TechBranch.RANGED: Color(0.95, 0.85, 0.25),
	TrainingData.TechBranch.MOBILE: Color(0.3, 0.55, 0.95),
	TrainingData.TechBranch.MAGIC: Color(0.7, 0.35, 0.9),
	TrainingData.TechBranch.FACTION_SPECIAL: Color(0.95, 0.78, 0.25),
}
const STATUS_ICONS: Dictionary = {
	"completed": "✓", "researching": "⟳", "locked": "🔒", "available": "◇", "queued": "⊕",
}

# ── State ──
var _visible: bool = false
var _selected_tech_id: String = ""
var _zoom: float = 1.0
var _anim_time: float = 0.0
var _entrance_progress: float = 0.0
var _card_positions: Dictionary = {}  # tech_id -> Vector2 (center)
var _card_controls: Dictionary = {}   # tech_id -> Control
var _hovered_tech_id: String = ""

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var queue_bar: HBoxContainer
var graph_scroll: ScrollContainer
var graph_canvas: Control  # custom draw node for connections
var card_container: Control
var detail_panel: PanelContainer
var detail_container: VBoxContainer
var zoom_label: Label

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_INFO_PANELS; _build_ui(); _connect_signals(); hide_panel()

func _process(delta: float) -> void:
	if not _visible: return
	_anim_time += delta
	if _entrance_progress < 1.0:
		_entrance_progress = minf(_entrance_progress + delta * 3.0, 1.0)
		_update_card_entrance()
	if is_instance_valid(graph_canvas):
		graph_canvas.queue_redraw()

func _connect_signals() -> void:
	var _rm = get_node_or_null("/root/ResearchManager")
	if _rm:
		_rm.research_started.connect(_on_research_changed)
		_rm.research_completed.connect(_on_research_changed)
		_rm.research_cancelled.connect(_on_research_changed)
	EventBus.tech_effects_applied.connect(_on_tech_effects)

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.game_active: return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_Y:
			if _visible: hide_panel()
			else: show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			hide_panel(); get_viewport().set_input_as_handled()

# ═══════════════ BUILD UI ═══════════════
func _build_ui() -> void:
	root = Control.new()
	root.name = "TechTreeRoot"
	root.anchor_right = 1.0; root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0; dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0, 0, 0, 0.6)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	main_panel = PanelContainer.new()
	main_panel.anchor_right = 1.0; main_panel.anchor_bottom = 1.0
	main_panel.offset_left = 20; main_panel.offset_right = -20
	main_panel.offset_top = 20; main_panel.offset_bottom = -20
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.96)
	style.border_color = ColorTheme.BORDER_DEFAULT
	style.set_border_width_all(2); style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	main_panel.add_theme_stylebox_override("panel", style)
	root.add_child(main_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 6)
	main_panel.add_child(outer_vbox)

	_build_header(outer_vbox)
	_build_queue_bar(outer_vbox)
	outer_vbox.add_child(HSeparator.new())

	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 6)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_hbox)

	_build_graph_area(content_hbox)
	_build_detail_panel(content_hbox)

func _build_header(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	header_label = Label.new()
	header_label.text = "⚗ Research Tree"
	header_label.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING + 2)
	header_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(header_label)
	_build_zoom_controls(row)
	btn_close = Button.new()
	btn_close.text = "X"; btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	row.add_child(btn_close)

func _build_zoom_controls(parent: HBoxContainer) -> void:
	var btn_minus := Button.new()
	btn_minus.text = "-"; btn_minus.custom_minimum_size = Vector2(28, 28)
	btn_minus.add_theme_font_size_override("font_size", 14)
	btn_minus.pressed.connect(_zoom_out)
	parent.add_child(btn_minus)
	zoom_label = Label.new()
	zoom_label.text = "100%"
	zoom_label.add_theme_font_size_override("font_size", 12)
	zoom_label.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	zoom_label.custom_minimum_size.x = 40
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(zoom_label)
	var btn_plus := Button.new()
	btn_plus.text = "+"; btn_plus.custom_minimum_size = Vector2(28, 28)
	btn_plus.add_theme_font_size_override("font_size", 14)
	btn_plus.pressed.connect(_zoom_in)
	parent.add_child(btn_plus)

func _build_queue_bar(parent: VBoxContainer) -> void:
	queue_bar = HBoxContainer.new()
	queue_bar.add_theme_constant_override("separation", 8)
	queue_bar.custom_minimum_size.y = 38
	parent.add_child(queue_bar)

func _build_graph_area(parent: HBoxContainer) -> void:
	graph_scroll = ScrollContainer.new()
	graph_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	graph_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	graph_scroll.gui_input.connect(_on_graph_scroll_input)
	parent.add_child(graph_scroll)

	var graph_root := Control.new()
	graph_root.name = "GraphRoot"
	graph_scroll.add_child(graph_root)

	graph_canvas = Control.new()
	graph_canvas.name = "ConnectionCanvas"
	graph_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_root.add_child(graph_canvas)
	graph_canvas.draw.connect(_draw_connections)

	card_container = Control.new()
	card_container.name = "CardContainer"
	card_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	graph_root.add_child(card_container)

func _build_detail_panel(parent: HBoxContainer) -> void:
	detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(310, 0)
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.visible = false
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	ds.border_color = ColorTheme.BORDER_DEFAULT
	ds.set_border_width_all(1); ds.set_corner_radius_all(8)
	ds.set_content_margin_all(12)
	detail_panel.add_theme_stylebox_override("panel", ds)
	parent.add_child(detail_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(scroll)
	detail_container = VBoxContainer.new()
	detail_container.add_theme_constant_override("separation", 6)
	detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(detail_container)

# ═══════════════ PUBLIC API ═══════════════

func show_panel() -> void:
	_visible = true; root.visible = true
	_selected_tech_id = ""; detail_panel.visible = false
	_entrance_progress = 0.0; _anim_time = 0.0
	_refresh()

func hide_panel() -> void:
	var _am = get_node_or_null("/root/AudioManager")
	if _am: _am.play_ui_cancel()
	_visible = false; root.visible = false

func is_panel_visible() -> bool:
	return _visible

# ═══════════════ ZOOM ═══════════════

func _zoom_in() -> void:
	_zoom = minf(_zoom + 0.15, 2.0); _apply_zoom()

func _zoom_out() -> void:
	_zoom = maxf(_zoom - 0.15, 0.5); _apply_zoom()

func _apply_zoom() -> void:
	zoom_label.text = "%d%%" % int(_zoom * 100)
	if is_instance_valid(card_container):
		card_container.scale = Vector2(_zoom, _zoom)
	if is_instance_valid(graph_canvas):
		graph_canvas.scale = Vector2(_zoom, _zoom)
	_resize_graph_root()

func _resize_graph_root() -> void:
	var base_size := _calc_graph_size()
	var scaled := base_size * _zoom
	var graph_root: Control = graph_scroll.get_child(0) if graph_scroll.get_child_count() > 0 else null
	if graph_root:
		graph_root.custom_minimum_size = scaled

func _on_graph_scroll_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_in(); get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_out(); get_viewport().set_input_as_handled()

# ═══════════════ REFRESH ═══════════════

func _refresh() -> void:
	_refresh_queue_bar(); _refresh_graph()
	if _selected_tech_id != "": _refresh_detail()

func _refresh_queue_bar() -> void:
	for c in queue_bar.get_children(): c.queue_free()
	var _rm = get_node_or_null("/root/ResearchManager")
	if not _rm: return
	var pid: int = GameManager.get_human_player_id()
	var current: String = _rm.get_current_research(pid)
	var progress: int = _rm.get_research_progress(pid)
	var speed: float = _rm.get_research_speed(pid)
	var queue: Array = _rm.get_research_queue(pid)

	# "Research:" label
	var prefix := Label.new()
	prefix.text = "Research:"
	prefix.add_theme_font_size_override("font_size", 12)
	prefix.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	queue_bar.add_child(prefix)

	if current == "":
		var lbl := Label.new()
		lbl.text = "  None — select a tech to begin"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		queue_bar.add_child(lbl)
		return

	# Current research chip
	var cur_data: Dictionary = _rm.get_tech_data(current)
	var turns_needed: int = cur_data.get("turns", 1)
	_add_queue_chip(cur_data.get("name", current), progress, turns_needed, true)

	# Queued items
	for tid in queue:
		var qd: Dictionary = _rm.get_tech_data(tid)
		_add_queue_chip(qd.get("name", tid), 0, qd.get("turns", 1), false)

	# Speed indicator
	var spd_lbl := Label.new()
	spd_lbl.text = "  Spd:%.1f" % speed
	spd_lbl.add_theme_font_size_override("font_size", 11)
	spd_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	queue_bar.add_child(spd_lbl)

	# Spacer + Cancel button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_bar.add_child(spacer)
	var btn_cancel := Button.new()
	btn_cancel.text = "Cancel"; btn_cancel.custom_minimum_size = Vector2(70, 26)
	btn_cancel.add_theme_font_size_override("font_size", 11)
	btn_cancel.pressed.connect(_on_cancel_research)
	queue_bar.add_child(btn_cancel)

func _add_queue_chip(tech_name: String, progress: int, total: int, is_current: bool) -> void:
	var chip := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.15, 0.14, 0.2, 0.9) if is_current else Color(0.1, 0.1, 0.15, 0.8)
	cs.border_color = ColorTheme.TEXT_GOLD if is_current else ColorTheme.BORDER_DIM
	cs.set_border_width_all(1); cs.set_corner_radius_all(4)
	cs.content_margin_left = 8; cs.content_margin_right = 8
	cs.content_margin_top = 2; cs.content_margin_bottom = 2
	chip.add_theme_stylebox_override("panel", cs)
	queue_bar.add_child(chip)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	chip.add_child(hb)

	# Abbreviated name (max 12 chars)
	var short_name: String = tech_name.left(12) + ".." if tech_name.length() > 14 else tech_name
	var icon_text: String = "⟳ " if is_current else "◇ "
	var nl := Label.new()
	nl.text = icon_text + short_name
	nl.add_theme_font_size_override("font_size", 11)
	nl.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD if is_current else ColorTheme.TEXT_DIM)
	hb.add_child(nl)

	# Progress / turns
	var tl := Label.new()
	tl.text = "%d/%dt" % [progress, total] if is_current else "%dt" % total
	tl.add_theme_font_size_override("font_size", 10)
	tl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	hb.add_child(tl)

func _refresh_graph() -> void:
	# Clear old cards
	for c in card_container.get_children(): c.queue_free()
	_card_positions.clear(); _card_controls.clear()

	var _rm = get_node_or_null("/root/ResearchManager")
	if not _rm: return
	var pid: int = GameManager.get_human_player_id()
	if _rm._active_tree.is_empty():
		var lbl := Label.new()
		lbl.text = "No research available (build an academy first)"
		lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		lbl.position = Vector2(GRAPH_MARGIN)
		card_container.add_child(lbl)
		return

	_layout_cards()
	_resize_graph_root()
	# Set canvas size to match
	var sz := _calc_graph_size()
	graph_canvas.custom_minimum_size = sz
	card_container.custom_minimum_size = sz

func _calc_graph_size() -> Vector2:
	var max_x: float = 400; var max_y: float = 300
	for pos in _card_positions.values():
		max_x = maxf(max_x, pos.x + CARD_W + GRAPH_MARGIN.x)
		max_y = maxf(max_y, pos.y + CARD_H + GRAPH_MARGIN.y)
	return Vector2(max_x, max_y)

func _layout_cards() -> void:
	var _rm = get_node_or_null("/root/ResearchManager")
	if not _rm: return
	var pid: int = GameManager.get_human_player_id()
	var completed: Array = _rm.get_completed_techs(pid)
	var current: String = _rm.get_current_research(pid)
	var queue: Array = _rm.get_research_queue(pid)
	var available_ids: Array = []
	for a in _rm.get_available_techs(pid): available_ids.append(a["id"])

	# Group by tier
	var tier_groups: Dictionary = {0: [], 1: [], 2: []}
	for tech_id in _rm._active_tree:
		var data: Dictionary = _rm._active_tree[tech_id]
		var tier: int = data.get("tier", 0)
		if not tier_groups.has(tier): tier_groups[tier] = []
		tier_groups[tier].append(tech_id)

	# Sort within each tier by branch for consistent ordering
	for tier in tier_groups:
		tier_groups[tier].sort_custom(func(a, b):
			var da: Dictionary = _rm._active_tree[a]
			var db: Dictionary = _rm._active_tree[b]
			if da.get("branch", 0) != db.get("branch", 0):
				return da.get("branch", 0) < db.get("branch", 0)
			return a < b
		)

	# Position cards: tier columns left-to-right
	for tier in tier_groups:
		var techs: Array = tier_groups[tier]
		var col_x: float = GRAPH_MARGIN.x + tier * TIER_GAP_X
		for i in range(techs.size()):
			var tid: String = techs[i]
			var y: float = GRAPH_MARGIN.y + i * CARD_GAP_Y
			_card_positions[tid] = Vector2(col_x, y)
			var state: String = _get_tech_state(tid, completed, current, queue, available_ids)
			_create_card(tid, Vector2(col_x, y), state)

func _get_tech_state(tid: String, completed: Array, current: String, queue: Array, available: Array) -> String:
	if tid in completed: return "completed"
	if tid == current: return "researching"
	if tid in queue: return "queued"
	if tid in available: return "available"
	return "locked"

func _get_branch_color(branch_val) -> Color:
	if BRANCH_COLORS.has(branch_val): return BRANCH_COLORS[branch_val]
	return Color(0.5, 0.5, 0.5)

func _create_card(tech_id: String, pos: Vector2, state: String) -> void:
	var _rm = get_node_or_null("/root/ResearchManager")
	var data: Dictionary = _rm._active_tree.get(tech_id, {}) if _rm else {}
	var branch_color: Color = _get_branch_color(data.get("branch", -1))
	var card := PanelContainer.new()
	card.position = pos
	card.custom_minimum_size = Vector2(CARD_W, CARD_H)
	card.size = Vector2(CARD_W, CARD_H)

	# Card background style
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.08, 0.08, 0.13, 0.92)
	match state:
		"completed": cs.border_color = Color(0.3, 0.85, 0.4)
		"researching": cs.border_color = Color(1.0, 0.85, 0.25)
		"available": cs.border_color = Color(0.7, 0.7, 0.8)
		"queued": cs.border_color = Color(0.75, 0.65, 0.25)
		_: cs.border_color = Color(0.2, 0.2, 0.25)
	cs.set_border_width_all(2)
	cs.border_width_top = 4
	cs.set_corner_radius_all(6)
	cs.set_content_margin_all(6)
	cs.content_margin_top = 2
	card.add_theme_stylebox_override("panel", cs)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	card.add_child(vb)

	# Top stripe (colored bar via ColorRect)
	var stripe := ColorRect.new()
	stripe.color = branch_color
	stripe.custom_minimum_size = Vector2(0, 3)
	vb.add_child(stripe)

	# Row: tier badge + status icon
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	vb.add_child(top_row)
	var tier_val: int = data.get("tier", 0)
	var tier_lbl := Label.new()
	tier_lbl.text = TIER_LABELS[clampi(tier_val, 0, 2)]
	tier_lbl.add_theme_font_size_override("font_size", 9)
	var tier_color: Color
	match tier_val:
		0: tier_color = Color(0.6, 0.8, 0.6)
		1: tier_color = Color(0.5, 0.7, 1.0)
		_: tier_color = Color(1.0, 0.8, 0.3)
	tier_lbl.add_theme_color_override("font_color", tier_color)
	top_row.add_child(tier_lbl)

	# Branch name
	var branch_names: Dictionary = {
		TrainingData.TechBranch.VANGUARD: "Vanguard",
		TrainingData.TechBranch.RANGED: "Ranged",
		TrainingData.TechBranch.MOBILE: "Mobile",
		TrainingData.TechBranch.MAGIC: "Magic",
		TrainingData.TechBranch.FACTION_SPECIAL: "Special",
	}
	var bn := Label.new()
	bn.text = branch_names.get(data.get("branch", -1), "??")
	bn.add_theme_font_size_override("font_size", 9)
	bn.add_theme_color_override("font_color", branch_color.darkened(0.15))
	top_row.add_child(bn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	# Status icon
	var si := Label.new()
	si.text = STATUS_ICONS.get(state, "?")
	si.add_theme_font_size_override("font_size", 12)
	match state:
		"completed": si.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4))
		"researching": si.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		"available": si.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		"queued": si.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
		_: si.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	top_row.add_child(si)

	# Tech name (bold via RichTextLabel)
	var name_rtl := RichTextLabel.new()
	name_rtl.bbcode_enabled = true
	name_rtl.fit_content = true; name_rtl.scroll_active = false
	name_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_rtl.custom_minimum_size = Vector2(0, 20)
	name_rtl.add_theme_font_size_override("normal_font_size", 11)
	var name_color: Color
	match state:
		"completed": name_color = Color(0.4, 0.95, 0.5)
		"researching": name_color = Color(1.0, 0.9, 0.35)
		"locked": name_color = Color(0.45, 0.45, 0.5)
		_: name_color = Color(0.9, 0.88, 0.82)
	var hex: String = name_color.to_html(false)
	name_rtl.text = "[b][color=#%s]%s[/color][/b]" % [hex, data.get("name", tech_id)]
	vb.add_child(name_rtl)

	# Cost summary (compact)
	var cost: Dictionary = data.get("cost", {})
	var cost_parts: Array = []
	for key in cost:
		var icon: String = _res_icon(key)
		cost_parts.append("%s%d" % [icon, cost[key]])
	var cost_lbl := Label.new()
	cost_lbl.text = " ".join(cost_parts) if cost_parts.size() > 0 else ""
	cost_lbl.add_theme_font_size_override("font_size", 9)
	cost_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.35))
	vb.add_child(cost_lbl)

	# Turns indicator
	var turns_lbl := Label.new()
	turns_lbl.text = "%dt" % data.get("turns", 1)
	turns_lbl.add_theme_font_size_override("font_size", 9)
	turns_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	vb.add_child(turns_lbl)

	# Interaction
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_tech_card_input.bind(tech_id))
	card.mouse_entered.connect(_on_card_hover_in.bind(tech_id, card))
	card.mouse_exited.connect(_on_card_hover_out.bind(tech_id, card))

	# Fade-in start
	card.modulate.a = 0.0

	card_container.add_child(card)
	_card_controls[tech_id] = card

func _res_icon(key: String) -> String:
	match key:
		"gold": return "⛁"
		"iron": return "⚒"
		"crystal": return "◆"
		"shadow": return "◈"
		"gunpowder": return "✧"
		"food": return "⊛"
		_: return key.left(2) + ":"

func _update_card_entrance() -> void:
	var keys: Array = _card_controls.keys()
	for i in range(keys.size()):
		var tid: String = keys[i]
		var ctrl: Control = _card_controls[tid]
		if not is_instance_valid(ctrl): continue
		var stagger: float = i * 0.07
		var alpha: float = clampf((_entrance_progress - stagger) * 4.0, 0.0, 1.0)
		ctrl.modulate.a = alpha
		ctrl.position.y = _card_positions[tid].y + (1.0 - alpha) * 12.0

# ═══════════════ DRAW CONNECTIONS ═══════════════

func _draw_connections() -> void:
	if not is_instance_valid(graph_canvas): return
	var _rm = get_node_or_null("/root/ResearchManager")
	if not _rm: return
	var pid: int = GameManager.get_human_player_id()
	var completed: Array = _rm.get_completed_techs(pid)
	var current: String = _rm.get_current_research(pid)

	for tech_id in _rm._active_tree:
		var data: Dictionary = _rm._active_tree[tech_id]
		var prereqs: Array = data.get("prereqs", [])
		if not _card_positions.has(tech_id): continue
		var to_pos: Vector2 = _card_positions[tech_id] + Vector2(0, CARD_H * 0.5)

		for prereq_id in prereqs:
			if not _card_positions.has(prereq_id): continue
			var from_pos: Vector2 = _card_positions[prereq_id] + Vector2(CARD_W, CARD_H * 0.5)

			var both_done: bool = prereq_id in completed and tech_id in completed
			var prereq_done: bool = prereq_id in completed
			var is_researching: bool = tech_id == current and prereq_done

			var line_color: Color
			var line_width: float
			var dashed: bool = false

			if both_done:
				# Green glow
				line_color = Color(0.35, 0.9, 0.4, 0.85)
				line_width = 2.5
			elif is_researching:
				# Animated golden
				line_color = Color(1.0, 0.85, 0.3, 0.9)
				line_width = 2.0
			elif prereq_done:
				# Gold solid (available path)
				line_color = Color(0.85, 0.7, 0.3, 0.7)
				line_width = 1.8
			else:
				# Gray dashed
				line_color = Color(0.35, 0.35, 0.4, 0.5)
				line_width = 1.2
				dashed = true

			if dashed:
				_draw_dashed_line(graph_canvas, from_pos, to_pos, line_color, line_width)
			else:
				_draw_bezier_line(graph_canvas, from_pos, to_pos, line_color, line_width)

			# Glow for completed connections
			if both_done:
				var glow_alpha: float = 0.15 + 0.1 * sin(_anim_time * 2.0)
				var glow_color := Color(0.35, 0.95, 0.45, glow_alpha)
				_draw_bezier_line(graph_canvas, from_pos, to_pos, glow_color, line_width + 4.0)

			# Animated dots for researching
			if is_researching:
				_draw_flow_dots(graph_canvas, from_pos, to_pos, line_color)

func _draw_bezier_line(canvas: Control, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var mid_x: float = (from.x + to.x) * 0.5
	var cp1 := Vector2(mid_x, from.y)
	var cp2 := Vector2(mid_x, to.y)
	var points: PackedVector2Array = []
	var segments: int = 16
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var p: Vector2 = _cubic_bezier(from, cp1, cp2, to, t)
		points.append(p)
	if points.size() >= 2:
		canvas.draw_polyline(points, color, width, true)

func _draw_dashed_line(canvas: Control, from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var mid_x: float = (from.x + to.x) * 0.5
	var cp1 := Vector2(mid_x, from.y)
	var cp2 := Vector2(mid_x, to.y)
	var segments: int = 16
	var dash_len: int = 2
	for i in range(0, segments, dash_len * 2):
		var t0: float = float(i) / float(segments)
		var t1: float = float(mini(i + dash_len, segments)) / float(segments)
		var p0: Vector2 = _cubic_bezier(from, cp1, cp2, to, t0)
		var p1: Vector2 = _cubic_bezier(from, cp1, cp2, to, t1)
		canvas.draw_line(p0, p1, color, width, true)

func _draw_flow_dots(canvas: Control, from: Vector2, to: Vector2, color: Color) -> void:
	var mid_x: float = (from.x + to.x) * 0.5
	var cp1 := Vector2(mid_x, from.y)
	var cp2 := Vector2(mid_x, to.y)
	var dot_count: int = 3
	for d in range(dot_count):
		var phase: float = fmod(_anim_time * 0.8 + float(d) / float(dot_count), 1.0)
		var p: Vector2 = _cubic_bezier(from, cp1, cp2, to, phase)
		var alpha: float = 0.5 + 0.5 * sin(phase * TAU)
		canvas.draw_circle(p, 3.0, Color(color.r, color.g, color.b, alpha * 0.9))

func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u*u*u*p0 + 3.0*u*u*t*p1 + 3.0*u*t*t*p2 + t*t*t*p3

# ═══════════════ DETAIL PANEL ═══════════════

func _refresh_detail() -> void:
	for c in detail_container.get_children(): c.queue_free()
	if _selected_tech_id == "": return
	var _rm = get_node_or_null("/root/ResearchManager")
	if not _rm: return
	var pid: int = GameManager.get_human_player_id()
	var data: Dictionary = _rm.get_tech_data(_selected_tech_id)
	if data.is_empty(): return
	var completed: Array = _rm.get_completed_techs(pid)
	var current: String = _rm.get_current_research(pid)
	var queue: Array = _rm.get_research_queue(pid)
	var available_ids: Array = []
	for a in _rm.get_available_techs(pid): available_ids.append(a["id"])
	var state: String = _get_tech_state(_selected_tech_id, completed, current, queue, available_ids)

	# Name
	var nl := Label.new()
	nl.text = data.get("name", _selected_tech_id)
	nl.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING)
	nl.add_theme_color_override("font_color", ColorTheme.TEXT_HEADING)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_container.add_child(nl)

	# Branch + Tier with color
	var branch_color: Color = _get_branch_color(data.get("branch", -1))
	var meta_rtl := RichTextLabel.new()
	meta_rtl.bbcode_enabled = true; meta_rtl.fit_content = true
	meta_rtl.scroll_active = false; meta_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta_rtl.add_theme_font_size_override("normal_font_size", 12)
	var tier_val: int = data.get("tier", 0)
	var tier_name: String = ["Basic", "Advanced", "Ultimate"][clampi(tier_val, 0, 2)]
	var bch: String = branch_color.to_html(false)
	meta_rtl.text = "[color=#%s]%s[/color]  |  %s  |  %s" % [bch, _branch_name(data.get("branch", -1)), TIER_LABELS[clampi(tier_val, 0, 2)], tier_name]
	detail_container.add_child(meta_rtl)

	# Status badge
	var status_lbl := Label.new()
	status_lbl.text = "%s %s" % [STATUS_ICONS.get(state, ""), state.capitalize()]
	status_lbl.add_theme_font_size_override("font_size", 13)
	match state:
		"completed": status_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
		"researching": status_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		"available": status_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		_: status_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	detail_container.add_child(status_lbl)
	detail_container.add_child(HSeparator.new())

	# Description with BBCode
	var desc_rtl := RichTextLabel.new()
	desc_rtl.bbcode_enabled = true; desc_rtl.fit_content = true
	desc_rtl.scroll_active = false; desc_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_rtl.add_theme_font_size_override("normal_font_size", 13)
	desc_rtl.text = data.get("desc", "No description")
	detail_container.add_child(desc_rtl)

	# Cost breakdown
	var cost: Dictionary = data.get("cost", {})
	if not cost.is_empty():
		detail_container.add_child(HSeparator.new())
		var cost_title := Label.new()
		cost_title.text = "Cost:"; cost_title.add_theme_font_size_override("font_size", 13)
		cost_title.add_theme_color_override("font_color", Color(0.8, 0.65, 0.35))
		detail_container.add_child(cost_title)
		for key in cost:
			var cl := Label.new()
			cl.text = "  %s %s: %d" % [_res_icon(key), _res_cn_name(key), cost[key]]
			cl.add_theme_font_size_override("font_size", 12)
			cl.add_theme_color_override("font_color", _res_color(key))
			detail_container.add_child(cl)

	# Turns
	var tl := Label.new()
	tl.text = "研究耗时: %d 回合" % data.get("turns", 1)
	tl.add_theme_font_size_override("font_size", 12)
	tl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.85))
	detail_container.add_child(tl)

	# Prerequisites with checkmarks
	var prereqs: Array = data.get("prereqs", [])
	if not prereqs.is_empty():
		detail_container.add_child(HSeparator.new())
		var pt := Label.new()
		pt.text = "前置科技:"
		pt.add_theme_font_size_override("font_size", 13)
		pt.add_theme_color_override("font_color", Color(0.7, 0.55, 0.4))
		detail_container.add_child(pt)
		for p in prereqs:
			var pd: Dictionary = _rm.get_tech_data(p)
			var done: bool = p in completed
			var pl := Label.new()
			pl.text = "  %s %s" % ["✓" if done else "✗", pd.get("name", p)]
			pl.add_theme_font_size_override("font_size", 12)
			pl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if done else Color(0.9, 0.4, 0.35))
			pl.autowrap_mode = TextServer.AUTOWRAP_WORD
			detail_container.add_child(pl)

	# Effects
	var effects: Dictionary = data.get("effects", {})
	if not effects.is_empty():
		detail_container.add_child(HSeparator.new())
		var et := Label.new()
		et.text = "科技效果:"
		et.add_theme_font_size_override("font_size", 13)
		et.add_theme_color_override("font_color", Color(0.5, 0.85, 0.55))
		detail_container.add_child(et)
		for key in effects:
			var ec: Color; var icon: String
			if "atk" in key.to_lower() or "buff" in key.to_lower():
				ec = Color(0.5, 0.9, 0.5); icon = "ATK↑"
			elif "def" in key.to_lower() or "shield" in key.to_lower():
				ec = Color(0.5, 0.7, 1.0); icon = "DEF↑"
			elif "passive" in key.to_lower():
				ec = Color(1.0, 0.85, 0.35); icon = "✦"
			elif "active" in key.to_lower():
				ec = Color(1.0, 0.6, 0.3); icon = "⚡"
			else:
				ec = Color(0.7, 0.8, 0.7); icon = "•"
			var el := Label.new()
			el.text = "  %s %s: %s" % [icon, _effect_cn_name(key), _format_effect_value(effects[key])]
			el.add_theme_font_size_override("font_size", 11)
			el.add_theme_color_override("font_color", ec)
			el.autowrap_mode = TextServer.AUTOWRAP_WORD
			detail_container.add_child(el)

	# Action buttons
	detail_container.add_child(HSeparator.new())
	if state == "completed":
		var done_lbl := Label.new()
		done_lbl.text = "✓ 研究完成"
		done_lbl.add_theme_font_size_override("font_size", 14)
		done_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.45))
		detail_container.add_child(done_lbl)
	elif state == "researching":
		var prog: Variant = _rm.get_research_progress(pid)
		var total: int = data.get("turns", 1)
		var pl := Label.new()
		pl.text = "⟳ 研究中... %d/%d 回合" % [prog, total]
		pl.add_theme_font_size_override("font_size", 13)
		pl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		detail_container.add_child(pl)
		var bar := ProgressBar.new()
		bar.min_value = 0; bar.max_value = total; bar.value = prog
		bar.custom_minimum_size = Vector2(0, 14); bar.show_percentage = false
		detail_container.add_child(bar)
		var bc := Button.new()
		bc.text = "取消研究"; bc.custom_minimum_size = Vector2(140, 34)
		bc.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		bc.pressed.connect(_on_cancel_research)
		var ds: Dictionary = ColorTheme.make_button_style_danger()
		for sk in ds: bc.add_theme_stylebox_override(sk, ds[sk])
		bc.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)
		detail_container.add_child(bc)
	elif state == "available":
		var btn_text: String = "开始研究" if current == "" else "加入研究队列"
		var bs := Button.new()
		bs.text = btn_text; bs.custom_minimum_size = Vector2(160, 38)
		bs.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY + 1)
		bs.pressed.connect(_on_start_research.bind(_selected_tech_id))
		var cs: Dictionary = ColorTheme.make_button_style_confirm()
		for sk in cs: bs.add_theme_stylebox_override(sk, cs[sk])
		bs.add_theme_color_override("font_color", ColorTheme.TEXT_SUCCESS)
		detail_container.add_child(bs)
	elif state == "queued":
		var ql := Label.new()
		ql.text = "⊕ 已加入研究队列"
		ql.add_theme_font_size_override("font_size", 13)
		ql.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3))
		detail_container.add_child(ql)
	else:
		var ll := Label.new()
		ll.text = "🔒 前置科技未完成"
		ll.add_theme_font_size_override("font_size", 13)
		ll.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
		detail_container.add_child(ll)

func _branch_name(branch_val) -> String:
	match branch_val:
		TrainingData.TechBranch.VANGUARD: return "先锋"
		TrainingData.TechBranch.RANGED: return "远程"
		TrainingData.TechBranch.MOBILE: return "机动"
		TrainingData.TechBranch.MAGIC: return "魔法"
		TrainingData.TechBranch.FACTION_SPECIAL: return "派系专属"
		_: return "未知"

func _res_color(key: String) -> Color:
	match key:
		"gold": return ColorTheme.RES_GOLD
		"iron": return ColorTheme.RES_IRON
		"crystal": return ColorTheme.RES_CRYSTAL
		"food": return ColorTheme.RES_FOOD
		"shadow": return Color(0.6, 0.4, 0.8)
		"gunpowder": return Color(0.9, 0.7, 0.4)
		_: return ColorTheme.TEXT_DIM

func _format_effect_value(val) -> String:
	if val is Dictionary:
		var parts: Array = []
		for k in val:
			parts.append("%s:%s" % [k, str(val[k])])
		return "{ %s }" % ", ".join(parts)
	return str(val)

# ═══════════════ CALLBACKS ═══════════════

func _on_tech_card_input(event: InputEvent, tech_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_select_tech(tech_id)

func _on_select_tech(tech_id: String) -> void:
	var _am = get_node_or_null("/root/AudioManager")
	if _am: _am.play_ui_click()
	_selected_tech_id = tech_id; detail_panel.visible = true; _refresh_detail()

func _on_card_hover_in(tech_id: String, card: Control) -> void:
	_hovered_tech_id = tech_id
	if is_instance_valid(card):
		var tw := card.create_tween()
		tw.tween_property(card, "scale", Vector2(1.06, 1.06), 0.1).set_ease(Tween.EASE_OUT)
		card.z_index = 10
		# Tooltip via hint
		var _rm = get_node_or_null("/root/ResearchManager")
		var data: Dictionary = _rm.get_tech_data(tech_id) if _rm else {}
		card.tooltip_text = data.get("desc", "")

func _on_card_hover_out(tech_id: String, card: Control) -> void:
	if _hovered_tech_id == tech_id: _hovered_tech_id = ""
	if is_instance_valid(card):
		var tw := card.create_tween()
		tw.tween_property(card, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_IN)
		card.z_index = 0

func _on_start_research(tech_id: String) -> void:
	var _am = get_node_or_null("/root/AudioManager")
	if _am: _am.play_ui_confirm()
	var _rm = get_node_or_null("/root/ResearchManager")
	if _rm: _rm.start_research(GameManager.get_human_player_id(), tech_id)
	_refresh()

func _on_cancel_research() -> void:
	var _am = get_node_or_null("/root/AudioManager")
	if _am: _am.play_ui_click()
	var _rm = get_node_or_null("/root/ResearchManager")
	if _rm: _rm.cancel_research(GameManager.get_human_player_id())
	_refresh()

func _on_research_changed(_pid: int, _tech_id: String) -> void:
	if _visible: _refresh()

func _on_tech_effects(_pid: int) -> void:
	if _visible: _refresh()

func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: hide_panel()

## 资源名称中文映射（v0.9.3 新增）
func _res_cn_name(key: String) -> String:
	var cn_map: Dictionary = {
		"gold": "黄金", "iron": "铁矿", "crystal": "魔晶",
		"food": "粮草", "shadow": "暗影精华", "gunpowder": "火药",
		"slaves": "奴隶", "prestige": "威望", "mana": "法力",
		"wood": "木材", "stone": "石料",
	}
	return cn_map.get(key, key)

## 科技效果键名中文映射（v0.9.3 新增）
func _effect_cn_name(key: String) -> String:
	var cn_map: Dictionary = {
		# 战斗效果
		"atk_bonus": "攻击加成", "def_bonus": "防御加成",
		"spd_bonus": "速度加成", "int_bonus": "智力加成",
		"morale_cap_bonus": "士气上限提升", "morale_bonus": "士气加成",
		"crit_chance": "暴击率", "crit_mult": "暴击倍率",
		"counter_bonus": "反击加成", "flanking_bonus": "侧翼加成",
		# 后勤效果
		"army_cap_bonus": "军队上限", "supply_range_bonus": "补给范围",
		"food_consume_reduction": "粮草消耗减少",
		"march_speed_bonus": "行军速度",
		# 经济效果
		"gold_per_turn": "每回合金币", "iron_per_turn": "每回合铁矿",
		"food_per_turn": "每回合粮草", "research_speed": "研究速度",
		"recruit_discount": "招募折扣",
		# 特殊效果
		"waaagh_regen_bonus": "WAAAGH! 再生", "infamy_gain_bonus": "恶名获取",
		"shadow_per_turn": "每回合暗影", "corruption_range": "腐化范围",
		"assassination_success_bonus": "暗杀成功率",
		# 被动/主动技能
		"passive": "被动技能", "active": "主动技能",
		"unlock_passive": "解锁被动", "unlock_active": "解锁主动",
		# 通用
		"hp_bonus": "生命值加成", "hp_regen": "生命回复",
		"siege_bonus": "攻城加成", "garrison_bonus": "驻守加成",
	}
	return cn_map.get(key, key)
