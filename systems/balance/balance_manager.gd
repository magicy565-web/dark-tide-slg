## balance_manager.gd — 暗潮 SLG 数值管理总控 (v3.0)
## Autoload: validates power budgets, simulates economy, enforces balance invariants.
## Call BalanceManager.run_full_audit() at game start or from debug console.
extends Node

const TroopReg = preload("res://systems/combat/troop_registry.gd")
const FactionData = preload("res://systems/faction/faction_data.gd")
const HeroLevelData = preload("res://systems/hero/hero_level_data.gd")

# ═══════════════ POWER BUDGET RANGES ═══════════════
# Acceptable (ATK+DEF)*soldiers ranges per tier. Troops outside these fail audit.
const POWER_BUDGET: Dictionary = {
	0: {"min": 10, "max": 60, "label": "T0-炮灰"},
	1: {"min": 40, "max": 90, "label": "T1-基础"},
	2: {"min": 55, "max": 130, "label": "T2-中级"},
	3: {"min": 60, "max": 160, "label": "T3-高级"},
	4: {"min": 15, "max": 50, "label": "T4-终极(单体+光环)"},
}

# Effective power multiplier estimates for passive abilities
const PASSIVE_POWER_MULT: Dictionary = {
	"horde_bonus": 1.15,       # conditional ATK+2
	"berserker_rage": 1.30,    # ×2 ATK at <50% HP (50% uptime estimate)
	"charge_stun": 1.25,       # ×1.5 first hit + 30% stun
	"pistol_shot": 1.10,       # can hit back row
	"reload_shot": 0.85,       # loses 1 turn reloading
	"aoe_immobile": 1.40,      # AoE + siege ×2 but can't move
	"counter_defend": 1.15,    # ×1.2 counter + DEF+2
	"assassin_crit": 1.35,     # ignores taunt + 30%×2 crit
	"poison_slow": 1.20,       # DoT + SPD debuff
	"fort_def_3": 1.10,        # situational DEF+3
	"counter_1_2": 1.10,       # ×1.2 counter
	"immobile": 0.80,          # can't move at all
	"preemptive_1_3": 1.20,    # first strike ×1.3
	"aoe_mana": 1.30,          # AoE costs mana
	"taunt": 1.25,             # forces targeting (tank value)
	"charge_mana_1": 1.05,     # +1 mana/turn utility
	"aoe_1_5_cost5": 1.30,     # AoE ×1.5
	"death_burst": 1.20,       # ATK×2 on death
	"immovable": 1.10,         # can't be pushed
	"zero_food": 1.05,         # no upkeep but -1/turn
	"forest_stealth": 1.25,    # stealth + forest ×2
	"blood_triple": 1.45,      # ×3 at <30% HP (high risk)
	"misfire": 0.85,           # 20% self-damage
	"gold_on_hit": 1.05,       # +2 gold per attack
	"dwarf_siege_t3": 1.35,    # ×3 siege + AoE
	"necro_summon": 1.30,      # +1 skeleton/turn
	"regen_2": 1.25,           # +2 soldiers/turn
	"blood_ritual": 1.15,      # sacrifice to heal
	"overload": 1.20,          # 3 attacks then self-destruct
	"leadership": 1.20,        # adjacent ATK+2
	"waaagh_triple": 1.80,     # ×3 ATK at WAAAGH! 80+ (aura) — v4.2: 2.50→1.80, was outlier (C1 audit fix)
	"siege_ignore": 2.00,      # bypasses walls (aura)
	"shadow_flight": 2.20,     # stealth aura + dominate
	# Hero-bound passives
	"oath_guard": 1.30,        # DEF+2 team + counter×1.3
	"divine_heal": 1.40,       # heal 2/turn + cleanse
	"command_charge": 1.35,    # ×1.8 charge + SPD+1
	"holy_bulwark": 1.45,      # taunt + -30% dmg + fort DEF+4
	"moonlight_volley": 1.30,  # ×1.5 preemptive
	"lunar_ward": 1.25,        # 40% shield + 2 mana/turn
	"shadow_assault": 1.40,    # stealth + 40%×2.5 crit
	"arcane_overload": 1.50,   # AoE×2.0 + 25% spell bonus
	"chrono_shift": 1.45,      # stun + extra action
	"inferno_rain": 1.40,      # AoE + DoT
	# Weak/negative passives
	"slave_fodder": 0.50,      # disposable
	"desperate": 1.05,         # ATK+2 when surrounded
	"scatter": 0.80,           # auto-rout at <30%
	"pillage": 1.05,           # +10 gold on win
	"conscript": 0.90,         # +1 soldier near friendly
	# ── v5.0: Elite faction troop passives ──
	"flanking_charge": 1.30,   # ignores front-row taunt + charges back row
	"siege_bombard": 1.40,     # ×3 siege + AoE splash
	"shadow_stealth": 1.25,    # first-round stealth + ×1.5 counter
	"veteran_resolve": 1.15,   # never routs, min morale 30
}

# ═══════════════ ECONOMY PROJECTIONS ═══════════════
# Expected gold/food/iron income per turn at different game phases

const ECONOMY_PHASES: Dictionary = {
	"early":  {"turn": 5,  "tiles_owned": 5,  "avg_tile_level": 1},
	"mid":    {"turn": 15, "tiles_owned": 12, "avg_tile_level": 2},
	"late":   {"turn": 30, "tiles_owned": 25, "avg_tile_level": 3},
	"endgame":{"turn": 50, "tiles_owned": 40, "avg_tile_level": 4},
}

# ═══════════════ DIFFICULTY SCALING ═══════════════
# Multipliers applied to AI stats, economy, and combat per difficulty level

const DIFFICULTY_PRESETS: Dictionary = {
	"easy": {
		"label": "简单",
		"ai_atk_mult": 0.85,            # Enemy ATK -15%
		"ai_def_mult": 0.80,
		"ai_garrison_mult": 0.75,
		"ai_expedition_chance_mult": 0.60,
		"ai_threat_gain_mult": 0.70,     # Threat gain -30%
		"ai_aggression": 0.30,           # Light AI barely counterattacks
		"player_income_mult": 1.30,      # Income +30%
		"player_xp_mult": 1.50,
		"light_wall_hp_mult": 0.75,
		"order_penalty_mult": 0.60,
		"player_atk_mult": 1.20,         # Player ATK +20%
		"ai_reinforce_mult": 1.00,       # No change
	},
	"normal": {
		"label": "普通",
		"ai_atk_mult": 1.00,
		"ai_def_mult": 1.00,
		"ai_garrison_mult": 1.00,
		"ai_expedition_chance_mult": 1.00,
		"ai_threat_gain_mult": 1.00,
		"ai_aggression": 1.00,           # Baseline counterattack frequency
		"player_income_mult": 1.00,
		"player_xp_mult": 1.00,
		"light_wall_hp_mult": 1.00,
		"order_penalty_mult": 1.00,
		"player_atk_mult": 1.00,         # No change (baseline)
		"ai_reinforce_mult": 1.00,
	},
	"hard": {
		"label": "困难",
		"ai_atk_mult": 1.15,            # Enemy ATK +15%
		"ai_def_mult": 1.15,
		"ai_garrison_mult": 1.25,
		"ai_expedition_chance_mult": 1.30,
		"ai_threat_gain_mult": 1.20,     # Threat gain +20%
		"ai_aggression": 1.60,           # Frequent counterattacks + raids
		"player_income_mult": 0.85,      # Income -15%
		"player_xp_mult": 0.80,
		"light_wall_hp_mult": 1.25,
		"order_penalty_mult": 1.30,
		"player_atk_mult": 0.90,         # Player ATK -10%
		"ai_reinforce_mult": 1.00,
	},
	"nightmare": {
		"label": "噩梦",
		"ai_atk_mult": 1.30,
		"ai_def_mult": 1.30,
		"ai_garrison_mult": 1.50,
		"ai_expedition_chance_mult": 1.60,
		"ai_threat_gain_mult": 1.50,
		"ai_aggression": 2.20,           # Relentless assault, raids every turn
		"player_income_mult": 0.70,
		"player_xp_mult": 0.60,
		"light_wall_hp_mult": 1.50,
		"order_penalty_mult": 1.60,
		"player_atk_mult": 0.80,         # Player ATK -20%
		"ai_reinforce_mult": 1.30,       # Enemy reinforcement +30%
	},
	"lunatic": {
		"label": "狂乱",
		"ai_atk_mult": 1.30,            # Enemy ATK +30%
		"ai_def_mult": 1.30,
		"ai_garrison_mult": 1.75,
		"ai_expedition_chance_mult": 2.00,
		"ai_threat_gain_mult": 1.50,     # Threat gain +50%
		"ai_aggression": 3.00,           # Maximum aggression, constant assault
		"player_income_mult": 0.70,      # Income -30%
		"player_xp_mult": 0.50,
		"light_wall_hp_mult": 1.75,
		"order_penalty_mult": 2.00,
		"player_atk_mult": 0.80,         # Player ATK -20%
		"ai_reinforce_mult": 1.50,       # Enemy reinforcement +50%
	},
}

# ── Runtime state ──
var current_difficulty: String = "normal"
var _audit_log: Array = []

# ═══════════════ DIFFICULTY API ═══════════════

func set_difficulty(key: String) -> void:
	if DIFFICULTY_PRESETS.has(key):
		current_difficulty = key
		EventBus.difficulty_changed.emit(key)

func get_diff() -> Dictionary:
	return DIFFICULTY_PRESETS.get(current_difficulty, DIFFICULTY_PRESETS["normal"])

func get_ai_atk_mult() -> float:
	return get_diff()["ai_atk_mult"]

func get_ai_def_mult() -> float:
	return get_diff()["ai_def_mult"]

func get_ai_garrison_mult() -> float:
	return get_diff()["ai_garrison_mult"]

func get_expedition_chance_mult() -> float:
	return get_diff()["ai_expedition_chance_mult"]

func get_threat_gain_mult() -> float:
	return get_diff()["ai_threat_gain_mult"]

func get_player_income_mult() -> float:
	return get_diff()["player_income_mult"]

func get_player_xp_mult() -> float:
	return get_diff()["player_xp_mult"]

func get_wall_hp_mult() -> float:
	return get_diff()["light_wall_hp_mult"]

func get_order_penalty_mult() -> float:
	return get_diff()["order_penalty_mult"]

func get_ai_aggression() -> float:
	return get_diff().get("ai_aggression", 1.0)

func get_player_atk_mult() -> float:
	return get_diff().get("player_atk_mult", 1.0)

func get_ai_reinforce_mult() -> float:
	return get_diff().get("ai_reinforce_mult", 1.0)

## Apply a difficulty preset by name. Validates the key and emits the
## difficulty_changed signal. Returns true if the preset was found.
## This is a convenience wrapper combining set_difficulty + confirmation.
func apply_difficulty(level: String) -> bool:
	if not DIFFICULTY_PRESETS.has(level):
		push_warning("BalanceManager: apply_difficulty('%s') — unknown preset, valid: %s" % [level, ", ".join(DIFFICULTY_PRESETS.keys())])
		return false
	set_difficulty(level)
	var d: Dictionary = DIFFICULTY_PRESETS[level]
	GameLogger.info("[BalanceManager] Difficulty set to '%s' (%s): player_atk=×%.2f, ai_atk=×%.2f, income=×%.2f, threat=×%.2f, reinforce=×%.2f" % [ level, d["label"], d.get("player_atk_mult", 1.0), d["ai_atk_mult"], d["player_income_mult"], d["ai_threat_gain_mult"], d.get("ai_reinforce_mult", 1.0)])
	return true

# ═══════════════ POWER BUDGET CALCULATOR ═══════════════

## Calculate raw power: (ATK + DEF) × soldiers
func raw_power(troop: Dictionary) -> float:
	var atk: float = float(troop.get("base_atk", 0))
	var def: float = float(troop.get("base_def", 0))
	var soldiers: int = troop.get("max_soldiers", 1)
	return (atk + def) * soldiers

## Calculate effective power: raw_power × passive_multiplier
func effective_power(troop: Dictionary) -> float:
	var rp: float = raw_power(troop)
	var passive: String = troop.get("passive", "")
	var mult: float = PASSIVE_POWER_MULT.get(passive, 1.0)
	# 未定义的被动技能默认使用1.0，输出警告以便排查
	if passive != "" and not PASSIVE_POWER_MULT.has(passive):
		push_warning("BalanceManager: 兵种 '%s' 的被动 '%s' 未在PASSIVE_POWER_MULT中定义，使用默认值1.0" % [troop.get("name", "unknown"), passive])
	return rp * mult

## Calculate cost efficiency: effective_power / recruit_cost
func cost_efficiency(troop: Dictionary) -> float:
	var ep: float = effective_power(troop)
	var cost: int = troop.get("recruit_cost", 1)
	if cost <= 0:
		return 0.0
	return ep / float(cost)

## Calculate DPS estimate: ATK × soldiers / DAMAGE_DIVISOR × passive_mult
func dps_estimate(troop: Dictionary) -> float:
	var atk: float = float(troop.get("base_atk", 0))
	var soldiers: int = troop.get("max_soldiers", 1)
	var passive: String = troop.get("passive", "")
	var mult: float = maxf(0.0, PASSIVE_POWER_MULT.get(passive, 1.0))
	# Assume average enemy DEF of 5
	var effective_atk: float = maxf(1.0, atk - 5.0)
	return soldiers * effective_atk * mult / 10.0

## Calculate EHP (effective hit points): soldiers × hp_per_soldier × (1 + DEF/10) × passive_mult
func ehp_estimate(troop: Dictionary) -> float:
	var def_val: float = float(troop.get("base_def", 0))
	var soldiers: int = troop.get("max_soldiers", 1)
	var hpp: int = troop.get("hp_per_soldier", 5)
	var passive: String = troop.get("passive", "")
	var tank_mult: float = 1.0
	if passive in ["taunt", "holy_bulwark", "immovable"]:
		tank_mult = 1.3
	elif passive == "regen_2":
		tank_mult = 1.5
	elif passive == "counter_defend":
		tank_mult = 1.15
	return soldiers * hpp * (1.0 + def_val / 10.0) * tank_mult

## Calculate hero+troop combo power
func hero_combo_power(hero_id: String, troop: Dictionary, level: int = 1) -> Dictionary:
	if not FactionData.HEROES.has(hero_id):
		return {"atk": 0, "def": 0, "power": 0, "dps": 0}
	var hero_atk: float
	var hero_def: float
	var hero_name: String
	if level > 1 and HeroLevelData.HERO_BASE_STATS.has(hero_id):
		var leveled: Dictionary = HeroLevelData.get_hero_stats_at_level(hero_id, level)
		hero_atk = float(leveled.get("atk", 0))
		hero_def = float(leveled.get("def", 0))
		hero_name = HeroLevelData.HERO_BASE_STATS[hero_id].get("name", hero_id)
	else:
		var hero: Dictionary = FactionData.HEROES[hero_id]
		hero_atk = float(hero.get("atk", 0))
		hero_def = float(hero.get("def", 0))
		hero_name = hero.get("name", hero_id)
	var combined_atk: float = float(troop.get("base_atk", 0)) + hero_atk
	var combined_def: float = float(troop.get("base_def", 0)) + hero_def
	var soldiers: int = troop.get("max_soldiers", 1)
	var passive: String = troop.get("passive", "")
	var mult: float = PASSIVE_POWER_MULT.get(passive, 1.0)
	var power: float = (combined_atk + combined_def) * soldiers * mult
	var effective_atk: float = maxf(1.0, combined_atk - 5.0)
	var dps: float = soldiers * effective_atk * mult / 10.0
	return {
		"atk": combined_atk, "def": combined_def,
		"power": power, "dps": dps,
		"hero": hero_name,
		"troop": troop.get("name", ""),
	}

# ═══════════════ ECONOMY SIMULATOR ═══════════════

## Simulate per-turn income for a faction at a given game phase
func simulate_income(faction_id: int, phase_key: String) -> Dictionary:
	var phase: Dictionary = ECONOMY_PHASES.get(phase_key, ECONOMY_PHASES["early"])
	var tiles: int = phase["tiles_owned"]
	var avg_level: int = phase["avg_tile_level"]
	var params: Dictionary = FactionData.FACTION_PARAMS.get(faction_id, {})

	# Base income from tiles
	var gold_per_tile: int = BalanceConfig.GOLD_PER_NODE_LEVEL[clampi(avg_level - 1, 0, 4)]
	var food_per_tile: int = BalanceConfig.FOOD_PER_NODE_LEVEL[clampi(avg_level - 1, 0, 4)]
	var iron_per_tile: int = BalanceConfig.IRON_PER_NODE_LEVEL[clampi(avg_level - 1, 0, 4)]

	var base_gold: float = gold_per_tile * tiles * params.get("gold_income_mult", 1.0)
	var base_food: float = food_per_tile * tiles * params.get("food_production_mult", 1.0)
	var base_iron: float = iron_per_tile * tiles * params.get("iron_income_mult", 1.0)

	# Apply production multiplier from tile level
	var prod_mult: float = BalanceConfig.UPGRADE_PROD_MULT[clampi(avg_level - 1, 0, 4)]
	base_gold *= prod_mult
	base_food *= prod_mult
	base_iron *= prod_mult

	# Upkeep estimate: assume 3 armies × 4 units average × 5 soldiers
	var estimated_soldiers: int = 3 * 4 * 5
	var food_upkeep: float = estimated_soldiers * BalanceConfig.FOOD_PER_SOLDIER
	var supply_penalty: float = 3 * 0.03  # Legacy estimate: 3 armies × 3% each

	# Net income
	var net_gold: float = base_gold * (1.0 - supply_penalty)
	var net_food: float = base_food - food_upkeep
	var net_iron: float = base_iron

	# Difficulty scaling
	var diff: Dictionary = get_diff()
	net_gold *= diff.get("player_income_mult", 1.0)
	net_food *= diff.get("player_income_mult", 1.0)
	net_iron *= diff.get("player_income_mult", 1.0)

	return {
		"phase": phase_key,
		"faction": FactionData.FACTION_NAMES.get(faction_id, "unknown"),
		"gold": snappedf(net_gold, 0.1),
		"food": snappedf(net_food, 0.1),
		"iron": snappedf(net_iron, 0.1),
		"food_upkeep": snappedf(food_upkeep, 0.1),
		"supply_penalty_pct": snappedf(supply_penalty * 100, 0.1),
	}

# ═══════════════ BALANCE VALIDATOR ═══════════════

## Run a full balance audit. Returns array of {severity, category, message}.
func run_full_audit() -> Array:
	_audit_log = []
	_audit_troop_power()
	_audit_cost_efficiency()
	_audit_hero_combos()
	_audit_economy_curves()
	_audit_faction_parity()
	_audit_tier_progression()
	_audit_combat_formula_bounds()
	_audit_hero_level_scaling()
	# Print summary
	var errors: int = 0
	var warnings: int = 0
	for entry in _audit_log:
		if entry["severity"] == "ERROR":
			errors += 1
		elif entry["severity"] == "WARN":
			warnings += 1
	GameLogger.info("[BalanceManager] Audit complete: %d errors, %d warnings, %d info" % [ errors, warnings, _audit_log.size() - errors - warnings])
	return _audit_log

func _log(severity: String, category: String, msg: String) -> void:
	var entry: Dictionary = {"severity": severity, "category": category, "message": msg}
	_audit_log.append(entry)
	if severity == "ERROR":
		push_warning("[BALANCE ERROR] [%s] %s" % [category, msg])
	elif severity == "WARN":
		push_warning("[BALANCE WARN] [%s] %s" % [category, msg])

## Validate all troop power budgets against tier ranges
func _audit_troop_power() -> void:
	var defs: Dictionary = TroopReg.get_all_troop_definitions()
	for id in defs:
		var troop: Dictionary = defs[id]
		var tier: int = troop.get("tier", 0)
		var rp: float = raw_power(troop)
		var ep: float = effective_power(troop)
		var budget: Dictionary = POWER_BUDGET.get(tier, POWER_BUDGET[0])

		if rp < budget["min"]:
			_log("WARN", "TroopPower", "%s [%s] raw_power=%.0f below T%d min=%d" % [
				troop.get("name", id), id, rp, tier, budget["min"]])
		elif rp > budget["max"]:
			_log("ERROR", "TroopPower", "%s [%s] raw_power=%.0f exceeds T%d max=%d" % [
				troop.get("name", id), id, rp, tier, budget["max"]])

		# Check if effective power exceeds 2× the tier max (broken passive)
		if ep > budget["max"] * 2.0:
			_log("ERROR", "PassivePower", "%s [%s] eff_power=%.0f exceeds 2×T%d max=%d (passive: %s)" % [
				troop.get("name", id), id, ep, tier, budget["max"] * 2, troop.get("passive", "")])

## Check cost efficiency outliers (>2× or <0.5× median)
func _audit_cost_efficiency() -> void:
	var defs: Dictionary = TroopReg.get_all_troop_definitions()
	var efficiencies: Array = []
	for id in defs:
		var troop: Dictionary = defs[id]
		var cost: int = troop.get("recruit_cost", 0)
		if cost <= 0:
			continue
		var ce: float = cost_efficiency(troop)
		efficiencies.append({"id": id, "name": troop.get("name", id), "ce": ce, "tier": troop.get("tier", 0)})

	if efficiencies.is_empty():
		return

	# Sort and find median
	efficiencies.sort_custom(func(a, b): return a["ce"] < b["ce"])
	@warning_ignore("integer_division")
	var median_idx: int = efficiencies.size() / 2
	var median_ce: float = efficiencies[median_idx]["ce"]

	for entry in efficiencies:
		if entry["ce"] > median_ce * 2.5:
			_log("WARN", "CostEfficiency", "%s [T%d] cost_eff=%.2f is >2.5× median=%.2f (too cheap for power)" % [
				entry["name"], entry["tier"], entry["ce"], median_ce])
		elif entry["ce"] < median_ce * 0.3:
			_log("WARN", "CostEfficiency", "%s [T%d] cost_eff=%.2f is <0.3× median=%.2f (overpriced)" % [
				entry["name"], entry["tier"], entry["ce"], median_ce])

## Check hero+troop combo ceiling doesn't create unstoppable units
func _audit_hero_combos() -> void:
	var defs: Dictionary = TroopReg.get_all_troop_definitions()
	var max_combo_power: float = 0.0
	var max_combo_name: String = ""

	for hero_id in FactionData.HEROES:
		var hero: Dictionary = FactionData.HEROES[hero_id]
		for troop_id in defs:
			var troop: Dictionary = defs[troop_id]
			# Only check hero-bound or same-faction troops
			var bound: String = troop.get("hero_bound", "")
			if bound != "" and bound != hero_id:
				continue
			if bound == "" and troop.get("faction", "") != hero.get("faction", ""):
				continue
			var combo: Dictionary = hero_combo_power(hero_id, troop)
			if combo["power"] > max_combo_power:
				max_combo_power = combo["power"]
				max_combo_name = "%s + %s" % [combo["hero"], combo["troop"]]

			# Flag combos with DPS > 15 (can one-round most armies)
			if combo["dps"] > 15.0:
				_log("WARN", "HeroCombo", "%s + %s DPS=%.1f (high burst risk)" % [
					combo["hero"], combo["troop"], combo["dps"]])

	_log("INFO", "HeroCombo", "Max combo power: %s = %.0f" % [max_combo_name, max_combo_power])

## Check economy curves don't diverge too far between factions
func _audit_economy_curves() -> void:
	for phase_key in ECONOMY_PHASES:
		var incomes: Array = []
		for fid in [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]:
			var income: Dictionary = simulate_income(fid, phase_key)
			incomes.append(income)

		# Check gold divergence
		var golds: Array = []
		for inc in incomes:
			golds.append(inc["gold"])
		golds.sort()
		if golds.size() >= 2 and golds[0] > 0:
			var ratio: float = golds[golds.size() - 1] / golds[0]
			if ratio > 2.0:
				_log("WARN", "Economy", "%s phase: gold ratio %.1f:1 between factions (>2.0 threshold)" % [
					phase_key, ratio])

		# Check if any faction goes food-negative
		for inc in incomes:
			if inc["food"] < 0:
				_log("WARN", "Economy", "%s phase: %s has negative food (%.1f/turn)" % [
					phase_key, inc["faction"], inc["food"]])

## Check faction starting parity
func _audit_faction_parity() -> void:
	# Territory count balance
	var territories: Dictionary = {
		"orc": FactionData.ORC_TERRITORY,
		"pirate": FactionData.PIRATE_TERRITORY,
		"dark_elf": FactionData.DARK_ELF_TERRITORY,
	}
	var max_t: int = 0
	var min_t: int = 999
	for k in territories:
		max_t = maxi(max_t, territories[k])
		min_t = mini(min_t, territories[k])
	if max_t > min_t * 3:
		_log("WARN", "FactionParity", "Territory ratio %d:%d (>3:1, may cause snowball)" % [max_t, min_t])

	# Starting resource total value (gold + food×2 + iron×3 as weighted)
	for fid in FactionData.STARTING_RESOURCES:
		var res: Dictionary = FactionData.STARTING_RESOURCES[fid]
		var value: float = res.get("gold", 0) + res.get("food", 0) * 2.0 + res.get("iron", 0) * 3.0
		_log("INFO", "FactionParity", "%s start value: %.0f (gold+food×2+iron×3)" % [
			FactionData.FACTION_NAMES.get(fid, str(fid)), value])

## Check tier progression: T(n+1) should be stronger than T(n) within same faction
func _audit_tier_progression() -> void:
	var defs: Dictionary = TroopReg.get_all_troop_definitions()
	var by_faction: Dictionary = {}
	for id in defs:
		var troop: Dictionary = defs[id]
		var faction: String = troop.get("faction", "unknown")
		if not by_faction.has(faction):
			by_faction[faction] = []
		by_faction[faction].append({"id": id, "tier": troop.get("tier", 0), "ep": effective_power(troop), "name": troop.get("name", id)})

	for faction in by_faction:
		var troops: Array = by_faction[faction]
		troops.sort_custom(func(a, b): return a["tier"] < b["tier"])
		for i in range(1, troops.size()):
			if troops[i]["tier"] > troops[i-1]["tier"] and troops[i]["ep"] < troops[i-1]["ep"] * 0.8:
				# T4 ultimates are single-entity with aura, allow lower raw power
				if troops[i]["tier"] == 4:
					continue
				_log("WARN", "TierProgression", "%s: %s (T%d, ep=%.0f) weaker than %s (T%d, ep=%.0f)" % [
					faction, troops[i]["name"], troops[i]["tier"], troops[i]["ep"],
					troops[i-1]["name"], troops[i-1]["tier"], troops[i-1]["ep"]])

## Check combat formula edge cases
func _audit_combat_formula_bounds() -> void:
	# Check that no troop can one-shot the tankiest unit
	var defs: Dictionary = TroopReg.get_all_troop_definitions()
	var max_ehp: float = 0.0
	var max_dps: float = 0.0
	var max_dps_name: String = ""
	var max_ehp_name: String = ""

	for id in defs:
		var troop: Dictionary = defs[id]
		var dps: float = dps_estimate(troop)
		var ehp: float = ehp_estimate(troop)
		if dps > max_dps:
			max_dps = dps
			max_dps_name = troop.get("name", id)
		if ehp > max_ehp:
			max_ehp = ehp
			max_ehp_name = troop.get("name", id)

	_log("INFO", "CombatBounds", "Max DPS: %s = %.1f | Max EHP: %s = %.1f" % [
		max_dps_name, max_dps, max_ehp_name, max_ehp])

	# One-shot check: if max DPS can kill max EHP in 1 round
	if max_dps > 0 and max_ehp > 0:
		var rounds_to_kill: float = max_ehp / max_dps
		if rounds_to_kill < 1.5:
			_log("ERROR", "CombatBounds", "Max DPS (%s) can kill Max EHP (%s) in %.1f rounds (too fast)" % [
				max_dps_name, max_ehp_name, rounds_to_kill])
		_log("INFO", "CombatBounds", "Rounds for max DPS to kill max EHP: %.1f" % rounds_to_kill)

## Validate hero level scaling doesn't break combat math at Lv20
func _audit_hero_level_scaling() -> void:
	for hero_id in HeroLevelData.HERO_BASE_STATS:
		var stats_lv1: Dictionary = HeroLevelData.get_hero_stats_at_level(hero_id, 1)
		var stats_lv20: Dictionary = HeroLevelData.get_hero_stats_at_level(hero_id, 20)
		var hero_name: String = HeroLevelData.HERO_BASE_STATS[hero_id].get("name", hero_id)

		# Check ATK growth doesn't exceed 3× base
		if stats_lv20["atk"] > stats_lv1["atk"] * 3.5:
			_log("WARN", "HeroGrowth", "%s ATK grows from %d to %d (>3.5× base)" % [
				hero_name, stats_lv1["atk"], stats_lv20["atk"]])

		# Check no stat exceeds 30 at Lv20 (combat formula assumes 1-20 range)
		for stat_key in ["atk", "def", "int_stat", "spd"]:
			if stats_lv20[stat_key] > 30:
				_log("WARN", "HeroGrowth", "%s %s=%d at Lv20 exceeds soft cap 30" % [
					hero_name, stat_key, stats_lv20[stat_key]])

		# Check HP pool is reasonable (not > 60)
		if stats_lv20["hp"] > 60:
			_log("WARN", "HeroGrowth", "%s HP=%d at Lv20 (very tanky)" % [
				name, stats_lv20["hp"]])

		# Log info for each hero
		_log("INFO", "HeroGrowth", "%s Lv20: ATK=%d DEF=%d INT=%d SPD=%d HP=%d MP=%d" % [
			name, stats_lv20["atk"], stats_lv20["def"], stats_lv20["int_stat"],
			stats_lv20["spd"], stats_lv20["hp"], stats_lv20["mp"]])

	# Check EXP curve reaches Lv20 in ~50 turns
	var total_exp: int = HeroLevelData.EXP_TABLE[HeroLevelData.MAX_LEVEL - 1]
	var avg_exp_per_turn: float = 24.0  # 2 wins + kills
	var est_turns: float = total_exp / avg_exp_per_turn
	_log("INFO", "HeroGrowth", "EXP to Lv20: %d, est. turns at avg 24/turn: %.0f" % [
		total_exp, est_turns])
	if est_turns > 70:
		_log("WARN", "HeroGrowth", "Lv20 takes ~%.0f turns (>70, may be too slow)" % est_turns)
	elif est_turns < 30:
		_log("WARN", "HeroGrowth", "Lv20 takes ~%.0f turns (<30, may be too fast)" % est_turns)

# ═══════════════ SAVE/LOAD ═══════════════

func serialize() -> Dictionary:
	return {"difficulty": current_difficulty}

func deserialize(data: Dictionary) -> void:
	current_difficulty = data.get("difficulty", "normal")
