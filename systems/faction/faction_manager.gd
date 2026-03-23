## faction_manager.gd - Coordinates faction-specific mechanics
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Rival dark faction AI states ──
var _rival_factions: Array = []   # Array of { "faction_id": int, "player_id": int, "alive": bool }


func _ready() -> void:
	pass


func reset() -> void:
	_rival_factions.clear()
	OrcMechanic.reset()
	PirateMechanic.reset()
	DarkElfMechanic.reset()


func init_faction(player_id: int, faction_id: int) -> void:
	match faction_id:
		FactionData.FactionID.ORC:
			OrcMechanic.init_player(player_id)
		FactionData.FactionID.PIRATE:
			PirateMechanic.init_player(player_id)
		FactionData.FactionID.DARK_ELF:
			DarkElfMechanic.init_player(player_id)


func register_rival(faction_id: int, player_id: int) -> void:
	_rival_factions.append({
		"faction_id": faction_id,
		"player_id": player_id,
		"alive": true,
	})


func get_rival_factions() -> Array:
	return _rival_factions


func is_faction_alive(faction_id: int) -> bool:
	for rival in _rival_factions:
		if rival["faction_id"] == faction_id:
			return rival["alive"]
	return false


func mark_faction_dead(faction_id: int) -> void:
	for rival in _rival_factions:
		if rival["faction_id"] == faction_id:
			rival["alive"] = false
			EventBus.message_log.emit("[color=gold]%s 已被征服![/color]" % FactionData.FACTION_NAMES[faction_id])
			OrderManager.on_faction_conquered()
			ResourceManager.apply_delta(
				GameManager.get_human_player_id(),
				{"prestige": FactionData.PRESTIGE_SOURCES["conquer_faction"]}
			)
			break


# ═══════════════ TURN TICK ═══════════════

func tick_faction(player_id: int, faction_id: int, had_combat: bool) -> void:
	## Called at the START of a player's turn.
	match faction_id:
		FactionData.FactionID.ORC:
			OrcMechanic.tick(player_id, had_combat)
		FactionData.FactionID.PIRATE:
			PirateMechanic.tick(player_id)
		FactionData.FactionID.DARK_ELF:
			DarkElfMechanic.tick(player_id)


# ═══════════════ COMBAT HOOKS ═══════════════

func on_combat_win(player_id: int, faction_id: int) -> void:
	## Called after any successful combat for the player.
	ResourceManager.apply_delta(player_id, {"prestige": FactionData.PRESTIGE_SOURCES["win_combat"]})

	match faction_id:
		FactionData.FactionID.ORC:
			OrcMechanic.on_combat_win(player_id)
		FactionData.FactionID.DARK_ELF:
			DarkElfMechanic.on_combat_win(player_id)

	# Slave capture removed – handled by CombatResolver to avoid double capture


func on_stronghold_captured(player_id: int, faction_id: int) -> void:
	ResourceManager.apply_delta(player_id, {"prestige": FactionData.PRESTIGE_SOURCES["capture_stronghold"]})
	ThreatManager.on_tile_captured()
	OrderManager.on_tile_captured()

	if faction_id == FactionData.FactionID.PIRATE:
		PirateMechanic.on_stronghold_captured(player_id)


# ═══════════════ COMBAT ATK BONUS ═══════════════

func get_faction_atk_bonus(player_id: int, faction_id: int) -> int:
	## Returns any faction-specific attack bonus.
	var bonus: int = 0
	match faction_id:
		FactionData.FactionID.ORC:
			# WAAAGH! graduated ATK bonus (+1/+2/+4 by tier)
			bonus += OrcMechanic.get_waaagh_atk_bonus(player_id)
		FactionData.FactionID.PIRATE:
			# Rum morale ATK bonus (+2 or +4 drunk)
			var rum_bonus: Dictionary = PirateMechanic.get_rum_combat_bonus(player_id)
			bonus += rum_bonus.get("atk", 0)
		FactionData.FactionID.DARK_ELF:
			bonus += DarkElfMechanic.get_combat_atk_bonus(player_id)
	return bonus


func get_damage_multiplier(player_id: int, faction_id: int) -> float:
	## Returns faction-specific damage multiplier (Orc WAAAGH!).
	match faction_id:
		FactionData.FactionID.ORC:
			return OrcMechanic.get_damage_multiplier(player_id)
	return 1.0


# ═══════════════ PRESTIGE ACTIONS ═══════════════

func spend_prestige_reduce_threat(player_id: int) -> bool:
	var cost: int = FactionData.PRESTIGE_COSTS["reduce_threat"]
	if not ResourceManager.can_afford(player_id, {"prestige": cost}):
		EventBus.message_log.emit("威望不足! 需要%d威望" % cost)
		return false
	ResourceManager.spend(player_id, {"prestige": cost})
	ThreatManager.change_threat(-10)
	EventBus.message_log.emit("消耗%d威望，威胁值-10" % cost)
	return true


func spend_prestige_boost_order(player_id: int) -> bool:
	var cost: int = FactionData.PRESTIGE_COSTS["boost_order"]
	if not ResourceManager.can_afford(player_id, {"prestige": cost}):
		EventBus.message_log.emit("威望不足! 需要%d威望" % cost)
		return false
	ResourceManager.spend(player_id, {"prestige": cost})
	OrderManager.change_order(10)
	EventBus.message_log.emit("消耗%d威望，秩序值+10" % cost)
	return true


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"rival_factions": _rival_factions.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_rival_factions = data.get("rival_factions", []).duplicate(true)
