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


func _ready() -> void:
	# Start with HUD hidden, menu visible (board stays visible - camera needs it)
	hud.visible = false

	# Connect main menu signal
	main_menu.game_started.connect(_on_game_started)

	# Create hero panel dynamically (no .tscn dependency for autoload-like behavior)
	var hero_panel_scene := preload("res://scenes/ui/hero_panel.tscn")
	hero_panel = hero_panel_scene.instantiate()
	add_child(hero_panel)

	# Wire combat view close to resume gameplay
	combat_view.combat_view_closed.connect(_on_combat_view_closed)


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
	pass


func show_combat_view(battle_result: Dictionary) -> void:
	## Call from GameManager after resolving combat to show animated battle.
	combat_view.show_battle(battle_result)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# ESC to show settings (if no other panel is open)
		if event.keycode == KEY_ESCAPE and GameManager.game_active:
			if hero_panel and hero_panel.is_panel_visible():
				return  # Let hero panel handle ESC first
			if combat_view.visible:
				return  # Let combat view handle ESC
			settings_panel.toggle_settings()
