## pirate_quest_guide.gd — 海盗阵营初始任务引导链
##
## 本文件定义海盗阵营专属的"引导任务"序列，注入 QuestJournal 的 _guide_progress 追踪器。
## 引导任务按顺序解锁，每完成一个即解锁下一个，覆盖海盗阵营所有特色功能：
##
##   阶段 1 — 掠夺经济  (赢得第一场战斗，获得掠夺金币)
##   阶段 2 — 黑市交易  (在黑市购买第一件商品)
##   阶段 3 — 朗姆酒士气(使用朗姆酒桶，提升士气)
##   阶段 4 — 藏宝图探索(获得并探索第一张藏宝图)
##   阶段 5 — 走私航线  (建立第一条走私航线)
##   阶段 6 — 恶名累积  (恶名值达到 50)
##   阶段 7 — 雇佣兵    (雇佣第一支佣兵部队)
##   阶段 8 — 英雄解锁  (解锁第一位海盗专属英雄)
##   阶段 9 — 港口控制  (占领第一个港口)
##   阶段 10— 挑战启程  (完成挑战任务 pirate_c1)
##
## 触发条件均使用 QuestJournal._evaluate_trigger / _evaluate_objective 已支持的 key，
## 无需修改 quest_journal.gd 的评估逻辑。
##
## Autoload: 无（静态数据类，由 QuestJournal 直接引用）
extends RefCounted
class_name PirateQuestGuide

const FactionData = preload("res://systems/faction/faction_data.gd")

# ══════════════════════════════════════════════════════════════════════════════
# GUIDE QUEST CHAIN — 海盗引导任务链（按顺序解锁）
# ══════════════════════════════════════════════════════════════════════════════

## 引导任务链：每个任务的 trigger 包含 "prev_guide_done" key，
## 由 QuestJournal._evaluate_trigger 中新增的 "prev_guide_done" 分支处理。
## 第一个任务（pirate_g1）无前置，游戏开始即激活。
const GUIDE_QUESTS: Array = [

	# ── 阶段 1：掠夺经济 ──────────────────────────────────────────────────────
	{
		"id": "pirate_g1",
		"name": "第一桶金",
		"desc":"海盗的生存之道是掠夺！赢得你的第一场战斗，让敌人的财富成为你的战利品。\n\n[color=yellow]提示：[/color]点击左侧「攻击」按钮，选择相邻的中立格子发动进攻。战斗胜利后会自动结算掠夺金币。",
		"category": "guide",
		"faction": FactionData.FactionID.PIRATE,
		"trigger": {},   # 游戏开始即激活
		"objectives": [
			{"type": "battles_won_min", "value": 1, "label": "赢得1场战斗"},
		],
		"reward": {
			"gold": 80,
			"message": "[color=gold]✓ 掠夺成功！你的海盗生涯正式开始！[/color]",
		},
		"hint": "点击「攻击」→ 选择相邻格子 → 战斗胜利后自动获得掠夺金币。",
		"unlock_next": "pirate_g2",
	},

	# ── 阶段 2：黑市交易 ──────────────────────────────────────────────────────
	{
		"id": "pirate_g2",
		"name": "黑市初体验",
		"desc":"海盗的秘密武器——[color=gold]黑市[/color]！按 [color=cyan][P][/color] 键打开海盗面板，在「Black Market」标签购买一件商品。\n\n[color=yellow]提示：[/color]黑市每回合刷新商品，恶名越低价格越优惠。走私军火、朗姆酒桶、藏宝图都是常见商品。",
		"category": "guide",
		"faction": FactionData.FactionID.PIRATE,
		"trigger": {"prev_guide_done": "pirate_g1"},
		"objectives": [
			{"type": "black_market_trades_min", "value": 1, "label": "在黑市购买1件商品"},
		],
		"reward": {
			"gold": 50,
			"message": "[color=gold]✓ 黑市交易完成！你已掌握海盗的秘密贸易渠道。[/color]",
		},
		"hint": "按 [P] 键打开海盗面板 → 切换到「Black Market」标签 → 点击「Buy」购买商品。",
		"unlock_next": "pirate_g3",
	},

	# ── 阶段 3：朗姆酒士气 ────────────────────────────────────────────────────
	{
		"id": "pirate_g3",
		"name": "朗姆酒的力量",
		"desc":"[color=orange]朗姆酒[/color]是海盗战斗力的秘密来源！士气值 ≥50 时全军 ATK+2，≥90 时 ATK+4（但 DEF-2）。\n\n在黑市购买「朗姆酒桶」，或在海盗面板直接使用，将朗姆酒士气提升到 50 以上，激活战斗加成。",
		"category": "guide",
		"faction": FactionData.FactionID.PIRATE,
		"trigger": {"prev_guide_done": "pirate_g2"},
		"objectives": [
			{"type": "rum_morale_min", "value": 50, "label": "朗姆酒士气达到50"},
		],
		"reward": {
			"gold": 60,
			"message": "[color=orange]✓ 船员们喝得热血沸腾！朗姆酒加成已激活！[/color]",
		},
		"hint": "黑市购买「朗姆酒桶」→ 士气 +15。起始士气为50，保持不消耗即可。",
		"unlock_next": "pirate_g4",
	},

	# ── 阶段 4：藏宝图探索 ────────────────────────────────────────────────────
	{
		"id": "pirate_g4",
		"name": "寻宝猎人",
		"desc":"[color=yellow]藏宝图[/color]是海盗的专属福利！每次战斗胜利有 15% 概率获得藏宝图，也可在黑市购买。\n\n获得藏宝图后，在海盗面板「Treasure Hunt」标签中点击「探索」，可能获得金币、佣兵、朗姆酒或稀有道具。",
		"category": "guide",
		"faction": FactionData.FactionID.PIRATE,
		"trigger": {"prev_guide_done": "pirate_g3"},
		"objectives": [
			{"type": "treasure_maps_min", "value": 1, "label": "获得并探索1张藏宝图"},
		],
		"reward": {
			"gold": 100,
			"message": "[color=yellow]✓ 宝藏已找到！你的探宝之路刚刚开始！[/color]",
		},
		"hint": "赢得战斗（15%概率掉落）或黑市购买「藏宝图」→ 海盗面板「Treasure Hunt」→「探索」。",
		"unlock_next": "pirate_g5",
	},

	# ── 阶段 5：走私航线 ──────────────────────────────────────────────────────
	{
		"id": "pirate_g5",
		"name": "秘密航线",
		"desc":"[color=cyan]走私航线[/color]是海盗的被动收入来源，每条航线每回合提供 +8 金币。\n\n在海盗面板「Smuggle Routes」标签中，选择两块你控制的领地建立航线。最多可建立 3 条航线，是稳定经济的关键。",
		"category": "guide",
		"faction": FactionData.FactionID.PIRATE,
		"trigger": {"prev_guide_done": "pirate_g4"},
		"objectives": [
			{"type": "smuggle_routes_min", "value": 1, "label": "建立1条走私航线"},
		],
		"reward": {
			"gold": 80,
			"message": "[color=cyan]✓ 走私航线建立！每回合被动收入 +8 金币！[/color]",
		},
		"hint": "需要控制至少2块领地 → 海盗面板「Smuggle Routes」→ 选择两块领地 →「建立航线」。",
		"unlock_next": "pirate_g6",
	},

	# ── 阶段 6：恶名累积 ──────────────────────────────────────────────────────
	{
		"id": "pirate_g6",
		"name": "恶名昭著",
		"desc":"[color=red]恶名[/color]是海盗的双刃剑：\n• 恶名 ≥70：光明阵营拒绝交易\n• 恶名 ≥50：掠夺倍率 +0.3，雇佣兵费用降低\n• 恶名 ≤30：黑暗阵营不信任你\n\n每次战斗胜利 +5 恶名，每回合自然衰减 -2。将恶名提升到 50，解锁「サイレン」英雄的加入条件。",
		"category": "guide",
		"faction": FactionData.FactionID.PIRATE,
		"trigger": {"prev_guide_done": "pirate_g5"},
		"objectives": [
			{"type": "infamy_min", "value": 50, "label": "恶名值达到50"},
		],
		"reward": {
			"gold": 120,
			"prestige": 10,
			"message": "[color=red]✓ 你的恶名已传遍四海！英雄们开始注意到你！[/color]",
		},
		"hint": "持续赢得战斗（每次 +5 恶名），避免交易和赎回（会降低恶名）。",
		"unlock_next": "pirate_g7",
	},

	# ── 阶段 7：雇佣兵 ────────────────────────────────────────────────────────
	{
		"id": "pirate_g7",
		"name": "雇佣军团",
		"desc":"[color=magenta]雇佣兵[/color]是海盗快速扩充兵力的手段！不需要铁矿，只需金币即可雇佣。\n\n在海盗面板「Mercenaries」标签中选择兵种雇佣。恶名越高、黑市等级越高，雇佣费用越低。\n\n可选兵种：佣兵剑士(30金)、佣兵弓手(35金)、佣兵重甲(45金)、佣兵刺客(60金)",
		"category": "guide",
		"faction": FactionData.FactionID.PIRATE,
		"trigger": {"prev_guide_done": "pirate_g6"},
		"objectives": [
			{"type": "mercenary_hired_min", "value": 1, "label": "雇佣1支佣兵部队"},
		],
		"reward": {
			"gold": 100,
			"message": "[color=magenta]✓ 佣兵已加入！你的军队实力大幅提升！[/color]",
		},
		"hint": "海盗面板「Mercenaries」→ 选择兵种 →「雇佣」（需要足够金币）。",
		"unlock_next": "pirate_g8",
	},

	# ── 阶段 8：英雄解锁 ──────────────────────────────────────────────────────
	{
		"id": "pirate_g8",
		"name": "传奇英雄",
		"desc":"海盗阵营拥有独特的[color=gold]英雄解锁条件[/color]，每位英雄都有专属加入要求：\n\n• [color=cyan]潮音[/color] — 第15回合后自动加入\n• [color=magenta]サイレン[/color] — 恶名 ≥50（已满足！）\n• [color=orange]アイアンフック[/color] — 累计掠夺 ≥100 金\n• [color=yellow]ストームコーラー[/color] — 第18回合后\n• [color=red]シャドウブレード[/color] — 走私航线 ≥2\n\n打开「英雄」面板（按 H 键），查看并招募可用英雄。",
		"category": "guide",
		"faction": FactionData.FactionID.PIRATE,
		"trigger": {"prev_guide_done": "pirate_g7"},
		"objectives": [
			{"type": "heroes_min", "value": 1, "label": "招募1位英雄"},
		],
		"reward": {
			"gold": 150,
			"message": "[color=gold]✓ 英雄已加入！他们将为你的海盗大业效力！[/color]",
		},
		"hint": "按 H 键打开英雄面板 → 查看满足条件的英雄 → 点击「招募」。",
		"unlock_next": "pirate_g9",
	},

	# ── 阶段 9：港口控制 ──────────────────────────────────────────────────────
	{
		"id": "pirate_g9",
		"name": "海上霸主",
		"desc":"[color=cyan]港口[/color]是海盗阵营的战略核心！\n\n占领港口可以：\n• 触发「海盗宝藏」剧情支线任务\n• 解锁走私航线的更多组合\n• 增加性奴隶容量上限\n• 满足挑战任务 pirate_c2「恐怖航路」的条件\n\n在地图上找到港口格子（HARBOR 类型），发动攻击并占领它！",
		"category": "guide",
		"faction": FactionData.FactionID.PIRATE,
		"trigger": {"prev_guide_done": "pirate_g8"},
		"objectives": [
			{"type": "harbor_min", "value": 1, "label": "控制1个港口"},
		],
		"reward": {
			"gold": 200,
			"message": "[color=cyan]✓ 港口已在掌控之中！你的海上帝国初具规模！[/color]",
		},
		"hint": "在地图上寻找港口格子 → 攻击并占领 → 港口每回合提供额外金币收入。",
		"unlock_next": "pirate_g10",
	},

	# ── 阶段 10：挑战任务启程 ─────────────────────────────────────────────────
	{
		"id": "pirate_g10",
		"name": "传奇之路",
		"desc":"你已掌握了海盗阵营的所有基础机制！\n\n现在是时候踏上[color=gold]传奇之路[/color]了——完成挑战任务「首次掠夺」（pirate_c1），获得传说装备「海王之刃」，开启海盗挑战链！\n\n[color=yellow]挑战链预览：[/color]\npirate_c1 首次掠夺 → pirate_c2 恐怖航路 → pirate_c3 幽灵船试炼\n→ pirate_c4 黑市之王 → pirate_c5 海上霸权 → pirate_c6 七海之王",
		"category": "guide",
		"faction": FactionData.FactionID.PIRATE,
		"trigger": {"prev_guide_done": "pirate_g9"},
		"objectives": [
			{"type": "gold_min", "value": 800, "label": "累计拥有800金币（完成 pirate_c1）"},
		],
		"reward": {
			"gold": 300,
			"prestige": 20,
			"message":"[color=gold]✓ 引导任务全部完成！你已成为真正的海盗首领！七海之王的传说从此开始！[/color]",
		},
		"hint": "积累800金币即可完成挑战任务 pirate_c1，获得「海王之刃」传说装备。",
		"unlock_next": "",   # 引导链结束
	},
]
