## ai_scaling.gd - AI combat scaling via threat tiers (v4.0)
## AI factions do NOT use training/research. Their stats scale with threat value.
## Each AI faction has independent threat tracking.
## v4.0: Bonus units, tactical directives, commander interventions, counter-composition.
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")
const TrainingData = preload("res://systems/faction/training_data.gd")

# ── Signals ──
signal ai_tier_changed(faction_key: String, old_tier: int, new_tier: int)
signal expedition_spawned(faction_key: String, tile_index: int)
signal boss_spawned(faction_key: String, tile_index: int)

# ── Per-faction threat state ──
# Keys: "human", "elf", "mage", "orc_ai", "pirate_ai", "dark_elf_ai"
var _faction_threat: Dictionary = {}  # faction_key -> int (0-100)
var _faction_tier: Dictionary = {}     # faction_key -> int (0-3)
var _expedition_cd: Dictionary = {}    # faction_key -> int (turns remaining)
var _boss_cd: Dictionary = {}          # faction_key -> int (turns remaining)

# All possible AI faction keys
const AI_FACTION_KEYS: Array = ["human", "elf", "mage", "orc_ai", "pirate_ai", "dark_elf_ai"]

# Tier thresholds (same as ThreatManager)
const TIER_THRESHOLDS: Array = [0, 30, 60, 80]

# ── AI Personality Types ──
enum Personality { AGGRESSIVE, DEFENSIVE, ECONOMIC, DIPLOMATIC }

const FACTION_PERSONALITY: Dictionary = {
	"human": Personality.DEFENSIVE,
	"elf": Personality.ECONOMIC,
	"mage": Personality.DIPLOMATIC,
	"orc_ai": Personality.AGGRESSIVE,
	"pirate_ai": Personality.ECONOMIC,
	"dark_elf_ai": Personality.AGGRESSIVE,
}

# Modifier axes per personality
const PERSONALITY_MODS: Dictionary = {
	Personality.AGGRESSIVE: {
		"raid_chance_mult": 2.0,
		"garrison_priority": 0.8,
		"expedition_cd_mult": 0.7,
		"peace_acceptance": 0.5,
		"threat_decay_mult": 0.7,
		"reinforce_mult": 1.0,
	},
	Personality.DEFENSIVE: {
		"raid_chance_mult": 0.5,
		"garrison_priority": 1.5,
		"expedition_cd_mult": 1.2,
		"peace_acceptance": 1.0,
		"threat_decay_mult": 1.0,
		"reinforce_mult": 1.3,
	},
	Personality.ECONOMIC: {
		"raid_chance_mult": 0.8,
		"garrison_priority": 1.0,
		"expedition_cd_mult": 1.0,
		"peace_acceptance": 1.2,
		"threat_decay_mult": 1.3,
		"reinforce_mult": 1.0,
	},
	Personality.DIPLOMATIC: {
		"raid_chance_mult": 0.3,
		"garrison_priority": 1.0,
		"expedition_cd_mult": 1.5,
		"peace_acceptance": 1.5,
		"threat_decay_mult": 1.5,
		"reinforce_mult": 0.8,
	},
}

const PERSONALITY_NAMES: Dictionary = {
	Personality.AGGRESSIVE: "好战",
	Personality.DEFENSIVE: "防守",
	Personality.ECONOMIC: "经济",
	Personality.DIPLOMATIC: "外交",
}


func _ready() -> void:
	pass


func reset() -> void:
	_faction_threat.clear()
	_faction_tier.clear()
	_expedition_cd.clear()
	_boss_cd.clear()
	for key in AI_FACTION_KEYS:
		_faction_threat[key] = 0
		_faction_tier[key] = 0
		_expedition_cd[key] = 0
		_boss_cd[key] = 0


# ═══════════════ INITIALIZATION ═══════════════

func init_for_game(player_faction_id: int) -> void:
	## Call at game start. Sets up tracking for all non-player factions.
	reset()
	# Validate faction_id before proceeding
	var player_key: String = _faction_id_to_ai_key(player_faction_id)
	if player_key == "":
		push_warning("ai_scaling: invalid player_faction_id %d — no matching AI key, skipping removal" % player_faction_id)
		return
	# 收集需要删除的key，避免迭代中修改字典
	var keys_to_erase: Array = []
	if _faction_threat.has(player_key):
		keys_to_erase.append(player_key)
	for key in keys_to_erase:
		_faction_threat.erase(key)
		_faction_tier.erase(key)
		_expedition_cd.erase(key)
		_boss_cd.erase(key)


# ═══════════════ THREAT MANAGEMENT ═══════════════

func get_threat(faction_key: String) -> int:
	return _faction_threat.get(faction_key, 0)


func get_tier(faction_key: String) -> int:
	return _faction_tier.get(faction_key, 0)


func get_tier_name(faction_key: String) -> String:
	var tier: int = get_tier(faction_key)
	var scaling: Dictionary = TrainingData.AI_THREAT_SCALING
	if scaling.has("tiers") and scaling["tiers"].has(tier):
		return scaling["tiers"][tier]["name"]
	return "未知"


func change_threat(faction_key: String, delta: int) -> void:
	if not _faction_threat.has(faction_key):
		return
	var old_val: int = _faction_threat[faction_key]
	_faction_threat[faction_key] = clampi(old_val + delta, 0, 100)
	var new_val: int = _faction_threat[faction_key]
	if new_val == old_val:
		return

	var old_tier: int = _faction_tier[faction_key]
	var new_tier: int = _calc_tier(new_val)
	_faction_tier[faction_key] = new_tier

	EventBus.message_log.emit("[%s] 威胁值: %d → %d" % [faction_key, old_val, new_val])
	if new_tier != old_tier:
		var tier_name: String = get_tier_name(faction_key)
		EventBus.message_log.emit("[color=orange][%s] 威胁阶梯变更: %s (Tier %d)[/color]" % [faction_key, tier_name, new_tier])
		ai_tier_changed.emit(faction_key, old_tier, new_tier)
	EventBus.ai_threat_changed.emit(faction_key, new_val, new_tier)


func _calc_tier(threat_val: int) -> int:
	if threat_val >= 80:
		return 3
	elif threat_val >= 60:
		return 2
	elif threat_val >= 30:
		return 1
	else:
		return 0


# ═══════════════ STAT QUERIES (for combat system) ═══════════════

func get_stat_multipliers(faction_key: String) -> Dictionary:
	## Returns {"atk_mult": float, "def_mult": float, "hp_mult": float} for an AI faction.
	var tier: int = get_tier(faction_key)
	var scaling: Dictionary = TrainingData.AI_THREAT_SCALING
	if scaling.has("tiers") and scaling["tiers"].has(tier):
		return scaling["tiers"][tier]
	return {"atk_mult": 1.0, "def_mult": 1.0, "hp_mult": 1.0}


func get_atk_multiplier(faction_key: String) -> float:
	return get_stat_multipliers(faction_key).get("atk_mult", 1.0) * NgPlusManager.get_ai_stat_mult()


func get_def_multiplier(faction_key: String) -> float:
	return get_stat_multipliers(faction_key).get("def_mult", 1.0) * NgPlusManager.get_ai_stat_mult()


func get_hp_multiplier(faction_key: String) -> float:
	# BUG FIX: apply NG+ scaling to HP like ATK/DEF
	return get_stat_multipliers(faction_key).get("hp_mult", 1.0) * NgPlusManager.get_ai_stat_mult()


func get_garrison_regen_bonus(faction_key: String) -> int:
	return get_stat_multipliers(faction_key).get("garrison_regen_bonus", 0)


func get_wall_bonus(faction_key: String) -> float:
	return get_stat_multipliers(faction_key).get("wall_bonus", 0.0)


# ═══════════════ v4.0: TIER-BASED BONUS UNITS ═══════════════

## At higher tiers, AI gets bonus garrison units instead of just stat multipliers.
## This makes AI stronger through NUMBERS not just inflated stats.
const TIER_BONUS_GARRISON: Dictionary = {
	0: 0,   # Tier 0: no bonus
	1: 2,   # Tier 1: +2 bonus garrison on border tiles per turn
	2: 4,   # Tier 2: +4
	3: 7,   # Tier 3: +7
}

func get_tier_bonus_garrison(faction_key: String) -> int:
	## Returns bonus garrison units per turn for border tiles at this threat tier.
	var tier: int = get_tier(faction_key)
	return TIER_BONUS_GARRISON.get(tier, 0)


func apply_tier_bonus_garrison(faction_key: String) -> void:
	## Apply bonus garrison to border tiles based on threat tier.
	## v5.1: Also applies ai_reinforce_mult from difficulty preset.
	var bonus: int = get_tier_bonus_garrison(faction_key)
	if bonus <= 0:
		return
	# v5.1: Scale reinforcement by difficulty preset multiplier
	if BalanceManager != null and BalanceManager.has_method("get_ai_reinforce_mult"):
		var reinforce_mult: float = BalanceManager.get_ai_reinforce_mult()
		bonus = maxi(1, int(float(bonus) * reinforce_mult))
	var applied: int = 0
	for tile in GameManager.tiles:
		if tile["owner_id"] >= 0:
			continue
		if not _tile_belongs_to_faction(tile, faction_key):
			continue
		# Only apply to border tiles (adjacent to player territory)
		var on_border: bool = false
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] >= 0:
					on_border = true
					break
		if on_border:
			tile["garrison"] += bonus
			applied += 1
	if applied > 0 and bonus >= 4:
		EventBus.message_log.emit("[color=orange][%s] 高威胁等级增援: %d个前线据点各+%d驻军[/color]" % [faction_key, applied, bonus])


# ═══════════════ v4.0: TACTICAL DIRECTIVE ACCESS ═══════════════

## At higher tiers, AI gains access to better tactical directives.
## Tier 0: NONE only
## Tier 1: HOLD_LINE, FOCUS_FIRE
## Tier 2: + ALL_OUT, GUERRILLA
## Tier 3: + AMBUSH (all directives)

const TIER_AVAILABLE_DIRECTIVES: Dictionary = {
	0: [],
	1: [2, 4],       # HOLD_LINE=2, FOCUS_FIRE=4
	2: [1, 2, 3, 4], # + ALL_OUT=1, GUERRILLA=3
	3: [1, 2, 3, 4, 5],  # + AMBUSH=5
}

func get_available_directives(faction_key: String) -> Array:
	## Returns array of TacticalDirective enum values available at current tier.
	var tier: int = get_tier(faction_key)
	return TIER_AVAILABLE_DIRECTIVES.get(tier, [])


func can_use_directive(faction_key: String, directive: int) -> bool:
	## Check if a faction can use a specific tactical directive at their current tier.
	if directive == 0:  # NONE is always available
		return true
	return directive in get_available_directives(faction_key)


# ═══════════════ v4.0: AI COMMANDER INTERVENTIONS ═══════════════

## At Tier 2+, AI can use Commander Interventions during combat with reduced CP.
const AI_INTERVENTION_CP: Dictionary = {
	2: 2,  # Tier 2: 2 CP budget
	3: 4,  # Tier 3: 4 CP budget
}

## Interventions the AI will prioritize by personality
const AI_INTERVENTION_PRIORITY: Dictionary = {
	Personality.AGGRESSIVE: [
		CommanderIntervention.InterventionType.INSPIRE,
		CommanderIntervention.InterventionType.REDIRECT_FIRE,
		CommanderIntervention.InterventionType.FOCUS_VOLLEY,
		CommanderIntervention.InterventionType.SACRIFICE_PAWN,
	],
	Personality.DEFENSIVE: [
		CommanderIntervention.InterventionType.SHIELD_WALL,
		CommanderIntervention.InterventionType.RALLY,
		CommanderIntervention.InterventionType.BAIT_AND_SWITCH,
		CommanderIntervention.InterventionType.TACTICAL_RETREAT,
	],
	Personality.ECONOMIC: [
		CommanderIntervention.InterventionType.FOCUS_VOLLEY,
		CommanderIntervention.InterventionType.REDIRECT_FIRE,
		CommanderIntervention.InterventionType.SHIELD_WALL,
		CommanderIntervention.InterventionType.TACTICAL_RETREAT,
	],
	Personality.DIPLOMATIC: [
		CommanderIntervention.InterventionType.BAIT_AND_SWITCH,
		CommanderIntervention.InterventionType.RALLY,
		CommanderIntervention.InterventionType.SHIELD_WALL,
		CommanderIntervention.InterventionType.TACTICAL_RETREAT,
	],
}

func get_ai_intervention_cp(faction_key: String) -> int:
	## Returns how many CP the AI gets for commander interventions.
	var tier: int = get_tier(faction_key)
	return AI_INTERVENTION_CP.get(tier, 0)


func get_ai_intervention_priorities(faction_key: String) -> Array:
	## Returns ordered list of intervention types the AI should try.
	var personality: int = get_personality(faction_key)
	return AI_INTERVENTION_PRIORITY.get(personality, [])


func can_use_interventions(faction_key: String) -> bool:
	## Returns true if this AI faction can use commander interventions.
	return get_tier(faction_key) >= 2


# ═══════════════ v4.0: COUNTER-COMPOSITION ═══════════════

## At Tier 3, AI can analyze player army and build counter-compositions.
## This changes the defender army composition metadata attached to tiles.

func should_use_counter_composition(faction_key: String) -> bool:
	## Tier 3 AI uses counter-composition against the player.
	return get_tier(faction_key) >= 3


func get_counter_army_types(faction_key: String) -> Array:
	## Returns unit types that counter the player's recent army composition.
	## Delegates to AIStrategicPlanner for the actual analysis.
	if not should_use_counter_composition(faction_key):
		return []
	var faction_id: int = _ai_key_to_faction_id(faction_key)
	if faction_id < 0:
		return []
	return AIStrategicPlanner.get_counter_composition(faction_key, faction_id)


func _ai_key_to_faction_id(ai_key: String) -> int:
	match ai_key:
		"orc_ai": return FactionData.FactionID.ORC
		"pirate_ai": return FactionData.FactionID.PIRATE
		"dark_elf_ai": return FactionData.FactionID.DARK_ELF
	return -1


# ═══════════════ PASSIVE & ULTIMATE QUERIES ═══════════════

func has_tier2_passive(faction_key: String) -> bool:
	return get_tier(faction_key) >= 2


func get_tier2_passive(faction_key: String) -> Dictionary:
	if not has_tier2_passive(faction_key):
		return {}
	var scaling: Dictionary = TrainingData.AI_THREAT_SCALING
	if scaling.has("tier2_passives") and scaling["tier2_passives"].has(faction_key):
		return scaling["tier2_passives"][faction_key]
	return {}


func has_tier3_ultimate(faction_key: String) -> bool:
	return get_tier(faction_key) >= 3


func get_tier3_ultimate(faction_key: String) -> Dictionary:
	if not has_tier3_ultimate(faction_key):
		return {}
	var scaling: Dictionary = TrainingData.AI_THREAT_SCALING
	if scaling.has("tier3_ultimates") and scaling["tier3_ultimates"].has(faction_key):
		return scaling["tier3_ultimates"][faction_key]
	return {}


# ═══════════════ TURN PROCESSING ═══════════════

func process_turn() -> void:
	## Called once per turn. Handles threat decay, expedition/boss spawns, and tier bonuses.
	for faction_key in _faction_threat:
		# Natural decay: -1 per turn
		if _faction_threat[faction_key] > 0:
			var decay_mult: float = get_personality_mod(faction_key, "threat_decay_mult")
			var decay: int = maxi(1, int(1.0 * decay_mult))
			change_threat(faction_key, -decay)

		var tier: int = get_tier(faction_key)

		# v4.0: Apply tier-based bonus garrison to border tiles
		apply_tier_bonus_garrison(faction_key)

		# Expedition spawn check
		var exp_data: Dictionary = TrainingData.AI_THREAT_SCALING.get("expedition", {})
		if tier >= exp_data.get("min_tier", 2):
			if _expedition_cd.get(faction_key, 0) <= 0:
				_try_spawn_expedition(faction_key)
				var base_cd: int = exp_data.get("interval_turns", 3)
				_expedition_cd[faction_key] = maxi(1, int(float(base_cd) * get_personality_mod(faction_key, "expedition_cd_mult")))
			else:
				_expedition_cd[faction_key] -= 1

		# Boss spawn check
		var boss_data: Dictionary = TrainingData.AI_THREAT_SCALING.get("boss", {})
		if tier >= boss_data.get("min_tier", 3):
			if _boss_cd.get(faction_key, 0) <= 0:
				_try_spawn_boss(faction_key)
				_boss_cd[faction_key] = boss_data.get("interval_turns", 5)
			else:
				_boss_cd[faction_key] -= 1


func _try_spawn_expedition(faction_key: String) -> void:
	## Attempt to spawn an expedition army for the given AI faction.
	## v4.0: Uses strategic planner to place expedition at predicted attack point.
	var exp_data: Dictionary = TrainingData.AI_THREAT_SCALING.get("expedition", {})
	var count_range: Array = exp_data.get("unit_count_range", [3, 5])
	var unit_count: int = randi_range(count_range[0], count_range[1])

	# v4.0: Tier bonus units for expeditions
	var tier: int = get_tier(faction_key)
	unit_count += tier  # +1/2/3 bonus units at tier 1/2/3

	# v4.0: Try to place at the predicted player attack point first
	var predicted_target: int = AIStrategicPlanner.predict_player_next_target(faction_key)
	var target_tile_idx: int = predicted_target if predicted_target >= 0 else _find_ai_border_tile(faction_key)
	if target_tile_idx < 0:
		target_tile_idx = _find_ai_border_tile(faction_key)
	if target_tile_idx < 0:
		return

	# Add garrison as the expedition
	if target_tile_idx < GameManager.tiles.size():
		GameManager.tiles[target_tile_idx]["garrison"] += unit_count
		var strategic_note: String = " (战略部署)" if predicted_target >= 0 else ""
		EventBus.message_log.emit("[color=red][%s] 远征军出动! +%d 兵力 → 据点#%d%s[/color]" % [faction_key, unit_count, target_tile_idx, strategic_note])
		expedition_spawned.emit(faction_key, target_tile_idx)


func _try_spawn_boss(faction_key: String) -> void:
	## Spawn a boss unit at one of this faction's key tiles.
	var target_tile_idx: int = _find_ai_fortress_tile(faction_key)
	if target_tile_idx < 0:
		target_tile_idx = _find_ai_border_tile(faction_key)
	if target_tile_idx < 0:
		return

	var boss_data: Dictionary = TrainingData.AI_THREAT_SCALING.get("boss", {})
	var boss_garrison: int = int(15 * boss_data.get("hp_mult", 3.0))

	if target_tile_idx < GameManager.tiles.size():
		GameManager.tiles[target_tile_idx]["garrison"] += boss_garrison
		GameManager.tiles[target_tile_idx]["has_boss"] = true
		EventBus.message_log.emit("[color=red][%s] Boss级单位出现! +%d 兵力 → 据点#%d[/color]" % [faction_key, boss_garrison, target_tile_idx])
		boss_spawned.emit(faction_key, target_tile_idx)


func _find_ai_border_tile(faction_key: String) -> int:
	## Find a tile owned by this AI faction that borders player territory.
	var candidates: Array = []
	for tile in GameManager.tiles:
		if tile["owner_id"] >= 0:
			continue  # Player-owned
		if not _tile_belongs_to_faction(tile, faction_key):
			continue
		# Check adjacency to player tiles
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] >= 0:
					candidates.append(tile["index"])
					break
	if candidates.is_empty():
		# Fallback: any tile of this faction
		for tile in GameManager.tiles:
			if tile["owner_id"] < 0 and _tile_belongs_to_faction(tile, faction_key):
				return tile["index"]
		return -1
	return candidates[randi() % candidates.size()]


func _find_ai_fortress_tile(faction_key: String) -> int:
	## Find a fortress tile for this AI faction.
	for tile in GameManager.tiles:
		if tile["owner_id"] >= 0:
			continue
		if tile.get("type", -1) == GameManager.TileType.CORE_FORTRESS:
			if _tile_belongs_to_faction(tile, faction_key):
				return tile["index"]
	return -1


func _tile_belongs_to_faction(tile: Dictionary, faction_key: String) -> bool:
	## Check if a tile belongs to the given AI faction.
	match faction_key:
		"human":
			return tile.get("light_faction", -1) == FactionData.LightFaction.HUMAN_KINGDOM
		"elf":
			return tile.get("light_faction", -1) == FactionData.LightFaction.HIGH_ELVES
		"mage":
			return tile.get("light_faction", -1) == FactionData.LightFaction.MAGE_TOWER
		"orc_ai":
			return tile.get("original_faction", -1) == FactionData.FactionID.ORC
		"pirate_ai":
			return tile.get("original_faction", -1) == FactionData.FactionID.PIRATE
		"dark_elf_ai":
			return tile.get("original_faction", -1) == FactionData.FactionID.DARK_ELF
	return false


# ═══════════════ THREAT TRIGGERS ═══════════════

func on_tile_captured(faction_key: String) -> void:
	change_threat(faction_key, 15)

func on_army_defeated(faction_key: String) -> void:
	change_threat(faction_key, 10)

func on_border_pressure(faction_key: String) -> void:
	change_threat(faction_key, 2)

func on_tile_recaptured(faction_key: String) -> void:
	change_threat(faction_key, -10)

func on_treaty_signed(faction_key: String) -> void:
	change_threat(faction_key, -20)


# ═══════════════ HELPER ═══════════════

func _faction_id_to_ai_key(faction_id: int) -> String:
	match faction_id:
		FactionData.FactionID.ORC: return "orc_ai"
		FactionData.FactionID.PIRATE: return "pirate_ai"
		FactionData.FactionID.DARK_ELF: return "dark_elf_ai"
	return ""


func get_all_ai_factions() -> Array:
	## Returns all currently tracked AI faction keys.
	return _faction_threat.keys()


# ═══════════════ PERSONALITY QUERIES ═══════════════

func get_personality(faction_key: String) -> int:
	return FACTION_PERSONALITY.get(faction_key, Personality.DEFENSIVE)


func get_personality_name(faction_key: String) -> String:
	var p: int = get_personality(faction_key)
	return PERSONALITY_NAMES.get(p, "未知")


func get_personality_mod(faction_key: String, mod_key: String) -> float:
	var p: int = get_personality(faction_key)
	var mods: Dictionary = PERSONALITY_MODS.get(p, {})
	return mods.get(mod_key, 1.0)


func get_all_personality_mods(faction_key: String) -> Dictionary:
	var p: int = get_personality(faction_key)
	return PERSONALITY_MODS.get(p, {}).duplicate()


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"faction_threat": _faction_threat.duplicate(),
		"faction_tier": _faction_tier.duplicate(),
		"expedition_cd": _expedition_cd.duplicate(),
		"boss_cd": _boss_cd.duplicate(),
	}


func from_save_data(data: Dictionary) -> void:
	_faction_threat = data.get("faction_threat", {}).duplicate()
	_faction_tier = data.get("faction_tier", {}).duplicate()
	_expedition_cd = data.get("expedition_cd", {}).duplicate()
	_boss_cd = data.get("boss_cd", {}).duplicate()
