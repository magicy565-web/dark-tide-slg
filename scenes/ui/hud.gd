## hud.gd - Action Selection HUD for 暗潮 SLG (v0.8 - Sengoku Rance style)
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

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
	EventBus.gold_changed.connect(_on_legacy_changed)
	EventBus.charm_changed.connect(_on_legacy_changed)
	if EventBus.has_signal("territory_selected"):
		EventBus.territory_selected.connect(_on_territory_selected)
	EventBus.combat_result.connect(_on_combat_result)
	EventBus.order_changed.connect(_on_order_changed)
	EventBus.threat_changed.connect(_on_threat_changed)


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.92)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
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

	turn_label = _make_label("回合: ---", 14, Color.WHITE)
	turn_label.custom_minimum_size.x = 120
	hbox.add_child(turn_label)
	gold_label = _make_label("金:0", 14, Color.GOLD)
	gold_label.custom_minimum_size.x = 50
	hbox.add_child(gold_label)
	food_label = _make_label("粮:0", 14, Color(0.6, 0.9, 0.4))
	food_label.custom_minimum_size.x = 50
	hbox.add_child(food_label)
	iron_label = _make_label("铁:0", 14, Color(0.7, 0.7, 0.8))
	iron_label.custom_minimum_size.x = 50
	hbox.add_child(iron_label)
	slaves_label = _make_label("奴:0", 14, Color(0.9, 0.6, 0.3))
	slaves_label.custom_minimum_size.x = 60
	hbox.add_child(slaves_label)
	prestige_label = _make_label("威:0", 14, Color(1.0, 0.85, 0.3))
	prestige_label.custom_minimum_size.x = 65
	hbox.add_child(prestige_label)
	army_label = _make_label("兵:0", 14, Color.LIGHT_BLUE)
	army_label.custom_minimum_size.x = 100
	hbox.add_child(army_label)
	pop_label = _make_label("人口:0/0", 13, Color(0.9, 0.75, 0.5))
	pop_label.custom_minimum_size.x = 80
	hbox.add_child(pop_label)
	ap_label = _make_label("AP:0", 14, Color.LIGHT_GREEN)
	ap_label.custom_minimum_size.x = 45
	hbox.add_child(ap_label)
	stronghold_label = _make_label("要塞:0/4", 14, Color.ORANGE)
	stronghold_label.custom_minimum_size.x = 70
	hbox.add_child(stronghold_label)

	# Row 2: order / threat / waaagh / strategic resources
	var hbox2 := HBoxContainer.new()
	hbox2.add_theme_constant_override("separation", 24)
	hbox2.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox2)

	order_label = _make_label("秩序:50", 12, Color(0.5, 0.8, 1.0))
	order_label.custom_minimum_size.x = 90
	hbox2.add_child(order_label)
	threat_label = _make_label("威胁:0", 12, Color(1.0, 0.4, 0.3))
	threat_label.custom_minimum_size.x = 90
	hbox2.add_child(threat_label)
	waaagh_label = _make_label("", 12, Color(1.0, 0.2, 0.1))
	waaagh_label.custom_minimum_size.x = 80
	hbox2.add_child(waaagh_label)
	magic_crystal_label = _make_label("魔晶:0", 11, Color(0.6, 0.4, 1.0))
	magic_crystal_label.custom_minimum_size.x = 55
	hbox2.add_child(magic_crystal_label)
	war_horse_label = _make_label("战马:0", 11, Color(0.8, 0.6, 0.3))
	war_horse_label.custom_minimum_size.x = 55
	hbox2.add_child(war_horse_label)
	gunpowder_label = _make_label("火药:0", 11, Color(0.9, 0.5, 0.2))
	gunpowder_label.custom_minimum_size.x = 55
	hbox2.add_child(gunpowder_label)
	shadow_essence_label = _make_label("暗影:0", 11, Color(0.5, 0.2, 0.7))
	shadow_essence_label.custom_minimum_size.x = 55
	hbox2.add_child(shadow_essence_label)


# ── Left panel: main action buttons ──

func _build_action_panel(parent: Control) -> void:
	action_panel = PanelContainer.new()
	action_panel.position = Vector2(10, 60)
	action_panel.size = Vector2(200, 560)
	action_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.88)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	action_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(action_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	action_panel.add_child(vbox)

	var title := _make_label("行動選択", 15, Color(0.8, 0.8, 0.9))
	vbox.add_child(title)

	btn_attack = _make_button("進攻 (1AP)")
	btn_attack.pressed.connect(_on_attack_pressed)
	vbox.add_child(btn_attack)

	btn_deploy = _make_button("部署 (1AP)")
	btn_deploy.pressed.connect(_on_deploy_pressed)
	vbox.add_child(btn_deploy)

	btn_domestic = _make_button("内政 (1AP)")
	btn_domestic.pressed.connect(_on_domestic_pressed)
	vbox.add_child(btn_domestic)

	btn_diplomacy = _make_button("外交 (1AP)")
	btn_diplomacy.pressed.connect(_on_diplomacy_pressed)
	vbox.add_child(btn_diplomacy)

	btn_explore = _make_button("探索 (1AP)")
	btn_explore.pressed.connect(_on_explore_pressed)
	vbox.add_child(btn_explore)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	# Prestige actions
	btn_reduce_threat = _make_button("降威胁-10 (20威望)")
	btn_reduce_threat.pressed.connect(_on_reduce_threat)
	vbox.add_child(btn_reduce_threat)

	btn_boost_order = _make_button("升秩序+10 (15威望)")
	btn_boost_order.pressed.connect(_on_boost_order)
	vbox.add_child(btn_boost_order)

	# Pirate slave trade (shown conditionally)
	btn_sell_slave = _make_button("出售奴隶 (25金)")
	btn_sell_slave.pressed.connect(_on_sell_slave)
	btn_sell_slave.visible = false
	vbox.add_child(btn_sell_slave)

	btn_buy_slave = _make_button("购买奴隶 (40金)")
	btn_buy_slave.pressed.connect(_on_buy_slave)
	btn_buy_slave.visible = false
	vbox.add_child(btn_buy_slave)

	# Hero & Research buttons (free actions)
	var sep_hero := HSeparator.new()
	sep_hero.add_theme_constant_override("separation", 4)
	vbox.add_child(sep_hero)

	btn_hero = _make_button("英雄管理 (H)")
	btn_hero.pressed.connect(_on_hero_pressed)
	vbox.add_child(btn_hero)

	btn_research = _make_button("训练科技")
	btn_research.pressed.connect(_on_research_pressed)
	vbox.add_child(btn_research)

	btn_quest_journal = _make_button("任务日志 (J)")
	btn_quest_journal.pressed.connect(_on_quest_journal_pressed)
	vbox.add_child(btn_quest_journal)

	# Save/Load buttons (free actions)
	var btn_save := _make_button("保存 (F5)")
	btn_save.pressed.connect(_on_save_pressed)
	vbox.add_child(btn_save)

	var btn_load := _make_button("读档 (F9)")
	btn_load.pressed.connect(_on_load_pressed)
	vbox.add_child(btn_load)

	# Separator before end turn
	var sep2 := HSeparator.new()
	sep2.add_theme_constant_override("separation", 8)
	vbox.add_child(sep2)

	btn_end_turn = _make_button("结束回合")
	btn_end_turn.pressed.connect(_on_end_turn_pressed)
	vbox.add_child(btn_end_turn)


# ── Domestic sub-menu (recruit / upgrade / build) ──

func _build_domestic_sub_panel(parent: Control) -> void:
	domestic_panel = PanelContainer.new()
	domestic_panel.position = Vector2(220, 60)
	domestic_panel.size = Vector2(160, 160)
	domestic_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	domestic_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.14, 0.92)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	domestic_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(domestic_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	domestic_panel.add_child(vbox)

	var title := _make_label("内政メニュー", 13, Color(0.7, 0.8, 0.9))
	vbox.add_child(title)

	btn_recruit = _make_button("招募 (募兵)")
	btn_recruit.custom_minimum_size = Vector2(140, 30)
	btn_recruit.pressed.connect(_on_domestic_recruit)
	vbox.add_child(btn_recruit)

	btn_upgrade = _make_button("升级领地")
	btn_upgrade.custom_minimum_size = Vector2(140, 30)
	btn_upgrade.pressed.connect(_on_domestic_upgrade)
	vbox.add_child(btn_upgrade)

	btn_build = _make_button("建造设施")
	btn_build.custom_minimum_size = Vector2(140, 30)
	btn_build.pressed.connect(_on_domestic_build)
	vbox.add_child(btn_build)

	btn_army_view = _make_button("军团一览")
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.12, 0.92)
	style.border_color = Color(0.3, 0.35, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	target_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(target_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	target_panel.add_child(vbox)

	# Header row: title + close button
	var header := HBoxContainer.new()
	vbox.add_child(header)

	target_title_label = _make_label("目标一覧", 14, Color(0.9, 0.85, 0.7))
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.88)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	item_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(item_panel)

	item_container = VBoxContainer.new()
	item_container.add_theme_constant_override("separation", 3)
	item_panel.add_child(item_container)

	var title := _make_label("道具背包", 14, Color(0.8, 0.8, 0.9))
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)

	tile_info_label = RichTextLabel.new()
	tile_info_label.bbcode_enabled = true
	tile_info_label.fit_content = true
	tile_info_label.scroll_active = false
	tile_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile_info_label.text = "[b]当前位置[/b]\n等待游戏开始..."
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.85)
	panel.add_theme_stylebox_override("panel", style)
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
	game_over_panel.offset_left = -220
	game_over_panel.offset_right = 220
	game_over_panel.offset_top = -70
	game_over_panel.offset_bottom = 70
	game_over_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.06, 0.15, 0.95)
	style.border_color = Color.GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	game_over_panel.add_theme_stylebox_override("panel", style)
	parent.add_child(game_over_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	game_over_panel.add_child(vbox)

	game_over_label = _make_label("游戏结束!", 26, Color.GOLD)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(game_over_label)

	var restart := _make_button("重新开始")
	restart.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart)


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

	_show_target_panel("進攻 - 選択軍団")

	if armies.is_empty():
		_add_target_label("(军团がありません — 先に作成してください)")
		return

	for army in armies:
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var power: int = GameManager.get_army_combat_power(army["id"])
		var tile_name: String = GameManager.tiles[army["tile_index"]]["name"]
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		var label_text: String = "%s (兵力:%d 戦力:%d) @%s" % [army["name"], soldiers, power, tile_name]
		if attackable.is_empty():
			label_text += " [無目標]"
		_add_target_button(label_text, _on_attack_army_selected.bind(army["id"]), attackable.is_empty())


func _on_attack_army_selected(army_id: int) -> void:
	_selected_army_id = army_id
	_current_mode = ActionMode.SELECT_ATTACK_TARGET
	var army: Dictionary = GameManager.get_army(army_id)
	var attackable: Array = GameManager.get_army_attackable_tiles(army_id)

	_show_target_panel("進攻 - %s → 目標選択" % army["name"])

	if attackable.is_empty():
		_add_target_label("(攻撃可能な領地がありません)")
		return

	for tidx in attackable:
		var tile: Dictionary = GameManager.tiles[tidx]
		var label_text: String = "%s (Lv%d)" % [tile["name"], tile["level"]]
		if tile["garrison"] > 0:
			label_text += " 守軍:%d" % tile["garrison"]
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

	_show_target_panel("部署 - 選択軍団")

	if armies.is_empty():
		_add_target_label("(军团がありません)")
		return

	for army in armies:
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var tile_name: String = GameManager.tiles[army["tile_index"]]["name"]
		var deployable: Array = GameManager.get_army_deployable_tiles(army["id"])
		var label_text: String = "%s (兵力:%d) @%s" % [army["name"], soldiers, tile_name]
		if deployable.is_empty():
			label_text += " [移動不可]"
		_add_target_button(label_text, _on_deploy_army_selected.bind(army["id"]), deployable.is_empty())


func _on_deploy_army_selected(army_id: int) -> void:
	_selected_army_id = army_id
	_current_mode = ActionMode.SELECT_DEPLOY_TARGET
	var army: Dictionary = GameManager.get_army(army_id)
	var deployable: Array = GameManager.get_army_deployable_tiles(army_id)

	_show_target_panel("部署 - %s → 目的地" % army["name"])

	if deployable.is_empty():
		_add_target_label("(移動可能な領地がありません)")
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
	btn_recruit.text = "招募部队 (%d/%d编制)" % [army_size, pop_cap]
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

	_show_target_panel("外交 - 対象選択")

	if targets.is_empty():
		_add_target_label("(外交対象がいません)")
		return

	for entry in targets:
		var label_text: String = entry.get("name", "???")
		if entry.get("recruited", false):
			label_text += " [已招募]"
		else:
			# Show taming level and tier
			var taming: int = entry.get("taming_level", 0)
			var tier_str: String = entry.get("taming_tier", "hostile")
			var tier_label: String = ""
			match tier_str:
				"hostile": tier_label = "敌对"
				"neutral": tier_label = "中立"
				"friendly": tier_label = "友好"
				"allied": tier_label = "同盟"
				"tamed": tier_label = "驯服"
			label_text += " [驯服:%d/10 %s]" % [taming, tier_label]
			if entry.get("quest_step", 0) > 0:
				label_text += " 任务:%d/%d" % [entry.get("quest_step", 0), entry.get("max_steps", 3)]
			# Show unlocked troops
			var unlocked: Array = entry.get("unlocked_troops", [])
			if not unlocked.is_empty():
				label_text += " 可招:%d兵种" % unlocked.size()
		_add_target_button(label_text, _on_diplomacy_target.bind(entry))


func _on_explore_pressed() -> void:
	if _current_mode == ActionMode.EXPLORE:
		_close_target_panel()
		return
	_current_mode = ActionMode.EXPLORE
	var pid: int = GameManager.get_human_player_id()
	var tiles: Array = GameManager.get_explorable_tiles(pid)

	_show_target_panel("探索 - 目標選択")

	if tiles.is_empty():
		_add_target_label("(探索可能な領地がありません)")
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

	_show_target_panel("招募部队 - 兵種選択")

	var available: Array = RecruitManager.get_available_units(pid, tile)
	if available.is_empty():
		_add_target_label("(当前位置无可招募兵种)")
		return

	# Show army status header
	var army_summary: Array = RecruitManager.get_army_summary(pid)
	var pop_cap: int = RecruitManager._get_pop_cap(pid)
	_add_target_label("军团: %d/%d 编制" % [army_summary.size(), pop_cap])

	# Show current army composition
	if not army_summary.is_empty():
		var army_text: String = "现有: "
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

		var label_text: String = "[%s] %s (%s) ATK:%d DEF:%d 兵:%d | %s" % [
			tier_str, entry["name"], entry["troop_class_name"] if entry.has("troop_class_name") else GameData.get_class_name(entry.get("troop_class", 0)),
			entry["base_atk"], entry.get("base_def", 0), entry["max_soldiers"],
			cost_str.strip_edges()
		]
		if passive_name != "":
			label_text += " [%s]" % passive_name
		if entry.get("is_mercenary", false):
			label_text += " (佣兵)"
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
	if player["ap"] < 1:
		EventBus.message_log.emit("AP不足!")
		return
	var success: bool = RecruitManager.recruit_unit(pid, troop_id, tile)
	if success:
		player["ap"] -= 1
		player["army_count"] = ResourceManager.get_army(pid)
		_update_player_info()
		# Refresh the recruit panel to show updated state
		_on_domestic_recruit()
	else:
		EventBus.message_log.emit("招募失败 — 资源不足或军团已满")


func _on_army_view() -> void:
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "army_view"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	_show_target_panel("军団一覧")

	var summary: Array = RecruitManager.get_army_summary(pid)
	if summary.is_empty():
		_add_target_label("(军团中没有部队)")
		return

	var pop_cap: int = RecruitManager._get_pop_cap(pid)
	_add_target_label("编制: %d/%d | 总兵力: %d" % [summary.size(), pop_cap, RecruitManager.get_total_soldiers(pid)])

	# Faction passive display
	var ftag: String = GameManager._get_faction_tag_for_player(pid)
	var fp: Dictionary = GameData.get_faction_passive(ftag)
	if not fp.is_empty():
		_add_target_label("阵营特性: %s — %s" % [fp.get("name", ""), fp.get("desc", "")], Color(0.8, 0.7, 0.4))

	# Slave conversion status (Dark Elf)
	if ftag == "dark_elf":
		var conv_status: Array = SlaveManager.get_conversion_status(pid)
		if not conv_status.is_empty():
			for cs in conv_status:
				_add_target_label("  转化中: %d名俘虏 (%d回合后完成)" % [cs["count"], cs["turns_left"]], Color(0.7, 0.5, 0.8))

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

		var line1: String = "[%s] %s (%s/%s) ATK:%d DEF:%d 兵:%d/%d%s" % [
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
			var used_str: String = "已使用" if entry["ability_used"] else "可用"
			_add_target_label("  技能: %s (%s)" % [entry["ability"], used_str], Color(0.6, 0.75, 0.6))

		# Upkeep
		if entry["upkeep"] > 0:
			_add_target_label("  维持: %d粮/回合 | 经验: %d" % [entry["upkeep"], entry["experience"]], Color(0.55, 0.55, 0.6))


func _on_domestic_upgrade() -> void:
	# Show owned tiles that can be upgraded
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "upgrade"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	_show_target_panel("升级领地 - 選択")

	var found: bool = false
	for i in range(GameManager.tiles.size()):
		var tile: Dictionary = GameManager.tiles[i]
		if tile["owner_id"] == pid and tile["level"] < GameManager.MAX_TILE_LEVEL:
			var cost: Array = GameManager.UPGRADE_COSTS[tile["level"]]
			var label_text: String = "%s Lv%d -> Lv%d (%d金 %d铁)" % [
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
		_add_target_label("(升级可能な領地がありません)")


func _on_domestic_build() -> void:
	# Show owned tiles that can have buildings
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "build"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	_show_target_panel("建造設施 - 領地選択")

	var found: bool = false
	for i in range(GameManager.tiles.size()):
		var tile: Dictionary = GameManager.tiles[i]
		if tile["owner_id"] == pid and tile.get("building_id", "") == "":
			var label_text: String = "%s (Lv%d)" % [tile["name"], tile["level"]]
			_add_target_button(label_text, _on_domestic_build_tile.bind(i))
			found = true

	if not found:
		_add_target_label("(建造可能な領地がありません)")


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

	_show_target_panel("建造設施 - %s" % tile["name"])

	if available.is_empty():
		_add_target_label("(建築可能な設施がありません)")
		return

	for b in available:
		var label_text: String = "%s" % b.get("name", b["id"])
		var cost: Dictionary = b.get("cost", {})
		if not cost.is_empty():
			var cost_parts: Array = []
			if cost.get("gold", 0) > 0:
				cost_parts.append("%d金" % cost["gold"])
			if cost.get("iron", 0) > 0:
				cost_parts.append("%d铁" % cost["iron"])
			if cost.get("slaves", 0) > 0:
				cost_parts.append("%d奴" % cost["slaves"])
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
	_show_target_panel("训练科技树")

	# Get research state from ResearchManager
	if not ResearchManager.has_method("get_research_status"):
		_add_target_label("(训练系统加载中...)")
		return

	var status: Dictionary = ResearchManager.get_research_status(pid)
	if status.is_empty():
		_add_target_label("(无可用训练项目)")
		return

	# Show current research
	var current: Dictionary = status.get("current", {})
	if not current.is_empty():
		_add_target_label("研究中: %s (%d/%d)" % [
			current.get("name", "???"),
			current.get("progress", 0),
			current.get("cost", 0)
		], Color(0.4, 0.8, 1.0))

	# Show available research
	var available: Array = status.get("available", [])
	for entry in available:
		var label_text: String = "%s (费用:%d)" % [entry.get("name", "???"), entry.get("cost", 0)]
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
		_add_target_label("\n已完成:", Color(0.5, 0.7, 0.4))
		for tech_name in completed:
			_add_target_label("  %s" % tech_name, Color(0.4, 0.6, 0.35))


func _on_start_research(tech_id: String) -> void:
	var pid: int = GameManager.get_human_player_id()
	if ResearchManager.has_method("start_research"):
		ResearchManager.start_research(pid, tech_id)
		EventBus.message_log.emit("开始研究: %s" % tech_id)
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
	get_tree().reload_current_scene()


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
	var is_human: bool = not player.get("is_ai", true)
	var pid: int = player["id"]
	var faction_id: int = GameManager.get_player_faction(pid)

	if not is_human or GameManager.waiting_for_move:
		_set_all_buttons_disabled(true)
		btn_end_turn.disabled = not is_human
		return

	var has_ap: bool = player["ap"] >= 1

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
	var player: Dictionary = GameManager.get_current_player()
	var pid: int = player["id"]

	turn_label.text = "第%d回合 %s" % [GameManager.turn_number, player["name"]]
	turn_label.add_theme_color_override("font_color", player["color"])

	gold_label.text = "金:%d" % ResourceManager.get_resource(pid, "gold")
	food_label.text = "粮:%d" % ResourceManager.get_resource(pid, "food")
	iron_label.text = "铁:%d" % ResourceManager.get_resource(pid, "iron")
	slaves_label.text = "奴:%d/%d" % [ResourceManager.get_slaves(pid), ResourceManager.get_slave_capacity(pid)]
	prestige_label.text = "威望:%d" % ResourceManager.get_resource(pid, "prestige")
	army_label.text = "兵:%d (%d部队)" % [RecruitManager.get_total_soldiers(pid), RecruitManager._get_army_ref(pid).size()]
	var pop_cap: int = GameManager.get_population_cap(pid)
	pop_label.text = "军团:%d/%d" % [RecruitManager._get_army_ref(pid).size(), pop_cap]
	ap_label.text = "AP:%d" % player["ap"]
	stronghold_label.text = "要塞:%s" % GameManager.get_stronghold_progress(pid)

	order_label.text = "秩序:%d (x%.2f)" % [OrderManager.get_order(), OrderManager.get_production_multiplier()]
	threat_label.text = "威胁:%d [%s]" % [ThreatManager.get_threat(), ThreatManager.get_tier_name()]

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
	magic_crystal_label.text = "魔晶:%d" % ResourceManager.get_resource(pid, "magic_crystal")
	war_horse_label.text = "战马:%d" % ResourceManager.get_resource(pid, "war_horse")
	gunpowder_label.text = "火药:%d" % ResourceManager.get_resource(pid, "gunpowder")
	shadow_essence_label.text = "暗影:%d" % ResourceManager.get_resource(pid, "shadow_essence")


func _update_tile_info() -> void:
	if GameManager.players.is_empty() or GameManager.tiles.is_empty():
		return
	var player: Dictionary = GameManager.get_current_player()
	var pid: int = player["id"]
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
	var type_name: String = GameManager.TILE_NAMES.get(tile["type"], "未知")

	var info: String = "[b]%s[/b] (Lv%d)\n類型: %s\n" % [tile["name"], tile["level"], type_name]

	if tile["owner_id"] >= 0:
		var prod: Dictionary = GameManager.get_tile_production(tile)
		info += "産出: 金%d 粮%d 铁%d 人口%d\n" % [prod["gold"], prod["food"], prod["iron"], prod["pop"]]

	if tile["owner_id"] == pid:
		info += "[color=green]已占領[/color]\n"
		var bld: String = tile.get("building_id", "")
		if bld != "":
			var bld_level: int = tile.get("building_level", 1)
			var max_level: int = BuildingRegistry.get_building_max_level(bld)
			info += "建築: [color=orchid]%s[/color] (Lv%d/%d)\n" % [BuildingRegistry.get_building_name(bld), bld_level, max_level]
		else:
			info += "[color=gray]可建造設施[/color]\n"
		var stype: String = tile.get("resource_station_type", "")
		if stype != "":
			info += "[color=cyan]資源産出: %s[/color]\n" % stype
	elif tile["owner_id"] >= 0:
		var _owner = GameManager.get_player_by_id(tile["owner_id"])
		var oname: String = _owner.get("name", "敵軍") if _owner else "敵軍"
		info += "[color=red]%s 占領[/color]\n" % oname
	else:
		if tile["garrison"] > 0:
			info += "守軍: %d\n" % tile["garrison"]

	if tile.get("light_faction", -1) >= 0:
		info += "光明陣営: %s\n" % FactionData.LIGHT_FACTION_NAMES.get(tile["light_faction"], "未知")

	if tile.get("neutral_faction_id", -1) >= 0:
		var nf_id: int = tile["neutral_faction_id"]
		var nf_name: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf_id, "未知")
		if NeutralFactionAI.is_vassal(nf_id):
			info += "[color=lime]附庸: %s[/color]\n" % nf_name
		else:
			info += "中立勢力: %s\n" % nf_name
		# Show territory info
		var territory: Array = NeutralFactionAI.get_faction_territory(nf_id)
		info += "领地节点: %d\n" % territory.size()

	if tile["owner_id"] == pid and tile["level"] < GameManager.MAX_TILE_LEVEL:
		var cost: Array = GameManager.UPGRADE_COSTS[tile["level"]]
		info += "\n[color=yellow]升級->Lv%d: %d金 %d铁[/color]" % [tile["level"] + 1, cost[0], cost[1]]

	info += "\n\n要塞進度:"
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

	var player: Dictionary = GameManager.players[0]
	var pid: int = player["id"]
	var inventory: Array = ItemManager.get_inventory(pid)

	if inventory.is_empty():
		var empty_lbl := _make_label("(空)", 11, Color(0.5, 0.5, 0.55))
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
	var type_name: String = GameManager.TILE_NAMES.get(tile["type"], "未知")
	var terrain: int = tile.get("terrain", FactionData.TerrainType.PLAINS)

	var tdata: Dictionary = FactionData.TERRAIN_DATA.get(terrain, {})
	var terrain_name: String = tdata.get("name", "未知")

	var info: String = "[b]%s[/b] (Lv%d)\n" % [tile["name"], tile["level"]]
	info += "类型: %s | 地形: %s\n" % [type_name, terrain_name]

	# Terrain combat modifiers
	var t_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain, {}) if "TERRAIN_DATA" in FactionData else {}
	if not t_data.is_empty():
		var atk_m: float = t_data.get("atk_mult", 1.0)
		var def_m: float = t_data.get("def_mult", 1.0)
		if atk_m != 1.0 or def_m != 1.0:
			info += "[color=gray]战斗修正: ATK×%.2f DEF×%.2f[/color]\n" % [atk_m, def_m]

	# Terrain move cost & attrition tooltip
	var move_cost: int = tdata.get("move_cost", 1)
	var attrition_pct: float = tdata.get("attrition_pct", 0.0)
	if move_cost > 1 or attrition_pct > 0.0:
		var extra_info: String = "[color=gray]移动消耗: %dAP" % move_cost
		if attrition_pct > 0.0:
			extra_info += " | 减员: %.0f%%/回合" % (attrition_pct * 100.0)
		extra_info += "[/color]\n"
		info += extra_info

	# Chokepoint
	if tile.get("is_chokepoint", false):
		info += "[color=orange]关隘: ATK-10% DEF+20%[/color]\n"

	# Owner info
	if tile["owner_id"] == pid:
		info += "[color=green]己方领地[/color]\n"
		var prod: Dictionary = GameManager.get_tile_production(tile) if GameManager.has_method("get_tile_production") else {}
		if not prod.is_empty():
			info += "产出: 金%d 粮%d 铁%d\n" % [prod.get("gold", 0), prod.get("food", 0), prod.get("iron", 0)]
		var bld: String = tile.get("building_id", "")
		if bld != "":
			info += "建筑: [color=orchid]%s[/color] Lv%d\n" % [BuildingRegistry.get_building_name(bld), tile.get("building_level", 1)]
	elif tile["owner_id"] >= 0:
		var _owner = GameManager.get_player_by_id(tile["owner_id"])
		var oname: String = _owner.get("name", "敌军") if _owner else "敌军"
		info += "[color=red]%s 占领[/color]\n" % oname
	else:
		info += "[color=gray]无主之地[/color]\n"

	# Garrison
	var garrison: int = tile.get("garrison", 0)
	if garrison > 0:
		info += "驻军: %d\n" % garrison

	# Army stationed here (v0.9.2)
	var army: Dictionary = GameManager.get_army_at_tile(tile_index)
	if not army.is_empty():
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var power: int = GameManager.get_army_combat_power(army["id"])
		var troop_count: int = army["troops"].size()
		info += "[color=yellow]━━ 军团: %s ━━[/color]\n" % army["name"]
		info += "部队编制: %d/%d | 总兵力: %d | 战力: %d\n" % [troop_count, GameManager.MAX_TROOPS_PER_ARMY, soldiers, power]
		if army["player_id"] == pid:
			var supply: int = GameManager.calculate_supply_line(army["id"])
			if supply < 0:
				info += "[color=red]补给线: 切断![/color]\n"
			elif supply > GameManager.SUPPLY_LINE_SAFE:
				info += "[color=orange]补给线: %d格 (过长)[/color]\n" % supply
			else:
				info += "[color=green]补给线: %d格[/color]\n" % supply

	# Neutral faction
	if tile.get("neutral_faction_id", -1) >= 0:
		var nf_id2: int = tile["neutral_faction_id"]
		var nf_name2: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf_id2, "未知")
		if NeutralFactionAI.is_vassal(nf_id2):
			info += "[color=lime]附庸: %s[/color]\n" % nf_name2
		else:
			info += "中立势力: %s\n" % nf_name2

	# Light faction
	if tile.get("light_faction", -1) >= 0:
		info += "光明阵营: %s\n" % FactionData.LIGHT_FACTION_NAMES.get(tile["light_faction"], "未知")

	# Wall HP
	var wall_hp: int = tile.get("wall_hp", 0)
	if wall_hp > 0:
		info += "城防HP: %d\n" % wall_hp

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
	game_over_panel.visible = true
	if winner_id >= 0 and winner_id < GameManager.players.size():
		game_over_label.text = "%s 獲得最終勝利!" % GameManager.players[winner_id]["name"]
	else:
		game_over_label.text = "游戏結束!"
	_update_buttons()


func _on_combat_result(_attacker_id: int, _defender_desc: String, _won: bool) -> void:
	# Refresh all UI after combat resolves
	_update_tile_info()
	_update_buttons()


func _on_order_changed(new_value: int) -> void:
	if order_label:
		order_label.text = "秩序: %d" % new_value


func _on_threat_changed(new_value: int) -> void:
	if threat_label:
		threat_label.text = "威胁: %d" % new_value


# ═══════════════════════════════════════════════════════════════
#                       HELPERS
# ═══════════════════════════════════════════════════════════════

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
	return btn
