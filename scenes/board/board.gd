## board.gd - 2.5D Territory Map for 暗潮 SLG (v0.9.2)
## Sengoku Rance 07 style regional domination map
## Features: Territory visualization, army markers, camera controls, fog of war
extends Node3D
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Visual tracking ──
var tile_visuals: Dictionary = {}   # idx -> {root, base, label, fog, border, garrison_label, army_marker}
var edge_meshes: Array = []
var army_visuals: Dictionary = {}   # army_id -> Node3D
var highlight_rings: Dictionary = {}

# ── Selection state ──
var selected_tile: int = -1
var hovered_tile: int = -1

# ── Camera state ──
var camera: Camera3D
var camera_pivot: Node3D
var camera_target_pos: Vector3 = Vector3.ZERO
var camera_zoom: float = 1.0
const ZOOM_MIN: float = 0.6
const ZOOM_MAX: float = 2.0
const ZOOM_SPEED: float = 0.1
const PAN_SPEED: float = 15.0
const EDGE_SCROLL_MARGIN: float = 30.0
const EDGE_SCROLL_SPEED: float = 8.0

# ── Color palette ──
# Faction territory colors (base ground tint)
const FACTION_COLORS := {
	"orc": Color(0.7, 0.25, 0.2),
	"pirate": Color(0.2, 0.35, 0.6),
	"dark_elf": Color(0.4, 0.18, 0.6),
	"human": Color(0.7, 0.6, 0.25),
	"high_elf": Color(0.2, 0.55, 0.3),
	"mage": Color(0.2, 0.35, 0.7),
	"neutral": Color(0.45, 0.45, 0.4),
	"none": Color(0.3, 0.3, 0.27),
}

# Faction flag colors (bright, saturated)
const FLAG_COLORS := {
	"orc": Color(1.0, 0.3, 0.2),
	"pirate": Color(0.3, 0.55, 0.85),
	"dark_elf": Color(0.55, 0.25, 0.8),
	"human": Color(1.0, 0.85, 0.15),
	"high_elf": Color(0.3, 0.85, 0.4),
	"mage": Color(0.3, 0.4, 1.0),
	"neutral": Color(0.6, 0.6, 0.55),
	"none": Color(0.35, 0.35, 0.3),
}

# Terrain decoration colors
const TERRAIN_COLORS := {
	FactionData.TerrainType.PLAINS: Color(0.45, 0.6, 0.3),
	FactionData.TerrainType.FOREST: Color(0.2, 0.45, 0.15),
	FactionData.TerrainType.MOUNTAIN: Color(0.6, 0.55, 0.5),
	FactionData.TerrainType.SWAMP: Color(0.35, 0.4, 0.28),
	FactionData.TerrainType.COASTAL: Color(0.3, 0.45, 0.6),
	FactionData.TerrainType.FORTRESS_WALL: Color(0.65, 0.6, 0.55),
}

const COL_FOG := Color(0.1, 0.1, 0.15, 0.55)
const COL_HIGHLIGHT_FRIENDLY := Color(0.2, 0.9, 0.3, 0.5)
const COL_HIGHLIGHT_ENEMY := Color(0.9, 0.2, 0.2, 0.5)
const COL_HIGHLIGHT_NEUTRAL := Color(0.9, 0.8, 0.2, 0.5)
const COL_HIGHLIGHT_SELECTED := Color(1.0, 1.0, 1.0, 0.4)

const TILE_RADIUS: float = 1.8    # Hex-ish territory radius
const TILE_HEIGHT: float = 0.15   # Base tile thickness
const GROUND_Y: float = -0.1


func _ready() -> void:
	_setup_environment()
	_setup_lighting()
	_setup_camera()
	_setup_ground()

	EventBus.tile_captured.connect(_on_tile_captured)
	EventBus.fog_updated.connect(_on_fog_updated)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.game_over.connect(_on_game_over)
	EventBus.army_changed.connect(_on_army_changed)
	EventBus.army_deployed.connect(_on_army_deployed)
	EventBus.army_created.connect(_on_army_created_or_disbanded)
	EventBus.army_disbanded.connect(_on_army_created_or_disbanded)

	# Wait for GameManager to initialize before building board
	# Board is now built after start_game() is called from main.gd
	# We listen for turn_started to know when to build
	if not GameManager.tiles.is_empty():
		_build_board()


func rebuild() -> void:
	_clear_board()
	_build_board()


# ═══════════════ ENVIRONMENT ═══════════════

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.65, 0.65, 0.7)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# SSAO and Glow disabled for gl_compatibility (web) support
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _setup_lighting() -> void:
	# Main directional light (sun) - strong for gl_compatibility
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 1.6
	sun.shadow_enabled = false
	add_child(sun)

	# Fill light - boosted so shadowed sides aren't black
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, -120.0, 0.0)
	fill.light_color = Color(0.6, 0.65, 0.85)
	fill.light_energy = 0.7
	fill.shadow_enabled = false
	add_child(fill)


func _setup_camera() -> void:
	camera_pivot = Node3D.new()
	camera_pivot.name = "CameraPivot"
	camera_pivot.position = Vector3(9.0, 0.0, -8.0)
	add_child(camera_pivot)

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0.0, 25.0, 12.0)
	camera.rotation_degrees = Vector3(-55.0, 0.0, 0.0)
	camera.fov = 50.0
	camera.current = true
	camera_pivot.add_child(camera)


func _setup_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60.0, 50.0)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.18, 0.12)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = mat
	ground.position = Vector3(9.0, GROUND_Y - 0.1, -7.0)
	add_child(ground)

	# DEBUG: Big bright cube to verify 3D rendering works
	var debug_cube := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(5.0, 5.0, 5.0)
	debug_cube.mesh = box
	var debug_mat := StandardMaterial3D.new()
	debug_mat.albedo_color = Color(1.0, 1.0, 0.0)
	debug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_cube.material_override = debug_mat
	debug_cube.position = Vector3(9.0, 2.5, -8.0)  # Center of map at y=2.5
	add_child(debug_cube)


# ═══════════════ INPUT ═══════════════

func _unhandled_input(event: InputEvent) -> void:
	# Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_zoom = clampf(camera_zoom - ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
			_apply_zoom()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_zoom = clampf(camera_zoom + ZOOM_SPEED, ZOOM_MIN, ZOOM_MAX)
			_apply_zoom()
		# Right-click to deselect
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_deselect_tile()


func _process(delta: float) -> void:
	_process_camera_input(delta)
	_process_edge_scroll(delta)


func _process_camera_input(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.z -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.z += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0

	if move.length_squared() > 0.01:
		move = move.normalized() * PAN_SPEED * delta / camera_zoom
		camera_pivot.position += move
		_clamp_camera()


func _process_edge_scroll(delta: float) -> void:
	var viewport := get_viewport()
	if not viewport:
		return
	var mouse_pos := viewport.get_mouse_position()
	var vp_size := viewport.get_visible_rect().size
	var move := Vector3.ZERO

	if mouse_pos.x < EDGE_SCROLL_MARGIN:
		move.x -= 1.0
	elif mouse_pos.x > vp_size.x - EDGE_SCROLL_MARGIN:
		move.x += 1.0
	if mouse_pos.y < EDGE_SCROLL_MARGIN:
		move.z -= 1.0
	elif mouse_pos.y > vp_size.y - EDGE_SCROLL_MARGIN:
		move.z += 1.0

	if move.length_squared() > 0.01:
		camera_pivot.position += move.normalized() * EDGE_SCROLL_SPEED * delta / camera_zoom
		_clamp_camera()


func _apply_zoom() -> void:
	var base_pos := Vector3(0.0, 25.0, 12.0)
	camera.position = base_pos / camera_zoom


func _clamp_camera() -> void:
	camera_pivot.position.x = clampf(camera_pivot.position.x, -5.0, 25.0)
	camera_pivot.position.z = clampf(camera_pivot.position.z, -25.0, 5.0)


# ═══════════════ BOARD BUILDING ═══════════════

func _clear_board() -> void:
	for idx in tile_visuals:
		var vis: Dictionary = tile_visuals[idx]
		if is_instance_valid(vis["root"]):
			vis["root"].queue_free()
	tile_visuals.clear()
	for edge in edge_meshes:
		if is_instance_valid(edge):
			edge.queue_free()
	edge_meshes.clear()
	for aid in army_visuals:
		if is_instance_valid(army_visuals[aid]):
			army_visuals[aid].queue_free()
	army_visuals.clear()
	_clear_highlights()


func _build_board() -> void:
	tile_visuals.clear()

	for tile in GameManager.tiles:
		var idx: int = tile["index"]
		var pos3d: Vector3 = tile["position_3d"]
		_build_territory(idx, tile, pos3d)

	_draw_edges()
	_update_all_territories()
	_update_fog()


func _build_territory(idx: int, tile: Dictionary, pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = Vector3(pos.x, 0.0, pos.z)
	root.name = "Territory_%d" % idx
	add_child(root)

	# Base platform (hexagonal approximation using cylinder)
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = TILE_RADIUS
	base_mesh.bottom_radius = TILE_RADIUS * 1.02
	base_mesh.height = TILE_HEIGHT
	base_mesh.radial_segments = 6  # Hexagonal
	var base_mi := MeshInstance3D.new()
	base_mi.mesh = base_mesh
	base_mi.position = Vector3(0.0, TILE_HEIGHT * 0.5, 0.0)
	# Default color, updated later by _update_territory_color
	base_mi.material_override = _make_mat(Color(1.0, 0.0, 0.0))  # BRIGHT RED for debug
	root.add_child(base_mi)

	# Border ring (thin cylinder slightly larger)
	var border_mesh := CylinderMesh.new()
	border_mesh.top_radius = TILE_RADIUS * 1.05
	border_mesh.bottom_radius = TILE_RADIUS * 1.05
	border_mesh.height = 0.03
	border_mesh.radial_segments = 6
	var border_mi := MeshInstance3D.new()
	border_mi.mesh = border_mesh
	border_mi.position = Vector3(0.0, 0.02, 0.0)
	border_mi.material_override = _make_mat(Color(0.3, 0.3, 0.28))
	root.add_child(border_mi)

	# Terrain decorations
	_build_terrain_decor(root, tile)

	# Territory name label
	var label := Label3D.new()
	label.text = tile.get("name", "#%d" % idx)
	label.font_size = 32
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1, 1, 1, 0.95)
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.outline_size = 10
	label.position = Vector3(0.0, 1.8, 0.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(label)

	# Garrison count label (smaller, below name)
	var garrison_label := Label3D.new()
	garrison_label.text = ""
	garrison_label.font_size = 24
	garrison_label.pixel_size = 0.005
	garrison_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	garrison_label.no_depth_test = true
	garrison_label.modulate = Color(1, 0.9, 0.7, 0.9)
	garrison_label.outline_modulate = Color(0, 0, 0, 0.8)
	garrison_label.outline_size = 8
	garrison_label.position = Vector3(0.0, 1.4, 0.0)
	garrison_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(garrison_label)

	# Army marker (visible when army is stationed here)
	var army_marker := Node3D.new()
	army_marker.name = "ArmyMarker"
	army_marker.visible = false
	army_marker.position = Vector3(-0.7, TILE_HEIGHT, 0.5)
	root.add_child(army_marker)

	# Army shield mesh (visual indicator)
	var shield := MeshInstance3D.new()
	var shield_mesh := BoxMesh.new()
	shield_mesh.size = Vector3(0.35, 0.45, 0.08)
	shield.mesh = shield_mesh
	shield.position = Vector3(0.0, 0.3, 0.0)
	shield.material_override = _make_mat(Color(0.6, 0.2, 0.2))
	army_marker.add_child(shield)

	# Army label (shows army name / soldier count)
	var army_label := Label3D.new()
	army_label.name = "ArmyLabel"
	army_label.font_size = 42
	army_label.pixel_size = 0.01
	army_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	army_label.no_depth_test = true
	army_label.modulate = Color(1.0, 0.6, 0.3, 1.0)
	army_label.outline_modulate = Color(0, 0, 0, 0.9)
	army_label.outline_size = 10
	army_label.position = Vector3(0.0, 0.7, 0.0)
	army_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	army_marker.add_child(army_label)

	# Flag pole + banner (shows faction ownership)
	var flag_root := Node3D.new()
	flag_root.name = "Flag"
	flag_root.position = Vector3(0.8, TILE_HEIGHT, -0.6)
	root.add_child(flag_root)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.02
	pole_mesh.bottom_radius = 0.025
	pole_mesh.height = 1.0
	pole.mesh = pole_mesh
	pole.material_override = _make_mat(Color(0.5, 0.45, 0.4))
	pole.position = Vector3(0.0, 0.5, 0.0)
	flag_root.add_child(pole)

	var banner := MeshInstance3D.new()
	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(0.3, 0.2, 0.02)
	banner.mesh = banner_mesh
	banner.position = Vector3(0.2, 0.9, 0.0)
	banner.material_override = _make_mat(Color(0.5, 0.5, 0.5))  # Updated per faction
	flag_root.add_child(banner)

	# Fog overlay (covers entire territory)
	var fog := MeshInstance3D.new()
	var fog_mesh := CylinderMesh.new()
	fog_mesh.top_radius = TILE_RADIUS * 1.1
	fog_mesh.bottom_radius = TILE_RADIUS * 1.1
	fog_mesh.height = 0.4
	fog_mesh.radial_segments = 6
	fog.mesh = fog_mesh
	var fog_mat := _make_mat(COL_FOG)
	fog_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog.material_override = fog_mat
	fog.position = Vector3(0.0, 0.3, 0.0)
	fog.name = "FogOverlay"
	root.add_child(fog)

	# Click area
	var area := Area3D.new()
	area.input_ray_pickable = true
	var col_shape := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = TILE_RADIUS * 0.9
	cyl_shape.height = 0.8
	col_shape.shape = cyl_shape
	col_shape.position = Vector3(0.0, 0.4, 0.0)
	area.add_child(col_shape)
	area.input_event.connect(_on_tile_input.bind(idx))
	area.mouse_entered.connect(_on_tile_hover_enter.bind(idx))
	area.mouse_exited.connect(_on_tile_hover_exit.bind(idx))
	root.add_child(area)

	tile_visuals[idx] = {
		"root": root,
		"base": base_mi,
		"border": border_mi,
		"label": label,
		"garrison_label": garrison_label,
		"army_marker": army_marker,
		"army_label": army_marker.get_node("ArmyLabel"),
		"flag_root": flag_root,
		"banner": banner,
		"fog": fog,
		"area": area,
	}


# ═══════════════ TERRAIN DECORATIONS ═══════════════

func _build_terrain_decor(parent: Node3D, tile: Dictionary) -> void:
	var terrain: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var y: float = TILE_HEIGHT

	match terrain:
		FactionData.TerrainType.FOREST:
			_add_trees(parent, y, 4)
		FactionData.TerrainType.MOUNTAIN:
			_add_rocks(parent, y, 3)
		FactionData.TerrainType.SWAMP:
			_add_swamp_pools(parent, y)
		FactionData.TerrainType.COASTAL:
			_add_water_edge(parent, y)
		FactionData.TerrainType.FORTRESS_WALL:
			_add_wall_structure(parent, y)
		FactionData.TerrainType.PLAINS:
			_add_grass_tufts(parent, y)


func _add_trees(parent: Node3D, y: float, count: int) -> void:
	for i in range(count):
		var angle: float = float(i) / float(count) * TAU + 0.3
		var dist: float = 0.6 + randf() * 0.5
		var tx: float = cos(angle) * dist
		var tz: float = sin(angle) * dist

		# Trunk
		var trunk := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.03
		tc.bottom_radius = 0.05
		tc.height = 0.4
		trunk.mesh = tc
		trunk.material_override = _make_mat(Color(0.35, 0.25, 0.15))
		trunk.position = Vector3(tx, y + 0.2, tz)
		parent.add_child(trunk)

		# Foliage
		var foliage := MeshInstance3D.new()
		var fs := SphereMesh.new()
		fs.radius = 0.15 + randf() * 0.1
		fs.height = 0.25
		foliage.mesh = fs
		foliage.material_override = _make_mat(Color(0.12 + randf() * 0.08, 0.3 + randf() * 0.15, 0.08))
		foliage.position = Vector3(tx, y + 0.5, tz)
		parent.add_child(foliage)


func _add_rocks(parent: Node3D, y: float, count: int) -> void:
	for i in range(count):
		var angle: float = float(i) / float(count) * TAU + 0.5
		var dist: float = 0.4 + randf() * 0.6
		var rock := MeshInstance3D.new()
		var rs := SphereMesh.new()
		rs.radius = 0.12 + randf() * 0.1
		rs.height = 0.2 + randf() * 0.15
		rock.mesh = rs
		rock.material_override = _make_mat(Color(0.45 + randf() * 0.1, 0.42, 0.38))
		rock.scale = Vector3(1.0, 0.5 + randf() * 0.5, 0.8)
		rock.position = Vector3(cos(angle) * dist, y + 0.06, sin(angle) * dist)
		parent.add_child(rock)


func _add_swamp_pools(parent: Node3D, y: float) -> void:
	for i in range(2):
		var pool := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.3 + randf() * 0.2
		pc.bottom_radius = 0.3 + randf() * 0.2
		pc.height = 0.02
		pool.mesh = pc
		var pm := _make_mat(Color(0.15, 0.25, 0.12, 0.7))
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pool.material_override = pm
		pool.position = Vector3(-0.3 + float(i) * 0.6, y + 0.01, randf() * 0.4 - 0.2)
		parent.add_child(pool)


func _add_water_edge(parent: Node3D, y: float) -> void:
	var water := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(2.0, 0.02, 0.6)
	water.mesh = wm
	var mat := _make_mat(Color(0.15, 0.3, 0.5, 0.6))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.material_override = mat
	water.position = Vector3(0.0, y + 0.01, 0.9)
	parent.add_child(water)


func _add_wall_structure(parent: Node3D, y: float) -> void:
	# Wall segments around the territory
	for i in range(4):
		var angle: float = float(i) / 4.0 * TAU + 0.4
		var dist: float = 1.1
		var wall := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.8, 0.5, 0.12)
		wall.mesh = wm
		wall.material_override = _make_mat(Color(0.55, 0.5, 0.45))
		wall.position = Vector3(cos(angle) * dist, y + 0.25, sin(angle) * dist)
		wall.rotation.y = angle + PI * 0.5
		parent.add_child(wall)


func _add_grass_tufts(parent: Node3D, y: float) -> void:
	for i in range(3):
		var tuft := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.06
		sm.height = 0.08
		tuft.mesh = sm
		tuft.material_override = _make_mat(Color(0.3, 0.5, 0.2))
		tuft.scale = Vector3(1.0, 0.4, 1.0)
		var angle: float = float(i) * 2.1
		tuft.position = Vector3(cos(angle) * 0.7, y + 0.02, sin(angle) * 0.5)
		parent.add_child(tuft)


# ═══════════════ TERRITORY UPDATES ═══════════════

func _update_all_territories() -> void:
	for tile in GameManager.tiles:
		_update_territory_visual(tile["index"])


func _update_territory_visual(idx: int) -> void:
	if not tile_visuals.has(idx):
		return
	var vis: Dictionary = tile_visuals[idx]
	var tile: Dictionary = GameManager.tiles[idx]

	# Update base color based on owner
	var faction_key: String = _get_tile_faction_key(tile)
	var base_color: Color = FACTION_COLORS.get(faction_key, FACTION_COLORS["none"])
	var terrain: String = tile.get("terrain", "plains")
	var terrain_tint: Color = TERRAIN_COLORS.get(terrain, Color(0.3, 0.4, 0.25))
	var final_color: Color = base_color.lerp(terrain_tint, 0.35)
	vis["base"].material_override = _make_mat(final_color)

	# Update border color
	var border_color: Color = FLAG_COLORS.get(faction_key, Color(0.3, 0.3, 0.28))
	if idx == selected_tile:
		border_color = Color(1.0, 1.0, 0.8)
	elif idx == hovered_tile:
		border_color = border_color.lightened(0.3)
	var border_mat := _make_mat(border_color)
	border_mat.emission_enabled = true
	border_mat.emission = border_color * 0.3
	border_mat.emission_energy_multiplier = 0.4
	vis["border"].material_override = border_mat

	# Update flag banner color
	var flag_color: Color = FLAG_COLORS.get(faction_key, Color(0.4, 0.4, 0.4))
	var flag_mat := _make_mat(flag_color)
	flag_mat.emission_enabled = true
	flag_mat.emission = flag_color * 0.3
	flag_mat.emission_energy_multiplier = 0.3
	vis["banner"].material_override = flag_mat
	vis["flag_root"].visible = tile["owner_id"] >= 0

	# Update garrison label
	var garrison: int = tile.get("garrison", 0)
	if garrison > 0 and not vis["fog"].visible:
		var level: int = tile.get("level", 1)
		vis["garrison_label"].text = "Lv%d  %d兵" % [level, garrison]
	else:
		vis["garrison_label"].text = ""

	# Update army marker (v0.9.2)
	var army: Dictionary = GameManager.get_army_at_tile(idx)
	if not army.is_empty() and not vis["fog"].visible:
		vis["army_marker"].visible = true
		var soldier_count: int = GameManager.get_army_soldier_count(army["id"])
		vis["army_label"].text = "%s\n⚔%d" % [army.get("name", "军团"), soldier_count]
		# Color the shield by army's faction
		var shield_node: MeshInstance3D = vis["army_marker"].get_child(0)
		var army_faction_key: String = _get_player_faction_key(army["player_id"])
		var army_color: Color = FLAG_COLORS.get(army_faction_key, Color(0.5, 0.5, 0.5))
		shield_node.material_override = _make_mat(army_color)
	else:
		vis["army_marker"].visible = false
		vis["army_label"].text = ""


func _get_tile_faction_key(tile: Dictionary) -> String:
	var owner_id: int = tile.get("owner_id", -1)
	if owner_id < 0:
		if tile.get("neutral_faction_id", -1) >= 0:
			return "neutral"
		return "none"

	if owner_id >= GameManager.players.size():
		return "none"

	var faction_id: int = GameManager.get_player_faction(owner_id)

	# Map faction_id to key
	match faction_id:
		FactionData.FactionID.ORC: return "orc"
		FactionData.FactionID.PIRATE: return "pirate"
		FactionData.FactionID.DARK_ELF: return "dark_elf"

	# AI players - check light faction
	var light_faction: int = tile.get("light_faction", -1)
	match light_faction:
		0: return "human"
		1: return "high_elf"
		2: return "mage"

	return "neutral"


func _get_player_faction_key(player_id: int) -> String:
	## Returns faction color key for a given player_id.
	if player_id < 0:
		return "none"
	var faction_id: int = GameManager.get_player_faction(player_id)
	match faction_id:
		FactionData.FactionID.ORC: return "orc"
		FactionData.FactionID.PIRATE: return "pirate"
		FactionData.FactionID.DARK_ELF: return "dark_elf"
	return "neutral"


# ═══════════════ EDGES ═══════════════

func _draw_edges() -> void:
	for tile_idx in GameManager.adjacency:
		for neighbor_idx in GameManager.adjacency[tile_idx]:
			if neighbor_idx > tile_idx:
				var from: Vector3 = GameManager.tiles[tile_idx]["position_3d"]
				var to: Vector3 = GameManager.tiles[neighbor_idx]["position_3d"]
				_create_road_edge(from, to)


func _create_road_edge(from: Vector3, to: Vector3) -> void:
	var mid := (from + to) * 0.5
	var diff := to - from
	var dist := diff.length()
	if dist < 0.01:
		return
	var road := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.15, 0.02, dist)
	road.mesh = box
	var mat := _make_mat(Color(0.3, 0.28, 0.22))
	road.material_override = mat
	road.position = Vector3(mid.x, TILE_HEIGHT + 0.01, mid.z)
	road.rotation.y = atan2(diff.x, diff.z)
	add_child(road)
	edge_meshes.append(road)


# ═══════════════ HIGHLIGHTING ═══════════════

func show_attackable(indices: Array) -> void:
	_clear_highlights()
	for idx in indices:
		_add_highlight_ring(idx, COL_HIGHLIGHT_ENEMY)


func show_deployable(indices: Array) -> void:
	_clear_highlights()
	for idx in indices:
		_add_highlight_ring(idx, COL_HIGHLIGHT_FRIENDLY)


func show_mixed_highlights(friendly: Array, enemy: Array, neutral: Array) -> void:
	_clear_highlights()
	for idx in friendly:
		_add_highlight_ring(idx, COL_HIGHLIGHT_FRIENDLY)
	for idx in enemy:
		_add_highlight_ring(idx, COL_HIGHLIGHT_ENEMY)
	for idx in neutral:
		_add_highlight_ring(idx, COL_HIGHLIGHT_NEUTRAL)


func _add_highlight_ring(idx: int, color: Color) -> void:
	if not tile_visuals.has(idx):
		return
	var pos: Vector3 = GameManager.tiles[idx]["position_3d"]
	var ring := MeshInstance3D.new()
	var tc := CylinderMesh.new()
	tc.top_radius = TILE_RADIUS * 1.08
	tc.bottom_radius = TILE_RADIUS * 1.08
	tc.height = 0.05
	tc.radial_segments = 6
	ring.mesh = tc
	var rm := _make_mat(color)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.emission_enabled = true
	rm.emission = color
	rm.emission_energy_multiplier = 1.2
	ring.material_override = rm
	ring.position = Vector3(pos.x, TILE_HEIGHT + 0.03, pos.z)
	add_child(ring)
	highlight_rings[idx] = ring


func _clear_highlights() -> void:
	for idx in highlight_rings:
		if is_instance_valid(highlight_rings[idx]):
			highlight_rings[idx].queue_free()
	highlight_rings.clear()


# ═══════════════ SELECTION & CLICK ═══════════════

func _on_tile_input(_camera_node: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int, tile_index: int) -> void:
	if not event is InputEventMouseButton:
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_on_tile_clicked(tile_index)


func _on_tile_hover_enter(tile_index: int) -> void:
	hovered_tile = tile_index
	_update_territory_visual(tile_index)
	# Emit signal for HUD to show tile info
	EventBus.message_log.emit("")  # Trigger info update


func _on_tile_hover_exit(tile_index: int) -> void:
	if hovered_tile == tile_index:
		hovered_tile = -1
		_update_territory_visual(tile_index)


func _on_tile_clicked(tile_index: int) -> void:
	var old_selected: int = selected_tile
	var pid: int = GameManager.get_human_player_id()
	var tile: Dictionary = GameManager.tiles[tile_index]

	# ── If we have a selected army and clicked an actionable tile ──
	if GameManager.selected_army_id >= 0:
		var army: Dictionary = GameManager.get_army(GameManager.selected_army_id)
		if not army.is_empty() and army["player_id"] == pid:
			# Check if target is a valid deploy target (green)
			var deployable: Array = GameManager.get_army_deployable_tiles(GameManager.selected_army_id)
			if deployable.has(tile_index):
				GameManager.action_deploy_army(GameManager.selected_army_id, tile_index)
				_deselect_tile()
				return
			# Check if target is a valid attack target (red)
			var attackable: Array = GameManager.get_army_attackable_tiles(GameManager.selected_army_id)
			if attackable.has(tile_index):
				GameManager.action_attack_with_army(GameManager.selected_army_id, tile_index)
				_deselect_tile()
				return

	# Deselect if clicking same tile
	if selected_tile == tile_index:
		_deselect_tile()
		return

	# Update selection
	selected_tile = tile_index
	if old_selected >= 0:
		_update_territory_visual(old_selected)
	_update_territory_visual(tile_index)
	_clear_highlights()

	# ── Auto-select army at clicked tile if owned ──
	if tile["owner_id"] == pid:
		var army_here: Dictionary = GameManager.get_army_at_tile_for_player(tile_index, pid)
		if not army_here.is_empty():
			GameManager.select_army(army_here["id"])
			# Show highlights for deployable (green) and attackable (red) tiles
			var deployable: Array = GameManager.get_army_deployable_tiles(army_here["id"])
			for dt in deployable:
				_add_highlight_ring(dt, Color(0.2, 0.9, 0.3, 0.6))
			var attackable: Array = GameManager.get_army_attackable_tiles(army_here["id"])
			for at in attackable:
				_add_highlight_ring(at, Color(0.9, 0.2, 0.2, 0.6))
		else:
			GameManager.deselect_army()
	else:
		GameManager.deselect_army()

	# Emit selection signal for HUD
	if EventBus.has_signal("territory_selected"):
		EventBus.emit_signal("territory_selected", tile_index)
	EventBus.player_arrived.emit(pid, tile_index)


func _deselect_tile() -> void:
	var old: int = selected_tile
	selected_tile = -1
	_clear_highlights()
	GameManager.deselect_army()
	if old >= 0:
		_update_territory_visual(old)
	if EventBus.has_signal("territory_deselected"):
		EventBus.territory_deselected.emit()


func get_selected_tile() -> int:
	return selected_tile


# ═══════════════ FOG OF WAR ═══════════════

func _update_fog() -> void:
	var pid: int = 0
	if not GameManager.players.is_empty():
		pid = GameManager.get_human_player_id()
	for idx in tile_visuals:
		var vis: Dictionary = tile_visuals[idx]
		var revealed: bool = GameManager.is_revealed_for(idx, pid)
		vis["fog"].visible = not revealed
		vis["label"].visible = revealed
		vis["garrison_label"].visible = revealed
		vis["flag_root"].visible = revealed and GameManager.tiles[idx].get("owner_id", -1) >= 0


# ═══════════════ SIGNAL HANDLERS ═══════════════

func _on_tile_captured(_player_id: int, tile_index: int) -> void:
	_update_territory_visual(tile_index)
	_update_fog()

func _on_fog_updated(_player_id: int) -> void:
	_update_fog()

func _on_turn_started(_player_id: int) -> void:
	_clear_highlights()
	_deselect_tile()
	# Rebuild board on first turn if not built yet
	if tile_visuals.is_empty() and not GameManager.tiles.is_empty():
		_build_board()
	else:
		_update_all_territories()

func _on_game_over(_winner_id: int) -> void:
	_clear_highlights()

func _on_army_changed(_pid: int, _count: int) -> void:
	_update_all_territories()

func _on_army_deployed(_pid: int, _army_id: int, from_tile: int, to_tile: int) -> void:
	_update_territory_visual(from_tile)
	_update_territory_visual(to_tile)

func _on_army_created_or_disbanded(_pid: int, _army_id: int, _extra = null) -> void:
	_update_all_territories()


# ═══════════════ CAMERA FOCUS ═══════════════

func focus_on_tile(tile_index: int) -> void:
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	var pos: Vector3 = GameManager.tiles[tile_index]["position_3d"]
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(camera_pivot, "position", Vector3(pos.x, 0.0, pos.z), 0.5)


# ═══════════════ UTILITY ═══════════════

func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
