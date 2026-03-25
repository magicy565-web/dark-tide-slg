## test_faction_data.gd — Tests for FactionData integrity
extends RefCounted

const FD = preload("res://systems/faction/faction_data.gd")

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg

func test_faction_ids_exist() -> String:
	return _assert(FD.FactionID.ORC >= 0 and FD.FactionID.PIRATE >= 0 and FD.FactionID.DARK_ELF >= 0, "Faction IDs should exist")

func test_faction_params_complete() -> String:
	for fid in [FD.FactionID.ORC, FD.FactionID.PIRATE, FD.FactionID.DARK_ELF]:
		if not FD.FACTION_PARAMS.has(fid):
			return "Missing FACTION_PARAMS for faction %d" % fid
	return "PASS"

func test_heroes_not_empty() -> String:
	return _assert(not FD.HEROES.is_empty(), "HEROES should not be empty")

func test_heroes_have_names() -> String:
	for hid in FD.HEROES:
		if not FD.HEROES[hid].has("name"):
			return "Hero %s missing name" % hid
	return "PASS"

func test_equipment_defs_mutable() -> String:
	# EQUIPMENT_DEFS should be static var (not const) so quest rewards can register items
	FD.EQUIPMENT_DEFS["_test_item"] = {"name": "test"}
	var ok: bool = FD.EQUIPMENT_DEFS.has("_test_item")
	FD.EQUIPMENT_DEFS.erase("_test_item")
	return _assert(ok, "EQUIPMENT_DEFS should be mutable (static var)")

func test_neutral_faction_names() -> String:
	return _assert(not FD.NEUTRAL_FACTION_NAMES.is_empty(), "NEUTRAL_FACTION_NAMES should not be empty")

func test_terrain_data_exists() -> String:
	return _assert(FD.TERRAIN_DATA.size() > 0, "TERRAIN_DATA should have entries")

func test_terrain_type_enum() -> String:
	return _assert(FD.TerrainType.PLAINS == 0, "PLAINS should be 0")

func test_faction_colors_exist() -> String:
	return _assert(FD.FACTION_COLORS.size() >= 3, "Should have at least 3 faction colors")
