# 任务链/事件系统全面检查与修复报告

**版本**: v5.2.0  
**提交**: `3cbd9f6`  
**检查范围**: 集成注册、完成奖励、前置条件、任务回合时限

---

## 一、检查范围与方法

本次检查覆盖以下 6 个核心文件：

| 文件 | 职责 |
|------|------|
| `systems/quest/quest_chain_manager.gd` | 任务链状态机、节点推进、时限管理 |
| `systems/quest/quest_journal.gd` | 任务注册、奖励发放、链任务集成 |
| `systems/quest/quest_progress_tracker.gd` | 每回合驱动 tick |
| `systems/event/chain_event_composer.gd` | 事件序列、延迟触发、条件门 |
| `autoloads/event_bus.gd` | 信号总线声明 |
| `autoloads/save_manager.gd` | 存档/读档集成 |

---

## 二、发现问题与修复详情

### 问题 1 — 缩进错误（严重，GDScript 解析失败）

**文件**: `quest_journal.gd`，第 1218–1348 行  
**现象**: 链任务集成函数段（`register_chain_quest`、`tick_chain_quests` 等）的函数体内所有代码行缺少 tab 缩进，GDScript 解析器会将这些行识别为顶层语句而非函数体，导致运行时错误。  
**修复**: 使用 Python 脚本对该段落进行批量 tab 缩进修复。

---

### 问题 2 — tick_chain_quests 未被调用（严重，链任务永远不自动完成）

**文件**: `quest_progress_tracker.gd`  
**现象**: `QuestJournal.tick_chain_quests()` 函数已定义，但 `QuestProgressTracker.tick_all()` 中没有调用它，导致链任务的目标完成检查从未执行。  
**修复**: 在 `tick_all()` 中添加：

```gdscript
QuestJournal.tick_chain_quests(player_id)
```

---

### 问题 3 — _apply_reward 缺少链专用奖励字段（奖励发放不完整）

**文件**: `quest_journal.gd`，`_apply_reward()` 函数  
**现象**: `CHAIN_QUESTS` 中定义了 `order_delta`、`threat_delta`、`flag_set`、`unlock_endgame`、`message` 等链专用奖励字段，但 `_apply_reward()` 完全没有处理这些字段，导致这些奖励静默丢失。  
**修复**: 在函数末尾补充以下处理逻辑：

```gdscript
if reward.has("order_delta") and OrderManager:
    OrderManager.change_order(int(reward["order_delta"]))
if reward.has("threat_delta") and ThreatManager:
    ThreatManager.change_threat(int(reward["threat_delta"]))
if reward.has("flag_set"):
    if ChainEventComposer:
        ChainEventComposer.set_flag(reward["flag_set"], true)
    EventBus.quest_chain_flag_set.emit(reward["flag_set"])
if reward.get("unlock_endgame", false):
    EventBus.quest_chain_endgame_unlocked.emit("quest_journal_reward")
var reward_msg: String = reward.get("message", "")
if reward_msg != "":
    EventBus.message_log.emit("[color=gold][任务奖励] %s[/color]" % reward_msg)
```

---

### 问题 4 — parallel_join gate 节点逻辑未实现（并行任务永远不汇合）

**文件**: `quest_chain_manager.gd`，`_check_node_completion()` 和 `_check_gate_condition()`  
**现象**: `quest_chain_data.gd` 中定义了 `gate_type: "parallel_join"` 的汇合节点（如古老遗迹链的 `ar_join_gate`），但 `_check_node_completion()` 的 gate 分支只调用了 `_check_gate_condition()`，完全没有处理 `gate_type` 字段，导致并行任务永远无法汇合推进。  
**修复**: 新增 `_check_parallel_join()` 函数，并在 gate 分支中根据 `gate_type` 分路处理：

```gdscript
var gate_type: String = node.get("gate_type", "condition")
if gate_type == "parallel_join":
    gate_passed = _check_parallel_join(chain_id, node_id)
else:
    var condition: Dictionary = node.get("condition", {})
    gate_passed = _check_gate_condition(condition, chain_id, player_id)
```

`_check_parallel_join()` 扫描同一 `parallel_group` 内的所有非门节点，要求全部处于 `COMPLETED` 或 `SKIPPED` 状态。

---

### 问题 5 — _check_gate_condition 缺少 turn_min/tiles_min/gold_min 条件键

**文件**: `quest_chain_manager.gd`，`_check_gate_condition()`  
**现象**: `_check_chain_trigger()` 中支持 `turn_min`、`tiles_min`、`gold_min` 等条件键，但 `_check_gate_condition()` 中没有这些键的处理，导致 gate 节点的时间/领地/资源条件无法生效。  
**修复**: 在 `_check_gate_condition()` 中补充三个条件键的原子评估。

---

### 问题 6 — time_limit_turns / fail_node 完全未实现（时限系统形同虚设）

**文件**: `quest_chain_manager.gd`  
**现象**: `quest_chain_data.gd` 中 `bc_prepare` 节点定义了 `time_limit_turns: 5, fail_node: "bc_fail"`，但 `_tick_chain()` 和 `_activate_node()` 中完全没有时限相关逻辑，节点激活时间从未记录，超时检查从未执行。  
**修复**:
1. 新增 `_node_activated_turns` 字典（`chain_id -> { node_id -> activated_turn }`）
2. `_activate_node()` 中记录激活回合
3. 新增 `_check_node_time_limit()` 函数，计算已用回合数，超时时调用 `_fail_node()` 并解锁 `fail_node` 分支
4. `_tick_chain()` 中先执行时限检查，再执行完成检查
5. `to_save_data()` / `from_save_data()` 同步保存/恢复激活回合数据

---

### 问题 7 — save_manager.gd 缺少链系统存档（读档后链状态丢失）

**文件**: `save_manager.gd`  
**现象**: `_collect_save_data()` 没有序列化 `QuestChainManager` 的状态（节点状态、分支选择、激活回合等）和 `QuestJournal._chain_quest_registry`，导致读档后所有任务链进度归零。  
**修复**:

```gdscript
# 存档
"quest_chain_manager": QuestChainManager.to_save_data() if QuestChainManager != null else {},
"quest_chain_registry": QuestJournal.chain_quest_save_data() if QuestJournal != null else {},

# 读档
if data.has("quest_chain_manager") and QuestChainManager != null:
    QuestChainManager.from_save_data(data.get("quest_chain_manager", {}))
if data.has("quest_chain_registry") and QuestJournal != null:
    QuestJournal.chain_quest_load_data(data.get("quest_chain_registry", {}))
```

---

### 问题 8 — EventBus 缺少 2 个信号声明（UI 面板运行时报错）

**文件**: `autoloads/event_bus.gd`  
**现象**: `quest_chain_panel.gd` 和 `chain_event_log_panel.gd` 中连接了 `quest_chain_node_activated` 和 `quest_chain_failed` 信号，但 `event_bus.gd` 中没有声明这两个信号，导致运行时 `connect()` 报错。  
**修复**: 补充两个信号声明：

```gdscript
signal quest_chain_failed(chain_id: String, reason: String)
signal quest_chain_node_activated(chain_id: String, node_id: String)
```

---

### 问题 9 — 事件序列 delay 步骤续接断链（序列在延迟后永远不继续）

**文件**: `systems/event/chain_event_composer.gd`，`_fire_delayed_event()`  
**现象**: `_execute_sequence_step()` 的 `delay` 分支通过 `schedule_event("__seq_{id}_continue", ...)` 调度一个续接事件，但 `_fire_delayed_event()` 在处理该事件时直接将其提交到 `EventScheduler`，而 `EventScheduler` 不认识这个内部事件 ID，导致序列在 delay 步骤后永远卡住。  
**修复**: 在 `_fire_delayed_event()` 中识别 `__seq_*_continue` 事件，直接调用 `_on_sequence_step_done()` 而非提交到 `EventScheduler`：

```gdscript
if event_id.begins_with("__seq_") and event_id.ends_with("_continue"):
    var sequence_id: String = data.get("sequence_id", "")
    if sequence_id == "":
        var prefix := "__seq_"
        var suffix := "_continue"
        sequence_id = event_id.substr(prefix.length(), event_id.length() - prefix.length() - suffix.length())
    if sequence_id != "" and _sequence_states.has(sequence_id):
        _on_sequence_step_done(sequence_id)
    return
```

---

## 三、修复总结

| # | 严重程度 | 文件 | 问题类型 | 状态 |
|---|----------|------|----------|------|
| 1 | 🔴 严重 | quest_journal.gd | 缩进错误/解析失败 | ✅ 已修复 |
| 2 | 🔴 严重 | quest_progress_tracker.gd | 集成缺失/tick 未调用 | ✅ 已修复 |
| 3 | 🟠 高 | quest_journal.gd | 奖励字段缺失 | ✅ 已修复 |
| 4 | 🟠 高 | quest_chain_manager.gd | parallel_join 未实现 | ✅ 已修复 |
| 5 | 🟡 中 | quest_chain_manager.gd | gate 条件键缺失 | ✅ 已修复 |
| 6 | 🔴 严重 | quest_chain_manager.gd | 时限系统未实现 | ✅ 已修复 |
| 7 | 🔴 严重 | save_manager.gd | 链系统存档缺失 | ✅ 已修复 |
| 8 | 🟠 高 | event_bus.gd | 信号声明缺失 | ✅ 已修复 |
| 9 | 🟠 高 | chain_event_composer.gd | 序列续接断链 | ✅ 已修复 |

**变更统计**: 6 个文件，+255 行，-117 行  
**提交 Hash**: `3cbd9f6`
