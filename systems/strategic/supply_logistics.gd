## SupplyLogistics (autoload — no class_name to avoid conflict)
## supply_logistics.gd - Deep Supply Chain & Logistics system for 暗潮 SLG.
## Manages depot networks, supply routes, convoys, army consumption, supply events,
## and faction-specific supply bonuses.
##
## Usage:
##   var logistics = SupplyLogistics.new()
##   logistics.process_turn(player_id)
##   var status = logistics.get_army_supply_status(army_id)
##   var eff = logistics.get_supply_efficiency(army_id)
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# 1. DEPOT NETWORK
# ═══════════════════════════════════════════════════════════════════════════════

## tile_idx -> DepotData dictionary
var _depots: Dictionary = {}

## Capital capacity is significantly higher than standard depots
const CAPITAL_CAPACITY: int = 200
const CAPITAL_PRODUCTION: int = 15
const STANDARD_CAPACITY: int = 100
const STANDARD_PRODUCTION: int = 8

## Buildings that qualify a tile as a supply depot
const DEPOT_BUILDING_IDS: Array = ["warehouse", "barracks", "smugglers_den", "totem_pole"]

func _make_depot(tile_idx: int, owner_id: int, capacity: int, production: int) -> Dictionary:
	return {
		"tile_idx": tile_idx,
		"owner_id": owner_id,
		"capacity": capacity,
		"current_supply": capacity,
		"production": production,
		"connected_to": [],
	}


func rebuild_depot_network(player_id: int) -> void:
	## Scan all owned tiles and rebuild depots for this player.
	# Remove old depots for this player
	var to_erase: Array = []
	for tidx in _depots:
		if _depots[tidx]["owner_id"] == player_id:
			to_erase.append(tidx)
	for tidx in to_erase:
		_depots.erase(tidx)

	var capital_tile: int = -1
	if SupplySystem != null and SupplySystem.has_method("get_capital"):
		capital_tile = SupplySystem.get_capital(player_id)

	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) != player_id:
			continue
		var tidx: int = tile["index"]
		var is_capital: bool = (tidx == capital_tile)
		var building_id: String = tile.get("building_id", "")
		# Check tile_development buildings array as well
		var has_depot_building: bool = building_id in DEPOT_BUILDING_IDS
		if not has_depot_building:
			var dev: Dictionary = tile.get("development", {})
			var buildings: Array = dev.get("buildings", [])
			for bid in buildings:
				if bid in DEPOT_BUILDING_IDS:
					has_depot_building = true
					break

		if is_capital:
			_depots[tidx] = _make_depot(tidx, player_id, CAPITAL_CAPACITY, CAPITAL_PRODUCTION)
		elif has_depot_building:
			var food_prod: int = tile.get("food", tile.get("prod", {}).get("food", 0))
			@warning_ignore("integer_division")
			var prod: int = maxi(STANDARD_PRODUCTION, STANDARD_PRODUCTION + food_prod / 2)
			_depots[tidx] = _make_depot(tidx, player_id, STANDARD_CAPACITY, prod)

	# Build connectivity between depots via BFS through owned territory
	_build_depot_connections(player_id)


func _build_depot_connections(player_id: int) -> void:
	## Connect depots that can reach each other through owned territory.
	var player_depots: Array = []
	for tidx in _depots:
		if _depots[tidx]["owner_id"] == player_id:
			player_depots.append(tidx)

	for i in range(player_depots.size()):
		_depots[player_depots[i]]["connected_to"] = []

	# BFS from each depot to find reachable depots
	for i in range(player_depots.size()):
		var src: int = player_depots[i]
		var visited: Dictionary = {src: true}
		var queue: Array = [src]
		while not queue.is_empty():
			var current: int = queue.pop_front()
			for nb in GameManager.adjacency.get(current, []):
				if visited.has(nb):
					continue
				if nb < 0 or nb >= GameManager.tiles.size():
					continue
				if GameManager.tiles[nb] == null:
					continue
				if GameManager.tiles[nb].get("owner_id", -1) != player_id:
					continue
				visited[nb] = true
				queue.append(nb)
				if _depots.has(nb) and _depots[nb]["owner_id"] == player_id:
					if nb not in _depots[src]["connected_to"]:
						_depots[src]["connected_to"].append(nb)


func replenish_depots(player_id: int) -> void:
	## Each depot produces supply up to its capacity each turn.
	for tidx in _depots:
		var depot: Dictionary = _depots[tidx]
		if depot["owner_id"] != player_id:
			continue
		var prod: int = depot["production"]
		# Apply active supply events
		prod = int(float(prod) * _get_depot_production_multiplier(tidx))
		depot["current_supply"] = mini(depot["current_supply"] + prod, depot["capacity"])


func get_depot(tile_idx: int) -> Dictionary:
	return _depots.get(tile_idx, {})


func get_player_depots(player_id: int) -> Array:
	var result: Array = []
	for tidx in _depots:
		if _depots[tidx]["owner_id"] == player_id:
			result.append(_depots[tidx])
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# 2. SUPPLY ROUTES
# ═══════════════════════════════════════════════════════════════════════════════

## Route efficiency thresholds by distance (tiles from nearest depot)
const ROUTE_FULL_RANGE: int = 3        # 1-3 tiles = 100% supply delivery
const ROUTE_REDUCED_RANGE: int = 6     # 4-6 tiles = 75%
const ROUTE_EXTENDED_RANGE: int = 99   # 7+ tiles  = 50%
const ROUTE_FULL_EFFICIENCY: float = 1.0
const ROUTE_REDUCED_EFFICIENCY: float = 0.75
const ROUTE_EXTENDED_EFFICIENCY: float = 0.50
const ROUTE_NO_ROUTE_EFFICIENCY: float = 0.0


func calculate_supply_route(army_id: int) -> Dictionary:
	## BFS from army tile to nearest depot. Returns route details.
	## {path: Array, efficiency: float, is_cut: bool, cut_by: int, depot_tile: int, distance: int}
	var result: Dictionary = {
		"path": [],
		"efficiency": ROUTE_NO_ROUTE_EFFICIENCY,
		"is_cut": false,
		"cut_by": -1,
		"depot_tile": -1,
		"distance": 999,
	}

	if not GameManager.armies.has(army_id):
		return result
	var army: Dictionary = GameManager.armies[army_id]
	var player_id: int = army.get("player_id", -1)
	var army_tile: int = army.get("tile_index", -1)
	if player_id < 0 or army_tile < 0:
		return result

	# Check faction coastal resupply (Pirate)
	var faction_id: int = _get_faction_id(player_id)
	if faction_id == FactionData.FactionID.PIRATE:
		if _is_coastal_tile(army_tile):
			result["path"] = [army_tile]
			result["efficiency"] = ROUTE_FULL_EFFICIENCY
			result["depot_tile"] = army_tile
			result["distance"] = 0
			return result

	# BFS from army_tile looking for any depot owned by player
	var parent: Dictionary = {army_tile: -1}
	var queue: Array = [army_tile]
	var found_depot: int = -1

	while not queue.is_empty():
		var current: int = queue.pop_front()
		# Check if current tile is a depot
		if _depots.has(current) and _depots[current]["owner_id"] == player_id:
			found_depot = current
			break
		for nb in GameManager.adjacency.get(current, []):
			if parent.has(nb):
				continue
			if nb < 0 or nb >= GameManager.tiles.size():
				continue
			if GameManager.tiles[nb] == null:
				continue
			# Allow BFS through own territory AND neutral/unowned tiles
			# (supply routes can cross non-enemy territory)
			var nb_owner: int = GameManager.tiles[nb].get("owner_id", -1)
			if nb_owner >= 0 and nb_owner != player_id:
				continue  # blocked by enemy territory
			parent[nb] = current
			queue.append(nb)

	if found_depot < 0:
		return result

	# Reconstruct path from army to depot
	var path: Array = []
	var cur: int = found_depot
	while cur != -1:
		path.push_front(cur)
		cur = parent.get(cur, -1)

	result["path"] = path
	result["depot_tile"] = found_depot
	result["distance"] = path.size() - 1  # distance in tiles (edges, not nodes)

	# Check if route is cut by enemy army occupying a tile along the path
	for i in range(1, path.size() - 1):  # skip endpoints (army tile and depot tile)
		var route_tile: int = path[i]
		var enemy_army_id: int = _enemy_army_on_tile(route_tile, player_id)
		if enemy_army_id >= 0:
			result["is_cut"] = true
			result["cut_by"] = enemy_army_id
			result["efficiency"] = ROUTE_NO_ROUTE_EFFICIENCY
			return result

	# Calculate efficiency based on distance
	var dist: int = result["distance"]
	if dist <= ROUTE_FULL_RANGE:
		result["efficiency"] = ROUTE_FULL_EFFICIENCY
	elif dist <= ROUTE_REDUCED_RANGE:
		result["efficiency"] = ROUTE_REDUCED_EFFICIENCY
	else:
		result["efficiency"] = ROUTE_EXTENDED_EFFICIENCY

	return result


func get_supply_efficiency(army_id: int) -> float:
	## Convenience: returns 0.0 to 1.0 supply efficiency for army.
	var route: Dictionary = calculate_supply_route(army_id)
	return route["efficiency"]


func _enemy_army_on_tile(tile_idx: int, player_id: int) -> int:
	## Returns the id of an enemy army at tile_idx, or -1.
	for aid in GameManager.armies:
		var a: Dictionary = GameManager.armies[aid]
		if a.get("player_id", -1) == player_id:
			continue
		if a.get("tile_index", -1) == tile_idx:
			return aid
	return -1


func _is_coastal_tile(tile_idx: int) -> bool:
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return false
	var tile: Dictionary = GameManager.tiles[tile_idx]
	if tile == null:
		return false
	var terrain: int = tile.get("terrain", -1)
	return terrain == FactionData.TerrainType.COASTAL

# ═══════════════════════════════════════════════════════════════════════════════
# 3. SUPPLY CONVOYS
# ═══════════════════════════════════════════════════════════════════════════════

var _convoys: Array = []
var _next_convoy_id: int = 1

const CONVOY_BASE_HP: int = 50
const CONVOY_BASE_ESCORT: int = 10
const CONVOY_INTERCEPT_LOSS_PCT: float = 0.5  # lose 50% supplies on interception


func dispatch_convoy(from_depot_tile: int, to_army_id: int, amount: int) -> int:
	## Dispatch a supply convoy from a depot to a specific army.
	## Returns convoy_id on success, -1 on failure.
	if not _depots.has(from_depot_tile):
		return -1
	if not GameManager.armies.has(to_army_id):
		return -1

	var depot: Dictionary = _depots[from_depot_tile]
	var army: Dictionary = GameManager.armies[to_army_id]
	if depot["owner_id"] != army.get("player_id", -1):
		return -1

	# Clamp amount to what depot has available
	var actual: int = mini(amount, depot["current_supply"])
	if actual <= 0:
		return -1

	# Calculate route from depot to army tile
	var army_tile: int = army.get("tile_index", -1)
	if army_tile < 0:
		return -1

	var path: Array = _bfs_path(from_depot_tile, army_tile, depot["owner_id"])
	if path.is_empty():
		return -1

	depot["current_supply"] -= actual

	var convoy_id: int = _next_convoy_id
	_next_convoy_id += 1

	var convoy: Dictionary = {
		"id": convoy_id,
		"from_depot": from_depot_tile,
		"to_army": to_army_id,
		"supplies": actual,
		"current_tile": from_depot_tile,
		"path": path,
		"path_step": 0,
		"hp": CONVOY_BASE_HP,
		"escort_strength": CONVOY_BASE_ESCORT,
		"owner_id": depot["owner_id"],
	}
	_convoys.append(convoy)

	if depot["owner_id"] == GameManager.get_human_player_id():
		EventBus.message_log.emit("[color=cyan]补给车队已出发! 运送 %d 补给前往军团[/color]" % actual)
	return convoy_id


func _process_convoy_movement() -> void:
	## Move all convoys one tile along their route. Called each turn.
	var to_remove: Array = []

	for convoy in _convoys:
		if convoy["path_step"] >= convoy["path"].size() - 1:
			# Arrived at destination — deliver supplies
			_deliver_convoy(convoy)
			to_remove.append(convoy)
			continue

		convoy["path_step"] += 1
		var next_tile: int = convoy["path"][convoy["path_step"]]
		convoy["current_tile"] = next_tile

		# Check for interception by enemy army
		var enemy_id: int = _enemy_army_on_tile(next_tile, convoy["owner_id"])
		if enemy_id >= 0:
			_intercept_convoy(convoy, enemy_id)
			if convoy["supplies"] <= 0 or convoy["hp"] <= 0:
				to_remove.append(convoy)
				continue

	for c in to_remove:
		_convoys.erase(c)


func _deliver_convoy(convoy: Dictionary) -> void:
	## Deliver convoy supplies to the target army's supply pool.
	var army_id: int = convoy["to_army"]
	var amount: int = convoy["supplies"]
	if not _army_supply.has(army_id):
		_army_supply[army_id] = 0
	_army_supply[army_id] += amount
	if convoy["owner_id"] == GameManager.get_human_player_id():
		EventBus.message_log.emit("[color=green]补给车队抵达! 交付 %d 补给[/color]" % amount)


func _intercept_convoy(convoy: Dictionary, enemy_army_id: int) -> void:
	## Enemy army intercepts convoy — lose supplies, take damage.
	var lost_supplies: int = int(float(convoy["supplies"]) * CONVOY_INTERCEPT_LOSS_PCT)
	convoy["supplies"] -= lost_supplies
	convoy["hp"] -= 20

	if convoy["owner_id"] == GameManager.get_human_player_id():
		EventBus.message_log.emit(
			"[color=red]补给车队被敌军截击! 损失 %d 补给[/color]" % lost_supplies)


func get_convoys_for_player(player_id: int) -> Array:
	var result: Array = []
	for c in _convoys:
		if c["owner_id"] == player_id:
			result.append(c)
	return result


func _bfs_path(from_tile: int, to_tile: int, player_id: int) -> Array:
	## BFS shortest path through non-enemy territory.
	if from_tile == to_tile:
		return [from_tile]
	var parent: Dictionary = {from_tile: -1}
	var queue: Array = [from_tile]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == to_tile:
			break
		for nb in GameManager.adjacency.get(current, []):
			if parent.has(nb):
				continue
			if nb < 0 or nb >= GameManager.tiles.size():
				continue
			if GameManager.tiles[nb] == null:
				continue
			var nb_owner: int = GameManager.tiles[nb].get("owner_id", -1)
			if nb_owner >= 0 and nb_owner != player_id:
				continue
			parent[nb] = current
			queue.append(nb)
	if not parent.has(to_tile):
		return []
	var path: Array = []
	var cur: int = to_tile
	while cur != -1:
		path.push_front(cur)
		cur = parent.get(cur, -1)
	return path

# ═══════════════════════════════════════════════════════════════════════════════
# 4. ARMY SUPPLY CONSUMPTION
# ═══════════════════════════════════════════════════════════════════════════════

## army_id -> current supply points
var _army_supply: Dictionary = {}
## army_id -> consecutive turns at zero supply
var _army_zero_turns: Dictionary = {}

const ARMY_SUPPLY_BASE_CONSUMPTION: int = 5
const ARMY_SUPPLY_PER_EXTRA_TROOP: int = 1
const ARMY_SUPPLY_TROOP_FREE_COUNT: int = 3

const FORAGING_ATK_PENALTY: float = -0.10
const FORAGING_DEF_PENALTY: float = -0.10
const STARVING_ATTRITION_PCT: float = 0.05
const DISBAND_ZERO_TURNS: int = 5
const STARVING_ZERO_TURNS: int = 2


func register_army_supply(army_id: int, initial_supply: int = 50) -> void:
	_army_supply[army_id] = initial_supply
	_army_zero_turns[army_id] = 0


func unregister_army_supply(army_id: int) -> void:
	_army_supply.erase(army_id)
	_army_zero_turns.erase(army_id)


func get_army_consumption(army_id: int) -> int:
	## Calculate per-turn supply consumption for an army.
	if not GameManager.armies.has(army_id):
		return ARMY_SUPPLY_BASE_CONSUMPTION
	var army: Dictionary = GameManager.armies[army_id]
	var troop_count: int = army.get("troops", []).size()
	var extra: int = maxi(0, troop_count - ARMY_SUPPLY_TROOP_FREE_COUNT)
	var consumption: int = ARMY_SUPPLY_BASE_CONSUMPTION + extra * ARMY_SUPPLY_PER_EXTRA_TROOP

	# Apply faction multiplier
	var player_id: int = army.get("player_id", -1)
	consumption = int(float(consumption) * get_faction_consumption_multiplier(player_id))
	return maxi(1, consumption)


func _process_army_supply(player_id: int) -> Array:
	## Process supply consumption for all armies of a player. Returns event array.
	var events: Array = []
	if not GameManager.has_method("get_player_armies"):
		return events
	var armies: Array = GameManager.get_player_armies(player_id)

	for army in armies:
		var army_id: int = army.get("id", -1)
		if army_id < 0:
			continue
		if not _army_supply.has(army_id):
			register_army_supply(army_id)

		# Calculate delivery from nearest depot
		var route: Dictionary = calculate_supply_route(army_id)
		var efficiency: float = route["efficiency"]
		var depot_tile: int = route.get("depot_tile", -1)

		# Deliver supply from depot based on efficiency
		if depot_tile >= 0 and _depots.has(depot_tile) and efficiency > 0.0:
			var consumption: int = get_army_consumption(army_id)
			var needed: int = consumption
			var depot: Dictionary = _depots[depot_tile]
			var available: int = mini(needed, depot["current_supply"])
			var delivered: int = int(float(available) * efficiency)
			depot["current_supply"] -= available
			_army_supply[army_id] += delivered

		# Consume supply
		var consumption: int = get_army_consumption(army_id)
		var old_supply: int = _army_supply.get(army_id, 0)
		var new_supply: int = maxi(0, old_supply - consumption)
		_army_supply[army_id] = new_supply

		# Track zero-supply turns
		if new_supply <= 0:
			_army_zero_turns[army_id] = _army_zero_turns.get(army_id, 0) + 1
		else:
			_army_zero_turns[army_id] = 0

		var zero_turns: int = _army_zero_turns.get(army_id, 0)

		# Emit supply changed
		if new_supply != old_supply:
			EventBus.army_supply_changed.emit(army_id, new_supply)

		# Low supply warning
		if new_supply > 0 and new_supply <= consumption * 3:
			EventBus.army_supply_low.emit(army_id, float(new_supply))

		# Attrition effects
		if zero_turns >= DISBAND_ZERO_TURNS:
			# Morale collapse — auto-disband
			events.append({
				"type": "disband",
				"army_id": army_id,
				"reason": "morale_collapse",
			})
			if player_id == GameManager.get_human_player_id():
				var army_name: String = army.get("name", "军团")
				EventBus.message_log.emit(
					"[color=red]%s 断粮%d回合, 军心崩溃, 部队溃散![/color]" % [army_name, zero_turns])
			EventBus.army_disbanded.emit(player_id, army_id)

		elif zero_turns >= STARVING_ZERO_TURNS:
			# Attrition — lose 5% troops per turn
			var troops: Array = army.get("troops", [])
			var total_lost: int = 0
			for troop in troops:
				var soldiers: int = troop.get("soldiers", 0)
				if soldiers > 0:
					var loss: int = maxi(1, int(float(soldiers) * STARVING_ATTRITION_PCT))
					troop["soldiers"] = maxi(0, soldiers - loss)
					total_lost += loss
			if total_lost > 0:
				events.append({"type": "attrition", "army_id": army_id, "losses": total_lost})
				EventBus.army_attrition.emit(army_id, {"starvation": total_lost})
				if player_id == GameManager.get_human_player_id():
					EventBus.message_log.emit(
						"[color=red]%s 饥饿减员! 损失 %d 名士兵[/color]" % [
							army.get("name", "军团"), total_lost])

		elif new_supply <= 0 and zero_turns >= 1:
			# Foraging state — emit warning
			if player_id == GameManager.get_human_player_id():
				EventBus.message_log.emit(
					"[color=yellow]%s 补给耗尽, 进入搜粮状态 (战斗力-10%%)[/color]" % army.get("name", "军团"))

	return events


func get_army_supply_status(army_id: int) -> Dictionary:
	## Returns detailed supply status for an army.
	var supply: int = _army_supply.get(army_id, 0)
	var consumption: int = get_army_consumption(army_id)
	var zero_turns: int = _army_zero_turns.get(army_id, 0)
	var turns_remaining: int = 0
	if consumption > 0:
		turns_remaining = supply / consumption

	var status: String = "supplied"
	if zero_turns >= DISBAND_ZERO_TURNS:
		status = "critical"
	elif zero_turns >= STARVING_ZERO_TURNS:
		status = "starving"
	elif supply <= 0:
		status = "foraging"
	elif turns_remaining <= 2:
		status = "foraging"

	var status_label: String
	match status:
		"supplied":
			status_label = "[color=green]补给充足[/color]"
		"foraging":
			status_label = "[color=yellow]搜粮中[/color]"
		"starving":
			status_label = "[color=orange]饥饿减员[/color]"
		"critical":
			status_label = "[color=red]军心崩溃[/color]"
		_:
			status_label = "[color=white]未知[/color]"

	return {
		"supply": supply,
		"consumption": consumption,
		"turns_remaining": turns_remaining,
		"status": status,
		"status_label": status_label,
		"zero_turns": zero_turns,
		"efficiency": get_supply_efficiency(army_id),
	}


func get_supply_combat_modifiers(army_id: int) -> Dictionary:
	## Returns ATK/DEF modifiers based on supply status. For CombatResolver integration.
	var status: Dictionary = get_army_supply_status(army_id)
	var mods: Dictionary = {"atk_mod": 0.0, "def_mod": 0.0}
	match status["status"]:
		"foraging":
			mods["atk_mod"] = FORAGING_ATK_PENALTY
			mods["def_mod"] = FORAGING_DEF_PENALTY
		"starving":
			mods["atk_mod"] = -0.20
			mods["def_mod"] = -0.20
		"critical":
			mods["atk_mod"] = -0.40
			mods["def_mod"] = -0.40
	return mods

# ═══════════════════════════════════════════════════════════════════════════════
# 5. SUPPLY EVENTS
# ═══════════════════════════════════════════════════════════════════════════════

## Active supply events: Array of {event_id, type, affected_depots, multiplier, turns_left}
var _active_events: Array = []
var _next_event_id: int = 1

const EVENT_ABUNDANCE_MULT: float = 1.50       # +50% depot production
const EVENT_ABUNDANCE_TURNS: int = 3
const EVENT_PLAGUE_MULT: float = 0.70           # -30% food/production
const EVENT_PLAGUE_TURNS: int = 3
const EVENT_TRADE_ROUTE_MULT: float = 1.20      # permanent +20%
const EVENT_RAID_LOSS_PCT: float = 0.30          # lose 30% depot supplies

## Chance per player per turn for a random supply event
const SUPPLY_EVENT_CHANCE: float = 0.12


func _check_supply_events(player_id: int) -> void:
	## Roll for random supply events each turn.
	# Tick down existing events
	var expired: Array = []
	for evt in _active_events:
		if evt.get("permanent", false):
			continue
		evt["turns_left"] -= 1
		if evt["turns_left"] <= 0:
			expired.append(evt)
	for evt in expired:
		_active_events.erase(evt)
		if player_id == GameManager.get_human_player_id():
			EventBus.message_log.emit("[color=gray]补给事件 '%s' 已结束[/color]" % evt.get("name", ""))

	# Random event roll
	if randf() >= SUPPLY_EVENT_CHANCE:
		return

	var player_depots: Array = get_player_depots(player_id)
	if player_depots.is_empty():
		return

	var roll: float = randf()
	if roll < 0.30:
		_trigger_abundance(player_id, player_depots)
	elif roll < 0.55:
		_trigger_plague(player_id, player_depots)
	elif roll < 0.75:
		_trigger_trade_route(player_id, player_depots)
	else:
		_trigger_raiding(player_id, player_depots)


func _trigger_abundance(player_id: int, depots: Array) -> void:
	## 丰收 — +50% depot production for 3 turns
	var affected: Array = []
	for d in depots:
		affected.append(d["tile_idx"])
	var evt: Dictionary = {
		"event_id": _next_event_id,
		"type": "abundance",
		"name": "丰收",
		"owner_id": player_id,
		"affected_depots": affected,
		"multiplier": EVENT_ABUNDANCE_MULT,
		"turns_left": EVENT_ABUNDANCE_TURNS,
		"permanent": false,
	}
	_next_event_id += 1
	_active_events.append(evt)
	if player_id == GameManager.get_human_player_id():
		EventBus.message_log.emit("[color=green]丰收! 所有据点补给产量+50%% (%d回合)[/color]" % EVENT_ABUNDANCE_TURNS)
	EventBus.event_triggered.emit(player_id, "supply_abundance", "丰收: 补给产量大幅提升")


func _trigger_plague(player_id: int, depots: Array) -> void:
	## 蝗灾 — -30% production for 3 turns
	var affected: Array = []
	for d in depots:
		affected.append(d["tile_idx"])
	var evt: Dictionary = {
		"event_id": _next_event_id,
		"type": "plague",
		"name": "蝗灾",
		"owner_id": player_id,
		"affected_depots": affected,
		"multiplier": EVENT_PLAGUE_MULT,
		"turns_left": EVENT_PLAGUE_TURNS,
		"permanent": false,
	}
	_next_event_id += 1
	_active_events.append(evt)
	if player_id == GameManager.get_human_player_id():
		EventBus.message_log.emit("[color=red]蝗灾! 所有据点补给产量-30%% (%d回合)[/color]" % EVENT_PLAGUE_TURNS)
	EventBus.event_triggered.emit(player_id, "supply_plague", "蝗灾: 粮食产量锐减")


func _trigger_trade_route(player_id: int, depots: Array) -> void:
	## 商路开通 — permanent +20% to connected depots
	var connected_depots: Array = []
	for d in depots:
		if d.get("connected_to", []).size() > 0:
			connected_depots.append(d["tile_idx"])
	if connected_depots.is_empty():
		return
	var evt: Dictionary = {
		"event_id": _next_event_id,
		"type": "trade_route",
		"name": "商路开通",
		"owner_id": player_id,
		"affected_depots": connected_depots,
		"multiplier": EVENT_TRADE_ROUTE_MULT,
		"turns_left": 999,
		"permanent": true,
	}
	_next_event_id += 1
	_active_events.append(evt)
	if player_id == GameManager.get_human_player_id():
		EventBus.message_log.emit("[color=green]商路开通! 连通据点补给永久+20%%[/color]")
	EventBus.event_triggered.emit(player_id, "supply_trade_route", "商路开通: 连通据点补给增加")


func _trigger_raiding(player_id: int, depots: Array) -> void:
	## 劫掠 — enemy raids reduce a random depot's supplies
	var target_depot: Dictionary = depots[randi() % depots.size()]
	var tidx: int = target_depot["tile_idx"]
	if _depots.has(tidx):
		var loss: int = int(float(_depots[tidx]["current_supply"]) * EVENT_RAID_LOSS_PCT)
		_depots[tidx]["current_supply"] = maxi(0, _depots[tidx]["current_supply"] - loss)
		if player_id == GameManager.get_human_player_id():
			EventBus.message_log.emit("[color=red]劫掠! 据点补给被敌军掠夺, 损失 %d 补给[/color]" % loss)
		EventBus.event_triggered.emit(player_id, "supply_raiding", "劫掠: 据点补给遭袭")


func _get_depot_production_multiplier(depot_tile: int) -> float:
	## Aggregate all active event multipliers for a specific depot.
	var mult: float = 1.0
	for evt in _active_events:
		if depot_tile in evt.get("affected_depots", []):
			mult *= evt["multiplier"]
	return mult


func get_active_supply_events(player_id: int) -> Array:
	var result: Array = []
	for evt in _active_events:
		if evt.get("owner_id", -1) == player_id:
			result.append(evt)
	return result

# ═══════════════════════════════════════════════════════════════════════════════
# 6. FACTION SUPPLY BONUSES
# ═══════════════════════════════════════════════════════════════════════════════

## Faction consumption multipliers
const ORC_CONSUMPTION_MULT: float = 0.70          # Orc war bands live off the land
const PIRATE_CONSUMPTION_MULT: float = 1.0         # Standard
const DARK_ELF_CONSUMPTION_MULT: float = 1.0       # Standard

## Dark Elf shadow resupply cooldown tracking: player_id -> last turn used
var _shadow_resupply_cooldown: Dictionary = {}
const SHADOW_RESUPPLY_COOLDOWN: int = 5
const SHADOW_RESUPPLY_AMOUNT: int = 30


func get_faction_consumption_multiplier(player_id: int) -> float:
	## Returns supply consumption multiplier based on faction.
	var faction_id: int = _get_faction_id(player_id)
	match faction_id:
		FactionData.FactionID.ORC:
			return ORC_CONSUMPTION_MULT
		FactionData.FactionID.PIRATE:
			return PIRATE_CONSUMPTION_MULT
		FactionData.FactionID.DARK_ELF:
			return DARK_ELF_CONSUMPTION_MULT
	return 1.0


func can_use_shadow_resupply(player_id: int, current_turn: int) -> bool:
	## Dark Elf: check if shadow network emergency resupply is available.
	var faction_id: int = _get_faction_id(player_id)
	if faction_id != FactionData.FactionID.DARK_ELF:
		return false
	var last_used: int = _shadow_resupply_cooldown.get(player_id, -999)
	return (current_turn - last_used) >= SHADOW_RESUPPLY_COOLDOWN


func use_shadow_resupply(player_id: int, army_id: int, current_turn: int) -> bool:
	## Dark Elf: activate shadow network emergency resupply for one army.
	if not can_use_shadow_resupply(player_id, current_turn):
		return false
	if not _army_supply.has(army_id):
		return false
	_army_supply[army_id] += SHADOW_RESUPPLY_AMOUNT
	_shadow_resupply_cooldown[player_id] = current_turn
	_army_zero_turns[army_id] = 0

	if player_id == GameManager.get_human_player_id():
		EventBus.message_log.emit(
			"[color=purple]暗影补给网络启动! 紧急补给 %d 点[/color]" % SHADOW_RESUPPLY_AMOUNT)
	return true


func _apply_pirate_coastal_resupply(player_id: int) -> void:
	## Pirate: armies on coastal/harbor tiles get free resupply (no depot needed).
	var faction_id: int = _get_faction_id(player_id)
	if faction_id != FactionData.FactionID.PIRATE:
		return
	if not GameManager.has_method("get_player_armies"):
		return
	var armies: Array = GameManager.get_player_armies(player_id)
	for army in armies:
		var army_id: int = army.get("id", -1)
		if army_id < 0:
			continue
		var tile_idx: int = army.get("tile_index", -1)
		if _is_coastal_tile(tile_idx):
			var consumption: int = get_army_consumption(army_id)
			if not _army_supply.has(army_id):
				register_army_supply(army_id)
			_army_supply[army_id] += consumption  # free resupply covers consumption


func _get_faction_id(player_id: int) -> int:
	## Look up faction ID for a player.
	if GameManager.has_method("get_player_faction"):
		return GameManager.get_player_faction(player_id)
	for p in GameManager.players:
		if p.get("id", -1) == player_id:
			return p.get("faction_id", -1)
	return -1

# ═══════════════════════════════════════════════════════════════════════════════
# 7. INTEGRATION & TURN PROCESSING
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Listen for tile ownership changes to rebuild depot network
	if not EventBus.tile_captured.is_connected(_on_tile_captured):
		EventBus.tile_captured.connect(_on_tile_captured)
	if not EventBus.tile_lost.is_connected(_on_tile_lost):
		EventBus.tile_lost.connect(_on_tile_lost)
	if not EventBus.army_created.is_connected(_on_army_created):
		EventBus.army_created.connect(_on_army_created)
	if not EventBus.army_disbanded.is_connected(_on_army_disbanded):
		EventBus.army_disbanded.connect(_on_army_disbanded)


func process_turn(player_id: int) -> Array:
	## Main per-turn entry point. Processes all supply logistics for one player.
	## Returns array of event dicts (attrition, disbands, convoy deliveries, etc.).
	var events: Array = []

	# 1. Rebuild depot network (tile ownership may have changed)
	rebuild_depot_network(player_id)

	# 2. Replenish depots
	replenish_depots(player_id)

	# 3. Apply faction-specific bonuses
	_apply_pirate_coastal_resupply(player_id)

	# 4. Process convoy movement
	_process_convoy_movement()

	# 5. Process army supply consumption and attrition
	var supply_events: Array = _process_army_supply(player_id)
	events.append_array(supply_events)

	# 6. Check for random supply events
	_check_supply_events(player_id)

	# 7. Detect and emit supply line cut/restored signals
	_check_supply_line_changes(player_id)

	return events


## Tracking previous supply-line status for change detection
var _prev_route_status: Dictionary = {}  # army_id -> bool (was connected)


func _check_supply_line_changes(player_id: int) -> void:
	## Detect supply line cuts and restorations, emit signals.
	if not GameManager.has_method("get_player_armies"):
		return
	var armies: Array = GameManager.get_player_armies(player_id)
	var newly_cut: Array = []
	var newly_restored: Array = []

	for army in armies:
		var army_id: int = army.get("id", -1)
		if army_id < 0:
			continue
		var route: Dictionary = calculate_supply_route(army_id)
		var is_connected: bool = route["efficiency"] > 0.0
		var was_connected: bool = _prev_route_status.get(army_id, true)

		if was_connected and not is_connected:
			newly_cut.append(army.get("tile_index", -1))
		elif not was_connected and is_connected:
			newly_restored.append(army.get("tile_index", -1))

		_prev_route_status[army_id] = is_connected

	if not newly_cut.is_empty():
		EventBus.supply_line_cut.emit(player_id, newly_cut)
	if not newly_restored.is_empty():
		EventBus.supply_line_restored.emit(player_id, newly_restored)


func _on_tile_captured(player_id: int, _tile_index: int) -> void:
	rebuild_depot_network(player_id)


func _on_tile_lost(player_id: int, _tile_index: int) -> void:
	rebuild_depot_network(player_id)
	# Check if any depots were lost
	var to_erase: Array = []
	for tidx in _depots:
		if tidx < 0 or tidx >= GameManager.tiles.size():
			continue
		var tile: Dictionary = GameManager.tiles[tidx]
		if tile == null or tile.get("owner_id", -1) != _depots[tidx]["owner_id"]:
			to_erase.append(tidx)
	for tidx in to_erase:
		_depots.erase(tidx)


func _on_army_created(_player_id: int, army_id: int, _tile_index: int) -> void:
	register_army_supply(army_id)


func _on_army_disbanded(_player_id: int, army_id: int) -> void:
	unregister_army_supply(army_id)
	_prev_route_status.erase(army_id)

# ═══════════════════════════════════════════════════════════════════════════════
# 8. SAVE / LOAD
# ═══════════════════════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	# Serialize convoy path arrays as plain arrays for JSON compat
	var convoy_data: Array = []
	for c in _convoys:
		var cd: Dictionary = c.duplicate()
		cd["path"] = Array(cd["path"])
		convoy_data.append(cd)

	var event_data: Array = []
	for evt in _active_events:
		var ed: Dictionary = evt.duplicate()
		ed["affected_depots"] = Array(ed.get("affected_depots", []))
		event_data.append(ed)

	return {
		"depots": _depots.duplicate(true),
		"convoys": convoy_data,
		"next_convoy_id": _next_convoy_id,
		"army_supply": _army_supply.duplicate(),
		"army_zero_turns": _army_zero_turns.duplicate(),
		"active_events": event_data,
		"next_event_id": _next_event_id,
		"shadow_resupply_cooldown": _shadow_resupply_cooldown.duplicate(),
		"prev_route_status": _prev_route_status.duplicate(),
	}


func from_save_data(data: Dictionary) -> void:
	# Depots
	_depots.clear()
	var depots_raw: Dictionary = data.get("depots", {})
	for k in depots_raw:
		var tidx: int = int(k)
		var d: Dictionary = depots_raw[k]
		d["tile_idx"] = int(d.get("tile_idx", tidx))
		d["owner_id"] = int(d.get("owner_id", -1))
		d["capacity"] = int(d.get("capacity", STANDARD_CAPACITY))
		d["current_supply"] = int(d.get("current_supply", 0))
		d["production"] = int(d.get("production", STANDARD_PRODUCTION))
		var conn: Array = []
		for c in d.get("connected_to", []):
			conn.append(int(c))
		d["connected_to"] = conn
		_depots[tidx] = d

	# Convoys
	_convoys.clear()
	for c in data.get("convoys", []):
		var cd: Dictionary = c if c is Dictionary else {}
		cd["id"] = int(cd.get("id", 0))
		cd["from_depot"] = int(cd.get("from_depot", -1))
		cd["to_army"] = int(cd.get("to_army", -1))
		cd["supplies"] = int(cd.get("supplies", 0))
		cd["current_tile"] = int(cd.get("current_tile", -1))
		cd["path_step"] = int(cd.get("path_step", 0))
		cd["hp"] = int(cd.get("hp", CONVOY_BASE_HP))
		cd["escort_strength"] = int(cd.get("escort_strength", CONVOY_BASE_ESCORT))
		cd["owner_id"] = int(cd.get("owner_id", -1))
		var int_path: Array = []
		for p in cd.get("path", []):
			int_path.append(int(p))
		cd["path"] = int_path
		_convoys.append(cd)

	_next_convoy_id = int(data.get("next_convoy_id", 1))

	# Army supply
	_army_supply.clear()
	for k in data.get("army_supply", {}):
		_army_supply[int(k)] = int(data["army_supply"][k])

	_army_zero_turns.clear()
	for k in data.get("army_zero_turns", {}):
		_army_zero_turns[int(k)] = int(data["army_zero_turns"][k])

	# Events
	_active_events.clear()
	for evt in data.get("active_events", []):
		if evt is Dictionary:
			evt["event_id"] = int(evt.get("event_id", 0))
			evt["turns_left"] = int(evt.get("turns_left", 0))
			evt["multiplier"] = float(evt.get("multiplier", 1.0))
			evt["owner_id"] = int(evt.get("owner_id", -1))
			evt["permanent"] = bool(evt.get("permanent", false))
			var ad: Array = []
			for d in evt.get("affected_depots", []):
				ad.append(int(d))
			evt["affected_depots"] = ad
			_active_events.append(evt)

	_next_event_id = int(data.get("next_event_id", 1))

	# Shadow resupply cooldown
	_shadow_resupply_cooldown.clear()
	for k in data.get("shadow_resupply_cooldown", {}):
		_shadow_resupply_cooldown[int(k)] = int(data["shadow_resupply_cooldown"][k])

	# Previous route status
	_prev_route_status.clear()
	for k in data.get("prev_route_status", {}):
		_prev_route_status[int(k)] = bool(data["prev_route_status"][k])


func reset() -> void:
	_depots.clear()
	_convoys.clear()
	_next_convoy_id = 1
	_army_supply.clear()
	_army_zero_turns.clear()
	_active_events.clear()
	_next_event_id = 1
	_shadow_resupply_cooldown.clear()
	_prev_route_status.clear()
