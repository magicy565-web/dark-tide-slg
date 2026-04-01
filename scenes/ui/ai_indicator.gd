## ai_indicator.gd — AI turn indicator overlay.
## Shows what AI factions are doing during their turns.
## Pure code UI — no .tscn required.
extends Control

const FactionData = preload("res://systems/faction/faction_data.gd")

# ═══════════════════════════════════════════════════════════════
#                      CONSTANTS
# ═══════════════════════════════════════════════════════════════

const PANEL_WIDTH := 320
const PANEL_MIN_HEIGHT := 180
const PANEL_MARGIN_TOP := 52        # below resource bar
const PANEL_MARGIN_RIGHT := 12
const SLIDE_DURATION := 0.35
const FADE_DURATION := 0.25
const PULSE_DURATION := 1.2
const DOT_INTERVAL := 0.4
const MAX_LOG_ENTRIES := 5
const ACCENT_BORDER_WIDTH := 4

const ACTION_LABELS := {
	"attack": "进攻",
	"deploy": "部署",
	"recruit": "征募",
	"build": "建造",
	"research": "研究",
	"explore": "探索",
	"diplomacy": "外交",
	"defend": "防御",
}

const FACTION_DISPLAY_NAMES := {
	"orc": "兽人部落",
	"pirate": "暗黑海盗",
	"dark_elf": "黑暗精灵议会",
	"human": "光明人类王国",
	"high_elf": "精灵联邦",
	"mage": "法师协会",
	"neutral": "中立势力",
}

# ═══════════════════════════════════════════════════════════════
#                      STATE
# ═══════════════════════════════════════════════════════════════

var _canvas_layer: CanvasLayer
var _panel: PanelContainer
var _accent_bar: ColorRect
var _faction_label: Label
var _action_label: Label
var _progress_bar: ProgressBar
var _progress_label: Label
var _log_container: VBoxContainer
var _skip_button: Button

var _current_faction_key: String = ""
var _is_visible: bool = false
var _dot_count: int = 0
var _dot_timer: float = 0.0
var _is_thinking: bool = false
var _pulse_tween: Tween
var _action_log: Array[String] = []

# ═══════════════════════════════════════════════════════════════
#                      LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_panel.visible = false


func _process(delta: float) -> void:
	if not _is_visible or not _is_thinking:
		return
	_dot_timer += delta
	if _dot_timer >= DOT_INTERVAL:
		_dot_timer = 0.0
		_dot_count = (_dot_count + 1) % 4
		_update_dot_animation()


# ═══════════════════════════════════════════════════════════════
#                      UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# CanvasLayer so we render above most panels
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = UILayerRegistry.LAYER_AI_INDICATOR
	add_child(_canvas_layer)

	# Main panel container — anchored top-right
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_MIN_HEIGHT)
	_panel.add_theme_stylebox_override("panel", _build_panel_style())
	_canvas_layer.add_child(_panel)

	# We position the panel off-screen to the right initially
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = -PANEL_WIDTH - PANEL_MARGIN_RIGHT
	_panel.offset_right = -PANEL_MARGIN_RIGHT
	_panel.offset_top = PANEL_MARGIN_TOP
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	# Accent border on the left side
	_accent_bar = ColorRect.new()
	_accent_bar.custom_minimum_size = Vector2(ACCENT_BORDER_WIDTH, 0)
	_accent_bar.color = ColorTheme.ACCENT_GOLD

	# Inner layout: HBox with accent bar + VBox content
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_panel.add_child(hbox)

	hbox.add_child(_accent_bar)
	_accent_bar.size_flags_vertical = Control.SIZE_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	# Row 1: Faction name
	_faction_label = Label.new()
	_faction_label.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING)
	_faction_label.add_theme_color_override("font_color", ColorTheme.TEXT_TITLE)
	_faction_label.text = "AI 势力"
	vbox.add_child(_faction_label)

	# Row 2: Current action with animated dots
	_action_label = Label.new()
	_action_label.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	_action_label.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	_action_label.text = "等待中..."
	vbox.add_child(_action_label)

	# Row 3: Phase progress
	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 6)
	vbox.add_child(progress_row)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(160, 16)
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_apply_progress_bar_style()
	progress_row.add_child(_progress_bar)

	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	_progress_label.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	_progress_label.text = "阶段 0/0"
	progress_row.add_child(_progress_label)

	# Row 4: Separator
	var sep := HSeparator.new()
	sep.add_theme_stylebox_override("separator", _build_separator_style())
	vbox.add_child(sep)

	# Row 5: Action log (scrollable)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 80)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_log_container = VBoxContainer.new()
	_log_container.add_theme_constant_override("separation", 2)
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_log_container)

	# Row 6: Skip button
	_skip_button = Button.new()
	_skip_button.text = "跳过动画 ▶▶"
	_skip_button.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	_skip_button.add_theme_color_override("font_color", ColorTheme.BTN_TEXT)
	_apply_skip_button_style()
	_skip_button.pressed.connect(_on_skip_pressed)
	vbox.add_child(_skip_button)
	ColorTheme.setup_button_hover(_skip_button)


func _build_panel_style() -> StyleBoxFlat:
	return ColorTheme.make_panel_style(
		ColorTheme.BG_DARK,
		ColorTheme.BORDER_DIM,
		1,
		6,
		10
	)


func _apply_progress_bar_style() -> void:
	# Background style
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	bg.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("background", bg)
	# Fill style
	var fill := StyleBoxFlat.new()
	fill.bg_color = ColorTheme.ACCENT_GOLD
	fill.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("fill", fill)


func _apply_skip_button_style() -> void:
	var normal := ColorTheme.make_button_style_flat("normal")
	var hover := ColorTheme.make_button_style_flat("hover")
	var pressed := ColorTheme.make_button_style_flat("pressed")
	_skip_button.add_theme_stylebox_override("normal", normal)
	_skip_button.add_theme_stylebox_override("hover", hover)
	_skip_button.add_theme_stylebox_override("pressed", pressed)


func _build_separator_style() -> StyleBoxFlat:
	var sf := StyleBoxFlat.new()
	sf.bg_color = ColorTheme.BORDER_DIM
	sf.set_content_margin_all(0)
	sf.content_margin_top = 1
	sf.content_margin_bottom = 1
	return sf

# ═══════════════════════════════════════════════════════════════
#                      SIGNAL CONNECTIONS
# ═══════════════════════════════════════════════════════════════

func _connect_signals() -> void:
	if not EventBus:
		push_warning("AIIndicator: EventBus not found")
		return
	EventBus.ai_action_started.connect(_on_ai_action_started)
	EventBus.ai_action_completed.connect(_on_ai_action_completed)
	EventBus.ai_turn_progress.connect(_on_ai_turn_progress)
	EventBus.ai_thinking.connect(_on_ai_thinking)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.turn_ended.connect(_on_turn_ended)
	if EventBus.has_signal("phase_banner_requested"):
		EventBus.phase_banner_requested.connect(_on_phase_banner_requested)

# ═══════════════════════════════════════════════════════════════
#                      EVENT HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_turn_started(player_id: int) -> void:
	if not GameManager:
		return
	var human_id: int = GameManager.get_human_player_id()
	if player_id == human_id:
		# Human turn — hide indicator
		if _is_visible:
			_slide_out()
		return
	# AI turn — determine faction and show
	var faction_key := _get_faction_key_for_player(player_id)
	_current_faction_key = faction_key
	_reset_state()
	_update_faction_display(faction_key)
	_slide_in()


func _on_turn_ended(player_id: int) -> void:
	if _is_visible:
		_slide_out()


func _on_ai_action_started(faction_key: String, action_type: String, detail: String) -> void:
	if not _is_visible:
		return
	var action_name: String = ACTION_LABELS.get(action_type, action_type)
	var display_text: String = action_name
	if detail != "":
		display_text += " — " + detail
	_action_label.text = display_text
	_is_thinking = true
	_dot_count = 0
	_dot_timer = 0.0
	_start_pulse()


func _on_ai_action_completed(faction_key: String, action_type: String, success: bool) -> void:
	if not _is_visible:
		return
	_is_thinking = false
	_stop_pulse()
	# Build log entry
	var action_name: String = ACTION_LABELS.get(action_type, action_type)
	var result_marker: String = "✓" if success else "✗"
	var result_color: Color = ColorTheme.TEXT_SUCCESS if success else ColorTheme.TEXT_RED
	_add_log_entry(result_marker + " " + action_name, result_color)


func _on_ai_turn_progress(faction_key: String, phase: int, total_phases: int) -> void:
	if not _is_visible:
		return
	if total_phases > 0:
		_progress_bar.value = float(phase) / float(total_phases)
	else:
		_progress_bar.value = 0.0
	_progress_label.text = "阶段 %d/%d" % [phase, total_phases]


func _on_ai_thinking(faction_key: String, is_thinking: bool) -> void:
	_is_thinking = is_thinking
	if is_thinking:
		_dot_count = 0
		_dot_timer = 0.0
		_start_pulse()
	else:
		_stop_pulse()


func _on_phase_banner_requested(text: String, is_ai_turn: bool) -> void:
	# When a phase banner is shown during AI turn, briefly dim our panel
	# so it doesn't compete visually
	if _is_visible and is_ai_turn:
		var tw := _panel.create_tween()
		tw.tween_property(_panel, "modulate:a", 0.4, 0.15)
		tw.tween_interval(1.5)
		tw.tween_property(_panel, "modulate:a", 1.0, 0.25)


func _on_skip_pressed() -> void:
	if EventBus and EventBus.has_signal("ai_skip_animations_requested"):
		EventBus.ai_skip_animations_requested.emit()

# ═══════════════════════════════════════════════════════════════
#                      SHOW / HIDE ANIMATIONS
# ═══════════════════════════════════════════════════════════════

func _slide_in() -> void:
	_panel.visible = true
	_is_visible = true
	# Start off-screen to the right
	_panel.offset_left = PANEL_MARGIN_RIGHT
	_panel.offset_right = PANEL_WIDTH + PANEL_MARGIN_RIGHT
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)

	var target_left := -PANEL_WIDTH - PANEL_MARGIN_RIGHT
	var target_right := -PANEL_MARGIN_RIGHT

	var tw := _panel.create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_panel, "offset_left", target_left, SLIDE_DURATION)
	tw.tween_property(_panel, "offset_right", target_right, SLIDE_DURATION)
	tw.tween_property(_panel, "modulate:a", 1.0, FADE_DURATION)


func _slide_out() -> void:
	_is_thinking = false
	_stop_pulse()

	var offscreen_left := PANEL_MARGIN_RIGHT
	var offscreen_right := PANEL_WIDTH + PANEL_MARGIN_RIGHT

	var tw := _panel.create_tween()
	tw.set_parallel(true)
	tw.set_ease(Tween.EASE_IN)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_panel, "offset_left", offscreen_left, SLIDE_DURATION)
	tw.tween_property(_panel, "offset_right", offscreen_right, SLIDE_DURATION)
	tw.tween_property(_panel, "modulate:a", 0.0, FADE_DURATION)
	tw.chain().tween_callback(_on_slide_out_finished)


func _on_slide_out_finished() -> void:
	_panel.visible = false
	_is_visible = false

# ═══════════════════════════════════════════════════════════════
#                      INTERNAL HELPERS
# ═══════════════════════════════════════════════════════════════

func _reset_state() -> void:
	_action_log.clear()
	_dot_count = 0
	_dot_timer = 0.0
	_is_thinking = false
	_progress_bar.value = 0.0
	_progress_label.text = "阶段 0/0"
	_action_label.text = "准备中..."
	# Clear log entries
	for child in _log_container.get_children():
		child.queue_free()


func _update_faction_display(faction_key: String) -> void:
	var display_name := _get_faction_display_name(faction_key)
	var faction_color := ColorTheme.get_faction_color(faction_key)
	_faction_label.text = "⚔ " + display_name
	_faction_label.add_theme_color_override("font_color", faction_color)
	_accent_bar.color = faction_color
	# Tint progress bar fill with faction color
	var fill := StyleBoxFlat.new()
	fill.bg_color = faction_color
	fill.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("fill", fill)


func _update_dot_animation() -> void:
	var base_text: String = _action_label.text.rstrip(".")
	_action_label.text = base_text + ".".repeat(_dot_count)


func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = _faction_label.create_tween()
	_pulse_tween.set_loops()
	var faction_color := ColorTheme.get_faction_color(_current_faction_key)
	var bright := faction_color.lightened(0.4)
	_pulse_tween.tween_property(_faction_label, "modulate", Color(bright.r, bright.g, bright.b, 1.0), PULSE_DURATION * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_faction_label, "modulate", Color.WHITE, PULSE_DURATION * 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	if is_instance_valid(_faction_label):
		_faction_label.modulate = Color.WHITE


func _add_log_entry(text: String, color: Color = ColorTheme.TEXT_DIM) -> void:
	_action_log.append(text)
	# Trim to max entries
	while _action_log.size() > MAX_LOG_ENTRIES:
		_action_log.pop_front()
		if _log_container.get_child_count() > 0:
			_log_container.get_child(0).queue_free()

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", ColorTheme.FONT_SMALL)
	lbl.add_theme_color_override("font_color", color)
	lbl.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_log_container.add_child(lbl)

	# Fade in new entry
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.2)

	# Apply fading to older entries (more transparent the older they are)
	_apply_log_fade()


func _apply_log_fade() -> void:
	var count := _log_container.get_child_count()
	for i in range(count):
		var child: Control = _log_container.get_child(i)
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		# Newest entry = full opacity, oldest = 0.35
		var age_ratio: float = float(count - 1 - i) / max(float(count - 1), 1.0)
		var target_alpha: float = lerpf(1.0, 0.35, age_ratio)
		var tw := child.create_tween()
		tw.tween_property(child, "modulate:a", target_alpha, 0.15)


func _get_faction_display_name(faction_key: String) -> String:
	if FACTION_DISPLAY_NAMES.has(faction_key):
		return FACTION_DISPLAY_NAMES[faction_key]
	# Try stripping _ai suffix (e.g. "orc_ai" -> "orc")
	var base_key := faction_key.replace("_ai", "")
	if FACTION_DISPLAY_NAMES.has(base_key):
		return FACTION_DISPLAY_NAMES[base_key]
	return faction_key.capitalize()


func _get_faction_key_for_player(player_id: int) -> String:
	if not GameManager:
		return "neutral"
	var faction_id: int = GameManager.get_player_faction(player_id)
	match faction_id:
		FactionData.FactionID.ORC:
			return "orc"
		FactionData.FactionID.PIRATE:
			return "pirate"
		FactionData.FactionID.DARK_ELF:
			return "dark_elf"
		_:
			return "neutral"
