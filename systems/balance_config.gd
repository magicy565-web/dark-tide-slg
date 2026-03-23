## balance_config.gd - Centralized balance tuning constants (v1.5)
## Modify values here to adjust game difficulty without touching system code.
## All systems should reference BalanceConfig.XXXX instead of hardcoded values.
extends Node

# ═══════════════ ECONOMY ═══════════════

## Starting resources for all factions
const STARTING_GOLD: int = 200
const STARTING_FOOD: int = 100
const STARTING_IRON: int = 50

## Production multipliers per order bracket
const ORDER_PROD_MULT := {
	"critical": 0.5,   # Order 0-25
	"low": 0.75,       # Order 26-50
	"normal": 1.0,     # Order 51-75
	"high": 1.15,      # Order 76-100
}

## Food maintenance per soldier per turn
const FOOD_PER_SOLDIER: float = 0.1

## Tile upgrade costs [gold, iron]
const UPGRADE_COSTS := [
	[0, 0],       # Lv1 (base)
	[100, 10],    # Lv2
	[200, 20],    # Lv3
]

# ═══════════════ COMBAT ═══════════════

## Maximum battle rounds before defender wins
const MAX_COMBAT_ROUNDS: int = 12

## Formation slots
const FRONT_SLOTS: int = 3
const BACK_SLOTS: int = 2

## Damage formula: soldiers × max(1, ATK - DEF) / DAMAGE_DIVISOR × modifiers
const DAMAGE_DIVISOR: float = 10.0

## Terrain modifiers (additive ATK bonus)
const TERRAIN_CAV_PLAINS_ATK: int = 1
const TERRAIN_ARCHER_FOREST_ATK: int = 1
const TERRAIN_CAV_FOREST_ATK: int = -1
const TERRAIN_SWAMP_SPD: int = -2
const TERRAIN_FORTRESS_DEF_MULT: float = 1.5

# ═══════════════ ARMY ═══════════════

## Base army count and cap
const MAX_ARMIES_BASE: int = 3
const MAX_ARMIES_UPGRADED: int = 5
const MAX_TROOPS_PER_ARMY: int = 5
const MAX_HEROES_PER_ARMY: int = 2

## Action points
const BASE_AP: int = 2
const AP_PER_5_TILES: int = 1
const MAX_AP: int = 6

## Supply line thresholds
const SUPPLY_SAFE_RANGE: int = 5
const SUPPLY_ATTRITION_MILD: int = 2   # soldiers lost per turn beyond safe range
const SUPPLY_ATTRITION_CUT: int = 5    # soldiers lost per turn if disconnected

## Forced march penalty
const FORCED_MARCH_AP: int = 2
const FORCED_MARCH_LOSS_PCT: float = 0.10

# ═══════════════ ORDER & THREAT ═══════════════

## Order value ranges
const ORDER_MAX: int = 100
const ORDER_GARRISON_BONUS: int = 5
const ORDER_BUILDING_BONUS: int = 3
const ORDER_NO_GARRISON_PENALTY: int = -10
const ORDER_NEW_CONQUEST_PENALTY: int = -5

## Rebellion chance per order bracket
const REBELLION_CHANCE := {
	"critical": 0.20,  # Order 0-25
	"low": 0.10,       # Order 26-50
	"normal": 0.0,     # Order 51+
}

## Threat thresholds for AI behavior
const THREAT_TIER_INDEPENDENT: int = 29
const THREAT_TIER_DEFENSE: int = 59
const THREAT_TIER_MILITARY: int = 79
const THREAT_TIER_FULL_ALLIANCE: int = 80

## Threat changes
const THREAT_PER_CAPTURE: int = 10
const THREAT_PER_HERO_CAPTURE: int = 20
const THREAT_PER_HERO_RELEASE: int = -10
const THREAT_PER_DIPLOMACY: int = -15
const THREAT_DECAY_PER_TURN: int = -5
const THREAT_DOMINANCE_BONUS: int = 5  # per turn if >50% nodes

# ═══════════════ FACTION MECHANICS ═══════════════

## Orc WAAAGH!
const WAAAGH_FRENZY_THRESHOLD: int = 80
const WAAAGH_FRENZY_DURATION: int = 3
const WAAAGH_FRENZY_DAMAGE_MULT: float = 1.5
const WAAAGH_DECAY_PER_TURN: int = 5
const WAAAGH_WIN_BONUS: int = 10
const WAAAGH_INFIGHTING_THRESHOLD: int = 20
const WAAAGH_INFIGHTING_CHANCE: float = 0.10

## Pirate plunder
const PIRATE_PLUNDER_PER_LEVEL: int = 10
const PIRATE_SPOILS_MULT: float = 1.5

## Dark Elf slaves
const SLAVE_CAPACITY_PER_NODE_LEVEL: int = 5
const SLAVE_LABOR_INCOME: float = 0.5
const SLAVE_CONVERSION_RATIO: int = 3   # slaves per soldier
const SLAVE_ALTAR_ESSENCE: int = 2      # shadow essence per sacrifice
const SLAVE_REVOLT_THRESHOLD_MULT: int = 3  # revolt if slaves > garrison * this
const SLAVE_REVOLT_CHANCE: float = 0.10

# ═══════════════ VICTORY ═══════════════

## Victory conditions
const DOMINANCE_VICTORY_PCT: float = 0.60
const SHADOW_VICTORY_THREAT: int = 100

## Scoring
const SCORE_PER_NODE: int = 10
const SCORE_PER_HERO: int = 50
const SCORE_PER_TURN: int = 2

# ═══════════════ HERO ═══════════════

## Capture and affinity
const MAX_PRISONERS: int = 3
const AFFINITY_MAX: int = 10
const AFFINITY_PER_TURN_FRIENDLY: int = 1

# ═══════════════ RESEARCH ═══════════════

## Academy tier multipliers
const ACADEMY_SPEED_MULT := [1.0, 1.25, 1.5, 2.0]  # Lv0, Lv1, Lv2, Lv3
const ACADEMY_QUEUE_SIZE := [1, 1, 2, 3]  # Lv0, Lv1, Lv2, Lv3
