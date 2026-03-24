extends Node

## alliance_ai.gd - Light Alliance joint military AI (v0.7)

enum AllianceTier { NONE, DEFENSE, MILITARY, DESPERATE }

var _current_tier: int = AllianceTier.NONE
var _expedition_cooldown: int = 0  # Turns until next expedition can spawn
const EXPEDITION_COOLDOWN: int = 3

func _ready() -> void:
	pass

func reset() -> void:
	_current_tier = AllianceTier.NONE
	_expedition_cooldown = 0

func get_current_tier() -> int:
	return _current_tier

func get_tier_name() -> String:
	match _current_tier:
		AllianceTier.NONE: return "各自为战"
		AllianceTier.DEFENSE: return "防御联盟"
		AllianceTier.MILITARY: return "军事联盟"
		AllianceTier.DESPERATE: return "殊死抵抗"
	return "未知"

func tick(threat_value: int) -> void:
	## Called each turn by GameManager. Updates alliance tier and executes AI actions.
	var old_tier: int = _current_tier
	_current_tier = _evaluate_tier(threat_value)

	if _current_tier != old_tier:
		EventBus.alliance_formed.emit(threat_value)
		EventBus.message_log.emit("[color=cyan]光明联盟状态变更: %s[/color]" % get_tier_name())

	if _expedition_cooldown > 0:
		_expedition_cooldown -= 1

	match _current_tier:
		AllianceTier.DEFENSE:
			_apply_defense_bonus()
		AllianceTier.MILITARY:
			_apply_defense_bonus()
			_try_spawn_expedition()
			_coordinate_defense_focus()
		AllianceTier.DESPERATE:
			_apply_defense_bonus()
			_try_spawn_expedition()
			_reinforce_final_outposts()
			_coordinate_defense_focus()

func _evaluate_tier(threat: int) -> int:
	if threat >= BalanceConfig.THREAT_TIER_FULL_ALLIANCE:
		return AllianceTier.DESPERATE
	elif threat >= BalanceConfig.THREAT_TIER_MILITARY:
		return AllianceTier.MILITARY
	elif threat >= BalanceConfig.THREAT_TIER_DEFENSE:
		return AllianceTier.DEFENSE
	return AllianceTier.NONE

func _apply_defense_bonus() -> void:
	## Adjacent uncaptured light outposts get +30% garrison bonus.
	## This is tracked as a temporary modifier on tiles, reset each turn.
	for tile in GameManager.tiles:
		tile["alliance_def_bonus"] = 0  # Reset

	for tile in GameManager.tiles:
		if tile["owner_id"] >= 0:  # Player-owned, skip
			continue
		if tile.get("light_faction", -1) < 0:
			continue
		# Count adjacent uncaptured light tiles
		var adj_light: int = 0
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size():
					var nb: Dictionary = GameManager.tiles[nb_idx]
					if nb["owner_id"] < 0 and nb.get("light_faction", -1) >= 0:
						adj_light += 1
		if adj_light > 0:
			tile["alliance_def_bonus"] = BalanceConfig.ALLIANCE_DEF_BONUS_PCT

func _try_spawn_expedition() -> void:
	## Attempt to spawn a joint expedition army that attacks player's frontier.
	if _expedition_cooldown > 0:
		return
	# Spawn chance from BalanceConfig
	var chance: int = BalanceConfig.EXPEDITION_CHANCE_MILITARY if _current_tier == AllianceTier.MILITARY else BalanceConfig.EXPEDITION_CHANCE_DESPERATE
	if randi() % 100 >= chance:
		return

	# Find a player-owned tile adjacent to uncaptured light tiles (frontier)
	var frontier_tiles: Array = []
	for tile in GameManager.tiles:
		if tile["owner_id"] < 0:
			continue
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size():
					var nb: Dictionary = GameManager.tiles[nb_idx]
					if nb["owner_id"] < 0 and nb.get("light_faction", -1) >= 0:
						frontier_tiles.append(tile)
						break

	if frontier_tiles.is_empty():
		return

	# Pick a random frontier tile to attack
	var target: Dictionary = frontier_tiles[randi() % frontier_tiles.size()]

	# Spawn expedition strength based on tier (from BalanceConfig)
	var strength: int = BalanceConfig.EXPEDITION_STRENGTH_MILITARY if _current_tier == AllianceTier.MILITARY else BalanceConfig.EXPEDITION_STRENGTH_DESPERATE

	var exp_name: String = "联军远征军" if _current_tier == AllianceTier.MILITARY else "光明联军精锐"
	EventBus.message_log.emit("[color=red]%s 向据点#%d 发起进攻! (兵力: %d)[/color]" % [exp_name, target["index"], strength])

	# Simulate attack: compare expedition strength vs tile garrison
	var garrison: int = target.get("garrison", 0)
	var random_coeff: float = randf_range(0.75, 1.25)
	var exp_power: float = float(strength) * BalanceConfig.EXPEDITION_ATK_PER_UNIT * random_coeff
	var def_power: float = float(garrison) * BalanceConfig.EXPEDITION_DEF_PER_UNIT * randf_range(0.75, 1.25)

	# Alliance defense bonus from adjacent tiles
	var def_bonus: float = 1.0 + float(target.get("alliance_def_bonus", 0)) / 100.0
	def_power *= def_bonus

	if exp_power > def_power:
		# Expedition wins - tile lost
		target["owner_id"] = -1
		target["garrison"] = maxi(1, strength - int(float(garrison) * BalanceConfig.EXPEDITION_CAPTURE_GARRISON_LOSS))
		EventBus.message_log.emit("[color=red]据点#%d 被联军夺回![/color]" % target["index"])
		EventBus.territory_changed.emit(target["index"], -1)
		OrderManager.change_order(-3)
	else:
		# Defense holds
		var losses: int = maxi(1, int(float(strength) * BalanceConfig.EXPEDITION_DEFENSE_LOSS))
		target["garrison"] = maxi(1, garrison - losses)
		EventBus.message_log.emit("击退联军进攻! 驻军损失 %d" % losses)

	_expedition_cooldown = EXPEDITION_COOLDOWN

func _reinforce_final_outposts() -> void:
	## At DESPERATE tier, reinforce remaining uncaptured light outposts.
	for tile in GameManager.tiles:
		if tile["owner_id"] >= 0:
			continue
		if tile.get("light_faction", -1) < 0:
			continue
		# Add reinforcement per turn from BalanceConfig
		tile["garrison"] = tile.get("garrison", 0) + BalanceConfig.DESPERATE_REINFORCE_PER_TURN

func _coordinate_defense_focus() -> void:
	## At MILITARY+ tier, identify the most threatened light faction zone
	## and redistribute garrison from safer zones.
	var zone_threat: Dictionary = {0: 0, 1: 0, 2: 0}  # light_faction -> threat score
	var zone_tiles: Dictionary = {0: [], 1: [], 2: []}

	for tile in GameManager.tiles:
		var lf: int = tile.get("light_faction", -1)
		if lf < 0 or tile["owner_id"] >= 0:
			continue
		zone_tiles[lf].append(tile)
		# Count adjacent player-owned tiles as threat
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size():
					var nb: Dictionary = GameManager.tiles[nb_idx]
					if nb["owner_id"] >= 0:
						zone_threat[lf] += 1

	# Find most threatened zone
	var max_threat: int = 0
	var focus_zone: int = -1
	for z in zone_threat:
		if zone_threat[z] > max_threat and zone_tiles[z].size() > 0:
			max_threat = zone_threat[z]
			focus_zone = z

	if focus_zone < 0 or max_threat <= 0:
		return

	# Transfer 1 garrison from least threatened zones to most threatened
	var min_threat: int = 999
	var donor_zone: int = -1
	for z in zone_threat:
		if z != focus_zone and zone_threat[z] < min_threat and zone_tiles[z].size() > 0:
			min_threat = zone_threat[z]
			donor_zone = z

	if donor_zone < 0:
		return

	for tile in zone_tiles[focus_zone]:
		tile["garrison"] += 1

	for tile in zone_tiles[donor_zone]:
		if tile["garrison"] > BalanceConfig.ZONE_TRANSFER_MIN_GARRISON:
			tile["garrison"] -= 1

	var zone_names: Dictionary = {0: "人类王国", 1: "精灵族", 2: "法师塔"}
	EventBus.message_log.emit("[color=cyan]联盟重点防御: %s 区域[/color]" % zone_names.get(focus_zone, "未知"))

func to_save_data() -> Dictionary:
	return {
		"current_tier": _current_tier,
		"expedition_cooldown": _expedition_cooldown,
	}


func from_save_data(data: Dictionary) -> void:
	_current_tier = data.get("current_tier", AllianceTier.NONE)
	_expedition_cooldown = data.get("expedition_cooldown", 0)


func get_expedition_garrison(tile: Dictionary) -> int:
	## Returns effective garrison considering alliance bonuses.
	var base: int = tile.get("garrison", 0)
	var bonus_pct: int = tile.get("alliance_def_bonus", 0)
	return base + int(float(base) * float(bonus_pct) / 100.0)
