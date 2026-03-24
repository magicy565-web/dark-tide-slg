## combat_abilities.gd — Per-round passive ticks, experience, and army recovery helpers.
## Split from combat_resolver.gd to reduce coupling and file size.
## Autoload: CombatAbilities
extends Node


# ---------------------------------------------------------------------------
# Per-round passive ticks (called between turns by game_manager)
# ---------------------------------------------------------------------------

## Applies per-round passives to a player's army. Call once per turn.
## Returns { "details": Array[String], "food_cost_reduction": int }
func tick_per_round_passives(player_id: int) -> Dictionary:
	var details: Array = []
	var food_saved: int = 0
	var army: Array = RecruitManager._get_army_ref(player_id)

	var i: int = army.size() - 1
	while i >= 0:
		var troop: Dictionary = army[i]
		var td: Dictionary = GameData.get_troop_def(troop["troop_id"])
		var passive: String = td.get("passive", "")

		if passive == "regen_1":
			if troop["soldiers"] < troop["max_soldiers"]:
				troop["soldiers"] += 1
				details.append("%s 再生 +1兵" % td.get("name", troop["troop_id"]))

		elif passive == "regen_2":
			var heal: int = mini(2, troop["max_soldiers"] - troop["soldiers"])
			if heal > 0:
				troop["soldiers"] += heal
				details.append("%s 深根再生 +%d兵" % [td.get("name", troop["troop_id"]), heal])

		elif passive == "zero_food":
			troop["soldiers"] -= 1
			food_saved += GameData.TIER_UPKEEP.get(td.get("tier", 1), 0)
			if troop["soldiers"] <= 0:
				details.append("%s 不死之军 — 兵力归零, 部队消散" % td.get("name", troop["troop_id"]))
				army.remove_at(i)
				i -= 1
				continue
			else:
				details.append("%s 不死之军 -1兵 (剩余%d)" % [td.get("name", troop["troop_id"]), troop["soldiers"]])

		elif passive == "necro_summon":
			var skel_inst: Dictionary = GameData.create_troop_instance("neutral_skeleton", 4)
			if not skel_inst.is_empty():
				army.append(skel_inst)
				details.append("%s 亡灵召唤: +1骷髅小队(4兵)" % td.get("name", troop["troop_id"]))

		elif passive == "self_destruct_20" or passive == "misfire":
			var chance: float = 0.2 if passive == "self_destruct_20" else 0.15
			if randf() < chance:
				troop["soldiers"] -= 1
				var pname: String = "自爆" if passive == "self_destruct_20" else "不稳定"
				if troop["soldiers"] <= 0:
					details.append("%s %s — 部队全灭!" % [td.get("name", troop["troop_id"]), pname])
					army.remove_at(i)
					i -= 1
					continue
				else:
					details.append("%s %s -1兵" % [td.get("name", troop["troop_id"]), pname])

		elif passive == "charge_mana_1":
			ResourceManager.add_resource(player_id, "mana", 1)
			details.append("%s 法力充能 +1法力" % td.get("name", troop["troop_id"]))

		# Reset ability_used flag for next battle
		troop["ability_used"] = false

		i -= 1

	RecruitManager._sync_army_count(player_id)
	return {"details": details, "food_cost_reduction": food_saved}


# ---------------------------------------------------------------------------
# Post-combat army management
# ---------------------------------------------------------------------------

## Grants post-combat experience to all surviving troops in a player's army.
func grant_combat_experience(player_id: int, exp_amount: int) -> void:
	var army: Array = RecruitManager._get_army_ref(player_id)
	for troop in army:
		GameData.grant_experience(troop, exp_amount)


## Apply zero_food victory recovery (+2 soldiers to undead units).
func apply_zero_food_recovery(player_id: int) -> void:
	var army: Array = RecruitManager._get_army_ref(player_id)
	for troop in army:
		var td: Dictionary = GameData.get_troop_def(troop["troop_id"])
		if td.get("passive", "") == "zero_food":
			troop["soldiers"] = mini(troop["soldiers"] + 2, troop["max_soldiers"])


## Remove all slave_fodder troops from a player's army (post-combat dissolve).
func dissolve_slave_fodder(player_id: int) -> void:
	var army: Array = RecruitManager._get_army_ref(player_id)
	var i: int = army.size() - 1
	while i >= 0:
		var td: Dictionary = GameData.get_troop_def(army[i]["troop_id"])
		if td.get("passive", "") == "slave_fodder":
			army.remove_at(i)
		i -= 1
	RecruitManager._sync_army_count(player_id)


# ---------------------------------------------------------------------------
# Morale System (design doc §7, §3)
# ---------------------------------------------------------------------------
# Morale range: 0-100. Affects combat effectiveness and retreat behavior.
# Veterancy grants morale bonuses: 历战+5, 精锐+10, 百战+15, 无双+20.
# Blood Moon berserker: <30%HP can't retreat.
# At morale 0: unit routs and is removed from combat.

var _morale: Dictionary = {}  # player_id -> { troop_index -> int }

func init_morale(player_id: int) -> void:
	_morale[player_id] = {}

func reset_morale() -> void:
	_morale.clear()

## Calculate starting morale for a troop based on veterancy and faction.
func get_base_morale(troop: Dictionary) -> int:
	var base: int = 50
	# Veterancy bonus
	var vet_bonuses: Dictionary = GameData.get_veterancy_bonuses(troop.get("experience", 0))
	var vet_label: String = vet_bonuses.get("label", "")
	match vet_label:
		"历战": base += 5
		"精锐": base += 10
		"百战": base += 15
		"无双": base += 20
	# WAAAGH! morale immunity at tier 2+ (60+)
	return clampi(base, 0, 100)

## Apply morale change from combat result.
## Returns true if unit routs (morale <= 0).
func apply_morale_change(troop: Dictionary, delta: int) -> bool:
	var current: int = troop.get("_morale", 50)
	current = clampi(current + delta, 0, 100)
	troop["_morale"] = current
	# Blood moon berserker: cannot retreat
	var td: Dictionary = GameData.get_troop_def(troop.get("troop_id", ""))
	if td.get("passive", "") == "blood_triple":
		return false  # Never routs
	# 百战+ never flees
	var vet: Dictionary = GameData.get_veterancy_bonuses(troop.get("experience", 0))
	if vet.get("label", "") in ["百战", "无双"]:
		return false
	return current <= 0

## Apply morale effects to combat units before power calculation.
## Low morale reduces effective power; high morale gives a bonus.
func apply_morale_modifier(units: Array) -> float:
	if units.is_empty():
		return 1.0
	var total_morale: float = 0.0
	for unit in units:
		total_morale += float(unit.get("_morale", 50))
	var avg_morale: float = total_morale / float(units.size())
	# Morale modifier: 50 = 1.0x, 0 = 0.6x, 100 = 1.15x
	# FIX(CRITICAL): 修正系数0.0055→0.008，使50士气正确返回1.0倍率（原公式50士气仅0.875x）
	return clampf(0.6 + avg_morale * 0.008, 0.6, 1.15)

## Set initial morale on combat units before battle starts.
func prepare_combat_morale(units: Array, player_id: int) -> void:
	for unit in units:
		if not unit.has("_morale"):
			unit["_morale"] = get_base_morale(unit)
	# WAAAGH! tier 2+ (60-89): immune to morale collapse
	var w: int = OrcMechanic.get_waaagh(player_id)
	if w >= 60:
		for unit in units:
			unit["_morale"] = maxi(unit.get("_morale", 50), 30)  # Floor at 30

## After combat: apply morale changes based on result.
func post_combat_morale(units: Array, won: bool, losses_pct: float) -> void:
	var delta: int
	if won:
		delta = 10 - int(losses_pct * 15)  # Win with low losses = +10, heavy losses = less
	else:
		delta = -15 - int(losses_pct * 20)  # Loss = -15 to -35
	for unit in units:
		apply_morale_change(unit, delta)
