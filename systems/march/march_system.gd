## march_system.gd - Romance of the Three Kingdoms 13 style node-based marching system
## Autoload singleton. Manages multi-turn army movement across the node map.
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")

# ── March speed multipliers by terrain ──
const TERRAIN_SPEED_MULT: Dictionary = {
	FactionData.TerrainType.PLAINS: 1.0,
	FactionData.TerrainType.FOREST: 0.7,
	FactionData.TerrainType.MOUNTAIN: 0.5,
	FactionData.TerrainType.SWAMP: 0.6,
	FactionData.TerrainType.COASTAL: 1.0,
	FactionData.TerrainType.FORTRESS_WALL: 0.4,  # BUG FIX R7: walls should slow movement, not speed it up
	FactionData.TerrainType.RIVER: 0.8,
	FactionData.TerrainType.RUINS: 0.8,
	FactionData.TerrainType.WASTELAND: 1.0,
	FactionData.TerrainType.VOLCANIC: 0.5,
}

# ── Supply consumption rates ──
const SUPPLY_MAX: float = 100.0
const SUPPLY_FRIENDLY: float = 2.0
const SUPPLY_NEUTRAL: float = 3.0
const SUPPLY_ENEMY: float = 4.0
const SUPPLY_LOW_THRESHOLD: float = 30.0

# ── Interception constants ──
const INTERCEPT_BASE_CHANCE: float = 0.40
const INTERCEPT_SCOUT_BONUS: float = 0.10

# ── Fatigue constants ──
const FATIGUE_THRESHOLD: int = 5
const FATIGUE_SPEED_PENALTY: float = 0.1

# ── Attrition ──
const NO_SUPPLY_ATTRITION_PCT: float = 0.05

# ── March orders storage ──
# { army_id: int -> march order Dictionary }
var march_orders: Dictionary = {}


func reset() -> void:
	march_orders.clear()


# ══════════════════ PATHFINDING ══════════════════

func find_path(from_tile: int, to_tile: int) -> Array:
	## Dijkstra pathfinding on GameManager.adjacency using terrain_move_cost as weight.
	## Returns array of tile indices from from_tile to to_tile (inclusive), or empty if unreachable.
	if from_tile == to_tile:
		return [from_tile]
	var adjacency: Dictionary = GameManager.adjacency
	var tiles: Array = GameManager.tiles
	if not adjacency.has(from_tile):
		return []

	# Dijkstra
	var dist: Dictionary = {from_tile: 0.0}
	var prev: Dictionary = {}
	# Simple priority queue using sorted array of [cost, tile]
	var open: Array = [[0.0, from_tile]]

	while not open.is_empty():
		# Pop lowest cost
		var current_cost: float = open[0][0]
		var current: int = open[0][1]
		open.remove_at(0)

		if current == to_tile:
			break

		if current_cost > dist.get(current, INF):
			continue

		if not adjacency.has(current):
			continue

		for neighbor in adjacency[current]:
			if neighbor < 0 or neighbor >= tiles.size():
				continue
			var move_cost: float = float(tiles[neighbor].get("terrain_move_cost", 1))
			var new_dist: float = current_cost + move_cost
			if new_dist < dist.get(neighbor, INF):
				dist[neighbor] = new_dist
				prev[neighbor] = current
				# Insert sorted
				var inserted: bool = false
				for i in range(open.size()):
					if new_dist < open[i][0]:
						open.insert(i, [new_dist, neighbor])
						inserted = true
						break
				if not inserted:
					open.append([new_dist, neighbor])

	# Reconstruct path
	if not prev.has(to_tile) and from_tile != to_tile:
		return []
	var path: Array = []
	var node: int = to_tile
	while node != from_tile:
		path.push_front(node)
		if not prev.has(node):
			return []
		node = prev[node]
	path.push_front(from_tile)
	return path


func get_path_cost(path: Array) -> float:
	## Total movement cost of a path (sum of terrain_move_cost for all tiles except origin).
	var total: float = 0.0
	var tiles: Array = GameManager.tiles
	for i in range(1, path.size()):
		var tidx: int = path[i]
		if tidx >= 0 and tidx < tiles.size():
			total += float(tiles[tidx].get("terrain_move_cost", 1))
	return total


func get_estimated_turns(path: Array, army_id: int) -> int:
	## Estimate how many turns a march will take based on terrain speed modifiers.
	if path.size() <= 1:
		return 0
	var tiles: Array = GameManager.tiles
	var base_speed: float = _get_army_march_speed(army_id)
	var total_turns: float = 0.0
	for i in range(1, path.size()):
		var tidx: int = path[i]
		if tidx < 0 or tidx >= tiles.size():
			continue
		var terrain: int = tiles[tidx].get("terrain", FactionData.TerrainType.PLAINS)
		var speed_mult: float = TERRAIN_SPEED_MULT.get(terrain, 1.0)
		var effective_speed: float = maxf(base_speed * speed_mult, 0.1)
		total_turns += 1.0 / effective_speed
	return ceili(total_turns)


# ══════════════════ MARCH ORDERS ══════════════════

func issue_march_order(army_id: int, target_tile: int) -> Dictionary:
	## Create a march order for the army. Returns the order dict or empty on failure.
	if not GameManager.armies.has(army_id):
		return {}
	var army: Dictionary = GameManager.armies[army_id]
	var from_tile: int = army["tile_index"]

	if from_tile == target_tile:
		return {}

	var path: Array = find_path(from_tile, target_tile)
	if path.is_empty():
		EventBus.message_log.emit("[color=red]无法找到前往目标的路径![/color]")
		return {}

	# Cancel any existing march
	if march_orders.has(army_id):
		cancel_march_order(army_id)

	var order: Dictionary = {
		"army_id": army_id,
		"player_id": army["player_id"],
		"path": path,
		"current_step": 0,
		"progress": 0.0,
		"state": "marching",
		"speed": _get_army_march_speed(army_id),
		"turns_marching": 0,
		"supply": SUPPLY_MAX,
		"target_tile": target_tile,
	}
	march_orders[army_id] = order

	EventBus.army_march_started.emit(army_id, path)
	var est_turns: int = get_estimated_turns(path, army_id)
	var tile_name: String = GameManager.tiles[target_tile].get("name", "目标")
	EventBus.message_log.emit("[color=cyan]%s 开始行军前往 %s (预计%d回合)[/color]" % [
		army.get("name", "军团"), tile_name, est_turns])

	return order


func cancel_march_order(army_id: int) -> void:
	## Cancel march, army stays at current position.
	if not march_orders.has(army_id):
		return
	var order: Dictionary = march_orders[army_id]
	# Ensure army tile is at last reached step
	if GameManager.armies.has(army_id) and order["path"].size() > order["current_step"]:
		GameManager.armies[army_id]["tile_index"] = order["path"][order["current_step"]]
	march_orders.erase(army_id)
	EventBus.army_march_cancelled.emit(army_id)
	EventBus.message_log.emit("[color=yellow]行军已取消[/color]")


func modify_march_target(army_id: int, new_target: int) -> Dictionary:
	## Recalculate path from current position to new target.
	if not march_orders.has(army_id):
		return issue_march_order(army_id, new_target)
	var order: Dictionary = march_orders[army_id]
	var current_tile: int = order["path"][order["current_step"]]
	cancel_march_order(army_id)
	# Re-issue from current position
	if GameManager.armies.has(army_id):
		GameManager.armies[army_id]["tile_index"] = current_tile
	return issue_march_order(army_id, new_target)


func get_march_order(army_id: int) -> Dictionary:
	## Get current march order or empty dict.
	return march_orders.get(army_id, {})


func is_army_marching(army_id: int) -> bool:
	if not march_orders.has(army_id):
		return false
	return march_orders[army_id]["state"] == "marching"


func get_all_marching_armies(player_id: int = -1) -> Array:
	## All marching armies, optionally filtered by player.
	var result: Array = []
	for army_id in march_orders:
		var order: Dictionary = march_orders[army_id]
		if player_id >= 0 and order["player_id"] != player_id:
			continue
		result.append(order)
	return result


# ══════════════════ TURN PROCESSING ══════════════════

func process_marches(player_id: int) -> Array:
	## Advance all marching armies for this player. Returns array of event dicts.
	var events: Array = []
	var to_remove: Array = []
	var tiles: Array = GameManager.tiles

	for army_id in march_orders:
		var order: Dictionary = march_orders[army_id]
		if order["player_id"] != player_id:
			continue
		if order["state"] != "marching":
			continue
		if not GameManager.armies.has(army_id):
			to_remove.append(army_id)
			continue

		var army: Dictionary = GameManager.armies[army_id]
		order["turns_marching"] += 1

		# Calculate effective speed
		var effective_speed: float = _calculate_effective_speed(army_id, order)
		order["speed"] = effective_speed

		# Advance progress
		order["progress"] += effective_speed
		var step_events: Array = _process_step_advancement(army_id, order, army)
		events.append_array(step_events)

		# Supply consumption
		if order["state"] == "marching":
			_consume_supply(army_id, order, army)

		# Check attrition from no supply
		if order["supply"] <= 0.0:
			var attrition_event: Dictionary = _apply_attrition(army_id, order, army)
			if not attrition_event.is_empty():
				events.append(attrition_event)

	# Cleanup removed orders
	for aid in to_remove:
		march_orders.erase(aid)

	return events


func _process_step_advancement(army_id: int, order: Dictionary, army: Dictionary) -> Array:
	## Process movement when progress accumulates past 1.0. Returns events.
	var events: Array = []
	var tiles: Array = GameManager.tiles
	var path: Array = order["path"]

	while order["progress"] >= 1.0 and order["state"] == "marching":
		order["progress"] -= 1.0
		var next_step: int = order["current_step"] + 1

		if next_step >= path.size():
			# Arrived at destination
			order["state"] = "arrived"
			order["current_step"] = path.size() - 1
			var dest_tile: int = path[path.size() - 1]
			army["tile_index"] = dest_tile
			events.append({"type": "arrived", "army_id": army_id, "tile_index": dest_tile})
			EventBus.army_march_arrived.emit(army_id, dest_tile)
			EventBus.message_log.emit("[color=green]%s 已抵达目的地![/color]" % army.get("name", "军团"))
			break

		var next_tile_idx: int = path[next_step]
		if next_tile_idx < 0 or next_tile_idx >= tiles.size():
			order["state"] = "blocked"
			break

		var next_tile: Dictionary = tiles[next_tile_idx]
		var tile_owner: int = next_tile.get("owner_id", -1)

		# Check interception by enemy armies
		var intercept: Dictionary = check_interception(army_id, next_tile_idx)
		if intercept.get("intercepted", false):
			order["state"] = "intercepted"
			army["tile_index"] = path[order["current_step"]]
			events.append({
				"type": "intercepted",
				"army_id": army_id,
				"interceptor_army_id": intercept["interceptor_army_id"],
				"tile_index": next_tile_idx,
			})
			EventBus.army_march_intercepted.emit(army_id, intercept["interceptor_army_id"], next_tile_idx)
			EventBus.message_log.emit("[color=red]%s 被敌军拦截![/color]" % army.get("name", "军团"))
			break

		if tile_owner == army["player_id"]:
			# Friendly tile — move through
			order["current_step"] = next_step
			army["tile_index"] = next_tile_idx
			# Resupply if tile has building
			if next_tile.get("building_id", "") != "":
				order["supply"] = SUPPLY_MAX
			EventBus.army_march_step.emit(army_id, path[next_step - 1], next_tile_idx, order["progress"])
		elif tile_owner < 0:
			# Neutral tile — check garrison
			if next_tile.get("garrison", 0) > 0:
				order["state"] = "blocked"
				army["tile_index"] = path[order["current_step"]]
				events.append({"type": "battle", "army_id": army_id, "tile_index": next_tile_idx, "defender": "neutral"})
				EventBus.army_march_battle.emit(army_id, next_tile_idx)
				EventBus.message_log.emit("[color=orange]%s 遭遇中立守军阻拦![/color]" % army.get("name", "军团"))
			else:
				# Empty neutral tile, pass through
				order["current_step"] = next_step
				army["tile_index"] = next_tile_idx
				EventBus.army_march_step.emit(army_id, path[next_step - 1], next_tile_idx, order["progress"])
		else:
			# Enemy tile — battle
			order["state"] = "blocked"
			army["tile_index"] = path[order["current_step"]]
			events.append({"type": "battle", "army_id": army_id, "tile_index": next_tile_idx, "defender": "enemy"})
			EventBus.army_march_battle.emit(army_id, next_tile_idx)
			EventBus.message_log.emit("[color=red]%s 抵达敌方领地边界, 准备进攻![/color]" % army.get("name", "军团"))

	return events


# ══════════════════ INTERCEPTION SYSTEM ══════════════════

func check_interception(marching_army_id: int, tile_index: int) -> Dictionary:
	## Check if enemy army on tile can intercept. Returns {intercepted: bool, interceptor_army_id: int}
	if not GameManager.armies.has(marching_army_id):
		return {"intercepted": false, "interceptor_army_id": -1}

	var marching_army: Dictionary = GameManager.armies[marching_army_id]
	var marching_player: int = marching_army["player_id"]

	# Check for enemy armies at the tile
	for aid in GameManager.armies:
		var other_army: Dictionary = GameManager.armies[aid]
		if other_army["player_id"] == marching_player:
			continue
		if other_army["tile_index"] != tile_index:
			continue
		# BUG FIX: skip armies that are currently marching (in transit, not truly at tile)
		if march_orders.has(aid) and march_orders[aid].get("state", "") == "marching":
			continue
		# Enemy army found at tile — roll interception
		var chance: float = INTERCEPT_BASE_CHANCE
		# Scout hero bonus
		for hero_id in other_army.get("heroes", []):
			if HeroSystem != null and HeroSystem.has_method("has_equipment_passive"):
				if HeroSystem.has_equipment_passive(hero_id, "scout"):
					chance += INTERCEPT_SCOUT_BONUS
		chance = minf(chance, 0.95)
		var roll: float = randf()
		if roll < chance:
			return {"intercepted": true, "interceptor_army_id": aid}

	return {"intercepted": false, "interceptor_army_id": -1}


# ══════════════════ SPEED CALCULATION ══════════════════

func _get_army_march_speed(army_id: int) -> float:
	## Base march speed for an army, including hero bonuses.
	var base_speed: float = 1.0
	if not GameManager.armies.has(army_id):
		return base_speed
	var army: Dictionary = GameManager.armies[army_id]
	# Hero march_speed passive bonus
	for hero_id in army.get("heroes", []):
		if HeroSystem != null and HeroSystem.has_method("has_equipment_passive"):
			if HeroSystem.has_equipment_passive(hero_id, "march_speed"):
				base_speed += HeroSystem.get_equipment_passive_value(hero_id, "march_speed") * 0.2
	return base_speed


func _calculate_effective_speed(army_id: int, order: Dictionary) -> float:
	## Calculate speed after terrain, hero, and fatigue modifiers.
	var base_speed: float = _get_army_march_speed(army_id)
	var path: Array = order["path"]
	var next_step: int = mini(order["current_step"] + 1, path.size() - 1)
	var next_tile_idx: int = path[next_step]
	var tiles: Array = GameManager.tiles

	# Terrain speed modifier
	var terrain: int = FactionData.TerrainType.PLAINS
	if next_tile_idx >= 0 and next_tile_idx < tiles.size():
		terrain = tiles[next_tile_idx].get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_mult: float = TERRAIN_SPEED_MULT.get(terrain, 1.0)

	# Fatigue penalty
	var fatigue_penalty: float = 0.0
	if order["turns_marching"] > FATIGUE_THRESHOLD:
		fatigue_penalty = float(order["turns_marching"] - FATIGUE_THRESHOLD) * FATIGUE_SPEED_PENALTY

	var effective: float = base_speed * terrain_mult - fatigue_penalty
	return maxf(effective, 0.1)


# ══════════════════ SUPPLY SYSTEM ══════════════════

func _consume_supply(army_id: int, order: Dictionary, army: Dictionary) -> void:
	## Deduct supply based on territory ownership.
	var current_tile_idx: int = order["path"][order["current_step"]]
	var tiles: Array = GameManager.tiles
	if current_tile_idx < 0 or current_tile_idx >= tiles.size():
		return

	var tile: Dictionary = tiles[current_tile_idx]
	var tile_owner: int = tile.get("owner_id", -1)
	var consumption: float = SUPPLY_NEUTRAL

	if tile_owner == army["player_id"]:
		consumption = SUPPLY_FRIENDLY
	elif tile_owner >= 0:
		consumption = SUPPLY_ENEMY

	# Difficult terrain extra cost
	var terrain: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	if terrain in [FactionData.TerrainType.MOUNTAIN, FactionData.TerrainType.SWAMP, FactionData.TerrainType.VOLCANIC]:
		consumption += 1.0

	order["supply"] = maxf(order["supply"] - consumption, 0.0)

	if order["supply"] <= SUPPLY_LOW_THRESHOLD and order["supply"] > 0.0:
		EventBus.army_supply_low.emit(army_id, order["supply"])


func _apply_attrition(army_id: int, order: Dictionary, army: Dictionary) -> Dictionary:
	## Apply soldier losses when supply is depleted.
	var total_lost: int = 0
	for troop in army.get("troops", []):
		var soldiers: int = troop.get("soldiers", 0)
		if soldiers <= 0:
			continue
		var loss: int = int(float(soldiers) * NO_SUPPLY_ATTRITION_PCT)
		# For small squads, use probabilistic loss instead of guaranteed minimum 1
		if loss <= 0:
			loss = 1 if randf() < NO_SUPPLY_ATTRITION_PCT else 0
		troop["soldiers"] = maxi(0, soldiers - loss)
		total_lost += loss

	if total_lost > 0:
		EventBus.message_log.emit("[color=red]%s 补给耗尽! 损失 %d 名士兵[/color]" % [
			army.get("name", "军团"), total_lost])
		return {"type": "attrition", "army_id": army_id, "losses": total_lost}
	return {}


# ══════════════════ COMBAT MODIFIERS ══════════════════

func get_supply_combat_modifier(army_id: int) -> Dictionary:
	## Returns ATK/DEF modifiers based on supply level. Called by combat system.
	if not march_orders.has(army_id):
		return {"atk_mult": 1.0, "def_mult": 1.0}
	var order: Dictionary = march_orders[army_id]
	if order["supply"] <= 0.0:
		return {"atk_mult": 0.7, "def_mult": 0.7}  # -30%
	elif order["supply"] < SUPPLY_LOW_THRESHOLD:
		return {"atk_mult": 0.9, "def_mult": 0.9}  # -10%
	return {"atk_mult": 1.0, "def_mult": 1.0}


# ══════════════════ SAVE / LOAD ══════════════════

func to_save_data() -> Dictionary:
	## Serialize all march orders for save.
	var data: Dictionary = {}
	for army_id in march_orders:
		data[str(army_id)] = march_orders[army_id].duplicate(true)
	return data


func from_save_data(data: Dictionary) -> void:
	## Restore march orders from save data.
	march_orders.clear()
	for key in data:
		if not str(key).is_valid_int():
			continue
		var order: Dictionary = data[key]
		if order is Dictionary:
			# Ensure integer fields are properly typed after JSON round-trip
			var army_id: int = int(key)
			order["army_id"] = int(order.get("army_id", army_id))
			order["player_id"] = int(order.get("player_id", 0))
			order["current_step"] = int(order.get("current_step", 0))
			order["progress"] = float(order.get("progress", 0.0))
			order["speed"] = float(order.get("speed", 1.0))
			order["turns_marching"] = int(order.get("turns_marching", 0))
			order["supply"] = float(order.get("supply", SUPPLY_MAX))
			order["target_tile"] = int(order.get("target_tile", -1))
			# Ensure path elements are ints
			var int_path: Array = []
			for p in order.get("path", []):
				int_path.append(int(p))
			order["path"] = int_path
			march_orders[army_id] = order
