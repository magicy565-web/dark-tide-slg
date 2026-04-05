extends Node

## alliance_ai.gd - Light Alliance joint military AI (v3.5)
## Now includes proactive counterattack, raid, and surge reinforcement systems.

enum AllianceTier { NONE, DEFENSE, MILITARY, DESPERATE }

var _current_tier: int = AllianceTier.NONE
var _expedition_cooldown: int = 0  # Turns until next expedition can spawn
var _counter_cooldown: int = 0     # Turns until next counterattack
const EXPEDITION_COOLDOWN: int = 3

func _ready() -> void:
	pass

func reset() -> void:
	_current_tier = AllianceTier.NONE
	_expedition_cooldown = 0
	_counter_cooldown = 0

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

	match _current_tier:
		AllianceTier.DEFENSE:
			_apply_defense_bonus()
			_try_counterattack()
			_try_light_raid()
		AllianceTier.MILITARY:
			_apply_defense_bonus()
			_try_spawn_expedition()
			_try_counterattack()
			_try_surge_reinforce()
			_try_light_raid()
			_coordinate_defense_focus()
		AllianceTier.DESPERATE:
			_apply_defense_bonus()
			_try_spawn_expedition()
			_try_counterattack()
			_try_surge_reinforce()
			_try_light_raid()
			_reinforce_final_outposts()
			_coordinate_defense_focus()

	_decrement_cooldowns()

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
	for tile in GameManager.tiles:
		if tile == null:
			continue
		tile["alliance_def_bonus"] = 0  # Reset

	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile["owner_id"] >= 0:
			continue
		if tile.get("light_faction", -1) < 0:
			continue
		var adj_light: int = 0
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size():
					var nb: Dictionary = GameManager.tiles[nb_idx]
					if nb["owner_id"] < 0 and nb.get("light_faction", -1) >= 0:
						adj_light += 1
		if adj_light > 0:
			tile["alliance_def_bonus"] = BalanceConfig.ALLIANCE_DEF_BONUS_PCT


# ═══════════════ EXPEDITION (reactive defense) ═══════════════

func _try_spawn_expedition() -> void:
	if _expedition_cooldown > 0:
		return
	var chance: int = BalanceConfig.EXPEDITION_CHANCE_MILITARY if _current_tier == AllianceTier.MILITARY else BalanceConfig.EXPEDITION_CHANCE_DESPERATE
	var scaled_chance: float = float(chance) * BalanceManager.get_expedition_chance_mult()
	if randi() % 100 >= int(scaled_chance):
		return

	var frontier_tiles: Array = _get_player_frontier_tiles()
	if frontier_tiles.is_empty():
		return

	var target: Dictionary = frontier_tiles[randi() % frontier_tiles.size()]
	var strength: int = BalanceConfig.EXPEDITION_STRENGTH_MILITARY if _current_tier == AllianceTier.MILITARY else BalanceConfig.EXPEDITION_STRENGTH_DESPERATE
	# v3.5: Scale strength by aggression
	strength = int(float(strength) * BalanceManager.get_ai_aggression())
	strength = maxi(strength, 4)

	var exp_name: String = "联军远征军" if _current_tier == AllianceTier.MILITARY else "光明联军精锐"
	EventBus.message_log.emit("[color=red]%s 向据点#%d 发起进攻! (兵力: %d)[/color]" % [exp_name, target["index"], strength])

	_resolve_attack(target, strength, exp_name)
	_expedition_cooldown = EXPEDITION_COOLDOWN


# ═══════════════ COUNTERATTACK (proactive reconquest) ═══════════════

func _try_counterattack() -> void:
	## Light AI actively attempts to recapture tiles adjacent to their territory.
	if _counter_cooldown > 0:
		return

	# Determine chance and strength from tier
	var chance: int
	var strength: int
	var cooldown: int
	match _current_tier:
		AllianceTier.DEFENSE:
			chance = BalanceConfig.COUNTER_CHANCE_DEFENSE
			strength = BalanceConfig.COUNTER_STRENGTH_DEFENSE
			cooldown = BalanceConfig.COUNTER_COOLDOWN_DEFENSE
		AllianceTier.MILITARY:
			chance = BalanceConfig.COUNTER_CHANCE_MILITARY
			strength = BalanceConfig.COUNTER_STRENGTH_MILITARY
			cooldown = BalanceConfig.COUNTER_COOLDOWN_MILITARY
		AllianceTier.DESPERATE:
			chance = BalanceConfig.COUNTER_CHANCE_DESPERATE
			strength = BalanceConfig.COUNTER_STRENGTH_DESPERATE
			cooldown = BalanceConfig.COUNTER_COOLDOWN_DESPERATE
		_:
			return

	# v3.5: Scale by difficulty aggression multiplier
	var scaled_chance: float = float(chance) * BalanceManager.get_ai_aggression()
	if randi() % 100 >= int(scaled_chance):
		return

	# Find player-owned tiles that were originally light faction territory
	var reconquest_targets: Array = _get_reconquest_targets()
	if reconquest_targets.is_empty():
		return

	# Score targets: prefer weakly garrisoned + high-value tiles
	var best_target: Dictionary = {}
	var best_score: float = -999.0
	for tile in reconquest_targets:
		var score: float = 0.0
		var garrison: int = tile.get("garrison", 0)
		# Weak garrison = high priority
		score += 10.0 - float(garrison) * 0.5
		# Strongholds/fortresses = very high priority to recapture
		match tile.get("type", -1):
			GameManager.TileType.LIGHT_STRONGHOLD:
				score += 15.0
			GameManager.TileType.CORE_FORTRESS:
				score += 20.0
			_:
				score += 3.0
		# Adjacent to more light tiles = easier to reinforce after capture
		var adj_light: int = _count_adjacent_light(tile["index"])
		score += float(adj_light) * 2.0
		if score > best_score:
			best_score = score
			best_target = tile

	if best_target.is_empty():
		return

	# Scale strength by aggression
	strength = int(float(strength) * BalanceManager.get_ai_aggression())
	strength = maxi(strength, 3)

	EventBus.message_log.emit("[color=red]光明联军向据点#%d 发动反攻! (兵力: %d)[/color]" % [best_target["index"], strength])

	var won: bool = _resolve_attack(best_target, strength, "光明反攻军")
	if won:
		# Recaptured tile reverts to light control
		best_target["light_faction"] = best_target.get("_original_light_faction", best_target.get("light_faction", 0))
		EventBus.message_log.emit("[color=red]据点#%d 被光明联军夺回![/color]" % best_target["index"])

	_counter_cooldown = cooldown


# ═══════════════ LIGHT RAIDS (economic harassment) ═══════════════

func _try_light_raid() -> void:
	## Light sends small raiding parties to damage player economy.
	var chance: int
	match _current_tier:
		AllianceTier.DEFENSE:
			chance = BalanceConfig.LIGHT_RAID_CHANCE_DEFENSE
		AllianceTier.MILITARY:
			chance = BalanceConfig.LIGHT_RAID_CHANCE_MILITARY
		AllianceTier.DESPERATE:
			chance = BalanceConfig.LIGHT_RAID_CHANCE_DESPERATE
		_:
			return

	var scaled_chance: float = float(chance) * BalanceManager.get_ai_aggression()
	if randi() % 100 >= int(scaled_chance):
		return

	# Find player interior tiles (not on frontier — raids bypass frontline)
	var interior_tiles: Array = _get_player_interior_tiles()
	if interior_tiles.is_empty():
		# Fall back to any player tile
		var all_player: Array = _get_all_player_tiles()
		if all_player.is_empty():
			return
		interior_tiles = all_player
	if interior_tiles.is_empty():
		return

	var target: Dictionary = interior_tiles[randi() % interior_tiles.size()]
	var pid: int = target["owner_id"]

	# Damage: steal gold + reduce garrison
	var gold_stolen: int = randi_range(BalanceConfig.LIGHT_RAID_GOLD_DAMAGE_MIN, BalanceConfig.LIGHT_RAID_GOLD_DAMAGE_MAX)
	gold_stolen = int(float(gold_stolen) * BalanceManager.get_ai_aggression())
	var current_gold: int = ResourceManager.get_resource(pid, "gold")
	gold_stolen = mini(gold_stolen, current_gold)

	if gold_stolen > 0:
		ResourceManager.apply_delta(pid, {"gold": -gold_stolen})
	target["garrison"] = maxi(0, target.get("garrison", 0) - BalanceConfig.LIGHT_RAID_GARRISON_DAMAGE)

	var raid_type: String
	match _current_tier:
		AllianceTier.DESPERATE: raid_type = "精锐游骑兵"
		AllianceTier.MILITARY: raid_type = "联军斥候队"
		_: raid_type = "光明游击队"

	EventBus.message_log.emit("[color=red]%s 袭击了据点#%d! 掠夺金币 %d, 驻军-2[/color]" % [raid_type, target["index"], gold_stolen])


# ═══════════════ SURGE REINFORCEMENT ═══════════════

func _try_surge_reinforce() -> void:
	## At MILITARY+, light AI periodically mass-reinforces frontier tiles.
	var scaled_chance: float = float(BalanceConfig.SURGE_REINFORCE_CHANCE) * BalanceManager.get_ai_aggression()
	if randi() % 100 >= int(scaled_chance):
		return

	# Find uncaptured light tiles on the frontline (adjacent to player tiles)
	var frontline: Array = []
	for tile in GameManager.tiles:
		if tile["owner_id"] >= 0:
			continue
		if tile.get("light_faction", -1) < 0:
			continue
		if _is_tile_on_frontline(tile["index"]):
			frontline.append(tile)

	if frontline.is_empty():
		return

	# Sort by garrison (reinforce weakest first)
	frontline.sort_custom(func(a, b): return a.get("garrison", 0) < b.get("garrison", 0))

	var reinforced: int = 0
	var amount: int = int(float(BalanceConfig.SURGE_REINFORCE_AMOUNT) * BalanceManager.get_ai_aggression())
	amount = maxi(amount, 2)
	for tile in frontline:
		if reinforced >= BalanceConfig.SURGE_REINFORCE_MAX_TILES:
			break
		tile["garrison"] = tile.get("garrison", 0) + amount
		reinforced += 1

	if reinforced > 0:
		EventBus.message_log.emit("[color=cyan]光明联盟紧急增援前线: %d个据点 各+%d驻军[/color]" % [reinforced, amount])


# ═══════════════ EXISTING DEFENSE SYSTEMS ═══════════════

func _reinforce_final_outposts() -> void:
	for tile in GameManager.tiles:
		if tile["owner_id"] >= 0:
			continue
		if tile.get("light_faction", -1) < 0:
			continue
		tile["garrison"] = tile.get("garrison", 0) + BalanceConfig.DESPERATE_REINFORCE_PER_TURN

func _coordinate_defense_focus() -> void:
	var zone_threat: Dictionary = {0: 0, 1: 0, 2: 0}
	var zone_tiles: Dictionary = {0: [], 1: [], 2: []}

	for tile in GameManager.tiles:
		# BUG FIX R16: null check + safe dict access
		if tile == null:
			continue
		var lf: int = tile.get("light_faction", -1)
		if lf < 0 or tile.get("owner_id", -1) >= 0:
			continue
		if not zone_tiles.has(lf):
			zone_tiles[lf] = []
			zone_threat[lf] = 0
		zone_tiles[lf].append(tile)
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size():
					var nb = GameManager.tiles[nb_idx]
					if nb != null and nb.get("owner_id", -1) >= 0:
						zone_threat[lf] += 1

	var max_threat: int = 0
	var focus_zone: int = -1
	for z in zone_threat:
		if zone_threat[z] > max_threat and zone_tiles[z].size() > 0:
			max_threat = zone_threat[z]
			focus_zone = z

	if focus_zone < 0 or max_threat <= 0:
		return

	var min_threat: int = 999
	var donor_zone: int = -1
	for z in zone_threat:
		if z != focus_zone and zone_threat[z] < min_threat and zone_tiles[z].size() > 0:
			min_threat = zone_threat[z]
			donor_zone = z

	if donor_zone < 0:
		return

	var donor_garrison_total: int = 0
	for tile in zone_tiles[donor_zone]:
		if tile["garrison"] > BalanceConfig.ZONE_TRANSFER_MIN_GARRISON:
			donor_garrison_total += 1

	var focus_tile_count: int = zone_tiles[focus_zone].size()
	var available: int = mini(donor_garrison_total, focus_tile_count)

	var transferred: int = 0
	for tile in zone_tiles[focus_zone]:
		if transferred >= available:
			break
		tile["garrison"] += 1
		transferred += 1

	var donated: int = 0
	for tile in zone_tiles[donor_zone]:
		if donated >= transferred:
			break
		if tile["garrison"] > BalanceConfig.ZONE_TRANSFER_MIN_GARRISON:
			tile["garrison"] -= 1
			donated += 1

	var zone_names: Dictionary = {0: "人类王国", 1: "精灵族", 2: "法师塔"}
	EventBus.message_log.emit("[color=cyan]联盟重点防御: %s 区域[/color]" % zone_names.get(focus_zone, "未知"))


# ═══════════════ COMBAT RESOLUTION ═══════════════

func _resolve_attack(target: Dictionary, strength: int, attacker_name: String) -> bool:
	## Resolves an AI attack on a player-owned tile. Returns true if attacker wins.
	var garrison: int = target.get("garrison", 0)
	var random_coeff: float = randf_range(0.75, 1.25)
	var exp_power: float = float(strength) * BalanceConfig.COUNTER_ATK_PER_UNIT * random_coeff * BalanceManager.get_ai_atk_mult()
	var def_power: float = float(garrison) * BalanceConfig.COUNTER_DEF_PER_UNIT * randf_range(0.75, 1.25)

	# alliance_def_bonus is already a percentage value (e.g., 30 = 30%)
	var def_bonus: float = 1.0 + float(target.get("alliance_def_bonus", 0)) * 0.01
	def_power *= def_bonus

	if exp_power > def_power:
		# Attacker wins — tile lost
		# Unstation garrison commander if any before changing ownership
		if HeroSystem and HeroSystem.has_method("unstation_hero"):
			HeroSystem.unstation_hero(target["index"])
		target["owner_id"] = -1
		target["garrison"] = maxi(1, strength - int(float(garrison) * BalanceConfig.EXPEDITION_CAPTURE_GARRISON_LOSS))
		EventBus.territory_changed.emit(target["index"], -1)
		OrderManager.change_order(-3)
		return true
	else:
		# Defense holds
		var losses: int = maxi(1, int(float(strength) * BalanceConfig.EXPEDITION_DEFENSE_LOSS))
		target["garrison"] = maxi(1, garrison - losses)
		EventBus.message_log.emit("击退%s进攻! 驻军损失 %d" % [attacker_name, losses])
		return false


# ═══════════════ UTILITY ═══════════════

func _get_player_frontier_tiles() -> Array:
	## Player tiles adjacent to uncaptured light tiles.
	var result: Array = []
	for tile in GameManager.tiles:
		if tile["owner_id"] < 0:
			continue
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size():
					var nb: Dictionary = GameManager.tiles[nb_idx]
					if nb["owner_id"] < 0 and nb.get("light_faction", -1) >= 0:
						result.append(tile)
						break
	return result

func _get_reconquest_targets() -> Array:
	## Player-owned tiles that originally belonged to light factions or are adjacent to light territory.
	var result: Array = []
	for tile in GameManager.tiles:
		if tile["owner_id"] < 0:
			continue
		# Was originally a light faction tile
		if tile.get("_original_light_faction", -1) >= 0 or tile.get("light_faction", -1) >= 0:
			result.append(tile)
			continue
		# Adjacent to uncaptured light tiles (border push-back)
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size():
					var nb: Dictionary = GameManager.tiles[nb_idx]
					if nb["owner_id"] < 0 and nb.get("light_faction", -1) >= 0:
						result.append(tile)
						break
	return result

func _get_player_interior_tiles() -> Array:
	## Player tiles NOT on the frontier (surrounded by friendly tiles).
	var result: Array = []
	for tile in GameManager.tiles:
		# BUG FIX R16: null check + safe dict access
		if tile == null:
			continue
		if tile.get("owner_id", -1) < 0:
			continue
		var on_border: bool = false
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size():
					var nb_tile = GameManager.tiles[nb_idx]
					if nb_tile != null and nb_tile.get("owner_id", -1) != tile.get("owner_id", -1):
						on_border = true
						break
		if not on_border:
			result.append(tile)
	return result

func _get_all_player_tiles() -> Array:
	var result: Array = []
	for tile in GameManager.tiles:
		# BUG FIX R16: null check
		if tile == null:
			continue
		if tile.get("owner_id", -1) >= 0:
			result.append(tile)
	return result

func _count_adjacent_light(tile_index: int) -> int:
	var count: int = 0
	if GameManager.adjacency.has(tile_index):
		for nb_idx in GameManager.adjacency[tile_index]:
			if nb_idx < GameManager.tiles.size():
				var nb: Dictionary = GameManager.tiles[nb_idx]
				if nb["owner_id"] < 0 and nb.get("light_faction", -1) >= 0:
					count += 1
	return count

func _is_tile_on_frontline(tile_index: int) -> bool:
	if GameManager.adjacency.has(tile_index):
		for nb_idx in GameManager.adjacency[tile_index]:
			if nb_idx < GameManager.tiles.size():
				if GameManager.tiles[nb_idx]["owner_id"] >= 0:
					return true
	return false

func _decrement_cooldowns() -> void:
	if _expedition_cooldown > 0:
		_expedition_cooldown -= 1
	if _counter_cooldown > 0:
		_counter_cooldown -= 1


# ═══════════════ SAVE/LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"current_tier": _current_tier,
		"expedition_cooldown": _expedition_cooldown,
		"counter_cooldown": _counter_cooldown,
	}


func from_save_data(data: Dictionary) -> void:
	_current_tier = data.get("current_tier", AllianceTier.NONE)
	_expedition_cooldown = data.get("expedition_cooldown", 0)
	_counter_cooldown = data.get("counter_cooldown", 0)


func get_expedition_garrison(tile: Dictionary) -> int:
	var base: int = tile.get("garrison", 0)
	var bonus_pct: int = tile.get("alliance_def_bonus", 0)
	return base + int(float(base) * float(bonus_pct) / 100.0)
