## threat_manager.gd - Tracks Threat value (0-100, start 0)
extends Node

var _threat: int = 0
var _expedition_timer: int = 0   # turns since last expedition
var _boss_timer: int = 0         # turns since last boss

# ── Tier thresholds ──
enum ThreatTier { NONE, DEFENSE, MILITARY, DESPERATE }

func _ready() -> void:
	pass


func reset() -> void:
	_threat = 0
	_expedition_timer = 0
	_boss_timer = 0


func get_threat() -> int:
	return _threat


func get_tier() -> int:
	if _threat >= 80:
		return ThreatTier.DESPERATE
	elif _threat >= 60:
		return ThreatTier.MILITARY
	elif _threat >= 30:
		return ThreatTier.DEFENSE
	else:
		return ThreatTier.NONE


func get_tier_name() -> String:
	match get_tier():
		ThreatTier.NONE: return "无威胁"
		ThreatTier.DEFENSE: return "防御态势"
		ThreatTier.MILITARY: return "军事行动"
		ThreatTier.DESPERATE: return "绝望反击"
		_: return "未知"


func change_threat(delta: int) -> void:
	var old: int = _threat
	# v3.0: Apply difficulty scaling to threat gains (not losses)
	var scaled_delta: int = delta
	if delta > 0:
		scaled_delta = int(float(delta) * BalanceManager.get_threat_gain_mult())
		scaled_delta = mini(scaled_delta, delta * 2)  # Cap at 2x original
	_threat = clampi(_threat + scaled_delta, 0, 100)
	if _threat != old:
		var old_tier: int = _get_tier_for(old)
		var new_tier: int = get_tier()
		EventBus.message_log.emit("威胁值: %d -> %d" % [old, _threat])
		if new_tier != old_tier:
			EventBus.message_log.emit("[color=orange]光明联盟威胁等级变更: %s[/color]" % get_tier_name())
		EventBus.resources_changed.emit(-1)
		EventBus.threat_changed.emit(_threat)


func _get_tier_for(val: int) -> int:
	if val >= 80: return ThreatTier.DESPERATE
	elif val >= 60: return ThreatTier.MILITARY
	elif val >= 30: return ThreatTier.DEFENSE
	else: return ThreatTier.NONE


# ═══════════════ DECAY ═══════════════

func tick_decay() -> void:
	## -5 threat per turn (natural decay, per 03_战略设定.md).
	if _threat > 0:
		change_threat(-5)
	# When threat is 0, skip decay entirely (no log spam)


# ═══════════════ GARRISON BONUS ═══════════════

func get_garrison_bonus() -> float:
	## Returns extra garrison multiplier for Light Alliance tiles.
	match get_tier():
		ThreatTier.DEFENSE: return 0.30
		ThreatTier.MILITARY: return 0.30
		ThreatTier.DESPERATE: return 0.30
		_: return 0.0


# ═══════════════ EXPEDITION CHECK (16_训练系统: interval-based) ═══════════════

func tick_timers() -> void:
	## Called once per turn. Increments expedition/boss timers only when at correct tier.
	if get_tier() >= ThreatTier.MILITARY:
		_expedition_timer += 1
	else:
		_expedition_timer = 0  # Reset timer when not at military+ tier
	if get_tier() >= ThreatTier.DESPERATE:
		_boss_timer += 1
	else:
		_boss_timer = 0  # Reset timer when not at desperate tier

func should_spawn_expedition() -> bool:
	## At MILITARY tier+, spawn expedition every 3 turns (per 16_训练系统.md §3.5).
	if get_tier() < ThreatTier.MILITARY:
		return false
	if _expedition_timer >= 3:
		_expedition_timer = 0
		return true
	return false


func should_spawn_boss() -> bool:
	## At DESPERATE tier, spawn boss every 5 turns (per 16_训练系统.md §3.5).
	if get_tier() < ThreatTier.DESPERATE:
		return false
	if _boss_timer >= 5:
		_boss_timer = 0
		return true
	return false


# ═══════════════ DOMINANCE CHECK (03_战略设定: 控制50%+节点+5/回合) ═══════════════

func check_dominance(player_owned_nodes: int, total_nodes: int) -> void:
	if total_nodes > 0 and float(player_owned_nodes) / float(total_nodes) >= 0.5:
		change_threat(5)


# ═══════════════ THREAT CHANGE TRIGGERS ═══════════════

func on_tile_captured() -> void:
	change_threat(10)  # 03_战略设定: 占领+10

func on_hero_captured() -> void:
	change_threat(20)  # 03_战略设定: 俘英雄+20

func on_army_destroyed() -> void:
	change_threat(5)

func on_hero_released() -> void:
	change_threat(-10)  # 03_战略设定: 释放英雄-10

func on_diplomacy_action() -> void:
	change_threat(-15)  # 03_战略设定: 外交-15


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"threat": _threat,
		"expedition_timer": _expedition_timer,
		"boss_timer": _boss_timer,
	}


func from_save_data(data: Dictionary) -> void:
	_threat = data.get("threat", 0)
	_expedition_timer = data.get("expedition_timer", 0)
	_boss_timer = data.get("boss_timer", 0)
