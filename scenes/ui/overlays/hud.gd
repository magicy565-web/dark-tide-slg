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
var _icon_order: Texture2D
var _icon_threat: Texture2D
var _icon_action_attack: Texture2D
var _icon_action_deploy: Texture2D
var _icon_action_build: Texture2D
var _icon_action_diplomacy: Texture2D
var _icon_action_end_turn: Texture2D
var _icon_action_hero: Texture2D
var _icon_action_recruit: Texture2D
var _has_resource_icons: bool = false

# ── HD UI frame textures (extracted from ui_panels sprite sheets) ──
var _frame_top_bar: Texture2D
var _frame_info_panel: Texture2D
var _frame_content: Texture2D
var _frame_parchment: Texture2D
var _frame_action_bar: Texture2D
var _frame_dialog: Texture2D

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
var order_bar: ProgressBar
var threat_bar: ProgressBar
var gold_delta_label: Label
var food_delta_label: Label
var iron_delta_label: Label

var ap_display: Label
var ap_display_bg: PanelContainer

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
var btn_armies: Button
var btn_economy: Button
var btn_guard: Button
var btn_commander: Button
var btn_interrogate: Button
var btn_reinforce: Button
var btn_sat_event: Button

# ── UI refs: faction-specific buttons ──
var btn_waaagh_burst: Button       # Orc: WAAAGH! Burst
var btn_blood_tribute: Button      # Orc: Blood Tribute
var btn_rare_market: Button        # Pirate: Rare Black Market
var btn_shadow_network: Button     # Dark Elf: Shadow Network
var btn_assassination: Button      # Dark Elf: Assassination
var btn_corruption: Button         # Dark Elf: Corruption

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
var btn_tile_dev: Button
var btn_merge_army: Button
var btn_split_army: Button
var btn_upgrade_troop: Button
var btn_formation: Button
var btn_unit_orders: Button
var btn_troop_training: Button
var btn_equipment_forge: Button
var _formation_army_id: int = -1
var _orders_army_id: int = -1
var _tile_dev_panel: Node = null

# ── UI refs: item panel ──
var item_panel: PanelContainer
var item_container: VBoxContainer
var item_buttons: Array = []

# ── UI refs: build selection (inside target panel) ──
var build_buttons: Array = []

# ── UI refs: right tile info ──
var tile_info_label: RichTextLabel
var _tile_info_panel_container: PanelContainer  # 右侧信息面板容器，供 ProvinceInfoPanel 接管时隐藏

# ── UI refs: bottom message log ──
var message_log_label: RichTextLabel

# ── UI refs: game over overlay ──
var game_over_panel: PanelContainer
var game_over_label: Label
var game_over_victory_type_label: Label
var game_over_stats_vbox: VBoxContainer
var game_over_style: StyleBox

# ── UI refs: turn phase banner (v4.5) ──
var _phase_banner: PanelContainer
var _phase_banner_label: Label
var _phase_banner_timer: Timer
var _ai_turn_active: bool = false

var messages: Array = []
const MAX_MESSAGES: int = 12

# ── Visual feedback tracking (v4.6) ──
var _prev_gold: int = -1
var _prev_food: int = -1
var _prev_iron: int = -1

# ── Crisis countdown display (v4.0) ──
var crisis_panel: PanelContainer = null
var crisis_vbox: VBoxContainer = null
var _crisis_labels: Array = []

# ── SR07 Diplomatic Event Queue ──
var _diplo_event_queue: Array = []  # Array of event_data Dictionaries
var _diplo_event_active: bool = false  # True while a diplomatic popup is showing


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_HUD
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
	EventBus.game_over_detailed.connect(_on_game_over_detailed)
	EventBus.phase_banner_requested.connect(_on_phase_banner_requested)
	EventBus.turn_started.connect(_on_turn_started_phase_cleanup)
	EventBus.tile_captured.connect(_on_tile_captured)
	EventBus.item_acquired.connect(_on_item_changed)
	EventBus.item_used.connect(_on_item_changed)
	EventBus.building_constructed.connect(_on_building_constructed)
	# LEGACY: gold_changed/charm_changed are never emitted — kept for backward compat
	EventBus.gold_changed.connect(_on_legacy_changed)
	EventBus.charm_changed.connect(_on_legacy_changed)
	EventBus.territory_selected.connect(_on_territory_selected)
	EventBus.territory_deselected.connect(_on_territory_deselected)
	EventBus.combat_result.connect(_on_combat_result)
	EventBus.order_changed.connect(_on_order_changed)
	EventBus.threat_changed.connect(_on_threat_changed)
	EventBus.ap_changed.connect(_on_ap_changed)
	EventBus.territory_changed.connect(_on_territory_changed)
	EventBus.army_deployed.connect(_on_army_deployed)
	EventBus.strategic_resource_changed.connect(_on_strategic_resource_changed)
	EventBus.diplomatic_event_triggered.connect(_on_diplomatic_event_triggered)
	EventBus.recruitment_event_triggered.connect(_on_recruitment_event_triggered)


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_panel_tex = _safe_load("res://assets/ui/panel_frame.png")
	_btn_normal_tex = _safe_load("res://assets/ui/btn_normal.png")
	_btn_hover_tex = _safe_load("res://assets/ui/btn_hover.png")
	_btn_pressed_tex = _safe_load("res://assets/ui/btn_pressed.png")
	_icon_gold = _safe_load("res://assets/ui/icons_hd/res_gold_hd.png")
	if not _icon_gold: _icon_gold = _safe_load("res://assets/ui/icon_gold_coin.png")
	if not _icon_gold: _icon_gold = _safe_load("res://assets/map/resources/res_gold.png")
	_icon_food = _safe_load("res://assets/ui/icons_hd/res_food_hd.png")
	if not _icon_food: _icon_food = _safe_load("res://assets/ui/icon_food_grain.png")
	if not _icon_food: _icon_food = _safe_load("res://assets/map/resources/res_food.png")
	_icon_iron = _safe_load("res://assets/ui/icons_hd/res_iron_hd.png")
	if not _icon_iron: _icon_iron = _safe_load("res://assets/ui/icon_iron_ore.png")
	if not _icon_iron: _icon_iron = _safe_load("res://assets/map/resources/res_iron.png")
	_icon_slave = _safe_load("res://assets/ui/icon_slave_chain.png")
	if not _icon_slave: _icon_slave = _safe_load("res://assets/map/resources/res_slave.png")
	_icon_prestige = _safe_load("res://assets/ui/icons_hd/res_prestige_hd.png")
	if not _icon_prestige: _icon_prestige = _safe_load("res://assets/ui/icon_prestige_crown.png")
	if not _icon_prestige: _icon_prestige = _safe_load("res://assets/map/resources/res_prestige.png")
	_icon_crystal = _safe_load("res://assets/ui/icons_hd/res_crystal_hd.png")
	if not _icon_crystal: _icon_crystal = _safe_load("res://assets/ui/icon_magic_crystal.png")
	if not _icon_crystal: _icon_crystal = _safe_load("res://assets/map/resources/res_mana.png")
	_icon_order = _safe_load("res://assets/ui/icons_hd/res_order_hd.png")
	if not _icon_order: _icon_order = _safe_load("res://assets/ui/icon_order.png")
	if not _icon_order: _icon_order = _safe_load("res://assets/map/resources/res_order.png")
	_icon_threat = _safe_load("res://assets/ui/icons_hd/res_threat_hd.png")
	if not _icon_threat: _icon_threat = _safe_load("res://assets/ui/icon_threat.png")
	if not _icon_threat: _icon_threat = _safe_load("res://assets/map/resources/res_threat.png")
	_icon_action_attack = _safe_load("res://assets/map/actions/action_attack.png")
	_icon_action_deploy = _safe_load("res://assets/map/actions/action_deploy.png")
	_icon_action_build = _safe_load("res://assets/map/actions/action_build.png")
	_icon_action_diplomacy = _safe_load("res://assets/map/actions/action_diplomacy.png")
	_icon_action_end_turn = _safe_load("res://assets/map/actions/action_end_turn.png")
	_icon_action_hero = _safe_load("res://assets/map/actions/action_hero.png")
	_icon_action_recruit = _safe_load("res://assets/map/actions/action_recruit.png")
	_has_resource_icons = _icon_gold != null

	# HD UI frame textures (v2 with fallback to v1)
	_frame_top_bar = _safe_load("res://assets/ui/frames/top_bar_frame_v2.png")
	if not _frame_top_bar: _frame_top_bar = _safe_load("res://assets/ui/frames/top_bar_frame.png")
	_frame_info_panel = _safe_load("res://assets/ui/frames/info_panel_frame_v2.png")
	if not _frame_info_panel: _frame_info_panel = _safe_load("res://assets/ui/frames/info_panel_frame.png")
	_frame_content = _safe_load("res://assets/ui/frames/action_panel_frame_v2.png")
	if not _frame_content: _frame_content = _safe_load("res://assets/ui/frames/content_panel_frame.png")
	_frame_parchment = _safe_load("res://assets/ui/frames/parchment_bg.png")
	_frame_action_bar = _safe_load("res://assets/ui/frames/action_panel_frame_v2.png")
	if not _frame_action_bar: _frame_action_bar = _safe_load("res://assets/ui/frames/inventory_bar_frame.png")
	_frame_dialog = _safe_load("res://assets/ui/frames/dialog_frame_v2.png")

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
	_build_phase_banner(root)
	_build_crisis_timer(root)


# ── Top bar (resources, turn info, strategic resources) ──

func _build_top_bar(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.offset_bottom = 58
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_top_bar_style())
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

	turn_label = _make_label("Turn: ---", ColorTheme.FONT_BODY, Color.WHITE)
	turn_label.custom_minimum_size.x = 120
	hbox.add_child(turn_label)
	var gold_hb := _make_icon_label(_icon_gold, "0", ColorTheme.FONT_BODY, ColorTheme.RES_GOLD, 50)
	gold_label = gold_hb.get_child(gold_hb.get_child_count() - 1)
	hbox.add_child(gold_hb)
	gold_delta_label = _make_label("", 10, Color(0.5, 0.8, 0.3))
	hbox.add_child(gold_delta_label)
	var food_hb := _make_icon_label(_icon_food, "0", ColorTheme.FONT_BODY, ColorTheme.RES_FOOD, 50)
	food_label = food_hb.get_child(food_hb.get_child_count() - 1)
	hbox.add_child(food_hb)
	food_delta_label = _make_label("", 10, Color(0.5, 0.8, 0.3))
	hbox.add_child(food_delta_label)
	var iron_hb := _make_icon_label(_icon_iron, "0", ColorTheme.FONT_BODY, ColorTheme.RES_IRON, 50)
	iron_label = iron_hb.get_child(iron_hb.get_child_count() - 1)
	hbox.add_child(iron_hb)
	iron_delta_label = _make_label("", 10, Color(0.5, 0.8, 0.3))
	hbox.add_child(iron_delta_label)
	var slave_hb := _make_icon_label(_icon_slave, "0", ColorTheme.FONT_BODY, ColorTheme.RES_SLAVE, 60)
	slaves_label = slave_hb.get_child(slave_hb.get_child_count() - 1)
	hbox.add_child(slave_hb)
	var prestige_hb := _make_icon_label(_icon_prestige, "0", ColorTheme.FONT_BODY, ColorTheme.RES_PRESTIGE, 65)
	prestige_label = prestige_hb.get_child(prestige_hb.get_child_count() - 1)
	hbox.add_child(prestige_hb)
	army_label = _make_label("Army:0", ColorTheme.FONT_BODY, Color.LIGHT_BLUE)
	army_label.custom_minimum_size.x = 100
	hbox.add_child(army_label)
	pop_label = _make_label("Pop:0/0", 13, ColorTheme.RES_SLAVE)
	pop_label.custom_minimum_size.x = 80
	hbox.add_child(pop_label)
	ap_label = _make_label("AP:0", ColorTheme.FONT_BODY, ColorTheme.TEXT_SUCCESS)
	ap_label.custom_minimum_size.x = 45
	hbox.add_child(ap_label)
	stronghold_label = _make_label("Fort:0/4", ColorTheme.FONT_BODY, Color.ORANGE)
	stronghold_label.custom_minimum_size.x = 70
	hbox.add_child(stronghold_label)

	# Row 2: order / threat / waaagh / strategic resources
	var hbox2 := HBoxContainer.new()
	hbox2.add_theme_constant_override("separation", 24)
	hbox2.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox2)

	var order_hb := _make_resource_bar("Order", 100, Color(0.3, 0.5, 1.0), 160)
	order_bar = order_hb.get_child(1) as ProgressBar
	order_label = order_hb.get_child(2) as Label
	hbox2.add_child(order_hb)
	var threat_hb := _make_resource_bar("Threat", 100, Color(1.0, 0.3, 0.3), 160)
	threat_bar = threat_hb.get_child(1) as ProgressBar
	threat_label = threat_hb.get_child(2) as Label
	hbox2.add_child(threat_hb)
	waaagh_label = _make_label("", 12, ColorTheme.TEXT_WARNING)
	waaagh_label.custom_minimum_size.x = 80
	hbox2.add_child(waaagh_label)
	var crystal_hb := _make_icon_label(_icon_crystal, "0", ColorTheme.FONT_SMALL, ColorTheme.RES_CRYSTAL, 55)
	magic_crystal_label = crystal_hb.get_child(crystal_hb.get_child_count() - 1)
	hbox2.add_child(crystal_hb)
	war_horse_label = _make_label("Horse:0", ColorTheme.FONT_SMALL, Color(0.8, 0.6, 0.3))
	war_horse_label.custom_minimum_size.x = 55
	hbox2.add_child(war_horse_label)
	gunpowder_label = _make_label("Gunpowder:0", ColorTheme.FONT_SMALL, Color(0.9, 0.5, 0.2))
	gunpowder_label.custom_minimum_size.x = 55
	hbox2.add_child(gunpowder_label)
	shadow_essence_label = _make_label("Shadow:0", ColorTheme.FONT_SMALL, Color(0.5, 0.2, 0.7))
	shadow_essence_label.custom_minimum_size.x = 55
	hbox2.add_child(shadow_essence_label)


# ── Left panel: main action buttons ──

func _build_action_panel(parent: Control) -> void:
	action_panel = PanelContainer.new()
	action_panel.position = Vector2(10, 60)
	action_panel.size = Vector2(200, 560)
	action_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	action_panel.add_theme_stylebox_override("panel", _make_action_bar_style())
	parent.add_child(action_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	action_panel.add_child(vbox)

	# Prominent AP counter at top of action panel
	var ap_hbox := HBoxContainer.new()
	ap_hbox.add_theme_constant_override("separation", 8)
	ap_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(ap_hbox)
	var ap_icon_lbl := _make_label("AP", 14, Color(0.3, 0.8, 1.0))
	ap_hbox.add_child(ap_icon_lbl)
	ap_display = Label.new()
	ap_display.text = "0"
	ap_display.add_theme_font_size_override("font_size", 24)
	ap_display.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	ap_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ap_display.custom_minimum_size.x = 40
	ap_hbox.add_child(ap_display)
	var ap_max_lbl := _make_label("/ turn", 10, Color(0.6, 0.6, 0.65))
	ap_hbox.add_child(ap_max_lbl)

	var title := _make_label("Actions", ColorTheme.FONT_SUBHEADING, ColorTheme.TEXT_HEADING)
	vbox.add_child(title)

	var section_combat := _make_label("-- Combat --", 10, Color(0.7, 0.5, 0.5))
	vbox.add_child(section_combat)

	btn_attack = _make_button("Attack [1] (1AP)", _icon_action_attack, "danger")
	btn_attack.tooltip_text = "Select an army and attack an adjacent enemy territory. Costs 1 Action Point."
	btn_attack.pressed.connect(_on_attack_pressed)
	vbox.add_child(btn_attack)

	btn_deploy = _make_button("Deploy [2] (1AP)", _icon_action_deploy)
	btn_deploy.tooltip_text = "Move an army to an adjacent friendly territory. Costs 1 Action Point."
	btn_deploy.pressed.connect(_on_deploy_pressed)
	vbox.add_child(btn_deploy)

	btn_domestic = _make_button("Domestic [3] (1AP)", _icon_action_build)
	btn_domestic.tooltip_text = "Recruit troops, upgrade territories, build structures, manage armies."
	btn_domestic.pressed.connect(_on_domestic_pressed)
	vbox.add_child(btn_domestic)

	btn_diplomacy = _make_button("Diplomacy [4] (1AP)", _icon_action_diplomacy)
	btn_diplomacy.tooltip_text = "Negotiate with other factions: ceasefire, tribute, alliance, or taming."
	btn_diplomacy.pressed.connect(_on_diplomacy_pressed)
	vbox.add_child(btn_diplomacy)

	btn_explore = _make_button("Explore [5] (1AP)")
	btn_explore.tooltip_text = "Explore unclaimed territories to discover resources and events."
	btn_explore.pressed.connect(_on_explore_pressed)
	vbox.add_child(btn_explore)

	var section_ops := _make_label("-- Operations --", 10, Color(0.5, 0.6, 0.7))
	vbox.add_child(section_ops)

	btn_guard = _make_button("Guard (1AP)")
	btn_guard.pressed.connect(_on_guard_pressed)
	vbox.add_child(btn_guard)

	btn_commander = _make_button("Commander (0AP)")
	btn_commander.pressed.connect(_on_commander_pressed)
	vbox.add_child(btn_commander)

	btn_interrogate = _make_button("Interrogate (1AP)")
	btn_interrogate.pressed.connect(_on_interrogate_pressed)
	vbox.add_child(btn_interrogate)

	btn_reinforce = _make_button("Reinforce (1AP)")
	btn_reinforce.pressed.connect(_on_reinforce_pressed)
	vbox.add_child(btn_reinforce)

	btn_sat_event = _make_button("SAT Event (0)")
	btn_sat_event.pressed.connect(_on_sat_event_pressed)
	vbox.add_child(btn_sat_event)

	var btn_mission = _make_button("Mission [M] (1AP)")
	btn_mission.pressed.connect(_on_mission_pressed)
	vbox.add_child(btn_mission)

	var btn_territory_info = _make_button("Territory [T]")
	btn_territory_info.pressed.connect(_on_territory_info_pressed)
	vbox.add_child(btn_territory_info)

	# Prestige actions
	var section_prestige := _make_label("-- Prestige --", 10, Color(0.7, 0.7, 0.5))
	vbox.add_child(section_prestige)

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
	var section_info := _make_label("-- Info & Management --", 10, Color(0.5, 0.7, 0.6))
	vbox.add_child(section_info)

	btn_hero = _make_button("Heroes (H)", _icon_action_hero)
	btn_hero.pressed.connect(_on_hero_pressed)
	vbox.add_child(btn_hero)

	btn_research = _make_button("Research")
	btn_research.pressed.connect(_on_research_pressed)
	vbox.add_child(btn_research)

	btn_quest_journal = _make_button("Quest Log (J)")
	btn_quest_journal.pressed.connect(_on_quest_journal_pressed)
	vbox.add_child(btn_quest_journal)

	btn_armies = _make_button("Armies (A)")
	btn_armies.pressed.connect(_on_armies_pressed)
	vbox.add_child(btn_armies)

	btn_economy = _make_button("Economy ($)")
	btn_economy.pressed.connect(_on_economy_pressed)
	vbox.add_child(btn_economy)

	var btn_event_mgr := _make_button("Event Mgr (E)")
	btn_event_mgr.pressed.connect(_on_event_manager_pressed)
	vbox.add_child(btn_event_mgr)

	# ── Faction-specific ability buttons ──
	var section_faction := _make_label("-- Faction Abilities --", 10, Color(0.8, 0.5, 0.3))
	vbox.add_child(section_faction)

	# Orc buttons
	btn_waaagh_burst = _make_button("WAAAGH! Burst (0AP)", null, "danger")
	btn_waaagh_burst.tooltip_text = "Spend 10 WAAAGH! Power: +30% ATK for 3 turns, then -15% for 2 turns."
	btn_waaagh_burst.pressed.connect(_on_waaagh_burst_pressed)
	btn_waaagh_burst.visible = false
	vbox.add_child(btn_waaagh_burst)

	btn_blood_tribute = _make_button("Blood Tribute (0AP)")
	btn_blood_tribute.tooltip_text = "Sacrifice a captured hero: permanent +2 ATK to all armies. Reputation cost."
	btn_blood_tribute.pressed.connect(_on_blood_tribute_pressed)
	btn_blood_tribute.visible = false
	vbox.add_child(btn_blood_tribute)

	# Pirate buttons
	btn_rare_market = _make_button("Rare Market (0AP)")
	btn_rare_market.tooltip_text = "Browse rare items at 50% markup. No reputation cost. Restocks every 5 turns."
	btn_rare_market.pressed.connect(_on_rare_market_pressed)
	btn_rare_market.visible = false
	vbox.add_child(btn_rare_market)

	# Dark Elf buttons
	btn_shadow_network = _make_button("Shadow Network (0AP)")
	btn_shadow_network.tooltip_text = "Toggle: reveal all enemy army positions. Costs 10g/turn upkeep."
	btn_shadow_network.pressed.connect(_on_shadow_network_pressed)
	btn_shadow_network.visible = false
	vbox.add_child(btn_shadow_network)

	btn_assassination = _make_button("Assassinate (2AP)")
	btn_assassination.tooltip_text = "Attempt to kill an enemy hero. 40% success, -20 reputation."
	btn_assassination.pressed.connect(_on_assassination_pressed)
	btn_assassination.visible = false
	vbox.add_child(btn_assassination)

	btn_corruption = _make_button("Corrupt Tile (0AP)")
	btn_corruption.tooltip_text = "Corrupt a neutral tile to join you without combat. Costs prestige, 3-turn process."
	btn_corruption.pressed.connect(_on_corruption_pressed)
	btn_corruption.visible = false
	vbox.add_child(btn_corruption)

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

	btn_end_turn = _make_button("End Turn [Enter]", _icon_action_end_turn)
	btn_end_turn.pressed.connect(_on_end_turn_pressed)
	vbox.add_child(btn_end_turn)


# ── Domestic sub-menu (recruit / upgrade / build) ──

func _build_domestic_sub_panel(parent: Control) -> void:
	domestic_panel = PanelContainer.new()
	domestic_panel.position = Vector2(220, 60)
	domestic_panel.size = Vector2(160, 365)
	domestic_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	domestic_panel.visible = false
	domestic_panel.add_theme_stylebox_override("panel", _make_content_panel_style())
	parent.add_child(domestic_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	domestic_panel.add_child(vbox)

	var title := _make_label("Domestic Menu", 13, ColorTheme.TEXT_HEADING)
	vbox.add_child(title)

	btn_recruit = _make_button("Recruit", _icon_action_recruit, "confirm")
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

	btn_merge_army = _make_button("Merge Armies")
	btn_merge_army.custom_minimum_size = Vector2(140, 30)
	btn_merge_army.pressed.connect(_on_merge_army)
	vbox.add_child(btn_merge_army)

	btn_split_army = _make_button("Split Army")
	btn_split_army.custom_minimum_size = Vector2(140, 30)
	btn_split_army.pressed.connect(_on_split_army)
	vbox.add_child(btn_split_army)

	btn_upgrade_troop = _make_button("Upgrade Troop (昇格)")
	btn_upgrade_troop.custom_minimum_size = Vector2(140, 30)
	btn_upgrade_troop.pressed.connect(_on_upgrade_troop)
	vbox.add_child(btn_upgrade_troop)

	btn_tile_dev = _make_button("Dev Path (Undeveloped)")
	btn_tile_dev.custom_minimum_size = Vector2(140, 30)
	btn_tile_dev.pressed.connect(_on_tile_dev_pressed)
	vbox.add_child(btn_tile_dev)

	btn_formation = _make_button("Edit Formation (陣形)")
	btn_formation.custom_minimum_size = Vector2(140, 30)
	btn_formation.pressed.connect(_on_formation_edit)
	vbox.add_child(btn_formation)

	btn_unit_orders = _make_button("Unit Orders (個別指令)")
	btn_unit_orders.custom_minimum_size = Vector2(140, 30)
	btn_unit_orders.pressed.connect(_on_unit_orders)
	vbox.add_child(btn_unit_orders)

	btn_troop_training = _make_button("兵種訓練")
	btn_troop_training.custom_minimum_size = Vector2(140, 30)
	btn_troop_training.tooltip_text = "訓練兵種解鎖新能力 (U)"
	btn_troop_training.pressed.connect(_on_troop_training)
	vbox.add_child(btn_troop_training)

	btn_equipment_forge = _make_button("装备锻造")
	btn_equipment_forge.custom_minimum_size = Vector2(140, 30)
	btn_equipment_forge.tooltip_text = "锻造装备与传说武器 (F)"
	btn_equipment_forge.pressed.connect(_on_equipment_forge)
	vbox.add_child(btn_equipment_forge)


# ── Center panel: target / tile selector ──

func _build_target_panel(parent: Control) -> void:
	target_panel = PanelContainer.new()
	target_panel.anchor_left = 0.0
	target_panel.anchor_right = 0.0
	target_panel.position = Vector2(220, 60)
	target_panel.size = Vector2(420, 400)
	target_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	target_panel.visible = false
	target_panel.add_theme_stylebox_override("panel", _make_info_panel_style())
	parent.add_child(target_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	target_panel.add_child(vbox)

	# Header row: title + close button
	var header := HBoxContainer.new()
	vbox.add_child(header)

	target_title_label = _make_label("Targets", ColorTheme.FONT_BODY, ColorTheme.TEXT_HEADING)
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
	item_panel.add_theme_stylebox_override("panel", _make_content_panel_style())
	parent.add_child(item_panel)

	item_container = VBoxContainer.new()
	item_container.add_theme_constant_override("separation", 3)
	item_panel.add_child(item_container)

	var title := _make_label("Inventory", ColorTheme.FONT_BODY, ColorTheme.TEXT_HEADING)
	item_container.add_child(title)


# ── Right panel: tile info ──

func _build_tile_info(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -250
	panel.offset_right = -10
	panel.offset_top = 60
	panel.offset_bottom = 460
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _make_info_panel_style())
	parent.add_child(panel)
	_tile_info_panel_container = panel  # 保存引用以便 ProvinceInfoPanel 接管时隐藏

	tile_info_label = RichTextLabel.new()
	tile_info_label.bbcode_enabled = true
	tile_info_label.fit_content = false
	tile_info_label.scroll_active = true
	tile_info_label.scroll_following = false
	tile_info_label.mouse_filter = Control.MOUSE_FILTER_PASS
	tile_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tile_info_label.text = "[b]Current Location[/b]\nWaiting for game to start..."
	tile_info_label.add_theme_font_size_override("normal_font_size", ColorTheme.FONT_SMALL + 1)
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
	panel.add_theme_stylebox_override("panel", _make_parchment_style())
	parent.add_child(panel)

	message_log_label = RichTextLabel.new()
	message_log_label.bbcode_enabled = true
	message_log_label.scroll_following = true
	message_log_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message_log_label.add_theme_font_size_override("normal_font_size", ColorTheme.FONT_SMALL)
	message_log_label.add_theme_color_override("default_color", ColorTheme.TEXT_DIM)
	panel.add_child(message_log_label)


# ── Game over overlay ──

func _build_game_over(parent: Control) -> void:
	game_over_panel = PanelContainer.new()
	game_over_panel.anchor_left = 0.5
	game_over_panel.anchor_right = 0.5
	game_over_panel.anchor_top = 0.5
	game_over_panel.anchor_bottom = 0.5
	game_over_panel.offset_left = -280
	game_over_panel.offset_right = 280
	game_over_panel.offset_top = -280
	game_over_panel.offset_bottom = 280
	game_over_panel.visible = false
	var dialog_style := _make_dialog_style()
	if dialog_style is StyleBoxTexture:
		game_over_style = dialog_style
	else:
		game_over_style = StyleBoxFlat.new()
		game_over_style.bg_color = ColorTheme.BG_VICTORY
		game_over_style.border_color = ColorTheme.ACCENT_GOLD
		game_over_style.set_border_width_all(3)
		game_over_style.set_corner_radius_all(10)
		game_over_style.set_content_margin_all(20)
	game_over_panel.add_theme_stylebox_override("panel", game_over_style)
	parent.add_child(game_over_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	game_over_panel.add_child(vbox)

	game_over_label = _make_label("Game Over!", ColorTheme.FONT_TITLE, ColorTheme.TEXT_GOLD)
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(game_over_label)

	game_over_victory_type_label = _make_label("", ColorTheme.FONT_HEADING - 2, ColorTheme.TEXT_GOLD)
	game_over_victory_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(game_over_victory_type_label)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	var stats_title := _make_label("-- Battle Stats --", ColorTheme.FONT_BODY, ColorTheme.TEXT_DIM)
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_title)

	game_over_stats_vbox = VBoxContainer.new()
	game_over_stats_vbox.add_theme_constant_override("separation", 4)
	var stats_scroll := ScrollContainer.new()
	stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_scroll.add_child(game_over_stats_vbox)
	game_over_stats_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(stats_scroll)

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
	var frame_style: StyleBox = _make_content_panel_style()
	frame.add_theme_stylebox_override("panel", frame_style)
	minimap_anchor.add_child(frame)

	# Hook into board_ready to request minimap setup
	EventBus.board_ready.connect(_on_board_ready_minimap)


func _on_board_ready_minimap() -> void:
	var board_node = get_tree().get_root().find_child("Board", true, false)
	if board_node and board_node.has_method("setup_minimap"):
		board_node.setup_minimap(minimap_anchor)


# ── Turn phase banner (v4.5) ──

func _build_phase_banner(parent: Control) -> void:
	_phase_banner = PanelContainer.new()
	_phase_banner.anchor_left = 0.5
	_phase_banner.anchor_right = 0.5
	_phase_banner.anchor_top = 0.0
	_phase_banner.anchor_bottom = 0.0
	_phase_banner.offset_left = -200
	_phase_banner.offset_right = 200
	_phase_banner.offset_top = 65
	_phase_banner.offset_bottom = 105
	_phase_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase_banner.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = ColorTheme.PHASE_BG
	style.border_color = ColorTheme.PHASE_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	_phase_banner.add_theme_stylebox_override("panel", style)
	parent.add_child(_phase_banner)

	_phase_banner_label = Label.new()
	_phase_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_banner_label.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING - 2)
	_phase_banner_label.add_theme_color_override("font_color", ColorTheme.PHASE_HUMAN)
	_phase_banner.add_child(_phase_banner_label)

	_phase_banner_timer = Timer.new()
	_phase_banner_timer.one_shot = true
	_phase_banner_timer.timeout.connect(_on_phase_banner_timeout)
	add_child(_phase_banner_timer)


func _on_phase_banner_requested(text: String, is_ai_turn: bool) -> void:
	_phase_banner_label.text = text
	_phase_banner.visible = true
	_ai_turn_active = is_ai_turn
	# Visual: slide banner in from top
	_animate_phase_banner_in()

	if is_ai_turn:
		# Stay visible and disable input during AI turn
		_phase_banner_label.add_theme_color_override("font_color", ColorTheme.PHASE_AI)
		_phase_banner_timer.stop()
		_set_all_buttons_disabled(true)
	else:
		# Human turn: show briefly then auto-hide
		_phase_banner_label.add_theme_color_override("font_color", ColorTheme.PHASE_HUMAN)
		_phase_banner_timer.start(1.5)
		# Re-enable buttons (will be refined by _update_buttons)
		_ai_turn_active = false


func _on_phase_banner_timeout() -> void:
	_phase_banner.visible = false


func _on_turn_started_phase_cleanup(_player_id: int) -> void:
	# When a new human turn starts, hide AI banner
	var human_id: int = GameManager.get_human_player_id()
	if _player_id == human_id and _ai_turn_active:
		_ai_turn_active = false
		_phase_banner.visible = false


# ── Crisis countdown timer (v4.0) ──

func _build_crisis_timer(parent: Control) -> void:
	crisis_panel = PanelContainer.new()
	crisis_panel.name = "CrisisPanel"
	# Position: top-right corner, below resource bar
	crisis_panel.anchor_left = 0.78
	crisis_panel.anchor_right = 0.99
	crisis_panel.anchor_top = 0.14
	crisis_panel.anchor_bottom = 0.14
	crisis_panel.offset_bottom = 120
	crisis_panel.z_index = 10
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.15, 0.85)
	style.border_color = Color(0.8, 0.2, 0.2, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	crisis_panel.add_theme_stylebox_override("panel", style)
	crisis_panel.visible = false
	parent.add_child(crisis_panel)

	crisis_vbox = VBoxContainer.new()
	crisis_vbox.add_theme_constant_override("separation", 4)
	crisis_panel.add_child(crisis_vbox)

	# Header
	var header := Label.new()
	header.text = "⚠ 危机倒计时"
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
	crisis_vbox.add_child(header)


func _update_crisis_display() -> void:
	if not CrisisCountdown:
		return
	var crises: Array = CrisisCountdown.get_active_countdowns()

	# Clear old labels
	for lbl in _crisis_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_crisis_labels.clear()

	if crises.is_empty():
		crisis_panel.visible = false
		return

	crisis_panel.visible = true
	for crisis in crises:
		var lbl := Label.new()
		var remaining: int = crisis["remaining"]
		var color: Color
		if remaining <= 3:
			color = Color(1.0, 0.2, 0.2)  # Red - imminent
		elif remaining <= 8:
			color = Color(1.0, 0.7, 0.2)  # Orange - warning
		else:
			color = Color(0.8, 0.8, 0.6)  # Pale - distant
		lbl.text = "%s: %d回合" % [crisis["name"], remaining]
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", color)
		crisis_vbox.add_child(lbl)
		_crisis_labels.append(lbl)

	# Pulse animation for imminent crises
	if crises[0]["remaining"] <= 3:
		var tw := create_tween().set_loops(3)
		tw.tween_property(crisis_panel, "modulate:a", 0.6, 0.3)
		tw.tween_property(crisis_panel, "modulate:a", 1.0, 0.3)


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
	ColorTheme.animate_panel_open(target_panel)


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
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("button_click")
	if _current_mode == ActionMode.ATTACK:
		_close_target_panel()
		return
	_current_mode = ActionMode.ATTACK
	_selected_army_id = -1
	_pulse_button(btn_attack)
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
			var tile_owner: Dictionary = GameManager.get_player_by_id(tile["owner_id"])
			label_text += " [%s]" % tile_owner.get("name", "???")
		# v5.0: Show siege/fortification status
		if SiegeSystem.is_tile_under_siege(tidx):
			var siege: Dictionary = SiegeSystem.get_siege_at_tile(tidx)
			label_text += " [围攻中 壁%.0f 气%.0f]" % [siege.get("wall_hp", 0), siege.get("defender_morale", 0)]
		elif SiegeSystem.is_tile_fortified(tidx):
			label_text += " [城壁]"
		_add_target_button(label_text, _on_attack_target.bind(tidx))


func _on_deploy_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("button_click")
	if _current_mode == ActionMode.DEPLOY:
		_close_target_panel()
		return
	_current_mode = ActionMode.DEPLOY
	_selected_army_id = -1
	_pulse_button(btn_deploy)
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
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("button_click")
	if _current_mode == ActionMode.DOMESTIC:
		_close_target_panel()
		return
	_current_mode = ActionMode.DOMESTIC
	_pulse_button(btn_domestic)
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

	# Update tile development button text based on selected tile
	var tile_idx: int = _get_selected_owned_tile(pid)
	if tile_idx >= 0 and _tile_dev_panel and _tile_dev_panel.has_method("get_tile_status_text"):
		btn_tile_dev.text = "Dev: %s" % _tile_dev_panel.get_tile_status_text(tile_idx)
		btn_tile_dev.disabled = false
	else:
		btn_tile_dev.text = "Dev Path (N/A)"
		btn_tile_dev.disabled = true

	domestic_panel.visible = true
	ColorTheme.animate_panel_open(domestic_panel)


func _on_diplomacy_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("button_click")
	# Notify tutorial system that diplomacy panel was opened
	if TutorialManager and TutorialManager.has_method("notify_diplomacy_panel_opened"):
		TutorialManager.notify_diplomacy_panel_opened()
	if _current_mode == ActionMode.DIPLOMACY:
		_close_target_panel()
		return
	_current_mode = ActionMode.DIPLOMACY
	_pulse_button(btn_diplomacy)
	var pid: int = GameManager.get_human_player_id()
	var targets: Array = GameManager.get_diplomacy_targets(pid)

	_show_target_panel("Diplomacy - Select Target")

	# Add evil faction targets (from DiplomacyManager relations)
	var evil_factions: Array = [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]
	var player_faction: int = GameManager.get_player_faction(pid)
	for fid in evil_factions:
		if fid == player_faction:
			continue
		var rel: Dictionary = DiplomacyManager.get_all_relations(pid).get(fid, {})
		if rel.get("recruited", false):
			continue
		var fname: String = FactionData.FACTION_NAMES.get(fid, "Unknown")
		var hostile: bool = rel.get("hostile", false)
		var ceasefire: bool = DiplomacyManager.is_ceasefire_active(pid, fid)
		var status: String = "Ceasefire" if ceasefire else ("Hostile" if hostile else "Neutral")
		var label_text: String = "%s [%s]" % [fname, status]
		var entry: Dictionary = {"type": "evil", "faction_id": fid, "name": fname}
		_add_target_button(label_text, _on_diplomacy_target.bind(entry))

	# Add neutral faction targets (original)
	if not targets.is_empty():
		_add_target_label("--- Neutral Factions ---", Color(0.8, 0.7, 0.5))

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

	if targets.is_empty() and evil_factions.all(func(f): return f == player_faction or DiplomacyManager.get_all_relations(pid).get(f, {}).get("recruited", false)):
		_add_target_label("(No diplomatic targets)")


func _on_explore_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("button_click")
	if _current_mode == ActionMode.EXPLORE:
		_close_target_panel()
		return
	_current_mode = ActionMode.EXPLORE
	_pulse_button(btn_explore)
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

	# ── Siege UI (v5.0): Show siege options for fortified tiles ──
	if _selected_army_id >= 0 and SiegeSystem.is_tile_fortified(tile_index):
		var existing_siege: Dictionary = SiegeSystem.get_siege_at_tile(tile_index)
		if existing_siege.is_empty():
			# No siege yet — show siege confirmation dialog
			_show_siege_options(tile_index, _selected_army_id, false)
			return
		elif existing_siege.get("wall_hp", 1.0) > 0.0 and existing_siege.get("turns_remaining", 1) > 0:
			# Siege in progress — show storm/lift/wait options
			_show_siege_options(tile_index, _selected_army_id, true)
			return
		# else: walls breached, proceed to normal attack (final assault)

	# ── SR07: Open battle preparation panel for army composition ──
	if _selected_army_id >= 0:
		_open_battle_prep(_selected_army_id, tile_index)
	else:
		GameManager.action_attack(pid, tile_index)
		_selected_army_id = -1
		_close_target_panel()
		_after_action()


# ═══════════════════════════════════════════════════════════════
#           BATTLE PREPARATION (SR07 Style)
# ═══════════════════════════════════════════════════════════════

var _battle_prep_connected: bool = false

func _open_battle_prep(army_id: int, tile_index: int) -> void:
	## Open the SR07-style battle preparation panel.
	var prep = _find_battle_prep()
	if not prep:
		# Fallback: skip prep, attack directly
		GameManager.action_attack_with_army(army_id, tile_index)
		_selected_army_id = -1
		_close_target_panel()
		_after_action()
		return
	if not _battle_prep_connected:
		prep.battle_confirmed.connect(_on_battle_prep_confirmed)
		prep.battle_cancelled.connect(_on_battle_prep_cancelled)
		_battle_prep_connected = true
	_close_target_panel()
	prep.show_panel(army_id, tile_index)


func _on_battle_prep_confirmed(army_id: int, target_tile: int, slot_assignments: Dictionary) -> void:
	## Battle preparation confirmed — apply slot assignments and attack.
	# Store slot preferences in GameManager before combat
	var prefs: Dictionary = {}
	for slot_idx in slot_assignments:
		var assignment: Dictionary = slot_assignments[slot_idx]
		prefs[assignment.get("troop_index", slot_idx)] = slot_idx
	GameManager.army_slot_preferences[army_id] = prefs
	# Reorder heroes array to match slot assignment
	var army: Dictionary = GameManager.get_army(army_id)
	if not army.is_empty():
		var new_heroes: Array = []
		var slot_hero_map: Array = []
		for i in range(6):
			if slot_assignments.has(i):
				slot_hero_map.append(slot_assignments[i].get("hero_id", ""))
			else:
				slot_hero_map.append("")
		for hid in slot_hero_map:
			if hid != "":
				new_heroes.append(hid)
		# Append any heroes not in assignments (shouldn't happen but safety)
		for hid in army.get("heroes", []):
			if hid not in new_heroes:
				new_heroes.append(hid)
		army["heroes"] = new_heroes
	GameManager.action_attack_with_army(army_id, target_tile)
	_selected_army_id = -1
	_after_action()


func _on_battle_prep_cancelled() -> void:
	## Battle preparation cancelled — return to normal state.
	_selected_army_id = -1
	_current_mode = ActionMode.NONE


func _find_battle_prep():
	## Find the battle_prep_panel node in the scene tree.
	var main_node = get_parent()
	if main_node and main_node.has_method("get") and main_node.get("battle_prep_panel"):
		return main_node.battle_prep_panel
	# Fallback: search siblings
	if main_node:
		for child in main_node.get_children():
			if child.has_method("show_panel") and child.has_signal("battle_confirmed"):
				return child
	return null


## v5.0: Show siege options sub-menu for fortified tiles.
func _show_siege_options(tile_index: int, army_id: int, siege_in_progress: bool) -> void:
	var tile: Dictionary = GameManager.tiles[tile_index]
	var tile_name: String = tile.get("name", "据点")
	var player: Dictionary = GameManager.get_player_by_id(GameManager.get_human_player_id())
	var current_ap: int = player.get("ap", 0)

	if siege_in_progress:
		var siege: Dictionary = SiegeSystem.get_siege_at_tile(tile_index)
		_show_target_panel("围攻进行中 - %s" % tile_name)
		_add_target_label("城壁: %.0f/%.0f  士气: %.0f  剩余: %d回合" % [
			siege.get("wall_hp", 0), siege.get("wall_max_hp", 0),
			siege.get("defender_morale", 0), siege.get("turns_remaining", 0)],
			Color(1.0, 0.8, 0.3))
		_add_target_button("强攻城壁 (消耗%dAP, DEF-30%%)" % SiegeSystem.STORM_AP_COST,
			_on_storm_walls.bind(army_id, tile_index),
			current_ap < SiegeSystem.STORM_AP_COST)
		_add_target_button("撤围 (放弃围攻)",
			_on_lift_siege.bind(tile_index))
		_add_target_button("继续围攻 (等待下回合)",
			_close_target_panel)
	else:
		_show_target_panel("该据点有城壁防护 - %s" % tile_name)
		_add_target_label("需要围攻才能攻陷，预计需要2-3回合。",
			Color(1.0, 0.8, 0.3))
		_add_target_button("开始围攻 (消耗1AP)",
			_on_start_siege.bind(army_id, tile_index),
			current_ap < 1)
		_add_target_button("强攻 (消耗%dAP, DEF-30%%)" % SiegeSystem.STORM_AP_COST,
			_on_storm_walls.bind(army_id, tile_index),
			current_ap < SiegeSystem.STORM_AP_COST)
		_add_target_button("取消", _close_target_panel)


func _on_start_siege(army_id: int, tile_index: int) -> void:
	GameManager.action_attack_with_army(army_id, tile_index)
	_selected_army_id = -1
	_close_target_panel()
	_after_action()


func _on_storm_walls(army_id: int, tile_index: int) -> void:
	GameManager.action_storm_walls(army_id, tile_index)
	_selected_army_id = -1
	_close_target_panel()
	_after_action()


func _on_lift_siege(tile_index: int) -> void:
	var siege: Dictionary = SiegeSystem.get_siege_at_tile(tile_index)
	if not siege.is_empty():
		SiegeSystem.lift_siege(siege["siege_id"])
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

	# Check if GameManager has the new options helper
	if GameManager.has_method("_get_diplomacy_options"):
		var options: Array = GameManager._get_diplomacy_options(pid, faction_id)
		if options.size() == 1 and options[0]["id"] == "neutral_quest":
			# Neutral faction: go straight to quest (original behavior)
			GameManager.action_diplomacy(pid, faction_id, "neutral_quest")
			_close_target_panel()
			_after_action()
			return
		# Show diplomacy sub-menu for evil factions
		_show_target_panel("Diplomacy Options - %s" % entry.get("name", "???"))
		if options.is_empty():
			_add_target_label("(No available options)")
			return
		for opt in options:
			var btn_text: String = "%s (%s)" % [opt["name"], opt["cost"]]
			if opt.get("desc", "") != "":
				btn_text += " - %s" % opt["desc"]
			var opt_id: String = opt["id"]
			var cfid: int = faction_id
			_add_target_button(btn_text, _on_diplomacy_option.bind(cfid, opt_id), not opt.get("available", true))
		return

	# Fallback: original behavior
	GameManager.action_diplomacy(pid, faction_id, "neutral_quest")
	_close_target_panel()
	_after_action()


func _on_diplomacy_option(faction_id: int, diplomacy_type: String) -> void:
	var pid: int = GameManager.get_human_player_id()
	GameManager.action_diplomacy(pid, faction_id, diplomacy_type)
	_close_target_panel()
	_after_action()


func _on_explore_target(tile_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	GameManager.action_explore(pid, tile_index)
	_close_target_panel()
	_after_action()


func _on_guard_pressed() -> void:
	if _current_mode == ActionMode.DOMESTIC_SUB:
		_close_target_panel()
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "guard"
	var pid: int = GameManager.get_human_player_id()
	var owned_tiles: Array = GameManager.get_domestic_tiles(pid)

	_show_target_panel("Guard Territory - Select")

	if owned_tiles.is_empty():
		_add_target_label("(No territories to guard)")
		return

	for tile in owned_tiles:
		var tidx: int = tile["index"]
		var is_guarded: bool = GameManager._guard_timers.has(tidx)
		var label_text: String = "%s (Lv%d)" % [tile["name"], tile["level"]]
		if is_guarded:
			label_text += " [Guarding]"
		_add_target_button(label_text, _on_guard_target.bind(tidx), is_guarded)


func _on_guard_target(tile_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	if GameManager.has_method("action_guard_territory"):
		GameManager.action_guard_territory(pid, tile_index)
	_close_target_panel()
	_after_action()


func _on_commander_pressed() -> void:
	## SR07: Open territory commander assignment panel.
	if _current_mode == ActionMode.DOMESTIC_SUB:
		_close_target_panel()
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "commander"
	var pid: int = GameManager.get_human_player_id()
	var owned_tiles: Array = GameManager.get_domestic_tiles(pid)

	_show_target_panel("Assign Commander - Select Territory")

	if owned_tiles.is_empty():
		_add_target_label("(No territories)")
		return

	for tile in owned_tiles:
		var tidx: int = tile["index"]
		var stationed: String = HeroSystem.get_stationed_hero(tidx)
		var label_text: String = "%s (Lv%d)" % [tile["name"], tile["level"]]
		if stationed != "":
			var hinfo: Dictionary = HeroSystem.get_hero_info(stationed)
			label_text += " [%s]" % hinfo.get("name", stationed)
		else:
			label_text += " [Empty]"
		_add_target_button(label_text, _on_commander_territory_selected.bind(tidx))


func _on_commander_territory_selected(tile_index: int) -> void:
	## Show available heroes to station at this territory.
	var pid: int = GameManager.get_human_player_id()
	var stationed: String = HeroSystem.get_stationed_hero(tile_index)
	var tile_name: String = GameManager.tiles[tile_index]["name"]

	_show_target_panel("Commander for %s" % tile_name)

	# Option to remove current commander
	if stationed != "":
		var hinfo: Dictionary = HeroSystem.get_hero_info(stationed)
		_add_target_button("[Remove] %s" % hinfo.get("name", stationed), _on_commander_remove.bind(tile_index))
		_add_target_label("")  # spacer

	# List available heroes (not in army, not stationed elsewhere)
	var heroes: Array = HeroSystem.get_recruited_heroes(pid)
	var any_available: bool = false
	for hero_id in heroes:
		if hero_id == stationed:
			continue
		if not HeroSystem.is_hero_available(hero_id):
			continue
		var hinfo: Dictionary = HeroSystem.get_hero_info(hero_id)
		var stats: Dictionary = HeroSystem.get_hero_combat_stats(hero_id)
		var label_text: String = "%s Lv%d (A%d D%d S%d)" % [
			hinfo.get("name", hero_id), hinfo.get("level", 1),
			stats.get("atk", 0), stats.get("def", 0), stats.get("spd", 0)
		]
		_add_target_button(label_text, _on_commander_assign.bind(hero_id, tile_index), false)
		any_available = true

	if not any_available and stationed == "":
		_add_target_label("(No available heroes - all in armies or stationed)")


func _on_commander_assign(hero_id: String, tile_index: int) -> void:
	HeroSystem.station_hero(hero_id, tile_index)
	var hinfo: Dictionary = HeroSystem.get_hero_info(hero_id)
	var tile_name: String = GameManager.tiles[tile_index]["name"]
	EventBus.message_log.emit("[color=orchid]%s[/color] assigned as commander of [color=gold]%s[/color]" % [hinfo.get("name", hero_id), tile_name])
	_close_target_panel()
	_update_tile_info()


func _on_commander_remove(tile_index: int) -> void:
	var hero_id: String = HeroSystem.unstation_hero(tile_index)
	if hero_id != "":
		var hinfo: Dictionary = HeroSystem.get_hero_info(hero_id)
		var tile_name: String = GameManager.tiles[tile_index]["name"]
		EventBus.message_log.emit("[color=orchid]%s[/color] relieved from [color=gold]%s[/color]" % [hinfo.get("name", hero_id), tile_name])
	_close_target_panel()
	_update_tile_info()


func _on_sat_event_pressed() -> void:
	if _current_mode == ActionMode.DOMESTIC_SUB:
		_close_target_panel()
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "sat_event"
	var pid: int = GameManager.get_human_player_id()
	var sat_pts: int = GameManager.get_sat_points(pid)

	_show_target_panel("SAT Event - Select Hero")

	if sat_pts <= 0:
		_add_target_label("(No SAT points available)")
		return

	var heroes: Array = HeroSystem.get_heroes_for_player(pid)
	if heroes.is_empty():
		_add_target_label("(No heroes available)")
		return

	for hero_id in heroes:
		var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
		var hero_name: String = hero_data.get("name", hero_id)
		var affection: int = HeroSystem.hero_affection.get(hero_id, 0)
		var label_text: String = "%s (Affection: %d)" % [hero_name, affection]
		_add_target_button(label_text, _on_sat_event_target.bind(hero_id))


func _on_sat_event_target(hero_id: String) -> void:
	var pid: int = GameManager.get_human_player_id()
	GameManager.action_sat_event(pid, hero_id)
	_close_target_panel()
	_after_action()


func _on_interrogate_pressed() -> void:
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "interrogate"

	_show_target_panel("Interrogate Prisoner - Select")

	var pid: int = GameManager.get_human_player_id()
	var player: Dictionary = GameManager.get_player_by_id(pid)
	var has_ap: bool = player.get("ap", 0) >= 1

	if HeroSystem.captured_heroes.is_empty():
		_add_target_label("(No prisoners)")
		return

	for hero_id in HeroSystem.captured_heroes:
		var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
		var hero_name: String = hero_data.get("name", hero_id)
		var corruption: int = HeroSystem.hero_corruption.get(hero_id, 0)
		var label_text: String = "%s (Corruption: %d/100)" % [hero_name, corruption]
		if not has_ap:
			label_text += " [No AP]"
		_add_target_button(label_text, _on_interrogate_target.bind(hero_id), not has_ap)


func _on_interrogate_target(hero_id: String) -> void:
	GameManager.action_interrogate_hero(hero_id)
	_close_target_panel()
	_after_action()


func _on_reinforce_pressed() -> void:
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "reinforce"

	var pid: int = GameManager.get_human_player_id()
	var armies: Array = GameManager.get_player_armies(pid)

	_show_target_panel("Reinforce Army - Select")

	if armies.is_empty():
		_add_target_label("(No armies)")
		return

	for army in armies:
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var tile_idx: int = army.get("tile_index", -1)
		# Only allow reinforcement on owned tiles
		var can_reinforce: bool = false
		if tile_idx >= 0 and tile_idx < GameManager.tiles.size():
			can_reinforce = GameManager.tiles[tile_idx]["owner_id"] == pid
		var tile_name: String = GameManager.tiles[tile_idx]["name"] if tile_idx >= 0 and tile_idx < GameManager.tiles.size() else "???"
		var label_text: String = "%s (Troops:%d) @%s" % [army["name"], soldiers, tile_name]
		if not can_reinforce:
			label_text += " [Not on owned tile]"
		_add_target_button(label_text, _on_reinforce_target.bind(army["id"]), not can_reinforce)


func _on_reinforce_target(army_id: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	GameManager.action_reinforce_army(pid, army_id)
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
	# BUG FIX R11: bounds-check tile_idx before access
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		_show_target_panel("Recruit - Select Troop")
		_add_target_label("(No valid tile selected)")
		return
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


func _on_tile_dev_pressed() -> void:
	domestic_panel.visible = false
	var pid: int = GameManager.get_human_player_id()
	var tile_idx: int = _get_selected_owned_tile(pid)
	if tile_idx < 0:
		return
	_ensure_tile_dev_panel()
	if _tile_dev_panel:
		_tile_dev_panel.show_panel(tile_idx)


func _ensure_tile_dev_panel() -> void:
	if _tile_dev_panel != null:
		return
	var panel_script = load("res://scenes/ui/panels/tile_development_panel.gd")
	if panel_script:
		_tile_dev_panel = panel_script.new()
		get_tree().root.add_child(_tile_dev_panel)


func _get_selected_owned_tile(pid: int) -> int:
	var board_node = get_tree().get_root().find_child("Board", true, false)
	if board_node and board_node.has_method("get_selected_tile"):
		var sel: int = board_node.get_selected_tile()
		if sel >= 0 and sel < GameManager.tiles.size() and GameManager.tiles[sel]["owner_id"] == pid:
			return sel
	var player: Dictionary = GameManager.get_player_by_id(pid)
	var pos: int = player.get("position", 0)
	if pos >= 0 and pos < GameManager.tiles.size() and GameManager.tiles[pos]["owner_id"] == pid:
		return pos
	return -1


var _merge_source_id: int = -1

func _on_merge_army() -> void:
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "merge"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	var armies: Array = GameManager.get_player_armies(pid)

	_show_target_panel("Merge - Select Source Army")

	if armies.size() < 2:
		_add_target_label("(Need at least 2 armies to merge)")
		return

	for army in armies:
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var tile_idx: int = army.get("tile_index", -1)
		var tile_name: String = GameManager.tiles[tile_idx]["name"] if tile_idx >= 0 and tile_idx < GameManager.tiles.size() else "???"
		var label_text: String = "%s (Troops:%d) @%s" % [army["name"], soldiers, tile_name]
		_add_target_button(label_text, _on_merge_source.bind(army["id"]))


func _on_merge_source(army_id: int) -> void:
	_merge_source_id = army_id
	var pid: int = GameManager.get_human_player_id()
	var armies: Array = GameManager.get_player_armies(pid)
	var source: Dictionary = GameManager.get_army(army_id)
	var source_tile: int = source.get("tile_index", -1)

	_show_target_panel("Merge %s -> Select Target" % source["name"])

	for army in armies:
		if army["id"] == army_id:
			continue
		# Can only merge armies on the same tile
		var same_tile: bool = army.get("tile_index", -1) == source_tile
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var tile_name: String = ""
		var atile: int = army.get("tile_index", -1)
		if atile >= 0 and atile < GameManager.tiles.size():
			tile_name = GameManager.tiles[atile]["name"]
		var label_text: String = "%s (Troops:%d) @%s" % [army["name"], soldiers, tile_name]
		if not same_tile:
			label_text += " [Different tile]"
		_add_target_button(label_text, _on_merge_target.bind(army["id"]), not same_tile)


func _on_merge_target(target_army_id: int) -> void:
	GameManager.action_merge_armies(_merge_source_id, target_army_id)
	_merge_source_id = -1
	_close_target_panel()
	_after_action()


func _on_split_army() -> void:
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "split"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	var armies: Array = GameManager.get_player_armies(pid)
	var max_armies: int = GameManager.get_max_armies(pid)

	_show_target_panel("Split - Select Army")

	if armies.size() >= max_armies:
		_add_target_label("(Army limit reached: %d/%d)" % [armies.size(), max_armies])
		return

	for army in armies:
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var troop_count: int = army.get("troops", []).size()
		var label_text: String = "%s (%d troops, %d soldiers)" % [army["name"], troop_count, soldiers]
		_add_target_button(label_text, _on_split_target.bind(army["id"]), troop_count < 2)


func _on_split_target(army_id: int) -> void:
	GameManager.action_split_army(army_id)
	_close_target_panel()
	_after_action()


func _on_troop_training() -> void:
	if PanelManager.has_method("open_panel"):
		PanelManager.open_panel("troop_training")


func _on_equipment_forge() -> void:
	if PanelManager.has_method("open_panel"):
		PanelManager.open_panel("equipment_forge")


func _on_upgrade_troop() -> void:
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "upgrade_troop"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	var armies: Array = GameManager.get_player_armies(pid)

	_show_target_panel("Upgrade Troop (昇格) - Select")

	var found: bool = false
	for army in armies:
		var troops: Array = army.get("troops", [])
		for i in range(troops.size()):
			var troop: Dictionary = troops[i]
			var current_id: String = troop.get("troop_id", "")
			var upgrade_id: String = GameManager._get_troop_upgrade(current_id)
			if upgrade_id == "":
				continue
			var upgrade_data: Dictionary = GameData.TROOP_TYPES.get(upgrade_id, {})
			var label_text: String = "%s -> %s (40g 15iron)" % [
				troop.get("name", current_id),
				upgrade_data.get("name", upgrade_id)
			]
			label_text += " [%s]" % army["name"]
			var can_afford: bool = ResourceManager.can_afford(pid, {"gold": 40, "iron": 15})
			_add_target_button(label_text, _on_upgrade_troop_confirm.bind(army["id"], i), not can_afford)
			found = true

	if not found:
		_add_target_label("(No troops can be upgraded)")


func _on_upgrade_troop_confirm(army_id: int, troop_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	GameManager.action_upgrade_troop(pid, army_id, troop_index)
	_close_target_panel()
	_after_action()


func _on_formation_edit() -> void:
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "formation"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	var armies: Array = GameManager.get_player_armies(pid)

	_show_target_panel("Edit Formation (陣形) - Select Army")

	if armies.is_empty():
		_add_target_label("(No armies)")
		return

	for army in armies:
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var troops: Array = army.get("troops", [])
		var label_text: String = "%s (%d troops, %d soldiers)" % [army["name"], troops.size(), soldiers]
		_add_target_button(label_text, _on_formation_army_selected.bind(army["id"]))


func _on_formation_army_selected(army_id: int) -> void:
	_formation_army_id = army_id
	var army: Dictionary = GameManager.get_army(army_id)
	var troops: Array = army.get("troops", [])
	var prefs: Dictionary = GameManager.get_army_slot_preferences(army_id)

	_show_target_panel("Formation: %s — Assign Slots" % army["name"])

	_add_target_label("Front Row: Slots 0-2 | Back Row: Slots 3-5", Color(0.7, 0.8, 0.9))
	_add_target_label("Current assignments:", Color(0.6, 0.7, 0.8))

	var slot_names: Array = ["Front-L(0)", "Front-C(1)", "Front-R(2)", "Back-L(3)", "Back-C(4)", "Back-R(5)"]

	for i in range(troops.size()):
		var troop: Dictionary = troops[i]
		var troop_name: String = troop.get("name", troop.get("troop_id", "???"))
		var current_slot: int = prefs.get(i, -1)
		var slot_str: String = slot_names[current_slot] if current_slot >= 0 and current_slot < 6 else "Auto"
		var default_row: String = "Front" if troop.get("row", "front") == "front" else "Back"

		_add_target_label("  %s (Default: %s, Current: %s)" % [troop_name, default_row, slot_str])

		# Add slot assignment buttons for this troop
		for s in range(6):
			var btn_text: String = "  -> %s" % slot_names[s]
			if current_slot == s:
				btn_text += " *"
			var btn := Button.new()
			btn.text = btn_text
			btn.custom_minimum_size = Vector2(200, 24)
			btn.add_theme_font_size_override("font_size", 10)
			btn.pressed.connect(_on_formation_slot_assign.bind(army_id, i, s))
			target_container.add_child(btn)
			target_buttons.append(btn)

	# Reset button
	_add_target_button("[Reset to Auto]", _on_formation_reset.bind(army_id))


func _on_formation_slot_assign(army_id: int, troop_index: int, slot: int) -> void:
	GameManager.set_troop_slot_preference(army_id, troop_index, slot)
	EventBus.message_log.emit("阵形设置: 编队%d -> 槽位%d" % [troop_index, slot])
	# Refresh the panel
	_on_formation_army_selected(army_id)


func _on_formation_reset(army_id: int) -> void:
	GameManager.clear_army_slot_preferences(army_id)
	EventBus.message_log.emit("阵形重置为自动分配")
	_on_formation_army_selected(army_id)


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


# ── Faction-specific ability handlers ──

func _on_waaagh_burst_pressed() -> void:
	var pid: int = GameManager.get_human_player_id()
	FactionManager.orc_waaagh_burst(pid)
	_update_buttons()
	_update_player_info()


func _on_blood_tribute_pressed() -> void:
	var pid: int = GameManager.get_human_player_id()
	# Show prisoner selection in target panel
	_show_target_panel("Blood Tribute - Select Hero to Sacrifice")
	var prisoners: Array = HeroSystem.captured_heroes
	if prisoners.is_empty():
		_add_target_label("(No captured heroes)")
	else:
		for hero_id in prisoners:
			var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
			var hero_name: String = hero_data.get("name", hero_id)
			_add_target_button("Sacrifice %s (+2 ATK)" % hero_name, _on_blood_tribute_confirm.bind(hero_id))


func _on_blood_tribute_confirm(hero_id: String) -> void:
	var pid: int = GameManager.get_human_player_id()
	FactionManager.orc_blood_tribute(pid, hero_id)
	_close_target_panel()
	_update_buttons()
	_update_player_info()


func _on_rare_market_pressed() -> void:
	var pid: int = GameManager.get_human_player_id()
	var stock: Array = PirateMechanic.get_rare_market_stock(pid)
	_show_target_panel("Rare Black Market (50%% markup, no rep cost)")
	if stock.is_empty():
		_add_target_label("(No rare items available)")
	else:
		for i in range(stock.size()):
			var item: Dictionary = stock[i]
			var label: String = "%s - %s (%dg)" % [item.get("name", "???"), item.get("desc", ""), item.get("price", 0)]
			_add_target_button(label, _on_rare_market_buy.bind(i))


func _on_rare_market_buy(item_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	FactionManager.pirate_buy_rare_item(pid, item_index)
	_close_target_panel()
	_update_buttons()
	_update_player_info()


func _on_shadow_network_pressed() -> void:
	var pid: int = GameManager.get_human_player_id()
	FactionManager.dark_elf_toggle_shadow_network(pid)
	_update_buttons()
	_update_player_info()


func _on_assassination_pressed() -> void:
	var pid: int = GameManager.get_human_player_id()
	# Show target faction selection
	_show_target_panel("Assassination - Select Target Faction")
	var player_faction: int = GameManager.get_player_faction(pid)
	var evil_factions: Array = [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]
	for fid in evil_factions:
		if fid == player_faction:
			continue
		if FactionManager.is_faction_alive(fid):
			var fname: String = FactionData.FACTION_NAMES.get(fid, "Unknown")
			_add_target_button("Assassinate %s Hero" % fname, _on_assassination_confirm.bind(fid))
	# Add light faction targets
	_add_target_button("Assassinate Light Alliance Hero", _on_assassination_confirm.bind(-1))


func _on_assassination_confirm(target_faction_id: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	FactionManager.dark_elf_assassination(pid, target_faction_id)
	_close_target_panel()
	_update_buttons()
	_update_player_info()


func _on_corruption_pressed() -> void:
	var pid: int = GameManager.get_human_player_id()
	# Show neutral tile selection
	_show_target_panel("Corruption - Select Neutral Tile")
	var found: bool = false
	for i in range(GameManager.tiles.size()):
		var tile: Dictionary = GameManager.tiles[i]
		if tile.get("owner_id", -1) == -1:
			var tile_name: String = tile.get("name", "Tile #%d" % i)
			# Check if already being corrupted
			var targets: Array = DarkElfMechanic.get_corruption_targets(pid)
			var already: bool = false
			for t in targets:
				if t.get("tile_index", -1) == i:
					already = true
					break
			if already:
				continue
			_add_target_button("Corrupt %s (#%d)" % [tile_name, i], _on_corruption_confirm.bind(i))
			found = true
	if not found:
		_add_target_label("(No neutral tiles available)")


func _on_corruption_confirm(tile_index: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	FactionManager.dark_elf_corrupt_tile(pid, tile_index)
	_close_target_panel()
	_update_buttons()
	_update_player_info()


func _on_hero_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("open_panel")
	if TutorialManager and TutorialManager.has_method("notify_hero_panel_opened"):
		TutorialManager.notify_hero_panel_opened()
	if PanelManager.has_method("open_panel"):
		PanelManager.open_panel("hero_panel")
func _on_economy_pressed() -> void:
	if _current_mode == ActionMode.DOMESTIC_SUB and _domestic_sub_type == "economy_report":
		_close_target_panel()
		return
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "economy_report"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	_show_target_panel("Economy Report")

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.add_theme_font_size_override("normal_font_size", 11)
	rtl.add_theme_color_override("default_color", Color(0.8, 0.8, 0.85))

	var bbtext: String = ""

	# ── INCOME BREAKDOWN ──
	bbtext += "[b][color=gold]-- Income Breakdown --[/color][/b]\n"
	var type_totals: Dictionary = {}  # tile_type -> {gold, food, iron, count}
	var faction_id: int = GameManager.get_player_faction(pid)
	var params: Dictionary = FactionData.FACTION_PARAMS.get(faction_id, {})
	var gold_mult: float = params.get("gold_income_mult", 1.0) * params.get("base_production_mult", 1.0)
	var food_mult: float = params.get("food_production_mult", 1.0) * params.get("base_production_mult", 1.0)
	var iron_mult: float = params.get("iron_income_mult", 1.0) * params.get("base_production_mult", 1.0)

	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) != pid:
			continue
		var ttype: int = tile.get("type", -1)
		var base: Dictionary = tile.get("base_production", {})
		var level: int = maxi(tile.get("level", 1), 1)
		var level_idx: int = clampi(level - 1, 0, GameManager.UPGRADE_PROD_MULT.size() - 1)
		var level_m: float = GameManager.UPGRADE_PROD_MULT[level_idx] if GameManager.UPGRADE_PROD_MULT.size() > 0 else 1.0
		var tile_order: float = tile.get("public_order", BalanceConfig.TILE_ORDER_DEFAULT)
		var order_m: float = ProductionCalculator.get_tile_order_multiplier(tile_order)
		var g: int = int(roundf(float(base.get("gold", 0)) * level_m * gold_mult * order_m))
		var f: int = int(roundf(float(base.get("food", 0)) * level_m * food_mult * order_m))
		var ir: int = int(roundf(float(base.get("iron", 0)) * level_m * iron_mult * order_m))
		if not type_totals.has(ttype):
			type_totals[ttype] = {"gold": 0, "food": 0, "iron": 0, "count": 0}
		type_totals[ttype]["gold"] += g
		type_totals[ttype]["food"] += f
		type_totals[ttype]["iron"] += ir
		type_totals[ttype]["count"] += 1

	var total_gold_income: int = 0
	var total_food_income: int = 0
	var total_iron_income: int = 0
	for ttype in type_totals:
		var entry: Dictionary = type_totals[ttype]
		var tname: String = GameManager.TILE_NAMES.get(ttype, "Tile#%d" % ttype)
		bbtext += "  %s (x%d): G+%d F+%d I+%d\n" % [tname, entry["count"], entry["gold"], entry["food"], entry["iron"]]
		total_gold_income += entry["gold"]
		total_food_income += entry["food"]
		total_iron_income += entry["iron"]

	# Full calculated income (includes building bonuses, relics, etc.)
	var full_income: Dictionary = ProductionCalculator.calculate_turn_income(pid)
	var bonus_gold: int = full_income.get("gold", 0) - total_gold_income
	var bonus_food: int = full_income.get("food", 0) - total_food_income
	var bonus_iron: int = full_income.get("iron", 0) - total_iron_income
	if bonus_gold != 0 or bonus_food != 0 or bonus_iron != 0:
		bbtext += "  [color=cyan]Bonuses (buildings/relics/buffs):[/color] G%+d F%+d I%+d\n" % [bonus_gold, bonus_food, bonus_iron]

	bbtext += "[color=green]Total Income: G+%d  F+%d  I+%d[/color]\n\n" % [
		full_income.get("gold", 0), full_income.get("food", 0), full_income.get("iron", 0)]

	# ── UPKEEP BREAKDOWN ──
	bbtext += "[b][color=gold]-- Upkeep Breakdown --[/color][/b]\n"
	var food_upkeep: int = ProductionCalculator.calculate_food_upkeep(pid)
	var military_food_upkeep: int = GameData.get_army_upkeep(RecruitManager._get_army_ref(pid))
	var total_food_upkeep: int = food_upkeep + military_food_upkeep
	var gold_upkeep: int = ProductionCalculator.calculate_gold_upkeep(pid)

	bbtext += "  Army food (base): [color=orange]%d[/color]\n" % food_upkeep
	bbtext += "  Army food (T2+ tier): [color=orange]%d[/color]\n" % military_food_upkeep
	bbtext += "  Army gold (salary): [color=orange]%d[/color]\n" % gold_upkeep
	bbtext += "[color=red]Total Upkeep: G-%d  F-%d[/color]\n\n" % [gold_upkeep, total_food_upkeep]

	# ── NET PROFIT ──
	bbtext += "[b][color=gold]-- Net Profit --[/color][/b]\n"
	var net_gold: int = full_income.get("gold", 0) - gold_upkeep
	var net_food: int = full_income.get("food", 0) - total_food_upkeep
	var net_iron: int = full_income.get("iron", 0)
	var gold_color: String = "green" if net_gold >= 0 else "red"
	var food_color: String = "green" if net_food >= 0 else "red"
	bbtext += "  Gold: [color=%s]%+d /turn[/color]\n" % [gold_color, net_gold]
	bbtext += "  Food: [color=%s]%+d /turn[/color]\n" % [food_color, net_food]
	bbtext += "  Iron: [color=green]+%d /turn[/color]\n\n" % net_iron

	# ── TERRITORY EFFECTS ──
	bbtext += "[b][color=gold]-- Territory Effects --[/color][/b]\n"
	var te: Dictionary = GameManager._active_territory_effects
	var active_ids: Array = te.get("_active_ids", [])
	if active_ids.is_empty():
		bbtext += "  [color=gray](No active territory effects)[/color]\n"
	else:
		for eid in active_ids:
			var eff_data: Dictionary = BalanceConfig.TERRITORY_EFFECTS.get(eid, {})
			bbtext += "  [color=cyan]%s[/color]: %s\n" % [eff_data.get("name", eid), eff_data.get("desc", "")]
	bbtext += "\n"

	# ── PREDICTIONS ──
	bbtext += "[b][color=gold]-- Predictions --[/color][/b]\n"
	var current_gold: int = ResourceManager.get_resource(pid, "gold")
	var current_food: int = ResourceManager.get_resource(pid, "food")
	if net_gold < 0:
		var turns_gold: int = ceili(float(current_gold) / float(-net_gold))
		bbtext += "  [color=red]Gold runs out in ~%d turns[/color]\n" % turns_gold
	else:
		bbtext += "  [color=green]Gold: surplus of %d/turn[/color]\n" % net_gold
	if net_food < 0:
		var turns_food: int = ceili(float(current_food) / float(-net_food))
		bbtext += "  [color=red]Food runs out in ~%d turns[/color]\n" % turns_food
	else:
		bbtext += "  [color=green]Food: surplus of %d/turn[/color]\n" % net_food

	rtl.text = bbtext
	target_container.add_child(rtl)
	target_buttons.append(rtl)quest_journal")


func _on_armies_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("open_panel")
	if PanelManager.has_method("open_panel"):
		PanelManager.open_panel("army")


func _on_armies_pressed_legacy() -> void:
	if _current_mode == ActionMode.DOMESTIC_SUB and _domestic_sub_type == "armies_detail":
		_close_target_panel()
		return
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "armies_detail"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	var player_armies: Array = GameManager.get_player_armies(pid)

	_show_target_panel("Army Details")

	if player_armies.is_empty():
		_add_target_label("(No armies deployed)")
		return

	# Build RichTextLabel content with BBCode
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.add_theme_font_size_override("normal_font_size", 11)
	rtl.add_theme_color_override("default_color", Color(0.8, 0.8, 0.85))

	var bbtext: String = ""

	for army in player_armies:
		var army_id: int = army["id"]
		var tile_idx: int = army.get("tile_index", -1)
		var tile_name: String = "???"
		if tile_idx >= 0 and tile_idx < GameManager.tiles.size():
			tile_name = GameManager.tiles[tile_idx].get("name", "???")
		var total_soldiers: int = GameManager.get_army_soldier_count(army_id)
		var total_power: int = GameManager.get_army_combat_power(army_id)

		bbtext += "[b][color=gold]%s[/color][/b]  @%s\n" % [army["name"], tile_name]
		bbtext += "  Strength: [color=cyan]%d[/color]  |  Soldiers: [color=white]%d[/color]\n" % [total_power, total_soldiers]

		# Troops
		var troops: Array = army.get("troops", [])
		if troops.is_empty():
			bbtext += "  [color=gray](No troops)[/color]\n"
		else:
			var army_food_upkeep: int = 0
			var army_gold_upkeep: int = 0
			for troop in troops:
				var troop_id: String = troop.get("troop_id", "")
				var td: Dictionary = GameData.get_troop_def(troop_id)
				var tier: int = td.get("tier", 1)
				var soldiers: int = troop.get("soldiers", 0)
				var max_sol: int = troop.get("max_soldiers", soldiers)
				var troop_name: String = troop.get("name", td.get("name", troop_id))
				var troop_class: int = td.get("troop_class", 0)
				var class_name_str: String = GameData.TROOP_CLASS_NAMES.get(troop_class, "???")
				var atk: int = GameData.get_effective_atk(troop)
				var def_val: int = GameData.get_effective_def(troop)
				var vet: Dictionary = GameData.get_veterancy_bonuses(troop.get("experience", 0))
				var vet_label: String = vet.get("label", "")
				var food_up: int = GameData.TIER_UPKEEP.get(tier, 0)
				var gold_up: int = BalanceConfig.TIER_GOLD_UPKEEP.get(tier, 0)
				army_food_upkeep += food_up
				army_gold_upkeep += gold_up

				var vet_str: String = ""
				if vet_label != "":
					vet_str = " [color=yellow][%s][/color]" % vet_label

				bbtext += "    [color=silver]T%d[/color] %s [%s] %d/%d  ATK:%d DEF:%d%s\n" % [
					tier, troop_name, class_name_str, soldiers, max_sol, atk, def_val, vet_str]

			bbtext += "  [color=orange]Upkeep: %d food + %d gold /turn[/color]\n" % [army_food_upkeep, army_gold_upkeep]

		# Heroes assigned to this army
		var hero_ids: Array = army.get("heroes", [])
		if not hero_ids.is_empty():
			for hid in hero_ids:
				var hdata: Dictionary = FactionData.HEROES.get(hid, {})
				if hdata.is_empty():
					continue
				var hname: String = hdata.get("name", hid)
				var hatk: int = hdata.get("atk", 0)
				var hdef: int = hdata.get("def", 0)
				var hint: int = hdata.get("int", 0)
				var hspd: int = hdata.get("spd", 0)
				bbtext += "  [color=aqua]Hero: %s[/color]  ATK:%d DEF:%d INT:%d SPD:%d\n" % [hname, hatk, hdef, hint, hspd]
		else:
			bbtext += "  [color=gray]No hero assigned[/color]\n"

		# Tactical directive
		var directive_names: Array = ["None", "Aggressive", "Defensive", "Balanced", "Retreat"]
		var dir_idx: int = clampi(GameManager._current_directive, 0, directive_names.size() - 1)
		bbtext += "  Directive: [color=white]%s[/color]\n" % directive_names[dir_idx]

		bbtext += "\n"

	rtl.text = bbtext
	target_container.add_child(rtl)
	target_buttons.append(rtl)


func _on_economy_pressed() -> void:
	if _current_mode == ActionMode.DOMESTIC_SUB and _domestic_sub_type == "economy_report":
		_close_target_panel()
		return
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "economy_report"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	_show_target_panel("Economy Report")

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.scroll_active = false
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS
	rtl.add_theme_font_size_override("normal_font_size", 11)
	rtl.add_theme_color_override("default_color", Color(0.8, 0.8, 0.85))

	var bbtext: String = ""

	# ── INCOME BREAKDOWN ──
	bbtext += "[b][color=gold]-- Income Breakdown --[/color][/b]\n"
	var type_totals: Dictionary = {}  # tile_type -> {gold, food, iron, count}
	var faction_id: int = GameManager.get_player_faction(pid)
	var params: Dictionary = FactionData.FACTION_PARAMS.get(faction_id, {})
	var gold_mult: float = params.get("gold_income_mult", 1.0) * params.get("base_production_mult", 1.0)
	var food_mult: float = params.get("food_production_mult", 1.0) * params.get("base_production_mult", 1.0)
	var iron_mult: float = params.get("iron_income_mult", 1.0) * params.get("base_production_mult", 1.0)

	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) != pid:
			continue
		var ttype: int = tile.get("type", -1)
		var base: Dictionary = tile.get("base_production", {})
		var level: int = maxi(tile.get("level", 1), 1)
		var level_idx: int = clampi(level - 1, 0, GameManager.UPGRADE_PROD_MULT.size() - 1)
		var level_m: float = GameManager.UPGRADE_PROD_MULT[level_idx] if GameManager.UPGRADE_PROD_MULT.size() > 0 else 1.0
		var tile_order: float = tile.get("public_order", BalanceConfig.TILE_ORDER_DEFAULT)
		var order_m: float = ProductionCalculator.get_tile_order_multiplier(tile_order)
		var g: int = int(roundf(float(base.get("gold", 0)) * level_m * gold_mult * order_m))
		var f: int = int(roundf(float(base.get("food", 0)) * level_m * food_mult * order_m))
		var ir: int = int(roundf(float(base.get("iron", 0)) * level_m * iron_mult * order_m))
		if not type_totals.has(ttype):
			type_totals[ttype] = {"gold": 0, "food": 0, "iron": 0, "count": 0}
		type_totals[ttype]["gold"] += g
		type_totals[ttype]["food"] += f
		type_totals[ttype]["iron"] += ir
		type_totals[ttype]["count"] += 1

	var total_gold_income: int = 0
	var total_food_income: int = 0
	var total_iron_income: int = 0
	for ttype in type_totals:
		var entry: Dictionary = type_totals[ttype]
		var tname: String = GameManager.TILE_NAMES.get(ttype, "Tile#%d" % ttype)
		bbtext += "  %s (x%d): G+%d F+%d I+%d\n" % [tname, entry["count"], entry["gold"], entry["food"], entry["iron"]]
		total_gold_income += entry["gold"]
		total_food_income += entry["food"]
		total_iron_income += entry["iron"]

	# Full calculated income (includes building bonuses, relics, etc.)
	var full_income: Dictionary = ProductionCalculator.calculate_turn_income(pid)
	var bonus_gold: int = full_income.get("gold", 0) - total_gold_income
	var bonus_food: int = full_income.get("food", 0) - total_food_income
	var bonus_iron: int = full_income.get("iron", 0) - total_iron_income
	if bonus_gold != 0 or bonus_food != 0 or bonus_iron != 0:
		bbtext += "  [color=cyan]Bonuses (buildings/relics/buffs):[/color] G%+d F%+d I%+d\n" % [bonus_gold, bonus_food, bonus_iron]

	bbtext += "[color=green]Total Income: G+%d  F+%d  I+%d[/color]\n\n" % [
		full_income.get("gold", 0), full_income.get("food", 0), full_income.get("iron", 0)]

	# ── UPKEEP BREAKDOWN ──
	bbtext += "[b][color=gold]-- Upkeep Breakdown --[/color][/b]\n"
	var food_upkeep: int = ProductionCalculator.calculate_food_upkeep(pid)
	var military_food_upkeep: int = GameData.get_army_upkeep(RecruitManager._get_army_ref(pid))
	var total_food_upkeep: int = food_upkeep + military_food_upkeep
	var gold_upkeep: int = ProductionCalculator.calculate_gold_upkeep(pid)

	bbtext += "  Army food (base): [color=orange]%d[/color]\n" % food_upkeep
	bbtext += "  Army food (T2+ tier): [color=orange]%d[/color]\n" % military_food_upkeep
	bbtext += "  Army gold (salary): [color=orange]%d[/color]\n" % gold_upkeep
	bbtext += "[color=red]Total Upkeep: G-%d  F-%d[/color]\n\n" % [gold_upkeep, total_food_upkeep]

	# ── NET PROFIT ──
	bbtext += "[b][color=gold]-- Net Profit --[/color][/b]\n"
	var net_gold: int = full_income.get("gold", 0) - gold_upkeep
	var net_food: int = full_income.get("food", 0) - total_food_upkeep
	var net_iron: int = full_income.get("iron", 0)
	var gold_color: String = "green" if net_gold >= 0 else "red"
	var food_color: String = "green" if net_food >= 0 else "red"
	bbtext += "  Gold: [color=%s]%+d /turn[/color]\n" % [gold_color, net_gold]
	bbtext += "  Food: [color=%s]%+d /turn[/color]\n" % [food_color, net_food]
	bbtext += "  Iron: [color=green]+%d /turn[/color]\n\n" % net_iron

	# ── TERRITORY EFFECTS ──
	bbtext += "[b][color=gold]-- Territory Effects --[/color][/b]\n"
	var te: Dictionary = GameManager._active_territory_effects
	var active_ids: Array = te.get("_active_ids", [])
	if active_ids.is_empty():
		bbtext += "  [color=gray](No active territory effects)[/color]\n"
	else:
		for eid in active_ids:
			var eff_data: Dictionary = BalanceConfig.TERRITORY_EFFECTS.get(eid, {})
			bbtext += "  [color=cyan]%s[/color]: %s\n" % [eff_data.get("name", eid), eff_data.get("desc", "")]
	bbtext += "\n"

	# ── PREDICTIONS ──
	bbtext += "[b][color=gold]-- Predictions --[/color][/b]\n"
	var current_gold: int = ResourceManager.get_resource(pid, "gold")
	var current_food: int = ResourceManager.get_resource(pid, "food")
	if net_gold < 0:
		var turns_gold: int = ceili(float(current_gold) / float(-net_gold))
		bbtext += "  [color=red]Gold runs out in ~%d turns[/color]\n" % turns_gold
	else:
		bbtext += "  [color=green]Gold: surplus of %d/turn[/color]\n" % net_gold
	if net_food < 0:
		var turns_food: int = ceili(float(current_food) / float(-net_food))
		bbtext += "  [color=red]Food runs out in ~%d turns[/color]\n" % turns_food
	else:
		bbtext += "  [color=green]Food: surplus of %d/turn[/color]\n" % net_food

	rtl.text = bbtext
	target_container.add_child(rtl)
	target_buttons.append(rtl)


func _on_event_manager_pressed() -> void:
	if PanelManager.has_method("toggle_panel"):
		PanelManager.toggle_panel("event_manager")


func _on_mission_pressed() -> void:
	if PanelManager.has_method("toggle_panel"):
		PanelManager.toggle_panel("mission")


func _on_research_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("open_panel")
	if PanelManager.has_method("open_panel"):
		PanelManager.open_panel("tech_tree")


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
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("turn_end")
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

	# Check domination: >= 75% tiles
	var total_tiles: int = GameManager.tiles.size()
	var human_tiles: int = GameManager.count_tiles_owned(human_id)
	if total_tiles > 0 and float(human_tiles) / float(total_tiles) >= BalanceConfig.DOMINANCE_VICTORY_PCT:
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

	# Check diplomatic victory: alliance with all surviving evil factions
	var surviving_rivals: Array = []
	for pid in range(1, GameManager.players.size()):
		if pid == human_id:
			continue
		if GameManager.count_tiles_owned(pid) > 0:
			surviving_rivals.append(pid)
	if surviving_rivals.size() > 0:
		var all_allied: bool = true
		for rival_pid in surviving_rivals:
			var rival_faction: int = GameManager._player_factions.get(rival_pid, -1)
			if not DiplomacyManager.has_treaty(human_id, "alliance", rival_faction):
				all_allied = false
				break
		if all_allied:
			return "Diplomatic Victory"

	# Check survival victory
	if BalanceConfig.SURVIVAL_TURN_GOAL > 0 and GameManager.turn_number >= BalanceConfig.SURVIVAL_TURN_GOAL:
		var cap_idx: int = GameManager.game_stats.get("capital_tile", -1)
		if cap_idx >= 0 and cap_idx < GameManager.tiles.size() and GameManager.tiles[cap_idx]["owner_id"] == human_id:
			return "Survival Victory"

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


func _get_score_breakdown(score_data: Dictionary) -> Array:
	## Build detailed score breakdown lines from score data dictionary.
	var lines: Array = []
	lines.append("--- Score Breakdown ---")
	lines.append("Territory: %d/%d  (+%d)" % [
		score_data.get("territories_owned", 0),
		score_data.get("territories_total", 0),
		score_data.get("territory_score", 0)])
	lines.append("Heroes: %d  (+%d)" % [
		score_data.get("heroes_recruited", 0),
		score_data.get("hero_score", 0)])
	lines.append("Battles: %dW / %dL  (%+d)" % [
		score_data.get("battles_won", 0),
		score_data.get("battles_lost", 0),
		score_data.get("battle_score", 0)])
	lines.append("Turns: %d  (+%d)" % [
		score_data.get("turns_taken", 0),
		score_data.get("turn_score", 0)])
	lines.append("Subtotal: %d" % score_data.get("subtotal", 0))
	var vtype: String = score_data.get("victory_type", "")
	var mult: float = score_data.get("multiplier", 1.0)
	if vtype != "":
		lines.append("%s bonus: x%.1f" % [vtype, mult])
	lines.append("=== Final Score: %d ===" % score_data.get("final_score", 0))
	return lines
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
	# Operations buttons
	btn_guard.disabled = not has_ap
	btn_reinforce.disabled = not has_ap
	btn_commander.disabled = false
	btn_interrogate.disabled = HeroSystem.captured_heroes.is_empty()

	# SAT Event button (free action, requires SAT points)
	var sat_pts: int = GameManager.get_sat_points(pid)
	btn_sat_event.text = "SAT Event (%d)" % sat_pts
	btn_sat_event.disabled = sat_pts <= 0

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

	# ── Faction-specific ability button visibility & state ──
	var is_orc: bool = faction_id == FactionData.FactionID.ORC
	var is_dark_elf: bool = faction_id == FactionData.FactionID.DARK_ELF

	# Orc buttons
	btn_waaagh_burst.visible = is_orc
	btn_blood_tribute.visible = is_orc
	if is_orc:
		var waaagh_power: int = OrcMechanic.get_waaagh_power(pid)
		btn_waaagh_burst.text = "WAAAGH! Burst (%d/10)" % waaagh_power
		btn_waaagh_burst.disabled = not OrcMechanic.can_trigger_waaagh_burst(pid)
		var has_prisoners: bool = not HeroSystem.captured_heroes.is_empty()
		btn_blood_tribute.disabled = not has_prisoners

	# Pirate buttons
	btn_rare_market.visible = is_pirate
	if is_pirate:
		var timer: int = PirateMechanic.get_rare_restock_timer(pid)
		var stock: Array = PirateMechanic.get_rare_market_stock(pid)
		btn_rare_market.text = "Rare Market (%d items, %dT)" % [stock.size(), timer]
		btn_rare_market.disabled = stock.is_empty()

	# Dark Elf buttons
	btn_shadow_network.visible = is_dark_elf
	btn_assassination.visible = is_dark_elf
	btn_corruption.visible = is_dark_elf
	if is_dark_elf:
		var net_active: bool = DarkElfMechanic.is_shadow_network_active(pid)
		btn_shadow_network.text = "Shadow Network [%s]" % ("ON" if net_active else "OFF")
		btn_shadow_network.disabled = false
		var can_assassinate: bool = DarkElfMechanic.can_assassinate(pid)
		var cooldown: int = DarkElfMechanic.get_assassination_cooldown(pid)
		if cooldown > 0:
			btn_assassination.text = "Assassinate (CD:%d)" % cooldown
		else:
			btn_assassination.text = "Assassinate (2AP)"
		btn_assassination.disabled = not can_assassinate
		btn_corruption.disabled = not ResourceManager.can_afford(pid, {"prestige": 15})

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
	btn_guard.disabled = val
	btn_commander.disabled = val
	btn_reinforce.disabled = val
	btn_interrogate.disabled = val
	btn_end_turn.disabled = val
	btn_reduce_threat.disabled = val
	btn_boost_order.disabled = val
	btn_sell_slave.disabled = val
	btn_buy_slave.disabled = val
	btn_sat_event.disabled = val


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
	if ap_display:
		var current_ap: int = player.get("ap", 0)
		ap_display.text = str(current_ap)
		if current_ap <= 0:
			ap_display.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		elif current_ap == 1:
			ap_display.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
		else:
			ap_display.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	stronghold_label.text = "Fort:%s" % GameManager.get_stronghold_progress(pid)

	if _icon_order:
		order_label.text = "%d (x%.2f)" % [OrderManager.get_order(), OrderManager.get_production_multiplier()]
	else:
		order_label.text = "Order:%d (x%.2f)" % [OrderManager.get_order(), OrderManager.get_production_multiplier()]
	if _icon_threat:
		threat_label.text = "%d [%s]" % [ThreatManager.get_threat(), ThreatManager.get_tier_name()]
	else:
		threat_label.text = "Threat:%d [%s]" % [ThreatManager.get_threat(), ThreatManager.get_tier_name()]

	# Update Order/Threat bars
	if order_bar:
		order_bar.value = OrderManager.get_order()
	if threat_bar:
		threat_bar.value = ThreatManager.get_threat()

	# Per-turn income deltas
	var full_income: Dictionary = ProductionCalculator.calculate_turn_income(pid) if ProductionCalculator.has_method("calculate_turn_income") else {}
	var food_upkeep: int = ProductionCalculator.calculate_food_upkeep(pid) if ProductionCalculator.has_method("calculate_food_upkeep") else 0
	var gold_upkeep: int = ProductionCalculator.calculate_gold_upkeep(pid) if ProductionCalculator.has_method("calculate_gold_upkeep") else 0
	var military_food_upkeep: int = GameData.get_army_upkeep(RecruitManager._get_army_ref(pid)) if GameData.has_method("get_army_upkeep") else 0

	var net_gold: int = full_income.get("gold", 0) - gold_upkeep
	var net_food: int = full_income.get("food", 0) - food_upkeep - military_food_upkeep
	var net_iron: int = full_income.get("iron", 0)

	gold_delta_label.text = "%+d" % net_gold if net_gold != 0 else ""
	gold_delta_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if net_gold >= 0 else Color(1.0, 0.3, 0.3))
	food_delta_label.text = "%+d" % net_food if net_food != 0 else ""
	food_delta_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if net_food >= 0 else Color(1.0, 0.3, 0.3))
	iron_delta_label.text = "%+d" % net_iron if net_iron != 0 else ""
	iron_delta_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4) if net_iron >= 0 else Color(1.0, 0.3, 0.3))

	# WAAAGH! display for Orc faction
	var faction_id: int = GameManager.get_player_faction(pid)
	if faction_id == FactionData.FactionID.ORC:
		var w: int = OrcMechanic.get_waaagh(pid)
		var wp: int = OrcMechanic.get_waaagh_power(pid)
		var burst: int = OrcMechanic.get_burst_turns(pid)
		var exhaust: int = OrcMechanic.get_exhaust_turns(pid)
		var extra: String = ""
		if burst > 0:
			extra = " [BURST:%dT]" % burst
		elif exhaust > 0:
			extra = " [EXH:%dT]" % exhaust
		waaagh_label.text = "W!:%d P:%d%s" % [w, wp, extra]
		waaagh_label.visible = true
		if burst > 0:
			waaagh_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
		elif exhaust > 0:
			waaagh_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		elif OrcMechanic.is_in_frenzy(pid):
			waaagh_label.add_theme_color_override("font_color", Color(1.0, 0.0, 0.0))
		else:
			waaagh_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
	elif faction_id == FactionData.FactionID.PIRATE:
		# Pirate: show intimidation bonus if active
		var intim_bonus: int = PirateMechanic.get_intimidation_atk_bonus(pid)
		if intim_bonus > 0:
			waaagh_label.text = "Intim:+%d ATK" % intim_bonus
			waaagh_label.visible = true
			waaagh_label.add_theme_color_override("font_color", Color(0.8, 0.4, 0.1))
		else:
			waaagh_label.visible = false
	elif faction_id == FactionData.FactionID.DARK_ELF:
		# Dark Elf: show shadow network status
		if DarkElfMechanic.is_shadow_network_active(pid):
			waaagh_label.text = "Shadow:ON"
			waaagh_label.visible = true
			waaagh_label.add_theme_color_override("font_color", Color(0.6, 0.2, 0.8))
		else:
			waaagh_label.visible = false
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
		info += "[color=green]Captured[/color]"
		# Capital & supply line indicators
		if SupplySystem.is_capital_tile(pid, tile_idx):
			info += " [color=gold][Capital][/color]"
		if not SupplySystem.is_tile_supplied(pid, tile_idx):
			info += " [color=red][ISOLATED][/color]"
		info += "\n"
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
#               VISUAL FEEDBACK HELPERS (v4.6)
# ═══════════════════════════════════════════════════════════════

## Flash a resource label yellow (gain) or red (loss) then back to white
func _flash_resource_label(label: Label, is_gain: bool) -> void:
	ColorTheme.flash_label(label, is_gain)

## Brief scale pulse on a button after a successful action
func _pulse_button(btn: Button) -> void:
	ColorTheme.pulse_button(btn)

## Slide the phase banner in from top with ease-out
func _animate_phase_banner_in() -> void:
	if not is_instance_valid(_phase_banner): return
	var target_top: float = _phase_banner.offset_top
	_phase_banner.offset_top = target_top - 60
	var tw := create_tween()
	tw.tween_property(_phase_banner, "offset_top", target_top, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


# ═══════════════════════════════════════════════════════════════
#                  KEYBOARD SHORTCUTS
# ═══════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.game_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		# Don't process shortcuts if any panel is open that might need text input
		if game_over_panel.visible:
			return
		var player: Dictionary = GameManager.get_current_player()
		if player.is_empty() or player.get("is_ai", true):
			return
		match event.keycode:
			KEY_1:
				_on_attack_pressed()
				get_viewport().set_input_as_handled()
			KEY_2:
				_on_deploy_pressed()
				get_viewport().set_input_as_handled()
			KEY_3:
				_on_domestic_pressed()
				get_viewport().set_input_as_handled()
			KEY_4:
				_on_diplomacy_pressed()
				get_viewport().set_input_as_handled()
			KEY_5:
				_on_explore_pressed()
				get_viewport().set_input_as_handled()
			KEY_H:
				_on_hero_pressed()
				get_viewport().set_input_as_handled()
			KEY_J:
				_on_quest_journal_pressed()
				get_viewport().set_input_as_handled()
			KEY_A:
				_on_armies_pressed()
				get_viewport().set_input_as_handled()
			KEY_E:
				_on_event_manager_pressed()
				get_viewport().set_input_as_handled()
			KEY_U:
				_on_troop_training()
				get_viewport().set_input_as_handled()
			KEY_F:
				_on_equipment_forge()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				_on_end_turn_pressed()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_close_target_panel()
				get_viewport().set_input_as_handled()
			KEY_F5:
				_on_save_pressed()
				get_viewport().set_input_as_handled()
			KEY_F9:
				_on_load_pressed()
				get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════
#                  SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_turn_started(_player_id: int) -> void:
	# Audio trigger for new turn
	if _player_id == GameManager.get_human_player_id():
		if AudioManager and AudioManager.has_method("play_sfx_by_name"):
			AudioManager.play_sfx_by_name("turn_start")
	_close_target_panel()
	_update_player_info()
	_update_tile_info()
	_update_buttons()
	_update_items()
	# Flash turn label on new turn
	if turn_label and _player_id == GameManager.get_human_player_id():
		var original_color: Color = turn_label.get_theme_color("font_color") if turn_label.has_theme_color_override("font_color") else Color.WHITE
		turn_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
		var tw := create_tween()
		tw.tween_property(turn_label, "theme_override_colors/font_color", original_color, 0.8).set_ease(Tween.EASE_IN)
	# Visual: snapshot resources for change detection on next update
	var pid: int = GameManager.get_human_player_id()
	_prev_gold = ResourceManager.get_resource(pid, "gold")
	_prev_food = ResourceManager.get_resource(pid, "food")
	_prev_iron = ResourceManager.get_resource(pid, "iron")
	# Update crisis countdown display
	_update_crisis_display()


func _on_turn_ended(_player_id: int) -> void:
	_close_target_panel()
	_update_buttons()


func _on_resources_changed(_pid: int) -> void:
	# Visual: flash resource labels on significant change (>10%)
	var pid: int = GameManager.get_human_player_id()
	if _pid == pid and _prev_gold >= 0:
		var new_gold: int = ResourceManager.get_resource(pid, "gold")
		var new_food: int = ResourceManager.get_resource(pid, "food")
		var new_iron: int = ResourceManager.get_resource(pid, "iron")
		var threshold := 0.10
		if _prev_gold > 0 and absf(float(new_gold - _prev_gold) / _prev_gold) > threshold:
			_flash_resource_label(gold_label, new_gold > _prev_gold)
		if _prev_food > 0 and absf(float(new_food - _prev_food) / _prev_food) > threshold:
			_flash_resource_label(food_label, new_food > _prev_food)
		if _prev_iron > 0 and absf(float(new_iron - _prev_iron) / _prev_iron) > threshold:
			_flash_resource_label(iron_label, new_iron > _prev_iron)
		_prev_gold = new_gold
		_prev_food = new_food
		_prev_iron = new_iron
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
	# 如果 ProvinceInfoPanel 已加载，则隐藏 HUD 右侧旧信息栏，让新面板独占显示
	var main_node = get_tree().get_root().get_node_or_null("Main")
	if main_node and "province_info_panel" in main_node and main_node.province_info_panel != null:
		if _tile_info_panel_container:
			_tile_info_panel_container.visible = false
		return
	# Show the tile info for the selected territory (fallback when ProvinceInfoPanel not available)
	if _tile_info_panel_container:
		_tile_info_panel_container.visible = true
	_update_tile_info_for(tile_index)


func _update_tile_info_for(tile_index: int) -> void:
	if GameManager.tiles.is_empty():
		return
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
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
		var own_label: String = "[color=green]Own territory[/color]"
		if SupplySystem.is_capital_tile(pid, tile_index):
			own_label += " [color=gold][Capital][/color]"
		if not SupplySystem.is_tile_supplied(pid, tile_index):
			own_label += " [color=red][ISOLATED — Supply cut!][/color]"
		info += own_label + "\n"
	elif tile["owner_id"] >= 0:
		var _owner = GameManager.get_player_by_id(tile["owner_id"])
		var oname: String = _owner.get("name", "Enemy") if _owner else "Enemy"
		info += "[color=red]Owner: %s[/color]\n" % oname
	else:
		info += "[color=gray]Unclaimed[/color]\n"

	# Production (show for any owned tile)
	if tile["owner_id"] >= 0:
		var prod: Dictionary = GameManager.get_tile_production(tile) if GameManager.has_method("get_tile_production") else {}
		if not prod.is_empty():
			info += "Output: [color=gold]Gold %d[/color] [color=green]Food %d[/color] [color=silver]Iron %d[/color]\n" % [prod.get("gold", 0), prod.get("food", 0), prod.get("iron", 0)]

	# Building
	var bld: String = tile.get("building_id", "")
	if bld != "":
		var bld_level: int = tile.get("building_level", 1)
		var max_level: int = BuildingRegistry.get_building_max_level(bld) if BuildingRegistry.has_method("get_building_max_level") else bld_level
		info += "Building: [color=orchid]%s[/color] (Lv%d/%d)\n" % [BuildingRegistry.get_building_name(bld), bld_level, max_level]
	elif tile["owner_id"] == pid:
		info += "[color=gray]No building (can build)[/color]\n"

	# Garrison
	var garrison: int = tile.get("garrison", 0)
	if garrison > 0:
		info += "Garrison: %d\n" % garrison

	# SR07: Garrison commander display
	var stationed_hero_id: String = HeroSystem.get_stationed_hero(tile_index)
	if stationed_hero_id != "":
		var hero_info: Dictionary = HeroSystem.get_hero_info(stationed_hero_id)
		var hero_name: String = hero_info.get("name", stationed_hero_id)
		var cmd_bonus: Dictionary = HeroSystem.get_garrison_commander_bonus(tile_index)
		info += "[color=orchid]Commander: %s[/color]\n" % hero_name
		info += "[color=gray]  DEF+25%% Prod+15%% Order+%d Garrison+%d[/color]\n" % [cmd_bonus.get("order_bonus", 0), cmd_bonus.get("garrison_add", 0)]
	elif tile["owner_id"] == pid and garrison > 0:
		info += "[color=gray]No commander (can assign)[/color]\n"

	# Guard status
	if GameManager._guard_timers.has(tile_index):
		var guard_info: Dictionary = GameManager._guard_timers[tile_index]
		var guard_owner: int = guard_info.get("player_id", -1)
		var turns_left: int = guard_info.get("turns_remaining", 0)
		if guard_owner == pid:
			info += "[color=cyan]Guarded (%d turn%s remaining) DEF+50%%[/color]\n" % [turns_left, "" if turns_left == 1 else "s"]
		else:
			info += "[color=orange]Enemy guarded (%d turn%s)[/color]\n" % [turns_left, "" if turns_left == 1 else "s"]

	# Army stationed here (v0.9.2)
	var army: Dictionary = GameManager.get_army_at_tile(tile_index)
	if not army.is_empty():
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var power: int = GameManager.get_army_combat_power(army["id"])
		var troop_count: int = army["troops"].size()
		info += "[color=yellow]━━ Army: %s ━━[/color]\n" % army["name"]
		info += "Troops: %d/%d | Soldiers: %d | Power: %d\n" % [troop_count, GameManager.get_effective_max_troops(army.get("player_id", pid)), soldiers, power]
		if army["player_id"] == pid:
			# Supply line status via SupplySystem
			var supply_status: Dictionary = SupplySystem.get_army_supply_status(army)
			var supply_label: String = supply_status.get("status_label", "[color=green]补给充足[/color]")
			var supply_code: String = supply_status.get("status", "supplied")
			info += "Supply: %s" % supply_label
			var dist: int = supply_status.get("distance", -1)
			if dist > 0:
				info += " (distance: %d)" % dist
			info += "\n"
			# Show warning for cut-off or strained supply
			if supply_code == "cut_off" or supply_code == "no_capital":
				info += "[color=red]!! CUT OFF — No reinforcement, morale draining, troops attriting !![/color]\n"
			elif supply_code == "extended":
				info += "[color=orange]Supply line overextended — reduced efficiency[/color]\n"
			# Show capital info
			var cap_tile: int = supply_status.get("capital_tile", -1)
			if cap_tile >= 0 and cap_tile < GameManager.tiles.size():
				var cap_name: String = GameManager.tiles[cap_tile].get("name", "Unknown")
				info += "[color=gray]Capital: %s[/color]\n" % cap_name
		else:
			var army_owner = GameManager.get_player_by_id(army["player_id"])
			var army_owner_name: String = army_owner.get("name", "Unknown") if army_owner else "Unknown"
			info += "[color=red]Owner: %s[/color]\n"  % army_owner_name

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

	# Quick power comparison if there are armies nearby
	var pid2: int = GameManager.get_human_player_id()
	var player_total_power: int = 0
	var enemy_total_power: int = 0
	for army_id_key in GameManager.armies:
		var a: Dictionary = GameManager.armies[army_id_key]
		var a_power: int = GameManager.get_army_combat_power(army_id_key)
		if a["player_id"] == pid2:
			player_total_power += a_power
		elif a["player_id"] >= 0:
			enemy_total_power += a_power
	info += "\n[color=gray]━━ Global Power ━━[/color]\n"
	info += "[color=cyan]Your Total: %d[/color] | [color=red]Enemy: %d[/color]\n" % [player_total_power, enemy_total_power]
	var ratio: float = float(player_total_power) / maxf(float(enemy_total_power), 1.0)
	if ratio > 1.5:
		info += "[color=green]Advantage: %.1fx[/color]\n" % ratio
	elif ratio < 0.7:
		info += "[color=red]Disadvantage: %.1fx[/color]\n" % ratio
	else:
		info += "[color=yellow]Contested: %.1fx[/color]\n" % ratio

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
	# Legacy handler for game_over signal (no score data).
	# The detailed handler below will be called by game_over_detailed with score data.
	# If game_over_detailed fires, it will override this panel — safe to show basic view here.
	var human_id: int = GameManager.get_human_player_id()
	var is_victory: bool = (winner_id == human_id)

	# ── Determine victory type ──
	var victory_type: String = ""
	if is_victory:
		victory_type = _detect_victory_type(human_id)
		game_over_label.text = "%s Wins!" % GameManager.get_player_by_id(human_id).get("name", "Player")
		game_over_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
		game_over_victory_type_label.text = victory_type
		game_over_victory_type_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
		game_over_style.border_color = ColorTheme.BORDER_VICTORY
		game_over_style.bg_color = ColorTheme.BG_VICTORY
	else:
		victory_type = "Defeat"
		game_over_label.text = "Game Over..."
		game_over_label.add_theme_color_override("font_color", ColorTheme.TEXT_RED)
		game_over_victory_type_label.text = victory_type
		game_over_victory_type_label.add_theme_color_override("font_color", ColorTheme.TEXT_RED)
		game_over_style.border_color = ColorTheme.BORDER_DEFEAT
		game_over_style.bg_color = ColorTheme.BG_DEFEAT

	# ── Populate stats (basic fallback, detailed handler may override) ──
	for child in game_over_stats_vbox.get_children():
		child.queue_free()
	var stats: Array = _get_victory_stats(human_id)
	for stat_text in stats:
		var lbl := _make_label(stat_text, 13, ColorTheme.TEXT_DIM)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_over_stats_vbox.add_child(lbl)

	game_over_panel.visible = true
	ColorTheme.animate_panel_open(game_over_panel)
	_update_buttons()


func _on_game_over_detailed(data: Dictionary) -> void:
	## Enhanced game over handler with full score breakdown.
	var human_id: int = GameManager.get_human_player_id()
	var is_victory: bool = data.get("is_victory", false)
	var victory_type: String = data.get("victory_type", "")
	var reason: String = data.get("reason", "")
	var score_data: Dictionary = data.get("score", {})

	# ── Title and styling ──
	if is_victory:
		if victory_type == "":
			victory_type = _detect_victory_type(human_id)
		game_over_label.text = "%s Wins!" % GameManager.get_player_by_id(human_id).get("name", "Player")
		game_over_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
		game_over_victory_type_label.text = victory_type
		game_over_victory_type_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
		game_over_style.border_color = ColorTheme.BORDER_VICTORY
		game_over_style.bg_color = ColorTheme.BG_VICTORY
	else:
		var defeat_label: String = "Defeat"
		if reason != "":
			defeat_label = "Defeat: %s" % reason
		game_over_label.text = "Game Over..."
		game_over_label.add_theme_color_override("font_color", ColorTheme.TEXT_RED)
		game_over_victory_type_label.text = defeat_label
		game_over_victory_type_label.add_theme_color_override("font_color", ColorTheme.TEXT_RED)
		game_over_style.border_color = ColorTheme.BORDER_DEFEAT
		game_over_style.bg_color = ColorTheme.BG_DEFEAT

	# ── Populate stats with score breakdown ──
	for child in game_over_stats_vbox.get_children():
		child.queue_free()

	# Basic stats first
	var basic_stats: Array = _get_victory_stats(human_id)
	for stat_text in basic_stats:
		var lbl := _make_label(stat_text, 13, ColorTheme.TEXT_DIM)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		game_over_stats_vbox.add_child(lbl)

	# Score breakdown if available
	if not score_data.is_empty():
		var score_lines: Array = _get_score_breakdown(score_data)
		for line_text in score_lines:
			var score_color: Color = ColorTheme.TEXT_GOLD if is_victory else ColorTheme.TEXT_DIM
			# Highlight the final score line
			var font_size: int = 13
			if line_text.begins_with("==="):
				font_size = 15
				score_color = ColorTheme.TEXT_GOLD if is_victory else ColorTheme.TEXT_RED
			var lbl := _make_label(line_text, font_size, score_color)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			game_over_stats_vbox.add_child(lbl)

	game_over_panel.visible = true
	ColorTheme.animate_panel_open(game_over_panel)
	_update_buttons()


func _on_combat_result(_attacker_id: int, _defender_desc: String, _won: bool) -> void:
	# Refresh all UI after combat resolves
	_update_player_info()
	_update_tile_info()
	_update_buttons()


func _on_order_changed(_new_value: int) -> void:
	_update_player_info()

func _on_threat_changed(_new_value: int) -> void:
	_update_player_info()


func _on_ap_changed(_pid: int, _new_ap: int) -> void:
	_update_player_info()
	_update_buttons()


func _on_territory_changed(_tile_index: int, _new_owner_id: int) -> void:
	_update_player_info()
	_update_tile_info()
	_update_buttons()


func _on_territory_deselected() -> void:
	_update_tile_info()


func _on_army_deployed(_pid: int, _army_id: int, _from: int, _to: int) -> void:
	_update_player_info()
	_update_tile_info()


func _on_strategic_resource_changed(_pid: int, _key: String, _val: int) -> void:
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


func _make_frame_style(tex: Texture2D, tex_margin: Array, content_margin: Array, fallback_color: Color) -> StyleBox:
	## Build a StyleBoxTexture from an HD frame, or fall back to flat color.
	## tex_margin = [left, top, right, bottom], content_margin = [left, top, right, bottom]
	if tex:
		var stex := StyleBoxTexture.new()
		stex.texture = tex
		stex.texture_margin_left = tex_margin[0]
		stex.texture_margin_top = tex_margin[1]
		stex.texture_margin_right = tex_margin[2]
		stex.texture_margin_bottom = tex_margin[3]
		stex.content_margin_left = content_margin[0]
		stex.content_margin_top = content_margin[1]
		stex.content_margin_right = content_margin[2]
		stex.content_margin_bottom = content_margin[3]
		return stex
	return _make_panel_style(fallback_color)


func _make_top_bar_style() -> StyleBox:
	return _make_frame_style(_frame_top_bar,
		[60, 30, 60, 20], [70, 14, 70, 8],
		ColorTheme.BG_PRIMARY)


func _make_info_panel_style() -> StyleBox:
	return _make_frame_style(_frame_info_panel,
		[30, 50, 30, 20], [20, 45, 20, 12],
		ColorTheme.BG_SECONDARY)


func _make_content_panel_style() -> StyleBox:
	return _make_frame_style(_frame_content,
		[25, 20, 25, 30], [14, 12, 14, 16],
		ColorTheme.BG_PANEL)


func _make_action_bar_style() -> StyleBox:
	return _make_frame_style(_frame_action_bar,
		[30, 40, 30, 20], [16, 30, 16, 10],
		ColorTheme.BG_PANEL)


func _make_parchment_style() -> StyleBox:
	return _make_frame_style(_frame_parchment,
		[8, 8, 8, 8], [10, 10, 10, 10],
		ColorTheme.BG_DARK)


func _make_dialog_style() -> StyleBox:
	return _make_frame_style(_frame_dialog,
		[40, 40, 40, 40], [30, 30, 30, 30],
		ColorTheme.BG_PRIMARY)


func _make_icon_label(icon: Texture2D, text: String, size: int, color: Color, min_w: float) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 2)
	hb.custom_minimum_size.x = min_w
	if icon:
		var tex_rect := TextureRect.new()
		tex_rect.texture = icon
		tex_rect.custom_minimum_size = Vector2(18, 18)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(tex_rect)
	var lbl := _make_label(text, size, color)
	hb.add_child(lbl)
	return hb


func _make_resource_bar(label_text: String, max_val: int, color: Color, min_w: float) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	hb.custom_minimum_size.x = min_w
	var lbl := _make_label(label_text, 11, color)
	lbl.custom_minimum_size.x = 50
	hb.add_child(lbl)
	var bar := ProgressBar.new()
	bar.max_value = max_val
	bar.value = 0
	bar.custom_minimum_size = Vector2(80, 14)
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Style the bar
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	bg_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg_style)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill_style)
	hb.add_child(bar)
	var val_lbl := _make_label("0", 11, color)
	hb.add_child(val_lbl)
	return hb

func _make_label(text: String, size: int, color: Color) -> Label:
	return ColorTheme.make_label(text, size, color)


func _make_button(text: String, icon: Texture2D = null, style_type: String = "default") -> Button:
	var btn := Button.new()
	btn.text = text
	if icon:
		btn.icon = icon
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.expand_icon = true
	btn.custom_minimum_size = Vector2(180, 32)
	btn.add_theme_font_size_override("font_size", 12)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var styles: Dictionary
	match style_type:
		"danger":
			styles = ColorTheme.make_button_style_danger()
		"confirm":
			styles = ColorTheme.make_button_style_confirm()
		_:
			styles = ColorTheme.make_button_style_textured()
	btn.add_theme_stylebox_override("normal", styles["normal"])
	if styles.has("hover"):
		btn.add_theme_stylebox_override("hover", styles["hover"])
	if styles.has("pressed"):
		btn.add_theme_stylebox_override("pressed", styles["pressed"])
	# Add hover scale tween
	ColorTheme.setup_button_hover(btn)
	return btn


# ═══════════════════════════════════════════════════════════════
#                   UNIT ORDERS (個別指令)
# ═══════════════════════════════════════════════════════════════

func _on_unit_orders() -> void:
	_current_mode = ActionMode.DOMESTIC_SUB
	_domestic_sub_type = "unit_orders"
	domestic_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	var armies: Array = GameManager.get_player_armies(pid)

	_show_target_panel("Unit Orders (個別指令) - Select Army")

	if armies.is_empty():
		_add_target_label("(No armies)")
		return

	for army in armies:
		var soldiers: int = GameManager.get_army_soldier_count(army["id"])
		var label_text: String = "%s (%d soldiers)" % [army["name"], soldiers]
		_add_target_button(label_text, _on_unit_orders_army.bind(army["id"]))


func _on_unit_orders_army(army_id: int) -> void:
	_orders_army_id = army_id
	var army: Dictionary = GameManager.get_army(army_id)
	var troops: Array = army.get("troops", [])
	var cmds: Dictionary = GameManager.get_army_unit_commands(army_id)

	_show_target_panel("Unit Orders: %s" % army["name"])

	_add_target_label("Set orders for next battle:", Color(0.7, 0.8, 0.9))

	var cmd_names: Array = ["Auto", "Attack", "Guard(DEF+50%)", "Charge(ATK+40%)"]

	for i in range(troops.size()):
		var troop: Dictionary = troops[i]
		var tname: String = troop.get("name", troop.get("troop_id", "???"))
		var current_cmd: int = cmds.get(i, 0)
		var cmd_str: String = cmd_names[current_cmd] if current_cmd < cmd_names.size() else "Auto"

		_add_target_label("  %s: [%s]" % [tname, cmd_str], Color(0.8, 0.85, 0.9))

		# Cycle through commands
		_add_target_button("  → Cycle: %s" % tname, _on_unit_order_cycle.bind(army_id, i))

	_add_target_button("[Reset All to Auto]", _on_unit_orders_reset.bind(army_id))


func _on_unit_order_cycle(army_id: int, troop_index: int) -> void:
	var cmds: Dictionary = GameManager.get_army_unit_commands(army_id)
	var current: int = cmds.get(troop_index, 0)
	var next_cmd: int = (current + 1) % 4  # Cycle: AUTO->ATTACK->GUARD->CHARGE->AUTO
	GameManager.set_unit_command(army_id, troop_index, next_cmd)
	var cmd_names: Array = ["Auto", "Attack", "Guard", "Charge"]
	EventBus.message_log.emit("指令設定: 編隊%d -> %s" % [troop_index, cmd_names[next_cmd]])
	_on_unit_orders_army(army_id)


func _on_unit_orders_reset(army_id: int) -> void:
	GameManager.clear_army_unit_commands(army_id)
	EventBus.message_log.emit("全部指令重置為自動")
	_on_unit_orders_army(army_id)


# ═══════════════════════════════════════════════════════════════
#              SR07 DIPLOMATIC EVENT QUEUE & POPUP
# ═══════════════════════════════════════════════════════════════

func _on_diplomatic_event_triggered(event_data: Dictionary) -> void:
	## Queue diplomatic events and show them one at a time via the existing event popup.
	_diplo_event_queue.append(event_data)
	if not _diplo_event_active:
		_show_next_diplomatic_event()


func _show_next_diplomatic_event() -> void:
	if _diplo_event_queue.is_empty():
		_diplo_event_active = false
		return
	_diplo_event_active = true
	var evt: Dictionary = _diplo_event_queue.pop_front()

	# Build choices array for event_popup format
	var popup_choices: Array = []
	var raw_choices: Array = evt.get("choices", [])
	for c in raw_choices:
		popup_choices.append({"text": c.get("text", "OK")})

	# Use the existing show_event_popup signal which event_popup.gd listens to
	EventBus.show_event_popup.emit(evt.get("title", "外交事件"), evt.get("description", ""), popup_choices)

	# Connect choice handler (disconnect first if already connected from previous event)
	if EventBus.event_choice_selected.is_connected(_on_diplo_popup_choice_any):
		EventBus.event_choice_selected.disconnect(_on_diplo_popup_choice_any)
	# Store current event for the choice handler
	_diplo_current_event = evt
	EventBus.event_choice_selected.connect(_on_diplo_popup_choice_any, CONNECT_ONE_SHOT)


var _diplo_current_event: Dictionary = {}


func _on_diplo_popup_choice_any(choice_index: int) -> void:
	## Handles the player's choice on the current diplomatic event popup.
	if _diplo_current_event.is_empty():
		return
	var evt: Dictionary = _diplo_current_event
	_diplo_current_event = {}

	# No manual disconnect needed — CONNECT_ONE_SHOT handles auto-disconnection

	# Resolve: if dismiss (-1), treat as last choice (reject/ignore)
	var actual_index: int = choice_index
	var choices: Array = evt.get("choices", [])
	if actual_index < 0 or actual_index >= choices.size():
		actual_index = 0  # Default to first (passive) choice on dismiss

	# Dispatch to DiplomacyManager or HeroSystem for resolution
	var evt_type: String = evt.get("type", "")
	if evt_type.begins_with("recruit_"):
		HeroSystem.resolve_recruitment_event(evt, actual_index)
	else:
		DiplomacyManager.resolve_diplomatic_event(evt, actual_index)

	# Show next queued event (deferred to let popup close)
	call_deferred("_show_next_diplomatic_event")


func _on_recruitment_event_triggered(event_data: Dictionary) -> void:
	## Queue recruitment events into the same diplomatic event popup pipeline.
	_diplo_event_queue.append(event_data)
	if not _diplo_event_active:
		_show_next_diplomatic_event()


# ═══════════════════════════════════════════════════════════════
#                MISSION PANEL (Sengoku Rance-style)
# ═══════════════════════════════════════════════════════════════

func _on_mission_pressed() -> void:
	## Open the Sengoku Rance-style mission panel for manual story event execution.
	var main = get_tree().current_scene
	if main and "mission_panel" in main and main.mission_panel:
		if main.mission_panel.is_panel_visible():
			main.mission_panel.hide_panel()
		else:
			main.mission_panel.show_panel()
		return
	# Fallback: walk root children for MissionPanel node
	for child in get_tree().root.get_children():
		if child.has_method("show_panel") and "Mission" in child.name:
			child.show_panel()
			return


func _on_territory_info_pressed() -> void:
	if PanelManager.has_method("toggle_panel"):
		var sel_tile: int = -1
		var board_node = get_tree().get_root().find_child("Board", true, false)
		if board_node and board_node.has_method("get_selected_tile"):
			sel_tile = board_node.get_selected_tile()
		if sel_tile >= 0:
			PanelManager.toggle_panel("province_info", [sel_tile])
		else:
			PanelManager.toggle_panel("province_info")
