## settings_panel.gd - Game settings UI for 暗潮 SLG (v1.5)
## Provides audio volume controls, tutorial toggle, and display options.
extends CanvasLayer

signal settings_closed()

var root: Control
var panel: PanelContainer
var _visible: bool = false

# ── Slider refs ──
var bgm_slider: HSlider
var sfx_slider: HSlider
var ambient_slider: HSlider
var mute_check: CheckButton
var tutorial_check: CheckButton
var edge_scroll_check: CheckButton

# ── Display settings ──
var show_grid_check: CheckButton
var show_fog_check: CheckButton


func _ready() -> void:
	layer = 25
	_build_ui()
	visible = false


func _build_ui() -> void:
	root = Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Background dim
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0, 0, 0, 0.5)
	bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			toggle_settings()
	)
	root.add_child(bg)

	# Main panel
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 500)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_top = -250
	panel.offset_right = 200
	panel.offset_bottom = 250

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.5, 0.45, 0.3)
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "游戏设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	vbox.add_child(title)

	var sep1 := HSeparator.new()
	vbox.add_child(sep1)

	# ── Audio section ──
	var audio_title := Label.new()
	audio_title.text = "音频"
	audio_title.add_theme_font_size_override("font_size", 18)
	audio_title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(audio_title)

	bgm_slider = _add_slider(vbox, "背景音乐", 0.7)
	bgm_slider.value_changed.connect(func(v): AudioManager.set_bgm_volume(v))

	sfx_slider = _add_slider(vbox, "音效", 0.8)
	sfx_slider.value_changed.connect(func(v): AudioManager.set_sfx_volume(v))

	ambient_slider = _add_slider(vbox, "环境音", 0.5)
	ambient_slider.value_changed.connect(func(v): AudioManager.set_ambient_volume(v))

	mute_check = CheckButton.new()
	mute_check.text = "静音"
	mute_check.toggled.connect(func(_on): AudioManager.toggle_mute())
	vbox.add_child(mute_check)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# ── Gameplay section ──
	var gameplay_title := Label.new()
	gameplay_title.text = "游戏"
	gameplay_title.add_theme_font_size_override("font_size", 18)
	gameplay_title.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(gameplay_title)

	tutorial_check = CheckButton.new()
	tutorial_check.text = "启用教程"
	tutorial_check.button_pressed = true
	vbox.add_child(tutorial_check)

	edge_scroll_check = CheckButton.new()
	edge_scroll_check.text = "边缘滚动"
	edge_scroll_check.button_pressed = true
	vbox.add_child(edge_scroll_check)

	var sep3 := HSeparator.new()
	vbox.add_child(sep3)

	# ── Close button ──
	var btn_close := Button.new()
	btn_close.text = "关闭"
	btn_close.pressed.connect(toggle_settings)
	vbox.add_child(btn_close)


func _add_slider(parent: VBoxContainer, label_text: String, default_val: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(80, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = default_val
	slider.custom_minimum_size = Vector2(200, 20)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(default_val * 100)
	val_lbl.custom_minimum_size = Vector2(40, 0)
	slider.value_changed.connect(func(v): val_lbl.text = "%d%%" % int(v * 100))
	row.add_child(val_lbl)

	return slider


func toggle_settings() -> void:
	_visible = not _visible
	visible = _visible
	if _visible:
		# Sync with current audio settings
		bgm_slider.value = AudioManager.bgm_volume
		sfx_slider.value = AudioManager.sfx_volume
		ambient_slider.value = AudioManager.ambient_volume
		mute_check.button_pressed = AudioManager.master_muted
	else:
		settings_closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _visible:
			toggle_settings()
			get_viewport().set_input_as_handled()
