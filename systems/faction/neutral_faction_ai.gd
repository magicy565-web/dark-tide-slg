## neutral_faction_ai.gd - Neutral faction territory AI & vassal system (v2.1)
## Manages neutral faction territories, patrol/defense behavior, and vassal mechanics.
## Each neutral faction owns a base + surrounding territory nodes.
## After recruitment via quest chain, they become vassals (production → player, independent garrison).
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── State ──
# { neutral_faction_id: { "base_tile": int, "territory": [tile_idx, ...],
#   "initial_garrisons": {tile_idx: int}, "vassal_of": int (-1 = independent) } }
var _faction_state: Dictionary = {}

# ── Patrol state ──
# { neutral_faction_id: { "patrol_target": int, "patrol_cooldown": int } }
var _patrol_state: Dictionary = {}


func _ready() -> void:
	pass


func reset() -> void:
	_faction_state.clear()
	_patrol_state.clear()


# ═══════════════ INITIALIZATION ═══════════════

func init_neutral_territories() -> void:
	## Called after map generation to identify and register neutral territories.
	## Each NEUTRAL_BASE tile and its adjacent nodes form a neutral faction's territory.
	_faction_state.clear()
	_patrol_state.clear()

	# Phase 1: Find all neutral base tiles
	var bases: Dictionary = {}  # neutral_faction_id -> tile_index
	for tile in GameManager.tiles:
		var nf_id: int = tile.get("neutral_faction_id", -1)
		if nf_id >= 0 and tile["type"] == GameManager.TileType.NEUTRAL_BASE:
			bases[nf_id] = tile["index"]

	# Phase 2: For each neutral base, claim adjacent unowned tiles as territory
	for nf_id in bases:
		var base_idx: int = bases[nf_id]
		var territory: Array = []
		var initial_garrisons: Dictionary = {base_idx: GameManager.tiles[base_idx]["garrison"]}

		# Find adjacent tiles that are unowned and not belonging to another faction
		var max_territory: int = BalanceConfig.NEUTRAL_TERRITORY_NODES
		if GameManager.adjacency.has(base_idx):
			var candidates: Array = []
			for nb_idx in GameManager.adjacency[base_idx]:
				if nb_idx >= GameManager.tiles.size():
					continue
				if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
					return
				var nb: Dictionary = GameManager.tiles[nb_idx]
				# Only claim unowned tiles that aren't other neutral bases or core fortresses
				if nb.get("owner_id", -1) < 0 and nb.get("light_faction", -1) < 0 \
					and nb.get("neutral_faction_id", -1) < 0 \
					and nb["type"] != GameManager.TileType.CORE_FORTRESS \
					and nb["type"] != GameManager.TileType.RESOURCE_STATION:
					candidates.append(nb_idx)

			# Pick up to max_territory nodes
			candidates.shuffle()
			for c_idx in range(mini(max_territory, candidates.size())):
				var t_idx: int = candidates[c_idx]
				territory.append(t_idx)
				# Mark this tile as belonging to this neutral faction
				if t_idx >= 0 and t_idx < GameManager.tiles.size():
					GameManager.tiles[t_idx]["neutral_faction_id"] = nf_id
				# Set garrison for territory nodes
				var gar: int = randi_range(
					BalanceConfig.NEUTRAL_TERRITORY_GARRISON_MIN,
					BalanceConfig.NEUTRAL_TERRITORY_GARRISON_MAX
				)
				if t_idx >= 0 and t_idx < GameManager.tiles.size():
					GameManager.tiles[t_idx]["garrison"] = gar
				initial_garrisons[t_idx] = gar
				# Update tile name
				var faction_name: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf_id, "中立")
				if t_idx >= 0 and t_idx < GameManager.tiles.size():
					GameManager.tiles[t_idx]["name"] = faction_name + "领地 #" + str(t_idx)

		_faction_state[nf_id] = {
			"base_tile": base_idx,
			"territory": territory,
			"initial_garrisons": initial_garrisons,
			"vassal_of": -1,
		}
		_patrol_state[nf_id] = {
			"patrol_target": -1,
			"patrol_cooldown": 0,
		}


# ═══════════════ TURN TICK ═══════════════

func tick() -> void:
	## Called each turn by GameManager. Executes neutral AI for all independent factions.
	for nf_id in _faction_state:
		var state: Dictionary = _faction_state[nf_id]
		if state["vassal_of"] >= 0:
			_tick_vassal(nf_id, state)
		else:
			_tick_independent(nf_id, state)


func _tick_independent(nf_id: int, state: Dictionary) -> void:
	## Independent neutral faction: reinforce garrisons and patrol.
	var base_idx: int = state["base_tile"]

	# Skip if base has been captured
	if base_idx >= 0 and base_idx < GameManager.tiles.size():
		var base_tile: Dictionary = GameManager.tiles[base_idx]
		if base_tile.get("owner_id", -1) >= 0:
			return  # Base captured, faction is defeated

	# 1. Reinforce garrisons (slow regen toward initial values)
	_reinforce_garrisons(nf_id, state)

	# 2. Patrol: detect nearby threats and redistribute garrison
	_patrol_territory(nf_id, state)


func _tick_vassal(nf_id: int, state: Dictionary) -> void:
	## Vassal faction: reinforce garrisons with player bonus, share production.
	_reinforce_garrisons(nf_id, state)


func _reinforce_garrisons(nf_id: int, state: Dictionary) -> void:
	## Slowly regenerate garrison toward initial values.
	var regen: int = BalanceConfig.NEUTRAL_REINFORCE_PER_TURN
	var all_tiles: Array = [state["base_tile"]] + state["territory"]
	var cap_mult: float = BalanceConfig.NEUTRAL_REINFORCE_CAP_MULT

	for t_idx in all_tiles:
		if t_idx < 0 or t_idx >= GameManager.tiles.size():
			continue
		if t_idx < 0 or t_idx >= GameManager.tiles.size():
			return
		var tile: Dictionary = GameManager.tiles[t_idx]
		# Only reinforce tiles still belonging to this neutral faction
		if tile.get("owner_id", -1) >= 0:
			continue
		if tile.get("neutral_faction_id", -1) != nf_id:
			continue

		var initial: int = state["initial_garrisons"].get(t_idx, 10)
		var cap: int = int(float(initial) * cap_mult)
		# BUG修复: 每回合仅恢复regen数量的驻军，不再直接跳到上限
		if tile["garrison"] < cap:
			tile["garrison"] = mini(cap, tile["garrison"] + regen)


func _patrol_territory(nf_id: int, state: Dictionary) -> void:
	## Check for adjacent threats and reinforce threatened tiles from safer ones.
	var patrol: Dictionary = _patrol_state.get(nf_id, {})

	if patrol.get("patrol_cooldown", 0) > 0:
		patrol["patrol_cooldown"] -= 1
		return

	var all_tiles: Array = [state["base_tile"]] + state["territory"]
	var threat_scores: Dictionary = {}  # tile_idx -> threat level

	for t_idx in all_tiles:
		if t_idx < 0 or t_idx >= GameManager.tiles.size():
			continue
		if t_idx < 0 or t_idx >= GameManager.tiles.size():
			return
		var tile: Dictionary = GameManager.tiles[t_idx]
		if tile.get("owner_id", -1) >= 0 or tile.get("neutral_faction_id", -1) != nf_id:
			continue

		var threat: int = 0
		if GameManager.adjacency.has(t_idx):
			for nb_idx in GameManager.adjacency[t_idx]:
				if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
					continue
				if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
					return
				var nb: Dictionary = GameManager.tiles[nb_idx]
				if nb.get("owner_id", -1) >= 0:
					threat += 1
				# Check for armies adjacent
				for army_id in GameManager.armies:
					if GameManager.armies[army_id]["tile_index"] == nb_idx:
						threat += 2
		threat_scores[t_idx] = threat

	# Find most and least threatened tiles
	var max_threat: int = 0
	var max_tile: int = -1
	var min_threat: int = 999
	var min_tile: int = -1

	for t_idx in threat_scores:
		if threat_scores[t_idx] > max_threat:
			max_threat = threat_scores[t_idx]
			max_tile = t_idx
		if threat_scores[t_idx] < min_threat:
			min_threat = threat_scores[t_idx]
			min_tile = t_idx

	# Transfer garrison from least threatened to most threatened
	if max_tile >= 0 and min_tile >= 0 and max_tile != min_tile and max_threat > 0:
		if min_tile < 0 or min_tile >= GameManager.tiles.size():
			return
		var donor: Dictionary = GameManager.tiles[min_tile]
		if max_tile < 0 or max_tile >= GameManager.tiles.size():
			return
		var receiver: Dictionary = GameManager.tiles[max_tile]
		var transfer: int = mini(3, donor["garrison"] - BalanceConfig.NEUTRAL_TERRITORY_GARRISON_MIN)
		if transfer > 0:
			donor["garrison"] -= transfer
			receiver["garrison"] += transfer
			var faction_name: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf_id, "中立")
			EventBus.message_log.emit("[color=gray]%s 调兵增援受威胁领地[/color]" % faction_name)

	patrol["patrol_cooldown"] = 2  # Patrol every 2 turns


# ═══════════════ VASSAL SYSTEM ═══════════════

func vassalize(player_id: int, neutral_faction_id: int) -> void:
	## Convert a neutral faction to vassal of the player.
	if not _faction_state.has(neutral_faction_id):
		push_warning("NeutralFactionAI: vassalize called with unknown neutral_faction_id=%d" % neutral_faction_id)
		return

	var state: Dictionary = _faction_state[neutral_faction_id]
	state["vassal_of"] = player_id

	var faction_name: String = FactionData.NEUTRAL_FACTION_NAMES.get(neutral_faction_id, "中立势力")
	EventBus.message_log.emit("[color=lime]%s 成为你的附庸! 领地产出归你所有[/color]" % faction_name)
	EventBus.neutral_faction_vassalized.emit(player_id, neutral_faction_id)


func is_vassal(neutral_faction_id: int) -> bool:
	if not _faction_state.has(neutral_faction_id):
		return false
	return _faction_state[neutral_faction_id]["vassal_of"] >= 0


func get_vassal_owner(neutral_faction_id: int) -> int:
	if not _faction_state.has(neutral_faction_id):
		return -1
	return _faction_state[neutral_faction_id]["vassal_of"]


func get_vassal_tiles(player_id: int) -> Array:
	## Returns all tile indices belonging to neutral factions vassalized by this player.
	var result: Array = []
	for nf_id in _faction_state:
		var state: Dictionary = _faction_state[nf_id]
		if state["vassal_of"] != player_id:
			continue
		result.append(state["base_tile"])
		result.append_array(state["territory"])
	return result


func get_vassal_production(player_id: int) -> Dictionary:
	## Calculate total production from vassal territories for a player.
	## Uses NEUTRAL_FACTION_PRODUCTION for faction-specific unique resources,
	## plus base_production × VASSAL_PRODUCTION_SHARE for standard resources.
	var income: Dictionary = {
		"gold": 0, "food": 0, "iron": 0, "prestige": 0,
		"magic_crystal": 0, "war_horse": 0, "gunpowder": 0, "shadow_essence": 0,
	}
	var share: float = BalanceConfig.VASSAL_PRODUCTION_SHARE

	for nf_id in _faction_state:
		var state: Dictionary = _faction_state[nf_id]
		if state["vassal_of"] != player_id:
			continue

		# ── Faction-specific unique production (独特产出) ──
		var faction_prod: Dictionary = BalanceConfig.NEUTRAL_FACTION_PRODUCTION.get(nf_id, {})
		var base_prod: Dictionary = faction_prod.get("base", {})
		var territory_prod: Dictionary = faction_prod.get("territory", {})

		# Count active tiles (still under neutral control, not captured by enemies)
		var active_territory_count: int = 0
		var all_tiles: Array = [state["base_tile"]] + state["territory"]
		var base_active: bool = false

		for t_idx in all_tiles:
			if t_idx < 0 or t_idx >= GameManager.tiles.size():
				continue
			if t_idx < 0 or t_idx >= GameManager.tiles.size():
				return
			var tile: Dictionary = GameManager.tiles[t_idx]
			if tile.get("owner_id", -1) >= 0:
				continue  # tile captured by a player, skip
			if t_idx == state["base_tile"]:
				base_active = true
			else:
				active_territory_count += 1

		# Apply base tile production (if base is still active)
		if base_active:
			for key in base_prod:
				if income.has(key):
					income[key] += int(base_prod[key])

		# Apply per-territory-node production
		for key in territory_prod:
			if income.has(key):
				income[key] += int(territory_prod[key]) * active_territory_count

		# Apply prestige per turn (Blood Moon Cult special)
		var prestige_per_turn: int = faction_prod.get("prestige_per_turn", 0)
		if prestige_per_turn > 0 and base_active:
			income["prestige"] += prestige_per_turn

		# ── Standard tile base_production share (地块原始产出分成) ──
		for t_idx in all_tiles:
			if t_idx < 0 or t_idx >= GameManager.tiles.size():
				continue
			if t_idx < 0 or t_idx >= GameManager.tiles.size():
				return
			var tile: Dictionary = GameManager.tiles[t_idx]
			if tile.get("owner_id", -1) >= 0:
				continue
			var prod: Dictionary = tile.get("base_production", {})
			income["gold"] += int(float(prod.get("gold", 0)) * share)
			income["food"] += int(float(prod.get("food", 0)) * share)
			income["iron"] += int(float(prod.get("iron", 0)) * share)

	return income


# ═══════════════ QUERIES ═══════════════

func get_faction_territory(neutral_faction_id: int) -> Array:
	## Returns all tile indices owned by a neutral faction (base + territory).
	if not _faction_state.has(neutral_faction_id):
		return []
	var state: Dictionary = _faction_state[neutral_faction_id]
	return [state["base_tile"]] + state["territory"]


func get_faction_state(neutral_faction_id: int) -> Dictionary:
	return _faction_state.get(neutral_faction_id, {})


func is_neutral_territory(tile_index: int) -> bool:
	## Check if a tile belongs to any neutral faction's territory.
	for nf_id in _faction_state:
		var state: Dictionary = _faction_state[nf_id]
		if state["base_tile"] == tile_index or tile_index in state["territory"]:
			return true
	return false


func get_neutral_faction_at_tile(tile_index: int) -> int:
	## Returns the neutral faction ID that owns this tile, or -1.
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return -1
	return GameManager.tiles[tile_index].get("neutral_faction_id", -1)


func on_tile_captured(tile_index: int, _new_owner_id: int) -> void:
	## Called when a tile is captured. Updates neutral territory tracking.
	for nf_id in _faction_state:
		var state: Dictionary = _faction_state[nf_id]
		if tile_index == state["base_tile"]:
			# Base captured — faction is defeated, all territory becomes unaffiliated
			var faction_name: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf_id, "中立势力")
			EventBus.message_log.emit("[color=red]%s 的基地被攻占! 势力瓦解[/color]" % faction_name)
			# Clear neutral_faction_id from remaining territory
			for t_idx in state["territory"]:
				if t_idx < GameManager.tiles.size():
					if GameManager.tiles[t_idx].get("owner_id", -1) < 0:
						if t_idx >= 0 and t_idx < GameManager.tiles.size():
							GameManager.tiles[t_idx]["neutral_faction_id"] = -1
						@warning_ignore("integer_division")
						if t_idx >= 0 and t_idx < GameManager.tiles.size():
							GameManager.tiles[t_idx]["garrison"] = maxi(1, GameManager.tiles[t_idx]["garrison"] / 2)
			state["territory"].clear()
			break
		elif tile_index in state["territory"]:
			state["territory"].erase(tile_index)
			break


# ═══════════════ COMBAT SUPPORT ═══════════════

func get_defense_bonus(tile_index: int) -> float:
	## Returns defense bonus for neutral territory tiles.
	var nf_id: int = get_neutral_faction_at_tile(tile_index)
	if nf_id < 0:
		return 0.0
	if not _faction_state.has(nf_id):
		return 0.0

	var state: Dictionary = _faction_state[nf_id]

	# Vassal tiles get player tech bonus
	if state["vassal_of"] >= 0:
		return BalanceConfig.VASSAL_DEFENSE_BONUS

	# Base tile gets +30% defense
	if tile_index == state["base_tile"]:
		return 0.30

	# Territory tiles get +15% defense
	return 0.15


func reinforce_on_attack(tile_index: int) -> void:
	## When a neutral territory tile is attacked, adjacent neutral tiles send reinforcements.
	var nf_id: int = get_neutral_faction_at_tile(tile_index)
	if nf_id < 0 or not _faction_state.has(nf_id):
		return

	var state: Dictionary = _faction_state[nf_id]
	var all_tiles: Array = [state["base_tile"]] + state["territory"]
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	var target_tile: Dictionary = GameManager.tiles[tile_index]

	for t_idx in all_tiles:
		if t_idx == tile_index or t_idx < 0 or t_idx >= GameManager.tiles.size():
			continue
		# Only from adjacent tiles
		if not GameManager.adjacency.has(t_idx):
			continue
		if tile_index not in GameManager.adjacency[t_idx]:
			continue

		if t_idx < 0 or t_idx >= GameManager.tiles.size():
			return
		var donor: Dictionary = GameManager.tiles[t_idx]
		if donor.get("owner_id", -1) >= 0 or donor.get("neutral_faction_id", -1) != nf_id:
			continue

		# Send up to 30% of garrison as reinforcement
		var send: int = int(float(donor["garrison"]) * 0.3)
		if send > 0 and donor["garrison"] - send >= 3:
			donor["garrison"] -= send
			target_tile["garrison"] += send
			var faction_name: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf_id, "中立")
			EventBus.message_log.emit("[color=gray]%s 从邻近领地调来 %d 援军[/color]" % [faction_name, send])
			EventBus.neutral_territory_attacked.emit(nf_id, tile_index, -1)
			break  # Only one reinforcement per attack


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"faction_state": _faction_state.duplicate(true),
		"patrol_state": _patrol_state.duplicate(true),
	}


func _fix_int_keys(dict: Dictionary) -> void:
	var fix_keys = []
	for k in dict.keys():
		if k is String and k.is_valid_int():
			fix_keys.append(k)
	for k in fix_keys:
		dict[int(k)] = dict[k]
		dict.erase(k)


func from_save_data(data: Dictionary) -> void:
	_faction_state = data.get("faction_state", {}).duplicate(true)
	_fix_int_keys(_faction_state)
	for nf_id in _faction_state:
		var state: Dictionary = _faction_state[nf_id]
		if state.has("initial_garrisons") and state["initial_garrisons"] is Dictionary:
			_fix_int_keys(state["initial_garrisons"])
	for nf_id in _faction_state:
		var state: Dictionary = _faction_state[nf_id]
		if state.has("territory"):
			var fixed: Array = []
			for v in state["territory"]:
				fixed.append(int(v))
			state["territory"] = fixed
		if state.has("base_tile"):
			state["base_tile"] = int(state.get("base_tile", -1))
		if state.has("vassal_of"):
			state["vassal_of"] = int(state.get("vassal_of", -1))
	_patrol_state = data.get("patrol_state", {}).duplicate(true)
	_fix_int_keys(_patrol_state)
