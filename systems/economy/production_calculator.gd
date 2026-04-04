## production_calculator.gd - Calculates per-turn income for a player (v0.7)
## Considers faction multipliers, buildings, slave allocation, order value, resource stations.
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Cached global building effects (updated each turn) ──
var cached_recruit_discount: int = 0
var cached_supply_penalty_reduction: int = 0

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
	## "magic_crystal":X, "war_horse":X, "gunpowder":X, "shadow_essence":X, "trade_goods":X, "soul_crystals":X, "arcane_dust":X }
	var income := {
		"gold": 0, "food": 0, "iron": 0, "slaves": 0, "prestige": 0,
		"magic_crystal": 0, "war_horse": 0, "gunpowder": 0, "shadow_essence": 0,
		"trade_goods": 0, "soul_crystals": 0, "arcane_dust": 0,
	}

	var faction_id: int = GameManager.get_player_faction(player_id)
	var params: Dictionary = FactionData.FACTION_PARAMS.get(faction_id, {})
	if params.is_empty():
		return income
	# NOTE: order_mult is now per-tile, not global
	# Cache faction multipliers (constant across all tiles)
	var gold_income_mult: float = params["gold_income_mult"]
	var food_production_mult: float = params["food_production_mult"]
	var base_production_mult: float = params["base_production_mult"]
	var iron_mult: float = params.get("iron_income_mult", 1.0)
	var gold_base_mult: float = gold_income_mult * base_production_mult
	var food_base_mult: float = food_production_mult * base_production_mult
	var iron_base_mult: float = iron_mult * base_production_mult

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

		var terrain_prod_mult: float = FactionData.TERRAIN_DATA.get(tile.get("terrain", FactionData.TerrainType.PLAINS), {}).get("production_mult", 1.0)

		var tile_mult: float = level_mult * (1.0 + building_prod_bonus) * terrain_prod_mult

		# Per-tile public order multiplier
		var tile_order: float = tile.get("public_order", BalanceConfig.TILE_ORDER_DEFAULT)
		var tile_order_mult: float = get_tile_order_multiplier(tile_order)

		var g: int = int(roundf(float(base.get("gold", 0)) * tile_mult * gold_base_mult * tile_order_mult))
		var f: int = int(roundf(float(base.get("food", 0)) * tile_mult * food_base_mult * tile_order_mult))
		var ir: int = int(roundf(float(base.get("iron", 0)) * tile_mult * iron_base_mult * tile_order_mult))

		# ── Supply line & classification production modifier ──
		var _supply_mod: float = SupplySystem.get_tile_production_modifier(player_id, tile.get("index", -1))
		if _supply_mod != 1.0:
			g = int(float(g) * _supply_mod)
			f = int(float(f) * _supply_mod)
			ir = int(float(ir) * _supply_mod)

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

		# ── Tile Development Path modifiers ──
		var tile_idx: int = tile.get("index", -1)
		if tile_idx >= 0:
			var tile_dev_effects: Dictionary = TileDevelopment.get_tile_path_effects(tile_idx)
			income["gold"] += int(tile_dev_effects.get("gold_per_turn", 0))
			income["gold"] += int(tile_dev_effects.get("gold_bonus", 0))
			if tile_dev_effects.has("gold_mult"):
				# BUG FIX R11: use current g (which includes supply_mod) as baseline,
				# not the raw pre-supply value, to correctly adjust income
				var g_before: int = g
				g = int(float(g) * tile_dev_effects["gold_mult"])
				income["gold"] -= g_before - g
			income["iron"] += int(tile_dev_effects.get("iron_per_turn", 0))
			income["iron"] += int(tile_dev_effects.get("iron_bonus", 0))
			if tile_dev_effects.has("iron_mult"):
				var ir_before: int = ir
				var ir_adj: int = int(float(ir) * tile_dev_effects["iron_mult"])
				income["iron"] -= ir_before - ir_adj
				ir = ir_adj
			income["food"] += int(tile_dev_effects.get("food_per_turn", 0))
			if tile_dev_effects.has("food_mult"):
				var f_before: int = f
				var f_adj: int = int(float(f) * tile_dev_effects["food_mult"])
				income["food"] -= f_before - f_adj
				f = f_adj
			income["prestige"] += int(tile_dev_effects.get("prestige_per_turn", 0))

			# Adjacent tile spillover effects from neighboring tiles
			var adj_tiles: Array = GameManager.adjacency.get(tile_idx, [])
			for adj_idx in adj_tiles:
				var adj_effects: Dictionary = TileDevelopment.get_adjacent_effects(adj_idx)
				if adj_effects.has("gold_mult_adjacent"):
					# BUG FIX: only multiply this tile's gold, not cumulative total
					var adj_gold_bonus: int = int(float(g) * (adj_effects["gold_mult_adjacent"] - 1.0))
					income["gold"] += adj_gold_bonus
				if adj_effects.has("order_per_turn_adjacent"):
					# NOTE: Do NOT mutate tile["public_order"] here — calculate_income must
					# be read-only. Order bonuses are applied in begin_turn Phase 4a instead.
					pass

			# ── Seasonal tile development bonuses ──
			var seasonal: Dictionary = TileDevelopment.get_seasonal_tile_bonus(tile_idx)
			income["prestige"] += seasonal.get("prestige_bonus", 0)
			# garrison_regen is applied by garrison system, not income

		# ── Espionage sabotage penalty ──
		if Engine.get_main_loop() is SceneTree:
			var _esp_root: Node = (Engine.get_main_loop() as SceneTree).root
			if _esp_root.has_node("EspionageSystem"):
				var esp: Node = _esp_root.get_node("EspionageSystem")
				if tile_idx >= 0 and esp.is_tile_sabotaged(tile_idx):
					var sab_penalty: float = esp.get_sabotage_penalty(tile_idx)
					if sab_penalty > 0.0:
						income["gold"] -= int(float(g) * sab_penalty)
						income["food"] -= int(float(f) * sab_penalty)
						income["iron"] -= int(float(ir) * sab_penalty)

	# ── Tile synergy bonuses from TileDevelopment ──
	var synergy: Dictionary = TileDevelopment.get_global_synergy_bonuses(player_id)
	if synergy.get("gold_mult", 1.0) != 1.0:
		income["gold"] = int(float(income["gold"]) * synergy["gold_mult"])

	# ── Supply depot upkeep ──
	if Engine.get_main_loop() is SceneTree:
		var _depot_root: Node = (Engine.get_main_loop() as SceneTree).root
		if _depot_root.has_node("SupplySystem"):
			var ss: Node = _depot_root.get_node("SupplySystem")
			if ss.has_method("get_depot_count"):
				var depot_count: int = ss.get_depot_count(player_id)
				income["gold"] -= depot_count * BalanceConfig.SUPPLY_DEPOT_UPKEEP_GOLD
			else:
				# Fallback: count depots from internal dict if method not available
				var depot_dict: Dictionary = ss.get("_supply_depots") if ss.get("_supply_depots") != null else {}
				var depot_count: int = 0
				for _tidx in depot_dict:
					if depot_dict[_tidx] == player_id:
						depot_count += 1
				income["gold"] -= depot_count * BalanceConfig.SUPPLY_DEPOT_UPKEEP_GOLD

	# ── Global building effects (recruit_discount, supply_penalty_reduction) ──
	var global_bld: Dictionary = BuildingRegistry.get_all_player_building_effects(player_id)
	cached_recruit_discount = int(global_bld.get("recruit_discount", 0))
	cached_supply_penalty_reduction = int(global_bld.get("supply_penalty_reduction", 0))

	# ── Prestige from strongholds ──
	var strongholds_owned: int = GameManager.count_strongholds_owned(player_id)
	income["prestige"] += strongholds_owned * FactionData.PRESTIGE_SOURCES["own_stronghold_per_turn"]

	# ── Dark Elf slave allocation income ──
	if faction_id == FactionData.FactionID.DARK_ELF:
		var alloc: Dictionary = SlaveManager.get_allocation(player_id)
		var efficiency: float = SlaveManager.get_efficiency_mult(player_id)
		# BUG FIX R12: add missing gold income from slave miners (+0.5 gold per slave)
		income["gold"] += int(float(alloc.get("mine", 0)) * 0.5 * efficiency)
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

	# ── Crystal efficiency bonus (Arcane Institute Lv2): multiply magic_crystal income ──
	var crystal_eff: float = float(global_bld.get("crystal_efficiency", 1.0))
	if crystal_eff > 1.0 and income["magic_crystal"] > 0:
		income["magic_crystal"] = int(float(income["magic_crystal"]) * crystal_eff)

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

	# ── Weather & Season production modifiers ──
	if Engine.get_main_loop() is SceneTree:
		var root: Node = (Engine.get_main_loop() as SceneTree).root
		if root.has_node("WeatherSystem"):
			var ws: Node = root.get_node("WeatherSystem")
			var weather_mods: Dictionary = ws.get_production_modifiers()
			income["gold"] = int(float(income["gold"]) * weather_mods.get("gold_mult", 1.0))
			income["food"] = int(float(income["food"]) * weather_mods.get("food_mult", 1.0))
			income["iron"] = int(float(income["iron"]) * weather_mods.get("iron_mult", 1.0))

	# ── Difficulty scaling ──
	# Human player gets player_income_mult; AI players get inverse scaling (higher on hard)
	var is_human: bool = (player_id == GameManager.get_human_player_id())
	if is_human:
		var player_mult: float = BalanceManager.get_player_income_mult()
		if player_mult != 1.0:
			income["gold"] = int(float(income["gold"]) * player_mult)
			income["food"] = int(float(income["food"]) * player_mult)
			income["iron"] = int(float(income["iron"]) * player_mult)
	else:
		# AI income scales inversely: when player_income_mult < 1.0, AI gets a boost
		# Use ai_garrison_mult as proxy for AI economic strength
		var ai_mult: float = BalanceManager.get_ai_garrison_mult()
		if ai_mult != 1.0:
			income["gold"] = int(float(income["gold"]) * ai_mult)
			income["food"] = int(float(income["food"]) * ai_mult)
			income["iron"] = int(float(income["iron"]) * ai_mult)

	return income


func get_tile_order_multiplier(order: float) -> float:
	## Returns production multiplier based on tile's public order (0.0-1.0).
	for entry in BalanceConfig.TILE_ORDER_PROD_TABLE:
		if order <= entry["threshold"]:
			return entry["mult"]
	return 1.0  # fallback


func get_tile_order_label(order: float) -> String:
	## Returns the descriptive label for a tile's public order level.
	for entry in BalanceConfig.TILE_ORDER_PROD_TABLE:
		if order <= entry["threshold"]:
			return entry["label"]
	return "正常运转"


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
	# Food per turn (port_facility, harbor_market)
	if effects.has("food_per_turn"):
		income["food"] += int(effects["food_per_turn"])
	# Iron per turn (dwarven_forge)
	if effects.has("iron_per_turn"):
		income["iron"] += int(effects["iron_per_turn"])
	# Gunpowder per turn (gear_workshop)
	if effects.has("gunpowder_per_turn"):
		income["gunpowder"] += int(effects["gunpowder_per_turn"])
	# War horse per turn (horse_breeder)
	if effects.has("horse_bonus"):
		income["war_horse"] += int(effects["horse_bonus"])
	# Magic crystal per turn (crystal_amplifier)
	if effects.has("crystal_bonus"):
		income["magic_crystal"] += int(effects["crystal_bonus"])
	# Shadow essence per turn (shadow_conduit)
	if effects.has("shadow_bonus"):
		income["shadow_essence"] += int(effects["shadow_bonus"])
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
	var params: Dictionary = FactionData.FACTION_PARAMS.get(faction_id, {})
	if params.is_empty():
		return 0
	var army: int = ResourceManager.get_army(player_id)
	var food_rate: float = params["food_per_soldier"]
	# Subtract skeleton legion from food calculation (undead don't eat)
	var skeleton_count: int = RecruitManager.get_army_composition(player_id).get("neutral_skeleton", 0)
	var food_army: int = maxi(0, army - skeleton_count)
	# Orc uses ceili for the whole army
	if faction_id == FactionData.FactionID.ORC:
		return ceili(float(food_army) * food_rate)
	return int(float(food_army) * food_rate)


func calculate_gold_upkeep(player_id: int) -> int:
	## Returns total gold upkeep (军饷) for army maintenance this turn.
	## Two components: per-soldier base cost + per-squad tier cost.
	## v5.1: Scaling army upkeep — armies beyond 3 cost +20% each cumulative.
	var faction_id: int = GameManager.get_player_faction(player_id)
	var army: int = ResourceManager.get_army(player_id)
	if army <= 0:
		return 0

	# 1. Per-soldier base gold upkeep (faction-specific)
	var gold_per_soldier: float = 0.3  # default
	match faction_id:
		FactionData.FactionID.ORC:
			gold_per_soldier = BalanceConfig.GOLD_UPKEEP_PER_SOLDIER_ORC
		FactionData.FactionID.PIRATE:
			gold_per_soldier = BalanceConfig.GOLD_UPKEEP_PER_SOLDIER_PIRATE
		FactionData.FactionID.DARK_ELF:
			gold_per_soldier = BalanceConfig.GOLD_UPKEEP_PER_SOLDIER_DARK_ELF

	# Skeleton legion: undead don't need pay
	var skeleton_count: int = RecruitManager.get_army_composition(player_id).get("neutral_skeleton", 0)
	var paid_army: int = maxi(0, army - skeleton_count)
	var base_cost: int = ceili(float(paid_army) * gold_per_soldier)

	# 2. Per-squad tier-based gold upkeep
	var tier_cost: int = 0
	var army_ref: Array = RecruitManager._get_army_ref(player_id)
	for troop in army_ref:
		var td: Dictionary = GameData.get_troop_def(troop.get("troop_id", ""))
		var tier: int = td.get("tier", 1)
		tier_cost += BalanceConfig.TIER_GOLD_UPKEEP.get(tier, 0)

	var total_upkeep: int = base_cost + tier_cost

	# 3. v5.1: Scaling army upkeep — each army beyond free count costs +20% more
	var army_count: int = GameManager.get_army_count(player_id) if GameManager.has_method("get_army_count") else 0
	if army_count > BalanceConfig.ARMY_UPKEEP_FREE_COUNT:
		var excess: int = army_count - BalanceConfig.ARMY_UPKEEP_FREE_COUNT
		var scale_mult: float = 1.0 + float(excess) * BalanceConfig.ARMY_UPKEEP_SCALE_PCT
		total_upkeep = ceili(float(total_upkeep) * scale_mult)

	# 4. v5.1: War exhaustion — after turn 50, all costs +1% per turn
	var current_turn: int = GameManager.turn_number if GameManager.get("turn_number") != null else 0
	if current_turn > BalanceConfig.WAR_EXHAUSTION_START_TURN:
		var exhaustion_turns: int = current_turn - BalanceConfig.WAR_EXHAUSTION_START_TURN
		var exhaustion_mult: float = 1.0 + float(exhaustion_turns) * BalanceConfig.WAR_EXHAUSTION_PCT_PER_TURN
		total_upkeep = ceili(float(total_upkeep) * exhaustion_mult)

	return total_upkeep


func calculate_plunder_value(player_id: int) -> int:
	## Pirate: Plunder Value = 2 * owned_tiles
	var faction_id: int = GameManager.get_player_faction(player_id)
	if faction_id != FactionData.FactionID.PIRATE:
		return 0
	var params: Dictionary = FactionData.FACTION_PARAMS.get(faction_id, {})
	if params.is_empty():
		return 0
	var owned: int = GameManager.count_tiles_owned(player_id)
	return params["plunder_base_per_tile"] * owned
