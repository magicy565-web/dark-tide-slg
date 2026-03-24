## main_menu.gd - Title screen + Faction selection for 暗潮 SLG (v0.9.1)
extends CanvasLayer

signal game_started(faction_id: int)

# ── Font ──
var _cjk_font: Font = null

# ── State ──
var _selected_faction: int = -1
var _phase: String = "title"  # "title", "faction_select", "loading"

# ── UI refs ──
var root: Control
var title_panel: PanelContainer
var faction_panel: PanelContainer
var loading_label: Label

# Title panel refs
var btn_new_game: Button
var btn_continue: Button
var btn_settings: Button
var version_label: Label

# Faction selection refs
var faction_container: VBoxContainer
var faction_buttons: Array = []
var faction_desc_label: RichTextLabel
var faction_preview_panel: PanelContainer
var btn_confirm: Button
var btn_back: Button

# Faction data for display
const FACTION_DISPLAY := {
	0: {  # ORC
		"name": "兽人部落",
		"color": Color(0.8, 0.3, 0.2),
		"icon": "WAAAGH!",
		"desc": "[b]兽人部落[/b]\n\n[color=orange]特殊机制: WAAAGH! 战意系统[/color]\n\n战斗胜利积累战意值，满100触发狂暴状态：\n- ATK +50%，DEF -20%\n- 持续3回合\n- 连续不战斗则战意衰减\n\n[color=yellow]专属兵种:[/color] 兽人步兵 / 巨魔 / 战猪骑兵\n\n[color=gray]难度: ★★☆ 适合进攻型玩家[/color]",
		"start_bonus": "初始兵力+5, 起始领地产粮+20%",
	},
	1: {  # PIRATE
		"name": "海盗联盟",
		"color": Color(0.3, 0.5, 0.8),
		"icon": "PLUNDER",
		"desc": "[b]海盗联盟[/b]\n\n[color=orange]特殊机制: 掠夺 & 奴隶贸易[/color]\n\n战斗胜利掠夺额外金币，俘虏敌人为奴隶：\n- 奴隶可分配至矿场/农场提升产出\n- 可在黑市买卖奴隶\n- 暗精灵可将奴隶转化为精锐兵种\n\n[color=yellow]专属兵种:[/color] 海盗刀客 / 火枪手 / 炮击手\n\n[color=gray]难度: ★★★ 适合经济型玩家[/color]",
		"start_bonus": "初始金币+30, 黑市解锁",
	},
	2: {  # DARK_ELF
		"name": "暗精灵议会",
		"color": Color(0.5, 0.2, 0.7),
		"icon": "SHADOW",
		"desc": "[b]暗精灵议会[/b]\n\n[color=orange]特殊机制: 奴隶祭坛 & 暗影转化[/color]\n\n通过暗影祭坛将奴隶转化为精锐暗精灵武士：\n- 每5奴隶转化1名暗精灵武士\n- 祭坛每3回合可献祭提升全军ATK\n- 暗影行者需训练解锁\n\n[color=yellow]专属兵种:[/color] 暗影行者 / 暗精灵刺客 / 冷蜥骑兵 / 暗精灵武士\n\n[color=gray]难度: ★★★ 适合策略型玩家[/color]",
		"start_bonus": "初始奴隶+3, 暗影精华+2",
	},
}


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 10
	# Load CJK font
	_cjk_font = load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	_build_ui()
	_show_title()


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "MenuRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Full-screen dark background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.03, 0.03, 0.06, 1.0)
	root.add_child(bg)

	_build_title_panel()
	_build_faction_panel()
	_build_loading_label()


func _build_title_panel() -> void:
	title_panel = PanelContainer.new()
	title_panel.name = "TitlePanel"
	# Center it
	title_panel.anchor_left = 0.5
	title_panel.anchor_right = 0.5
	title_panel.anchor_top = 0.5
	title_panel.anchor_bottom = 0.5
	title_panel.offset_left = -200
	title_panel.offset_right = 200
	title_panel.offset_top = -180
	title_panel.offset_bottom = 180
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.95)
	style.border_color = Color(0.6, 0.3, 0.1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	title_panel.add_theme_stylebox_override("panel", style)
	root.add_child(title_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	title_panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "暗    潮"
	_apply_font_to_label(title)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.15))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Subtitle
	var sub := Label.new()
	sub.text = "D A R K   T I D E"
	_apply_font_to_label(sub)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 20)
	vbox.add_child(sep)

	# Buttons
	btn_new_game = _make_menu_button("新的征程")
	btn_new_game.pressed.connect(_on_new_game)
	vbox.add_child(btn_new_game)

	btn_continue = _make_menu_button("继续战役")
	btn_continue.pressed.connect(_on_continue)
	vbox.add_child(btn_continue)

	btn_settings = _make_menu_button("游戏设置")
	btn_settings.pressed.connect(_on_settings)
	vbox.add_child(btn_settings)

	# Version
	version_label = Label.new()
	version_label.text = "v2.2.0"
	_apply_font_to_label(version_label)
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(version_label)


func _build_faction_panel() -> void:
	# PLACEHOLDER - filled in by _build_faction_panel_content
	faction_panel = PanelContainer.new()
	faction_panel.name = "FactionPanel"
	faction_panel.anchor_right = 1.0
	faction_panel.anchor_bottom = 1.0
	faction_panel.offset_left = 40
	faction_panel.offset_right = -40
	faction_panel.offset_top = 40
	faction_panel.offset_bottom = -40
	faction_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.08, 0.97)
	style.border_color = Color(0.5, 0.3, 0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	faction_panel.add_theme_stylebox_override("panel", style)
	root.add_child(faction_panel)

	_build_faction_panel_content()


func _build_faction_panel_content() -> void:
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 20)
	faction_panel.add_child(main_hbox)

	# Left side: faction list
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_vbox.custom_minimum_size = Vector2(280, 0)
	main_hbox.add_child(left_vbox)

	var header := Label.new()
	header.text = "选择你的阵营"
	_apply_font_to_label(header)
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(header)

	var sep := HSeparator.new()
	left_vbox.add_child(sep)

	faction_container = VBoxContainer.new()
	faction_container.add_theme_constant_override("separation", 6)
	left_vbox.add_child(faction_container)

	# Create faction buttons
	for fid in FACTION_DISPLAY.keys():
		var fdata: Dictionary = FACTION_DISPLAY[fid]
		var btn := Button.new()
		btn.text = "  %s  %s" % [fdata["icon"], fdata["name"]]
		btn.custom_minimum_size = Vector2(260, 52)
		if _cjk_font:
			btn.add_theme_font_override("font", _cjk_font)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_faction_button.bind(fid))
		faction_container.add_child(btn)
		faction_buttons.append(btn)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	left_vbox.add_child(spacer)

	# Bottom buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.add_child(btn_row)

	btn_back = _make_menu_button("返回")
	btn_back.custom_minimum_size = Vector2(120, 38)
	btn_back.pressed.connect(_on_back_to_title)
	btn_row.add_child(btn_back)

	btn_confirm = _make_menu_button("开始征程")
	btn_confirm.custom_minimum_size = Vector2(140, 38)
	btn_confirm.disabled = true
	btn_confirm.pressed.connect(_on_confirm_faction)
	btn_row.add_child(btn_confirm)

	# Right side: faction description
	faction_preview_panel = PanelContainer.new()
	faction_preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.06, 0.05, 0.1, 0.9)
	preview_style.border_color = Color(0.3, 0.25, 0.2)
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(8)
	preview_style.set_content_margin_all(16)
	faction_preview_panel.add_theme_stylebox_override("panel", preview_style)
	main_hbox.add_child(faction_preview_panel)

	faction_desc_label = RichTextLabel.new()
	faction_desc_label.bbcode_enabled = true
	faction_desc_label.fit_content = false
	faction_desc_label.scroll_active = true
	_apply_font_to_rtl(faction_desc_label)
	faction_desc_label.add_theme_font_size_override("normal_font_size", 14)
	faction_desc_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.88))
	faction_desc_label.text = "[center][color=gray]请从左侧选择一个阵营[/color][/center]"
	faction_preview_panel.add_child(faction_desc_label)


func _build_loading_label() -> void:
	loading_label = Label.new()
	loading_label.name = "LoadingLabel"
	loading_label.anchor_left = 0.5
	loading_label.anchor_right = 0.5
	loading_label.anchor_top = 0.5
	loading_label.anchor_bottom = 0.5
	loading_label.offset_left = -100
	loading_label.offset_right = 100
	_apply_font_to_label(loading_label)
	loading_label.text = "生成世界中..."
	loading_label.add_theme_font_size_override("font_size", 20)
	loading_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.visible = false
	root.add_child(loading_label)


# ═══════════════════════════════════════════════════════════════
#                       PHASE SWITCHING
# ═══════════════════════════════════════════════════════════════

func _show_title() -> void:
	_phase = "title"
	title_panel.visible = true
	faction_panel.visible = false
	loading_label.visible = false
	# Check if save exists
	btn_continue.disabled = not SaveManager.has_save(0)


func _show_faction_select() -> void:
	_phase = "faction_select"
	title_panel.visible = false
	faction_panel.visible = true
	loading_label.visible = false
	_selected_faction = -1
	btn_confirm.disabled = true
	_update_faction_highlight()


func _show_loading() -> void:
	_phase = "loading"
	title_panel.visible = false
	faction_panel.visible = false
	loading_label.visible = true


# ═══════════════════════════════════════════════════════════════
#                       BUTTON CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_new_game() -> void:
	_show_faction_select()


func _on_continue() -> void:
	_show_loading()
	# Defer to next frame so loading label shows
	await get_tree().process_frame
	var success: bool = SaveManager.load_game(0)
	if success:
		_hide_menu()
	else:
		EventBus.message_log.emit("[color=red]存档加载失败[/color]")
		_show_title()


func _on_settings() -> void:
	var sp = get_tree().root.find_child("SettingsPanel", true, false)
	if sp and sp.has_method("toggle_settings"):
		sp.toggle_settings()


func _on_faction_button(faction_id: int) -> void:
	_selected_faction = faction_id
	btn_confirm.disabled = false
	_update_faction_highlight()
	_update_faction_description()


func _on_back_to_title() -> void:
	_show_title()


func _on_confirm_faction() -> void:
	if _selected_faction < 0:
		return
	_show_loading()
	await get_tree().process_frame
	game_started.emit(_selected_faction)
	# The main scene will handle starting the game, then hide this menu
	_hide_menu()


func _hide_menu() -> void:
	root.visible = false


func show_menu() -> void:
	root.visible = true
	_show_title()


# ═══════════════════════════════════════════════════════════════
#                       DISPLAY UPDATES
# ═══════════════════════════════════════════════════════════════

func _update_faction_highlight() -> void:
	for i in range(faction_buttons.size()):
		var btn: Button = faction_buttons[i]
		if i == _selected_faction:
			var fdata: Dictionary = FACTION_DISPLAY[i]
			btn.add_theme_color_override("font_color", fdata["color"])
			var sel_style := StyleBoxFlat.new()
			sel_style.bg_color = fdata["color"] * 0.25
			sel_style.border_color = fdata["color"]
			sel_style.set_border_width_all(2)
			sel_style.set_corner_radius_all(6)
			btn.add_theme_stylebox_override("normal", sel_style)
			btn.add_theme_stylebox_override("hover", sel_style)
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")


func _update_faction_description() -> void:
	if _selected_faction < 0:
		return
	var fdata: Dictionary = FACTION_DISPLAY[_selected_faction]
	var text: String = fdata["desc"]
	text += "\n\n[color=lime]开局加成: %s[/color]" % fdata["start_bonus"]
	faction_desc_label.text = text


# ═══════════════════════════════════════════════════════════════
#                          HELPERS
# ═══════════════════════════════════════════════════════════════

func _make_menu_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(200, 44)
	if _cjk_font:
		btn.add_theme_font_override("font", _cjk_font)
	btn.add_theme_font_size_override("font_size", 16)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	return btn


func _apply_font_to_label(label: Label) -> void:
	if _cjk_font:
		label.add_theme_font_override("font", _cjk_font)


func _apply_font_to_rtl(rtl: RichTextLabel) -> void:
	if _cjk_font:
		rtl.add_theme_font_override("normal_font", _cjk_font)
