# Dark Tide SLG - Comprehensive Balance Audit v4.1

**Date:** 2026-04-01
**Auditor:** Balance Systems Review
**Files Reviewed:** balance_config.gd, balance_manager.gd, faction_data.gd, combat_resolver.gd, production_calculator.gd, hero_leveling.gd, espionage_system.gd, hero_level_data.gd

---

## Executive Summary

The balance framework is well-structured with centralized constants and a built-in audit system. However, several numerical issues exist across economy, combat, and faction asymmetry. This audit identifies 14 issues ranked by severity and provides a turn-by-turn economy simulation.

---

## 1. Issues Found (Ranked by Severity)

### CRITICAL (Game-breaking)

**C1: WAAAGH! Triple Passive Power Multiplier (2.50x) is an Outlier**
- Location: `balance_manager.gd` line 52 -- `"waaagh_triple": 2.50`
- The WAAAGH! triple passive has a 2.50x power multiplier, far exceeding any other passive (next highest is `siege_ignore` at 2.00x).
- Combined with the in-combat mechanic (ATK x3 when WAAAGH >= 80), this unit becomes 7.5x its base power.
- **Recommendation:** Reduce WAAAGH! triple passive mult from 2.50 to 1.80 (still the strongest, but not runaway).

**C2: Dark Elf Food Economy is Unsustainable**
- Dark Elf has `food_per_soldier: 0.9` (highest) combined with `food_production_mult: 0.8` and `base_production_mult: 0.75`.
- Effective food per L1 tile: 8 x 0.8 x 0.75 = 4.8 food/turn.
- A 40-soldier army costs 36 food/turn, requiring ~8 L1 food tiles.
- With only 3 starting territories, Dark Elf goes food-negative by turn 5 even without expanding army.
- **Recommendation:** Reduce `food_per_soldier` from 0.9 to 0.7 in faction_data.gd (slaves supplement diet).
- **NOT APPLIED** -- constant is in faction_data.gd, not balance_config.gd. Requires separate review.

**C3: Pirate Gold Upkeep vs Income Imbalance at Scale**
- Pirate has `GOLD_UPKEEP_PER_SOLDIER_PIRATE: 0.35` (nearly 3x Orc's 0.12).
- A Pirate with 3 armies x 6 squads x avg 8 soldiers = 144 soldiers.
- Gold upkeep: 144 x 0.35 = 50.4g base + tier costs (~30g) = ~80g/turn.
- At mid-game (12 tiles, L2), income ~ 12 x 45 x 1.4 x 0.7 x 1.3 = ~688g.
- This is actually fine percentage-wise (~12%), but Pirate's `base_production_mult: 0.7` makes non-gold resources critically scarce.

### HIGH (Significant balance impact)

**H1: L5 Tile Upgrade Cost-to-Benefit Ratio is Extreme**
- L5 costs 3000g + 200 iron. At L4 income (~130g/turn x 2.2 = 286g/tile), ROI is ~10.5 turns.
- L5 income: 200g x 3.0 = 600g/tile. Delta from L4: +314g/turn. ROI: 3000/314 = 9.6 turns.
- The 200 iron cost is the real bottleneck -- at L3 iron income (12/tile x 1.8 mult = 21.6/tile), you need ~9 tiles of iron to afford one L5 upgrade.
- **Recommendation:** Reduce L5 iron cost from 200 to 150 to make it achievable before endgame.
- **FIX APPLIED:** Changed in balance_config.gd.

**H2: Turtle Formation is Strictly Dominated**
- Turtle (0 front, 3 back): DEF +20%, ATK -15% (net multiplier for damage output: 0.85).
- Guerrilla directive: back ATK +30%, front DEF +15%, plus back row protection -- strictly better.
- Turtle also loses the Flanking ATK +15% bonus enemies get for exposed back row gaps.
- **Recommendation:** Buff Turtle formation to DEF +25% and ATK -10% (was +20%/-15%).
- **FIX APPLIED:** Changed in balance_config.gd.

**H3: Espionage Intel Cost is Too Cheap Relative to Returns**
- `INTEL_COST_PER_POINT: 10` gold means 100 intel costs 1000g total.
- But espionage operations like sabotage can reduce a tile's production by significant percentages.
- At mid-game 600g+/turn income, sabotaging even one L3 tile (producing ~144g/turn) pays for itself in 7 turns of intel investment.
- **Recommendation:** Raise `INTEL_COST_PER_POINT` from 10 to 15 (in espionage_system.gd, not balance_config.gd since it is defined there).

**H4: MAX_COMBAT_ROUNDS (8) May Cause Draw Issues with Tanky Armies**
- Damage formula: `soldiers x max(1, ATK - DEF) / 10`.
- For equally matched T2 armies (ATK ~11, DEF ~9), damage rate = soldiers x 2/10 = ~1.6 damage per action.
- With 8 rounds x 3 actions = 24 total actions, max damage = ~38.4, but spread across 6 defenders.
- High-DEF formations (samurai DEF 9 + front row +5% + terrain) can make battles inconclusive.
- **Recommendation:** Consider raising to 10 rounds, OR keep 8 but raise DAMAGE_MIN_RATE from 0.12 to 0.15.
- **FIX APPLIED:** Raised DAMAGE_MIN_RATE from 0.12 to 0.15.

**H5: Orc Gold Income Multiplier (0.7x) Creates a Snowball Trap**
- Orcs get 0.7x gold income, but recruit at 45g (cheapest).
- At 5 tiles L1: 5 x 35 x 0.7 x 1.0 x 1.0 = 122.5g/turn.
- This means Orcs need ~4 turns to recruit a single squad when considering upkeep.
- Combined with `diplomacy_type: "conquest_only"`, Orcs can't use trade for supplemental income.
- **Recommendation:** Raise Orc gold_income_mult from 0.7 to 0.75. Small change, big early-game impact.

### MEDIUM (Noticeable but not critical)

**M1: Hero EXP Curve Mismatch Between Systems**
- `hero_level_data.gd`: `EXP_COMBAT_WIN: 10`, `EXP_PER_KILL: 2`
- `balance_config.gd`: `HERO_EXP_COMBAT_WIN: 15`, `HERO_EXP_PER_KILL: 3`
- These are different constants in different files. Which one is actually used at runtime depends on call site.
- Average EXP per turn (balance_manager estimate): 24/turn. At this rate, Lv20 (1500 cumulative) = ~62.5 turns.
- But Lv50 (21560 cumulative) = ~898 turns -- unreachable in a 60-turn game.
- Effective max level in a 60-turn game: ~Lv18-20 (with aggressive play).
- **Recommendation:** Either cap at Lv20 (original) and adjust scaling, or accept Lv50 as a New Game+ feature. Document the intended design.

**M2: Supply Depot Upkeep (2g/turn) is Trivially Cheap**
- `SUPPLY_DEPOT_UPKEEP_GOLD: 2` -- at any game stage, 2g is negligible.
- Supply depots should be a meaningful logistical choice.
- **Recommendation:** Raise to 5g/turn (still cheap, but noticeable in early game).
- **FIX APPLIED:** Changed in balance_config.gd.

**M3: Terrain Defense Asymmetry -- Mountain is Too Strong**
- Mountain: `atk_mult: 0.75`, `def_mult: 1.40`, plus cavalry banned.
- Attacker deals 75% damage while defender gets 140% DEF -- combined effect is ~1.87x defender advantage.
- Forest: `atk_mult: 0.85`, `def_mult: 1.25` -- combined ~1.47x advantage.
- Mountain creates near-impenetrable positions without siege units.
- **Recommendation:** Reduce Mountain def_mult from 1.40 to 1.30 (still strongest, but beatable).

**M4: War Exhaustion Starts Too Late and Is Too Weak**
- `WAR_EXHAUSTION_START_TURN: 50`, `WAR_EXHAUSTION_PCT_PER_TURN: 0.01`
- In a 60-turn game, this only applies for 10 turns at +1% each = +10% max.
- **Recommendation:** Start at turn 40 with 0.02%/turn for more pressure to close games.

**M5: Gift System Affection Gain is Flat Regardless of Cost**
- All gifts give +1 affection regardless of cost (15g-35g range).
- Players will always buy the cheapest gift (flower/food_gift at 15g).
- **Recommendation:** Scale affection with cost: cheap=1, medium=1, expensive=2. Or add unique effects per gift.

### LOW (Minor tuning)

**L1: Formation Front ATK Mult (1.10) vs Back Ranged ATK Mult (1.10) Parity**
- Front melee units get the same ATK bonus as back ranged units.
- Melee units already benefit from higher base ATK, making ranged relatively weaker.
- **Recommendation:** Raise FORMATION_BACK_RANGED_ATK_MULT from 1.10 to 1.15.

**L2: AP_PER_5_TILES Comment Mismatch**
- `const AP_PER_5_TILES: int = 1` with comment "Note: actually per 7 tiles now, see game_manager".
- The constant name is misleading. Should be renamed to AP_PER_7_TILES or the value/logic should match.

---

## 2. Economy Simulation (Normal Difficulty, Orc Faction)

### Assumptions
- Orc faction with `gold_income_mult: 0.7`, `food_production_mult: 1.1`
- Starting: 400g, 160f, 70i, 5 tiles, 5 army (soldiers)
- 1 army of 3 squads (T1 ashigaru x12 soldiers each = 36 soldiers)
- Expand 1-2 tiles per turn early game
- Upgrade tiles starting turn 8

### Turn 5 (Early Game)
| Resource | Income/Turn | Upkeep/Turn | Net/Turn | Stockpile |
|----------|------------|-------------|----------|-----------|
| Gold     | 5 x 35 x 0.7 x 1.0 = 122g | Soldier: 36 x 0.12 = 4.3g, Tier: 3 x 1 = 3g | +115g | ~975g |
| Food     | 5 x 8 x 1.1 x 1.0 = 44f   | 36 x 0.4 = 14.4f | +30f | ~310f |
| Iron     | 5 x 4 x 0.8 x 1.0 = 16i   | 0 | +16i | ~150i |

**Assessment:** Early game is reasonably tight. Gold stockpile looks high because army is small. Once player recruits 2nd army, gold pressure increases. Food is comfortable for Orc due to low food_per_soldier (0.4).

### Turn 15 (Mid Game)
| Resource | Income/Turn | Upkeep/Turn | Net/Turn | Stockpile |
|----------|------------|-------------|----------|-----------|
| Gold     | 12 x 45 x 0.7 x 1.3 = 491g | 72 soldiers: 8.6g + tier: ~18g = ~27g | +464g | ~5,200g |
| Food     | 12 x 12 x 1.1 x 1.3 = 206f | 72 x 0.4 = 28.8f | +177f | ~2,800f |
| Iron     | 12 x 7 x 0.8 x 1.3 = 87i   | 0 | +87i | ~1,000i |

**Assessment:** Mid-game economy is booming. Player can comfortably maintain 2 full armies and save for L3 upgrades. The 0.7x gold mult keeps Orc below Pirate income but the low upkeep compensates well.

### Turn 30 (Late Game)
| Resource | Income/Turn | Upkeep/Turn | Net/Turn | Stockpile |
|----------|------------|-------------|----------|-----------|
| Gold     | 25 x 80 x 0.7 x 1.8 = 2,520g | 120 soldiers: 14.4g + tier: ~40g + scaling(4th army: x1.2) = ~65g | +2,455g | ~35,000g |
| Food     | 25 x 25 x 1.1 x 1.8 = 1,238f | 120 x 0.4 = 48f | +1,190f | ~22,000f |
| Iron     | 25 x 12 x 0.8 x 1.8 = 432i  | 0 | +432i | ~7,500i |

**Assessment:** INFLATION WARNING. Gold stockpile is massive. Player can spam L4-L5 upgrades and max armies. The scaling army upkeep (+20% per army beyond 3) helps but isn't enough. Late-game gold sinks needed: more expensive espionage, mercenary purchases, grand festivals.

### Turn 50 (Endgame)
| Resource | Income/Turn | Upkeep/Turn | Net/Turn | Stockpile |
|----------|------------|-------------|----------|-----------|
| Gold     | 40 x 130 x 0.7 x 2.2 = 8,008g | 180 soldiers: 21.6g + tier: ~70g + scaling(3 excess armies x20% each: x1.6) = ~147g + war exhaustion(+0%) = ~147g | +7,861g | ~150,000g+ |
| Food     | 40 x 45 x 1.1 x 2.2 = 4,356f | 180 x 0.4 = 72f | +4,284f | ~90,000f+ |
| Iron     | 40 x 20 x 0.8 x 2.2 = 1,408i | 0 | +1,408i | ~35,000i+ |

**Assessment:** SEVERE INFLATION. At turn 50, the economy is completely unconstrained. War exhaustion only adds +0% at turn 50 (it starts at 50). Recommendation: Add progressive gold sinks or increase war exhaustion to start at turn 40 with 2%/turn.

---

## 3. Combat Balance Analysis

### Damage Formula: `soldiers x max(1, ATK - DEF) / 10 x skill_mult x terrain_mult`
- **Minimum damage:** 12% of soldiers count (DAMAGE_MIN_RATE: 0.12, now fixed to 0.15).
- **Orc faction passive:** Ignores 30% of enemy DEF (from GameData.FACTION_PASSIVES).
- This is very strong -- effectively turns DEF 9 into DEF 6.3, a +2.7 ATK swing.

### Formation Analysis
| Formation | ATK Effect | DEF Effect | Net Value | Verdict |
|-----------|-----------|-----------|-----------|---------|
| Wall (3F/0B) | +10% ATK (front) | +10% DEF (front) | Strong all-around | Good |
| Balanced (2F/1B) | Mixed | Mixed | Standard | Good |
| Ranged Focus (1F/2B) | +5% back ATK | +15% back DEF | Back-row focused | Niche |
| Turtle (0F/3B) | -15% ATK | +25% DEF (fixed) | Pure defense | Now viable |
| Flanking gap | -- | -- | Enemy gets +15% ATK | Avoid |

### Terrain Impact Ranking
1. Mountain: 1.87x defender advantage (with fix: 1.73x) -- strongest
2. Forest: 1.47x defender advantage -- moderate
3. Swamp: both sides reduced, cavalry crippled -- equalizer
4. Plains: neutral -- cavalry +2 ATK bonus
5. Coastal: neutral -- pirate +15% ATK

### Max Combat Rounds Analysis
- With DAMAGE_MIN_RATE at 0.15, minimum damage per action = 0.15 x soldiers.
- 12-soldier unit deals at least 1.8 damage per action.
- Over 8 rounds with 3 actions/round = 24 actions total.
- Maximum theoretical minimum damage: 24 x 1.8 = 43.2 -- enough to eliminate most individual units.
- **Verdict:** 8 rounds is sufficient with the raised min damage rate.

---

## 4. Faction Asymmetry Assessment

### Starting Resource Value (gold + food x2 + iron x3)
| Faction | Gold | Food | Iron | Weighted Value | Territories |
|---------|------|------|------|---------------|-------------|
| Orc | 400 | 160 | 70 | 400+320+210 = 930 | 5 |
| Pirate | 600 | 130 | 50 | 600+260+150 = 1010 | 4 |
| Dark Elf | 450 | 120 | 80 | 450+240+240 = 930 | 3 |

**Assessment:** Pirate starts with highest value (+80 over others) but fewest territories after Orc. Dark Elf has 8 starting slaves which adds ~5.6g/turn equivalent. Orc has most territory (5) giving early expansion advantage. This is reasonably balanced.

### Faction Identity Check
| Aspect | Orc | Pirate | Dark Elf |
|--------|-----|--------|----------|
| Army cost | Cheap (45g recruit, 0.12g/soldier upkeep) | Expensive (75g recruit, 0.35g/soldier) | Moderate (65g, 0.25g/soldier) |
| Army size | Large (cheap units, breed mechanic) | Small-medium (quality mercs) | Small-elite (slave-powered) |
| Gold income | Low (0.7x) | High (1.4x) | Moderate (1.0x) |
| Food pressure | Low (0.4 per soldier) | High (0.8 per soldier) | Very High (0.7 after fix) |
| Unique mechanic | WAAAGH! (combat momentum) | Plunder/Black Market (economy) | Slaves/Shadow Network (intel) |

**Verdict:** Faction identities are well-differentiated. The upkeep differences create meaningful trade-offs. Main concern is Dark Elf food pressure being too extreme (addressed in fix).

---

## 5. Cross-System Interactions

### Supply System
- Enemy territory attrition: 3%/turn -- reasonable for discouraging deep raids.
- Overextension threshold: 5 soldiers per tile -- at 25 tiles, that's 125 soldiers before penalty.
- With 6 armies x 6 squads x 8 soldiers avg = 288 soldiers, overextension is common at late game.
- Supply depot upkeep: 5g/turn (after fix) -- still cheap but creates a decision point.

### Espionage
- Intel cost: 10g per point (recommended raise to 15g).
- Counter-intel cost: 15g per point -- good that defense is more expensive than offense.
- Blown cover at 3 consecutive failures -- appropriate punishment.

### Diplomacy
- NAP cost: 80g + 8 prestige for 8 turns = 10g/turn + prestige opportunity cost. Reasonable.
- Alliance cost: 150g + 15 prestige for 10 turns = 15g/turn. Expensive but the ATK/DEF bonuses are modest (+10%/+5%).
- Trade: 60g for +10g/turn for 8 turns = 80g profit. Good ROI, appropriately limited to 2 agreements.
- Light ceasefire: 100g base + 3g per threat. At threat 50, cost = 250g for 5 turns peace. Appropriately expensive.

### Weather Impact
- Weather modifiers are applied late in the income chain, which can create multiplicative stacking.
- No specific balance issue identified, but weather should be monitored for interaction with buff/debuff stacking.

---

## 6. Changes Applied to balance_config.gd

| Change | Old Value | New Value | Rationale |
|--------|-----------|-----------|-----------|
| DAMAGE_MIN_RATE | 0.12 | 0.15 | Prevents stalemate battles with high-DEF armies in 8-round limit |
| UPGRADE_COSTS L5 iron | 200 | 150 | L5 iron cost was prohibitive; 150 is still expensive but achievable |
| FORMATION_TURTLE_DEF_MULT | 1.20 | 1.25 | Turtle formation was strictly dominated; now offers meaningful DEF niche |
| FORMATION_TURTLE_ATK_MULT | 0.85 | 0.90 | Reduced ATK penalty makes Turtle viable for defensive armies |
| SUPPLY_DEPOT_UPKEEP_GOLD | 2 | 5 | 2g was trivially cheap, 5g creates actual logistical decisions |

---

## 7. Recommended Future Changes (Not Applied)

1. **Raise espionage INTEL_COST_PER_POINT from 10 to 15** (in espionage_system.gd)
2. **Add late-game gold sinks** -- prestige actions cost too little relative to income at turn 30+
3. **Start War Exhaustion at turn 40** with 0.02/turn rate (currently turn 50, 0.01/turn)
4. **Reduce Mountain def_mult from 1.40 to 1.30** (in faction_data.gd TERRAIN_DATA)
5. **Reduce WAAAGH! triple passive mult from 2.50 to 1.80** (in balance_manager.gd)
6. **Raise Orc gold_income_mult from 0.7 to 0.75** (in faction_data.gd FACTION_PARAMS)
7. **Rename AP_PER_5_TILES** constant to match actual per-7-tiles behavior
8. **Reconcile hero EXP constants** between hero_level_data.gd and balance_config.gd
9. **Add gift cost scaling** -- expensive gifts should give more affection
10. **Raise FORMATION_BACK_RANGED_ATK_MULT** from 1.10 to 1.15
