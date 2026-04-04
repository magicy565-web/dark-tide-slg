## supply_system.gd - Supply Line & Front Line / Rear Classification system
## Autoload singleton: SupplySystem
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Supply status: "{player_id}_{tile_id}" -> bool (true = connected) ──
var _supply_status: Dictionary = {}

# ── Player capitals: player_id -> tile_index ──
var _player_capitals: Dictionary = {}

# ── Territory classification: "{player_id}_{tile_id}" -> "front"/"middle"/"rear" ──
var _tile_class: Dictionary = {}

# ── Isolation penalty constants ──
const ISOLATION_PROD_PENALTY: float = 0.5      # -50% gold/food/iron
const ISOLATION_GARRISON_LOSS: float = 0.05     # 5% garrison attrition per turn
const ISOLATION_ORDER_LOSS: float = 3.0         # -3 public_order per turn

# ── Classification bonus constants ──
const FRONT_DEF_BONUS: float = 0.2              # +20% garrison DEF
const FRONT_ATK_BONUS: float = 0.1              # +10% ATK for stationed armies
const REAR_PROD_BONUS: float = 0.3              # +30% production
const REAR_ORDER_RECOVERY: float = 5.0          # +5 public_order per turn
const CAPITAL_PROD_BONUS: float = 0.5           # +50% production
const CAPITAL_DEF_BONUS: float = 0.3            # +30% garrison DEF

# ── Previous supply state for change detection ──
var _prev_connected: Dictionary = {}  # player_id -> Array of connected tile indices


func _ready() -> void:
	# Connect to tile_captured to recalculate supply lines for all players
	if not EventBus.tile_captured.is_connected(_on_tile_captured):
		EventBus.tile_captured.connect(_on_tile_captured)
	if not EventBus.tile_lost.is_connected(_on_tile_lost):
		EventBus.tile_lost.connect(_on_tile_lost)


# ═══════════════ CAPITAL DETECTION ═══════════════

func detect_capital(player_id: int) -> int:
	## Find the capital tile for a player.
	## Priority order:
	##   1. Player's original starting position (home base)
	##   2. DARK_BASE tile matching player's original_faction
	##   3. First CORE_FORTRESS still owned
	##   4. First LIGHT_STRONGHOLD still owned
	##   5. Tile with highest garrison (last resort)

	# 1. Check player's starting position — the most reliable capital indicator
	var player: Dictionary = _get_player_dict(player_id)
	var start_pos: int = player.get("position", -1)
	if start_pos >= 0 and start_pos < GameManager.tiles.size():
		var start_tile: Dictionary = GameManager.tiles[start_pos]
		if start_tile != null and start_tile.get("owner_id", -1) == player_id:
			_player_capitals[player_id] = start_pos
			return start_pos

	# 2. For dark factions, find a DARK_BASE matching their original_faction
	var faction_id: int = GameManager.get_player_faction(player_id) if GameManager.has_method("get_player_faction") else -1
	var home_base: int = -1
	var first_fortress: int = -1
	var first_stronghold: int = -1
	var best_garrison_tile: int = -1
	var best_garrison: int = -1

	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) != player_id:
			continue
		var tidx: int = tile["index"]
		var tile_type: int = tile.get("type", -1)

		# 2. DARK_BASE with matching original_faction
		if tile_type == GameManager.TileType.DARK_BASE and faction_id >= 0:
			if tile.get("original_faction", -1) == faction_id and home_base < 0:
				home_base = tidx

		# 3. CORE_FORTRESS
		if tile_type == GameManager.TileType.CORE_FORTRESS and first_fortress < 0:
			first_fortress = tidx

		# 4. LIGHT_STRONGHOLD
		if tile_type == GameManager.TileType.LIGHT_STRONGHOLD and first_stronghold < 0:
			first_stronghold = tidx

		# 5. Highest garrison fallback
		var gar: int = tile.get("garrison", 0)
		if gar > best_garrison:
			best_garrison = gar
			best_garrison_tile = tidx

	# Pick best available in priority order
	var result: int = -1
	if home_base >= 0:
		result = home_base
	elif first_fortress >= 0:
		result = first_fortress
	elif first_stronghold >= 0:
		result = first_stronghold
	elif best_garrison_tile >= 0:
		result = best_garrison_tile

	if result >= 0:
		_player_capitals[player_id] = result
	return result


func _get_player_dict(player_id: int) -> Dictionary:
	## Look up a player dict from GameManager.players by id.
	for p in GameManager.players:
		if p.get("id", -1) == player_id:
			return p
	return {}


func get_capital(player_id: int) -> int:
	if _player_capitals.has(player_id):
		var cap: int = _player_capitals[player_id]
		# Validate capital is still owned
		if cap >= 0 and cap < GameManager.tiles.size():
			if GameManager.tiles[cap].get("owner_id", -1) == player_id:
				return cap
	# Recalculate
	return detect_capital(player_id)


# ═══════════════ SUPPLY LINE CALCULATION ═══════════════

func recalculate_supply_lines(player_id: int) -> void:
	## BFS from capital through same-owner tiles. Mark connected vs isolated.
	var capital: int = get_capital(player_id)

	# Store previous connected set for change detection
	var prev_connected_set: Array = []
	for key in _supply_status:
		if key.begins_with(str(player_id) + "_") and _supply_status[key] == true:
			var parts: PackedStringArray = key.split("_")
			if parts.size() >= 2:
				prev_connected_set.append(int(parts[1]))
	_prev_connected[player_id] = prev_connected_set

	# Clear existing supply status for this player
	var keys_to_remove: Array = []
	for key in _supply_status:
		if key.begins_with(str(player_id) + "_"):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_supply_status.erase(key)

	# Get all owned tiles
	var owned_tiles: Array = []
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) == player_id:
			owned_tiles.append(tile["index"])

	# If no capital, all tiles are isolated
	if capital < 0:
		for tidx in owned_tiles:
			_supply_status["%d_%d" % [player_id, tidx]] = false
		_emit_supply_signals(player_id, prev_connected_set, [])
		return

	# BFS from capital
	var connected: Dictionary = {}
	var queue: Array = [capital]
	connected[capital] = true
	while not queue.is_empty():
		var current: int = queue.pop_front()
		var neighbors: Array = GameManager.adjacency.get(current, [])
		for nb in neighbors:
			if connected.has(nb):
				continue
			if nb < 0 or nb >= GameManager.tiles.size():
				continue
			if GameManager.tiles[nb] == null:
				continue
			if GameManager.tiles[nb].get("owner_id", -1) != player_id:
				continue
			connected[nb] = true
			queue.append(nb)

	# Mark all owned tiles
	var new_connected_set: Array = []
	for tidx in owned_tiles:
		var is_connected: bool = connected.has(tidx)
		_supply_status["%d_%d" % [player_id, tidx]] = is_connected
		if is_connected:
			new_connected_set.append(tidx)

	_emit_supply_signals(player_id, prev_connected_set, new_connected_set)


func _emit_supply_signals(player_id: int, old_connected: Array, new_connected: Array) -> void:
	## Emit supply_line_cut / supply_line_restored signals based on changes.
	var old_set: Dictionary = {}
	for t in old_connected:
		old_set[t] = true
	var new_set: Dictionary = {}
	for t in new_connected:
		new_set[t] = true

	var newly_isolated: Array = []
	for t in old_connected:
		if not new_set.has(t):
			newly_isolated.append(t)
	var newly_restored: Array = []
	for t in new_connected:
		if not old_set.has(t):
			newly_restored.append(t)

	if not newly_isolated.is_empty():
		EventBus.supply_line_cut.emit(player_id, newly_isolated)
		if player_id == GameManager.get_human_player_id():
			EventBus.message_log.emit("[color=red]补给线被切断! %d个据点失去补给[/color]" % newly_isolated.size())
	if not newly_restored.is_empty():
		EventBus.supply_line_restored.emit(player_id, newly_restored)
		if player_id == GameManager.get_human_player_id():
			EventBus.message_log.emit("[color=green]补给线恢复! %d个据点重新连通[/color]" % newly_restored.size())


func is_tile_supplied(player_id: int, tile_index: int) -> bool:
	var key: String = "%d_%d" % [player_id, tile_index]
	return _supply_status.get(key, true)


func get_isolated_tiles(player_id: int) -> Array:
	var result: Array = []
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) != player_id:
			continue
		if not is_tile_supplied(player_id, tile["index"]):
			result.append(tile["index"])
	return result


func get_supply_path(player_id: int, tile_index: int) -> Array:
	## BFS shortest path from tile_index back to capital through owned tiles.
	## Returns empty array if isolated.
	var capital: int = get_capital(player_id)
	if capital < 0 or tile_index == capital:
		return [tile_index] if tile_index == capital else []
	if not is_tile_supplied(player_id, tile_index):
		return []

	# BFS from tile_index to capital
	var parent: Dictionary = {}
	parent[tile_index] = -1
	var queue: Array = [tile_index]
	var found: bool = false
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == capital:
			found = true
			break
		var neighbors: Array = GameManager.adjacency.get(current, [])
		for nb in neighbors:
			if parent.has(nb):
				continue
			if nb < 0 or nb >= GameManager.tiles.size():
				continue
			if GameManager.tiles[nb] == null:
				continue
			if GameManager.tiles[nb].get("owner_id", -1) != player_id:
				continue
			parent[nb] = current
			queue.append(nb)

	if not found:
		return []

	# Reconstruct path
	var path: Array = []
	var cur: int = capital
	while cur != -1:
		path.append(cur)
		cur = parent.get(cur, -1)
	path.reverse()
	return path


# ═══════════════ ARMY SUPPLY CONNECTIVITY ═══════════════

func is_army_supplied(army: Dictionary) -> bool:
	## Check if an army has a supply line back to its capital.
	## An army is supplied if:
	##   1. It is on a friendly tile that is connected to the capital, OR
	##   2. It is on an enemy/neutral tile but adjacent to a connected friendly tile
	var player_id: int = army.get("player_id", -1)
	var tile_index: int = army.get("tile_index", -1)
	if player_id < 0 or tile_index < 0:
		return false
	if tile_index >= GameManager.tiles.size():
		return false

	var tile: Dictionary = GameManager.tiles[tile_index]
	if tile == null:
		return false

	# On own territory — use standard tile supply check
	if tile.get("owner_id", -1) == player_id:
		return is_tile_supplied(player_id, tile_index)

	# On enemy/neutral tile — check if adjacent to any connected friendly tile
	var neighbors: Array = GameManager.adjacency.get(tile_index, [])
	for nb in neighbors:
		if nb < 0 or nb >= GameManager.tiles.size():
			continue
		if GameManager.tiles[nb] == null:
			continue
		if GameManager.tiles[nb].get("owner_id", -1) == player_id:
			if is_tile_supplied(player_id, nb):
				return true
	return false


func get_army_supply_status(army: Dictionary) -> Dictionary:
	## Returns detailed supply status for an army.
	## Keys: "connected" (bool), "capital_tile" (int), "distance" (int),
	##        "status" (String: "supplied"/"strained"/"cut_off"),
	##        "status_label" (String: Chinese label for HUD)
	var player_id: int = army.get("player_id", -1)
	var tile_index: int = army.get("tile_index", -1)
	var capital: int = get_capital(player_id)
	var connected: bool = is_army_supplied(army)

	var result: Dictionary = {
		"connected": connected,
		"capital_tile": capital,
		"distance": -1,
		"status": "cut_off",
		"status_label": "[color=red]补给断绝[/color]",
	}

	if capital < 0:
		result["status"] = "no_capital"
		result["status_label"] = "[color=red]无首都![/color]"
		return result

	if not connected:
		return result

	# Calculate distance through supply path
	var tile_owner: int = -1
	if tile_index >= 0 and tile_index < GameManager.tiles.size() and GameManager.tiles[tile_index] != null:
		tile_owner = GameManager.tiles[tile_index].get("owner_id", -1)

	var path: Array = []
	if tile_owner == player_id:
		path = get_supply_path(player_id, tile_index)
	else:
		# On enemy tile — find path from nearest connected friendly tile
		var neighbors: Array = GameManager.adjacency.get(tile_index, [])
		var shortest: Array = []
		for nb in neighbors:
			if nb < 0 or nb >= GameManager.tiles.size():
				continue
			if GameManager.tiles[nb] == null:
				continue
			if GameManager.tiles[nb].get("owner_id", -1) != player_id:
				continue
			if not is_tile_supplied(player_id, nb):
				continue
			var p: Array = get_supply_path(player_id, nb)
			if not p.is_empty() and (shortest.is_empty() or p.size() < shortest.size()):
				shortest = p
		path = shortest

	var dist: int = path.size() if not path.is_empty() else 999
	result["distance"] = dist

	if dist <= 3:
		result["status"] = "supplied"
		result["status_label"] = "[color=green]补给充足[/color]"
	elif dist <= 6:
		result["status"] = "strained"
		result["status_label"] = "[color=yellow]补给紧张[/color]"
	else:
		result["status"] = "extended"
		result["status_label"] = "[color=orange]补给线过长[/color]"

	return result


func is_capital_tile(player_id: int, tile_index: int) -> bool:
	## Returns true if the given tile is the capital for the given player.
	return get_capital(player_id) == tile_index


# ═══════════════ ISOLATION PENALTIES ═══════════════

func apply_isolation_penalties(player_id: int) -> void:
	## Apply attrition and public order loss to isolated tiles.
	## Also apply morale drain and reinforcement block to armies cut off from capital.
	var isolated: Array = get_isolated_tiles(player_id)
	for tidx in isolated:
		if tidx < 0 or tidx >= GameManager.tiles.size():
			continue
		var tile: Dictionary = GameManager.tiles[tidx]
		if tile == null:
			continue
		# Garrison attrition: -5%
		var gar: int = tile.get("garrison", 0)
		if gar > 0:
			var loss: int = maxi(1, int(float(gar) * ISOLATION_GARRISON_LOSS))
			tile["garrison"] = maxi(0, gar - loss)
		# Public order loss: -3
		var order: float = tile.get("public_order", BalanceConfig.TILE_ORDER_DEFAULT)
		tile["public_order"] = maxf(0.0, order - ISOLATION_ORDER_LOSS)

	# Apply penalties to armies cut off from capital
	_apply_army_isolation_penalties(player_id)


const ARMY_CUTOFF_MORALE_DRAIN: float = 8.0      # -8 morale per turn when cut off
const ARMY_CUTOFF_ATTRITION_PCT: float = 0.03     # 3% soldier loss per turn when cut off

func _apply_army_isolation_penalties(player_id: int) -> void:
	## Armies cut off from capital suffer morale drain and attrition.
	if not GameManager.has_method("get_player_armies"):
		return
	var armies: Array = GameManager.get_player_armies(player_id)
	for army in armies:
		if not is_army_supplied(army):
			var army_id: int = army.get("id", -1)
			if army_id < 0:
				continue
			# Morale drain
			var morale: float = army.get("morale", 100.0)
			army["morale"] = maxf(0.0, morale - ARMY_CUTOFF_MORALE_DRAIN)
			# Soldier attrition on each troop
			var troops: Array = army.get("troops", [])
			for troop in troops:
				var soldiers: int = troop.get("soldiers", 0)
				if soldiers > 0:
					var loss: int = maxi(1, int(float(soldiers) * ARMY_CUTOFF_ATTRITION_PCT))
					troop["soldiers"] = maxi(0, soldiers - loss)
			# Emit army_supply_low signal (used by board.gd / action_visualizer for visual alerts)
			EventBus.army_supply_low.emit(army_id, 0.0)
			# Emit warning for human player
			if player_id == GameManager.get_human_player_id():
				var army_name: String = army.get("name", "Army")
				EventBus.message_log.emit("[color=red]⚠ %s 补给线断绝! 士气-%.0f, 减员中...[/color]" % [army_name, ARMY_CUTOFF_MORALE_DRAIN])
		else:
			# Strained supply (distance 4-6): emit partial supply warning
			var supply_status: Dictionary = get_army_supply_status(army)
			var status: String = supply_status.get("status", "supplied")
			if status == "strained" or status == "extended":
				# Emit supply_low with partial supply ratio (0.5 for strained, 0.25 for extended)
				var supply_ratio: float = 0.5 if status == "strained" else 0.25
				EventBus.army_supply_low.emit(army_id, supply_ratio)
				if player_id == GameManager.get_human_player_id():
					var army_name: String = army.get("name", "Army")
					EventBus.message_log.emit("[color=orange]⚠ %s %s[/color]" % [army_name, supply_status.get("status_label", "")])


func get_supply_production_mult(player_id: int, tile_index: int) -> float:
	## Returns production multiplier based on supply status.
	## 1.0 for supplied tiles, 0.5 for isolated tiles.
	if is_tile_supplied(player_id, tile_index):
		return 1.0
	return 1.0 - ISOLATION_PROD_PENALTY


func can_recruit_at_tile(player_id: int, tile_index: int) -> bool:
	## Returns false if tile is isolated (cannot recruit).
	return is_tile_supplied(player_id, tile_index)


func can_build_at_tile(player_id: int, tile_index: int) -> bool:
	## Returns false if tile is isolated (cannot build).
	return is_tile_supplied(player_id, tile_index)


# ═══════════════ FRONT LINE / REAR CLASSIFICATION ═══════════════

func classify_territories(player_id: int) -> void:
	## Classify all owned tiles as FRONT, MIDDLE, or REAR.
	# Clear existing classification for this player
	var keys_to_remove: Array = []
	for key in _tile_class:
		if key.begins_with(str(player_id) + "_"):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		_tile_class.erase(key)

	# Pass 1: Identify FRONT tiles (adjacent to enemy/neutral)
	var front_tiles: Dictionary = {}
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) != player_id:
			continue
		var tidx: int = tile["index"]
		var neighbors: Array = GameManager.adjacency.get(tidx, [])
		var is_front: bool = false
		for nb in neighbors:
			if nb < 0 or nb >= GameManager.tiles.size():
				continue
			if GameManager.tiles[nb] == null:
				continue
			if GameManager.tiles[nb].get("owner_id", -1) != player_id:
				is_front = true
				break
		if is_front:
			front_tiles[tidx] = true
			_tile_class["%d_%d" % [player_id, tidx]] = "front"

	# Pass 2: Identify MIDDLE tiles (adjacent to FRONT but not FRONT themselves)
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) != player_id:
			continue
		var tidx: int = tile["index"]
		if front_tiles.has(tidx):
			continue
		var neighbors: Array = GameManager.adjacency.get(tidx, [])
		var is_middle: bool = false
		for nb in neighbors:
			if front_tiles.has(nb):
				is_middle = true
				break
		if is_middle:
			_tile_class["%d_%d" % [player_id, tidx]] = "middle"
		else:
			_tile_class["%d_%d" % [player_id, tidx]] = "rear"

	EventBus.territory_classified.emit(player_id)


func get_tile_classification(player_id: int, tile_index: int) -> String:
	var key: String = "%d_%d" % [player_id, tile_index]
	return _tile_class.get(key, "middle")


func get_front_tiles(player_id: int) -> Array:
	var result: Array = []
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) != player_id:
			continue
		if get_tile_classification(player_id, tile["index"]) == "front":
			result.append(tile["index"])
	return result


func get_rear_tiles(player_id: int) -> Array:
	var result: Array = []
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) != player_id:
			continue
		if get_tile_classification(player_id, tile["index"]) == "rear":
			result.append(tile["index"])
	return result


# ═══════════════ CLASSIFICATION BONUSES ═══════════════

func get_classification_production_mult(player_id: int, tile_index: int) -> float:
	## Returns production multiplier based on tile classification.
	var capital: int = get_capital(player_id)
	if tile_index == capital:
		return 1.0 + CAPITAL_PROD_BONUS
	var cls: String = get_tile_classification(player_id, tile_index)
	if cls == "rear":
		return 1.0 + REAR_PROD_BONUS
	return 1.0


func get_classification_def_bonus(player_id: int, tile_index: int) -> float:
	## Returns DEF multiplier bonus from classification.
	var capital: int = get_capital(player_id)
	if tile_index == capital:
		return CAPITAL_DEF_BONUS
	var cls: String = get_tile_classification(player_id, tile_index)
	if cls == "front":
		return FRONT_DEF_BONUS
	return 0.0


func get_classification_atk_bonus(player_id: int, tile_index: int) -> float:
	## Returns ATK bonus multiplier from classification.
	var cls: String = get_tile_classification(player_id, tile_index)
	if cls == "front":
		return FRONT_ATK_BONUS
	return 0.0


func apply_rear_order_recovery(player_id: int) -> void:
	## Apply +5 public_order per turn to REAR tiles.
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) != player_id:
			continue
		var cls: String = get_tile_classification(player_id, tile["index"])
		if cls == "rear":
			var order: float = tile.get("public_order", BalanceConfig.TILE_ORDER_DEFAULT)
			tile["public_order"] = minf(order + REAR_ORDER_RECOVERY, 100.0)


# ═══════════════ COMBINED MODIFIERS ═══════════════

func get_tile_production_modifier(player_id: int, tile_index: int) -> float:
	## Combined production modifier from supply + classification.
	var supply_mult: float = get_supply_production_mult(player_id, tile_index)
	var class_mult: float = get_classification_production_mult(player_id, tile_index)
	return supply_mult * class_mult


# ═══════════════ EVENT HANDLERS ═══════════════

func _on_tile_captured(_player_id: int, _tile_index: int) -> void:
	## When any tile is captured, recalculate supply for all players.
	for p in GameManager.players:
		var pid: int = p["id"]
		recalculate_supply_lines(pid)
		classify_territories(pid)


func _on_tile_lost(_player_id: int, _tile_index: int) -> void:
	## When a tile is lost, recalculate supply for all players.
	for p in GameManager.players:
		var pid: int = p["id"]
		recalculate_supply_lines(pid)
		classify_territories(pid)


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"supply_status": _supply_status.duplicate(),
		"player_capitals": _player_capitals.duplicate(),
		"tile_class": _tile_class.duplicate(),
	}


func from_save_data(data: Dictionary) -> void:
	_supply_status = data.get("supply_status", {})
	_player_capitals = {}
	var caps: Dictionary = data.get("player_capitals", {})
	for k in caps:
		_player_capitals[int(k)] = int(caps[k])
	_tile_class = data.get("tile_class", {})


# ═══════════════ RESET ═══════════════

func reset() -> void:
	_supply_status.clear()
	_player_capitals.clear()
	_tile_class.clear()
	_prev_connected.clear()
