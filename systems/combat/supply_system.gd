class_name SupplySystem
## Army Supply Lines & Attrition system for 暗潮 SLG.
## Armies need supply and suffer attrition when overextended from owned territory.
##
## Usage:
##   var supply = SupplySystem.new()
##   supply.set_march_mode(army_id, SupplySystem.MarchMode.FORCED_MARCH)
##   var events = supply.process_turn(player_id)
##   var mods   = supply.get_combat_modifiers_for_army(army_id)

# ---------------------------------------------------------------------------
# Constants & Enums
# ---------------------------------------------------------------------------

## March modes available to the player when moving an army.
enum MarchMode {
	NORMAL        = 0,
	FORCED_MARCH  = 1,  ## AP cost -1 (min 1), supply drains 2x, SPD-1 next combat
	CAREFUL_MARCH = 2,  ## AP cost +1, supply drains 0.5x, +10% DEF, no ambush
	FORAGE        = 3,  ## Stay in place, restore 20 supply, 15% foraging accident
}

const SUPPLY_MAX          := 100
const SUPPLY_DRAIN_PER_DIST := 5   ## supply_drain = distance * this
const ATTRITION_THRESHOLD := 50    ## supply < this: light attrition
const SEVERE_THRESHOLD    := 25    ## supply < this: stat penalties + morale drain
const CATASTROPHIC         := 0    ## supply == 0: catastrophic losses

const LIGHT_ATTRITION_LOSS   := 1  ## soldiers lost per squad per turn (supply < 50)
const CATASTROPHIC_LOSS      := 5  ## soldiers lost per squad per turn (supply == 0)
const SEVERE_ATK_DEF_PENALTY := -0.20  ## -20% ATK/DEF when supply < 25
const CATASTROPHIC_ATK_DEF_PENALTY := -0.40  ## -40% ATK/DEF when supply == 0
const SEVERE_MORALE_DRAIN   := 10
const DESERT_CHANCE          := 0.10  ## 10% desert chance per squad at supply 0

const FORAGE_RESTORE       := 20
const FORAGE_ACCIDENT_CHANCE := 0.15
const FORAGE_ACCIDENT_MIN  := 1
const FORAGE_ACCIDENT_MAX  := 2

const DEPOT_GOLD_COST := 15
const DEPOT_IRON_COST := 5
const DEPOT_RANGE_BONUS := 2  ## extends supply range by this many tiles

# ---------------------------------------------------------------------------
# Internal State
# ---------------------------------------------------------------------------

## { army_id: int -> supply_level: int }
var _supply: Dictionary = {}

## { army_id: int -> MarchMode }
var _march_modes: Dictionary = {}

## Set[tile_index] of tiles with supply depots.  { tile_index: player_id }
var _supply_depots: Dictionary = {}

# ---------------------------------------------------------------------------
# References (set externally or via init)
# ---------------------------------------------------------------------------

## Placeholder for external references injected at runtime.
var game_data: Node = null   ## Expected: GameData autoload
var map_graph: Node = null   ## Expected: MapGraph / board providing adjacency + ownership

# ---------------------------------------------------------------------------
# Public API — Supply Queries
# ---------------------------------------------------------------------------

func get_supply_for_army(army_id: int) -> int:
	return _supply.get(army_id, SUPPLY_MAX)


func get_march_mode(army_id: int) -> int:
	return _march_modes.get(army_id, MarchMode.NORMAL)


func set_march_mode(army_id: int, mode: int) -> void:
	_march_modes[army_id] = mode

# ---------------------------------------------------------------------------
# Public API — Supply Depots
# ---------------------------------------------------------------------------

func is_supply_depot(tile_index: int) -> bool:
	return _supply_depots.has(tile_index)


func build_supply_depot(tile_index: int, player_id: int) -> bool:
	if _supply_depots.has(tile_index):
		return false
	# Check resources via game_data (gold & iron)
	if game_data == null:
		push_warning("SupplySystem: game_data not set — cannot check resources.")
		return false
	var player = _get_player(player_id)
	if player == null:
		return false
	var gold: int = player.get("gold", 0)
	var iron: int = player.get("iron", 0) if player.has_method("get") else _get_strategic_resource(player_id, "iron")
	if gold < DEPOT_GOLD_COST or iron < DEPOT_IRON_COST:
		return false
	# Deduct resources
	_deduct_resource(player_id, "gold", DEPOT_GOLD_COST)
	_deduct_resource(player_id, "iron", DEPOT_IRON_COST)
	_supply_depots[tile_index] = player_id
	if EventBus:
		EventBus.supply_depot_built.emit(tile_index, player_id)
	return true


func destroy_supply_depot(tile_index: int) -> void:
	if _supply_depots.has(tile_index):
		_supply_depots.erase(tile_index)
		if EventBus:
			EventBus.supply_depot_destroyed.emit(tile_index)

# ---------------------------------------------------------------------------
# Public API — Combat Modifiers
# ---------------------------------------------------------------------------

## Returns a dict with keys: atk_mod, def_mod, spd_mod (float multipliers/offsets).
func get_combat_modifiers_for_army(army_id: int) -> Dictionary:
	var supply := get_supply_for_army(army_id)
	var mode := get_march_mode(army_id)
	var mods := { "atk_mod": 0.0, "def_mod": 0.0, "spd_mod": 0 }

	# Supply penalties
	if supply <= CATASTROPHIC:
		mods["atk_mod"] = CATASTROPHIC_ATK_DEF_PENALTY
		mods["def_mod"] = CATASTROPHIC_ATK_DEF_PENALTY
	elif supply < SEVERE_THRESHOLD:
		mods["atk_mod"] = SEVERE_ATK_DEF_PENALTY
		mods["def_mod"] = SEVERE_ATK_DEF_PENALTY

	# March mode bonuses/penalties
	if mode == MarchMode.FORCED_MARCH:
		mods["spd_mod"] = -1
	elif mode == MarchMode.CAREFUL_MARCH:
		mods["def_mod"] += 0.10  # +10% DEF

	return mods

# ---------------------------------------------------------------------------
# Public API — Turn Processing
# ---------------------------------------------------------------------------

## Process supply drain, attrition, and forage for all armies belonging to player.
## Returns an Array of event Dictionaries describing what happened.
func process_turn(player_id: int) -> Array:
	var events: Array = []
	var armies := _get_armies_for_player(player_id)

	for army in armies:
		var army_id: int = army["id"]
		var tile: int = army["tile_index"]
		var mode: int = get_march_mode(army_id)

		# -- Forage mode: no movement, attempt to restore supply --
		if mode == MarchMode.FORAGE:
			var ev := _process_forage(army_id, army)
			events.append(ev)
			# Reset march mode after forage
			_march_modes[army_id] = MarchMode.NORMAL
			continue

		# -- Calculate distance to nearest owned tile / depot --
		var dist := _distance_to_supply_source(tile, player_id)

		# -- Restore or drain supply --
		var old_supply := get_supply_for_army(army_id)
		var new_supply := old_supply

		if dist <= 1:
			# On or adjacent to owned tile / depot — full restore
			new_supply = SUPPLY_MAX
		else:
			var drain := dist * SUPPLY_DRAIN_PER_DIST
			# March mode multipliers
			match mode:
				MarchMode.FORCED_MARCH:
					drain = int(drain * 2.0)
				MarchMode.CAREFUL_MARCH:
					drain = int(drain * 0.5)
			new_supply = clampi(old_supply - drain, 0, SUPPLY_MAX)

		_supply[army_id] = new_supply
		if EventBus and new_supply != old_supply:
			EventBus.army_supply_changed.emit(army_id, new_supply)

		# -- Attrition --
		var losses := _apply_attrition(army_id, new_supply, army)
		if not losses.is_empty():
			var ev := {
				"type": "attrition",
				"army_id": army_id,
				"supply": new_supply,
				"losses": losses,
			}
			events.append(ev)
			if EventBus:
				EventBus.army_attrition.emit(army_id, losses)

		# Reset march mode each turn (player must re-select)
		_march_modes[army_id] = MarchMode.NORMAL

	return events

# ---------------------------------------------------------------------------
# Public API — Army Lifecycle
# ---------------------------------------------------------------------------

## Register a new army with full supply.
func register_army(army_id: int) -> void:
	_supply[army_id] = SUPPLY_MAX
	_march_modes[army_id] = MarchMode.NORMAL


## Remove tracking when an army is disbanded.
func unregister_army(army_id: int) -> void:
	_supply.erase(army_id)
	_march_modes.erase(army_id)

# ---------------------------------------------------------------------------
# Internals — Attrition
# ---------------------------------------------------------------------------

func _apply_attrition(army_id: int, supply: int, army: Dictionary) -> Dictionary:
	var losses: Dictionary = {}
	var squads: Array = army.get("squads", [])

	if supply > ATTRITION_THRESHOLD:
		return losses

	for squad in squads:
		var squad_id: String = squad.get("id", "")
		var lost := 0

		if supply <= CATASTROPHIC:
			# Catastrophic losses
			lost = CATASTROPHIC_LOSS
			# Desertion check
			if randf() < DESERT_CHANCE:
				lost += squad.get("soldiers", 0)  # entire squad deserts
				losses[squad_id] = lost
				continue
		elif supply < SEVERE_THRESHOLD:
			lost = LIGHT_ATTRITION_LOSS
		else:
			# supply < ATTRITION_THRESHOLD
			lost = LIGHT_ATTRITION_LOSS

		if lost > 0:
			losses[squad_id] = lost

	return losses

# ---------------------------------------------------------------------------
# Internals — Forage
# ---------------------------------------------------------------------------

func _process_forage(army_id: int, army: Dictionary) -> Dictionary:
	var old_supply := get_supply_for_army(army_id)
	var new_supply := mini(old_supply + FORAGE_RESTORE, SUPPLY_MAX)
	_supply[army_id] = new_supply

	var ev: Dictionary = {
		"type": "forage",
		"army_id": army_id,
		"supply_before": old_supply,
		"supply_after": new_supply,
		"accident": false,
		"accident_losses": {},
	}

	# Foraging accident
	if randf() < FORAGE_ACCIDENT_CHANCE:
		ev["accident"] = true
		var squads: Array = army.get("squads", [])
		for squad in squads:
			var squad_id: String = squad.get("id", "")
			var lost := randi_range(FORAGE_ACCIDENT_MIN, FORAGE_ACCIDENT_MAX)
			ev["accident_losses"][squad_id] = lost
		if EventBus:
			EventBus.army_attrition.emit(army_id, ev["accident_losses"])

	if EventBus and new_supply != old_supply:
		EventBus.army_supply_changed.emit(army_id, new_supply)

	return ev

# ---------------------------------------------------------------------------
# Internals — Distance Calculation
# ---------------------------------------------------------------------------

## Return the minimum tile distance from `tile_index` to any owned tile or supply depot.
## Supply depots extend effective range by DEPOT_RANGE_BONUS.
func _distance_to_supply_source(tile_index: int, player_id: int) -> int:
	if map_graph == null:
		push_warning("SupplySystem: map_graph not set — assuming distance 0.")
		return 0

	# Delegate to map_graph which is expected to expose a BFS / distance helper.
	# _bfs_nearest_owned returns the tile distance to the closest owned tile.
	var base_dist: int = 999
	if map_graph.has_method("get_tile_distance_to_nearest_owned"):
		base_dist = map_graph.get_tile_distance_to_nearest_owned(tile_index, player_id)
	else:
		# Fallback: check ownership of current tile
		var owner_id = map_graph.get("tile_owner") if map_graph else {}
		if typeof(owner_id) == TYPE_DICTIONARY:
			if owner_id.get(tile_index, -1) == player_id:
				base_dist = 0

	# Check supply depots — depot effectively makes the tile an owned tile for supply
	for depot_tile in _supply_depots:
		if _supply_depots[depot_tile] != player_id:
			continue
		var depot_dist := _tile_distance(tile_index, depot_tile)
		# Depot extends range: if army is within DEPOT_RANGE_BONUS of depot, treat as dist 1
		var effective := depot_dist - DEPOT_RANGE_BONUS
		if effective < 0:
			effective = 0
		base_dist = mini(base_dist, effective)

	return base_dist


func _tile_distance(a: int, b: int) -> int:
	if a == b:
		return 0
	if map_graph and map_graph.has_method("get_tile_distance"):
		return map_graph.get_tile_distance(a, b)
	# Fallback: treat as far
	return 999

# ---------------------------------------------------------------------------
# Internals — Helpers (adapt to project specifics)
# ---------------------------------------------------------------------------

func _get_armies_for_player(player_id: int) -> Array:
	## Expected to return Array of Dicts: { id, tile_index, squads: [{ id, soldiers, ... }] }
	if game_data and game_data.has_method("get_armies_for_player"):
		return game_data.get_armies_for_player(player_id)
	push_warning("SupplySystem: game_data.get_armies_for_player() not available.")
	return []


func _get_player(player_id: int) -> Variant:
	if game_data and game_data.has_method("get_player"):
		return game_data.get_player(player_id)
	return null


func _get_strategic_resource(player_id: int, resource: String) -> int:
	if game_data and game_data.has_method("get_strategic_resource"):
		return game_data.get_strategic_resource(player_id, resource)
	return 0


func _deduct_resource(player_id: int, resource: String, amount: int) -> void:
	if game_data and game_data.has_method("deduct_resource"):
		game_data.deduct_resource(player_id, resource, amount)
