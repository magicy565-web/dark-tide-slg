## tech_tree_panel.gd - Research Tree Panel UI for Dark Tide SLG (v1.0)
## Displays research tree, progress, queue, and allows starting/cancelling research.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── State ──
var _visible: bool = false
var _selected_tech_id: String = ""

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var tree_scroll: ScrollContainer
var tree_container: VBoxContainer
var detail_panel: PanelContainer
var detail_container: VBoxContainer
var status_container: VBoxContainer
var _tree_nodes: Array = []

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	layer = 5; _build_ui(); _connect_signals(); hide_panel()

func _connect_signals() -> void:
	ResearchManager.research_started.connect(_on_research_changed)
	ResearchManager.research_completed.connect(_on_research_changed)
	ResearchManager.research_cancelled.connect(_on_research_changed)
	EventBus.tech_effects_applied.connect(_on_tech_effects)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
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
	dim_bg.color = Color(0, 0, 0, 0.5)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	main_panel = PanelContainer.new()
	main_panel.anchor_right = 1.0; main_panel.anchor_bottom = 1.0
	main_panel.offset_left = 30; main_panel.offset_right = -30
	main_panel.offset_top = 30; main_panel.offset_bottom = -30
	var style := StyleBoxFlat.new()
	style.bg_color = ColorTheme.BG_SECONDARY
	style.border_color = ColorTheme.BORDER_DEFAULT
	style.set_border_width_all(2); style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	main_panel.add_theme_stylebox_override("panel", style)
	root.add_child(main_panel)
	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	main_panel.add_child(outer_vbox)

	# Header
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header_row)
	header_label = Label.new()
	header_label.text = "Research Tree"
	header_label.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING + 2)
	header_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)
	btn_close = Button.new()
	btn_close.text = "X"; btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	status_container = VBoxContainer.new()
	status_container.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(status_container)
	outer_vbox.add_child(HSeparator.new())

	# Content: left tree + right detail
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 10)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_hbox)
	tree_scroll = ScrollContainer.new()
	tree_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_hbox.add_child(tree_scroll)
	tree_container = VBoxContainer.new()
	tree_container.add_theme_constant_override("separation", 4)
	tree_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_scroll.add_child(tree_container)

	detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(340, 0); detail_panel.visible = false
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.07, 0.06, 0.12, 0.95)
	ds.border_color = Color(0.3, 0.45, 0.5)
	ds.set_border_width_all(1); ds.set_corner_radius_all(6); ds.set_content_margin_all(12)
	detail_panel.add_theme_stylebox_override("panel", ds)
	content_hbox.add_child(detail_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(detail_scroll)
	detail_container = VBoxContainer.new()
	detail_container.add_theme_constant_override("separation", 6)
	detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_container)

# ═══════════════ PUBLIC API ═══════════════

func show_panel() -> void:
	_visible = true; root.visible = true
	_selected_tech_id = ""; detail_panel.visible = false; _refresh()

func hide_panel() -> void:
	AudioManager.play_ui_cancel()
	_visible = false; root.visible = false

func is_panel_visible() -> bool:
	return _visible

# ═══════════════ REFRESH ═══════════════

func _refresh() -> void:
	_refresh_status(); _refresh_tree()
	if _selected_tech_id != "": _refresh_detail()

func _refresh_status() -> void:
	for child in status_container.get_children(): child.queue_free()
	var pid: int = GameManager.get_human_player_id()
	var current: String = ResearchManager.get_current_research(pid)
	var progress: int = ResearchManager.get_research_progress(pid)
	var speed: float = ResearchManager.get_research_speed(pid)
	if current == "":
		var lbl := Label.new()
		lbl.text = "No current research"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		status_container.add_child(lbl)
	else:
		var data: Dictionary = ResearchManager.get_tech_data(current)
		var turns_needed: int = data.get("turns", 1)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		status_container.add_child(row)
		var lbl := Label.new()
		lbl.text = "Researching: %s  [%d/%d turns]  Speed: %.1f" % [data.get("name", current), progress, turns_needed, speed]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var bar := ProgressBar.new()
		bar.min_value = 0; bar.max_value = turns_needed; bar.value = progress
		bar.custom_minimum_size = Vector2(180, 16); bar.show_percentage = false
		row.add_child(bar)
		var btn_cancel := Button.new()
		btn_cancel.text = "Cancel Research"; btn_cancel.custom_minimum_size = Vector2(100, 28)
		btn_cancel.add_theme_font_size_override("font_size", 12)
		btn_cancel.pressed.connect(_on_cancel_research)
		row.add_child(btn_cancel)
	# Research queue
	var queue: Array = ResearchManager.get_research_queue(pid)
	if not queue.is_empty():
		var names: Array = []
		for tid in queue: names.append(ResearchManager.get_tech_name(tid))
		var ql := Label.new()
		ql.text = "Queue: %s" % " -> ".join(names)
		ql.add_theme_font_size_override("font_size", 12)
		ql.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		status_container.add_child(ql)

func _refresh_tree() -> void:
	for node in _tree_nodes:
		if is_instance_valid(node): node.queue_free()
	_tree_nodes.clear()
	var pid: int = GameManager.get_human_player_id()
	var completed: Array = ResearchManager.get_completed_techs(pid)
	var current: String = ResearchManager.get_current_research(pid)
	var queue: Array = ResearchManager.get_research_queue(pid)
	var available_ids: Array = []
	for a in ResearchManager.get_available_techs(pid): available_ids.append(a["id"])

	# Group by branch
	var branches: Dictionary = {}
	for tech_id in ResearchManager._active_tree:
		var data: Dictionary = ResearchManager._active_tree[tech_id]
		var branch: String = data.get("branch", "General")
		if not branches.has(branch): branches[branch] = []
		branches[branch].append({"id": tech_id, "data": data})
	if branches.is_empty():
		var lbl := Label.new()
		lbl.text = "No research available (build an academy first)"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		tree_container.add_child(lbl); _tree_nodes.append(lbl); return

	for branch_name in branches:
		# Branch header with horizontal line
		var branch_row := HBoxContainer.new()
		branch_row.add_theme_constant_override("separation", 8)
		tree_container.add_child(branch_row); _tree_nodes.append(branch_row)
		var line_left := HSeparator.new()
		line_left.custom_minimum_size.x = 20
		line_left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		branch_row.add_child(line_left)
		var bl := Label.new()
		bl.text = branch_name
		bl.add_theme_font_size_override("font_size", 15)
		bl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.5))
		branch_row.add_child(bl)
		var line_right := HSeparator.new()
		line_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		branch_row.add_child(line_right)

		var techs: Array = branches[branch_name]
		techs.sort_custom(func(a, b): return a["data"].get("tier", 0) < b["data"].get("tier", 0))
		for entry in techs:
			var tid: String = entry["id"]; var d: Dictionary = entry["data"]
			var state_text: String; var nc: Color; var border_color: Color
			if tid in completed: state_text = "Complete"; nc = Color(0.3, 0.9, 0.4); border_color = Color(0.2, 0.7, 0.3)
			elif tid == current: state_text = "Researching"; nc = Color(1.0, 0.9, 0.3); border_color = Color(0.8, 0.7, 0.2)
			elif tid in queue: state_text = "Queued"; nc = Color(0.8, 0.7, 0.3); border_color = Color(0.6, 0.5, 0.2)
			elif tid in available_ids: state_text = "Available"; nc = Color(0.9, 0.9, 0.95); border_color = Color(0.5, 0.5, 0.6)
			else: state_text = "Locked"; nc = Color(0.4, 0.4, 0.45); border_color = Color(0.25, 0.25, 0.3)

			var card := PanelContainer.new()
			var cs := StyleBoxFlat.new()
			cs.bg_color = Color(0.08, 0.08, 0.12, 0.85)
			cs.border_color = border_color
			cs.border_width_left = 4
			cs.border_width_top = 1; cs.border_width_right = 1; cs.border_width_bottom = 1
			cs.set_corner_radius_all(4)
			cs.set_content_margin_all(8)
			card.add_theme_stylebox_override("panel", cs)
			card.custom_minimum_size = Vector2(0, 38)

			var card_hbox := HBoxContainer.new()
			card_hbox.add_theme_constant_override("separation", 8)
			card.add_child(card_hbox)

			# Tier badge
			var tier_lbl := Label.new()
			tier_lbl.text = "T%d" % d.get("tier", 0)
			tier_lbl.add_theme_font_size_override("font_size", 11)
			tier_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			tier_lbl.custom_minimum_size.x = 24
			card_hbox.add_child(tier_lbl)

			# Tech name
			var name_lbl := Label.new()
			name_lbl.text = d.get("name", tid)
			name_lbl.add_theme_font_size_override("font_size", 13)
			name_lbl.add_theme_color_override("font_color", nc)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card_hbox.add_child(name_lbl)

			# Status badge
			var status_lbl := Label.new()
			status_lbl.text = state_text
			status_lbl.add_theme_font_size_override("font_size", 10)
			status_lbl.add_theme_color_override("font_color", nc.darkened(0.2))
			card_hbox.add_child(status_lbl)

			# Turns info
			var turns_lbl := Label.new()
			turns_lbl.text = "%dt" % d.get("turns", 1)
			turns_lbl.add_theme_font_size_override("font_size", 10)
			turns_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			card_hbox.add_child(turns_lbl)

			# Make clickable
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.gui_input.connect(_on_tech_card_input.bind(tid))

			# Show prerequisite indicator
			var prereqs: Array = d.get("prereqs", [])
			if not prereqs.is_empty():
				var pnames: Array = []
				for p in prereqs:
					var pd: Dictionary = ResearchManager.get_tech_data(p)
					var pname: String = pd.get("name", p)
					var done: bool = p in completed
					pnames.append("[color=%s]%s[/color]" % ["green" if done else "red", pname])
				var req_rtl := RichTextLabel.new()
				req_rtl.bbcode_enabled = true
				req_rtl.fit_content = true
				req_rtl.scroll_active = false
				req_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				req_rtl.custom_minimum_size = Vector2(0, 18)
				req_rtl.add_theme_font_size_override("normal_font_size", 10)
				req_rtl.text = "    Requires: %s" % ", ".join(pnames)
				tree_container.add_child(card); _tree_nodes.append(card)
				tree_container.add_child(req_rtl); _tree_nodes.append(req_rtl)
			else:
				tree_container.add_child(card); _tree_nodes.append(card)

func _refresh_detail() -> void:
	for child in detail_container.get_children(): child.queue_free()
	if _selected_tech_id == "": return
	var pid: int = GameManager.get_human_player_id()
	var data: Dictionary = ResearchManager.get_tech_data(_selected_tech_id)
	if data.is_empty(): return
	var completed: Array = ResearchManager.get_completed_techs(pid)
	var current: String = ResearchManager.get_current_research(pid)
	var available_ids: Array = []
	for a in ResearchManager.get_available_techs(pid): available_ids.append(a["id"])

	# Name & meta
	var nl := Label.new()
	nl.text = data.get("name", _selected_tech_id)
	nl.add_theme_font_size_override("font_size", 18)
	nl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	detail_container.add_child(nl)
	var ml := Label.new()
	ml.text = "Branch: %s  |  Tier: T%d" % [data.get("branch", "?"), data.get("tier", 0)]
	ml.add_theme_font_size_override("font_size", 12)
	ml.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	detail_container.add_child(ml)
	detail_container.add_child(HSeparator.new())
	# Description
	var dl := Label.new()
	dl.text = data.get("desc", "No description"); dl.add_theme_font_size_override("font_size", 13)
	dl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_container.add_child(dl)
	# Cost
	var cost: Dictionary = data.get("cost", {})
	if not cost.is_empty():
		var parts: Array = []
		for key in cost: parts.append("%s: %d" % [key, cost[key]])
		var cl := Label.new()
		cl.text = "Cost: %s" % ", ".join(parts)
		cl.add_theme_font_size_override("font_size", 12)
		cl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
		detail_container.add_child(cl)
	# Turns
	var tl := Label.new()
	tl.text = "Research turns: %d" % data.get("turns", 1)
	tl.add_theme_font_size_override("font_size", 12)
	tl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	detail_container.add_child(tl)
	# Prerequisites
	var prereqs: Array = data.get("prereqs", [])
	if not prereqs.is_empty():
		var pn: Array = []
		for p in prereqs:
			var pd: Dictionary = ResearchManager.get_tech_data(p)
			pn.append(pd.get("name", p) + (" (done)" if p in completed else ""))
		var pl := Label.new()
		pl.text = "Requires: %s" % ", ".join(pn)
		pl.add_theme_font_size_override("font_size", 12)
		pl.add_theme_color_override("font_color", Color(0.7, 0.5, 0.4))
		pl.autowrap_mode = TextServer.AUTOWRAP_WORD
		detail_container.add_child(pl)
	# Effects
	var effects: Dictionary = data.get("effects", {})
	if not effects.is_empty():
		detail_container.add_child(HSeparator.new())
		var et := Label.new()
		et.text = "Effects:"; et.add_theme_font_size_override("font_size", 13)
		et.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
		detail_container.add_child(et)
		for key in effects:
			var el := Label.new()
			el.text = "  %s: %s" % [key, str(effects[key])]
			el.add_theme_font_size_override("font_size", 11)
			el.add_theme_color_override("font_color", Color(0.6, 0.75, 0.6))
			el.autowrap_mode = TextServer.AUTOWRAP_WORD
			detail_container.add_child(el)
	# Action button
	detail_container.add_child(HSeparator.new())
	if _selected_tech_id in completed:
		var done := Label.new()
		done.text = "Complete"; done.add_theme_font_size_override("font_size", 14)
		done.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
		detail_container.add_child(done)
	elif _selected_tech_id in available_ids:
		var bs := Button.new()
		bs.text = "Start Research" if current == "" else "Queue Research"
		bs.custom_minimum_size = Vector2(140, 34)
		bs.add_theme_font_size_override("font_size", 14)
		bs.pressed.connect(_on_start_research.bind(_selected_tech_id))
		var bs_style := StyleBoxFlat.new()
		bs_style.bg_color = Color(0.15, 0.25, 0.15, 0.9)
		bs_style.border_color = Color(0.3, 0.7, 0.3)
		bs_style.set_border_width_all(1)
		bs_style.set_corner_radius_all(6)
		bs_style.set_content_margin_all(6)
		bs.add_theme_stylebox_override("normal", bs_style)
		bs.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		detail_container.add_child(bs)
	else:
		var ll := Label.new()
		ll.text = "Prerequisites not met"; ll.add_theme_font_size_override("font_size", 13)
		ll.add_theme_color_override("font_color", Color(0.5, 0.4, 0.4))
		detail_container.add_child(ll)

# ═══════════════ CALLBACKS ═══════════════

func _on_tech_card_input(event: InputEvent, tech_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_select_tech(tech_id)

func _on_select_tech(tech_id: String) -> void:
	AudioManager.play_ui_click()
	_selected_tech_id = tech_id; detail_panel.visible = true; _refresh_detail()

func _on_start_research(tech_id: String) -> void:
	AudioManager.play_ui_confirm()
	ResearchManager.start_research(GameManager.get_human_player_id(), tech_id); _refresh()

func _on_cancel_research() -> void:
	AudioManager.play_ui_click()
	ResearchManager.cancel_research(GameManager.get_human_player_id()); _refresh()

func _on_research_changed(_pid: int, _tech_id: String) -> void:
	if _visible: _refresh()

func _on_tech_effects(_pid: int) -> void:
	if _visible: _refresh()

func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: hide_panel()
