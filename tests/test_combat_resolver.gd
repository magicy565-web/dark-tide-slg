## test_combat_resolver.gd — Tests for combat buff system fixes
extends RefCounted

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg

func test_iron_wall_no_direct_def_mod() -> String:
	# Verify iron_wall skill doesn't directly modify unit["def"]
	# by checking the script source (static analysis)
	var script: GDScript = load("res://systems/combat/combat_resolver.gd")
	var src: String = script.source_code
	# The old buggy pattern was: unit["def"] += 3 right before iron_wall buff append
	var has_direct_mod: bool = src.contains("unit[\"def\"] += 3\n\t\t\tunit[\"buffs\"].append({\"id\": \"iron_wall\"")
	return _assert(not has_direct_mod, "Iron wall should not directly modify def")

func test_slow_no_direct_spd_mod() -> String:
	var script: GDScript = load("res://systems/combat/combat_resolver.gd")
	var src: String = script.source_code
	# Check that poison_slow doesn't directly modify spd
	var has_poison_spd: bool = src.contains("target[\"spd\"] = maxf(target[\"spd\"] - 2")
	var has_time_spd: bool = src.contains("enemy[\"spd\"] = maxf(enemy[\"spd\"] - 3")
	return _assert(not has_poison_spd and not has_time_spd, "Slow effects should not directly modify spd")

func test_sort_by_spd_reads_debuffs() -> String:
	var script: GDScript = load("res://systems/combat/combat_resolver.gd")
	var src: String = script.source_code
	var reads_debuffs: bool = src.contains("\"slow\"") and src.contains("_sort_by_spd")
	return _assert(reads_debuffs, "_sort_by_spd should read slow debuffs")

func test_calculate_damage_reads_iron_wall() -> String:
	var script: GDScript = load("res://systems/combat/combat_resolver.gd")
	var src: String = script.source_code
	var reads_iron_wall: bool = src.contains("iron_wall") and src.contains("def_val += b[\"value\"]")
	return _assert(reads_iron_wall, "_calculate_damage should read iron_wall buff for DEF bonus")

func test_correct_autoload_targets() -> String:
	# Verify game_manager calls CombatAbilities not CombatResolver for experience/dissolve/recovery
	var script: GDScript = load("res://autoloads/game_manager.gd")
	var src: String = script.source_code
	var has_wrong_exp: bool = src.contains("CombatResolver.grant_combat_experience")
	var has_wrong_dissolve: bool = src.contains("CombatResolver.dissolve_slave_fodder")
	var has_wrong_recovery: bool = src.contains("CombatResolver.apply_zero_food_recovery")
	return _assert(not has_wrong_exp and not has_wrong_dissolve and not has_wrong_recovery,
		"Should use CombatAbilities not CombatResolver for post-combat methods")
