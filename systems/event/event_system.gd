## event_system.gd - Random event engine with 20 events and 2-choice system (v0.8.7)
## Hooks into GameManager turn loop. Handles DOT, combat, lose_node, reveal,
## immobile, temp_soldiers, debuff, gold_delayed, special_npc effects.
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")
const SideQuestData = preload("res://systems/quest/side_quest_data.gd")

# Event structure: { id, name, desc, condition, repeatable, choices: [{text, effects}] }
var _events := []
var _triggered_this_turn := []

# ── Deduplication: non-repeatable events fire at most once per game ──
var _triggered_ids: Dictionary = {}  # event_id -> true

# ── DOT (damage-over-time) active effects ──
# Array of { "resource_key": String, "delta": int, "remaining": int }
var _active_dots: Array = []

# ── Delayed gold grants (pirate shipwreck "标记" effect) ──
var _pending_gold: int = 0

# ── Immobile flag: set by events, cleared at start of next event phase ──
var _immobile_this_turn: bool = false

# ── Temporary soldiers granted by mercenaries (expire after 3 turns) ──
# Array of { "count": int, "remaining": int }
var _temp_soldier_batches: Array = []

# ── Pending event queue (events rolled, awaiting player choices) ──
var _pending_events: Array = []


func _ready() -> void:
	_register_events()
	register_world_events()


func reset() -> void:
	_triggered_this_turn.clear()
	_triggered_ids.clear()
	_active_dots.clear()
	_pending_gold = 0
	_immobile_this_turn = false
	_temp_soldier_batches.clear()
	_pending_events.clear()
	_world_events.clear()
	_world_event_triggered_ids.clear()


# ═══════════════ EVENT REGISTRATION ═══════════════
# "repeatable": true means universal events that can fire every game.
# Non-repeatable (faction/threat events) fire at most once per game.

func _register_events() -> void:
	# === UNIVERSAL EVENTS (1-10) - repeatable ===
	_events.append({
		"id": "refugee_camp", "name": "流民营地",
		"desc": "发现一群无家可归的难民。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "奴役 (+3奴隶)", "effects": {"slaves": 3}},
			{"text": "屠杀 (+2兵力, 秩序-2)", "effects": {"soldiers": 2, "order": -2}},
		]
	})
	_events.append({
		"id": "abandoned_mine", "name": "废弃矿洞",
		"desc": "洞穴深处传来微光。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "探索 (60%+15铁, 40%损失2兵)", "effects": {"type": "gamble", "success_rate": 0.6, "success": {"iron": 15}, "fail": {"soldiers": -2}}},
			{"text": "放弃", "effects": {}},
		]
	})
	_events.append({
		"id": "plague", "name": "瘟疫蔓延",
		"desc": "领地内爆发疫病。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "隔离 (-3奴隶)", "effects": {"slaves": -3}},
			{"text": "不管 (-1兵/回合x3)", "effects": {"type": "dot", "soldiers": -1, "duration": 3}},
		]
	})
	_events.append({
		"id": "black_trader", "name": "黑商来访",
		"desc": "一位神秘商人提出交易。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "交易 (-50金, +随机道具)", "effects": {"gold": -50, "item": "random"}},
			{"text": "抢劫 (70%+80金, 30%损3兵)", "effects": {"type": "gamble", "success_rate": 0.7, "success": {"gold": 80}, "fail": {"soldiers": -3}}},
		]
	})
	_events.append({
		"id": "ancient_ruins", "name": "远古遗迹",
		"desc": "发现一座上古废墟。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "挖掘 (-5奴隶, +1遗物)", "effects": {"slaves": -5, "relic": true}},
			{"text": "炸毁 (+20铁+10金)", "effects": {"iron": 20, "gold": 10}},
		]
	})
	_events.append({
		"id": "rebel_remnant", "name": "叛军残部",
		"desc": "遭遇一支溃败的叛军。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "收编 (+3兵, 秩序-1)", "effects": {"soldiers": 3, "order": -1}},
			{"text": "消灭 (+2奴隶, 威望+3)", "effects": {"slaves": 2, "prestige": 3}},
		]
	})
	_events.append({
		"id": "blizzard", "name": "暴风雪",
		"desc": "极端天气席卷全图。",
		"condition": "turn_gte_5", "repeatable": true,
		"choices": [
			{"text": "固守 (本回合不可移动, -5粮)", "effects": {"food": -5, "immobile": true}},
			{"text": "强行军 (-2兵)", "effects": {"soldiers": -2}},
		]
	})
	_events.append({
		"id": "slave_treasure", "name": "奴隶献宝",
		"desc": "一名奴隶声称知道宝藏位置。",
		"condition": "has_slaves", "repeatable": true,
		"choices": [
			{"text": "信任 (70%+30金+10铁, 30%-1奴隶)", "effects": {"type": "gamble", "success_rate": 0.7, "success": {"gold": 30, "iron": 10}, "fail": {"slaves": -1}}},
			{"text": "无视", "effects": {}},
		]
	})
	_events.append({
		"id": "mercenaries", "name": "佣兵团",
		"desc": "一队佣兵愿意为金币而战。",
		"condition": "gold_gte_80", "repeatable": true,
		"choices": [
			{"text": "雇佣 (-80金, +5临时兵)", "effects": {"gold": -80, "temp_soldiers": 5}},
			{"text": "拒绝", "effects": {}},
		]
	})
	_events.append({
		"id": "blood_ritual", "name": "祭祀仪式",
		"desc": "部下要求举行血祭。",
		"condition": "has_slaves", "repeatable": true,
		"choices": [
			{"text": "允许 (-2奴隶, ATK+15% 3回合)", "effects": {"slaves": -2, "buff": {"type": "atk_pct", "value": 15, "duration": 3}}},
			{"text": "拒绝 (秩序-2)", "effects": {"order": -2}},
		]
	})

	# === FACTION EVENTS (11-16) - once per game ===
	_events.append({
		"id": "orc_infighting", "name": "内斗爆发",
		"desc": "两个头目争夺权力。",
		"condition": "faction_orc", "repeatable": false,
		"choices": [
			{"text": "决斗裁决 (-1兵, WAAAGH+15)", "effects": {"soldiers": -1, "waaagh": 15}},
			{"text": "镇压 (-3兵, 秩序+3)", "effects": {"soldiers": -3, "order": 3}},
		]
	})
	_events.append({
		"id": "orc_mushroom", "name": "蘑菇酒宴",
		"desc": "部落发现大量蘑菇酒。",
		"condition": "faction_orc", "repeatable": false,
		"choices": [
			{"text": "豪饮 (WAAAGH+20, 下回合不可动)", "effects": {"waaagh": 20, "immobile": true}},
			{"text": "储存 (+10粮)", "effects": {"food": 10}},
		]
	})
	_events.append({
		"id": "pirate_shipwreck", "name": "沉船宝藏",
		"desc": "发现一艘沉没的商船。",
		"condition": "faction_pirate", "repeatable": false,
		"choices": [
			{"text": "打捞 (-10铁, +60金+1道具)", "effects": {"iron": -10, "gold": 60, "item": "random"}},
			{"text": "标记 (下次+30金)", "effects": {"gold_delayed": 30}},
		]
	})
	_events.append({
		"id": "pirate_mutiny", "name": "船员哗变",
		"desc": "部分手下不满分赃。",
		"condition": "faction_pirate", "repeatable": false,
		"choices": [
			{"text": "让步 (-30金)", "effects": {"gold": -30}},
			{"text": "处决 (-2兵, 掠夺+5)", "effects": {"soldiers": -2, "plunder": 5}},
		]
	})
	_events.append({
		"id": "de_whisper", "name": "暗影低语",
		"desc": "奴隶中传出诡异耳语。",
		"condition": "faction_dark_elf", "repeatable": false,
		"choices": [
			{"text": "调查 (+1特殊NPC)", "effects": {"special_npc": true}},
			{"text": "处决传播者 (-2奴隶, 秩序+2)", "effects": {"slaves": -2, "order": 2}},
		]
	})
	_events.append({
		"id": "de_conspiracy", "name": "议会阴谋",
		"desc": "暗精灵内部有人密谋叛变。",
		"condition": "faction_dark_elf", "repeatable": false,
		"choices": [
			{"text": "先发制人 (-1奴隶, 揭示2迷雾)", "effects": {"slaves": -1, "reveal": 2}},
			{"text": "静观 (30%无事, 70%失1据点)", "effects": {"type": "gamble", "success_rate": 0.3, "success": {}, "fail": {"lose_node": true}}},
		]
	})

	# === LIGHT COUNTER EVENTS (17-20) - once per game ===
	_events.append({
		"id": "knight_patrol", "name": "女骑士巡逻",
		"desc": "人类女骑士率队突袭边境。",
		"condition": "threat_gte_30", "repeatable": false,
		"choices": [
			{"text": "迎战 (战斗: 敌8兵)", "effects": {"type": "combat", "enemy_soldiers": 8}},
			{"text": "撤退 (放弃边境据点)", "effects": {"lose_node": true}},
		]
	})
	_events.append({
		"id": "elf_curse", "name": "精灵诅咒",
		"desc": "精灵法师对领地施加诅咒。",
		"condition": "threat_gte_30", "repeatable": false,
		"choices": [
			{"text": "解咒 (-20金)", "effects": {"gold": -20}},
			{"text": "硬扛 (产出-20% 3回合)", "effects": {"debuff": {"type": "income_pct", "value": -20, "duration": 3}}},
		]
	})
	_events.append({
		"id": "arcane_storm", "name": "奥术风暴",
		"desc": "法师族释放区域魔法风暴。",
		"condition": "threat_gte_50", "repeatable": false,
		"choices": [
			{"text": "魔法防护 (-3魔晶)", "effects": {"magic_crystal": -3}},
			{"text": "硬抗 (-4兵全军)", "effects": {"soldiers": -4}},
		]
	})
	_events.append({
		"id": "holy_crusade", "name": "圣战号召",
		"desc": "三族联军发起十字军东征。",
		"condition": "threat_gte_80", "repeatable": false,
		"choices": [
			{"text": "全力迎战 (大型战斗)", "effects": {"type": "combat", "enemy_soldiers": 20}},
			{"text": "战略撤退 (放弃2据点, 威胁-10)", "effects": {"lose_nodes": 2, "threat": -10}},
		]
	})


# ═══════════════ CONDITION CHECKS ═══════════════

func check_condition(event: Dictionary) -> bool:
	var pid: int = GameManager.get_human_player_id()
	var faction_id: int = GameManager.get_player_faction(pid)
	match event["condition"]:
		"always":
			return true
		"turn_gte_5":
			return GameManager.turn_number >= 5
		"has_slaves":
			return ResourceManager.get_resource(pid, "slaves") > 0
		"gold_gte_80":
			return ResourceManager.get_resource(pid, "gold") >= 80
		"faction_orc":
			return faction_id == FactionData.FactionID.ORC
		"faction_pirate":
			return faction_id == FactionData.FactionID.PIRATE
		"faction_dark_elf":
			return faction_id == FactionData.FactionID.DARK_ELF
		"threat_gte_30":
			return ThreatManager.get_threat() >= 30
		"threat_gte_50":
			return ThreatManager.get_threat() >= 50
		"threat_gte_80":
			return ThreatManager.get_threat() >= 80
	return false


# ═══════════════ EVENT ROLLING ═══════════════

## Roll for random events this turn (called during Events phase).
## Respects deduplication: non-repeatable events only fire once per game.
func roll_events(max_events: int = 2) -> Array:
	_triggered_this_turn.clear()
	var eligible := []
	for event in _events:
		# Skip non-repeatable events already triggered this game
		if not event.get("repeatable", false) and _triggered_ids.has(event["id"]):
			continue
		if not check_condition(event):
			# BUG修复: 不满足条件的非重复事件不应标记为已触发，否则条件
			# 后续满足时也无法触发（如faction_orc事件在选择兽人后永远无法触发）
			continue
		eligible.append(event)
	eligible.shuffle()
	var triggered := []
	for i in range(mini(max_events, eligible.size())):
		var ev: Dictionary = eligible[i]
		triggered.append(ev)
		_triggered_this_turn.append(ev["id"])
		# Mark non-repeatable events as used
		if not ev.get("repeatable", false):
			_triggered_ids[ev["id"]] = true
	return triggered


## Returns true if the player is immobilised this turn by an event effect.
func is_immobile() -> bool:
	return _immobile_this_turn


# ═══════════════ WORLD EVENTS (from SideQuestData) ═══════════════

## World events registered from SideQuestData.WORLD_EVENTS.
## These are non-repeatable narrative events checked each turn.
var _world_events: Array = []
var _world_event_triggered_ids: Dictionary = {}  # event_id -> true


func register_world_events() -> void:
	## Load world events from SideQuestData and register them for per-turn checking.
	_world_events.clear()
	_world_event_triggered_ids.clear()
	if SideQuestData.WORLD_EVENTS.is_empty():
		return
	for we in SideQuestData.WORLD_EVENTS:
		_world_events.append(we)


func check_world_events() -> Array:
	## Check and trigger world events this turn. Returns triggered events.
	var triggered: Array = []
	var pid: int = GameManager.get_human_player_id()
	for we in _world_events:
		var eid: String = we.get("id", "")
		if _world_event_triggered_ids.has(eid):
			continue
		# Evaluate trigger conditions
		var trigger: Dictionary = we.get("trigger", {})
		if not _check_world_event_trigger(trigger, pid):
			continue
		# Trigger the event
		_world_event_triggered_ids[eid] = true
		triggered.append(we)
		# Show event popup
		var popup_data: Dictionary = {
			"title": we.get("name", ""),
			"desc": we.get("desc", ""),
		}
		if EventBus.has_signal("show_event_popup"):
			EventBus.show_event_popup.emit(popup_data)
		# Apply player effects
		var effects: Dictionary = we.get("effects", {})
		if not effects.is_empty():
			_apply_world_event_effects(effects, pid)
		# Apply AI effects to AI factions
		var ai_effects: Dictionary = we.get("ai_effects", {})
		if not ai_effects.is_empty():
			_apply_ai_effects(ai_effects)
		EventBus.message_log.emit("[color=cyan][世界事件] %s[/color]" % we.get("name", ""))
	return triggered


func _check_world_event_trigger(trigger: Dictionary, player_id: int) -> bool:
	for key in trigger:
		match key:
			"turn_min":
				if GameManager.turn_number < trigger[key]:
					return false
			"tiles_min":
				var c: int = 0
				for tile in GameManager.tiles:
					if tile.get("owner_id", -1) == player_id:
						c += 1
				if c < trigger[key]:
					return false
			"threat_min":
				if ThreatManager.get_threat() < trigger[key]:
					return false
			"battles_won_min":
				var stats: Dictionary = QuestJournal.get_stats() if QuestJournal.has_method("get_stats") else {}
				if stats.get("battles_won", 0) < trigger[key]:
					return false
			"side_quest_completed":
				if not QuestJournal.has_method("_is_completed"):
					return false
				if not QuestJournal._is_completed(QuestJournal._side_progress, trigger[key]):
					return false
	return true


func _apply_world_event_effects(effects: Dictionary, player_id: int) -> void:
	for key in effects:
		match key:
			"gold":
				ResourceManager.apply_delta(player_id, {"gold": effects[key]})
			"food":
				ResourceManager.apply_delta(player_id, {"food": effects[key]})
			"iron":
				ResourceManager.apply_delta(player_id, {"iron": effects[key]})
			"prestige":
				ResourceManager.apply_delta(player_id, {"prestige": effects[key]})
			"order":
				OrderManager.change_order(effects[key])
			"threat":
				ThreatManager.change_threat(effects[key])
			"soldiers":
				if effects[key] > 0:
					ResourceManager.add_army(player_id, effects[key])
				else:
					ResourceManager.remove_army(player_id, -effects[key])
			"reveal":
				_apply_reveal(player_id, effects[key])
			"buff":
				var buff: Dictionary = effects[key]
				BuffManager.add_buff(player_id, "world_%s" % buff.get("type", ""), buff.get("type", ""), buff.get("value", 0), buff.get("duration", 1), "world_event")


func _apply_ai_effects(ai_effects: Dictionary) -> void:
	## Apply effects to all AI factions.
	var ai_ids: Array = GameManager.get_ai_player_ids() if GameManager.has_method("get_ai_player_ids") else []
	for ai_id in ai_ids:
		for key in ai_effects:
			match key:
				"soldiers":
					if ai_effects[key] > 0:
						ResourceManager.add_army(ai_id, ai_effects[key])
					else:
						ResourceManager.remove_army(ai_id, -ai_effects[key])
				"gold":
					ResourceManager.apply_delta(ai_id, {"gold": ai_effects[key]})
				"threat":
					ThreatManager.change_threat(ai_effects[key])
				"order":
					OrderManager.change_order(ai_effects[key])
				"buff":
					var buff: Dictionary = ai_effects[key]
					BuffManager.add_buff(ai_id, "world_ai_%s" % buff.get("type", ""), buff.get("type", ""), buff.get("value", 0), buff.get("duration", 1), "world_event")


## Called by GameManager at the start of the event phase each turn.
## Processes DOTs, delayed gold, temp soldier expiry, then rolls new events.
func process_turn_start() -> void:
	# Clear previous immobile flag
	_immobile_this_turn = false

	var pid: int = GameManager.get_human_player_id()

	# ── Tick active DOTs ──
	var remaining_dots: Array = []
	for dot in _active_dots:
		var key: String = dot["resource_key"]
		var delta: int = dot["delta"]
		if key == "soldiers":
			if delta < 0:
				ResourceManager.remove_army(pid, -delta)
				EventBus.message_log.emit("[color=yellow]瘟疫持续: 损失%d名士兵 (剩余%d回合)[/color]" % [-delta, dot["remaining"] - 1])
			else:
				ResourceManager.add_army(pid, delta)
		else:
			ResourceManager.apply_delta(pid, {key: delta})
		dot["remaining"] -= 1
		if dot["remaining"] > 0:
			remaining_dots.append(dot)
	_active_dots = remaining_dots

	# ── Grant delayed gold ──
	if _pending_gold > 0:
		ResourceManager.apply_delta(pid, {"gold": _pending_gold})
		EventBus.message_log.emit("[color=green]延迟金币到账: +%d金[/color]" % _pending_gold)
		_pending_gold = 0

	# ── Expire temp soldiers ──
	var remaining_batches: Array = []
	for batch in _temp_soldier_batches:
		batch["remaining"] -= 1
		if batch["remaining"] <= 0:
			# Temp soldiers leave — clamp to prevent negative army
			var current_army: int = ResourceManager.get_army(pid)
			var count: int = mini(batch["count"], maxi(0, current_army - 1))
			if count > 0:
				ResourceManager.remove_army(pid, count)
				EventBus.message_log.emit("[color=yellow]佣兵合同到期: %d名临时士兵离开[/color]" % count)
		else:
			remaining_batches.append(batch)
	_temp_soldier_batches = remaining_batches

	# ── Check world events ──
	check_world_events()


# ═══════════════ CHOICE APPLICATION ═══════════════

## Apply the chosen effect from an event
func apply_choice(event_id: String, choice_index: int) -> Dictionary:
	var event: Dictionary = {}
	for e in _events:
		if e["id"] == event_id:
			event = e
			break
	if event.is_empty() or choice_index >= event["choices"].size():
		push_warning("EventSystem: apply_choice failed for event_id='%s' choice_index=%d" % [event_id, choice_index])
		return {"ok": false}

	var effects: Dictionary = event["choices"][choice_index]["effects"]
	var result := {"ok": true, "applied": []}
	var pid: int = GameManager.get_human_player_id()

	# Handle gamble type
	if effects.get("type") == "gamble":
		if randf() <= effects["success_rate"]:
			effects = effects["success"]
			result["gamble_result"] = "success"
		else:
			effects = effects["fail"]
			result["gamble_result"] = "fail"

	# Handle DOT type
	if effects.get("type") == "dot":
		var dot_duration: int = effects.get("duration", 3)
		# Find which resource is affected
		for key in ["soldiers", "gold", "food", "iron"]:
			if effects.has(key):
				_active_dots.append({
					"resource_key": key,
					"delta": effects[key],
					"remaining": dot_duration,
				})
				result["applied"].append("DOT %s: %+d/回合 x%d" % [key, effects[key], dot_duration])
		EventBus.event_choice_made.emit(event_id, choice_index)
		return result

	# Handle combat type
	if effects.get("type") == "combat":
		var enemy_count: int = effects.get("enemy_soldiers", 8)
		result["combat"] = true
		result["enemy_soldiers"] = enemy_count
		# Combat resolution delegated to GameManager via signal
		EventBus.event_combat_requested.emit(pid, enemy_count, event_id)
		result["applied"].append("combat: vs %d enemy soldiers" % enemy_count)
		EventBus.event_choice_made.emit(event_id, choice_index)
		return result

	# Apply resource changes via ResourceManager
	var res_delta := {}
	for key in ["gold", "food", "iron", "slaves", "prestige", "magic_crystal"]:
		if effects.has(key):
			res_delta[key] = effects[key]
			result["applied"].append("%s: %+d" % [key, effects[key]])
	if not res_delta.is_empty():
		ResourceManager.apply_delta(pid, res_delta)

	# Order changes via OrderManager
	if effects.has("order"):
		OrderManager.change_order(effects["order"])
		result["applied"].append("order: %+d" % effects["order"])

	# Threat changes via ThreatManager
	if effects.has("threat"):
		ThreatManager.change_threat(effects["threat"])
		result["applied"].append("threat: %+d" % effects["threat"])

	# Soldier changes via ResourceManager army
	if effects.has("soldiers"):
		if effects["soldiers"] > 0:
			ResourceManager.add_army(pid, effects["soldiers"])
		else:
			ResourceManager.remove_army(pid, -effects["soldiers"])
		result["soldier_change"] = effects["soldiers"]
		result["applied"].append("soldiers: %+d" % effects["soldiers"])

	# WAAAGH! changes — delegate to OrcMechanic so the value is actually applied
	if effects.has("waaagh"):
		if OrcMechanic != null and OrcMechanic.has_method("add_waaagh"):
			OrcMechanic.add_waaagh(pid, effects["waaagh"])
		else:
			EventBus.waaagh_changed.emit(pid, effects["waaagh"])
		result["applied"].append("waaagh: %+d" % effects["waaagh"])

	# Plunder changes — delegate to PirateMechanic so the value is actually applied
	if effects.has("plunder"):
		if PirateMechanic != null and PirateMechanic.has_method("add_plunder_bonus"):
			PirateMechanic.add_plunder_bonus(pid, effects["plunder"])
		else:
			EventBus.plunder_changed.emit(pid, effects["plunder"])
		result["applied"].append("plunder: %+d" % effects["plunder"])

	# Item reward
	if effects.has("item") and effects["item"] == "random":
		var granted_id: String = ItemManager.grant_random_loot(pid)
		if granted_id != null and granted_id != "":
			EventBus.item_acquired.emit(pid, ItemManager._get_item_name(granted_id))
			result["applied"].append("item: random")

	# Relic reward - emit signal; if player has no relic, trigger relic selection
	if effects.has("relic") and effects["relic"]:
		EventBus.message_log.emit("[color=green]发现远古遗物![/color]")
		if not RelicManager.has_relic(pid):
			# Trigger relic selection for player
			var choices: Array = RelicManager.generate_relic_choices()
			EventBus.message_log.emit("可选遗物: %s" % str(choices))
		else:
			# Already has relic - grant upgrade materials instead
			ResourceManager.apply_delta(pid, {"prestige": 10})
			EventBus.message_log.emit("已有遗物, 转化为 +10威望")
		result["applied"].append("relic: +1")

	# Buff application
	if effects.has("buff"):
		var buff: Dictionary = effects["buff"]
		var buff_type: String = buff.get("type", "atk_pct")
		var buff_val: float = buff.get("value", 0)
		var buff_dur: int = buff.get("duration", 1)
		BuffManager.add_buff(pid, "event_%s" % event_id, buff_type, buff_val, buff_dur, "event")
		result["applied"].append("buff: %s (%d turns)" % [buff_type, buff_dur])

	# Debuff application (negative buff)
	if effects.has("debuff"):
		var debuff: Dictionary = effects["debuff"]
		var debuff_type: String = debuff.get("type", "income_pct")
		var debuff_val: float = debuff.get("value", 0)
		var debuff_dur: int = debuff.get("duration", 1)
		BuffManager.add_buff(pid, "event_debuff_%s" % event_id, debuff_type, debuff_val, debuff_dur, "event")
		result["applied"].append("debuff: %s %+d%% (%d turns)" % [debuff_type, debuff_val, debuff_dur])

	# Immobile flag
	if effects.get("immobile", false):
		_immobile_this_turn = true
		result["applied"].append("immobile: 本回合无法移动")

	# Temp soldiers (expire after 3 turns)
	if effects.has("temp_soldiers"):
		var count: int = effects["temp_soldiers"]
		ResourceManager.add_army(pid, count)
		_temp_soldier_batches.append({"count": count, "remaining": 3})
		result["applied"].append("temp_soldiers: +%d (3回合)" % count)

	# Delayed gold (granted next turn)
	if effects.has("gold_delayed"):
		_pending_gold += effects["gold_delayed"]
		result["applied"].append("gold_delayed: +%d (下回合到账)" % effects["gold_delayed"])

	# Lose node(s): player loses border tile(s) to neutral
	if effects.has("lose_node") and effects["lose_node"]:
		_apply_lose_nodes(pid, 1)
		result["applied"].append("lose_node: -1据点")

	if effects.has("lose_nodes"):
		var count: int = effects["lose_nodes"]
		_apply_lose_nodes(pid, count)
		result["applied"].append("lose_nodes: -%d据点" % count)

	# Reveal fog of war
	if effects.has("reveal"):
		var count: int = effects["reveal"]
		_apply_reveal(pid, count)
		result["applied"].append("reveal: %d格迷雾" % count)

	# Special NPC (dark elf event) - capture a random available NPC
	if effects.get("special_npc", false):
		var faction_id: int = GameManager.get_player_faction(pid)
		var available_npcs: Array = NpcManager.get_available_npcs_for_faction(faction_id)
		var captured_ids: Array = []
		for npc in NpcManager.get_captured_npcs(pid):
			captured_ids.append(npc.get("npc_id", ""))
		var uncaptured: Array = []
		for npc_id_str in available_npcs:
			if npc_id_str not in captured_ids:
				uncaptured.append(npc_id_str)
		if not uncaptured.is_empty():
			uncaptured.shuffle()
			var npc_id: String = uncaptured[0]
			NpcManager.capture_npc(pid, npc_id)
			var npc_def: Dictionary = NpcManager.NPC_DEFS.get(npc_id, {})
			EventBus.message_log.emit("[color=green]事件获得特殊NPC: %s[/color]" % npc_def.get("name", npc_id))
		else:
			ResourceManager.apply_delta(pid, {"prestige": 5})
			EventBus.message_log.emit("无可用NPC, 转化为 +5威望")
		result["applied"].append("special_npc: +1")

	EventBus.event_choice_made.emit(event_id, choice_index)
	return result


# ═══════════════ EFFECT HELPERS ═══════════════

func _apply_lose_nodes(player_id: int, count: int) -> void:
	## Remove the outermost (border) tiles from the player. They become neutral.
	var border_tiles: Array = _get_border_tiles(player_id)
	border_tiles.shuffle()
	var lost: int = 0
	for i in range(mini(count, border_tiles.size())):
		var tile: Dictionary = border_tiles[i]
		tile["owner_id"] = -1
		tile["garrison"] = 0
		EventBus.tile_lost.emit(player_id, tile["index"])
		OrderManager.on_tile_lost()
		lost += 1
	if lost > 0:
		EventBus.message_log.emit("[color=red]事件导致失去 %d 个据点![/color]" % lost)


func _get_border_tiles(player_id: int) -> Array:
	## Get tiles owned by player that border non-owned tiles.
	var result: Array = []
	for tile in GameManager.tiles:
		if tile["owner_id"] != player_id:
			continue
		var neighbors: Array = GameManager.adjacency.get(tile["index"], [])
		for n_idx in neighbors:
			if n_idx < GameManager.tiles.size():
				if GameManager.tiles[n_idx]["owner_id"] != player_id:
					result.append(tile)
					break
	return result


func _apply_reveal(player_id: int, count: int) -> void:
	## Reveal unrevealed tiles for the player.
	var unrevealed: Array = []
	for t in GameManager.tiles:
		if not t.get("revealed", {}).get(player_id, false):
			unrevealed.append(t["index"])
	unrevealed.shuffle()
	var revealed_count: int = 0
	for i in range(mini(count, unrevealed.size())):
		GameManager.tiles[unrevealed[i]]["revealed"][player_id] = true
		# Also reveal neighbors
		var neighbors: Array = GameManager.adjacency.get(unrevealed[i], [])
		for n_idx in neighbors:
			if n_idx < GameManager.tiles.size():
				GameManager.tiles[n_idx]["revealed"][player_id] = true
		revealed_count += 1
	if revealed_count > 0:
		EventBus.fog_updated.emit(player_id)
		EventBus.message_log.emit("揭示了 %d 格迷雾" % revealed_count)


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"triggered_this_turn": _triggered_this_turn.duplicate(true),
		"triggered_ids": _triggered_ids.duplicate(true),
		"active_dots": _active_dots.duplicate(true),
		"pending_gold": _pending_gold,
		"immobile_this_turn": _immobile_this_turn,
		"temp_soldier_batches": _temp_soldier_batches.duplicate(true),
		"world_event_triggered_ids": _world_event_triggered_ids.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_triggered_this_turn = data.get("triggered_this_turn", []).duplicate(true)
	_triggered_ids = data.get("triggered_ids", {}).duplicate(true)
	_active_dots = data.get("active_dots", []).duplicate(true)
	_pending_gold = data.get("pending_gold", 0)
	_immobile_this_turn = data.get("immobile_this_turn", false)
	_temp_soldier_batches = data.get("temp_soldier_batches", []).duplicate(true)
	_world_event_triggered_ids = data.get("world_event_triggered_ids", {}).duplicate(true)
	# Re-register world events from data file so check_world_events() works
	register_world_events()
