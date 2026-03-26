## challenge_quest_data.gd — 挑战任务数据定义 (全战:战锤风格传奇领主任务)
## 每个阵营6阶段挑战，解锁传奇装备+被动特性+技能强化
extends RefCounted
class_name ChallengeQuestData

const FactionData = preload("res://systems/faction/faction_data.gd")

# ═══════════════ CHALLENGE LEGENDARY EQUIPMENT ═══════════════
# These items are ONLY obtainable through challenge quests. drop_weight = 0.

const CHALLENGE_EQUIPMENT: Dictionary = {
	# ── Orc Faction ──
	"orc_cleaver_of_gork": {
		"name": "哥克的碎骨斧", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+5, WAAAGH!获取+25%", "faction": "orc",
		"stats": {"atk": 5},
		"passive": "waaagh_gain_bonus", "passive_value": 0.25,
		"drop_weight": 0,
	},
	"orc_iron_jaw_plate": {
		"name": "铁牙重甲", "slot": FactionData.EquipSlot.ARMOR, "rarity": "legendary",
		"desc": "DEF+4, 受到致命伤害时保留1兵", "faction": "orc",
		"stats": {"def": 4},
		"passive": "death_resist", "passive_value": 1.0,
		"drop_weight": 0,
	},
	"orc_warboss_trophy": {
		"name": "战争首领的战利品", "slot": FactionData.EquipSlot.ACCESSORY, "rarity": "legendary",
		"desc": "全军ATK+2, 战胜后额外+5 WAAAGH!", "faction": "orc",
		"stats": {"atk": 2},
		"passive": "victory_waaagh_bonus", "passive_value": 5,
		"drop_weight": 0,
	},
	# ── Pirate Faction ──
	"pirate_sea_kings_cutlass": {
		"name": "海王的弯刀", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+4, SPD+2, 先手攻击概率+20%", "faction": "pirate",
		"stats": {"atk": 4, "spd": 2},
		"passive": "preemptive_bonus", "passive_value": 0.20,
		"drop_weight": 0,
	},
	"pirate_ghost_ship_coat": {
		"name": "幽灵船长外套", "slot": FactionData.EquipSlot.ARMOR, "rarity": "legendary",
		"desc": "DEF+3, 30%概率闪避远程攻击", "faction": "pirate",
		"stats": {"def": 3},
		"passive": "ranged_dodge", "passive_value": 0.30,
		"drop_weight": 0,
	},
	"pirate_treasure_compass": {
		"name": "传说中的罗盘", "slot": FactionData.EquipSlot.ACCESSORY, "rarity": "legendary",
		"desc": "战斗掠夺+50%, 每回合+3金币", "faction": "pirate",
		"stats": {},
		"passive": "plunder_gold_bonus", "passive_value": 0.50,
		"drop_weight": 0,
	},
	# ── Dark Elf Faction ──
	"de_shadow_fang": {
		"name": "暗影之牙", "slot": FactionData.EquipSlot.WEAPON, "rarity": "legendary",
		"desc": "ATK+4, INT+2, 暗杀后排概率+25%", "faction": "dark_elf",
		"stats": {"atk": 4, "int_stat": 2},
		"passive": "assassinate_bonus", "passive_value": 0.25,
		"drop_weight": 0,
	},
	"de_nightweave_robe": {
		"name": "夜织法袍", "slot": FactionData.EquipSlot.ARMOR, "rarity": "legendary",
		"desc": "DEF+3, 己方法术伤害+20%", "faction": "dark_elf",
		"stats": {"def": 3},
		"passive": "spell_damage_bonus", "passive_value": 0.20,
		"drop_weight": 0,
	},
	"de_soul_gem": {
		"name": "灵魂宝石", "slot": FactionData.EquipSlot.ACCESSORY, "rarity": "legendary",
		"desc": "俘获率+20%, 每次俘虏+2暗影精华", "faction": "dark_elf",
		"stats": {},
		"passive": "capture_essence_bonus", "passive_value": 0.20,
		"drop_weight": 0,
	},
}

# ═══════════════ CHALLENGE TRAIT UNLOCKS ═══════════════
# Passive traits granted to the player's lord (affect all armies).
# These are stored in ChallengeQuestManager, checked by combat system.

const CHALLENGE_TRAITS: Dictionary = {
	# ── Orc Traits ──
	"orc_trait_iron_will": {
		"name": "钢铁意志", "desc": "补给线衰减距离+2",
		"effect": {"supply_range_bonus": 2},
	},
	"orc_trait_warlord": {
		"name": "不败战神", "desc": "全军ATK+1, DEF+1 (永久)",
		"effect": {"global_atk_bonus": 1, "global_def_bonus": 1},
	},
	# ── Pirate Traits ──
	"pirate_trait_sea_legs": {
		"name": "老练航海", "desc": "强行军损耗降低至1%",
		"effect": {"forced_march_override": 0.01},
	},
	"pirate_trait_dread_captain": {
		"name": "恐惧船长", "desc": "全军SPD+1, 敌方士气-5",
		"effect": {"global_spd_bonus": 1, "enemy_morale_penalty": -5},
	},
	# ── Dark Elf Traits ──
	"de_trait_shadow_veil": {
		"name": "暗影面纱", "desc": "首回合全军隐匿(不可被选为目标)",
		"effect": {"first_turn_stealth": true},
	},
	"de_trait_dark_sovereign": {
		"name": "暗黑君主", "desc": "全军INT+2, 技能冷却-1回合",
		"effect": {"global_int_bonus": 2, "cooldown_reduction": 1},
	},
}

# ═══════════════ CHALLENGE QUEST CHAINS ═══════════════
# 6 challenges per faction, escalating difficulty.
# trigger: conditions to unlock the challenge
# task: UI description
# battle: optional boss fight data (null = no combat required)
# reward: what's granted on completion

const CHALLENGES: Dictionary = {
	FactionData.FactionID.ORC: [
		{
			"id": "orc_c1", "name": "初战之血",
			"desc": "证明你的实力 — 赢得你的第一场大规模战斗。",
			"trigger": {"battles_won_min": 3},
			"task": "赢得3场战斗",
			"battle": null,
			"reward": {"equipment": "orc_cleaver_of_gork"},
		},
		{
			"id": "orc_c2", "name": "扩张领地",
			"desc": "真正的战争首领需要广阔的领土。",
			"trigger": {"tiles_min": 10},
			"task": "占领至少10个领地",
			"battle": null,
			"reward": {"trait": "orc_trait_iron_will"},
		},
		{
			"id": "orc_c3", "name": "铁牙的考验",
			"desc": "击败铁牙部落的挑战者，证明你配得上铁牙重甲。",
			"trigger": {"tiles_min": 12, "turn_min": 8},
			"task": "击败铁牙挑战者 (战力35)",
			"battle": {"name": "铁牙挑战者", "strength": 35, "units": [
				{"type": "orc_samurai", "atk": 12, "def": 8, "spd": 4, "count": 20, "special": "regen_1"},
				{"type": "orc_cavalry", "atk": 10, "def": 6, "spd": 6, "count": 12, "special": "charge_1_5"},
			]},
			"reward": {"equipment": "orc_iron_jaw_plate"},
		},
		{
			"id": "orc_c4", "name": "WAAAGH!的共鸣",
			"desc": "在WAAAGH!狂暴状态下赢得一场战斗。",
			"trigger": {"waaagh_battle_win": true},
			"task": "在WAAAGH!狂暴中赢得战斗",
			"battle": null,
			"reward": {"equipment": "orc_warboss_trophy"},
		},
		{
			"id": "orc_c5", "name": "征服者的资格",
			"desc": "攻陷一座光明阵营要塞。",
			"trigger": {"strongholds_min": 1},
			"task": "攻占至少1座光明要塞",
			"battle": null,
			"reward": {"trait": "orc_trait_warlord"},
		},
		{
			"id": "orc_c6", "name": "最强战争首领",
			"desc": "击败传说中的巨兽统领，获得终极称号。",
			"trigger": {"tiles_min": 20, "turn_min": 20, "heroes_min": 3},
			"task": "击败巨兽统领 (战力60)",
			"battle": {"name": "巨兽统领·格鲁姆巴", "strength": 60, "units": [
				{"type": "orc_samurai", "atk": 14, "def": 10, "spd": 5, "count": 25, "special": "regen_1"},
				{"type": "orc_cavalry", "atk": 12, "def": 8, "spd": 7, "count": 15, "special": "charge_1_5"},
				{"type": "orc_ashigaru", "atk": 9, "def": 6, "spd": 4, "count": 30, "special": "taunt"},
			]},
			"reward": {"skill_upgrade": "orc_ultimate", "title": "至尊战争首领"},
		},
	],

	FactionData.FactionID.PIRATE: [
		{
			"id": "pirate_c1", "name": "首次掠夺",
			"desc": "劫掠是海盗的本能 — 积累你的第一桶金。",
			"trigger": {"gold_min": 800},
			"task": "累计拥有800金币",
			"battle": null,
			"reward": {"equipment": "pirate_sea_kings_cutlass"},
		},
		{
			"id": "pirate_c2", "name": "恐怖航路",
			"desc": "控制海上要道，建立你的势力范围。",
			"trigger": {"tiles_min": 8, "harbor_min": 1},
			"task": "占领8个领地且至少1个港口",
			"battle": null,
			"reward": {"trait": "pirate_trait_sea_legs"},
		},
		{
			"id": "pirate_c3", "name": "幽灵船的试炼",
			"desc": "传说中的幽灵船出现在你的航路上。击败它，获得船长的遗物。",
			"trigger": {"tiles_min": 10, "turn_min": 10},
			"task": "击败幽灵船 (战力30)",
			"battle": {"name": "幽灵船·冥河号", "strength": 30, "units": [
				{"type": "pirate_ashigaru", "atk": 8, "def": 6, "spd": 5, "count": 20, "special": "escape_30"},
				{"type": "pirate_archer", "atk": 10, "def": 4, "spd": 6, "count": 15, "special": "preemptive"},
			]},
			"reward": {"equipment": "pirate_ghost_ship_coat"},
		},
		{
			"id": "pirate_c4", "name": "黑市之王",
			"desc": "建立庞大的贸易网络。",
			"trigger": {"gold_min": 1500, "tiles_min": 15},
			"task": "拥有1500金币和15个领地",
			"battle": null,
			"reward": {"equipment": "pirate_treasure_compass"},
		},
		{
			"id": "pirate_c5", "name": "海上霸权",
			"desc": "让光明联盟感受到你的威胁。",
			"trigger": {"threat_min": 60, "strongholds_min": 1},
			"task": "威胁值达到60并攻占1座要塞",
			"battle": null,
			"reward": {"trait": "pirate_trait_dread_captain"},
		},
		{
			"id": "pirate_c6", "name": "七海之王",
			"desc": "击败传说中的深海巨兽，成为真正的海盗王。",
			"trigger": {"tiles_min": 20, "turn_min": 20, "heroes_min": 3},
			"task": "击败深海巨兽·利维坦 (战力55)",
			"battle": {"name": "深海利维坦", "strength": 55, "units": [
				{"type": "pirate_cannon", "atk": 14, "def": 5, "spd": 3, "count": 12, "special": "siege_x2"},
				{"type": "pirate_archer", "atk": 11, "def": 5, "spd": 7, "count": 20, "special": "preemptive"},
				{"type": "pirate_ashigaru", "atk": 9, "def": 8, "spd": 5, "count": 25, "special": "taunt"},
			]},
			"reward": {"skill_upgrade": "pirate_ultimate", "title": "七海霸王"},
		},
	],

	FactionData.FactionID.DARK_ELF: [
		{
			"id": "de_c1", "name": "暗影初步",
			"desc": "在暗处积蓄力量 — 收集暗影精华。",
			"trigger": {"shadow_essence_min": 15},
			"task": "积累15点暗影精华",
			"battle": null,
			"reward": {"equipment": "de_shadow_fang"},
		},
		{
			"id": "de_c2", "name": "情报网络",
			"desc": "用你的间谍网控制周围的区域。",
			"trigger": {"tiles_min": 10, "heroes_min": 2},
			"task": "占领10个领地并招募2名英雄",
			"battle": null,
			"reward": {"trait": "de_trait_shadow_veil"},
		},
		{
			"id": "de_c3", "name": "月下之战",
			"desc": "暗影守护者在月下等待你的挑战。",
			"trigger": {"tiles_min": 12, "turn_min": 10},
			"task": "击败暗影守护者 (战力35)",
			"battle": {"name": "暗影守护者·梦魇", "strength": 35, "units": [
				{"type": "de_ninja", "atk": 9, "def": 4, "spd": 8, "count": 15, "special": "assassinate_back"},
				{"type": "de_samurai", "atk": 10, "def": 7, "spd": 5, "count": 18, "special": "extra_action"},
			]},
			"reward": {"equipment": "de_nightweave_robe"},
		},
		{
			"id": "de_c4", "name": "灵魂收割",
			"desc": "通过俘虏和奴役收集足够的灵魂。",
			"trigger": {"heroes_captured_total": 3},
			"task": "累计俘获过3名英雄",
			"battle": null,
			"reward": {"equipment": "de_soul_gem"},
		},
		{
			"id": "de_c5", "name": "黑暗崛起",
			"desc": "让世界认识到黑暗精灵的力量。",
			"trigger": {"tiles_min": 18, "strongholds_min": 1},
			"task": "占领18个领地并攻占1座要塞",
			"battle": null,
			"reward": {"trait": "de_trait_dark_sovereign"},
		},
		{
			"id": "de_c6", "name": "暗黑君主的加冕",
			"desc": "击败远古暗影领主，继承暗黑王座。",
			"trigger": {"tiles_min": 20, "turn_min": 20, "heroes_min": 3},
			"task": "击败远古暗影领主 (战力60)",
			"battle": {"name": "远古暗影领主·奥尼克斯", "strength": 60, "units": [
				{"type": "de_samurai", "atk": 13, "def": 9, "spd": 6, "count": 20, "special": "extra_action"},
				{"type": "de_ninja", "atk": 11, "def": 5, "spd": 9, "count": 12, "special": "assassinate_back"},
				{"type": "de_cavalry", "atk": 12, "def": 8, "spd": 7, "count": 15, "special": "ignore_terrain"},
			]},
			"reward": {"skill_upgrade": "de_ultimate", "title": "暗影君王"},
		},
	],
}

# ═══════════════ SKILL UPGRADES (final challenge reward) ═══════════════
# These are added to HERO_SKILL_DEFS when unlocked, available to the faction leader.

const SKILL_UPGRADES: Dictionary = {
	"orc_ultimate": {
		"name": "灭世怒吼", "type": "aoe", "power": 80, "int_scale": 3.0,
		"target": "enemy", "desc": "WAAAGH!终极技能: 对全体敌军造成毁灭伤害并降低防御",
		"cooldown": 5, "buff_type": "def_mult", "debuff_value": -0.25, "duration": 2,
	},
	"pirate_ultimate": {
		"name": "深海审判", "type": "aoe", "power": 70, "int_scale": 4.0,
		"target": "enemy", "desc": "召唤深海之力冲击全体敌军, 25%概率立即歼灭",
		"cooldown": 5,
	},
	"de_ultimate": {
		"name": "暗影支配", "type": "debuff", "power": 0.40, "int_scale": 0.03,
		"target": "enemy", "buff_type": "atk_mult", "duration": 3,
		"desc": "控制敌军意志, 大幅削弱攻击力3回合",
		"cooldown": 5,
	},
}
