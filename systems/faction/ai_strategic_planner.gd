## ai_strategic_planner.gd - Strategic AI decision layer (v4.0)
## Provides intelligent decision-making for all AI factions.
## Tracks player behavior, adapts strategies, and coordinates multi-faction actions.
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

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
				if GameManager.tiles[nb_idx]["owner_id"] >= 0:
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

func process_turn(player_id: int) -> void:
	## Called each turn. Update memory and evaluate strategies for all AI factions.
	var ai_factions: Array = AIScaling.get_all_ai_factions()

	# Update memory for each faction
	for faction_key in ai_factions:
		record_player_buildup(faction_key)
		var strategy: int = evaluate_strategy(faction_key)
		_faction_strategy[faction_key] = strategy

	# Try coordinated attacks among warlike evil factions
	var evil_keys: Array = []
	for key in ai_factions:
		if key in ["orc_ai", "pirate_ai", "dark_elf_ai"]:
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

func _get_weather_system() -> Node:
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


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"player_memory": _player_memory.duplicate(true),
		"faction_strategy": _faction_strategy.duplicate(),
		"coordinated_target": _coordinated_target,
		"coordination_cooldown": _coordination_cooldown,
	}


func from_save_data(data: Dictionary) -> void:
	_player_memory = data.get("player_memory", {}).duplicate(true)
	_faction_strategy = data.get("faction_strategy", {}).duplicate()
	_coordinated_target = data.get("coordinated_target", -1)
	_coordination_cooldown = data.get("coordination_cooldown", 0)
