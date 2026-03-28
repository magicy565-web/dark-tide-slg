## game_over_panel.gd - Full-screen game over overlay (v4.5)
## CanvasLayer with high layer to overlay on top of everything.
## Listens to EventBus.game_over_detailed for rich result data,
## falls back to EventBus.game_over for basic winner_id.
extends CanvasLayer

const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Theme ──
const BG_DIM := Color(0.0, 0.0, 0.0, 0.72)
const PANEL_BG_VICTORY := Color(0.12, 0.1, 0.02, 0.96)
const PANEL_BG_DEFEAT := Color(0.15, 0.04, 0.04, 0.96)
const BORDER_VICTORY := Color(0.85, 0.7, 0.3)
const BORDER_DEFEAT := Color(0.8, 0.15, 0.15)
const TEXT_GOLD := Color(1.0, 0.85, 0.35)
const TEXT_RED := Color(1.0, 0.3, 0.3)
const TEXT_DIM := Color(0.75, 0.75, 0.82)

# ── UI refs ──
var _overlay: ColorRect
var _panel: PanelContainer
var _panel_style: StyleBoxFlat
var _title_label: Label
var _subtitle_label: Label
var _reason_label: Label
var _stats_vbox: VBoxContainer
var _btn_new_game: Button
var _btn_main_menu: Button

# ── State ──
var _received_detailed: bool = false


func _ready() -> void:
	layer = 100
	visible = false
	_build_ui()
	EventBus.game_over_detailed.connect(_on_game_over_detailed)
	EventBus.game_over.connect(_on_game_over_fallback)


func _build_ui() -> void:
	# Full-screen dark overlay
	_overlay = ColorRect.new()
	_overlay.anchor_right = 1.0
	_overlay.anchor_bottom = 1.0
	_overlay.color = BG_DIM
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Centered panel
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -280
	_panel.offset_right = 280
	_panel.offset_top = -240
	_panel.offset_bottom = 240
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = PANEL_BG_VICTORY
	_panel_style.border_color = BORDER_VICTORY
	_panel_style.set_border_width_all(3)
	_panel_style.set_corner_radius_all(12)
	_panel_style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	_overlay.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	# Title: VICTORY / DEFEAT
	_title_label = _make_label("", 32, TEXT_GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# Subtitle: victory type or defeat reason
	_subtitle_label = _make_label("", 18, TEXT_GOLD)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_subtitle_label)

	# Defeat reason (hidden for victories)
	_reason_label = _make_label("", 14, TEXT_DIM)
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_reason_label)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	# Stats title
	var stats_title := _make_label("-- Battle Stats --", 14, TEXT_DIM)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_title)

	# Stats container
	_stats_vbox = VBoxContainer.new()
	_stats_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_stats_vbox)

	# Separator
	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	vbox.add_child(sep2)

	# Buttons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_hbox)

	_btn_new_game = _make_button("New Game")
	_btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_hbox.add_child(_btn_new_game)

	_btn_main_menu = _make_button("Return to Menu")
	_btn_main_menu.pressed.connect(_on_main_menu_pressed)
	btn_hbox.add_child(_btn_main_menu)


# ═══════════════════════════════════════════
#              SIGNAL HANDLERS
# ═══════════════════════════════════════════

func _on_game_over_detailed(data: Dictionary) -> void:
	_received_detailed = true
	var is_victory: bool = data.get("is_victory", false)
	var victory_type: String = data.get("victory_type", "")
	var reason: String = data.get("reason", "")
	_show(is_victory, victory_type, reason)


func _on_game_over_fallback(winner_id: int) -> void:
	# Only use fallback if detailed signal was not received this frame
	if _received_detailed:
		return
	# Defer to allow detailed signal to fire first
	await get_tree().process_frame
	if _received_detailed:
		return
	var human_id: int = GameManager.get_human_player_id()
	var is_victory: bool = (winner_id == human_id)
	_show(is_victory, "", "")


func _show(is_victory: bool, victory_type: String, reason: String) -> void:
	# Configure colors
	if is_victory:
		_title_label.text = "VICTORY"
		_title_label.add_theme_color_override("font_color", TEXT_GOLD)
		_subtitle_label.add_theme_color_override("font_color", TEXT_GOLD)
		_panel_style.bg_color = PANEL_BG_VICTORY
		_panel_style.border_color = BORDER_VICTORY
		_subtitle_label.text = victory_type if victory_type != "" else "Victory"
		_reason_label.text = ""
		_reason_label.visible = false
	else:
		_title_label.text = "DEFEAT"
		_title_label.add_theme_color_override("font_color", TEXT_RED)
		_subtitle_label.add_theme_color_override("font_color", TEXT_RED)
		_panel_style.bg_color = PANEL_BG_DEFEAT
		_panel_style.border_color = BORDER_DEFEAT
		_subtitle_label.text = "Game Over"
		if reason != "":
			_reason_label.text = reason
			_reason_label.visible = true
		else:
			_reason_label.text = ""
			_reason_label.visible = false

	# Populate stats
	_populate_stats()

	visible = true


func _populate_stats() -> void:
	for child in _stats_vbox.get_children():
		child.queue_free()

	var human_id: int = GameManager.get_human_player_id()

	# Turns played
	_add_stat("Turns Played: %d" % GameManager.turn_number)

	# Territory
	var owned: int = GameManager.count_tiles_owned(human_id)
	var total: int = GameManager.tiles.size()
	_add_stat("Tiles Controlled: %d / %d" % [owned, total])

	# Army strength
	var total_soldiers: int = 0
	for army_id in GameManager.armies:
		var army: Dictionary = GameManager.armies[army_id]
		if army["player_id"] == human_id:
			total_soldiers += GameManager.get_army_soldier_count(army_id)
	_add_stat("Army Strength: %d" % total_soldiers)

	# Heroes recruited
	if HeroSystem:
		var recruited: int = HeroSystem.recruited_heroes.size()
		var total_h: int = FactionData.HEROES.size()
		_add_stat("Heroes: %d / %d" % [recruited, total_h])

	# Gold
	var gold: int = ResourceManager.get_resource(human_id, "gold")
	_add_stat("Gold: %d" % gold)

	# Threat level
	if ThreatManager:
		_add_stat("Threat Level: %d" % ThreatManager.get_threat())


func _add_stat(text: String) -> void:
	var lbl := _make_label(text, 13, TEXT_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_vbox.add_child(lbl)


# ═══════════════════════════════════════════
#              BUTTON HANDLERS
# ═══════════════════════════════════════════

func _on_new_game_pressed() -> void:
	visible = false
	_received_detailed = false
	_reset_all_singletons()
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	visible = false
	_received_detailed = false
	_reset_all_singletons()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _reset_all_singletons() -> void:
	ResourceManager.reset()
	SlaveManager.reset()
	BuffManager.reset()
	ItemManager.reset()
	RelicManager.reset()
	OrderManager.reset()
	ThreatManager.reset()
	OrcMechanic.reset()
	PirateMechanic.reset()
	DarkElfMechanic.reset()
	FactionManager.reset()
	LightFactionAI.reset()
	AllianceAI.reset()
	EvilFactionAI.reset()
	DiplomacyManager.reset()
	NpcManager.reset()
	QuestManager.reset()
	StrategicResourceManager.reset()
	RecruitManager.reset()
	HeroSystem.reset()
	EventSystem.reset()
	AIScaling.reset()
	NeutralFactionAI.reset()
	QuestJournal.reset()
	StoryEventSystem.reset()
	if HeroLeveling.has_method("reset"):
		HeroLeveling.reset()
	else:
		HeroLeveling.hero_exp.clear()
		HeroLeveling.hero_level.clear()
		HeroLeveling.hero_unlocked_passives.clear()
		HeroLeveling.hero_current_hp.clear()
		HeroLeveling.hero_current_mp.clear()


# ═══════════════════════════════════════════
#              HELPERS
# ═══════════════════════════════════════════

func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 36)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.18, 0.15, 0.25, 0.9)
	normal_style.border_color = Color(0.5, 0.45, 0.3)
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(6)
	normal_style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal_style)
	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.2, 0.35, 0.95)
	hover_style.border_color = Color(0.8, 0.7, 0.4)
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.1, 0.08, 0.15, 0.95)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	return btn
