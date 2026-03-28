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

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const MAP_WIDTH: int = 1280
const MAP_HEIGHT: int = 720
const MIN_NODE_DISTANCE: float = 80.0
const NODE_COUNT_MIN: int = 50
const NODE_COUNT_MAX: int = 60
const EXTRA_EDGE_RATIO_MIN: float = 0.15
const EXTRA_EDGE_RATIO_MAX: float = 0.20

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
]

# Neutral base leaders – one node each.
const NEUTRAL_LEADERS: Array = [
	{"name": "草原部落营地", "faction": "NEUTRAL"},
	{"name": "山贼据点", "faction": "BANDIT"},
	{"name": "废墟前哨站", "faction": "NEUTRAL"},
	{"name": "沙漠商队驿站", "faction": "NEUTRAL"},
	{"name": "冰原猎手村", "faction": "NEUTRAL"},
	{"name": "暗巷佣兵所", "faction": "BANDIT"},
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

	# -- Step 3: Build edges via Kruskal's MST + extra edges -------------------
	var edges: Dictionary = _build_edges(positions, node_count)

	# -- Step 4: Assign node metadata ------------------------------------------
	var nodes: Dictionary = _assign_nodes(positions, edges, player_faction)

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
	var max_attempts: int = 5000
	var attempts: int = 0
	while positions.size() < target_count and attempts < max_attempts:
		var candidate := Vector2(
			randf_range(30, MAP_WIDTH - 30),
			randf_range(30, MAP_HEIGHT - 30)
		)
		if _min_distance_to(candidate, positions) >= MIN_NODE_DISTANCE:
			positions.append(candidate)
		attempts += 1

	# If we could not reach target_count (very unlikely), that is acceptable.
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
		# Skip very long edges to keep the map playable.
		if e["dist"] > 300.0:
			continue
		mst_edges.append(e)
		extras_added += 1

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

func _assign_nodes(positions: Array, edges: Dictionary, player_faction: int) -> Dictionary:
	var n: int = positions.size()
	var nodes: Dictionary = {}

	# Track which ids have been assigned already.
	var assigned: Dictionary = {}  # id -> true

	# --- Phase 1: Core fortresses (ids 0..7) ---------------------------------
	for i in range(FORTRESS_DATA.size()):
		var fd: Dictionary = FORTRESS_DATA[i]
		var faction_enum: int = _faction_string_to_enum(fd["faction"])
		var city_def: int = fd.get("city_def", 30)
		var garrison_count: int = fd["garrison"]
		nodes[i] = _make_node(i, positions[i], "FORTRESS", fd["name"], faction_enum, city_def, garrison_count)
		assigned[i] = true

	# --- Phase 2: Neutral leader bases (pick 6 unassigned nodes nearest center) --
	var neutral_ids: Array = _pick_unassigned_ids(positions, assigned, NEUTRAL_LEADERS.size(), Vector2(MAP_WIDTH * 0.4, MAP_HEIGHT * 0.5))
	for idx in range(neutral_ids.size()):
		var nid: int = neutral_ids[idx]
		var nl: Dictionary = NEUTRAL_LEADERS[idx]
		var fac: int = _faction_string_to_enum(nl["faction"])
		nodes[nid] = _make_node(nid, positions[nid], "STRONGHOLD", nl["name"], fac, 20, randi_range(6, 8))
		assigned[nid] = true

	# --- Phase 3: Resource stations -------------------------------------------
	var resource_nodes: Array = []
	for rp in RESOURCE_POOL:
		var count: int = randi_range(rp["count_min"], rp["count_max"])
		for c in range(count):
			resource_nodes.append({"resource_type": rp["resource_type"], "name_prefix": rp["name_prefix"]})

	var resource_ids: Array = _pick_unassigned_scattered(positions, assigned, resource_nodes.size())
	# Guard: only assign as many as we actually found positions for (Bug fix Round 3)
	var resource_assign_count: int = mini(resource_ids.size(), resource_nodes.size())
	for idx in range(resource_assign_count):
		var rid: int = resource_ids[idx]
		var rdata: Dictionary = resource_nodes[idx]
		var node_name: String = rdata["name_prefix"] + "采集站" + str(idx + 1)
		var nd: Dictionary = _make_node(rid, positions[rid], "RESOURCE", node_name, -1, 5, randi_range(3, 5))
		nd["resource_type"] = rdata["resource_type"]
		nodes[rid] = nd
		assigned[rid] = true

	# --- Phase 4: Remaining nodes – distribute by type weights ----------------
	# village 40%, stronghold 25%, bandit_camp 20%, event_point 15%
	var remaining_ids: Array = []
	for i in range(n):
		if not assigned.has(i):
			remaining_ids.append(i)
	remaining_ids.shuffle()

	# Precompute shuffled name pools.
	var village_pool: Array = VILLAGE_NAMES.duplicate()
	village_pool.shuffle()
	var stronghold_pool: Array = STRONGHOLD_NAMES.duplicate()
	stronghold_pool.shuffle()
	var bandit_pool: Array = BANDIT_NAMES.duplicate()
	bandit_pool.shuffle()
	var event_pool: Array = EVENT_NAMES.duplicate()
	event_pool.shuffle()

	var vi: int = 0
	var si: int = 0
	var bi: int = 0
	var ei: int = 0

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
			node_name = village_pool[vi % village_pool.size()] if village_pool.size() > 0 else "村庄" + str(vi)
			vi += 1
			garrison_count = randi_range(3, 5)
			city_def = 5
			owner = _region_faction(positions[nid])
		elif roll < 0.65:
			node_type = "STRONGHOLD"
			node_name = stronghold_pool[si % stronghold_pool.size()] if stronghold_pool.size() > 0 else "据点" + str(si)
			si += 1
			garrison_count = randi_range(6, 8)
			city_def = 15
			owner = _region_faction(positions[nid])
		elif roll < 0.85:
			node_type = "BANDIT_CAMP"
			node_name = bandit_pool[bi % bandit_pool.size()] if bandit_pool.size() > 0 else "匪寨" + str(bi)
			bi += 1
			garrison_count = randi_range(4, 6)
			city_def = 10
			owner = _faction_string_to_enum("BANDIT")
		else:
			node_type = "EVENT_POINT"
			node_name = event_pool[ei % event_pool.size()] if event_pool.size() > 0 else "事件点" + str(ei)
			ei += 1
			garrison_count = 0
			city_def = 0
			owner = -1

		nodes[nid] = _make_node(nid, positions[nid], node_type, node_name, owner, city_def, garrison_count)
		assigned[nid] = true

	# --- Phase 5: Player start – claim 1 fortress + 2 adjacent villages ------
	_assign_player_start(nodes, edges, player_faction)

	return nodes

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
func _make_node(id: int, pos: Vector2, type_str: String, node_name: String, owner: int, city_def: int, garrison_size: int) -> Dictionary:
	var terrain_str: String = _random_terrain()
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
