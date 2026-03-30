extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## diplomacy_manager.gd - Full diplomacy, treaties & tribute system (v3.4)
## Manages evil faction relations, light faction diplomacy, tribute, trade, and alliances.

# ── Evil faction relations ──
# { player_id: { faction_id: { "hostile": bool, "recruited": bool, "method": String, "rebellion_turns": int } } }
var _relations: Dictionary = {}
var _ceasefire: Dictionary = {}  # {player_id: {target_faction_id: turns_remaining}}

# ── Treaty system (v3.4) ──
# { player_id: [ { "type": String, "target": int, "turns_left": int, "gold_per_turn": int, ... }, ... ] }
var _treaties: Dictionary = {}

# ── Light faction diplomacy ──
var _light_ceasefire_turns: int = 0  # Remaining turns of light ceasefire
var _light_extort_cooldown: int = 0  # Cooldown for light extortion
var _pending_light_peace: Dictionary = {}  # {"active": bool, "gold": int} — pending peace offer from light

# ── Reputation System (v3.5) ──
# { faction_key: int } — reputation per faction, -100 to +100
var _reputation: Dictionary = {}
const REPUTATION_DECAY_RATE: int = 1  # decay 1 point toward 0 per turn

func _ready() -> void:
	pass

func reset() -> void:
	_relations.clear()
	_ceasefire.clear()
	_treaties.clear()
	_light_ceasefire_turns = 0
	_light_extort_cooldown = 0
	_pending_light_peace = {}
	_reputation.clear()
	_event_cooldowns.clear()
	_diplo_event_counter = 0

func init_player(player_id: int) -> void:
	_relations[player_id] = {}
	_treaties[player_id] = []
	for fid in [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]:
		if fid != GameManager.get_player_faction(player_id):
			_relations[player_id][fid] = {"hostile": false, "recruited": false, "method": "", "rebellion_turns": 0}
	# Initialize reputation for all factions
	for key in ["human", "elf", "mage", "orc_ai", "pirate_ai", "dark_elf_ai"]:
		if not _reputation.has(key):
			_reputation[key] = 0

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

	# BUG FIX R18: use .get() consistently for costs dictionary access
	var prestige_cost: int = costs.get("prestige", 0)
	var gold_cost: int = costs.get("gold", 0)
	var order_min: int = costs.get("order_min", 0)
	if ResourceManager.get_resource(player_id, "prestige") < prestige_cost:
		result["possible"] = false
		result["missing"].append("威望不足 (需要%d)" % prestige_cost)
	if ResourceManager.get_resource(player_id, "gold") < gold_cost:
		result["possible"] = false
		result["missing"].append("金币不足 (需要%d)" % gold_cost)
	if OrderManager.get_order() < order_min:
		result["possible"] = false
		result["missing"].append("秩序值不足 (需要%d)" % order_min)

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
	# Reputation boost for diplomatic recruitment
	var rep_key: String = _faction_to_ai_key(faction_id)
	if rep_key != "":
		change_reputation(rep_key, 30)
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
	# Reputation: conquest penalty
	var rep_key: String = _faction_to_ai_key(faction_id)
	if rep_key != "":
		change_reputation(rep_key, -20)

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
			# BUG FIX R18: use .get() for owner_id
			if tile.get("owner_id", -1) != player_id:
				continue
			if tile.get("original_faction", -1) != faction_id:
				continue
			if randi() % 100 < 15:
				tile["owner_id"] = -1
				tile["garrison"] = randi_range(10, 15)
				var fname: String = _get_faction_name(faction_id)
				EventBus.message_log.emit("[color=red]%s 的据点发生叛乱! 据点#%d 失守[/color]" % [fname, tile["index"]])
				EventBus.rebellion_occurred.emit(tile["index"])
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


func improve_relation(player_id: int, faction_id: int, amount: int) -> void:
	## Improve the relation value with a faction by the given amount.
	if not _relations.has(player_id):
		_relations[player_id] = {}
	if not _relations[player_id].has(faction_id):
		_relations[player_id][faction_id] = {"hostile": false, "recruited": false, "method": "", "rebellion_turns": 0}
	# If relation is hostile, a large enough improvement can de-escalate
	if amount > 0 and _relations[player_id][faction_id].get("hostile", false):
		_relations[player_id][faction_id]["hostile"] = false
	EventBus.message_log.emit("[color=green]与%s的关系改善了 +%d[/color]" % [_get_faction_name(faction_id), amount])

func _grant_faction_outposts(player_id: int, faction_id: int) -> void:
	## Transfer all faction outposts to the player.
	for tile in GameManager.tiles:
		# BUG FIX R18: null check + .get() for safety
		if tile == null:
			continue
		if tile.get("original_faction", -1) == faction_id and tile.get("owner_id", -1) < 0:
			tile["owner_id"] = player_id
			tile["original_faction"] = faction_id
			EventBus.territory_changed.emit(tile.get("index", -1), player_id)

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


# ═══════════════ REPUTATION SYSTEM (v3.5) ═══════════════

func get_reputation(faction_key: String) -> int:
	return _reputation.get(faction_key, 0)


func change_reputation(faction_key: String, delta: int) -> void:
	var old_val: int = _reputation.get(faction_key, 0)
	_reputation[faction_key] = clampi(old_val + delta, -100, 100)
	if _reputation[faction_key] != old_val:
		EventBus.message_log.emit("[声望] %s: %d → %d" % [faction_key, old_val, _reputation[faction_key]])


func get_reputation_level(faction_key: String) -> String:
	var rep: int = get_reputation(faction_key)
	if rep < -50:
		return "敌对"
	elif rep < -20:
		return "警惕"
	elif rep <= 30:
		return "中立"
	elif rep <= 80:
		return "友好"
	else:
		return "盟友"


func is_reputation_hostile(faction_key: String) -> bool:
	return get_reputation(faction_key) < -50


func is_reputation_friendly(faction_key: String) -> bool:
	return get_reputation(faction_key) > 30


func get_all_reputations() -> Dictionary:
	return _reputation.duplicate()


func tick_reputation_decay() -> void:
	## Natural decay: reputation moves 1 point toward 0 each turn.
	for key in _reputation:
		if _reputation[key] > 0:
			_reputation[key] -= REPUTATION_DECAY_RATE
		elif _reputation[key] < 0:
			_reputation[key] += REPUTATION_DECAY_RATE


# ═══════════════ REPUTATION GAMEPLAY IMPACT (v4.3) ═══════════════

## Track total treaty-breaking count for "背信弃义" debuff
var _treaty_breaks_total: int = 0

# ── SR07-Style Dynamic Diplomatic Events ──
# Cooldown tracker: { event_type_string: turns_remaining }
var _event_cooldowns: Dictionary = {}
# Running event ID counter for unique identification
var _diplo_event_counter: int = 0
# Event type constants
const DIPLO_EVT_BORDER_INCIDENT := "border_incident"
const DIPLO_EVT_TRADE_OPPORTUNITY := "trade_opportunity"
const DIPLO_EVT_ALLIANCE_PROPOSAL := "alliance_proposal"
const DIPLO_EVT_BETRAYAL := "betrayal"
const DIPLO_EVT_REFUGEE_CRISIS := "refugee_crisis"
# Chance range: 10-15% per eligible faction per turn
const DIPLO_EVT_CHANCE_MIN: float = 0.10
const DIPLO_EVT_CHANCE_MAX: float = 0.15
const DIPLO_EVT_COOLDOWN_TURNS: int = 2  # Same event type can't fire 2 turns in a row


func get_reputation_cost_multiplier(faction_key: String) -> float:
	## Returns a cost multiplier for diplomacy actions based on reputation.
	## Friendly = cheaper (0.80x), hostile = more expensive (1.50x).
	var rep: int = get_reputation(faction_key)
	if rep > 30:
		return BalanceConfig.REPUTATION_FRIENDLY_COST_MULT
	elif rep < -50:
		return BalanceConfig.REPUTATION_HOSTILE_COST_MULT
	return 1.0


func get_reputation_duration_modifier(faction_key: String) -> int:
	## Returns a treaty duration modifier based on reputation.
	## Friendly = +2 turns, hostile = -2 turns.
	var rep: int = get_reputation(faction_key)
	if rep > 30:
		return BalanceConfig.REPUTATION_FRIENDLY_DURATION_BONUS
	elif rep < -50:
		return -BalanceConfig.REPUTATION_HOSTILE_DURATION_PENALTY
	return 0


func is_trade_blocked_by_reputation(faction_key: String) -> bool:
	## Returns true if reputation is too low for trade.
	return get_reputation(faction_key) < BalanceConfig.REPUTATION_TRADE_BLOCK_THRESHOLD


func is_alliance_blocked_by_reputation(faction_key: String) -> bool:
	## Returns true if reputation is too low for military alliance.
	return get_reputation(faction_key) < BalanceConfig.REPUTATION_ALLIANCE_THRESHOLD


func get_treaty_breaks_total() -> int:
	return _treaty_breaks_total


func _apply_treaty_break_cascade(target_faction: int) -> void:
	## Breaking a treaty hurts reputation with ALL factions, not just the target.
	_treaty_breaks_total += 1
	for key in _reputation:
		change_reputation(key, BalanceConfig.TREATY_BREAK_REPUTATION_CASCADE)
	EventBus.message_log.emit("[color=red]背盟行为传遍各地! 所有势力声望%d[/color]" % BalanceConfig.TREATY_BREAK_REPUTATION_CASCADE)
	# Check for "背信弃义" debuff threshold
	if _treaty_breaks_total >= BalanceConfig.TREATY_BREAK_THRESHOLD:
		var pid: int = GameManager.get_human_player_id()
		BuffManager.add_buff(pid, "treachery_debuff", "atk_pct",
			-BalanceConfig.TREATY_BREAK_DEBUFF_ATK_PENALTY * 100,
			BalanceConfig.TREATY_BREAK_DEBUFF_DURATION, "reputation")
		EventBus.message_log.emit("[color=red]【背信弃义】连续背盟%d次! ATK-%d%% 持续%d回合[/color]" % [
			_treaty_breaks_total,
			int(BalanceConfig.TREATY_BREAK_DEBUFF_ATK_PENALTY * 100),
			BalanceConfig.TREATY_BREAK_DEBUFF_DURATION])


func get_tile_combat_bonuses(tile_idx: int) -> Dictionary:
	## Returns combat bonuses for units fighting at/from a developed tile.
	## Military path: +ATK per building, +morale per building
	## Cultural path: hero skill CD-1
	## Economic path: supply bonus
	var bonuses: Dictionary = {"atk": 0, "def": 0, "morale": 0, "supply": 0, "hero_cd_reduction": 0}
	if not _has_autoload("TileDevelopment"):
		return bonuses
	var td: Node = _get_autoload("TileDevelopment")
	if td == null:
		return bonuses
	var dev: Dictionary = td.get_tile_development(tile_idx)
	if dev["path"] == td.DevPath.UNDEVELOPED:
		return bonuses
	var num_buildings: int = dev["buildings"].size()
	match dev["path"]:
		td.DevPath.MILITARY:
			bonuses["atk"] = BalanceConfig.TILE_MILITARY_GARRISON_ATK * num_buildings
			bonuses["morale"] = BalanceConfig.TILE_MILITARY_GARRISON_MORALE * num_buildings
		td.DevPath.CULTURAL:
			bonuses["hero_cd_reduction"] = BalanceConfig.TILE_CULTURAL_HERO_CD_REDUCTION if num_buildings >= 2 else 0
		td.DevPath.ECONOMIC:
			bonuses["supply"] = BalanceConfig.TILE_ECONOMIC_SUPPLY_BONUS if num_buildings >= 2 else 0
	return bonuses


func _has_autoload(aname: String) -> bool:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		return (tree as SceneTree).root.has_node(aname)
	return false


func _get_autoload(aname: String) -> Node:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var root: Node = (tree as SceneTree).root
		if root.has_node(aname):
			return root.get_node(aname)
	return null


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
	# BUG修复: 停战不再重置hostile标记，改用ceasefire_active抑制敌对检查
	if not _relations[player_id][faction_id].has("was_hostile"):
		_relations[player_id][faction_id]["was_hostile"] = _relations[player_id][faction_id]["hostile"]
	_relations[player_id][faction_id]["ceasefire_active"] = true
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
				# BUG修复: 停战到期后恢复原始hostile状态（但已收编则跳过）
				if _relations.has(player_id) and _relations[player_id].has(fid):
					_relations[player_id][fid]["ceasefire_active"] = false
					if not _relations[player_id][fid].get("recruited", false):
						if _relations[player_id][fid].get("was_hostile", false):
							_relations[player_id][fid]["hostile"] = true
				EventBus.message_log.emit("[color=red]与%s的停战协议已到期![/color]" % _get_faction_name(fid))


# ═══════════════ TREATY SYSTEM (v3.4) ═══════════════

func _get_player_treaties(player_id: int) -> Array:
	if not _treaties.has(player_id):
		_treaties[player_id] = []
	return _treaties[player_id]


func has_treaty(player_id: int, treaty_type: String, target_faction: int) -> bool:
	for t in _get_player_treaties(player_id):
		if t["type"] == treaty_type and t["target"] == target_faction and t["turns_left"] > 0:
			return true
	return false


func get_treaty(player_id: int, treaty_type: String, target_faction: int) -> Dictionary:
	for t in _get_player_treaties(player_id):
		if t["type"] == treaty_type and t["target"] == target_faction and t["turns_left"] > 0:
			return t
	return {}


func count_treaties_of_type(player_id: int, treaty_type: String) -> int:
	var count: int = 0
	for t in _get_player_treaties(player_id):
		if t["type"] == treaty_type and t["turns_left"] > 0:
			count += 1
	return count


## ── Tribute (朝贡) ──

func can_demand_tribute(player_id: int, target_faction: int) -> Dictionary:
	## Check if player can demand tribute from an evil faction.
	var result := {"possible": true, "missing": [], "gold_per_turn": 0}
	if has_treaty(player_id, "tribute_receive", target_faction):
		return {"possible": false, "missing": ["已有朝贡协议"], "gold_per_turn": 0}
	if has_treaty(player_id, "tribute_pay", target_faction):
		return {"possible": false, "missing": ["你正在向其纳贡"], "gold_per_turn": 0}
	var rel: Dictionary = _relations.get(player_id, {}).get(target_faction, {})
	if rel.get("recruited", false):
		return {"possible": false, "missing": ["已收编"], "gold_per_turn": 0}
	# Strength comparison: player tiles vs faction tiles
	var player_tiles: int = GameManager.count_tiles_owned(player_id)
	var faction_tiles: int = _count_faction_tiles(target_faction)
	if faction_tiles <= 0:
		return {"possible": false, "missing": ["该势力已无领地"], "gold_per_turn": 0}
	var ratio: float = float(player_tiles) / float(maxi(1, faction_tiles))
	if ratio < BalanceConfig.TRIBUTE_MIN_STRENGTH_RATIO:
		result["possible"] = false
		result["missing"].append("实力不足(需要%.1f倍领地, 当前%.1f倍)" % [BalanceConfig.TRIBUTE_MIN_STRENGTH_RATIO, ratio])
	var diff: int = maxi(0, player_tiles - faction_tiles)
	result["gold_per_turn"] = BalanceConfig.TRIBUTE_GOLD_PER_TURN_BASE + diff * BalanceConfig.TRIBUTE_GOLD_PER_TILE_DIFF
	return result


func demand_tribute(player_id: int, target_faction: int) -> bool:
	var check: Dictionary = can_demand_tribute(player_id, target_faction)
	if not check["possible"]:
		return false
	var treaty := {
		"type": "tribute_receive",
		"target": target_faction,
		"turns_left": BalanceConfig.TRIBUTE_DURATION,
		"gold_per_turn": check["gold_per_turn"],
	}
	_get_player_treaties(player_id).append(treaty)
	var fname: String = _get_faction_name(target_faction)
	EventBus.message_log.emit("[color=gold]%s 被迫向你朝贡! 每回合+%d金, 持续%d回合[/color]" % [
		fname, check["gold_per_turn"], BalanceConfig.TRIBUTE_DURATION])
	EventBus.treaty_signed.emit(player_id, "tribute_receive", target_faction)
	return true


func offer_tribute(player_id: int, target_faction: int) -> bool:
	## Player voluntarily pays tribute to buy peace (纳贡求和).
	if has_treaty(player_id, "tribute_pay", target_faction):
		EventBus.message_log.emit("[color=red]已有纳贡协议[/color]")
		return false
	var prestige: int = ResourceManager.get_resource(player_id, "prestige")
	if prestige < BalanceConfig.TRIBUTE_OFFER_PRESTIGE_COST:
		EventBus.message_log.emit("[color=red]威望不足(需要%d)[/color]" % BalanceConfig.TRIBUTE_OFFER_PRESTIGE_COST)
		return false
	ResourceManager.apply_delta(player_id, {"prestige": -BalanceConfig.TRIBUTE_OFFER_PRESTIGE_COST})
	var gold_per_turn: int = BalanceConfig.TRIBUTE_GOLD_PER_TURN_BASE
	var treaty := {
		"type": "tribute_pay",
		"target": target_faction,
		"turns_left": BalanceConfig.TRIBUTE_DURATION,
		"gold_per_turn": gold_per_turn,
	}
	_get_player_treaties(player_id).append(treaty)
	# Tribute payment reduces hostility
	if _relations.has(player_id) and _relations[player_id].has(target_faction):
		_relations[player_id][target_faction]["hostile"] = false
		# Clear was_hostile so ceasefire expiry won't re-hostile
		_relations[player_id][target_faction]["was_hostile"] = false
	var fname: String = _get_faction_name(target_faction)
	EventBus.message_log.emit("[color=yellow]向%s纳贡求和! 每回合-%d金, 持续%d回合, 双方停止敌对[/color]" % [
		fname, gold_per_turn, BalanceConfig.TRIBUTE_DURATION])
	EventBus.treaty_signed.emit(player_id, "tribute_pay", target_faction)
	return true


## ── Non-Aggression Pact (互不侵犯条约) ──

func can_sign_nap(player_id: int, target_faction: int) -> Dictionary:
	var result := {"possible": true, "missing": []}
	if has_treaty(player_id, "nap", target_faction):
		return {"possible": false, "missing": ["已有互不侵犯条约"]}
	var rel: Dictionary = _relations.get(player_id, {}).get(target_faction, {})
	if rel.get("recruited", false):
		return {"possible": false, "missing": ["已收编"]}
	if rel.get("hostile", false):
		result["possible"] = false
		result["missing"].append("已敌对, 无法签约(需先停战)")
	if not ResourceManager.can_afford(player_id, {"gold": BalanceConfig.NAP_COST_GOLD}):
		result["possible"] = false
		result["missing"].append("金币不足(需要%d金)" % BalanceConfig.NAP_COST_GOLD)
	if ResourceManager.get_resource(player_id, "prestige") < BalanceConfig.NAP_COST_PRESTIGE:
		result["possible"] = false
		result["missing"].append("威望不足(需要%d)" % BalanceConfig.NAP_COST_PRESTIGE)
	return result


func sign_nap(player_id: int, target_faction: int) -> bool:
	var check: Dictionary = can_sign_nap(player_id, target_faction)
	if not check["possible"]:
		return false
	ResourceManager.spend(player_id, {"gold": BalanceConfig.NAP_COST_GOLD, "prestige": BalanceConfig.NAP_COST_PRESTIGE})
	var treaty := {
		"type": "nap",
		"target": target_faction,
		"turns_left": BalanceConfig.NAP_DURATION,
	}
	_get_player_treaties(player_id).append(treaty)
	var fname: String = _get_faction_name(target_faction)
	EventBus.message_log.emit("[color=cyan]与%s签订互不侵犯条约! 持续%d回合[/color]" % [fname, BalanceConfig.NAP_DURATION])
	EventBus.treaty_signed.emit(player_id, "nap", target_faction)
	return true


## ── Military Alliance (军事同盟) ──

func can_sign_alliance(player_id: int, target_faction: int) -> Dictionary:
	var result := {"possible": true, "missing": []}
	if has_treaty(player_id, "alliance", target_faction):
		return {"possible": false, "missing": ["已有军事同盟"]}
	var rel: Dictionary = _relations.get(player_id, {}).get(target_faction, {})
	if rel.get("recruited", false):
		return {"possible": false, "missing": ["已收编"]}
	if rel.get("hostile", false):
		return {"possible": false, "missing": ["已敌对, 无法结盟"]}
	# Need NAP first
	if not has_treaty(player_id, "nap", target_faction):
		result["possible"] = false
		result["missing"].append("需要先签订互不侵犯条约")
	# v4.3: Reputation gate — need minimum reputation for alliance
	var rep_key: String = _faction_to_ai_key(target_faction)
	if rep_key != "" and is_alliance_blocked_by_reputation(rep_key):
		result["possible"] = false
		result["missing"].append("声望不足(需≥%d), 对方不信任你" % BalanceConfig.REPUTATION_ALLIANCE_THRESHOLD)
	# v4.3: Reputation-adjusted costs
	var cost_mult: float = get_reputation_cost_multiplier(rep_key) if rep_key != "" else 1.0
	var adjusted_gold: int = int(BalanceConfig.ALLIANCE_EVIL_COST_GOLD * cost_mult)
	var adjusted_prestige: int = int(BalanceConfig.ALLIANCE_EVIL_COST_PRESTIGE * cost_mult)
	if not ResourceManager.can_afford(player_id, {"gold": adjusted_gold}):
		result["possible"] = false
		result["missing"].append("金币不足(需要%d金)" % adjusted_gold)
	if ResourceManager.get_resource(player_id, "prestige") < adjusted_prestige:
		result["possible"] = false
		result["missing"].append("威望不足(需要%d)" % adjusted_prestige)
	return result


func sign_alliance(player_id: int, target_faction: int) -> bool:
	var check: Dictionary = can_sign_alliance(player_id, target_faction)
	if not check["possible"]:
		return false
	# v4.3: Reputation-adjusted costs and duration
	var rep_key: String = _faction_to_ai_key(target_faction)
	var cost_mult: float = get_reputation_cost_multiplier(rep_key) if rep_key != "" else 1.0
	var adjusted_gold: int = int(BalanceConfig.ALLIANCE_EVIL_COST_GOLD * cost_mult)
	var adjusted_prestige: int = int(BalanceConfig.ALLIANCE_EVIL_COST_PRESTIGE * cost_mult)
	var dur_mod: int = get_reputation_duration_modifier(rep_key) if rep_key != "" else 0
	var adjusted_duration: int = maxi(3, BalanceConfig.ALLIANCE_EVIL_DURATION + dur_mod)
	ResourceManager.spend(player_id, {"gold": adjusted_gold, "prestige": adjusted_prestige})
	var treaty := {
		"type": "alliance",
		"target": target_faction,
		"turns_left": adjusted_duration,
	}
	_get_player_treaties(player_id).append(treaty)
	var fname: String = _get_faction_name(target_faction)
	EventBus.message_log.emit("[color=lime]与%s缔结军事同盟! ATK+%d%% DEF+%d%%, 持续%d回合[/color]" % [
		fname, int(BalanceConfig.ALLIANCE_EVIL_ATK_BONUS * 100),
		int(BalanceConfig.ALLIANCE_EVIL_DEF_BONUS * 100), adjusted_duration])
	if cost_mult != 1.0:
		EventBus.message_log.emit("[color=gray](声望影响: 费用x%.0f%%, 时长%+d回合)[/color]" % [cost_mult * 100, dur_mod])
	EventBus.treaty_signed.emit(player_id, "alliance", target_faction)
	# Reduce AI threat for allied faction
	var ai_key: String = _faction_to_ai_key(target_faction)
	if ai_key != "":
		AIScaling.on_treaty_signed(ai_key)
	return true


## ── Trade Agreement (通商协定) ──

func can_sign_trade(player_id: int, target_faction: int) -> Dictionary:
	var result := {"possible": true, "missing": []}
	if has_treaty(player_id, "trade", target_faction):
		return {"possible": false, "missing": ["已有通商协定"]}
	if count_treaties_of_type(player_id, "trade") >= BalanceConfig.TRADE_MAX_AGREEMENTS:
		return {"possible": false, "missing": ["通商上限(%d个)" % BalanceConfig.TRADE_MAX_AGREEMENTS]}
	var rel: Dictionary = _relations.get(player_id, {}).get(target_faction, {})
	if rel.get("recruited", false):
		return {"possible": false, "missing": ["已收编"]}
	if rel.get("hostile", false):
		result["possible"] = false
		result["missing"].append("已敌对, 无法通商")
	# v4.3: Reputation gate — too low reputation blocks trade
	var rep_key: String = _faction_to_ai_key(target_faction)
	if rep_key != "" and is_trade_blocked_by_reputation(rep_key):
		result["possible"] = false
		result["missing"].append("声望过低(<%d), 对方拒绝通商" % BalanceConfig.REPUTATION_TRADE_BLOCK_THRESHOLD)
	if not ResourceManager.can_afford(player_id, {"gold": BalanceConfig.TRADE_COST_GOLD}):
		result["possible"] = false
		result["missing"].append("金币不足(需要%d金)" % BalanceConfig.TRADE_COST_GOLD)
	return result


func sign_trade(player_id: int, target_faction: int) -> bool:
	var check: Dictionary = can_sign_trade(player_id, target_faction)
	if not check["possible"]:
		return false
	ResourceManager.spend(player_id, {"gold": BalanceConfig.TRADE_COST_GOLD})
	var treaty := {
		"type": "trade",
		"target": target_faction,
		"turns_left": BalanceConfig.TRADE_DURATION,
	}
	_get_player_treaties(player_id).append(treaty)
	var fname: String = _get_faction_name(target_faction)
	EventBus.message_log.emit("[color=cyan]与%s签订通商协定! 每回合+%d金+%d粮, 持续%d回合[/color]" % [
		fname, BalanceConfig.TRADE_INCOME_SELF, BalanceConfig.TRADE_FOOD_BONUS, BalanceConfig.TRADE_DURATION])
	EventBus.treaty_signed.emit(player_id, "trade", target_faction)
	return true


## ── Break Treaty (撕毁条约) ──

func break_treaty(player_id: int, treaty_type: String, target_faction: int) -> bool:
	var treaties: Array = _get_player_treaties(player_id)
	for i in range(treaties.size()):
		if treaties[i]["type"] == treaty_type and treaties[i]["target"] == target_faction and treaties[i]["turns_left"] > 0:
			treaties[i]["turns_left"] = 0
			var fname: String = _get_faction_name(target_faction)
			# Apply penalties based on treaty type
			match treaty_type:
				"nap":
					ResourceManager.apply_delta(player_id, {"prestige": -BalanceConfig.NAP_BREAK_PRESTIGE_PENALTY})
					OrderManager.change_order(BalanceConfig.NAP_BREAK_ORDER_PENALTY)
					EventBus.message_log.emit("[color=red]撕毁与%s的互不侵犯条约! 威望-%d 秩序%d[/color]" % [
						fname, BalanceConfig.NAP_BREAK_PRESTIGE_PENALTY, BalanceConfig.NAP_BREAK_ORDER_PENALTY])
					# Also breaks alliance if exists
					if has_treaty(player_id, "alliance", target_faction):
						break_treaty(player_id, "alliance", target_faction)
				"alliance":
					ResourceManager.apply_delta(player_id, {"prestige": -BalanceConfig.ALLIANCE_EVIL_BREAK_PENALTY})
					EventBus.message_log.emit("[color=red]撕毁与%s的军事同盟! 威望-%d[/color]" % [
						fname, BalanceConfig.ALLIANCE_EVIL_BREAK_PENALTY])
				"tribute_receive", "tribute_pay":
					ResourceManager.apply_delta(player_id, {"prestige": -BalanceConfig.TRIBUTE_BREAK_PRESTIGE_COST})
					ThreatManager.change_threat(BalanceConfig.TRIBUTE_BREAK_THREAT_GAIN)
					EventBus.message_log.emit("[color=red]撕毁与%s的朝贡协议! 威望-%d 威胁+%d[/color]" % [
						fname, BalanceConfig.TRIBUTE_BREAK_PRESTIGE_COST, BalanceConfig.TRIBUTE_BREAK_THREAT_GAIN])
				"trade":
					EventBus.message_log.emit("[color=yellow]终止与%s的通商协定[/color]" % fname)
			# v4.3: Reputation cascade — breaking any treaty hurts ALL reputations
			_apply_treaty_break_cascade(target_faction)
			EventBus.treaty_broken.emit(player_id, treaty_type, target_faction)
			return true
	return false


## ── Treaty Tick (每回合处理) ──

func tick_treaties(player_id: int) -> void:
	## Called each turn. Process all active treaties: collect tribute, trade income, expire treaties.
	var treaties: Array = _get_player_treaties(player_id)
	var expired: Array = []

	for treaty in treaties:
		if treaty["turns_left"] <= 0:
			continue
		treaty["turns_left"] -= 1

		match treaty["type"]:
			"tribute_receive":
				var gold: int = treaty["gold_per_turn"]
				ResourceManager.apply_delta(player_id, {"gold": gold})
				var fname: String = _get_faction_name(treaty["target"])
				EventBus.message_log.emit("[color=gold]%s朝贡: +%d金[/color]" % [fname, gold])
				EventBus.tribute_received.emit(player_id, treaty["target"], gold)
			"tribute_pay":
				var gold: int = treaty["gold_per_turn"]
				var current: int = ResourceManager.get_resource(player_id, "gold")
				var actual_pay: int = mini(gold, current)
				if actual_pay > 0:
					ResourceManager.apply_delta(player_id, {"gold": -actual_pay})
				var fname: String = _get_faction_name(treaty["target"])
				EventBus.message_log.emit("[color=yellow]向%s纳贡: -%d金[/color]" % [fname, actual_pay])
			"trade":
				ResourceManager.apply_delta(player_id, {
					"gold": BalanceConfig.TRADE_INCOME_SELF,
					"food": BalanceConfig.TRADE_FOOD_BONUS,
				})
				var fname: String = _get_faction_name(treaty["target"])
				EventBus.message_log.emit("[color=cyan]%s通商收入: +%d金 +%d粮[/color]" % [
					fname, BalanceConfig.TRADE_INCOME_SELF, BalanceConfig.TRADE_FOOD_BONUS])

		# Check expiration
		if treaty["turns_left"] <= 0:
			expired.append(treaty)

	# Notify expired treaties
	for treaty in expired:
		var fname: String = _get_faction_name(treaty["target"])
		var type_name: String = _get_treaty_type_name(treaty["type"])
		EventBus.message_log.emit("[color=gray]与%s的%s已到期[/color]" % [fname, type_name])
		EventBus.treaty_expired.emit(player_id, treaty["type"], treaty["target"])

	# Cleanup expired treaties
	var active: Array = []
	for treaty in treaties:
		if treaty["turns_left"] > 0:
			active.append(treaty)
	_treaties[player_id] = active


## ── Alliance Combat Bonus Query ──

func get_alliance_atk_bonus(player_id: int) -> float:
	## Returns total ATK bonus from military alliances.
	var bonus: float = 0.0
	for t in _get_player_treaties(player_id):
		if t["type"] == "alliance" and t["turns_left"] > 0:
			bonus += BalanceConfig.ALLIANCE_EVIL_ATK_BONUS
	return bonus


func get_alliance_def_bonus(player_id: int) -> float:
	## Returns total DEF bonus from military alliances.
	var bonus: float = 0.0
	for t in _get_player_treaties(player_id):
		if t["type"] == "alliance" and t["turns_left"] > 0:
			bonus += BalanceConfig.ALLIANCE_EVIL_DEF_BONUS
	return bonus


## ── Treaty Info Queries ──

func get_active_treaties(player_id: int) -> Array:
	## Returns list of all active treaties for display.
	var result: Array = []
	for t in _get_player_treaties(player_id):
		if t["turns_left"] > 0:
			result.append(t.duplicate())
	return result


func get_treaty_count(player_id: int) -> int:
	## Returns the number of active treaties for a player.
	var count: int = 0
	for t in _get_player_treaties(player_id):
		if t["turns_left"] > 0:
			count += 1
	return count


func cleanup_faction_treaties(faction_id: int) -> void:
	## Remove all treaties involving the eliminated faction across all players.
	for player_id in _treaties:
		var active: Array = []
		for treaty in _treaties[player_id]:
			if treaty["target"] == faction_id:
				var fname: String = _get_faction_name(faction_id)
				var type_name: String = _get_treaty_type_name(treaty["type"])
				EventBus.message_log.emit("[color=gray]%s已灭亡, 与其的%s自动终止[/color]" % [fname, type_name])
			else:
				active.append(treaty)
		_treaties[player_id] = active
	# Also clean up ceasefire entries
	for player_id in _ceasefire:
		if _ceasefire[player_id].has(faction_id):
			_ceasefire[player_id].erase(faction_id)
	# Clean up relations
	for player_id in _relations:
		if _relations[player_id].has(faction_id):
			_relations[player_id].erase(faction_id)


func _get_treaty_type_name(treaty_type: String) -> String:
	match treaty_type:
		"tribute_receive": return "朝贡(收取)"
		"tribute_pay": return "朝贡(缴纳)"
		"nap": return "互不侵犯条约"
		"alliance": return "军事同盟"
		"trade": return "通商协定"
	return treaty_type


func _count_faction_tiles(faction_id: int) -> int:
	## Count tiles originally belonging to an evil faction (not captured by player).
	var count: int = 0
	for tile in GameManager.tiles:
		# BUG FIX R18: null check + .get() for owner_id
		if tile == null:
			continue
		if tile.get("original_faction", -1) == faction_id and tile.get("owner_id", -1) < 0:
			count += 1
	return count


# ═══════════════ LIGHT FACTION DIPLOMACY (v3.4) ═══════════════

func buy_light_ceasefire(player_id: int) -> bool:
	## Pay gold to stop light faction expeditions for N turns.
	var threat: int = ThreatManager.get_threat()
	if threat > BalanceConfig.LIGHT_CEASEFIRE_MAX_THREAT:
		EventBus.message_log.emit("[color=red]威胁值过高(%d), 光明阵营拒绝停战![/color]" % threat)
		return false
	if _light_ceasefire_turns > 0:
		EventBus.message_log.emit("[color=yellow]停战协议仍在生效中(%d回合)[/color]" % _light_ceasefire_turns)
		return false
	var cost: int = BalanceConfig.LIGHT_CEASEFIRE_BASE_COST + threat * BalanceConfig.LIGHT_CEASEFIRE_PER_THREAT
	if not ResourceManager.can_afford(player_id, {"gold": cost}):
		EventBus.message_log.emit("[color=red]金币不足! 停战需要%d金[/color]" % cost)
		return false
	ResourceManager.spend(player_id, {"gold": cost})
	_light_ceasefire_turns = BalanceConfig.LIGHT_CEASEFIRE_DURATION
	ThreatManager.change_threat(-BalanceConfig.LIGHT_CEASEFIRE_THREAT_REDUCTION)
	EventBus.message_log.emit("[color=cyan]与光明阵营达成停战! -%d金 威胁-%d 持续%d回合[/color]" % [
		cost, BalanceConfig.LIGHT_CEASEFIRE_THREAT_REDUCTION, BalanceConfig.LIGHT_CEASEFIRE_DURATION])
	return true


func extort_light(player_id: int) -> bool:
	## Use high threat to extort gold from light faction.
	var threat: int = ThreatManager.get_threat()
	if threat < BalanceConfig.LIGHT_EXTORT_MIN_THREAT:
		EventBus.message_log.emit("[color=red]威胁值不足(%d/%d), 无法勒索光明阵营[/color]" % [
			threat, BalanceConfig.LIGHT_EXTORT_MIN_THREAT])
		return false
	if _light_extort_cooldown > 0:
		EventBus.message_log.emit("[color=yellow]勒索冷却中(%d回合)[/color]" % _light_extort_cooldown)
		return false
	var gold: int = BalanceConfig.LIGHT_EXTORT_GOLD_BASE + threat * BalanceConfig.LIGHT_EXTORT_GOLD_PER_THREAT
	ResourceManager.apply_delta(player_id, {"gold": gold})
	ThreatManager.change_threat(BalanceConfig.LIGHT_EXTORT_THREAT_COST)
	_light_extort_cooldown = BalanceConfig.LIGHT_EXTORT_COOLDOWN
	EventBus.message_log.emit("[color=gold]勒索光明阵营成功! +%d金 威胁%d[/color]" % [
		gold, BalanceConfig.LIGHT_EXTORT_THREAT_COST])
	EventBus.light_extorted.emit(player_id, gold)
	return true


func accept_light_peace() -> bool:
	## Accept a pending peace offer from light faction.
	if not _pending_light_peace.get("active", false):
		return false
	var pid: int = GameManager.get_human_player_id()
	var gold: int = _pending_light_peace.get("gold", 0)
	ResourceManager.apply_delta(pid, {"gold": gold})
	_light_ceasefire_turns = BalanceConfig.LIGHT_CEASEFIRE_DURATION
	_pending_light_peace = {}
	EventBus.message_log.emit("[color=lime]接受光明阵营求和! +%d金 停战%d回合[/color]" % [
		gold, BalanceConfig.LIGHT_CEASEFIRE_DURATION])
	return true


func reject_light_peace() -> void:
	## Reject light peace offer, gain threat.
	_pending_light_peace = {}
	ThreatManager.change_threat(5)
	EventBus.message_log.emit("[color=red]拒绝光明阵营求和! 威胁+5[/color]")


func is_light_ceasefire_active() -> bool:
	return _light_ceasefire_turns > 0


func get_light_ceasefire_turns() -> int:
	return _light_ceasefire_turns


func has_pending_light_peace() -> bool:
	return _pending_light_peace.get("active", false)


func get_pending_light_peace() -> Dictionary:
	return _pending_light_peace


func tick_light_diplomacy() -> void:
	## Called each turn. Tick light ceasefire timer, check for peace offers.
	if _light_ceasefire_turns > 0:
		_light_ceasefire_turns -= 1
		if _light_ceasefire_turns <= 0:
			EventBus.message_log.emit("[color=red]与光明阵营的停战已到期![/color]")

	if _light_extort_cooldown > 0:
		_light_extort_cooldown -= 1

	# Light peace offer: only when threat is low and no ceasefire active
	if _light_ceasefire_turns <= 0 and not _pending_light_peace.get("active", false):
		var threat: int = ThreatManager.get_threat()
		if threat <= BalanceConfig.LIGHT_PEACE_OFFER_THRESHOLD:
			if randi() % 100 < BalanceConfig.LIGHT_PEACE_OFFER_CHANCE:
				_pending_light_peace = {
					"active": true,
					"gold": BalanceConfig.LIGHT_PEACE_OFFER_GOLD,
				}
				EventBus.message_log.emit("[color=cyan]光明阵营派来使者, 提出停战并支付%d金![/color]" % BalanceConfig.LIGHT_PEACE_OFFER_GOLD)
				EventBus.light_peace_offered.emit(BalanceConfig.LIGHT_PEACE_OFFER_GOLD)

# ═══════════════ DIPLOMACY UI ACTIONS ═══════════════

func get_available_actions(player_id: int, faction_id: int) -> Array:
	## Returns list of available diplomatic actions for UI display (evil factions)
	var actions: Array = []
	var rel = _relations.get(player_id, {}).get(faction_id, {})
	var recruited: bool = rel.get("recruited", false)
	if recruited:
		return actions

	if is_orc_player(player_id):
		# Orc: war/ceasefire + tribute
		if rel.get("hostile", false) and not is_ceasefire_active(player_id, faction_id):
			actions.append({"id": "ceasefire", "name": "停战协议", "cost": "100金", "desc": "贡品换取5回合和平"})
			actions.append({"id": "offer_tribute", "name": "纳贡求和", "cost": "%d威望" % BalanceConfig.TRIBUTE_OFFER_PRESTIGE_COST,
				"desc": "每回合缴纳%d金换取和平" % BalanceConfig.TRIBUTE_GOLD_PER_TURN_BASE})
		elif not rel.get("hostile", false):
			actions.append({"id": "declare_war", "name": "宣战", "cost": "无", "desc": "兽人只懂征服!"})
		# Tribute demand (orc can demand from anyone they're not hostile with)
		var tribute_check = can_demand_tribute(player_id, faction_id)
		if tribute_check["possible"]:
			actions.append({"id": "demand_tribute", "name": "索取朝贡", "cost": "无",
				"desc": "强制朝贡 %d金/回合" % tribute_check["gold_per_turn"]})
		return actions

	# Non-orc: full diplomacy options
	var check = can_diplomacy(player_id, faction_id)
	if check["possible"]:
		actions.append({"id": "recruit_diplomacy", "name": "外交收编", "cost": "威望+金币", "desc": "和平收编该势力"})

	# Treaty options (non-orc)
	if not rel.get("hostile", false):
		# Trade
		var trade_check = can_sign_trade(player_id, faction_id)
		if trade_check["possible"]:
			actions.append({"id": "trade", "name": "通商协定", "cost": "%d金" % BalanceConfig.TRADE_COST_GOLD,
				"desc": "+%d金+%d粮/回合 持续%dT" % [BalanceConfig.TRADE_INCOME_SELF, BalanceConfig.TRADE_FOOD_BONUS, BalanceConfig.TRADE_DURATION]})
		# NAP
		var nap_check = can_sign_nap(player_id, faction_id)
		if nap_check["possible"]:
			actions.append({"id": "nap", "name": "互不侵犯", "cost": "%d金+%d威望" % [BalanceConfig.NAP_COST_GOLD, BalanceConfig.NAP_COST_PRESTIGE],
				"desc": "持续%d回合" % BalanceConfig.NAP_DURATION})
		# Alliance (requires NAP)
		var alliance_check = can_sign_alliance(player_id, faction_id)
		if alliance_check["possible"]:
			actions.append({"id": "alliance", "name": "军事同盟", "cost": "%d金+%d威望" % [BalanceConfig.ALLIANCE_EVIL_COST_GOLD, BalanceConfig.ALLIANCE_EVIL_COST_PRESTIGE],
				"desc": "ATK+%d%% DEF+%d%% 持续%dT" % [int(BalanceConfig.ALLIANCE_EVIL_ATK_BONUS * 100), int(BalanceConfig.ALLIANCE_EVIL_DEF_BONUS * 100), BalanceConfig.ALLIANCE_EVIL_DURATION]})
		# Tribute demand
		var tribute_check = can_demand_tribute(player_id, faction_id)
		if tribute_check["possible"]:
			actions.append({"id": "demand_tribute", "name": "索取朝贡", "cost": "无",
				"desc": "强制朝贡 %d金/回合" % tribute_check["gold_per_turn"]})
	else:
		# Hostile: can offer tribute to make peace
		if not has_treaty(player_id, "tribute_pay", faction_id):
			actions.append({"id": "offer_tribute", "name": "纳贡求和", "cost": "%d威望" % BalanceConfig.TRIBUTE_OFFER_PRESTIGE_COST,
				"desc": "每回合缴纳%d金换取和平" % BalanceConfig.TRIBUTE_GOLD_PER_TURN_BASE})
	return actions


func get_light_actions(player_id: int) -> Array:
	## Returns available actions for light faction diplomacy.
	var actions: Array = []
	var threat: int = ThreatManager.get_threat()

	# Light ceasefire (buy peace)
	if not is_light_ceasefire_active():
		var cost: int = BalanceConfig.LIGHT_CEASEFIRE_BASE_COST + threat * BalanceConfig.LIGHT_CEASEFIRE_PER_THREAT
		if threat <= BalanceConfig.LIGHT_CEASEFIRE_MAX_THREAT:
			actions.append({"id": "light_ceasefire", "name": "停战交涉", "cost": "%d金" % cost,
				"desc": "停止远征%d回合 威胁-%d" % [BalanceConfig.LIGHT_CEASEFIRE_DURATION, BalanceConfig.LIGHT_CEASEFIRE_THREAT_REDUCTION]})

	# Extort light
	if threat >= BalanceConfig.LIGHT_EXTORT_MIN_THREAT and _light_extort_cooldown <= 0:
		var gold: int = BalanceConfig.LIGHT_EXTORT_GOLD_BASE + threat * BalanceConfig.LIGHT_EXTORT_GOLD_PER_THREAT
		actions.append({"id": "light_extort", "name": "勒索光明", "cost": "威胁%d" % BalanceConfig.LIGHT_EXTORT_THREAT_COST,
			"desc": "获得%d金(冷却%dT)" % [gold, BalanceConfig.LIGHT_EXTORT_COOLDOWN]})

	# Accept/reject peace offer
	if has_pending_light_peace():
		var peace: Dictionary = get_pending_light_peace()
		actions.append({"id": "accept_peace", "name": "接受求和", "cost": "无",
			"desc": "+%d金 停战%dT" % [peace["gold"], BalanceConfig.LIGHT_CEASEFIRE_DURATION]})
		actions.append({"id": "reject_peace", "name": "拒绝求和", "cost": "威胁+5",
			"desc": "继续战争, 展示实力"})

	return actions


# ═══════════════ SR07 DYNAMIC DIPLOMATIC EVENTS ═══════════════

func process_diplomatic_events(player_id: int) -> void:
	## Called each turn. Rolls for random diplomatic events per eligible faction.
	## Events are queued via EventBus.diplomatic_event_triggered for the HUD to display.
	_tick_event_cooldowns()

	var faction_keys: Array = ["orc_ai", "pirate_ai", "dark_elf_ai"]
	var faction_ids: Array = [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]

	# Per-faction events
	for i in range(faction_keys.size()):
		var fkey: String = faction_keys[i]
		var fid: int = faction_ids[i]
		# Skip player's own faction
		if fid == GameManager.get_player_faction(player_id):
			continue
		# Skip factions with no territory
		if _count_faction_tiles(fid) <= 0:
			continue

		var rep: int = get_reputation(fkey)

		# --- Betrayal: rep < -30 and has any treaty ---
		if rep < -30 and not _is_event_on_cooldown(DIPLO_EVT_BETRAYAL):
			if _roll_event_chance() and _has_any_treaty(player_id, fid):
				event_betrayal(player_id, fid)
				continue  # Max one event per faction per turn

		# --- Border Incident: always eligible ---
		if not _is_event_on_cooldown(DIPLO_EVT_BORDER_INCIDENT):
			if _roll_event_chance():
				event_border_incident(player_id, fid)
				continue

		# --- Trade Opportunity: rep > 20 ---
		if rep > 20 and not _is_event_on_cooldown(DIPLO_EVT_TRADE_OPPORTUNITY):
			if _roll_event_chance():
				event_trade_opportunity(player_id, fid)
				continue

		# --- Alliance Proposal: rep > 50, no existing alliance ---
		if rep > 50 and not _is_event_on_cooldown(DIPLO_EVT_ALLIANCE_PROPOSAL):
			if not has_treaty(player_id, "alliance", fid) and _roll_event_chance():
				event_alliance_proposal(player_id, fid)
				continue

	# Global events (not per-faction)
	if not _is_event_on_cooldown(DIPLO_EVT_REFUGEE_CRISIS):
		if _roll_event_chance():
			event_refugee_crisis(player_id)


func _roll_event_chance() -> bool:
	var threshold: float = randf_range(DIPLO_EVT_CHANCE_MIN, DIPLO_EVT_CHANCE_MAX)
	return randf() < threshold


func _is_event_on_cooldown(event_type: String) -> bool:
	return _event_cooldowns.get(event_type, 0) > 0


func _set_event_cooldown(event_type: String) -> void:
	_event_cooldowns[event_type] = DIPLO_EVT_COOLDOWN_TURNS


func _tick_event_cooldowns() -> void:
	for key in _event_cooldowns.keys():
		_event_cooldowns[key] -= 1
		if _event_cooldowns[key] <= 0:
			_event_cooldowns.erase(key)


func _next_diplo_event_id() -> String:
	_diplo_event_counter += 1
	return "diplo_%d" % _diplo_event_counter


func _has_any_treaty(player_id: int, faction_id: int) -> bool:
	for t in _get_player_treaties(player_id):
		if t["target"] == faction_id and t["turns_left"] > 0:
			return true
	if is_ceasefire_active(player_id, faction_id):
		return true
	return false


## ── Event: Border Incident ──

func event_border_incident(player_id: int, faction_id: int) -> void:
	_set_event_cooldown(DIPLO_EVT_BORDER_INCIDENT)
	var fname: String = _get_faction_name(faction_id)
	var fkey: String = _faction_to_ai_key(faction_id)
	var eid: String = _next_diplo_event_id()
	var event_data: Dictionary = {
		"type": DIPLO_EVT_BORDER_INCIDENT,
		"faction_id": faction_id,
		"event_id": eid,
		"title": "边境冲突",
		"description": "[color=red]%s[/color]的巡逻队在边境与你的守军发生了小规模冲突。\n损失了少量部队，双方关系恶化。" % fname,
		"choices": [
			{"text": "派兵还击 (声望+5, 关系再-5)", "callback": "border_incident_retaliate"},
			{"text": "忍气吞声 (仅承受损失)", "callback": "border_incident_ignore"},
		],
	}
	# Immediate effect: -10 rep, small troop loss
	change_reputation(fkey, -10)
	var army: int = ResourceManager.get_resource(player_id, "soldiers")
	var loss: int = mini(clampi(army / 20, 5, 30), army)
	ResourceManager.apply_delta(player_id, {"soldiers": -loss})
	EventBus.message_log.emit("[color=red]边境冲突: 损失%d名士兵, %s声望-10[/color]" % [loss, fname])
	EventBus.diplomatic_event_triggered.emit(event_data)


func resolve_border_incident(player_id: int, faction_id: int, choice: String) -> void:
	var fkey: String = _faction_to_ai_key(faction_id)
	if choice == "border_incident_retaliate":
		ResourceManager.apply_delta(player_id, {"prestige": 5})
		change_reputation(fkey, -5)
		EventBus.message_log.emit("[color=yellow]你选择还击! 威望+5, %s声望再-5[/color]" % _get_faction_name(faction_id))
	else:
		EventBus.message_log.emit("[color=gray]你选择忍耐，边境冲突事件结束。[/color]")


## ── Event: Trade Opportunity ──

func event_trade_opportunity(player_id: int, faction_id: int) -> void:
	_set_event_cooldown(DIPLO_EVT_TRADE_OPPORTUNITY)
	var fname: String = _get_faction_name(faction_id)
	var eid: String = _next_diplo_event_id()
	var event_data: Dictionary = {
		"type": DIPLO_EVT_TRADE_OPPORTUNITY,
		"faction_id": faction_id,
		"event_id": eid,
		"title": "贸易商机",
		"description": "[color=cyan]%s[/color]的商队带来了一批稀有货物，提议进行一次特别交易。\n如果接受，将获得[color=gold]50金币[/color]的额外利润。" % fname,
		"choices": [
			{"text": "接受交易 (+50金, 关系+5)", "callback": "trade_opportunity_accept"},
			{"text": "婉拒 (无变化)", "callback": "trade_opportunity_reject"},
		],
	}
	EventBus.diplomatic_event_triggered.emit(event_data)


func resolve_trade_opportunity(player_id: int, faction_id: int, choice: String) -> void:
	var fkey: String = _faction_to_ai_key(faction_id)
	if choice == "trade_opportunity_accept":
		ResourceManager.apply_delta(player_id, {"gold": 50})
		change_reputation(fkey, 5)
		EventBus.message_log.emit("[color=gold]贸易成功! +50金, %s声望+5[/color]" % _get_faction_name(faction_id))
	else:
		EventBus.message_log.emit("[color=gray]你婉拒了%s的贸易提议。[/color]" % _get_faction_name(faction_id))


## ── Event: Alliance Proposal ──

func event_alliance_proposal(player_id: int, faction_id: int) -> void:
	_set_event_cooldown(DIPLO_EVT_ALLIANCE_PROPOSAL)
	var fname: String = _get_faction_name(faction_id)
	var eid: String = _next_diplo_event_id()
	var event_data: Dictionary = {
		"type": DIPLO_EVT_ALLIANCE_PROPOSAL,
		"faction_id": faction_id,
		"event_id": eid,
		"title": "同盟提议",
		"description": "[color=green]%s[/color]派遣使节，提议缔结军事同盟。\n同盟将带来战斗加成和外交收益。" % fname,
		"choices": [
			{"text": "接受同盟 (缔结同盟, 关系+10)", "callback": "alliance_proposal_accept"},
			{"text": "拒绝提议 (关系-10)", "callback": "alliance_proposal_reject"},
		],
	}
	EventBus.diplomatic_event_triggered.emit(event_data)


func resolve_alliance_proposal(player_id: int, faction_id: int, choice: String) -> void:
	var fkey: String = _faction_to_ai_key(faction_id)
	if choice == "alliance_proposal_accept":
		sign_alliance(player_id, faction_id)
		change_reputation(fkey, 10)
		EventBus.message_log.emit("[color=green]你与%s缔结了军事同盟! 声望+10[/color]" % _get_faction_name(faction_id))
	else:
		change_reputation(fkey, -10)
		EventBus.message_log.emit("[color=yellow]你拒绝了%s的同盟提议, 声望-10[/color]" % _get_faction_name(faction_id))


## ── Event: Betrayal ──

func event_betrayal(player_id: int, faction_id: int) -> void:
	_set_event_cooldown(DIPLO_EVT_BETRAYAL)
	var fname: String = _get_faction_name(faction_id)
	var eid: String = _next_diplo_event_id()
	# Find an existing treaty to break
	var broken_type: String = ""
	for t in _get_player_treaties(player_id):
		if t["target"] == faction_id and t["turns_left"] > 0:
			broken_type = t["type"]
			break
	if broken_type == "":
		# Ceasefire break
		if is_ceasefire_active(player_id, faction_id):
			broken_type = "ceasefire"
		else:
			return  # Nothing to betray

	var type_label: String = _get_treaty_type_name(broken_type) if broken_type != "ceasefire" else "停战协议"
	var event_data: Dictionary = {
		"type": DIPLO_EVT_BETRAYAL,
		"faction_id": faction_id,
		"event_id": eid,
		"title": "背叛!",
		"description": "[color=red]%s[/color]撕毁了与你的[color=yellow]%s[/color]!\n对方关系已经恶化到极点，条约不复存在。" % [fname, type_label],
		"choices": [
			{"text": "宣战报复 (进入敌对)", "callback": "betrayal_war"},
			{"text": "保持克制 (声望+5)", "callback": "betrayal_restrain"},
		],
		"_broken_treaty_type": broken_type,
	}
	# Immediately break the treaty from the AI side
	if broken_type == "ceasefire":
		if _ceasefire.has(player_id) and _ceasefire[player_id].has(faction_id):
			_ceasefire[player_id][faction_id] = 0
	else:
		# Remove the treaty directly
		var treaties: Array = _get_player_treaties(player_id)
		for t in treaties:
			if t["target"] == faction_id and t["type"] == broken_type and t["turns_left"] > 0:
				t["turns_left"] = 0
				EventBus.treaty_broken.emit(player_id, broken_type, faction_id)
				break

	EventBus.message_log.emit("[color=red]%s背叛了你! 撕毁%s![/color]" % [fname, type_label])
	EventBus.diplomatic_event_triggered.emit(event_data)


func resolve_betrayal(player_id: int, faction_id: int, choice: String) -> void:
	var fkey: String = _faction_to_ai_key(faction_id)
	if choice == "betrayal_war":
		mark_hostile(player_id, faction_id)
		EventBus.message_log.emit("[color=red]你向%s宣战![/color]" % _get_faction_name(faction_id))
	else:
		ResourceManager.apply_delta(player_id, {"prestige": 5})
		EventBus.message_log.emit("[color=cyan]你保持克制, 威望+5[/color]")


## ── Event: Refugee Crisis ──

func event_refugee_crisis(player_id: int) -> void:
	_set_event_cooldown(DIPLO_EVT_REFUGEE_CRISIS)
	var eid: String = _next_diplo_event_id()
	var event_data: Dictionary = {
		"type": DIPLO_EVT_REFUGEE_CRISIS,
		"faction_id": -1,
		"event_id": eid,
		"title": "难民危机",
		"description": "一群因战乱流离失所的难民来到你的领地请求庇护。\n[color=green]接纳[/color]: 秩序+5, 但需消耗[color=yellow]30粮食[/color]\n[color=red]拒绝[/color]: 秩序-5, 无额外消耗",
		"choices": [
			{"text": "接纳难民 (秩序+5, 粮食-30)", "callback": "refugee_accept"},
			{"text": "拒绝入境 (秩序-5)", "callback": "refugee_reject"},
		],
	}
	EventBus.diplomatic_event_triggered.emit(event_data)


func resolve_refugee_crisis(player_id: int, choice: String) -> void:
	if choice == "refugee_accept":
		var food: int = ResourceManager.get_resource(player_id, "food")
		var cost: int = mini(30, food)
		ResourceManager.apply_delta(player_id, {"food": -cost})
		OrderManager.change_order(5)
		EventBus.message_log.emit("[color=green]你接纳了难民! 秩序+5, 粮食-%d[/color]" % cost)
	else:
		OrderManager.change_order(-5)
		EventBus.message_log.emit("[color=red]你拒绝了难民, 秩序-5[/color]")


## ── Event Resolution Dispatcher ──

func resolve_diplomatic_event(event_data: Dictionary, choice_index: int) -> void:
	## Called by UI when player makes a choice on a diplomatic event.
	var player_id: int = GameManager.get_human_player_id()
	var faction_id: int = event_data.get("faction_id", -1)
	var choices: Array = event_data.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var callback: String = choices[choice_index].get("callback", "")
	EventBus.diplomatic_event_resolved.emit(event_data.get("event_id", ""), choice_index)

	match event_data.get("type", ""):
		DIPLO_EVT_BORDER_INCIDENT:
			resolve_border_incident(player_id, faction_id, callback)
		DIPLO_EVT_TRADE_OPPORTUNITY:
			resolve_trade_opportunity(player_id, faction_id, callback)
		DIPLO_EVT_ALLIANCE_PROPOSAL:
			resolve_alliance_proposal(player_id, faction_id, callback)
		DIPLO_EVT_BETRAYAL:
			resolve_betrayal(player_id, faction_id, callback)
		DIPLO_EVT_REFUGEE_CRISIS:
			resolve_refugee_crisis(player_id, callback)


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"relations": _relations.duplicate(true),
		"ceasefire": _ceasefire.duplicate(true),
		"treaties": _treaties.duplicate(true),
		"light_ceasefire_turns": _light_ceasefire_turns,
		"light_extort_cooldown": _light_extort_cooldown,
		"pending_light_peace": _pending_light_peace.duplicate(true),
		"reputation": _reputation.duplicate(),
		"treaty_breaks_total": _treaty_breaks_total,
		"event_cooldowns": _event_cooldowns.duplicate(),
		"diplo_event_counter": _diplo_event_counter,
	}


static func _fix_int_keys(dict: Dictionary) -> void:
	var fix_keys = []
	for k in dict.keys():
		if k is String and k.is_valid_int():
			fix_keys.append(k)
	for k in fix_keys:
		dict[int(k)] = dict[k]
		dict.erase(k)


func from_save_data(data: Dictionary) -> void:
	_relations = data.get("relations", {}).duplicate(true)
	_fix_int_keys(_relations)
	# Fix nested dicts inside _relations (faction_id int keys)
	for pid in _relations:
		if _relations[pid] is Dictionary:
			_fix_int_keys(_relations[pid])
	_ceasefire = data.get("ceasefire", {}).duplicate(true)
	_fix_int_keys(_ceasefire)
	# Fix nested dicts inside _ceasefire (target_faction_id int keys)
	for pid in _ceasefire:
		if _ceasefire[pid] is Dictionary:
			_fix_int_keys(_ceasefire[pid])
	_treaties = data.get("treaties", {}).duplicate(true)
	_fix_int_keys(_treaties)
	# Fix treaty int values after JSON round-trip
	for pid in _treaties:
		if _treaties[pid] is Array:
			for treaty in _treaties[pid]:
				if treaty is Dictionary:
					if treaty.has("target"):
						treaty["target"] = int(treaty["target"])
					if treaty.has("turns_left"):
						treaty["turns_left"] = int(treaty["turns_left"])
					if treaty.has("gold_per_turn"):
						treaty["gold_per_turn"] = int(treaty["gold_per_turn"])
	# Fix ceasefire int values after JSON round-trip
	for pid in _ceasefire:
		if _ceasefire[pid] is Dictionary:
			for fid in _ceasefire[pid]:
				_ceasefire[pid][fid] = int(_ceasefire[pid][fid])
	# Fix relations rebellion_turns after JSON round-trip
	for pid in _relations:
		if _relations[pid] is Dictionary:
			for fid in _relations[pid]:
				var rel = _relations[pid][fid]
				if rel is Dictionary and rel.has("rebellion_turns"):
					rel["rebellion_turns"] = int(rel["rebellion_turns"])
	_light_ceasefire_turns = int(data.get("light_ceasefire_turns", 0))
	_light_extort_cooldown = int(data.get("light_extort_cooldown", 0))
	_pending_light_peace = data.get("pending_light_peace", {}).duplicate(true)
	_reputation = data.get("reputation", {}).duplicate()
	_treaty_breaks_total = int(data.get("treaty_breaks_total", 0))
	# Fix reputation int values after JSON round-trip
	for key in _reputation:
		_reputation[key] = int(_reputation[key])
	# SR07 diplomatic events
	_event_cooldowns = data.get("event_cooldowns", {}).duplicate()
	for key in _event_cooldowns:
		_event_cooldowns[key] = int(_event_cooldowns[key])
	_diplo_event_counter = int(data.get("diplo_event_counter", 0))
