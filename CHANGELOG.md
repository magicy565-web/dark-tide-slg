# 《暗潮 Dark Tide》更新日志

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
