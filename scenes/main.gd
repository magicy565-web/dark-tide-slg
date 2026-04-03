## main.gd - Root scene controller for 暗潮 SLG (v3.5)
## Manages game flow: MainMenu -> FactionSelect -> GameStart -> Gameplay
extends Node3D

# ── Scene refs ──
@onready var board: Node3D = $Board
@onready var hud: CanvasLayer = $HUD
@onready var main_menu = $MainMenu
@onready var event_popup = $EventPopup
@onready var combat_popup = $CombatPopup
@onready var notification_bar = $NotificationBar
@onready var save_load_panel = $SaveLoadPanel
@onready var combat_view = $CombatView
@onready var settings_panel = $SettingsPanel

# ── Hero panel (created at runtime) ──
var hero_panel = null

# ── Quest journal panel (created at runtime) ──
var quest_journal_panel = null

# ── Quest tracker widget (on-screen HUD) ──
var quest_tracker = null

# ── Additional UI panels (created at runtime, code-only) ──
var diplomacy_panel = null
var tech_tree_panel = null
var inventory_panel = null
var hero_detail_panel_node = null
var pirate_panel = null

# ── New depth systems UI (v4.2) ──
var weather_hud = null
var espionage_panel = null
var supply_overlay = null
var formation_preview = null
var combat_intervention_panel = null
var battle_prep_panel = null

# ── Game over overlay (v4.5) ──
var game_over_panel_node = null

# ── Army Management Panel (SR07-style) ──
var army_panel = null

# ── Mission Panel (Sengoku Rance-style manual story event trigger) ──
var mission_panel = null

# ── Territory Info Panel (comprehensive territory details) ──
var territory_info_panel = null

# ── v3.4 New panels ──
var ai_indicator = null
var debug_console = null
var troop_training_panel = null
var action_visualizer = null

# ── v3.5 Tile indicators & intel ──
var tile_indicator_system = null
var intel_overlay = null

# ── v3.6 Equipment Forge panel ──
var equipment_forge_panel = null

# ── v4.8: Nation & Multi-route panels ──
var nation_panel = null
var multi_route_panel = null


func _ready() -> void:
	# Start with HUD hidden, menu visible (board stays visible - camera needs it)
	hud.visible = false

	# Connect main menu signal
	main_menu.game_started.connect(_on_game_started)

	# Create hero panel dynamically (no .tscn dependency for autoload-like behavior)
	var hero_panel_scene := preload("res://scenes/ui/panels/hero_panel.tscn")
	hero_panel = hero_panel_scene.instantiate()
	add_child(hero_panel)

	# Create quest journal panel dynamically
	var quest_panel_scene := preload("res://scenes/ui/panels/quest_journal_panel.tscn")
	quest_journal_panel = quest_panel_scene.instantiate()
	add_child(quest_journal_panel)

	# Create code-only UI panels (no .tscn needed — they build UI in _ready)
	var DiplomacyPanelScript = preload("res://scenes/ui/panels/diplomacy_panel.gd")
	diplomacy_panel = CanvasLayer.new()
	diplomacy_panel.set_script(DiplomacyPanelScript)
	add_child(diplomacy_panel)

	var TechTreePanelScript = preload("res://scenes/ui/panels/tech_tree_panel.gd")
	tech_tree_panel = CanvasLayer.new()
	tech_tree_panel.set_script(TechTreePanelScript)
	add_child(tech_tree_panel)

	var InventoryPanelScript = preload("res://scenes/ui/panels/inventory_panel.gd")
	inventory_panel = CanvasLayer.new()
	inventory_panel.set_script(InventoryPanelScript)
	add_child(inventory_panel)

	var HeroDetailPanelScript = preload("res://scenes/ui/panels/hero_detail_panel.gd")
	hero_detail_panel_node = CanvasLayer.new()
	hero_detail_panel_node.set_script(HeroDetailPanelScript)
	add_child(hero_detail_panel_node)

	var PiratePanelScript = preload("res://scenes/ui/panels/pirate_panel.gd")
	pirate_panel = CanvasLayer.new()
	pirate_panel.set_script(PiratePanelScript)
	add_child(pirate_panel)

	# Mission panel (Sengoku Rance-style manual story event trigger)
	var MissionPanelScript = preload("res://scenes/ui/dialog/mission_panel.gd")
	mission_panel = CanvasLayer.new()
	mission_panel.set_script(MissionPanelScript)
	add_child(mission_panel)

	# Territory Info Panel (comprehensive territory details)
	var TerritoryInfoPanelScript = preload("res://scenes/ui/panels/territory_info_panel.gd")
	territory_info_panel = CanvasLayer.new()
	territory_info_panel.set_script(TerritoryInfoPanelScript)
	add_child(territory_info_panel)

	# Quest tracker (always-visible on-screen widget)
	var QuestTrackerScript = preload("res://scenes/ui/overlays/quest_tracker.gd")
	quest_tracker = CanvasLayer.new()
	quest_tracker.set_script(QuestTrackerScript)
	add_child(quest_tracker)

	# ── New depth system UI panels (v4.2) ──
	var WeatherHudScript = preload("res://scenes/ui/overlays/weather_hud.gd")
	weather_hud = CanvasLayer.new()
	weather_hud.set_script(WeatherHudScript)
	add_child(weather_hud)

	var EspionagePanelScript = preload("res://scenes/ui/panels/espionage_panel.gd")
	espionage_panel = CanvasLayer.new()
	espionage_panel.set_script(EspionagePanelScript)
	add_child(espionage_panel)

	var SupplyOverlayScript = preload("res://scenes/ui/overlays/supply_overlay.gd")
	supply_overlay = CanvasLayer.new()
	supply_overlay.set_script(SupplyOverlayScript)
	add_child(supply_overlay)

	var FormationPreviewScript = preload("res://scenes/ui/combat/formation_preview.gd")
	formation_preview = CanvasLayer.new()
	formation_preview.set_script(FormationPreviewScript)
	add_child(formation_preview)

	var CombatInterventionScript = preload("res://scenes/ui/combat/combat_intervention_panel.gd")
	combat_intervention_panel = CanvasLayer.new()
	combat_intervention_panel.set_script(CombatInterventionScript)
	add_child(combat_intervention_panel)

	var BattlePrepScript = preload("res://scenes/ui/combat/battle_prep_panel.gd")
	battle_prep_panel = CanvasLayer.new()
	battle_prep_panel.set_script(BattlePrepScript)
	add_child(battle_prep_panel)

	# Army Management Panel (SR07-style, code-only)
	var ArmyPanelScript = preload("res://scenes/ui/panels/army_panel.gd")
	army_panel = CanvasLayer.new()
	army_panel.name = "ArmyPanel"
	army_panel.set_script(ArmyPanelScript)
	add_child(army_panel)

	# Game over overlay (v4.5) — high-layer CanvasLayer that covers everything
	var GameOverPanelScript = preload("res://scenes/ui/system/game_over_panel.gd")
	game_over_panel_node = CanvasLayer.new()
	game_over_panel_node.set_script(GameOverPanelScript)
	add_child(game_over_panel_node)

	# ── v3.4: AI Indicator overlay ──
	var AIIndicatorScript = preload("res://scenes/ui/overlays/ai_indicator.gd")
	var ai_indicator_layer = CanvasLayer.new()
	ai_indicator_layer.layer = UILayerRegistry.LAYER_AI_INDICATOR
	add_child(ai_indicator_layer)
	ai_indicator = Control.new()
	ai_indicator.set_script(AIIndicatorScript)
	ai_indicator_layer.add_child(ai_indicator)

	# ── v3.4: Action Visualizer overlay ──
	var ActionVisualizerScript = preload("res://scenes/ui/overlays/action_visualizer.gd")
	var action_visualizer_layer = CanvasLayer.new()
	action_visualizer_layer.layer = UILayerRegistry.LAYER_ACTION_VISUALIZER
	add_child(action_visualizer_layer)
	action_visualizer = Control.new()
	action_visualizer.set_script(ActionVisualizerScript)
	action_visualizer_layer.add_child(action_visualizer)

	# ── v3.4: Troop Training Panel ──
	var TroopTrainingScript = preload("res://scenes/ui/panels/troop_training_panel.gd")
	troop_training_panel = CanvasLayer.new()
	troop_training_panel.set_script(TroopTrainingScript)
	add_child(troop_training_panel)

	# ── v3.4: Debug Console (highest layer) ──
	var DebugConsoleScript = preload("res://scenes/ui/system/debug_console.gd")
	var debug_console_layer = CanvasLayer.new()
	debug_console_layer.layer = UILayerRegistry.LAYER_DEBUG_CONSOLE
	add_child(debug_console_layer)
	debug_console = Control.new()
	debug_console.set_script(DebugConsoleScript)
	debug_console_layer.add_child(debug_console)

	# ── v3.5: Tile Indicator System (low layer, above board) ──
	var TileIndicatorScript = preload("res://scenes/ui/overlays/tile_indicator_system.gd")
	var tile_indicator_layer = CanvasLayer.new()
	tile_indicator_layer.layer = UILayerRegistry.LAYER_TILE_INDICATORS
	add_child(tile_indicator_layer)
	tile_indicator_system = Control.new()
	tile_indicator_system.set_script(TileIndicatorScript)
	tile_indicator_layer.add_child(tile_indicator_system)

	# ── v3.5: Intel Overlay (above tile indicators) ──
	var IntelOverlayScript = preload("res://scenes/ui/overlays/intel_overlay.gd")
	var intel_overlay_layer = CanvasLayer.new()
	intel_overlay_layer.layer = UILayerRegistry.LAYER_INTEL_OVERLAY
	add_child(intel_overlay_layer)
	intel_overlay = Control.new()
	intel_overlay.set_script(IntelOverlayScript)
	intel_overlay_layer.add_child(intel_overlay)

	# ── v3.6: Equipment Forge Panel ──
	var EquipmentForgePanelScript = preload("res://scenes/ui/panels/equipment_forge_panel.gd")
	equipment_forge_panel = CanvasLayer.new()
	equipment_forge_panel.set_script(EquipmentForgePanelScript)
	add_child(equipment_forge_panel)

	# ── v4.8: Nation Power Panel (fixed map, Key: N) ──
	var NationPanelScript = preload("res://scenes/ui/panels/nation_panel.gd")
	nation_panel = CanvasLayer.new()
	nation_panel.set_script(NationPanelScript)
	add_child(nation_panel)

	# ── v4.8: Multi-route Battle Panel (合战, Key: G) ──
	var MultiRoutePanelScript = preload("res://scenes/ui/combat/multi_route_panel.gd")
	multi_route_panel = CanvasLayer.new()
	multi_route_panel.set_script(MultiRoutePanelScript)
	add_child(multi_route_panel)

	# Wire combat view close to resume gameplay
	if combat_view.has_signal("combat_view_closed"):
		combat_view.combat_view_closed.connect(_on_combat_view_closed)
	else:
		push_warning("main.gd: CombatView script failed to load — combat_view_closed signal unavailable")

	# Listen for combat view requests from GameManager
	EventBus.combat_view_requested.connect(_on_combat_view_requested)

	# ── Register panels with PanelManager ──
	_register_panels()


func _on_game_started(faction_id: int, fixed_map: bool = false) -> void:
	# Show the HUD
	hud.visible = true

	# Start the game with the chosen faction
	GameManager.start_game(faction_id, fixed_map)

	# Rebuild board with new game data
	if board.has_method("rebuild"):
		board.rebuild()
	EventBus.board_ready.emit()

	# Start tutorial for new games (skipped if previously completed)
	TutorialManager.start_tutorial()
	# Add tutorial UI to the scene tree if tutorial is active
	if TutorialManager.is_active():
		var overlay := TutorialManager.get_overlay_control()
		var popup := TutorialManager.get_popup_control()
		if overlay.get_parent() == null:
			add_child(overlay)
		if popup.get_parent() == null:
			add_child(popup)


func _on_combat_view_closed() -> void:
	# Resume normal gameplay after watching battle
	# Re-enable HUD interaction
	hud.visible = true
	# Notify EventBus so other systems can respond (e.g., board refresh)
	EventBus.combat_view_closed.emit()
	# Refresh board visuals to reflect combat outcome
	if board.has_method("rebuild"):
		board.rebuild()


func _on_combat_view_requested(battle_result: Dictionary) -> void:
	## Triggered by EventBus when GameManager resolves combat.
	combat_view.show_battle(battle_result)


func _register_panels() -> void:
	# Modal panels — only one visible at a time (layers 5-11)
	PanelManager.register_panel("hero_panel", hero_panel, true)
	PanelManager.register_panel("quest_journal", quest_journal_panel, true)
	PanelManager.register_panel("diplomacy", diplomacy_panel, true)
	PanelManager.register_panel("tech_tree", tech_tree_panel, true)
	PanelManager.register_panel("inventory", inventory_panel, true)
	PanelManager.register_panel("hero_detail", hero_detail_panel_node, true)
	PanelManager.register_panel("pirate", pirate_panel, true)
	PanelManager.register_panel("mission", mission_panel, true)
	PanelManager.register_panel("territory_info", territory_info_panel, true)
	PanelManager.register_panel("troop_training", troop_training_panel, true)
	PanelManager.register_panel("equipment_forge", equipment_forge_panel, true)
	PanelManager.register_panel("nation", nation_panel, true)
	PanelManager.register_panel("multi_route", multi_route_panel, true)
	PanelManager.register_panel("army", army_panel, true)
	PanelManager.register_panel("event_popup", event_popup, true)
	PanelManager.register_panel("battle_prep", battle_prep_panel, true)
	PanelManager.register_panel("espionage", espionage_panel, true)
	# Non-modal panels (system overlays, persistent)
	PanelManager.register_panel("combat_popup", combat_popup, false)
	PanelManager.register_panel("combat_view", combat_view, false)
	PanelManager.register_panel("settings", settings_panel, false)
	PanelManager.register_panel("save_load", save_load_panel, false)
	PanelManager.register_panel("debug_console", debug_console, false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# ESC to show settings (if no other panel is open)
		if event.keycode == KEY_ESCAPE and GameManager.game_active:
			# Debug console has highest priority
			if debug_console and debug_console.has_method("is_panel_visible") and debug_console.is_panel_visible():
				return  # Let debug console handle ESC
			# Check if any modal panel is open — let it handle ESC itself
			if PanelManager.is_any_modal_open():
				return
			if combat_view.visible:
				return  # Let combat view handle ESC
			settings_panel.toggle_settings()
