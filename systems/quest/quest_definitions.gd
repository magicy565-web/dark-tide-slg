## quest_definitions.gd — 主线/支线/角色任务数据定义
## 挑战任务数据在 challenge_quest_data.gd 中定义
extends RefCounted
class_name QuestDefinitions

const FactionData = preload("res://systems/faction/faction_data.gd")

# ═══════════════ QUEST CATEGORIES ═══════════════
enum QuestType { MAIN, SIDE, CHALLENGE, CHARACTER }
enum QuestStatus { LOCKED, AVAILABLE, ACTIVE, COMBAT_PENDING, COMPLETED, FAILED }

# ═══════════════ MAIN QUEST LINE ═══════════════
# 6-stage story progression, faction-agnostic (adapts to chosen faction).
# Rewards scale with progression; final stage triggers endgame.

const MAIN_QUESTS: Array = [
	{
		"id": "main_1", "name": "崛起之始",
		"desc": "巩固你的根据地，建立初始势力范围。",
		"trigger": {},  # Available from start
		"objectives": [
			{"type": "tiles_min", "value": 5, "label": "占领5个领地"},
			{"type": "building_any", "value": 1, "label": "建造1座建筑"},
		],
		"reward": {"gold": 200, "food": 50, "message": "你的势力开始崭露头角。"},
	},
	{
		"id": "main_2", "name": "第一滴血",
		"desc": "在战场上证明你的军事才能。",
		"trigger": {"main_quest_completed": "main_1"},
		"objectives": [
			{"type": "battles_won_min", "value": 3, "label": "赢得3场战斗"},
			{"type": "army_count_min", "value": 2, "label": "拥有2支军团"},
		],
		"reward": {"gold": 300, "item": "war_totem", "message": "你的军威开始传播。"},
	},
	{
		"id": "main_3", "name": "扩张的野心",
		"desc": "拓展你的版图，将势力范围延伸到新的区域。",
		"trigger": {"main_quest_completed": "main_2"},
		"objectives": [
			{"type": "tiles_min", "value": 15, "label": "占领15个领地"},
			{"type": "neutral_recruited_min", "value": 1, "label": "招募1个中立势力"},
		],
		"reward": {"gold": 500, "iron": 100, "message": "中立势力开始注意到你的崛起。"},
	},
	{
		"id": "main_4", "name": "光暗对峙",
		"desc": "光明联盟已将你视为威胁。是时候正面对决了。",
		"trigger": {"main_quest_completed": "main_3"},
		"objectives": [
			{"type": "threat_min", "value": 40, "label": "威胁值达到40"},
			{"type": "strongholds_min", "value": 1, "label": "攻占1座光明要塞"},
		],
		"reward": {"gold": 800, "item": "blood_moon_blade", "message": "光明联盟的第一道防线已经崩溃。"},
	},
	{
		"id": "main_5", "name": "黑暗崛起",
		"desc": "彻底瓦解光明联盟的抵抗力量。",
		"trigger": {"main_quest_completed": "main_4"},
		"objectives": [
			{"type": "tiles_min", "value": 25, "label": "占领25个领地"},
			{"type": "heroes_min", "value": 4, "label": "拥有4名英雄"},
			{"type": "strongholds_min", "value": 3, "label": "攻占3座要塞"},
		],
		"reward": {"gold": 1000, "iron": 200, "relic": "chaos_amulet", "message": "光明的时代即将落幕。"},
	},
	{
		"id": "main_6", "name": "终焉之战",
		"desc": "消灭所有抵抗，统一大陆。这是最终决战。",
		"trigger": {"main_quest_completed": "main_5"},
		"objectives": [
			{"type": "all_strongholds", "value": true, "label": "攻占所有光明要塞"},
		],
		"reward": {"title": "大陆霸主", "message": "你统一了整个大陆！游戏胜利！"},
	},
]

# ═══════════════ SIDE QUESTS ═══════════════
# One-time optional quests, unlocked by game state conditions.
# Each grants a meaningful but non-essential reward.

const SIDE_QUESTS: Array = [
	{
		"id": "side_builder", "name": "领地建设者",
		"desc": "在你的领地中建造多种建筑，发展经济基础。",
		"trigger": {"tiles_min": 3},
		"objectives": [
			{"type": "buildings_min", "value": 3, "label": "建造3座不同建筑"},
		],
		"reward": {"gold": 150, "message": "建设成果显著。"},
	},
	{
		"id": "side_economist", "name": "经济大师",
		"desc": "积累大量财富，证明你的经济管理能力。",
		"trigger": {"turn_min": 5},
		"objectives": [
			{"type": "gold_min", "value": 1200, "label": "持有1200金币"},
			{"type": "food_min", "value": 300, "label": "持有300粮食"},
		],
		"reward": {"gold": 300, "item": "garrison_banner", "message": "你的国库充盈。"},
	},
	{
		"id": "side_diplomat", "name": "外交纵横家",
		"desc": "通过外交手段招募多个中立势力。",
		"trigger": {"neutral_recruited_min": 1},
		"objectives": [
			{"type": "neutral_recruited_min", "value": 3, "label": "招募3个中立势力"},
		],
		"reward": {"gold": 400, "prestige": 20, "message": "你的外交网络遍布大陆。"},
	},
	{
		"id": "side_warden", "name": "秩序守护者",
		"desc": "在混乱中维持高秩序值，证明你的统治力。",
		"trigger": {"turn_min": 8},
		"objectives": [
			{"type": "order_min", "value": 50, "label": "秩序值保持50以上"},
			{"type": "tiles_min", "value": 12, "label": "同时拥有12个领地"},
		],
		"reward": {"gold": 200, "order_bonus": 10, "message": "你的领地秩序井然。"},
	},
	{
		"id": "side_conqueror", "name": "闪电战",
		"desc": "在短时间内快速扩张。",
		"trigger": {"turn_min": 3},
		"objectives": [
			{"type": "tiles_gained_in_turns", "value": 5, "turns": 3, "label": "3回合内占领5个领地"},
		],
		"reward": {"gold": 500, "item": "gale_boots", "message": "你的进攻势如破竹。"},
	},
	{
		"id": "side_slavelord", "name": "奴隶帝国",
		"desc": "建立庞大的奴隶劳动力体系。(暗精灵限定)",
		"trigger": {"faction": FactionData.FactionID.DARK_ELF, "turn_min": 5},
		"objectives": [
			{"type": "slaves_min", "value": 20, "label": "拥有20名奴隶"},
		],
		"reward": {"shadow_essence": 10, "gold": 300, "message": "暗影精华源源不断。"},
	},
	{
		"id": "side_pirate_fleet", "name": "无敌舰队",
		"desc": "建立强大的海上力量。(海盗限定)",
		"trigger": {"faction": FactionData.FactionID.PIRATE, "turn_min": 5},
		"objectives": [
			{"type": "harbor_min", "value": 2, "label": "控制2个港口"},
			{"type": "army_count_min", "value": 3, "label": "拥有3支军团"},
		],
		"reward": {"gold": 500, "plunder": 30, "message": "你的舰队无人可挡。"},
	},
	{
		"id": "side_waaagh_fury", "name": "WAAAGH!的怒火",
		"desc": "引爆WAAAGH!狂暴的力量。(兽人限定)",
		"trigger": {"faction": FactionData.FactionID.ORC, "turn_min": 5},
		"objectives": [
			{"type": "waaagh_frenzy_triggered", "value": true, "label": "触发WAAAGH!狂暴状态"},
		],
		"reward": {"gold": 300, "waaagh": 20, "message": "WAAAGH!的力量响彻战场！"},
	},
	{
		"id": "side_hero_collector", "name": "英雄收集家",
		"desc": "招募多名英雄，组建强大的指挥团。",
		"trigger": {"heroes_min": 1},
		"objectives": [
			{"type": "heroes_min", "value": 5, "label": "招募5名英雄"},
		],
		"reward": {"gold": 400, "item": "counter_tactics", "message": "强大的英雄团队已就位。"},
	},
	{
		"id": "side_survivor", "name": "绝境求生",
		"desc": "在一次光明远征军的进攻中成功防守。",
		"trigger": {"threat_min": 30},
		"objectives": [
			{"type": "defend_expedition", "value": true, "label": "成功抵御1次光明远征"},
		],
		"reward": {"gold": 300, "prestige": 15, "message": "你在逆境中证明了自己。"},
	},
]

# ═══════════════ CHARACTER QUESTS ═══════════════
# Hero affection-driven personal quest chains (3 steps each).
# Triggered at affection 3, 5, and 8. Rewards deepen hero bond.

const CHARACTER_QUESTS: Dictionary = {
	"rin": {
		"hero_id": "rin", "hero_name": "凛",
		"steps": [
			{
				"id": "rin_cq1", "name": "凛: 骑士的荣耀",
				"affection_required": 3,
				"desc": "凛希望你能证明自己配得上她的追随。",
				"objective": {"type": "battles_won_min", "value": 5, "label": "赢得5场战斗"},
				"reward": {"affection": 2, "message": "「你的剑技...令人刮目相看。」"},
			},
			{
				"id": "rin_cq2", "name": "凛: 被夺走的家园",
				"affection_required": 5,
				"desc": "凛请求你帮助夺回她曾经守护的村庄。",
				"objective": {"type": "tiles_min", "value": 15, "label": "占领15个领地"},
				"reward": {"affection": 2, "equipment": "rin_sacred_blade", "message": "「这把剑...交给你保管。」"},
			},
			{
				"id": "rin_cq3", "name": "凛: 誓约",
				"affection_required": 8,
				"desc": "凛向你袒露了心声。",
				"objective": {"type": "strongholds_min", "value": 2, "label": "攻占2座要塞"},
				"reward": {"affection": 2, "trait": "rin_oath_bond", "message": "「从今以后...我的剑只为你而挥。」"},
			},
		],
	},
	"suirei": {
		"hero_id": "suirei", "hero_name": "翠玲",
		"steps": [
			{
				"id": "suirei_cq1", "name": "翠玲: 森林的呼唤",
				"affection_required": 3,
				"desc": "翠玲想确认你是否尊重自然。",
				"objective": {"type": "neutral_recruited_min", "value": 1, "label": "招募1个中立势力"},
				"reward": {"affection": 2, "message": "「你并非只知破坏的野蛮人...」"},
			},
			{
				"id": "suirei_cq2", "name": "翠玲: 精灵之弓",
				"affection_required": 5,
				"desc": "翠玲愿意将家传的精灵弓赠予你。",
				"objective": {"type": "heroes_min", "value": 3, "label": "拥有3名英雄"},
				"reward": {"affection": 2, "equipment": "suirei_elf_bow", "message": "「请善用这把弓。」"},
			},
			{
				"id": "suirei_cq3", "name": "翠玲: 月下之约",
				"affection_required": 8,
				"desc": "翠玲在月光下等待着你。",
				"objective": {"type": "tiles_min", "value": 20, "label": "占领20个领地"},
				"reward": {"affection": 2, "trait": "suirei_moon_blessing", "message": "「月光会守护你...永远。」"},
			},
		],
	},
	"sou": {
		"hero_id": "sou", "hero_name": "蒼",
		"steps": [
			{
				"id": "sou_cq1", "name": "蒼: 知识的渴望",
				"affection_required": 3,
				"desc": "蒼想测试你的战略智慧。",
				"objective": {"type": "buildings_min", "value": 5, "label": "建造5座建筑"},
				"reward": {"affection": 2, "message": "「你不只是个武夫，很好。」"},
			},
			{
				"id": "sou_cq2", "name": "蒼: 禁忌魔导书",
				"affection_required": 5,
				"desc": "蒼找到了一本古代魔导书，但需要素材来解读。",
				"objective": {"type": "gold_min", "value": 1000, "label": "持有1000金币"},
				"reward": {"affection": 2, "equipment": "sou_arcane_tome", "message": "「这本书的秘密...只属于我们。」"},
			},
			{
				"id": "sou_cq3", "name": "蒼: 大贤者的觉醒",
				"affection_required": 8,
				"desc": "蒼的魔力觉醒到了新的境界。",
				"objective": {"type": "threat_min", "value": 60, "label": "威胁值达到60"},
				"reward": {"affection": 2, "trait": "sou_archmage_awakening", "message": "「我的全部力量...都为你所用。」"},
			},
		],
	},
	"homura": {
		"hero_id": "homura", "hero_name": "焔",
		"steps": [
			{
				"id": "homura_cq1", "name": "焔: 燃烧的意志",
				"affection_required": 3,
				"desc": "焔想看到你在战斗中的果断。",
				"objective": {"type": "battles_won_min", "value": 8, "label": "赢得8场战斗"},
				"reward": {"affection": 2, "message": "「不错的气魄！」"},
			},
			{
				"id": "homura_cq2", "name": "焔: 火之试炼",
				"affection_required": 5,
				"desc": "焔准备了一件用她的火焰锻造的武器。",
				"objective": {"type": "iron_min", "value": 150, "label": "持有150铁矿"},
				"reward": {"affection": 2, "equipment": "homura_flame_gauntlet", "message": "「用这个...烧尽一切阻碍！」"},
			},
			{
				"id": "homura_cq3", "name": "焔: 不灭之焰",
				"affection_required": 8,
				"desc": "焔将自己的灵魂之火与你共享。",
				"objective": {"type": "strongholds_min", "value": 2, "label": "攻占2座要塞"},
				"reward": {"affection": 2, "trait": "homura_eternal_flame", "message": "「我的火焰...永远不会熄灭。」"},
			},
		],
	},
	"yukino": {
		"hero_id": "yukino", "hero_name": "雪乃",
		"steps": [
			{
				"id": "yukino_cq1", "name": "雪乃: 圣光治愈者",
				"affection_required": 3,
				"desc": "雪乃希望你能在战场上展现力量。",
				"objective": {"type": "battles_won_min", "value": 5, "label": "赢得5场战斗"},
				"reward": {"affection": 2, "message": "「你的力量...让人安心。」"},
			},
			{
				"id": "yukino_cq2", "name": "雪乃: 圣杖的传承",
				"affection_required": 5,
				"desc": "雪乃需要更多的伙伴来守护和平。",
				"objective": {"type": "heroes_min", "value": 2, "label": "招募2名英雄"},
				"reward": {"affection": 2, "equipment": "yukino_holy_staff", "message": "「这根圣杖...请用它守护大家。」"},
			},
			{
				"id": "yukino_cq3", "name": "雪乃: 圣域",
				"affection_required": 8,
				"desc": "雪乃决定以圣光守护你的全部领地。",
				"objective": {"type": "tiles_min", "value": 20, "label": "占领20个领地"},
				"reward": {"affection": 2, "trait": "yukino_sanctuary", "message": "「我的圣光...将永远照耀这片大地。」"},
			},
		],
	},
	"momiji": {
		"hero_id": "momiji", "hero_name": "紅葉",
		"steps": [
			{
				"id": "momiji_cq1", "name": "紅葉: 骑兵指挥官",
				"affection_required": 3,
				"desc": "紅葉想看到你的领地扩张能力。",
				"objective": {"type": "tiles_min", "value": 8, "label": "占领8个领地"},
				"reward": {"affection": 2, "message": "「不错的战略眼光。」"},
			},
			{
				"id": "momiji_cq2", "name": "紅葉: 军配扇的授予",
				"affection_required": 5,
				"desc": "紅葉需要你在战场上证明实力。",
				"objective": {"type": "battles_won_min", "value": 10, "label": "赢得10场战斗"},
				"reward": {"affection": 2, "equipment": "momiji_war_fan", "message": "「这把军配扇...象征着天下布武的意志。」"},
			},
			{
				"id": "momiji_cq3", "name": "紅葉: 名将之风",
				"affection_required": 8,
				"desc": "紅葉认可你为真正的统帅。",
				"objective": {"type": "threat_min", "value": 50, "label": "威胁值达到50"},
				"reward": {"affection": 2, "trait": "momiji_general", "message": "「从今以后...我的骑兵团只听从你的号令。」"},
			},
		],
	},
	"hyouka": {
		"hero_id": "hyouka", "hero_name": "冰華",
		"steps": [
			{
				"id": "hyouka_cq1", "name": "冰華: 聖殿騎士",
				"affection_required": 3,
				"desc": "冰華想确认你有建设领地的能力。",
				"objective": {"type": "buildings_min", "value": 3, "label": "建造3座建筑"},
				"reward": {"affection": 2, "message": "「你懂得守护的意义。」"},
			},
			{
				"id": "hyouka_cq2", "name": "冰華: 水晶盾的觉醒",
				"affection_required": 5,
				"desc": "冰華需要你扩大防御范围。",
				"objective": {"type": "tiles_min", "value": 15, "label": "占领15个领地"},
				"reward": {"affection": 2, "equipment": "hyouka_crystal_shield", "message": "「这面盾...将挡住一切攻击。」"},
			},
			{
				"id": "hyouka_cq3", "name": "冰華: 铁壁守护",
				"affection_required": 8,
				"desc": "冰華将自己的防御信念与你共享。",
				"objective": {"type": "battles_won_min", "value": 15, "label": "赢得15场战斗"},
				"reward": {"affection": 2, "trait": "hyouka_bastion", "message": "「我的盾...就是你的城墙。」"},
			},
		],
	},
	"gekka": {
		"hero_id": "gekka", "hero_name": "月華",
		"steps": [
			{
				"id": "gekka_cq1", "name": "月華: 精灵祭司",
				"affection_required": 3,
				"desc": "月華想确认你是否懂得外交。",
				"objective": {"type": "neutral_recruited_min", "value": 1, "label": "招募1个中立势力"},
				"reward": {"affection": 2, "message": "「你并非只会用武力...」"},
			},
			{
				"id": "gekka_cq2", "name": "月華: 月光石的秘密",
				"affection_required": 5,
				"desc": "月華需要资金来进行月光石的仪式。",
				"objective": {"type": "gold_min", "value": 800, "label": "持有800金币"},
				"reward": {"affection": 2, "equipment": "gekka_moonstone", "message": "「月光石...感应到了你的心意。」"},
			},
			{
				"id": "gekka_cq3", "name": "月華: 月光祝福",
				"affection_required": 8,
				"desc": "月華以月光祝福你的军团。",
				"objective": {"type": "heroes_min", "value": 4, "label": "拥有4名英雄"},
				"reward": {"affection": 2, "trait": "gekka_moonlight", "message": "「月光将永远照耀你的道路。」"},
			},
		],
	},
	"hakagure": {
		"hero_id": "hakagure", "hero_name": "葉隱",
		"steps": [
			{
				"id": "hakagure_cq1", "name": "葉隱: 影之忍者",
				"affection_required": 3,
				"desc": "葉隱想看到你的战斗实力。",
				"objective": {"type": "battles_won_min", "value": 8, "label": "赢得8场战斗"},
				"reward": {"affection": 2, "message": "「你的实力...勉强合格。」"},
			},
			{
				"id": "hakagure_cq2", "name": "葉隱: 影刃的传授",
				"affection_required": 5,
				"desc": "葉隱需要你展现足够的威慑力。",
				"objective": {"type": "threat_min", "value": 40, "label": "威胁值达到40"},
				"reward": {"affection": 2, "equipment": "hakagure_shadow_blade", "message": "「这把影刃...只有强者才能驾驭。」"},
			},
			{
				"id": "hakagure_cq3", "name": "葉隱: 幻影",
				"affection_required": 8,
				"desc": "葉隱将影之秘术传授于你的军团。",
				"objective": {"type": "strongholds_min", "value": 2, "label": "攻占2座要塞"},
				"reward": {"affection": 2, "trait": "hakagure_phantom", "message": "「从今以后...我的影子就是你的盾。」"},
			},
		],
	},
	"shion": {
		"hero_id": "shion", "hero_name": "紫苑",
		"steps": [
			{
				"id": "shion_cq1", "name": "紫苑: 时空魔导师",
				"affection_required": 3,
				"desc": "紫苑想确认你有发展领地的能力。",
				"objective": {"type": "buildings_min", "value": 5, "label": "建造5座建筑"},
				"reward": {"affection": 2, "message": "「你对时间的运用...很有效率。」"},
			},
			{
				"id": "shion_cq2", "name": "紫苑: 时之砂漏",
				"affection_required": 5,
				"desc": "紫苑需要大量资金来完成时之砂漏的制作。",
				"objective": {"type": "gold_min", "value": 1200, "label": "持有1200金币"},
				"reward": {"affection": 2, "equipment": "shion_hourglass", "message": "「时之砂漏...现在属于你了。」"},
			},
			{
				"id": "shion_cq3", "name": "紫苑: 时空支配",
				"affection_required": 8,
				"desc": "紫苑将时空之力与你共享。",
				"objective": {"type": "threat_min", "value": 60, "label": "威胁值达到60"},
				"reward": {"affection": 2, "trait": "shion_time_lord", "message": "「时间...将永远站在你这边。」"},
			},
		],
	},
	"shion_pirate": {
		"hero_id": "shion_pirate", "hero_name": "潮音",
		"steps": [
			{
				"id": "shion_pirate_cq1", "name": "潮音: 海盗射手",
				"affection_required": 3,
				"desc": "潮音想看到你的领地扩张。",
				"objective": {"type": "tiles_min", "value": 6, "label": "占领6个领地"},
				"reward": {"affection": 2, "message": "「还行吧，船长。」"},
			},
			{
				"id": "shion_pirate_cq2", "name": "潮音: 连弩的秘密",
				"affection_required": 5,
				"desc": "潮音需要资金来改造她的连弩。",
				"objective": {"type": "gold_min", "value": 1000, "label": "持有1000金币"},
				"reward": {"affection": 2, "equipment": "shion_pirate_crossbow", "message": "「这把连弩...能让敌人闻风丧胆！」"},
			},
			{
				"id": "shion_pirate_cq3", "name": "潮音: 潮汐之力",
				"affection_required": 8,
				"desc": "潮音将海洋的力量赋予你的军团。",
				"objective": {"type": "tiles_min", "value": 15, "label": "占领15个领地"},
				"reward": {"affection": 2, "trait": "shion_pirate_tides", "message": "「大海的力量...永远与你同在！」"},
			},
		],
	},
	"youya": {
		"hero_id": "youya", "hero_name": "妖夜",
		"steps": [
			{
				"id": "youya_cq1", "name": "妖夜: 暗影刺客",
				"affection_required": 3,
				"desc": "妖夜想确认你的战斗能力。",
				"objective": {"type": "battles_won_min", "value": 5, "label": "赢得5场战斗"},
				"reward": {"affection": 2, "message": "「你的手法...还算利落。」"},
			},
			{
				"id": "youya_cq2", "name": "妖夜: 毒蛇匕首",
				"affection_required": 5,
				"desc": "妖夜需要你俘获敌方英雄来证明实力。",
				"objective": {"type": "heroes_captured_min", "value": 2, "label": "俘获2名敌方英雄"},
				"reward": {"affection": 2, "equipment": "youya_venom_dagger", "message": "「这把匕首...沾满了毒液。」"},
			},
			{
				"id": "youya_cq3", "name": "妖夜: 夜之支配者",
				"affection_required": 8,
				"desc": "妖夜将暗影之力与你共享。",
				"objective": {"type": "tiles_min", "value": 18, "label": "占领18个领地"},
				"reward": {"affection": 2, "trait": "youya_night_lord", "message": "「黑夜...是我们的领域。」"},
			},
		],
	},
	"hibiki": {
		"hero_id": "hibiki", "hero_name": "響",
		"steps": [
			{
				"id": "hibiki_cq1", "name": "響: 山岳守护者",
				"affection_required": 3,
				"desc": "響想确认你有建设的能力。",
				"objective": {"type": "buildings_min", "value": 3, "label": "建造3座建筑"},
				"reward": {"affection": 2, "message": "「你懂得建设...不错。」"},
			},
			{
				"id": "hibiki_cq2", "name": "響: 铁壁战斧",
				"affection_required": 5,
				"desc": "響需要你扩展领地来证明守护的价值。",
				"objective": {"type": "tiles_min", "value": 10, "label": "占领10个领地"},
				"reward": {"affection": 2, "equipment": "hibiki_iron_halberd", "message": "「这把战斧...是山的意志。」"},
			},
			{
				"id": "hibiki_cq3", "name": "響: 山岳之心",
				"affection_required": 8,
				"desc": "響将山岳之力赋予你的军团。",
				"objective": {"type": "battles_won_min", "value": 12, "label": "赢得12场战斗"},
				"reward": {"affection": 2, "trait": "hibiki_mountain", "message": "「山的力量...永远不会动摇。」"},
			},
		],
	},
	"sara": {
		"hero_id": "sara", "hero_name": "沙羅",
		"steps": [
			{
				"id": "sara_cq1", "name": "沙羅: 沙漠游侠",
				"affection_required": 3,
				"desc": "沙羅想确认你的战斗实力。",
				"objective": {"type": "battles_won_min", "value": 5, "label": "赢得5场战斗"},
				"reward": {"affection": 2, "message": "「在沙漠中...只有强者才能生存。」"},
			},
			{
				"id": "sara_cq2", "name": "沙羅: 砂尘弓",
				"affection_required": 5,
				"desc": "沙羅需要资金来修复她的传家之弓。",
				"objective": {"type": "gold_min", "value": 500, "label": "持有500金币"},
				"reward": {"affection": 2, "equipment": "sara_desert_bow", "message": "「这把弓...是沙漠的馈赠。」"},
			},
			{
				"id": "sara_cq3", "name": "沙羅: 蜃气楼",
				"affection_required": 8,
				"desc": "沙羅将沙漠的幻术赋予你的军团。",
				"objective": {"type": "tiles_min", "value": 15, "label": "占领15个领地"},
				"reward": {"affection": 2, "trait": "sara_mirage", "message": "「蜃气楼...将迷惑所有敌人。」"},
			},
		],
	},
	"mei": {
		"hero_id": "mei", "hero_name": "冥",
		"steps": [
			{
				"id": "mei_cq1", "name": "冥: 亡灵术士",
				"affection_required": 3,
				"desc": "冥想确认你在战场上的实力。",
				"objective": {"type": "battles_won_min", "value": 6, "label": "赢得6场战斗"},
				"reward": {"affection": 2, "message": "「死亡...也是一种力量。」"},
			},
			{
				"id": "mei_cq2", "name": "冥: 死灵秘典",
				"affection_required": 5,
				"desc": "冥需要你展现足够的威慑力。",
				"objective": {"type": "threat_min", "value": 40, "label": "威胁值达到40"},
				"reward": {"affection": 2, "equipment": "mei_necronomicon", "message": "「这本秘典...记载着生与死的秘密。」"},
			},
			{
				"id": "mei_cq3", "name": "冥: 冥府支配",
				"affection_required": 8,
				"desc": "冥将亡灵之力赋予你的军团。",
				"objective": {"type": "heroes_min", "value": 3, "label": "招募3名英雄"},
				"reward": {"affection": 2, "trait": "mei_undead_lord", "message": "「冥府的大门...已为你敞开。」"},
			},
		],
	},
	"kaede": {
		"hero_id": "kaede", "hero_name": "楓",
		"steps": [
			{
				"id": "kaede_cq1", "name": "楓: 隐秘忍者",
				"affection_required": 3,
				"desc": "楓想看到你的领地扩张能力。",
				"objective": {"type": "tiles_min", "value": 8, "label": "占领8个领地"},
				"reward": {"affection": 2, "message": "「你的行动...够迅速。」"},
			},
			{
				"id": "kaede_cq2", "name": "楓: 风魔手里剑",
				"affection_required": 5,
				"desc": "楓需要你在战场上证明实力。",
				"objective": {"type": "battles_won_min", "value": 10, "label": "赢得10场战斗"},
				"reward": {"affection": 2, "equipment": "kaede_wind_kunai", "message": "「这枚手里剑...快如疾风。」"},
			},
			{
				"id": "kaede_cq3", "name": "楓: 疾风迅雷",
				"affection_required": 8,
				"desc": "楓将疾风之力赋予你的军团。",
				"objective": {"type": "strongholds_min", "value": 2, "label": "攻占2座要塞"},
				"reward": {"affection": 2, "trait": "kaede_wind", "message": "「疾风...将扫清一切障碍。」"},
			},
		],
	},
	"akane": {
		"hero_id": "akane", "hero_name": "朱音",
		"steps": [
			{
				"id": "akane_cq1", "name": "朱音: 巫女治愈师",
				"affection_required": 3,
				"desc": "朱音想确认你是否懂得外交。",
				"objective": {"type": "neutral_recruited_min", "value": 1, "label": "招募1个中立势力"},
				"reward": {"affection": 2, "message": "「你的心中...有慈悲。」"},
			},
			{
				"id": "akane_cq2", "name": "朱音: 神乐铃",
				"affection_required": 5,
				"desc": "朱音需要资金来进行神乐铃的净化仪式。",
				"objective": {"type": "gold_min", "value": 600, "label": "持有600金币"},
				"reward": {"affection": 2, "equipment": "akane_sacred_bell", "message": "「神乐铃的音色...能净化一切邪恶。」"},
			},
			{
				"id": "akane_cq3", "name": "朱音: 净化之光",
				"affection_required": 8,
				"desc": "朱音以神乐之力守护你的全部领地。",
				"objective": {"type": "tiles_min", "value": 20, "label": "占领20个领地"},
				"reward": {"affection": 2, "trait": "akane_purify", "message": "「净化之光...将永远守护着你。」"},
			},
		],
	},
	"hanabi": {
		"hero_id": "hanabi", "hero_name": "花火",
		"steps": [
			{
				"id": "hanabi_cq1", "name": "花火: 爆破专家",
				"affection_required": 3,
				"desc": "花火想确认你的战斗实力。",
				"objective": {"type": "battles_won_min", "value": 5, "label": "赢得5场战斗"},
				"reward": {"affection": 2, "message": "「轰轰轰！不错嘛！」"},
			},
			{
				"id": "hanabi_cq2", "name": "花火: 超弩级炮",
				"affection_required": 5,
				"desc": "花火需要铁矿来建造她的超弩级炮。",
				"objective": {"type": "iron_min", "value": 200, "label": "持有200铁矿"},
				"reward": {"affection": 2, "equipment": "hanabi_mega_cannon", "message": "「看看这门大炮！花火大会开始了！」"},
			},
			{
				"id": "hanabi_cq3", "name": "花火: 花火大会",
				"affection_required": 8,
				"desc": "花火将爆破之力赋予你的攻城部队。",
				"objective": {"type": "strongholds_min", "value": 2, "label": "攻占2座要塞"},
				"reward": {"affection": 2, "trait": "hanabi_fireworks", "message": "「最华丽的烟花...只为你绽放！」"},
			},
		],
	},
}

# ═══════════════ CHARACTER QUEST EQUIPMENT ═══════════════
# Unique equipment rewarded by character quests

const CHARACTER_EQUIPMENT: Dictionary = {
	"rin_sacred_blade": {
		"name": "凛的圣剑·光断", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+4, 对光明阵营单位伤害+15%",
		"stats": {"atk": 4},
		"passive": "light_slayer", "passive_value": 0.15,
		"drop_weight": 0, "icon": "rin_sacred_blade",
	},
	"suirei_elf_bow": {
		"name": "翠玲的精灵弓·月影", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+3, SPD+3, 先手射击",
		"stats": {"atk": 3, "spd": 3},
		"passive": "preemptive_shot", "passive_value": 1.0,
		"drop_weight": 0, "icon": "suirei_elf_bow",
	},
	"sou_arcane_tome": {
		"name": "蒼的魔导书·星辰录", "slot": FactionData.EquipSlot.ACCESSORY, "rarity": "legendary",
		"desc": "INT+3, 全军法术伤害+25%",
		"stats": {"int_stat": 3},
		"passive": "spell_power_bonus", "passive_value": 0.25,
		"drop_weight": 0, "icon": "sou_arcane_tome",
	},
	"homura_flame_gauntlet": {
		"name": "焔的火焰手甲", "slot": FactionData.EquipSlot.ARMOR, "rarity": "legendary",
		"desc": "DEF+3, ATK+2, 反击伤害+30%",
		"stats": {"def": 3, "atk": 2},
		"passive": "counter_damage_bonus", "passive_value": 0.30,
		"drop_weight": 0, "icon": "homura_flame_gauntlet",
	},
	"yukino_holy_staff": {
		"name": "雪乃的圣杖·白夜", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "INT+4, 治愈量+30%",
		"stats": {"int_stat": 4},
		"passive": "heal_bonus", "passive_value": 0.30,
		"drop_weight": 0, "icon": "yukino_holy_staff",
	},
	"momiji_war_fan": {
		"name": "紅葉的军配扇·天下布武", "slot": FactionData.EquipSlot.ACCESSORY, "rarity": "legendary",
		"desc": "ATK+2, SPD+2, 全军先手骰+1",
		"stats": {"atk": 2, "spd": 2},
		"passive": "command_bonus", "passive_value": 1.0,
		"drop_weight": 0, "icon": "momiji_war_fan",
	},
	"hyouka_crystal_shield": {
		"name": "冰華的水晶盾·绝对零度", "slot": FactionData.EquipSlot.ARMOR, "rarity": "legendary",
		"desc": "DEF+6, 受伤减免20%",
		"stats": {"def": 6},
		"passive": "damage_reduce", "passive_value": 0.20,
		"drop_weight": 0, "icon": "hyouka_crystal_shield",
	},
	"gekka_moonstone": {
		"name": "月華的月光石·永夜之辉", "slot": FactionData.EquipSlot.ACCESSORY, "rarity": "legendary",
		"desc": "INT+3, DEF+2, 法力回复+2/回合",
		"stats": {"int_stat": 3, "def": 2},
		"passive": "mana_regen", "passive_value": 2,
		"drop_weight": 0, "icon": "gekka_moonstone",
	},
	"hakagure_shadow_blade": {
		"name": "葉隱的影刃·朧月", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+5, SPD+2, 暗杀后排必中",
		"stats": {"atk": 5, "spd": 2},
		"passive": "assassinate_back", "passive_value": 1.0,
		"drop_weight": 0, "icon": "hakagure_shadow_blade",
	},
	"shion_hourglass": {
		"name": "紫苑的时之砂漏·永劫", "slot": FactionData.EquipSlot.ACCESSORY, "rarity": "legendary",
		"desc": "INT+4, SPD+3, 敌方首回合SPD-3",
		"stats": {"int_stat": 4, "spd": 3},
		"passive": "time_slow", "passive_value": 3,
		"drop_weight": 0, "icon": "shion_hourglass",
	},
	"shion_pirate_crossbow": {
		"name": "潮音的连弩·怒涛", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+4, SPD+2, 每回合攻击2次(首轮)",
		"stats": {"atk": 4, "spd": 2},
		"passive": "double_shot", "passive_value": 1.0,
		"drop_weight": 0, "icon": "shion_pirate_crossbow",
	},
	"youya_venom_dagger": {
		"name": "妖夜的毒蛇匕首·夜叉", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+5, 击中附加毒(2回合DOT)",
		"stats": {"atk": 5},
		"passive": "poison_attack", "passive_value": 2,
		"drop_weight": 0, "icon": "youya_venom_dagger",
	},
	"hibiki_iron_halberd": {
		"name": "響的铁壁战斧·山的意志", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+3, DEF+4, 嘲讽(强制敌方攻击自己)",
		"stats": {"atk": 3, "def": 4},
		"passive": "taunt", "passive_value": 1.0,
		"drop_weight": 0, "icon": "hibiki_iron_halberd",
	},
	"sara_desert_bow": {
		"name": "沙羅的砂尘弓·蜃气楼", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+4, SPD+3, 沙漠地形ATK翻倍",
		"stats": {"atk": 4, "spd": 3},
		"passive": "desert_mastery", "passive_value": 2.0,
		"drop_weight": 0, "icon": "sara_desert_bow",
	},
	"mei_necronomicon": {
		"name": "冥的死灵秘典·冥府之书", "slot": FactionData.EquipSlot.ACCESSORY, "rarity": "legendary",
		"desc": "INT+5, 击杀回复2兵",
		"stats": {"int_stat": 5},
		"passive": "kill_heal_2", "passive_value": 2.0,
		"drop_weight": 0, "icon": "mei_necronomicon",
	},
	"kaede_wind_kunai": {
		"name": "楓的风魔手里剑·疾风", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+3, SPD+5, 先手攻击",
		"stats": {"atk": 3, "spd": 5},
		"passive": "preemptive_bonus", "passive_value": 0.20,
		"drop_weight": 0, "icon": "kaede_wind_kunai",
	},
	"akane_sacred_bell": {
		"name": "朱音的神乐铃·鎮魂", "slot": FactionData.EquipSlot.ACCESSORY, "rarity": "legendary",
		"desc": "INT+3, DEF+2, 每回合全军恢复1兵",
		"stats": {"int_stat": 3, "def": 2},
		"passive": "regen_aura", "passive_value": 1,
		"drop_weight": 0, "icon": "akane_sacred_bell",
	},
	"hanabi_mega_cannon": {
		"name": "花火的超弩级炮·花火大会", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+7, 攻城城防-10",
		"stats": {"atk": 7},
		"passive": "siege_bonus", "passive_value": 10,
		"drop_weight": 0, "icon": "hanabi_mega_cannon",
	},
}

# ═══════════════ CHARACTER QUEST TRAITS ═══════════════

const CHARACTER_TRAITS: Dictionary = {
	"rin_oath_bond": {
		"name": "凛的誓约", "desc": "凛在队伍中时全军DEF+2, 士气+10",
		"hero_id": "rin",
		"effect": {"conditional_hero": "rin", "global_def_bonus": 2, "morale_bonus": 10},
	},
	"suirei_moon_blessing": {
		"name": "月之祝福", "desc": "翠玲在队伍中时全军SPD+2, 夜战无惩罚",
		"hero_id": "suirei",
		"effect": {"conditional_hero": "suirei", "global_spd_bonus": 2, "night_immunity": true},
	},
	"sou_archmage_awakening": {
		"name": "大贤者觉醒", "desc": "蒼在队伍中时法术冷却-1, 法力+5",
		"hero_id": "sou",
		"effect": {"conditional_hero": "sou", "cooldown_reduction": 1, "mana_bonus": 5},
	},
	"homura_eternal_flame": {
		"name": "不灭之焰", "desc": "焔在队伍中时全军ATK+2, 火属性伤害+20%",
		"hero_id": "homura",
		"effect": {"conditional_hero": "homura", "global_atk_bonus": 2, "fire_damage_bonus": 0.20},
	},
	"yukino_sanctuary": {
		"name": "圣域守护", "desc": "雪乃在队伍中时每回合恢复1兵, 全军DEF+1",
		"hero_id": "yukino",
		"effect": {"conditional_hero": "yukino", "regen_per_turn": 1, "global_def_bonus": 1},
	},
	"momiji_general": {
		"name": "名将之风", "desc": "紅葉在队伍中时骑兵ATK+3, 全军士气+5",
		"hero_id": "momiji",
		"effect": {"conditional_hero": "momiji", "cavalry_atk_bonus": 3, "morale_bonus": 5},
	},
	"hyouka_bastion": {
		"name": "铁壁守护", "desc": "冰華在队伍中时所有据点城防+3",
		"hero_id": "hyouka",
		"effect": {"conditional_hero": "hyouka", "stronghold_def_bonus": 3},
	},
	"gekka_moonlight": {
		"name": "月光祝福", "desc": "月華在队伍中时全军INT+2, 夜战ATK+2",
		"hero_id": "gekka",
		"effect": {"conditional_hero": "gekka", "global_int_bonus": 2, "night_atk_bonus": 2},
	},
	"hakagure_phantom": {
		"name": "幻影", "desc": "葉隱在队伍中时首回合全军回避+30%",
		"hero_id": "hakagure",
		"effect": {"conditional_hero": "hakagure", "first_turn_evasion": 0.30},
	},
	"shion_time_lord": {
		"name": "时空支配", "desc": "紫苑在队伍中时全军技能冷却-1, 首回合全军SPD+2",
		"hero_id": "shion",
		"effect": {"conditional_hero": "shion", "cooldown_reduction": 1, "first_turn_spd_bonus": 2},
	},
	"shion_pirate_tides": {
		"name": "潮汐之力", "desc": "潮音在队伍中时沿海地形ATK+3, 掠夺金+20%",
		"hero_id": "shion_pirate",
		"effect": {"conditional_hero": "shion_pirate", "coastal_atk_bonus": 3, "plunder_gold_bonus": 0.20},
	},
	"youya_night_lord": {
		"name": "夜之支配者", "desc": "妖夜在队伍中时暗杀概率+20%, 暗影精华获取+1",
		"hero_id": "youya",
		"effect": {"conditional_hero": "youya", "assassinate_chance_bonus": 0.20, "shadow_essence_bonus": 1},
	},
	"hibiki_mountain": {
		"name": "山岳之心", "desc": "響在队伍中时山地地形DEF+4, 全军士气+10",
		"hero_id": "hibiki",
		"effect": {"conditional_hero": "hibiki", "mountain_def_bonus": 4, "morale_bonus": 10},
	},
	"sara_mirage": {
		"name": "蜃气楼", "desc": "沙羅在队伍中时远程单位SPD+2, 15%概率闪避攻击",
		"hero_id": "sara",
		"effect": {"conditional_hero": "sara", "ranged_spd_bonus": 2, "evasion_chance": 0.15},
	},
	"mei_undead_lord": {
		"name": "冥府支配", "desc": "冥在队伍中时击杀敌方有15%概率召唤骷髅兵+1",
		"hero_id": "mei",
		"effect": {"conditional_hero": "mei", "skeleton_summon_chance": 0.15, "skeleton_count": 1},
	},
	"kaede_wind": {
		"name": "疾风迅雷", "desc": "楓在队伍中时忍者单位SPD+3, 森林地形ATK+2",
		"hero_id": "kaede",
		"effect": {"conditional_hero": "kaede", "ninja_spd_bonus": 3, "forest_atk_bonus": 2},
	},
	"akane_purify": {
		"name": "净化之光", "desc": "朱音在队伍中时负面状态持续-1回合, 全军DEF+1",
		"hero_id": "akane",
		"effect": {"conditional_hero": "akane", "debuff_duration_reduction": 1, "global_def_bonus": 1},
	},
	"hanabi_fireworks": {
		"name": "花火大会", "desc": "花火在队伍中时攻城伤害+30%, 炮兵ATK+3",
		"hero_id": "hanabi",
		"effect": {"conditional_hero": "hanabi", "siege_damage_bonus": 0.30, "artillery_atk_bonus": 3},
	},
}
