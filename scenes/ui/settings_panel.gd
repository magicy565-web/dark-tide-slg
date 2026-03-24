## settings_panel.gd - Game settings UI for 暗潮 SLG (v2.1)
## Provides audio volume controls, tutorial toggle, display options, and settings persistence.
extends CanvasLayer

signal settings_closed()

const SETTINGS_PATH: String = "user://settings.cfg"

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
var combat_speed_slider: HSlider
var auto_end_turn_check: CheckButton

# ── Defaults for reset ──
const DEFAULTS: Dictionary = {
	"bgm_volume": 0.7,
	"sfx_volume": 0.8,
	"ambient_volume": 0.5,
	"master_muted": false,
	"tutorial_enabled": true,
	"edge_scroll": true,
	"show_grid": true,
	"show_fog": true,
	"combat_speed": 1.0,
	"auto_end_turn": false,
}


func _ready() -> void:
	layer = 25
	_build_ui()
	visible = false
	_load_settings()


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
	panel.custom_minimum_size = Vector2(420, 580)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_top = -290
	panel.offset_right = 210
	panel.offset_bottom = 290

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

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "游戏设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# ── Audio section ──
	_add_section_header(vbox, "音频")

	bgm_slider = _add_slider(vbox, "背景音乐", DEFAULTS["bgm_volume"])
	bgm_slider.value_changed.connect(func(v): AudioManager.set_bgm_volume(v))

	sfx_slider = _add_slider(vbox, "音效", DEFAULTS["sfx_volume"])
	sfx_slider.value_changed.connect(func(v): AudioManager.set_sfx_volume(v))

	ambient_slider = _add_slider(vbox, "环境音", DEFAULTS["ambient_volume"])
	ambient_slider.value_changed.connect(func(v): AudioManager.set_ambient_volume(v))

	mute_check = CheckButton.new()
	mute_check.text = "静音"
	mute_check.toggled.connect(func(_on): AudioManager.toggle_mute())
	vbox.add_child(mute_check)

	vbox.add_child(HSeparator.new())

	# ── Display section ──
	_add_section_header(vbox, "显示")

	show_grid_check = CheckButton.new()
	show_grid_check.text = "显示网格"
	show_grid_check.button_pressed = DEFAULTS["show_grid"]
	show_grid_check.toggled.connect(func(on): EventBus.message_log.emit("网格显示: %s" % ("开" if on else "关")))
	vbox.add_child(show_grid_check)

	show_fog_check = CheckButton.new()
	show_fog_check.text = "显示迷雾"
	show_fog_check.button_pressed = DEFAULTS["show_fog"]
	show_fog_check.toggled.connect(func(on): EventBus.message_log.emit("迷雾显示: %s" % ("开" if on else "关")))
	vbox.add_child(show_fog_check)

	combat_speed_slider = _add_slider(vbox, "战斗速度", DEFAULTS["combat_speed"] / 3.0)
	combat_speed_slider.value_changed.connect(func(v):
		var speed: float = v * 3.0
		EventBus.message_log.emit("战斗速度: %.1fx" % speed)
	)

	vbox.add_child(HSeparator.new())

	# ── Gameplay section ──
	_add_section_header(vbox, "游戏")

	tutorial_check = CheckButton.new()
	tutorial_check.text = "启用教程"
	tutorial_check.button_pressed = DEFAULTS["tutorial_enabled"]
	vbox.add_child(tutorial_check)

	edge_scroll_check = CheckButton.new()
	edge_scroll_check.text = "边缘滚动"
	edge_scroll_check.button_pressed = DEFAULTS["edge_scroll"]
	vbox.add_child(edge_scroll_check)

	auto_end_turn_check = CheckButton.new()
	auto_end_turn_check.text = "自动结束回合 (无行动时)"
	auto_end_turn_check.button_pressed = DEFAULTS["auto_end_turn"]
	vbox.add_child(auto_end_turn_check)

	vbox.add_child(HSeparator.new())

	# ── Button row ──
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn_defaults := Button.new()
	btn_defaults.text = "恢复默认"
	btn_defaults.pressed.connect(_reset_to_defaults)
	btn_row.add_child(btn_defaults)

	var btn_close := Button.new()
	btn_close.text = "保存并关闭"
	btn_close.pressed.connect(func():
		_save_settings()
		toggle_settings()
	)
	btn_row.add_child(btn_close)


func _add_section_header(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	parent.add_child(lbl)


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
		_save_settings()
		settings_closed.emit()


func _reset_to_defaults() -> void:
	bgm_slider.value = DEFAULTS["bgm_volume"]
	sfx_slider.value = DEFAULTS["sfx_volume"]
	ambient_slider.value = DEFAULTS["ambient_volume"]
	mute_check.button_pressed = DEFAULTS["master_muted"]
	tutorial_check.button_pressed = DEFAULTS["tutorial_enabled"]
	edge_scroll_check.button_pressed = DEFAULTS["edge_scroll"]
	show_grid_check.button_pressed = DEFAULTS["show_grid"]
	show_fog_check.button_pressed = DEFAULTS["show_fog"]
	combat_speed_slider.value = DEFAULTS["combat_speed"] / 3.0
	auto_end_turn_check.button_pressed = DEFAULTS["auto_end_turn"]
	# Apply audio defaults immediately
	AudioManager.set_bgm_volume(DEFAULTS["bgm_volume"])
	AudioManager.set_sfx_volume(DEFAULTS["sfx_volume"])
	AudioManager.set_ambient_volume(DEFAULTS["ambient_volume"])
	if AudioManager.master_muted != DEFAULTS["master_muted"]:
		AudioManager.toggle_mute()


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "bgm_volume", bgm_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	config.set_value("audio", "ambient_volume", ambient_slider.value)
	config.set_value("audio", "master_muted", mute_check.button_pressed)
	config.set_value("gameplay", "tutorial_enabled", tutorial_check.button_pressed)
	config.set_value("gameplay", "edge_scroll", edge_scroll_check.button_pressed)
	config.set_value("gameplay", "auto_end_turn", auto_end_turn_check.button_pressed)
	config.set_value("display", "show_grid", show_grid_check.button_pressed)
	config.set_value("display", "show_fog", show_fog_check.button_pressed)
	config.set_value("display", "combat_speed", combat_speed_slider.value * 3.0)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsPanel: Failed to save settings (error %d)" % err)


func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		return  # No saved settings, use defaults

	bgm_slider.value = config.get_value("audio", "bgm_volume", DEFAULTS["bgm_volume"])
	sfx_slider.value = config.get_value("audio", "sfx_volume", DEFAULTS["sfx_volume"])
	ambient_slider.value = config.get_value("audio", "ambient_volume", DEFAULTS["ambient_volume"])
	mute_check.button_pressed = config.get_value("audio", "master_muted", DEFAULTS["master_muted"])
	tutorial_check.button_pressed = config.get_value("gameplay", "tutorial_enabled", DEFAULTS["tutorial_enabled"])
	edge_scroll_check.button_pressed = config.get_value("gameplay", "edge_scroll", DEFAULTS["edge_scroll"])
	auto_end_turn_check.button_pressed = config.get_value("gameplay", "auto_end_turn", DEFAULTS["auto_end_turn"])
	show_grid_check.button_pressed = config.get_value("display", "show_grid", DEFAULTS["show_grid"])
	show_fog_check.button_pressed = config.get_value("display", "show_fog", DEFAULTS["show_fog"])
	combat_speed_slider.value = config.get_value("display", "combat_speed", DEFAULTS["combat_speed"]) / 3.0

	# Apply loaded audio settings
	AudioManager.set_bgm_volume(bgm_slider.value)
	AudioManager.set_sfx_volume(sfx_slider.value)
	AudioManager.set_ambient_volume(ambient_slider.value)
	if mute_check.button_pressed != AudioManager.master_muted:
		AudioManager.toggle_mute()


## Get a setting value (for other systems to query)
func get_setting(key: String):
	match key:
		"edge_scroll": return edge_scroll_check.button_pressed if edge_scroll_check else DEFAULTS["edge_scroll"]
		"show_grid": return show_grid_check.button_pressed if show_grid_check else DEFAULTS["show_grid"]
		"show_fog": return show_fog_check.button_pressed if show_fog_check else DEFAULTS["show_fog"]
		"combat_speed": return combat_speed_slider.value * 3.0 if combat_speed_slider else DEFAULTS["combat_speed"]
		"auto_end_turn": return auto_end_turn_check.button_pressed if auto_end_turn_check else DEFAULTS["auto_end_turn"]
		"tutorial_enabled": return tutorial_check.button_pressed if tutorial_check else DEFAULTS["tutorial_enabled"]
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _visible:
			toggle_settings()
			get_viewport().set_input_as_handled()
