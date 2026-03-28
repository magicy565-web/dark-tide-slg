## counter_matrix.gd — Unit Type Advantage/Disadvantage Matrix
## Creates meaningful army composition decisions through hard counters.
##
## Design Philosophy:
## - Counters give +30% damage dealt / -20% damage taken (significant but not auto-win)
## - Hard counters give +50% damage dealt / -30% damage taken (dominant but beatable with numbers)
## - Neutral matchups have no modifier
## - Synergy counters: some units TOGETHER counter things neither could alone
class_name CounterMatrix
extends RefCounted

## Troop base types for counter lookup
## Maps specific unit_type strings to their base archetype
const TYPE_MAP: Dictionary = {
	# Ashigaru / Infantry
	"orc_ashigaru": "infantry", "pirate_ashigaru": "infantry", "de_samurai": "infantry",
	"human_ashigaru": "infantry", "slave_fodder": "infantry",
	"neutral_dwarf_guard": "heavy_infantry", "neutral_skeleton": "undead_infantry",
	"rebel_militia": "infantry", "wanderer_deserter": "infantry",
	"hero_rin_knights": "heavy_infantry", "hero_hyouka_templars": "heavy_infantry",
	# Samurai / Elite Melee
	"orc_samurai": "berserker", "human_samurai": "heavy_infantry",
	"neutral_blood_berserker": "berserker", "neutral_merc_captain": "infantry",
	"neutral_caravan_guard": "infantry", "wanderer_bandit": "infantry",
	# Cavalry
	"orc_cavalry": "cavalry", "de_cavalry": "cavalry", "human_cavalry": "cavalry",
	"hero_momiji_cavalry": "cavalry", "neutral_goblin_mech": "mech",
	# Archer / Ranged
	"pirate_archer": "gunner", "elf_archer": "archer", "neutral_green_archer": "archer",
	"hero_suirei_archers": "archer", "rebel_archer": "archer",
	# Ninja / Assassin
	"de_ninja": "assassin", "hero_hakagure_shinobi": "assassin",
	# Priest / Healer
	"hero_yukino_maidens": "priest", "hero_gekka_acolytes": "priest",
	"neutral_blood_shaman": "priest",
	# Mage
	"elf_mage": "mage", "mage_apprentice": "mage", "mage_battle": "mage",
	"mage_grand": "mage", "hero_sou_disciples": "mage",
	"hero_shion_chrono": "mage", "hero_homura_flame": "mage",
	"neutral_necromancer": "mage",
	# Cannon / Artillery
	"pirate_cannon": "artillery", "neutral_goblin_cannon": "artillery",
	"neutral_dwarf_cannon": "artillery",
	# Special
	"elf_ashigaru": "tank", "neutral_treant": "tank",
	"orc_ultimate": "boss", "pirate_ultimate": "boss", "de_ultimate": "boss",
	"wanderer_refugee": "fodder",
	# Alliance
	"alliance_vanguard": "cavalry", "alliance_arcane_battery": "mage",
}

## The counter matrix: attacker_type -> defender_type -> {atk_mult, def_mult, label}
## atk_mult: multiplier on damage DEALT by attacker
## def_mult: multiplier on damage TAKEN by attacker (< 1.0 = takes less damage)
## Only non-neutral matchups are listed. Missing = neutral (1.0, 1.0)
const COUNTER_TABLE: Dictionary = {
	"cavalry": {
		"archer":    {"atk_mult": 1.50, "def_mult": 0.70, "label": "骑兵冲锋弓手", "hard": true},
		"gunner":    {"atk_mult": 1.30, "def_mult": 0.80, "label": "骑兵冲击火枪"},
		"mage":      {"atk_mult": 1.30, "def_mult": 0.80, "label": "骑兵突袭法师"},
		"artillery": {"atk_mult": 1.50, "def_mult": 0.70, "label": "骑兵碾压炮兵", "hard": true},
		"priest":    {"atk_mult": 1.30, "def_mult": 0.85, "label": "骑兵追击祭司"},
		"assassin":  {"atk_mult": 1.25, "def_mult": 0.90, "label": "骑兵追猎刺客"},
		"heavy_infantry": {"atk_mult": 0.70, "def_mult": 1.30, "label": "骑兵撞铁壁", "weak": true},
		"tank":      {"atk_mult": 0.60, "def_mult": 1.40, "label": "骑兵撞坦克", "weak": true},
	},
	"infantry": {
		"cavalry":   {"atk_mult": 1.20, "def_mult": 0.90, "label": "步兵列阵拒骑"},
		"gunner":    {"atk_mult": 1.20, "def_mult": 0.90, "label": "步兵盾墙挡火枪"},
		"berserker": {"atk_mult": 0.80, "def_mult": 1.20, "label": "步兵惧怕狂战士", "weak": true},
		"assassin":  {"atk_mult": 0.85, "def_mult": 1.15, "label": "步兵难防刺客"},
	},
	"heavy_infantry": {
		"cavalry":   {"atk_mult": 1.40, "def_mult": 0.70, "label": "重步兵克骑兵", "hard": true},
		"infantry":  {"atk_mult": 1.20, "def_mult": 0.85, "label": "重步兵碾压步兵"},
		"berserker": {"atk_mult": 1.10, "def_mult": 0.90, "label": "重步兵抗狂战"},
		"mage":      {"atk_mult": 0.70, "def_mult": 1.40, "label": "重甲弱于魔法", "weak": true},
		"assassin":  {"atk_mult": 0.80, "def_mult": 1.20, "label": "重甲弱点暴露"},
	},
	"archer": {
		"infantry":  {"atk_mult": 1.30, "def_mult": 0.90, "label": "弓手压制步兵"},
		"berserker": {"atk_mult": 1.20, "def_mult": 0.90, "label": "弓手风筝狂战"},
		"tank":      {"atk_mult": 0.70, "def_mult": 1.10, "label": "弓手难伤坦克", "weak": true},
		"cavalry":   {"atk_mult": 0.70, "def_mult": 1.30, "label": "弓手惧骑兵", "weak": true},
		"assassin":  {"atk_mult": 0.60, "def_mult": 1.40, "label": "弓手怕刺客", "weak": true},
	},
	"gunner": {
		"infantry":  {"atk_mult": 1.30, "def_mult": 0.85, "label": "火枪穿透步兵"},
		"heavy_infantry": {"atk_mult": 1.20, "def_mult": 0.90, "label": "火枪破重甲"},
		"tank":      {"atk_mult": 1.10, "def_mult": 0.95, "label": "火枪击坦克"},
		"mech":      {"atk_mult": 1.20, "def_mult": 0.90, "label": "火枪穿甲击机甲"},
		"assassin":  {"atk_mult": 1.15, "def_mult": 0.90, "label": "火枪警戒防刺客"},
		"cavalry":   {"atk_mult": 0.80, "def_mult": 1.20, "label": "火枪怕突击", "weak": true},
	},
	"mage": {
		"heavy_infantry": {"atk_mult": 1.50, "def_mult": 0.70, "label": "魔法克重甲", "hard": true},
		"tank":      {"atk_mult": 1.40, "def_mult": 0.75, "label": "魔法克坦克", "hard": true},
		"infantry":  {"atk_mult": 1.20, "def_mult": 0.90, "label": "魔法压步兵"},
		"berserker": {"atk_mult": 1.15, "def_mult": 0.90, "label": "魔法压狂战"},  # v4.3: mage soft-counters berserker (low magic resist)
		"assassin":  {"atk_mult": 0.60, "def_mult": 1.50, "label": "法师怕刺客", "weak": true},
		"cavalry":   {"atk_mult": 0.80, "def_mult": 1.20, "label": "法师怕骑兵", "weak": true},
	},
	"assassin": {
		"mage":      {"atk_mult": 1.50, "def_mult": 0.70, "label": "刺客克法师", "hard": true},
		"priest":    {"atk_mult": 1.40, "def_mult": 0.75, "label": "刺客克祭司", "hard": true},
		"archer":    {"atk_mult": 1.40, "def_mult": 0.80, "label": "刺客克弓手"},
		"artillery": {"atk_mult": 1.40, "def_mult": 0.80, "label": "刺客破坏炮兵"},
		"heavy_infantry": {"atk_mult": 1.20, "def_mult": 0.90, "label": "刺客找弱点"},
		"tank":      {"atk_mult": 0.50, "def_mult": 1.30, "label": "刺客打不动坦克", "weak": true},
	},
	"berserker": {
		"infantry":  {"atk_mult": 1.40, "def_mult": 0.80, "label": "狂战碾压步兵", "hard": true},
		"archer":    {"atk_mult": 1.30, "def_mult": 0.85, "label": "狂战追击弓手"},
		"priest":    {"atk_mult": 1.30, "def_mult": 0.85, "label": "狂战追击祭司"},
		"heavy_infantry": {"atk_mult": 0.80, "def_mult": 1.20, "label": "狂战撞铁壁", "weak": true},
		"tank":      {"atk_mult": 0.70, "def_mult": 1.30, "label": "狂战撞坦克", "weak": true},
	},
	"artillery": {
		"tank":      {"atk_mult": 1.30, "def_mult": 0.90, "label": "炮击坦克"},
		"heavy_infantry": {"atk_mult": 1.20, "def_mult": 0.90, "label": "炮击重甲"},
		"infantry":  {"atk_mult": 1.20, "def_mult": 0.90, "label": "炮击步兵"},
		"mech":      {"atk_mult": 1.20, "def_mult": 0.90, "label": "炮击机甲"},
		"cavalry":   {"atk_mult": 0.60, "def_mult": 1.50, "label": "炮兵怕骑兵", "weak": true},
		"assassin":  {"atk_mult": 0.60, "def_mult": 1.40, "label": "炮兵怕刺客", "weak": true},
	},
	"tank": {
		"assassin":  {"atk_mult": 1.20, "def_mult": 0.80, "label": "坦克无惧刺客"},
		"cavalry":   {"atk_mult": 1.30, "def_mult": 0.70, "label": "坦克拒骑兵", "hard": true},
		"mage":      {"atk_mult": 0.60, "def_mult": 1.50, "label": "坦克弱于魔法", "weak": true},
		"artillery": {"atk_mult": 0.70, "def_mult": 1.20, "label": "坦克怕炮击", "weak": true},
	},
	"priest": {
		# Priests generally don't deal damage (heal mode), but if forced to:
		"undead_infantry": {"atk_mult": 1.50, "def_mult": 0.70, "label": "神圣克亡灵", "hard": true},
		"berserker": {"atk_mult": 1.20, "def_mult": 0.90, "label": "神圣安抚狂战"},
	},
	"undead_infantry": {
		"infantry":  {"atk_mult": 1.10, "def_mult": 0.90, "label": "亡灵压步兵"},
		"priest":    {"atk_mult": 0.60, "def_mult": 1.50, "label": "亡灵惧神圣", "weak": true},
	},
	"mech": {
		"infantry":  {"atk_mult": 1.40, "def_mult": 0.70, "label": "机甲碾压步兵", "hard": true},
		"cavalry":   {"atk_mult": 1.20, "def_mult": 0.85, "label": "机甲拒骑兵"},
		"mage":      {"atk_mult": 0.70, "def_mult": 1.40, "label": "机甲弱于魔法", "weak": true},
		"artillery": {"atk_mult": 0.80, "def_mult": 1.20, "label": "机甲怕炮击"},
	},
	"boss": {
		# Boss has actual matchups instead of flat bonus
		"infantry":  {"atk_mult": 1.40, "def_mult": 0.75, "label": "终极碾压步兵", "hard": true},
		"archer":    {"atk_mult": 1.30, "def_mult": 0.80, "label": "终极压制弓手"},
		"mage":      {"atk_mult": 0.75, "def_mult": 1.25, "label": "终极畏惧魔法", "weak": true},
		"artillery": {"atk_mult": 0.70, "def_mult": 1.30, "label": "终极怕炮击", "weak": true},
	},
	"fodder": {
		"_default":  {"atk_mult": 0.80, "def_mult": 1.20, "label": "弱小单位", "morale_resist": 0.50},
	},
}

## Get the counter relationship between two units
## Returns: { "atk_mult": float, "def_mult": float, "label": String, "advantage": String }
## advantage: "strong", "hard_counter", "weak", "neutral"
static func get_counter(attacker_type: String, defender_type: String) -> Dictionary:
	var atk_base: String = TYPE_MAP.get(attacker_type, "infantry")
	var def_base: String = TYPE_MAP.get(defender_type, "infantry")

	# Same type = neutral
	if atk_base == def_base:
		return {"atk_mult": 1.0, "def_mult": 1.0, "label": "", "advantage": "neutral"}

	var matchup: Dictionary = {}
	if COUNTER_TABLE.has(atk_base):
		matchup = COUNTER_TABLE[atk_base].get(def_base, {})

	if matchup.is_empty():
		# Check for _default entry
		if COUNTER_TABLE.has(atk_base) and COUNTER_TABLE[atk_base].has("_default"):
			matchup = COUNTER_TABLE[atk_base]["_default"]
		else:
			return {"atk_mult": 1.0, "def_mult": 1.0, "label": "", "advantage": "neutral"}

	var advantage: String = "neutral"
	if matchup.get("hard", false):
		advantage = "hard_counter"
	elif matchup.get("weak", false):
		advantage = "weak"
	elif matchup.get("atk_mult", 1.0) > 1.0:
		advantage = "strong"

	return {
		"atk_mult": matchup.get("atk_mult", 1.0),
		"def_mult": matchup.get("def_mult", 1.0),
		"label": matchup.get("label", ""),
		"advantage": advantage,
	}

## Get a preview of all counters for a given unit type (for UI tooltip)
static func get_counter_summary(unit_type: String) -> Dictionary:
	var base: String = TYPE_MAP.get(unit_type, "infantry")
	var strong_vs: Array = []
	var weak_vs: Array = []

	if COUNTER_TABLE.has(base):
		for target_type in COUNTER_TABLE[base]:
			if target_type == "_default":
				continue
			var data: Dictionary = COUNTER_TABLE[base][target_type]
			if data.get("atk_mult", 1.0) > 1.0:
				strong_vs.append({"type": target_type, "label": data.get("label", ""), "hard": data.get("hard", false)})

	# Find what counters US
	for atk_type in COUNTER_TABLE:
		if atk_type == base:
			continue
		var table: Dictionary = COUNTER_TABLE[atk_type]
		if table.has(base):
			var data: Dictionary = table[base]
			if data.get("atk_mult", 1.0) > 1.0:
				weak_vs.append({"type": atk_type, "label": data.get("label", ""), "hard": data.get("hard", false)})

	return {"strong_vs": strong_vs, "weak_vs": weak_vs, "base_type": base}
