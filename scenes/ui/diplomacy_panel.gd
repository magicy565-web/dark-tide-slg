## diplomacy_panel.gd - Diplomacy Panel UI for Dark Tide SLG (v2.0)
## Enhanced with Treaty tab, Reputation tab, treaty proposal popup, and color-coded relations.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Tab IDs ──
const TAB_EVIL := "evil"
const TAB_LIGHT := "light"
const TAB_NEUTRAL := "neutral"
const TAB_TREATIES := "treaties"
const TAB_REPUTATION := "reputation"

# ── Reputation tier labels (ordered ascending) ──
const REP_TIER_LABELS: Array = ["唾弃", "敌视", "冷淡", "中立", "友善", "尊敬", "盟友"]
const REP_TIER_THRESHOLDS: Array = [-100, -60, -20, -5, 20, 50, 80]
const REP_TIER_COLORS: Array = [
	Color(0.6, 0.1, 0.1), Color(1.0, 0.3, 0.2), Color(0.7, 0.5, 0.4),
	Color(0.8, 0.8, 0.5), Color(0.4, 0.8, 0.4), Color(0.3, 0.7, 1.0),
	Color(1.0, 0.85, 0.3),
]

# ── Relation color coding ──
const COLOR_HOSTILE := Color(1.0, 0.35, 0.25)
const COLOR_NEUTRAL := Color(0.9, 0.85, 0.4)
const COLOR_FRIENDLY := Color(0.35, 0.85, 0.4)
const COLOR_ALLIED := Color(1.0, 0.85, 0.3)

# ── Quick-propose treaty types (id -> display) ──
const QUICK_TREATY_TYPES: Array = ["ceasefire", "nap", "trade", "alliance"]

# ── State ──
var _visible: bool = false
var _current_tab: String = TAB_EVIL
var _reputation_history: Array = []  # [{faction_key, delta, reason, turn}]

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var tab_container: HBoxContainer
var tab_buttons: Dictionary = {}  # tab_id -> Button
var content_scroll: ScrollContainer
var content_container: VBoxContainer
var _faction_nodes: Array = []

# ── Treaty proposal popup refs ──
var _popup_overlay: Control
var _popup_panel: PanelContainer
var _popup_partner_option: OptionButton
var _popup_type_option: OptionButton
var _popup_terms_label: Label
var _popup_probability_bar: ProgressBar
var _popup_probability_label: Label
var _popup_effects_label: Label
var _popup_confirm_btn: Button
var _popup_cancel_btn: Button
var _popup_target_faction: int = -1

# ── TreatySystem reference (null-safe) ──
var _treaty_system: Node = null

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	layer = 5
	_treaty_system = _get_treaty_system()
	_build_ui()
	_build_proposal_popup()
	_connect_signals()
	hide_panel()

func _get_treaty_system() -> Node:
	if Engine.has_singleton("TreatySystem"):
		return Engine.get_singleton("TreatySystem")
	var ts = get_node_or_null("/root/TreatySystem")
	if ts: return ts
	for child in get_tree().root.get_children():
		if child is TreatySystem:
			return child
	return null

func _connect_signals() -> void:
	EventBus.faction_recruited.connect(_on_diplomacy_changed)
	EventBus.taming_changed.connect(_on_taming_changed)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.treaty_signed.connect(_on_treaty_changed)
	EventBus.treaty_broken.connect(_on_treaty_changed)
	EventBus.treaty_expired.connect(_on_treaty_changed)
	EventBus.threat_changed.connect(_on_threat_changed)
	if EventBus.has_signal("reputation_threshold_crossed"):
		EventBus.reputation_threshold_crossed.connect(_on_reputation_threshold)

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.game_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			if _visible: hide_panel()
			else: show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			if _popup_overlay and _popup_overlay.visible:
				_close_proposal_popup()
			else:
				hide_panel()
			get_viewport().set_input_as_handled()

# ═══════════════ BUILD UI ═══════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "DiplomacyRoot"
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

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header_row)
	header_label = Label.new()
	header_label.text = "Diplomacy Overview"
	header_label.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING + 2)
	header_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)
	btn_close = Button.new()
	btn_close.text = "X"; btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	# Tab buttons (5 tabs)
	tab_container = HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(tab_container)

	var tab_defs: Array = [
		[TAB_EVIL, "Evil Factions"],
		[TAB_LIGHT, "Light Alliance"],
		[TAB_NEUTRAL, "Neutral Factions"],
		[TAB_TREATIES, "Treaties"],
		[TAB_REPUTATION, "Reputation"],
	]
	for td in tab_defs:
		var btn := _make_tab_button(td[1])
		var tab_id: String = td[0]
		btn.pressed.connect(func(): _switch_tab(tab_id))
		tab_container.add_child(btn)
		tab_buttons[tab_id] = btn

	outer_vbox.add_child(HSeparator.new())
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(content_scroll)
	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 6)
	content_scroll.add_child(content_container)

# ═══════════════ PROPOSAL POPUP ═══════════════

func _build_proposal_popup() -> void:
	_popup_overlay = Control.new()
	_popup_overlay.name = "ProposalPopupOverlay"
	_popup_overlay.anchor_right = 1.0; _popup_overlay.anchor_bottom = 1.0
	_popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup_overlay.visible = false
	root.add_child(_popup_overlay)

	var popup_dim := ColorRect.new()
	popup_dim.anchor_right = 1.0; popup_dim.anchor_bottom = 1.0
	popup_dim.color = Color(0, 0, 0, 0.6)
	popup_dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _close_proposal_popup())
	_popup_overlay.add_child(popup_dim)

	_popup_panel = PanelContainer.new()
	_popup_panel.anchor_left = 0.2; _popup_panel.anchor_right = 0.8
	_popup_panel.anchor_top = 0.15; _popup_panel.anchor_bottom = 0.85
	var ps := StyleBoxFlat.new()
	ps.bg_color = ColorTheme.BG_PRIMARY
	ps.border_color = ColorTheme.ACCENT_GOLD
	ps.set_border_width_all(2); ps.set_corner_radius_all(10)
	ps.set_content_margin_all(16)
	_popup_panel.add_theme_stylebox_override("panel", ps)
	_popup_overlay.add_child(_popup_panel)

	var pvbox := VBoxContainer.new()
	pvbox.add_theme_constant_override("separation", 10)
	_popup_panel.add_child(pvbox)

	# Popup title
	var ptitle := Label.new()
	ptitle.text = "Propose Treaty"
	ptitle.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING)
	ptitle.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	ptitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pvbox.add_child(ptitle)
	pvbox.add_child(HSeparator.new())

	# Partner selector
	var partner_row := HBoxContainer.new()
	partner_row.add_theme_constant_override("separation", 8)
	pvbox.add_child(partner_row)
	var partner_lbl := Label.new()
	partner_lbl.text = "Partner:"
	partner_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	partner_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	partner_lbl.custom_minimum_size = Vector2(100, 0)
	partner_row.add_child(partner_lbl)
	_popup_partner_option = OptionButton.new()
	_popup_partner_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_partner_option.item_selected.connect(_on_popup_selection_changed)
	partner_row.add_child(_popup_partner_option)

	# Treaty type selector
	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 8)
	pvbox.add_child(type_row)
	var type_lbl := Label.new()
	type_lbl.text = "Treaty Type:"
	type_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	type_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	type_lbl.custom_minimum_size = Vector2(100, 0)
	type_row.add_child(type_lbl)
	_popup_type_option = OptionButton.new()
	_popup_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_type_option.item_selected.connect(_on_popup_selection_changed)
	type_row.add_child(_popup_type_option)

	# Terms preview
	pvbox.add_child(HSeparator.new())
	_popup_terms_label = Label.new()
	_popup_terms_label.text = "Select a partner and treaty type to see terms."
	_popup_terms_label.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	_popup_terms_label.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	_popup_terms_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	pvbox.add_child(_popup_terms_label)

	# Effects preview
	_popup_effects_label = Label.new()
	_popup_effects_label.text = ""
	_popup_effects_label.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	_popup_effects_label.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	_popup_effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	pvbox.add_child(_popup_effects_label)

	# Acceptance probability
	var prob_row := HBoxContainer.new()
	prob_row.add_theme_constant_override("separation", 8)
	pvbox.add_child(prob_row)
	var prob_lbl := Label.new()
	prob_lbl.text = "Acceptance:"
	prob_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	prob_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	prob_lbl.custom_minimum_size = Vector2(100, 0)
	prob_row.add_child(prob_lbl)
	_popup_probability_bar = ProgressBar.new()
	_popup_probability_bar.min_value = 0; _popup_probability_bar.max_value = 100
	_popup_probability_bar.value = 0
	_popup_probability_bar.custom_minimum_size = Vector2(200, 20)
	_popup_probability_bar.show_percentage = false
	var prob_bg := StyleBoxFlat.new()
	prob_bg.bg_color = Color(0.12, 0.12, 0.15, 0.8)
	prob_bg.set_corner_radius_all(4)
	_popup_probability_bar.add_theme_stylebox_override("background", prob_bg)
	var prob_fill := StyleBoxFlat.new()
	prob_fill.bg_color = Color(0.4, 0.7, 0.3)
	prob_fill.set_corner_radius_all(4)
	_popup_probability_bar.add_theme_stylebox_override("fill", prob_fill)
	prob_row.add_child(_popup_probability_bar)
	_popup_probability_label = Label.new()
	_popup_probability_label.text = "0%"
	_popup_probability_label.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	_popup_probability_label.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	prob_row.add_child(_popup_probability_label)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pvbox.add_child(spacer)

	# Confirm/Cancel buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pvbox.add_child(btn_row)
	_popup_confirm_btn = Button.new()
	_popup_confirm_btn.text = "Propose Treaty"
	_popup_confirm_btn.custom_minimum_size = Vector2(160, 36)
	_popup_confirm_btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.1, 0.3, 0.1, 0.9)
	confirm_style.border_color = Color(0.3, 0.7, 0.3)
	confirm_style.set_border_width_all(1); confirm_style.set_corner_radius_all(6)
	confirm_style.set_content_margin_all(6)
	_popup_confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	_popup_confirm_btn.pressed.connect(_on_popup_confirm)
	btn_row.add_child(_popup_confirm_btn)
	_popup_cancel_btn = Button.new()
	_popup_cancel_btn.text = "Cancel"
	_popup_cancel_btn.custom_minimum_size = Vector2(120, 36)
	_popup_cancel_btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	_popup_cancel_btn.pressed.connect(_close_proposal_popup)
	btn_row.add_child(_popup_cancel_btn)

func _open_proposal_popup(preselect_faction: int = -1) -> void:
	AudioManager.play_ui_click()
	_popup_partner_option.clear()
	_popup_type_option.clear()

	# Populate partners
	var pid: int = GameManager.get_human_player_id()
	var player_faction: int = GameManager.get_player_faction(pid)
	var factions: Array = [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]
	var idx: int = 0
	var preselect_idx: int = 0
	for fid in factions:
		if fid == player_faction: continue
		var fname: String = FactionData.FACTION_NAMES.get(fid, "Unknown")
		_popup_partner_option.add_item(fname, fid)
		if fid == preselect_faction:
			preselect_idx = idx
		idx += 1
	if _popup_partner_option.item_count > 0:
		_popup_partner_option.selected = preselect_idx

	# Populate treaty types from TreatySystem if available
	if _treaty_system:
		for t_val in TreatySystem.TreatyType.values():
			var t_name: String = TreatySystem.TREATY_NAMES.get(t_val, "Unknown")
			_popup_type_option.add_item(t_name, t_val)
	else:
		# Fallback to basic types
		var basic_types: Array = [
			["Ceasefire (停战协定)", 0], ["Non-Aggression (互不侵犯)", 1],
			["Trade Agreement (贸易协定)", 2], ["Military Access (军事通行权)", 3],
			["Defensive Alliance (防御同盟)", 4], ["Offensive Alliance (攻守同盟)", 5],
		]
		for bt in basic_types:
			_popup_type_option.add_item(bt[0], bt[1])

	_update_popup_preview()
	_popup_overlay.visible = true

func _close_proposal_popup() -> void:
	AudioManager.play_ui_cancel()
	_popup_overlay.visible = false

func _on_popup_selection_changed(_idx: int) -> void:
	_update_popup_preview()

func _update_popup_preview() -> void:
	if _popup_partner_option.item_count == 0 or _popup_type_option.item_count == 0:
		_popup_terms_label.text = "No valid options available."
		_popup_effects_label.text = ""
		_popup_probability_label.text = "0%"
		_popup_probability_bar.value = 0
		return

	var partner_id: int = _popup_partner_option.get_item_id(_popup_partner_option.selected)
	var treaty_type_id: int = _popup_type_option.get_item_id(_popup_type_option.selected)
	var partner_name: String = FactionData.FACTION_NAMES.get(partner_id, "Unknown")
	var faction_key: String = _get_faction_key(partner_id)

	# Terms text
	var duration: int = -1
	var rep_threshold: int = 0
	var break_penalty: int = 0
	if _treaty_system:
		duration = TreatySystem.TREATY_DEFAULT_DURATION.get(treaty_type_id, -1)
		rep_threshold = TreatySystem.TREATY_REP_THRESHOLD.get(treaty_type_id, 0)
		break_penalty = TreatySystem.TREATY_BREAK_PENALTY.get(treaty_type_id, -20)

	var dur_text: String = "Permanent" if duration == -1 else "%d turns" % duration
	_popup_terms_label.text = "Treaty with %s\nDuration: %s\nRequired reputation: %d\nBreak penalty: %d rep" % [partner_name, dur_text, rep_threshold, break_penalty]

	# Effects preview
	var effects: String = _get_treaty_effects_text(treaty_type_id)
	_popup_effects_label.text = effects

	# Acceptance probability
	var probability: int = _estimate_acceptance_probability(partner_id, treaty_type_id, faction_key)
	_popup_probability_bar.value = probability
	_popup_probability_label.text = "%d%%" % probability
	var prob_fill := StyleBoxFlat.new()
	prob_fill.set_corner_radius_all(4)
	if probability >= 70:
		prob_fill.bg_color = Color(0.3, 0.8, 0.3)
	elif probability >= 40:
		prob_fill.bg_color = Color(0.8, 0.7, 0.2)
	else:
		prob_fill.bg_color = Color(0.8, 0.3, 0.2)
	_popup_probability_bar.add_theme_stylebox_override("fill", prob_fill)

func _get_treaty_effects_text(treaty_type_id: int) -> String:
	if not _treaty_system:
		return "Effects: Treaty system unavailable."
	match treaty_type_id:
		TreatySystem.TreatyType.CEASEFIRE:
			return "Effects: Both sides cease hostilities. No attacks for the duration."
		TreatySystem.TreatyType.NON_AGGRESSION:
			return "Effects: Long-term peace pact. Stronger commitment than ceasefire."
		TreatySystem.TreatyType.TRADE_AGREEMENT:
			return "Effects: +15% gold income for both parties."
		TreatySystem.TreatyType.MILITARY_ACCESS:
			return "Effects: Move armies through each other's territory."
		TreatySystem.TreatyType.DEFENSIVE_ALLIANCE:
			return "Effects: Ally joins defense if either is attacked."
		TreatySystem.TreatyType.OFFENSIVE_ALLIANCE:
			return "Effects: Joint attacks, +10% ATK vs shared enemies."
		TreatySystem.TreatyType.VASSALAGE:
			return "Effects: Vassal pays tribute each turn. Overlord provides protection."
		TreatySystem.TreatyType.CONFEDERATION:
			return "Effects: Full political merge. Shared armies and resources. (Endgame)"
	return "Effects: Unknown treaty type."

func _estimate_acceptance_probability(partner_id: int, treaty_type_id: int, faction_key: String) -> int:
	var rep: int = DiplomacyManager.get_reputation(faction_key) if faction_key != "" else 0
	var threat: int = ThreatManager.get_threat() if ThreatManager else 0
	var base: int = 50

	# Reputation influence: each point of rep = ~0.5% acceptance
	base += int(rep * 0.5)

	# Threat influence: higher threat makes defensive pacts more likely
	if _treaty_system:
		if treaty_type_id in [TreatySystem.TreatyType.DEFENSIVE_ALLIANCE, TreatySystem.TreatyType.CEASEFIRE]:
			base += int(threat * 0.2)
		elif treaty_type_id == TreatySystem.TreatyType.VASSALAGE:
			base -= 20  # Vassalage hard to accept
		elif treaty_type_id == TreatySystem.TreatyType.CONFEDERATION:
			base -= 30  # Confederation very hard

	# Check reputation threshold
	if _treaty_system:
		var threshold: int = TreatySystem.TREATY_REP_THRESHOLD.get(treaty_type_id, 0)
		if rep < threshold:
			base = int(base * 0.3)  # Severely penalize if below threshold

	return clampi(base, 0, 95)

func _on_popup_confirm() -> void:
	AudioManager.play_ui_confirm()
	if _popup_partner_option.item_count == 0 or _popup_type_option.item_count == 0:
		return
	var partner_id: int = _popup_partner_option.get_item_id(_popup_partner_option.selected)
	var treaty_type_id: int = _popup_type_option.get_item_id(_popup_type_option.selected)
	var pid: int = GameManager.get_human_player_id()

	# Attempt to use TreatySystem first, fall back to DiplomacyManager
	if _treaty_system and _treaty_system.has_method("propose_treaty"):
		_treaty_system.propose_treaty(pid, partner_id, treaty_type_id)
	else:
		# Fallback: map treaty type to DiplomacyManager actions
		match treaty_type_id:
			0: DiplomacyManager.offer_ceasefire(pid, partner_id)
			1:
				if DiplomacyManager.has_method("sign_nap"):
					DiplomacyManager.sign_nap(pid, partner_id)
			2:
				if DiplomacyManager.has_method("sign_trade"):
					DiplomacyManager.sign_trade(pid, partner_id)
			4, 5:
				if DiplomacyManager.has_method("sign_alliance"):
					DiplomacyManager.sign_alliance(pid, partner_id)
	_close_proposal_popup()
	_refresh()

# ═══════════════ PUBLIC API ═══════════════

func show_panel() -> void:
	_visible = true; root.visible = true; _refresh()

func hide_panel() -> void:
	AudioManager.play_ui_cancel()
	_visible = false; root.visible = false

func is_panel_visible() -> bool:
	return _visible

# ═══════════════ TABS ═══════════════

func _switch_tab(tab: String) -> void:
	AudioManager.play_ui_click()
	_current_tab = tab; _refresh()

func _update_tab_highlight() -> void:
	for key in tab_buttons:
		if key == _current_tab:
			tab_buttons[key].add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT)
		else:
			tab_buttons[key].remove_theme_color_override("font_color")

# ═══════════════ REFRESH ═══════════════

func _refresh() -> void:
	_update_tab_highlight(); _clear_content()
	match _current_tab:
		TAB_EVIL: _build_evil_factions()
		TAB_LIGHT: _build_light_factions()
		TAB_NEUTRAL: _build_neutral_factions()
		TAB_TREATIES: _build_treaties_tab()
		TAB_REPUTATION: _build_reputation_tab()

func _clear_content() -> void:
	for node in _faction_nodes:
		if is_instance_valid(node): node.queue_free()
	_faction_nodes.clear()

# ═══════════════ EVIL FACTIONS TAB (enhanced) ═══════════════

func _build_evil_factions() -> void:
	var pid: int = GameManager.get_human_player_id()
	var factions: Array = [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]
	var player_faction: int = GameManager.get_player_faction(pid)

	for fid in factions:
		if fid == player_faction: continue
		var rel: Dictionary = DiplomacyManager.get_all_relations(pid).get(fid, {})
		var fname: String = FactionData.FACTION_NAMES.get(fid, "Unknown")
		var recruited: bool = rel.get("recruited", false)
		var hostile: bool = rel.get("hostile", false)
		var ceasefire: bool = DiplomacyManager.is_ceasefire_active(pid, fid)
		var method: String = rel.get("method", "")
		# Determine status with color-coded relations
		var status_text: String; var status_color: Color
		if recruited:
			if method == "diplomacy":
				status_text = "Subjugated (Diplomacy)"; status_color = Color(0.3, 0.9, 0.4)
			else:
				status_text = "Conquered"; status_color = Color(0.9, 0.7, 0.2)
				var reb: int = rel.get("rebellion_turns", 0)
				if reb > 0: status_text += " (Rebellion risk: %d turns)" % reb
		elif ceasefire:
			status_text = "Ceasefire"; status_color = Color(0.6, 0.7, 1.0)
		elif hostile:
			status_text = "Hostile"; status_color = COLOR_HOSTILE
		else:
			status_text = "Neutral"; status_color = COLOR_NEUTRAL

		# Relation color for the card border
		var relation_color: Color = _get_relation_color(hostile, ceasefire, recruited)
		var card := _build_faction_card(fname, status_text, status_color, _get_evil_faction_color(fid), relation_color)

		# Treaty icons next to faction name
		var active_treaties: Array = DiplomacyManager.get_active_treaties(pid)
		var treaty_icons_row := HBoxContainer.new()
		treaty_icons_row.add_theme_constant_override("separation", 4)
		var has_treaties: bool = false
		for treaty in active_treaties:
			if treaty["target"] == fid:
				has_treaties = true
				var icon_lbl := Label.new()
				var type_name: String = DiplomacyManager._get_treaty_type_name(treaty["type"])
				icon_lbl.text = _get_treaty_icon(treaty["type"])
				icon_lbl.tooltip_text = "%s (%d turns left)" % [type_name, treaty["turns_left"]]
				icon_lbl.add_theme_font_size_override("font_size", 16)
				icon_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
				treaty_icons_row.add_child(icon_lbl)
		if has_treaties:
			card.get_child(0).add_child(treaty_icons_row)

		# Reputation display
		var faction_key: String = _get_faction_key(fid)
		if faction_key != "":
			var rep_lbl := _build_reputation_label(faction_key)
			card.get_child(0).add_child(rep_lbl)

		# Show active treaties detail
		for treaty in active_treaties:
			if treaty["target"] == fid:
				var treaty_lbl := Label.new()
				var type_name: String = DiplomacyManager._get_treaty_type_name(treaty["type"])
				var extra: String = ""
				if treaty.has("gold_per_turn"):
					extra = " (%d gold/turn)" % treaty["gold_per_turn"]
				treaty_lbl.text = "  [%s] %d turns left%s" % [type_name, treaty["turns_left"], extra]
				treaty_lbl.add_theme_font_size_override("font_size", 11)
				treaty_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
				card.get_child(0).add_child(treaty_lbl)

		# Action buttons
		if not recruited:
			var actions: Array = DiplomacyManager.get_available_actions(pid, fid)
			if actions.size() > 0:
				var btn_row := HBoxContainer.new()
				btn_row.add_theme_constant_override("separation", 4)
				card.get_child(0).add_child(btn_row)
				for action in actions:
					var btn := Button.new()
					btn.text = "%s (%s)" % [action["name"], action["cost"]]
					btn.tooltip_text = action.get("desc", "")
					btn.custom_minimum_size = Vector2(140, 28)
					btn.add_theme_font_size_override("font_size", 11)
					var aid: String = action["id"]; var cfid: int = fid
					var btn_style := _make_action_button_style(aid)
					btn.add_theme_stylebox_override("normal", btn_style)
					btn.pressed.connect(_on_evil_action.bind(cfid, aid))
					btn_row.add_child(btn)

			# Quick-propose buttons for common treaty types
			var quick_row := HBoxContainer.new()
			quick_row.add_theme_constant_override("separation", 4)
			var has_quick: bool = false
			for qt in QUICK_TREATY_TYPES:
				if _can_quick_propose(pid, fid, qt):
					has_quick = true
					var qbtn := Button.new()
					qbtn.text = _get_quick_propose_label(qt)
					qbtn.custom_minimum_size = Vector2(110, 26)
					qbtn.add_theme_font_size_override("font_size", 10)
					var qs := StyleBoxFlat.new()
					qs.bg_color = Color(0.12, 0.18, 0.25, 0.9)
					qs.border_color = Color(0.3, 0.5, 0.7)
					qs.set_border_width_all(1); qs.set_corner_radius_all(4)
					qs.set_content_margin_all(3)
					qbtn.add_theme_stylebox_override("normal", qs)
					var cqt: String = qt; var cqfid: int = fid
					qbtn.pressed.connect(_on_quick_propose.bind(cqfid, cqt))
					quick_row.add_child(qbtn)
			if has_quick:
				card.get_child(0).add_child(quick_row)

			# Full propose button
			var propose_btn := Button.new()
			propose_btn.text = "Propose Treaty..."
			propose_btn.custom_minimum_size = Vector2(140, 28)
			propose_btn.add_theme_font_size_override("font_size", 11)
			var ps := StyleBoxFlat.new()
			ps.bg_color = Color(0.15, 0.15, 0.28, 0.9)
			ps.border_color = Color(0.4, 0.4, 0.7)
			ps.set_border_width_all(1); ps.set_corner_radius_all(4)
			ps.set_content_margin_all(4)
			propose_btn.add_theme_stylebox_override("normal", ps)
			var pfid: int = fid
			propose_btn.pressed.connect(_open_proposal_popup.bind(pfid))
			card.get_child(0).add_child(propose_btn)

			# Send gift (non-orc, non-hostile only)
			if not DiplomacyManager.is_orc_player(pid) and not hostile:
				var btn_row2 := HBoxContainer.new()
				btn_row2.add_theme_constant_override("separation", 4)
				card.get_child(0).add_child(btn_row2)
				var btn_gift := Button.new()
				btn_gift.text = "Gift (50g)"
				btn_gift.custom_minimum_size = Vector2(120, 28)
				btn_gift.add_theme_font_size_override("font_size", 11)
				btn_gift.pressed.connect(_on_send_gift.bind(fid))
				btn_row2.add_child(btn_gift)

			# Break treaty buttons
			for treaty in active_treaties:
				if treaty["target"] == fid:
					var btn_break := Button.new()
					btn_break.text = "Break: %s" % DiplomacyManager._get_treaty_type_name(treaty["type"])
					btn_break.custom_minimum_size = Vector2(140, 28)
					btn_break.add_theme_font_size_override("font_size", 11)
					btn_break.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)
					var ttype: String = treaty["type"]; var tfid: int = fid
					btn_break.pressed.connect(_on_break_treaty.bind(tfid, ttype))
					card.get_child(0).add_child(btn_break)
		content_container.add_child(card); _faction_nodes.append(card)

# ═══════════════ LIGHT FACTIONS TAB (enhanced) ═══════════════

func _build_light_factions() -> void:
	var pid: int = GameManager.get_human_player_id()
	var threat: int = ThreatManager.get_threat()
	var ceasefire_active: bool = DiplomacyManager.is_light_ceasefire_active()

	var status_text: String; var status_color: Color
	if ceasefire_active:
		status_text = "Ceasefire (%d turns)" % DiplomacyManager.get_light_ceasefire_turns()
		status_color = Color(0.4, 0.8, 1.0)
	elif threat >= 80:
		status_text = "Desperate Counter (Threat %d)" % threat
		status_color = Color(1.0, 0.2, 0.2)
	elif threat >= 60:
		status_text = "Total War (Threat %d)" % threat
		status_color = Color(1.0, 0.5, 0.2)
	elif threat >= 30:
		status_text = "Alert Defense (Threat %d)" % threat
		status_color = Color(1.0, 0.7, 0.3)
	else:
		status_text = "Vigilant (Threat %d)" % threat
		status_color = ColorTheme.TEXT_DIM

	# Color-coded relation for alliance card
	var alliance_relation_color: Color = COLOR_HOSTILE
	if ceasefire_active:
		alliance_relation_color = COLOR_NEUTRAL
	var card := _build_faction_card("Light Alliance", status_text, status_color, Color(0.4, 0.6, 1.0), alliance_relation_color)

	# Threat bar
	var threat_row := HBoxContainer.new()
	threat_row.add_theme_constant_override("separation", 8)
	card.get_child(0).add_child(threat_row)
	var threat_lbl := Label.new()
	threat_lbl.text = "Threat: %d/100" % threat
	threat_lbl.custom_minimum_size = Vector2(100, 0)
	threat_lbl.add_theme_font_size_override("font_size", 12)
	threat_lbl.add_theme_color_override("font_color", Color(0.8, 0.5, 0.3))
	threat_row.add_child(threat_lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0; bar.max_value = 100; bar.value = threat
	bar.custom_minimum_size = Vector2(200, 16); bar.show_percentage = false
	var t_bg := StyleBoxFlat.new()
	t_bg.bg_color = Color(0.12, 0.12, 0.15, 0.8); t_bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", t_bg)
	var t_fill := StyleBoxFlat.new()
	t_fill.bg_color = Color(0.8, 0.3, 0.2) if threat >= 60 else Color(0.9, 0.6, 0.2) if threat >= 30 else Color(0.5, 0.7, 0.3)
	t_fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", t_fill)
	threat_row.add_child(bar)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = "The Light Alliance is naturally hostile to dark forces, but can negotiate ceasefires or extortion"
	desc_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	desc_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	card.get_child(0).add_child(desc_lbl)

	# Action buttons
	var actions: Array = DiplomacyManager.get_light_actions(pid)
	if actions.size() > 0:
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 4)
		card.get_child(0).add_child(btn_row)
		for action in actions:
			var btn := Button.new()
			btn.text = "%s (%s)" % [action["name"], action["cost"]]
			btn.tooltip_text = action.get("desc", "")
			btn.custom_minimum_size = Vector2(160, 28)
			btn.add_theme_font_size_override("font_size", 11)
			var aid: String = action["id"]
			btn.pressed.connect(_on_light_action.bind(aid))
			btn_row.add_child(btn)

	content_container.add_child(card); _faction_nodes.append(card)

	# Individual light factions (info cards with treaty icons)
	for lfid in FactionData.LIGHT_FACTION_NAMES:
		var fname: String = FactionData.LIGHT_FACTION_NAMES[lfid]
		var light_key: String = _get_light_faction_key(lfid)
		var light_rep: int = DiplomacyManager.get_reputation(light_key) if light_key != "" else 0
		var sub_relation_color: Color = _get_color_for_reputation(light_rep)
		var sub_card := _build_faction_card(fname, "Hostile", Color(1.0, 0.5, 0.3), Color(0.4, 0.6, 1.0), sub_relation_color)
		if light_key != "":
			var rep_lbl := _build_reputation_label(light_key)
			sub_card.get_child(0).add_child(rep_lbl)
		content_container.add_child(sub_card); _faction_nodes.append(sub_card)

# ═══════════════ NEUTRAL FACTIONS TAB ═══════════════

func _build_neutral_factions() -> void:
	var pid: int = GameManager.get_human_player_id()
	for nfid in FactionData.NEUTRAL_FACTION_NAMES:
		var fname: String = FactionData.NEUTRAL_FACTION_NAMES[nfid]
		var taming: int = QuestManager.get_taming_level(pid, nfid)
		var tier: String = QuestManager.get_taming_tier(pid, nfid)
		var recruited: bool = QuestManager.is_faction_recruited(pid, nfid) if QuestManager.has_method("is_faction_recruited") else (taming >= 10)
		var status_text: String; var status_color: Color
		match tier:
			"hostile": status_text = "Hostile"; status_color = COLOR_HOSTILE
			"neutral": status_text = "Neutral"; status_color = COLOR_NEUTRAL
			"friendly": status_text = "Friendly"; status_color = COLOR_FRIENDLY
			"allied": status_text = "Allied"; status_color = COLOR_ALLIED
			"tamed": status_text = "Tamed"; status_color = Color(1.0, 0.85, 0.3)
			_: status_text = tier; status_color = Color(0.6, 0.6, 0.6)
		if recruited:
			status_text = "Subjugated"; status_color = Color(0.3, 1.0, 0.5)

		# Color-coded card border based on taming tier
		var relation_color: Color = COLOR_NEUTRAL
		if tier == "hostile": relation_color = COLOR_HOSTILE
		elif tier == "friendly": relation_color = COLOR_FRIENDLY
		elif tier in ["allied", "tamed"]: relation_color = COLOR_ALLIED
		if recruited: relation_color = Color(0.3, 1.0, 0.5)

		var card := _build_faction_card(fname, status_text, status_color, Color(0.8, 0.7, 0.5), relation_color)

		# Taming progress bar
		var taming_row := HBoxContainer.new()
		taming_row.add_theme_constant_override("separation", 8)
		card.get_child(0).add_child(taming_row)
		var taming_lbl := Label.new()
		taming_lbl.text = "Taming: %d/10" % taming
		taming_lbl.custom_minimum_size = Vector2(90, 0)
		taming_lbl.add_theme_font_size_override("font_size", 12)
		taming_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
		taming_row.add_child(taming_lbl)
		var bar := ProgressBar.new()
		bar.min_value = 0; bar.max_value = 10; bar.value = taming
		bar.custom_minimum_size = Vector2(200, 16); bar.show_percentage = false
		var bar_bg := StyleBoxFlat.new()
		bar_bg.bg_color = Color(0.12, 0.12, 0.15, 0.8); bar_bg.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bar_bg)
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.7, 0.6, 0.3) if taming < 5 else Color(0.3, 0.8, 0.4) if taming < 8 else Color(1.0, 0.85, 0.3)
		bar_fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", bar_fill)
		taming_row.add_child(bar)
		# Threshold labels
		var threshold_lbl := Label.new()
		threshold_lbl.text = "  0=Hostile  3=Neutral  5=Friendly  7=Allied  10=Tamed"
		threshold_lbl.add_theme_font_size_override("font_size", 10)
		threshold_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		card.get_child(0).add_child(threshold_lbl)
		# Quest step
		if QuestManager.has_method("get_quest_step"):
			var step: int = QuestManager.get_quest_step(pid, nfid)
			var quest_lbl := Label.new()
			quest_lbl.text = "Quest: %d/3 steps" % step
			quest_lbl.add_theme_font_size_override("font_size", 12)
			quest_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5))
			card.get_child(0).add_child(quest_lbl)
		content_container.add_child(card); _faction_nodes.append(card)

# ═══════════════ TREATIES TAB ═══════════════

func _build_treaties_tab() -> void:
	var pid: int = GameManager.get_human_player_id()

	# ── Section: Active Treaties ──
	var active_header := Label.new()
	active_header.text = "Active Treaties"
	active_header.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	active_header.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	content_container.add_child(active_header); _faction_nodes.append(active_header)

	var active_treaties: Array = DiplomacyManager.get_active_treaties(pid)
	if active_treaties.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "No active treaties."
		empty_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		empty_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		content_container.add_child(empty_lbl); _faction_nodes.append(empty_lbl)
	else:
		for treaty in active_treaties:
			var treaty_card := _build_treaty_card(treaty, pid)
			content_container.add_child(treaty_card); _faction_nodes.append(treaty_card)

	# ── Section: Incoming Proposals ──
	content_container.add_child(HSeparator.new())
	var incoming_header := Label.new()
	incoming_header.text = "Incoming Proposals"
	incoming_header.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	incoming_header.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	content_container.add_child(incoming_header); _faction_nodes.append(incoming_header)

	var proposals: Array = _get_pending_proposals()
	if proposals.size() == 0:
		var empty_lbl2 := Label.new()
		empty_lbl2.text = "No incoming proposals."
		empty_lbl2.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		empty_lbl2.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		content_container.add_child(empty_lbl2); _faction_nodes.append(empty_lbl2)
	else:
		for proposal in proposals:
			var prop_card := _build_proposal_card(proposal)
			content_container.add_child(prop_card); _faction_nodes.append(prop_card)

	# ── Section: Propose New Treaty ──
	content_container.add_child(HSeparator.new())
	var propose_header := Label.new()
	propose_header.text = "Propose New Treaty"
	propose_header.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	propose_header.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	content_container.add_child(propose_header); _faction_nodes.append(propose_header)

	var propose_btn := Button.new()
	propose_btn.text = "Open Treaty Proposal..."
	propose_btn.custom_minimum_size = Vector2(220, 36)
	propose_btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.15, 0.2, 0.3, 0.9)
	ps.border_color = Color(0.4, 0.5, 0.8)
	ps.set_border_width_all(1); ps.set_corner_radius_all(6); ps.set_content_margin_all(8)
	propose_btn.add_theme_stylebox_override("normal", ps)
	propose_btn.pressed.connect(_open_proposal_popup.bind(-1))
	content_container.add_child(propose_btn); _faction_nodes.append(propose_btn)

func _build_treaty_card(treaty: Dictionary, pid: int) -> PanelContainer:
	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = ColorTheme.BG_CARD
	s.border_color = Color(0.3, 0.5, 0.7)
	s.set_border_width_all(1); s.set_corner_radius_all(6); s.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", s)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Title row: type + partner
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var icon_lbl := Label.new()
	icon_lbl.text = _get_treaty_icon(treaty.get("type", ""))
	icon_lbl.add_theme_font_size_override("font_size", 18)
	title_row.add_child(icon_lbl)
	var type_name: String = DiplomacyManager._get_treaty_type_name(treaty.get("type", ""))
	var type_lbl := Label.new()
	type_lbl.text = type_name
	type_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	type_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_HEADING)
	type_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(type_lbl)

	# Partner
	var partner_name: String = FactionData.FACTION_NAMES.get(treaty.get("target", -1), "Unknown")
	var partner_lbl := Label.new()
	partner_lbl.text = "Partner: %s" % partner_name
	partner_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	partner_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	vbox.add_child(partner_lbl)

	# Duration
	var turns_left: int = treaty.get("turns_left", -1)
	var dur_text: String = "Permanent" if turns_left == -1 else "%d turns remaining" % turns_left
	var dur_lbl := Label.new()
	dur_lbl.text = "Duration: %s" % dur_text
	dur_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	dur_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	vbox.add_child(dur_lbl)

	# Terms/extras
	if treaty.has("gold_per_turn") and treaty["gold_per_turn"] > 0:
		var terms_lbl := Label.new()
		terms_lbl.text = "Terms: %d gold/turn" % treaty["gold_per_turn"]
		terms_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		terms_lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
		vbox.add_child(terms_lbl)

	# Break button
	var break_btn := Button.new()
	break_btn.text = "Break Treaty"
	break_btn.custom_minimum_size = Vector2(120, 26)
	break_btn.add_theme_font_size_override("font_size", 11)
	break_btn.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.25, 0.08, 0.08, 0.9)
	bs.border_color = Color(0.7, 0.2, 0.2)
	bs.set_border_width_all(1); bs.set_corner_radius_all(4); bs.set_content_margin_all(3)
	break_btn.add_theme_stylebox_override("normal", bs)
	var ttype: String = treaty.get("type", ""); var tfid: int = treaty.get("target", -1)
	break_btn.pressed.connect(_on_break_treaty.bind(tfid, ttype))
	vbox.add_child(break_btn)

	return card

func _build_proposal_card(proposal: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.12, 0.1, 0.06, 0.9)
	s.border_color = Color(0.7, 0.6, 0.3)
	s.set_border_width_all(1); s.set_corner_radius_all(6); s.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", s)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var from_name: String = FactionData.FACTION_NAMES.get(proposal.get("from", -1), "Unknown")
	var type_name: String = proposal.get("type_name", "Unknown")
	var title_lbl := Label.new()
	title_lbl.text = "%s proposes: %s" % [from_name, type_name]
	title_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	title_lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT)
	vbox.add_child(title_lbl)

	if proposal.has("terms"):
		var terms_lbl := Label.new()
		terms_lbl.text = "Terms: %s" % proposal["terms"]
		terms_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		terms_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
		terms_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(terms_lbl)

	# Accept/Reject buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)
	var accept_btn := Button.new()
	accept_btn.text = "Accept"
	accept_btn.custom_minimum_size = Vector2(100, 30)
	accept_btn.add_theme_font_size_override("font_size", 12)
	var as_ := StyleBoxFlat.new()
	as_.bg_color = Color(0.1, 0.25, 0.1, 0.9)
	as_.border_color = Color(0.3, 0.7, 0.3)
	as_.set_border_width_all(1); as_.set_corner_radius_all(4); as_.set_content_margin_all(4)
	accept_btn.add_theme_stylebox_override("normal", as_)
	var prop_id = proposal.get("id", -1)
	accept_btn.pressed.connect(_on_accept_proposal.bind(prop_id))
	btn_row.add_child(accept_btn)

	var reject_btn := Button.new()
	reject_btn.text = "Reject"
	reject_btn.custom_minimum_size = Vector2(100, 30)
	reject_btn.add_theme_font_size_override("font_size", 12)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.25, 0.08, 0.08, 0.9)
	rs.border_color = Color(0.7, 0.2, 0.2)
	rs.set_border_width_all(1); rs.set_corner_radius_all(4); rs.set_content_margin_all(4)
	reject_btn.add_theme_stylebox_override("normal", rs)
	reject_btn.pressed.connect(_on_reject_proposal.bind(prop_id))
	btn_row.add_child(reject_btn)

	return card

func _get_pending_proposals() -> Array:
	if _treaty_system and _treaty_system.has_method("get_pending_proposals"):
		return _treaty_system._pending_proposals
	# Fallback: check DiplomacyManager
	if DiplomacyManager.has_method("get_pending_proposals"):
		return DiplomacyManager.get_pending_proposals()
	return []

func _on_accept_proposal(proposal_id: int) -> void:
	AudioManager.play_ui_confirm()
	if _treaty_system and _treaty_system.has_method("accept_treaty"):
		_treaty_system.accept_treaty(proposal_id)
	elif DiplomacyManager.has_method("accept_proposal"):
		DiplomacyManager.accept_proposal(proposal_id)
	_refresh()

func _on_reject_proposal(proposal_id: int) -> void:
	AudioManager.play_ui_click()
	if _treaty_system and _treaty_system.has_method("reject_treaty"):
		_treaty_system.reject_treaty(proposal_id)
	elif DiplomacyManager.has_method("reject_proposal"):
		DiplomacyManager.reject_proposal(proposal_id)
	_refresh()

# ═══════════════ REPUTATION TAB ═══════════════

func _build_reputation_tab() -> void:
	var header := Label.new()
	header.text = "Faction Reputation"
	header.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	header.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	content_container.add_child(header); _faction_nodes.append(header)

	# Tier legend
	var legend_row := HBoxContainer.new()
	legend_row.add_theme_constant_override("separation", 6)
	content_container.add_child(legend_row); _faction_nodes.append(legend_row)
	for i in range(REP_TIER_LABELS.size()):
		var tier_lbl := Label.new()
		tier_lbl.text = "%s(%d)" % [REP_TIER_LABELS[i], REP_TIER_THRESHOLDS[i]]
		tier_lbl.add_theme_font_size_override("font_size", 10)
		tier_lbl.add_theme_color_override("font_color", REP_TIER_COLORS[i])
		legend_row.add_child(tier_lbl)

	content_container.add_child(HSeparator.new())

	# All known faction keys for reputation display
	var faction_keys: Array = _get_all_faction_keys()
	for fkey in faction_keys:
		var rep_card := _build_reputation_card(fkey)
		content_container.add_child(rep_card); _faction_nodes.append(rep_card)

	# ── Reputation History ──
	content_container.add_child(HSeparator.new())
	var hist_header := Label.new()
	hist_header.text = "Reputation History"
	hist_header.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	hist_header.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	content_container.add_child(hist_header); _faction_nodes.append(hist_header)

	if _reputation_history.size() == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "No reputation changes recorded yet."
		empty_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		empty_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		content_container.add_child(empty_lbl); _faction_nodes.append(empty_lbl)
	else:
		# Show last 20 entries, most recent first
		var display_count: int = mini(_reputation_history.size(), 20)
		for i in range(_reputation_history.size() - 1, _reputation_history.size() - 1 - display_count, -1):
			var entry: Dictionary = _reputation_history[i]
			var hist_lbl := Label.new()
			var delta_sign: String = "+" if entry.get("delta", 0) >= 0 else ""
			hist_lbl.text = "Turn %d: %s %s%d (%s)" % [
				entry.get("turn", 0),
				_get_faction_display_name(entry.get("faction_key", "")),
				delta_sign, entry.get("delta", 0),
				entry.get("reason", "unknown"),
			]
			hist_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
			var delta: int = entry.get("delta", 0)
			hist_lbl.add_theme_color_override("font_color",
				Color(0.3, 0.8, 0.3) if delta > 0 else Color(0.9, 0.3, 0.3) if delta < 0 else ColorTheme.TEXT_DIM)
			content_container.add_child(hist_lbl); _faction_nodes.append(hist_lbl)

func _build_reputation_card(faction_key: String) -> PanelContainer:
	var card := PanelContainer.new()
	var rep: int = DiplomacyManager.get_reputation(faction_key)
	var tier_label: String = _get_rep_tier_label(rep)
	var tier_color: Color = _get_rep_tier_color(rep)

	var s := StyleBoxFlat.new()
	s.bg_color = ColorTheme.BG_CARD
	s.border_color = tier_color.darkened(0.3)
	s.set_border_width_all(1); s.set_corner_radius_all(6); s.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", s)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Faction name + tier
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	vbox.add_child(title_row)
	var name_lbl := Label.new()
	name_lbl.text = _get_faction_display_name(faction_key)
	name_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	name_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_HEADING)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)
	var tier_lbl := Label.new()
	tier_lbl.text = "[%s]" % tier_label
	tier_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	tier_lbl.add_theme_color_override("font_color", tier_color)
	title_row.add_child(tier_lbl)

	# Reputation bar (-100 to 100)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	vbox.add_child(bar_row)

	var rep_val_lbl := Label.new()
	var sign: String = "+" if rep >= 0 else ""
	rep_val_lbl.text = "%s%d" % [sign, rep]
	rep_val_lbl.custom_minimum_size = Vector2(50, 0)
	rep_val_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	rep_val_lbl.add_theme_color_override("font_color", tier_color)
	bar_row.add_child(rep_val_lbl)

	# Custom dual-sided bar: left half = negative, right half = positive
	var bar_container := Control.new()
	bar_container.custom_minimum_size = Vector2(300, 18)
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_row.add_child(bar_container)

	# Background
	var bar_bg := ColorRect.new()
	bar_bg.anchor_right = 1.0; bar_bg.anchor_bottom = 1.0
	bar_bg.color = Color(0.12, 0.12, 0.15, 0.8)
	bar_container.add_child(bar_bg)

	# Center marker
	var center_mark := ColorRect.new()
	center_mark.anchor_left = 0.5; center_mark.anchor_right = 0.5
	center_mark.anchor_bottom = 1.0
	center_mark.offset_left = -1; center_mark.offset_right = 1
	center_mark.color = Color(0.5, 0.5, 0.5, 0.6)
	bar_container.add_child(center_mark)

	# Fill bar
	var fill := ColorRect.new()
	fill.anchor_bottom = 1.0
	var normalized: float = (rep + 100.0) / 200.0  # 0.0 to 1.0
	if rep >= 0:
		fill.anchor_left = 0.5
		fill.anchor_right = 0.5 + normalized - 0.5
	else:
		fill.anchor_left = normalized
		fill.anchor_right = 0.5
	fill.color = tier_color
	fill.color.a = 0.7
	bar_container.add_child(fill)

	return card

func _get_rep_tier_label(rep: int) -> String:
	var label: String = REP_TIER_LABELS[0]
	for i in range(REP_TIER_THRESHOLDS.size()):
		if rep >= REP_TIER_THRESHOLDS[i]:
			label = REP_TIER_LABELS[i]
	return label

func _get_rep_tier_color(rep: int) -> Color:
	var color: Color = REP_TIER_COLORS[0]
	for i in range(REP_TIER_THRESHOLDS.size()):
		if rep >= REP_TIER_THRESHOLDS[i]:
			color = REP_TIER_COLORS[i]
	return color

func _get_all_faction_keys() -> Array:
	var keys: Array = ["orc_ai", "pirate_ai", "dark_elf_ai", "human", "elf", "mage"]
	# If TreatySystem tracks additional factions, include them
	if _treaty_system and _treaty_system._reputation is Dictionary:
		for k in _treaty_system._reputation.keys():
			if k not in keys:
				keys.append(k)
	return keys

func _get_faction_display_name(faction_key: String) -> String:
	match faction_key:
		"orc_ai": return "Orc Horde"
		"pirate_ai": return "Pirate Fleet"
		"dark_elf_ai": return "Dark Elves"
		"human": return "Human Kingdom"
		"elf": return "High Elves"
		"mage": return "Mage Tower"
	return faction_key.capitalize()

func _record_reputation_change(faction_key: String, delta: int, reason: String) -> void:
	var turn: int = GameManager.current_turn if GameManager.has_method("get") else 0
	if "current_turn" in GameManager:
		turn = GameManager.current_turn
	_reputation_history.append({
		"faction_key": faction_key, "delta": delta,
		"reason": reason, "turn": turn,
	})
	# Cap history at 100 entries
	if _reputation_history.size() > 100:
		_reputation_history = _reputation_history.slice(-100)

# ═══════════════ FACTION CARD BUILDER ═══════════════

func _build_faction_card(fname: String, status_text: String, status_color: Color, name_color: Color, relation_border_color: Color = Color(-1, -1, -1)) -> PanelContainer:
	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = ColorTheme.BG_PANEL
	# Use relation border color if provided, otherwise darken name color
	if relation_border_color.r >= 0:
		s.border_color = relation_border_color
		s.set_border_width_all(2)
	else:
		s.border_color = name_color.darkened(0.4)
		s.set_border_width_all(1)
	s.set_corner_radius_all(6); s.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", s)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	vbox.add_child(title_row)
	var name_lbl := Label.new()
	name_lbl.text = fname; name_lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	name_lbl.add_theme_color_override("font_color", name_color)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)
	var status_lbl := Label.new()
	status_lbl.text = "[%s]" % status_text; status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.add_theme_color_override("font_color", status_color)
	title_row.add_child(status_lbl)
	return card

# ═══════════════ ACTION CALLBACKS ═══════════════

func _on_evil_action(faction_id: int, action_id: String) -> void:
	AudioManager.play_ui_confirm()
	var pid: int = GameManager.get_human_player_id()
	match action_id:
		"recruit_diplomacy":
			var ok: bool = DiplomacyManager.recruit_by_diplomacy(pid, faction_id)
			if not ok:
				for msg in DiplomacyManager.can_diplomacy(pid, faction_id).get("missing", []):
					EventBus.message_log.emit("[color=red]%s[/color]" % msg)
		"ceasefire": DiplomacyManager.offer_ceasefire(pid, faction_id)
		"declare_war": DiplomacyManager.mark_hostile(pid, faction_id)
		"demand_tribute": DiplomacyManager.demand_tribute(pid, faction_id)
		"offer_tribute": DiplomacyManager.offer_tribute(pid, faction_id)
		"nap":
			var ok: bool = DiplomacyManager.sign_nap(pid, faction_id)
			if not ok:
				for msg in DiplomacyManager.can_sign_nap(pid, faction_id).get("missing", []):
					EventBus.message_log.emit("[color=red]%s[/color]" % msg)
		"alliance":
			var ok: bool = DiplomacyManager.sign_alliance(pid, faction_id)
			if not ok:
				for msg in DiplomacyManager.can_sign_alliance(pid, faction_id).get("missing", []):
					EventBus.message_log.emit("[color=red]%s[/color]" % msg)
		"trade":
			var ok: bool = DiplomacyManager.sign_trade(pid, faction_id)
			if not ok:
				for msg in DiplomacyManager.can_sign_trade(pid, faction_id).get("missing", []):
					EventBus.message_log.emit("[color=red]%s[/color]" % msg)
	_refresh()

func _on_light_action(action_id: String) -> void:
	AudioManager.play_ui_confirm()
	var pid: int = GameManager.get_human_player_id()
	match action_id:
		"light_ceasefire": DiplomacyManager.buy_light_ceasefire(pid)
		"light_extort": DiplomacyManager.extort_light(pid)
		"accept_peace": DiplomacyManager.accept_light_peace()
		"reject_peace": DiplomacyManager.reject_light_peace()
	_refresh()

func _on_break_treaty(faction_id: int, treaty_type: String) -> void:
	AudioManager.play_ui_click()
	var pid: int = GameManager.get_human_player_id()
	var faction_key: String = _get_faction_key(faction_id)
	# Record reputation change from breaking
	if _treaty_system and faction_key != "":
		# Look up penalty from TreatySystem constants
		for t_val in TreatySystem.TreatyType.values():
			var t_name: String = TreatySystem.TREATY_NAMES.get(t_val, "")
			if treaty_type in t_name or DiplomacyManager._get_treaty_type_name(treaty_type) == t_name:
				var penalty: int = TreatySystem.TREATY_BREAK_PENALTY.get(t_val, -20)
				_record_reputation_change(faction_key, penalty, "Broke treaty: %s" % treaty_type)
				break
	DiplomacyManager.break_treaty(pid, treaty_type, faction_id)
	_refresh()

func _on_send_gift(faction_id: int) -> void:
	AudioManager.play_ui_click()
	var pid: int = GameManager.get_human_player_id()
	if not ResourceManager.can_afford(pid, {"gold": 50}):
		EventBus.message_log.emit("[color=red]Not enough gold (need 50)[/color]"); return
	ResourceManager.spend(pid, {"gold": 50})
	if DiplomacyManager.has_method("improve_relation"):
		DiplomacyManager.improve_relation(pid, faction_id, 5)
	var faction_key: String = _get_faction_key(faction_id)
	if faction_key != "":
		_record_reputation_change(faction_key, 5, "Sent gift (50g)")
	EventBus.message_log.emit("Sent tribute to %s (-50g, Rep +5)" % FactionData.FACTION_NAMES.get(faction_id, "Unknown"))
	_refresh()

func _on_quick_propose(faction_id: int, treaty_type: String) -> void:
	AudioManager.play_ui_confirm()
	var pid: int = GameManager.get_human_player_id()
	match treaty_type:
		"ceasefire": DiplomacyManager.offer_ceasefire(pid, faction_id)
		"nap":
			if DiplomacyManager.has_method("sign_nap"):
				DiplomacyManager.sign_nap(pid, faction_id)
		"trade":
			if DiplomacyManager.has_method("sign_trade"):
				DiplomacyManager.sign_trade(pid, faction_id)
		"alliance":
			if DiplomacyManager.has_method("sign_alliance"):
				DiplomacyManager.sign_alliance(pid, faction_id)
	_refresh()

func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: hide_panel()

# ═══════════════ SIGNAL HANDLERS ═══════════════

func _on_diplomacy_changed(_pid: int, _fid: int) -> void:
	if _visible: _refresh()

func _on_taming_changed(_pid: int, _tag: String, _val: int) -> void:
	if _visible: _refresh()

func _on_resources_changed(_pid: int) -> void:
	if _visible: _refresh()

func _on_treaty_changed(_pid: int, _type: String, _fid: int) -> void:
	if _visible: _refresh()

func _on_threat_changed(_val: int) -> void:
	if _visible: _refresh()

func _on_reputation_threshold(faction_key: String, old_level: String, new_level: String) -> void:
	_record_reputation_change(faction_key, 0, "Tier: %s -> %s" % [old_level, new_level])
	if _visible: _refresh()

# ═══════════════ HELPERS ═══════════════

func _make_tab_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text; btn.custom_minimum_size = Vector2(130, 34)
	btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	btn.add_theme_stylebox_override("normal", ColorTheme.make_button_style_flat("normal"))
	btn.add_theme_stylebox_override("hover", ColorTheme.make_button_style_flat("hover"))
	return btn

func _get_evil_faction_color(fid: int) -> Color:
	match fid:
		FactionData.FactionID.ORC: return Color(0.9, 0.5, 0.2)
		FactionData.FactionID.PIRATE: return Color(0.4, 0.6, 0.9)
		FactionData.FactionID.DARK_ELF: return Color(0.6, 0.3, 0.8)
	return ColorTheme.TEXT_DIM

func _get_faction_key(fid: int) -> String:
	match fid:
		FactionData.FactionID.ORC: return "orc_ai"
		FactionData.FactionID.PIRATE: return "pirate_ai"
		FactionData.FactionID.DARK_ELF: return "dark_elf_ai"
	return ""

func _get_light_faction_key(lfid) -> String:
	var name_lower: String = FactionData.LIGHT_FACTION_NAMES.get(lfid, "").to_lower()
	if "human" in name_lower: return "human"
	if "elf" in name_lower or "elves" in name_lower: return "elf"
	if "mage" in name_lower: return "mage"
	return ""

func _build_reputation_label(faction_key: String) -> Label:
	var rep: int = DiplomacyManager.get_reputation(faction_key)
	var level: String = DiplomacyManager.get_reputation_level(faction_key)
	var rep_lbl := Label.new()
	var sign: String = "+" if rep >= 0 else ""
	var level_cn: String = _get_rep_tier_label(rep)
	var rep_color: Color = _get_rep_tier_color(rep)
	rep_lbl.text = "Rep: %s%d (%s)" % [sign, rep, level_cn]
	rep_lbl.add_theme_font_size_override("font_size", 12)
	rep_lbl.add_theme_color_override("font_color", rep_color)
	return rep_lbl

func _get_relation_color(hostile: bool, ceasefire: bool, recruited: bool) -> Color:
	if recruited: return COLOR_ALLIED
	if hostile: return COLOR_HOSTILE
	if ceasefire: return Color(0.5, 0.6, 0.9)
	return COLOR_NEUTRAL

func _get_color_for_reputation(rep: int) -> Color:
	if rep > 50: return COLOR_ALLIED
	if rep > 20: return COLOR_FRIENDLY
	if rep > -20: return COLOR_NEUTRAL
	return COLOR_HOSTILE

func _get_treaty_icon(treaty_type: String) -> String:
	match treaty_type:
		"ceasefire": return "[CF]"
		"nap", "non_aggression": return "[NAP]"
		"trade", "trade_agreement": return "[TR]"
		"military_access": return "[MA]"
		"alliance", "defensive_alliance": return "[DA]"
		"offensive_alliance": return "[OA]"
		"tribute_receive", "tribute_pay", "vassalage": return "[VAS]"
		"confederation": return "[CON]"
	return "[T]"

func _make_action_button_style(action_id: String) -> StyleBoxFlat:
	var btn_style := StyleBoxFlat.new()
	match action_id:
		"recruit_diplomacy":
			btn_style.bg_color = Color(0.15, 0.3, 0.15, 0.9)
			btn_style.border_color = Color(0.3, 0.7, 0.3)
		"ceasefire":
			btn_style.bg_color = Color(0.15, 0.2, 0.3, 0.9)
			btn_style.border_color = Color(0.3, 0.5, 0.8)
		"declare_war":
			btn_style.bg_color = Color(0.3, 0.1, 0.1, 0.9)
			btn_style.border_color = Color(0.8, 0.2, 0.2)
		"demand_tribute", "offer_tribute":
			btn_style.bg_color = Color(0.25, 0.2, 0.1, 0.9)
			btn_style.border_color = Color(0.7, 0.6, 0.3)
		_:
			btn_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
			btn_style.border_color = Color(0.4, 0.4, 0.5)
	btn_style.set_border_width_all(1)
	btn_style.set_corner_radius_all(4)
	btn_style.set_content_margin_all(4)
	return btn_style

func _can_quick_propose(pid: int, faction_id: int, treaty_type: String) -> bool:
	# Check if this quick treaty type is available (not already active)
	var active: Array = DiplomacyManager.get_active_treaties(pid)
	for treaty in active:
		if treaty["target"] == faction_id and treaty["type"] == treaty_type:
			return false
	# Check reputation threshold if TreatySystem available
	if _treaty_system:
		var faction_key: String = _get_faction_key(faction_id)
		var rep: int = DiplomacyManager.get_reputation(faction_key) if faction_key != "" else 0
		var type_map: Dictionary = {
			"ceasefire": TreatySystem.TreatyType.CEASEFIRE,
			"nap": TreatySystem.TreatyType.NON_AGGRESSION,
			"trade": TreatySystem.TreatyType.TRADE_AGREEMENT,
			"alliance": TreatySystem.TreatyType.DEFENSIVE_ALLIANCE,
		}
		var t_enum = type_map.get(treaty_type, -1)
		if t_enum >= 0:
			var threshold: int = TreatySystem.TREATY_REP_THRESHOLD.get(t_enum, 0)
			if rep < threshold:
				return false
	return true

func _get_quick_propose_label(treaty_type: String) -> String:
	match treaty_type:
		"ceasefire": return "Quick: Ceasefire"
		"nap": return "Quick: NAP"
		"trade": return "Quick: Trade"
		"alliance": return "Quick: Alliance"
	return "Quick: %s" % treaty_type
