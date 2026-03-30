## order_manager.gd - Tracks Order value (-100 to +100, start 50)
extends Node

var _order: int = 50
# 叛乱冷却计数器：防止叛乱死亡螺旋，每次叛乱后需等待N回合
var _rebellion_cooldown: int = 0
const REBELLION_COOLDOWN_TURNS: int = 3  # 叛乱冷却回合数

func _ready() -> void:
	pass


func reset() -> void:
	_order = 50
	_rebellion_cooldown = 0


func get_order() -> int:
	return _order


func change_order(delta: int) -> void:
	var old: int = _order
	_order = clampi(_order + delta, BalanceConfig.ORDER_MIN, BalanceConfig.ORDER_MAX)
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
	# v2.0: deterministic rebellion below threshold
	if _order <= BalanceConfig.ORDER_REBELLION_THRESHOLD:
		return 1.0  # guaranteed rebellion
	return 0.0


func try_rebellion() -> Dictionary:
	if _order > BalanceConfig.ORDER_REBELLION_THRESHOLD:
		return {"rebelled": false}
	# 叛乱冷却检查：防止连续叛乱造成死亡螺旋
	if _rebellion_cooldown > 0:
		return {"rebelled": false}
	var strength := int(BalanceConfig.REBELLION_GARRISON_STRENGTH * abs(_order) / 100.0)

	# Pick a random player-owned tile to rebel
	var player_id: int = GameManager.get_human_player_id()
	var owned_tiles: Array = []
	for tile in GameManager.tiles:
		# BUG FIX R18: null check on tile from GameManager.tiles
		if tile != null and tile.get("owner_id", -1) == player_id:
			owned_tiles.append(tile)

	if owned_tiles.is_empty():
		return {"rebelled": false}

	var rebel_tile: Dictionary = owned_tiles[randi() % owned_tiles.size()]
	var garrison: int = maxi(1, strength)
	rebel_tile["owner_id"] = -1
	rebel_tile["garrison"] = garrison

	# BUG FIX R18: use .get() for safety on rebel_tile fields
	var rebel_name: String = rebel_tile.get("name", "未知领地")
	var rebel_index: int = rebel_tile.get("index", -1)
	EventBus.message_log.emit("[color=red]叛乱爆发! %s 脱离控制，叛军驻守%d![/color]" % [rebel_name, garrison])
	EventBus.tile_lost.emit(player_id, rebel_index)
	EventBus.rebellion_occurred.emit(rebel_index)
	# 秩序惩罚，但限制最低值为ORDER_MIN防止无限螺旋
	var new_order: int = maxi(_order - 3, BalanceConfig.ORDER_MIN)
	var penalty: int = new_order - _order
	if penalty != 0:
		change_order(penalty)
	# 设置叛乱冷却
	_rebellion_cooldown = REBELLION_COOLDOWN_TURNS
	return {"rebelled": true, "strength": maxi(1, strength), "tile_index": rebel_index, "garrison": garrison}


# ═══════════════ TURN TICK (self-correcting drift) ═══════════════

func tick_turn() -> void:
	# 每回合递减叛乱冷却
	if _rebellion_cooldown > 0:
		_rebellion_cooldown -= 1
	if _order > 50:
		change_order(BalanceConfig.ORDER_DRIFT_HIGH)
	elif _order < -10:
		change_order(BalanceConfig.ORDER_DRIFT_LOW)


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
		"rebellion_cooldown": _rebellion_cooldown,
	}


func from_save_data(data: Dictionary) -> void:
	_order = int(data.get("order", 50))
	_rebellion_cooldown = int(data.get("rebellion_cooldown", 0))
