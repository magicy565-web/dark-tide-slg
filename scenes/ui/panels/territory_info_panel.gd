## territory_info_panel.gd — Comprehensive Territory Info Panel for Dark Tide SLG
## Sengoku Rance-style detailed territory popup showing all territory information.
## Opens with T key when a territory is selected.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Constants ──
const AP_COST: int = 1
const ROUTE_LABELS: Dictionary = {
	"training": "调教路线",
	"pure_love": "纯爱路线",
	"neutral": "中立路线",
	"friendly": "友好路线",
}

# Colors
const CLR_GOLD := Color(0.9, 0.8, 0.4)
const CLR_GREEN := Color(0.4, 0.8, 0.4)
const CLR_SILVER := Color(0.7, 0.7, 0.8)
const CLR_RED := Color(0.9, 0.3, 0.3)
const CLR_ORCHID := Color(0.85, 0.6, 0.9)
const CLR_CYAN := Color(0.4, 0.8, 0.8)
const CLR_HEADER := Color(0.8, 0.9, 0.6)
const CLR_SECTION := Color(0.7, 0.6, 0.3)
const CLR_DIM := Color(0.5, 0.5, 0.5)
const CLR_TEXT := Color(0.8, 0.8, 0.8)
const CLR_LABEL := Color(0.6, 0.6, 0.6)

# ── State ──
var _visible: bool = false
var _selected_tile: int = -1

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var content_scroll: ScrollContainer
var content_container: VBoxContainer


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_DETAIL_PANELS
	_build_ui()
	_connect_signals()
	hide_panel()


func _connect_signals() -> void:
	EventBus.territory_selected.connect(_on_territory_selected)
	if EventBus.has_signal("story_event_completed"):
		EventBus.story_event_completed.connect(_on_story_event_completed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_T:
			if _visible:
				hide_panel()
			else:
				show_for_tile(_selected_tile)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			hide_panel()
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "TerritoryInfoRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dim background
	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	# Main panel — 70% width, 85% height, centered
	main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.15
	main_panel.anchor_right = 0.85
	main_panel.anchor_top = 0.075
	main_panel.anchor_bottom = 0.925
	main_panel.offset_left = 0
	main_panel.offset_right = 0
	main_panel.offset_top = 0
	main_panel.offset_bottom = 0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1, 0.95)
	style.border_color = Color(0.45, 0.35, 0.2, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	main_panel.add_theme_stylebox_override("panel", style)
	root.add_child(main_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 6)
	main_panel.add_child(outer_vbox)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header_row)

	header_label = Label.new()
	header_label.text = "据点情报"
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", CLR_HEADER)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)

	btn_close = Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	# Separator
	var sep := HSeparator.new()
	outer_vbox.add_child(sep)

	# Content area (scrollable)
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(content_scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 8)
	content_scroll.add_child(content_container)


# ═══════════════════════════════════════════════════════════════
#                         SHOW / HIDE
# ═══════════════════════════════════════════════════════════════

func show_panel() -> void:
	if not GameManager.game_active:
		return
	_visible = true
	root.visible = true
	_refresh()


func show_for_tile(tile_index: int) -> void:
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	_selected_tile = tile_index
	show_panel()


func hide_panel() -> void:
	_visible = false
	root.visible = false


func is_panel_visible() -> bool:
	return _visible


# ═══════════════════════════════════════════════════════════════
#                         REFRESH
# ═══════════════════════════════════════════════════════════════

func _refresh() -> void:
	_clear_content()
	if _selected_tile < 0 or _selected_tile >= GameManager.tiles.size():
		_add_empty_notice("No territory selected")
		return

	if _selected_tile < 0 or _selected_tile >= GameManager.tiles.size():
		return
	var tile: Dictionary = GameManager.tiles[_selected_tile]
	var tile_name: String = tile.get("name", "???")
	var tile_level: int = tile.get("level", 0)
	header_label.text = "%s (Lv%d)" % [tile_name, tile_level]

	# Build each section
	_build_section_tile_info(tile)
	_build_section_garrison(tile)
	_build_section_characters(tile)
	_build_section_story_missions(tile)
	_build_section_side_quests(tile)
	_build_section_adjacency(tile)


func _clear_content() -> void:
	for child in content_container.get_children():
		child.queue_free()


func _add_empty_notice(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", CLR_DIM)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(lbl)


# ═══════════════════════════════════════════════════════════════
#                    SECTION BUILDERS
# ═══════════════════════════════════════════════════════════════

func _build_section_tile_info(tile: Dictionary) -> void:
	content_container.add_child(_make_section_header("据点信息"))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Type and Terrain
	var type_name: String = GameManager.TILE_NAMES.get(tile.get("type", 0), "Unknown")
	var terrain_int: int = tile.get("terrain", 0)
	var tdata: Dictionary = FactionData.TERRAIN_DATA.get(terrain_int, {})
	var terrain_name: String = tdata.get("name", "Unknown")
	vbox.add_child(_make_info_label("类型: %s  |  地形: %s" % [type_name, terrain_name]))

	# Region
	var region_name: String = tile.get("region_name", "")
	if region_name != "":
		vbox.add_child(_make_info_label("区域: %s" % region_name))

	# Production
	var prod: Dictionary = GameManager.get_tile_production(tile)
	var gold_val: int = prod.get("gold", 0)
	var food_val: int = prod.get("food", 0)
	var iron_val: int = prod.get("iron", 0)
	var prod_hbox := HBoxContainer.new()
	prod_hbox.add_theme_constant_override("separation", 4)
	prod_hbox.add_child(_make_info_label("产出:", CLR_LABEL))
	prod_hbox.add_child(_make_info_label("◆%d" % gold_val, CLR_GOLD))
	prod_hbox.add_child(_make_info_label("◇%d" % food_val, CLR_GREEN))
	prod_hbox.add_child(_make_info_label("◇%d" % iron_val, CLR_SILVER))
	vbox.add_child(prod_hbox)

	# Building
	var building_id: String = tile.get("building_id", "")
	if building_id != "":
		var b_name: String = BuildingRegistry.get_building_name(building_id)
		var b_level: int = tile.get("building_level", 0)
		var b_max: int = BuildingRegistry.get_building_max_level(building_id)
		vbox.add_child(_make_info_label("建筑: %s Lv%d/%d" % [b_name, b_level, b_max], CLR_CYAN))

	# Defense: Wall HP + Chokepoint
	var defense_parts: Array = []
	var wall_hp: int = tile.get("wall_hp", 0)
	if wall_hp > 0:
		defense_parts.append("城墙HP %d" % wall_hp)
	var is_chokepoint: bool = tile.get("is_chokepoint", false)
	if is_chokepoint:
		var def_mult: float = tdata.get("def_mult", 1.0)
		defense_parts.append("扼守点 DEF+%d%%" % int((def_mult - 1.0) * 100))
	if not defense_parts.is_empty():
		vbox.add_child(_make_info_label("防御: %s" % " | ".join(defense_parts), CLR_CYAN))

	# Terrain combat modifiers
	var atk_mult: float = tdata.get("atk_mult", 1.0)
	var def_mult_t: float = tdata.get("def_mult", 1.0)
	var move_cost: int = tdata.get("move_cost", 1)
	var attrition: float = tdata.get("attrition_pct", 0.0)
	var terr_line: String = "地形效果: ATK×%.1f DEF×%.1f 移动%d" % [atk_mult, def_mult_t, move_cost]
	if attrition > 0:
		terr_line += " 损耗%.0f%%" % (attrition * 100)
	vbox.add_child(_make_info_label(terr_line, CLR_DIM, 13))

	# Public order bar
	var public_order: int = tile.get("public_order", 50)
	vbox.add_child(_make_order_bar(public_order))

	# Supply status
	var pid: int = GameManager.get_human_player_id()
	var is_supplied: bool = SupplySystem.is_tile_supplied(pid, _selected_tile)
	var is_capital: bool = SupplySystem.is_capital_tile(pid, _selected_tile)
	var supply_text: String = ""
	if is_capital:
		supply_text = "★ 首都"
	elif is_supplied:
		supply_text = "✓ 已连接"
	else:
		supply_text = "✗ 未连接"
	var supply_color: Color = CLR_GREEN if (is_supplied or is_capital) else CLR_RED
	vbox.add_child(_make_hbox_pair("补给:", supply_text, CLR_LABEL, supply_color))

	# Siege status
	if SiegeSystem.is_tile_under_siege(_selected_tile):
		var siege_data: Dictionary = SiegeSystem.get_siege_at_tile(_selected_tile)
		vbox.add_child(_make_info_label("⚠ 围城中!", CLR_RED, 15))

	# Guard timer
	if GameManager._guard_timers.has(_selected_tile):
		var guard_info: Dictionary = GameManager._guard_timers[_selected_tile]
		var turns_rem: int = guard_info.get("turns_remaining", 0)
		vbox.add_child(_make_info_label("守备中 (剩余%d回合)" % turns_rem, CLR_CYAN))

# -- Section: Garrison --
func _build_section_garrison(tile: Dictionary) -> void:
	content_container.add_child(_make_section_header("驻军"))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var has_content: bool = false

	# Commander hero
	var hero_id: String = HeroSystem.get_stationed_hero(_selected_tile)
	if hero_id != "":
		has_content = true
		var hero_info: Dictionary = HeroSystem.get_hero_info(hero_id)
		var hero_name: String = hero_info.get("name", "???")
		var hero_level: int = hero_info.get("level", 1)
		var hero_faction: String = hero_info.get("faction", "")

		# Commander card
		var cmd_panel := PanelContainer.new()
		var cmd_style := StyleBoxFlat.new()
		cmd_style.bg_color = Color(0.1, 0.08, 0.14, 0.8)
		cmd_style.border_color = Color(0.5, 0.35, 0.6, 0.6)
		cmd_style.set_border_width_all(1)
		cmd_style.set_corner_radius_all(4)
		cmd_style.set_content_margin_all(8)
		cmd_panel.add_theme_stylebox_override("panel", cmd_style)
		vbox.add_child(cmd_panel)

		var cmd_vbox := VBoxContainer.new()
		cmd_vbox.add_theme_constant_override("separation", 2)
		cmd_panel.add_child(cmd_vbox)

		cmd_vbox.add_child(_make_info_label("指挥官: %s (Lv%d %s)" % [hero_name, hero_level, hero_faction], CLR_ORCHID, 15))

		# Commander bonuses
		var bonuses: Dictionary = HeroSystem.get_garrison_commander_bonus(_selected_tile)
		var bonus_parts: Array = []
		var def_bonus: int = bonuses.get("def_bonus", 0)
		var prod_bonus: int = bonuses.get("prod_bonus", 0)
		var order_bonus: int = bonuses.get("order_bonus", 0)
		var garrison_add: int = bonuses.get("garrison_add", 0)
		if def_bonus != 0:
			bonus_parts.append("DEF+%d%%" % def_bonus)
		if prod_bonus != 0:
			bonus_parts.append("产出+%d%%" % prod_bonus)
		if order_bonus != 0:
			bonus_parts.append("秩序+%d" % order_bonus)
		if garrison_add != 0:
			bonus_parts.append("兵力+%d" % garrison_add)
		if not bonus_parts.is_empty():
			cmd_vbox.add_child(_make_info_label("  " + " ".join(bonus_parts), CLR_GREEN, 13))

	# Army at tile
	var army: Dictionary = GameManager.get_army_at_tile(_selected_tile)
	if not army.is_empty():
		has_content = true
		var army_name: String = army.get("name", "???")
		var army_id: int = army.get("id", -1)
		var troops: Array = army.get("troops", [])
		var soldier_count: int = GameManager.get_army_soldier_count(army_id)
		var combat_power: int = GameManager.get_army_combat_power(army_id)

		vbox.add_child(_make_info_label("军队: %s" % army_name, CLR_TEXT, 15))
		vbox.add_child(_make_info_label("兵力: %d部队 | 兵员: %d | 战力: %d" % [troops.size(), soldier_count, combat_power]))

		# Supply status for army
		var supply_status: Dictionary = SupplySystem.get_army_supply_status(army)
		var s_label: String = supply_status.get("status_label", "Unknown")
		var s_dist: int = supply_status.get("distance", 0)
		var supply_str: String = "%s (距首都%d格)" % [s_label, s_dist]
		var s_status: String = supply_status.get("status", "")
		var s_color: Color = CLR_GREEN if s_status == "supplied" else CLR_RED
		vbox.add_child(_make_hbox_pair("补给:", supply_str, CLR_LABEL, s_color))

	# Garrison count
	var garrison: int = tile.get("garrison", 0)
	if garrison > 0:
		has_content = true
		vbox.add_child(_make_info_label("驻军兵力: %d" % garrison, CLR_CYAN))

	if not has_content:
		vbox.add_child(_make_info_label("无驻军", CLR_DIM))

# -- Section: Characters & NPC --
func _build_section_characters(tile: Dictionary) -> void:
	content_container.add_child(_make_section_header("NPC・角色"))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var has_content: bool = false

	# Heroes with story progress at this tile (from StoryEventSystem missions)
	var missions: Array = StoryEventSystem.get_available_missions()
	var seen_heroes: Dictionary = {}
	for m in missions:
		var hero_id: String = m.get("hero_id", "")
		if hero_id == "" or seen_heroes.has(hero_id):
			continue
		seen_heroes[hero_id] = true
		has_content = true
		var hero_name: String = m.get("hero_name", "???")
		var route: String = m.get("route", "")
		var route_label: String = ROUTE_LABELS.get(route, route)
		var stage: int = m.get("stage", 0)
		var status: String = m.get("status", "locked")
		var icon: String = "★" if status == "available" else "○"
		vbox.add_child(_make_info_label("%s %s — %s Stage %d" % [icon, hero_name, route_label, stage], CLR_ORCHID))

	# Neutral faction
	var nf_id: String = str(tile.get("neutral_faction_id", ""))
	if nf_id != "" and nf_id != "0":
		has_content = true
		var nf_name: String = FactionData.NEUTRAL_FACTION_NAMES.get(nf_id, "Unknown")
		var is_vassal: bool = NeutralFactionAI.is_vassal(int(nf_id)) if nf_id.is_valid_int() else false
		var vassal_tag: String = " (附庸)" if is_vassal else ""
		vbox.add_child(_make_info_label("中立势力: %s%s" % [nf_name, vassal_tag], CLR_GOLD))

	# Light faction
	var lf_id = tile.get("light_faction", "")
	if lf_id != "" and lf_id != "0" and lf_id != 0:
		has_content = true
		var lf_name: String = FactionData.LIGHT_FACTION_NAMES.get(lf_id, "Unknown")
		vbox.add_child(_make_info_label("光之势力: %s" % lf_name, CLR_GOLD))

	# Named outpost
	var outpost_id = tile.get("named_outpost_id", "")
	if outpost_id != "" and outpost_id != "0" and outpost_id != 0:
		has_content = true
		vbox.add_child(_make_info_label("据点: %s" % str(outpost_id), CLR_CYAN))

	if not has_content:
		vbox.add_child(_make_info_label("无相关角色", CLR_DIM))

# -- Section: Story Missions --
func _build_section_story_missions(_tile: Dictionary) -> void:
	content_container.add_child(_make_section_header("可用任務"))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var missions: Array = StoryEventSystem.get_available_missions()
	if missions.is_empty():
		vbox.add_child(_make_info_label("无可用任务", CLR_DIM))
		return

	var player: Dictionary = GameManager.get_current_player()
	var current_ap: int = player.get("ap", 0)

	for m in missions:
		var hero_id: String = m.get("hero_id", "")
		var hero_name: String = m.get("hero_name", "???")
		var event_name: String = m.get("event_name", "???")
		var route: String = m.get("route", "")
		var route_label: String = ROUTE_LABELS.get(route, route)
		var status: String = m.get("status", "locked")

		# Mission card
		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		if status == "available":
			cs.bg_color = Color(0.08, 0.12, 0.08, 0.9)
			cs.border_color = Color(0.4, 0.8, 0.4, 0.7)
		else:
			cs.bg_color = Color(0.06, 0.06, 0.06, 0.8)
			cs.border_color = Color(0.3, 0.3, 0.3, 0.4)
		cs.set_border_width_all(1)
		cs.set_corner_radius_all(4)
		cs.set_content_margin_all(8)
		card.add_theme_stylebox_override("panel", cs)
		vbox.add_child(card)

		var card_hbox := HBoxContainer.new()
		card_hbox.add_theme_constant_override("separation", 8)
		card.add_child(card_hbox)

		# Icon + text
		var icon: String = "★" if status == "available" else "○"
		var text_color: Color = CLR_GREEN if status == "available" else CLR_DIM
		var info_lbl := Label.new()
		info_lbl.text = "%s %s: %s" % [icon, hero_name, event_name]
		info_lbl.add_theme_font_size_override("font_size", 14)
		info_lbl.add_theme_color_override("font_color", text_color)
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_hbox.add_child(info_lbl)

		# Execute button or locked label
		if status == "available":
			var btn := Button.new()
			btn.text = "▶ 1AP"
			btn.custom_minimum_size = Vector2(80, 28)
			btn.add_theme_font_size_override("font_size", 13)
			if current_ap < AP_COST:
				btn.disabled = true
				btn.tooltip_text = "AP不足 (需要 %d AP)" % AP_COST
			btn.pressed.connect(func(): _on_execute_mission(hero_id))
			card_hbox.add_child(btn)
		else:
			var lock_lbl := Label.new()
			lock_lbl.text = "[锁定]"
			lock_lbl.add_theme_font_size_override("font_size", 13)
			lock_lbl.add_theme_color_override("font_color", CLR_DIM)
			card_hbox.add_child(lock_lbl)

# -- Section: Side Quests --
func _build_section_side_quests(_tile: Dictionary) -> void:
	# Only show if QuestJournal is available
	if not Engine.has_singleton("QuestJournal"):
		# Try access as global — safe check via has_method pattern
		var has_qj: bool = false
		for child in get_tree().root.get_children():
			if child.has_method("get_all_quests"):
				has_qj = true
				break
		if not has_qj:
			# Check if QuestJournal autoload exists as a global name
			if not is_instance_valid(get_node_or_null("/root/QuestJournal")):
				return

	content_container.add_child(_make_section_header("支线任務"))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var pid: int = GameManager.get_human_player_id()
	var all_quests: Array = QuestJournal.get_all_quests(pid)
	var side_quests: Array = []
	for q in all_quests:
		if q.get("category", "") == "side":
			var q_status = q.get("status", 0)
			# Show active and available only
			var status_str: String = ""
			if q_status is String:
				status_str = q_status
			else:
				match int(q_status):
					1: status_str = "available"
					2: status_str = "active"
					_: continue
			if status_str in ["active", "available"]:
				q["_status_str"] = status_str
				side_quests.append(q)

	if side_quests.is_empty():
		vbox.add_child(_make_info_label("无活跃支线任务", CLR_DIM))
		return

	for q in side_quests:
		var q_name: String = q.get("name", "???")
		var status_str: String = q.get("_status_str", "")
		var tag: String = "[进行中]" if status_str == "active" else "[可接取]"
		var tag_color: Color = CLR_GOLD if status_str == "active" else CLR_GREEN
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_make_info_label(tag, tag_color, 13))
		row.add_child(_make_info_label(q_name, CLR_TEXT, 13))
		vbox.add_child(row)

# -- Section: Adjacency / Strategic Situation --
func _build_section_adjacency(tile: Dictionary) -> void:
	content_container.add_child(_make_section_header("周边态势"))
	var panel := _make_section_panel()
	content_container.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var pid: int = GameManager.get_human_player_id()
	var adj_indices: Array = GameManager.adjacency.get(_selected_tile, [])

	if adj_indices.is_empty():
		vbox.add_child(_make_info_label("无相邻据点", CLR_DIM))
		return

	# Adjacent tiles list
	var adj_labels: Array = []
	var player_power: int = 0
	var enemy_power: int = 0

	# Own tile army power
	var own_army: Dictionary = GameManager.get_army_at_tile(_selected_tile)
	if not own_army.is_empty():
		player_power += GameManager.get_army_combat_power(own_army.get("id", -1))

	for adj_idx in adj_indices:
		if adj_idx < 0 or adj_idx >= GameManager.tiles.size():
			continue
		if adj_idx < 0 or adj_idx >= GameManager.tiles.size():
			return
		var adj_tile: Dictionary = GameManager.tiles[adj_idx]
		var adj_name: String = adj_tile.get("name", "???")
		var adj_owner: int = adj_tile.get("owner_id", -1)

		var owner_tag: String = ""
		var tag_color: Color = CLR_DIM
		if adj_owner == pid:
			owner_tag = "己"
			tag_color = CLR_GREEN
		elif adj_owner > 0:
			owner_tag = "敌"
			tag_color = CLR_RED
		else:
			owner_tag = "空"
			tag_color = CLR_DIM

		adj_labels.append({"name": adj_name, "tag": owner_tag, "color": tag_color})

		# Tally power
		var adj_army: Dictionary = GameManager.get_army_at_tile(adj_idx)
		if not adj_army.is_empty():
			var adj_power: int = GameManager.get_army_combat_power(adj_army.get("id", -1))
			if adj_owner == pid:
				player_power += adj_power
			elif adj_owner > 0:
				enemy_power += adj_power

	# Display adjacent tiles in a flow layout
	var adj_line: String = "相邻: "
	var parts: Array = []
	for a in adj_labels:
		parts.append("%s(%s)" % [a["name"], a["tag"]])
	adj_line += ", ".join(parts)
	var adj_lbl := _make_info_label(adj_line, CLR_TEXT, 13)
	adj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(adj_lbl)

	# Power comparison
	var power_hbox := HBoxContainer.new()
	power_hbox.add_theme_constant_override("separation", 8)
	power_hbox.add_child(_make_info_label("我方总战力:", CLR_LABEL, 13))
	power_hbox.add_child(_make_info_label("%d" % player_power, CLR_GREEN, 13))
	power_hbox.add_child(_make_info_label("|", CLR_DIM, 13))
	power_hbox.add_child(_make_info_label("敌方:", CLR_LABEL, 13))
	power_hbox.add_child(_make_info_label("%d" % enemy_power, CLR_RED, 13))
	vbox.add_child(power_hbox)

	# Situation assessment
	if enemy_power > 0:
		var ratio: float = float(player_power) / float(enemy_power) if enemy_power > 0 else 99.0
		var sit_text: String = ""
		var sit_color: Color = CLR_TEXT
		if ratio >= 2.0:
			sit_text = "态势: 压倒优势 %.1fx" % ratio
			sit_color = CLR_GREEN
		elif ratio >= 1.2:
			sit_text = "态势: 优势 %.1fx" % ratio
			sit_color = CLR_GREEN
		elif ratio >= 0.8:
			sit_text = "态势: 均势 %.1fx" % ratio
			sit_color = CLR_GOLD
		else:
			sit_text = "态势: 劣势 %.1fx" % ratio
			sit_color = CLR_RED
		vbox.add_child(_make_info_label(sit_text, sit_color, 14))
	elif player_power > 0:
		vbox.add_child(_make_info_label("态势: 无威胁", CLR_GREEN, 14))
	else:
		vbox.add_child(_make_info_label("态势: 无军事存在", CLR_DIM, 14))


# ═══════════════════════════════════════════════════════════════
#                       UI HELPERS
# ═══════════════════════════════════════════════════════════════

func _make_section_header(title: String) -> Label:
	var lbl := Label.new()
	lbl.text = "═══ %s ═══" % title
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", CLR_SECTION)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _make_section_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.08, 0.8)
	s.border_color = Color(0.3, 0.25, 0.15, 0.6)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", s)
	return panel


func _make_info_label(text: String, color: Color = CLR_TEXT, size: int = 14) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl


func _make_hbox_pair(key: String, value: String, key_color: Color = CLR_LABEL, val_color: Color = CLR_TEXT) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 14)
	k.add_theme_color_override("font_color", key_color)
	hbox.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", val_color)
	hbox.add_child(v)
	return hbox


func _make_order_bar(order_value: int) -> HBoxContainer:
	## Create a visual public order bar with percentage text.
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)

	var lbl := Label.new()
	lbl.text = "秩序:"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", CLR_LABEL)
	hbox.add_child(lbl)

	# Bar background
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(120, 14)
	bar_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	hbox.add_child(bar_bg)

	# Bar fill
	var bar_fill := ColorRect.new()
	var clamped: int = clampi(order_value, 0, 100)
	bar_fill.custom_minimum_size = Vector2(120.0 * clamped / 100.0, 14)
	if clamped >= 70:
		bar_fill.color = CLR_GREEN
	elif clamped >= 40:
		bar_fill.color = CLR_GOLD
	else:
		bar_fill.color = CLR_RED
	bar_bg.add_child(bar_fill)

	var pct := Label.new()
	pct.text = "%d%%" % clamped
	pct.add_theme_font_size_override("font_size", 13)
	pct.add_theme_color_override("font_color", CLR_TEXT)
	hbox.add_child(pct)

	return hbox


# ═══════════════════════════════════════════════════════════════
#                       MISSION ACTIONS
# ═══════════════════════════════════════════════════════════════

func _on_execute_mission(hero_id: String) -> void:
	var player: Dictionary = GameManager.get_current_player()
	var pid: int = GameManager.get_human_player_id()
	var current_ap: int = player.get("ap", 0)

	if current_ap < AP_COST:
		EventBus.message_log.emit("[color=red]行动点不足! 任務需要%dAP。[/color]" % AP_COST)
		return

	# Deduct AP
	player["ap"] -= AP_COST
	EventBus.ap_changed.emit(pid, player["ap"])

	# Trigger story event
	StoryEventSystem.manually_trigger_event(hero_id)

	# Hide panel while dialog plays
	hide_panel()


# ═══════════════════════════════════════════════════════════════
#                         CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_territory_selected(tile_index: int) -> void:
	_selected_tile = tile_index
	if _visible:
		_refresh()


func _on_story_event_completed(_hero_id: String, _event_id: String) -> void:
	if _visible:
		_refresh()


func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
