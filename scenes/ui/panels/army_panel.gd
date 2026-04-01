## army_panel.gd - SR07-style centralized Army Management Panel
## Shows all armies at a glance with commanders, troops, location, and status.
## Pure GDScript UI (no .tscn). Uses ColorTheme for all styling.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Status colors ──
const STATUS_IDLE := Color(0.4, 0.9, 0.4)
const STATUS_MARCHING := Color(0.4, 0.7, 1.0)
const STATUS_GARRISONED := Color(1.0, 0.85, 0.3)
const STATUS_COMBAT := Color(1.0, 0.3, 0.3)

# ── State ──
var _visible: bool = false
var _selected_army_id: int = -1

# ── UI refs: root ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer

# ── UI refs: header ──
var header_label: Label
var btn_close: Button

# ── UI refs: summary bar ──
var summary_container: HBoxContainer
var lbl_total_armies: Label
var lbl_total_troops: Label
var lbl_total_upkeep: Label
var lbl_avg_morale: Label

# ── UI refs: army list (left) ──
var list_scroll: ScrollContainer
var list_container: VBoxContainer
var _army_cards: Array = []

# ── UI refs: detail panel (right) ──
var detail_panel: PanelContainer
var detail_scroll: ScrollContainer
var detail_container: VBoxContainer

# ── UI refs: detail action buttons ──
var btn_deploy: Button
var btn_merge: Button
var btn_split: Button
var btn_dismiss: Button


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_INFO_PANELS
	_build_ui()
	_connect_signals()
	hide_panel()


func _connect_signals() -> void:
	EventBus.army_created.connect(_on_army_changed)
	EventBus.army_disbanded.connect(_on_army_changed)
	EventBus.army_changed.connect(_on_army_count_changed)
	EventBus.army_march_started.connect(_on_march_changed)
	EventBus.army_march_arrived.connect(_on_march_arrived)
	EventBus.army_march_cancelled.connect(_on_march_cancelled)


func _on_army_changed(_pid: int, _aid: int, _extra = null) -> void:
	if _visible:
		_refresh_all()


func _on_army_count_changed(_pid: int, _count: int) -> void:
	if _visible:
		_refresh_all()


func _on_march_changed(_aid: int, _path = null) -> void:
	if _visible:
		_refresh_all()


func _on_march_arrived(_aid: int, _tile: int) -> void:
	if _visible:
		_refresh_all()


func _on_march_cancelled(_aid: int) -> void:
	if _visible:
		_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.game_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and _visible:
			hide_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_A and _visible and not event.ctrl_pressed and not event.alt_pressed:
			# Allow toggling off via 'A' when panel is open
			hide_panel()
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "ArmyPanelRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dim background
	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = ColorTheme.BG_OVERLAY
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	# Main panel - centered, large
	main_panel = PanelContainer.new()
	main_panel.anchor_right = 1.0
	main_panel.anchor_bottom = 1.0
	main_panel.offset_left = 30
	main_panel.offset_right = -30
	main_panel.offset_top = 30
	main_panel.offset_bottom = -30
	var panel_style: StyleBoxFlat
	if UITheme and UITheme.has_method("make_content_style") and UITheme.frame_content:
		main_panel.add_theme_stylebox_override("panel", UITheme.make_content_style())
	else:
		panel_style = StyleBoxFlat.new()
		panel_style.bg_color = ColorTheme.BG_SECONDARY
		panel_style.border_color = ColorTheme.BORDER_DEFAULT
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(10)
		panel_style.set_content_margin_all(12)
		main_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(main_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	main_panel.add_child(outer_vbox)

	# ── Header row ──
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header_row)

	header_label = Label.new()
	header_label.text = "Army Management"
	header_label.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING + 2)
	header_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)

	btn_close = Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	# ── Summary bar ──
	_build_summary_bar(outer_vbox)

	# ── Separator ──
	var sep := HSeparator.new()
	outer_vbox.add_child(sep)

	# ── Content: left list + right detail ──
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 10)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_hbox)

	# Left: scrollable army list
	_build_army_list(content_hbox)

	# Right: detail panel
	_build_detail_panel(content_hbox)


func _build_summary_bar(parent: VBoxContainer) -> void:
	summary_container = HBoxContainer.new()
	summary_container.add_theme_constant_override("separation", 24)
	parent.add_child(summary_container)

	var summary_style := ColorTheme.make_panel_style(ColorTheme.BG_DARK, ColorTheme.BORDER_DIM, 1, 4, 6)

	var summary_bg := PanelContainer.new()
	summary_bg.add_theme_stylebox_override("panel", summary_style)
	summary_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_container.get_parent().remove_child(summary_container)
	summary_bg.add_child(summary_container)
	parent.add_child(summary_bg)

	lbl_total_armies = ColorTheme.make_label("Armies: 0/0", ColorTheme.FONT_BODY, ColorTheme.TEXT_NORMAL)
	summary_container.add_child(lbl_total_armies)

	lbl_total_troops = ColorTheme.make_label("Total Troops: 0", ColorTheme.FONT_BODY, ColorTheme.TEXT_NORMAL)
	summary_container.add_child(lbl_total_troops)

	lbl_total_upkeep = ColorTheme.make_label("Upkeep: 0 food", ColorTheme.FONT_BODY, ColorTheme.RES_FOOD)
	summary_container.add_child(lbl_total_upkeep)

	lbl_avg_morale = ColorTheme.make_label("Avg Morale: --", ColorTheme.FONT_BODY, ColorTheme.TEXT_DIM)
	summary_container.add_child(lbl_avg_morale)


func _build_army_list(parent: HBoxContainer) -> void:
	var list_wrapper := VBoxContainer.new()
	list_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_wrapper.size_flags_stretch_ratio = 0.45
	list_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(list_wrapper)

	var list_title := ColorTheme.make_label("Your Armies", ColorTheme.FONT_SUBHEADING, ColorTheme.TEXT_HEADING)
	list_wrapper.add_child(list_title)

	list_scroll = ScrollContainer.new()
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_wrapper.add_child(list_scroll)

	list_container = VBoxContainer.new()
	list_container.add_theme_constant_override("separation", 4)
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_container)


func _build_detail_panel(parent: HBoxContainer) -> void:
	detail_panel = PanelContainer.new()
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.size_flags_stretch_ratio = 0.55
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var ds := StyleBoxFlat.new()
	ds.bg_color = ColorTheme.BG_SECONDARY
	ds.border_color = ColorTheme.BORDER_DEFAULT
	ds.set_border_width_all(1)
	ds.set_corner_radius_all(6)
	ds.set_content_margin_all(12)
	detail_panel.add_theme_stylebox_override("panel", ds)
	parent.add_child(detail_panel)

	detail_scroll = ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(detail_scroll)

	detail_container = VBoxContainer.new()
	detail_container.add_theme_constant_override("separation", 6)
	detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_container)


# ═══════════════════════════════════════════════════════════════
#                       PUBLIC API
# ═══════════════════════════════════════════════════════════════

func show_panel() -> void:
	_visible = true
	root.visible = true
	ColorTheme.animate_panel_open(main_panel)
	_selected_army_id = -1
	_refresh_all()


func hide_panel() -> void:
	if AudioManager and AudioManager.has_method("play_ui_cancel"):
		AudioManager.play_ui_cancel()
	_visible = false
	root.visible = false
	_selected_army_id = -1


# ═══════════════════════════════════════════════════════════════
#                     REFRESH / DATA
# ═══════════════════════════════════════════════════════════════

func _refresh_all() -> void:
	_refresh_summary()
	_refresh_army_list()
	_refresh_detail()


func _get_player_armies() -> Array:
	var pid: int = GameManager.get_human_player_id()
	return GameManager.get_player_armies(pid)


func _get_army_status(army_id: int) -> String:
	# Check march system first
	if MarchSystem and MarchSystem.march_orders.has(army_id):
		var order: Dictionary = MarchSystem.march_orders[army_id]
		if order.get("state", "") == "marching":
			return "marching"
	# Check if tile has garrison building or is a fortress
	var army: Dictionary = GameManager.get_army(army_id)
	if army.is_empty():
		return "idle"
	var tile_idx: int = army.get("tile_index", -1)
	if tile_idx >= 0 and tile_idx < GameManager.tiles.size():
		var tile: Dictionary = GameManager.tiles[tile_idx]
		var tile_type: int = tile.get("type", -1)
		if tile_type in [GameManager.TileType.LIGHT_STRONGHOLD, GameManager.TileType.CORE_FORTRESS, GameManager.TileType.DARK_BASE, GameManager.TileType.CHOKEPOINT]:
			return "garrisoned"
	return "idle"


func _get_status_color(status: String) -> Color:
	match status:
		"idle": return STATUS_IDLE
		"marching": return STATUS_MARCHING
		"garrisoned": return STATUS_GARRISONED
		"in_combat": return STATUS_COMBAT
	return ColorTheme.TEXT_NORMAL


func _get_commander_name(army: Dictionary) -> String:
	var heroes: Array = army.get("heroes", [])
	if heroes.is_empty():
		return "(No Commander)"
	var hero_id: String = heroes[0]
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	return hero_data.get("name", hero_id)


func _get_commander_stats(army: Dictionary) -> Dictionary:
	var heroes: Array = army.get("heroes", [])
	if heroes.is_empty():
		return {}
	var hero_id: String = heroes[0]
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	return hero_data


# ═══════════════════════════════════════════════════════════════
#                     SUMMARY BAR
# ═══════════════════════════════════════════════════════════════

func _refresh_summary() -> void:
	var pid: int = GameManager.get_human_player_id()
	var player_armies: Array = _get_player_armies()
	var max_armies: int = GameManager.get_max_armies(pid)
	var total_troops: int = 0
	var total_upkeep: int = 0

	for army in player_armies:
		var army_id: int = army["id"]
		total_troops += GameManager.get_army_soldier_count(army_id)
		var troops: Array = army.get("troops", [])
		if GameData and GameData.has_method("get_army_upkeep"):
			total_upkeep += GameData.get_army_upkeep(troops)

	lbl_total_armies.text = "Armies: %d/%d" % [player_armies.size(), max_armies]
	lbl_total_troops.text = "Total Troops: %d" % total_troops
	lbl_total_upkeep.text = "Upkeep: %d food" % total_upkeep
	lbl_avg_morale.text = "Avg Morale: --"


# ═══════════════════════════════════════════════════════════════
#                     ARMY LIST (LEFT)
# ═══════════════════════════════════════════════════════════════

func _refresh_army_list() -> void:
	# Clear existing cards
	for child in list_container.get_children():
		child.queue_free()
	_army_cards.clear()

	var player_armies: Array = _get_player_armies()
	if player_armies.is_empty():
		var empty_lbl := ColorTheme.make_label("(No armies deployed)", ColorTheme.FONT_BODY, ColorTheme.TEXT_MUTED)
		list_container.add_child(empty_lbl)
		return

	for army in player_armies:
		var card := _create_army_card(army)
		list_container.add_child(card)
		_army_cards.append(card)


func _create_army_card(army: Dictionary) -> PanelContainer:
	var army_id: int = army["id"]
	var status: String = _get_army_status(army_id)
	var status_color: Color = _get_status_color(status)
	var is_selected: bool = (army_id == _selected_army_id)

	# Card container
	var card := PanelContainer.new()
	var card_border_color: Color = ColorTheme.BORDER_HIGHLIGHT if is_selected else status_color.darkened(0.4)
	var card_bg: Color = ColorTheme.BG_CARD.lightened(0.05) if is_selected else ColorTheme.BG_CARD
	var card_style := ColorTheme.make_panel_style(card_bg, card_border_color, 2 if is_selected else 1, 6, 8)
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(0, 70)
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Make card clickable
	card.gui_input.connect(_on_card_input.bind(army_id))

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(hbox)

	# Portrait placeholder (colored rect)
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(50, 50)
	portrait.color = status_color.darkened(0.3)
	portrait.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(portrait)

	# Portrait label (first letter of commander)
	var commander_name: String = _get_commander_name(army)
	var portrait_label := Label.new()
	portrait_label.text = commander_name.left(1).to_upper() if commander_name != "(No Commander)" else "?"
	portrait_label.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING)
	portrait_label.add_theme_color_override("font_color", ColorTheme.TEXT_WHITE)
	portrait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_label.anchor_right = 1.0
	portrait_label.anchor_bottom = 1.0
	portrait_label.mouse_filter = Control.MOUSE_FILTER_PASS
	portrait.add_child(portrait_label)

	# Info vbox
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(info_vbox)

	# Army name row
	var name_label := ColorTheme.make_label(army.get("name", "Army %d" % army_id), ColorTheme.FONT_BODY, ColorTheme.TEXT_GOLD)
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	info_vbox.add_child(name_label)

	# Commander
	var cmd_label := ColorTheme.make_label("Cmd: %s" % commander_name, ColorTheme.FONT_SMALL, ColorTheme.TEXT_DIM)
	cmd_label.mouse_filter = Control.MOUSE_FILTER_PASS
	info_vbox.add_child(cmd_label)

	# Location + troops row
	var tile_idx: int = army.get("tile_index", -1)
	var tile_name: String = "???"
	if tile_idx >= 0 and tile_idx < GameManager.tiles.size():
		tile_name = GameManager.tiles[tile_idx].get("name", "???")
	var soldier_count: int = GameManager.get_army_soldier_count(army_id)
	var loc_label := ColorTheme.make_label("@ %s  |  Troops: %d" % [tile_name, soldier_count], ColorTheme.FONT_SMALL, ColorTheme.TEXT_NORMAL)
	loc_label.mouse_filter = Control.MOUSE_FILTER_PASS
	info_vbox.add_child(loc_label)

	# Status indicator (right side)
	var status_label := ColorTheme.make_label(status.capitalize(), ColorTheme.FONT_SMALL, status_color)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(status_label)

	return card


func _on_card_input(event: InputEvent, army_id: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_card_clicked(army_id)


# ═══════════════════════════════════════════════════════════════
#                     DETAIL PANEL (RIGHT)
# ═══════════════════════════════════════════════════════════════

func _refresh_detail() -> void:
	# Clear existing detail content
	for child in detail_container.get_children():
		child.queue_free()

	if _selected_army_id < 0:
		var hint := ColorTheme.make_label("Select an army to view details", ColorTheme.FONT_BODY, ColorTheme.TEXT_MUTED)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		detail_container.add_child(hint)
		return

	var army: Dictionary = GameManager.get_army(_selected_army_id)
	if army.is_empty():
		_selected_army_id = -1
		var hint := ColorTheme.make_label("Army no longer exists", ColorTheme.FONT_BODY, ColorTheme.TEXT_WARNING)
		detail_container.add_child(hint)
		return

	var army_id: int = army["id"]
	var status: String = _get_army_status(army_id)
	var status_color: Color = _get_status_color(status)

	# ── Army Title ──
	var title := ColorTheme.make_label(army.get("name", "Army"), ColorTheme.FONT_HEADING, ColorTheme.TEXT_GOLD)
	detail_container.add_child(title)

	# Status
	var status_lbl := ColorTheme.make_label("Status: %s" % status.capitalize(), ColorTheme.FONT_BODY, status_color)
	detail_container.add_child(status_lbl)

	# Location
	var tile_idx: int = army.get("tile_index", -1)
	var tile_name: String = "???"
	if tile_idx >= 0 and tile_idx < GameManager.tiles.size():
		tile_name = GameManager.tiles[tile_idx].get("name", "???")
	var loc_lbl := ColorTheme.make_label("Location: %s (tile %d)" % [tile_name, tile_idx], ColorTheme.FONT_BODY, ColorTheme.TEXT_NORMAL)
	detail_container.add_child(loc_lbl)

	# March info if marching
	if MarchSystem and MarchSystem.march_orders.has(army_id):
		var order: Dictionary = MarchSystem.march_orders[army_id]
		if order.get("state", "") == "marching":
			var target_tile: int = order.get("target_tile", -1)
			var dest_name: String = "???"
			if target_tile >= 0 and target_tile < GameManager.tiles.size():
				dest_name = GameManager.tiles[target_tile].get("name", "???")
			var step: int = order.get("current_step", 0)
			var total_steps: int = order.get("path", []).size()
			var supply: float = order.get("supply", 100.0)
			var march_lbl := ColorTheme.make_label("Marching to: %s (%d/%d steps)" % [dest_name, step, total_steps], ColorTheme.FONT_BODY, STATUS_MARCHING)
			detail_container.add_child(march_lbl)
			# Supply bar
			_add_bar(detail_container, "Supply", supply, 100.0, _get_supply_color(supply))

	# Combat power
	var power: int = GameManager.get_army_combat_power(army_id)
	var power_lbl := ColorTheme.make_label("Combat Power: %d" % power, ColorTheme.FONT_BODY, ColorTheme.ACCENT_GOLD)
	detail_container.add_child(power_lbl)

	# ── Separator ──
	detail_container.add_child(HSeparator.new())

	# ── Commander Stats ──
	var heroes: Array = army.get("heroes", [])
	var cmd_header := ColorTheme.make_heading_label("Commander")
	detail_container.add_child(cmd_header)

	if heroes.is_empty():
		var no_cmd := ColorTheme.make_label("(No commander assigned)", ColorTheme.FONT_BODY, ColorTheme.TEXT_MUTED)
		detail_container.add_child(no_cmd)
	else:
		for hero_id in heroes:
			var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
			var hname: String = hero_data.get("name", hero_id)
			var cmd_lbl := ColorTheme.make_label(hname, ColorTheme.FONT_BODY, ColorTheme.TEXT_TITLE)
			detail_container.add_child(cmd_lbl)

			# Show key stats
			var stats_text: String = ""
			for stat_key in ["atk", "def", "int", "leadership"]:
				var val = hero_data.get(stat_key, 0)
				if val > 0:
					stats_text += "%s:%d  " % [stat_key.to_upper(), val]
			if not stats_text.is_empty():
				var stats_lbl := ColorTheme.make_label(stats_text.strip_edges(), ColorTheme.FONT_SMALL, ColorTheme.TEXT_DIM)
				detail_container.add_child(stats_lbl)

	# ── Separator ──
	detail_container.add_child(HSeparator.new())

	# ── Troop Breakdown ──
	var troop_header := ColorTheme.make_heading_label("Troop Breakdown")
	detail_container.add_child(troop_header)

	var troops: Array = army.get("troops", [])
	if troops.is_empty():
		var no_troops := ColorTheme.make_label("(No troops)", ColorTheme.FONT_BODY, ColorTheme.TEXT_MUTED)
		detail_container.add_child(no_troops)
	else:
		# Group by troop type
		var type_counts: Dictionary = {}  # troop_id -> {soldiers, name, tier, category}
		for troop in troops:
			var troop_id: String = troop.get("troop_id", "unknown")
			var soldiers: int = troop.get("soldiers", 0)
			if type_counts.has(troop_id):
				type_counts[troop_id]["soldiers"] += soldiers
				type_counts[troop_id]["stacks"] += 1
			else:
				var td: Dictionary = {}
				if GameData and GameData.has_method("get_troop_def"):
					td = GameData.get_troop_def(troop_id)
				type_counts[troop_id] = {
					"soldiers": soldiers,
					"stacks": 1,
					"name": td.get("name", troop_id),
					"tier": td.get("tier", 1),
					"category": td.get("category", "infantry"),
				}

		for troop_id in type_counts:
			var info: Dictionary = type_counts[troop_id]
			var cat_icon: String = _get_category_icon(info.get("category", "infantry"))
			var line_text: String = "%s %s (T%d) x%d  [%d soldiers]" % [
				cat_icon, info["name"], info["tier"], info["stacks"], info["soldiers"]]
			var tier_color: Color = _get_tier_color(info["tier"])
			var troop_lbl := ColorTheme.make_label(line_text, ColorTheme.FONT_SMALL, tier_color)
			detail_container.add_child(troop_lbl)

	# Total soldiers
	var total_soldiers: int = GameManager.get_army_soldier_count(army_id)
	var total_lbl := ColorTheme.make_label("Total: %d soldiers" % total_soldiers, ColorTheme.FONT_BODY, ColorTheme.TEXT_NORMAL)
	detail_container.add_child(total_lbl)

	# ── Separator ──
	detail_container.add_child(HSeparator.new())

	# ── Morale Bar (placeholder - no direct morale per army in data) ──
	_add_bar(detail_container, "Morale", 75.0, 100.0, ColorTheme.HP_HIGH)

	# ── Separator ──
	detail_container.add_child(HSeparator.new())

	# ── Action Buttons ──
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	detail_container.add_child(btn_row)

	btn_deploy = _make_action_button("Deploy", "default")
	btn_deploy.pressed.connect(_on_deploy_pressed)
	btn_row.add_child(btn_deploy)

	btn_merge = _make_action_button("Merge", "default")
	btn_merge.pressed.connect(_on_merge_pressed)
	btn_row.add_child(btn_merge)

	btn_split = _make_action_button("Split", "default")
	btn_split.pressed.connect(_on_split_pressed)
	btn_row.add_child(btn_split)

	btn_dismiss = _make_action_button("Dismiss", "danger")
	btn_dismiss.pressed.connect(_on_dismiss_pressed)
	btn_row.add_child(btn_dismiss)

	# Disable merge if no other army on same tile
	var can_merge: bool = false
	for other_army in _get_player_armies():
		if other_army["id"] != army_id and other_army.get("tile_index", -1) == tile_idx:
			can_merge = true
			break
	btn_merge.disabled = not can_merge

	# Disable split if fewer than 2 troop stacks
	btn_split.disabled = troops.size() < 2


func _add_bar(parent: VBoxContainer, label_text: String, value: float, max_value: float, bar_color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)

	var lbl := ColorTheme.make_label("%s:" % label_text, ColorTheme.FONT_SMALL, ColorTheme.TEXT_DIM)
	lbl.custom_minimum_size.x = 60
	row.add_child(lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(180, 16)
	bar.max_value = max_value
	bar.value = value
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Style the bar
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	bg_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = bar_color
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)
	row.add_child(bar)

	var val_lbl := ColorTheme.make_label("%.0f/%.0f" % [value, max_value], ColorTheme.FONT_SMALL, ColorTheme.TEXT_NORMAL)
	row.add_child(val_lbl)


func _make_action_button(text: String, style_type: String = "default") -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(80, 32)
	btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	var styles: Dictionary
	match style_type:
		"danger":
			styles = ColorTheme.make_button_style_danger()
		"confirm":
			styles = ColorTheme.make_button_style_confirm()
		_:
			styles = ColorTheme.make_button_style_textured()
	if styles.has("normal"):
		btn.add_theme_stylebox_override("normal", styles["normal"])
	if styles.has("hover"):
		btn.add_theme_stylebox_override("hover", styles["hover"])
	if styles.has("pressed"):
		btn.add_theme_stylebox_override("pressed", styles["pressed"])
	btn.add_theme_color_override("font_color", ColorTheme.BTN_TEXT)
	ColorTheme.setup_button_hover(btn)
	return btn


func _get_supply_color(supply: float) -> Color:
	if supply > 60.0:
		return ColorTheme.MARCH_SUPPLY_HIGH
	elif supply > 30.0:
		return ColorTheme.MARCH_SUPPLY_MID
	return ColorTheme.MARCH_SUPPLY_LOW


func _get_category_icon(category: String) -> String:
	match category:
		"infantry": return "[INF]"
		"cavalry": return "[CAV]"
		"archer", "ranged": return "[ARC]"
		"siege": return "[SIG]"
		"monster": return "[MON]"
		"magic": return "[MAG]"
	return "[---]"


func _get_tier_color(tier: int) -> Color:
	match tier:
		1: return ColorTheme.TEXT_NORMAL
		2: return ColorTheme.TEXT_SUCCESS
		3: return ColorTheme.ACCENT_GOLD
		4: return ColorTheme.RES_CRYSTAL
	return ColorTheme.TEXT_DIM


# ═══════════════════════════════════════════════════════════════
#                     ACTION HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_deploy_pressed() -> void:
	if _selected_army_id < 0:
		return
	hide_panel()
	EventBus.message_log.emit("[color=cyan]Select a target tile to deploy the army.[/color]")
	EventBus.army_selected.emit(_selected_army_id)


func _on_merge_pressed() -> void:
	if _selected_army_id < 0:
		return
	var army: Dictionary = GameManager.get_army(_selected_army_id)
	if army.is_empty():
		return
	var tile_idx: int = army.get("tile_index", -1)
	var pid: int = army.get("player_id", -1)
	# Find another army on the same tile
	for other_army in _get_player_armies():
		if other_army["id"] != _selected_army_id and other_army.get("tile_index", -1) == tile_idx:
			GameManager.action_merge_armies(_selected_army_id, other_army["id"])
			_refresh_all()
			return
	EventBus.message_log.emit("[color=yellow]No other army on the same tile to merge with.[/color]")


func _on_split_pressed() -> void:
	if _selected_army_id < 0:
		return
	GameManager.action_split_army(_selected_army_id)
	_refresh_all()


func _on_dismiss_pressed() -> void:
	if _selected_army_id < 0:
		return
	GameManager.disband_army(_selected_army_id)
	_selected_army_id = -1
	_refresh_all()


func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()


func _on_card_clicked(army_id: int) -> void:
	_selected_army_id = army_id
	_refresh_army_list()
	_refresh_detail()
