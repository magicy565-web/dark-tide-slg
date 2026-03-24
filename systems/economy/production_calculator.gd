## production_calculator.gd - Calculates per-turn income for a player (v0.7)
## Considers faction multipliers, buildings, slave allocation, order value, resource stations.
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Base production by tile type (v0.7 values) ──
const BASE_PRODUCTION: Dictionary = {
	"Village": {"gold": 10, "food": 5, "iron": 1},
	"Stronghold": {"gold": 15, "food": 3, "iron": 5},
	"NPC_Camp": {"gold": 5, "food": 2, "iron": 2},
	"Event": {"gold": 8, "food": 3, "iron": 1},
}

# Called by GameManager at start of each turn to compute total income.


func calculate_turn_income(player_id: int) -> Dictionary:
	## Returns delta dictionary: { "gold":X, "food":X, "iron":X, "slaves":X, "prestige":X,
	## "magic_crystal":X, "war_horse":X, "gunpowder":X, "shadow_essence":X }
	var income := {
		"gold": 0, "food": 0, "iron": 0, "slaves": 0, "prestige": 0,
		"magic_crystal": 0, "war_horse": 0, "gunpowder": 0, "shadow_essence": 0,
	}

	var faction_id: int = GameManager.get_player_faction(player_id)
	var params: Dictionary = FactionData.FACTION_PARAMS[faction_id]
	var order_mult: float = OrderManager.get_production_multiplier()

	# ── Tile production ──
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) != player_id:
			continue
		var base: Dictionary = tile.get("base_production", {})
		var level: int = maxi(tile.get("level", 1), 1)
		var level_idx: int = clampi(level - 1, 0, GameManager.UPGRADE_PROD_MULT.size() - 1)
		var level_mult: float = GameManager.UPGRADE_PROD_MULT[level_idx] if GameManager.UPGRADE_PROD_MULT.size() > 0 else 1.0

		# Building level production bonus
		var building_prod_bonus: float = _get_building_level_bonus(tile)

		var iron_mult: float = params.get("iron_income_mult", 1.0)

		var terrain_prod_mult: float = FactionData.TERRAIN_DATA.get(tile.get("terrain", FactionData.TerrainType.PLAINS), {}).get("production_mult", 1.0)

		var g: int = int(roundf(float(base.get("gold", 0)) * level_mult * params["gold_income_mult"] * params["base_production_mult"] * order_mult * (1.0 + building_prod_bonus) * terrain_prod_mult))
		var f: int = int(roundf(float(base.get("food", 0)) * level_mult * params["food_production_mult"] * params["base_production_mult"] * order_mult * (1.0 + building_prod_bonus) * terrain_prod_mult))
		var ir: int = int(roundf(float(base.get("iron", 0)) * level_mult * iron_mult * params["base_production_mult"] * order_mult * (1.0 + building_prod_bonus) * terrain_prod_mult))

		income["gold"] += g
		income["food"] += f
		income["iron"] += ir

		# ── Building bonuses ──
		var bld: String = tile.get("building_id", "")
		var bld_level: int = tile.get("building_level", 1)
		_apply_building_income(bld, bld_level, income, faction_id, player_id)

		# ── Resource station income (strategic resources only) ──
		var station_type: String = tile.get("resource_station_type", "")
		if station_type != "":
			var station_output: int = _get_station_output(station_type, level)
			if income.has(station_type):
				income[station_type] += station_output

	# ── Prestige from strongholds ──
	var strongholds_owned: int = GameManager.count_strongholds_owned(player_id)
	income["prestige"] += strongholds_owned * FactionData.PRESTIGE_SOURCES["own_stronghold_per_turn"]

	# ── Dark Elf slave allocation income ──
	if faction_id == FactionData.FactionID.DARK_ELF:
		var alloc: Dictionary = SlaveManager.get_allocation(player_id)
		var efficiency: float = SlaveManager.get_efficiency_mult(player_id)
		income["iron"] += int(float(alloc.get("mine", 0)) * float(params["slave_mine_iron_per_turn"]) * efficiency)
		income["food"] += int(float(alloc.get("farm", 0)) * float(params["slave_farm_food_per_turn"]) * efficiency)
		# Altar: global atk bonus handled in SlaveManager tick

	# ── NPC bonuses ──
	var npc_bonuses: Dictionary = NpcManager.get_active_skill_bonuses(player_id)
	income["gold"] += npc_bonuses.get("gold_per_turn", 0)
	income["food"] += npc_bonuses.get("food_per_turn", 0)
	income["iron"] += npc_bonuses.get("iron_per_turn", 0)

	# ── Relic multipliers ──
	var relic_gold_mult: float = RelicManager.get_gold_income_mult(player_id)
	if relic_gold_mult != 1.0:
		income["gold"] = int(float(income["gold"]) * relic_gold_mult)

	# ── Faction resource relic bonus (ancient_totem: applies to faction-specific resources) ──
	var faction_res_mult: float = RelicManager.get_faction_resource_mult(player_id)
	if faction_res_mult != 1.0:
		income["slaves"] = int(float(income["slaves"]) * faction_res_mult)
		income["shadow_essence"] = int(float(income["shadow_essence"]) * faction_res_mult)
		income["magic_crystal"] = int(float(income["magic_crystal"]) * faction_res_mult)

	# ── Buff production multiplier ──
	var buff_prod_mult: float = BuffManager.get_production_multiplier(player_id)
	if buff_prod_mult != 1.0:
		income["gold"] = int(float(income["gold"]) * buff_prod_mult)
		income["food"] = int(float(income["food"]) * buff_prod_mult)
		income["iron"] = int(float(income["iron"]) * buff_prod_mult)

	# v0.8.7: income_pct debuff (e.g. elf_curse: -20% for 3 turns)
	var _raw_income_pct = BuffManager.get_buff_value(player_id, "income_pct")
	var income_pct_mod: float = float(_raw_income_pct) if _raw_income_pct != null else 0.0
	if income_pct_mod != 0.0:
		var mult: float = 1.0 + income_pct_mod / 100.0  # e.g. -20 -> 0.8
		income["gold"] = int(float(income["gold"]) * mult)
		income["food"] = int(float(income["food"]) * mult)
		income["iron"] = int(float(income["iron"]) * mult)

	# ── Neutral faction recruitment bonuses ──
	var recruit_bonuses: Dictionary = QuestManager.get_recruitment_bonuses(player_id)
	if recruit_bonuses.get("gold_per_turn", 0) > 0:
		income["gold"] += recruit_bonuses["gold_per_turn"]
	if recruit_bonuses.get("gunpowder_per_turn", 0) > 0:
		income["gunpowder"] += recruit_bonuses["gunpowder_per_turn"]
	if recruit_bonuses.get("iron_flat_per_turn", 0) > 0:
		income["iron"] += recruit_bonuses["iron_flat_per_turn"]
	var iron_bonus_pct: float = recruit_bonuses.get("iron_per_turn_bonus", 0.0)
	if iron_bonus_pct > 0.0:
		income["iron"] = int(float(income["iron"]) * (1.0 + iron_bonus_pct))

	return income


func _get_building_level_bonus(tile: Dictionary) -> float:
	## Returns a fractional production bonus from building level.
	var bld: String = tile.get("building_id", "")
	if bld == "":
		return 0.0
	var bld_level: int = tile.get("building_level", 1)
	# Training ground and labor camp provide scaling bonuses
	if bld == "training_ground":
		match bld_level:
			1: return 0.0
			2: return 0.05
			3: return 0.10
	if bld == "labor_camp":
		match bld_level:
			1: return 0.0
			2: return 0.10
			3: return 0.20
	return 0.0


func _apply_building_income(bld: String, bld_level: int, income: Dictionary, faction_id: int, _player_id: int) -> void:
	## Apply per-turn income bonuses from buildings using BuildingRegistry effects.
	if bld == "":
		return
	var effects: Dictionary = BuildingRegistry.get_building_effects(bld, bld_level)
	# Slaves per turn (slave_market)
	if effects.has("slaves_per_turn"):
		income["slaves"] += effects["slaves_per_turn"]
	# Food/iron bonus (labor_camp)
	if effects.has("food_bonus"):
		income["food"] += int(effects["food_bonus"])
	if effects.has("iron_bonus"):
		income["iron"] += int(effects["iron_bonus"])
	# Gold per turn (merchant_guild)
	if effects.has("gold_per_turn"):
		income["gold"] += effects["gold_per_turn"]
	# Shadow essence per turn (bone_tower / necromancer building)
	if effects.has("shadow_per_turn"):
		income["shadow_essence"] += effects["shadow_per_turn"]
	# Smuggler's den (pirate faction bonus)
	if bld == "smugglers_den" and faction_id == FactionData.FactionID.PIRATE:
		income["gold"] += 5


func _get_station_output(station_type: String, tile_level: int) -> int:
	## Resource station output scales with tile level. Strategic resources only.
	for station in FactionData.RESOURCE_STATION_TYPES:
		if station["type"] == station_type:
			return station["base_output"] * tile_level
	return 0


func calculate_food_upkeep(player_id: int) -> int:
	## Returns total food consumed this turn by army.
	## Skeleton legion (undead) units do not consume food.
	var faction_id: int = GameManager.get_player_faction(player_id)
	var params: Dictionary = FactionData.FACTION_PARAMS[faction_id]
	var army: int = ResourceManager.get_army(player_id)
	var food_rate: float = params["food_per_soldier"]
	# Subtract skeleton legion from food calculation (undead don't eat)
	var skeleton_count: int = RecruitManager.get_army_composition(player_id).get("skeleton_legion", 0)
	var food_army: int = maxi(0, army - skeleton_count)
	# Orc uses ceili for the whole army
	if faction_id == FactionData.FactionID.ORC:
		return ceili(float(food_army) * food_rate)
	return int(float(food_army) * food_rate)


func calculate_plunder_value(player_id: int) -> int:
	## Pirate: Plunder Value = 2 * owned_tiles
	var faction_id: int = GameManager.get_player_faction(player_id)
	if faction_id != FactionData.FactionID.PIRATE:
		return 0
	var params: Dictionary = FactionData.FACTION_PARAMS[faction_id]
	var owned: int = GameManager.count_tiles_owned(player_id)
	return params["plunder_base_per_tile"] * owned
