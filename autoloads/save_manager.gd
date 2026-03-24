## save_manager.gd - Save/Load orchestration (v1.5.0)
## Autoload singleton. Serializes full game state to JSON files.
extends Node

const SAVE_VERSION: String = "3.0.0"
const SAVE_DIR: String = "user://saves/"
const MAX_MANUAL_SLOTS: int = 5
const AUTO_SLOT: int = 99


func _ready() -> void:
	# Ensure save directory exists
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _unhandled_input(event: InputEvent) -> void:
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
			"player_name": GameManager.players[0].get("name", ""),
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
		"heroes": HeroSystem.to_save_data(),
		"research": ResearchManager.to_save_data(),
		"ai_scaling": AIScaling.to_save_data(),
		"events": EventSystem.to_save_data(),
		"light_faction_ai": LightFactionAI.to_save_data(),
		"alliance_ai": AllianceAI.to_save_data(),
		"evil_faction_ai": EvilFactionAI.to_save_data(),
		"neutral_faction_ai": NeutralFactionAI.to_save_data(),
		"audio": AudioManager.to_save_data(),
		"tutorial": TutorialManager.to_save_data(),
		"quest_journal": QuestJournal.to_save_data(),
		"balance_manager": BalanceManager.serialize(),
		"story": StoryEventSystem.to_save_data(),
	}


func _save_game_state() -> Dictionary:
	## Serialize GameManager's own state.
	var players_data: Array = []
	for p in GameManager.players:
		players_data.append(p.duplicate(true))

	var tiles_data: Array = []
	for t in GameManager.tiles:
		tiles_data.append(t.duplicate(true))

	# Serialize armies (JSON keys must be strings)
	var armies_data: Dictionary = {}
	for army_id in GameManager.armies:
		armies_data[str(army_id)] = GameManager.armies[army_id].duplicate(true)

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
	}


# ═══════════════ DESERIALIZATION ═══════════════

func _apply_save_data(data: Dictionary) -> void:
	## Restore full game state from save data.

	# 1. Restore GameManager core state
	_load_game_state(data.get("game_state", {}))

	# 2. Restore all subsystems
	ResourceManager.from_save_data(data.get("resources", {}))
	SlaveManager.from_save_data(data.get("slaves", {}))
	BuffManager.from_save_data(data.get("buffs", {}))
	ItemManager.from_save_data(data.get("items", {}))
	RelicManager.from_save_data(data.get("relics", {}))
	StrategicResourceManager.from_save_data(data.get("strategic", {}))
	OrderManager.from_save_data(data.get("order", {}))
	ThreatManager.from_save_data(data.get("threat", {}))
	FactionManager.from_save_data(data.get("factions", {}))
	OrcMechanic.from_save_data(data.get("orc", {}))
	PirateMechanic.from_save_data(data.get("pirate", {}))
	DarkElfMechanic.from_save_data(data.get("dark_elf", {}))
	NpcManager.from_save_data(data.get("npcs", {}))
	QuestManager.from_save_data(data.get("quests", {}))
	RecruitManager.from_save_data(data.get("recruit", {}))
	DiplomacyManager.from_save_data(data.get("diplomacy", {}))
	HeroSystem.from_save_data(data.get("heroes", {}))
	ResearchManager.from_save_data(data.get("research", {}))
	AIScaling.from_save_data(data.get("ai_scaling", {}))
	EventSystem.from_save_data(data.get("events", {}))

	# 3. Restore AI faction state (with legacy fallback)
	if data.has("light_faction_ai"):
		LightFactionAI.from_save_data(data.get("light_faction_ai", {}))
	else:
		# Legacy save: re-init from tile state
		LightFactionAI.init_light_defenses()
	AllianceAI.from_save_data(data.get("alliance_ai", {}))
	EvilFactionAI.from_save_data(data.get("evil_faction_ai", {}))

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
			GameManager.players.append(p)

	# Restore tiles
	GameManager.tiles.clear()
	for t in gs.get("tiles", []):
		if t is Dictionary:
			GameManager.tiles.append(t)

	# Restore adjacency (JSON keys are strings, convert back to int)
	GameManager.adjacency.clear()
	var adj_raw: Dictionary = gs.get("adjacency", {})
	for key in adj_raw:
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
			GameManager.armies[int_key] = army
	GameManager._next_army_id = int(gs.get("next_army_id", 1))
	# If armies exist but next_army_id is too low, fix it
	if not GameManager.armies.is_empty():
		var max_id: int = 0
		for aid in GameManager.armies:
			max_id = maxi(max_id, aid)
		GameManager._next_army_id = maxi(GameManager._next_army_id, max_id + 1)
	GameManager.selected_army_id = -1


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

func _slot_path(slot: int) -> String:
	if slot == AUTO_SLOT:
		return SAVE_DIR + "autosave.json"
	return SAVE_DIR + "save_slot_%d.json" % slot
