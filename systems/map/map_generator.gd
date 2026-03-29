## map_generator.gd
## Generates a random node-based strategy map for a Sengoku Rance-style game.
## Uses Kruskal's MST for base connectivity, then adds extra edges for alternate paths.
## Divides the map into faction-controlled regions with fortresses, villages, etc.
##
## Usage:
##   var generator = MapGenerator.new()
##   var result = generator.generate(player_faction)
##   # result = { "nodes": {id: node_data}, "edges": {id: [connected_ids]} }

class_name MapGenerator
extends RefCounted

const FactionData = preload("res://systems/faction/faction_data.gd")
const LocationPresets = preload("res://systems/map/location_presets.gd")

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const MAP_WIDTH: int = 2200
const MAP_HEIGHT: int = 1400
const MIN_NODE_DISTANCE: float = 70.0
const NODE_COUNT_MIN: int = 90
const NODE_COUNT_MAX: int = 110
const EXTRA_EDGE_RATIO_MIN: float = 0.15
const EXTRA_EDGE_RATIO_MAX: float = 0.20

# ---------------------------------------------------------------------------
# Region definitions – 6 provinces for strategic depth (Sengoku Rance style)
# ---------------------------------------------------------------------------

const REGIONS: Array = [
	{
		"id": "northern_wastes",
		"name": "北方荒原",
		"center": Vector2(0.50, 0.10),
		"terrain_weights": {"PLAINS": 10, "FOREST": 8, "MOUNTAIN": 18, "SWAMP": 5, "WALL": 5, "RIVER": 5, "RUINS": 8, "WASTELAND": 26, "VOLCANIC": 15},
	},
	{
		"id": "deep_coast",
		"name": "深海沿岸",
		"center": Vector2(0.10, 0.45),
		"terrain_weights": {"PLAINS": 25, "FOREST": 10, "MOUNTAIN": 5, "SWAMP": 8, "WALL": 5, "RIVER": 22, "RUINS": 5, "WASTELAND": 10, "VOLCANIC": 10},
	},
	{
		"id": "eternal_night",
		"name": "永夜密林",
		"center": Vector2(0.20, 0.85),
		"terrain_weights": {"PLAINS": 8, "FOREST": 35, "MOUNTAIN": 5, "SWAMP": 22, "WALL": 5, "RIVER": 8, "RUINS": 7, "WASTELAND": 5, "VOLCANIC": 5},
	},
	{
		"id": "radiant_kingdom",
		"name": "光辉王国",
		"center": Vector2(0.50, 0.50),
		"terrain_weights": {"PLAINS": 35, "FOREST": 12, "MOUNTAIN": 5, "SWAMP": 3, "WALL": 18, "RIVER": 12, "RUINS": 5, "WASTELAND": 5, "VOLCANIC": 5},
	},
	{
		"id": "eastern_highlands",
		"name": "东方高地",
		"center": Vector2(0.85, 0.35),
		"terrain_weights": {"PLAINS": 12, "FOREST": 10, "MOUNTAIN": 28, "SWAMP": 3, "WALL": 5, "RIVER": 5, "RUINS": 22, "WASTELAND": 10, "VOLCANIC": 5},
	},
	{
		"id": "southern_ruins",
		"name": "南方废墟",
		"center": Vector2(0.75, 0.85),
		"terrain_weights": {"PLAINS": 10, "FOREST": 8, "MOUNTAIN": 10, "SWAMP": 5, "WALL": 5, "RIVER": 5, "RUINS": 28, "WASTELAND": 22, "VOLCANIC": 7},
	},
]

# Fortress definitions – placed first with maximum spacing.
const FORTRESS_DATA: Array = [
	{"name": "碎骨王座", "faction": "ORC", "garrison": 12},
	{"name": "深渊港", "faction": "PIRATE", "garrison": 10},
	{"name": "永夜暗城", "faction": "DARK_ELF", "garrison": 14},
	{"name": "天城王都", "faction": "HUMAN", "garrison": 15, "city_def": 50},
	{"name": "银冠要塞", "faction": "HUMAN", "garrison": 10, "city_def": 35},
	{"name": "世界树圣地", "faction": "HIGH_ELF", "garrison": 12},
	{"name": "奥术堡垒", "faction": "MAGE", "garrison": 12},
	{"name": "翡翠尖塔", "faction": "MAGE", "garrison": 8},
	# New fortresses for expanded map
	{"name": "铁壁关", "faction": "HUMAN", "garrison": 12, "city_def": 40},
	{"name": "霜牙港", "faction": "PIRATE", "garrison": 10, "city_def": 30},
	{"name": "月影祭坛", "faction": "DARK_ELF", "garrison": 11},
	{"name": "贤者之塔", "faction": "MAGE", "garrison": 10},
]

# Neutral base leaders – one node each.
const NEUTRAL_LEADERS: Array = [
	{"name": "草原部落营地", "faction": "NEUTRAL"},
	{"name": "山贼据点", "faction": "BANDIT"},
	{"name": "废墟前哨站", "faction": "NEUTRAL"},
	{"name": "沙漠商队驿站", "faction": "NEUTRAL"},
	{"name": "冰原猎手村", "faction": "NEUTRAL"},
	{"name": "暗巷佣兵所", "faction": "BANDIT"},
	# New neutral bases for expanded map
	{"name": "山贼寨", "faction": "BANDIT"},
	{"name": "流浪商团", "faction": "NEUTRAL"},
	{"name": "亡灵墓地", "faction": "NEUTRAL"},
	{"name": "龙穴", "faction": "NEUTRAL"},
]

# Resource station pool with target counts.
const RESOURCE_POOL: Array = [
	{"resource_type": "crystal", "name_prefix": "魔晶", "count_min": 2, "count_max": 3},
	{"resource_type": "horse", "name_prefix": "战马", "count_min": 2, "count_max": 3},
	{"resource_type": "gunpowder", "name_prefix": "火药", "count_min": 2, "count_max": 2},
	{"resource_type": "shadow", "name_prefix": "暗影裂隙", "count_min": 2, "count_max": 2},
]

# Generic names for filler nodes, picked at random.
const VILLAGE_NAMES: Array = [
	"枫叶村", "晨曦镇", "柳河庄", "白石村", "鹿角镇",
	"云雾庄", "碧水村", "红叶镇", "松风庄", "星落村",
	"银溪镇", "青石庄", "月影村", "暖风镇", "幽谷庄",
	"花田村", "铁砧镇", "雪峰庄", "霞光村", "古木镇",
	"翠竹村", "落霞庄", "清泉镇", "桃源村", "雁归庄",
	"磐石镇", "紫藤村", "黄昏庄", "碧落镇", "苍松村",
]
const STRONGHOLD_NAMES: Array = [
	"铁壁堡", "狮鹫堡", "雷鸣关", "苍穹堡", "玄武堡",
	"朱雀关", "黑曜堡", "白虎关", "龙脊堡", "凤翼关",
]
const BANDIT_NAMES: Array = [
	"黑风寨", "落日盗窟", "蛇牙洞", "血月岭", "乌鸦巢",
	"断刃谷", "影牙堡", "狼烟寨", "毒雾林", "骷髅崖",
]
const EVENT_NAMES: Array = [
	"古战场遗迹", "神秘石碑", "精灵泉", "魔法阵", "遗忘圣殿",
	"时光裂缝", "命运十字路", "龙骨遗址", "先知祭坛", "回响之地",
]

# Terrain distribution weights (must sum to 100).
const TERRAIN_WEIGHTS: Dictionary = {
	"PLAINS": 28,
	"FOREST": 18,
	"MOUNTAIN": 10,
	"SWAMP": 7,
	"WALL": 7,
	"RIVER": 10,
	"RUINS": 7,
	"WASTELAND": 8,
	"VOLCANIC": 5,
}

# ---------------------------------------------------------------------------
# UnionFind helper – used by Kruskal's algorithm
# ---------------------------------------------------------------------------

class UnionFind:
	var parent: Array = []
	var rank: Array = []

	func _init(n: int) -> void:
		parent.resize(n)
		rank.resize(n)
		for i in range(n):
			parent[i] = i
			rank[i] = 0

	func find(x: int) -> int:
		while parent[x] != x:
			parent[x] = parent[parent[x]]  # path compression
			x = parent[x]
		return x

	func union(a: int, b: int) -> bool:
		var ra := find(a)
		var rb := find(b)
		if ra == rb:
			return false
		# Union by rank
		if rank[ra] < rank[rb]:
			parent[ra] = rb
		elif rank[ra] > rank[rb]:
			parent[rb] = ra
		else:
			parent[rb] = ra
			rank[ra] += 1
		return true

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

## Generate a full map and return {"nodes": {id: node_data}, "edges": {id: [connected_ids]}}.
func generate(player_faction: int) -> Dictionary:
	randomize()

	var target_count: int = randi_range(NODE_COUNT_MIN, NODE_COUNT_MAX)

	# -- Step 1: Place fortress positions first with maximum spacing -----------
	var positions: Array = []  # Array[Vector2], index == node id
	positions = _place_fortresses()

	# -- Step 2: Fill remaining positions randomly -----------------------------
	positions = _fill_positions(positions, target_count)
	var node_count: int = positions.size()

	# -- Step 2b: Assign each tile to the nearest region -----------------------
	var tile_regions: Array = _assign_regions(positions)

	# -- Step 3: Build edges via Kruskal's MST + extra edges -------------------
	var edges: Dictionary = _build_edges(positions, node_count)

	# -- Step 3b: Create chokepoints by pruning cross-region edges -------------
	edges = _create_chokepoints(positions, edges, tile_regions)

	# -- Step 4: Assign node metadata ------------------------------------------
	var nodes: Dictionary = _assign_nodes(positions, edges, player_faction, tile_regions)

	return {"nodes": nodes, "edges": edges}

# ---------------------------------------------------------------------------
# Fortress placement
# ---------------------------------------------------------------------------

## Place 8 core fortresses with maximum spacing via greedy farthest-point.
func _place_fortresses() -> Array:
	var positions: Array = []

	# Ideal quadrant hints for each fortress to respect region design.
	# Format: [center_x_ratio, center_y_ratio]
	var hints: Array = [
		# ORC – South/Southwest fringe
		Vector2(0.20, 0.80),
		# PIRATE – far south coast
		Vector2(0.75, 0.90),
		# DARK_ELF – west fringe
		Vector2(0.10, 0.55),
		# HUMAN 天城王都 – north
		Vector2(0.45, 0.12),
		# HUMAN 银冠要塞 – north-center
		Vector2(0.65, 0.22),
		# HIGH_ELF 世界树 – east
		Vector2(0.88, 0.35),
		# MAGE 奥术堡垒 – center
		Vector2(0.50, 0.45),
		# MAGE 翡翠尖塔 – center-south
		Vector2(0.55, 0.60),
		# NEW: 铁壁关 – chokepoint between North and Center
		Vector2(0.45, 0.30),
		# NEW: 霜牙港 – northern coastal
		Vector2(0.15, 0.15),
		# NEW: 月影祭坛 – Dark Elf secondary
		Vector2(0.22, 0.70),
		# NEW: 贤者之塔 – Eastern Highlands
		Vector2(0.82, 0.55),
	]

	for i in range(FORTRESS_DATA.size()):
		var hint: Vector2 = hints[i]
		# Jitter around hint within a small radius so maps vary each run.
		var jitter := Vector2(randf_range(-60, 60), randf_range(-60, 60))
		var pos := Vector2(
			clampf(hint.x * MAP_WIDTH + jitter.x, 40, MAP_WIDTH - 40),
			clampf(hint.y * MAP_HEIGHT + jitter.y, 40, MAP_HEIGHT - 40)
		)
		# Ensure minimum distance from already-placed fortresses.
		var safe := _push_away(pos, positions, MIN_NODE_DISTANCE)
		positions.append(safe)

	return positions

# ---------------------------------------------------------------------------
# Fill remaining node positions
# ---------------------------------------------------------------------------

func _fill_positions(positions: Array, target_count: int) -> Array:
	# --- Poisson Disk Sampling via grid-accelerated dart throwing ---
	# This produces a more even, natural-looking distribution than pure random.
	var cell_size: float = MIN_NODE_DISTANCE / sqrt(2.0)
	var grid_w: int = int(ceil(MAP_WIDTH / cell_size))
	var grid_h: int = int(ceil(MAP_HEIGHT / cell_size))

	# Grid stores index into positions array, -1 means empty.
	var grid: Array = []
	grid.resize(grid_w * grid_h)
	for gi in range(grid.size()):
		grid[gi] = -1

	# Insert existing fortress positions into grid.
	for idx in range(positions.size()):
		var gx: int = int(positions[idx].x / cell_size)
		var gy: int = int(positions[idx].y / cell_size)
		gx = clampi(gx, 0, grid_w - 1)
		gy = clampi(gy, 0, grid_h - 1)
		grid[gy * grid_w + gx] = idx

	# Active list for Poisson Disk iteration.
	var active: Array = []
	for idx in range(positions.size()):
		active.append(idx)

	# If no seeds yet, place one random seed.
	if active.is_empty():
		var seed_pos := Vector2(randf_range(30, MAP_WIDTH - 30), randf_range(30, MAP_HEIGHT - 30))
		positions.append(seed_pos)
		var gx: int = clampi(int(seed_pos.x / cell_size), 0, grid_w - 1)
		var gy: int = clampi(int(seed_pos.y / cell_size), 0, grid_h - 1)
		grid[gy * grid_w + gx] = 0
		active.append(0)

	var k_candidates: int = 30  # candidates per active point
	while active.size() > 0 and positions.size() < target_count:
		# Pick a random active point.
		var active_idx: int = randi_range(0, active.size() - 1)
		var point_idx: int = active[active_idx]
		var center: Vector2 = positions[point_idx]
		var found_any: bool = false

		for _attempt in range(k_candidates):
			# Generate random point in annulus [MIN_NODE_DISTANCE, 2 * MIN_NODE_DISTANCE].
			var angle: float = randf() * TAU
			var radius: float = randf_range(MIN_NODE_DISTANCE, MIN_NODE_DISTANCE * 2.0)
			var candidate := center + Vector2(cos(angle), sin(angle)) * radius

			# Bounds check.
			if candidate.x < 30 or candidate.x > MAP_WIDTH - 30:
				continue
			if candidate.y < 30 or candidate.y > MAP_HEIGHT - 30:
				continue

			# Grid neighbourhood check (faster than scanning all points).
			var cgx: int = int(candidate.x / cell_size)
			var cgy: int = int(candidate.y / cell_size)
			cgx = clampi(cgx, 0, grid_w - 1)
			cgy = clampi(cgy, 0, grid_h - 1)
			var too_close: bool = false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var nx: int = cgx + dx
					var ny: int = cgy + dy
					if nx < 0 or nx >= grid_w or ny < 0 or ny >= grid_h:
						continue
					var neighbor_idx: int = grid[ny * grid_w + nx]
					if neighbor_idx != -1:
						if candidate.distance_to(positions[neighbor_idx]) < MIN_NODE_DISTANCE:
							too_close = true
							break
				if too_close:
					break
			if too_close:
				continue

			# Accept candidate.
			var new_idx: int = positions.size()
			positions.append(candidate)
			grid[cgy * grid_w + cgx] = new_idx
			active.append(new_idx)
			found_any = true

			if positions.size() >= target_count:
				break

		if not found_any:
			# Remove exhausted point from active list.
			active[active_idx] = active.back()
			active.pop_back()

	# Fallback: if Poisson didn't fill enough (rare on large maps), do random fill.
	var fallback_attempts: int = 3000
	while positions.size() < target_count and fallback_attempts > 0:
		var candidate := Vector2(
			randf_range(30, MAP_WIDTH - 30),
			randf_range(30, MAP_HEIGHT - 30)
		)
		if _min_distance_to(candidate, positions) >= MIN_NODE_DISTANCE:
			positions.append(candidate)
		fallback_attempts -= 1

	return positions

# ---------------------------------------------------------------------------
# Edge generation – Kruskal MST + extra edges
# ---------------------------------------------------------------------------

func _build_edges(positions: Array, n: int) -> Dictionary:
	# Collect all possible edges sorted by distance.
	var all_edges: Array = []  # [{a, b, dist}]
	for i in range(n):
		for j in range(i + 1, n):
			var d: float = positions[i].distance_to(positions[j])
			all_edges.append({"a": i, "b": j, "dist": d})

	all_edges.sort_custom(func(x, y): return x["dist"] < y["dist"])

	# --- Kruskal's MST ---
	var uf := UnionFind.new(n)
	var mst_edges: Array = []
	var non_mst_edges: Array = []

	for e in all_edges:
		if uf.union(e["a"], e["b"]):
			mst_edges.append(e)
		else:
			non_mst_edges.append(e)

	# Verify full connectivity: if graph is disconnected (e.g. very few nodes placed
	# far apart), force-connect remaining components via nearest edges (Bug fix Round 3).
	var root_set: Dictionary = {}
	for i in range(n):
		root_set[uf.find(i)] = true
	if root_set.size() > 1:
		# There are disconnected components — force-connect them.
		# Re-scan all_edges (sorted by distance) and union any cross-component edges.
		for e in all_edges:
			if uf.find(e["a"]) != uf.find(e["b"]):
				uf.union(e["a"], e["b"])
				mst_edges.append(e)
				# Check if now fully connected
				root_set.clear()
				for i2 in range(n):
					root_set[uf.find(i2)] = true
				if root_set.size() == 1:
					break

	# --- Add 15-20% extra edges for alternate paths ---
	var extra_ratio: float = randf_range(EXTRA_EDGE_RATIO_MIN, EXTRA_EDGE_RATIO_MAX)
	var extra_count: int = int(ceil(mst_edges.size() * extra_ratio))
	# Prefer shorter non-MST edges (already sorted by distance within non_mst_edges
	# because all_edges was sorted and we appended in order).
	var extras_added: int = 0
	for e in non_mst_edges:
		if extras_added >= extra_count:
			break
		# Skip very long edges to keep the map tight.
		if e["dist"] > 250.0:
			continue
		mst_edges.append(e)
		extras_added += 1

	# --- Ensure fortress-to-fortress connections exist even if longer ---
	var fortress_count: int = FORTRESS_DATA.size()
	var existing_edges_set: Dictionary = {}
	for e in mst_edges:
		existing_edges_set["%d_%d" % [mini(e["a"], e["b"]), maxi(e["a"], e["b"])]] = true
	for i in range(fortress_count):
		for j in range(i + 1, fortress_count):
			var key: String = "%d_%d" % [i, j]
			if not existing_edges_set.has(key):
				var d: float = positions[i].distance_to(positions[j])
				# Connect fortresses up to 500 units apart (generous for strategic links).
				if d <= 500.0:
					mst_edges.append({"a": i, "b": j, "dist": d})
					existing_edges_set[key] = true

	# --- Strategic corridors: ensure each region pair has a path of <=3 hops ---
	# Build a temporary adjacency from mst_edges so we can do BFS hop counting.
	var temp_adj: Dictionary = {}
	for i2 in range(n):
		temp_adj[i2] = []
	for e in mst_edges:
		temp_adj[e["a"]].append(e["b"])
		temp_adj[e["b"]].append(e["a"])

	# For each fortress pair, check if they can reach in <=3 hops; if not, add
	# a shortcut edge through the nearest intermediate node.
	for i2 in range(fortress_count):
		for j2 in range(i2 + 1, fortress_count):
			var hops: int = _bfs_hops(temp_adj, i2, j2, 4)
			if hops <= 3:
				continue
			# Find the non-fortress node nearest to midpoint of the two fortresses.
			var mid: Vector2 = (positions[i2] + positions[j2]) * 0.5
			var best_mid: int = -1
			var best_dist: float = INF
			for k in range(n):
				if k < fortress_count:
					continue
				var dm: float = positions[k].distance_to(mid)
				if dm < best_dist:
					best_dist = dm
					best_mid = k
			if best_mid != -1:
				# Add edges from both fortresses to the midpoint node.
				for endpoint in [i2, j2]:
					var ek: String = "%d_%d" % [mini(endpoint, best_mid), maxi(endpoint, best_mid)]
					if not existing_edges_set.has(ek):
						var de: float = positions[endpoint].distance_to(positions[best_mid])
						mst_edges.append({"a": endpoint, "b": best_mid, "dist": de})
						existing_edges_set[ek] = true
						temp_adj[endpoint].append(best_mid)
						temp_adj[best_mid].append(endpoint)

	# Build adjacency dictionary {node_id: [connected_ids]}.
	var adj: Dictionary = {}
	for i in range(n):
		adj[i] = []
	for e in mst_edges:
		adj[e["a"]].append(e["b"])
		adj[e["b"]].append(e["a"])

	return adj

# ---------------------------------------------------------------------------
# Node metadata assignment
# ---------------------------------------------------------------------------

func _assign_nodes(positions: Array, edges: Dictionary, player_faction: int, tile_regions: Array) -> Dictionary:
	var n: int = positions.size()
	var nodes: Dictionary = {}
	var assigned: Dictionary = {}  # id -> true
	var used_names: Dictionary = {}  # name -> true, tracks all assigned names to prevent reuse

	# --- Phase 1: Core fortresses from presets (ids 0..FORTRESS_DATA.size()-1) ---
	var core_presets: Array = LocationPresets.get_presets_by_category("core_fortress")
	for i in range(FORTRESS_DATA.size()):
		var fd: Dictionary = FORTRESS_DATA[i]
		var faction_enum: int = _faction_string_to_enum(fd["faction"])
		var city_def: int = fd.get("city_def", 30)
		var garrison_count: int = fd["garrison"]
		var rid: String = tile_regions[i] if i < tile_regions.size() else ""
		var rname: String = _region_name_for_id(rid)
		# Use preset name if available for richer data.
		var pname: String = fd["name"]
		if i < core_presets.size():
			pname = core_presets[i]["name"]
		nodes[i] = _make_node(i, positions[i], "FORTRESS", pname, faction_enum, city_def, garrison_count, rid, rname)
		# Apply chokepoint flag from articulation-point analysis.
		if _chokepoint_flags.has(i):
			nodes[i]["is_chokepoint"] = true
		assigned[i] = true
		used_names[pname] = true

	# --- Phase 2: Place all non-core presets by proximity to their position_hint ---
	# Group presets by category for ordered placement (outposts first, then specials, etc.)
	var preset_categories: Array = ["outpost", "special", "neutral", "bandit_lair", "event_point", "resource_station", "village"]
	var presets_to_place: Array = []
	for cat in preset_categories:
		var cat_presets: Array = LocationPresets.get_presets_by_category(cat)
		for p in cat_presets:
			presets_to_place.append(p)

	for preset in presets_to_place:
		# Find the closest unassigned node to this preset's position hint.
		var hint: Vector2 = preset["position_hint"]
		var target: Vector2
		if hint.x < 0 or hint.y < 0:
			# Random placement — pick a scattered node.
			target = Vector2(randf_range(100, MAP_WIDTH - 100), randf_range(100, MAP_HEIGHT - 100))
		else:
			target = Vector2(hint.x * MAP_WIDTH, hint.y * MAP_HEIGHT)

		var best_id: int = -1
		var best_dist: float = INF
		for i in range(n):
			if assigned.has(i):
				continue
			var d: float = positions[i].distance_to(target)
			if d < best_dist:
				best_dist = d
				best_id = i
		if best_id == -1:
			continue  # No free nodes left.

		var nid: int = best_id
		var rid: String = tile_regions[nid] if nid < tile_regions.size() else ""
		var rname: String = _region_name_for_id(rid)
		var cat: String = preset["category"]
		var type_str: String = _preset_category_to_type(cat)
		var fac: int = _faction_string_to_enum(preset["faction"])
		var garrison_count: int = randi_range(preset["garrison_min"], preset["garrison_max"])
		var city_def: int = preset["city_def"]
		var level: int = preset["level"]
		var pname: String = preset["name"]

		# Build node using _make_node then override specific fields.
		var nd: Dictionary = _make_node(nid, positions[nid], type_str, pname, fac, city_def, garrison_count, rid, rname)
		nd["level"] = level
		# Override terrain with preset preference if specified.
		var tpref: String = preset["terrain_pref"]
		if tpref != "":
			nd["terrain"] = _terrain_string_to_enum(tpref)
		# Resource type for resource stations.
		if preset["resource_type"] != "":
			nd["resource_type"] = preset["resource_type"]
		# Chokepoint flag.
		if _chokepoint_flags.has(nid):
			nd["is_chokepoint"] = true
		nodes[nid] = nd
		assigned[nid] = true
		used_names[pname] = true

	# --- Phase 3: Fill remaining unassigned nodes with generated names ----------
	# Since presets provide 78 unique names and maps have 90-110 nodes,
	# only ~12-32 nodes need generated names (<20% reuse guaranteed).
	var remaining_ids: Array = []
	for i in range(n):
		if not assigned.has(i):
			remaining_ids.append(i)
	remaining_ids.shuffle()

	# Build de-duped name pools from constants, excluding already-used names.
	var village_pool: Array = _filter_unused_names(VILLAGE_NAMES, used_names)
	var stronghold_pool: Array = _filter_unused_names(STRONGHOLD_NAMES, used_names)
	var bandit_pool: Array = _filter_unused_names(BANDIT_NAMES, used_names)
	var event_pool: Array = _filter_unused_names(EVENT_NAMES, used_names)
	village_pool.shuffle()
	stronghold_pool.shuffle()
	bandit_pool.shuffle()
	event_pool.shuffle()

	var vi: int = 0; var si: int = 0; var bi: int = 0; var ei: int = 0
	var suffix_counter: int = 1  # For generating unique suffixed names.

	for idx in range(remaining_ids.size()):
		var nid: int = remaining_ids[idx]
		var roll: float = randf()
		var node_type: String
		var node_name: String
		var garrison_count: int
		var city_def: int
		var owner: int

		if roll < 0.40:
			node_type = "VILLAGE"
			node_name = _pick_unique_name(village_pool, vi, "边境村落", suffix_counter, used_names)
			vi += 1
			garrison_count = randi_range(3, 5)
			city_def = 5
			owner = _region_faction(positions[nid])
		elif roll < 0.65:
			node_type = "STRONGHOLD"
			node_name = _pick_unique_name(stronghold_pool, si, "前线据点", suffix_counter, used_names)
			si += 1
			garrison_count = randi_range(6, 8)
			city_def = 15
			owner = _region_faction(positions[nid])
		elif roll < 0.85:
			node_type = "BANDIT_CAMP"
			node_name = _pick_unique_name(bandit_pool, bi, "荒野匪巢", suffix_counter, used_names)
			bi += 1
			garrison_count = randi_range(4, 6)
			city_def = 10
			owner = _faction_string_to_enum("BANDIT")
		else:
			node_type = "EVENT_POINT"
			node_name = _pick_unique_name(event_pool, ei, "未知遗迹", suffix_counter, used_names)
			ei += 1
			garrison_count = 0
			city_def = 0
			owner = -1

		if used_names.has(node_name):
			suffix_counter += 1
			node_name = node_name + "·" + _num_to_cn(suffix_counter)

		used_names[node_name] = true
		var nid_rid: String = tile_regions[nid] if nid < tile_regions.size() else ""
		var nid_rname: String = _region_name_for_id(nid_rid)
		var nd: Dictionary = _make_node(nid, positions[nid], node_type, node_name, owner, city_def, garrison_count, nid_rid, nid_rname)
		if _chokepoint_flags.has(nid):
			nd["is_chokepoint"] = true
		nodes[nid] = nd
		assigned[nid] = true

	# --- Phase 4: Player start – claim 1 fortress + 2 adjacent villages ------
	_assign_player_start(nodes, edges, player_faction)

	return nodes

## Convert a preset category string to the node type string used by _make_node.
func _preset_category_to_type(category: String) -> String:
	match category:
		"core_fortress": return "FORTRESS"
		"outpost": return "STRONGHOLD"
		"special": return "STRONGHOLD"
		"neutral": return "VILLAGE"
		"bandit_lair": return "BANDIT_CAMP"
		"event_point": return "EVENT_POINT"
		"resource_station": return "RESOURCE"
		"village": return "VILLAGE"
		_: return "VILLAGE"

## Filter a name array, removing names already in used_names.
func _filter_unused_names(pool: Array, used: Dictionary) -> Array:
	var result: Array = []
	for name in pool:
		if not used.has(name):
			result.append(name)
	return result

## Pick a unique name from a pool. If pool is exhausted, generate a suffixed name.
func _pick_unique_name(pool: Array, index: int, fallback_prefix: String, _suffix: int, used: Dictionary) -> String:
	if index < pool.size():
		var name: String = pool[index]
		if not used.has(name):
			return name
	# Pool exhausted or name collision — generate unique name.
	var gen_name: String = fallback_prefix + "·" + _num_to_cn(index + 1)
	var safety: int = 0
	while used.has(gen_name) and safety < 50:
		safety += 1
		gen_name = fallback_prefix + "·" + _num_to_cn(index + 1 + safety)
	return gen_name

## Convert a small integer to a Chinese numeral suffix for unique naming.
func _num_to_cn(num: int) -> String:
	var cn_digits: Array = ["零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖", "拾",
		"拾壹", "拾贰", "拾叁", "拾肆", "拾伍", "拾陆", "拾柒", "拾捌", "拾玖", "贰拾",
		"贰拾壹", "贰拾贰", "贰拾叁", "贰拾肆", "贰拾伍", "贰拾陆", "贰拾柒", "贰拾捌", "贰拾玖", "叁拾"]
	if num >= 0 and num < cn_digits.size():
		return cn_digits[num]
	return str(num)

# ---------------------------------------------------------------------------
# Player start assignment
# ---------------------------------------------------------------------------

## Give the player their faction fortress plus 2 adjacent villages.
func _assign_player_start(nodes: Dictionary, edges: Dictionary, player_faction: int) -> void:
	# Find the fortress that matches the player's chosen faction.
	# If the player picks a faction that has multiple fortresses, use the first one.
	var start_fortress_id: int = -1
	for i in range(FORTRESS_DATA.size()):
		if _faction_string_to_enum(FORTRESS_DATA[i]["faction"]) == player_faction:
			start_fortress_id = i
			break

	# Fallback: if no fortress matches (e.g. player chose BANDIT), pick the first one
	# from the South/Southwest area.
	if start_fortress_id == -1:
		start_fortress_id = 0  # ORC fortress at SW

	# Set fortress owner to player.
	nodes[start_fortress_id]["owner"] = player_faction

	# Find adjacent nodes and convert up to 2 to player-owned villages.
	var adj: Array = edges.get(start_fortress_id, [])
	var converted: int = 0
	for neighbor_id in adj:
		if converted >= 2:
			break
		var nd: Dictionary = nodes[neighbor_id]
		# Prefer converting villages or generic non-fortress nodes.
		if nd["type"] == GameManager.TileType.CORE_FORTRESS:
			continue
		nd["owner"] = player_faction
		nd["type"] = GameManager.TileType.LIGHT_VILLAGE
		nd["garrison"] = _make_garrison(3)
		nd["city_def"] = 5
		nd["city_def_max"] = 5
		converted += 1

	# If we could not convert 2 neighbors (unlikely), just move on – the player
	# starts with whatever is adjacent.

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Build a single node_data dictionary.
func _make_node(id: int, pos: Vector2, type_str: String, node_name: String, owner: int, city_def: int, garrison_size: int, region_id: String = "", region_name: String = "") -> Dictionary:
	var terrain_str: String
	if region_id != "":
		terrain_str = _random_terrain_for_region(region_id)
	else:
		terrain_str = _random_terrain()
	# Fortresses and strongholds always get WALL terrain override for their base.
	if type_str == "FORTRESS":
		terrain_str = "WALL"

	var node_type_enum: int = _type_string_to_enum(type_str)
	var terrain_enum: int = _terrain_string_to_enum(terrain_str)
	var level: int = 1
	if type_str == "FORTRESS":
		level = 3
	elif type_str == "STRONGHOLD":
		level = 2

	return {
		"id": id,
		"position": pos,
		"type": node_type_enum,
		"terrain": terrain_enum,
		"owner": owner,
		"name": node_name,
		"garrison": _make_garrison(garrison_size),
		"city_def": city_def,
		"city_def_max": city_def,
		"level": level,
		"building": -1,
		"building_level": 0,
		"resource_type": "",
		"region_id": region_id,
		"region_name": region_name,
	}

## Create a simple garrison array with the given number of placeholder unit dicts.
func _make_garrison(count: int) -> Array:
	var garrison: Array = []
	for i in range(count):
		garrison.append({
			"unit_id": i,
			"type": "soldier",
			"hp": 100,
			"atk": 10,
			"def": 5,
		})
	return garrison

## Pick a random terrain string respecting the weight distribution.
func _random_terrain() -> String:
	var roll: int = randi_range(1, 100)
	var cumulative: int = 0
	for key in TERRAIN_WEIGHTS:
		cumulative += TERRAIN_WEIGHTS[key]
		if roll <= cumulative:
			return key
	return "PLAINS"

# ---------------------------------------------------------------------------
# Region system helpers
# ---------------------------------------------------------------------------

## Assign each tile position to the nearest region, returning an Array[String] of region ids.
func _assign_regions(positions: Array) -> Array:
	var tile_regions: Array = []
	for pos in positions:
		var best_region: String = REGIONS[0]["id"]
		var best_dist: float = INF
		for region in REGIONS:
			var center := Vector2(region["center"].x * MAP_WIDTH, region["center"].y * MAP_HEIGHT)
			var d: float = pos.distance_to(center)
			if d < best_dist:
				best_dist = d
				best_region = region["id"]
		tile_regions.append(best_region)
	return tile_regions

## Get the display name for a region id.
func _region_name_for_id(region_id: String) -> String:
	for region in REGIONS:
		if region["id"] == region_id:
			return region["name"]
	return ""

## Pick a random terrain using region-specific weights.
func _random_terrain_for_region(region_id: String) -> String:
	var weights: Dictionary = TERRAIN_WEIGHTS
	for region in REGIONS:
		if region["id"] == region_id:
			weights = region["terrain_weights"]
			break
	var roll: int = randi_range(1, 100)
	var cumulative: int = 0
	for key in weights:
		cumulative += weights[key]
		if roll <= cumulative:
			return key
	return "PLAINS"

## Create chokepoints by pruning cross-region extra edges while maintaining connectivity.
func _create_chokepoints(positions: Array, edges: Dictionary, tile_regions: Array) -> Dictionary:
	var n: int = positions.size()

	# Identify all edges and classify as intra-region or cross-region
	var edge_set: Dictionary = {}  # "a_b" -> true (tracks processed edges)
	var cross_region_edges: Array = []  # [{a, b}]

	for a in edges:
		for b in edges[a]:
			var key: String = "%d_%d" % [mini(a, b), maxi(a, b)]
			if edge_set.has(key):
				continue
			edge_set[key] = true
			if a < tile_regions.size() and b < tile_regions.size():
				if tile_regions[a] != tile_regions[b]:
					cross_region_edges.append({"a": a, "b": b})

	# Count cross-region connections per region-pair
	var pair_counts: Dictionary = {}  # "regionA_regionB" -> count
	for ce in cross_region_edges:
		var ra: String = tile_regions[ce["a"]]
		var rb: String = tile_regions[ce["b"]]
		var pair_key: String = ra + "_" + rb if ra < rb else rb + "_" + ra
		pair_counts[pair_key] = pair_counts.get(pair_key, 0) + 1

	# Remove some cross-region edges to create chokepoints, but keep at least 2 per region pair
	cross_region_edges.shuffle()
	var removed_edges: Array = []
	for ce in cross_region_edges:
		var ra: String = tile_regions[ce["a"]]
		var rb: String = tile_regions[ce["b"]]
		var pair_key: String = ra + "_" + rb if ra < rb else rb + "_" + ra
		if pair_counts.get(pair_key, 0) > 2:
			# Remove this edge
			edges[ce["a"]].erase(ce["b"])
			edges[ce["b"]].erase(ce["a"])
			pair_counts[pair_key] -= 1
			removed_edges.append(ce)

	# Verify full connectivity — if broken, restore edges until connected
	if not _is_fully_connected(edges, n):
		# Restore removed edges one by one until connected
		for re in removed_edges:
			edges[re["a"]].append(re["b"])
			edges[re["b"]].append(re["a"])
			if _is_fully_connected(edges, n):
				break

	# --- Articulation point detection (bridge/gate logic) ---
	# Find nodes whose removal would disconnect parts of the graph and flag them.
	_chokepoint_flags = _find_articulation_points(edges, n)

	return edges

## Nodes flagged as chokepoints by articulation point analysis.
## Keyed by node id -> true. Consumed later by _assign_nodes to set is_chokepoint.
var _chokepoint_flags: Dictionary = {}

## Find articulation points using iterative Tarjan's algorithm.
## Returns a Dictionary {node_id: true} for every articulation point.
func _find_articulation_points(edges: Dictionary, n: int) -> Dictionary:
	var disc: Array = []      # discovery time
	var low: Array = []       # low-link value
	var parent: Array = []    # parent in DFS tree
	var is_ap: Dictionary = {}
	disc.resize(n)
	low.resize(n)
	parent.resize(n)
	for i in range(n):
		disc[i] = -1
		low[i] = -1
		parent[i] = -1

	var timer: int = 0

	# Iterative DFS for each unvisited component.
	for start in range(n):
		if disc[start] != -1:
			continue
		# Stack entries: [node, neighbor_index, is_returning]
		var stack: Array = [[start, 0, false]]
		disc[start] = timer
		low[start] = timer
		timer += 1
		var child_count: Dictionary = {}  # root child count for AP detection
		child_count[start] = 0

		while stack.size() > 0:
			var top: Array = stack.back()
			var u: int = top[0]
			var ni: int = top[1]
			var neighbors: Array = edges.get(u, [])

			if ni < neighbors.size():
				var v: int = neighbors[ni]
				top[1] = ni + 1  # advance neighbor index

				if disc[v] == -1:
					# Tree edge: push v.
					parent[v] = u
					disc[v] = timer
					low[v] = timer
					timer += 1
					if parent[u] == -1:
						child_count[u] = child_count.get(u, 0) + 1
					stack.append([v, 0, false])
				else:
					# Back edge: update low-link.
					if v != parent[u]:
						low[u] = mini(low[u], disc[v])
			else:
				# Done with u — propagate low-link to parent and check AP condition.
				stack.pop_back()
				if stack.size() > 0:
					var pu: int = parent[u]
					low[pu] = mini(low[pu], low[u])
					# Non-root AP condition: low[u] >= disc[parent].
					if parent[pu] != -1 and low[u] >= disc[pu]:
						is_ap[pu] = true
				else:
					# Root of DFS tree: AP if it has 2+ children.
					if child_count.get(u, 0) >= 2:
						is_ap[u] = true

	return is_ap

## BFS hop count between two nodes. Returns max_hops+1 if not reachable within max_hops.
func _bfs_hops(adj: Dictionary, from_id: int, to_id: int, max_hops: int) -> int:
	if from_id == to_id:
		return 0
	var visited: Dictionary = {from_id: true}
	var queue: Array = [[from_id, 0]]
	while queue.size() > 0:
		var current: Array = queue.pop_front()
		var node: int = current[0]
		var depth: int = current[1]
		if depth >= max_hops:
			continue
		for nb in adj.get(node, []):
			if nb == to_id:
				return depth + 1
			if not visited.has(nb):
				visited[nb] = true
				queue.append([nb, depth + 1])
	return max_hops + 1

## Check if the graph is fully connected via BFS.
func _is_fully_connected(edges: Dictionary, n: int) -> bool:
	if n <= 0:
		return true
	var visited: Dictionary = {}
	var queue: Array = [0]
	visited[0] = true
	while queue.size() > 0:
		var current: int = queue.pop_front()
		for nb in edges.get(current, []):
			if not visited.has(nb):
				visited[nb] = true
				queue.append(nb)
	return visited.size() == n

## Determine which faction owns a region based on position quadrant rules.
func _region_faction(pos: Vector2) -> int:
	var rx: float = pos.x / MAP_WIDTH
	var ry: float = pos.y / MAP_HEIGHT

	# North: top 30% -> Human
	if ry < 0.30:
		return _faction_string_to_enum("HUMAN")

	# East: right 30% -> High Elf
	if rx > 0.70:
		return _faction_string_to_enum("HIGH_ELF")

	# South/Southwest: bottom 30% AND left 50% -> neutral / scattered
	if ry > 0.70 and rx < 0.50:
		return -1  # player start area – neutral until claimed

	# Center band -> Mage
	if rx > 0.30 and rx < 0.70 and ry > 0.30 and ry < 0.70:
		return _faction_string_to_enum("MAGE")

	# Everything else: scattered neutral / bandit
	if randf() < 0.5:
		return _faction_string_to_enum("BANDIT")
	return -1

## Convert a faction string key to the FactionData.FactionID enum value.
func _faction_string_to_enum(s: String) -> int:
	match s:
		"ORC":
			return FactionData.FactionID.ORC
		"PIRATE":
			return FactionData.FactionID.PIRATE
		"DARK_ELF":
			return FactionData.FactionID.DARK_ELF
		"HUMAN":
			return 100  # Light faction placeholder (Human Kingdom)
		"HIGH_ELF":
			return 101  # Light faction placeholder (High Elves)
		"MAGE":
			return 102  # Light faction placeholder (Mage Tower)
		"BANDIT":
			return 200  # Neutral/bandit placeholder
		"NEUTRAL":
			return -1
		_:
			return -1

## Convert a node type string to the GameManager.TileType enum value.
func _type_string_to_enum(s: String) -> int:
	match s:
		"FORTRESS":
			return GameManager.TileType.CORE_FORTRESS
		"VILLAGE":
			return GameManager.TileType.LIGHT_VILLAGE
		"STRONGHOLD":
			return GameManager.TileType.NEUTRAL_BASE
		"BANDIT_CAMP":
			return GameManager.TileType.DARK_BASE
		"EVENT_POINT":
			return GameManager.TileType.EVENT_TILE
		"RESOURCE":
			return GameManager.TileType.RESOURCE_STATION
		_:
			return GameManager.TileType.WILDERNESS

## Convert a terrain string to the FactionData.TerrainType enum value.
func _terrain_string_to_enum(s: String) -> int:
	match s:
		"PLAINS":
			return FactionData.TerrainType.PLAINS
		"FOREST":
			return FactionData.TerrainType.FOREST
		"MOUNTAIN":
			return FactionData.TerrainType.MOUNTAIN
		"SWAMP":
			return FactionData.TerrainType.SWAMP
		"WALL":
			return FactionData.TerrainType.FORTRESS_WALL
		"RIVER":
			return FactionData.TerrainType.RIVER
		"RUINS":
			return FactionData.TerrainType.RUINS
		"WASTELAND":
			return FactionData.TerrainType.WASTELAND
		"VOLCANIC":
			return FactionData.TerrainType.VOLCANIC
		_:
			return FactionData.TerrainType.PLAINS

## Return the minimum distance from a point to any point in an existing array.
func _min_distance_to(point: Vector2, others: Array) -> float:
	var min_dist: float = INF
	for other in others:
		var d: float = point.distance_to(other)
		if d < min_dist:
			min_dist = d
	return min_dist

## Push a position away from nearby points until it satisfies the minimum distance,
## or return the best position found after a few iterations.
func _push_away(pos: Vector2, others: Array, min_dist: float) -> Vector2:
	if others.is_empty():
		return pos
	var current := pos
	for _iter in range(20):
		var closest_dist: float = _min_distance_to(current, others)
		if closest_dist >= min_dist:
			return current
		# Nudge away from the closest point.
		var closest_pt: Vector2 = others[0]
		for o in others:
			if current.distance_to(o) < current.distance_to(closest_pt):
				closest_pt = o
		var direction: Vector2 = (current - closest_pt).normalized()
		if direction.length_squared() < 0.001:
			direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		current += direction * (min_dist - closest_dist + 5.0)
		current.x = clampf(current.x, 40, MAP_WIDTH - 40)
		current.y = clampf(current.y, 40, MAP_HEIGHT - 40)
	return current

## Pick `count` unassigned node ids closest to a target point.
func _pick_unassigned_ids(positions: Array, assigned: Dictionary, count: int, target: Vector2) -> Array:
	var candidates: Array = []
	for i in range(positions.size()):
		if not assigned.has(i):
			candidates.append({"id": i, "dist": positions[i].distance_to(target)})
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var result: Array = []
	for c in candidates:
		if result.size() >= count:
			break
		result.append(c["id"])
	return result

## Pick `count` unassigned node ids spread across the map (every N-th from a shuffled list).
func _pick_unassigned_scattered(positions: Array, assigned: Dictionary, count: int) -> Array:
	var candidates: Array = []
	for i in range(positions.size()):
		if not assigned.has(i):
			candidates.append(i)
	candidates.shuffle()
	var result: Array = []
	for c in candidates:
		if result.size() >= count:
			break
		result.append(c)
	return result
