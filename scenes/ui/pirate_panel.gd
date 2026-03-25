## pirate_panel.gd - 海盗势力面板 UI for 暗潮 SLG (v2.0)
## Shows pirate stats, black market, smuggling routes, mercenaries, and active raids.
extends CanvasLayer

# ── State ──
var _visible: bool = false
var _current_tab: String = "market"  # "market", "smuggle", "mercs", "raids"

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
var btn_tab_smuggle: Button
var btn_tab_mercs: Button
var btn_tab_raids: Button
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

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	layer = 5; _build_ui(); _connect_signals(); hide_panel()

func _connect_signals() -> void:
	EventBus.infamy_changed.connect(func(_p, _v): _refresh_stats())
	EventBus.rum_morale_changed.connect(func(_p, _v): _refresh_stats())
	EventBus.black_market_refreshed.connect(func(_p, _c): if _visible: _refresh())
	EventBus.resources_changed.connect(func(_p): if _visible: _refresh())

func _unhandled_input(event: InputEvent) -> void:
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
	header_label.text = "海盗势力"
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
	stat_infamy = _make_stat_label("恶名: 0/100")
	stats_row.add_child(stat_infamy)
	stat_rum = _make_stat_label("朗姆酒士气: 0/100")
	stats_row.add_child(stat_rum)
	stat_streak = _make_stat_label("掠夺连击: 0")
	stats_row.add_child(stat_streak)

	# ── Tab buttons ──
	tab_container = HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(tab_container)
	btn_tab_market = _make_tab_button("黑市")
	btn_tab_market.pressed.connect(func(): _switch_tab("market"))
	tab_container.add_child(btn_tab_market)
	btn_tab_smuggle = _make_tab_button("走私航线")
	btn_tab_smuggle.pressed.connect(func(): _switch_tab("smuggle"))
	tab_container.add_child(btn_tab_smuggle)
	btn_tab_mercs = _make_tab_button("雇佣兵")
	btn_tab_mercs.pressed.connect(func(): _switch_tab("mercs"))
	tab_container.add_child(btn_tab_mercs)
	btn_tab_raids = _make_tab_button("突袭")
	btn_tab_raids.pressed.connect(func(): _switch_tab("raids"))
	tab_container.add_child(btn_tab_raids)

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
	_visible = false; root.visible = false

func is_panel_visible() -> bool:
	return _visible

# ═══════════════ TABS ═══════════════

func _switch_tab(tab: String) -> void:
	_current_tab = tab; _refresh()

func _update_tab_highlight() -> void:
	var tabs_map := {"market": btn_tab_market, "smuggle": btn_tab_smuggle, "mercs": btn_tab_mercs, "raids": btn_tab_raids}
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
		"smuggle": _build_smuggle()
		"mercs": _build_mercs()
		"raids": _build_raids()

func _refresh_stats() -> void:
	var pid: int = GameManager.get_human_player_id()
	var infamy: int = PirateMechanic.get_infamy(pid)
	var rum: int = PirateMechanic.get_rum_morale(pid)
	var streak: int = PirateMechanic._plunder_streak.get(pid, 0)
	stat_infamy.text = "恶名: %d/100" % infamy
	stat_infamy.add_theme_color_override("font_color", COL_WARN if infamy >= 70 else COL_GOLD)
	stat_rum.text = "朗姆酒士气: %d/100" % rum
	stat_rum.add_theme_color_override("font_color", COL_WARN if rum >= 90 else COL_GOOD if rum >= 50 else COL_DIM)
	stat_streak.text = "掠夺连击: %d" % streak

func _clear_content() -> void:
	for node in _content_nodes:
		if is_instance_valid(node): node.queue_free()
	_content_nodes.clear()

# ═══════════════ BLACK MARKET ═══════════════

func _build_market() -> void:
	var pid: int = GameManager.get_human_player_id()
	var stock: Array = PirateMechanic.get_market_stock(pid)
	if stock.is_empty():
		_add_empty_label("黑市暂无商品, 下回合刷新"); return
	for i in range(stock.size()):
		var item: Dictionary = stock[i]
		var card := _make_card()
		var vbox: VBoxContainer = card.get_child(0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)
		var name_lbl := Label.new()
		name_lbl.text = item.get("name", "???")
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.add_theme_color_override("font_color", COL_GOLD)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var desc_lbl := Label.new()
		desc_lbl.text = item.get("desc", "")
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", COL_DIM)
		row.add_child(desc_lbl)
		var btn := Button.new()
		btn.text = "购买 (%d金)" % item.get("price", 0)
		btn.custom_minimum_size = Vector2(120, 28)
		btn.add_theme_font_size_override("font_size", 12)
		var idx: int = i
		btn.pressed.connect(_on_buy_market.bind(idx))
		row.add_child(btn)
		content_container.add_child(card); _content_nodes.append(card)

# ═══════════════ SMUGGLING ROUTES ═══════════════

func _build_smuggle() -> void:
	var pid: int = GameManager.get_human_player_id()
	var routes: Array = PirateMechanic.get_smuggle_routes(pid)
	var income: int = PirateMechanic.get_smuggle_income(pid)
	# Summary
	var summary := _make_card()
	var sv: VBoxContainer = summary.get_child(0)
	var sl := Label.new()
	sl.text = "走私航线: %d/%d | 每回合收入: %d金" % [routes.size(), PirateMechanic.MAX_SMUGGLE_ROUTES, income]
	sl.add_theme_font_size_override("font_size", 14)
	sl.add_theme_color_override("font_color", COL_GOLD)
	sv.add_child(sl)
	content_container.add_child(summary); _content_nodes.append(summary)
	if routes.is_empty():
		_add_empty_label("暂无走私航线, 占领沿海领地后可建立"); return
	for i in range(routes.size()):
		var route: Array = routes[i]
		var card := _make_card()
		var vbox: VBoxContainer = card.get_child(0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)
		var rl := Label.new()
		rl.text = "航线 #%d: 格%d <-> 格%d | +%d金/回合" % [i + 1, route[0], route[1], PirateMechanic.SMUGGLE_INCOME_PER_ROUTE]
		rl.add_theme_font_size_override("font_size", 13)
		rl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(rl)
		var btn := Button.new()
		btn.text = "废除"
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
	if mercs.is_empty():
		_add_empty_label("无可用佣兵"); return
	for merc in mercs:
		var card := _make_card()
		var vbox: VBoxContainer = card.get_child(0)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)
		var nl := Label.new()
		nl.text = "%s (ATK:%d HP:%d x%d)" % [merc.get("name", "?"), merc.get("atk", 0), merc.get("hp", 0), merc.get("count", 0)]
		nl.add_theme_font_size_override("font_size", 14)
		nl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		var btn := Button.new()
		btn.text = "雇佣 (%d金)" % merc.get("adjusted_cost", 0)
		btn.custom_minimum_size = Vector2(120, 28)
		btn.add_theme_font_size_override("font_size", 12)
		var mid: String = merc.get("id", "")
		btn.pressed.connect(_on_hire_merc.bind(pid, mid, merc.get("adjusted_cost", 0)))
		row.add_child(btn)
		content_container.add_child(card); _content_nodes.append(card)

# ═══════════════ ACTIVE RAIDS ═══════════════

func _build_raids() -> void:
	var raids: Array = PirateMechanic.get_active_raids()
	if raids.is_empty():
		_add_empty_label("当前无活跃的AI突袭队"); return
	for i in range(raids.size()):
		var raid: Dictionary = raids[i]
		var card := _make_card()
		var vbox: VBoxContainer = card.get_child(0)
		var rl := Label.new()
		rl.text = "突袭队 #%d | 位置: 格%d | 兵力: %d | 剩余: %d回合" % [
			i + 1, raid.get("tile_index", -1), raid.get("strength", 0), raid.get("turns_left", 0)]
		rl.add_theme_font_size_override("font_size", 14)
		rl.add_theme_color_override("font_color", COL_WARN)
		vbox.add_child(rl)
		var note := Label.new()
		note.text = "击败可获得 %d金" % PirateMechanic.AI_RAID_LOOT_ON_DEFEAT
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", COL_DIM)
		vbox.add_child(note)
		content_container.add_child(card); _content_nodes.append(card)

# ═══════════════ ACTION CALLBACKS ═══════════════

func _on_buy_market(item_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	var ok: bool = PirateMechanic.buy_market_item(pid, item_index)
	if not ok:
		EventBus.message_log.emit("[color=red]金币不足或商品已售罄[/color]")
	_refresh()

func _on_destroy_route(route_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	PirateMechanic.destroy_smuggle_route(pid, route_index)
	EventBus.message_log.emit("走私航线已废除")
	_refresh()

func _on_hire_merc(pid: int, merc_id: String, cost: int) -> void:
	if not ResourceManager.can_afford(pid, {"gold": cost}):
		EventBus.message_log.emit("[color=red]金币不足 (需要%d金)[/color]" % cost); return
	ResourceManager.spend(pid, {"gold": cost})
	# Add soldiers from mercenary
	for merc in PirateMechanic.MERCENARY_TYPES:
		if merc["id"] == merc_id:
			ResourceManager.add(pid, {"soldiers": merc["count"]})
			EventBus.message_log.emit("雇佣了 %s x%d (-%d金)" % [merc["name"], merc["count"], cost])
			break
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
