## hud.gd - Action Selection HUD for Dark Tide SLG (v0.8 - Sengoku Rance style)
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Pixel art assets ──
var _panel_tex: Texture2D
var _btn_normal_tex: Texture2D
var _btn_hover_tex: Texture2D
var _btn_pressed_tex: Texture2D
var _icon_gold: Texture2D
var _icon_food: Texture2D
var _icon_iron: Texture2D
var _icon_slave: Texture2D
var _icon_prestige: Texture2D
var _icon_crystal: Texture2D
var _has_resource_icons: bool = false

func _safe_load(path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	return null

# ── Action mode state machine ──
enum ActionMode { NONE, ATTACK, DEPLOY, DOMESTIC, DIPLOMACY, EXPLORE, DOMESTIC_SUB, SELECT_ATTACK_TARGET, SELECT_DEPLOY_TARGET }

var _current_mode: int = ActionMode.NONE
var _domestic_sub_type: String = ""   # "recruit", "upgrade", "build"
var _selected_building_id: String = ""
var _selected_army_id: int = -1      # Army selected for attack/deploy action

# ── UI refs: top bar ──
var turn_label: Label
var gold_label: Label
var food_label: Label
var iron_label: Label
var slaves_label: Label
var prestige_label: Label
var army_label: Label
var pop_label: Label
var ap_label: Label
var stronghold_label: Label
var order_label: Label
var threat_label: Label
var waaagh_label: Label

var magic_crystal_label: Label
var war_horse_label: Label
var gunpowder_label: Label
var shadow_essence_label: Label

# ── UI refs: left action panel ──
var action_panel: PanelContainer
var btn_attack: Button
var btn_deploy: Button
var btn_domestic: Button
var btn_diplomacy: Button
var btn_explore: Button
var btn_end_turn: Button
var btn_reduce_threat: Button
var btn_boost_order: Button
var btn_sell_slave: Button
var btn_buy_slave: Button
var btn_hero: Button
var btn_research: Button
var btn_quest_journal: Button

# ── UI refs: center target selector ──
var target_panel: PanelContainer
var target_title_label: Label
var target_scroll: ScrollContainer
var target_container: VBoxContainer
var target_buttons: Array = []

# ── UI refs: domestic sub-menu ──
var domestic_panel: PanelContainer
var btn_recruit: Button
var btn_upgrade: Button
var btn_build: Button
var btn_army_view: Button

# ── UI refs: item panel ──
var item_panel: PanelContainer
var item_container: VBoxContainer
var item_buttons: Array = []

# ── UI refs: build selection (inside target panel) ──
var build_buttons: Array = []

# ── UI refs: right tile info ──
var tile_info_label: RichTextLabel

# ── UI refs: bottom message log ──
var message_log_label: RichTextLabel

# ── UI refs: game over overlay ──
var game_over_panel: PanelContainer
var game_over_label: Label
var game_over_victory_type_label: Label
var game_over_stats_vbox: VBoxContainer
var game_over_style: StyleBoxFlat

var messages: Array = []
const MAX_MESSAGES: int = 12


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 1
	_build_ui()
	_connect_signals()


func _connect_signals() -> void:
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.army_changed.connect(_on_army_changed)
	EventBus.player_arrived.connect(_on_player_arrived)
	EventBus.message_log.connect(_on_message_log)
	EventBus.game_over.connect(_on_game_over)
	EventBus.tile_captured.connect(_on_tile_captured)
	EventBus.item_acquired.connect(_on_item_changed)
	EventBus.item_used.connect(_on_item_changed)
	EventBus.building_constructed.connect(_on_building_constructed)
	# LEGACY: gold_changed/charm_changed are never emitted — kept for backward compat
	EventBus.gold_changed.connect(_on_legacy_changed)
	EventBus.charm_changed.connect(_on_legacy_changed)
	EventBus.territory_selected.connect(_on_territory_selected)
	EventBus.combat_result.connect(_on_combat_result)
	EventBus.order_changed.connect(_on_order_changed)
	EventBus.threat_changed.connect(_on_threat_changed)


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_panel_tex = _safe_load("res://assets/ui/panel_frame.png")
	_btn_normal_tex = _safe_load("res://assets/ui/btn_normal.png")
	_btn_hover_tex = _safe_load("res://assets/ui/btn_hover.png")
	_btn_pressed_tex = _safe_load("res://assets/ui/btn_pressed.png")
	_icon_gold = _safe_load("res://assets/ui/icon_gold_coin.png")
	_icon_food = _safe_load("res://assets/ui/icon_food_grain.png")
	_icon_iron = _safe_load("res://assets/ui/icon_iron_ore.png")
	_icon_slave = _safe_load("res://assets/ui/icon_slave_chain.png")
	_icon_prestige = _safe_load("res://assets/ui/icon_prestige_crown.png")
	_icon_crystal = _safe_load("res://assets/ui/icon_magic_crystal.png")
	_has_resource_icons = _icon_gold != null

	var root := Control.new()
	root.name = "HUDRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	_build_top_bar(root)
	_build_action_panel(root)
	_build_domestic_sub_panel(root)
	_build_target_panel(root)
	_build_item_panel(root)
	_build_tile_info(root)
	_build_message_log(root)
	_build_game_over(root)
	_build_minimap(root)


# ── Top bar (resources, turn info, strategic resources) ──

func _build_top_bar(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.offset_bottom = 58
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.06, 0.1, 0.92), 8))
	parent.add_child(panel)

	# Use a VBoxContainer to hold both rows so layout is automatic
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Row 1: core resources
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	turn_label = _make_label("Turn: ---", 14, Color.WHITE)
	turn_label.custom_minimum_size.x = 120
	hbox.add_child(turn_label)
	var gold_hb := _make_icon_label(_icon_gold, "0", 14, Color.GOLD, 50)
	gold_label = gold_hb.get_child(gold_hb.get_child_count() - 1)
	hbox.add_child(gold_hb)
	var food_hb := _make_icon_label(_icon_food, "0", 14, Color(0.6, 0.9, 0.4), 50)
	food_label = food_hb.get_child(food_hb.get_child_count() - 1)
	hbox.add_child(food_hb)
	var iron_hb := _make_icon_label(_icon_iron, "0", 14, Color(0.7, 0.7, 0.8), 50)
	iron_label = iron_hb.get_child(iron_hb.get_child_count() - 1)
	hbox.add_child(iron_hb)
	var slave_hb := _make_icon_label(_icon_slave, "0", 14, Color(0.9, 0.6, 0.3), 60)
	slaves_label = slave_hb.get_child(slave_hb.get_child_count() - 1)
	hbox.add_child(slave_hb)
	var prestige_hb := _make_icon_label(_icon_prestige, "0", 14, Color(1.0, 0.85, 0.3), 65)
	prestige_label = prestige_hb.get_child(prestige_hb.get_child_count() - 1)
	hbox.add_child(prestige_hb)
	army_label = _make_label("Army:0", 14, Color.LIGHT_BLUE)
	army_label.custom_minimum_size.x = 100
	hbox.add_child(army_label)
	pop_label = _make_label("Pop:0/0", 13, Color(0.9, 0.75, 0.5))
	pop_label.custom_minimum_size.x = 80
	hbox.add_child(pop_label)
	ap_label = _make_label("AP:0", 14, Color.LIGHT_GREEN)
	ap_label.custom_minimum_size.x = 45
	hbox.add_child(ap_label)
	stronghold_label = _make_label("Fort:0/4", 14, Color.ORANGE)
	stronghold_label.custom_minimum_size.x = 70
	hbox.add_child(stronghold_label)

	# Row 2: order / threat / waaagh / strategic resources
	var hbox2 := HBoxContainer.new()
	hbox2.add_theme_constant_override("separation", 24)
	hbox2.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox2)

	order_label = _make_label("Order:50", 12, Color(0.5, 0.8, 1.0))
	order_label.custom_minimum_size.x = 90
	hbox2.add_child(order_label)
	threat_label = _make_label("Threat:0", 12, Color(1.0, 0.4, 0.3))
	threat_label.custom_minimum_size.x = 90
	hbox2.add_child(threat_label)
	waaagh_label = _make_label("", 12, Color(1.0, 0.2, 0.1))
	waaagh_label.custom_minimum_size.x = 80
	hbox2.add_child(waaagh_label)
	var crystal_hb := _make_icon_label(_icon_crystal, "0", 11, Color(0.6, 0.4, 1.0), 55)
	magic_crystal_label = crystal_hb.get_child(crystal_hb.get_child_count() - 1)
	hbox2.add_child(crystal_hb)
	war_horse_label = _make_label("Horse:0", 11, Color(0.8, 0.6, 0.3))
	war_horse_label.custom_minimum_size.x = 55
	hbox2.add_child(war_horse_label)
	gunpowder_label = _make_label("Gunpowder:0", 11, Color(0.9, 0.5, 0.2))
	gunpowder_label.custom_minimum_size.x = 55
	hbox2.add_child(gunpowder_label)
	shadow_essence_label = _make_label("Shadow:0", 11, Color(0.5, 0.2, 0.7))
	shadow_essence_label.custom_minimum_size.x = 55
	hbox2.add_child(shadow_essence_label)


# ── Left panel: main action buttons ──

func _build_action_panel(parent: Control) -> void:
	action_panel = PanelContainer.new()
	action_panel.position = Vector2(10, 60)
	action_panel.size = Vector2(200, 560)
	action_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	action_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.06, 0.1, 0.88)))
	parent.add_child(action_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	action_panel.add_child(vbox)

	var title := _make_label("Actions", 15, Color(0.8, 0.8, 0.9))
	vbox.add_child(title)

	btn_attack = _make_button("Attack (1AP)")
	btn_attack.pressed.connect(_on_attack_pressed)
	vbox.add_child(btn_attack)

	btn_deploy = _make_button("Deploy (1AP)")
	btn_deploy.pressed.connect(_on_deploy_pressed)
	vbox.add_child(btn_deploy)

	btn_domestic = _make_button("Domestic (1AP)")
	btn_domestic.pressed.connect(_on_domestic_pressed)
	vbox.add_child(btn_domestic)

	btn_diplomacy = _make_button("Diplomacy (1AP)")
	btn_diplomacy.pressed.connect(_on_diplomacy_pressed)
	vbox.add_child(btn_diplomacy)

	btn_explore = _make_button("Explore (1AP)")
	btn_explore.pressed.connect(_on_explore_pressed)
	vbox.add_child(btn_explore)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	# Prestige actions
	btn_reduce_threat = _make_button("Reduce Threat -10 (20 Prestige)")
	btn_reduce_threat.pressed.connect(_on_reduce_threat)
	vbox.add_child(btn_reduce_threat)

	btn_boost_order = _make_button("Boost Order +10 (15 Prestige)")
	btn_boost_order.pressed.connect(_on_boost_order)
	vbox.add_child(btn_boost_order)

	# Pirate slave trade (shown conditionally)
	btn_sell_slave = _make_button("Sell Slave (25g)")
	btn_sell_slave.pressed.connect(_on_sell_slave)
	btn_sell_slave.visible = false
	vbox.add_child(btn_sell_slave)

	btn_buy_slave = _make_button("Buy Slave (40g)")
	btn_buy_slave.pressed.connect(_on_buy_slave)
	btn_buy_slave.visible = false
	vbox.add_child(btn_buy_slave)

	# Hero & Research buttons (free actions)
	var sep_hero := HSeparator.new()
	sep_hero.add_theme_constant_override("separation", 4)
	vbox.add_child(sep_hero)

	btn_hero = _make_button("Heroes (H)")
	btn_hero.pressed.connect(_on_hero_pressed)
	vbox.add_child(btn_hero)

	btn_research = _make_button("Research")
	btn_research.pressed.connect(_on_research_pressed)
	vbox.add_child(btn_research)

	btn_quest_journal = _make_button("Quest Log (J)")
	btn_quest_journal.pressed.connect(_on_quest_journal_pressed)
	vbox.add_child(btn_quest_journal)

	# Save/Load buttons (free actions)
	var btn_save := _make_button("Save (F5)")
	btn_save.pressed.connect(_on_save_pressed)
	vbox.add_child(btn_save)

	var btn_load := _make_button("Load (F9)")
	btn_load.pressed.connect(_on_load_pressed)
	vbox.add_child(btn_load)

	# Separator before end turn
	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	vbox.add_child(sep2)

	btn_end_turn = _make_button("End Turn")
	btn_end_turn.pressed.connect(_on_end_turn_pressed)
	vbox.add_child(btn_end_turn)


# ── Domestic sub-menu (recruit / upgrade / build) ──

func _build_domestic_sub_panel(parent: Control) -> void:
	domestic_panel = PanelContainer.new()
	domestic_panel.position = Vector2(220, 60)
	domestic_panel.size = Vector2(160, 160)
	domestic_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	domestic_panel.visible = false
	domestic_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.06, 0.14, 0.92)))
	parent.add_child(domestic_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	domestic_panel.add_child(vbox)

	var title := _make_label("Domestic Menu", 13, Color(0.7, 0.8, 0.9))
	vbox.add_child(title)

	btn_recruit = _make_button("Recruit")
	btn_recruit.custom_minimum_size = Vector2(140, 30)
	btn_recruit.pressed.connect(_on_domestic_recruit)
	vbox.add_child(btn_recruit)

	btn_upgrade = _make_button("Upgrade Territory")
	btn_upgrade.custom_minimum_size = Vector2(140, 30)
	btn_upgrade.pressed.connect(_on_domestic_upgrade)
	vbox.add_child(btn_upgrade)

	btn_build = _make_button("Build")
	btn_build.custom_minimum_size = Vector2(140, 30)
	btn_build.pressed.connect(_on_domestic_build)
	vbox.add_child(btn_build)

	btn_army_view = _make_button("Army Overview")
	btn_army_view.custom_minimum_size = Vector2(140, 30)
	btn_army_view.pressed.connect(_on_army_view)
	vbox.add_child(btn_army_view)


# ── Center panel: target / tile selector ──

func _build_target_panel(parent: Control) -> void:
	target_panel = PanelContainer.new()
	target_panel.anchor_left = 0.0
	target_panel.anchor_right = 0.0
	target_panel.position = Vector2(220, 60)
	target_panel.size = Vector2(420, 400)
	target_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	target_panel.visible = false
	target_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.07, 0.12, 0.92)))
	parent.add_child(target_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	target_panel.add_child(vbox)

	# Header row: title + close button
	var header := HBoxContainer.new()
	vbox.add_child(header)

	target_title_label = _make_label("Targets", 14, Color(0.9, 0.85, 0.7))
	target_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(target_title_label)

	var btn_close := Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(28, 28)
	btn_close.add_theme_font_size_override("font_size", 12)
	btn_close.pressed.connect(_close_target_panel)
	header.add_child(btn_close)

	# Scrollable list area
	target_scroll = ScrollContainer.new()
	target_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	target_scroll.custom_minimum_size = Vector2(280, 300)
	vbox.add_child(target_scroll)

	target_container = VBoxContainer.new()
	target_container.add_theme_constant_override("separation", 3)
	target_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_scroll.add_child(target_container)


# ── Item panel ──

func _build_item_panel(parent: Control) -> void:
	item_panel = PanelContainer.new()
	item_panel.position = Vector2(10, 450)
	item_panel.size = Vector2(200, 130)
	item_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	item_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.06, 0.1, 0.88)))
	parent.add_child(item_panel)

	item_container = VBoxContainer.new()
	item_container.add_theme_constant_override("separation", 3)
	item_panel.add_child(item_container)

	var title := _make_label("Inventory", 14, Color(0.8, 0.8, 0.9))
	item_container.add_child(title)


# ── Right panel: tile info ──

func _build_tile_info(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -250
	panel.offset_right = -10
	panel.offset_top = 60
	panel.offset_bottom = 360
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.06, 0.08, 0.12, 0.9)))
	parent.add_child(panel)

	tile_info_label = RichTextLabel.new()
	tile_info_label.bbcode_enabled = true
	tile_info_label.fit_content = true
	tile_info_label.scroll_active = false
	tile_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_info_label.text = "[b]Current Location[/b]\nWaiting for game to start..."
	tile_info_label.add_theme_font_size_override("normal_font_size", 12)
	panel.add_child(tile_info_label)


# ── Bottom: message log ──

func _build_message_log(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -160
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.04, 0.04, 0.08, 0.85)))
	parent.add_child(panel)

	message_log_label = RichTextLabel.new()
	message_log_label.bbcode_enabled = true
	message_log_label.scroll_following = true
	message_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_log_label.add_theme_font_size_override("normal_font_size", 11)
	message_log_label.add_theme_color_override("default_color", Color(0.8, 0.8, 0.85))
	panel.add_child(message_log_label)


# ── Game over overlay ──

func _build_game_over(parent: Control) -> void:
	game_over_panel = PanelContainer.new()
	game_over_panel.anchor_left = 0.5
	game_over_panel.anchor_right = 0.5
	game_over_panel.anchor_top = 0.5
	game_over_panel.anchor_bottom = 0.5
	game_over_panel.offset_left = -250
	game_over_panel.offset_right = 250
	game_over_panel.offset_top = -200
	game_over_panel.offset_bottom = 200
	game_over_panel.visible = false
	game_over_style = StyleBoxFlat.new()
	game_over_style.bg_color = Color(0.1, 0.06, 0.15, 0.95)
	game_over_style.border_color = Color.GOLD
	game_over_style.set_border_width_all(3)
	game_over_style.set_corner_radius_all(10)
	game_over_style.set_content_margin_all(20)
	game_over_panel.add_theme_stylebox_override("panel", game_over_style)
	parent.add_child(game_over_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	game_over_panel.add_child(vbox)

	game_over_label = _make_label("Game Over!", 26, Color.GOLD)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(game_over_label)

	game_over_victory_type_label = _make_label("", 18, Color.GOLD)
	game_over_victory_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(game_over_victory_type_label)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	var stats_title := _make_label("-- Battle Stats --", 14, Color(0.7, 0.7, 0.8))
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_title)

	game_over_stats_vbox = VBoxContainer.new()
	game_over_stats_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(game_over_stats_vbox)

	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	vbox.add_child(sep2)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_hbox)

	var restart := _make_button("Restart")
	restart.pressed.connect(_on_restart_pressed)
	btn_hbox.add_child(restart)

	var main_menu_btn := _make_button("Main Menu")
	main_menu_btn.pressed.connect(_on_return_main_menu_pressed)
	btn_hbox.add_child(main_menu_btn)


var minimap_anchor: Control

func _build_minimap(parent: Control) -> void:
	## Bottom-right minimap container — board.setup_minimap() fills it on board_ready.
	minimap_anchor = Control.new()
	minimap_anchor.name = "MinimapAnchor"
	minimap_anchor.anchor_left = 1.0
	minimap_anchor.anchor_right = 1.0
	minimap_anchor.anchor_top = 1.0
	minimap_anchor.anchor_bottom = 1.0
	minimap_anchor.offset_left = -196
	minimap_anchor.offset_top = -156
	minimap_anchor.offset_right = -8
	minimap_anchor.offset_bottom = -8
	minimap_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(minimap_anchor)

	# Border frame around minimap
	var frame := PanelContainer.new()
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color(0.05, 0.05, 0.08, 0.8)
	frame_style.border_color = Color(0.5, 0.45, 0.3)
	frame_style.set_border_width_all(1)
	frame_style.set_corner_radius_all(4)
	frame_style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	minimap_anchor.add_child(frame)

	# Hook into board_ready to request minimap setup
	EventBus.board_ready.connect(_on_board_ready_minimap)


func _on_board_ready_minimap() -> void:
	var board_node = get_tree().get_root().find_child("Board", true, false)
	if board_node and board_node.has_method("setup_minimap"):
		board_node.setup_minimap(minimap_anchor)


# ═══════════════════════════════════════════════════════════════
#                  TARGET PANEL MANAGEMENT
# ═══════════════════════════════════════════════════════════════

func _clear_target_buttons() -> void:
	for btn in target_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	target_buttons.clear()


func _close_target_panel() -> void:
	_current_mode = ActionMode.NONE
	_domestic_sub_type = ""
	_selected_building_id = ""
	target_panel.visible = false
	domestic_panel.visible = false
	_clear_target_buttons()


func _show_target_panel(title_text: String) -> void:
	_clear_target_buttons()
	target_title_label.text = title_text
	domestic_panel.visible = false
	target_panel.visible = true


func _add_target_button(label_text: String, callback: Callable, is_disabled: bool = false) -> void:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(270, 32)
	btn.add_theme_font_size_override("font_size", 12)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.disabled = is_disabled
	btn.pressed.connect(callback)
	target_container.add_child(btn)
	target_buttons.append(btn)


func _add_target_label(label_text: String, color: Color = Color(0.6, 0.6, 0.65)) -> void:
	var lbl := _make_label(label_text, 11, color)
	target_container.add_child(lbl)
	target_buttons.append(lbl)  # tracked so _clear_target_buttons can free it


# ═══════════════════════════════════════════════════════════════
#              MAIN ACTION BUTTON CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_attack_pressed() -> void:
	if _current_mode == ActionMode.ATTACK:
		_close_target_panel()
		return
	_current_mode = ActionMode.ATTACK
	_selected_army_id = -1
	var pid: int = GameManager.get_human_player_id()
	var armies: Array = GameManager.get_player_armies(pid)

	_show_target_panel("Attack - Select Army")

	if armies.is_empty():
		_add_target_label("(No armies available)")
		return

	for army in armies:
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var power: int = GameManager.get_army_combat_power(army["id"])
		var tile_idx: int = army.get("tile_index", -1)
		var tile_name: String = GameManager.tiles[tile_idx]["name"] if tile_idx >= 0 and tile_idx < GameManager.tiles.size() else "???"
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		var label_text: String = "%s (Troops:%d Power:%d) @%s" % [army["name"], soldiers, power, tile_name]
		if attackable.is_empty():
			label_text += " [No Target]"
		_add_target_button(label_text, _on_attack_army_selected.bind(army["id"]), attackable.is_empty())


func _on_attack_army_selected(army_id: int) -> void:
	_selected_army_id = army_id
	_current_mode = ActionMode.SELECT_ATTACK_TARGET
	var army: Dictionary = GameManager.get_army(army_id)
	var attackable: Array = GameManager.get_army_attackable_tiles(army_id)

	_show_target_panel("Attack - %s -> Select Target" % army["name"])

	if attackable.is_empty():
		_add_target_label("(No attackable territories)")
		return

	for tidx in attackable:
		var tile: Dictionary = GameManager.tiles[tidx]
		var label_text: String = "%s (Lv%d)" % [tile["name"], tile["level"]]
		if tile["garrison"] > 0:
			label_text += " Garrison:%d" % tile["garrison"]
		if tile["owner_id"] >= 0:
			var owner: Dictionary = GameManager.get_player_by_id(tile["owner_id"])
			label_text += " [%s]" % owner.get("name", "???")
		_add_target_button(label_text, _on_attack_target.bind(tidx))


func _on_deploy_pressed() -> void:
	if _current_mode == ActionMode.DEPLOY:
		_close_target_panel()
		return
	_current_mode = ActionMode.DEPLOY
	_selected_army_id = -1
	var pid: int = GameManager.get_human_player_id()
	var armies: Array = GameManager.get_player_armies(pid)

	_show_target_panel("Deploy - Select Army")

	if armies.is_empty():
		_add_target_label("(No armies available)")
		return

	for army in armies:
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var tile_idx: int = army.get("tile_index", -1)
		var tile_name: String = GameManager.tiles[tile_idx]["name"] if tile_idx >= 0 and tile_idx < GameManager.tiles.size() else "???"
		var deployable: Array = GameManager.get_army_deployable_tiles(army["id"])
		var label_text: String = "%s (Troops:%d) @%s" % [army["name"], soldiers, tile_name]
		if deployable.is_empty():
			label_text += " [Cannot Move]"
		_add_target_button(label_text, _on_deploy_army_selected.bind(army["id"]), deployable.is_empty())


func _on_deploy_army_selected(army_id: int) -> void:
	_selected_army_id = army_id
	_current_mode = ActionMode.SELECT_DEPLOY_TARGET
	var army: Dictionary = GameManager.get_army(army_id)
	var deployable: Array = GameManager.get_army_deployable_tiles(army_id)

	_show_target_panel("Deploy - %s -> Destination" % army["name"])

	if deployable.is_empty():
		_add_target_label("(No reachable territories)")
		return

	for tidx in deployable:
		var tile: Dictionary = GameManager.tiles[tidx]
		_add_target_button("%s (Lv%d)" % [tile["name"], tile["level"]], _on_deploy_target.bind(tidx))


func _on_domestic_pressed() -> void:
	if _current_mode == ActionMode.DOMESTIC:
		_close_target_panel()
		return
	_current_mode = ActionMode.DOMESTIC
	target_panel.visible = false
	_clear_target_buttons()

	# Update domestic sub-menu button texts and states
	var pid: int = GameManager.get_human_player_id()
	var player: Dictionary = GameManager.get_player_by_id(pid)
	var army_size: int = RecruitManager.get_army(pid).size()
	var pop_cap: int = RecruitManager._get_pop_cap(pid)
	btn_recruit.text = "Recruit (%d/%d slots)" % [army_size, pop_cap]
	btn_recruit.disabled = player.get("ap", 0) < 1
	btn_upgrade.disabled = not GameManager.can_upgrade()
	btn_build.disabled = not GameManager.can_build_any()

	domestic_panel.visible = true


func _on_diplomacy_pressed() -> void:
	if _current_mode == ActionMode.DIPLOMACY:
		_close_target_panel()
		return
	_current_mode = ActionMode.DIPLOMACY
	var pid: int = GameManager.get_human_player_id()
	var targets: Array = GameManager.get_diplomacy_targets(pid)

	_show_target_panel("Diplomacy - Select Target")

	if targets.is_empty():
		_add_target_label("(No diplomatic targets)")
		return

	for entry in targets:
		var label_text: String = entry.get("name", "???")
		if entry.get("recruited", false):
			label_text += " [Recruited]"
		else:
			# Show taming level and tier
			var taming: int = entry.get("taming_level", 0)
			var tier_str: String = entry.get("taming_tier", "hostile")
			var tier_label: String = ""
			match tier_str:
				"hostile": tier_label = "Hostile"
				"neutral": tier_label = "Neutral"
				"friendly": tier_label = "Friendly"
				"allied": tier_label = "Allied"
				"tamed": tier_label = "Tamed"
			label_text += " [Taming:%d/10 %s]" % [taming, tier_label]
			if entry.get("quest_step", 0) > 0:
				label_text += " Quest:%d/%d" % [entry.get("quest_step", 0), entry.get("max_steps", 3)]
			# Show unlocked troops
			var unlocked: Array = entry.get("unlocked_troops", [])
			if not unlocked.is_empty():
				label_text += " Recruitable: %d types" % unlocked.size()
		_add_target_button(label_text, _on_diplomacy_target.bind(entry))


func _on_explore_pressed() -> void:
	if _current_mode == ActionMode.EXPLORE:
		_close_target_panel()
		return
	_current_mode = ActionMode.EXPLORE
	var pid: int = GameManager.get_human_player_id()
	var tiles: Array = GameManager.get_explorable_tiles(pid)

	_show_target_panel("Explore - Select Target")

	if tiles.is_empty():
		_add_target_label("(No explorable territories)")
		return

	for tile in tiles:
		var tidx: int = tile["index"]
		var label_text: String = "%s" % tile["name"]
		_add_target_button(label_text, _on_explore_target.bind(tidx))


# ═══════════════════════════════════════════════════════════════
#             TARGET SELECTION CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_attack_target(tile_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	if _selected_army_id >= 0:
		GameManager.action_attack_with_army(_selected_army_id, tile_index)
	else:
		GameManager.action_attack(pid, tile_index)
	_selected_army_id = -1
	_close_target_panel()
	_after_action()


func _on_deploy_target(tile_index: int) -> void:
	if _selected_army_id >= 0:
		GameManager.action_deploy_army(_selected_army_id, tile_index)
	_selected_army_id = -1
	_close_target_panel()
	_after_action()


func _on_diplomacy_target(entry: Dictionary) -> void:
	var pid: int = GameManager.get_human_player_id()
	var faction_id: int = entry.get("faction_id", -1)
	GameManager.action_diplomacy(pid, faction_id)
	_close_target_panel()
	_after_action()


func _on_explore_target(tile_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	GameManager.action_explore(pid, tile_index)
	_close_target_panel()
	_after_action()


# ═══════════════════════════════════════════════════════════════
#             DOMESTIC SUB-MENU CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_domestic_recruit() -> void:
	# Show troop selection panel (Phase 3 troop composition system)
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "recruit"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	var player: Dictionary = GameManager.get_player_by_id(pid)
	# Use selected tile or first owned tile for recruit context
	var tile_idx: int = player.get("position", 0)
	var board_node = get_tree().get_root().find_child("Board", true, false)
	if board_node and board_node.has_method("get_selected_tile"):
		var sel: int = board_node.get_selected_tile()
		if sel >= 0 and sel < GameManager.tiles.size() and GameManager.tiles[sel]["owner_id"] == pid:
			tile_idx = sel
	var tile: Dictionary = GameManager.tiles[tile_idx]

	_show_target_panel("Recruit - Select Troop")

	var available: Array = RecruitManager.get_available_units(pid, tile)
	if available.is_empty():
		_add_target_label("(No recruitable troops here)")
		return

	# Show army status header
	var army_summary: Array = RecruitManager.get_army_summary(pid)
	var pop_cap: int = RecruitManager._get_pop_cap(pid)
	_add_target_label("Army: %d/%d slots" % [army_summary.size(), pop_cap])

	# Show current army composition
	if not army_summary.is_empty():
		var army_text: String = "Current: "
		for entry in army_summary:
			var vet_str: String = " [%s]" % entry["veterancy"] if entry["veterancy"] != "" else ""
			army_text += "%s(%d/%d)%s " % [entry["name"], entry["soldiers"], entry["max_soldiers"], vet_str]
		_add_target_label(army_text)

	# List available troops
	for entry in available:
		var cost_str: String = ""
		for key in entry["cost"]:
			cost_str += "%s:%d " % [key, entry["cost"][key]]
		var tier_str: String = "T%d" % entry["tier"]
		var passive_name: String = ""
		var pdef: Dictionary = GameData.PASSIVE_DEFS.get(entry.get("passive", ""), {})
		if not pdef.is_empty():
			passive_name = pdef.get("name", "")

		var label_text: String = "[%s] %s (%s) ATK:%d DEF:%d Troops:%d | %s" % [
			tier_str, entry["name"], entry["troop_class_name"] if entry.has("troop_class_name") else GameData.get_class_name(entry.get("troop_class", 0)),
			entry["base_atk"], entry.get("base_def", 0), entry["max_soldiers"],
			cost_str.strip_edges()
		]
		if passive_name != "":
			label_text += " [%s]" % passive_name
		if entry.get("is_mercenary", false):
			label_text += " (Merc)"
		if entry.get("synergy", "") != "":
			label_text += " ★%s" % entry["synergy"]

		var btn := Button.new()
		btn.text = label_text
		btn.custom_minimum_size = Vector2(380, 32)
		btn.add_theme_font_size_override("font_size", 11)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.disabled = not entry["can_recruit"]
		btn.pressed.connect(_on_recruit_troop.bind(entry["troop_id"], tile))
		target_container.add_child(btn)
		target_buttons.append(btn)

		# Tooltip / description line
		if entry.get("desc", "") != "":
			var desc_label: Label = _make_label("  %s" % entry["desc"], 10, Color(0.6, 0.6, 0.7))
			target_container.add_child(desc_label)


func _on_recruit_troop(troop_id: String, tile: Dictionary) -> void:
	var pid: int = GameManager.get_human_player_id()
	var player: Dictionary = GameManager.get_player_by_id(pid)
	if player.is_empty() or player.get("ap", 0) < 1:
		EventBus.message_log.emit("Not enough AP!")
		return
	var success: bool = RecruitManager.recruit_unit(pid, troop_id, tile)
	if success:
		player["ap"] -= 1
		player["army_count"] = ResourceManager.get_army(pid)
		_update_player_info()
		# Refresh the recruit panel to show updated state
		_on_domestic_recruit()
	else:
		EventBus.message_log.emit("Recruit failed - insufficient resources or army full")


func _on_army_view() -> void:
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "army_view"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	_show_target_panel("Army Overview")

	var summary: Array = RecruitManager.get_army_summary(pid)
	if summary.is_empty():
		_add_target_label("(No troops in army)")
		return

	var pop_cap: int = RecruitManager._get_pop_cap(pid)
	_add_target_label("Roster: %d/%d | Total: %d" % [summary.size(), pop_cap, RecruitManager.get_total_soldiers(pid)])

	# Faction passive display
	var ftag: String = GameManager._get_faction_tag_for_player(pid)
	var fp: Dictionary = GameData.get_faction_passive(ftag)
	if not fp.is_empty():
		_add_target_label("Faction Trait: %s -- %s" % [fp.get("name", ""), fp.get("desc", "")], Color(0.8, 0.7, 0.4))

	# Slave conversion status (Dark Elf)
	if ftag == "dark_elf":
		var conv_status: Array = SlaveManager.get_conversion_status(pid)
		if not conv_status.is_empty():
			for cs in conv_status:
				_add_target_label("  Converting: %d prisoners (%d turns left)" % [cs["count"], cs["turns_left"]], Color(0.7, 0.5, 0.8))

	# Troop list
	for entry in summary:
		var tier_str: String = "T%d" % entry["tier"]
		var vet_str: String = ""
		if entry["veterancy"] != "":
			vet_str = " [%s]" % entry["veterancy"]

		var passive_name: String = ""
		var pdef: Dictionary = GameData.PASSIVE_DEFS.get(entry.get("passive", ""), {})
		if not pdef.is_empty():
			passive_name = pdef.get("name", "")

		var line1: String = "[%s] %s (%s/%s) ATK:%d DEF:%d Troops:%d/%d%s" % [
			tier_str, entry["name"], entry["class_name"], entry["row"],
			entry["atk"], entry["def"],
			entry["soldiers"], entry["max_soldiers"], vet_str
		]
		if entry["synergy"] != "":
			line1 += " ★%s" % entry["synergy"]
		if passive_name != "":
			line1 += " [%s]" % passive_name

		_add_target_label(line1, Color(0.8, 0.85, 0.9))

		# Active ability status
		if entry["ability"] != "":
			var used_str: String = "Used" if entry["ability_used"] else "Ready"
			_add_target_label("  Skill: %s (%s)" % [entry["ability"], used_str], Color(0.6, 0.75, 0.6))

		# Upkeep
		if entry["upkeep"] > 0:
			_add_target_label("  Upkeep: %d food/turn | EXP: %d" % [entry["upkeep"], entry["experience"]], Color(0.55, 0.55, 0.6))


func _on_domestic_upgrade() -> void:
	# Show owned tiles that can be upgraded
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "upgrade"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	_show_target_panel("Upgrade Territory - Select")

	var found: bool = false
	for i in range(GameManager.tiles.size()):
		var tile: Dictionary = GameManager.tiles[i]
		if tile["owner_id"] == pid and tile["level"] < GameManager.MAX_TILE_LEVEL:
			var cost: Array = GameManager.UPGRADE_COSTS[tile["level"]]
			var label_text: String = "%s Lv%d -> Lv%d (%d gold %d iron)" % [
				tile["name"], tile["level"], tile["level"] + 1, cost[0], cost[1]
			]
			var can_afford: bool = ResourceManager.can_afford(pid, {"gold": cost[0], "iron": cost[1]})
			var btn := Button.new()
			btn.text = label_text
			btn.custom_minimum_size = Vector2(270, 32)
			btn.add_theme_font_size_override("font_size", 12)
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.disabled = not can_afford
			btn.pressed.connect(_on_domestic_upgrade_target.bind(i))
			target_container.add_child(btn)
			target_buttons.append(btn)
			found = true

	if not found:
		_add_target_label("(No upgradable territories)")


func _on_domestic_build() -> void:
	# Show owned tiles that can have buildings
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "build"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	_show_target_panel("Build - Select Territory")

	var found: bool = false
	for i in range(GameManager.tiles.size()):
		var tile: Dictionary = GameManager.tiles[i]
		if tile["owner_id"] == pid and tile.get("building_id", "") == "":
			var label_text: String = "%s (Lv%d)" % [tile["name"], tile["level"]]
			_add_target_button(label_text, _on_domestic_build_tile.bind(i))
			found = true

	if not found:
		_add_target_label("(No buildable territories)")


func _on_domestic_upgrade_target(tile_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	GameManager.action_domestic(pid, tile_index, "upgrade")
	_close_target_panel()
	_after_action()


func _on_domestic_build_tile(tile_index: int) -> void:
	# Show available buildings for this tile
	var pid: int = GameManager.get_human_player_id()
	var tile: Dictionary = GameManager.tiles[tile_index]
	var available: Array = BuildingRegistry.get_available_buildings_for(pid, tile)

	_show_target_panel("Build - %s" % tile["name"])

	if available.is_empty():
		_add_target_label("(No buildings available)")
		return

	for b in available:
		var label_text: String = "%s" % b.get("name", b["id"])
		var cost: Dictionary = b.get("cost", {})
		if not cost.is_empty():
			var cost_parts: Array = []
			if cost.get("gold", 0) > 0:
				cost_parts.append("%dg" % cost["gold"])
			if cost.get("iron", 0) > 0:
				cost_parts.append("%d iron" % cost["iron"])
			if cost.get("slaves", 0) > 0:
				cost_parts.append("%d slaves" % cost["slaves"])
			if not cost_parts.is_empty():
				label_text += " (%s)" % " ".join(cost_parts)
		var btn := Button.new()
		btn.text = label_text
		btn.custom_minimum_size = Vector2(270, 32)
		btn.add_theme_font_size_override("font_size", 12)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.disabled = not b.get("can_build", false)
		btn.pressed.connect(_on_domestic_build_confirm.bind(tile_index, b["id"]))
		target_container.add_child(btn)
		target_buttons.append(btn)


func _on_domestic_build_confirm(tile_index: int, building_id: String) -> void:
	var pid: int = GameManager.get_human_player_id()
	GameManager.action_domestic(pid, tile_index, "build", building_id)
	_close_target_panel()
	_after_action()


# ═══════════════════════════════════════════════════════════════
#            PRESTIGE / SLAVE TRADE / END TURN
# ═══════════════════════════════════════════════════════════════

func _on_reduce_threat() -> void:
	FactionManager.spend_prestige_reduce_threat(GameManager.get_human_player_id())
	_after_action()


func _on_boost_order() -> void:
	FactionManager.spend_prestige_boost_order(GameManager.get_human_player_id())
	_after_action()


func _on_sell_slave() -> void:
	PirateMechanic.sell_slave(GameManager.get_human_player_id())
	_after_action()


func _on_buy_slave() -> void:
	PirateMechanic.buy_slave(GameManager.get_human_player_id())
	_after_action()


func _on_hero_pressed() -> void:
	# Hero panel is managed by main.gd scene — find it via tree
	var hero_panel = get_tree().get_root().find_child("HeroPanel", true, false)
	if hero_panel and hero_panel.has_method("show_panel"):
		hero_panel.show_panel()


func _on_quest_journal_pressed() -> void:
	var quest_panel = get_tree().get_root().find_child("QuestJournalPanel", true, false)
	if quest_panel and quest_panel.has_method("show_panel"):
		quest_panel.show_panel()


func _on_research_pressed() -> void:
	# Show research/training tree in target panel
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "research"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	_show_target_panel("Research Tree")

	# Get research state from ResearchManager
	if not ResearchManager.has_method("get_research_status"):
		_add_target_label("(Loading research system...)")
		return

	var status: Dictionary = ResearchManager.get_research_status(pid)
	if status.is_empty():
		_add_target_label("(No available research)")
		return

	# Show current research
	var current: Dictionary = status.get("current", {})
	if not current.is_empty():
		_add_target_label("Researching: %s (%d/%d)" % [
			current.get("name", "???"),
			current.get("progress", 0),
			current.get("cost", 0)
		], Color(0.4, 0.8, 1.0))

	# Show available research
	var available: Array = status.get("available", [])
	for entry in available:
		var label_text: String = "%s (Cost:%d)" % [entry.get("name", "???"), entry.get("cost", 0)]
		if entry.get("desc", "") != "":
			label_text += "\n  %s" % entry["desc"]
		var btn := Button.new()
		btn.text = label_text
		btn.custom_minimum_size = Vector2(380, 36)
		btn.add_theme_font_size_override("font_size", 11)
		btn.disabled = not entry.get("can_research", false)
		btn.pressed.connect(_on_start_research.bind(entry.get("tech_id", "")))
		target_container.add_child(btn)
		target_buttons.append(btn)

	# Show completed research
	var completed: Array = status.get("completed", [])
	if not completed.is_empty():
		_add_target_label("\nCompleted:", Color(0.5, 0.7, 0.4))
		for tech_name in completed:
			_add_target_label("  %s" % tech_name, Color(0.4, 0.6, 0.35))


func _on_start_research(tech_id: String) -> void:
	var pid: int = GameManager.get_human_player_id()
	if ResearchManager.has_method("start_research"):
		ResearchManager.start_research(pid, tech_id)
		EventBus.message_log.emit("Started research: %s" % tech_id)
		# Refresh the panel
		_on_research_pressed()


func _on_save_pressed() -> void:
	var save_panel = get_tree().get_root().find_child("SaveLoadPanel", true, false)
	if save_panel and save_panel.has_method("show_save"):
		save_panel.show_save()


func _on_load_pressed() -> void:
	var save_panel = get_tree().get_root().find_child("SaveLoadPanel", true, false)
	if save_panel and save_panel.has_method("show_load"):
		save_panel.show_load()


func _on_end_turn_pressed() -> void:
	_close_target_panel()
	GameManager.end_turn()


func _on_item_pressed(item_id: String) -> void:
	GameManager.use_item(item_id)
	_update_items()
	_update_player_info()
	_update_buttons()


func _on_restart_pressed() -> void:
	game_over_panel.visible = false
	messages.clear()
	message_log_label.text = ""
	_reset_all_singletons()
	get_tree().reload_current_scene()


func _on_return_main_menu_pressed() -> void:
	game_over_panel.visible = false
	messages.clear()
	message_log_label.text = ""
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


func _detect_victory_type(human_id: int) -> String:
	# Check conquest: all light strongholds / core fortresses owned
	var total_sh: int = 0
	var human_sh: int = 0
	for tile in GameManager.tiles:
		if tile["type"] == GameManager.TileType.LIGHT_STRONGHOLD or tile["type"] == GameManager.TileType.CORE_FORTRESS:
			if tile.get("original_faction", -1) != -1 or tile["type"] == GameManager.TileType.LIGHT_STRONGHOLD:
				total_sh += 1
				if tile["owner_id"] == human_id:
					human_sh += 1
	if total_sh > 0 and human_sh >= total_sh:
		return "Conquest Victory"

	# Check domination: >= 60% tiles
	var total_tiles: int = GameManager.tiles.size()
	var human_tiles: int = GameManager.count_tiles_owned(human_id)
	if total_tiles > 0 and float(human_tiles) / float(total_tiles) >= 0.60:
		return "Domination Victory"

	# Check shadow dominion: threat >= 100 + ultimate unit
	var threat: int = ThreatManager.get_threat()
	var has_ultimate: bool = false
	for army_id in GameManager.armies:
		var army: Dictionary = GameManager.armies[army_id]
		if army["player_id"] != human_id:
			continue
		for troop in army["troops"]:
			var tid: String = troop.get("troop_id", "")
			if tid in ["beast_ultimate", "leviathan_ultimate", "shadow_dragon_ultimate"]:
				has_ultimate = true
				break
			if GameData.TROOP_TYPES.has(tid):
				var td: Dictionary = GameData.TROOP_TYPES[tid]
				if td.get("category", -1) == GameData.TroopCategory.ULTIMATE:
					has_ultimate = true
					break
		if has_ultimate:
			break
	if threat >= 100 and has_ultimate:
		return "Shadow Domination"

	# Check harem victory
	var human_faction: int = GameManager.get_player_faction(human_id)
	if human_faction == FactionData.FactionID.PIRATE and HeroSystem.check_harem_victory():
		return "Harem Victory"

	return "Victory"


func _get_victory_stats(player_id: int) -> Array:
	var stats: Array = []
	stats.append("Turns: %d" % GameManager.turn_number)

	var owned: int = GameManager.count_tiles_owned(player_id)
	var total: int = GameManager.tiles.size()
	stats.append("Territory: %d/%d" % [owned, total])

	var total_soldiers: int = 0
	for army_id in GameManager.armies:
		var army: Dictionary = GameManager.armies[army_id]
		if army["player_id"] == player_id:
			total_soldiers += GameManager.get_army_soldier_count(army_id)
	stats.append("Army: %d" % total_soldiers)

	var recruited: int = HeroSystem.recruited_heroes.size()
	var total_heroines: int = FactionData.HEROES.size()
	stats.append("Heroines: %d/%d" % [recruited, total_heroines])

	var player_gold: int = ResourceManager.get_resource(player_id, "gold")
	stats.append("Gold: %d" % player_gold)

	return stats
# ═══════════════════════════════════════════════════════════════
#                  POST-ACTION REFRESH
# ═══════════════════════════════════════════════════════════════

func _after_action() -> void:
	_update_player_info()
	_update_tile_info()
	_update_buttons()
	_update_items()


# ═══════════════════════════════════════════════════════════════
#                  STATE UPDATES
# ═══════════════════════════════════════════════════════════════

func _update_buttons() -> void:
	if not GameManager.game_active:
		_set_all_buttons_disabled(true)
		return

	var player: Dictionary = GameManager.get_current_player()
	if player.is_empty():
		return
	var is_human: bool = not player.get("is_ai", true)
	var pid: int = player.get("id", 0)
	var faction_id: int = GameManager.get_player_faction(pid)

	if not is_human or GameManager.waiting_for_move:
		_set_all_buttons_disabled(true)
		btn_end_turn.disabled = not is_human
		return

	var has_ap: bool = player.get("ap", 0) >= 1

	# Main four action buttons -- all require at least 1 AP
	btn_attack.disabled = not has_ap
	btn_deploy.disabled = not has_ap
	btn_domestic.disabled = not has_ap
	btn_diplomacy.disabled = not has_ap
	btn_explore.disabled = not has_ap

	# End turn is always available to the human player (player decides when to stop)
	btn_end_turn.disabled = false

	# Prestige buttons (free actions, no AP cost)
	btn_reduce_threat.disabled = not ResourceManager.can_afford(pid, {"prestige": 20})
	btn_boost_order.disabled = not ResourceManager.can_afford(pid, {"prestige": 15})

	# Pirate slave trade visibility
	var is_pirate: bool = faction_id == FactionData.FactionID.PIRATE
	btn_sell_slave.visible = is_pirate
	btn_buy_slave.visible = is_pirate
	if is_pirate:
		btn_sell_slave.disabled = ResourceManager.get_slaves(pid) <= 0
		btn_buy_slave.disabled = not ResourceManager.can_afford(pid, {"gold": 40})

	# Highlight active mode button
	_set_mode_highlight(btn_attack, _current_mode == ActionMode.ATTACK or _current_mode == ActionMode.SELECT_ATTACK_TARGET)
	_set_mode_highlight(btn_deploy, _current_mode == ActionMode.DEPLOY or _current_mode == ActionMode.SELECT_DEPLOY_TARGET)
	_set_mode_highlight(btn_domestic, _current_mode == ActionMode.DOMESTIC)
	_set_mode_highlight(btn_diplomacy, _current_mode == ActionMode.DIPLOMACY)
	_set_mode_highlight(btn_explore, _current_mode == ActionMode.EXPLORE)


func _set_mode_highlight(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	else:
		btn.remove_theme_color_override("font_color")


func _set_all_buttons_disabled(val: bool) -> void:
	btn_attack.disabled = val
	btn_deploy.disabled = val
	btn_domestic.disabled = val
	btn_diplomacy.disabled = val
	btn_explore.disabled = val
	btn_end_turn.disabled = val
	btn_reduce_threat.disabled = val
	btn_boost_order.disabled = val
	btn_sell_slave.disabled = val
	btn_buy_slave.disabled = val


func _update_player_info() -> void:
	if GameManager.players.is_empty():
		return
	var pid: int = GameManager.get_human_player_id()
	var player: Dictionary = GameManager.get_player_by_id(pid)
	if player.is_empty():
		return

	turn_label.text = "Turn %d %s" % [GameManager.turn_number, player.get("name", "???")]
	turn_label.add_theme_color_override("font_color", player.get("color", Color.WHITE))

	gold_label.text = str(ResourceManager.get_resource(pid, "gold")) if _has_resource_icons else "Gold:%d" % ResourceManager.get_resource(pid, "gold")
	food_label.text = str(ResourceManager.get_resource(pid, "food")) if _has_resource_icons else "Food:%d" % ResourceManager.get_resource(pid, "food")
	iron_label.text = str(ResourceManager.get_resource(pid, "iron")) if _has_resource_icons else "Iron:%d" % ResourceManager.get_resource(pid, "iron")
	slaves_label.text = ("%d/%d" % [ResourceManager.get_slaves(pid), ResourceManager.get_slave_capacity(pid)]) if _has_resource_icons else "Slaves:%d/%d" % [ResourceManager.get_slaves(pid), ResourceManager.get_slave_capacity(pid)]
	prestige_label.text = str(ResourceManager.get_resource(pid, "prestige")) if _has_resource_icons else "Prestige:%d" % ResourceManager.get_resource(pid, "prestige")
	army_label.text = "Army:%d (%d units)" % [RecruitManager.get_total_soldiers(pid), RecruitManager._get_army_ref(pid).size()]
	var pop_cap: int = GameManager.get_population_cap(pid)
	pop_label.text = "Roster:%d/%d" % [RecruitManager._get_army_ref(pid).size(), pop_cap]
	ap_label.text = "AP:%d" % player.get("ap", 0)
	stronghold_label.text = "Fort:%s" % GameManager.get_stronghold_progress(pid)

	order_label.text = "Order:%d (x%.2f)" % [OrderManager.get_order(), OrderManager.get_production_multiplier()]
	threat_label.text = "Threat:%d [%s]" % [ThreatManager.get_threat(), ThreatManager.get_tier_name()]

	# WAAAGH! display for Orc faction
	var faction_id: int = GameManager.get_player_faction(pid)
	if faction_id == FactionData.FactionID.ORC:
		var w: int = OrcMechanic.get_waaagh(pid)
		waaagh_label.text = "WAAAGH!:%d" % w
		waaagh_label.visible = true
		if OrcMechanic.is_in_frenzy(pid):
			waaagh_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))
		else:
			waaagh_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
	else:
		waaagh_label.visible = false

	# Food deficit warning
	var food_needed: int = ProductionCalculator.calculate_food_upkeep(pid)
	if ResourceManager.get_resource(pid, "food") < food_needed:
		food_label.add_theme_color_override("font_color", Color.RED)
	else:
		food_label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.4))

	# Strategic resources
	magic_crystal_label.text = str(ResourceManager.get_resource(pid, "magic_crystal")) if _has_resource_icons else "Crystal:%d" % ResourceManager.get_resource(pid, "magic_crystal")
	war_horse_label.text = "Horse:%d" % ResourceManager.get_resource(pid, "war_horse")
	gunpowder_label.text = "Gunpowder:%d" % ResourceManager.get_resource(pid, "gunpowder")
	shadow_essence_label.text = "Shadow:%d" % ResourceManager.get_resource(pid, "shadow_essence")


func _update_tile_info() -> void:
	if GameManager.players.is_empty() or GameManager.tiles.is_empty():
		return
	var player: Dictionary = GameManager.get_current_player()
	if player.is_empty():
		return
	var pid: int = player.get("id", 0)
	# Use selected tile from board, or first owned tile as fallback
	var tile_idx: int = 0
	var board_node = get_tree().get_root().find_child("Board", true, false)
	if board_node and board_node.has_method("get_selected_tile"):
		var sel: int = board_node.get_selected_tile()
		if sel >= 0 and sel < GameManager.tiles.size():
			tile_idx = sel
	if tile_idx == 0:
		# Fallback: find first tile owned by this player
		for i in range(GameManager.tiles.size()):
			if GameManager.tiles[i]["owner_id"] == pid:
				tile_idx = i
				break
	var tile: Dictionary = GameManager.tiles[tile_idx]
	var type_name: String = GameManager.TILE_NAMES.get(tile["type"], "Unknown")

	var info: String = "[b]%s[/b] (Lv%d)\nType: %s\n" % [tile["name"], tile["level"], type_name]

	if tile["owner_id"] >= 0:
		var prod: Dictionary = GameManager.get_tile_production(tile)
		info += "Output: Gold %d Food %d Iron %d Pop %d\n" % [prod["gold"], prod["food"], prod["iron"], prod["pop"]]

	if tile["owner_id"] == pid:
		info += "[color=green]Captured[/color]\n"
		var bld: String = tile.get("building_id", "")
		if bld != "":
			var bld_level: int = tile.get("building_level", 1)
			var max_level: int = BuildingRegistry.get_building_max_level(bld)
			info += "Building: [color=orchid]%s[/color] (Lv%d/%d)\n" % [BuildingRegistry.get_building_name(bld), bld_level, max_level]
		else:
			info += "[color=gray]Can build[/color]\n"
		var stype: String = tile.get("resource_station_type", "")
		if stype != "":
			info += "[color=cyan]Resource output: %s[/color]\n" % stype
	elif tile["owner_id"] >= 0:
		var _owner = GameManager.get_player_by_id(tile["owner_id"])
		var oname: String = _owner.get("name", "Enemy") if _owner else "Enemy"
		info += "[color=red]%s Captured[/color]\n" % oname
	else:
		if tile["garrison"] > 0:
			info += "Garrison: %d\n" % tile["garrison"]

	if tile.get("light_faction", -1) >= 0:
		info += "Light Alliance: %s\n" % FactionData.LIGHT_FACTION_NAMES.get(tile["light_faction"], "Unknown")

	if tile.get("neutral_faction_id", -1) >= 0:
		var nf_id: int = tile["neutral_faction_id"]
		var nf_name: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf_id, "Unknown")
		if NeutralFactionAI.is_vassal(nf_id):
			info += "[color=lime]Vassal: %s[/color]\n" % nf_name
		else:
			info += "Neutral Faction: %s\n" % nf_name
		# Show territory info
		var territory: Array = NeutralFactionAI.get_faction_territory(nf_id)
		info += "Territory nodes: %d\n" % territory.size()

	if tile["owner_id"] == pid and tile["level"] < GameManager.MAX_TILE_LEVEL:
		var cost: Array = GameManager.UPGRADE_COSTS[tile["level"]]
		info += "\n[color=yellow]Upgrade->Lv%d: %d gold %d iron[/color]" % [tile["level"] + 1, cost[0], cost[1]]

	info += "\n\nFortress Progress:"
	for p in GameManager.players:
		info += "\n  %s: %s" % [p["name"], GameManager.get_stronghold_progress(p["id"])]

	tile_info_label.text = info


func _update_items() -> void:
	for btn in item_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	item_buttons.clear()

	if GameManager.players.is_empty():
		return

	var pid: int = GameManager.get_human_player_id()
	var player: Dictionary = GameManager.get_player_by_id(pid)
	var inventory: Array = ItemManager.get_inventory(pid)

	if inventory.is_empty():
		var empty_lbl := _make_label("(Empty)", 11, Color(0.5, 0.5, 0.55))
		item_container.add_child(empty_lbl)
		item_buttons.append(empty_lbl)
		return

	for i in range(inventory.size()):
		var entry: Dictionary = inventory[i]
		var btn := Button.new()
		btn.text = "%s" % entry["name"]
		btn.tooltip_text = entry["desc"]
		btn.custom_minimum_size = Vector2(180, 28)
		btn.add_theme_font_size_override("font_size", 11)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_item_pressed.bind(entry["item_id"]))
		item_container.add_child(btn)
		item_buttons.append(btn)


# ═══════════════════════════════════════════════════════════════
#                  SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_turn_started(_player_id: int) -> void:
	_close_target_panel()
	_update_player_info()
	_update_tile_info()
	_update_buttons()
	_update_items()


func _on_turn_ended(_player_id: int) -> void:
	_close_target_panel()
	_update_buttons()


func _on_resources_changed(_pid: int) -> void:
	_update_player_info()


func _on_army_changed(_pid: int, _val: int) -> void:
	_update_player_info()


func _on_legacy_changed(_pid: int, _val: int) -> void:
	_update_player_info()


func _on_player_arrived(_pid: int, _tidx: int) -> void:
	_update_player_info()
	_update_tile_info()
	_update_buttons()


func _on_dice_rolled(_pid: int, _val: int) -> void:
	_update_player_info()
	_update_buttons()


func _on_tile_captured(_pid: int, _tidx: int) -> void:
	_update_tile_info()
	_update_buttons()
	_update_player_info()


func _on_item_changed(_pid: int, _name: String) -> void:
	_update_items()


func _on_reachable_computed(_indices: Array) -> void:
	_update_buttons()


func _on_building_constructed(_pid: int, _tidx: int, _bid: String) -> void:
	_update_tile_info()
	_update_buttons()
	_update_player_info()


func _on_territory_selected(tile_index: int) -> void:
	# Update tile info panel when a territory is clicked on the map
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	# Show the tile info for the selected territory
	_update_tile_info_for(tile_index)


func _update_tile_info_for(tile_index: int) -> void:
	if GameManager.tiles.is_empty():
		return
	var tile: Dictionary = GameManager.tiles[tile_index]
	var pid: int = GameManager.get_human_player_id()
	var type_name: String = GameManager.TILE_NAMES.get(tile["type"], "Unknown")
	var terrain: int = tile.get("terrain", FactionData.TerrainType.PLAINS)

	var tdata: Dictionary = FactionData.TERRAIN_DATA.get(terrain, {})
	var terrain_name: String = tdata.get("name", "Unknown")

	var info: String = "[b]%s[/b] (Lv%d)\n" % [tile["name"], tile["level"]]
	info += "Type: %s | Terrain: %s\n" % [type_name, terrain_name]

	# Terrain combat modifiers
	var t_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain, {}) if "TERRAIN_DATA" in FactionData else {}
	if not t_data.is_empty():
		var atk_m: float = t_data.get("atk_mult", 1.0)
		var def_m: float = t_data.get("def_mult", 1.0)
		if atk_m != 1.0 or def_m != 1.0:
			info += "[color=gray]Combat mod: ATK×%.2f DEF×%.2f[/color]\n" % [atk_m, def_m]

	# Terrain move cost & attrition tooltip
	var move_cost: int = tdata.get("move_cost", 1)
	var attrition_pct: float = tdata.get("attrition_pct", 0.0)
	if move_cost > 1 or attrition_pct > 0.0:
		var extra_info: String = "[color=gray]Move cost: %dAP" % move_cost
		if attrition_pct > 0.0:
			extra_info += " | Attrition: %.0f%%/turn" % (attrition_pct * 100.0)
		extra_info += "[/color]\n"
		info += extra_info

	# Chokepoint
	if tile.get("is_chokepoint", false):
		info += "[color=orange]Chokepoint: ATK-10% DEF+20%[/color]\n"

	# Owner info
	if tile["owner_id"] == pid:
		info += "[color=green]Own territory[/color]\n"
		var prod: Dictionary = GameManager.get_tile_production(tile) if GameManager.has_method("get_tile_production") else {}
		if not prod.is_empty():
			info += "Output: Gold %d Food %d Iron %d\n" % [prod.get("gold", 0), prod.get("food", 0), prod.get("iron", 0)]
		var bld: String = tile.get("building_id", "")
		if bld != "":
			info += "Building: [color=orchid]%s[/color] Lv%d\n" % [BuildingRegistry.get_building_name(bld), tile.get("building_level", 1)]
	elif tile["owner_id"] >= 0:
		var _owner = GameManager.get_player_by_id(tile["owner_id"])
		var oname: String = _owner.get("name", "Enemy") if _owner else "Enemy"
		info += "[color=red]%s Captured[/color]\n" % oname
	else:
		info += "[color=gray]Unclaimed[/color]\n"

	# Garrison
	var garrison: int = tile.get("garrison", 0)
	if garrison > 0:
		info += "Garrison: %d\n" % garrison

	# Army stationed here (v0.9.2)
	var army: Dictionary = GameManager.get_army_at_tile(tile_index)
	if not army.is_empty():
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var power: int = GameManager.get_army_combat_power(army["id"])
		var troop_count: int = army["troops"].size()
		info += "[color=yellow]━━ Army: %s ━━[/color]\n" % army["name"]
		info += "Troop roster: %d/%d | Total troops: %d | Power: %d\n" % [troop_count, GameManager.MAX_TROOPS_PER_ARMY, soldiers, power]
		if army["player_id"] == pid:
			var tile_idx: int = army.get("tile_index", -1)
			var on_enemy: bool = tile_idx >= 0 and tile_idx < GameManager.tiles.size() and GameManager.tiles[tile_idx]["owner_id"] != pid and GameManager.tiles[tile_idx]["owner_id"] >= 0
			if on_enemy:
				info += "[color=orange]Supply: Enemy territory (%.0f%% attrition/turn)[/color]\n" % (BalanceConfig.SUPPLY_ENEMY_TERRITORY_ATTRITION * 100.0)
			else:
				info += "[color=green]Supply: Normal[/color]\n"

	# Neutral faction
	if tile.get("neutral_faction_id", -1) >= 0:
		var nf_id2: int = tile["neutral_faction_id"]
		var nf_name2: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf_id2, "Unknown")
		if NeutralFactionAI.is_vassal(nf_id2):
			info += "[color=lime]Vassal: %s[/color]\n" % nf_name2
		else:
			info += "Neutral Faction: %s\n" % nf_name2

	# Light faction
	if tile.get("light_faction", -1) >= 0:
		info += "Light Alliance: %s\n" % FactionData.LIGHT_FACTION_NAMES.get(tile["light_faction"], "Unknown")

	# Wall HP
	var wall_hp: int = tile.get("wall_hp", 0)
	if wall_hp > 0:
		info += "Wall HP: %d\n" % wall_hp

	tile_info_label.text = info


func _on_message_log(text: String) -> void:
	messages.append(text)
	if messages.size() > MAX_MESSAGES:
		messages.pop_front()
	var display: String = ""
	for msg in messages:
		display += msg + "\n"
	message_log_label.text = display


func _on_game_over(winner_id: int) -> void:
	var human_id: int = GameManager.get_human_player_id()
	var is_victory: bool = (winner_id == human_id)

	# ── Determine victory type ──
	var victory_type: String = ""
	if is_victory:
		victory_type = _detect_victory_type(human_id)
		game_over_label.text = "%s Wins!" % GameManager.get_player_by_id(human_id).get("name", "Player")
		game_over_label.add_theme_color_override("font_color", Color.GOLD)
		game_over_victory_type_label.text = victory_type
		game_over_victory_type_label.add_theme_color_override("font_color", Color.GOLD)
		game_over_style.border_color = Color.GOLD
		game_over_style.bg_color = Color(0.12, 0.1, 0.02, 0.95)
	else:
		victory_type = "Defeat"
		game_over_label.text = "Game Over..."
		game_over_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		game_over_victory_type_label.text = victory_type
		game_over_victory_type_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		game_over_style.border_color = Color(0.8, 0.15, 0.15)
		game_over_style.bg_color = Color(0.15, 0.04, 0.04, 0.95)

	# ── Populate stats ──
	for child in game_over_stats_vbox.get_children():
		child.queue_free()
	var stats: Array = _get_victory_stats(human_id)
	for stat_text in stats:
		var lbl := _make_label(stat_text, 13, Color(0.85, 0.85, 0.9))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_over_stats_vbox.add_child(lbl)

	game_over_panel.visible = true
	_update_buttons()


func _on_combat_result(_attacker_id: int, _defender_desc: String, _won: bool) -> void:
	# Refresh all UI after combat resolves
	_update_tile_info()
	_update_buttons()


func _on_order_changed(_new_value: int) -> void:
	_update_player_info()

func _on_threat_changed(_new_value: int) -> void:
	_update_player_info()


# ═══════════════════════════════════════════════════════════════
#                       HELPERS
# ═══════════════════════════════════════════════════════════════

func _make_panel_style(fallback_color: Color = Color(0.06, 0.06, 0.1, 0.88), margin: int = 12) -> StyleBox:
	if _panel_tex:
		var stex := StyleBoxTexture.new()
		stex.texture = _panel_tex
		stex.texture_margin_left = margin
		stex.texture_margin_right = margin
		stex.texture_margin_top = margin
		stex.texture_margin_bottom = margin
		stex.content_margin_left = 8
		stex.content_margin_right = 8
		stex.content_margin_top = 8
		stex.content_margin_bottom = 8
		return stex
	else:
		var sf := StyleBoxFlat.new()
		sf.bg_color = fallback_color
		sf.set_corner_radius_all(6)
		sf.set_content_margin_all(8)
		return sf


func _make_icon_label(icon: Texture2D, text: String, size: int, color: Color, min_w: float) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	hb.custom_minimum_size.x = min_w
	if icon:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.custom_minimum_size = Vector2(18, 18)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(tr)
	var lbl := _make_label(text, size, color)
	hb.add_child(lbl)
	return hb


func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 32)
	btn.add_theme_font_size_override("font_size", 12)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	if _btn_normal_tex:
		var sn := StyleBoxTexture.new()
		sn.texture = _btn_normal_tex
		sn.texture_margin_left = 8
		sn.texture_margin_right = 8
		sn.texture_margin_top = 6
		sn.texture_margin_bottom = 6
		sn.content_margin_left = 10
		sn.content_margin_right = 10
		sn.content_margin_top = 4
		sn.content_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", sn)
		if _btn_hover_tex:
			var sh := sn.duplicate()
			sh.texture = _btn_hover_tex
			btn.add_theme_stylebox_override("hover", sh)
		if _btn_pressed_tex:
			var sp := sn.duplicate()
			sp.texture = _btn_pressed_tex
			btn.add_theme_stylebox_override("pressed", sp)
	return btn
