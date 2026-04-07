## development_quest_data.gd — 18条领地/城堡发展里程碑任务
## 供 QuestManager 加载，分为建设/经济/军事/外交四组。
extends RefCounted

const DEVELOPMENT_QUESTS: Array = [
	# ═══════════════ 建设类 (Construction) — 5 quests ═══════════════
	{
		"id": "dev_first_wall", "name": "初建城防",
		"desc": "在你的领地上建起第一道城墙，为日后的防御体系奠定基础。",
		"category": "development",
		"trigger": {},
		"objectives": [
			{"type": "building_level_min", "building": "wall", "value": 1, "label": "建造1级城墙"},
		],
		"reward": {"gold": 100, "message": "城防初成，领地安全得到保障。"},
		"choices": [
			{"text": "修筑石墙（防御+2）", "effects": {"tile_defense": 2}},
			{"text": "搭建木栅栏（防御+1，节省50金币）", "effects": {"tile_defense": 1, "gold": 50}},
		],
		"ai_effects": {"player_defense_posture": "fortifying"},
	},
	{
		"id": "dev_upgrade_fortress", "name": "要塞升级",
		"desc": "将任意一座建筑升级至3级，展现你卓越的建设能力。",
		"category": "development",
		"trigger": {"turn_min": 5},
		"objectives": [
			{"type": "building_level_min", "building": "any", "value": 3, "label": "任意建筑达到3级"},
		],
		"reward": {"gold": 200, "message": "高等级建筑落成，领地实力大幅提升。"},
		"choices": [],
		"ai_effects": {"player_infrastructure": "advanced"},
	},
	{
		"id": "dev_full_construction", "name": "全面建设",
		"desc": "在广袤的领地上兴建五座以上建筑，打造全面发展的根据地。",
		"category": "development",
		"trigger": {"tiles_min": 8},
		"objectives": [
			{"type": "buildings_min", "value": 5, "label": "拥有5座以上建筑"},
		],
		"reward": {"gold": 150, "message": "全面建设完成，领地欣欣向荣。"},
		"choices": [
			{"text": "军事优先（兵营与城墙建造费用-20%）", "effects": {"military_build_cost_pct": -20}},
			{"text": "经济优先（市场与农场建造费用-20%）", "effects": {"economic_build_cost_pct": -20}},
		],
		"ai_effects": {"player_expansion_type": "balanced"},
	},
	{
		"id": "dev_iron_walls", "name": "铁壁防线",
		"desc": "确保所有要塞的城墙等级达到2级以上，构筑坚不可摧的防线。",
		"category": "development",
		"trigger": {"strongholds_min": 1},
		"objectives": [
			{"type": "building_level_min", "building": "wall", "value": 2, "label": "所有要塞城墙达到2级"},
		],
		"reward": {"trait": "iron_defense", "message": "铁壁防线已成，敌军望而却步。"},
		"choices": [],
		"ai_effects": {"player_defense_rating": "high"},
	},
	{
		"id": "dev_master_builder", "name": "建筑大师",
		"desc": "在领地内建造十座以上建筑，成为名副其实的建筑大师。",
		"category": "development",
		"trigger": {"tiles_min": 10},
		"objectives": [
			{"type": "buildings_min", "value": 10, "label": "拥有10座以上建筑"},
		],
		"reward": {"buff": {"type": "build_cost_pct", "value": -15, "duration": 99}, "message": "建筑大师之名远扬，所有建造费用永久降低15%。"},
		"choices": [],
		"ai_effects": {"player_build_efficiency": "master"},
	},
	# ═══════════════ 经济类 (Economy) — 4 quests ═══════════════
	{
		"id": "dev_first_harvest", "name": "初次丰收",
		"desc": "积累500金币，完成你的第一桶金，为进一步扩张奠定经济基础。",
		"category": "development",
		"trigger": {},
		"objectives": [
			{"type": "gold_min", "value": 500, "label": "积累500金币"},
		],
		"reward": {"gold": 100, "message": "初次丰收！额外获得100金币奖励。"},
		"choices": [],
		"ai_effects": {"player_economy": "growing"},
	},
	{
		"id": "dev_trade_network", "name": "贸易网络",
		"desc": "控制两个以上的贸易站，建立起初步的贸易网络。",
		"category": "development",
		"trigger": {"tile_type_min": {"type": "TRADING_POST", "value": 1}},
		"objectives": [
			{"type": "tile_type_min", "tile_type": "TRADING_POST", "value": 2, "label": "拥有2个以上贸易站"},
		],
		"reward": {"gold": 200, "message": "贸易网络初步建成，商路繁忙。"},
		"choices": [
			{"text": "征收贸易税（每回合+30金，商人好感-10）", "effects": {"gold_per_turn": 30, "merchant_rep": -10}},
			{"text": "自由贸易（每回合+15金，商人好感+10）", "effects": {"gold_per_turn": 15, "merchant_rep": 10}},
		],
		"ai_effects": {"player_trade_presence": "established"},
	},
	{
		"id": "dev_war_chest", "name": "战争宝箱",
		"desc": "积累2000金币的战争储备金，为大规模军事行动做好准备。",
		"category": "development",
		"trigger": {"turn_min": 8},
		"objectives": [
			{"type": "gold_min", "value": 2000, "label": "积累2000金币"},
		],
		"reward": {"buff": {"type": "gold_per_turn", "value": 20, "duration": 99}, "message": "战争宝箱充盈，每回合额外获得20金币。"},
		"choices": [],
		"ai_effects": {"player_war_readiness": "high"},
	},
	{
		"id": "dev_economic_empire", "name": "经济帝国",
		"desc": "同时拥有三个以上贸易站和1500金币以上的储备，建立强大的经济帝国。",
		"category": "development",
		"trigger": {"tile_type_min": {"type": "TRADING_POST", "value": 2}, "turn_min": 10},
		"objectives": [
			{"type": "tile_type_min", "tile_type": "TRADING_POST", "value": 3, "label": "拥有3个以上贸易站"},
			{"type": "gold_min", "value": 1500, "label": "持有1500金币以上"},
		],
		"reward": {"trait": "merchant_lord", "gold": 500, "message": "经济帝国崛起！获得'商业霸主'称号和500金币。"},
		"choices": [],
		"ai_effects": {"player_economy": "dominant", "ai_trade_competition": true},
	},
	# ═══════════════ 军事类 (Military) — 5 quests ═══════════════
	{
		"id": "dev_first_army", "name": "初建军团",
		"desc": "组建你的第一支正规军团，拥有至少20名士兵的战斗力量。",
		"category": "development",
		"trigger": {},
		"objectives": [
			{"type": "armies_min", "value": 1, "soldiers_min": 20, "label": "拥有1支20人以上的军队"},
		],
		"reward": {"gold": 50, "message": "第一支军团组建完毕，随时可以出征。"},
		"choices": [],
		"ai_effects": {"player_military_presence": true},
	},
	{
		"id": "dev_dual_front", "name": "双线作战",
		"desc": "同时维持两支以上军队，具备多线作战的能力。",
		"category": "development",
		"trigger": {"turn_min": 3},
		"objectives": [
			{"type": "armies_min", "value": 2, "label": "拥有2支以上军队"},
		],
		"reward": {"ap_max_bonus": 1, "message": "双线作战能力达成，最大行动点+1。"},
		"choices": [],
		"ai_effects": {"player_military_threat": "multi_front"},
	},
	{
		"id": "dev_veteran_force", "name": "百战之师",
		"desc": "累计赢得10场战斗，锤炼出一支真正的百战之师。",
		"category": "development",
		"trigger": {"battles_won_min": 5},
		"objectives": [
			{"type": "battles_won_min", "value": 10, "label": "累计赢得10场战斗"},
		],
		"reward": {"prestige": 20, "message": "百战之师威名远扬。"},
		"choices": [
			{"text": "精锐化训练（全军攻击+10%）", "effects": {"army_atk_pct": 10}},
			{"text": "大规模征兵（所有军队+5士兵）", "effects": {"all_armies_soldiers": 5}},
		],
		"ai_effects": {"player_army_quality": "veteran"},
	},
	{
		"id": "dev_hero_academy", "name": "英雄学院",
		"desc": "招募三名以上英雄，建立起可靠的英雄团队。",
		"category": "development",
		"trigger": {"turn_min": 5},
		"objectives": [
			{"type": "hero_count_min", "value": 3, "label": "招募3名以上英雄"},
		],
		"reward": {"buff": {"type": "hero_exp_pct", "value": 20, "duration": 99}, "message": "英雄学院成立，英雄经验获取永久提升20%。"},
		"choices": [],
		"ai_effects": {"player_hero_strength": "academy"},
	},
	{
		"id": "dev_war_machine", "name": "战争机器",
		"desc": "拥有四支以上军队并控制20块以上领地，成为不可阻挡的战争机器。",
		"category": "development",
		"trigger": {"armies_min": 3, "tiles_min": 15},
		"objectives": [
			{"type": "armies_min", "value": 4, "label": "拥有4支以上军队"},
			{"type": "tiles_min", "value": 20, "label": "控制20块以上领地"},
		],
		"reward": {"trait": "war_machine", "buff": {"type": "all_stats_pct", "value": 5, "duration": 99}, "message": "战争机器全面启动！获得'战争机器'称号，所有军队属性永久+5%。"},
		"choices": [],
		"ai_effects": {"player_military_threat": "overwhelming", "ai_defensive_posture": true},
	},
	# ═══════════════ 外交类 (Diplomacy) — 4 quests ═══════════════
	{
		"id": "dev_first_contact", "name": "初次邂逅",
		"desc": "招募第一位中立英雄，迈出外交的第一步。",
		"category": "development",
		"trigger": {},
		"objectives": [
			{"type": "hero_count_min", "value": 1, "label": "招募1名中立英雄"},
		],
		"reward": {"gold": 100, "buff": {"type": "diplomacy", "value": 10, "duration": 99}, "message": "初次邂逅！获得100金币，外交值+10。"},
		"choices": [],
		"ai_effects": {"player_diplomacy": "open"},
	},
	{
		"id": "dev_influence_spread", "name": "影响力扩散",
		"desc": "将你的势力延伸至三种以上不同地形，展现广泛的影响力。",
		"category": "development",
		"trigger": {"tiles_min": 5},
		"objectives": [
			{"type": "terrain_tiles_min", "value": 3, "label": "在3种以上不同地形拥有领地"},
		],
		"reward": {"prestige": 15, "message": "你的影响力遍布大陆各处。"},
		"choices": [
			{"text": "文化同化（新占领地秩序+15）", "effects": {"new_tile_order": 15}},
			{"text": "军事占领（新占领地驻军+5）", "effects": {"new_tile_garrison": 5}},
		],
		"ai_effects": {"player_influence": "widespread"},
	},
	{
		"id": "dev_feared_ruler", "name": "令人畏惧的统治者",
		"desc": "当你的威胁值达到30以上，整个大陆都在你的阴影之下颤抖。",
		"category": "development",
		"trigger": {"threat_min": 15},
		"objectives": [
			{"type": "threat_min", "value": 30, "label": "威胁值达到30"},
		],
		"reward": {"buff": {"type": "enemy_morale_debuff", "value": -10, "duration": 99}, "message": "你的威名令敌军士气永久降低10。"},
		"choices": [],
		"ai_effects": {"ai_fear_factor": 30, "ai_avoid_player": true},
	},
	{
		"id": "dev_continental_power", "name": "大陆强权",
		"desc": "控制20块以上领地、拥有3名以上英雄且威胁值达到40，成为大陆上无可争议的强权。",
		"category": "development",
		"trigger": {"tiles_min": 15, "hero_count_min": 2, "threat_min": 30},
		"objectives": [
			{"type": "tiles_min", "value": 20, "label": "控制20块以上领地"},
			{"type": "hero_count_min", "value": 3, "label": "拥有3名以上英雄"},
			{"type": "threat_min", "value": 40, "label": "威胁值达到40"},
		],
		"reward": {"trait": "continental_power", "gold": 1000, "message": "大陆强权崛起！获得'大陆强权'称号和1000金币。"},
		"choices": [],
		"ai_effects": {"ai_alliance_against_player": true, "global_threat_modifier": 1.5},
	},
]
