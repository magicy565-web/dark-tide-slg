extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## evil_faction_ai.gd - AI for unrecruited evil faction outposts (v0.7)

func _ready() -> void:
	pass

func reset() -> void:
	pass

func tick(player_id: int) -> void:
	## Called each turn. Run AI for each unrecruited evil faction.
	for faction_id in [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]:
		if faction_id == GameManager.get_player_faction(player_id):
			continue  # Player's own faction
		if DiplomacyManager.is_recruited(player_id, faction_id):
			continue  # Already recruited
		_tick_faction(player_id, faction_id)

func _tick_faction(player_id: int, faction_id: int) -> void:
	var is_hostile: bool = false
	var relations: Dictionary = DiplomacyManager.get_all_relations(player_id)
	if relations.has(faction_id):
		is_hostile = relations[faction_id].get("hostile", false)

	for tile in GameManager.tiles:
		if tile.get("original_faction", -1) != faction_id:
			continue
		if tile["owner_id"] >= 0:
			continue  # Already captured by player

		# Garrison recovery: +1 per turn up to base max
		var base_garrison: int = _get_base_garrison(tile)
		# v0.8.5: AI threat scaling garrison regen bonus
		var ai_key: String = _faction_to_ai_key(faction_id)
		var regen_bonus: int = AIScaling.get_garrison_regen_bonus(ai_key) if ai_key != "" else 0
		var regen_rate: int = 1 + regen_bonus
		# BUG修复: 限制每回合最大驻军恢复量，防止无限制增长
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

		# Hostile faction: chance to raid player's adjacent tiles
		if is_hostile and player_nearby:
			_try_raid(player_id, tile, faction_id)

func _try_raid(player_id: int, source_tile: Dictionary, _faction_id: int) -> void:
	## Hostile faction has 10% chance per turn to raid an adjacent player tile.
	if randi() % 100 >= BalanceConfig.EVIL_RAID_CHANCE_PCT:
		return

	if not GameManager.adjacency.has(source_tile["index"]):
		return

	var targets: Array = []
	for nb_idx in GameManager.adjacency[source_tile["index"]]:
		if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] == player_id:
			targets.append(GameManager.tiles[nb_idx])

	if targets.is_empty():
		return

	var target: Dictionary = targets[randi() % targets.size()]
	var raid_strength: int = maxi(BalanceConfig.EVIL_RAID_MIN_STRENGTH, source_tile.get("garrison", 0) / BalanceConfig.EVIL_RAID_STRENGTH_DIVISOR)
	var target_garrison: int = target.get("garrison", 0)

	EventBus.message_log.emit("[color=orange]敌对军团突袭据点#%d! (兵力: %d)[/color]" % [target["index"], raid_strength])

	if raid_strength > target_garrison:
		# Raid success - damage but don't capture (just reduce garrison)
		target["garrison"] = maxi(0, target_garrison - raid_strength / BalanceConfig.EVIL_RAID_DAMAGE_DIVISOR)
		EventBus.message_log.emit("[color=red]突袭成功! 驻军损失严重[/color]")
	else:
		target["garrison"] = maxi(0, target_garrison - 1)
		EventBus.message_log.emit("击退了敌方突袭, 驻军-1")

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
	# EvilFactionAI has no persistent state beyond tile garrisons (saved in GameManager).
	# This stub ensures SaveManager compatibility and future extensibility.
	return {}


func from_save_data(_data: Dictionary) -> void:
	pass


func _faction_to_ai_key(faction_id: int) -> String:
	## v0.8.5: Map faction ID to AIScaling key.
	match faction_id:
		FactionData.FactionID.ORC: return "orc_ai"
		FactionData.FactionID.PIRATE: return "pirate_ai"
		FactionData.FactionID.DARK_ELF: return "dark_elf_ai"
	return ""
