# 任务链/事件系统深度开发报告 (v1.0)

> 项目：dark-tide-slg | 引擎：Godot 4.2.2 | 提交：`4d4b87e`

---

## 一、开发概览

本次开发在原有基础架构之上，对**任务链（Quest Chain）**与**事件系统（Event System）**进行了全面深度扩展，新增约 **3,641 行**代码，涉及 11 个文件（7 个新建，4 个扩展）。

| 维度 | 本次开发成果 |
|------|------------|
| 新增核心系统 | 3 个（QuestChainManager、ChainEventComposer、QuestChainData） |
| 扩展现有系统 | 4 个（EventBus、QuestJournal、QuestJournalPanel、project.godot） |
| 新增 UI 组件 | 2 个（QuestChainBranchDialog、ChainEventLogPanel） |
| 新增任务链数量 | 3 条（共 7 条） |
| 新增信号数量 | 13 个 |
| 代码总量 | 3,641 行（新增） |

---

## 二、核心系统详解

### 2.1 任务链管理器 `quest_chain_manager.gd`（576 行）

**图驱动状态机**是本次开发的核心。每条任务链被建模为**有向无环图（DAG）**，节点之间通过 `requires`/`next` 关系形成依赖链，由管理器统一驱动状态转换。

```
节点状态机:
LOCKED → AVAILABLE → ACTIVE → COMPLETED
                            ↘ FAILED
                            ↘ SKIPPED（互斥分支）
```

**关键能力：**

- **多分支选择（branch_choice）**：节点完成后弹出分支选择弹窗，玩家主动选择路线，互斥分支自动标记为 SKIPPED
- **并行子任务（parallel_group）**：同一 `parallel_group` 的节点同时激活，配合 `parallel_join` 门节点等待全部完成后才推进
- **限时任务（time_limit_turns）**：节点超时自动跳转到 `fail_node`，触发失败分支
- **全局标记（_global_flags）**：跨链共享的布尔标记，用于条件门控和后续链的触发判断
- **存档集成**：`save_data()` / `load_data()` 完整保存链状态、节点状态、分支选择历史、全局标记

### 2.2 事件组合器 `chain_event_composer.gd`（538 行）

在原有 EventSystem 的单事件触发基础上，新增**复合条件门控**和**连锁效果**能力。

**CompositeCondition（复合条件）：**

```gdscript
# AND 条件：所有子条件都满足才触发
composer.add_condition_listener("and_gate_1", {
    "type": "AND",
    "conditions": [
        {"type": "resource_min", "resource": "gold", "amount": 500},
        {"type": "flag_set", "flag": "rebellion_suppressed"},
    ]
}, callback_func)

# OR 条件：任意子条件满足即触发
composer.add_condition_listener("or_gate_1", {
    "type": "OR",
    "conditions": [
        {"type": "turn_reached", "turn": 10},
        {"type": "threat_min", "amount": 80},
    ]
}, callback_func)
```

**延迟触发（delay_turns）**：注册事件时指定延迟回合数，到达时自动触发，支持取消。

**连锁效果（chain_effects）**：一个事件触发后，自动按序触发一组后续效果（资源变化、标记设置、任务激活等），无需手动串联。

### 2.3 任务链数据定义 `quest_chain_data.gd`（920 行）

原有 4 条链基础上新增 3 条，覆盖所有节点类型和分支模式：

| 链 ID | 名称 | 类别 | 触发条件 | 分支模式 | 特色机制 |
|-------|------|------|---------|---------|---------|
| `epic_rebellion` | 史诗叛乱 | side_chain | 主线3完成 + 秩序<40 | 武力/外交 双分支 | 条件门（flag_set_any） |
| `shadow_elite` | 暗影精英 | character_chain | 暗影精华≥30 + 英雄≥2 | 强化/腐化 双分支 | 英雄成长影响 |
| `pirate_alliance` | 海盗同盟 | faction_chain | 海盗存活 + 声望≥50 | 结盟/征服 双分支 | 并行子任务（盟约+贡品） |
| `ancient_curse` | 古老诅咒 | crisis_chain | 威胁≥60 + 事件触发 | 仪式/神器 双分支 | 全链限时（10回合） |
| **`dark_tide_rising`** | **暗潮崛起** | faction_chain | 第5回合 | 征服/阴谋 双分支 | 终局解锁（unlock_endgame） |
| **`border_crisis`** | **边境危机** | crisis_chain | 威胁≥50 | 占领/谈判 双分支 | 限时备战 + 失败节点 |
| **`ancient_ruin`** | **古老遗迹** | side_chain | 领地≥4 | 无分支（并行汇合） | parallel_group + parallel_join |

---

## 三、系统扩展详解

### 3.1 EventBus 新增 13 个任务链信号

```gdscript
# 链生命周期
signal quest_chain_started(chain_id: String)
signal quest_chain_completed(chain_id: String)
signal quest_chain_failed(chain_id: String, reason: String)

# 节点状态
signal quest_chain_node_activated(chain_id: String, node_id: String)
signal quest_chain_node_completed(chain_id: String, node_id: String)

# 分支系统
signal quest_chain_branch_requested(chain_id: String, node_id: String, options: Array)
signal quest_chain_branch_chosen(chain_id: String, node_id: String, chosen_id: String)

# 奖励与标记
signal quest_chain_flag_set(flag_id: String, value: bool)
signal quest_chain_reward_granted(chain_id: String, reward: Dictionary)

# 事件组合器
signal chain_event_triggered(event_id: String, data: Dictionary)
signal chain_condition_met(condition_id: String)
signal chain_effect_applied(effect_type: String, data: Dictionary)
signal chain_log_updated(entry: Dictionary)
```

### 3.2 QuestJournal 链任务集成

新增 4 个公开方法，使链内嵌任务与标准任务系统无缝衔接：

```gdscript
func register_chain_quest(quest_id: String, chain_id: String) -> void
func is_chain_quest(quest_id: String) -> bool
func get_chain_quests_for_chain(chain_id: String) -> Array
func complete_chain_quest(quest_id: String) -> void  # 完成后自动通知 QuestChainManager
```

---

## 四、UI 系统详解

### 4.1 任务日志面板新增「任务链」Tab

在原有「进行中/已完成/主线/支线」Tab 基础上，新增**任务链 Tab**：

- **链卡片**：显示链名、类别标签（faction/crisis/character/side）、整体进度条
- **节点列表**：每个节点按状态着色
  - 🟢 绿色 = COMPLETED（已完成）
  - 🟡 黄色 = ACTIVE（进行中）
  - ⚪ 灰色 = LOCKED（未解锁）
  - 🔵 蓝色 = AVAILABLE（可激活）
  - 🔴 红色 = FAILED（已失败）
  - ⬛ 暗灰 = SKIPPED（已跳过）
- **实时刷新**：监听 `quest_chain_node_activated` / `quest_chain_node_completed` 信号自动更新

### 4.2 任务链分支选择弹窗 `quest_chain_branch_dialog.gd`（231 行）

- 监听 `EventBus.quest_chain_branch_requested` 信号自动弹出
- 支持最多 4 个分支选项，每项显示**选项名称 + 详细描述**
- 玩家选择后发射 `quest_chain_branch_chosen` 信号，由 QuestChainManager 处理互斥逻辑
- 弹窗关闭前禁止其他操作（模态）

### 4.3 事件链日志面板 `chain_event_log_panel.gd`（391 行）

- 实时记录所有链事件，每条日志包含：回合数、事件类型、链 ID、节点 ID、描述
- **按类型着色**：链启动（绿）/ 节点激活（黄）/ 分支选择（蓝）/ 完成（亮绿）/ 失败（红）/ 奖励（金）
- **按链 ID 过滤**：下拉菜单选择特定链，只显示该链的事件历史
- **最多保留 200 条**日志，超出自动清理最旧记录

---

## 五、数据流与集成架构

```
玩家操作 / 回合推进
        │
        ▼
QuestChainManager._on_turn_started()
        │
        ├─ 评估触发条件 → 激活新链 → EventBus.quest_chain_started
        │
        ├─ 检查活跃节点 → 超时判断 → 跳转 fail_node
        │
        └─ 检查节点完成 → 推进下一节点
                │
                ├─ 普通节点 → EventBus.quest_chain_node_activated
                │
                ├─ branch_choice → EventBus.quest_chain_branch_requested
                │       └─ QuestChainBranchDialog 弹出
                │               └─ 玩家选择 → EventBus.quest_chain_branch_chosen
                │                       └─ QuestChainManager._on_branch_chosen()
                │
                ├─ parallel_join → 等待 parallel_group 全部完成
                │
                └─ reward 节点 → EventBus.quest_chain_reward_granted
                        └─ 资源系统处理奖励

ChainEventComposer（独立监听）
        ├─ 条件监听器 → 满足时触发回调
        ├─ 延迟事件 → 到达回合时触发
        └─ 连锁效果 → 顺序执行效果列表

UI 层（信号驱动）
        ├─ QuestJournalPanel → 任务链 Tab 实时刷新
        ├─ QuestChainBranchDialog → 分支选择弹窗
        └─ ChainEventLogPanel → 事件历史日志
```

---

## 六、使用指南

### 6.1 定义新任务链

在 `quest_chain_data.gd` 的 `CHAINS` 字典中添加新条目：

```gdscript
"my_new_chain": {
    "name": "我的新任务链",
    "desc": "链的描述",
    "category": "side_chain",  # faction_chain / character_chain / crisis_chain / side_chain
    "trigger": {
        "turn_min": 10,         # 回合条件
        "gold_min": 300,        # 资源条件
        "flag_set": "some_flag", # 标记条件
    },
    "start_node": "node_a",
    "nodes": {
        "node_a": {
            "type": "event",    # event / quest / gate / reward
            "name": "节点名称",
            "event_id": "some_event_id",
            "requires": [],
            "next": ["node_b"],
        },
        "node_b": {
            "type": "quest",
            "quest_id": "chain_my_quest",
            "requires": ["node_a"],
            "next": ["node_c"],
        },
        # ... 更多节点
    },
}
```

### 6.2 触发分支选择

将节点的 `branch_choice` 设为 `true`，并在 `next` 中列出所有分支节点 ID：

```gdscript
"branch_node": {
    "type": "gate",
    "branch_choice": true,
    "requires": ["prev_node"],
    "next": ["branch_a", "branch_b"],
},
"branch_a": {
    "mutually_exclusive": ["branch_b"],  # 选择 a 时，b 自动 SKIPPED
    "requires": ["branch_node"],
    "next": ["end_node"],
},
```

### 6.3 使用并行任务

```gdscript
"parallel_task_1": {
    "parallel_group": "group_name",
    "requires": ["start_node"],
    "next": ["join_gate"],
},
"parallel_task_2": {
    "parallel_group": "group_name",
    "requires": ["start_node"],
    "next": ["join_gate"],
},
"join_gate": {
    "type": "gate",
    "gate_type": "parallel_join",
    "parallel_group": "group_name",
    "requires": ["parallel_task_1", "parallel_task_2"],  # 等待全部完成
    "next": ["next_node"],
},
```

---

## 七、提交信息

- **仓库**：https://github.com/magicy565-web/dark-tide-slg
- **提交哈希**：`4d4b87e`
- **分支**：`main`
- **变更规模**：11 files changed, 3,641 insertions(+), 1 deletion(-)
