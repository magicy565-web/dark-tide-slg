## tactical_grid.gd — 6x4 Tactical Grid Battlefield for positional combat
## Columns (x: 0-5) = lateral position, Rows (y: 0-3) = depth (0=front, 3=rear)
## Each cell holds at most 1 unit. Supports movement, range, LoS, flanking, AoE.
class_name TacticalGrid
extends RefCounted

# Grid dimensions
const GRID_WIDTH: int = 6
const GRID_HEIGHT: int = 4

# Range constants by unit archetype
const RANGE_MELEE: int = 1
const RANGE_RANGED: int = 3
const RANGE_ARTILLERY: int = 4

# Positional bonus constants
const FLANK_DAMAGE_BONUS: float = 0.15
const REAR_DAMAGE_BONUS: float = 0.25
const ARTILLERY_MAX_RANGE_ACCURACY_PENALTY: float = 0.20

# Obstacle types
const OBSTACLE_NONE: String = ""
const OBSTACLE_RUBBLE: String = "rubble"
const OBSTACLE_WATER: String = "water"
const OBSTACLE_FIRE: String = "fire"
const OBSTACLE_WALL: String = "wall"

# AoE pattern names
const AOE_CROSS: String = "cross"
const AOE_LINE_H: String = "line_h"
const AOE_LINE_V: String = "line_v"
const AOE_AREA_2X2: String = "area_2x2"

# ---------------------------------------------------------------------------
# GridCell
# ---------------------------------------------------------------------------

class GridCell:
	var x: int
	var y: int
	var unit: Dictionary  # {} if empty; unit dict with at least "id", "side"
	var obstacle: String  # OBSTACLE_* constant
	var terrain_bonus: Dictionary  # e.g. {"def": 2} for rubble

	func _init(cx: int, cy: int) -> void:
		x = cx
		y = cy
		unit = {}
		obstacle = OBSTACLE_NONE
		terrain_bonus = {}

	func is_empty() -> bool:
		return unit.is_empty()

	func has_unit() -> bool:
		return not unit.is_empty()

	func clear_unit() -> void:
		unit = {}

# ---------------------------------------------------------------------------
# Grid state
# ---------------------------------------------------------------------------

var cells: Array = []  # Flat array of GridCell, indexed [y * GRID_WIDTH + x]

func _init() -> void:
	_initialize_grid()

func _initialize_grid() -> void:
	cells.clear()
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			cells.append(GridCell.new(x, y))

## Reset grid to empty state, clearing all units and obstacles.
func reset() -> void:
	_initialize_grid()

# ---------------------------------------------------------------------------
# Cell access
# ---------------------------------------------------------------------------

func _cell_index(x: int, y: int) -> int:
	return y * GRID_WIDTH + x

func is_valid(x: int, y: int) -> bool:
	return x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT

func get_cell(x: int, y: int) -> GridCell:
	if not is_valid(x, y):
		return null
	return cells[_cell_index(x, y)]

func get_unit_at(x: int, y: int) -> Dictionary:
	var cell: GridCell = get_cell(x, y)
	if cell == null:
		return {}
	return cell.unit

# ---------------------------------------------------------------------------
# Unit placement
# ---------------------------------------------------------------------------

## Place a unit dict onto the grid. Returns true on success.
func place_unit(unit: Dictionary, x: int, y: int) -> bool:
	if not is_valid(x, y):
		return false
	var cell: GridCell = get_cell(x, y)
	if cell.has_unit():
		return false
	if cell.obstacle == OBSTACLE_WALL:
		return false
	cell.unit = unit.duplicate()
	cell.unit["grid_x"] = x
	cell.unit["grid_y"] = y
	return true

## Remove unit from a cell. Returns the removed unit dict (or {} if empty).
func remove_unit(x: int, y: int) -> Dictionary:
	if not is_valid(x, y):
		return {}
	var cell: GridCell = get_cell(x, y)
	var removed: Dictionary = cell.unit
	cell.clear_unit()
	return removed

# ---------------------------------------------------------------------------
# Obstacles
# ---------------------------------------------------------------------------

## Set an obstacle on a cell. Clears any existing unit if wall.
func set_obstacle(x: int, y: int, obstacle_type: String) -> void:
	if not is_valid(x, y):
		return
	var cell: GridCell = get_cell(x, y)
	cell.obstacle = obstacle_type
	cell.terrain_bonus = _get_obstacle_bonus(obstacle_type)
	if obstacle_type == OBSTACLE_WALL:
		cell.clear_unit()

func _get_obstacle_bonus(obstacle_type: String) -> Dictionary:
	match obstacle_type:
		OBSTACLE_RUBBLE:
			return {"def": 2}
		OBSTACLE_WATER:
			return {"spd": -1}
		_:
			return {}

# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

## Move a unit from one cell to another. Returns true on success.
func move_unit(from_x: int, from_y: int, to_x: int, to_y: int) -> bool:
	if not is_valid(from_x, from_y) or not is_valid(to_x, to_y):
		return false
	var from_cell: GridCell = get_cell(from_x, from_y)
	var to_cell: GridCell = get_cell(to_x, to_y)
	if not from_cell.has_unit() or to_cell.has_unit():
		return false
	if to_cell.obstacle == OBSTACLE_WALL:
		return false
	# Check move is within valid range
	var valid_moves: Array = get_valid_moves(from_x, from_y)
	var target := Vector2i(to_x, to_y)
	if target not in valid_moves:
		return false
	to_cell.unit = from_cell.unit.duplicate()
	to_cell.unit["grid_x"] = to_x
	to_cell.unit["grid_y"] = to_y
	from_cell.clear_unit()
	return true

## Get all valid move destinations for a unit at (x, y).
## Most units move 1 cell; cavalry can move 2.
func get_valid_moves(x: int, y: int) -> Array:
	var result: Array = []  # Array of Vector2i
	if not is_valid(x, y):
		return result
	var cell: GridCell = get_cell(x, y)
	if not cell.has_unit():
		return result

	var move_range: int = _get_move_range(cell.unit)

	# BFS to find all reachable cells within move_range
	var visited: Dictionary = {}
	var frontier: Array = [[x, y, 0]]  # [cx, cy, dist]
	visited[Vector2i(x, y)] = true

	while not frontier.is_empty():
		var current: Array = frontier.pop_front()
		var cx: int = current[0]
		var cy: int = current[1]
		var dist: int = current[2]

		if dist > 0:
			var target_cell: GridCell = get_cell(cx, cy)
			if target_cell != null and not target_cell.has_unit() and target_cell.obstacle != OBSTACLE_WALL:
				result.append(Vector2i(cx, cy))

		if dist < move_range:
			for neighbor in _orthogonal_neighbors(cx, cy):
				var nv := Vector2i(neighbor[0], neighbor[1])
				if not visited.has(nv):
					visited[nv] = true
					var ncell: GridCell = get_cell(neighbor[0], neighbor[1])
					if ncell != null and ncell.obstacle != OBSTACLE_WALL:
						frontier.append([neighbor[0], neighbor[1], dist + 1])

	return result

func _get_move_range(unit: Dictionary) -> int:
	var troop_id: String = unit.get("troop_id", unit.get("unit_type", "")).to_lower()
	if troop_id.find("cavalry") != -1 or troop_id.find("rider") != -1 or troop_id.find("horseman") != -1:
		return 2
	return 1

func _orthogonal_neighbors(x: int, y: int) -> Array:
	var result: Array = []
	if x > 0:
		result.append([x - 1, y])
	if x < GRID_WIDTH - 1:
		result.append([x + 1, y])
	if y > 0:
		result.append([x, y - 1])
	if y < GRID_HEIGHT - 1:
		result.append([x, y + 1])
	return result

# ---------------------------------------------------------------------------
# Attack targeting
# ---------------------------------------------------------------------------

## Get all cells a unit at (x, y) can attack based on its attack range.
func get_attack_targets(x: int, y: int, attack_range: int) -> Array:
	var result: Array = []  # Array of Vector2i
	if not is_valid(x, y):
		return result
	var attacker_cell: GridCell = get_cell(x, y)
	if not attacker_cell.has_unit():
		return result

	var attacker_side: String = attacker_cell.unit.get("side", "")

	for cy in range(GRID_HEIGHT):
		for cx in range(GRID_WIDTH):
			if cx == x and cy == y:
				continue
			var dist: int = _manhattan_distance(x, y, cx, cy)
			if dist > attack_range:
				continue
			var target_cell: GridCell = get_cell(cx, cy)
			if not target_cell.has_unit():
				continue
			# Can only attack enemies
			if target_cell.unit.get("side", "") == attacker_side:
				continue
			# Melee: adjacent only
			if attack_range == RANGE_MELEE and dist > 1:
				continue
			# Ranged (2-3): check LoS blockage
			if attack_range >= 2 and attack_range <= 3:
				if not check_line_of_sight(Vector2i(x, y), Vector2i(cx, cy)):
					continue
			# Artillery (4): can hit any cell, no LoS restriction
			result.append(Vector2i(cx, cy))

	return result

## Get the attack range for a unit based on its type.
func get_unit_attack_range(unit: Dictionary) -> int:
	var troop_id: String = unit.get("troop_id", unit.get("unit_type", "")).to_lower()
	# Artillery
	if troop_id.find("cannon") != -1 or troop_id.find("artillery") != -1 or troop_id.find("bombardier") != -1:
		return RANGE_ARTILLERY
	# Ranged
	if troop_id.find("archer") != -1 or troop_id.find("gunner") != -1 or troop_id.find("ranger") != -1 or troop_id.find("marksman") != -1:
		return RANGE_RANGED
	# Mages have range 2
	if troop_id.find("mage") != -1 or troop_id.find("wizard") != -1 or troop_id.find("sorcerer") != -1:
		return 2
	# Melee default
	return RANGE_MELEE

# ---------------------------------------------------------------------------
# AoE
# ---------------------------------------------------------------------------

## Get all cells hit by an AoE pattern centered on a given cell.
func get_aoe_targets(center: Vector2i, pattern: String) -> Array:
	var result: Array = []  # Array of Vector2i
	match pattern:
		AOE_CROSS:
			result.append(center)
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var pos: Vector2i = center + offset
				if is_valid(pos.x, pos.y):
					result.append(pos)
		AOE_LINE_H:
			for dx in range(-2, 3):
				var pos := Vector2i(center.x + dx, center.y)
				if is_valid(pos.x, pos.y):
					result.append(pos)
		AOE_LINE_V:
			for dy in range(-2, 3):
				var pos := Vector2i(center.x, center.y + dy)
				if is_valid(pos.x, pos.y):
					result.append(pos)
		AOE_AREA_2X2:
			for dx in range(2):
				for dy in range(2):
					var pos := Vector2i(center.x + dx, center.y + dy)
					if is_valid(pos.x, pos.y):
						result.append(pos)
		_:
			result.append(center)
	return result

# ---------------------------------------------------------------------------
# Flanking & Rear attack
# ---------------------------------------------------------------------------

## Check positional advantage of attacker vs defender.
## Returns {is_flank: bool, is_rear: bool, damage_multiplier: float}
func check_flanking(attacker_pos: Vector2i, defender_pos: Vector2i) -> Dictionary:
	var result: Dictionary = {"is_flank": false, "is_rear": false, "damage_multiplier": 1.0}

	# Rear attack: attacker is behind the defender (higher y = further back)
	# For attacker-side units (y=0 is front), attacking defender at lower y from higher y is rear
	# Simplified: if attacker's y > defender's y, it's a rear attack
	if attacker_pos.y > defender_pos.y:
		result["is_rear"] = true
		result["damage_multiplier"] += REAR_DAMAGE_BONUS
		return result

	# Flank: attacking from side columns (x=0 or x=5, the extreme edges)
	if attacker_pos.x == 0 or attacker_pos.x == GRID_WIDTH - 1:
		# Only counts as flank if defender is not also on an edge
		if defender_pos.x != 0 and defender_pos.x != GRID_WIDTH - 1:
			result["is_flank"] = true
			result["damage_multiplier"] += FLANK_DAMAGE_BONUS

	return result

# ---------------------------------------------------------------------------
# Line of Sight
# ---------------------------------------------------------------------------

## Check if there is a clear line of sight from `from` to `to`.
## Units (friendly or enemy) in intermediate cells along the cardinal/direct path block LoS.
func check_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return true

	# Get the source unit's side to determine what blocks
	var from_cell: GridCell = get_cell(from.x, from.y)
	if from_cell == null:
		return false
	var attacker_side: String = from_cell.unit.get("side", "")

	# Use Bresenham-like stepping through intermediate cells
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	var steps: int = maxi(absi(dx), absi(dy))
	if steps <= 1:
		return true  # Adjacent cells always have LoS

	var fx: float = float(from.x)
	var fy: float = float(from.y)
	var step_x: float = float(dx) / float(steps)
	var step_y: float = float(dy) / float(steps)

	for i in range(1, steps):
		fx += step_x
		fy += step_y
		var check_x: int = roundi(fx)
		var check_y: int = roundi(fy)
		if check_x == to.x and check_y == to.y:
			break
		if not is_valid(check_x, check_y):
			continue
		var check_cell: GridCell = get_cell(check_x, check_y)
		if check_cell == null:
			continue
		# Walls always block
		if check_cell.obstacle == OBSTACLE_WALL:
			return false
		# Units in intermediate cells block ranged attacks
		if check_cell.has_unit():
			return false

	return true

# ---------------------------------------------------------------------------
# Adjacency helpers
# ---------------------------------------------------------------------------

## Get all adjacent cell positions (orthogonal + diagonal).
func get_adjacent(x: int, y: int) -> Array:
	var result: Array = []  # Array of Vector2i
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if is_valid(nx, ny):
				result.append(Vector2i(nx, ny))
	return result

## Get orthogonal neighbors only (no diagonals).
func get_orthogonal_adjacent(x: int, y: int) -> Array:
	var result: Array = []
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if is_valid(nx, ny):
			result.append(Vector2i(nx, ny))
	return result

# ---------------------------------------------------------------------------
# Obstacle effects
# ---------------------------------------------------------------------------

## Apply start-of-round obstacle effects to all units on the grid.
## Returns an array of log entries.
func apply_obstacle_effects() -> Array:
	var log_entries: Array = []
	for cell_obj in cells:
		var cell: GridCell = cell_obj
		if not cell.has_unit():
			continue
		match cell.obstacle:
			OBSTACLE_FIRE:
				var unit_id: String = cell.unit.get("id", "unknown")
				cell.unit["soldiers"] = maxi(0, cell.unit.get("soldiers", 0) - 3)
				if cell.unit.get("soldiers", 0) <= 0:
					cell.unit["is_alive"] = false
				log_entries.append({
					"type": "obstacle_damage",
					"obstacle": OBSTACLE_FIRE,
					"unit_id": unit_id,
					"damage": 3,
					"x": cell.x, "y": cell.y,
				})
			OBSTACLE_WATER:
				pass  # SPD penalty applied via terrain_bonus in damage calc
			OBSTACLE_RUBBLE:
				pass  # DEF bonus applied via terrain_bonus in damage calc
	return log_entries

## Get terrain bonus for a unit at a given position.
func get_terrain_bonus(x: int, y: int) -> Dictionary:
	if not is_valid(x, y):
		return {}
	var cell: GridCell = get_cell(x, y)
	return cell.terrain_bonus.duplicate()

# ---------------------------------------------------------------------------
# Query helpers
# ---------------------------------------------------------------------------

## Find the position of a unit by its id. Returns Vector2i(-1, -1) if not found.
func find_unit(unit_id: String) -> Vector2i:
	for cell_obj in cells:
		var cell: GridCell = cell_obj
		if cell.has_unit() and cell.unit.get("id", "") == unit_id:
			return Vector2i(cell.x, cell.y)
	return Vector2i(-1, -1)

## Get all units on a specific side. Returns array of {unit, x, y}.
func get_units_on_side(side: String) -> Array:
	var result: Array = []
	for cell_obj in cells:
		var cell: GridCell = cell_obj
		if cell.has_unit() and cell.unit.get("side", "") == side:
			result.append({"unit": cell.unit, "x": cell.x, "y": cell.y})
	return result

## Get all occupied cells.
func get_all_units() -> Array:
	var result: Array = []
	for cell_obj in cells:
		var cell: GridCell = cell_obj
		if cell.has_unit():
			result.append({"unit": cell.unit, "x": cell.x, "y": cell.y})
	return result

## Check if the grid is actively being used (has any placed units).
func is_active() -> bool:
	for cell_obj in cells:
		var cell: GridCell = cell_obj
		if cell.has_unit():
			return true
	return false

## Get the artillery accuracy penalty for a shot at max range.
func get_artillery_accuracy_penalty(from: Vector2i, to: Vector2i) -> float:
	var dist: int = _manhattan_distance(from.x, from.y, to.x, to.y)
	if dist >= RANGE_ARTILLERY:
		return ARTILLERY_MAX_RANGE_ACCURACY_PENALTY
	return 0.0

# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _manhattan_distance(x1: int, y1: int, x2: int, y2: int) -> int:
	return absi(x2 - x1) + absi(y2 - y1)

## Serialize grid state to a dictionary for save/load or passing to combat resolver.
func serialize() -> Dictionary:
	var grid_data: Array = []
	for y in range(GRID_HEIGHT):
		var row: Array = []
		for x in range(GRID_WIDTH):
			var cell: GridCell = get_cell(x, y)
			row.append({
				"unit": cell.unit.duplicate() if cell.has_unit() else {},
				"obstacle": cell.obstacle,
			})
		grid_data.append(row)
	return {"width": GRID_WIDTH, "height": GRID_HEIGHT, "grid": grid_data}

## Load grid state from a serialized dictionary.
func deserialize(data: Dictionary) -> void:
	reset()
	var grid_data: Array = data.get("grid", [])
	for y in range(mini(grid_data.size(), GRID_HEIGHT)):
		var row: Array = grid_data[y]
		for x in range(mini(row.size(), GRID_WIDTH)):
			var cell_data: Dictionary = row[x]
			var cell: GridCell = get_cell(x, y)
			if cell_data.get("obstacle", "") != "":
				set_obstacle(x, y, cell_data["obstacle"])
			var unit_data: Dictionary = cell_data.get("unit", {})
			if not unit_data.is_empty():
				cell.unit = unit_data.duplicate()
