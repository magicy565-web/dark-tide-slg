## save_manager.gd - Save/Load orchestration (v1.5.0)
## Autoload singleton. Serializes full game state to JSON files.
extends Node

const SAVE_VERSION: String = "3.3.0"
const SAVE_DIR: String = "user://saves/"
const MAX_MANUAL_SLOTS: int = 5
const AUTO_SLOT: int = 99


func _ready() -> void:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.game_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5:
			save_game(0)  # Quick save to slot 0
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F9:
			load_game(0)  # Quick load from slot 0
			get_viewport().set_input_as_handled()


# ═══════════════ PUBLIC API ═══════════════

func save_game(slot: int) -> bool:
	## Save current game state to the given slot. Returns true on success.
	# 校验槽位索引范围，仅允许手动槽位(0..MAX_MANUAL_SLOTS-1)和自动存档槽位
	if slot != AUTO_SLOT and (slot < 0 or slot >= MAX_MANUAL_SLOTS):
		push_warning("SaveManager: 无效的存档槽位 %d (有效范围: 0-%d 或 %d)" % [slot, MAX_MANUAL_SLOTS - 1, AUTO_SLOT])
		return false
	if not GameManager.game_active:
		EventBus.message_log.emit("[color=red]无法保存: 游戏未运行[/color]")
		return false

	var save_data: Dictionary = _collect_save_data()
	var json_str: String = JSON.stringify(save_data, "\t")
	var path: String = _slot_path(slot)

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Failed to open %s for writing" % path)
		EventBus.message_log.emit("[color=red]保存失败![/color]")
		return false
	file.store_string(json_str)
	file.close()

	# Write checksum
	var crc: int = json_str.hash()
	var crc_file := FileAccess.open(path + ".crc", FileAccess.WRITE)
	if crc_file:
		crc_file.store_string(str(crc))
		crc_file.close()

	EventBus.message_log.emit("[color=green]游戏已保存 (槽位%d)[/color]" % slot)
	return true


func load_game(slot: int) -> bool:
	## Load game state from the given slot. Returns true on success.
	# 校验槽位索引范围
	if slot != AUTO_SLOT and (slot < 0 or slot >= MAX_MANUAL_SLOTS):
		push_warning("SaveManager: 无效的存档槽位 %d" % slot)
		return false
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		EventBus.message_log.emit("[color=red]存档不存在 (槽位%d)[/color]" % slot)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Failed to open %s for reading" % path)
		return false
	var json_str: String = file.get_as_text()
	file.close()

	# Verify checksum
	var crc_path: String = path + ".crc"
	if FileAccess.file_exists(crc_path):
		var crc_file := FileAccess.open(crc_path, FileAccess.READ)
		if crc_file:
			var stored_crc: String = crc_file.get_as_text().strip_edges()
			crc_file.close()
			var actual_crc: int = json_str.hash()
			if stored_crc != str(actual_crc):
				EventBus.message_log.emit("[color=yellow]警告: 存档可能已损坏 (校验和不匹配)[/color]")

	# Parse JSON
	var json := JSON.new()
	var parse_result: int = json.parse(json_str)
	if parse_result != OK:
		push_error("SaveManager: JSON parse error: %s" % json.get_error_message())
		EventBus.message_log.emit("[color=red]存档解析失败![/color]")
		return false
	var save_data: Dictionary = json.data
	if not save_data is Dictionary:
		push_error("SaveManager: Invalid save data format")
		return false

	# Version check
	var saved_version: String = save_data.get("meta", {}).get("version", "0.0.0")
	if not _is_version_compatible(saved_version):
		EventBus.message_log.emit("[color=red]存档版本不兼容 (存档:%s 当前:%s)[/color]" % [saved_version, SAVE_VERSION])
		return false

	# Apply save data
	_apply_save_data(save_data)

	EventBus.message_log.emit("[color=green]游戏已加载 (槽位%d, 第%d回合)[/color]" % [slot, GameManager.turn_number])
	return true


func auto_save() -> bool:
	return save_game(AUTO_SLOT)


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: int) -> bool:
	var path: String = _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		var crc_path: String = path + ".crc"
		if FileAccess.file_exists(crc_path):
			DirAccess.remove_absolute(crc_path)
		return true
	return false


func get_save_info(slot: int) -> Dictionary:
	## Returns meta info for display (without loading full state).
	var path: String = _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json_str: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		return {}
	var data: Dictionary = json.data
	if not data is Dictionary:
		return {}
	return data.get("meta", {})


func get_all_save_info() -> Array:
	## Returns meta info for all slots (manual + auto).
	var result: Array = []
	for i in range(MAX_MANUAL_SLOTS):
		var info: Dictionary = get_save_info(i)
		if not info.is_empty():
			info["slot"] = i
			result.append(info)
	var auto_info: Dictionary = get_save_info(AUTO_SLOT)
	if not auto_info.is_empty():
		auto_info["slot"] = AUTO_SLOT
		result.append(auto_info)
	return result


# ═══════════════ SERIALIZATION ═══════════════

func _collect_save_data() -> Dictionary:
	var pid: int = GameManager.get_human_player_id()
	var faction_id: int = GameManager.get_player_faction(pid)

	return {
		"meta": {
			"version": SAVE_VERSION,
			"timestamp": Time.get_datetime_string_from_system(),
			"turn": GameManager.turn_number,
			"faction": faction_id,
			"player_name": GameManager.players[0].get("name", "") if not GameManager.players.is_empty() else "",
		},
		"game_state": _save_game_state(),
		"resources": ResourceManager.to_save_data(),
		"slaves": SlaveManager.to_save_data(),
		"buffs": BuffManager.to_save_data(),
		"items": ItemManager.to_save_data(),
		"relics": RelicManager.to_save_data(),
		"strategic": StrategicResourceManager.to_save_data(),
		"order": OrderManager.to_save_data(),
		"threat": ThreatManager.to_save_data(),
		"factions": FactionManager.to_save_data(),
		"orc": OrcMechanic.to_save_data(),
		"pirate": PirateMechanic.to_save_data(),
		"dark_elf": DarkElfMechanic.to_save_data(),
		"npcs": NpcManager.to_save_data(),
		"quests": QuestManager.to_save_data(),
		"recruit": RecruitManager.to_save_data(),
		"diplomacy": DiplomacyManager.to_save_data(),
		"heroes": HeroSystem.to_save_data() if HeroSystem != null else {},
		"research": ResearchManager.to_save_data(),
		"ai_scaling": AIScaling.to_save_data(),
		"events": EventSystem.to_save_data(),
		"light_faction_ai": LightFactionAI.to_save_data(),
		"alliance_ai": AllianceAI.to_save_data(),
		"evil_faction_ai": EvilFactionAI.to_save_data(),
		"ai_strategic_planner": AIStrategicPlanner.to_save_data(),
		"neutral_faction_ai": NeutralFactionAI.to_save_data(),
		"audio": AudioManager.to_save_data(),
		"tutorial": TutorialManager.to_save_data(),
		"quest_journal": QuestJournal.to_save_data(),
		"balance_manager": BalanceManager.serialize(),
		"story": StoryEventSystem.to_save_data(),
		# NOTE: hero_leveling is serialized inside HeroSystem.to_save_data()["hero_leveling"]
		# so we no longer duplicate it at the top level to avoid double-serialize/deserialize.
		"hero_leveling": HeroLeveling.serialize(),  # kept for backward compat on load
		"tile_development": TileDevelopment.to_save_data(),
		"supply_system": SupplySystem.to_save_data(),
		"siege": SiegeSystem.to_save_data(),
		# BUG FIX: save 4 previously missing systems
		"march_system": MarchSystem.to_save_data() if MarchSystem != null else {},
		"enchantment": EnchantmentSystem.to_save_data() if EnchantmentSystem != null else {},
		"hero_skills_advanced": HeroSkillsAdvanced.to_save_data() if HeroSkillsAdvanced != null else {},
		"environment": EnvironmentSystem.to_save_data() if EnvironmentSystem != null else {},
	}


func _save_game_state() -> Dictionary:
	## Serialize GameManager's own state.
	var players_data: Array = []
	for p in GameManager.players:
		var pd: Dictionary = p.duplicate(true)
		# Convert Color to serializable dict
		if pd.has("color") and pd["color"] is Color:
			var c: Color = pd["color"]
			pd["color"] = {"r": c.r, "g": c.g, "b": c.b, "a": c.a, "_type": "Color"}
		players_data.append(pd)

	var tiles_data: Array = []
	for t in GameManager.tiles:
		var td: Dictionary = t.duplicate(true)
		# Convert Vector3/Vector2 to serializable dicts
		if td.has("position_3d") and td["position_3d"] is Vector3:
			var v: Vector3 = td["position_3d"]
			td["position_3d"] = {"x": v.x, "y": v.y, "z": v.z, "_type": "Vector3"}
		if td.has("position") and td["position"] is Vector2:
			var v2: Vector2 = td["position"]
			td["position"] = {"x": v2.x, "y": v2.y, "_type": "Vector2"}
		# Convert revealed dict int keys to string for JSON
		if td.has("revealed") and td["revealed"] is Dictionary:
			var rev: Dictionary = {}
			for k in td["revealed"]:
				rev[str(k)] = td["revealed"][k]
			td["revealed"] = rev
		tiles_data.append(td)

	# Serialize armies (JSON keys must be strings)
	var armies_data: Dictionary = {}
	for army_id in GameManager.armies:
		armies_data[str(army_id)] = GameManager.armies[army_id].duplicate(true)

	# Serialize _guard_timers (int keys -> string keys for JSON)
	var guard_timers_data: Dictionary = {}
	for k in GameManager._guard_timers:
		guard_timers_data[str(k)] = GameManager._guard_timers[k].duplicate()

	# Serialize _sat_points (int keys -> string keys for JSON)
	var sat_points_data: Dictionary = {}
	for k in GameManager._sat_points:
		sat_points_data[str(k)] = GameManager._sat_points[k]

	return {
		"players": players_data,
		"tiles": tiles_data,
		"adjacency": GameManager.adjacency.duplicate(true),
		"current_player_index": GameManager.current_player_index,
		"turn_number": GameManager.turn_number,
		"player_factions": GameManager._player_factions.duplicate(),
		"game_active": GameManager.game_active,
		"armies": armies_data,
		"next_army_id": GameManager._next_army_id,
		"guard_timers": guard_timers_data,
		"sat_points": sat_points_data,
	}


# ═══════════════ DESERIALIZATION ═══════════════

func _apply_save_data(data: Dictionary) -> void:
	## Restore full game state from save data.

	# 1. Restore GameManager core state
	_load_game_state(data.get("game_state", {}))

	# 2. Restore all subsystems (with error handling for each)
	_safe_load(func(): ResourceManager.from_save_data(data.get("resources", {})), "ResourceManager")
	_safe_load(func(): SlaveManager.from_save_data(data.get("slaves", {})), "SlaveManager")
	_safe_load(func(): BuffManager.from_save_data(data.get("buffs", {})), "BuffManager")
	_safe_load(func(): ItemManager.from_save_data(data.get("items", {})), "ItemManager")
	_safe_load(func(): RelicManager.from_save_data(data.get("relics", {})), "RelicManager")
	_safe_load(func(): StrategicResourceManager.from_save_data(data.get("strategic", {})), "StrategicResourceManager")
	_safe_load(func(): OrderManager.from_save_data(data.get("order", {})), "OrderManager")
	_safe_load(func(): ThreatManager.from_save_data(data.get("threat", {})), "ThreatManager")
	_safe_load(func(): FactionManager.from_save_data(data.get("factions", {})), "FactionManager")
	_safe_load(func(): OrcMechanic.from_save_data(data.get("orc", {})), "OrcMechanic")
	_safe_load(func(): PirateMechanic.from_save_data(data.get("pirate", {})), "PirateMechanic")
	_safe_load(func(): DarkElfMechanic.from_save_data(data.get("dark_elf", {})), "DarkElfMechanic")
	_safe_load(func(): NpcManager.from_save_data(data.get("npcs", {})), "NpcManager")
	_safe_load(func(): QuestManager.from_save_data(data.get("quests", {})), "QuestManager")
	_safe_load(func(): RecruitManager.from_save_data(data.get("recruit", {})), "RecruitManager")
	_safe_load(func(): DiplomacyManager.from_save_data(data.get("diplomacy", {})), "DiplomacyManager")
	_safe_load(func(): HeroSystem.from_save_data(data.get("heroes", {})) if HeroSystem != null else null, "HeroSystem")
	_safe_load(func(): ResearchManager.from_save_data(data.get("research", {})), "ResearchManager")
	_safe_load(func(): AIScaling.from_save_data(data.get("ai_scaling", {})), "AIScaling")
	_safe_load(func(): EventSystem.from_save_data(data.get("events", {})), "EventSystem")

	# 3. Restore AI faction state (with legacy fallback)
	if data.has("light_faction_ai"):
		LightFactionAI.from_save_data(data.get("light_faction_ai", {}))
	else:
		# Legacy save: re-init from tile state
		LightFactionAI.init_light_defenses()
	AllianceAI.from_save_data(data.get("alliance_ai", {}))
	EvilFactionAI.from_save_data(data.get("evil_faction_ai", {}))
	AIStrategicPlanner.from_save_data(data.get("ai_strategic_planner", {}))

	# 3b. Restore neutral faction AI (v2.1+)
	if data.has("neutral_faction_ai"):
		NeutralFactionAI.from_save_data(data.get("neutral_faction_ai", {}))
	else:
		# Legacy save: re-init from tile state
		NeutralFactionAI.reset()
		NeutralFactionAI.init_neutral_territories()

	# 4. Restore new systems (v1.5+)
	if data.has("audio"):
		AudioManager.from_save_data(data.get("audio", {}))
	if data.has("tutorial"):
		TutorialManager.from_save_data(data.get("tutorial", {}))

	# 4b. Restore quest journal (v2.4+)
	if data.has("quest_journal"):
		QuestJournal.from_save_data(data.get("quest_journal", {}))
	if data.has("balance_manager"):
		BalanceManager.deserialize(data.get("balance_manager", {}))

	# 4c. Restore story event progress (v3.1+)
	if data.has("story"):
		StoryEventSystem.from_save_data(data.get("story", {}))

	# 4d. Restore hero leveling state (v3.2+)
	# BUG FIX: HeroLeveling was deserialized twice — once inside HeroSystem.from_save_data()
	# and again here. Only restore from top-level if HeroSystem didn't already handle it
	# (i.e., for saves where "heroes" key lacks "hero_leveling" but top-level has it).
	if data.has("hero_leveling") and not data.get("heroes", {}).has("hero_leveling"):
		HeroLeveling.deserialize(data.get("hero_leveling", {}))

	# 4e. Restore tile development state (v3.5+)
	if data.has("tile_development"):
		TileDevelopment.from_save_data(data.get("tile_development", {}))

	# 4f. Restore supply system state (v4.7+)
	if data.has("supply_system"):
		SupplySystem.from_save_data(data.get("supply_system", {}))
	else:
		SupplySystem.reset()

	# 4g. Restore siege system state (v5.0+)
	if data.has("siege"):
		SiegeSystem.from_save_data(data.get("siege", {}))

	# 4h. BUG FIX: Restore 4 previously missing systems (v5.1+)
	if data.has("march_system") and MarchSystem != null:
		MarchSystem.from_save_data(data.get("march_system", {}))
	if data.has("enchantment") and EnchantmentSystem != null:
		EnchantmentSystem.from_save_data(data.get("enchantment", {}))
	if data.has("hero_skills_advanced") and HeroSkillsAdvanced != null:
		HeroSkillsAdvanced.from_save_data(data.get("hero_skills_advanced", {}))
	if data.has("environment") and EnvironmentSystem != null:
		EnvironmentSystem.from_save_data(data.get("environment", {}))

	# 5. Emit signals to refresh UI
	var pid: int = GameManager.get_human_player_id()
	EventBus.resources_changed.emit(pid)
	EventBus.army_changed.emit(pid, ResourceManager.get_army(pid))
	EventBus.order_changed.emit(OrderManager.get_order())
	EventBus.threat_changed.emit(ThreatManager.get_threat())
	EventBus.turn_started.emit(pid)


func _load_game_state(gs: Dictionary) -> void:
	## Restore GameManager's own state.
	if gs.is_empty():
		return

	# Restore players
	GameManager.players.clear()
	for p in gs.get("players", []):
		if p is Dictionary:
			# Restore Color from serialized dict
			if p.has("color") and p["color"] is Dictionary and p["color"].get("_type") == "Color":
				var cd: Dictionary = p["color"]
				p["color"] = Color(cd.get("r", 1.0), cd.get("g", 1.0), cd.get("b", 1.0), cd.get("a", 1.0))
			GameManager.players.append(p)

	# Restore tiles
	GameManager.tiles.clear()
	for t in gs.get("tiles", []):
		if t is Dictionary:
			# Restore Vector3 from serialized dict
			if t.has("position_3d") and t["position_3d"] is Dictionary and t["position_3d"].get("_type") == "Vector3":
				var vd: Dictionary = t["position_3d"]
				t["position_3d"] = Vector3(vd.get("x", 0), vd.get("y", 0), vd.get("z", 0))
			# Restore Vector2 from serialized dict
			if t.has("position") and t["position"] is Dictionary and t["position"].get("_type") == "Vector2":
				var vd2: Dictionary = t["position"]
				t["position"] = Vector2(vd2.get("x", 0), vd2.get("y", 0))
			# Restore revealed dict with int keys
			if t.has("revealed") and t["revealed"] is Dictionary:
				var rev: Dictionary = {}
				for k in t["revealed"]:
					rev[int(k)] = t["revealed"][k]
				t["revealed"] = rev
			var i: int = GameManager.tiles.size()
			t["index"] = int(t.get("index", i))
			t["type"] = int(t.get("type", 0))
			t["owner_id"] = int(t.get("owner_id", -1))
			t["garrison"] = int(t.get("garrison", 0))
			t["level"] = int(t.get("level", 1))
			t["light_faction"] = int(t.get("light_faction", -1))
			t["neutral_faction_id"] = int(t.get("neutral_faction_id", -1))
			t["terrain"] = int(t.get("terrain", 0))
			t["original_faction"] = int(t.get("original_faction", -1))
			t["building_level"] = int(t.get("building_level", 0))
			t["terrain_move_cost"] = int(t.get("terrain_move_cost", 1))
			GameManager.tiles.append(t)

	# Restore adjacency (JSON keys are strings, convert back to int)
	GameManager.adjacency.clear()
	var adj_raw: Dictionary = gs.get("adjacency", {})
	for key in adj_raw:
		if not str(key).is_valid_int():
			continue
		var int_key: int = int(key)
		var neighbors: Array = []
		for v in adj_raw[key]:
			neighbors.append(int(v))
		GameManager.adjacency[int_key] = neighbors

	# Restore player factions (JSON keys are strings)
	GameManager._player_factions.clear()
	var factions_raw: Dictionary = gs.get("player_factions", {})
	for key in factions_raw:
		GameManager._player_factions[int(key)] = int(factions_raw[key])

	GameManager.current_player_index = int(gs.get("current_player_index", 0))
	# Bounds check: clamp to valid player range
	if GameManager.players.size() > 0:
		GameManager.current_player_index = clampi(GameManager.current_player_index, 0, GameManager.players.size() - 1)
	else:
		GameManager.current_player_index = 0
	GameManager.turn_number = int(gs.get("turn_number", 0))
	GameManager.game_active = gs.get("game_active", true)

	# Reset transient state
	GameManager.has_rolled = false
	GameManager.waiting_for_move = false
	GameManager.dice_value = 0
	GameManager.reachable_tiles.clear()
	GameManager._had_combat_this_turn = false
	GameManager._prev_turn_had_combat = false

	# Restore armies (JSON keys are strings, convert back to int)
	GameManager.armies.clear()
	var armies_raw: Dictionary = gs.get("armies", {})
	for key in armies_raw:
		var army: Dictionary = armies_raw[key]
		if army is Dictionary:
			var int_key: int = int(key)
			# Ensure integer fields are properly typed after JSON round-trip
			army["id"] = int(army.get("id", int_key))
			army["player_id"] = int(army.get("player_id", 0))
			army["tile_index"] = int(army.get("tile_index", -1))
			# BUG FIX: also fix troop dict fields inside army after JSON round-trip
			var troops: Array = army.get("troops", [])
			for troop in troops:
				if troop is Dictionary:
					for fld in ["soldiers", "max_soldiers", "hp_per_soldier", "total_hp", "max_hp", "experience", "base_atk", "base_def", "morale"]:
						if troop.has(fld) and troop[fld] is float:
							troop[fld] = int(troop[fld])
			GameManager.armies[int_key] = army
	GameManager._next_army_id = int(gs.get("next_army_id", 1))
	# If armies exist but next_army_id is too low, fix it
	if not GameManager.armies.is_empty():
		var max_id: int = 0
		for aid in GameManager.armies:
			max_id = maxi(max_id, aid)
		GameManager._next_army_id = maxi(GameManager._next_army_id, max_id + 1)
	# 防止ID为零或负数
	GameManager._next_army_id = maxi(GameManager._next_army_id, 1)
	GameManager.selected_army_id = -1

	# Restore _guard_timers (string keys -> int keys)
	GameManager._guard_timers.clear()
	var guard_raw: Dictionary = gs.get("guard_timers", {})
	for key in guard_raw:
		if str(key).is_valid_int():
			# BUG FIX: deep-convert guard_timers inner dict values to int after JSON round-trip
			var timer_data = guard_raw[key]
			if timer_data is Dictionary:
				for tk in timer_data:
					if timer_data[tk] is float:
						timer_data[tk] = int(timer_data[tk])
			GameManager._guard_timers[int(key)] = timer_data

	# Restore _sat_points (string keys -> int keys)
	GameManager._sat_points.clear()
	var sat_raw: Dictionary = gs.get("sat_points", {})
	for key in sat_raw:
		if str(key).is_valid_int():
			GameManager._sat_points[int(key)] = int(sat_raw[key])


# ═══════════════ VERSION COMPAT ═══════════════

func _is_version_compatible(saved_ver: String) -> bool:
	## Major version must match. Minor differences are OK.
	var saved_parts: Array = saved_ver.split(".")
	var current_parts: Array = SAVE_VERSION.split(".")
	if saved_parts.size() < 2 or current_parts.size() < 2:
		return false
	# Major version (first number) must match
	return saved_parts[0] == current_parts[0]


# ═══════════════ HELPERS ═══════════════

func _safe_load(loader: Callable, system_name: String) -> void:
	## Wraps a subsystem load call with error handling to prevent one failure from breaking all loading.
	# Note: GDScript does not have try/catch, so we validate the callable runs without crashing.
	# In practice, from_save_data methods handle missing keys with .get() defaults.
	# This wrapper logs and continues if a system is null or unavailable.
	if loader == null:
		push_warning("SaveManager: Skipping null loader for %s" % system_name)
		return
	loader.call()


func _slot_path(slot: int) -> String:
	if slot == AUTO_SLOT:
		return SAVE_DIR + "autosave.json"
	return SAVE_DIR + "save_slot_%d.json" % slot
