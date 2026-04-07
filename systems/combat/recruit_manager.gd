extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")
const TROOP_UPGRADE_RULES_PATH: String = "res://systems/combat/data/troop_upgrade_rules.json"

## recruit_manager.gd — Army composition system (v0.9 / Phase 3)
##
## Manages per-player armies as Arrays of troop instances (from GameData).
## Each troop instance: { troop_id, soldiers, max_soldiers, commander_id, experience }
##
## Also handles tile garrison composition (replacing flat int garrisons).

# ── Player armies: { player_id: Array[Dictionary] } ──
var _armies: Dictionary = {}

# ── Tile garrisons: { tile_index: Array[Dictionary] } ──
var _garrisons: Dictionary = {}

# ── Wanderer armies on map: { tile_index: Array[Dictionary] } ──
var _wanderers: Dictionary = {}

# ── Rebel armies: { tile_index: Array[Dictionary] } ──
var _rebels: Dictionary = {}

const _DEFAULT_FACTION_TROOP_MAP: Dictionary = {
	FactionData.FactionID.ORC: "orc_ashigaru",
	FactionData.FactionID.PIRATE: "pirate_ashigaru",
	FactionData.FactionID.DARK_ELF: "de_samurai",
}

const _TROOP_UPGRADE_PATHS: Dictionary = {
	# Orc
	"orc_ashigaru": "orc_samurai",
	"orc_samurai": "orc_cavalry",
	# Pirate
	"pirate_ashigaru": "pirate_archer",
	"pirate_archer": "pirate_cannon",
	# Dark Elf
	"de_samurai": "de_ninja",
	"de_ninja": "de_cavalry",
	# Generic
	"ashigaru": "samurai",
	"samurai": "cavalry",
	"archer": "ninja",
	"militia": "knight",
	# Human
	"human_ashigaru": "human_samurai",
	"human_samurai": "human_cavalry",
	# High Elf
	"elf_archer": "elf_mage",
	"elf_mage": "elf_ashigaru",
	# Mage
	"mage_apprentice": "mage_battle",
	"mage_battle": "mage_grand",
}

const _DEFAULT_UPGRADE_RULES: Dictionary = {
	"default": {
		"min_exp_ratio": 0.5,
		"min_exp_floor": 10,
		"cost": {
			"gold_base": 20,
			"gold_per_tier": 20,
			"iron_base": 8,
			"iron_per_tier": 7,
		},
	},
	"rules": {}
}

var _upgrade_rules: Dictionary = _DEFAULT_UPGRADE_RULES.duplicate(true)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load_troop_upgrade_rules()

func reset() -> void:
	_armies.clear()
	_garrisons.clear()
	_wanderers.clear()
	_rebels.clear()


func init_player(player_id: int) -> void:
	_armies[player_id] = []


func _load_troop_upgrade_rules() -> void:
	_upgrade_rules = _DEFAULT_UPGRADE_RULES.duplicate(true)
	if not FileAccess.file_exists(TROOP_UPGRADE_RULES_PATH):
		push_warning("RecruitManager: upgrade rules file missing, using defaults")
		return
	var file := FileAccess.open(TROOP_UPGRADE_RULES_PATH, FileAccess.READ)
	if file == null:
		push_warning("RecruitManager: failed to open %s, using defaults" % TROOP_UPGRADE_RULES_PATH)
		return
	var json_str: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_warning("RecruitManager: invalid upgrade rules json: %s" % json.get_error_message())
		return
	if not json.data is Dictionary:
		push_warning("RecruitManager: upgrade rules root must be Dictionary")
		return
	var loaded: Dictionary = json.data
	if loaded.has("default") and loaded["default"] is Dictionary:
		_upgrade_rules["default"] = loaded["default"]
	if loaded.has("rules") and loaded["rules"] is Dictionary:
		_upgrade_rules["rules"] = loaded["rules"]


# ---------------------------------------------------------------------------
# Player Army API
# ---------------------------------------------------------------------------

## Returns the player's army (Array of troop instances). Returns a copy.
func get_army(player_id: int) -> Array:
	if not _armies.has(player_id):
		return []
	return _armies[player_id].duplicate(true)


## Returns the actual mutable army reference (internal use).
func _get_army_ref(player_id: int) -> Array:
	if not _armies.has(player_id):
		_armies[player_id] = []
	return _armies[player_id]


## Total soldiers across all troop instances for a player.
func get_total_soldiers(player_id: int) -> int:
	return GameData.get_army_total_soldiers(_get_army_ref(player_id))


## Combat power estimate.
func get_combat_power(player_id: int) -> int:
	return GameData.get_army_combat_power(_get_army_ref(player_id))


## Returns display-friendly army summary.
func get_army_summary(player_id: int) -> Array:
	return GameData.get_army_summary(_get_army_ref(player_id))


# ---------------------------------------------------------------------------
# Recruitment
# ---------------------------------------------------------------------------

## Default fallback troop id used by legacy recruit flows.
func get_default_troop_id_for_faction(faction_id: int) -> String:
	return _DEFAULT_FACTION_TROOP_MAP.get(faction_id, "ashigaru")


func get_remaining_pop_slots(player_id: int) -> int:
	var pop_cap: int = _get_pop_cap(player_id)
	var army_ref: Array = _get_army_ref(player_id)
	return maxi(0, pop_cap - army_ref.size())


## Recruit one default squad by faction, used by GameManager legacy/domestic recruit entry points.
## Returns { "ok": bool, "troop_id": String, "soldiers": int }.
func recruit_default_unit_for_faction(player_id: int, faction_id: int) -> Dictionary:
	var troop_id: String = get_default_troop_id_for_faction(faction_id)
	if get_remaining_pop_slots(player_id) <= 0:
		return {"ok": false, "troop_id": troop_id, "soldiers": 0, "reason": "pop_cap"}
	var instance: Dictionary = GameData.create_troop_instance(troop_id)
	if instance.is_empty():
		return {"ok": false, "troop_id": troop_id, "soldiers": 0, "reason": "invalid_troop_def"}
	reinforce_army(player_id, [instance])
	if EventBus.has_signal("army_troops_assigned"):
		EventBus.army_troops_assigned.emit(player_id, troop_id, instance.get("soldiers", 0))
	return {"ok": true, "troop_id": troop_id, "soldiers": instance.get("soldiers", 0)}


func get_troop_upgrade_target(troop_id: String) -> String:
	var rule: Dictionary = _get_upgrade_rule(troop_id)
	if not rule.is_empty():
		return String(rule.get("to_troop_id", ""))
	return _TROOP_UPGRADE_PATHS.get(troop_id, "")


## Returns upgrade requirements for a troop instance.
## { can_upgrade, reason, upgrade_id, cost, min_exp, current_exp }
func get_troop_upgrade_requirements(troop: Dictionary, player_id: int = -1) -> Dictionary:
	var current_id: String = troop.get("troop_id", "")
	var upgrade_id: String = get_troop_upgrade_target(current_id)
	if upgrade_id == "":
		return {"can_upgrade": false, "reason": "no_upgrade_path", "upgrade_id": ""}
	var current_def: Dictionary = GameData.TROOP_TYPES.get(current_id, {})
	var target_def: Dictionary = GameData.TROOP_TYPES.get(upgrade_id, {})
	if current_def.is_empty() or target_def.is_empty():
		return {"can_upgrade": false, "reason": "invalid_upgrade_def", "upgrade_id": upgrade_id}

	var rule: Dictionary = _get_upgrade_rule(current_id)
	var current_tier: int = int(current_def.get("tier", 1))
	var min_exp: int = _compute_upgrade_min_exp(current_tier, rule)
	var current_exp: int = int(troop.get("experience", 0))
	var cost: Dictionary = _compute_upgrade_cost(current_tier, rule)
	if current_exp < min_exp:
		return {
			"can_upgrade": false,
			"reason": "insufficient_experience",
			"upgrade_id": upgrade_id,
			"cost": cost,
			"min_exp": min_exp,
			"current_exp": current_exp,
		}
	if player_id >= 0 and not ResourceManager.can_afford(player_id, cost):
		return {
			"can_upgrade": false,
			"reason": "insufficient_resources",
			"upgrade_id": upgrade_id,
			"cost": cost,
			"min_exp": min_exp,
			"current_exp": current_exp,
		}
	return {
		"can_upgrade": true,
		"reason": "",
		"upgrade_id": upgrade_id,
		"cost": cost,
		"min_exp": min_exp,
		"current_exp": current_exp,
	}


func get_upgrade_failure_reason_text(req: Dictionary) -> String:
	var reason: String = req.get("reason", "")
	match reason:
		"no_upgrade_path":
			return "无可用升级路线"
		"invalid_upgrade_def":
			return "目标兵种数据异常"
		"insufficient_experience":
			return "经验不足 %d/%d" % [int(req.get("current_exp", 0)), int(req.get("min_exp", 0))]
		"insufficient_resources":
			var cost: Dictionary = req.get("cost", {})
			return "资源不足 (金%d 铁%d)" % [int(cost.get("gold", 0)), int(cost.get("iron", 0))]
	return "暂不可升级"


func plan_default_recruit_for_faction(player_id: int, faction_id: int) -> Dictionary:
	var troop_id: String = get_default_troop_id_for_faction(faction_id)
	var result: Dictionary = {
		"ok": false,
		"reason": "",
		"troop_id": troop_id,
		"cost": {},
	}
	if FactionData.FACTION_PARAMS.has(faction_id):
		var fp: Dictionary = FactionData.FACTION_PARAMS[faction_id]
		result["cost"] = {
			"gold": int(fp.get("recruit_cost_gold", 0)),
			"iron": int(fp.get("recruit_cost_iron", 0)),
		}
	if get_remaining_pop_slots(player_id) <= 0:
		result["reason"] = "pop_cap"
		return result
	if not ResourceManager.can_afford(player_id, result["cost"]):
		result["reason"] = "insufficient_resources"
		return result
	var instance: Dictionary = GameData.create_troop_instance(troop_id)
	if instance.is_empty():
		result["reason"] = "invalid_troop_def"
		return result
	result["ok"] = true
	return result


func _get_upgrade_rule(troop_id: String) -> Dictionary:
	var rules: Dictionary = _upgrade_rules.get("rules", {})
	if rules.has(troop_id) and rules[troop_id] is Dictionary:
		return rules[troop_id]
	return {}


func _compute_upgrade_min_exp(current_tier: int, rule: Dictionary) -> int:
	var tier_exp_cap: int = int(GameData.TIER_EXP_CAP.get(current_tier, 30))
	var default_rule: Dictionary = _upgrade_rules.get("default", {})
	var ratio: float = float(default_rule.get("min_exp_ratio", 0.5))
	var floor_val: int = int(default_rule.get("min_exp_floor", 10))
	if rule.has("min_exp_ratio"):
		ratio = float(rule.get("min_exp_ratio", ratio))
	if rule.has("min_exp"):
		return maxi(0, int(rule.get("min_exp", floor_val)))
	return maxi(floor_val, int(round(float(tier_exp_cap) * ratio)))


func _compute_upgrade_cost(current_tier: int, rule: Dictionary) -> Dictionary:
	var default_rule: Dictionary = _upgrade_rules.get("default", {})
	var cost_rule: Dictionary = default_rule.get("cost", {})
	var gold: int = int(cost_rule.get("gold_base", 20)) + current_tier * int(cost_rule.get("gold_per_tier", 20))
	var iron: int = int(cost_rule.get("iron_base", 8)) + current_tier * int(cost_rule.get("iron_per_tier", 7))
	if rule.has("cost") and rule["cost"] is Dictionary:
		var override_cost: Dictionary = rule["cost"]
		gold = int(override_cost.get("gold", gold))
		iron = int(override_cost.get("iron", iron))
	return {"gold": maxi(0, gold), "iron": maxi(0, iron)}


## Mutates troop dictionary in place and returns operation result.
## Returns { "ok": bool, "old_name": String, "new_name": String }.
func apply_troop_upgrade(troop: Dictionary, exp_cost: int = 0) -> Dictionary:
	var current_id: String = troop.get("troop_id", "")
	var upgrade_id: String = get_troop_upgrade_target(current_id)
	if upgrade_id == "":
		return {"ok": false, "reason": "no_upgrade_path"}
	var new_data: Dictionary = GameData.TROOP_TYPES.get(upgrade_id, {})
	if new_data.is_empty():
		return {"ok": false, "reason": "invalid_upgrade_def"}

	var old_name: String = troop.get("name", current_id)
	troop["troop_id"] = upgrade_id
	troop["name"] = new_data.get("name", upgrade_id)
	troop["atk"] = new_data.get("atk", troop.get("atk", 0))
	troop["def"] = new_data.get("def", troop.get("def", 0))
	troop["spd"] = new_data.get("spd", troop.get("spd", 5))
	var new_max: int = new_data.get("max_soldiers", troop.get("max_soldiers", troop.get("soldiers", 1)))
	troop["max_soldiers"] = new_max
	troop["soldiers"] = mini(troop.get("soldiers", new_max), new_max)
	troop["hp_per_soldier"] = new_data.get("hp_per_soldier", troop.get("hp_per_soldier", 5))
	troop["total_hp"] = troop["soldiers"] * troop["hp_per_soldier"]
	if new_data.has("passive"):
		troop["passive"] = new_data["passive"]
	var spent: int = maxi(0, exp_cost)
	var cur_exp: int = int(troop.get("experience", 0))
	if spent > 0:
		troop["experience"] = maxi(0, cur_exp - spent)
	troop["upgrade_count"] = int(troop.get("upgrade_count", 0)) + 1
	if GameManager != null:
		troop["last_upgrade_turn"] = int(GameManager.turn_number)
	return {"ok": true, "old_name": old_name, "new_name": troop["name"], "exp_spent": spent}

## Returns recruitable troops at a tile for a player.
func get_available_units(player_id: int, tile: Dictionary) -> Array:
	var result: Array = []
	var faction_tag: String = _get_faction_tag(player_id)
	var tile_level: int = tile.get("level", 1)
	var recruitables: Array = GameData.get_recruitable_troops(faction_tag, tile_level)

	# Gather discounts
	var discount_pct: float = _get_recruit_discount(player_id)
	var cost_mult: float = RelicManager.get_recruit_cost_mult(player_id)

	for troop_id in recruitables:
		var td: Dictionary = GameData.get_troop_def(troop_id)
		if td.is_empty():
			continue
		var cost: Dictionary = GameData.calculate_recruit_cost(troop_id, discount_pct, cost_mult)
		result.append(_build_unit_entry(troop_id, td, cost, player_id))

	# ── Neutral faction troops (unlocked via taming) ──
	var neutral_troops: Array = QuestManager.get_all_unlocked_neutral_troops(player_id)
	for troop_id in neutral_troops:
		var td: Dictionary = GameData.get_troop_def(troop_id)
		if td.is_empty():
			continue
		var cost: Dictionary = GameData.calculate_recruit_cost(troop_id, 0.0, 1.0)
		result.append(_build_unit_entry(troop_id, td, cost, player_id))

	# ── Pirate mercenary hiring (any faction T1-T2 at 2x cost) ──
	if faction_tag == "pirate":
		var fp: Dictionary = GameData.FACTION_PASSIVES.get("pirate", {})
		if fp.get("mercenary_hiring", false):
			var merc_mult: float = fp.get("mercenary_cost_mult", 2.0)
			var merc_factions: Array = ["orc", "dark_elf", "human", "high_elf", "mage"]
			for mf in merc_factions:
				var merc_troops: Array = GameData.get_troops_by_faction(mf)
				for mid in merc_troops:
					var mtd: Dictionary = GameData.get_troop_def(mid)
					if mtd.is_empty() or mtd.get("tier", 1) > 2:
						continue
					if mtd.get("category", 0) != GameData.TroopCategory.FACTION:
						continue
					var mcost: Dictionary = GameData.calculate_recruit_cost(mid, 0.0, merc_mult)
					var entry: Dictionary = _build_unit_entry(mid, mtd, mcost, player_id)
					entry["is_mercenary"] = true
					result.append(entry)

	# ── Dark Elf slave fodder (free T0) ──
	if faction_tag == "dark_elf":
		var fp: Dictionary = GameData.FACTION_PASSIVES.get("dark_elf", {})
		if fp.get("slave_deploy", false):
			var slave_td: Dictionary = GameData.get_troop_def("slave_fodder")
			if not slave_td.is_empty():
				# Requires slaves resource
				var slave_count: int = ResourceManager.get_resource(player_id, "slaves")
				var scost: Dictionary = {"slaves": 1}
				var entry: Dictionary = _build_unit_entry("slave_fodder", slave_td, scost, player_id)
				entry["can_recruit"] = slave_count >= 1
				result.append(entry)

	return result


func _build_unit_entry(troop_id: String, td: Dictionary, cost: Dictionary, player_id: int) -> Dictionary:
	var affordable: bool = ResourceManager.can_afford(player_id, cost)
	# WAAAGH! cost check (not in ResourceManager)
	var waaagh_needed: int = cost.get("waaagh", 0)
	if waaagh_needed > 0 and OrcMechanic.get_waaagh(player_id) < waaagh_needed:
		affordable = false
	return {
		"troop_id": troop_id,
		"unit_id": troop_id,
		"name": td.get("name", troop_id),
		"base_atk": td.get("base_atk", 0),
		"base_def": td.get("base_def", 0),
		"max_soldiers": td.get("max_soldiers", 1),
		"troop_class": td.get("troop_class", 0),
		"row": td.get("row", "front"),
		"passive": td.get("passive", ""),
		"tier": td.get("tier", 1),
		"cost": cost,
		"can_recruit": affordable,
		"special": td.get("passive", "none"),
		"desc": td.get("desc", ""),
		"is_mercenary": false,
	}


## Recruit a troop. Creates a full squad at max_soldiers. Deducts cost.
# FIX(HIGH): 使用原子校验+扣除模式，防止并发招募时资源竞态条件
func recruit_unit(player_id: int, troop_id: String, tile: Dictionary) -> bool:
	var available: Array = get_available_units(player_id, tile)
	var found: Dictionary = {}
	for entry in available:
		if entry["troop_id"] == troop_id:
			found = entry
			break
	if found.is_empty() or not found["can_recruit"]:
		return false

	# Check population cap
	var pop_cap: int = _get_pop_cap(player_id)
	var army_ref: Array = _get_army_ref(player_id)
	if army_ref.size() >= pop_cap:
		EventBus.message_log.emit("[color=red]军团已满(%d/%d)[/color]" % [army_ref.size(), pop_cap])
		return false

	# 原子校验并扣除资源：try_spend内部同时检查余额并扣除，避免竞态
	if not ResourceManager.try_spend(player_id, found["cost"]):
		EventBus.message_log.emit("[color=red]资源不足，招募失败[/color]")
		return false

	# Orc WAAAGH! cost: deduct from OrcMechanic (not tracked in ResourceManager)
	var waaagh_cost: int = found["cost"].get("waaagh", 0)
	if waaagh_cost > 0:
		OrcMechanic.add_waaagh(player_id, -waaagh_cost)

	var instance: Dictionary = GameData.create_troop_instance(troop_id)
	army_ref.append(instance)

	# Sync total soldier count to ResourceManager for legacy compatibility
	_sync_army_count(player_id)

	# Emit army_troops_assigned signal so board.gd / army_panel.gd can refresh
	var new_count: int = army_ref.size()
	var new_pop_cap: int = _get_pop_cap(player_id)
	if EventBus.has_signal("army_troops_assigned"):
		EventBus.army_troops_assigned.emit(player_id, troop_id, instance.get("soldiers", 0))

	var tier_str: String = "T%d" % found.get("tier", 1)
	var remaining_slots: int = new_pop_cap - new_count
	EventBus.message_log.emit("[color=cyan]✔ 招募 %s [%s] (%d兵) | 名额: %d/%d (剩余%d格)[/color]" % [found["name"], tier_str, instance.get("soldiers", 0), new_count, new_pop_cap, remaining_slots])
	return true


## Remove a specific troop instance by index.
func remove_troop(player_id: int, index: int) -> void:
	var army_ref: Array = _get_army_ref(player_id)
	if index >= 0 and index < army_ref.size():
		army_ref.remove_at(index)
		_sync_army_count(player_id)


## Apply combat losses to a player's army.
func apply_combat_losses(player_id: int, total_losses: int) -> int:
	var army_ref: Array = _get_army_ref(player_id)
	var actual: int = GameData.apply_army_losses(army_ref, total_losses)
	_sync_army_count(player_id)
	return actual


## Merge reinforcements into army.
func reinforce_army(player_id: int, reinforcements: Array) -> void:
	var army_ref: Array = _get_army_ref(player_id)
	var slots_left: int = get_remaining_pop_slots(player_id)
	if slots_left <= 0:
		if EventBus != null:
			EventBus.message_log.emit("[color=yellow]军团名额已满，无法接收增援[/color]")
		return
	var accepted: Array = reinforcements
	if reinforcements.size() > slots_left:
		accepted = reinforcements.slice(0, slots_left)
		if EventBus != null:
			EventBus.message_log.emit("[color=yellow]军团名额不足，仅接收%d/%d支增援[/color]" % [accepted.size(), reinforcements.size()])
	GameData.merge_into_army(army_ref, accepted)
	_sync_army_count(player_id)


## v4.4: Heal army squads — distribute healing to most-damaged squads first.
## Returns total soldiers actually healed.
func heal_army_squads(player_id: int, amount: int) -> int:
	var army_ref: Array = _get_army_ref(player_id)
	if army_ref.is_empty():
		return 0
	var total_healed: int = 0
	var remaining: int = amount
	# Sort squads by damage (most damaged first) — work on indices to mutate in-place
	var sorted_indices: Array = range(army_ref.size())
	sorted_indices.sort_custom(func(a: int, b: int) -> bool:
		var da: int = army_ref[a].get("max_soldiers", army_ref[a]["soldiers"]) - army_ref[a]["soldiers"]
		var db: int = army_ref[b].get("max_soldiers", army_ref[b]["soldiers"]) - army_ref[b]["soldiers"]
		return da > db
	)
	for idx in sorted_indices:
		if remaining <= 0:
			break
		var troop: Dictionary = army_ref[idx]
		var max_s: int = troop.get("max_soldiers", troop["soldiers"])
		var missing: int = max_s - troop["soldiers"]
		if missing <= 0:
			continue
		var heal: int = mini(missing, remaining)
		troop["soldiers"] += heal
		remaining -= heal
		total_healed += heal
	if total_healed > 0:
		_sync_army_count(player_id)
	return total_healed


## Build combat unit array for CombatResolver (backward compatible format).
## Includes synergy bonuses, veterancy, and aura from T4 troops.
func get_combat_units(player_id: int) -> Array:
	var result: Array = []
	var army_ref: Array = _get_army_ref(player_id)
	# Compute tier mechanic bonuses
	var syn_bonuses: Dictionary = GameData.compute_synergy_bonuses(army_ref)
	var aura: Dictionary = GameData.compute_aura_bonuses(army_ref)
	for idx in range(army_ref.size()):
		var troop: Dictionary = army_ref[idx]
		var td: Dictionary = GameData.get_troop_def(troop["troop_id"])
		if td.is_empty():
			continue
		# Base stats + veterancy
		var eff_atk: int = GameData.get_effective_atk(troop)
		var eff_def: int = GameData.get_effective_def(troop)
		# + synergy
		var syn: Dictionary = syn_bonuses.get(idx, {})
		eff_atk += syn.get("atk", 0)
		eff_def += syn.get("def", 0)
		# + aura (T4 buff)
		eff_atk += aura.get("atk", 0)
		eff_def += aura.get("def", 0)
		var row_int: int = td.get("row", GameData.Row.FRONT)
		var row_str: String = "back" if row_int == GameData.Row.BACK else "front"
		result.append({
			"type": troop["troop_id"],
			"atk": eff_atk,
			"def": eff_def,
			"hp": troop["soldiers"],
			"special": td.get("passive", "none"),
			"count": troop["soldiers"],
			"soldiers": troop["soldiers"],
			"troop_class": td.get("troop_class", GameData.TroopClass.ASHIGARU),
			"row": row_str,
			"row_int": 0 if row_str == "front" else 1,
			"max_soldiers": troop.get("max_soldiers", td["max_soldiers"]),
			"tier": td.get("tier", 1),
			"synergy": syn.get("synergy_name", ""),
			"experience": troop.get("experience", 0),
			"spd": td.get("spd", 5),
			"int_stat": td.get("int_stat", 0),
			"hero_id": troop.get("commander_id", ""),
		})
	# Reset ability_used flags for the upcoming battle
	for troop in army_ref:
		troop["ability_used"] = false
	return result


# ---------------------------------------------------------------------------
# Garrison API (tile-based troop composition)
# ---------------------------------------------------------------------------

## Set garrison for a tile from template.
func set_garrison_from_template(tile_index: int, template_id: String) -> void:
	_garrisons[tile_index] = GameData.create_garrison_from_template(template_id)


## Set garrison directly.
func set_garrison(tile_index: int, troops: Array) -> void:
	_garrisons[tile_index] = troops


## Get garrison troops for a tile.
func get_garrison(tile_index: int) -> Array:
	if not _garrisons.has(tile_index):
		return []
	return _garrisons[tile_index].duplicate(true)


## Get garrison reference (internal).
func _get_garrison_ref(tile_index: int) -> Array:
	if not _garrisons.has(tile_index):
		_garrisons[tile_index] = []
	return _garrisons[tile_index]


## Total garrison soldiers at a tile.
func get_garrison_strength(tile_index: int) -> int:
	return GameData.get_army_total_soldiers(_get_garrison_ref(tile_index))


## Get garrison combat units (for CombatResolver).
func get_garrison_combat_units(tile_index: int) -> Array:
	var result: Array = []
	for troop in _get_garrison_ref(tile_index):
		var td: Dictionary = GameData.get_troop_def(troop["troop_id"])
		if td.is_empty():
			continue
		var gar_row_int: int = td.get("row", GameData.Row.FRONT)
		var gar_row_str: String = "back" if gar_row_int == GameData.Row.BACK else "front"
		var _eff_atk: int = td.get("base_atk", 5)
		var _eff_def: int = td.get("base_def", 3)
		var _eff_spd: int = td.get("spd", 5)
		var _eff_int: int = td.get("int_stat", 0)
		var _hero_id: String = troop.get("commander_id", "")
		var _unit: Dictionary = {
			"type": troop["troop_id"],
			"atk": _eff_atk,
			"def": _eff_def,
			"hp": troop["soldiers"],
			"special": td.get("passive", "none"),
			"count": troop["soldiers"],
			"soldiers": troop["soldiers"],
			"troop_class": td.get("troop_class", GameData.TroopClass.ASHIGARU),
			"row": gar_row_str,
			"max_soldiers": troop.get("max_soldiers", td.get("max_soldiers", troop.get("soldiers", 10))),
			"spd": _eff_spd,
			"int_stat": _eff_int,
			"hero_id": _hero_id,
		}
		# BUG FIX: inject garrison commander hero_data so CombatResolver applies
		# hero stat bonuses, passives, and level_passives in defensive battles.
		if _hero_id != "" and HeroSystem != null and HeroSystem.has_method("get_hero_combat_stats"):
			var _hcs: Dictionary = HeroSystem.get_hero_combat_stats(_hero_id)
			if not _hcs.is_empty():
				_unit["atk"] += _hcs.get("atk", 0)
				_unit["def"] += _hcs.get("def", 0)
				_unit["spd"] += _hcs.get("spd", 0)
				_unit["int_stat"] += _hcs.get("int_stat", 0)
				_unit["hero_data"] = {
					"id": _hero_id,
					"hp": _hcs.get("hp", 20),
					"mp": _hcs.get("mp", 10),
					"troop_specialty": _hcs.get("troop", ""),
					"equipment_passives": _hcs.get("equipment_passives", []),
					"level_passives": _hcs.get("level_passives", []),
					"active_skill": _hcs.get("active", ""),
					"active_skill_2": _hcs.get("active_2", ""),
					"passive": _hcs.get("passive", ""),
				}
		result.append(_unit)
	return result


## Apply combat losses to garrison.
func apply_garrison_losses(tile_index: int, total_losses: int) -> int:
	var garrison_ref: Array = _get_garrison_ref(tile_index)
	return GameData.apply_army_losses(garrison_ref, total_losses)


## Clear garrison (tile captured).
func clear_garrison(tile_index: int) -> void:
	_garrisons.erase(tile_index)


## Reinforce garrison.
func reinforce_garrison(tile_index: int, reinforcements: Array) -> void:
	var garrison_ref: Array = _get_garrison_ref(tile_index)
	GameData.merge_into_army(garrison_ref, reinforcements)


## Garrison display summary.
func get_garrison_summary(tile_index: int) -> Array:
	return GameData.get_army_summary(_get_garrison_ref(tile_index))


# ---------------------------------------------------------------------------
# Wanderer Army API
# ---------------------------------------------------------------------------

## Spawn wanderers at a tile.
func spawn_wanderer(tile_index: int) -> void:
	var army: Array = GameData.spawn_wanderer_army()
	if not army.is_empty():
		_wanderers[tile_index] = army


## Get wanderer army at tile.
func get_wanderer(tile_index: int) -> Array:
	return _wanderers.get(tile_index, [])


## Remove wanderer (defeated or absorbed).
func clear_wanderer(tile_index: int) -> void:
	_wanderers.erase(tile_index)


## Get all tiles with wanderers.
func get_wanderer_tiles() -> Array:
	return _wanderers.keys()


## Wanderer combat units (for resolver).
func get_wanderer_combat_units(tile_index: int) -> Array:
	var result: Array = []
	for troop in get_wanderer(tile_index):
		var td: Dictionary = GameData.get_troop_def(troop["troop_id"])
		if td.is_empty():
			continue
		var wnd_row_int: int = td.get("row", GameData.Row.FRONT)
		var wnd_row_str: String = "back" if wnd_row_int == GameData.Row.BACK else "front"
		result.append({
			"type": troop["troop_id"],
			"atk": td.get("base_atk", 5),
			"def": td.get("base_def", 3),
			"hp": troop["soldiers"],
			"special": td.get("passive", "none"),
			"count": troop["soldiers"],
			"soldiers": troop["soldiers"],
			"max_soldiers": troop.get("max_soldiers", td.get("max_soldiers", troop.get("soldiers", 10))),
			"troop_class": td.get("troop_class", GameData.TroopClass.ASHIGARU),
			"row": wnd_row_str,
			"spd": td.get("spd", 5),
			"int_stat": td.get("int_stat", 0),
			"hero_id": troop.get("commander_id", ""),
		})
	return result


# ---------------------------------------------------------------------------
# Rebel Army API
# ---------------------------------------------------------------------------

## Try to spawn a rebel army at a tile (based on order value).
func try_spawn_rebel(tile_index: int, order_value: int) -> bool:
	if _rebels.has(tile_index):
		return false
	var army: Array = GameData.spawn_rebel_army(order_value)
	if not army.is_empty():
		_rebels[tile_index] = army
		return true
	return false


## Get rebel army at tile.
func get_rebel(tile_index: int) -> Array:
	return _rebels.get(tile_index, [])


## Remove rebel army.
func clear_rebel(tile_index: int) -> void:
	_rebels.erase(tile_index)


## Get all tiles with rebel armies.
func get_rebel_tiles() -> Array:
	return _rebels.keys()


## Rebel combat units (for resolver).
func get_rebel_combat_units(tile_index: int) -> Array:
	var result: Array = []
	for troop in get_rebel(tile_index):
		var td: Dictionary = GameData.get_troop_def(troop["troop_id"])
		if td.is_empty():
			continue
		var reb_row_int: int = td.get("row", GameData.Row.FRONT)
		var reb_row_str: String = "back" if reb_row_int == GameData.Row.BACK else "front"
		result.append({
			"type": troop["troop_id"],
			"atk": td.get("base_atk", 5),
			"def": td.get("base_def", 3),
			"hp": troop["soldiers"],
			"special": td.get("passive", "none"),
			"count": troop["soldiers"],
			"soldiers": troop["soldiers"],
			"max_soldiers": troop.get("max_soldiers", td.get("max_soldiers", troop.get("soldiers", 10))),
			"troop_class": td.get("troop_class", GameData.TroopClass.ASHIGARU),
			"row": reb_row_str,
			"spd": td.get("spd", 5),
			"int_stat": td.get("int_stat", 0),
			"hero_id": troop.get("commander_id", ""),
		})
	return result


# ---------------------------------------------------------------------------
# Legacy compatibility — remove_units (old API)
# ---------------------------------------------------------------------------

## Backward compat: remove units by type + amount (kills soldiers, not instances).
func remove_units(player_id: int, unit_id: String, amount: int) -> void:
	var army_ref: Array = _get_army_ref(player_id)
	var remaining: int = amount
	var i: int = army_ref.size() - 1
	while i >= 0 and remaining > 0:
		if army_ref[i]["troop_id"] == unit_id:
			var kill: int = mini(remaining, army_ref[i]["soldiers"])
			army_ref[i]["soldiers"] -= kill
			remaining -= kill
			if army_ref[i]["soldiers"] <= 0:
				army_ref.remove_at(i)
		i -= 1
	_sync_army_count(player_id)


## Backward compat: get army composition as {troop_id: soldier_count}.
func get_army_composition(player_id: int) -> Dictionary:
	var result: Dictionary = {}
	for troop in _get_army_ref(player_id):
		var tid: String = troop["troop_id"]
		result[tid] = result.get(tid, 0) + troop["soldiers"]
	return result


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _get_faction_tag(player_id: int) -> String:
	var faction_id: int = GameManager.get_player_faction(player_id)
	match faction_id:
		FactionData.FactionID.ORC: return "orc"
		FactionData.FactionID.PIRATE: return "pirate"
		FactionData.FactionID.DARK_ELF: return "dark_elf"
	return "orc"


func _get_recruit_discount(player_id: int) -> float:
	var discount: float = 0.0
	# Training ground building discount
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) != player_id:
			continue
		if tile.get("building_id", "") == "training_ground":
			var bld_level: int = tile.get("building_level", 1)
			var effects: Dictionary = BuildingRegistry.get_building_effects("training_ground", bld_level)
			discount = maxf(discount, float(effects.get("recruit_discount", 0)))
	# NPC discount
	var npc_bonuses: Dictionary = NpcManager.get_active_skill_bonuses(player_id)
	discount += float(npc_bonuses.get("recruit_discount", 0))
	# v4.7: PrestigeShop permanent recruit discount
	if PrestigeShop != null:
		discount += PrestigeShop.get_recruit_discount()
	return discount


func _get_pop_cap(player_id: int) -> int:
	## Max number of troop squads (instances) a player can have.
	## Base 3 + 1 per 5 tiles owned.
	var owned_tiles: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			owned_tiles += 1
	@warning_ignore("integer_division")
	var base: int = 3 + (owned_tiles / 5)
	# v4.4: garrison_bonus — equipment passive increases troop cap
	if player_id == GameManager.get_human_player_id():
		for hid in HeroSystem.recruited_heroes:
			if HeroSystem.has_equipment_passive(hid, "garrison_bonus"):
				base += int(HeroSystem.get_equipment_passive_value(hid, "garrison_bonus"))
				break  # Only apply once
	return base


func _sync_army_count(player_id: int) -> void:
	## Keep ResourceManager.army in sync (total soldiers) for HUD/legacy code.
	var total: int = get_total_soldiers(player_id)
	ResourceManager.set_army(player_id, total)


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func to_save_data() -> Dictionary:
	return {
		"armies": _armies.duplicate(true),
		"garrisons": _garrisons.duplicate(true),
		"wanderers": _wanderers.duplicate(true),
		"rebels": _rebels.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_armies = data.get("armies", {}).duplicate(true)
	_garrisons = data.get("garrisons", {}).duplicate(true)
	_wanderers = data.get("wanderers", {}).duplicate(true)
	_rebels = data.get("rebels", {}).duplicate(true)
	# Fix int keys that became strings after JSON round-trip
	_fix_int_keys(_armies)
	_fix_int_keys(_garrisons)
	_fix_int_keys(_wanderers)
	_fix_int_keys(_rebels)


func _fix_int_keys(dict: Dictionary) -> void:
	var fix_keys = []
	for k in dict.keys():
		if k is String and k.is_valid_int():
			fix_keys.append(k)
	for k in fix_keys:
		var int_key: int = int(k)
		if not dict.has(int_key):
			dict[int_key] = dict[k]
		dict.erase(k)


# ---------------------------------------------------------------------------
# Fatigue & Veterancy Integration (v6.0)
# ---------------------------------------------------------------------------

## Get army fatigue level for display.
func get_army_fatigue(player_id: int) -> int:
	return EnvironmentSystem.get_fatigue(player_id)


## Get fatigue tier info for army.
func get_army_fatigue_tier(player_id: int) -> Dictionary:
	return EnvironmentSystem.get_fatigue_tier(player_id)


## Rest army to reduce fatigue (call when army is in friendly territory).
func rest_army_at_territory(player_id: int) -> void:
	EnvironmentSystem.rest_army(player_id)


## Get veterancy info for a specific troop unit.
func get_troop_veterancy(unit_id: String) -> Dictionary:
	return {
		"bonuses": EnvironmentSystem.get_veterancy_bonuses(unit_id),
		"rank": EnvironmentSystem.VETERANCY_NAMES.get(EnvironmentSystem.check_promotion(unit_id), "新兵"),
		"battles": EnvironmentSystem.get_unit_battles(unit_id),
	}
