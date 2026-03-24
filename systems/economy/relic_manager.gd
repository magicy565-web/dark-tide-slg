extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## relic_manager.gd - Permanent relic system (v0.7)

# Per-player relic state: { player_id: { "relic_id": String, "upgraded": bool } }
var _player_relics: Dictionary = {}

func reset() -> void:
	_player_relics.clear()

func init_player(player_id: int) -> void:
	_player_relics[player_id] = {"relic_id": "", "upgraded": false}

func generate_relic_choices() -> Array:
	## Returns 3 random relic IDs for game-start selection.
	var all_ids: Array = FactionData.RELIC_DEFS.keys()
	all_ids.shuffle()
	return all_ids.slice(0, 3)

func select_relic(player_id: int, relic_id: String) -> bool:
	## Player selects their starting relic.
	if not FactionData.RELIC_DEFS.has(relic_id):
		return false
	if not _player_relics.has(player_id):
		init_player(player_id)
	_player_relics[player_id]["relic_id"] = relic_id
	var relic: Dictionary = FactionData.RELIC_DEFS[relic_id]
	EventBus.message_log.emit("选择遗物: %s - %s" % [relic["name"], relic["desc"]])
	EventBus.relic_selected.emit(player_id, relic_id)
	return true

func get_relic(player_id: int) -> Dictionary:
	## Returns current relic data with upgrade status.
	if not _player_relics.has(player_id) or _player_relics[player_id]["relic_id"] == "":
		return {}
	var relic_id: String = _player_relics[player_id]["relic_id"]
	var relic_def = FactionData.RELIC_DEFS.get(relic_id, null)
	if relic_def == null:
		return {}
	var base: Dictionary = relic_def.duplicate()
	base["upgraded"] = _player_relics[player_id]["upgraded"]
	return base

func upgrade_relic(player_id: int) -> bool:
	## Upgrade relic using shadow essence (cost: 5). Doubles effect.
	if not _player_relics.has(player_id) or _player_relics[player_id]["relic_id"] == "":
		return false
	if _player_relics[player_id]["upgraded"]:
		EventBus.message_log.emit("遗物已经升级过了!")
		return false
	var cost: Dictionary = {"shadow_essence": 5}
	if not ResourceManager.can_afford(player_id, cost):
		EventBus.message_log.emit("暗影精华不足!")
		return false
	ResourceManager.spend(player_id, cost)
	_player_relics[player_id]["upgraded"] = true
	var relic: Dictionary = FactionData.RELIC_DEFS[_player_relics[player_id]["relic_id"]]
	EventBus.message_log.emit("[color=purple]遗物升级: %s 效果翻倍![/color]" % relic["name"])
	return true

func get_relic_effect(player_id: int, effect_key: String) -> Variant:
	## Get the effective value of a relic bonus. Accounts for upgrade doubling.
	var relic: Dictionary = get_relic(player_id)
	if relic.is_empty():
		return null
	var effects: Dictionary = relic.get("effect", {})
	if not effects.has(effect_key):
		return null
	var value = effects[effect_key]
	if relic.get("upgraded", false):
		if value is float:
			# For multipliers, double the bonus/penalty portion:
			# Buffs:   1.2 -> 1.4 (bonus 0.2 doubled to 0.4)
			# Debuffs: 0.8 -> 0.6 (penalty 0.2 doubled to 0.4, subtracted)
			if value > 1.0:
				value = 1.0 + (value - 1.0) * 2.0
			elif value < 1.0:
				value = 1.0 + (value - 1.0) * 2.0
		elif value is int:
			value = value * 2
		elif value is bool:
			pass  # Bool stays true
	return value

# Convenience getters for common relic effects
func get_gold_income_mult(player_id: int) -> float:
	var v = get_relic_effect(player_id, "gold_income_mult")
	return v if v != null else 1.0

func get_recruit_cost_mult(player_id: int) -> float:
	var v = get_relic_effect(player_id, "recruit_cost_mult")
	return v if v != null else 1.0

func get_victory_slave_bonus(player_id: int) -> int:
	var v = get_relic_effect(player_id, "victory_slave_bonus")
	return v if v != null else 0

func get_faction_resource_mult(player_id: int) -> float:
	var v = get_relic_effect(player_id, "faction_resource_mult")
	return v if v != null else 1.0

func get_negative_event_mult(player_id: int) -> float:
	var v = get_relic_effect(player_id, "negative_event_mult")
	return v if v != null else 1.0

func has_first_hit_immune(player_id: int) -> bool:
	var v = get_relic_effect(player_id, "first_hit_immune")
	return v == true

func has_relic(player_id: int) -> bool:
	return _player_relics.has(player_id) and _player_relics[player_id]["relic_id"] != ""


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"player_relics": _player_relics.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_player_relics = data.get("player_relics", {}).duplicate(true)
