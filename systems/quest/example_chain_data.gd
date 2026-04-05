## example_chain_data.gd — 示例任务链数据 (v1.0)
## 包含4条完整的示例任务链，覆盖所有节点类型和分支模式。
## 供 QuestChainManager 在 init 时注册使用。
## 使用方式: QuestChainManager.register_chain(ExampleChainData.CHAIN_DARK_TIDE_RISING)
class_name ExampleChainData

# ═══════════════════════════════════════════════════════════════
#   链1: 暗潮崛起（主线扩展链）
#   类型: faction_chain  分支: 双路线（征服/外交）
# ═══════════════════════════════════════════════════════════════
const CHAIN_DARK_TIDE_RISING: Dictionary = {
	"id": "chain_dark_tide_rising",
	"name": "暗潮崛起",
	"desc": "黑暗势力在大陆边缘集结，你必须在征服与外交之间做出抉择，决定暗潮的崛起方式。",
	"category": "faction_chain",
	"trigger": {
		"type": "turn_reached",
		"turn": 5,
	},
	"nodes": [
		# ── 节点1: 序章事件（event 节点）──
		{
			"id": "dtr_n01_prologue",
			"name": "黑暗的呼唤",
			"type": "event",
			"desc": "一名神秘使者带来了来自深渊的信息，暗示着大规模行动的时机已到。",
			"popup": {
				"title": "黑暗的呼唤",
				"desc": "「主人，深渊的力量正在汇聚。是时候让这片大陆感受到真正的黑暗了。」\n\n神秘使者的话语在你心中回荡，你感到一股前所未有的力量在体内涌动。",
				"choices": [],
			},
			"children": ["dtr_n02_gather_forces"],
			"reward": {"shadow_essence": 50},
		},
		# ── 节点2: 集结力量（quest 节点）──
		{
			"id": "dtr_n02_gather_forces",
			"name": "集结暗影军团",
			"type": "quest",
			"desc": "在行动之前，必须先集结足够的军事力量。",
			"objectives": [
				{"type": "resource_min", "resource": "army", "amount": 30, "label": "拥有至少 30 支军队"},
				{"type": "territory_count", "amount": 3, "label": "控制至少 3 块领地"},
			],
			"children": ["dtr_n03_choose_path"],
			"reward": {"gold": 200, "prestige": 50},
		},
		# ── 节点3: 关键分支（gate 节点）──
		{
			"id": "dtr_n03_choose_path",
			"name": "抉择时刻",
			"type": "gate",
			"gate_type": "branch_choice",
			"desc": "你的力量已经足够强大。现在，你必须选择暗潮崛起的方式。",
			"popup": {
				"title": "抉择时刻",
				"desc": "你的军团已经集结完毕，领地也已稳固。现在，是时候决定如何让暗潮真正崛起了。\n\n[color=yellow]征服之路[/color]：以武力征服邻近势力，彰显暗潮的强大。\n[color=cyan]阴谋之路[/color]：通过外交与阴谋，在幕后操控各方势力。",
				"choices": [
					{"text": "征服之路", "desc": "以武力震慑大陆，直接征服邻近势力", "node_id": "dtr_n04a_conquest"},
					{"text": "阴谋之路", "desc": "在幕后操控，通过外交手段扩大影响力", "node_id": "dtr_n04b_intrigue"},
				],
			},
			"children": ["dtr_n04a_conquest", "dtr_n04b_intrigue"],
		},
		# ── 节点4a: 征服路线 ──
		{
			"id": "dtr_n04a_conquest",
			"name": "铁蹄征途",
			"type": "quest",
			"desc": "率领军团征服邻近的人类领地，彰显暗潮的军事实力。",
			"objectives": [
				{"type": "combat_wins", "amount": 3, "label": "赢得 3 场战斗"},
				{"type": "territory_count", "amount": 6, "label": "控制至少 6 块领地"},
			],
			"children": ["dtr_n05a_subjugate"],
			"reward": {"gold": 500, "army": 20, "prestige": 100},
		},
		# ── 节点4b: 阴谋路线 ──
		{
			"id": "dtr_n04b_intrigue",
			"name": "暗影外交",
			"type": "quest",
			"desc": "通过外交手段与各势力建立关系，在幕后操控局势。",
			"objectives": [
				{"type": "diplomacy_count", "amount": 2, "label": "完成 2 次外交行动"},
				{"type": "resource_min", "resource": "gold", "amount": 500, "label": "积累 500 金币"},
			],
			"children": ["dtr_n05b_puppet"],
			"reward": {"gold": 800, "charm": 50, "prestige": 80},
		},
		# ── 节点5a: 征服路线终章 ──
		{
			"id": "dtr_n05a_subjugate",
			"name": "征服大陆",
			"type": "event",
			"desc": "你的军团已经证明了暗潮的力量，各势力纷纷臣服。",
			"popup": {
				"title": "征服大陆",
				"desc": "你的铁蹄踏遍了大陆的每一寸土地，敌人的旗帜纷纷倒下。\n\n暗潮的威名将永远铭刻在历史之中！",
				"choices": [],
			},
			"children": ["dtr_n06_endgame"],
			"reward": {"gold": 1000, "prestige": 200, "army": 50},
			"flags": ["dark_tide_conquest_path_completed"],
		},
		# ── 节点5b: 阴谋路线终章 ──
		{
			"id": "dtr_n05b_puppet",
			"name": "幕后掌控",
			"type": "event",
			"desc": "各势力都在不知不觉中成为了你的棋子，暗潮的影响力渗透到了大陆的每个角落。",
			"popup": {
				"title": "幕后掌控",
				"desc": "他们以为自己在做决定，却不知道每一步都在你的掌握之中。\n\n暗潮的阴影笼罩着整片大陆，而你，就是那个拉动线索的人。",
				"choices": [],
			},
			"children": ["dtr_n06_endgame"],
			"reward": {"gold": 1200, "prestige": 150, "charm": 100},
			"flags": ["dark_tide_intrigue_path_completed"],
		},
		# ── 节点6: 终局奖励（reward 节点）──
		{
			"id": "dtr_n06_endgame",
			"name": "暗潮崛起",
			"type": "reward",
			"desc": "暗潮已经真正崛起，你的名字将被历史铭记。",
			"reward": {
				"gold": 2000,
				"prestige": 500,
				"shadow_essence": 200,
				"unlock_content": "endgame_dark_tide",
			},
			"flags": ["dark_tide_chain_completed"],
			"is_terminal": true,
			"endgame_unlock": true,
		},
	],
}

# ═══════════════════════════════════════════════════════════════
#   链2: 英雄归来（角色链 — 以 rin 为主角）
#   类型: character_chain  分支: 三阶段渐进式
# ═══════════════════════════════════════════════════════════════
const CHAIN_HERO_RETURN: Dictionary = {
	"id": "chain_hero_return",
	"name": "英雄归来",
	"desc": "被俘的英雄林终于有机会重获自由，但她的回归之路充满了考验。",
	"category": "character_chain",
	"trigger": {
		"type": "hero_captured",
		"hero_id": "rin",
	},
	"nodes": [
		{
			"id": "hr_n01_capture",
			"name": "落入囹圄",
			"type": "event",
			"desc": "林被俘虏了，她的命运掌握在你的手中。",
			"popup": {
				"title": "落入囹圄",
				"desc": "「你……你赢了这一次。」林咬着牙，但眼中仍然燃烧着不屈的火焰。\n\n她的命运，将由你来决定。",
				"choices": [],
			},
			"children": ["hr_n02_persuade"],
			"reward": {},
		},
		{
			"id": "hr_n02_persuade",
			"name": "软化心防",
			"type": "quest",
			"desc": "通过对话和互动，逐渐软化林的抵抗意志。",
			"objectives": [
				{"type": "hero_affection_min", "hero_id": "rin", "amount": 30, "label": "林的好感度达到 30"},
			],
			"children": ["hr_n03_trust"],
			"reward": {"charm": 30},
		},
		{
			"id": "hr_n03_trust",
			"name": "建立信任",
			"type": "quest",
			"desc": "林开始对你产生信任，她愿意为你提供情报。",
			"objectives": [
				{"type": "hero_affection_min", "hero_id": "rin", "amount": 60, "label": "林的好感度达到 60"},
				{"type": "turn_passed", "turns": 3, "label": "等待 3 回合"},
			],
			"children": ["hr_n04_choice"],
			"reward": {"charm": 50, "intel": 100},
		},
		{
			"id": "hr_n04_choice",
			"name": "关键选择",
			"type": "gate",
			"gate_type": "branch_choice",
			"desc": "林已经完全信任你了，现在你需要决定她的最终归宿。",
			"popup": {
				"title": "关键选择",
				"desc": "「我……我愿意留在你身边。」林低声说道，脸上泛起了红晕。\n\n你感到这是一个重要的时刻，你的选择将决定你们之间的关系。",
				"choices": [
					{"text": "招募为将领", "desc": "让林成为你麾下的将领，发挥她的军事才能", "node_id": "hr_n05a_recruit"},
					{"text": "深化感情", "desc": "与林建立更深厚的个人关系", "node_id": "hr_n05b_romance"},
				],
			},
			"children": ["hr_n05a_recruit", "hr_n05b_romance"],
		},
		{
			"id": "hr_n05a_recruit",
			"name": "并肩作战",
			"type": "quest",
			"desc": "林加入了你的军团，在战场上展现出卓越的指挥才能。",
			"objectives": [
				{"type": "combat_wins", "amount": 2, "label": "与林一起赢得 2 场战斗"},
			],
			"children": ["hr_n06_finale"],
			"reward": {"prestige": 100, "army": 30},
			"flags": ["rin_recruited_as_general"],
		},
		{
			"id": "hr_n05b_romance",
			"name": "心灵契合",
			"type": "quest",
			"desc": "你与林之间的感情日益深厚，她成为了你最信任的伴侣。",
			"objectives": [
				{"type": "hero_affection_min", "hero_id": "rin", "amount": 90, "label": "林的好感度达到 90"},
			],
			"children": ["hr_n06_finale"],
			"reward": {"charm": 100},
			"flags": ["rin_romance_path"],
		},
		{
			"id": "hr_n06_finale",
			"name": "英雄归来",
			"type": "reward",
			"desc": "林的故事迎来了圆满的结局，她将永远是你最重要的伙伴。",
			"reward": {
				"gold": 500,
				"prestige": 200,
				"charm": 50,
				"unlock_content": "rin_final_cg",
			},
			"flags": ["rin_chain_completed"],
			"is_terminal": true,
		},
	],
}

# ═══════════════════════════════════════════════════════════════
#   链3: 边境危机（危机链 — 限时多阶段）
#   类型: crisis_chain  特点: 有失败节点、限时压力
# ═══════════════════════════════════════════════════════════════
const CHAIN_BORDER_CRISIS: Dictionary = {
	"id": "chain_border_crisis",
	"name": "边境危机",
	"desc": "光明联盟的军队正在边境集结，你必须在有限的时间内做出应对，否则将付出沉重代价。",
	"category": "crisis_chain",
	"trigger": {
		"type": "threat_min",
		"amount": 50,
	},
	"nodes": [
		{
			"id": "bc_n01_warning",
			"name": "边境警报",
			"type": "event",
			"desc": "斥候带来了紧急情报：光明联盟的大军正在向边境推进。",
			"popup": {
				"title": "边境警报",
				"desc": "「报！光明联盟的军队已经在边境集结，估计不超过 5 回合就会发动进攻！」\n\n时间紧迫，你必须立即做出决策。",
				"choices": [],
			},
			"children": ["bc_n02_prepare"],
			"reward": {},
		},
		{
			"id": "bc_n02_prepare",
			"name": "紧急备战",
			"type": "quest",
			"desc": "在敌军到来之前，必须迅速加强边境防御。",
			"objectives": [
				{"type": "resource_min", "resource": "army", "amount": 50, "label": "集结至少 50 支军队"},
				{"type": "building_exists", "building_id": "fortress", "label": "建造一座要塞"},
			],
			"time_limit_turns": 5,
			"fail_node": "bc_n_fail",
			"children": ["bc_n03_battle"],
			"reward": {"prestige": 80},
		},
		{
			"id": "bc_n03_battle",
			"name": "边境决战",
			"type": "quest",
			"desc": "光明联盟的军队已经到达边境，决战时刻来临。",
			"objectives": [
				{"type": "combat_wins", "amount": 1, "label": "击退光明联盟的进攻"},
			],
			"children": ["bc_n04_aftermath"],
			"reward": {"gold": 300, "prestige": 150},
		},
		{
			"id": "bc_n04_aftermath",
			"name": "战后处置",
			"type": "gate",
			"gate_type": "branch_choice",
			"desc": "击退了光明联盟的进攻，现在需要决定如何处置战俘和边境领地。",
			"popup": {
				"title": "战后处置",
				"desc": "你的军队成功击退了光明联盟的进攻，边境暂时安全了。\n\n现在，你需要决定如何处置战俘和边境领地。",
				"choices": [
					{"text": "强硬占领", "desc": "占领边境领地，处决战俘以震慑敌人", "node_id": "bc_n05a_occupy"},
					{"text": "谈判和解", "desc": "释放战俘，与光明联盟谈判，换取暂时的和平", "node_id": "bc_n05b_negotiate"},
				],
			},
			"children": ["bc_n05a_occupy", "bc_n05b_negotiate"],
		},
		{
			"id": "bc_n05a_occupy",
			"name": "铁腕统治",
			"type": "reward",
			"desc": "你以铁腕手段处置了战俘，边境领地被纳入暗潮版图。",
			"reward": {
				"gold": 600,
				"territory": 2,
				"prestige": 200,
				"order_penalty": -20,
			},
			"flags": ["border_crisis_conquest_end"],
			"is_terminal": true,
		},
		{
			"id": "bc_n05b_negotiate",
			"name": "边境协议",
			"type": "reward",
			"desc": "你与光明联盟签订了边境协议，换取了一段时间的和平。",
			"reward": {
				"gold": 400,
				"charm": 80,
				"prestige": 100,
				"threat_reduction": 30,
			},
			"flags": ["border_crisis_peace_end"],
			"is_terminal": true,
		},
		# ── 失败节点 ──
		{
			"id": "bc_n_fail",
			"name": "边境失守",
			"type": "event",
			"desc": "由于准备不足，边境被光明联盟突破，你付出了沉重的代价。",
			"popup": {
				"title": "边境失守",
				"desc": "「主人，边境已经失守！光明联盟的军队正在向内地推进！」\n\n这次失败将会在历史上留下污点，但你仍然有机会重新崛起。",
				"choices": [],
			},
			"children": [],
			"reward": {
				"gold": -300,
				"prestige": -100,
				"territory_loss": 1,
			},
			"is_terminal": true,
			"is_failure": true,
		},
	],
}

# ═══════════════════════════════════════════════════════════════
#   链4: 古老遗迹（支线探索链）
#   类型: side_chain  特点: 并行子任务、多阶段解锁
# ═══════════════════════════════════════════════════════════════
const CHAIN_ANCIENT_RUIN: Dictionary = {
	"id": "chain_ancient_ruin",
	"name": "古老遗迹的秘密",
	"desc": "在领地深处发现了一处古老的遗迹，其中蕴藏着强大的力量和危险的秘密。",
	"category": "side_chain",
	"trigger": {
		"type": "territory_count",
		"amount": 4,
	},
	"nodes": [
		{
			"id": "ar_n01_discover",
			"name": "发现遗迹",
			"type": "event",
			"desc": "你的探险队在领地深处发现了一处古老的遗迹。",
			"popup": {
				"title": "发现遗迹",
				"desc": "「主人，我们在领地的深处发现了一处古老的建筑群。那里弥漫着浓厚的魔法气息，似乎有着极大的价值。」\n\n这可能是一个重要的发现。",
				"choices": [],
			},
			"children": ["ar_n02_explore", "ar_n02b_research"],
			"reward": {"prestige": 30},
		},
		# ── 并行节点（两个同时进行）──
		{
			"id": "ar_n02_explore",
			"name": "探索遗迹",
			"type": "quest",
			"desc": "派遣探险队深入遗迹，探索其中的秘密。",
			"objectives": [
				{"type": "action_done", "action": "explore", "amount": 3, "label": "完成 3 次探索行动"},
			],
			"parallel_group": "ar_phase2",
			"children": ["ar_n03_gate"],
			"reward": {"gold": 200, "shadow_essence": 50},
		},
		{
			"id": "ar_n02b_research",
			"name": "研究古文字",
			"type": "quest",
			"desc": "研究遗迹中发现的古代文字，破解其中的秘密。",
			"objectives": [
				{"type": "research_done", "amount": 1, "label": "完成 1 次研究行动"},
			],
			"parallel_group": "ar_phase2",
			"children": ["ar_n03_gate"],
			"reward": {"prestige": 50},
		},
		# ── 汇合门（等待并行任务全部完成）──
		{
			"id": "ar_n03_gate",
			"name": "解读遗迹",
			"type": "gate",
			"gate_type": "parallel_join",
			"parallel_group": "ar_phase2",
			"desc": "探索和研究都已完成，现在可以真正进入遗迹的核心区域了。",
			"children": ["ar_n04_core"],
		},
		{
			"id": "ar_n04_core",
			"name": "遗迹核心",
			"type": "quest",
			"desc": "进入遗迹的核心区域，面对最终的考验。",
			"objectives": [
				{"type": "combat_wins", "amount": 1, "label": "击败遗迹守卫"},
			],
			"children": ["ar_n05_treasure"],
			"reward": {"gold": 400, "shadow_essence": 100},
		},
		{
			"id": "ar_n05_treasure",
			"name": "古老的馈赠",
			"type": "reward",
			"desc": "你成功探索了整个遗迹，获得了古老文明留下的宝藏。",
			"reward": {
				"gold": 1500,
				"shadow_essence": 300,
				"prestige": 300,
				"unlock_content": "ancient_ruin_relic",
			},
			"flags": ["ancient_ruin_completed"],
			"is_terminal": true,
		},
	],
}

# ── 所有示例链的列表 ──
const ALL_EXAMPLE_CHAINS: Array = [
	CHAIN_DARK_TIDE_RISING,
	CHAIN_HERO_RETURN,
	CHAIN_BORDER_CRISIS,
	CHAIN_ANCIENT_RUIN,
]
