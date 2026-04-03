## expanded_random_events.gd - 30 additional random events for Dark Tide SLG (v4.0)
## Supplements event_system.gd with military, social, supernatural, and economic events.
extends Node



func get_expanded_events() -> Array:
	var events: Array = []
	# -- MILITARY EVENTS (8) --
	events.append({
		"id": "exp_deserter_officer", "name": "逃兵军官",
		"desc": "一名敌方逃兵军官请求庇护，声称掌握重要军事情报。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "收编 (+1英雄ATK)", "effects": {"hero_stat": {"stat": "atk", "value": 1}}},
			{"text": "审讯后处决 (+10威望)", "effects": {"prestige": 10}},
		]
	})
	events.append({
		"id": "exp_captured_spy", "name": "捕获密探",
		"desc": "巡逻队抓获了一名敌方密探，身上携带密信。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "审讯获取情报 (揭示邻近地块)", "effects": {"reveal": 2}},
			{"text": "放走以示善意 (+15外交声望)", "effects": {"prestige": 15}},
		]
	})
	events.append({
		"id": "exp_arms_dealer", "name": "军火商人",
		"desc": "一名走私商带来了一批上等武器装备。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "购买 (-80金, +5兵力, ATK+10% 3回合)", "effects": {"gold": -80, "soldiers": 5, "buff": {"type": "atk", "value": 10, "duration": 3}}},
			{"text": "没收充公 (+30铁, 秩序-3)", "effects": {"iron": 30, "order": -3}},
		]
	})
	events.append({
		"id": "exp_training_accident", "name": "训练事故",
		"desc": "一次军事训练中发生了严重事故，多名士兵受伤。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "加强安全 (-20金, 秩序+2)", "effects": {"gold": -20, "order": 2}},
			{"text": "继续高强度训练 (-2兵, ATK+15% 5回合)", "effects": {"soldiers": -2, "buff": {"type": "atk", "value": 15, "duration": 5}}},
		]
	})
	events.append({
		"id": "exp_veteran_soldiers", "name": "老兵归来",
		"desc": "一群退役老兵听闻战事，自愿重新参军。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "欣然接纳 (+4兵力)", "effects": {"soldiers": 4}},
			{"text": "委以重任 (+2兵力, DEF+10% 3回合)", "effects": {"soldiers": 2, "buff": {"type": "def", "value": 10, "duration": 3}}},
		]
	})
	events.append({
		"id": "exp_mercenary_captain", "name": "佣兵团长",
		"desc": "一位声名远扬的佣兵团长愿意为你效力——但代价不菲。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "雇佣 (-100金, +8临时兵力3回合)", "effects": {"gold": -100, "type": "temp_soldiers", "count": 8, "duration": 3}},
			{"text": "拒绝 (他可能转投敌方)", "effects": {}},
		]
	})
	events.append({
		"id": "exp_war_profiteer", "name": "战争奸商",
		"desc": "有人在大量囤积军用物资哄抬物价。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "查抄仓库 (+40铁, +30粮, 秩序-2)", "effects": {"iron": 40, "food": 30, "order": -2}},
			{"text": "征收重税 (+60金)", "effects": {"gold": 60}},
		]
	})
	events.append({
		"id": "exp_siege_engineers", "name": "攻城工匠",
		"desc": "一队精通攻城器械的工匠前来投奔。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "雇佣建造攻城器 (-50金, ATK+20% 3回合)", "effects": {"gold": -50, "buff": {"type": "atk", "value": 20, "duration": 3}}},
			{"text": "让他们修筑城防 (-30金, DEF+20% 5回合)", "effects": {"gold": -30, "buff": {"type": "def", "value": 20, "duration": 5}}},
		]
	})
	# -- SOCIAL EVENTS (8) --
	events.append({
		"id": "exp_festival", "name": "丰收庆典",
		"desc": "领民自发组织了一场盛大的庆祝活动。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "赞助庆典 (-30金, 秩序+5, 威望+10)", "effects": {"gold": -30, "order": 5, "prestige": 10}},
			{"text": "禁止集会 (秩序-3, +20金税收)", "effects": {"order": -3, "gold": 20}},
		]
	})
	events.append({
		"id": "exp_witch_hunt", "name": "猎巫运动",
		"desc": "民间兴起了一股猎巫狂热，多名妇女被指控为女巫。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "制止暴行 (秩序+3, 威望+5)", "effects": {"order": 3, "prestige": 5}},
			{"text": "顺势而为 (秩序-2, +2奴隶)", "effects": {"order": -2, "slaves": 2}},
		]
	})
	events.append({
		"id": "exp_religious_schism", "name": "教派分裂",
		"desc": "领地内两大教派爆发严重冲突，信众对立。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "调停斡旋 (-20金, 秩序+4)", "effects": {"gold": -20, "order": 4}},
			{"text": "打压一方 (秩序-3, +30金没收财产)", "effects": {"order": -3, "gold": 30}},
		]
	})
	events.append({
		"id": "exp_peasant_hero", "name": "草莽英雄",
		"desc": "一位农民在抵抗盗匪时表现出惊人的战斗才能。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "提拔为军官 (+3兵力, 秩序+2)", "effects": {"soldiers": 3, "order": 2}},
			{"text": "赐予田地 (秩序+5)", "effects": {"order": 5}},
		]
	})
	events.append({
		"id": "exp_merchant_caravan", "name": "商队驻留",
		"desc": "一支大型商队途经你的领地，愿意进行贸易。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "贸易往来 (-20铁, +60金)", "effects": {"iron": -20, "gold": 60}},
			{"text": "征收通行税 (+25金, 威望-5)", "effects": {"gold": 25, "prestige": -5}},
		]
	})
	events.append({
		"id": "exp_bards_tale", "name": "吟游诗人",
		"desc": "一位著名的吟游诗人来到你的领地，愿意为你传颂功绩。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "资助创作 (-15金, 威望+20)", "effects": {"gold": -15, "prestige": 20}},
			{"text": "让他歌颂军威 (-10金, ATK+5% 5回合)", "effects": {"gold": -10, "buff": {"type": "atk", "value": 5, "duration": 5}}},
		]
	})
	events.append({
		"id": "exp_noble_exile", "name": "流亡贵族",
		"desc": "一位被推翻的邻国贵族携带财宝前来寻求庇护。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "接纳 (+50金, 威望+10, 可能引来追兵)", "effects": {"gold": 50, "prestige": 10}},
			{"text": "驱逐 (威望-5)", "effects": {"prestige": -5}},
		]
	})
	events.append({
		"id": "exp_bandit_surrender", "name": "匪首归降",
		"desc": "盘踞山林的匪首派人前来表示愿意归降。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "接受投降 (+5兵力, 秩序-2)", "effects": {"soldiers": 5, "order": -2}},
			{"text": "围剿灭之 (-3兵力, 秩序+4, +20金)", "effects": {"soldiers": -3, "order": 4, "gold": 20}},
		]
	})
	# -- SUPERNATURAL EVENTS (8) --
	events.append({
		"id": "exp_haunted_ruins", "name": "闹鬼废墟",
		"desc": "领地边缘的废墟中传出诡异的哭声，士兵不敢靠近。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "派人调查 (50%+1遗物, 50%-3兵)", "effects": {"type": "gamble", "success_rate": 0.5, "success": {"relic": true}, "fail": {"soldiers": -3}}},
			{"text": "封锁区域 (秩序+2)", "effects": {"order": 2}},
		]
	})
	events.append({
		"id": "exp_dragon_sighting", "name": "巨龙目击",
		"desc": "有人声称在山脉上空看到了巨龙的身影，全城恐慌。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "悬赏猎龙 (-50金, 威望+15)", "effects": {"gold": -50, "prestige": 15}},
			{"text": "安抚民心 (秩序-3, -10金)", "effects": {"order": -3, "gold": -10}},
		]
	})
	events.append({
		"id": "exp_magic_well", "name": "魔力之泉",
		"desc": "发现一口散发着魔力光芒的古井，水中蕴含神秘力量。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "汲取魔力 (+3魔晶)", "effects": {"magic_crystal": 3}},
			{"text": "封印水源 (秩序+3, DEF+10% 3回合)", "effects": {"order": 3, "buff": {"type": "def", "value": 10, "duration": 3}}},
		]
	})
	events.append({
		"id": "exp_cursed_artifact", "name": "受诅圣物",
		"desc": "士兵从战场上捡回了一件散发着黑暗气息的古老神器。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "研究利用 (ATK+25% 3回合, 秩序-4)", "effects": {"buff": {"type": "atk", "value": 25, "duration": 3}, "order": -4}},
			{"text": "销毁净化 (秩序+3, 威望+5)", "effects": {"order": 3, "prestige": 5}},
		]
	})
	events.append({
		"id": "exp_spirit_shrine", "name": "精灵祭坛",
		"desc": "森林深处发现了一座古老的精灵祭坛，散发着柔和光芒。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "祈祷祝福 (全军HP恢复, DEF+10% 3回合)", "effects": {"buff": {"type": "def", "value": 10, "duration": 3}}},
			{"text": "拆除取材 (+25铁, +15金)", "effects": {"iron": 25, "gold": 15}},
		]
	})
	events.append({
		"id": "exp_blood_rain", "name": "血色之雨",
		"desc": "天空降下了血色的雨水，大地被染成猩红。不祥的预兆！",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "举行驱邪仪式 (-20金, -2奴隶, 秩序+3)", "effects": {"gold": -20, "slaves": -2, "order": 3}},
			{"text": "借势宣传 (威望+10, 秩序-3)", "effects": {"prestige": 10, "order": -3}},
		]
	})
	events.append({
		"id": "exp_ancient_guardian", "name": "远古守卫",
		"desc": "领地地下发掘出一具远古魔像，似乎可以重新激活。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "激活魔像 (-3魔晶, +6兵力, DEF+15% 3回合)", "effects": {"magic_crystal": -3, "soldiers": 6, "buff": {"type": "def", "value": 15, "duration": 3}}},
			{"text": "拆解研究 (+40铁, +2魔晶)", "effects": {"iron": 40, "magic_crystal": 2}},
		]
	})
	events.append({
		"id": "exp_dimensional_rift", "name": "次元裂隙",
		"desc": "空间出现了一道不稳定的裂缝，奇异的能量不断涌出。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "探索裂隙 (70%+遗物+5魔晶, 30%-5兵)", "effects": {"type": "gamble", "success_rate": 0.7, "success": {"relic": true, "magic_crystal": 5}, "fail": {"soldiers": -5}}},
			{"text": "封闭裂隙 (秩序+4, 威望+5)", "effects": {"order": 4, "prestige": 5}},
		]
	})
	# -- ECONOMIC EVENTS (6) --
	events.append({
		"id": "exp_gold_rush", "name": "淘金热",
		"desc": "领地内发现了金矿脉，大量人口涌入淘金。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "国有开采 (+80金, 秩序-2)", "effects": {"gold": 80, "order": -2}},
			{"text": "开放民采 (+40金, 秩序+2, 威望+5)", "effects": {"gold": 40, "order": 2, "prestige": 5}},
		]
	})
	events.append({
		"id": "exp_trade_monopoly", "name": "贸易垄断",
		"desc": "一个商会试图垄断领地内的所有贸易活动。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "允许垄断 (+60金/回合x3, 秩序-3)", "effects": {"type": "dot", "gold": 20, "duration": 3, "order": -3}},
			{"text": "打破垄断 (-20金, 秩序+3, 威望+10)", "effects": {"gold": -20, "order": 3, "prestige": 10}},
		]
	})
	events.append({
		"id": "exp_resource_discovery", "name": "资源发现",
		"desc": "勘探队在领地深处发现了丰富的矿藏。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "开采铁矿 (+50铁)", "effects": {"iron": 50}},
			{"text": "开采金矿 (+40金)", "effects": {"gold": 40}},
		]
	})
	events.append({
		"id": "exp_economic_crisis", "name": "经济危机",
		"desc": "领地经济陷入低迷，商铺纷纷关门歇业。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "减税刺激 (-30金, 秩序+4)", "effects": {"gold": -30, "order": 4}},
			{"text": "强制征税 (+50金, 秩序-5)", "effects": {"gold": 50, "order": -5}},
		]
	})
	events.append({
		"id": "exp_currency_devaluation", "name": "货币贬值",
		"desc": "邻国大量铸造劣质货币流入市场，物价飞涨。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "铸新币稳经济 (-40金, 秩序+3, 威望+10)", "effects": {"gold": -40, "order": 3, "prestige": 10}},
			{"text": "趁机囤积物资 (-30金, +30铁, +20粮)", "effects": {"gold": -30, "iron": 30, "food": 20}},
		]
	})
	events.append({
		"id": "exp_foreign_investment", "name": "外邦投资",
		"desc": "一位异国富商愿意在你的领地投资建设。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "接受投资 (+70金, +20粮, 威望-5)", "effects": {"gold": 70, "food": 20, "prestige": -5}},
			{"text": "婉拒 (威望+10)", "effects": {"prestige": 10}},
		]
	})
	# -- NEW CONTENT v5.1: Additional random events (8) --
	events.append({
		"id": "exp_wandering_swordsman", "name": "流浪剑客",
		"desc": "一位身背巨剑的流浪武士来到你的领地，他目光锐利，浑身散发着战场的气息。他提出要么加入你的军队，要么在此一战以证明自己的实力。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "招募他 (-30金, +4兵力, ATK+10% 3回合)", "effects": {"gold": -30, "soldiers": 4, "buff": {"type": "atk", "value": 10, "duration": 3}}},
			{"text": "接受挑战 (战斗: 3精锐兵, 胜利+15威望+1遗物)", "effects": {"type": "combat", "enemy_soldiers": 3, "enemy_type": "elite_guard"}},
		]
	})
	events.append({
		"id": "exp_plague_spreads", "name": "瘟疫蔓延",
		"desc": "一场不明瘟疫在领地内蔓延，百姓纷纷倒下。堆积的尸体需要焚烧处理，但火葬堆中发现了铁矿石——死者的随身物品。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "全力抗疫 (-30金, -15粮, 秩序+5)", "effects": {"gold": -30, "food": -15, "order": 5}},
			{"text": "收集火葬物资 (-20粮, +25铁, 秩序-4)", "effects": {"food": -20, "iron": 25, "order": -4}},
		]
	})
	events.append({
		"id": "exp_dwarven_caravan", "name": "矮人商队",
		"desc": "一支矮人商队敲响了城门。他们携带着精良的矮人工艺品和稀有矿石，愿意与你进行公平交易。矮人的锻造术举世闻名。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "用金币交易 (-50金, +1遗物, +20铁)", "effects": {"gold": -50, "relic": true, "iron": 20}},
			{"text": "用粮食交易 (-25粮, +35铁, DEF+10% 3回合)", "effects": {"food": -25, "iron": 35, "buff": {"type": "def", "value": 10, "duration": 3}}},
		]
	})
	events.append({
		"id": "exp_eclipse_omen", "name": "月蚀凶兆",
		"desc": "天空突然暗沉，一轮血色月蚀笼罩大地。士兵们惶恐不安，但领地内的神秘学者声称这是强化预言力量的绝佳时机。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "安抚军心 (-15金, 秩序+3, DEF-5% 2回合)", "effects": {"gold": -15, "order": 3, "buff": {"type": "def", "value": -5, "duration": 2}}},
			{"text": "利用月蚀进行占卜 (-2魔晶, 揭示3格迷雾, 事件品质提升)", "effects": {"magic_crystal": -2, "reveal": 3}},
		]
	})
	events.append({
		"id": "exp_rebels_surrender", "name": "叛军归顺",
		"desc": "盘踞山区的叛军派出使者，声称若你能保证他们的安全，愿意放下武器归顺。你的秩序声望让他们心生畏惧。",
		"condition": "order_above_60", "repeatable": true,
		"choices": [
			{"text": "接纳归顺 (+6兵力, 秩序+2)", "effects": {"soldiers": 6, "order": 2}},
			{"text": "要求缴械并交出财物 (+3兵力, +30金, 秩序-2)", "effects": {"soldiers": 3, "gold": 30, "order": -2}},
		]
	})
	events.append({
		"id": "exp_ancient_treasury", "name": "古代宝库",
		"desc": "探险队在地下发现了一座古代宝库，大门上刻满了警告铭文。宝库中似乎蕴藏着惊人的财富，但也可能暗藏诅咒。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "强行开启 (60%: +100金+1遗物, 40%: -5兵-10秩序)", "effects": {"type": "gamble", "success_rate": 0.6, "success": {"gold": 100, "relic": true}, "fail": {"soldiers": -5, "order": -10}}},
			{"text": "谨慎探索 (+40金, +15铁)", "effects": {"gold": 40, "iron": 15}},
		]
	})
	events.append({
		"id": "exp_elven_emissary", "name": "精灵密使",
		"desc": "一位高等精灵密使悄然来访，她代表远方的精灵议会，希望与你建立秘密外交关系。精灵的知识和魔法都是极为宝贵的资源。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "接受外交提案 (+15威望, +2魔晶, 揭示2格)", "effects": {"prestige": 15, "magic_crystal": 2, "reveal": 2}},
			{"text": "请求贸易协定 (+40金, +10粮, 威望+5)", "effects": {"gold": 40, "food": 10, "prestige": 5}},
		]
	})
	events.append({
		"id": "exp_volcanic_eruption", "name": "火山爆发",
		"desc": "领地边缘的休眠火山突然喷发！熔岩流向农田和矿区，但火山灰下也暴露出了深层矿脉和稀有晶体。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "全力救灾 (-40金, -10粮, 秩序+5, +20铁)", "effects": {"gold": -40, "food": -10, "order": 5, "iron": 20}},
			{"text": "趁机开采暴露矿脉 (+50铁, +3魔晶, 秩序-6, -5粮)", "effects": {"iron": 50, "magic_crystal": 3, "order": -6, "food": -5}},
		]
	})
	return events
