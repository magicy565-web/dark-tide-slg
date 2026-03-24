## board.gd - Total War: Warhammer style Campaign Map for 暗潮 SLG (v1.0)
## Elevated terrain, faction borders, army figures, settlement growth, smooth camera,
## selection pulse, path preview, fog of war. Godot 4.2 gl_compatibility safe.
extends Node3D
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Visual tracking ──
var tile_visuals: Dictionary = {}
var edge_meshes: Array = []
var army_visuals: Dictionary = {}
var highlight_rings: Dictionary = {}
var faction_border_meshes: Array = []
var path_preview_meshes: Array = []
var settlement_nodes: Dictionary = {}
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
}
const TERRAIN_ELEVATION := {
	FactionData.TerrainType.PLAINS: 0.0, FactionData.TerrainType.FOREST: 0.05,
	FactionData.TerrainType.MOUNTAIN: 0.3, FactionData.TerrainType.SWAMP: -0.05,
	FactionData.TerrainType.COASTAL: 0.0, FactionData.TerrainType.FORTRESS_WALL: 0.2,
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
	var g := MeshInstance3D.new(); var p := PlaneMesh.new(); p.size = Vector2(70, 60); g.mesh = p
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.12, 0.15, 0.1)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; g.material_override = m
	g.position = Vector3(9.0, GROUND_Y - 0.15, -7.0); add_child(g)
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
	_process_camera_input(delta); _process_edge_scroll(delta); _process_hover_path()

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
	settlement_nodes.clear()
	_clear_highlights(); _clear_path_preview(); _clear_pulse_ring()

func _build_board() -> void:
	tile_visuals.clear()
	for tile in GameManager.tiles:
		_build_territory(tile["index"], tile, tile["position_3d"])
	_draw_edges(); _draw_faction_borders()
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
	base_mi.material_override = _make_mat(Color(0.5, 0.5, 0.5)); root.add_child(base_mi)
	# Border ring
	var brm := CylinderMesh.new()
	brm.top_radius = TILE_RADIUS * 1.06; brm.bottom_radius = TILE_RADIUS * 1.06
	brm.height = 0.04; brm.radial_segments = 6
	var border_mi := MeshInstance3D.new(); border_mi.mesh = brm
	border_mi.position.y = 0.02
	border_mi.material_override = _make_mat(Color(0.3, 0.3, 0.28)); root.add_child(border_mi)
	# Terrain decor
	_build_terrain_decor(root, tile)
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
	# Fog
	var fog := MeshInstance3D.new(); var fm := CylinderMesh.new()
	fm.top_radius = TILE_RADIUS * 1.15; fm.bottom_radius = TILE_RADIUS * 1.15
	fm.height = 0.5; fm.radial_segments = 6; fog.mesh = fm
	var fmat := _make_mat(COL_FOG); fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog.material_override = fmat; fog.position.y = 0.35; fog.name = "FogOverlay"
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

# ═══════════════ SETTLEMENTS ═══════════════
func _build_settlement(parent: Node3D, tile: Dictionary) -> void:
	for c in parent.get_children(): c.queue_free()
	var terrain = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var level: int = tile.get("level", 1)
	var tt = tile.get("type", -1)
	var y: float = TILE_HEIGHT
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
		var pm := _make_mat(Color(0.12, 0.22, 0.1, 0.7))
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; pool.material_override = pm
		var a := float(i) * TAU / 3.0
		pool.position = Vector3(cos(a) * 0.45, y + 0.01, sin(a) * 0.4); parent.add_child(pool)

func _add_water_edge(parent: Node3D, y: float) -> void:
	var w := _make_box_mesh(Vector3(2.2, 0.02, 0.7), Color(0.12, 0.28, 0.5, 0.55))
	w.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	w.position = Vector3(0, y + 0.01, 0.95); parent.add_child(w)

func _add_grass_tufts(parent: Node3D, y: float) -> void:
	for i in range(4):
		var t := MeshInstance3D.new(); var sm := SphereMesh.new()
		sm.radius = 0.07; sm.height = 0.09; t.mesh = sm
		t.material_override = _make_mat(Color(0.28, 0.5, 0.18))
		t.scale = Vector3(1, 0.35, 1)
		var a := float(i) * 1.7 + 0.4
		t.position = Vector3(cos(a) * 0.75, y + 0.02, sin(a) * 0.55); parent.add_child(t)

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
	vis["base"].material_override = _make_mat(fc)
	# Border
	var brc: Color = FLAG_COLORS.get(fk, Color(0.3, 0.3, 0.28))
	if idx == selected_tile: brc = Color(1.0, 1.0, 0.8)
	elif idx == hovered_tile: brc = brc.lightened(0.35)
	var bm := _make_mat(brc); bm.emission_enabled = true
	bm.emission = brc * 0.4; bm.emission_energy_multiplier = 0.5
	vis["border"].material_override = bm
	# Flag
	var flc: Color = FLAG_COLORS.get(fk, Color(0.4, 0.4, 0.4))
	var fm := _make_mat(flc); fm.emission_enabled = true
	fm.emission = flc * 0.35; fm.emission_energy_multiplier = 0.35
	vis["banner"].material_override = fm
	vis["flag_root"].visible = tile["owner_id"] >= 0
	# Garrison
	var garrison: int = tile.get("garrison", 0)
	if garrison > 0 and not vis["fog"].visible:
		vis["garrison_label"].text = "Lv%d  %d兵" % [tile.get("level", 1), garrison]
	else: vis["garrison_label"].text = ""
	# Settlement update
	if settlement_nodes.has(idx): _build_settlement(settlement_nodes[idx], tile)
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
		0: return "human"
		1: return "high_elf"
		2: return "mage"
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
			var bmat := _make_mat(Color(bc.r, bc.g, bc.b, 0.7))
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
	var fmat := _make_mat(color); fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	var rm := _make_mat(color); rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	var pm := _make_mat(Color(1.0, 1.0, 0.8, 0.5))
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
		var dm := _make_mat(Color(1.0, 0.9, 0.3, 0.7))
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
		_on_tile_clicked(tile_index)

func _on_tile_hover_enter(tile_index: int) -> void:
	var oh: int = hovered_tile; hovered_tile = tile_index
	if oh >= 0: _update_territory_visual(oh); _animate_tile_hover(oh, false)
	_update_territory_visual(tile_index); _animate_tile_hover(tile_index, true)
	EventBus.message_log.emit("")

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
	if EventBus.has_signal("territory_selected"):
		EventBus.emit_signal("territory_selected", tile_index)
	EventBus.player_arrived.emit(pid, tile_index)

func _deselect_tile() -> void:
	var old: int = selected_tile; selected_tile = -1
	_clear_highlights(); _clear_pulse_ring(); _clear_path_preview()
	GameManager.deselect_army()
	if old >= 0: _update_territory_visual(old)
	if EventBus.has_signal("territory_deselected"): EventBus.territory_deselected.emit()

func get_selected_tile() -> int:
	return selected_tile

# ═══════════════ FOG OF WAR ═══════════════
func _update_fog() -> void:
	var pid: int = 0
	if not GameManager.players.is_empty(): pid = GameManager.get_human_player_id()
	for idx in tile_visuals:
		var vis: Dictionary = tile_visuals[idx]
		var rev: bool = GameManager.is_revealed_for(idx, pid)
		vis["fog"].visible = not rev
		if not rev:
			var edge: bool = _has_revealed_neighbor(idx, pid)
			var fc := COL_FOG_EDGE if edge else COL_FOG
			var fm := _make_mat(fc); fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			vis["fog"].material_override = fm
		vis["label"].visible = rev; vis["garrison_label"].visible = rev
		vis["flag_root"].visible = rev and GameManager.tiles[idx].get("owner_id", -1) >= 0

func _has_revealed_neighbor(idx: int, pid: int) -> bool:
	if not GameManager.adjacency.has(idx): return false
	for n in GameManager.adjacency[idx]:
		if GameManager.is_revealed_for(n, pid): return true
	return false

# ═══════════════ SIGNAL HANDLERS ═══════════════
func _on_tile_captured(_pid: int, ti: int) -> void:
	_update_territory_visual(ti); _update_fog(); _draw_faction_borders()
func _on_fog_updated(_pid: int) -> void:
	_update_fog()
func _on_turn_started(_pid: int) -> void:
	_clear_highlights(); _deselect_tile()
	if tile_visuals.is_empty() and not GameManager.tiles.is_empty(): _build_board()
	else: _update_all_territories()
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

# ═══════════════ UTILITY ═══════════════
func _make_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; return m

func _make_label3d(text: String, size: int, pos: Vector3, col: Color = Color(1,1,1,0.95)) -> Label3D:
	var l := Label3D.new(); l.text = text; l.font_size = size; l.pixel_size = 0.005
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true
	l.modulate = col; l.outline_modulate = Color(0, 0, 0, 0.9); l.outline_size = 10
	l.position = pos; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; return l

func _make_cyl_mesh(tr: float, br: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new()
	cm.top_radius = tr; cm.bottom_radius = br; cm.height = h
	mi.mesh = cm; mi.material_override = _make_mat(c); return mi

func _make_box_mesh(s: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = s
	mi.mesh = bm; mi.material_override = _make_mat(c); return mi

# ═══════════════ AMBIENT PARTICLES ═══════════════
func _setup_ambient_particles() -> void:
	for i in range(25):
		var p := MeshInstance3D.new(); var sm := SphereMesh.new()
		sm.radius = 0.025 + randf() * 0.02; sm.height = sm.radius * 2; p.mesh = sm
		var pm := _make_mat(Color(0.85, 0.6, 0.25, 0.35))
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
	minimap_viewport.transparent_bg = false; minimap_container.add_child(minimap_viewport)
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
	var pm := _make_mat(color); pm.emission_enabled = true
	pm.emission = color; pm.emission_energy_multiplier = 2.0
	bmi.material_override = pm
	var tw := create_tween()
	tw.tween_callback(func(): bmi.material_override = orig).set_delay(duration)
