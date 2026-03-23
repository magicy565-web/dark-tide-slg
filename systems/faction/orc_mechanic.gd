## orc_mechanic.gd - WAAAGH! system and Orc-specific logic (design doc §3.1)
##
## Graduated WAAAGH! thresholds:
##   0-29:  No bonus
##   30-59: ATK+1 to all orc units
##   60-89: ATK+2, immune to morale collapse
##   90-100: WAAAGH! Explosion — ATK+4, first-round charge bonus, frenzy state
##
## WAAAGH! gain:  +5 per orc unit in combat, +10 per enemy squad destroyed
## WAAAGH! decay: -10 per non-combat turn
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── WAAAGH! state per player (only used by Orc faction) ──
var _waaagh: Dictionary = {}           # player_id -> int (0-100)
var _frenzy_turns: Dictionary = {}     # player_id -> int remaining frenzy turns
var _idle_turns: Dictionary = {}       # player_id -> int turns without combat
var _frenzy_count: int = 0


func _ready() -> void:
	pass


func reset() -> void:
	_waaagh.clear()
	_frenzy_turns.clear()
	_idle_turns.clear()
	_frenzy_count = 0


func init_player(player_id: int) -> void:
	_waaagh[player_id] = 0
	_frenzy_turns[player_id] = 0
	_idle_turns[player_id] = 0


func get_waaagh(player_id: int) -> int:
	return _waaagh.get(player_id, 0)


func is_in_frenzy(player_id: int) -> bool:
	return _frenzy_turns.get(player_id, 0) > 0


## Returns the WAAAGH! tier label string for UI display.
func get_waaagh_tier_name(player_id: int) -> String:
	var w: int = get_waaagh(player_id)
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	if w >= params["waaagh_tier_3_threshold"]:
		return "WAAAGH!爆发"
	elif w >= params["waaagh_tier_2_threshold"]:
		return "狂热"
	elif w >= params["waaagh_tier_1_threshold"]:
		return "亢奋"
	return "平静"


## Returns graduated ATK bonus from WAAAGH! thresholds (applied to all orc units).
func get_waaagh_atk_bonus(player_id: int) -> int:
	var w: int = get_waaagh(player_id)
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	if w >= params["waaagh_tier_3_threshold"]:
		return params["waaagh_tier_3_atk"]  # +4
	elif w >= params["waaagh_tier_2_threshold"]:
		return params["waaagh_tier_2_atk"]  # +2
	elif w >= params["waaagh_tier_1_threshold"]:
		return params["waaagh_tier_1_atk"]  # +1
	return 0


## Returns frenzy damage multiplier (2.0 during frenzy, else 1.0).
func get_damage_multiplier(player_id: int) -> float:
	if is_in_frenzy(player_id):
		return FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]["waaagh_frenzy_damage_mult"]
	return 1.0


# ═══════════════ TURN TICK ═══════════════

func tick(player_id: int, had_combat: bool) -> void:
	## Called at the START of each Orc player's turn.
	if not _waaagh.has(player_id):
		return

	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]

	# ── Totem Pole bonus ──
	var totem_bonus: int = 0
	for tile in GameManager.tiles:
		if tile["owner_id"] == player_id and tile.get("building_id", "") == "totem_pole":
			var lvl: int = tile.get("building_level", 1)
			var level_data: Dictionary = FactionData.BUILDING_LEVELS.get("totem_pole", {}).get(lvl, {})
			totem_bonus += level_data.get("waaagh_per_turn", 5)
	if totem_bonus > 0:
		_add_waaagh(player_id, totem_bonus)
		EventBus.message_log.emit("[color=red]图腾柱效果: WAAAGH! +%d[/color]" % totem_bonus)

	# ── T4 蛮牛酋长 aura: +15 WAAAGH!/turn (map_effect.waaagh_per_turn) ──
	var army: Array = RecruitManager.get_army(player_id)
	for troop in army:
		var aura: Dictionary = GameData.AURA_DEFS.get(troop.get("troop_id", ""), {})
		var map_eff: Dictionary = aura.get("map_effect", {})
		if map_eff.has("waaagh_per_turn"):
			var waaagh_gain: int = map_eff["waaagh_per_turn"]
			_add_waaagh(player_id, waaagh_gain)
			EventBus.message_log.emit("[color=red]蛮牛酋长光环: WAAAGH! +%d[/color]" % waaagh_gain)

	# ── Idle decay (doc: -10 per non-combat turn) ──
	if not had_combat:
		_idle_turns[player_id] = _idle_turns.get(player_id, 0) + 1
		var decay: int = params["waaagh_idle_decay"]
		_add_waaagh(player_id, -decay)
		EventBus.message_log.emit("无战斗回合, WAAAGH! -%d (当前: %d)" % [decay, _waaagh[player_id]])
	else:
		_idle_turns[player_id] = 0

	# ── Frenzy handling ──
	if _frenzy_turns.get(player_id, 0) > 0:
		_frenzy_turns[player_id] -= 1
		EventBus.message_log.emit("[color=red]WAAAGH! 狂暴中! 剩余%d回合 (伤害x%.1f)[/color]" % [
			_frenzy_turns[player_id], params["waaagh_frenzy_damage_mult"]])
		if _frenzy_turns[player_id] <= 0:
			_end_frenzy(player_id)
		return

	# ── Threshold check: 90+ triggers frenzy explosion ──
	if _waaagh[player_id] >= params["waaagh_tier_3_threshold"]:
		_start_frenzy(player_id)
	elif _waaagh[player_id] <= 0:
		_trigger_infighting(player_id)

	# ── Report graduated bonus ──
	var atk_bonus: int = get_waaagh_atk_bonus(player_id)
	if atk_bonus > 0:
		EventBus.message_log.emit("[color=red]WAAAGH! %s: 全军ATK+%d (当前: %d)[/color]" % [
			get_waaagh_tier_name(player_id), atk_bonus, _waaagh[player_id]])


# ═══════════════ COMBAT CALLBACK ═══════════════

## Called after combat. Gains WAAAGH! based on orc_unit_count and enemy_kills.
func on_combat_result(player_id: int, orc_unit_count: int, enemy_squads_destroyed: int) -> void:
	if not _waaagh.has(player_id):
		return
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	var unit_gain: int = orc_unit_count * params["waaagh_per_unit_in_combat"]
	var kill_gain: int = enemy_squads_destroyed * params["waaagh_per_kill"]
	var total: int = unit_gain + kill_gain
	_add_waaagh(player_id, total)
	EventBus.waaagh_changed.emit(player_id, _waaagh[player_id])
	EventBus.message_log.emit("[color=red]战斗! WAAAGH! +%d (%d兵×5 + %d击杀×10) 当前: %d[/color]" % [
		total, orc_unit_count, enemy_squads_destroyed, _waaagh[player_id]])


## Legacy: simple flat gain (for backward compat with non-detailed combat calls).
func on_combat_win(player_id: int) -> void:
	on_combat_result(player_id, 3, 1)  # Approximate: 3 units, 1 squad kill


# ═══════════════ WAR PIT ═══════════════

func convert_slave_to_army(player_id: int) -> bool:
	## War Pit: 1 slave -> 3 army.
	var slaves: int = ResourceManager.get_slaves(player_id)
	if slaves <= 0:
		EventBus.message_log.emit("没有奴隶可以转换!")
		return false
	ResourceManager.apply_delta(player_id, {"slaves": -1})
	SlaveManager.remove_slaves(player_id, 1)
	var gain: int = FactionData.UNIQUE_BUILDINGS[FactionData.FactionID.ORC]["war_pit"]["effect_value"]
	ResourceManager.add_army(player_id, gain)
	EventBus.message_log.emit("[color=red]战争深坑: 1奴隶 -> %d军队![/color]" % gain)
	return true


# ═══════════════ INTERNAL ═══════════════

func add_waaagh(player_id: int, amount: int) -> void:
	_waaagh[player_id] = clampi(_waaagh.get(player_id, 0) + amount, 0, 100)
	EventBus.waaagh_changed.emit(player_id, _waaagh[player_id])


func _add_waaagh(player_id: int, amount: int) -> void:
	_waaagh[player_id] = clampi(_waaagh.get(player_id, 0) + amount, 0, 100)


func get_frenzy_count() -> int:
	return _frenzy_count


func _start_frenzy(player_id: int) -> void:
	_frenzy_count += 1
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	_frenzy_turns[player_id] = params["waaagh_frenzy_turns"]
	EventBus.message_log.emit("[color=red]>>> WAAAGH! 狂暴爆发! %d回合内伤害x%.1f! <<<[/color]" % [
		params["waaagh_frenzy_turns"], params["waaagh_frenzy_damage_mult"]])


func _end_frenzy(player_id: int) -> void:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	var army: int = ResourceManager.get_army(player_id)
	var loss: int = ceili(float(army) * params["waaagh_frenzy_army_loss_pct"])
	if loss > 0:
		ResourceManager.remove_army(player_id, loss)
		EventBus.message_log.emit("[color=red]WAAAGH! 狂暴结束! 军队损失%d (疲劳)[/color]" % loss)
	_waaagh[player_id] = 0


func _trigger_infighting(player_id: int) -> void:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.ORC]
	var army: int = ResourceManager.get_army(player_id)
	var loss: int = ceili(float(army) * params["waaagh_zero_infighting_loss_pct"])
	if loss > 0:
		ResourceManager.remove_army(player_id, loss)
		EventBus.message_log.emit("[color=red]WAAAGH! 耗尽! 内讧导致%d军队损失![/color]" % loss)
	_waaagh[player_id] = 10  # Reset to small value to prevent infinite loop


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"waaagh": _waaagh.duplicate(),
		"frenzy_turns": _frenzy_turns.duplicate(),
		"idle_turns": _idle_turns.duplicate(),
		"frenzy_count": _frenzy_count,
	}


func from_save_data(data: Dictionary) -> void:
	_waaagh = data.get("waaagh", {}).duplicate()
	_frenzy_turns = data.get("frenzy_turns", {}).duplicate()
	_idle_turns = data.get("idle_turns", {}).duplicate()
	_frenzy_count = int(data.get("frenzy_count", 0))
