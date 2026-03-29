## deployment_phase.gd — Pre-Battle Deployment Phase (战前部署阶段)
## Autoload singleton: lets player arrange units on a 6×4 tactical grid before battle.
## AI auto-deploys instantly with smart placement based on unit types and counter analysis.
extends Node

const FormationSystem = preload("res://systems/combat/formation_system.gd")
const CounterMatrix = preload("res://systems/combat/counter_matrix.gd")
const TacticalGrid = preload("res://systems/combat/tactical_grid.gd")
const CombatResolverScript = preload("res://systems/combat/combat_resolver.gd")

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal deployment_complete(result: Dictionary)
signal formation_preview_updated(formations: Array)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const GRID_WIDTH: int = 6
const GRID_HEIGHT: int = 4
const FRONT_ROW_MAX_Y: int = 1   # y=0,1 are front rows (melee preferred)
const BACK_ROW_MIN_Y: int = 2    # y=2,3 are back rows (ranged preferred)
const DEFAULT_TIME_LIMIT: float = 60.0  # seconds, 0 = no limit

# Troop type → default row preference ("front" or "back")
# Mirrors CombatResolver.TROOP_DEFAULT_ROW
const TROOP_DEFAULT_ROW: Dictionary = {
	"ashigaru": "front", "samurai": "front", "cavalry": "front",
	"archer": "back", "ninja": "back", "priest": "back",
	"mage_unit": "back", "cannon": "back",
	"grunt": "front", "troll": "front", "warg_rider": "front",
	"cutthroat": "front", "gunner": "back", "bombardier": "back",
	"warrior": "front", "assassin": "back", "cold_lizard": "front",
	"militia": "front", "knight": "front", "temple_guard": "front",
	"elf_ranger": "back", "elf_mage": "back", "treant": "front",
	"apprentice_mage": "back", "battle_mage": "back", "archmage": "back",
	"dwarf_ironguard": "front", "skeleton_legion": "front",
	"green_archer": "back", "blood_berserker": "front",
	"goblin_artillery": "back",
	"orc_ashigaru": "front", "orc_samurai": "front", "orc_cavalry": "front",
	"pirate_ashigaru": "front", "pirate_archer": "back", "pirate_cannon": "back",
	"de_samurai": "front", "de_ninja": "back", "de_cavalry": "front",
	"human_ashigaru": "front", "human_cavalry": "front", "human_samurai": "front",
	"elf_archer": "back", "elf_ashigaru": "front",
	"mage_apprentice": "back", "mage_battle": "back", "mage_grand": "back",
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _grid: RefCounted = null  # TacticalGrid instance
var _player_units: Array = []
var _enemy_preview: Array = []
var _terrain: int = 0
var _directive: int = 0  # TacticalDirective enum from CombatResolver
var _is_active: bool = false
var _time_remaining: float = 0.0
var _time_limit: float = 0.0
var _detected_formations: Array = []

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Start the deployment phase. Player arranges units on the grid.
## Emits deployment_complete when done.
func start_deployment(player_units: Array, enemy_preview: Array, terrain: int) -> void:
	_player_units = player_units.duplicate(true)
	_enemy_preview = enemy_preview.duplicate(true)
	_terrain = terrain
	_directive = 0  # TacticalDirective.NONE
	_is_active = true
	_time_remaining = DEFAULT_TIME_LIMIT
	_time_limit = DEFAULT_TIME_LIMIT

	# Create fresh grid
	_grid = TacticalGrid.new()

	# Auto-deploy as default starting arrangement (player can rearrange)
	var auto_result: Dictionary = auto_deploy(_player_units, _terrain)
	_apply_auto_deployment(auto_result)

	# Initial formation detection
	_update_formation_preview()

	# Signal UI to open deployment screen
	EventBus.emit_signal("message_log", "战前部署阶段开始 — 在格子战场上安排部队!")

## AI/default automatic deployment. Returns placement data without modifying internal state.
func auto_deploy(units: Array, terrain: int) -> Dictionary:
	var grid_placement: Array = []  # Array of {unit, x, y}
	var occupied: Dictionary = {}   # Vector2i -> true

	# Separate units into front-preferred and back-preferred
	var front_units: Array = []
	var back_units: Array = []
	for unit in units:
		var row_pref: String = _get_row_preference(unit)
		if row_pref == "front":
			front_units.append(unit)
		else:
			back_units.append(unit)

	# Sort each group by placement score (highest priority first)
	front_units.sort_custom(func(a, b):
		return _unit_priority_score(a) > _unit_priority_score(b)
	)
	back_units.sort_custom(func(a, b):
		return _unit_priority_score(a) > _unit_priority_score(b)
	)

	# Place front units in rows 0-1
	var front_placed: int = 0
	for unit in front_units:
		var best_pos: Vector2i = _find_best_position(unit, 0, FRONT_ROW_MAX_Y, terrain, occupied)
		if best_pos.x >= 0:
			grid_placement.append({"unit": unit, "x": best_pos.x, "y": best_pos.y})
			occupied[best_pos] = true
			front_placed += 1
		else:
			# Overflow to back rows
			back_units.append(unit)

	# Place back units in rows 2-3
	for unit in back_units:
		if unit in front_units and grid_placement.any(func(p): return p["unit"] == unit):
			continue  # Already placed
		var best_pos: Vector2i = _find_best_position(unit, BACK_ROW_MIN_Y, GRID_HEIGHT - 1, terrain, occupied)
		if best_pos.x >= 0:
			grid_placement.append({"unit": unit, "x": best_pos.x, "y": best_pos.y})
			occupied[best_pos] = true
		else:
			# Overflow: try any open cell
			var fallback: Vector2i = _find_any_open_cell(occupied)
			if fallback.x >= 0:
				grid_placement.append({"unit": unit, "x": fallback.x, "y": fallback.y})
				occupied[fallback] = true

	# Detect formations for auto-deployed army
	var formation_dicts: Array = _build_formation_dicts_from_placement(grid_placement)
	var fs := FormationSystem.new()
	var formations: Array = fs.detect_formations(formation_dicts)

	return {
		"grid": grid_placement,
		"directive": _pick_ai_directive(units, _enemy_preview, terrain),
		"formations": formations,
	}

## Get the current deployment result.
func get_deployment_result() -> Dictionary:
	if _grid == null:
		return {}

	var grid_data: Array = []
	for y in range(GRID_HEIGHT):
		var row: Array = []
		for x in range(GRID_WIDTH):
			var cell = _grid.get_cell(x, y)
			if cell != null and cell.has_unit():
				row.append(cell.unit.duplicate())
			else:
				row.append({})
		grid_data.append(row)

	return {
		"grid": grid_data,
		"directive": _directive,
		"formations": _detected_formations.duplicate(),
		"tactical_grid": _grid,
	}

## Confirm deployment and emit signal.
func confirm_deployment() -> void:
	_is_active = false
	var result: Dictionary = get_deployment_result()
	deployment_complete.emit(result)

## Cancel deployment (use auto-deploy result).
func cancel_deployment() -> void:
	_is_active = false
	var result: Dictionary = get_deployment_result()
	deployment_complete.emit(result)

## Check if deployment phase is active.
func is_active() -> bool:
	return _is_active

## Set the tactical directive.
func set_directive(directive: int) -> void:
	_directive = directive

## Get current directive.
func get_directive() -> int:
	return _directive

## Place a unit at a specific grid position (player drag-and-drop).
func place_unit_at(unit: Dictionary, x: int, y: int) -> bool:
	if _grid == null or not _is_active:
		return false

	# Remove unit from its current position if already placed
	var current_pos: Vector2i = _grid.find_unit(unit.get("id", ""))
	if current_pos.x >= 0:
		_grid.remove_unit(current_pos.x, current_pos.y)

	var success: bool = _grid.place_unit(unit, x, y)
	if success:
		_update_formation_preview()
	return success

## Remove a unit from the grid.
func remove_unit_at(x: int, y: int) -> Dictionary:
	if _grid == null:
		return {}
	var removed: Dictionary = _grid.remove_unit(x, y)
	if not removed.is_empty():
		_update_formation_preview()
	return removed

## Swap two units on the grid.
func swap_units(x1: int, y1: int, x2: int, y2: int) -> bool:
	if _grid == null:
		return false
	var unit1: Dictionary = _grid.remove_unit(x1, y1)
	var unit2: Dictionary = _grid.remove_unit(x2, y2)
	var success: bool = true
	if not unit1.is_empty():
		success = success and _grid.place_unit(unit1, x2, y2)
	if not unit2.is_empty():
		success = success and _grid.place_unit(unit2, x1, y1)
	if success:
		_update_formation_preview()
	return success

## Get the current grid (for UI rendering).
func get_grid() -> RefCounted:
	return _grid

## Get counter analysis against detected enemy composition.
func get_counter_analysis() -> Array:
	var analysis: Array = []
	if _grid == null:
		return analysis

	var player_units_on_grid: Array = _grid.get_units_on_side("attacker")
	for pu in player_units_on_grid:
		var p_type: String = pu["unit"].get("unit_type", pu["unit"].get("troop_id", ""))
		for eu in _enemy_preview:
			var e_type: String = eu.get("unit_type", eu.get("troop_id", eu.get("type", "")))
			if p_type == "" or e_type == "":
				continue
			var counter: Dictionary = CounterMatrix.get_counter(p_type, e_type)
			if counter.get("advantage", "neutral") != "neutral":
				analysis.append({
					"player_unit": p_type,
					"enemy_unit": e_type,
					"advantage": counter["advantage"],
					"label": counter.get("label", ""),
					"atk_mult": counter.get("atk_mult", 1.0),
				})
	return analysis

## Get enemy preview data.
func get_enemy_preview() -> Array:
	return _enemy_preview

## Get player units.
func get_player_units() -> Array:
	return _player_units

## Process timer tick (called from deployment UI or game loop).
func tick_timer(delta: float) -> float:
	if not _is_active or _time_limit <= 0.0:
		return _time_remaining
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		confirm_deployment()
	return _time_remaining

## Get remaining time.
func get_time_remaining() -> float:
	return _time_remaining

## Check if deployment is timed.
func is_timed() -> bool:
	return _time_limit > 0.0

# ---------------------------------------------------------------------------
# Placement score (for AI and default placement)
# ---------------------------------------------------------------------------

## Calculate a placement score for a unit at a given position.
func _calculate_placement_score(unit: Dictionary, x: int, y: int, terrain: int) -> float:
	var score: float = 0.0
	var row_pref: String = _get_row_preference(unit)

	# Row preference match bonus
	if row_pref == "front" and y <= FRONT_ROW_MAX_Y:
		score += 10.0
	elif row_pref == "back" and y >= BACK_ROW_MIN_Y:
		score += 10.0
	else:
		score -= 5.0  # Penalty for wrong row

	# Center columns preferred for ranged (better coverage)
	if row_pref == "back":
		var center_dist: float = absf(float(x) - 2.5)
		score += (3.0 - center_dist) * 2.0

	# Front units prefer spread across columns for coverage
	if row_pref == "front":
		# Slight preference for even distribution
		score += 1.0

	# Edge columns bonus for potential flanking
	if x == 0 or x == GRID_WIDTH - 1:
		var troop_id: String = unit.get("troop_id", unit.get("unit_type", "")).to_lower()
		if troop_id.find("cavalry") != -1 or troop_id.find("ninja") != -1:
			score += 3.0  # Fast/flanking units prefer edges

	# Terrain-specific adjustments
	if terrain == 1:  # FOREST
		if row_pref == "back":
			score += 2.0  # Ranged units benefit from forest cover
	elif terrain == 2:  # MOUNTAIN
		if y >= BACK_ROW_MIN_Y:
			score += 1.0  # High ground advantage

	# Counter-based placement: if enemy has ranged threats, put tanky units front
	var atk: int = unit.get("atk", 0)
	var def_stat: int = unit.get("def", 0)
	if y <= FRONT_ROW_MAX_Y:
		score += float(def_stat) * 0.5  # Tankier units get bonus for front placement
	else:
		score += float(atk) * 0.3  # Higher ATK units get bonus for back placement

	return score

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _get_row_preference(unit: Dictionary) -> String:
	var troop_id: String = unit.get("troop_id", unit.get("type", unit.get("unit_type", ""))).to_lower()
	# Check known troop types
	for key in TROOP_DEFAULT_ROW:
		if troop_id.find(key) != -1:
			return TROOP_DEFAULT_ROW[key]
	# Fallback: check troop_class
	var troop_class: int = unit.get("troop_class", -1)
	match troop_class:
		0, 1, 3:  # ashigaru, samurai, cavalry
			return "front"
		2, 4, 5, 6, 7:  # archer, ninja, priest, mage, cannon
			return "back"
	return "front"

func _unit_priority_score(unit: Dictionary) -> float:
	# Higher priority = placed first (gets preferred spots)
	var soldiers: int = unit.get("soldiers", unit.get("count", 1))
	var atk: int = unit.get("atk", 0)
	var def_stat: int = unit.get("def", 0)
	return float(soldiers) * 0.5 + float(atk + def_stat)

func _find_best_position(unit: Dictionary, min_y: int, max_y: int, terrain: int, occupied: Dictionary) -> Vector2i:
	var best_pos := Vector2i(-1, -1)
	var best_score: float = -9999.0

	for y in range(min_y, max_y + 1):
		for x in range(GRID_WIDTH):
			var pos := Vector2i(x, y)
			if occupied.has(pos):
				continue
			var score: float = _calculate_placement_score(unit, x, y, terrain)
			if score > best_score:
				best_score = score
				best_pos = pos

	return best_pos

func _find_any_open_cell(occupied: Dictionary) -> Vector2i:
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			var pos := Vector2i(x, y)
			if not occupied.has(pos):
				return pos
	return Vector2i(-1, -1)

func _apply_auto_deployment(auto_result: Dictionary) -> void:
	if _grid == null:
		return
	_grid.reset()
	var placements: Array = auto_result.get("grid", [])
	for placement in placements:
		var unit: Dictionary = placement["unit"].duplicate()
		unit["side"] = "attacker"
		_grid.place_unit(unit, placement["x"], placement["y"])

func _update_formation_preview() -> void:
	if _grid == null:
		return
	var units_on_grid: Array = _grid.get_units_on_side("attacker")
	var formation_dicts: Array = []
	for entry in units_on_grid:
		formation_dicts.append(_to_formation_dict(entry["unit"], entry["y"]))

	var fs := FormationSystem.new()
	_detected_formations = fs.detect_formations(formation_dicts)
	formation_preview_updated.emit(_detected_formations)

func _to_formation_dict(unit: Dictionary, grid_y: int) -> Dictionary:
	var troop_id: String = unit.get("troop_id", unit.get("unit_type", unit.get("type", "")))
	var row: int = 0 if grid_y <= FRONT_ROW_MAX_Y else 1
	return {
		"id": unit.get("id", troop_id),
		"troop_id": troop_id,
		"unit_type": troop_id,
		"troop_class": unit.get("troop_class", -1),
		"row": row,
		"faction": unit.get("faction", ""),
	}

func _build_formation_dicts_from_placement(placements: Array) -> Array:
	var result: Array = []
	for p in placements:
		result.append(_to_formation_dict(p["unit"], p["y"]))
	return result

## AI picks a directive based on army composition and enemy analysis.
func _pick_ai_directive(player_units: Array, enemy_units: Array, terrain: int) -> int:
	# Count unit types
	var melee_count: int = 0
	var ranged_count: int = 0
	var total: int = player_units.size()

	for unit in player_units:
		var pref: String = _get_row_preference(unit)
		if pref == "front":
			melee_count += 1
		else:
			ranged_count += 1

	# Heavy melee -> ALL_OUT or HOLD_LINE
	if total > 0 and float(melee_count) / float(total) >= 0.7:
		if terrain == 5:  # FORTRESS
			return CombatResolverScript.TacticalDirective.HOLD_LINE
		return CombatResolverScript.TacticalDirective.ALL_OUT

	# Heavy ranged -> GUERRILLA
	if total > 0 and float(ranged_count) / float(total) >= 0.6:
		return CombatResolverScript.TacticalDirective.GUERRILLA

	# Small army -> AMBUSH
	if total <= 2 and total < enemy_units.size():
		return CombatResolverScript.TacticalDirective.AMBUSH

	# Balanced -> FOCUS_FIRE
	if melee_count > 0 and ranged_count > 0:
		return CombatResolverScript.TacticalDirective.FOCUS_FIRE

	# Default: NONE
	return CombatResolverScript.TacticalDirective.NONE
