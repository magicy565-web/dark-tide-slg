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

		# FIX(MAJOR): zero_food优先于regen处理，防止regen+zero_food净值为零导致软锁
		# zero_food先扣兵，之后regen仅在兵力>0时才生效
		if passive == "zero_food":
			troop["soldiers"] -= 1
			food_saved += GameData.TIER_UPKEEP.get(td.get("tier", 1), 0)
			if troop["soldiers"] <= 0:
				details.append("%s 不死之军 — 兵力归零, 部队消散" % td.get("name", troop["troop_id"]))
				army.remove_at(i)
				i -= 1
				continue
			else:
				details.append("%s 不死之军 -1兵 (剩余%d)" % [td.get("name", troop["troop_id"]), troop["soldiers"]])

		elif passive == "regen_1":
			if troop["soldiers"] > 0 and troop["soldiers"] < troop["max_soldiers"]:
				troop["soldiers"] += 1
				details.append("%s 再生 +1兵" % td.get("name", troop["troop_id"]))

		elif passive == "regen_2":
			if troop["soldiers"] > 0:
				var heal: int = mini(2, troop["max_soldiers"] - troop["soldiers"])
				if heal > 0:
					troop["soldiers"] += heal
					details.append("%s 深根再生 +%d兵" % [td.get("name", troop["troop_id"]), heal])

		elif passive == "necro_summon":
			# Cap skeleton squads: max 3 necro-summoned skeletons per army
			var skeleton_count: int = 0
			for t in army:
				if t["troop_id"] == "neutral_skeleton":
					skeleton_count += 1
			if skeleton_count < 3:
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
			ResourceManager.apply_delta(player_id, {"mana": 1})
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
			continue
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


# ---------------------------------------------------------------------------
# Movement Passives
# ---------------------------------------------------------------------------

## Conscript passive: when passing through a friendly-owned tile, +1 soldier to troops with conscript.
## Called from movement system when a troop enters a new tile.
func apply_conscript_bonus(player_id: int, tile_index: int) -> Array:
	var details: Array = []
	var army: Array = RecruitManager._get_army_ref(player_id)
	# Check if tile is owned by the player
	# BUG FIX: LightFactionAI.get_tile_owner() doesn't exist. Read owner_id
	# directly from GameManager.tiles instead.
	var tile_owner: int = -1
	if tile_index >= 0 and tile_index < GameManager.tiles.size():
		tile_owner = GameManager.tiles[tile_index].get("owner_id", -1)
	if tile_owner != player_id:
		return details
	for troop in army:
		var td: Dictionary = GameData.get_troop_def(troop["troop_id"])
		var passive: String = td.get("passive", "")
		if passive == "conscript":
			if troop["soldiers"] < troop["max_soldiers"]:
				troop["soldiers"] += 1
				details.append("%s 征召 +1兵 (剩余%d)" % [td.get("name", troop["troop_id"]), troop["soldiers"]])
	if not details.is_empty():
		RecruitManager._sync_army_count(player_id)
	return details


# ---------------------------------------------------------------------------
# Enchantment Passive Processing (v6.0)
# ---------------------------------------------------------------------------

## Process enchantment effects after an attack action.
## Called from combat resolver after damage is calculated.
## Returns modified action_result with enchantment_effects populated.
func process_enchantment_passive(hero_id: String, action_result: Dictionary) -> Dictionary:
	if hero_id.is_empty():
		return action_result
	return EnchantmentSystem.apply_enchantment_in_combat(hero_id, action_result)


## Apply burn debuff damage at start of round for units with burn.
func tick_burn_debuffs(units: Array, combat_log: Array) -> void:
	for unit in units:
		if not unit.get("is_alive", false):
			continue
		var burn_found: bool = false
		for debuff in unit.get("debuffs", []):
			if debuff.get("id", "") == "burn":
				burn_found = true
				break
		if burn_found:
			var burn_dmg: int = 1
			unit["soldiers"] = maxi(0, unit["soldiers"] - burn_dmg)
			if unit["soldiers"] <= 0:
				unit["is_alive"] = false
			combat_log.append("%s [%s] 灼烧伤害 -%d兵" % [unit.get("unit_type", ""), unit.get("side", ""), burn_dmg])


## Apply slow debuff (reduce SPD) for units with slow.
func apply_slow_debuffs(units: Array) -> void:
	for unit in units:
		if not unit.get("is_alive", false):
			continue
		for debuff in unit.get("debuffs", []):
			if debuff.get("id", "") == "slow" and not debuff.get("_applied", false):
				unit["spd"] = maxf(unit.get("spd", 5.0) - 2.0, 1.0)
				debuff["_applied"] = true
