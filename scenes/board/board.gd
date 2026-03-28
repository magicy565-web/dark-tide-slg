## board.gd - Total War: Warhammer style Campaign Map for 暗潮 SLG (v1.0)
## Elevated terrain, faction borders, army figures, settlement growth, smooth camera,
## selection pulse, path preview, fog of war. Godot 4.2 gl_compatibility safe.
extends Node3D
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── AI-Generated Map Textures ──
var _terrain_textures: Dictionary = {}
var _settlement_textures: Dictionary = {}
var _crest_textures: Dictionary = {}
var _map_bg_texture: Texture2D = null
var _map_bg_variants: Array = []  # Alternative background textures
var _map_decoration_tex: Texture2D = null  # Map decoration sprite sheet
var _military_icon_tex: Texture2D = null  # Military army icon for 3D markers

func _load_map_assets() -> void:
	# Map background (primary)
	_map_bg_texture = _safe_tex_load("res://assets/map/map_background.png")
	# Load alternative backgrounds for faction-themed maps
	for bg_name in ["map_pixel_hd", "map_hd_v1", "map_hd_tw_v1", "map_hd_mj_v0", "map_hd_mj_v1", "map_hd_mj_v2", "map_hd_mj_v3"]:
		var tex: Texture2D = _safe_tex_load("res://assets/map/backgrounds/%s.png" % bg_name)
		if tex:
			_map_bg_variants.append(tex)
	# Select faction-themed background if available
	_select_faction_background()
	# Map decoration sprites
	_map_decoration_tex = _safe_tex_load("res://assets/map/map_decorations/map_sprites.png")
	# Military icon for army markers
	_military_icon_tex = _safe_tex_load("res://assets/map/actions/military_army.png")
	# Terrain textures
	for tname in ["plains","forest","mountain","swamp","coastal","fortress_wall","river","ruins","wasteland","volcanic"]:
		_terrain_textures[tname] = _safe_tex_load("res://assets/map/terrain/terrain_%s.png" % tname)
	# Settlement/building icons
	for sname in ["fortress","village","watchtower","trading_post","beacon","ruins","port","gate","bandit","crystal_mine","horse_ranch","gunpowder","shadow_rift","stronghold","event"]:
		_settlement_textures[sname] = _safe_tex_load("res://assets/map/settlements/settlement_%s.png" % sname)
	# Faction crests (including bandit/neutral fallbacks)
	for fname in ["orc","pirate","dark_elf","human","high_elf","mage"]:
		_crest_textures[fname] = _safe_tex_load("res://assets/map/crests/crest_%s.png" % fname)
	# Bandit and neutral don't have dedicated crests; use orc crest tinted as fallback
	if not _crest_textures.has("bandit") or _crest_textures.get("bandit") == null:
		_crest_textures["bandit"] = _crest_textures.get("orc")
	if not _crest_textures.has("neutral") or _crest_textures.get("neutral") == null:
		_crest_textures["neutral"] = null  # Neutral deliberately has no crest

func _select_faction_background() -> void:
	## Pick a map background variant based on the player's faction for thematic consistency.
	if _map_bg_variants.is_empty():
		return
	if GameManager.players.is_empty():
		return
	var pid: int = GameManager.get_human_player_id()
	var fid: int = GameManager.get_player_faction(pid)
	# Faction → preferred background index (pixel_hd=0, hd_v1=1, tw_v1=2, mj_v0-v3=3-6)
	var bg_idx: int = 0
	match fid:
		FactionData.FactionID.ORC:
			bg_idx = 2  # Total War style for Orc warfare theme
		FactionData.FactionID.PIRATE:
			bg_idx = 1  # HD style for naval/coastal feel
		FactionData.FactionID.DARK_ELF:
			bg_idx = 0  # Pixel HD for dark fantasy aesthetic
	if bg_idx < _map_bg_variants.size():
		_map_bg_texture = _map_bg_variants[bg_idx]

func _safe_tex_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null

# ── Visual tracking ──
var tile_visuals: Dictionary = {}
var edge_meshes: Array = []
var army_visuals: Dictionary = {}
var highlight_rings: Dictionary = {}
var faction_border_meshes: Array = []
var path_preview_meshes: Array = []
var water_anim_nodes: Array = []  # [{node, type}]
var attack_route_meshes: Array = []
var settlement_nodes: Dictionary = {}
var _settlement_cache: Dictionary = {}  # idx -> last icon_key to avoid redundant rebuilds
# ── Material cache ──
var _material_cache: Dictionary = {}
const _MATERIAL_CACHE_MAX: int = 512
var _fog_mat: StandardMaterial3D = null
var _fog_edge_mat: StandardMaterial3D = null
# ── Dirty fog tracking ──
var _fog_dirty_tiles: Array = []
# ── Selection state ──
var selected_tile: int = -1
var hovered_tile: int = -1
var _last_click_tile: int = -1
var _last_click_time: float = 0.0
var _hover_tween: Tween = null
var _pulse_tween: Tween = null
var _pulse_ring: MeshInstance3D = null
# ── Camera state ──
var camera: Camera3D
var camera_pivot: Node3D
var camera_target_pos: Vector3 = Vector3(9.0, 0.0, -8.0)
var camera_zoom: float = 1.0
const ZOOM_MIN: float = 0.6
const ZOOM_MAX: float = 2.0
const ZOOM_SPEED: float = 0.1
const PAN_SPEED: float = 15.0
const EDGE_SCROLL_MARGIN: float = 30.0
const EDGE_SCROLL_SPEED: float = 8.0
const CAM_LERP_SPEED: float = 6.0
const DOUBLE_CLICK_TIME: float = 0.35
const TILE_RADIUS: float = 1.8
const TILE_HEIGHT: float = 0.18
const GROUND_Y: float = -0.1

const FACTION_COLORS := {
	"orc": Color(0.75, 0.22, 0.18), "pirate": Color(0.18, 0.32, 0.62),
	"dark_elf": Color(0.45, 0.15, 0.62), "human": Color(0.75, 0.62, 0.22),
	"high_elf": Color(0.18, 0.58, 0.28), "mage": Color(0.18, 0.32, 0.72),
	"neutral": Color(0.45, 0.45, 0.38), "vassal": Color(0.35, 0.55, 0.40),
	"none": Color(0.28, 0.28, 0.25),
}
const FLAG_COLORS := {
	"orc": Color(1.0, 0.3, 0.2), "pirate": Color(0.3, 0.55, 0.85),
	"dark_elf": Color(0.55, 0.25, 0.8), "human": Color(1.0, 0.85, 0.15),
	"high_elf": Color(0.3, 0.85, 0.4), "mage": Color(0.3, 0.4, 1.0),
	"neutral": Color(0.6, 0.6, 0.55), "vassal": Color(0.45, 0.75, 0.50),
	"none": Color(0.35, 0.35, 0.3),
}
const TERRAIN_COLORS := {
	FactionData.TerrainType.PLAINS: Color(0.45, 0.6, 0.3),
	FactionData.TerrainType.FOREST: Color(0.2, 0.45, 0.15),
	FactionData.TerrainType.MOUNTAIN: Color(0.6, 0.55, 0.5),
	FactionData.TerrainType.SWAMP: Color(0.35, 0.4, 0.28),
	FactionData.TerrainType.COASTAL: Color(0.3, 0.45, 0.6),
	FactionData.TerrainType.FORTRESS_WALL: Color(0.65, 0.6, 0.55),
	FactionData.TerrainType.RIVER: Color(0.25, 0.4, 0.65),
	FactionData.TerrainType.RUINS: Color(0.5, 0.45, 0.55),
	FactionData.TerrainType.WASTELAND: Color(0.65, 0.55, 0.35),
	FactionData.TerrainType.VOLCANIC: Color(0.55, 0.25, 0.15),
}
const TERRAIN_ELEVATION := {
	FactionData.TerrainType.PLAINS: 0.0, FactionData.TerrainType.FOREST: 0.05,
	FactionData.TerrainType.MOUNTAIN: 0.3, FactionData.TerrainType.SWAMP: -0.05,
	FactionData.TerrainType.COASTAL: 0.0, FactionData.TerrainType.FORTRESS_WALL: 0.2,
	FactionData.TerrainType.RIVER: -0.03, FactionData.TerrainType.RUINS: 0.08,
	FactionData.TerrainType.WASTELAND: 0.02, FactionData.TerrainType.VOLCANIC: 0.25,
}
const COL_FOG := Color(0.08, 0.08, 0.12, 0.6)
const COL_FOG_EDGE := Color(0.08, 0.08, 0.12, 0.3)
const COL_HIGHLIGHT_FRIENDLY := Color(0.2, 0.9, 0.3, 0.35)
const COL_HIGHLIGHT_ENEMY := Color(0.9, 0.15, 0.15, 0.35)
const COL_HIGHLIGHT_NEUTRAL := Color(0.9, 0.8, 0.2, 0.35)
const COL_HIGHLIGHT_SELECTED := Color(1.0, 1.0, 1.0, 0.4)
const COL_DEPLOY_FILL := Color(0.95, 0.9, 0.2, 0.18)
const COL_ATTACK_FILL := Color(0.9, 0.15, 0.1, 0.18)

func _ready() -> void:
	_load_map_assets()
	_setup_environment(); _setup_lighting(); _setup_camera(); _setup_ground()
	EventBus.tile_captured.connect(_on_tile_captured)
	EventBus.fog_updated.connect(_on_fog_updated)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.game_over.connect(_on_game_over)
	EventBus.army_changed.connect(_on_army_changed)
	EventBus.army_deployed.connect(_on_army_deployed)
	EventBus.army_created.connect(_on_army_created_or_disbanded)
	EventBus.army_disbanded.connect(_on_army_created_or_disbanded)
	if not GameManager.tiles.is_empty():
		_build_board()

func rebuild() -> void:
	_clear_board(); _build_board()

# ═══════════════ ENVIRONMENT ═══════════════
func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.12, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.68)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)

func _setup_lighting() -> void:
	for cfg in [
		[Vector3(-50, 30, 0), Color(1.0, 0.95, 0.85), 1.7],
		[Vector3(-25, -120, 0), Color(0.55, 0.6, 0.82), 0.75],
		[Vector3(-10, 180, 0), Color(0.9, 0.7, 0.5), 0.35]]:
		var l := DirectionalLight3D.new()
		l.rotation_degrees = cfg[0]; l.light_color = cfg[1]
		l.light_energy = cfg[2]; l.shadow_enabled = false; add_child(l)

func _setup_camera() -> void:
	camera_pivot = Node3D.new(); camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(9.0, 0.0, -8.0); add_child(camera_pivot)
	camera = Camera3D.new(); camera.name = "Camera3D"
	camera.position = Vector3(0.0, 25.0, 12.0)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera.fov = 50.0; camera.current = true; camera_pivot.add_child(camera)

func _setup_ground() -> void:
	# ── Main ground plane with map background ──
	var g := MeshInstance3D.new(); var p := PlaneMesh.new(); p.size = Vector2(70, 60); g.mesh = p
	var m := StandardMaterial3D.new()
	if _map_bg_texture:
		m.albedo_texture = _map_bg_texture
		m.albedo_color = Color(0.7, 0.65, 0.55)
		m.uv1_scale = Vector3(1, 1, 1)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		m.albedo_color = Color(0.12, 0.15, 0.1)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; g.material_override = m
	g.position = Vector3(9.0, GROUND_Y - 0.15, -7.0); add_child(g)
	# ── Ocean/void boundary ring around the playable area ──
	_build_map_boundary()
	_setup_ambient_particles()

# ═══════════════ INPUT & CAMERA ═══════════════
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_zoom = clampf(camera_zoom - ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX); _apply_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_zoom = clampf(camera_zoom + ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX); _apply_zoom()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_deselect_tile()

func _process(delta: float) -> void:
	camera_pivot.position = camera_pivot.position.lerp(camera_target_pos, CAM_LERP_SPEED * delta)
	_process_camera_input(delta); _process_edge_scroll(delta); _process_hover_path(); _process_water_animation(delta)

func _process_camera_input(delta: float) -> void:
	var mv := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1.0
	if mv.length_squared() > 0.01:
		camera_target_pos += mv.normalized() * PAN_SPEED * delta / camera_zoom; _clamp_camera()

func _process_edge_scroll(delta: float) -> void:
	var vp := get_viewport()
	if not vp: return
	var mp := vp.get_mouse_position(); var vs := vp.get_visible_rect().size
	var mv := Vector3.ZERO
	if mp.x < EDGE_SCROLL_MARGIN: mv.x -= 1.0
	elif mp.x > vs.x - EDGE_SCROLL_MARGIN: mv.x += 1.0
	if mp.y < EDGE_SCROLL_MARGIN: mv.z -= 1.0
	elif mp.y > vs.y - EDGE_SCROLL_MARGIN: mv.z += 1.0
	if mv.length_squared() > 0.01:
		camera_target_pos += mv.normalized() * EDGE_SCROLL_SPEED * delta / camera_zoom; _clamp_camera()

func _apply_zoom() -> void:
	var t: float = inverse_lerp(ZOOM_MIN, ZOOM_MAX, camera_zoom)
	camera.position = Vector3(0.0, lerpf(30.0, 18.0, t) / camera_zoom, lerpf(8.0, 14.0, t) / camera_zoom)
	camera.rotation_degrees.x = lerpf(-68.0, -48.0, t)

func _clamp_camera() -> void:
	camera_target_pos.x = clampf(camera_target_pos.x, -5.0, 25.0)
	camera_target_pos.z = clampf(camera_target_pos.z, -25.0, 5.0)

# ═══════════════ BOARD BUILDING ═══════════════
func _clear_board() -> void:
	for idx in tile_visuals:
		var v: Dictionary = tile_visuals[idx]
		if is_instance_valid(v["root"]): v["root"].queue_free()
	tile_visuals.clear()
	for e in edge_meshes:
		if is_instance_valid(e): e.queue_free()
	edge_meshes.clear()
	for aid in army_visuals:
		if is_instance_valid(army_visuals[aid]): army_visuals[aid].queue_free()
	army_visuals.clear()
	for b in faction_border_meshes:
		if is_instance_valid(b): b.queue_free()
	faction_border_meshes.clear()
	# Clean up edge decorations and map boundary elements
	for ch in get_children():
		if ch.name in ["EdgeDeco", "MapBorder", "EdgeFog"]:
			ch.queue_free()
	settlement_nodes.clear()
	_settlement_cache.clear()
	water_anim_nodes.clear()
	for m in attack_route_meshes:
		if is_instance_valid(m): m.queue_free()
	attack_route_meshes.clear()
	_clear_highlights(); _clear_path_preview(); _clear_pulse_ring()

func _build_board() -> void:
	tile_visuals.clear()
	_material_cache.clear()
	_fog_dirty_tiles.clear()
	# Pre-build fog materials
	_fog_mat = StandardMaterial3D.new()
	_fog_mat.albedo_color = COL_FOG
	_fog_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fog_edge_mat = StandardMaterial3D.new()
	_fog_edge_mat.albedo_color = COL_FOG_EDGE
	_fog_edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fog_edge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for tile in GameManager.tiles:
		_build_territory(tile["index"], tile, tile["position_3d"])
	_draw_edges(); _draw_faction_borders()
	_build_inter_tile_decorations()
	_update_all_territories(); _update_fog()

func _get_elev(tile: Dictionary) -> float:
	return TERRAIN_ELEVATION.get(tile.get("terrain", FactionData.TerrainType.PLAINS), 0.0)

func _build_territory(idx: int, tile: Dictionary, pos: Vector3) -> void:
	var elev: float = _get_elev(tile)
	var root := Node3D.new()
	root.position = Vector3(pos.x, elev, pos.z)
	root.name = "Territory_%d" % idx; add_child(root)
	# Base hex
	var bm := CylinderMesh.new()
	bm.top_radius = TILE_RADIUS; bm.bottom_radius = TILE_RADIUS * 1.02
	bm.height = TILE_HEIGHT + elev * 0.5; bm.radial_segments = 6
	var base_mi := MeshInstance3D.new(); base_mi.mesh = bm
	base_mi.position.y = (TILE_HEIGHT + elev * 0.5) * 0.5 - elev * 0.25
	# Apply terrain texture to hex tile
	var terrain_key: String = _terrain_enum_to_key(tile.get("terrain", FactionData.TerrainType.PLAINS))
	var terrain_tex: Texture2D = _terrain_textures.get(terrain_key, null)
	if terrain_tex:
		base_mi.material_override = _make_textured_mat(Color(0.65, 0.65, 0.6), terrain_tex)
	else:
		base_mi.material_override = _make_mat(Color(0.5, 0.5, 0.5))
	root.add_child(base_mi)
	# Border ring
	var brm := CylinderMesh.new()
	brm.top_radius = TILE_RADIUS * 1.06; brm.bottom_radius = TILE_RADIUS * 1.06
	brm.height = 0.04; brm.radial_segments = 6
	var border_mi := MeshInstance3D.new(); border_mi.mesh = brm
	border_mi.position.y = 0.02
	border_mi.material_override = _make_mat(Color(0.3, 0.3, 0.28)); root.add_child(border_mi)
	# Terrain decor
	_build_terrain_decor(root, tile)
	# Chokepoint gate marker
	if tile.get("is_chokepoint", false):
		_build_chokepoint_marker(root, TILE_HEIGHT)
	# Settlement
	var sett := Node3D.new(); sett.name = "Settlement"; root.add_child(sett)
	settlement_nodes[idx] = sett; _build_settlement(sett, tile)
	# Labels
	var label := _make_label3d(tile.get("name", "#%d" % idx), 30, Vector3(0, 2.0, 0))
	root.add_child(label)
	var glabel := _make_label3d("", 22, Vector3(0, 1.6, 0), Color(1, 0.9, 0.7, 0.9))
	root.add_child(glabel)
	# Army marker
	var am := Node3D.new(); am.name = "ArmyMarker"; am.visible = false
	am.position = Vector3(-0.7, TILE_HEIGHT, 0.5); root.add_child(am)
	_build_army_figure(am)
	var alabel := _make_label3d("", 38, Vector3(0, 1.1, 0), Color(1.0, 0.6, 0.3, 1.0))
	alabel.name = "ArmyLabel"; alabel.pixel_size = 0.01; am.add_child(alabel)
	# Flag
	var fr := Node3D.new(); fr.name = "Flag"
	fr.position = Vector3(0.8, TILE_HEIGHT, -0.6); root.add_child(fr)
	var pole := _make_cyl_mesh(0.02, 0.03, 1.2, Color(0.45, 0.4, 0.35))
	pole.position.y = 0.6; fr.add_child(pole)
	var banner := _make_box_mesh(Vector3(0.35, 0.22, 0.02), Color(0.5, 0.5, 0.5))
	banner.position = Vector3(0.22, 1.1, 0.0); fr.add_child(banner)
	# Faction crest sprite (billboard)
	var crest_sprite := Sprite3D.new()
	crest_sprite.name = "CrestSprite"
	crest_sprite.pixel_size = 0.006
	crest_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	crest_sprite.no_depth_test = true
	crest_sprite.position = Vector3(-0.8, TILE_HEIGHT + 0.8, 0.6)
	crest_sprite.modulate = Color(1, 1, 1, 0.85)
	var fk_crest: String = _get_tile_faction_key(tile) if tile.get("owner_id", -1) >= 0 else ""
	if _crest_textures.has(fk_crest) and _crest_textures[fk_crest] != null:
		crest_sprite.texture = _crest_textures[fk_crest]
	else:
		crest_sprite.visible = false
	root.add_child(crest_sprite)
	# Fog
	var fog := MeshInstance3D.new(); var fm := CylinderMesh.new()
	fm.top_radius = TILE_RADIUS * 1.15; fm.bottom_radius = TILE_RADIUS * 1.15
	fm.height = 0.5; fm.radial_segments = 6; fog.mesh = fm
	fog.material_override = _fog_mat; fog.position.y = 0.35; fog.name = "FogOverlay"
	root.add_child(fog)
	# Click area
	var area := Area3D.new(); area.input_ray_pickable = true
	var cs := CollisionShape3D.new(); var cy := CylinderShape3D.new()
	cy.radius = TILE_RADIUS * 0.9; cy.height = 1.0; cs.shape = cy; cs.position.y = 0.5
	area.add_child(cs)
	area.input_event.connect(_on_tile_input.bind(idx))
	area.mouse_entered.connect(_on_tile_hover_enter.bind(idx))
	area.mouse_exited.connect(_on_tile_hover_exit.bind(idx))
	root.add_child(area)
	tile_visuals[idx] = {
		"root": root, "base": base_mi, "border": border_mi, "label": label,
		"garrison_label": glabel, "army_marker": am,
		"army_label": am.get_node("ArmyLabel"), "flag_root": fr, "banner": banner,
		"fog": fog, "area": area, "elevation": elev,
		"crest_sprite": crest_sprite,
	}

# ═══════════════ ARMY FIGURE ═══════════════
func _build_army_figure(p: Node3D) -> void:
	var body := _make_cyl_mesh(0.12, 0.15, 0.45, Color(0.6, 0.2, 0.2))
	body.name = "ArmyBody"; body.position.y = 0.25; p.add_child(body)
	var head := MeshInstance3D.new(); var hm := SphereMesh.new()
	hm.radius = 0.1; hm.height = 0.2; head.mesh = hm; head.name = "ArmyHead"
	head.material_override = _make_mat(Color(0.85, 0.7, 0.55)); head.position.y = 0.55
	p.add_child(head)
	var fp := _make_cyl_mesh(0.015, 0.02, 0.7, Color(0.5, 0.45, 0.4))
	fp.name = "ArmyFlagPole"; fp.position = Vector3(-0.15, 0.4, 0); p.add_child(fp)
	var fb := _make_box_mesh(Vector3(0.18, 0.12, 0.015), Color(0.6, 0.2, 0.2))
	fb.name = "ArmyBanner"; fb.position = Vector3(-0.06, 0.7, 0); p.add_child(fb)
	# Military icon billboard above the figure
	if _military_icon_tex:
		var mil_sprite := Sprite3D.new()
		mil_sprite.texture = _military_icon_tex
		mil_sprite.pixel_size = 0.004
		mil_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mil_sprite.no_depth_test = true
		mil_sprite.position = Vector3(0.15, 0.85, 0)
		mil_sprite.modulate = Color(1, 1, 1, 0.8)
		mil_sprite.scale = Vector3(0.5, 0.5, 0.5)
		mil_sprite.name = "MilitaryIcon"
		p.add_child(mil_sprite)

# ═══════════════ SETTLEMENTS ═══════════════
func _build_settlement(parent: Node3D, tile: Dictionary) -> void:
	for c in parent.get_children(): c.queue_free()
	var terrain = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var level: int = tile.get("level", 1)
	var tt = tile.get("type", -1)
	var y: float = TILE_HEIGHT
	# Determine settlement icon key based on tile type and special properties
	var icon_key: String = _get_settlement_icon_key(tile)
	var tex: Texture2D = _settlement_textures.get(icon_key, null)
	if tex != null:
		# Use AI-generated sprite instead of procedural geometry
		var sprite := Sprite3D.new()
		sprite.texture = tex
		sprite.pixel_size = 0.008
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sprite.axis = Vector3.AXIS_Y
		# Flat on top of hex, facing up
		sprite.rotation_degrees = Vector3(-90, 0, 0)
		var sscale: float = 0.6 + level * 0.15
		if tt == GameManager.TileType.CORE_FORTRESS:
			sscale = 1.1
		sprite.scale = Vector3(sscale, sscale, sscale)
		sprite.position = Vector3(0, y + 0.02, 0)
		sprite.modulate = Color(1, 1, 1, 0.9)
		parent.add_child(sprite)
		# Also add a small upright billboard version for visibility from camera angle
		var billboard := Sprite3D.new()
		billboard.texture = tex
		billboard.pixel_size = 0.005
		billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		billboard.no_depth_test = true
		var bscale: float = 0.45 + level * 0.1
		if tt == GameManager.TileType.CORE_FORTRESS:
			bscale = 0.8
		billboard.scale = Vector3(bscale, bscale, bscale)
		billboard.position = Vector3(0, y + 0.6 + level * 0.1, 0)
		billboard.modulate = Color(1, 1, 1, 0.85)
		parent.add_child(billboard)
	else:
		# Fallback to procedural geometry
		if tt == GameManager.TileType.CORE_FORTRESS or terrain == FactionData.TerrainType.FORTRESS_WALL:
			_build_castle(parent, y); return
		if level >= 3:
			_build_town_hall(parent, y, Vector3(0.3, 0, 0.3))
			_add_house(parent, y, Vector3(0.55, 0, 0.2)); _add_house(parent, y, Vector3(0.15, 0, 0.55))
		elif level >= 2:
			_add_house(parent, y, Vector3(0.2, 0, 0.25))
			_add_house(parent, y, Vector3(0.5, 0, 0.4)); _add_house(parent, y, Vector3(0.35, 0, 0.55))
		else:
			_add_house(parent, y, Vector3(0.3, 0, 0.3))

func _get_settlement_icon_key(tile: Dictionary) -> String:
	var tt = tile.get("type", -1)
	var terrain = tile.get("terrain", FactionData.TerrainType.PLAINS)
	# ── Primary: match by TileType enum ──
	match tt:
		GameManager.TileType.CORE_FORTRESS:
			return "fortress"
		GameManager.TileType.LIGHT_STRONGHOLD:
			return "stronghold"
		GameManager.TileType.NEUTRAL_BASE:
			return "stronghold"
		GameManager.TileType.DARK_BASE:
			return "bandit"
		GameManager.TileType.EVENT_TILE:
			return "event"
		GameManager.TileType.TRADING_POST:
			return "trading_post"
		GameManager.TileType.WATCHTOWER:
			return "beacon"
		GameManager.TileType.RUINS:
			return "ruins"
		GameManager.TileType.HARBOR:
			return "port"
		GameManager.TileType.CHOKEPOINT:
			return "gate"
		GameManager.TileType.MINE_TILE:
			return "crystal_mine"
		GameManager.TileType.RESOURCE_STATION:
			# Map by resource_station_type field
			var rst: String = tile.get("resource_station_type", "")
			match rst:
				"crystal": return "crystal_mine"
				"horse": return "horse_ranch"
				"gunpowder": return "gunpowder"
				"shadow": return "shadow_rift"
			return "crystal_mine"
	# ── Secondary: check chokepoint flag ──
	if tile.get("is_chokepoint", false):
		return "gate"
	# ── Tertiary: terrain-based ──
	if terrain == FactionData.TerrainType.FORTRESS_WALL:
		return "stronghold"
	# ── Default by level ──
	if tile.get("level", 1) >= 3:
		return "stronghold"
	return "village"

func _add_house(p: Node3D, y: float, o: Vector3) -> void:
	var h := _make_box_mesh(Vector3(0.18, 0.15, 0.18), Color(0.6, 0.5, 0.38))
	h.position = Vector3(o.x, y + 0.075, o.z); p.add_child(h)
	var r := _make_box_mesh(Vector3(0.22, 0.06, 0.22), Color(0.5, 0.25, 0.15))
	r.position = Vector3(o.x, y + 0.18, o.z); p.add_child(r)

func _build_town_hall(p: Node3D, y: float, o: Vector3) -> void:
	var h := _make_box_mesh(Vector3(0.3, 0.25, 0.25), Color(0.55, 0.48, 0.4))
	h.position = Vector3(o.x, y + 0.125, o.z); p.add_child(h)
	var t := _make_cyl_mesh(0.06, 0.08, 0.35, Color(0.5, 0.45, 0.4))
	t.position = Vector3(o.x + 0.15, y + 0.3, o.z - 0.1); p.add_child(t)

func _build_castle(p: Node3D, y: float) -> void:
	var keep := _make_box_mesh(Vector3(0.4, 0.45, 0.4), Color(0.55, 0.5, 0.45))
	keep.position = Vector3(0, y + 0.225, 0); p.add_child(keep)
	var mt := _make_cyl_mesh(0.08, 0.1, 0.4, Color(0.5, 0.48, 0.42))
	mt.position = Vector3(0, y + 0.65, 0); p.add_child(mt)
	for i in range(4):
		var a: float = float(i) / 4.0 * TAU + PI * 0.25
		var d: float = 0.6; var wx := cos(a) * d; var wz := sin(a) * d
		var tw := _make_cyl_mesh(0.07, 0.09, 0.5, Color(0.52, 0.48, 0.42))
		tw.position = Vector3(wx, y + 0.25, wz); p.add_child(tw)
		var wl := _make_box_mesh(Vector3(0.7, 0.3, 0.08), Color(0.5, 0.46, 0.4))
		wl.position = Vector3(wx * 0.7, y + 0.15, wz * 0.7)
		wl.rotation.y = a + PI * 0.5; p.add_child(wl)
	var gate := _make_box_mesh(Vector3(0.15, 0.2, 0.12), Color(0.35, 0.28, 0.2))
	gate.position = Vector3(0, y + 0.1, 0.6); p.add_child(gate)

# ═══════════════ TERRAIN DECORATIONS ═══════════════
func _build_terrain_decor(parent: Node3D, tile: Dictionary) -> void:
	var t: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var y: float = TILE_HEIGHT
	match t:
		FactionData.TerrainType.FOREST: _add_trees(parent, y, 5)
		FactionData.TerrainType.MOUNTAIN: _add_mountain_peaks(parent, y)
		FactionData.TerrainType.SWAMP: _add_swamp_pools(parent, y)
		FactionData.TerrainType.COASTAL: _add_water_edge(parent, y)
		FactionData.TerrainType.FORTRESS_WALL: pass
		FactionData.TerrainType.PLAINS: _add_grass_tufts(parent, y)
		FactionData.TerrainType.RUINS: _add_ruins_decor(parent, y)
		FactionData.TerrainType.VOLCANIC: _add_volcanic_decor(parent, y)
		FactionData.TerrainType.RIVER: _add_river_flow(parent, y)
		FactionData.TerrainType.WASTELAND: _add_wasteland_decor(parent, y)

func _add_trees(parent: Node3D, y: float, count: int) -> void:
	for i in range(count):
		var a: float = float(i) / float(count) * TAU + 0.3
		var d: float = 0.7 + randf() * 0.5
		var tx := cos(a) * d; var tz := sin(a) * d
		var trunk := _make_cyl_mesh(0.03, 0.06, 0.5, Color(0.3, 0.22, 0.12))
		trunk.position = Vector3(tx, y + 0.25, tz); parent.add_child(trunk)
		var f := MeshInstance3D.new(); var fs := SphereMesh.new()
		fs.radius = 0.18 + randf() * 0.1; fs.height = 0.3 + randf() * 0.1; f.mesh = fs
		f.material_override = _make_mat(Color(0.1 + randf() * 0.08, 0.28 + randf() * 0.18, 0.06))
		f.position = Vector3(tx, y + 0.58, tz); parent.add_child(f)

func _add_mountain_peaks(parent: Node3D, y: float) -> void:
	var pk := _make_cyl_mesh(0.04, 0.35, 0.5, Color(0.5, 0.48, 0.42))
	pk.position = Vector3(0, y + 0.25, 0); parent.add_child(pk)
	var sn := MeshInstance3D.new(); var sm := SphereMesh.new()
	sm.radius = 0.08; sm.height = 0.1; sn.mesh = sm
	sn.material_override = _make_mat(Color(0.9, 0.9, 0.95))
	sn.position = Vector3(0, y + 0.5, 0); parent.add_child(sn)
	for i in range(3):
		var a: float = float(i) * TAU / 3.0 + 0.5
		var r := _make_cyl_mesh(0.02, 0.15 + randf() * 0.1, 0.25 + randf() * 0.15, Color(0.45 + randf() * 0.1, 0.42, 0.38))
		r.position = Vector3(cos(a) * 0.6, y + 0.12, sin(a) * 0.6); parent.add_child(r)

func _add_swamp_pools(parent: Node3D, y: float) -> void:
	for i in range(3):
		var pool := MeshInstance3D.new(); var pc := CylinderMesh.new()
		pc.top_radius = 0.25 + randf() * 0.2; pc.bottom_radius = pc.top_radius
		pc.height = 0.02; pc.radial_segments = 8; pool.mesh = pc
		var pm := StandardMaterial3D.new(); pm.albedo_color = Color(0.12, 0.22, 0.1, 0.7)
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; pool.material_override = pm
		var a := float(i) * TAU / 3.0
		pool.position = Vector3(cos(a) * 0.45, y + 0.01, sin(a) * 0.4); parent.add_child(pool)
		# Bubble marker
		var bubble := MeshInstance3D.new(); var bs := SphereMesh.new()
		bs.radius = 0.03; bs.height = 0.06; bubble.mesh = bs
		var bm := StandardMaterial3D.new(); bm.albedo_color = Color(0.2, 0.35, 0.15, 0.5)
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bubble.material_override = bm
		bubble.position = Vector3(pool.position.x, y + 0.05, pool.position.z)
		bubble.name = "SwampBubble_%d" % i
		parent.add_child(bubble)
		_register_water_node(bubble, "bubble")

func _add_water_edge(parent: Node3D, y: float) -> void:
	var w := _make_box_mesh(Vector3(2.2, 0.02, 0.7), Color(0.12, 0.28, 0.5, 0.55))
	var mat := w.material_override.duplicate()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	w.material_override = mat
	w.position = Vector3(0, y + 0.01, 0.95); parent.add_child(w)
	w.name = "CoastalWater"
	_register_water_node(w, "wave")

func _add_grass_tufts(parent: Node3D, y: float) -> void:
	for i in range(4):
		var t := MeshInstance3D.new(); var sm := SphereMesh.new()
		sm.radius = 0.07; sm.height = 0.09; t.mesh = sm
		t.material_override = _make_mat(Color(0.28, 0.5, 0.18))
		t.scale = Vector3(1, 0.35, 1)
		var a := float(i) * 1.7 + 0.4
		t.position = Vector3(cos(a) * 0.75, y + 0.02, sin(a) * 0.55); parent.add_child(t)

func _add_ruins_decor(parent: Node3D, y: float) -> void:
	# Broken pillars
	for i in range(3):
		var a: float = float(i) * TAU / 3.0 + 0.2
		var d: float = 0.5 + randf() * 0.3
		var pillar := _make_cyl_mesh(0.06, 0.08, 0.3 + randf() * 0.25, Color(0.55, 0.5, 0.58))
		pillar.position = Vector3(cos(a) * d, y + 0.15, sin(a) * d)
		pillar.rotation_degrees.z = randf_range(-12, 12)
		parent.add_child(pillar)
	# Stone arch (tilted)
	var arch := _make_box_mesh(Vector3(0.6, 0.08, 0.08), Color(0.5, 0.48, 0.52))
	arch.position = Vector3(0, y + 0.35, 0)
	arch.rotation_degrees = Vector3(0, 25, 8)
	parent.add_child(arch)
	# Rubble
	for i in range(4):
		var rb := MeshInstance3D.new(); var sm := SphereMesh.new()
		sm.radius = 0.04 + randf() * 0.03; sm.height = sm.radius * 1.5; rb.mesh = sm
		rb.material_override = _make_mat(Color(0.42 + randf() * 0.08, 0.4, 0.44))
		rb.position = Vector3(randf_range(-0.6, 0.6), y + 0.02, randf_range(-0.5, 0.5))
		parent.add_child(rb)

func _add_volcanic_decor(parent: Node3D, y: float) -> void:
	# Volcanic cone
	var cone := _make_cyl_mesh(0.08, 0.35, 0.45, Color(0.35, 0.2, 0.15))
	cone.position = Vector3(0, y + 0.22, 0)
	parent.add_child(cone)
	# Lava crater (emissive)
	var crater := MeshInstance3D.new(); var cm := CylinderMesh.new()
	cm.top_radius = 0.12; cm.bottom_radius = 0.1; cm.height = 0.06; crater.mesh = cm
	var lm := StandardMaterial3D.new(); lm.albedo_color = Color(1.0, 0.35, 0.05)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.emission_enabled = true; lm.emission = Color(1.0, 0.4, 0.1)
	lm.emission_energy_multiplier = 2.5; crater.material_override = lm
	crater.position = Vector3(0, y + 0.46, 0)
	parent.add_child(crater)
	# Lava streams
	for i in range(2):
		var a: float = float(i) * PI + randf() * 0.5
		var stream := _make_box_mesh(Vector3(0.04, 0.02, 0.4), Color(0.9, 0.3, 0.05))
		stream.material_override = _make_emissive_mat(Color(0.9, 0.3, 0.05), Color(1.0, 0.35, 0.05), 1.8)
		stream.position = Vector3(cos(a) * 0.3, y + 0.1, sin(a) * 0.3)
		stream.rotation.y = a; parent.add_child(stream)
	# Dark rocks
	for i in range(3):
		var rock := MeshInstance3D.new(); var rs := SphereMesh.new()
		rs.radius = 0.06 + randf() * 0.04; rs.height = rs.radius * 1.4; rock.mesh = rs
		rock.material_override = _make_mat(Color(0.18, 0.15, 0.12))
		var ra: float = float(i) * TAU / 3.0 + 1.0
		rock.position = Vector3(cos(ra) * 0.7, y + 0.03, sin(ra) * 0.6)
		parent.add_child(rock)

func _add_river_flow(parent: Node3D, y: float) -> void:
	# Water strip
	var water := _make_box_mesh(Vector3(0.5, 0.02, 2.8), Color(0.15, 0.32, 0.55, 0.65))
	var water_mat := water.material_override.duplicate()
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = water_mat
	water.position = Vector3(0, y + 0.01, 0)
	water.name = "RiverWater"
	parent.add_child(water)
	# Banks
	for side in [-1, 1]:
		var bank := _make_box_mesh(Vector3(0.12, 0.04, 2.5), Color(0.35, 0.3, 0.2))
		bank.position = Vector3(0.35 * side, y + 0.02, 0)
		parent.add_child(bank)
	# Flow markers (small spheres that will animate)
	for i in range(3):
		var marker := MeshInstance3D.new(); var sm := SphereMesh.new()
		sm.radius = 0.03; sm.height = 0.06; marker.mesh = sm
		var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.3, 0.55, 0.8, 0.6)
		mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		marker.material_override = mm
		marker.position = Vector3(randf_range(-0.15, 0.15), y + 0.04, randf_range(-1.0, 1.0))
		marker.name = "FlowMarker_%d" % i
		parent.add_child(marker)
		_register_water_node(marker, "flow")

func _add_wasteland_decor(parent: Node3D, y: float) -> void:
	# Dead trees (bare trunks)
	for i in range(2):
		var a: float = float(i) * PI + 0.5
		var d: float = 0.5 + randf() * 0.3
		var trunk := _make_cyl_mesh(0.03, 0.05, 0.4 + randf() * 0.2, Color(0.35, 0.28, 0.2))
		trunk.position = Vector3(cos(a) * d, y + 0.2, sin(a) * d)
		trunk.rotation_degrees.z = randf_range(-15, 15)
		parent.add_child(trunk)
		# Bare branch
		var branch := _make_cyl_mesh(0.01, 0.02, 0.18, Color(0.32, 0.26, 0.18))
		branch.position = Vector3(cos(a) * d + 0.08, y + 0.35, sin(a) * d)
		branch.rotation_degrees.z = 45
		parent.add_child(branch)
	# Bone/skull markers
	for i in range(2):
		var bone := MeshInstance3D.new(); var sm := SphereMesh.new()
		sm.radius = 0.035; sm.height = 0.05; bone.mesh = sm
		bone.material_override = _make_mat(Color(0.82, 0.78, 0.7))
		bone.position = Vector3(randf_range(-0.5, 0.5), y + 0.015, randf_range(-0.4, 0.4))
		bone.scale = Vector3(1.3, 0.6, 1.0)
		parent.add_child(bone)
	# Cracked earth patches
	for i in range(3):
		var crack := _make_box_mesh(Vector3(0.3 + randf() * 0.2, 0.01, 0.02), Color(0.5, 0.42, 0.3))
		crack.position = Vector3(randf_range(-0.5, 0.5), y + 0.005, randf_range(-0.5, 0.5))
		crack.rotation.y = randf() * PI
		parent.add_child(crack)

func _register_water_node(node: MeshInstance3D, type: String) -> void:
	water_anim_nodes.append({"node": node, "type": type, "original_y": node.position.y, "original_z": node.position.z})

func _build_chokepoint_marker(parent: Node3D, y: float) -> void:
	# Gate pillars
	for side in [-1, 1]:
		var pillar := _make_cyl_mesh(0.06, 0.08, 0.6, Color(0.5, 0.45, 0.4))
		pillar.position = Vector3(0.4 * side, y + 0.3, 0)
		parent.add_child(pillar)
	# Arch connecting pillars
	var arch := _make_box_mesh(Vector3(0.9, 0.06, 0.06), Color(0.48, 0.42, 0.38))
	arch.position = Vector3(0, y + 0.62, 0)
	parent.add_child(arch)
	# Emissive gem on top of arch
	var gem := MeshInstance3D.new(); var gs := SphereMesh.new()
	gs.radius = 0.05; gs.height = 0.1; gem.mesh = gs
	var gm := _make_emissive_mat(Color(0.9, 0.2, 0.15), Color(1.0, 0.3, 0.1), 2.0)
	gem.material_override = gm
	gem.position = Vector3(0, y + 0.68, 0)
	parent.add_child(gem)

# ═══════════════ TERRITORY UPDATES ═══════════════
func _update_all_territories() -> void:
	for tile in GameManager.tiles: _update_territory_visual(tile["index"])
	_draw_faction_borders()

func _update_territory_visual(idx: int) -> void:
	if not tile_visuals.has(idx): return
	var vis: Dictionary = tile_visuals[idx]
	var tile: Dictionary = GameManager.tiles[idx]
	var fk: String = _get_tile_faction_key(tile)
	var bc: Color = FACTION_COLORS.get(fk, FACTION_COLORS["none"])
	var terrain = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var tt: Color = TERRAIN_COLORS.get(terrain, Color(0.3, 0.4, 0.25))
	var fc: Color = bc.lerp(tt, 0.2)
	if tile.get("owner_id", -1) >= 0: fc = fc.lightened(0.08)
	# Apply terrain texture if available, otherwise fallback to color
	var terrain_key: String = _terrain_enum_to_key(terrain)
	var terrain_tex: Texture2D = _terrain_textures.get(terrain_key, null)
	if terrain_tex:
		vis["base"].material_override = _make_textured_mat(fc.lightened(0.15), terrain_tex)
	else:
		vis["base"].material_override = _make_mat(fc)
	# Border
	var brc: Color = FLAG_COLORS.get(fk, Color(0.3, 0.3, 0.28))
	if idx == selected_tile: brc = Color(1.0, 1.0, 0.8)
	elif idx == hovered_tile: brc = brc.lightened(0.35)
	vis["border"].material_override = _make_emissive_mat(brc, brc * 0.4, 0.5)
	# Flag
	var flc: Color = FLAG_COLORS.get(fk, Color(0.4, 0.4, 0.4))
	vis["banner"].material_override = _make_emissive_mat(flc, flc * 0.35, 0.35)
	vis["flag_root"].visible = tile["owner_id"] >= 0
	# Update faction crest sprite
	if vis.has("crest_sprite"):
		var cs: Sprite3D = vis["crest_sprite"]
		if tile["owner_id"] >= 0 and _crest_textures.has(fk) and _crest_textures[fk] != null:
			cs.texture = _crest_textures[fk]
			cs.visible = not vis["fog"].visible
		else:
			cs.visible = false
	# Garrison
	var garrison: int = tile.get("garrison", 0)
	if garrison > 0 and not vis["fog"].visible:
		vis["garrison_label"].text = "Lv%d  %d兵" % [tile.get("level", 1), garrison]
	else: vis["garrison_label"].text = ""
	# Settlement update (only rebuild if tile state changed)
	if settlement_nodes.has(idx):
		var new_key: String = _get_settlement_icon_key(tile) + "_%d" % tile.get("level", 1)
		if _settlement_cache.get(idx, "") != new_key:
			_build_settlement(settlement_nodes[idx], tile)
			_settlement_cache[idx] = new_key
	# Army
	var army: Dictionary = GameManager.get_army_at_tile(idx)
	if not army.is_empty() and not vis["fog"].visible:
		vis["army_marker"].visible = true
		var sc: int = GameManager.get_army_soldier_count(army["id"])
		vis["army_label"].text = "%s\n⚔%d" % [army.get("name", "军团"), sc]
		var afk: String = _get_player_faction_key(army["player_id"])
		var ac: Color = FLAG_COLORS.get(afk, Color(0.5, 0.5, 0.5))
		var body_n = vis["army_marker"].get_node_or_null("ArmyBody")
		if body_n: body_n.material_override = _make_mat(ac)
		var ban_n = vis["army_marker"].get_node_or_null("ArmyBanner")
		if ban_n: ban_n.material_override = _make_mat(ac)
	else:
		vis["army_marker"].visible = false; vis["army_label"].text = ""

func _get_tile_faction_key(tile: Dictionary) -> String:
	var oid: int = tile.get("owner_id", -1)
	if oid < 0:
		var nf_id: int = tile.get("neutral_faction_id", -1)
		if nf_id >= 0:
			# Check if this neutral faction is vassalized
			if NeutralFactionAI.is_vassal(nf_id):
				return "vassal"
			return "neutral"
		return "none"
	if oid >= GameManager.players.size(): return "none"
	var fid: int = GameManager.get_player_faction(oid)
	match fid:
		FactionData.FactionID.ORC: return "orc"
		FactionData.FactionID.PIRATE: return "pirate"
		FactionData.FactionID.DARK_ELF: return "dark_elf"
	match tile.get("light_faction", -1):
		FactionData.LightFaction.HUMAN_KINGDOM: return "human"
		FactionData.LightFaction.HIGH_ELVES: return "high_elf"
		FactionData.LightFaction.MAGE_TOWER: return "mage"
	return "neutral"

func _get_player_faction_key(player_id: int) -> String:
	if player_id < 0: return "none"
	var fid: int = GameManager.get_player_faction(player_id)
	match fid:
		FactionData.FactionID.ORC: return "orc"
		FactionData.FactionID.PIRATE: return "pirate"
		FactionData.FactionID.DARK_ELF: return "dark_elf"
	return "neutral"

# ═══════════════ EDGES / ROADS ═══════════════
func _draw_edges() -> void:
	for ti in GameManager.adjacency:
		for ni in GameManager.adjacency[ti]:
			if ni > ti:
				if ti >= GameManager.tiles.size() or ni >= GameManager.tiles.size():
					continue
				var ft: Dictionary = GameManager.tiles[ti]; var tt: Dictionary = GameManager.tiles[ni]
				_create_road_edge(ft["position_3d"], tt["position_3d"], _get_elev(ft), _get_elev(tt))

func _create_road_edge(from: Vector3, to: Vector3, fe: float, te: float) -> void:
	var diff := Vector3(to.x - from.x, 0, to.z - from.z)
	var dist := diff.length()
	if dist < 0.01: return
	var seg_n: int = maxi(int(dist / 0.6), 1)
	var gap: float = 0.15; var angle: float = atan2(diff.x, diff.z)
	var seg_l: float = dist / float(seg_n) * (1.0 - gap)
	for i in range(seg_n):
		var t0: float = (float(i) + gap * 0.5) / float(seg_n)
		var tm: float = t0 + (1.0 - gap) * 0.5 / float(seg_n)
		var rd := _make_box_mesh(Vector3(0.22, 0.025, seg_l), Color(0.32, 0.28, 0.2))
		rd.position = Vector3(lerpf(from.x, to.x, tm), lerpf(fe, te, tm) + TILE_HEIGHT + 0.015, lerpf(from.z, to.z, tm))
		rd.rotation.y = angle; add_child(rd); edge_meshes.append(rd)

# ═══════════════ FACTION BORDERS ═══════════════
func _draw_faction_borders() -> void:
	for b in faction_border_meshes:
		if is_instance_valid(b): b.queue_free()
	faction_border_meshes.clear()
	for ti in GameManager.adjacency:
		if ti >= GameManager.tiles.size(): continue
		var ta: Dictionary = GameManager.tiles[ti]
		var oa: int = ta.get("owner_id", -1)
		if oa < 0: continue
		for ni in GameManager.adjacency[ti]:
			if ni >= GameManager.tiles.size(): continue
			var tb: Dictionary = GameManager.tiles[ni]
			if oa == tb.get("owner_id", -1): continue
			var pa: Vector3 = ta["position_3d"]; var pb: Vector3 = tb["position_3d"]
			var mid := Vector3((pa.x + pb.x) * 0.5, 0, (pa.z + pb.z) * 0.5)
			var d := Vector3(pb.x - pa.x, 0, pb.z - pa.z)
			if d.length() < 0.01: continue
			var perp := Vector3(-d.z, 0, d.x).normalized()
			var my: float = (_get_elev(ta) + _get_elev(tb)) * 0.5 + TILE_HEIGHT + 0.06
			var line := MeshInstance3D.new(); var lm := BoxMesh.new()
			lm.size = Vector3(TILE_RADIUS * 0.8, 0.06, 0.06); line.mesh = lm
			var fk: String = _get_tile_faction_key(ta)
			var bc: Color = FLAG_COLORS.get(fk, Color(0.5, 0.5, 0.5))
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(bc.r, bc.g, bc.b, 0.7)
			bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bmat.emission_enabled = true; bmat.emission = bc * 0.6
			bmat.emission_energy_multiplier = 0.8; line.material_override = bmat
			line.position = Vector3(mid.x, my, mid.z)
			line.rotation.y = atan2(perp.x, perp.z)
			add_child(line); faction_border_meshes.append(line)

# ═══════════════ HIGHLIGHTING ═══════════════
func show_attackable(indices: Array) -> void:
	_clear_highlights()
	for idx in indices:
		_add_highlight_fill(idx, COL_ATTACK_FILL); _add_highlight_ring(idx, COL_HIGHLIGHT_ENEMY)

func show_deployable(indices: Array) -> void:
	_clear_highlights()
	for idx in indices:
		_add_highlight_fill(idx, COL_DEPLOY_FILL); _add_highlight_ring(idx, COL_HIGHLIGHT_FRIENDLY)

func show_mixed_highlights(friendly: Array, enemy: Array, neutral: Array) -> void:
	_clear_highlights()
	for idx in friendly:
		_add_highlight_fill(idx, COL_DEPLOY_FILL); _add_highlight_ring(idx, COL_HIGHLIGHT_FRIENDLY)
	for idx in enemy:
		_add_highlight_fill(idx, COL_ATTACK_FILL); _add_highlight_ring(idx, COL_HIGHLIGHT_ENEMY)
	for idx in neutral: _add_highlight_ring(idx, COL_HIGHLIGHT_NEUTRAL)

func _add_highlight_fill(idx: int, color: Color) -> void:
	if not tile_visuals.has(idx): return
	var pos: Vector3 = GameManager.tiles[idx]["position_3d"]
	var el: float = tile_visuals[idx].get("elevation", 0.0)
	var fill := MeshInstance3D.new(); var fm := CylinderMesh.new()
	fm.top_radius = TILE_RADIUS * 0.95; fm.bottom_radius = TILE_RADIUS * 0.95
	fm.height = 0.03; fm.radial_segments = 6; fill.mesh = fm
	var fmat := StandardMaterial3D.new(); fmat.albedo_color = color
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.material_override = fmat
	fill.position = Vector3(pos.x, el + TILE_HEIGHT + 0.04, pos.z)
	add_child(fill); highlight_rings[-1000 - idx] = fill

func _add_highlight_ring(idx: int, color: Color) -> void:
	if not tile_visuals.has(idx): return
	var pos: Vector3 = GameManager.tiles[idx]["position_3d"]
	var el: float = tile_visuals[idx].get("elevation", 0.0)
	var ring := MeshInstance3D.new(); var tc := CylinderMesh.new()
	tc.top_radius = TILE_RADIUS * 1.08; tc.bottom_radius = TILE_RADIUS * 1.08
	tc.height = 0.05; tc.radial_segments = 6; ring.mesh = tc
	var rm := StandardMaterial3D.new(); rm.albedo_color = color
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled = true; rm.emission = color; rm.emission_energy_multiplier = 1.3
	ring.material_override = rm
	ring.position = Vector3(pos.x, el + TILE_HEIGHT + 0.035, pos.z)
	add_child(ring); highlight_rings[idx] = ring

func _clear_highlights() -> void:
	for idx in highlight_rings:
		if is_instance_valid(highlight_rings[idx]): highlight_rings[idx].queue_free()
	highlight_rings.clear()

# ═══════════════ SELECTION PULSE RING ═══════════════
func _start_pulse_ring(idx: int) -> void:
	_clear_pulse_ring()
	if not tile_visuals.has(idx): return
	var pos: Vector3 = GameManager.tiles[idx]["position_3d"]
	var el: float = tile_visuals[idx].get("elevation", 0.0)
	_pulse_ring = MeshInstance3D.new(); var tc := CylinderMesh.new()
	tc.top_radius = TILE_RADIUS * 1.1; tc.bottom_radius = TILE_RADIUS * 1.1
	tc.height = 0.04; tc.radial_segments = 6; _pulse_ring.mesh = tc
	var pm := StandardMaterial3D.new(); pm.albedo_color = Color(1.0, 1.0, 0.8, 0.5)
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; pm.emission_enabled = true
	pm.emission = Color(1.0, 0.95, 0.7); pm.emission_energy_multiplier = 1.0
	_pulse_ring.material_override = pm
	_pulse_ring.position = Vector3(pos.x, el + TILE_HEIGHT + 0.05, pos.z)
	add_child(_pulse_ring)
	_pulse_tween = create_tween(); _pulse_tween.set_loops()
	_pulse_tween.tween_property(_pulse_ring, "scale", Vector3(1.08, 1, 1.08), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_pulse_ring, "scale", Vector3(0.95, 1, 0.95), 0.6).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _clear_pulse_ring() -> void:
	if _pulse_tween and _pulse_tween.is_valid(): _pulse_tween.kill()
	_pulse_tween = null
	if is_instance_valid(_pulse_ring): _pulse_ring.queue_free()
	_pulse_ring = null

# ═══════════════ PATH PREVIEW ═══════════════
func _process_hover_path() -> void:
	if hovered_tile < 0 or selected_tile < 0 or GameManager.selected_army_id < 0:
		_clear_path_preview(); return
	var dep: Array = GameManager.get_army_deployable_tiles(GameManager.selected_army_id)
	var atk: Array = GameManager.get_army_attackable_tiles(GameManager.selected_army_id)
	if not dep.has(hovered_tile) and not atk.has(hovered_tile):
		_clear_path_preview(); return
	_draw_path_preview(selected_tile, hovered_tile)

func _draw_path_preview(fi: int, ti: int) -> void:
	_clear_path_preview()
	if fi < 0 or ti < 0 or fi >= GameManager.tiles.size() or ti >= GameManager.tiles.size(): return
	var fp: Vector3 = GameManager.tiles[fi]["position_3d"]
	var tp: Vector3 = GameManager.tiles[ti]["position_3d"]
	var fe: float = _get_elev(GameManager.tiles[fi]); var te: float = _get_elev(GameManager.tiles[ti])
	var dist := Vector3(tp.x - fp.x, 0, tp.z - fp.z).length()
	if dist < 0.1: return
	var dn: int = maxi(int(dist / 0.5), 3)
	for i in range(dn):
		var t: float = float(i + 1) / float(dn + 1)
		var dot := MeshInstance3D.new(); var sm := SphereMesh.new()
		sm.radius = 0.06; sm.height = 0.12; dot.mesh = sm
		var dm := StandardMaterial3D.new(); dm.albedo_color = Color(1.0, 0.9, 0.3, 0.7)
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; dm.emission_enabled = true
		dm.emission = Color(1.0, 0.85, 0.2); dm.emission_energy_multiplier = 0.8
		dot.material_override = dm
		dot.position = Vector3(lerpf(fp.x, tp.x, t), lerpf(fe, te, t) + TILE_HEIGHT + 0.15, lerpf(fp.z, tp.z, t))
		add_child(dot); path_preview_meshes.append(dot)

func _clear_path_preview() -> void:
	for m in path_preview_meshes:
		if is_instance_valid(m): m.queue_free()
	path_preview_meshes.clear()

# ═══════════════ SELECTION & CLICK ═══════════════
func _on_tile_input(_cn: Node, event: InputEvent, _p: Vector3, _n: Vector3, _si: int, tile_index: int) -> void:
	if not event is InputEventMouseButton: return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var now: float = Time.get_ticks_msec() / 1000.0
		if tile_index == _last_click_tile and (now - _last_click_time) < DOUBLE_CLICK_TIME:
			focus_on_tile(tile_index); _last_click_tile = -1; return
		_last_click_tile = tile_index; _last_click_time = now
		# Shift+click: show attack route preview
		if mb.shift_pressed and selected_tile >= 0 and tile_index != selected_tile:
			show_attack_route(selected_tile, tile_index)
			return
		_on_tile_clicked(tile_index)

func _on_tile_hover_enter(tile_index: int) -> void:
	var oh: int = hovered_tile; hovered_tile = tile_index
	if oh >= 0: _update_territory_visual(oh); _animate_tile_hover(oh, false)
	_update_territory_visual(tile_index); _animate_tile_hover(tile_index, true)

func _on_tile_hover_exit(tile_index: int) -> void:
	if hovered_tile == tile_index:
		hovered_tile = -1; _update_territory_visual(tile_index)
		_animate_tile_hover(tile_index, false)

func _animate_tile_hover(idx: int, entering: bool) -> void:
	if not tile_visuals.has(idx): return
	var vis: Dictionary = tile_visuals[idx]
	var be: float = vis.get("elevation", 0.0)
	var ty: float = be + (0.05 if entering else 0.0)
	if _hover_tween and _hover_tween.is_valid(): _hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_hover_tween.tween_property(vis["root"], "position:y", ty, 0.15)

func _on_tile_clicked(tile_index: int) -> void:
	var old_sel: int = selected_tile
	var pid: int = GameManager.get_human_player_id()
	var tile: Dictionary = GameManager.tiles[tile_index]
	if GameManager.selected_army_id >= 0:
		var army: Dictionary = GameManager.get_army(GameManager.selected_army_id)
		if not army.is_empty() and army["player_id"] == pid:
			var dep: Array = GameManager.get_army_deployable_tiles(GameManager.selected_army_id)
			if dep.has(tile_index):
				GameManager.action_deploy_army(GameManager.selected_army_id, tile_index)
				_deselect_tile(); return
			var atk: Array = GameManager.get_army_attackable_tiles(GameManager.selected_army_id)
			if atk.has(tile_index):
				GameManager.action_attack_with_army(GameManager.selected_army_id, tile_index)
				_deselect_tile(); return
	if selected_tile == tile_index: _deselect_tile(); return
	selected_tile = tile_index
	if old_sel >= 0: _update_territory_visual(old_sel)
	_update_territory_visual(tile_index); _clear_highlights()
	_start_pulse_ring(tile_index)
	if tile["owner_id"] == pid:
		var ah: Dictionary = GameManager.get_army_at_tile_for_player(tile_index, pid)
		if not ah.is_empty():
			GameManager.select_army(ah["id"])
			for dt in GameManager.get_army_deployable_tiles(ah["id"]):
				_add_highlight_fill(dt, COL_DEPLOY_FILL)
				_add_highlight_ring(dt, Color(0.2, 0.9, 0.3, 0.6))
			for at in GameManager.get_army_attackable_tiles(ah["id"]):
				_add_highlight_fill(at, COL_ATTACK_FILL)
				_add_highlight_ring(at, Color(0.9, 0.2, 0.2, 0.6))
		else: GameManager.deselect_army()
	else: GameManager.deselect_army()
	EventBus.territory_selected.emit(tile_index)

func _deselect_tile() -> void:
	var old: int = selected_tile; selected_tile = -1
	_clear_highlights(); _clear_pulse_ring(); _clear_path_preview()
	clear_attack_route()
	GameManager.deselect_army()
	if old >= 0: _update_territory_visual(old)
	if EventBus.has_signal("territory_deselected"): EventBus.territory_deselected.emit()

func get_selected_tile() -> int:
	return selected_tile

# ═══════════════ ATTACK ROUTE PREVIEW ═══════════════
func show_attack_route(from_idx: int, to_idx: int) -> void:
	clear_attack_route()
	var route: Array = GameManager.calculate_attack_route(from_idx, to_idx)
	if route.is_empty():
		return
	var full_path: Array = [from_idx] + route
	var total_cost: float = 0.0
	var chokepoint_count: int = 0
	# Draw route segments
	for i in range(full_path.size() - 1):
		var fi: int = full_path[i]; var ti: int = full_path[i + 1]
		if fi >= GameManager.tiles.size() or ti >= GameManager.tiles.size():
			continue
		var ft: Dictionary = GameManager.tiles[fi]; var tt: Dictionary = GameManager.tiles[ti]
		var fp: Vector3 = ft["position_3d"]; var tp: Vector3 = tt["position_3d"]
		var fe: float = _get_elev(ft); var te: float = _get_elev(tt)
		# Color based on ownership
		var color: Color = Color(0.2, 0.9, 0.3, 0.6)  # Green = own territory
		if tt.get("owner_id", -1) >= 0 and tt["owner_id"] != GameManager.get_human_player_id():
			color = Color(0.9, 0.2, 0.15, 0.6)  # Red = enemy
		elif tt.get("owner_id", -1) < 0:
			color = Color(0.9, 0.8, 0.2, 0.6)  # Gold = neutral
		# Dotted path segments
		var dist := Vector3(tp.x - fp.x, 0, tp.z - fp.z).length()
		var dots: int = maxi(int(dist / 0.4), 2)
		for d in range(dots):
			var t: float = float(d + 1) / float(dots + 1)
			var dot := MeshInstance3D.new(); var sm := SphereMesh.new()
			sm.radius = 0.05; sm.height = 0.1; dot.mesh = sm
			var dm := StandardMaterial3D.new(); dm.albedo_color = color
			dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dm.emission_enabled = true; dm.emission = color
			dm.emission_energy_multiplier = 1.0
			dot.material_override = dm
			dot.position = Vector3(
				lerpf(fp.x, tp.x, t),
				lerpf(fe, te, t) + TILE_HEIGHT + 0.2,
				lerpf(fp.z, tp.z, t))
			add_child(dot); attack_route_meshes.append(dot)
		# Waypoint ring at destination tile
		var ring_color: Color = Color(0.9, 0.6, 0.1, 0.5)
		if tt.get("is_chokepoint", false):
			ring_color = Color(1.0, 0.4, 0.1, 0.7)
			chokepoint_count += 1
		if i == full_path.size() - 2:  # Final target
			ring_color = Color(0.9, 0.15, 0.1, 0.7)
		var ring := MeshInstance3D.new(); var rc := CylinderMesh.new()
		rc.top_radius = TILE_RADIUS * 0.5; rc.bottom_radius = TILE_RADIUS * 0.5
		rc.height = 0.03; rc.radial_segments = 6; ring.mesh = rc
		var rm := StandardMaterial3D.new(); rm.albedo_color = ring_color
		rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rm.emission_enabled = true; rm.emission = ring_color
		rm.emission_energy_multiplier = 1.2
		ring.material_override = rm
		ring.position = Vector3(tp.x, te + TILE_HEIGHT + 0.06, tp.z)
		add_child(ring); attack_route_meshes.append(ring)
		# Track costs
		var terrain_type: int = tt.get("terrain", FactionData.TerrainType.PLAINS)
		var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
		total_cost += float(terrain_data.get("move_cost", 1))
	# Summary label at start
	var start_tile: Dictionary = GameManager.tiles[from_idx]
	var sp: Vector3 = start_tile["position_3d"]; var se: float = _get_elev(start_tile)
	var summary_text: String = "路线: %d步 | AP%.0f" % [route.size(), total_cost]
	if chokepoint_count > 0:
		summary_text += " | 关隘×%d" % chokepoint_count
	var slabel := _make_label3d(summary_text, 24, Vector3(0, 0, 0), Color(1.0, 0.9, 0.3, 1.0))
	slabel.position = Vector3(sp.x, se + TILE_HEIGHT + 2.5, sp.z)
	add_child(slabel); attack_route_meshes.append(slabel)

func clear_attack_route() -> void:
	for m in attack_route_meshes:
		if is_instance_valid(m): m.queue_free()
	attack_route_meshes.clear()

# ═══════════════ FOG OF WAR ═══════════════
func _mark_fog_dirty(tile_indices: Array) -> void:
	for idx in tile_indices:
		if idx not in _fog_dirty_tiles:
			_fog_dirty_tiles.append(idx)
		# Also mark neighbors dirty
		if GameManager.adjacency.has(idx):
			for n in GameManager.adjacency[idx]:
				if n not in _fog_dirty_tiles:
					_fog_dirty_tiles.append(n)

func _update_fog() -> void:
	var pid: int = 0
	if not GameManager.players.is_empty(): pid = GameManager.get_human_player_id()
	var tiles_to_update: Array
	if _fog_dirty_tiles.is_empty():
		# Full update: all tiles
		tiles_to_update = tile_visuals.keys()
	else:
		tiles_to_update = _fog_dirty_tiles
		_fog_dirty_tiles = []
	for idx in tiles_to_update:
		if not tile_visuals.has(idx): continue
		var vis: Dictionary = tile_visuals[idx]
		var rev: bool = GameManager.is_revealed_for(idx, pid)
		vis["fog"].visible = not rev
		if not rev:
			var edge: bool = _has_revealed_neighbor(idx, pid)
			vis["fog"].material_override = _fog_edge_mat if edge else _fog_mat
		vis["label"].visible = rev; vis["garrison_label"].visible = rev
		vis["flag_root"].visible = rev and GameManager.tiles[idx].get("owner_id", -1) >= 0

func _has_revealed_neighbor(idx: int, pid: int) -> bool:
	if not GameManager.adjacency.has(idx): return false
	for n in GameManager.adjacency[idx]:
		if GameManager.is_revealed_for(n, pid): return true
	return false

# ═══════════════ SIGNAL HANDLERS ═══════════════
func _on_tile_captured(_pid: int, ti: int) -> void:
	_update_territory_visual(ti)
	# Update neighbors for border visuals
	if GameManager.adjacency.has(ti):
		for n in GameManager.adjacency[ti]:
			_update_territory_visual(n)
	_mark_fog_dirty([ti]); _update_fog(); _draw_faction_borders()
func _on_fog_updated(_pid: int) -> void:
	_fog_dirty_tiles.clear()  # Full fog rebuild
	_update_fog()
func _on_turn_started(_pid: int) -> void:
	_clear_highlights(); _deselect_tile()
	if tile_visuals.is_empty() and not GameManager.tiles.is_empty(): _build_board()
	else:
		_update_all_territories()
		_fog_dirty_tiles.clear()  # Force full fog rebuild on turn start
		_update_fog()
func _on_game_over(_wid: int) -> void:
	_clear_highlights()
func _on_army_changed(_pid: int, _cnt: int) -> void:
	_update_all_territories()
func _on_army_deployed(_pid: int, _aid: int, from_tile: int, to_tile: int) -> void:
	_animate_army_move(from_tile, to_tile)
	_update_territory_visual(from_tile); _update_territory_visual(to_tile)
func _on_army_created_or_disbanded(_pid: int, _aid: int, _extra = null) -> void:
	_update_all_territories()

# ═══════════════ ARMY MOVEMENT ANIMATION ═══════════════
func _animate_army_move(fi: int, ti: int) -> void:
	if not tile_visuals.has(fi) or not tile_visuals.has(ti): return
	var marker: Node3D = tile_visuals[ti]["army_marker"]
	if not marker.visible: return
	var from_root: Node3D = tile_visuals[fi]["root"]
	var to_root: Node3D = tile_visuals[ti]["root"]
	var lp: Vector3 = marker.position
	var start_local := to_root.to_local(from_root.global_position + lp)
	marker.position = start_local
	var tw := create_tween()
	tw.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(marker, "position", lp, 0.5)

# ═══════════════ CAMERA FOCUS ═══════════════
func focus_on_tile(tile_index: int) -> void:
	if tile_index < 0 or tile_index >= GameManager.tiles.size(): return
	var p: Vector3 = GameManager.tiles[tile_index]["position_3d"]
	camera_target_pos = Vector3(p.x, 0.0, p.z)

func _process_water_animation(_delta: float) -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	for entry in water_anim_nodes:
		var node: MeshInstance3D = entry["node"]
		if not is_instance_valid(node): continue
		var original_y: float = entry["original_y"]
		match entry["type"]:
			"wave":  # Coastal bob
				node.position.y = original_y + sin(t * 1.8) * 0.015
			"bubble":  # Swamp bubble rise
				var cycle: float = fmod(t, 3.5) / 3.5
				node.position.y = original_y + sin(cycle * PI) * 0.05
				node.scale = Vector3.ONE * (1.0 - cycle * 0.3)
			"flow":  # River flow drift
				var original_z: float = entry["original_z"]
				node.position.z = fmod(original_z + t * 0.1, 1.2) - 0.6

# ═══════════════ UTILITY ═══════════════
func _trim_material_cache() -> void:
	if _material_cache.size() > _MATERIAL_CACHE_MAX:
		# Evict oldest half of entries
		var keys: Array = _material_cache.keys()
		var to_remove: int = _material_cache.size() / 2
		for i in range(to_remove):
			_material_cache.erase(keys[i])

func _make_mat(color: Color) -> StandardMaterial3D:
	var key := "%s" % color
	if _material_cache.has(key): return _material_cache[key]
	if _material_cache.size() >= _MATERIAL_CACHE_MAX: _trim_material_cache()
	var m := StandardMaterial3D.new(); m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material_cache[key] = m; return m

func _make_textured_mat(color: Color, texture: Texture2D) -> StandardMaterial3D:
	if texture == null:
		return _make_mat(color)
	var key := "tex_%s_%s" % [color, texture.resource_path]
	if _material_cache.has(key): return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = texture
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material_cache[key] = m; return m

func _make_emissive_mat(color: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var key := "e_%s_%s_%.2f" % [color, emission, energy]
	if _material_cache.has(key): return _material_cache[key]
	var m := StandardMaterial3D.new(); m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true; m.emission = emission
	m.emission_energy_multiplier = energy
	_material_cache[key] = m; return m

func _make_label3d(text: String, size: int, pos: Vector3, col: Color = Color(1,1,1,0.95)) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font_size = size; l.pixel_size = 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true
	l.modulate = col; l.outline_modulate = Color(0, 0, 0, 0.9); l.outline_size = 10
	l.position = pos; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; return l

func _terrain_enum_to_key(terrain_type: int) -> String:
	match terrain_type:
		FactionData.TerrainType.PLAINS: return "plains"
		FactionData.TerrainType.FOREST: return "forest"
		FactionData.TerrainType.MOUNTAIN: return "mountain"
		FactionData.TerrainType.SWAMP: return "swamp"
		FactionData.TerrainType.COASTAL: return "coastal"
		FactionData.TerrainType.FORTRESS_WALL: return "fortress_wall"
		FactionData.TerrainType.RIVER: return "river"
		FactionData.TerrainType.RUINS: return "ruins"
		FactionData.TerrainType.WASTELAND: return "wasteland"
		FactionData.TerrainType.VOLCANIC: return "volcanic"
	return "plains"

func _make_cyl_mesh(tr: float, br: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new()
	cm.top_radius = tr; cm.bottom_radius = br; cm.height = h
	mi.mesh = cm; mi.material_override = _make_mat(c); return mi

func _make_box_mesh(s: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = s
	mi.mesh = bm; mi.material_override = _make_mat(c); return mi

# ═══════════════ MAP BOUNDARY & EDGE DECORATIONS ═══════════════
func _build_map_boundary() -> void:
	## Create a dark ocean/void border around the playable map area.
	## This frames the hex grid and prevents the ground plane edges from looking bare.
	var center := Vector3(9.0, GROUND_Y - 0.12, -7.0)
	var half_w: float = 28.0
	var half_h: float = 22.0
	var border_w: float = 12.0
	var border_mat := StandardMaterial3D.new()
	border_mat.albedo_color = Color(0.05, 0.07, 0.15, 0.75)
	border_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Four border strips (top, bottom, left, right)
	var strips: Array = [
		# [position, size] for each border strip
		[Vector3(center.x, center.y, center.z - half_h - border_w * 0.5), Vector2(half_w * 2 + border_w * 2, border_w)],  # top
		[Vector3(center.x, center.y, center.z + half_h + border_w * 0.5), Vector2(half_w * 2 + border_w * 2, border_w)],  # bottom
		[Vector3(center.x - half_w - border_w * 0.5, center.y, center.z), Vector2(border_w, half_h * 2)],  # left
		[Vector3(center.x + half_w + border_w * 0.5, center.y, center.z), Vector2(border_w, half_h * 2)],  # right
	]
	for strip_data in strips:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = strip_data[1]
		mi.mesh = pm
		mi.material_override = border_mat
		mi.position = strip_data[0]
		mi.name = "MapBorder"
		add_child(mi)
	# Subtle gradient fog at edges using a ring of small planes
	_build_edge_fog(center, half_w, half_h)

func _build_edge_fog(center: Vector3, half_w: float, half_h: float) -> void:
	## Place subtle fog planes along the map edges for a smooth visual transition.
	var fog_mat := StandardMaterial3D.new()
	fog_mat.albedo_color = Color(0.06, 0.08, 0.18, 0.4)
	fog_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var fog_depth: float = 5.0
	# Top and bottom edge fog
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(half_w * 2, fog_depth)
		mi.mesh = pm
		mi.material_override = fog_mat
		mi.position = Vector3(center.x, center.y + 0.01, center.z + side * (half_h - fog_depth * 0.3))
		mi.name = "EdgeFog"
		add_child(mi)
	# Left and right edge fog
	for side in [-1.0, 1.0]:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(fog_depth, half_h * 2)
		mi.mesh = pm
		mi.material_override = fog_mat
		mi.position = Vector3(center.x + side * (half_w - fog_depth * 0.3), center.y + 0.01, center.z)
		mi.name = "EdgeFog"
		add_child(mi)

# ═══════════════ INTER-TILE DECORATIONS ═══════════════
func _build_inter_tile_decorations() -> void:
	## Place small decorative elements between tiles for visual richness.
	## Uses procedural placement based on terrain types of adjacent tiles.
	if GameManager.tiles.is_empty():
		return
	var deco_count: int = 0
	var max_decos: int = 80  # Cap for performance
	for ti in GameManager.adjacency:
		if deco_count >= max_decos:
			break
		if ti >= GameManager.tiles.size():
			continue
		var ta: Dictionary = GameManager.tiles[ti]
		for ni in GameManager.adjacency[ti]:
			if ni <= ti or ni >= GameManager.tiles.size():
				continue
			if deco_count >= max_decos:
				break
			# Only place decorations along ~30% of edges for natural feel
			if randf() > 0.30:
				continue
			var tb: Dictionary = GameManager.tiles[ni]
			var pa: Vector3 = ta["position_3d"]
			var pb: Vector3 = tb["position_3d"]
			var mid := Vector3((pa.x + pb.x) * 0.5, TILE_HEIGHT + 0.01, (pa.z + pb.z) * 0.5)
			# Jitter position off the road centerline
			var perp := Vector3(-(pb.z - pa.z), 0, pb.x - pa.x).normalized()
			mid += perp * randf_range(-0.4, 0.4)
			var terrain_a: int = ta.get("terrain", FactionData.TerrainType.PLAINS)
			var terrain_b: int = tb.get("terrain", FactionData.TerrainType.PLAINS)
			_place_edge_decoration(mid, terrain_a, terrain_b)
			deco_count += 1

func _place_edge_decoration(pos: Vector3, terrain_a: int, terrain_b: int) -> void:
	## Place a small decoration appropriate for the terrain transition.
	var dominant: int = terrain_a if randf() < 0.6 else terrain_b
	match dominant:
		FactionData.TerrainType.FOREST:
			# Small bush/shrub
			var bush := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.08 + randf() * 0.06
			sm.height = sm.radius * 1.5
			bush.mesh = sm
			bush.material_override = _make_mat(Color(0.15 + randf() * 0.08, 0.3 + randf() * 0.12, 0.08))
			bush.position = pos
			bush.name = "EdgeDeco"
			add_child(bush)
		FactionData.TerrainType.MOUNTAIN, FactionData.TerrainType.VOLCANIC:
			# Small rock
			var rock := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.05 + randf() * 0.04
			sm.height = sm.radius * 1.2
			rock.mesh = sm
			rock.material_override = _make_mat(Color(0.4 + randf() * 0.1, 0.38, 0.35))
			rock.position = pos
			rock.scale = Vector3(1.0 + randf() * 0.4, 0.5 + randf() * 0.3, 1.0 + randf() * 0.3)
			rock.name = "EdgeDeco"
			add_child(rock)
		FactionData.TerrainType.WASTELAND, FactionData.TerrainType.RUINS:
			# Bone/debris
			var debris := _make_box_mesh(
				Vector3(0.06 + randf() * 0.04, 0.02, 0.02),
				Color(0.6 + randf() * 0.15, 0.55, 0.45))
			debris.position = pos
			debris.rotation.y = randf() * TAU
			debris.name = "EdgeDeco"
			add_child(debris)
		FactionData.TerrainType.SWAMP, FactionData.TerrainType.RIVER, FactionData.TerrainType.COASTAL:
			# Small puddle/water patch
			var puddle := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.1 + randf() * 0.08
			cm.bottom_radius = cm.top_radius
			cm.height = 0.01
			cm.radial_segments = 8
			puddle.mesh = cm
			var pm := StandardMaterial3D.new()
			pm.albedo_color = Color(0.1, 0.25, 0.45, 0.5)
			pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			puddle.material_override = pm
			puddle.position = pos
			puddle.name = "EdgeDeco"
			add_child(puddle)
		_:
			# Grass tuft for plains and generic terrain
			var tuft := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.04 + randf() * 0.03
			sm.height = sm.radius * 1.4
			tuft.mesh = sm
			tuft.material_override = _make_mat(Color(0.3 + randf() * 0.1, 0.45 + randf() * 0.1, 0.2))
			tuft.position = pos
			tuft.scale = Vector3(1, 0.4, 1)
			tuft.name = "EdgeDeco"
			add_child(tuft)

# ═══════════════ AMBIENT PARTICLES ═══════════════
func _setup_ambient_particles() -> void:
	for i in range(25):
		var p := MeshInstance3D.new(); var sm := SphereMesh.new()
		sm.radius = 0.025 + randf() * 0.02; sm.height = sm.radius * 2; p.mesh = sm
		var pm := StandardMaterial3D.new(); pm.albedo_color = Color(0.85, 0.6, 0.25, 0.35)
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; p.material_override = pm
		p.position = Vector3(randf_range(-5, 25), randf_range(0.5, 4), randf_range(-25, 5))
		p.name = "AmbientParticle_%d" % i; add_child(p)
	_animate_particles()

func _animate_particles() -> void:
	for ch in get_children():
		if ch.name.begins_with("AmbientParticle_"):
			var tw := create_tween(); tw.set_loops()
			var dur: float = randf_range(3.0, 8.0)
			var ty: float = ch.position.y + randf_range(0.5, 1.5)
			var dx: float = randf_range(-1.0, 1.0)
			tw.tween_property(ch, "position:y", ty, dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(ch, "position:x", ch.position.x + dx, dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.tween_property(ch, "position:y", ch.position.y, dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(ch, "position:x", ch.position.x, dur).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

# ═══════════════ MINIMAP ═══════════════
var minimap_container: SubViewportContainer
var minimap_viewport: SubViewport
var minimap_camera: Camera3D

func setup_minimap(parent_control: Control) -> void:
	minimap_container = SubViewportContainer.new()
	minimap_container.name = "MinimapContainer"
	minimap_container.custom_minimum_size = Vector2(180, 140)
	minimap_container.stretch = true; parent_control.add_child(minimap_container)
	minimap_viewport = SubViewport.new(); minimap_viewport.name = "MinimapViewport"
	minimap_viewport.size = Vector2i(360, 280)
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	minimap_viewport.transparent_bg = false; minimap_viewport.world_3d = get_viewport().world_3d; minimap_container.add_child(minimap_viewport)
	minimap_camera = Camera3D.new(); minimap_camera.name = "MinimapCamera"
	minimap_camera.position = Vector3(9, 40, -8)
	minimap_camera.rotation_degrees = Vector3(-90, 0, 0)
	minimap_camera.fov = 60; minimap_camera.current = true
	minimap_viewport.add_child(minimap_camera)

# ═══════════════ TILE PULSE ANIMATION ═══════════════
func pulse_tile(idx: int, color: Color, duration: float = 0.6) -> void:
	if not tile_visuals.has(idx): return
	var bmi: MeshInstance3D = tile_visuals[idx]["base"]
	var orig: StandardMaterial3D = bmi.material_override
	var pm := _make_emissive_mat(color, color, 2.0)
	bmi.material_override = pm
	var tw := create_tween()
	tw.tween_callback(func(): bmi.material_override = orig).set_delay(duration)
