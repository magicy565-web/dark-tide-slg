## pirate_onboarding.gd — 海盗阵营初始任务引导系统
##
## 当玩家选择海盗阵营开始游戏时自动激活，通过弹窗步骤逐步引导玩家
## 解锁并体验海盗阵营的所有特色功能。
##
## 与 TutorialManager 的区别：
##   - TutorialManager 是教程关卡（验证功能）的引导，适用于所有阵营
##   - PirateOnboarding 是正式游戏中海盗阵营的新手引导，专注于海盗机制
##
## 架构：
##   - 复用 TutorialManager 的弹窗 UI 样式（独立弹窗节点）
##   - 通过 EventBus 信号监听游戏事件自动推进步骤
##   - 在 QuestJournal 中追踪引导任务进度
##
## Autoload: PirateOnboarding (res://systems/tutorial/pirate_onboarding.gd)
extends CanvasLayer

# ══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ══════════════════════════════════════════════════════════════════════════════

signal onboarding_step_changed(step_id: String)
signal onboarding_completed()

# ══════════════════════════════════════════════════════════════════════════════
# CONSTANTS — 引导步骤定义
# ══════════════════════════════════════════════════════════════════════════════

## PHASE_NAMES: 阶段名称映射（用于弹窗顶部进度显示）
const PHASE_NAMES: Dictionary = {
	"intro":       "欢迎",
	"plunder":     "掠夺经济",
	"black_market":"黑市交易",
	"rum":         "朗姆酒士气",
	"treasure":    "藏宝图",
	"smuggle":     "走私航线",
	"infamy":      "恶名系统",
	"mercenary":   "雇佣兵",
	"hero":        "英雄解锁",
	"harbor":      "港口控制",
	"challenge":   "传奇之路",
}

## STEPS: 引导步骤序列
## 每个步骤包含：
##   id        — 唯一标识符（对应 pirate_quest_guide.gd 中的 guide quest id）
##   phase     — 所属阶段（用于进度显示）
##   title     — 弹窗标题
##   text      — 说明文本（支持 BBCode）
##   trigger   — 自动推进触发条件（事件名称，空字符串=手动点击继续）
##   highlight — 要高亮的 UI 节点路径（空字符串=不高亮）
const STEPS: Array = [

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 0：欢迎 & 海盗阵营介绍
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "pirate_welcome",
		"phase": "intro",
		"title": "⚓ 欢迎加入暗黑海盗！",
		"text": (
			"[color=gold]暗黑海盗[/color]是一个以[color=cyan]金币为王[/color]的中间势力，"
			"在光明与黑暗阵营之间游走，以掠夺和贸易积累财富。\n\n"
			"[color=yellow]海盗阵营特色机制：[/color]\n"
			"• [color=gold]掠夺经济[/color] — 战斗胜利获得大量金币\n"
			"• [color=orange]黑市交易[/color] — 购买走私商品和稀有道具\n"
			"• [color=orange]朗姆酒士气[/color] — 提升全军战斗力\n"
			"• [color=yellow]藏宝图[/color] — 探索隐藏宝藏\n"
			"• [color=cyan]走私航线[/color] — 被动金币收入\n"
			"• [color=red]恶名系统[/color] — 影响外交与雇佣费用\n"
			"• [color=magenta]雇佣兵[/color] — 用金币快速扩充兵力\n\n"
			"[color=gray]本引导将逐步带你体验以上所有功能。点击「继续」开始！[/color]"
		),
		"trigger": "",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 1：掠夺经济
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "pirate_plunder_intro",
		"phase": "plunder",
		"title": "【掠夺】海盗的生存之道",
		"text": (
			"[color=gold]掠夺[/color]是海盗阵营的核心收入来源！\n\n"
			"[color=yellow]掠夺机制说明：[/color]\n"
			"• 每次战斗胜利自动获得掠夺金币\n"
			"• 基础掠夺 = 敌方战力 × 3\n"
			"• [color=cyan]连续掠夺加成[/color]：每连续回合 +10% 掠夺收益\n"
			"• [color=red]高恶名加成[/color]：恶名 ≥70 时掠夺倍率 +0.3\n"
			"• 走私者巢穴建筑可额外提升 +0.5 掠夺倍率\n\n"
			"[color=orange]引导任务：[/color]赢得第一场战斗，获得掠夺金币！\n\n"
			"[color=gray]点击左侧「攻击」按钮，选择相邻的中立格子发动进攻。[/color]"
		),
		"trigger": "",
		"highlight": "ActionPanel",
	},
	{
		"id": "pirate_plunder_do",
		"phase": "plunder",
		"title": "【掠夺】发动第一次进攻",
		"text": (
			"[color=red]攻击步骤：[/color]\n"
			"1. 点击你的起始格子（暗黑港湾）\n"
			"2. 点击左侧 [color=red]「攻击」[/color] 按钮\n"
			"3. 选择相邻的中立格子作为目标\n"
			"4. 确认攻击，等待战斗结算\n\n"
			"[color=yellow]战斗胜利后你将看到：[/color]\n"
			"• 消息日志：「海盗掠夺！获得 XX 金」\n"
			"• 恶名值 +5\n"
			"• 15% 概率获得藏宝图\n\n"
			"[color=red]⚠ 验证点：掠夺金币是否正确发放，恶名是否上升。[/color]"
		),
		"trigger": "first_combat",
		"highlight": "",
	},
	{
		"id": "pirate_plunder_done",
		"phase": "plunder",
		"title": "【掠夺】掠夺成功 ✓",
		"text": (
			"[color=green]✓ 第一次掠夺完成！[/color]\n\n"
			"[color=yellow]已解锁功能：[/color]\n"
			"• 掠夺金币自动结算 ✓\n"
			"• 恶名值上升 ✓\n"
			"• 连续掠夺计数器已启动 ✓\n\n"
			"[color=cyan]引导任务「第一桶金」已完成，奖励 80 金已发放！[/color]\n\n"
			"下一步：[color=orange]黑市交易[/color] — 按 [P] 键打开海盗面板。"
		),
		"trigger": "pirate_combat_won",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 2：黑市交易
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "pirate_market_intro",
		"phase": "black_market",
		"title": "【黑市】海盗的秘密武器库",
		"text": (
			"[color=gold]黑市[/color]是海盗阵营的专属商店，"
			"每回合刷新 1~3 件商品（取决于黑市建筑等级）。\n\n"
			"[color=yellow]商品分类：[/color]\n"
			"• [color=red]武器类[/color] — 走私军火、黑火药、毒刃（提升战力）\n"
			"• [color=green]补给类[/color] — 朗姆酒桶、干粮包、铁锚碎片\n"
			"• [color=cyan]特殊类[/color] — 藏宝图、望远镜、海图\n"
			"• [color=magenta]消耗品[/color] — 烟雾弹、治疗药剂\n\n"
			"[color=orange]恶名影响价格：[/color]\n"
			"恶名 0 时享受 20% 折扣，恶名 100 时被加价 30%。\n\n"
			"[color=gray]按 [P] 键打开海盗面板，切换到「Black Market」标签。[/color]"
		),
		"trigger": "pirate_combat_won",
		"highlight": "",
	},
	{
		"id": "pirate_market_do",
		"phase": "black_market",
		"title": "【黑市】购买第一件商品",
		"text": (
			"[color=orange]操作步骤：[/color]\n"
			"1. 按 [color=cyan][P][/color] 键打开海盗面板\n"
			"2. 点击「[color=gold]Black Market[/color]」标签\n"
			"3. 查看当前商品（显示名称、描述、价格）\n"
			"4. 点击「[color=green]Buy[/color]」购买一件商品\n\n"
			"[color=yellow]推荐购买：[/color]\n"
			"• 「朗姆酒桶」— 士气 +15，为下一阶段做准备\n"
			"• 「藏宝图」— 获得宝藏线索\n"
			"• 「走私军火」— 战力 +15\n\n"
			"[color=red]⚠ 验证点：购买后金币是否正确扣除，商品效果是否生效。[/color]"
		),
		"trigger": "pirate_panel_opened",
		"highlight": "",
	},
	{
		"id": "pirate_market_done",
		"phase": "black_market",
		"title": "【黑市】黑市交易完成 ✓",
		"text": (
			"[color=green]✓ 黑市交易完成！[/color]\n\n"
			"[color=yellow]已解锁功能：[/color]\n"
			"• 黑市商品购买 ✓\n"
			"• 恶名影响价格计算 ✓\n"
			"• 商品效果应用 ✓\n\n"
			"[color=cyan]引导任务「黑市初体验」已完成，奖励 50 金已发放！[/color]\n\n"
			"下一步：[color=orange]朗姆酒士气[/color] — 将士气提升到 50 以上。"
		),
		"trigger": "pirate_market_bought",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 3：朗姆酒士气
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "pirate_rum_intro",
		"phase": "rum",
		"title": "【朗姆酒】船员士气系统",
		"text": (
			"[color=orange]朗姆酒士气[/color]（0~100）影响全军战斗加成：\n\n"
			"• 士气 0~49：无加成\n"
			"• 士气 50~89：[color=green]全军 ATK+2[/color]\n"
			"• 士气 90~100：[color=red]全军 ATK+4，但 DEF-2[/color]（醉酒作战）\n\n"
			"[color=yellow]士气来源：[/color]\n"
			"• 黑市购买「朗姆酒桶」：+15\n"
			"• 藏宝图奖励「陈年朗姆酒」：+30\n"
			"• 黑市稀有商品「龙血朗姆」：+40\n\n"
			"[color=red]士气每回合自然衰减 -5，需要持续补充！[/color]\n\n"
			"[color=gray]你的起始士气为 50，当前已激活 ATK+2 加成。[/color]"
		),
		"trigger": "pirate_market_bought",
		"highlight": "",
	},
	{
		"id": "pirate_rum_done",
		"phase": "rum",
		"title": "【朗姆酒】士气系统验证 ✓",
		"text": (
			"[color=green]✓ 朗姆酒士气系统已验证！[/color]\n\n"
			"[color=yellow]当前状态：[/color]\n"
			"• 士气值：显示在海盗面板顶部统计栏\n"
			"• 战斗加成：ATK+2（士气 ≥50）\n"
			"• 每回合衰减：-5\n\n"
			"[color=cyan]引导任务「朗姆酒的力量」已完成，奖励 60 金已发放！[/color]\n\n"
			"下一步：[color=yellow]藏宝图[/color] — 探索隐藏宝藏。"
		),
		"trigger": "pirate_rum_active",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 4：藏宝图探索
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "pirate_treasure_intro",
		"phase": "treasure",
		"title": "【藏宝图】寻宝系统",
		"text": (
			"[color=yellow]藏宝图[/color]是海盗阵营的专属福利，"
			"可以带来丰厚的随机奖励！\n\n"
			"[color=yellow]获取方式：[/color]\n"
			"• 战斗胜利后 [color=cyan]15% 概率[/color]自动掉落\n"
			"• 黑市购买「藏宝图」（50 金）\n"
			"• 黑市稀有商品「走私者地图」（×2）\n\n"
			"[color=yellow]奖励类型：[/color]\n"
			"• [color=gold]金币[/color] 50~200\n"
			"• [color=magenta]佣兵[/color] 5名\n"
			"• [color=pink]性奴隶[/color] 2名\n"
			"• [color=orange]朗姆酒[/color] +30 士气\n"
			"• [color=cyan]稀有道具[/color]\n\n"
			"[color=gray]在海盗面板「Treasure Hunt」标签中探索藏宝图。[/color]"
		),
		"trigger": "pirate_rum_active",
		"highlight": "",
	},
	{
		"id": "pirate_treasure_do",
		"phase": "treasure",
		"title": "【藏宝图】探索宝藏",
		"text": (
			"[color=orange]探索步骤：[/color]\n"
			"1. 确保你已获得至少 1 张藏宝图\n"
			"   （赢得战斗或黑市购买）\n"
			"2. 按 [color=cyan][P][/color] 键打开海盗面板\n"
			"3. 点击「[color=yellow]Treasure Hunt[/color]」标签\n"
			"4. 点击「[color=green]探索[/color]」按钮\n"
			"5. 查看奖励结果\n\n"
			"[color=red]⚠ 验证点：\n"
			"• 藏宝图数量是否正确减少\n"
			"• 奖励是否正确发放\n"
			"• 消息日志是否记录[/color]"
		),
		"trigger": "pirate_panel_opened",
		"highlight": "",
	},
	{
		"id": "pirate_treasure_done",
		"phase": "treasure",
		"title": "【藏宝图】寻宝完成 ✓",
		"text": (
			"[color=green]✓ 藏宝图探索完成！[/color]\n\n"
			"[color=yellow]已解锁功能：[/color]\n"
			"• 藏宝图掉落机制 ✓\n"
			"• 藏宝图探索奖励 ✓\n"
			"• 随机奖励类型覆盖 ✓\n\n"
			"[color=cyan]引导任务「寻宝猎人」已完成，奖励 100 金已发放！[/color]\n\n"
			"下一步：[color=cyan]走私航线[/color] — 建立被动收入。"
		),
		"trigger": "pirate_treasure_explored",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 5：走私航线
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "pirate_smuggle_intro",
		"phase": "smuggle",
		"title": "【走私】建立秘密航线",
		"text": (
			"[color=cyan]走私航线[/color]是海盗阵营的被动收入来源，"
			"每条航线每回合提供 [color=gold]+8 金币[/color]。\n\n"
			"[color=yellow]建立条件：[/color]\n"
			"• 选择你控制的两块领地作为航线端点\n"
			"• 最多同时维持 3 条走私航线\n"
			"• 若某端领地丢失，该航线自动中断\n\n"
			"[color=yellow]走私航线的额外价值：[/color]\n"
			"• 满足英雄「シャドウブレード」的解锁条件（≥2条）\n"
			"• 黑市商品「海图」可临时提升走私收入\n\n"
			"[color=gray]在海盗面板「Smuggle Routes」标签中建立航线。[/color]"
		),
		"trigger": "pirate_treasure_explored",
		"highlight": "",
	},
	{
		"id": "pirate_smuggle_do",
		"phase": "smuggle",
		"title": "【走私】建立第一条航线",
		"text": (
			"[color=orange]操作步骤：[/color]\n"
			"1. 确保你控制至少 2 块领地\n"
			"2. 按 [color=cyan][P][/color] 键打开海盗面板\n"
			"3. 点击「[color=cyan]Smuggle Routes[/color]」标签\n"
			"4. 选择两块领地作为航线端点\n"
			"5. 点击「[color=green]建立航线[/color]」\n\n"
			"[color=yellow]建立后每回合将看到：[/color]\n"
			"消息日志：「走私收入：+8 金（1条航线）」\n\n"
			"[color=red]⚠ 验证点：\n"
			"• 航线是否成功建立\n"
			"• 下回合是否自动结算走私收入\n"
			"• 消息日志是否记录[/color]"
		),
		"trigger": "pirate_panel_opened",
		"highlight": "",
	},
	{
		"id": "pirate_smuggle_done",
		"phase": "smuggle",
		"title": "【走私】走私航线建立 ✓",
		"text": (
			"[color=green]✓ 走私航线建立成功！[/color]\n\n"
			"[color=yellow]已解锁功能：[/color]\n"
			"• 走私航线被动收入 ✓\n"
			"• 航线有效性检查 ✓\n"
			"• 领地丢失时航线中断机制 ✓\n\n"
			"[color=cyan]引导任务「秘密航线」已完成，奖励 80 金已发放！[/color]\n\n"
			"下一步：[color=red]恶名系统[/color] — 提升你的海盗恶名。"
		),
		"trigger": "pirate_smuggle_established",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 6：恶名系统
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "pirate_infamy_intro",
		"phase": "infamy",
		"title": "【恶名】双刃剑系统",
		"text": (
			"[color=red]恶名[/color]（0~100）是海盗阵营的独特资源，"
			"影响外交、价格和英雄解锁：\n\n"
			"[color=yellow]恶名阈值效果：[/color]\n"
			"• 恶名 ≥70：[color=red]光明阵营拒绝交易[/color]\n"
			"• 恶名 ≥50：[color=green]掠夺倍率 +0.3，雇佣兵费用降低[/color]\n"
			"• 恶名 ≤30：[color=orange]黑暗阵营不信任你[/color]\n\n"
			"[color=yellow]恶名变化：[/color]\n"
			"• 战斗胜利 +5\n"
			"• 赎回性奴隶 -3\n"
			"• 交易 -2\n"
			"• 每回合自然衰减 -2\n\n"
			"[color=cyan]目标：将恶名提升到 50，解锁「サイレン」英雄！[/color]"
		),
		"trigger": "pirate_smuggle_established",
		"highlight": "",
	},
	{
		"id": "pirate_infamy_done",
		"phase": "infamy",
		"title": "【恶名】恶名系统验证 ✓",
		"text": (
			"[color=green]✓ 恶名已达到 50！[/color]\n\n"
			"[color=yellow]已解锁功能：[/color]\n"
			"• 恶名值追踪 ✓\n"
			"• 恶名影响掠夺倍率 ✓\n"
			"• 恶名影响雇佣兵费用 ✓\n"
			"• 恶名影响黑市价格 ✓\n\n"
			"[color=cyan]引导任务「恶名昭著」已完成，奖励 120 金 + 威望 10 已发放！[/color]\n\n"
			"[color=gold]英雄「サイレン」的加入条件已满足！[/color]\n\n"
			"下一步：[color=magenta]雇佣兵[/color] — 用金币快速扩军。"
		),
		"trigger": "pirate_infamy_50",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 7：雇佣兵
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "pirate_merc_intro",
		"phase": "mercenary",
		"title": "【雇佣兵】金币换兵力",
		"text": (
			"[color=magenta]雇佣兵[/color]是海盗阵营快速扩军的独特方式，"
			"[color=gold]只需金币[/color]，无需铁矿！\n\n"
			"[color=yellow]可雇佣兵种：[/color]\n"
			"• [color=white]佣兵剑士[/color] — ATK4/HP35，10人，30金\n"
			"• [color=green]佣兵弓手[/color] — ATK5/HP25，8人，35金\n"
			"• [color=silver]佣兵重甲[/color] — ATK3/HP50，6人，45金\n"
			"• [color=red]佣兵刺客[/color] — ATK8/HP20，4人，60金\n\n"
			"[color=cyan]费用折扣：[/color]\n"
			"• 恶名 ≥70：费用 -25%\n"
			"• 恶名 ≥50：费用 -15%\n"
			"• 黑市等级每级：费用 -7.5%\n\n"
			"[color=gray]在海盗面板「Mercenaries」标签中雇佣。[/color]"
		),
		"trigger": "pirate_infamy_50",
		"highlight": "",
	},
	{
		"id": "pirate_merc_do",
		"phase": "mercenary",
		"title": "【雇佣兵】雇佣第一支佣兵",
		"text": (
			"[color=orange]操作步骤：[/color]\n"
			"1. 按 [color=cyan][P][/color] 键打开海盗面板\n"
			"2. 点击「[color=magenta]Mercenaries[/color]」标签\n"
			"3. 查看可用兵种及调整后的价格\n"
			"4. 点击「[color=green]雇佣[/color]」\n\n"
			"[color=yellow]雇佣后：[/color]\n"
			"• 佣兵部队加入你的军队\n"
			"• 消息日志记录雇佣信息\n"
			"• 金币相应扣除\n\n"
			"[color=red]⚠ 验证点：\n"
			"• 金币是否正确扣除\n"
			"• 佣兵是否加入军队\n"
			"• 军队战力是否更新[/color]"
		),
		"trigger": "pirate_panel_opened",
		"highlight": "",
	},
	{
		"id": "pirate_merc_done",
		"phase": "mercenary",
		"title": "【雇佣兵】雇佣完成 ✓",
		"text": (
			"[color=green]✓ 佣兵已加入你的军队！[/color]\n\n"
			"[color=yellow]已解锁功能：[/color]\n"
			"• 雇佣兵系统 ✓\n"
			"• 恶名影响雇佣费用 ✓\n"
			"• 黑市等级影响费用 ✓\n\n"
			"[color=cyan]引导任务「雇佣军团」已完成，奖励 100 金已发放！[/color]\n\n"
			"下一步：[color=gold]英雄解锁[/color] — 招募海盗专属英雄。"
		),
		"trigger": "pirate_merc_hired",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 8：英雄解锁
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "pirate_hero_intro",
		"phase": "hero",
		"title": "【英雄】海盗专属英雄",
		"text": (
			"海盗阵营拥有 [color=gold]5 位专属英雄[/color]，"
			"每位都有独特的解锁条件和技能：\n\n"
			"• [color=cyan]潮音[/color] — 第15回合后加入，弓兵专精，技能「连射」\n"
			"• [color=magenta]サイレン[/color] — 恶名 ≥50 加入（[color=green]已满足！[/color]），魅惑之歌\n"
			"• [color=orange]アイアンフック[/color] — 累计掠夺 ≥100 金，铁钩连击\n"
			"• [color=yellow]ストームコーラー[/color] — 第18回合后，法术专精\n"
			"• [color=red]シャドウブレード[/color] — 走私航线 ≥2，暗杀技能\n\n"
			"[color=gray]按 H 键打开英雄面板，查看并招募可用英雄。[/color]"
		),
		"trigger": "pirate_merc_hired",
		"highlight": "",
	},
	{
		"id": "pirate_hero_done",
		"phase": "hero",
		"title": "【英雄】英雄招募完成 ✓",
		"text": (
			"[color=green]✓ 英雄已加入你的阵营！[/color]\n\n"
			"[color=yellow]已解锁功能：[/color]\n"
			"• 英雄解锁条件检查 ✓\n"
			"• 英雄招募流程 ✓\n"
			"• 英雄技能系统 ✓\n\n"
			"[color=cyan]引导任务「传奇英雄」已完成，奖励 150 金已发放！[/color]\n\n"
			"下一步：[color=cyan]港口控制[/color] — 占领战略要地。"
		),
		"trigger": "pirate_hero_recruited",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 9：港口控制
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "pirate_harbor_intro",
		"phase": "harbor",
		"title": "【港口】海上战略核心",
		"text": (
			"[color=cyan]港口[/color]是海盗阵营的战略核心，"
			"占领港口将解锁多项重要功能：\n\n"
			"[color=yellow]港口的价值：[/color]\n"
			"• 触发剧情支线「[color=gold]海盗宝藏[/color]」（奖励 800 金 + 掠夺 +20）\n"
			"• 满足挑战任务「恐怖航路」（pirate_c2）的条件\n"
			"• 增加性奴隶容量上限（+3）\n"
			"• 港口格子每回合额外金币收入\n\n"
			"[color=orange]在地图上找到港口格子（HARBOR 类型），"
			"发动攻击并占领它！[/color]"
		),
		"trigger": "pirate_hero_recruited",
		"highlight": "",
	},
	{
		"id": "pirate_harbor_done",
		"phase": "harbor",
		"title": "【港口】港口控制完成 ✓",
		"text": (
			"[color=green]✓ 港口已在你的掌控之中！[/color]\n\n"
			"[color=yellow]已解锁功能：[/color]\n"
			"• 港口占领奖励 ✓\n"
			"• 剧情支线「海盗宝藏」触发 ✓\n"
			"• 挑战任务 pirate_c2 条件满足 ✓\n\n"
			"[color=cyan]引导任务「海上霸主」已完成，奖励 200 金已发放！[/color]\n\n"
			"下一步：[color=gold]传奇之路[/color] — 开启海盗挑战链！"
		),
		"trigger": "pirate_harbor_captured",
		"highlight": "",
	},

	# ─────────────────────────────────────────────────────────────────────────
	# 阶段 10：挑战任务启程
	# ─────────────────────────────────────────────────────────────────────────
	{
		"id": "pirate_challenge_intro",
		"phase": "challenge",
		"title": "【挑战】传奇之路",
		"text": (
			"[color=gold]恭喜！你已掌握了海盗阵营的所有基础机制！[/color]\n\n"
			"现在是时候踏上[color=gold]传奇之路[/color]了——"
			"海盗阵营的 6 阶挑战任务链：\n\n"
			"• [color=white]pirate_c1[/color] 首次掠夺 → 奖励「海王之刃」\n"
			"• [color=green]pirate_c2[/color] 恐怖航路 → 奖励「海脚」特质\n"
			"• [color=yellow]pirate_c3[/color] 幽灵船试炼 → 奖励「幽灵船长外套」\n"
			"• [color=orange]pirate_c4[/color] 黑市之王 → 奖励「寻宝罗盘」\n"
			"• [color=red]pirate_c5[/color] 海上霸权 → 奖励「恐惧船长」特质\n"
			"• [color=magenta]pirate_c6[/color] 七海之王 → 奖励「黑旗恐惧」终极技能 + 称号\n\n"
			"[color=gray]在任务日志（按 J 键）的「挑战」标签中查看进度。[/color]"
		),
		"trigger": "pirate_harbor_captured",
		"highlight": "",
	},
	{
		"id": "pirate_onboarding_complete",
		"phase": "challenge",
		"title": "⚓ 海盗引导完成！",
		"text": (
			"[color=gold]✓ 所有海盗阵营引导任务已完成！[/color]\n\n"
			"[color=yellow]你已掌握的机制：[/color]\n"
			"✓ 掠夺经济（战斗金币 + 连击加成）\n"
			"✓ 黑市交易（商品购买 + 恶名折扣）\n"
			"✓ 朗姆酒士气（ATK 加成）\n"
			"✓ 藏宝图探索（随机奖励）\n"
			"✓ 走私航线（被动收入）\n"
			"✓ 恶名系统（影响外交/价格/英雄）\n"
			"✓ 雇佣兵（金币换兵力）\n"
			"✓ 英雄解锁（5位专属英雄）\n"
			"✓ 港口控制（战略要地）\n"
			"✓ 挑战任务链（6阶传奇之路）\n\n"
			"[color=cyan]引导任务「传奇之路」已完成，奖励 300 金 + 威望 20 已发放！[/color]\n\n"
			"[color=gold]七海之王的传说，从此由你书写！[/color]"
		),
		"trigger": "pirate_challenge_started",
		"highlight": "",
	},
]

# ══════════════════════════════════════════════════════════════════════════════
# STATE VARIABLES
# ══════════════════════════════════════════════════════════════════════════════

var _active: bool = false
var _current_step_index: int = 0
var _completed_steps: Array = []
var _onboarding_complete: bool = false

# ── UI 节点引用 ──
var _popup: PanelContainer
var _title_label: Label
var _text_label: RichTextLabel
var _btn_next: Button
var _btn_skip: Button
var _step_label: Label
var _phase_label: Label
var _visible_popup: bool = false

# ── 事件追踪标记 ──
var _first_combat_done: bool = false
var _market_bought: bool = false
var _rum_active: bool = false
var _treasure_explored: bool = false
var _smuggle_established: bool = false
var _infamy_50_reached: bool = false
var _merc_hired: bool = false
var _hero_recruited: bool = false
var _harbor_captured: bool = false
var _challenge_started: bool = false

# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_ui()
	_connect_signals()


func _build_ui() -> void:
	## 构建引导弹窗 UI（复用 TutorialManager 的样式）
	# CanvasLayer.layer 属性直接赋值，高于通知层，低于设置层
	layer = UILayerRegistry.LAYER_NOTIFICATION + 1

	_popup = PanelContainer.new()
	_popup.custom_minimum_size = Vector2(460, 300)
	_popup.anchor_left   = 0.5
	_popup.anchor_top    = 0.5
	_popup.anchor_right  = 0.5
	_popup.anchor_bottom = 0.5
	_popup.offset_left   = -230
	_popup.offset_top    = -200
	_popup.offset_right  = 230
	_popup.offset_bottom = 200
	_popup.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.15, 0.96)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.15, 0.55, 0.9, 1.0)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	_popup.add_theme_stylebox_override("panel", style)
	add_child(_popup)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_popup.add_child(vbox)

	# ── 顶部：阶段标签 ──
	_phase_label = Label.new()
	_phase_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	_phase_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_phase_label)

	# ── 标题 ──
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# ── 正文 ──
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.custom_minimum_size = Vector2(0, 120)
	_text_label.add_theme_font_size_override("normal_font_size", 13)
	vbox.add_child(_text_label)

	# ── 步骤进度 ──
	_step_label = Label.new()
	_step_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_step_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_step_label)

	# ── 按钮行 ──
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_row)

	_btn_skip = Button.new()
	_btn_skip.text = "跳过引导"
	_btn_skip.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_btn_skip.pressed.connect(_on_skip_pressed)
	btn_row.add_child(_btn_skip)

	_btn_next = Button.new()
	_btn_next.text = "继续 ▶"
	_btn_next.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_btn_next.pressed.connect(_advance_step)
	btn_row.add_child(_btn_next)


func _connect_signals() -> void:
	## 连接所有需要监听的 EventBus 信号
	if not EventBus:
		return

	# 战斗胜利
	EventBus.combat_result.connect(_on_combat_result)
	# 恶名变化
	EventBus.infamy_changed.connect(_on_infamy_changed)
	# 朗姆酒士气变化
	EventBus.rum_morale_changed.connect(_on_rum_morale_changed)
	# 资源变化（用于检测走私收入）
	EventBus.resources_changed.connect(_on_resources_changed)
	# 英雄招募
	EventBus.hero_recruited.connect(_on_hero_recruited)
	# 游戏开始
	if EventBus.has_signal("game_started"):
		EventBus.game_started.connect(_on_game_started)


# ══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ══════════════════════════════════════════════════════════════════════════════

func start_onboarding() -> void:
	## 启动海盗阵营引导（由 GameManager 在海盗阵营游戏开始时调用）
	if _onboarding_complete:
		return
	_active = true
	_current_step_index = 0
	_completed_steps.clear()
	_reset_flags()
	_show_step(STEPS[0])
	EventBus.message_log.emit("[color=cyan]⚓ 海盗阵营引导已启动！[/color]")


func stop_onboarding() -> void:
	## 停止引导（跳过或完成时调用）
	_active = false
	if _popup:
		_popup.visible = false
	_visible_popup = false


func is_active() -> bool:
	return _active


func notify_pirate_panel_opened() -> void:
	## 由 pirate_panel.gd 的 show_panel() 调用
	_trigger("pirate_panel_opened")


func notify_market_item_bought() -> void:
	## 由 pirate_panel.gd 的 _on_buy_market() 调用
	if not _market_bought:
		_market_bought = true
		_trigger("pirate_market_bought")


func notify_treasure_explored() -> void:
	## 由 pirate_panel.gd 的探索按钮调用
	if not _treasure_explored:
		_treasure_explored = true
		_trigger("pirate_treasure_explored")


func notify_smuggle_established() -> void:
	## 由 pirate_panel.gd 的建立航线按钮调用
	if not _smuggle_established:
		_smuggle_established = true
		_trigger("pirate_smuggle_established")


func notify_merc_hired() -> void:
	## 由 pirate_panel.gd 的雇佣按钮调用
	if not _merc_hired:
		_merc_hired = true
		_trigger("pirate_merc_hired")


func notify_hero_recruited() -> void:
	## 由 HeroSystem 的招募回调调用
	if not _hero_recruited:
		_hero_recruited = true
		_trigger("pirate_hero_recruited")


func notify_harbor_captured() -> void:
	## 由 GameManager 的占领逻辑调用（港口格子被占领时）
	if not _harbor_captured:
		_harbor_captured = true
		_trigger("pirate_harbor_captured")


# ══════════════════════════════════════════════════════════════════════════════
# SIGNAL HANDLERS
# ══════════════════════════════════════════════════════════════════════════════

func _on_game_started() -> void:
	## 游戏开始时检查是否为海盗阵营
	pass  # 由 GameManager 显式调用 start_onboarding()


func _on_combat_result(player_id: int, _target_tile: int, won: bool) -> void:
	if player_id != 0 or not won:
		return
	if not _first_combat_done:
		_first_combat_done = true
		_trigger("first_combat")
	# 检查是否为港口格子
	if not _harbor_captured and GameManager and GameManager.has_method("get_tile"):
		# 港口占领检查由 notify_harbor_captured() 处理
		pass


func _on_infamy_changed(player_id: int, new_value: int) -> void:
	if player_id != 0:
		return
	if not _infamy_50_reached and new_value >= 50:
		_infamy_50_reached = true
		_trigger("pirate_infamy_50")


func _on_rum_morale_changed(player_id: int, new_value: int) -> void:
	if player_id != 0:
		return
	if not _rum_active and new_value >= 50:
		_rum_active = true
		_trigger("pirate_rum_active")


func _on_resources_changed(_player_id: int) -> void:
	## 资源变化时检查挑战任务 pirate_c1 的完成条件（800 金）
	if not _challenge_started and _active:
		if ResourceManager and ResourceManager.has_method("get_resource"):
			var gold: int = ResourceManager.get_resource(0, "gold")
			if gold >= 800:
				_challenge_started = true
				_trigger("pirate_challenge_started")


func _on_hero_recruited(_hero_id: String) -> void:
	## 英雄被招募时通知引导系统
	if not _hero_recruited:
		_hero_recruited = true
		_trigger("pirate_hero_recruited")


# ══════════════════════════════════════════════════════════════════════════════
# CORE LOGIC
# ══════════════════════════════════════════════════════════════════════════════

func _trigger(trigger_id: String) -> void:
	## 检查当前步骤是否等待该触发器，若是则推进
	if not _active or _current_step_index >= STEPS.size():
		return
	var step: Dictionary = STEPS[_current_step_index]
	if step.get("trigger", "") == trigger_id:
		_advance_step()


func _show_step(step: Dictionary) -> void:
	## 显示指定步骤的弹窗
	if not _popup:
		return
	var phase_name: String = PHASE_NAMES.get(step.get("phase", ""), "")
	_phase_label.text = "⚓ 海盗引导 — %s" % phase_name if phase_name else "⚓ 海盗引导"
	_title_label.text = step.get("title", "")
	_text_label.text  = step.get("text", "")
	_step_label.text  = "步骤 %d / %d" % [_current_step_index + 1, STEPS.size()]

	_popup.visible = true
	_visible_popup = true

	# 淡入动画
	_popup.modulate = Color(1, 1, 1, 0)
	var tween := _popup.create_tween()
	tween.tween_property(_popup, "modulate", Color(1, 1, 1, 1), 0.3)

	onboarding_step_changed.emit(step.get("id", ""))
	EventBus.message_log.emit(
		"[color=cyan]⚓ 海盗引导[/color] — [color=yellow]%s[/color]" % step.get("title", "")
	)


func _advance_step() -> void:
	## 推进到下一步骤
	if _current_step_index < STEPS.size():
		_completed_steps.append(STEPS[_current_step_index]["id"])
	_current_step_index += 1

	if _current_step_index >= STEPS.size():
		_complete_onboarding()
		return

	var next_step: Dictionary = STEPS[_current_step_index]
	# 如果下一步骤有自动触发条件且该条件已满足，直接跳过到手动步骤
	var trigger: String = next_step.get("trigger", "")
	if trigger == "" or _is_trigger_already_met(trigger):
		_show_step(next_step)
	else:
		_show_step(next_step)


func _is_trigger_already_met(trigger_id: String) -> bool:
	## 检查某个触发条件是否已经满足（用于跳过已完成的步骤）
	match trigger_id:
		"first_combat":
			return _first_combat_done
		"pirate_combat_won":
			return _first_combat_done
		"pirate_market_bought":
			return _market_bought
		"pirate_rum_active":
			return _rum_active
		"pirate_treasure_explored":
			return _treasure_explored
		"pirate_smuggle_established":
			return _smuggle_established
		"pirate_infamy_50":
			return _infamy_50_reached
		"pirate_merc_hired":
			return _merc_hired
		"pirate_hero_recruited":
			return _hero_recruited
		"pirate_harbor_captured":
			return _harbor_captured
		"pirate_challenge_started":
			return _challenge_started
	return false


func _complete_onboarding() -> void:
	## 引导全部完成
	_onboarding_complete = true
	_active = false
	if _popup:
		_popup.visible = false
	_visible_popup = false
	onboarding_completed.emit()
	EventBus.message_log.emit(
		"[color=gold]⚓ 海盗阵营引导全部完成！七海之王的传说从此开始！[/color]"
	)


func _on_skip_pressed() -> void:
	## 跳过整个引导
	stop_onboarding()
	EventBus.message_log.emit("[color=gray]海盗引导已跳过。[/color]")


func _reset_flags() -> void:
	_first_combat_done    = false
	_market_bought        = false
	_rum_active           = false
	_treasure_explored    = false
	_smuggle_established  = false
	_infamy_50_reached    = false
	_merc_hired           = false
	_hero_recruited       = false
	_harbor_captured      = false
	_challenge_started    = false


# ══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD
# ══════════════════════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	return {
		"active":              _active,
		"current_step_index":  _current_step_index,
		"completed_steps":     _completed_steps.duplicate(),
		"onboarding_complete": _onboarding_complete,
		"flags": {
			"first_combat_done":   _first_combat_done,
			"market_bought":       _market_bought,
			"rum_active":          _rum_active,
			"treasure_explored":   _treasure_explored,
			"smuggle_established": _smuggle_established,
			"infamy_50_reached":   _infamy_50_reached,
			"merc_hired":          _merc_hired,
			"hero_recruited":      _hero_recruited,
			"harbor_captured":     _harbor_captured,
			"challenge_started":   _challenge_started,
		},
	}


func from_save_data(data: Dictionary) -> void:
	_active              = data.get("active", false)
	_current_step_index  = data.get("current_step_index", 0)
	_completed_steps     = data.get("completed_steps", [])
	_onboarding_complete = data.get("onboarding_complete", false)
	var flags: Dictionary = data.get("flags", {})
	_first_combat_done   = flags.get("first_combat_done", false)
	_market_bought       = flags.get("market_bought", false)
	_rum_active          = flags.get("rum_active", false)
	_treasure_explored   = flags.get("treasure_explored", false)
	_smuggle_established = flags.get("smuggle_established", false)
	_infamy_50_reached   = flags.get("infamy_50_reached", false)
	_merc_hired          = flags.get("merc_hired", false)
	_hero_recruited      = flags.get("hero_recruited", false)
	_harbor_captured     = flags.get("harbor_captured", false)
	_challenge_started   = flags.get("challenge_started", false)
	# 如果引导未完成，恢复弹窗显示
	if _active and _current_step_index < STEPS.size():
		_show_step(STEPS[_current_step_index])
