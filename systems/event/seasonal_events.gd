## seasonal_events.gd - Season-specific random events (v1.0)
## Integrates with WeatherSystem to trigger thematic events per season.
extends Node

# ── Season event definitions: season_name -> Array of events ──
var _season_events: Dictionary = {}

# ── Cooldown tracking ──
var _last_seasonal_event_turn: int = -10
const SEASONAL_COOLDOWN: int = 3

# ── Track which events have fired this season to avoid repeats ──
var _fired_this_season: Array = []

# ── Current season for change detection ──
var _current_season: String = ""

# ── Pending choice event ──
var _current_event: Dictionary = {}


func _ready() -> void:
	_register_seasonal_events()
	EventBus.season_changed.connect(_on_season_changed)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.event_choice_selected.connect(_on_event_choice_selected)


# ═══════════════ EVENT REGISTRATION ═══════════════

func _register_seasonal_events() -> void:
	_season_events["spring"] = _spring_events()
	_season_events["summer"] = _summer_events()
	_season_events["autumn"] = _autumn_events()
	_season_events["winter"] = _winter_events()


func _spring_events() -> Array:
	return [
		{
			"id": "spring_harvest_festival", "name": "春耕祭",
			"desc": "春季来临，农民们举行盛大的春耕祭典，粮食和秩序得到提升。",
			"auto": true,
			"effects": {"food": 5, "order": 2},
		},
		{
			"id": "spring_recruits", "name": "新兵入伍",
			"desc": "春暖花开，各地青年踊跃参军。",
			"auto": false,
			"choices": [
				{"text": "训练新兵 (+3兵力, -10金)", "effects": {"soldiers": 3, "gold": -10}},
				{"text": "强征入伍 (+5兵力, 秩序-2)", "effects": {"soldiers": 5, "order": -2}},
			]
		},
		{
			"id": "spring_hanami", "name": "花见之宴",
			"desc": "樱花盛开，举办宴会可以提升所有英雄好感。",
			"auto": false,
			"choices": [
				{"text": "举办宴会 (-20金, 全英雄好感+1)", "effects": {"gold": -20, "hero_affection_all": 1}},
				{"text": "取消宴会", "effects": {}},
			]
		},
		{
			"id": "spring_plague", "name": "春季疫病",
			"desc": "春季温暖潮湿的气候导致疫病蔓延。",
			"auto": false,
			"choices": [
				{"text": "隔离封锁 (1领地不可移动, 秩序+2)", "effects": {"immobile": true, "order": 2}},
				{"text": "无视疫情 (3领地各-1兵力)", "effects": {"soldiers": -3}},
			]
		},
	]


func _summer_events() -> Array:
	return [
		{
			"id": "summer_heat", "name": "酷暑",
			"desc": "极端酷暑席卷大地，所有军队行动迟缓。",
			"auto": false,
			"choices": [
				{"text": "休整 (-1行动点)", "effects": {"ap": -1}},
				{"text": "顶着酷暑行军", "effects": {}},
			]
		},
		{
			"id": "summer_offensive", "name": "夏季攻势",
			"desc": "夏日炎炎，将士们的战意也随之高涨！",
			"auto": true,
			"effects": {"buff": {"type": "atk_pct", "value": 10, "duration": 2}},
		},
		{
			"id": "summer_pirate_monsoon", "name": "海盗季风",
			"desc": "季风带来了更多的海盗袭击，沿海领地秩序下降。",
			"auto": false,
			"auto_effect": {"order": -2, "coastal": true},
			"choices": [
				{"text": "加强巡逻 (-10金, 防止损失)", "effects": {"gold": -10, "order": 2}},
				{"text": "忍耐", "effects": {}},
			]
		},
		{
			"id": "summer_fire_festival", "name": "火焰节",
			"desc": "盛夏火焰节，是庆祝还是劳作？",
			"auto": false,
			"choices": [
				{"text": "庆祝火焰节 (-15金, +3威望, 秩序+1)", "effects": {"gold": -15, "prestige": 3, "order": 1}},
				{"text": "加紧生产 (+10铁)", "effects": {"iron": 10}},
			]
		},
	]


func _autumn_events() -> Array:
	return [
		{
			"id": "autumn_harvest", "name": "丰收",
			"desc": "秋季大丰收，粮仓充盈，金库也得到补充。",
			"auto": true,
			"effects": {"food": 10, "gold": 5},
		},
		{
			"id": "autumn_conscription", "name": "秋季征兵",
			"desc": "丰收之后，正是征兵的好时机。",
			"auto": false,
			"choices": [
				{"text": "大规模征兵 (+5兵力, -15粮食, 秩序-1)", "effects": {"soldiers": 5, "food": -15, "order": -1}},
				{"text": "适度征兵 (+2兵力)", "effects": {"soldiers": 2}},
			]
		},
		{
			"id": "autumn_spy", "name": "落叶密使",
			"desc": "一名密探带来了敌方情报，揭示了部分迷雾区域。",
			"auto": true,
			"effects": {"reveal": 3},
		},
		{
			"id": "autumn_trade", "name": "贸易季",
			"desc": "秋季是传统的贸易旺季，商队络绎不绝。",
			"auto": false,
			"choices": [
				{"text": "开放市场 (+30金, -5粮食)", "effects": {"gold": 30, "food": -5}},
				{"text": "囤积物资 (+10粮食, +5铁)", "effects": {"food": 10, "iron": 5}},
			]
		},
	]


func _winter_events() -> Array:
	return [
		{
			"id": "winter_harsh", "name": "严冬",
			"desc": "严酷的冬季来临，粮食产量大幅下降。",
			"auto": true,
			"effects": {"food": -5},
		},
		{
			"id": "winter_march", "name": "雪中行军",
			"desc": "大雪封路，是否继续行军？",
			"auto": false,
			"choices": [
				{"text": "冬眠休整 (本回合不出击, 秩序+3)", "effects": {"immobile": true, "order": 3}},
				{"text": "冬季战役 (ATK+15% 对低秩序敌军)", "effects": {"buff": {"type": "atk_pct", "value": 15, "duration": 2}}},
			]
		},
		{
			"id": "winter_shortage", "name": "冬季物资短缺",
			"desc": "冬季物资消耗加剧，粮食告急。",
			"auto": false,
			"auto_effect": {"food": -5},
			"choices": [
				{"text": "配给制 (-2兵力)", "effects": {"soldiers": -2}},
				{"text": "购买物资 (-40金)", "effects": {"gold": -40}},
			]
		},
		{
			"id": "winter_festival", "name": "冰雪祭典",
			"desc": "冬季传统节日，举办盛大的冰雪祭典可以提振士气。",
			"auto": false,
			"choices": [
				{"text": "举办祭典 (-25金, 全英雄好感+1, 秩序+2)", "effects": {"gold": -25, "hero_affection_all": 1, "order": 2}},
				{"text": "取消祭典", "effects": {}},
			]
		},
	]


# ═══════════════ SEASON CHANGE HANDLER ═══════════════

func _on_season_changed(season_id: int, season_data: Dictionary) -> void:
	var season_name: String = season_data.get("name", "")
	# Map season names to keys
	var season_map: Dictionary = {"春": "spring", "夏": "summer", "秋": "autumn", "冬": "winter"}
	for key in season_map:
		if season_name.begins_with(key) or season_data.get("id", "") == season_map[key]:
			_current_season = season_map[key]
			break

	# Also try direct id mapping
	var id_map: Dictionary = {0: "spring", 1: "summer", 2: "autumn", 3: "winter"}
	if id_map.has(season_id):
		_current_season = id_map[season_id]

	_fired_this_season.clear()
	_roll_seasonal_events()


func _on_turn_started(player_id: int) -> void:
	if player_id != 0:
		return
	# Also detect season from WeatherSystem if not yet set
	if _current_season == "" and WeatherSystem != null:
		var sd: Dictionary = WeatherSystem.get_current_season()
		var id_map: Dictionary = {0: "spring", 1: "summer", 2: "autumn", 3: "winter"}
		if id_map.has(sd.get("id", -1)):
			_current_season = id_map[sd["id"]]


# ═══════════════ EVENT ROLLING ═══════════════

func _roll_seasonal_events() -> void:
	var current_turn: int = 0
	if "current_turn" in GameManager:
		current_turn = GameManager.current_turn

	if current_turn - _last_seasonal_event_turn < SEASONAL_COOLDOWN:
		return

	if not _season_events.has(_current_season):
		return

	var available: Array = _season_events[_current_season].duplicate()
	available.shuffle()

	# Fire 1-2 events per season change
	var count: int = randi_range(1, 2)
	var fired: int = 0

	for evt in available:
		if fired >= count:
			break
		if _fired_this_season.has(evt["id"]):
			continue

		_fired_this_season.append(evt["id"])
		_last_seasonal_event_turn = current_turn
		_fire_seasonal_event(evt)
		fired += 1


func _fire_seasonal_event(event: Dictionary) -> void:
	var pid: int = GameManager.current_player_index if "current_player_index" in GameManager else 0

	# Apply auto effects first
	if event.has("auto_effect"):
		_apply_resource_effects(pid, event["auto_effect"])

	if event.get("auto", false):
		# Auto events apply effects directly without choice
		_apply_resource_effects(pid, event.get("effects", {}))
		EventBus.message_log.emit("[color=cyan][季节事件] %s: %s[/color]" % [event["name"], event["desc"]])
		return

	# Choice-based event — route through EventScheduler
	_current_event = event
	var choice_texts: Array = []
	for c in event.get("choices", []):
		choice_texts.append(c["text"])

	if EventScheduler:
		EventScheduler.submit_candidate(
			event["id"],
			"seasonal_event",
			EventScheduler.PRIORITY_LOW,
			1.0,
			{"name": event["name"], "description": event["desc"], "choices": choice_texts, "source_type": "seasonal_event"}
		)
	else:
		EventBus.show_event_popup.emit(event["name"], event["desc"], choice_texts)
	EventBus.message_log.emit("[color=cyan][季节事件] %s[/color]" % event["name"])


# ═══════════════ CHOICE HANDLING ═══════════════

func _on_event_choice_selected(choice_index: int) -> void:
	if _current_event.is_empty():
		return

	var choices: Array = _current_event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		_current_event = {}
		return

	var effects: Dictionary = choices[choice_index].get("effects", {})
	var pid: int = GameManager.current_player_index if "current_player_index" in GameManager else 0
	_apply_resource_effects(pid, effects)
	_current_event = {}


# ═══════════════ EFFECT APPLICATION ═══════════════

func _apply_resource_effects(pid: int, effects: Dictionary) -> void:
	# Route through centralized EffectResolver if available
	if EffectResolver:
		EffectResolver.resolve(effects, {"player_id": pid, "source": "seasonal_event", "event_id": _current_event.get("id", "seasonal")})
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
		BuffManager.add_buff(pid, "seasonal_%s" % buff.get("type", ""), buff.get("type", ""), buff.get("value", 0), buff.get("duration", 1), "seasonal_event")

	# Immobile
	if effects.has("immobile") and effects["immobile"]:
		EventBus.message_log.emit("[color=yellow]本回合移动受限[/color]")

	# Hero affection all
	if effects.has("hero_affection_all"):
		var aff_val: int = effects["hero_affection_all"]
		var _se_pid: int = GameManager.get_human_player_id() if GameManager else 0
		if HeroSystem != null and HeroSystem.has_method("get_recruited_heroes"):
			var heroes: Array = HeroSystem.get_recruited_heroes(_se_pid)
			for hero_id in heroes:
				if HeroSystem.has_method("change_affection"):
					HeroSystem.change_affection(hero_id, aff_val)
				EventBus.hero_affection_changed.emit(hero_id, aff_val)
		EventBus.message_log.emit("[color=pink]所有英雄好感度 +%d[/color]" % aff_val)

	# Reveal
	if effects.has("reveal"):
		var count: int = effects["reveal"]
		var unrevealed: Array = []
		if "tiles" in GameManager:
			for t in GameManager.tiles:
				if not t.get("revealed", false):
					unrevealed.append(t)
		unrevealed.shuffle()
		var to_reveal: int = mini(count, unrevealed.size())
		for i in range(to_reveal):
			unrevealed[i]["revealed"] = true
		if to_reveal > 0:
			EventBus.message_log.emit("揭示了 %d 格迷雾" % to_reveal)

	# AP cost
	if effects.has("ap"):
		EventBus.message_log.emit("[color=yellow]行动点变化: %+d[/color]" % effects["ap"])


# ═══════════════ SAVE / LOAD ═══════════════

func get_save_data() -> Dictionary:
	return {
		"last_seasonal_event_turn": _last_seasonal_event_turn,
		"fired_this_season": _fired_this_season.duplicate(),
		"current_season": _current_season,
	}


func load_save_data(data: Dictionary) -> void:
	_last_seasonal_event_turn = data.get("last_seasonal_event_turn", -10)
	_fired_this_season = data.get("fired_this_season", [])
	_current_season = data.get("current_season", "")
