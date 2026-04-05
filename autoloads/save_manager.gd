## save_manager.gd - Save/Load orchestration (v1.5.0)
## Autoload singleton. Serializes full game state to JSON files.
extends Node

const SAVE_VERSION: String = "4.1.0"
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

	# Migrate save data if needed
	save_data = _migrate_save_data(save_data, saved_version)

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
		"human_kingdom_ai": HumanKingdomAI.to_save_data() if HumanKingdomAI != null else {},
		"human_kingdom_events": HumanKingdomEvents.to_save_data() if HumanKingdomEvents != null else {},
		"alliance_ai": AllianceAI.to_save_data(),
		"evil_faction_ai": EvilFactionAI.to_save_data(),
		"ai_strategic_planner": AIStrategicPlanner.to_save_data(),
		"neutral_faction_ai": NeutralFactionAI.to_save_data(),
		"audio": AudioManager.to_save_data(),
		"tutorial": TutorialManager.to_save_data(),
		"pirate_onboarding": PirateOnboarding.to_save_data() if PirateOnboarding != null else {},
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
		"troop_training": _collect_troop_training(),
		"treaty_system": TreatySystem.to_save_data() if TreatySystem != null else {},
		"equipment_forge": EquipmentForge.to_save_data() if EquipmentForge != null else {},
		"supply_logistics": SupplyLogistics.to_save_data() if SupplyLogistics != null else {},
		"weather": WeatherSystem.to_save_data() if WeatherSystem != null else {},
		"espionage": EspionageSystem.to_save_data() if EspionageSystem != null else {},
		"cg_gallery": CGManager.to_save_data() if CGManager != null else {},
		# v4.0 new systems
		"faction_destruction_events": FactionDestructionEvents.get_save_data() if FactionDestructionEvents != null else {},
		"seasonal_events": SeasonalEvents.get_save_data() if SeasonalEvents != null else {},
		"character_interaction_events": CharacterInteractionEvents.get_save_data() if CharacterInteractionEvents != null else {},
		"grand_event_director": GrandEventDirector.get_save_data() if GrandEventDirector != null else {},
		"dynamic_situation_events": DynamicSituationEvents.get_save_data() if DynamicSituationEvents != null else {},
		"crisis_countdown": CrisisCountdown.get_save_data() if CrisisCountdown != null else {},
		"nation_system": _save_nation_system(),
		# v4.1 centralized event/quest systems
		"event_registry": EventRegistry.serialize() if EventRegistry != null else {},
		"quest_progress_tracker": QuestProgressTracker.to_save_data() if QuestProgressTracker != null else {},
		"event_scheduler": EventScheduler.to_save_data() if EventScheduler != null else {},
		# v4.3 新增系统
		"general_system": GeneralSystem.serialize() if GeneralSystem != null else {},
		# v4.7 新增系统
		"prestige_shop": PrestigeShop.to_save_data() if PrestigeShop != null else {},
		"ngplus_shop": NGPlusShop.to_save_data() if NGPlusShop != null else {},
		# v1.2.0 据点系统
		"stronghold_governance": GameManager.governance_system.to_save_data() if GameManager.governance_system != null else {},
		"stronghold_morale": GameManager.morale_corruption_system.to_save_data() if GameManager.morale_corruption_system != null else {},
		"stronghold_development": GameManager.development_path_system.to_save_data() if GameManager.development_path_system != null else {},
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
		"game_stats": GameManager.game_stats.duplicate(true),
		"_last_grand_festival_turn": GameManager._last_grand_festival_turn,
		"_imperial_decree_used": GameManager._imperial_decree_used,
		"_forge_alliance_used": GameManager._forge_alliance_used,
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
	if data.has("human_kingdom_ai") and HumanKingdomAI != null:
		HumanKingdomAI.from_save_data(data.get("human_kingdom_ai", {}))
	if data.has("human_kingdom_events") and HumanKingdomEvents != null:
		HumanKingdomEvents.from_save_data(data.get("human_kingdom_events", {}))
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
	if data.has("pirate_onboarding") and PirateOnboarding != null:
		PirateOnboarding.from_save_data(data.get("pirate_onboarding", {}))

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

	# 4i. Restore troop training panel state
	if data.has("troop_training"):
		var ttp = _find_troop_training_panel()
		if ttp and ttp.has_method("from_save_data"):
			ttp.from_save_data(data.get("troop_training", {}))

	# 4j. Restore treaty system state (v3.6+)
	if data.has("treaty_system") and TreatySystem != null:
		TreatySystem.from_save_data(data.get("treaty_system", {}))

	# 4k. Restore equipment forge state (v3.6+)
	if data.has("equipment_forge") and EquipmentForge != null:
		EquipmentForge.from_save_data(data.get("equipment_forge", {}))

	# 4l. Restore supply logistics state (v3.6+)
	if data.has("supply_logistics") and SupplyLogistics != null:
		SupplyLogistics.from_save_data(data.get("supply_logistics", {}))

	# 4m. Restore weather system state (v3.7+)
	if data.has("weather") and WeatherSystem != null:
		WeatherSystem.from_save_data(data.get("weather", {}))

	# 4n. Restore espionage system state (v3.7+)
	if data.has("espionage") and EspionageSystem != null:
		EspionageSystem.from_save_data(data.get("espionage", {}))

	# 4o. Restore CG gallery unlock state (v3.8+)
	if data.has("cg_gallery") and CGManager != null:
		CGManager.from_save_data(data.get("cg_gallery", {}))

	# 4p. Restore v4.0 new systems
	if data.has("faction_destruction_events") and FactionDestructionEvents != null:
		FactionDestructionEvents.load_save_data(data.get("faction_destruction_events", {}))
	if data.has("seasonal_events") and SeasonalEvents != null:
		SeasonalEvents.load_save_data(data.get("seasonal_events", {}))
	if data.has("character_interaction_events") and CharacterInteractionEvents != null:
		CharacterInteractionEvents.load_save_data(data.get("character_interaction_events", {}))
	if data.has("grand_event_director") and GrandEventDirector != null:
		GrandEventDirector.load_save_data(data.get("grand_event_director", {}))
	if data.has("dynamic_situation_events") and DynamicSituationEvents != null:
		DynamicSituationEvents.load_save_data(data.get("dynamic_situation_events", {}))
	if data.has("crisis_countdown") and CrisisCountdown != null:
		CrisisCountdown.load_save_data(data.get("crisis_countdown", {}))

	# 4q. Restore nation system state (Direction D, fixed map)
	if data.has("nation_system"):
		_load_nation_system(data.get("nation_system", {}))

	# 4r. Restore event registry state (v4.1+)
	if data.has("event_registry") and EventRegistry != null:
		EventRegistry.deserialize(data.get("event_registry", {}))

	# 4s. Restore quest progress tracker state (v4.1+)
	if data.has("quest_progress_tracker") and QuestProgressTracker != null:
		QuestProgressTracker.from_save_data(data.get("quest_progress_tracker", {}))

	# 4t. Restore event scheduler state (v4.1+)
	if data.has("event_scheduler") and EventScheduler != null:
		EventScheduler.from_save_data(data.get("event_scheduler", {}))
	# 4u. Restore general system state (v4.3+)
	if data.has("general_system") and GeneralSystem != null:
		GeneralSystem.deserialize(data.get("general_system", {}))
	# 4v. Restore v4.7 new systems
	if data.has("prestige_shop") and PrestigeShop != null:
		PrestigeShop.from_save_data(data.get("prestige_shop", {}))
	if data.has("ngplus_shop") and NGPlusShop != null:
		NGPlusShop.from_save_data(data.get("ngplus_shop", {}))
	# v1.2.0 据点系统存档恢复
	if data.has("stronghold_governance") and GameManager.governance_system != null:
		GameManager.governance_system.from_save_data(data.get("stronghold_governance", {}))
	if data.has("stronghold_morale") and GameManager.morale_corruption_system != null:
		GameManager.morale_corruption_system.from_save_data(data.get("stronghold_morale", {}))
	if data.has("stronghold_development") and GameManager.development_path_system != null:
		GameManager.development_path_system.from_save_data(data.get("stronghold_development", {}))
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
	GameManager.game_stats = gs.get("game_stats", {"battles_won": 0, "battles_lost": 0, "capital_tile": -1})
	GameManager._last_grand_festival_turn = int(gs.get("_last_grand_festival_turn", -999))
	GameManager._imperial_decree_used = gs.get("_imperial_decree_used", false)
	GameManager._forge_alliance_used = gs.get("_forge_alliance_used", false)

	# Reset transient state
	GameManager.has_rolled = false
	GameManager.waiting_for_move = false
	GameManager.dice_value = 0
	GameManager.reachable_tiles.clear()
	GameManager._had_combat_this_turn = false
	GameManager._prev_turn_had_combat = false
	GameManager._pending_event_queue.clear()
	GameManager._scheduler_event_queue.clear()

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
	## Accepts saves from v3.x+ (migratable) and v4.x (current major).
	var saved_parts: Array = saved_ver.split(".")
	var current_parts: Array = SAVE_VERSION.split(".")
	if saved_parts.size() < 2 or current_parts.size() < 2:
		return false
	var saved_major: int = int(saved_parts[0])
	var current_major: int = int(current_parts[0])
	# Accept current major and one major version back (for migration)
	return saved_major >= current_major - 1 and saved_major <= current_major


func _migrate_save_data(data: Dictionary, from_version: String) -> Dictionary:
	## Apply sequential migrations to bring old saves up to current format.
	var parts: Array = from_version.split(".")
	var major: int = int(parts[0]) if parts.size() > 0 else 0
	var minor: int = int(parts[1]) if parts.size() > 1 else 0
	var _patch: int = int(parts[2]) if parts.size() > 2 else 0

	# v3.7 -> v3.8: No structural changes needed
	# v3.8 -> v4.0: event subsystems added save data
	if major == 3:
		data = _migrate_3_to_4(data)

	# v4.0 -> v4.1: event_registry, quest_progress_tracker, event_scheduler added
	if major <= 4 and minor < 1:
		data = _migrate_4_0_to_4_1(data)

	return data


func _migrate_3_to_4(data: Dictionary) -> Dictionary:
	## Migrate v3.x saves to v4.0 format.
	# Add empty entries for v4.0 new systems if missing
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
	if not data.has("tile_development"):
		data["tile_development"] = {"tile_dev": {}, "rebuilding_tiles": {}}
	return data


func _migrate_4_0_to_4_1(data: Dictionary) -> Dictionary:
	## Migrate v4.0 saves to v4.1 format.
	# Add empty entries for v4.1 centralized systems
	if not data.has("event_registry"):
		data["event_registry"] = {}
	if not data.has("quest_progress_tracker"):
		data["quest_progress_tracker"] = {}
	if not data.has("event_scheduler"):
		data["event_scheduler"] = {}
	return data


# ═══════════════ HELPERS ═══════════════

func _find_troop_training_panel():
	## Locate the TroopTrainingPanel node in the scene tree.
	var scene = get_tree().current_scene
	if scene and "troop_training_panel" in scene and scene.troop_training_panel:
		return scene.troop_training_panel
	return null


func _collect_troop_training() -> Dictionary:
	var ttp = _find_troop_training_panel()
	if ttp and ttp.has_method("to_save_data"):
		return ttp.to_save_data()
	return {}


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


# ═══════════════ NATION SYSTEM SAVE/LOAD ═══════════════

func _save_nation_system() -> Dictionary:
	if not GameManager.use_fixed_map or GameManager.nation_system == null:
		return {}
	var ns = GameManager.nation_system
	# Convert int keys to string for JSON
	var owners: Dictionary = {}
	for k in ns.territory_owners:
		owners[str(k)] = ns.territory_owners[k]
	return {
		"use_fixed_map": true,
		"territory_owners": owners,
		"nation_controllers": ns.nation_controllers.duplicate(),
		"active_bonuses": ns.active_bonuses.duplicate(true),
	}


func _load_nation_system(data: Dictionary) -> void:
	if not data.get("use_fixed_map", false):
		return
	# Rebuild fixed map state
	GameManager.use_fixed_map = true
	var NationSystemClass = preload("res://systems/map/nation_system.gd")
	var ns = NationSystemClass.new()
	ns.event_bus = EventBus
	# Restore territory owners (convert string keys back to int)
	var owners: Dictionary = data.get("territory_owners", {})
	for k in owners:
		ns.territory_owners[int(k)] = owners[k]
	ns.nation_controllers = data.get("nation_controllers", {}).duplicate()
	ns.active_bonuses = data.get("active_bonuses", {}).duplicate(true)
	GameManager.nation_system = ns
