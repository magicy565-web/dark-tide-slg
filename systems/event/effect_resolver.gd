## EffectResolver — Centralized pipeline that validates and applies ALL event/quest
## effects through a single entry point: resolve(effects, context).
##
## Replaces the scattered _apply_effects / _apply_resource_effects / apply_choice
## pattern found in event_system.gd, seasonal_events.gd, dynamic_situation_events.gd,
## faction_destruction_events.gd, grand_event_director.gd, and
## character_interaction_events.gd.
##
## Every known effect key is registered in _handlers. Unknown keys emit a warning
## but never crash. Each handler null-checks its target system.
extends Node

# Effect handler registry: effect_key -> Callable
var _handlers: Dictionary = {}

# Log of the most recent resolve() call for UI / debugging
var _last_resolved: Array = []

# ── Delayed gold accumulator (paid out next turn via EventSystem) ──
var _pending_gold: int = 0


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_register_handlers()


# ---------------------------------------------------------------------------
# Handler registration
# ---------------------------------------------------------------------------

func _register_handlers() -> void:
	# --- Resources (applied via ResourceManager.apply_delta) ---
	_handlers["gold"] = _apply_resource.bind("gold")
	_handlers["food"] = _apply_resource.bind("food")
	_handlers["iron"] = _apply_resource.bind("iron")
	_handlers["slaves"] = _apply_resource.bind("slaves")
	_handlers["prestige"] = _apply_resource.bind("prestige")
	_handlers["magic_crystal"] = _apply_resource.bind("magic_crystal")
	_handlers["shadow_essence"] = _apply_resource.bind("shadow_essence")
	_handlers["gunpowder"] = _apply_resource.bind("gunpowder")

	# --- Soldiers ---
	_handlers["soldiers"] = _apply_soldiers

	# --- State values ---
	_handlers["order"] = _apply_order
	_handlers["threat"] = _apply_threat

	# --- Faction-specific ---
	_handlers["waaagh"] = _apply_waaagh
	_handlers["plunder"] = _apply_plunder

	# --- Buffs / Debuffs ---
	_handlers["buff"] = _apply_buff
	_handlers["debuff"] = _apply_debuff

	# --- Map ---
	_handlers["reveal"] = _apply_reveal
	_handlers["lose_node"] = _apply_lose_node
	_handlers["lose_nodes"] = _apply_lose_nodes

	# --- Buildings / Units ---
	_handlers["unlock_building"] = _apply_unlock_building
	_handlers["unlock_unit"] = _apply_unlock_unit
	_handlers["wall_boost"] = _apply_wall_boost

	# --- Items / Relics / NPCs ---
	_handlers["item"] = _apply_item
	_handlers["relic"] = _apply_relic
	_handlers["special_npc"] = _apply_special_npc
	_handlers["special_unit"] = _apply_special_unit

	# --- Hero ---
	_handlers["hero_stat"] = _apply_hero_stat
	_handlers["hero_stat_boost"] = _apply_hero_stat_boost
	_handlers["hero_affection_all"] = _apply_hero_affection_all
	_handlers["hero_stat_bonus"] = _apply_hero_stat_bonus
	_handlers["affection_boost"] = _apply_affection_boost
	_handlers["corruption_boost"] = _apply_corruption_boost
	_handlers["lowest_stat_bonus"] = _apply_lowest_stat_bonus
	_handlers["all_stats_bonus"] = _apply_all_stats_bonus

	# --- Delayed / DOT ---
	_handlers["gold_delayed"] = _apply_gold_delayed
	_handlers["temp_soldiers"] = _apply_temp_soldiers

	# --- Reputation ---
	_handlers["reputation_all"] = _apply_reputation_all

	# --- Mobility ---
	_handlers["immobile"] = _apply_immobile
	_handlers["ap"] = _apply_ap

	# --- Tech ---
	_handlers["tech_point"] = _apply_tech_point

	# --- Interaction-specific ---
	_handlers["combo_passive"] = _apply_combo_passive
	_handlers["heal_per_turn"] = _apply_heal_per_turn
	_handlers["espionage_bonus"] = _apply_espionage_bonus
	_handlers["unit_buff"] = _apply_unit_buff
	_handlers["terrain_buff"] = _apply_terrain_buff

	# --- Meta keys (not actual effects, consumed by pre-processing) ---
	# These are silently skipped — they are parameters for gamble/dot/combat,
	# not standalone effects.
	for meta_key in [
		"type", "success_rate", "success", "fail",
		"duration", "enemy_soldiers", "enemy_type",
		"coastal", "all_tiles", "random_tiles",
		"chain_parent", "chain_choice", "condition",
		"item_count",
	]:
		_handlers[meta_key] = _noop


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Apply all effects in *effects*. Returns an array of result dictionaries:
## [{ key, value, success, message }]
##
## Pre-processing handles composite "type" effects (gamble, dot, combat) before
## individual keys are dispatched to handlers.
##
## *context* keys used by handlers:
##   player_id  — int, defaults to human player
##   source     — String tag for buff dedup (e.g. "event_system", "seasonal")
##   event_id   — String, the originating event id
##   recruited  — Array (optional, for character_interaction hero list)
##   affections — Dictionary (optional, hero affection map)
func resolve(effects: Dictionary, context: Dictionary = {}) -> Array:
	_last_resolved.clear()

	if effects.is_empty():
		return _last_resolved

	# Ensure player_id
	if not context.has("player_id"):
		context["player_id"] = _get_default_pid()

	# ── Pre-process composite types ──
	var working: Dictionary = _preprocess(effects, context)

	# ── Dispatch each key ──
	for key in working:
		if _handlers.has(key):
			var result_msg: String = _handlers[key].call(working[key], context)
			_last_resolved.append({
				"key": key, "value": working[key],
				"success": true, "message": result_msg,
			})
		else:
			push_warning("EffectResolver: Unknown effect type '%s' (value: %s)" % [key, str(working[key])])
			_last_resolved.append({
				"key": key, "value": working[key],
				"success": false, "message": "no handler",
			})

	return _last_resolved


## Returns the result array from the most recent resolve() call.
func get_last_resolved() -> Array:
	return _last_resolved


## Returns and resets any accumulated delayed gold.
func pop_pending_gold() -> int:
	var amount: int = _pending_gold
	_pending_gold = 0
	return amount


# ---------------------------------------------------------------------------
# Pre-processing (gamble / dot / combat)
# ---------------------------------------------------------------------------

## Resolves composite "type" effects and returns a flat dictionary of simple
## key-value effects for handler dispatch.  Combat is emitted as a signal and
## removed from the dict.
func _preprocess(effects: Dictionary, context: Dictionary) -> Dictionary:
	var etype: String = str(effects.get("type", ""))

	# ── Gamble ──
	if etype == "gamble":
		var roll: float = randf()
		var success_rate: float = effects.get("success_rate", 0.5)
		if roll <= success_rate:
			context["gamble_result"] = "success"
			EventBus.message_log.emit("[color=green]成功![/color]")
			return effects.get("success", {})
		else:
			context["gamble_result"] = "fail"
			EventBus.message_log.emit("[color=red]失败![/color]")
			return effects.get("fail", {})

	# ── DOT (damage-over-time) — register with EventSystem ──
	if etype == "dot":
		_register_dot(effects, context)
		return {}  # DOT is deferred, nothing to apply now

	# ── Combat — emit signal and bail ──
	if etype == "combat":
		_emit_combat(effects, context)
		return {}  # Combat is handled externally

	# No composite type — return as-is
	return effects


func _register_dot(effects: Dictionary, context: Dictionary) -> void:
	var dot_duration: int = effects.get("duration", 3)
	var pid: int = context.get("player_id", 0)
	for key in ["soldiers", "gold", "food", "iron"]:
		if effects.has(key):
			# Route to EventSystem's DOT tracker if available
			if EventSystem != null and "_active_dots" in EventSystem:
				EventSystem._active_dots.append({
					"resource_key": key,
					"delta": effects[key],
					"remaining": dot_duration,
				})
			_last_resolved.append({
				"key": key, "value": effects[key],
				"success": true,
				"message": "DOT %s: %+d/turn x%d" % [key, effects[key], dot_duration],
			})


func _emit_combat(effects: Dictionary, context: Dictionary) -> void:
	var pid: int = context.get("player_id", 0)
	var enemy_count: int = effects.get("enemy_soldiers", 8)
	var event_id: String = context.get("event_id", "")
	var enemy_type: String = effects.get("enemy_type", "")
	var combat_id: String = event_id
	if enemy_type != "":
		combat_id = event_id + "::" + enemy_type

	# Apply any pre-combat buff attached to the combat effect
	if effects.has("buff"):
		_apply_buff(effects["buff"], context)

	EventBus.event_combat_requested.emit(pid, enemy_count, combat_id)
	_last_resolved.append({
		"key": "combat", "value": enemy_count,
		"success": true,
		"message": "combat: vs %d enemy soldiers (%s)" % [enemy_count, enemy_type],
	})


# ---------------------------------------------------------------------------
# Individual handlers — each returns a short human-readable message
# ---------------------------------------------------------------------------

## No-op handler for meta keys that are consumed by pre-processing.
func _noop(_value, _context) -> String:
	return ""


# ── Resources ──

func _apply_resource(value, context, res_key: String) -> String:
	var pid: int = context.get("player_id", 0)
	if ResourceManager != null:
		ResourceManager.apply_delta(pid, {res_key: value})
	return "%s %+d" % [res_key, value]


# ── Soldiers ──

func _apply_soldiers(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	if ResourceManager != null:
		if value > 0:
			ResourceManager.add_army(pid, value)
		elif value < 0:
			ResourceManager.remove_army(pid, -value)
	return "soldiers %+d" % value


# ── Order ──

func _apply_order(value, context) -> String:
	if OrderManager != null:
		OrderManager.change_order(value)
	return "order %+d" % value


# ── Threat ──

func _apply_threat(value, context) -> String:
	if ThreatManager != null:
		ThreatManager.change_threat(value)
	return "threat %+d" % value


# ── WAAAGH! ──

func _apply_waaagh(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	if OrcMechanic != null and OrcMechanic.has_method("add_waaagh"):
		OrcMechanic.add_waaagh(pid, value)
	else:
		EventBus.waaagh_changed.emit(pid, value)
	return "waaagh %+d" % value


# ── Plunder ──

func _apply_plunder(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	if PirateMechanic != null and PirateMechanic.has_method("add_plunder_bonus"):
		PirateMechanic.add_plunder_bonus(pid, value)
	else:
		EventBus.plunder_changed.emit(pid, value)
	return "plunder %+d" % value


# ── Buff ──

func _apply_buff(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	if not value is Dictionary:
		return "buff: invalid (not dict)"
	var buff_type: String = value.get("type", "atk_pct")
	var buff_val = value.get("value", 0)
	var buff_dur: int = value.get("duration", 1)
	var source: String = context.get("source", "event")
	var event_id: String = context.get("event_id", "unknown")
	if BuffManager != null:
		BuffManager.add_buff(pid, "%s_%s" % [source, event_id], buff_type, buff_val, buff_dur, source)
	return "buff %s %+d (%d turns)" % [buff_type, buff_val, buff_dur]


# ── Debuff ──

func _apply_debuff(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	if not value is Dictionary:
		return "debuff: invalid (not dict)"
	var debuff_type: String = value.get("type", "income_pct")
	var debuff_val = value.get("value", 0)
	var debuff_dur: int = value.get("duration", 1)
	var source: String = context.get("source", "event")
	var event_id: String = context.get("event_id", "unknown")
	if BuffManager != null:
		BuffManager.add_buff(pid, "%s_debuff_%s" % [source, event_id], debuff_type, debuff_val, debuff_dur, source)
	return "debuff %s %+d%% (%d turns)" % [debuff_type, debuff_val, debuff_dur]


# ── Reveal fog of war ──

func _apply_reveal(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	var count: int = int(value)
	# Prefer EventSystem helper; fall back to direct tile manipulation
	if EventSystem != null and EventSystem.has_method("_apply_reveal"):
		EventSystem._apply_reveal(pid, count)
	else:
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
	return "reveal %d tiles" % count


# ── Lose node(s) ──

func _apply_lose_node(value, context) -> String:
	if not value:
		return "lose_node: skipped (false)"
	var pid: int = context.get("player_id", 0)
	if EventSystem != null and EventSystem.has_method("_apply_lose_nodes"):
		EventSystem._apply_lose_nodes(pid, 1)
	return "lose_node: -1"


func _apply_lose_nodes(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	var count: int = int(value)
	if EventSystem != null and EventSystem.has_method("_apply_lose_nodes"):
		EventSystem._apply_lose_nodes(pid, count)
	return "lose_nodes: -%d" % count


# ── Wall boost ──

func _apply_wall_boost(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	var boost_amount: int = int(value)
	if LightFactionAI != null and "tiles" in GameManager:
		for tile in GameManager.tiles:
			if tile.get("owner_id", -1) == pid and LightFactionAI.has_method("has_wall") and LightFactionAI.has_wall(tile["index"]):
				LightFactionAI.repair_wall(tile["index"], boost_amount)
	return "wall_boost +%d" % boost_amount


# ── Unlock building ──

func _apply_unlock_building(value, context) -> String:
	EventBus.message_log.emit("[color=green]解锁特殊建筑: %s[/color]" % str(value))
	return "unlock_building: %s" % str(value)


# ── Unlock unit ──

func _apply_unlock_unit(value, context) -> String:
	EventBus.message_log.emit("[color=green]解锁部队类型: %s[/color]" % str(value))
	return "unlock_unit: %s" % str(value)


# ── Item ──

func _apply_item(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	if value == "random":
		if ItemManager != null and ItemManager.has_method("grant_random_loot"):
			var granted_id = ItemManager.grant_random_loot(pid)
			if granted_id != null and granted_id != "":
				if ItemManager.has_method("_get_item_name"):
					EventBus.item_acquired.emit(pid, ItemManager._get_item_name(granted_id))
				return "item: random -> %s" % str(granted_id)
		return "item: random (no ItemManager)"
	# Named item (e.g. "shadow_essence")
	EventBus.message_log.emit("[color=green]获得道具: %s[/color]" % str(value))
	return "item: %s" % str(value)


# ── Relic ──

func _apply_relic(value, context) -> String:
	if not value:
		return "relic: skipped (false)"
	var pid: int = context.get("player_id", 0)
	EventBus.message_log.emit("[color=green]发现远古遗物![/color]")
	if RelicManager != null:
		if not RelicManager.has_relic(pid):
			var choices: Array = RelicManager.generate_relic_choices()
			EventBus.message_log.emit("可选遗物: %s" % str(choices))
		else:
			if ResourceManager != null:
				ResourceManager.apply_delta(pid, {"prestige": 10})
			EventBus.message_log.emit("已有遗物, 转化为 +10威望")
	return "relic +1"


# ── Special NPC ──

func _apply_special_npc(value, context) -> String:
	if not value:
		return "special_npc: skipped (false)"
	var pid: int = context.get("player_id", 0)
	if NpcManager != null and GameManager != null:
		var faction_id: int = GameManager.get_player_faction(pid) if GameManager.has_method("get_player_faction") else 0
		var available_npcs: Array = NpcManager.get_available_npcs_for_faction(faction_id) if NpcManager.has_method("get_available_npcs_for_faction") else []
		var captured_ids: Array = []
		if NpcManager.has_method("get_captured_npcs"):
			for npc in NpcManager.get_captured_npcs(pid):
				captured_ids.append(npc.get("npc_id", ""))
		var uncaptured: Array = []
		for npc_id_str in available_npcs:
			if npc_id_str not in captured_ids:
				uncaptured.append(npc_id_str)
		if not uncaptured.is_empty():
			uncaptured.shuffle()
			var npc_id: String = uncaptured[0]
			if NpcManager.has_method("capture_npc"):
				NpcManager.capture_npc(pid, npc_id)
			var npc_def: Dictionary = NpcManager.NPC_DEFS.get(npc_id, {}) if "NPC_DEFS" in NpcManager else {}
			EventBus.message_log.emit("[color=green]事件获得特殊NPC: %s[/color]" % npc_def.get("name", npc_id))
			return "special_npc: %s" % npc_id
		else:
			if ResourceManager != null:
				ResourceManager.apply_delta(pid, {"prestige": 5})
			EventBus.message_log.emit("无可用NPC, 转化为 +5威望")
			return "special_npc: none available -> +5 prestige"
	EventBus.message_log.emit("[color=green]发现隐藏英雄![/color]")
	return "special_npc: logged"


# ── Special unit ──

func _apply_special_unit(value, context) -> String:
	EventBus.message_log.emit("[color=green]获得特殊部队: %s[/color]" % str(value))
	return "special_unit: %s" % str(value)


# ── Hero stat (from expanded_random_events / extra_events_v5) ──

func _apply_hero_stat(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	if not value is Dictionary:
		return "hero_stat: invalid"
	var stat_key: String = value.get("stat", "atk")
	var stat_val: int = value.get("value", 1)
	if HeroSystem != null and HeroSystem.has_method("get_recruited_heroes"):
		var recruited: Array = HeroSystem.get_recruited_heroes(pid)
		if not recruited.is_empty():
			var target: String = recruited[randi() % recruited.size()]
			if HeroSystem.has_method("modify_hero_stat"):
				HeroSystem.modify_hero_stat(target, stat_key, stat_val)
			elif HeroSystem.has_method("add_stat_bonus"):
				HeroSystem.add_stat_bonus(target, stat_key, stat_val)
			EventBus.message_log.emit("[color=green]%s 的%s永久+%d![/color]" % [target, stat_key.to_upper(), stat_val])
			return "hero_stat: %s %s+%d" % [target, stat_key, stat_val]
	return "hero_stat: %s+%d (no hero)" % [stat_key, stat_val]


# ── Hero stat boost (from chain events in event_system.gd) ──

func _apply_hero_stat_boost(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	if not value is Dictionary:
		return "hero_stat_boost: invalid"
	var stat_key: String = value.get("stat", "atk")
	var stat_val: int = value.get("value", 1)
	if HeroSystem != null and HeroSystem.has_method("get_recruited_heroes"):
		var recruited: Array = HeroSystem.get_recruited_heroes(pid)
		if not recruited.is_empty():
			var target: String = recruited[randi() % recruited.size()]
			if HeroSystem.has_method("modify_hero_stat"):
				HeroSystem.modify_hero_stat(target, stat_key, stat_val)
			EventBus.message_log.emit("[color=green]%s 的%s永久+%d![/color]" % [target, stat_key.to_upper(), stat_val])
			return "hero_stat_boost: %s %s+%d" % [target, stat_key, stat_val]
	return "hero_stat_boost: %s+%d (no hero)" % [stat_key, stat_val]


# ── Hero affection all ──

func _apply_hero_affection_all(value, context) -> String:
	var aff_val: int = int(value)
	var _pid_aff: int = context.get("player_id", 0)
	if HeroSystem != null and HeroSystem.has_method("get_recruited_heroes"):
		var heroes: Array = HeroSystem.get_recruited_heroes(_pid_aff)
		for hero_id in heroes:
			if HeroSystem.has_method("change_affection"):
				HeroSystem.change_affection(hero_id, aff_val)
			EventBus.hero_affection_changed.emit(hero_id, aff_val)
	EventBus.message_log.emit("[color=pink]所有英雄好感度 +%d[/color]" % aff_val)
	return "hero_affection_all %+d" % aff_val


# ── Hero stat bonus (from character_interaction_events) ──

func _apply_hero_stat_bonus(value, context) -> String:
	if not value is Array:
		return "hero_stat_bonus: invalid (not array)"
	for bonus in value:
		var hero_id: String = bonus.get("hero", "")
		var stat: String = bonus.get("stat", "")
		var bval: int = bonus.get("value", 0)
		if hero_id != "" and stat != "" and HeroSystem != null:
			if HeroSystem.has_method("add_stat_bonus"):
				HeroSystem.add_stat_bonus(hero_id, stat, bval)
			EventBus.message_log.emit("[color=green]%s 的%s永久+%d[/color]" % [hero_id, stat.to_upper(), bval])
	return "hero_stat_bonus applied"


# ── Affection boost ──

func _apply_affection_boost(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	var aff_val: int = int(value)
	if HeroSystem != null and HeroSystem.has_method("get_recruited_heroes"):
		var recruited: Array = HeroSystem.get_recruited_heroes(pid)
		if not recruited.is_empty():
			var target: String = recruited[randi() % recruited.size()]
			if HeroSystem.has_method("add_affection"):
				HeroSystem.add_affection(target, aff_val)
			EventBus.message_log.emit("[color=pink]%s 好感度 +%d[/color]" % [target, aff_val])
			return "affection_boost +%d (%s)" % [aff_val, target]
		else:
			if ResourceManager != null:
				ResourceManager.apply_delta(pid, {"prestige": aff_val})
			EventBus.message_log.emit("无可用英雄, 转化为 +%d 威望" % aff_val)
			return "affection_boost +%d (no heroes -> prestige)" % aff_val
	return "affection_boost +%d (no HeroSystem)" % aff_val


# ── Corruption boost ──

func _apply_corruption_boost(value, context) -> String:
	var boost_val: int = int(value)
	if HeroSystem != null and "captured_heroes" in HeroSystem and "hero_corruption" in HeroSystem:
		for hid in HeroSystem.captured_heroes:
			var cur: int = HeroSystem.hero_corruption.get(hid, 0)
			HeroSystem.hero_corruption[hid] = clampi(cur + boost_val, 0, 100)
	return "corruption_boost +%d (all prisoners)" % boost_val


# ── Lowest stat bonus (character interaction) ──

func _apply_lowest_stat_bonus(value, context) -> String:
	var val: int = int(value)
	var recruited: Array = context.get("recruited", [])
	var affections: Dictionary = context.get("affections", {})
	var qualifying: Array = []
	for h in recruited:
		if affections.get(h, 0) >= 5:
			qualifying.append(h)
	qualifying.shuffle()
	for i in range(mini(2, qualifying.size())):
		if HeroSystem != null and HeroSystem.has_method("add_stat_bonus"):
			HeroSystem.add_stat_bonus(qualifying[i], "lowest", val)
		EventBus.message_log.emit("[color=green]%s 最低属性+%d[/color]" % [qualifying[i], val])
	return "lowest_stat_bonus +%d" % val


# ── All stats bonus (character interaction) ──

func _apply_all_stats_bonus(value, context) -> String:
	var val: int = int(value)
	var recruited: Array = context.get("recruited", [])
	var affections: Dictionary = context.get("affections", {})
	for h in recruited:
		if affections.get(h, 0) >= 7:
			for stat in ["atk", "def", "int", "spd"]:
				if HeroSystem != null and HeroSystem.has_method("add_stat_bonus"):
					HeroSystem.add_stat_bonus(h, stat, val)
			EventBus.message_log.emit("[color=green]%s 全属性+%d![/color]" % [h, val])
			return "all_stats_bonus +%d (%s)" % [val, h]
	return "all_stats_bonus +%d (no qualifying hero)" % val


# ── Delayed gold ──

func _apply_gold_delayed(value, context) -> String:
	var amount: int = int(value)
	_pending_gold += amount
	# Also notify EventSystem if it tracks pending gold
	if EventSystem != null and "_pending_gold" in EventSystem:
		EventSystem._pending_gold += amount
	return "gold_delayed +%d (next turn)" % amount


# ── Temp soldiers ──

func _apply_temp_soldiers(value, context) -> String:
	var pid: int = context.get("player_id", 0)
	var count: int = int(value)
	if ResourceManager != null:
		ResourceManager.add_army(pid, count)
	# Register with EventSystem for expiry tracking
	if EventSystem != null and "_temp_soldier_batches" in EventSystem:
		EventSystem._temp_soldier_batches.append({"count": count, "remaining": 3})
	return "temp_soldiers +%d (3 turns)" % count


# ── Reputation all ──

func _apply_reputation_all(value, context) -> String:
	var rep_val: int = int(value)
	if DiplomacyManager != null and DiplomacyManager.has_method("get_all_reputations"):
		var reps: Dictionary = DiplomacyManager.get_all_reputations()
		for faction_key in reps:
			DiplomacyManager.change_reputation(faction_key, rep_val)
	return "reputation_all %+d" % rep_val


# ── Immobile ──

func _apply_immobile(value, context) -> String:
	if not value:
		return "immobile: skipped (false)"
	if EventSystem != null and "_immobile_this_turn" in EventSystem:
		EventSystem._immobile_this_turn = true
	EventBus.message_log.emit("[color=yellow]本回合移动受限[/color]")
	return "immobile: true"


# ── AP (action points) ──

func _apply_ap(value, context) -> String:
	EventBus.message_log.emit("[color=yellow]行动点变化: %+d[/color]" % int(value))
	return "ap %+d" % int(value)


# ── Tech point ──

func _apply_tech_point(value, context) -> String:
	var amount: int = int(value)
	EventBus.message_log.emit("[color=cyan]获得 %d 科技点[/color]" % amount)
	return "tech_point +%d" % amount


# ── Combo passive ──

func _apply_combo_passive(value, context) -> String:
	EventBus.message_log.emit("[color=green]解锁战术配合: %s[/color]" % str(value))
	return "combo_passive: %s" % str(value)


# ── Heal per turn ──

func _apply_heal_per_turn(value, context) -> String:
	var heal: int = int(value)
	var dur: int = context.get("duration", 3)
	# Also check the effects dict for duration (passed as sibling key)
	EventBus.message_log.emit("[color=green]全军每回合治愈 +%d兵力 (持续%d回合)[/color]" % [heal, dur])
	return "heal_per_turn +%d (%d turns)" % [heal, dur]


# ── Espionage bonus ──

func _apply_espionage_bonus(value, context) -> String:
	var bonus: int = int(value)
	var dur: int = context.get("duration", 5)
	EventBus.message_log.emit("[color=cyan]谍报成功率 +%d%% (持续%d回合)[/color]" % [bonus, dur])
	return "espionage_bonus +%d%% (%d turns)" % [bonus, dur]


# ── Unit buff ──

func _apply_unit_buff(value, context) -> String:
	if not value is Dictionary:
		return "unit_buff: invalid"
	EventBus.message_log.emit("[color=green]%s部队 %s+%d (持续%d回合)[/color]" % [
		value.get("unit_type", ""), value.get("stat", "").to_upper(),
		value.get("value", 0), value.get("duration", 0)])
	return "unit_buff: %s %s+%d" % [value.get("unit_type", ""), value.get("stat", ""), value.get("value", 0)]


# ── Terrain buff ──

func _apply_terrain_buff(value, context) -> String:
	EventBus.message_log.emit("[color=green]获得地形增益: %s[/color]" % str(value))
	return "terrain_buff: %s" % str(value)


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _get_default_pid() -> int:
	if GameManager != null:
		if GameManager.has_method("get_human_player_id"):
			return GameManager.get_human_player_id()
		if "current_player_index" in GameManager:
			return GameManager.current_player_index
	return 0
