# 《暗潮》 Design Reference — Data Tables & Formulas

---

## 1. Factions

### 1.1 Evil Factions (Playable)

| ID | Name | Core Mechanic | Gold | Food | Iron | Slave Capture | Special |
|----|------|---------------|------|------|------|---------------|---------|
| orc | 兽人 | WAAAGH! (战斗胜利+10, 每回合-5, >=80全军ATK+2, <=20内斗损兵) | ×0.8 | ×0.5 | ×0.8 | +50% | 无需食物维护,兵数上限+20% |
| pirate | 海盗 | 掠夺值 (攻占节点+掠夺值=节点等级×10, 可兑换金币1:1) | ×1.3 | ×1.0 | ×0.8 | base | 海上节点移动+1, 可劫掠不占领 |
| dark_elf | 暗精灵 | 奴隶分配 (俘虏→劳工/祭品/士兵, 劳工+产出, 祭品+法力, 士兵+兵数) | ×0.9 | ×1.0 | ×1.0 | +100% | 夜间战斗ATK/DEF+1, 奴隶建筑效率×1.5 |

### 1.2 Light Factions (AI Enemy)

| ID | Name | Trait |
|----|------|-------|
| human | 人类王国 | 据点DEF+3, 联盟号召力高, 圣殿女卫不可移动但超高DEF |
| high_elf | 高等精灵 | 先手优势, 法力系统, 树人守护 |
| mage | 法师公会 | 法力池机制, AoE特化, 死亡法力爆发 |

---

## 2. Unit Data (v3.0 Sengoku Rance Style)

### 2.1 Troop Type Base

| ID | Name | Role | Row |
|----|------|------|-----|
| ashigaru | 足轻 | 肉盾/前排 | front |
| samurai | 武士 | 近战输出 | front |
| archer | 弓兵 | 远程输出 | back |
| cavalry | 骑兵 | 突击/机动 | front |
| ninja | 忍者 | 暗杀/侦查 | back |
| priest | 祭司 | 治疗/buff | back |
| mage_unit | 術師 | AoE/法力 | back |
| cannon | 砲兵 | 攻城/AoE | back |

### 2.2 Commander Stats

| Stat | Range | Effect |
|------|-------|--------|
| ATK | 1-9 | 伤害公式加成 |
| DEF | 1-9 | 伤害公式减免 |
| INT | 1-9 | 技能效果×(1+INT×0.05), 法力恢复+INT×0.5 |
| SPD | 1-9 | 行动顺序, SPD相同随机 |

### 2.3 Evil Faction Troops

**Orc 兽人**

| Unit | Type | ATK | DEF | Soldiers | Passive |
|------|------|-----|-----|----------|---------|
| 兽人足軽 | 足轻 | 6 | 3 | 8 | — |
| 巨魔 | 武士 | 9 | 6 | 6 | 每回合回复1兵 |
| 战猪骑兵 | 骑兵 | 8 | 4 | 5 | 冲锋首击×1.5 |

**Pirate 海盗**

| Unit | Type | ATK | DEF | Soldiers | Passive |
|------|------|-----|-----|----------|---------|
| 海盗散兵 | 足轻 | 5 | 4 | 6 | 30%逃跑免死 |
| 火枪手 | 弓兵 | 7 | 3 | 5 | 先手射击(SPD视为+2) |
| 炮击手 | 砲兵 | 10 | 2 | 4 | 城防削减×2 |

**Dark Elf 暗精灵**

| Unit | Type | ATK | DEF | Soldiers | Passive |
|------|------|-----|-----|----------|---------|
| 暗精灵战士 | 武士 | 7 | 5 | 5 | 每回合行动+1 |
| 暗影刺客 | 忍者 | 5 | 2 | 4 | 可暗杀后排 |
| 冷蜥骑兵 | 骑兵 | 8 | 6 | 5 | 无视地形减益 |

### 2.4 Light Faction Troops

**Human 人类**

| Unit | Type | ATK | DEF | Soldiers | Passive |
|------|------|-----|-----|----------|---------|
| 民兵 | 足轻 | 4 | 6 | 8 | 据点内DEF+3 |
| 骑士 | 骑兵 | 7 | 7 | 6 | 反击×1.2 |
| 圣殿女卫 | 武士 | 6 | 9 | 10 | 不可移动 |

**High Elf 高等精灵**

| Unit | Type | ATK | DEF | Soldiers | Passive |
|------|------|-----|-----|----------|---------|
| 精灵游侠 | 弓兵 | 7 | 3 | 5 | 先手攻击×1.3 |
| 法师 | 術師 | 8 | 2 | 4 | AoE, 消耗法力 |
| 树人 | 足轻 | 4 | 10 | 15 | 守护嘲讽(吸引攻击) |

**Mage 法师公会**

| Unit | Type | ATK | DEF | Soldiers | Passive |
|------|------|-----|-----|----------|---------|
| 学徒法师 | 術師 | 4 | 3 | 4 | 每回合充能法力池+1 |
| 战斗法师 | 術師 | 8 | 4 | 5 | AoE×1.5, 消耗5法力 |
| 大法师 | 術師 | 9 | 7 | 8 | 死亡时法力爆发(对敌全体ATK×2伤害) |

---

## 3. Combat System

### 3.1 Battle Layout

```
Front Row: [slot1] [slot2] [slot3]
Back Row:  [slot4] [slot5]
Total action slots per battle: 12
```

### 3.2 Damage Formula

```
base_damage = soldiers × max(1, attacker_ATK - defender_DEF) / 10
final_damage = base_damage × skill_multiplier × terrain_modifier
soldiers_killed = floor(final_damage)
```

### 3.3 Action Queue

```
Sort all units by SPD descending.
Ties: random.
Each unit acts once per round (except passives granting +1 action).
Battle ends when one side has 0 soldiers or after 12 rounds.
After 12 rounds: defender wins.
```

### 3.4 Terrain Modifiers

| Terrain | ATK Mod | DEF Mod | Note |
|---------|---------|---------|------|
| 平原 | ×1.0 | ×1.0 | 骑兵ATK+1 |
| 森林 | ×0.9 | ×1.1 | 弓兵ATK+1, 骑兵ATK-1 |
| 山地 | ×0.8 | ×1.2 | 骑兵不可进入(冷蜥骑兵除外) |
| 沼泽 | ×0.9 | ×0.9 | SPD-2(全体) |
| 城墙 | ×0.7 | ×1.5 | 需先破城防 |

### 3.5 City Defense

```
city_defense: per node (default by type: village=5, town=10, fortress=20)
siege_damage = attacker_ATK × 0.5 per attack (砲兵 ×2)
city_defense auto-recover: +3 per turn (owner's turn)
combat starts only when city_defense <= 0
```

---

## 4. Economy

### 4.1 Resources

| ID | Name | Type | Use |
|----|------|------|-----|
| gold | 金币 | economic | 建筑/招募/维护 |
| food | 粮食 | economic | 兵员维护(1兵=0.1食/回合, 兽人豁免) |
| iron | 铁矿 | economic | 装备/升级/建筑 |
| slaves | 奴隶 | economic | 劳动/祭品/转化兵员(暗精灵特化) |
| prestige | 威望 | economic | 外交/解锁/事件选项 |
| crystal | 魔晶 | strategic | 法术研究/術師招募 |
| horse | 战马 | strategic | 骑兵招募/加速行军 |
| gunpowder | 火药 | strategic | 砲兵招募/火枪手弹药 |
| shadow | 暗影精华 | strategic | 暗精灵专属/暗杀/诅咒 |

### 4.2 Node Types & Base Income

| Type | Gold | Food | Iron | Garrison Cap | City Defense |
|------|------|------|------|-------------|-------------|
| village | 10 | 5 | 1 | 3 | 5 |
| stronghold | 15 | 3 | 5 | 5 | 10 |
| bandit_camp | 5 | 2 | 2 | 3 | 5 |
| event_point | 8 | 3 | 1 | 3 | 5 |
| fortress | 20 | 5 | 8 | 8 | 20 |

### 4.3 Node Upgrade

| Level | Cost | Income Mult | Garrison Bonus |
|-------|------|-------------|----------------|
| Lv1 | — | ×1.0 | +0 |
| Lv2 | 100g + 10i | ×1.5 | +1 |
| Lv3 | 200g + 20i | ×2.0 | +2 |

---

## 5. Buildings

### 5.1 Universal Buildings

| ID | Name | Lv1 Effect | Lv2 Effect | Lv3 Effect | Cost Lv1/2/3 |
|----|------|-----------|-----------|-----------|--------------|
| slave_market | 奴隶市场 | 奴隶交易(买卖) | 交易税-10% | 自动捕获+1/回合 | 50g/100g/200g |
| labor_camp | 劳动营 | 奴隶产出+10% | +20% | +30% | 40g+5i/80g+10i/160g+20i |
| arena | 竞技场 | 驻军经验+10%/回合 | +20% | +30%+随机技能习得 | 60g/120g/240g |
| training_ground | 训练场 | 招募速度+1 | +2 | +3+精英兵种解锁 | 50g+5i/100g+10i/200g+20i |

### 5.2 Faction Buildings

| Faction | ID | Name | Lv1 | Lv2 | Lv3 | Cost Lv1/2/3 |
|---------|-----|------|-----|-----|-----|--------------|
| orc | totem_pole | 战争图腾 | WAAAGH!衰减-2/回合 | 衰减-3+ATK+1全军 | 衰减-4+暴走免疫 | 60g/120g/240g |
| pirate | black_market | 黑市 | 掠夺值兑换率1.2:1 | 1.5:1+稀有物品刷新 | 2:1+走私路线(隐蔽运输) | 60g/120g/240g |
| dark_elf | pain_temple | 苦痛神殿 | 祭品转化效率+20% | +40%+诅咒技能 | +60%+复活1英雄(每10回合) | 60g+5shadow/120g+10shadow/240g+20shadow |

---

## 6. Order Value (秩序值)

Per node, range 0-100. Starts at 50 on capture.

| Range | Output Mult | Revolt Chance/Turn | Enemy Morale Effect |
|-------|-------------|-------------------|---------------------|
| 0-25 | ×0.5 | 20% | — |
| 26-50 | ×0.75 | 10% | — |
| 51-75 | ×1.0 | 0% | — |
| 76-100 | ×1.15 | 0% | Enemy morale -20% |

```
Modifiers per turn:
  garrison_present: +5
  building_constructed: +3
  no_garrison: -10
  recently_conquered: -5 (3 turns)
  slave_labor_active: -3
  event_bonus: varies
```

---

## 7. Threat Value (威胁值)

Global, per light faction's perception of player. Range 0-100.

| Range | AI Behavior |
|-------|-------------|
| 0-29 | Independent (factions act alone) |
| 30-59 | Defense Alliance (attacked faction calls 1 neighbor) |
| 60-79 | Military Alliance (2-3 factions coordinate attacks) |
| 80-100 | Desperate Resistance (all light factions unite, +10% ATK/DEF) |

```
Threat increases:
  +10 per node conquered
  +20 per hero captured
  +5 per turn if player controls >= 50% nodes
Threat decreases:
  -5 per turn (natural decay)
  -10 on releasing captured hero
  -15 on diplomatic event (gift/trade)
```

---

## 8. Heroes (18 Total)

### 8.1 Light Faction Heroes (Capturable)

| Name | Faction | Troop Type | ATK | DEF | INT | SPD | Capture Condition | Active Skill | Passive Skill |
|------|---------|-----------|-----|-----|-----|-----|-------------------|-------------|--------------|
| 凛 | human | 武士 | 7 | 8 | 5 | 4 | 败北后50%捕获 | 圣光斩(单体ATK×1.8) | 守护决心(DEF+2 when HP<50%) |
| 雪乃 | human | 祭司 | 3 | 4 | 8 | 5 | 凛被捕后自动加入 | 治愈之光(恢复2兵) | 祝福(全队DEF+1) |
| 红叶 | human | 骑兵 | 5 | 5 | 7 | 6 | 外交事件(威望>=30) | 突击号令(骑兵全体ATK+2, 1回合) | 指挥官(相邻友军SPD+1) |
| 冰华 | human | 武士 | 6 | 9 | 4 | 3 | 圣殿要塞攻陷后捕获 | 不动如山(本回合免疫伤害) | 圣殿之盾(前排DEF+2) |
| 翠玲 | high_elf | 弓兵 | 8 | 3 | 6 | 7 | 败北后30%捕获,需秩序>=60 | 箭雨(后排AoE, ATK×1.2) | 精灵之眼(弓兵先手+1) |
| 月华 | high_elf | 祭司 | 4 | 5 | 9 | 4 | 翠玲好感>=3后事件 | 月光护盾(全队减伤30%, 1回合) | 法力涌泉(每回合+1法力) |
| 叶隐 | high_elf | 忍者 | 6 | 4 | 5 | 8 | 暗杀任务成功后加入 | 影步(无视前排攻击后排) | 隐匿(首回合不可被targeting) |
| 蒼 | mage | 術師 | 9 | 6 | 9 | 3 | 法师公会总部攻陷 | 流星火雨(全体AoE, ATK×2, 消耗8法力) | 大贤者(INT+2, 法力上限+5) |
| 紫苑 | mage | 術師 | 5 | 4 | 9 | 7 | 蒼被捕后事件 | 时间减速(敌方SPD-3, 2回合) | 时空感知(回避率+15%) |
| 焔 | mage | 術師 | 8 | 3 | 7 | 8 | 败北后40%捕获 | 爆裂火球(单体ATK×2.5, 消耗3法力) | 火焰亲和(火系技能伤害+20%) |

### 8.2 Pirate / Dark Elf Heroes

| Name | Faction | Troop Type | ATK | DEF | INT | SPD | Capture Condition | Active Skill | Passive Skill |
|------|---------|-----------|-----|-----|-----|-----|-------------------|-------------|--------------|
| 潮音 | pirate | 弓兵 | 7 | 4 | 5 | 7 | 海盗主线剧情(回合15+) | 连射(攻击2次,每次ATK×0.7) | 海风(海域地形ATK+2) |
| 妖夜 | dark_elf | 忍者 | 6 | 3 | 4 | 9 | 暗精灵主线剧情(回合10+) | 致命一击(暗杀,ATK×3,miss率40%) | 夜行者(夜间SPD+2) |

### 8.3 Neutral Leaders (6, guard neutral bases)

| Name | Troop Type | ATK | DEF | INT | SPD | Location | Join Condition | Skill |
|------|-----------|-----|-----|-----|-----|----------|----------------|-------|
| 響 | 足轻 | 5 | 7 | 4 | 5 | 山岳要塞 | 击败后100%加入 | 铁壁(DEF+3, 1回合) |
| 沙罗 | 弓兵 | 7 | 3 | 6 | 6 | 沙漠绿洲 | 击败后100%加入 | 沙暴(敌方命中-30%, 2回合) |
| 冥 | 術師 | 8 | 2 | 8 | 4 | 废墟神殿 | 击败后100%加入 | 亡灵召唤(召唤2兵骷髅, 持续3回合) |
| 枫 | 忍者 | 6 | 4 | 5 | 9 | 隐秘森林 | 击败后100%加入 | 分身(回避下一次攻击) |
| 朱音 | 祭司 | 3 | 5 | 7 | 5 | 古代圣地 | 击败后100%加入 | 净化(移除1个debuff+恢复1兵) |
| 花火 | 砲兵 | 9 | 2 | 5 | 3 | 废弃矿山 | 击败后100%加入 | 集中轰炸(单体ATK×2.2, 城防×3) |

### 8.4 Hero Mechanics

```
Affection: 0-10 per hero. +1 per battle together, +2 event choice.
  Lv3: unlock passive upgrade
  Lv5: unlock unique event
  Lv7: unlock second active skill
  Lv10: exclusive ending flag

Capture: defeated hero has capture% chance. Captured heroes go to prison.
  Prison capacity: 3 (upgradeable to 5).
  Each turn in prison: +1 corruption, at corruption>=5 can recruit (50% success).
  Release: -threat, +prestige.
```

---

## 9. Map Generation

### 9.1 Parameters

```
total_nodes: 50-60
core_fortresses: 8 (2 per light faction, 2 neutral)
outposts: 20-25
resource_stations: 8-12
neutral_bases: 6 (one per neutral leader)
player_start: 1 fortress + 2 adjacent villages
```

### 9.2 Generation Algorithm

```
1. Place 8 fortress nodes (evenly spaced, min distance 5 grid units)
2. Place 6 neutral bases (min distance 3 from fortresses)
3. Scatter remaining nodes randomly (min distance 2 between any two)
4. Build edges: Kruskal MST on all nodes (ensures connectivity)
5. Add random edges: 15-20% extra (for alternate paths)
6. Assign node types by proximity:
   - Adjacent to fortress → stronghold (40%) or village (60%)
   - Cluster of 3+ → one becomes event_point
   - Isolated → bandit_camp
7. Assign terrain randomly: 平原40%, 森林25%, 山地15%, 沼泽10%, 特殊10%
8. Assign factions:
   - Human: north region
   - High Elf: east region
   - Mage: center
   - Player start: south
   - Neutral: scattered
```

### 9.3 Distance & Movement

```
Movement: 1 node per turn per army
Forced march: 2 nodes, soldiers -10%
Scout range: 2 nodes (忍者 extends to 3)
Supply line: broken if path to owned node > 3 hops → -2 soldiers/turn
```

---

## 10. Turn Structure

```
Phase 1: Income — collect resources from all owned nodes (apply faction/order mods)
Phase 2: Upkeep — pay food (1兵=0.1食), deduct maintenance
Phase 3: Events — trigger story/random events, hero interactions
Phase 4: Strategy — build, recruit, upgrade, deploy, move armies, diplomacy
Phase 5: Combat — resolve all battles (attacker moves into defended node)
Phase 6: Resolution — capture nodes, capture heroes, update order/threat
Phase 7: AI Turn — enemy factions execute same phases
Phase 8: World Update — decay threat, recover city defense, tick WAAAGH!/掠夺值
```

---

## 11. Recruitment

```
Base recruit cost: soldiers × 2g per soldier
Type surcharge: 足轻×1, 武士×1.5, 弓兵×1.2, 骑兵×2, 忍者×1.8, 祭司×1.5, 術師×2, 砲兵×2.5
Recruit time: 1 turn (training_ground reduces by level)
Replenish: stationed army at owned node, cost = lost_soldiers × 1.5g, 1 turn
Max armies in field: 3 + 1 per 10 nodes owned
```

---

## 12. Mana System (術師/法师公会)

```
Mana pool: per army, starts at 0, max = 10 + (INT of highest INT unit × 2)
Regen: +1 per turn + 学徒法师 passive + 月华 passive
Spend: per skill (see hero/unit skills for costs)
Overflow: if pool > max, excess lost
```

---

## 13. Slave System (Dark Elf Specialization)

```
Capture: defeated enemy soldiers × capture_rate (base 10%, dark_elf +100% = 20%)
Allocation per turn:
  Labor: +0.5 gold per slave per node
  Sacrifice: 1 slave = 2 shadow essence = 1 mana
  Convert: 3 slaves = 1 soldier (any owned troop type)
Slave cap: 5 per node × node level
Slave revolt: if slaves > garrison soldiers × 3, 10% revolt/turn (lose all slaves in node)
```

---

## 14. Items & Loot

```
Rarity: common(60%) / rare(30%) / legendary(10%)
Slot: weapon / armor / accessory (1 each per hero)
Drop: post-battle loot table, event rewards, black_market purchase

Example items:
  血月之刃(legendary, weapon): ATK+3, 击杀恢复1兵
  铁壁之盾(rare, armor): DEF+2, 城防+5本节点
  疾风之靴(rare, accessory): SPD+2
  奴隶枷锁(common, accessory): 俘获率+10%
  法力宝珠(rare, accessory): 法力上限+3
```

---

## 15. Win/Lose Conditions

```
Victory: Conquer all 8 core fortresses
Defeat: Lose all owned nodes OR player commander killed (no retreat)
Score: nodes×10 + heroes×50 + turns_survived×2 + prestige
Endings: vary by affection levels (hero-specific flags at Lv10)
```

---

## 16. Key Constants

```python
MAX_TURNS = 100
STARTING_GOLD = 200
STARTING_FOOD = 100
STARTING_IRON = 50
STARTING_SLAVES = 10  # dark_elf only, others 0
BASE_ORDER = 50
BASE_THREAT = 0
CITY_DEF_RECOVERY = 3  # per turn
WAAAGH_DECAY = 5       # per turn
WAAAGH_GAIN_ON_WIN = 10
WAAAGH_BUFF_THRESHOLD = 80   # ATK+2 all
WAAAGH_CRISIS_THRESHOLD = 20 # infighting
PRISON_CAPACITY = 3
CORRUPTION_TO_RECRUIT = 5
AFFECTION_MAX = 10
MANA_BASE_MAX = 10
SUPPLY_LINE_MAX_HOPS = 3
```

---

## 17. Dev Roadmap

| Step | Module | Dependencies | Key Deliverables |
|------|--------|-------------|-----------------|
| 1 | Data Layer | none | Enums (faction, troop_type, terrain, resource), dataclass/dict for all tables above |
| 2 | Map Generation | Step 1 | Node graph, Kruskal MST, region assignment, node type/terrain |
| 3 | Turn Loop + Economy | Steps 1-2 | Turn phases, income calc, upkeep, resource tracking |
| 4 | Combat System | Steps 1-3 | Damage formula, action queue, front/back row, terrain mods, city defense |
| 5 | Building System | Steps 1-3 | Build/upgrade, per-node buildings, faction buildings, effect application |
| 6 | Hero + Slave System | Steps 1-4 | Hero roster, capture/recruit, affection, prison, slave allocation |
| 7 | Events + Items | Steps 1-6 | Event triggers, item drops, loot table, story flags |
| 8 | AI | Steps 1-7 | Threat response, army movement, alliance behavior, difficulty scaling |
| 9 | UI / HUD | Steps 1-8 | Map view, battle view, resource bar, hero panel, event dialogs |
| 10 | Integration + Balance | All | Full loop test, number tuning, difficulty curves, ending paths |

---

## 18. Implementation Status (v1.1)

> Last updated: 2026-03-22

### 已实现系统

| 系统 | 对应文件 | 状态 | 备注 |
|------|---------|------|------|
| 战斗系统 | combat_resolver.gd | v1.0 重写 | 战国兰斯式回合制，前后排，SPD队列，12回合上限 |
| 威胁值 | threat_manager.gd | v1.0 修正 | 衰减-5/回合，占领+10，俘英雄+20，间隔制远征/Boss |
| WAAAGH! | orc_mechanic.gd | v1.0 修正 | 阈值80(非50)，内斗<=20时10%概率 |
| 奴隶系统 | slave_manager.gd | v1.0 补全 | 3奴隶=1士兵转化，节点容量5×等级，暴动检测，劳工收入 |
| 英雄系统 | hero_system.gd | v1.0 | 18英雄完整，俘获/招募/好感/装备/主动技能 |
| 兵种数据 | faction_data.gd | v1.1 对齐 | UNIT_DEFS/LIGHT_UNIT_DEFS/ULTIMATE_UNITS全部对齐11_兵种数据包 |
| 招募系统 | recruit_manager.gd | v1.1 修正 | 支持新数据格式(soldiers/spd/row/recruit_gold)，金币制招募 |
| 训练树 | faction_data.gd FACTION_TRAINING_TREE | v1.1 对齐 | T1=1回合/T2=2回合/T3=3回合，金币制，对齐16_训练系统 |
| 建筑系统 | building_registry.gd | v0.9 | 35种建筑×3级，效果大部分已连接 |
| 经济系统 | production_calculator.gd | v0.9 | 资源收入/维护/建筑加成 |
| AI系统 | ai_scaling.gd + alliance_ai.gd | v0.8.5 | 4级威胁缩放，联军AI |
| 科技研究 | research_manager.gd | v0.8.5 | 每阵营9节点训练树(4T1+4T2+1T3) |
| 任务链 | quest_manager.gd | v0.8.5 | 6中立势力任务链(铁锤矮人/沙罗/冥/枫/朱音/花火) |
| 事件系统 | event_system.gd | v0.8.5 | 20事件(10通用+6阵营+4光明反击)，2选项制 |
| NPC系统 | npc_manager.gd | v0.8.5 | 10NPC服从度系统，5阶段(叛逆/抗拒/屈从/服从/忠诚) |
| 外交系统 | diplomacy_manager.gd | v0.8.5 | 恶势力外交/武力收编，叛乱机制 |
| 装备系统 | hero_system.gd + item_manager.gd | v0.8.7 | 8装备(3槽位)，道具背包(8格)，掉率(60%普/30%稀/10%传说) |
| 遗物系统 | relic_manager.gd | v0.8.5 | 6遗物，战斗/经济/招募加成 |
| 地图生成 | map_generator.gd | v0.8.3 | 50-60节点随机图，8要塞+6中立+12命名前哨 |
| 存档系统 | save_manager.gd | v0.9.1 | JSON格式，版本兼容，F5/F9快捷存读 |
| MOD系统 | mod_manager.gd | v0.8.5 | user://mods/扫描，优先级排序，JSON覆盖 |

### 关键公式实现

```
# 战斗伤害 (05_行动设定.md)
damage = soldiers × max(1, ATK - DEF) / 10 × skill_mult × terrain_mult

# 粮食消耗 (04_经济设定.md)
food_upkeep = 每兵 × 0.1食/回合 (兽人×0.5豁免, 骷髅免)

# 招募费用 (04_经济设定.md)
recruit_cost = 兵数 × 2金 × 兵种加价 (足轻×1 ~ 砲兵×2.5)

# 法力上限 (05_行动设定.md)
mana_max = 10 + 最高INT单位 × 2

# 秩序产出 (03_战略设定.md)
0-25: ×0.5 | 26-50: ×0.75 | 51-75: ×1.0 | 76-100: ×1.15
```

### 代码架构

```
project/
├── autoloads/          # 44个单例自动加载
│   ├── game_manager.gd   # 主循环，8阶段回合制
│   ├── event_bus.gd       # 122+信号松耦合
│   └── save_manager.gd   # 存档管理
├── systems/
│   ├── combat/
│   │   ├── combat_resolver.gd  # v1.0 回合制战斗核心
│   │   └── recruit_manager.gd  # v1.1 兵种招募（新数据格式）
│   ├── faction/
│   │   ├── faction_data.gd     # v1.1 全局常量/数据表（所有DEFS已对齐文档）
│   │   ├── orc_mechanic.gd     # WAAAGH!
│   │   ├── pirate_mechanic.gd  # 掠夺值
│   │   ├── diplomacy_manager.gd # 恶势力外交
│   │   └── ai_scaling.gd       # AI威胁缩放
│   ├── economy/
│   │   ├── slave_manager.gd    # v1.0 奴隶分配/转化/暴动
│   │   ├── item_manager.gd     # 道具背包(8格)
│   │   └── production_calculator.gd  # 收入计算
│   ├── building/
│   │   ├── building_registry.gd  # 35种建筑数据+效果
│   │   └── research_manager.gd   # v1.1 科技研究（金币制，对齐文档回合数）
│   ├── hero/
│   │   └── hero_system.gd       # 18英雄完整系统+装备
│   ├── npc/
│   │   ├── npc_manager.gd       # 10NPC服从度系统
│   │   └── quest_manager.gd     # 6中立势力任务链
│   ├── event/
│   │   └── event_system.gd      # 20全局事件
│   └── values/
│       ├── threat_manager.gd    # 威胁值(0-100)
│       └── order_manager.gd     # 秩序值(0-100)
```

### v1.1 变更记录 (2026-03-22)

- **兵种数据对齐**: UNIT_DEFS/LIGHT_UNIT_DEFS/ULTIMATE_UNITS/ALLIANCE_UNIT_DEFS全部使用新格式(soldiers/spd/row/recruit_gold/special)，ID对齐11_兵种数据包.md
- **招募系统修正**: recruit_manager.gd支持recruit_gold/cost_mult两种定价，移除iron成本，兵种ID更新
- **训练树对齐**: 金币制(移除iron/strategic成本)，T1=1回合/T2=2回合/T3=3回合，名称和效果匹配16_训练系统.md
- **向后兼容**: combat_resolver.gd保留新旧ID映射表，支持旧存档
