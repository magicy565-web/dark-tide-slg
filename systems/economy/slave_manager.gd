## slave_manager.gd - Manages slave allocation (especially for Dark Elf)
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Per-player slave allocation: { player_id: { "mine": int, "farm": int, "altar": int, "idle": int } } ──
var _allocations: Dictionary = {}
# ── Per-player efficiency multiplier (from Slave Pit building) ──
var _efficiency: Dictionary = {}
# ── Altar sacrifice counter (Dark Elf) ──
var _altar_counters: Dictionary = {}   # player_id -> turns since last sacrifice
# ── 防止sync_slave_count递归调用 ──
var _syncing: bool = false
# ── Conversion queue (Dark Elf): { player_id: [{ "count": int, "turns_left": int }] } ──
var _conversion_queue: Dictionary = {}


func _ready() -> void:
	pass


func reset() -> void:
	_allocations.clear()
	_efficiency.clear()
	_altar_counters.clear()
	_conversion_queue.clear()


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
	if count <= 0:
		return
	if not _allocations.has(player_id):
		init_player(player_id, count)
		if not _syncing:
			sync_slave_count(player_id)
		return
	_allocations[player_id]["idle"] += count
	# 每次增加奴隶后同步ResourceManager（防止递归）
	if not _syncing:
		sync_slave_count(player_id)


func remove_slaves(player_id: int, count: int) -> void:
	## Remove from idle first, then from roles if needed.
	if count <= 0:
		return
	if not _allocations.has(player_id):
		push_warning("SlaveManager: remove_slaves called for unknown player_id=%d" % player_id)
		return
	var alloc: Dictionary = _allocations[player_id]
	# Clamp to total available slaves to prevent negative counts
	var total: int = alloc["idle"] + alloc["mine"] + alloc["farm"] + alloc["altar"]
	var actual_remove: int = mini(count, total)
	if actual_remove <= 0:
		return
	var remaining: int = actual_remove
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
	# 每次移除奴隶后同步ResourceManager（防止递归）
	if not _syncing:
		sync_slave_count(player_id)


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

	# BUG FIX: only apply altar mechanics for Dark Elf faction
	if GameManager.get_player_faction(player_id) != FactionData.FactionID.DARK_ELF:
		return result
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.DARK_ELF]
	var altar_mult: float = StrategicResourceManager.get_altar_multiplier(player_id)
	result["atk_bonus"] = int(altar_count * params["slave_altar_atk_per_slave"] * altar_mult)

	# 03_战略设定: 祭品 1奴隶=2暗影精华=1法力
	result["shadow_essence"] = int(altar_count * 2 * altar_mult)

	# Sacrifice check
	_altar_counters[player_id] = _altar_counters.get(player_id, 0) + 1
	if _altar_counters[player_id] >= params["slave_altar_sacrifice_interval"]:
		_altar_counters[player_id] = 0
		if altar_count > 0:
			alloc["altar"] -= 1
			result["sacrificed"] = true
			# 献祭后同步奴隶计数
			sync_slave_count(player_id)
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
	# BUG FIX: 不再手动调用 apply_delta({slaves:-3})，改用 sync_slave_count 统一对齐
	# 原代码同时手动减 alloc["idle"] 又调用 apply_delta，下次 sync 会再次从 alloc 移除
	# 3 名奴隶（三重扣减）。现在只修改 alloc，让 sync 负责更新 ResourceManager。
	sync_slave_count(player_id)
	ResourceManager.add_army(player_id, 1)
	EventBus.message_log.emit("[color=purple]奴隶转化: %d名奴隶 → 1名士兵[/color]" % SLAVES_PER_SOLDIER)
	return true


# ── Slave Capacity (03_战略设定: use BalanceConfig for canonical value) ──

func get_slave_capacity(player_id: int) -> int:
	## Returns max slave capacity based on owned nodes.
	var cap: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			var level: int = tile.get("level", 1)
			cap += BalanceConfig.SLAVE_CAPACITY_PER_NODE_LEVEL * level
	return cap


func is_at_capacity(player_id: int) -> bool:
	return get_total_slaves(player_id) >= get_slave_capacity(player_id)


# ── Slave Production (03_战略设定: 劳工+0.5金/奴隶/节点) ──
func get_labor_income(player_id: int) -> Dictionary:
	## Returns per-turn income from slave labor allocations.
	var alloc: Dictionary = get_allocation(player_id)
	var eff: float = get_efficiency_mult(player_id)
	var faction_id: int = GameManager.get_player_faction(player_id) if GameManager else FactionData.FactionID.DARK_ELF
	var params: Dictionary = FactionData.FACTION_PARAMS.get(faction_id, {})
	# BUG FIX R12: return ints, not floats — ResourceManager expects integer values
	return {
		"gold": int(float(alloc["mine"]) * 0.5 * eff),
		"iron": int(float(alloc["mine"]) * float(params.get("slave_mine_iron_per_turn", 1)) * eff),
		"food": int(float(alloc["farm"]) * float(params.get("slave_farm_food_per_turn", 2)) * eff),
	}


# ── Slave Revolt Check (03_战略设定: 奴隶>驻军×3时 10%/回合) ──
# 暴动优先移除空闲奴隶，不足时按 矿场→农场→祭坛 顺序移除分配奴隶
func check_revolt(player_id: int) -> bool:
	var total_slaves: int = get_total_slaves(player_id)
	var total_garrison: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			total_garrison += tile.get("garrison", 0)
	if total_slaves > total_garrison * 3:
		if randf() < 0.10:
			@warning_ignore("integer_division")
			var lost: int = maxi(1, total_slaves / 5)
			if not _allocations.has(player_id):
				return false
			var alloc: Dictionary = _allocations[player_id]
			var remaining: int = lost
			# 优先移除空闲奴隶
			var from_idle: int = mini(alloc["idle"], remaining)
			alloc["idle"] -= from_idle
			remaining -= from_idle
			# 不足时按优先级移除：矿场 > 农场 > 祭坛（祭坛最后）
			for role in ["mine", "farm", "altar"]:
				if remaining <= 0:
					break
				var from_role: int = mini(alloc.get(role, 0), remaining)
				alloc[role] -= from_role
				remaining -= from_role
			# 暴动后同步奴隶计数（alloc已手动调整，sync会reconcile ResourceManager）
			sync_slave_count(player_id)
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
	if _syncing:
		return
	_syncing = true
	var rm_slaves: int = ResourceManager.get_slaves(player_id)
	var current_total: int = get_total_slaves(player_id)
	var diff: int = rm_slaves - current_total
	if diff > 0:
		add_slaves(player_id, diff)
	elif diff < 0:
		remove_slaves(player_id, -diff)
	_syncing = false


# ═══════════════ CONVERSION QUEUE (Dark Elf) ═══════════════

func queue_conversion(player_id: int, count: int, turns: int) -> void:
	## Queue captured slaves for troop conversion over N turns.
	if not _conversion_queue.has(player_id):
		_conversion_queue[player_id] = []
	_conversion_queue[player_id].append({"count": count, "turns_left": turns})
	EventBus.message_log.emit("[color=purple]%d名俘虏进入转化队列 (%d回合后完成)[/color]" % [count, turns])


func tick_conversion(player_id: int) -> int:
	## Called each turn for Dark Elf. Decrements conversion timers and returns total soldiers produced.
	if not _conversion_queue.has(player_id):
		return 0
	var queue: Array = _conversion_queue[player_id]
	var total_soldiers: int = 0
	var i: int = queue.size() - 1
	while i >= 0:
		queue[i]["turns_left"] -= 1
		if queue[i]["turns_left"] <= 0:
			var count: int = queue[i]["count"]
			var soldiers: int = count / SLAVES_PER_SOLDIER
			if soldiers > 0:
				total_soldiers += soldiers
				EventBus.message_log.emit("[color=purple]奴隶转化完成: %d名奴隶 → %d名士兵[/color]" % [count, soldiers])
			else:
				EventBus.message_log.emit("[color=gray]奴隶转化失败: %d名奴隶不足以转化为士兵[/color]" % count)
			queue.remove_at(i)
		i -= 1
	return total_soldiers


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"allocations": _allocations.duplicate(true),
		"efficiency": _efficiency.duplicate(true),
		"altar_counters": _altar_counters.duplicate(true),
		"conversion_queue": _conversion_queue.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_allocations = data.get("allocations", {}).duplicate(true)
	_efficiency = data.get("efficiency", {}).duplicate(true)
	_altar_counters = data.get("altar_counters", {}).duplicate(true)
	_conversion_queue = data.get("conversion_queue", {}).duplicate(true)
	# Fix int keys after JSON round-trip
	for dict_ref in [_allocations, _efficiency, _altar_counters, _conversion_queue]:
		var keys_to_fix: Array = []
		for k in dict_ref:
			if k is String and k.is_valid_int():
				keys_to_fix.append(k)
		for k in keys_to_fix:
			dict_ref[int(k)] = dict_ref[k]
			dict_ref.erase(k)
	# Fix allocation role int values after JSON round-trip
	for pid in _allocations:
		if _allocations[pid] is Dictionary:
			for role in ["mine", "farm", "altar", "idle"]:
				if _allocations[pid].has(role):
					_allocations[pid][role] = int(_allocations[pid][role])
	# Fix altar_counters int values after JSON round-trip
	for pid in _altar_counters:
		_altar_counters[pid] = int(_altar_counters[pid])
	# Fix conversion_queue int values after JSON round-trip
	for pid in _conversion_queue:
		if _conversion_queue[pid] is Array:
			for entry in _conversion_queue[pid]:
				if entry is Dictionary:
					if entry.has("count"):
						entry["count"] = int(entry["count"])
					if entry.has("turns_left"):
						entry["turns_left"] = int(entry["turns_left"])
