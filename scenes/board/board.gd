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
var _deco_textures: Dictionary = {}  # Extracted decoration sprites by terrain/type
var _military_icon_tex: Texture2D = null  # Military army icon for 3D markers

func _load_map_assets() -> void:
	# Map background — prefer v3 hand-painted, fall back to others
	_map_bg_texture = _safe_tex_load("res://assets/map/backgrounds/map_bg_v3.png")
	if not _map_bg_texture:
		_map_bg_texture = _safe_tex_load("res://assets/map/map_background.png")
	# Load alternative backgrounds for faction-themed maps
	for bg_name in ["map_bg_v3", "map_pixel_hd", "map_hd_v1", "map_hd_tw_v1", "map_hd_mj_v0", "map_hd_mj_v1", "map_hd_mj_v2", "map_hd_mj_v3"]:
		var tex: Texture2D = _safe_tex_load("res://assets/map/backgrounds/%s.png" % bg_name)
		if tex:
			_map_bg_variants.append(tex)
	# Select faction-themed background if available
	_select_faction_background()
	# Map decoration sprites
	_map_decoration_tex = _safe_tex_load("res://assets/map/map_decorations/map_sprites.png")
	# Individual decoration sprites for inter-tile placement
	for dname in ["trees", "castle", "dock", "mountains", "village", "crystal", "bridge", "skull_cave", "ruins_arch", "watchtower"]:
		_deco_textures[dname] = _safe_tex_load("res://assets/map/decorations/%s.png" % dname)
	# Military icon for army markers
	_military_icon_tex = _safe_tex_load("res://assets/map/actions/military_army.png")
	# Terrain textures — load directly from v3
	for tname in ["plains","forest","mountain","swamp","coastal","fortress_wall","river","ruins","wasteland","volcanic"]:
		_terrain_textures[tname] = _safe_tex_load("res://assets/map/terrain_v3/terrain_%s.png" % tname)
	# Settlement/building icons — load directly from v3
	for sname in ["fortress","village","watchtower","trading_post","beacon","ruins","port","gate","bandit","crystal_mine","horse_ranch","gunpowder","shadow_rift","stronghold","event"]:
		_settlement_textures[sname] = _safe_tex_load("res://assets/map/settlements_v3/settlement_%s.png" % sname)
	# Faction crests — load directly from crests_hd
	for fname in ["orc","pirate","dark_elf","human","high_elf","mage","bandit","neutral"]:
		_crest_textures[fname] = _safe_tex_load("res://assets/map/crests_hd/crest_%s.png" % fname)
	# Bandit/neutral fallbacks if still missing
	if not _crest_textures.get("bandit"):
		_crest_textures["bandit"] = _crest_textures.get("orc")
	if not _crest_textures.has("neutral"):
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
## Per-army march route meshes: { army_id: int -> Array[MeshInstance3D] }
## Using a Dictionary prevents multi-army marches from clearing each other's paths.
var march_route_meshes: Dictionary = {}
var supply_line_meshes: Array = []  # Supply route dot visuals
var supply_depot_markers: Array = []  # 3D depot crate markers
var isolated_overlay_meshes: Array = []  # Red overlay for isolated tiles
var settlement_nodes: Dictionary = {}
var _settlement_cache: Dictionary = {}  # idx -> last icon_key to avoid redundant rebuilds
var _upgrade_flash_tiles: Dictionary = {}  # idx -> true, tiles currently playing upgrade flash
# ── Material cache ──
var _material_cache: Dictionary = {}
const _MATERIAL_CACHE_MAX: int = 512
var _fog_shader: Shader = null
var _fog_mat: ShaderMaterial = null   # Shared base; per-tile instances created in _build_territory
# ── Dirty fog tracking ──
var _fog_dirty_tiles: Array = []
var _fog_tweens: Dictionary = {}  # idx -> Tween for reveal/conceal transitions
# ── Selection state ──
var selected_tile: int = -1
var hovered_tile: int = -1
var _last_click_tile: int = -1
var _last_click_time: float = 0.0
var _hover_tween: Tween = null
var _hover_glow: MeshInstance3D = null
var _hover_glow_mat: StandardMaterial3D = null
var _pulse_tween: Tween = null
var _pulse_ring: MeshInstance3D = null
# ── Garrison visual state ──
## Per-army garrison shield meshes: { army_id: int -> MeshInstance3D }
var _garrison_shield_meshes: Dictionary = {}
## Per-army marching arrow meshes: { army_id: int -> MeshInstance3D }
var _marching_arrow_meshes: Dictionary = {}
# ── Input mode & undo state ──
var _input_mode: String = "normal"  # "normal", "attack", "deploy"
var _undo_stack: Array = []  # [{type, army_id, from_tile, to_tile, ap_cost}]
const _UNDO_MAX: int = 5
# ── Camera state ──
var camera: Camera3D
var camera_pivot: Node3D
var camera_target_pos: Vector3 = Vector3(9.0, 0.0, -8.0)
var camera_zoom: float = 1.0
var _camera_zoom_target: float = 1.0
const ZOOM_MIN: float = 0.6
const ZOOM_MAX: float = 2.0
const ZOOM_SPEED: float = 0.1
const ZOOM_LERP_SPEED: float = 8.0
const PAN_SPEED: float = 15.0
const EDGE_SCROLL_MARGIN: float = 30.0
const EDGE_SCROLL_SPEED: float = 8.0
const CAM_LERP_SPEED: float = 6.0
const DOUBLE_CLICK_TIME: float = 0.35
const TILE_RADIUS: float = 1.8
const TILE_HEIGHT: float = 0.18
const GROUND_Y: float = -0.1

const FACTION_COLORS := {
	"orc": Color(0.85, 0.25, 0.2), "pirate": Color(0.2, 0.38, 0.72),
	"dark_elf": Color(0.52, 0.18, 0.72), "human": Color(0.85, 0.72, 0.25),
	"high_elf": Color(0.22, 0.65, 0.32), "mage": Color(0.22, 0.38, 0.82),
	"neutral": Color(0.52, 0.52, 0.42), "vassal": Color(0.4, 0.62, 0.45),
	"none": Color(0.35, 0.35, 0.3),
}
const FLAG_COLORS := {
	"orc": Color(1.0, 0.3, 0.2), "pirate": Color(0.3, 0.55, 0.85),
	"dark_elf": Color(0.55, 0.25, 0.8), "human": Color(1.0, 0.85, 0.15),
	"high_elf": Color(0.3, 0.85, 0.4), "mage": Color(0.3, 0.4, 1.0),
	"neutral": Color(0.6, 0.6, 0.55), "vassal": Color(0.45, 0.75, 0.50),
	"none": Color(0.35, 0.35, 0.3),
}
const TERRAIN_COLORS := {
	FactionData.TerrainType.PLAINS: Color(0.55, 0.72, 0.35),
	FactionData.TerrainType.FOREST: Color(0.28, 0.55, 0.2),
	FactionData.TerrainType.MOUNTAIN: Color(0.7, 0.65, 0.58),
	FactionData.TerrainType.SWAMP: Color(0.4, 0.48, 0.32),
	FactionData.TerrainType.COASTAL: Color(0.35, 0.55, 0.72),
	FactionData.TerrainType.FORTRESS_WALL: Color(0.75, 0.7, 0.62),
	FactionData.TerrainType.RIVER: Color(0.3, 0.5, 0.75),
	FactionData.TerrainType.RUINS: Color(0.6, 0.55, 0.62),
	FactionData.TerrainType.WASTELAND: Color(0.75, 0.65, 0.4),
	FactionData.TerrainType.VOLCANIC: Color(0.65, 0.3, 0.18),
}
const TERRAIN_ELEVATION := {
	FactionData.TerrainType.PLAINS: 0.0, FactionData.TerrainType.FOREST: 0.05,
	FactionData.TerrainType.MOUNTAIN: 0.3, FactionData.TerrainType.SWAMP: -0.05,
	FactionData.TerrainType.COASTAL: 0.0, FactionData.TerrainType.FORTRESS_WALL: 0.2,
	FactionData.TerrainType.RIVER: -0.03, FactionData.TerrainType.RUINS: 0.08,
	FactionData.TerrainType.WASTELAND: 0.02, FactionData.TerrainType.VOLCANIC: 0.25,
}
const COL_FOG := Color(0.35, 0.3, 0.22, 0.55)
const COL_FOG_EDGE := Color(0.35, 0.3, 0.22, 0.25)
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
	EventBus.army_march_started.connect(_on_march_started)
	EventBus.army_march_arrived.connect(_on_march_arrived)
	EventBus.army_march_cancelled.connect(_on_march_cancelled)
	# March step / battle / intercept / supply signals
	if EventBus.has_signal("army_march_step"):
		EventBus.army_march_step.connect(_on_march_step)
	if EventBus.has_signal("army_march_battle"):
		EventBus.army_march_battle.connect(_on_march_battle)
	if EventBus.has_signal("army_march_intercepted"):
		EventBus.army_march_intercepted.connect(_on_march_intercepted)
	if EventBus.has_signal("army_supply_low"):
		EventBus.army_supply_low.connect(_on_army_supply_low)
	# Garrison visual signals
	if EventBus.has_signal("army_garrisoned"):
		EventBus.army_garrisoned.connect(_on_army_garrisoned)
	if EventBus.has_signal("army_ungarrisoned"):
		EventBus.army_ungarrisoned.connect(_on_army_ungarrisoned)
	if EventBus.has_signal("building_upgraded"):
		EventBus.building_upgraded.connect(_on_building_upgraded)
	if EventBus.has_signal("supply_line_cut"):
		EventBus.supply_line_cut.connect(_on_supply_line_cut)
	if EventBus.has_signal("supply_line_restored"):
		EventBus.supply_line_restored.connect(_on_supply_line_restored)
	if EventBus.has_signal("supply_depot_built"):
		EventBus.supply_depot_built.connect(_on_supply_depot_built)
	if EventBus.has_signal("supply_depot_destroyed"):
		EventBus.supply_depot_destroyed.connect(_on_supply_depot_destroyed)
	if not GameManager.tiles.is_empty():
		_build_board()
	_board_hud_init()

func rebuild() -> void:
	_clear_board(); _build_board()

# ═══════════════ ENVIRONMENT ═══════════════
func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.18, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.88, 0.82)
	env.ambient_light_energy = 1.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)

func _setup_lighting() -> void:
	for cfg in [
		[Vector3(-50, 30, 0), Color(1.0, 0.95, 0.85), 2.2],
		[Vector3(-25, -120, 0), Color(0.65, 0.7, 0.9), 1.1],
		[Vector3(-10, 180, 0), Color(0.95, 0.8, 0.6), 0.6]]:
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
		m.albedo_color = Color(0.85, 0.8, 0.7)
		m.uv1_scale = Vector3(1, 1, 1)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		m.albedo_color = Color(0.18, 0.2, 0.14)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; g.material_override = m
	g.position = Vector3(9.0, GROUND_Y - 0.15, -7.0); add_child(g)
	# ── Ocean/void boundary ring around the playable area ──
	_build_map_boundary()
	_setup_ambient_particles()

# ═══════════════ INPUT & CAMERA ═══════════════
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			var old_zoom := _camera_zoom_target
			_camera_zoom_target = clampf(_camera_zoom_target - ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
			_zoom_toward_cursor(event.position, old_zoom, _camera_zoom_target)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var old_zoom := _camera_zoom_target
			_camera_zoom_target = clampf(_camera_zoom_target + ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
			_zoom_toward_cursor(event.position, old_zoom, _camera_zoom_target)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if hovered_tile >= 0:
				_show_context_menu(hovered_tile)
			else:
				_deselect_tile()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_hide_context_menu()
			if _input_mode == "attack" and hovered_tile >= 0:
				_handle_mode_click_attack(hovered_tile)
				get_viewport().set_input_as_handled()
				return
			elif _input_mode == "deploy" and hovered_tile >= 0:
				_handle_mode_click_deploy(hovered_tile)
				get_viewport().set_input_as_handled()
				return
	if event is InputEventKey and event.pressed and not event.echo:
		_handle_keyboard_shortcut(event)


func _zoom_toward_cursor(mouse_pos: Vector2, old_zoom: float, new_zoom: float) -> void:
	## Shift camera toward cursor when zooming in, away when zooming out.
	if is_equal_approx(old_zoom, new_zoom):
		return
	var world_pos := _screen_to_world_xz(mouse_pos)
	if world_pos == Vector3.ZERO:
		return
	var factor: float = 0.15  # How much to shift toward cursor
	if new_zoom < old_zoom:  # Zooming in — move toward cursor
		camera_target_pos = camera_target_pos.lerp(world_pos, factor)
	else:  # Zooming out — move away from cursor gently
		var away := camera_target_pos + (camera_target_pos - world_pos).normalized() * 0.5
		camera_target_pos = camera_target_pos.lerp(away, factor * 0.5)
	_clamp_camera()


func _screen_to_world_xz(screen_pos: Vector2) -> Vector3:
	## Project screen position to world XZ plane at Y=0.
	if not camera or not camera.is_inside_tree():
		return Vector3.ZERO
	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.001:
		return Vector3.ZERO
	var t: float = -from.y / dir.y
	if t < 0.0:
		return Vector3.ZERO
	return from + dir * t

func _process(delta: float) -> void:
	camera_pivot.position = camera_pivot.position.lerp(camera_target_pos, CAM_LERP_SPEED * delta)
	# Smooth zoom interpolation
	if not is_equal_approx(camera_zoom, _camera_zoom_target):
		camera_zoom = lerpf(camera_zoom, _camera_zoom_target, ZOOM_LERP_SPEED * delta)
		if absf(camera_zoom - _camera_zoom_target) < 0.005:
			camera_zoom = _camera_zoom_target
		_apply_zoom()
	_process_camera_input(delta); _process_edge_scroll(delta); _process_hover_path(); _process_water_animation(delta)
	_process_hover_delay(delta); _redraw_custom_minimap()
	update_minimap_overlay()

func _process_camera_input(delta: float) -> void:
	# BUG FIX: don't pan camera when UI has focus (panel open, typing, etc.)
	if get_viewport() and get_viewport().gui_get_focus_owner() != null:
		return
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
	camera_target_pos.x = clampf(camera_target_pos.x, -5.0, 40.0)
	camera_target_pos.z = clampf(camera_target_pos.z, -35.0, 5.0)

# ═══════════════ BOARD BUILDING ═══════════════
func _clear_board() -> void:
	# Kill active tweens before freeing nodes
	for key in _fog_tweens:
		if _fog_tweens[key] and _fog_tweens[key].is_valid():
			_fog_tweens[key].kill()
	_fog_tweens.clear()
	if _ap_flash_tween and _ap_flash_tween.is_valid():
		_ap_flash_tween.kill()
	_ap_flash_tween = null
	if _camera_follow_tween and _camera_follow_tween.is_valid():
		_camera_follow_tween.kill()
	_camera_follow_tween = null
	if _camera_zoom_restore_tween and _camera_zoom_restore_tween.is_valid():
		_camera_zoom_restore_tween.kill()
	_camera_zoom_restore_tween = null

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
	# Clean up edge decorations, map boundary elements, and ambient particles
	for ch in get_children():
		if ch.name in ["EdgeDeco", "MapBorder", "EdgeFog"] or ch.name.begins_with("AmbientParticle_"):
			ch.queue_free()
	settlement_nodes.clear()
	_settlement_cache.clear()
	water_anim_nodes.clear()
	for m in attack_route_meshes:
		if is_instance_valid(m): m.queue_free()
	attack_route_meshes.clear()
	_clear_all_march_routes()
	_clear_all_garrison_shields()
	_clear_all_marching_arrows()
	_clear_supply_lines(); _clear_supply_depots(); _clear_isolated_overlays()
	_clear_highlights(); _clear_path_preview(); _clear_pulse_ring()
	if is_instance_valid(_hover_glow):
		_hover_glow.queue_free()
		_hover_glow = null

func _build_board() -> void:
	tile_visuals.clear()
	_material_cache.clear()
	_fog_dirty_tiles.clear()
	# Pre-build fog shader material
	_fog_shader = load("res://shaders/fog_of_war.gdshader")
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = _fog_shader
	_fog_mat.set_shader_parameter("fog_density", 1.0)
	_fog_mat.set_shader_parameter("alpha_multiplier", 1.0)
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
		base_mi.material_override = _make_textured_mat(Color(0.85, 0.85, 0.8), terrain_tex)
	else:
		base_mi.material_override = _make_mat(Color(0.6, 0.6, 0.55))
	root.add_child(base_mi)
	# Faction territory glow disc
	var owner_id: int = tile.get("owner_id", -1)
	if owner_id >= 0:
		var glow_fk: String = _get_tile_faction_key(tile)
		var glow_color: Color = FACTION_COLORS.get(glow_fk, FACTION_COLORS["none"])
		var glow_mesh := CylinderMesh.new()
		glow_mesh.top_radius = TILE_RADIUS * 1.25
		glow_mesh.bottom_radius = TILE_RADIUS * 1.25
		glow_mesh.height = 0.02
		glow_mesh.radial_segments = 6
		var glow_mi := MeshInstance3D.new()
		glow_mi.mesh = glow_mesh
		glow_mi.name = "FactionGlow"
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, 0.18)
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.emission_enabled = true
		gm.emission = glow_color
		gm.emission_energy_multiplier = 0.5
		glow_mi.material_override = gm
		glow_mi.position.y = -0.02
		root.add_child(glow_mi)
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
	var label := _make_label3d(tile.get("name", "#%d" % idx), 36, Vector3(0, 2.2, 0))
	root.add_child(label)
	var glabel := _make_label3d("", 26, Vector3(0, 1.75, 0), Color(1, 0.95, 0.8, 0.95))
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
	crest_sprite.pixel_size = 0.009
	crest_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	crest_sprite.no_depth_test = true
	crest_sprite.position = Vector3(-0.8, TILE_HEIGHT + 1.0, 0.6)
	crest_sprite.modulate = Color(1, 1, 1, 0.92)
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
	# Per-tile ShaderMaterial instance so density can vary per tile
	var fog_mat_inst := ShaderMaterial.new()
	fog_mat_inst.shader = _fog_shader
	fog_mat_inst.set_shader_parameter("fog_density", 1.0)
	fog_mat_inst.set_shader_parameter("alpha_multiplier", 1.0)
	fog.material_override = fog_mat_inst; fog.position.y = 0.35; fog.name = "FogOverlay"
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
	var building_level: int = tile.get("building_level", 0)
	var effective_level: int = maxi(level, building_level) if building_level > 0 else level
	var tt = tile.get("type", -1)
	var y: float = TILE_HEIGHT
	# Determine settlement icon key based on tile type and special properties
	var icon_key: String = _get_settlement_icon_key(tile)
	var tex: Texture2D = _settlement_textures.get(icon_key, null)
	if tex != null:
		# Use AI-generated sprite instead of procedural geometry
		var sprite := Sprite3D.new()
		sprite.texture = tex
		sprite.pixel_size = 0.012
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sprite.axis = Vector3.AXIS_Y
		# Flat on top of hex, facing up
		sprite.rotation_degrees = Vector3(-90, 0, 0)
		var sscale: float = 0.8 + level * 0.2
		if tt == GameManager.TileType.CORE_FORTRESS:
			sscale = 1.4
		# Level 3: slightly larger icon for progression feel
		if effective_level >= 3:
			sscale *= 1.1
		sprite.scale = Vector3(sscale, sscale, sscale)
		sprite.position = Vector3(0, y + 0.02, 0)
		sprite.modulate = Color(1, 1, 1, 0.9)
		# Level-based tinting on flat sprite
		if effective_level >= 3:
			sprite.modulate = Color(1.15, 1.05, 0.85, 0.95)
		elif effective_level >= 2:
			sprite.modulate = Color(1.05, 1.0, 0.88, 0.92)
		parent.add_child(sprite)
		# Also add a small upright billboard version for visibility from camera angle
		var billboard := Sprite3D.new()
		billboard.texture = tex
		billboard.pixel_size = 0.008
		billboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		billboard.no_depth_test = true
		billboard.name = "SettlementBillboard"
		var bscale: float = 0.6 + level * 0.15
		if tt == GameManager.TileType.CORE_FORTRESS:
			bscale = 1.0
		if effective_level >= 3:
			bscale *= 1.12
		billboard.scale = Vector3(bscale, bscale, bscale)
		billboard.position = Vector3(0, y + 0.6 + level * 0.1, 0)
		billboard.modulate = Color(1, 1, 1, 0.85)
		# Level-based tinting on billboard
		if effective_level >= 3:
			billboard.modulate = Color(1.15, 1.05, 0.85, 0.9)
		elif effective_level >= 2:
			billboard.modulate = Color(1.05, 1.0, 0.88, 0.88)
		parent.add_child(billboard)
		# ── Level-based golden glow outline (levels 2+) ──
		if effective_level >= 2:
			var glow := Sprite3D.new()
			glow.texture = tex
			glow.pixel_size = billboard.pixel_size * 1.15
			glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			glow.no_depth_test = true
			glow.name = "LevelGlow"
			var glow_scale: float = bscale * 1.18
			if effective_level >= 3:
				glow_scale = bscale * 1.25
			glow.scale = Vector3(glow_scale, glow_scale, glow_scale)
			glow.position = billboard.position
			# Golden glow: brighter for level 3
			if effective_level >= 3:
				glow.modulate = Color(1.0, 0.85, 0.3, 0.35)
			else:
				glow.modulate = Color(1.0, 0.88, 0.4, 0.2)
			parent.add_child(glow)
			# Pulsing glow animation
			var glow_tw := create_tween()
			glow_tw.set_loops()
			var glow_bright: float = glow.modulate.a + 0.12
			var glow_dim: float = glow.modulate.a - 0.05
			glow_tw.tween_property(glow, "modulate:a", glow_bright, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			glow_tw.tween_property(glow, "modulate:a", glow_dim, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		# ── Star/pip level indicators below billboard ──
		if effective_level >= 1:
			_add_level_stars(parent, billboard.position, effective_level)
		# Subtle breathing animation for settlement icon
		if tt == GameManager.TileType.CORE_FORTRESS:
			var tw := create_tween()
			tw.set_loops()
			tw.tween_property(billboard, "scale", billboard.scale * 1.05, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
			tw.tween_property(billboard, "scale", billboard.scale, 1.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
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
		# ── Star indicators for procedural buildings too ──
		if effective_level >= 1:
			_add_level_stars(parent, Vector3(0, TILE_HEIGHT + 0.55, 0), effective_level)

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

# ── Level star/pip indicators ──
func _add_level_stars(parent: Node3D, ref_pos: Vector3, level: int) -> void:
	## Add small gold star pips below/beside the building billboard to indicate level.
	## Uses tiny emissive sphere meshes as pips (4-6px equivalent in 3D).
	var star_count: int = clampi(level, 1, 3)
	var star_container := Node3D.new()
	star_container.name = "LevelStars"
	# Position below the billboard reference
	star_container.position = Vector3(ref_pos.x, ref_pos.y - 0.22, ref_pos.z)
	parent.add_child(star_container)
	# Spread stars horizontally, centered
	var spacing: float = 0.12
	var start_x: float = -spacing * (star_count - 1) * 0.5
	for i in range(star_count):
		var pip := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		sm.radial_segments = 6
		sm.rings = 3
		pip.mesh = sm
		# Gold color, brighter at higher levels
		var gold_col: Color
		match star_count:
			1: gold_col = Color(0.85, 0.7, 0.3)
			2: gold_col = Color(0.95, 0.8, 0.3)
			3, _: gold_col = Color(1.0, 0.9, 0.35)
		pip.material_override = _make_emissive_mat(gold_col, gold_col * 0.7, 1.5)
		pip.position = Vector3(start_x + i * spacing, 0, 0)
		star_container.add_child(pip)

# ── Upgrade flash animation ──
func _on_building_upgraded(_player_id: int, tile_index: int, _building_id: String, _new_level: int) -> void:
	## Plays a white flash on the settlement billboard when a building is upgraded.
	if _upgrade_flash_tiles.has(tile_index):
		return  # Already animating
	_upgrade_flash_tiles[tile_index] = true
	# First update the settlement visuals to reflect the new level
	_update_territory_visual(tile_index)
	# Then play the flash on top
	_play_upgrade_flash(tile_index)

func _play_upgrade_flash(idx: int) -> void:
	if not settlement_nodes.has(idx):
		_upgrade_flash_tiles.erase(idx)
		return
	var sett_node: Node3D = settlement_nodes[idx]
	# Find the billboard sprite to flash
	var billboard: Sprite3D = sett_node.get_node_or_null("SettlementBillboard")
	if billboard == null:
		# Try first Sprite3D child as fallback
		for c in sett_node.get_children():
			if c is Sprite3D:
				billboard = c
				break
	if billboard == null:
		_upgrade_flash_tiles.erase(idx)
		return
	# Store original modulate and flash white then restore
	var original_mod: Color = billboard.modulate
	var tw := create_tween()
	# Flash to bright white
	tw.tween_property(billboard, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Hold briefly
	tw.tween_interval(0.08)
	# Fade to golden highlight
	tw.tween_property(billboard, "modulate", Color(1.4, 1.2, 0.7, 1.0), 0.15).set_ease(Tween.EASE_IN_OUT)
	# Return to new appearance
	tw.tween_property(billboard, "modulate", original_mod, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func(): _upgrade_flash_tiles.erase(idx))
	# Also flash the glow layer if present
	var glow_node = sett_node.get_node_or_null("LevelGlow")
	if glow_node and is_instance_valid(glow_node):
		var glow_orig: Color = glow_node.modulate
		var gtw := create_tween()
		gtw.tween_property(glow_node, "modulate", Color(1.5, 1.3, 0.6, 0.7), 0.12).set_ease(Tween.EASE_OUT)
		gtw.tween_interval(0.08)
		gtw.tween_property(glow_node, "modulate", glow_orig, 0.35).set_ease(Tween.EASE_IN)

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

func _register_water_node(node: MeshInstance3D, node_type: String) -> void:
	water_anim_nodes.append({"node": node, "type": node_type, "original_y": node.position.y, "original_z": node.position.z})

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
	var fc: Color = tt.lerp(bc, 0.25)
	if tile.get("owner_id", -1) >= 0: fc = fc.lightened(0.12)
	# Apply terrain texture if available, otherwise fallback to color
	var terrain_key: String = _terrain_enum_to_key(terrain)
	var terrain_tex: Texture2D = _terrain_textures.get(terrain_key, null)
	if terrain_tex:
		vis["base"].material_override = _make_textured_mat(fc.lightened(0.35), terrain_tex)
	else:
		vis["base"].material_override = _make_mat(fc)
	# Border
	var brc: Color = FLAG_COLORS.get(fk, Color(0.3, 0.3, 0.28))
	if idx == selected_tile: brc = Color(1.0, 1.0, 0.8)
	elif idx == hovered_tile: brc = brc.lightened(0.35)
	vis["border"].material_override = _make_emissive_mat(brc, brc * 0.6, 0.8)
	# Flag
	var flc: Color = FLAG_COLORS.get(fk, Color(0.4, 0.4, 0.4))
	vis["banner"].material_override = _make_emissive_mat(flc, flc * 0.5, 0.6)
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
		var new_key: String = _get_settlement_icon_key(tile) + "_%d_%d" % [tile.get("level", 1), tile.get("building_level", 0)]
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
	# Add slight curve via perpendicular offset
	var perp := Vector3(-diff.z, 0, diff.x).normalized()
	var curve_offset: float = dist * 0.08 * (1.0 if randf() > 0.5 else -1.0)
	var mid_point := Vector3(
		(from.x + to.x) * 0.5 + perp.x * curve_offset,
		0,
		(from.z + to.z) * 0.5 + perp.z * curve_offset
	)
	var mid_elev: float = (fe + te) * 0.5
	var seg_n: int = maxi(int(dist / 0.5), 2)
	var gap: float = 0.12
	for i in range(seg_n):
		var t0: float = (float(i) + gap * 0.5) / float(seg_n)
		var t1: float = (float(i) + 1.0 - gap * 0.5) / float(seg_n)
		var tm: float = (t0 + t1) * 0.5
		# Quadratic bezier interpolation
		var p0 := Vector3(from.x, fe, from.z)
		var p1 := Vector3(mid_point.x, mid_elev, mid_point.z)
		var p2 := Vector3(to.x, te, to.z)
		var a := p0.lerp(p1, tm)
		var b := p1.lerp(p2, tm)
		var pos := a.lerp(b, tm)
		# Direction for rotation
		var da := p0.lerp(p1, t1)
		var db := p1.lerp(p2, t1)
		var next_pos := da.lerp(db, t1)
		var seg_dir := Vector3(next_pos.x - pos.x, 0, next_pos.z - pos.z)
		var angle: float = atan2(seg_dir.x, seg_dir.z) if seg_dir.length() > 0.001 else 0.0
		var seg_len: float = dist / float(seg_n) * (1.0 - gap)
		var rd := _make_box_mesh(Vector3(0.28, 0.03, seg_len), Color(0.42, 0.36, 0.26))
		rd.position = Vector3(pos.x, pos.y + TILE_HEIGHT + 0.015, pos.z)
		rd.rotation.y = angle
		add_child(rd)
		edge_meshes.append(rd)

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
			lm.size = Vector3(TILE_RADIUS * 0.9, 0.07, 0.07); line.mesh = lm
			var fk: String = _get_tile_faction_key(ta)
			var bc: Color = FLAG_COLORS.get(fk, Color(0.5, 0.5, 0.5))
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(bc.r, bc.g, bc.b, 0.7)
			bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bmat.emission_enabled = true; bmat.emission = bc * 0.6
			bmat.emission_energy_multiplier = 1.2; line.material_override = bmat
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
	# 行军规划模式下显示路径消耗标签
	if _march_planning_active:
		_show_path_cost_label(selected_tile, hovered_tile)

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
	_hide_path_cost_label()

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
	if oh >= 0:
		_update_territory_visual(oh)
		_animate_tile_hover(oh, false)
	_update_territory_visual(tile_index); _animate_tile_hover(tile_index, true)
	_show_hover_glow(tile_index)
	# Reset hover info delay for new tile
	_hover_delay = 0.0
	_hover_active_tile = -1

func _on_tile_hover_exit(tile_index: int) -> void:
	if hovered_tile == tile_index:
		hovered_tile = -1; _update_territory_visual(tile_index)
		_animate_tile_hover(tile_index, false)
		_hide_hover_glow()
		_hide_hover_info()

func _animate_tile_hover(idx: int, entering: bool) -> void:
	if not tile_visuals.has(idx): return
	var vis: Dictionary = tile_visuals[idx]
	var be: float = vis.get("elevation", 0.0)
	var ty: float = be + (0.05 if entering else 0.0)
	if _hover_tween and _hover_tween.is_valid(): _hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_hover_tween.tween_property(vis["root"], "position:y", ty, 0.15)

func _show_hover_glow(idx: int) -> void:
	if not tile_visuals.has(idx): return
	var pos: Vector3 = GameManager.tiles[idx]["position_3d"]
	var el: float = tile_visuals[idx].get("elevation", 0.0)
	if not is_instance_valid(_hover_glow):
		_hover_glow = MeshInstance3D.new()
		_hover_glow.name = "HoverGlow"
		var tc := CylinderMesh.new()
		tc.top_radius = TILE_RADIUS * 1.12
		tc.bottom_radius = TILE_RADIUS * 1.12
		tc.height = 0.03
		tc.radial_segments = 6
		_hover_glow.mesh = tc
		_hover_glow_mat = StandardMaterial3D.new()
		_hover_glow_mat.albedo_color = Color(1.0, 0.92, 0.65, 0.3)
		_hover_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hover_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hover_glow_mat.emission_enabled = true
		_hover_glow_mat.emission = Color(1.0, 0.88, 0.55)
		_hover_glow_mat.emission_energy_multiplier = 0.8
		_hover_glow.material_override = _hover_glow_mat
		add_child(_hover_glow)
	_hover_glow.position = Vector3(pos.x, el + TILE_HEIGHT + 0.045, pos.z)
	_hover_glow.visible = true
	_hover_glow.scale = Vector3(0.9, 1.0, 0.9)
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_hover_glow, "scale", Vector3(1.0, 1.0, 1.0), 0.12)

func _hide_hover_glow() -> void:
	if is_instance_valid(_hover_glow):
		_hover_glow.visible = false

func _on_tile_clicked(tile_index: int) -> void:
	var old_sel: int = selected_tile
	var pid: int = GameManager.get_human_player_id()
	var tile: Dictionary = GameManager.tiles[tile_index]
	if GameManager.selected_army_id >= 0:
		var army: Dictionary = GameManager.get_army(GameManager.selected_army_id)
		if not army.is_empty() and army["player_id"] == pid:
			var dep: Array = GameManager.get_army_deployable_tiles(GameManager.selected_army_id)
			if dep.has(tile_index):
				_execute_deploy_with_undo(GameManager.selected_army_id, tile_index)
				return
			var atk: Array = GameManager.get_army_attackable_tiles(GameManager.selected_army_id)
			if atk.has(tile_index):
				_request_attack_confirm(GameManager.selected_army_id, tile_index)
				return
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
	clear_attack_route(); _exit_march_planning_mode()
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
	# Clean up any existing dot meshes before re-creation
	for m in attack_route_meshes:
		if is_instance_valid(m): m.queue_free()
	attack_route_meshes.clear()
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
		var fog_mi: MeshInstance3D = vis["fog"]
		var rev: bool = GameManager.is_revealed_for(idx, pid)
		if rev:
			# Tile is revealed -> fade fog out smoothly
			if fog_mi.visible:
				_tween_fog_out(idx, fog_mi)
			vis["label"].visible = true; vis["garrison_label"].visible = true
			vis["flag_root"].visible = GameManager.tiles[idx].get("owner_id", -1) >= 0
		else:
			# Tile is fogged -> compute distance-based density
			var dist: int = _fog_distance_to_revealed(idx, pid)
			var density: float = 1.0
			if dist <= 1:
				density = 0.2   # very light - edge fog
			elif dist == 2:
				density = 0.55  # medium fog
			else:
				density = 1.0   # full dense fog
			var height_scale: float = lerp(0.5, 1.0, density)
			fog_mi.scale = Vector3(1.0, height_scale, 1.0)
			var mat: ShaderMaterial = fog_mi.material_override as ShaderMaterial
			if mat:
				mat.set_shader_parameter("fog_density", density)
			if not fog_mi.visible:
				fog_mi.visible = true
				if mat:
					mat.set_shader_parameter("alpha_multiplier", 1.0)
			vis["label"].visible = false; vis["garrison_label"].visible = false
			vis["flag_root"].visible = false

func _fog_distance_to_revealed(idx: int, pid: int) -> int:
	## BFS to find shortest distance from idx to the nearest revealed tile.
	## Returns 0 if the tile itself is revealed, capped at 4 for performance.
	if GameManager.is_revealed_for(idx, pid):
		return 0
	var visited: Dictionary = {idx: 0}
	var queue: Array = [idx]
	while queue.size() > 0:
		var current: int = queue.pop_front()
		var depth: int = visited[current]
		if depth >= 4:
			break
		var neighbors: Array = GameManager.adjacency.get(current, [])
		for n in neighbors:
			if visited.has(n):
				continue
			if GameManager.is_revealed_for(n, pid):
				return depth + 1
			visited[n] = depth + 1
			queue.append(n)
	return 4  # Far from any revealed tile

func _tween_fog_out(idx: int, fog_mi: MeshInstance3D) -> void:
	## Smoothly fades fog out over 0.3s then hides the mesh.
	if _fog_tweens.has(idx) and _fog_tweens[idx] != null:
		_fog_tweens[idx].kill()
	var mat: ShaderMaterial = fog_mi.material_override as ShaderMaterial
	if not mat:
		fog_mi.visible = false
		return
	var tw: Tween = create_tween()
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(fog_mi) and is_instance_valid(mat):
			mat.set_shader_parameter("alpha_multiplier", v)
	, 1.0, 0.0, 0.3)
	tw.tween_callback(func() -> void:
		if is_instance_valid(fog_mi):
			fog_mi.visible = false
	)
	_fog_tweens[idx] = tw

func _has_revealed_neighbor(idx: int, pid: int) -> bool:
	if not GameManager.adjacency.has(idx): return false
	for n in GameManager.adjacency[idx]:
		if GameManager.is_revealed_for(n, pid): return true
	return false

# ═══════════════ VISUAL FEEDBACK (v4.6) ═══════════════

## Flash a captured tile: bright flash on the base mesh over 0.5s
func _flash_tile_capture(idx: int) -> void:
	if not tile_visuals.has(idx): return
	var vis: Dictionary = tile_visuals[idx]
	var base_mi: MeshInstance3D = vis["base"]
	if not is_instance_valid(base_mi): return
	var tile: Dictionary = GameManager.tiles[idx]
	var fk: String = _get_tile_faction_key(tile)
	var fc: Color = FLAG_COLORS.get(fk, FLAG_COLORS["none"])
	# Create a temporary emissive flash by tweening border ring scale
	var border_mi: MeshInstance3D = vis["border"]
	if is_instance_valid(border_mi):
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color.WHITE
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.emission_enabled = true
		bmat.emission = Color.WHITE
		bmat.emission_energy_multiplier = 2.0
		border_mi.material_override = bmat
		var tw := create_tween()
		tw.tween_property(bmat, "albedo_color", fc, 0.5).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(bmat, "emission", fc * 0.5, 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func(): _update_territory_visual(idx))

## Brief shake on a tile (used for combat at that location)
func _shake_tile(idx: int) -> void:
	if not tile_visuals.has(idx): return
	var vis: Dictionary = tile_visuals[idx]
	var root_node: Node3D = vis["root"]
	var original_pos: Vector3 = root_node.position
	var tw := create_tween()
	tw.tween_property(root_node, "position", original_pos + Vector3(0.08, 0, 0.08), 0.04)
	tw.tween_property(root_node, "position", original_pos + Vector3(-0.06, 0, -0.06), 0.04)
	tw.tween_property(root_node, "position", original_pos + Vector3(0.04, 0, 0), 0.04)
	tw.tween_property(root_node, "position", original_pos, 0.06).set_ease(Tween.EASE_OUT)

# ═══════════════ SIGNAL HANDLERS ═══════════════
func _on_tile_captured(_pid: int, ti: int) -> void:
	# Check if this is a level upgrade (cache key changed means rebuild happened)
	var was_upgrade: bool = false
	if settlement_nodes.has(ti) and ti < GameManager.tiles.size():
		var tile: Dictionary = GameManager.tiles[ti]
		var new_key: String = _get_settlement_icon_key(tile) + "_%d_%d" % [tile.get("level", 1), tile.get("building_level", 0)]
		if _settlement_cache.has(ti) and _settlement_cache[ti] != new_key:
			was_upgrade = true
	# Audio trigger for tile capture
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("tile_capture")
	_update_territory_visual(ti)
	# Visual: flash captured tile white → faction color over 0.5s
	_flash_tile_capture(ti)
	# Conquest ripple effect (spawns after flash completes ~0.5s)
	_spawn_conquest_ripple(ti)
	# If the settlement was rebuilt due to level change, play upgrade flash
	if was_upgrade:
		_play_upgrade_flash(ti)
	# Update neighbors for border visuals
	if GameManager.adjacency.has(ti):
		for n in GameManager.adjacency[ti]:
			_update_territory_visual(n)
	_mark_fog_dirty([ti]); _update_fog(); _draw_faction_borders()
func _on_fog_updated(_pid: int) -> void:
	_fog_dirty_tiles.clear()  # Full fog rebuild
	_update_fog()
func _on_turn_started(_pid: int) -> void:
	_clear_highlights(); _deselect_tile(); _cancel_input_mode(); _undo_stack.clear()
	if tile_visuals.is_empty() and not GameManager.tiles.is_empty(): _build_board()
	else:
		_update_all_territories()
		_fog_dirty_tiles.clear()  # Force full fog rebuild on turn start
		_update_fog()
	_update_supply_lines()
	# Show turn summary for human player
	if _pid == GameManager.get_human_player_id():
		_show_turn_summary()
func _on_game_over(_wid: int) -> void:
	_clear_highlights()
func _on_army_changed(_pid: int, _cnt: int) -> void:
	_update_all_territories()
func _on_army_deployed(_pid: int, _aid: int, from_tile: int, to_tile: int) -> void:
	_animate_army_move(from_tile, to_tile)
	_update_territory_visual(from_tile); _update_territory_visual(to_tile)
	# Camera follow army to destination after short delay
	_camera_follow_delayed(to_tile, 0.3)
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
	# Smooth arc movement with slight Y bounce
	var mid_y: float = lp.y + 0.3
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(marker, "position:x", lp.x, 0.45).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(marker, "position:z", lp.z, 0.45).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	# Y arc: rise then fall
	var tw_y := create_tween()
	tw_y.tween_property(marker, "position:y", mid_y, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw_y.tween_property(marker, "position:y", lp.y, 0.23).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	# Spawn dust effect at origin
	_spawn_move_dust(from_root.global_position + Vector3(0, TILE_HEIGHT + 0.05, 0))


func _spawn_move_dust(pos: Vector3) -> void:
	## Spawn a small dust puff at the departure tile.
	var dust := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.1
	dust.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.5, 0.35, 0.5)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust.material_override = mat
	dust.position = pos
	add_child(dust)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(dust, "scale", Vector3(2.5, 0.5, 2.5), 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.6).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(dust.queue_free)

# ═══════════════ MARCH ROUTE VISUALIZATION ═══════════════

func _on_march_started(army_id: int, path: Array) -> void:
	## Triggered when a march order is issued. Draws the persistent route and
	## attaches a marching-arrow indicator above the army marker.
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("army_march")
	_draw_march_route(army_id, path)
	_spawn_marching_arrow(army_id)
	# Cancel garrison stance if the army was garrisoned
	if MarchSystem.is_army_garrisoned(army_id):
		MarchSystem.cancel_garrison_order(army_id)


func _on_march_arrived(army_id: int, tile: int) -> void:
	## Triggered when the army reaches its destination.
	_clear_march_route(army_id)
	_clear_marching_arrow(army_id)
	_update_territory_visual(tile)
	# Camera follow to arrival tile
	_camera_follow_delayed(tile, 0.2)


func _on_march_cancelled(army_id: int) -> void:
	## Triggered when a march order is cancelled.
	_clear_march_route(army_id)
	_clear_marching_arrow(army_id)


func _on_march_step(army_id: int, from_tile: int, to_tile: int, _progress: float) -> void:
	## Triggered each time an army advances one tile during turn processing.
	## Plays the movement animation and updates territory visuals for both tiles.
	_animate_army_move(from_tile, to_tile)
	_update_territory_visual(from_tile)
	_update_territory_visual(to_tile)
	# Advance the marching arrow to the new tile
	_move_marching_arrow(army_id, to_tile)
	# Trim the route: remove the segment the army just traversed
	_trim_march_route(army_id, from_tile)


func _on_march_battle(army_id: int, tile_index: int) -> void:
	## Triggered when a marching army encounters a hostile tile.
	_clear_march_route(army_id)
	_clear_marching_arrow(army_id)
	_spawn_battle_toast(tile_index, "⚔ 遇敌!", Color(1.0, 0.45, 0.1))
	_camera_follow_tile(tile_index, false)


func _on_march_intercepted(army_id: int, _interceptor_id: int, tile_index: int) -> void:
	## Triggered when a marching army is intercepted by an enemy.
	_clear_march_route(army_id)
	_clear_marching_arrow(army_id)
	_spawn_battle_toast(tile_index, "⚠ 拦截!", Color(1.0, 0.85, 0.1))
	_camera_follow_tile(tile_index, false)


func _on_army_supply_low(army_id: int, supply: float) -> void:
	## Triggered when an army's supply drops below the low threshold.
	var army: Dictionary = GameManager.get_army(army_id)
	if army.is_empty(): return
	var tile_idx: int = army.get("tile_index", -1)
	if tile_idx < 0: return
	var pct_text: String = "%d%%" % int(supply)
	_spawn_battle_toast(tile_idx, "⚠ 补给不足 " + pct_text, Color(0.95, 0.7, 0.1))


# ── Per-army route drawing ──

func _draw_march_route(army_id: int, path: Array) -> void:
	## Draw the full planned route for a specific army.
	_clear_march_route(army_id)
	if path.size() < 2: return
	var meshes: Array = []
	for i in range(path.size() - 1):
		var fi: int = path[i]
		var ti: int = path[i + 1]
		if fi < 0 or fi >= GameManager.tiles.size() or ti < 0 or ti >= GameManager.tiles.size(): continue
		var fp: Vector3 = GameManager.tiles[fi]["position_3d"]
		var tp: Vector3 = GameManager.tiles[ti]["position_3d"]
		var fe: float = TERRAIN_ELEVATION.get(GameManager.tiles[fi].get("terrain", 0), 0.0)
		var te: float = TERRAIN_ELEVATION.get(GameManager.tiles[ti].get("terrain", 0), 0.0)
		var dist: float = fp.distance_to(tp)
		var dot_count: int = maxi(int(dist / 0.6), 2)
		for d in range(dot_count):
			var t_ratio: float = float(d + 1) / float(dot_count + 1)
			var pos := fp.lerp(tp, t_ratio)
			pos.y = lerpf(fe, te, t_ratio) + TILE_HEIGHT + 0.12
			var dot := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.045
			sm.height = 0.09
			dot.mesh = sm
			var mat := _make_emissive_mat(
				ColorTheme.MARCH_PATH_FRIENDLY,
				Color(0.3, 0.6, 1.0),
				0.6
			)
			dot.material_override = mat
			add_child(dot)
			dot.position = pos
			meshes.append(dot)
	# Add waypoint rings at each step
	for i in range(1, path.size()):
		var idx: int = path[i]
		if idx < 0 or idx >= GameManager.tiles.size(): continue
		var p: Vector3 = GameManager.tiles[idx]["position_3d"]
		var elev: float = TERRAIN_ELEVATION.get(GameManager.tiles[idx].get("terrain", 0), 0.0)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.25
		tm.outer_radius = 0.35
		ring.mesh = tm
		var ring_color: Color
		if i == path.size() - 1:
			ring_color = Color(1.0, 0.3, 0.1, 0.7)  # Final destination: red-orange
		else:
			ring_color = Color(0.3, 0.65, 1.0, 0.5)  # Waypoint: blue
		var rmat := _make_emissive_mat(ring_color, ring_color.lightened(0.3), 0.5)
		ring.material_override = rmat
		ring.position = Vector3(p.x, elev + TILE_HEIGHT + 0.05, p.z)
		ring.rotation_degrees.x = 90.0
		add_child(ring)
		meshes.append(ring)
	march_route_meshes[army_id] = meshes


func _trim_march_route(army_id: int, completed_from_tile: int) -> void:
	## Remove the first segment of a route once the army has moved past it.
	## This keeps the displayed path in sync with the remaining journey.
	if not march_route_meshes.has(army_id): return
	if not GameManager.tiles.size() > completed_from_tile: return
	var from_pos: Vector3 = GameManager.tiles[completed_from_tile]["position_3d"]
	var meshes: Array = march_route_meshes[army_id]
	var keep: Array = []
	for m in meshes:
		if not is_instance_valid(m):
			continue
		# Keep meshes that are not near the completed_from_tile position
		var d: float = Vector2(m.position.x - from_pos.x, m.position.z - from_pos.z).length()
		if d < 0.8:
			m.queue_free()
		else:
			keep.append(m)
	march_route_meshes[army_id] = keep


func _clear_march_route(army_id: int) -> void:
	## Clear route meshes for a single army.
	if not march_route_meshes.has(army_id): return
	for m in march_route_meshes[army_id]:
		if is_instance_valid(m): m.queue_free()
	march_route_meshes.erase(army_id)


func _clear_all_march_routes() -> void:
	## Clear all per-army route meshes (used on board rebuild).
	for aid in march_route_meshes:
		for m in march_route_meshes[aid]:
			if is_instance_valid(m): m.queue_free()
	march_route_meshes.clear()


# ── Marching arrow indicator ──

func _spawn_marching_arrow(army_id: int) -> void:
	## Spawn a small billboard arrow above the army marker to indicate active march.
	_clear_marching_arrow(army_id)
	var army: Dictionary = GameManager.get_army(army_id)
	if army.is_empty(): return
	var tile_idx: int = army.get("tile_index", -1)
	if tile_idx < 0 or not tile_visuals.has(tile_idx): return
	var vis: Dictionary = tile_visuals[tile_idx]
	var am: Node3D = vis["army_marker"]
	var arrow := Label3D.new()
	arrow.name = "MarchArrow"
	arrow.text = "➡"
	arrow.font_size = 32
	arrow.pixel_size = 0.010
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.no_depth_test = true
	arrow.modulate = Color(0.35, 0.75, 1.0, 0.92)
	arrow.outline_modulate = Color(0, 0, 0, 0.85)
	arrow.outline_size = 10
	arrow.position = Vector3(0, 1.6, 0)
	am.add_child(arrow)
	# Gentle bob animation
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(arrow, "position:y", 1.85, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(arrow, "position:y", 1.6, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_marching_arrow_meshes[army_id] = arrow


func _move_marching_arrow(army_id: int, new_tile: int) -> void:
	## Re-parent the marching arrow to the army marker at the new tile.
	if not _marching_arrow_meshes.has(army_id): return
	var arrow: Node3D = _marching_arrow_meshes[army_id]
	if not is_instance_valid(arrow): return
	if not tile_visuals.has(new_tile): return
	var vis: Dictionary = tile_visuals[new_tile]
	var am: Node3D = vis["army_marker"]
	if arrow.get_parent() != am:
		if is_instance_valid(arrow.get_parent()):
			arrow.get_parent().remove_child(arrow)
		am.add_child(arrow)


func _clear_marching_arrow(army_id: int) -> void:
	if not _marching_arrow_meshes.has(army_id): return
	var arrow: Node3D = _marching_arrow_meshes[army_id]
	if is_instance_valid(arrow): arrow.queue_free()
	_marching_arrow_meshes.erase(army_id)


func _clear_all_marching_arrows() -> void:
	for aid in _marching_arrow_meshes:
		var arrow: Node3D = _marching_arrow_meshes[aid]
		if is_instance_valid(arrow): arrow.queue_free()
	_marching_arrow_meshes.clear()


# ── Garrison shield indicator ──

func _on_army_garrisoned(army_id: int, tile_index: int) -> void:
	## Spawn a shield icon above the garrisoned army marker.
	_spawn_garrison_shield(army_id, tile_index)
	_update_territory_visual(tile_index)


func _on_army_ungarrisoned(army_id: int, tile_index: int) -> void:
	## Remove the shield icon when garrison stance is cancelled.
	_clear_garrison_shield(army_id)
	_update_territory_visual(tile_index)


func _spawn_garrison_shield(army_id: int, tile_index: int) -> void:
	## Spawn a golden shield Label3D above the army marker to indicate garrison.
	_clear_garrison_shield(army_id)
	if not tile_visuals.has(tile_index): return
	var vis: Dictionary = tile_visuals[tile_index]
	var am: Node3D = vis["army_marker"]
	var shield := Label3D.new()
	shield.name = "GarrisonShield"
	shield.text = "🛡"
	shield.font_size = 30
	shield.pixel_size = 0.010
	shield.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shield.no_depth_test = true
	shield.modulate = Color(1.0, 0.88, 0.25, 0.95)
	shield.outline_modulate = Color(0, 0, 0, 0.85)
	shield.outline_size = 10
	shield.position = Vector3(0, 1.6, 0)
	am.add_child(shield)
	# Slow pulse animation to draw attention
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(shield, "modulate:a", 0.55, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(shield, "modulate:a", 0.95, 1.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_garrison_shield_meshes[army_id] = shield


func _clear_garrison_shield(army_id: int) -> void:
	if not _garrison_shield_meshes.has(army_id): return
	var shield: Node3D = _garrison_shield_meshes[army_id]
	if is_instance_valid(shield): shield.queue_free()
	_garrison_shield_meshes.erase(army_id)


func _clear_all_garrison_shields() -> void:
	for aid in _garrison_shield_meshes:
		var shield: Node3D = _garrison_shield_meshes[aid]
		if is_instance_valid(shield): shield.queue_free()
	_garrison_shield_meshes.clear()

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
		@warning_ignore("integer_division")
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
	var l := Label3D.new(); l.text = text; l.font_size = size; l.pixel_size = 0.007
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
	fog_mat.albedo_color = Color(0.3, 0.25, 0.18, 0.35)
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
	## Place a decoration sprite appropriate for the terrain transition.
	var dominant: int = terrain_a if randf() < 0.6 else terrain_b
	var deco_key: String = ""
	var deco_scale: float = 0.4 + randf() * 0.2
	match dominant:
		FactionData.TerrainType.FOREST:
			deco_key = "trees"
		FactionData.TerrainType.MOUNTAIN, FactionData.TerrainType.VOLCANIC:
			deco_key = "mountains"
		FactionData.TerrainType.WASTELAND, FactionData.TerrainType.RUINS:
			deco_key = "ruins_arch" if randf() < 0.4 else "skull_cave"
		FactionData.TerrainType.SWAMP, FactionData.TerrainType.RIVER:
			deco_key = "bridge"
		FactionData.TerrainType.COASTAL:
			deco_key = "dock"
		FactionData.TerrainType.FORTRESS_WALL:
			deco_key = "watchtower"
		_:
			deco_key = "trees"
			deco_scale = 0.3 + randf() * 0.15
	var tex: Texture2D = _deco_textures.get(deco_key)
	if tex:
		var spr := Sprite3D.new()
		spr.texture = tex
		spr.pixel_size = 0.002 * deco_scale
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.no_depth_test = false
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		spr.position = pos + Vector3(0, 0.15 * deco_scale, 0)
		spr.name = "EdgeDeco"
		add_child(spr)
	else:
		var fb := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06 + randf() * 0.04; sm.height = sm.radius * 1.4
		fb.mesh = sm
		fb.material_override = _make_mat(Color(0.25, 0.35, 0.2))
		fb.position = pos; fb.name = "EdgeDeco"
		add_child(fb)

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
	minimap_camera.position = Vector3(13, 55, -12)
	minimap_camera.rotation_degrees = Vector3(-90, 0, 0)
	minimap_camera.fov = 65; minimap_camera.current = true
	minimap_viewport.add_child(minimap_camera)
	_setup_minimap_overlay()

# ═══════════════ MINIMAP OVERLAY ═══════════════
var _minimap_overlay: Control
var _minimap_cam_rect: ColorRect  # Shows camera viewport position

func update_minimap_overlay() -> void:
	## Called each frame or on camera move to update the camera viewport indicator.
	if not is_instance_valid(_minimap_cam_rect) or not is_instance_valid(minimap_camera):
		return
	# Calculate the camera's visible area as a fraction of the full map
	var cam := camera if is_instance_valid(camera) else null
	if not cam:
		cam = get_viewport().get_camera_3d()
	if not cam or cam == minimap_camera:
		return
	# Map bounds (approximate from tile positions)
	var map_min := Vector2(-5, -25)
	var map_max := Vector2(30, 5)
	var map_size := map_max - map_min
	# Camera position on the XZ plane — use pivot position, not camera global
	# (camera is offset from pivot by its local transform)
	var pivot_pos := camera_pivot.global_position if is_instance_valid(camera_pivot) else cam.global_position
	var cam_pos := Vector2(pivot_pos.x, pivot_pos.z)
	# Normalize to 0-1 range
	var norm_x: float = clampf((cam_pos.x - map_min.x) / map_size.x, 0.0, 1.0)
	var norm_y: float = clampf((cam_pos.y - map_min.y) / map_size.y, 0.0, 1.0)
	# Size of viewport indicator (depends on zoom/FOV)
	var view_w: float = 0.2  # ~20% of map visible
	var view_h: float = 0.15
	if minimap_container:
		var msize: Vector2 = minimap_container.size
		_minimap_cam_rect.position = Vector2(
			(norm_x - view_w * 0.5) * msize.x,
			(norm_y - view_h * 0.5) * msize.y
		)
		_minimap_cam_rect.size = Vector2(view_w * msize.x, view_h * msize.y)


func _setup_minimap_overlay() -> void:
	## Add a transparent overlay on top of the minimap for the camera rect indicator.
	if not is_instance_valid(minimap_container):
		return
	_minimap_overlay = Control.new()
	_minimap_overlay.name = "MinimapOverlay"
	_minimap_overlay.anchor_right = 1.0
	_minimap_overlay.anchor_bottom = 1.0
	_minimap_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap_overlay.gui_input.connect(_on_minimap_input)
	minimap_container.add_child(_minimap_overlay)
	# Camera viewport rectangle
	_minimap_cam_rect = ColorRect.new()
	_minimap_cam_rect.color = Color(1.0, 0.9, 0.3, 0.25)
	_minimap_cam_rect.size = Vector2(36, 28)
	_minimap_cam_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap_overlay.add_child(_minimap_cam_rect)
	# Border for cam rect
	var border := ReferenceRect.new()
	border.anchor_right = 1.0
	border.anchor_bottom = 1.0
	border.border_color = Color(1.0, 0.85, 0.3, 0.6)
	border.border_width = 1.5
	border.editor_only = false
	_minimap_cam_rect.add_child(border)

func _on_minimap_input(event: InputEvent) -> void:
	## Click/drag on minimap to move main camera.
	if not event is InputEventMouseButton and not event is InputEventMouseMotion:
		return
	var is_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_drag := event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not is_click and not is_drag:
		return
	if not is_instance_valid(minimap_container):
		return
	var msize: Vector2 = minimap_container.size
	if msize.x < 1.0 or msize.y < 1.0:
		return
	var local_pos: Vector2 = event.position
	var norm_x: float = clampf(local_pos.x / msize.x, 0.0, 1.0)
	var norm_y: float = clampf(local_pos.y / msize.y, 0.0, 1.0)
	# Map bounds must match update_minimap_overlay
	var map_min := Vector2(-5, -25)
	var map_max := Vector2(30, 5)
	var map_size := map_max - map_min
	camera_target_pos.x = map_min.x + norm_x * map_size.x
	camera_target_pos.z = map_min.y + norm_y * map_size.y
	_clamp_camera()

# ═══════════════ TILE PULSE ANIMATION ═══════════════
func pulse_tile(idx: int, color: Color, duration: float = 0.6) -> void:
	if not tile_visuals.has(idx): return
	var bmi: MeshInstance3D = tile_visuals[idx]["base"]
	var orig: StandardMaterial3D = bmi.material_override
	var pm := _make_emissive_mat(color, color, 2.0)
	bmi.material_override = pm
	var tw := create_tween()
	tw.tween_callback(func(): bmi.material_override = orig).set_delay(duration)

# ═══════════════ SUPPLY LINES ═══════════════

const COL_SUPPLY_CONNECTED := Color(0.2, 0.8, 0.3, 0.55)
const COL_SUPPLY_STRAINED := Color(0.9, 0.8, 0.2, 0.55)
const COL_SUPPLY_DISCONNECTED := Color(0.85, 0.2, 0.2, 0.55)
const COL_ISOLATED_OVERLAY := Color(0.85, 0.15, 0.1, 0.2)
const COL_DEPOT_MARKER := Color(0.3, 0.6, 0.9, 0.85)
const SUPPLY_LINE_DOT_SPACING := 0.7
const SUPPLY_LINE_DOT_RADIUS := 0.035
const SUPPLY_CONNECTED_THRESHOLD := 5
var _isolated_pulse_tween: Tween = null

func _update_supply_lines() -> void:
	_clear_supply_lines()
	_clear_supply_depots()
	_clear_isolated_overlays()
	var pid: int = GameManager.get_human_player_id()
	if pid < 0: return
	_draw_supply_lines(pid)
	_draw_supply_depot_markers(pid)
	_draw_isolated_overlays(pid)

func _draw_supply_lines(player_id: int) -> void:
	## Draw dotted supply route from each army back to capital.
	if not GameManager.has_method("get_player_armies"): return
	var armies: Array = GameManager.get_player_armies(player_id)
	for army in armies:
		var army_id: int = army.get("id", -1)
		var tile_index: int = army.get("tile_index", -1)
		if army_id < 0 or tile_index < 0: continue
		if tile_index >= GameManager.tiles.size(): continue
		# Get supply path through SupplySystem autoload
		var path: Array = _get_army_supply_path(player_id, army)
		if path.is_empty(): continue
		# Determine line color based on path length
		var line_color: Color
		if path.size() <= SUPPLY_CONNECTED_THRESHOLD:
			line_color = COL_SUPPLY_CONNECTED
		elif path.size() <= SUPPLY_CONNECTED_THRESHOLD * 2:
			line_color = COL_SUPPLY_STRAINED
		else:
			line_color = COL_SUPPLY_DISCONNECTED
		_draw_supply_path_dots(path, line_color)

func _get_army_supply_path(player_id: int, army: Dictionary) -> Array:
	## Resolve supply path for an army using the strategic SupplySystem.
	var tile_index: int = army.get("tile_index", -1)
	if tile_index < 0: return []
	# Use autoload SupplySystem (strategic)
	if SupplySystem and SupplySystem.has_method("get_supply_path"):
		var tile: Dictionary = GameManager.tiles[tile_index] if tile_index < GameManager.tiles.size() else {}
		var owner_id: int = tile.get("owner_id", -1)
		if owner_id == player_id:
			return SupplySystem.get_supply_path(player_id, tile_index)
		# Army on enemy/neutral tile — find path from nearest connected neighbor
		var neighbors: Array = GameManager.adjacency.get(tile_index, [])
		var best_path: Array = []
		for nb in neighbors:
			if nb < 0 or nb >= GameManager.tiles.size(): continue
			if GameManager.tiles[nb] == null: continue
			if GameManager.tiles[nb].get("owner_id", -1) != player_id: continue
			if not SupplySystem.is_tile_supplied(player_id, nb): continue
			var p: Array = SupplySystem.get_supply_path(player_id, nb)
			if not p.is_empty() and (best_path.is_empty() or p.size() < best_path.size()):
				best_path = p
		if not best_path.is_empty():
			return [tile_index] + best_path
	return []

func _draw_supply_path_dots(path: Array, color: Color) -> void:
	## Draw small dotted line along a supply path, similar to march route dots.
	if path.size() < 2: return
	var mat: StandardMaterial3D = _make_supply_dot_mat(color)
	for i in range(path.size() - 1):
		var fi: int = path[i]; var ti: int = path[i + 1]
		if fi < 0 or fi >= GameManager.tiles.size(): continue
		if ti < 0 or ti >= GameManager.tiles.size(): continue
		var fp: Vector3 = GameManager.tiles[fi]["position_3d"]
		var tp: Vector3 = GameManager.tiles[ti]["position_3d"]
		var fe: float = _get_elev(GameManager.tiles[fi])
		var te: float = _get_elev(GameManager.tiles[ti])
		var seg_dist: float = Vector3(tp.x - fp.x, 0, tp.z - fp.z).length()
		if seg_dist < 0.1: continue
		var dot_count: int = maxi(int(seg_dist / SUPPLY_LINE_DOT_SPACING), 2)
		for d in range(dot_count):
			var t_ratio: float = float(d + 1) / float(dot_count + 1)
			var dot := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = SUPPLY_LINE_DOT_RADIUS
			sm.height = SUPPLY_LINE_DOT_RADIUS * 2.0
			dot.mesh = sm
			dot.material_override = mat
			dot.position = Vector3(
				lerpf(fp.x, tp.x, t_ratio),
				lerpf(fe, te, t_ratio) + TILE_HEIGHT + 0.1,
				lerpf(fp.z, tp.z, t_ratio))
			add_child(dot)
			supply_line_meshes.append(dot)

func _make_supply_dot_mat(color: Color) -> StandardMaterial3D:
	var key := "supply_%s" % color
	if _material_cache.has(key): return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b, 1.0)
	m.emission_energy_multiplier = 0.5
	_material_cache[key] = m
	return m

func _clear_supply_lines() -> void:
	for m in supply_line_meshes:
		if is_instance_valid(m): m.queue_free()
	supply_line_meshes.clear()

# ═══════════════ SUPPLY DEPOT MARKERS ═══════════════

func _draw_supply_depot_markers(player_id: int) -> void:
	## Draw small 3D crate indicators on tiles that have supply depots.
	# Check combat SupplySystem node for depot data
	var depot_node: Node = null
	if Engine.get_main_loop() is SceneTree:
		depot_node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("SupplySystem")
	# Also check for SupplyLogistics depot buildings
	var logistics_node: Node = null
	if Engine.get_main_loop() is SceneTree:
		logistics_node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("SupplyLogistics")
	# Gather depot tile indices
	var depot_tiles: Array = []
	# Method 1: SupplySystem._supply_depots (combat system, may be separate node)
	if depot_node and depot_node.has_method("is_supply_depot"):
		for tile in GameManager.tiles:
			if tile == null: continue
			if tile.get("owner_id", -1) != player_id: continue
			if depot_node.is_supply_depot(tile["index"]):
				depot_tiles.append(tile["index"])
	# Method 2: Check building_id for depot buildings
	var depot_building_ids: Array = ["supply_depot", "depot", "granary"]
	for tile in GameManager.tiles:
		if tile == null: continue
		if tile.get("owner_id", -1) != player_id: continue
		var bid: String = tile.get("building_id", "")
		if bid in depot_building_ids and not depot_tiles.has(tile["index"]):
			depot_tiles.append(tile["index"])
	# Draw markers
	for tidx in depot_tiles:
		_create_depot_3d_marker(tidx)

func _create_depot_3d_marker(idx: int) -> void:
	if idx < 0 or idx >= GameManager.tiles.size(): return
	if not tile_visuals.has(idx): return
	var pos: Vector3 = GameManager.tiles[idx]["position_3d"]
	var el: float = tile_visuals[idx].get("elevation", 0.0)
	# Small box (crate) mesh
	var crate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.25, 0.2, 0.25)
	crate.mesh = bm
	var mat := _make_emissive_mat(
		COL_DEPOT_MARKER,
		Color(0.3, 0.55, 0.85),
		0.6
	)
	crate.material_override = mat
	crate.position = Vector3(pos.x + 0.6, el + TILE_HEIGHT + 0.15, pos.z + 0.6)
	add_child(crate)
	supply_depot_markers.append(crate)
	# Label above crate
	var lbl := _make_label3d(
		"补给站", 8,
		Vector3(pos.x + 0.6, el + TILE_HEIGHT + 0.4, pos.z + 0.6),
		COL_DEPOT_MARKER
	)
	add_child(lbl)
	supply_depot_markers.append(lbl)

func _clear_supply_depots() -> void:
	for m in supply_depot_markers:
		if is_instance_valid(m): m.queue_free()
	supply_depot_markers.clear()

# ═══════════════ ISOLATED TERRITORY OVERLAY ═══════════════

func _draw_isolated_overlays(player_id: int) -> void:
	## Draw darkened red overlay on isolated (cut-off) tiles.
	if not SupplySystem or not SupplySystem.has_method("get_isolated_tiles"): return
	var isolated: Array = SupplySystem.get_isolated_tiles(player_id)
	if isolated.is_empty(): return
	for tidx in isolated:
		_add_isolated_overlay(tidx)
	_start_isolated_pulse()

func _add_isolated_overlay(idx: int) -> void:
	if idx < 0 or idx >= GameManager.tiles.size(): return
	if not tile_visuals.has(idx): return
	var pos: Vector3 = GameManager.tiles[idx]["position_3d"]
	var el: float = tile_visuals[idx].get("elevation", 0.0)
	var overlay := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = TILE_RADIUS * 0.95
	cm.bottom_radius = TILE_RADIUS * 0.95
	cm.height = 0.02
	cm.radial_segments = 6
	overlay.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COL_ISOLATED_OVERLAY
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.15, 0.1)
	mat.emission_energy_multiplier = 0.4
	overlay.material_override = mat
	overlay.position = Vector3(pos.x, el + TILE_HEIGHT + 0.06, pos.z)
	add_child(overlay)
	isolated_overlay_meshes.append(overlay)

func _start_isolated_pulse() -> void:
	## Pulse the isolated overlays between dim and bright red.
	if isolated_overlay_meshes.is_empty(): return
	if _isolated_pulse_tween and _isolated_pulse_tween.is_valid():
		_isolated_pulse_tween.kill()
	_isolated_pulse_tween = create_tween()
	_isolated_pulse_tween.set_loops()
	for overlay in isolated_overlay_meshes:
		if not is_instance_valid(overlay): continue
		var mat: StandardMaterial3D = overlay.material_override
		if mat == null: continue
		_isolated_pulse_tween.set_parallel(true)
		_isolated_pulse_tween.tween_property(mat, "albedo_color:a", 0.35, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_isolated_pulse_tween.chain()
	for overlay in isolated_overlay_meshes:
		if not is_instance_valid(overlay): continue
		var mat: StandardMaterial3D = overlay.material_override
		if mat == null: continue
		_isolated_pulse_tween.set_parallel(true)
		_isolated_pulse_tween.tween_property(mat, "albedo_color:a", 0.12, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func _clear_isolated_overlays() -> void:
	if _isolated_pulse_tween and _isolated_pulse_tween.is_valid():
		_isolated_pulse_tween.kill()
		_isolated_pulse_tween = null
	for m in isolated_overlay_meshes:
		if is_instance_valid(m): m.queue_free()
	isolated_overlay_meshes.clear()

# ═══════════════ SUPPLY SIGNAL HANDLERS ═══════════════

func _on_supply_line_cut(_player_id: int, isolated_tiles: Array) -> void:
	var pid: int = GameManager.get_human_player_id()
	if _player_id != pid: return
	# Add isolated overlays for newly cut tiles
	for tidx in isolated_tiles:
		_add_isolated_overlay(tidx)
	_start_isolated_pulse()

func _on_supply_line_restored(_player_id: int, _tiles: Array) -> void:
	var pid: int = GameManager.get_human_player_id()
	if _player_id != pid: return
	# Full refresh — rebuild isolated overlays from current state
	_clear_isolated_overlays()
	_draw_isolated_overlays(pid)
	# Refresh supply lines as paths may have changed
	_clear_supply_lines()
	_draw_supply_lines(pid)

func _on_supply_depot_built(_tile_index: int, _player_id: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	if _player_id != pid: return
	# Refresh depot markers and supply lines
	_clear_supply_depots()
	_draw_supply_depot_markers(pid)
	_clear_supply_lines()
	_draw_supply_lines(pid)

func _on_supply_depot_destroyed(_tile_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	_clear_supply_depots()
	_draw_supply_depot_markers(pid)
	_clear_supply_lines()
	_draw_supply_lines(pid)


# ═══════════════ AP COUNTER DISPLAY (CanvasLayer HUD) ═══════════════
var _ap_canvas_layer: CanvasLayer
var _ap_label: Label
var _ap_flash_tween: Tween

func _setup_ap_display() -> void:
	## Creates a CanvasLayer with a Label showing current AP in the top-left.
	_ap_canvas_layer = CanvasLayer.new()
	_ap_canvas_layer.name = "APOverlay"
	_ap_canvas_layer.layer = 10
	add_child(_ap_canvas_layer)
	var panel := PanelContainer.new()
	panel.name = "APPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.75)
	sb.corner_radius_top_left = 6; sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6; sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 14; sb.content_margin_right = 14
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.65, 0.13, 0.6)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(16, 16)
	_ap_canvas_layer.add_child(panel)
	_ap_label = Label.new()
	_ap_label.name = "APLabel"
	_ap_label.text = "⚡ AP: -- / --"
	_ap_label.add_theme_font_size_override("font_size", 22)
	_ap_label.add_theme_color_override("font_color", Color("#DAA520"))
	panel.add_child(_ap_label)
	EventBus.ap_changed.connect(_on_ap_changed_display)
	EventBus.turn_started.connect(_on_ap_turn_started_display)

func _on_ap_changed_display(_pid: int, _new_ap: int) -> void:
	_refresh_ap_display()
	_flash_ap_counter()

func _on_ap_turn_started_display(_pid: int) -> void:
	_refresh_ap_display()

func _refresh_ap_display() -> void:
	if not is_instance_valid(_ap_label):
		return
	var pid: int = GameManager.get_human_player_id()
	var player: Dictionary = GameManager.get_player_by_id(pid)
	if player.is_empty():
		return
	var current_ap: int = player.get("ap", 0)
	var max_ap: int = GameManager.calculate_action_points(pid)
	_ap_label.text = "⚡ AP: %d / %d" % [current_ap, max_ap]


# ═══════════════ AP CHANGE FEEDBACK (Flash / Pulse) ═══════════════

func _flash_ap_counter() -> void:
	## Brief gold -> red -> gold flash on the AP label when AP is consumed.
	if not is_instance_valid(_ap_label):
		return
	if is_instance_valid(_ap_flash_tween):
		_ap_flash_tween.kill()
	var gold_color := Color("#DAA520")
	var red_color := Color(0.95, 0.2, 0.15)
	_ap_label.add_theme_color_override("font_color", red_color)
	_ap_flash_tween = create_tween()
	_ap_flash_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_ap_flash_tween.tween_method(func(c: Color): _ap_label.add_theme_color_override("font_color", c),
		red_color, gold_color, 0.45)


# ═══════════════ BATTLE RESULT TOAST ON MAP ═══════════════
var _battle_toast_nodes: Array = []

func _setup_battle_toast_listener() -> void:
	EventBus.action_visualize_attack.connect(_on_battle_visualize)

func _on_battle_visualize(_attacker_tile: int, defender_tile: int, result: Dictionary) -> void:
	var won: bool = result.get("won", false)
	var text: String = "⚔ 胜利!" if won else "⚔ 败北!"
	var color: Color = Color(0.15, 0.9, 0.25) if won else Color(0.95, 0.2, 0.15)
	_spawn_battle_toast(defender_tile, text, color)
	# Camera follow: pan + zoom to battle tile, then restore after toast
	_camera_follow_tile(defender_tile, true)
	var reset_tw := create_tween()
	reset_tw.tween_interval(1.5)
	reset_tw.tween_callback(func(): _camera_reset_zoom())

func _spawn_battle_toast(tile_index: int, text: String, color: Color) -> void:
	## Floating Label3D at the tile that drifts upward and fades out over 1.5s.
	if not tile_visuals.has(tile_index):
		return
	var vis: Dictionary = tile_visuals[tile_index]
	var root: Node3D = vis["root"]
	var toast := Label3D.new()
	toast.text = text
	toast.font_size = 48
	toast.pixel_size = 0.012
	toast.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	toast.no_depth_test = true
	toast.modulate = color
	toast.outline_modulate = Color(0, 0, 0, 0.95)
	toast.outline_size = 14
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector3(0, 2.8, 0)
	root.add_child(toast)
	_battle_toast_nodes.append(toast)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(toast, "position:y", 5.0, 1.5)
	tw.tween_property(toast, "modulate:a", 0.0, 1.5).set_delay(0.3)
	tw.chain().tween_callback(func():
		if is_instance_valid(toast):
			toast.queue_free()
			_battle_toast_nodes.erase(toast)
	)


# ═══════════════ ARMY SUPPLY STATUS INDICATORS ═══════════════

func _update_army_supply_bar(idx: int) -> void:
	## Updates or creates the supply status bar for an army at tile idx.
	if not tile_visuals.has(idx):
		return
	var vis: Dictionary = tile_visuals[idx]
	var am: Node3D = vis["army_marker"]
	if not am.visible:
		var old_bar: Node3D = am.get_node_or_null("SupplyBar")
		if old_bar:
			old_bar.visible = false
		return
	var army: Dictionary = GameManager.get_army_at_tile(idx)
	if army.is_empty():
		return
	var supply_pct: float = _get_army_supply_pct(army)
	var bar_color: Color
	if supply_pct > 60.0:
		bar_color = Color(0.2, 0.85, 0.25)
	elif supply_pct >= 40.0:
		bar_color = Color(0.9, 0.85, 0.15)
	else:
		bar_color = Color(0.9, 0.2, 0.15)
	var bar: MeshInstance3D = am.get_node_or_null("SupplyBar")
	if not bar:
		bar = MeshInstance3D.new()
		bar.name = "SupplyBar"
		var bm := BoxMesh.new()
		bm.size = Vector3(0.35, 0.035, 0.06)
		bar.mesh = bm
		bar.position = Vector3(0, 0.05, 0)
		am.add_child(bar)
	bar.visible = true
	var full_width: float = 0.35
	var current_w: float = full_width * clampf(supply_pct / 100.0, 0.05, 1.0)
	bar.scale.x = current_w / full_width
	bar.position.x = -(full_width - current_w) * 0.5
	bar.material_override = _make_mat(bar_color)

func _get_army_supply_pct(army: Dictionary) -> float:
	## Army supply as percentage (0-100). Uses MarchSystem if marching, else troop fullness.
	var army_id: int = army.get("id", -1)
	if MarchSystem.march_orders.has(army_id):
		var order: Dictionary = MarchSystem.march_orders[army_id]
		return clampf(float(order.get("supply", 100.0)), 0.0, 100.0)
	var current_total: int = 0
	var max_total: int = 0
	for troop in army.get("troops", []):
		current_total += troop.get("soldiers", 0)
		max_total += troop.get("max_soldiers", troop.get("soldiers", 1))
	if max_total <= 0:
		return 100.0
	return clampf(float(current_total) / float(max_total) * 100.0, 0.0, 100.0)

func _update_all_army_supply_bars() -> void:
	for idx in tile_visuals:
		_update_army_supply_bar(idx)


# ═══════════════ SIEGE PROGRESS INDICATOR ═══════════════
var _siege_hp_nodes: Dictionary = {}

func _setup_siege_listeners() -> void:
	EventBus.siege_started.connect(_on_siege_started_visual)
	EventBus.siege_progress.connect(_on_siege_progress_visual)
	EventBus.siege_ended.connect(_on_siege_ended_visual)

func _on_siege_started_visual(_attacker_id: int, tile_index: int, _turns: int) -> void:
	_update_siege_hp_bar(tile_index)

func _on_siege_progress_visual(tile_index: int, _wall_hp: float, _morale: float, _turns_left: int) -> void:
	_update_siege_hp_bar(tile_index)

func _on_siege_ended_visual(tile_index: int, _result: String) -> void:
	_remove_siege_hp_bar(tile_index)

func _update_siege_hp_bar(tile_index: int) -> void:
	if not tile_visuals.has(tile_index):
		return
	var siege: Dictionary = SiegeSystem.get_siege_at_tile(tile_index)
	if siege.is_empty():
		_remove_siege_hp_bar(tile_index)
		return
	var wall_hp: float = siege.get("wall_hp", 0.0)
	var wall_max: float = siege.get("wall_max_hp", 1.0)
	if wall_max <= 0.0:
		wall_max = 1.0
	var pct: float = clampf(wall_hp / wall_max, 0.0, 1.0)
	var bar_color: Color
	if pct > 0.6:
		bar_color = Color(0.3, 0.7, 0.9)
	elif pct > 0.3:
		bar_color = Color(0.9, 0.75, 0.15)
	else:
		bar_color = Color(0.9, 0.2, 0.1)
	var vis: Dictionary = tile_visuals[tile_index]
	var root: Node3D = vis["root"]
	var bg_bar: MeshInstance3D = root.get_node_or_null("SiegeHPBg")
	if not bg_bar:
		bg_bar = MeshInstance3D.new()
		bg_bar.name = "SiegeHPBg"
		var bgm := BoxMesh.new()
		bgm.size = Vector3(1.0, 0.06, 0.06)
		bg_bar.mesh = bgm
		bg_bar.position = Vector3(0, 2.55, 0)
		bg_bar.material_override = _make_mat(Color(0.15, 0.12, 0.1, 0.8))
		root.add_child(bg_bar)
	bg_bar.visible = true
	var hp_bar: MeshInstance3D = root.get_node_or_null("SiegeHPBar")
	if not hp_bar:
		hp_bar = MeshInstance3D.new()
		hp_bar.name = "SiegeHPBar"
		var hpm := BoxMesh.new()
		hpm.size = Vector3(1.0, 0.06, 0.07)
		hp_bar.mesh = hpm
		hp_bar.position = Vector3(0, 2.55, 0)
		root.add_child(hp_bar)
	hp_bar.visible = true
	hp_bar.material_override = _make_mat(bar_color)
	hp_bar.scale.x = pct
	hp_bar.position.x = -(1.0 - pct) * 0.5
	var hp_label: Label3D = root.get_node_or_null("SiegeHPLabel")
	if not hp_label:
		hp_label = _make_label3d("", 22, Vector3(0, 2.72, 0), Color(0.9, 0.85, 0.7))
		hp_label.name = "SiegeHPLabel"
		root.add_child(hp_label)
	hp_label.visible = true
	hp_label.text = "🏰 %.0f / %.0f" % [wall_hp, wall_max]
	_siege_hp_nodes[tile_index] = hp_bar

func _remove_siege_hp_bar(tile_index: int) -> void:
	if not tile_visuals.has(tile_index):
		return
	var root: Node3D = tile_visuals[tile_index]["root"]
	for nname in ["SiegeHPBg", "SiegeHPBar", "SiegeHPLabel"]:
		var n: Node = root.get_node_or_null(nname)
		if n:
			n.queue_free()
	_siege_hp_nodes.erase(tile_index)


# ═══════════════ BOARD HUD INITIALIZATION ═══════════════

func _board_hud_init() -> void:
	## Master init for all new HUD/feedback systems. Called at end of _ready.
	_setup_ap_display()
	_setup_battle_toast_listener()
	_setup_siege_listeners()
	_refresh_ap_display()
	_setup_context_menu()
	_setup_attack_confirm_panel()
	_init_new_hud()
	EventBus.army_changed.connect(_on_army_changed_supply_bar)
	EventBus.army_deployed.connect(_on_army_deployed_supply_bar)
	EventBus.army_created.connect(_on_army_created_supply_bar)
	EventBus.army_disbanded.connect(_on_army_disbanded_supply_bar)
	EventBus.army_supply_changed.connect(_on_army_supply_changed_bar)
	EventBus.turn_started.connect(_on_turn_started_supply_bar)

func _on_army_changed_supply_bar(_pid: int, _cnt: int) -> void:
	_update_all_army_supply_bars()

func _on_army_deployed_supply_bar(_pid: int, _aid: int, from_tile: int, to_tile: int) -> void:
	_update_army_supply_bar(from_tile)
	_update_army_supply_bar(to_tile)

func _on_army_created_supply_bar(_pid: int, _aid: int, _extra = null) -> void:
	_update_all_army_supply_bars()

func _on_army_disbanded_supply_bar(_pid: int, _aid: int, _extra = null) -> void:
	_update_all_army_supply_bars()

func _on_army_supply_changed_bar(army_id: int, _supply_val: int) -> void:
	var army: Dictionary = GameManager.get_army(army_id)
	if not army.is_empty():
		_update_army_supply_bar(army["tile_index"])

func _on_turn_started_supply_bar(_pid: int) -> void:
	_update_all_army_supply_bars()


# ═══════════════ CONTEXT MENU ═══════════════
var _ctx_canvas: CanvasLayer
var _ctx_panel: PanelContainer
var _ctx_vbox: VBoxContainer
var _ctx_tile_index: int = -1

func _setup_context_menu() -> void:
	_ctx_canvas = CanvasLayer.new()
	_ctx_canvas.name = "ContextMenuLayer"
	_ctx_canvas.layer = 11
	add_child(_ctx_canvas)
	_ctx_panel = PanelContainer.new()
	_ctx_panel.name = "ContextPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.06, 0.92)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 6; sb.content_margin_right = 6
	sb.content_margin_top = 4; sb.content_margin_bottom = 4
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.65, 0.13, 0.7)
	_ctx_panel.add_theme_stylebox_override("panel", sb)
	_ctx_panel.visible = false
	_ctx_canvas.add_child(_ctx_panel)
	_ctx_vbox = VBoxContainer.new()
	_ctx_vbox.name = "ContextItems"
	_ctx_vbox.add_theme_constant_override("separation", 2)
	_ctx_panel.add_child(_ctx_vbox)

func _show_context_menu(tile_index: int) -> void:
	_hide_context_menu()
	_ctx_tile_index = tile_index
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	var pid: int = GameManager.get_human_player_id()
	var tile: Dictionary = GameManager.tiles[tile_index]
	var owner_id: int = tile.get("owner_id", -1)
	var army: Dictionary = GameManager.get_army_at_tile_for_player(tile_index, pid)
	var has_selected_army: bool = GameManager.selected_army_id >= 0
	var items: Array = []  # [{label, callback}]
	if owner_id == pid:
		if not army.is_empty():
			var atk_tiles: Array = GameManager.get_army_attackable_tiles(army["id"])
			if not atk_tiles.is_empty():
				items.append({"label": "出击 (A)", "callback": "_ctx_attack"})
			var dep_tiles: Array = GameManager.get_army_deployable_tiles(army["id"])
			if not dep_tiles.is_empty():
				items.append({"label": "部署 (D)", "callback": "_ctx_deploy"})
			items.append({"label": "招募", "callback": "_ctx_recruit"})
			items.append({"label": "建造", "callback": "_ctx_build"})
			items.append({"label": "守卫", "callback": "_ctx_guard"})
		else:
			items.append({"label": "建造", "callback": "_ctx_build"})
			items.append({"label": "查看详情", "callback": "_ctx_detail"})
	elif has_selected_army:
		var sel_army: Dictionary = GameManager.get_army(GameManager.selected_army_id)
		if not sel_army.is_empty() and sel_army["player_id"] == pid:
			var atk_tiles: Array = GameManager.get_army_attackable_tiles(GameManager.selected_army_id)
			if atk_tiles.has(tile_index):
				items.append({"label": "出击 (A)", "callback": "_ctx_attack_selected"})
	else:
		# Neutral adjacent tiles
		if has_selected_army:
			items.append({"label": "探索", "callback": "_ctx_explore"})
			items.append({"label": "外交", "callback": "_ctx_diplomacy"})
		elif owner_id < 0:
			items.append({"label": "探索", "callback": "_ctx_explore"})
			items.append({"label": "外交", "callback": "_ctx_diplomacy"})
	if items.is_empty():
		items.append({"label": "查看详情", "callback": "_ctx_detail"})
	_populate_context_items(items)
	var mpos: Vector2 = get_viewport().get_mouse_position()
	_ctx_panel.position = mpos + Vector2(4, 4)
	_ctx_panel.visible = true

func _populate_context_items(items: Array) -> void:
	for c in _ctx_vbox.get_children():
		c.queue_free()
	for item in items:
		var btn := Button.new()
		btn.text = item["label"]
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.3))
		btn.custom_minimum_size = Vector2(130, 28)
		var cb_name: String = item["callback"]
		btn.pressed.connect(_on_ctx_item_pressed.bind(cb_name))
		_ctx_vbox.add_child(btn)

func _on_ctx_item_pressed(callback_name: String) -> void:
	_hide_context_menu()
	call(callback_name)

func _hide_context_menu() -> void:
	if is_instance_valid(_ctx_panel):
		_ctx_panel.visible = false

func _ctx_attack() -> void:
	var pid: int = GameManager.get_human_player_id()
	var army: Dictionary = GameManager.get_army_at_tile_for_player(_ctx_tile_index, pid)
	if army.is_empty():
		return
	GameManager.select_army(army["id"])
	selected_tile = _ctx_tile_index
	_enter_attack_mode()

func _ctx_deploy() -> void:
	var pid: int = GameManager.get_human_player_id()
	var army: Dictionary = GameManager.get_army_at_tile_for_player(_ctx_tile_index, pid)
	if army.is_empty():
		return
	GameManager.select_army(army["id"])
	selected_tile = _ctx_tile_index
	_enter_deploy_mode()

func _ctx_recruit() -> void:
	EventBus.territory_selected.emit(_ctx_tile_index)
	EventBus.message_log.emit("招募: 请在领地面板中操作")

func _ctx_build() -> void:
	EventBus.territory_selected.emit(_ctx_tile_index)
	EventBus.message_log.emit("建造: 请在领地面板中操作")

func _ctx_guard() -> void:
	EventBus.message_log.emit("守卫: 军团驻守当前领地")

func _ctx_detail() -> void:
	EventBus.territory_selected.emit(_ctx_tile_index)

func _ctx_attack_selected() -> void:
	if GameManager.selected_army_id < 0:
		return
	_request_attack_confirm(GameManager.selected_army_id, _ctx_tile_index)

func _ctx_explore() -> void:
	EventBus.message_log.emit("探索: 派遣军团前往该区域")

func _ctx_diplomacy() -> void:
	EventBus.message_log.emit("外交: 请在外交面板中操作")


# ═══════════════ KEYBOARD SHORTCUTS ═══════════════

func _handle_keyboard_shortcut(event: InputEventKey) -> void:
	# Ctrl+Z: undo
	if event.keycode == KEY_Z and event.ctrl_pressed:
		_undo_last_action()
		get_viewport().set_input_as_handled()
		return
	# Don't process shortcuts when a GUI element has focus (typing, etc.)
	if get_viewport() and get_viewport().gui_get_focus_owner() != null:
		return
	match event.keycode:
		KEY_ESCAPE:
			if _input_mode != "normal":
				_cancel_input_mode()
			else:
				_deselect_tile()
				_hide_context_menu()
				_hide_attack_confirm()
			get_viewport().set_input_as_handled()
		KEY_E:
			if not event.ctrl_pressed:
				GameManager.end_turn()
				get_viewport().set_input_as_handled()
		KEY_SPACE:
			if GameManager.selected_army_id >= 0:
				var army: Dictionary = GameManager.get_army(GameManager.selected_army_id)
				if not army.is_empty():
					focus_on_tile(army["tile_index"])
			elif selected_tile >= 0:
				focus_on_tile(selected_tile)
			get_viewport().set_input_as_handled()
		KEY_TAB:
			_cycle_player_armies()
			get_viewport().set_input_as_handled()
		KEY_A:
			if not event.ctrl_pressed and GameManager.selected_army_id >= 0:
				_enter_attack_mode()
				get_viewport().set_input_as_handled()
		KEY_D:
			if not event.ctrl_pressed and GameManager.selected_army_id >= 0:
				_enter_deploy_mode()
				get_viewport().set_input_as_handled()

func _enter_attack_mode() -> void:
	if GameManager.selected_army_id < 0:
		return
	var atk: Array = GameManager.get_army_attackable_tiles(GameManager.selected_army_id)
	if atk.is_empty():
		EventBus.message_log.emit("无可攻击目标")
		return
	_input_mode = "attack"
	_clear_highlights()
	show_attackable(atk)
	EventBus.message_log.emit("出击模式: 点击红色目标发动攻击, Esc取消")

func _enter_deploy_mode() -> void:
	if GameManager.selected_army_id < 0:
		return
	var dep: Array = GameManager.get_army_deployable_tiles(GameManager.selected_army_id)
	if dep.is_empty():
		EventBus.message_log.emit("无可部署目标")
		return
	_input_mode = "deploy"
	_clear_highlights()
	show_deployable(dep)
	EventBus.message_log.emit("部署模式: 点击绿色目标部署军团, Esc取消")

func _cancel_input_mode() -> void:
	_input_mode = "normal"
	_clear_highlights()
	# Re-show highlights for selected army if any
	if GameManager.selected_army_id >= 0 and selected_tile >= 0:
		var pid: int = GameManager.get_human_player_id()
		var army: Dictionary = GameManager.get_army(GameManager.selected_army_id)
		if not army.is_empty() and army["player_id"] == pid:
			for dt in GameManager.get_army_deployable_tiles(army["id"]):
				_add_highlight_fill(dt, COL_DEPLOY_FILL)
				_add_highlight_ring(dt, Color(0.2, 0.9, 0.3, 0.6))
			for at in GameManager.get_army_attackable_tiles(army["id"]):
				_add_highlight_fill(at, COL_ATTACK_FILL)
				_add_highlight_ring(at, Color(0.9, 0.2, 0.2, 0.6))

func _handle_mode_click_attack(tile_index: int) -> void:
	if GameManager.selected_army_id < 0:
		_cancel_input_mode()
		return
	var atk: Array = GameManager.get_army_attackable_tiles(GameManager.selected_army_id)
	if atk.has(tile_index):
		_request_attack_confirm(GameManager.selected_army_id, tile_index)
	_cancel_input_mode()

func _handle_mode_click_deploy(tile_index: int) -> void:
	if GameManager.selected_army_id < 0:
		_cancel_input_mode()
		return
	var dep: Array = GameManager.get_army_deployable_tiles(GameManager.selected_army_id)
	if dep.has(tile_index):
		_execute_deploy_with_undo(GameManager.selected_army_id, tile_index)
	_cancel_input_mode()

func _cycle_player_armies() -> void:
	var pid: int = GameManager.get_human_player_id()
	var armies: Array = GameManager.get_player_armies(pid)
	if armies.is_empty():
		EventBus.message_log.emit("没有军团")
		return
	var current_id: int = GameManager.selected_army_id
	var next_idx: int = 0
	if current_id >= 0:
		for i in range(armies.size()):
			if armies[i]["id"] == current_id:
				next_idx = (i + 1) % armies.size()
				break
	var next_army: Dictionary = armies[next_idx]
	GameManager.select_army(next_army["id"])
	selected_tile = next_army["tile_index"]
	_clear_highlights(); _start_pulse_ring(selected_tile)
	_update_territory_visual(selected_tile)
	focus_on_tile(selected_tile)
	for dt in GameManager.get_army_deployable_tiles(next_army["id"]):
		_add_highlight_fill(dt, COL_DEPLOY_FILL)
		_add_highlight_ring(dt, Color(0.2, 0.9, 0.3, 0.6))
	for at in GameManager.get_army_attackable_tiles(next_army["id"]):
		_add_highlight_fill(at, COL_ATTACK_FILL)
		_add_highlight_ring(at, Color(0.9, 0.2, 0.2, 0.6))
	EventBus.message_log.emit("选中军团: %s" % next_army.get("name", "军团"))


# ═══════════════ ATTACK CONFIRMATION ═══════════════
var _atk_confirm_canvas: CanvasLayer
var _atk_confirm_panel: PanelContainer
var _atk_confirm_army_id: int = -1
var _atk_confirm_target_tile: int = -1
var _atk_info_label: RichTextLabel
var _atk_confirm_btn: Button
var _atk_cancel_btn: Button

func _setup_attack_confirm_panel() -> void:
	_atk_confirm_canvas = CanvasLayer.new()
	_atk_confirm_canvas.name = "AttackConfirmLayer"
	_atk_confirm_canvas.layer = 12
	add_child(_atk_confirm_canvas)
	# Dimmed background
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.45)
	dim.anchor_right = 1.0; dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	_atk_confirm_canvas.add_child(dim)
	# Center container
	var center := CenterContainer.new()
	center.name = "Center"
	center.anchor_right = 1.0; center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	_atk_confirm_canvas.add_child(center)
	# Main panel
	_atk_confirm_panel = PanelContainer.new()
	_atk_confirm_panel.name = "AtkConfirmPanel"
	_atk_confirm_panel.custom_minimum_size = Vector2(420, 300)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.05, 0.95)
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 16; sb.content_margin_right = 16
	sb.content_margin_top = 12; sb.content_margin_bottom = 12
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.55, 0.13, 0.8)
	_atk_confirm_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_atk_confirm_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_atk_confirm_panel.add_child(vbox)
	# Title
	var title := Label.new()
	title.text = "⚔ 出击确认"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)
	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)
	# Info label (RichTextLabel for flexible layout)
	_atk_info_label = RichTextLabel.new()
	_atk_info_label.bbcode_enabled = true
	_atk_info_label.fit_content = true
	_atk_info_label.scroll_active = false
	_atk_info_label.custom_minimum_size = Vector2(390, 160)
	_atk_info_label.add_theme_font_size_override("normal_font_size", 16)
	_atk_info_label.add_theme_color_override("default_color", Color(0.9, 0.88, 0.82))
	vbox.add_child(_atk_info_label)
	# Button row
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	_atk_confirm_btn = Button.new()
	_atk_confirm_btn.text = "确认出击 (1 AP)"
	_atk_confirm_btn.custom_minimum_size = Vector2(160, 38)
	_atk_confirm_btn.add_theme_font_size_override("font_size", 16)
	_atk_confirm_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.85))
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.7, 0.15, 0.1, 0.9)
	btn_sb.corner_radius_top_left = 4; btn_sb.corner_radius_top_right = 4
	btn_sb.corner_radius_bottom_left = 4; btn_sb.corner_radius_bottom_right = 4
	btn_sb.border_width_left = 1; btn_sb.border_width_top = 1
	btn_sb.border_width_right = 1; btn_sb.border_width_bottom = 1
	btn_sb.border_color = Color(0.9, 0.3, 0.2, 0.7)
	_atk_confirm_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_sb_h := btn_sb.duplicate()
	btn_sb_h.bg_color = Color(0.85, 0.2, 0.12, 0.95)
	_atk_confirm_btn.add_theme_stylebox_override("hover", btn_sb_h)
	_atk_confirm_btn.pressed.connect(_on_attack_confirmed)
	hbox.add_child(_atk_confirm_btn)
	_atk_cancel_btn = Button.new()
	_atk_cancel_btn.text = "取消"
	_atk_cancel_btn.custom_minimum_size = Vector2(100, 38)
	_atk_cancel_btn.add_theme_font_size_override("font_size", 16)
	var cbtn_sb := StyleBoxFlat.new()
	cbtn_sb.bg_color = Color(0.3, 0.3, 0.28, 0.85)
	cbtn_sb.corner_radius_top_left = 4; cbtn_sb.corner_radius_top_right = 4
	cbtn_sb.corner_radius_bottom_left = 4; cbtn_sb.corner_radius_bottom_right = 4
	_atk_cancel_btn.add_theme_stylebox_override("normal", cbtn_sb)
	var cbtn_sb_h := cbtn_sb.duplicate()
	cbtn_sb_h.bg_color = Color(0.4, 0.4, 0.38, 0.9)
	_atk_cancel_btn.add_theme_stylebox_override("hover", cbtn_sb_h)
	_atk_cancel_btn.pressed.connect(_on_attack_cancelled)
	hbox.add_child(_atk_cancel_btn)
	_hide_attack_confirm()

func _request_attack_confirm(army_id: int, target_tile: int) -> void:
	_atk_confirm_army_id = army_id
	_atk_confirm_target_tile = target_tile
	var army: Dictionary = GameManager.get_army(army_id)
	if army.is_empty():
		return
	var tile: Dictionary = GameManager.tiles[target_tile]
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
	var terrain_name: String = terrain_data.get("name", "未知")
	var atk_mult: float = terrain_data.get("atk_mult", 1.0)
	var def_mult: float = terrain_data.get("def_mult", 1.0)
	# Attacker info
	var atk_soldiers: int = GameManager.get_army_soldier_count(army_id)
	var atk_name: String = army.get("name", "军团")
	var heroes: Array = army.get("heroes", [])
	var hero_count: int = heroes.size()
	# Defender info
	var garrison: int = tile.get("garrison", 0)
	var defender_army: Dictionary = GameManager.get_army_at_tile(target_tile)
	var def_soldiers: int = garrison
	if not defender_army.is_empty():
		def_soldiers += GameManager.get_army_soldier_count(defender_army.get("id", -1))
	# Build BBCode info text
	var bbtext: String = ""
	bbtext += "[color=#daa520]【攻击方】[/color]\n"
	bbtext += "  军团: %s\n" % atk_name
	bbtext += "  兵力: %d\n" % atk_soldiers
	if hero_count > 0:
		bbtext += "  英雄: %d人\n" % hero_count
	bbtext += "\n[color=#cc4444]【防御方】[/color]\n"
	bbtext += "  驻军: %d\n" % garrison
	if not defender_army.is_empty():
		bbtext += "  军团兵力: %d\n" % GameManager.get_army_soldier_count(defender_army.get("id", -1))
	bbtext += "  地形: %s\n" % terrain_name
	bbtext += "\n[color=#aaaaaa]地形效果: %s  防御×%.2f  攻击×%.2f[/color]\n" % [terrain_name, def_mult, atk_mult]
	if tile.get("is_chokepoint", false):
		bbtext += "[color=#ff6633]⚠ 关隘: 额外+20%%防御[/color]\n"
	_atk_info_label.text = bbtext
	_show_attack_confirm()

func _show_attack_confirm() -> void:
	if not is_instance_valid(_atk_confirm_canvas):
		return
	var dim: ColorRect = _atk_confirm_canvas.get_node_or_null("Dim")
	var center: CenterContainer = _atk_confirm_canvas.get_node_or_null("Center")
	if dim:
		dim.visible = true
	if center:
		center.visible = true

func _hide_attack_confirm() -> void:
	if not is_instance_valid(_atk_confirm_canvas):
		return
	var dim: ColorRect = _atk_confirm_canvas.get_node_or_null("Dim")
	var center: CenterContainer = _atk_confirm_canvas.get_node_or_null("Center")
	if dim:
		dim.visible = false
	if center:
		center.visible = false
	_atk_confirm_army_id = -1
	_atk_confirm_target_tile = -1

func _on_attack_confirmed() -> void:
	var aid: int = _atk_confirm_army_id
	var tid: int = _atk_confirm_target_tile
	_hide_attack_confirm()
	_cancel_input_mode()
	if aid >= 0 and tid >= 0:
		GameManager.action_attack_with_army(aid, tid)
		_deselect_tile()

func _on_attack_cancelled() -> void:
	_hide_attack_confirm()
	_cancel_input_mode()


# ═══════════════ UNDO SYSTEM ═══════════════

func _execute_deploy_with_undo(army_id: int, target_tile: int) -> void:
	## Deploy army and push to undo stack for Ctrl+Z reversal.
	var army: Dictionary = GameManager.get_army(army_id)
	if army.is_empty():
		return
	var from_tile: int = army["tile_index"]
	var tile: Dictionary = GameManager.tiles[target_tile] if target_tile < GameManager.tiles.size() else {}
	var ap_cost: int = tile.get("terrain_move_cost", 1)
	var success: bool = GameManager.action_deploy_army(army_id, target_tile)
	if success:
		if _undo_stack.size() >= _UNDO_MAX:
			_undo_stack.pop_front()
		_undo_stack.append({
			"type": "deploy",
			"army_id": army_id,
			"from_tile": from_tile,
			"to_tile": target_tile,
			"ap_cost": ap_cost,
		})
		_deselect_tile()

func _undo_last_action() -> void:
	if _undo_stack.is_empty():
		EventBus.message_log.emit("没有可撤销的操作")
		return
	var action: Dictionary = _undo_stack.pop_back()
	if action["type"] == "deploy":
		_undo_deploy(action)

func _undo_deploy(action: Dictionary) -> void:
	var army_id: int = action["army_id"]
	var from_tile: int = action["from_tile"]
	var to_tile: int = action["to_tile"]
	var ap_cost: int = action["ap_cost"]
	var army: Dictionary = GameManager.get_army(army_id)
	if army.is_empty():
		EventBus.message_log.emit("撤销失败: 军团不存在")
		return
	if army["tile_index"] != to_tile:
		EventBus.message_log.emit("撤销失败: 军团已移动到其他位置")
		return
	# Check the original tile is free
	var occupant: Dictionary = GameManager.get_army_at_tile(from_tile)
	if not occupant.is_empty():
		EventBus.message_log.emit("撤销失败: 原位置已有其他军团")
		return
	# Directly reverse: move army back and restore AP
	army["tile_index"] = from_tile
	var pid: int = army["player_id"]
	var player: Dictionary = GameManager.get_player_by_id(pid)
	if not player.is_empty():
		player["ap"] = player.get("ap", 0) + ap_cost
		EventBus.ap_changed.emit(pid, player["ap"])
	EventBus.army_deployed.emit(pid, army_id, to_tile, from_tile)
	_update_territory_visual(from_tile)
	_update_territory_visual(to_tile)
	_spawn_undo_toast(from_tile)
	EventBus.message_log.emit("↩ 已撤销部署")

func _spawn_undo_toast(tile_index: int) -> void:
	## Floating "↩ 已撤销" text at the tile.
	if not tile_visuals.has(tile_index):
		return
	var vis: Dictionary = tile_visuals[tile_index]
	var root: Node3D = vis["root"]
	var toast := Label3D.new()
	toast.text = "↩ 已撤销"
	toast.font_size = 36
	toast.pixel_size = 0.01
	toast.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	toast.no_depth_test = true
	toast.modulate = Color(0.3, 0.85, 1.0)
	toast.outline_modulate = Color(0, 0, 0, 0.9)
	toast.outline_size = 12
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position = Vector3(0, 2.5, 0)
	root.add_child(toast)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(toast, "position:y", 4.5, 1.2)
	tw.tween_property(toast, "modulate:a", 0.0, 1.2).set_delay(0.2)
	tw.chain().tween_callback(func():
		if is_instance_valid(toast):
			toast.queue_free()
	)


# ═══════════════ HOVER INFO PANEL ═══════════════
var _hover_canvas: CanvasLayer
var _hover_panel: PanelContainer
var _hover_vbox: VBoxContainer
var _hover_name_lbl: Label
var _hover_terrain_lbl: Label
var _hover_sep1: HSeparator
var _hover_faction_lbl: Label
var _hover_garrison_lbl: Label
var _hover_army_lbl: Label
var _hover_sep2: HSeparator
var _hover_atk_lbl: Label
var _hover_def_lbl: Label
var _hover_prod_lbl: Label
var _hover_building_lbl: Label
var _hover_delay: float = 0.0
var _hover_active_tile: int = -1
const HOVER_DELAY_SEC: float = 0.3

# placeholder: hover setup, show, hide, update

func _setup_hover_panel() -> void:
	_hover_canvas = CanvasLayer.new()
	_hover_canvas.name = "HoverInfoLayer"
	_hover_canvas.layer = 9
	add_child(_hover_canvas)
	_hover_panel = PanelContainer.new()
	_hover_panel.name = "HoverInfoPanel"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.05, 0.92)
	sb.corner_radius_top_left = 6; sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6; sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.65, 0.13, 0.7)
	_hover_panel.add_theme_stylebox_override("panel", sb)
	_hover_panel.visible = false
	_hover_canvas.add_child(_hover_panel)
	_hover_vbox = VBoxContainer.new()
	_hover_vbox.add_theme_constant_override("separation", 2)
	_hover_panel.add_child(_hover_vbox)
	_hover_name_lbl = _make_hover_label(20, Color(1.0, 0.85, 0.3))
	_hover_terrain_lbl = _make_hover_label(14, Color(0.8, 0.78, 0.7))
	_hover_sep1 = HSeparator.new()
	_hover_sep1.add_theme_constant_override("separation", 2)
	_hover_vbox.add_child(_hover_sep1)
	_hover_faction_lbl = _make_hover_label(14, Color(0.9, 0.88, 0.82))
	_hover_garrison_lbl = _make_hover_label(14, Color(0.9, 0.88, 0.82))
	_hover_army_lbl = _make_hover_label(14, Color(1.0, 0.6, 0.3))
	_hover_sep2 = HSeparator.new()
	_hover_sep2.add_theme_constant_override("separation", 2)
	_hover_vbox.add_child(_hover_sep2)
	_hover_atk_lbl = _make_hover_label(13, Color(0.85, 0.75, 0.65))
	_hover_def_lbl = _make_hover_label(13, Color(0.85, 0.75, 0.65))
	_hover_prod_lbl = _make_hover_label(13, Color(0.85, 0.75, 0.65))
	_hover_building_lbl = _make_hover_label(13, Color(0.85, 0.75, 0.65))

func _make_hover_label(font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	_hover_vbox.add_child(lbl)
	return lbl

func _show_hover_info(tile_index: int) -> void:
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		_hide_hover_info(); return
	var pid: int = GameManager.get_human_player_id()
	if not GameManager.is_revealed_for(tile_index, pid):
		_hide_hover_info(); return
	var tile: Dictionary = GameManager.tiles[tile_index]
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
	var terrain_name: String = terrain_data.get("name", "未知")
	var tile_name: String = tile.get("name", "#%d" % tile_index)
	var type_str: String = ""
	var tt = tile.get("type", -1)
	if tile.get("is_chokepoint", false):
		type_str = "关隘"
	elif tt == GameManager.TileType.CORE_FORTRESS:
		type_str = "主城"
	elif tt == GameManager.TileType.TRADING_POST:
		type_str = "贸易站"
	elif tt == GameManager.TileType.WATCHTOWER:
		type_str = "瞭望塔"
	elif tt == GameManager.TileType.HARBOR:
		type_str = "港口"
	elif tt == GameManager.TileType.RUINS:
		type_str = "遗迹"
	elif tt == GameManager.TileType.MINE_TILE:
		type_str = "矿场"
	elif tt == GameManager.TileType.EVENT_TILE:
		type_str = "事件"
	_hover_name_lbl.text = tile_name
	_hover_terrain_lbl.text = terrain_name + (" · " + type_str if type_str != "" else "")
	var owner_id: int = tile.get("owner_id", -1)
	if owner_id >= 0:
		var fid: int = GameManager.get_player_faction(owner_id)
		var faction_name: String = FactionData.FACTION_NAMES.get(fid, "")
		if faction_name == "":
			var lf: int = tile.get("light_faction", -1)
			faction_name = FactionData.LIGHT_FACTION_NAMES.get(lf, "中立")
		var fk: String = _get_tile_faction_key(tile)
		var fc: Color = FACTION_COLORS.get(fk, FACTION_COLORS["none"])
		_hover_faction_lbl.text = "阵营: " + faction_name
		_hover_faction_lbl.add_theme_color_override("font_color", fc.lightened(0.3))
	else:
		_hover_faction_lbl.text = "阵营: 中立"
		_hover_faction_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	var garrison: int = tile.get("garrison", 0)
	var max_garrison: int = tile.get("max_garrison", garrison)
	if max_garrison <= 0:
		max_garrison = garrison
	_hover_garrison_lbl.text = "驻军: %d/%d" % [garrison, max_garrison] if garrison > 0 else "驻军: 无"
	var army: Dictionary = GameManager.get_army_at_tile(tile_index)
	if not army.is_empty():
		var sc: int = GameManager.get_army_soldier_count(army.get("id", -1))
		_hover_army_lbl.text = "军团: %s (⚔%d)" % [army.get("name", "军团"), sc]
		_hover_army_lbl.visible = true
	else:
		_hover_army_lbl.text = ""
		_hover_army_lbl.visible = false
	var atk_mult: float = terrain_data.get("atk_mult", 1.0)
	var def_mult: float = terrain_data.get("def_mult", 1.0)
	_hover_atk_lbl.text = "攻击修正: ×%.2f" % atk_mult
	_hover_def_lbl.text = "防御修正: ×%.2f" % def_mult
	var prod_text: String = ""
	var tile_type_prod = tile.get("type", -1)
	if GameManager.PROD_RANGES.has(tile_type_prod):
		var pr: Dictionary = GameManager.PROD_RANGES[tile_type_prod]
		var parts: Array = []
		for rk in ["gold", "food", "iron"]:
			if pr.has(rk):
				var avg: int = int((pr[rk][0] + pr[rk][1]) * 0.5)
				if avg > 0:
					var label_cn: String = "金" if rk == "gold" else ("粮" if rk == "food" else "铁")
					parts.append("%s%d" % [label_cn, avg])
		if not parts.is_empty():
			prod_text = "产出: " + " ".join(parts)
	_hover_prod_lbl.text = prod_text
	_hover_prod_lbl.visible = prod_text != ""
	var building_id: String = tile.get("building_id", "")
	var building_level: int = tile.get("building_level", 0)
	if building_id != "" and building_level > 0:
		_hover_building_lbl.text = "建筑: %s Lv.%d" % [building_id, building_level]
		_hover_building_lbl.visible = true
	else:
		_hover_building_lbl.text = ""
		_hover_building_lbl.visible = false
	_hover_panel.visible = true

func _hide_hover_info() -> void:
	if is_instance_valid(_hover_panel):
		_hover_panel.visible = false
	_hover_delay = 0.0
	_hover_active_tile = -1

func _update_hover_panel_position() -> void:
	if not is_instance_valid(_hover_panel) or not _hover_panel.visible:
		return
	var vp := get_viewport()
	if not vp:
		return
	var mpos: Vector2 = vp.get_mouse_position()
	var vs: Vector2 = vp.get_visible_rect().size
	var offset := Vector2(20, 20)
	var pos := mpos + offset
	if pos.x + 240 > vs.x:
		pos.x = mpos.x - 260
	if pos.y + 300 > vs.y:
		pos.y = mpos.y - 320
	_hover_panel.position = pos

func _process_hover_delay(delta: float) -> void:
	if hovered_tile < 0:
		_hide_hover_info()
		return
	if _hover_active_tile == hovered_tile and is_instance_valid(_hover_panel) and _hover_panel.visible:
		_update_hover_panel_position()
		return
	if _hover_active_tile != hovered_tile:
		_hover_delay = 0.0
		_hover_active_tile = hovered_tile
		if is_instance_valid(_hover_panel):
			_hover_panel.visible = false
	_hover_delay += delta
	if _hover_delay >= HOVER_DELAY_SEC:
		_show_hover_info(_hover_active_tile)
		_update_hover_panel_position()


# ═══════════════ TURN SUMMARY ═══════════════
var _turn_summary_canvas: CanvasLayer
var _turn_summary_panel: PanelContainer
var _turn_summary_title: Label
var _turn_summary_body: RichTextLabel
var _turn_summary_btn: Button
var _last_turn_snapshot: Dictionary = {}

# placeholder: turn summary setup, show, dismiss, snapshot

func _setup_turn_summary() -> void:
	_turn_summary_canvas = CanvasLayer.new()
	_turn_summary_canvas.name = "TurnSummaryLayer"
	_turn_summary_canvas.layer = 13
	add_child(_turn_summary_canvas)
	# Dimmed backdrop
	var dim := ColorRect.new()
	dim.name = "TurnSummaryDim"
	dim.color = Color(0, 0, 0, 0.5)
	dim.anchor_right = 1.0; dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	_turn_summary_canvas.add_child(dim)
	# Centered container
	var center := CenterContainer.new()
	center.name = "TurnSummaryCenter"
	center.anchor_right = 1.0; center.anchor_bottom = 1.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	_turn_summary_canvas.add_child(center)
	# Panel
	_turn_summary_panel = PanelContainer.new()
	_turn_summary_panel.name = "TurnSummaryPanel"
	_turn_summary_panel.custom_minimum_size = Vector2(500, 400)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.05, 0.95)
	sb.corner_radius_top_left = 8; sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8; sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 20; sb.content_margin_right = 20
	sb.content_margin_top = 16; sb.content_margin_bottom = 16
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.65, 0.13, 0.8)
	_turn_summary_panel.add_theme_stylebox_override("panel", sb)
	center.add_child(_turn_summary_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_turn_summary_panel.add_child(vbox)
	# Title
	_turn_summary_title = Label.new()
	_turn_summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_summary_title.add_theme_font_size_override("font_size", 28)
	_turn_summary_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(_turn_summary_title)
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	vbox.add_child(sep)
	# Body
	_turn_summary_body = RichTextLabel.new()
	_turn_summary_body.bbcode_enabled = true
	_turn_summary_body.fit_content = true
	_turn_summary_body.scroll_active = true
	_turn_summary_body.custom_minimum_size = Vector2(460, 260)
	_turn_summary_body.add_theme_font_size_override("normal_font_size", 15)
	_turn_summary_body.add_theme_color_override("default_color", Color(0.9, 0.88, 0.82))
	vbox.add_child(_turn_summary_body)
	# Button
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)
	_turn_summary_btn = Button.new()
	_turn_summary_btn.text = "开始行动"
	_turn_summary_btn.custom_minimum_size = Vector2(160, 40)
	_turn_summary_btn.add_theme_font_size_override("font_size", 18)
	_turn_summary_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.85))
	var btn_sb := StyleBoxFlat.new()
	btn_sb.bg_color = Color(0.65, 0.5, 0.12, 0.9)
	btn_sb.corner_radius_top_left = 4; btn_sb.corner_radius_top_right = 4
	btn_sb.corner_radius_bottom_left = 4; btn_sb.corner_radius_bottom_right = 4
	btn_sb.border_width_left = 1; btn_sb.border_width_top = 1
	btn_sb.border_width_right = 1; btn_sb.border_width_bottom = 1
	btn_sb.border_color = Color(0.85, 0.65, 0.13, 0.7)
	_turn_summary_btn.add_theme_stylebox_override("normal", btn_sb)
	var btn_sb_h := btn_sb.duplicate()
	btn_sb_h.bg_color = Color(0.8, 0.6, 0.15, 0.95)
	_turn_summary_btn.add_theme_stylebox_override("hover", btn_sb_h)
	_turn_summary_btn.pressed.connect(_dismiss_turn_summary)
	btn_hbox.add_child(_turn_summary_btn)
	_hide_turn_summary()

func _take_turn_snapshot() -> void:
	var pid: int = GameManager.get_human_player_id()
	var owned: Array = []
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == pid:
			owned.append(tile["index"])
	var visible_armies: Array = []
	for aid in GameManager.armies:
		var a: Dictionary = GameManager.armies[aid]
		if a["player_id"] != pid and GameManager.is_revealed_for(a["tile_index"], pid):
			visible_armies.append({"id": aid, "tile": a["tile_index"], "name": a.get("name", "")})
	var res: Dictionary = {}
	if ResourceManager and ResourceManager.has_method("get_all"):
		res = ResourceManager.get_all(pid)
	_last_turn_snapshot = {
		"owned_tiles": owned,
		"visible_armies": visible_armies,
		"resources": res,
		"turn": GameManager.turn_number,
	}

func _show_turn_summary() -> void:
	var pid: int = GameManager.get_human_player_id()
	var turn_num: int = GameManager.turn_number
	# Skip turn 1 summary (nothing happened yet)
	if turn_num <= 1 and _last_turn_snapshot.is_empty():
		_take_turn_snapshot()
		return
	_turn_summary_title.text = "第 %d 回合" % turn_num
	var bb: String = ""
	# Territory changes
	var current_owned: Array = []
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == pid:
			current_owned.append(tile["index"])
	var prev_owned: Array = _last_turn_snapshot.get("owned_tiles", [])
	var gained: Array = []
	var lost: Array = []
	for idx in current_owned:
		if not prev_owned.has(idx):
			gained.append(idx)
	for idx in prev_owned:
		if not current_owned.has(idx):
			lost.append(idx)
	bb += "[color=#daa520]【领地变动】[/color]\n"
	if gained.is_empty() and lost.is_empty():
		bb += "  无变化\n"
	else:
		if not gained.is_empty():
			var names: Array = []
			for idx in gained:
				if idx < GameManager.tiles.size():
					names.append(GameManager.tiles[idx].get("name", "#%d" % idx))
			bb += "  [color=#66cc66]占领: %s[/color]\n" % ", ".join(names)
		if not lost.is_empty():
			var names: Array = []
			for idx in lost:
				if idx < GameManager.tiles.size():
					names.append(GameManager.tiles[idx].get("name", "#%d" % idx))
			bb += "  [color=#cc4444]失去: %s[/color]\n" % ", ".join(names)
	# Enemy movements
	bb += "\n[color=#daa520]【敌军动向】[/color]\n"
	var prev_armies: Array = _last_turn_snapshot.get("visible_armies", [])
	var current_vis: Array = []
	for aid in GameManager.armies:
		var a: Dictionary = GameManager.armies[aid]
		if a["player_id"] != pid and GameManager.is_revealed_for(a["tile_index"], pid):
			current_vis.append({"id": aid, "tile": a["tile_index"], "name": a.get("name", "")})
	if current_vis.is_empty():
		bb += "  未发现敌军活动\n"
	else:
		var new_sightings: int = 0
		for vis in current_vis:
			var was_seen: bool = false
			for prev in prev_armies:
				if prev["id"] == vis["id"] and prev["tile"] == vis["tile"]:
					was_seen = true; break
			if not was_seen:
				new_sightings += 1
		if new_sightings > 0:
			bb += "  发现 %d 支敌军移动\n" % new_sightings
		else:
			bb += "  敌军位置未变\n"
	# Resources
	bb += "\n[color=#daa520]【资源】[/color]\n"
	var res: Dictionary = {}
	if ResourceManager and ResourceManager.has_method("get_all"):
		res = ResourceManager.get_all(pid)
	if not res.is_empty():
		var gold_val: int = res.get("gold", 0)
		var food_val: int = res.get("food", 0)
		var iron_val: int = res.get("iron", 0)
		bb += "  金: %d  粮: %d  铁: %d\n" % [gold_val, food_val, iron_val]
	else:
		bb += "  暂无数据\n"
	_turn_summary_body.text = bb
	# Show with fade-in
	var dim: ColorRect = _turn_summary_canvas.get_node_or_null("TurnSummaryDim")
	var center: CenterContainer = _turn_summary_canvas.get_node_or_null("TurnSummaryCenter")
	if dim:
		dim.visible = true; dim.modulate.a = 0.0
	if center:
		center.visible = true; center.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	if dim:
		tw.tween_property(dim, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	if center:
		tw.tween_property(center, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	# Take snapshot for next turn comparison
	_take_turn_snapshot()

func _dismiss_turn_summary() -> void:
	_hide_turn_summary()

func _hide_turn_summary() -> void:
	if not is_instance_valid(_turn_summary_canvas):
		return
	var dim: ColorRect = _turn_summary_canvas.get_node_or_null("TurnSummaryDim")
	var center: CenterContainer = _turn_summary_canvas.get_node_or_null("TurnSummaryCenter")
	if dim:
		dim.visible = false
	if center:
		center.visible = false


# ═══════════════ MINIMAP ═══════════════
var _minimap_canvas: CanvasLayer
var _minimap_draw: Control
var _minimap_bg: ColorRect
const MINIMAP_W: float = 200.0
const MINIMAP_H: float = 150.0
const MINIMAP_MARGIN: float = 12.0
const MINIMAP_MAP_MIN := Vector2(-5.0, -25.0)
const MINIMAP_MAP_MAX := Vector2(30.0, 5.0)

# placeholder: minimap setup, draw, click

func _setup_custom_minimap() -> void:
	_minimap_canvas = CanvasLayer.new()
	_minimap_canvas.name = "CustomMinimapLayer"
	_minimap_canvas.layer = 8
	add_child(_minimap_canvas)
	# Background frame
	var frame := PanelContainer.new()
	frame.name = "MinimapFrame"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.04, 0.85)
	sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.85, 0.65, 0.13, 0.6)
	sb.content_margin_left = 0; sb.content_margin_right = 0
	sb.content_margin_top = 0; sb.content_margin_bottom = 0
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size = Vector2(MINIMAP_W, MINIMAP_H)
	frame.anchor_left = 1.0; frame.anchor_right = 1.0
	frame.anchor_top = 1.0; frame.anchor_bottom = 1.0
	frame.offset_left = -(MINIMAP_W + MINIMAP_MARGIN)
	frame.offset_right = -MINIMAP_MARGIN
	frame.offset_top = -(MINIMAP_H + MINIMAP_MARGIN)
	frame.offset_bottom = -MINIMAP_MARGIN
	_minimap_canvas.add_child(frame)
	# Draw control
	_minimap_draw = MinimapDrawControl.new()
	_minimap_draw.name = "MinimapDraw"
	_minimap_draw.custom_minimum_size = Vector2(MINIMAP_W, MINIMAP_H)
	_minimap_draw.board_ref = self
	_minimap_draw.mouse_filter = Control.MOUSE_FILTER_STOP
	_minimap_draw.gui_input.connect(_on_custom_minimap_input)
	frame.add_child(_minimap_draw)

func _on_custom_minimap_input(event: InputEvent) -> void:
	var is_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_drag := event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not is_click and not is_drag:
		return
	if not is_instance_valid(_minimap_draw):
		return
	var msize: Vector2 = _minimap_draw.size
	if msize.x < 1.0 or msize.y < 1.0:
		return
	var local_pos: Vector2 = event.position
	var norm_x: float = clampf(local_pos.x / msize.x, 0.0, 1.0)
	var norm_y: float = clampf(local_pos.y / msize.y, 0.0, 1.0)
	var map_size := MINIMAP_MAP_MAX - MINIMAP_MAP_MIN
	camera_target_pos.x = MINIMAP_MAP_MIN.x + norm_x * map_size.x
	camera_target_pos.z = MINIMAP_MAP_MIN.y + norm_y * map_size.y
	_clamp_camera()

func _redraw_custom_minimap() -> void:
	if is_instance_valid(_minimap_draw):
		_minimap_draw.queue_redraw()


# ── Inner class for minimap custom drawing ──
class MinimapDrawControl:
	extends Control
	var board_ref  # Reference to Board (avoid cyclic typed ref)

	func _draw() -> void:
		if board_ref == null:
			return
		var map_min: Vector2 = board_ref.MINIMAP_MAP_MIN
		var map_max: Vector2 = board_ref.MINIMAP_MAP_MAX
		var map_size: Vector2 = map_max - map_min
		var ctrl_size: Vector2 = size
		if ctrl_size.x < 1.0 or ctrl_size.y < 1.0:
			return
		var pid: int = GameManager.get_human_player_id()
		# Draw all tiles as colored circles
		for tile in GameManager.tiles:
			if tile == null:
				continue
			var pos3: Vector3 = tile["position_3d"]
			var nx: float = (pos3.x - map_min.x) / map_size.x
			var ny: float = (pos3.z - map_min.y) / map_size.y
			var draw_pos := Vector2(nx * ctrl_size.x, ny * ctrl_size.y)
			var idx: int = tile["index"]
			var revealed: bool = GameManager.is_revealed_for(idx, pid)
			if not revealed:
				draw_circle(draw_pos, 3.0, Color(0.4, 0.38, 0.32, 0.6))
				continue
			var fk: String = board_ref._get_tile_faction_key(tile)
			var col: Color = board_ref.FACTION_COLORS.get(fk, board_ref.FACTION_COLORS["none"])
			draw_circle(draw_pos, 3.5, col)
		# Draw player armies as white diamonds
		for aid in GameManager.armies:
			var army: Dictionary = GameManager.armies[aid]
			var ti: int = army["tile_index"]
			if ti < 0 or ti >= GameManager.tiles.size():
				continue
			if army["player_id"] != pid:
				if not GameManager.is_revealed_for(ti, pid):
					continue
			var tpos: Vector3 = GameManager.tiles[ti]["position_3d"]
			var nx: float = (tpos.x - map_min.x) / map_size.x
			var ny: float = (tpos.z - map_min.y) / map_size.y
			var dp := Vector2(nx * ctrl_size.x, ny * ctrl_size.y)
			var diamond_col: Color
			if army["player_id"] == pid:
				diamond_col = Color(1.0, 1.0, 1.0, 0.95)
			else:
				diamond_col = Color(0.95, 0.25, 0.2, 0.9)
			var ds: float = 4.0
			var diamond := PackedVector2Array([
				dp + Vector2(0, -ds), dp + Vector2(ds, 0),
				dp + Vector2(0, ds), dp + Vector2(-ds, 0)
			])
			draw_colored_polygon(diamond, diamond_col)
		# Draw camera viewport rectangle
		var pivot_pos: Vector3 = board_ref.camera_pivot.global_position if is_instance_valid(board_ref.camera_pivot) else Vector3(9, 0, -8)
		var cam_nx: float = clampf((pivot_pos.x - map_min.x) / map_size.x, 0.0, 1.0)
		var cam_ny: float = clampf((pivot_pos.z - map_min.y) / map_size.y, 0.0, 1.0)
		var view_w: float = 0.2 * ctrl_size.x
		var view_h: float = 0.15 * ctrl_size.y
		var rect_pos := Vector2(cam_nx * ctrl_size.x - view_w * 0.5, cam_ny * ctrl_size.y - view_h * 0.5)
		var rect := Rect2(rect_pos, Vector2(view_w, view_h))
		draw_rect(rect, Color(1.0, 0.9, 0.3, 0.5), false, 1.5)


# ═══════════════ NEW HUD MASTER INIT ═══════════════

func _init_new_hud() -> void:
	_setup_hover_panel()
	_setup_turn_summary()
	_setup_custom_minimap()


# ═══════════════ CAMERA FOLLOW ═══════════════

var _camera_auto_follow: bool = true
var _camera_follow_tween: Tween = null
var _camera_zoom_restore_tween: Tween = null
var _camera_zoom_before_follow: float = -1.0

func _camera_follow_tile(tile_index: int, zoom_in: bool = false) -> void:
	## 平滑将镜头移至指定地块，可选轻微拉近。
	if not _camera_auto_follow: return
	if tile_index < 0 or tile_index >= GameManager.tiles.size(): return
	var p: Vector3 = GameManager.tiles[tile_index]["position_3d"]
	var target := Vector3(p.x, 0.0, p.z)
	if _camera_follow_tween and _camera_follow_tween.is_valid():
		_camera_follow_tween.kill()
	_camera_follow_tween = create_tween()
	_camera_follow_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_camera_follow_tween.tween_property(self, "camera_target_pos", target, 0.5)
	if zoom_in:
		_camera_zoom_before_follow = _camera_zoom_target
		var zoomed := clampf(_camera_zoom_target - 0.15, ZOOM_MIN, ZOOM_MAX)
		_camera_follow_tween.parallel().tween_property(self, "_camera_zoom_target", zoomed, 0.5)

func _camera_follow_delayed(tile_index: int, delay: float) -> void:
	## 延迟后平滑跟随至目标地块（用于军队部署后跟随）。
	if not _camera_auto_follow: return
	if tile_index < 0 or tile_index >= GameManager.tiles.size(): return
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_callback(func(): _camera_follow_tile(tile_index, false))

func _camera_reset_zoom() -> void:
	## 战斗结束后恢复拉近前的缩放级别。
	if _camera_zoom_before_follow < 0.0: return
	if _camera_zoom_restore_tween and _camera_zoom_restore_tween.is_valid():
		_camera_zoom_restore_tween.kill()
	_camera_zoom_restore_tween = create_tween()
	_camera_zoom_restore_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_camera_zoom_restore_tween.tween_property(self, "_camera_zoom_target", _camera_zoom_before_follow, 0.5)
	_camera_zoom_restore_tween.tween_callback(func(): _camera_zoom_before_follow = -1.0)


# ═══════════════ CONQUEST RIPPLE ═══════════════

func _spawn_conquest_ripple(tile_index: int) -> void:
	## 占领地块后生成向外扩散的涟漪环效果。
	if tile_index < 0 or tile_index >= GameManager.tiles.size(): return
	if not tile_visuals.has(tile_index): return
	var tile: Dictionary = GameManager.tiles[tile_index]
	var pos: Vector3 = tile["position_3d"]
	var el: float = tile_visuals[tile_index].get("elevation", 0.0)
	var fk: String = _get_tile_faction_key(tile)
	var fc: Color = FACTION_COLORS.get(fk, FACTION_COLORS["none"])
	# 主涟漪环
	_spawn_single_ripple(pos, el, fc, TILE_RADIUS, TILE_RADIUS * 4.0, 0.4, 1.0, 0.0)
	# 相邻地块级联次级涟漪
	if GameManager.adjacency.has(tile_index):
		var adj_delay: float = 0.2
		for ni in GameManager.adjacency[tile_index]:
			if ni < 0 or ni >= GameManager.tiles.size(): continue
			if not tile_visuals.has(ni): continue
			var np: Vector3 = GameManager.tiles[ni]["position_3d"]
			var ne: float = tile_visuals[ni].get("elevation", 0.0)
			_spawn_single_ripple(np, ne, fc, TILE_RADIUS * 0.6, TILE_RADIUS * 2.5, 0.25, 0.8, adj_delay)
			adj_delay += 0.2

func _spawn_single_ripple(pos: Vector3, elev: float, color: Color, start_r: float, end_r: float, start_alpha: float, duration: float, delay: float) -> void:
	## 生成单个涟漪环：薄圆柱从 start_r 扩展到 end_r 并淡出。
	var ring := MeshInstance3D.new()
	ring.name = "ConquestRipple"
	var cm := CylinderMesh.new()
	cm.top_radius = start_r
	cm.bottom_radius = start_r
	cm.height = 0.02
	cm.radial_segments = 24
	ring.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, start_alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	ring.material_override = mat
	ring.position = Vector3(pos.x, elev + TILE_HEIGHT + 0.04, pos.z)
	ring.visible = false
	add_child(ring)
	var scale_factor: float = end_r / maxf(start_r, 0.01)
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func(): ring.visible = true)
	tw.tween_property(ring, "scale", Vector3(scale_factor, 1.0, scale_factor), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mat, "emission_energy_multiplier", 0.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(ring): ring.queue_free()
	)


# ═══════════════ MARCH PLANNING ═══════════════

var _march_planning_active: bool = false
var _march_planning_army_id: int = -1
var _march_planning_meshes: Array = []
var _march_cost_label: Label3D = null

func _enter_march_planning_mode(army_id: int) -> void:
	## 进入行军规划模式：显示1/2/3步可达范围及路径预览。
	_exit_march_planning_mode()
	var army: Dictionary = GameManager.get_army(army_id)
	if army.is_empty(): return
	_march_planning_active = true
	_march_planning_army_id = army_id
	var origin: int = army.get("tile_index", -1)
	if origin < 0: return
	# BFS 计算1/2/3步可达地块
	var frontier: Array = [origin]
	var visited: Dictionary = {origin: 0}
	var step_tiles: Dictionary = {}
	for step in range(1, 4):
		var next_frontier: Array = []
		for fi in frontier:
			if not GameManager.adjacency.has(fi): continue
			for ni in GameManager.adjacency[fi]:
				if visited.has(ni): continue
				if ni < 0 or ni >= GameManager.tiles.size(): continue
				visited[ni] = step
				step_tiles[ni] = step
				next_frontier.append(ni)
		frontier = next_frontier
	# 绘制不同透明度的高亮
	for tidx in step_tiles:
		var steps: int = step_tiles[tidx]
		var alpha: float
		var green_col: Color
		match steps:
			1:
				green_col = Color(0.2, 0.9, 0.3)
				alpha = 0.30
			2:
				green_col = Color(0.2, 0.75, 0.3)
				alpha = 0.18
			_:
				green_col = Color(0.2, 0.6, 0.25)
				alpha = 0.10
		if not tile_visuals.has(tidx): continue
		var pos: Vector3 = GameManager.tiles[tidx]["position_3d"]
		var el: float = tile_visuals[tidx].get("elevation", 0.0)
		var fill := MeshInstance3D.new()
		fill.name = "MarchPlanFill"
		var fm := CylinderMesh.new()
		fm.top_radius = TILE_RADIUS * 0.92
		fm.bottom_radius = TILE_RADIUS * 0.92
		fm.height = 0.02
		fm.radial_segments = 6
		fill.mesh = fm
		var fmat := StandardMaterial3D.new()
		fmat.albedo_color = Color(green_col.r, green_col.g, green_col.b, alpha)
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fmat.emission_enabled = true
		fmat.emission = green_col
		fmat.emission_energy_multiplier = 0.4
		fill.material_override = fmat
		fill.position = Vector3(pos.x, el + TILE_HEIGHT + 0.035, pos.z)
		add_child(fill)
		_march_planning_meshes.append(fill)

func _exit_march_planning_mode() -> void:
	## 退出行军规划模式，清理所有临时视觉元素。
	_march_planning_active = false
	_march_planning_army_id = -1
	for m in _march_planning_meshes:
		if is_instance_valid(m): m.queue_free()
	_march_planning_meshes.clear()
	_hide_path_cost_label()

func _show_path_cost_label(from_idx: int, to_idx: int) -> void:
	## 在路径中点显示 AP 消耗和补给损耗的浮动标签。
	_hide_path_cost_label()
	if from_idx < 0 or from_idx >= GameManager.tiles.size(): return
	if to_idx < 0 or to_idx >= GameManager.tiles.size(): return
	var fp: Vector3 = GameManager.tiles[from_idx]["position_3d"]
	var tp: Vector3 = GameManager.tiles[to_idx]["position_3d"]
	var fe: float = _get_elev(GameManager.tiles[from_idx])
	var te: float = _get_elev(GameManager.tiles[to_idx])
	# 计算路径 AP 消耗
	var route: Array = GameManager.calculate_attack_route(from_idx, to_idx)
	var full_path: Array = [from_idx] + route if not route.is_empty() else [from_idx, to_idx]
	var total_ap: float = 0.0
	var total_supply_drain: int = 0
	for i in range(1, full_path.size()):
		var ti: int = full_path[i]
		if ti < 0 or ti >= GameManager.tiles.size(): continue
		var terrain_type: int = GameManager.tiles[ti].get("terrain", FactionData.TerrainType.PLAINS)
		var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
		var move_cost: int = terrain_data.get("move_cost", 1)
		total_ap += move_cost
		total_supply_drain += maxi(move_cost, 1) * 4
	# 预计回合数
	var est_turns: int = maxi(ceili(total_ap / 3.0), 1)
	var label_text: String = "AP: %d" % int(total_ap)
	if est_turns > 1:
		label_text += " | %d回合" % est_turns
	label_text += " | 补给: -%d" % total_supply_drain
	var mid_pos := Vector3(
		(fp.x + tp.x) * 0.5,
		maxf(fe, te) + TILE_HEIGHT + 2.0,
		(fp.z + tp.z) * 0.5
	)
	_march_cost_label = Label3D.new()
	_march_cost_label.name = "MarchCostLabel"
	_march_cost_label.text = label_text
	_march_cost_label.font_size = 28
	_march_cost_label.pixel_size = 0.009
	_march_cost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_march_cost_label.no_depth_test = true
	_march_cost_label.modulate = Color(1.0, 0.95, 0.3, 0.95)
	_march_cost_label.outline_modulate = Color(0, 0, 0, 0.9)
	_march_cost_label.outline_size = 12
	_march_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_march_cost_label.position = mid_pos
	add_child(_march_cost_label)

func _hide_path_cost_label() -> void:
	## 清除浮动路径消耗标签。
	if is_instance_valid(_march_cost_label):
		_march_cost_label.queue_free()
	_march_cost_label = null