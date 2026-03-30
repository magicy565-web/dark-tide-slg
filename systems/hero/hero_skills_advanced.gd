## hero_skills_advanced.gd — Ultimate Skills, Combo Skills, and Awakening System
## Autoload singleton: HeroSkillsAdvanced
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")

# ---------------------------------------------------------------------------
# State (per-battle, reset each battle)
# ---------------------------------------------------------------------------
var _charge_counters: Dictionary = {}   # hero_id -> int (current charge rounds)
var _awakened_heroes: Dictionary = {}   # hero_id -> {rounds_left: int}
var _combo_charges: Dictionary = {}     # combo_index -> int (current charge rounds)

# ---------------------------------------------------------------------------
# A. Ultimate Skills (必杀技)
# ---------------------------------------------------------------------------

var ultimate_skills: Dictionary = {
	# --- Light Faction Heroes ---
	"rin": {name = "桜吹雪", charge_rounds = 4, mp_cost = 8,
			effect = "aoe_damage", damage_mult = 3.0, targets = "all_enemies",
			desc = "樱花暴风席卷全场，对所有敌方单位造成3倍ATK伤害"},
	"yukino": {name = "氷河世紀", charge_rounds = 5, mp_cost = 10,
			   effect = "aoe_damage_freeze", damage_mult = 2.5, targets = "all_enemies",
			   freeze_rounds = 2, desc = "冰封全场，2.5倍伤害并冻结2回合"},
	"momiji": {name = "紅蓮業火", charge_rounds = 3, mp_cost = 6,
			   effect = "line_damage", damage_mult = 4.0, targets = "column",
			   desc = "一列火焰贯穿，对一列敌人造成4倍伤害"},
	"hyouka": {name = "絶対零度", charge_rounds = 5, mp_cost = 9,
			   effect = "aoe_damage_freeze", damage_mult = 2.0, targets = "all_enemies",
			   freeze_rounds = 3, desc = "绝对零度冻结全场，2倍伤害冻结3回合"},
	"suirei": {name = "星矢乱舞", charge_rounds = 3, mp_cost = 7,
			   effect = "multi_hit", damage_mult = 1.8, hits = 4, targets = "random",
			   desc = "精灵箭雨4连射，每次1.8倍伤害随机目标"},
	"gekka": {name = "月影無双", charge_rounds = 4, mp_cost = 7,
			  effect = "multi_hit", damage_mult = 1.5, hits = 5, targets = "random",
			  desc = "月光斩击5次，每次1.5倍伤害随机目标"},
	"hakagure": {name = "影殺陣", charge_rounds = 3, mp_cost = 5,
				 effect = "execute", damage_mult = 5.0, targets = "all_enemies",
				 desc = "暗影处刑，对30%HP以下敌人直接斩杀，其余5倍伤害"},
	"sou": {name = "天崩地裂", charge_rounds = 5, mp_cost = 12,
			effect = "aoe_damage", damage_mult = 4.0, targets = "all_enemies",
			desc = "大贤者的终极魔法，对所有敌人造成4倍INT伤害"},
	"shion": {name = "時空断裂", charge_rounds = 4, mp_cost = 8,
			  effect = "aoe_damage_freeze", damage_mult = 2.0, targets = "all_enemies",
			  freeze_rounds = 2, desc = "撕裂时空，2倍伤害并使全体敌人冻结2回合"},
	"homura": {name = "煉獄炎舞", charge_rounds = 3, mp_cost = 7,
			   effect = "aoe_damage", damage_mult = 3.5, targets = "all_enemies",
			   desc = "炼狱之火吞噬全场，3.5倍ATK伤害"},
	# --- Neutral Heroes ---
	"hibiki": {name = "山崩地裂", charge_rounds = 5, mp_cost = 8,
			   effect = "aoe_damage", damage_mult = 2.5, targets = "all_enemies",
			   desc = "大地震动，对所有敌人造成2.5倍伤害"},
	"sara": {name = "砂塵嵐", charge_rounds = 4, mp_cost = 7,
			 effect = "line_damage", damage_mult = 3.5, targets = "column",
			 desc = "沙暴席卷一列，3.5倍伤害"},
	"mei": {name = "冥府召喚", charge_rounds = 5, mp_cost = 10,
			effect = "drain_damage", damage_mult = 3.0, targets = "all_enemies",
			desc = "冥界之力吸取全体敌人生命，伤害转化为治疗"},
	"kaede": {name = "千影分身", charge_rounds = 3, mp_cost = 6,
			  effect = "multi_hit", damage_mult = 2.0, hits = 6, targets = "random",
			  desc = "千影分身术，6次2倍伤害随机打击"},
	"akane": {name = "浄化の光", charge_rounds = 5, mp_cost = 10,
			  effect = "heal_all", damage_mult = 3.0, targets = "all_allies",
			  desc = "神圣净化之光，全体友军回复大量兵力"},
	"hanabi": {name = "花火連弾", charge_rounds = 4, mp_cost = 8,
			   effect = "aoe_damage", damage_mult = 3.5, targets = "all_enemies",
			   desc = "花火连弹轰炸全场，3.5倍ATK伤害"},
	# --- Evil Faction Heroes ---
	"shion_pirate": {name = "潮鳴砲撃", charge_rounds = 3, mp_cost = 6,
					 effect = "line_damage", damage_mult = 3.5, targets = "column",
					 desc = "海潮炮击贯穿一列，3.5倍伤害"},
	"youya": {name = "闇夜葬送", charge_rounds = 3, mp_cost = 5,
			  effect = "execute", damage_mult = 5.0, targets = "all_enemies",
			  desc = "暗夜处刑，30%HP以下直接斩杀"},
	"grok": {name = "蛮怒旋風", charge_rounds = 4, mp_cost = 6,
			 effect = "aoe_damage", damage_mult = 3.0, targets = "all_enemies",
			 desc = "兽人战吼引发旋风，3倍ATK伤害"},
	"shaman_zog": {name = "混沌雷暴", charge_rounds = 5, mp_cost = 10,
				   effect = "aoe_damage", damage_mult = 3.5, targets = "all_enemies",
				   desc = "混沌闪电暴风，3.5倍伤害全场"},
	"bonecrusher": {name = "骨碎天降", charge_rounds = 4, mp_cost = 7,
					effect = "single_damage", damage_mult = 8.0, targets = "strongest",
					desc = "跃起重砸最强敌人，8倍ATK单体伤害"},
	"wolf_rider": {name = "狼群襲來", charge_rounds = 3, mp_cost = 5,
				   effect = "multi_hit", damage_mult = 1.5, hits = 5, targets = "random",
				   desc = "狼群突袭5次，每次1.5倍伤害"},
	"siren": {name = "魅惑旋律", charge_rounds = 4, mp_cost = 9,
			  effect = "buff_all", damage_mult = 3.0, targets = "all_allies",
			  buff_rounds = 3, desc = "魅惑之歌，全体友军3回合增益"},
	"iron_hook": {name = "鉄鎖連環", charge_rounds = 4, mp_cost = 7,
				  effect = "aoe_damage", damage_mult = 3.0, targets = "all_enemies",
				  desc = "铁锁连环绞杀全场，3倍ATK伤害"},
	"storm_caller": {name = "大海嘯", charge_rounds = 5, mp_cost = 12,
					 effect = "aoe_damage", damage_mult = 4.0, targets = "all_enemies",
					 desc = "召唤大海啸席卷战场，4倍ATK伤害"},
	"shadow_blade": {name = "暗影乱舞", charge_rounds = 3, mp_cost = 5,
					 effect = "multi_hit", damage_mult = 2.0, hits = 4, targets = "random",
					 desc = "暗影分身乱舞，4次2倍伤害随机"},
	"venom_queen": {name = "劇毒蔓延", charge_rounds = 4, mp_cost = 8,
					effect = "aoe_damage", damage_mult = 2.5, targets = "all_enemies",
					desc = "剧毒蔓延全场，2.5倍伤害"},
	"dark_knight": {name = "闇黒突撃", charge_rounds = 4, mp_cost = 7,
					effect = "line_damage", damage_mult = 4.5, targets = "column",
					desc = "暗黑骑士突击贯穿一列，4.5倍伤害"},
	"spymaster": {name = "情報操作", charge_rounds = 3, mp_cost = 6,
				  effect = "buff_all", damage_mult = 2.0, targets = "all_allies",
				  buff_rounds = 3, desc = "情报操纵，全体友军3回合ATK/DEF提升"},
	"soul_binder": {name = "靈魂收割", charge_rounds = 5, mp_cost = 10,
					effect = "drain_damage", damage_mult = 3.0, targets = "all_enemies",
					desc = "灵魂收割，全体吸取伤害转化治疗"},
	# --- Hidden Heroes ---
	"dragon_slayer": {name = "屠龍断空斬", charge_rounds = 4, mp_cost = 8,
					  effect = "single_damage", damage_mult = 10.0, targets = "strongest",
					  desc = "屠龙者的终极斩击，10倍ATK单体伤害"},
	"saint_aria": {name = "聖域展開", charge_rounds = 5, mp_cost = 12,
				   effect = "heal_all", damage_mult = 4.0, targets = "all_allies",
				   desc = "圣域展开，全体友军大幅回复"},
	"master_smith": {name = "鉄鍛神撃", charge_rounds = 4, mp_cost = 7,
					 effect = "buff_all", damage_mult = 2.0, targets = "all_allies",
					 buff_rounds = 4, desc = "铁匠祝福，全军装备强化4回合"},
}

var combo_skills: Array = [
	{heroes = ["rin", "yukino"], name = "桜雪双舞",
	 charge_rounds = 6, mp_cost = 12, effect = "aoe_damage",
	 damage_mult = 4.0, targets = "all_enemies",
	 desc = "樱与雪的双重共鸣，4倍合计ATK伤害"},
	{heroes = ["rin", "hyouka"], name = "聖盾連撃",
	 charge_rounds = 5, mp_cost = 10, effect = "focus_damage",
	 damage_mult = 6.0, targets = "strongest",
	 desc = "圣盾连击集火最强敌人，6倍合计ATK"},
	{heroes = ["suirei", "gekka"], name = "星月交輝",
	 charge_rounds = 5, mp_cost = 11, effect = "aoe_damage",
	 damage_mult = 3.5, targets = "all_enemies",
	 desc = "星光与月华交织，3.5倍合计ATK全体伤害"},
	{heroes = ["momiji", "hakagure"], name = "紅影疾風",
	 charge_rounds = 4, mp_cost = 8, effect = "aoe_damage",
	 damage_mult = 3.5, targets = "all_enemies",
	 desc = "红叶与影的疾风突袭"},
	{heroes = ["sou", "homura"], name = "賢者炎獄",
	 charge_rounds = 6, mp_cost = 14, effect = "aoe_damage",
	 damage_mult = 5.0, targets = "all_enemies",
	 desc = "贤者与炎的合力魔法，5倍合计ATK"},
	{heroes = ["sou", "shion"], name = "時空魔導",
	 charge_rounds = 5, mp_cost = 12, effect = "aoe_damage",
	 damage_mult = 4.5, targets = "all_enemies",
	 desc = "时空魔导连携，4.5倍合计ATK"},
	{heroes = ["kaede", "hakagure"], name = "双影暗殺",
	 charge_rounds = 4, mp_cost = 8, effect = "focus_damage",
	 damage_mult = 7.0, targets = "strongest",
	 desc = "双影暗杀，7倍合计ATK集火"},
	{heroes = ["akane", "yukino"], name = "聖光祈禱",
	 charge_rounds = 5, mp_cost = 10, effect = "heal_and_damage",
	 damage_mult = 3.0, targets = "all",
	 desc = "圣光祈祷，伤害敌人并治疗友军"},
	{heroes = ["grok", "bonecrusher"], name = "蛮族双壁",
	 charge_rounds = 5, mp_cost = 10, effect = "aoe_damage",
	 damage_mult = 4.0, targets = "all_enemies",
	 desc = "兽人双壁联合冲锋，4倍合计ATK"},
	{heroes = ["siren", "storm_caller"], name = "海嵐共鳴",
	 charge_rounds = 6, mp_cost = 14, effect = "aoe_damage",
	 damage_mult = 5.0, targets = "all_enemies",
	 desc = "海妖与风暴的共鸣，5倍合计ATK"},
]

var awakening_data: Dictionary = {
	"rin": {threshold_hp = 0.3, chance = 0.5, duration_rounds = 3,
			atk_mult = 2.0, def_mult = 1.5, spd_mult = 1.5,
			passive_gain = "berserker_rage",
			name = "血桜覚醒", desc = "樱花染血，凛觉醒为战鬼形态"},
	"yukino": {threshold_hp = 0.3, chance = 0.4, duration_rounds = 3,
			   atk_mult = 1.5, def_mult = 2.0, spd_mult = 1.3,
			   passive_gain = "ice_barrier",
			   name = "氷晶覚醒", desc = "冰晶环绕，雪乃觉醒为冰之巫女"},
	"momiji": {threshold_hp = 0.3, chance = 0.5, duration_rounds = 3,
			   atk_mult = 2.0, def_mult = 1.0, spd_mult = 2.0,
			   passive_gain = "flame_charge",
			   name = "炎騎覚醒", desc = "红叶化为烈焰骑士"},
	"hyouka": {threshold_hp = 0.25, chance = 0.6, duration_rounds = 4,
			   atk_mult = 1.5, def_mult = 2.5, spd_mult = 1.0,
			   passive_gain = "iron_wall",
			   name = "鋼城覚醒", desc = "冰华觉醒为不落之城壁"},
	"suirei": {threshold_hp = 0.3, chance = 0.5, duration_rounds = 3,
			   atk_mult = 2.5, def_mult = 1.0, spd_mult = 1.5,
			   passive_gain = "eagle_eye",
			   name = "翠弓覚醒", desc = "翠玲觉醒，箭无虚发"},
	"gekka": {threshold_hp = 0.3, chance = 0.4, duration_rounds = 3,
			  atk_mult = 1.8, def_mult = 1.5, spd_mult = 1.5,
			  passive_gain = "lunar_blessing",
			  name = "月神覚醒", desc = "月华承受月神之力觉醒"},
	"hakagure": {threshold_hp = 0.3, chance = 0.6, duration_rounds = 2,
				 atk_mult = 3.0, def_mult = 1.0, spd_mult = 2.0,
				 passive_gain = "phantom_strike",
				 name = "影鬼覚醒", desc = "叶隐化为暗影鬼，攻击翻倍"},
	"sou": {threshold_hp = 0.3, chance = 0.4, duration_rounds = 3,
			atk_mult = 2.5, def_mult = 1.5, spd_mult = 1.0,
			passive_gain = "arcane_overload",
			name = "大魔導覚醒", desc = "蒼觉醒为大魔导，魔力暴走"},
	"shion": {threshold_hp = 0.3, chance = 0.5, duration_rounds = 3,
			  atk_mult = 2.0, def_mult = 1.5, spd_mult = 2.0,
			  passive_gain = "time_warp",
			  name = "時空覚醒", desc = "紫苑觉醒，操纵时空"},
	"homura": {threshold_hp = 0.3, chance = 0.6, duration_rounds = 2,
			   atk_mult = 3.0, def_mult = 0.8, spd_mult = 1.5,
			   passive_gain = "inferno",
			   name = "業火覚醒", desc = "焔觉醒为业火化身，攻击暴增"},
	"shion_pirate": {threshold_hp = 0.3, chance = 0.5, duration_rounds = 3,
					 atk_mult = 2.0, def_mult = 1.3, spd_mult = 1.5,
					 passive_gain = "sea_fury",
					 name = "怒濤覚醒", desc = "潮音觉醒为怒涛射手"},
	"youya": {threshold_hp = 0.3, chance = 0.6, duration_rounds = 2,
			  atk_mult = 2.5, def_mult = 1.0, spd_mult = 2.0,
			  passive_gain = "shadow_dance",
			  name = "闇舞覚醒", desc = "妖夜觉醒，暗影之舞"},
	"grok": {threshold_hp = 0.25, chance = 0.7, duration_rounds = 3,
			 atk_mult = 2.5, def_mult = 1.0, spd_mult = 1.5,
			 passive_gain = "blood_rage",
			 name = "血怒覚醒", desc = "グロック暴怒觉醒，攻击力暴增"},
	"shaman_zog": {threshold_hp = 0.3, chance = 0.4, duration_rounds = 3,
				   atk_mult = 2.0, def_mult = 1.5, spd_mult = 1.0,
				   passive_gain = "chaos_surge",
				   name = "混沌覚醒", desc = "シャーマン觉醒为混沌之源"},
	"bonecrusher": {threshold_hp = 0.25, chance = 0.7, duration_rounds = 3,
					atk_mult = 2.0, def_mult = 2.0, spd_mult = 1.0,
					passive_gain = "bone_armor",
					name = "骨鎧覚醒", desc = "ボーンクラッシャー觉醒，攻防双增"},
	"wolf_rider": {threshold_hp = 0.3, chance = 0.6, duration_rounds = 2,
				   atk_mult = 2.0, def_mult = 1.0, spd_mult = 2.5,
				   passive_gain = "wolf_frenzy",
				   name = "狼王覚醒", desc = "ウルフライダー觉醒为狼王"},
	"siren": {threshold_hp = 0.3, chance = 0.4, duration_rounds = 3,
			  atk_mult = 1.5, def_mult = 1.5, spd_mult = 1.5,
			  passive_gain = "siren_song",
			  name = "海妖覚醒", desc = "サイレン觉醒，魅惑之力全开"},
	"iron_hook": {threshold_hp = 0.25, chance = 0.6, duration_rounds = 3,
				  atk_mult = 2.0, def_mult = 1.5, spd_mult = 1.0,
				  passive_gain = "iron_fury",
				  name = "鉄鬼覚醒", desc = "アイアンフック觉醒为铁鬼"},
	"storm_caller": {threshold_hp = 0.3, chance = 0.4, duration_rounds = 3,
					 atk_mult = 2.5, def_mult = 1.0, spd_mult = 1.5,
					 passive_gain = "storm_lord",
					 name = "嵐王覚醒", desc = "ストームコーラー觉醒为岚之王"},
	"shadow_blade": {threshold_hp = 0.3, chance = 0.6, duration_rounds = 2,
					 atk_mult = 3.0, def_mult = 1.0, spd_mult = 2.0,
					 passive_gain = "lethal_shadow",
					 name = "致命覚醒", desc = "シャドウブレード觉醒，致命暗影"},
	"venom_queen": {threshold_hp = 0.3, chance = 0.5, duration_rounds = 3,
					atk_mult = 2.0, def_mult = 1.5, spd_mult = 1.0,
					passive_gain = "venom_nova",
					name = "猛毒覚醒", desc = "ヴェノムクイーン觉醒，剧毒爆发"},
	"dark_knight": {threshold_hp = 0.25, chance = 0.6, duration_rounds = 3,
					atk_mult = 2.0, def_mult = 2.0, spd_mult = 1.5,
					passive_gain = "dark_fortress",
					name = "闇城覚醒", desc = "ダークナイト觉醒为暗黑城塞"},
	"spymaster": {threshold_hp = 0.3, chance = 0.5, duration_rounds = 3,
				  atk_mult = 1.5, def_mult = 1.5, spd_mult = 2.0,
				  passive_gain = "mind_control",
				  name = "策謀覚醒", desc = "スパイマスター觉醒，策谋无双"},
	"soul_binder": {threshold_hp = 0.3, chance = 0.5, duration_rounds = 3,
					atk_mult = 2.0, def_mult = 1.5, spd_mult = 1.0,
					passive_gain = "soul_harvest",
					name = "冥王覚醒", desc = "ソウルバインダー觉醒为冥王"},
	"hibiki": {threshold_hp = 0.25, chance = 0.6, duration_rounds = 4,
			   atk_mult = 1.5, def_mult = 2.5, spd_mult = 1.0,
			   passive_gain = "mountain_fortress",
			   name = "山神覚醒", desc = "響觉醒为山神，铁壁不倒"},
	"sara": {threshold_hp = 0.3, chance = 0.5, duration_rounds = 3,
			 atk_mult = 2.5, def_mult = 1.0, spd_mult = 1.5,
			 passive_gain = "desert_storm",
			 name = "砂神覚醒", desc = "沙罗觉醒为砂之神射手"},
	"mei": {threshold_hp = 0.3, chance = 0.4, duration_rounds = 3,
			atk_mult = 2.5, def_mult = 1.5, spd_mult = 1.0,
			passive_gain = "death_lord",
			name = "死神覚醒", desc = "冥觉醒为死神，亡灵之王"},
	"kaede": {threshold_hp = 0.3, chance = 0.6, duration_rounds = 2,
			  atk_mult = 2.5, def_mult = 1.0, spd_mult = 2.5,
			  passive_gain = "phantom_clone",
			  name = "幻影覚醒", desc = "枫觉醒为幻影忍者"},
	"akane": {threshold_hp = 0.3, chance = 0.4, duration_rounds = 4,
			  atk_mult = 1.5, def_mult = 2.0, spd_mult = 1.0,
			  passive_gain = "holy_aura",
			  name = "聖女覚醒", desc = "朱音觉醒为圣女，全场回复"},
	"hanabi": {threshold_hp = 0.3, chance = 0.5, duration_rounds = 3,
			   atk_mult = 3.0, def_mult = 1.0, spd_mult = 1.0,
			   passive_gain = "artillery_barrage",
			   name = "砲神覚醒", desc = "花火觉醒为炮神，火力全开"},
	# --- Hidden Heroes ---
	"dragon_slayer": {threshold_hp = 0.25, chance = 0.5, duration_rounds = 3,
					  atk_mult = 3.0, def_mult = 1.5, spd_mult = 1.5,
					  passive_gain = "dragon_fury",
					  name = "龍殺覚醒", desc = "屠龙者觉醒，龙之力量爆发"},
	"saint_aria": {threshold_hp = 0.3, chance = 0.4, duration_rounds = 4,
				   atk_mult = 1.5, def_mult = 2.5, spd_mult = 1.0,
				   passive_gain = "divine_shield",
				   name = "聖域覚醒", desc = "圣女觉醒，神圣领域展开"},
	"master_smith": {threshold_hp = 0.3, chance = 0.5, duration_rounds = 3,
					 atk_mult = 2.0, def_mult = 2.0, spd_mult = 1.0,
					 passive_gain = "iron_forge",
					 name = "鉄匠覚醒", desc = "铁匠觉醒，钢铁之躯"},
}


# ---------------------------------------------------------------------------
# Ultimate Skill API
# ---------------------------------------------------------------------------

func get_ultimate(hero_id: String) -> Dictionary:
	return ultimate_skills.get(hero_id, {})


func tick_charge(hero_id: String) -> bool:
	if not ultimate_skills.has(hero_id):
		return false
	if not _charge_counters.has(hero_id):
		_charge_counters[hero_id] = 0
	_charge_counters[hero_id] += 1
	var needed: int = ultimate_skills[hero_id].get("charge_rounds", 99)
	if _charge_counters[hero_id] >= needed:
		EventBus.message_log.emit("[必杀技] %s 必杀技已充能!" % _get_hero_name(hero_id))
		return true
	return false


func is_charged(hero_id: String) -> bool:
	if not ultimate_skills.has(hero_id):
		return false
	var needed: int = ultimate_skills[hero_id].get("charge_rounds", 99)
	return _charge_counters.get(hero_id, 0) >= needed


func reset_charge(hero_id: String) -> void:
	_charge_counters[hero_id] = 0


func execute_ultimate(hero_id: String, battle_state: Dictionary) -> Dictionary:
	if not is_charged(hero_id):
		return {"ok": false, "reason": "未充能"}
	var ult: Dictionary = ultimate_skills.get(hero_id, {})
	if ult.is_empty():
		return {"ok": false, "reason": "无必杀技数据"}

	var mp_cost: int = ult.get("mp_cost", 0)
	var side: String = _find_hero_side(hero_id, battle_state)
	var mana_key: String = side + "_mana" if not side.is_empty() else ""
	if not mana_key.is_empty() and battle_state.get(mana_key, 0) < mp_cost:
		return {"ok": false, "reason": "法力不足"}

	if not mana_key.is_empty():
		battle_state[mana_key] -= mp_cost

	var hero_unit: Dictionary = _find_hero_unit(hero_id, battle_state)
	var base_atk: float = hero_unit.get("atk", 10.0)
	var damage_mult: float = ult.get("damage_mult", 2.0)
	var total_damage: int = int(base_atk * damage_mult)

	var result: Dictionary = {
		"ok": true,
		"name": ult.get("name", ""),
		"effect": ult.get("effect", ""),
		"total_damage": total_damage,
		"targets_hit": [],
		"special_effects": [],
	}

	var enemy_units: Array = _get_enemy_units(side, battle_state)

	match ult.get("effect", ""):
		"aoe_damage":
			for unit in enemy_units:
				if unit.get("is_alive", false):
					var dmg: int = maxi(1, total_damage - int(unit.get("def", 0.0)))
					unit["soldiers"] = maxi(0, unit["soldiers"] - dmg)
					if unit["soldiers"] <= 0:
						unit["is_alive"] = false
					result["targets_hit"].append({"unit": unit.get("unit_type", ""), "damage": dmg})

		"aoe_damage_freeze":
			var freeze_rounds: int = ult.get("freeze_rounds", 2)
			for unit in enemy_units:
				if unit.get("is_alive", false):
					var dmg: int = maxi(1, total_damage - int(unit.get("def", 0.0)))
					unit["soldiers"] = maxi(0, unit["soldiers"] - dmg)
					if unit["soldiers"] <= 0:
						unit["is_alive"] = false
					else:
						if not unit.has("debuffs"):
							unit["debuffs"] = []
						unit["debuffs"].append({"id": "frozen", "duration": freeze_rounds, "value": 0})
					result["targets_hit"].append({"unit": unit.get("unit_type", ""), "damage": dmg})
			result["special_effects"].append("freeze_%d" % freeze_rounds)

		"line_damage":
			var column_targets: Array = _get_column_targets(enemy_units)
			for unit in column_targets:
				if unit.get("is_alive", false):
					var dmg: int = maxi(1, total_damage - int(unit.get("def", 0.0)))
					unit["soldiers"] = maxi(0, unit["soldiers"] - dmg)
					if unit["soldiers"] <= 0:
						unit["is_alive"] = false
					result["targets_hit"].append({"unit": unit.get("unit_type", ""), "damage": dmg})

		"multi_hit":
			var hits: int = ult.get("hits", 5)
			for _i in range(hits):
				var alive: Array = []
				for u in enemy_units:
					if u.get("is_alive", false):
						alive.append(u)
				if alive.is_empty():
					break
				var target: Dictionary = alive[randi() % alive.size()]
				var dmg: int = maxi(1, total_damage - int(target.get("def", 0.0)))
				target["soldiers"] = maxi(0, target["soldiers"] - dmg)
				if target["soldiers"] <= 0:
					target["is_alive"] = false
				result["targets_hit"].append({"unit": target.get("unit_type", ""), "damage": dmg})

		"single_damage":
			var alive: Array = []
			for u in enemy_units:
				if u.get("is_alive", false):
					alive.append(u)
			if not alive.is_empty():
				alive.sort_custom(func(a, b): return a["soldiers"] > b["soldiers"])
				var target: Dictionary = alive[0]
				var dmg: int = maxi(1, total_damage - int(target.get("def", 0.0)))
				target["soldiers"] = maxi(0, target["soldiers"] - dmg)
				if target["soldiers"] <= 0:
					target["is_alive"] = false
				result["targets_hit"].append({"unit": target.get("unit_type", ""), "damage": dmg})

		"heal_all":
			var ally_units: Array = _get_ally_units(side, battle_state)
			for unit in ally_units:
				if unit.get("is_alive", false):
					var heal: int = int(base_atk * damage_mult)
					unit["soldiers"] = mini(unit["soldiers"] + heal, unit.get("max_soldiers", unit["soldiers"] + heal))
					result["targets_hit"].append({"unit": unit.get("unit_type", ""), "healed": heal})

		"buff_all":
			var ally_units: Array = _get_ally_units(side, battle_state)
			var buff_rounds: int = ult.get("buff_rounds", 3)
			for unit in ally_units:
				if unit.get("is_alive", false):
					if not unit.has("buffs"):
						unit["buffs"] = []
					unit["buffs"].append({"id": "ultimate_buff", "duration": buff_rounds, "value": damage_mult * 0.1})
					result["targets_hit"].append({"unit": unit.get("unit_type", ""), "buffed": true})
			result["special_effects"].append("team_buff_%d" % buff_rounds)

		"drain_damage":
			var ally_units: Array = _get_ally_units(side, battle_state)
			for unit in enemy_units:
				if unit.get("is_alive", false):
					var dmg: int = maxi(1, total_damage - int(unit.get("def", 0.0)))
					unit["soldiers"] = maxi(0, unit["soldiers"] - dmg)
					if unit["soldiers"] <= 0:
						unit["is_alive"] = false
					result["targets_hit"].append({"unit": unit.get("unit_type", ""), "damage": dmg})
			# Heal allies proportional to damage
			var total_dealt: int = 0
			for t in result["targets_hit"]:
				total_dealt += t.get("damage", 0)
			var heal_per: int = maxi(1, total_dealt / maxi(1, ally_units.size()))
			for unit in ally_units:
				if unit.get("is_alive", false):
					unit["soldiers"] = mini(unit["soldiers"] + heal_per, unit.get("max_soldiers", 999))

		"execute":
			for unit in enemy_units:
				if unit.get("is_alive", false):
					var hp_ratio: float = float(unit["soldiers"]) / float(maxi(1, unit.get("max_soldiers", unit["soldiers"])))
					var dmg: int
					if hp_ratio < 0.3:
						dmg = unit["soldiers"]
					else:
						dmg = maxi(1, total_damage - int(unit.get("def", 0.0)))
					unit["soldiers"] = maxi(0, unit["soldiers"] - dmg)
					if unit["soldiers"] <= 0:
						unit["is_alive"] = false
					result["targets_hit"].append({"unit": unit.get("unit_type", ""), "damage": dmg})

	reset_charge(hero_id)
	EventBus.ultimate_executed.emit(hero_id, ult.get("name", ""), result)
	EventBus.message_log.emit("[必杀技] %s 发动 %s!" % [_get_hero_name(hero_id), ult.get("name", "")])
	return result


# ---------------------------------------------------------------------------
# B. Combo Skills (连携技)
# ---------------------------------------------------------------------------

func check_available_combos(army_heroes: Array) -> Array:
	var available: Array = []
	for i in range(combo_skills.size()):
		var combo: Dictionary = combo_skills[i]
		var heroes_needed: Array = combo.get("heroes", [])
		var all_present: bool = true
		for h in heroes_needed:
			if h not in army_heroes:
				all_present = false
				break
		if all_present:
			var combo_copy: Dictionary = combo.duplicate()
			combo_copy["combo_id"] = i
			combo_copy["charged"] = _combo_charges.get(i, 0) >= combo.get("charge_rounds", 99)
			available.append(combo_copy)
	return available


func tick_combo_charges(army_heroes: Array) -> void:
	for i in range(combo_skills.size()):
		var combo: Dictionary = combo_skills[i]
		var heroes_needed: Array = combo.get("heroes", [])
		var all_present: bool = true
		for h in heroes_needed:
			if h not in army_heroes:
				all_present = false
				break
		if all_present:
			if not _combo_charges.has(i):
				_combo_charges[i] = 0
			_combo_charges[i] += 1
			var needed: int = combo.get("charge_rounds", 99)
			if _combo_charges[i] == needed:
				EventBus.message_log.emit("[连携技] %s 已就绪!" % combo.get("name", ""))


func execute_combo(combo_id: int, battle_state: Dictionary) -> Dictionary:
	if combo_id < 0 or combo_id >= combo_skills.size():
		return {"ok": false, "reason": "无效连携技"}
	var combo: Dictionary = combo_skills[combo_id]
	if _combo_charges.get(combo_id, 0) < combo.get("charge_rounds", 99):
		return {"ok": false, "reason": "未充能"}

	var mp_cost: int = combo.get("mp_cost", 0)
	var heroes_arr: Array = combo.get("heroes", [])
	var side: String = ""
	if not heroes_arr.is_empty():
		side = _find_hero_side(heroes_arr[0], battle_state)
	var mana_key: String = side + "_mana" if not side.is_empty() else ""
	if not mana_key.is_empty() and battle_state.get(mana_key, 0) < mp_cost:
		return {"ok": false, "reason": "法力不足"}

	if not mana_key.is_empty():
		battle_state[mana_key] -= mp_cost

	# Calculate combined ATK from both heroes
	var combined_atk: float = 0.0
	for hid in heroes_arr:
		var hu: Dictionary = _find_hero_unit(hid, battle_state)
		combined_atk += hu.get("atk", 10.0)
	var damage_mult: float = combo.get("damage_mult", 3.0)
	var total_damage: int = int(combined_atk * damage_mult)
	var enemy_units: Array = _get_enemy_units(side, battle_state)

	var result: Dictionary = {
		"ok": true,
		"name": combo.get("name", ""),
		"total_damage": total_damage,
		"targets_hit": [],
	}

	match combo.get("effect", "aoe_damage"):
		"aoe_damage":
			for unit in enemy_units:
				if unit.get("is_alive", false):
					var dmg: int = maxi(1, total_damage - int(unit.get("def", 0.0)))
					unit["soldiers"] = maxi(0, unit["soldiers"] - dmg)
					if unit["soldiers"] <= 0:
						unit["is_alive"] = false
					result["targets_hit"].append({"unit": unit.get("unit_type", ""), "damage": dmg})
		"focus_damage":
			var alive: Array = []
			for u in enemy_units:
				if u.get("is_alive", false):
					alive.append(u)
			if not alive.is_empty():
				alive.sort_custom(func(a, b): return a["soldiers"] > b["soldiers"])
				var target: Dictionary = alive[0]
				var dmg: int = maxi(1, total_damage)
				target["soldiers"] = maxi(0, target["soldiers"] - dmg)
				if target["soldiers"] <= 0:
					target["is_alive"] = false
				result["targets_hit"].append({"unit": target.get("unit_type", ""), "damage": dmg})
		"heal_and_damage":
			for unit in enemy_units:
				if unit.get("is_alive", false):
					var dmg: int = maxi(1, int(total_damage * 0.5) - int(unit.get("def", 0.0)))
					unit["soldiers"] = maxi(0, unit["soldiers"] - dmg)
					if unit["soldiers"] <= 0:
						unit["is_alive"] = false
					result["targets_hit"].append({"unit": unit.get("unit_type", ""), "damage": dmg})
			var ally_units: Array = _get_ally_units(side, battle_state)
			for unit in ally_units:
				if unit.get("is_alive", false):
					var heal: int = int(total_damage * 0.3)
					unit["soldiers"] = mini(unit["soldiers"] + heal, unit.get("max_soldiers", 999))

	_combo_charges[combo_id] = 0
	EventBus.combo_executed.emit(combo_id, combo.get("name", ""), result)
	EventBus.message_log.emit("[连携技] %s 发动!" % combo.get("name", ""))
	return result


# ---------------------------------------------------------------------------
# C. Awakening System (觉醒)
# ---------------------------------------------------------------------------

func check_awakening(hero_id: String, current_hp_ratio: float) -> bool:
	if not awakening_data.has(hero_id):
		return false
	if _awakened_heroes.has(hero_id):
		return false
	var data: Dictionary = awakening_data[hero_id]
	if current_hp_ratio > data.get("threshold_hp", 0.3):
		return false
	var chance: float = data.get("chance", 0.5)
	return randf() < chance


func trigger_awakening(hero_id: String) -> Dictionary:
	if not awakening_data.has(hero_id):
		return {}
	var data: Dictionary = awakening_data[hero_id]
	var duration: int = data.get("duration_rounds", 3)
	_awakened_heroes[hero_id] = {"rounds_left": duration}

	var stat_changes: Dictionary = {
		"atk_mult": data.get("atk_mult", 1.5),
		"def_mult": data.get("def_mult", 1.5),
		"spd_mult": data.get("spd_mult", 1.0),
		"passive_gain": data.get("passive_gain", ""),
		"name": data.get("name", ""),
		"desc": data.get("desc", ""),
	}

	EventBus.hero_awakened.emit(hero_id, stat_changes)
	EventBus.message_log.emit("[觉醒] %s — %s!" % [_get_hero_name(hero_id), data.get("name", "")])
	return stat_changes


func tick_awakening(hero_id: String) -> bool:
	if not _awakened_heroes.has(hero_id):
		return false
	_awakened_heroes[hero_id]["rounds_left"] -= 1
	if _awakened_heroes[hero_id]["rounds_left"] <= 0:
		_awakened_heroes.erase(hero_id)
		EventBus.awakening_ended.emit(hero_id)
		EventBus.message_log.emit("[觉醒] %s 觉醒状态结束" % _get_hero_name(hero_id))
		return false
	return true


func is_awakened(hero_id: String) -> bool:
	return _awakened_heroes.has(hero_id)


func get_awakening_stat_mults(hero_id: String) -> Dictionary:
	if not is_awakened(hero_id) or not awakening_data.has(hero_id):
		return {"atk_mult": 1.0, "def_mult": 1.0, "spd_mult": 1.0}
	var data: Dictionary = awakening_data[hero_id]
	return {
		"atk_mult": data.get("atk_mult", 1.0),
		"def_mult": data.get("def_mult", 1.0),
		"spd_mult": data.get("spd_mult", 1.0),
	}


# ---------------------------------------------------------------------------
# Battle lifecycle
# ---------------------------------------------------------------------------

func reset_battle() -> void:
	_charge_counters.clear()
	_awakened_heroes.clear()
	_combo_charges.clear()


func get_charge_progress(hero_id: String) -> Dictionary:
	if not ultimate_skills.has(hero_id):
		return {}
	var needed: int = ultimate_skills[hero_id].get("charge_rounds", 99)
	var current: int = _charge_counters.get(hero_id, 0)
	return {"current": current, "needed": needed, "charged": current >= needed}


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func to_save_data() -> Dictionary:
	# Per-battle state should NOT be persisted — it is reset each battle.
	# Returning empty to avoid stale awakened_heroes blocking future awakenings.
	return {}


func from_save_data(_data: Dictionary) -> void:
	# Per-battle state is transient; always start clean.
	_charge_counters.clear()
	_awakened_heroes.clear()
	_combo_charges.clear()


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _get_hero_name(hero_id: String) -> String:
	var data: Dictionary = FactionData.HEROES.get(hero_id, {})
	return data.get("name", hero_id)


func _find_hero_side(hero_id: String, battle_state: Dictionary) -> String:
	# Check alive units first
	for unit in battle_state.get("atk_units", []):
		if unit.get("hero_id", "") == hero_id and unit.get("is_alive", false):
			return "atk"
	for unit in battle_state.get("def_units", []):
		if unit.get("hero_id", "") == hero_id and unit.get("is_alive", false):
			return "def"
	# Fallback: search dead units to find correct side
	for unit in battle_state.get("atk_units", []):
		if unit.get("hero_id", "") == hero_id:
			return "atk"
	for unit in battle_state.get("def_units", []):
		if unit.get("hero_id", "") == hero_id:
			return "def"
	return "atk"


func _find_hero_unit(hero_id: String, battle_state: Dictionary) -> Dictionary:
	for unit in battle_state.get("atk_units", []):
		if unit.get("hero_id", "") == hero_id:
			return unit
	for unit in battle_state.get("def_units", []):
		if unit.get("hero_id", "") == hero_id:
			return unit
	return {}


func _get_enemy_units(side: String, battle_state: Dictionary) -> Array:
	if side == "atk":
		return battle_state.get("def_units", [])
	return battle_state.get("atk_units", [])


func _get_ally_units(side: String, battle_state: Dictionary) -> Array:
	if side == "atk":
		return battle_state.get("atk_units", [])
	return battle_state.get("def_units", [])


func _get_column_targets(enemy_units: Array) -> Array:
	## Select a vertical column (one front + one back unit sharing the same slot index).
	## Picks the column with the most total soldiers for maximum impact.
	var front_by_slot: Dictionary = {}  # slot -> unit
	var back_by_slot: Dictionary = {}
	for u in enemy_units:
		if not u.get("is_alive", false):
			continue
		var slot: int = u.get("slot", 0)
		if u.get("row", "front") == "front":
			front_by_slot[slot] = u
		else:
			back_by_slot[slot] = u
	# Collect all unique slot indices
	var all_slots: Dictionary = {}
	for s in front_by_slot:
		all_slots[s] = true
	for s in back_by_slot:
		all_slots[s] = true
	if all_slots.is_empty():
		return []
	# Pick the slot column with the most total soldiers
	var best_slot: int = -1
	var best_soldiers: int = -1
	for s in all_slots:
		var total: int = 0
		if front_by_slot.has(s):
			total += front_by_slot[s].get("soldiers", 0)
		if back_by_slot.has(s):
			total += back_by_slot[s].get("soldiers", 0)
		if total > best_soldiers:
			best_soldiers = total
			best_slot = s
	var result: Array = []
	if front_by_slot.has(best_slot):
		result.append(front_by_slot[best_slot])
	if back_by_slot.has(best_slot):
		result.append(back_by_slot[best_slot])
	return result
