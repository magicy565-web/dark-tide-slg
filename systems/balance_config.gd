## balance_config.gd - Centralized balance tuning constants (v2.0 — SR07+TW:W数值对齐)
## Modify values here to adjust game difficulty without touching system code.
## All systems should reference BalanceConfig.XXXX instead of hardcoded values.
extends Node

# ═══════════════ ECONOMY (TW:W aligned) ═══════════════

## Starting resources for all factions
const STARTING_GOLD: int = 600
const STARTING_FOOD: int = 150
const STARTING_IRON: int = 80

## Income per settlement level per turn (TW:W 5-level settlement)
const GOLD_PER_NODE_LEVEL := [40, 50, 80, 120, 180]
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

## Gold maintenance per troop tier per turn (军饷)
## T1 troops are conscripts (cheap), T3+ are elite professionals (expensive)
## 平衡基准: 10地块~70金/回合净收入, 6编制T3军队满编军饷≈24金≈34%收入
const TIER_GOLD_UPKEEP: Dictionary = { 0: 0, 1: 1, 2: 2, 3: 4, 4: 6 }

## Per-soldier base gold upkeep (faction-specific, applied to raw soldier count)
## Stacks with tier upkeep: total = base_per_soldier × soldiers + tier_upkeep × squads
const GOLD_UPKEEP_PER_SOLDIER_ORC: float = 0.15       # 蛮兵便宜 — 40兵=6金
const GOLD_UPKEEP_PER_SOLDIER_PIRATE: float = 0.30    # 雇佣兵贵 — 40兵=12金
const GOLD_UPKEEP_PER_SOLDIER_DARK_ELF: float = 0.20  # 精灵适中 — 40兵=8金

## Gold deficit combat penalty: ATK/DEF debuff when can't pay
const GOLD_DEFICIT_COMBAT_PENALTY: float = 0.15  # -15% ATK/DEF

## Supply strain: armies in enemy territory take attrition
const SUPPLY_ENEMY_TERRITORY_ATTRITION: float = 0.03  # 3% per turn in unowned tiles
## Overextension: if total soldiers > owned_tiles × 5, surplus soldiers take attrition
const SUPPLY_OVEREXTENSION_THRESHOLD: int = 5  # soldiers per owned tile before strain
const SUPPLY_OVEREXTENSION_ATTRITION: float = 0.02  # 2% per turn when overextended

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
const HERO_MAX_LEVEL: int = 50

## EXP awards per combat
const HERO_EXP_COMBAT_WIN: int = 10
const HERO_EXP_COMBAT_LOSS: int = 3
const HERO_EXP_PER_KILL: int = 2
const HERO_EXP_BOSS_BONUS: int = 15

## Default HP per soldier (fallback if troop def missing)
const HP_PER_SOLDIER_DEFAULT: int = 5

## Hero knockout threshold (hero loses passives when HP <= 0)
const HERO_KNOCKOUT_PASSIVE_LOSS: bool = true

# ═══════════════ TILE DEVELOPMENT ENRICHMENT (v3.6) ═══════════════

## Supply depot upkeep: gold cost per depot per turn
const SUPPLY_DEPOT_UPKEEP_GOLD: int = 2

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

# ═══════════════ TURN LIMIT (ターン制限 — SR07 aligned) ═══════════════

## Maximum turns before defeat. Rance 07 has ~50 turns depending on difficulty.
## 0 = no turn limit (sandbox mode)
const TURN_LIMIT: int = 60
## Warning threshold: start showing urgency messages
const TURN_LIMIT_WARNING: int = 10
## Bonus scoring for finishing early
const SPEED_CLEAR_BONUS_PER_TURN: int = 50
