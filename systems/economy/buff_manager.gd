## BuffManager - Temporary buff management system for 暗潮 SLG
##
## Autoload singleton that tracks and expires temporary effects applied by
## events, items, and abilities. Each buff has a type, value, duration in turns,
## and a source tag for removal/filtering.
##
## Buff types:
##   atk_mult           - multiplier on attack (e.g. 1.15 = +15%)
##   def_mult           - multiplier on defense
##   siege_mult         - multiplier on siege/wall damage
##   dice_bonus         - flat bonus added to dice roll
##   production_mult    - multiplier on all production (e.g. 0.8 = -20%)
##   no_move            - prevents movement this turn (bool)
##   temp_army          - temporary army units removed on expiry
##   wall_damage        - flat bonus wall damage per turn (additive)
##   army_per_turn      - army units lost per turn (additive debuff)
##   mage_weaken        - weakens enemy mage abilities (bool)
##   guaranteed_slave   - next combat guarantees slave capture (consumed on use)
##   first_hit_immune   - first attack immunity from relic (consumed on use)
extends Node

## { player_id (int) : Array[Dictionary] }
## Each dictionary: { "id": String, "type": String, "value": Variant,
##                     "turns_remaining": int, "source": String }
var _active_buffs: Dictionary = {}


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	reset()


func reset() -> void:
	_active_buffs.clear()


# ---------------------------------------------------------------------------
# Core API
# ---------------------------------------------------------------------------

## Adds a new buff to the given player. Emits EventBus.temporary_buff_applied.
##
## Full form (timed buff):
##   add_buff(player_id, buff_id, buff_type, value, duration, source)
##
## Short form (permanent / research-style key-value entry):
##   add_buff(player_id, buff_id, value)
##   When called with 3 args the buff_type is set to buff_id, duration to -1
##   (permanent), and source to "research".

## 每种类型最多允许的乘算buff数量上限
const MAX_MULT_BUFFS_PER_TYPE: int = 5

func add_buff(player_id: int, buff_id: String, buff_type_or_value = null, value = null, duration: int = -1, source: String = "") -> void:
	# Detect short-form call: add_buff(player_id, buff_id, value)
	# In the short form, buff_type_or_value IS the value and the remaining
	# positional args (value, duration, source) keep their defaults.
	var actual_type: String
	var actual_value
	var actual_duration: int
	var actual_source: String

	if value == null and duration == -1:
		# Short form: 3 args — (player_id, buff_id, value)
		actual_type = buff_id
		actual_value = buff_type_or_value
		actual_duration = -1
		actual_source = "research"
	else:
		# Full form: 5-6 args — (player_id, buff_id, buff_type, value, duration[, source])
		actual_type = str(buff_type_or_value)
		actual_value = value
		actual_duration = duration
		actual_source = source

	if not _active_buffs.has(player_id):
		_active_buffs[player_id] = []

	# ── 去重：相同 source+type 的buff更新而非叠加 ──
	var existing_idx: int = -1
	for idx in _active_buffs[player_id].size():
		var b: Dictionary = _active_buffs[player_id][idx]
		if b["source"] == actual_source and b["type"] == actual_type:
			# 永久buff(duration=-1)每个source只允许一个
			if actual_duration == -1 and b["turns_remaining"] == -1:
				existing_idx = idx
				break
			# 相同source+type的有时限buff也更新已有条目
			if b["turns_remaining"] != -1 and actual_duration != -1:
				existing_idx = idx
				break

	if existing_idx >= 0:
		# 更新已有buff而非新增
		var existing_buff: Dictionary = _active_buffs[player_id][existing_idx]
		existing_buff["id"] = buff_id
		existing_buff["value"] = actual_value
		existing_buff["turns_remaining"] = actual_duration
		EventBus.temporary_buff_applied.emit(player_id, buff_id, actual_duration)
		return

	# ── 乘算buff数量上限检查 ──
	if actual_type in ["atk_mult", "def_mult", "production_mult", "siege_mult"]:
		var count: int = 0
		for b in _active_buffs[player_id]:
			if b["type"] == actual_type:
				count += 1
		if count >= MAX_MULT_BUFFS_PER_TYPE:
			push_warning("BuffManager: 类型 %s 的乘算buff已达上限(%d)，跳过添加" % [actual_type, MAX_MULT_BUFFS_PER_TYPE])
			return

	var buff := {
		"id": buff_id,
		"type": actual_type,
		"value": actual_value,
		"turns_remaining": actual_duration,
		"source": actual_source,
	}
	_active_buffs[player_id].append(buff)
	EventBus.temporary_buff_applied.emit(player_id, buff["id"], buff["turns_remaining"])


## Called once per turn for a player. Decrements remaining turns on every buff
## and removes any that have expired. Handles side-effects for special types
## (e.g. temp_army removal).
func tick_buffs(player_id: int) -> void:
	if not _active_buffs.has(player_id):
		return

	var buffs: Array = _active_buffs[player_id]
	var i := buffs.size() - 1
	while i >= 0:
		# 防止外部修改导致索引越界
		if i >= buffs.size():
			i = buffs.size() - 1
			continue
		# Per-turn effects
		if buffs[i]["type"] == "army_per_turn":
			var loss: int = int(buffs[i]["value"])
			if loss > 0:
				ResourceManager.remove_army(player_id, loss)
				EventBus.message_log.emit("[color=red]军队受debuff影响,损失%d兵力[/color]" % loss)

		# 永久buff(turns_remaining=-1)不递减、不过期
		if buffs[i]["turns_remaining"] == -1:
			i -= 1
			continue

		buffs[i]["turns_remaining"] -= 1
		# 修复off-by-one：用 <= 0 而非 == 0，确保duration=1只持续1回合
		if buffs[i]["turns_remaining"] <= 0:
			_on_buff_expired(player_id, buffs[i])
			buffs.remove_at(i)
		i -= 1


# ---------------------------------------------------------------------------
# Aggregated getters
# ---------------------------------------------------------------------------

## Returns an aggregated value for the given buff type.
## - Multiplicative types (atk_mult, def_mult, production_mult): returns the
##   product of all matching buff values (1.0 when none).
## - Additive types (dice_bonus, temp_army): returns the sum (0 when none).
## - Boolean types (no_move, guaranteed_slave, first_hit_immune): returns true
##   if at least one matching buff exists.
## - Falls back to null when no buffs match and the type is unrecognised.
func get_buff_value(player_id: int, buff_type: String, default_value = null) -> Variant:
	var buffs := _get_buffs_of_type(player_id, buff_type)

	# If a default was explicitly provided and there are no matching buffs,
	# return the caller's default immediately.  This supports the research
	# manager's key-value lookup pattern (e.g. get_buff_value(pid, key, 0)).
	if buffs.is_empty() and default_value != null:
		return default_value

	match buff_type:
		"atk_mult", "def_mult", "production_mult", "siege_mult":
			if buffs.is_empty():
				return 1.0
			var product := 1.0
			for b in buffs:
				product *= float(b["value"])
			# 防止乘积溢出或变为负数/零：下限0.1(10%)，上限5.0(500%)
			product = clampf(product, 0.1, 5.0)
			return product
		"income_pct", "atk_pct":
			# Additive percentage: sum all values (e.g. -20 + -10 = -30%)
			var total := 0.0
			for b in buffs:
				# 跳过空值，避免类型转换错误
				if b["value"] == null:
					continue
				total += float(b["value"])
			return total
		"dice_bonus", "temp_army", "wall_damage", "army_per_turn", "gold_per_turn":
			var total := 0
			for b in buffs:
				total += int(b["value"])
			return total
		"no_move", "guaranteed_slave", "first_hit_immune", "mage_weaken", "instant_build":
			return buffs.size() > 0
		"research_speed":
			# Multiplicative stacking for research speed multiplier
			if buffs.is_empty():
				return 1.0
			var rs_product := 1.0
			for b in buffs:
				rs_product *= float(b["value"])
			return clampf(rs_product, 1.0, 5.0)

	# Unknown type -- for single-entry key-value lookups (research buffs),
	# return the raw value of the last matching buff, or the caller's default.
	if not buffs.is_empty():
		return buffs[-1]["value"]
	if default_value != null:
		return default_value
	return null


func get_atk_multiplier(player_id: int) -> float:
	var raw_mult = get_buff_value(player_id, "atk_mult")
	var mult: float = raw_mult as float if raw_mult != null else 1.0
	# v0.8.7: Also apply atk_pct additive bonuses (e.g. blood_ritual: +15%)
	var raw_pct = get_buff_value(player_id, "atk_pct")
	var atk_pct: float = raw_pct as float if raw_pct != null else 0.0
	if atk_pct != 0.0:
		mult *= (1.0 + atk_pct / 100.0)
	# v7.0: Empire Decree combat buff (+15% combat power for 3 turns)
	var raw_decree = get_buff_value(player_id, "empire_decree_combat")
	var decree_bonus: float = raw_decree as float if raw_decree != null else 0.0
	if decree_bonus > 0.0:
		mult *= (1.0 + decree_bonus)
	return clampf(mult, 0.1, 5.0)


func get_def_multiplier(player_id: int) -> float:
	var raw = get_buff_value(player_id, "def_mult")
	var result: float = raw as float if raw != null else 1.0
	return clampf(result, 0.1, 5.0)


func get_dice_bonus(player_id: int) -> int:
	return get_buff_value(player_id, "dice_bonus") as int


func get_production_multiplier(player_id: int) -> float:
	var raw = get_buff_value(player_id, "production_mult")
	var result: float = raw as float if raw != null else 1.0
	return clampf(result, 0.1, 5.0)


func is_move_blocked(player_id: int) -> bool:
	return get_buff_value(player_id, "no_move") as bool


func has_guaranteed_slave(player_id: int) -> bool:
	return get_buff_value(player_id, "guaranteed_slave") as bool


# ---------------------------------------------------------------------------
# One-use / consumable buffs
# ---------------------------------------------------------------------------

## Removes the first buff of the given type for the player. Returns true if a
## buff was consumed, false if none existed.
func consume_buff(player_id: int, buff_type: String) -> bool:
	if not _active_buffs.has(player_id):
		return false

	var buffs: Array = _active_buffs[player_id]
	for i in buffs.size():
		if buffs[i]["type"] == buff_type:
			_on_buff_expired(player_id, buffs[i])
			buffs.remove_at(i)
			return true
	return false


# ---------------------------------------------------------------------------
# Query / UI helpers
# ---------------------------------------------------------------------------

## Returns a shallow copy of the active buff array for the player (safe for UI
## iteration).
func get_active_buffs(player_id: int) -> Array:
	if not _active_buffs.has(player_id):
		return []
	return _active_buffs[player_id].duplicate()


## Returns true if a buff with the given id exists for the player.
func has_buff(player_id: int, buff_id: String) -> bool:
	if not _active_buffs.has(player_id):
		return false
	for b in _active_buffs[player_id]:
		if b["id"] == buff_id:
			return true
	return false


## Removes all buffs originating from the given source string.
func remove_buffs_by_source(player_id: int, source: String) -> void:
	if not _active_buffs.has(player_id):
		return

	var buffs: Array = _active_buffs[player_id]
	var i := buffs.size() - 1
	while i >= 0:
		if buffs[i]["source"] == source:
			_on_buff_expired(player_id, buffs[i])
			buffs.remove_at(i)
		i -= 1


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## Handles side-effects when a buff is removed (expiry, consumption, or source
## removal). Emits the expired signal and performs type-specific cleanup.
func _on_buff_expired(player_id: int, buff: Dictionary) -> void:
	# Special handling: temp_army units must be removed from the player's army.
	if buff["type"] == "temp_army":
		ResourceManager.remove_army(player_id, buff["value"])

	EventBus.temporary_buff_expired.emit(player_id, buff["id"])


## Returns all active buff dictionaries of a specific type for a player.
func _get_buffs_of_type(player_id: int, buff_type: String) -> Array:
	if not _active_buffs.has(player_id):
		return []

	var result: Array = []
	for b in _active_buffs[player_id]:
		if b["type"] == buff_type:
			result.append(b)
	return result


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"active_buffs": _active_buffs.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_active_buffs = data.get("active_buffs", {}).duplicate(true)
	# Fix int keys after JSON round-trip (player_id keys become strings)
	var keys_to_fix: Array = []
	for k in _active_buffs:
		if k is String and k.is_valid_int():
			keys_to_fix.append(k)
	for k in keys_to_fix:
		_active_buffs[int(k)] = _active_buffs[k]
		_active_buffs.erase(k)


# ═══════════════ MISSING METHOD STUBS (v5.3 audit) ═══════════════

## Called by game_manager — alias for add_buff with dict-style value.
## BUG FIX: 原实现将 value_dict 作为 buff_type 传入，value=null，
## 导致 buff 以 value=null 存储，后续 float()/int() 转换崩溃。
## 修复：将 value_dict 作为 actual_value，buff_type 设为 buff_id。
func apply_buff(player_id: int, buff_id: String, value_dict: Dictionary, duration: int = -1) -> void:
	# apply_buff(pid, "sat_morale", {"morale_boost": 10}, 3)
	# → add_buff(pid, "sat_morale", buff_type="sat_morale", value=value_dict, duration)
	add_buff(player_id, buff_id, buff_id, value_dict, duration, "apply_buff")
