## nation_panel.gd — Nation power & control status panel (国力面板)
## Shows 7 nations, control %, bonuses, borders. Key: N
extends CanvasLayer

var _visible: bool = false
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var content_scroll: ScrollContainer
var content_vbox: VBoxContainer

const NationSystemClass = preload("res://systems/map/nation_system.gd")
const FixedMapData = preload("res://systems/map/fixed_map_data.gd")

# Nation display colors
const NATION_COLORS: Dictionary = {
	"human_kingdom": Color(0.9, 0.8, 0.3),
	"elven_domain": Color(0.3, 0.9, 0.5),
	"mage_alliance": Color(0.4, 0.5, 1.0),
	"orc_horde": Color(0.9, 0.3, 0.2),
	"pirate_coalition": Color(0.3, 0.6, 0.9),
	"dark_elf_clan": Color(0.6, 0.2, 0.8),
	"neutral": Color(0.5, 0.5, 0.5),
}

func _ready() -> void:
	layer = UILayerRegistry.LAYER_INFO_PANELS
	_build_ui()
	_connect_signals()
	hide_panel()

func _connect_signals() -> void:
	EventBus.tile_captured.connect(func(_a, _b): _refresh_if_visible())
	EventBus.turn_started.connect(func(_a): _refresh_if_visible())
	if EventBus.has_signal("nation_conquered"):
		EventBus.nation_conquered.connect(func(_a, _b): _refresh_if_visible())

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.game_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_N:
			if _visible: hide_panel()
			else: show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			hide_panel()
			get_viewport().set_input_as_handled()

func _build_ui() -> void:
	root = Control.new()
	root.name = "NationPanelRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.1
	main_panel.anchor_right = 0.9
	main_panel.anchor_top = 0.05
	main_panel.anchor_bottom = 0.95
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.95)
	style.border_color = Color(0.5, 0.4, 0.2, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	main_panel.add_theme_stylebox_override("panel", style)
	root.add_child(main_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	main_panel.add_child(outer_vbox)

	# Header
	var header_row := HBoxContainer.new()
	outer_vbox.add_child(header_row)
	header_label = Label.new()
	header_label.text = "国力总览 — Nation Power"
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", Color(0.85, 0.7, 0.3))
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)
	btn_close = Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	outer_vbox.add_child(HSeparator.new())

	# Scroll content
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_scroll)
	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 12)
	content_scroll.add_child(content_vbox)

func show_panel() -> void:
	if not GameManager.use_fixed_map:
		EventBus.message_log.emit("[color=yellow]国力面板仅在固定地图模式下可用[/color]")
		return
	_visible = true
	root.visible = true
	_refresh()

func hide_panel() -> void:
	_visible = false
	root.visible = false

func is_panel_visible() -> bool:
	return _visible

func _refresh_if_visible() -> void:
	if _visible:
		_refresh()

func _refresh() -> void:
	for child in content_vbox.get_children():
		child.queue_free()

	if not GameManager.use_fixed_map or GameManager.nation_system == null:
		var lbl := Label.new()
		lbl.text = "国力面板仅在固定地图模式下可用"
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		content_vbox.add_child(lbl)
		return

	var ns = GameManager.nation_system
	var pid: int = GameManager.get_human_player_id()

	for nation_id in FixedMapData.NATION_IDS:
		if nation_id == "neutral":
			continue
		_build_nation_card(nation_id, ns, pid)

	# Neutral summary at bottom
	_build_neutral_summary(ns, pid)

func _build_nation_card(nation_id: String, ns, pid: int) -> void:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	var nc: Color = NATION_COLORS.get(nation_id, Color.GRAY)
	card_style.bg_color = Color(nc.r * 0.15, nc.g * 0.15, nc.b * 0.15, 0.9)
	card_style.border_color = Color(nc.r * 0.6, nc.g * 0.6, nc.b * 0.6, 0.7)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	content_vbox.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Nation name + controller
	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)
	var name_lbl := Label.new()
	var nation_name: String = FixedMapData.NATION_NAMES.get(nation_id, nation_id)
	name_lbl.text = nation_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", nc)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	var controller: int = ns.get_nation_controller(nation_id)
	var ctrl_lbl := Label.new()
	if controller == pid:
		ctrl_lbl.text = "★ 已征服"
		ctrl_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	elif controller >= 0:
		var p = GameManager.get_player_by_id(controller)
		if p.is_empty():
			return
		ctrl_lbl.text = "控制者: %s" % p.get("name", "AI")
		ctrl_lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.3))
	else:
		ctrl_lbl.text = "争夺中"
		ctrl_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.3))
	ctrl_lbl.add_theme_font_size_override("font_size", 14)
	name_row.add_child(ctrl_lbl)

	# Control progress bar
	var control_info: Dictionary = ns.get_player_nation_control_count(pid, nation_id)
	var controlled: int = control_info.get("controlled", 0)
	var total: int = control_info.get("total", 1)
	var pct: float = float(controlled) / float(maxi(total, 1))

	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	vbox.add_child(bar_row)

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(300, 14)
	bar_bg.color = Color(0.15, 0.15, 0.2)
	bar_row.add_child(bar_bg)
	var bar_fill := ColorRect.new()
	bar_fill.custom_minimum_size = Vector2(300.0 * pct, 14)
	bar_fill.color = nc * 0.8
	bar_bg.add_child(bar_fill)

	var pct_lbl := Label.new()
	pct_lbl.text = "%d/%d (%d%%)" % [controlled, total, int(pct * 100)]
	pct_lbl.add_theme_font_size_override("font_size", 13)
	pct_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	bar_row.add_child(pct_lbl)

	# Nation bonus
	var bonus: Dictionary = ns.get_nation_bonus(nation_id)
	if not bonus.is_empty() and bonus.get("name", "") != "":
		var bonus_row := HBoxContainer.new()
		vbox.add_child(bonus_row)
		var bonus_icon := Label.new()
		bonus_icon.text = "加成: "
		bonus_icon.add_theme_font_size_override("font_size", 13)
		bonus_icon.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		bonus_row.add_child(bonus_icon)
		var bonus_text := Label.new()
		bonus_text.text = "%s — %s" % [bonus.get("name", ""), bonus.get("description", "")]
		bonus_text.add_theme_font_size_override("font_size", 13)
		var is_active: bool = ns.has_nation_bonus(pid, nation_id)
		bonus_text.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5) if is_active else Color(0.5, 0.5, 0.5))
		bonus_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bonus_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bonus_row.add_child(bonus_text)

	# Power score
	var power: Dictionary = ns.calculate_nation_power(nation_id)
	var stats_lbl := Label.new()
	stats_lbl.text = "国力: %d | 据点: %d | 总驻军: %d | 城防: %d | 资源点: %d" % [
		power.get("power_score", 0), power.get("territory_count", 0),
		power.get("total_garrison", 0), power.get("total_city_def", 0),
		power.get("resource_count", 0),
	]
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	vbox.add_child(stats_lbl)

func _build_neutral_summary(ns, pid: int) -> void:
	var sep := HSeparator.new()
	content_vbox.add_child(sep)
	var neutral_control: Dictionary = ns.get_player_nation_control_count(pid, "neutral")
	var lbl := Label.new()
	lbl.text = "中立地带: 已控制 %d / %d" % [neutral_control.get("controlled", 0), neutral_control.get("total", 0)]
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	content_vbox.add_child(lbl)

func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
