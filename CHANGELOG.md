# 《暗潮 Dark Tide》更新日志

---

## v1.4.0 — 2026-03-22 (V1+V2 合并版)

### 从 V2 分支合并的内容

**combat_system.gd (新增, 769行)** — 独立战斗引擎:
- class_name CombatSystem, 可通过 `CombatSystem.new().resolve_battle()` 调用
- BattleUnit 内部类: id/commander_id/troop_id/atk/def/spd/soldiers/row/slot/passive/mana
- BattleState 内部类: 管理双方部队、地形、回合、法力池、战斗日志
- 5格阵型 (前排3 + 后排2), SPD降序行动队列, 12回合上限
- 先手阶段: preemptive/preemptive_1_3 被动触发
- AoE法术: aoe_mana/aoe_1_5_cost5, 消耗法力打击整行
- 攻城阶段: siege_x2 双倍破城, 城墙残余→防御加成
- 被动系统: regen_1/charge_mana_1/charge_1_5/extra_action/escape_30/death_burst/
  counter_1_2/taunt/assassinate_back/fort_def_3/ignore_terrain
- 目标选择: 嘲讽优先→前排阻挡→忍者穿透→后排射程
- 地形修正: 平原骑兵+1ATK, 森林弓兵+1ATK, 山地骑兵禁入, 沼泽SPD-2, 要塞防御x1.5
- 完整战斗日志返回 (log: Array[Dictionary])

**map_generator.gd (新增, 614行)** — 程序化地图生成:
- class_name MapGenerator, 可通过 `MapGenerator.new().generate(player_faction)` 调用
- Kruskal MST 算法保证全连通 + 15-20% 额外边提供多路径
- UnionFind 内部类 (路径压缩 + 按秩合并)
- 50-60个节点, 最小间距80px, 1280x720地图
- 8核心要塞固定位置 (贪心最远点放置 + 抖动)
- 节点类型分配: 村庄40%/据点25%/匪寨20%/事件点15%
- 资源站: 魔晶/战马/火药/暗影 各2-3个
- 6中立据点: 草原部落/山贼/废墟前哨/沙漠商队/冰原猎手/暗巷佣兵
- 地形权重: 平原40%/森林25%/山地15%/沼泽10%/城墙10%
- 玩家出生: 对应阵营要塞 + 2个相邻村庄
- 区域势力划分: 北=人类, 东=精灵, 中=法师, 西南=玩家

### 存档系统升级 (save_manager.gd)

- 版本号: 0.8.6 → 1.4.0
- 新增 AI 状态持久化: LightFactionAI/AllianceAI/EvilFactionAI 的 to_save_data/from_save_data
- 兼容旧存档: 缺少 light_faction_ai 键时回退到 init_light_defenses()

### CombatSystem 接入 (game_manager.gd)

- `_resolve_army_combat()` 重写: 用 CombatSystem.new().resolve_battle() 替代旧版简单战力比较
- 攻方军团 troops → CombatSystem.BattleUnit 格式转换 (atk/def/spd/row/slot/passive)
- 守方驻军 → garrison_troops 或 fallback 通用步兵分队
- 地形 → CombatSystem.Terrain 枚举映射
- 攻城支持: wall_hp > 0 时启用 siege 阶段
- 战后损失按 BattleUnit 粒度回写到 army.troops
- 英雄俘获: captured_heroes → HeroSystem.attempt_capture()
- 新增 `_terrain_to_combat_enum()` 辅助函数

### 三路胜利条件 (game_manager.gd)

- `check_win_condition()` 重写，支持 3 种胜利路径:
  - **征服胜利**: 攻占所有光明联盟要塞 (LIGHT_STRONGHOLD + CORE_FORTRESS)
  - **支配胜利**: 控制 ≥60% 地图节点
  - **暗影统治**: 威胁值 100 + 拥有终极兵种
- 新增 2 种失败条件:
  - 玩家被消灭 (无军队 + 无领地)
  - 所有暗黑势力被光明联盟消灭

---

## v1.3.0 — 2026-03-22 (驯服系统 + 外交修复 + AI强化)

### 驯服系统实装 (quest_manager.gd)

- 新增 `_taming_levels` 持久化字典 — 每玩家×每中立势力驯服度 (0-10)
- `get_taming_level()` — 支持int(枚举)和String(标签)双入口
- `set_taming_level()` — 任务推进时+3, 完成时=10
- `get_taming_tier()` — 5级别: hostile/neutral/friendly/allied/tamed
- `get_unlocked_neutral_troops()` — 从招募奖励提取可招兵种
- `_resolve_faction_tag()` / `_resolve_faction_id()` — ID⇄标签双向转换
- `_get_faction_name()` — 从标签获取中文显示名
- `NEUTRAL_FACTIONS` — 运行时构建的标签→数据映射表
- `tick_turn()` — 每回合处理(包装process_turn + 未来衰减扩展)
- `advance_quest()` 扩展: 每步+3驯服度
- `complete_quest()` 扩展: 驯服度设为10
- Save/Load 扩展: 驯服度持久化

### 外交系统修复

**game_manager.gd — _handle_neutral_quest()**:
- 移除重复的费用扣除/奖励发放逻辑, 委托给quest_manager
- 新增战斗触发分支: requires_combat→set_pending_combat→emit信号
- 消除对不存在的 NEUTRAL_FACTIONS 常量的崩溃引用

**game_manager.gd — get_diplomacy_targets()**:
- 所有 QuestManager 调用现在有对应实现, 不再崩溃
- 驯服等级/阶段/可招兵种正确传递给HUD

### HUD修复 (hud.gd)

- 修复 `_on_domestic_recruit()`: 恢复被误删的 `_show_target_panel` + `var available` 行
- 修复 `_update_tile_info()`: `player["position"]` → 棋盘选中格/己方领地回退
- 修复 `_update_tile_info_for()`: `GameData.TERRAIN_DATA` → `FactionData.TERRAIN_DATA`
- 部署按钮: 加入 `_update_buttons()` 和 `_set_all_buttons_disabled()`
- 模式高亮: 攻击/部署的子模式(SELECT_ATTACK_TARGET/SELECT_DEPLOY_TARGET)也显示高亮

### AI强化 (game_manager.gd — run_ai_turn)

- Phase 0: 无军团时自动创建 (优先核心要塞/暗黑基地)
- Phase 1: 攻击评分系统扩展 — 考虑军团战力vs驻军、领地连接奖励、港口/关隘价值
- Phase 2: 部署评分系统 — 弱防御邻接加分, 不再只选第一个
- Phase 3: 招募改善 — 优先在军团驻扎格招募
- Phase 4 (新): 多军团创建 — 前线附近无军团格自动建军
- Phase 5: 探索保留为兜底行动
- `_ai_score_attack()`: 新增军团参数、领地连接评分、强敌回避(-15)

### Board修复 (board.gd)

- `_deselect_tile()` 现在发射 `territory_deselected` 信号

---

## v1.2.0 — 2026-03-22 (多军团系统 + 地域制压 + 数据合并)

### 多军团系统 (核心重构)

**game_manager.gd — Army System**:
- 新增 `armies: Dictionary` — 独立军团对象 (id/player_id/tile_index/name/troops/heroes)
- 玩家最多3支军团 (建筑可升级至5支), 每支最多5编制+2英雄
- `create_army()` / `disband_army()` — 军团生命周期管理
- `action_deploy_army()` — 部署至相邻己方地域 (1 AP)
- `action_forced_march()` — 强行军2格, 损耗10%兵力 (2 AP)
- `action_attack_with_army()` — 军团进攻相邻敌方地域 (1 AP)
- `_resolve_army_combat()` — 地形/关隘修正, 按比例损失
- `calculate_supply_line()` — BFS计算至核心要塞最短路径
- `_tick_supply_lines()` — 补给线衰减: >5格-2兵/回合, 断线-5兵/回合
- 移除旧版骰子移动 (`roll_dice()`/`select_move_target()` 标记为Legacy)

**board.gd — 军团可视化**:
- 军团标记: 盾牌模型 + Label3D (军团名+兵力)
- 颜色编码与阵营对应
- 点击己方军团 → 自动选中, 显示绿色(部署)/红色(进攻)高亮环
- 点击高亮地域 → 执行部署或进攻

**hud.gd — 军团信息面板**:
- 地域信息新增军团详情: 名称/编制数/总兵力/战力
- 补给线状态显示 (绿色/橙色/红色)

**event_bus.gd — 新信号**:
- `army_created`, `army_disbanded`, `army_selected`

**AI系统更新**:
- `run_ai_turn()` 重写为军团感知: 优先攻击→部署前线→招募→探索
- AI使用 `action_attack_with_army()` 和 `action_deploy_army()`

### 数据合并 (v1.0+v1.1 cherry-pick)

从战斗系统重写分支合并:
- **combat_resolver.gd**: v1.0完全重写 (战国兰斯式回合制, 5槽位编制, SPD行动队列)
- **faction_data.gd**: v1.1数据对齐 (新兵种ID, 训练树重构, 终极兵种)
- **20个子系统更新**: building_registry, item_manager, light_faction_ai, quest_manager, threat_manager, slave_manager, hero_system, buff_manager, production_calculator等
- **单位ID统一**: grunt→orc_ashigaru, militia→human_ashigaru等 (game_manager.gd内同步更新)
- **设计文档更新**: 05_行动设定, 11_兵种数据包, 16_训练系统, design_reference

---

## v1.1.0 — 2026-03-22 (数据对齐 + 训练树重构)

### 兵种数据全面对齐 11_兵种数据包.md

**faction_data.gd — UNIT_DEFS (邪恶阵营兵种)**
- 兽人: `grunt` → `orc_ashigaru` (ATK 8→6, DEF 3, 兵数 8, 16g)
- 兽人: `troll` → `orc_samurai` (ATK 15→9, DEF 8→6, 兵数 6, 27g, regen_1)
- 兽人: `warg_rider` → `orc_cavalry` (ATK 12→8, DEF 5→4, 兵数 5, 40g, charge_1_5)
- 海盗: `cutthroat` → `pirate_ashigaru` (ATK 6→5, DEF 4, 兵数 6, 12g, escape_30)
- 海盗: `gunner` → `pirate_archer` (ATK 10→7, DEF 3, 兵数 5, 14g, preemptive)
- 海盗: `bombardier` → `pirate_cannon` (ATK 14→10, DEF 2, 兵数 4, 50g, siege_x2)
- 暗精灵: `warrior` → `de_samurai` (ATK 9→7, DEF 6→5, 兵数 5, 22g, extra_action)
- 暗精灵: `assassin` → `de_ninja` (ATK 7→5, DEF 2, 兵数 4, 25g, assassinate_back)
- 暗精灵: `cold_lizard` → `de_cavalry` (ATK 11→8, DEF 7→6, 兵数 5, 40g, ignore_terrain)
- 数据格式统一: 新增 `soldiers`/`spd`/`row`/`recruit_gold`/`class` 字段，移除 `hp`/`cost_gold`/`cost_iron`

**faction_data.gd — LIGHT_UNIT_DEFS (光明阵营兵种)**
- 人类: `militia` → `human_ashigaru` (ATK 5→4, DEF 8→6, 兵数 8, fort_def_3)
- 人类: `knight` → `human_cavalry` (ATK 10→7, DEF 8→7, 兵数 6, counter_1_2)
- 人类: `temple_guard` → `human_samurai` (ATK 8→6, DEF 15→9, 兵数 10, immobile)
- 精灵: `elf_ranger` → `elf_archer` (ATK 9→7, DEF 4→3, 兵数 5, preemptive_1_3)
- 精灵: `elf_mage` 保留 (ATK 12→8, DEF 3→2, 兵数 4, aoe_mana)
- 精灵: `treant` → `elf_ashigaru` (ATK 6→4, DEF 18→10, 兵数 15, taunt)
- 法师: `apprentice_mage` → `mage_apprentice` (ATK 5→4, DEF 3, 兵数 4, charge_mana_1)
- 法师: `battle_mage` → `mage_battle` (ATK 11→8, DEF 5→4, 兵数 5, aoe_1_5_cost5)
- 法师: `archmage` → `mage_grand` (ATK 14→9, DEF 10→7, 兵数 8, death_burst)

**faction_data.gd — ULTIMATE_UNITS (终极兵种)**
- 狂暴巨兽: ATK 20→12, DEF 12→8, 兵数 12, 120g+8暗影精华
- 深海利维坦: ATK 18→11, DEF 15→10, 兵数 10, 100g+8暗影精华
- 暗影龙骑: ATK 22→13, DEF 10→7, 兵数 8, 130g+8暗影精华

**faction_data.gd — ALLIANCE_UNIT_DEFS (联军兵种)**
- 联军先锋: ATK 12→8, DEF 10→6, 兵数 7
- 奥术炮台: ATK 15→10, DEF 6→3, 兵数 6

**faction_data.gd — FACTION_AVAILABLE_UNITS**
- 兽人: grunt/troll/warg_rider → orc_ashigaru/orc_samurai/orc_cavalry
- 海盗: cutthroat/gunner/bombardier → pirate_ashigaru/pirate_archer/pirate_cannon
- 暗精灵: assassin/cold_lizard/warrior → de_ninja/de_cavalry/de_samurai

### 训练树对齐 16_训练系统.md

**费用体系重构**: 全部改为金币制（移除 iron/crystal/gunpowder/shadow 成本）

**回合数对齐**: T1=1回合, T2=2回合, T3=3回合（原: T1=2, T2=3, T3=4）

**兽人训练树** (9节点):
- O-1a 蛮力操练: 200g/1回合, 足軽ATK+15%
- O-1b 重甲锻造: 200g/1回合, 武士DEF+15%
- O-1c 战吼鼓舞: 250g/1回合, 士气上限+10
- O-1d 祭祀祈福: 200g/1回合, 祭司治疗+20%
- O-2a 狂暴突击: 400g/2回合, HP<50%→ATK+25%
- O-2b 战场嚎叫: 350g/2回合, 敌前排士气-5
- O-2c 血祭术: 400g/2回合, 術師消耗10%HP→伤害×1.8
- O-2d 铁壁方阵: 350g/2回合, 武士相邻减伤15%
- O-3 WAAAGH!怒吼: 800g/3回合, 全军ATK×1.5

**海盗训练树** (9节点):
- P-1a 精准射击: 200g/1回合, 弓兵ATK+15%
- P-1b 火药改良: 250g/1回合, 砲兵攻城+20%
- P-1c 轻骑突袭: 200g/1回合, 騎兵移动+1
- P-1d 暗杀训练: 200g/1回合, 忍者暴击+10%
- P-2a 齐射战术: 400g/2回合, 弓兵集火+30%
- P-2b 连环炮: 400g/2回合, 砲兵25%追加半伤
- P-2c 劫掠之风: 350g/2回合, 占领掠夺+50%
- P-2d 烟雾弹: 350g/2回合, 忍者列闪避+30%
- P-3 黑旗恐惧: 800g/3回合, 敌ATK-20%/DEF-10%+25%逃兵

**暗精灵训练树** (9节点):
- D-1a 暗影潜行: 200g/1回合, 忍者首回合不可选
- D-1b 月之祝福: 250g/1回合, 祭司护盾30%
- D-1c 黑魔研习: 200g/1回合, 術師伤害+15%
- D-1d 暗影行者训练: 300g/1回合, 解锁暗影行者
- D-2a 精神侵蚀: 400g/2回合, 術師DOT 8%×2回合
- D-2b 幽影分身: 400g/2回合, 暗影行者25%闪避
- D-2c 暗之治愈: 350g/2回合, 祭司20%净化
- D-2d 情报网络: 350g/2回合, 战前查看敌军编制
- D-3 暗影支配: 800g/3回合, 控制1敌+全军隐匿

### 招募系统修正

**recruit_manager.gd**:
- `udata["hp"]` → `_get_soldiers(udata)` (兼容新旧格式)
- `_calculate_recruit_cost()`: 支持 `recruit_gold`(显式) / `cost_mult`(公式) / `cost_gold`(回退) 三种定价
- 移除铁矿招募成本（文档仅定义金币制）
- `_get_tier_order()`: 更新为新兵种ID
- `_needs_strategic_resource()`: warg_rider/cold_lizard → orc_cavalry/de_cavalry
- `get_combat_units()`: 新增 spd/row/soldiers 输出字段
- 新增 `_get_soldiers()` 辅助函数

### game_manager.gd 修正

- 防御方默认单位: `militia` → `human_ashigaru` (ATK 4, DEF 6, fort_def_3)
- AI缩放: `unit["hp"]` → `unit["count"]`（按兵数缩放而非不存在的hp字段）

### combat_resolver.gd 修正

- 默认单位回退: `grunt` → `orc_ashigaru`
- TROOP_DEFAULT_ROW / `_get_troop_base_type()` 保留新旧ID双向映射（存档兼容）

### 文档更新

- `11_兵种数据包.md`: 新增实现文件引用和格式说明
- `16_训练系统.md`: 新增实现文件引用
- `design_reference.md`: 更新至 v1.1，扩充系统清单(21个系统)，新增 v1.1 变更记录

---

## v1.0.0 — 2026-03-22 (战斗系统重写 + 核心数值修正)

### 战斗系统重写

**combat_resolver.gd** — 完全重写 (~700行):
- 旧: 同时比较战力的简单系统
- 新: 战国兰斯式回合制战斗
  - 前排3槽位 + 后排2槽位，每侧最多5个部队
  - SPD降序行动队列，12回合上限
  - 伤害公式: `soldiers × max(1, ATK - DEF) / 10 × 技能倍率 × 地形修正`
  - 16种被动技能全部实现（regen_1/charge_1_5/escape_30/preemptive/preemptive_1_3/siege_x2/extra_action/assassinate_back/ignore_terrain/fort_def_3/counter_1_2/immobile/taunt/aoe_mana/charge_mana_1/aoe_1_5_cost5/death_burst）
  - 18种英雄主动技能实现（圣光斩/治愈之光/突击号令 等）
  - 城防/攻城、精灵屏障、地形修正、法力系统完整
  - 保留旧API兼容

### 威胁值系统修正

**threat_manager.gd**:
- 衰减: -1/回合 → -5/回合（对齐 03_战略设定.md）
- 占领节点: +5 → +10
- 新增: `on_hero_captured()` +20
- 新增: `on_hero_released()` -10
- 新增: `on_diplomacy_action()` -15
- 远征军: 概率制 → 间隔制(每3回合)
- Boss: 概率制 → 间隔制(每5回合)
- 新增: `check_dominance()` 控制≥50%节点时+5/回合
- 新增: `tick_timers()` 计时器系统

### WAAAGH! 系统修正

**orc_mechanic.gd + faction_data.gd**:
- 狂暴阈值: 50 → 80
- 狂暴伤害倍率: 2.0 → 1.5
- 内斗: ≤0时必触发 → ≤20时10%概率
- 新增: `waaagh_infighting_threshold: 20`, `waaagh_infighting_chance: 0.10`

### 奴隶系统补全

**slave_manager.gd** — 新增5个功能:
- `convert_slaves_to_soldiers()`: 3奴隶→1士兵
- `get_slave_capacity()`: 5×节点等级
- `is_at_capacity()`: 容量检测
- `get_labor_income()`: +0.5金/奴隶 + 铁/粮配置收入
- `check_revolt()`: 奴隶>驻军×3时10%暴动
- `tick_altar()`: 新增shadow_essence产出(1奴隶=2暗影精华)

### 英雄系统联动

**hero_system.gd**:
- `attempt_capture()`: 新增 `ThreatManager.on_hero_captured()` 调用
- `release_hero()`: 改用 `ThreatManager.on_hero_released()`

### 共享兵种数据重构

**faction_data.gd — SHARED_UNIT_DEFS**:
- 新格式: soldiers/spd/row/cost_mult/class（移除hp/cost_gold/cost_iron）
- 被动ID对齐文档（first_strike→preemptive, mana_aoe→aoe_mana 等）
- 新增 `RECRUIT_COST_MULT` 字典

### 起始资源对齐

**faction_data.gd — STARTING_RESOURCES**:
- 全阵营统一: 200金/100粮/50铁（原: 兽人150/20/10等不一致值）

### 海盗粮食产出修正

**faction_data.gd — FACTION_PARAMS**:
- 海盗 food_production_mult: 0.7 → 1.0（对齐 04_经济设定.md）

### game_manager.gd 回合循环扩展

- 英雄分配至攻击方部队（SPD/hero_id/hdata）
- 防御方兵种ID更新（对齐11_兵种数据包）
- 新增暗精灵奴隶机制（祭坛tick/暗影精华/劳工收入/暴动检测）
- 新增威胁计时器tick和支配检测
- 攻击方回退单位: grunt → orc_ashigaru

### 文档新增

- `05_行动设定.md`: 新增实现文件引用
- `design_reference.md`: 新增 §18 实现状态表
