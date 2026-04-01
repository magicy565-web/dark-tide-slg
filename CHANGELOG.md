# 《暗潮 Dark Tide》更新日志

---

## v4.1.0 — 2026-04-01 (代码质量: Autoload精简 + 数值外部化 + 文档)

### Autoload精简 (79 → 78)

- **移除 StoryDialog autoload**: `story_dialog.gd` 不被任何代码作为全局单例访问, 仅被 VnDirector 在注释中提及. 从 project.godot 移除, 无功能影响.
- **CGGalleryPanel 保留**: `main_menu.gd` 通过 `CGGalleryPanel.show_gallery()` 直接引用, 移除不安全.
- **EventRegistry + EventScheduler 合并跳过**: 引用面过广, 风险大于收益.

### 硬编码值外部化 (scene_audio_director.gd)

- **BUG**: `SceneAudioDirector` 的威胁阈值 (`THREAT_TENSE_THRESHOLD=50`, `THREAT_CRISIS_THRESHOLD=80`) 硬编码, 与 BalanceConfig 中心化原则冲突.
- `balance_config.gd` 新增 `THREAT_BGM_TENSE_THRESHOLD` (50) 和 `THREAT_BGM_CRISIS_THRESHOLD` (80).
- `scene_audio_director.gd` 改为引用 BalanceConfig, 带 fallback 默认值.

### 空函数注释 (combat_view.gd)

- `from_save_data()` 空 pass 已补充注释: 战斗视图为临时UI, 从游戏状态重建, 无需持久化.

### 新增文档

- `README.md`: 项目简介 + 架构目录 + 启动说明

### 文件变更清单

| 文件 | 变更类型 |
|------|----------|
| project.godot | 精简 (-StoryDialog autoload, 79→78) |
| systems/balance/balance_config.gd | 增强 (+2 BGM威胁阈值常量) |
| systems/audio/scene_audio_director.gd | 增强 (阈值引用BalanceConfig) |
| scenes/ui/combat/combat_view.gd | 注释 (from_save_data 意图说明) |
| README.md | **新增** (项目文档) |
| CHANGELOG.md | 新增条目 |

---

## v3.7.0 — 2026-03-30 (存档修复 + Credits画面)

### 修复: WeatherSystem 未注册为 Autoload (P1)

- **BUG**: WeatherSystem (`systems/world/weather_system.gd`) 有 `class_name` 但从未注册为 Autoload
- 多处代码通过 `root.has_node("WeatherSystem")` 访问，运行时始终找不到节点
- project.godot 新增 `WeatherSystem` Autoload 注册
- 天气/季节/燃烧地块现在正常运作

### 修复: WeatherSystem 未纳入存档 (P1)

- **BUG**: 天气/季节/燃烧地块状态在存档后丢失
- save_manager.gd `_collect_save_data()` 新增 `"weather"` 条目
- save_manager.gd `_apply_save_data()` 新增恢复块 (4m)
- 存档包含: current_season, current_weather, current_turn, season_turn, burning_tiles

### 修复: EspionageSystem 未纳入存档 (P1)

- **BUG**: 情报/反谍/冷却/侦察/破坏状态在存档后丢失
- save_manager.gd `_collect_save_data()` 新增 `"espionage"` 条目
- save_manager.gd `_apply_save_data()` 新增恢复块 (4n)
- 存档包含: intel, counter_intel, cooldowns, revealed_tiles, intercepted_orders, sabotaged_tiles, wounded_heroes, consecutive_failures, scout_history

### 新增: Credits 画面

- 主菜单新增 "Credits" 按钮
- 滚动面板显示: 制作团队/系统设计/18位角色/引擎/致谢
- 返回按钮回到标题画面

### 版本号更新

- SAVE_VERSION: 3.3.0 → 3.7.0
- main_menu 版本标签: v4.0.0-pixel → v3.7.0-pixel

### 文件变更清单

| 文件 | 变更类型 |
|------|----------|
| project.godot | 增强 (+WeatherSystem Autoload) |
| autoloads/save_manager.gd | 增强 (天气+谍报存档/读档, 版本号) |
| scenes/ui/main_menu.gd | 增强 (Credits画面 + 版本号) |
| CHANGELOG.md | 新增条目 |

---

## v3.6.1 — 2026-03-30 (关键集成修复: 孤立系统接入运行时)

### 修复: 兵种训练回合推进

- **BUG**: TroopTrainingPanel.process_turn() 从未被调用, 训练永远不会完成
- game_manager.gd begin_turn() Phase 5b3 新增调用, 每回合推进训练进度
- 训练完成后自动解锁能力并通知玩家

### 修复: 装备锻造回合推进

- **BUG**: EquipmentForge.process_turn() 从未被调用, 锻造永远不会完成
- game_manager.gd begin_turn() Phase 5b4 新增调用
- start_game() 新增 EquipmentForge.reset() 和 init_player() 初始化

### 新增: 装备锻造 UI 面板 (equipment_forge_panel.gd)

- **KEY_J** 打开/关闭, HUD 内政面板新增"装备锻造"按钮
- 左侧配方列表: 按类型分组(武器/防具/饰品), 状态色彩编码(可锻造/锁定/队列中/已完成)
- 右侧详情: 属性/被动/前置条件/锻造等级需求, 开始锻造按钮
- 锻造队列: 进度条+取消按钮(50%退款)
- 锻造炉升级: 当前等级+升级费用+升级按钮
- 未领取物品: 背包满时暂存, 可手动领取

### 修复: 补给后勤接入运行时

- **BUG**: SupplyLogistics.process_turn() 从未被调用
- game_manager.gd Phase 5g4 新增调用, 与 SupplySystem 并行运作

### 修复: 存档系统遗漏

- **BUG**: TreatySystem / EquipmentForge / SupplyLogistics 的存档/读档未接入
- save_manager.gd _collect_save_data() 新增3个条目
- save_manager.gd _apply_save_data() 新增3个恢复块 (4j/4k/4l)

### ESC 优先级更新

- main.gd _unhandled_input() ESC 级联新增 equipment_forge_panel 检查

### 文件变更清单

| 文件 | 变更类型 |
|------|----------|
| scenes/ui/equipment_forge_panel.gd | **新增** (装备锻造 UI 面板) |
| autoloads/game_manager.gd | 增强 (process_turn 接入 + reset/init) |
| autoloads/save_manager.gd | 增强 (3系统存档/读档) |
| scenes/main.gd | 增强 (锻造面板实例化 + ESC) |
| scenes/ui/hud.gd | 增强 (锻造按钮 + KEY_J 快捷键) |

---

## v3.6.0 — 2026-03-30 (条约外交+补给后勤+装备锻造 三大深度系统)

### 新系统: 条约外交 (treaty_system.gd, 802行)

- **8种条约类型**: 停战/互不侵犯/贸易协定/军事通行/防御同盟/攻击同盟/附庸/联邦
- **条约效果**: 贸易+15%金币/军事通行/防御+15%DEF/攻击+10%ATK/附庸20%贡金/联邦+5%全属性
- **声望系统**: -100~+100, 7级("唾弃"→"盟友"), 毁约-20~-50声望+级联惩罚
- **AI条约逻辑**: 基于威胁/实力/声望/共同敌人评估提案, 主动提议停战/同盟/贸易
- **附庸贡金**: 每回合自动从附庸收取20%金币收入
- **条约提案流程**: propose→accept/reject→break, 完整存档支持

### 新系统: 补给后勤 (supply_logistics.gd, 1074行)

- **补给站网络**: 仓库/兵营/走私巢穴自动成为补给站, 首都最高容量(200)
- **补给路线**: BFS计算军队→最近补给站路径, 距离影响效率(1-3格100%/4-6格75%/7+格50%)
- **路线切断**: 敌军占据路线上地块→补给中断→军队进入掠食模式
- **补给车队**: 玩家手动派遣车队(1格/回合), 可被敌军拦截(损失50%+战斗)
- **军队消耗**: 基础5+每额外编制1, 4种状态(充足/掠食-10%/饥荒-5%兵/崩溃→解散)
- **补给事件**: 丰收+50%/蝗灾-30%/商路+20%(永久)/劫掠
- **阵营加成**: 兽人0.7x消耗/海盗沿海免补给站/暗精灵暗影紧急补给(5回合CD)

### 新系统: 装备锻造 (equipment_forge.gd, 568行)

- **12种锻造配方**: 3武器(鉄剣→鋼刃→暗炎剣) + 3防具(革鎧→鉄壁鎧→影隠外套) + 3饰品(戦太鼓→水晶球→不死鳥羽) + 3传说级
- **传说级装备**: ゴルクの肉断ち(AoE) / 黒旗(敌ATK-20%) / 虚無の冠(支配1敌)
- **锻造流程**: 选配方→检查资源→扣费→等待回合→完成→入库
- **锻造等级**: 1-3级锻造炉, 升级解锁高级配方
- **取消退款50%**: 中途取消返还半数材料
- **传说级限一**: 全局追踪, 每种传说装备整局游戏只能锻造一件

### 外交面板重构 (diplomacy_panel.gd, 1514行)

- **条约标签页**: 活跃条约列表+收到提案(接受/拒绝)+发起提案按钮
- **声望标签页**: 各阵营声望条(-100~+100)+等级标签+变更历史
- **增强现有标签**: 阵营卡片旁显示条约图标+快速提案按钮+声望色彩编码
- **条约提案弹窗**: 选择伙伴→选择类型→条款预览→接受概率→确认/取消

### 系统注册 (project.godot)

- 新增4个Autoload: TreatySystem, SupplyLogistics, EquipmentForge, EspionageSystem

### 文件变更清单

| 文件 | 变更类型 |
|------|----------|
| systems/faction/treaty_system.gd | **新增** (802行, 条约外交+声望系统) |
| systems/strategic/supply_logistics.gd | **新增** (1074行, 补给后勤网络) |
| systems/hero/equipment_forge.gd | **新增** (568行, 装备锻造系统) |
| scenes/ui/diplomacy_panel.gd | 重构 (→1514行, 条约/声望标签+提案弹窗) |
| project.godot | 增强 (+4个Autoload注册) |

---

## v3.5.0 — 2026-03-30 (地块信息指示器 + 情报系统可视化)

### 新系统: 地块信息指示器 (tile_indicator_system.gd, 684行)

- **8种实时指示器** 覆盖每个已揭露地块:
  - **驻军徽章** (左上): 显示"⚔12", 绿色=己方/红色=敌方/灰色=中立
  - **秩序指示灯** (右上): 绿(>60)/黄(30-60)/橙(10-30)/红(<10), 仅己方地块
  - **建筑标识** (左下): 建筑缩写+等级 (如"训Lv2"), 蓝色=己方
  - **补给状态** (右下): ✓已连接(绿)/✗断供(红)/⚠远距(黄), 仅己方地块
  - **要冲标记** (中心): 金色脉冲"⚡"标识咽喉要道
  - **情报图标** (覆盖层): 👁侦察中(蓝, 随回合衰减)/⚠破坏中(红, 脉冲)/🛡高反谍(灰)
  - **领地等级星** (上方): 1-5金色星标
  - **资源迷你条** (下方): 金/粮/铁三色比例条
- **3D→2D投影**: 利用Camera3D.unproject_position()实时追踪地块屏幕坐标
- **缩放自适应**: 随摄像机距离自动缩放+远距淡出
- **迷雾联动**: 未揭露地块自动隐藏所有指示器
- **图层开关**: toggle_layer()可分类切换显示

### 新系统: 情报可视化覆盖层 (intel_overlay.gd, 1268行)

#### 情报地图覆盖 (Part 1)
- **侦察高亮**: 已侦察地块蓝色覆盖层, 透明度随剩余回合衰减(3回合=100%→1回合=33%)
- **破坏高亮**: 被破坏地块红色脉冲覆盖 + "⚠" + "-20%" 产出惩罚标识
- **受伤英雄标记**: 黄色十字图标标记受伤英雄驻扎地块
- **截获命令预览**: 浮动卡片显示被截获的敌方下回合行动
- **情报热力图** (H键切换): 绿→红渐变显示情报覆盖密度, 近=情报充足/远=情报匮乏

#### 地块悬浮提示卡 (Part 2)
- **280px浮动信息卡**: 鼠标悬停0.3秒后显示, 跟随鼠标+视口边缘约束
- **阵营色带头部**: 显示地块名称+阵营徽章+等级
- **4种详情模式**:
  - 己方地块: 完整数据 (产出/精确驻军/建筑升级/补给/秩序)
  - 敌方(已侦察): 驻军/建筑/产出估算/城墙HP
  - 敌方(未侦察): "情报不足" + 模糊驻军估算 ("约20-30兵")
  - 中立地块: 势力名/驯服度/任务状态
- **迷雾处理**: 未揭露地块显示"未探索区域"
- **情报状态区**: 显示当前侦察/破坏状态与剩余回合

#### 情报总览侧面板 (Part 3, I键切换)
- **240px可折叠面板**: 右侧边缘, KEY_I切换显示
- **情报/反谍进度条**: 数值+可视化条
- **4个折叠区域**:
  - 已侦察地块 (名称+剩余回合)
  - 破坏中地块 (名称+惩罚+剩余回合)
  - 截获情报 (敌方下回合计划)
  - 受伤英雄 (名称+减益+剩余回合)

### EventBus新增11个信号

- **地块指示器** (3): tile_indicators_toggle, tile_indicator_refresh, tile_indicators_rebuild
- **情报覆盖** (8): intel_tile_scouted, intel_tile_sabotaged, intel_orders_intercepted, intel_hero_wounded, intel_overlay_toggle, intel_report_requested, tile_tooltip_requested, tile_tooltip_dismissed

### 谍报系统信号集成 (espionage_system.gd)

- 侦察成功后发射 intel_tile_scouted 信号
- 破坏成功后发射 intel_tile_sabotaged 信号
- 截获命令后发射 intel_orders_intercepted 信号
- 暗杀致伤后发射 intel_hero_wounded 信号
- 每回合结算后发射 tile_indicator_refresh 刷新所有指示器
- 所有信号发射带 has_signal 安全检查

### 文件变更清单

| 文件 | 变更类型 |
|------|----------|
| scenes/ui/tile_indicator_system.gd | **新增** (684行, 地块信息指示器) |
| scenes/ui/intel_overlay.gd | **新增** (1268行, 情报可视化+提示卡+总览面板) |
| autoloads/event_bus.gd | 增强 (+11个新信号) |
| systems/faction/espionage_system.gd | 增强 (5处情报信号发射) |
| scenes/main.gd | 增强 (2个新覆盖层集成) |

---

## v3.4.0 — 2026-03-30 (游戏体验优化 + 6大新系统)

### 新系统: 行动可视化 (action_visualizer.gd, 732行)

- **攻击可视化**: 红色虚线箭头+刀剑碰撞图标+屏幕边缘红闪+浮动结果文字("胜利!"/"失败!")
- **部署可视化**: 蓝色箭头+旗帜沿路径移动+到达脉冲
- **征募可视化**: 绿色粒子效果+"+兵 xN"浮动文字
- **建造可视化**: 锤子动画+灰尘粒子+"建造完成!"浮动文字
- **研究可视化**: 卷轴图标+紫色粒子拖尾+横幅公告
- **回合过渡**: 大字"第N回合"缩放动画+阵营徽章水印+画面暗化
- **领地占领**: 阵营色脉冲环+"占领!"文字
- **效果队列系统**: 多效果顺序播放,25%重叠

### 新系统: AI指示器 (ai_indicator.gd, 492行)

- **位置**: 右上角紧凑覆盖层,仅AI回合时显示
- **内容**: 阵营名称(阵营色)+当前行动("进攻中...")+阶段进度条+最近5条行动日志
- **动画**: 从右侧滑入/滑出+阵营名脉冲发光+日志条目淡入
- **行动类型中文化**: attack→进攻, deploy→部署, recruit→征募, build→建造, research→研究, explore→探索, diplomacy→外交
- **跳过按钮**: 可跳过AI动画演出
- **信号集成**: ai_action_started/completed, ai_turn_progress, ai_thinking

### 新系统: 指令控制台 DEBUG (debug_console.gd, 1426行)

- **切换**: 反引号键(`)打开/关闭, 底部40%高度面板
- **4标签页**:
  - **控制台**: 终端风格输入/输出, 命令历史(↑↓), Tab自动补全
  - **游戏状态**: 实时资源/AP/领地/军队/回合数/威胁/秩序/英雄状态网格
  - **平衡监视**: 阵营战力对比条/经济收支/军事力量/BalanceManager警告
  - **事件日志**: 全部EventBus信号时间线, 分类过滤, 点击查看参数
- **24条命令**: help, give gold/food/iron/ap, set turn/threat/order, spawn, tp, reveal, god, win, kill, heal, research, level, dump state/tiles/armies, eval, clear, speed, spy
- **信号间谍模式**: 实时记录所有EventBus信号发射
- **性能监控**: FPS/内存用量实时显示

### 新系统: 兵种训练面板 (troop_training_panel.gd, 981行)

- **核心概念**: 每种兵种3个能力升级槽, 花费金币+战略资源+等待N回合解锁
- **布局**: 全屏模态 — 左侧兵种列表(按阵营分组) + 中央兵种详情 + 右侧能力树
- **3级训练**:
  - 基础训练(T1): 低费用, 1-2回合
  - 进阶训练(T2): 中等费用, 2-3回合, 需要T1
  - 精通训练(T3): 高费用, 3-4回合, 需要T2
- **9种邪恶阵营兵种**: 兽人足轻/武士/骑兵, 海盗散兵/弓手/炮兵, 暗精灵武士/忍者/骑兵
- **训练状态管理**: 内置状态字典, 支持开始/取消(50%退款)/回合推进/存档序列化
- **快捷键**: U键打开, ESC关闭

### 科技树面板重构 (tech_tree_panel.gd, 437→911行)

- **节点图视图**: 从简单列表改为2D节点图, T1左/T2中/T3右, 前置连线
- **增强卡片**: 160x100px, 分支色带(前锋=红/远程=黄/机动=蓝/法术=紫/特殊=金), 状态图标(✓/⟳/🔒/◇)
- **连接线**: `_draw()`绘制贝塞尔曲线 — 灰色虚线(锁定)/金色实线(可用)/绿色发光(完成)/流动光点(研究中)
- **研究队列条**: 顶部水平显示当前+排队研究, 进度环+简称+剩余回合
- **详情面板升级**: BBCode描述/彩色效果列表(ATK↑绿/DEF↑蓝/被动✦金)/资源图标成本/前置状态勾选
- **缩放控制**: 滚轮或+/-按钮, 50%-200%
- **入场动画**: 卡片交错淡入

### 任务面板增强 (quest_journal_panel.gd)

- 支线任务子分类: 剧情/奖励/情报 三标签
- 卡片色彩按状态区分: 完成=绿/激活=黄/可用=蓝/待战斗=红/失败=暗红/锁定=灰

### EventBus新增22个信号

- **AI指示器** (4): ai_action_started, ai_action_completed, ai_turn_progress, ai_thinking
- **调试控制台** (3): debug_command_executed, debug_state_changed, debug_log
- **行动可视化** (5): action_visualize_attack/deploy/recruit/build/research
- **兵种训练** (4): troop_training_started/completed/cancelled, troop_ability_unlocked
- **任务面板** (4): task_assigned, task_progress_updated, task_completed, task_panel_refresh_requested

### GameManager集成 (game_manager.gd)

- AI回合处理: 每阶段发射ai_action_started/completed/turn_progress信号
- 玩家行动: 攻击/部署/征募/建造后发射action_visualize信号
- 新增`_get_faction_key()`辅助函数

### HUD集成 (hud.gd)

- 国内面板新增"兵种训练"按钮 (快捷键U)
- 连接到troop_training_panel.show_panel()

### 文件变更清单

| 文件 | 变更类型 |
|------|----------|
| scenes/ui/action_visualizer.gd | **新增** (732行, 行动可视化覆盖层) |
| scenes/ui/ai_indicator.gd | **新增** (492行, AI回合指示器) |
| scenes/ui/debug_console.gd | **新增** (1426行, 调试控制台) |
| scenes/ui/troop_training_panel.gd | **新增** (981行, 兵种训练面板) |
| scenes/ui/tech_tree_panel.gd | 重构 (437→911行, 节点图视图) |
| autoloads/event_bus.gd | 增强 (+22个新信号) |
| autoloads/game_manager.gd | 增强 (AI/行动可视化信号发射) |
| scenes/main.gd | 增强 (4个新面板集成+ESC处理) |
| scenes/ui/hud.gd | 增强 (兵种训练按钮+快捷键U) |

---

## v3.3.0 — 2026-03-25 (战斗演出强化 + 装备系统完善 + 全面Debug)

### 战斗演出增强 (combat_view.gd)

- **英雄技能视觉**: 治疗技能→绿色上升粒子; 伤害/AOE→扩散冲击环; 增益→金色上升箭头; 减益→红色下降箭头
- **击杀演出强化**: 击杀时0.3秒慢动作 + 白色闪屏; 最后一个单位击杀额外缩放震动
- **回合过渡动画**: 大字"第X回合"缩放淡出 + 暗角脉冲效果
- **英雄KO可视化**: 红色闪烁 + "K.O."覆盖文字(2x缩放弹入) + 裂痕线条效果
- **状态图标增强**: Buff/Debuff箭头指示; 毒素脉冲绿色覆盖; 燃烧脉冲橙色覆盖

### 装备系统完善

- **英雄界面装备**: hero_detail_panel 空装备栏新增"装备"按钮, 弹出筛选面板可直接装备
- **背包装备**: inventory_panel 装备详情页新增"装备到[英雄名]"按钮列表
- **战斗掉落**: 玩家胜利后自动掉落随机战利品 (70%消耗品/30%装备)

### Bug修复 (9个)

- **CRASH**: `QuestManager.get_all_unlocked_neutral_troops()` 函数缺失 → 新增聚合函数
- **CRASH**: `LightFactionAI.get_tile_owner()` 不存在 → 改用 GameManager.tiles 直接查询
- **CRASH**: `ThreatManager.tick_timers()` 从未被调用 → 加入Phase 4
- **CRASH**: `ThreatManager.check_dominance()` 从未被调用 → 加入Phase 4
- **CRASH**: `HeroSystem.process_prison_turn()` 从未被调用 → 加入Phase 5c3
- **BUG**: `get_army_combat_power` 整数截断 → 改为浮点除法
- **BUG**: HeroLeveling 存档重复反序列化 → 移除 save_manager 中的冗余调用
- **DEPRECATED**: 2处 `emit_signal()` Godot 3语法 → 改为 `.emit()` (balance_manager, board)
- **CLEANUP**: hud.gd 移除多余 `has_signal()` 守卫

### 文件变更清单

| 文件 | 变更类型 |
|------|----------|
| scenes/ui/combat_view.gd | 增强 (+350行动画/视觉效果) |
| scenes/ui/hero_detail_panel.gd | 增强 (装备选择弹窗) |
| scenes/ui/inventory_panel.gd | 增强 (装备到英雄功能) |
| autoloads/game_manager.gd | 修复 (4个缺失调用 + 战斗掉落 + 整数截断) |
| autoloads/save_manager.gd | 修复 (重复反序列化) |
| systems/npc/quest_manager.gd | 修复 (新增聚合函数) |
| systems/combat/combat_abilities.gd | 修复 (tile_owner查询) |
| systems/balance/balance_manager.gd | 修复 (emit_signal语法) |
| scenes/board/board.gd | 修复 (emit_signal语法) |
| scenes/ui/hud.gd | 修复 (移除has_signal守卫) |

---

## v3.2.0 — 2026-03-24 (地形系统全面重构)

### 地形系统重构 (faction_data.gd TERRAIN_DATA)

- **新增地形**: 河流 (RIVER)、遗迹 (RUINS)、荒原 (WASTELAND)、火山 (VOLCANIC), 共10种地形
- **统一数据源**: 所有地形数据合并至 `TERRAIN_DATA` 字典, 消除三处硬编码不一致
  - 每种地形包含: atk_mult, def_mult, move_cost, visibility_range, prod_mult, attrition_pct
  - 每种地形包含 `unit_mods`: 8种兵种 × (atk/def/spd/ban) 修正值
- **移动消耗**: 地形移动AP从固定1改为数据驱动 (平原1, 森林2, 山地3, 河流3, 火山4等)
- **视野系统**: BFS迷雾战争, 视野范围受地形影响 (平原3, 山地4, 森林1, 火山2等)
- **生产修正**: 地形影响据点产出倍率 (平原1.0, 森林0.8, 遗迹1.3, 火山0.5等)
- **损耗系统**: 新增地形损耗 (荒原2%/回合, 火山5%/回合, 沼泽3%/回合)

### 战斗系统数据驱动化 (combat_system.gd + combat_resolver.gd)

- **地形修正**: combat_system 和 combat_resolver 的硬编码 match 块替换为 TERRAIN_DATA 查询
- **兵种地形适性**: 8种兵种类别 (infantry/cavalry/archer/mage/tank/assassin/artillery/support) 各有独立地形修正
- **Terrain enum对齐**: 修复 COASTAL 缺失导致的枚举偏移问题

### 地图与UI更新

- **地图生成**: map_generator 新增4种地形权重, 地形字符串映射更新
- **棋盘渲染**: board.gd 新增4种地形颜色和高度值
- **战斗UI**: combat_view 地形名称改为数据驱动查询
- **HUD**: 地形提示框显示移动消耗和损耗信息
- **命名据点**: 新增8个命名据点 (河流/遗迹/荒原/火山各2)

### 文件变更清单

| 文件 | 变更类型 |
|------|----------|
| systems/faction/faction_data.gd | 重构 (TerrainType enum + TERRAIN_DATA + TERRAIN_ZONE_WEIGHTS + NAMED_OUTPOSTS) |
| systems/combat/combat_system.gd | 重构 (Terrain enum + 数据驱动地形修正) |
| systems/combat/combat_resolver.gd | 重构 (数据驱动地形修正) |
| systems/balance_config.gd | 修改 (旧地形常量标记DEPRECATED) |
| systems/economy/production_calculator.gd | 修改 (地形产出倍率) |
| autoloads/game_manager.gd | 修改 (移动消耗 + BFS视野 + 损耗系统) |
| systems/map/map_generator.gd | 修改 (新地形权重和映射) |
| scenes/board/board.gd | 修改 (新地形颜色和高度) |
| scenes/ui/combat_view.gd | 修改 (数据驱动地形名称) |
| scenes/ui/hud.gd | 修改 (地形信息提示框) |
| scenes/ui/main_menu.gd | 修改 (版本号 → v3.2.0) |
| autoloads/save_manager.gd | 修改 (SAVE_VERSION → 3.2.0) |
| systems/mod/mod_manager.gd | 修改 (GAME_VERSION → 3.2.0) |

---

## v3.1.0 — 2026-03-24 (英雄等级成长系统 + 独立HP模型)

### 新系统: 英雄等级成长 (hero_level_data.gd + hero_leveling.gd)

- **等级系统**: 英雄 Lv1-20, 二次曲线EXP表 (总计1500 EXP满级, 约50回合)
- **成长率**: 每位英雄独立成长率 (Fire Emblem风格确定性成长, 非RNG)
  - 攻击型: 翠玲/焔/蒼 ATK成长 8-9/10
  - 防御型: 冰华 DEF成长 9/10, HP成长 10/10
  - 法术型: 月华/紫苑 INT成长 9-10/10
  - 速度型: 叶隐 SPD成长 10/10
- **英雄HP/MP池**: 每位英雄有独立HP/MP, 战斗中可被击倒 (失去被动加成)
- **被动技能树**: 每位英雄4个等级解锁被动 (Lv3/Lv7/Lv12/Lv18)
  - 共40个新被动技能 (光环/反击/治疗/闪避/DoT/时间操控等)
- **EXP获取**: 战斗胜利+10, 失败+3, 每击杀+2, 击败英雄军+15
- **难度缩放**: EXP受玩家经验倍率影响

### 新系统: 独立HP模型 (troop_registry.gd + combat_system.gd)

- **单兵HP**: 每个部队新增 `hp_per_soldier` 字段
  - T0: 3HP, T1: 3-5HP, T2: 4-8HP, T3: 4-10HP, T4: 20-30HP
  - 部队总HP = 兵数 × 单兵HP
- **战斗伤害**: 伤害扣减HP, 兵数从剩余HP推算 (`ceili(hp/hpp)`)
- **恢复机制**: regen类被动按单兵HP恢复

### 文件变更清单

- **新增** `systems/hero/hero_level_data.gd` — 静态数据 (EXP表/成长率/被动技能树)
- **新增** `systems/hero/hero_leveling.gd` — 运行时等级管理 (Autoload)
- **修改** `systems/combat/troop_registry.gd` — 全51个部队添加 hp_per_soldier
- **修改** `systems/combat/combat_system.gd` — BattleUnit HP字段, 伤害→HP模型
- **修改** `systems/faction/faction_data.gd` — 英雄添加 base_hp/base_mp
- **修改** `systems/hero/hero_system.gd` — 使用等级化数值, 序列化支持
- **修改** `autoloads/game_data.gd` — 部队实例HP字段, HP总量计算
- **修改** `autoloads/game_manager.gd` — 战斗后英雄EXP发放
- **修改** `autoloads/event_bus.gd` — 3个新信号 (升级/技能解锁/经验获取)
- **修改** `systems/balance_config.gd` — 英雄升级常量
- **修改** `systems/balance/balance_manager.gd` — 英雄成长审计, EHP公式更新
- **修改** `project.godot` — 注册 HeroLeveling 自动加载

---

## v3.0.1 — 2026-03-24 (海盗势力前期强化)

### 海盗经济调整 (faction_data.gd)
- **起始资源**: 粮食 100→180, 铁矿 40→60, 火药 0→5
- **食物消耗**: food_per_soldier 1.0→0.7 (缓解前期粮荒)
- **基础产出倍率**: base_production_mult 0.6→0.7
- **掠夺收益**: plunder_base_per_tile 3→5

### 海盗兵种强化 (troop_registry.gd)
- **海盗散兵**: ATK 5→6, 兵数 6→7 (raw_power 54→70, 与兽人足轻接近)

### 海盗建筑降价 (building_registry.gd)
- **走私者巢穴 Lv1**: 成本 100金+8铁→70金+5铁 (前期可更早建造)

### 海盗士气提升 (pirate_mechanic.gd)
- **起始朗姆酒士气**: 30→50 (立即获得ATK+2效果)

---

## v3.0.0 — 2026-03-24 (完整数值管理系统 + 平衡性全面修正)

### 新系统: BalanceManager (数值管理总控)

- 新增 `systems/balance/balance_manager.gd` (Autoload)
- **战力预算计算器**: raw_power / effective_power / cost_efficiency / DPS / EHP
- **英雄组合战力分析**: hero_combo_power() 检测过强搭配
- **经济曲线模拟器**: 按游戏阶段(early/mid/late/endgame)模拟各阵营收支
- **被动技能战力乘数表**: 40+被动技能的标准化效果评估
- **完整审计系统**: run_full_audit() 在游戏启动时自动检测:
  - 兵种战力是否超出T0-T4预算范围
  - 费效比异常值 (>2.5× 或 <0.3× 中位数)
  - 英雄+兵种组合DPS上限 (>15即警告)
  - 阵营间经济曲线偏差 (>2:1即警告)
  - 阵营起始资源公平性
  - 同阵营T(n+1)弱于T(n)的逆向进阶
  - 最强DPS vs 最强EHP的回合数 (<1.5回合即报错)

### 新系统: 四级难度设定

- **简单**: AI战力×0.80, 远征-40%, 威胁+70%, 玩家收入+20%, 经验+50%, 城墙-25%
- **普通**: 所有数值×1.00 (基准)
- **困难**: AI战力×1.15, 远征+30%, 威胁+20%, 玩家收入-15%, 城墙+25%
- **噩梦**: AI战力×1.30, 远征+60%, 威胁+50%, 玩家收入-30%, 城墙+50%
- 难度设置已集成到: 战斗AI缩放/联盟远征/威胁增长/城墙HP/设置面板/存档系统

### 关键平衡修正

**兵种数值修正:**
- **血月狂战士** (中立T2): ATK 14→11, 兵数 6→5
  - 修前: ×3触发时ATK=42, 一击秒杀几乎所有单位
  - 修后: ×3触发时ATK=33, 仍然强力但可被防御
- **地精炮兵** (中立T2): ATK 16→12, 费用 18→24, 自伤 15%→20%
  - 修前: T2的ATK等于T4蛮牛酋长, 严重越级
  - 修后: 保持独特定位(攻城×3)但不再碾压高阶兵种
- **树人** (精灵T3): 兵数 15→12, 费用 30→34
  - 修前: 15兵+DEF10+嘲讽=几乎不可能被击穿
  - 修后: 保持最强坦克定位但留出突破窗口

**经济修正:**
- **海盗金币乘数**: 1.5×→1.3× (防止滚雪球)
- **海盗铁矿乘数**: 0.5×→0.65× (缓解极端资源荒)
- **海盗粮食乘数**: 0.7×→0.75× (微调)

**阵营公平性修正:**
- **暗精灵起始领地**: 2→3 (永夜暗城+2前哨)
- **邪恶阵营总领地**: 11→12 (5+4+3)

**老兵系统增强:**
- 经验10: ATK+1, DEF+0 → ATK+1, DEF+1
- 经验25: ATK+1, DEF+1 → ATK+2, DEF+1, **兵数+1**
- 经验50: ATK+2, DEF+1 → ATK+3, DEF+2, **兵数+1**
- 经验80: ATK+2, DEF+2 → ATK+4, DEF+3, **兵数+2**
- 修正原因: 旧体系下满级老兵加成(+2/+2)远不及英雄加成(+7~+9), 老兵机制形同虚设

### 集成改动

- `project.godot`: 注册 BalanceManager autoload
- `event_bus.gd`: 新增 `difficulty_changed` 信号
- `combat_resolver.gd`: AI缩放层叠加难度乘数
- `alliance_ai.gd`: 远征概率乘以难度系数
- `threat_manager.gd`: 威胁增长乘以难度系数
- `light_faction_ai.gd`: 城墙HP乘以难度系数, 改用BalanceConfig常量
- `settings_panel.gd`: 新增难度选择器(OptionButton + 说明)
- `save_manager.gd`: 序列化/反序列化难度设定
- `game_manager.gd`: 游戏开始时运行balance audit(仅debug), 显示当前难度
- `main_menu.gd` / `mod_manager.gd` / `save_manager.gd`: 版本号统一为3.0.0

---

## v2.4.1 — 2026-03-24 (统一兵种注册表 + 角色绑定专属兵种)

### 架构重构: 兵种注册表 (TroopRegistry)

- 新增 `systems/combat/troop_registry.gd` (class_name TroopRegistry)
- 将全部50+兵种定义从 `game_data.gd` 抽离至统一注册表
- 按类别组织: 邪恶阵营(9)/正义阵营(9)/中立(13)/联盟(2)/终极(3)/叛军(2)/流浪(3)/角色绑定(10)
- `game_data.gd` 保留查询API/军队辅助函数, 通过 `TroopRegistry.get_all_troop_definitions()` 加载数据
- `PASSIVE_DEFS`/`ACTIVE_ABILITY_DEFS` 从 `const` 改为 `var` 以支持运行时合并角色绑定数据
- 零外部引用变更 — 所有消费者仍通过 `GameData.*` 访问

### 新功能: 正义方角色绑定专属兵种 (HERO_BOUND)

- 新增 `TroopCategory.HERO_BOUND` 枚举值
- 10位光明英雄各拥有1支专属部队 (T3级, 仅在英雄已招募时可征兵):
  - **凛** → 誓约骑士团 (前排武士, DEF+2/反击×1.3)
  - **雪乃** → 白百合巫女团 (后排祭司, 治愈/净化)
  - **红叶** → 枫骑兵团 (前排骑兵, 冲锋×1.8/全军SPD+1)
  - **冰华** → 圣殿卫士 (前排武士, 嘲讽/受伤-30%)
  - **翠玲** → 月光射手队 (后排弓兵, 先制×1.5/夜间ATK+3)
  - **月华** → 月神侍从团 (后排祭司, 法力护盾/+2法力)
  - **叶隐** → 暗叶忍众 (后排忍者, 2回合隐身/暴击40%×2.5)
  - **蒼** → 星辰弟子团 (后排法师, AoE×2.0/法术+25%)
  - **紫苑** → 时空卫士团 (后排法师, 时停/20%额外行动)
  - **焔** → 炎舞军团 (后排法师, AoE火焰/灼烧DoT)
- 每支专属部队拥有:
  - 独特被动技能 (10个新PASSIVE)
  - 独特主动技能 (10个新ACTIVE, 1次/战)
- `get_recruitable_troops()` 自动检查英雄招募状态过滤
- `get_hero_bound_troop(hero_id)` 查询英雄绑定兵种
- `get_hero_bound_troops_for_player()` 返回当前可用的全部绑定兵种

---

## v2.4.0 — 2026-03-24 (统一任务日志系统)

### 新功能: 任务日志 (Quest Journal)

- 新增统一任务管理器 `QuestJournal` (autoload)，支持4类任务:
  - **主线任务** (6阶段): 崛起之始→第一滴血→扩张的野心→光暗对峙→黑暗崛起→终焉之战
  - **支线任务** (10个): 建设者、经济大师、外交家、秩序守护者、闪电战等
  - **挑战任务** (每阵营6阶段): 兽人/海盗/暗精灵各有独立挑战链，解锁传奇装备和特性
  - **角色任务** (4英雄×3步): 凛/翠玲/蒼/焔的好感度驱动个人任务链
- 挑战任务奖励: 9件传奇装备 + 6个被动特性 + 3个终极技能
- 角色任务奖励: 4件传奇装备 + 4个英雄绑定特性

### 新功能: 任务日志UI面板

- 新增全屏模态面板 `QuestJournalPanel`，按 J 键或HUD按钮开启
- 4个标签页分类显示: 主线/支线/挑战/角色
- 每个任务卡片显示: 名称、状态徽章、描述、目标进度、奖励预览
- 挑战战斗按钮: 待战斗状态的任务可直接发起Boss战
- 实时刷新: 监听 `quest_journal_updated` 信号自动更新

### 系统集成

- `game_manager.gd`: 游戏开始时调用 `QuestJournal.init_journal(faction_id)`
- `save_manager.gd`: 完整序列化/反序列化任务日志状态
- `event_bus.gd`: 新增 `quest_journal_updated`、`challenge_battle_requested/resolved` 信号
- `hud.gd`: 新增"任务日志 (J)"按钮
- `main.gd`: 动态创建QuestJournalPanel，ESC处理集成
- 挑战战斗解决: 通过 `challenge_battle_resolved` 信号自动回调

### 文件变更

- 新增 `systems/quest/quest_journal.gd` — 统一任务管理器
- 新增 `systems/quest/quest_definitions.gd` — 主线/支线/角色任务数据
- 新增 `systems/quest/challenge_quest_data.gd` — 挑战任务数据 (从npc目录迁移)
- 新增 `scenes/ui/quest_journal_panel.gd` + `.tscn` — 任务日志UI面板
- 版本号统一升级至 v2.4.0

---

## v2.3.0 — 2026-03-24 (小地图 + 自动存档 + 附庸平衡修复)

### 新功能: 小地图

- HUD右下角新增小地图显示 (180×140px)
- 通过Board的SubViewport俯视摄像机实现
- 带半透明边框样式，在board_ready信号时自动初始化
- 位于消息日志上方，不遮挡操作面板

### 自动存档

- 开启"自动结束回合"设置后，每次人类玩家回合结束时自动存档到autosave槽位
- 通过SettingsPanel.get_setting("auto_end_turn")查询设置状态
- 仅在人类玩家回合触发，AI回合不存档

### 平衡性修复

- **附庸产出受秩序值影响**: get_vassal_production()现在应用OrderManager的生产力乘数，与正常领地产出机制一致（低秩序→减产，高秩序→增产）

---

## v2.2.1 — 2026-03-24 (关键Bug修复 + 数值外部化)

### 严重Bug修复

- **军队数据丢失**: 存档系统现在完整序列化/反序列化 `armies` 字典和 `_next_army_id` 计数器（之前存档后读档会丢失所有军队）
- **枚举引用错误**: `FactionData.Faction.ORC` → `FactionData.FactionID.ORC`（修复get_max_armies()中兽人WAAAGH!加成不生效）

### 版本号统一

- SAVE_VERSION: `1.5.0` → `2.2.0`（与实际游戏版本对齐）
- GAME_VERSION (mod_manager): `0.8.6` → `2.2.0`（MOD兼容性检查使用正确版本）

### 数值全面外部化

- **BalanceConfig新增常量组**:
  - `EVIL_FACTION_AI`: 突袭概率(10%)/突袭强度/驻军上限(14/10/6)
  - `LIGHT_SPELLS`: 传送增援(10-20)/屏障防御(10)/弹幕伤害(15-30)/法力容量(10/tile)
  - `COMBAT`: 战斗经验(胜5/负2)/防御方军队贡献(50%)/起始驻军(10)/占领后最低驻军(5)
  - `EXPEDITION`: 防御损耗(50%)/占领驻军(60%)
- **game_manager.gd**: COMBAT_POWER_PER_UNIT/HERO_BASE_COMBAT_POWER/BASE_POPULATION_CAP + 8处硬编码值→BalanceConfig
- **evil_faction_ai.gd**: 突袭系统5处硬编码值→BalanceConfig
- **light_faction_ai.gd**: 法术效果6处硬编码值→BalanceConfig

### 战斗视图修复

- **_on_combat_view_closed()**: 实现战斗结束回调（恢复HUD、发射信号、刷新地图），替代之前的空pass

---

## v2.2.0 — 2026-03-24 (中立势力领地系统 + 附庸机制)

### 新系统: 中立势力领地 & AI

- **领地扩展**: 每个中立势力基地现在拥有2个附属领地节点(通过 BalanceConfig.NEUTRAL_TERRITORY_NODES 配置)
  - 领地在地图生成后自动分配(取基地相邻的无主节点)
  - 领地节点有独立驻军(8-15兵力)和资源产出
  - 领地节点在地图上标记为"XX领地"

- **中立AI行为** (`neutral_faction_ai.gd`, 新文件):
  - **驻军恢复**: 每回合缓慢恢复驻军至初始值的1.5倍上限
  - **巡逻调兵**: 每2回合检测威胁，从安全领地调兵至受威胁领地
  - **战斗增援**: 被攻击时，相邻中立领地自动派遣30%驻军增援
  - **基地陷落**: 基地被攻占后势力瓦解，残余领地驻军减半并脱离阵营

### 新机制: 附庸系统

- **附庸转化**: 完成中立势力3步任务链后，自动转为玩家的附庸
- **附庸特性**:
  - 领地保留中立所有权(不计入玩家节点数)
  - 60%产出归玩家(金/粮/铁)，每回合自动结算
  - 独立驻军持续存在，享受+20%防御加成
  - 驻军仍会自动恢复
- **视觉标识**: 附庸领地在地图上显示为独特的绿色调，区别于普通中立灰色
- **HUD显示**: 悬停附庸领地时显示"附庸: XX"标签和领地节点数

### 集成点

- 新增 `NeutralFactionAI` 全局自动加载(project.godot)
- 存档系统完整支持序列化/反序列化(旧存档自动重建领地)
- EventBus 新增3个信号: `neutral_territory_attacked`, `neutral_faction_vassalized`, `vassal_territory_changed`
- BalanceConfig 新增中立势力配置组(领地数/驻军范围/巡逻/恢复/附庸产出)

---

## v2.1.0 — 2026-03-24 (数值统一 + AI改进 + 系统完善 + UI增强)

### 关键修复: 数值冲突统一

- **GameManager 与 BalanceConfig 数值冲突解决**: GameManager 中的所有战斗/经济常量现在统一委托给 BalanceConfig，消除了以下冲突:
  - 强行军损耗: 10% → 5% (统一为 BalanceConfig 值)
  - 最大军队数: 5 → 6 (统一为 BalanceConfig 值)
  - 地块最大等级: 3 → 5 (统一为 BalanceConfig 值)
  - 升级费用/产出乘数: 3级 → 5级 (统一为 BalanceConfig 的TW:W五级体系)

### Bug修复

- **好感度乘数整除Bug**: `hero_system.gd` 中 `float(aff / 5)` 改为 `float(aff) / 5.0`，修复了好感度低于5时加成被截断为0的问题
- **主菜单设置按钮**: 从禁用状态改为可用，连接到设置面板

### AI与平衡性

- **联盟AI使用BalanceConfig**: `alliance_ai.gd` 中所有硬编码阈值（30/60/80威胁、25%/40%远征概率、8/15远征兵力等）全部改为引用 BalanceConfig 常量
- **光明阵营防御数值外部化**: 城墙HP上限（10/25/50）、精灵结界吸收率（30%基础/15%灵脉/90%上限）、法师塔伤害倍率均移至 BalanceConfig
- **新增 BalanceConfig 常量组**: ALLIANCE_AI（远征机制）、LIGHT_FACTION_DEFENSE（城墙/结界/法师塔）

### 系统完善

- **军队上限升级系统**: 实现了 `get_max_armies()` 的完整逻辑，支持:
  - Lv3训练场建筑 → +1军团上限
  - "兵站精通"科技 → +1军团上限
  - 兽人WAAAGH!狂暴状态 → 临时+1军团
  - 上限封顶于 BalanceConfig.MAX_ARMIES_UPGRADED (6)
- **延迟地块效果实现**: 事件系统的 `gold_next_visit`、`attacked_next_turn`、`prep_turns` 三种延迟效果完整实现
- **"兵站精通"科技**: 为三个阵营训练树各添加 `logistics_mastery` 节点（军团+1, 补给+1）
- **ResearchManager添加is_completed()**: 为军队上限检查提供别名方法

### UI/UX增强

- **设置面板全面升级 (v2.1)**:
  - 新增"显示"分类: 网格显示、迷雾显示、战斗速度调节
  - 新增"自动结束回合"选项
  - 设置持久化: 保存到 `user://settings.cfg`，启动时自动加载
  - "恢复默认"按钮一键重置所有设置
  - 面板支持滚动，适配更多选项
  - 外部系统可通过 `get_setting()` 查询设置值
- **英雄面板装备选择弹窗**: 当多件装备匹配同一栏位时，显示选择弹窗让玩家选择（替代原来的自动装备第一件）

---

## v1.6.0 — 2026-03-23 (全战:战锤地图 + 战国兰斯07战斗 精细打磨)

### 大地图重写 — 全面战争:战锤风格 (board.gd, 831行)

**地形与地貌**:
- 地形海拔系统: 平原/森林/山地/沼泽/城墙各有不同高度
- 六角地块改用CylinderMesh, 边缘倒角更自然
- 森林/山地/沼泽地块附加装饰物 (树木/岩石/水面)
- 雾缘柔化: 战争迷雾边界渐变过渡

**城镇与建筑**:
- 城镇结构按等级缩放 (Lv1小屋→Lv2塔楼→Lv3城堡)
- 核心要塞/暗黑基地有独立视觉标识
- 建筑高度随等级增长, 顶部带旗帜

**军团可视化**:
- 军团人偶模型: 身体+头部+旗杆组合体
- 阵营颜色编码旗帜
- 平滑移动动画 (Tween lerp)
- 兵力Label3D实时更新

**摄像机与交互**:
- 摄像机惯性平滑移动 (lerp追踪目标)
- 双击地块居中摄像机
- 缩放时倾斜角变化 (近距低角度, 远距俯视)
- 鼠标悬停地块抬升效果
- 选中地块脉冲光环动画
- 行军路径虚线预览
- 边缘滚动支持

**阵营边界**:
- 阵营领地边界发光线条
- 实时更新边界随领地变化

**道路系统**:
- 节点间虚线道路 (加宽可见性)
- 道路颜色区分友方/敌方/中立

### 战斗视图重写 — 战国兰斯07风格 (combat_view.gd, 980行)

**单位卡片 (180×120px)**:
- 兵种色标头部标签 (足轻/武士/骑兵/弓兵/砲兵/忍者/法师/特殊)
- 指挥官肖像区域 (48×48)
- 双血条: 当前兵力(绿) + 最大兵力(暗底)
- ATK/DEF/SPD数值显示
- 增益箭头动画 (绿色↑/红色↓)
- 被动技能文字标签
- 行动回合闪烁横幅 ("行动中!")
- 歼灭/俘获死亡覆盖层

**阵型布局**:
- 双栏镜像布局: 攻方左侧 vs 守方右侧
- 前排3列 + 后排2列, 面对中央VS线
- 阵营色彩头部横条 + 阵营名称

**回合序列条**:
- 顶部显示下10个行动单位
- 当前行动单位高亮标记
- SPD排序可视化

**战斗时钟**:
- 12段圆弧进度显示
- 当前回合高亮, 已用回合变暗
- 中央回合数字

**攻击动画**:
- Line2D连线动画 (攻击方→目标)
- 颜色区分: 近战=红, 远程=黄, 魔法=紫, 忍者=绿
- 浮动伤害数字弹出
- 命中闪烁效果

**控制与日志**:
- 播放速度选择器 (1x/2x/3x)
- 战斗日志滚动面板
- 战斗结束结果覆盖层
- 关闭按钮 + ESC退出

### 战斗数据管线改进

**combat_system.gd**:
- 新增 `_snapshot_units()` 捕获战前/战后单位状态
- 新增 `_infer_unit_class()` 兵种分类推断
- `resolve_battle()` 返回扩展: terrain/rounds/attacker_units_initial/defender_units_initial/attacker_units_final/defender_units_final

**game_manager.gd**:
- 战斗结果附加title字段
- 人类玩家战斗自动触发 `combat_view_requested` 信号

---

## v1.5.0 — 2026-03-23 (可视化强化 + 音频系统 + 教程)

### 战斗可视化系统 (新增)

**combat_view.gd + combat_view.tscn** — 战国兰斯风格战斗演出:
- 5v5 阵型网格显示 (前排3 + 后排2)
- 兵种颜色编码: 足轻/武士/骑兵/弓兵/炮兵/忍者/法师/特殊
- 血量条动画 + 伤害闪烁效果
- 战斗日志逐步回放 (播放/单步/跳过)
- 回合计数器 + 地形信息显示
- 战斗结果覆盖层 (进攻方/防御方胜利)
- 死亡单位视觉变暗效果

### 音频系统 (新增)

**audio_manager.gd** — 完整音频管理框架:
- BGM 系统: 8种场景音乐ID (标题/选阵营/大地图/紧张/战斗/Boss/胜利/失败)
- 交叉淡入淡出 BGM 切换
- SFX 系统: 24种音效ID, 8通道并行播放
- 环境音支持
- 音量独立控制 (BGM/SFX/环境)
- 全局静音开关
- 自动响应 EventBus 信号切换音乐 (威胁值≥60→紧张BGM)
- 设置持久化 (Save/Load)

### 设置面板 (新增)

**settings_panel.gd + settings_panel.tscn**:
- BGM/SFX/环境音量滑块
- 静音切换
- 教程开关
- 边缘滚动开关
- ESC键打开/关闭

### 教程系统 (新增)

**tutorial_manager.gd** — 引导式新手教程:
- 13步教程流程: 欢迎→阵营→地图→军团→招募→进攻→战斗→经济→秩序/威胁→外交→胜利条件
- 事件触发机制: 根据游戏进度自动推进
- 半透明覆盖层 + 弹出面板
- 跳过/继续按钮
- 教程状态持久化 (Save/Load)

### 地图可视化改进

**board.gd**:
- 移除调试大方块 (debug cube)
- 新增环境粒子系统: 20个浮动光点 (Tween动画, 不依赖 GPUParticles)
- 新增小地图接口: `setup_minimap()` (SubViewport + 俯视Camera)
- 新增领地脉冲动画: `pulse_tile()` (占领/失去时闪烁效果)

### 项目配置更新

**project.godot**:
- 新增 Autoload: AudioManager, TutorialManager

**main.tscn**:
- 新增子场景: CombatView, SettingsPanel

**main.gd**:
- 版本升级至 v1.5
- 集成战斗视图: `show_combat_view()` + 关闭回调
- 集成教程: 游戏开始时启动教程
- ESC键打开设置面板

**event_bus.gd**:
- 新增信号: bgm_changed, sfx_requested, tutorial_step, tutorial_completed
- 新增信号: combat_view_requested, combat_view_closed
- 新增信号: settings_opened, settings_closed

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
