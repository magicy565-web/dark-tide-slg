# Dark Tide SLG 任务链与事件系统深度开发架构设计

## 1. 现状分析与痛点

目前 `dark-tide-slg` 项目的任务与事件系统已经具备了良好的基础：
- `quest_journal.gd` 和 `quest_progress_tracker.gd` 提供了任务状态的统一管理。
- `event_system.gd` 实现了基于权重的随机事件和简单的 `chain:parent_id` 延迟触发机制。
- `event_scheduler.gd` 提供了回合级别的事件调度。

**存在的痛点与局限性：**
1. **任务链缺乏图结构支持**：当前任务是线性的（如 `main_1` -> `main_2`），不支持多分支（Branching）、并行任务（Parallel Tasks）和条件门控（Conditional Gates）。
2. **事件链过于简单**：`event_system.gd` 中的链式事件仅支持单线延迟触发，无法实现复杂的“事件树”（如：选择A导致事件B，选择B导致事件C，且带有不同的前置条件和变量状态）。
3. **UI 表现力不足**：任务日志面板（`quest_journal_panel.gd`）仅能显示列表，无法直观展示任务链的拓扑结构和分支进度。
4. **状态机缺失**：缺乏统一的任务/事件状态机来处理复杂的生命周期（如：挂起、进行中、失败重试、分支锁定）。

## 2. 架构设计目标

本次深度开发旨在引入**图驱动（Graph-Driven）**的任务链与事件系统，实现以下目标：
- **多分支任务链（Quest Chain Graph）**：支持节点化的任务定义，包含前置节点（Prerequisites）、互斥分支（Mutually Exclusive Branches）和聚合节点（Join Nodes）。
- **复杂事件组合器（Event Composer）**：支持事件的条件组合（AND/OR）、变量标记（Flags）和多层级连锁反应。
- **可视化任务链 UI**：在任务日志中新增“任务链视图”，以节点图的形式展示玩家的进度和未解锁的分支。
- **无缝集成**：与现有的 `QuestJournal`、`EventSystem` 和 `EventBus` 深度融合，保持向后兼容。

## 3. 核心模块设计

### 3.1 任务链管理器 (`quest_chain_manager.gd`)
作为新的 Autoload 单例，负责解析和管理复杂的任务链图。
- **数据结构**：使用字典表示有向无环图（DAG）。每个节点代表一个任务或事件，边代表解锁条件。
- **核心功能**：
  - `load_chains()`: 加载任务链定义。
  - `evaluate_chain(chain_id)`: 评估链中各节点的状态。
  - `unlock_node(chain_id, node_id)`: 解锁特定节点。
  - `complete_node(chain_id, node_id)`: 完成节点并触发后续分支的评估。

### 3.2 事件组合器 (`chain_event_composer.gd`)
扩展现有的事件系统，支持复杂的事件逻辑。
- **条件门（Condition Gates）**：支持复杂的逻辑表达式（如 `(flag_A == true AND gold > 100) OR (reputation > 50)`）。
- **变量标记（Global Flags）**：引入全局和局部的事件标记，用于跨回合、跨事件的状态追踪。
- **连锁触发（Chain Triggers）**：支持即时连锁（Instant Chain）和延迟连锁（Delayed Chain）。

### 3.3 信号总线扩展 (`event_bus.gd`)
新增以下信号以支持任务链：
- `quest_chain_started(chain_id: String)`
- `quest_chain_node_unlocked(chain_id: String, node_id: String)`
- `quest_chain_node_completed(chain_id: String, node_id: String)`
- `quest_chain_branched(chain_id: String, chosen_branch: String)`
- `quest_chain_completed(chain_id: String)`

### 3.4 任务链 UI (`quest_chain_panel.gd`)
在现有的任务日志面板中新增一个 Tab，用于展示任务链。
- **节点绘制**：使用 `GraphEdit` 或自定义的 `Control` 节点绘制任务树。
- **状态可视化**：使用不同颜色区分节点状态（已完成：绿色，进行中：金色，未解锁：灰色，已锁定/互斥：暗红色）。

## 4. 数据结构定义示例

### 4.1 任务链定义 (`quest_chain_data.gd`)
```gdscript
const CHAINS = {
    "epic_rebellion": {
        "name": "史诗叛乱",
        "start_node": "rebellion_start",
        "nodes": {
            "rebellion_start": {
                "type": "event",
                "event_id": "rebellion_outbreak",
                "next": ["suppress_force", "negotiate_peace"]
            },
            "suppress_force": {
                "type": "quest",
                "quest_id": "defeat_rebel_army",
                "requires": ["rebellion_start"],
                "mutually_exclusive": ["negotiate_peace"],
                "next": ["military_victory"]
            },
            "negotiate_peace": {
                "type": "quest",
                "quest_id": "pay_rebel_ransom",
                "requires": ["rebellion_start"],
                "mutually_exclusive": ["suppress_force"],
                "next": ["diplomatic_victory"]
            }
        }
    }
}
```

## 5. 实施计划

1. **Phase 3**: 实现 `quest_chain_manager.gd` 和 `chain_event_composer.gd`，并扩展 `event_bus.gd`。
2. **Phase 4**: 开发 `quest_chain_panel.gd`，集成到现有的 UI 系统中。
3. **Phase 5**: 编写测试数据（如上述的“史诗叛乱”链），并在演示场景中验证逻辑和 UI 表现。
4. **Phase 6**: 代码审查、清理并提交到 GitHub。
