## combat_intervention_panel.gd - Mid-battle Commander Intervention UI
## Shows available interventions during combat rounds when player has CP.
## Appears on the right side of the screen with dark/gold pixel-art theme.
extends CanvasLayer

signal intervention_decided(intervention_type: int, target: Variant)
signal intervention_skipped()

# ── Theme colors ──
const BG_COLOR := Color(0.08, 0.06, 0.12, 0.95)
const GOLD := Color(0.85, 0.7, 0.3)
const GOLD_DIM := Color(0.55, 0.45, 0.2)
const GOLD_BRIGHT := Color(1.0, 0.85, 0.4)
const TEXT_COLOR := Color(0.9, 0.88, 0.82)
const DISABLED_COLOR := Color(0.35, 0.32, 0.28)
const CP_BAR_BG := Color(0.15, 0.12, 0.2)
const CP_BAR_FILL := Color(0.2, 0.55, 0.85)
const HOVER_COLOR := Color(0.14, 0.11, 0.2, 0.95)
const CARD_BG := Color(0.1, 0.08, 0.15)
const CARD_BORDER := Color(0.4, 0.32, 0.18)
const CARD_DISABLED_BG := Color(0.07, 0.06, 0.09)
const CARD_DISABLED_BORDER := Color(0.2, 0.18, 0.15)
const PANEL_WIDTH := 380.0

# ── State ──
var _state: Dictionary = {}
var _card_buttons: Array = []  # Array of {button, type, data}
var _target_selector: VBoxContainer = null
var _pending_type: int = -1

# ── UI refs ──
var root: PanelContainer
var main_vbox: VBoxContainer
var cp_label: Label
var cp_bar_fill: ColorRect
var cp_bar_bg: ColorRect
var scroll: ScrollContainer
var card_container: VBoxContainer
var skip_btn: Button
var title_label: Label
var round_label: Label

func _ready() -> void:
	layer = 25
	visible = false
	_build_ui()

# ═══════════════════════════════════════════════════════════
#                        PUBLIC API
# ═══════════════════════════════════════════════════════════

func show_panel(state: Dictionary) -> void:
	_state = state
	_pending_type = -1
	visible = true
	_refresh()

func hide_panel() -> void:
	visible = false
	_clear_target_selector()

# ═══════════════════════════════════════════════════════════
#                        BUILD UI
# ═══════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = PanelContainer.new()
	root.anchor_left = 1.0; root.anchor_right = 1.0
	root.anchor_top = 0.0; root.anchor_bottom = 1.0
	root.offset_left = -PANEL_WIDTH - 16; root.offset_right = -16
	root.offset_top = 60; root.offset_bottom = -60
	root.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR, GOLD_DIM, 2))
	add_child(root)

	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	root.add_child(main_vbox)

	# ── Header ──
	title_label = Label.new()
	title_label.text = "指挥干预"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	title_label.add_theme_font_size_override("font_size", 20)
	main_vbox.add_child(title_label)

	round_label = Label.new()
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_color_override("font_color", GOLD_DIM)
	round_label.add_theme_font_size_override("font_size", 13)
	main_vbox.add_child(round_label)

	main_vbox.add_child(_make_hsep())

	# ── CP display ──
	cp_label = Label.new()
	cp_label.add_theme_color_override("font_color", TEXT_COLOR)
	cp_label.add_theme_font_size_override("font_size", 15)
	main_vbox.add_child(cp_label)

	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(0, 12)
	main_vbox.add_child(bar_container)

	cp_bar_bg = ColorRect.new()
	cp_bar_bg.color = CP_BAR_BG
	cp_bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_container.add_child(cp_bar_bg)

	cp_bar_fill = ColorRect.new()
	cp_bar_fill.color = CP_BAR_FILL
	cp_bar_fill.anchor_top = 0.0; cp_bar_fill.anchor_bottom = 1.0
	cp_bar_fill.anchor_left = 0.0; cp_bar_fill.anchor_right = 0.0
	bar_container.add_child(cp_bar_fill)

	main_vbox.add_child(_make_hsep())

	# ── Scrollable card list ──
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	card_container = VBoxContainer.new()
	card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_container.add_theme_constant_override("separation", 6)
	scroll.add_child(card_container)

	# ── Skip button ──
	skip_btn = _make_styled_button("跳过 (不干预)", GOLD_DIM)
	skip_btn.pressed.connect(_on_skip)
	main_vbox.add_child(skip_btn)

# ═══════════════════════════════════════════════════════════
#                       REFRESH
# ═══════════════════════════════════════════════════════════

func _refresh() -> void:
	var cp: int = CommanderIntervention.get_current_cp()
	var max_cp: int = CommanderIntervention.get_max_cp()
	var round_num: int = _state.get("round", 0)

	round_label.text = "第 %d 回合" % round_num
	cp_label.text = "指挥点数: %d/%d" % [cp, max_cp]

	# Update CP bar
	var ratio: float = float(cp) / max(1, max_cp)
	cp_bar_fill.anchor_right = ratio

	# Clear old cards
	for child in card_container.get_children():
		child.queue_free()
	_card_buttons.clear()
	_clear_target_selector()

	# Build intervention cards
	for type_key in CommanderIntervention.INTERVENTION_DATA:
		var data: Dictionary = CommanderIntervention.INTERVENTION_DATA[type_key]
		var can_use: bool = CommanderIntervention.can_use(type_key)
		var cooldown_left: int = CommanderIntervention._cooldowns.get(type_key, 0)
		var enough_cp: bool = cp >= data["cp_cost"]
		_build_card(type_key, data, can_use, cooldown_left, enough_cp)

func _build_card(type_key: int, data: Dictionary, can_use: bool, cooldown: int, enough_cp: bool) -> void:
	var card := PanelContainer.new()
	var bg_col: Color = CARD_BG if can_use else CARD_DISABLED_BG
	var border_col: Color = CARD_BORDER if can_use else CARD_DISABLED_BORDER
	card.add_theme_stylebox_override("panel", _make_panel_style(bg_col, border_col, 1))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# Row 1: Name + CP cost
	var row1 := HBoxContainer.new()
	vbox.add_child(row1)
	var name_lbl := Label.new()
	name_lbl.text = data["name"]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_color_override("font_color", GOLD_BRIGHT if can_use else DISABLED_COLOR)
	name_lbl.add_theme_font_size_override("font_size", 15)
	row1.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "CP:%d" % data["cp_cost"]
	cost_lbl.add_theme_color_override("font_color", CP_BAR_FILL if enough_cp else Color(0.8, 0.2, 0.2))
	cost_lbl.add_theme_font_size_override("font_size", 13)
	row1.add_child(cost_lbl)

	# Row 2: Description
	var desc_lbl := Label.new()
	desc_lbl.text = data["desc"]
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_color_override("font_color", TEXT_COLOR if can_use else DISABLED_COLOR)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(desc_lbl)

	# Row 3: Status (cooldown or ready)
	var status_lbl := Label.new()
	if cooldown > 0:
		status_lbl.text = "冷却中: %d 回合" % cooldown
		status_lbl.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	elif not enough_cp:
		status_lbl.text = "CP不足"
		status_lbl.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	else:
		status_lbl.text = "可用"
		status_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
	status_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(status_lbl)

	# Make clickable if usable
	if can_use:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_card_input.bind(type_key, data, card))
		card.mouse_entered.connect(_on_card_hover.bind(card, true))
		card.mouse_exited.connect(_on_card_hover.bind(card, false))
	else:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.modulate = Color(0.6, 0.6, 0.6, 0.8)

	card_container.add_child(card)
	_card_buttons.append({"panel": card, "type": type_key, "data": data})

# ═══════════════════════════════════════════════════════════
#                    INPUT HANDLERS
# ═══════════════════════════════════════════════════════════

func _on_card_input(event: InputEvent, type_key: int, data: Dictionary, _card: PanelContainer) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if data.get("requires_target", false):
			_show_target_selector(type_key, data)
		else:
			_execute_intervention(type_key, null)

func _on_card_hover(card: PanelContainer, entering: bool) -> void:
	if entering:
		card.add_theme_stylebox_override("panel", _make_panel_style(HOVER_COLOR, GOLD, 1))
	else:
		card.add_theme_stylebox_override("panel", _make_panel_style(CARD_BG, CARD_BORDER, 1))

func _on_skip() -> void:
	hide_panel()
	intervention_skipped.emit()
	# Bridge to EventBus so combat_system.gd's await resolves
	EventBus.combat_intervention_chosen.emit(-1, null)

func _execute_intervention(type_key: int, target: Variant) -> void:
	# Don't execute here -- the CombatSystem will execute after receiving the signal.
	# Just validate that it's still usable and emit the decision.
	if CommanderIntervention.can_use(type_key):
		hide_panel()
		intervention_decided.emit(type_key, target)
		# Bridge to EventBus so combat_system.gd's await resolves
		EventBus.combat_intervention_chosen.emit(type_key, target)
	else:
		# Refresh to show updated state (e.g. insufficient CP now)
		_refresh()

# ═══════════════════════════════════════════════════════════
#                   TARGET SELECTOR
# ═══════════════════════════════════════════════════════════

func _show_target_selector(type_key: int, data: Dictionary) -> void:
	_clear_target_selector()
	_pending_type = type_key

	_target_selector = VBoxContainer.new()
	_target_selector.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "选择目标:"
	header.add_theme_color_override("font_color", GOLD)
	header.add_theme_font_size_override("font_size", 14)
	_target_selector.add_child(header)

	# Determine target list based on intervention type
	var targets: Array = _get_targets_for_type(type_key)
	for t in targets:
		var btn := _make_styled_button(t["label"], CARD_BORDER)
		btn.pressed.connect(_on_target_selected.bind(t["value"]))
		_target_selector.add_child(btn)

	# Cancel button
	var cancel := _make_styled_button("取消", Color(0.5, 0.2, 0.2))
	cancel.pressed.connect(_clear_target_selector)
	_target_selector.add_child(cancel)

	main_vbox.add_child(_target_selector)

func _get_targets_for_type(type_key: int) -> Array:
	var targets: Array = []
	var CI := CommanderIntervention
	match type_key:
		CI.InterventionType.REDIRECT_FIRE, CI.InterventionType.FOCUS_VOLLEY:
			# Enemy units
			var def_units: Array = _state.get("def_units", [])
			for i in range(def_units.size()):
				var u: Dictionary = def_units[i]
				if u.get("is_alive", false):
					targets.append({
						"label": "%s (兵:%d)" % [u.get("unit_type", "单位%d" % i), u.get("soldiers", 0)],
						"value": i
					})
		CI.InterventionType.HERO_SKILL_NOW:
			# Ally heroes
			var atk_units: Array = _state.get("atk_units", [])
			for u in atk_units:
				if u.get("is_alive", false) and u.get("hero_id", "") != "":
					var skill_name: String = u.get("active_skill", {}).get("name", "技能")
					targets.append({
						"label": "%s (%s)" % [u["hero_id"], skill_name],
						"value": u["hero_id"]
					})
		CI.InterventionType.FORMATION_SHIFT:
			# Pairs of front/back units
			var atk_units: Array = _state.get("atk_units", [])
			var front: Array = []
			var back: Array = []
			for u in atk_units:
				if u.get("is_alive", false):
					if u.get("row", "") == "front":
						front.append(u)
					elif u.get("row", "") == "back":
						back.append(u)
			for f in front:
				for b in back:
					targets.append({
						"label": "%s <-> %s" % [f.get("unit_type", "?"), b.get("unit_type", "?")],
						"value": [f["slot"], b["slot"]]
					})
		CI.InterventionType.TACTICAL_RETREAT:
			# Ally units
			var atk_units: Array = _state.get("atk_units", [])
			for u in atk_units:
				if u.get("is_alive", false):
					targets.append({
						"label": "%s (兵:%d)" % [u.get("unit_type", "?"), u.get("soldiers", 0)],
						"value": u.get("slot", 0)
					})
	return targets

func _on_target_selected(target_value: Variant) -> void:
	if _pending_type >= 0:
		_execute_intervention(_pending_type, target_value)

func _clear_target_selector() -> void:
	if _target_selector and is_instance_valid(_target_selector):
		_target_selector.queue_free()
	_target_selector = null
	_pending_type = -1

# ═══════════════════════════════════════════════════════════
#                      STYLING
# ═══════════════════════════════════════════════════════════

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
