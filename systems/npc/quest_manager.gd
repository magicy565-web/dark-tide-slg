extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## quest_manager.gd - Quest chain tracking & per-turn automation (v0.8.9)

# Per-player quest progress: { player_id: { faction_enum_value: { "step": int, "completed": bool } } }
var _quest_progress: Dictionary = {}

# Recruited neutral factions: { player_id: Array of faction_enum_values }
var _recruited_factions: Dictionary = {}

# Stored recruitment bonuses for production integration
# { player_id: { "iron_per_turn_bonus": float, "gold_per_turn": int, "gunpowder_per_turn": int,
#                "atk_bonus": int, "iron_flat_per_turn": int, "victory_prestige": int } }
var _recruitment_bonuses: Dictionary = {}

# Unlocked unique unit IDs per player: { player_id: Array of unit_special strings }
var _unlocked_units: Dictionary = {}

# Pending quest combat: { player_id: { "neutral_faction": int, "enemy_soldiers": int } or null }
var _pending_quest_combat: Dictionary = {}

# Free item timer for recruited Wandering Caravan: { player_id: int (turns since last free item) }
var _caravan_item_timer: Dictionary = {}

# Taming levels per player per neutral faction: { player_id: { faction_id_or_tag: int (0-10) } }
var _taming_levels: Dictionary = {}

# ═══════════════ NEUTRAL_FACTIONS LOOKUP ═══════════════
# Maps string tags to FactionData.NEUTRAL_FACTION_DATA entries (bridging game_manager calls)

static var _FACTION_TAG_TO_ID: Dictionary = {
	"neutral_ironhammer_dwarf": FactionData.NeutralFaction.IRONHAMMER_DWARF,
	"neutral_caravan": FactionData.NeutralFaction.WANDERING_CARAVAN,
	"neutral_necromancer": FactionData.NeutralFaction.NECROMANCER,
	"neutral_forest_ranger": FactionData.NeutralFaction.FOREST_RANGER,
	"neutral_blood_moon": FactionData.NeutralFaction.BLOOD_MOON_CULT,
	"neutral_goblin_engineer": FactionData.NeutralFaction.GOBLIN_ENGINEER,
}

static var _FACTION_ID_TO_TAG: Dictionary = {
	FactionData.NeutralFaction.IRONHAMMER_DWARF: "neutral_ironhammer_dwarf",
	FactionData.NeutralFaction.WANDERING_CARAVAN: "neutral_caravan",
	FactionData.NeutralFaction.NECROMANCER: "neutral_necromancer",
	FactionData.NeutralFaction.FOREST_RANGER: "neutral_forest_ranger",
	FactionData.NeutralFaction.BLOOD_MOON_CULT: "neutral_blood_moon",
	FactionData.NeutralFaction.GOBLIN_ENGINEER: "neutral_goblin_engineer",
}

## NEUTRAL_FACTIONS - exposed for game_manager compatibility.
## Maps string tag → faction data dict (mirrors FactionData.NEUTRAL_FACTION_DATA keyed by tag).
var NEUTRAL_FACTIONS: Dictionary = {}

func _ready() -> void:
	# Build NEUTRAL_FACTIONS from FactionData at runtime
	for nf_id in FactionData.NEUTRAL_FACTION_DATA:
		var tag: String = _FACTION_ID_TO_TAG.get(nf_id, "")
		if tag != "":
			NEUTRAL_FACTIONS[tag] = FactionData.NEUTRAL_FACTION_DATA[nf_id]


func reset() -> void:
	_quest_progress.clear()
	_recruited_factions.clear()
	_recruitment_bonuses.clear()
	_unlocked_units.clear()
	_pending_quest_combat.clear()
	_caravan_item_timer.clear()
	_taming_levels.clear()


func init_player(player_id: int) -> void:
	_quest_progress[player_id] = {}
	_recruited_factions[player_id] = []
	_recruitment_bonuses[player_id] = _default_bonuses()
	_unlocked_units[player_id] = []
	_caravan_item_timer[player_id] = 0
	_taming_levels[player_id] = {}


func _default_bonuses() -> Dictionary:
	return {
		"iron_per_turn_bonus": 0.0, "gold_per_turn": 0, "gunpowder_per_turn": 0,
		"atk_bonus": 0, "iron_flat_per_turn": 0, "victory_prestige": 0,
		"vision_bonus": 0,
	}


# ═══════════════ QUEST STEP MANAGEMENT ═══════════════

func get_quest_step(player_id: int, neutral_faction: int) -> int:
	## Returns current step (0 = not started, 1-3 = in progress/completed steps)
	if not _quest_progress.has(player_id):
		return 0
	var player_quests: Dictionary = _quest_progress.get(player_id, {})
	if not player_quests.has(neutral_faction):
		return 0
	return player_quests.get(neutral_faction, {}).get("step", 0)


func start_quest(player_id: int, neutral_faction: int) -> bool:
	## Begin quest chain (triggered when passing through neutral faction's tile).
	if not _quest_progress.has(player_id):
		init_player(player_id)
	if _quest_progress[player_id].has(neutral_faction):
		return false  # Already started
	_quest_progress[player_id][neutral_faction] = {"step": 1, "completed": false}
	var fname: String = FactionData.NEUTRAL_FACTION_NAMES.get(neutral_faction, "未知")
	var leader: String = FactionData.NEUTRAL_FACTION_DATA.get(neutral_faction, {}).get("leader_name", "")
	if leader != "":
		EventBus.message_log.emit("开始任务链: %s (领袖: %s)" % [fname, leader])
	else:
		EventBus.message_log.emit("开始任务链: %s" % fname)
	return true


func advance_quest(player_id: int, neutral_faction: int) -> bool:
	## Advance to next step. Called when step conditions are met.
	if not _quest_progress.has(player_id) or not _quest_progress[player_id].has(neutral_faction):
		return false
	var current_step: int = _quest_progress[player_id][neutral_faction]["step"]
	# 边界检查：根据实际任务链长度判断是否已到最大步骤
	var fd: Dictionary = FactionData.NEUTRAL_FACTION_DATA.get(neutral_faction, {})
	var quest_chain: Array = fd.get("quest_chain", [])
	var max_steps: int = quest_chain.size() if not quest_chain.is_empty() else 3
	if current_step >= max_steps:
		return false
	_quest_progress[player_id][neutral_faction]["step"] = current_step + 1
	# Increase taming by +3 per step advancement
	var old_taming: int = get_taming_level(player_id, neutral_faction)
	set_taming_level(player_id, neutral_faction, old_taming + 3)
	EventBus.neutral_quest_step_completed.emit(player_id, neutral_faction, current_step + 1)
	var fname: String = FactionData.NEUTRAL_FACTION_NAMES.get(neutral_faction, "未知")
	EventBus.message_log.emit("%s 任务进度: 步骤 %d/3" % [fname, current_step + 1])
	return true


func complete_quest(player_id: int, neutral_faction: int) -> bool:
	## Mark quest as completed and recruit the faction.
	if not _quest_progress.has(player_id) or not _quest_progress[player_id].has(neutral_faction):
		return false
	var fd: Dictionary = FactionData.NEUTRAL_FACTION_DATA.get(neutral_faction, {})
	var quest_chain: Array = fd.get("quest_chain", [])
	var max_steps: int = quest_chain.size() if not quest_chain.is_empty() else 3
	if _quest_progress[player_id][neutral_faction]["step"] < max_steps:
		return false
	_quest_progress[player_id][neutral_faction]["completed"] = true
	if not _recruited_factions.has(player_id):
		_recruited_factions[player_id] = []
	_recruited_factions[player_id].append(neutral_faction)
	# Max out taming on completion
	set_taming_level(player_id, neutral_faction, 10)

	# Apply recruitment rewards
	_apply_recruitment_rewards(player_id, neutral_faction)

	var fname: String = FactionData.NEUTRAL_FACTION_NAMES.get(neutral_faction, "未知")
	var leader: String = FactionData.NEUTRAL_FACTION_DATA.get(neutral_faction, {}).get("leader_name", "")
	EventBus.message_log.emit("[color=green]成功收编 %s! (%s加入, 服从度35)[/color]" % [fname, leader])
	EventBus.faction_recruited.emit(player_id, neutral_faction)
	return true


func is_faction_recruited(player_id: int, neutral_faction: int) -> bool:
	if not _recruited_factions.has(player_id):
		return false
	return neutral_faction in _recruited_factions[player_id]


func get_recruited_factions(player_id: int) -> Array:
	return _recruited_factions.get(player_id, [])


func has_unlocked_unit(player_id: int, unit_special: String) -> bool:
	return unit_special in _unlocked_units.get(player_id, [])


func get_unlocked_units(player_id: int) -> Array:
	return _unlocked_units.get(player_id, [])


# ═══════════════ TRIGGER CHECKING ═══════════════

func check_quest_triggers(player_id: int, neutral_faction: int) -> Dictionary:
	## Check if current step's trigger conditions are met.
	## Returns { "can_advance": bool, "missing": String, "requires_combat": bool, ... }
	var step: int = get_quest_step(player_id, neutral_faction)
	if step == 0 or step > 3:
		return {"can_advance": false, "missing": "任务未开始"}

	if not FactionData.NEUTRAL_FACTION_DATA.has(neutral_faction):
		return {"can_advance": false, "missing": "无效势力"}

	var faction_data: Dictionary = FactionData.NEUTRAL_FACTION_DATA[neutral_faction]
	var quest_chain: Array = faction_data.get("quest_chain", [])
	if step < 1 or step > quest_chain.size():
		return {"can_advance": false, "missing": "无此步骤"}

	var step_data: Dictionary = quest_chain[step - 1]
	var trigger = step_data.get("trigger", "")

	# String triggers
	if trigger is String:
		if trigger == "discover" or trigger == "auto":
			return {"can_advance": true, "trigger_type": trigger}
		return {"can_advance": true, "trigger_type": trigger}

	# Dictionary triggers with conditions
	if trigger is Dictionary:
		# Check prerequisite conditions first (non-cost conditions)
		if trigger.has("strongholds_min"):
			if GameManager.count_strongholds_owned(player_id) < trigger["strongholds_min"]:
				return {"can_advance": false, "missing": "需要拥有%d个要塞" % trigger["strongholds_min"]}
		if trigger.has("tiles_min"):
			if GameManager.count_tiles_owned(player_id) < trigger["tiles_min"]:
				return {"can_advance": false, "missing": "需要拥有%d个据点" % trigger["tiles_min"]}
		if trigger.has("prestige_min"):
			if ResourceManager.get_resource(player_id, "prestige") < trigger["prestige_min"]:
				return {"can_advance": false, "missing": "威望不足 (需要%d)" % trigger["prestige_min"]}
		if trigger.has("order_min"):
			if OrderManager.get_order() < trigger["order_min"]:
				return {"can_advance": false, "missing": "秩序值不足 (需要%d)" % trigger["order_min"]}

		# Check resource costs (will be deducted on advance)
		if trigger.has("iron_cost"):
			if ResourceManager.get_resource(player_id, "iron") < trigger["iron_cost"]:
				return {"can_advance": false, "missing": "铁矿不足 (需要%d)" % trigger["iron_cost"]}
		if trigger.has("gold_cost"):
			if ResourceManager.get_resource(player_id, "gold") < trigger["gold_cost"]:
				return {"can_advance": false, "missing": "金币不足 (需要%d)" % trigger["gold_cost"]}
		if trigger.has("slaves_cost"):
			if ResourceManager.get_resource(player_id, "slaves") < trigger["slaves_cost"]:
				return {"can_advance": false, "missing": "奴隶不足 (需要%d)" % trigger["slaves_cost"]}
		if trigger.has("gunpowder_cost"):
			if ResourceManager.get_resource(player_id, "gunpowder") < trigger["gunpowder_cost"]:
				return {"can_advance": false, "missing": "火药不足 (需要%d)" % trigger["gunpowder_cost"]}
		if trigger.has("magic_crystal_cost"):
			if ResourceManager.get_resource(player_id, "magic_crystal") < trigger["magic_crystal_cost"]:
				return {"can_advance": false, "missing": "魔晶不足 (需要%d)" % trigger["magic_crystal_cost"]}

		# Combat trigger - all other conditions passed, now need combat
		if trigger.has("combat"):
			return {"can_advance": true, "requires_combat": true, "enemy_strength": trigger["combat"]}

	return {"can_advance": true, "missing": ""}


# ═══════════════ QUEST STEP COST HANDLING ═══════════════

func _get_step_data(neutral_faction: int, step: int) -> Dictionary:
	var fd: Dictionary = FactionData.NEUTRAL_FACTION_DATA.get(neutral_faction, {})
	var chain: Array = fd.get("quest_chain", [])
	if step < 1 or step > chain.size():
		return {}
	return chain[step - 1]


func deduct_step_costs(player_id: int, neutral_faction: int) -> void:
	## Deduct resource costs for the current step's trigger + any "cost" field.
	var step: int = get_quest_step(player_id, neutral_faction)
	var step_data: Dictionary = _get_step_data(neutral_faction, step)
	if step_data.is_empty():
		return

	var costs: Dictionary = {}

	# Check trigger Dictionary for _cost keys
	var trigger = step_data.get("trigger", "")
	if trigger is Dictionary:
		for cost_key in ["iron_cost", "gold_cost", "slaves_cost", "gunpowder_cost", "magic_crystal_cost"]:
			if trigger.has(cost_key):
				var res_key: String = cost_key.replace("_cost", "")
				costs[res_key] = trigger[cost_key]

	# Check separate "cost" field (for discover steps that still have costs)
	var explicit_cost: Dictionary = step_data.get("cost", {})
	for key in explicit_cost:
		costs[key] = explicit_cost[key]

	if not costs.is_empty():
		ResourceManager.spend(player_id, costs)
		var msg: String = "任务消耗:"
		for key in costs:
			msg += " %s-%d" % [key, costs[key]]
		EventBus.message_log.emit(msg)


func apply_step_rewards(player_id: int, neutral_faction: int) -> void:
	## Apply rewards for the current step.
	var step: int = get_quest_step(player_id, neutral_faction)
	var step_data: Dictionary = _get_step_data(neutral_faction, step)
	if step_data.is_empty():
		return

	var reward: Dictionary = step_data.get("reward", {})

	# Resource rewards
	var delta: Dictionary = {}
	for key in reward:
		if key in ["gold", "iron", "prestige", "shadow_essence", "food"]:
			delta[key] = reward[key]
	if not delta.is_empty():
		ResourceManager.apply_delta(player_id, delta)
		var reward_msg: String = "任务奖励:"
		for key in delta:
			reward_msg += " %s+%d" % [key, delta[key]]
		EventBus.message_log.emit(reward_msg)

	# Item rewards
	if reward.has("item"):
		ItemManager.add_item(player_id, reward["item"])

	# Temp soldiers reward (necromancer step 2)
	if reward.has("temp_soldiers"):
		var count: int = reward["temp_soldiers"]
		var duration: int = reward.get("temp_duration", 5)
		ResourceManager.add_army(player_id, count)
		EventBus.message_log.emit("获得%d临时士兵(%d回合)" % [count, duration])

	# Reveal fog tiles (caravan step 1)
	if reward.has("reveal"):
		var reveal_count: int = reward["reveal"]
		_reveal_fog_tiles(player_id, reveal_count)

	# Order change (blood moon step 3)
	if reward.has("order_change"):
		OrderManager.change_order(reward["order_change"])
		EventBus.message_log.emit("秩序值变化: %d" % reward["order_change"])


func _reveal_fog_tiles(player_id: int, count: int) -> void:
	## Reveal up to 'count' unrevealed tiles.
	var revealed: int = 0
	for tile in GameManager.tiles:
		if revealed >= count:
			break
		if tile.get("fog", true) and tile["owner_id"] < 0:
			tile["fog"] = false
			revealed += 1
	if revealed > 0:
		EventBus.fog_updated.emit(player_id)
		EventBus.message_log.emit("揭示了%d个迷雾格!" % revealed)


# ═══════════════ QUEST COMBAT ═══════════════

func set_pending_combat(player_id: int, neutral_faction: int, enemy_soldiers: int) -> void:
	_pending_quest_combat[player_id] = {"neutral_faction": neutral_faction, "enemy_soldiers": enemy_soldiers}


func get_pending_combat(player_id: int) -> Dictionary:
	return _pending_quest_combat.get(player_id, {})


func clear_pending_combat(player_id: int) -> void:
	_pending_quest_combat.erase(player_id)


func _cleanup_stale_pending_combat(player_id: int) -> void:
	## 每回合检查：如果待处理任务战斗对应的地块已不属于玩家，则清除
	var pending: Dictionary = get_pending_combat(player_id)
	if pending.is_empty():
		return
	var nf: int = pending.get("neutral_faction", -1)
	if nf < 0:
		return
	# 检查是否仍然拥有该中立势力所在的地块
	var still_owns_tile: bool = false
	for tile in GameManager.tiles:
		if tile.get("neutral_faction_id", -1) == nf and tile.get("owner_id", -1) == player_id:
			still_owns_tile = true
			break
	if not still_owns_tile:
		var fname: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf, "未知")
		EventBus.message_log.emit("[color=orange]%s 任务战斗已取消（地块丢失）[/color]" % fname)
		clear_pending_combat(player_id)


func resolve_quest_combat_win(player_id: int) -> void:
	## Called after player wins quest combat. Advances the quest step.
	var pending: Dictionary = get_pending_combat(player_id)
	if pending.is_empty():
		return
	var nf: int = pending["neutral_faction"]
	deduct_step_costs(player_id, nf)
	apply_step_rewards(player_id, nf)
	advance_quest(player_id, nf)
	# Check completion
	var new_step: int = get_quest_step(player_id, nf)
	var faction_data: Dictionary = FactionData.NEUTRAL_FACTION_DATA.get(nf, {})
	var quest_chain: Array = faction_data.get("quest_chain", [])
	var max_steps: int = quest_chain.size() if not quest_chain.is_empty() else 3
	if new_step >= max_steps:
		complete_quest(player_id, nf)
	clear_pending_combat(player_id)


func resolve_quest_combat_loss(player_id: int) -> void:
	## Quest combat lost - no advancement, clear pending.
	var pending: Dictionary = get_pending_combat(player_id)
	if pending.is_empty():
		return
	var nf: int = pending["neutral_faction"]
	var fname: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf, "未知")
	EventBus.message_log.emit("[color=red]%s 任务战斗失败, 下次再试[/color]" % fname)
	clear_pending_combat(player_id)


# ═══════════════ PER-TURN PROCESSING (v0.8.9) ═══════════════

func process_turn(player_id: int) -> void:
	## Called each turn from begin_turn(). Handles:
	## 1. 清理因地块丢失而失效的待处理任务战斗
	## 2. Auto-advance quests whose resource conditions are now met
	## 3. Caravan free item timer
	## 4. Recruitment periodic effects
	_cleanup_stale_pending_combat(player_id)
	_check_auto_advance(player_id)
	_process_recruited_effects(player_id)


func _check_auto_advance(player_id: int) -> void:
	## For each active (non-completed) quest, check if conditions are met for current step.
	## If met and step doesn't require combat, auto-advance.
	if not _quest_progress.has(player_id):
		return
	for nf in _quest_progress[player_id]:
		var qdata: Dictionary = _quest_progress[player_id][nf]
		if qdata.get("completed", false):
			continue
		var step: int = qdata.get("step", 0)
		if step < 1 or step > 3:
			continue

		var check: Dictionary = check_quest_triggers(player_id, nf)
		if not check.get("can_advance", false):
			continue
		if check.get("requires_combat", false):
			# 战斗步骤不能自动推进，通知UI需要玩家手动处理战斗
			var step_data: Dictionary = _get_step_data(nf, step)
			var enemy_soldiers: int = step_data.get("enemy_soldiers", 30)
			EventBus.quest_combat_requested.emit(player_id, nf, enemy_soldiers)
			continue

		# Auto-advance: deduct costs, apply rewards, advance
		var fname: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf, "未知")
		EventBus.message_log.emit("[color=cyan]%s 任务条件已满足, 自动推进![/color]" % fname)
		deduct_step_costs(player_id, nf)
		apply_step_rewards(player_id, nf)
		advance_quest(player_id, nf)

		var new_step: int = get_quest_step(player_id, nf)
		var nf_data: Dictionary = FactionData.NEUTRAL_FACTION_DATA.get(nf, {})
		var nf_chain: Array = nf_data.get("quest_chain", [])
		var nf_max_steps: int = nf_chain.size() if not nf_chain.is_empty() else 3
		if new_step >= nf_max_steps:
			complete_quest(player_id, nf)


func _process_recruited_effects(player_id: int) -> void:
	## Per-turn effects from recruited factions.
	var recruited: Array = get_recruited_factions(player_id)

	# Wandering Caravan: free item every N turns
	if FactionData.NeutralFaction.WANDERING_CARAVAN in recruited:
		var fd: Dictionary = FactionData.NEUTRAL_FACTION_DATA[FactionData.NeutralFaction.WANDERING_CARAVAN]
		var interval: int = fd.get("recruitment_reward", {}).get("free_item_interval", 3)
		_caravan_item_timer[player_id] = _caravan_item_timer.get(player_id, 0) + 1
		if _caravan_item_timer[player_id] >= interval:
			_caravan_item_timer[player_id] = 0
			var item_id: String = ItemManager.grant_random_loot(player_id)
			if item_id != "":
				EventBus.message_log.emit("[color=cyan]商队网络: 免费获得道具![/color]")
				EventBus.neutral_faction_free_item.emit(player_id, FactionData.NeutralFaction.WANDERING_CARAVAN, item_id)

	# Wandering Caravan: reveal 1 fog tile per turn
	if FactionData.NeutralFaction.WANDERING_CARAVAN in recruited:
		_reveal_fog_tiles(player_id, 1)

	# Blood Moon Cult: +1 prestige per victory (tracked in _resolve_combat, not here)
	# Necromancer: skeleton decay (-1 per turn) handled via unique unit mechanic


# ═══════════════ RECRUITMENT REWARDS ═══════════════

func _apply_recruitment_rewards(player_id: int, neutral_faction: int) -> void:
	var faction_data: Dictionary = FactionData.NEUTRAL_FACTION_DATA[neutral_faction]
	var reward: Dictionary = faction_data.get("recruitment_reward", {})
	if not _recruitment_bonuses.has(player_id):
		_recruitment_bonuses[player_id] = _default_bonuses()

	# Production bonuses
	if reward.has("iron_per_turn_bonus"):
		_recruitment_bonuses[player_id]["iron_per_turn_bonus"] += reward["iron_per_turn_bonus"]
		EventBus.message_log.emit("全局铁矿产出 +%d%%!" % int(reward["iron_per_turn_bonus"] * 100))
	if reward.has("iron_flat_per_turn"):
		_recruitment_bonuses[player_id]["iron_flat_per_turn"] += reward["iron_flat_per_turn"]
		EventBus.message_log.emit("据点铁矿 +%d/回合!" % reward["iron_flat_per_turn"])
	if reward.has("gold_per_turn"):
		_recruitment_bonuses[player_id]["gold_per_turn"] += reward["gold_per_turn"]
		EventBus.message_log.emit("每回合额外 +%d 金币!" % reward["gold_per_turn"])
	if reward.has("gunpowder_per_turn"):
		_recruitment_bonuses[player_id]["gunpowder_per_turn"] += reward["gunpowder_per_turn"]
		EventBus.message_log.emit("每回合额外 +%d 火药!" % reward["gunpowder_per_turn"])

	# Permanent ATK bonus (Blood Moon)
	if reward.has("atk_bonus_permanent"):
		_recruitment_bonuses[player_id]["atk_bonus"] += reward["atk_bonus_permanent"]
		EventBus.message_log.emit("全军攻击永久+%d!" % reward["atk_bonus_permanent"])

	# Victory prestige (Blood Moon: +1 prestige per combat win)
	if reward.has("victory_prestige"):
		_recruitment_bonuses[player_id]["victory_prestige"] += reward["victory_prestige"]
		EventBus.message_log.emit("每次战斗胜利+%d威望!" % reward["victory_prestige"])

	# Vision bonus (Forest Ranger)
	if reward.has("vision_bonus"):
		_recruitment_bonuses[player_id]["vision_bonus"] += reward["vision_bonus"]
		EventBus.message_log.emit("视野+%d格!" % reward["vision_bonus"])

	# Unique unit unlock
	if reward.has("unique_unit"):
		var unit_data: Dictionary = reward["unique_unit"]
		var unit_name: String = unit_data.get("name", "")
		var unit_special: String = unit_data.get("special", "")
		if not _unlocked_units.has(player_id):
			_unlocked_units[player_id] = []
		_unlocked_units[player_id].append(unit_special)
		EventBus.message_log.emit("[color=yellow]解锁专属单位: %s![/color]" % unit_name)

	# Abilities
	if reward.has("abilities"):
		for ability in reward["abilities"]:
			EventBus.message_log.emit("解锁能力: %s" % ability)


func get_recruitment_bonuses(player_id: int) -> Dictionary:
	return _recruitment_bonuses.get(player_id, _default_bonuses())


# ═══════════════ TAMING SYSTEM (v1.2) ═══════════════

func _resolve_faction_id(nf_id_or_tag) -> int:
	## Accepts either an int (NeutralFaction enum) or a String tag.
	## Returns the int faction ID, or -1 if unresolvable.
	if nf_id_or_tag is int:
		return nf_id_or_tag
	if nf_id_or_tag is String:
		return _FACTION_TAG_TO_ID.get(nf_id_or_tag, -1)
	return -1


func _resolve_faction_tag(nf_id) -> String:
	## Convert a faction enum int (or string tag) to its string tag.
	if nf_id is String:
		return nf_id  # already a tag
	return _FACTION_ID_TO_TAG.get(nf_id, "")


func _get_faction_name(ftag: String) -> String:
	## Get display name from a string tag.
	var fid: int = _FACTION_TAG_TO_ID.get(ftag, -1)
	if fid >= 0:
		return FactionData.NEUTRAL_FACTION_NAMES.get(fid, ftag)
	return ftag


func get_taming_level(player_id: int, nf_id_or_tag) -> int:
	## Returns the taming level (0-10) for a neutral faction.
	## Taming increases when quest steps advance (+3 per step, +1 bonus on completion = max 10).
	var fid: int = _resolve_faction_id(nf_id_or_tag)
	if fid < 0:
		return 0
	if not _taming_levels.has(player_id):
		return 0
	if _taming_levels[player_id].has(fid):
		return _taming_levels[player_id][fid]
	# Derive from quest step if taming was never explicitly set
	var step: int = get_quest_step(player_id, fid)
	var recruited: bool = is_faction_recruited(player_id, fid)
	if recruited:
		return 10
	return clampi(step * 3, 0, 9)


func set_taming_level(player_id: int, nf_id_or_tag, value: int) -> void:
	var fid: int = _resolve_faction_id(nf_id_or_tag)
	if fid < 0:
		return
	if not _taming_levels.has(player_id):
		_taming_levels[player_id] = {}
	_taming_levels[player_id][fid] = clampi(value, 0, 10)
	EventBus.taming_changed.emit(player_id, _resolve_faction_tag(fid), value)


func get_taming_tier(player_id: int, nf_id_or_tag) -> String:
	## Returns a tier label based on taming level:
	## 0-1 = hostile, 2-4 = neutral, 5-6 = friendly, 7-8 = allied, 9-10 = tamed
	var level: int = get_taming_level(player_id, nf_id_or_tag)
	if level <= 1:
		return "hostile"
	elif level <= 4:
		return "neutral"
	elif level <= 6:
		return "friendly"
	elif level <= 8:
		return "allied"
	else:
		return "tamed"


func get_all_unlocked_neutral_troops(player_id: int) -> Array:
	## Returns all troop IDs unlocked from ALL recruited neutral factions.
	## Called by RecruitManager to add neutral troops to the recruit list.
	var result: Array = []
	var recruited: Array = get_recruited_factions(player_id)
	for nf_id in recruited:
		result.append_array(get_unlocked_neutral_troops(player_id, nf_id))
	return result


func get_unlocked_neutral_troops(player_id: int, nf_id_or_tag) -> Array:
	## Returns array of troop IDs unlocked by recruiting this neutral faction.
	var fid: int = _resolve_faction_id(nf_id_or_tag)
	if fid < 0:
		return []
	if not is_faction_recruited(player_id, fid):
		return []
	var fd: Dictionary = FactionData.NEUTRAL_FACTION_DATA.get(fid, {})
	var reward: Dictionary = fd.get("recruitment_reward", {})
	var result: Array = []
	if reward.has("unique_unit"):
		var unit_data: Dictionary = reward["unique_unit"]
		var special: String = unit_data.get("special", "")
		if special != "":
			result.append(special)
		var unit_name: String = unit_data.get("name", "")
		if unit_name != "" and unit_name != special:
			result.append(unit_name)
	return result


func tick_turn(player_id: int) -> void:
	## Called per turn from game_manager. Wraps process_turn + taming decay for neglected factions.
	process_turn(player_id)
	# Taming decay: factions with active (non-completed) quests that player hasn't interacted with
	# lose 1 taming point every 5 turns (handled by checking quest step staleness)
	# For now this is a no-op placeholder — can be expanded later.


func get_all_quest_status(player_id: int) -> Array:
	## Returns array of quest status for UI display.
	var result: Array = []
	for nf in FactionData.NEUTRAL_FACTION_DATA:
		var step: int = get_quest_step(player_id, nf)
		var recruited: bool = is_faction_recruited(player_id, nf)
		var fname: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf, "未知")
		var fd: Dictionary = FactionData.NEUTRAL_FACTION_DATA[nf]
		var leader: String = fd.get("leader_name", "")
		var quest_chain: Array = fd.get("quest_chain", [])
		var current_task: String = ""
		if step >= 1 and step <= quest_chain.size() and not recruited:
			current_task = quest_chain[step - 1].get("task", "")
		result.append({
			"faction_id": nf,
			"name": fname,
			"leader": leader,
			"step": step,
			"max_steps": 3,
			"recruited": recruited,
			"current_task": current_task,
		})
	return result


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"quest_progress": _quest_progress.duplicate(true),
		"recruited_factions": _recruited_factions.duplicate(true),
		"recruitment_bonuses": _recruitment_bonuses.duplicate(true),
		"unlocked_units": _unlocked_units.duplicate(true),
		"pending_quest_combat": _pending_quest_combat.duplicate(true),
		"caravan_item_timer": _caravan_item_timer.duplicate(true),
		"taming_levels": _taming_levels.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_quest_progress = data.get("quest_progress", {}).duplicate(true)
	_recruited_factions = data.get("recruited_factions", {}).duplicate(true)
	_recruitment_bonuses = data.get("recruitment_bonuses", {}).duplicate(true)
	_unlocked_units = data.get("unlocked_units", {}).duplicate(true)
	_pending_quest_combat = data.get("pending_quest_combat", {}).duplicate(true)
	_caravan_item_timer = data.get("caravan_item_timer", {}).duplicate(true)
	_taming_levels = data.get("taming_levels", {}).duplicate(true)
