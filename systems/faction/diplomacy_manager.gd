extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## diplomacy_manager.gd - Evil faction diplomacy & conquest (v0.7)

# Track faction relations: { player_id: { faction_id: { "hostile": bool, "recruited": bool, "method": String, "rebellion_turns": int } } }
var _relations: Dictionary = {}
var _ceasefire: Dictionary = {}  # {player_id: {target_faction_id: turns_remaining}}

func _ready() -> void:
	pass

func reset() -> void:
	_relations.clear()
	_ceasefire.clear()

func init_player(player_id: int) -> void:
	_relations[player_id] = {}
	for fid in [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]:
		if fid != GameManager.get_player_faction(player_id):
			_relations[player_id][fid] = {"hostile": false, "recruited": false, "method": "", "rebellion_turns": 0}

func mark_hostile(player_id: int, faction_id: int) -> void:
	## Called when player attacks a faction's outpost. Locks out diplomacy.
	if _relations.has(player_id) and _relations[player_id].has(faction_id):
		_relations[player_id][faction_id]["hostile"] = true
		EventBus.message_log.emit("[color=red]对该军团的外交途径已关闭![/color]")

func is_orc_player(player_id: int) -> bool:
	return GameManager.get_player_faction(player_id) == FactionData.FactionID.ORC

func can_diplomacy(player_id: int, faction_id: int) -> Dictionary:
	## Check if diplomatic recruitment is possible.
	## Returns { "possible": bool, "missing": Array of String }
	# Orc players cannot use diplomacy at all
	if is_orc_player(player_id):
		return {"possible": false, "missing": ["兽人部落只懂得征服! 无法进行外交收编"]}
	var result := {"possible": true, "missing": []}
	if not _relations.has(player_id) or not _relations[player_id].has(faction_id):
		return {"possible": false, "missing": ["无效阵营"]}
	var rel: Dictionary = _relations[player_id][faction_id]
	if rel["recruited"]:
		return {"possible": false, "missing": ["已收编"]}
	if rel["hostile"]:
		result["possible"] = false
		result["missing"].append("已对该军团发动过攻击")

	var costs: Dictionary = FactionData.EVIL_FACTION_DIPLOMACY_COSTS.get(faction_id, {})
	if costs.is_empty():
		return {"possible": false, "missing": ["无外交数据"]}

	if ResourceManager.get_resource(player_id, "prestige") < costs.get("prestige", 0):
		result["possible"] = false
		result["missing"].append("威望不足 (需要%d)" % costs["prestige"])
	if ResourceManager.get_resource(player_id, "gold") < costs.get("gold", 0):
		result["possible"] = false
		result["missing"].append("金币不足 (需要%d)" % costs["gold"])
	if OrderManager.get_order() < costs.get("order_min", 0):
		result["possible"] = false
		result["missing"].append("秩序值不足 (需要%d)" % costs["order_min"])

	return result

func recruit_by_diplomacy(player_id: int, faction_id: int) -> bool:
	## Peacefully recruit a faction. Deducts costs.
	var check: Dictionary = can_diplomacy(player_id, faction_id)
	if not check["possible"]:
		return false
	var costs: Dictionary = FactionData.EVIL_FACTION_DIPLOMACY_COSTS[faction_id]
	ResourceManager.spend(player_id, {"gold": costs["gold"], "prestige": costs["prestige"]})
	_relations[player_id][faction_id]["recruited"] = true
	_relations[player_id][faction_id]["method"] = "diplomacy"

	_grant_faction_outposts(player_id, faction_id)
	_grant_weakened_abilities(player_id, faction_id)

	OrderManager.change_order(10)  # +10 order for successful diplomacy
	var fname: String = _get_faction_name(faction_id)
	EventBus.message_log.emit("[color=green]通过外交手段成功收编 %s![/color]" % fname)
	EventBus.faction_recruited.emit(player_id, faction_id)
	# v0.8.5: Reduce AI threat for diplomatically recruited faction
	var ai_key: String = _faction_to_ai_key(faction_id)
	if ai_key != "":
		AIScaling.on_treaty_signed(ai_key)
	return true

func recruit_by_conquest(player_id: int, faction_id: int) -> void:
	## Called after player captures the faction's core fortress.
	if not _relations.has(player_id) or not _relations[player_id].has(faction_id):
		return
	_relations[player_id][faction_id]["recruited"] = true
	_relations[player_id][faction_id]["method"] = "conquest"
	_relations[player_id][faction_id]["rebellion_turns"] = 5

	_grant_faction_outposts(player_id, faction_id)
	_grant_weakened_abilities(player_id, faction_id)

	OrderManager.change_order(-8)  # -8 order for forced conquest
	var fname: String = _get_faction_name(faction_id)
	EventBus.message_log.emit("[color=yellow]武力征服 %s! 秩序-8, 据点可能叛乱[/color]" % fname)
	EventBus.faction_recruited.emit(player_id, faction_id)

func tick_rebellion(player_id: int) -> void:
	## Called each turn. Check for rebellion in conquered faction's outposts.
	if not _relations.has(player_id):
		return
	for faction_id in _relations[player_id]:
		var rel: Dictionary = _relations[player_id][faction_id]
		if rel["method"] != "conquest" or rel["rebellion_turns"] <= 0:
			continue
		rel["rebellion_turns"] -= 1
		# 15% rebellion chance per conquered outpost
		for n_idx in range(GameManager.tiles.size()):
			if n_idx < 0 or n_idx >= GameManager.tiles.size():
				continue
			var tile: Dictionary = GameManager.tiles[n_idx]
			if tile["owner_id"] != player_id:
				continue
			if tile.get("original_faction", -1) != faction_id:
				continue
			if randi() % 100 < 15:
				tile["owner_id"] = -1
				tile["garrison"] = randi_range(10, 15)
				var fname: String = _get_faction_name(faction_id)
				EventBus.message_log.emit("[color=red]%s 的据点发生叛乱! 据点#%d 失守[/color]" % [fname, tile["index"]])
				OrderManager.change_order(-3)

func is_recruited(player_id: int, faction_id: int) -> bool:
	if not _relations.has(player_id) or not _relations[player_id].has(faction_id):
		return false
	return _relations[player_id][faction_id]["recruited"]

func get_recruitment_method(player_id: int, faction_id: int) -> String:
	if not _relations.has(player_id) or not _relations[player_id].has(faction_id):
		return ""
	return _relations[player_id][faction_id]["method"]

func get_all_relations(player_id: int) -> Dictionary:
	return _relations.get(player_id, {})

func _grant_faction_outposts(player_id: int, faction_id: int) -> void:
	## Transfer all faction outposts to the player.
	for tile in GameManager.tiles:
		if tile.get("original_faction", -1) == faction_id and tile["owner_id"] < 0:
			tile["owner_id"] = player_id
			tile["original_faction"] = faction_id
			EventBus.territory_changed.emit(tile["index"], player_id)

func _grant_weakened_abilities(player_id: int, faction_id: int) -> void:
	## Unlock weakened abilities based on conquered/recruited faction.
	match faction_id:
		FactionData.FactionID.ORC:
			EventBus.message_log.emit("解锁: 兽人杂兵招募 + 图腾柱建筑 + WAAAGH!(减半效果)")
		FactionData.FactionID.PIRATE:
			EventBus.message_log.emit("解锁: 海盗散兵招募 + 黑市建筑 + 掠夺值(减半效果)")
		FactionData.FactionID.DARK_ELF:
			EventBus.message_log.emit("解锁: 暗精灵战士招募 + 苦痛神殿建筑 + 奴隶分配(仅2工位)")

func has_weakened_ability(player_id: int, faction_id: int) -> bool:
	return is_recruited(player_id, faction_id)

func _get_faction_name(faction_id: int) -> String:
	match faction_id:
		FactionData.FactionID.ORC: return "兽人部落"
		FactionData.FactionID.PIRATE: return "暗夜海盗团"
		FactionData.FactionID.DARK_ELF: return "暗精灵议会"
	return "未知"


func _faction_to_ai_key(faction_id: int) -> String:
	## v0.8.5: Map faction ID to AIScaling key.
	match faction_id:
		FactionData.FactionID.ORC: return "orc_ai"
		FactionData.FactionID.PIRATE: return "pirate_ai"
		FactionData.FactionID.DARK_ELF: return "dark_elf_ai"
	return ""


# ═══════════════ CEASEFIRE (ORC-ONLY) ═══════════════

func offer_ceasefire(player_id: int, faction_id: int, turns: int = 5) -> bool:
	## Orc can offer ceasefire (costs gold, temporary peace)
	if not is_orc_player(player_id):
		return false  # Only orcs use this
	var cost: int = 100  # Ceasefire costs gold (tribute)
	if not ResourceManager.can_afford(player_id, {"gold": cost}):
		EventBus.message_log.emit("[color=red]金币不足! 停战需要%d金作为贡品[/color]" % cost)
		return false
	ResourceManager.spend(player_id, {"gold": cost})
	if not _ceasefire.has(player_id):
		_ceasefire[player_id] = {}
	_ceasefire[player_id][faction_id] = turns
	if not _relations.has(player_id):
		_relations[player_id] = {}
	if not _relations[player_id].has(faction_id):
		_relations[player_id][faction_id] = {"hostile": false, "recruited": false, "method": "", "rebellion_turns": 0}
	_relations[player_id][faction_id]["hostile"] = false
	EventBus.message_log.emit("[color=yellow]与%s达成停战协议! %d回合内不可互攻[/color]" % [_get_faction_name(faction_id), turns])
	return true

func is_ceasefire_active(player_id: int, faction_id: int) -> bool:
	if not _ceasefire.has(player_id):
		return false
	return _ceasefire[player_id].get(faction_id, 0) > 0

func tick_ceasefire(player_id: int) -> void:
	## Called each turn to decrement ceasefire timers
	if not _ceasefire.has(player_id):
		return
	for fid in _ceasefire[player_id]:
		if _ceasefire[player_id][fid] > 0:
			_ceasefire[player_id][fid] -= 1
			if _ceasefire[player_id][fid] <= 0:
				EventBus.message_log.emit("[color=red]与%s的停战协议已到期![/color]" % _get_faction_name(fid))

# ═══════════════ DIPLOMACY UI ACTIONS ═══════════════

func get_available_actions(player_id: int, faction_id: int) -> Array:
	## Returns list of available diplomatic actions for UI display
	var actions: Array = []
	if is_orc_player(player_id):
		# Orc: only war/ceasefire
		var rel = _relations.get(player_id, {}).get(faction_id, {})
		if rel.get("hostile", false) and not is_ceasefire_active(player_id, faction_id):
			actions.append({"id": "ceasefire", "name": "停战协议", "cost": "100金", "desc": "贡品换取5回合和平"})
		elif not rel.get("hostile", false):
			actions.append({"id": "declare_war", "name": "宣战", "cost": "无", "desc": "兽人只懂征服!"})
		return actions
	# Non-orc: full diplomacy options
	if not _relations.get(player_id, {}).get(faction_id, {}).get("recruited", false):
		var check = can_diplomacy(player_id, faction_id)
		if check["possible"]:
			actions.append({"id": "recruit_diplomacy", "name": "外交收编", "cost": "威望+金币", "desc": "和平收编该势力"})
	return actions


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"relations": _relations.duplicate(true),
		"ceasefire": _ceasefire.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_relations = data.get("relations", {}).duplicate(true)
	_ceasefire = data.get("ceasefire", {}).duplicate(true)
