## espionage_panel.gd - Full panel for managing spy operations.
## Shows intel/counter-intel bars, invest button, 8 operation cards, and results log.
## Toggled via HUD button. Connected to EventBus.spy_operation_result for live updates.
extends CanvasLayer

signal panel_closed()

# ── Theme colors ──
const BG_COLOR := Color(0.08, 0.06, 0.12, 0.95)
const GOLD := Color(0.85, 0.7, 0.3)
const GOLD_DIM := Color(0.55, 0.45, 0.2)
const GOLD_BRIGHT := Color(1.0, 0.85, 0.4)
const TEXT_COLOR := Color(0.9, 0.88, 0.82)
const DISABLED_COLOR := Color(0.35, 0.32, 0.28)
const HOVER_COLOR := Color(0.14, 0.11, 0.2, 0.95)
const CARD_BG := Color(0.1, 0.08, 0.15)
const CARD_BORDER := Color(0.4, 0.32, 0.18)
const CARD_DISABLED_BG := Color(0.07, 0.06, 0.09)
const CARD_DISABLED_BORDER := Color(0.2, 0.18, 0.15)
const INTEL_BAR_FILL := Color(0.2, 0.55, 0.85)
const COUNTER_BAR_FILL := Color(0.7, 0.3, 0.6)
const SUCCESS_COLOR := Color(0.3, 0.8, 0.35)
const FAIL_COLOR := Color(0.85, 0.25, 0.25)
const PANEL_WIDTH := 820.0

# ── Operation descriptions ──
const OP_DESCS: Dictionary = {
	0: "侦察目标格, 揭露军事情报",
	1: "破坏建筑, 产出-20%持续2回合",
	2: "暗杀敌方英雄 (击杀/负伤/失败)",
	3: "窃取目标阵营一项随机科技",
	4: "煽动目标格叛乱, 民心-40",
	5: "降低目标阵营英雄好感与声望",
	6: "截获命令, 下回合查看敌方行动",
	7: "栽赃嫁祸, 目标与第三方外交-15",
}

# ── Target type per operation ──
const OP_TARGET_TYPE: Dictionary = {
	0: "tile",      # SCOUT
	1: "tile",      # SABOTAGE
	2: "faction",   # ASSASSINATE
	3: "faction",   # STEAL_TECH
	4: "tile",      # INCITE_REVOLT
	5: "faction",   # SPREAD_RUMORS
	6: "faction",   # INTERCEPT_ORDERS
	7: "faction",   # PLANT_EVIDENCE
}

# ── State ──
var _player_id: int = 0
var _results_log: Array = []  # last 5 results
var _card_panels: Array = []  # Array of { panel, op_type }
var _target_popup: PanelContainer = null
var _pending_op: int = -1

# ── UI refs ──
var root: PanelContainer
var main_vbox: VBoxContainer
var intel_label: Label
var intel_bar_fill: ColorRect
var counter_label: Label
var counter_bar_fill: ColorRect
var invest_btn: Button
var card_grid: GridContainer
var log_vbox: VBoxContainer
var close_btn: Button
var title_label: Label

func _ready() -> void:
	layer = 25
	visible = false
	_build_ui()
	if EventBus:
		EventBus.spy_operation_result.connect(_on_spy_result)
		if EventBus.has_signal("intel_changed"):
			EventBus.intel_changed.connect(_on_intel_changed)

# ═════════════════════════════════════════════════
#                  PUBLIC API
# ═════════════════════════════════════════════════

func show_panel(player_id: int) -> void:
	_player_id = player_id
	visible = true
	_refresh()

func hide_panel() -> void:
	visible = false
	_clear_target_popup()

func toggle_panel(player_id: int) -> void:
	if visible:
		hide_panel()
	else:
		show_panel(player_id)

# ═════════════════════════════════════════════════
#                   BUILD UI
# ═════════════════════════════════════════════════

func _build_ui() -> void:
	# Dim background
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.4)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(_on_dimmer_input)
	add_child(dimmer)

	root = PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.anchor_left = 0.5; root.anchor_right = 0.5
	root.anchor_top = 0.5; root.anchor_bottom = 0.5
	root.offset_left = -PANEL_WIDTH * 0.5; root.offset_right = PANEL_WIDTH * 0.5
	root.offset_top = -310; root.offset_bottom = 310
	root.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR, GOLD, 2))
	add_child(root)

	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	root.add_child(main_vbox)

	_build_header()
	main_vbox.add_child(_make_hsep())
	_build_intel_section()
	main_vbox.add_child(_make_hsep())
	_build_card_grid()
	main_vbox.add_child(_make_hsep())
	_build_log_section()

func _build_header() -> void:
	var hbox := HBoxContainer.new()
	main_vbox.add_child(hbox)

	title_label = Label.new()
	title_label.text = "🕵 谍报中心"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	title_label.add_theme_font_size_override("font_size", 20)
	hbox.add_child(title_label)

	close_btn = _make_styled_button("✕", Color(0.5, 0.2, 0.2))
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.pressed.connect(_on_close)
	hbox.add_child(close_btn)

func _build_intel_section() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(hbox)

	# Intel bar
	var intel_col := VBoxContainer.new()
	intel_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intel_col.add_theme_constant_override("separation", 3)
	hbox.add_child(intel_col)

	intel_label = Label.new()
	intel_label.text = "情报: 0/100"
	intel_label.add_theme_color_override("font_color", TEXT_COLOR)
	intel_label.add_theme_font_size_override("font_size", 14)
	intel_col.add_child(intel_label)

	var intel_bar_ct := Control.new()
	intel_bar_ct.custom_minimum_size = Vector2(0, 14)
	intel_col.add_child(intel_bar_ct)

	var intel_bg := ColorRect.new()
	intel_bg.color = Color(0.15, 0.12, 0.2)
	intel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intel_bar_ct.add_child(intel_bg)

	intel_bar_fill = ColorRect.new()
	intel_bar_fill.color = INTEL_BAR_FILL
	intel_bar_fill.anchor_top = 0.0; intel_bar_fill.anchor_bottom = 1.0
	intel_bar_fill.anchor_left = 0.0; intel_bar_fill.anchor_right = 0.0
	intel_bar_ct.add_child(intel_bar_fill)

	# Counter-intel bar
	var counter_col := VBoxContainer.new()
	counter_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counter_col.add_theme_constant_override("separation", 3)
	hbox.add_child(counter_col)

	counter_label = Label.new()
	counter_label.text = "反谍: 0/100"
	counter_label.add_theme_color_override("font_color", TEXT_COLOR)
	counter_label.add_theme_font_size_override("font_size", 14)
	counter_col.add_child(counter_label)

	var counter_bar_ct := Control.new()
	counter_bar_ct.custom_minimum_size = Vector2(0, 14)
	counter_col.add_child(counter_bar_ct)

	var counter_bg := ColorRect.new()
	counter_bg.color = Color(0.15, 0.12, 0.2)
	counter_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	counter_bar_ct.add_child(counter_bg)

	counter_bar_fill = ColorRect.new()
	counter_bar_fill.color = COUNTER_BAR_FILL
	counter_bar_fill.anchor_top = 0.0; counter_bar_fill.anchor_bottom = 1.0
	counter_bar_fill.anchor_left = 0.0; counter_bar_fill.anchor_right = 0.0
	counter_bar_ct.add_child(counter_bar_fill)

	# Invest button
	var invest_col := VBoxContainer.new()
	invest_col.add_theme_constant_override("separation", 3)
	hbox.add_child(invest_col)

	invest_btn = _make_styled_button("投资情报 (10金=1点)", GOLD)
	invest_btn.custom_minimum_size = Vector2(180, 0)
	invest_btn.pressed.connect(_on_invest)
	invest_col.add_child(invest_btn)

func _build_card_grid() -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	card_grid = GridContainer.new()
	card_grid.columns = 4
	card_grid.add_theme_constant_override("h_separation", 8)
	card_grid.add_theme_constant_override("v_separation", 8)
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card_grid)

func _build_log_section() -> void:
	var header := Label.new()
	header.text = "行动记录"
	header.add_theme_color_override("font_color", GOLD_DIM)
	header.add_theme_font_size_override("font_size", 13)
	main_vbox.add_child(header)

	log_vbox = VBoxContainer.new()
	log_vbox.add_theme_constant_override("separation", 2)
	log_vbox.custom_minimum_size = Vector2(0, 70)
	main_vbox.add_child(log_vbox)

# ═════════════════════════════════════════════════
#                   REFRESH
# ═════════════════════════════════════════════════

func _refresh() -> void:
	_refresh_intel_bars()
	_refresh_cards()
	_refresh_log()

func _refresh_intel_bars() -> void:
	var intel: int = 0
	var counter: int = 0
	if EspionageSystem:
		intel = EspionageSystem.get_intel(_player_id)
		counter = EspionageSystem.get_counter_intel(_player_id)
	intel_label.text = "情报: %d/100" % intel
	intel_bar_fill.anchor_right = intel / 100.0
	counter_label.text = "反谍: %d/100" % counter
	counter_bar_fill.anchor_right = counter / 100.0

func _refresh_cards() -> void:
	for child in card_grid.get_children():
		child.queue_free()
	_card_panels.clear()

	var cooldowns: Dictionary = {}
	var intel: int = 0
	if EspionageSystem:
		cooldowns = EspionageSystem.get_operation_cooldowns(_player_id)
		intel = EspionageSystem.get_intel(_player_id)

	for op_type in EspionageSystem.OPERATION_DEFS:
		var op_def: Dictionary = EspionageSystem.OPERATION_DEFS[op_type]
		var cd: int = cooldowns.get(op_type, 0)
		var can_afford_gold: bool = true
		if ResourceManager and ResourceManager.has_method("can_afford"):
			can_afford_gold = ResourceManager.can_afford(_player_id, {"gold": op_def["gold"]})
		var has_intel: bool = intel >= op_def["intel"]
		var can_use: bool = cd <= 0 and can_afford_gold and has_intel
		_build_op_card(op_type, op_def, can_use, cd, can_afford_gold, has_intel)

func _build_op_card(op_type: int, op_def: Dictionary, can_use: bool, cd: int, has_gold: bool, has_intel: bool) -> void:
	var card := PanelContainer.new()
	var bg_col: Color = CARD_BG if can_use else CARD_DISABLED_BG
	var border_col: Color = CARD_BORDER if can_use else CARD_DISABLED_BORDER
	card.add_theme_stylebox_override("panel", _make_panel_style(bg_col, border_col, 1))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(180, 0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	card.add_child(vb)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = op_def["name"]
	name_lbl.add_theme_color_override("font_color", GOLD_BRIGHT if can_use else DISABLED_COLOR)
	name_lbl.add_theme_font_size_override("font_size", 14)
	vb.add_child(name_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = OP_DESCS.get(op_type, "")
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", TEXT_COLOR if can_use else DISABLED_COLOR)
	desc_lbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(desc_lbl)

	# Cost row
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 8)
	vb.add_child(cost_row)

	var gold_lbl := Label.new()
	gold_lbl.text = "金:%d" % op_def["gold"]
	gold_lbl.add_theme_color_override("font_color", GOLD if has_gold else FAIL_COLOR)
	gold_lbl.add_theme_font_size_override("font_size", 11)
	cost_row.add_child(gold_lbl)

	var intel_lbl := Label.new()
	intel_lbl.text = "情报:%d" % op_def["intel"]
	intel_lbl.add_theme_color_override("font_color", INTEL_BAR_FILL if has_intel else FAIL_COLOR)
	intel_lbl.add_theme_font_size_override("font_size", 11)
	cost_row.add_child(intel_lbl)

	var success_lbl := Label.new()
	success_lbl.text = "成功:%d%%" % op_def["success"]
	success_lbl.add_theme_color_override("font_color", SUCCESS_COLOR if op_def["success"] >= 50 else FAIL_COLOR)
	success_lbl.add_theme_font_size_override("font_size", 11)
	cost_row.add_child(success_lbl)

	# Status
	var status_lbl := Label.new()
	if cd > 0:
		status_lbl.text = "冷却: %d回合" % cd
		status_lbl.add_theme_color_override("font_color", FAIL_COLOR)
	elif not has_gold:
		status_lbl.text = "金币不足"
		status_lbl.add_theme_color_override("font_color", FAIL_COLOR)
	elif not has_intel:
		status_lbl.text = "情报不足"
		status_lbl.add_theme_color_override("font_color", FAIL_COLOR)
	else:
		status_lbl.text = "可执行"
		status_lbl.add_theme_color_override("font_color", SUCCESS_COLOR)
	status_lbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(status_lbl)

	# Interaction
	if can_use:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_click.bind(op_type, card))
		card.mouse_entered.connect(_on_card_hover.bind(card, true))
		card.mouse_exited.connect(_on_card_hover.bind(card, false))
	else:
		card.modulate = Color(0.6, 0.6, 0.6, 0.8)

	card_grid.add_child(card)
	_card_panels.append({"panel": card, "op_type": op_type})

func _refresh_log() -> void:
	for child in log_vbox.get_children():
		child.queue_free()
	if _results_log.is_empty():
		var empty := Label.new()
		empty.text = "暂无记录"
		empty.add_theme_color_override("font_color", DISABLED_COLOR)
		empty.add_theme_font_size_override("font_size", 11)
		log_vbox.add_child(empty)
		return
	for entry in _results_log:
		var lbl := Label.new()
		lbl.text = entry["message"]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", SUCCESS_COLOR if entry["success"] else FAIL_COLOR)
		lbl.add_theme_font_size_override("font_size", 11)
		log_vbox.add_child(lbl)

# ═════════════════════════════════════════════════
#              INPUT / CARD HANDLERS
# ═════════════════════════════════════════════════

func _on_card_click(event: InputEvent, op_type: int, card: PanelContainer) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	_show_target_popup(op_type)

func _on_card_hover(card: PanelContainer, entering: bool) -> void:
	if entering:
		card.add_theme_stylebox_override("panel", _make_panel_style(HOVER_COLOR, GOLD, 1))
	else:
		card.add_theme_stylebox_override("panel", _make_panel_style(CARD_BG, CARD_BORDER, 1))

func _on_invest() -> void:
	if EspionageSystem:
		EspionageSystem.invest_in_intel(_player_id, EspionageSystem.INTEL_COST_PER_POINT)
		_refresh()

func _on_close() -> void:
	hide_panel()
	panel_closed.emit()

func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()
		panel_closed.emit()

# ═════════════════════════════════════════════════
#             TARGET SELECTION POPUP
# ═════════════════════════════════════════════════

func _show_target_popup(op_type: int) -> void:
	_clear_target_popup()
	_pending_op = op_type

	_target_popup = PanelContainer.new()
	_target_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_target_popup.anchor_left = 0.5; _target_popup.anchor_right = 0.5
	_target_popup.anchor_top = 0.5; _target_popup.anchor_bottom = 0.5
	_target_popup.offset_left = -150; _target_popup.offset_right = 150
	_target_popup.offset_top = -100; _target_popup.offset_bottom = 100
	_target_popup.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR, GOLD, 2))
	add_child(_target_popup)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	_target_popup.add_child(vb)

	var header := Label.new()
	var target_type: String = OP_TARGET_TYPE.get(op_type, "tile")
	header.text = "选择目标格" if target_type == "tile" else "选择目标阵营"
	header.add_theme_color_override("font_color", GOLD)
	header.add_theme_font_size_override("font_size", 15)
	vb.add_child(header)

	# Build target list based on type
	if target_type == "tile":
		# Provide sample tile targets (in real game, populated from map state)
		for i in range(6):
			var btn := _make_styled_button("地块 #%d" % i, CARD_BORDER)
			btn.pressed.connect(_on_target_chosen.bind(i))
			vb.add_child(btn)
	else:
		# Faction targets
		for fid in range(1, 5):
			if fid == _player_id:
				continue
			var btn := _make_styled_button("势力 #%d" % fid, CARD_BORDER)
			btn.pressed.connect(_on_target_chosen.bind(fid))
			vb.add_child(btn)

	var cancel := _make_styled_button("取消", Color(0.5, 0.2, 0.2))
	cancel.pressed.connect(_clear_target_popup)
	vb.add_child(cancel)

func _on_target_chosen(target: int) -> void:
	if _pending_op < 0:
		return
	_clear_target_popup()
	if EspionageSystem:
		var result: Dictionary = EspionageSystem.execute_operation(_player_id, _pending_op, target)
		_add_result_to_log(result)
	_pending_op = -1
	_refresh()

func _clear_target_popup() -> void:
	if _target_popup and is_instance_valid(_target_popup):
		_target_popup.queue_free()
	_target_popup = null
	_pending_op = -1

# ═════════════════════════════════════════════════
#                RESULTS LOG
# ═════════════════════════════════════════════════

func _add_result_to_log(result: Dictionary) -> void:
	_results_log.push_front({
		"success": result.get("success", false),
		"message": result.get("message", ""),
	})
	if _results_log.size() > 5:
		_results_log.resize(5)

func _on_spy_result(player_id: int, op_type: int, success: bool, details: Dictionary) -> void:
	if player_id != _player_id:
		return
	var op_name: String = ""
	if EspionageSystem and EspionageSystem.OPERATION_DEFS.has(op_type):
		op_name = EspionageSystem.OPERATION_DEFS[op_type].get("name", "")
	var msg: String = "%s: %s" % [op_name, "成功" if success else "失败"]
	_results_log.push_front({"success": success, "message": msg})
	if _results_log.size() > 5:
		_results_log.resize(5)
	if visible:
		_refresh()

func _on_intel_changed(player_id: int, _intel: int) -> void:
	if player_id == _player_id and visible:
		_refresh_intel_bars()

# ═════════════════════════════════════════════════
#                   STYLING
# ═════════════════════════════════════════════════

func _make_panel_style(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	return s

func _make_hsep() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = GOLD_DIM
	s.set_content_margin_all(0)
	s.content_margin_top = 1; s.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", s)
	return sep

func _make_styled_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var normal := _make_panel_style(Color(0.12, 0.1, 0.16), accent, 1)
	normal.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal)
	var hover := _make_panel_style(Color(0.18, 0.14, 0.24), accent.lightened(0.3), 1)
	hover.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed := _make_panel_style(Color(0.08, 0.06, 0.12), accent, 2)
	pressed.set_content_margin_all(6)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", TEXT_COLOR)
	btn.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	btn.add_theme_font_size_override("font_size", 14)
	return btn
