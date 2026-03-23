## order_manager.gd - Tracks Order value (0-100, start 50)
extends Node

var _order: int = 50

func _ready() -> void:
	pass


func reset() -> void:
	_order = 50


func get_order() -> int:
	return _order


func change_order(delta: int) -> void:
	var old: int = _order
	_order = clampi(_order + delta, 0, 100)
	if _order != old:
		EventBus.message_log.emit("秩序值: %d -> %d" % [old, _order])
		EventBus.resources_changed.emit(-1)  # global refresh
		EventBus.order_changed.emit(_order)


# ═══════════════ PRODUCTION MULTIPLIER ═══════════════

func get_production_multiplier() -> float:
	if _order <= 25:
		return 0.5
	elif _order <= 50:
		return 0.75
	elif _order <= 75:
		return 1.0
	else:
		return 1.15


# ═══════════════ REBELLION ═══════════════

func get_rebellion_chance() -> float:
	## Per-turn rebellion probability.
	if _order <= 25:
		return 0.20
	elif _order <= 50:
		return 0.10
	else:
		return 0.0


func try_rebellion() -> Dictionary:
	## Roll for rebellion. Returns { "occurred": bool, "tile_index": int, "garrison": int }.
	var chance: float = get_rebellion_chance()
	if chance <= 0.0 or randf() >= chance:
		return {"occurred": false, "tile_index": -1, "garrison": 0}

	# Pick a random player-owned tile to rebel
	var player_id: int = GameManager.get_human_player_id()
	var owned_tiles: Array = []
	for tile in GameManager.tiles:
		if tile["owner_id"] == player_id:
			owned_tiles.append(tile)

	if owned_tiles.is_empty():
		return {"occurred": false, "tile_index": -1, "garrison": 0}

	var rebel_tile: Dictionary = owned_tiles[randi_range(0, owned_tiles.size() - 1)]
	var garrison: int = randi_range(10, 25)
	rebel_tile["owner_id"] = -1
	rebel_tile["garrison"] = garrison

	EventBus.message_log.emit("[color=red]叛乱爆发! %s 脱离控制，叛军驻守%d![/color]" % [rebel_tile["name"], garrison])
	EventBus.tile_lost.emit(player_id, rebel_tile["index"])
	change_order(-3)  # slave revolt penalty
	return {"occurred": true, "tile_index": rebel_tile["index"], "garrison": garrison}


# ═══════════════ ORDER CHANGE TRIGGERS ═══════════════

func on_tile_captured() -> void:
	change_order(3)

func on_building_constructed() -> void:
	change_order(2)

func on_tile_upgraded() -> void:
	change_order(2)

func on_faction_conquered() -> void:
	change_order(10)

func on_tile_lost() -> void:
	change_order(-5)

func on_slave_revolt() -> void:
	change_order(-3)


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"order": _order,
	}


func from_save_data(data: Dictionary) -> void:
	_order = data.get("order", 50)
