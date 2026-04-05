## weather_hud.gd - Compact HUD showing current season + weather in the top-right corner.
## Updates live via EventBus.season_changed / weather_changed signals.
extends CanvasLayer

# ── Theme colors (shared dark/gold palette) ──
const BG_COLOR := Color(0.08, 0.06, 0.12, 0.92)
const GOLD := Color(0.85, 0.7, 0.3)
const GOLD_DIM := Color(0.55, 0.45, 0.2)
const GOLD_BRIGHT := Color(1.0, 0.85, 0.4)
const TEXT_COLOR := Color(0.9, 0.88, 0.82)
const HOVER_COLOR := Color(0.14, 0.11, 0.2, 0.95)

const SEASON_ICONS: Dictionary = {
	0: "🌸春",  # SPRING
	1: "☀夏",   # SUMMER
	2: "🍂秋",  # AUTUMN
	3: "❄冬",   # WINTER
}

const WEATHER_ICONS: Dictionary = {
	0: "☀", 1: "🌧", 2: "🌫", 3: "⛈", 4: "❄", 5: "🔥", 6: "🌊",
}

# ── State ──
var _season_id: int = 0
var _season_data: Dictionary = {}
var _weather_id: int = 0
var _weather_data: Dictionary = {}

# ── UI refs ──
var root: PanelContainer
var season_label: Label
var weather_label: Label
var effect_label: Label
var tooltip_panel: PanelContainer
var tooltip_label: RichTextLabel

func _ready() -> void:
	layer = UILayerRegistry.LAYER_WEATHER_HUD
	_build_ui()
	# Connect EventBus signals
	if EventBus:
		EventBus.season_changed.connect(_on_season_changed)
		EventBus.weather_changed.connect(_on_weather_changed)

# ═════════════════════════════════════════════════
#                    BUILD UI
# ═════════════════════════════════════════════════

func _build_ui() -> void:
	root = PanelContainer.new()
	root.anchor_left = 1.0; root.anchor_right = 1.0
	root.anchor_top = 0.0; root.anchor_bottom = 0.0
	root.offset_left = -220; root.offset_right = -12
	root.offset_top = 12; root.offset_bottom = 100
	root.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR, GOLD_DIM, 1))
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.mouse_entered.connect(_on_hover.bind(true))
	root.mouse_exited.connect(_on_hover.bind(false))
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	root.add_child(vbox)

	season_label = Label.new()
	season_label.text = SEASON_ICONS.get(0, "?")
	season_label.add_theme_color_override("font_color", GOLD_BRIGHT)
	season_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(season_label)

	weather_label = Label.new()
	weather_label.text = "☀ Clear"
	weather_label.add_theme_color_override("font_color", TEXT_COLOR)
	weather_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(weather_label)

	effect_label = Label.new()
	effect_label.text = ""
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.add_theme_color_override("font_color", GOLD_DIM)
	effect_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(effect_label)

	# Tooltip (hidden by default)
	tooltip_panel = PanelContainer.new()
	tooltip_panel.anchor_left = 1.0; tooltip_panel.anchor_right = 1.0
	tooltip_panel.offset_left = -320; tooltip_panel.offset_right = -12
	tooltip_panel.offset_top = 105; tooltip_panel.offset_bottom = 300
	tooltip_panel.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR, GOLD, 1))
	tooltip_panel.visible = false
	add_child(tooltip_panel)

	tooltip_label = RichTextLabel.new()
	tooltip_label.bbcode_enabled = true
	tooltip_label.fit_content = true
	tooltip_label.scroll_active = false
	tooltip_label.add_theme_color_override("default_color", TEXT_COLOR)
	tooltip_label.add_theme_font_size_override("normal_font_size", 12)
	tooltip_panel.add_child(tooltip_label)

# ═════════════════════════════════════════════════
#                 SIGNAL HANDLERS
# ═════════════════════════════════════════════════

func _on_season_changed(season_id: int, season_data: Dictionary) -> void:
	_season_id = season_id
	_season_data = season_data
	_refresh()

func _on_weather_changed(weather_id: int, weather_data: Dictionary) -> void:
	_weather_id = weather_id
	_weather_data = weather_data
	_refresh()

func _refresh() -> void:
	season_label.text = SEASON_ICONS.get(_season_id, "?") + " " + _season_data.get("name", "")
	var w_icon: String = WEATHER_ICONS.get(_weather_id, "?")
	var w_name: String = _weather_data.get("name", "Unknown")
	weather_label.text = "%s %s" % [w_icon, w_name]
	effect_label.text = _build_brief_effects()
	_build_tooltip()

func _build_brief_effects() -> String:
	var parts: Array = []
	var w := _weather_data
	if w.get("cavalry_charge_disabled", false):
		parts.append("骑兵冲锋禁止")
	if w.get("fire_attacks_nullified", false):
		parts.append("火攻无效")
	if w.get("naval_blocked", false):
		parts.append("海运封锁")
	if w.get("attrition_exposed", false):
		parts.append("暴露减员")
	var s := _season_data
	if s.get("food_mult", 1.0) != 1.0:
		parts.append("粮×%.0f%%" % (s["food_mult"] * 100))
	if parts.is_empty():
		return "无特殊效果"
	return ", ".join(parts)

func _build_tooltip() -> void:
	var lines: Array = []
	lines.append("[color=#%s]── 季节修正 ──[/color]" % GOLD_BRIGHT.to_html(false))
	var s := _season_data
	for key in ["food_mult", "gold_mult", "iron_mult", "cavalry_atk_mod", "cavalry_spd_mod",
				"heavy_armor_def_mod", "supply_attrition_mult", "morale_recovery", "movement_ap_extra"]:
		var val = s.get(key, 0)
		if (val is float and val != 1.0) or (val is int and val != 0):
			lines.append("  %s: %s" % [key, str(val)])

	lines.append("[color=#%s]── 天气修正 ──[/color]" % GOLD_BRIGHT.to_html(false))
	var w := _weather_data
	for key in ["atk_mod", "def_mod", "spd_mod", "ranged_atk_mod", "movement_ap_extra",
				"cavalry_charge_disabled", "fire_attacks_nullified", "naval_blocked",
				"ambush_bonus", "attrition_exposed", "food_mult", "supply_convoy_loss_chance"]:
		var val = w.get(key, 0)
		var dominated: bool = (val is float and val != 1.0 and val != 0.0) or (val is int and val != 0) or (val is bool and val)
		if dominated:
			lines.append("  %s: %s" % [key, str(val)])
	tooltip_label.text = "\n".join(lines)

func _on_hover(entering: bool) -> void:
	tooltip_panel.visible = entering
	if entering:
		root.add_theme_stylebox_override("panel", _make_panel_style(HOVER_COLOR, GOLD, 1))
	else:
		root.add_theme_stylebox_override("panel", _make_panel_style(BG_COLOR, GOLD_DIM, 1))

# ═════════════════════════════════════════════════
#                    STYLING
# ═════════════════════════════════════════════════

func _make_panel_style(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(8)
	return s
