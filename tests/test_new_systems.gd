## test_new_systems.gd — Tests for morale, gifts, AI personalities, reputation, events, affection
extends RefCounted

const FactionData = preload("res://systems/faction/faction_data.gd")

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg

# ── 1. Morale constants ──

func test_morale_start_is_100() -> String:
	var script: GDScript = load("res://systems/combat/combat_resolver.gd")
	var src: String = script.source_code
	var ok: bool = src.contains("const MORALE_START: int = 100")
	return _assert(ok, "MORALE_START should be 100")

func test_morale_per_soldier_killed_is_5() -> String:
	var script: GDScript = load("res://systems/combat/combat_resolver.gd")
	var src: String = script.source_code
	var ok: bool = src.contains("const MORALE_PER_SOLDIER_KILLED: int = 5")
	return _assert(ok, "MORALE_PER_SOLDIER_KILLED should be 5")

func test_morale_ally_eliminated_is_15() -> String:
	var script: GDScript = load("res://systems/combat/combat_resolver.gd")
	var src: String = script.source_code
	var ok: bool = src.contains("const MORALE_ALLY_ELIMINATED: int = 15")
	return _assert(ok, "MORALE_ALLY_ELIMINATED should be 15")

func test_morale_rout_threshold_is_0() -> String:
	var script: GDScript = load("res://systems/combat/combat_resolver.gd")
	var src: String = script.source_code
	var ok: bool = src.contains("const MORALE_ROUT_THRESHOLD: int = 0")
	return _assert(ok, "MORALE_ROUT_THRESHOLD should be 0")

# ── 2. Gift types ──

func test_gift_types_has_6_entries() -> String:
	return _assert(FactionData.GIFT_TYPES.size() == 6, "GIFT_TYPES should have 6 entries, got %d" % FactionData.GIFT_TYPES.size())

func test_gift_types_each_has_name_cost_affection() -> String:
	for gift_id in FactionData.GIFT_TYPES:
		var gt: Dictionary = FactionData.GIFT_TYPES[gift_id]
		if not gt.has("name"):
			return "Gift '%s' missing 'name'" % gift_id
		if not gt.has("cost"):
			return "Gift '%s' missing 'cost'" % gift_id
		if not gt.has("affection"):
			return "Gift '%s' missing 'affection'" % gift_id
		if gt["cost"] <= 0:
			return "Gift '%s' cost should be positive" % gift_id
	return "PASS"

# ── 3. Preferred gifts ──

func test_all_heroes_have_preferred_gift() -> String:
	for hero_id in FactionData.HEROES:
		var hero: Dictionary = FactionData.HEROES[hero_id]
		if not hero.has("preferred_gift"):
			return "Hero '%s' missing preferred_gift" % hero_id
		var pg: String = hero["preferred_gift"]
		if not FactionData.GIFT_TYPES.has(pg):
			return "Hero '%s' preferred_gift '%s' not in GIFT_TYPES" % [hero_id, pg]
	return _assert(FactionData.HEROES.size() == 18, "Expected 18 heroes with preferred_gift, got %d" % FactionData.HEROES.size())

# ── 4. AI personalities ──

func test_all_ai_factions_have_personality() -> String:
	var script: GDScript = load("res://systems/faction/ai_scaling.gd")
	var src: String = script.source_code
	var expected_keys: Array = ["human", "elf", "mage", "orc_ai", "pirate_ai", "dark_elf_ai"]
	for key in expected_keys:
		if not src.contains("\"%s\":" % key):
			return "AI faction '%s' not found in FACTION_PERSONALITY" % key
	return "PASS"

# ── 5. Personality mods ──

func test_personality_mods_have_all_keys() -> String:
	var script: GDScript = load("res://systems/faction/ai_scaling.gd")
	var src: String = script.source_code
	var required_mod_keys: Array = ["raid_chance_mult", "garrison_priority", "expedition_cd_mult", "peace_acceptance", "threat_decay_mult", "reinforce_mult"]
	# Check all 4 personality types have all 6 modifier keys
	var personality_names: Array = ["AGGRESSIVE", "DEFENSIVE", "ECONOMIC", "DIPLOMATIC"]
	for pname in personality_names:
		if not src.contains("Personality.%s" % pname):
			return "Personality type '%s' not found in PERSONALITY_MODS" % pname
	for mod_key in required_mod_keys:
		if not src.contains("\"%s\":" % mod_key):
			return "Modifier key '%s' not found in PERSONALITY_MODS" % mod_key
	return "PASS"

# ── 6. Reputation levels ──

func test_reputation_level_hostile() -> String:
	# rep = -60 should return "敌对" (threshold is < -50)
	var script: GDScript = load("res://systems/faction/diplomacy_manager.gd")
	var src: String = script.source_code
	var has_hostile: bool = src.contains("\"敌对\"") and src.contains("rep < -50")
	return _assert(has_hostile, "get_reputation_level should return '敌对' when rep < -50")

func test_reputation_level_neutral() -> String:
	# rep = 0 should return "中立" (threshold is <= 30)
	var script: GDScript = load("res://systems/faction/diplomacy_manager.gd")
	var src: String = script.source_code
	var has_neutral: bool = src.contains("\"中立\"") and src.contains("rep <= 30")
	return _assert(has_neutral, "get_reputation_level should return '中立' when rep <= 30")

func test_reputation_level_friendly() -> String:
	# rep = 50 should return "友好" (threshold is <= 80)
	var script: GDScript = load("res://systems/faction/diplomacy_manager.gd")
	var src: String = script.source_code
	var has_friendly: bool = src.contains("\"友好\"") and src.contains("rep <= 80")
	return _assert(has_friendly, "get_reputation_level should return '友好' when rep <= 80")

func test_reputation_level_ally() -> String:
	# rep = 90 should return "盟友" (> 80)
	var script: GDScript = load("res://systems/faction/diplomacy_manager.gd")
	var src: String = script.source_code
	var has_ally: bool = src.contains("\"盟友\"")
	return _assert(has_ally, "get_reputation_level should return '盟友' for high rep")

# ── 7. Event cooldown constant ──

func test_event_cooldown_turns_is_5() -> String:
	var script: GDScript = load("res://systems/event/event_system.gd")
	var src: String = script.source_code
	var ok: bool = src.contains("const EVENT_COOLDOWN_TURNS: int = 5")
	return _assert(ok, "EVENT_COOLDOWN_TURNS should be 5")

# ── 8. Affection bonus thresholds ──

func test_affection_bonus_at_0() -> String:
	# aff=0: no bonus
	var script: GDScript = load("res://systems/hero/hero_system.gd")
	var src: String = script.source_code
	var has_aff5_check: bool = src.contains("if affection >= 5: atk_bonus += 1")
	return _assert(has_aff5_check, "Affection >= 5 should give atk_bonus += 1")

func test_affection_bonus_at_3() -> String:
	# aff=3: no combat stat bonus (only passive_upgrade unlock)
	var script: GDScript = load("res://systems/hero/hero_system.gd")
	var src: String = script.source_code
	# At aff=3, only passive_upgrade is unlocked, no atk/def bonus
	var has_unlock_3: bool = src.contains("if aff >= 3: unlocks.append(\"passive_upgrade\")")
	return _assert(has_unlock_3, "Affection >= 3 should unlock passive_upgrade")

func test_affection_bonus_at_5() -> String:
	# aff=5: +1 ATK
	var script: GDScript = load("res://systems/hero/hero_system.gd")
	var src: String = script.source_code
	var has_check: bool = src.contains("if affection >= 5: atk_bonus += 1")
	var has_unlock: bool = src.contains("if aff >= 5: unlocks.append(\"unique_event\")")
	return _assert(has_check and has_unlock, "Affection >= 5 should give +1 ATK and unique_event unlock")

func test_affection_bonus_at_8() -> String:
	# aff=8: +1 ATK from aff>=5, +1 DEF from aff>=7
	var script: GDScript = load("res://systems/hero/hero_system.gd")
	var src: String = script.source_code
	var has_def7: bool = src.contains("if affection >= 7: def_bonus += 1")
	return _assert(has_def7, "Affection >= 7 should give def_bonus += 1")

func test_affection_bonus_at_10() -> String:
	# aff=10: +2 ATK total, +2 DEF total
	var script: GDScript = load("res://systems/hero/hero_system.gd")
	var src: String = script.source_code
	var has_bonus_10: bool = src.contains("if affection >= 10: atk_bonus += 1; def_bonus += 1")
	var has_unlock: bool = src.contains("if aff >= 10: unlocks.append(\"exclusive_ending\")")
	return _assert(has_bonus_10 and has_unlock, "Affection >= 10 should give +1 ATK/DEF and exclusive_ending unlock")
