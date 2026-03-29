## environment_system.gd — Environment & Growth System for 暗潮 SLG
## Combines: Day/Night Cycle, Fatigue, Soldier Promotion, War Loot
## Autoload singleton: EnvironmentSystem
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")

# ---------------------------------------------------------------------------
# A. Day/Night Cycle (昼夜)
# ---------------------------------------------------------------------------

enum TimeOfDay { DAWN, DAY, DUSK, NIGHT }

const TIME_NAMES: Dictionary = {
	TimeOfDay.DAWN: "黎明",
	TimeOfDay.DAY: "白昼",
	TimeOfDay.DUSK: "黄昏",
	TimeOfDay.NIGHT: "夜晚",
}

const TIME_EFFECTS: Dictionary = {
	TimeOfDay.DAWN: {
		name = "黎明",
		assassin_atk_bonus = 0, ranged_accuracy_mod = 0, undead_atk_bonus = 0,
		visibility_mod = 0, morale_bonus = 3,
		desc = "黎明时分，士气微增+3",
	},
	TimeOfDay.DAY: {
		name = "白昼",
		assassin_atk_bonus = 0, ranged_accuracy_mod = 5, undead_atk_bonus = 0,
		visibility_mod = 0, morale_bonus = 0,
		desc = "白昼，远程精度+5%",
	},
	TimeOfDay.DUSK: {
		name = "黄昏",
		assassin_atk_bonus = 1, ranged_accuracy_mod = 0, undead_atk_bonus = 0,
		visibility_mod = -1, morale_bonus = 1,
		desc = "黄昏，刺客ATK+1，视野-1",
	},
	TimeOfDay.NIGHT: {
		name = "夜晚",
		assassin_atk_bonus = 3, ranged_accuracy_mod = -15, undead_atk_bonus = 2,
		visibility_mod = -2, morale_bonus = 0,
		desc = "夜晚: 刺客ATK+3, 远程精度-15%, 亡灵ATK+2, 视野-2",
	},
}

var current_time: TimeOfDay = TimeOfDay.DAWN
var _time_turn_counter: int = 0

func advance_time() -> void:
	_time_turn_counter += 1
	var new_time: TimeOfDay = (_time_turn_counter % 4) as TimeOfDay
	if new_time != current_time:
		current_time = new_time
		EventBus.time_of_day_changed.emit(int(current_time), get_time_data())
		EventBus.message_log.emit("[昼夜] %s" % TIME_NAMES.get(current_time, ""))

func get_time() -> TimeOfDay:
	return current_time

func get_time_data() -> Dictionary:
	return TIME_EFFECTS.get(current_time, TIME_EFFECTS[TimeOfDay.DAY]).duplicate()

func get_time_combat_modifiers() -> Dictionary:
	var data: Dictionary = TIME_EFFECTS.get(current_time, {})
	return {
		"assassin_atk_bonus": data.get("assassin_atk_bonus", 0),
		"ranged_accuracy_mod": data.get("ranged_accuracy_mod", 0),
		"undead_atk_bonus": data.get("undead_atk_bonus", 0),
		"visibility_mod": data.get("visibility_mod", 0),
		"morale_bonus": data.get("morale_bonus", 0),
	}

# ---------------------------------------------------------------------------
# B. Fatigue System (疲劳度)
# ---------------------------------------------------------------------------

# army_id -> int (fatigue 0-100)
var _fatigue: Dictionary = {}

const FATIGUE_PER_BATTLE: int = 15
const FATIGUE_PER_MARCH: int = 10
const FATIGUE_PER_IDLE_TURN: int = 5
const FATIGUE_REST_RECOVERY: int = 20
const FATIGUE_MAX: int = 100

const FATIGUE_TIERS: Array = [
	{threshold = 0, atk_pct = 0, def_pct = 0, spd_mod = 0, morale_drain = 0, desertion_chance = 0.0,
	 label = "良好", desc = "无惩罚"},
	{threshold = 31, atk_pct = -10, def_pct = -10, spd_mod = 0, morale_drain = 0, desertion_chance = 0.0,
	 label = "疲惫", desc = "ATK/DEF -10%"},
	{threshold = 61, atk_pct = -20, def_pct = -20, spd_mod = -1, morale_drain = 5, desertion_chance = 0.0,
	 label = "精疲力竭", desc = "ATK/DEF -20%, SPD-1, 士气-5/回合"},
	{threshold = 81, atk_pct = -30, def_pct = -30, spd_mod = -2, morale_drain = 10, desertion_chance = 0.10,
	 label = "崩溃边缘", desc = "ATK/DEF -30%, SPD-2, 士气-10/回合, 10%逃兵"},
]

func get_fatigue(army_id: int) -> int:
	return _fatigue.get(army_id, 0)

func add_fatigue(army_id: int, amount: int) -> void:
	var current: int = _fatigue.get(army_id, 0)
	_fatigue[army_id] = clampi(current + amount, 0, FATIGUE_MAX)
	EventBus.fatigue_changed.emit(army_id, _fatigue[army_id])

func rest_army(army_id: int) -> void:
	add_fatigue(army_id, -FATIGUE_REST_RECOVERY)
	EventBus.message_log.emit("[疲劳] 军队 %d 休整，疲劳-20 (当前: %d)" % [army_id, get_fatigue(army_id)])

func on_battle(army_id: int) -> void:
	add_fatigue(army_id, FATIGUE_PER_BATTLE)

func on_march(army_id: int) -> void:
	add_fatigue(army_id, FATIGUE_PER_MARCH)

func on_idle_turn(army_id: int) -> void:
	add_fatigue(army_id, FATIGUE_PER_IDLE_TURN)

func get_fatigue_tier(army_id: int) -> Dictionary:
	var fatigue: int = get_fatigue(army_id)
	var tier: Dictionary = FATIGUE_TIERS[0]
	for t in FATIGUE_TIERS:
		if fatigue >= t["threshold"]:
			tier = t
	return tier

func get_fatigue_combat_modifiers(army_id: int) -> Dictionary:
	var tier: Dictionary = get_fatigue_tier(army_id)
	return {
		"atk_pct": tier.get("atk_pct", 0),
		"def_pct": tier.get("def_pct", 0),
		"spd_mod": tier.get("spd_mod", 0),
		"morale_drain": tier.get("morale_drain", 0),
		"desertion_chance": tier.get("desertion_chance", 0.0),
	}

func check_desertion(army_id: int) -> bool:
	var tier: Dictionary = get_fatigue_tier(army_id)
	var chance: float = tier.get("desertion_chance", 0.0)
	if chance > 0.0 and randf() < chance:
		EventBus.fatigue_desertion.emit(army_id)
		EventBus.message_log.emit("[疲劳] 军队 %d 出现逃兵! (疲劳: %d)" % [army_id, get_fatigue(army_id)])
		return true
	return false

func reset_fatigue(army_id: int) -> void:
	_fatigue[army_id] = 0

# ---------------------------------------------------------------------------
# C. Soldier Promotion / Veterancy (士兵晋升)
# ---------------------------------------------------------------------------

enum Veterancy { RECRUIT, REGULAR, VETERAN, ELITE, LEGENDARY }

const VETERANCY_NAMES: Dictionary = {
	Veterancy.RECRUIT: "新兵",
	Veterancy.REGULAR: "正规",
	Veterancy.VETERAN: "老兵",
	Veterancy.ELITE: "精锐",
	Veterancy.LEGENDARY: "传奇",
}

const PROMOTION_THRESHOLDS: Dictionary = {
	Veterancy.REGULAR: 3,
	Veterancy.VETERAN: 8,
	Veterancy.ELITE: 15,
	Veterancy.LEGENDARY: 30,
}

const VETERANCY_BONUSES: Dictionary = {
	Veterancy.RECRUIT: {atk = 0, def = 0, spd = 0, morale = 0, passive = ""},
	Veterancy.REGULAR: {atk = 1, def = 1, spd = 0, morale = 5, passive = ""},
	Veterancy.VETERAN: {atk = 2, def = 2, spd = 1, morale = 10, passive = ""},
	Veterancy.ELITE: {atk = 3, def = 3, spd = 1, morale = 15, passive = "steady"},
	Veterancy.LEGENDARY: {atk = 5, def = 4, spd = 2, morale = 20, passive = "unbreakable"},
}

# unit_id -> {battles: int, veterancy: Veterancy}
var _unit_veterancy: Dictionary = {}

func record_battle(unit_id: String) -> void:
	if not _unit_veterancy.has(unit_id):
		_unit_veterancy[unit_id] = {battles = 0, veterancy = Veterancy.RECRUIT}
	_unit_veterancy[unit_id]["battles"] += 1
	var old_vet: int = _unit_veterancy[unit_id]["veterancy"]
	var new_vet: int = _calculate_veterancy(_unit_veterancy[unit_id]["battles"])
	if new_vet > old_vet:
		_unit_veterancy[unit_id]["veterancy"] = new_vet
		EventBus.unit_promoted.emit(unit_id, VETERANCY_NAMES.get(new_vet, ""))
		EventBus.message_log.emit("[晋升] %s 晋升为 %s!" % [unit_id, VETERANCY_NAMES.get(new_vet, "")])

func check_promotion(unit_id: String) -> Veterancy:
	if not _unit_veterancy.has(unit_id):
		return Veterancy.RECRUIT
	return _unit_veterancy[unit_id]["veterancy"] as Veterancy

func get_veterancy_bonuses(unit_id: String) -> Dictionary:
	var vet: int = check_promotion(unit_id)
	return VETERANCY_BONUSES.get(vet, VETERANCY_BONUSES[Veterancy.RECRUIT]).duplicate()

func get_unit_battles(unit_id: String) -> int:
	return _unit_veterancy.get(unit_id, {}).get("battles", 0)

func _calculate_veterancy(battles: int) -> int:
	if battles >= PROMOTION_THRESHOLDS[Veterancy.LEGENDARY]:
		return Veterancy.LEGENDARY
	if battles >= PROMOTION_THRESHOLDS[Veterancy.ELITE]:
		return Veterancy.ELITE
	if battles >= PROMOTION_THRESHOLDS[Veterancy.VETERAN]:
		return Veterancy.VETERAN
	if battles >= PROMOTION_THRESHOLDS[Veterancy.REGULAR]:
		return Veterancy.REGULAR
	return Veterancy.RECRUIT

# ---------------------------------------------------------------------------
# D. War Loot / Drop System (战利品)
# ---------------------------------------------------------------------------

var loot_tables: Dictionary = {
	"normal": [
		{item = "iron", weight = 30, qty = [5, 15]},
		{item = "gold", weight = 25, qty = [20, 50]},
		{item = "food", weight = 20, qty = [10, 30]},
		{item = "equipment_common", weight = 15, qty = [1, 1]},
		{item = "equipment_rare", weight = 7, qty = [1, 1]},
		{item = "enchant_scroll", weight = 3, qty = [1, 1]},
	],
	"boss": [
		{item = "gold", weight = 20, qty = [50, 150]},
		{item = "equipment_rare", weight = 25, qty = [1, 1]},
		{item = "equipment_epic", weight = 15, qty = [1, 1]},
		{item = "enchant_scroll", weight = 20, qty = [1, 2]},
		{item = "skill_book", weight = 10, qty = [1, 1]},
		{item = "legendary_fragment", weight = 10, qty = [1, 3]},
	],
	"siege": [
		{item = "gold", weight = 25, qty = [30, 100]},
		{item = "iron", weight = 20, qty = [15, 40]},
		{item = "equipment_common", weight = 20, qty = [1, 2]},
		{item = "strategic_resource", weight = 15, qty = [1, 1]},
		{item = "enchant_scroll", weight = 10, qty = [1, 1]},
		{item = "territory_bonus", weight = 10, qty = [1, 1]},
	],
}

func generate_loot(battle_type: String, enemy_tier: int) -> Array:
	var table: Array = loot_tables.get(battle_type, loot_tables["normal"])
	var drops: Array = []
	# Number of loot rolls: 2 for normal, 3 for boss/siege, +1 per enemy tier above 2
	var num_rolls: int = 2 if battle_type == "normal" else 3
	num_rolls += maxi(0, enemy_tier - 2)
	num_rolls = mini(num_rolls, 6)

	var total_weight: int = 0
	for entry in table:
		total_weight += entry["weight"]

	for _i in range(num_rolls):
		var roll: int = randi() % total_weight
		var cumulative: int = 0
		for entry in table:
			cumulative += entry["weight"]
			if roll < cumulative:
				var qty_range: Array = entry.get("qty", [1, 1])
				var qty: int = randi_range(qty_range[0], qty_range[1])
				# Check if same item already dropped, stack it
				var found: bool = false
				for existing in drops:
					if existing["item"] == entry["item"]:
						existing["qty"] += qty
						found = true
						break
				if not found:
					drops.append({"item": entry["item"], "qty": qty})
				break

	# Tier bonus: higher enemy tier = more quantity
	if enemy_tier >= 3:
		for drop in drops:
			if drop["item"] in ["gold", "iron", "food"]:
				drop["qty"] = int(float(drop["qty"]) * (1.0 + float(enemy_tier - 2) * 0.25))

	EventBus.loot_generated.emit(drops)
	return drops


func apply_loot(loot: Array) -> void:
	var pid: int = GameManager.get_human_player_id()
	var loot_summary: Array = []

	for drop in loot:
		var item: String = drop["item"]
		var qty: int = drop["qty"]

		match item:
			"gold":
				ResourceManager.apply_delta(pid, {"gold": qty})
				loot_summary.append("金币 +%d" % qty)
			"iron":
				ResourceManager.apply_delta(pid, {"iron": qty})
				loot_summary.append("铁矿 +%d" % qty)
			"food":
				ResourceManager.apply_delta(pid, {"food": qty})
				loot_summary.append("粮食 +%d" % qty)
			"equipment_common", "equipment_rare", "equipment_epic":
				# Add to item manager inventory
				if ItemManager.has_method("add_random_equipment"):
					ItemManager.add_random_equipment(pid, item)
				loot_summary.append("%s x%d" % [item, qty])
			"enchant_scroll":
				if ItemManager.has_method("add_item"):
					ItemManager.add_item(pid, "enchant_scroll", qty)
				loot_summary.append("附魔卷轴 x%d" % qty)
			"skill_book":
				if ItemManager.has_method("add_item"):
					ItemManager.add_item(pid, "skill_book", qty)
				loot_summary.append("技能书 x%d" % qty)
			"legendary_fragment":
				if ItemManager.has_method("add_item"):
					ItemManager.add_item(pid, "legendary_fragment", qty)
				loot_summary.append("传说碎片 x%d" % qty)
			"strategic_resource":
				if StrategicResourceManager.has_method("add_random_resource"):
					StrategicResourceManager.add_random_resource(pid, qty)
				loot_summary.append("战略资源 x%d" % qty)
			"territory_bonus":
				loot_summary.append("领地加成 x%d" % qty)
			_:
				loot_summary.append("%s x%d" % [item, qty])

	if not loot_summary.is_empty():
		EventBus.loot_applied.emit(loot)
		EventBus.message_log.emit("[战利品] " + ", ".join(loot_summary))


# ---------------------------------------------------------------------------
# Strategic turn tick — call once per turn
# ---------------------------------------------------------------------------

func advance_turn() -> void:
	advance_time()


# ---------------------------------------------------------------------------
# Reset
# ---------------------------------------------------------------------------

func reset() -> void:
	current_time = TimeOfDay.DAWN
	_time_turn_counter = 0
	_fatigue.clear()
	_unit_veterancy.clear()


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func to_save_data() -> Dictionary:
	return {
		"current_time": int(current_time),
		"time_turn_counter": _time_turn_counter,
		"fatigue": _fatigue.duplicate(),
		"unit_veterancy": _unit_veterancy.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	current_time = data.get("current_time", 0) as TimeOfDay
	_time_turn_counter = data.get("time_turn_counter", 0)
	_fatigue = data.get("fatigue", {}).duplicate()
	_unit_veterancy = data.get("unit_veterancy", {}).duplicate(true)
