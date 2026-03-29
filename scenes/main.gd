## main.gd - Root scene controller for 暗潮 SLG (v1.5)
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

# ── Game over overlay (v4.5) ──
var game_over_panel_node = null


func _ready() -> void:
	# Start with HUD hidden, menu visible (board stays visible - camera needs it)
	hud.visible = false

	# Connect main menu signal
	main_menu.game_started.connect(_on_game_started)

	# Create hero panel dynamically (no .tscn dependency for autoload-like behavior)
	var hero_panel_scene := preload("res://scenes/ui/hero_panel.tscn")
	hero_panel = hero_panel_scene.instantiate()
	add_child(hero_panel)

	# Create quest journal panel dynamically
	var quest_panel_scene := preload("res://scenes/ui/quest_journal_panel.tscn")
	quest_journal_panel = quest_panel_scene.instantiate()
	add_child(quest_journal_panel)

	# Create code-only UI panels (no .tscn needed — they build UI in _ready)
	var DiplomacyPanelScript = preload("res://scenes/ui/diplomacy_panel.gd")
	diplomacy_panel = CanvasLayer.new()
	diplomacy_panel.set_script(DiplomacyPanelScript)
	add_child(diplomacy_panel)

	var TechTreePanelScript = preload("res://scenes/ui/tech_tree_panel.gd")
	tech_tree_panel = CanvasLayer.new()
	tech_tree_panel.set_script(TechTreePanelScript)
	add_child(tech_tree_panel)

	var InventoryPanelScript = preload("res://scenes/ui/inventory_panel.gd")
	inventory_panel = CanvasLayer.new()
	inventory_panel.set_script(InventoryPanelScript)
	add_child(inventory_panel)

	var HeroDetailPanelScript = preload("res://scenes/ui/hero_detail_panel.gd")
	hero_detail_panel_node = CanvasLayer.new()
	hero_detail_panel_node.set_script(HeroDetailPanelScript)
	add_child(hero_detail_panel_node)

	var PiratePanelScript = preload("res://scenes/ui/pirate_panel.gd")
	pirate_panel = CanvasLayer.new()
	pirate_panel.set_script(PiratePanelScript)
	add_child(pirate_panel)

	# Quest tracker (always-visible on-screen widget)
	var QuestTrackerScript = preload("res://scenes/ui/quest_tracker.gd")
	quest_tracker = CanvasLayer.new()
	quest_tracker.set_script(QuestTrackerScript)
	add_child(quest_tracker)

	# ── New depth system UI panels (v4.2) ──
	var WeatherHudScript = preload("res://scenes/ui/weather_hud.gd")
	weather_hud = CanvasLayer.new()
	weather_hud.set_script(WeatherHudScript)
	add_child(weather_hud)

	var EspionagePanelScript = preload("res://scenes/ui/espionage_panel.gd")
	espionage_panel = CanvasLayer.new()
	espionage_panel.set_script(EspionagePanelScript)
	add_child(espionage_panel)

	var SupplyOverlayScript = preload("res://scenes/ui/supply_overlay.gd")
	supply_overlay = CanvasLayer.new()
	supply_overlay.set_script(SupplyOverlayScript)
	add_child(supply_overlay)

	var FormationPreviewScript = preload("res://scenes/ui/formation_preview.gd")
	formation_preview = CanvasLayer.new()
	formation_preview.set_script(FormationPreviewScript)
	add_child(formation_preview)

	var CombatInterventionScript = preload("res://scenes/ui/combat_intervention_panel.gd")
	combat_intervention_panel = CanvasLayer.new()
	combat_intervention_panel.set_script(CombatInterventionScript)
	add_child(combat_intervention_panel)

	# Game over overlay (v4.5) — high-layer CanvasLayer that covers everything
	var GameOverPanelScript = preload("res://scenes/ui/game_over_panel.gd")
	game_over_panel_node = CanvasLayer.new()
	game_over_panel_node.set_script(GameOverPanelScript)
	add_child(game_over_panel_node)

	# Wire combat view close to resume gameplay
	combat_view.combat_view_closed.connect(_on_combat_view_closed)

	# Listen for combat view requests from GameManager
	EventBus.combat_view_requested.connect(_on_combat_view_requested)


func _on_game_started(faction_id: int) -> void:
	# Show the HUD
	hud.visible = true

	# Start the game with the chosen faction
	GameManager.start_game(faction_id)

	# Rebuild board with new game data
	if board.has_method("rebuild"):
		board.rebuild()
	EventBus.board_ready.emit()

	# Start tutorial for new games
	TutorialManager.start_tutorial()
	# Add tutorial UI to the scene tree
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# ESC to show settings (if no other panel is open)
		if event.keycode == KEY_ESCAPE and GameManager.game_active:
			if hero_panel and hero_panel.is_panel_visible():
				return  # Let hero panel handle ESC first
			if quest_journal_panel and quest_journal_panel.is_panel_visible():
				return  # Let quest journal handle ESC first
			if diplomacy_panel and diplomacy_panel.is_panel_visible():
				return
			if tech_tree_panel and tech_tree_panel.is_panel_visible():
				return
			if inventory_panel and inventory_panel.is_panel_visible():
				return
			if hero_detail_panel_node and hero_detail_panel_node.is_panel_visible():
				return
			if pirate_panel and pirate_panel.is_panel_visible():
				return
			if espionage_panel and espionage_panel.visible:
				espionage_panel.hide_panel()  # BUG FIX: call hide_panel() for proper cleanup
				return
			if combat_view.visible:
				return  # Let combat view handle ESC
			settings_panel.toggle_settings()
