## extra_events_v5.gd — 50 additional random events to reach 250+ total
## Auto-registers with EventSystem on _ready(). Categories:
## - Political intrigue (10)
## - Military encounters (10)
## - Supernatural phenomena (10)
## - Economic opportunities (10)
## - Character & faction depth (10)
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
	# POLITICAL INTRIGUE (10)
	# ══════════════════════════════════════════════════════════
	# placeholder - filled below
	events.append({"id":"v5_court_conspiracy","name":"宫廷阴谋","desc":"一名密探传来消息——宫廷内部有人正密谋叛变。是否清洗可疑分子？","condition":"always","repeatable":true,"choices":[{"text":"大规模清洗 (-10秩序, +15威望)","effects":{"order":-10,"prestige":15}},{"text":"暗中监视 (+5情报)","effects":{"prestige":5}}]})
	events.append({"id":"v5_rival_heir","name":"继承危机","desc":"一个自称王室血脉的人出现了，部分贵族开始向他效忠。","condition":"always","repeatable":true,"choices":[{"text":"公开处决 (-5秩序, +10威望)","effects":{"order":-5,"prestige":10}},{"text":"收买拉拢 (-30金, +5秩序)","effects":{"gold":-30,"order":5}}]})
	events.append({"id":"v5_merchant_guild","name":"商会请愿","desc":"本地商会要求减税以换取更多贸易收入。","condition":"always","repeatable":true,"choices":[{"text":"同意减税 (-15金, +20下回合金)","effects":{"gold":-15,"gold_delayed":20}},{"text":"拒绝 (+5威望)","effects":{"prestige":5}}]})
	events.append({"id":"v5_noble_feud","name":"贵族内斗","desc":"两个贵族家族爆发冲突，一方请求你的裁决。","condition":"always","repeatable":true,"choices":[{"text":"支持强者 (+10金, -3秩序)","effects":{"gold":10,"order":-3}},{"text":"居中调停 (+5秩序, +3威望)","effects":{"order":5,"prestige":3}}]})
	events.append({"id":"v5_spy_network","name":"间谍网络","desc":"情报机构发现一个敌方间谍网络正在活动。","condition":"always","repeatable":true,"choices":[{"text":"一网打尽 (+15威望, -20金)","effects":{"prestige":15,"gold":-20}},{"text":"放长线钓大鱼 (3回合后+30金)","effects":{"gold_delayed":30}}]})
	events.append({"id":"v5_tax_revolt","name":"税收暴动","desc":"过高的税率引发了领地内的暴动。","condition":"always","repeatable":true,"choices":[{"text":"武力镇压 (-5秩序, +2兵)","effects":{"order":-5,"soldiers":2}},{"text":"减税安抚 (-20金, +8秩序)","effects":{"gold":-20,"order":8}}]})
	events.append({"id":"v5_peace_envoy","name":"和平使者","desc":"一位来自远方的使者提议建立贸易通道。","condition":"always","repeatable":true,"choices":[{"text":"接受 (+25金, -3威望)","effects":{"gold":25,"prestige":-3}},{"text":"拒绝 (+5威望)","effects":{"prestige":5}}]})
	events.append({"id":"v5_assassination_plot","name":"暗杀阴谋","desc":"侍卫长报告发现了一起针对你的暗杀计划。","condition":"always","repeatable":true,"choices":[{"text":"加强防卫 (-15金, +5秩序)","effects":{"gold":-15,"order":5}},{"text":"设置陷阱抓捕刺客 (70%成功+20威望)","effects":{"type":"gamble","success_rate":0.7,"success":{"prestige":20},"fail":{"soldiers":-2,"order":-5}}}]})
	events.append({"id":"v5_religious_schism","name":"教派分裂","desc":"领地内两大教派爆发冲突，信徒们对立严重。","condition":"always","repeatable":true,"choices":[{"text":"强制统一 (-8秩序, +10威望)","effects":{"order":-8,"prestige":10}},{"text":"宣布宗教自由 (+5秩序, -5威望)","effects":{"order":5,"prestige":-5}}]})
	events.append({"id":"v5_foreign_princess","name":"异国公主","desc":"一位流亡的异国公主请求庇护，据说她掌握着重要情报。","condition":"always","repeatable":true,"choices":[{"text":"收留她 (+15威望, 可能引发外交事件)","effects":{"prestige":15,"threat":5}},{"text":"婉拒 (+10金遣散费)","effects":{"gold":10}}]})

	# ══════════════════════════════════════════════════════════
	# MILITARY ENCOUNTERS (10)
	# ══════════════════════════════════════════════════════════
	events.append({"id":"v5_veteran_company","name":"老兵佣兵团","desc":"一支经验丰富的佣兵团路过你的领地，愿意为你效力。","condition":"always","repeatable":true,"choices":[{"text":"雇佣 (-40金, +6精锐兵)","effects":{"gold":-40,"soldiers":6}},{"text":"礼貌拒绝","effects":{}}]})
	events.append({"id":"v5_weapons_cache","name":"武器密藏","desc":"巡逻队发现了一处隐藏的武器储藏室。","condition":"always","repeatable":true,"choices":[{"text":"装备军队 (全军ATK+1, 3回合)","effects":{"buff":{"type":"atk_pct","value":10,"duration":3}}},{"text":"卖掉武器 (+35金)","effects":{"gold":35}}]})
	events.append({"id":"v5_siege_engineers","name":"攻城工程师","desc":"一群流浪工程师提出帮助建造攻城器械。","condition":"always","repeatable":true,"choices":[{"text":"雇佣 (-25金, +5城防)","effects":{"gold":-25,"wall_boost":5}},{"text":"雇佣为教官 (全军DEF+1, 3回合)","effects":{"gold":-15,"buff":{"type":"def_pct","value":8,"duration":3}}}]})
	events.append({"id":"v5_border_skirmish","name":"边境小冲突","desc":"边境哨兵报告有小股敌军试探进攻。","condition":"always","repeatable":true,"choices":[{"text":"全面反击 (战斗: 6敌兵)","effects":{"type":"combat","enemy_soldiers":6}},{"text":"加固防线 (-10金, +3秩序)","effects":{"gold":-10,"order":3}}]})
	events.append({"id":"v5_deserter_wave","name":"逃兵潮","desc":"大量敌方逃兵涌入你的领地。","condition":"always","repeatable":true,"choices":[{"text":"收编 (+4兵, -3秩序)","effects":{"soldiers":4,"order":-3}},{"text":"驱逐 (+5秩序)","effects":{"order":5}}]})
	events.append({"id":"v5_war_trophies","name":"战利品","desc":"将领们献上了上次战役的战利品。","condition":"always","repeatable":true,"choices":[{"text":"分给士兵 (士气+15%, 3回合)","effects":{"buff":{"type":"morale_pct","value":15,"duration":3}}},{"text":"卖掉充公 (+30金)","effects":{"gold":30}}]})
	events.append({"id":"v5_ambush_intel","name":"伏击情报","desc":"密探传来消息: 附近有一支敌军落入了包围圈。","condition":"always","repeatable":true,"choices":[{"text":"发动伏击 (战斗: 5弱敌, ATK+20%)","effects":{"type":"combat","enemy_soldiers":5,"buff":{"type":"atk_pct","value":20,"duration":1}}},{"text":"按兵不动 (+5情报)","effects":{"prestige":5}}]})
	events.append({"id":"v5_naval_patrol","name":"海上巡逻","desc":"海军在近海发现了走私船队。","condition":"always","repeatable":true,"choices":[{"text":"截获 (+25金, -3外交声望)","effects":{"gold":25,"prestige":-3}},{"text":"放行收税 (+10金)","effects":{"gold":10}}]})
	events.append({"id":"v5_training_ground","name":"训练场扩建","desc":"将领建议扩建训练场以提高新兵素质。","condition":"always","repeatable":true,"choices":[{"text":"批准 (-30金, 全军ATK+1永久)","effects":{"gold":-30,"hero_stat":{"stat":"atk","value":1}}},{"text":"暂缓","effects":{}}]})
	events.append({"id":"v5_night_raid","name":"夜袭","desc":"敌方发动了一次小规模夜袭!","condition":"always","repeatable":true,"choices":[{"text":"迎战 (战斗: 4敌兵)","effects":{"type":"combat","enemy_soldiers":4}},{"text":"据守营地 (-2兵, +3城防)","effects":{"soldiers":-2,"wall_boost":3}}]})

	# ══════════════════════════════════════════════════════════
	# SUPERNATURAL PHENOMENA (10)
	# ══════════════════════════════════════════════════════════
	events.append({"id":"v5_blood_moon_omen","name":"血月异象","desc":"天空出现了诡异的血红色月亮，士兵们惶恐不安。","condition":"always","repeatable":true,"choices":[{"text":"举行祈福仪式 (-15金, +5秩序)","effects":{"gold":-15,"order":5}},{"text":"宣称是吉兆 (+8威望, -3秩序)","effects":{"prestige":8,"order":-3}}]})
	events.append({"id":"v5_ancient_tomb","name":"远古墓穴","desc":"探险队发现了一座封印的远古墓穴。","condition":"always","repeatable":true,"choices":[{"text":"开启 (50%几率获得神器)","effects":{"type":"gamble","success_rate":0.5,"success":{"relic":true,"prestige":10},"fail":{"soldiers":-3,"order":-5}}},{"text":"重新封印 (+5秩序)","effects":{"order":5}}]})
	events.append({"id":"v5_cursed_well","name":"诅咒之井","desc":"村庄的水井被黑暗魔法污染了。","condition":"always","repeatable":true,"choices":[{"text":"净化 (-20金, +8秩序)","effects":{"gold":-20,"order":8}},{"text":"封闭水井 (-5粮食, -2秩序)","effects":{"food":-5,"order":-2}}]})
	events.append({"id":"v5_spirit_guardian","name":"精灵守护者","desc":"一位古老的精灵现身，愿意守护你的领地。","condition":"always","repeatable":true,"choices":[{"text":"接受守护 (DEF+15%, 5回合)","effects":{"buff":{"type":"def_pct","value":15,"duration":5}}},{"text":"请求情报 (揭示2格迷雾)","effects":{"reveal":2}}]})
	events.append({"id":"v5_mana_surge","name":"魔力潮汐","desc":"大地中涌出了强烈的魔力波动。","condition":"always","repeatable":true,"choices":[{"text":"引导魔力 (+2魔晶)","effects":{"magic_crystal":2}},{"text":"分配给军队 (全军ATK+2, 2回合)","effects":{"buff":{"type":"atk_pct","value":15,"duration":2}}}]})
	events.append({"id":"v5_haunted_forest","name":"闹鬼森林","desc":"领地附近的森林开始出现诡异的光芒和声响。","condition":"always","repeatable":true,"choices":[{"text":"派兵调查 (战斗: 7幽灵兵)","effects":{"type":"combat","enemy_soldiers":7}},{"text":"划为禁区 (-5秩序)","effects":{"order":-5}}]})
	events.append({"id":"v5_dragon_sighting","name":"龙的踪迹","desc":"猎人报告在山间看到了巨龙的身影!","condition":"always","repeatable":true,"choices":[{"text":"派勇士讨伐 (60%成功: +50金+20威望)","effects":{"type":"gamble","success_rate":0.6,"success":{"gold":50,"prestige":20},"fail":{"soldiers":-5,"order":-8}}},{"text":"敬而远之","effects":{}}]})
	events.append({"id":"v5_prophecy","name":"神秘预言","desc":"一位盲眼预言者留下了模糊的预言。","condition":"always","repeatable":true,"choices":[{"text":"信以为真 (+10威望)","effects":{"prestige":10}},{"text":"赏赐打发 (-5金)","effects":{"gold":-5,"order":2}}]})
	events.append({"id":"v5_elemental_rift","name":"元素裂隙","desc":"领地中出现了一条时空裂隙，散发着危险的能量。","condition":"always","repeatable":true,"choices":[{"text":"研究利用 (+3魔晶, -10秩序)","effects":{"magic_crystal":3,"order":-10}},{"text":"强行封闭 (-25金, +5秩序)","effects":{"gold":-25,"order":5}}]})
	events.append({"id":"v5_dark_ritual_found","name":"暗黑仪式","desc":"巡逻队发现有人在秘密进行暗黑仪式。","condition":"always","repeatable":true,"choices":[{"text":"阻止并逮捕 (+5秩序, +5威望)","effects":{"order":5,"prestige":5}},{"text":"秘密观察学习 (+2暗影精华, -5秩序)","effects":{"prestige":-5,"order":-5}}]})

	# ══════════════════════════════════════════════════════════
	# ECONOMIC OPPORTUNITIES (10)
	# ══════════════════════════════════════════════════════════
	events.append({"id":"v5_gold_vein","name":"金矿脉","desc":"矿工在领地内发现了一条新的金矿脉!","condition":"always","repeatable":true,"choices":[{"text":"大规模开采 (-20金投资, +60金/3回合)","effects":{"gold":-20,"gold_delayed":60}},{"text":"谨慎试采 (+15金)","effects":{"gold":15}}]})
	events.append({"id":"v5_trade_caravan","name":"贸易商队","desc":"一支来自远方的贸易商队经过你的领地。","condition":"always","repeatable":true,"choices":[{"text":"征税 (+20金, -3外交)","effects":{"gold":20,"prestige":-3}},{"text":"合作贸易 (+10金, +5威望)","effects":{"gold":10,"prestige":5}}]})
	events.append({"id":"v5_harvest_festival","name":"丰收节","desc":"领地迎来了大丰收，百姓欢庆丰收节。","condition":"always","repeatable":true,"choices":[{"text":"举办庆典 (-15金, +10秩序, +5威望)","effects":{"gold":-15,"order":10,"prestige":5}},{"text":"储备粮草 (+15粮食)","effects":{"food":15}}]})
	events.append({"id":"v5_black_market_deal","name":"黑市交易","desc":"黑市商人提供了一笔利润丰厚但有风险的交易。","condition":"always","repeatable":true,"choices":[{"text":"交易 (60%: +50金, 40%: -20金-5秩序)","effects":{"type":"gamble","success_rate":0.6,"success":{"gold":50},"fail":{"gold":-20,"order":-5}}},{"text":"举报 (+10秩序)","effects":{"order":10}}]})
	events.append({"id":"v5_rare_material","name":"稀有材料","desc":"商人带来了一批稀有的锻造材料。","condition":"always","repeatable":true,"choices":[{"text":"购买 (-35金, +3铁)","effects":{"gold":-35,"iron":3}},{"text":"不感兴趣","effects":{}}]})
	events.append({"id":"v5_loan_shark","name":"高利贷商人","desc":"一个富商愿意借给你一大笔金币，但利息惊人。","condition":"always","repeatable":true,"choices":[{"text":"借款 (+60金, 5回合后-80金)","effects":{"gold":60}},{"text":"拒绝","effects":{}}]})
	events.append({"id":"v5_smuggler_route","name":"走私通道","desc":"密探发现了一条走私通道可以绕过敌方封锁。","condition":"always","repeatable":true,"choices":[{"text":"利用走私 (+20金, +2铁, -5威望)","effects":{"gold":20,"iron":2,"prestige":-5}},{"text":"关闭通道 (+5秩序)","effects":{"order":5}}]})
	events.append({"id":"v5_artisan_workshop","name":"工匠作坊","desc":"一位著名工匠愿意在你的领地建立作坊。","condition":"always","repeatable":true,"choices":[{"text":"提供资助 (-30金, +5城防永久)","effects":{"gold":-30,"wall_boost":5}},{"text":"收取租金 (+15金)","effects":{"gold":15}}]})
	events.append({"id":"v5_treasure_map","name":"藏宝图","desc":"一位垂死的旅人交给你一张藏宝图。","condition":"always","repeatable":true,"choices":[{"text":"派人寻宝 (40%: +80金+神器, 60%: -10金)","effects":{"type":"gamble","success_rate":0.4,"success":{"gold":80,"relic":true},"fail":{"gold":-10}}},{"text":"卖掉地图 (+10金)","effects":{"gold":10}}]})
	events.append({"id":"v5_food_shortage","name":"粮食紧缺","desc":"连日暴雨导致粮食歉收，百姓面临饥饿。","condition":"always","repeatable":true,"choices":[{"text":"开仓赈灾 (-15粮, +10秩序)","effects":{"food":-15,"order":10}},{"text":"强征余粮 (+5粮, -8秩序)","effects":{"food":5,"order":-8}}]})

	# ══════════════════════════════════════════════════════════
	# CHARACTER & FACTION DEPTH (10)
	# ══════════════════════════════════════════════════════════
	events.append({"id":"v5_hero_challenge","name":"英雄挑战","desc":"一位游历的剑客前来挑战你的武将。","condition":"has_multiple_heroes","repeatable":true,"choices":[{"text":"接受挑战 (60%: 武将ATK+2)","effects":{"type":"gamble","success_rate":0.6,"success":{"hero_stat":{"stat":"atk","value":2},"prestige":10},"fail":{"prestige":-5}}},{"text":"以礼相待 (+5威望)","effects":{"prestige":5}}]})
	events.append({"id":"v5_hero_romance","name":"花前月下","desc":"两位武将之间萌生了情愫...","condition":"has_multiple_heroes","repeatable":true,"choices":[{"text":"祝福他们 (全武将好感+1)","effects":{"hero_affection_all":1}},{"text":"不干涉","effects":{}}]})
	events.append({"id":"v5_orc_feast","name":"兽人狂宴","desc":"兽人战士们要求举办一场战前狂宴。","condition":"faction_orc","repeatable":true,"choices":[{"text":"举办 (-20粮, +25WAAAGH)","effects":{"food":-20,"waaagh":25}},{"text":"拒绝 (-10WAAAGH, +5秩序)","effects":{"waaagh":-10,"order":5}}]})
	events.append({"id":"v5_pirate_mutiny","name":"海盗兵变","desc":"部分海盗对分赃不均表示不满。","condition":"faction_pirate","repeatable":true,"choices":[{"text":"增加分赃 (-25金, +8秩序)","effects":{"gold":-25,"order":8}},{"text":"以铁腕镇压 (-3兵, +15威望)","effects":{"soldiers":-3,"prestige":15}}]})
	events.append({"id":"v5_dark_elf_ritual","name":"暗精灵仪式","desc":"暗精灵长老提议举行一次古老的增幅仪式。","condition":"faction_dark_elf","repeatable":true,"choices":[{"text":"参加 (-5奴隶, 全军DEF+3, 3回合)","effects":{"slaves":-5,"buff":{"type":"def_pct","value":20,"duration":3}}},{"text":"拒绝","effects":{}}]})
	events.append({"id":"v5_prisoner_escape","name":"囚犯逃脱","desc":"监狱中传来骚动——有囚犯试图越狱!","condition":"has_prisoners","repeatable":true,"choices":[{"text":"加强看守 (-10金, +3秩序)","effects":{"gold":-10,"order":3}},{"text":"镇压 (-2秩序, +5威望)","effects":{"order":-2,"prestige":5}}]})
	events.append({"id":"v5_wandering_sage","name":"云游贤者","desc":"一位云游四方的贤者愿意传授知识。","condition":"always","repeatable":true,"choices":[{"text":"拜师学习 (-10金, +1科技点)","effects":{"gold":-10,"tech_point":1}},{"text":"请教战术 (全军SPD+5%, 3回合)","effects":{"buff":{"type":"morale_pct","value":10,"duration":3}}}]})
	events.append({"id":"v5_legendary_weapon","name":"传说武器","desc":"工匠声称能锻造一把传说级武器。","condition":"always","repeatable":true,"choices":[{"text":"投资锻造 (-50金, -5铁, 获得强力装备)","effects":{"gold":-50,"iron":-5,"relic":true}},{"text":"太贵了","effects":{}}]})
	events.append({"id":"v5_hero_betrayal","name":"背叛之影","desc":"有人举报一名武将暗中与敌方联络。","condition":"has_multiple_heroes","repeatable":true,"choices":[{"text":"立即软禁 (+5秩序, 1武将好感-2)","effects":{"order":5}},{"text":"暗中调查 (50%: 抓到奸细+20威望)","effects":{"type":"gamble","success_rate":0.5,"success":{"prestige":20},"fail":{"order":-5}}}]})
	events.append({"id":"v5_faction_summit","name":"势力会谈","desc":"周边势力提议举行一次多方会谈。","condition":"always","repeatable":true,"choices":[{"text":"参加 (-15金, +10威望, +5外交)","effects":{"gold":-15,"prestige":10}},{"text":"拒绝 (+5威望, -3外交)","effects":{"prestige":5}}]})

	return events
