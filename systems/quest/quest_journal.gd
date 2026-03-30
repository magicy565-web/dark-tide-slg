## quest_journal.gd — 统一任务日志管理器 (v2.4)
## Autoload singleton. Tracks all quest types: main, side, challenge, character.
## Wraps existing systems (QuestManager for neutral, EventSystem for events).
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")
const QuestDefs = preload("res://systems/quest/quest_definitions.gd")
const ChallengeData = preload("res://systems/quest/challenge_quest_data.gd")
const SideQuestData = preload("res://systems/quest/side_quest_data.gd")

# ═══════════════ STATE ═══════════════

# quest_id → { status, progress_snapshot, completed_at_turn }
var _main_progress: Dictionary = {}
var _side_progress: Dictionary = {}
var _challenge_progress: Dictionary = {}  # "faction_step" key, e.g. "orc_c1"
var _character_progress: Dictionary = {}  # "hero_id_step" key, e.g. "rin_cq1"

# Unlocked traits and titles
var _unlocked_traits: Array = []  # trait_id strings
var _unlocked_titles: Array = []  # title strings
var _active_title: String = ""

# Cumulative stat counters (for trigger checks)
var _stats: Dictionary = {
	"battles_won": 0,
	"heroes_captured_total": 0,
	"waaagh_battle_wins": 0,
	"expeditions_defended": 0,
	"tiles_captured_log": [],  # [{turn, count}] for time-window checks
	"total_kills": 0,
	"ap_purchased": 0,
	"tiles_not_lost_streak": 0,
	"tiles_lost_this_turn": false,
}

var _initialized: bool = false


func _ready() -> void:
	# Connect to game events for automatic stat tracking
	if EventBus.has_signal("combat_result"):
		EventBus.combat_result.connect(_on_combat_result)
	if EventBus.has_signal("tile_captured"):
		EventBus.tile_captured.connect(_on_tile_captured)
	if EventBus.has_signal("hero_captured"):
		EventBus.hero_captured.connect(_on_hero_captured)
	if EventBus.has_signal("turn_started"):
		EventBus.turn_started.connect(_on_turn_started)
	if EventBus.has_signal("challenge_battle_resolved"):
		EventBus.challenge_battle_resolved.connect(_on_challenge_battle_resolved)
	if EventBus.has_signal("tile_lost"):
		EventBus.tile_lost.connect(_on_tile_lost)


# ═══════════════ INITIALIZATION ═══════════════

func init_journal(player_faction: int) -> void:
	## Call after game start to set up all quest entries.
	_main_progress.clear()
	_side_progress.clear()
	_challenge_progress.clear()
	_character_progress.clear()
	_unlocked_traits.clear()
	_unlocked_titles.clear()
	_active_title = ""
	_stats = {"battles_won": 0, "heroes_captured_total": 0,
		"waaagh_battle_wins": 0, "expeditions_defended": 0, "tiles_captured_log": [],
		"total_kills": 0, "ap_purchased": 0, "tiles_not_lost_streak": 0, "tiles_lost_this_turn": false}

	# Init main quests (first one starts as AVAILABLE)
	for i in range(QuestDefs.MAIN_QUESTS.size()):
		var q: Dictionary = QuestDefs.MAIN_QUESTS[i]
		var status: int = QuestDefs.QuestStatus.LOCKED
		if i == 0:
			status = QuestDefs.QuestStatus.ACTIVE
		_main_progress[q["id"]] = {"status": status, "completed_at": -1}

	# Init side quests (all start LOCKED, unlocked by triggers)
	for q in QuestDefs.SIDE_QUESTS:
		_side_progress[q["id"]] = {"status": QuestDefs.QuestStatus.LOCKED, "completed_at": -1}

	# Init expanded side quests (story/bonus/intel)
	for q in SideQuestData.STORY_QUESTS:
		_side_progress[q["id"]] = {"status": QuestDefs.QuestStatus.LOCKED, "completed_at": -1}
	for q in SideQuestData.BONUS_QUESTS:
		_side_progress[q["id"]] = {"status": QuestDefs.QuestStatus.LOCKED, "completed_at": -1}
	for q in SideQuestData.INTEL_QUESTS:
		_side_progress[q["id"]] = {"status": QuestDefs.QuestStatus.LOCKED, "completed_at": -1}

	# Init challenge quests (only for player's faction)
	if ChallengeData.CHALLENGES.has(player_faction):
		var chain: Array = ChallengeData.CHALLENGES[player_faction]
		for i in range(chain.size()):
			var c: Dictionary = chain[i]
			var status: int = QuestDefs.QuestStatus.LOCKED
			if i == 0:
				status = QuestDefs.QuestStatus.ACTIVE
			_challenge_progress[c["id"]] = {"status": status, "completed_at": -1}

	# Init character quests (all LOCKED, unlock by affection)
	for hero_id in QuestDefs.CHARACTER_QUESTS:
		var cq: Dictionary = QuestDefs.CHARACTER_QUESTS[hero_id]
		for step in cq["steps"]:
			_character_progress[step["id"]] = {"status": QuestDefs.QuestStatus.LOCKED, "completed_at": -1}

	_initialized = true
	EventBus.message_log.emit("[color=cyan]任务日志已初始化[/color]")


func reset() -> void:
	_main_progress.clear()
	_side_progress.clear()
	_challenge_progress.clear()
	_character_progress.clear()
	_unlocked_traits.clear()
	_unlocked_titles.clear()
	_active_title = ""
	_stats = {"battles_won": 0, "heroes_captured_total": 0,
		"waaagh_battle_wins": 0, "expeditions_defended": 0, "tiles_captured_log": [],
		"total_kills": 0, "ap_purchased": 0, "tiles_not_lost_streak": 0, "tiles_lost_this_turn": false}
	_initialized = false


# ═══════════════ PER-TURN TICK ═══════════════

func tick(player_id: int) -> void:
	## Called each turn from GameManager. Checks all quest triggers.
	if not _initialized:
		return
	# Update tiles_not_lost_streak
	if not _stats.get("tiles_lost_this_turn", false):
		_stats["tiles_not_lost_streak"] = _stats.get("tiles_not_lost_streak", 0) + 1
	else:
		_stats["tiles_not_lost_streak"] = 0
	_stats["tiles_lost_this_turn"] = false

	_check_main_quests(player_id)
	_check_side_quests(player_id)
	_check_challenge_quests(player_id)
	_check_character_quests(player_id)


# ═══════════════ TRIGGER EVALUATION ═══════════════

func _evaluate_objective(obj: Dictionary, player_id: int) -> bool:
	## Check if a single objective is met. Returns true if satisfied.
	var otype: String = obj.get("type", "")
	var value = obj.get("value", 0)
	match otype:
		"tiles_min":
			return _count_player_tiles(player_id) >= value
		"battles_won_min":
			return _stats["battles_won"] >= value
		"army_count_min":
			return GameManager.get_player_armies(player_id).size() >= value
		"building_any":
			return _count_player_buildings(player_id) >= value
		"buildings_min":
			return _count_player_buildings(player_id) >= value
		"gold_min":
			return ResourceManager.get_resource(player_id, "gold") >= value
		"food_min":
			return ResourceManager.get_resource(player_id, "food") >= value
		"iron_min":
			return ResourceManager.get_resource(player_id, "iron") >= value
		"heroes_min":
			return HeroSystem.recruited_heroes.size() >= value
		"neutral_recruited_min":
			return QuestManager.get_recruited_factions(player_id).size() >= value
		"threat_min":
			return ThreatManager.get_threat() >= value
		"order_min":
			return OrderManager.get_order() >= value
		"strongholds_min":
			return GameManager.count_strongholds_owned(player_id) >= value
		"all_strongholds":
			return GameManager.count_strongholds_owned(player_id) >= GameManager.get_total_strongholds()
		"harbor_min":
			return _count_tile_type(player_id, GameManager.TileType.HARBOR) >= value
		"slaves_min":
			return ResourceManager.get_resource(player_id, "slaves") >= value
		"shadow_essence_min":
			return ResourceManager.get_resource(player_id, "shadow_essence") >= value
		"waaagh_frenzy_triggered":
			return _stats["waaagh_battle_wins"] >= 1
		"waaagh_battle_win":
			return _stats["waaagh_battle_wins"] >= 1
		"heroes_captured_total":
			return _stats["heroes_captured_total"] >= value
		"defend_expedition":
			return _stats["expeditions_defended"] >= 1
		"tiles_gained_in_turns":
			return _check_tiles_in_window(obj.get("turns", 3), value)
		"total_kills_min":
			return _stats.get("total_kills", 0) >= value
		"tiles_not_lost_turns":
			return _stats.get("tiles_not_lost_streak", 0) >= value
		"ap_purchased_min":
			return _stats.get("ap_purchased", 0) >= value
		"hero_level_min":
			return _get_max_hero_level() >= value
		"relics_min":
			return (1 if RelicManager.has_relic(player_id) else 0) >= value
		"researches_min":
			return ResearchManager.get_completed_techs(player_id).size() >= value
		"public_order_all_min":
			return _all_tiles_public_order_min(player_id, value / 100.0)
		"fog_revealed_pct":
			return _get_fog_revealed_pct(player_id) >= value
		"watchtowers_min":
			return _count_tiles_with_building(player_id, "watchtower") >= value
		"treaties_signed_min":
			return DiplomacyManager.get_treaty_count(player_id) >= value
		"total_soldiers_min":
			return _get_total_soldiers(player_id) >= value
		"ruins_captured_min":
			return _count_tiles_with_terrain(player_id, "ruins") >= value
		"trading_posts_min":
			return _count_tiles_with_building(player_id, "trading_post") >= value
		"mines_captured_min":
			return _count_tiles_with_terrain(player_id, "mine") >= value
		"waaagh_min":
			if OrcMechanic and OrcMechanic.has_method("get_waaagh"):
				return OrcMechanic.get_waaagh(player_id) >= value
			return false
		"main_quest_completed":
			return _is_completed(_main_progress, str(value))
		"tiles_defended_min":
			return _stats.get("tiles_defended", 0) >= value
		"black_market_trades_min":
			return _stats.get("black_market_trades", 0) >= value
		"heroines_submission_min":
			var required_count: int = obj.get("count", 1)
			return _count_heroes_with_submission(player_id, value) >= required_count
		"heroines_captured_min":
			return _count_captured_heroines(player_id) >= value
		"building_level_max":
			return _any_building_level_at_least(player_id, value)
		"treasure_maps_min":
			return _stats.get("treasure_maps", 0) >= value
		"low_ap_turns_min":
			return _stats.get("low_ap_turns", 0) >= value
		"tiles_captured_in_turn_min":
			return _stats.get("tiles_captured_this_turn", 0) >= value
		"wanderer_kills_min":
			return _stats.get("wanderer_kills", 0) >= value
		"gold_spent_min":
			return _stats.get("gold_spent", 0) >= value
		"infamy_min":
			if PirateMechanic and PirateMechanic.has_method("get_infamy"):
				return PirateMechanic.get_infamy(player_id) >= value
			return false
		"turn_min":
			return GameManager.turn_number >= value
		_:
			push_warning("QuestJournal: _evaluate_objective unhandled type '%s'" % otype)
			return false


func _evaluate_trigger(trigger: Dictionary, player_id: int) -> bool:
	## Check if a quest's unlock trigger conditions are met.
	for key in trigger:
		match key:
			"main_quest_completed":
				if not _is_completed(_main_progress, trigger[key]):
					return false
			"tiles_min":
				if _count_player_tiles(player_id) < trigger[key]:
					return false
			"turn_min":
				if GameManager.turn_number < trigger[key]:
					return false
			"heroes_min":
				if HeroSystem.recruited_heroes.size() < trigger[key]:
					return false
			"battles_won_min":
				if _stats["battles_won"] < trigger[key]:
					return false
			"gold_min":
				if ResourceManager.get_resource(player_id, "gold") < trigger[key]:
					return false
			"threat_min":
				if ThreatManager.get_threat() < trigger[key]:
					return false
			"strongholds_min":
				if GameManager.count_strongholds_owned(player_id) < trigger[key]:
					return false
			"harbor_min":
				if _count_tile_type(player_id, GameManager.TileType.HARBOR) < trigger[key]:
					return false
			"neutral_recruited_min":
				if QuestManager.get_recruited_factions(player_id).size() < trigger[key]:
					return false
			"shadow_essence_min":
				if ResourceManager.get_resource(player_id, "shadow_essence") < trigger[key]:
					return false
			"waaagh_battle_win":
				if _stats["waaagh_battle_wins"] < 1:
					return false
			"heroes_captured_total":
				if _stats["heroes_captured_total"] < trigger[key]:
					return false
			"faction":
				if GameManager.get_player_faction(player_id) != trigger[key]:
					return false
			"total_kills_min":
				if _stats.get("total_kills", 0) < trigger[key]:
					return false
			"ap_purchased_min":
				if _stats.get("ap_purchased", 0) < trigger[key]:
					return false
			"hero_level_min":
				if _get_max_hero_level() < trigger[key]:
					return false
			"relics_min":
				if (1 if RelicManager.has_relic(player_id) else 0) < trigger[key]:
					return false
			"researches_min":
				if ResearchManager.get_completed_techs(player_id).size() < trigger[key]:
					return false
			"treaties_signed_min":
				if DiplomacyManager.get_treaty_count(player_id) < trigger[key]:
					return false
			"side_quest_completed":
				if not _is_completed(_side_progress, trigger[key]):
					return false
			"waaagh_min":
				if not (OrcMechanic and OrcMechanic.has_method("get_waaagh") and OrcMechanic.get_waaagh(player_id) >= trigger[key]):
					return false
			"ruins_captured_min":
				if _count_tiles_with_terrain(player_id, "ruins") < trigger[key]:
					return false
			"trading_posts_min":
				if _count_tiles_with_building(player_id, "trading_post") < trigger[key]:
					return false
			"mines_captured_min":
				if _count_tiles_with_terrain(player_id, "mine") < trigger[key]:
					return false
			"heroines_captured_min":
				if _count_captured_heroines(player_id) < trigger[key]:
					return false
			_:
				push_warning("QuestJournal: _evaluate_trigger unhandled key '%s'" % key)
				return false
	return true


# ═══════════════ QUEST TYPE CHECKERS ═══════════════

func _check_main_quests(player_id: int) -> void:
	for i in range(QuestDefs.MAIN_QUESTS.size()):
		var q: Dictionary = QuestDefs.MAIN_QUESTS[i]
		var state: Dictionary = _main_progress.get(q["id"], {})
		if state.get("status", -1) == QuestDefs.QuestStatus.LOCKED:
			# Check if trigger is met to unlock
			if _evaluate_trigger(q.get("trigger", {}), player_id):
				_main_progress[q["id"]]["status"] = QuestDefs.QuestStatus.ACTIVE
				_notify_quest_available("主线", q["name"])
		elif state.get("status", -1) == QuestDefs.QuestStatus.ACTIVE:
			# Check if all objectives are complete
			var all_done: bool = true
			for obj in q.get("objectives", []):
				if not _evaluate_objective(obj, player_id):
					all_done = false
					break
			if all_done:
				_complete_quest_entry(_main_progress, q["id"], q.get("reward", {}), player_id, "主线", q["name"])
				EventBus.main_quest_completed.emit(q["id"])


func _check_side_quests(player_id: int) -> void:
	for q in QuestDefs.SIDE_QUESTS:
		var state: Dictionary = _side_progress.get(q["id"], {})
		if state.get("status", -1) == QuestDefs.QuestStatus.LOCKED:
			if _evaluate_trigger(q.get("trigger", {}), player_id):
				_side_progress[q["id"]]["status"] = QuestDefs.QuestStatus.ACTIVE
				_notify_quest_available("支线", q["name"])
		elif state.get("status", -1) == QuestDefs.QuestStatus.ACTIVE:
			var all_done: bool = true
			for obj in q.get("objectives", []):
				if not _evaluate_objective(obj, player_id):
					all_done = false
					break
			if all_done:
				_complete_quest_entry(_side_progress, q["id"], q.get("reward", {}), player_id, "支线", q["name"])

	# Check expanded side quests (story/bonus/intel)
	for q in SideQuestData.STORY_QUESTS + SideQuestData.BONUS_QUESTS + SideQuestData.INTEL_QUESTS:
		var state: Dictionary = _side_progress.get(q["id"], {})
		if state.get("status", -1) == QuestDefs.QuestStatus.LOCKED:
			if _evaluate_trigger(q.get("trigger", {}), player_id):
				_side_progress[q["id"]]["status"] = QuestDefs.QuestStatus.ACTIVE
				_notify_quest_available("支线", q["name"])
		elif state.get("status", -1) == QuestDefs.QuestStatus.ACTIVE:
			var all_done: bool = true
			for obj in q.get("objectives", []):
				if not _evaluate_objective(obj, player_id):
					all_done = false
					break
			if all_done:
				_complete_quest_entry(_side_progress, q["id"], q.get("reward", {}), player_id, "支线", q["name"])


func _check_challenge_quests(player_id: int) -> void:
	var faction_id: int = GameManager.get_player_faction(player_id)
	if not ChallengeData.CHALLENGES.has(faction_id):
		return
	var chain: Array = ChallengeData.CHALLENGES[faction_id]
	for i in range(chain.size()):
		var c: Dictionary = chain[i]
		var state: Dictionary = _challenge_progress.get(c["id"], {})
		if state.get("status", -1) == QuestDefs.QuestStatus.LOCKED:
			# Unlock next in chain if previous is completed
			if i == 0 or _is_completed(_challenge_progress, chain[i - 1]["id"]):
				if _evaluate_trigger(c.get("trigger", {}), player_id):
					_challenge_progress[c["id"]]["status"] = QuestDefs.QuestStatus.ACTIVE
					_notify_quest_available("挑战", c["name"])
		elif state.get("status", -1) == QuestDefs.QuestStatus.ACTIVE:
			# Challenge quests with battles need explicit completion via complete_challenge_battle()
			if c.get("battle") != null:
				continue  # Must be resolved through combat flow
			# Non-battle challenges auto-complete when trigger is met
			if _evaluate_trigger(c.get("trigger", {}), player_id):
				_complete_challenge(c, player_id)


func _check_character_quests(player_id: int) -> void:
	for hero_id in QuestDefs.CHARACTER_QUESTS:
		# Hero must be recruited
		if hero_id not in HeroSystem.recruited_heroes:
			continue
		var cq: Dictionary = QuestDefs.CHARACTER_QUESTS[hero_id]
		var affection: int = HeroSystem.hero_affection.get(hero_id, 0)
		for i in range(cq["steps"].size()):
			var step: Dictionary = cq["steps"][i]
			var state: Dictionary = _character_progress.get(step["id"], {})
			if state.get("status", -1) == QuestDefs.QuestStatus.LOCKED:
				# Check: previous step done (or first step), affection threshold met
				var prev_done: bool = (i == 0) or _is_completed(_character_progress, cq["steps"][i - 1]["id"])
				if prev_done and affection >= step["affection_required"]:
					_character_progress[step["id"]]["status"] = QuestDefs.QuestStatus.ACTIVE
					_notify_quest_available("角色", step["name"])
			elif state.get("status", -1) == QuestDefs.QuestStatus.ACTIVE:
				if _evaluate_objective(step["objective"], player_id):
					_complete_character_step(step, hero_id, player_id)


# ═══════════════ COMPLETION LOGIC ═══════════════

func _complete_quest_entry(progress_dict: Dictionary, quest_id: String, reward: Dictionary, player_id: int, category: String, quest_name: String) -> void:
	progress_dict[quest_id]["status"] = QuestDefs.QuestStatus.COMPLETED
	progress_dict[quest_id]["completed_at"] = GameManager.turn_number
	_apply_reward(reward, player_id)
	var msg_text: String = reward.get("message", "")
	EventBus.message_log.emit("[color=gold][%s完成] %s[/color]" % [category, quest_name])
	if msg_text != "":
		EventBus.message_log.emit("[color=white]%s[/color]" % msg_text)
	if EventBus.has_signal("quest_journal_updated"):
		EventBus.quest_journal_updated.emit()


func _complete_challenge(challenge: Dictionary, player_id: int) -> void:
	_challenge_progress[challenge["id"]]["status"] = QuestDefs.QuestStatus.COMPLETED
	_challenge_progress[challenge["id"]]["completed_at"] = GameManager.turn_number
	_apply_challenge_reward(challenge.get("reward", {}), player_id)
	EventBus.message_log.emit("[color=gold][挑战完成] %s[/color]" % challenge["name"])
	if EventBus.has_signal("quest_journal_updated"):
		EventBus.quest_journal_updated.emit()


func _complete_character_step(step: Dictionary, hero_id: String, player_id: int) -> void:
	_character_progress[step["id"]]["status"] = QuestDefs.QuestStatus.COMPLETED
	_character_progress[step["id"]]["completed_at"] = GameManager.turn_number
	var reward: Dictionary = step.get("reward", {})
	# Affection bonus
	if reward.has("affection"):
		HeroSystem.add_affection(hero_id, reward["affection"])
	# Equipment
	if reward.has("equipment"):
		_grant_equipment(reward["equipment"], player_id, "character")
	# Trait
	if reward.has("trait"):
		_unlock_trait(reward["trait"])
	var msg_text: String = reward.get("message", "")
	EventBus.message_log.emit("[color=orchid][角色任务完成] %s[/color]" % step["name"])
	if msg_text != "":
		EventBus.message_log.emit("[color=white]%s[/color]" % msg_text)
	if EventBus.has_signal("quest_journal_updated"):
		EventBus.quest_journal_updated.emit()


# ═══════════════ REWARD APPLICATION ═══════════════

func _apply_reward(reward: Dictionary, player_id: int) -> void:
	var delta: Dictionary = {}
	if reward.has("gold"):
		delta["gold"] = reward["gold"]
	if reward.has("food"):
		delta["food"] = reward["food"]
	if reward.has("iron"):
		delta["iron"] = reward["iron"]
	if reward.has("prestige"):
		delta["prestige"] = reward["prestige"]
	if not delta.is_empty():
		ResourceManager.apply_delta(player_id, delta)
	if reward.has("shadow_essence"):
		StrategicResourceManager.add_amount(player_id, "shadow_essence", reward["shadow_essence"])
	if reward.has("item"):
		ItemManager.add_item(player_id, reward["item"])
	if reward.has("relic"):
		RelicManager.add_relic(player_id, reward["relic"])
	if reward.has("order_bonus"):
		OrderManager.change_order(reward["order_bonus"])
	if reward.has("waaagh"):
		OrcMechanic.add_waaagh(player_id, reward["waaagh"])
	if reward.has("plunder"):
		PirateMechanic.add_plunder_bonus(player_id, reward["plunder"])
	if reward.has("title"):
		_unlocked_titles.append(reward["title"])
		_active_title = reward["title"]
		EventBus.message_log.emit("[color=gold]获得称号: %s[/color]" % reward["title"])


func _apply_challenge_reward(reward: Dictionary, player_id: int) -> void:
	if reward.has("equipment"):
		_grant_equipment(reward["equipment"], player_id, "challenge")
	if reward.has("trait"):
		_unlock_trait(reward["trait"])
	if reward.has("skill_upgrade"):
		_unlock_skill(reward["skill_upgrade"])
	if reward.has("title"):
		_unlocked_titles.append(reward["title"])
		_active_title = reward["title"]
		EventBus.message_log.emit("[color=gold]获得称号: %s[/color]" % reward["title"])


func _grant_equipment(equip_id: String, player_id: int, source: String) -> void:
	# Register in EQUIPMENT_DEFS if it's a challenge/character item
	var equip_data: Dictionary = {}
	if source == "challenge" and ChallengeData.CHALLENGE_EQUIPMENT.has(equip_id):
		equip_data = ChallengeData.CHALLENGE_EQUIPMENT[equip_id]
	elif source == "character" and QuestDefs.CHARACTER_EQUIPMENT.has(equip_id):
		equip_data = QuestDefs.CHARACTER_EQUIPMENT[equip_id]
	if not equip_data.is_empty():
		# Dynamically register into FactionData.EQUIPMENT_DEFS for item system compatibility
		FactionData.EQUIPMENT_DEFS[equip_id] = equip_data
	ItemManager.add_item(player_id, equip_id)
	var name_str: String = equip_data.get("name", equip_id)
	EventBus.message_log.emit("[color=orange]获得传奇装备: %s[/color]" % name_str)


func _unlock_trait(trait_id: String) -> void:
	if trait_id in _unlocked_traits:
		return
	_unlocked_traits.append(trait_id)
	# Look up trait name from all trait sources
	var trait_data: Dictionary = {}
	if ChallengeData.CHALLENGE_TRAITS.has(trait_id):
		trait_data = ChallengeData.CHALLENGE_TRAITS[trait_id]
	elif QuestDefs.CHARACTER_TRAITS.has(trait_id):
		trait_data = QuestDefs.CHARACTER_TRAITS[trait_id]
	var tname: String = trait_data.get("name", trait_id)
	var tdesc: String = trait_data.get("desc", "")
	EventBus.message_log.emit("[color=cyan]解锁特性: %s — %s[/color]" % [tname, tdesc])


func _unlock_skill(skill_id: String) -> void:
	if ChallengeData.SKILL_UPGRADES.has(skill_id):
		var skill_data: Dictionary = ChallengeData.SKILL_UPGRADES[skill_id]
		# Register into HERO_SKILL_DEFS for combat system
		FactionData.HERO_SKILL_DEFS[skill_data["name"]] = skill_data
		EventBus.message_log.emit("[color=gold]解锁终极技能: %s[/color]" % skill_data["name"])


# ═══════════════ CHALLENGE BATTLE API ═══════════════

func get_pending_challenge_battle(player_id: int) -> Dictionary:
	## Returns the next challenge that requires a battle, or empty dict.
	var faction_id: int = GameManager.get_player_faction(player_id)
	if not ChallengeData.CHALLENGES.has(faction_id):
		return {}
	for c in ChallengeData.CHALLENGES[faction_id]:
		var state: Dictionary = _challenge_progress.get(c["id"], {})
		if state.get("status", -1) == QuestDefs.QuestStatus.ACTIVE and c.get("battle") != null:
			if _evaluate_trigger(c.get("trigger", {}), player_id):
				return c
	return {}


func start_challenge_battle(challenge_id: String) -> Dictionary:
	## Returns battle data for combat system. Sets quest to COMBAT_PENDING.
	if _challenge_progress.has(challenge_id):
		_challenge_progress[challenge_id]["status"] = QuestDefs.QuestStatus.COMBAT_PENDING
	# Find challenge data
	for faction_id in ChallengeData.CHALLENGES:
		for c in ChallengeData.CHALLENGES[faction_id]:
			if c["id"] == challenge_id:
				return c.get("battle", {})
	return {}


func resolve_challenge_battle(challenge_id: String, won: bool, player_id: int) -> void:
	## Called after challenge boss fight resolves.
	if not _challenge_progress.has(challenge_id):
		return
	if won:
		for faction_id in ChallengeData.CHALLENGES:
			for c in ChallengeData.CHALLENGES[faction_id]:
				if c["id"] == challenge_id:
					_complete_challenge(c, player_id)
					return
	else:
		# Failed: reset to ACTIVE so player can retry
		_challenge_progress[challenge_id]["status"] = QuestDefs.QuestStatus.ACTIVE
		EventBus.message_log.emit("[color=red]挑战战斗失败! 可以再次尝试。[/color]")


# ═══════════════ PUBLIC QUERY API ═══════════════

func get_all_quests(player_id: int) -> Array:
	## Returns all quests with current status for UI display.
	var result: Array = []
	# Main
	for q in QuestDefs.MAIN_QUESTS:
		var state: Dictionary = _main_progress.get(q["id"], {})
		result.append(_format_quest(q, state, "main", player_id))
	# Side
	for q in QuestDefs.SIDE_QUESTS:
		var state: Dictionary = _side_progress.get(q["id"], {})
		if state.get("status", -1) != QuestDefs.QuestStatus.LOCKED:
			result.append(_format_quest(q, state, "side", player_id))
	# Expanded side quests (story/bonus/intel)
	for q in SideQuestData.STORY_QUESTS:
		var state: Dictionary = _side_progress.get(q["id"], {})
		if state.get("status", -1) != QuestDefs.QuestStatus.LOCKED:
			var entry: Dictionary = _format_quest(q, state, "side", player_id)
			entry["sub_category"] = "story"
			result.append(entry)
	for q in SideQuestData.BONUS_QUESTS:
		var state: Dictionary = _side_progress.get(q["id"], {})
		if state.get("status", -1) != QuestDefs.QuestStatus.LOCKED:
			var entry: Dictionary = _format_quest(q, state, "side", player_id)
			entry["sub_category"] = "bonus"
			result.append(entry)
	for q in SideQuestData.INTEL_QUESTS:
		var state: Dictionary = _side_progress.get(q["id"], {})
		if state.get("status", -1) != QuestDefs.QuestStatus.LOCKED:
			var entry: Dictionary = _format_quest(q, state, "side", player_id)
			entry["sub_category"] = "intel"
			result.append(entry)
	# Challenge
	var faction_id: int = GameManager.get_player_faction(player_id)
	if ChallengeData.CHALLENGES.has(faction_id):
		for c in ChallengeData.CHALLENGES[faction_id]:
			var state: Dictionary = _challenge_progress.get(c["id"], {})
			if state.get("status", -1) != QuestDefs.QuestStatus.LOCKED:
				result.append(_format_challenge(c, state, player_id))
	# Character
	for hero_id in QuestDefs.CHARACTER_QUESTS:
		var cq: Dictionary = QuestDefs.CHARACTER_QUESTS[hero_id]
		for step in cq["steps"]:
			var state: Dictionary = _character_progress.get(step["id"], {})
			if state.get("status", -1) != QuestDefs.QuestStatus.LOCKED:
				result.append(_format_character_quest(step, cq, state, player_id))
	return result


func get_active_count() -> int:
	var count: int = 0
	for qid in _main_progress:
		if _main_progress[qid].get("status") == QuestDefs.QuestStatus.ACTIVE:
			count += 1
	for qid in _side_progress:
		if _side_progress[qid].get("status") == QuestDefs.QuestStatus.ACTIVE:
			count += 1
	for qid in _challenge_progress:
		if _challenge_progress[qid].get("status") == QuestDefs.QuestStatus.ACTIVE:
			count += 1
	for qid in _character_progress:
		if _character_progress[qid].get("status") == QuestDefs.QuestStatus.ACTIVE:
			count += 1
	return count


func has_trait(trait_id: String) -> bool:
	return trait_id in _unlocked_traits


func get_trait_effects() -> Array:
	## Returns all active trait effect dicts (for combat system to query).
	var effects: Array = []
	for tid in _unlocked_traits:
		if ChallengeData.CHALLENGE_TRAITS.has(tid):
			effects.append(ChallengeData.CHALLENGE_TRAITS[tid].get("effect", {}))
		elif QuestDefs.CHARACTER_TRAITS.has(tid):
			effects.append(QuestDefs.CHARACTER_TRAITS[tid].get("effect", {}))
	return effects


func get_active_title() -> String:
	return _active_title


func get_stats() -> Dictionary:
	return _stats


## Returns a list of active quests with objective details, for the on-screen tracker.
## Each entry: { id, name, category, objectives: [{label, done, guidance}], desc }
## Priority: main quest first, then side, then challenge, then character.
func get_tracked_quests(player_id: int) -> Array:
	var result: Array = []
	# Main quests
	for q in QuestDefs.MAIN_QUESTS:
		var state: Dictionary = _main_progress.get(q["id"], {})
		if state.get("status", -1) == QuestDefs.QuestStatus.ACTIVE:
			result.append(_format_tracked(q, "主线", player_id))
			break  # Only first active main quest
	# Side quests (original + expanded)
	var side_lists: Array = [QuestDefs.SIDE_QUESTS, SideQuestData.STORY_QUESTS, SideQuestData.BONUS_QUESTS, SideQuestData.INTEL_QUESTS]
	for arr in side_lists:
		for q in arr:
			var state: Dictionary = _side_progress.get(q["id"], {})
			if state.get("status", -1) == QuestDefs.QuestStatus.ACTIVE:
				result.append(_format_tracked(q, "支线", player_id))
	# Challenge quests
	var faction_id: int = GameManager.get_player_faction(player_id)
	if ChallengeData.CHALLENGES.has(faction_id):
		for c in ChallengeData.CHALLENGES[faction_id]:
			var state: Dictionary = _challenge_progress.get(c["id"], {})
			if state.get("status", -1) == QuestDefs.QuestStatus.ACTIVE:
				result.append({
					"id": c["id"], "name": c["name"], "category": "挑战",
					"desc": c.get("desc", ""),
					"objectives": [{"label": c.get("task", ""), "done": false, "guidance": _get_guidance_for_type("challenge")}],
				})
	# Character quests
	for hero_id in QuestDefs.CHARACTER_QUESTS:
		if hero_id not in HeroSystem.recruited_heroes:
			continue
		var cq: Dictionary = QuestDefs.CHARACTER_QUESTS[hero_id]
		for step in cq["steps"]:
			var state: Dictionary = _character_progress.get(step["id"], {})
			if state.get("status", -1) == QuestDefs.QuestStatus.ACTIVE:
				var obj: Dictionary = step["objective"]
				result.append({
					"id": step["id"], "name": "%s - %s" % [cq["hero_name"], step["name"]],
					"category": "角色", "desc": step.get("desc", ""),
					"objectives": [{"label": obj.get("label", ""), "done": _evaluate_objective(obj, player_id), "guidance": _get_guidance_for_type(obj.get("type", ""))}],
				})
	return result


func _format_tracked(q: Dictionary, category: String, player_id: int) -> Dictionary:
	var objectives_status: Array = []
	for obj in q.get("objectives", []):
		objectives_status.append({
			"label": obj.get("label", ""),
			"done": _evaluate_objective(obj, player_id),
			"guidance": _get_guidance_for_type(obj.get("type", "")),
		})
	return {
		"id": q["id"], "name": q["name"], "category": category,
		"desc": q.get("desc", ""),
		"objectives": objectives_status,
	}


## Guidance text mapping: tells the player HOW to complete each objective type.
func _get_guidance_for_type(otype: String) -> String:
	match otype:
		"tiles_min":
			return "选择「进攻」行动，攻占相邻敌方或中立领地"
		"battles_won_min":
			return "进攻敌方领地并赢得战斗"
		"army_count_min":
			return "通过「内政→招募」创建新的军团"
		"building_any", "buildings_min":
			return "选择「内政→建造」在己方领地建造建筑"
		"gold_min":
			return "占领产金领地或等待回合收入积累"
		"food_min":
			return "占领农田领地或建造粮仓建筑"
		"iron_min":
			return "占领矿山领地或建造冶炼厂"
		"heroes_min":
			return "通过战斗俘获敌方英雄，在英雄管理中招募"
		"neutral_recruited_min":
			return "使用「外交」行动与中立势力交涉并完成收编任务"
		"threat_min":
			return "持续扩张领土和攻占要塞会自动提升威胁值"
		"order_min":
			return "使用威望提升秩序，或避免过度扩张"
		"strongholds_min", "all_strongholds":
			return "进攻光明联盟的要塞领地（地图上的城堡标记）"
		"harbor_min":
			return "攻占沿海的港口领地"
		"slaves_min":
			return "通过战斗俘获奴隶，或在奴隶市场购买"
		"shadow_essence_min":
			return "占领暗影领地或通过祭坛获取暗影精华"
		"waaagh_frenzy_triggered", "waaagh_battle_win":
			return "在WAAAGH!值较高时发动进攻触发狂暴"
		"heroes_captured_total":
			return "在战斗中击败并俘获敌方英雄"
		"defend_expedition":
			return "当远征军出现时防守己方领地"
		"tiles_gained_in_turns":
			return "集中在短时间内连续攻占多个领地"
		"total_kills_min":
			return "通过战斗消灭敌方士兵积累击杀数"
		"tiles_not_lost_turns":
			return "加强防御，避免领地被敌方夺回"
		"ap_purchased_min":
			return "使用威望在行动面板购买额外行动力"
		"hero_level_min":
			return "让英雄参与战斗获取经验升级"
		"relics_min":
			return "通过「探索」行动寻找遗物"
		"researches_min":
			return "在「训练科技」面板中完成研究项目"
		"public_order_all_min":
			return "在所有领地保持较高的公共秩序"
		"fog_revealed_pct":
			return "使用「探索」行动揭开战争迷雾"
		"watchtowers_min":
			return "在己方领地建造瞭望塔建筑"
		"treaties_signed_min":
			return "使用「外交」行动与其他势力签订条约"
		"total_soldiers_min":
			return "通过「内政→招募」扩充军队总兵力"
		"challenge":
			return "完成当前挑战任务的战斗要求"
	return "查看任务日志(J)获取详情"


# ═══════════════ FORMAT HELPERS ═══════════════

func _format_quest(q: Dictionary, state: Dictionary, category: String, player_id: int) -> Dictionary:
	var objectives_status: Array = []
	for obj in q.get("objectives", []):
		objectives_status.append({
			"label": obj.get("label", ""),
			"done": _evaluate_objective(obj, player_id),
		})
	return {
		"id": q["id"], "name": q["name"], "desc": q.get("desc", ""),
		"category": category,
		"status": state.get("status", QuestDefs.QuestStatus.LOCKED),
		"objectives": objectives_status,
		"reward_preview": _preview_reward(q.get("reward", {})),
	}

func _format_challenge(c: Dictionary, state: Dictionary, player_id: int) -> Dictionary:
	var has_battle: bool = c.get("battle") != null
	return {
		"id": c["id"], "name": c["name"], "desc": c.get("desc", ""),
		"category": "challenge",
		"status": state.get("status", QuestDefs.QuestStatus.LOCKED),
		"objectives": [{"label": c.get("task", ""), "done": state.get("status") == QuestDefs.QuestStatus.COMPLETED}],
		"has_battle": has_battle,
		"battle_name": c["battle"]["name"] if has_battle else "",
		"reward_preview": _preview_challenge_reward(c.get("reward", {})),
	}

func _format_character_quest(step: Dictionary, cq: Dictionary, state: Dictionary, player_id: int) -> Dictionary:
	return {
		"id": step["id"], "name": step["name"], "desc": step.get("desc", ""),
		"category": "character", "hero_name": cq["hero_name"],
		"status": state.get("status", QuestDefs.QuestStatus.LOCKED),
		"objectives": [{"label": step["objective"].get("label", ""), "done": _evaluate_objective(step["objective"], player_id)}],
		"reward_preview": step.get("reward", {}).get("message", ""),
	}

func _preview_reward(reward: Dictionary) -> String:
	var parts: Array = []
	if reward.has("gold"): parts.append("%d金" % reward["gold"])
	if reward.has("food"): parts.append("%d粮" % reward["food"])
	if reward.has("iron"): parts.append("%d铁" % reward["iron"])
	if reward.has("item"): parts.append("道具")
	if reward.has("title"): parts.append("称号: %s" % reward["title"])
	return ", ".join(parts) if not parts.is_empty() else ""

func _preview_challenge_reward(reward: Dictionary) -> String:
	var parts: Array = []
	if reward.has("equipment"): parts.append("传奇装备")
	if reward.has("trait"): parts.append("特性解锁")
	if reward.has("skill_upgrade"): parts.append("终极技能")
	if reward.has("title"): parts.append("称号: %s" % reward["title"])
	return ", ".join(parts) if not parts.is_empty() else ""


# ═══════════════ STAT TRACKING (signal handlers) ═══════════════

func _on_combat_result(attacker_id: int, _defender_desc: String, won: bool) -> void:
	if not _initialized:
		return
	var pid: int = GameManager.get_human_player_id()
	if attacker_id == pid and won:
		_stats["battles_won"] += 1
		# Bug fix Round 3: total_kills was incrementing by 1 per battle.
		# Signal handler only receives (attacker_id, defender_desc, won) — no detailed
		# combat result dict available. Use a reasonable estimate based on typical garrison.
		var last_kills: int = clampi(GameManager.tiles.size(), 3, 15) if not GameManager.tiles.is_empty() else 5
		_stats["total_kills"] = _stats.get("total_kills", 0) + last_kills
		# Check WAAAGH! state for orc challenge
		if OrcMechanic and OrcMechanic.has_method("get_waaagh"):
			if OrcMechanic.get_waaagh(pid) >= BalanceConfig.WAAAGH_FRENZY_THRESHOLD:
				_stats["waaagh_battle_wins"] += 1


func _on_tile_captured(player_id: int, _tile_index: int) -> void:
	if not _initialized:
		return
	_stats["tiles_captured_log"].append({"turn": GameManager.turn_number, "count": 1})


func _on_hero_captured(_hero_id: String) -> void:
	if not _initialized:
		return
	_stats["heroes_captured_total"] += 1


func _on_turn_started(player_id: int) -> void:
	if not _initialized:
		return
	if player_id == GameManager.get_human_player_id():
		tick(player_id)


func notify_expedition_defended() -> void:
	## Call from GameManager when player successfully defends against expedition.
	_stats["expeditions_defended"] += 1


func _on_tile_lost(_player_id: int, _tile_index: int) -> void:
	if not _initialized:
		return
	_stats["tiles_lost_this_turn"] = true


func _on_challenge_battle_resolved(challenge_id: String, won: bool) -> void:
	var pid: int = GameManager.get_human_player_id()
	resolve_challenge_battle(challenge_id, won, pid)


# ═══════════════ UTILITY ═══════════════

func _count_player_tiles(player_id: int) -> int:
	var c: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			c += 1
	return c

func _count_player_buildings(player_id: int) -> int:
	var c: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id and tile.get("building_id", "") != "":
			c += 1
	return c

func _count_tile_type(player_id: int, tile_type: int) -> int:
	var c: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id and tile.get("type", -1) == tile_type:
			c += 1
	return c

func _check_tiles_in_window(turns: int, required: int) -> bool:
	var current_turn: int = GameManager.turn_number
	var count: int = 0
	for entry in _stats["tiles_captured_log"]:
		if entry["turn"] >= current_turn - turns:
			count += entry["count"]
	return count >= required


func _get_max_hero_level() -> int:
	var max_lvl: int = 0
	for hero_id in HeroSystem.recruited_heroes:
		var lvl: int = HeroLeveling.get_hero_level(hero_id)
		if lvl > max_lvl:
			max_lvl = lvl
	return max_lvl


func _all_tiles_public_order_min(player_id: int, threshold: float) -> bool:
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			if tile.get("public_order", 0.0) < threshold:
				return false
	return true


func _get_fog_revealed_pct(player_id: int) -> float:
	var total: int = GameManager.tiles.size()
	if total == 0:
		return 0.0
	var revealed: int = 0
	for t in GameManager.tiles:
		if t.get("revealed", {}).get(player_id, false):
			revealed += 1
	return (float(revealed) / float(total)) * 100.0


func _count_tiles_with_building(player_id: int, building_id: String) -> int:
	var c: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id and tile.get("building_id", "") == building_id:
			c += 1
	return c


func _get_total_soldiers(player_id: int) -> int:
	var total: int = 0
	for army in GameManager.get_player_armies(player_id):
		total += army.get("soldiers", 0)
	return total

func _is_completed(progress_dict: Dictionary, quest_id: String) -> bool:
	return progress_dict.get(quest_id, {}).get("status", -1) == QuestDefs.QuestStatus.COMPLETED


func _count_tiles_with_terrain(player_id: int, terrain_type: String) -> int:
	var terrain_enum: int = -1
	match terrain_type:
		"ruins":
			terrain_enum = FactionData.TerrainType.RUINS
		"mine":
			terrain_enum = FactionData.TerrainType.MOUNTAIN
		_:
			push_warning("QuestJournal: unknown terrain_type string '%s'" % terrain_type)
			return 0
	var c: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id and tile.get("terrain", -1) == terrain_enum:
			c += 1
	return c


func _count_captured_heroines(player_id: int) -> int:
	return HeroSystem.captured_heroes.size()


func _count_heroes_with_submission(player_id: int, threshold: int) -> int:
	var c: int = 0
	for hero_id in HeroSystem.recruited_heroes:
		var submission: int = HeroSystem.hero_submission.get(hero_id, 0)
		if submission >= threshold:
			c += 1
	return c


func _any_building_level_at_least(player_id: int, min_level: int) -> bool:
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id and tile.get("building_level", 0) >= min_level:
			return true
	return false

func _notify_quest_available(category: String, quest_name: String) -> void:
	EventBus.message_log.emit("[color=yellow][新%s任务] %s[/color]" % [category, quest_name])
	if EventBus.has_signal("quest_journal_updated"):
		EventBus.quest_journal_updated.emit()


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"main": _main_progress.duplicate(true),
		"side": _side_progress.duplicate(true),
		"challenge": _challenge_progress.duplicate(true),
		"character": _character_progress.duplicate(true),
		"traits": _unlocked_traits.duplicate(),
		"titles": _unlocked_titles.duplicate(),
		"active_title": _active_title,
		"stats": _stats.duplicate(true),
		"initialized": _initialized,
	}

func from_save_data(data: Dictionary) -> void:
	# Deep-duplicate all loaded data to avoid mutating the save source (Bug fix Round 3)
	_main_progress = data.get("main", {}).duplicate(true)
	_side_progress = data.get("side", {}).duplicate(true)
	_challenge_progress = data.get("challenge", {}).duplicate(true)
	_character_progress = data.get("character", {}).duplicate(true)
	_unlocked_traits = data.get("traits", []).duplicate()
	_unlocked_titles = data.get("titles", []).duplicate()
	_active_title = data.get("active_title", "")
	_stats = data.get("stats", {"battles_won": 0, "heroes_captured_total": 0,
		"waaagh_battle_wins": 0, "expeditions_defended": 0, "tiles_captured_log": [],
		"total_kills": 0, "ap_purchased": 0, "tiles_not_lost_streak": 0, "tiles_lost_this_turn": false}).duplicate(true)
	# Fix int values in _stats after JSON round-trip
	for stat_key in ["battles_won", "heroes_captured_total", "waaagh_battle_wins",
			"expeditions_defended", "total_kills", "ap_purchased", "tiles_not_lost_streak"]:
		if _stats.has(stat_key):
			_stats[stat_key] = int(_stats[stat_key])
	# BUG FIX R17: fix int values inside tiles_captured_log nested dicts after JSON round-trip
	if _stats.has("tiles_captured_log") and _stats["tiles_captured_log"] is Array:
		for entry in _stats["tiles_captured_log"]:
			if entry is Dictionary:
				if entry.has("turn"):
					entry["turn"] = int(entry["turn"])
				if entry.has("count"):
					entry["count"] = int(entry["count"])
	# Fix status/completed_at in progress dicts
	for prog_dict in [_main_progress, _side_progress, _challenge_progress, _character_progress]:
		for qid in prog_dict:
			var entry: Dictionary = prog_dict[qid]
			if entry.has("status"):
				entry["status"] = int(entry["status"])
			if entry.has("completed_at"):
				entry["completed_at"] = int(entry["completed_at"])
	_initialized = data.get("initialized", false)
