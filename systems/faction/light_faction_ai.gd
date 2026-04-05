## light_faction_ai.gd - Light faction mechanics (v0.7)
## Handles Human city defense, Elf magic barrier, Mage mana pool.
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Human Kingdom: City Defense ──
# Wall HP must be depleted before combat. Wall regens +3/turn.
var _wall_hp: Dictionary = {}  # tile_index -> current wall HP

# ── Elf: Magic Barrier ──
# First attack absorbs 30% damage. Ley line bonuses from adjacent elf tiles.
var _barrier_active: Dictionary = {}  # tile_index -> bool (refreshes each turn)

# ── Mage: Shared Mana Pool ──
var _mana_pool: Dictionary = {}  # player_id (light faction pseudo-id) -> current mana
var _mana_max: int = 0
const MAGE_FACTION_ID: int = -100  # pseudo player ID for mage faction

# ── Fortress Fall Effect Flags ──
var _human_reinforcement_disabled: bool = false
var _teleport_disabled: bool = false


func _ready() -> void:
	pass


func reset() -> void:
	_wall_hp.clear()
	_barrier_active.clear()
	_mana_pool.clear()
	_human_reinforcement_disabled = false
	_teleport_disabled = false


func to_save_data() -> Dictionary:
	return {
		"wall_hp": _wall_hp.duplicate(),
		"barrier_active": _barrier_active.duplicate(),
		"mana_pool": _mana_pool.duplicate(),
		"mana_max": _mana_max,
		"human_reinforcement_disabled": _human_reinforcement_disabled,
		"teleport_disabled": _teleport_disabled,
	}


func _fix_int_keys(dict: Dictionary) -> void:
	var fix_keys = []
	for k in dict.keys():
		if k is String and k.is_valid_int():
			fix_keys.append(k)
	for k in fix_keys:
		dict[int(k)] = dict[k]
		dict.erase(k)


func from_save_data(data: Dictionary) -> void:
	# Deep-duplicate to avoid mutating the save source (Bug fix Round 3)
	_wall_hp = data.get("wall_hp", {}).duplicate(true)
	_fix_int_keys(_wall_hp)
	_barrier_active = data.get("barrier_active", {}).duplicate(true)
	_fix_int_keys(_barrier_active)
	_mana_pool = data.get("mana_pool", {}).duplicate(true)
	_fix_int_keys(_mana_pool)
	_mana_max = data.get("mana_max", 0)
	_human_reinforcement_disabled = data.get("human_reinforcement_disabled", false)
	_teleport_disabled = data.get("teleport_disabled", false)


# ═══════════════ INITIALIZATION ═══════════════

func init_light_defenses() -> void:
	## Called after map generation to set up light faction defenses.
	for tile in GameManager.tiles:
		if tile == null:
			continue
		var lf: int = tile.get("light_faction", -1)
		if lf < 0:
			continue

		match lf:
			FactionData.LightFaction.HUMAN_KINGDOM:
				_init_human_defense(tile)
			FactionData.LightFaction.HIGH_ELVES:
				_init_elf_barrier(tile)
			FactionData.LightFaction.MAGE_TOWER:
				_init_mage_tile(tile)

	# Count mage tiles for mana pool
	var mage_tile_count: int = 0
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) == FactionData.LightFaction.MAGE_TOWER and tile.get("owner_id", -1) < 0:
			mage_tile_count += 1
	_mana_max = mage_tile_count * BalanceConfig.MANA_PER_MAGE_TILE  # mana capacity per tile
	_mana_pool[MAGE_FACTION_ID] = _mana_max


func _init_human_defense(tile: Dictionary) -> void:
	var wall_hp: int = BalanceConfig.WALL_HP_VILLAGE  # Default village
	match tile["type"]:
		GameManager.TileType.LIGHT_STRONGHOLD:
			wall_hp = BalanceConfig.WALL_HP_STRONGHOLD
		GameManager.TileType.CORE_FORTRESS:
			wall_hp = BalanceConfig.WALL_HP_CORE_FORTRESS
	# v3.0: Apply difficulty scaling to wall HP
	wall_hp = int(float(wall_hp) * BalanceManager.get_wall_hp_mult())
	_wall_hp[tile["index"]] = wall_hp


func _init_elf_barrier(tile: Dictionary) -> void:
	_barrier_active[tile["index"]] = true


func _init_mage_tile(_tile: Dictionary) -> void:
	pass  # Mage tiles use the shared pool


# ═══════════════ HUMAN: CITY DEFENSE ═══════════════

func get_wall_hp(tile_index: int) -> int:
	return _wall_hp.get(tile_index, 0)


func has_wall(tile_index: int) -> bool:
	return _wall_hp.get(tile_index, 0) > 0


func damage_wall(tile_index: int, damage: int) -> int:
	## Apply damage to wall. Returns remaining damage after wall absorbs.
	if not _wall_hp.has(tile_index) or _wall_hp[tile_index] <= 0:
		return damage
	var absorbed: int = mini(damage, _wall_hp[tile_index])
	_wall_hp[tile_index] -= absorbed
	var remaining: int = damage - absorbed
	if _wall_hp[tile_index] <= 0:
		EventBus.message_log.emit("[color=yellow]城墙被攻破![/color]")
	else:
		EventBus.message_log.emit("城墙承受了 %d 伤害 (剩余HP: %d)" % [absorbed, _wall_hp[tile_index]])
	return remaining


func repair_wall(tile_index: int, amount: int) -> void:
	## Repair wall HP on a player-owned tile (from fortification building effect).
	if not _wall_hp.has(tile_index):
		_wall_hp[tile_index] = 0
	var cap: int = BalanceConfig.WALL_HP_VILLAGE
	if tile_index < GameManager.tiles.size():
		var tile: Dictionary = GameManager.tiles[tile_index]
		match tile.get("type", -1):
			GameManager.TileType.LIGHT_STRONGHOLD:
				cap = BalanceConfig.WALL_HP_STRONGHOLD
			GameManager.TileType.CORE_FORTRESS:
				cap = BalanceConfig.WALL_HP_CORE_FORTRESS
		# Add wall_hp_bonus from building
		var bld: String = tile.get("building_id", "")
		var bld_level: int = tile.get("building_level", 1)
		if bld != "":
			var effects: Dictionary = BuildingRegistry.get_building_effects(bld, bld_level)
			cap += int(effects.get("wall_hp_bonus", 0))
		# BUG FIX R7: apply difficulty scaling to repair cap, matching init_human_defense
		cap = int(float(cap) * BalanceManager.get_wall_hp_mult())
	var old_hp: int = _wall_hp[tile_index]
	_wall_hp[tile_index] = mini(cap, _wall_hp[tile_index] + amount)
	if _wall_hp[tile_index] > old_hp:
		EventBus.message_log.emit("城墙修复 +%d (HP: %d/%d)" % [_wall_hp[tile_index] - old_hp, _wall_hp[tile_index], cap])


func regen_walls() -> void:
	if _human_reinforcement_disabled:
		return
	var data: Dictionary = FactionData.LIGHT_FACTION_DATA[FactionData.LightFaction.HUMAN_KINGDOM]
	var regen: int = data["wall_regen_per_turn"]
	# v0.8.5: AI threat scaling wall bonus
	var wall_bonus: float = AIScaling.get_wall_bonus("human")
	# Seasonal factor: walls regen faster in defensive seasons (Winter)
	var seasonal_def: float = 2.0 - _get_seasonal_factor()  # inverse: Winter=1.3, Spring=0.8
	regen = maxi(1, int(float(regen) * seasonal_def))
	for tile in GameManager.tiles:
		if tile.get("light_faction", -1) != FactionData.LightFaction.HUMAN_KINGDOM:
			continue
		if tile["owner_id"] >= 0:
			continue
		var idx: int = tile["index"]
		if _wall_hp.has(idx):
			var cap: int = BalanceConfig.WALL_HP_VILLAGE
			match tile["type"]:
				GameManager.TileType.LIGHT_STRONGHOLD:
					cap = BalanceConfig.WALL_HP_STRONGHOLD
				GameManager.TileType.CORE_FORTRESS:
					cap = BalanceConfig.WALL_HP_CORE_FORTRESS
			# BUG FIX R7: apply difficulty scaling to regen cap, matching init_human_defense
			cap = int(float(cap) * BalanceManager.get_wall_hp_mult())
			cap = int(float(cap) * (1.0 + wall_bonus))  # Apply wall bonus to cap
			_wall_hp[idx] = mini(cap, _wall_hp[idx] + regen)


# ═══════════════ ELF: MAGIC BARRIER ═══════════════

func is_barrier_active(tile_index: int) -> bool:
	return _barrier_active.get(tile_index, false)


func apply_barrier_absorption(tile_index: int, damage: float) -> float:
	if not _barrier_active.get(tile_index, false):
		return damage
	var base_absorb: float = BalanceConfig.BARRIER_BASE_ABSORPTION
	# Ley line bonus: +15% per adjacent uncaptured elf tile
	var ley_bonus: int = 0
	if GameManager.adjacency.has(tile_index):
		for neighbor in GameManager.adjacency[tile_index]:
			if neighbor < GameManager.tiles.size():
				var nb_tile: Dictionary = GameManager.tiles[neighbor]
				if nb_tile.get("light_faction", -1) == FactionData.LightFaction.HIGH_ELVES and nb_tile["owner_id"] < 0:
					ley_bonus += 1
	var total_absorb: float = base_absorb + (float(ley_bonus) * BalanceConfig.BARRIER_LEY_LINE_BONUS)
	total_absorb = minf(total_absorb, BalanceConfig.BARRIER_MAX_ABSORPTION)  # Cap
	var absorbed: float = damage * total_absorb
	_barrier_active[tile_index] = false
	EventBus.message_log.emit("魔法屏障吸收了 %.0f 伤害! (灵脉加成: +%d%%)" % [absorbed, ley_bonus * 15])
	return damage - absorbed


func get_ley_line_bonus(tile_index: int) -> int:
	## Returns bonus from adjacent elf tiles.
	var data: Dictionary = FactionData.LIGHT_FACTION_DATA[FactionData.LightFaction.HIGH_ELVES]
	var bonus_per_adj: int = data["ley_line_bonus_per_adj"]
	var count: int = 0
	if GameManager.adjacency.has(tile_index):
		for neighbor in GameManager.adjacency[tile_index]:
			if neighbor < GameManager.tiles.size():
				var nb_tile: Dictionary = GameManager.tiles[neighbor]
				if nb_tile.get("light_faction", -1) == FactionData.LightFaction.HIGH_ELVES and nb_tile["owner_id"] < 0:
					count += 1
	return count * bonus_per_adj


func refresh_barriers() -> void:
	## Called each turn. Refresh barriers on uncaptured elf tiles.
	for tile in GameManager.tiles:
		if tile.get("light_faction", -1) != FactionData.LightFaction.HIGH_ELVES:
			continue
		if tile["owner_id"] >= 0:
			continue
		_barrier_active[tile["index"]] = true


# ═══════════════ MAGE: MANA POOL ═══════════════

func get_mana() -> int:
	return _mana_pool.get(MAGE_FACTION_ID, 0)


func regen_mana() -> void:
	var regen: int = 0
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) == FactionData.LightFaction.MAGE_TOWER and tile.get("owner_id", -1) < 0:
			regen += 3
	# Recalculate max (decreases as tiles are lost)
	var uncaptured_count: int = 0
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) == FactionData.LightFaction.MAGE_TOWER and tile.get("owner_id", -1) < 0:
			uncaptured_count += 1
	_mana_max = uncaptured_count * BalanceConfig.MANA_PER_MAGE_TILE
	# v0.9.0: mana_bonus equipment passive reduces enemy mana max & regen
	var mana_reduction: int = 0
	for hero in HeroSystem.get_available_heroes():
		if HeroSystem.has_equipment_passive(hero["id"], "mana_bonus"):
			mana_reduction += int(HeroSystem.get_equipment_passive_value(hero["id"], "mana_bonus"))
	if mana_reduction > 0:
		_mana_max = maxi(0, _mana_max - mana_reduction)
		regen = maxi(0, regen - 1)  # Also reduce regen by 1 per orb
	_mana_pool[MAGE_FACTION_ID] = mini(_mana_max, _mana_pool.get(MAGE_FACTION_ID, 0) + regen)


func can_cast_spell(spell_name: String) -> bool:
	var data: Dictionary = FactionData.LIGHT_FACTION_DATA[FactionData.LightFaction.MAGE_TOWER]
	var spells: Dictionary = data["spells"]
	if not spells.has(spell_name):
		return false
	return get_mana() >= spells[spell_name]["cost"]


func cast_spell(spell_name: String) -> bool:
	## AI casts a spell. Returns true if successful.
	if spell_name == "teleport" and _teleport_disabled:
		return false
	var data: Dictionary = FactionData.LIGHT_FACTION_DATA[FactionData.LightFaction.MAGE_TOWER]
	var spells: Dictionary = data["spells"]
	if not spells.has(spell_name):
		push_warning("LightFactionAI: cast_spell unknown spell '%s'" % spell_name)
		return false
	var cost: int = spells[spell_name]["cost"]
	if get_mana() < cost:
		return false
	_mana_pool[MAGE_FACTION_ID] -= cost
	EventBus.message_log.emit("[color=cyan]法师塔施放了 %s! (消耗%d法力)[/color]" % [spells[spell_name]["desc"], cost])
	return true


func apply_spell_effect(spell_name: String, target_tile_index: int) -> Dictionary:
	## Returns effect data for the spell.
	var result := {"type": spell_name, "success": false}
	# Validate tile index before applying any spell effect
	if target_tile_index < 0 or target_tile_index >= GameManager.tiles.size():
		push_warning("light_faction_ai: spell '%s' target_tile_index %d out of bounds (tiles: %d)" % [spell_name, target_tile_index, GameManager.tiles.size()])
		return result
	match spell_name:
		"teleport":
			# Teleport defenders to a tile
			result["success"] = true
			result["garrison_add"] = randi_range(BalanceConfig.SPELL_TELEPORT_GARRISON_MIN, BalanceConfig.SPELL_TELEPORT_GARRISON_MAX)
			if target_tile_index >= 0 and target_tile_index < GameManager.tiles.size():
				GameManager.tiles[target_tile_index]["garrison"] += result["garrison_add"]
			EventBus.message_log.emit("传送增援 +%d 守军" % result["garrison_add"])
		"barrier":
			# Add temporary defense
			result["success"] = true
			result["defense_bonus"] = BalanceConfig.SPELL_BARRIER_DEFENSE_BONUS
			if target_tile_index >= 0 and target_tile_index < GameManager.tiles.size():
				GameManager.tiles[target_tile_index]["garrison"] += result["defense_bonus"]
			EventBus.message_log.emit("魔法屏障: +%d 防御" % result["defense_bonus"])
		"barrage":
			# Damage attacking army
			result["success"] = true
			result["damage"] = randi_range(BalanceConfig.SPELL_BARRAGE_DAMAGE_MIN, BalanceConfig.SPELL_BARRAGE_DAMAGE_MAX)
			EventBus.message_log.emit("魔法弹幕造成 %d 伤害!" % result["damage"])
	return result


# ═══════════════ TURN TICK ═══════════════

func tick_light_factions() -> void:
	## Called each turn to update all light faction mechanics.
	regen_walls()
	refresh_barriers()
	regen_mana()
	# 光明势力驻军自动恢复（BUG FIX: 光明势力缺少garrison regen）
	regen_light_garrison()
	# Mage AI: try to cast spells on threatened tiles
	_mage_ai_cast()
	# 人类王国：主动将内部守军向前线集结（旧逻辑，保留兼容）
	human_kingdom_action()
	# v1.0: 人类王国AI完整系统 tick（动员度、英雄出击、圣战等）
	if HumanKingdomAI != null:
		HumanKingdomAI.tick(0)
	# v1.0: 人类王国事件链 tick（女骑士巡逻、圣战buff计时等）
	if HumanKingdomEvents != null:
		HumanKingdomEvents.tick(0)
	# 精灵族：屏障失效时重新激活
	high_elf_action()
	# Alliance coordination: light factions help each other against shared threats
	_try_light_faction_coordination()


func _mage_ai_cast() -> void:
	## Improved AI for mage spell casting. Priorities:
	## 1. Barrage - deal damage when mana >= 20 and player is adjacent
	## 2. Teleport - reinforce most threatened tile when mana >= 15
	## 3. Barrier - protect threatened mage tiles when mana >= 10
	var seasonal_factor: float = _get_seasonal_factor()

	# Priority 1: Barrage against player tiles (more aggressive in Spring/Summer)
	if can_cast_spell("barrage"):
		for tile in GameManager.tiles:
			if tile.get("light_faction", -1) != FactionData.LightFaction.MAGE_TOWER:
				continue
			if tile["owner_id"] >= 0:
				continue
			if GameManager.adjacency.has(tile["index"]):
				for nb in GameManager.adjacency[tile["index"]]:
					if nb < GameManager.tiles.size() and GameManager.tiles[nb]["owner_id"] >= 0:
						cast_spell("barrage")
						var effect: Dictionary = apply_spell_effect("barrage", nb)
						if effect.get("success", false):
							if nb < 0 or nb >= GameManager.tiles.size():
								return
							var target_tile: Dictionary = GameManager.tiles[nb]
							var dmg: int = effect.get("damage", 0)
							# v3.5: Scale barrage damage by difficulty aggression
							var aggr_mult: float = BalanceManager.get_ai_aggression()
							var scaled_dmg: float = float(dmg) * 0.6 * aggr_mult * seasonal_factor
							target_tile["garrison"] = maxi(0, target_tile.get("garrison", 0) - int(scaled_dmg))
							EventBus.message_log.emit("[法师塔] 魔法弹幕命中据点#%d! 驻军-%.0f" % [nb, scaled_dmg])
						return  # One spell per turn

	# Priority 2: Teleport to reinforce most threatened light tile
	if can_cast_spell("teleport") and not _teleport_disabled:
		var most_threatened_idx: int = -1
		var max_threat_score: int = 0
		for tile in GameManager.tiles:
			if tile == null:
				continue
			if tile.get("owner_id", -1) >= 0:
				continue
			if tile.get("light_faction", -1) < 0:
				continue
			var threat_score: int = 0
			if GameManager.adjacency.has(tile["index"]):
				for nb in GameManager.adjacency[tile["index"]]:
					if nb < GameManager.tiles.size() and GameManager.tiles[nb]["owner_id"] >= 0:
						threat_score += 1
			if threat_score > max_threat_score:
				max_threat_score = threat_score
				most_threatened_idx = tile["index"]
		if most_threatened_idx >= 0 and max_threat_score >= 2:
			# Seasonal: in defensive seasons (low factor), teleport more readily
			var teleport_threshold: int = 2 if seasonal_factor >= 1.0 else 1
			if max_threat_score >= teleport_threshold:
				cast_spell("teleport")
				apply_spell_effect("teleport", most_threatened_idx)
				return

	# Priority 3: Barrier on threatened mage tiles (existing logic)
	for tile in GameManager.tiles:
		if tile.get("light_faction", -1) != FactionData.LightFaction.MAGE_TOWER:
			continue
		if tile["owner_id"] >= 0:
			continue
		var is_threatened: bool = false
		if GameManager.adjacency.has(tile["index"]):
			for nb in GameManager.adjacency[tile["index"]]:
				if nb < GameManager.tiles.size() and GameManager.tiles[nb]["owner_id"] >= 0:
					is_threatened = true
					break
		if is_threatened and can_cast_spell("barrier"):
			cast_spell("barrier")
			apply_spell_effect("barrier", tile["index"])
			break


func disable_human_reinforcement() -> void:
	_human_reinforcement_disabled = true


func disable_teleport() -> void:
	_teleport_disabled = true


# ═══════════════ WEATHER / SEASON AWARENESS ═══════════════

func _get_weather_system() -> Variant:
	## Safe autoload access to WeatherSystem node.
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	if root and root.has_node("WeatherSystem"):
		return root.get_node("WeatherSystem")
	return null


func _get_seasonal_factor() -> float:
	## Returns a multiplier for light faction aggressiveness based on current season.
	## Spring: 1.2 (fresh start), Summer: 1.1, Autumn: 0.9, Winter: 0.7 (hunker down).
	var ws: Node = _get_weather_system()
	if ws == null:
		return 1.0
	match ws.current_season:
		0:  # SPRING
			return 1.2
		1:  # SUMMER
			return 1.1
		2:  # AUTUMN
			return 0.9
		3:  # WINTER
			return 0.7
	return 1.0


# ═══════════════ ALLIANCE COORDINATION ═══════════════

func _try_light_faction_coordination() -> void:
	## When multiple light factions share borders with the same evil faction attacker,
	## the one with the larger garrison reinforces the weaker one (20% of excess).
	# Build a map of light factions and their border threats from evil factions
	var faction_garrisons: Dictionary = {}  # light_faction_id -> { "total": int, "tiles": Array }
	var faction_threats: Dictionary = {}    # light_faction_id -> Set[evil_faction_id]

	for tile in GameManager.tiles:
		# BUG FIX R16: null check + safe dict access
		if tile == null:
			continue
		var lf: int = tile.get("light_faction", -1)
		if lf < 0 or tile.get("owner_id", -1) >= 0:
			continue  # Skip non-light or captured tiles

		if not faction_garrisons.has(lf):
			faction_garrisons[lf] = {"total": 0, "tiles": []}
		faction_garrisons[lf]["total"] += tile.get("garrison", 0)
		faction_garrisons[lf]["tiles"].append(tile)

		# Check adjacent tiles for evil faction threats
		if not faction_threats.has(lf):
			faction_threats[lf] = {}
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx >= GameManager.tiles.size():
					continue
				if nb_idx < 0 or nb_idx >= GameManager.tiles.size():
					return
				var nb = GameManager.tiles[nb_idx]
				# BUG FIX R16: null check + safe dict access
				if nb == null:
					continue
				var evil_fac: int = nb.get("original_faction", -1)
				if nb.get("owner_id", -1) < 0 and evil_fac >= 0:
					faction_threats[lf][evil_fac] = true

	# Find light factions that share the same evil attacker
	var light_factions: Array = faction_threats.keys()
	if light_factions.size() < 2:
		return

	for i in range(light_factions.size()):
		for j in range(i + 1, light_factions.size()):
			var lf_a: int = light_factions[i]
			var lf_b: int = light_factions[j]
			# Check if they share any common evil threat
			var shared_threat: bool = false
			for evil_id in faction_threats.get(lf_a, {}):
				if faction_threats.get(lf_b, {}).has(evil_id):
					shared_threat = true
					break
			if not shared_threat:
				continue

			# Determine which is stronger and which is weaker
			var garrison_a: int = faction_garrisons.get(lf_a, {}).get("total", 0)
			var garrison_b: int = faction_garrisons.get(lf_b, {}).get("total", 0)
			var stronger: int = lf_a if garrison_a >= garrison_b else lf_b
			var weaker: int = lf_b if garrison_a >= garrison_b else lf_a
			var stronger_garrison: int = maxi(garrison_a, garrison_b)
			var weaker_garrison: int = mini(garrison_a, garrison_b)

			# Only reinforce if there's a meaningful difference
			var excess: int = stronger_garrison - weaker_garrison
			if excess < 4:
				continue

			# Transfer 20% of excess from strongest tile to weakest tile of weaker faction
			@warning_ignore("integer_division")
			var transfer: int = maxi(1, excess / 5)  # 20% of excess
			var stronger_tiles: Array = faction_garrisons.get(stronger, {}).get("tiles", [])
			var weaker_tiles: Array = faction_garrisons.get(weaker, {}).get("tiles", [])
			if stronger_tiles.is_empty() or weaker_tiles.is_empty():
				continue

			# Find strongest donor tile and weakest recipient tile
			var donor: Dictionary = stronger_tiles[0]
			for t in stronger_tiles:
				if t.get("garrison", 0) > donor.get("garrison", 0):
					donor = t
			var recipient: Dictionary = weaker_tiles[0]
			for t in weaker_tiles:
				if t.get("garrison", 0) < recipient.get("garrison", 0):
					recipient = t

			# Only transfer if donor can afford it (keep at least 3 garrison)
			var actual_transfer: int = mini(transfer, maxi(0, donor.get("garrison", 0) - 3))
			if actual_transfer <= 0:
				continue

			donor["garrison"] -= actual_transfer
			recipient["garrison"] += actual_transfer
			EventBus.message_log.emit("[光明阵营] 联盟协调: 增援%d兵力至薄弱据点#%d" % [actual_transfer, recipient["index"]])

# ═══════════════ GARRISON REGEN & FACTION-SPECIFIC ACTIONS ═══════════════
func regen_light_garrison() -> void:
	## 光明势力驻军每回合自动恢复（类似邪恶势力的garrison regen）
	var seasonal_factor: float = _get_seasonal_factor()
	for tile in GameManager.tiles:
		if tile == null:
			continue
		var lf: int = tile.get("light_faction", -1)
		if lf < 0 or tile.get("owner_id", -1) >= 0:
			continue
		var base_garrison: int = 5
		match tile.get("type", -1):
			GameManager.TileType.CORE_FORTRESS: base_garrison = 20
			GameManager.TileType.LIGHT_STRONGHOLD: base_garrison = 12
			GameManager.TileType.LIGHT_VILLAGE: base_garrison = 8
			_: base_garrison = 5
		var wall_bonus: float = AIScaling.get_wall_bonus("human") if lf == FactionData.LightFaction.HUMAN_KINGDOM else 0.0
		base_garrison = int(float(base_garrison) * (1.0 + wall_bonus))
		var regen_rate: int = 1
		if seasonal_factor < 1.0:
			regen_rate = 2
		if tile.get("garrison", 0) < base_garrison:
			tile["garrison"] = mini(base_garrison, tile.get("garrison", 0) + regen_rate)
		var player_nearby: bool = false
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] >= 0:
					player_nearby = true
					break
		if player_nearby:
			tile["garrison"] = mini(tile.get("garrison", 0) + 1, base_garrison + 5)

func human_kingdom_action() -> void:
	## 人类王国主动行动：将内部守军向前线集结
	var border_tiles: Array = []
	var interior_tiles: Array = []
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != FactionData.LightFaction.HUMAN_KINGDOM:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		var is_border: bool = false
		if GameManager.adjacency.has(tile["index"]):
			for nb_idx in GameManager.adjacency[tile["index"]]:
				if nb_idx < GameManager.tiles.size() and GameManager.tiles[nb_idx]["owner_id"] >= 0:
					is_border = true
					break
		if is_border:
			border_tiles.append(tile)
		else:
			interior_tiles.append(tile)
	if border_tiles.is_empty() or interior_tiles.is_empty():
		return
	for interior in interior_tiles:
		var interior_garrison: int = interior.get("garrison", 0)
		if interior_garrison <= 3:
			continue
		border_tiles.sort_custom(func(a, b): return a.get("garrison", 0) < b.get("garrison", 0))
		var weakest_border: Dictionary = border_tiles[0]
		if weakest_border.get("garrison", 0) >= interior_garrison:
			continue
		interior["garrison"] -= 1
		weakest_border["garrison"] += 1
		EventBus.message_log.emit("[人类王国] 内部守军向边界增强 #%d" % weakest_border["index"])
		break

func high_elf_action() -> void:
	## 精灵族主动行动：当屏障失效时尝试重新激活
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != FactionData.LightFaction.HIGH_ELVES:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		var tile_idx: int = tile["index"]
		if not is_barrier_active(tile_idx):
			var ley_bonus: int = get_ley_line_bonus(tile_idx)
			if ley_bonus >= 5:
				_barrier_active[tile_idx] = true
				EventBus.message_log.emit("[精灵族] 魔法屏障重新激活 #%d" % tile_idx)
