## extra_events_v5.gd — 50 events: 10 three-step narrative chains (30) + 20 standalone
## Auto-registers with EventSystem on _ready().
## Chain events use "chain:parent_id:choice" condition format.
## Each chain: Step 1 (trigger) → Step 2 (2-4 turns later) → Step 3 (2-4 turns after step 2)
extends Node

func _ready() -> void:
	call_deferred("register_with_event_system")
	if EventRegistry:
		EventRegistry._register_source("extra_events_v5", get_events(), "chain_v5")

func register_with_event_system() -> void:
	if not EventSystem:
		push_warning("ExtraEventsV5: EventSystem not available")
		return
	var events: Array = get_events()
	for ev in events:
		EventSystem._events.append(ev)

func get_events() -> Array:
	var events: Array = []

	# ══════════════════════════════════════════════════════════
	# CHAIN 1: 宫廷阴谋 (Court Conspiracy) — 3 steps
	# Path A: 暗中监视 → 揭露主谋 → 政变/收服
	# Path B: 大规模清洗 → 冤案风波 → 平反/镇压
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_court_conspiracy", "name": "宫廷阴谋·密报",
		"desc": "一名密探传来消息——宫廷内部有人正密谋叛变。大臣们争论不休，有人主张雷厉风行，有人建议暗中调查。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "大规模清洗 (-10秩序, +15威望)", "effects": {"order": -10, "prestige": 15}},
			{"text": "暗中监视，放长线钓大鱼 (+5威望)", "effects": {"prestige": 5}},
		]
	})
	events.append({
		"id": "v5_court_conspiracy_s2a", "name": "宫廷阴谋·冤案",
		"desc": "清洗行动过于激烈——数位忠臣被误杀，他们的家族在暗中集结力量。街头出现了控诉暴政的檄文。",
		"condition": "chain:v5_court_conspiracy:0", "repeatable": false,
		"chain_parent": "v5_court_conspiracy", "chain_choice": 0,
		"choices": [
			{"text": "公开道歉并赔偿 (-40金, +12秩序, -5威望)", "effects": {"gold": -40, "order": 12, "prestige": -5}},
			{"text": "变本加厉镇压 (-15秩序, +20威望, +3兵)", "effects": {"order": -15, "prestige": 20, "soldiers": 3}},
		]
	})
	events.append({
		"id": "v5_court_conspiracy_s2b", "name": "宫廷阴谋·幕后黑手",
		"desc": "数周的监视终于有了结果——密探查明叛乱的主谋竟是你最信赖的财务大臣。他已经秘密联络了三个贵族家族。",
		"condition": "chain:v5_court_conspiracy:1", "repeatable": false,
		"chain_parent": "v5_court_conspiracy", "chain_choice": 1,
		"choices": [
			{"text": "证据确凿，公开审判 (+20威望, +8秩序, -10金)", "effects": {"prestige": 20, "order": 8, "gold": -10}},
			{"text": "私下谈判，收服为己用 (-30金, +1科技点, 威胁+3)", "effects": {"gold": -30, "tech_point": 1, "threat": 3}},
		]
	})
	events.append({
		"id": "v5_court_conspiracy_s3_purge", "name": "宫廷阴谋·叛军起义",
		"desc": "变本加厉的镇压终于引爆了危机——被清洗的贵族家族联合起来，在城外集结了一支叛军！他们打着\"诛杀暴君\"的旗号向你的据点进发。必须迎战！",
		"condition": "chain:v5_court_conspiracy_s2a:1", "repeatable": false,
		"chain_parent": "v5_court_conspiracy_s2a", "chain_choice": 1,
		"choices": [
			{"text": "亲率精锐迎击叛军 (战斗: 10叛军, 胜利+30威望+20金)", "effects": {"type": "combat", "enemy_soldiers": 10, "enemy_type": "rebels"}},
			{"text": "据城死守，等待援军 (战斗: 7叛军, DEF+20%, 胜利+15秩序)", "effects": {"type": "combat", "enemy_soldiers": 7, "enemy_type": "rebels", "buff": {"type": "def_pct", "value": 20, "duration": 1}}},
		]
	})
	events.append({
		"id": "v5_court_conspiracy_s3_trial", "name": "宫廷阴谋·审判之后",
		"desc": "公开审判震慑了所有人。被处决的财务大臣留下了一本密账，记载着大量秘密交易和隐藏资产。",
		"condition": "chain:v5_court_conspiracy_s2b:0", "repeatable": false,
		"chain_parent": "v5_court_conspiracy_s2b", "chain_choice": 0,
		"choices": [
			{"text": "追查密账中的隐藏资产 (+60金, +1遗物)", "effects": {"gold": 60, "relic": true}},
			{"text": "销毁密账以安人心 (+10秩序, +10威望)", "effects": {"order": 10, "prestige": 10}},
		]
	})

	# ══════════════════════════════════════════════════════════
	# CHAIN 2: 异国公主 (Foreign Princess) — 3 steps
	# Path A: 收留 → 外交危机 → 联姻/战争
	# Path B: 婉拒 (standalone, no chain)
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_foreign_princess", "name": "异国公主·流亡",
		"desc": "一位容貌绝美的异国公主请求庇护。她声称母国被篡位者夺取，手中握有重要情报和王室信物。收留她可能引来麻烦，但也可能带来意想不到的机遇。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "收留她 (+15威望, 威胁+5)", "effects": {"prestige": 15, "threat": 5}},
			{"text": "婉拒并赠送路费 (+10金)", "effects": {"gold": 10}},
		]
	})
	events.append({
		"id": "v5_princess_demand", "name": "异国公主·交人令",
		"desc": "篡位者派来使者，要求你交出公主，否则将视为敌对行为。公主跪求你不要将她交出，并献上了母国的军事布防图。",
		"condition": "chain:v5_foreign_princess:0", "repeatable": false,
		"chain_parent": "v5_foreign_princess", "chain_choice": 0,
		"choices": [
			{"text": "拒绝交人，备战 (+20威望, +揭示3格迷雾, 威胁+8)", "effects": {"prestige": 20, "reveal": 3, "threat": 8}},
			{"text": "秘密送公主离开，避免冲突 (+10秩序, -10威望)", "effects": {"order": 10, "prestige": -10}},
		]
	})
	events.append({
		"id": "v5_princess_war", "name": "异国公主·复国之战",
		"desc": "公主在你的庇护下联络了母国的忠臣旧部。他们聚集了一支复国军，请求你出兵相助。如果成功，你将获得一个强大的盟友。",
		"condition": "chain:v5_princess_demand:0", "repeatable": false,
		"chain_parent": "v5_princess_demand", "chain_choice": 0,
		"choices": [
			{"text": "出兵援助 (战斗:12敌兵, 胜利+80金+1遗物+30威望)", "effects": {"type": "combat", "enemy_soldiers": 12, "enemy_type": "elite_guard"}},
			{"text": "提供资金支持 (-50金, +20威望, 3回合后+40金朝贡)", "effects": {"gold": -50, "prestige": 20, "gold_delayed": 40}},
		]
	})

	# ══════════════════════════════════════════════════════════
	# CHAIN 3: 间谍网络 (Spy Network) — 3 steps
	# Path A: 放长线 → 情报收获 → 策反/歼灭
	# Path B: 一网打尽 → 报复 → 反击
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_spy_network", "name": "间谍网络·发现",
		"desc": "情报机构截获了一封密信，揭露了一个渗透你领地多年的敌方间谍网络。网络中至少有5名活跃特工。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "一网打尽 (+15威望, -20金)", "effects": {"prestige": 15, "gold": -20}},
			{"text": "放长线钓大鱼，喂假情报 (+5威望)", "effects": {"prestige": 5}},
		]
	})
	events.append({
		"id": "v5_spy_retaliation", "name": "间谍网络·报复",
		"desc": "间谍网络被捣毁后，敌方发动了报复行动——你的一个粮仓被纵火焚烧，边境哨所遭到突袭。",
		"condition": "chain:v5_spy_network:0", "repeatable": false,
		"chain_parent": "v5_spy_network", "chain_choice": 0,
		"choices": [
			{"text": "加强全境防卫 (-25金, +8秩序, +5城防)", "effects": {"gold": -25, "order": 8, "wall_boost": 5}},
			{"text": "以牙还牙，派密探渗透敌方 (-15金, 50%: +40金+揭示4格)", "effects": {"gold": -15, "type": "gamble", "success_rate": 0.5, "success": {"gold": 40, "reveal": 4}, "fail": {"prestige": -10}}},
		]
	})
	events.append({
		"id": "v5_spy_turned", "name": "间谍网络·策反",
		"desc": "经过数周的假情报投喂，你的反间谍人员成功接触了敌方间谍头目。他愿意反水——条件是一大笔金币和新身份。",
		"condition": "chain:v5_spy_network:1", "repeatable": false,
		"chain_parent": "v5_spy_network", "chain_choice": 1,
		"choices": [
			{"text": "策反他 (-40金, +20威望, 揭示5格迷雾, +2科技点)", "effects": {"gold": -40, "prestige": 20, "reveal": 5, "tech_point": 2}},
			{"text": "不信任，全部逮捕 (+10秩序, +10威望)", "effects": {"order": 10, "prestige": 10}},
		]
	})

	# ══════════════════════════════════════════════════════════
	# CHAIN 4: 远古墓穴 (Ancient Tomb) — 3 steps
	# Path A: 开启 → 诅咒蔓延/宝藏 → 净化/堕落
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_ancient_tomb", "name": "远古墓穴·发现",
		"desc": "探险队在荒野中发现了一座散发着古老气息的墓穴。封印上的铭文已经模糊不清，但隐约能感受到内部强大的魔力波动。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "破封开启 (-10金)", "effects": {"gold": -10}},
			{"text": "重新封印离开 (+5秩序)", "effects": {"order": 5}},
		]
	})
	events.append({
		"id": "v5_tomb_horror", "name": "远古墓穴·亡灵苏醒",
		"desc": "墓穴开启后，一股黑暗能量席卷了周围区域。探险队报告：墓穴深处的亡灵开始苏醒，它们正在向领地方向移动！同时，探险队也发现了墓穴中的宝库入口。",
		"condition": "chain:v5_ancient_tomb:0", "repeatable": false,
		"chain_parent": "v5_ancient_tomb", "chain_choice": 0,
		"choices": [
			{"text": "优先消灭亡灵 (战斗: 8亡灵兵, 胜利+3暗影精华)", "effects": {"type": "combat", "enemy_soldiers": 8, "enemy_type": "undead"}},
			{"text": "趁乱抢夺宝库 (+50金, +1遗物, -8秩序, -3兵)", "effects": {"gold": 50, "relic": true, "order": -8, "soldiers": -3}},
		]
	})
	events.append({
		"id": "v5_tomb_seal", "name": "远古墓穴·封印仪式",
		"desc": "亡灵被击退后，墓穴中的黑暗能量仍在持续外泄。法师们建议进行一次大规模封印仪式，但需要大量资源。也有人提议利用这股黑暗能量...",
		"condition": "chain:v5_tomb_horror:0", "repeatable": false,
		"chain_parent": "v5_tomb_horror", "chain_choice": 0,
		"choices": [
			{"text": "神圣封印 (-30金, -2魔晶, +15秩序, +10威望)", "effects": {"gold": -30, "magic_crystal": -2, "order": 15, "prestige": 10}},
			{"text": "汲取黑暗能量 (+5暗影精华, +3魔晶, -10秩序, 威胁+5)", "effects": {"magic_crystal": 3, "order": -10, "threat": 5}},
		]
	})

	# ══════════════════════════════════════════════════════════
	# CHAIN 5: 暗杀阴谋 (Assassination Plot) — 3 steps
	# Path A: 设陷阱 → 审讯 → 幕后势力
	# Path B: 加强防卫 → 第二次暗杀 → 反击
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_assassination_plot", "name": "暗杀阴谋·第一幕",
		"desc": "侍卫长脸色凝重地报告：在你寝宫的梁上发现了一枚涂有剧毒的暗器，还有一条用于逃跑的绳索。刺客很专业——这不是普通的暗杀。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "加强防卫，封锁宫廷 (-15金, +5秩序)", "effects": {"gold": -15, "order": 5}},
			{"text": "设置陷阱，守株待兔 (冒险但可能抓到刺客)", "effects": {}},
		]
	})
	events.append({
		"id": "v5_assassin_second", "name": "暗杀阴谋·二度出手",
		"desc": "加强防卫后平静了一段时间，但刺客再次出手——这次目标是你的军队指挥官。幸好指挥官警觉，只受了轻伤。",
		"condition": "chain:v5_assassination_plot:0", "repeatable": false,
		"chain_parent": "v5_assassination_plot", "chain_choice": 0,
		"choices": [
			{"text": "悬赏追杀刺客 (-30金, 70%: +25威望+抓住刺客)", "effects": {"gold": -30, "type": "gamble", "success_rate": 0.7, "success": {"prestige": 25}, "fail": {"soldiers": -2}}},
			{"text": "全军戒严 (-5秩序, +5城防, 全军DEF+10% 3回合)", "effects": {"order": -5, "wall_boost": 5, "buff": {"type": "def_pct", "value": 10, "duration": 3}}},
		]
	})
	events.append({
		"id": "v5_assassin_caught", "name": "暗杀阴谋·审讯",
		"desc": "陷阱奏效了——一名黑衣刺客在深夜潜入时被活捉。审讯中，他供出了雇主的身份：竟是邻国的一位高级将领。",
		"condition": "chain:v5_assassination_plot:1", "repeatable": false,
		"chain_parent": "v5_assassination_plot", "chain_choice": 1,
		"choices": [
			{"text": "公开处决刺客以示威慑 (+20威望, +5秩序, 威胁+5)", "effects": {"prestige": 20, "order": 5, "threat": 5}},
			{"text": "利用刺客传递假情报给敌方 (+15威望, 揭示4格迷雾)", "effects": {"prestige": 15, "reveal": 4}},
		]
	})

	# ══════════════════════════════════════════════════════════
	# CHAIN 6: 金矿脉 (Gold Vein) — 3 steps
	# Path A: 大规模开采 → 矿难/丰收 → 后续
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_gold_vein", "name": "金矿脉·勘探",
		"desc": "矿工们兴奋地报告：在领地东部山区发现了一条品质极高的金矿脉！初步估计储量巨大，但开采需要大量投入。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "大规模开采 (-30金投资, -2铁建矿场)", "effects": {"gold": -30, "iron": -2}},
			{"text": "谨慎小规模试采 (+15金)", "effects": {"gold": 15}},
		]
	})
	events.append({
		"id": "v5_mine_crisis", "name": "金矿脉·强盗袭矿",
		"desc": "金矿的消息走漏了！一支山贼团伙在夜间突袭了矿场，杀死守卫并劫走了第一批矿石。矿工们恐惧地拒绝继续工作，除非你能消灭这些强盗。",
		"condition": "chain:v5_gold_vein:0", "repeatable": false,
		"chain_parent": "v5_gold_vein", "chain_choice": 0,
		"choices": [
			{"text": "派兵剿匪 (战斗: 7山贼, 胜利夺回矿石+25金)", "effects": {"type": "combat", "enemy_soldiers": 7, "enemy_type": "bandits"}},
			{"text": "花钱雇佣佣兵保护 (-35金, +5秩序)", "effects": {"gold": -35, "order": 5}},
		]
	})
	events.append({
		"id": "v5_mine_boom", "name": "金矿脉·深层探索",
		"desc": "强盗被消灭后，矿工们的信心恢复了。他们在更深处挖掘时发现了一个巨大的地下空间——但里面盘踞着一群地穴蜘蛛！不过，蛛巢背后隐约可见几百年积累的天然金库。",
		"condition": "chain:v5_mine_crisis:0", "repeatable": false,
		"chain_parent": "v5_mine_crisis", "chain_choice": 0,
		"choices": [
			{"text": "清剿蛛巢夺取金库 (战斗: 9地穴兽, 胜利+100金+1遗物)", "effects": {"type": "combat", "enemy_soldiers": 9, "enemy_type": "beasts"}},
			{"text": "用烟熏驱赶后谨慎开采 (+50金, 60%安全/40%: -3兵)", "effects": {"type": "gamble", "success_rate": 0.6, "success": {"gold": 50}, "fail": {"gold": 30, "soldiers": -3}}},
		]
	})

	# ══════════════════════════════════════════════════════════
	# CHAIN 7: 英雄背叛 (Hero Betrayal) — 3 steps
	# Path A: 暗中调查 → 发现真相 → 对质
	# Path B: 立即软禁 → 武将反应 → 后果
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_hero_betrayal", "name": "背叛之影·密报",
		"desc": "深夜，一封匿名信送到你的书房——信中声称你最器重的武将正在秘密与敌方联络，甚至已经收受了大量贿赂。是捕风捉影还是确有其事？",
		"condition": "has_multiple_heroes", "repeatable": false,
		"choices": [
			{"text": "立即软禁该武将 (+5秩序)", "effects": {"order": 5}},
			{"text": "暗中展开调查 (-10金)", "effects": {"gold": -10}},
		]
	})
	events.append({
		"id": "v5_betrayal_unrest", "name": "背叛之影·亲卫叛乱",
		"desc": "武将被软禁的消息传开后，她的亲卫队300人趁夜劫狱！他们杀死了看守，释放了被软禁的武将，现在正向城门突围——你必须拦截他们！",
		"condition": "chain:v5_hero_betrayal:0", "repeatable": false,
		"chain_parent": "v5_hero_betrayal", "chain_choice": 0,
		"choices": [
			{"text": "堵截城门，武力镇压 (战斗: 6亲卫精兵, 胜利+10秩序+10威望)", "effects": {"type": "combat", "enemy_soldiers": 6, "enemy_type": "elite_guard"}},
			{"text": "放她们走，避免流血 (-4兵, -8秩序, 但全武将好感+1)", "effects": {"soldiers": -4, "order": -8, "hero_affection_all": 1}},
		]
	})
	events.append({
		"id": "v5_betrayal_truth", "name": "背叛之影·真相与追杀",
		"desc": "调查结果令人震惊——所谓的\"通敌\"竟是一场陷害！真正的叛徒得知阴谋败露，带着一批死士仓皇出逃。如果让他逃到敌国，后患无穷！",
		"condition": "chain:v5_hero_betrayal:1", "repeatable": false,
		"chain_parent": "v5_hero_betrayal", "chain_choice": 1,
		"choices": [
			{"text": "派精锐骑兵追击 (战斗: 5死士, 胜利+20威望+15秩序+1遗物)", "effects": {"type": "combat", "enemy_soldiers": 5, "enemy_type": "assassins"}},
			{"text": "放他走，专注内政 (+5秩序, -5威望, 威胁+5)", "effects": {"order": 5, "prestige": -5, "threat": 5}},
		]
	})

	# ══════════════════════════════════════════════════════════
	# CHAIN 8: 教派分裂 (Religious Schism) — 3 steps
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_religious_schism", "name": "教派分裂·裂痕",
		"desc": "领地内两大教派的矛盾终于爆发——光明教会指控月神教派进行异端仪式，月神教派则控诉光明教会囤积财富。信徒们在街头对峙，一触即发。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "强制统一，取缔月神教派 (-8秩序, +10威望)", "effects": {"order": -8, "prestige": 10}},
			{"text": "宣布宗教自由，双方共存 (+5秩序, -5威望)", "effects": {"order": 5, "prestige": -5}},
		]
	})
	events.append({
		"id": "v5_schism_underground", "name": "教派分裂·地下教会",
		"desc": "被取缔的月神教派转入地下活动。他们的信徒在暗处集结，开始秘密传教。更糟糕的是，一些不满的士兵也加入了地下教会。",
		"condition": "chain:v5_religious_schism:0", "repeatable": false,
		"chain_parent": "v5_religious_schism", "chain_choice": 0,
		"choices": [
			{"text": "铁腕清剿 (战斗: 6叛军, +10秩序)", "effects": {"type": "combat", "enemy_soldiers": 6, "enemy_type": "rebels"}},
			{"text": "恢复月神教派合法地位 (+8秩序, -10威望, +3暗影精华)", "effects": {"order": 8, "prestige": -10}},
		]
	})
	events.append({
		"id": "v5_schism_harmony", "name": "教派分裂·大融合",
		"desc": "宗教自由政策执行数周后，意想不到的事情发生了——两个教派的温和派开始交流教义，逐渐形成了一种融合两者精华的新信仰。信徒们前所未有地团结。",
		"condition": "chain:v5_religious_schism:1", "repeatable": false,
		"chain_parent": "v5_religious_schism", "chain_choice": 1,
		"choices": [
			{"text": "支持新信仰，建造融合神殿 (-25金, +15秩序, +10威望, 全军DEF+10% 5回合)", "effects": {"gold": -25, "order": 15, "prestige": 10, "buff": {"type": "def_pct", "value": 10, "duration": 5}}},
			{"text": "不介入，让其自由发展 (+8秩序, +5威望)", "effects": {"order": 8, "prestige": 5}},
		]
	})

	# ══════════════════════════════════════════════════════════
	# CHAIN 9: 传说武器 (Legendary Weapon) — 3 steps
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_legendary_weapon", "name": "传说武器·设计图",
		"desc": "一位白发苍苍的老铁匠找到你，颤抖着展开一张泛黄的羊皮纸——那是失传已久的魔剑\"黄昏之牙\"的锻造设计图。他说只需材料和时间，就能复刻这把神器。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "投资锻造 (-30金, -3铁)", "effects": {"gold": -30, "iron": -3}},
			{"text": "太冒险了，婉拒 (+5金)", "effects": {"gold": 5}},
		]
	})
	events.append({
		"id": "v5_weapon_forging", "name": "传说武器·守护者试炼",
		"desc": "锻造进行到最关键的一步时，老铁匠突然停下了锤子：设计图上写着，\"黄昏之牙\"的最终材料——陨铁核心——被封存在一座远古试炼场中。要获得它，必须击败试炼场的守护者。",
		"condition": "chain:v5_legendary_weapon:0", "repeatable": false,
		"chain_parent": "v5_legendary_weapon", "chain_choice": 0,
		"choices": [
			{"text": "派最强武将挑战守护者 (战斗: 10远古傀儡, 胜利获得陨铁核心)", "effects": {"type": "combat", "enemy_soldiers": 10, "enemy_type": "constructs"}},
			{"text": "用替代材料凑合 (80%成功: 品质稍低但可用, 20%失败: -15金)", "effects": {"type": "gamble", "success_rate": 0.8, "success": {"prestige": 5}, "fail": {"gold": -15}}},
		]
	})
	events.append({
		"id": "v5_weapon_holy", "name": "传说武器·黄昏之牙·真",
		"desc": "陨铁核心在炉火中绽放出金色光芒。老铁匠倾注毕生心血，完成了最后一锤。\"黄昏之牙\"重现人间——一把能斩断一切黑暗的神器。你的武将们争相请求佩戴它。",
		"condition": "chain:v5_weapon_forging:0", "repeatable": false,
		"chain_parent": "v5_weapon_forging", "chain_choice": 0,
		"choices": [
			{"text": "赐予最强武将 (武将ATK+3永久, +15威望)", "effects": {"hero_stat": {"stat": "atk", "value": 3}, "prestige": 15, "relic": true}},
			{"text": "作为领地圣物供奉 (全军ATK+8% 永久, +20威望)", "effects": {"prestige": 20, "buff": {"type": "atk_pct", "value": 8, "duration": 99}}},
		]
	})
	events.append({
		"id": "v5_weapon_cursed", "name": "传说武器·黄昏之牙·残",
		"desc": "替代材料终究不如陨铁核心——锻造出的剑身出现了不稳定的裂纹，暗红色的能量从裂缝中渗出。这把剑比预想的更危险，但力量也更加狂暴不可控。",
		"condition": "chain:v5_weapon_forging:1", "repeatable": false,
		"chain_parent": "v5_weapon_forging", "chain_choice": 1,
		"choices": [
			{"text": "赐予武将（力量与诅咒并存）(ATK+5, 但秩序-5永久)", "effects": {"hero_stat": {"stat": "atk", "value": 5}, "order": -5, "relic": true}},
			{"text": "封印这把危险的武器 (+10秩序, +5威望, +2暗影精华)", "effects": {"order": 10, "prestige": 5}},
		]
	})

	# ══════════════════════════════════════════════════════════
	# CHAIN 10: 海盗兵变 (Pirate Mutiny) — 3 steps [阵营专属]
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_pirate_mutiny", "name": "海盗兵变·不满",
		"desc": "船员们的不满终于爆发了。以\"红胡子\"为首的一群老海盗认为最近的分赃不公，他们占据了旗舰的甲板，公开要求更换船长。",
		"condition": "faction_pirate", "repeatable": false,
		"choices": [
			{"text": "增加分赃平息不满 (-25金, +8秩序)", "effects": {"gold": -25, "order": 8}},
			{"text": "以铁腕镇压叛乱 (-3兵, +15威望)", "effects": {"soldiers": -3, "prestige": 15}},
		]
	})
	events.append({
		"id": "v5_mutiny_split", "name": "海盗兵变·分裂",
		"desc": "镇压虽然成功了，但红胡子带着一批忠于他的海盗连夜驾船出逃。他们在附近海域建立了据点，开始劫掠你的补给线。",
		"condition": "chain:v5_pirate_mutiny:1", "repeatable": false,
		"chain_parent": "v5_pirate_mutiny", "chain_choice": 1,
		"choices": [
			{"text": "追击歼灭 (战斗: 8叛军, 胜利+30金)", "effects": {"type": "combat", "enemy_soldiers": 8, "enemy_type": "pirates"}},
			{"text": "谈判招安 (-20金, +4兵, +5秩序)", "effects": {"gold": -20, "soldiers": 4, "order": 5}},
		]
	})
	events.append({
		"id": "v5_mutiny_loyalty", "name": "海盗兵变·铁血忠诚",
		"desc": "你的慷慨赢得了船员们的心。红胡子带头高呼你的名号，船员们纷纷举杯效忠。一场危机变成了团结全船的契机。",
		"condition": "chain:v5_pirate_mutiny:0", "repeatable": false,
		"chain_parent": "v5_pirate_mutiny", "chain_choice": 0,
		"choices": [
			{"text": "趁热打铁发动劫掠 (全军ATK+15% 3回合, +20金)", "effects": {"gold": 20, "buff": {"type": "atk_pct", "value": 15, "duration": 3}}},
			{"text": "举办海盗大宴 (-15粮, +12秩序, +10威望)", "effects": {"food": -15, "order": 12, "prestige": 10}},
		]
	})

	# ══════════════════════════════════════════════════════════
	# STANDALONE EVENTS (20) — Simple but thematic
	# ══════════════════════════════════════════════════════════

	# Political (4)
	events.append({"id": "v5_rival_heir", "name": "继承危机", "desc": "一个自称王室血脉的人带着一支私兵出现了，部分贵族投靠了他。他公开向你宣战！", "condition": "always", "repeatable": true, "choices": [{"text": "武力镇压 (战斗: 8叛军, 胜利+15威望)", "effects": {"type": "combat", "enemy_soldiers": 8, "enemy_type": "rebels"}}, {"text": "收买拉拢 (-30金, +5秩序)", "effects": {"gold": -30, "order": 5}}]})
	events.append({"id": "v5_merchant_guild", "name": "商会请愿", "desc": "本地商会要求减税以换取更多贸易收入。", "condition": "always", "repeatable": true, "choices": [{"text": "同意减税 (-15金, +20下回合金)", "effects": {"gold": -15, "gold_delayed": 20}}, {"text": "拒绝 (+5威望)", "effects": {"prestige": 5}}]})
	events.append({"id": "v5_noble_feud", "name": "贵族械斗", "desc": "两个贵族家族的私兵在街头大打出手，已经有平民伤亡！你必须立刻干预。", "condition": "always", "repeatable": true, "choices": [{"text": "派兵弹压 (战斗: 5混战兵, 胜利+8秩序+5威望)", "effects": {"type": "combat", "enemy_soldiers": 5, "enemy_type": "rebels"}}, {"text": "居中调停 (+5秩序, +3威望, -10金)", "effects": {"order": 5, "prestige": 3, "gold": -10}}]})
	events.append({"id": "v5_peace_envoy", "name": "和平使者", "desc": "一位来自远方的使者提议建立贸易通道。", "condition": "always", "repeatable": true, "choices": [{"text": "接受 (+25金, -3威望)", "effects": {"gold": 25, "prestige": -3}}, {"text": "拒绝 (+5威望)", "effects": {"prestige": 5}}]})

	# Military (4)
	events.append({"id": "v5_veteran_company", "name": "老兵佣兵团", "desc": "一支经验丰富的佣兵团路过你的领地，愿意为你效力。", "condition": "always", "repeatable": true, "choices": [{"text": "雇佣 (-40金, +6精锐兵)", "effects": {"gold": -40, "soldiers": 6}}, {"text": "礼貌拒绝", "effects": {}}]})
	events.append({"id": "v5_weapons_cache", "name": "武器密藏", "desc": "巡逻队发现了一处隐藏的武器储藏室。", "condition": "always", "repeatable": true, "choices": [{"text": "装备军队 (全军ATK+10%, 3回合)", "effects": {"buff": {"type": "atk_pct", "value": 10, "duration": 3}}}, {"text": "卖掉武器 (+35金)", "effects": {"gold": 35}}]})
	events.append({"id": "v5_deserter_wave", "name": "逃兵潮", "desc": "大量敌方逃兵涌入你的领地。", "condition": "always", "repeatable": true, "choices": [{"text": "收编 (+4兵, -3秩序)", "effects": {"soldiers": 4, "order": -3}}, {"text": "驱逐 (+5秩序)", "effects": {"order": 5}}]})
	events.append({"id": "v5_night_raid", "name": "夜袭", "desc": "敌方发动了一次小规模夜袭!", "condition": "always", "repeatable": true, "choices": [{"text": "迎战 (战斗: 4敌兵)", "effects": {"type": "combat", "enemy_soldiers": 4, "enemy_type": "bandits"}}, {"text": "据守营地 (-2兵, +3城防)", "effects": {"soldiers": -2, "wall_boost": 3}}]})

	# Supernatural (4)
	events.append({"id": "v5_blood_moon_omen", "name": "血月·亡灵潮", "desc": "血红色月亮升起的同时，领地边境出现了大量亡灵！它们被血月之力驱动，向你的据点涌来。", "condition": "always", "repeatable": true, "choices": [{"text": "全军迎战 (战斗: 8亡灵, 胜利+3暗影精华+10威望)", "effects": {"type": "combat", "enemy_soldiers": 8, "enemy_type": "undead"}}, {"text": "据守城墙等天亮 (-3兵, +5城防, 50%: +2暗影精华)", "effects": {"soldiers": -3, "wall_boost": 5, "type": "gamble", "success_rate": 0.5, "success": {}, "fail": {"order": -5}}}]})
	events.append({"id": "v5_spirit_guardian", "name": "精灵守护者", "desc": "一位古老的精灵现身，愿意守护你的领地。", "condition": "always", "repeatable": true, "choices": [{"text": "接受守护 (DEF+15%, 5回合)", "effects": {"buff": {"type": "def_pct", "value": 15, "duration": 5}}}, {"text": "请求情报 (揭示2格迷雾)", "effects": {"reveal": 2}}]})
	events.append({"id": "v5_mana_surge", "name": "魔力潮汐·元素暴走", "desc": "大地中涌出的魔力波动失控了——火元素和冰元素在领地中央具现化，正在互相厮杀并波及周围建筑！", "condition": "always", "repeatable": true, "choices": [{"text": "派法师和士兵消灭元素体 (战斗: 6元素兵, 胜利+3魔晶)", "effects": {"type": "combat", "enemy_soldiers": 6, "enemy_type": "elementals"}}, {"text": "引导魔力分散 (-15金, +2魔晶, +5秩序)", "effects": {"gold": -15, "magic_crystal": 2, "order": 5}}]})
	events.append({"id": "v5_dark_ritual_found", "name": "暗黑仪式·邪教巢穴", "desc": "巡逻队不仅发现了暗黑仪式——他们还找到了一个完整的邪教地下巢穴，里面有召唤出的恶魔守卫。", "condition": "always", "repeatable": true, "choices": [{"text": "突袭邪教巢穴 (战斗: 7恶魔+邪教徒, 胜利+2暗影精华+10秩序)", "effects": {"type": "combat", "enemy_soldiers": 7, "enemy_type": "cultists"}}, {"text": "封锁入口上报 (+5秩序, +5威望)", "effects": {"order": 5, "prestige": 5}}]})

	# Economic (4)
	events.append({"id": "v5_trade_caravan", "name": "贸易商队", "desc": "一支来自远方的贸易商队经过你的领地。", "condition": "always", "repeatable": true, "choices": [{"text": "征税 (+20金, -3外交)", "effects": {"gold": 20, "prestige": -3}}, {"text": "合作贸易 (+10金, +5威望)", "effects": {"gold": 10, "prestige": 5}}]})
	events.append({"id": "v5_black_market_deal", "name": "黑市交易", "desc": "黑市商人提供了一笔利润丰厚但有风险的交易。", "condition": "always", "repeatable": true, "choices": [{"text": "交易 (60%: +50金, 40%: -20金-5秩序)", "effects": {"type": "gamble", "success_rate": 0.6, "success": {"gold": 50}, "fail": {"gold": -20, "order": -5}}}, {"text": "举报 (+10秩序)", "effects": {"order": 10}}]})
	events.append({"id": "v5_treasure_map", "name": "藏宝图", "desc": "一位垂死的旅人交给你一张藏宝图。", "condition": "always", "repeatable": true, "choices": [{"text": "派人寻宝 (40%: +80金+神器, 60%: -10金)", "effects": {"type": "gamble", "success_rate": 0.4, "success": {"gold": 80, "relic": true}, "fail": {"gold": -10}}}, {"text": "卖掉地图 (+10金)", "effects": {"gold": 10}}]})
	events.append({"id": "v5_food_shortage", "name": "粮食紧缺", "desc": "连日暴雨导致粮食歉收，百姓面临饥饿。", "condition": "always", "repeatable": true, "choices": [{"text": "开仓赈灾 (-15粮, +10秩序)", "effects": {"food": -15, "order": 10}}, {"text": "强征余粮 (+5粮, -8秩序)", "effects": {"food": 5, "order": -8}}]})

	# Character / Faction (4)
	events.append({"id": "v5_orc_feast", "name": "兽人狂宴", "desc": "兽人战士们要求举办一场战前狂宴。", "condition": "faction_orc", "repeatable": true, "choices": [{"text": "举办 (-20粮, +25WAAAGH)", "effects": {"food": -20, "waaagh": 25}}, {"text": "拒绝 (-10WAAAGH, +5秩序)", "effects": {"waaagh": -10, "order": 5}}]})
	events.append({"id": "v5_dark_elf_ritual", "name": "暗精灵仪式", "desc": "暗精灵长老提议举行一次古老的增幅仪式。", "condition": "faction_dark_elf", "repeatable": true, "choices": [{"text": "参加 (-5奴隶, 全军DEF+20%, 3回合)", "effects": {"slaves": -5, "buff": {"type": "def_pct", "value": 20, "duration": 3}}}, {"text": "拒绝", "effects": {}}]})
	events.append({"id": "v5_wandering_sage", "name": "云游贤者", "desc": "一位云游四方的贤者愿意传授知识。", "condition": "always", "repeatable": true, "choices": [{"text": "拜师学习 (-10金, +1科技点)", "effects": {"gold": -10, "tech_point": 1}}, {"text": "请教战术 (士气+10%, 3回合)", "effects": {"buff": {"type": "morale_pct", "value": 10, "duration": 3}}}]})
	events.append({"id": "v5_faction_summit", "name": "势力会谈", "desc": "周边势力提议举行一次多方会谈。", "condition": "always", "repeatable": true, "choices": [{"text": "参加 (-15金, +10威望)", "effects": {"gold": -15, "prestige": 10}}, {"text": "拒绝 (+5威望)", "effects": {"prestige": 5}}]})

	# ══════════════════════════════════════════════════════════
	# CHAIN 11: 深渊觉醒 (Abyss Awakening) — 4 steps
	# Turn-gated progression: earthquakes → ruins → portal → final choice
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_abyss_awakening", "name": "深渊觉醒·异震",
		"desc": "大地突然剧烈震颤！城墙出现裂纹，地下传来低沉的轰鸣声。学者们惊恐地报告：震源不在地表——而是来自地底深处某个不该存在的空间。更诡异的是，每次地震后，领地周围的暗影精华浓度都会明显上升。",
		"condition": "turn_min_20", "repeatable": false,
		"choices": [
			{"text": "组织勘探队深入地下调查 (-20金, -2兵)", "effects": {"gold": -20, "soldiers": -2}},
			{"text": "加固城防，静观其变 (-30铁, +5城防, +3秩序)", "effects": {"iron": -30, "wall_boost": 5, "order": 3}},
		]
	})
	events.append({
		"id": "v5_abyss_ruins", "name": "深渊觉醒·远古遗迹",
		"desc": "勘探队带回了惊人的发现——地震撕裂了地层，暴露出一座远古文明的遗迹！遗迹入口散发着诡异的紫光，空气中充斥着令人不安的低语声。遗迹内部似乎藏有强大的魔法器物，但守护者的力量也不容小觑。",
		"condition": "chain:v5_abyss_awakening:0", "repeatable": false,
		"chain_parent": "v5_abyss_awakening", "chain_choice": 0,
		"choices": [
			{"text": "派精锐探索遗迹 (战斗: 8远古守卫, 胜利+1遗物+3魔晶+50金)", "effects": {"type": "combat", "enemy_soldiers": 8, "enemy_type": "constructs"}},
			{"text": "封锁入口，开采外围资源 (+30铁, +2魔晶, +10威望)", "effects": {"iron": 30, "magic_crystal": 2, "prestige": 10}},
		]
	})
	events.append({
		"id": "v5_abyss_portal", "name": "深渊觉醒·深渊之门",
		"desc": "遗迹深处的封印被打破了——一道巨大的裂隙撕开了现实的帷幕！深渊之门已经开启，源源不断的深渊魔物从裂隙中涌出。它们的力量远超普通敌人，而且门的另一侧似乎有更强大的存在正在蠢蠢欲动。整个领地都能感受到来自深渊的压迫感。",
		"condition": "chain:v5_abyss_ruins:0", "repeatable": false,
		"chain_parent": "v5_abyss_ruins", "chain_choice": 0,
		"choices": [
			{"text": "全军迎战深渊先锋 (战斗: 12深渊魔物, 胜利+5暗影精华+20威望)", "effects": {"type": "combat", "enemy_soldiers": 12, "enemy_type": "abyss_demon"}},
			{"text": "紧急撤退，放弃遗迹区域 (-1控制地块, +8秩序, 全军存活)", "effects": {"order": 8, "lose_node": true}},
		]
	})
	events.append({
		"id": "v5_abyss_seal", "name": "深渊觉醒·封印还是掌控",
		"desc": "深渊先锋被击退后，门户仍在运转。法师们发现了两种可能：用大量魔晶进行永久封印，彻底关闭深渊之门；或者利用遗迹中发现的控制装置，将深渊之门转化为己用的力量源泉——但代价是领地将永远笼罩在深渊的阴影之下。",
		"condition": "chain:v5_abyss_portal:0", "repeatable": false,
		"chain_parent": "v5_abyss_portal", "chain_choice": 0,
		"choices": [
			{"text": "永久封印深渊之门 (-5魔晶, -50金, +20秩序, +30威望, 全军DEF+10%永久)", "effects": {"magic_crystal": -5, "gold": -50, "order": 20, "prestige": 30, "buff": {"type": "def_pct", "value": 10, "duration": 99}}},
			{"text": "掌控深渊之力 (+10暗影精华, +3魔晶/回合, 全军ATK+15%永久, 秩序-15, 威胁+10)", "effects": {"magic_crystal": 3, "order": -15, "threat": 10, "buff": {"type": "atk_pct", "value": 15, "duration": 99}}},
		]
	})

	# ══════════════════════════════════════════════════════════
	# CHAIN 12: 商路争夺 (Trade Route War) — 5 steps
	# Triggered by tile control; economic-focused chain
	# ══════════════════════════════════════════════════════════
	events.append({
		"id": "v5_trade_route_war", "name": "商路争夺·商队求援",
		"desc": "一支庞大的商队抵达你的领地，队长满脸焦虑。他说自从你控制了这片区域，一条重要的贸易路线变得安全了许多，但最近有不明势力开始劫掠商队。他请求你派兵保护商路，作为回报，商队愿意缴纳丰厚的保护费。",
		"condition": "tiles_min_10", "repeatable": false,
		"choices": [
			{"text": "派兵护送商队 (-3兵, +40金, +10威望)", "effects": {"soldiers": -3, "gold": 40, "prestige": 10}},
			{"text": "收取保护费但不出兵 (+25金, -5威望)", "effects": {"gold": 25, "prestige": -5}},
		]
	})
	events.append({
		"id": "v5_trade_raiders", "name": "商路争夺·劫匪伏击",
		"desc": "你的护送部队在商路要道遭遇了伏击！这些不是普通的土匪——他们装备精良、训练有素，显然是某个敌对势力雇佣的精锐佣兵。战斗结束后，你在敌方指挥官身上发现了一封密信，揭露了幕后主使是一个试图垄断商路的敌对领主。",
		"condition": "chain:v5_trade_route_war:0", "repeatable": false,
		"chain_parent": "v5_trade_route_war", "chain_choice": 0,
		"choices": [
			{"text": "追击残敌并夺取据点 (战斗: 9佣兵, 胜利+50金+15威望)", "effects": {"type": "combat", "enemy_soldiers": 9, "enemy_type": "mercenaries"}},
			{"text": "加固商路防线，不主动出击 (-20铁, +8秩序, +5城防)", "effects": {"iron": -20, "order": 8, "wall_boost": 5}},
		]
	})
	events.append({
		"id": "v5_trade_negotiation", "name": "商路争夺·谈判桌上",
		"desc": "你的胜利引起了广泛关注。多方势力派出代表，希望就商路控制权进行谈判。敌对领主也派来了使者，提出和解方案——共享商路利润。但商队队长劝你独占商路，因为这样利润更高。",
		"condition": "chain:v5_trade_raiders:0", "repeatable": false,
		"chain_parent": "v5_trade_raiders", "chain_choice": 0,
		"choices": [
			{"text": "接受共享方案 (+15金/回合永久, +15威望, +5秩序)", "effects": {"prestige": 15, "order": 5, "type": "dot", "gold": 15, "duration": 99}},
			{"text": "拒绝谈判，独占商路 (+25金/回合永久, -10威望, 威胁+5)", "effects": {"prestige": -10, "threat": 5, "type": "dot", "gold": 25, "duration": 99}},
		]
	})
	events.append({
		"id": "v5_trade_monopoly_war", "name": "商路争夺·最终决战",
		"desc": "你拒绝共享商路的决定激怒了敌对领主。他联合了数个小势力组建了联军，向你的商路要塞发动了大规模进攻！这是一场决定商路归属的关键战役——胜者将获得永久的贸易垄断权。",
		"condition": "chain:v5_trade_negotiation:1", "repeatable": false,
		"chain_parent": "v5_trade_negotiation", "chain_choice": 1,
		"choices": [
			{"text": "主动出击，歼灭联军 (战斗: 14联军精锐, 胜利+100金+1遗物+30威望)", "effects": {"type": "combat", "enemy_soldiers": 14, "enemy_type": "elite_guard"}},
			{"text": "据守要塞，消耗敌军 (战斗: 10联军, DEF+25%, 胜利+60金+20威望)", "effects": {"type": "combat", "enemy_soldiers": 10, "enemy_type": "rebels", "buff": {"type": "def_pct", "value": 25, "duration": 1}}},
		]
	})
	events.append({
		"id": "v5_trade_alliance", "name": "商路争夺·贸易联盟",
		"desc": "和平共享方案执行数周后，商路比以往任何时候都繁荣。各方势力对你的公正裁决心悦诚服，提议成立一个由你主导的贸易联盟。这将大幅提升你的经济实力和政治影响力。",
		"condition": "chain:v5_trade_negotiation:0", "repeatable": false,
		"chain_parent": "v5_trade_negotiation", "chain_choice": 0,
		"choices": [
			{"text": "主导贸易联盟 (-30金投资, +20金/回合永久, +20威望, +10秩序)", "effects": {"gold": -30, "prestige": 20, "order": 10, "type": "dot", "gold_bonus": 20, "duration": 99}},
			{"text": "保持独立，仅收取分成 (+10金/回合永久, +10威望)", "effects": {"prestige": 10, "type": "dot", "gold": 10, "duration": 99}},
		]
	})

	return events
