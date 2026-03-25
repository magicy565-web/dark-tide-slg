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


func from_save_data(data: Dictionary) -> void:
	_wall_hp = data.get("wall_hp", {})
	_barrier_active = data.get("barrier_active", {})
	_mana_pool = data.get("mana_pool", {})
	_mana_max = data.get("mana_max", 0)
	_human_reinforcement_disabled = data.get("human_reinforcement_disabled", false)
	_teleport_disabled = data.get("teleport_disabled", false)


# ═══════════════ INITIALIZATION ═══════════════

func init_light_defenses() -> void:
	## Called after map generation to set up light faction defenses.
	for tile in GameManager.tiles:
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
		if tile.get("light_faction", -1) == FactionData.LightFaction.MAGE_TOWER and tile["owner_id"] < 0:
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
		if tile.get("light_faction", -1) == FactionData.LightFaction.MAGE_TOWER and tile["owner_id"] < 0:
			regen += 3
	# Recalculate max (decreases as tiles are lost)
	var uncaptured_count: int = 0
	for tile in GameManager.tiles:
		if tile.get("light_faction", -1) == FactionData.LightFaction.MAGE_TOWER and tile["owner_id"] < 0:
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
			GameManager.tiles[target_tile_index]["garrison"] += result["garrison_add"]
			EventBus.message_log.emit("传送增援 +%d 守军" % result["garrison_add"])
		"barrier":
			# Add temporary defense
			result["success"] = true
			result["defense_bonus"] = BalanceConfig.SPELL_BARRIER_DEFENSE_BONUS
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

	# Mage AI: try to cast spells on threatened tiles
	_mage_ai_cast()


func _mage_ai_cast() -> void:
	## Improved AI for mage spell casting. Priorities:
	## 1. Barrage - deal damage when mana >= 20 and player is adjacent
	## 2. Teleport - reinforce most threatened tile when mana >= 15
	## 3. Barrier - protect threatened mage tiles when mana >= 10

	# Priority 1: Barrage against player tiles
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
							var target_tile: Dictionary = GameManager.tiles[nb]
							var dmg: int = effect.get("damage", 0)
							# v3.5: Scale barrage damage by difficulty aggression
							var aggr_mult: float = BalanceManager.get_ai_aggression()
							var scaled_dmg: float = float(dmg) * 0.6 * aggr_mult
							target_tile["garrison"] = maxi(0, target_tile.get("garrison", 0) - int(scaled_dmg))
							EventBus.message_log.emit("[法师塔] 魔法弹幕命中据点#%d! 驻军-%.0f" % [nb, scaled_dmg])
						return  # One spell per turn

	# Priority 2: Teleport to reinforce most threatened light tile
	if can_cast_spell("teleport") and not _teleport_disabled:
		var most_threatened_idx: int = -1
		var max_threat_score: int = 0
		for tile in GameManager.tiles:
			if tile["owner_id"] >= 0:
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
