## crisis_countdown.gd - SR07-style invasion countdown timer (v1.0)
## Creates urgency by counting down to major crisis events.
## Multiple crisis types can be active simultaneously.
extends Node

signal crisis_warning(crisis_id: String, turns_remaining: int)
signal crisis_triggered(crisis_id: String)
signal crisis_averted(crisis_id: String)

# Crisis definitions
const CRISIS_TYPES := {
	"demon_invasion": {
		"name": "魔族入侵",
		"desc": "古代封印即将破碎，魔族大军将从暗影裂隙中涌出！",
		"warning_desc": "距离魔族入侵还有 %d 回合！",
		"base_countdown": 40,
		"trigger_turn": -1,
		"warning_turns": [10, 5, 3, 1],
		"effect": "demon_army_spawn",
		"avoidable": true,
		"avert_condition": "threat_below_30",
		"severity": 3,
	},
	"ancient_awakening": {
		"name": "远古觉醒",
		"desc": "大地深处的远古存在正在苏醒，地震频发！",
		"warning_desc": "距离远古觉醒还有 %d 回合！",
		"base_countdown": 55,
		"trigger_turn": -1,
		"warning_turns": [15, 8, 3, 1],
		"effect": "earthquake_crisis",
		"avoidable": true,
		"avert_condition": "own_ruins_tiles_3",
		"severity": 2,
	},
	"blood_moon": {
		"name": "血月之夜",
		"desc": "血月即将升起，所有邪恶力量将获得极大增强！",
		"warning_desc": "距离血月之夜还有 %d 回合！",
		"base_countdown": 25,
		"trigger_turn": -1,
		"warning_turns": [5, 3, 1],
		"effect": "blood_moon_buff_enemies",
		"avoidable": false,
		"avert_condition": "",
		"severity": 1,
	},
	"coalition_war": {
		"name": "反玩家联盟",
		"desc": "其余势力组成联盟，准备联合进攻你的领地！",
		"warning_desc": "联盟军集结中... 还有 %d 回合发动总攻！",
		"base_countdown": 30,
		"trigger_turn": -1,
		"warning_turns": [8, 4, 2, 1],
		"effect": "coalition_attack",
		"avoidable": true,
		"avert_condition": "destroy_2_factions",
		"severity": 3,
	},
}

# State
var _active_crises: Dictionary = {}  # crisis_id -> {countdown: int, triggered: bool, averted: bool, start_turn: int}
var _initialized: bool = false
var _current_turn: int = 0

func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)
	if EventRegistry:
		var _crisis_events: Array = []
		for _cid in CRISIS_TYPES:
			var _ct: Dictionary = CRISIS_TYPES[_cid].duplicate()
			_ct["id"] = _cid
			_crisis_events.append(_ct)
		EventRegistry._register_source("crisis_countdown", _crisis_events, "crisis")


func initialize_crises() -> void:
	if _initialized:
		return
	_initialized = true
	# Activate crises based on difficulty/NG+ level
	var ng_level: int = NgPlusManager.get_level() if NgPlusManager else 0

	# Always active: demon invasion (core SR07-style countdown)
	_activate_crisis("demon_invasion", CRISIS_TYPES["demon_invasion"]["base_countdown"])

	# NG+1+: blood moon
	if ng_level >= 1 or _current_turn >= 10:
		_activate_crisis("blood_moon", CRISIS_TYPES["blood_moon"]["base_countdown"])

	# NG+2+ or when player is dominant: coalition war
	if ng_level >= 2:
		_activate_crisis("coalition_war", CRISIS_TYPES["coalition_war"]["base_countdown"])


func _activate_crisis(crisis_id: String, countdown: int) -> void:
	if _active_crises.has(crisis_id):
		return
	_active_crises[crisis_id] = {
		"countdown": countdown,
		"triggered": false,
		"averted": false,
		"start_turn": _current_turn,
	}


func _on_turn_started(player_id: int) -> void:
	var human_id: int = GameManager.get_human_player_id() if GameManager else 0
	if player_id != human_id:
		return
	_current_turn = GameManager.turn_number if GameManager else _current_turn + 1

	# Initialize on first real turn
	if not _initialized and _current_turn >= 3:
		initialize_crises()

	# Process each active crisis
	for crisis_id in _active_crises.keys():
		var state: Dictionary = _active_crises[crisis_id]
		if state["triggered"] or state["averted"]:
			continue

		# Check avert condition
		if _check_avert_condition(crisis_id):
			state["averted"] = true
			crisis_averted.emit(crisis_id)
			var crisis_data: Dictionary = CRISIS_TYPES.get(crisis_id, {})
			EventBus.message_log.emit("[color=green]危机解除! %s 已被成功阻止![/color]" % crisis_data.get("name", crisis_id))
			continue

		# Countdown
		state["countdown"] -= 1
		var remaining: int = state["countdown"]

		# Warning checks
		var crisis_data: Dictionary = CRISIS_TYPES.get(crisis_id, {})
		var warnings: Array = crisis_data.get("warning_turns", [])
		if remaining in warnings:
			crisis_warning.emit(crisis_id, remaining)
			var warn_text: String = crisis_data.get("warning_desc", "危机倒计时: %d") % remaining
			EventBus.message_log.emit("[color=yellow]⚠ %s[/color]" % warn_text)
			# Show dramatic warning popup for imminent crises
			if remaining <= 3:
				var choices: Array = [{"text": "了解 (准备防御)", "effects": {}}, {"text": "忽视 (继续进攻)", "effects": {}}]
				EventBus.show_event_popup.emit("⚠ " + crisis_data.get("name", ""), warn_text, choices)

		# Trigger
		if remaining <= 0:
			state["triggered"] = true
			crisis_triggered.emit(crisis_id)
			_execute_crisis(crisis_id)


func _check_avert_condition(crisis_id: String) -> bool:
	var crisis_data: Dictionary = CRISIS_TYPES.get(crisis_id, {})
	if not crisis_data.get("avoidable", false):
		return false
	var condition: String = crisis_data.get("avert_condition", "")
	match condition:
		"threat_below_30":
			return ThreatManager.get_threat() < 30 if ThreatManager else false
		"own_ruins_tiles_3":
			# Check if player owns 3+ ruins tiles
			var human_id: int = GameManager.get_human_player_id() if GameManager else 0
			var count: int = 0
			if GameManager:
				for tile in GameManager.map_tiles:
					if tile.get("owner", -1) == human_id and tile.get("terrain", -1) == 7:  # RUINS
						count += 1
			return count >= 3
		"destroy_2_factions":
			# Check if player has destroyed 2+ factions
			if FactionManager:
				var dead_count: int = 0
				for f in FactionManager.get_all_factions():
					if FactionManager.is_faction_dead(f):
						dead_count += 1
				return dead_count >= 2
			return false
	return false


func _execute_crisis(crisis_id: String) -> void:
	var crisis_data: Dictionary = CRISIS_TYPES.get(crisis_id, {})
	var severity: int = crisis_data.get("severity", 1)
	var effect: String = crisis_data.get("effect", "")

	# Grand event for crisis trigger
	EventBus.grand_event_started.emit("crisis_" + crisis_id)
	EventBus.message_log.emit("[color=red]████ %s 已经降临! ████[/color]" % crisis_data.get("name", crisis_id))

	match effect:
		"demon_army_spawn":
			# Spawn powerful neutral enemy army at random border tile
			var soldiers: int = 20 + severity * 10
			var desc: String = "魔族大军从暗影裂隙中涌出! %d名魔族战士入侵你的领地!" % soldiers
			EventBus.show_event_popup.emit("魔族入侵!", desc, [
				{"text": "迎战! (+ATK 20% 防御buff)", "effects": {"buff": {"type": "atk", "value": 20, "duration": 3}}},
				{"text": "紧急撤退 (放弃边境领地)", "effects": {"lose_node": true, "soldiers": -5}}
			])
		"earthquake_crisis":
			# All tiles lose 2 order, 3 random tiles lose garrison
			if OrderManager:
				var human_id: int = GameManager.get_human_player_id() if GameManager else 0
				for tile in GameManager.map_tiles:
					if tile.get("owner", -1) == human_id:
						OrderManager.change_order(tile.get("index", 0), -2)
			EventBus.show_event_popup.emit("远古觉醒!", "大地震动,所有领地秩序-2! 部分城墙受损!", [
				{"text": "紧急修复 (-50金, +3秩序)", "effects": {"gold": -50, "order": 3}},
				{"text": "趁乱进攻 (+ATK 25% 3回合)", "effects": {"buff": {"type": "atk", "value": 25, "duration": 3}}}
			])
		"blood_moon_buff_enemies":
			# All enemy factions get ATK buff for 5 turns
			EventBus.show_event_popup.emit("血月升起!", "血红的月亮悬挂天际,所有敌方势力ATK+20%持续5回合!", [
				{"text": "以毒攻毒 (-3奴隶, 我方也获得ATK+15%)", "effects": {"slaves": -3, "buff": {"type": "atk", "value": 15, "duration": 5}}},
				{"text": "固守待旦 (DEF+25% 5回合)", "effects": {"buff": {"type": "def", "value": 25, "duration": 5}}}
			])
		"coalition_attack":
			# Multiple enemy factions declare war simultaneously
			EventBus.show_event_popup.emit("联盟总攻!", "所有存活敌方势力组成联盟向你发动总攻! 所有边境受到压力!", [
				{"text": "集中兵力 (选择一个方向突破)", "effects": {"buff": {"type": "atk", "value": 30, "duration": 3}}},
				{"text": "外交斡旋 (-100金, -20威望, 延缓5回合)", "effects": {"gold": -100, "prestige": -20}}
			])

	EventBus.grand_event_ended.emit("crisis_" + crisis_id)


## Get all active crisis countdowns for HUD display
func get_active_countdowns() -> Array:
	var result: Array = []
	for crisis_id in _active_crises.keys():
		var state: Dictionary = _active_crises[crisis_id]
		if state["triggered"] or state["averted"]:
			continue
		var crisis_data: Dictionary = CRISIS_TYPES.get(crisis_id, {})
		result.append({
			"id": crisis_id,
			"name": crisis_data.get("name", crisis_id),
			"remaining": state["countdown"],
			"severity": crisis_data.get("severity", 1),
			"avoidable": crisis_data.get("avoidable", false),
		})
	# Sort by remaining turns ascending
	result.sort_custom(func(a, b): return a["remaining"] < b["remaining"])
	return result


func get_save_data() -> Dictionary:
	return {
		"active_crises": _active_crises.duplicate(true),
		"initialized": _initialized,
		"current_turn": _current_turn,
	}


func load_save_data(data: Dictionary) -> void:
	_active_crises = data.get("active_crises", {})
	_initialized = data.get("initialized", false)
	_current_turn = data.get("current_turn", 0)
