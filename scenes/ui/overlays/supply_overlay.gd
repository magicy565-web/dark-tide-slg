## supply_overlay.gd - Map overlay showing supply lines, depot markers, and attrition warnings.
## Toggled on when armies are selected; shows per-army supply bars and march mode selector.
extends CanvasLayer

# ── Theme colors ──
const BG_COLOR := Color(0.08, 0.06, 0.12, 0.92)
const GOLD := Color(0.85, 0.7, 0.3)
const GOLD_DIM := Color(0.55, 0.45, 0.2)
const GOLD_BRIGHT := Color(1.0, 0.85, 0.4)
const TEXT_COLOR := Color(0.9, 0.88, 0.82)
const CARD_BG := Color(0.1, 0.08, 0.15)
const CARD_BORDER := Color(0.4, 0.32, 0.18)

const GREEN := Color(0.2, 0.8, 0.3)
const YELLOW := Color(0.9, 0.8, 0.2)
const RED := Color(0.85, 0.2, 0.2)
const DEPOT_COLOR := Color(0.3, 0.6, 0.9)

const BAR_WIDTH := 60.0
const BAR_HEIGHT := 8.0

# ── State ──
var _army_bars: Dictionary = {}   # { army_id: { bar_bg, bar_fill, label, container } }
var _depot_markers: Dictionary = {} # { tile_index: marker_node }
var _attrition_labels: Array = []
var _selected_army_id: int = -1

# ── UI refs ──
var overlay_root: Control
var march_panel: PanelContainer
var march_dropdown: OptionButton
var march_label: Label

func _ready() -> void:
	layer = UILayerRegistry.LAYER_SUPPLY_OVERLAY
	visible = false
	_build_ui()
	if EventBus:
		EventBus.army_supply_changed.connect(_on_supply_changed)
		EventBus.army_attrition.connect(_on_attrition)
		EventBus.supply_depot_built.connect(_on_depot_built)
		EventBus.supply_depot_destroyed.connect(_on_depot_destroyed)

# ═════════════════════════════════════════════════
#                   PUBLIC API
# ═════════════════════════════════════════════════

func show_overlay(armies: Array, depots: Dictionary, selected_army: int = -1) -> void:
	_clear_all()
	_selected_army_id = selected_army
	visible = true
	# Build army supply bars
	for army in armies:
		var army_id: int = army.get("id", -1)
		var supply: int = army.get("supply", 100)
		var tile_pos: Vector2 = army.get("screen_pos", Vector2.ZERO)
		_create_army_bar(army_id, supply, tile_pos)
	# Build depot markers
	for tile_idx in depots:
		var pos: Vector2 = depots[tile_idx].get("screen_pos", Vector2.ZERO)
		_create_depot_marker(tile_idx, pos)
	# Show march mode selector if army selected
	if selected_army >= 0:
		march_panel.visible = true
		_refresh_march_dropdown(selected_army)
	else:
		march_panel.visible = false

func hide_overlay() -> void:
	visible = false
	_clear_all()

func update_army_supply(army_id: int, supply: int) -> void:
	if _army_bars.has(army_id):
		_update_bar(_army_bars[army_id], supply)

# ═════════════════════════════════════════════════
#                    BUILD UI
# ═════════════════════════════════════════════════

func _build_ui() -> void:
	overlay_root = Control.new()
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_root)

	# March mode selector panel (bottom-left)
	march_panel = PanelContainer.new()
	march_panel.anchor_left = 0.0; march_panel.anchor_right = 0.0
	march_panel.anchor_top = 1.0; march_panel.anchor_bottom = 1.0
	march_panel.offset_left = 16; march_panel.offset_right = 230
	march_panel.offset_top = -120; march_panel.offset_bottom = -16
	march_panel.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR, GOLD_DIM, 1))
	march_panel.visible = false
	add_child(march_panel)

	var mvbox := VBoxContainer.new()
	mvbox.add_theme_constant_override("separation", 6)
	march_panel.add_child(mvbox)

	march_label = Label.new()
	march_label.text = "行军模式"
	march_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	march_label.add_theme_font_size_override("font_size", 14)
	mvbox.add_child(march_label)

	march_dropdown = OptionButton.new()
	march_dropdown.add_item("普通行军", 0)
	march_dropdown.add_item("强行军 (AP-1, 补给×2)", 1)
	march_dropdown.add_item("谨慎行军 (AP+1, 补给×0.5)", 2)
	march_dropdown.add_item("就地征粮 (恢复补给)", 3)
	march_dropdown.add_theme_color_override("font_color", TEXT_COLOR)
	march_dropdown.add_theme_font_size_override("font_size", 12)
	var dd_style := _make_panel_style(CARD_BG, CARD_BORDER, 1)
	dd_style.set_content_margin_all(4)
	march_dropdown.add_theme_stylebox_override("normal", dd_style)
	march_dropdown.item_selected.connect(_on_march_mode_selected)
	mvbox.add_child(march_dropdown)

	var hint := Label.new()
	hint.text = "强行军: 速度快但补给消耗加倍\n谨慎行军: 防御+10%, 不可被伏击\n征粮: 原地恢复20补给, 15%意外"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", GOLD_DIM)
	hint.add_theme_font_size_override("font_size", 10)
	mvbox.add_child(hint)

# ═════════════════════════════════════════════════
#               ARMY SUPPLY BARS
# ═════════════════════════════════════════════════

func _create_army_bar(army_id: int, supply: int, screen_pos: Vector2) -> void:
	var container := Control.new()
	container.position = screen_pos + Vector2(-BAR_WIDTH * 0.5, -20)
	container.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT + 14)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(container)

	# Background bar
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.15, 0.12, 0.2)
	bar_bg.position = Vector2.ZERO
	bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	container.add_child(bar_bg)

	# Fill bar
	var bar_fill := ColorRect.new()
	bar_fill.position = Vector2.ZERO
	bar_fill.size = Vector2(BAR_WIDTH * (supply / 100.0), BAR_HEIGHT)
	bar_fill.color = _supply_color(supply)
	container.add_child(bar_fill)

	# Supply text
	var lbl := Label.new()
	lbl.text = "%d%%" % supply
	lbl.position = Vector2(0, BAR_HEIGHT + 1)
	lbl.add_theme_color_override("font_color", _supply_color(supply))
	lbl.add_theme_font_size_override("font_size", 10)
	container.add_child(lbl)

	_army_bars[army_id] = {
		"container": container, "bar_bg": bar_bg,
		"bar_fill": bar_fill, "label": lbl,
	}

func _update_bar(entry: Dictionary, supply: int) -> void:
	var fill: ColorRect = entry["bar_fill"]
	var lbl: Label = entry["label"]
	fill.size.x = BAR_WIDTH * (supply / 100.0)
	fill.color = _supply_color(supply)
	lbl.text = "%d%%" % supply
	lbl.add_theme_color_override("font_color", _supply_color(supply))

func _supply_color(supply: int) -> Color:
	if supply > 50:
		return GREEN
	elif supply > 25:
		return YELLOW
	return RED

# ═════════════════════════════════════════════════
#               DEPOT MARKERS
# ═════════════════════════════════════════════════

func _create_depot_marker(tile_idx: int, screen_pos: Vector2) -> void:
	var marker := Label.new()
	marker.text = "⚑ 补给站"
	marker.position = screen_pos + Vector2(-30, -28)
	marker.add_theme_color_override("font_color", DEPOT_COLOR)
	marker.add_theme_font_size_override("font_size", 11)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(marker)
	_depot_markers[tile_idx] = marker

# ═════════════════════════════════════════════════
#             ATTRITION WARNINGS
# ═════════════════════════════════════════════════

func show_attrition_warning(screen_pos: Vector2, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = screen_pos + Vector2(-40, -40)
	lbl.add_theme_color_override("font_color", RED)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_root.add_child(lbl)
	_attrition_labels.append(lbl)
	# Auto-fade after 3 seconds
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 2.0).set_delay(1.0)
	tween.tween_callback(lbl.queue_free)

# ═════════════════════════════════════════════════
#              SIGNAL HANDLERS
# ═════════════════════════════════════════════════

func _on_supply_changed(army_id: int, supply: int) -> void:
	update_army_supply(army_id, supply)

func _on_attrition(army_id: int, losses: Dictionary) -> void:
	if _army_bars.has(army_id):
		var pos: Vector2 = _army_bars[army_id]["container"].position
		var total_lost: int = 0
		for squad_id in losses:
			total_lost += losses[squad_id]
		if total_lost > 0:
			show_attrition_warning(pos, "减员 -%d" % total_lost)

func _on_depot_built(_tile_index: int, _player_id: int) -> void:
	# Depot position would be resolved by caller; placeholder for signal-only update
	pass

func _on_depot_destroyed(tile_index: int) -> void:
	if _depot_markers.has(tile_index):
		_depot_markers[tile_index].queue_free()
		_depot_markers.erase(tile_index)

func _on_march_mode_selected(index: int) -> void:
	if _selected_army_id < 0:
		return
	var mode: int = march_dropdown.get_item_id(index)
	# Delegate to SupplySystem (expected as sibling or autoload)
	var _ss = get_tree().root.get_node_or_null("SupplySystem")
	if _ss and _ss.has_method("set_march_mode"):
		_ss.set_march_mode(_selected_army_id, mode)
	elif EventBus:
		EventBus.message_log.emit("[补给] 设置行军模式: %s" % march_dropdown.get_item_text(index))

func _refresh_march_dropdown(army_id: int) -> void:
	var current_mode: int = 0
	var _ss = get_tree().root.get_node_or_null("SupplySystem")
	if _ss and _ss.has_method("get_march_mode"):
		current_mode = _ss.get_march_mode(army_id)
	for i in range(march_dropdown.item_count):
		if march_dropdown.get_item_id(i) == current_mode:
			march_dropdown.select(i)
			break

# ═════════════════════════════════════════════════
#                  CLEANUP
# ═════════════════════════════════════════════════

func _clear_all() -> void:
	for army_id in _army_bars:
		var entry: Dictionary = _army_bars[army_id]
		if is_instance_valid(entry["container"]):
			entry["container"].queue_free()
	_army_bars.clear()
	for tile_idx in _depot_markers:
		if is_instance_valid(_depot_markers[tile_idx]):
			_depot_markers[tile_idx].queue_free()
	_depot_markers.clear()
	for lbl in _attrition_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_attrition_labels.clear()

# ═════════════════════════════════════════════════
#                   STYLING
# ═════════════════════════════════════════════════

func _make_panel_style(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(10)
	return s
