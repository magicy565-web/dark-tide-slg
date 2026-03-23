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
		# Per-turn effects
		if buffs[i]["type"] == "army_per_turn":
			var loss: int = int(buffs[i]["value"])
			if loss > 0:
				ResourceManager.remove_army(player_id, loss)
				EventBus.message_log.emit("[color=red]军队受debuff影响,损失%d兵力[/color]" % loss)

		buffs[i]["turns_remaining"] -= 1
		if buffs[i]["turns_remaining"] == 0:
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
			var product := 1.0
			for b in buffs:
				product *= float(b["value"])
			return product
		"income_pct", "atk_pct":
			# Additive percentage: sum all values (e.g. -20 + -10 = -30%)
			var total := 0.0
			for b in buffs:
				total += float(b["value"])
			return total
		"dice_bonus", "temp_army", "wall_damage", "army_per_turn":
			var total := 0
			for b in buffs:
				total += int(b["value"])
			return total
		"no_move", "guaranteed_slave", "first_hit_immune", "mage_weaken":
			return buffs.size() > 0

	# Unknown type -- for single-entry key-value lookups (research buffs),
	# return the raw value of the last matching buff, or the caller's default.
	if not buffs.is_empty():
		return buffs[-1]["value"]
	if default_value != null:
		return default_value
	return null


func get_atk_multiplier(player_id: int) -> float:
	var mult: float = get_buff_value(player_id, "atk_mult") as float
	# v0.8.7: Also apply atk_pct additive bonuses (e.g. blood_ritual: +15%)
	var atk_pct: float = get_buff_value(player_id, "atk_pct") as float
	if atk_pct != 0.0:
		mult *= (1.0 + atk_pct / 100.0)
	return mult


func get_def_multiplier(player_id: int) -> float:
	return get_buff_value(player_id, "def_mult") as float


func get_dice_bonus(player_id: int) -> int:
	return get_buff_value(player_id, "dice_bonus") as int


func get_production_multiplier(player_id: int) -> float:
	return get_buff_value(player_id, "production_mult") as float


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
