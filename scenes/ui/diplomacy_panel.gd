## diplomacy_panel.gd - 外交面板 UI for 暗潮 SLG (v1.0)
## Shows all factions (light/evil/neutral) with diplomacy actions and taming levels.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── State ──
var _visible: bool = false
var _current_tab: String = "evil"  # "evil", "light", "neutral"

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var tab_container: HBoxContainer
var btn_tab_evil: Button
var btn_tab_light: Button
var btn_tab_neutral: Button
var content_scroll: ScrollContainer
var content_container: VBoxContainer
var _faction_nodes: Array = []

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	layer = 5
	_build_ui()
	_connect_signals()
	hide_panel()

func _connect_signals() -> void:
	EventBus.faction_recruited.connect(_on_diplomacy_changed)
	EventBus.taming_changed.connect(_on_taming_changed)
	EventBus.resources_changed.connect(_on_resources_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			if _visible: hide_panel()
			else: show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
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
	main_panel.offset_left = 40; main_panel.offset_right = -40
	main_panel.offset_top = 30; main_panel.offset_bottom = -30
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.97)
	style.border_color = Color(0.5, 0.4, 0.2)
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
	header_label.text = "外交总览"
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)
	btn_close = Button.new()
	btn_close.text = "X"; btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	# Tab buttons
	tab_container = HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(tab_container)
	btn_tab_evil = _make_tab_button("恶势力阵营")
	btn_tab_evil.pressed.connect(func(): _switch_tab("evil"))
	tab_container.add_child(btn_tab_evil)
	btn_tab_light = _make_tab_button("光明阵营")
	btn_tab_light.pressed.connect(func(): _switch_tab("light"))
	tab_container.add_child(btn_tab_light)
	btn_tab_neutral = _make_tab_button("中立势力")
	btn_tab_neutral.pressed.connect(func(): _switch_tab("neutral"))
	tab_container.add_child(btn_tab_neutral)

	outer_vbox.add_child(HSeparator.new())
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(content_scroll)
	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 6)
	content_scroll.add_child(content_container)

# ═══════════════ PUBLIC API ═══════════════

func show_panel() -> void:
	_visible = true; root.visible = true; _refresh()

func hide_panel() -> void:
	_visible = false; root.visible = false

func is_panel_visible() -> bool:
	return _visible

# ═══════════════ TABS ═══════════════

func _switch_tab(tab: String) -> void:
	_current_tab = tab; _refresh()

func _update_tab_highlight() -> void:
	var tabs_map: Dictionary = {"evil": btn_tab_evil, "light": btn_tab_light, "neutral": btn_tab_neutral}
	for key in tabs_map:
		if key == _current_tab:
			tabs_map[key].add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		else:
			tabs_map[key].remove_theme_color_override("font_color")

# ═══════════════ REFRESH ═══════════════

func _refresh() -> void:
	_update_tab_highlight(); _clear_content()
	match _current_tab:
		"evil": _build_evil_factions()
		"light": _build_light_factions()
		"neutral": _build_neutral_factions()

func _clear_content() -> void:
	for node in _faction_nodes:
		if is_instance_valid(node): node.queue_free()
	_faction_nodes.clear()

func _build_evil_factions() -> void:
	## 恶势力阵营: ORC, PIRATE, DARK_ELF — 使用 DiplomacyManager
	var pid: int = GameManager.get_human_player_id()
	var factions: Array = [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]
	var player_faction: int = GameManager.get_player_faction(pid)

	for fid in factions:
		if fid == player_faction: continue
		var rel: Dictionary = DiplomacyManager.get_all_relations(pid).get(fid, {})
		var fname: String = FactionData.FACTION_NAMES.get(fid, "未知")
		var recruited: bool = rel.get("recruited", false)
		var hostile: bool = rel.get("hostile", false)
		var ceasefire: bool = DiplomacyManager.is_ceasefire_active(pid, fid)
		var method: String = rel.get("method", "")
		# Determine status
		var status_text: String; var status_color: Color
		if recruited:
			if method == "diplomacy":
				status_text = "已收编 (外交)"; status_color = Color(0.3, 0.9, 0.4)
			else:
				status_text = "已征服"; status_color = Color(0.9, 0.7, 0.2)
				var reb: int = rel.get("rebellion_turns", 0)
				if reb > 0: status_text += " (叛乱风险: %d回合)" % reb
		elif ceasefire:
			status_text = "停战中"; status_color = Color(0.6, 0.7, 1.0)
		elif hostile:
			status_text = "敌对"; status_color = Color(1.0, 0.4, 0.3)
		else:
			status_text = "中立"; status_color = Color(0.7, 0.7, 0.75)

		var card := _build_faction_card(fname, status_text, status_color, _get_evil_faction_color(fid))
		# Action buttons for non-recruited factions
		if not recruited:
			var actions: Array = DiplomacyManager.get_available_actions(pid, fid)
			var btn_row := HBoxContainer.new()
			btn_row.add_theme_constant_override("separation", 6)
			card.get_child(0).add_child(btn_row)
			for action in actions:
				var btn := Button.new()
				btn.text = "%s (%s)" % [action["name"], action["cost"]]
				btn.tooltip_text = action.get("desc", "")
				btn.custom_minimum_size = Vector2(160, 30)
				btn.add_theme_font_size_override("font_size", 12)
				var aid: String = action["id"]; var cfid: int = fid
				btn.pressed.connect(_on_evil_action.bind(cfid, aid))
				btn_row.add_child(btn)
			# Send gift (non-orc, non-hostile only)
			if not DiplomacyManager.is_orc_player(pid) and not hostile:
				var btn_gift := Button.new()
				btn_gift.text = "赠礼 (50金)"
				btn_gift.custom_minimum_size = Vector2(120, 30)
				btn_gift.add_theme_font_size_override("font_size", 12)
				btn_gift.pressed.connect(_on_send_gift.bind(fid))
				btn_row.add_child(btn_gift)
		content_container.add_child(card); _faction_nodes.append(card)

func _build_light_factions() -> void:
	## 光明阵营: HUMAN_KINGDOM, HIGH_ELVES, MAGE_TOWER — 始终敌对
	for lfid in FactionData.LIGHT_FACTION_NAMES:
		var fname: String = FactionData.LIGHT_FACTION_NAMES[lfid]
		var card := _build_faction_card(fname, "敌对 (光明阵营)", Color(1.0, 0.5, 0.3), Color(0.4, 0.6, 1.0))
		var note := Label.new()
		note.text = "光明阵营与暗势力天然敌对, 只能通过战争征服"
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD
		card.get_child(0).add_child(note)
		content_container.add_child(card); _faction_nodes.append(card)

func _build_neutral_factions() -> void:
	## 中立势力: 6 neutral factions with taming system (0-10)
	var pid: int = GameManager.get_human_player_id()
	for nfid in FactionData.NEUTRAL_FACTION_NAMES:
		var fname: String = FactionData.NEUTRAL_FACTION_NAMES[nfid]
		var taming: int = QuestManager.get_taming_level(pid, nfid)
		var tier: String = QuestManager.get_taming_tier(pid, nfid)
		var recruited: bool = QuestManager.is_faction_recruited(pid, nfid) if QuestManager.has_method("is_faction_recruited") else (taming >= 10)
		var status_text: String; var status_color: Color
		match tier:
			"hostile": status_text = "敌意"; status_color = Color(1.0, 0.4, 0.3)
			"neutral": status_text = "中立"; status_color = Color(0.7, 0.7, 0.75)
			"friendly": status_text = "友好"; status_color = Color(0.5, 0.8, 0.4)
			"allied": status_text = "同盟"; status_color = Color(0.3, 0.7, 1.0)
			"tamed": status_text = "驯服"; status_color = Color(1.0, 0.85, 0.3)
			_: status_text = tier; status_color = Color(0.6, 0.6, 0.6)
		if recruited:
			status_text = "已收编"; status_color = Color(0.3, 1.0, 0.5)
		var card := _build_faction_card(fname, status_text, status_color, Color(0.8, 0.7, 0.5))
		# Taming progress bar
		var taming_row := HBoxContainer.new()
		taming_row.add_theme_constant_override("separation", 8)
		card.get_child(0).add_child(taming_row)
		var taming_lbl := Label.new()
		taming_lbl.text = "驯服度: %d/10" % taming
		taming_lbl.custom_minimum_size = Vector2(90, 0)
		taming_lbl.add_theme_font_size_override("font_size", 12)
		taming_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
		taming_row.add_child(taming_lbl)
		var bar := ProgressBar.new()
		bar.min_value = 0; bar.max_value = 10; bar.value = taming
		bar.custom_minimum_size = Vector2(200, 16); bar.show_percentage = false
		taming_row.add_child(bar)
		# Threshold labels
		var threshold_lbl := Label.new()
		threshold_lbl.text = "  0=敌意  3=中立  5=友好  7=同盟  10=驯服"
		threshold_lbl.add_theme_font_size_override("font_size", 10)
		threshold_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		card.get_child(0).add_child(threshold_lbl)
		# Quest step
		if QuestManager.has_method("get_quest_step"):
			var step: int = QuestManager.get_quest_step(pid, nfid)
			var quest_lbl := Label.new()
			quest_lbl.text = "任务进度: %d/3 步骤" % step
			quest_lbl.add_theme_font_size_override("font_size", 12)
			quest_lbl.add_theme_color_override("font_color", Color(0.6, 0.7, 0.5))
			card.get_child(0).add_child(quest_lbl)
		content_container.add_child(card); _faction_nodes.append(card)

# ═══════════════ FACTION CARD BUILDER ═══════════════

func _build_faction_card(fname: String, status_text: String, status_color: Color, name_color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.07, 0.12, 0.9)
	s.border_color = Color(0.3, 0.25, 0.2)
	s.set_border_width_all(1); s.set_corner_radius_all(6); s.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", s)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	vbox.add_child(title_row)
	var name_lbl := Label.new()
	name_lbl.text = fname; name_lbl.add_theme_font_size_override("font_size", 16)
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
	var pid: int = GameManager.get_human_player_id()
	match action_id:
		"recruit_diplomacy":
			var ok: bool = DiplomacyManager.recruit_by_diplomacy(pid, faction_id)
			if not ok:
				for msg in DiplomacyManager.can_diplomacy(pid, faction_id).get("missing", []):
					EventBus.message_log.emit("[color=red]%s[/color]" % msg)
		"ceasefire": DiplomacyManager.offer_ceasefire(pid, faction_id)
		"declare_war": DiplomacyManager.mark_hostile(pid, faction_id)
	_refresh()

func _on_send_gift(faction_id: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	if not ResourceManager.can_afford(pid, {"gold": 50}):
		EventBus.message_log.emit("[color=red]金币不足 (需要50金)[/color]"); return
	ResourceManager.spend(pid, {"gold": 50})
	EventBus.message_log.emit("向 %s 赠送贡品 (-50金)" % FactionData.FACTION_NAMES.get(faction_id, "未知"))
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

# ═══════════════ HELPERS ═══════════════

func _make_tab_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text; btn.custom_minimum_size = Vector2(130, 32)
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func _get_evil_faction_color(fid: int) -> Color:
	match fid:
		FactionData.FactionID.ORC: return Color(0.9, 0.5, 0.2)
		FactionData.FactionID.PIRATE: return Color(0.4, 0.6, 0.9)
		FactionData.FactionID.DARK_ELF: return Color(0.6, 0.3, 0.8)
	return Color(0.7, 0.7, 0.75)
