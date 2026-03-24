## npc_manager.gd - Special NPC obedience system (v0.7)
## Manages captured NPC characters with obedience mechanics.
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── NPC Definitions ──
# 4 universal + 6 faction-specific (2 per evil faction)
static var NPC_DEFS: Dictionary = {
	# Universal NPCs (obtainable by any faction)
	"war_prisoner": {
		"name": "败军之将",
		"type": "universal",
		"base_obedience": 20,
		"combat_bonus": {"atk": 5},
		"skill": "recruit_discount",
		"skill_desc": "招募费-15%",
		"event_chains": {40: "knight_intel", 60: "knight_train", 80: "knight_sworn"},
	},
	"village_serf": {
		"name": "村庄农奴",
		"type": "universal",
		"base_obedience": 30,
		"combat_bonus": {},
		"skill": "food_production",
		"skill_desc": "+3粮草/回合",
		"event_chains": {40: "serf_farm", 60: "serf_settle", 80: "serf_loyal"},
	},
	"mine_worker": {
		"name": "矿坑苦工",
		"type": "universal",
		"base_obedience": 25,
		"combat_bonus": {},
		"skill": "iron_production",
		"skill_desc": "+2铁矿/回合",
		"event_chains": {40: "miner_dig", 60: "miner_vein", 80: "miner_master"},
	},
	"merchant_captive": {
		"name": "商人俘虏",
		"type": "universal",
		"base_obedience": 30,
		"combat_bonus": {},
		"skill": "trade_connections",
		"skill_desc": "+15金/回合",
		"event_chains": {40: "merchant_deal", 60: "merchant_network", 80: "merchant_empire"},
	},
	# Orc-specific NPCs
	"orc_shaman": {
		"name": "野蛮萨满",
		"type": "orc",
		"faction": FactionData.FactionID.ORC,
		"base_obedience": 15,
		"combat_bonus": {"atk": 3},
		"skill": "waaagh_boost",
		"skill_desc": "WAAAGH!获取+30%",
		"event_chains": {40: "shaman_ritual", 60: "shaman_totem", 80: "shaman_avatar"},
	},
	"gladiator": {
		"name": "角斗士",
		"type": "orc",
		"faction": FactionData.FactionID.ORC,
		"base_obedience": 20,
		"combat_bonus": {"atk": 8},
		"skill": "arena_boost",
		"skill_desc": "竞技场效果翻倍",
		"event_chains": {40: "gladiator_fight", 60: "gladiator_champion", 80: "gladiator_legend"},
	},
	# Pirate-specific NPCs
	"pirate_navigator": {
		"name": "领航员",
		"type": "pirate",
		"faction": FactionData.FactionID.PIRATE,
		"base_obedience": 25,
		"combat_bonus": {},
		"skill": "plunder_boost",
		"skill_desc": "掠夺值+3/回合",
		"event_chains": {40: "nav_route", 60: "nav_treasure", 80: "nav_legendary"},
	},
	"smuggler": {
		"name": "走私犯",
		"type": "pirate",
		"faction": FactionData.FactionID.PIRATE,
		"base_obedience": 20,
		"combat_bonus": {},
		"skill": "trade_discount",
		"skill_desc": "黑市手续费减半",
		"event_chains": {40: "smuggler_contact", 60: "smuggler_network", 80: "smuggler_kingpin"},
	},
	# Dark Elf-specific NPCs
	"dark_seer": {
		"name": "暗影先知",
		"type": "dark_elf",
		"faction": FactionData.FactionID.DARK_ELF,
		"base_obedience": 10,
		"combat_bonus": {"atk": 3},
		"skill": "fog_reveal",
		"skill_desc": "揭示3迷雾格/回合",
		"event_chains": {40: "seer_vision", 60: "seer_prophecy", 80: "seer_omniscient"},
	},
	"pain_artisan": {
		"name": "苦痛工匠",
		"type": "dark_elf",
		"faction": FactionData.FactionID.DARK_ELF,
		"base_obedience": 25,
		"combat_bonus": {},
		"skill": "slave_efficiency",
		"skill_desc": "奴隶分配产出+50%",
		"event_chains": {40: "artisan_tools", 60: "artisan_craft", 80: "artisan_masterwork"},
	},
}

# ── Obedience Tiers ──
enum ObedienceTier { REBEL, RESIST, SUBMIT, OBEY, LOYAL }

const TIER_THRESHOLDS: Dictionary = {
	ObedienceTier.REBEL: [0, 19],
	ObedienceTier.RESIST: [20, 39],
	ObedienceTier.SUBMIT: [40, 59],
	ObedienceTier.OBEY: [60, 79],
	ObedienceTier.LOYAL: [80, 100],
}

const TIER_NAMES: Dictionary = {
	ObedienceTier.REBEL: "反叛",
	ObedienceTier.RESIST: "抗拒",
	ObedienceTier.SUBMIT: "服从",
	ObedienceTier.OBEY: "忠顺",
	ObedienceTier.LOYAL: "忠诚",
}

# ── State ──
# { player_id: { npc_id: { "obedience": int, "last_trained_turn": int, "active": bool } } }
var _npc_states: Dictionary = {}


func _ready() -> void:
	pass


func reset() -> void:
	_npc_states.clear()


func init_player(player_id: int) -> void:
	_npc_states[player_id] = {}


# ═══════════════ NPC CAPTURE ═══════════════

func capture_npc(player_id: int, npc_id: String) -> bool:
	## Add an NPC to the player's roster.
	if not NPC_DEFS.has(npc_id):
		return false
	if not _npc_states.has(player_id):
		init_player(player_id)
	if _npc_states[player_id].has(npc_id):
		return false  # Already captured

	var def: Dictionary = NPC_DEFS[npc_id]
	_npc_states[player_id][npc_id] = {
		"obedience": def["base_obedience"],
		"last_trained_turn": 0,
		"active": true,
		"triggered_thresholds": [],
	}
	EventBus.message_log.emit("捕获了 %s!" % def["name"])
	EventBus.npc_obedience_changed.emit(player_id, npc_id, def["base_obedience"])
	return true


# ═══════════════ OBEDIENCE MANAGEMENT ═══════════════

func get_obedience(player_id: int, npc_id: String) -> int:
	if not _npc_states.has(player_id):
		return 0
	if not _npc_states[player_id].has(npc_id):
		return 0
	return _npc_states[player_id][npc_id]["obedience"]


func get_obedience_tier(player_id: int, npc_id: String) -> int:
	var ob: int = get_obedience(player_id, npc_id)
	if ob >= 80:
		return ObedienceTier.LOYAL
	elif ob >= 60:
		return ObedienceTier.OBEY
	elif ob >= 40:
		return ObedienceTier.SUBMIT
	elif ob >= 20:
		return ObedienceTier.RESIST
	else:
		return ObedienceTier.REBEL


func get_tier_name(player_id: int, npc_id: String) -> String:
	var tier: int = get_obedience_tier(player_id, npc_id)
	return TIER_NAMES.get(tier, "未知")


func train_npc(player_id: int, npc_id: String) -> bool:
	## Training: consume 2 slaves -> +10 obedience.
	if not _npc_states.has(player_id) or not _npc_states[player_id].has(npc_id):
		return false
	if ResourceManager.get_slaves(player_id) < 2:
		EventBus.message_log.emit("训练需要2名奴隶!")
		return false

	ResourceManager.apply_delta(player_id, {"slaves": -2})
	SlaveManager.remove_slaves(player_id, 2)

	var state: Dictionary = _npc_states[player_id][npc_id]
	state["obedience"] = mini(100, state["obedience"] + 10)
	state["last_trained_turn"] = GameManager.turn_number

	var def: Dictionary = NPC_DEFS[npc_id]
	EventBus.message_log.emit("训练 %s: 服从度+10 (当前%d)" % [def["name"], state["obedience"]])
	EventBus.npc_obedience_changed.emit(player_id, npc_id, state["obedience"])

	# Check event chain triggers
	_check_event_chains(player_id, npc_id)
	return true


func gift_resources(player_id: int, npc_id: String, gift: Dictionary) -> bool:
	## Gift resources to increase obedience. Gold/food/iron accepted.
	if not _npc_states.has(player_id) or not _npc_states[player_id].has(npc_id):
		return false
	if not ResourceManager.can_afford(player_id, gift):
		return false

	ResourceManager.spend(player_id, gift)

	var total_value: int = gift.get("gold", 0) / 10 + gift.get("food", 0) / 2 + gift.get("iron", 0) / 3
	var ob_gain: int = maxi(1, total_value)

	var state: Dictionary = _npc_states[player_id][npc_id]
	state["obedience"] = mini(100, state["obedience"] + ob_gain)

	var def: Dictionary = NPC_DEFS[npc_id]
	EventBus.message_log.emit("赠礼给 %s: 服从度+%d (当前%d)" % [def["name"], ob_gain, state["obedience"]])
	EventBus.npc_obedience_changed.emit(player_id, npc_id, state["obedience"])

	_check_event_chains(player_id, npc_id)
	return true


# ═══════════════ TURN TICK ═══════════════

func tick_all(player_id: int, current_turn: int) -> void:
	## Called each turn. Handles natural decay and growth.
	if not _npc_states.has(player_id):
		return

	var npcs_to_remove: Array = []
	for npc_id in _npc_states[player_id]:
		var state: Dictionary = _npc_states[player_id][npc_id]
		if not state["active"]:
			continue

		# Escape chance at REBEL tier (obedience < 20): 10% per turn
		if state["obedience"] < 20:
			if randi() % 100 < 10:
				var esc_def: Dictionary = NPC_DEFS[npc_id]
				EventBus.message_log.emit("[color=red]%s 趁机逃跑了![/color]" % esc_def["name"])
				state["active"] = false
				npcs_to_remove.append(npc_id)
				continue

		var turns_since_train: int = current_turn - state["last_trained_turn"]

		# Natural decay: -3/turn if not trained for 3 turns
		if turns_since_train >= 3:
			state["obedience"] = maxi(0, state["obedience"] - 3)
			var def: Dictionary = NPC_DEFS[npc_id]
			if state["obedience"] <= 0:
				EventBus.message_log.emit("[color=red]%s 反叛逃跑了![/color]" % def["name"])
				state["active"] = false
				npcs_to_remove.append(npc_id)
				continue

		# Natural growth: +2 every 5 turns
		if current_turn > 0 and current_turn % 5 == 0:
			state["obedience"] = mini(100, state["obedience"] + 2)

		EventBus.npc_obedience_changed.emit(player_id, npc_id, state["obedience"])

		# Check event chain triggers after obedience changes
		_check_event_chains(player_id, npc_id)

	# Remove escaped/rebelled NPCs from active state
	for npc_id in npcs_to_remove:
		_npc_states[player_id].erase(npc_id)


func on_combat_loss(player_id: int) -> void:
	## Combat loss penalty: all NPCs -5 obedience.
	if not _npc_states.has(player_id):
		return
	for npc_id in _npc_states[player_id]:
		var state: Dictionary = _npc_states[player_id][npc_id]
		if not state["active"]:
			continue
		state["obedience"] = maxi(0, state["obedience"] - 5)
		EventBus.npc_obedience_changed.emit(player_id, npc_id, state["obedience"])
		_check_event_chains(player_id, npc_id)
	EventBus.message_log.emit("[color=orange]战败! 所有NPC服从度-5[/color]")


# ═══════════════ QUERIES ═══════════════

func get_captured_npcs(player_id: int) -> Array:
	## Returns array of { "npc_id": String, "name": String, "obedience": int, "tier": String, "active": bool }
	var result: Array = []
	if not _npc_states.has(player_id):
		return result
	for npc_id in _npc_states[player_id]:
		var state: Dictionary = _npc_states[player_id][npc_id]
		var def: Dictionary = NPC_DEFS[npc_id]
		result.append({
			"npc_id": npc_id,
			"name": def["name"],
			"obedience": state["obedience"],
			"tier": get_tier_name(player_id, npc_id),
			"active": state["active"],
			"skill": def["skill_desc"],
		})
	return result


func get_active_skill_bonuses(player_id: int) -> Dictionary:
	## Returns aggregated bonuses from NPCs at SUBMIT tier or above.
	var bonuses := {
		"atk_bonus": 0, "def_bonus": 0, "gold_per_turn": 0,
		"food_per_turn": 0, "iron_per_turn": 0,
		"recruit_discount": 0, "trade_discount": 1.0,
		"waaagh_mult": 1.0, "arena_mult": 1.0,
		"plunder_per_turn": 0, "fog_reveal_per_turn": 0,
		"slave_efficiency_mult": 1.0,
	}
	if not _npc_states.has(player_id):
		return bonuses

	for npc_id in _npc_states[player_id]:
		var state: Dictionary = _npc_states[player_id][npc_id]
		if not state["active"] or state["obedience"] < 40:
			continue  # Must be at SUBMIT or above
		var def: Dictionary = NPC_DEFS[npc_id]
		match def["skill"]:
			"recruit_discount":
				bonuses["recruit_discount"] = 15
			"food_production":
				bonuses["food_per_turn"] += 3
			"iron_production":
				bonuses["iron_per_turn"] += 2
			"trade_connections":
				bonuses["gold_per_turn"] += 15
			"waaagh_boost":
				bonuses["waaagh_mult"] = 1.3
			"arena_boost":
				bonuses["arena_mult"] = 2.0
			"plunder_boost":
				bonuses["plunder_per_turn"] += 3
			"trade_discount":
				bonuses["trade_discount"] = 0.5
			"fog_reveal":
				bonuses["fog_reveal_per_turn"] += 3
			"slave_efficiency":
				bonuses["slave_efficiency_mult"] = 1.5

	return bonuses


func get_available_npcs_for_faction(faction_id: int) -> Array:
	## Returns NPC IDs that are universal or match the given faction.
	var result: Array = []
	for npc_id in NPC_DEFS:
		var def: Dictionary = NPC_DEFS[npc_id]
		if def["type"] == "universal":
			result.append(npc_id)
		elif def.has("faction") and def["faction"] == faction_id:
			result.append(npc_id)
	return result


func boost_all_obedience(player_id: int, amount: int) -> void:
	if not _npc_states.has(player_id):
		return
	for npc_id in _npc_states[player_id]:
		var state: Dictionary = _npc_states[player_id][npc_id]
		if not state["active"]:
			continue
		state["obedience"] = mini(100, state["obedience"] + amount)
		EventBus.npc_obedience_changed.emit(player_id, npc_id, state["obedience"])
		_check_event_chains(player_id, npc_id)


# ═══════════════ INTERNAL ═══════════════

func _check_event_chains(player_id: int, npc_id: String) -> void:
	## Trigger event chains at obedience thresholds.
	if not NPC_DEFS.has(npc_id):
		return
	var def: Dictionary = NPC_DEFS[npc_id]
	var state: Dictionary = _npc_states[player_id][npc_id]
	var ob: int = state["obedience"]
	var triggered: Array = state.get("triggered_thresholds", [])
	var chains: Dictionary = def.get("event_chains", {})
	for threshold in chains:
		if ob >= threshold and not triggered.has(threshold):
			var quest_id: String = chains[threshold]
			triggered.append(threshold)
			EventBus.message_log.emit("[NPC事件] %s 信任度达到%d, 触发特殊事件!" % [def["name"], threshold])
			EventBus.quest_triggered.emit(player_id, quest_id, {"npc_id": npc_id, "threshold": threshold})
	state["triggered_thresholds"] = triggered


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"npc_states": _npc_states.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_npc_states = data.get("npc_states", {}).duplicate(true)
