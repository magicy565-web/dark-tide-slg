## pirate_panel.gd - Pirate Fleet Panel UI for Dark Tide SLG (v2.0)
## Shows pirate stats, black market, smuggling routes, mercenaries, active raids, and harem.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── State ──
var _visible: bool = false
var _current_tab: String = "market"  # "market", "treasure", "smuggle", "mercs", "raids", "harem"

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var stat_infamy: Label
var stat_rum: Label
var stat_streak: Label
var tab_container: HBoxContainer
var btn_tab_market: Button
var btn_tab_treasure: Button
var btn_tab_smuggle: Button
var btn_tab_mercs: Button
var btn_tab_raids: Button
var btn_tab_harem: Button
var content_scroll: ScrollContainer
var content_container: VBoxContainer
var _content_nodes: Array = []

# ── Theme colors ──
const COL_BG := Color(0.04, 0.06, 0.14, 0.97)
const COL_BORDER := Color(0.75, 0.6, 0.2)
const COL_GOLD := Color(1.0, 0.85, 0.3)
const COL_CARD_BG := Color(0.06, 0.08, 0.18, 0.9)
const COL_CARD_BORDER := Color(0.4, 0.35, 0.15)
const COL_DIM := Color(0.6, 0.6, 0.65)
const COL_GOOD := Color(0.3, 0.9, 0.4)
const COL_WARN := Color(1.0, 0.5, 0.3)

# ── Item category colors ──
const COL_CAT_WEAPON := Color(1.0, 0.4, 0.35)
const COL_CAT_SUPPLY := Color(0.4, 0.85, 0.5)
const COL_CAT_SPECIAL := Color(0.6, 0.5, 1.0)
const COL_CAT_CONSUMABLE := Color(0.3, 0.75, 0.95)
const COL_CAT_SLAVE := Color(1.0, 0.55, 0.75)

# ── Treasure reward type colors ──
const COL_TREASURE_GOLD := Color(1.0, 0.85, 0.2)
const COL_TREASURE_MERC := Color(0.45, 0.7, 1.0)
const COL_TREASURE_SLAVE := Color(1.0, 0.45, 0.65)
const COL_TREASURE_RUM := Color(1.0, 0.6, 0.15)
const COL_TREASURE_ITEM := Color(0.7, 0.4, 1.0)

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	layer = 5; _build_ui(); _connect_signals(); hide_panel()

func _connect_signals() -> void:
	EventBus.infamy_changed.connect(func(_p, _v): _refresh_stats())
	EventBus.rum_morale_changed.connect(func(_p, _v): _refresh_stats())
	EventBus.black_market_refreshed.connect(func(_p, _c): if _visible: _refresh())
	EventBus.resources_changed.connect(func(_p): if _visible: _refresh())
	EventBus.heroine_submission_changed.connect(func(_hid, _val): if _visible: _refresh())
	EventBus.harem_progress_updated.connect(func(_r, _s, _t): if _visible: _refresh())

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.game_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:
			if _visible: hide_panel()
			else: show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			hide_panel(); get_viewport().set_input_as_handled()

# ═══════════════ BUILD UI ═══════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "PirateRoot"
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
	style.bg_color = COL_BG; style.border_color = COL_BORDER
	style.set_border_width_all(2); style.set_corner_radius_all(10); style.set_content_margin_all(12)
	main_panel.add_theme_stylebox_override("panel", style)
	root.add_child(main_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	main_panel.add_child(outer_vbox)

	# ── Header row ──
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header_row)
	header_label = Label.new()
	header_label.text = "Pirate Fleet"
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", COL_GOLD)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)
	btn_close = Button.new()
	btn_close.text = "X"; btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	# ── Stats bar ──
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 24)
	outer_vbox.add_child(stats_row)
	stat_infamy = _make_stat_label("Infamy: 0/100")
	stats_row.add_child(stat_infamy)
	stat_rum = _make_stat_label("Rum Morale: 0/100")
	stats_row.add_child(stat_rum)
	stat_streak = _make_stat_label("Plunder Streak: 0")
	stats_row.add_child(stat_streak)

	# ── Tab buttons ──
	tab_container = HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(tab_container)
	btn_tab_market = _make_tab_button("Black Market")
	btn_tab_market.pressed.connect(func(): _switch_tab("market"))
	tab_container.add_child(btn_tab_market)
	btn_tab_treasure = _make_tab_button("Treasure Hunt")
	btn_tab_treasure.pressed.connect(func(): _switch_tab("treasure"))
	tab_container.add_child(btn_tab_treasure)
	btn_tab_smuggle = _make_tab_button("Smuggle Routes")
	btn_tab_smuggle.pressed.connect(func(): _switch_tab("smuggle"))
	tab_container.add_child(btn_tab_smuggle)
	btn_tab_mercs = _make_tab_button("Mercenaries")
	btn_tab_mercs.pressed.connect(func(): _switch_tab("mercs"))
	tab_container.add_child(btn_tab_mercs)
	btn_tab_raids = _make_tab_button("Raids")
	btn_tab_raids.pressed.connect(func(): _switch_tab("raids"))
	tab_container.add_child(btn_tab_raids)
	btn_tab_harem = _make_tab_button("Harem")
	btn_tab_harem.pressed.connect(func(): _switch_tab("harem"))
	tab_container.add_child(btn_tab_harem)

	outer_vbox.add_child(HSeparator.new())

	# ── Content scroll ──
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
	AudioManager.play_ui_cancel()
	_visible = false; root.visible = false

func is_panel_visible() -> bool:
	return _visible

# ═══════════════ TABS ═══════════════

func _switch_tab(tab: String) -> void:
	AudioManager.play_ui_click()
	_current_tab = tab; _refresh()

func _update_tab_highlight() -> void:
	var tabs_map := {"market": btn_tab_market, "treasure": btn_tab_treasure, "smuggle": btn_tab_smuggle, "mercs": btn_tab_mercs, "raids": btn_tab_raids, "harem": btn_tab_harem}
	for key in tabs_map:
		if key == _current_tab:
			tabs_map[key].add_theme_color_override("font_color", COL_GOLD)
		else:
			tabs_map[key].remove_theme_color_override("font_color")

# ═══════════════ REFRESH ═══════════════

func _refresh() -> void:
	_update_tab_highlight(); _refresh_stats(); _clear_content()
	match _current_tab:
		"market": _build_market()
		"treasure": _build_treasure()
		"smuggle": _build_smuggle()
		"mercs": _build_mercs()
		"raids": _build_raids()
		"harem": _build_harem()

func _refresh_stats() -> void:
	var pid: int = GameManager.get_human_player_id()
	var infamy: int = PirateMechanic.get_infamy(pid)
	var rum: int = PirateMechanic.get_rum_morale(pid)
	var streak: int = PirateMechanic._plunder_streak.get(pid, 0)
	stat_infamy.text = "Infamy: %d/100" % infamy
	stat_infamy.add_theme_color_override("font_color", COL_WARN if infamy >= 70 else COL_GOLD)
	stat_rum.text = "Rum Morale: %d/100" % rum
	stat_rum.add_theme_color_override("font_color", COL_WARN if rum >= 90 else COL_GOOD if rum >= 50 else COL_DIM)
	stat_streak.text = "Plunder Streak: %d" % streak

func _clear_content() -> void:
	for node in _content_nodes:
		if is_instance_valid(node): node.queue_free()
	_content_nodes.clear()

# ═══════════════ BLACK MARKET ═══════════════

func _get_category_color(category: String) -> Color:
	match category:
		"weapon": return COL_CAT_WEAPON
		"supply": return COL_CAT_SUPPLY
		"special": return COL_CAT_SPECIAL
		"consumable": return COL_CAT_CONSUMABLE
		"slave": return COL_CAT_SLAVE
	return COL_DIM

func _get_category_icon(category: String) -> String:
	match category:
		"weapon": return "[WPN]"
		"supply": return "[SUP]"
		"special": return "[SPC]"
		"consumable": return "[CON]"
		"slave": return "[SLV]"
	return "[?]"

func _get_category_label(category: String) -> String:
	match category:
		"weapon": return "Weapon"
		"supply": return "Supply"
		"special": return "Special"
		"consumable": return "Consumable"
		"slave": return "Slave"
	return "Unknown"

func _build_market() -> void:
	var pid: int = GameManager.get_human_player_id()
	var stock: Array = PirateMechanic.get_market_stock(pid)

	# ── Market header: stock count + infamy trade modifier ──
	var header_card := _make_card()
	var hv: VBoxContainer = header_card.get_child(0)
	var infamy: int = PirateMechanic.get_infamy(pid)
	var trade_mult: float = PirateMechanic.get_infamy_trade_mult(pid)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 16)
	hv.add_child(header_row)
	var hl := Label.new()
	hl.text = "Market Stock: %d items" % stock.size()
	hl.add_theme_font_size_override("font_size", 15)
	hl.add_theme_color_override("font_color", COL_GOLD)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(hl)
	var trade_lbl := Label.new()
	if trade_mult != 1.0:
		trade_lbl.text = "Price mod: x%.2f (Infamy %d)" % [trade_mult, infamy]
		trade_lbl.add_theme_color_override("font_color", COL_WARN if trade_mult > 1.0 else COL_GOOD)
	else:
		trade_lbl.text = "Normal price (Infamy %d)" % infamy
		trade_lbl.add_theme_color_override("font_color", COL_DIM)
	trade_lbl.add_theme_font_size_override("font_size", 12)
	header_row.add_child(trade_lbl)
	content_container.add_child(header_card); _content_nodes.append(header_card)

	if stock.is_empty():
		_add_empty_label("Market empty, refreshes next turn"); return

	for i in range(stock.size()):
		var item: Dictionary = stock[i]
		var category: String = item.get("category", "")
		var cat_color: Color = _get_category_color(category)

		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = COL_CARD_BG
		cs.border_color = cat_color.darkened(0.3)
		cs.set_border_width_all(1)
		cs.border_width_left = 3  # Thick left border as category accent
		cs.set_corner_radius_all(6); cs.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", cs)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		# Row 1: [category icon] name + price button
		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		vbox.add_child(top_row)

		var cat_tag := Label.new()
		cat_tag.text = _get_category_icon(category)
		cat_tag.add_theme_font_size_override("font_size", 13)
		cat_tag.add_theme_color_override("font_color", cat_color)
		top_row.add_child(cat_tag)

		var name_lbl := Label.new()
		name_lbl.text = item.get("name", "???")
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", COL_GOLD)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(name_lbl)

		var cat_lbl := Label.new()
		cat_lbl.text = _get_category_label(category)
		cat_lbl.add_theme_font_size_override("font_size", 11)
		cat_lbl.add_theme_color_override("font_color", cat_color.darkened(0.15))
		top_row.add_child(cat_lbl)

		# Row 2: description + effect hint
		var desc_row := HBoxContainer.new()
		desc_row.add_theme_constant_override("separation", 12)
		vbox.add_child(desc_row)
		var desc_lbl := Label.new()
		desc_lbl.text = item.get("desc", "")
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc_row.add_child(desc_lbl)

		var effect_hint := Label.new()
		effect_hint.text = _get_effect_hint(item)
		effect_hint.add_theme_font_size_override("font_size", 11)
		effect_hint.add_theme_color_override("font_color", COL_GOOD)
		desc_row.add_child(effect_hint)

		# Row 3: buy button (with adjusted price)
		var btn_row := HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_END
		vbox.add_child(btn_row)
		var final_price: int = maxi(int(float(item.get("price", 0)) / maxf(trade_mult, 0.01)), 1)
		var btn := Button.new()
		btn.text = "Buy (%dg)" % final_price
		btn.custom_minimum_size = Vector2(130, 30)
		btn.add_theme_font_size_override("font_size", 13)
		var idx: int = i
		btn.pressed.connect(_on_buy_market.bind(idx))
		var player_gold: int = ResourceManager.get_resource(pid, "gold")
		if player_gold < final_price:
			btn.disabled = true
			btn.tooltip_text = "Not enough gold"
		btn_row.add_child(btn)

		content_container.add_child(card); _content_nodes.append(card)


func _get_effect_hint(item: Dictionary) -> String:
	var effect: String = item.get("effect", "")
	var value: int = item.get("value", 0)
	match effect:
		"atk_boost": return "ATK+%d" % value
		"rum": return "Morale+%d" % value
		"iron": return "Iron+%d" % value
		"food": return "Food+%d" % value
		"treasure_map": return "Treasure map obtained"
		"scout_range": return "Scout +%d turns" % value
		"smuggle_boost": return "Smuggle +%dg" % value
		"infamy": return "Infamy +%d" % value
		"escape_bonus": return "Retreat +%d%%" % value
		"heal": return "HP+%d" % value
		"slave_train_all": return "Train +%d" % value
		"slave_capture_bonus": return "Capture +%d" % value
		"prestige": return "Prestige +%d" % value
		"gold": return "Gold +%d" % value
	return ""


# ═══════════════ TREASURE HUNTING ═══════════════

func _get_treasure_reward_color(reward_type: String) -> Color:
	match reward_type:
		"gold": return COL_TREASURE_GOLD
		"mercenary": return COL_TREASURE_MERC
		"sex_slave": return COL_TREASURE_SLAVE
		"rum": return COL_TREASURE_RUM
		"item": return COL_TREASURE_ITEM
	return COL_DIM

func _get_treasure_reward_label(reward_type: String) -> String:
	match reward_type:
		"gold": return "Gold Chest"
		"mercenary": return "Wandering Merc"
		"sex_slave": return "Captive Slave"
		"rum": return "Aged Rum"
		"item": return "Rare Weapon"
	return "Unknown Treasure"

func _get_treasure_reward_icon(reward_type: String) -> String:
	match reward_type:
		"gold": return "[G]"
		"mercenary": return "[M]"
		"sex_slave": return "[S]"
		"rum": return "[R]"
		"item": return "[W]"
	return "[?]"

func _build_treasure() -> void:
	var pid: int = GameManager.get_human_player_id()
	var maps: Array = PirateMechanic.get_treasure_maps(pid)

	# ── Treasure header card ──
	var header_card := _make_card()
	var hv: VBoxContainer = header_card.get_child(0)
	var h_row := HBoxContainer.new()
	h_row.add_theme_constant_override("separation", 16)
	hv.add_child(h_row)
	var hl := Label.new()
	hl.text = "Maps: %d" % maps.size()
	hl.add_theme_font_size_override("font_size", 16)
	hl.add_theme_color_override("font_color", COL_GOLD)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_row.add_child(hl)
	var hint_lbl := Label.new()
	hint_lbl.text = "Battle wins have %d%% chance to drop treasure maps" % int(PirateMechanic.TREASURE_MAP_DROP_CHANCE * 100)
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.add_theme_color_override("font_color", COL_DIM)
	h_row.add_child(hint_lbl)
	content_container.add_child(header_card); _content_nodes.append(header_card)

	if maps.is_empty():
		_add_empty_label("No treasure maps -- win battles or buy from market"); return

	for i in range(maps.size()):
		var tmap: Dictionary = maps[i]
		var reward_type: String = tmap.get("reward_type", "gold")
		var reward_value: int = tmap.get("reward_value", 0)
		var tile_idx: int = tmap.get("tile_index", -1)
		var rcolor: Color = _get_treasure_reward_color(reward_type)

		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.08, 0.07, 0.16, 0.92)
		cs.border_color = rcolor.darkened(0.25)
		cs.set_border_width_all(1)
		cs.border_width_left = 3
		cs.set_corner_radius_all(6); cs.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", cs)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		# Row 1: Treasure icon + type + location
		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		vbox.add_child(top_row)

		var icon_lbl := Label.new()
		icon_lbl.text = _get_treasure_reward_icon(reward_type)
		icon_lbl.add_theme_font_size_override("font_size", 14)
		icon_lbl.add_theme_color_override("font_color", rcolor)
		top_row.add_child(icon_lbl)

		var type_lbl := Label.new()
		type_lbl.text = "Map #%d: %s" % [i + 1, _get_treasure_reward_label(reward_type)]
		type_lbl.add_theme_font_size_override("font_size", 15)
		type_lbl.add_theme_color_override("font_color", rcolor)
		type_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(type_lbl)

		var loc_lbl := Label.new()
		loc_lbl.text = "Location: Tile %d" % tile_idx
		loc_lbl.add_theme_font_size_override("font_size", 12)
		loc_lbl.add_theme_color_override("font_color", COL_DIM)
		top_row.add_child(loc_lbl)

		# Row 2: Expected reward description
		var reward_desc := Label.new()
		reward_desc.add_theme_font_size_override("font_size", 12)
		reward_desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		match reward_type:
			"gold":
				reward_desc.text = "Expected reward: ~%d gold" % reward_value
			"mercenary":
				reward_desc.text = "Expected reward: Mercenary x%d" % reward_value
			"sex_slave":
				reward_desc.text = "Expected reward: Slave x%d" % reward_value
			"rum":
				reward_desc.text = "Expected reward: Rum Morale +%d" % reward_value
			"item":
				reward_desc.text = "Expected reward: Rare Weapon (ATK+15)"
		vbox.add_child(reward_desc)

		# Row 3: Explore button
		var btn_row := HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_END
		vbox.add_child(btn_row)
		var btn := Button.new()
		btn.text = "Explore"
		btn.custom_minimum_size = Vector2(130, 30)
		btn.add_theme_font_size_override("font_size", 13)
		var map_idx: int = i
		btn.pressed.connect(_on_explore_treasure.bind(map_idx))
		btn_row.add_child(btn)

		content_container.add_child(card); _content_nodes.append(card)

# ═══════════════ SMUGGLING ROUTES ═══════════════

func _build_smuggle() -> void:
	var pid: int = GameManager.get_human_player_id()
	var routes: Array = PirateMechanic.get_smuggle_routes(pid)
	var income: int = PirateMechanic.get_smuggle_income(pid)
	var infamy: int = PirateMechanic.get_infamy(pid)

	# ── Summary card with income breakdown ──
	var summary := _make_card()
	var sv: VBoxContainer = summary.get_child(0)
	var s_row := HBoxContainer.new()
	s_row.add_theme_constant_override("separation", 16)
	sv.add_child(s_row)
	var sl := Label.new()
	sl.text = "Routes: %d/%d" % [routes.size(), PirateMechanic.MAX_SMUGGLE_ROUTES]
	sl.add_theme_font_size_override("font_size", 15)
	sl.add_theme_color_override("font_color", COL_GOLD)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_row.add_child(sl)
	var income_lbl := Label.new()
	income_lbl.text = "Per turn: +%dg" % income
	income_lbl.add_theme_font_size_override("font_size", 14)
	income_lbl.add_theme_color_override("font_color", COL_GOOD if income > 0 else COL_DIM)
	s_row.add_child(income_lbl)
	# Risk warning based on infamy
	if infamy >= PirateMechanic.INFAMY_HIGH_THRESHOLD:
		var warn := Label.new()
		warn.text = "High infamy: smuggle routes may be disrupted!"
		warn.add_theme_font_size_override("font_size", 11)
		warn.add_theme_color_override("font_color", COL_WARN)
		sv.add_child(warn)
	# Capacity hint
	if routes.size() < PirateMechanic.MAX_SMUGGLE_ROUTES:
		var cap_hint := Label.new()
		cap_hint.text = "Capture more coastal territory to open new routes (%d remaining)" % (PirateMechanic.MAX_SMUGGLE_ROUTES - routes.size())
		cap_hint.add_theme_font_size_override("font_size", 11)
		cap_hint.add_theme_color_override("font_color", Color(0.5, 0.65, 0.8))
		sv.add_child(cap_hint)
	content_container.add_child(summary); _content_nodes.append(summary)

	if routes.is_empty():
		_add_empty_label("No smuggle routes. Capture coastal territory to establish them"); return

	for i in range(routes.size()):
		var route: Array = routes[i]
		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = COL_CARD_BG
		cs.border_color = Color(0.25, 0.45, 0.6)
		cs.set_border_width_all(1)
		cs.border_width_left = 3
		cs.set_corner_radius_all(6); cs.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", cs)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		card.add_child(vbox)

		if route.size() < 2:
			card.queue_free()
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)
		var route_icon := Label.new()
		route_icon.text = "[R]"
		route_icon.add_theme_font_size_override("font_size", 13)
		route_icon.add_theme_color_override("font_color", Color(0.3, 0.65, 0.9))
		row.add_child(route_icon)
		var rl := Label.new()
		rl.text = "Route #%d: Tile %d <-> Tile %d" % [i + 1, route[0], route[1]]
		rl.add_theme_font_size_override("font_size", 14)
		rl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rl)
		var profit := Label.new()
		profit.text = "+%dg/turn" % PirateMechanic.SMUGGLE_INCOME_PER_ROUTE
		profit.add_theme_font_size_override("font_size", 13)
		profit.add_theme_color_override("font_color", COL_GOOD)
		row.add_child(profit)
		var btn := Button.new()
		btn.text = "Abolish"
		btn.custom_minimum_size = Vector2(70, 26)
		btn.add_theme_font_size_override("font_size", 12)
		var ri: int = i
		btn.pressed.connect(_on_destroy_route.bind(ri))
		row.add_child(btn)

		content_container.add_child(card); _content_nodes.append(card)

# ═══════════════ MERCENARIES ═══════════════

func _build_mercs() -> void:
	var pid: int = GameManager.get_human_player_id()
	var mercs: Array = PirateMechanic.get_available_mercenaries(pid)
	var player_gold: int = ResourceManager.get_resource(pid, "gold")

	# ── Header card ──
	var header_card := _make_card()
	var hcv: VBoxContainer = header_card.get_child(0)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 16)
	hcv.add_child(hrow)
	var htitle := Label.new()
	htitle.text = "Mercenary Market"
	htitle.add_theme_font_size_override("font_size", 15)
	htitle.add_theme_color_override("font_color", COL_GOLD)
	htitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(htitle)
	var gold_lbl := Label.new()
	gold_lbl.text = "Gold: %d" % player_gold
	gold_lbl.add_theme_font_size_override("font_size", 13)
	gold_lbl.add_theme_color_override("font_color", COL_GOLD)
	hrow.add_child(gold_lbl)
	var hint := Label.new()
	hint.text = "Mercenaries are weaker than regulars but provide quick reinforcement"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", COL_DIM)
	hcv.add_child(hint)
	content_container.add_child(header_card); _content_nodes.append(header_card)

	if mercs.is_empty():
		_add_empty_label("No mercenaries available"); return

	for merc in mercs:
		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = COL_CARD_BG
		cs.border_color = Color(0.3, 0.4, 0.55)
		cs.set_border_width_all(1)
		cs.border_width_left = 3
		cs.set_corner_radius_all(6); cs.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", cs)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		card.add_child(vbox)

		# Row 1: Name
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		vbox.add_child(name_row)
		var nl := Label.new()
		nl.text = merc.get("name", "?")
		nl.add_theme_font_size_override("font_size", 15)
		nl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(nl)
		var count_lbl := Label.new()
		count_lbl.text = "x%d" % merc.get("count", 0)
		count_lbl.add_theme_font_size_override("font_size", 14)
		count_lbl.add_theme_color_override("font_color", COL_GOLD)
		name_row.add_child(count_lbl)

		# Row 2: Stats (ATK / HP in colored labels)
		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 16)
		vbox.add_child(stat_row)
		var atk_lbl := Label.new()
		atk_lbl.text = "ATK: %d" % merc.get("atk", 0)
		atk_lbl.add_theme_font_size_override("font_size", 12)
		atk_lbl.add_theme_color_override("font_color", COL_CAT_WEAPON)
		stat_row.add_child(atk_lbl)
		var hp_lbl := Label.new()
		hp_lbl.text = "HP: %d" % merc.get("hp", 0)
		hp_lbl.add_theme_font_size_override("font_size", 12)
		hp_lbl.add_theme_color_override("font_color", COL_CAT_SUPPLY)
		stat_row.add_child(hp_lbl)
		var ce_lbl := Label.new()
		var cost_val: int = merc.get("adjusted_cost", merc.get("cost", 0))
		var count_val: int = merc.get("count", 1)
		ce_lbl.text = "Per unit: %.1fg" % (float(cost_val) / float(maxi(count_val, 1)))
		ce_lbl.add_theme_font_size_override("font_size", 11)
		ce_lbl.add_theme_color_override("font_color", COL_DIM)
		ce_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_row.add_child(ce_lbl)

		# Hire button
		var btn := Button.new()
		btn.text = "Hire (%dg)" % merc.get("adjusted_cost", 0)
		btn.custom_minimum_size = Vector2(130, 30)
		btn.add_theme_font_size_override("font_size", 13)
		var mid: String = merc.get("id", "")
		var adj_cost: int = merc.get("adjusted_cost", 0)
		btn.pressed.connect(_on_hire_merc.bind(pid, mid, adj_cost))
		if player_gold < adj_cost:
			btn.disabled = true
			btn.tooltip_text = "Not enough gold"
		stat_row.add_child(btn)

		content_container.add_child(card); _content_nodes.append(card)

# ═══════════════ ACTIVE RAIDS ═══════════════

func _build_raids() -> void:
	var raids: Array = PirateMechanic.get_active_raids()

	# ── Header card ──
	var header_card := _make_card()
	var hv: VBoxContainer = header_card.get_child(0)
	var h_row := HBoxContainer.new()
	h_row.add_theme_constant_override("separation", 16)
	hv.add_child(h_row)
	var hl := Label.new()
	hl.text = "AI Raids: %d/%d" % [raids.size(), PirateMechanic.AI_MAX_RAID_PARTIES]
	hl.add_theme_font_size_override("font_size", 15)
	hl.add_theme_color_override("font_color", COL_WARN if raids.size() > 0 else COL_DIM)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_row.add_child(hl)
	var reward_lbl := Label.new()
	reward_lbl.text = "Defeat reward: %dg/party" % PirateMechanic.AI_RAID_LOOT_ON_DEFEAT
	reward_lbl.add_theme_font_size_override("font_size", 12)
	reward_lbl.add_theme_color_override("font_color", COL_GOLD)
	h_row.add_child(reward_lbl)
	var spawn_hint := Label.new()
	spawn_hint.text = "%d%% chance to spawn new raid each turn" % int(PirateMechanic.AI_RAID_SPAWN_CHANCE * 100)
	spawn_hint.add_theme_font_size_override("font_size", 11)
	spawn_hint.add_theme_color_override("font_color", COL_DIM)
	hv.add_child(spawn_hint)
	content_container.add_child(header_card); _content_nodes.append(header_card)

	if raids.is_empty():
		_add_empty_label("No active AI raids -- peacetime"); return

	for i in range(raids.size()):
		var raid: Dictionary = raids[i]
		var turns_left: int = raid.get("turns_left", 0)
		var strength: int = raid.get("strength", 0)

		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.12, 0.06, 0.06, 0.92)
		cs.border_color = COL_WARN.darkened(0.2)
		cs.set_border_width_all(1)
		cs.border_width_left = 3
		cs.set_corner_radius_all(6); cs.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", cs)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		card.add_child(vbox)

		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 12)
		vbox.add_child(top_row)
		var raid_icon := Label.new()
		raid_icon.text = "[!]"
		raid_icon.add_theme_font_size_override("font_size", 14)
		raid_icon.add_theme_color_override("font_color", COL_WARN)
		top_row.add_child(raid_icon)
		var rl := Label.new()
		rl.text = "Raid #%d" % (i + 1)
		rl.add_theme_font_size_override("font_size", 14)
		rl.add_theme_color_override("font_color", COL_WARN)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(rl)

		var stat_row := HBoxContainer.new()
		stat_row.add_theme_constant_override("separation", 16)
		vbox.add_child(stat_row)
		var loc := Label.new()
		loc.text = "Location: Tile %d" % raid.get("tile_index", -1)
		loc.add_theme_font_size_override("font_size", 12)
		loc.add_theme_color_override("font_color", COL_DIM)
		stat_row.add_child(loc)
		var str_lbl := Label.new()
		str_lbl.text = "Strength: %d" % strength
		str_lbl.add_theme_font_size_override("font_size", 12)
		str_lbl.add_theme_color_override("font_color", COL_CAT_WEAPON)
		stat_row.add_child(str_lbl)
		var turn_lbl := Label.new()
		turn_lbl.text = "Remaining: %d turns" % turns_left
		turn_lbl.add_theme_font_size_override("font_size", 12)
		turn_lbl.add_theme_color_override("font_color", COL_WARN if turns_left <= 1 else COL_DIM)
		stat_row.add_child(turn_lbl)

		content_container.add_child(card); _content_nodes.append(card)

# ═══════════════ HAREM -- Lance 07 Style Gallery ═══════════════

# ── Silhouette color scheme ──
const COL_LOCKED := Color(0.15, 0.15, 0.18)
const COL_CAPTURED := Color(0.3, 0.12, 0.12)
const COL_HUMAN := Color(0.85, 0.7, 0.35)
const COL_HIGH_ELF := Color(0.3, 0.7, 0.35)
const COL_MAGE := Color(0.3, 0.4, 0.8)
const COL_PIRATE_HERO := Color(0.2, 0.35, 0.65)
const COL_DARK_ELF_HERO := Color(0.45, 0.15, 0.55)
const COL_NEUTRAL_HERO := Color(0.5, 0.5, 0.45)
const COL_GOLD_BORDER := Color(1.0, 0.85, 0.2)

func _get_faction_color(faction: String) -> Color:
	match faction:
		"human": return COL_HUMAN
		"high_elf": return COL_HIGH_ELF
		"mage": return COL_MAGE
		"pirate": return COL_PIRATE_HERO
		"dark_elf": return COL_DARK_ELF_HERO
		"neutral": return COL_NEUTRAL_HERO
	return COL_LOCKED

## Determine the visual state of a hero for the gallery.
## Returns: "locked", "captured", "recruited", "bedding", "unlocked"
func _get_hero_state(hero_id: String) -> String:
	if HeroSystem.is_heroine_unlocked(hero_id):
		return "unlocked"
	var sub: int = HeroSystem.get_submission(hero_id)
	if hero_id in HeroSystem.recruited_heroes:
		if sub >= 5:
			return "bedding"
		return "recruited"
	if hero_id in HeroSystem.captured_heroes:
		return "captured"
	return "locked"

func _build_harem() -> void:
	var pid: int = GameManager.get_human_player_id()

	# ── Count unlocked for progress header ──
	var all_hero_ids: Array = FactionData.HEROES.keys()
	var total_count: int = all_hero_ids.size()
	var unlocked_count: int = 0
	for hid in all_hero_ids:
		if HeroSystem.is_heroine_unlocked(hid):
			unlocked_count += 1

	# ── Progress header card ──
	var header_card := _make_card()
	var hv: VBoxContainer = header_card.get_child(0)
	var progress_label := Label.new()
	progress_label.text = "Harem %d/%d unlocked" % [unlocked_count, total_count]
	progress_label.add_theme_font_size_override("font_size", 16)
	progress_label.add_theme_color_override("font_color", COL_GOLD)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(progress_label)
	var progress_bar := ProgressBar.new()
	progress_bar.min_value = 0; progress_bar.max_value = maxi(total_count, 1)
	progress_bar.value = unlocked_count
	progress_bar.custom_minimum_size = Vector2(0, 20)
	progress_bar.show_percentage = false
	hv.add_child(progress_bar)
	content_container.add_child(header_card); _content_nodes.append(header_card)

	# ── Character gallery grid (3 per row) ──
	var columns: int = 3
	var current_row: HBoxContainer = null
	var col_index: int = 0

	for i in range(all_hero_ids.size()):
		var hero_id: String = all_hero_ids[i]
		var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
		var state: String = _get_hero_state(hero_id)
		var faction: String = hero_data.get("faction", "")
		var hero_name: String = hero_data.get("name", hero_id)
		var submission: int = HeroSystem.get_submission(hero_id)
		var cooldowns: Dictionary = HeroSystem.get_harem_cooldowns(hero_id)

		# Create new row if needed
		if col_index % columns == 0:
			current_row = HBoxContainer.new()
			current_row.add_theme_constant_override("separation", 8)
			current_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content_container.add_child(current_row)
			_content_nodes.append(current_row)

		# ── Build character card ──
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(120, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = COL_CARD_BG
		card_style.set_corner_radius_all(6)
		card_style.set_content_margin_all(6)
		# Gold border for unlocked heroes
		if state == "unlocked":
			card_style.border_color = COL_GOLD_BORDER
			card_style.set_border_width_all(2)
		else:
			card_style.border_color = COL_CARD_BORDER
			card_style.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", card_style)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card.add_child(card_vbox)

		# ── Silhouette rectangle ──
		var silhouette := ColorRect.new()
		silhouette.custom_minimum_size = Vector2(100, 140)
		silhouette.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var sil_color: Color
		match state:
			"locked":
				sil_color = COL_LOCKED
			"captured":
				sil_color = COL_CAPTURED
			"recruited":
				var fc: Color = _get_faction_color(faction)
				sil_color = fc.darkened(0.5)
			"bedding":
				var fc: Color = _get_faction_color(faction)
				sil_color = fc.darkened(0.2)
			"unlocked":
				sil_color = _get_faction_color(faction)
		silhouette.color = sil_color
		card_vbox.add_child(silhouette)

		# ── Name label ──
		var name_lbl := Label.new()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 13)
		if state == "locked":
			name_lbl.text = "???"
			name_lbl.add_theme_color_override("font_color", COL_DIM)
		elif state == "unlocked":
			name_lbl.text = hero_name + " \u2605Unlocked"
			name_lbl.add_theme_color_override("font_color", COL_GOLD)
		else:
			name_lbl.text = hero_name
			name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
		card_vbox.add_child(name_lbl)

		# ── Submission bar (recruited, bedding, unlocked only) ──
		if state in ["recruited", "bedding", "unlocked"]:
			var sub_bar := ProgressBar.new()
			sub_bar.min_value = 0; sub_bar.max_value = 10
			sub_bar.value = submission
			sub_bar.custom_minimum_size = Vector2(0, 14)
			sub_bar.show_percentage = false
			card_vbox.add_child(sub_bar)
			var sub_lbl := Label.new()
			sub_lbl.text = "Submit %d/10" % submission
			sub_lbl.add_theme_font_size_override("font_size", 10)
			sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if submission < 5:
				sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
			elif submission < 10:
				sub_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			else:
				sub_lbl.add_theme_color_override("font_color", COL_GOOD)
			card_vbox.add_child(sub_lbl)

		# ── Action buttons ──
		if state == "recruited" and submission < 5:
			# Train button
			var btn_train := Button.new()
			if cooldowns.get("train", 0) > 0:
				btn_train.text = "Train (CD:%d)" % cooldowns["train"]
				btn_train.disabled = true
			else:
				btn_train.text = "Train"
			btn_train.custom_minimum_size = Vector2(0, 26)
			btn_train.add_theme_font_size_override("font_size", 11)
			btn_train.pressed.connect(_on_train_heroine.bind(hero_id))
			card_vbox.add_child(btn_train)

		if state == "bedding" and submission >= 5 and submission < 10:
			# Bed button
			var btn_bed := Button.new()
			if cooldowns.get("bed", 0) > 0:
				btn_bed.text = "Bed (CD:%d)" % cooldowns["bed"]
				btn_bed.disabled = true
			else:
				btn_bed.text = "Bed"
			btn_bed.custom_minimum_size = Vector2(0, 26)
			btn_bed.add_theme_font_size_override("font_size", 11)
			btn_bed.pressed.connect(_on_bed_heroine.bind(hero_id))
			card_vbox.add_child(btn_bed)

		if (state == "bedding" or state == "recruited") and submission >= 10 and not HeroSystem.is_heroine_unlocked(hero_id):
			# Final story button
			var btn_final := Button.new()
			btn_final.text = "Final Story"
			btn_final.custom_minimum_size = Vector2(0, 26)
			btn_final.add_theme_font_size_override("font_size", 11)
			btn_final.add_theme_color_override("font_color", COL_GOLD)
			btn_final.pressed.connect(_on_final_story.bind(hero_id))
			card_vbox.add_child(btn_final)

		current_row.add_child(card)
		col_index += 1

	# Pad last row with spacers if needed
	if current_row != null:
		var remaining: int = columns - (col_index % columns)
		if remaining > 0 and remaining < columns:
			for _j in range(remaining):
				var spacer := Control.new()
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				current_row.add_child(spacer)

# ═══════════════ ACTION CALLBACKS ═══════════════

func _on_buy_market(item_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	var ok: bool = PirateMechanic.buy_market_item(pid, item_index)
	if ok:
		AudioManager.play_ui_confirm()
	if not ok:
		EventBus.message_log.emit("[color=red]Not enough gold or item sold out[/color]")
	_refresh()

func _on_explore_treasure(map_index: int) -> void:
	AudioManager.play_ui_confirm()
	var pid: int = GameManager.get_human_player_id()
	var result: Dictionary = PirateMechanic.explore_treasure(pid, map_index)
	if result.is_empty():
		EventBus.message_log.emit("[color=red]Treasure exploration failed[/color]")
	_refresh()

func _on_destroy_route(route_index: int) -> void:
	AudioManager.play_ui_click()
	var pid: int = GameManager.get_human_player_id()
	PirateMechanic.destroy_smuggle_route(pid, route_index)
	EventBus.message_log.emit("Smuggle route abolished")
	_refresh()

func _on_hire_merc(pid: int, merc_id: String, cost: int) -> void:
	if not ResourceManager.can_afford(pid, {"gold": cost}):
		EventBus.message_log.emit("[color=red]Not enough gold (need %dg)[/color]" % cost); return
	AudioManager.play_ui_confirm()
	ResourceManager.spend(pid, {"gold": cost})
	# Add soldiers from mercenary
	for merc in PirateMechanic.MERCENARY_TYPES:
		if merc["id"] == merc_id:
			ResourceManager.add_army(pid, merc["count"])
			EventBus.message_log.emit("Hired %s x%d (-%dg)" % [merc["name"], merc["count"], cost])
			break
	_refresh()

func _on_train_heroine(hero_id: String) -> void:
	AudioManager.play_ui_click()
	var result: Dictionary = HeroSystem.train_heroine(hero_id)
	if not result.get("success", false):
		EventBus.message_log.emit("[color=red]%s[/color]" % result.get("reason", "Training failed"))
	_refresh()

func _on_bed_heroine(hero_id: String) -> void:
	AudioManager.play_ui_click()
	var result: Dictionary = HeroSystem.bed_heroine(hero_id)
	if not result.get("success", false):
		EventBus.message_log.emit("[color=red]%s[/color]" % result.get("reason", "Bedding failed"))
	_refresh()

func _on_final_story(hero_id: String) -> void:
	AudioManager.play_ui_confirm()
	var result: Dictionary = HeroSystem.trigger_final_story(hero_id)
	if not result.get("success", false):
		EventBus.message_log.emit("[color=red]%s[/color]" % result.get("reason", "Story trigger failed"))
	_refresh()

func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: hide_panel()

# ═══════════════ HELPERS ═══════════════

func _make_card() -> PanelContainer:
	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = COL_CARD_BG; s.border_color = COL_CARD_BORDER
	s.set_border_width_all(1); s.set_corner_radius_all(6); s.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", s)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)
	return card

func _make_tab_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text; btn.custom_minimum_size = Vector2(100, 32)
	btn.add_theme_font_size_override("font_size", 14)
	return btn

func _make_stat_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", COL_DIM)
	return lbl

func _add_empty_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", COL_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(lbl); _content_nodes.append(lbl)
