## tile_development_panel.gd - Tile Development Path UI Panel for 暗潮 SLG
## Lets players choose development paths and build path-specific buildings on owned tiles.
extends CanvasLayer

# ── State ──
var _visible: bool = false
var _tile_idx: int = -1

# ── Path colors ──
const COLOR_MILITARY := Color(0.85, 0.2, 0.2)
const COLOR_ECONOMIC := Color(0.9, 0.75, 0.15)
const COLOR_CULTURAL := Color(0.3, 0.5, 0.95)
const COLOR_DIM_BG := Color(0, 0, 0, 0.55)

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var content_scroll: ScrollContainer
var content_vbox: VBoxContainer
# Confirmation dialog
var confirm_overlay: Control
var confirm_label: Label
var _pending_path: int = -1

# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 8
	_build_ui()
	_connect_signals()
	hide_panel()


func _connect_signals() -> void:
	EventBus.tile_path_chosen.connect(_on_tile_path_chosen)
	EventBus.tile_building_built.connect(_on_tile_building_built)
	EventBus.resources_changed.connect(_on_resources_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _visible:
		hide_panel()
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "TileDevRoot"
	root.anchor_right = 1.0; root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dim background
	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0; dim_bg.anchor_bottom = 1.0
	dim_bg.color = COLOR_DIM_BG
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	# Main panel (~70% width, ~80% height, centered)
	main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.15; main_panel.anchor_right = 0.85
	main_panel.anchor_top = 0.1; main_panel.anchor_bottom = 0.9
	var style := StyleBoxFlat.new()
	style.bg_color = ColorTheme.BG_SECONDARY
	style.border_color = ColorTheme.BORDER_DEFAULT
	style.set_border_width_all(2); style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	main_panel.add_theme_stylebox_override("panel", style)
	root.add_child(main_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	main_panel.add_child(outer_vbox)

	# Header
	var header_row := HBoxContainer.new()
	outer_vbox.add_child(header_row)
	header_label = Label.new()
	header_label.text = "Tile Development"
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)
	btn_close = Button.new()
	btn_close.text = "X"; btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	# Scrollable content area
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(content_scroll)
	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 8)
	content_scroll.add_child(content_vbox)

	# Confirmation dialog (hidden by default)
	_build_confirm_dialog()


func _build_confirm_dialog() -> void:
	confirm_overlay = Control.new()
	confirm_overlay.anchor_right = 1.0; confirm_overlay.anchor_bottom = 1.0
	confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP; confirm_overlay.visible = false
	root.add_child(confirm_overlay)
	var overlay_bg := ColorRect.new()
	overlay_bg.anchor_right = 1.0; overlay_bg.anchor_bottom = 1.0
	overlay_bg.color = Color(0, 0, 0, 0.6); overlay_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm_overlay.add_child(overlay_bg)
	var dialog := PanelContainer.new()
	dialog.anchor_left = 0.3; dialog.anchor_right = 0.7
	dialog.anchor_top = 0.35; dialog.anchor_bottom = 0.65
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.08, 0.06, 0.14, 0.98); ds.border_color = Color(0.8, 0.3, 0.2)
	ds.set_border_width_all(2); ds.set_corner_radius_all(8); ds.set_content_margin_all(16)
	dialog.add_theme_stylebox_override("panel", ds)
	confirm_overlay.add_child(dialog)
	var dvbox := VBoxContainer.new()
	dvbox.add_theme_constant_override("separation", 12)
	dvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dialog.add_child(dvbox)
	dvbox.add_child(_lbl("WARNING", 18, Color(1.0, 0.3, 0.2), false, HORIZONTAL_ALIGNMENT_CENTER))
	confirm_label = _lbl("", 14, Color(0.9, 0.85, 0.7), true, HORIZONTAL_ALIGNMENT_CENTER)
	dvbox.add_child(confirm_label)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	dvbox.add_child(btn_row)

	var btn_yes := Button.new()
	btn_yes.text = "Confirm"; btn_yes.custom_minimum_size = Vector2(120, 36)
	btn_yes.add_theme_font_size_override("font_size", 14)
	btn_yes.pressed.connect(_on_confirm_yes)
	btn_row.add_child(btn_yes)

	var btn_no := Button.new()
	btn_no.text = "Cancel"; btn_no.custom_minimum_size = Vector2(120, 36)
	btn_no.add_theme_font_size_override("font_size", 14)
	btn_no.pressed.connect(_on_confirm_no)
	btn_row.add_child(btn_no)


# ═══════════════════════════════════════════════════════════════
#                     SHOW / HIDE / REFRESH
# ═══════════════════════════════════════════════════════════════

func show_panel(tile_idx: int) -> void:
	_tile_idx = tile_idx
	_visible = true
	root.visible = true
	_refresh()


func hide_panel() -> void:
	_visible = false
	root.visible = false
	confirm_overlay.visible = false
	_pending_path = -1


func _refresh() -> void:
	if _tile_idx < 0:
		return
	_clear_content()
	var dev: Dictionary = TileDevelopment.get_tile_development(_tile_idx)
	var tile_name: String = ""
	if _tile_idx < GameManager.tiles.size():
		tile_name = GameManager.tiles[_tile_idx].get("name", "Tile %d" % _tile_idx)
	header_label.text = "Development - %s" % tile_name

	if dev["committed"]:
		_build_building_phase(dev)
	else:
		_build_path_selection_phase()


func _clear_content() -> void:
	for c in content_vbox.get_children():
		c.queue_free()


# ═══════════════════════════════════════════════════════════════
#             PHASE 1: PATH SELECTION (three cards)
# ═══════════════════════════════════════════════════════════════

func _build_path_selection_phase() -> void:
	content_vbox.add_child(_lbl("Choose a development path for this tile. This decision is permanent!", 13, Color(0.8, 0.7, 0.5), true, HORIZONTAL_ALIGNMENT_CENTER))

	# Cards container
	var cards_hbox := HBoxContainer.new()
	cards_hbox.add_theme_constant_override("separation", 10)
	cards_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(cards_hbox)

	var paths := [
		TileDevelopment.DevPath.MILITARY,
		TileDevelopment.DevPath.ECONOMIC,
		TileDevelopment.DevPath.CULTURAL,
	]
	for path in paths:
		var card := _build_path_card(path)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards_hbox.add_child(card)


func _build_path_card(path: int) -> PanelContainer:
	var data: Dictionary = TileDevelopment.PATH_BONUSES[path]
	var accent: Color = _get_path_color(path)

	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.07, 0.06, 0.12, 0.95)
	cs.border_color = accent.darkened(0.3)
	cs.set_border_width_all(2); cs.set_corner_radius_all(8); cs.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", cs)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	vbox.add_child(_lbl("%s %s" % [_get_path_icon(path), data["name"]], 17, accent, false, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(_lbl(data["desc"], 11, Color(0.75, 0.7, 0.6), true, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(_make_separator(accent.darkened(0.5)))

	# Per-building bonuses
	vbox.add_child(_lbl("Per Building:", 11, Color(0.6, 0.8, 0.6)))
	for key in data["per_building"]:
		vbox.add_child(_lbl("  %s: +%s" % [_format_key(key), _format_val(data["per_building"][key])], 10, Color(0.7, 0.9, 0.7)))

	# Global penalties
	vbox.add_child(_make_separator(Color(0.4, 0.2, 0.2, 0.5)))
	vbox.add_child(_lbl("Penalties:", 11, Color(0.9, 0.5, 0.4)))
	for key in data["global_penalty"]:
		vbox.add_child(_lbl("  %s: x%s" % [_format_key(key), str(data["global_penalty"][key])], 10, Color(1.0, 0.6, 0.5)))

	# Tier unlocks
	vbox.add_child(_make_separator(accent.darkened(0.5)))
	vbox.add_child(_lbl("Tier Unlocks:", 11, Color(0.6, 0.7, 0.9)))
	var tier_data: Dictionary = data["tier_unlocks"]
	for threshold in tier_data:
		vbox.add_child(_lbl("  %d buildings: %s" % [threshold, _format_key(tier_data[threshold])], 10, Color(0.65, 0.7, 0.85)))

	# Choose button
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	vbox.add_child(spacer)
	var btn := Button.new()
	btn.text = "Choose Path"
	btn.custom_minimum_size = Vector2(0, 34)
	btn.add_theme_font_size_override("font_size", 13)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = accent.darkened(0.5)
	btn_style.set_corner_radius_all(4); btn_style.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := StyleBoxFlat.new()
	btn_hover.bg_color = accent.darkened(0.3)
	btn_hover.set_corner_radius_all(4); btn_hover.set_content_margin_all(4)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.pressed.connect(_on_path_selected.bind(path))
	vbox.add_child(btn)

	return card


# ═══════════════════════════════════════════════════════════════
#        PHASE 2: BUILDING (after path committed)
# ═══════════════════════════════════════════════════════════════

func _build_building_phase(dev: Dictionary) -> void:
	var path: int = dev["path"]
	var accent: Color = _get_path_color(path)
	var path_data: Dictionary = TileDevelopment.PATH_BONUSES[path]
	var buildings_built: Array = dev["buildings"]
	var total_slots: int = TileDevelopment.SLOTS_PER_LEVEL[mini(
		TileDevelopment._get_tile_level(_tile_idx) - 1,
		TileDevelopment.SLOTS_PER_LEVEL.size() - 1)]
	var used_slots: int = buildings_built.size()

	content_vbox.add_child(_lbl("%s %s" % [_get_path_icon(path), path_data["name"]], 18, accent))

	# Slot display (RichTextLabel for colored squares)
	var slot_lbl := RichTextLabel.new()
	slot_lbl.bbcode_enabled = true
	var filled_tag := "[color=#%s]%s[/color]" % [accent.to_html(false), "■"]
	var empty_tag := "[color=#555555]□[/color]"
	var bbtext: String = "Slots: "
	for i in total_slots:
		bbtext += filled_tag if i < used_slots else empty_tag
		if i < total_slots - 1: bbtext += " "
	bbtext += "  (%d/%d)" % [used_slots, total_slots]
	slot_lbl.text = bbtext
	slot_lbl.add_theme_font_size_override("normal_font_size", 14)
	slot_lbl.fit_content = true; slot_lbl.custom_minimum_size.y = 24; slot_lbl.scroll_active = false
	content_vbox.add_child(slot_lbl)
	content_vbox.add_child(_make_separator(accent.darkened(0.4)))

	content_vbox.add_child(_lbl("Available Buildings:", 14, Color(0.8, 0.8, 0.7)))
	var pid: int = GameManager.get_human_player_id()
	for bld in TileDevelopment.get_path_buildings_list(path):
		_build_building_row(bld, buildings_built, pid, accent)
	content_vbox.add_child(_make_separator(Color(0.3, 0.3, 0.4)))
	_build_effects_summary()


func _build_building_row(bld: Dictionary, built: Array, pid: int, accent: Color) -> void:
	var is_built: bool = bld["id"] in built
	var can_check: Dictionary = TileDevelopment.can_build(_tile_idx, bld["id"])
	var can_afford: bool = ResourceManager.can_afford(pid, {"gold": bld["cost_gold"], "iron": bld["cost_iron"]})

	var row := PanelContainer.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.08, 0.07, 0.13, 0.8) if not is_built else Color(0.06, 0.1, 0.06, 0.8)
	rs.set_corner_radius_all(4); rs.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", rs)
	content_vbox.add_child(row)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row.add_child(hbox)

	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	info_vbox.add_child(_lbl(bld["name"] + (" [BUILT]" if is_built else ""), 13, accent if not is_built else Color(0.5, 0.7, 0.5)))
	info_vbox.add_child(_lbl(bld["desc"], 10, Color(0.65, 0.65, 0.6), true))
	var cost_color: Color = Color(0.7, 0.7, 0.6) if can_afford else Color(1.0, 0.4, 0.3)
	info_vbox.add_child(_lbl("Cost: %d gold, %d iron" % [bld["cost_gold"], bld["cost_iron"]], 10, cost_color))

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(90, 32)
	btn.add_theme_font_size_override("font_size", 12)
	if is_built:
		btn.text = "Built"; btn.disabled = true
	elif not can_check["can"]:
		btn.text = can_check.get("reason", "N/A"); btn.disabled = true
	elif not can_afford:
		btn.text = "Insufficient"; btn.disabled = true
	else:
		btn.text = "Build"
		btn.pressed.connect(_on_build_pressed.bind(bld["id"]))
	hbox.add_child(btn)


func _build_effects_summary() -> void:
	var effects: Dictionary = TileDevelopment.get_tile_path_effects(_tile_idx)
	content_vbox.add_child(_lbl("Current Tile Effects:", 13, Color(0.7, 0.8, 0.9)))

	if effects.is_empty():
		content_vbox.add_child(_lbl("  (No effects yet)", 11, Color(0.5, 0.5, 0.5)))
		return
	for key in effects:
		var val = effects[key]
		var txt: String; var clr: Color
		if val is bool:
			txt = "  %s: Unlocked" % _format_key(key); clr = Color(0.5, 0.8, 1.0)
		elif val is float and val < 1.0:
			txt = "  %s: x%s" % [_format_key(key), str(snapped(val, 0.01))]; clr = Color(1.0, 0.6, 0.5)
		else:
			txt = "  %s: +%s" % [_format_key(key), str(snapped(val, 0.01) if val is float else val)]; clr = Color(0.6, 0.9, 0.6)
		content_vbox.add_child(_lbl(txt, 10, clr))


# ═══════════════════════════════════════════════════════════════
#                      CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_path_selected(path: int) -> void:
	_pending_path = path
	var pname: String = TileDevelopment.get_path_name(path)
	confirm_label.text = "Are you sure you want to choose [%s]?\nThis cannot be changed later!" % pname
	confirm_overlay.visible = true


func _on_confirm_yes() -> void:
	confirm_overlay.visible = false
	if _pending_path >= 0 and _tile_idx >= 0:
		TileDevelopment.choose_path(_tile_idx, _pending_path)
	_pending_path = -1


func _on_confirm_no() -> void:
	confirm_overlay.visible = false
	_pending_path = -1


func _on_build_pressed(building_id: String) -> void:
	if _tile_idx < 0:
		return
	var check: Dictionary = TileDevelopment.can_build(_tile_idx, building_id)
	if not check["can"]:
		return
	var pid: int = GameManager.get_human_player_id()
	if not ResourceManager.can_afford(pid, {"gold": check["cost_gold"], "iron": check["cost_iron"]}):
		return
	ResourceManager.spend(pid, {"gold": check["cost_gold"], "iron": check["cost_iron"]})
	TileDevelopment.build(_tile_idx, building_id)


func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()


func _on_tile_path_chosen(tile_idx: int, _path: int) -> void:
	if _visible and tile_idx == _tile_idx:
		_refresh()


func _on_tile_building_built(tile_idx: int, _building_id: String) -> void:
	if _visible and tile_idx == _tile_idx:
		_refresh()


func _on_resources_changed(_pid: int) -> void:
	if _visible:
		_refresh()


# ═══════════════════════════════════════════════════════════════
#                      HELPERS
# ═══════════════════════════════════════════════════════════════

func _lbl(text: String, sz: int, color: Color, wrap: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text; l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	if wrap: l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _get_path_color(path: int) -> Color:
	match path:
		TileDevelopment.DevPath.MILITARY: return COLOR_MILITARY
		TileDevelopment.DevPath.ECONOMIC: return COLOR_ECONOMIC
		TileDevelopment.DevPath.CULTURAL: return COLOR_CULTURAL
		_: return Color(0.5, 0.5, 0.5)

func _get_path_icon(path: int) -> String:
	match path:
		TileDevelopment.DevPath.MILITARY: return "[M]"
		TileDevelopment.DevPath.ECONOMIC: return "[E]"
		TileDevelopment.DevPath.CULTURAL: return "[C]"
		_: return "[?]"

func _make_separator(color: Color) -> HSeparator:
	var sep := HSeparator.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = color; ss.set_content_margin_all(0)
	ss.content_margin_top = 1; ss.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", ss)
	return sep

func _format_key(key: String) -> String:
	return key.replace("_", " ").capitalize()

func _format_val(val) -> String:
	if val is float:
		if val < 1.0: return "%d%%" % int(val * 100)
		return str(snapped(val, 0.01))
	return str(val)


## Returns a status string for the HUD button label
func get_tile_status_text(tile_idx: int) -> String:
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return "N/A"
	var dev: Dictionary = TileDevelopment.get_tile_development(tile_idx)
	if not dev["committed"]:
		return "Undeveloped"
	var path_name: String = TileDevelopment.get_path_name(dev["path"])
	var num_bld: int = dev["buildings"].size()
	return "%s Lv%d" % [path_name, num_bld]
