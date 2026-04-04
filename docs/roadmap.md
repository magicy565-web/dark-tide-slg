# 暗潮 SLG — 完整开发路线图

> 生成时间：2026-04-04  
> 基于全项目代码扫描（~150 个 GDScript 文件，约 80,000 行代码）

---

## 一、项目现状总结

| 系统 | 完成度 | 说明 |
|------|--------|------|
| 核心战斗（CombatSystem） | ✅ 95% | 战斗解算、阵型、反制矩阵、英雄技能均已完成 |
| 地图与格子系统 | ✅ 90% | 地图生成、邻接、地形、占领均完整 |
| 资源经济系统 | ✅ 90% | 金币/食物/铁矿/奴隶/战略资源均已完成 |
| 英雄系统 | ✅ 85% | 招募、升级、好感度、隐藏英雄均已完成 |
| 任务日志 | ✅ 80% | 主线/支线/挑战/角色任务均已完成 |
| 海盗阵营机制 | ✅ 85% | 恶名/朗姆酒/走私/藏宝图/黑市均已完成 |
| **海盗引导任务链** | ✅ 新增 | pirate_g1~g10 + PirateOnboarding（本次开发） |
| 故事/剧情系统 | ✅ 85% | 17 位英雄故事数据，共 370+ 个事件 |
| AI 系统 | ✅ 80% | 邪恶/光明/中立/联盟 AI 均已完成 |
| 外交系统 | ✅ 80% | 条约、和平谈判、提案系统均已完成 |
| 科技树 | ✅ 85% | 人类/兽人/海盗/暗精灵四阵营均有数据 |
| 攻城战系统 | ✅ 85% | 围城/强攻/城墙破坏均已完成 |
| 存档/读档 | ✅ 90% | 含版本迁移，引导状态已纳入 |
| NG+ 系统 | ✅ 85% | 等级/加成/英雄好感度继承均已完成 |
| 任务日志 UI（guide tab） | ⚠️ 缺失 | 未添加"引导任务"标签页 |
| test_realworld.gd | ❌ 语法错误 | 协程调用方式错误，阻断测试加载 |

---

## 二、当前已知 Bug 清单（按优先级）

### 🔴 P0 — 阻断游戏运行

| # | 位置 | 问题 | 修复方案 |
|---|------|------|----------|
| B1 | `tests/test_realworld.gd` | 直接调用协程 `resolve_battle()` 未加 `await`，导致解析失败，阻断 test_attack_bugs.gd 加载 | 重写 test_realworld.gd，移除协程调用 |

### 🟠 P1 — 功能缺失

| # | 位置 | 问题 | 修复方案 |
|---|------|------|----------|
| B2 | `scenes/ui/panels/quest_journal_panel.gd` | 任务日志面板没有"引导任务"标签页，pirate_g1~g10 无法在 UI 中显示 | 添加 "guide" tab，映射 category="guide" 的任务 |
| B3 | `systems/faction/training_data.gd` | 注释标注 `# PLACEHOLDER: PIRATE and DARK_ELF follow`，但实际数据已存在（可能是注释未更新） | 确认数据完整性，删除过时注释 |
| B4 | `autoloads/game_data.gd` | wanderer/rebel 模板为 PLACEHOLDER，随机事件中的流浪者和叛军无兵力数据 | 补充真实兵力模板数据 |

### 🟡 P2 — 潜在运行时 Bug

| # | 位置 | 问题 | 修复方案 |
|---|------|------|----------|
| B5 | `scenes/ui/combat/combat_view.gd:4748` | `from_save_data()` 函数体为空（pass），战斗视图状态不持久化 | 实现 from_save_data 逻辑 |
| B6 | `scenes/ui/overlays/supply_overlay.gd:228` | `_on_depot_built()` 为空，补给站建造后 UI 不更新 | 连接信号并刷新 UI |
| B7 | `systems/faction/dark_elf_mechanic.gd` | `_ready()` 为空，暗精灵阵营特有机制可能未初始化 | 检查并实现初始化逻辑 |
| B8 | `autoloads/game_manager.gd` | `open_domestic_panel()` 只打印日志，未真正打开内政面板 | 连接到 PanelManager |
| B9 | `autoloads/game_manager.gd` | `open_research_panel()` 只打印日志，未真正打开科技树面板 | 连接到 PanelManager |

### 🟢 P3 — 轻微问题

| # | 位置 | 问题 | 修复方案 |
|---|------|------|----------|
| B10 | `systems/faction/training_data.gd:27` | 过时的 PLACEHOLDER 注释 | 删除注释 |
| B11 | `systems/story/story_event_system.gd` | `record_event` 中 `GameManager.current_turn` 可能不存在 | 改用 `GameManager.get_current_turn()` |
| B12 | `tests/test_realworld.gd` | `GUIDE_QUESTS` 通过 `preload` 的脚本类访问，需要 `new()` 实例化 | 已在 test_attack_bugs.gd 中修正 |

---

## 三、开发路线图（按阶段）

### 阶段 1：修复阻断性问题（1-2天）⭐ 立即执行

**目标：让测试套件完整运行，所有测试通过**

- [ ] **B1** 重写 `test_realworld.gd`（移除协程调用，改为源码分析）
- [ ] 验证 `test_attack_bugs.gd` 全部通过（目标：150+ 测试通过）
- [ ] 删除 `test_attack_bug_scene.gd`（依赖图形环境，无法在无头模式运行）

---

### 阶段 2：引导任务 UI 集成（1-2天）

**目标：玩家能在任务日志中看到并追踪海盗引导任务**

- [ ] **B2** 在 `quest_journal_panel.gd` 中添加"引导任务"标签页
  - 新增 `btn_tab_guide` 按钮
  - `category_map` 中添加 `"guide": "guide"`
  - `_current_tab` 初始值改为 `"guide"`（海盗阵营首次进入时）
- [ ] 验证 pirate_g1~g10 在任务日志中正确显示进度

---

### 阶段 3：数据完整性修复（1-2天）

**目标：消除所有 PLACEHOLDER 数据，确保游戏内容完整**

- [ ] **B3** 清理 `training_data.gd` 的过时注释
- [ ] **B4** 补充 `game_data.gd` 中 wanderer/rebel 的真实兵力模板
  - wanderer：50-150 兵，中等 ATK/DEF
  - rebel：80-200 兵，低 ATK 高 DEF（防守型）

---

### 阶段 4：UI 功能连接（2-3天）

**目标：所有面板按钮能正确打开对应面板**

- [ ] **B8** `open_domestic_panel()` → 连接到 `PanelManager.open_panel("nation")`
- [ ] **B9** `open_research_panel()` → 连接到 `PanelManager.open_panel("tech_tree")`
- [ ] **B6** `supply_overlay._on_depot_built()` → 刷新补给站 UI
- [ ] **B5** `combat_view.from_save_data()` → 实现战斗视图状态恢复

---

### 阶段 5：暗精灵阵营完善（2-3天）

**目标：暗精灵阵营能正常游玩**

- [ ] **B7** `dark_elf_mechanic._ready()` → 实现初始化（参考 pirate_mechanic 结构）
- [ ] 验证暗精灵科技树（`training_data.gd` 第170行后）数据完整
- [ ] 添加暗精灵阵营引导任务链（参考 pirate_quest_guide.gd 结构）

---

### 阶段 6：端到端游戏流程验证（3-5天）

**目标：完整游玩一局游戏（海盗阵营），无崩溃**

- [ ] 主菜单 → 选择海盗阵营 → 开始游戏
- [ ] 回合 1：攻击相邻格子，验证战斗流程
- [ ] 回合 2-5：引导任务链推进（pirate_g1 → pirate_g5）
- [ ] 中期：走私航线、黑市、藏宝图功能验证
- [ ] 后期：恶名系统、雇佣兵、英雄解锁验证
- [ ] 胜利条件触发：攻占所有光明联盟要塞
- [ ] 存档/读档：验证引导进度正确恢复
- [ ] NG+：验证好感度继承和 AI 强化

---

### 阶段 7：稳定性加固（2-3天）

**目标：消除所有已知边界条件 Bug**

- [ ] 零兵力军队不崩溃（已有保护，验证即可）
- [ ] 空守方格子直接获胜（已有保护，验证即可）
- [ ] 超时战斗守方获胜（已有保护，验证即可）
- [ ] 存档版本迁移（v3→v4→v4.1）正确运行
- [ ] 所有 Autoload null 检查完整

---

## 四、各系统完成度详细评估

### 战斗系统（CombatSystem）— 95% 完成

```
✅ resolve_battle（协程，含玩家干预）
✅ 阵型检测（FormationSystem）
✅ 反制矩阵（CounterMatrix）
✅ 英雄技能（HeroSkillsAdvanced）
✅ 地形加成（6种地形）
✅ 攻城战（SiegeSystem）
✅ 多路合战（MultiRouteBattle）
✅ 战斗日志（action_log）
⚠️ 战斗视图 from_save_data 为空（B5）
```

### 海盗阵营 — 85% 完成

```
✅ 恶名系统（infamy 0-100）
✅ 朗姆酒士气（rum_morale）
✅ 走私航线（smuggle_routes）
✅ 藏宝图（treasure_maps）
✅ 黑市（black_market）
✅ 雇佣兵（mercenaries）
✅ 海盗引导弹窗（PirateOnboarding，11步）
✅ 海盗引导任务链（pirate_g1~g10）
⚠️ 引导任务 UI 标签页缺失（B2）
```

### 任务系统 — 80% 完成

```
✅ 主线任务（quest_definitions.gd）
✅ 支线任务（side_quest_data.gd）
✅ 挑战任务链（challenge_quest_data.gd）
✅ 角色任务（character quests）
✅ 海盗引导任务（pirate_quest_guide.gd，新增）
✅ QuestJournal（tick/trigger/objective评估）
✅ QuestProgressTracker
⚠️ 任务日志 UI 缺少 guide 标签页（B2）
```

### AI 系统 — 80% 完成

```
✅ 邪恶阵营 AI（evil_faction_ai.gd，567行）
✅ 光明联盟 AI（light_faction_ai.gd，551行）
✅ 中立势力 AI（neutral_faction_ai.gd，465行）
✅ 联盟 AI（alliance_ai.gd，514行）
✅ 战略规划器（ai_strategic_planner.gd，1652行）
⚠️ AI 难度曲线需要游戏测试验证
```

---

## 五、推荐立即执行的任务（本次 PR）

按优先级排序：

1. **修复 test_realworld.gd**（30分钟）— 解除测试阻断
2. **添加 quest_journal_panel guide 标签页**（1小时）— 让引导任务可见
3. **补充 wanderer/rebel 兵力模板**（30分钟）— 消除 PLACEHOLDER
4. **连接 open_domestic_panel / open_research_panel**（1小时）— 修复 UI 断链

---

*文档由自动化代码扫描生成，如有遗漏请手动补充。*
