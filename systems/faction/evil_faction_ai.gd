extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")
const CounterMatrix = preload("res://systems/combat/counter_matrix.gd")

## evil_faction_ai.gd - Strategic AI for unrecruited evil faction outposts (v4.0)
## Now uses AIStrategicPlanner for intelligent target selection, tactical directives,
## personality-driven behavior, and adaptive army composition.

# ── Raid cooldown per faction to prevent spam ──
var _raid_cooldowns: Dictionary = {}  # faction_id -> int (turns remaining)

func _ready() -> void:
	pass

func reset() -> void:
	_raid_cooldowns.clear()

func tick(player_id: int) -> void:
	## Called each turn. Run AI for each unrecruited evil faction.
	for faction_id in [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]:
		if faction_id == GameManager.get_player_faction(player_id):
			continue  # Player's own faction
		if DiplomacyManager.is_recruited(player_id, faction_id):
			continue  # Already recruited
		_tick_faction(player_id, faction_id)
	# Decrement raid cooldowns
	for key in _raid_cooldowns.keys():
		if _raid_cooldowns[key] > 0:
			_raid_cooldowns[key] -= 1

func _tick_faction(player_id: int, faction_id: int) -> void:
	var is_hostile: bool = false
	var relations: Dictionary = DiplomacyManager.get_all_relations(player_id)
	if relations.has(faction_id):
		is_hostile = relations[faction_id].get("hostile", false)

	var ai_key: String = _faction_to_ai_key(faction_id)
	var strategy: int = AIStrategicPlanner.get_current_strategy(ai_key)
	var source_tiles: Array = []  # tiles belonging to this faction

	for tile in GameManager.tiles:
		if tile.get("original_faction", -1) != faction_id:
			continue
		if tile["owner_id"] >= 0:
			continue  # Already captured by player
		source_tiles.append(tile)

		# Garrison recovery: +1 per turn up to base max
		var base_garrison: int = _get_base_garrison(tile)
		var regen_bonus: int = AIScaling.get_garrison_regen_bonus(ai_key) if ai_key != "" else 0
		var regen_rate: int = 1 + regen_bonus
		var reinforce_mult: float = AIScaling.get_personality_mod(ai_key, "reinforce_mult") if ai_key != "" else 1.0
		regen_rate = maxi(1, int(float(regen_rate) * reinforce_mult))
		regen_rate = mini(regen_rate, 5)
		if tile.get("garrison", 0) < base_garrison:
			tile["garrison"] = mini(base_garrison, tile.get("garrison", 0) + regen_rate)

		# Reactive: if player owns adjacent tile, boost garrison
		var player_nearby: bool = false
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] == player_id:
					player_nearby = true
					break

		if player_nearby:
			tile["garrison"] = mini(tile.get("garrison", 0) + 1, base_garrison + 5)

	# ── Strategic actions based on planner ──
	if is_hostile and source_tiles.size() > 0:
		# ── Phase 0.5: Advanced tactical intelligence ──
		var tactical_plan: Dictionary = AIStrategicPlanner.get_tactical_plan(ai_key)
		var plan_type: String = tactical_plan.get("type", "normal")

		# Execute strategic retreats before anything else
		if plan_type == "retreat":
			for retreat_idx in tactical_plan.get("tiles", []):
				AIStrategicPlanner.execute_retreat(ai_key, retreat_idx)

		# Execute concentration (garrison transfer toward rally point)
		if plan_type == "concentration":
			AIStrategicPlanner.execute_concentration(ai_key)

		# Execute feint: boost garrison near feint target to draw attention
		if plan_type == "feint_setup":
			var feint_plan: Dictionary = tactical_plan.get("plan", {})
			var feint_src: int = feint_plan.get("feint_source", -1)
			if feint_src >= 0 and feint_src < GameManager.tiles.size():
				GameManager.tiles[feint_src]["garrison"] += 3
				EventBus.message_log.emit("[%s] 佯攻部队集结中..." % ai_key)

		# Execute diversion: raid enemy rear instead of defending
		if plan_type == "diversion":
			var div_plan: Dictionary = tactical_plan.get("plan", {})
			var div_target: int = div_plan.get("target_tile", -1)
			if div_target >= 0:
				_execute_diversion_raid(player_id, source_tiles, faction_id, div_target)

		# Normal strategic behavior
		if plan_type == "normal" or plan_type == "retreat":
			match strategy:
				AIStrategicPlanner.Strategy.RAID:
					_try_strategic_raid(player_id, source_tiles, faction_id)
				AIStrategicPlanner.Strategy.EXPAND:
					_try_strategic_raid(player_id, source_tiles, faction_id)
				AIStrategicPlanner.Strategy.DEFEND:
					AIStrategicPlanner.reinforce_threatened_border(ai_key)
				AIStrategicPlanner.Strategy.CONSOLIDATE:
					_consolidate_garrison(source_tiles, faction_id)
				_:
					_try_legacy_raid(player_id, source_tiles, faction_id)

		# Execute pending feint real attack (turn 2)
		if plan_type == "feint":
			var feint_plan: Dictionary = tactical_plan.get("plan", {})
			var real_target: int = feint_plan.get("real_target", -1)
			if real_target >= 0:
				_execute_diversion_raid(player_id, source_tiles, faction_id, real_target)

	# Coordinated attacks: if this faction is part of a coordinated assault
	if is_hostile:
		_try_coordinated_attack(player_id, faction_id, source_tiles)

	# Counter-espionage: invest in counter-intel if being scouted
	_try_counter_espionage(player_id, faction_id)
	# ── 势力差异化行动 ──
	match faction_id:
		FactionData.FactionID.ORC:
			# 兽人：当WAAAGH积累时，额外增兵前线
			_orc_faction_action(player_id, source_tiles)
		FactionData.FactionID.PIRATE:
			# 海盗：优先攻击港口和贸易站
			_pirate_faction_action(player_id, source_tiles)
		FactionData.FactionID.DARK_ELF:
			# 暗精灵：情报收集和精准打击
			_dark_elf_faction_action(player_id, source_tiles)


func _try_strategic_raid(_player_id: int, source_tiles: Array, faction_id: int) -> void:
	## Strategic raid: pick the best target instead of random.
	var ai_key: String = _faction_to_ai_key(faction_id)
	var raid_chance: float = float(BalanceConfig.EVIL_RAID_CHANCE_PCT) * AIScaling.get_personality_mod(ai_key, "raid_chance_mult")
	# Strategy RAID doubles the chance
	if AIStrategicPlanner.get_current_strategy(ai_key) == AIStrategicPlanner.Strategy.RAID:
		raid_chance *= 1.5
	if randi() % 100 >= int(raid_chance):
		return
	if _raid_cooldowns.get(faction_id, 0) > 0:
		return

	# Use strategic planner to find best target
	var result: Dictionary = AIStrategicPlanner.select_raid_target(ai_key, source_tiles)

	# ── Supply chokepoint consideration ──
	var strategy: int = AIStrategicPlanner.get_current_strategy(ai_key)
	if strategy == AIStrategicPlanner.Strategy.RAID:
		# Check for supply-cut targets that may outperform normal raid targets
		var human_pid: int = GameManager.get_human_player_id()
		var chokepoints: Array = AIStrategicPlanner.find_supply_chokepoints(human_pid)
		for cp in chokepoints:
			var cp_idx: int = cp["tile_index"]
			# Check if we have a source tile adjacent
			for src in source_tiles:
				if not GameManager.adjacency.has(src["index"]):
					continue
				if cp_idx in GameManager.adjacency[src["index"]]:
					var supply_score: float = AIStrategicPlanner.score_supply_cut_attack(ai_key, cp_idx)
					var current_best: float = result.get("score", 0.0)
					if supply_score > current_best:
						result = {"tile": GameManager.tiles[cp_idx], "score": supply_score, "source": src}
						EventBus.message_log.emit("[%s] 选择切断补给线目标 #%d (可孤立%d个据点)" % [ai_key, cp_idx, cp["isolation_count"]])
					break

	if result.is_empty():
		return

	var target: Dictionary = result["tile"]
	var source: Dictionary = result.get("source", source_tiles[0])
	var raid_strength: int = maxi(BalanceConfig.EVIL_RAID_MIN_STRENGTH, source.get("garrison", 0) / BalanceConfig.EVIL_RAID_STRENGTH_DIVISOR)

	# At tier 2+, bonus raid troops
	var tier: int = AIScaling.get_tier(ai_key)
	if tier >= 2:
		raid_strength += tier * 2

	# Build formation-aware army composition for the raid
	var _raid_composition: Array = _pick_raid_composition(faction_id, raid_strength)

	var target_garrison: int = target.get("garrison", 0)

	# Choose tactical directive for the raid (weather-adjusted)
	var directive: int = AIStrategicPlanner.choose_tactical_directive(ai_key, true, raid_strength, target_garrison)
	directive = _adjust_directive_for_weather(directive, ai_key)
	var directive_name: String = CombatResolver.DIRECTIVE_DATA.get(directive, {}).get("name", "")
	var directive_suffix: String = ""
	if directive_name != "" and directive_name != "无":
		directive_suffix = " [战术:%s]" % directive_name

	EventBus.message_log.emit("[color=orange]敌对军团突袭据点#%d! (兵力: %d)%s[/color]" % [target["index"], raid_strength, directive_suffix])

	# Apply directive multipliers to raid
	var atk_mult: float = 1.0
	var def_mult: float = 1.0
	var dir_data: Dictionary = CombatResolver.DIRECTIVE_DATA.get(directive, {})
	atk_mult = dir_data.get("atk_mult", 1.0)

	var effective_strength: float = float(raid_strength) * atk_mult

	if effective_strength > float(target_garrison):
		target["garrison"] = maxi(0, target_garrison - int(effective_strength / float(BalanceConfig.EVIL_RAID_DAMAGE_DIVISOR)))
		EventBus.message_log.emit("[color=red]突袭成功! 驻军损失严重[/color]")
		# Record this as a successful action for the player's memory
		AIStrategicPlanner.record_player_attack(ai_key, target["index"])
	else:
		target["garrison"] = maxi(0, target_garrison - 1)
		EventBus.message_log.emit("击退了敌方突袭, 驻军-1")

	_raid_cooldowns[faction_id] = 2  # Cooldown after raid


func _execute_diversion_raid(_player_id: int, source_tiles: Array, faction_id: int, target_tile: int) -> void:
	## Execute a diversion/feint raid on a specific target tile.
	if target_tile < 0 or target_tile >= GameManager.tiles.size():
		return
	var ai_key: String = _faction_to_ai_key(faction_id)
	if _raid_cooldowns.get(faction_id, 0) > 0:
		return

	if target_tile < 0 or target_tile >= GameManager.tiles.size():
		return
	var target: Dictionary = GameManager.tiles[target_tile]
	if target.get("owner_id", -1) < 0:
		return  # Not a player tile

	# Find closest source tile to launch the raid
	var best_source: Dictionary = {}
	for src in source_tiles:
		if not GameManager.adjacency.has(src["index"]):
			continue
		# Check if target is reachable (1 or 2 hops)
		if target_tile in GameManager.adjacency[src["index"]]:
			best_source = src
			break
		# 2-hop check
		for nb in GameManager.adjacency[src["index"]]:
			if GameManager.adjacency.has(nb) and target_tile in GameManager.adjacency[nb]:
				if best_source.is_empty():
					best_source = src
				break

	if best_source.is_empty():
		# Fallback: use strongest source tile
		if not source_tiles.is_empty():
			source_tiles.sort_custom(func(a, b): return a.get("garrison", 0) > b.get("garrison", 0))
			best_source = source_tiles[0]
		else:
			return

	var raid_strength: int = maxi(BalanceConfig.EVIL_RAID_MIN_STRENGTH, best_source.get("garrison", 0) / BalanceConfig.EVIL_RAID_STRENGTH_DIVISOR)
	var tier: int = AIScaling.get_tier(ai_key)
	if tier >= 2:
		raid_strength += tier * 2

	var target_garrison: int = target.get("garrison", 0)
	var directive: int = AIStrategicPlanner.choose_tactical_directive(ai_key, true, raid_strength, target_garrison)
	directive = _adjust_directive_for_weather(directive, ai_key)
	var dir_data: Dictionary = CombatResolver.DIRECTIVE_DATA.get(directive, {})
	var atk_mult: float = dir_data.get("atk_mult", 1.0)
	var effective_strength: float = float(raid_strength) * atk_mult

	EventBus.message_log.emit("[color=orange][%s] 战术奇袭据点#%d! (兵力: %d)[/color]" % [ai_key, target_tile, raid_strength])

	if effective_strength > float(target_garrison):
		target["garrison"] = maxi(0, target_garrison - int(effective_strength / float(BalanceConfig.EVIL_RAID_DAMAGE_DIVISOR)))
		EventBus.message_log.emit("[color=red]奇袭成功! 后方据点驻军损失严重[/color]")
		AIStrategicPlanner.record_player_attack(ai_key, target_tile)
		AIStrategicPlanner.record_diversion_result(ai_key, true)
	else:
		target["garrison"] = maxi(0, target_garrison - 1)
		EventBus.message_log.emit("击退了敌方奇袭, 驻军-1")
		AIStrategicPlanner.record_diversion_result(ai_key, false)

	_raid_cooldowns[faction_id] = 2


func _try_legacy_raid(player_id: int, source_tiles: Array, faction_id: int) -> void:
	## Fallback raid logic for non-strategic turns.
	var ai_key: String = _faction_to_ai_key(faction_id)
	if randi() % 100 >= int(float(BalanceConfig.EVIL_RAID_CHANCE_PCT) * AIScaling.get_personality_mod(ai_key, "raid_chance_mult")):
		return

	# Collect adjacent player tiles from all source tiles
	var targets: Array = []
	for src in source_tiles:
		if not GameManager.adjacency.has(src["index"]):
			continue
		for nb_idx in GameManager.adjacency[src["index"]]:
			if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] == player_id:
				var already: bool = false
				for t in targets:
					if t["tile"]["index"] == GameManager.tiles[nb_idx]["index"]:
						already = true
						break
				if not already:
					targets.append({"tile": GameManager.tiles[nb_idx], "source": src})

	if targets.is_empty():
		return

	# Pick weakest target instead of random
	targets.sort_custom(func(a, b): return a["tile"].get("garrison", 0) < b["tile"].get("garrison", 0))
	var target: Dictionary = targets[0]["tile"]
	var source: Dictionary = targets[0]["source"]

	var raid_strength: int = maxi(BalanceConfig.EVIL_RAID_MIN_STRENGTH, source.get("garrison", 0) / BalanceConfig.EVIL_RAID_STRENGTH_DIVISOR)
	var target_garrison: int = target.get("garrison", 0)

	EventBus.message_log.emit("[color=orange]敌对军团突袭据点#%d! (兵力: %d)[/color]" % [target["index"], raid_strength])

	if raid_strength > target_garrison:
		target["garrison"] = maxi(0, target_garrison - raid_strength / BalanceConfig.EVIL_RAID_DAMAGE_DIVISOR)
		EventBus.message_log.emit("[color=red]突袭成功! 驻军损失严重[/color]")
	else:
		target["garrison"] = maxi(0, target_garrison - 1)
		EventBus.message_log.emit("击退了敌方突袭, 驻军-1")


func _consolidate_garrison(source_tiles: Array, _faction_id: int) -> void:
	## CONSOLIDATE strategy: redistribute garrison from safe interior to threatened border tiles.
	var border_tiles: Array = []
	var interior_tiles: Array = []

	for tile in source_tiles:
		var on_border: bool = false
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] >= 0:
					on_border = true
					break
		if on_border:
			border_tiles.append(tile)
		else:
			interior_tiles.append(tile)

	if border_tiles.is_empty() or interior_tiles.is_empty():
		return

	# Transfer from interior to border
	var transferred: int = 0
	for donor in interior_tiles:
		if donor.get("garrison", 0) > 3:
			var transfer: int = mini(2, donor["garrison"] - 3)
			donor["garrison"] -= transfer
			transferred += transfer

	if transferred <= 0:
		return

	# Sort border tiles by garrison ascending (weakest first)
	border_tiles.sort_custom(func(a, b): return a.get("garrison", 0) < b.get("garrison", 0))
	var per_tile: int = maxi(1, transferred / maxi(1, border_tiles.size()))
	var remaining: int = transferred
	for tile in border_tiles:
		if remaining <= 0:
			break
		var give: int = mini(per_tile, remaining)
		tile["garrison"] += give
		remaining -= give


func _try_coordinated_attack(_player_id: int, faction_id: int, source_tiles: Array) -> void:
	## If AIStrategicPlanner has a coordinated target, add garrison pressure toward it.
	var coord_target: int = AIStrategicPlanner.get_coordinated_target()
	if coord_target < 0 or coord_target >= GameManager.tiles.size():
		return

	# Check if we have a tile adjacent to the coordinated target
	var adjacent_src: Dictionary = {}
	for src in source_tiles:
		if GameManager.adjacency.has(src["index"]):
			if coord_target in GameManager.adjacency[src["index"]]:
				adjacent_src = src
				break

	if adjacent_src.is_empty():
		return

	# Boost garrison on the adjacent tile for the coordinated push
	var ai_key: String = _faction_to_ai_key(faction_id)
	adjacent_src["garrison"] = adjacent_src.get("garrison", 0) + 3
	EventBus.message_log.emit("[%s] 调集兵力准备联合进攻据点#%d" % [AIScaling.FACTION_PERSONALITY.keys()[0] if ai_key == "" else ai_key, coord_target])


func _get_base_garrison(tile: Dictionary) -> int:
	## Returns the max garrison an AI faction tile should maintain.
	match tile.get("type", -1):
		GameManager.TileType.CORE_FORTRESS:
			return BalanceConfig.EVIL_GARRISON_CORE_FORTRESS
		GameManager.TileType.DARK_BASE:
			return BalanceConfig.EVIL_GARRISON_DARK_BASE
	return BalanceConfig.EVIL_GARRISON_DEFAULT

func get_faction_total_strength(faction_id: int) -> int:
	## Returns total garrison across all tiles of a faction (for difficulty display).
	var total: int = 0
	for tile in GameManager.tiles:
		if tile.get("original_faction", -1) == faction_id and tile["owner_id"] < 0:
			total += tile.get("garrison", 0)
	return total


func to_save_data() -> Dictionary:
	return {
		"raid_cooldowns": _raid_cooldowns.duplicate(),
	}


func from_save_data(data: Dictionary) -> void:
	var raw: Dictionary = data.get("raid_cooldowns", {}).duplicate()
	# Fix int keys after JSON round-trip (keys become strings)
	_raid_cooldowns = {}
	for k in raw:
		if k is String and k.is_valid_int():
			_raid_cooldowns[int(k)] = int(raw[k])
		else:
			_raid_cooldowns[k] = raw[k]


func _faction_to_ai_key(faction_id: int) -> String:
	## Map faction ID to AIScaling key.
	match faction_id:
		FactionData.FactionID.ORC: return "orc_ai"
		FactionData.FactionID.PIRATE: return "pirate_ai"
		FactionData.FactionID.DARK_ELF: return "dark_elf_ai"
	return ""


# ═══════════════ WEATHER-TACTICAL AWARENESS ═══════════════

func _get_weather_system() -> Variant:
	## Safe autoload access to WeatherSystem node.
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	if root and root.has_node("WeatherSystem"):
		return root.get_node("WeatherSystem")
	return null


func _adjust_directive_for_weather(directive: int, ai_key: String) -> int:
	## Adjust tactical directive choice based on current weather conditions.
	var ws: Node = _get_weather_system()
	if ws == null:
		return directive

	var weather: int = ws.current_weather  # WeatherSystem.Weather enum

	match weather:
		1, 3:  # RAIN or STORM — prefer defensive / guerrilla tactics, avoid offense-heavy
			if directive == CombatResolver.TacticalDirective.ALL_OUT or directive == CombatResolver.TacticalDirective.FOCUS_FIRE:
				# Try HOLD_LINE first, then GUERRILLA
				if AIScaling.can_use_directive(ai_key, CombatResolver.TacticalDirective.HOLD_LINE):
					return CombatResolver.TacticalDirective.HOLD_LINE
				if AIScaling.can_use_directive(ai_key, CombatResolver.TacticalDirective.GUERRILLA):
					return CombatResolver.TacticalDirective.GUERRILLA
		2:  # FOG — prefer AMBUSH
			if AIScaling.can_use_directive(ai_key, CombatResolver.TacticalDirective.AMBUSH):
				return CombatResolver.TacticalDirective.AMBUSH

	return directive


# ═══════════════ FORMATION-AWARE ARMY COMPOSITION ═══════════════

func _pick_raid_composition(faction_id: int, base_strength: int) -> Array:
	## Build a raid army composition that tries to achieve formation thresholds.
	## Returns an array of unit_type strings weighted toward formation requirements.
	var ai_key: String = _faction_to_ai_key(faction_id)
	var available: Array = AIStrategicPlanner._get_faction_available_units(faction_id)
	if available.is_empty():
		return []

	# Classify available units by archetype
	var heavy_infantry: Array = []
	var cavalry: Array = []
	var orc_units: Array = []
	var other_units: Array = []

	for unit_type in available:
		var base: String = CounterMatrix.TYPE_MAP.get(unit_type, "infantry")
		var is_orc: bool = unit_type.begins_with("orc_")
		if base == "heavy_infantry" or base == "tank":
			heavy_infantry.append(unit_type)
		if base == "cavalry":
			cavalry.append(unit_type)
		if is_orc:
			orc_units.append(unit_type)
		other_units.append(unit_type)

	# Determine preferred composition based on formation thresholds
	var composition: Array = []

	# Prefer IRON_WALL if we have heavy infantry types (need 3+ for formation)
	if heavy_infantry.size() > 0 and base_strength >= 3:
		@warning_ignore("integer_division")
		var heavy_count: int = mini(base_strength, maxi(3, base_strength / 2))
		for i in range(heavy_count):
			composition.append(heavy_infantry[i % heavy_infantry.size()])
		# Fill rest with other units
		var remaining: int = base_strength - heavy_count
		for i in range(remaining):
			composition.append(other_units[i % other_units.size()])
		return composition

	# Prefer CAVALRY_CHARGE if we have 2+ cavalry types
	if cavalry.size() > 0 and base_strength >= 2:
		@warning_ignore("integer_division")
		var cav_count: int = mini(base_strength, maxi(2, base_strength / 2))
		for i in range(cav_count):
			composition.append(cavalry[i % cavalry.size()])
		var remaining: int = base_strength - cav_count
		for i in range(remaining):
			composition.append(other_units[i % other_units.size()])
		return composition

	# Prefer BERSERKER_HORDE if we have 4+ orc units
	if orc_units.size() > 0 and base_strength >= 4 and faction_id == FactionData.FactionID.ORC:
		for i in range(base_strength):
			composition.append(orc_units[i % orc_units.size()])
		return composition

	# Fallback: use counter-composition from planner
	var counter: Array = AIStrategicPlanner.get_counter_composition(ai_key, faction_id)
	if counter.is_empty():
		return composition  # No counter data available, return what we have
	for i in range(base_strength):
		composition.append(counter[i % counter.size()])
	return composition


# ═══════════════ COUNTER-ESPIONAGE ═══════════════

func _get_espionage_system() -> Variant:
	## Safe autoload access to EspionageSystem node.
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	if root and root.has_node("EspionageSystem"):
		return root.get_node("EspionageSystem")
	return null


func _try_counter_espionage(player_id: int, faction_id: int) -> void:
	## If AI detects it has been scouted, invest in counter-intel.
	var es: Node = _get_espionage_system()
	if es == null:
		return

	# Check if any of our tiles have been revealed by the player's espionage
	var revealed: Array = es.get_revealed_tiles(player_id)
	if revealed.is_empty():
		return

	# Check if any revealed tiles belong to this faction
	var faction_scouted: bool = false
	for tile_idx in revealed:
		if tile_idx < GameManager.tiles.size():
			var tile: Dictionary = GameManager.tiles[tile_idx]
			if tile.get("original_faction", -1) == faction_id and tile["owner_id"] < 0:
				faction_scouted = true
				break

	if not faction_scouted:
		return

	# AI faction is being scouted — invest in counter-intelligence
	# Use a pseudo player_id for the AI faction (negative faction_id)
	var ai_pseudo_id: int = -(faction_id + 100)
	var ai_key: String = _faction_to_ai_key(faction_id)
	var current_ci: int = es.get_counter_intel(ai_pseudo_id)
	if current_ci < 30:
		# Directly boost counter-intel for the AI faction (no gold cost for AI)
		es.set_counter_intel(ai_pseudo_id, mini(50, current_ci + 5))
		EventBus.message_log.emit("[%s] 检测到敌方侦察活动, 加强反情报措施" % ai_key)

# ═══════════════ 势力差异化行动 ═══════════════
func _orc_faction_action(player_id: int, source_tiles: Array) -> void:
	## 兽人特有行动：当有多个源地块时，将守军向最前线集中（WAAAGH集结）
	if source_tiles.size() < 2:
		return
	# 找到距离玩家最近的地块（边界地块）
	var border_tiles: Array = []
	var interior_tiles: Array = []
	for tile in source_tiles:
		var is_border: bool = false
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] == player_id:
					is_border = true
					break
		if is_border:
			border_tiles.append(tile)
		else:
			interior_tiles.append(tile)
	if border_tiles.is_empty() or interior_tiles.is_empty():
		return
	# 从内部向边界转移1个守军（WAAAGH集结）
	interior_tiles.sort_custom(func(a, b): return a.get("garrison", 0) > b.get("garrison", 0))
	border_tiles.sort_custom(func(a, b): return a.get("garrison", 0) < b.get("garrison", 0))
	var donor: Dictionary = interior_tiles[0]
	var target: Dictionary = border_tiles[0]
	if donor.get("garrison", 0) > 3:
		donor["garrison"] -= 1
		target["garrison"] += 1
		EventBus.message_log.emit("[兽人部落] WAAAGH! 前线集结 #%d" % target["index"])

func _pirate_faction_action(player_id: int, source_tiles: Array) -> void:
	## 海盗特有行动：额外检查港口和贸易站，发动机会性突袭
	if source_tiles.is_empty():
		return
	# 查找相邻的港口/贸易站
	var harbor_targets: Array = []
	for src in source_tiles:
		if not GameManager.adjacency.has(src["index"]):
			continue
		for nb_idx in GameManager.adjacency[src["index"]]:
			if nb_idx >= GameManager.tiles.size():
				continue
			if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
				continue
			var nb: Dictionary = GameManager.tiles[nb_idx]
			if nb["owner_id"] != player_id:
				continue
			match nb.get("type", -1):
				GameManager.TileType.HARBOR, GameManager.TileType.TRADING_POST:
					harbor_targets.append({"tile": nb, "source": src})
	if harbor_targets.is_empty():
		return
	# 对港口发动机会性突袭（不受冷却限制，但伤害较低）
	var target_data: Dictionary = harbor_targets[randi() % harbor_targets.size()]
	var target: Dictionary = target_data["tile"]
	var source: Dictionary = target_data["source"]
	var raid_strength: int = maxi(2, source.get("garrison", 0) / 3)
	var target_garrison: int = target.get("garrison", 0)
	if raid_strength > target_garrison:
		target["garrison"] = maxi(0, target_garrison - 1)
		EventBus.message_log.emit("[color=orange][暗黑海盗] 港口突袭! 据点#%d 驻军-1[/color]" % target["index"])

func _dark_elf_faction_action(player_id: int, source_tiles: Array) -> void:
	## 暗精灵特有行动：精准打击孤立目标（支援较少的玩家地块）
	if source_tiles.is_empty():
		return
	# 找到支援最少的玩家地块（孤立目标）
	var isolated_targets: Array = []
	for src in source_tiles:
		if not GameManager.adjacency.has(src["index"]):
			continue
		for nb_idx in GameManager.adjacency[src["index"]]:
			if nb_idx >= GameManager.tiles.size():
				continue
			if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
				continue
			var nb: Dictionary = GameManager.tiles[nb_idx]
			if nb["owner_id"] != player_id:
				continue
			# 计算该地块的友方支援数
			var support: int = 0
			if GameManager.adjacency.has(nb_idx):
				for nb2_idx in GameManager.adjacency[nb_idx]:
					if nb2_idx < GameManager.tiles.size() and GameManager.tiles[nb2_idx]["owner_id"] == player_id:
						support += 1
			if support <= 1:  # 孤立目标（只有1个或0个友方邻居）
				isolated_targets.append({"tile": nb, "source": src, "support": support})
	if isolated_targets.is_empty():
		return
	# 对孤立目标发动精准打击
	isolated_targets.sort_custom(func(a, b): return a["support"] < b["support"])
	var target_data: Dictionary = isolated_targets[0]
	var target: Dictionary = target_data["tile"]
	var source: Dictionary = target_data["source"]
	var raid_strength: int = maxi(2, source.get("garrison", 0) / 3)
	var target_garrison: int = target.get("garrison", 0)
	if raid_strength > target_garrison:
		target["garrison"] = maxi(0, target_garrison - 1)
		EventBus.message_log.emit("[color=purple][黑暗精灵] 精准打击孤立据点#%d![/color]" % target["index"])
