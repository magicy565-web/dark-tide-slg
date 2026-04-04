## resource_manager.gd - Central ledger for all player resources
## Autoload singleton. Other systems call apply_delta() to change resources.
extends Node

# ── Resource keys ──
const RES_GOLD := "gold"
const RES_FOOD := "food"
const RES_IRON := "iron"
const RES_SLAVES := "slaves"
const RES_PRESTIGE := "prestige"
const RES_MAGIC_CRYSTAL := "magic_crystal"
const RES_WAR_HORSE := "war_horse"
const RES_GUNPOWDER := "gunpowder"
const RES_SHADOW_ESSENCE := "shadow_essence"
const RES_MANA := "mana"
const RES_TRADE_GOODS := "trade_goods"
const RES_SOUL_CRYSTALS := "soul_crystals"
const RES_ARCANE_DUST := "arcane_dust"
const ALL_RESOURCES: Array = ["gold", "food", "iron", "slaves", "prestige", "magic_crystal", "war_horse", "gunpowder", "shadow_essence", "mana", "trade_goods", "soul_crystals", "arcane_dust"]

# ── Per-player ledgers  { player_id: { "gold": int, ... } } ──
var _ledgers: Dictionary = {}

# ── Army counts stored here for convenience ──
var _army: Dictionary = {}          # player_id -> int
var _slave_capacity: Dictionary = {} # player_id -> int (from Slave Pen buildings, etc.)


func _ready() -> void:
	pass


# ═══════════════ INIT ═══════════════

func init_player(player_id: int, starting: Dictionary) -> void:
	_ledgers[player_id] = {
		RES_GOLD: starting.get("gold", 0),
		RES_FOOD: starting.get("food", 0),
		RES_IRON: starting.get("iron", 0),
		RES_SLAVES: starting.get("slaves", 0),
		RES_PRESTIGE: starting.get("prestige", 0),
		RES_MAGIC_CRYSTAL: starting.get("magic_crystal", 0),
		RES_WAR_HORSE: starting.get("war_horse", 0),
		RES_GUNPOWDER: starting.get("gunpowder", 0),
		RES_SHADOW_ESSENCE: starting.get("shadow_essence", 0),
		RES_MANA: starting.get("mana", 0),
		RES_TRADE_GOODS: starting.get("trade_goods", 0),
		RES_SOUL_CRYSTALS: starting.get("soul_crystals", 0),
		RES_ARCANE_DUST: starting.get("arcane_dust", 0),
	}
	_army[player_id] = starting.get("army", 0)
	_slave_capacity[player_id] = starting.get("slaves", 0) + 3  # base capacity 3 + starting


func reset() -> void:
	_ledgers.clear()
	_army.clear()
	_slave_capacity.clear()


# ═══════════════ GETTERS ═══════════════

func get_resource(player_id: int, res_key: String) -> int:
	if not _ledgers.has(player_id):
		return 0
	return _ledgers[player_id].get(res_key, 0)


func get_all(player_id: int) -> Dictionary:
	if not _ledgers.has(player_id):
		return {}
	return _ledgers[player_id].duplicate()


func get_army(player_id: int) -> int:
	return _army.get(player_id, 0)


func get_slave_capacity(player_id: int) -> int:
	return _slave_capacity.get(player_id, 3)


# ═══════════════ MUTATIONS ═══════════════

func apply_delta(player_id: int, delta: Dictionary) -> void:
	## Apply a resource change dictionary. Negative values allowed.
	## Clamps each resource at 0 minimum.
	if not _ledgers.has(player_id):
		push_warning("ResourceManager: apply_delta called for unknown player_id=%d" % player_id)
		return
	var ledger: Dictionary = _ledgers[player_id]
	for key in delta:
		if ledger.has(key):
			ledger[key] = maxi(0, ledger[key] + delta[key])
	EventBus.resources_changed.emit(player_id)


func set_resource(player_id: int, res_key: String, value: int) -> void:
	if not _ledgers.has(player_id):
		push_warning("ResourceManager: set_resource called for unknown player_id=%d" % player_id)
		return
	_ledgers[player_id][res_key] = maxi(0, value)
	EventBus.resources_changed.emit(player_id)


func can_afford(player_id: int, cost: Dictionary) -> bool:
	if not _ledgers.has(player_id):
		return false
	var ledger: Dictionary = _ledgers[player_id]
	for key in cost:
		# Reject negative costs to prevent exploits (Bug fix Round 3)
		if cost[key] < 0:
			return false
		if ledger.get(key, 0) < cost[key]:
			return false
	return true


func spend(player_id: int, cost: Dictionary) -> bool:
	## Deduct cost if affordable, return success.
	if not can_afford(player_id, cost):
		return false
	var neg: Dictionary = {}
	for key in cost:
		# Skip zero-value costs to avoid needless delta entries (Bug fix Round 3)
		if cost[key] > 0:
			neg[key] = -cost[key]
	if neg.is_empty():
		return true
	apply_delta(player_id, neg)
	return true


## Alias for spend() — atomic check-and-deduct to prevent race conditions.
func try_spend(player_id: int, cost: Dictionary) -> bool:
	return spend(player_id, cost)


# ═══════════════ ARMY ═══════════════

func set_army(player_id: int, count: int) -> void:
	_army[player_id] = maxi(0, count)
	EventBus.army_changed.emit(player_id, _army[player_id])


func add_army(player_id: int, amount: int) -> void:
	set_army(player_id, get_army(player_id) + amount)


func remove_army(player_id: int, amount: int) -> void:
	set_army(player_id, maxi(0, get_army(player_id) - amount))


# ═══════════════ SLAVE CAPACITY ═══════════════

func add_slave_capacity(player_id: int, amount: int) -> void:
	_slave_capacity[player_id] = _slave_capacity.get(player_id, 3) + amount


func get_slaves(player_id: int) -> int:
	return get_resource(player_id, RES_SLAVES)


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"ledgers": _ledgers.duplicate(true),
		"army": _army.duplicate(true),
		"slave_capacity": _slave_capacity.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_ledgers = data.get("ledgers", {}).duplicate(true)
	_army = data.get("army", {}).duplicate(true)
	_slave_capacity = data.get("slave_capacity", {}).duplicate(true)
	# Fix int keys after JSON round-trip (keys become strings)
	for dict_ref in [_ledgers, _army, _slave_capacity]:
		var keys_to_fix: Array = []
		for k in dict_ref:
			if k is String and k.is_valid_int():
				keys_to_fix.append(k)
		for k in keys_to_fix:
			dict_ref[int(k)] = dict_ref[k]
			dict_ref.erase(k)
	# BUG FIX: Ensure all new strategic resource keys exist in old saves
	var new_res_keys: Array = ["trade_goods", "soul_crystals", "arcane_dust"]
	for pid in _ledgers:
		for rk in new_res_keys:
			if not _ledgers[pid].has(rk):
				_ledgers[pid][rk] = 0


# ═══════════════ MISSING METHOD STUBS (v5.3 audit) ═══════════════

## Called by environment_system — adds a random resource to a player.
func add_random_resource(player_id: int, qty: int) -> void:
	var resource_keys: Array = ["gold", "food", "iron"]
	var chosen: String = resource_keys[randi() % resource_keys.size()]
	apply_delta(player_id, {chosen: qty})
	EventBus.message_log.emit("获得随机资源: %s +%d" % [chosen, qty])


## Called by dynamic_situation_events — returns army size for a player.
func get_army_size(player_id: int) -> int:
	return get_army(player_id)
