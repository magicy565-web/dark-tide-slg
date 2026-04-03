## story_dialog.gd - Visual-novel style dialogue UI for story events (v2.0)
## Displays scene descriptions, character dialogues, H-events, choices, and system prompts.
## Supports fullscreen CG backgrounds, character portrait display with expression switching.
## Integrates with StoryEventSystem and CGManager for progression & CG tracking.
extends CanvasLayer

const FactionData = preload("res://systems/faction/faction_data.gd")

# ── State ──
var _visible: bool = false
var _current_hero_id: String = ""
var _current_event: Dictionary = {}
var _dialogue_queue: Array = []        # Array of dialogue entries to display sequentially
var _current_dialogue_index: int = -1
var _waiting_for_choice: bool = false
var _showing_h_event: bool = false
var _text_revealing: bool = false       # True while text is being revealed char-by-char
var _is_branch_choice: bool = false     # True when showing a story branch choice (vs inline dialogue choice)

# ── CG / Portrait state ──
var _current_cg_id: String = ""        # Currently displayed CG ID (empty = no CG)
var _current_portrait_hero: String = "" # Hero ID of currently displayed portrait
var _current_expression: String = ""    # Current expression variant

# ── Text reveal settings ──
const CHARS_PER_SECOND: float = 40.0
var _reveal_timer: float = 0.0
var _reveal_target: String = ""
var _reveal_current: int = 0

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var cg_layer: TextureRect              # Fullscreen CG background layer
var portrait_container: Control        # Container for character portrait display (LEFT)
var portrait_sprite: TextureRect       # Character portrait/head image (LEFT)
var portrait_name_label: Label         # Small name label under portrait (LEFT)
var right_portrait_container: Control  # Container for RIGHT character portrait
var right_portrait_sprite: TextureRect # Character portrait/head image (RIGHT)
var right_portrait_name_label: Label   # Small name label under portrait (RIGHT)
var dialog_panel: PanelContainer
var speaker_label: Label
var text_label: RichTextLabel
var scene_label: RichTextLabel          # Scene description area
var scene_panel: PanelContainer         # Scene description panel (for visibility toggling)
var choice_container: VBoxContainer
var btn_next: Button
var btn_skip: Button
var system_prompt_label: Label
var progress_label: Label               # "Event 3/10" counter

# ── Animation ──
var _tween: Tween = null
var _cg_tween: Tween = null
var _portrait_tween: Tween = null


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_STORY_DIALOG
	_build_ui()
	_connect_signals()
	hide_dialog()


func _process(delta: float) -> void:
	if _text_revealing:
		_reveal_timer += delta * CHARS_PER_SECOND
		var chars_to_show: int = int(_reveal_timer)
		if chars_to_show > _reveal_current:
			_reveal_current = mini(chars_to_show, _reveal_target.length())
			text_label.visible_characters = _reveal_current
			if _reveal_current >= _reveal_target.length():
				_text_revealing = false
				text_label.visible_characters = -1
				btn_next.visible = true


func _connect_signals() -> void:
	if EventBus.has_signal("story_event_triggered"):
		EventBus.story_event_triggered.connect(_on_story_event_triggered)
	if EventBus.has_signal("story_choice_requested"):
		EventBus.story_choice_requested.connect(_on_story_choice_requested)


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "StoryDialogRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dimming background (lowest layer)
	dim_bg = ColorRect.new()
	dim_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.75)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim_bg)

	# ── Fullscreen CG layer (behind all UI, above dim_bg) ──
	cg_layer = TextureRect.new()
	cg_layer.name = "CGLayer"
	cg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	cg_layer.offset_left = 0; cg_layer.offset_right = 0
	cg_layer.offset_top = 0; cg_layer.offset_bottom = 0
	cg_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cg_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cg_layer.visible = false
	cg_layer.modulate = Color(1, 1, 1, 1)
	root.add_child(cg_layer)

	# ── Character portrait container (left side, above CG, below dialog) ──
	portrait_container = Control.new()
	portrait_container.name = "PortraitContainer"
	# Position: left side of screen, vertically centered between scene_panel and dialog_panel
	portrait_container.anchor_left = 0.02
	portrait_container.anchor_right = 0.22
	portrait_container.anchor_top = 0.20
	portrait_container.anchor_bottom = 0.65
	portrait_container.offset_left = 0; portrait_container.offset_right = 0
	portrait_container.offset_top = 0; portrait_container.offset_bottom = 0
	portrait_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_container.visible = false
	root.add_child(portrait_container)

	portrait_sprite = TextureRect.new()
	portrait_sprite.name = "PortraitSprite"
	portrait_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_sprite.offset_left = 0; portrait_sprite.offset_right = 0
	portrait_sprite.offset_top = 0; portrait_sprite.offset_bottom = -24
	portrait_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_container.add_child(portrait_sprite)

	portrait_name_label = Label.new()
	portrait_name_label.name = "PortraitName"
	portrait_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_name_label.anchor_left = 0.0; portrait_name_label.anchor_right = 1.0
	portrait_name_label.anchor_top = 1.0; portrait_name_label.anchor_bottom = 1.0
	portrait_name_label.offset_top = -22; portrait_name_label.offset_bottom = 0
	portrait_name_label.offset_left = 0; portrait_name_label.offset_right = 0
	portrait_name_label.add_theme_font_size_override("font_size", 12)
	portrait_name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	portrait_container.add_child(portrait_name_label)

	# ── RIGHT character portrait container (right side, mirrored) ──
	right_portrait_container = Control.new()
	right_portrait_container.name = "RightPortraitContainer"
	right_portrait_container.anchor_left = 0.78
	right_portrait_container.anchor_right = 0.98
	right_portrait_container.anchor_top = 0.20
	right_portrait_container.anchor_bottom = 0.65
	right_portrait_container.offset_left = 0; right_portrait_container.offset_right = 0
	right_portrait_container.offset_top = 0; right_portrait_container.offset_bottom = 0
	right_portrait_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_portrait_container.visible = false
	root.add_child(right_portrait_container)

	right_portrait_sprite = TextureRect.new()
	right_portrait_sprite.name = "RightPortraitSprite"
	right_portrait_sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_portrait_sprite.offset_left = 0; right_portrait_sprite.offset_right = 0
	right_portrait_sprite.offset_top = 0; right_portrait_sprite.offset_bottom = -24
	right_portrait_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right_portrait_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	right_portrait_sprite.flip_h = true  # Mirror horizontally for right side
	right_portrait_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_portrait_container.add_child(right_portrait_sprite)

	right_portrait_name_label = Label.new()
	right_portrait_name_label.name = "RightPortraitName"
	right_portrait_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_portrait_name_label.anchor_left = 0.0; right_portrait_name_label.anchor_right = 1.0
	right_portrait_name_label.anchor_top = 1.0; right_portrait_name_label.anchor_bottom = 1.0
	right_portrait_name_label.offset_top = -22; right_portrait_name_label.offset_bottom = 0
	right_portrait_name_label.offset_left = 0; right_portrait_name_label.offset_right = 0
	right_portrait_name_label.add_theme_font_size_override("font_size", 12)
	right_portrait_name_label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	right_portrait_container.add_child(right_portrait_name_label)

	# ── Scene description area (top) ──
	scene_panel = PanelContainer.new()
	scene_panel.anchor_left = 0.1
	scene_panel.anchor_right = 0.9
	scene_panel.anchor_top = 0.02
	scene_panel.anchor_bottom = 0.25
	scene_panel.offset_left = 0; scene_panel.offset_right = 0
	scene_panel.offset_top = 0; scene_panel.offset_bottom = 0
	var scene_style := StyleBoxFlat.new()
	scene_style.bg_color = ColorTheme.BG_DARK
	scene_style.border_color = ColorTheme.BORDER_DIM
	scene_style.set_border_width_all(1)
	scene_style.set_corner_radius_all(6)
	scene_style.set_content_margin_all(14)
	scene_panel.add_theme_stylebox_override("panel", scene_style)
	root.add_child(scene_panel)

	var scene_scroll := ScrollContainer.new()
	scene_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene_panel.add_child(scene_scroll)

	scene_label = RichTextLabel.new()
	scene_label.bbcode_enabled = true
	scene_label.fit_content = true
	scene_label.scroll_active = false
	scene_label.add_theme_font_size_override("normal_font_size", 13)
	scene_label.add_theme_font_size_override("italics_font_size", 13)
	scene_label.add_theme_color_override("default_color", Color(0.75, 0.72, 0.80))
	scene_scroll.add_child(scene_label)

	# ── Main dialog panel (bottom) ──
	dialog_panel = PanelContainer.new()
	dialog_panel.anchor_left = 0.05
	dialog_panel.anchor_right = 0.95
	dialog_panel.anchor_top = 0.62
	dialog_panel.anchor_bottom = 0.95
	dialog_panel.offset_left = 0; dialog_panel.offset_right = 0
	dialog_panel.offset_top = 0; dialog_panel.offset_bottom = 0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = ColorTheme.BG_PRIMARY
	panel_style.border_color = ColorTheme.ACCENT_GOLD
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(16)
	dialog_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(dialog_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	dialog_panel.add_child(vbox)

	# Speaker name
	speaker_label = Label.new()
	speaker_label.text = ""
	speaker_label.add_theme_font_size_override("font_size", 18)
	speaker_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	vbox.add_child(speaker_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Dialogue text
	var text_scroll := ScrollContainer.new()
	text_scroll.custom_minimum_size = Vector2(0, 120)
	text_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(text_scroll)

	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.add_theme_font_size_override("normal_font_size", 15)
	text_label.add_theme_color_override("default_color", Color(0.92, 0.90, 0.95))
	text_scroll.add_child(text_label)

	# Choice container (hidden unless choices present)
	choice_container = VBoxContainer.new()
	choice_container.add_theme_constant_override("separation", 6)
	choice_container.visible = false
	vbox.add_child(choice_container)

	# System prompt (small text at bottom)
	system_prompt_label = Label.new()
	system_prompt_label.text = ""
	system_prompt_label.add_theme_font_size_override("font_size", 11)
	system_prompt_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9, 0.8))
	system_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	system_prompt_label.visible = false
	vbox.add_child(system_prompt_label)

	# ── Button row (bottom-right) ──
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	# Progress label (Sengoku Rance style: shows hero name + chapter progress)
	progress_label = Label.new()
	progress_label.text = ""
	progress_label.add_theme_font_size_override("font_size", 12)
	progress_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))  # Gold tint
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_row.add_child(progress_label)

	btn_skip = Button.new()
	btn_skip.text = "跳过"
	btn_skip.custom_minimum_size = Vector2(70, 32)
	btn_skip.add_theme_font_size_override("font_size", 12)
	btn_skip.pressed.connect(_on_skip)
	btn_row.add_child(btn_skip)

	btn_next = Button.new()
	btn_next.text = "下一步 ▶"
	btn_next.custom_minimum_size = Vector2(90, 32)
	btn_next.add_theme_font_size_override("font_size", 13)
	btn_next.pressed.connect(_on_next)
	btn_row.add_child(btn_next)


# ═══════════════════════════════════════════════════════════════
#                       PUBLIC API
# ═══════════════════════════════════════════════════════════════

## Start displaying a story event.
func show_story_event(hero_id: String, event: Dictionary) -> void:
	_current_hero_id = hero_id
	_current_event = event
	_showing_h_event = false
	_waiting_for_choice = false

	# Build dialogue queue from event data
	_build_dialogue_queue(event)

	# Show scene description
	var scene_text: String = event.get("scene", "")
	scene_label.clear()
	if scene_text != "":
		scene_label.append_text("[i]%s[/i]" % scene_text)

	# ── CG: check for event-level CG background ──
	var event_cg: String = event.get("cg", "")
	if event_cg != "":
		_show_cg(hero_id, event_cg)
		# When CG is active, hide scene description panel (CG replaces it)
		scene_panel.visible = false
	else:
		_hide_cg()
		scene_panel.visible = scene_text != ""

	# ── Portrait: show the event's hero portrait with default expression ──
	_show_portrait(hero_id, "")

	# ── VN Director: mood-based BGM switching ──
	var event_mood: String = event.get("mood", "")
	if event_mood != "" and is_instance_valid(VnDirector):
		VnDirector.switch_mood(event_mood)

	# ── VN Director: dual portrait scene setup ──
	var right_hero: String = event.get("right_hero", "")
	if right_hero != "" and is_instance_valid(VnDirector):
		VnDirector.setup_scene(hero_id, right_hero, event_mood)
		_show_right_portrait(right_hero, "")

	# Show progress (Sengoku Rance style: 「英雄名 · 路线 第3章/7」)
	var route: String = StoryEventSystem.get_route(hero_id)
	var events: Array = StoryEventSystem.get_route_events(hero_id, route)
	var prog: Dictionary = StoryEventSystem.get_progress(hero_id)
	var idx: int = prog.get("current_event", 0)
	const ROUTE_DISPLAY: Dictionary = {
		"training": "训练路线",
		"pure_love": "纯爱路线",
		"friendly": "友好路线",
		"neutral": "中立路线",
		"hostile": "对抗路线",
	}
	var route_display: String = ROUTE_DISPLAY.get(route, route)
	progress_label.text = "%s · %s — 第%d章 / 共%d章" % [
		_get_hero_name(hero_id),
		route_display,
		idx + 1,
		events.size()
	]

	# Start from first dialogue entry
	_current_dialogue_index = -1
	_show_animated()
	_advance_dialogue()


func hide_dialog() -> void:
	_visible = false
	root.visible = false
	_text_revealing = false
	_dialogue_queue.clear()
	# Reset CG/portrait state
	_hide_cg()
	_hide_portrait()
	_hide_right_portrait()
	_current_cg_id = ""
	_current_portrait_hero = ""
	_current_expression = ""
	# Cleanup VnDirector state
	if is_instance_valid(VnDirector):
		VnDirector.cleanup()


# ═══════════════════════════════════════════════════════════════
#                    DIALOGUE QUEUE MANAGEMENT
# ═══════════════════════════════════════════════════════════════

func _build_dialogue_queue(event: Dictionary) -> void:
	_dialogue_queue.clear()
	# Main dialogues
	var dialogues: Array = event.get("dialogues", [])
	for d in dialogues:
		_dialogue_queue.append(d)
	# Branch-point choices (story branching system) — inserted after main dialogues
	var choices: Array = event.get("choices", [])
	if not choices.is_empty():
		_dialogue_queue.append({
			"type": "branch_choice",
			"prompt": event.get("choice_prompt", ""),
			"choices": choices,
		})
	# H-event dialogues (appended after main)
	var h_event: Dictionary = event.get("h_event", {})
	if not h_event.is_empty():
		# Add H-event marker (with optional CG)
		var h_start_entry: Dictionary = {"type": "h_event_start", "title": h_event.get("title", "")}
		var h_cg: String = h_event.get("cg", "")
		if h_cg != "":
			h_start_entry["cg"] = h_cg
		_dialogue_queue.append(h_start_entry)
		var h_dialogues: Array = h_event.get("dialogues", [])
		for d in h_dialogues:
			_dialogue_queue.append(d)
	# System prompt at the end
	var sys_prompt: String = event.get("system_prompt", "")
	if sys_prompt != "":
		_dialogue_queue.append({"type": "system_prompt", "text": sys_prompt})


func _advance_dialogue() -> void:
	_current_dialogue_index += 1
	if _current_dialogue_index >= _dialogue_queue.size():
		_finish_event()
		return

	var entry: Dictionary = _dialogue_queue[_current_dialogue_index]
	var entry_type: String = entry.get("type", "dialogue")

	choice_container.visible = false
	system_prompt_label.visible = false

	# ── Per-dialogue CG switch (any dialogue entry can change the CG) ──
	var d_cg: String = entry.get("cg", "")
	if d_cg != "":
		_show_cg(_current_hero_id, d_cg)
		scene_panel.visible = false
	elif entry.get("clear_cg", false):
		_hide_cg()
		scene_panel.visible = true

	# ── Per-dialogue expression switch ──
	var d_expr: String = entry.get("expression", "")

	match entry_type:
		"narration":
			speaker_label.text = ""
			# Narration: dim the portrait slightly
			_dim_portrait(true)
			_start_text_reveal(entry.get("text", ""))
		"action":
			speaker_label.text = ""
			_dim_portrait(true)
			_start_text_reveal("[color=#8888aa]%s[/color]" % entry.get("text", ""))
		"dialogue":
			var speaker_id: String = entry.get("speaker_id", "")
			speaker_label.text = entry.get("speaker", "")
			# ── Speaker position support (left/right portrait) ──
			var speaker_pos: String = entry.get("speaker_position", "")
			if speaker_pos == "right":
				if speaker_id != "":
					_show_right_portrait(speaker_id, d_expr)
				_dim_portrait(true)
				_dim_right_portrait(false)
				if is_instance_valid(VnDirector):
					VnDirector.set_speaker(VnDirector.PortraitSlot.RIGHT)
			elif speaker_pos == "left" or speaker_id != "":
				# Default: left side
				if speaker_id != "":
					_show_portrait(speaker_id, d_expr)
				elif d_expr != "":
					_update_expression(d_expr)
				_dim_portrait(false)
				_dim_right_portrait(true)
				if is_instance_valid(VnDirector):
					VnDirector.set_speaker(VnDirector.PortraitSlot.LEFT)
			else:
				# No position specified, no speaker_id — use expression on current
				if d_expr != "":
					_update_expression(d_expr)
				_dim_portrait(false)
			# ── Per-dialogue screen effect ──
			var d_effect: String = entry.get("effect", "")
			if d_effect != "" and is_instance_valid(VnDirector):
				var effect_duration: float = entry.get("effect_duration", 0.3)
				VnDirector.play_effect_by_name(d_effect, effect_duration)
			var action: String = entry.get("action", "")
			var text: String = entry.get("text", "")
			if action != "":
				text = "[color=#8888aa]%s[/color]\n%s" % [action, text]
			_start_text_reveal(text)
		"choice":
			speaker_label.text = "Choice"
			text_label.text = entry.get("prompt", "Choose:")
			_show_choices(entry.get("options", []))
			btn_next.visible = false
			_waiting_for_choice = true
		"branch_choice":
			_show_branch_choices(entry.get("choices", []))
		"h_event_start":
			_showing_h_event = true
			speaker_label.text = ""
			var title: String = entry.get("title", "")
			# H-event may have its own CG
			var h_cg: String = entry.get("cg", "")
			if h_cg != "":
				_show_cg(_current_hero_id, h_cg)
				scene_panel.visible = false
			_start_text_reveal("[color=#ff6688]◆ %s ◆[/color]" % title if title != "" else "[color=#ff6688]◆ ◆[/color]")
		"system_prompt":
			speaker_label.text = "System"
			system_prompt_label.text = entry.get("text", "")
			system_prompt_label.visible = true
			text_label.clear()
			btn_next.visible = true


func _start_text_reveal(full_text: String) -> void:
	_reveal_target = full_text
	_reveal_current = 0
	_reveal_timer = 0.0
	_text_revealing = true
	text_label.clear()
	text_label.append_text(full_text)
	text_label.visible_characters = 0
	btn_next.visible = false  # Hidden until reveal completes


func _finish_text_reveal() -> void:
	_text_revealing = false
	text_label.visible_characters = -1
	btn_next.visible = true


# ═══════════════════════════════════════════════════════════════
#                       CHOICES
# ═══════════════════════════════════════════════════════════════

func _show_choices(options: Array) -> void:
	_clear_choices()
	choice_container.visible = true
	for i in range(options.size()):
		var opt: Dictionary = options[i] if options[i] is Dictionary else {"text": str(options[i])}
		var btn := Button.new()
		btn.text = opt.get("text", "Option %d" % (i + 1))
		btn.custom_minimum_size = Vector2(400, 36)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_choice_selected.bind(i))
		choice_container.add_child(btn)


func _clear_choices() -> void:
	for child in choice_container.get_children():
		child.queue_free()


func _on_choice_selected(index: int) -> void:
	_waiting_for_choice = false
	choice_container.visible = false
	var event_id: String = _current_event.get("id", "")
	# If this is a branch-point choice (event has "choices" array), resolve via StoryEventSystem.
	# IMPORTANT: resolve_story_choice() already calls complete_current_event() internally.
	# We must NOT call _advance_dialogue() -> _finish_event() -> complete_current_event() again,
	# as that would double-advance the story progress (skip one event).
	# Instead: unlock CGs and close the dialog directly.
	if _is_branch_choice:
		_is_branch_choice = false
		_unlock_event_cgs(_current_hero_id, _current_event)
		StoryEventSystem.resolve_story_choice(_current_hero_id, event_id, index)
		_hide_animated()
	else:
		EventBus.story_choice_made.emit(_current_hero_id, event_id, index)
		_advance_dialogue()


# ═══════════════════════════════════════════════════════════════
#                       EVENT COMPLETION
# ═══════════════════════════════════════════════════════════════

func _finish_event() -> void:
	# Unlock any CGs that were displayed during this event
	_unlock_event_cgs(_current_hero_id, _current_event)
	# Mark event completed in story system
	StoryEventSystem.complete_current_event(_current_hero_id)
	_hide_animated()


# ═══════════════════════════════════════════════════════════════
#                       SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_story_event_triggered(hero_id: String, event: Dictionary) -> void:
	show_story_event(hero_id, event)


func _on_next() -> void:
	if _text_revealing:
		_finish_text_reveal()
	elif not _waiting_for_choice:
		_advance_dialogue()


func _on_skip() -> void:
	# Skip to end of current event.
	# If a branch choice is pending, we must clear it from StoryEventSystem before completing.
	if _is_branch_choice:
		_is_branch_choice = false
		_waiting_for_choice = false
		var event_id: String = _current_event.get("id", "")
		# Erase pending choice so complete_current_event works correctly
		StoryEventSystem._pending_choices.erase(_current_hero_id)
	_finish_event()


## Handle story_choice_requested signal — show branch-point choices with consequence hints.
## This is called when StoryEventSystem detects an event with a "choices" array.
func _on_story_choice_requested(hero_id: String, _event_id: String, choices: Array) -> void:
	if not _visible:
		# If dialog isn't open yet, the story_event_triggered signal will open it.
		# We just need to inject the branch choices into the dialogue queue.
		return
	if hero_id != _current_hero_id:
		return
	# Show the branch choices in the existing dialog
	_show_branch_choices(choices)


## Display branch-point choices with rich consequence hints.
## Unlike inline dialogue choices, these have lasting gameplay effects shown to the player.
func _show_branch_choices(choices: Array) -> void:
	_clear_choices()
	_is_branch_choice = true
	_waiting_for_choice = true
	choice_container.visible = true
	btn_next.visible = false

	speaker_label.text = "命运的抉择"
	text_label.clear()
	text_label.visible_characters = -1
	_text_revealing = false

	# Build prompt from event context
	var prompt_text: String = _current_event.get("choice_prompt", "你的选择将改变这段关系的走向。")
	text_label.append_text("[color=#ffcc88]%s[/color]" % prompt_text)

	for i in range(choices.size()):
		var choice: Dictionary = choices[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(500, 0)
		btn.add_theme_font_size_override("font_size", 13)

		# Build rich choice text: support both "label" (story data format) and "text" (legacy format)
		var choice_text: String = choice.get("label", choice.get("text", "选项 %d" % (i + 1)))
		# Append description as consequence hint if present
		var hint: String = choice.get("hint", "")
		var consequence: String = choice.get("consequence", choice.get("description", ""))

		if hint != "":
			choice_text += "  [%s]" % hint
		if consequence != "":
			choice_text += "\n    → %s" % consequence

		btn.text = choice_text
		# Color code by choice tone if available
		var tone: String = choice.get("tone", "")
		match tone:
			"kind", "gentle", "pure":
				btn.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
			"dark", "cruel", "dominate":
				btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
			"pragmatic", "neutral":
				btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
			_:
				btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

		btn.pressed.connect(_on_choice_selected.bind(i))
		choice_container.add_child(btn)

	# Show a system hint about permanence
	system_prompt_label.text = "⚠ 此选择不可撤回，将影响后续剧情走向和战斗能力。"
	system_prompt_label.visible = true


# ═══════════════════════════════════════════════════════════════
#                       ANIMATION
# ═══════════════════════════════════════════════════════════════

func _show_animated() -> void:
	_visible = true
	root.visible = true
	dim_bg.modulate.a = 0.0
	dialog_panel.modulate.a = 0.0
	cg_layer.modulate.a = 0.0
	portrait_container.modulate.a = 0.0
	right_portrait_container.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim_bg, "modulate:a", 1.0, 0.25)
	_tween.tween_property(dialog_panel, "modulate:a", 1.0, 0.3)
	# CG fades in if visible
	if cg_layer.visible:
		_tween.tween_property(cg_layer, "modulate:a", 1.0, 0.4)
	# Portrait fades in if visible
	if portrait_container.visible:
		_tween.tween_property(portrait_container, "modulate:a", 1.0, 0.35)
	if right_portrait_container.visible:
		_tween.tween_property(right_portrait_container, "modulate:a", 1.0, 0.35)


func _hide_animated() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim_bg, "modulate:a", 0.0, 0.2)
	_tween.tween_property(dialog_panel, "modulate:a", 0.0, 0.2)
	if cg_layer.visible:
		_tween.tween_property(cg_layer, "modulate:a", 0.0, 0.25)
	if portrait_container.visible:
		_tween.tween_property(portrait_container, "modulate:a", 0.0, 0.2)
	if right_portrait_container.visible:
		_tween.tween_property(right_portrait_container, "modulate:a", 0.0, 0.2)
	_tween.chain().tween_callback(hide_dialog)


# ═══════════════════════════════════════════════════════════════
#                          HELPERS
# ═══════════════════════════════════════════════════════════════

func _get_hero_name(hero_id: String) -> String:
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	return hero_data.get("name", hero_id)


# ═══════════════════════════════════════════════════════════════
#                   CG DISPLAY MANAGEMENT
# ═══════════════════════════════════════════════════════════════

## Show a fullscreen CG background with crossfade transition.
func _show_cg(hero_id: String, cg_id: String) -> void:
	if cg_id == _current_cg_id:
		return  # Already showing this CG
	var tex: Texture2D = CGManager.load_cg_texture(hero_id, cg_id)
	if tex == null:
		# CG asset not found — keep current state, don't break
		push_warning("StoryDialog: CG not found: %s/%s" % [hero_id, cg_id])
		return
	_current_cg_id = cg_id
	# Crossfade transition
	if _cg_tween:
		_cg_tween.kill()
	if cg_layer.visible:
		# Crossfade: fade out then swap texture and fade in
		_cg_tween = create_tween()
		_cg_tween.tween_property(cg_layer, "modulate:a", 0.0, 0.15)
		_cg_tween.tween_callback(func(): cg_layer.texture = tex)
		_cg_tween.tween_property(cg_layer, "modulate:a", 1.0, 0.25)
	else:
		# First CG: just set and fade in
		cg_layer.texture = tex
		cg_layer.visible = true
		cg_layer.modulate.a = 0.0
		_cg_tween = create_tween()
		_cg_tween.tween_property(cg_layer, "modulate:a", 1.0, 0.35)
	# When CG is showing, reduce dim_bg opacity for better visibility
	dim_bg.color.a = 0.4
	# Emit signal for tracking
	EventBus.cg_displayed.emit(cg_id, hero_id)


## Hide the CG layer with fade out.
func _hide_cg() -> void:
	if not cg_layer.visible:
		return
	_current_cg_id = ""
	if _cg_tween:
		_cg_tween.kill()
	_cg_tween = create_tween()
	_cg_tween.tween_property(cg_layer, "modulate:a", 0.0, 0.2)
	_cg_tween.tween_callback(func():
		cg_layer.visible = false
		cg_layer.texture = null
	)
	# Restore dim_bg opacity
	dim_bg.color.a = 0.75


# ═══════════════════════════════════════════════════════════════
#                 CHARACTER PORTRAIT MANAGEMENT
# ═══════════════════════════════════════════════════════════════

## Show a character portrait with optional expression variant.
func _show_portrait(hero_id: String, expression: String = "") -> void:
	var tex: Texture2D = CGManager.load_head_texture(hero_id, expression)
	if tex == null:
		# No portrait asset — hide portrait area
		_hide_portrait()
		return
	var is_new_hero: bool = (hero_id != _current_portrait_hero)
	_current_portrait_hero = hero_id
	_current_expression = expression
	portrait_sprite.texture = tex
	portrait_name_label.text = _get_hero_name(hero_id)
	if not portrait_container.visible:
		# First show: fade in
		portrait_container.visible = true
		portrait_container.modulate.a = 0.0
		if _portrait_tween:
			_portrait_tween.kill()
		_portrait_tween = create_tween()
		_portrait_tween.tween_property(portrait_container, "modulate:a", 1.0, 0.25)
	elif is_new_hero:
		# Switching to a different character: quick crossfade
		if _portrait_tween:
			_portrait_tween.kill()
		_portrait_tween = create_tween()
		_portrait_tween.tween_property(portrait_container, "modulate:a", 0.6, 0.08)
		_portrait_tween.tween_property(portrait_container, "modulate:a", 1.0, 0.15)
	# Undim when active speaker
	portrait_sprite.modulate = Color(1, 1, 1, 1)


## Update expression on the current portrait without changing hero.
func _update_expression(expression: String) -> void:
	if _current_portrait_hero == "":
		return
	if expression == _current_expression:
		return
	var tex: Texture2D = CGManager.load_head_texture(_current_portrait_hero, expression)
	if tex == null:
		return  # Expression variant not available, keep current
	_current_expression = expression
	portrait_sprite.texture = tex


## Hide the portrait display.
func _hide_portrait() -> void:
	_current_portrait_hero = ""
	_current_expression = ""
	portrait_container.visible = false
	portrait_sprite.texture = null
	portrait_name_label.text = ""


## Dim/undim the portrait (for narration vs dialogue).
func _dim_portrait(dimmed: bool) -> void:
	if not portrait_container.visible:
		return
	var target_color: Color = Color(0.5, 0.5, 0.5, 0.7) if dimmed else Color(1, 1, 1, 1)
	if _portrait_tween:
		_portrait_tween.kill()
	_portrait_tween = create_tween()
	_portrait_tween.tween_property(portrait_sprite, "modulate", target_color, 0.15)


# ═══════════════════════════════════════════════════════════════
#                     CG UNLOCK HELPER
# ═══════════════════════════════════════════════════════════════

## Scan an event for CG references and unlock them in CGManager.
func _unlock_event_cgs(hero_id: String, event: Dictionary) -> void:
	# Event-level CG
	var cg_id: String = event.get("cg", "")
	if cg_id != "":
		CGManager.unlock_cg(cg_id, hero_id)
	# H-event CG
	var h_event: Dictionary = event.get("h_event", {})
	var h_cg: String = h_event.get("cg", "")
	if h_cg != "":
		CGManager.unlock_cg(h_cg, hero_id)
	# Inline dialogue CGs
	for d in event.get("dialogues", []):
		var d_cg: String = d.get("cg", "")
		if d_cg != "":
			CGManager.unlock_cg(d_cg, hero_id)
	# H-event dialogue CGs
	for d in h_event.get("dialogues", []):
		var d_cg: String = d.get("cg", "")
		if d_cg != "":
			CGManager.unlock_cg(d_cg, hero_id)


# ═══════════════════════════════════════════════════════════════
#                RIGHT PORTRAIT MANAGEMENT (v2.1)
# ═══════════════════════════════════════════════════════════════

## Show a character portrait on the RIGHT side with optional expression.
func _show_right_portrait(hero_id: String, expression: String = "") -> void:
	var tex: Texture2D = CGManager.load_head_texture(hero_id, expression)
	if tex == null:
		_hide_right_portrait()
		return
	right_portrait_sprite.texture = tex
	right_portrait_name_label.text = _get_hero_name(hero_id)
	if not right_portrait_container.visible:
		right_portrait_container.visible = true
		right_portrait_container.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(right_portrait_container, "modulate:a", 1.0, 0.25)
	right_portrait_sprite.modulate = Color(1, 1, 1, 1)


## Hide the right portrait display.
func _hide_right_portrait() -> void:
	right_portrait_container.visible = false
	right_portrait_sprite.texture = null
	right_portrait_name_label.text = ""


## Dim/undim the right portrait (for narration vs dialogue).
func _dim_right_portrait(dimmed: bool) -> void:
	if not right_portrait_container.visible:
		return
	var target_color: Color = Color(0.5, 0.5, 0.5, 0.7) if dimmed else Color(1, 1, 1, 1)
	var tw := create_tween()
	tw.tween_property(right_portrait_sprite, "modulate", target_color, 0.15)
