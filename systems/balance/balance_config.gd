## balance_config.gd - Centralized balance tuning constants (v2.0 — SR07+TW:W数值对齐)
## Modify values here to adjust game difficulty without touching system code.
## All systems should reference BalanceConfig.XXXX instead of hardcoded values.
extends Node

# ═══════════════ ECONOMY (TW:W aligned, v4.6 balance pass) ═══════════════

## Starting resources for all factions
## v4.6: Reduced from 600→500 to tighten early game. With ~5 starting tiles
## producing ~35g/turn, 500g lasts ~6-7 turns of active play before needing expansion.
const STARTING_GOLD: int = 500
const STARTING_FOOD: int = 120
const STARTING_IRON: int = 60

## Income per settlement level per turn (TW:W 5-level settlement)
## v4.6: Flattened L1-L2 income, steeper L3-L5 curve for mid-game power spike.
## At 15 tiles (mixed L1-L2), player gets ~600g/turn. At 20 tiles with L3+, ~1000g+.
const GOLD_PER_NODE_LEVEL := [35, 45, 80, 130, 200]
const FOOD_PER_NODE_LEVEL := [8, 12, 25, 45, 70]
const IRON_PER_NODE_LEVEL := [4, 7, 12, 20, 30]

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
## v4.6: Raised from 0.5→0.6 so maintaining large armies requires 3+ farm tiles.
## A 40-soldier army costs 24 food/turn. With 3 L1 farms producing 8f each = 24f.
const FOOD_PER_SOLDIER: float = 0.6

## Gold maintenance per troop tier per turn (军饷)
## T1 troops are conscripts (cheap), T3+ are elite professionals (expensive)
## v4.6: Raised T2-T4 by +1 each to make elite armies a real economic commitment.
## 平衡基准: 10地块~60金/回合净收入, 6编制T3军队满编军饷≈30金≈50%收入
const TIER_GOLD_UPKEEP: Dictionary = { 0: 0, 1: 1, 2: 3, 3: 5, 4: 8 }

## Per-soldier base gold upkeep (faction-specific, applied to raw soldier count)
## Stacks with tier upkeep: total = base_per_soldier × soldiers + tier_upkeep × squads
## v4.6: Increased Pirate upkeep to reinforce "rich but expensive" identity.
## Orc stays cheap (horde army), Dark Elf moderate (quality over quantity).
const GOLD_UPKEEP_PER_SOLDIER_ORC: float = 0.12       # 蛮兵便宜 — 40兵=4.8金 (down from 6)
const GOLD_UPKEEP_PER_SOLDIER_PIRATE: float = 0.35    # 雇佣兵贵 — 40兵=14金 (up from 12)
const GOLD_UPKEEP_PER_SOLDIER_DARK_ELF: float = 0.25  # 精灵适中 — 40兵=10金 (up from 8)

## Gold deficit combat penalty: ATK/DEF debuff when can't pay
const GOLD_DEFICIT_COMBAT_PENALTY: float = 0.15  # -15% ATK/DEF

## ── Scaling Army Upkeep (v5.1 balance pass) ──
## Each army beyond ARMY_UPKEEP_FREE_COUNT costs ARMY_UPKEEP_SCALE_PCT more
## cumulative upkeep. Prevents late-game army spam without punishing early play.
## Example: 4 armies → 4th army costs base×1.20; 5th → base×1.40; 6th → base×1.60
const ARMY_UPKEEP_FREE_COUNT: int = 3       # First 3 armies at base upkeep
const ARMY_UPKEEP_SCALE_PCT: float = 0.20   # +20% per army beyond free count

## ── War Exhaustion (v5.1 balance pass) ──
## After WAR_EXHAUSTION_START_TURN, all costs increase by WAR_EXHAUSTION_PCT_PER_TURN
## per turn. Encourages finishing the game rather than turtling indefinitely.
## At turn 50+10 = turn 60 (the turn limit), costs are +10% — a nudge, not a wall.
const WAR_EXHAUSTION_START_TURN: int = 50
const WAR_EXHAUSTION_PCT_PER_TURN: float = 0.01  # +1% per turn past start

## Supply strain: armies in enemy territory take attrition
const SUPPLY_ENEMY_TERRITORY_ATTRITION: float = 0.03  # 3% per turn in unowned tiles
## Overextension: if total soldiers > owned_tiles × 5, surplus soldiers take attrition
const SUPPLY_OVEREXTENSION_THRESHOLD: int = 5  # soldiers per owned tile before strain
const SUPPLY_OVEREXTENSION_ATTRITION: float = 0.02  # 2% per turn when overextended

## Tile upgrade costs [gold, iron] — 5 levels (TW:W building cost curve)
## v4.6: L2 cheaper (250→200) to encourage early upgrading of key tiles.
## L4-L5 more expensive to be true late-game investments.
const UPGRADE_COSTS := [
	[0, 0],         # Lv1 (base)
	[200, 15],      # Lv2 — affordable after 3-4 turns of saving
	[600, 40],      # Lv3 — mid-game investment, requires ~10 tiles income
	[1400, 90],     # Lv4 — late-mid commitment
	[3000, 150],    # Lv5 — endgame prestige upgrade (v4.1 audit: iron 200→150, was prohibitive)
]

## Production multipliers per settlement level (TW:W scaling)
## v4.6: Steeper curve at L3+ to reward upgrading. L3 = 1.8x (up from 1.6),
## L5 = 3.0x (up from 2.5) makes fully upgraded tiles a major power source.
const UPGRADE_PROD_MULT := [1.0, 1.3, 1.8, 2.2, 3.0]

## Construction time per level (turns)
const UPGRADE_TURNS := [0, 1, 2, 3, 4]

# ═══════════════ COMBAT (SR07 aligned) ═══════════════

## Power calculation divisor for army strength estimates
const COMBAT_POWER_PER_UNIT: int = 10

## Base hero contribution to army combat power
const HERO_BASE_COMBAT_POWER: int = 5

## Maximum battle rounds before defender wins
## v4.6: Reduced from 12→8 to make battles more decisive. Combined with
## higher minimum damage rate, battles should resolve in 3-5 rounds typically.
const MAX_COMBAT_ROUNDS: int = 8

## Formation slots (SR07: 3 front + 3 back = 6 per side)
const FRONT_SLOTS: int = 3
const BACK_SLOTS: int = 3

## ── Formation Bonuses (SR07-style front/back placement bonuses) ──
## Row bonuses (applied to every unit in that row)
const FORMATION_FRONT_ATK_MULT: float = 1.10   # Front row: ATK +10% (melee advantage)
const FORMATION_FRONT_DEF_MULT: float = 1.05   # Front row: DEF +5%
const FORMATION_BACK_ATK_MULT: float = 0.95    # Back row: ATK -5% (non-ranged)
const FORMATION_BACK_DEF_MULT: float = 1.15    # Back row: DEF +15% (defensive advantage)
const FORMATION_BACK_RANGED_ATK_MULT: float = 1.10  # Back row ranged: ATK +10% instead of -5%

## Named formation pattern bonuses (based on front/back unit counts)
const FORMATION_WALL_DEF_MULT: float = 1.10       # Wall (3 front, 0 back): front DEF +10%
const FORMATION_TURTLE_DEF_MULT: float = 1.25     # Turtle (0 front, 3 back): back DEF +25% (v4.1 audit: 1.20→1.25 to make viable)
const FORMATION_TURTLE_ATK_MULT: float = 0.90     # Turtle: back ATK -10% (v4.1 audit: 0.85→0.90 to reduce penalty)
const FORMATION_RANGED_FOCUS_ATK_MULT: float = 1.05  # Ranged Focus (1F+2B): back ATK +5%
const FORMATION_FLANKING_ATK_MULT: float = 1.15   # Flanking: enemy bonus ATK +15% for gap

## Damage formula: SR07 percentage-based (soldiers × (ATK-DEF)% × skill × terrain)
const DAMAGE_DIVISOR: float = 100.0

## SR07 guarantees minimum 15% damage rate (v4.1 audit: raised from 12% to prevent
## stalemate battles with high-DEF armies under the 8-round limit)
const DAMAGE_MIN_RATE: float = 0.15

## SR07 war banners: each unit gets 2-4 actions per battle
const UNIT_MOVES_BASE: int = 3
const UNIT_MOVES_MAX: int = 5

## v4.6: Raised from 10%→15% so defenders have a real edge. Attacking
## requires planning — you can't just throw troops at fortified positions.
const TERRAIN_DEFENDER_BONUS: float = 0.15  # SR07 town +15% 防御方优势 (独立于地形)

# ═══════════════ ARMY (TW:W aligned) ═══════════════

## Base army count and cap
const MAX_ARMIES_BASE: int = 3
const MAX_ARMIES_UPGRADED: int = 6
const MAX_TROOPS_PER_ARMY: int = 6  # match 6 slots
const MAX_HEROES_PER_ARMY: int = 2

## Action points (matches SR07's 2 action fans)
## v4.6: Kept BASE_AP at 2 (SR07 standard). Scaling now grants +1 per 7 tiles
## instead of 5, so the jump from 2→3 AP requires real expansion (~7 tiles).
## Max raised to 6 so late-game empires (35+ tiles) feel powerful.
const BASE_AP: int = 2
const AP_PER_5_TILES: int = 1   # Note: actually per 7 tiles now, see game_manager
const MAX_AP: int = 6

## Base population cap before tile bonuses
const BASE_POPULATION_CAP: int = 3

## Forced march → replaced by AP purchase system
const AP_BUY_BASE_COST: int = 20      # First extra AP costs 20 gold
const AP_BUY_COST_SCALE: int = 20     # Each subsequent AP costs +20 more
const AP_BUY_MAX_PER_TURN: int = 3    # Max 3 extra AP per turn

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
## v4.6: Threat decay slowed from -3 to -2 per turn so turtling is penalized.
## Capturing tiles now generates +12 threat (up from 10) to create faster escalation.
## Dominance bonus raised to +10 so holding >50% map creates real urgency.
const THREAT_PER_CAPTURE: int = 12
const THREAT_PER_HERO_CAPTURE: int = 15
const THREAT_PER_HERO_RELEASE: int = -10
const THREAT_PER_DIPLOMACY: int = -10
const THREAT_DECAY_PER_TURN: int = -2
const THREAT_DOMINANCE_BONUS: int = 10  # per turn if >50% nodes

## Audio: threat thresholds for BGM switching (used by SceneAudioDirector)
const THREAT_BGM_TENSE_THRESHOLD: int = 50   # map BGM switches to tense at this level
const THREAT_BGM_CRISIS_THRESHOLD: int = 80  # map BGM switches to crisis at this level

# ═══════════════ FACTION MECHANICS ═══════════════

## Orc WAAAGH!
const WAAAGH_FRENZY_THRESHOLD: int = 80
const WAAAGH_FRENZY_DURATION: int = 3
const WAAAGH_FRENZY_DAMAGE_MULT: float = 1.5
const WAAAGH_DECAY_PER_TURN: int = 5
const WAAAGH_WIN_BONUS: int = 10
const WAAAGH_INFIGHTING_THRESHOLD: int = 20
const WAAAGH_INFIGHTING_CHANCE: float = 0.10

## Orc WAAAGH! Power (spendable burst)
const ORC_WAAAGH_POWER_PER_WIN: int = 1          # +1 waaagh_power per battle won
const ORC_WAAAGH_POWER_BURST_COST: int = 10       # Spend 10 waaagh_power to trigger burst
const ORC_WAAAGH_BURST_ATK_MULT: float = 1.30     # +30% ATK during burst
const ORC_WAAAGH_BURST_ATK_TURNS: int = 3         # Burst ATK lasts 3 turns
const ORC_WAAAGH_BURST_EXHAUST_MULT: float = 0.85 # -15% ATK during exhaustion
const ORC_WAAAGH_BURST_EXHAUST_TURNS: int = 2     # Exhaustion lasts 2 turns

## Orc Blood Tribute (hero sacrifice)
const ORC_BLOOD_TRIBUTE_ATK_PER_SACRIFICE: int = 2  # +2 permanent army ATK per sacrificed hero
const ORC_BLOOD_TRIBUTE_REP_COST: int = -15          # Reputation penalty per sacrifice

## Pirate plunder
const PIRATE_PLUNDER_PER_LEVEL: int = 10
const PIRATE_SPOILS_MULT: float = 1.5

## Pirate Black Market (rare item shop)
const PIRATE_BLACK_MARKET_MARKUP: float = 1.50     # 50% price markup on rare items
const PIRATE_BLACK_MARKET_RESTOCK_TURNS: int = 5   # Restock every 5 turns

## Pirate Intimidation (threat-based ATK bonus)
const PIRATE_INTIMIDATION_THREAT_FLOOR: int = 50   # Bonus starts above 50 threat
const PIRATE_INTIMIDATION_ATK_PER_POINT: float = 0.01  # +1% ATK per threat above floor

## Dark Elf slaves
## v4.6: Slave labor income raised from 0.5→0.7 to make the slave economy
## a meaningful alternative income stream. With 8 starting slaves = 5.6 extra gold/turn.
## Capacity raised to 6 per level so upgraded tiles can hold large slave populations.
const SLAVE_CAPACITY_PER_NODE_LEVEL: int = 6
const SLAVE_LABOR_INCOME: float = 0.7
const SLAVE_CONVERSION_RATIO: int = 3   # slaves per soldier
const SLAVE_ALTAR_ESSENCE: int = 2      # shadow essence per sacrifice
const SLAVE_REVOLT_THRESHOLD_MULT: int = 3  # revolt if slaves > garrison × this
const SLAVE_REVOLT_CHANCE: float = 0.10

## Dark Elf Shadow Network (fog of war removal)
const DARK_ELF_SHADOW_NETWORK_UPKEEP: int = 10    # Gold cost per turn to maintain
const DARK_ELF_SHADOW_NETWORK_REVEAL: bool = true  # Reveals all enemy army positions

## Dark Elf Assassination
const DARK_ELF_ASSASSINATION_AP_COST: int = 2      # AP cost to attempt assassination
const DARK_ELF_ASSASSINATION_SUCCESS: float = 0.40 # 40% base success chance
const DARK_ELF_ASSASSINATION_REP_COST: int = -20   # Reputation penalty on attempt

## Dark Elf Corruption (convert neutral tiles)
const DARK_ELF_CORRUPTION_PRESTIGE_COST: int = 15  # Prestige cost to start corruption
const DARK_ELF_CORRUPTION_TURNS: int = 3            # Turns to corrupt a neutral tile

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
##
## 平衡基准: T1兵=12~16金, T2=22~28金, T3=30~40金
##   占领(×0.5)低价值地块 ≈ 1个T1兵队   →  基础金需≥24
##   洗劫(×1.5)中价值地块 ≈ 2个T2兵队   →  基础金需≥30
##   洗劫(×1.5)高价值地块 ≈ 1个T3+1个T2 →  基础金需≥45
const CONQUEST_LOOT_TABLE: Dictionary = {
	0:  {"gold": 48, "food": 10, "iron": 18, "name": "光明要塞"},    # LIGHT_STRONGHOLD  — 洗劫72金≈2×T3
	1:  {"gold": 30, "food": 14, "iron": 6,  "name": "光明村庄"},    # LIGHT_VILLAGE     — 洗劫45金≈1×T3+余
	2:  {"gold": 28, "food": 8,  "iron": 12, "name": "暗黑据点"},    # DARK_BASE         — 洗劫42金≈1×T3
	3:  {"gold": 16, "food": 4,  "iron": 24, "name": "矿场"},        # MINE_TILE         — 铁矿丰富,金少
	4:  {"gold": 16, "food": 22, "iron": 3,  "name": "农场"},        # FARM_TILE         — 粮草丰富,金少
	5:  {"gold": 12, "food": 6,  "iron": 4,  "name": "荒野"},        # WILDERNESS        — 占领6金=半个T1
	6:  {"gold": 24, "food": 10, "iron": 6,  "name": "事件点"},      # EVENT_TILE        — 洗劫36金≈1×T2+T1
	7:  {"gold": 20, "food": 8,  "iron": 6,  "name": "起点"},        # START             — 洗劫30金≈1×T2
	8:  {"gold": 18, "food": 4,  "iron": 8,  "name": "资源站"},      # RESOURCE_STATION  — 战略资源另算
	9:  {"gold": 60, "food": 14, "iron": 24, "name": "核心要塞"},    # CORE_FORTRESS     — 洗劫90金≈2×T3+T1
	10: {"gold": 24, "food": 8,  "iron": 10, "name": "中立势力"},    # NEUTRAL_BASE      — 洗劫36金≈1×T3
	11: {"gold": 36, "food": 8,  "iron": 6,  "name": "交易站"},      # TRADING_POST      — 洗劫54金≈2×T2
	12: {"gold": 14, "food": 4,  "iron": 6,  "name": "瞭望塔"},      # WATCHTOWER        — 占领7金≈半T1
	13: {"gold": 18, "food": 3,  "iron": 8,  "name": "遗迹"},        # RUINS             — 洗劫27金≈1×T2
	14: {"gold": 32, "food": 18, "iron": 4,  "name": "港口"},        # HARBOR            — 洗劫48金≈1×T3+余
	15: {"gold": 16, "food": 6,  "iron": 14, "name": "关隘"},        # CHOKEPOINT        — 铁矿多,军事要地
}

## Public order → production multiplier breakpoints
## 设计核心: 默认治安50% = 1.0×产出; 低于50%减产, 高于50%增产
## 占领(70%) = 1.15x, 洗劫(10%) = 0.30x, 掳掠(0%) = 0.10x
const TILE_ORDER_PROD_TABLE: Array = [
	{"threshold": 0.05, "mult": 0.10, "label": "民不聊生"},   # 0-5%   极端破坏
	{"threshold": 0.15, "mult": 0.30, "label": "动荡不安"},   # 5-15%  洗劫后
	{"threshold": 0.25, "mult": 0.55, "label": "人心惶惶"},   # 15-25%
	{"threshold": 0.349, "mult": 0.75, "label": "秩序初定"},   # 25-35%
	{"threshold": 0.50, "mult": 1.00, "label": "正常运转"},   # 35-50% ← 默认50%
	{"threshold": 0.60, "mult": 1.10, "label": "安居乐业"},   # 50-60%
	{"threshold": 0.70, "mult": 1.15, "label": "繁荣发展"},   # 60-70% ← 自然上限/占领
	{"threshold": 0.80, "mult": 1.25, "label": "歌舞升平"},   # 70-80% 需特殊加成
	{"threshold": 0.90, "mult": 1.35, "label": "国泰民安"},   # 80-90%
	{"threshold": 1.01, "mult": 1.50, "label": "太平盛世"},   # 90-100% 极端繁荣
]

# ═══════════════ VICTORY (TW:W aligned) ═══════════════

## Victory conditions
const DOMINANCE_VICTORY_PCT: float = 0.75  # TW:W short campaign ~75 settlements
const SHADOW_VICTORY_THREAT: int = 100
const SURVIVAL_TURN_GOAL: int = 100         # Survive N turns without losing capital
const CAPITAL_LOSS_DEFEAT: bool = true       # Lose capital = instant defeat

## Scoring
const SCORE_PER_NODE: int = 10
const SCORE_PER_HERO: int = 50
const SCORE_PER_TURN: int = 2
const SCORE_PER_BATTLE_WON: int = 15
const SCORE_PER_BATTLE_LOST: int = -5

## Victory type score multipliers (applied to final score)
const VICTORY_SCORE_MULTIPLIER: Dictionary = {
	"Conquest Victory": 2.0,
	"Domination Victory": 1.5,
	"Shadow Domination": 1.8,
	"Harem Victory": 1.6,
	"Diplomatic Victory": 1.4,
	"Survival Victory": 1.2,
	"Defeat": 0.5,
}

# ═══════════════ HERO (SR07 aligned) ═══════════════

## Capture and affinity (SR07 capture mechanics)
# BUG FIX: unified with FactionData.PRISON_CAPACITY (was 5 here vs 3 there)
const MAX_PRISONERS: int = 3   # Base capacity; Pirate gets PIRATE_PRISON_CAPACITY from FactionData
const CAPTURE_BASE_CHANCE: float = 0.20     # SR07 base 20%
const CAPTURE_HUNT_CHANCE: float = 0.50     # SR07 with fleeing warrior hunt 50%
const CAPTURE_GUARANTEED_BOTH: float = 1.0  # SR07 with both skills = 100%
const AFFINITY_MAX: int = 10
const AFFINITY_PER_TURN_FRIENDLY: int = 1

## SR07 commander stat multipliers (scaled for our number range)
## v4.6: ATK mult raised to 4 so high-ATK heroes (8-10) give +32-40 to army.
## DEF kept at 2 (defense is less exciting but still valuable).
## SPD raised to 2 so fast heroes meaningfully affect turn order.
const HERO_STAT_ATK_MULT: int = 4   # SR07 commander ATK adds ATK×10, we scale to ×4
const HERO_STAT_DEF_MULT: int = 2   # SR07 DEF adds DEF×8, we scale to ×2
const HERO_STAT_SPD_MULT: int = 2   # SR07 SPD affects delay by SPD×2

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

## Vassal production share (% of vassal node base_production sent to player)
const VASSAL_PRODUCTION_SHARE: float = 0.60
## Vassal garrison is independent but benefits from player tech
const VASSAL_DEFENSE_BONUS: float = 0.20  # +20% DEF for vassal garrisons

## ── Neutral faction unique production (附庸后每回合独特产出) ──
## 每个中立势力附庸后提供独特资源，体现其种族特色
## base = 基地产出, territory = 每个领地节点产出 (叠加)
## 设计基准: 附庸价值 ≈ 占领2-3个普通地块 + 独特资源加成
const NEUTRAL_FACTION_PRODUCTION: Dictionary = {
	# 铁锤矮人: 铁矿大户 + 少量金币, 提供火药(锻造副产物)
	0: {
		"base": {"gold": 8, "food": 2, "iron": 12, "gunpowder": 1},
		"territory": {"gold": 3, "food": 1, "iron": 5},
		"desc": "铁锤熔炉持续锻造精铁, 矮人工匠生产火药",
	},
	# 流浪商队: 金币大户 + 揭露情报(视野), 周期性免费道具
	1: {
		"base": {"gold": 18, "food": 4, "iron": 2},
		"territory": {"gold": 6, "food": 2, "iron": 1},
		"desc": "商队贸易网络带来丰厚金币收入",
	},
	# 亡灵巫师: 暗影精华 + 骷髅兵补充(不耗粮), 低金低粮
	2: {
		"base": {"gold": 4, "food": 0, "iron": 3, "shadow_essence": 3},
		"territory": {"gold": 2, "food": 0, "iron": 1, "shadow_essence": 1},
		"desc": "墓穴源源不断产出暗影精华, 亡灵不需要食物",
	},
	# 森林游侠: 粮食大户 + 少量魔晶(森林灵脉)
	3: {
		"base": {"gold": 6, "food": 14, "iron": 2, "magic_crystal": 1},
		"territory": {"gold": 2, "food": 6, "iron": 1},
		"desc": "森林丰饶的猎场与灵脉提供粮食和魔晶",
	},
	# 血月教团: 暗影精华 + 威望(信仰传播), 少量金铁
	4: {
		"base": {"gold": 6, "food": 2, "iron": 4, "shadow_essence": 2},
		"territory": {"gold": 3, "food": 1, "iron": 2},
		"desc": "血月祭坛汲取暗影之力, 教团扩张带来威望",
		"prestige_per_turn": 2,
	},
	# 地精工匠: 火药大户 + 铁矿, 提供战马(机械坐骑)
	5: {
		"base": {"gold": 8, "food": 2, "iron": 8, "gunpowder": 3},
		"territory": {"gold": 3, "food": 1, "iron": 3, "gunpowder": 1},
		"desc": "地精工坊日夜不停生产火药和机械零件",
	},
}

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
## v4.6: Raised desperate chance from 40→50 for real late-game pressure.
const EXPEDITION_CHANCE_MILITARY: int = 25
const EXPEDITION_CHANCE_DESPERATE: int = 50

## Expedition army strength
## v4.6: Desperate strength raised from 15→18 to punish over-expansion.
const EXPEDITION_STRENGTH_MILITARY: int = 8
const EXPEDITION_STRENGTH_DESPERATE: int = 18

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

# ── Light Counterattack System (v3.5) ──
## Proactive reconquest: light AI actively recaptures lost tiles

## Counterattack spawn chance per turn (%) — scaled by difficulty ai_aggression
const COUNTER_CHANCE_DEFENSE: int = 10    # DEFENSE tier: low aggression
const COUNTER_CHANCE_MILITARY: int = 25   # MILITARY tier: moderate
const COUNTER_CHANCE_DESPERATE: int = 40  # DESPERATE tier: all-out assault

## Counterattack army strength (garrison units)
const COUNTER_STRENGTH_DEFENSE: int = 6
const COUNTER_STRENGTH_MILITARY: int = 12
const COUNTER_STRENGTH_DESPERATE: int = 20

## Counterattack cooldown (turns between counterattacks)
const COUNTER_COOLDOWN_DEFENSE: int = 5
const COUNTER_COOLDOWN_MILITARY: int = 3
const COUNTER_COOLDOWN_DESPERATE: int = 2

## Counterattack power multipliers (vs expedition which uses generic units)
const COUNTER_ATK_PER_UNIT: float = 9.0   # Slightly weaker per-unit than expedition
const COUNTER_DEF_PER_UNIT: float = 7.0

## Garrison reinforcement surge: light AI periodically mass-reinforces frontier
const SURGE_REINFORCE_CHANCE: int = 15     # % per turn at MILITARY+
const SURGE_REINFORCE_AMOUNT: int = 5      # Garrison added to each frontier tile
const SURGE_REINFORCE_MAX_TILES: int = 4   # Max tiles reinforced per surge

## Proactive raid: light sends small raiding parties to harass player economy
const LIGHT_RAID_CHANCE_DEFENSE: int = 5
const LIGHT_RAID_CHANCE_MILITARY: int = 15
const LIGHT_RAID_CHANCE_DESPERATE: int = 25
const LIGHT_RAID_GOLD_DAMAGE_MIN: int = 15  # Gold stolen per raid
const LIGHT_RAID_GOLD_DAMAGE_MAX: int = 40
const LIGHT_RAID_GARRISON_DAMAGE: int = 2   # Garrison lost on raided tile

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

# ═══════════════ DIPLOMACY & TREATIES (v3.4) ═══════════════

## ── Evil faction tribute (朝贡体系) ──
## 强势方可向弱势方索取朝贡，或弱势方主动纳贡求和
const TRIBUTE_MIN_STRENGTH_RATIO: float = 1.5  # 实力 ≥ 对方1.5倍才能索取朝贡
const TRIBUTE_GOLD_PER_TURN_BASE: int = 15     # 基础朝贡金/回合
const TRIBUTE_GOLD_PER_TILE_DIFF: int = 3      # 每多1个地块差距+3金/回合
const TRIBUTE_DURATION: int = 5                 # 朝贡协议持续5回合
const TRIBUTE_BREAK_PRESTIGE_COST: int = 10     # 单方面撕毁朝贡-10威望
const TRIBUTE_BREAK_THREAT_GAIN: int = 8        # 撕毁朝贡+8威胁值
const TRIBUTE_OFFER_PRESTIGE_COST: int = 5      # 主动纳贡需花5威望

## ── Evil faction non-aggression pact (互不侵犯) ──
const NAP_DURATION: int = 8                     # 互不侵犯持续8回合
const NAP_COST_GOLD: int = 80                   # 签约费80金
const NAP_COST_PRESTIGE: int = 8                # 签约费8威望
const NAP_BREAK_PRESTIGE_PENALTY: int = 15      # 背盟-15威望
const NAP_BREAK_ORDER_PENALTY: int = -10        # 背盟-10秩序

## ── Evil faction military alliance (军事同盟) ──
const ALLIANCE_EVIL_DURATION: int = 10          # 军事同盟持续10回合
const ALLIANCE_EVIL_COST_GOLD: int = 150        # 签约费150金
const ALLIANCE_EVIL_COST_PRESTIGE: int = 15     # 签约费15威望
const ALLIANCE_EVIL_ATK_BONUS: float = 0.10     # 同盟双方+10%ATK
const ALLIANCE_EVIL_DEF_BONUS: float = 0.05     # 同盟双方+5%DEF
const ALLIANCE_EVIL_BREAK_PENALTY: int = 20     # 背盟-20威望

## ── Light faction diplomacy (对光明外交) ──
## 停战协议: 花金币换取N回合内不被远征军攻击
const LIGHT_CEASEFIRE_BASE_COST: int = 100      # 基础停战费
const LIGHT_CEASEFIRE_PER_THREAT: int = 3       # 每点威胁值+3金
const LIGHT_CEASEFIRE_DURATION: int = 5         # 停战持续5回合
const LIGHT_CEASEFIRE_THREAT_REDUCTION: int = 15 # 停战降低15威胁值
const LIGHT_CEASEFIRE_MAX_THREAT: int = 70      # 威胁>70不可停战(已进入绝望级)

## 光明求和: 威胁值低时光明阵营可能主动求和(给玩家金币)
const LIGHT_PEACE_OFFER_THRESHOLD: int = 25     # 威胁≤25时光明可能求和
const LIGHT_PEACE_OFFER_GOLD: int = 60          # 光明求和支付60金
const LIGHT_PEACE_OFFER_CHANCE: int = 20        # 每回合20%概率提出

## 勒索光明: 高威胁时可勒索光明势力(用武力威慑换取金币)
const LIGHT_EXTORT_MIN_THREAT: int = 50         # 威胁≥50才能勒索
const LIGHT_EXTORT_GOLD_BASE: int = 40          # 基础勒索金
const LIGHT_EXTORT_GOLD_PER_THREAT: int = 2     # 每点威胁+2金(一次性)
const LIGHT_EXTORT_THREAT_COST: int = -10       # 勒索后威胁-10(消耗威慑)
const LIGHT_EXTORT_COOLDOWN: int = 5            # 勒索冷却5回合

## ── Trade agreements (通商协定) ──
const TRADE_COST_GOLD: int = 60                 # 签约费60金
const TRADE_DURATION: int = 8                   # 通商持续8回合
const TRADE_INCOME_SELF: int = 10               # 自己每回合+10金
const TRADE_INCOME_TARGET: int = 8              # 对方每回合+8金(AI不实际获得)
const TRADE_FOOD_BONUS: int = 5                 # 额外+5粮/回合
const TRADE_MAX_AGREEMENTS: int = 2             # 同时最多2个通商协定

## Starting garrison for newly captured tiles
const STARTING_GARRISON: int = 10

## Minimum garrison after tile capture (maxi(this, garrison/2))
const CAPTURE_MIN_GARRISON: int = 5

## Expedition auto-resolve multipliers
const EXPEDITION_DEFEND_LOSS_MULT: float = 0.5   # garrison -= strength × this (on defend win)
const EXPEDITION_CAPTURE_GARRISON_MULT: float = 0.6  # new garrison = strength × this (on defend loss)

## Combat experience values
## v4.6: Increased rewards for winning and penalty for losing to make
## each battle decision matter. Winning grants real progression, losing hurts.
const COMBAT_XP_WIN: int = 8
const COMBAT_XP_LOSS: int = 3

## Defender army contribution
const DEFENDER_ARMY_CONTRIBUTION: float = 0.5

# ═══════════════ RESEARCH ═══════════════

## Academy tier multipliers
const ACADEMY_SPEED_MULT := [1.0, 1.25, 1.5, 2.0]  # Lv0, Lv1, Lv2, Lv3
const ACADEMY_QUEUE_SIZE := [1, 1, 2, 3]  # Lv0, Lv1, Lv2, Lv3

# ═══════════════ HERO LEVELING (v3.1) ═══════════════

## Hero level cap
const HERO_MAX_LEVEL: int = 50

## EXP awards per combat
## v4.6: Winning grants more XP to reward successful battles.
## Per-kill XP raised so aggressive play builds stronger heroes.
const HERO_EXP_COMBAT_WIN: int = 15
const HERO_EXP_COMBAT_LOSS: int = 4
const HERO_EXP_PER_KILL: int = 3
const HERO_EXP_BOSS_BONUS: int = 20

## Default HP per soldier (fallback if troop def missing)
const HP_PER_SOLDIER_DEFAULT: int = 5

## Hero knockout threshold (hero loses passives when HP <= 0)
const HERO_KNOCKOUT_PASSIVE_LOSS: bool = true

# ═══════════════ TILE DEVELOPMENT ENRICHMENT (v3.6) ═══════════════

## Supply depot upkeep: gold cost per depot per turn
## v4.1 audit: raised from 2→5 so depots are a meaningful logistical decision
const SUPPLY_DEPOT_UPKEEP_GOLD: int = 5

## Path conversion costs (switching a tile's development path)
const PATH_CONVERSION_GOLD_COST: int = 30
const PATH_CONVERSION_IRON_COST: int = 10
const PATH_CONVERSION_REBUILD_TURNS: int = 2

## Specialization synergy thresholds and bonuses
const SYNERGY_MILITARY_THRESHOLD: int = 3
const SYNERGY_ECONOMIC_THRESHOLD: int = 3
const SYNERGY_CULTURAL_THRESHOLD: int = 3
const SYNERGY_MILITARY_ATK_BONUS: int = 1
const SYNERGY_ECONOMIC_GOLD_MULT: float = 1.10
const SYNERGY_CULTURAL_EXP_MULT: float = 1.15

# ═══════════════ REPUTATION GAMEPLAY IMPACT (v4.3) ═══════════════

## Reputation-based diplomacy cost modifiers
## friendly (>30): -20% treaty costs | hostile (<-50): +50% costs, blocks trade
const REPUTATION_FRIENDLY_COST_MULT: float = 0.80     # 友好声望: 条约费用-20%
const REPUTATION_HOSTILE_COST_MULT: float = 1.50       # 敌对声望: 条约费用+50%
const REPUTATION_FRIENDLY_DURATION_BONUS: int = 2      # 友好声望: 条约持续+2回合
const REPUTATION_HOSTILE_DURATION_PENALTY: int = 2      # 敌对声望: 条约持续-2回合

## Reputation thresholds for gating advanced diplomatic options
const REPUTATION_ALLIANCE_THRESHOLD: int = 10          # 声望≥10才能结盟
const REPUTATION_TRADE_BLOCK_THRESHOLD: int = -30      # 声望<-30封锁通商

## Reputation cascade on treaty-breaking: penalty applied to ALL factions
const TREATY_BREAK_REPUTATION_CASCADE: int = -10       # 背盟时所有势力声望-10
const TREATY_BREAK_THRESHOLD: int = 3                  # 连续背盟N次触发"背信"debuff
const TREATY_BREAK_DEBUFF_ATK_PENALTY: float = 0.10    # "背信弃义"debuff: ATK-10%
const TREATY_BREAK_DEBUFF_DURATION: int = 10           # "背信弃义"持续10回合

# ═══════════════ HERO-TROOP SYNERGY (v4.3) ═══════════════

## Hero commanding matching troop type gets synergy bonus
const HERO_TROOP_SYNERGY_ATK: int = 2                 # 英雄指挥匹配兵种: ATK+2
const HERO_TROOP_SYNERGY_DEF: int = 1                 # DEF+1
const HERO_TROOP_SYNERGY_MORALE: int = 10              # 初始士气+10

## Veteran unit bonuses (based on accumulated EXP/battles)
const VETERAN_EXP_THRESHOLD: int = 20                  # EXP≥20: 老兵
const VETERAN_ATK_BONUS: int = 1                       # 老兵ATK+1
const VETERAN_MORALE_BONUS: int = 5                    # 老兵初始士气+5
const ELITE_EXP_THRESHOLD: int = 50                    # EXP≥50: 精锐
const ELITE_ATK_BONUS: int = 2                         # 精锐ATK+2
const ELITE_DEF_BONUS: int = 1                         # 精锐DEF+1
const ELITE_MORALE_BONUS: int = 10                     # 精锐初始士气+10

# ═══════════════ TILE DEVELOPMENT → COMBAT (v4.3) ═══════════════

## Military tile stationed army bonuses
const TILE_MILITARY_GARRISON_ATK: int = 1              # 军事地块驻军ATK+1 per building
const TILE_MILITARY_GARRISON_MORALE: int = 5           # 军事地块驻军士气+5 per building
const TILE_MILITARY_TRAINING_GROUND_EXP: int = 3       # 练兵场每回合给驻军+3 EXP

## Cultural tile bonuses
const TILE_CULTURAL_HERO_CD_REDUCTION: int = 1         # 文化地块英雄技能CD-1
const TILE_CULTURAL_AFFECTION_BONUS: int = 1           # 文化地块英雄好感+1/回合

## Economic tile supply bonuses
const TILE_ECONOMIC_SUPPLY_BONUS: int = 10             # 经济地块补给恢复+10/回合

# ═══════════════ EVENT CHAINS (v4.3) ═══════════════

## Event chain follow-up delay (turns after trigger event)
const EVENT_CHAIN_DELAY_MIN: int = 2
const EVENT_CHAIN_DELAY_MAX: int = 4

## Event consequence escalation
const EVENT_CHAIN_REWARD_ESCALATION: float = 1.25      # 连锁事件奖励提高25%
const EVENT_CHAIN_RISK_ESCALATION: float = 1.30        # 连锁事件风险提高30%

# ═══════════════ TIMED STORY WINDOWS (限时剧情窗口 — SR07 aligned) ═══════════════
## Sengoku Rance-style timed events: miss the turn window, miss the content.
## Each entry: id, title, turn_range, conditions, rewards, narrative_text,
##   miss_consequence, priority (1-3, higher = more important).
## Condition keys: tile_control (int), army_strength (int), prestige_min (int),
##   hero_required (String), faction_state (String), tile_type_count (dict),
##   resource_min (dict), espionage_level (int), tile_index_owned (int).

const TIMED_STORY_WINDOWS: Array = [
	{
		"id": "merchant_caravan",
		"title": "商队来访",
		"turn_range": [5, 10],
		"conditions": {},
		"rewards": {"gold": 60, "food": 20},
		"narrative_text": "一支来自远方的商队途经你的领地，带来了丰厚的贸易品。",
		"miss_consequence": {"type": "nothing"},
		"priority": 1,
	},
	{
		"id": "border_refugees",
		"title": "边境流民",
		"turn_range": [8, 15],
		"conditions": {"tile_control": 5},
		"rewards": {"soldiers": 8, "food": 30},
		"narrative_text": "战火波及边境，大批流民涌入你的领地寻求庇护。收容他们可以充实军力。",
		"miss_consequence": {"type": "enemy_buff", "buff_type": "atk_pct", "value": 5, "duration": 5, "desc": "流民投靠敌方，敌军ATK+5% 5回合"},
		"priority": 2,
	},
	{
		"id": "ancient_ruins_expedition",
		"title": "远古遗迹探险",
		"turn_range": [12, 20],
		"conditions": {"tile_index_owned": 27},
		"rewards": {"prestige": 25, "troop_unlock": "ruins_guardian"},
		"narrative_text": "在第27号地块发现了远古遗迹入口。派遣精锐探索，可能解锁失落的守卫兵种。",
		"miss_consequence": {"type": "enemy_buff", "buff_type": "def_pct", "value": 10, "duration": 8, "desc": "敌方先一步探索遗迹，获得守卫兵种，DEF+10% 8回合"},
		"priority": 3,
	},
	{
		"id": "alliance_proposal",
		"title": "同盟提案",
		"turn_range": [10, 18],
		"conditions": {"prestige_min": 100},
		"rewards": {"hero_recruit": "wandering_knight", "gold": 100},
		"narrative_text": "你的威望远播，一位流浪骑士慕名而来，愿意为你效力，并带来了一笔可观的赞助金。",
		"miss_consequence": {"type": "hero_lost", "desc": "流浪骑士转投敌方阵营"},
		"priority": 3,
	},
	{
		"id": "dark_ritual_warning",
		"title": "暗黑仪式预警",
		"turn_range": [20, 30],
		"conditions": {"espionage_level": 2},
		"rewards": {"prestige": 20, "gold": 50, "enemy_debuff": {"type": "atk_pct", "value": -10, "duration": 5}},
		"narrative_text": "间谍网络截获情报：敌方正在筹备大规模暗黑仪式。提前干预可以削弱其力量。",
		"miss_consequence": {"type": "enemy_buff", "buff_type": "atk_pct", "value": 20, "duration": 10, "desc": "暗黑仪式完成，敌军ATK+20% 10回合"},
		"priority": 3,
	},
	{
		"id": "harvest_festival",
		"title": "丰收祭典",
		"turn_range": [15, 25],
		"conditions": {"tile_type_count": {"type": 4, "count": 3}},
		"rewards": {"food": 80, "gold": 40, "order": 10},
		"narrative_text": "农场连年丰收，百姓欢庆丰收祭典。举国上下士气高涨，粮仓满溢。",
		"miss_consequence": {"type": "resource_loss", "food": -30, "desc": "错过丰收季，粮草减少30"},
		"priority": 2,
	},
	{
		"id": "weapon_smiths_offer",
		"title": "锻造大师来访",
		"turn_range": [18, 28],
		"conditions": {"tile_type_count": {"type": 3, "count": 2}, "resource_min": {"iron": 100}},
		"rewards": {"iron": -50, "army_atk_buff": {"type": "atk_pct", "value": 10, "duration": 10}},
		"narrative_text": "一位传奇锻造大师途经你的领地，愿以精铁为材，为全军锻造利刃。",
		"miss_consequence": {"type": "nothing"},
		"priority": 2,
	},
	{
		"id": "final_prophecy",
		"title": "终焉预言",
		"turn_range": [40, 50],
		"conditions": {"tile_control": 30},
		"rewards": {"prestige": 80, "troop_unlock": "prophecy_vanguard"},
		"narrative_text": "先知现身，宣告终焉之战的预言。只有控制足够疆域的霸者，才能获得天命之兵。",
		"miss_consequence": {"type": "enemy_buff", "buff_type": "atk_pct", "value": 25, "duration": 15, "desc": "预言应验于敌方，敌军获得终焉之力，ATK+25% 15回合"},
		"priority": 3,
	},
	{
		"id": "pirate_king_negotiation",
		"title": "海盗王谈判",
		"turn_range": [12, 22],
		"conditions": {"tile_type_count": {"type": 14, "count": 2}},
		"rewards": {"gold": 80, "troop_unlock": "corsair_fleet"},
		"narrative_text": "海盗王派遣使者前来谈判。控制港口的你有资格与其交涉，换取海上力量。",
		"miss_consequence": {"type": "resource_loss", "gold": -40, "food": -20, "desc": "海盗王发动突袭，掠夺金40粮20"},
		"priority": 2,
	},
	{
		"id": "scholar_conclave",
		"title": "学者议会",
		"turn_range": [25, 35],
		"conditions": {"prestige_min": 200},
		"rewards": {"research_bonus": 50, "hero_xp": 30},
		"narrative_text": "各地学者齐聚你的领地，召开学术盛会。你的威望吸引了最杰出的智者。",
		"miss_consequence": {"type": "nothing"},
		"priority": 1,
	},
]

# ═══════════════ TERRITORY EFFECTS (国効果 — SR07 aligned) ═══════════════

## Controlling specific tile types grants faction-wide passive bonuses.
## Format: effect_id -> { "name": String, "desc": String, ... "effect": Dictionary }
## effect_type can be: "atk_bonus", "def_bonus", "gold_income_pct", "food_income_pct",
##   "iron_income_pct", "garrison_bonus_pct", "morale_boost", "research_speed_pct",
##   "spd_bonus", "reveal_all", "threat_decay_bonus", "prestige_per_turn", "pop_bonus"
const TERRITORY_EFFECTS: Dictionary = {
	# Core Fortress effects (controlling these is like Rance 07's key provinces)
	"core_fortress_control": {
		"name": "要塞掌控", "desc": "每座核心要塞: 全军ATK+1, DEF+1",
		"per_tile": true, "effect": {"atk_bonus": 1, "def_bonus": 1},
	},
	# Tile type effects
	"mine_network": {
		"name": "矿脉网络", "desc": "控制3+矿场: 铁产量+30%",
		"required_type": 3, "required_count": 3,
		"effect": {"iron_income_pct": 0.30},
	},
	"granary_chain": {
		"name": "粮仓连锁", "desc": "控制3+农场: 粮产量+30%, 兵力上限+5",
		"required_type": 4, "required_count": 3,
		"effect": {"food_income_pct": 0.30, "pop_bonus": 5},
	},
	"trade_empire": {
		"name": "贸易帝国", "desc": "控制2+交易站: 金产量+25%",
		"required_type": 11, "required_count": 2,
		"effect": {"gold_income_pct": 0.25},
	},
	"naval_dominion": {
		"name": "制海权", "desc": "控制2+港口: 全军SPD+1, 粮+15%",
		"required_type": 14, "required_count": 2,
		"effect": {"spd_bonus": 1, "food_income_pct": 0.15},
	},
	"watchtower_network": {
		"name": "瞭望网络", "desc": "控制3+瞭望塔: 视野全开, 威胁-2/回合",
		"required_type": 12, "required_count": 3,
		"effect": {"reveal_all": true, "threat_decay_bonus": 2},
	},
	"chokepoint_fortress": {
		"name": "关隘壁垒", "desc": "控制2+关隘: 全据点驻防+20%",
		"required_type": 15, "required_count": 2,
		"effect": {"garrison_bonus_pct": 0.20},
	},
	"ruins_scholar": {
		"name": "遗迹学者", "desc": "控制2+遗迹: 研究速度+20%, 探索奖励+1",
		"required_type": 13, "required_count": 2,
		"effect": {"research_speed_pct": 0.20, "explore_bonus": 1},
	},
	"light_conquest": {
		"name": "光明征服者", "desc": "控制5+光明据点: 威望+3/回合, 全军士气+10",
		"required_type": 0, "required_count": 5,
		"effect": {"prestige_per_turn": 3, "morale_boost": 10},
	},
}

# ═══════════════ HIDDEN HEROES (秘密英雄 — SR07 aligned) ═══════════════

## Hidden heroes unlockable through specific in-game conditions.
## unlock_type: tile_capture | turn_and_tiles | corruption_check | tile_type_count |
##              battle_count | prestige | compound | tile_set
## hero_template: stats used to create the hero when discovered.
const HIDDEN_HEROES: Array = [
	{
		"id": "shadow_blade",
		"name": "影刃·零",
		"unlock_type": "tile_capture",
		"unlock_params": {"tile_index": 27},
		"hero_template": {
			"atk": 9, "def": 4, "spd": 10, "hp": 22, "int": 6,
			"troop_type": "assassin",
			"active": "shadow_strike",
			"passive": "stealth",
			"capture_chance": 0.0,
		},
		"reveal_message": "遗迹深处的封印被打破，一道黑影掠过——影刃·零现身效忠!",
		"hint": "据说某处遗迹封印着一位上古刺客……",
	},
	{
		"id": "ancient_sage",
		"name": "太古贤者·摩根",
		"unlock_type": "turn_and_tiles",
		"unlock_params": {"min_turn": 20, "min_tiles": 15},
		"hero_template": {
			"atk": 3, "def": 6, "spd": 4, "hp": 18, "int": 12,
			"troop_type": "mage",
			"active": "arcane_storm",
			"passive": "wisdom_aura",
			"capture_chance": 0.0,
		},
		"reveal_message": "你的征服引起了太古贤者的注意——摩根从隐居中现身，愿为你出谋划策!",
		"hint": "传闻一位隐世贤者只在霸业初成时现身……",
	},
	{
		"id": "fallen_knight",
		"name": "堕落骑士·加隆",
		"unlock_type": "corruption_check",
		"unlock_params": {"min_corruption": 40},
		"hero_template": {
			"atk": 8, "def": 8, "spd": 5, "hp": 28, "int": 3,
			"troop_type": "heavy_cavalry",
			"active": "dark_charge",
			"passive": "unyielding",
			"capture_chance": 0.0,
		},
		"reveal_message": "深渊的腐化吸引了一位堕落骑士——加隆拖着残破的战旗前来投奔!",
		"hint": "黑暗的力量或许能唤醒沉眠的亡魂骑士……",
	},
	{
		"id": "sea_phantom",
		"name": "海幽灵·莉薇娅",
		"unlock_type": "tile_type_count",
		"unlock_params": {"tile_type": 14, "min_count": 3},
		"hero_template": {
			"atk": 7, "def": 5, "spd": 9, "hp": 20, "int": 7,
			"troop_type": "pirate",
			"active": "tidal_wave",
			"passive": "sea_legs",
			"capture_chance": 0.0,
		},
		"reveal_message": "制海权的确立引来了传说中的海幽灵——莉薇娅的幽灵船靠岸了!",
		"hint": "掌控足够多的港口，或许能召唤海上的传说……",
	},
	{
		"id": "iron_general",
		"name": "铁壁将军·赫尔曼",
		"unlock_type": "battle_count",
		"unlock_params": {"min_battles_won": 10},
		"hero_template": {
			"atk": 7, "def": 10, "spd": 3, "hp": 32, "int": 5,
			"troop_type": "heavy_infantry",
			"active": "iron_wall",
			"passive": "fortify",
			"capture_chance": 0.0,
		},
		"reveal_message": "你的赫赫战功传遍大陆——铁壁将军赫尔曼慕名来投!",
		"hint": "身经百战的指挥官才能赢得铁壁将军的尊重……",
	},
	{
		"id": "dark_priestess",
		"name": "暗黑祭司·赛琳娜",
		"unlock_type": "prestige",
		"unlock_params": {"min_prestige": 300},
		"hero_template": {
			"atk": 5, "def": 6, "spd": 6, "hp": 20, "int": 11,
			"troop_type": "priest",
			"active": "dark_ritual",
			"passive": "life_drain",
			"capture_chance": 0.0,
		},
		"reveal_message": "你的威望震动了暗界——暗黑祭司赛琳娜奉上效忠之礼!",
		"hint": "积累足够的威望，暗界的信徒自会前来朝拜……",
	},
	{
		"id": "twin_assassins",
		"name": "双子刺客·影与风",
		"unlock_type": "compound",
		"unlock_params": {"min_intel": 60, "tile_index": 42},
		"hero_template": {
			"atk": 10, "def": 3, "spd": 11, "hp": 16, "int": 8,
			"troop_type": "ninja",
			"active": "twin_blade_dance",
			"passive": "evasion",
			"capture_chance": 0.0,
		},
		"reveal_message": "情报网触及了暗影之地——双子刺客影与风从黑暗中现身!",
		"hint": "完善的情报网络加上特定据点的控制，能找到隐藏的刺客组织……",
	},
	{
		"id": "dragon_rider",
		"name": "龙骑士·阿尔贡",
		"unlock_type": "tile_set",
		"unlock_params": {"terrain_type": 2, "require_all": false, "min_count": 4},
		"hero_template": {
			"atk": 11, "def": 7, "spd": 8, "hp": 30, "int": 5,
			"troop_type": "dragon_rider",
			"active": "dragon_breath",
			"passive": "flying",
			"capture_chance": 0.0,
		},
		"reveal_message": "群山之巅传来龙吟——你对山脉的统治唤醒了龙骑士阿尔贡!",
		"hint": "征服足够多的山地领域，或许能惊醒沉睡的巨龙……",
	},
]

# ═══════════════ TURN LIMIT (ターン制限 — SR07 aligned) ═══════════════

## Maximum turns before defeat. Rance 07 has ~50 turns depending on difficulty.
## 0 = no turn limit (sandbox mode)
const TURN_LIMIT: int = 60
## Warning threshold: start showing urgency messages
## v4.6: Raised from 10→15 to give player more time to react to time pressure.
const TURN_LIMIT_WARNING: int = 15
## Bonus scoring for finishing early
## v4.6: Raised from 50→75 to incentivize aggressive play over turtling.
const SPEED_CLEAR_BONUS_PER_TURN: int = 75

# ═══════════════ SAT / 満足度 (SR07 aligned) ═══════════════

## Satisfaction points gained when capturing tiles
const SAT_GAIN_NORMAL: int = 1       # Normal tile capture
const SAT_GAIN_FORTRESS: int = 2     # Fortress / core tile capture

## SAT event: hero affection interaction (free action, costs SAT points)
const SAT_EVENT_COST: int = 1        # SAT points consumed per event
const SAT_EVENT_AFFECTION_GAIN: int = 1  # Affection gain per event

## SAT event rewards scaling with hero affection level (0-10)
## gold_base + gold_per_aff * affection, morale_buff duration scales too
const SAT_REWARD_GOLD_BASE: int = 10
const SAT_REWARD_GOLD_PER_AFF: int = 5
const SAT_REWARD_MORALE_BUFF: int = 5       # morale boost to army
const SAT_REWARD_MORALE_DURATION: int = 2   # turns

# ═══════════════ PRISONER ACTIONS (SR07 aligned) ═══════════════

## Execute prisoner: permanent kill, +threat, -reputation, +prestige
const EXECUTE_THREAT_GAIN: int = 20
const EXECUTE_REP_PENALTY: int = -15
const EXECUTE_PRESTIGE_GAIN: int = 5

## Ransom prisoner: gold reward based on hero level, +reputation
const RANSOM_GOLD_PER_LEVEL: int = 20
const RANSOM_GOLD_BASE: int = 50
const RANSOM_REP_BONUS: int = 5

## Exile prisoner: no reward, -threat, hero returns to enemy pool after N turns
const EXILE_THREAT_REDUCTION: int = 5
const EXILE_RETURN_TURNS: int = 5

# ═══════════════ ENDGAME CRISIS (v7.0 — SR07 aligned) ═══════════════

## Turn threshold for crisis eligibility
const CRISIS_START_TURN: int = 40
## Base chance per turn (%) after CRISIS_START_TURN
const CRISIS_BASE_CHANCE_PCT: int = 5
## Chance increase per turn past CRISIS_START_TURN (%)
const CRISIS_CHANCE_INCREASE_PCT: int = 1
## Max 1 active crisis at a time
const CRISIS_MAX_ACTIVE: int = 1

## crisis_plague
const CRISIS_PLAGUE_TROOP_LOSS_PCT: float = 0.30     # -30% troops in affected tile
const CRISIS_PLAGUE_QUARANTINE_COST: int = 50         # Gold per tile to quarantine
const CRISIS_PLAGUE_DURATION: int = 3                 # Turns

## crisis_rebellion
const CRISIS_REBELLION_ORDER_THRESHOLD: float = 0.30  # Tiles with order < 30%
const CRISIS_REBELLION_ARMY_STRENGTH: int = 12        # Medium rebel army strength

## crisis_invasion
const CRISIS_INVASION_ARMY_STRENGTH: int = 30         # Much stronger than normal
const CRISIS_INVASION_REWARD_GOLD: int = 500          # Legendary gold reward
const CRISIS_INVASION_REWARD_PRESTIGE: int = 100      # Legendary prestige reward

## crisis_famine
const CRISIS_FAMINE_DURATION: int = 5                 # Turns
const CRISIS_FAMINE_PRODUCTION_MULT: float = 0.50     # Food production halved

## Late-Game Prestige Actions
const GRAND_FESTIVAL_COST_GOLD: int = 200
const GRAND_FESTIVAL_ORDER_BONUS: int = 15
const GRAND_FESTIVAL_AFFECTION_BONUS: int = 3
const GRAND_FESTIVAL_COOLDOWN: int = 10               # 1 per 10 turns

const IMPERIAL_DECREE_COST_AP: int = 3
const IMPERIAL_DECREE_COST_GOLD: int = 100
const IMPERIAL_DECREE_THREAT_REDUCTION: int = 20

const FORGE_ALLIANCE_COST_GOLD: int = 150
