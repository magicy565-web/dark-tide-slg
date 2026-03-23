## balance_config.gd - Centralized balance tuning constants (v2.0 — SR07+TW:W数值对齐)
## Modify values here to adjust game difficulty without touching system code.
## All systems should reference BalanceConfig.XXXX instead of hardcoded values.
extends Node

# ═══════════════ ECONOMY (TW:W aligned) ═══════════════

## Starting resources for all factions
const STARTING_GOLD: int = 500
const STARTING_FOOD: int = 150
const STARTING_IRON: int = 80

## Income per settlement level per turn (TW:W 5-level settlement)
const GOLD_PER_NODE_LEVEL := [30, 50, 80, 120, 180]
const FOOD_PER_NODE_LEVEL := [10, 15, 25, 40, 60]
const IRON_PER_NODE_LEVEL := [5, 8, 12, 18, 25]

## Settlement max level (TW:W has 5 settlement levels)
const TILE_MAX_LEVEL: int = 5

## Production multipliers per order bracket (-100 to +100, TW:W public order)
const ORDER_PROD_MULT := {
	"revolt": 0.0,      # Order -100 to -75 (no production during revolt)
	"very_low": 0.5,    # Order -75 to -25
	"low": 0.75,        # Order -25 to 0
	"normal": 1.0,      # Order 0 to 50
	"high": 1.1,        # Order 50 to 75
	"very_high": 1.25,  # Order 75 to 100
}

## Food maintenance per soldier per turn (TW:W meaningful upkeep)
const FOOD_PER_SOLDIER: float = 0.5

## Supply line penalty: 3% global upkeep increase per additional army (TW:W hard difficulty)
const SUPPLY_LINE_PENALTY_PCT: float = 0.03

## Tile upgrade costs [gold, iron] — 5 levels (TW:W building cost curve)
const UPGRADE_COSTS := [
	[0, 0],         # Lv1 (base)
	[300, 20],      # Lv2
	[800, 50],      # Lv3
	[1500, 100],    # Lv4
	[3000, 200],    # Lv5
]

## Construction time per level (turns)
const UPGRADE_TURNS := [0, 1, 2, 3, 4]

# ═══════════════ COMBAT (SR07 aligned) ═══════════════

## Maximum battle rounds before defender wins
const MAX_COMBAT_ROUNDS: int = 12

## Formation slots (SR07: 3 front + 3 back = 6 per side)
const FRONT_SLOTS: int = 3
const BACK_SLOTS: int = 3

## Damage formula: SR07 percentage-based (soldiers × (ATK-DEF)% × skill × terrain)
const DAMAGE_DIVISOR: float = 100.0

## SR07 guarantees minimum 10% damage rate
const DAMAGE_MIN_RATE: float = 0.10

## SR07 war banners: each unit gets 2-4 actions per battle
const UNIT_MOVES_BASE: int = 3
const UNIT_MOVES_MAX: int = 5

## Terrain modifiers (additive ATK bonus, more impactful like TW:W)
const TERRAIN_CAV_PLAINS_ATK: int = 3
const TERRAIN_ARCHER_FOREST_ATK: int = 3
const TERRAIN_CAV_FOREST_ATK: int = -3
const TERRAIN_SWAMP_SPD: int = -3
const TERRAIN_FORTRESS_DEF_MULT: float = 1.5
const TERRAIN_MOUNTAIN_DEF_MULT: float = 1.2
const TERRAIN_DEFENDER_BONUS: float = 0.10  # SR07 town +10% defender advantage

# ═══════════════ ARMY (TW:W aligned) ═══════════════

## Base army count and cap
const MAX_ARMIES_BASE: int = 3
const MAX_ARMIES_UPGRADED: int = 6
const MAX_TROOPS_PER_ARMY: int = 6  # match 6 slots
const MAX_HEROES_PER_ARMY: int = 2

## Action points (matches SR07's 2 action fans)
const BASE_AP: int = 2
const AP_PER_5_TILES: int = 1
const MAX_AP: int = 5

## Supply line thresholds (TW:W attrition)
const SUPPLY_SAFE_RANGE: int = 4
const SUPPLY_ATTRITION_MILD_PCT: float = 0.03  # TW:W 3% losses per turn beyond safe range
const SUPPLY_ATTRITION_CUT_PCT: float = 0.08   # TW:W 8% in hostile territory

## Forced march penalty (TW:W: vulnerability, not heavy losses)
const FORCED_MARCH_AP: int = 2
const FORCED_MARCH_LOSS_PCT: float = 0.05

# ═══════════════ ORDER & THREAT (TW:W public order aligned) ═══════════════

## Order value ranges (TW:W range: -100 to +100)
const ORDER_MIN: int = -100
const ORDER_MAX: int = 100

## Rebellion triggers around -75 (TW:W at -100)
const ORDER_REBELLION_THRESHOLD: int = -75

## Self-correction drift (TW:W mechanic)
const ORDER_DRIFT_HIGH: int = -4   # PO>50 drifts -4/turn toward neutral
const ORDER_DRIFT_LOW: int = 4     # PO<-25 drifts +4/turn toward neutral

## Order modifiers
const ORDER_GARRISON_BONUS: int = 8      # TW:W army presence is significant
const ORDER_BUILDING_BONUS: int = 5      # TW:W buildings +3 to +8
const ORDER_NO_GARRISON_PENALTY: int = -15
const ORDER_NEW_CONQUEST_PENALTY: int = -20  # TW:W new conquests are very unstable
const ORDER_TAX_PENALTY: int = -8         # taxation reduces order (TW:W mechanic)
const ORDER_CORRUPTION_PENALTY: int = -5  # per corruption source nearby

## Rebellion: deterministic at threshold, not random chance
const REBELLION_GARRISON_STRENGTH: int = 8  # rebel army strength = this × abs(order)/100

## Threat thresholds for AI behavior
const THREAT_TIER_INDEPENDENT: int = 29
const THREAT_TIER_DEFENSE: int = 59
const THREAT_TIER_MILITARY: int = 79
const THREAT_TIER_FULL_ALLIANCE: int = 80

## Threat changes
const THREAT_PER_CAPTURE: int = 10
const THREAT_PER_HERO_CAPTURE: int = 15
const THREAT_PER_HERO_RELEASE: int = -10
const THREAT_PER_DIPLOMACY: int = -10
const THREAT_DECAY_PER_TURN: int = -3
const THREAT_DOMINANCE_BONUS: int = 8  # per turn if >50% nodes

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
const SLAVE_REVOLT_THRESHOLD_MULT: int = 3  # revolt if slaves > garrison × this
const SLAVE_REVOLT_CHANCE: float = 0.10

# ═══════════════ VICTORY (TW:W aligned) ═══════════════

## Victory conditions
const DOMINANCE_VICTORY_PCT: float = 0.75  # TW:W short campaign ~75 settlements
const SHADOW_VICTORY_THREAT: int = 100

## Scoring
const SCORE_PER_NODE: int = 10
const SCORE_PER_HERO: int = 50
const SCORE_PER_TURN: int = 2

# ═══════════════ HERO (SR07 aligned) ═══════════════

## Capture and affinity (SR07 capture mechanics)
const MAX_PRISONERS: int = 5
const CAPTURE_BASE_CHANCE: float = 0.20     # SR07 base 20%
const CAPTURE_HUNT_CHANCE: float = 0.50     # SR07 with fleeing warrior hunt 50%
const CAPTURE_GUARANTEED_BOTH: float = 1.0  # SR07 with both skills = 100%
const AFFINITY_MAX: int = 10
const AFFINITY_PER_TURN_FRIENDLY: int = 1

## SR07 commander stat multipliers (scaled for our number range)
const HERO_STAT_ATK_MULT: int = 3   # SR07 commander ATK adds ATK×10, we scale to ×3
const HERO_STAT_DEF_MULT: int = 2   # SR07 DEF adds DEF×8, we scale to ×2
const HERO_STAT_SPD_MULT: int = 1   # SR07 SPD affects delay by SPD×2

# ═══════════════ RESEARCH ═══════════════

## Academy tier multipliers
const ACADEMY_SPEED_MULT := [1.0, 1.25, 1.5, 2.0]  # Lv0, Lv1, Lv2, Lv3
const ACADEMY_QUEUE_SIZE := [1, 1, 2, 3]  # Lv0, Lv1, Lv2, Lv3
