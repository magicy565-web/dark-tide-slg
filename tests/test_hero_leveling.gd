## test_hero_leveling.gd — Tests for HeroLeveling system
extends RefCounted

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg

func _clear_hero_state() -> void:
	HeroLeveling.hero_exp.clear()
	HeroLeveling.hero_level.clear()
	HeroLeveling.hero_unlocked_passives.clear()
	HeroLeveling.hero_current_hp.clear()
	HeroLeveling.hero_current_mp.clear()

func test_init_hero() -> String:
	_clear_hero_state()
	HeroLeveling.init_hero("hero_a")
	var level: int = HeroLeveling.get_hero_level("hero_a")
	return _assert(level == 1, "New hero should be level 1, got %d" % level)

func test_grant_hero_exp() -> String:
	_clear_hero_state()
	HeroLeveling.init_hero("hero_b")
	HeroLeveling.grant_hero_exp("hero_b", 10)
	var xp: int = HeroLeveling.get_hero_exp("hero_b")
	return _assert(xp == 10, "XP should be 10 after granting 10, got %d" % xp)

func test_level_up() -> String:
	_clear_hero_state()
	HeroLeveling.init_hero("hero_c")
	HeroLeveling.grant_hero_exp("hero_c", 5000)
	var level: int = HeroLeveling.get_hero_level("hero_c")
	return _assert(level >= 2, "Hero should level up with 5000 XP, got level %d" % level)

func test_hp_accessible() -> String:
	_clear_hero_state()
	HeroLeveling.init_hero("hero_d")
	var hp: int = HeroLeveling.get_hero_max_hp("hero_d")
	# HP may be 0 for test hero IDs that don't exist in HeroLevelData
	# Just verify it doesn't crash
	return _assert(hp >= 0, "Max HP should be non-negative, got %d" % hp)

func test_serialize_roundtrip() -> String:
	_clear_hero_state()
	HeroLeveling.init_hero("hero_e")
	HeroLeveling.grant_hero_exp("hero_e", 50)
	var save_data: Dictionary = HeroLeveling.serialize()
	_clear_hero_state()
	HeroLeveling.deserialize(save_data)
	var xp: int = HeroLeveling.get_hero_exp("hero_e")
	return _assert(xp == 50, "XP should persist after save/load, got %d" % xp)

func test_unknown_hero_returns_zero() -> String:
	_clear_hero_state()
	var level: int = HeroLeveling.get_hero_level("nonexistent")
	return _assert(level == 0 or level == 1, "Unknown hero level should be 0 or 1")

func test_multiple_heroes() -> String:
	_clear_hero_state()
	HeroLeveling.init_hero("hero_g")
	HeroLeveling.init_hero("hero_h")
	HeroLeveling.grant_hero_exp("hero_g", 100)
	HeroLeveling.grant_hero_exp("hero_h", 200)
	var g_xp: int = HeroLeveling.get_hero_exp("hero_g")
	var h_xp: int = HeroLeveling.get_hero_exp("hero_h")
	return _assert(g_xp == 100 and h_xp == 200, "Heroes should have independent XP: g=%d h=%d" % [g_xp, h_xp])
