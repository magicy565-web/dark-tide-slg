## grand_event_director.gd - Full-screen cinematic event presentation (v1.0)
## Handles major story milestones with dramatic VN-style presentation.
extends Node

# ── Grand event definitions ──
var _grand_events: Array = []

# ── Tracking which grand events have triggered (once per game) ──
var _triggered_events: Dictionary = {}  # event_id -> true

# ── Currently playing grand event ──
var _current_grand_event: Dictionary = {}
var _is_playing: bool = false


func _ready() -> void:
	_register_grand_events()
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.event_choice_selected.connect(_on_event_choice_selected)


# ═══════════════ GRAND EVENT REGISTRATION ═══════════════

func _register_grand_events() -> void:
	_grand_events.append({
		"id": "ge_dark_tide_rising", "name": "暗潮涌动",
		"desc": "黑暗势力开始在大陆蔓延，各方势力蠢蠢欲动……",
		"condition": "turn_1",
		"dialogue": [
			{"speaker": "", "text": "大陆的天空被阴云笼罩，暗潮正在涌动。"},
			{"speaker": "", "text": "各方势力在废墟上争夺着霸权，战争的号角已经吹响。"},
			{"speaker": "", "text": "你的命运，将由你自己书写。"},
		],
		"bgm": "bgm_prologue",
		"choices": [],
	})

	_grand_events.append({
		"id": "ge_first_blood", "name": "第一滴血",
		"desc": "第一个势力被消灭，大陆格局发生剧变。",
		"condition": "first_faction_destroyed",
		"dialogue": [
			{"speaker": "", "text": "第一个势力覆灭了，他们的旗帜永远倒下。"},
			{"speaker": "", "text": "残存的势力感到了恐惧，也看到了机会。"},
			{"speaker": "", "text": "大陆的力量平衡已经被打破，更激烈的冲突即将到来。"},
		],
		"bgm": "bgm_dramatic",
		"choices": [
			{"text": "巩固领地", "effects": {"order": 3}},
			{"text": "乘胜追击", "effects": {"buff": {"type": "atk_pct", "value": 10, "duration": 3}}},
		],
	})

	_grand_events.append({
		"id": "ge_three_kingdoms", "name": "三足鼎立",
		"desc": "大陆上仅剩三大势力，最终的决战即将来临。",
		"condition": "three_factions_remain",
		"dialogue": [
			{"speaker": "", "text": "硝烟散尽，大陆上仅存三方势力。"},
			{"speaker": "", "text": "三足鼎立的局面意味着——任何一次失误都可能是致命的。"},
			{"speaker": "", "text": "最终的胜者，将统一这片大陆。"},
		],
		"bgm": "bgm_tension",
		"choices": [
			{"text": "外交斡旋 (威胁-10)", "effects": {"threat": -10}},
			{"text": "全面备战 (+10兵力, -50金)", "effects": {"soldiers": 10, "gold": -50}},
		],
	})

	_grand_events.append({
		"id": "ge_dawn_approaches", "name": "黎明之前",
		"desc": "你已控制大陆半数以上的领土，胜利在望。",
		"condition": "player_50pct_map",
		"dialogue": [
			{"speaker": "", "text": "你的旗帜飘扬在大陆的每一个角落。"},
			{"speaker": "", "text": "敌人在颤抖，盟友在欢呼。"},
			{"speaker": "", "text": "黎明前最黑暗的时刻——也是最关键的时刻。"},
			{"speaker": "", "text": "坚持住，胜利就在眼前。"},
		],
		"bgm": "bgm_epic",
		"choices": [
			{"text": "发表胜利演说 (+10威望, 秩序+5)", "effects": {"prestige": 10, "order": 5}},
			{"text": "保持警惕 (威胁-15)", "effects": {"threat": -15}},
		],
	})

	_grand_events.append({
		"id": "ge_final_battle", "name": "最终决战",
		"desc": "大陆上仅剩你和最后的敌人，命运的决战即将开始。",
		"condition": "two_factions_remain",
		"dialogue": [
			{"speaker": "", "text": "大陆上的硝烟终于只剩下最后一缕。"},
			{"speaker": "", "text": "你与最后的对手隔着战场对峙。"},
			{"speaker": "", "text": "这将是一场决定一切的战斗。"},
			{"speaker": "", "text": "为了荣耀，为了生存——决战吧！"},
		],
		"bgm": "bgm_final_battle",
		"choices": [
			{"text": "全军出击 (ATK+20% 5回合)", "effects": {"buff": {"type": "atk_pct", "value": 20, "duration": 5}}},
			{"text": "稳扎稳打 (+5兵力, 秩序+3)", "effects": {"soldiers": 5, "order": 3}},
		],
	})

	_grand_events.append({
		"id": "ge_victory", "name": "暗潮退去",
		"desc": "你统一了大陆，暗潮终于退去。",
		"condition": "victory",
		"dialogue": [
			{"speaker": "", "text": "战争结束了。"},
			{"speaker": "", "text": "你站在废墟之上，看着黎明的曙光穿透乌云。"},
			{"speaker": "", "text": "这片大陆终于迎来了和平——"},
			{"speaker": "", "text": "但和平能持续多久，取决于你今后的选择。"},
		],
		"bgm": "bgm_victory",
		"choices": [],
	})

	_grand_events.append({
		"id": "ge_threat_critical", "name": "威胁降临",
		"desc": "威胁等级已到达危险水平，各方势力开始联合对抗你。",
		"condition": "threat_80_plus",
		"dialogue": [
			{"speaker": "", "text": "你的扩张引起了所有势力的恐慌。"},
			{"speaker": "", "text": "暗地里，敌人们正在结成同盟。"},
			{"speaker": "", "text": "如果不采取措施，你将面对所有人的围攻。"},
		],
		"bgm": "bgm_ominous",
		"choices": [
			{"text": "外交安抚 (-80金, 威胁-20)", "effects": {"gold": -80, "threat": -20}},
			{"text": "加固防线 (+5兵力, 秩序+3)", "effects": {"soldiers": 5, "order": 3}},
		],
	})

	_grand_events.append({
		"id": "ge_hero_assembly", "name": "英雄集结",
		"desc": "十位以上的英雄聚集在你的麾下，这是前所未有的壮举。",
		"condition": "heroes_10_plus",
		"dialogue": [
			{"speaker": "", "text": "来自各方的英雄齐聚一堂。"},
			{"speaker": "", "text": "他们因为你的魅力和信念而汇聚。"},
			{"speaker": "", "text": "有了这些强大的伙伴，没有什么是不可能的。"},
		],
		"bgm": "bgm_heroic",
		"choices": [
			{"text": "举办英雄大会 (-30金, 全英雄好感+2)", "effects": {"gold": -30, "hero_affection_all": 2}},
			{"text": "分配任务 (+10威望)", "effects": {"prestige": 10}},
		],
	})

	_grand_events.append({
		"id": "ge_empire_crumbles", "name": "帝国崩塌",
		"desc": "你失去了大量领土，帝国正在崩塌的边缘。",
		"condition": "player_lost_50pct",
		"dialogue": [
			{"speaker": "", "text": "一个接一个的领地沦陷……"},
			{"speaker": "", "text": "将士们的士气跌到了谷底。"},
			{"speaker": "", "text": "但只要你还站着，就还有希望。"},
			{"speaker": "", "text": "是时候做出艰难的选择了。"},
		],
		"bgm": "bgm_desperate",
		"choices": [
			{"text": "背水一战 (ATK+30% 3回合, 秩序-5)", "effects": {"buff": {"type": "atk_pct", "value": 30, "duration": 3}, "order": -5}},
			{"text": "收缩防线 (+10兵力, 秩序+5)", "effects": {"soldiers": 10, "order": 5}},
		],
	})


# ═══════════════ CONDITION CHECKING ═══════════════

func _on_turn_started(player_id: int) -> void:
	if player_id != 0:
		return
	if _is_playing:
		return
	_check_grand_events()


func _check_grand_events() -> void:
	for ge in _grand_events:
		var gid: String = ge["id"]
		if _triggered_events.has(gid):
			continue
		if _evaluate_condition(ge["condition"]):
			_trigger_grand_event(ge)
			return  # Only one grand event per turn


func _evaluate_condition(condition: String) -> bool:
	match condition:
		"turn_1":
			var turn: int = GameManager.current_turn if "current_turn" in GameManager else 0
			return turn <= 1

		"first_faction_destroyed":
			return _count_destroyed_factions() >= 1

		"three_factions_remain":
			return _count_active_factions() == 3

		"two_factions_remain":
			return _count_active_factions() == 2

		"player_50pct_map":
			return _get_player_tile_pct() >= 0.5

		"player_lost_50pct":
			return _get_player_tile_pct() < 0.25 and _get_current_turn() > 10

		"victory":
			return _count_active_factions() == 1

		"threat_80_plus":
			if ThreatManager != null and "threat" in ThreatManager:
				return ThreatManager.threat >= 80
			if ThreatManager != null and ThreatManager.has_method("get_threat"):
				return ThreatManager.get_threat() >= 80
			return false

		"heroes_10_plus":
			if HeroSystem != null and HeroSystem.has_method("get_recruited_heroes"):
				return HeroSystem.get_recruited_heroes().size() >= 10
			return false

	return false


func _count_destroyed_factions() -> int:
	var count: int = 0
	if GameManager.has_method("get_all_factions"):
		var factions: Array = GameManager.get_all_factions()
		for f in factions:
			if f.get("destroyed", false) or f.get("eliminated", false):
				count += 1
	elif "players" in GameManager:
		for p in GameManager.players:
			if p.get("eliminated", false) and p.get("is_ai", false):
				count += 1
	return count


func _count_active_factions() -> int:
	var count: int = 0
	if "players" in GameManager:
		for p in GameManager.players:
			if not p.get("eliminated", false):
				count += 1
	return count


func _get_player_tile_pct() -> float:
	if "tiles" not in GameManager:
		return 0.0
	var pid: int = GameManager.current_player_index if "current_player_index" in GameManager else 0
	var total: int = GameManager.tiles.size()
	if total == 0:
		return 0.0
	var owned: int = 0
	for t in GameManager.tiles:
		if t.get("owner", -1) == pid:
			owned += 1
	return float(owned) / float(total)


func _get_current_turn() -> int:
	return GameManager.current_turn if "current_turn" in GameManager else 0


# ═══════════════ GRAND EVENT TRIGGERING ═══════════════

func _trigger_grand_event(ge: Dictionary) -> void:
	_triggered_events[ge["id"]] = true
	_current_grand_event = ge
	_is_playing = true

	EventBus.message_log.emit("[color=gold]══ [重大事件] %s ══[/color]" % ge["name"])

	# Try VnDirector for cinematic presentation
	if VnDirector != null and VnDirector.has_method("play_sequence"):
		var sequence: Array = _build_vn_sequence(ge)
		VnDirector.play_sequence(sequence)
	else:
		# Fallback: use event popup
		_show_grand_event_popup(ge)

	# Set BGM
	if ge.has("bgm") and AudioManager != null:
		if AudioManager.has_method("play_bgm"):
			AudioManager.play_bgm(ge["bgm"])

	# Record in StoryEventSystem
	if StoryEventSystem != null and StoryEventSystem.has_method("record_event"):
		StoryEventSystem.record_event(ge["id"], ge["name"])

	# Emit grand event signals
	if EventBus.has_signal("grand_event_started"):
		EventBus.grand_event_started.emit(ge["id"])


func _build_vn_sequence(ge: Dictionary) -> Array:
	var sequence: Array = []
	for line in ge.get("dialogue", []):
		sequence.append({
			"type": "dialogue",
			"speaker": line.get("speaker", ""),
			"text": line.get("text", ""),
		})
	return sequence


func _show_grand_event_popup(ge: Dictionary) -> void:
	var full_desc: String = ge["desc"] + "\n\n"
	for line in ge.get("dialogue", []):
		var speaker: String = line.get("speaker", "")
		if speaker != "":
			full_desc += "【%s】: %s\n" % [speaker, line["text"]]
		else:
			full_desc += "%s\n" % line["text"]

	var choice_texts: Array = []
	for c in ge.get("choices", []):
		choice_texts.append(c["text"])

	if choice_texts.is_empty():
		choice_texts.append("继续")

	EventBus.show_event_popup.emit(ge["name"], full_desc, choice_texts)


# ═══════════════ CHOICE HANDLING ═══════════════

func _on_event_choice_selected(choice_index: int) -> void:
	if _current_grand_event.is_empty():
		return

	var choices: Array = _current_grand_event.get("choices", [])
	if choice_index >= 0 and choice_index < choices.size():
		var effects: Dictionary = choices[choice_index].get("effects", {})
		_apply_grand_effects(effects)

	# End grand event
	var gid: String = _current_grand_event.get("id", "")
	_current_grand_event = {}
	_is_playing = false

	if EventBus.has_signal("grand_event_ended"):
		EventBus.grand_event_ended.emit(gid)


func _apply_grand_effects(effects: Dictionary) -> void:
	var pid: int = GameManager.current_player_index if "current_player_index" in GameManager else 0

	# Resources
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
		BuffManager.add_buff(pid, "grand_%s" % buff.get("type", ""), buff.get("type", ""), buff.get("value", 0), buff.get("duration", 1), "grand_event")

	# Hero affection all
	if effects.has("hero_affection_all"):
		var aff_val: int = effects["hero_affection_all"]
		if HeroSystem != null and HeroSystem.has_method("get_recruited_heroes"):
			var heroes: Array = HeroSystem.get_recruited_heroes()
			for hero_id in heroes:
				if HeroSystem.has_method("change_affection"):
					HeroSystem.change_affection(hero_id, aff_val)
				EventBus.hero_affection_changed.emit(hero_id, aff_val)
		EventBus.message_log.emit("[color=pink]所有英雄好感度 +%d[/color]" % aff_val)


# ═══════════════ SAVE / LOAD ═══════════════

func get_save_data() -> Dictionary:
	return {
		"triggered_events": _triggered_events.duplicate(),
	}


func load_save_data(data: Dictionary) -> void:
	_triggered_events = data.get("triggered_events", {})
	_is_playing = false
	_current_grand_event = {}
