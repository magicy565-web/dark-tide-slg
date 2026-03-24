## quest_journal_panel.gd — Quest Journal UI Panel for 暗潮 SLG (v2.4)
## Modal panel showing all quest types: main, side, challenge, character.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")
const QuestDefs = preload("res://systems/quest/quest_definitions.gd")

# ── State ──
var _visible: bool = false
var _current_tab: String = "main"  # "main", "side", "challenge", "character"

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button

# Tab buttons
var tab_container: HBoxContainer
var btn_tab_main: Button
var btn_tab_side: Button
var btn_tab_challenge: Button
var btn_tab_character: Button

# Content area
var content_scroll: ScrollContainer
var content_container: VBoxContainer

# Status label
var status_label: Label


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 5
	_build_ui()
	_connect_signals()
	hide_panel()


func _connect_signals() -> void:
	EventBus.quest_journal_updated.connect(_on_quest_updated)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_J:
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
	root.name = "QuestJournalRoot"
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
	main_panel.offset_left = 40
	main_panel.offset_right = -40
	main_panel.offset_top = 30
	main_panel.offset_bottom = -30
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.09, 0.97)
	style.border_color = Color(0.4, 0.55, 0.3)
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
	header_label.text = "任务日志"
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.6))
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header_row.add_child(status_label)

	btn_close = Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	# Tab buttons
	tab_container = HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(tab_container)

	btn_tab_main = _make_tab_button("主线任务")
	btn_tab_main.pressed.connect(func(): _switch_tab("main"))
	tab_container.add_child(btn_tab_main)

	btn_tab_side = _make_tab_button("支线任务")
	btn_tab_side.pressed.connect(func(): _switch_tab("side"))
	tab_container.add_child(btn_tab_side)

	btn_tab_challenge = _make_tab_button("挑战任务")
	btn_tab_challenge.pressed.connect(func(): _switch_tab("challenge"))
	tab_container.add_child(btn_tab_challenge)

	btn_tab_character = _make_tab_button("角色任务")
	btn_tab_character.pressed.connect(func(): _switch_tab("character"))
	tab_container.add_child(btn_tab_character)

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


func _make_tab_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(110, 32)
	btn.add_theme_font_size_override("font_size", 14)
	return btn


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
#                          TABS
# ═══════════════════════════════════════════════════════════════

func _switch_tab(tab: String) -> void:
	_current_tab = tab
	_refresh()


func _update_tab_highlight() -> void:
	var tabs_map: Dictionary = {
		"main": btn_tab_main,
		"side": btn_tab_side,
		"challenge": btn_tab_challenge,
		"character": btn_tab_character,
	}
	for key in tabs_map:
		var btn: Button = tabs_map[key]
		if key == _current_tab:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		else:
			btn.remove_theme_color_override("font_color")


# ═══════════════════════════════════════════════════════════════
#                         REFRESH
# ═══════════════════════════════════════════════════════════════

func _refresh() -> void:
	_update_tab_highlight()
	_clear_content()

	var pid: int = GameManager.get_human_player_id()
	var all_quests: Array = QuestJournal.get_all_quests(pid)

	# Filter by current tab category
	var category_map: Dictionary = {
		"main": "main",
		"side": "side",
		"challenge": "challenge",
		"character": "character",
	}
	var target_cat: String = category_map.get(_current_tab, "main")
	var filtered: Array = []
	for q in all_quests:
		if q.get("category", "") == target_cat:
			filtered.append(q)

	# Update status label
	var active_count: int = QuestJournal.get_active_count()
	status_label.text = "进行中: %d" % active_count

	if filtered.is_empty():
		_add_empty_notice(target_cat)
	else:
		for quest in filtered:
			_add_quest_card(quest)


func _clear_content() -> void:
	for child in content_container.get_children():
		child.queue_free()


func _add_empty_notice(category: String) -> void:
	var names: Dictionary = {
		"main": "主线", "side": "支线", "challenge": "挑战", "character": "角色"
	}
	var lbl := Label.new()
	lbl.text = "暂无%s任务" % names.get(category, "")
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(lbl)


func _status_to_string(status_val) -> String:
	## Convert QuestStatus enum int to string key.
	if status_val is String:
		return status_val
	match int(status_val):
		QuestDefs.QuestStatus.LOCKED: return "locked"
		QuestDefs.QuestStatus.AVAILABLE: return "available"
		QuestDefs.QuestStatus.ACTIVE: return "active"
		QuestDefs.QuestStatus.COMBAT_PENDING: return "combat_pending"
		QuestDefs.QuestStatus.COMPLETED: return "completed"
		QuestDefs.QuestStatus.FAILED: return "failed"
	return "locked"


func _add_quest_card(quest: Dictionary) -> void:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	var status: String = _status_to_string(quest.get("status", 0))

	# Color based on status
	match status:
		"completed":
			card_style.bg_color = Color(0.08, 0.14, 0.08, 0.9)
			card_style.border_color = Color(0.3, 0.6, 0.3, 0.7)
		"active":
			card_style.bg_color = Color(0.12, 0.1, 0.05, 0.9)
			card_style.border_color = Color(0.7, 0.6, 0.2, 0.8)
		"available":
			card_style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
			card_style.border_color = Color(0.4, 0.5, 0.7, 0.6)
		"combat_pending":
			card_style.bg_color = Color(0.14, 0.06, 0.06, 0.9)
			card_style.border_color = Color(0.8, 0.3, 0.2, 0.8)
		"failed":
			card_style.bg_color = Color(0.1, 0.05, 0.05, 0.9)
			card_style.border_color = Color(0.5, 0.2, 0.2, 0.5)
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

	# Title row: name + status badge
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)

	var name_lbl := Label.new()
	name_lbl.text = quest.get("name", "???")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", _status_title_color(status))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)

	var badge_lbl := Label.new()
	badge_lbl.text = _status_text(status)
	badge_lbl.add_theme_font_size_override("font_size", 12)
	badge_lbl.add_theme_color_override("font_color", _status_badge_color(status))
	title_row.add_child(badge_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = quest.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# Objectives
	var objectives: Array = quest.get("objectives", [])
	if not objectives.is_empty() and status != "locked":
		var obj_vbox := VBoxContainer.new()
		obj_vbox.add_theme_constant_override("separation", 2)
		vbox.add_child(obj_vbox)

		for obj in objectives:
			var obj_lbl := Label.new()
			var obj_label: String = obj.get("label", "")
			var obj_done: bool = obj.get("done", false)
			if obj_done:
				obj_lbl.text = "  [x] %s" % obj_label
				obj_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 0.4))
			else:
				obj_lbl.text = "  [ ] %s" % obj_label
				obj_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5))
			obj_lbl.add_theme_font_size_override("font_size", 13)
			obj_vbox.add_child(obj_lbl)

	# Reward preview
	var reward_preview: String = quest.get("reward_preview", "")
	if reward_preview != "" and status != "locked":
		var reward_lbl := Label.new()
		reward_lbl.text = "奖励: %s" % reward_preview
		reward_lbl.add_theme_font_size_override("font_size", 12)
		reward_lbl.add_theme_color_override("font_color", Color(0.6, 0.5, 0.3))
		vbox.add_child(reward_lbl)

	# Challenge battle button (for combat_pending status)
	if status == "combat_pending":
		var battle_btn := Button.new()
		battle_btn.text = "开始挑战战斗"
		battle_btn.custom_minimum_size = Vector2(140, 30)
		battle_btn.add_theme_font_size_override("font_size", 13)
		var quest_id: String = quest.get("id", "")
		battle_btn.pressed.connect(func(): _on_challenge_battle(quest_id))
		vbox.add_child(battle_btn)


# ═══════════════════════════════════════════════════════════════
#                       STATUS HELPERS
# ═══════════════════════════════════════════════════════════════

func _status_text(status: String) -> String:
	match status:
		"locked": return "[未解锁]"
		"available": return "[可接受]"
		"active": return "[进行中]"
		"combat_pending": return "[待战斗]"
		"completed": return "[已完成]"
		"failed": return "[已失败]"
	return "[未知]"


func _status_title_color(status: String) -> Color:
	match status:
		"completed": return Color(0.5, 0.8, 0.5)
		"active": return Color(0.95, 0.85, 0.5)
		"available": return Color(0.7, 0.8, 1.0)
		"combat_pending": return Color(1.0, 0.5, 0.4)
		"failed": return Color(0.6, 0.3, 0.3)
	return Color(0.4, 0.4, 0.4)


func _status_badge_color(status: String) -> Color:
	match status:
		"completed": return Color(0.3, 0.7, 0.3)
		"active": return Color(0.9, 0.75, 0.2)
		"available": return Color(0.5, 0.6, 0.9)
		"combat_pending": return Color(0.9, 0.3, 0.2)
		"failed": return Color(0.5, 0.2, 0.2)
	return Color(0.35, 0.35, 0.35)


# ═══════════════════════════════════════════════════════════════
#                         ACTIONS
# ═══════════════════════════════════════════════════════════════

func _on_challenge_battle(quest_id: String) -> void:
	var pid: int = GameManager.get_human_player_id()
	var battle_data: Dictionary = QuestJournal.start_challenge_battle(quest_id)
	if battle_data.is_empty():
		return
	hide_panel()
	EventBus.challenge_battle_requested.emit(quest_id, battle_data)


# ═══════════════════════════════════════════════════════════════
#                         CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_quest_updated() -> void:
	if _visible:
		_refresh()


func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
