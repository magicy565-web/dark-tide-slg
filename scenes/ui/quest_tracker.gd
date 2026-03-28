## quest_tracker.gd — On-screen quest progress widget (v1.0)
## Always-visible HUD showing 3-5 active quests in the top-right corner.
## Clicking a quest opens the Quest Journal panel.
extends CanvasLayer

const MAX_QUESTS: int = 5
const WIDGET_WIDTH: float = 250.0
const TOP_OFFSET: float = 70.0
const RIGHT_MARGIN: float = 10.0

# ── Priority color coding ──
const COLOR_MAIN := Color(1.0, 0.84, 0.3)      # gold for main quests
const COLOR_SIDE := Color(0.7, 0.85, 0.55)      # soft green for side
const COLOR_CHALLENGE := Color(0.6, 0.75, 1.0)  # blue for challenge
const COLOR_CHARACTER := Color(0.85, 0.6, 0.9)  # purple for character
const COLOR_DEFAULT := Color(0.8, 0.75, 0.6)    # muted gold default
const COLOR_DONE := Color(0.4, 0.9, 0.4)        # green checkmark
const COLOR_PENDING := Color(0.7, 0.65, 0.5)    # dim for incomplete

# ── State ──
var _expanded: bool = true

# ── UI refs ──
var root: Control
var bg_panel: PanelContainer
var header_row: HBoxContainer
var title_label: Label
var toggle_btn: Button
var quest_container: VBoxContainer
var _quest_buttons: Array = []


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 2
	_build_ui()
	_connect_signals()
	_refresh()


func _connect_signals() -> void:
	EventBus.quest_journal_updated.connect(_on_quest_updated)
	EventBus.turn_started.connect(_on_turn_started)


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "QuestTrackerRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	bg_panel = PanelContainer.new()
	bg_panel.anchor_left = 1.0
	bg_panel.anchor_right = 1.0
	bg_panel.offset_left = -(WIDGET_WIDTH + RIGHT_MARGIN)
	bg_panel.offset_right = -RIGHT_MARGIN
	bg_panel.offset_top = TOP_OFFSET
	bg_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.78)
	style.border_color = Color(0.45, 0.38, 0.2, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	bg_panel.add_theme_stylebox_override("panel", style)
	root.add_child(bg_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 4)
	bg_panel.add_child(outer_vbox)

	# ── Header row with title + toggle ──
	header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(header_row)

	title_label = Label.new()
	title_label.text = "任务追踪"
	title_label.add_theme_font_size_override("font_size", 14)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(title_label)

	toggle_btn = Button.new()
	toggle_btn.text = "—"
	toggle_btn.custom_minimum_size = Vector2(24, 24)
	toggle_btn.add_theme_font_size_override("font_size", 12)
	toggle_btn.pressed.connect(_on_toggle_pressed)
	header_row.add_child(toggle_btn)

	# ── Quest list container ──
	quest_container = VBoxContainer.new()
	quest_container.add_theme_constant_override("separation", 2)
	outer_vbox.add_child(quest_container)


# ═══════════════════════════════════════════════════════════════
#                       REFRESH / UPDATE
# ═══════════════════════════════════════════════════════════════

func _refresh() -> void:
	# Clear old entries
	for child in quest_container.get_children():
		child.queue_free()
	_quest_buttons.clear()

	if not _expanded:
		return

	if not GameManager.game_active:
		return

	var pid: int = GameManager.get_human_player_id()
	var quests: Array = QuestJournal.get_tracked_quests(pid)

	if quests.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "暂无活跃任务"
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		quest_container.add_child(empty_lbl)
		return

	var count: int = mini(quests.size(), MAX_QUESTS)
	for i in range(count):
		var q: Dictionary = quests[i]
		var entry := _build_quest_entry(q)
		quest_container.add_child(entry)


func _build_quest_entry(q: Dictionary) -> Control:
	var btn := Button.new()
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(WIDGET_WIDTH - 20, 0)

	# ── Style: flat transparent button ──
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.1, 0.08, 0.15, 0.4)
	style_normal.set_corner_radius_all(3)
	style_normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.15, 0.12, 0.22, 0.6)
	style_hover.set_corner_radius_all(3)
	style_hover.set_content_margin_all(4)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.2, 0.16, 0.28, 0.7)
	style_pressed.set_corner_radius_all(3)
	style_pressed.set_content_margin_all(4)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	# ── Build display text ──
	var category: String = q.get("category", "")
	var name_text: String = q.get("name", "???")
	if name_text.length() > 20:
		name_text = name_text.left(18) + ".."

	var progress_text: String = _get_progress_text(q)
	var color: Color = _get_category_color(category)

	btn.text = "[%s] %s  %s" % [category, name_text, progress_text]
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", color)

	btn.pressed.connect(_on_quest_clicked)
	_quest_buttons.append(btn)
	return btn


func _get_progress_text(q: Dictionary) -> String:
	var objectives: Array = q.get("objectives", [])
	if objectives.is_empty():
		return "进行中"
	var done_count: int = 0
	var total: int = objectives.size()
	for obj in objectives:
		if obj.get("done", false):
			done_count += 1
	if total == 1:
		return "完成" if done_count > 0 else "进行中"
	return "%d/%d" % [done_count, total]


func _get_category_color(category: String) -> Color:
	match category:
		"主线":
			return COLOR_MAIN
		"支线":
			return COLOR_SIDE
		"挑战":
			return COLOR_CHALLENGE
		"角色":
			return COLOR_CHARACTER
		_:
			return COLOR_DEFAULT


# ═══════════════════════════════════════════════════════════════
#                       SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_quest_updated() -> void:
	_refresh()


func _on_turn_started(_player_id: int) -> void:
	_refresh()


func _on_toggle_pressed() -> void:
	_expanded = not _expanded
	toggle_btn.text = "+" if not _expanded else "—"
	quest_container.visible = _expanded
	if _expanded:
		_refresh()


func _on_quest_clicked() -> void:
	# Find the quest_journal_panel via the main scene (main.gd stores it as a var)
	var tree := get_tree()
	if tree == null:
		return
	var main := tree.root.get_child(0) if tree.root.get_child_count() > 0 else null
	if main and "quest_journal_panel" in main and main.quest_journal_panel:
		main.quest_journal_panel.show_panel()
		return
	# Fallback: walk root children for anything with show_panel
	for child in tree.root.get_children():
		if child.has_method("show_panel") and "Journal" in child.name:
			child.show_panel()
			return
