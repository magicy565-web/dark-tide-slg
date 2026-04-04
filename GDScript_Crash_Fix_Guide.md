# Dark Tide SLG — GDScript 崩溃点扫描与修复指南

**扫描日期**：2026-04-04  
**引擎版本**：Godot 4.2  
**扫描范围**：全量 195 个 `.gd` 文件  
**扫描工具**：静态语法分析 + `gdparse 4.5.0` 语法树解析  
**文档用途**：标注每个文件的扫描状态，方便团队接力开发

---

## 一、总体概览

经系统级全量扫描，项目整体代码质量良好，绝大多数文件通过静态分析。以下是汇总数据：

| 分类 | 文件数 | 占比 | 说明 |
| :--- | ---: | ---: | :--- |
| ✅ 已完成（无问题） | 191 | 97.9% | 无严重语法错误或高危崩溃点 |
| 🔴 待修复（P0 严重错误） | 2 | 1.0% | 存在会导致脚本解析失败的语法错误，**必须修复** |
| 🟡 待审查（P1 潜在风险） | 2 | 1.0% | 存在潜在空指针访问风险，建议加固 |

> **关于 `gdparse` 工具兼容性说明**：`gdparse 4.5.0` 对 `connect(func(): call())` 形式的内联 Lambda 语法存在已知解析 Bug，会报 `Unexpected token RPAR` 错误。经核实，**Godot 4.2 引擎本身完全支持该语法**，属于工具误报，不影响实际运行。涉及文件已在本文档中标注为 `[已完成 — gdparse 工具兼容性]`。

---

## 二、P0 严重错误 — 必须修复（未完成）

以下 2 个文件存在真实语法错误，会导致 Godot 引擎在加载脚本时直接报错崩溃，**接力开发时须优先处理**。

---

### `systems/faction/ai_factions/ai_faction_elf.gd`

**错误类型**：`super._init()` 缩进缺失，位于函数体外部

**问题代码（第 9–11 行）**：

```gdscript
func _init() -> void:
## FactionConfig.FactionType.HIGH_ELF = 4
super._init(4, "elf_ai")   # ← 缺少 Tab 缩进，不在函数体内
```

**修复方案**：在第 11 行的 `super._init(...)` 前添加一个 Tab 缩进，使其正确包含在 `_init` 函数体内。同时，第 10 行的注释也应移入函数体：

```gdscript
func _init() -> void:
	## FactionConfig.FactionType.HIGH_ELF = 4
	super._init(4, "elf_ai")
```

**参考**：同目录下 `ai_faction_human.gd` 第 7–8 行为正确写法。

---

### `systems/faction/ai_factions/human_kingdom_events.gd`

**错误类型**：字符串内含未转义双引号 & 对话文本引号格式错误（共 14 处）

该文件中大量对话文本使用了中文全角引号或在双引号字符串内嵌套了未转义的双引号，导致 GDScript 解析器将字符串提前截断，后续内容被错误地解析为标识符，引发崩溃。

| 行号 | 错误类型 | 修复方案 |
| ---: | :--- | :--- |
| L107 | 字符串内含未转义 `"` | 将 `以"王都无权干涉领地内政"为由` 改为 `以\"王都无权干涉领地内政\"为由` |
| L109 | 对话引号格式错误 | 将 `emit(""您的势力...` 改为 `emit('"您的势力...')` |
| L169 | 对话引号格式错误 | 同上，改用单引号包裹含双引号的对话文本 |
| L236 | 对话引号格式错误 | 同上 |
| L239 | 对话引号格式错误 | 同上 |
| L289 | 对话引号格式错误 | 同上 |
| L291 | 对话引号格式错误 | 同上 |
| L353 | 对话引号格式错误 | 同上 |
| L355 | 对话引号格式错误 | 同上 |
| L357 | 对话引号格式错误 | 同上 |
| L399 | 对话引号格式错误 | 同上 |
| L402 | 对话引号格式错误 | 同上 |
| L425 | 对话引号格式错误 | 同上 |
| L428 | 对话引号格式错误 | 同上 |

**修复示例**：

```gdscript
# ❌ 错误写法（会崩溃）
EventBus.message_log.emit(""您的势力已引起了我的注意。我是个务实的人——")

# ✅ 正确写法（单引号包裹含双引号的字符串）
EventBus.message_log.emit('"您的势力已引起了我的注意。我是个务实的人——')
```

---

## 三、P1 潜在风险 — 建议审查（未完成）

以下 2 个文件存在潜在的空指针访问风险。当前逻辑下因有前置条件判断而不会必然触发，但在节点动态销毁或场景切换的边界情况下存在崩溃可能，建议在接力开发时加固。

---

### `autoloads/game_manager.gd`

**风险类型**：`get_node()` 无 null 检查（4 处，第 2227、2229、2231、2233 行）

**问题代码**：

```gdscript
if _sys_root.has_node("WeatherSystem"):
    _sys_root.get_node("WeatherSystem").advance_turn()   # L2227
if _sys_root.has_node("SupplySystem"):
    _sys_root.get_node("SupplySystem").process_turn(pid) # L2229
```

**风险说明**：`has_node()` 与 `get_node()` 之间存在极小的时间窗口，在多帧异步场景下节点可能已被释放。

**建议修复**：

```gdscript
var weather := _sys_root.get_node_or_null("WeatherSystem")
if weather:
    weather.advance_turn()
```

---

### `scenes/ui/overlays/intel_overlay.gd`

**风险类型**：链式 `get_node()` 调用无 null 检查（第 110 行）

**问题代码**：

```gdscript
elif has_node("/root/GameManager") and get_node("/root/GameManager").has_node("EspionageSystem"):
    _espionage_system = get_node("/root/GameManager").get_node("EspionageSystem")  # L110
```

**建议修复**：

```gdscript
elif has_node("/root/GameManager"):
    var gm := get_node_or_null("/root/GameManager")
    if gm and gm.has_node("EspionageSystem"):
        _espionage_system = gm.get_node("EspionageSystem")
```

---

## 四、全量文件扫描状态清单

以下为全部 195 个 `.gd` 文件的逐一扫描状态，按模块分组。

**状态图例**：
- ✅ `[已完成]` — 已扫描，无严重问题
- 🔴 `[未完成 — P0]` — 存在严重语法错误，必须修复
- 🟡 `[未完成 — P1]` — 存在潜在风险，建议审查
- ⚠️ `[已完成 — gdparse 工具兼容性]` — gdparse 工具误报，Godot 4.2 引擎正常

---

### 模块：`autoloads/`（全局单例，11 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `autoloads/asset_loader.gd` | ✅ 已完成 | — |
| `autoloads/audio_manager.gd` | ✅ 已完成 | — |
| `autoloads/cg_manager.gd` | ✅ 已完成 | — |
| `autoloads/color_theme.gd` | ✅ 已完成 | — |
| `autoloads/event_bus.gd` | ✅ 已完成 | — |
| `autoloads/game_data.gd` | ✅ 已完成 | — |
| `autoloads/game_manager.gd` | 🟡 未完成 — P1 | L2227/2229/2231/2233：`get_node()` 建议改为 `get_node_or_null()` |
| `autoloads/panel_manager.gd` | ✅ 已完成 | — |
| `autoloads/save_manager.gd` | ✅ 已完成 | — |
| `autoloads/ui_layer_registry.gd` | ✅ 已完成 | — |
| `autoloads/ui_theme_manager.gd` | ✅ 已完成 | — |

---

### 模块：`scenes/board/`（棋盘，1 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `scenes/board/board.gd` | ✅ 已完成 | — |

---

### 模块：`scenes/`（主场景，1 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `scenes/main.gd` | ✅ 已完成 | — |

---

### 模块：`scenes/ui/combat/`（战斗 UI，5 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `scenes/ui/combat/battle_prep_panel.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | L205/206/207：内联 Lambda，gdparse 误报，Godot 4.2 正常 |
| `scenes/ui/combat/combat_intervention_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/combat/combat_popup.gd` | ✅ 已完成 | — |
| `scenes/ui/combat/combat_view.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | 多处内联 Lambda，gdparse 误报，Godot 4.2 正常 |
| `scenes/ui/combat/formation_preview.gd` | ✅ 已完成 | — |
| `scenes/ui/combat/multi_route_panel.gd` | ✅ 已完成 | — |

---

### 模块：`scenes/ui/dialog/`（对话 UI，4 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `scenes/ui/dialog/event_manager_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/dialog/event_popup.gd` | ✅ 已完成 | — |
| `scenes/ui/dialog/mission_panel.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | L343：内联 Lambda，gdparse 误报，Godot 4.2 正常 |
| `scenes/ui/dialog/story_dialog.gd` | ✅ 已完成 | — |

---

### 模块：`scenes/ui/overlays/`（覆盖层 UI，8 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `scenes/ui/overlays/action_visualizer.gd` | ✅ 已完成 | — |
| `scenes/ui/overlays/ai_indicator.gd` | ✅ 已完成 | — |
| `scenes/ui/overlays/hud.gd` | ✅ 已完成 | — |
| `scenes/ui/overlays/intel_overlay.gd` | 🟡 未完成 — P1 | L110：链式 `get_node()` 建议改为 `get_node_or_null()` |
| `scenes/ui/overlays/notification_bar.gd` | ✅ 已完成 | — |
| `scenes/ui/overlays/quest_tracker.gd` | ✅ 已完成 | — |
| `scenes/ui/overlays/supply_overlay.gd` | ✅ 已完成 | — |
| `scenes/ui/overlays/tile_indicator_system.gd` | ✅ 已完成 | — |
| `scenes/ui/overlays/weather_hud.gd` | ✅ 已完成 | — |

---

### 模块：`scenes/ui/panels/`（面板 UI，14 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `scenes/ui/panels/army_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/panels/diplomacy_panel.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | L173/200：内联 Lambda，gdparse 误报，Godot 4.2 正常 |
| `scenes/ui/panels/equipment_forge_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/panels/espionage_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/panels/hero_detail_panel.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | L626：内联 Lambda，gdparse 误报，Godot 4.2 正常 |
| `scenes/ui/panels/hero_panel.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | L825：内联 Lambda，gdparse 误报，Godot 4.2 正常 |
| `scenes/ui/panels/inventory_panel.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | L106/109/112/115/118：内联 Lambda，gdparse 误报，Godot 4.2 正常 |
| `scenes/ui/panels/nation_panel.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | L35/36/38：内联 Lambda，gdparse 误报，Godot 4.2 正常 |
| `scenes/ui/panels/pirate_panel.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | L60–65：内联 Lambda，gdparse 误报，Godot 4.2 正常 |
| `scenes/ui/panels/province_info_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/panels/quest_journal_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/panels/tech_tree_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/panels/territory_info_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/panels/tile_development_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/panels/troop_training_panel.gd` | ✅ 已完成 | — |

---

### 模块：`scenes/ui/system/`（系统 UI，5 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `scenes/ui/system/cg_gallery_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/system/debug_console.gd` | ✅ 已完成 | — |
| `scenes/ui/system/game_over_panel.gd` | ✅ 已完成 | — |
| `scenes/ui/system/main_menu.gd` | ✅ 已完成 | — |
| `scenes/ui/system/save_load_panel.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | L57：内联 Lambda，gdparse 误报，Godot 4.2 正常 |
| `scenes/ui/system/settings_panel.gd` | ✅ 已完成 | — |

---

### 模块：`systems/balance/`（平衡配置，1 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/balance/balance_config.gd` | ✅ 已完成 | — |

---

### 模块：`systems/building/`（建筑系统，2 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/building/building_registry.gd` | ✅ 已完成 | — |
| `systems/building/research_manager.gd` | ✅ 已完成 | — |

---

### 模块：`systems/combat/`（战斗系统，18 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/combat/battle_cutin.gd` | ✅ 已完成 | — |
| `systems/combat/battle_sprite_animator.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | L459：内联 Lambda，gdparse 误报，Godot 4.2 正常 |
| `systems/combat/battle_vfx_controller.gd` | ✅ 已完成 | — |
| `systems/combat/chibi_sprite_loader.gd` | ✅ 已完成 | — |
| `systems/combat/combat_abilities.gd` | ✅ 已完成 | — |
| `systems/combat/combat_resolver.gd` | ✅ 已完成 | — |
| `systems/combat/combat_system.gd` | ✅ 已完成 | — |
| `systems/combat/commander_intervention.gd` | ✅ 已完成 | — |
| `systems/combat/counter_matrix.gd` | ✅ 已完成 | — |
| `systems/combat/environment_system.gd` | ✅ 已完成 | — |
| `systems/combat/formation_system.gd` | ✅ 已完成 | — |
| `systems/combat/light_sprite_loader.gd` | ✅ 已完成 | — |
| `systems/combat/multi_route_battle.gd` | ✅ 已完成 | — |
| `systems/combat/recruit_manager.gd` | ✅ 已完成 | — |
| `systems/combat/skill_animation_data.gd` | ✅ 已完成 | — |
| `systems/combat/supply_system.gd` | ✅ 已完成 | — |
| `systems/combat/troop_registry.gd` | ✅ 已完成 | — |
| `systems/combat/vfx_loader.gd` | ✅ 已完成 | — |

---

### 模块：`systems/economy/`（经济系统，9 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/economy/buff_manager.gd` | ✅ 已完成 | — |
| `systems/economy/item_manager.gd` | ✅ 已完成 | — |
| `systems/economy/prestige_shop.gd` | ✅ 已完成 | — |
| `systems/economy/production_calculator.gd` | ✅ 已完成 | — |
| `systems/economy/relic_manager.gd` | ✅ 已完成 | — |
| `systems/economy/resource_manager.gd` | ✅ 已完成 | — |
| `systems/economy/slave_manager.gd` | ✅ 已完成 | — |
| `systems/economy/strategic_resource_manager.gd` | ✅ 已完成 | — |
| `systems/economy/tile_development.gd` | ✅ 已完成 | — |

---

### 模块：`systems/event/`（事件系统，12 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/event/character_interaction_events.gd` | ✅ 已完成 | — |
| `systems/event/crisis_countdown.gd` | ✅ 已完成 | — |
| `systems/event/dynamic_situation_events.gd` | ✅ 已完成 | — |
| `systems/event/effect_resolver.gd` | ✅ 已完成 | — |
| `systems/event/event_registry.gd` | ✅ 已完成 | — |
| `systems/event/event_scheduler.gd` | ✅ 已完成 | — |
| `systems/event/event_system.gd` | ✅ 已完成 | — |
| `systems/event/expanded_random_events.gd` | ✅ 已完成 | — |
| `systems/event/extra_events_v5.gd` | ✅ 已完成 | — |
| `systems/event/faction_destruction_events.gd` | ✅ 已完成 | — |
| `systems/event/grand_event_director.gd` | ✅ 已完成 | — |
| `systems/event/seasonal_events.gd` | ✅ 已完成 | — |

---

### 模块：`systems/faction/`（势力系统，20 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/faction/ai_factions/ai_faction_base.gd` | ✅ 已完成 | — |
| `systems/faction/ai_factions/ai_faction_dark_elf.gd` | ✅ 已完成 | — |
| `systems/faction/ai_factions/ai_faction_elf.gd` | 🔴 **未完成 — P0** | **L11：super._init() 缩进缺失，必须修复** |
| `systems/faction/ai_factions/ai_faction_human.gd` | ✅ 已完成 | — |
| `systems/faction/ai_factions/ai_faction_orc.gd` | ✅ 已完成 | — |
| `systems/faction/ai_factions/ai_faction_pirate.gd` | ✅ 已完成 | — |
| `systems/faction/ai_factions/human_kingdom_ai.gd` | ✅ 已完成 | — |
| `systems/faction/ai_factions/human_kingdom_events.gd` | 🔴 **未完成 — P0** | **L107/109/169/236/239/289/291/353/355/357/399/402/425/428：字符串引号错误，必须修复** |
| `systems/faction/ai_scaling.gd` | ✅ 已完成 | — |
| `systems/faction/ai_strategic_planner.gd` | ✅ 已完成 | — |
| `systems/faction/alliance_ai.gd` | ✅ 已完成 | — |
| `systems/faction/dark_elf_mechanic.gd` | ✅ 已完成 | — |
| `systems/faction/diplomacy_manager.gd` | ✅ 已完成 | — |
| `systems/faction/espionage_system.gd` | ✅ 已完成 | — |
| `systems/faction/evil_faction_ai.gd` | ✅ 已完成 | — |
| `systems/faction/faction_config.gd` | ✅ 已完成 | — |
| `systems/faction/faction_data.gd` | ✅ 已完成 | — |
| `systems/faction/faction_manager.gd` | ✅ 已完成 | — |
| `systems/faction/light_faction_ai.gd` | ✅ 已完成 | — |
| `systems/faction/neutral_faction_ai.gd` | ✅ 已完成 | — |
| `systems/faction/orc_mechanic.gd` | ✅ 已完成 | — |
| `systems/faction/pirate_mechanic.gd` | ✅ 已完成 | — |
| `systems/faction/training_data.gd` | ✅ 已完成 | — |
| `systems/faction/treaty_system.gd` | ✅ 已完成 | — |

---

### 模块：`systems/general/`（通用系统，1 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/general/general_system.gd` | ✅ 已完成 | — |

---

### 模块：`systems/hero/`（英雄系统，6 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/hero/enchantment_system.gd` | ✅ 已完成 | — |
| `systems/hero/equipment_forge.gd` | ✅ 已完成 | — |
| `systems/hero/hero_level_data.gd` | ✅ 已完成 | — |
| `systems/hero/hero_leveling.gd` | ✅ 已完成 | — |
| `systems/hero/hero_skills_advanced.gd` | ✅ 已完成 | — |
| `systems/hero/hero_system.gd` | ✅ 已完成 | — |

---

### 模块：`systems/map/`（地图系统，6 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/map/fixed_map_data.gd` | ✅ 已完成 | — |
| `systems/map/location_presets.gd` | ✅ 已完成 | — |
| `systems/map/map_generator.gd` | ✅ 已完成 | — |
| `systems/map/nation_system.gd` | ✅ 已完成 | — |
| `systems/map/territory_effects.gd` | ✅ 已完成 | — |
| `systems/map/territory_type_system.gd` | ✅ 已完成 | — |

---

### 模块：`systems/march/`（行军系统，1 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/march/march_system.gd` | ✅ 已完成 | — |

---

### 模块：`systems/mod/`（模组系统，1 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/mod/mod_manager.gd` | ✅ 已完成 | — |

---

### 模块：`systems/ngplus/`（NG+ 系统，2 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/ngplus/ngplus_manager.gd` | ✅ 已完成 | — |
| `systems/ngplus/ngplus_shop.gd` | ✅ 已完成 | — |

---

### 模块：`systems/npc/`（NPC 系统，2 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/npc/npc_manager.gd` | ✅ 已完成 | — |
| `systems/npc/quest_manager.gd` | ✅ 已完成 | — |

---

### 模块：`systems/quest/`（任务系统，6 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/quest/challenge_quest_data.gd` | ✅ 已完成 | — |
| `systems/quest/pirate_quest_guide.gd` | ✅ 已完成 | — |
| `systems/quest/quest_definitions.gd` | ✅ 已完成 | — |
| `systems/quest/quest_journal.gd` | ✅ 已完成 | — |
| `systems/quest/quest_progress_tracker.gd` | ✅ 已完成 | — |
| `systems/quest/side_quest_data.gd` | ✅ 已完成 | — |

---

### 模块：`systems/story/`（故事系统，20 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/story/data/akane_story.gd` | ✅ 已完成 | — |
| `systems/story/data/epilogue_events.gd` | ✅ 已完成 | — |
| `systems/story/data/gekka_story.gd` | ✅ 已完成 | — |
| `systems/story/data/hakagure_story.gd` | ✅ 已完成 | — |
| `systems/story/data/hanabi_story.gd` | ✅ 已完成 | — |
| `systems/story/data/hibiki_story.gd` | ✅ 已完成 | — |
| `systems/story/data/homura_story.gd` | ✅ 已完成 | — |
| `systems/story/data/hyouka_story.gd` | ✅ 已完成 | — |
| `systems/story/data/kaede_story.gd` | ✅ 已完成 | — |
| `systems/story/data/mei_story.gd` | ✅ 已完成 | — |
| `systems/story/data/momiji_story.gd` | ✅ 已完成 | — |
| `systems/story/data/rin_story.gd` | ✅ 已完成 | — |
| `systems/story/data/sara_story.gd` | ✅ 已完成 | — |
| `systems/story/data/shion_story.gd` | ✅ 已完成 | — |
| `systems/story/data/sou_story.gd` | ✅ 已完成 | — |
| `systems/story/data/suirei_story.gd` | ✅ 已完成 | — |
| `systems/story/data/yukino_story.gd` | ✅ 已完成 | — |
| `systems/story/story_data_template.gd` | ✅ 已完成 | — |
| `systems/story/story_event_system.gd` | ✅ 已完成 | — |
| `systems/story/vn_director.gd` | ✅ 已完成 | — |

---

### 模块：`systems/strategic/`（战略系统，3 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/strategic/siege_system.gd` | ✅ 已完成 | — |
| `systems/strategic/supply_logistics.gd` | ✅ 已完成 | — |
| `systems/strategic/supply_system.gd` | ✅ 已完成 | — |

---

### 模块：`systems/tutorial/`（教程系统，2 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/tutorial/pirate_onboarding.gd` | ✅ 已完成 | — |
| `systems/tutorial/tutorial_manager.gd` | ⚠️ 已完成 — gdparse 工具兼容性 | L495/496/509/513：内联 Lambda，gdparse 误报，Godot 4.2 正常 |

---

### 模块：`systems/values/`（数值系统，2 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/values/order_manager.gd` | ✅ 已完成 | — |
| `systems/values/threat_manager.gd` | ✅ 已完成 | — |

---

### 模块：`systems/web/`（Web 系统，1 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/web/web_loader.gd` | ✅ 已完成 | — |

---

### 模块：`systems/world/`（世界系统，1 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/world/weather_system.gd` | ✅ 已完成 | — |

---

### 模块：`tests/`（测试，20 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `tests/pirate_t0_t3_run.gd` | ✅ 已完成 | — |
| `tests/test_attack_bug_scene.gd` | ✅ 已完成 | — |
| `tests/test_attack_bugs.gd` | ✅ 已完成 | — |
| `tests/test_balance_config.gd` | ✅ 已完成 | — |
| `tests/test_combat_resolver.gd` | ✅ 已完成 | — |
| `tests/test_effect_resolver.gd` | ✅ 已完成 | — |
| `tests/test_event_bus.gd` | ✅ 已完成 | — |
| `tests/test_event_registry.gd` | ✅ 已完成 | — |
| `tests/test_event_scheduler.gd` | ✅ 已完成 | — |
| `tests/test_faction_data.gd` | ✅ 已完成 | — |
| `tests/test_hero_leveling.gd` | ✅ 已完成 | — |
| `tests/test_new_systems.gd` | ✅ 已完成 | — |
| `tests/test_quest_progress_tracker.gd` | ✅ 已完成 | — |
| `tests/test_realworld.gd` | ✅ 已完成 | — |
| `tests/test_resource_manager.gd` | ✅ 已完成 | — |
| `tests/test_runner.gd` | ✅ 已完成 | — |
| `tests/test_save_manager.gd` | ✅ 已完成 | — |
| `tests/test_save_migration.gd` | ✅ 已完成 | — |
| `tests/test_victory_conditions.gd` | ✅ 已完成 | — |
| `tests/web_readiness_check.gd` | ✅ 已完成 | — |

---

### 模块：`tools/`（工具，1 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `tools/balance_analyzer.gd` | ✅ 已完成 | — |

---

### 模块：`template/`（模板，1 个文件）

| 文件 | 扫描状态 | 备注 |
| :--- | :--- | :--- |
| `systems/story/story_data_template.gd` | ✅ 已完成 | — |

---

## 五、接力开发建议

基于本次扫描结果，为后续接力开发提供以下建议：

**立即行动（P0）**：修复 `ai_faction_elf.gd` 的缩进错误和 `human_kingdom_events.gd` 的字符串引号问题，这两个文件会导致精灵族 AI 模块和人类王国事件模块完全无法加载。

**近期加固（P1）**：将 `game_manager.gd` 和 `intel_overlay.gd` 中的 `get_node()` 调用统一改为 `get_node_or_null()` 模式，提高系统在场景切换和节点动态销毁时的健壮性。

**工具配置**：`gdparse 4.5.0` 对 Godot 4.2 的内联 Lambda 语法存在兼容性问题，建议在 CI/CD 流程中升级至 `gdparse 4.6+` 或在 `.gdlintrc` 中针对性禁用相关规则，避免误报干扰开发。

---

*文档由 Manus AI 自动生成 | 扫描工具：静态语法分析 + gdparse 4.5.0*
