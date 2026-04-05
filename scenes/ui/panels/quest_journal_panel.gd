## quest_journal_panel.gd — Quest Journal UI Panel for Dark Tide SLG (v2.4)
## Modal panel showing all quest types: main, side, challenge, character.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")
const QuestDefs = preload("res://systems/quest/quest_definitions.gd")
const SideQuestData = preload("res://systems/quest/side_quest_data.gd")

# ── State ──
var _visible: bool = false
var _current_tab: String = "main"  # "main", "side", "challenge", "character", "chain"

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
var btn_tab_chain: Button

# Content area
var content_scroll: ScrollContainer
var content_container: VBoxContainer

# Status label
var status_label: Label


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_INFO_PANELS
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
	header_label.text = "Quest Journal"
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

	btn_tab_main = _make_tab_button("Main Quests")
	btn_tab_main.pressed.connect(func(): _switch_tab("main"))
	tab_container.add_child(btn_tab_main)

	btn_tab_side = _make_tab_button("Side Quests")
	btn_tab_side.pressed.connect(func(): _switch_tab("side"))
	tab_container.add_child(btn_tab_side)

	btn_tab_challenge = _make_tab_button("Challenges")
	btn_tab_challenge.pressed.connect(func(): _switch_tab("challenge"))
	tab_container.add_child(btn_tab_challenge)

	btn_tab_character = _make_tab_button("Character Quests")
	btn_tab_character.pressed.connect(func(): _switch_tab("character"))
	tab_container.add_child(btn_tab_character)

	btn_tab_chain = _make_tab_button("任务链")
	btn_tab_chain.pressed.connect(func(): _switch_tab("chain"))
	tab_container.add_child(btn_tab_chain)

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
		"chain": btn_tab_chain,
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

	# Handle chain tab separately
	if _current_tab == "chain":
		var active_count: int = QuestJournal.get_active_count()
		status_label.text = "Active: %d" % active_count
		_refresh_chain_tab(pid)
		return

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
	status_label.text = "Active: %d" % active_count

	if filtered.is_empty():
		_add_empty_notice(target_cat)
	elif _current_tab == "side":
		# Group side quests by sub-category with headers
		var no_sub: Array = []
		var story: Array = []
		var bonus: Array = []
		var intel: Array = []
		for quest in filtered:
			match quest.get("sub_category", ""):
				"story": story.append(quest)
				"bonus": bonus.append(quest)
				"intel": intel.append(quest)
				_: no_sub.append(quest)
		# Original side quests (no sub-category)
		for quest in no_sub:
			_add_quest_card(quest)
		# Story sub-header
		if not story.is_empty():
			_add_sub_header("Story")
			for quest in story:
				_add_quest_card(quest)
		# Bonus sub-header
		if not bonus.is_empty():
			_add_sub_header("Bonus")
			for quest in bonus:
				_add_quest_card(quest)
		# Intel sub-header
		if not intel.is_empty():
			_add_sub_header("Intel")
			for quest in intel:
				_add_quest_card(quest)
	else:
		for quest in filtered:
			_add_quest_card(quest)


func _clear_content() -> void:
	for child in content_container.get_children():
		child.queue_free()


func _add_empty_notice(category: String) -> void:
	var names: Dictionary = {
		"main": "Main", "side": "Side", "challenge": "Challenge", "character": "Character"
	}
	var lbl := Label.new()
	lbl.text = "No %s quests" % names.get(category, "")
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(lbl)


func _add_sub_header(title: String) -> void:
	## Add a sub-category header label within the side quest tab.
	var sep := HSeparator.new()
	content_container.add_child(sep)
	var lbl := Label.new()
	lbl.text = "— %s —" % title
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.5))
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
		reward_lbl.text = "Reward: %s" % reward_preview
		reward_lbl.add_theme_font_size_override("font_size", 12)
		reward_lbl.add_theme_color_override("font_color", Color(0.6, 0.5, 0.3))
		vbox.add_child(reward_lbl)

	# Challenge battle button (for combat_pending status)
	if status == "combat_pending":
		var battle_btn := Button.new()
		battle_btn.text = "Start Challenge"
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
		"locked": return "[Locked]"
		"available": return "[Available]"
		"active": return "[Active]"
		"combat_pending": return "[Combat Ready]"
		"completed": return "[Completed]"
		"failed": return "[Failed]"
	return "[Unknown]"


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


# ═══════════════════════════════════════════════════════════════
#                    QUEST CHAIN TAB (v1.0)
# ═══════════════════════════════════════════════════════════════

func _refresh_chain_tab(pid: int) -> void:
	## 渲染任务链 Tab 的全部内容
	if not Engine.has_singleton("QuestChainManager"):
		_add_chain_unavailable_notice()
		return
	var all_chains: Array = QuestChainManager.get_all_chains_summary()
	if all_chains.is_empty():
		_add_empty_notice("chain")
		return
	# 分组：进行中 / 已完成 / 未激活
	var active_chains: Array = []
	var completed_chains: Array = []
	var locked_chains: Array = []
	for chain in all_chains:
		if chain.get("completed", false):
			completed_chains.append(chain)
		elif chain.get("active", false):
			active_chains.append(chain)
		else:
			locked_chains.append(chain)
	# 渲染进行中的链
	if not active_chains.is_empty():
		_add_chain_section_header("进行中的任务链", Color(1.0, 0.85, 0.3))
		for chain in active_chains:
			_add_chain_card(chain, pid)
	# 渲染已完成的链
	if not completed_chains.is_empty():
		_add_chain_section_header("已完成的任务链", Color(0.4, 0.9, 0.4))
		for chain in completed_chains:
			_add_chain_card(chain, pid)
	# 渲染未激活的链（仅显示名称和触发提示）
	if not locked_chains.is_empty():
		_add_chain_section_header("待触发的任务链", Color(0.5, 0.5, 0.5))
		for chain in locked_chains:
			_add_chain_locked_card(chain)
	# 渲染链内任务列表（活跃的链任务）
	var chain_quests: Array = QuestJournal.get_all_chain_quests(pid)
	if not chain_quests.is_empty():
		_add_chain_section_header("任务链子任务", Color(0.6, 0.8, 1.0))
		for cq in chain_quests:
			_add_quest_card(cq)


func _add_chain_unavailable_notice() -> void:
	var lbl := Label.new()
	lbl.text = "任务链系统未加载"
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_container.add_child(lbl)


func _add_chain_section_header(title: String, color: Color) -> void:
	var sep := HSeparator.new()
	content_container.add_child(sep)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 14)
	content_container.add_child(lbl)


func _add_chain_card(chain: Dictionary, pid: int) -> void:
	## 渲染一个任务链卡片（含节点进度图）
	var panel := PanelContainer.new()
	var sf := StyleBoxFlat.new()
	sf.bg_color = Color(0.12, 0.12, 0.18, 0.95)
	sf.border_color = Color(0.4, 0.6, 0.9, 0.7)
	sf.set_border_width_all(1)
	sf.set_corner_radius_all(6)
	sf.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sf)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# 标题行
	var title_row := HBoxContainer.new()
	vbox.add_child(title_row)
	var chain_icon := Label.new()
	chain_icon.text = "[链]"
	chain_icon.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	chain_icon.add_theme_font_size_override("font_size", 12)
	title_row.add_child(chain_icon)
	var name_lbl := Label.new()
	name_lbl.text = " " + chain.get("name", "")
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(name_lbl)
	# 完成状态标签
	if chain.get("completed", false):
		var done_lbl := Label.new()
		done_lbl.text = "已完成"
		done_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		done_lbl.add_theme_font_size_override("font_size", 12)
		title_row.add_child(done_lbl)

	# 描述
	var desc_lbl := Label.new()
	desc_lbl.text = chain.get("desc", "")
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_lbl)

	# 节点进度图
	var nodes: Array = chain.get("nodes", [])
	if not nodes.is_empty():
		var nodes_row := HBoxContainer.new()
		nodes_row.add_theme_constant_override("separation", 4)
		vbox.add_child(nodes_row)
		for node in nodes:
			var node_btn := _make_chain_node_badge(node)
			nodes_row.add_child(node_btn)

	# 分支选择按钮（如果有待处理的分支请求）
	var chain_id: String = chain.get("id", "")
	if Engine.has_singleton("QuestChainManager"):
		var pending = QuestChainManager._pending_branch_request
		if pending.get("chain_id", "") == chain_id:
			var branch_lbl := Label.new()
			branch_lbl.text = "请选择分支方向："
			branch_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
			branch_lbl.add_theme_font_size_override("font_size", 13)
			vbox.add_child(branch_lbl)
			# 从 nodes 中找出 AVAILABLE 状态的节点作为选项
			var branch_row := HBoxContainer.new()
			branch_row.add_theme_constant_override("separation", 8)
			vbox.add_child(branch_row)
			for node in nodes:
				var ns: int = node.get("status", 0)
				# NodeStatus.AVAILABLE = 1
				if ns == 1:
					var parent_node_id: String = pending.get("node_id", "")
					var node_id: String = node.get("id", "")
					var btn := Button.new()
					btn.text = node.get("name", node_id)
					btn.custom_minimum_size = Vector2(120, 30)
					btn.add_theme_font_size_override("font_size", 13)
					btn.pressed.connect(func():
						EventBus.quest_chain_branch_chosen.emit(chain_id, parent_node_id, node_id)
						_refresh()
					)
					branch_row.add_child(btn)

	content_container.add_child(panel)


func _make_chain_node_badge(node: Dictionary) -> PanelContainer:
	## 创建一个节点状态徽章
	var badge := PanelContainer.new()
	var sf := StyleBoxFlat.new()
	var status: int = node.get("status", 0)
	# 颜色映射: LOCKED=灰, AVAILABLE=蓝, ACTIVE=金, COMPLETED=绿, FAILED=红, SKIPPED=暗红
	var bg_colors: Array = [
		Color(0.2, 0.2, 0.2, 0.8),   # 0 LOCKED
		Color(0.1, 0.3, 0.6, 0.9),   # 1 AVAILABLE
		Color(0.5, 0.4, 0.0, 0.9),   # 2 ACTIVE
		Color(0.1, 0.45, 0.1, 0.9),  # 3 COMPLETED
		Color(0.5, 0.1, 0.1, 0.9),   # 4 FAILED
		Color(0.25, 0.1, 0.1, 0.8),  # 5 SKIPPED
	]
	var border_colors: Array = [
		Color(0.35, 0.35, 0.35),   # LOCKED
		Color(0.3, 0.6, 1.0),      # AVAILABLE
		Color(1.0, 0.85, 0.2),     # ACTIVE
		Color(0.3, 0.9, 0.3),      # COMPLETED
		Color(0.9, 0.2, 0.2),      # FAILED
		Color(0.5, 0.2, 0.2),      # SKIPPED
	]
	var safe_status: int = clampi(status, 0, bg_colors.size() - 1)
	sf.bg_color = bg_colors[safe_status]
	sf.border_color = border_colors[safe_status]
	sf.set_border_width_all(1)
	sf.set_corner_radius_all(4)
	sf.set_content_margin_all(4)
	badge.add_theme_stylebox_override("panel", sf)
	var lbl := Label.new()
	var node_type: String = node.get("type", "quest")
	var type_icons: Dictionary = {
		"quest": "Q", "event": "E", "gate": "G", "reward": "R"
	}
	var icon: String = type_icons.get(node_type, "?")
	var short_name: String = node.get("name", "")
	if short_name.length() > 6:
		short_name = short_name.substr(0, 5) + "…"
	lbl.text = "[%s] %s" % [icon, short_name]
	lbl.add_theme_font_size_override("font_size", 11)
	var font_colors: Array = [
		Color(0.5, 0.5, 0.5),   # LOCKED
		Color(0.6, 0.85, 1.0),  # AVAILABLE
		Color(1.0, 0.9, 0.3),   # ACTIVE
		Color(0.5, 1.0, 0.5),   # COMPLETED
		Color(1.0, 0.4, 0.4),   # FAILED
		Color(0.6, 0.3, 0.3),   # SKIPPED
	]
	lbl.add_theme_color_override("font_color", font_colors[safe_status])
	badge.add_child(lbl)
	# Tooltip
	var status_names: Array = ["锁定", "可用", "进行中", "已完成", "已失败", "已跳过"]
	badge.tooltip_text = "%s\n类型: %s\n状态: %s" % [
		node.get("name", ""),
		node_type,
		status_names[safe_status],
	]
	return badge


func _add_chain_locked_card(chain: Dictionary) -> void:
	## 渲染一个未激活的任务链（仅显示名称和类别）
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	var icon_lbl := Label.new()
	icon_lbl.text = "[?]"
	icon_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	icon_lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(icon_lbl)
	var name_lbl := Label.new()
	name_lbl.text = chain.get("name", "")
	name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)
	var cat_lbl := Label.new()
	var cat_map: Dictionary = {
		"side_chain": "支线链", "character_chain": "角色链",
		"faction_chain": "势力链", "crisis_chain": "危机链",
		"endgame_chain": "终局链",
	}
	cat_lbl.text = cat_map.get(chain.get("category", ""), "任务链")
	cat_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	cat_lbl.add_theme_font_size_override("font_size", 12)
	hbox.add_child(cat_lbl)
	content_container.add_child(hbox)
