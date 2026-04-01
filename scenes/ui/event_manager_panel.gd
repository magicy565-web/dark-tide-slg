## event_manager_panel.gd - Strategic event timeline panel (事件管理器)
## Shows all timed story windows with status, turn ranges, and conditions hints.
## Toggled via HUD button or "E" key. Layer 12 full-screen modal.
extends CanvasLayer

const BalanceConfig = preload("res://systems/balance_config.gd")

signal panel_closed()

# ── Theme colors ──
const BG_COLOR := Color(0.05, 0.04, 0.09, 0.97)
const BORDER_COLOR := Color(0.6, 0.45, 0.2)
const CARD_BG := Color(0.08, 0.06, 0.12)
const CARD_BORDER := Color(0.3, 0.25, 0.15)
const TEXT_COLOR := Color(0.9, 0.88, 0.82)
const GOLD := Color(0.85, 0.7, 0.3)
const GOLD_BRIGHT := Color(1.0, 0.85, 0.4)
const ACTIVE_COLOR := Color(0.3, 0.8, 0.35)
const PENDING_COLOR := Color(0.7, 0.65, 0.4)
const EXPIRED_COLOR := Color(0.5, 0.3, 0.3)
const TRIGGERED_COLOR := Color(0.3, 0.6, 0.9)
const DIM_TEXT := Color(0.5, 0.48, 0.42)
const MARGIN := 40.0

# ── Filter enum ──
enum Filter { ALL, ACTIVE, COMPLETED, EXPIRED }

# ── State ──
var _filter: int = Filter.ALL
var _tween: Tween = null

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var main_vbox: VBoxContainer
var turn_label: Label
var filter_buttons: Array = []
var timeline_bar: Control
var scroll_container: ScrollContainer
var card_vbox: VBoxContainer
var summary_label: Label

func _ready() -> void:
	layer = UILayerRegistry.LAYER_EVENT_MANAGER
	visible = false
	_build_ui()
	if EventBus:
		EventBus.turn_started.connect(_on_turn_started)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			toggle_panel()
			get_viewport().set_input_as_handled()

# ═══════════════════════════════════════════════════════════════
#                         PUBLIC API
# ═══════════════════════════════════════════════════════════════

func show_panel() -> void:
	visible = true
	_refresh()
	_show_animated()

func hide_panel() -> void:
	_hide_animated()

func toggle_panel() -> void:
	if visible:
		hide_panel()
	else:
		show_panel()

# ═══════════════════════════════════════════════════════════════
#                         BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "EventManagerRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dim background
	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.6)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dimmer_input)
	root.add_child(dim_bg)

	# Main panel with 40px margins
	main_panel = PanelContainer.new()
	main_panel.anchor_right = 1.0
	main_panel.anchor_bottom = 1.0
	main_panel.offset_left = MARGIN
	main_panel.offset_top = MARGIN
	main_panel.offset_right = -MARGIN
	main_panel.offset_bottom = -MARGIN
	main_panel.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR, BORDER_COLOR, 2, 12))
	root.add_child(main_panel)

	main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	main_panel.add_child(main_vbox)

	_build_header()
	_build_filter_tabs()
	_build_timeline()
	_build_event_list()
	_build_footer()

# ── Placeholder build methods (filled in via Edit) ──

func _build_header() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	main_vbox.add_child(hbox)

	var title := Label.new()
	title.text = "事件管理器"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", 22)
	hbox.add_child(title)

	turn_label = Label.new()
	turn_label.text = "当前回合: 1"
	turn_label.add_theme_color_override("font_color", TEXT_COLOR)
	turn_label.add_theme_font_size_override("font_size", 15)
	hbox.add_child(turn_label)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(36, 36)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.pressed.connect(hide_panel)
	hbox.add_child(close_btn)

	var sep := HSeparator.new()
	main_vbox.add_child(sep)

func _build_filter_tabs() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(hbox)

	var tab_names := ["全部", "进行中", "已完成", "已过期"]
	for i in range(tab_names.size()):
		var btn := Button.new()
		btn.text = tab_names[i]
		btn.custom_minimum_size = Vector2(90, 32)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_filter_pressed.bind(i))
		hbox.add_child(btn)
		filter_buttons.append(btn)

func _build_timeline() -> void:
	# Horizontal timeline bar showing all events mapped to turn ranges
	timeline_bar = Control.new()
	timeline_bar.custom_minimum_size = Vector2(0, 50)
	main_vbox.add_child(timeline_bar)
	# Drawing handled in _refresh_timeline()

func _build_event_list() -> void:
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll_container)

	card_vbox = VBoxContainer.new()
	card_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_theme_constant_override("separation", 8)
	scroll_container.add_child(card_vbox)

func _build_footer() -> void:
	var sep := HSeparator.new()
	main_vbox.add_child(sep)

	summary_label = Label.new()
	summary_label.text = "0 个事件可用 / 0 已触发 / 0 已过期"
	summary_label.add_theme_color_override("font_color", DIM_TEXT)
	summary_label.add_theme_font_size_override("font_size", 13)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(summary_label)

# ═══════════════════════════════════════════════════════════════
#                         REFRESH
# ═══════════════════════════════════════════════════════════════

func _refresh() -> void:
	var turn: int = _get_current_turn()
	turn_label.text = "当前回合: %d" % turn

	# Update filter button highlights
	for i in range(filter_buttons.size()):
		var btn: Button = filter_buttons[i]
		if i == _filter:
			btn.add_theme_color_override("font_color", GOLD_BRIGHT)
		else:
			btn.add_theme_color_override("font_color", TEXT_COLOR)

	# Gather window data
	var es = get_tree().root.get_node_or_null("EventSystem")
	var statuses: Dictionary = {}
	if es and es.has_method("get_story_window_status"):
		statuses = es.get_story_window_status()

	var windows: Array = []
	if BalanceConfig:
		windows = BalanceConfig.TIMED_STORY_WINDOWS

	# Build filtered list
	var filtered: Array = []
	var count_active: int = 0
	var count_triggered: int = 0
	var count_expired: int = 0
	var count_pending: int = 0

	for w in windows:
		var wid: String = w["id"]
		var status: String = statuses.get(wid, {}).get("status", "pending")
		var turn_min: int = w["turn_range"][0]
		var turn_max: int = w["turn_range"][1]

		# Determine display status
		var display_status: String = status
		if status == "pending":
			if turn < turn_min:
				display_status = "locked"
				count_pending += 1
			else:
				display_status = "active"
				count_active += 1
		elif status == "triggered":
			count_triggered += 1
		elif status == "expired":
			count_expired += 1

		# Apply filter
		var show_card: bool = false
		match _filter:
			Filter.ALL:
				show_card = true
			Filter.ACTIVE:
				show_card = display_status == "active" or display_status == "locked"
			Filter.COMPLETED:
				show_card = display_status == "triggered"
			Filter.EXPIRED:
				show_card = display_status == "expired"

		if show_card:
			filtered.append({"def": w, "status": display_status, "db_status": status})

	# Clear old cards
	for child in card_vbox.get_children():
		child.queue_free()

	# Build cards
	for entry in filtered:
		_build_event_card(entry["def"], entry["status"], entry["db_status"], turn)

	# Update timeline
	_refresh_timeline(windows, statuses, turn)

	# Update footer
	summary_label.text = "%d 个进行中 / %d 已触发 / %d 已过期 / %d 未开放" % [
		count_active, count_triggered, count_expired, count_pending]


func _build_event_card(w: Dictionary, display_status: String, _db_status: String, turn: int) -> void:
	var card := PanelContainer.new()
	var border_col: Color
	match display_status:
		"active":
			border_col = ACTIVE_COLOR
		"triggered":
			border_col = TRIGGERED_COLOR
		"expired":
			border_col = EXPIRED_COLOR
		_:
			border_col = CARD_BORDER
	card.add_theme_stylebox_override("panel", _make_panel_style(CARD_BG, border_col, 1, 6))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vbox.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	# Row 1: Status badge + Title + Priority
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 8)
	vb.add_child(row1)

	var badge := Label.new()
	badge.add_theme_font_size_override("font_size", 12)
	match display_status:
		"locked":
			badge.text = "[未开放]"
			badge.add_theme_color_override("font_color", DIM_TEXT)
		"active":
			badge.text = "[进行中]"
			badge.add_theme_color_override("font_color", ACTIVE_COLOR)
		"triggered":
			badge.text = "[已触发]"
			badge.add_theme_color_override("font_color", TRIGGERED_COLOR)
		"expired":
			badge.text = "[已过期]"
			badge.add_theme_color_override("font_color", EXPIRED_COLOR)
	row1.add_child(badge)

	var title_lbl := Label.new()
	title_lbl.text = w["title"]
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", GOLD if display_status != "expired" else DIM_TEXT)
	row1.add_child(title_lbl)

	var priority: int = w.get("priority", 1)
	var star_lbl := Label.new()
	star_lbl.text = "*".repeat(priority)
	star_lbl.add_theme_font_size_override("font_size", 14)
	var star_col: Color = Color(1.0, 0.3, 0.3) if priority >= 3 else (Color(1.0, 0.8, 0.2) if priority == 2 else Color(0.6, 0.6, 0.5))
	star_lbl.add_theme_color_override("font_color", star_col)
	row1.add_child(star_lbl)

	# Row 2: Turn window bar
	var turn_min: int = w["turn_range"][0]
	var turn_max: int = w["turn_range"][1]
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 6)
	vb.add_child(bar_row)

	var range_lbl := Label.new()
	range_lbl.text = "T%d - T%d" % [turn_min, turn_max]
	range_lbl.add_theme_font_size_override("font_size", 11)
	range_lbl.add_theme_color_override("font_color", DIM_TEXT)
	range_lbl.custom_minimum_size = Vector2(70, 0)
	bar_row.add_child(range_lbl)

	# Progress bar
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(200, 12)
	bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.color = Color(0.15, 0.12, 0.2)
	bar_row.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	var max_turn: int = maxi(turn_max, 60)
	var bar_width: float = 200.0
	var fill_start: float = (float(turn_min) / float(max_turn)) * bar_width
	var fill_end: float = (float(turn_max) / float(max_turn)) * bar_width
	bar_fill.position = Vector2(fill_start, 0)
	bar_fill.custom_minimum_size = Vector2(fill_end - fill_start, 12)
	bar_fill.color = border_col * Color(1, 1, 1, 0.6)
	bar_bg.add_child(bar_fill)

	# Current turn marker
	if turn <= max_turn:
		var marker := ColorRect.new()
		var marker_x: float = (float(turn) / float(max_turn)) * bar_width
		marker.position = Vector2(marker_x - 1, 0)
		marker.custom_minimum_size = Vector2(2, 12)
		marker.color = Color.WHITE
		bar_bg.add_child(marker)

	# Remaining turns indicator
	if display_status == "active":
		var remaining: int = turn_max - turn
		var remain_lbl := Label.new()
		remain_lbl.text = "剩余%d回合" % remaining
		remain_lbl.add_theme_font_size_override("font_size", 11)
		var urgency_col: Color = ACTIVE_COLOR if remaining > 5 else (PENDING_COLOR if remaining > 2 else EXPIRED_COLOR)
		remain_lbl.add_theme_color_override("font_color", urgency_col)
		bar_row.add_child(remain_lbl)

	# Row 3: Description / hint
	var desc_lbl := Label.new()
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	if display_status == "triggered":
		desc_lbl.text = w.get("narrative_text", "")
		desc_lbl.add_theme_color_override("font_color", TEXT_COLOR)
	elif display_status == "expired":
		var miss: Dictionary = w.get("miss_consequence", {})
		var miss_desc: String = miss.get("desc", "机会已失")
		desc_lbl.text = miss_desc if miss.get("type", "nothing") != "nothing" else "此事件已过期"
		desc_lbl.add_theme_color_override("font_color", EXPIRED_COLOR)
	elif display_status == "active":
		desc_lbl.text = _get_vague_hint(w)
		desc_lbl.add_theme_color_override("font_color", PENDING_COLOR)
	else:
		desc_lbl.text = "尚未开放 — 回合 %d 后可能出现" % turn_min
		desc_lbl.add_theme_color_override("font_color", DIM_TEXT)
	vb.add_child(desc_lbl)

	# Row 4: Conditions hint for active events
	if display_status == "active":
		var cond_text: String = _get_condition_hint(w)
		if cond_text != "":
			var cond_lbl := Label.new()
			cond_lbl.text = "条件: " + cond_text
			cond_lbl.add_theme_font_size_override("font_size", 11)
			cond_lbl.add_theme_color_override("font_color", DIM_TEXT)
			cond_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(cond_lbl)

	# Row 5: Reward preview for triggered events
	if display_status == "triggered":
		var reward_text: String = _get_reward_text(w)
		if reward_text != "":
			var reward_lbl := Label.new()
			reward_lbl.text = "奖励: " + reward_text
			reward_lbl.add_theme_font_size_override("font_size", 11)
			reward_lbl.add_theme_color_override("font_color", TRIGGERED_COLOR)
			vb.add_child(reward_lbl)


func _refresh_timeline(windows: Array, statuses: Dictionary, turn: int) -> void:
	# Clear previous timeline children
	for child in timeline_bar.get_children():
		child.queue_free()

	# Background
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.1, 0.08, 0.14)
	timeline_bar.add_child(bg)

	var max_turn: int = 60
	var bar_w: float = timeline_bar.size.x if timeline_bar.size.x > 100 else 800.0
	var bar_h: float = 50.0

	# Draw each window as a colored segment
	var row: int = 0
	for w in windows:
		var wid: String = w["id"]
		var status: String = statuses.get(wid, {}).get("status", "pending")
		var turn_min: int = w["turn_range"][0]
		var turn_max: int = w["turn_range"][1]

		var col: Color
		match status:
			"triggered":
				col = TRIGGERED_COLOR * Color(1, 1, 1, 0.5)
			"expired":
				col = EXPIRED_COLOR * Color(1, 1, 1, 0.5)
			_:
				if turn >= turn_min and turn <= turn_max:
					col = ACTIVE_COLOR * Color(1, 1, 1, 0.5)
				else:
					col = PENDING_COLOR * Color(1, 1, 1, 0.3)

		var x_start: float = (float(turn_min) / float(max_turn)) * bar_w
		var x_end: float = (float(turn_max) / float(max_turn)) * bar_w
		var seg := ColorRect.new()
		seg.position = Vector2(x_start, row * 5)
		seg.size = Vector2(x_end - x_start, 4)
		seg.color = col
		bg.add_child(seg)
		row = (row + 1) % 10

	# Current turn marker
	var marker := ColorRect.new()
	var mx: float = (float(turn) / float(max_turn)) * bar_w
	marker.position = Vector2(mx - 1, 0)
	marker.size = Vector2(2, bar_h)
	marker.color = Color.WHITE
	bg.add_child(marker)

	# Turn labels
	for t in [1, 10, 20, 30, 40, 50, 60]:
		var lbl := Label.new()
		lbl.text = str(t)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color", DIM_TEXT)
		lbl.position = Vector2((float(t) / float(max_turn)) * bar_w - 5, bar_h - 14)
		bg.add_child(lbl)


func _get_vague_hint(w: Dictionary) -> String:
	var hints: Dictionary = {
		"merchant_caravan": "远方传来商队的铃铛声...",
		"border_refugees": "边境传来流民的消息，需要足够的领地来安置...",
		"ancient_ruins_expedition": "遗迹入口散发着微光，需要控制特定区域...",
		"alliance_proposal": "有人在打听你的威名，足够的威望或许能吸引来访...",
		"dark_ritual_warning": "暗处有异常的魔力波动，需要谍报网络来追踪...",
		"harvest_festival": "农田丰收在望，需要足够的农场领地...",
		"weapon_smiths_offer": "矿区传来锻造声，需要矿场和精铁储备...",
		"final_prophecy": "先知的低语在风中回荡，需要广阔的疆域...",
		"pirate_king_negotiation": "海上旗帜摇曳，需要控制港口...",
		"scholar_conclave": "学者们在议论你的成就，需要足够的威望...",
	}
	return hints.get(w["id"], w.get("narrative_text", "未知事件...").left(30) + "...")


func _get_condition_hint(w: Dictionary) -> String:
	var conditions: Dictionary = w.get("conditions", {})
	if conditions.is_empty():
		return "无特殊条件"
	var parts: Array = []
	if conditions.has("tile_control"):
		parts.append("控制 %d+ 领地" % conditions["tile_control"])
	if conditions.has("prestige_min"):
		parts.append("威望 >= %d" % conditions["prestige_min"])
	if conditions.has("tile_index_owned"):
		parts.append("控制特定区域")
	if conditions.has("tile_type_count"):
		parts.append("控制特定类型领地")
	if conditions.has("espionage_level"):
		parts.append("谍报等级 >= %d" % conditions["espionage_level"])
	if conditions.has("resource_min"):
		parts.append("需要特定资源储备")
	return " | ".join(parts)


func _get_reward_text(w: Dictionary) -> String:
	var rewards: Dictionary = w.get("rewards", {})
	var parts: Array = []
	if rewards.has("gold") and rewards["gold"] > 0:
		parts.append("金 %d" % rewards["gold"])
	if rewards.has("food") and rewards["food"] > 0:
		parts.append("粮 %d" % rewards["food"])
	if rewards.has("prestige") and rewards["prestige"] > 0:
		parts.append("威望 %d" % rewards["prestige"])
	if rewards.has("soldiers"):
		parts.append("士兵 %d" % rewards["soldiers"])
	if rewards.has("hero_recruit"):
		parts.append("招募英雄")
	if rewards.has("troop_unlock"):
		parts.append("解锁兵种")
	if rewards.has("order"):
		parts.append("秩序 +%d" % rewards["order"])
	return " / ".join(parts)

# ═══════════════════════════════════════════════════════════════
#                        ANIMATION
# ═══════════════════════════════════════════════════════════════

func _show_animated() -> void:
	root.visible = true
	dim_bg.modulate.a = 0.0
	main_panel.modulate.a = 0.0
	main_panel.scale = Vector2(0.9, 0.9)
	main_panel.pivot_offset = main_panel.size * 0.5
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim_bg, "modulate:a", 1.0, 0.2)
	_tween.tween_property(main_panel, "modulate:a", 1.0, 0.25)
	_tween.tween_property(main_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_animated() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim_bg, "modulate:a", 0.0, 0.15)
	_tween.tween_property(main_panel, "modulate:a", 0.0, 0.15)
	_tween.tween_property(main_panel, "scale", Vector2(0.95, 0.95), 0.15)
	_tween.chain().tween_callback(_on_hide_done)

func _on_hide_done() -> void:
	visible = false
	panel_closed.emit()

# ═══════════════════════════════════════════════════════════════
#                        SIGNALS
# ═══════════════════════════════════════════════════════════════

func _on_turn_started(_player_id: int) -> void:
	if visible:
		_refresh()

func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_panel()

func _on_filter_pressed(filter_index: int) -> void:
	_filter = filter_index
	_refresh()

# ═══════════════════════════════════════════════════════════════
#                         HELPERS
# ═══════════════════════════════════════════════════════════════

func _make_panel_style(bg: Color, border: Color, width: int, radius: int = 8) -> StyleBoxFlat:
	var sf := StyleBoxFlat.new()
	sf.bg_color = bg
	sf.border_color = border
	sf.set_border_width_all(width)
	sf.set_corner_radius_all(radius)
	sf.set_content_margin_all(16)
	return sf

func _get_current_turn() -> int:
	if GameManager and GameManager.get("turn_number") != null:
		return GameManager.turn_number
	return 1
