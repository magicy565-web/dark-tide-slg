## event_popup.gd - Modal event dialog for 暗潮 SLG (v0.9.1)
extends CanvasLayer

# ── State ──
var _visible: bool = false
var _choices: Array = []
var _current_event_id: String = ""

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var popup_panel: PanelContainer
var title_label: Label
var desc_label: RichTextLabel
var choice_container: VBoxContainer
var choice_buttons: Array = []
var btn_dismiss: Button
var icon_label: Label

# ── Animation ──
var _tween: Tween = null


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 5
	_build_ui()
	_connect_signals()
	hide_popup()


func _connect_signals() -> void:
	EventBus.show_event_popup.connect(_on_show_event_popup)
	EventBus.hide_event_popup.connect(_on_hide_event_popup)


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "EventRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dimming background
	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.6)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim_bg)

	# Main popup panel
	popup_panel = PanelContainer.new()
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.offset_left = -260
	popup_panel.offset_right = 260
	popup_panel.offset_top = -200
	popup_panel.offset_bottom = 200
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.97)
	style.border_color = Color(0.7, 0.45, 0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(20)
	popup_panel.add_theme_stylebox_override("panel", style)
	root.add_child(popup_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	popup_panel.add_child(vbox)

	# Header row: icon + title
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	icon_label = Label.new()
	icon_label.text = "!"
	icon_label.add_theme_font_size_override("font_size", 28)
	icon_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	header.add_child(icon_label)

	title_label = Label.new()
	title_label.text = "事件"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.6))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Description
	var desc_scroll := ScrollContainer.new()
	desc_scroll.custom_minimum_size = Vector2(0, 160)
	desc_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(desc_scroll)

	desc_label = RichTextLabel.new()
	desc_label.bbcode_enabled = true
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.add_theme_font_size_override("normal_font_size", 14)
	desc_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.88))
	desc_scroll.add_child(desc_label)

	# Separator before choices
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Choices container
	choice_container = VBoxContainer.new()
	choice_container.add_theme_constant_override("separation", 6)
	vbox.add_child(choice_container)

	# Dismiss button (for events without choices)
	btn_dismiss = Button.new()
	btn_dismiss.text = "确认"
	btn_dismiss.custom_minimum_size = Vector2(120, 38)
	btn_dismiss.add_theme_font_size_override("font_size", 14)
	btn_dismiss.pressed.connect(_on_dismiss)
	choice_container.add_child(btn_dismiss)


# ═══════════════════════════════════════════════════════════════
#                       PUBLIC API
# ═══════════════════════════════════════════════════════════════

func show_event(title: String, description: String, choices: Array = [], event_id: String = "") -> void:
	_current_event_id = event_id
	_choices = choices
	title_label.text = title
	desc_label.text = description

	# Clear old choice buttons
	_clear_choices()

	if choices.is_empty():
		# No choices, just show dismiss
		btn_dismiss.visible = true
		btn_dismiss.text = "确认"
	else:
		btn_dismiss.visible = false
		for i in range(choices.size()):
			var choice: Dictionary = choices[i] if choices[i] is Dictionary else {"text": str(choices[i])}
			var btn := Button.new()
			btn.text = choice.get("text", "选项 %d" % (i + 1))
			btn.custom_minimum_size = Vector2(400, 36)
			btn.add_theme_font_size_override("font_size", 13)
			btn.pressed.connect(_on_choice.bind(i))
			choice_container.add_child(btn)
			choice_buttons.append(btn)

	# Set icon based on event type
	_set_event_icon(event_id)

	# Show with animation
	_show_animated()


func hide_popup() -> void:
	_visible = false
	root.visible = false


# ═══════════════════════════════════════════════════════════════
#                       SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_show_event_popup(title: String, description: String, choices: Array) -> void:
	show_event(title, description, choices)


func _on_hide_event_popup() -> void:
	hide_popup()


func _on_dismiss() -> void:
	EventBus.event_choice_selected.emit(-1)
	if _is_conquest_popup():
		EventBus.conquest_choice_selected.emit(0)
	_hide_animated()


func _on_choice(index: int) -> void:
	EventBus.event_choice_selected.emit(index)
	if _is_conquest_popup():
		EventBus.conquest_choice_selected.emit(index)
	if _current_event_id != "":
		EventBus.event_choice_made.emit(_current_event_id, index)
	_hide_animated()


# ═══════════════════════════════════════════════════════════════
#                       ANIMATION
# ═══════════════════════════════════════════════════════════════

func _show_animated() -> void:
	_visible = true
	root.visible = true

	# Fade in
	dim_bg.modulate.a = 0.0
	popup_panel.modulate.a = 0.0
	popup_panel.scale = Vector2(0.9, 0.9)

	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim_bg, "modulate:a", 1.0, 0.2)
	_tween.tween_property(popup_panel, "modulate:a", 1.0, 0.25)
	_tween.tween_property(popup_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_animated() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim_bg, "modulate:a", 0.0, 0.15)
	_tween.tween_property(popup_panel, "modulate:a", 0.0, 0.15)
	_tween.tween_property(popup_panel, "scale", Vector2(0.95, 0.95), 0.15)
	_tween.chain().tween_callback(hide_popup)


# ═══════════════════════════════════════════════════════════════
#                          HELPERS
# ═══════════════════════════════════════════════════════════════

func _clear_choices() -> void:
	for btn in choice_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	choice_buttons.clear()


func _set_event_icon(event_id: String) -> void:
	# Set icon color based on event category
	if event_id.begins_with("plague") or event_id.begins_with("famine"):
		icon_label.text = "!"
		icon_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
	elif event_id.begins_with("blessing") or event_id.begins_with("hero"):
		icon_label.text = "+"
		icon_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	elif event_id.begins_with("combat") or event_id.begins_with("raid"):
		icon_label.text = "X"
		icon_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	elif event_id.begins_with("quest"):
		icon_label.text = "?"
		icon_label.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	else:
		icon_label.text = "!"
		icon_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))


func _is_conquest_popup() -> bool:
	return title_label.text.begins_with("占领")
