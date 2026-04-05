## dynamic_situation_events.gd - Game-state-responsive random events (v1.0)
## Events that trigger based on specific game conditions and thresholds.
extends Node

# ── Dynamic event definitions ──
var _dynamic_events: Array = []

# ── Cooldown tracking per event ──
var _event_cooldowns: Dictionary = {}  # event_id -> turns_remaining
const DEFAULT_COOLDOWN: int = 8

# ── Global cooldown to prevent event spam ──
var _global_cooldown: int = 0
const GLOBAL_COOLDOWN: int = 2

# ── Non-repeatable tracking ──
var _fired_once: Dictionary = {}  # event_id -> true

# ── Combat tracking ──
var _win_streak: int = 0
var _total_wins: int = 0
var _last_battle_losses: int = 0
var _last_battle_tile_type: String = ""
var _threat_last_turn: int = 0

# ── Pending choice event ──
var _current_event: Dictionary = {}


func _ready() -> void:
	_register_dynamic_events()
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.event_choice_selected.connect(_on_event_choice_selected)
	# Combat tracking signals
	if EventBus.has_signal("combat_result"):
		EventBus.combat_result.connect(_on_combat_result)
	if EventRegistry:
		EventRegistry._register_source("dynamic_situation_events", _dynamic_events, "dynamic")


# ═══════════════ PLACEHOLDER for combat result ═══════════════

func _on_combat_result(attacker_id: int, _defender_desc: String, won: bool) -> void:
	if attacker_id == 0 and won:
		_win_streak += 1
		_total_wins += 1
	elif attacker_id == 0:
		_win_streak = 0
	_last_battle_losses = 0
	_last_battle_tile_type = ""
func _register_dynamic_events() -> void:
	# --- Resource-based (6) ---
	_dynamic_events.append({
		"id": "dyn_treasury_overflow", "name": "金库溢出",
		"desc": "你的金库堆满了财宝，引来了各地商人。",
		"condition_func": "_cond_gold_over_300",
		"repeatable": true,
		"choices": [
			{"text": "投资军备 (+5兵力)", "effects": {"soldiers": 5}},
			{"text": "继续储蓄", "effects": {}},
		]
	})
	_dynamic_events.append({
		"id": "dyn_famine", "name": "粮荒",
		"desc": "粮仓见底，饥荒在领地蔓延。",
		"condition_func": "_cond_food_below_5",
		"repeatable": true,
		"auto": true,
		"effects": {"soldiers": -2, "order": -3},
	})
	_dynamic_events.append({
		"id": "dyn_iron_discovery", "name": "铁矿发现",
		"desc": "在山区领地发现了新的铁矿脉！",
		"condition_func": "_cond_iron_below_10",
		"repeatable": true,
		"auto": true,
		"effects": {"iron": 20},
	})
	_dynamic_events.append({
		"id": "dyn_slave_revolt", "name": "奴隶暴动",
		"desc": "大量奴隶聚集在一起密谋暴动，局势危险。",
		"condition_func": "_cond_slaves_over_15",
		"repeatable": true,
		"choices": [
			{"text": "镇压暴动 (-3兵力, 保留奴隶)", "effects": {"soldiers": -3}},
			{"text": "释放奴隶 (失去全部奴隶, 秩序+10)", "effects": {"slaves": -99, "order": 10}},
		]
	})
	_dynamic_events.append({
		"id": "dyn_prestige_diplomacy", "name": "威望外交",
		"desc": "你的威名远播，外国使节前来拜访。",
		"condition_func": "_cond_prestige_over_50",
		"repeatable": true,
		"choices": [
			{"text": "结盟提案 (威胁-10, +5威望)", "effects": {"threat": -10, "prestige": 5}},
			{"text": "贸易协定 (+50金, +10铁)", "effects": {"gold": 50, "iron": 10}},
		]
	})
	_dynamic_events.append({
		"id": "dyn_resource_crisis", "name": "资源匮乏",
		"desc": "国库空虚、粮食告罄、铁矿耗尽——绝境之中必须做出抉择。",
		"condition_func": "_cond_resources_critical",
		"repeatable": true,
		"choices": [
			{"text": "紧急征税 (秩序-5, +30金)", "effects": {"order": -5, "gold": 30}},
			{"text": "出售领地 (失去1据点, +50金+10粮)", "effects": {"lose_node": true, "gold": 50, "food": 10}},
		]
	})

	# --- Territory-based (5) ---
	_dynamic_events.append({
		"id": "dyn_overextension", "name": "扩张过快",
		"desc": "领土扩张过快导致管理混乱，各地秩序下降。",
		"condition_func": "_cond_own_40pct",
		"repeatable": true,
		"choices": [
			{"text": "巩固领地 (秩序+3, -20金)", "effects": {"order": 3, "gold": -20}},
			{"text": "继续推进", "effects": {}},
		]
	})
	_dynamic_events.append({
		"id": "dyn_underdog", "name": "弹丸之地",
		"desc": "领土虽小，但将士们的斗志因绝境而燃烧！",
		"condition_func": "_cond_own_below_10pct",
		"repeatable": true,
		"auto": true,
		"effects": {"buff": {"type": "atk_pct", "value": 25, "duration": 3}},
	})
	_dynamic_events.append({
		"id": "dyn_surrounded", "name": "四面楚歌",
		"desc": "三个以上的敌对势力与你接壤，形势严峻。",
		"condition_func": "_cond_surrounded",
		"repeatable": true,
		"choices": [
			{"text": "外交斡旋 (威胁-8, -30金)", "effects": {"threat": -8, "gold": -30}},
			{"text": "加固防线 (+3兵力, 秩序+2)", "effects": {"soldiers": 3, "order": 2}},
		]
	})
	_dynamic_events.append({
		"id": "dyn_trade_hub", "name": "交通要道",
		"desc": "你控制了多个要塞形成的交通枢纽，商路繁荣。",
		"condition_func": "_cond_trade_hub",
		"repeatable": true,
		"auto": true,
		"effects": {"gold": 15},
	})
	_dynamic_events.append({
		"id": "dyn_supply_strain", "name": "前线过长",
		"desc": "领地分散在多个区域，补给线过长导致损耗。",
		"condition_func": "_cond_frontline_long",
		"repeatable": true,
		"auto": true,
		"effects": {"soldiers": -3, "food": -5},
	})

	# --- Combat-based (5) ---
	_dynamic_events.append({
		"id": "dyn_win_streak", "name": "连胜",
		"desc": "连续五场胜利！全军士气高涨。",
		"condition_func": "_cond_win_streak_5",
		"repeatable": true,
		"auto": true,
		"effects": {"buff": {"type": "atk_pct", "value": 10, "duration": 2}},
	})
	_dynamic_events.append({
		"id": "dyn_devastating_loss", "name": "惨败",
		"desc": "一场惨烈的战败，损失惨重，士气低落。",
		"condition_func": "_cond_heavy_losses",
		"repeatable": true,
		"auto": true,
		"effects": {"order": -5},
	})
	_dynamic_events.append({
		"id": "dyn_legendary_commander", "name": "常胜将军",
		"desc": "你的赫赫战功传遍大陆，令敌人闻风丧胆。",
		"condition_func": "_cond_total_wins_10",
		"repeatable": false,
		"auto": true,
		"effects": {"prestige": 5},
	})
	_dynamic_events.append({
		"id": "dyn_depleted_army", "name": "兵力枯竭",
		"desc": "兵力严重不足，一队雇佣兵提出以金币换取效力。",
		"condition_func": "_cond_soldiers_below_10",
		"repeatable": true,
		"choices": [
			{"text": "雇佣 (-50金, +8兵力)", "effects": {"gold": -50, "soldiers": 8}},
			{"text": "拒绝", "effects": {}},
		]
	})
	_dynamic_events.append({
		"id": "dyn_battlefield_relic", "name": "战场遗物",
		"desc": "在战斗遗迹中发现了古老的遗物。",
		"condition_func": "_cond_battle_on_ruins",
		"repeatable": true,
		"choices": [
			{"text": "鉴定遗物 (+1遗物)", "effects": {"relic": true}},
			{"text": "出售遗物 (+15金)", "effects": {"gold": 15}},
		]
	})

	# --- Threat/Order-based (4) ---
	_dynamic_events.append({
		"id": "dyn_golden_age", "name": "和平时期",
		"desc": "威胁低、秩序高——这是难得的黄金时代！",
		"condition_func": "_cond_golden_age",
		"repeatable": true,
		"auto": true,
		"effects": {"gold": 20, "food": 5, "iron": 3},
	})
	_dynamic_events.append({
		"id": "dyn_internal_external", "name": "内忧外患",
		"desc": "外部威胁高涨，内部秩序崩坏——双重危机。",
		"condition_func": "_cond_internal_external",
		"repeatable": true,
		"choices": [
			{"text": "专注内政 (秩序+5, 威胁+5)", "effects": {"order": 5, "threat": 5}},
			{"text": "专注外敌 (威胁-10, 秩序-3)", "effects": {"threat": -10, "order": -3}},
		]
	})
	_dynamic_events.append({
		"id": "dyn_anarchy", "name": "秩序崩溃",
		"desc": "多处领地秩序极低，叛军开始出现！",
		"condition_func": "_cond_anarchy",
		"repeatable": true,
		"auto": true,
		"effects": {"order": -3},
	})
	_dynamic_events.append({
		"id": "dyn_threat_spike", "name": "威胁升级",
		"desc": "威胁等级急剧上升，必须立即应对！",
		"condition_func": "_cond_threat_spike",
		"repeatable": true,
		"choices": [
			{"text": "紧急会议 (-1行动点, 威胁-10)", "effects": {"threat": -10, "ap": -1}},
			{"text": "无视警告", "effects": {}},
		]
	})


# ═══════════════ CONDITION FUNCTIONS ═══════════════

func _get_pid() -> int:
	return GameManager.current_player_index if "current_player_index" in GameManager else 0

func _get_resource(key: String) -> int:
	if ResourceManager != null and ResourceManager.has_method("get_resource"):
		return ResourceManager.get_resource(_get_pid(), key)
	if ResourceManager != null and "resources" in ResourceManager:
		var res: Dictionary = ResourceManager.resources.get(_get_pid(), {})
		return res.get(key, 0)
	return 0

func _get_soldiers() -> int:
	if ResourceManager != null and ResourceManager.has_method("get_army_size"):
		return ResourceManager.get_army_size(_get_pid())
	return _get_resource("soldiers")

func _get_threat() -> int:
	if ThreatManager != null and "threat" in ThreatManager:
		return ThreatManager.threat
	if ThreatManager != null and ThreatManager.has_method("get_threat"):
		return ThreatManager.get_threat()
	return 0

func _get_tile_pct() -> float:
	if "tiles" not in GameManager:
		return 0.0
	var pid: int = _get_pid()
	var total: int = GameManager.tiles.size()
	if total == 0:
		return 0.0
	var owned: int = 0
	for t in GameManager.tiles:
		if t.get("owner", -1) == pid:
			owned += 1
	return float(owned) / float(maxi(int(total), 1))

func _get_player_tiles() -> Array:
	var pid: int = _get_pid()
	var result: Array = []
	if "tiles" in GameManager:
		for t in GameManager.tiles:
			if t.get("owner", -1) == pid:
				result.append(t)
	return result

# --- Condition implementations ---

func _cond_gold_over_300() -> bool:
	return _get_resource("gold") > 300

func _cond_food_below_5() -> bool:
	return _get_resource("food") < 5

func _cond_iron_below_10() -> bool:
	return _get_resource("iron") < 10

func _cond_slaves_over_15() -> bool:
	return _get_resource("slaves") > 15

func _cond_prestige_over_50() -> bool:
	return _get_resource("prestige") > 50

func _cond_resources_critical() -> bool:
	return _get_resource("gold") < 20 and _get_resource("food") < 5 and _get_resource("iron") < 5

func _cond_own_40pct() -> bool:
	return _get_tile_pct() >= 0.4

func _cond_own_below_10pct() -> bool:
	return _get_tile_pct() < 0.1 and _get_tile_pct() > 0.0

func _cond_surrounded() -> bool:
	# Check if 3+ enemy factions border player tiles
	var pid: int = _get_pid()
	var bordering_factions: Dictionary = {}
	if "tiles" in GameManager:
		for t in GameManager.tiles:
			if t.get("owner", -1) == pid:
				for n_idx in t.get("neighbors", []):
					if n_idx >= 0 and n_idx < GameManager.tiles.size():
						var neighbor = GameManager.tiles[n_idx]
						var n_owner: int = neighbor.get("owner", -1)
						if n_owner != pid and n_owner >= 0:
							bordering_factions[n_owner] = true
	return bordering_factions.size() >= 3

func _cond_trade_hub() -> bool:
	# Check for 3+ fortress tiles owned
	var fortress_count: int = 0
	for t in _get_player_tiles():
		if t.get("type", "") == "fortress" or t.get("building", "") == "fortress":
			fortress_count += 1
	return fortress_count >= 3

func _cond_frontline_long() -> bool:
	# Own tiles in 4+ different regions
	var regions: Dictionary = {}
	for t in _get_player_tiles():
		var region: Variant = t.get("region", t.get("zone", -1))
		if region != -1:
			regions[region] = true
	return regions.size() >= 4

func _cond_win_streak_5() -> bool:
	return _win_streak >= 5

func _cond_heavy_losses() -> bool:
	return _last_battle_losses >= 30

func _cond_total_wins_10() -> bool:
	return _total_wins >= 10

func _cond_soldiers_below_10() -> bool:
	return _get_soldiers() < 10 and _get_soldiers() > 0

func _cond_battle_on_ruins() -> bool:
	return _last_battle_tile_type == "ruins"

func _cond_golden_age() -> bool:
	var threat_ok: bool = _get_threat() < 20
	if not threat_ok:
		return false
	# Check all tiles order > 80
	for t in _get_player_tiles():
		if t.get("order", 100) < 80:
			return false
	return _get_player_tiles().size() > 0

func _cond_internal_external() -> bool:
	if _get_threat() <= 60:
		return false
	for t in _get_player_tiles():
		if t.get("order", 100) < 30:
			return true
	return false

func _cond_anarchy() -> bool:
	var low_order_count: int = 0
	for t in _get_player_tiles():
		if t.get("order", 100) < 20:
			low_order_count += 1
	return low_order_count >= 3

func _cond_threat_spike() -> bool:
	var current_threat: int = _get_threat()
	var spike: bool = current_threat - _threat_last_turn >= 20
	return spike


# ═══════════════ TURN PROCESSING ═══════════════

func _on_turn_started(player_id: int) -> void:
	if player_id != 0:
		return

	# Tick cooldowns
	if _global_cooldown > 0:
		_global_cooldown -= 1

	var expired: Array = []
	for key in _event_cooldowns:
		_event_cooldowns[key] -= 1
		if _event_cooldowns[key] <= 0:
			expired.append(key)
	for key in expired:
		_event_cooldowns.erase(key)

	# Reset per-turn combat tracking
	_last_battle_losses = 0
	_last_battle_tile_type = ""

	# Store threat for spike detection
	_threat_last_turn = _get_threat()

	# Check dynamic events
	if _global_cooldown <= 0:
		_check_dynamic_events()


func _check_dynamic_events() -> void:
	# Shuffle to add randomness
	var shuffled: Array = _dynamic_events.duplicate()
	shuffled.shuffle()

	for evt in shuffled:
		var eid: String = evt["id"]

		# Skip if on cooldown
		if _event_cooldowns.has(eid):
			continue

		# Skip if non-repeatable and already fired
		if not evt.get("repeatable", true) and _fired_once.has(eid):
			continue

		# Check condition
		var cond_func: String = evt.get("condition_func", "")
		if cond_func == "" or not has_method(cond_func):
			continue

		if not call(cond_func):
			continue

		# Fire the event
		_fire_dynamic_event(evt)
		_global_cooldown = GLOBAL_COOLDOWN
		return  # Only one per turn


func _fire_dynamic_event(event: Dictionary) -> void:
	var eid: String = event["id"]
	_event_cooldowns[eid] = DEFAULT_COOLDOWN

	if not event.get("repeatable", true):
		_fired_once[eid] = true

	var pid: int = _get_pid()

	if event.get("auto", false):
		# Auto events - apply directly
		_apply_effects(pid, event.get("effects", {}))
		EventBus.message_log.emit("[color=yellow][动态事件] %s: %s[/color]" % [event["name"], event["desc"]])
		return

	# Choice-based event — route through EventScheduler
	_current_event = event
	var choice_texts: Array = []
	for c in event.get("choices", []):
		choice_texts.append(c["text"])

	# FIX A6: pass full choices dict (with effects) so EventPopup can apply them
	if EventScheduler:
		EventScheduler.submit_candidate(
			eid,
			"dynamic_situation",
			EventScheduler.PRIORITY_LOW,
			1.0,
			{"name": event["name"], "description": event["desc"], "choices": event.get("choices", []), "source_type": "dynamic_situation"}
		)
	else:
		EventBus.show_event_popup.emit(event["name"], event["desc"], event.get("choices", []))
	EventBus.message_log.emit("[color=yellow][动态事件] %s[/color]" % event["name"])


# ═══════════════ CHOICE HANDLING ═══════════════

func _on_event_choice_selected(choice_index: int, source_type: String = "") -> void:
	# FIX A6: only handle choices originating from dynamic_situation to prevent race condition
	if source_type != "" and source_type != "dynamic_situation":
		return
	if _current_event.is_empty():
		return

	var choices: Array = _current_event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		_current_event = {}
		return

	var effects: Dictionary = choices[choice_index].get("effects", {})
	var pid: int = _get_pid()
	_apply_effects(pid, effects)
	_current_event = {}


# ═══════════════ EFFECT APPLICATION ═══════════════

func _apply_effects(pid: int, effects: Dictionary) -> void:
	# Route through centralized EffectResolver if available
	if EffectResolver:
		EffectResolver.resolve(effects, {"player_id": pid, "source": "dynamic_event", "event_id": _current_event.get("id", "dynamic")})
		return

	# Legacy fallback — Resource changes
	var res_delta := {}
	for key in ["gold", "food", "iron", "slaves", "prestige", "magic_crystal"]:
		if effects.has(key):
			res_delta[key] = effects[key]
	if not res_delta.is_empty():
		ResourceManager.apply_delta(pid, res_delta)

	# Soldiers
	if effects.has("soldiers"):
		if effects["soldiers"] > 0:
			ResourceManager.add_army(pid, effects["soldiers"])
		else:
			ResourceManager.remove_army(pid, -effects["soldiers"])

	# Order
	if effects.has("order"):
		OrderManager.change_order(effects["order"])

	# Threat
	if effects.has("threat"):
		ThreatManager.change_threat(effects["threat"])

	# Buff
	if effects.has("buff"):
		var buff: Dictionary = effects["buff"]
		BuffManager.add_buff(pid, "dynamic_%s" % buff.get("type", ""), buff.get("type", ""), buff.get("value", 0), buff.get("duration", 1), "dynamic_event")

	# Relic
	if effects.has("relic") and effects["relic"]:
		EventBus.message_log.emit("[color=green]发现远古遗物![/color]")
		if not RelicManager.has_relic(pid):
			var relic_choices: Array = RelicManager.generate_relic_choices()
			EventBus.message_log.emit("可选遗物: %s" % str(relic_choices))
		else:
			ResourceManager.apply_delta(pid, {"prestige": 10})

	# Lose node
	if effects.has("lose_node") and effects["lose_node"]:
		var border_tiles: Array = []
		if "tiles" in GameManager:
			for t in GameManager.tiles:
				if t.get("owner", -1) == pid:
					for n_idx in t.get("neighbors", []):
						if n_idx >= 0 and n_idx < GameManager.tiles.size():
							if GameManager.tiles[n_idx].get("owner", -1) != pid:
								border_tiles.append(t)
								break
		if border_tiles.size() > 0:
			border_tiles.shuffle()
			var lost_tile = border_tiles[0]
			lost_tile["owner"] = -1
			EventBus.tile_lost.emit(pid, lost_tile.get("index", 0))
			EventBus.message_log.emit("[color=red]失去了一个边境据点[/color]")

	# AP
	if effects.has("ap"):
		EventBus.message_log.emit("[color=yellow]行动点变化: %+d[/color]" % effects["ap"])


# ═══════════════ SAVE / LOAD ═══════════════

func get_save_data() -> Dictionary:
	return {
		"event_cooldowns": _event_cooldowns.duplicate(),
		"fired_once": _fired_once.duplicate(),
		"global_cooldown": _global_cooldown,
		"win_streak": _win_streak,
		"total_wins": _total_wins,
		"threat_last_turn": _threat_last_turn,
	}


func load_save_data(data: Dictionary) -> void:
	_event_cooldowns = data.get("event_cooldowns", {})
	_fired_once = data.get("fired_once", {})
	_global_cooldown = data.get("global_cooldown", 0)
	_win_streak = data.get("win_streak", 0)
	_total_wins = data.get("total_wins", 0)
	_threat_last_turn = data.get("threat_last_turn", 0)
