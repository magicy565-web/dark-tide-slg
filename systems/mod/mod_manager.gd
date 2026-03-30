## mod_manager.gd - MOD loading and data override system (v0.8.6)
## Autoload singleton. Scans user://mods/ for JSON data packs.
## MODs override/extend core data dictionaries without modifying code.
extends Node

const MOD_DIR: String = "user://mods/"
const GAME_VERSION: String = "3.7.0"

# ── MOD state ──
var _installed_mods: Array = []   # Array of mod.json metadata dicts
var _enabled_mods: Array = []     # Array of mod_id strings (ordered by priority)
var _loaded_data: Dictionary = {} # mod_id -> { "troops": {}, "heroes": {}, ... }

# ── Override registries (merged data from all enabled mods) ──
var _troop_overrides: Dictionary = {}
var _hero_overrides: Dictionary = {}
var _event_overrides: Dictionary = {}
var _item_overrides: Dictionary = {}
var _building_overrides: Dictionary = {}

# ── Config persistence ──
const MOD_CONFIG_PATH: String = "user://mod_config.json"


func _ready() -> void:
	_ensure_mod_dir()
	_load_config()
	scan_mods()


# ═══════════════ PUBLIC API ═══════════════

func scan_mods() -> Array:
	## Scan user://mods/ for all installed mods. Returns array of mod metadata.
	_installed_mods.clear()
	_ensure_mod_dir()

	var dir := DirAccess.open(MOD_DIR)
	if dir == null:
		return _installed_mods

	dir.list_dir_begin()
	var folder_name: String = dir.get_next()
	while folder_name != "":
		if dir.current_is_dir() and folder_name != "." and folder_name != "..":
			var mod_json_path: String = MOD_DIR + folder_name + "/mod.json"
			if FileAccess.file_exists(mod_json_path):
				var meta: Dictionary = _read_json(mod_json_path)
				if not meta.is_empty() and meta.has("id"):
					meta["_folder"] = folder_name
					meta["_path"] = MOD_DIR + folder_name + "/"
					meta["enabled"] = meta["id"] in _enabled_mods
					_installed_mods.append(meta)
		folder_name = dir.get_next()
	dir.list_dir_end()

	# Sort by priority (lower = loaded first)
	_installed_mods.sort_custom(func(a, b): return a.get("priority", 100) < b.get("priority", 100))
	return _installed_mods


func get_installed_mods() -> Array:
	return _installed_mods


func get_enabled_mods() -> Array:
	return _enabled_mods


func get_mod_info(mod_id: String) -> Dictionary:
	for mod in _installed_mods:
		if mod.get("id", "") == mod_id:
			return mod
	return {}


func enable_mod(mod_id: String) -> bool:
	if mod_id in _enabled_mods:
		return true
	# Verify mod exists
	var info: Dictionary = get_mod_info(mod_id)
	if info.is_empty():
		return false
	# Check game version compatibility
	if not _is_mod_compatible(info):
		EventBus.message_log.emit("[color=yellow]MOD '%s' 与当前游戏版本不兼容[/color]" % info.get("name", mod_id))
		return false
	_enabled_mods.append(mod_id)
	_save_config()
	EventBus.message_log.emit("[color=green]MOD '%s' 已启用 (重启生效)[/color]" % info.get("name", mod_id))
	return true


func disable_mod(mod_id: String) -> bool:
	if mod_id not in _enabled_mods:
		return false
	_enabled_mods.erase(mod_id)
	_save_config()
	var info: Dictionary = get_mod_info(mod_id)
	EventBus.message_log.emit("MOD '%s' 已禁用 (重启生效)" % info.get("name", mod_id))
	return true


func check_conflicts() -> Array:
	## Returns array of conflict description strings.
	var conflicts: Array = []
	for mod in _installed_mods:
		if not mod.get("enabled", false):
			continue
		var mod_conflicts: Array = mod.get("conflicts", [])
		for conflict_id in mod_conflicts:
			if conflict_id in _enabled_mods:
				conflicts.append("MOD '%s' 与 '%s' 冲突" % [mod["id"], conflict_id])
	return conflicts


func load_all_mods() -> void:
	## Called at game startup after core data is loaded.
	## Loads all enabled mods in priority order and applies overrides.
	_troop_overrides.clear()
	_hero_overrides.clear()
	_event_overrides.clear()
	_item_overrides.clear()
	_building_overrides.clear()
	_loaded_data.clear()

	# Sort enabled mods by their priority
	var sorted_mods: Array = []
	for mod in _installed_mods:
		if mod.get("id", "") in _enabled_mods:
			sorted_mods.append(mod)
	sorted_mods.sort_custom(func(a, b): return a.get("priority", 100) < b.get("priority", 100))

	for mod in sorted_mods:
		_load_single_mod(mod)

	var count: int = sorted_mods.size()
	if count > 0:
		EventBus.message_log.emit("[MOD] 已加载 %d 个MOD" % count)


# ═══════════════ QUERY API (for other systems) ═══════════════

func get_troop_override(troop_id: String) -> Dictionary:
	## Returns override data for a troop, or empty if no mod overrides it.
	return _troop_overrides.get(troop_id, {})


func get_hero_override(hero_id: String) -> Dictionary:
	return _hero_overrides.get(hero_id, {})


func get_event_override(event_id: String) -> Dictionary:
	return _event_overrides.get(event_id, {})


func get_item_override(item_id: String) -> Dictionary:
	return _item_overrides.get(item_id, {})


func get_building_override(building_id: String) -> Dictionary:
	return _building_overrides.get(building_id, {})


func get_all_troop_overrides() -> Dictionary:
	return _troop_overrides


func get_all_hero_overrides() -> Dictionary:
	return _hero_overrides


func has_troop_override(troop_id: String) -> bool:
	return _troop_overrides.has(troop_id)


func has_hero_override(hero_id: String) -> bool:
	return _hero_overrides.has(hero_id)


func get_mod_asset_path(mod_id: String, relative_path: String) -> String:
	## Resolves a relative asset path within a mod's directory.
	var info: Dictionary = get_mod_info(mod_id)
	if info.is_empty():
		return ""
	return info.get("_path", "") + "assets/" + relative_path


# ═══════════════ INTERNAL ═══════════════

func _load_single_mod(mod: Dictionary) -> void:
	var mod_id: String = mod["id"]
	var mod_path: String = mod.get("_path", "")
	var data_path: String = mod_path + "data/"

	_loaded_data[mod_id] = {}

	# Load troops.json
	var troops_path: String = data_path + "troops.json"
	if FileAccess.file_exists(troops_path):
		var troops_data: Dictionary = _read_json(troops_path)
		if _validate_mod_schema(troops_data, "troops", mod_id):
			var troops: Dictionary = troops_data.get("troops", {})
			for troop_id in troops:
				if not _validate_entry_schema(troops[troop_id], ["name"], "troops", troop_id, mod_id):
					continue
				troops[troop_id]["_mod_id"] = mod_id
				_troop_overrides[troop_id] = troops[troop_id]
			_loaded_data[mod_id]["troops"] = troops
			EventBus.message_log.emit("[MOD:%s] 加载 %d 个兵种" % [mod_id, troops.size()])

	# Load heroes.json
	var heroes_path: String = data_path + "heroes.json"
	if FileAccess.file_exists(heroes_path):
		var heroes_data: Dictionary = _read_json(heroes_path)
		if _validate_mod_schema(heroes_data, "heroes", mod_id):
			var heroes: Dictionary = heroes_data.get("heroes", {})
			for hero_id in heroes:
				if not _validate_entry_schema(heroes[hero_id], ["name"], "heroes", hero_id, mod_id):
					continue
				heroes[hero_id]["_mod_id"] = mod_id
				_hero_overrides[hero_id] = heroes[hero_id]
			_loaded_data[mod_id]["heroes"] = heroes
			EventBus.message_log.emit("[MOD:%s] 加载 %d 个英雄" % [mod_id, heroes.size()])

	# Load events.json
	var events_path: String = data_path + "events.json"
	if FileAccess.file_exists(events_path):
		var events_data: Dictionary = _read_json(events_path)
		if _validate_mod_schema(events_data, "events", mod_id):
			var events: Dictionary = events_data.get("events", {})
			for event_id in events:
				if not events[event_id] is Dictionary:
					push_warning("ModManager: [%s] event '%s' is not a Dictionary, skipping" % [mod_id, event_id])
					continue
				events[event_id]["_mod_id"] = mod_id
				_event_overrides[event_id] = events[event_id]
			_loaded_data[mod_id]["events"] = events

	# Load items.json
	var items_path: String = data_path + "items.json"
	if FileAccess.file_exists(items_path):
		var items_data: Dictionary = _read_json(items_path)
		if _validate_mod_schema(items_data, "items", mod_id):
			var items: Dictionary = items_data.get("items", {})
			for item_id in items:
				if not items[item_id] is Dictionary:
					push_warning("ModManager: [%s] item '%s' is not a Dictionary, skipping" % [mod_id, item_id])
					continue
				items[item_id]["_mod_id"] = mod_id
				_item_overrides[item_id] = items[item_id]
			_loaded_data[mod_id]["items"] = items

	# Load buildings.json
	var buildings_path: String = data_path + "buildings.json"
	if FileAccess.file_exists(buildings_path):
		var buildings_data: Dictionary = _read_json(buildings_path)
		if _validate_mod_schema(buildings_data, "buildings", mod_id):
			var buildings: Dictionary = buildings_data.get("buildings", {})
			for bld_id in buildings:
				if not buildings[bld_id] is Dictionary:
					push_warning("ModManager: [%s] building '%s' is not a Dictionary, skipping" % [mod_id, bld_id])
					continue
				buildings[bld_id]["_mod_id"] = mod_id
				_building_overrides[bld_id] = buildings[bld_id]
			_loaded_data[mod_id]["buildings"] = buildings


func _read_json(path: String) -> Dictionary:
	## Read and parse a JSON file. Returns empty dict on failure.
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("ModManager: Cannot open %s" % path)
		return {}
	var json_str: String = file.get_as_text()
	file.close()

	# Basic safety check: reject excessively large files (> 10MB)
	if json_str.length() > 10 * 1024 * 1024:
		push_warning("ModManager: File too large, rejecting %s (%d bytes)" % [path, json_str.length()])
		return {}

	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_warning("ModManager: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	if json.data is Dictionary:
		return json.data
	return {}


func _validate_mod_schema(data: Dictionary, expected_key: String, mod_id: String) -> bool:
	## Basic schema validation: the top-level dict must contain the expected key as a Dictionary.
	if data.is_empty():
		push_warning("ModManager: [%s] Empty data file for '%s'" % [mod_id, expected_key])
		return false
	if not data.has(expected_key):
		push_warning("ModManager: [%s] Missing required key '%s' in data file" % [mod_id, expected_key])
		return false
	if not data[expected_key] is Dictionary:
		push_warning("ModManager: [%s] Key '%s' must be a Dictionary, got %s" % [mod_id, expected_key, typeof(data[expected_key])])
		return false
	return true


func _validate_entry_schema(entry: Variant, required_fields: Array, category: String, entry_id: String, mod_id: String) -> bool:
	## Validate that an individual entry is a Dictionary and has required fields.
	if not entry is Dictionary:
		push_warning("ModManager: [%s] %s entry '%s' is not a Dictionary" % [mod_id, category, entry_id])
		return false
	for field in required_fields:
		if not entry.has(field):
			push_warning("ModManager: [%s] %s entry '%s' missing required field '%s'" % [mod_id, category, entry_id, field])
			return false
	return true


func _is_mod_compatible(mod: Dictionary) -> bool:
	var min_ver: String = mod.get("game_version_min", "0.0.0")
	var max_ver: String = mod.get("game_version_max", "99.99.99")
	return _version_compare(GAME_VERSION, min_ver) >= 0 and _version_compare(GAME_VERSION, max_ver) <= 0


func _version_compare(a: String, b: String) -> int:
	## Simple version comparison. Returns -1, 0, or 1.
	var pa: Array = a.split(".")
	var pb: Array = b.split(".")
	for i in range(maxi(pa.size(), pb.size())):
		var va: int = int(pa[i]) if i < pa.size() else 0
		var vb: int = int(pb[i]) if i < pb.size() else 0
		if va < vb:
			return -1
		elif va > vb:
			return 1
	return 0


func _ensure_mod_dir() -> void:
	if not DirAccess.dir_exists_absolute(MOD_DIR):
		DirAccess.make_dir_recursive_absolute(MOD_DIR)


# ═══════════════ CONFIG PERSISTENCE ═══════════════

func _save_config() -> void:
	## Save enabled mod list to config file.
	var data: Dictionary = {"enabled_mods": _enabled_mods.duplicate()}
	var json_str: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(MOD_CONFIG_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()


func _load_config() -> void:
	## Load enabled mod list from config file.
	if not FileAccess.file_exists(MOD_CONFIG_PATH):
		return
	var data: Dictionary = _read_json(MOD_CONFIG_PATH)
	_enabled_mods = []
	for mod_id in data.get("enabled_mods", []):
		_enabled_mods.append(str(mod_id))
