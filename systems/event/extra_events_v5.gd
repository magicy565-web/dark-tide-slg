## extra_events_v5.gd — 50 events: 10 three-step narrative chains (30) + 20 standalone
## Auto-registers with EventSystem on _ready().
## Chain events use "chain:parent_id:choice" condition format.
## Each chain: Step 1 (trigger) → Step 2 (2-4 turns later) → Step 3 (2-4 turns after step 2)
extends Node

func _ready() -> void:
	call_deferred("register_with_event_system")

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
		"id": "v5_court_conspiracy_s3_purge", "name": "宫廷阴谋·铁腕代价",
		"desc": "持续的镇压让宫廷笼罩在恐惧中。大臣们噤若寒蝉，效率低下，但再无人敢质疑你的权威。",
		"condition": "chain:v5_court_conspiracy_s2a:1", "repeatable": false,
		"chain_parent": "v5_court_conspiracy_s2a", "chain_choice": 1,
		"choices": [
			{"text": "建立密探机构永久监控 (-20金, +15威望, 秩序-5)", "effects": {"gold": -20, "prestige": 15, "order": -5}},
			{"text": "大赦天下，重新开始 (+15秩序, -10威望, +20金)", "effects": {"order": 15, "prestige": -10, "gold": 20}},
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
			{"text": "出兵援助 (战斗:12敌兵, 胜利+80金+1遗物+30威望)", "effects": {"type": "combat", "enemy_soldiers": 12}},
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
			{"text": "优先消灭亡灵 (战斗: 8亡灵兵, 胜利+3暗影精华)", "effects": {"type": "combat", "enemy_soldiers": 8}},
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
		"id": "v5_mine_crisis", "name": "金矿脉·矿难",
		"desc": "大规模开采进行到第三周，灾难降临——矿道坍塌，数十名矿工被困地下。救援需要资源，但如果不救，剩余矿工将拒绝继续工作。",
		"condition": "chain:v5_gold_vein:0", "repeatable": false,
		"chain_parent": "v5_gold_vein", "chain_choice": 0,
		"choices": [
			{"text": "全力救援 (-20金, -1铁, +10秩序)", "effects": {"gold": -20, "iron": -1, "order": 10}},
			{"text": "封闭坍塌矿道，继续其他区域开采 (+30金, -12秩序, -5威望)", "effects": {"gold": 30, "order": -12, "prestige": -5}},
		]
	})
	events.append({
		"id": "v5_mine_boom", "name": "金矿脉·黄金时代",
		"desc": "救援成功后，矿工们士气高涨。他们在更深处发现了一个巨大的天然金库——几百年来积累的纯金矿石堆满了整个洞穴！",
		"condition": "chain:v5_mine_crisis:0", "repeatable": false,
		"chain_parent": "v5_mine_crisis", "chain_choice": 0,
		"choices": [
			{"text": "全部开采充实国库 (+100金, +5威望)", "effects": {"gold": 100, "prestige": 5}},
			{"text": "分一半给矿工作为奖励 (+50金, +15秩序, +10威望)", "effects": {"gold": 50, "order": 15, "prestige": 10}},
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
		"id": "v5_betrayal_unrest", "name": "背叛之影·军心动摇",
		"desc": "武将被软禁的消息传开后，她的亲卫队和追随者们群情激愤。其他武将也开始不安——如果任何人都可能突然被软禁，谁还敢卖命？",
		"condition": "chain:v5_hero_betrayal:0", "repeatable": false,
		"chain_parent": "v5_hero_betrayal", "chain_choice": 0,
		"choices": [
			{"text": "公开证据平息众怒 (+10威望, -5秩序)", "effects": {"prestige": 10, "order": -5}},
			{"text": "释放武将并道歉 (全武将好感+1, -10威望)", "effects": {"hero_affection_all": 1, "prestige": -10}},
		]
	})
	events.append({
		"id": "v5_betrayal_truth", "name": "背叛之影·真相",
		"desc": "调查结果令人震惊——所谓的\"通敌\"竟是一场陷害！匿名信的寄信人是另一位嫉妒她战功的武将。真正的叛徒就隐藏在你身边。",
		"condition": "chain:v5_hero_betrayal:1", "repeatable": false,
		"chain_parent": "v5_hero_betrayal", "chain_choice": 1,
		"choices": [
			{"text": "揪出陷害者并严惩 (+15威望, +8秩序, 被诬陷武将好感+2)", "effects": {"prestige": 15, "order": 8}},
			{"text": "私下警告，维持表面和平 (+5秩序, -5威望)", "effects": {"order": 5, "prestige": -5}},
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
			{"text": "铁腕清剿 (战斗: 6叛军, +10秩序)", "effects": {"type": "combat", "enemy_soldiers": 6}},
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
		"id": "v5_weapon_forging", "name": "传说武器·锻造",
		"desc": "锻造已经持续了数日，炉火昼夜不息。老铁匠说还缺少一种关键催化剂——要么使用昂贵的魔晶，要么用更危险但免费的方法：以鲜血淬火。",
		"condition": "chain:v5_legendary_weapon:0", "repeatable": false,
		"chain_parent": "v5_legendary_weapon", "chain_choice": 0,
		"choices": [
			{"text": "使用魔晶 (-2魔晶, 安全锻造)", "effects": {"magic_crystal": -2}},
			{"text": "鲜血淬火 (-2兵献祭, 武器更强但带有诅咒)", "effects": {"soldiers": -2}},
		]
	})
	events.append({
		"id": "v5_weapon_holy", "name": "传说武器·黄昏之牙·圣",
		"desc": "魔晶的纯净能量注入剑身，金色的光芒从刃口涌出。\"黄昏之牙\"重现人间——一把能斩断黑暗的圣剑。你的武将们争相请求佩戴它。",
		"condition": "chain:v5_weapon_forging:0", "repeatable": false,
		"chain_parent": "v5_weapon_forging", "chain_choice": 0,
		"choices": [
			{"text": "赐予最强武将 (武将ATK+3永久, +15威望)", "effects": {"hero_stat": {"stat": "atk", "value": 3}, "prestige": 15, "relic": true}},
			{"text": "作为领地圣物供奉 (全军ATK+8% 永久, +20威望)", "effects": {"prestige": 20, "buff": {"type": "atk_pct", "value": 8, "duration": 99}}},
		]
	})
	events.append({
		"id": "v5_weapon_cursed", "name": "传说武器·黄昏之牙·诅咒",
		"desc": "鲜血浸透了剑身，暗红色的脉络在刀刃上蔓延。这把剑的力量远超预期——但它似乎有了自己的意志，每次拔剑都让持有者陷入狂暴。",
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
			{"text": "追击歼灭 (战斗: 8叛军, 胜利+30金)", "effects": {"type": "combat", "enemy_soldiers": 8}},
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
	events.append({"id": "v5_rival_heir", "name": "继承危机", "desc": "一个自称王室血脉的人出现了，部分贵族开始向他效忠。", "condition": "always", "repeatable": true, "choices": [{"text": "公开处决 (-5秩序, +10威望)", "effects": {"order": -5, "prestige": 10}}, {"text": "收买拉拢 (-30金, +5秩序)", "effects": {"gold": -30, "order": 5}}]})
	events.append({"id": "v5_merchant_guild", "name": "商会请愿", "desc": "本地商会要求减税以换取更多贸易收入。", "condition": "always", "repeatable": true, "choices": [{"text": "同意减税 (-15金, +20下回合金)", "effects": {"gold": -15, "gold_delayed": 20}}, {"text": "拒绝 (+5威望)", "effects": {"prestige": 5}}]})
	events.append({"id": "v5_noble_feud", "name": "贵族内斗", "desc": "两个贵族家族爆发冲突，一方请求你的裁决。", "condition": "always", "repeatable": true, "choices": [{"text": "支持强者 (+10金, -3秩序)", "effects": {"gold": 10, "order": -3}}, {"text": "居中调停 (+5秩序, +3威望)", "effects": {"order": 5, "prestige": 3}}]})
	events.append({"id": "v5_peace_envoy", "name": "和平使者", "desc": "一位来自远方的使者提议建立贸易通道。", "condition": "always", "repeatable": true, "choices": [{"text": "接受 (+25金, -3威望)", "effects": {"gold": 25, "prestige": -3}}, {"text": "拒绝 (+5威望)", "effects": {"prestige": 5}}]})

	# Military (4)
	events.append({"id": "v5_veteran_company", "name": "老兵佣兵团", "desc": "一支经验丰富的佣兵团路过你的领地，愿意为你效力。", "condition": "always", "repeatable": true, "choices": [{"text": "雇佣 (-40金, +6精锐兵)", "effects": {"gold": -40, "soldiers": 6}}, {"text": "礼貌拒绝", "effects": {}}]})
	events.append({"id": "v5_weapons_cache", "name": "武器密藏", "desc": "巡逻队发现了一处隐藏的武器储藏室。", "condition": "always", "repeatable": true, "choices": [{"text": "装备军队 (全军ATK+10%, 3回合)", "effects": {"buff": {"type": "atk_pct", "value": 10, "duration": 3}}}, {"text": "卖掉武器 (+35金)", "effects": {"gold": 35}}]})
	events.append({"id": "v5_deserter_wave", "name": "逃兵潮", "desc": "大量敌方逃兵涌入你的领地。", "condition": "always", "repeatable": true, "choices": [{"text": "收编 (+4兵, -3秩序)", "effects": {"soldiers": 4, "order": -3}}, {"text": "驱逐 (+5秩序)", "effects": {"order": 5}}]})
	events.append({"id": "v5_night_raid", "name": "夜袭", "desc": "敌方发动了一次小规模夜袭!", "condition": "always", "repeatable": true, "choices": [{"text": "迎战 (战斗: 4敌兵)", "effects": {"type": "combat", "enemy_soldiers": 4}}, {"text": "据守营地 (-2兵, +3城防)", "effects": {"soldiers": -2, "wall_boost": 3}}]})

	# Supernatural (4)
	events.append({"id": "v5_blood_moon_omen", "name": "血月异象", "desc": "天空出现了诡异的血红色月亮，士兵们惶恐不安。", "condition": "always", "repeatable": true, "choices": [{"text": "举行祈福仪式 (-15金, +5秩序)", "effects": {"gold": -15, "order": 5}}, {"text": "宣称是吉兆 (+8威望, -3秩序)", "effects": {"prestige": 8, "order": -3}}]})
	events.append({"id": "v5_spirit_guardian", "name": "精灵守护者", "desc": "一位古老的精灵现身，愿意守护你的领地。", "condition": "always", "repeatable": true, "choices": [{"text": "接受守护 (DEF+15%, 5回合)", "effects": {"buff": {"type": "def_pct", "value": 15, "duration": 5}}}, {"text": "请求情报 (揭示2格迷雾)", "effects": {"reveal": 2}}]})
	events.append({"id": "v5_mana_surge", "name": "魔力潮汐", "desc": "大地中涌出了强烈的魔力波动。", "condition": "always", "repeatable": true, "choices": [{"text": "引导魔力 (+2魔晶)", "effects": {"magic_crystal": 2}}, {"text": "分配给军队 (全军ATK+15%, 2回合)", "effects": {"buff": {"type": "atk_pct", "value": 15, "duration": 2}}}]})
	events.append({"id": "v5_dark_ritual_found", "name": "暗黑仪式", "desc": "巡逻队发现有人在秘密进行暗黑仪式。", "condition": "always", "repeatable": true, "choices": [{"text": "阻止并逮捕 (+5秩序, +5威望)", "effects": {"order": 5, "prestige": 5}}, {"text": "秘密观察学习 (+2暗影精华, -5秩序)", "effects": {"order": -5}}]})

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

	return events
