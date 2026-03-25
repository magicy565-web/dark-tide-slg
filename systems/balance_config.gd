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

## Production multipliers per settlement level (TW:W scaling)
const UPGRADE_PROD_MULT := [1.0, 1.3, 1.6, 2.0, 2.5]

## Construction time per level (turns)
const UPGRADE_TURNS := [0, 1, 2, 3, 4]

# ═══════════════ COMBAT (SR07 aligned) ═══════════════

## Power calculation divisor for army strength estimates
const COMBAT_POWER_PER_UNIT: int = 10

## Base hero contribution to army combat power
const HERO_BASE_COMBAT_POWER: int = 5

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

## DEPRECATED (v3.2): 地形修正已统一至 FactionData.TERRAIN_DATA
## 保留仅供参考，新代码请勿使用
#const TERRAIN_CAV_PLAINS_ATK: int = 3
#const TERRAIN_ARCHER_FOREST_ATK: int = 3
#const TERRAIN_CAV_FOREST_ATK: int = -3
#const TERRAIN_SWAMP_SPD: int = -3
#const TERRAIN_FORTRESS_DEF_MULT: float = 1.5
#const TERRAIN_MOUNTAIN_DEF_MULT: float = 1.2
const TERRAIN_DEFENDER_BONUS: float = 0.10  # SR07 town +10% 防御方优势 (独立于地形)

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

## Base population cap before tile bonuses
const BASE_POPULATION_CAP: int = 3

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

# ═══════════════ TILE PUBLIC ORDER (治安度) ═══════════════

## Default public order for owned tiles (50%)
const TILE_ORDER_DEFAULT: float = 0.50

## Per-turn natural drift toward equilibrium
const TILE_ORDER_DRIFT_PER_TURN: float = 0.03  # +3% per turn
## Garrison bonus: if garrison > 5, extra drift
const TILE_ORDER_GARRISON_DRIFT: float = 0.02
## Building bonus: per building level
const TILE_ORDER_BUILDING_DRIFT: float = 0.01
## Natural cap (order drifts toward this without player action)
const TILE_ORDER_NATURAL_CAP: float = 0.70

## Conquest choice modifiers
const CONQUEST_OCCUPY_ORDER_BONUS: float = 0.20   # 占领: +20%
const CONQUEST_PILLAGE_ORDER_PENALTY: float = 0.40 # 洗劫: -40%
const CONQUEST_PLUNDER_ORDER_PENALTY: float = 0.70 # 掳掠: -70%

## Conquest gold multipliers (applied to base loot)
const CONQUEST_OCCUPY_GOLD_MULT: float = 0.50   # 占领: 50% gold
const CONQUEST_PILLAGE_GOLD_MULT: float = 1.50  # 洗劫: 150% gold
const CONQUEST_PLUNDER_GOLD_MULT: float = 1.00  # 掳掠: normal gold

## Plunder HP recovery for soldiers
const CONQUEST_PLUNDER_HP_RECOVERY: float = 0.25  # 25% soldier HP restored

## Pirate faction conquest loot bonus
const PIRATE_CONQUEST_LOOT_BONUS: float = 0.25  # 海盗+25% loot

## Base conquest loot per tile type (gold, food, iron)
## Applied BEFORE conquest choice multiplier. Level multiplier applied on top.
## TileType enum → {gold, food, iron}
const CONQUEST_LOOT_TABLE: Dictionary = {
	0:  {"gold": 40, "food": 8,  "iron": 15, "name": "光明要塞"},    # LIGHT_STRONGHOLD
	1:  {"gold": 25, "food": 12, "iron": 5,  "name": "光明村庄"},    # LIGHT_VILLAGE
	2:  {"gold": 20, "food": 6,  "iron": 10, "name": "暗黑据点"},    # DARK_BASE
	3:  {"gold": 8,  "food": 2,  "iron": 20, "name": "矿场"},        # MINE_TILE
	4:  {"gold": 8,  "food": 18, "iron": 2,  "name": "农场"},        # FARM_TILE
	5:  {"gold": 5,  "food": 3,  "iron": 3,  "name": "荒野"},        # WILDERNESS
	6:  {"gold": 20, "food": 8,  "iron": 5,  "name": "事件点"},      # EVENT_TILE
	7:  {"gold": 15, "food": 6,  "iron": 5,  "name": "起点"},        # START
	8:  {"gold": 10, "food": 2,  "iron": 5,  "name": "资源站"},      # RESOURCE_STATION
	9:  {"gold": 50, "food": 10, "iron": 20, "name": "核心要塞"},    # CORE_FORTRESS
	10: {"gold": 18, "food": 6,  "iron": 8,  "name": "中立势力"},    # NEUTRAL_BASE
	11: {"gold": 30, "food": 6,  "iron": 5,  "name": "交易站"},      # TRADING_POST
	12: {"gold": 8,  "food": 3,  "iron": 5,  "name": "瞭望塔"},      # WATCHTOWER
	13: {"gold": 12, "food": 2,  "iron": 5,  "name": "遗迹"},        # RUINS
	14: {"gold": 25, "food": 15, "iron": 3,  "name": "港口"},        # HARBOR
	15: {"gold": 10, "food": 4,  "iron": 10, "name": "关隘"},        # CHOKEPOINT
}

## Public order → production multiplier breakpoints
## Keys are upper bounds of order ranges (0.0-1.0), values are production multipliers
const TILE_ORDER_PROD_TABLE: Array = [
	{"threshold": 0.10, "mult": 0.10, "label": "民不聊生"},
	{"threshold": 0.20, "mult": 0.30, "label": "动荡不安"},
	{"threshold": 0.30, "mult": 0.50, "label": "人心惶惶"},
	{"threshold": 0.40, "mult": 0.70, "label": "秩序初定"},
	{"threshold": 0.50, "mult": 0.85, "label": "渐趋稳定"},
	{"threshold": 0.60, "mult": 1.00, "label": "正常运转"},
	{"threshold": 0.70, "mult": 1.10, "label": "安居乐业"},
	{"threshold": 0.80, "mult": 1.20, "label": "繁荣发展"},
	{"threshold": 0.90, "mult": 1.30, "label": "歌舞升平"},
	{"threshold": 1.01, "mult": 1.40, "label": "太平盛世"},
]

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

# ═══════════════ NEUTRAL FACTIONS ═══════════════

## Territory nodes per neutral faction (surrounding their base)
const NEUTRAL_TERRITORY_NODES: int = 2

## Neutral garrison strength range
const NEUTRAL_BASE_GARRISON_MIN: int = 15
const NEUTRAL_BASE_GARRISON_MAX: int = 30
const NEUTRAL_TERRITORY_GARRISON_MIN: int = 8
const NEUTRAL_TERRITORY_GARRISON_MAX: int = 15

## Neutral AI patrol range (max tiles from base to patrol)
const NEUTRAL_PATROL_RANGE: int = 2

## Neutral reinforcement rate per turn
const NEUTRAL_REINFORCE_PER_TURN: int = 1
const NEUTRAL_REINFORCE_CAP_MULT: float = 1.5  # garrison cap = initial × this

## Vassal production share (% of vassal node production sent to player)
const VASSAL_PRODUCTION_SHARE: float = 0.60
## Vassal garrison is independent but benefits from player tech
const VASSAL_DEFENSE_BONUS: float = 0.20  # +20% DEF for vassal garrisons

# ═══════════════ LIGHT FACTION DEFENSE ═══════════════

## Wall HP caps by tile type
const WALL_HP_VILLAGE: int = 10
const WALL_HP_STRONGHOLD: int = 25
const WALL_HP_CORE_FORTRESS: int = 50

## Elf barrier mechanics
const BARRIER_BASE_ABSORPTION: float = 0.30
const BARRIER_LEY_LINE_BONUS: float = 0.15
const BARRIER_MAX_ABSORPTION: float = 0.90

## Mage tower spell damage multiplier (hardcoded 0.3 → configurable)
const MAGE_SPELL_DAMAGE_MULT: float = 0.30

## Light faction spell effects
const SPELL_TELEPORT_GARRISON_MIN: int = 10
const SPELL_TELEPORT_GARRISON_MAX: int = 20
const SPELL_BARRIER_DEFENSE_BONUS: int = 10
const SPELL_BARRAGE_DAMAGE_MIN: int = 15
const SPELL_BARRAGE_DAMAGE_MAX: int = 30

## Light mana capacity per mage tile
const MANA_PER_MAGE_TILE: int = 10

# ═══════════════ ALLIANCE AI ═══════════════

## Alliance defense bonus % applied to adjacent light tiles
const ALLIANCE_DEF_BONUS_PCT: int = 30

## Expedition spawn chance per turn (%)
const EXPEDITION_CHANCE_MILITARY: int = 25
const EXPEDITION_CHANCE_DESPERATE: int = 40

## Expedition army strength
const EXPEDITION_STRENGTH_MILITARY: int = 8
const EXPEDITION_STRENGTH_DESPERATE: int = 15

## Expedition combat multipliers
const EXPEDITION_ATK_PER_UNIT: float = 10.0
const EXPEDITION_DEF_PER_UNIT: float = 8.0

## Post-expedition garrison calculations
const EXPEDITION_CAPTURE_GARRISON_LOSS: float = 0.5  # % of defender garrison subtracted from attacker
const EXPEDITION_DEFENSE_LOSS: float = 0.3  # % of expedition strength lost on failed attack

## Desperate tier reinforcement per turn
const DESPERATE_REINFORCE_PER_TURN: int = 2

## Minimum garrison for zone transfer
const ZONE_TRANSFER_MIN_GARRISON: int = 3

# ═══════════════ EVIL FACTION AI ═══════════════

## Raid mechanics
const EVIL_RAID_CHANCE_PCT: int = 10
const EVIL_RAID_MIN_STRENGTH: int = 3
const EVIL_RAID_STRENGTH_DIVISOR: int = 2  # garrison / this = raid strength
const EVIL_RAID_DAMAGE_DIVISOR: int = 2    # raid_strength / this = damage on success

## Evil AI garrison caps by tile type
const EVIL_GARRISON_CORE_FORTRESS: int = 14
const EVIL_GARRISON_DARK_BASE: int = 10
const EVIL_GARRISON_DEFAULT: int = 6

# ═══════════════ GAME MANAGER COMBAT ═══════════════

## Starting garrison for newly captured tiles
const STARTING_GARRISON: int = 10

## Minimum garrison after tile capture (maxi(this, garrison/2))
const CAPTURE_MIN_GARRISON: int = 5

## Expedition auto-resolve multipliers
const EXPEDITION_DEFEND_LOSS_MULT: float = 0.5   # garrison -= strength × this (on defend win)
const EXPEDITION_CAPTURE_GARRISON_MULT: float = 0.6  # new garrison = strength × this (on defend loss)

## Combat experience values
const COMBAT_XP_WIN: int = 5
const COMBAT_XP_LOSS: int = 2

## Defender army contribution
const DEFENDER_ARMY_CONTRIBUTION: float = 0.5

# ═══════════════ RESEARCH ═══════════════

## Academy tier multipliers
const ACADEMY_SPEED_MULT := [1.0, 1.25, 1.5, 2.0]  # Lv0, Lv1, Lv2, Lv3
const ACADEMY_QUEUE_SIZE := [1, 1, 2, 3]  # Lv0, Lv1, Lv2, Lv3

# ═══════════════ HERO LEVELING (v3.1) ═══════════════

## Hero level cap
const HERO_MAX_LEVEL: int = 20

## EXP awards per combat
const HERO_EXP_COMBAT_WIN: int = 10
const HERO_EXP_COMBAT_LOSS: int = 3
const HERO_EXP_PER_KILL: int = 2
const HERO_EXP_BOSS_BONUS: int = 15

## Default HP per soldier (fallback if troop def missing)
const HP_PER_SOLDIER_DEFAULT: int = 5

## Hero knockout threshold (hero loses passives when HP <= 0)
const HERO_KNOCKOUT_PASSIVE_LOSS: bool = true
