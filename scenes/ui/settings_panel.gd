## settings_panel.gd - Game settings UI for Dark Tide SLG (v4.0)
## Provides audio, display, gameplay, and difficulty settings with persistence.
extends CanvasLayer

signal settings_closed()

const SETTINGS_PATH: String = "user://settings.cfg"

var root: Control
var panel: PanelContainer
var _visible: bool = false

# ── Slider refs ──
var master_slider: HSlider
var bgm_slider: HSlider
var sfx_slider: HSlider
var ambient_slider: HSlider
var mute_check: CheckButton
var tutorial_check: CheckButton
var edge_scroll_check: CheckButton

# ── Display settings ──
var show_grid_check: CheckButton
var show_fog_check: CheckButton
var game_speed_option: OptionButton
var auto_end_turn_check: CheckButton
var auto_save_check: CheckButton

# ── Display settings (extra) ──
var fullscreen_check: CheckButton

# ── Difficulty ──
var difficulty_option: OptionButton

# ── Game speed values ──
const GAME_SPEED_VALUES: Array = [0.5, 1.0, 1.5, 2.0]
const GAME_SPEED_LABELS: Array = ["x0.5", "x1", "x1.5", "x2"]

## Global game speed multiplier for combat_view and other time-scaled systems
static var game_speed: float = 1.0

# ── Defaults for reset ──
const DEFAULTS: Dictionary = {
	"master_volume": 0.8,
	"bgm_volume": 0.7,
	"sfx_volume": 0.8,
	"ambient_volume": 0.5,
	"master_muted": false,
	"tutorial_enabled": true,
	"edge_scroll": true,
	"show_grid": true,
	"show_fog": true,
	"game_speed_idx": 1,
	"auto_end_turn": false,
	"auto_save": true,
	"fullscreen": false,
	"difficulty": 1,
}


func _ready() -> void:
	layer = UILayerRegistry.LAYER_SETTINGS
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

	var style: StyleBox
	if UITheme.frame_content:
		style = UITheme.make_content_style()
	else:
		var sf := StyleBoxFlat.new()
		sf.bg_color = ColorTheme.BG_SECONDARY
		sf.border_color = ColorTheme.BORDER_DEFAULT
		sf.set_border_width_all(2)
		sf.set_corner_radius_all(8)
		sf.content_margin_left = 20
		sf.content_margin_right = 20
		sf.content_margin_top = 16
		sf.content_margin_bottom = 16
		style = sf
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
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING + 4)
	title.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# ── Audio section ──
	_add_section_header(vbox, "Audio")

	master_slider = _add_slider(vbox, "Master", DEFAULTS["master_volume"])
	master_slider.value_changed.connect(func(v):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(v))
	)

	bgm_slider = _add_slider(vbox, "Music", DEFAULTS["bgm_volume"])
	bgm_slider.value_changed.connect(func(v):
		AudioManager.set_bgm_volume(v)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), linear_to_db(v))
	)

	sfx_slider = _add_slider(vbox, "SFX", DEFAULTS["sfx_volume"])
	sfx_slider.value_changed.connect(func(v):
		AudioManager.set_sfx_volume(v)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(v))
	)

	ambient_slider = _add_slider(vbox, "Ambient", DEFAULTS["ambient_volume"])
	ambient_slider.value_changed.connect(func(v): AudioManager.set_ambient_volume(v))

	mute_check = CheckButton.new()
	mute_check.text = "Mute"
	mute_check.toggled.connect(func(_on): AudioManager.toggle_mute())
	vbox.add_child(mute_check)

	vbox.add_child(HSeparator.new())

	# ── Display section ──
	_add_section_header(vbox, "Display")

	show_grid_check = CheckButton.new()
	show_grid_check.text = "Show Grid"
	show_grid_check.button_pressed = DEFAULTS["show_grid"]
	show_grid_check.toggled.connect(func(on): EventBus.message_log.emit("Grid: %s" % ("ON" if on else "OFF")))
	vbox.add_child(show_grid_check)

	show_fog_check = CheckButton.new()
	show_fog_check.text = "Show Fog"
	show_fog_check.button_pressed = DEFAULTS["show_fog"]
	show_fog_check.toggled.connect(func(on): EventBus.message_log.emit("Fog: %s" % ("ON" if on else "OFF")))
	vbox.add_child(show_fog_check)

	fullscreen_check = CheckButton.new()
	fullscreen_check.text = "Fullscreen"
	fullscreen_check.button_pressed = DEFAULTS["fullscreen"]
	fullscreen_check.toggled.connect(func(on):
		if on:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		EventBus.message_log.emit("Fullscreen: %s" % ("ON" if on else "OFF"))
	)
	vbox.add_child(fullscreen_check)

	# Game Speed OptionButton
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	vbox.add_child(speed_row)

	var speed_lbl := Label.new()
	speed_lbl.text = "Game Speed"
	speed_lbl.custom_minimum_size = Vector2(80, 0)
	speed_lbl.add_theme_font_size_override("font_size", 14)
	speed_row.add_child(speed_lbl)

	game_speed_option = OptionButton.new()
	game_speed_option.custom_minimum_size = Vector2(120, 30)
	for i in range(GAME_SPEED_LABELS.size()):
		game_speed_option.add_item(GAME_SPEED_LABELS[i], i)
	game_speed_option.selected = DEFAULTS["game_speed_idx"]
	game_speed_option.item_selected.connect(func(idx):
		game_speed = GAME_SPEED_VALUES[idx]
		EventBus.message_log.emit("Game Speed: %s" % GAME_SPEED_LABELS[idx])
	)
	speed_row.add_child(game_speed_option)

	vbox.add_child(HSeparator.new())

	# ── Gameplay section ──
	_add_section_header(vbox, "Gameplay")

	tutorial_check = CheckButton.new()
	tutorial_check.text = "Enable Tutorial"
	tutorial_check.button_pressed = DEFAULTS["tutorial_enabled"]
	vbox.add_child(tutorial_check)

	edge_scroll_check = CheckButton.new()
	edge_scroll_check.text = "Edge Scroll"
	edge_scroll_check.button_pressed = DEFAULTS["edge_scroll"]
	vbox.add_child(edge_scroll_check)

	auto_end_turn_check = CheckButton.new()
	auto_end_turn_check.text = "Auto End Turn (when idle)"
	auto_end_turn_check.button_pressed = DEFAULTS["auto_end_turn"]
	vbox.add_child(auto_end_turn_check)

	auto_save_check = CheckButton.new()
	auto_save_check.text = "Auto Save"
	auto_save_check.button_pressed = DEFAULTS["auto_save"]
	vbox.add_child(auto_save_check)

	vbox.add_child(HSeparator.new())

	# ── Difficulty section (v3.0) ──
	_add_section_header(vbox, "Difficulty")

	var diff_row := HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	vbox.add_child(diff_row)

	var diff_lbl := Label.new()
	diff_lbl.text = "Game Difficulty"
	diff_lbl.custom_minimum_size = Vector2(80, 0)
	diff_lbl.add_theme_font_size_override("font_size", 14)
	diff_row.add_child(diff_lbl)

	difficulty_option = OptionButton.new()
	difficulty_option.custom_minimum_size = Vector2(160, 30)
	var diff_keys: Array = ["easy", "normal", "hard", "nightmare"]
	var diff_labels: Array = ["Easy", "Normal", "Hard", "Nightmare"]
	for i in range(diff_keys.size()):
		difficulty_option.add_item(diff_labels[i], i)
	difficulty_option.selected = 1  # default: normal
	difficulty_option.item_selected.connect(func(idx):
		var key: String = diff_keys[idx]
		BalanceManager.set_difficulty(key)
		EventBus.message_log.emit("Difficulty set to: %s" % diff_labels[idx])
	)
	diff_row.add_child(difficulty_option)

	# Difficulty description
	var diff_desc := Label.new()
	diff_desc.text = "Affects AI strength, expedition frequency, threat growth, player economy"
	diff_desc.add_theme_font_size_override("font_size", 11)
	diff_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	diff_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(diff_desc)

	vbox.add_child(HSeparator.new())

	# ── Button row ──
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var btn_defaults := Button.new()
	btn_defaults.text = "Reset Defaults"
	btn_defaults.pressed.connect(_reset_to_defaults)
	btn_row.add_child(btn_defaults)

	var btn_close := Button.new()
	btn_close.text = "Save & Close"
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
	AudioManager.play_ui_click()
	_visible = not _visible
	visible = _visible
	if _visible:
		ColorTheme.animate_panel_open(panel)
		# Sync with current audio settings
		var master_db: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
		master_slider.value = db_to_linear(master_db)
		bgm_slider.value = AudioManager.bgm_volume
		sfx_slider.value = AudioManager.sfx_volume
		ambient_slider.value = AudioManager.ambient_volume
		mute_check.button_pressed = AudioManager.master_muted
		# Sync game speed
		var speed_idx: int = GAME_SPEED_VALUES.find(game_speed)
		if speed_idx >= 0:
			game_speed_option.selected = speed_idx
	else:
		_save_settings()
		settings_closed.emit()


func _reset_to_defaults() -> void:
	AudioManager.play_ui_click()
	master_slider.value = DEFAULTS["master_volume"]
	bgm_slider.value = DEFAULTS["bgm_volume"]
	sfx_slider.value = DEFAULTS["sfx_volume"]
	ambient_slider.value = DEFAULTS["ambient_volume"]
	mute_check.button_pressed = DEFAULTS["master_muted"]
	tutorial_check.button_pressed = DEFAULTS["tutorial_enabled"]
	edge_scroll_check.button_pressed = DEFAULTS["edge_scroll"]
	show_grid_check.button_pressed = DEFAULTS["show_grid"]
	show_fog_check.button_pressed = DEFAULTS["show_fog"]
	game_speed_option.selected = DEFAULTS["game_speed_idx"]
	game_speed = GAME_SPEED_VALUES[DEFAULTS["game_speed_idx"]]
	auto_end_turn_check.button_pressed = DEFAULTS["auto_end_turn"]
	auto_save_check.button_pressed = DEFAULTS["auto_save"]
	fullscreen_check.button_pressed = DEFAULTS["fullscreen"]
	difficulty_option.selected = DEFAULTS["difficulty"]
	# Apply audio defaults immediately
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(DEFAULTS["master_volume"]))
	AudioManager.set_bgm_volume(DEFAULTS["bgm_volume"])
	AudioManager.set_sfx_volume(DEFAULTS["sfx_volume"])
	AudioManager.set_ambient_volume(DEFAULTS["ambient_volume"])
	AudioManager.master_muted = DEFAULTS["master_muted"]
	AudioServer.set_bus_mute(0, DEFAULTS["master_muted"])


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_slider.value)
	config.set_value("audio", "bgm_volume", bgm_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	config.set_value("audio", "ambient_volume", ambient_slider.value)
	config.set_value("audio", "master_muted", mute_check.button_pressed)
	config.set_value("gameplay", "tutorial_enabled", tutorial_check.button_pressed)
	config.set_value("gameplay", "edge_scroll", edge_scroll_check.button_pressed)
	config.set_value("gameplay", "auto_end_turn", auto_end_turn_check.button_pressed)
	config.set_value("gameplay", "auto_save", auto_save_check.button_pressed)
	config.set_value("display", "show_grid", show_grid_check.button_pressed)
	config.set_value("display", "show_fog", show_fog_check.button_pressed)
	config.set_value("display", "game_speed_idx", game_speed_option.selected)
	config.set_value("display", "fullscreen", fullscreen_check.button_pressed)
	config.set_value("gameplay", "difficulty", difficulty_option.selected)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("SettingsPanel: Failed to save settings (error %d)" % err)


func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err != OK:
		# No saved settings — apply defaults to AudioServer buses
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(DEFAULTS["master_volume"]))
		return

	master_slider.value = config.get_value("audio", "master_volume", DEFAULTS["master_volume"])
	bgm_slider.value = config.get_value("audio", "bgm_volume", DEFAULTS["bgm_volume"])
	sfx_slider.value = config.get_value("audio", "sfx_volume", DEFAULTS["sfx_volume"])
	ambient_slider.value = config.get_value("audio", "ambient_volume", DEFAULTS["ambient_volume"])
	mute_check.button_pressed = config.get_value("audio", "master_muted", DEFAULTS["master_muted"])
	tutorial_check.button_pressed = config.get_value("gameplay", "tutorial_enabled", DEFAULTS["tutorial_enabled"])
	edge_scroll_check.button_pressed = config.get_value("gameplay", "edge_scroll", DEFAULTS["edge_scroll"])
	auto_end_turn_check.button_pressed = config.get_value("gameplay", "auto_end_turn", DEFAULTS["auto_end_turn"])
	auto_save_check.button_pressed = config.get_value("gameplay", "auto_save", DEFAULTS["auto_save"])
	show_grid_check.button_pressed = config.get_value("display", "show_grid", DEFAULTS["show_grid"])
	show_fog_check.button_pressed = config.get_value("display", "show_fog", DEFAULTS["show_fog"])
	fullscreen_check.button_pressed = config.get_value("display", "fullscreen", DEFAULTS["fullscreen"])
	difficulty_option.selected = config.get_value("gameplay", "difficulty", DEFAULTS["difficulty"])

	# Game speed
	var speed_idx: int = config.get_value("display", "game_speed_idx", DEFAULTS["game_speed_idx"])
	speed_idx = clampi(speed_idx, 0, GAME_SPEED_VALUES.size() - 1)
	game_speed_option.selected = speed_idx
	game_speed = GAME_SPEED_VALUES[speed_idx]

	# Apply loaded difficulty setting
	var _diff_keys: Array = ["easy", "normal", "hard", "nightmare"]
	var _diff_idx: int = difficulty_option.selected
	if _diff_idx >= 0 and _diff_idx < _diff_keys.size():
		BalanceManager.set_difficulty(_diff_keys[_diff_idx])

	# Apply loaded audio settings
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_slider.value))
	AudioManager.set_bgm_volume(bgm_slider.value)
	AudioManager.set_sfx_volume(sfx_slider.value)
	AudioManager.set_ambient_volume(ambient_slider.value)
	AudioManager.master_muted = mute_check.button_pressed
	AudioServer.set_bus_mute(0, mute_check.button_pressed)

	# Apply loaded fullscreen setting
	if fullscreen_check.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Get a setting value (for other systems to query)
func get_setting(key: String):
	match key:
		"edge_scroll": return edge_scroll_check.button_pressed if edge_scroll_check else DEFAULTS["edge_scroll"]
		"show_grid": return show_grid_check.button_pressed if show_grid_check else DEFAULTS["show_grid"]
		"show_fog": return show_fog_check.button_pressed if show_fog_check else DEFAULTS["show_fog"]
		"game_speed": return game_speed
		"combat_speed": return game_speed  # backward compat alias
		"auto_end_turn": return auto_end_turn_check.button_pressed if auto_end_turn_check else DEFAULTS["auto_end_turn"]
		"auto_save": return auto_save_check.button_pressed if auto_save_check else DEFAULTS["auto_save"]
		"fullscreen": return fullscreen_check.button_pressed if fullscreen_check else DEFAULTS["fullscreen"]
		"tutorial_enabled": return tutorial_check.button_pressed if tutorial_check else DEFAULTS["tutorial_enabled"]
		"master_volume": return master_slider.value if master_slider else DEFAULTS["master_volume"]
	return null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _visible:
			toggle_settings()
			get_viewport().set_input_as_handled()
