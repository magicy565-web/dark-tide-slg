## siege_system.gd - Siege mechanic for fortified tiles (v5.0)
## Autoload singleton. Fortified tiles require multi-turn sieges before capture.
extends Node

# ── Siege constants ──
const FORTRESS_SIEGE_TURNS: int = 3
const WALLED_SIEGE_TURNS: int = 2
const FORTRESS_WALL_HP: float = 100.0
const WALLED_WALL_HP: float = 60.0
const BASE_WALL_DAMAGE: float = 20.0
const ARMY_ATK_WALL_FACTOR: float = 0.1
const BASE_MORALE_LOSS: float = 15.0
const ISOLATED_MORALE_PENALTY: float = 5.0
const BASE_ATTRITION_RATE: float = 0.03
const BASE_SORTIE_CHANCE: float = 0.20
const SORTIE_HERO_BONUS: float = 0.10
const SORTIE_LOSS_PCT: float = 0.10
const STORM_AP_COST: int = 2
const STORM_DEF_PENALTY: float = 0.30
const ASSAULT_ATK_BONUS: float = 0.20

# ── Active sieges ──
var _active_sieges: Dictionary = {}
var _next_siege_id: int = 1


func _ready() -> void:
	pass


# ═══════════════ PUBLIC API ═══════════════

## Check whether a tile qualifies as fortified (requires siege to capture).
func is_tile_fortified(tile_index: int) -> bool:
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return false
	var tile: Dictionary = GameManager.tiles[tile_index]
	if tile.get("type", -1) == GameManager.TileType.CORE_FORTRESS:
		return true
	if tile.get("building_id", "") == "fortification":
		return true
	return false


## Start a siege on a fortified tile.
func start_siege(attacker_army_id: int, tile_index: int) -> Dictionary:
	if not GameManager.armies.has(attacker_army_id):
		return {}
	var army: Dictionary = GameManager.armies[attacker_army_id]
	var tile: Dictionary = GameManager.tiles[tile_index]
	var attacker_pid: int = army["player_id"]
	var defender_pid: int = tile.get("owner_id", -1)

	# Determine siege parameters based on tile type
	var turns: int = WALLED_SIEGE_TURNS
	var wall_hp: float = WALLED_WALL_HP
	if tile.get("type", -1) == GameManager.TileType.CORE_FORTRESS:
		turns = FORTRESS_SIEGE_TURNS
		wall_hp = FORTRESS_WALL_HP
	# Fortification building wall HP from building effects
	if tile.get("building_id", "") == "fortification":
		var bld_level: int = tile.get("building_level", 1)
		var effects: Dictionary = BuildingRegistry.get_building_effects("fortification", bld_level)
		wall_hp = float(effects.get("wall_hp", WALLED_WALL_HP))

	var siege_id: String = "siege_%d" % _next_siege_id
	_next_siege_id += 1

	var siege: Dictionary = {
		"siege_id": siege_id,
		"attacker_army_id": attacker_army_id,
		"attacker_player_id": attacker_pid,
		"defender_player_id": defender_pid,
		"tile_index": tile_index,
		"turns_remaining": turns,
		"total_turns": turns,
		"wall_hp": wall_hp,
		"wall_max_hp": wall_hp,
		"defender_morale": 100.0,
		"attrition_rate": BASE_ATTRITION_RATE,
		"sortie_chance": BASE_SORTIE_CHANCE,
	}
	_active_sieges[siege_id] = siege

	EventBus.siege_started.emit(attacker_army_id, tile_index, turns)
	EventBus.message_log.emit("[color=orange]围攻开始! %s 正在围攻 %s (需要%d回合)[/color]" % [
		army.get("name", "军团"), tile.get("name", "据点"), turns])
	return siege


## Process all sieges belonging to a player at the start of their turn.
## Returns an array of event dictionaries describing what happened.
func process_sieges(player_id: int) -> Array:
	var events: Array = []
	var sieges_to_remove: Array = []

	for siege_id in _active_sieges:
		var siege: Dictionary = _active_sieges[siege_id]
		if siege["attacker_player_id"] != player_id:
			continue
		# Verify army still exists
		if not GameManager.armies.has(siege["attacker_army_id"]):
			sieges_to_remove.append(siege_id)
			events.append({"type": "lifted", "siege_id": siege_id, "reason": "army_lost"})
			continue

		var army: Dictionary = GameManager.armies[siege["attacker_army_id"]]
		var tile_index: int = siege["tile_index"]
		var tile: Dictionary = GameManager.tiles[tile_index]

		# 1. Attacker deals wall damage
		var army_total_atk: int = _get_army_total_atk(siege["attacker_army_id"])
		var wall_damage: float = BASE_WALL_DAMAGE + float(army_total_atk) * ARMY_ATK_WALL_FACTOR
		# Gunpowder strategic buff
		var buffs: Dictionary = get_strategic_buffs(player_id)
		if buffs.get("siege_wall_damage_bonus", 0.0) > 0.0:
			wall_damage *= (1.0 + buffs["siege_wall_damage_bonus"])
		siege["wall_hp"] = maxf(0.0, siege["wall_hp"] - wall_damage)
		events.append({"type": "wall_damage", "siege_id": siege_id, "damage": wall_damage, "wall_hp": siege["wall_hp"]})
		EventBus.message_log.emit("[color=orange]围攻: 城壁受损 -%.0f (剩余%.0f/%.0f)[/color]" % [
			wall_damage, siege["wall_hp"], siege["wall_max_hp"]])

		# 2. Check wall breach -> final assault
		if siege["wall_hp"] <= 0.0:
			events.append({"type": "wall_breached", "siege_id": siege_id})
			EventBus.message_log.emit("[color=red]城壁崩塌! 发起总攻![/color]")
			# Final assault will be handled by game_manager when the player attacks
			# Mark siege as ready for assault
			siege["wall_hp"] = 0.0
			siege["turns_remaining"] = 0
			EventBus.siege_progress.emit(tile_index, siege["wall_hp"], siege["defender_morale"], 0)
			EventBus.siege_ended.emit(tile_index, "assault")
			sieges_to_remove.append(siege_id)
			continue

		# 3. Defender morale loss
		var morale_loss: float = BASE_MORALE_LOSS
		if _is_defender_isolated(tile_index, siege["defender_player_id"]):
			morale_loss += ISOLATED_MORALE_PENALTY
		siege["defender_morale"] = maxf(0.0, siege["defender_morale"] - morale_loss)
		EventBus.message_log.emit("[color=yellow]守军士气下降 -%.0f (剩余%.0f)[/color]" % [
			morale_loss, siege["defender_morale"]])

		# 4. Check morale collapse -> surrender
		if siege["defender_morale"] <= 0.0:
			events.append({"type": "surrender", "siege_id": siege_id, "tile_index": tile_index})
			EventBus.message_log.emit("[color=green]守军投降! 据点不战而降![/color]")
			_capture_tile_from_siege(siege)
			EventBus.siege_ended.emit(tile_index, "surrender")
			sieges_to_remove.append(siege_id)
			continue

		# 5. Attacker attrition
		var attrition_losses: int = _apply_attrition(siege["attacker_army_id"], siege["attrition_rate"])
		if attrition_losses > 0:
			events.append({"type": "attrition", "siege_id": siege_id, "losses": attrition_losses})
			EventBus.message_log.emit("[color=red]围城消耗: 己方损失 %d 名士兵[/color]" % attrition_losses)

		# 6. Sortie check
		var sortie_roll: float = randf()
		var sortie_threshold: float = siege["sortie_chance"]
		if sortie_roll < sortie_threshold:
			var defender_won: bool = _resolve_sortie(siege)
			events.append({"type": "sortie", "siege_id": siege_id, "defender_won": defender_won})
			EventBus.sortie_triggered.emit(tile_index, defender_won)

		# 7. Decrement turns
		siege["turns_remaining"] = maxi(0, siege["turns_remaining"] - 1)

		EventBus.siege_progress.emit(tile_index, siege["wall_hp"], siege["defender_morale"], siege["turns_remaining"])

	for sid in sieges_to_remove:
		_active_sieges.erase(sid)

	return events


## Storm the walls — immediate assault with DEF penalty. Costs 2 AP.
func storm_walls(siege_id: String) -> void:
	if not _active_sieges.has(siege_id):
		return
	var siege: Dictionary = _active_sieges[siege_id]
	EventBus.message_log.emit("[color=red]强攻城壁! 攻方DEF-%.0f%%[/color]" % (STORM_DEF_PENALTY * 100.0))
	# Mark siege as stormed — game_manager will apply penalty during combat
	siege["stormed"] = true
	siege["wall_hp"] = 0.0
	siege["turns_remaining"] = 0
	EventBus.siege_ended.emit(siege["tile_index"], "assault")
	_active_sieges.erase(siege_id)


## Lift (cancel) a siege. Army retreats.
func lift_siege(siege_id: String) -> void:
	if not _active_sieges.has(siege_id):
		return
	var siege: Dictionary = _active_sieges[siege_id]
	var tile_index: int = siege["tile_index"]
	EventBus.message_log.emit("[color=yellow]围攻撤退![/color]")
	EventBus.siege_ended.emit(tile_index, "lifted")
	_active_sieges.erase(siege_id)


## Get the active siege at a tile, or empty dict.
func get_siege_at_tile(tile_index: int) -> Dictionary:
	for siege_id in _active_sieges:
		if _active_sieges[siege_id]["tile_index"] == tile_index:
			return _active_sieges[siege_id]
	return {}


## Check if a tile is currently under siege.
func is_tile_under_siege(tile_index: int) -> bool:
	for siege_id in _active_sieges:
		if _active_sieges[siege_id]["tile_index"] == tile_index:
			return true
	return false


## Get all sieges for a player (as attacker).
func get_player_sieges(player_id: int) -> Array:
	var result: Array = []
	for siege_id in _active_sieges:
		if _active_sieges[siege_id]["attacker_player_id"] == player_id:
			result.append(_active_sieges[siege_id])
	return result


## Allied army attempts to break a siege.
func try_relief(army_id: int, siege_id: String) -> bool:
	if not _active_sieges.has(siege_id):
		return false
	if not GameManager.armies.has(army_id):
		return false
	var siege: Dictionary = _active_sieges[siege_id]
	var relief_army: Dictionary = GameManager.armies[army_id]
	var tile_index: int = siege["tile_index"]

	# Relief army must be on an adjacent tile
	if not GameManager.adjacency.has(relief_army["tile_index"]):
		return false
	var adj_tiles: Array = GameManager.adjacency[relief_army["tile_index"]]
	if not adj_tiles.has(tile_index):
		return false

	# Relief army must belong to the defender or an ally
	if relief_army["player_id"] != siege["defender_player_id"]:
		return false

	EventBus.message_log.emit("[color=green]援军抵达! 围攻被打破![/color]")
	EventBus.siege_ended.emit(tile_index, "relief")
	_active_sieges.erase(siege_id)
	return true


## Aggregate strategic resource buffs for a player based on owned resource stations.
func get_strategic_buffs(player_id: int) -> Dictionary:
	var buffs: Dictionary = {
		"magic_atk_bonus": 0.0,
		"movement_range_bonus": 0,
		"siege_wall_damage_bonus": 0.0,
		"espionage_bonus": 0.0,
	}
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) != player_id:
			continue
		if tile.get("type", -1) != GameManager.TileType.RESOURCE_STATION:
			continue
		var stype: String = tile.get("resource_station_type", "")
		match stype:
			"magic_crystal":
				buffs["magic_atk_bonus"] += 0.10
			"war_horse":
				buffs["movement_range_bonus"] += 1
			"gunpowder":
				buffs["siege_wall_damage_bonus"] += 0.15
			"shadow_essence":
				buffs["espionage_bonus"] += 0.20
	EventBus.strategic_buff_changed.emit(player_id, buffs)
	return buffs


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"active_sieges": _active_sieges.duplicate(true),
		"next_siege_id": _next_siege_id,
	}


func from_save_data(data: Dictionary) -> void:
	_active_sieges = data.get("active_sieges", {}).duplicate(true)
	_next_siege_id = int(data.get("next_siege_id", 1))
	# Fix integer fields inside each siege dict after JSON round-trip
	for siege_id in _active_sieges:
		var s: Dictionary = _active_sieges[siege_id]
		for key in ["attacker_army_id", "attacker_player_id", "defender_player_id",
					"tile_index", "turns_remaining", "total_turns"]:
			if s.has(key):
				s[key] = int(s[key])
		for key in ["wall_hp", "wall_max_hp", "defender_morale", "attrition_rate", "sortie_chance"]:
			if s.has(key):
				s[key] = float(s[key])


# ═══════════════ INTERNALS ═══════════════

func _get_army_total_atk(army_id: int) -> int:
	if not GameManager.armies.has(army_id):
		return 0
	var total: int = 0
	for troop in GameManager.armies[army_id]["troops"]:
		var troop_id: String = troop.get("troop_id", "")
		var base_atk: int = GameData.get_troop_def(troop_id).get("base_atk", 5)
		total += base_atk * troop.get("soldiers", 0)
	return total


func _apply_attrition(army_id: int, rate: float) -> int:
	if not GameManager.armies.has(army_id):
		return 0
	var total_lost: int = 0
	for troop in GameManager.armies[army_id]["troops"]:
		var soldiers: int = troop.get("soldiers", 0)
		var lost: int = maxi(1, int(float(soldiers) * rate))
		troop["soldiers"] = maxi(0, soldiers - lost)
		total_lost += lost
	return total_lost


func _is_defender_isolated(tile_index: int, defender_pid: int) -> bool:
	## A defender is isolated if none of the adjacent tiles belong to them.
	if not GameManager.adjacency.has(tile_index):
		return true
	for nb in GameManager.adjacency[tile_index]:
		if nb < GameManager.tiles.size() and GameManager.tiles[nb].get("owner_id", -1) == defender_pid:
			return false
	return true


func _resolve_sortie(siege: Dictionary) -> bool:
	## Mini-combat sortie. Returns true if defender wins.
	var defender_won: bool = randf() < 0.5  # 50/50 for simplicity
	if defender_won:
		# Attacker loses 10% troops
		_apply_attrition(siege["attacker_army_id"], SORTIE_LOSS_PCT)
		EventBus.message_log.emit("[color=red]守军突围成功! 攻方损失%.0f%%兵力[/color]" % (SORTIE_LOSS_PCT * 100.0))
	else:
		# Defender loses morale
		siege["defender_morale"] = maxf(0.0, siege["defender_morale"] - 10.0)
		EventBus.message_log.emit("[color=green]守军突围失败! 守方士气-10[/color]")
	return defender_won


func _capture_tile_from_siege(siege: Dictionary) -> void:
	## Capture a tile through siege surrender (no battle).
	var army_id: int = siege["attacker_army_id"]
	if not GameManager.armies.has(army_id):
		return
	var army: Dictionary = GameManager.armies[army_id]
	var player: Dictionary = GameManager.get_player_by_id(army["player_id"])
	if player.is_empty():
		return
	var tile: Dictionary = GameManager.tiles[siege["tile_index"]]
	var from_tile: int = army["tile_index"]
	GameManager._capture_tile(player, tile)
	army["tile_index"] = siege["tile_index"]
	GameManager._reveal_around(siege["tile_index"], army["player_id"])
	GameManager.check_win_condition()
	EventBus.army_deployed.emit(army["player_id"], army_id, from_tile, siege["tile_index"])
