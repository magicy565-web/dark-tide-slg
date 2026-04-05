## ai_strategic_planner.gd - Strategic AI decision layer (v4.0)
## Provides intelligent decision-making for all AI factions.
## Tracks player behavior, adapts strategies, and coordinates multi-faction actions.
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")
const CounterMatrix = preload("res://systems/combat/counter_matrix.gd")
const TroopRegistry = preload("res://systems/combat/troop_registry.gd")

# ── Strategic Decisions ──
enum Strategy { EXPAND, DEFEND, RAID, CONSOLIDATE, DIPLOMATIZE }

const STRATEGY_NAMES: Dictionary = {
	Strategy.EXPAND: "扩张",
	Strategy.DEFEND: "防御",
	Strategy.RAID: "袭扰",
	Strategy.CONSOLIDATE: "巩固",
	Strategy.DIPLOMATIZE: "外交",
}

# ── Memory System ──
const MEMORY_MAX_TURNS: int = 5

# Player action tracking per faction
var _player_memory: Dictionary = {}  # faction_key -> PlayerMemory dict
# Current strategy per faction
var _faction_strategy: Dictionary = {}  # faction_key -> Strategy enum
# Coordination state for multi-faction attacks
var _coordinated_target: int = -1  # tile index for coordinated assault
var _coordination_cooldown: int = 0

# ── Advanced Tactical Intelligence ──
var _pending_feints: Dictionary = {}           # faction_key -> feint plan Dictionary
var _concentration_plans: Dictionary = {}      # faction_key -> concentration plan Dictionary
var _stall_counters: Dictionary = {}           # faction_key -> int (turns since last capture)
var _diversion_results: Dictionary = {}        # faction_key -> {successes: int, failures: int}
var _feint_results: Dictionary = {}            # faction_key -> {successes: int, failures: int}
var _last_tile_counts: Dictionary = {}         # faction_key -> int (tile count last turn)

# ── Personality weights for strategy selection ──
# Each personality type has base weights for each strategy
const STRATEGY_WEIGHTS: Dictionary = {
	AIScaling.Personality.AGGRESSIVE: {
		Strategy.EXPAND: 0.35, Strategy.DEFEND: 0.10,
		Strategy.RAID: 0.35, Strategy.CONSOLIDATE: 0.05,
		Strategy.DIPLOMATIZE: 0.05,
	},
	AIScaling.Personality.DEFENSIVE: {
		Strategy.EXPAND: 0.10, Strategy.DEFEND: 0.40,
		Strategy.RAID: 0.10, Strategy.CONSOLIDATE: 0.30,
		Strategy.DIPLOMATIZE: 0.10,
	},
	AIScaling.Personality.ECONOMIC: {
		Strategy.EXPAND: 0.15, Strategy.DEFEND: 0.15,
		Strategy.RAID: 0.30, Strategy.CONSOLIDATE: 0.20,
		Strategy.DIPLOMATIZE: 0.20,
	},
	AIScaling.Personality.DIPLOMATIC: {
		Strategy.EXPAND: 0.10, Strategy.DEFEND: 0.15,
		Strategy.RAID: 0.10, Strategy.CONSOLIDATE: 0.20,
		Strategy.DIPLOMATIZE: 0.45,
	},
}

# ── Counter-composition mapping ──
# Maps base archetype to what counters it effectively
const COUNTER_PICKS: Dictionary = {
	"infantry": ["cavalry", "berserker"],
	"heavy_infantry": ["mage", "assassin"],
	"cavalry": ["heavy_infantry", "tank"],
	"archer": ["cavalry", "assassin"],
	"gunner": ["cavalry"],
	"mage": ["assassin", "cavalry"],
	"assassin": ["tank", "heavy_infantry"],
	"berserker": ["heavy_infantry", "tank"],
	"artillery": ["cavalry", "assassin"],
	"tank": ["mage", "artillery"],
	"priest": ["assassin"],
}

# Maps base archetype to faction unit_type keys that have it
const ARCHETYPE_TO_UNITS: Dictionary = {
	"infantry": ["orc_ashigaru", "pirate_ashigaru", "de_samurai"],
	"heavy_infantry": ["human_samurai"],
	"cavalry": ["orc_cavalry", "de_cavalry"],
	"berserker": ["orc_samurai"],
	"gunner": ["pirate_archer"],
	"mage": ["elf_mage", "mage_apprentice"],
	"assassin": ["de_ninja"],
	"artillery": ["pirate_cannon"],
	"tank": ["elf_ashigaru"],
}


func _ready() -> void:
	pass


func reset() -> void:
	_player_memory.clear()
	_faction_strategy.clear()
	_coordinated_target = -1
	_coordination_cooldown = 0
	_pending_feints.clear()
	_concentration_plans.clear()
	_stall_counters.clear()
	_diversion_results.clear()
	_feint_results.clear()
	_last_tile_counts.clear()


# ═══════════════ MEMORY SYSTEM ═══════════════

func _get_memory(faction_key: String) -> Dictionary:
	if not _player_memory.has(faction_key):
		_player_memory[faction_key] = {
			"attack_targets": [],        # last N tile indices player attacked
			"army_archetypes": [],       # last N dominant archetypes in player army
			"buildup_tiles": [],         # tiles player is reinforcing
			"player_strength_trend": 0,  # positive = growing, negative = weakening
			"last_player_garrison_total": 0,
		}
	return _player_memory[faction_key]


func record_player_attack(faction_key: String, tile_index: int) -> void:
	## Call when player attacks a tile belonging to this faction.
	var mem: Dictionary = _get_memory(faction_key)
	mem["attack_targets"].append(tile_index)
	if mem["attack_targets"].size() > MEMORY_MAX_TURNS:
		mem["attack_targets"].pop_front()


func record_player_army_composition(faction_key: String, army: Array) -> void:
	## Call before combat to track player's troop types.
	var mem: Dictionary = _get_memory(faction_key)
	var archetype_counts: Dictionary = {}
	for unit in army:
		var unit_type: String = unit.get("troop_id", unit.get("unit_type", ""))
		var base: String = CounterMatrix.TYPE_MAP.get(unit_type, "infantry")
		archetype_counts[base] = archetype_counts.get(base, 0) + 1
	# Find dominant archetype
	var dominant: String = "infantry"
	var max_count: int = 0
	for arch in archetype_counts:
		if archetype_counts[arch] > max_count:
			max_count = archetype_counts[arch]
			dominant = arch
	mem["army_archetypes"].append(dominant)
	if mem["army_archetypes"].size() > MEMORY_MAX_TURNS:
		mem["army_archetypes"].pop_front()


func record_player_buildup(faction_key: String) -> void:
	## Scan player tiles near this faction and track garrison buildup.
	var mem: Dictionary = _get_memory(faction_key)
	var buildup: Array = []
	var total_garrison: int = 0
	for tile in GameManager.tiles:
		if tile["owner_id"] < 0:
			continue
		total_garrison += tile.get("garrison", 0)
		# Check if near this faction's territory
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size():
					var nb: Dictionary = GameManager.tiles[nb_idx]
					if nb["owner_id"] < 0 and AIScaling._tile_belongs_to_faction(nb, faction_key):
						if tile.get("garrison", 0) >= 5:
							buildup.append(tile["index"])
						break
	mem["buildup_tiles"] = buildup
	# Track strength trend
	var prev: int = mem.get("last_player_garrison_total", 0)
	if prev > 0:
		mem["player_strength_trend"] = total_garrison - prev
	mem["last_player_garrison_total"] = total_garrison


func get_player_dominant_archetype(faction_key: String) -> String:
	## Returns the most common archetype the player has used recently.
	var mem: Dictionary = _get_memory(faction_key)
	var archetypes: Array = mem.get("army_archetypes", [])
	if archetypes.is_empty():
		return "infantry"
	# Count frequency
	var counts: Dictionary = {}
	for arch in archetypes:
		counts[arch] = counts.get(arch, 0) + 1
	var best: String = "infantry"
	var best_count: int = 0
	for arch in counts:
		if counts[arch] > best_count:
			best_count = counts[arch]
			best = arch
	return best


func predict_player_next_target(faction_key: String) -> int:
	## Predict which tile the player will attack next based on recent attacks.
	var mem: Dictionary = _get_memory(faction_key)
	var recent: Array = mem.get("attack_targets", [])
	if recent.is_empty():
		return -1
	# Find which region (cluster of tiles) player is focused on
	# Return the most common adjacent AI tile to recent attack targets
	var adj_candidates: Dictionary = {}  # tile_index -> score
	for attacked_idx in recent:
		if not GameManager.adjacency.has(attacked_idx):
			continue
		for nb_idx in GameManager.adjacency[attacked_idx]:
			if nb_idx >= GameManager.tiles.size():
				continue
			if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
				return
			var nb: Dictionary = GameManager.tiles[nb_idx]
			if nb["owner_id"] < 0 and AIScaling._tile_belongs_to_faction(nb, faction_key):
				adj_candidates[nb_idx] = adj_candidates.get(nb_idx, 0) + 1
	if adj_candidates.is_empty():
		return -1
	var best_idx: int = -1
	var best_score: int = 0
	for idx in adj_candidates:
		if adj_candidates[idx] > best_score:
			best_score = adj_candidates[idx]
			best_idx = idx
	return best_idx


func get_player_buildup_tiles(faction_key: String) -> Array:
	var mem: Dictionary = _get_memory(faction_key)
	return mem.get("buildup_tiles", [])


# ═══════════════ STRATEGY EVALUATION ═══════════════

func evaluate_strategy(faction_key: String) -> int:
	## Evaluate the best strategy for a faction this turn. Returns Strategy enum.
	var personality: int = AIScaling.get_personality(faction_key)
	var weights: Dictionary = STRATEGY_WEIGHTS.get(personality, STRATEGY_WEIGHTS[AIScaling.Personality.DEFENSIVE]).duplicate()
	var tier: int = AIScaling.get_tier(faction_key)
	var mem: Dictionary = _get_memory(faction_key)

	# Situational modifiers
	var own_tiles: int = _count_faction_tiles(faction_key)
	var border_pressure: int = _count_border_pressure(faction_key)
	var buildup: Array = mem.get("buildup_tiles", [])

	# Heavy player buildup near us -> increase DEFEND weight
	if buildup.size() >= 3:
		weights[Strategy.DEFEND] += 0.30
		weights[Strategy.EXPAND] -= 0.10
	elif buildup.size() >= 1:
		weights[Strategy.DEFEND] += 0.15

	# Low tile count -> CONSOLIDATE
	if own_tiles <= 3:
		weights[Strategy.CONSOLIDATE] += 0.25
		weights[Strategy.EXPAND] -= 0.15

	# High tier -> more aggressive
	if tier >= 2:
		weights[Strategy.RAID] += 0.15
		weights[Strategy.EXPAND] += 0.10
	if tier >= 3:
		weights[Strategy.EXPAND] += 0.15

	# Player getting stronger -> DEFEND or RAID
	var trend: int = mem.get("player_strength_trend", 0)
	if trend > 10:
		weights[Strategy.DEFEND] += 0.10
		weights[Strategy.RAID] += 0.10
	elif trend < -5:
		weights[Strategy.EXPAND] += 0.15

	# Border pressure from player -> DEFEND
	if border_pressure >= 4:
		weights[Strategy.DEFEND] += 0.20

	# v13.0: 外交策略触发条件——当势力较弱且声望尚可时，优先选择外交
	if DiplomacyManager:
		var rep: int = DiplomacyManager.get_reputation(faction_key)
		if rep >= 40 and own_tiles <= 4:
			weights[Strategy.DIPLOMATIZE] += 0.25
			weights[Strategy.EXPAND] -= 0.10
		elif rep >= 60:
			weights[Strategy.DIPLOMATIZE] += 0.15

	# Commitment awareness: if overcommitted in sieges, favor DEFEND/CONSOLIDATE
	var commitments: Dictionary = get_active_commitments(faction_key)
	if commitments.get("overcommitted", false):
		weights[Strategy.DEFEND] += 0.30
		weights[Strategy.CONSOLIDATE] += 0.20
		weights[Strategy.EXPAND] -= 0.20
		weights[Strategy.RAID] -= 0.20
	if commitments.get("free_armies", 0) <= 0 and commitments.get("total_armies", 0) > 0:
		# All armies committed — force defensive posture
		weights[Strategy.DEFEND] += 0.40
		weights[Strategy.CONSOLIDATE] += 0.30
		weights[Strategy.EXPAND] = 0.0
		weights[Strategy.RAID] = 0.0

	# Weather awareness: apply weather multiplier to offensive strategies
	var weather_mult: float = _evaluate_weather_for_attack()
	weights[Strategy.RAID] *= weather_mult
	weights[Strategy.EXPAND] *= weather_mult
	# Harsh weather favors defending / consolidating
	if weather_mult < 0.7:
		weights[Strategy.DEFEND] += 0.20
		weights[Strategy.CONSOLIDATE] += 0.10

	# Normalize and pick weighted random
	var total: float = 0.0
	for s in weights:
		weights[s] = maxf(weights[s], 0.0)
		total += weights[s]
	if total <= 0.0:
		return Strategy.DEFEND

	var roll: float = randf() * total
	var cumulative: float = 0.0
	for s in weights:
		cumulative += weights[s]
		if roll <= cumulative:
			_faction_strategy[faction_key] = s
			return s

	_faction_strategy[faction_key] = Strategy.DEFEND
	return Strategy.DEFEND


func get_current_strategy(faction_key: String) -> int:
	return _faction_strategy.get(faction_key, Strategy.DEFEND)


# ═══════════════ TARGET SELECTION ═══════════════

func select_raid_target(faction_key: String, source_tiles: Array) -> Dictionary:
	## Pick the best player tile to raid. Returns {"tile": Dictionary, "score": float} or empty.
	var candidates: Array = []
	for src in source_tiles:
		if not GameManager.adjacency.has(src["index"]):
			continue
		for nb_idx in GameManager.adjacency[src["index"]]:
			if nb_idx >= GameManager.tiles.size():
				continue
			if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
				return
			var nb: Dictionary = GameManager.tiles[nb_idx]
			if nb["owner_id"] < 0:
				continue
			# Score: higher for weak garrison, high-value tiles
			var score: float = 0.0
			var garrison: int = nb.get("garrison", 0)
			score += 20.0 - float(garrison) * 2.0  # Prefer weak targets
			# Economic value scoring
			var level: int = nb.get("level", 1)
			score += float(level) * 3.0  # Higher level = more value to raid
			# Building value
			if nb.get("building_id", "") != "":
				score += 5.0
			# Economic personality prefers economic tiles
			var personality: int = AIScaling.get_personality(faction_key)
			if personality == AIScaling.Personality.ECONOMIC:
				score += float(level) * 2.0
			# Supply feasibility: skip targets that are too far for reliable supply
			if not _check_supply_feasibility(src, nb):
				continue
			candidates.append({"tile": nb, "score": score, "source": src})

	# ── Supply chokepoint consideration (RAID / EXPAND strategies) ──
	var strategy: int = get_current_strategy(faction_key)
	if strategy == Strategy.RAID or strategy == Strategy.EXPAND:
		# Find all enemy player IDs adjacent to our territory
		var enemy_pids: Dictionary = {}
		for c in candidates:
			var oid: int = c["tile"].get("owner_id", -1)
			if oid >= 0:
				enemy_pids[oid] = true
		for epid in enemy_pids:
			var chokepoints: Array = find_supply_chokepoints(epid)
			for cp in chokepoints:
				var cp_idx: int = cp["tile_index"]
				# Check if this chokepoint is already in candidates
				var already: bool = false
				for c in candidates:
					if c["tile"]["index"] == cp_idx:
						# Boost existing candidate score with supply-cut value
						var supply_score: float = score_supply_cut_attack(faction_key, cp_idx)
						if supply_score > 0.0:
							c["score"] += supply_score
							EventBus.message_log.emit("[%s] AI targets #%d to cut supply line (would isolate %d tiles)" % [faction_key, cp_idx, cp["isolation_count"]])
						already = true
						break
				if not already:
					# Add as new candidate if we have a source tile adjacent to it
					for src in source_tiles:
						if not GameManager.adjacency.has(src["index"]):
							continue
						if cp_idx in GameManager.adjacency[src["index"]]:
							var supply_score: float = score_supply_cut_attack(faction_key, cp_idx)
							if supply_score > 0.0:
								candidates.append({"tile": GameManager.tiles[cp_idx], "score": supply_score, "source": src})
								EventBus.message_log.emit("[%s] AI targets #%d to cut supply line (would isolate %d tiles)" % [faction_key, cp_idx, cp["isolation_count"]])
							break

	if candidates.is_empty():
		return {}

	# Sort by score descending
	candidates.sort_custom(func(a, b): return a["score"] > b["score"])
	return candidates[0]


func select_weakest_adjacent_target(faction_key: String) -> Dictionary:
	## Pick weakest player tile adjacent to faction territory for expansion.
	var candidates: Array = []
	for tile in GameManager.tiles:
		if tile["owner_id"] >= 0:
			continue
		if not AIScaling._tile_belongs_to_faction(tile, faction_key):
			continue
		if not GameManager.adjacency.has(tile["index"]):
			continue
		for nb_idx in GameManager.adjacency[tile["index"]]:
			if nb_idx >= GameManager.tiles.size():
				continue
			if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
				return
			var nb: Dictionary = GameManager.tiles[nb_idx]
			if nb["owner_id"] < 0:
				continue
			var garrison: int = nb.get("garrison", 0)
			var already_listed: bool = false
			for c in candidates:
				if c["tile"]["index"] == nb["index"]:
					already_listed = true
					break
			if not already_listed:
				# Supply feasibility: skip if target is out of sustainable range
				if not _check_supply_feasibility(tile, nb):
					continue
				candidates.append({"tile": nb, "garrison": garrison})

	if candidates.is_empty():
		return {}

	candidates.sort_custom(func(a, b): return a["garrison"] < b["garrison"])
	return candidates[0]


# ═══════════════ ARMY COMPOSITION ═══════════════

func get_counter_composition(faction_key: String, faction_id: int) -> Array:
	## Returns an array of unit_type strings that counter the player's recent army.
	var player_dominant: String = get_player_dominant_archetype(faction_key)
	var counters: Array = COUNTER_PICKS.get(player_dominant, ["infantry"])
	var available_units: Array = _get_faction_available_units(faction_id)

	# Find units in our faction that match counter archetypes
	var counter_units: Array = []
	for unit_type in available_units:
		var base: String = CounterMatrix.TYPE_MAP.get(unit_type, "infantry")
		if base in counters:
			counter_units.append(unit_type)

	# Fallback: if no counter units available, just use strongest available
	if counter_units.is_empty():
		return available_units

	return counter_units


func _get_faction_available_units(faction_id: int) -> Array:
	## Get unit types available to a faction.
	var faction_tag: String = ""
	match faction_id:
		FactionData.FactionID.ORC: faction_tag = "orc"
		FactionData.FactionID.PIRATE: faction_tag = "pirate"
		FactionData.FactionID.DARK_ELF: faction_tag = "dark_elf"
		_: return ["orc_ashigaru"]

	var result: Array = []
	var all_troops: Dictionary = TroopRegistry.get_all_troop_definitions()
	for key in all_troops:
		var troop: Dictionary = all_troops[key]
		if troop.get("faction", "") == faction_tag:
			result.append(key)
	# Also include faction-available neutrals
	return result


# ═══════════════ TACTICAL DIRECTIVE SELECTION ═══════════════

func choose_tactical_directive(faction_key: String, is_attacking: bool, our_strength: int, enemy_strength: int) -> int:
	## Choose the best tactical directive based on situation and personality.
	## Respects tier-based directive availability from AIScaling.
	var personality: int = AIScaling.get_personality(faction_key)
	var tier: int = AIScaling.get_tier(faction_key)
	var ratio: float = float(our_strength) / maxf(float(enemy_strength), 1.0)

	# Tier 0: no directives
	if tier < 1:
		return CombatResolver.TacticalDirective.NONE

	var chosen: int = CombatResolver.TacticalDirective.NONE

	# Decision based on combat situation
	if is_attacking:
		if ratio >= 1.8:
			chosen = CombatResolver.TacticalDirective.ALL_OUT
		elif ratio >= 1.3:
			match personality:
				AIScaling.Personality.AGGRESSIVE:
					chosen = CombatResolver.TacticalDirective.ALL_OUT
				_:
					chosen = CombatResolver.TacticalDirective.FOCUS_FIRE
		elif ratio >= 0.8:
			match personality:
				AIScaling.Personality.AGGRESSIVE:
					chosen = CombatResolver.TacticalDirective.AMBUSH
				AIScaling.Personality.DEFENSIVE:
					chosen = CombatResolver.TacticalDirective.GUERRILLA
				_:
					chosen = CombatResolver.TacticalDirective.FOCUS_FIRE
		else:
			if tier >= 2:
				chosen = CombatResolver.TacticalDirective.AMBUSH
			else:
				chosen = CombatResolver.TacticalDirective.GUERRILLA
	else:
		if ratio <= 0.5:
			chosen = CombatResolver.TacticalDirective.HOLD_LINE
		elif ratio <= 0.8:
			match personality:
				AIScaling.Personality.DEFENSIVE:
					chosen = CombatResolver.TacticalDirective.HOLD_LINE
				AIScaling.Personality.AGGRESSIVE:
					chosen = CombatResolver.TacticalDirective.GUERRILLA
				_:
					chosen = CombatResolver.TacticalDirective.HOLD_LINE
		else:
			match personality:
				AIScaling.Personality.AGGRESSIVE:
					chosen = CombatResolver.TacticalDirective.ALL_OUT
				_:
					chosen = CombatResolver.TacticalDirective.GUERRILLA

	# Validate: can the AI use this directive at their current tier?
	if AIScaling.can_use_directive(faction_key, chosen):
		return chosen
	# Fallback: pick best available directive
	var available: Array = AIScaling.get_available_directives(faction_key)
	if available.is_empty():
		return CombatResolver.TacticalDirective.NONE
	# Prefer HOLD_LINE for defense, FOCUS_FIRE for attack
	if not is_attacking and CombatResolver.TacticalDirective.HOLD_LINE in available:
		return CombatResolver.TacticalDirective.HOLD_LINE
	if is_attacking and CombatResolver.TacticalDirective.FOCUS_FIRE in available:
		return CombatResolver.TacticalDirective.FOCUS_FIRE
	return available[0]


# ═══════════════ THREAT RESPONSE ═══════════════

func reinforce_threatened_border(faction_key: String) -> void:
	## When player masses forces near AI territory, reinforce that border.
	var predicted: int = predict_player_next_target(faction_key)
	var buildup: Array = get_player_buildup_tiles(faction_key)

	# Collect tiles to reinforce (predicted targets + tiles adjacent to buildup)
	var reinforce_targets: Array = []
	if predicted >= 0 and predicted < GameManager.tiles.size():
		reinforce_targets.append(predicted)

	for player_tile_idx in buildup:
		if not GameManager.adjacency.has(player_tile_idx):
			continue
		for nb_idx in GameManager.adjacency[player_tile_idx]:
			if nb_idx >= GameManager.tiles.size():
				continue
			if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
				return
			var nb: Dictionary = GameManager.tiles[nb_idx]
			if nb["owner_id"] < 0 and AIScaling._tile_belongs_to_faction(nb, faction_key):
				if nb_idx not in reinforce_targets:
					reinforce_targets.append(nb_idx)

	# Apply reinforcement: +2 garrison per threatened tile
	var reinforce_mult: float = AIScaling.get_personality_mod(faction_key, "reinforce_mult")
	var amount: int = maxi(1, int(2.0 * reinforce_mult))
	var reinforced: int = 0
	for idx in reinforce_targets:
		if idx < GameManager.tiles.size():
			GameManager.tiles[idx]["garrison"] += amount
			reinforced += 1
	if reinforced > 0:
		EventBus.message_log.emit("[%s] AI侦测到威胁, 增援%d个前线据点" % [faction_key, reinforced])


# ═══════════════ ALLIANCE COORDINATION ═══════════════

func try_coordinate_attack(faction_keys: Array) -> void:
	## Warlike AI factions try to coordinate attacks on the same player tile.
	if _coordination_cooldown > 0:
		_coordination_cooldown -= 1
		return

	# Find warlike factions
	var warlike: Array = []
	for key in faction_keys:
		if AIScaling.get_personality(key) == AIScaling.Personality.AGGRESSIVE:
			warlike.append(key)

	if warlike.size() < 2:
		return

	# Find a shared adjacent player tile
	var shared_targets: Dictionary = {}  # tile_index -> count of factions adjacent
	for key in warlike:
		for tile in GameManager.tiles:
			if tile["owner_id"] >= 0:
				continue
			if not AIScaling._tile_belongs_to_faction(tile, key):
				continue
			if not GameManager.adjacency.has(tile["index"]):
				continue
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx >= GameManager.tiles.size():
					continue
				if nb_idx >= 0 and nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] >= 0:
					shared_targets[nb_idx] = shared_targets.get(nb_idx, 0) + 1

	# Pick target with most factions adjacent
	var best_target: int = -1
	var best_count: int = 1  # Need at least 2
	for idx in shared_targets:
		if shared_targets[idx] > best_count:
			best_count = shared_targets[idx]
			best_target = idx

	if best_target >= 0:
		_coordinated_target = best_target
		_coordination_cooldown = 4
		EventBus.message_log.emit("[color=red]暗势力联合进攻准备中! 目标: 据点#%d[/color]" % best_target)


func get_coordinated_target() -> int:
	return _coordinated_target


func clear_coordinated_target() -> void:
	_coordinated_target = -1


# ═══════════════ MAIN TURN PROCESSING ═══════════════

func process_turn(_player_id: int) -> void:
	## Called each turn. Update memory, evaluate strategies, and run tactical intelligence.
	# v13.0: 安全防护——如果 tiles 尚未初始化则跳过，避免空数组访问崩溃
	if GameManager.tiles.is_empty():
		return

	var ai_factions: Array = AIScaling.get_all_ai_factions()

	# Update memory for each faction
	for faction_key in ai_factions:
		record_player_buildup(faction_key)
		var strategy: int = evaluate_strategy(faction_key)
		_faction_strategy[faction_key] = strategy

		# ── Stall tracking for force concentration ──
		var current_tiles: int = _count_faction_tiles(faction_key)
		var prev_tiles: int = _last_tile_counts.get(faction_key, current_tiles)
		if current_tiles <= prev_tiles:
			_stall_counters[faction_key] = _stall_counters.get(faction_key, 0) + 1
		else:
			_stall_counters[faction_key] = 0
		_last_tile_counts[faction_key] = current_tiles

		# ── Execute pending feints (turn 2: real attack phase) ──
		_check_pending_feint(faction_key)

		# ── Track diversion results (did player pull back from our threatened tile?) ──
		_evaluate_tactic_results(faction_key)

	# Try coordinated attacks among warlike evil factions
	# v13.0: 包含 elf_ai 和 human_kingdom_ai 中的侵略性势力
	var evil_keys: Array = []
	for key in ai_factions:
		var personality: int = AIScaling.get_personality(key)
		if personality == AIScaling.Personality.AGGRESSIVE:
			evil_keys.append(key)
	if evil_keys.size() >= 2:
		try_coordinate_attack(evil_keys)


# ═══════════════ UTILITY ═══════════════

func _count_faction_tiles(faction_key: String) -> int:
	var count: int = 0
	for tile in GameManager.tiles:
		if tile["owner_id"] < 0 and AIScaling._tile_belongs_to_faction(tile, faction_key):
			count += 1
	return count


func _count_border_pressure(faction_key: String) -> int:
	## Count how many player tiles are adjacent to this faction's territory.
	var pressure: int = 0
	for tile in GameManager.tiles:
		if tile["owner_id"] < 0 and AIScaling._tile_belongs_to_faction(tile, faction_key):
			if GameManager.adjacency.has(tile["index"]):
				for nb_idx in GameManager.adjacency[tile["index"]]:
					if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] >= 0:
						pressure += 1
						break
	return pressure


# ═══════════════ WEATHER AWARENESS ═══════════════

func _get_weather_system() -> Variant:
	## Safe autoload access to WeatherSystem node.
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	if root and root.has_node("WeatherSystem"):
		return root.get_node("WeatherSystem")
	return null


func _evaluate_weather_for_attack() -> float:
	## Returns a multiplier (0.3–1.5) indicating how favorable weather/season is for attacking.
	## Low values discourage attacks; high values encourage them (e.g. fog for ambush).
	var ws: Node = _get_weather_system()
	if ws == null:
		return 1.0  # No weather system present, neutral

	var season: int = ws.current_season  # WeatherSystem.Season enum
	var weather: int = ws.current_weather  # WeatherSystem.Weather enum

	# Winter + Storm = blizzard: strongly discourage attacking
	if season == 3 and weather == 3:  # WINTER + STORM
		return 0.3

	var multiplier: float = 1.0

	# Season base adjustments
	match season:
		3:  # WINTER
			multiplier *= 0.7  # Winter generally discourages offense
		2:  # AUTUMN
			multiplier *= 0.9
		0:  # SPRING
			multiplier *= 1.05
		1:  # SUMMER
			multiplier *= 1.0

	# Weather adjustments
	match weather:
		1:  # RAIN — slight disadvantage for ranged-heavy armies
			multiplier *= 0.8
		2:  # FOG — good for ambush-oriented factions
			multiplier *= 1.2
		3:  # STORM
			multiplier *= 0.6
		4:  # SNOW
			multiplier *= 0.5
		0:  # CLEAR — neutral
			multiplier *= 1.0
		5:  # DROUGHT
			multiplier *= 0.9
		6:  # MONSOON
			multiplier *= 0.75

	return clampf(multiplier, 0.3, 1.5)


# ═══════════════ SUPPLY AWARENESS ═══════════════

func _check_supply_feasibility(source_tile: Dictionary, target_tile: Dictionary) -> bool:
	## Estimates if an army can sustain a campaign from source to target.
	## Uses a rough BFS-based adjacency hop distance. If the distance exceeds a
	## reasonable supply range, the campaign is not feasible.
	var max_supply_range: int = 6  # maximum hops the AI considers sustainable
	var source_idx: int = source_tile.get("index", -1)
	var target_idx: int = target_tile.get("index", -1)
	if source_idx < 0 or target_idx < 0:
		return false
	if source_idx == target_idx:
		return true

	# BFS to find hop distance
	var visited: Dictionary = {source_idx: true}
	var frontier: Array = [source_idx]
	var depth: int = 0
	while frontier.size() > 0 and depth < max_supply_range:
		depth += 1
		var next_frontier: Array = []
		for idx in frontier:
			if not GameManager.adjacency.has(idx):
				continue
			for nb_idx in GameManager.adjacency[idx]:
				if nb_idx == target_idx:
					return true  # Reachable within supply range
				if not visited.has(nb_idx) and nb_idx < GameManager.tiles.size():
					visited[nb_idx] = true
					next_frontier.append(nb_idx)
		frontier = next_frontier

	return false  # Target is too far for reliable supply


# ═══════════════ SUPPLY LINE WARFARE ═══════════════

func find_supply_chokepoints(target_player_id: int) -> Array:
	## Analyze enemy territory graph. Find tiles whose capture would ISOLATE
	## the most enemy territory. Returns [{tile_index, isolation_count, garrison}]
	## sorted by isolation_count descending.
	var enemy_tiles: Dictionary = {}  # index -> true
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == target_player_id:
			enemy_tiles[tile["index"]] = true

	if enemy_tiles.is_empty():
		return []

	var capital: int = SupplySystem.get_capital(target_player_id)

	# Find enemy border tiles adjacent to any AI territory
	var border_candidates: Array = []
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) != target_player_id:
			continue
		var idx: int = tile["index"]
		if not GameManager.adjacency.has(idx):
			continue
		var adj_to_ai: bool = false
		for nb_idx in GameManager.adjacency[idx]:
			if nb_idx < GameManager.tiles.size():
				var nb: Dictionary = GameManager.tiles[nb_idx]
				if nb["owner_id"] < 0:  # AI-owned tile
					adj_to_ai = true
					break
		if adj_to_ai:
			border_candidates.append(idx)

	# For each candidate, simulate capturing it and count isolated enemy tiles
	var results: Array = []
	for cand_idx in border_candidates:
		# Simulate removal: BFS from capital through enemy tiles minus this one
		if capital < 0 or capital == cand_idx:
			# Capturing capital itself isolates everything
			var iso_count: int = enemy_tiles.size() - 1
			results.append({
				"tile_index": cand_idx,
				"isolation_count": iso_count,
				"garrison": GameManager.tiles[cand_idx].get("garrison", 0),
			})
			continue

		var connected: Dictionary = {}
		var queue: Array = [capital]
		connected[capital] = true
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			var neighbors: Array = GameManager.adjacency.get(cur, [])
			for nb in neighbors:
				if connected.has(nb):
					continue
				if nb == cand_idx:
					continue  # Pretend this tile is captured
				if not enemy_tiles.has(nb):
					continue
				connected[nb] = true
				queue.append(nb)

		var isolated_count: int = 0
		for eidx in enemy_tiles:
			if eidx != cand_idx and not connected.has(eidx):
				isolated_count += 1

		if isolated_count > 0:
			results.append({
				"tile_index": cand_idx,
				"isolation_count": isolated_count,
				"garrison": GameManager.tiles[cand_idx].get("garrison", 0),
			})

	# Sort by isolation_count descending
	results.sort_custom(func(a, b): return a["isolation_count"] > b["isolation_count"])
	return results


func score_supply_cut_attack(_faction_key: String, tile_index: int) -> float:
	## Score a supply-cut attack. Higher = better target.
	# BUG FIX R15: bounds check before tiles[] access
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return 0.0
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	var tile = GameManager.tiles[tile_index]
	if tile == null:
		return 0.0
	var target_player_id: int = tile.get("owner_id", -1)
	if target_player_id < 0:
		return 0.0

	# Get isolation count for this tile
	var chokepoints: Array = find_supply_chokepoints(target_player_id)
	var isolation_count: int = 0
	for cp in chokepoints:
		if cp["tile_index"] == tile_index:
			isolation_count = cp["isolation_count"]
			break

	if isolation_count <= 0:
		return 0.0

	# Base attack score
	var base_score: float = 10.0
	# Isolation bonus: each isolated tile worth 3 points
	var isolation_bonus: float = float(isolation_count) * 3.0
	var score: float = base_score + isolation_bonus

	# Penalize if tile is heavily fortified (siege cost)
	var siege_info: Dictionary = evaluate_siege_cost(tile_index)
	if siege_info.get("is_fortified", false):
		score -= float(siege_info.get("siege_turns", 0)) * 2.0
		score -= siege_info.get("estimated_attrition", 0.0) * 10.0

	# Bonus if cutting supply also isolates enemy capital approach
	var capital: int = SupplySystem.get_capital(target_player_id)
	if capital >= 0 and GameManager.adjacency.has(tile_index):
		if capital in GameManager.adjacency[tile_index]:
			score += 5.0  # Adjacent to capital — high strategic value

	return score


# ═══════════════ SIEGE INTELLIGENCE ═══════════════

func evaluate_siege_cost(tile_index: int) -> Dictionary:
	## Evaluate the cost of besieging a tile.
	## Returns {is_fortified, siege_turns, estimated_attrition, wall_hp, worth_sieging}
	var result: Dictionary = {
		"is_fortified": false,
		"siege_turns": 0,
		"estimated_attrition": 0.0,
		"wall_hp": 0.0,
		"worth_sieging": true,
	}

	if not SiegeSystem.is_tile_fortified(tile_index):
		return result

	result["is_fortified"] = true
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	var tile: Dictionary = GameManager.tiles[tile_index]

	# Determine wall HP and siege turns based on tile type
	if tile.get("type", -1) == GameManager.TileType.CORE_FORTRESS:
		result["siege_turns"] = SiegeSystem.FORTRESS_SIEGE_TURNS
		result["wall_hp"] = SiegeSystem.FORTRESS_WALL_HP
	else:
		result["siege_turns"] = SiegeSystem.WALLED_SIEGE_TURNS
		result["wall_hp"] = SiegeSystem.WALLED_WALL_HP

	# Estimated attrition: base rate * siege turns
	result["estimated_attrition"] = SiegeSystem.BASE_ATTRITION_RATE * float(result["siege_turns"])

	# Calculate strategic importance of tile
	var tile_value: float = 0.0
	match tile.get("type", -1):
		GameManager.TileType.CORE_FORTRESS: tile_value = 12.0
		GameManager.TileType.LIGHT_STRONGHOLD: tile_value = 10.0
		GameManager.TileType.CHOKEPOINT: tile_value = 7.0
		GameManager.TileType.RESOURCE_STATION: tile_value = 6.0
		_: tile_value = 3.0

	# Siege cost = attrition penalty + time penalty
	var siege_cost: float = result["estimated_attrition"] * 30.0 + float(result["siege_turns"]) * 2.0
	result["worth_sieging"] = tile_value > siege_cost

	return result


# ═══════════════ 围魏救赵 — DIVERSIONARY ATTACK ═══════════════

func plan_diversion(faction_key: String, threatened_tile: int) -> Dictionary:
	## When AI territory is under pressure, consider attacking enemy rear instead
	## of directly defending. Returns {type:"diversion",...} or {type:"direct_defense"}.
	var tier: int = AIScaling.get_tier(faction_key)
	if tier < 1:
		return {"type": "direct_defense"}

	# Check learning: if player ignores diversions 4+ times (v13.0: 提高阈値避免过早放弃), stop trying
	var div_res: Dictionary = _diversion_results.get(faction_key, {"successes": 0, "failures": 0})
	if div_res.get("failures", 0) >= 4 and div_res.get("successes", 0) < div_res.get("failures", 0):
		return {"type": "direct_defense"}

	# Find the enemy player(s) threatening this tile
	var enemy_pids: Array = []
	if GameManager.adjacency.has(threatened_tile):
		for nb_idx in GameManager.adjacency[threatened_tile]:
			if nb_idx < GameManager.tiles.size():
				var nb_owner: int = GameManager.tiles[nb_idx].get("owner_id", -1)
				if nb_owner >= 0 and nb_owner not in enemy_pids:
					enemy_pids.append(nb_owner)

	if enemy_pids.is_empty():
		return {"type": "direct_defense"}

	# Find undefended rear tiles for each threatening enemy
	var best_rear: Dictionary = {}
	var best_rear_score: float = 0.0
	for epid in enemy_pids:
		var rear_targets: Array = find_undefended_enemy_rear(faction_key, epid)
		for rt in rear_targets:
			if rt["score"] > best_rear_score:
				best_rear_score = rt["score"]
				best_rear = rt

	if best_rear.is_empty():
		return {"type": "direct_defense"}

	# Score direct defense: garrison strength of threatened tile
	var threatened: Dictionary = GameManager.tiles[threatened_tile] if threatened_tile < GameManager.tiles.size() else {}
	var direct_def_score: float = float(threatened.get("garrison", 0)) * 1.5
	match threatened.get("type", -1):
		GameManager.TileType.CORE_FORTRESS: direct_def_score += 15.0
		GameManager.TileType.DARK_BASE: direct_def_score += 10.0

	# Personality modifier: aggressive factions prefer diversion
	var personality: int = AIScaling.get_personality(faction_key)
	var diversion_mult: float = 1.0
	if personality == AIScaling.Personality.AGGRESSIVE:
		diversion_mult = 1.4
	elif personality == AIScaling.Personality.DEFENSIVE:
		diversion_mult = 0.6

	# Past success bonus
	if div_res.get("successes", 0) >= 2:
		diversion_mult *= 1.3

	if best_rear_score * diversion_mult > direct_def_score:
		EventBus.ai_diversion_planned.emit(faction_key, threatened_tile, best_rear["tile_index"])
		EventBus.message_log.emit("[color=red][%s] 围魏救赵! 佯攻据点#%d, 实攻后方据点#%d[/color]" % [faction_key, threatened_tile, best_rear["tile_index"]])
		return {
			"type": "diversion",
			"target_tile": best_rear["tile_index"],
			"threatened_tile": threatened_tile,
			"diversion_score": best_rear_score,
		}

	return {"type": "direct_defense"}


func find_undefended_enemy_rear(faction_key: String, enemy_player_id: int) -> Array:
	## Find enemy rear tiles reachable by this AI faction (1-2 hops from AI territory).
	## Returns sorted array of {tile_index, score, garrison}.
	var rear_tiles: Array = SupplySystem.get_rear_tiles(enemy_player_id)
	if rear_tiles.is_empty():
		return []

	# Collect all AI-owned tile indices for adjacency check
	var ai_tiles: Dictionary = {}
	for tile in GameManager.tiles:
		if tile["owner_id"] < 0 and AIScaling._tile_belongs_to_faction(tile, faction_key):
			ai_tiles[tile["index"]] = true

	# Also collect 2-hop reachable indices from AI tiles
	var reachable_2hop: Dictionary = {}
	for ai_idx in ai_tiles:
		if GameManager.adjacency.has(ai_idx):
			for nb1 in GameManager.adjacency[ai_idx]:
				reachable_2hop[nb1] = true
				if GameManager.adjacency.has(nb1):
					for nb2 in GameManager.adjacency[nb1]:
						reachable_2hop[nb2] = true

	var capital: int = SupplySystem.get_capital(enemy_player_id)
	var results: Array = []
	for rt_idx in rear_tiles:
		if rt_idx < 0 or rt_idx >= GameManager.tiles.size():
			continue
		# Must be reachable (1 or 2 hops from AI territory)
		var directly_adjacent: bool = false
		if GameManager.adjacency.has(rt_idx):
			for nb in GameManager.adjacency[rt_idx]:
				if ai_tiles.has(nb):
					directly_adjacent = true
					break
		var two_hop_reachable: bool = reachable_2hop.has(rt_idx)
		if not directly_adjacent and not two_hop_reachable:
			continue

		if rt_idx < 0 or rt_idx >= GameManager.tiles.size():
			return
		var tile: Dictionary = GameManager.tiles[rt_idx]
		var garrison: int = tile.get("garrison", 0)
		var level: int = tile.get("level", 1)

		# Score: production_value * 2 + (10 - garrison) + capital_proximity_bonus
		var prod_value: float = float(level) * 2.0
		if tile.get("building_id", "") != "":
			prod_value += 3.0
		var score: float = prod_value * 2.0 + maxf(0.0, 10.0 - float(garrison))

		# Capital proximity bonus
		if capital >= 0 and GameManager.adjacency.has(rt_idx):
			if capital in GameManager.adjacency[rt_idx]:
				score += 8.0
			else:
				for nb in GameManager.adjacency[rt_idx]:
					if GameManager.adjacency.has(nb) and capital in GameManager.adjacency[nb]:
						score += 4.0
						break

		if directly_adjacent:
			score += 5.0

		results.append({"tile_index": rt_idx, "score": score, "garrison": garrison})

	results.sort_custom(func(a, b): return a["score"] > b["score"])
	return results


# ═══════════════ 声东击西 — FEINT EAST STRIKE WEST ═══════════════

func plan_feint(faction_key: String) -> Dictionary:
	## Plan a coordinated misdirection: deploy army to strong border (feint)
	## while real attack comes from another direction.
	var tier: int = AIScaling.get_tier(faction_key)
	if tier < 2:
		return {}

	# Check learning: if player ignores feints 4+ times (v13.0: 提高阈値), stop feinting
	var feint_res: Dictionary = _feint_results.get(faction_key, {"successes": 0, "failures": 0})
	if feint_res.get("failures", 0) >= 4 and feint_res.get("successes", 0) < feint_res.get("failures", 0):
		return {}

	# Need at least 2 available AI border tiles with garrison
	var border_info: Array = _get_faction_border_info(faction_key)
	if border_info.size() < 2:
		return {}

	# Find the strongest enemy border tile (feint target) and weakest (real target)
	border_info.sort_custom(func(a, b): return a["adj_enemy_garrison"] > b["adj_enemy_garrison"])

	var feint_source: Dictionary = border_info[0]
	var real_source: Dictionary = {}
	for bi in border_info:
		if bi["index"] == feint_source["index"]:
			continue
		var is_adjacent: bool = false
		if GameManager.adjacency.has(feint_source["index"]):
			if bi["index"] in GameManager.adjacency[feint_source["index"]]:
				is_adjacent = true
		if not is_adjacent:
			real_source = bi
			break

	if real_source.is_empty():
		if border_info.size() >= 2:
			real_source = border_info[border_info.size() - 1]
		else:
			return {}

	var feint_target: int = _find_adjacent_enemy_tile(feint_source["index"])
	var real_target: int = _find_weakest_adjacent_enemy_tile(real_source["index"])

	if feint_target < 0 or real_target < 0:
		return {}
	if feint_target == real_target:
		return {}

	var plan: Dictionary = {
		"feint_source": feint_source["index"],
		"feint_target": feint_target,
		"real_source": real_source["index"],
		"real_target": real_target,
		"execute_turn": 1,
		"feint_garrison_before": GameManager.tiles[feint_target].get("garrison", 0) if feint_target < GameManager.tiles.size() else 0,
	}

	_pending_feints[faction_key] = plan
	EventBus.ai_diversion_planned.emit(faction_key, feint_target, real_target)
	EventBus.message_log.emit("[color=red][%s] 声东击西! 佯攻据点#%d, 暗袭据点#%d[/color]" % [faction_key, feint_target, real_target])
	return plan


func _check_pending_feint(faction_key: String) -> void:
	## Check and advance pending feint plans each turn.
	if not _pending_feints.has(faction_key):
		return
	var plan: Dictionary = _pending_feints[faction_key]
	plan["execute_turn"] -= 1
	if plan["execute_turn"] < 0:
		var feint_target: int = plan.get("feint_target", -1)
		if feint_target >= 0 and feint_target < GameManager.tiles.size():
			var current_garrison: int = GameManager.tiles[feint_target].get("garrison", 0)
			var before_garrison: int = plan.get("feint_garrison_before", 0)
			var res: Dictionary = _feint_results.get(faction_key, {"successes": 0, "failures": 0})
			if current_garrison > before_garrison + 1:
				res["successes"] = res.get("successes", 0) + 1
			else:
				res["failures"] = res.get("failures", 0) + 1
			_feint_results[faction_key] = res
		_pending_feints.erase(faction_key)


func get_pending_feint(faction_key: String) -> Dictionary:
	## Returns the current feint plan for a faction, or empty dict.
	return _pending_feints.get(faction_key, {})


func _get_faction_border_info(faction_key: String) -> Array:
	## Get all faction border tiles with info about adjacent enemy strength.
	var results: Array = []
	for tile in GameManager.tiles:
		if tile["owner_id"] >= 0:
			continue
		if not AIScaling._tile_belongs_to_faction(tile, faction_key):
			continue
		if not GameManager.adjacency.has(tile["index"]):
			continue
		var max_enemy_garrison: int = 0
		var has_enemy: bool = false
		for nb_idx in GameManager.adjacency[tile["index"]]:
			if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] >= 0:
				has_enemy = true
				var g: int = GameManager.tiles[nb_idx].get("garrison", 0)
				if g > max_enemy_garrison:
					max_enemy_garrison = g
		if has_enemy:
			results.append({
				"index": tile["index"],
				"garrison": tile.get("garrison", 0),
				"adj_enemy_garrison": max_enemy_garrison,
			})
	return results


func _find_adjacent_enemy_tile(source_idx: int) -> int:
	## Find the strongest adjacent enemy tile (for feint target selection).
	if not GameManager.adjacency.has(source_idx):
		return -1
	var best_idx: int = -1
	var best_garrison: int = -1
	for nb_idx in GameManager.adjacency[source_idx]:
		if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] >= 0:
			var g: int = GameManager.tiles[nb_idx].get("garrison", 0)
			if g > best_garrison:
				best_garrison = g
				best_idx = nb_idx
	return best_idx


func _find_weakest_adjacent_enemy_tile(source_idx: int) -> int:
	## Find the weakest adjacent enemy tile (for real attack target).
	if not GameManager.adjacency.has(source_idx):
		return -1
	var best_idx: int = -1
	var best_garrison: int = 9999
	for nb_idx in GameManager.adjacency[source_idx]:
		if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] >= 0:
			var g: int = GameManager.tiles[nb_idx].get("garrison", 0)
			if g < best_garrison:
				best_garrison = g
				best_idx = nb_idx
	return best_idx


# ═══════════════ 集中优势兵力 — FORCE CONCENTRATION ═══════════════

func plan_concentration(faction_key: String) -> Dictionary:
	## Plan force concentration: consolidate garrison toward a single high-value
	## attack point to create overwhelming force.
	var tier: int = AIScaling.get_tier(faction_key)
	if tier < 1:
		return {}

	var border_info: Array = _get_faction_border_info(faction_key)
	if border_info.is_empty():
		return {}

	var best_target_idx: int = -1
	var best_combined_score: float = 0.0
	var rally_tiles: Array = []

	for bi in border_info:
		var weak_enemy: int = _find_weakest_adjacent_enemy_tile(bi["index"])
		if weak_enemy < 0:
			continue
		var enemy_garrison: int = GameManager.tiles[weak_enemy].get("garrison", 0)
		var supporters: Array = [bi]
		for bi2 in border_info:
			if bi2["index"] == bi["index"]:
				continue
			var dist: int = _hop_distance(bi2["index"], bi["index"], 3)
			if dist >= 0 and dist <= 2:
				supporters.append(bi2)

		var combined_force: int = 0
		for s in supporters:
			combined_force += s["garrison"]

		# BUG FIX: removed asymmetric *8.0 that made concentration ratio 8x harder to reach
		var ratio: float = float(combined_force) / maxf(float(enemy_garrison), 1.0)
		if ratio > 2.0 and float(combined_force) > best_combined_score:
			best_combined_score = float(combined_force)
			best_target_idx = weak_enemy
			rally_tiles = []
			for s in supporters:
				rally_tiles.append({"tile_index": s["index"], "garrison": s["garrison"]})

	if best_target_idx < 0 or rally_tiles.size() < 2:
		return {}

	var plan: Dictionary = {
		"target_tile": best_target_idx,
		"rally_tiles": rally_tiles,
		"attack_turn": 1,
	}
	_concentration_plans[faction_key] = plan
	EventBus.ai_concentration_started.emit(faction_key, best_target_idx, rally_tiles.size())
	EventBus.message_log.emit("[color=red][%s] 集中优势兵力! %d个据点合力进攻据点#%d[/color]" % [faction_key, rally_tiles.size(), best_target_idx])
	return plan


func should_concentrate(faction_key: String) -> bool:
	## Returns true if force concentration is recommended for this faction.
	if _concentration_plans.has(faction_key):
		return false
	if _stall_counters.get(faction_key, 0) >= 3:
		return true
	var strategy: int = get_current_strategy(faction_key)
	if strategy == Strategy.EXPAND and _stall_counters.get(faction_key, 0) >= 2:
		return true
	var border_info: Array = _get_faction_border_info(faction_key)
	if border_info.size() >= 3:
		var can_attack: bool = false
		for bi in border_info:
			var weak: int = _find_weakest_adjacent_enemy_tile(bi["index"])
			if weak >= 0:
				var enemy_g: int = GameManager.tiles[weak].get("garrison", 0)
				# BUG FIX R7: fixed indentation — condition was outside loop body
				if float(bi["garrison"]) > float(enemy_g) * 1.2:
					can_attack = true
					break
		if not can_attack:
			return true
	return false


func get_concentration_plan(faction_key: String) -> Dictionary:
	## Returns the active concentration plan for a faction, or empty dict.
	return _concentration_plans.get(faction_key, {})


func execute_concentration(faction_key: String) -> void:
	## Execute force concentration: boost garrison at rally tiles toward target.
	if not _concentration_plans.has(faction_key):
		return
	var plan: Dictionary = _concentration_plans[faction_key]
	var target: int = plan.get("target_tile", -1)
	if target < 0:
		_concentration_plans.erase(faction_key)
		return

	plan["attack_turn"] = plan.get("attack_turn", 1) - 1
	if plan["attack_turn"] <= 0:
		var best_rally: int = -1
		var best_dist: int = 9999
		for rt in plan.get("rally_tiles", []):
			var d: int = _hop_distance(rt["tile_index"], target, 4)
			if d >= 0 and d < best_dist:
				best_dist = d
				best_rally = rt["tile_index"]

		if best_rally >= 0 and best_rally < GameManager.tiles.size():
			var transferred: int = 0
			for rt in plan.get("rally_tiles", []):
				if rt["tile_index"] == best_rally:
					continue
				if rt["tile_index"] < GameManager.tiles.size():
					var donate: int = maxi(0, GameManager.tiles[rt["tile_index"]].get("garrison", 0) - 2)
					if donate > 0:
						GameManager.tiles[rt["tile_index"]]["garrison"] -= donate
						transferred += donate
			if transferred > 0:
				if best_rally >= 0 and best_rally < GameManager.tiles.size():
					GameManager.tiles[best_rally]["garrison"] += transferred
				EventBus.message_log.emit("[%s] 兵力集结完毕! 据点#%d获得+%d援军" % [faction_key, best_rally, transferred])
		_concentration_plans.erase(faction_key)
	else:
		_concentration_plans[faction_key] = plan


# ═══════════════ STRATEGIC RETREAT ═══════════════

func should_retreat(faction_key: String, tile_index: int) -> bool:
	## Returns true if the garrison at tile_index should consider retreating.
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return false
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	var tile: Dictionary = GameManager.tiles[tile_index]
	var garrison: int = tile.get("garrison", 0)
	if garrison <= 0:
		return false

	var tile_type: int = tile.get("type", -1)
	if tile_type == GameManager.TileType.CORE_FORTRESS or tile_type == GameManager.TileType.DARK_BASE:
		return false

	if not GameManager.adjacency.has(tile_index):
		return false

	var enemy_force: int = 0
	var enemy_tile_count: int = 0
	var friendly_count: int = 0
	for nb_idx in GameManager.adjacency[tile_index]:
		if nb_idx >= GameManager.tiles.size():
			continue
		if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
			return
		var nb: Dictionary = GameManager.tiles[nb_idx]
		if nb["owner_id"] >= 0:
			enemy_force += nb.get("garrison", 0) * 8
			var enemy_army: Dictionary = GameManager.get_army_at_tile(nb_idx)
			if not enemy_army.is_empty():
				enemy_force += GameManager.get_army_combat_power(enemy_army["id"])
			enemy_tile_count += 1
		elif nb["owner_id"] < 0 and AIScaling._tile_belongs_to_faction(nb, faction_key):
			friendly_count += 1

	var our_force: int = garrison * 8
	if enemy_force > our_force * 3:
		return true
	if enemy_tile_count >= 3 and garrison < 5:
		return true
	if friendly_count == 0 and enemy_force > our_force * 1.5:
		return true

	return false


func find_retreat_tile(faction_key: String, tile_index: int) -> int:
	## Find safest adjacent owned tile for retreat. Returns tile_index or -1.
	if not GameManager.adjacency.has(tile_index):
		return -1

	var best_idx: int = -1
	var best_score: float = -999.0
	for nb_idx in GameManager.adjacency[tile_index]:
		if nb_idx >= GameManager.tiles.size():
			continue
		if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
			return
		var nb: Dictionary = GameManager.tiles[nb_idx]
		if nb["owner_id"] >= 0:
			continue
		if not AIScaling._tile_belongs_to_faction(nb, faction_key):
			continue

		var score: float = 0.0
		score += float(nb.get("garrison", 0)) * 0.5
		if nb.get("building_id", "") != "":
			score += 3.0
		if GameManager.adjacency.has(nb_idx):
			for nb2_idx in GameManager.adjacency[nb_idx]:
				if nb2_idx < GameManager.tiles.size():
					if GameManager.tiles[nb2_idx]["owner_id"] >= 0:
						score -= 2.0
					elif AIScaling._tile_belongs_to_faction(GameManager.tiles[nb2_idx], faction_key):
						score += 1.0
		var nb_type: int = nb.get("type", -1)
		if nb_type == GameManager.TileType.CORE_FORTRESS or nb_type == GameManager.TileType.DARK_BASE:
			score += 5.0

		if score > best_score:
			best_score = score
			best_idx = nb_idx

	return best_idx


func execute_retreat(faction_key: String, from_tile: int) -> bool:
	## Execute a strategic retreat: move garrison from from_tile to safest neighbor.
	var retreat_to: int = find_retreat_tile(faction_key, from_tile)
	if retreat_to < 0:
		return false

	var garrison: int = GameManager.tiles[from_tile].get("garrison", 0)
	if garrison <= 0:
		return false

	var transfer: int = maxi(0, garrison - 1)
	if transfer <= 0:
		return false

	if from_tile >= 0 and from_tile < GameManager.tiles.size():
		GameManager.tiles[from_tile]["garrison"] -= transfer
	if retreat_to >= 0 and retreat_to < GameManager.tiles.size():
		GameManager.tiles[retreat_to]["garrison"] += transfer
	EventBus.ai_strategic_retreat.emit(0, from_tile, retreat_to)
	EventBus.message_log.emit("[%s] 战略转进: 据点#%d → 据点#%d (%d兵力)" % [faction_key, from_tile, retreat_to, transfer])
	return true


# ═══════════════ TACTICAL PLAN DISPATCH ═══════════════

func get_tactical_plan(faction_key: String) -> Dictionary:
	## Returns the best tactical plan for this faction's current situation.
	## Called by game_manager before attack phase.

	var feint: Dictionary = get_pending_feint(faction_key)
	if not feint.is_empty() and feint.get("execute_turn", 1) <= 0:
		return {"type": "feint", "plan": feint}

	var conc: Dictionary = get_concentration_plan(faction_key)
	if not conc.is_empty():
		return {"type": "concentration", "plan": conc}

	if should_concentrate(faction_key):
		var new_conc: Dictionary = plan_concentration(faction_key)
		if not new_conc.is_empty():
			return {"type": "concentration", "plan": new_conc}

	var border_pressure: int = _count_border_pressure(faction_key)
	if border_pressure >= 2:
		var predicted: int = predict_player_next_target(faction_key)
		if predicted >= 0:
			var diversion: Dictionary = plan_diversion(faction_key, predicted)
			if diversion.get("type", "") == "diversion":
				return {"type": "diversion", "plan": diversion}

	if not _pending_feints.has(faction_key):
		var tier: int = AIScaling.get_tier(faction_key)
		if tier >= 2:
			var personality: int = AIScaling.get_personality(faction_key)
			var feint_chance: float = 0.2
			if personality == AIScaling.Personality.AGGRESSIVE:
				feint_chance = 0.4
			if randf() < feint_chance:
				var new_feint: Dictionary = plan_feint(faction_key)
				if not new_feint.is_empty():
					return {"type": "feint_setup", "plan": new_feint}

	var retreat_tiles: Array = _find_tiles_needing_retreat(faction_key)
	if not retreat_tiles.is_empty():
		return {"type": "retreat", "tiles": retreat_tiles}

	return {"type": "normal"}


func _find_tiles_needing_retreat(faction_key: String) -> Array:
	## Find all faction tiles that should retreat.
	var result: Array = []
	for tile in GameManager.tiles:
		if tile["owner_id"] >= 0:
			continue
		if not AIScaling._tile_belongs_to_faction(tile, faction_key):
			continue
		if should_retreat(faction_key, tile["index"]):
			result.append(tile["index"])
	return result


# ═══════════════ LEARNING & RESULT TRACKING ═══════════════

func _evaluate_tactic_results(_faction_key: String) -> void:
	## Evaluate past tactical decisions for adaptive learning.
	pass  # Actual tracking happens in _check_pending_feint and plan_diversion


func record_diversion_result(faction_key: String, success: bool) -> void:
	## Record whether a diversion caused the player to pull back.
	var res: Dictionary = _diversion_results.get(faction_key, {"successes": 0, "failures": 0})
	if success:
		res["successes"] = res.get("successes", 0) + 1
	else:
		res["failures"] = res.get("failures", 0) + 1
	_diversion_results[faction_key] = res


# ═══════════════ HOP DISTANCE UTILITY ═══════════════

func _hop_distance(from_idx: int, to_idx: int, max_hops: int) -> int:
	## BFS hop distance between two tiles. Returns -1 if unreachable within max_hops.
	if from_idx == to_idx:
		return 0
	var visited: Dictionary = {from_idx: true}
	var frontier: Array = [from_idx]
	var depth: int = 0
	while not frontier.is_empty() and depth < max_hops:
		depth += 1
		var next_frontier: Array = []
		for idx in frontier:
			if not GameManager.adjacency.has(idx):
				continue
			for nb_idx in GameManager.adjacency[idx]:
				if nb_idx == to_idx:
					return depth
				if not visited.has(nb_idx) and nb_idx < GameManager.tiles.size():
					visited[nb_idx] = true
					next_frontier.append(nb_idx)
		frontier = next_frontier
	return -1


# ═══════════════ COMMITMENT TRACKING ═══════════════

func get_active_commitments(faction_key: String) -> Dictionary:
	## Track how many armies are in sieges vs free.
	## Returns {total_armies, sieging_armies, free_armies, overcommitted}
	var result: Dictionary = {
		"total_armies": 0,
		"sieging_armies": 0,
		"free_armies": 0,
		"overcommitted": false,
	}

	# Find player_id for this faction key
	var faction_pid: int = -1
	for p in GameManager.players:
		var ai_key: String = ""
		var fid: int = GameManager.get_player_faction(p["id"])
		match fid:
			FactionData.FactionID.ORC: ai_key = "orc_ai"
			FactionData.FactionID.PIRATE: ai_key = "pirate_ai"
			FactionData.FactionID.DARK_ELF: ai_key = "dark_elf_ai"
		if ai_key == faction_key:
			faction_pid = p["id"]
			break

	if faction_pid < 0:
		return result

	var armies: Array = GameManager.get_player_armies(faction_pid)
	result["total_armies"] = armies.size()

	# Count armies involved in sieges
	var sieges: Array = SiegeSystem.get_player_sieges(faction_pid)
	result["sieging_armies"] = sieges.size()
	result["free_armies"] = maxi(0, result["total_armies"] - result["sieging_armies"])

	# Overcommitted if >50% armies in sieges
	if result["total_armies"] > 0:
		result["overcommitted"] = float(result["sieging_armies"]) / float(result["total_armies"]) > 0.5

	return result


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"player_memory": _player_memory.duplicate(true),
		"faction_strategy": _faction_strategy.duplicate(),
		"coordinated_target": _coordinated_target,
		"coordination_cooldown": _coordination_cooldown,
		"pending_feints": _pending_feints.duplicate(true),
		"concentration_plans": _concentration_plans.duplicate(true),
		"stall_counters": _stall_counters.duplicate(),
		"diversion_results": _diversion_results.duplicate(true),
		"feint_results": _feint_results.duplicate(true),
		"last_tile_counts": _last_tile_counts.duplicate(),
	}


func from_save_data(data: Dictionary) -> void:
	_player_memory = data.get("player_memory", {}).duplicate(true)
	_faction_strategy = data.get("faction_strategy", {}).duplicate()
	_coordinated_target = int(data.get("coordinated_target", -1))
	_coordination_cooldown = int(data.get("coordination_cooldown", 0))
	_pending_feints = data.get("pending_feints", {}).duplicate(true)
	_concentration_plans = data.get("concentration_plans", {}).duplicate(true)
	_stall_counters = data.get("stall_counters", {}).duplicate()
	_diversion_results = data.get("diversion_results", {}).duplicate(true)
	_feint_results = data.get("feint_results", {}).duplicate(true)
	_last_tile_counts = data.get("last_tile_counts", {}).duplicate()
	# BUG FIX: cast Strategy enum values and counter ints after JSON round-trip
	for key in _faction_strategy:
		_faction_strategy[key] = int(_faction_strategy[key])
	for key in _stall_counters:
		_stall_counters[key] = int(_stall_counters[key])
	for key in _last_tile_counts:
		_last_tile_counts[key] = int(_last_tile_counts[key])
