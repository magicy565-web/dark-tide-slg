## formation_system.gd — Formation Synergy & Advanced Battle Tactics (v1.0)
## Auto-detects army composition bonuses, formation clashes, and mid-battle combos.
## Integrated with EventBus signals for UI/audio hooks.
extends RefCounted
class_name FormationSystem

# ─── Formation IDs ───────────────────────────────────────────────────────────
enum FormationID {
	IRON_WALL,
	CAVALRY_CHARGE,
	ARROW_STORM,
	SHADOW_STRIKE,
	ARCANE_BARRAGE,
	HOLY_BASTION,
	BERSERKER_HORDE,
	PIRATE_BROADSIDE,
	BALANCED_FORCE,
	LONE_WOLF,
}

const FORMATION_NAMES: Dictionary = {
	FormationID.IRON_WALL: "Iron Wall",
	FormationID.CAVALRY_CHARGE: "Cavalry Charge",
	FormationID.ARROW_STORM: "Arrow Storm",
	FormationID.SHADOW_STRIKE: "Shadow Strike",
	FormationID.ARCANE_BARRAGE: "Arcane Barrage",
	FormationID.HOLY_BASTION: "Holy Bastion",
	FormationID.BERSERKER_HORDE: "Berserker Horde",
	FormationID.PIRATE_BROADSIDE: "Pirate Broadside",
	FormationID.BALANCED_FORCE: "Balanced Force",
	FormationID.LONE_WOLF: "Lone Wolf",
}

const FORMATION_NAMES_CN: Dictionary = {
	FormationID.IRON_WALL: "铁壁阵",
	FormationID.CAVALRY_CHARGE: "骑兵冲锋",
	FormationID.ARROW_STORM: "箭雨阵",
	FormationID.SHADOW_STRIKE: "影袭阵",
	FormationID.ARCANE_BARRAGE: "奥术轰炸",
	FormationID.HOLY_BASTION: "圣域阵",
	FormationID.BERSERKER_HORDE: "狂暴部落",
	FormationID.PIRATE_BROADSIDE: "海盗齐射",
	FormationID.BALANCED_FORCE: "均衡阵容",
	FormationID.LONE_WOLF: "独狼",
}

# ─── Tactical Combo IDs ─────────────────────────────────────────────────────
const COMBO_PINCER_ATTACK := "PINCER_ATTACK"
const COMBO_DESPERATE_STAND := "DESPERATE_STAND"
const COMBO_COMMANDER_DUEL := "COMMANDER_DUEL"

# ─── Unit classification helpers ─────────────────────────────────────────────
# TroopClass mirrors from TroopRegistry (avoid circular preload)
const TC_ASHIGARU := 0
const TC_SAMURAI := 1
const TC_ARCHER := 2
const TC_CAVALRY := 3
const TC_NINJA := 4
const TC_PRIEST := 5
const TC_MAGE_UNIT := 6
const TC_CANNON := 7

const ROW_FRONT := 0
const ROW_BACK := 1

# Heavy front-row types that qualify for IRON_WALL
const HEAVY_FRONT_CLASSES: Array = [TC_SAMURAI]
const HEAVY_FRONT_IDS: Array = ["knight", "ironguard", "temple_guard"]

# Ranged classes for ARROW_STORM
const RANGED_CLASSES: Array = [TC_ARCHER, TC_CANNON]

# ─── Detection: classify a single unit ───────────────────────────────────────

static func _is_heavy_front(unit: Dictionary) -> bool:
	if unit.get("row", ROW_FRONT) != ROW_FRONT:
		return false
	if unit.get("troop_class", -1) in HEAVY_FRONT_CLASSES:
		return true
	var uid := _get_unit_id_string(unit)
	for tag in HEAVY_FRONT_IDS:
		if uid.find(tag) != -1:
			return true
	# Additional keyword fallback for troop_id/unit_type strings
	return uid.find("samurai") != -1 or uid.find("guardian") != -1 or uid.find("shield") != -1

static func _get_unit_id_string(unit: Dictionary) -> String:
	return unit.get("id", unit.get("troop_id", unit.get("unit_type", ""))).to_lower()

static func _is_cavalry(unit: Dictionary) -> bool:
	if unit.get("troop_class", -1) == TC_CAVALRY:
		return true
	var uid := _get_unit_id_string(unit)
	return uid.find("cavalry") != -1 or uid.find("knight") != -1 or uid.find("rider") != -1 or uid.find("horseman") != -1

static func _is_ranged(unit: Dictionary) -> bool:
	if unit.get("troop_class", -1) in RANGED_CLASSES:
		return true
	var uid := _get_unit_id_string(unit)
	return uid.find("archer") != -1 or uid.find("cannon") != -1 or uid.find("gunner") != -1 or uid.find("bowman") != -1 or uid.find("marksman") != -1

static func _is_ninja_or_assassin(unit: Dictionary) -> bool:
	if unit.get("troop_class", -1) == TC_NINJA:
		return true
	var uid := _get_unit_id_string(unit)
	return uid.find("assassin") != -1 or uid.find("ninja") != -1 or uid.find("shinobi") != -1

static func _is_mage(unit: Dictionary) -> bool:
	if unit.get("troop_class", -1) == TC_MAGE_UNIT:
		return true
	var uid := _get_unit_id_string(unit)
	return uid.find("mage") != -1 or uid.find("wizard") != -1 or uid.find("sorcerer") != -1 or uid.find("warlock") != -1

static func _is_priest(unit: Dictionary) -> bool:
	if unit.get("troop_class", -1) == TC_PRIEST:
		return true
	var uid := _get_unit_id_string(unit)
	return uid.find("priest") != -1 or uid.find("cleric") != -1 or uid.find("monk") != -1 or uid.find("healer") != -1

static func _is_orc(unit: Dictionary) -> bool:
	return unit.get("faction", "") == "orc"

static func _is_cannon_or_gunner(unit: Dictionary) -> bool:
	if unit.get("troop_class", -1) == TC_CANNON:
		return true
	var uid := _get_unit_id_string(unit)
	return uid.find("gunner") != -1 or uid.find("cannon") != -1 or uid.find("artillery") != -1

static func _is_front(unit: Dictionary) -> bool:
	return unit.get("row", ROW_FRONT) == ROW_FRONT

static func _is_support(unit: Dictionary) -> bool:
	if unit.get("troop_class", -1) in [TC_PRIEST, TC_MAGE_UNIT]:
		return true
	return _is_mage(unit) or _is_priest(unit)

# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — detect_formations
# ═══════════════════════════════════════════════════════════════════════════════

## Analyse an army's unit list and return all matching formation IDs.
## Each unit is a Dictionary with at minimum: troop_class, row, faction, id/troop_id.
## Optional key "terrain" on any unit (or passed separately) enables terrain checks.
static func detect_formations(units: Array, terrain: String = "") -> Array:
	var result: Array = []
	if units.size() == 0:
		return result

	# ── Counts ──
	var heavy_front_count: int = 0
	var cavalry_count: int = 0
	var ranged_count: int = 0
	var ninja_count: int = 0
	var mage_count: int = 0
	var priest_count: int = 0
	var orc_count: int = 0
	var cannon_gunner_count: int = 0
	var front_count: int = 0
	var support_count: int = 0

	for u in units:
		if _is_heavy_front(u):
			heavy_front_count += 1
		if _is_cavalry(u):
			cavalry_count += 1
		if _is_ranged(u):
			ranged_count += 1
		if _is_ninja_or_assassin(u):
			ninja_count += 1
		if _is_mage(u):
			mage_count += 1
		if _is_priest(u):
			priest_count += 1
		if _is_orc(u):
			orc_count += 1
		if _is_cannon_or_gunner(u):
			cannon_gunner_count += 1
		if _is_front(u):
			front_count += 1
		if _is_support(u):
			support_count += 1

	# ── LONE_WOLF (exclusive — if exactly 1 unit, only this triggers) ──
	if units.size() == 1:
		result.append(FormationID.LONE_WOLF)
		return result

	# ── Multi-unit formations ──
	if heavy_front_count >= 3:
		result.append(FormationID.IRON_WALL)
	if cavalry_count >= 2:
		result.append(FormationID.CAVALRY_CHARGE)
	if ranged_count >= 3:
		result.append(FormationID.ARROW_STORM)
	if ninja_count >= 2:
		result.append(FormationID.SHADOW_STRIKE)
	if mage_count >= 2:
		result.append(FormationID.ARCANE_BARRAGE)
	if priest_count >= 1 and front_count >= 2:
		result.append(FormationID.HOLY_BASTION)
	if orc_count >= 4:
		result.append(FormationID.BERSERKER_HORDE)

	# PIRATE_BROADSIDE needs coastal terrain
	var is_coastal: bool = terrain in ["coastal", "harbor", "shore", "port"]
	if cannon_gunner_count >= 2 and is_coastal:
		result.append(FormationID.PIRATE_BROADSIDE)

	# BALANCED_FORCE: at least 1 front, 1 ranged, 1 support
	if front_count >= 1 and ranged_count >= 1 and support_count >= 1:
		result.append(FormationID.BALANCED_FORCE)

	return result


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — get_formation_bonuses
# ═══════════════════════════════════════════════════════════════════════════════

## Combine all detected formations into a single bonuses dictionary.
## Keys returned (all optional — consumers check with .get()):
##   atk_add, def_add, spd_add                  — flat stat adds (all units)
##   front_def_add                               — front row DEF add
##   back_damage_reduction                       — back row incoming damage mult
##   cavalry_atk_mult_r1                         — cavalry ATK mult round 1
##   cavalry_def_penalty_r1                      — cavalry DEF penalty during charge round
##   cavalry_stampede_morale                     — morale penalty if stampede triggers
##   ranged_double_attack_rounds                 — rounds where ranged attack twice
##   ranged_def_penalty                          — DEF penalty for ranged in those rounds
##   ranged_exhaustion_after_round               — after this round, ranged get SPD penalty
##   ranged_exhaustion_spd_penalty               — SPD penalty for exhausted ranged units
##   shadow_bypass_chance                        — chance to bypass front row
##   shadow_bypass_rounds                        — how many rounds bypass lasts
##   mana_regen_add                              — extra mana per round
##   aoe_damage_mult                             — AoE damage multiplier
##   heal_per_round                              — soldiers healed per round (all)
##   front_morale_loss_reduction                 — front row morale loss reduction (0.5 = 50%)
##   orc_atk_add                                 — flat ATK add for orc units
##   orc_death_atk_stack                         — ATK gained per orc death
##   orc_death_atk_stack_cap                     — max ATK from death stacking
##   ranged_atk_add                              — flat ATK add for ranged
##   siege_damage_mult                           — siege damage multiplier
##   adaptive_bonus                              — if losing, all stats get additional +1
##   lone_wolf_atk_mult, lone_wolf_def_mult      — lone wolf multipliers
##   lone_wolf_spd_add, lone_wolf_morale_immune  — lone wolf extras
static func get_formation_bonuses(formations: Array) -> Dictionary:
	var b: Dictionary = {}

	for fid in formations:
		match fid:
			FormationID.IRON_WALL:
				b["front_def_add"] = b.get("front_def_add", 0) + 3
				b["back_damage_reduction"] = minf(b.get("back_damage_reduction", 1.0), 0.5)
			FormationID.CAVALRY_CHARGE:
				b["cavalry_atk_mult_r1"] = b.get("cavalry_atk_mult_r1", 1.0) * 1.5
				b["cavalry_stampede_morale"] = b.get("cavalry_stampede_morale", 0) + 20
				b["cavalry_def_penalty_r1"] = b.get("cavalry_def_penalty_r1", 0) - 2
			FormationID.ARROW_STORM:
				b["ranged_double_attack_rounds"] = [1, 2]
				b["ranged_def_penalty"] = b.get("ranged_def_penalty", 0) - 2
				b["ranged_exhaustion_after_round"] = 2  # After round 2, ranged units get SPD-2
				b["ranged_exhaustion_spd_penalty"] = -2
			FormationID.SHADOW_STRIKE:
				b["shadow_bypass_chance"] = 0.4
				b["shadow_bypass_rounds"] = 2
			FormationID.ARCANE_BARRAGE:
				b["mana_regen_add"] = b.get("mana_regen_add", 0) + 2
				b["aoe_damage_mult"] = b.get("aoe_damage_mult", 1.0) * 1.25
			FormationID.HOLY_BASTION:
				b["heal_per_round"] = b.get("heal_per_round", 0) + 1
				b["front_morale_loss_reduction"] = 0.5  # Front row morale loss reduced by 50%
			FormationID.BERSERKER_HORDE:
				b["orc_atk_add"] = b.get("orc_atk_add", 0) + 2
				b["orc_death_atk_stack"] = 1
				b["orc_death_atk_stack_cap"] = 3  # Maximum +3 ATK from death stacking
			FormationID.PIRATE_BROADSIDE:
				b["ranged_atk_add"] = b.get("ranged_atk_add", 0) + 4
				b["siege_damage_mult"] = b.get("siege_damage_mult", 1.0) * 2.0
			FormationID.BALANCED_FORCE:
				b["atk_add"] = b.get("atk_add", 0) + 1
				b["def_add"] = b.get("def_add", 0) + 2
				b["spd_add"] = b.get("spd_add", 0) + 1
				b["adaptive_bonus"] = true  # If losing (total soldiers < enemy), all stats +1
			FormationID.LONE_WOLF:
				b["lone_wolf_atk_mult"] = 1.5
				b["lone_wolf_def_mult"] = 1.3
				b["lone_wolf_spd_add"] = 3
				b["lone_wolf_morale_immune"] = true

	return b


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — check_formation_clash
# ═══════════════════════════════════════════════════════════════════════════════

## Given attacker and defender formation lists, return clash effect overrides.
## Each clash is a Dictionary: { "effect": String, "modifiers": Dictionary }
static func check_formation_clash(atk_formations: Array, def_formations: Array) -> Dictionary:
	var clashes: Dictionary = {}

	# IRON_WALL vs CAVALRY_CHARGE
	if FormationID.IRON_WALL in def_formations and FormationID.CAVALRY_CHARGE in atk_formations:
		clashes["iron_wall_vs_cavalry"] = {
			"effect": "Cavalry charge bonus negated; cavalry take DEF counter-damage",
			"negate_cavalry_charge": true,
			"cavalry_counter_damage": true,
		}
	if FormationID.IRON_WALL in atk_formations and FormationID.CAVALRY_CHARGE in def_formations:
		clashes["iron_wall_vs_cavalry"] = {
			"effect": "Cavalry charge bonus negated; cavalry take DEF counter-damage",
			"negate_cavalry_charge": true,
			"cavalry_counter_damage": true,
		}

	# ARROW_STORM vs SHADOW_STRIKE
	if FormationID.ARROW_STORM in atk_formations and FormationID.SHADOW_STRIKE in def_formations:
		clashes["arrow_vs_shadow_def"] = {
			"effect": "Shadow units dodge 60% of ranged attacks",
			"shadow_ranged_dodge": 0.6,
		}
	if FormationID.ARROW_STORM in def_formations and FormationID.SHADOW_STRIKE in atk_formations:
		clashes["arrow_vs_shadow_atk"] = {
			"effect": "Shadow units dodge 60% of ranged attacks",
			"shadow_ranged_dodge": 0.6,
		}

	# ARCANE_BARRAGE vs HOLY_BASTION
	if FormationID.ARCANE_BARRAGE in atk_formations and FormationID.HOLY_BASTION in def_formations:
		clashes["arcane_vs_holy_def"] = {
			"effect": "Holy units resist 30% magic damage",
			"magic_damage_resist": 0.3,
		}
	if FormationID.ARCANE_BARRAGE in def_formations and FormationID.HOLY_BASTION in atk_formations:
		clashes["arcane_vs_holy_atk"] = {
			"effect": "Holy units resist 30% magic damage",
			"magic_damage_resist": 0.3,
		}

	# BERSERKER_HORDE vs IRON_WALL
	if FormationID.BERSERKER_HORDE in atk_formations and FormationID.IRON_WALL in def_formations:
		clashes["berserker_vs_iron_def"] = {
			"effect": "Berserkers ignore 50% of Iron Wall DEF bonus",
			"ignore_iron_wall_pct": 0.5,
		}
	if FormationID.BERSERKER_HORDE in def_formations and FormationID.IRON_WALL in atk_formations:
		clashes["berserker_vs_iron_atk"] = {
			"effect": "Berserkers ignore 50% of Iron Wall DEF bonus",
			"ignore_iron_wall_pct": 0.5,
		}

	return clashes


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — check_tactical_combo
# ═══════════════════════════════════════════════════════════════════════════════

## Evaluate mid-battle tactical combos.
## state Dictionary expected keys:
##   "own_units"       : Array of unit dicts (with current soldiers, max_soldiers, row, troop_class)
##   "enemy_units"     : Array of unit dicts
##   "own_has_hero"    : bool
##   "enemy_has_hero"  : bool
##   "rng"             : RandomNumberGenerator (optional — falls back to randf())
## Returns an Array of combo dicts: { "id": String, "description": String, "effects": Dictionary }
static func check_tactical_combo(state: Dictionary, round_num: int) -> Array:
	var combos: Array = []
	var own: Array = state.get("own_units", [])
	var enemy: Array = state.get("enemy_units", [])
	var rng: Variant = state.get("rng", null)

	# ── PINCER_ATTACK ──
	# Requires: own front melee + own back ranged, enemy front below 50% total HP
	var has_own_front_melee: bool = false
	var has_own_back_ranged: bool = false
	for u in own:
		if _is_front(u) and u.get("troop_class", -1) in [TC_ASHIGARU, TC_SAMURAI, TC_CAVALRY]:
			has_own_front_melee = true
		if u.get("row", ROW_FRONT) == ROW_BACK and _is_ranged(u):
			has_own_back_ranged = true

	if has_own_front_melee and has_own_back_ranged:
		var enemy_front_cur: int = 0
		var enemy_front_max: int = 0
		for u in enemy:
			if _is_front(u):
				enemy_front_cur += u.get("soldiers", u.get("current_soldiers", 0))
				enemy_front_max += u.get("max_soldiers", 1)
		if enemy_front_max > 0 and float(enemy_front_cur) / float(enemy_front_max) < 0.5:
			combos.append({
				"id": COMBO_PINCER_ATTACK,
				"description": "Pincer Attack: front melee + back ranged exploit weakened enemy front — all ATK +20% for 1 round",
				"effects": {"atk_mult": 1.2, "duration": 1},
			})

	# ── DESPERATE_STAND ──
	# Triggers when own total soldiers <= 30% of max
	var own_cur: int = 0
	var own_max: int = 0
	for u in own:
		own_cur += u.get("soldiers", u.get("current_soldiers", 0))
		own_max += u.get("max_soldiers", 1)
	if own_max > 0 and float(own_cur) / float(own_max) <= 0.3:
		combos.append({
			"id": COMBO_DESPERATE_STAND,
			"description": "Desperate Stand: army at critical strength — all DEF +5, counter-attack x1.5",
			"effects": {"def_add": 5, "counter_mult": 1.5},
		})

	# ── COMMANDER_DUEL ──
	# 20% chance per round if both sides have a hero
	var own_hero: bool = state.get("own_has_hero", false)
	var enemy_hero: bool = state.get("enemy_has_hero", false)
	if own_hero and enemy_hero:
		var roll: float = rng.randf() if rng else randf()
		if roll < 0.2:
			# Outcome is 50/50 — caller resolves with their own RNG
			combos.append({
				"id": COMBO_COMMANDER_DUEL,
				"description": "Commander Duel: heroes clash — winner's army morale +15, loser's -15",
				"effects": {"winner_morale": 15, "loser_morale": -15},
			})

	return combos


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — apply_formation_to_units
# ═══════════════════════════════════════════════════════════════════════════════

## Modify unit stat fields in-place based on combined bonuses dictionary
## (from get_formation_bonuses).  Works on the same unit dicts used by
## combat_resolver — mutates "base_atk", "base_def", and optionally "spd".
## Round-dependent or conditional bonuses (cavalry round 1, orc death stacks)
## are NOT applied here — they are consumed by combat_resolver each round.
static func apply_formation_to_units(units: Array, bonuses: Dictionary) -> void:
	var global_atk: int = bonuses.get("atk_add", 0)
	var global_def: int = bonuses.get("def_add", 0)
	var global_spd: int = bonuses.get("spd_add", 0)
	var front_def: int = bonuses.get("front_def_add", 0)
	var ranged_def_pen: int = bonuses.get("ranged_def_penalty", 0)
	var orc_atk: int = bonuses.get("orc_atk_add", 0)
	var ranged_atk: int = bonuses.get("ranged_atk_add", 0)

	# Lone wolf multipliers (only when exactly 1 unit)
	var lw_atk: float = bonuses.get("lone_wolf_atk_mult", 1.0)
	var lw_def: float = bonuses.get("lone_wolf_def_mult", 1.0)
	var lw_spd: int = bonuses.get("lone_wolf_spd_add", 0)

	for u in units:
		var atk_mod: int = global_atk
		var def_mod: int = global_def
		var spd_mod: int = global_spd

		# Row-specific
		if _is_front(u):
			def_mod += front_def
		if _is_ranged(u):
			def_mod += ranged_def_pen
			atk_mod += ranged_atk
		if _is_orc(u):
			atk_mod += orc_atk

		# Apply flat mods first
		u["base_atk"] = u.get("base_atk", 0) + atk_mod
		u["base_def"] = maxi(0, u.get("base_def", 0) + def_mod)
		if u.has("spd"):
			u["spd"] = u.get("spd", 0) + spd_mod

		# Lone Wolf multiplicative (applied after additive)
		if lw_atk != 1.0:
			u["base_atk"] = int(float(u["base_atk"]) * lw_atk)
		if lw_def != 1.0:
			u["base_def"] = int(float(u["base_def"]) * lw_def)
		if lw_spd != 0 and u.has("spd"):
			u["spd"] = u.get("spd", 0) + lw_spd

	# Store bonuses reference on each unit for round-based lookups
	for u in units:
		u["_formation_bonuses"] = bonuses


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL EMISSION HELPERS
# ═══════════════════════════════════════════════════════════════════════════════
# These are static convenience methods that emit on EventBus (the autoload).
# The caller (combat_resolver) should invoke them after detection/clash/combo.

## Emit formation_detected for each formation in the list.
static func emit_formation_detected(side: String, formations: Array) -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
	for fid in formations:
		var fname: String = FORMATION_NAMES.get(fid, "Unknown")
		bus.formation_detected.emit(side, fid, fname)

## Emit formation_clash for each clash entry.
static func emit_formation_clashes(clashes: Dictionary) -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
	for key in clashes:
		var c: Dictionary = clashes[key]
		# Determine atk/def formation IDs from the key name
		bus.formation_clash.emit(-1, -1, c.get("effect", key))

## Emit tactical_combo_triggered for each triggered combo.
static func emit_tactical_combos(combos: Array) -> void:
	var bus: Node = _get_event_bus()
	if bus == null:
		return
	for combo in combos:
		bus.tactical_combo_triggered.emit(combo["id"], combo["description"])

## Safely fetch the EventBus autoload (returns null outside SceneTree).
static func _get_event_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/EventBus")


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — get_formation_description_cn
# ═══════════════════════════════════════════════════════════════════════════════

## Returns a Chinese description of a formation's requirements and effects for UI display.
static func get_formation_description_cn(formation_id: int) -> String:
	match formation_id:
		FormationID.IRON_WALL:
			return "【铁壁阵】需要3个以上重装前排单位。效果：前排防御+3，后排受伤减半。"
		FormationID.CAVALRY_CHARGE:
			return "【骑兵冲锋】需要2个以上骑兵单位。效果：第1回合骑兵攻击+50%，敌方士气-20。代价：冲锋回合骑兵防御-2。"
		FormationID.ARROW_STORM:
			return "【箭雨阵】需要3个以上远程单位。效果：前2回合远程单位攻击两次，防御-2。代价：第2回合后远程单位疲劳，速度-2持续至战斗结束。"
		FormationID.SHADOW_STRIKE:
			return "【影袭阵】需要2个以上忍者/刺客单位。效果：前2回合40%概率绕过前排直击后排。"
		FormationID.ARCANE_BARRAGE:
			return "【奥术轰炸】需要2个以上法师单位。效果：每回合法力回复+2，范围伤害+25%。"
		FormationID.HOLY_BASTION:
			return "【圣域阵】需要至少1个牧师和2个前排单位。效果：每回合回复1名士兵，前排士气损失减少50%。"
		FormationID.BERSERKER_HORDE:
			return "【狂暴部落】需要4个以上兽人单位。效果：兽人攻击+2，每有兽人阵亡全队攻击+1（上限+3）。"
		FormationID.PIRATE_BROADSIDE:
			return "【海盗齐射】需要2个以上炮手/火枪手且在沿海地形。效果：远程攻击+4，攻城伤害翻倍。"
		FormationID.BALANCED_FORCE:
			return "【均衡阵容】需要至少1个前排、1个远程、1个辅助单位。效果：攻击+1，防御+2，速度+1。自适应：若总兵力少于敌方，全属性额外+1。"
		FormationID.LONE_WOLF:
			return "【独狼】仅部署1个单位时自动触发。效果：攻击x1.5，防御x1.3，速度+3，免疫士气崩溃。"
	return "未知阵型"
