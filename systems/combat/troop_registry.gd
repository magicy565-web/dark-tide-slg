## troop_registry.gd — Unified troop/unit definition registry for 暗潮 SLG (v2.4)
## Static data file (RefCounted). All troop definitions organized by category.
## Imported by GameData autoload; no circular dependencies.
##
## Categories:
##   FACTION      — 9 evil + 9 light faction troops (18 total)
##   NEUTRAL      — 13 neutral faction troops (1 T0 + 6 T2 + 6 T3)
##   ALLIANCE     — 2 alliance expedition troops
##   ULTIMATE     — 3 evil faction T4 troops
##   REBEL        — 2 rebel uprising troops
##   WANDERER     — 3 wandering band troops
##   HERO_BOUND   — 10 light hero exclusive troops (NEW)
class_name TroopRegistry
extends RefCounted

# ─── Mirror GameData enums as int constants (avoid circular preload) ────────
# TroopClass ordinals
const TC_ASHIGARU = 0
const TC_SAMURAI = 1
const TC_ARCHER = 2
const TC_CAVALRY = 3
const TC_NINJA = 4
const TC_PRIEST = 5
const TC_MAGE_UNIT = 6
const TC_CANNON = 7

# Row ordinals
const ROW_FRONT = 0
const ROW_BACK = 1

# TroopCategory ordinals (must match GameData.TroopCategory)
const CAT_FACTION = 0
const CAT_NEUTRAL = 1
const CAT_REBEL = 2
const CAT_WANDERER = 3
const CAT_ALLIANCE = 4
const CAT_ULTIMATE = 5
const CAT_HERO_BOUND = 6


# ═══════════════ PUBLIC API ═══════════════

static func get_all_troop_definitions() -> Dictionary:
	var defs: Dictionary = {}
	_register_evil_faction(defs)
	_register_light_faction(defs)
	_register_neutral(defs)
	_register_alliance(defs)
	_register_ultimate(defs)
	_register_rebel(defs)
	_register_wanderer(defs)
	_register_hero_bound(defs)
	return defs


# ═══════════════ EVIL FACTION TROOPS (9) ═══════════════

static func _register_evil_faction(d: Dictionary) -> void:
	# ── Orc 兽人部落 ──
	d["orc_ashigaru"] = {
		"name": "兽人足軽", "faction": "orc",
		"troop_class": TC_ASHIGARU, "row": ROW_FRONT,
		"base_atk": 6, "base_def": 3, "max_soldiers": 8, "hp_per_soldier": 5,
		"recruit_cost": 16, "passive": "horde_bonus", "category": CAT_FACTION,
		"tier": 1, "desc": "廉价蛮兵, 同军3+兽人时ATK+2",
	}
	d["orc_samurai"] = {
		"name": "巨魔", "faction": "orc",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 9, "base_def": 6, "max_soldiers": 7, "hp_per_soldier": 7,
		"recruit_cost": 27, "passive": "berserker_rage", "category": CAT_FACTION,
		"tier": 2, "desc": "狂暴化: <50%HP时ATK翻倍失DEF",
	}
	d["orc_cavalry"] = {
		"name": "战猪骑兵", "faction": "orc",
		"troop_class": TC_CAVALRY, "row": ROW_FRONT,
		"base_atk": 8, "base_def": 4, "max_soldiers": 5, "hp_per_soldier": 7,
		"recruit_cost": 40, "passive": "charge_stun", "category": CAT_FACTION,
		"tier": 3, "desc": "冲锋首击×1.5且30%眩晕, 需要战马",
		"strategic_cost": {"war_horse": 2},
	}
	# ── Pirate 暗夜海盗 ──
	d["pirate_ashigaru"] = {
		"name": "海盗散兵", "faction": "pirate",
		"troop_class": TC_ASHIGARU, "row": ROW_FRONT,
		"base_atk": 6, "base_def": 4, "max_soldiers": 7, "hp_per_soldier": 5,
		"recruit_cost": 16, "passive": "pistol_shot", "category": CAT_FACTION,
		"tier": 1, "desc": "手枪散兵, 前排可攻击后排",
	}
	d["pirate_archer"] = {
		"name": "火枪手", "faction": "pirate",
		"troop_class": TC_ARCHER, "row": ROW_BACK,
		"base_atk": 7, "base_def": 3, "max_soldiers": 6, "hp_per_soldier": 5,
		"recruit_cost": 14, "passive": "reload_shot", "category": CAT_FACTION,
		"tier": 2, "desc": "先手齐射后需1回合装填",
	}
	d["pirate_cannon"] = {
		"name": "炮击手", "faction": "pirate",
		"troop_class": TC_CANNON, "row": ROW_BACK,
		"base_atk": 10, "base_def": 2, "max_soldiers": 4, "hp_per_soldier": 5,
		"recruit_cost": 40, "passive": "aoe_immobile", "category": CAT_FACTION,
		"tier": 3, "desc": "定点AoE炮击+攻城×2+不可移动, 需要火药",
		"strategic_cost": {"gunpowder": 2},
	}
	# ── Dark Elf 暗精灵议会 ──
	d["de_samurai"] = {
		"name": "暗精灵战士", "faction": "dark_elf",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 7, "base_def": 5, "max_soldiers": 5, "hp_per_soldier": 6,
		"recruit_cost": 22, "passive": "counter_defend", "category": CAT_FACTION,
		"tier": 1, "desc": "防御反击×1.2+防守时DEF+2",
	}
	d["de_ninja"] = {
		"name": "暗影刺客", "faction": "dark_elf",
		"troop_class": TC_NINJA, "row": ROW_BACK,
		"base_atk": 9, "base_def": 2, "max_soldiers": 5, "hp_per_soldier": 4,
		"recruit_cost": 25, "passive": "assassin_crit", "category": CAT_FACTION,
		"tier": 2, "desc": "无视嘲讽攻后排+30%暴击×2",
	}
	d["de_cavalry"] = {
		"name": "冷蜥骑兵", "faction": "dark_elf",
		"troop_class": TC_CAVALRY, "row": ROW_FRONT,
		"base_atk": 8, "base_def": 6, "max_soldiers": 5, "hp_per_soldier": 7,
		"recruit_cost": 40, "passive": "poison_slow", "category": CAT_FACTION,
		"tier": 3, "desc": "命中附毒DoT+降SPD, 需要战马",
		"strategic_cost": {"war_horse": 2},
	}
	# ── New Elite Faction Troops (v5.0) ──
	d["orc_warg_rider"] = {
		"name": "座狼骑兵", "faction": "orc",
		"troop_class": TC_CAVALRY, "row": ROW_FRONT,
		"base_atk": 9, "base_def": 5, "max_soldiers": 5, "hp_per_soldier": 6,
		"recruit_cost": 45, "passive": "flanking_charge", "category": CAT_FACTION,
		"tier": 3, "desc": "高速侧翼冲锋, 无视前排嘲讽攻击后排, 需要战马",
		"strategic_cost": {"war_horse": 2},
	}
	d["pirate_bombard"] = {
		"name": "海盗轰炸手", "faction": "pirate",
		"troop_class": TC_CANNON, "row": ROW_BACK,
		"base_atk": 12, "base_def": 2, "max_soldiers": 4, "hp_per_soldier": 5,
		"recruit_cost": 48, "passive": "siege_bombard", "category": CAT_FACTION,
		"tier": 3, "desc": "高爆轰炸, 攻城×3+AoE溅射, 需要火药",
		"strategic_cost": {"gunpowder": 3},
	}
	d["de_shadow_guard"] = {
		"name": "暗影禁卫", "faction": "dark_elf",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 7, "base_def": 7, "max_soldiers": 5, "hp_per_soldier": 7,
		"recruit_cost": 42, "passive": "shadow_stealth", "category": CAT_FACTION,
		"tier": 3, "desc": "首回合隐身+反击×1.5, 攻守均衡的精锐",
	}

# ═══════════════ LIGHT FACTION TROOPS (9) ═══════════════

static func _register_light_faction(d: Dictionary) -> void:
	# ── Human 人类王国 ──
	d["human_ashigaru"] = {
		"name": "民兵", "faction": "human",
		"troop_class": TC_ASHIGARU, "row": ROW_FRONT,
		"base_atk": 4, "base_def": 6, "max_soldiers": 8, "hp_per_soldier": 5,
		"recruit_cost": 16, "passive": "fort_def_3", "category": CAT_FACTION,
		"tier": 1, "desc": "据点内DEF+3",
	}
	d["human_cavalry"] = {
		"name": "骑士", "faction": "human",
		"troop_class": TC_CAVALRY, "row": ROW_FRONT,
		"base_atk": 7, "base_def": 7, "max_soldiers": 6, "hp_per_soldier": 6,
		"recruit_cost": 28, "passive": "counter_1_2", "category": CAT_FACTION,
		"tier": 2, "desc": "被攻击时反击×1.2",
	}
	d["human_samurai"] = {
		"name": "圣殿女卫", "faction": "human",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 6, "base_def": 9, "max_soldiers": 10, "hp_per_soldier": 9,
		"recruit_cost": 30, "passive": "immobile", "category": CAT_FACTION,
		"tier": 3, "desc": "不可移动但超高DEF",
	}
	# ── High Elf 高等精灵 ──
	d["elf_archer"] = {
		"name": "精灵游侠", "faction": "high_elf",
		"troop_class": TC_ARCHER, "row": ROW_BACK,
		"base_atk": 7, "base_def": 3, "max_soldiers": 5, "hp_per_soldier": 4,
		"recruit_cost": 14, "passive": "preemptive_1_3", "category": CAT_FACTION,
		"tier": 1, "desc": "先制攻击×1.3",
	}
	d["elf_mage"] = {
		"name": "法师", "faction": "high_elf",
		"troop_class": TC_MAGE_UNIT, "row": ROW_BACK,
		"base_atk": 8, "base_def": 2, "max_soldiers": 4, "hp_per_soldier": 4,
		"recruit_cost": 20, "passive": "aoe_mana", "category": CAT_FACTION,
		"tier": 2, "desc": "AoE攻击, 消耗5法力",
	}
	# v3.0 rebalance: soldiers 15→12, cost 30→34 (raw 210→168, eff ×1.25→210→168)
	# Old: 15 soldiers + DEF 10 + taunt = EHP ~30, nearly impenetrable wall
	# v3.5: soldiers 12→9 (raw_power 168→126, within T3 budget 60-160)
	d["elf_ashigaru"] = {
		"name": "树人", "faction": "high_elf",
		"troop_class": TC_ASHIGARU, "row": ROW_FRONT,
		"base_atk": 4, "base_def": 10, "max_soldiers": 9, "hp_per_soldier": 8,
		"recruit_cost": 34, "passive": "taunt", "category": CAT_FACTION,
		"tier": 3, "desc": "守护嘲讽, 强制吸引攻击",
	}
	# ── Mage 法师公会 ──
	d["mage_apprentice"] = {
		"name": "学徒法师", "faction": "mage",
		"troop_class": TC_MAGE_UNIT, "row": ROW_BACK,
		"base_atk": 4, "base_def": 3, "max_soldiers": 4, "hp_per_soldier": 3,
		"recruit_cost": 16, "passive": "charge_mana_1", "category": CAT_FACTION,
		"tier": 1, "desc": "每回合+1法力",
	}
	d["mage_battle"] = {
		"name": "战斗法师", "faction": "mage",
		"troop_class": TC_MAGE_UNIT, "row": ROW_BACK,
		"base_atk": 9, "base_def": 3, "max_soldiers": 5, "hp_per_soldier": 4,
		"recruit_cost": 25, "passive": "aoe_1_5_cost5", "category": CAT_FACTION,
		"tier": 2, "desc": "AoE×1.5, 消耗5法力, 高攻低防的玻璃炮",
	}
	d["mage_grand"] = {
		"name": "大法师", "faction": "mage",
		"troop_class": TC_MAGE_UNIT, "row": ROW_BACK,
		"base_atk": 10, "base_def": 5, "max_soldiers": 8, "hp_per_soldier": 5,
		"recruit_cost": 36, "passive": "death_burst", "category": CAT_FACTION,
		"tier": 3, "desc": "死亡时对敌全体ATK×2伤害, 高攻中低防",
	}

# ═══════════════ NEUTRAL TROOPS (13) ═══════════════

static func _register_neutral(d: Dictionary) -> void:
	# ── T0 Dark Elf Slave fodder (faction passive: 奴隶先锋) ──
	d["slave_fodder"] = {
		"name": "奴隶肉盾", "faction": "dark_elf",
		"troop_class": TC_ASHIGARU, "row": ROW_FRONT,
		"base_atk": 1, "base_def": 1, "max_soldiers": 4, "hp_per_soldier": 3,
		"recruit_cost": 0, "passive": "slave_fodder", "category": CAT_FACTION,
		"tier": 0, "desc": "0费消耗品, 吸收首轮伤害后溃散",
	}
	# ── 6 neutral factions: T2 base troops (taming >= 5) ──
	d["neutral_dwarf_guard"] = {
		"name": "矮人铁卫", "faction": "neutral_dwarf",
		"troop_class": TC_ASHIGARU, "row": ROW_FRONT,
		"base_atk": 5, "base_def": 12, "max_soldiers": 6, "hp_per_soldier": 8,
		"recruit_cost": 25, "passive": "immovable", "category": CAT_NEUTRAL,
		"tier": 2, "desc": "全游戏最高DEF, 不可被强制移至后排",
	}
	d["neutral_skeleton"] = {
		"name": "骷髅军团", "faction": "neutral_necro",
		"troop_class": TC_ASHIGARU, "row": ROW_FRONT,
		"base_atk": 6, "base_def": 4, "max_soldiers": 8, "hp_per_soldier": 3,
		"recruit_cost": 15, "passive": "zero_food", "category": CAT_NEUTRAL,
		"tier": 2, "desc": "0粮耗, -1兵/回合, 胜利+2兵, 永不溃逃",
	}
	d["neutral_green_archer"] = {
		"name": "绿影射手", "faction": "neutral_ranger",
		"troop_class": TC_ARCHER, "row": ROW_BACK,
		"base_atk": 8, "base_def": 3, "max_soldiers": 5, "hp_per_soldier": 4,
		"recruit_cost": 20, "passive": "forest_stealth", "category": CAT_NEUTRAL,
		"tier": 2, "desc": "首回合隐身, 森林地形双倍攻击",
	}
	# v3.0 rebalance: ATK 14→11, soldiers 6→5 (raw 90→60, eff ×1.45→87)
	# Old: (14+1)×6=90 → ×3 at <30% = ATK 42, one-shots everything
	# New: (11+1)×5=60 → ×3 at <30% = ATK 33, still strong but survivable
	d["neutral_blood_berserker"] = {
		"name": "血月狂战士", "faction": "neutral_blood",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 11, "base_def": 1, "max_soldiers": 5, "hp_per_soldier": 5,
		"recruit_cost": 22, "passive": "blood_triple", "category": CAT_NEUTRAL,
		"tier": 2, "desc": "<30%HP时ATK×3, 不可撤退, 极端攻击型",
	}
	# v3.0 rebalance: ATK 16→12, cost 18→24 (raw 48→36, eff ×0.85→30.6)
	# Old: ATK 16 at T2 exceeded T4 Orc Ultimate (16). Misfire 15% didn't compensate.
	# New: ATK 12 + 20% misfire. Still unique niche (siege×3) without overshadowing T3+.
	d["neutral_goblin_cannon"] = {
		"name": "地精炮兵", "faction": "neutral_goblin",
		"troop_class": TC_CANNON, "row": ROW_BACK,
		"base_atk": 12, "base_def": 0, "max_soldiers": 3, "hp_per_soldier": 3,
		"recruit_cost": 24, "passive": "misfire", "category": CAT_NEUTRAL,
		"tier": 2, "desc": "城防×3, 20%概率自伤, 高风险高回报",
	}
	d["neutral_caravan_guard"] = {
		"name": "商队护卫", "faction": "neutral_caravan",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 6, "base_def": 6, "max_soldiers": 5, "hp_per_soldier": 6,
		"recruit_cost": 20, "passive": "gold_on_hit", "category": CAT_NEUTRAL,
		"tier": 2, "desc": "均衡型, 每次攻击+2金",
	}
	# ── New Neutral Elite Troop (v5.0) ──
	d["mercenary_veteran"] = {
		"name": "佣兵老兵", "faction": "neutral_merc",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 7, "base_def": 6, "max_soldiers": 6, "hp_per_soldier": 6,
		"recruit_cost": 35, "passive": "veteran_resolve", "category": CAT_NEUTRAL,
		"tier": 2, "desc": "全属性高于同级, 招募费用昂贵, 永不溃逃",
	}
	# ── 6 neutral factions: T3 advanced troops (taming >= 7) ──
	d["neutral_dwarf_cannon"] = {
		"name": "矮人攻城炮", "faction": "neutral_dwarf",
		"troop_class": TC_CANNON, "row": ROW_BACK,
		"base_atk": 10, "base_def": 5, "max_soldiers": 4, "hp_per_soldier": 5,
		"recruit_cost": 40, "passive": "dwarf_siege_t3", "category": CAT_NEUTRAL,
		"tier": 3, "desc": "城防×3+AoE, 极慢但极强攻城",
	}
	d["neutral_necromancer"] = {
		"name": "死灵法师", "faction": "neutral_necro",
		"troop_class": TC_MAGE_UNIT, "row": ROW_BACK,
		"base_atk": 7, "base_def": 3, "max_soldiers": 3, "hp_per_soldier": 4,
		"recruit_cost": 35, "passive": "necro_summon", "category": CAT_NEUTRAL,
		"tier": 3, "desc": "每回合召唤1骷髅小队, 法力吸取",
	}
	d["neutral_treant"] = {
		"name": "树人守卫", "faction": "neutral_ranger",
		"troop_class": TC_ASHIGARU, "row": ROW_FRONT,
		"base_atk": 5, "base_def": 10, "max_soldiers": 9, "hp_per_soldier": 10,
		"recruit_cost": 38, "passive": "regen_2", "category": CAT_NEUTRAL,
		"tier": 3, "desc": "巨量HP+每回合回复2兵, 根缚定身敌人",
	}
	d["neutral_blood_shaman"] = {
		"name": "血月萨满", "faction": "neutral_blood",
		"troop_class": TC_PRIEST, "row": ROW_BACK,
		"base_atk": 4, "base_def": 4, "max_soldiers": 4, "hp_per_soldier": 5,
		"recruit_cost": 30, "passive": "blood_ritual", "category": CAT_NEUTRAL,
		"tier": 3, "desc": "血祭(牺牲2兵治愈全军)+战吼(全军ATK+2, 3回合)",
	}
	d["neutral_goblin_mech"] = {
		"name": "地精机甲", "faction": "neutral_goblin",
		"troop_class": TC_CAVALRY, "row": ROW_FRONT,
		"base_atk": 12, "base_def": 8, "max_soldiers": 3, "hp_per_soldier": 8,
		"recruit_cost": 45, "passive": "overload", "category": CAT_NEUTRAL,
		"tier": 3, "desc": "重甲DEF+5+蒸汽炮远程, 3次攻击后自爆",
	}
	d["neutral_merc_captain"] = {
		"name": "佣兵团长", "faction": "neutral_caravan",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 8, "base_def": 7, "max_soldiers": 5, "hp_per_soldier": 7,
		"recruit_cost": 40, "passive": "leadership", "category": CAT_NEUTRAL,
		"tier": 3, "desc": "统帅(邻近ATK+2)+战中可招募1随机佣兵",
	}

# ═══════════════ ALLIANCE TROOPS (2) ═══════════════

static func _register_alliance(d: Dictionary) -> void:
	d["alliance_vanguard"] = {
		"name": "联军先锋", "faction": "alliance",
		"troop_class": TC_CAVALRY, "row": ROW_FRONT,
		"base_atk": 8, "base_def": 6, "max_soldiers": 7, "hp_per_soldier": 6,
		"recruit_cost": 0, "passive": "preemptive", "category": CAT_ALLIANCE,
		"tier": 0, "desc": "骑士+游侠混编, 先手+反击",
	}
	d["alliance_arcane_battery"] = {
		"name": "奥术炮台", "faction": "alliance",
		"troop_class": TC_MAGE_UNIT, "row": ROW_BACK,
		"base_atk": 10, "base_def": 3, "max_soldiers": 6, "hp_per_soldier": 4,
		"recruit_cost": 0, "passive": "aoe_1_5_cost5", "category": CAT_ALLIANCE,
		"tier": 0, "desc": "法师集群, AoE×1.5+法力爆发",
	}

# ═══════════════ ULTIMATE TROOPS (3) ═══════════════

static func _register_ultimate(d: Dictionary) -> void:
	d["orc_ultimate"] = {
		"name": "蛮牛酋长", "faction": "orc",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 16, "base_def": 8, "max_soldiers": 1, "hp_per_soldier": 30,
		"recruit_cost": 120, "passive": "waaagh_triple", "category": CAT_ULTIMATE,
		"tier": 4, "desc": "WAAAGH!光环(+15/回合), 战吼(首回合DEF+3)",
		"strategic_cost": {"shadow_essence": 8},
	}
	d["pirate_ultimate"] = {
		"name": "海盗船长", "faction": "pirate",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 11, "base_def": 4, "max_soldiers": 1, "hp_per_soldier": 25,
		"recruit_cost": 100, "passive": "siege_ignore", "category": CAT_ULTIMATE,
		"tier": 4, "desc": "掠夺光环(+50%金币), 激励射击",
		"strategic_cost": {"shadow_essence": 8},
	}
	d["de_ultimate"] = {
		"name": "暗影女王", "faction": "dark_elf",
		"troop_class": TC_MAGE_UNIT, "row": ROW_BACK,
		"base_atk": 8, "base_def": 4, "max_soldiers": 1, "hp_per_soldier": 20,
		"recruit_cost": 130, "passive": "shadow_flight", "category": CAT_ULTIMATE,
		"tier": 4, "desc": "暗影光环(全体隐匿1回合), 支配",
		"strategic_cost": {"shadow_essence": 8},
	}

# ═══════════════ REBEL TROOPS (2) ═══════════════

static func _register_rebel(d: Dictionary) -> void:
	d["rebel_militia"] = {
		"name": "叛军民兵", "faction": "rebel",
		"troop_class": TC_ASHIGARU, "row": ROW_FRONT,
		"base_atk": 4, "base_def": 4, "max_soldiers": 6, "hp_per_soldier": 4,
		"recruit_cost": 0, "passive": "desperate", "category": CAT_REBEL,
		"tier": 0, "desc": "低秩序叛乱产生, 被围时ATK+2",
	}
	d["rebel_archer"] = {
		"name": "叛军弓手", "faction": "rebel",
		"troop_class": TC_ARCHER, "row": ROW_BACK,
		"base_atk": 5, "base_def": 2, "max_soldiers": 4, "hp_per_soldier": 3,
		"recruit_cost": 0, "passive": "scatter", "category": CAT_REBEL,
		"tier": 0, "desc": "兵力<30%自动溃散",
	}

# ═══════════════ WANDERER TROOPS (3) ═══════════════

static func _register_wanderer(d: Dictionary) -> void:
	d["wanderer_deserter"] = {
		"name": "逃兵", "faction": "wanderer",
		"troop_class": TC_ASHIGARU, "row": ROW_FRONT,
		"base_atk": 3, "base_def": 3, "max_soldiers": 5, "hp_per_soldier": 3,
		"recruit_cost": 0, "passive": "scatter", "category": CAT_WANDERER,
		"tier": 0, "desc": "战场逃兵聚集, 兵力低时溃散",
	}
	d["wanderer_bandit"] = {
		"name": "山贼", "faction": "wanderer",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 6, "base_def": 3, "max_soldiers": 4, "hp_per_soldier": 4,
		"recruit_cost": 0, "passive": "pillage", "category": CAT_WANDERER,
		"tier": 0, "desc": "劫掠者, 胜利后+10金",
	}
	d["wanderer_refugee"] = {
		"name": "流民军团", "faction": "wanderer",
		"troop_class": TC_ASHIGARU, "row": ROW_FRONT,
		"base_atk": 2, "base_def": 2, "max_soldiers": 10, "hp_per_soldier": 2,
		"recruit_cost": 0, "passive": "conscript", "category": CAT_WANDERER,
		"tier": 0, "desc": "流民聚集, 经过友方据点时+1兵, 人多势众",
	}

# ═══════════════ HERO-BOUND EXCLUSIVE TROOPS (10) ═══════════════
## 正义方角色绑定专属兵种 — Each light faction hero has a unique regiment.
## Only recruitable when the bound hero is in the player's army.
## Power budget: above faction T3 (power 48-70), below T4 ultimate (single + aura).
## Target total power (ATK+DEF)*soldiers: 75-110, recruit_cost: 45-60.
## hero_bound field links to the hero_id in FactionData.HEROES.

static func _register_hero_bound(d: Dictionary) -> void:
	# ── Human Kingdom Heroes ──

	# 凛 (rin) — 圣剑骑士, samurai → 凛的誓约骑士团
	# 定位: 攻守均衡前排精锐, (9+9)*6=108
	d["hero_rin_knights"] = {
		"name": "誓约骑士团", "faction": "human",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 9, "base_def": 9, "max_soldiers": 6, "hp_per_soldier": 8,
		"recruit_cost": 50, "passive": "oath_guard", "category": CAT_HERO_BOUND,
		"tier": 3, "desc": "凛专属: 凛存活时全队DEF+2, 反击×1.3",
		"hero_bound": "rin",
	}

	# 雪乃 (yukino) — 治愈祭司, priest → 雪乃的白百合巫女团
	# 定位: 治疗辅助, 战力不高但被动极强, (4+6)*5=50 (辅助型允许偏低)
	d["hero_yukino_maidens"] = {
		"name": "白百合巫女团", "faction": "human",
		"troop_class": TC_PRIEST, "row": ROW_BACK,
		"base_atk": 4, "base_def": 6, "max_soldiers": 5, "hp_per_soldier": 5,
		"recruit_cost": 45, "passive": "divine_heal", "category": CAT_HERO_BOUND,
		"tier": 3, "desc": "雪乃专属: 每回合治愈全军最伤部队2兵, 净化减益",
		"hero_bound": "yukino",
	}

	# 红叶 (momiji) — 指挥官, cavalry → 红叶的枫骑兵
	# 定位: 高机动冲锋骑兵, (9+7)*5=80
	d["hero_momiji_cavalry"] = {
		"name": "枫骑兵团", "faction": "human",
		"troop_class": TC_CAVALRY, "row": ROW_FRONT,
		"base_atk": 9, "base_def": 7, "max_soldiers": 5, "hp_per_soldier": 7,
		"recruit_cost": 50, "passive": "command_charge", "category": CAT_HERO_BOUND,
		"tier": 3, "desc": "红叶专属: 冲锋首击×1.8, 全军SPD+1",
		"hero_bound": "momiji",
		"strategic_cost": {"war_horse": 1},
	}

	# 冰华 (hyouka) — 圣殿守护, samurai → 冰华的圣殿卫士
	# 定位: 极致肉盾坦克, (6+12)*7=126 (高DEF低ATK, 需要嘲讽吸伤)
	d["hero_hyouka_templars"] = {
		"name": "圣殿卫士", "faction": "human",
		"troop_class": TC_SAMURAI, "row": ROW_FRONT,
		"base_atk": 6, "base_def": 12, "max_soldiers": 7, "hp_per_soldier": 10,
		"recruit_cost": 48, "passive": "holy_bulwark", "category": CAT_HERO_BOUND,
		"tier": 3, "desc": "冰华专属: 嘲讽+受伤-30%, 据点时DEF再+4",
		"hero_bound": "hyouka",
	}

	# ── High Elf Heroes ──

	# 翠玲 (suirei) — 精灵射手, archer → 翠玲的月光射手
	# 定位: 高攻精准射手, (10+4)*5=70 (被动先制×1.5拉高实际输出)
	d["hero_suirei_archers"] = {
		"name": "月光射手队", "faction": "high_elf",
		"troop_class": TC_ARCHER, "row": ROW_BACK,
		"base_atk": 10, "base_def": 4, "max_soldiers": 5, "hp_per_soldier": 5,
		"recruit_cost": 48, "passive": "moonlight_volley", "category": CAT_HERO_BOUND,
		"tier": 3, "desc": "翠玲专属: 先制×1.5, 夜间战斗ATK+3",
		"hero_bound": "suirei",
	}

	# 月华 (gekka) — 月神巫女, priest → 月华的月神侍从
	# 定位: 法力辅助+护盾, (6+5)*5=55 (辅助型, 法力回复是核心价值)
	d["hero_gekka_acolytes"] = {
		"name": "月神侍从团", "faction": "high_elf",
		"troop_class": TC_PRIEST, "row": ROW_BACK,
		"base_atk": 6, "base_def": 5, "max_soldiers": 5, "hp_per_soldier": 5,
		"recruit_cost": 45, "passive": "lunar_ward", "category": CAT_HERO_BOUND,
		"tier": 3, "desc": "月华专属: 法力护盾(吸收首次伤害40%), +2法力/回合",
		"hero_bound": "gekka",
	}

	# 叶隐 (hakagure) — 影忍, ninja → 叶隐的暗叶忍众
	# 定位: 极致暗杀, 脆皮高爆发, (10+3)*4=52 (暴击40%×2.5弥补纸面战力)
	d["hero_hakagure_shinobi"] = {
		"name": "暗叶忍众", "faction": "high_elf",
		"troop_class": TC_NINJA, "row": ROW_BACK,
		"base_atk": 10, "base_def": 3, "max_soldiers": 4, "hp_per_soldier": 4,
		"recruit_cost": 48, "passive": "shadow_assault", "category": CAT_HERO_BOUND,
		"tier": 3, "desc": "叶隐专属: 2回合隐身+暗杀后排, 暴击率40%×2.5",
		"hero_bound": "hakagure",
	}

	# ── Mage Tower Heroes ──

	# 蒼 (sou) — 大贤者, mage → 蒼的星辰弟子
	# 定位: 最强AoE法师, (12+5)*4=68 (AoE×2.0+法术+25%实际伤害远超纸面)
	d["hero_sou_disciples"] = {
		"name": "星辰弟子团", "faction": "mage",
		"troop_class": TC_MAGE_UNIT, "row": ROW_BACK,
		"base_atk": 12, "base_def": 5, "max_soldiers": 4, "hp_per_soldier": 4,
		"recruit_cost": 55, "passive": "arcane_overload", "category": CAT_HERO_BOUND,
		"tier": 3, "desc": "蒼专属: AoE×2.0+法术伤害+25%, 消耗8法力",
		"hero_bound": "sou",
		"strategic_cost": {"magic_crystal": 1},
	}

	# 紫苑 (shion) — 时空法师, mage → 紫苑的时空卫士
	# 定位: 控制型法师, (8+7)*4=60 (时停+额外行动的战术价值极高)
	d["hero_shion_chrono"] = {
		"name": "时空卫士团", "faction": "mage",
		"troop_class": TC_MAGE_UNIT, "row": ROW_BACK,
		"base_atk": 8, "base_def": 7, "max_soldiers": 4, "hp_per_soldier": 5,
		"recruit_cost": 52, "passive": "chrono_shift", "category": CAT_HERO_BOUND,
		"tier": 3, "desc": "紫苑专属: 每2回合令1敌跳过行动, 全军额外行动概率20%",
		"hero_bound": "shion",
		"strategic_cost": {"magic_crystal": 1},
	}

	# 焔 (homura) — 火焰法师, mage → 焔的炎舞军团
	# 定位: 爆发AoE+持续DoT, (13+3)*4=64 (灼烧DoT叠加后伤害极高)
	d["hero_homura_flame"] = {
		"name": "炎舞军团", "faction": "mage",
		"troop_class": TC_MAGE_UNIT, "row": ROW_BACK,
		"base_atk": 13, "base_def": 3, "max_soldiers": 4, "hp_per_soldier": 4,
		"recruit_cost": 50, "passive": "inferno_rain", "category": CAT_HERO_BOUND,
		"tier": 3, "desc": "焔专属: AoE火焰攻击, 附带2回合灼烧DoT(ATK×0.3/回合)",
		"hero_bound": "homura",
		"strategic_cost": {"magic_crystal": 1},
	}


# ═══════════════ HERO-BOUND PASSIVE DEFINITIONS ═══════════════
## Passives specific to hero-bound troops. Should be merged into
## GameData.PASSIVE_DEFS at registration time.

const HERO_BOUND_PASSIVES: Dictionary = {
	"oath_guard":      {"name": "誓约守护", "desc": "凛存活时全队DEF+2, 反击×1.3",
		"type": "conditional_stat", "hero_condition": "rin", "def_bonus": 2, "counter_mult": 1.3},
	"divine_heal":     {"name": "神圣治愈", "desc": "每回合治愈全军最伤部队2兵+净化减益",
		"type": "per_round", "heal_weakest": 2, "cleanse": true},
	"command_charge":  {"name": "指挥冲锋", "desc": "首击×1.8, 全军SPD+1",
		"type": "first_attack", "mult": 1.8, "global_spd": 1},
	"holy_bulwark":    {"name": "圣殿壁垒", "desc": "嘲讽+受伤-30%, 据点时DEF+4",
		"type": "targeting", "taunt": true, "damage_reduction": 0.3, "fort_def": 4},
	"moonlight_volley": {"name": "月光齐射", "desc": "先制×1.5, 夜间ATK+3",
		"type": "priority", "mult": 1.5, "night_atk_bonus": 3},
	"lunar_ward":      {"name": "月神结界", "desc": "法力护盾吸收首次伤害40%+2法力/回合",
		"type": "special", "shield_absorb": 0.4, "mana_regen": 2},
	"shadow_assault":  {"name": "暗影突袭", "desc": "2回合隐身+暗杀后排, 暴击40%×2.5",
		"type": "targeting", "stealth_duration": 2, "crit_chance": 0.4, "crit_mult": 2.5},
	"arcane_overload": {"name": "奥术超载", "desc": "AoE×2.0+法术伤害+25%, 消耗8法力",
		"type": "attack_mode", "mult": 2.0, "spell_bonus": 0.25, "mana_cost": 8},
	"chrono_shift":    {"name": "时空错位", "desc": "每2回合令1敌跳过行动, 20%额外行动",
		"type": "special", "stun_interval": 2, "extra_action_chance": 0.2},
	"inferno_rain":    {"name": "炎舞天降", "desc": "AoE火焰+灼烧DoT(ATK×0.3, 2回合)",
		"type": "attack_mode", "aoe": true, "dot_mult": 0.3, "dot_duration": 2},
}


# ═══════════════ HERO-BOUND ACTIVE ABILITIES ═══════════════
## Active abilities for hero-bound troops (once per battle).

const HERO_BOUND_ABILITIES: Dictionary = {
	"hero_rin_knights": {
		"name": "圣剑·光断", "desc": "全军DEF+4且免疫控制(2回合)",
		"target": "all_ally", "effect": {"def": 4, "cc_immune": true}, "duration": 2,
	},
	"hero_yukino_maidens": {
		"name": "白百合绽放", "desc": "全军回复3兵+解除所有减益",
		"target": "all_ally", "effect": {"heal_all": 3, "cleanse_all": true}, "duration": 0,
	},
	"hero_momiji_cavalry": {
		"name": "枫叶乱舞", "desc": "对敌前排造成ATK×2.5伤害+30%混乱",
		"target": "row_front_enemy", "effect": {"damage_mult": 2.5, "confuse_chance": 0.3}, "duration": 1,
	},
	"hero_hyouka_templars": {
		"name": "不动明王阵", "desc": "全军受伤-50%+反射20%伤害(1回合)",
		"target": "all_ally", "effect": {"damage_reduction": 0.5, "reflect": 0.2}, "duration": 1,
	},
	"hero_suirei_archers": {
		"name": "月影乱箭", "desc": "对全敌ATK×1.8伤害, 命中降SPD-3(2回合)",
		"target": "all_enemy", "effect": {"damage_mult": 1.8, "spd_debuff": -3}, "duration": 2,
	},
	"hero_gekka_acolytes": {
		"name": "月轮守护", "desc": "法力护盾: 吸收下一次60%伤害+全军+3法力",
		"target": "all_ally", "effect": {"shield_absorb": 0.6, "mana_gain": 3}, "duration": 0,
	},
	"hero_hakagure_shinobi": {
		"name": "影分身·千杀", "desc": "忽略防御攻击全后排(ATK×2), 无法被反击",
		"target": "row_back_enemy", "effect": {"damage_mult": 2.0, "ignore_def": true, "no_counter": true}, "duration": 0,
	},
	"hero_sou_disciples": {
		"name": "流星·终焉", "desc": "全敌ATK×3伤害, 消耗全部法力(最少10)",
		"target": "all_enemy", "effect": {"damage_mult": 3.0, "mana_cost_all": true, "min_mana": 10}, "duration": 0,
	},
	"hero_shion_chrono": {
		"name": "时间停止", "desc": "全敌无法行动1回合+己方全体额外行动1次",
		"target": "all", "effect": {"stun_all_enemy": true, "extra_action_ally": 1}, "duration": 1,
	},
	"hero_homura_flame": {
		"name": "业火·燎原", "desc": "全场AoE(ATK×2.5)+3回合灼烧DoT, 自身-2兵",
		"target": "all_enemy", "effect": {"damage_mult": 2.5, "dot_mult": 0.3, "dot_duration": 3, "self_damage": 2}, "duration": 0,
	},
}
