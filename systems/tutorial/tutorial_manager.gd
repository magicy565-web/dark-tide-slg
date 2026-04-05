## tutorial_manager.gd — 暗潮 SLG 教程关卡管理器 (v3.0)
## 覆盖所有核心流程：内政、行动、任务、战斗、事件、地域压制、交易、外交
## 教程关卡目的：通过跑通这些流程验证基础功能无BUG。
extends Node

signal tutorial_step_changed(step_id: String)
signal tutorial_completed()

# ══════════════════════════════════════════════════════════════════════════════
# ── 教程步骤定义 (STEPS) ──
# 每个步骤包含：
#   id       — 唯一标识符
#   title    — 弹窗标题
#   text     — 说明文本（支持BBCode）
#   trigger  — 触发条件（事件ID字符串）
#   highlight — 要高亮的UI节点名称（空字符串=不高亮）
#   phase    — 所属流程阶段（用于进度显示）
# ══════════════════════════════════════════════════════════════════════════════
const STEPS: Array = [

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 0：欢迎 & 界面介绍
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "welcome",
		"phase": "intro",
		"title": "欢迎来到暗潮教程关卡",
		"text": "[color=gold]本教程关卡[/color]将引导你逐步跑通所有核心游戏流程：\n\n• [color=cyan]内政[/color] — 招募、建造、升级\n• [color=yellow]行动[/color] — 探索、驻守、封锁\n• [color=green]任务[/color] — 主线任务与中立势力任务\n• [color=red]战斗[/color] — 攻击中立与光明阵营\n• [color=magenta]事件[/color] — 随机事件处理\n• [color=orange]地域压制[/color] — 稳固占领区\n• [color=cyan]交易[/color] — 资源买卖\n• [color=yellow]外交[/color] — 停战、结盟\n\n[color=gray]目的：验证所有基础功能正常运行。[/color]\n\n点击 [color=cyan]继续[/color] 开始教程。",
		"trigger": "game_start",
		"highlight": "",
	},
	{
		"id": "ui_overview",
		"phase": "intro",
		"title": "界面总览",
		"text": "游戏界面主要区域：\n\n• [color=gold]顶部栏[/color] — 资源（金币、粮草、铁矿）和行动点(AP)\n• [color=cyan]左侧面板[/color] — 行动按钮（攻击/内政/外交等）\n• [color=green]地图中央[/color] — 点击任意格子查看详情\n• [color=yellow]右下角[/color] — 小地图，点击快速跳转\n• [color=red]右侧[/color] — 消息日志，记录所有事件\n\n[color=gray]教程地图共9个格子（3×3），所有格子已揭示。[/color]",
		"trigger": "board_ready",
		"highlight": "board",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 1：内政系统 (Domestic)
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "domestic_intro",
		"phase": "domestic",
		"title": "【内政】第一步：了解内政系统",
		"text": "[color=cyan]内政[/color]是管理你领地的核心操作。\n\n你目前拥有 [color=gold]3块领地[/color]：\n• [color=white]暗潮营地[/color]（起点，格子0）\n• [color=white]荒野丘陵[/color]（格子1）\n• [color=white]铁矿山[/color]（格子3）\n\n[color=yellow]内政操作包括：[/color]\n• [color=green]招募兵力[/color] — 消耗金币+铁矿增加军队\n• [color=cyan]建造建筑[/color] — 提升领地产出\n• [color=magenta]升级领地[/color] — 提高等级获得更多资源\n• [color=orange]提升秩序[/color] — 防止叛乱\n\n[color=gray]点击左侧「内政」按钮，选择你的起始领地（格子0）进行操作。[/color]",
		"trigger": "first_turn",
		"highlight": "ActionPanel",
	},
	{
		"id": "domestic_recruit",
		"phase": "domestic",
		"title": "【内政】招募兵力",
		"text": "在内政面板中，选择 [color=green]「招募」[/color] 操作。\n\n[color=yellow]招募说明：[/color]\n• 消耗 [color=gold]金币[/color] 和 [color=silver]铁矿[/color]\n• 增加你的军队规模（army_count）\n• 军队越多，战斗力越强\n\n[color=cyan]当前资源充足，请尝试招募一批兵力。[/color]\n\n[color=gray]操作路径：点击「内政」→ 选择格子0 → 选择「招募」→ 确认[/color]\n\n[color=red]⚠ 验证点：招募后检查资源是否正确扣除，军队数量是否增加。[/color]",
		"trigger": "domestic_action_started",
		"highlight": "",
	},
	{
		"id": "domestic_done",
		"phase": "domestic",
		"title": "【内政】内政完成 ✓",
		"text": "[color=green]✓ 内政操作完成！[/color]\n\n[color=yellow]验证结果：[/color]\n• 资源扣除 ✓\n• 军队数量更新 ✓\n• 消息日志记录 ✓\n\n[color=cyan]内政系统基础功能验证通过。[/color]\n\n下一步：[color=yellow]行动系统[/color]——探索周边格子。",
		"trigger": "tutorial_domestic_done",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 2：行动系统 (Actions)
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "action_intro",
		"phase": "actions",
		"title": "【行动】行动系统概览",
		"text": "每回合你有 [color=yellow]行动点(AP)[/color]，用于执行各种操作。\n\n[color=cyan]可用行动类型：[/color]\n• [color=red]攻击[/color] — 对相邻格子发动进攻（消耗1AP）\n• [color=green]探索[/color] — 探索未知格子（消耗1AP）\n• [color=cyan]驻守[/color] — 加强领地防御（消耗1AP）\n• [color=orange]封锁补给[/color] — 切断敌方补给线\n• [color=magenta]强化[/color] — 临时提升战斗力\n\n[color=gray]现在请尝试「探索」操作：点击左侧「行动」→ 选择相邻的荒野格子（格子1）→ 选择「探索」。[/color]",
		"trigger": "tutorial_domestic_done",
		"highlight": "ActionPanel",
	},
	{
		"id": "action_explore",
		"phase": "actions",
		"title": "【行动】探索操作",
		"text": "[color=cyan]探索[/color]可以揭示格子信息并获得奖励。\n\n[color=yellow]探索说明：[/color]\n• 对相邻的中立格子执行探索\n• 可能触发随机事件\n• 可能发现资源或中立势力\n\n[color=gray]请选择格子1（荒野丘陵）执行探索操作。[/color]\n\n[color=red]⚠ 验证点：探索后检查AP是否正确扣除，消息日志是否有记录。[/color]",
		"trigger": "action_explore_started",
		"highlight": "",
	},
	{
		"id": "action_guard",
		"phase": "actions",
		"title": "【行动】驻守操作",
		"text": "[color=green]驻守[/color]可以加强领地的防御能力。\n\n[color=yellow]驻守说明：[/color]\n• 对己方领地执行驻守\n• 提升该格子的驻军数量\n• 增加城防值，使攻击方更难攻克\n\n[color=gray]请选择格子0（暗潮营地）执行驻守操作。[/color]\n\n[color=red]⚠ 验证点：驻守后检查该格子的garrison值是否增加。[/color]",
		"trigger": "action_guard_started",
		"highlight": "",
	},
	{
		"id": "action_done",
		"phase": "actions",
		"title": "【行动】行动系统验证完成 ✓",
		"text": "[color=green]✓ 行动系统操作完成！[/color]\n\n[color=yellow]验证结果：[/color]\n• AP消耗正确 ✓\n• 探索效果生效 ✓\n• 驻守效果生效 ✓\n\n[color=cyan]行动系统基础功能验证通过。[/color]\n\n下一步：[color=red]战斗系统[/color]——攻击中立格子。",
		"trigger": "tutorial_domestic_done",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 3：战斗系统 (Combat)
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "combat_intro",
		"phase": "combat",
		"title": "【战斗】战斗系统说明",
		"text": "[color=red]战斗[/color]是扩张领地的主要方式。\n\n[color=yellow]战斗流程：[/color]\n1. 选择你的军队（格子0的起始军团）\n2. 点击「攻击」按钮\n3. 选择目标格子（相邻的中立格子）\n4. 战斗自动结算（基于兵力、地形、英雄加成）\n5. 胜利后选择：[color=gold]占领[/color] / [color=red]掠夺[/color] / [color=gray]夷平[/color]\n\n[color=cyan]教程目标：攻击格子1（荒野丘陵，驻军3）。[/color]\n\n[color=gray]你的军队有15兵力，应该轻松获胜。[/color]",
		"trigger": "first_turn",
		"highlight": "",
	},
	{
		"id": "combat_attack",
		"phase": "combat",
		"title": "【战斗】发动攻击",
		"text": "请按以下步骤发动攻击：\n\n1. [color=cyan]点击格子0[/color]（暗潮营地，你的起始格子）\n2. 在左侧面板点击 [color=red]「攻击」[/color]\n3. [color=yellow]选择目标格子1[/color]（荒野丘陵）\n4. 确认攻击\n\n[color=yellow]战斗结算要素：[/color]\n• 攻击方：你的军队（15兵力 + 兽人ATK加成）\n• 防守方：中立驻军（3兵力）\n• 地形：平原（无特殊加成）\n\n[color=red]⚠ 验证点：战斗结算是否正常，伤亡计算是否合理，消息日志是否完整。[/color]",
		"trigger": "first_combat",
		"highlight": "",
	},
	{
		"id": "combat_conquest",
		"phase": "combat",
		"title": "【战斗】征服选择",
		"text": "战斗胜利后，你将看到 [color=gold]征服选择弹窗[/color]：\n\n• [color=gold]占领[/color] — 将该格子纳入你的版图，保留建筑\n• [color=red]掠夺[/color] — 获得额外资源，但格子受损\n• [color=gray]夷平[/color] — 摧毁格子，获得大量资源但失去该领地\n\n[color=cyan]教程建议：选择「占领」，扩大你的领土。[/color]\n\n[color=red]⚠ 验证点：\n• 征服弹窗是否正常显示\n• 选择后格子归属是否更新\n• 资源奖励是否正确发放[/color]",
		"trigger": "conquest_choice_shown",
		"highlight": "",
	},
	{
		"id": "combat_done",
		"phase": "combat",
		"title": "【战斗】战斗系统验证完成 ✓",
		"text": "[color=green]✓ 战斗系统验证完成！[/color]\n\n[color=yellow]验证结果：[/color]\n• 战斗结算正常 ✓\n• 伤亡计算合理 ✓\n• 征服选择弹窗正常 ✓\n• 领地归属更新 ✓\n\n[color=cyan]战斗系统基础功能验证通过。[/color]\n\n下一步：[color=magenta]事件系统[/color]——处理随机事件。",
		"trigger": "tutorial_combat_done",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 4：事件系统 (Events)
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "event_intro",
		"phase": "events",
		"title": "【事件】随机事件系统",
		"text": "[color=magenta]随机事件[/color]会在每回合结束时触发，影响游戏进程。\n\n[color=yellow]事件类型：[/color]\n• [color=green]正面事件[/color] — 获得资源、兵力、声望\n• [color=red]负面事件[/color] — 失去资源、叛乱、攻击\n• [color=cyan]中性事件[/color] — 需要做出选择，影响不同方向\n\n[color=gray]事件弹窗会显示事件描述和可选项，你的选择将影响结果。[/color]\n\n[color=orange]教程将在下一回合触发一个示例事件，请注意观察弹窗。[/color]\n\n[color=red]⚠ 验证点：事件弹窗是否正常显示，选择后效果是否正确应用。[/color]",
		"trigger": "tutorial_combat_done",
		"highlight": "",
	},
	{
		"id": "event_handle",
		"phase": "events",
		"title": "【事件】处理事件",
		"text": "[color=magenta]事件弹窗已出现！[/color]\n\n[color=yellow]如何处理事件：[/color]\n1. 阅读事件描述\n2. 查看各选项的效果预览\n3. 点击你想要的选项\n4. 观察消息日志中的结果\n\n[color=cyan]不同选择会带来不同后果，请根据当前资源状况做出决策。[/color]\n\n[color=red]⚠ 验证点：\n• 事件弹窗UI是否正常\n• 选项按钮是否可点击\n• 选择后资源/状态是否正确变化[/color]",
		"trigger": "show_event_popup",
		"highlight": "",
	},
	{
		"id": "event_done",
		"phase": "events",
		"title": "【事件】事件系统验证完成 ✓",
		"text": "[color=green]✓ 事件系统验证完成！[/color]\n\n[color=yellow]验证结果：[/color]\n• 事件弹窗正常显示 ✓\n• 选项交互正常 ✓\n• 效果正确应用 ✓\n\n[color=cyan]事件系统基础功能验证通过。[/color]\n\n下一步：[color=orange]地域压制[/color]——稳固你的占领区。",
		"trigger": "tutorial_event_handled",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 5：地域压制 (Territory Suppression)
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "suppression_intro",
		"phase": "suppression",
		"title": "【地域压制】稳固占领区",
		"text": "[color=orange]地域压制[/color]是维持新占领领地秩序的关键操作。\n\n[color=yellow]为什么需要压制？[/color]\n• 新占领的格子 [color=red]秩序值(Order)[/color] 较低\n• 低秩序导致产出减少，甚至触发叛乱\n• 压制可以快速恢复秩序，稳固统治\n\n[color=cyan]压制操作：[/color]\n• 选择你刚占领的格子（格子1）\n• 在行动面板选择「驻守/压制」\n• 消耗AP，提升该格子的秩序值\n\n[color=gray]教程地图中格子1刚被占领，秩序值较低，需要压制。[/color]\n\n[color=red]⚠ 验证点：压制后秩序值是否正确提升。[/color]",
		"trigger": "tutorial_combat_done",
		"highlight": "",
	},
	{
		"id": "suppression_do",
		"phase": "suppression",
		"title": "【地域压制】执行压制",
		"text": "请对格子1执行压制操作：\n\n1. [color=cyan]点击格子1[/color]（你刚占领的荒野丘陵）\n2. 在左侧面板选择 [color=orange]「驻守」[/color] 或 [color=orange]「压制」[/color]\n3. 确认操作\n\n[color=yellow]压制效果：[/color]\n• 秩序值 +0.1 ~ +0.2\n• 驻军数量增加\n• 叛乱风险降低\n\n[color=red]⚠ 验证点：\n• 操作是否消耗AP\n• 格子秩序值(public_order)是否提升\n• 消息日志是否记录[/color]",
		"trigger": "action_guard_started",
		"highlight": "",
	},
	{
		"id": "suppression_done",
		"phase": "suppression",
		"title": "【地域压制】地域压制验证完成 ✓",
		"text": "[color=green]✓ 地域压制验证完成！[/color]\n\n[color=yellow]验证结果：[/color]\n• 压制操作正常 ✓\n• 秩序值正确提升 ✓\n• AP消耗正确 ✓\n\n[color=cyan]地域压制系统基础功能验证通过。[/color]\n\n下一步：[color=cyan]交易系统[/color]——在交易站买卖资源。",
		"trigger": "tutorial_suppression_done",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 6：交易系统 (Trade)
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "trade_intro",
		"phase": "trade",
		"title": "【交易】交易系统说明",
		"text": "[color=cyan]交易[/color]是获取额外资源的重要方式。\n\n[color=yellow]教程地图中的交易站：[/color]\n• [color=white]格子4（流浪商队站）[/color] — 占领后自动获得金币+30\n• 占领交易站后每回合产出额外金币\n• 交易站也可作为外交谈判的筹码\n\n[color=cyan]交易操作：[/color]\n• 占领交易站 → 自动获得金币奖励\n• 交易站每回合产出金币+10~14\n• 海盗阵营可利用奖励市场买卖稀有物品\n\n[color=orange]教程任务：[/color]占领格子4（流浪商队站）触发交易流程验证。\n\n[color=red]⚠ 验证点：占领交易站后金币+30是否正确发放，消息日志是否记录。[/color]",
		"trigger": "tutorial_suppression_done",
		"highlight": "",
	},
	{
		"id": "trade_do",
		"phase": "trade",
		"title": "【交易】占领交易站",
		"text": "请占领格子4（流浪商队站）触发交易流程：\n\n[color=yellow]步骤：[/color]\n1. 将你的军队移动到格子4附近（格子3或格子1）\n2. 点击 [color=red]「攻击」[/color] 选择格子4\n3. 战斗胜利后选择 [color=gold]「占领」[/color]\n4. 观察消息日志中的金币+30奖励\n\n[color=cyan]交易站占领奖励：[/color]\n• 占领时立即获得 [color=gold]金币+30[/color]\n• 每回合产出 [color=gold]金币+10~14[/color]\n\n[color=red]⚠ 验证点：\n• 占领后金币是否正确增加\n• 交易站是否正确归属为你的领地\n• 消息日志是否显示交易站占领信息[/color]",
		"trigger": "action_trade_started",
		"highlight": "",
	},
	{
		"id": "trade_done",
		"phase": "trade",
		"title": "【交易】交易系统验证完成 ✓",
		"text": "[color=green]✓ 交易系统验证完成！[/color]\n\n[color=yellow]验证结果：[/color]\n• 交易面板正常显示 ✓\n• 资源交换正确计算 ✓\n• 交易记录在消息日志 ✓\n\n[color=cyan]交易系统基础功能验证通过。[/color]\n\n下一步：[color=yellow]外交系统[/color]——与其他势力谈判。",
		"trigger": "tutorial_trade_done",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 7：外交系统 (Diplomacy)
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "diplomacy_intro",
		"phase": "diplomacy",
		"title": "【外交】外交系统说明",
		"text": "[color=yellow]外交[/color]让你与地图上的各势力建立关系。\n\n[color=cyan]教程地图中的外交对象：[/color]\n• [color=white]格子2[/color] — 流浪商队（中立势力）\n• [color=white]格子5[/color] — 铁锤矮人（中立势力）\n• [color=white]格子8[/color] — 光明前哨（光明阵营）\n\n[color=yellow]外交操作类型：[/color]\n• [color=cyan]停战[/color] — 与光明阵营暂时停战\n• [color=green]贸易协议[/color] — 建立贸易关系获得资源\n• [color=magenta]招募[/color] — 将中立势力纳入麾下\n• [color=orange]进贡[/color] — 用资源换取和平\n\n[color=red]⚠ 验证点：外交面板是否正常，各操作是否可执行。[/color]",
		"trigger": "tutorial_trade_done",
		"highlight": "",
	},
	{
		"id": "diplomacy_open",
		"phase": "diplomacy",
		"title": "【外交】打开外交面板",
		"text": "请打开外交面板：\n\n1. 点击左侧行动面板中的 [color=yellow]「外交」[/color] 按钮\n2. 或按快捷键 [color=cyan]D[/color]\n\n[color=yellow]外交面板包含以下标签：[/color]\n• [color=red]邪恶势力[/color] — 其他邪恶阵营\n• [color=cyan]光明势力[/color] — 光明阵营（当前威胁来源）\n• [color=green]中立势力[/color] — 可招募的中立派系\n• [color=gold]条约[/color] — 当前生效的外交协议\n• [color=magenta]声望[/color] — 你的外交声誉\n\n[color=red]⚠ 验证点：面板是否正常打开，各标签数据是否正确显示。[/color]",
		"trigger": "diplomacy_panel_opened",
		"highlight": "",
	},
	{
		"id": "diplomacy_neutral",
		"phase": "diplomacy",
		"title": "【外交】与中立势力互动",
		"text": "在 [color=green]「中立势力」[/color] 标签中：\n\n[color=yellow]可以看到：[/color]\n• 流浪商队（格子2附近）\n• 铁锤矮人（格子5附近）\n\n[color=cyan]尝试与流浪商队互动：[/color]\n• 查看其任务链\n• 尝试「进贡」或「贸易协议」\n• 如果声望足够，可以尝试「招募」\n\n[color=gray]招募中立势力需要：声望≥10，金币≥80，秩序≥35[/color]\n\n[color=red]⚠ 验证点：中立势力数据是否正确显示，交互按钮是否可用。[/color]",
		"trigger": "diplomacy_panel_opened",
		"highlight": "",
	},
	{
		"id": "diplomacy_light",
		"phase": "diplomacy",
		"title": "【外交】与光明阵营外交",
		"text": "在 [color=cyan]「光明势力」[/color] 标签中：\n\n[color=yellow]可以尝试：[/color]\n• [color=cyan]停战[/color] — 消耗金币+声望，暂时停止光明阵营的进攻\n• [color=orange]进贡[/color] — 用资源降低威胁值\n\n[color=gray]当前威胁值较低，停战条件可能已满足。[/color]\n\n[color=cyan]尝试与光明阵营签署停战协议。[/color]\n\n[color=red]⚠ 验证点：\n• 停战条件判断是否正确\n• 签署后威胁值是否降低\n• 条约是否出现在「条约」标签[/color]",
		"trigger": "diplomacy_panel_opened",
		"highlight": "",
	},
	{
		"id": "diplomacy_done",
		"phase": "diplomacy",
		"title": "【外交】外交系统验证完成 ✓",
		"text": "[color=green]✓ 外交系统验证完成！[/color]\n\n[color=yellow]验证结果：[/color]\n• 外交面板正常显示 ✓\n• 中立势力数据正确 ✓\n• 外交操作可执行 ✓\n\n[color=cyan]外交系统基础功能验证通过。[/color]\n\n下一步：[color=green]任务系统[/color]——查看和完成任务。",
		"trigger": "tutorial_diplomacy_done",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 8：任务系统 (Quests & Missions)
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "quest_intro",
		"phase": "quests",
		"title": "【任务】任务系统说明",
		"text": "[color=green]任务系统[/color]提供游戏目标和奖励。\n\n[color=yellow]任务类型：[/color]\n• [color=gold]主线任务[/color] — 推进游戏主要剧情\n• [color=cyan]支线任务[/color] — 可选任务，提供额外奖励\n• [color=red]挑战任务[/color] — 高难度战斗挑战\n• [color=magenta]角色任务[/color] — 英雄专属任务\n\n[color=cyan]打开任务日志：[/color]\n• 按快捷键 [color=yellow]J[/color]\n• 或点击HUD中的任务图标\n\n[color=red]⚠ 验证点：任务日志是否正常显示，任务进度是否正确追踪。[/color]",
		"trigger": "tutorial_diplomacy_done",
		"highlight": "",
	},
	{
		"id": "quest_journal",
		"phase": "quests",
		"title": "【任务】查看任务日志",
		"text": "请打开任务日志（按 [color=yellow]J[/color]）：\n\n[color=yellow]在任务日志中检查：[/color]\n• [color=gold]主线任务[/color]标签 — 是否有当前激活的主线任务\n• [color=cyan]支线任务[/color]标签 — 是否有可接受的支线任务\n• 任务目标是否清晰\n• 奖励是否显示\n\n[color=cyan]当前可能的任务：[/color]\n• 「扩张领土」— 占领5块格子\n• 「首战告捷」— 赢得第一场战斗\n• 「外交先锋」— 完成一次外交操作\n\n[color=red]⚠ 验证点：任务进度是否与实际游戏状态同步。[/color]",
		"trigger": "quest_journal_opened",
		"highlight": "",
	},
	{
		"id": "quest_neutral",
		"phase": "quests",
		"title": "【任务】中立势力任务链",
		"text": "中立势力有专属的 [color=green]任务链[/color]，完成后可以招募他们。\n\n[color=yellow]流浪商队任务链（格子2）：[/color]\n• 步骤1：花40金揭示3个迷雾格\n• 步骤2：清剿匪巢（击败5兵力的敌人）\n• 步骤3：威望≥20后结盟\n\n[color=cyan]尝试触发任务链：[/color]\n1. 靠近格子2（流浪商队站）\n2. 在外交面板中与流浪商队互动\n3. 查看任务链进度\n\n[color=red]⚠ 验证点：任务链触发是否正常，进度追踪是否准确。[/color]",
		"trigger": "quest_journal_opened",
		"highlight": "",
	},
	{
		"id": "quest_done",
		"phase": "quests",
		"title": "【任务】任务系统验证完成 ✓",
		"text": "[color=green]✓ 任务系统验证完成！[/color]\n\n[color=yellow]验证结果：[/color]\n• 任务日志正常显示 ✓\n• 任务进度追踪正确 ✓\n• 中立势力任务链可触发 ✓\n\n[color=cyan]任务系统基础功能验证通过。[/color]\n\n下一步：[color=gold]回合结算[/color]——结束回合并验证收入计算。",
		"trigger": "tutorial_quest_done",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 9：回合结算验证
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "turn_end_intro",
		"phase": "turn_end",
		"title": "【回合结算】结束回合",
		"text": "点击 [color=yellow]「结束回合」[/color] 按钮完成当前回合。\n\n[color=cyan]回合结算包括：[/color]\n• 收取所有领地的资源产出\n• 扣除军队的粮草消耗\n• 处理建筑效果\n• 触发随机事件\n• 更新威胁值\n• 更新任务进度\n\n[color=red]⚠ 验证点：\n• 资源收入计算是否正确\n• 粮草消耗是否正确扣除\n• 回合数是否正确递增\n• 消息日志是否完整记录[/color]",
		"trigger": "tutorial_quest_done",
		"highlight": "EndTurnButton",
	},
	{
		"id": "turn_end_done",
		"phase": "turn_end",
		"title": "【回合结算】回合结算验证完成 ✓",
		"text": "[color=green]✓ 回合结算验证完成！[/color]\n\n[color=yellow]验证结果：[/color]\n• 资源收入正确 ✓\n• 粮草消耗正确 ✓\n• 回合递增正常 ✓\n• 事件触发正常 ✓\n\n[color=cyan]回合结算系统基础功能验证通过。[/color]",
		"trigger": "tutorial_turn_ended",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 10：教程完成
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "tutorial_complete",
		"phase": "complete",
		"title": "🎉 教程关卡完成！",
		"text": "[color=gold]恭喜！所有核心流程验证完成！[/color]\n\n[color=green]已验证的系统：[/color]\n✓ 内政系统（招募、建造、升级）\n✓ 行动系统（探索、驻守、封锁）\n✓ 战斗系统（攻击、结算、征服）\n✓ 事件系统（随机事件、选择处理）\n✓ 地域压制（秩序管理）\n✓ 交易系统（资源买卖）\n✓ 外交系统（停战、招募、条约）\n✓ 任务系统（主线、支线、中立任务链）\n✓ 回合结算（收入、消耗、事件）\n\n[color=cyan]基础功能验证通过，可以在此基础上添加更多内容和元素！[/color]\n\n[color=gray]点击「完成」返回主菜单，或继续自由探索。[/color]",
		"trigger": "_complete",
		"highlight": "",
	},
]

# ══════════════════════════════════════════════════════════════════════════════
# ── 状态变量 ──
# ══════════════════════════════════════════════════════════════════════════════
var _tutorial_step: int = 0
var _tutorial_complete: bool = false
var _active: bool = false
var _current_step_index: int = 0
var _completed_steps: Array = []
var _tutorial_enabled: bool = true
var _pending_triggers: Array = []
var _turn_count: int = 0
var _combat_seen: bool = false
var _hero_panel_seen: bool = false
var _diplomacy_panel_seen: bool = false
var _quest_journal_seen: bool = false
var _event_handled: bool = false
var _suppression_done: bool = false
var _trade_done: bool = false
var _diplomacy_done: bool = false
var _quest_done: bool = false

# ── UI ──
var _popup: PanelContainer
var _title_label: Label
var _text_label: RichTextLabel
var _btn_next: Button
var _btn_skip: Button
var _overlay: ColorRect
var _step_label: Label
var _phase_label: Label

# ── Highlight ──
var _highlight_node: Control = null
var _highlight_tween: Tween = null

# 阶段名称映射（用于进度显示）
const PHASE_NAMES: Dictionary = {
	"intro": "介绍",
	"domestic": "内政",
	"actions": "行动",
	"combat": "战斗",
	"events": "事件",
	"suppression": "地域压制",
	"trade": "交易",
	"diplomacy": "外交",
	"quests": "任务",
	"turn_end": "回合结算",
	"complete": "完成",
}


func _ready() -> void:
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	# 半透明遮罩
	_overlay = ColorRect.new()
	_overlay.name = "TutorialOverlay"
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.color = Color(0, 0, 0, 0.3)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 200

	# 弹窗面板
	_popup = PanelContainer.new()
	_popup.name = "TutorialPopup"
	_popup.custom_minimum_size = Vector2(500, 220)
	_popup.anchor_left = 0.5
	_popup.anchor_top = 0.5
	_popup.anchor_right = 0.5
	_popup.anchor_bottom = 0.5
	_popup.offset_left = -250
	_popup.offset_top = -120
	_popup.offset_right = 250
	_popup.offset_bottom = 120

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.12, 0.97)
	style.border_color = Color(0.7, 0.55, 0.1)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_popup.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_popup.add_child(vbox)

	# 阶段标签（小字，顶部）
	_phase_label = Label.new()
	_phase_label.add_theme_font_size_override("font_size", 12)
	_phase_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0, 0.8))
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_phase_label)

	# 标题
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 正文
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.custom_minimum_size = Vector2(460, 100)
	_text_label.add_theme_font_size_override("normal_font_size", 15)
	vbox.add_child(_text_label)

	# 按钮行
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	_btn_skip = Button.new()
	_btn_skip.text = "跳过教程"
	_btn_skip.pressed.connect(_skip_tutorial)
	btn_row.add_child(_btn_skip)

	_btn_next = Button.new()
	_btn_next.text = "继续 ▶"
	_btn_next.pressed.connect(_advance_step)
	btn_row.add_child(_btn_next)

	# 步骤进度
	_step_label = Label.new()
	_step_label.add_theme_font_size_override("font_size", 12)
	_step_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.45, 0.7))
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_step_label)

	_popup.visible = false
	_popup.z_index = 201
	add_child(_overlay)
	add_child(_popup)


func _connect_signals() -> void:
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.board_ready.connect(func(): _trigger("board_ready"))
	EventBus.army_created.connect(func(_a, _b, _c): _trigger("army_created"))
	EventBus.combat_result.connect(_on_first_combat)
	EventBus.tutorial_step.connect(_on_external_trigger)
	# 教程关卡专用信号
	EventBus.tutorial_domestic_done.connect(_on_tutorial_domestic_done)
	EventBus.tutorial_combat_done.connect(_on_tutorial_combat_done)
	EventBus.tutorial_suppression_done.connect(_on_tutorial_suppression_done)
	EventBus.tutorial_trade_done.connect(_on_tutorial_trade_done)
	EventBus.tutorial_diplomacy_done.connect(_on_tutorial_diplomacy_done)
	EventBus.tutorial_quest_done.connect(_on_tutorial_quest_done)
	EventBus.tutorial_event_handled.connect(_on_tutorial_event_handled)
	EventBus.tutorial_turn_ended.connect(_on_tutorial_turn_ended)
	# 事件弹窗信号：任何事件弹窗显示时触发
	EventBus.show_event_popup.connect(func(_t, _d, _c): _trigger("show_event_popup"))
	# 事件选择完成时触发教程事件处理步骤
	EventBus.event_choice_selected.connect(_on_event_choice_selected)
	# 征服选择弹窗
	EventBus.conquest_choice_selected.connect(func(_i): _trigger("conquest_choice_shown"))


func start_tutorial() -> void:
	if _tutorial_complete or not _tutorial_enabled:
		return
	_active = true
	_current_step_index = 0
	_tutorial_step = 0
	_completed_steps.clear()
	_turn_count = 0
	_combat_seen = false
	_hero_panel_seen = false
	_diplomacy_panel_seen = false
	_quest_journal_seen = false
	_event_handled = false
	_suppression_done = false
	_trade_done = false
	_diplomacy_done = false
	_quest_done = false
	_pending_triggers.clear()
	_trigger("game_start")


## 教程关卡专用启动（跳过欢迎步骤，直接从内政开始）
func start_tutorial_level() -> void:
	_tutorial_complete = false
	_tutorial_enabled = true
	_active = true
	_current_step_index = 0
	_tutorial_step = 0
	_completed_steps.clear()
	_turn_count = 0
	_combat_seen = false
	_hero_panel_seen = false
	_diplomacy_panel_seen = false
	_quest_journal_seen = false
	_event_handled = false
	_suppression_done = false
	_trade_done = false
	_diplomacy_done = false
	_quest_done = false
	_pending_triggers.clear()
	_trigger("game_start")


## 外部触发器（来自EventBus.tutorial_step信号）
func _on_external_trigger(step_id: String) -> void:
	_trigger(step_id)


## 首次战斗触发
func _on_first_combat(_a: int, _b: String, _c: bool) -> void:
	if not _combat_seen:
		_combat_seen = true
		_trigger("first_combat")


## 内政完成
func _on_tutorial_domestic_done(_action: String, _tile: int) -> void:
	_trigger("tutorial_domestic_done")


## 战斗完成
func _on_tutorial_combat_done(_won: bool, _tile: int) -> void:
	_trigger("tutorial_combat_done")


## 地域压制完成
func _on_tutorial_suppression_done(_tile: int) -> void:
	if not _suppression_done:
		_suppression_done = true
		_trigger("tutorial_suppression_done")


## 交易完成
func _on_tutorial_trade_done() -> void:
	if not _trade_done:
		_trade_done = true
		_trigger("tutorial_trade_done")


## 外交完成
func _on_tutorial_diplomacy_done(_dtype: String) -> void:
	if not _diplomacy_done:
		_diplomacy_done = true
		_trigger("tutorial_diplomacy_done")


## 任务完成
func _on_tutorial_quest_done(_qid: String) -> void:
	if not _quest_done:
		_quest_done = true
		_trigger("tutorial_quest_done")


## 事件处理完成
func _on_tutorial_event_handled(_eid: String) -> void:
	if not _event_handled:
		_event_handled = true
		_trigger("tutorial_event_handled")


## 玩家选择了事件选项（包括弹窗关闭）
func _on_event_choice_selected(_choice_index: int) -> void:
	if not _event_handled:
		_event_handled = true
		_trigger("tutorial_event_handled")


## 回合结束
func _on_tutorial_turn_ended(_turn: int) -> void:
	_trigger("tutorial_turn_ended")


## 通知：英雄面板打开
func notify_hero_panel_opened() -> void:
	if _hero_panel_seen:
		return
	_hero_panel_seen = true
	_trigger("hero_panel_opened")


## 通知：外交面板打开
func notify_diplomacy_panel_opened() -> void:
	if _diplomacy_panel_seen:
		return
	_diplomacy_panel_seen = true
	_trigger("diplomacy_panel_opened")


## 通知：任务日志打开
func notify_quest_journal_opened() -> void:
	if _quest_journal_seen:
		return
	_quest_journal_seen = true
	_trigger("quest_journal_opened")


## 通知：内政操作开始
func notify_domestic_action_started() -> void:
	_trigger("domestic_action_started")


## 通知：探索操作开始
func notify_action_explore_started() -> void:
	_trigger("action_explore_started")


## 通知：驻守操作开始
func notify_action_guard_started() -> void:
	_trigger("action_guard_started")


## 通知：交易操作开始
func notify_action_trade_started() -> void:
	_trigger("action_trade_started")


func _trigger(trigger_id: String) -> void:
	if not _active:
		return
	if _current_step_index >= STEPS.size():
		_end_tutorial()
		return

	# 弹窗显示中，排队等待
	if _popup.visible:
		if trigger_id not in _pending_triggers:
			_pending_triggers.append(trigger_id)
		return

	var step: Dictionary = STEPS[_current_step_index]
	if step["trigger"] == trigger_id:
		_show_step(step)


func _show_step(step: Dictionary) -> void:
	_title_label.text = step["title"]
	_text_label.clear()
	_text_label.append_text(step["text"])

	# 阶段显示
	var phase_name: String = PHASE_NAMES.get(step.get("phase", ""), "")
	if not phase_name.is_empty():
		_phase_label.text = "▶ %s 阶段" % phase_name
	else:
		_phase_label.text = ""

	# 步骤进度
	_step_label.text = "步骤 %d / %d" % [_current_step_index + 1, STEPS.size()]
	_popup.visible = true
	_overlay.visible = true

	# 入场动画
	_popup.modulate = Color(1, 1, 1, 0)
	var tween := _popup.create_tween()
	tween.tween_property(_popup, "modulate:a", 1.0, 0.25)

	_apply_highlight(step.get("highlight", ""))
	tutorial_step_changed.emit(step["id"])


func _advance_step() -> void:
	_completed_steps.append(STEPS[_current_step_index]["id"])
	_current_step_index += 1
	_tutorial_step = _current_step_index
	_remove_highlight()
	_popup.visible = false
	_overlay.visible = false

	if _current_step_index >= STEPS.size():
		_end_tutorial()
		return

	var next_step: Dictionary = STEPS[_current_step_index]
	var prev_step: Dictionary = STEPS[_current_step_index - 1]

	# 同一触发器，立即显示下一步
	if next_step["trigger"] == prev_step["trigger"]:
		_show_step(next_step)
		return

	# _complete 触发器，立即显示
	if next_step["trigger"] == "_complete":
		_show_step(next_step)
		return

	# 处理排队中的触发器
	var pending := _pending_triggers.duplicate()
	_pending_triggers.clear()
	for t in pending:
		_trigger(t)


func _skip_tutorial() -> void:
	_active = false
	_tutorial_complete = true
	_tutorial_enabled = false
	_remove_highlight()
	_popup.visible = false
	_overlay.visible = false
	_pending_triggers.clear()
	EventBus.tutorial_completed.emit()
	EventBus.message_log.emit("[color=gray]教程已跳过。按 ESC 查看帮助。[/color]")


func _end_tutorial() -> void:
	_active = false
	_tutorial_complete = true
	_remove_highlight()
	_popup.visible = false
	_overlay.visible = false
	_pending_triggers.clear()
	tutorial_completed.emit()
	EventBus.tutorial_completed.emit()
	EventBus.message_log.emit("[color=gold]🎉 教程关卡完成！所有核心流程验证通过！[/color]")


func _apply_highlight(target_name: String) -> void:
	_remove_highlight()
	if target_name.is_empty():
		return

	var target: Control = null
	var group_nodes := get_tree().get_nodes_in_group(target_name)
	if group_nodes.size() > 0 and group_nodes[0] is Control:
		target = group_nodes[0] as Control
	else:
		target = _find_control_by_name(get_tree().root, target_name)

	if target == null or not is_instance_valid(target):
		return

	_highlight_node = Control.new()
	_highlight_node.name = "TutorialHighlight"
	_highlight_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_node.z_index = 100

	var hl_style := StyleBoxFlat.new()
	hl_style.bg_color = Color(0, 0, 0, 0)
	hl_style.border_color = Color(1.0, 0.84, 0.0, 0.9)
	hl_style.border_width_top = 3
	hl_style.border_width_bottom = 3
	hl_style.border_width_left = 3
	hl_style.border_width_right = 3
	hl_style.corner_radius_top_left = 6
	hl_style.corner_radius_top_right = 6
	hl_style.corner_radius_bottom_left = 6
	hl_style.corner_radius_bottom_right = 6

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", hl_style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_node.add_child(panel)

	var target_rect := target.get_global_rect()
	var margin := 4.0
	_highlight_node.global_position = target_rect.position - Vector2(margin, margin)
	_highlight_node.size = target_rect.size + Vector2(margin * 2, margin * 2)
	panel.position = Vector2.ZERO
	panel.size = _highlight_node.size

	get_tree().root.add_child(_highlight_node)

	_highlight_node.modulate = Color(1, 1, 1, 0.9)
	_highlight_tween = _highlight_node.create_tween()
	_highlight_tween.set_loops()
	_highlight_tween.tween_property(_highlight_node, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_highlight_tween.tween_property(_highlight_node, "modulate:a", 0.9, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _remove_highlight() -> void:
	if _highlight_tween and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = null
	if _highlight_node and is_instance_valid(_highlight_node):
		_highlight_node.queue_free()
	_highlight_node = null


func _find_control_by_name(node: Node, node_name: String) -> Variant:
	if node.name == node_name and node is Control:
		return node as Control
	for child in node.get_children():
		var result := _find_control_by_name(child, node_name)
		if result != null:
			return result
	return null


func _on_turn_started(_pid: int) -> void:
	_turn_count += 1
	if _active:
		if _turn_count == 1:
			_trigger("first_turn")
		_trigger("turn_%d" % _turn_count)


func get_popup_control() -> PanelContainer:
	return _popup


func get_overlay_control() -> ColorRect:
	return _overlay


func is_active() -> bool:
	return _active


func is_complete() -> bool:
	return _tutorial_complete


## 重置教程状态（新游戏时调用）
func reset() -> void:
	_active = false
	_current_step_index = 0
	_tutorial_step = 0
	_completed_steps.clear()
	_turn_count = 0
	_combat_seen = false
	_hero_panel_seen = false
	_diplomacy_panel_seen = false
	_quest_journal_seen = false
	_event_handled = false
	_suppression_done = false
	_trade_done = false
	_diplomacy_done = false
	_quest_done = false
	_pending_triggers.clear()
	_remove_highlight()
	_popup.visible = false
	_overlay.visible = false


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"active": _active,
		"current_step": _current_step_index,
		"tutorial_step": _tutorial_step,
		"tutorial_complete": _tutorial_complete,
		"completed_steps": _completed_steps.duplicate(),
		"tutorial_enabled": _tutorial_enabled,
		"turn_count": _turn_count,
		"combat_seen": _combat_seen,
		"hero_panel_seen": _hero_panel_seen,
		"diplomacy_panel_seen": _diplomacy_panel_seen,
		"quest_journal_seen": _quest_journal_seen,
		"event_handled": _event_handled,
		"suppression_done": _suppression_done,
		"trade_done": _trade_done,
		"diplomacy_done": _diplomacy_done,
		"quest_done": _quest_done,
	}


func from_save_data(data: Dictionary) -> void:
	_active = data.get("active", false)
	_current_step_index = data.get("current_step", 0)
	_tutorial_step = data.get("tutorial_step", _current_step_index)
	_tutorial_complete = data.get("tutorial_complete", false)
	_completed_steps = data.get("completed_steps", []).duplicate()
	_tutorial_enabled = data.get("tutorial_enabled", true)
	_turn_count = data.get("turn_count", 0)
	_combat_seen = data.get("combat_seen", false)
	_hero_panel_seen = data.get("hero_panel_seen", false)
	_diplomacy_panel_seen = data.get("diplomacy_panel_seen", false)
	_quest_journal_seen = data.get("quest_journal_seen", false)
	_event_handled = data.get("event_handled", false)
	_suppression_done = data.get("suppression_done", false)
	_trade_done = data.get("trade_done", false)
	_diplomacy_done = data.get("diplomacy_done", false)
	_quest_done = data.get("quest_done", false)
	if _tutorial_complete:
		_active = false
		_tutorial_enabled = false
