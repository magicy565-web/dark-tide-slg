## tile_indicator_system.gd — Visual indicator overlay for board tiles.
## CanvasLayer overlay (layer 3) that draws 2D indicator badges/icons over
## the 3D board, showing garrison, public order, buildings, supply, intel,
## territory level, and resource production at a glance.
extends Control

# ═══════════════════════════════════════════════════════════════════════════
#                          CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════

## Master toggle — hides every indicator when false.
var indicators_visible: bool = true

## Per-layer toggles.
var show_garrison: bool = true
var show_public_order: bool = true
var show_buildings: bool = true
var show_supply: bool = true
var show_chokepoints: bool = true
var show_intel: bool = true
var show_resources: bool = true
var show_level_stars: bool = true

# ═══════════════════════════════════════════════════════════════════════════
#                          LAYOUT CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════

## Half-size of the indicator cluster bounding box.
const CLUSTER_HALF := Vector2(42, 36)
## Offsets relative to the cluster centre for each badge slot.
const OFF_GARRISON     := Vector2(-38, -28)   # top-left
const OFF_ORDER        := Vector2( 26, -28)   # top-right
const OFF_BUILDING     := Vector2(-38,  16)   # bottom-left
const OFF_SUPPLY       := Vector2( 26,  16)   # bottom-right
const OFF_CHOKEPOINT   := Vector2(  0,  -4)   # centre
const OFF_INTEL_SCOUT  := Vector2(-18,  -4)   # centre-left
const OFF_INTEL_SABO   := Vector2(  0,  -4)   # centre
const OFF_INTEL_SHIELD := Vector2( 18,  -4)   # centre-right
const OFF_STARS        := Vector2(  0, -42)   # above cluster
const OFF_RES_BAR      := Vector2(  0,  34)   # below cluster

## Badge geometry.
const BADGE_SIZE     := Vector2(36, 16)
const DOT_RADIUS     := 5.0
const STAR_SPACING   := 10
const RES_BAR_W      := 48
const RES_BAR_H      := 4

## Pulse animation parameters.
const PULSE_SPEED    := 3.0
const PULSE_MIN_A    := 0.55
const PULSE_MAX_A    := 1.0

## Camera zoom thresholds — indicators fade / hide at extremes.
const ZOOM_FADE_FAR  := 35.0   # start fading out
const ZOOM_HIDE_FAR  := 50.0   # fully hidden
const ZOOM_FADE_NEAR := 8.0    # start fading in (too close = clutter)
const ZOOM_SCALE_REF := 18.0   # reference distance for scale = 1.0

# ═══════════════════════════════════════════════════════════════════════════
#                           INTERNAL STATE
# ═══════════════════════════════════════════════════════════════════════════

## Cached 2D screen positions per tile index.
var _tile_screen_positions: Dictionary = {}
## Container nodes per tile index — keys mirror badge names.
var _indicator_nodes: Dictionary = {}
## Reference to the active Camera3D (resolved each frame if null).
var _camera: Camera3D = null
## Reference to the Board node (for tile_visuals lookup).
var _board: Node = null

## Accumulated delta for pulsing animations.
var _pulse_time: float = 0.0

## Isolated-tile cache (refreshed on supply events or turn start).
var _isolated_tiles: Dictionary = {}  # tile_idx -> bool

## Scouted / sabotaged tile caches (refreshed from EspionageSystem).
var _scouted_tiles: Dictionary = {}   # tile_idx -> turns_left
var _sabotaged_tiles: Dictionary = {} # tile_idx -> turns_left
var _high_ci_tiles: Dictionary = {}   # tile_idx -> bool  (counter-intel)

# ═══════════════════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_signals()
	# Defer first build until the board is ready.
	if EventBus.has_signal("board_ready"):
		EventBus.board_ready.connect(_on_board_ready, CONNECT_ONE_SHOT)
	else:
		call_deferred("_deferred_init")


func _deferred_init() -> void:
	_resolve_board()
	rebuild_indicators()


func _on_board_ready() -> void:
	_deferred_init()


func _process(delta: float) -> void:
	if not indicators_visible:
		visible = false
		return
	visible = true

	_pulse_time += delta
	_resolve_camera()
	if _camera == null:
		return

	var cam_dist: float = _camera.global_position.length()
	# Global alpha based on zoom level.
	var alpha: float = 1.0
	if cam_dist > ZOOM_FADE_FAR:
		alpha = clampf(1.0 - (cam_dist - ZOOM_FADE_FAR) / (ZOOM_HIDE_FAR - ZOOM_FADE_FAR), 0.0, 1.0)
	modulate.a = alpha
	if alpha <= 0.0:
		return

	# Scale factor relative to reference zoom.
	var view_scale: float = clampf(ZOOM_SCALE_REF / maxf(cam_dist, 1.0), 0.5, 1.5)

	# Project every tile and reposition clusters.
	for tile_idx in _indicator_nodes:
		var cluster: Control = _indicator_nodes[tile_idx].get("cluster")
		if cluster == null:
			continue
		var screen_pos: Vector2 = _project_tile_to_screen(tile_idx)
		if screen_pos == Vector2(-9999, -9999):
			cluster.visible = false
			continue
		cluster.visible = true
		cluster.position = screen_pos
		cluster.scale = Vector2(view_scale, view_scale)

	# Animate pulsing elements.
	_animate_pulses(delta)

# ═══════════════════════════════════════════════════════════════════════════
#                       SIGNAL CONNECTIONS
# ═══════════════════════════════════════════════════════════════════════════

func _connect_signals() -> void:
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.tile_captured.connect(_on_tile_captured)
	EventBus.territory_changed.connect(_on_territory_changed)
	EventBus.building_constructed.connect(_on_building_constructed)
	EventBus.building_upgraded.connect(_on_building_upgraded)
	EventBus.resources_changed.connect(_on_resources_changed)
	if EventBus.has_signal("supply_line_cut"):
		EventBus.supply_line_cut.connect(_on_supply_line_cut)
	if EventBus.has_signal("supply_line_restored"):
		EventBus.supply_line_restored.connect(_on_supply_line_restored)
	# Manual single-tile refresh signal (emitted by army deploy, garrison, etc.)
	if EventBus.has_signal("tile_indicator_refresh"):
		EventBus.tile_indicator_refresh.connect(_on_tile_indicator_refresh)
	# Army state changes that affect tile display
	if EventBus.has_signal("army_march_arrived"):
		EventBus.army_march_arrived.connect(_on_army_march_arrived_indicator)
	if EventBus.has_signal("army_garrisoned"):
		EventBus.army_garrisoned.connect(_on_army_garrisoned_indicator)
	if EventBus.has_signal("army_deployed"):
		EventBus.army_deployed.connect(_on_army_deployed_indicator)


func _on_turn_started(_player_id: int) -> void:
	_refresh_intel_caches()
	_refresh_supply_cache()
	_update_all_indicators()


func _on_turn_ended(_player_id: int) -> void:
	_update_all_indicators()


func _on_tile_captured(_player_id: int, tile_index: int) -> void:
	_refresh_supply_cache()
	_update_tile_indicators(tile_index)
	# Neighbours may change supply status.
	for n_idx in GameManager.adjacency.get(tile_index, []):
		_update_tile_indicators(n_idx)


func _on_territory_changed(tile_index: int, _new_owner_id: int) -> void:
	_update_tile_indicators(tile_index)


func _on_building_constructed(_player_id: int, tile_index: int, _building_id: String) -> void:
	_update_tile_indicators(tile_index)


func _on_building_upgraded(_player_id: int, tile_index: int, _building_id: String, _new_level: int) -> void:
	_update_tile_indicators(tile_index)


func _on_resources_changed(_player_id: int) -> void:
	_update_all_indicators()


func _on_supply_line_cut(_player_id: int, isolated_tiles: Array) -> void:
	for t_idx in isolated_tiles:
		_isolated_tiles[t_idx] = true
		_update_tile_indicators(t_idx)


func _on_supply_line_restored(_player_id: int, tiles: Array) -> void:
	for t_idx in tiles:
		_isolated_tiles.erase(t_idx)
		_update_tile_indicators(t_idx)

# ═══════════════════════════════════════════════════════════════════════════
#                     REBUILD / UPDATE
# ═══════════════════════════════════════════════════════════════════════════

## Destroy and recreate all indicator clusters from scratch.
func rebuild_indicators() -> void:
	# Remove existing.
	for tile_idx in _indicator_nodes:
		var cluster = _indicator_nodes[tile_idx].get("cluster")
		if is_instance_valid(cluster):
			cluster.queue_free()
	_indicator_nodes.clear()

	if GameManager.tiles.is_empty():
		return

	_refresh_intel_caches()
	_refresh_supply_cache()

	for idx in range(GameManager.tiles.size()):
		var tile: Dictionary = GameManager.tiles[idx]
		if tile == null or tile.is_empty():
			continue
		_create_indicator_cluster(idx)

	_update_all_indicators()


## Update every tile's indicators in one pass.
func _update_all_indicators() -> void:
	for tile_idx in _indicator_nodes:
		_update_tile_indicators(tile_idx)


## Update the indicators for a single tile.
func _update_tile_indicators(tile_idx: int) -> void:
	if not _indicator_nodes.has(tile_idx):
		return
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return

	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return
	var tile_data: Dictionary = GameManager.tiles[tile_idx]
	if tile_data == null or tile_data.is_empty():
		return

	# Skip unrevealed (fogged) tiles.
	if _is_tile_fogged(tile_idx):
		var cluster = _indicator_nodes[tile_idx].get("cluster")
		if is_instance_valid(cluster):
			cluster.visible = false
		return

	_update_garrison_badge(tile_idx, tile_data)
	_update_order_dot(tile_idx, tile_data)
	_update_building_badge(tile_idx, tile_data)
	_update_supply_status(tile_idx, tile_data)
	_update_chokepoint_marker(tile_idx, tile_data)
	_update_intel_indicators(tile_idx, tile_data)
	_update_level_stars(tile_idx, tile_data)
	_update_resource_bar(tile_idx, tile_data)

# ═══════════════════════════════════════════════════════════════════════════
#                    CLUSTER CREATION
# ═══════════════════════════════════════════════════════════════════════════

## Build the full set of lightweight Control nodes for one tile.
func _create_indicator_cluster(tile_idx: int) -> void:
	var cluster := Control.new()
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster.name = "TileCluster_%d" % tile_idx
	add_child(cluster)

	var nodes: Dictionary = {"cluster": cluster}

	# 1 — Garrison badge (top-left).
	var garrison_badge := _make_badge_label()
	garrison_badge.position = OFF_GARRISON
	cluster.add_child(garrison_badge)
	nodes["garrison"] = garrison_badge

	# 2 — Public order dot (top-right).
	var order_dot := _make_color_dot()
	order_dot.position = OFF_ORDER
	cluster.add_child(order_dot)
	nodes["order_dot"] = order_dot

	var order_tip := _make_tiny_label()
	order_tip.position = OFF_ORDER + Vector2(DOT_RADIUS * 2 + 2, -2)
	order_tip.visible = false
	cluster.add_child(order_tip)
	nodes["order_tip"] = order_tip

	# 3 — Building badge (bottom-left).
	var building_badge := _make_badge_label()
	building_badge.position = OFF_BUILDING
	cluster.add_child(building_badge)
	nodes["building"] = building_badge

	# 4 — Supply status (bottom-right).
	var supply_lbl := _make_tiny_label()
	supply_lbl.position = OFF_SUPPLY
	cluster.add_child(supply_lbl)
	nodes["supply"] = supply_lbl

	# 5 — Chokepoint marker (centre).
	var choke_lbl := _make_tiny_label()
	choke_lbl.position = OFF_CHOKEPOINT
	choke_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cluster.add_child(choke_lbl)
	nodes["chokepoint"] = choke_lbl

	# 6a — Intel: scouted eye.
	var intel_scout := _make_tiny_label()
	intel_scout.position = OFF_INTEL_SCOUT
	cluster.add_child(intel_scout)
	nodes["intel_scout"] = intel_scout

	# 6b — Intel: sabotage warning.
	var intel_sabo := _make_tiny_label()
	intel_sabo.position = OFF_INTEL_SABO
	cluster.add_child(intel_sabo)
	nodes["intel_sabo"] = intel_sabo

	# 6c — Intel: counter-intel shield.
	var intel_shield := _make_tiny_label()
	intel_shield.position = OFF_INTEL_SHIELD
	cluster.add_child(intel_shield)
	nodes["intel_shield"] = intel_shield

	# 7 — Territory level stars.
	var stars_lbl := _make_tiny_label()
	stars_lbl.position = OFF_STARS
	stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cluster.add_child(stars_lbl)
	nodes["stars"] = stars_lbl

	# 8 — Resource production mini-bar (three ColorRects).
	var bar_root := Control.new()
	bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.position = OFF_RES_BAR
	cluster.add_child(bar_root)

	var bar_gold := ColorRect.new()
	bar_gold.size = Vector2(0, RES_BAR_H)
	bar_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(bar_gold)
	nodes["bar_gold"] = bar_gold

	var bar_food := ColorRect.new()
	bar_food.size = Vector2(0, RES_BAR_H)
	bar_food.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(bar_food)
	nodes["bar_food"] = bar_food

	var bar_iron := ColorRect.new()
	bar_iron.size = Vector2(0, RES_BAR_H)
	bar_iron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_root.add_child(bar_iron)
	nodes["bar_iron"] = bar_iron

	nodes["bar_root"] = bar_root

	_indicator_nodes[tile_idx] = nodes

# ═══════════════════════════════════════════════════════════════════════════
#                    INDIVIDUAL BADGE UPDATES
# ═══════════════════════════════════════════════════════════════════════════

func _update_garrison_badge(tile_idx: int, tile_data: Dictionary) -> void:
	var lbl: Label = _indicator_nodes[tile_idx].get("garrison")
	if lbl == null:
		return
	if not show_garrison:
		lbl.visible = false
		return

	var garrison: int = tile_data.get("garrison", 0)
	if garrison <= 0:
		lbl.visible = false
		return

	lbl.visible = true
	lbl.text = "\u2694%d" % garrison  # ⚔

	var owner_id: int = tile_data.get("owner_id", -1)
	var player: Dictionary = GameManager.get_current_player()
	var player_id: int = player.get("id", 0) if not player.is_empty() else 0

	if owner_id == player_id:
		_style_badge(lbl, ColorTheme.TEXT_SUCCESS, Color(0.15, 0.35, 0.15, 0.85))
	elif owner_id >= 0:
		_style_badge(lbl, ColorTheme.TEXT_RED, Color(0.35, 0.12, 0.12, 0.85))
	else:
		_style_badge(lbl, ColorTheme.TEXT_DIM, Color(0.25, 0.25, 0.28, 0.85))


func _update_order_dot(tile_idx: int, tile_data: Dictionary) -> void:
	var dot: ColorRect = _indicator_nodes[tile_idx].get("order_dot")
	var tip: Label = _indicator_nodes[tile_idx].get("order_tip")
	if dot == null:
		return
	if not show_public_order:
		dot.visible = false
		if tip:
			tip.visible = false
		return

	var player: Dictionary = GameManager.get_current_player()
	var player_id: int = player.get("id", 0) if not player.is_empty() else 0
	var owner_id: int = tile_data.get("owner_id", -1)

	if owner_id != player_id:
		dot.visible = false
		if tip:
			tip.visible = false
		return

	var order: int = tile_data.get("public_order", tile_data.get("order", 50))
	dot.visible = true
	dot.color = _order_color(order)
	dot.tooltip_text = "\u79E9\u5E8F: %d" % order  # 秩序: N

	if tip:
		tip.visible = false  # Keep tip hidden by default; tooltip suffices.


func _update_building_badge(tile_idx: int, tile_data: Dictionary) -> void:
	var lbl: Label = _indicator_nodes[tile_idx].get("building")
	if lbl == null:
		return
	if not show_buildings:
		lbl.visible = false
		return

	var building_id: String = tile_data.get("building_id", tile_data.get("building", ""))
	var building_level: int = tile_data.get("building_level", 0)

	if building_id.is_empty() or building_level <= 0:
		lbl.visible = false
		return

	lbl.visible = true
	var abbrev: String = _building_abbrev(building_id)
	lbl.text = "%s Lv%d" % [abbrev, building_level]

	var player: Dictionary = GameManager.get_current_player()
	var player_id: int = player.get("id", 0) if not player.is_empty() else 0
	var owner_id: int = tile_data.get("owner_id", -1)

	if owner_id == player_id:
		_style_badge(lbl, ColorTheme.SIDE_DEFENDER, Color(0.12, 0.18, 0.35, 0.85))
	else:
		_style_badge(lbl, ColorTheme.TEXT_MUTED, Color(0.2, 0.2, 0.22, 0.7))


func _update_supply_status(tile_idx: int, tile_data: Dictionary) -> void:
	var lbl: Label = _indicator_nodes[tile_idx].get("supply")
	if lbl == null:
		return
	if not show_supply:
		lbl.visible = false
		return

	var player: Dictionary = GameManager.get_current_player()
	var player_id: int = player.get("id", 0) if not player.is_empty() else 0
	var owner_id: int = tile_data.get("owner_id", -1)

	if owner_id != player_id:
		lbl.visible = false
		return

	lbl.visible = true

	var supplied: bool = _is_tile_supplied(player_id, tile_idx)
	if not supplied:
		# Cut off.
		lbl.text = "\u2717"  # ✗
		lbl.add_theme_color_override("font_color", ColorTheme.TEXT_RED)
	elif _isolated_tiles.has(tile_idx):
		# Distant / marginal.
		lbl.text = "\u2717"
		lbl.add_theme_color_override("font_color", ColorTheme.HP_MID)
	else:
		# Supplied.
		lbl.text = "\u2713"  # ✓
		lbl.add_theme_color_override("font_color", ColorTheme.TEXT_SUCCESS)


func _update_chokepoint_marker(tile_idx: int, tile_data: Dictionary) -> void:
	var lbl: Label = _indicator_nodes[tile_idx].get("chokepoint")
	if lbl == null:
		return
	if not show_chokepoints:
		lbl.visible = false
		return

	if not tile_data.get("is_chokepoint", false):
		lbl.visible = false
		return

	lbl.visible = true
	lbl.text = "\u26A1"  # ⚡
	lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT)


func _update_intel_indicators(tile_idx: int, _tile_data: Dictionary) -> void:
	var scout_lbl: Label = _indicator_nodes[tile_idx].get("intel_scout")
	var sabo_lbl: Label = _indicator_nodes[tile_idx].get("intel_sabo")
	var shield_lbl: Label = _indicator_nodes[tile_idx].get("intel_shield")

	if not show_intel:
		if scout_lbl:
			scout_lbl.visible = false
		if sabo_lbl:
			sabo_lbl.visible = false
		if shield_lbl:
			shield_lbl.visible = false
		return

	# Scouted (eye icon, blue, alpha fades with remaining turns).
	if scout_lbl:
		if _scouted_tiles.has(tile_idx):
			scout_lbl.visible = true
			scout_lbl.text = "\U0001F441"  # 👁
			var turns_left: int = _scouted_tiles[tile_idx]
			var fade_a: float = clampf(float(turns_left) / 5.0, 0.25, 1.0)
			scout_lbl.add_theme_color_override("font_color",
				Color(ColorTheme.SIDE_DEFENDER.r, ColorTheme.SIDE_DEFENDER.g,
					  ColorTheme.SIDE_DEFENDER.b, fade_a))
		else:
			scout_lbl.visible = false

	# Sabotaged (warning icon, red, pulsing handled in _animate_pulses).
	if sabo_lbl:
		if _sabotaged_tiles.has(tile_idx):
			sabo_lbl.visible = true
			sabo_lbl.text = "\u26A0"  # ⚠
			sabo_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_RED)
			sabo_lbl.set_meta("pulse", true)
		else:
			sabo_lbl.visible = false
			sabo_lbl.set_meta("pulse", false)

	# High counter-intel (shield icon).
	if shield_lbl:
		if _high_ci_tiles.has(tile_idx):
			shield_lbl.visible = true
			shield_lbl.text = "\U0001F6E1"  # 🛡
			shield_lbl.add_theme_color_override("font_color", ColorTheme.SIDE_DEFENDER)
		else:
			shield_lbl.visible = false


func _update_level_stars(tile_idx: int, tile_data: Dictionary) -> void:
	var lbl: Label = _indicator_nodes[tile_idx].get("stars")
	if lbl == null:
		return
	if not show_level_stars:
		lbl.visible = false
		return

	var level: int = clampi(tile_data.get("level", 1), 1, 5)
	if level <= 0:
		lbl.visible = false
		return

	lbl.visible = true
	lbl.text = "\u2605".repeat(level)  # ★
	lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD)


func _update_resource_bar(tile_idx: int, tile_data: Dictionary) -> void:
	var nodes: Dictionary = _indicator_nodes[tile_idx]
	var bar_root: Control = nodes.get("bar_root")
	var bar_gold: ColorRect = nodes.get("bar_gold")
	var bar_food: ColorRect = nodes.get("bar_food")
	var bar_iron: ColorRect = nodes.get("bar_iron")

	if bar_root == null:
		return
	if not show_resources:
		bar_root.visible = false
		return

	var player: Dictionary = GameManager.get_current_player()
	var player_id: int = player.get("id", 0) if not player.is_empty() else 0
	var owner_id: int = tile_data.get("owner_id", -1)

	if owner_id != player_id:
		bar_root.visible = false
		return

	var gold_prod: float = float(tile_data.get("gold_production", tile_data.get("gold", 0)))
	var food_prod: float = float(tile_data.get("food_production", tile_data.get("food", 0)))
	var iron_prod: float = float(tile_data.get("iron_production", tile_data.get("iron", 0)))

	var total: float = gold_prod + food_prod + iron_prod
	if total <= 0.0:
		bar_root.visible = false
		return

	bar_root.visible = true

	var gw: float = (gold_prod / total) * RES_BAR_W
	var fw: float = (food_prod / total) * RES_BAR_W
	var iw: float = (iron_prod / total) * RES_BAR_W

	bar_gold.color = ColorTheme.RES_GOLD
	bar_gold.size = Vector2(gw, RES_BAR_H)
	bar_gold.position = Vector2(-RES_BAR_W * 0.5, 0)

	bar_food.color = ColorTheme.RES_FOOD
	bar_food.size = Vector2(fw, RES_BAR_H)
	bar_food.position = Vector2(-RES_BAR_W * 0.5 + gw, 0)

	bar_iron.color = ColorTheme.RES_IRON
	bar_iron.size = Vector2(iw, RES_BAR_H)
	bar_iron.position = Vector2(-RES_BAR_W * 0.5 + gw + fw, 0)

# ═══════════════════════════════════════════════════════════════════════════
#                     3D → 2D PROJECTION
# ═══════════════════════════════════════════════════════════════════════════

## Project a tile's 3D world position onto the 2D screen.
## Returns Vector2(-9999, -9999) if the tile is behind the camera or off-screen.
func _project_tile_to_screen(tile_idx: int) -> Vector2:
	if _camera == null:
		return Vector2(-9999, -9999)

	var pos_3d: Vector3 = _get_tile_world_position(tile_idx)
	if pos_3d == Vector3.ZERO and tile_idx != 0:
		return Vector2(-9999, -9999)

	# Check if position is in front of camera.
	if not _camera.is_position_behind(pos_3d):
		var screen_pos: Vector2 = _camera.unproject_position(pos_3d)
		var vp_size: Vector2 = get_viewport_rect().size
		# Cull positions that are far off-screen.
		if screen_pos.x > -200 and screen_pos.x < vp_size.x + 200 \
		   and screen_pos.y > -200 and screen_pos.y < vp_size.y + 200:
			return screen_pos
	return Vector2(-9999, -9999)


## Retrieve the 3D world position of a tile from the board's tile_visuals.
func _get_tile_world_position(tile_idx: int) -> Vector3:
	if _board and _board.has_method("get") and _board.tile_visuals.has(tile_idx):
		var root: Node3D = _board.tile_visuals[tile_idx].get("root")
		if is_instance_valid(root):
			return root.global_position + Vector3(0, 2.5, 0)  # Offset above the hex.

	# Fallback: read from tile data if board is unavailable.
	if tile_idx >= 0 and tile_idx < GameManager.tiles.size():
		var tile: Dictionary = GameManager.tiles[tile_idx]
		var px: float = tile.get("world_x", tile.get("pos_x", 0.0))
		var pz: float = tile.get("world_z", tile.get("pos_z", 0.0))
		var py: float = tile.get("elevation", 0.0) + 2.5
		return Vector3(px, py, pz)

	return Vector3.ZERO

# ═══════════════════════════════════════════════════════════════════════════
#                     ANIMATION HELPERS
# ═══════════════════════════════════════════════════════════════════════════

## Drive pulsing alpha on chokepoint markers and sabotage warnings.
func _animate_pulses(_delta: float) -> void:
	var pulse_alpha: float = lerpf(PULSE_MIN_A, PULSE_MAX_A,
		(sin(_pulse_time * PULSE_SPEED) + 1.0) * 0.5)

	for tile_idx in _indicator_nodes:
		var nodes: Dictionary = _indicator_nodes[tile_idx]

		# Chokepoint pulse.
		var choke: Label = nodes.get("chokepoint")
		if choke and choke.visible:
			choke.modulate.a = pulse_alpha

		# Sabotage pulse.
		var sabo: Label = nodes.get("intel_sabo")
		if sabo and sabo.visible and sabo.get_meta("pulse", false):
			sabo.modulate.a = pulse_alpha

# ═══════════════════════════════════════════════════════════════════════════
#                     PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════

## Toggle a specific indicator layer on or off by name.
## Valid names: "garrison", "public_order", "buildings", "supply",
##              "chokepoints", "intel", "resources", "level_stars".
func toggle_layer(layer_name: String) -> void:
	match layer_name:
		"garrison":
			show_garrison = not show_garrison
		"public_order":
			show_public_order = not show_public_order
		"buildings":
			show_buildings = not show_buildings
		"supply":
			show_supply = not show_supply
		"chokepoints":
			show_chokepoints = not show_chokepoints
		"intel":
			show_intel = not show_intel
		"resources":
			show_resources = not show_resources
		"level_stars":
			show_level_stars = not show_level_stars
		_:
			push_warning("TileIndicatorSystem: unknown layer '%s'" % layer_name)
			return
	_update_all_indicators()


## Master visibility toggle.
func set_all_visible(vis: bool) -> void:
	indicators_visible = vis
	show_garrison = vis
	show_public_order = vis
	show_buildings = vis
	show_supply = vis
	show_chokepoints = vis
	show_intel = vis
	show_resources = vis
	show_level_stars = vis
	if vis:
		_update_all_indicators()

# ═══════════════════════════════════════════════════════════════════════════
#                     CACHE REFRESH
# ═══════════════════════════════════════════════════════════════════════════

func _refresh_intel_caches() -> void:
	_scouted_tiles.clear()
	_sabotaged_tiles.clear()
	_high_ci_tiles.clear()

	var espionage = _get_espionage_system()
	if espionage == null:
		return

	var player: Dictionary = GameManager.get_current_player()
	var player_id: int = player.get("id", 0) if not player.is_empty() else 0

	# Scouted tiles (revealed by player's own spy ops).
	if espionage.has_method("get_revealed_tiles"):
		var revealed: Array = espionage.get_revealed_tiles(player_id)
		# get_revealed_tiles may return indices directly or dicts.
		for entry in revealed:
			if entry is int:
				_scouted_tiles[entry] = 3  # Default visibility turns.
			elif entry is Dictionary:
				_scouted_tiles[entry.get("tile", -1)] = entry.get("turns_left", 1)

	# Sabotaged tiles.
	if espionage.has_method("get_sabotaged_tiles"):
		var sabotaged: Array = espionage.get_sabotaged_tiles(player_id)
		for entry in sabotaged:
			if entry is Dictionary:
				_sabotaged_tiles[entry.get("tile", -1)] = entry.get("turns_left", 1)

	# High counter-intel: mark player-owned tiles with notable CI.
	for idx in range(GameManager.tiles.size()):
		var tile: Dictionary = GameManager.tiles[idx]
		if tile == null:
			continue
		var ci: int = tile.get("counter_intel", 0)
		if ci >= 3:
			_high_ci_tiles[idx] = true


func _refresh_supply_cache() -> void:
	_isolated_tiles.clear()
	var supply_sys = _get_supply_system()
	if supply_sys == null:
		return

	var player: Dictionary = GameManager.get_current_player()
	var player_id: int = player.get("id", 0) if not player.is_empty() else 0

	if supply_sys.has_method("get_isolated_tiles"):
		var isolated: Array = supply_sys.get_isolated_tiles(player_id)
		for t_idx in isolated:
			_isolated_tiles[t_idx] = true

# ═══════════════════════════════════════════════════════════════════════════
#                     NODE FACTORIES
# ═══════════════════════════════════════════════════════════════════════════

## Create a small Label styled as a rounded badge (uses a StyleBoxFlat background).
func _make_badge_label() -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_TINY)
	lbl.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.14, 0.85)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(2)
	lbl.add_theme_stylebox_override("normal", sb)

	lbl.custom_minimum_size = Vector2(BADGE_SIZE.x, BADGE_SIZE.y)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.visible = false
	return lbl


## Create a small colored circle (ColorRect with rounded style).
func _make_color_dot() -> ColorRect:
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(DOT_RADIUS * 2, DOT_RADIUS * 2)
	dot.size = Vector2(DOT_RADIUS * 2, DOT_RADIUS * 2)
	dot.color = Color.GRAY
	dot.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow tooltip.
	dot.visible = false
	return dot


## Create a tiny text label for symbols / status characters.
func _make_tiny_label() -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_TINY)
	lbl.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.visible = false
	return lbl

# ═══════════════════════════════════════════════════════════════════════════
#                     STYLE HELPERS
# ═══════════════════════════════════════════════════════════════════════════

## Apply text colour and background colour to a badge label.
func _style_badge(lbl: Label, text_color: Color, bg_color: Color) -> void:
	lbl.add_theme_color_override("font_color", text_color)
	var sb: StyleBoxFlat = lbl.get_theme_stylebox("normal") as StyleBoxFlat
	if sb:
		# StyleBoxFlat is shared by reference; duplicate to avoid cross-badge leaks.
		var new_sb: StyleBoxFlat = sb.duplicate() as StyleBoxFlat
		new_sb.bg_color = bg_color
		lbl.add_theme_stylebox_override("normal", new_sb)


## Map public order value to a colour.
func _order_color(order: int) -> Color:
	if order > 60:
		return ColorTheme.TEXT_SUCCESS
	elif order > 30:
		return ColorTheme.HP_MID
	elif order > 10:
		return ColorTheme.RES_SLAVE  # Orange.
	else:
		return ColorTheme.TEXT_RED


## Abbreviate a building ID to a short display string.
func _building_abbrev(building_id: String) -> String:
	match building_id:
		"barracks", "barrack":
			return "Bk"
		"market":
			return "Mk"
		"farm":
			return "Fm"
		"mine":
			return "Mn"
		"wall", "walls", "fortification":
			return "Ft"
		"temple":
			return "Tp"
		"harbor", "harbour", "port":
			return "Hb"
		"tower", "watchtower":
			return "Tw"
		"academy":
			return "Ac"
		"slave_pit", "slave_pen":
			return "Sp"
		"forge":
			return "Fg"
		"tavern":
			return "Tv"
		"shrine":
			return "Sh"
		"workshop":
			return "Ws"
		_:
			# Generic: first two characters capitalised.
			if building_id.length() >= 2:
				return building_id.substr(0, 2).capitalize()
			return building_id.to_upper()

# ═══════════════════════════════════════════════════════════════════════════
#                     RESOLUTION HELPERS
# ═══════════════════════════════════════════════════════════════════════════

## Lazily find the Camera3D used by the board scene.
func _resolve_camera() -> void:
	if is_instance_valid(_camera):
		return
	_camera = get_viewport().get_camera_3d()


## Lazily find the Board node in the scene tree.
func _resolve_board() -> void:
	if is_instance_valid(_board):
		return
	# Try common paths first.
	var candidates: Array[String] = [
		"/root/Main/Board",
		"/root/Game/Board",
		"/root/Board",
	]
	for path in candidates:
		var node = get_node_or_null(path)
		if node and node.get("tile_visuals") != null:
			_board = node
			return
	# Brute search for a node with tile_visuals.
	_board = _find_board_recursive(get_tree().root)


func _find_board_recursive(node: Node) -> Variant:
	if node.get("tile_visuals") is Dictionary:
		return node
	for child in node.get_children():
		var found = _find_board_recursive(child)
		if found:
			return found
	return null


## Check if a tile is covered by fog of war.
func _is_tile_fogged(tile_idx: int) -> bool:
	if _board and _board.get("tile_visuals") is Dictionary:
		var vis: Dictionary = _board.tile_visuals.get(tile_idx, {})
		var fog: Node = vis.get("fog")
		if is_instance_valid(fog):
			return fog.visible
	return false


## Query the strategic SupplySystem singleton (or scene node).
func _get_supply_system():
	# Check autoload first.
	var ss = get_node_or_null("/root/SupplySystem")
	if ss:
		return ss
	# Check common tree paths.
	for path in ["/root/Main/SupplySystem", "/root/Game/Systems/SupplySystem"]:
		ss = get_node_or_null(path)
		if ss:
			return ss
	return null


## Query whether a tile is supplied via the SupplySystem.
func _is_tile_supplied(player_id: int, tile_idx: int) -> bool:
	var ss = _get_supply_system()
	if ss and ss.has_method("is_tile_supplied"):
		return ss.is_tile_supplied(player_id, tile_idx)
	# Fallback: assume supplied if no system is available.
	return not _isolated_tiles.has(tile_idx)


## Query the EspionageSystem singleton (or scene node).
func _get_espionage_system():
	var es = get_node_or_null("/root/EspionageSystem")
	if es:
		return es
	for path in ["/root/Main/EspionageSystem", "/root/Game/Systems/EspionageSystem"]:
		es = get_node_or_null(path)
		if es:
			return es
	return null


# ═══════════════════════════════════════════════════════════════
#   ARMY STATE → TILE INDICATOR REFRESH HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_tile_indicator_refresh(tile_index: int) -> void:
	## Refresh a single tile's indicators immediately (e.g. after deploy/garrison).
	if tile_index >= 0 and tile_index < GameManager.tiles.size():
		_update_tile_indicators(tile_index)


func _on_army_march_arrived_indicator(army_id: int, tile_index: int) -> void:
	## When an army arrives, refresh its destination tile and neighbours.
	_on_tile_indicator_refresh(tile_index)
	for n_idx in GameManager.adjacency.get(tile_index, []):
		_update_tile_indicators(n_idx)


func _on_army_garrisoned_indicator(army_id: int, tile_index: int) -> void:
	## When an army garrisons, refresh the tile so the garrison badge updates.
	_on_tile_indicator_refresh(tile_index)


func _on_army_deployed_indicator(_player_id: int, _army_id: int, from_tile: int, to_tile: int) -> void:
	## When an army deploys, refresh both origin and destination tiles.
	_on_tile_indicator_refresh(from_tile)
	_on_tile_indicator_refresh(to_tile)
