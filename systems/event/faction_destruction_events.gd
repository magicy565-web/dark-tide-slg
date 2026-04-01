## faction_destruction_events.gd - Event chains triggered when factions are destroyed (v1.0)
## Each faction has unique destruction events with lasting consequences.
extends Node

# ── Chain definitions: faction_key -> Array of chain event dicts ──
var _chain_defs: Dictionary = {}

# ── Active chain tracking: faction_key -> { "step": int, "trigger_turn": int } ──
var _active_chains: Dictionary = {}

# ── Pending chain events waiting to fire: [ { "faction": String, "event": Dictionary, "trigger_turn": int } ] ──
var _pending_chain_events: Array = []

# ── Which factions have been fully destroyed (to avoid re-triggering) ──
var _destroyed_factions: Dictionary = {}  # faction_key -> true

# ── Current pending event awaiting player choice ──
var _current_event: Dictionary = {}
var _current_faction: String = ""


func _ready() -> void:
	_register_chain_defs()
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.event_choice_selected.connect(_on_event_choice_selected)
	if EventRegistry:
		var _all: Array = []
		for _fk in _chain_defs:
			_all.append_array(_chain_defs[_fk])
		EventRegistry._register_source("faction_destruction_events", _all, "destruction_chain")


# ═══════════════ CHAIN DEFINITIONS ═══════════════

func _register_chain_defs() -> void:
	_chain_defs["human"] = _human_chain()
	_chain_defs["elf"] = _elf_chain()
	_chain_defs["mage_guild"] = _mage_guild_chain()
	_chain_defs["orc"] = _orc_chain()
	_chain_defs["pirate"] = _pirate_chain()
	_chain_defs["dark_elf"] = _dark_elf_chain()


func _human_chain() -> Array:
	return [
		{
			"id": "human_destruction_1", "name": "人类王国覆灭",
			"desc": "人类王国覆灭，大量难民涌入你的领地，请求庇护。",
			"delay": 0,
			"choices": [
				{"text": "接纳难民 (+5兵力, 秩序-3)", "effects": {"soldiers": 5, "order": -3}},
				{"text": "驱逐难民 (+5威望, -2粮食)", "effects": {"prestige": 5, "food": -2}},
			]
		},
		{
			"id": "human_destruction_2", "name": "王室遗产",
			"desc": "在人类王国的废墟中发现了一座隐秘的王室宝库。",
			"delay": 2,
			"choices": [
				{"text": "掠夺宝库 (+100金)", "effects": {"gold": 100}},
				{"text": "归还百姓 (秩序+5, 声望+15)", "effects": {"order": 5, "reputation_all": 15}},
			]
		},
		{
			"id": "human_destruction_3", "name": "复仇者",
			"desc": "一群人类忠臣组织了一支复仇军，向你的领地发起进攻！",
			"delay": 4,
			"choices": [
				{"text": "迎战 (战斗: 15兵力敌军, 胜利+1遗物)", "effects": {"type": "combat", "enemy_soldiers": 15, "success": {"relic": true}}},
				{"text": "防御 (-5兵力, 秩序-2)", "effects": {"soldiers": -5, "order": -2}},
			]
		},
	]


func _elf_chain() -> Array:
	return [
		{
			"id": "elf_destruction_1", "name": "精灵森林枯萎",
			"desc": "失去精灵守护的古老森林开始枯萎死亡。",
			"delay": 0,
			"choices": [
				{"text": "种植新苗 (-30金, 秩序+3)", "effects": {"gold": -30, "order": 3}},
				{"text": "采伐残余 (+40铁, -5威望)", "effects": {"iron": 40, "prestige": -5}},
			]
		},
		{
			"id": "elf_destruction_2", "name": "精灵遗民",
			"desc": "流浪的精灵们寻求庇护，他们中有技艺精湛的弓箭手。",
			"delay": 3,
			"choices": [
				{"text": "欢迎加入 (+精锐弓箭手部队)", "effects": {"special_unit": "elf_archer", "soldiers": 3}},
				{"text": "奴役利用 (+3奴隶, +2威望)", "effects": {"slaves": 3, "prestige": 2}},
			]
		},
		{
			"id": "elf_destruction_3", "name": "世界树碎片",
			"desc": "在精灵领地的深处发现了世界树的碎片，蕴含强大魔力。",
			"delay": 5,
			"choices": [
				{"text": "研究 (+1科技点, +10魔晶)", "effects": {"tech_point": 1, "magic_crystal": 10}},
				{"text": "摧毁 (+20威望, 威胁-10)", "effects": {"prestige": 20, "threat": -10}},
			]
		},
	]


func _mage_guild_chain() -> Array:
	return [
		{
			"id": "mage_destruction_1", "name": "魔法暴走",
			"desc": "失去控制的魔法能量在全图暴走，所有领地秩序-1。",
			"delay": 0,
			"auto_effect": {"order": -1, "all_tiles": true},
			"choices": [
				{"text": "稳定魔力 (-50金, 秩序+5)", "effects": {"gold": -50, "order": 5}},
				{"text": "利用暴走 (ATK+20% 3回合, 秩序-3)", "effects": {"order": -3, "buff": {"type": "atk_pct", "value": 20, "duration": 3}}},
			]
		},
		{
			"id": "mage_destruction_2", "name": "禁书流出",
			"desc": "魔导士公会的禁忌魔法书籍流入黑市。",
			"delay": 3,
			"choices": [
				{"text": "研读禁书 (解锁法师部队招募)", "effects": {"unlock_unit": "mage_unit", "prestige": 5}},
				{"text": "焚烧禁书 (+10威望, 威胁-5)", "effects": {"prestige": 10, "threat": -5}},
			]
		},
		{
			"id": "mage_destruction_3", "name": "魔导残骸",
			"desc": "发现魔导士公会的秘密武器库，里面存放着未完成的魔导炮。",
			"delay": 5,
			"choices": [
				{"text": "回收残骸 (+3炮兵部队)", "effects": {"special_unit": "cannon", "soldiers": 5}},
				{"text": "封印遗址 (威胁-15, 秩序+3)", "effects": {"threat": -15, "order": 3}},
			]
		},
	]


func _orc_chain() -> Array:
	return [
		{
			"id": "orc_destruction_1", "name": "兽人溃散",
			"desc": "溃散的兽人残部变成土匪，在各地烧杀抢掠。3个随机领地秩序-2。",
			"delay": 0,
			"auto_effect": {"order": -2, "random_tiles": 3},
			"choices": [
				{"text": "了解", "effects": {}},
			]
		},
		{
			"id": "orc_destruction_2", "name": "WAAAGH消散",
			"desc": "残留的WAAAGH能量在空气中弥漫，可以被吸收或净化。",
			"delay": 2,
			"choices": [
				{"text": "吸收能量 (ATK+15% 5回合)", "effects": {"buff": {"type": "atk_pct", "value": 15, "duration": 5}}},
				{"text": "净化能量 (所有领地秩序+2)", "effects": {"order": 2, "all_tiles": true}},
			]
		},
		{
			"id": "orc_destruction_3", "name": "部落遗物",
			"desc": "在兽人部落遗址中发现了古老的部落神器和驯服的座狼。",
			"delay": 4,
			"choices": [
				{"text": "保留 (+1遗物, +座狼骑兵)", "effects": {"relic": true, "special_unit": "warg_rider"}},
				{"text": "交易 (+80金)", "effects": {"gold": 80}},
			]
		},
	]


func _pirate_chain() -> Array:
	return [
		{
			"id": "pirate_destruction_1", "name": "海贼宝藏",
			"desc": "缴获了海贼的藏宝图，标注了多处隐藏宝藏的位置。",
			"delay": 0,
			"choices": [
				{"text": "派遣远征队 (-20兵力, 70%获200金, 30%损失兵力)", "effects": {"soldiers": -20, "type": "gamble", "success_rate": 0.7, "success": {"gold": 200, "soldiers": 20}, "fail": {}}},
				{"text": "出售藏宝图 (+60金)", "effects": {"gold": 60}},
			]
		},
		{
			"id": "pirate_destruction_2", "name": "黑市崩溃",
			"desc": "海贼覆灭导致地下交易网络崩塌，市场剧烈动荡。",
			"delay": 3,
			"auto_effect": {"gold": -30, "iron": 15, "food": 10},
			"choices": [
				{"text": "了解", "effects": {}},
			]
		},
		{
			"id": "pirate_destruction_3", "name": "幽灵船",
			"desc": "海上出现一艘无人的幽灵船，据说船上藏有传说级宝物。",
			"delay": 5,
			"choices": [
				{"text": "登船探索 (战斗: 20兵力亡灵, 胜利=传说道具)", "effects": {"type": "combat", "enemy_soldiers": 20, "success": {"item": "legendary"}}},
				{"text": "无视", "effects": {}},
			]
		},
	]


func _dark_elf_chain() -> Array:
	return [
		{
			"id": "dark_elf_destruction_1", "name": "奴隶解放",
			"desc": "暗精灵覆灭后，原领地上的大量奴隶获得自由。",
			"delay": 0,
			"choices": [
				{"text": "重新捕获 (-2兵力, +5奴隶)", "effects": {"soldiers": -2, "slaves": 5}},
				{"text": "给予自由 (+10威望, 秩序+3)", "effects": {"prestige": 10, "order": 3}},
			]
		},
		{
			"id": "dark_elf_destruction_2", "name": "暗影仪式残留",
			"desc": "暗精灵留下的黑暗仪式能量仍然在涌动。",
			"delay": 3,
			"choices": [
				{"text": "驾驭暗影 (-2奴隶, +暗影精华×3)", "effects": {"slaves": -2, "item": "shadow_essence", "item_count": 3}},
				{"text": "净化暗影 (秩序+5, 威望+5)", "effects": {"order": 5, "prestige": 5}},
			]
		},
		{
			"id": "dark_elf_destruction_3", "name": "地下城入口",
			"desc": "发现一条通往暗精灵地下城的秘密通道。",
			"delay": 5,
			"choices": [
				{"text": "探索地下城 (揭示5格迷雾, 40%发现隐藏英雄)", "effects": {"reveal": 5, "type": "gamble", "success_rate": 0.4, "success": {"special_npc": true}, "fail": {}}},
				{"text": "封闭入口 (秩序+10)", "effects": {"order": 10}},
			]
		},
	]


# ═══════════════ FACTION DESTROYED HANDLER ═══════════════

func on_faction_destroyed(faction_key: String) -> void:
	if _destroyed_factions.has(faction_key):
		return
	_destroyed_factions[faction_key] = true

	if not _chain_defs.has(faction_key):
		return

	var chain: Array = _chain_defs[faction_key]
	var current_turn: int = GameManager.current_turn if GameManager.has_method("get") else 0
	if "current_turn" in GameManager:
		current_turn = GameManager.current_turn

	_active_chains[faction_key] = {"step": 0, "base_turn": current_turn}

	# Queue all chain events with their delays
	for i in range(chain.size()):
		var evt: Dictionary = chain[i]
		_pending_chain_events.append({
			"faction": faction_key,
			"step": i,
			"event": evt,
			"trigger_turn": current_turn + evt.get("delay", 0),
		})

	# Fire immediate events (delay == 0)
	_check_pending_events(current_turn)


# ═══════════════ TURN PROCESSING ═══════════════

func _on_turn_started(player_id: int) -> void:
	if player_id != 0:
		return
	var current_turn: int = 0
	if "current_turn" in GameManager:
		current_turn = GameManager.current_turn
	_check_pending_events(current_turn)


func _check_pending_events(current_turn: int) -> void:
	var to_fire: Array = []
	var remaining: Array = []

	for pe in _pending_chain_events:
		if pe["trigger_turn"] <= current_turn:
			to_fire.append(pe)
		else:
			remaining.append(pe)

	_pending_chain_events = remaining

	for pe in to_fire:
		_fire_chain_event(pe["faction"], pe["event"])


func _fire_chain_event(faction_key: String, event: Dictionary) -> void:
	_current_event = event
	_current_faction = faction_key

	# Apply auto effects before showing choices
	if event.has("auto_effect"):
		_apply_auto_effect(event["auto_effect"])

	var choices: Array = []
	for c in event.get("choices", []):
		choices.append(c["text"])

	EventBus.show_event_popup.emit(event["name"], event["desc"], choices)
	EventBus.message_log.emit("[color=orange][势力覆灭] %s[/color]" % event["name"])


func _apply_auto_effect(auto_eff: Dictionary) -> void:
	var pid: int = GameManager.current_player_index if "current_player_index" in GameManager else 0

	if auto_eff.get("all_tiles", false) and auto_eff.has("order"):
		OrderManager.change_order(auto_eff["order"])
		EventBus.message_log.emit("[color=yellow]所有领地秩序 %+d[/color]" % auto_eff["order"])

	if auto_eff.has("random_tiles"):
		var count: int = auto_eff["random_tiles"]
		var order_delta: int = auto_eff.get("order", -2)
		var player_tiles: Array = []
		if GameManager.has_method("get_player_tiles"):
			player_tiles = GameManager.get_player_tiles(pid)
		elif "tiles" in GameManager:
			for t in GameManager.tiles:
				if t.get("owner", -1) == pid:
					player_tiles.append(t)
		player_tiles.shuffle()
		var affected: int = mini(count, player_tiles.size())
		for i in range(affected):
			OrderManager.change_order(order_delta)
		if affected > 0:
			EventBus.message_log.emit("[color=yellow]%d个领地秩序 %+d[/color]" % [affected, order_delta])

	# Direct resource auto-effects
	var res_delta := {}
	for key in ["gold", "food", "iron", "slaves", "prestige", "magic_crystal"]:
		if auto_eff.has(key):
			res_delta[key] = auto_eff[key]
	if not res_delta.is_empty():
		ResourceManager.apply_delta(pid, res_delta)


# ═══════════════ CHOICE HANDLING ═══════════════

func _on_event_choice_selected(choice_index: int) -> void:
	if _current_event.is_empty():
		return

	var choices: Array = _current_event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		_current_event = {}
		return

	var effects: Dictionary = choices[choice_index].get("effects", {})
	_apply_effects(effects)
	_current_event = {}
	_current_faction = ""


func _apply_effects(effects: Dictionary) -> void:
	var pid: int = GameManager.current_player_index if "current_player_index" in GameManager else 0

	# Route through centralized EffectResolver if available
	if EffectResolver:
		EffectResolver.resolve(effects, {"player_id": pid, "source": "faction_destruction", "event_id": _current_event.get("id", "faction_dest")})
		return

	# Legacy fallback — Handle gamble type
	if effects.get("type") == "gamble":
		if randf() <= effects.get("success_rate", 0.5):
			effects = effects.get("success", {})
			EventBus.message_log.emit("[color=green]成功![/color]")
		else:
			effects = effects.get("fail", {})
			EventBus.message_log.emit("[color=red]失败![/color]")

	# Handle combat type
	if effects.get("type") == "combat":
		var enemy_count: int = effects.get("enemy_soldiers", 10)
		EventBus.event_combat_requested.emit(pid, enemy_count, _current_event.get("id", ""))
		return

	# Resource changes
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
		if effects.get("all_tiles", false):
			# Apply to all tiles
			OrderManager.change_order(effects["order"])
		else:
			OrderManager.change_order(effects["order"])

	# Threat
	if effects.has("threat"):
		ThreatManager.change_threat(effects["threat"])

	# Buff
	if effects.has("buff"):
		var buff: Dictionary = effects["buff"]
		BuffManager.add_buff(pid, "faction_dest_%s" % buff.get("type", ""), buff.get("type", ""), buff.get("value", 0), buff.get("duration", 1), "faction_destruction")

	# Relic
	if effects.has("relic") and effects["relic"]:
		EventBus.message_log.emit("[color=green]发现远古遗物![/color]")
		if not RelicManager.has_relic(pid):
			var relic_choices: Array = RelicManager.generate_relic_choices()
			EventBus.message_log.emit("可选遗物: %s" % str(relic_choices))
		else:
			ResourceManager.apply_delta(pid, {"prestige": 10})

	# Reveal fog
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

	# Special NPC
	if effects.has("special_npc") and effects["special_npc"]:
		EventBus.message_log.emit("[color=green]发现隐藏英雄![/color]")

	# Reputation
	if effects.has("reputation_all"):
		EventBus.message_log.emit("[color=cyan]声望变化: %+d[/color]" % effects["reputation_all"])

	# Special unit
	if effects.has("special_unit"):
		EventBus.message_log.emit("[color=green]获得特殊部队: %s[/color]" % effects["special_unit"])

	# Tech point
	if effects.has("tech_point"):
		EventBus.message_log.emit("[color=cyan]获得 %d 科技点[/color]" % effects["tech_point"])

	# Unlock unit type
	if effects.has("unlock_unit"):
		EventBus.message_log.emit("[color=green]解锁部队类型: %s[/color]" % effects["unlock_unit"])

	# Item
	if effects.has("item"):
		var item_id: String = effects["item"]
		if item_id == "random" or item_id == "legendary":
			var granted_id: String = ItemManager.grant_random_loot(pid)
			if granted_id != null and granted_id != "":
				EventBus.item_acquired.emit(pid, ItemManager._get_item_name(granted_id))
		elif item_id != "":
			var count: int = effects.get("item_count", 1)
			EventBus.message_log.emit("[color=green]获得物品: %s ×%d[/color]" % [item_id, count])


# ═══════════════ SAVE / LOAD ═══════════════

func get_save_data() -> Dictionary:
	return {
		"destroyed_factions": _destroyed_factions.duplicate(),
		"active_chains": _active_chains.duplicate(true),
		"pending_chain_events": _pending_chain_events.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	_destroyed_factions = data.get("destroyed_factions", {})
	_active_chains = data.get("active_chains", {})
	_pending_chain_events = data.get("pending_chain_events", [])
