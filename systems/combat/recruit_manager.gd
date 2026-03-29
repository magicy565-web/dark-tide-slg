extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## recruit_manager.gd — Army composition system (v0.9 / Phase 3)
##
## Manages per-player armies as Arrays of troop instances (from GameData).
## Each troop instance: { troop_id, soldiers, max_soldiers, commander_id, experience }
##
## Also handles tile garrison composition (replacing flat int garrisons).

# ── Player armies: { player_id: Array[Dictionary] } ──
var _armies: Dictionary = {}

# ── Tile garrisons: { tile_index: Array[Dictionary] } ──
var _garrisons: Dictionary = {}

# ── Wanderer armies on map: { tile_index: Array[Dictionary] } ──
var _wanderers: Dictionary = {}

# ── Rebel armies: { tile_index: Array[Dictionary] } ──
var _rebels: Dictionary = {}


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func reset() -> void:
	_armies.clear()
	_garrisons.clear()
	_wanderers.clear()
	_rebels.clear()


func init_player(player_id: int) -> void:
	_armies[player_id] = []


# ---------------------------------------------------------------------------
# Player Army API
# ---------------------------------------------------------------------------

## Returns the player's army (Array of troop instances). Returns a copy.
func get_army(player_id: int) -> Array:
	if not _armies.has(player_id):
		return []
	return _armies[player_id].duplicate(true)


## Returns the actual mutable army reference (internal use).
func _get_army_ref(player_id: int) -> Array:
	if not _armies.has(player_id):
		_armies[player_id] = []
	return _armies[player_id]


## Total soldiers across all troop instances for a player.
func get_total_soldiers(player_id: int) -> int:
	return GameData.get_army_total_soldiers(_get_army_ref(player_id))


## Combat power estimate.
func get_combat_power(player_id: int) -> int:
	return GameData.get_army_combat_power(_get_army_ref(player_id))


## Returns display-friendly army summary.
func get_army_summary(player_id: int) -> Array:
	return GameData.get_army_summary(_get_army_ref(player_id))


# ---------------------------------------------------------------------------
# Recruitment
# ---------------------------------------------------------------------------

## Returns recruitable troops at a tile for a player.
func get_available_units(player_id: int, tile: Dictionary) -> Array:
	var result: Array = []
	var faction_tag: String = _get_faction_tag(player_id)
	var tile_level: int = tile.get("level", 1)
	var recruitables: Array = GameData.get_recruitable_troops(faction_tag, tile_level)

	# Gather discounts
	var discount_pct: float = _get_recruit_discount(player_id)
	var cost_mult: float = RelicManager.get_recruit_cost_mult(player_id)

	for troop_id in recruitables:
		var td: Dictionary = GameData.get_troop_def(troop_id)
		if td.is_empty():
			continue
		var cost: Dictionary = GameData.calculate_recruit_cost(troop_id, discount_pct, cost_mult)
		result.append(_build_unit_entry(troop_id, td, cost, player_id))

	# ── Neutral faction troops (unlocked via taming) ──
	var neutral_troops: Array = QuestManager.get_all_unlocked_neutral_troops(player_id)
	for troop_id in neutral_troops:
		var td: Dictionary = GameData.get_troop_def(troop_id)
		if td.is_empty():
			continue
		var cost: Dictionary = GameData.calculate_recruit_cost(troop_id, 0.0, 1.0)
		result.append(_build_unit_entry(troop_id, td, cost, player_id))

	# ── Pirate mercenary hiring (any faction T1-T2 at 2x cost) ──
	if faction_tag == "pirate":
		var fp: Dictionary = GameData.FACTION_PASSIVES.get("pirate", {})
		if fp.get("mercenary_hiring", false):
			var merc_mult: float = fp.get("mercenary_cost_mult", 2.0)
			var merc_factions: Array = ["orc", "dark_elf", "human", "high_elf", "mage"]
			for mf in merc_factions:
				var merc_troops: Array = GameData.get_troops_by_faction(mf)
				for mid in merc_troops:
					var mtd: Dictionary = GameData.get_troop_def(mid)
					if mtd.is_empty() or mtd.get("tier", 1) > 2:
						continue
					if mtd.get("category", 0) != GameData.TroopCategory.FACTION:
						continue
					var mcost: Dictionary = GameData.calculate_recruit_cost(mid, 0.0, merc_mult)
					var entry: Dictionary = _build_unit_entry(mid, mtd, mcost, player_id)
					entry["is_mercenary"] = true
					result.append(entry)

	# ── Dark Elf slave fodder (free T0) ──
	if faction_tag == "dark_elf":
		var fp: Dictionary = GameData.FACTION_PASSIVES.get("dark_elf", {})
		if fp.get("slave_deploy", false):
			var slave_td: Dictionary = GameData.get_troop_def("slave_fodder")
			if not slave_td.is_empty():
				# Requires slaves resource
				var slave_count: int = ResourceManager.get_resource(player_id, "slaves")
				var scost: Dictionary = {"slaves": 1}
				var entry: Dictionary = _build_unit_entry("slave_fodder", slave_td, scost, player_id)
				entry["can_recruit"] = slave_count >= 1
				result.append(entry)

	return result


func _build_unit_entry(troop_id: String, td: Dictionary, cost: Dictionary, player_id: int) -> Dictionary:
	var affordable: bool = ResourceManager.can_afford(player_id, cost)
	# WAAAGH! cost check (not in ResourceManager)
	var waaagh_needed: int = cost.get("waaagh", 0)
	if waaagh_needed > 0 and OrcMechanic.get_waaagh(player_id) < waaagh_needed:
		affordable = false
	return {
		"troop_id": troop_id,
		"unit_id": troop_id,
		"name": td.get("name", troop_id),
		"base_atk": td.get("base_atk", 0),
		"base_def": td.get("base_def", 0),
		"max_soldiers": td.get("max_soldiers", 1),
		"troop_class": td.get("troop_class", 0),
		"row": td.get("row", "front"),
		"passive": td.get("passive", ""),
		"tier": td.get("tier", 1),
		"cost": cost,
		"can_recruit": affordable,
		"special": td.get("passive", "none"),
		"desc": td.get("desc", ""),
		"is_mercenary": false,
	}


## Recruit a troop. Creates a full squad at max_soldiers. Deducts cost.
# FIX(HIGH): 使用原子校验+扣除模式，防止并发招募时资源竞态条件
func recruit_unit(player_id: int, troop_id: String, tile: Dictionary) -> bool:
	var available: Array = get_available_units(player_id, tile)
	var found: Dictionary = {}
	for entry in available:
		if entry["troop_id"] == troop_id:
			found = entry
			break
	if found.is_empty() or not found["can_recruit"]:
		return false

	# Check population cap
	var pop_cap: int = _get_pop_cap(player_id)
	var army_ref: Array = _get_army_ref(player_id)
	if army_ref.size() >= pop_cap:
		EventBus.message_log.emit("[color=red]军团已满(%d/%d)[/color]" % [army_ref.size(), pop_cap])
		return false

	# 原子校验并扣除资源：try_spend内部同时检查余额并扣除，避免竞态
	if not ResourceManager.try_spend(player_id, found["cost"]):
		EventBus.message_log.emit("[color=red]资源不足，招募失败[/color]")
		return false

	# Orc WAAAGH! cost: deduct from OrcMechanic (not tracked in ResourceManager)
	var waaagh_cost: int = found["cost"].get("waaagh", 0)
	if waaagh_cost > 0:
		OrcMechanic.add_waaagh(player_id, -waaagh_cost)

	var instance: Dictionary = GameData.create_troop_instance(troop_id)
	army_ref.append(instance)

	# Sync total soldier count to ResourceManager for legacy compatibility
	_sync_army_count(player_id)

	EventBus.message_log.emit("招募了 %s (%d兵)" % [found["name"], instance["soldiers"]])
	return true


## Remove a specific troop instance by index.
func remove_troop(player_id: int, index: int) -> void:
	var army_ref: Array = _get_army_ref(player_id)
	if index >= 0 and index < army_ref.size():
		army_ref.remove_at(index)
		_sync_army_count(player_id)


## Apply combat losses to a player's army.
func apply_combat_losses(player_id: int, total_losses: int) -> int:
	var army_ref: Array = _get_army_ref(player_id)
	var actual: int = GameData.apply_army_losses(army_ref, total_losses)
	_sync_army_count(player_id)
	return actual


## Merge reinforcements into army.
func reinforce_army(player_id: int, reinforcements: Array) -> void:
	var army_ref: Array = _get_army_ref(player_id)
	GameData.merge_into_army(army_ref, reinforcements)
	_sync_army_count(player_id)


## v4.4: Heal army squads — distribute healing to most-damaged squads first.
## Returns total soldiers actually healed.
func heal_army_squads(player_id: int, amount: int) -> int:
	var army_ref: Array = _get_army_ref(player_id)
	if army_ref.is_empty():
		return 0
	var total_healed: int = 0
	var remaining: int = amount
	# Sort squads by damage (most damaged first) — work on indices to mutate in-place
	var sorted_indices: Array = range(army_ref.size())
	sorted_indices.sort_custom(func(a: int, b: int) -> bool:
		var da: int = army_ref[a].get("max_soldiers", army_ref[a]["soldiers"]) - army_ref[a]["soldiers"]
		var db: int = army_ref[b].get("max_soldiers", army_ref[b]["soldiers"]) - army_ref[b]["soldiers"]
		return da > db
	)
	for idx in sorted_indices:
		if remaining <= 0:
			break
		var troop: Dictionary = army_ref[idx]
		var max_s: int = troop.get("max_soldiers", troop["soldiers"])
		var missing: int = max_s - troop["soldiers"]
		if missing <= 0:
			continue
		var heal: int = mini(missing, remaining)
		troop["soldiers"] += heal
		remaining -= heal
		total_healed += heal
	if total_healed > 0:
		_sync_army_count(player_id)
	return total_healed


## Build combat unit array for CombatResolver (backward compatible format).
## Includes synergy bonuses, veterancy, and aura from T4 troops.
func get_combat_units(player_id: int) -> Array:
	var result: Array = []
	var army_ref: Array = _get_army_ref(player_id)
	# Compute tier mechanic bonuses
	var syn_bonuses: Dictionary = GameData.compute_synergy_bonuses(army_ref)
	var aura: Dictionary = GameData.compute_aura_bonuses(army_ref)
	for idx in range(army_ref.size()):
		var troop: Dictionary = army_ref[idx]
		var td: Dictionary = GameData.get_troop_def(troop["troop_id"])
		if td.is_empty():
			continue
		# Base stats + veterancy
		var eff_atk: int = GameData.get_effective_atk(troop)
		var eff_def: int = GameData.get_effective_def(troop)
		# + synergy
		var syn: Dictionary = syn_bonuses.get(idx, {})
		eff_atk += syn.get("atk", 0)
		eff_def += syn.get("def", 0)
		# + aura (T4 buff)
		eff_atk += aura.get("atk", 0)
		eff_def += aura.get("def", 0)
		var row_int: int = td.get("row", GameData.Row.FRONT)
		var row_str: String = "back" if row_int == GameData.Row.BACK else "front"
		result.append({
			"type": troop["troop_id"],
			"atk": eff_atk,
			"def": eff_def,
			"hp": troop["soldiers"],
			"special": td.get("passive", "none"),
			"count": troop["soldiers"],
			"soldiers": troop["soldiers"],
			"troop_class": td.get("troop_class", GameData.TroopClass.ASHIGARU),
			"row": row_str,
			"row_int": 0 if row_str == "front" else 1,
			"max_soldiers": troop.get("max_soldiers", td["max_soldiers"]),
			"tier": td.get("tier", 1),
			"synergy": syn.get("synergy_name", ""),
			"experience": troop.get("experience", 0),
			"spd": td.get("spd", 5),
			"int_stat": td.get("int_stat", 0),
			"hero_id": troop.get("commander_id", ""),
		})
	# Reset ability_used flags for the upcoming battle
	for troop in army_ref:
		troop["ability_used"] = false
	return result


# ---------------------------------------------------------------------------
# Garrison API (tile-based troop composition)
# ---------------------------------------------------------------------------

## Set garrison for a tile from template.
func set_garrison_from_template(tile_index: int, template_id: String) -> void:
	_garrisons[tile_index] = GameData.create_garrison_from_template(template_id)


## Set garrison directly.
func set_garrison(tile_index: int, troops: Array) -> void:
	_garrisons[tile_index] = troops


## Get garrison troops for a tile.
func get_garrison(tile_index: int) -> Array:
	if not _garrisons.has(tile_index):
		return []
	return _garrisons[tile_index].duplicate(true)


## Get garrison reference (internal).
func _get_garrison_ref(tile_index: int) -> Array:
	if not _garrisons.has(tile_index):
		_garrisons[tile_index] = []
	return _garrisons[tile_index]


## Total garrison soldiers at a tile.
func get_garrison_strength(tile_index: int) -> int:
	return GameData.get_army_total_soldiers(_get_garrison_ref(tile_index))


## Get garrison combat units (for CombatResolver).
func get_garrison_combat_units(tile_index: int) -> Array:
	var result: Array = []
	for troop in _get_garrison_ref(tile_index):
		var td: Dictionary = GameData.get_troop_def(troop["troop_id"])
		if td.is_empty():
			continue
		var gar_row_int: int = td.get("row", GameData.Row.FRONT)
		var gar_row_str: String = "back" if gar_row_int == GameData.Row.BACK else "front"
		result.append({
			"type": troop["troop_id"],
			"atk": td["base_atk"],
			"def": td["base_def"],
			"hp": troop["soldiers"],
			"special": td.get("passive", "none"),
			"count": troop["soldiers"],
			"soldiers": troop["soldiers"],
			"troop_class": td.get("troop_class", GameData.TroopClass.ASHIGARU),
			"row": gar_row_str,
			"max_soldiers": troop.get("max_soldiers", td["max_soldiers"]),
			"spd": td.get("spd", 5),
			"int_stat": td.get("int_stat", 0),
			"hero_id": troop.get("commander_id", ""),
		})
	return result


## Apply combat losses to garrison.
func apply_garrison_losses(tile_index: int, total_losses: int) -> int:
	var garrison_ref: Array = _get_garrison_ref(tile_index)
	return GameData.apply_army_losses(garrison_ref, total_losses)


## Clear garrison (tile captured).
func clear_garrison(tile_index: int) -> void:
	_garrisons.erase(tile_index)


## Reinforce garrison.
func reinforce_garrison(tile_index: int, reinforcements: Array) -> void:
	var garrison_ref: Array = _get_garrison_ref(tile_index)
	GameData.merge_into_army(garrison_ref, reinforcements)


## Garrison display summary.
func get_garrison_summary(tile_index: int) -> Array:
	return GameData.get_army_summary(_get_garrison_ref(tile_index))


# ---------------------------------------------------------------------------
# Wanderer Army API
# ---------------------------------------------------------------------------

## Spawn wanderers at a tile.
func spawn_wanderer(tile_index: int) -> void:
	var army: Array = GameData.spawn_wanderer_army()
	if not army.is_empty():
		_wanderers[tile_index] = army


## Get wanderer army at tile.
func get_wanderer(tile_index: int) -> Array:
	return _wanderers.get(tile_index, [])


## Remove wanderer (defeated or absorbed).
func clear_wanderer(tile_index: int) -> void:
	_wanderers.erase(tile_index)


## Get all tiles with wanderers.
func get_wanderer_tiles() -> Array:
	return _wanderers.keys()


## Wanderer combat units (for resolver).
func get_wanderer_combat_units(tile_index: int) -> Array:
	var result: Array = []
	for troop in get_wanderer(tile_index):
		var td: Dictionary = GameData.get_troop_def(troop["troop_id"])
		if td.is_empty():
			continue
		var wnd_row_int: int = td.get("row", GameData.Row.FRONT)
		var wnd_row_str: String = "back" if wnd_row_int == GameData.Row.BACK else "front"
		result.append({
			"type": troop["troop_id"],
			"atk": td["base_atk"],
			"def": td["base_def"],
			"hp": troop["soldiers"],
			"special": td.get("passive", "none"),
			"count": troop["soldiers"],
			"soldiers": troop["soldiers"],
			"max_soldiers": troop.get("max_soldiers", td.get("max_soldiers", troop.get("soldiers", 10))),
			"troop_class": td.get("troop_class", GameData.TroopClass.ASHIGARU),
			"row": wnd_row_str,
			"spd": td.get("spd", 5),
			"int_stat": td.get("int_stat", 0),
			"hero_id": troop.get("commander_id", ""),
		})
	return result


# ---------------------------------------------------------------------------
# Rebel Army API
# ---------------------------------------------------------------------------

## Try to spawn a rebel army at a tile (based on order value).
func try_spawn_rebel(tile_index: int, order_value: int) -> bool:
	if _rebels.has(tile_index):
		return false
	var army: Array = GameData.spawn_rebel_army(order_value)
	if not army.is_empty():
		_rebels[tile_index] = army
		return true
	return false


## Get rebel army at tile.
func get_rebel(tile_index: int) -> Array:
	return _rebels.get(tile_index, [])


## Remove rebel army.
func clear_rebel(tile_index: int) -> void:
	_rebels.erase(tile_index)


## Get all tiles with rebel armies.
func get_rebel_tiles() -> Array:
	return _rebels.keys()


## Rebel combat units (for resolver).
func get_rebel_combat_units(tile_index: int) -> Array:
	var result: Array = []
	for troop in get_rebel(tile_index):
		var td: Dictionary = GameData.get_troop_def(troop["troop_id"])
		if td.is_empty():
			continue
		var reb_row_int: int = td.get("row", GameData.Row.FRONT)
		var reb_row_str: String = "back" if reb_row_int == GameData.Row.BACK else "front"
		result.append({
			"type": troop["troop_id"],
			"atk": td["base_atk"],
			"def": td["base_def"],
			"hp": troop["soldiers"],
			"special": td.get("passive", "none"),
			"count": troop["soldiers"],
			"soldiers": troop["soldiers"],
			"max_soldiers": troop.get("max_soldiers", td.get("max_soldiers", troop.get("soldiers", 10))),
			"troop_class": td.get("troop_class", GameData.TroopClass.ASHIGARU),
			"row": reb_row_str,
			"spd": td.get("spd", 5),
			"int_stat": td.get("int_stat", 0),
			"hero_id": troop.get("commander_id", ""),
		})
	return result


# ---------------------------------------------------------------------------
# Legacy compatibility — remove_units (old API)
# ---------------------------------------------------------------------------

## Backward compat: remove units by type + amount (kills soldiers, not instances).
func remove_units(player_id: int, unit_id: String, amount: int) -> void:
	var army_ref: Array = _get_army_ref(player_id)
	var remaining: int = amount
	var i: int = army_ref.size() - 1
	while i >= 0 and remaining > 0:
		if army_ref[i]["troop_id"] == unit_id:
			var kill: int = mini(remaining, army_ref[i]["soldiers"])
			army_ref[i]["soldiers"] -= kill
			remaining -= kill
			if army_ref[i]["soldiers"] <= 0:
				army_ref.remove_at(i)
		i -= 1
	_sync_army_count(player_id)


## Backward compat: get army composition as {troop_id: soldier_count}.
func get_army_composition(player_id: int) -> Dictionary:
	var result: Dictionary = {}
	for troop in _get_army_ref(player_id):
		var tid: String = troop["troop_id"]
		result[tid] = result.get(tid, 0) + troop["soldiers"]
	return result


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _get_faction_tag(player_id: int) -> String:
	var faction_id: int = GameManager.get_player_faction(player_id)
	match faction_id:
		FactionData.FactionID.ORC: return "orc"
		FactionData.FactionID.PIRATE: return "pirate"
		FactionData.FactionID.DARK_ELF: return "dark_elf"
	return "orc"


func _get_recruit_discount(player_id: int) -> float:
	var discount: float = 0.0
	# Training ground building discount
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) != player_id:
			continue
		if tile.get("building_id", "") == "training_ground":
			var bld_level: int = tile.get("building_level", 1)
			var effects: Dictionary = BuildingRegistry.get_building_effects("training_ground", bld_level)
			discount = maxf(discount, float(effects.get("recruit_discount", 0)))
	# NPC discount
	var npc_bonuses: Dictionary = NpcManager.get_active_skill_bonuses(player_id)
	discount += float(npc_bonuses.get("recruit_discount", 0))
	return discount


func _get_pop_cap(player_id: int) -> int:
	## Max number of troop squads (instances) a player can have.
	## Base 3 + 1 per 5 tiles owned.
	var owned_tiles: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			owned_tiles += 1
	var base: int = 3 + (owned_tiles / 5)
	# v4.4: garrison_bonus — equipment passive increases troop cap
	if player_id == GameManager.get_human_player_id():
		for hid in HeroSystem.recruited_heroes:
			if HeroSystem.has_equipment_passive(hid, "garrison_bonus"):
				base += int(HeroSystem.get_equipment_passive_value(hid, "garrison_bonus"))
				break  # Only apply once
	return base


func _sync_army_count(player_id: int) -> void:
	## Keep ResourceManager.army in sync (total soldiers) for HUD/legacy code.
	var total: int = get_total_soldiers(player_id)
	ResourceManager.set_army(player_id, total)


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func to_save_data() -> Dictionary:
	return {
		"armies": _armies.duplicate(true),
		"garrisons": _garrisons.duplicate(true),
		"wanderers": _wanderers.duplicate(true),
		"rebels": _rebels.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_armies = data.get("armies", {}).duplicate(true)
	_garrisons = data.get("garrisons", {}).duplicate(true)
	_wanderers = data.get("wanderers", {}).duplicate(true)
	_rebels = data.get("rebels", {}).duplicate(true)
	# Fix int keys that became strings after JSON round-trip
	_fix_int_keys(_armies)
	_fix_int_keys(_garrisons)
	_fix_int_keys(_wanderers)
	_fix_int_keys(_rebels)


func _fix_int_keys(dict: Dictionary) -> void:
	var fix_keys = []
	for k in dict.keys():
		if k is String and k.is_valid_int():
			fix_keys.append(k)
	for k in fix_keys:
		var int_key: int = int(k)
		if not dict.has(int_key):
			dict[int_key] = dict[k]
		dict.erase(k)


# ---------------------------------------------------------------------------
# Fatigue & Veterancy Integration (v6.0)
# ---------------------------------------------------------------------------

## Get army fatigue level for display.
func get_army_fatigue(player_id: int) -> int:
	return EnvironmentSystem.get_fatigue(player_id)


## Get fatigue tier info for army.
func get_army_fatigue_tier(player_id: int) -> Dictionary:
	return EnvironmentSystem.get_fatigue_tier(player_id)


## Rest army to reduce fatigue (call when army is in friendly territory).
func rest_army_at_territory(player_id: int) -> void:
	EnvironmentSystem.rest_army(player_id)


## Get veterancy info for a specific troop unit.
func get_troop_veterancy(unit_id: String) -> Dictionary:
	return {
		"bonuses": EnvironmentSystem.get_veterancy_bonuses(unit_id),
		"rank": EnvironmentSystem.VETERANCY_NAMES.get(EnvironmentSystem.check_promotion(unit_id), "新兵"),
		"battles": EnvironmentSystem.get_unit_battles(unit_id),
	}
