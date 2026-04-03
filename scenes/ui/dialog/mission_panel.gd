## mission_panel.gd — Territory Mission Panel for Dark Tide SLG
## Sengoku Rance 07-style modal panel showing available character story missions.
## Opens when the player clicks an owned territory; missions can be manually executed for 1 AP.
extends CanvasLayer

# ── Constants ──
const AP_COST: int = 1
const ROUTE_LABELS: Dictionary = {
	"training": "调教路线",
	"pure_love": "纯爱路线",
	"neutral": "中立路线",
	"friendly": "友好路线",
}

const COLOR_HEADER := Color(0.8, 0.9, 0.6)
const COLOR_AVAILABLE := Color(0.4, 0.8, 0.4)
const COLOR_LOCKED := Color(0.5, 0.5, 0.5)
const COLOR_COMPLETED := Color(0.3, 0.6, 0.3)

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
	layer = UILayerRegistry.LAYER_INFO_PANELS
	_build_ui()
	_connect_signals()
	hide_panel()


func _connect_signals() -> void:
	EventBus.territory_selected.connect(_on_territory_selected)
	EventBus.story_event_completed.connect(_on_story_event_completed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			if _visible:
				hide_panel()
			else:
				show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			hide_panel()
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "MissionPanelRoot"
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

	# Main panel
	main_panel = PanelContainer.new()
	main_panel.anchor_right = 1.0
	main_panel.anchor_bottom = 1.0
	main_panel.offset_left = 80
	main_panel.offset_right = -80
	main_panel.offset_top = 40
	main_panel.offset_bottom = -40
	var style := StyleBoxFlat.new()
	style.bg_color = ColorTheme.BG_SECONDARY
	style.border_color = ColorTheme.BORDER_DEFAULT
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	main_panel.add_theme_stylebox_override("panel", style)
	root.add_child(main_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	main_panel.add_child(outer_vbox)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header_row)

	header_label = Label.new()
	header_label.text = "据点任務"
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", COLOR_HEADER)
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

	# Content area
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(content_scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 6)
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

	var missions: Array = StoryEventSystem.get_available_missions()

	# Count available
	var available_count: int = 0
	for m in missions:
		if m.get("status", "") == "available":
			available_count += 1

	header_label.text = "据点任務 (%d 个可用)" % available_count

	# Filter: only show available and completed missions (hide locked future events)
	var visible_missions: Array = missions.filter(func(m): return m.get("status", "") != "locked")

	if visible_missions.is_empty():
		_add_empty_notice()
		return

	# Group by hero_name
	var groups: Dictionary = {}
	var group_order: Array = []
	for m in visible_missions:
		var hero_name: String = m.get("hero_name", "???")
		if not groups.has(hero_name):
			groups[hero_name] = []
			group_order.append(hero_name)
		groups[hero_name].append(m)

	# Render each group (sorted: available first, then completed)
	for hero_name in group_order:
		_add_character_group_header(hero_name)
		var sorted_missions: Array = groups[hero_name].duplicate()
		sorted_missions.sort_custom(func(a, b):
			var order: Dictionary = {"available": 0, "completed": 1}
			return order.get(a.get("status", ""), 2) < order.get(b.get("status", ""), 2)
		)
		for mission in sorted_missions:
			_add_mission_card(mission)


func _clear_content() -> void:
	for child in content_container.get_children():
		child.queue_free()


func _add_empty_notice() -> void:
	var lbl := Label.new()
	lbl.text = "暂无可用任务"
	lbl.add_theme_color_override("font_color", COLOR_LOCKED)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = "提示：提升英雄好感度或满足触发条件后，任务将在此处显示。"
	hint_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.4))
	hint_lbl.add_theme_font_size_override("font_size", 12)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_container.add_child(hint_lbl)


func _add_character_group_header(hero_name: String) -> void:
	var sep := HSeparator.new()
	content_container.add_child(sep)

	var lbl := Label.new()
	lbl.text = "— %s —" % hero_name
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", COLOR_HEADER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(lbl)


func _add_mission_card(mission: Dictionary) -> void:
	var status: String = mission.get("status", "locked")
	var hero_id: String = mission.get("hero_id", "")
	var event_name: String = mission.get("event_name", "???")
	var route: String = mission.get("route", "")
	var route_label: String = ROUTE_LABELS.get(route, route)

	# Card container
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()

	match status:
		"available":
			card_style.bg_color = Color(0.08, 0.12, 0.08, 0.9)
			card_style.border_color = Color(0.4, 0.8, 0.4, 0.7)
		"completed":
			card_style.bg_color = Color(0.06, 0.08, 0.06, 0.8)
			card_style.border_color = Color(0.3, 0.6, 0.3, 0.5)
		_:  # locked
			card_style.bg_color = Color(0.06, 0.06, 0.06, 0.8)
			card_style.border_color = Color(0.3, 0.3, 0.3, 0.4)

	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", card_style)
	content_container.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	# Title row: icon + event name + status badge
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var icon_lbl := Label.new()
	match status:
		"available": icon_lbl.text = "★"
		"completed": icon_lbl.text = "✓"
		_: icon_lbl.text = "○"
	icon_lbl.add_theme_font_size_override("font_size", 16)
	icon_lbl.add_theme_color_override("font_color", _status_color(status))
	title_row.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = " %s" % event_name
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", _status_color(status))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = _status_text(status)
	badge_lbl.add_theme_font_size_override("font_size", 12)
	badge_lbl.add_theme_color_override("font_color", _status_color(status))
	title_row.add_child(badge_lbl)

	# Detail row: route + cost (only for non-completed)
	if status != "completed":
		var detail_row := HBoxContainer.new()
		vbox.add_child(detail_row)

		var route_lbl := Label.new()
		route_lbl.text = "路线：%s" % route_label
		route_lbl.add_theme_font_size_override("font_size", 13)
		route_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		route_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		detail_row.add_child(route_lbl)

		if status == "available":
			var cost_lbl := Label.new()
			cost_lbl.text = "消耗：%d AP" % AP_COST
			cost_lbl.add_theme_font_size_override("font_size", 13)
			cost_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.5))
			detail_row.add_child(cost_lbl)
	else:
		# Completed: show route in muted tone
		var route_lbl := Label.new()
		route_lbl.text = "路线：%s" % route_label
		route_lbl.add_theme_font_size_override("font_size", 13)
		route_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		vbox.add_child(route_lbl)

	# Execute button (available only)
	if status == "available":
		var btn_row := HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_END
		vbox.add_child(btn_row)

		var execute_btn := Button.new()
		execute_btn.text = "▶ 执行任务"
		execute_btn.custom_minimum_size = Vector2(120, 30)
		execute_btn.add_theme_font_size_override("font_size", 13)

		# Disable if not enough AP
		var player: Dictionary = GameManager.get_current_player()
		var current_ap: int = player.get("ap", 0)
		if current_ap < AP_COST:
			execute_btn.disabled = true
			execute_btn.tooltip_text = "AP不足 (需要 %d AP)" % AP_COST

		execute_btn.pressed.connect(func(): _on_execute_mission(hero_id))
		btn_row.add_child(execute_btn)


# ═══════════════════════════════════════════════════════════════
#                       STATUS HELPERS
# ═══════════════════════════════════════════════════════════════

func _status_text(status: String) -> String:
	match status:
		"available": return "【可执行】"
		"locked": return "【未解锁】"
		"completed": return "【已完成】"
	return "【未知】"


func _status_color(status: String) -> Color:
	match status:
		"available": return COLOR_AVAILABLE
		"completed": return COLOR_COMPLETED
		"locked": return COLOR_LOCKED
	return COLOR_LOCKED


# ═══════════════════════════════════════════════════════════════
#                         ACTIONS
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

	# Emit signal for external listeners
	EventBus.mission_execute_requested.emit(hero_id)

	# Trigger story event
	StoryEventSystem.manually_trigger_event(hero_id)

	# Hide panel while dialog plays
	hide_panel()


# ═══════════════════════════════════════════════════════════════
#                         CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_territory_selected(tile_index: int) -> void:
	_selected_tile = tile_index


func _on_story_event_completed(_hero_id: String, _event_id: String) -> void:
	if _visible:
		_refresh()


func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
