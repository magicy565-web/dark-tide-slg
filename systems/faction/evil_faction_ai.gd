extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## evil_faction_ai.gd - Strategic AI for unrecruited evil faction outposts (v4.0)
## Now uses AIStrategicPlanner for intelligent target selection, tactical directives,
## personality-driven behavior, and adaptive army composition.

# ── Raid cooldown per faction to prevent spam ──
var _raid_cooldowns: Dictionary = {}  # faction_id -> int (turns remaining)

func _ready() -> void:
	pass

func reset() -> void:
	_raid_cooldowns.clear()

func tick(player_id: int) -> void:
	## Called each turn. Run AI for each unrecruited evil faction.
	for faction_id in [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]:
		if faction_id == GameManager.get_player_faction(player_id):
			continue  # Player's own faction
		if DiplomacyManager.is_recruited(player_id, faction_id):
			continue  # Already recruited
		_tick_faction(player_id, faction_id)
	# Decrement raid cooldowns
	for key in _raid_cooldowns.keys():
		if _raid_cooldowns[key] > 0:
			_raid_cooldowns[key] -= 1

func _tick_faction(player_id: int, faction_id: int) -> void:
	var is_hostile: bool = false
	var relations: Dictionary = DiplomacyManager.get_all_relations(player_id)
	if relations.has(faction_id):
		is_hostile = relations[faction_id].get("hostile", false)

	var ai_key: String = _faction_to_ai_key(faction_id)
	var strategy: int = AIStrategicPlanner.get_current_strategy(ai_key)
	var source_tiles: Array = []  # tiles belonging to this faction

	for tile in GameManager.tiles:
		if tile.get("original_faction", -1) != faction_id:
			continue
		if tile["owner_id"] >= 0:
			continue  # Already captured by player
		source_tiles.append(tile)

		# Garrison recovery: +1 per turn up to base max
		var base_garrison: int = _get_base_garrison(tile)
		var regen_bonus: int = AIScaling.get_garrison_regen_bonus(ai_key) if ai_key != "" else 0
		var regen_rate: int = 1 + regen_bonus
		var reinforce_mult: float = AIScaling.get_personality_mod(ai_key, "reinforce_mult") if ai_key != "" else 1.0
		regen_rate = maxi(1, int(float(regen_rate) * reinforce_mult))
		regen_rate = mini(regen_rate, 5)
		if tile.get("garrison", 0) < base_garrison:
			tile["garrison"] = mini(base_garrison, tile.get("garrison", 0) + regen_rate)

		# Reactive: if player owns adjacent tile, boost garrison
		var player_nearby: bool = false
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] == player_id:
					player_nearby = true
					break

		if player_nearby:
			tile["garrison"] = mini(tile.get("garrison", 0) + 1, base_garrison + 5)

	# ── Strategic actions based on planner ──
	if is_hostile and source_tiles.size() > 0:
		match strategy:
			AIStrategicPlanner.Strategy.RAID:
				_try_strategic_raid(player_id, source_tiles, faction_id)
			AIStrategicPlanner.Strategy.EXPAND:
				_try_strategic_raid(player_id, source_tiles, faction_id)
			AIStrategicPlanner.Strategy.DEFEND:
				AIStrategicPlanner.reinforce_threatened_border(ai_key)
			AIStrategicPlanner.Strategy.CONSOLIDATE:
				_consolidate_garrison(source_tiles, faction_id)
			_:
				# Default: chance-based raid for backward compat
				_try_legacy_raid(player_id, source_tiles, faction_id)

	# Coordinated attacks: if this faction is part of a coordinated assault
	if is_hostile:
		_try_coordinated_attack(player_id, faction_id, source_tiles)


func _try_strategic_raid(player_id: int, source_tiles: Array, faction_id: int) -> void:
	## Strategic raid: pick the best target instead of random.
	var ai_key: String = _faction_to_ai_key(faction_id)
	var raid_chance: float = float(BalanceConfig.EVIL_RAID_CHANCE_PCT) * AIScaling.get_personality_mod(ai_key, "raid_chance_mult")
	# Strategy RAID doubles the chance
	if AIStrategicPlanner.get_current_strategy(ai_key) == AIStrategicPlanner.Strategy.RAID:
		raid_chance *= 1.5
	if randi() % 100 >= int(raid_chance):
		return
	if _raid_cooldowns.get(faction_id, 0) > 0:
		return

	# Use strategic planner to find best target
	var result: Dictionary = AIStrategicPlanner.select_raid_target(ai_key, source_tiles)
	if result.is_empty():
		return

	var target: Dictionary = result["tile"]
	var source: Dictionary = result.get("source", source_tiles[0])
	var raid_strength: int = maxi(BalanceConfig.EVIL_RAID_MIN_STRENGTH, source.get("garrison", 0) / BalanceConfig.EVIL_RAID_STRENGTH_DIVISOR)

	# At tier 2+, bonus raid troops
	var tier: int = AIScaling.get_tier(ai_key)
	if tier >= 2:
		raid_strength += tier * 2

	var target_garrison: int = target.get("garrison", 0)

	# Choose tactical directive for the raid
	var directive: int = AIStrategicPlanner.choose_tactical_directive(ai_key, true, raid_strength, target_garrison)
	var directive_name: String = CombatResolver.DIRECTIVE_DATA.get(directive, {}).get("name", "")
	var directive_suffix: String = ""
	if directive_name != "" and directive_name != "无":
		directive_suffix = " [战术:%s]" % directive_name

	EventBus.message_log.emit("[color=orange]敌对军团突袭据点#%d! (兵力: %d)%s[/color]" % [target["index"], raid_strength, directive_suffix])

	# Apply directive multipliers to raid
	var atk_mult: float = 1.0
	var def_mult: float = 1.0
	var dir_data: Dictionary = CombatResolver.DIRECTIVE_DATA.get(directive, {})
	atk_mult = dir_data.get("atk_mult", 1.0)

	var effective_strength: float = float(raid_strength) * atk_mult

	if effective_strength > float(target_garrison):
		target["garrison"] = maxi(0, target_garrison - int(effective_strength / float(BalanceConfig.EVIL_RAID_DAMAGE_DIVISOR)))
		EventBus.message_log.emit("[color=red]突袭成功! 驻军损失严重[/color]")
		# Record this as a successful action for the player's memory
		AIStrategicPlanner.record_player_attack(ai_key, target["index"])
	else:
		target["garrison"] = maxi(0, target_garrison - 1)
		EventBus.message_log.emit("击退了敌方突袭, 驻军-1")

	_raid_cooldowns[faction_id] = 2  # Cooldown after raid


func _try_legacy_raid(player_id: int, source_tiles: Array, faction_id: int) -> void:
	## Fallback raid logic for non-strategic turns.
	var ai_key: String = _faction_to_ai_key(faction_id)
	if randi() % 100 >= int(float(BalanceConfig.EVIL_RAID_CHANCE_PCT) * AIScaling.get_personality_mod(ai_key, "raid_chance_mult")):
		return

	# Collect adjacent player tiles from all source tiles
	var targets: Array = []
	for src in source_tiles:
		if not GameManager.adjacency.has(src["index"]):
			continue
		for nb_idx in GameManager.adjacency[src["index"]]:
			if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] == player_id:
				var already: bool = false
				for t in targets:
					if t["tile"]["index"] == GameManager.tiles[nb_idx]["index"]:
						already = true
						break
				if not already:
					targets.append({"tile": GameManager.tiles[nb_idx], "source": src})

	if targets.is_empty():
		return

	# Pick weakest target instead of random
	targets.sort_custom(func(a, b): return a["tile"].get("garrison", 0) < b["tile"].get("garrison", 0))
	var target: Dictionary = targets[0]["tile"]
	var source: Dictionary = targets[0]["source"]

	var raid_strength: int = maxi(BalanceConfig.EVIL_RAID_MIN_STRENGTH, source.get("garrison", 0) / BalanceConfig.EVIL_RAID_STRENGTH_DIVISOR)
	var target_garrison: int = target.get("garrison", 0)

	EventBus.message_log.emit("[color=orange]敌对军团突袭据点#%d! (兵力: %d)[/color]" % [target["index"], raid_strength])

	if raid_strength > target_garrison:
		target["garrison"] = maxi(0, target_garrison - raid_strength / BalanceConfig.EVIL_RAID_DAMAGE_DIVISOR)
		EventBus.message_log.emit("[color=red]突袭成功! 驻军损失严重[/color]")
	else:
		target["garrison"] = maxi(0, target_garrison - 1)
		EventBus.message_log.emit("击退了敌方突袭, 驻军-1")


func _consolidate_garrison(source_tiles: Array, faction_id: int) -> void:
	## CONSOLIDATE strategy: redistribute garrison from safe interior to threatened border tiles.
	var border_tiles: Array = []
	var interior_tiles: Array = []

	for tile in source_tiles:
		var on_border: bool = false
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] >= 0:
					on_border = true
					break
		if on_border:
			border_tiles.append(tile)
		else:
			interior_tiles.append(tile)

	if border_tiles.is_empty() or interior_tiles.is_empty():
		return

	# Transfer from interior to border
	var transferred: int = 0
	for donor in interior_tiles:
		if donor.get("garrison", 0) > 3:
			var transfer: int = mini(2, donor["garrison"] - 3)
			donor["garrison"] -= transfer
			transferred += transfer

	if transferred <= 0:
		return

	# Sort border tiles by garrison ascending (weakest first)
	border_tiles.sort_custom(func(a, b): return a.get("garrison", 0) < b.get("garrison", 0))
	var per_tile: int = maxi(1, transferred / maxi(1, border_tiles.size()))
	var remaining: int = transferred
	for tile in border_tiles:
		if remaining <= 0:
			break
		var give: int = mini(per_tile, remaining)
		tile["garrison"] += give
		remaining -= give


func _try_coordinated_attack(player_id: int, faction_id: int, source_tiles: Array) -> void:
	## If AIStrategicPlanner has a coordinated target, add garrison pressure toward it.
	var coord_target: int = AIStrategicPlanner.get_coordinated_target()
	if coord_target < 0 or coord_target >= GameManager.tiles.size():
		return

	# Check if we have a tile adjacent to the coordinated target
	var adjacent_src: Dictionary = {}
	for src in source_tiles:
		if GameManager.adjacency.has(src["index"]):
			if coord_target in GameManager.adjacency[src["index"]]:
				adjacent_src = src
				break

	if adjacent_src.is_empty():
		return

	# Boost garrison on the adjacent tile for the coordinated push
	var ai_key: String = _faction_to_ai_key(faction_id)
	adjacent_src["garrison"] = adjacent_src.get("garrison", 0) + 3
	EventBus.message_log.emit("[%s] 调集兵力准备联合进攻据点#%d" % [AIScaling.FACTION_PERSONALITY.keys()[0] if ai_key == "" else ai_key, coord_target])


func _get_base_garrison(tile: Dictionary) -> int:
	## Returns the max garrison an AI faction tile should maintain.
	match tile.get("type", -1):
		GameManager.TileType.CORE_FORTRESS:
			return BalanceConfig.EVIL_GARRISON_CORE_FORTRESS
		GameManager.TileType.DARK_BASE:
			return BalanceConfig.EVIL_GARRISON_DARK_BASE
	return BalanceConfig.EVIL_GARRISON_DEFAULT

func get_faction_total_strength(faction_id: int) -> int:
	## Returns total garrison across all tiles of a faction (for difficulty display).
	var total: int = 0
	for tile in GameManager.tiles:
		if tile.get("original_faction", -1) == faction_id and tile["owner_id"] < 0:
			total += tile.get("garrison", 0)
	return total


func to_save_data() -> Dictionary:
	return {
		"raid_cooldowns": _raid_cooldowns.duplicate(),
	}


func from_save_data(data: Dictionary) -> void:
	_raid_cooldowns = data.get("raid_cooldowns", {}).duplicate()


func _faction_to_ai_key(faction_id: int) -> String:
	## Map faction ID to AIScaling key.
	match faction_id:
		FactionData.FactionID.ORC: return "orc_ai"
		FactionData.FactionID.PIRATE: return "pirate_ai"
		FactionData.FactionID.DARK_ELF: return "dark_elf_ai"
	return ""
