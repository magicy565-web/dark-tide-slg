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
}

# ═══════════════ CHARACTER QUEST EQUIPMENT ═══════════════
# Unique equipment rewarded by character quests

const CHARACTER_EQUIPMENT: Dictionary = {
	"rin_sacred_blade": {
		"name": "凛的圣剑·光断", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+4, 对光明阵营单位伤害+15%",
		"stats": {"atk": 4},
		"passive": "light_slayer", "passive_value": 0.15,
		"drop_weight": 0,
	},
	"suirei_elf_bow": {
		"name": "翠玲的精灵弓·月影", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+3, SPD+3, 先手射击",
		"stats": {"atk": 3, "spd": 3},
		"passive": "preemptive_shot", "passive_value": 1.0,
		"drop_weight": 0,
	},
	"sou_arcane_tome": {
		"name": "蒼的魔导书·星辰录", "slot": FactionData.EquipSlot.ACCESSORY, "rarity": "legendary",
		"desc": "INT+3, 全军法术伤害+25%",
		"stats": {"int_stat": 3},
		"passive": "spell_power_bonus", "passive_value": 0.25,
		"drop_weight": 0,
	},
	"homura_flame_gauntlet": {
		"name": "焔的火焰手甲", "slot": FactionData.EquipSlot.ARMOR, "rarity": "legendary",
		"desc": "DEF+3, ATK+2, 反击伤害+30%",
		"stats": {"def": 3, "atk": 2},
		"passive": "counter_damage_bonus", "passive_value": 0.30,
		"drop_weight": 0,
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
}
