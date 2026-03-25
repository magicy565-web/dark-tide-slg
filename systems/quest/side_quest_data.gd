## side_quest_data.gd — 80条支线任务数据（剧情/奖励/情报/世界事件）
## 供 QuestManager 加载，按类别分为4个常量数组。
extends RefCounted
class_name SideQuestData

const FactionData = preload("res://systems/faction/faction_data.gd")

# ═══════════════ CATEGORY 1: STORY QUESTS (剧情支线) — 20 quests ═══════════════
const STORY_QUESTS: Array = [
	{
		"id": "story_fallen_fortress", "name": "陨落的堡垒",
		"desc": "攻占一座光明要塞后，你发现了其中尘封的历史记录，揭露了光明联盟不为人知的黑暗过往。",
		"category": "story",
		"trigger": {"strongholds_min": 1},
		"objectives": [
			{"type": "strongholds_min", "value": 1, "label": "攻占1座光明要塞"},
		],
		"reward": {"gold": 400, "prestige": 20, "message": "要塞的秘密已被揭开。"},
	},
	{
		"id": "story_slave_uprising", "name": "奴隶暴动",
		"desc": "你的奴隶数量过多，引发了一场暴动。你必须选择镇压还是谈判。",
		"category": "story",
		"trigger": {"slaves_min": 10},
		"objectives": [
			{"type": "slaves_min", "value": 10, "label": "拥有10名以上奴隶"},
		],
		"reward": {"gold": 200, "item": "slave_chain", "message": "暴动已平息，但代价不小。"},
	},
	{
		"id": "story_ancient_seal", "name": "远古封印",
		"desc": "在废墟中发现了一个被封印的神器。是研究它的力量，还是彻底摧毁？",
		"category": "story",
		"trigger": {"ruins_captured_min": 1},
		"objectives": [
			{"type": "ruins_captured_min", "value": 1, "label": "占领1处废墟"},
		],
		"reward": {"relic": "ancient_seal_fragment", "prestige": 15, "message": "封印之力现已为你所用。"},
	},
	{
		"id": "story_pirate_treasure", "name": "海盗宝藏",
		"desc": "占领港口后，你发现了一张残破的藏宝图，线索指向深海某处。",
		"category": "story",
		"trigger": {"faction": FactionData.FactionID.PIRATE, "harbor_min": 1},
		"objectives": [
			{"type": "harbor_min", "value": 1, "label": "控制1个港口"},
		],
		"reward": {"gold": 800, "plunder": 20, "message": "海底的宝藏终于重见天日！"},
	},
	{
		"id": "story_orc_shaman", "name": "萨满的仪式",
		"desc": "WAAAGH!能量积累到极点，部落萨满提出进行一场危险的仪式，可能带来强大增益或可怕诅咒。",
		"category": "story",
		"trigger": {"faction": FactionData.FactionID.ORC, "waaagh_min": 50},
		"objectives": [
			{"type": "waaagh_min", "value": 50, "label": "WAAAGH!值达到50"},
		],
		"reward": {"waaagh": 30, "buff": {"type": "atk_pct", "value": 20, "duration": 5}, "message": "萨满的仪式释放了原始之力！"},
	},
	{
		"id": "story_dark_ritual", "name": "暗神的低语",
		"desc": "当足够多的奴隶被献上祭坛，暗神的声音在你耳边响起，许诺给予禁忌之力。",
		"category": "story",
		"trigger": {"faction": FactionData.FactionID.DARK_ELF, "slaves_min": 5},
		"objectives": [
			{"type": "slaves_min", "value": 5, "label": "祭坛上拥有5名奴隶"},
		],
		"reward": {"shadow_essence": 20, "prestige": 10, "message": "暗神的力量注入了你的灵魂。"},
	},
	{
		"id": "story_elven_prisoner", "name": "精灵囚徒",
		"desc": "在森林附近的领地中发现了一名被囚禁的精灵贵族。招募她还是卖为奴隶？",
		"category": "story",
		"trigger": {"tiles_min": 8},
		"objectives": [
			{"type": "tiles_min", "value": 8, "label": "占领8个领地"},
		],
		"reward": {"gold": 300, "prestige": 10, "message": "精灵囚徒的命运已由你决定。"},
	},
	{
		"id": "story_deserter_general", "name": "叛逃的将军",
		"desc": "在你连战连胜后，一名人类将军对光明联盟失去信心，秘密联络你请求投诚。",
		"category": "story",
		"trigger": {"battles_won_min": 10},
		"objectives": [
			{"type": "battles_won_min", "value": 10, "label": "赢得10场战斗"},
		],
		"reward": {"hero": "deserter_general", "gold": 200, "message": "一位经验丰富的将军加入了你的阵营。"},
	},
	{
		"id": "story_merchant_guild", "name": "商人公会",
		"desc": "控制多个贸易站后，跨大陆商人公会主动提出独家贸易协议。",
		"category": "story",
		"trigger": {"trading_posts_min": 2},
		"objectives": [
			{"type": "trading_posts_min", "value": 2, "label": "控制2个贸易站"},
		],
		"reward": {"gold": 500, "buff": {"type": "income_pct", "value": 15, "duration": 5}, "message": "商人公会的协议生效，财源广进。"},
	},
	{
		"id": "story_cursed_mine", "name": "被诅咒的矿山",
		"desc": "占领一座矿山后，矿工报告地底传来诡异声响，疑似远古诅咒。",
		"category": "story",
		"trigger": {"mines_captured_min": 1},
		"objectives": [
			{"type": "mines_captured_min", "value": 1, "label": "占领1座矿山"},
		],
		"reward": {"iron": 80, "item": "cursed_pickaxe", "message": "矿山深处的秘密已被解开。"},
	},
	{
		"id": "story_dragon_egg", "name": "龙之卵",
		"desc": "在某处特殊领地发现了一枚龙蛋。孵化它需要漫长的时间，但出售能获得巨额财富。",
		"category": "story",
		"trigger": {"tiles_min": 12},
		"objectives": [
			{"type": "tiles_min", "value": 12, "label": "占领12个领地"},
		],
		"reward": {"item": "dragon_egg", "gold": 100, "message": "龙蛋散发着灼热的光芒。"},
	},
	{
		"id": "story_forgotten_library", "name": "被遗忘的图书馆",
		"desc": "废墟深处隐藏着一座古代图书馆，其中的知识可以大幅提升研究进度。",
		"category": "story",
		"trigger": {"ruins_captured_min": 2},
		"objectives": [
			{"type": "ruins_captured_min", "value": 2, "label": "占领2处废墟"},
		],
		"reward": {"buff": {"type": "research_speed_pct", "value": 30, "duration": 5}, "prestige": 15, "message": "古代知识的光芒照亮了前路。"},
	},
	{
		"id": "story_blood_oath", "name": "血誓挑战",
		"desc": "当你的威胁值足够高时，光明联盟的一位英雄向你发出决斗邀请。",
		"category": "story",
		"trigger": {"threat_min": 60},
		"objectives": [
			{"type": "threat_min", "value": 60, "label": "威胁值达到60"},
		],
		"reward": {"gold": 600, "item": "blood_oath_ring", "prestige": 25, "message": "决斗胜利，光明联盟士气大挫。"},
	},
	{
		"id": "story_refugee_queen", "name": "流亡的女王",
		"desc": "一位被废黜的女王带着少量随从逃到你的领地，请求庇护。收留她或出卖她都有利可图。",
		"category": "story",
		"trigger": {"tiles_min": 15},
		"objectives": [
			{"type": "tiles_min", "value": 15, "label": "占领15个领地"},
		],
		"reward": {"hero": "refugee_queen", "prestige": 20, "message": "流亡女王誓言效忠于你。"},
	},
	{
		"id": "story_haunted_battlefield", "name": "闹鬼的战场",
		"desc": "多次战斗后，你的士兵报告在旧战场上看到亡灵游荡。",
		"category": "story",
		"trigger": {"battles_won_min": 5},
		"objectives": [
			{"type": "battles_won_min", "value": 5, "label": "赢得5场战斗"},
		],
		"reward": {"gold": 250, "item": "ghost_lantern", "message": "亡魂已被安抚，留下了珍贵的遗物。"},
	},
	{
		"id": "story_underground_city", "name": "地下都市",
		"desc": "占领特定领地后发现一条通往地下的密道，深处隐藏着一座失落的城市。",
		"category": "story",
		"trigger": {"tiles_min": 18},
		"objectives": [
			{"type": "tiles_min", "value": 18, "label": "占领18个领地"},
		],
		"reward": {"gold": 500, "iron": 100, "food": 100, "message": "地下都市的资源为你所用。"},
	},
	{
		"id": "story_divine_punishment", "name": "神罚降临",
		"desc": "威胁值极高时，光明神殿发动神圣陨石打击你的领地。",
		"category": "story",
		"trigger": {"threat_min": 80},
		"objectives": [
			{"type": "threat_min", "value": 80, "label": "威胁值达到80"},
		],
		"reward": {"gold": 800, "prestige": 30, "message": "你在神罚中幸存，威望大增。"},
	},
	{
		"id": "story_traitor_within", "name": "内部叛徒",
		"desc": "随着势力扩张，你的阵营内部被发现有光明联盟的间谍。",
		"category": "story",
		"trigger": {"turn_min": 15, "tiles_min": 10},
		"objectives": [
			{"type": "tiles_min", "value": 10, "label": "占领10个领地"},
		],
		"reward": {"prestige": 15, "buff": {"type": "def_flat", "value": 2, "duration": 5}, "message": "间谍已被清除，防御加强。"},
	},
	{
		"id": "story_ancient_weapon", "name": "远古兵器",
		"desc": "占领多处废墟后，收集到足够的碎片，可以组合成一件传说级武器。",
		"category": "story",
		"trigger": {"ruins_captured_min": 3},
		"objectives": [
			{"type": "ruins_captured_min", "value": 3, "label": "占领3处废墟"},
		],
		"reward": {"item": "ancient_weapon_reforged", "prestige": 20, "message": "远古兵器重铸完成，散发着毁灭的气息。"},
	},
	{
		"id": "story_final_prophecy", "name": "终末预言",
		"desc": "完成光暗对峙后，你在遗迹中发现了一则古老预言，揭示了光明联盟的致命弱点。",
		"category": "story",
		"trigger": {"main_quest_completed": "main_4"},
		"objectives": [
			{"type": "main_quest_completed", "value": "main_4", "label": "完成主线「光暗对峙」"},
		],
		"reward": {"buff": {"type": "atk_vs_light", "value": 15, "duration": 99}, "prestige": 30, "message": "预言揭示了光明联盟的致命弱点。"},
	},
]

# ═══════════════ CATEGORY 2: BONUS QUESTS (奖励支线) — 25 quests ═══════════════
const BONUS_QUESTS: Array = [
	{
		"id": "bonus_first_blood", "name": "初战告捷",
		"desc": "赢得你的第一场战斗，证明你的军事实力。",
		"category": "bonus",
		"trigger": {},
		"objectives": [
			{"type": "battles_won_min", "value": 1, "label": "赢得1场战斗"},
		],
		"reward": {"gold": 100, "message": "首战即胜，军心大振。"},
	},
	{
		"id": "bonus_ironmonger", "name": "铁矿大亨",
		"desc": "积累大量铁矿资源，成为金属产业的霸主。",
		"category": "bonus",
		"trigger": {"turn_min": 5},
		"objectives": [
			{"type": "iron_min", "value": 200, "label": "持有200铁矿"},
		],
		"reward": {"buff": {"type": "iron_prod_pct", "value": 20, "duration": 99}, "message": "铁矿产出永久提升20%。"},
	},
	{
		"id": "bonus_gold_rush", "name": "淘金热",
		"desc": "积累巨额财富，触发经济繁荣。",
		"category": "bonus",
		"trigger": {"turn_min": 3},
		"objectives": [
			{"type": "gold_min", "value": 2000, "label": "持有2000金币"},
		],
		"reward": {"buff": {"type": "gold_prod_pct", "value": 25, "duration": 3}, "message": "金币产出在3回合内提升25%。"},
	},
	{
		"id": "bonus_speed_demon", "name": "速度恶魔",
		"desc": "在单回合内多次购买行动点，展现你的高效作风。",
		"category": "bonus",
		"trigger": {"turn_min": 3},
		"objectives": [
			{"type": "ap_purchased_min", "value": 3, "label": "单回合购买3次行动点"},
		],
		"reward": {"ap_max_bonus": 1, "message": "最大行动点永久+1。"},
	},
	{
		"id": "bonus_builder_master", "name": "建筑大师",
		"desc": "大规模建设领地，展示你的发展能力。",
		"category": "bonus",
		"trigger": {"turn_min": 5},
		"objectives": [
			{"type": "buildings_min", "value": 8, "label": "建造8座建筑"},
		],
		"reward": {"buff": {"type": "build_cost_pct", "value": -20, "duration": 99}, "message": "建筑成本永久降低20%。"},
	},
	{
		"id": "bonus_warlord", "name": "战争领主",
		"desc": "在战场上不断取得胜利，成为令人畏惧的军事强权。",
		"category": "bonus",
		"trigger": {"battles_won_min": 5},
		"objectives": [
			{"type": "battles_won_min", "value": 15, "label": "赢得15场战斗"},
		],
		"reward": {"buff": {"type": "atk_flat", "value": 1, "duration": 99}, "message": "全军ATK永久+1。"},
	},
	{
		"id": "bonus_defender", "name": "铁壁防御",
		"desc": "成功防守多个领地，证明你的防御实力。",
		"category": "bonus",
		"trigger": {"turn_min": 5},
		"objectives": [
			{"type": "tiles_defended_min", "value": 3, "label": "成功防守3个领地"},
		],
		"reward": {"buff": {"type": "def_flat", "value": 1, "duration": 99}, "message": "全军DEF永久+1。"},
	},
	{
		"id": "bonus_slaver", "name": "奴隶帝国",
		"desc": "建立庞大的奴隶体系，最大化劳动力产出。",
		"category": "bonus",
		"trigger": {"slaves_min": 10},
		"objectives": [
			{"type": "slaves_min", "value": 30, "label": "拥有30名奴隶"},
		],
		"reward": {"buff": {"type": "slave_efficiency_pct", "value": 20, "duration": 99}, "message": "奴隶效率永久提升20%。"},
	},
	{
		"id": "bonus_merchant", "name": "黑市常客",
		"desc": "频繁与黑市交易，获得商人的优惠待遇。",
		"category": "bonus",
		"trigger": {"turn_min": 5},
		"objectives": [
			{"type": "black_market_trades_min", "value": 5, "label": "在黑市交易5次"},
		],
		"reward": {"buff": {"type": "market_price_pct", "value": -15, "duration": 99}, "message": "黑市价格永久降低15%。"},
	},
	{
		"id": "bonus_explorer", "name": "探索先驱",
		"desc": "揭开大陆的迷雾，发现未知的土地。",
		"category": "bonus",
		"trigger": {"turn_min": 8},
		"objectives": [
			{"type": "fog_revealed_pct", "value": 80, "label": "揭露80%地图迷雾"},
		],
		"reward": {"buff": {"type": "vision_bonus", "value": 2, "duration": 99}, "message": "视野范围永久扩大。"},
	},
	{
		"id": "bonus_harem_5", "name": "后宫之主",
		"desc": "收集并提升多名女英雄的好感度。",
		"category": "bonus",
		"trigger": {"heroines_min": 3},
		"objectives": [
			{"type": "heroines_submission_min", "value": 5, "count": 5, "label": "5名女英雄屈服度≥5"},
		],
		"reward": {"prestige": 30, "message": "你的声望因后宫而大增。"},
	},
	{
		"id": "bonus_full_army", "name": "满编军团",
		"desc": "建立多支满员军队，形成压倒性的军事力量。",
		"category": "bonus",
		"trigger": {"army_count_min": 3},
		"objectives": [
			{"type": "total_soldiers_min", "value": 60, "label": "拥有6支满编军团（共60兵力）"},
		],
		"reward": {"buff": {"type": "morale_flat", "value": 10, "duration": 99}, "message": "全军士气永久+10。"},
	},
	{
		"id": "bonus_tech_master", "name": "科技先驱",
		"desc": "完成多项研究，掌握先进的技术。",
		"category": "bonus",
		"trigger": {"turn_min": 8},
		"objectives": [
			{"type": "researches_min", "value": 5, "label": "完成5项研究"},
		],
		"reward": {"buff": {"type": "research_speed_pct", "value": 25, "duration": 99}, "message": "研究速度永久提升25%。"},
	},
	{
		"id": "bonus_fortress_lord", "name": "要塞领主",
		"desc": "将建筑升级到最高等级，打造坚不可摧的要塞。",
		"category": "bonus",
		"trigger": {"turn_min": 10},
		"objectives": [
			{"type": "building_level_max", "value": 3, "label": "任意建筑升至3级"},
		],
		"reward": {"buff": {"type": "fortification_pct", "value": 25, "duration": 99}, "message": "要塞防御永久强化25%。"},
	},
	{
		"id": "bonus_treasure_hunter", "name": "宝藏猎人",
		"desc": "收集多张藏宝图，解锁传说级宝物。",
		"category": "bonus",
		"trigger": {"turn_min": 8},
		"objectives": [
			{"type": "treasure_maps_min", "value": 3, "label": "收集3张藏宝图"},
		],
		"reward": {"item": "legendary_random", "message": "藏宝图指引你找到了传说级宝物！"},
	},
	{
		"id": "bonus_ap_efficiency", "name": "精打细算",
		"desc": "以最少的行动点完成回合任务，展示高效的战略规划。",
		"category": "bonus",
		"trigger": {"turn_min": 5},
		"objectives": [
			{"type": "low_ap_turns_min", "value": 3, "count": 2, "label": "连续3回合每回合使用≤2行动点"},
		],
		"reward": {"buff": {"type": "ap_cost_pct", "value": -10, "duration": 99}, "message": "行动点消耗永久降低10%。"},
	},
	{
		"id": "bonus_genocide", "name": "屠杀者",
		"desc": "在战场上消灭大量敌军，让恐惧成为你的武器。",
		"category": "bonus",
		"trigger": {"battles_won_min": 5},
		"objectives": [
			{"type": "total_kills_min", "value": 100, "label": "累计消灭100名敌军"},
		],
		"reward": {"buff": {"type": "fear_debuff_enemy", "value": 10, "duration": 99}, "message": "敌军因恐惧士气永久-10。"},
	},
	{
		"id": "bonus_ironwall", "name": "铜墙铁壁",
		"desc": "在较长时间内保持领地不失，证明你的统治稳固。",
		"category": "bonus",
		"trigger": {"turn_min": 10},
		"objectives": [
			{"type": "tiles_not_lost_turns", "value": 10, "label": "连续10回合未失去任何领地"},
		],
		"reward": {"buff": {"type": "def_flat", "value": 2, "duration": 99}, "message": "全军DEF永久+2。"},
	},
	{
		"id": "bonus_blitz_king", "name": "闪电战王",
		"desc": "在单回合内发动多次进攻，以极快的速度扩张领土。",
		"category": "bonus",
		"trigger": {"turn_min": 5},
		"objectives": [
			{"type": "tiles_captured_in_turn_min", "value": 3, "label": "单回合占领3个领地"},
		],
		"reward": {"ap_max_bonus": 1, "message": "最大行动点永久+1。"},
	},
	{
		"id": "bonus_resource_hoarder", "name": "资源囤积者",
		"desc": "同时持有大量各类资源，建立坚实的经济基础。",
		"category": "bonus",
		"trigger": {"turn_min": 8},
		"objectives": [
			{"type": "gold_min", "value": 500, "label": "持有500金币"},
			{"type": "food_min", "value": 200, "label": "持有200粮食"},
			{"type": "iron_min", "value": 100, "label": "持有100铁矿"},
		],
		"reward": {"buff": {"type": "all_prod_pct", "value": 10, "duration": 99}, "message": "所有资源产出永久提升10%。"},
	},
	{
		"id": "bonus_hero_trainer", "name": "英雄导师",
		"desc": "将一名英雄培养到高等级，释放其全部潜力。",
		"category": "bonus",
		"trigger": {"heroes_min": 1},
		"objectives": [
			{"type": "hero_level_min", "value": 10, "label": "任意英雄达到10级"},
		],
		"reward": {"buff": {"type": "hero_exp_pct", "value": 20, "duration": 99}, "message": "英雄经验获取永久提升20%。"},
	},
	{
		"id": "bonus_relic_collector", "name": "遗物收藏家",
		"desc": "收集多件远古遗物，汲取它们的力量。",
		"category": "bonus",
		"trigger": {"turn_min": 10},
		"objectives": [
			{"type": "relics_min", "value": 3, "label": "拥有3件遗物"},
		],
		"reward": {"buff": {"type": "relic_effect_pct", "value": 25, "duration": 99}, "message": "遗物效果永久强化25%。"},
	},
	{
		"id": "bonus_vassal_empire", "name": "附庸帝国",
		"desc": "让多个中立势力臣服于你的统治。",
		"category": "bonus",
		"trigger": {"neutral_recruited_min": 2},
		"objectives": [
			{"type": "neutral_recruited_min", "value": 4, "label": "招募4个中立势力"},
		],
		"reward": {"buff": {"type": "vassal_prod_pct", "value": 30, "duration": 99}, "message": "附庸势力产出永久提升30%。"},
	},
	{
		"id": "bonus_public_order", "name": "太平盛世",
		"desc": "让所有领地都维持高秩序水平。",
		"category": "bonus",
		"trigger": {"tiles_min": 5, "turn_min": 8},
		"objectives": [
			{"type": "public_order_all_min", "value": 80, "label": "所有领地秩序值≥80%"},
		],
		"reward": {"buff": {"type": "gold_prod_pct", "value": 20, "duration": 5}, "message": "金币产出在5回合内提升20%。"},
	},
	{
		"id": "bonus_bounty_hunter", "name": "赏金猎人",
		"desc": "消灭大量流浪者和叛军，成为令人闻风丧胆的赏金猎人。",
		"category": "bonus",
		"trigger": {"battles_won_min": 3},
		"objectives": [
			{"type": "wanderer_kills_min", "value": 5, "label": "击败5支流浪者/叛军"},
		],
		"reward": {"buff": {"type": "wanderer_gold_pct", "value": 50, "duration": 99}, "message": "击败流浪者获得的金币永久提升50%。"},
	},
]

# ═══════════════ CATEGORY 3: INTELLIGENCE QUESTS (情报支线) — 15 quests ═══════════════
const INTEL_QUESTS: Array = [
	{
		"id": "intel_scout_network", "name": "侦察网络",
		"desc": "建造了望塔，建立初步的情报侦察体系。",
		"category": "intel",
		"trigger": {"turn_min": 3},
		"objectives": [
			{"type": "watchtowers_min", "value": 2, "label": "建造2座了望塔"},
		],
		"reward": {"reveal": 5, "message": "侦察网络已建立，揭示了5格迷雾。"},
	},
	{
		"id": "intel_spy_master", "name": "间谍大师",
		"desc": "花费金币部署间谍，获取敌军动向的关键情报。",
		"category": "intel",
		"trigger": {"turn_min": 5},
		"objectives": [
			{"type": "gold_spent_min", "value": 100, "label": "花费100金币部署间谍"},
		],
		"reward": {"buff": {"type": "reveal_enemy_armies", "value": 1, "duration": 3}, "message": "3回合内可见所有敌军位置。"},
	},
	{
		"id": "intel_enemy_plans", "name": "截获作战计划",
		"desc": "威胁值积累后，你的密探成功截获了光明联盟的下一步行动计划。",
		"category": "intel",
		"trigger": {"threat_min": 30},
		"objectives": [
			{"type": "threat_min", "value": 30, "label": "威胁值达到30"},
		],
		"reward": {"buff": {"type": "preview_expedition", "value": 1, "duration": 3}, "message": "你已知晓光明联盟下一次远征的计划。"},
	},
	{
		"id": "intel_faction_secrets", "name": "势力机密",
		"desc": "招募中立势力后，他们分享了各阵营的弱点情报。",
		"category": "intel",
		"trigger": {"neutral_recruited_min": 1},
		"objectives": [
			{"type": "neutral_recruited_min", "value": 2, "label": "招募2个中立势力"},
		],
		"reward": {"buff": {"type": "atk_vs_faction", "value": 1, "duration": 99}, "message": "获知所有阵营弱点，对应攻击永久+1。"},
	},
	{
		"id": "intel_trade_routes", "name": "贸易路线图",
		"desc": "控制贸易站后，获取了完整的大陆贸易路线情报。",
		"category": "intel",
		"trigger": {"trading_posts_min": 1},
		"objectives": [
			{"type": "trading_posts_min", "value": 2, "label": "控制2个贸易站"},
		],
		"reward": {"reveal_trade_routes": true, "message": "所有贸易路线已标记在地图上。"},
	},
	{
		"id": "intel_ancient_map", "name": "古代地图",
		"desc": "在废墟中发现了一张古代地图，标注了大片未知区域。",
		"category": "intel",
		"trigger": {"ruins_captured_min": 1},
		"objectives": [
			{"type": "ruins_captured_min", "value": 1, "label": "占领1处废墟"},
		],
		"reward": {"reveal": 10, "message": "古代地图揭示了整片区域的迷雾。"},
	},
	{
		"id": "intel_double_agent", "name": "双面间谍",
		"desc": "游戏进行一段时间后，你成功在光明联盟内部安插了一名双面间谍。",
		"category": "intel",
		"trigger": {"turn_min": 10},
		"objectives": [
			{"type": "turn_min", "value": 10, "label": "游戏进行到第10回合"},
		],
		"reward": {"buff": {"type": "reveal_threat_actions", "value": 1, "duration": 5}, "message": "5回合内可预知敌方威胁行动。"},
	},
	{
		"id": "intel_heroine_weakness", "name": "女英雄弱点",
		"desc": "俘获多名女英雄后，你从审讯中获得了光明英雄的战斗弱点情报。",
		"category": "intel",
		"trigger": {"heroines_captured_min": 1},
		"objectives": [
			{"type": "heroines_captured_min", "value": 3, "label": "俘获3名女英雄"},
		],
		"reward": {"buff": {"type": "crit_vs_heroes_pct", "value": 10, "duration": 99}, "message": "对敌方英雄暴击率永久+10%。"},
	},
	{
		"id": "intel_light_hierarchy", "name": "光明联盟指挥链",
		"desc": "攻占要塞后，缴获了光明联盟的完整指挥体系文件。",
		"category": "intel",
		"trigger": {"strongholds_min": 1},
		"objectives": [
			{"type": "strongholds_min", "value": 1, "label": "攻占1座光明要塞"},
		],
		"reward": {"buff": {"type": "ai_response_delay", "value": 1, "duration": 99}, "message": "光明联盟的反应速度永久延迟1回合。"},
	},
	{
		"id": "intel_underground_network", "name": "地下情报网",
		"desc": "利用已招募的中立势力，建立一套遍布大陆的地下情报网络。",
		"category": "intel",
		"trigger": {"neutral_recruited_min": 2},
		"objectives": [
			{"type": "neutral_recruited_min", "value": 2, "label": "招募2个中立势力"},
		],
		"reward": {"buff": {"type": "fog_reduction", "value": 3, "duration": 99}, "message": "迷雾范围永久缩减。"},
	},
	{
		"id": "intel_diplomatic_leverage", "name": "外交筹码",
		"desc": "签署条约后获取了可用于勒索的外交情报。",
		"category": "intel",
		"trigger": {"turn_min": 8},
		"objectives": [
			{"type": "treaties_signed_min", "value": 1, "label": "签署1项条约"},
		],
		"reward": {"buff": {"type": "diplomacy_cost_pct", "value": -30, "duration": 99}, "message": "外交花费永久降低30%。"},
	},
	{
		"id": "intel_war_council", "name": "军事参议",
		"desc": "大量实战经验汇编成军事情报，为全军提供战术优势。",
		"category": "intel",
		"trigger": {"battles_won_min": 10},
		"objectives": [
			{"type": "battles_won_min", "value": 20, "label": "赢得20场战斗"},
		],
		"reward": {"buff": {"type": "atk_flat", "value": 1, "duration": 5}, "message": "5回合内全军ATK+1。"},
	},
	{
		"id": "intel_enemy_weakness", "name": "敌军补给弱点",
		"desc": "在高威胁值下，你的情报人员发现了光明联盟的补给线漏洞。",
		"category": "intel",
		"trigger": {"threat_min": 50},
		"objectives": [
			{"type": "threat_min", "value": 50, "label": "威胁值达到50"},
		],
		"reward": {"buff": {"type": "enemy_def_debuff_pct", "value": -10, "duration": 99}, "message": "光明联盟防御永久降低10%。"},
	},
	{
		"id": "intel_pirate_informant", "name": "海盗线人",
		"desc": "利用海盗的恶名网络，获取大范围的情报。",
		"category": "intel",
		"trigger": {"faction": FactionData.FactionID.PIRATE, "turn_min": 8},
		"objectives": [
			{"type": "infamy_min", "value": 20, "label": "恶名值达到20"},
		],
		"reward": {"reveal": 8, "buff": {"type": "reveal_enemy_armies", "value": 1, "duration": 3}, "message": "海盗线人揭示了8格迷雾和敌军位置。"},
	},
	{
		"id": "intel_dark_whispers", "name": "暗影探知",
		"desc": "利用暗精灵的暗影魔法，感知所有英雄的位置。",
		"category": "intel",
		"trigger": {"faction": FactionData.FactionID.DARK_ELF, "turn_min": 8},
		"objectives": [
			{"type": "shadow_essence_min", "value": 15, "label": "暗影精华达到15"},
		],
		"reward": {"buff": {"type": "reveal_all_heroes", "value": 1, "duration": 99}, "message": "暗影魔法持续探知所有英雄位置。"},
	},
]

# ═══════════════ CATEGORY 4: WORLD EVENTS (世界局势事件) — 20 quests ═══════════════
const WORLD_EVENTS: Array = [
	{
		"id": "world_orc_human_war", "name": "兽人入侵人类王国",
		"desc": "兽人部落对人类王国发动了大规模进攻，整个大陆的力量格局正在改变。",
		"category": "world",
		"trigger": {"turn_min": 8, "orc_faction_exists": true},
		"choices": [
			{"text": "支援兽人（兽人ATK+2持续5回合，人类敌视你）", "effects": {"buff_faction_orc": {"type": "atk_flat", "value": 2, "duration": 5}, "threat": 10}},
			{"text": "保持中立（双方小幅增益）", "effects": {"gold": 100}},
		],
		"ai_effects": {"orc_atk_bonus": 2, "orc_bonus_duration": 5, "human_def_bonus": 2, "human_bonus_duration": 5},
	},
	{
		"id": "world_orc_elf_war", "name": "兽人入侵精灵森林",
		"desc": "兽人部落将矛头指向了精灵的古老森林，战火蔓延至林地深处。",
		"category": "world",
		"trigger": {"turn_min": 12, "orc_faction_exists": true},
		"choices": [
			{"text": "趁火打劫（获得1个临时要塞领地）", "effects": {"temp_fortress_tile": 1, "threat": 5}},
			{"text": "静观其变（获取战场情报）", "effects": {"reveal": 5}},
		],
		"ai_effects": {"orc_gains_temp_fortress": true, "elf_territory_reduced": 1},
	},
	{
		"id": "world_pirate_blockade", "name": "海盗封锁航线",
		"desc": "海盗势力封锁了主要贸易航线，所有阵营的经济都受到了冲击。",
		"category": "world",
		"trigger": {"turn_min": 10, "pirate_faction_exists": true},
		"choices": [
			{"text": "打破封锁（花费200金，获得贸易独占权）", "effects": {"gold": -200, "buff": {"type": "gold_prod_pct", "value": 30, "duration": 3}}},
			{"text": "利用封锁（走私获利）", "effects": {"gold": 150}},
		],
		"ai_effects": {"all_factions_gold_income_pct": -15, "duration": 3},
	},
	{
		"id": "world_dark_elf_ritual", "name": "暗精灵大规模仪式",
		"desc": "暗精灵在各地同时进行大规模暗影仪式，黑暗能量笼罩了大陆。",
		"category": "world",
		"trigger": {"turn_min": 15, "dark_elf_faction_exists": true},
		"choices": [
			{"text": "汲取暗影能量（+10暗影精华，但威胁+15）", "effects": {"shadow_essence": 10, "threat": 15}},
			{"text": "抵抗暗影侵蚀（保持稳定，秩序+5）", "effects": {"order": 5}},
		],
		"ai_effects": {"dark_elf_shadow_essence": 10, "global_threat_increase": 5},
	},
	{
		"id": "world_holy_crusade", "name": "光明圣战",
		"desc": "光明联盟发动了一场规模空前的圣战，集结所有力量对抗黑暗势力。",
		"category": "world",
		"trigger": {"threat_min": 70},
		"choices": [
			{"text": "主动迎击（大型战斗，胜利后威胁-20）", "effects": {"type": "combat", "enemy_soldiers": 25, "on_win": {"threat": -20, "prestige": 30}}},
			{"text": "固守要塞（放弃2个边境领地，但保存主力）", "effects": {"lose_nodes": 2, "buff": {"type": "def_flat", "value": 3, "duration": 3}}},
		],
		"ai_effects": {"light_alliance_atk_bonus": 3, "light_bonus_duration": 5, "massive_expedition": true},
	},
	{
		"id": "world_plague_outbreak", "name": "大陆瘟疫",
		"desc": "一场可怕的瘟疫席卷整个大陆，所有阵营都损失惨重。",
		"category": "world",
		"trigger": {"turn_min": 10},
		"choices": [
			{"text": "严格隔离（-5奴隶，但保全军队）", "effects": {"slaves": -5}},
			{"text": "放任不管（军队损失10%，但经济不受影响）", "effects": {"soldiers_pct": -10}},
		],
		"ai_effects": {"all_factions_soldiers_pct": -10},
	},
	{
		"id": "world_meteor_strike", "name": "天降陨石",
		"desc": "一颗巨大的陨石撞击了大陆某处，摧毁了地表建筑，但留下了珍贵的战略资源。",
		"category": "world",
		"trigger": {"turn_min": 20},
		"choices": [
			{"text": "派军队占领陨石坑（获取稀有资源）", "effects": {"iron": 80, "magic_crystal": 5, "threat": 5}},
			{"text": "出售陨石坑位置情报（+300金）", "effects": {"gold": 300}},
		],
		"ai_effects": {"random_tile_destroyed": true, "strategic_resource_spawned": true},
	},
	{
		"id": "world_dragon_awakening", "name": "远古巨龙苏醒",
		"desc": "沉睡万年的远古巨龙从废墟深处苏醒，整个大陆都在颤抖。",
		"category": "world",
		"trigger": {"turn_min": 25, "ruins_captured_min": 1},
		"choices": [
			{"text": "挑战巨龙（Boss战斗，胜利获传说装备）", "effects": {"type": "combat", "enemy_soldiers": 30, "boss": true, "on_win": {"item": "dragon_slayer_sword", "prestige": 50}}},
			{"text": "献上贡品（-500金，巨龙离开）", "effects": {"gold": -500}},
		],
		"ai_effects": {"dragon_terrorizes_map": true, "random_tiles_damaged": 3},
	},
	{
		"id": "world_neutral_alliance", "name": "中立势力联盟",
		"desc": "未被招募的中立势力感到威胁，结成了反玩家联盟。",
		"category": "world",
		"trigger": {"turn_min": 15, "unrecruited_neutrals_min": 2},
		"choices": [
			{"text": "外交瓦解（花费300金拉拢其中一个）", "effects": {"gold": -300, "neutral_recruited": 1}},
			{"text": "武力威慑（提升威胁，但吓退部分势力）", "effects": {"threat": 10, "buff": {"type": "atk_flat", "value": 2, "duration": 3}}},
		],
		"ai_effects": {"neutral_alliance_formed": true, "neutral_hostility_increase": 20},
	},
	{
		"id": "world_trade_boom", "name": "贸易繁荣",
		"desc": "大陆迎来了一个难得的贸易繁荣期，所有阵营都从中受益。",
		"category": "world",
		"trigger": {"turn_min": 5, "turn_max": 15},
		"choices": [
			{"text": "加大投资（-100金，产出+30%持续3回合）", "effects": {"gold": -100, "buff": {"type": "all_prod_pct", "value": 30, "duration": 3}}},
			{"text": "稳健经营（产出+20%持续3回合）", "effects": {"buff": {"type": "all_prod_pct", "value": 20, "duration": 3}}},
		],
		"ai_effects": {"all_factions_prod_pct": 20, "duration": 3},
	},
	{
		"id": "world_famine", "name": "大陆饥荒",
		"desc": "严重的自然灾害导致大陆性饥荒，粮食成为最紧缺的资源。",
		"category": "world",
		"trigger": {"turn_min": 12},
		"choices": [
			{"text": "开仓赈灾（-50粮食，秩序+10，威望+15）", "effects": {"food": -50, "order": 10, "prestige": 15}},
			{"text": "囤积粮食（粮食不减，但秩序-5）", "effects": {"order": -5}},
		],
		"ai_effects": {"all_factions_food_prod_pct": -30, "duration": 3},
	},
	{
		"id": "world_arms_race", "name": "军备竞赛",
		"desc": "光明联盟开始大规模升级军备，你需要加紧应对。",
		"category": "world",
		"trigger": {"threat_min": 40},
		"choices": [
			{"text": "跟进军备升级（-100铁，全军ATK+2持续5回合）", "effects": {"iron": -100, "buff": {"type": "atk_flat", "value": 2, "duration": 5}}},
			{"text": "外交斡旋（花费200金，延缓敌军升级）", "effects": {"gold": -200, "buff": {"type": "ai_response_delay", "value": 2, "duration": 3}}},
		],
		"ai_effects": {"light_units_upgrade_tier": 1, "player_iron_grant": 50},
	},
	{
		"id": "world_civil_war", "name": "光明联盟内战",
		"desc": "当你的威胁较低时，光明联盟内部因权力分配爆发了内战。",
		"category": "world",
		"trigger": {"turn_min": 20, "threat_max": 40},
		"choices": [
			{"text": "支持一方（获得盟友，但另一方敌视）", "effects": {"neutral_recruited": 1, "threat": 10}},
			{"text": "两面下注（双方都给小好处）", "effects": {"gold": 200, "prestige": 10}},
		],
		"ai_effects": {"light_alliance_split": true, "two_weaker_factions": true},
	},
	{
		"id": "world_dark_alliance", "name": "黑暗联盟",
		"desc": "当多个邪恶势力被招募后，它们自发形成了黑暗联盟，互相增强。",
		"category": "world",
		"trigger": {"turn_min": 15, "evil_factions_recruited_min": 2},
		"choices": [
			{"text": "领导联盟（成为盟主，全军ATK+2）", "effects": {"buff": {"type": "atk_flat", "value": 2, "duration": 99}, "prestige": 20}},
			{"text": "保持独立（获得资源但不结盟）", "effects": {"gold": 300, "iron": 50}},
		],
		"ai_effects": {"evil_factions_mutual_atk_bonus": 2},
	},
	{
		"id": "world_elven_exodus", "name": "精灵大迁徙",
		"desc": "精灵王国决定放弃部分领地向西迁徙，留下大片空旷的森林领地。",
		"category": "world",
		"trigger": {"turn_min": 18},
		"choices": [
			{"text": "立即占领空地（获得2个森林领地）", "effects": {"free_forest_tiles": 2, "threat": 5}},
			{"text": "与精灵交涉（获得精灵科技）", "effects": {"buff": {"type": "research_speed_pct", "value": 20, "duration": 5}}},
		],
		"ai_effects": {"elf_territory_abandoned": 3, "open_tiles_available": true},
	},
	{
		"id": "world_dwarven_vault", "name": "矮人宝库开启",
		"desc": "你招募的矮人势力决定打开他们隐藏千年的宝库，共享资源。",
		"category": "world",
		"trigger": {"turn_min": 12, "dwarf_recruited": true},
		"choices": [
			{"text": "索取军事物资（+100铁，+5火药）", "effects": {"iron": 100, "gunpowder": 5}},
			{"text": "索取财富（+400金）", "effects": {"gold": 400}},
		],
		"ai_effects": {"dwarf_vault_opened": true, "dwarf_loyalty_increase": 10},
	},
	{
		"id": "world_blood_moon", "name": "血月之夜",
		"desc": "天空被血红的月光笼罩，所有生物变得狂暴而脆弱。",
		"category": "world",
		"trigger": {"turn_min": 10, "random_chance": 0.10},
		"choices": [
			{"text": "借血月之力进攻（ATK+3，DEF-2，持续1回合）", "effects": {"buff": {"type": "atk_flat", "value": 3, "duration": 1}, "debuff": {"type": "def_flat", "value": -2, "duration": 1}}},
			{"text": "龟缩防守（无增减益）", "effects": {}},
		],
		"ai_effects": {"all_units_atk_bonus": 3, "all_units_def_penalty": 2, "duration": 1},
	},
	{
		"id": "world_eclipse", "name": "日蚀降临",
		"desc": "罕见的日蚀打断了大陆的魔法流动，但暗影单位反而因此获得了力量。",
		"category": "world",
		"trigger": {"turn_min": 15, "random_chance": 0.05},
		"choices": [
			{"text": "利用暗影力量（暗影单位ATK+4，持续2回合）", "effects": {"buff": {"type": "shadow_atk_flat", "value": 4, "duration": 2}}},
			{"text": "保存魔力（2回合后获得双倍魔力恢复）", "effects": {"buff": {"type": "mana_regen_pct", "value": 100, "duration": 2}}},
		],
		"ai_effects": {"magic_disrupted": true, "no_mana_duration": 2, "shadow_units_atk_bonus": 4},
	},
	{
		"id": "world_harvest_festival", "name": "丰收祭典",
		"desc": "大陆迎来了定期的丰收季节，各地举办庆典。",
		"category": "world",
		"trigger": {"turn_exact": [8, 16, 24]},
		"choices": [
			{"text": "举办盛大庆典（-30金，士气+15，粮食+80）", "effects": {"gold": -30, "food": 80, "buff": {"type": "morale_flat", "value": 15, "duration": 3}}},
			{"text": "低调庆祝（粮食+50，士气+10）", "effects": {"food": 50, "buff": {"type": "morale_flat", "value": 10, "duration": 2}}},
		],
		"ai_effects": {"all_factions_food": 50, "all_factions_morale": 10},
	},
	{
		"id": "world_mercenary_influx", "name": "佣兵涌入",
		"desc": "你的军事成就吸引了大量佣兵前来投奔，雇佣费用大幅降低。",
		"category": "world",
		"trigger": {"turn_min": 10, "battles_won_min": 5},
		"choices": [
			{"text": "大量雇佣（-100金，+10临时兵力）", "effects": {"gold": -100, "temp_soldiers": 10}},
			{"text": "精挑细选（-50金，+5永久兵力）", "effects": {"gold": -50, "soldiers": 5}},
		],
		"ai_effects": {"mercenary_costs_pct": -50, "duration": 3},
	},
]
