## test_save_migration.gd — Tests for save version compatibility and migration logic
extends RefCounted

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg


## Replicates the version compatibility and migration logic from save_manager.gd
## so we can test it in isolation without autoloads or file I/O.
class MigrationHelper extends RefCounted:
	const SAVE_VERSION: String = "4.1.0"

	func _is_version_compatible(saved_ver: String) -> bool:
		var saved_parts: Array = saved_ver.split(".")
		var current_parts: Array = SAVE_VERSION.split(".")
		if saved_parts.size() < 2 or current_parts.size() < 2:
			return false
		return saved_parts[0] == current_parts[0]

	func _migrate_save_data(data: Dictionary, saved_version: String) -> Dictionary:
		var parts: Array = saved_version.split(".")
		var major: int = int(parts[0]) if parts.size() > 0 else 0
		var minor: int = int(parts[1]) if parts.size() > 1 else 0

		# v3.x -> v4.0 migration
		if major == 3:
			data = _migrate_3_to_4(data)
			major = 4
			minor = 0

		# v4.0 -> v4.1 migration
		if major == 4 and minor < 1:
			data = _migrate_4_0_to_4_1(data)

		return data

	func _migrate_3_to_4(data: Dictionary) -> Dictionary:
		## Add v4.0 keys that didn't exist in v3.x saves.
		if not data.has("faction_destruction_events"):
			data["faction_destruction_events"] = {}
		if not data.has("seasonal_events"):
			data["seasonal_events"] = {}
		if not data.has("character_interaction_events"):
			data["character_interaction_events"] = {}
		if not data.has("grand_event_director"):
			data["grand_event_director"] = {}
		if not data.has("dynamic_situation_events"):
			data["dynamic_situation_events"] = {}
		if not data.has("crisis_countdown"):
			data["crisis_countdown"] = {}
		if not data.has("nation_system"):
			data["nation_system"] = {}
		# Ensure meta version is updated
		if not data.has("meta"):
			data["meta"] = {}
		data["meta"]["version"] = "4.0.0"
		return data

	func _migrate_4_0_to_4_1(data: Dictionary) -> Dictionary:
		## Add v4.1 centralized systems keys.
		if not data.has("event_registry"):
			data["event_registry"] = {}
		if not data.has("quest_progress_tracker"):
			data["quest_progress_tracker"] = {}
		if not data.has("event_scheduler"):
			data["event_scheduler"] = {}
		if not data.has("meta"):
			data["meta"] = {}
		data["meta"]["version"] = "4.1.0"
		return data


var helper: RefCounted

func setup() -> void:
	helper = MigrationHelper.new()


# ── Version compatibility tests ──

func test_version_compatible_same_major() -> String:
	setup()
	return _assert(helper._is_version_compatible("4.0.0"),
		"v4.0.0 should be compatible with v4.1.0 (same major)")


func test_version_compatible_4_1() -> String:
	setup()
	return _assert(helper._is_version_compatible("4.1.0"),
		"v4.1.0 should be compatible with itself")


func test_version_incompatible_major_3() -> String:
	setup()
	return _assert(not helper._is_version_compatible("3.9.0"),
		"v3.9.0 should NOT be compatible (different major)")


func test_version_incompatible_major_5() -> String:
	setup()
	return _assert(not helper._is_version_compatible("5.0.0"),
		"v5.0.0 should NOT be compatible (different major)")


func test_version_incompatible_garbage() -> String:
	setup()
	return _assert(not helper._is_version_compatible("x"),
		"Garbage version string should be incompatible")


func test_version_incompatible_empty() -> String:
	setup()
	return _assert(not helper._is_version_compatible(""),
		"Empty version string should be incompatible")


# ── Migration v3 -> v4 tests ──

func test_migrate_3_to_4_adds_missing_keys() -> String:
	setup()
	var data: Dictionary = {"meta": {"version": "3.5.0"}, "resources": {}}
	var migrated: Dictionary = helper._migrate_3_to_4(data)
	var has_all: bool = migrated.has("faction_destruction_events") \
		and migrated.has("seasonal_events") \
		and migrated.has("character_interaction_events") \
		and migrated.has("grand_event_director") \
		and migrated.has("dynamic_situation_events") \
		and migrated.has("crisis_countdown") \
		and migrated.has("nation_system")
	return _assert(has_all, "migrate_3_to_4 should add all v4.0 system keys")


func test_migrate_3_to_4_preserves_existing_data() -> String:
	setup()
	var data: Dictionary = {"meta": {"version": "3.5.0"}, "resources": {"gold": 100}}
	var migrated: Dictionary = helper._migrate_3_to_4(data)
	return _assert(migrated.has("resources") and migrated["resources"]["gold"] == 100,
		"migrate_3_to_4 should preserve existing data")


func test_migrate_3_to_4_updates_version() -> String:
	setup()
	var data: Dictionary = {"meta": {"version": "3.5.0"}}
	var migrated: Dictionary = helper._migrate_3_to_4(data)
	return _assert(migrated["meta"]["version"] == "4.0.0",
		"migrate_3_to_4 should update meta version to 4.0.0")


# ── Migration v4.0 -> v4.1 tests ──

func test_migrate_4_0_to_4_1_adds_missing_keys() -> String:
	setup()
	var data: Dictionary = {"meta": {"version": "4.0.0"}}
	var migrated: Dictionary = helper._migrate_4_0_to_4_1(data)
	var has_all: bool = migrated.has("event_registry") \
		and migrated.has("quest_progress_tracker") \
		and migrated.has("event_scheduler")
	return _assert(has_all, "migrate_4_0_to_4_1 should add event_registry, quest_progress_tracker, event_scheduler")


func test_migrate_4_0_to_4_1_updates_version() -> String:
	setup()
	var data: Dictionary = {"meta": {"version": "4.0.0"}}
	var migrated: Dictionary = helper._migrate_4_0_to_4_1(data)
	return _assert(migrated["meta"]["version"] == "4.1.0",
		"migrate_4_0_to_4_1 should update meta version to 4.1.0")


func test_migrate_4_0_to_4_1_no_overwrite() -> String:
	setup()
	var data: Dictionary = {
		"meta": {"version": "4.0.0"},
		"event_registry": {"fired_history": {"evt_1": {"count": 3}}},
	}
	var migrated: Dictionary = helper._migrate_4_0_to_4_1(data)
	return _assert(migrated["event_registry"].has("fired_history"),
		"migrate_4_0_to_4_1 should not overwrite existing event_registry data")


# ── Full migration chain tests ──

func test_full_migration_3_to_4_1() -> String:
	setup()
	var data: Dictionary = {"meta": {"version": "3.7.0"}, "resources": {"gold": 50}}
	var migrated: Dictionary = helper._migrate_save_data(data, "3.7.0")
	var has_v4_keys: bool = migrated.has("faction_destruction_events")
	var has_v41_keys: bool = migrated.has("event_registry") and migrated.has("event_scheduler")
	var version_ok: bool = migrated["meta"]["version"] == "4.1.0"
	return _assert(has_v4_keys and has_v41_keys and version_ok,
		"Full chain from v3.7 should add both v4.0 and v4.1 keys and set version to 4.1.0")


func test_full_migration_4_0_only_adds_4_1() -> String:
	setup()
	var data: Dictionary = {"meta": {"version": "4.0.0"}}
	var migrated: Dictionary = helper._migrate_save_data(data, "4.0.0")
	var has_v41_keys: bool = migrated.has("event_registry")
	# Should NOT have added v4.0 keys again (they would only come from _migrate_3_to_4)
	return _assert(has_v41_keys and migrated["meta"]["version"] == "4.1.0",
		"v4.0 save should only run 4.0->4.1 migration")
