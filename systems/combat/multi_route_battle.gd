## multi_route_battle.gd — Multi-route coordinated attack system (合战)
## Supports 2-4 armies attacking the same target tile simultaneously.
## Each route gets its own combat phase but shares a common defender.
## Flanking and pincer bonuses apply based on route count.
class_name MultiRouteBattle
extends RefCounted

# ─── Constants ────────────────────────────────────────────────────────────────

const MIN_ROUTES := 2
const MAX_ROUTES := 4

## Flanking: +15% ATK per additional route beyond the first
const FLANKING_ATK_BONUS_PER_ROUTE := 0.15
## Pincer: -25% DEF on defender when 3+ routes attack
const PINCER_DEF_REDUCTION := 0.25
const PINCER_MIN_ROUTES := 3

## Direction IDs for route origins
enum Direction { NORTH, SOUTH, EAST, WEST }

const DIRECTION_NAMES: Dictionary = {
	Direction.NORTH: "North",
	Direction.SOUTH: "South",
	Direction.EAST: "East",
	Direction.WEST: "West",
}

const DIRECTION_NAMES_CN: Dictionary = {
	Direction.NORTH: "北",
	Direction.SOUTH: "南",
	Direction.EAST: "东",
	Direction.WEST: "西",
}

## Terrain modifiers per direction (applied on top of base terrain)
## Keys: terrain_type -> direction -> modifier dict
## Consumers merge these into the route's combat bonuses.
const TERRAIN_DIRECTION_MODIFIERS: Dictionary = {
	"mountain": {
		Direction.NORTH: {"def_add": 2, "spd_add": -1},
		Direction.SOUTH: {"atk_add": 1},
		Direction.EAST: {},
		Direction.WEST: {"def_add": 1},
	},
	"river": {
		Direction.NORTH: {"atk_add": -2, "spd_add": -2},
		Direction.SOUTH: {"atk_add": -2, "spd_add": -2},
		Direction.EAST: {"atk_add": -1, "spd_add": -1},
		Direction.WEST: {"atk_add": -1, "spd_add": -1},
	},
	"forest": {
		Direction.NORTH: {"def_add": 1},
		Direction.SOUTH: {"def_add": 1},
		Direction.EAST: {"atk_add": -1, "def_add": 2},
		Direction.WEST: {"atk_add": -1, "def_add": 2},
	},
	"plains": {
		Direction.NORTH: {},
		Direction.SOUTH: {},
		Direction.EAST: {},
		Direction.WEST: {},
	},
}


# ─── Data Structures ─────────────────────────────────────────────────────────

## Create a battle route descriptor.
## army_data: the attacker's army dictionary (must have "army_id", "units", etc.)
## direction: Direction enum value
## terrain: terrain string at the target tile
static func create_route(army_data: Dictionary, direction: int, terrain: String = "plains") -> Dictionary:
	return {
		"army_id": army_data.get("army_id", -1),
		"army_data": army_data,
		"direction": direction,
		"terrain": terrain,
		"flanking_bonus": 0.0,
		"pincer_active": false,
		"terrain_modifiers": {},
		"phase_result": {},  # Filled after combat resolution
		"completed": false,
	}


## Create a full multi-route battle context.
## routes: Array of route dicts from create_route()
## defender_data: the defending army dictionary
## target_tile: tile index being attacked
static func create_battle(routes: Array, defender_data: Dictionary, target_tile: int) -> Dictionary:
	var clamped_routes: Array = routes.slice(0, mini(routes.size(), MAX_ROUTES))
	if clamped_routes.size() < MIN_ROUTES:
		push_warning("MultiRouteBattle: need at least %d routes, got %d" % [MIN_ROUTES, clamped_routes.size()])
		return {}

	var route_count: int = clamped_routes.size()

	return {
		"target_tile": target_tile,
		"routes": clamped_routes,
		"route_count": route_count,
		"defender_data": defender_data.duplicate(true),
		"defender_original": defender_data.duplicate(true),
		"flanking_atk_bonus": _calc_flanking_bonus(route_count),
		"pincer_active": route_count >= PINCER_MIN_ROUTES,
		"pincer_def_reduction": PINCER_DEF_REDUCTION if route_count >= PINCER_MIN_ROUTES else 0.0,
		"current_phase": 0,
		"phase_results": [],
		"resolved": false,
		"defender_survived": true,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — prepare_routes
# ═══════════════════════════════════════════════════════════════════════════════

## Apply flanking bonuses, pincer debuffs, and terrain direction modifiers to
## each route and the defender in the battle context. Call before resolving.
## Mutates battle_ctx in-place.
static func prepare_routes(battle_ctx: Dictionary) -> void:
	if battle_ctx.is_empty():
		return

	var route_count: int = battle_ctx["route_count"]
	var flanking_bonus: float = battle_ctx["flanking_atk_bonus"]
	var pincer_active: bool = battle_ctx["pincer_active"]
	var pincer_reduction: float = battle_ctx["pincer_def_reduction"]

	# Apply per-route data
	for route in battle_ctx["routes"]:
		route["flanking_bonus"] = flanking_bonus
		route["pincer_active"] = pincer_active
		route["terrain_modifiers"] = _get_terrain_direction_modifier(
			route.get("terrain", "plains"), route.get("direction", Direction.NORTH)
		)

	# Apply pincer DEF reduction to defender's units
	if pincer_active:
		var def_units: Array = battle_ctx["defender_data"].get("units", [])
		for u in def_units:
			var base_def: int = u.get("base_def", 0)
			var reduction: int = maxi(1, int(float(base_def) * pincer_reduction))
			u["base_def"] = maxi(0, base_def - reduction)
			u["_pincer_def_reduced"] = reduction

	# Emit signals
	_emit_battle_started(battle_ctx)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — get_route_attacker_bonuses
# ═══════════════════════════════════════════════════════════════════════════════

## Returns a bonuses Dictionary for a specific route's attacker, incorporating
## flanking ATK bonus and terrain direction modifiers. Merge with formation
## bonuses before passing to combat_resolver.
static func get_route_attacker_bonuses(route: Dictionary) -> Dictionary:
	var bonuses: Dictionary = {}
	var flanking: float = route.get("flanking_bonus", 0.0)
	if flanking > 0.0:
		bonuses["flanking_atk_mult"] = 1.0 + flanking

	# Merge terrain direction modifiers
	var terr_mods: Dictionary = route.get("terrain_modifiers", {})
	for key in terr_mods:
		bonuses[key] = bonuses.get(key, 0) + terr_mods[key]

	return bonuses


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — record_phase_result
# ═══════════════════════════════════════════════════════════════════════════════

## After combat_resolver finishes one route's combat phase, record the result.
## phase_result dict expected keys:
##   "attacker_won": bool, "defender_remaining_soldiers": int,
##   "attacker_losses": int, "defender_losses": int, "rounds_fought": int
## Returns true if more phases remain, false if battle is fully resolved.
static func record_phase_result(battle_ctx: Dictionary, route_index: int, phase_result: Dictionary) -> bool:
	if battle_ctx.is_empty() or route_index < 0 or route_index >= battle_ctx["route_count"]:
		return false

	var route: Dictionary = battle_ctx["routes"][route_index]
	route["phase_result"] = phase_result
	route["completed"] = true
	battle_ctx["phase_results"].append({
		"route_index": route_index,
		"army_id": route.get("army_id", -1),
		"direction": route.get("direction", Direction.NORTH),
		"result": phase_result,
	})
	battle_ctx["current_phase"] = route_index + 1

	# If defender lost (no remaining soldiers), mark immediately
	var def_remaining: int = phase_result.get("defender_remaining_soldiers", 1)
	if def_remaining <= 0:
		battle_ctx["defender_survived"] = false

	# Update defender data for next phase (carry over damage)
	if def_remaining > 0:
		_apply_defender_attrition(battle_ctx, phase_result)

	# Emit phase result signal
	_emit_phase_result(battle_ctx, route_index, phase_result)

	# Check if all phases done
	var all_done: bool = battle_ctx["current_phase"] >= battle_ctx["route_count"]
	if all_done or not battle_ctx["defender_survived"]:
		battle_ctx["resolved"] = true
		_emit_battle_resolved(battle_ctx)
		return false

	# Emit next phase start
	_emit_phase_started(battle_ctx, battle_ctx["current_phase"])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — get_battle_summary
# ═══════════════════════════════════════════════════════════════════════════════

## After all phases are resolved, return an aggregate summary.
static func get_battle_summary(battle_ctx: Dictionary) -> Dictionary:
	if not battle_ctx.get("resolved", false):
		return {"error": "Battle not yet resolved"}

	var total_atk_losses: int = 0
	var total_def_losses: int = 0
	var total_rounds: int = 0
	var routes_won: int = 0

	for pr in battle_ctx.get("phase_results", []):
		var r: Dictionary = pr.get("result", {})
		total_atk_losses += r.get("attacker_losses", 0)
		total_def_losses += r.get("defender_losses", 0)
		total_rounds += r.get("rounds_fought", 0)
		if r.get("attacker_won", false):
			routes_won += 1

	return {
		"target_tile": battle_ctx.get("target_tile", -1),
		"route_count": battle_ctx.get("route_count", 0),
		"defender_survived": battle_ctx.get("defender_survived", true),
		"routes_won_by_attacker": routes_won,
		"total_attacker_losses": total_atk_losses,
		"total_defender_losses": total_def_losses,
		"total_rounds_fought": total_rounds,
		"flanking_bonus_applied": battle_ctx.get("flanking_atk_bonus", 0.0),
		"pincer_active": battle_ctx.get("pincer_active", false),
		"phase_results": battle_ctx.get("phase_results", []),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — validate_multi_route
# ═══════════════════════════════════════════════════════════════════════════════

## Check if a set of armies can form a valid multi-route battle.
## Returns { "valid": bool, "reason": String, "route_count": int }
static func validate_multi_route(army_ids: Array, target_tile: int, army_lookup: Callable) -> Dictionary:
	if army_ids.size() < MIN_ROUTES:
		return {"valid": false, "reason": "Need at least %d armies" % MIN_ROUTES, "route_count": 0}
	if army_ids.size() > MAX_ROUTES:
		return {"valid": false, "reason": "Maximum %d armies allowed" % MAX_ROUTES, "route_count": 0}

	var directions_used: Array = []
	for aid in army_ids:
		var army: Dictionary = army_lookup.call(aid)
		if army.is_empty():
			return {"valid": false, "reason": "Army %d not found" % aid, "route_count": 0}
		var dir: int = army.get("approach_direction", -1)
		if dir in directions_used:
			return {"valid": false, "reason": "Duplicate direction for army %d" % aid, "route_count": 0}
		if dir >= 0:
			directions_used.append(dir)

	return {"valid": true, "reason": "OK", "route_count": army_ids.size()}


# ─── Private Helpers ──────────────────────────────────────────────────────────

static func _calc_flanking_bonus(route_count: int) -> float:
	# First route = baseline (0%), each additional route adds 15%
	return FLANKING_ATK_BONUS_PER_ROUTE * float(maxi(0, route_count - 1))


static func _get_terrain_direction_modifier(terrain: String, direction: int) -> Dictionary:
	var terrain_data: Dictionary = TERRAIN_DIRECTION_MODIFIERS.get(terrain, {})
	return terrain_data.get(direction, {})


static func _apply_defender_attrition(battle_ctx: Dictionary, phase_result: Dictionary) -> void:
	## Reduce defender unit soldiers based on losses from last phase.
	## Distributes losses across remaining alive units.
	var def_units: Array = battle_ctx["defender_data"].get("units", [])
	var losses: int = phase_result.get("defender_losses", 0)
	if losses <= 0:
		return

	var remaining_loss: int = losses
	for u in def_units:
		if remaining_loss <= 0:
			break
		var cur: int = u.get("soldiers", u.get("current_soldiers", 0))
		if cur <= 0:
			continue
		var lost: int = mini(cur, remaining_loss)
		if u.has("soldiers"):
			u["soldiers"] = cur - lost
		if u.has("current_soldiers"):
			u["current_soldiers"] = cur - lost
		remaining_loss -= lost


# ─── Signal Emission Helpers ──────────────────────────────────────────────────

static func _get_event_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/EventBus")


static func _emit_battle_started(ctx: Dictionary) -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
	var attacker_ids: Array = []
	for route in ctx.get("routes", []):
		attacker_ids.append(route.get("army_id", -1))
	bus.multi_route_battle_started.emit(ctx.get("target_tile", -1), ctx.get("route_count", 0), attacker_ids)

	if ctx.get("flanking_atk_bonus", 0.0) > 0.0:
		bus.flanking_bonus_applied.emit(
			ctx.get("target_tile", -1),
			ctx.get("route_count", 0),
			ctx.get("flanking_atk_bonus", 0.0)
		)
	if ctx.get("pincer_active", false):
		bus.pincer_bonus_applied.emit(
			ctx.get("target_tile", -1),
			ctx.get("pincer_def_reduction", 0.0)
		)

	# Emit first phase start
	if ctx.get("route_count", 0) > 0:
		_emit_phase_started(ctx, 0)


static func _emit_phase_started(ctx: Dictionary, phase_idx: int) -> void:
	var bus: Node = _get_event_bus()
	if bus == null or phase_idx >= ctx.get("route_count", 0):
		return
	var route: Dictionary = ctx["routes"][phase_idx]
	bus.multi_route_phase_started.emit(
		ctx.get("target_tile", -1), phase_idx, route.get("army_id", -1)
	)


static func _emit_phase_result(ctx: Dictionary, phase_idx: int, result: Dictionary) -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
	bus.multi_route_phase_result.emit(
		ctx.get("target_tile", -1), phase_idx,
		result.get("attacker_won", false), result
	)


static func _emit_battle_resolved(ctx: Dictionary) -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
	bus.multi_route_battle_resolved.emit(
		ctx.get("target_tile", -1),
		ctx.get("defender_survived", true),
		ctx.get("phase_results", [])
	)
