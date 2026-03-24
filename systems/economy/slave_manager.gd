## slave_manager.gd - Manages slave allocation (especially for Dark Elf)
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Per-player slave allocation: { player_id: { "mine": int, "farm": int, "altar": int, "idle": int } } ──
var _allocations: Dictionary = {}
# ── Per-player efficiency multiplier (from Slave Pit building) ──
var _efficiency: Dictionary = {}
# ── Altar sacrifice counter (Dark Elf) ──
var _altar_counters: Dictionary = {}   # player_id -> turns since last sacrifice


func _ready() -> void:
	pass


func reset() -> void:
	_allocations.clear()
	_efficiency.clear()
	_altar_counters.clear()


func init_player(player_id: int, slave_count: int) -> void:
	_allocations[player_id] = {"mine": 0, "farm": 0, "altar": 0, "idle": slave_count}
	_efficiency[player_id] = 1.0
	_altar_counters[player_id] = 0


# ═══════════════ ALLOCATION ═══════════════

func get_allocation(player_id: int) -> Dictionary:
	return _allocations.get(player_id, {"mine": 0, "farm": 0, "altar": 0, "idle": 0}).duplicate()


func allocate_slave(player_id: int, role: String) -> bool:
	## Move one slave from idle to role ("mine", "farm", "altar").
	if not _allocations.has(player_id):
		return false
	var alloc: Dictionary = _allocations[player_id]
	if alloc["idle"] <= 0:
		return false
	if not alloc.has(role):
		return false
	alloc["idle"] -= 1
	alloc[role] += 1
	EventBus.message_log.emit("分配1名奴隶至 %s (剩余空闲: %d)" % [_role_name(role), alloc["idle"]])
	return true


func deallocate_slave(player_id: int, role: String) -> bool:
	## Move one slave from role back to idle.
	if not _allocations.has(player_id):
		return false
	var alloc: Dictionary = _allocations[player_id]
	if not alloc.has(role) or alloc[role] <= 0:
		return false
	alloc[role] -= 1
	alloc["idle"] += 1
	return true


func add_slaves(player_id: int, count: int) -> void:
	if not _allocations.has(player_id):
		init_player(player_id, count)
		return
	_allocations[player_id]["idle"] += count


func remove_slaves(player_id: int, count: int) -> void:
	## Remove from idle first, then from roles if needed.
	if not _allocations.has(player_id):
		push_warning("SlaveManager: remove_slaves called for unknown player_id=%d" % player_id)
		return
	var alloc: Dictionary = _allocations[player_id]
	var remaining: int = count
	# Remove idle first
	var from_idle: int = mini(alloc["idle"], remaining)
	alloc["idle"] -= from_idle
	remaining -= from_idle
	# Then from roles
	for role in ["mine", "farm", "altar"]:
		if remaining <= 0:
			break
		var from_role: int = mini(alloc.get(role, 0), remaining)
		alloc[role] = alloc.get(role, 0) - from_role
		remaining -= from_role


func get_total_slaves(player_id: int) -> int:
	if not _allocations.has(player_id):
		return 0
	var alloc: Dictionary = _allocations[player_id]
	return alloc["mine"] + alloc["farm"] + alloc["altar"] + alloc["idle"]


# ═══════════════ EFFICIENCY ═══════════════

func get_efficiency_mult(player_id: int) -> float:
	return _efficiency.get(player_id, 1.0)


func set_efficiency_mult(player_id: int, mult: float) -> void:
	_efficiency[player_id] = mult


# ═══════════════ ALTAR TICK (Dark Elf) ═══════════════

func tick_altar(player_id: int) -> Dictionary:
	## Called each turn for Dark Elf. Returns { "atk_bonus": int, "sacrificed": bool }.
	var result := {"atk_bonus": 0, "sacrificed": false, "shadow_essence": 0}
	if not _allocations.has(player_id):
		return result
	var alloc: Dictionary = _allocations[player_id]
	var altar_count: int = alloc.get("altar", 0)
	if altar_count <= 0:
		return result

	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.DARK_ELF]
	result["atk_bonus"] = altar_count * params["slave_altar_atk_per_slave"]

	# 03_战略设定: 祭品 1奴隶=2暗影精华=1法力
	result["shadow_essence"] = altar_count * 2

	# Sacrifice check
	_altar_counters[player_id] = _altar_counters.get(player_id, 0) + 1
	if _altar_counters[player_id] >= params["slave_altar_sacrifice_interval"]:
		_altar_counters[player_id] = 0
		if altar_count > 0:
			alloc["altar"] -= 1
			result["sacrificed"] = true
			EventBus.message_log.emit("[color=purple]祭坛献祭! 1名奴隶被献祭，获得2暗影精华[/color]")

	return result


# ═══════════════ HELPERS ═══════════════

# ── Slave Conversion (03_战略设定: 3奴隶=1士兵) ──
const SLAVES_PER_SOLDIER: int = 3

func convert_slaves_to_soldiers(player_id: int) -> bool:
	## Convert 3 idle slaves into 1 soldier.
	if not _allocations.has(player_id):
		return false
	var alloc: Dictionary = _allocations[player_id]
	if alloc["idle"] < SLAVES_PER_SOLDIER:
		EventBus.message_log.emit("奴隶不足! 需要 %d 名空闲奴隶" % SLAVES_PER_SOLDIER)
		return false
	alloc["idle"] -= SLAVES_PER_SOLDIER
	ResourceManager.apply_delta(player_id, {"slaves": -SLAVES_PER_SOLDIER})
	ResourceManager.add_army(player_id, 1)
	# Sync: ensure ResourceManager slave count matches allocation total
	sync_slave_count(player_id)
	EventBus.message_log.emit("[color=purple]奴隶转化: %d名奴隶 → 1名士兵[/color]" % SLAVES_PER_SOLDIER)
	return true


# ── Slave Capacity (03_战略设定: 5/节点×节点等级) ──
const SLAVE_CAP_PER_NODE_LEVEL: int = 5

func get_slave_capacity(player_id: int) -> int:
	## Returns max slave capacity based on owned nodes.
	var cap: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			var level: int = tile.get("level", 1)
			cap += SLAVE_CAP_PER_NODE_LEVEL * level
	return cap


func is_at_capacity(player_id: int) -> bool:
	return get_total_slaves(player_id) >= get_slave_capacity(player_id)


# ── Slave Production (03_战略设定: 劳工+0.5金/奴隶/节点) ──
func get_labor_income(player_id: int) -> Dictionary:
	## Returns per-turn income from slave labor allocations.
	var alloc: Dictionary = get_allocation(player_id)
	var eff: float = get_efficiency_mult(player_id)
	var params: Dictionary = FactionData.FACTION_PARAMS.get(FactionData.FactionID.DARK_ELF, {})
	return {
		"gold": float(alloc["mine"]) * 0.5 * eff,  # 03_战略设定: +0.5金/奴隶/节点
		"iron": float(alloc["mine"]) * float(params.get("slave_mine_iron_per_turn", 1)) * eff,
		"food": float(alloc["farm"]) * float(params.get("slave_farm_food_per_turn", 2)) * eff,
	}


# ── Slave Revolt Check (03_战略设定: 奴隶>驻军×3时 10%/回合) ──
func check_revolt(player_id: int) -> bool:
	var total_slaves: int = get_total_slaves(player_id)
	var total_garrison: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			total_garrison += tile.get("garrison", 0)
	if total_slaves > total_garrison * 3:
		if randf() < 0.10:
			var lost: int = maxi(1, total_slaves / 5)
			remove_slaves(player_id, lost)
			ResourceManager.apply_delta(player_id, {"slaves": -lost})
			EventBus.message_log.emit("[color=red]奴隶暴动! 损失 %d 名奴隶![/color]" % lost)
			return true
	return false

func _role_name(role: String) -> String:
	match role:
		"mine": return "矿场"
		"farm": return "农场"
		"altar": return "祭坛"
		_: return "空闲"


func sync_slave_count(player_id: int) -> void:
	## Sync allocation total with ResourceManager slave count.
	var rm_slaves: int = ResourceManager.get_slaves(player_id)
	var current_total: int = get_total_slaves(player_id)
	var diff: int = rm_slaves - current_total
	if diff > 0:
		add_slaves(player_id, diff)
	elif diff < 0:
		remove_slaves(player_id, -diff)


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"allocations": _allocations.duplicate(true),
		"efficiency": _efficiency.duplicate(true),
		"altar_counters": _altar_counters.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_allocations = data.get("allocations", {}).duplicate(true)
	_efficiency = data.get("efficiency", {}).duplicate(true)
	_altar_counters = data.get("altar_counters", {}).duplicate(true)
