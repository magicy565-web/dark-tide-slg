## deployment_ui.gd — Pre-battle deployment grid UI (战前部署界面)
## 6×4 grid display with drag-and-drop unit placement, formation preview,
## counter analysis panel, directive selector, and "Battle Start" button.
extends CanvasLayer

const FormationSystem = preload("res://systems/combat/formation_system.gd")
const CombatResolverScript = preload("res://systems/combat/combat_resolver.gd")

signal battle_start_pressed()
signal deployment_cancelled()

# ── Theme colors (matches existing dark/gold pixel-art theme) ──
const BG_COLOR := Color(0.08, 0.06, 0.12, 0.95)
const GOLD := Color(0.85, 0.7, 0.3)
const GOLD_DIM := Color(0.55, 0.45, 0.2)
const GOLD_BRIGHT := Color(1.0, 0.85, 0.4)
const TEXT_COLOR := Color(0.9, 0.88, 0.82)
const DISABLED_COLOR := Color(0.35, 0.32, 0.28)
const CARD_BG := Color(0.1, 0.08, 0.15)
const CARD_BORDER := Color(0.4, 0.32, 0.18)
const GREEN := Color(0.3, 0.8, 0.35)
const RED := Color(0.85, 0.25, 0.25)
const YELLOW := Color(0.9, 0.75, 0.15)
const BLUE := Color(0.3, 0.5, 0.85)
const CELL_EMPTY := Color(0.12, 0.10, 0.18, 0.8)
const CELL_VALID := Color(0.15, 0.35, 0.15, 0.8)
const CELL_INVALID := Color(0.35, 0.12, 0.12, 0.8)
const CELL_OCCUPIED := Color(0.35, 0.30, 0.10, 0.8)
const CELL_HOVER := Color(0.25, 0.22, 0.35, 0.9)
const CELL_SIZE := Vector2(100.0, 80.0)

# ── Grid dimensions ──
const GRID_W: int = 6
const GRID_H: int = 4

# ── State ──
var _cell_buttons: Array = []  # 2D array [y][x] of Button nodes
var _unit_pool_buttons: Array = []  # Array of {button, unit} for unplaced units
var _dragging_unit: Dictionary = {}
var _drag_source: Vector2i = Vector2i(-1, -1)
var _hovered_cell: Vector2i = Vector2i(-1, -1)
var _tooltip_unit: Dictionary = {}

# ── UI refs ──
var root: PanelContainer
var main_hbox: HBoxContainer
var left_panel: VBoxContainer  # Unit pool
var center_panel: VBoxContainer  # Grid + buttons
var right_panel: VBoxContainer  # Formation + counter
var grid_container: GridContainer
var unit_pool_container: VBoxContainer
var formation_list: VBoxContainer
var counter_list: VBoxContainer
var directive_option: OptionButton
var start_btn: Button
var cancel_btn: Button
var timer_bar: ProgressBar
var timer_label: Label
var tooltip_panel: PanelContainer
var tooltip_label: RichTextLabel
var title_label: Label

func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()

func _process(delta: float) -> void:
	if not visible:
		return
	if DeploymentPhase.is_active() and DeploymentPhase.is_timed():
		var remaining: float = DeploymentPhase.tick_timer(delta)
		_update_timer(remaining)

# ═════════════════════════════════════════════════
#                  PUBLIC API
# ═════════════════════════════════════════════════

func show_deployment() -> void:
	visible = true
	_refresh_grid()
	_refresh_unit_pool()
	_refresh_formation_panel()
	_refresh_counter_panel()
	_refresh_directive()
	if DeploymentPhase.is_timed():
		timer_bar.visible = true
		timer_label.visible = true
	else:
		timer_bar.visible = false
		timer_label.visible = false

func hide_deployment() -> void:
	visible = false
	_dragging_unit = {}
	_drag_source = Vector2i(-1, -1)

# ═════════════════════════════════════════════════
#                   BUILD UI
# ═════════════════════════════════════════════════

func _build_ui() -> void:
	root = PanelContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR, GOLD_DIM, 2))
	add_child(root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	root.add_child(margin)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(outer_vbox)

	# ── Title ──
	title_label = Label.new()
	title_label.text = "战前部署"
	title_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(title_label)

	# ── Timer ──
	var timer_hbox := HBoxContainer.new()
	timer_hbox.add_theme_constant_override("separation", 8)
	outer_vbox.add_child(timer_hbox)

	timer_label = Label.new()
	timer_label.text = "剩余时间: 60s"
	timer_label.add_theme_color_override("font_color", TEXT_COLOR)
	timer_label.visible = false
	timer_hbox.add_child(timer_label)

	timer_bar = ProgressBar.new()
	timer_bar.min_value = 0.0
	timer_bar.max_value = 60.0
	timer_bar.value = 60.0
	timer_bar.custom_minimum_size = Vector2(200, 16)
	timer_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_bar.visible = false
	timer_hbox.add_child(timer_bar)

	# ── Main content: 3-column layout ──
	main_hbox = HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 12)
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(main_hbox)

	_build_left_panel()
	_build_center_panel()
	_build_right_panel()

	# ── Bottom buttons ──
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	outer_vbox.add_child(btn_hbox)

	cancel_btn = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.custom_minimum_size = Vector2(120, 36)
	cancel_btn.pressed.connect(_on_cancel)
	btn_hbox.add_child(cancel_btn)

	var auto_btn := Button.new()
	auto_btn.text = "自动部署"
	auto_btn.custom_minimum_size = Vector2(120, 36)
	auto_btn.pressed.connect(_on_auto_deploy)
	btn_hbox.add_child(auto_btn)

	start_btn = Button.new()
	start_btn.text = "开战!"
	start_btn.custom_minimum_size = Vector2(160, 40)
	start_btn.add_theme_color_override("font_color", GOLD_BRIGHT)
	start_btn.pressed.connect(_on_start)
	btn_hbox.add_child(start_btn)

	# ── Tooltip ──
	tooltip_panel = PanelContainer.new()
	tooltip_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.04, 0.08, 0.95), GOLD, 1))
	tooltip_panel.visible = false
	tooltip_panel.z_index = 100
	tooltip_panel.custom_minimum_size = Vector2(220, 60)
	add_child(tooltip_panel)

	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = true
	tooltip_label.custom_minimum_size = Vector2(200, 50)
	tooltip_label.add_theme_color_override("default_color", TEXT_COLOR)
	tooltip_panel.add_child(tooltip_label)

func _build_left_panel() -> void:
	left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(180, 0)
	left_panel.add_theme_constant_override("separation", 4)
	main_hbox.add_child(left_panel)

	var lbl := Label.new()
	lbl.text = "待部署部队"
	lbl.add_theme_color_override("font_color", GOLD)
	lbl.add_theme_font_size_override("font_size", 16)
	left_panel.add_child(lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(scroll)

	unit_pool_container = VBoxContainer.new()
	unit_pool_container.add_theme_constant_override("separation", 4)
	scroll.add_child(unit_pool_container)

func _build_center_panel() -> void:
	center_panel = VBoxContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.add_theme_constant_override("separation", 8)
	main_hbox.add_child(center_panel)

	# Row labels
	var row_labels_hbox := HBoxContainer.new()
	row_labels_hbox.add_theme_constant_override("separation", 0)
	center_panel.add_child(row_labels_hbox)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(50, 20)
	row_labels_hbox.add_child(spacer)

	for col in range(GRID_W):
		var col_lbl := Label.new()
		col_lbl.text = str(col + 1)
		col_lbl.custom_minimum_size = Vector2(CELL_SIZE.x, 20)
		col_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col_lbl.add_theme_color_override("font_color", GOLD_DIM)
		col_lbl.add_theme_font_size_override("font_size", 12)
		row_labels_hbox.add_child(col_lbl)

	# Grid area with row labels
	var grid_hbox := HBoxContainer.new()
	grid_hbox.add_theme_constant_override("separation", 0)
	center_panel.add_child(grid_hbox)

	# Row labels column
	var row_label_vbox := VBoxContainer.new()
	row_label_vbox.add_theme_constant_override("separation", 0)
	grid_hbox.add_child(row_label_vbox)

	var row_names: Array = ["前卫", "前列", "后列", "后卫"]
	for ry in range(GRID_H):
		var rlbl := Label.new()
		rlbl.text = row_names[ry]
		rlbl.custom_minimum_size = Vector2(50, CELL_SIZE.y)
		rlbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		rlbl.add_theme_color_override("font_color", GOLD_DIM)
		rlbl.add_theme_font_size_override("font_size", 12)
		row_label_vbox.add_child(rlbl)

	# Grid
	grid_container = GridContainer.new()
	grid_container.columns = GRID_W
	grid_container.add_theme_constant_override("h_separation", 2)
	grid_container.add_theme_constant_override("v_separation", 2)
	grid_hbox.add_child(grid_container)

	_cell_buttons.clear()
	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			var btn := Button.new()
			btn.custom_minimum_size = CELL_SIZE
			btn.clip_text = true
			btn.add_theme_stylebox_override("normal", _make_panel_style(CELL_EMPTY, GOLD_DIM, 1))
			btn.add_theme_stylebox_override("hover", _make_panel_style(CELL_HOVER, GOLD, 1))
			btn.add_theme_color_override("font_color", TEXT_COLOR)
			btn.add_theme_font_size_override("font_size", 11)
			btn.pressed.connect(_on_cell_pressed.bind(x, y))
			btn.mouse_entered.connect(_on_cell_hover.bind(x, y))
			btn.mouse_exited.connect(_on_cell_unhover.bind(x, y))
			grid_container.add_child(btn)
			row.append(btn)
		_cell_buttons.append(row)

	# Directive selector
	var dir_hbox := HBoxContainer.new()
	dir_hbox.add_theme_constant_override("separation", 8)
	center_panel.add_child(dir_hbox)

	var dir_label := Label.new()
	dir_label.text = "战术指令:"
	dir_label.add_theme_color_override("font_color", GOLD)
	dir_hbox.add_child(dir_label)

	directive_option = OptionButton.new()
	directive_option.add_item("无", 0)
	directive_option.add_item("猛攻 (ATK+25%, DEF-15%)", 1)
	directive_option.add_item("坚守 (DEF+25%, ATK-15%)", 2)
	directive_option.add_item("游击 (后排ATK+30%)", 3)
	directive_option.add_item("集火 (ATK+10%, 集中攻击)", 4)
	directive_option.add_item("奇袭 (首回合ATK+40%)", 5)
	directive_option.add_item("一骑打 (英雄单挑)", 6)
	directive_option.add_item("撤退 (损失20%保全主力)", 7)
	directive_option.item_selected.connect(_on_directive_changed)
	dir_hbox.add_child(directive_option)

func _build_right_panel() -> void:
	right_panel = VBoxContainer.new()
	right_panel.custom_minimum_size = Vector2(240, 0)
	right_panel.add_theme_constant_override("separation", 8)
	main_hbox.add_child(right_panel)

	# Formation preview
	var form_label := Label.new()
	form_label.text = "阵型预览"
	form_label.add_theme_color_override("font_color", GOLD)
	form_label.add_theme_font_size_override("font_size", 16)
	right_panel.add_child(form_label)

	var form_scroll := ScrollContainer.new()
	form_scroll.custom_minimum_size = Vector2(0, 150)
	right_panel.add_child(form_scroll)

	formation_list = VBoxContainer.new()
	formation_list.add_theme_constant_override("separation", 4)
	form_scroll.add_child(formation_list)

	# Separator
	var sep := HSeparator.new()
	right_panel.add_child(sep)

	# Counter analysis
	var counter_label := Label.new()
	counter_label.text = "克制分析"
	counter_label.add_theme_color_override("font_color", GOLD)
	counter_label.add_theme_font_size_override("font_size", 16)
	right_panel.add_child(counter_label)

	var counter_scroll := ScrollContainer.new()
	counter_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(counter_scroll)

	counter_list = VBoxContainer.new()
	counter_list.add_theme_constant_override("separation", 4)
	counter_scroll.add_child(counter_list)

	# Enemy composition summary
	var enemy_label := Label.new()
	enemy_label.text = "敌方情报"
	enemy_label.add_theme_color_override("font_color", RED)
	enemy_label.add_theme_font_size_override("font_size", 16)
	right_panel.add_child(enemy_label)

	var enemy_scroll := ScrollContainer.new()
	enemy_scroll.custom_minimum_size = Vector2(0, 100)
	right_panel.add_child(enemy_scroll)

	var enemy_list_container := VBoxContainer.new()
	enemy_list_container.name = "EnemyList"
	enemy_list_container.add_theme_constant_override("separation", 2)
	enemy_scroll.add_child(enemy_list_container)

# ═════════════════════════════════════════════════
#                 REFRESH / UPDATE
# ═════════════════════════════════════════════════

func _refresh_grid() -> void:
	var grid = DeploymentPhase.get_grid()
	if grid == null:
		return

	for y in range(GRID_H):
		for x in range(GRID_W):
			var btn: Button = _cell_buttons[y][x]
			var cell = grid.get_cell(x, y)
			if cell == null:
				btn.text = ""
				btn.add_theme_stylebox_override("normal", _make_panel_style(CELL_EMPTY, GOLD_DIM, 1))
				continue

			if cell.has_unit():
				var unit: Dictionary = cell.unit
				var troop_id: String = unit.get("troop_id", unit.get("unit_type", unit.get("type", "?")))
				var soldiers: int = unit.get("soldiers", unit.get("count", 0))
				btn.text = "%s\n%d兵" % [troop_id.substr(0, 8), soldiers]
				btn.add_theme_stylebox_override("normal", _make_panel_style(CELL_OCCUPIED, GOLD, 1))
			elif cell.obstacle != "":
				btn.text = cell.obstacle
				btn.add_theme_stylebox_override("normal", _make_panel_style(CELL_INVALID, GOLD_DIM, 1))
			else:
				btn.text = ""
				# Color code: front rows green (melee), back rows blue (ranged)
				var color: Color = CELL_VALID if y <= 1 else Color(0.12, 0.18, 0.30, 0.8)
				btn.add_theme_stylebox_override("normal", _make_panel_style(color, GOLD_DIM, 1))

func _refresh_unit_pool() -> void:
	# Clear existing
	for child in unit_pool_container.get_children():
		child.queue_free()
	_unit_pool_buttons.clear()

	# Get unplaced units
	var placed_ids: Dictionary = {}
	var grid = DeploymentPhase.get_grid()
	if grid != null:
		var all_units: Array = grid.get_all_units()
		for entry in all_units:
			placed_ids[entry["unit"].get("id", "")] = true

	var player_units: Array = DeploymentPhase.get_player_units()
	for unit in player_units:
		var uid: String = unit.get("id", "")
		if placed_ids.has(uid):
			continue
		var btn := Button.new()
		var troop_id: String = unit.get("troop_id", unit.get("type", unit.get("unit_type", "?")))
		var soldiers: int = unit.get("soldiers", unit.get("count", 0))
		btn.text = "%s (%d)" % [troop_id, soldiers]
		btn.custom_minimum_size = Vector2(170, 30)
		btn.clip_text = true
		btn.add_theme_color_override("font_color", TEXT_COLOR)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_pool_unit_pressed.bind(unit))
		btn.mouse_entered.connect(_on_unit_hover.bind(unit))
		btn.mouse_exited.connect(_on_unit_unhover)
		unit_pool_container.add_child(btn)
		_unit_pool_buttons.append({"button": btn, "unit": unit})

func _refresh_formation_panel() -> void:
	for child in formation_list.get_children():
		child.queue_free()

	var formations: Array = DeploymentPhase.get_deployment_result().get("formations", [])
	if formations.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "未检测到阵型"
		none_lbl.add_theme_color_override("font_color", DISABLED_COLOR)
		formation_list.add_child(none_lbl)
		return

	for fid in formations:
		var fname: String = FormationSystem.FORMATION_NAMES_CN.get(fid, "未知阵型")
		var lbl := Label.new()
		lbl.text = "★ " + fname
		lbl.add_theme_color_override("font_color", GOLD_BRIGHT)
		lbl.add_theme_font_size_override("font_size", 14)
		formation_list.add_child(lbl)

func _refresh_counter_panel() -> void:
	for child in counter_list.get_children():
		child.queue_free()

	var analysis: Array = DeploymentPhase.get_counter_analysis()
	if analysis.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "无克制关系"
		none_lbl.add_theme_color_override("font_color", DISABLED_COLOR)
		counter_list.add_child(none_lbl)
		return

	# Deduplicate by player_unit + enemy_unit pair
	var seen: Dictionary = {}
	for entry in analysis:
		var key: String = entry["player_unit"] + ">" + entry["enemy_unit"]
		if seen.has(key):
			continue
		seen[key] = true
		var lbl := Label.new()
		var color: Color = GREEN if entry["advantage"] == "hard_counter" else RED
		var arrow: String = "★" if entry["advantage"] == "hard_counter" else "✗"
		lbl.text = "%s %s → %s" % [arrow, entry["player_unit"], entry["enemy_unit"]]
		lbl.add_theme_color_override("font_color", color)
		lbl.add_theme_font_size_override("font_size", 12)
		counter_list.add_child(lbl)

	# Also refresh enemy list
	_refresh_enemy_list()

func _refresh_enemy_list() -> void:
	var enemy_container: Node = right_panel.find_child("EnemyList", true, false)
	if enemy_container == null:
		return
	for child in enemy_container.get_children():
		child.queue_free()

	var enemies: Array = DeploymentPhase.get_enemy_preview()
	for eu in enemies:
		var troop_id: String = eu.get("unit_type", eu.get("troop_id", eu.get("type", "?")))
		var soldiers: int = eu.get("soldiers", eu.get("count", 0))
		var lbl := Label.new()
		lbl.text = "%s (%d兵)" % [troop_id, soldiers]
		lbl.add_theme_color_override("font_color", Color(0.75, 0.55, 0.55))
		lbl.add_theme_font_size_override("font_size", 12)
		enemy_container.add_child(lbl)

func _refresh_directive() -> void:
	var current: int = DeploymentPhase.get_directive()
	directive_option.selected = current

func _update_timer(remaining: float) -> void:
	timer_label.text = "剩余时间: %ds" % int(remaining)
	timer_bar.value = remaining

# ═════════════════════════════════════════════════
#                  INTERACTIONS
# ═════════════════════════════════════════════════

func _on_cell_pressed(x: int, y: int) -> void:
	var grid = DeploymentPhase.get_grid()
	if grid == null:
		return

	var cell = grid.get_cell(x, y)
	if cell == null:
		return

	# If we are dragging a unit, try to place it
	if not _dragging_unit.is_empty():
		if cell.has_unit():
			# Swap if dragging from grid
			if _drag_source.x >= 0:
				DeploymentPhase.swap_units(_drag_source.x, _drag_source.y, x, y)
			else:
				# Can't place on occupied cell from pool
				return
		else:
			if _drag_source.x >= 0:
				# Moving from grid cell to empty cell
				DeploymentPhase.remove_unit_at(_drag_source.x, _drag_source.y)
			var unit_to_place: Dictionary = _dragging_unit.duplicate()
			unit_to_place["side"] = "attacker"
			DeploymentPhase.place_unit_at(unit_to_place, x, y)

		_dragging_unit = {}
		_drag_source = Vector2i(-1, -1)
		_refresh_grid()
		_refresh_unit_pool()
		_refresh_formation_panel()
		_refresh_counter_panel()
		return

	# If cell has a unit, pick it up for dragging
	if cell.has_unit():
		_dragging_unit = cell.unit.duplicate()
		_drag_source = Vector2i(x, y)
		# Visual feedback: highlight valid placement cells
		_highlight_valid_cells()
		return

	# Empty cell clicked with nothing selected: do nothing
	pass

func _on_pool_unit_pressed(unit: Dictionary) -> void:
	_dragging_unit = unit.duplicate()
	_drag_source = Vector2i(-1, -1)  # From pool, not grid
	_highlight_valid_cells()

func _on_cell_hover(x: int, y: int) -> void:
	_hovered_cell = Vector2i(x, y)
	var grid = DeploymentPhase.get_grid()
	if grid == null:
		return
	var cell = grid.get_cell(x, y)
	if cell != null and cell.has_unit():
		_show_tooltip(cell.unit)
	else:
		_hide_tooltip()

func _on_cell_unhover(x: int, y: int) -> void:
	if _hovered_cell == Vector2i(x, y):
		_hovered_cell = Vector2i(-1, -1)
		_hide_tooltip()

func _on_unit_hover(unit: Dictionary) -> void:
	_show_tooltip(unit)

func _on_unit_unhover() -> void:
	_hide_tooltip()

func _on_directive_changed(index: int) -> void:
	DeploymentPhase.set_directive(index)

func _on_start() -> void:
	DeploymentPhase.confirm_deployment()
	hide_deployment()
	battle_start_pressed.emit()

func _on_cancel() -> void:
	DeploymentPhase.cancel_deployment()
	hide_deployment()
	deployment_cancelled.emit()

func _on_auto_deploy() -> void:
	var result: Dictionary = DeploymentPhase.auto_deploy(
		DeploymentPhase.get_player_units(),
		DeploymentPhase._terrain
	)
	DeploymentPhase._apply_auto_deployment(result)
	DeploymentPhase._update_formation_preview()
	_refresh_grid()
	_refresh_unit_pool()
	_refresh_formation_panel()
	_refresh_counter_panel()

# ═════════════════════════════════════════════════
#                   HELPERS
# ═════════════════════════════════════════════════

func _highlight_valid_cells() -> void:
	var grid = DeploymentPhase.get_grid()
	if grid == null:
		return
	for y in range(GRID_H):
		for x in range(GRID_W):
			var cell = grid.get_cell(x, y)
			var btn: Button = _cell_buttons[y][x]
			if cell == null:
				continue
			if cell.has_unit():
				btn.add_theme_stylebox_override("normal", _make_panel_style(CELL_OCCUPIED, GOLD, 1))
			elif cell.obstacle == "wall":
				btn.add_theme_stylebox_override("normal", _make_panel_style(CELL_INVALID, RED, 1))
			else:
				btn.add_theme_stylebox_override("normal", _make_panel_style(CELL_VALID, GREEN, 1))

func _show_tooltip(unit: Dictionary) -> void:
	var troop_id: String = unit.get("troop_id", unit.get("unit_type", unit.get("type", "?")))
	var soldiers: int = unit.get("soldiers", unit.get("count", 0))
	var atk: int = unit.get("atk", 0)
	var def_val: int = unit.get("def", 0)
	var spd: int = unit.get("spd", 0)
	var passive: String = unit.get("passive", "")

	var text: String = "[b]%s[/b]\n" % troop_id
	text += "兵力: %d  ATK: %d  DEF: %d  SPD: %d\n" % [soldiers, atk, def_val, spd]
	if passive != "":
		text += "[color=#aa8833]特性: %s[/color]" % passive

	tooltip_label.text = text
	tooltip_panel.visible = true
	# Position near mouse
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	tooltip_panel.position = mouse_pos + Vector2(16, 16)

func _hide_tooltip() -> void:
	tooltip_panel.visible = false

func _make_panel_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_width
	sb.border_width_right = border_width
	sb.border_width_top = border_width
	sb.border_width_bottom = border_width
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	sb.content_margin_left = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	return sb
