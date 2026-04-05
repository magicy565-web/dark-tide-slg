## intel_overlay.gd — Intelligence visualization overlay for the strategic map.
## Shows espionage data (scouted/sabotaged tiles, wounded heroes, intercepted orders),
## a rich tile tooltip on hover, and a collapsible intel summary side panel (KEY_I).
## Placed on CanvasLayer layer 4 so it sits above the board but below modal panels.
extends Control

# ═══════════════════════════════════════════════════════════════
#                       CONSTANTS
# ═══════════════════════════════════════════════════════════════

# Overlay colors
const SCOUT_TINT := Color(0.2, 0.45, 0.9, 0.35)
const SABOTAGE_TINT := Color(0.9, 0.15, 0.15, 0.3)
const WOUNDED_TINT := Color(0.9, 0.85, 0.2, 0.35)
const HEATMAP_GOOD := Color(0.2, 0.75, 0.3, 0.25)
const HEATMAP_BAD := Color(0.85, 0.15, 0.15, 0.25)

# Tooltip
const TOOLTIP_WIDTH := 280.0
const TOOLTIP_HEIGHT_MIN := 200.0
const TOOLTIP_OFFSET := Vector2(15.0, 10.0)
const TOOLTIP_DELAY := 0.3
const TOOLTIP_BG := Color(0.06, 0.06, 0.1, 0.92)
const TOOLTIP_BORDER := Color(0.5, 0.45, 0.3)

# Side panel
const SIDE_PANEL_WIDTH := 240.0
const SIDE_PANEL_BG := Color(0.06, 0.06, 0.1, 0.92)

# Tile size (board rendering cell — adjust if board uses different sizing)
const TILE_SIZE := Vector2(80.0, 80.0)

# ═══════════════════════════════════════════════════════════════
#                       STATE
# ═══════════════════════════════════════════════════════════════

# Sub-components
var _tooltip_card: PanelContainer = null
var _intel_side_panel: PanelContainer = null
var _overlay_rects: Dictionary = {}   # tile_idx -> { node: Control, type: String }
var _hovered_tile_idx: int = -1
var _tooltip_timer: float = 0.0
var _tooltip_visible: bool = false
var _camera: Camera3D = null
var _heatmap_enabled: bool = false
var _side_panel_open: bool = false
var _pulse_time: float = 0.0

# Cached references
var _espionage_system: Node = null
var _player_id: int = 0

# Tooltip label references (populated in _build_tooltip)
var _tt_header_label: Label = null
var _tt_header_stripe: ColorRect = null
var _tt_terrain_label: Label = null
var _tt_owner_label: Label = null
var _tt_garrison_label: Label = null
var _tt_building_label: Label = null
var _tt_production_label: Label = null
var _tt_order_label: Label = null
var _tt_supply_label: Label = null
var _tt_intel_section: VBoxContainer = null
var _tt_special_section: VBoxContainer = null
var _tt_vbox: VBoxContainer = null

# Side panel label references
var _sp_intel_label: Label = null
var _sp_intel_bar: ColorRect = null
var _sp_intel_bar_bg: ColorRect = null
var _sp_counter_label: Label = null
var _sp_counter_bar: ColorRect = null
var _sp_counter_bar_bg: ColorRect = null
var _sp_scouted_vbox: VBoxContainer = null
var _sp_sabotage_vbox: VBoxContainer = null
var _sp_intercept_vbox: VBoxContainer = null
var _sp_wounded_vbox: VBoxContainer = null
var _sp_scouted_header: Button = null
var _sp_sabotage_header: Button = null
var _sp_intercept_header: Button = null
var _sp_wounded_header: Button = null

# Overlay container (holds all tile overlay nodes)
var _overlay_container: Control = null
# Intercepted order floating cards
var _intercept_cards: Array = []

# ═══════════════════════════════════════════════════════════════
#                       LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_resolve_espionage_system()
	_build_overlay_container()
	_build_tooltip()
	_build_side_panel()
	_connect_signals()
	_refresh_overlay()


func _resolve_espionage_system() -> void:
	# Try common access patterns
	if Engine.has_singleton("EspionageSystem"):
		_espionage_system = Engine.get_singleton("EspionageSystem")
	elif has_node("/root/EspionageSystem"):
		_espionage_system = get_node_or_null("/root/EspionageSystem")
	elif has_node("/root/GameManager"):
		var _gm := get_node_or_null("/root/GameManager")
		if _gm and _gm.has_node("EspionageSystem"):
			_espionage_system = _gm.get_node_or_null("EspionageSystem")
	# Fallback: search parent tree
	if _espionage_system == null:
		var parent := get_parent()
		while parent:
			if parent.has_node("EspionageSystem"):
				_espionage_system = parent.get_node("EspionageSystem")
				break
			parent = parent.get_parent()


func _connect_signals() -> void:
	if not EventBus:
		return
	if EventBus.has_signal("territory_selected"):
		EventBus.territory_selected.connect(_on_territory_selected)
	if EventBus.has_signal("territory_deselected"):
		EventBus.territory_deselected.connect(_on_territory_deselected)
	if EventBus.has_signal("turn_started"):
		EventBus.turn_started.connect(_on_turn_started)
	if EventBus.has_signal("spy_operation_result"):
		EventBus.spy_operation_result.connect(_on_spy_operation_result)
	if EventBus.has_signal("intel_changed"):
		EventBus.intel_changed.connect(_on_intel_changed)
	if EventBus.has_signal("fog_updated"):
		EventBus.fog_updated.connect(_on_fog_updated)


func _process(delta: float) -> void:
	_pulse_time += delta
	_update_pulse_overlays(delta)
	_update_tooltip_timer(delta)


func _unhandled_input(event: InputEvent) -> void:
	# Toggle side panel with KEY_L
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			_toggle_side_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_H:
			_toggle_heatmap()
			get_viewport().set_input_as_handled()

	# Mouse hover for tooltip
	if event is InputEventMouseMotion:
		_handle_mouse_hover(event.position)


# ═══════════════════════════════════════════════════════════════
#             PART 1: INTEL MAP OVERLAY
# ═══════════════════════════════════════════════════════════════

func _build_overlay_container() -> void:
	_overlay_container = Control.new()
	_overlay_container.name = "OverlayContainer"
	_overlay_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay_container)


func _refresh_overlay() -> void:
	_clear_overlay()
	if _espionage_system == null:
		return
	_player_id = _get_current_player_id()
	_add_scouted_overlays()
	_add_sabotaged_overlays()
	_add_wounded_overlays()
	_add_intercepted_cards()
	if _heatmap_enabled:
		_apply_heatmap()


func _clear_overlay() -> void:
	for key in _overlay_rects:
		var entry: Dictionary = _overlay_rects[key]
		if is_instance_valid(entry.get("node")):
			entry["node"].queue_free()
	_overlay_rects.clear()
	for card in _intercept_cards:
		if is_instance_valid(card):
			card.queue_free()
	_intercept_cards.clear()


func _add_scouted_overlays() -> void:
	if _espionage_system == null:
		return
	var revealed: Array = _espionage_system._revealed_tiles.get(_player_id, [])
	for entry in revealed:
		var tile_idx: int = entry["tile"]
		var turns_left: int = entry["turns_left"]
		if turns_left <= 0:
			continue
		var screen_pos: Vector2 = _tile_to_screen_pos(tile_idx)
		# Opacity scales: 3 turns = 100%, 2 = 66%, 1 = 33%
		var alpha_ratio: float = clampf(float(turns_left) / float(EspionageSystem.SCOUT_REVEAL_DURATION), 0.0, 1.0)
		var overlay_node := _create_tile_overlay(screen_pos, SCOUT_TINT, alpha_ratio)
		# Eye icon with turn counter
		var icon_label := Label.new()
		icon_label.text = "👁 %d" % turns_left
		icon_label.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		icon_label.add_theme_color_override("font_color", ColorTheme.TEXT_WHITE)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.position = Vector2(0, 2)
		icon_label.size = TILE_SIZE
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_node.add_child(icon_label)
		_overlay_rects[tile_idx] = {"node": overlay_node, "type": "scout"}


func _add_sabotaged_overlays() -> void:
	if _espionage_system == null:
		return
	var sabotaged: Array = _espionage_system.get_sabotaged_tiles(_player_id)
	for entry in sabotaged:
		var tile_idx: int = entry["tile"]
		var turns_left: int = entry["turns_left"]
		var penalty: float = entry.get("production_penalty", 0.20)
		if turns_left <= 0:
			continue
		if _overlay_rects.has(tile_idx):
			# If already has scout overlay, skip sabotage visual to avoid clutter
			continue
		var screen_pos: Vector2 = _tile_to_screen_pos(tile_idx)
		var overlay_node := _create_tile_overlay(screen_pos, SABOTAGE_TINT, 1.0)
		overlay_node.set_meta("pulse", true)
		# Warning icon with duration and penalty
		var icon_label := Label.new()
		icon_label.text = "⚠ %d" % turns_left
		icon_label.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		icon_label.add_theme_color_override("font_color", ColorTheme.TEXT_RED)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.position = Vector2(0, 2)
		icon_label.size = TILE_SIZE
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_node.add_child(icon_label)
		# Penalty label
		var penalty_label := Label.new()
		penalty_label.text = "-%d%%" % int(penalty * 100.0)
		penalty_label.add_theme_font_size_override("font_size", ColorTheme.FONT_TINY)
		penalty_label.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)
		penalty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		penalty_label.position = Vector2(0, TILE_SIZE.y - 16)
		penalty_label.size = Vector2(TILE_SIZE.x, 14)
		penalty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_node.add_child(penalty_label)
		_overlay_rects[tile_idx] = {"node": overlay_node, "type": "sabotage"}


func _add_wounded_overlays() -> void:
	if _espionage_system == null:
		return
	var wounded: Array = _espionage_system.get_wounded_heroes(_player_id)
	# Build a mapping of hero_id -> stationed tile
	var hero_tiles: Dictionary = {}
	if HeroSystem:
		for hero_id in HeroSystem.recruited_heroes:
			var info: Dictionary = HeroSystem.get_hero_info(hero_id)
			if info.is_empty():
				continue
			var stationed_tile: int = info.get("stationed_tile", -1)
			if stationed_tile >= 0:
				hero_tiles[hero_id] = stationed_tile
	for entry in wounded:
		var hero_id: String = entry["hero_id"]
		if not hero_tiles.has(hero_id):
			continue
		var tile_idx: int = hero_tiles[hero_id]
		if _overlay_rects.has(tile_idx):
			continue
		var screen_pos: Vector2 = _tile_to_screen_pos(tile_idx)
		var overlay_node := _create_tile_overlay(screen_pos, WOUNDED_TINT, 0.8)
		var icon_label := Label.new()
		icon_label.text = "✚"
		icon_label.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
		icon_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.2))
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.position = Vector2(0, TILE_SIZE.y * 0.3)
		icon_label.size = Vector2(TILE_SIZE.x, 20)
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay_node.add_child(icon_label)
		_overlay_rects[tile_idx] = {"node": overlay_node, "type": "wounded"}


func _add_intercepted_cards() -> void:
	if _espionage_system == null:
		return
	var intercepted: Array = _espionage_system._intercepted_orders.get(_player_id, [])
	for entry in intercepted:
		if entry["turns_left"] <= 0:
			continue
		var target_id: int = entry["target_id"]
		var moves: Array = entry.get("moves", [])
		var card := _create_intercept_card(target_id, moves)
		_overlay_container.add_child(card)
		_intercept_cards.append(card)


func _create_intercept_card(faction_id: int, moves: Array) -> PanelContainer:
	var card := PanelContainer.new()
	var style := ColorTheme.make_panel_style(
		Color(0.08, 0.06, 0.12, 0.9),
		ColorTheme.BORDER_HIGHLIGHT, 1, 4, 6
	)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)
	# Faction header
	var faction_name: String = _get_faction_name(faction_id)
	var faction_color: Color = _get_faction_color_by_id(faction_id)
	var header := Label.new()
	header.text = "截获: %s" % faction_name
	header.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	header.add_theme_color_override("font_color", faction_color)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)
	# Moves preview
	if moves.is_empty():
		var no_info := Label.new()
		no_info.text = "  下回合行动计划已获取"
		no_info.add_theme_font_size_override("font_size", ColorTheme.FONT_TINY)
		no_info.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
		no_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(no_info)
	else:
		for move_text in moves:
			var ml := Label.new()
			ml.text = "  • %s" % str(move_text)
			ml.add_theme_font_size_override("font_size", ColorTheme.FONT_TINY)
			ml.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
			ml.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(ml)
	# Position near the faction's territory — approximate using first owned tile
	var approx_pos := _get_faction_territory_center(faction_id)
	card.position = approx_pos + Vector2(TILE_SIZE.x + 4, -20)
	card.size = Vector2(160, 0)  # auto height
	return card


func _apply_heatmap() -> void:
	## Color gradient overlay based on proximity to player tiles.
	if not GameManager or not GameManager.get("tiles"):
		return
	var tiles: Array = GameManager.tiles
	var player_tiles: Array = []
	for i in tiles.size():
		if tiles[i] == null:
			continue
		if tiles[i].get("owner_id", -1) == _player_id:
			player_tiles.append(i)
	if player_tiles.is_empty():
		continue
	for i in tiles.size():
		if tiles[i] == null:
			continue
		if _overlay_rects.has(i):
			continue  # don't overwrite intel overlays
		var min_dist: float = _min_tile_distance(i, player_tiles)
		var max_range: float = 8.0
		var ratio: float = clampf(min_dist / max_range, 0.0, 1.0)
		var heat_color: Color = HEATMAP_GOOD.lerp(HEATMAP_BAD, ratio)
		var screen_pos: Vector2 = _tile_to_screen_pos(i)
		var overlay_node := _create_tile_overlay(screen_pos, heat_color, 1.0)
		_overlay_rects[i] = {"node": overlay_node, "type": "heatmap"}


func _update_pulse_overlays(_delta: float) -> void:
	## Pulsing animation for sabotaged tile overlays.
	var pulse_alpha: float = 0.3 + 0.2 * sin(_pulse_time * 3.0)
	for tile_idx in _overlay_rects:
		var entry: Dictionary = _overlay_rects[tile_idx]
		if entry["type"] == "sabotage" and is_instance_valid(entry["node"]):
			entry["node"].modulate.a = pulse_alpha


func _create_tile_overlay(screen_pos: Vector2, color: Color, alpha_ratio: float) -> Control:
	var container := Control.new()
	container.position = screen_pos
	container.size = TILE_SIZE
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rect := ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, color.a * alpha_ratio)
	rect.size = TILE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(rect)
	_overlay_container.add_child(container)
	return container


func _tile_to_screen_pos(tile_idx: int) -> Vector2:
	## Convert a tile index to its on-screen pixel position.
	## Tries GameManager.tile_positions, then falls back to grid math.
	if GameManager and GameManager.get("tile_positions") and tile_idx < GameManager.tile_positions.size():
		return GameManager.tile_positions[tile_idx]
	# Fallback: assume a grid layout
	var cols: int = 10
	if GameManager and GameManager.get("board_columns"):
		cols = GameManager.board_columns
	var row: int = tile_idx / cols
	var col: int = tile_idx % cols
	return Vector2(col * TILE_SIZE.x, row * TILE_SIZE.y)

# ═══════════════════════════════════════════════════════════════
#             PART 2: TILE TOOLTIP
# ═══════════════════════════════════════════════════════════════

func _build_tooltip() -> void:
	_tooltip_card = PanelContainer.new()
	_tooltip_card.name = "TileTooltip"
	var style := ColorTheme.make_panel_style(TOOLTIP_BG, TOOLTIP_BORDER, 1, 6, 10)
	_tooltip_card.add_theme_stylebox_override("panel", style)
	_tooltip_card.custom_minimum_size = Vector2(TOOLTIP_WIDTH, TOOLTIP_HEIGHT_MIN)
	_tooltip_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_card.visible = false
	_tooltip_card.z_index = 50

	_tt_vbox = VBoxContainer.new()
	_tt_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tt_vbox.add_theme_constant_override("separation", 2)
	_tooltip_card.add_child(_tt_vbox)

	# Header stripe (faction color bar at top)
	_tt_header_stripe = ColorRect.new()
	_tt_header_stripe.custom_minimum_size = Vector2(TOOLTIP_WIDTH - 20, 3)
	_tt_header_stripe.color = ColorTheme.ACCENT_GOLD
	_tt_header_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tt_vbox.add_child(_tt_header_stripe)

	# Header label (tile name + level)
	_tt_header_label = Label.new()
	_tt_header_label.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	_tt_header_label.add_theme_color_override("font_color", ColorTheme.TEXT_TITLE)
	_tt_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tt_vbox.add_child(_tt_header_label)

	# Terrain + move cost
	_tt_terrain_label = _make_tt_label()
	_tt_vbox.add_child(_tt_terrain_label)

	# Owner
	_tt_owner_label = _make_tt_label()
	_tt_vbox.add_child(_tt_owner_label)

	# Separator
	_tt_vbox.add_child(_make_tt_separator())

	# Garrison
	_tt_garrison_label = _make_tt_label()
	_tt_vbox.add_child(_tt_garrison_label)

	# Building
	_tt_building_label = _make_tt_label()
	_tt_vbox.add_child(_tt_building_label)

	# Production
	_tt_production_label = _make_tt_label()
	_tt_vbox.add_child(_tt_production_label)

	# Separator
	_tt_vbox.add_child(_make_tt_separator())

	# Public order
	_tt_order_label = _make_tt_label()
	_tt_vbox.add_child(_tt_order_label)

	# Supply
	_tt_supply_label = _make_tt_label()
	_tt_vbox.add_child(_tt_supply_label)

	# Separator
	_tt_vbox.add_child(_make_tt_separator())

	# Intel section (dynamic entries)
	_tt_intel_section = VBoxContainer.new()
	_tt_intel_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tt_intel_section.add_theme_constant_override("separation", 1)
	_tt_vbox.add_child(_tt_intel_section)

	# Special section (chokepoint, wall HP, region)
	_tt_special_section = VBoxContainer.new()
	_tt_special_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tt_special_section.add_theme_constant_override("separation", 1)
	_tt_vbox.add_child(_tt_special_section)

	add_child(_tooltip_card)


func _make_tt_label() -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	lbl.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size.x = TOOLTIP_WIDTH - 24
	return lbl


func _make_tt_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.add_theme_stylebox_override("separator", StyleBoxLine.new())
	sep.add_theme_constant_override("separation", 4)
	return sep


func _show_tooltip(tile_idx: int) -> void:
	if tile_idx < 0:
		_hide_tooltip()
		return
	_populate_tooltip(tile_idx)
	_tooltip_card.visible = true
	_tooltip_visible = true
	_clamp_tooltip_to_viewport()


func _hide_tooltip() -> void:
	_tooltip_card.visible = false
	_tooltip_visible = false
	_hovered_tile_idx = -1
	_tooltip_timer = 0.0


func _populate_tooltip(tile_idx: int) -> void:
	## Fill tooltip content based on tile data, ownership, and fog status.
	var tile_data: Dictionary = _get_tile_data(tile_idx)
	if tile_data.is_empty():
		_tt_header_label.text = "未探索区域"
		_tt_header_stripe.color = ColorTheme.TEXT_MUTED
		_tt_terrain_label.text = ""
		_tt_owner_label.text = ""
		_tt_garrison_label.text = ""
		_tt_building_label.text = ""
		_tt_production_label.text = ""
		_tt_order_label.text = ""
		_tt_supply_label.text = ""
		_clear_dynamic_section(_tt_intel_section)
		_clear_dynamic_section(_tt_special_section)
		return

	var owner_id: int = tile_data.get("owner_id", -1)
	var is_player_owned: bool = owner_id == _player_id
	var is_scouted: bool = _is_tile_scouted(tile_idx)
	var is_revealed: bool = _is_tile_revealed(tile_idx)
	var tile_name: String = tile_data.get("name", "地块 #%d" % tile_idx)
	var tile_level: int = tile_data.get("level", 1)

	# ── Header ──
	var faction_color: Color = _get_faction_color_by_id(owner_id)
	_tt_header_stripe.color = faction_color
	_tt_header_label.text = "%s  Lv%d" % [tile_name, tile_level]

	# ── Fog check: unrevealed ──
	if not is_revealed and not is_player_owned:
		_tt_terrain_label.text = ""
		_tt_owner_label.text = "未探索区域"
		_tt_owner_label.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		_tt_garrison_label.text = ""
		_tt_building_label.text = ""
		_tt_production_label.text = ""
		_tt_order_label.text = ""
		_tt_supply_label.text = ""
		_clear_dynamic_section(_tt_intel_section)
		_clear_dynamic_section(_tt_special_section)
		return

	# ── Terrain + movement ──
	var terrain: String = tile_data.get("terrain", "平原")
	var move_cost: int = tile_data.get("move_cost", 1)
	_tt_terrain_label.text = "地形: %s  移动: %dAP" % [terrain, move_cost]
	_tt_terrain_label.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)

	# ── Owner ──
	var owner_name: String = _get_faction_name(owner_id) if owner_id >= 0 else "无主"
	_tt_owner_label.text = "领主: %s" % owner_name
	_tt_owner_label.add_theme_color_override("font_color", faction_color if owner_id >= 0 else ColorTheme.TEXT_DIM)

	# ── Ownership-dependent detail ──
	if is_player_owned:
		_populate_player_owned(tile_data, tile_idx)
	elif is_scouted:
		_populate_enemy_scouted(tile_data, tile_idx)
	elif is_revealed:
		_populate_enemy_basic(tile_data, tile_idx)
	else:
		_populate_neutral(tile_data, tile_idx)

	# ── Intel section ──
	_clear_dynamic_section(_tt_intel_section)
	var has_intel: bool = false
	if _espionage_system:
		# Scouted status
		var scout_turns: int = _get_scout_turns_left(tile_idx)
		if scout_turns > 0:
			_add_dynamic_label(_tt_intel_section, "🕵 侦察中 (%d回合剩余)" % scout_turns, ColorTheme.MARCH_PATH_FRIENDLY)
			has_intel = true
		# Sabotage status
		var sab_info: Dictionary = _get_sabotage_info(tile_idx)
		if not sab_info.is_empty():
			var penalty_pct: int = int(sab_info.get("production_penalty", 0.2) * 100)
			_add_dynamic_label(_tt_intel_section, "🕵 破坏中 (-%d%% 产出, %d回合)" % [penalty_pct, sab_info.get("turns_left", 0)], ColorTheme.TEXT_WARNING)
			has_intel = true
	if not has_intel:
		_tt_intel_section.visible = false
	else:
		_tt_intel_section.visible = true

	# ── Special properties ──
	_clear_dynamic_section(_tt_special_section)
	var has_special: bool = false
	if tile_data.get("is_chokepoint", false):
		_add_dynamic_label(_tt_special_section, "⚡ 要塞关隘", ColorTheme.TEXT_GOLD)
		has_special = true
	var wall_hp: int = tile_data.get("wall_hp", 0)
	var wall_max: int = tile_data.get("wall_max_hp", 0)
	if wall_max > 0:
		_add_dynamic_label(_tt_special_section, "🏰 城墙: %d/%d" % [wall_hp, wall_max], ColorTheme.hp_color(float(wall_hp) / float(maxi(int(wall_max), 1))))
		has_special = true
	var region_name: String = tile_data.get("region", "")
	if region_name != "":
		_add_dynamic_label(_tt_special_section, "📍 区域: %s" % region_name, ColorTheme.TEXT_DIM)
		has_special = true
	_tt_special_section.visible = has_special


func _populate_player_owned(tile_data: Dictionary, _tile_idx: int) -> void:
	## Full detail for player-owned tiles.
	var garrison: int = tile_data.get("garrison", 0)
	_tt_garrison_label.text = "⚔ 驻军: %d" % garrison
	_tt_garrison_label.add_theme_color_override("font_color", ColorTheme.TEXT_SUCCESS)

	var building: String = tile_data.get("building_name", "")
	var building_level: int = tile_data.get("building_level", 0)
	if building != "":
		_tt_building_label.text = "🏗 建筑: %s Lv%d" % [building, building_level]
	else:
		_tt_building_label.text = "🏗 建筑: 无"
	_tt_building_label.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)

	var gold_prod: int = tile_data.get("gold_production", 0)
	var food_prod: int = tile_data.get("food_production", 0)
	var iron_prod: int = tile_data.get("iron_production", 0)
	_tt_production_label.text = "📊 产出: 🪙%d 🌾%d ⚒%d" % [gold_prod, food_prod, iron_prod]
	_tt_production_label.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)

	var public_order: int = tile_data.get("public_order", 100)
	var order_color: Color = ColorTheme.TEXT_SUCCESS if public_order >= 60 else (ColorTheme.TEXT_WARNING if public_order >= 30 else ColorTheme.TEXT_RED)
	_tt_order_label.text = "📋 民心: %d" % public_order
	_tt_order_label.add_theme_color_override("font_color", order_color)

	var supply_connected: bool = tile_data.get("supply_connected", true)
	var supply_dist: int = tile_data.get("supply_distance", 0)
	if supply_connected:
		_tt_supply_label.text = "🔗 补给: 已连接 (%d格)" % supply_dist
		_tt_supply_label.add_theme_color_override("font_color", ColorTheme.TEXT_SUCCESS)
	else:
		_tt_supply_label.text = "🔗 补给: 断裂"
		_tt_supply_label.add_theme_color_override("font_color", ColorTheme.TEXT_RED)


func _populate_enemy_scouted(tile_data: Dictionary, _tile_idx: int) -> void:
	## Scouted enemy tile — garrison, building, production estimates, wall HP.
	var garrison: int = tile_data.get("garrison", 0)
	_tt_garrison_label.text = "⚔ 驻军: %d" % garrison
	_tt_garrison_label.add_theme_color_override("font_color", ColorTheme.TEXT_RED)

	var building: String = tile_data.get("building_name", "")
	var building_level: int = tile_data.get("building_level", 0)
	if building != "":
		_tt_building_label.text = "🏗 建筑: %s Lv%d" % [building, building_level]
	else:
		_tt_building_label.text = "🏗 建筑: 不明"
	_tt_building_label.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)

	var gold_prod: int = tile_data.get("gold_production", 0)
	var food_prod: int = tile_data.get("food_production", 0)
	var iron_prod: int = tile_data.get("iron_production", 0)
	_tt_production_label.text = "📊 产出: 🪙~%d 🌾~%d ⚒~%d" % [gold_prod, food_prod, iron_prod]
	_tt_production_label.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)

	_tt_order_label.text = ""
	_tt_supply_label.text = ""


func _populate_enemy_basic(tile_data: Dictionary, _tile_idx: int) -> void:
	## Revealed but not scouted — only basic info.
	var garrison: int = tile_data.get("garrison", 0)
	# Show a rough estimate range
	var low: int = maxi(0, garrison - 10)
	var high: int = garrison + 10
	_tt_garrison_label.text = "⚔ 驻军: 约%d-%d兵" % [low, high]
	_tt_garrison_label.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)

	_tt_building_label.text = "情报不足"
	_tt_building_label.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	_tt_production_label.text = ""
	_tt_order_label.text = ""
	_tt_supply_label.text = ""


func _populate_neutral(tile_data: Dictionary, _tile_idx: int) -> void:
	## Neutral (unowned or neutral faction) tile.
	var garrison: int = tile_data.get("garrison", 0)
	_tt_garrison_label.text = "⚔ 驻军: %d" % garrison
	_tt_garrison_label.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)

	var faction_tag: String = tile_data.get("neutral_faction", "")
	if faction_tag != "":
		_tt_building_label.text = "阵营: %s" % faction_tag
	else:
		_tt_building_label.text = ""
	_tt_building_label.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)

	var taming_level: int = tile_data.get("taming_level", 0)
	if taming_level > 0:
		_tt_production_label.text = "驯服度: %d" % taming_level
		_tt_production_label.add_theme_color_override("font_color", ColorTheme.RES_ORDER)
	else:
		_tt_production_label.text = ""

	var quest_status: String = tile_data.get("quest_status", "")
	if quest_status != "":
		_tt_order_label.text = "任务: %s" % quest_status
		_tt_order_label.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD)
	else:
		_tt_order_label.text = ""
	_tt_supply_label.text = ""


func _clamp_tooltip_to_viewport() -> void:
	if not _tooltip_card.visible:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var card_size: Vector2 = _tooltip_card.size
	var pos: Vector2 = _tooltip_card.position
	if pos.x + card_size.x > vp_size.x:
		pos.x = vp_size.x - card_size.x - 4
	if pos.y + card_size.y > vp_size.y:
		pos.y = vp_size.y - card_size.y - 4
	if pos.x < 0:
		pos.x = 4
	if pos.y < 0:
		pos.y = 4
	_tooltip_card.position = pos


func _handle_mouse_hover(mouse_pos: Vector2) -> void:
	var tile_idx: int = _get_tile_at_screen(mouse_pos)
	if tile_idx != _hovered_tile_idx:
		if tile_idx < 0:
			_hide_tooltip()
			_hovered_tile_idx = -1
		else:
			# New tile hovered — reset timer
			_hovered_tile_idx = tile_idx
			_tooltip_timer = 0.0
			if _tooltip_visible:
				# Already showing tooltip, switch immediately
				_show_tooltip(tile_idx)
	if _tooltip_visible and _hovered_tile_idx >= 0:
		_tooltip_card.position = mouse_pos + TOOLTIP_OFFSET
		_clamp_tooltip_to_viewport()


func _update_tooltip_timer(delta: float) -> void:
	if _hovered_tile_idx >= 0 and not _tooltip_visible:
		_tooltip_timer += delta
		if _tooltip_timer >= TOOLTIP_DELAY:
			_show_tooltip(_hovered_tile_idx)
			var mouse_pos: Vector2 = get_viewport().get_mouse_position()
			_tooltip_card.position = mouse_pos + TOOLTIP_OFFSET
			_clamp_tooltip_to_viewport()


func _get_tile_at_screen(screen_pos: Vector2) -> int:
	## Determine which tile index the screen position corresponds to.
	## Checks GameManager for a hit-test method first, then falls back to grid math.
	if GameManager and GameManager.has_method("get_tile_at_position"):
		return GameManager.get_tile_at_position(screen_pos)
	if not GameManager or not GameManager.get("tiles"):
		return -1
	# Fallback grid calculation
	var cols: int = 10
	if GameManager and GameManager.get("board_columns"):
		cols = GameManager.board_columns
	var col: int = int(screen_pos.x / TILE_SIZE.x)
	var row: int = int(screen_pos.y / TILE_SIZE.y)
	if col < 0 or row < 0:
		return -1
	var idx: int = row * cols + col
	if idx < 0 or idx >= GameManager.tiles.size():
		return -1
	return idx

# ═══════════════════════════════════════════════════════════════
#             PART 3: INTEL REPORT SIDE PANEL
# ═══════════════════════════════════════════════════════════════

func _build_side_panel() -> void:
	_intel_side_panel = PanelContainer.new()
	_intel_side_panel.name = "IntelSidePanel"
	var style := ColorTheme.make_panel_style(SIDE_PANEL_BG, ColorTheme.BORDER_DEFAULT, 1, 6, 10)
	_intel_side_panel.add_theme_stylebox_override("panel", style)
	_intel_side_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_intel_side_panel.visible = false
	_intel_side_panel.z_index = 40

	# Anchor to right-center of viewport
	_intel_side_panel.anchor_left = 1.0
	_intel_side_panel.anchor_right = 1.0
	_intel_side_panel.anchor_top = 0.25
	_intel_side_panel.anchor_bottom = 0.75
	_intel_side_panel.offset_left = -SIDE_PANEL_WIDTH - 10
	_intel_side_panel.offset_right = -10
	_intel_side_panel.offset_top = 0
	_intel_side_panel.offset_bottom = 0
	_intel_side_panel.custom_minimum_size = Vector2(SIDE_PANEL_WIDTH, 300)

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_intel_side_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "情报总览"
	title.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING)
	title.add_theme_color_override("font_color", ColorTheme.TEXT_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# ── Intel bar ──
	var intel_row := _make_bar_row("情报值")
	_sp_intel_label = intel_row["label"]
	_sp_intel_bar = intel_row["fill"]
	_sp_intel_bar_bg = intel_row["bg"]
	vbox.add_child(intel_row["container"])

	# ── Counter-intel bar ──
	var counter_row := _make_bar_row("反谍值")
	_sp_counter_label = counter_row["label"]
	_sp_counter_bar = counter_row["fill"]
	_sp_counter_bar_bg = counter_row["bg"]
	vbox.add_child(counter_row["container"])

	vbox.add_child(_make_sp_separator())

	# ── Scouted section ──
	_sp_scouted_header = _make_collapsible_header("▼ 已侦察地块")
	vbox.add_child(_sp_scouted_header)
	_sp_scouted_vbox = VBoxContainer.new()
	_sp_scouted_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_sp_scouted_vbox)
	_sp_scouted_header.pressed.connect(_toggle_section.bind(_sp_scouted_vbox, _sp_scouted_header))

	# ── Sabotage section ──
	_sp_sabotage_header = _make_collapsible_header("▼ 破坏中")
	vbox.add_child(_sp_sabotage_header)
	_sp_sabotage_vbox = VBoxContainer.new()
	_sp_sabotage_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_sp_sabotage_vbox)
	_sp_sabotage_header.pressed.connect(_toggle_section.bind(_sp_sabotage_vbox, _sp_sabotage_header))

	# ── Intercepted orders section ──
	_sp_intercept_header = _make_collapsible_header("▼ 截获情报")
	vbox.add_child(_sp_intercept_header)
	_sp_intercept_vbox = VBoxContainer.new()
	_sp_intercept_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_sp_intercept_vbox)
	_sp_intercept_header.pressed.connect(_toggle_section.bind(_sp_intercept_vbox, _sp_intercept_header))

	# ── Wounded heroes section ──
	_sp_wounded_header = _make_collapsible_header("▼ 受伤英雄")
	vbox.add_child(_sp_wounded_header)
	_sp_wounded_vbox = VBoxContainer.new()
	_sp_wounded_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_sp_wounded_vbox)
	_sp_wounded_header.pressed.connect(_toggle_section.bind(_sp_wounded_vbox, _sp_wounded_header))

	add_child(_intel_side_panel)


func _make_bar_row(label_text: String) -> Dictionary:
	## Creates a labeled progress bar row. Returns { container, label, bg, fill }.
	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var label := Label.new()
	label.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	label.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	label.text = "%s: 0/100" % label_text
	container.add_child(label)

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(SIDE_PANEL_WIDTH - 30, 10)
	bar_bg.color = Color(0.15, 0.15, 0.2, 0.8)
	container.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.custom_minimum_size = Vector2(0, 10)
	bar_fill.size = Vector2(0, 10)
	bar_fill.position = Vector2.ZERO
	if label_text == "情报值":
		bar_fill.color = Color(0.2, 0.55, 0.85)
	else:
		bar_fill.color = Color(0.7, 0.3, 0.6)
	bar_bg.add_child(bar_fill)

	return {"container": container, "label": label, "bg": bar_bg, "fill": bar_fill}


func _make_collapsible_header(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.flat = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	btn.add_theme_color_override("font_color", ColorTheme.TEXT_HEADING)
	btn.add_theme_color_override("font_hover_color", ColorTheme.TEXT_GOLD)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	return btn


func _make_sp_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	return sep


func _toggle_section(section_vbox: VBoxContainer, header_btn: Button) -> void:
	section_vbox.visible = not section_vbox.visible
	var current_text: String = header_btn.text
	if current_text.begins_with("▼"):
		header_btn.text = "▶" + current_text.substr(1)
	elif current_text.begins_with("▶"):
		header_btn.text = "▼" + current_text.substr(1)


func _toggle_side_panel() -> void:
	_side_panel_open = not _side_panel_open
	if _side_panel_open:
		_refresh_side_panel()
		_intel_side_panel.visible = true
		ColorTheme.animate_panel_open(_intel_side_panel)
	else:
		_intel_side_panel.visible = false


func _toggle_heatmap() -> void:
	_heatmap_enabled = not _heatmap_enabled
	_refresh_overlay()


func _refresh_side_panel() -> void:
	if _espionage_system == null:
		return
	_player_id = _get_current_player_id()

	# ── Intel / Counter bars ──
	var intel_val: int = _espionage_system.get_intel(_player_id)
	var intel_max: int = _espionage_system._get_max_intel(_player_id)
	_sp_intel_label.text = "情报值: %d/%d" % [intel_val, intel_max]
	var intel_ratio: float = float(intel_val) / float(maxi(intel_max, 1))
	_sp_intel_bar.custom_minimum_size.x = (SIDE_PANEL_WIDTH - 30) * intel_ratio
	_sp_intel_bar.size.x = _sp_intel_bar.custom_minimum_size.x

	var counter_val: int = _espionage_system.get_counter_intel(_player_id)
	_sp_counter_label.text = "反谍值: %d/%d" % [counter_val, EspionageSystem.COUNTER_INTEL_MAX]
	var counter_ratio: float = float(counter_val) / float(EspionageSystem.COUNTER_INTEL_MAX)
	_sp_counter_bar.custom_minimum_size.x = (SIDE_PANEL_WIDTH - 30) * counter_ratio
	_sp_counter_bar.size.x = _sp_counter_bar.custom_minimum_size.x

	# ── Scouted tiles ──
	_clear_dynamic_section(_sp_scouted_vbox)
	var revealed: Array = _espionage_system._revealed_tiles.get(_player_id, [])
	var scout_count: int = 0
	for entry in revealed:
		if entry["turns_left"] <= 0:
			continue
		scout_count += 1
		var tile_name: String = _get_tile_name(entry["tile"])
		var lbl := Label.new()
		lbl.text = "  • %s (%d回合)" % [tile_name, entry["turns_left"]]
		lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		lbl.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
		_sp_scouted_vbox.add_child(lbl)
	_sp_scouted_header.text = "▼ 已侦察地块 (%d)" % scout_count if _sp_scouted_vbox.visible else "▶ 已侦察地块 (%d)" % scout_count

	# ── Sabotaged tiles ──
	_clear_dynamic_section(_sp_sabotage_vbox)
	var sabotaged: Array = _espionage_system.get_sabotaged_tiles(_player_id)
	var sab_count: int = 0
	for entry in sabotaged:
		if entry["turns_left"] <= 0:
			continue
		sab_count += 1
		var tile_name: String = _get_tile_name(entry["tile"])
		var penalty_pct: int = int(entry.get("production_penalty", 0.2) * 100)
		var lbl := Label.new()
		lbl.text = "  • %s (-%d%%, %d回合)" % [tile_name, penalty_pct, entry["turns_left"]]
		lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		lbl.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)
		_sp_sabotage_vbox.add_child(lbl)
	_sp_sabotage_header.text = "▼ 破坏中 (%d)" % sab_count if _sp_sabotage_vbox.visible else "▶ 破坏中 (%d)" % sab_count

	# ── Intercepted orders ──
	_clear_dynamic_section(_sp_intercept_vbox)
	var intercepted: Array = _espionage_system._intercepted_orders.get(_player_id, [])
	for entry in intercepted:
		if entry["turns_left"] <= 0:
			continue
		var faction_name: String = _get_faction_name(entry["target_id"])
		var moves: Array = entry.get("moves", [])
		if moves.is_empty():
			var lbl := Label.new()
			lbl.text = "  %s: 下回合行动已截获" % faction_name
			lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
			lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD)
			_sp_intercept_vbox.add_child(lbl)
		else:
			for move_text in moves:
				var lbl := Label.new()
				lbl.text = "  %s: %s" % [faction_name, str(move_text)]
				lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
				lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD)
				_sp_intercept_vbox.add_child(lbl)
	_sp_intercept_header.text = "▼ 截获情报" if _sp_intercept_vbox.visible else "▶ 截获情报"

	# ── Wounded heroes ──
	_clear_dynamic_section(_sp_wounded_vbox)
	var wounded: Array = _espionage_system.get_wounded_heroes(_player_id)
	var wound_count: int = wounded.size()
	for entry in wounded:
		var hero_id: String = entry["hero_id"]
		var hero_name: String = _get_hero_display_name(hero_id)
		var atk_pen: int = entry.get("atk_penalty", 0)
		var turns_left: int = entry.get("turns_left", 0)
		var lbl := Label.new()
		lbl.text = "  • %s (ATK-%d%%, %d回合)" % [hero_name, atk_pen, turns_left]
		lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
		lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.2))
		_sp_wounded_vbox.add_child(lbl)
	_sp_wounded_header.text = "▼ 受伤英雄 (%d)" % wound_count if _sp_wounded_vbox.visible else "▶ 受伤英雄 (%d)" % wound_count

# ═══════════════════════════════════════════════════════════════
#             SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_territory_selected(tile_index: int) -> void:
	_hovered_tile_idx = tile_index
	_tooltip_timer = TOOLTIP_DELAY  # show immediately on selection
	_show_tooltip(tile_index)
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	_tooltip_card.position = mouse_pos + TOOLTIP_OFFSET
	_clamp_tooltip_to_viewport()


func _on_territory_deselected() -> void:
	_hide_tooltip()


func _on_turn_started(player_id: int) -> void:
	_player_id = player_id
	_refresh_overlay()
	if _side_panel_open:
		_refresh_side_panel()


func _on_spy_operation_result(_pid: int, _op_type: int, _success: bool, _details: Dictionary) -> void:
	# Refresh overlays after any spy operation completes
	_refresh_overlay()
	if _side_panel_open:
		_refresh_side_panel()


func _on_intel_changed(player_id: int, _intel: int) -> void:
	if player_id == _player_id and _side_panel_open:
		_refresh_side_panel()


func _on_fog_updated(_pid: int) -> void:
	_refresh_overlay()

# ═══════════════════════════════════════════════════════════════
#             HELPERS
# ═══════════════════════════════════════════════════════════════

func _get_current_player_id() -> int:
	if GameManager and GameManager.get("current_player_id") != null:
		return GameManager.current_player_id
	if GameManager and GameManager.has_method("get_current_player"):
		var result: Variant = GameManager.get_current_player()
		if result is int:
			return result
		elif result is Dictionary:
			return result.get("id", 0)
	return 0


func _get_tile_data(tile_idx: int) -> Dictionary:
	if not GameManager or not GameManager.get("tiles"):
		return {}
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return {}
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[tile_idx]
	if tile == null:
		return {}
	if tile is Dictionary:
		return tile
	# If tile is an object, try to get a dictionary representation
	if tile.has_method("to_dict"):
		return tile.to_dict()
	return {}


func _get_tile_name(tile_idx: int) -> String:
	var data: Dictionary = _get_tile_data(tile_idx)
	if data.has("name"):
		return data["name"]
	return "地块 #%d" % tile_idx


func _is_tile_scouted(tile_idx: int) -> bool:
	if _espionage_system == null:
		return false
	var revealed: Array = _espionage_system._revealed_tiles.get(_player_id, [])
	for entry in revealed:
		if entry["tile"] == tile_idx and entry["turns_left"] > 0:
			return true
	return false


func _is_tile_revealed(tile_idx: int) -> bool:
	## Check if tile is visible through fog of war (not necessarily scouted).
	## Player-owned tiles are always revealed.
	var tile_data: Dictionary = _get_tile_data(tile_idx)
	if tile_data.is_empty():
		return false
	if tile_data.get("owner_id", -1) == _player_id:
		return true
	# Check fog of war system
	if GameManager and GameManager.has_method("is_tile_visible"):
		return GameManager.is_tile_visible(_player_id, tile_idx)
	# Fallback: if the tile has a "visible" or "revealed" field
	if tile_data.has("revealed"):
		return tile_data["revealed"]
	if tile_data.has("visible"):
		return tile_data["visible"]
	# Default to revealed if no fog system
	return true


func _get_scout_turns_left(tile_idx: int) -> int:
	if _espionage_system == null:
		return 0
	var revealed: Array = _espionage_system._revealed_tiles.get(_player_id, [])
	for entry in revealed:
		if entry["tile"] == tile_idx:
			return entry.get("turns_left", 0)
	return 0


func _get_sabotage_info(tile_idx: int) -> Dictionary:
	if _espionage_system == null:
		return {}
	# Check all players' sabotaged tiles
	for pid in _espionage_system._sabotaged_tiles:
		for entry in _espionage_system._sabotaged_tiles[pid]:
			if entry["tile"] == tile_idx and entry["turns_left"] > 0:
				return entry
	return {}


func _get_faction_name(faction_id: int) -> String:
	# Try GameManager faction data
	if GameManager and GameManager.has_method("get_faction_name"):
		return GameManager.get_faction_name(faction_id)
	# Fallback to known faction names
	var names: Dictionary = {
		0: "兽人部落",
		1: "海盗联盟",
		2: "暗精灵",
	}
	return names.get(faction_id, "势力 #%d" % faction_id)


func _get_faction_color_by_id(faction_id: int) -> Color:
	if ColorTheme.FACTION_ID_COLORS.has(faction_id):
		return ColorTheme.FACTION_ID_COLORS[faction_id]
	return ColorTheme.TEXT_DIM


func _get_faction_territory_center(faction_id: int) -> Vector2:
	## Approximate the screen center of a faction's territory for intercept card placement.
	if not GameManager or not GameManager.get("tiles"):
		return Vector2(400, 300)
	var sum := Vector2.ZERO
	var count: int = 0
	for i in GameManager.tiles.size():
		var tile = GameManager.tiles[i]
		if tile == null:
			continue
		var owner_id: int = -1
		if tile is Dictionary:
			owner_id = tile.get("owner_id", -1)
		if owner_id == faction_id:
			sum += _tile_to_screen_pos(i)
			count += 1
	if count == 0:
		return Vector2(400, 300)
	return sum / float(count)


func _get_hero_display_name(hero_id: String) -> String:
	if HeroSystem and HeroSystem.has_method("get_hero_info"):
		var info: Dictionary = HeroSystem.get_hero_info(hero_id)
		if not info.is_empty():
			return info.get("name", hero_id)
	return hero_id


func _min_tile_distance(tile_idx: int, target_tiles: Array) -> float:
	## Approximate distance between tile_idx and the nearest tile in target_tiles.
	## Uses grid coordinate distance as a proxy.
	var cols: int = 10
	if GameManager and GameManager.get("board_columns"):
		cols = GameManager.board_columns
	var row_a: int = tile_idx / cols
	var col_a: int = tile_idx % cols
	var min_d: float = 9999.0
	for t_idx in target_tiles:
		var row_b: int = t_idx / cols
		var col_b: int = t_idx % cols
		var d: float = absf(row_a - row_b) + absf(col_a - col_b)
		if d < min_d:
			min_d = d
	return min_d


func _clear_dynamic_section(container: Control) -> void:
	for child in container.get_children():
		child.queue_free()


func _add_dynamic_label(container: Control, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size.x = TOOLTIP_WIDTH - 30
	container.add_child(lbl)
