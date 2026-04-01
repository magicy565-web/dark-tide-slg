## main_menu.gd - Title screen + Faction selection for Dark Tide SLG (v4.0-pixel)
extends CanvasLayer

signal game_started(faction_id: int, fixed_map: bool)

# ── Map mode ──
var _use_fixed_map: bool = false

# ── Font ──
var _cjk_font: Font = null

# ── Pixel art assets ──
var _bg_texture: Texture2D = null
var _logo_texture: Texture2D = null
var _crest_textures: Dictionary = {}  # faction_id -> Texture2D

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
var btn_credits: Button
var version_label: Label

# Faction selection refs
var faction_container: VBoxContainer
var faction_buttons: Array = []
var faction_desc_label: RichTextLabel
var faction_preview_panel: PanelContainer
var faction_crest_display: TextureRect
var btn_confirm: Button
var btn_back: Button

# Credits panel refs
var credits_panel: PanelContainer
var credits_scroll: ScrollContainer
var btn_credits_back: Button

# Faction crest paths
const CREST_PATHS := {
	0: "res://assets/icons/ui/crest_orc.png",
	1: "res://assets/icons/ui/crest_pirate.png",
	2: "res://assets/icons/ui/crest_dark_elf.png",
}

# Faction data for display
const FACTION_DISPLAY := {
	0: {  # ORC
		"name": "Orc Horde",
		"color": Color(0.8, 0.3, 0.2),
		"icon": "WAAAGH!",
		"desc": "[b]Orc Horde[/b]\n\n[color=orange]Special Mechanic: WAAAGH! Battle Fury[/color]\n\nWin battles to accumulate fury. At 100, triggers berserker rage:\n- ATK +50%, DEF -20%\n- Lasts 3 turns\n- Fury decays if idle\n\n[color=yellow]Unique Troops:[/color] Orc Infantry / Troll / War Boar Rider\n\n[color=gray]Difficulty: ★★☆ Aggressive playstyle[/color]",
		"start_bonus": "Starting troops +5, Territory grain +20%",
	},
	1: {  # PIRATE
		"name": "Pirate Alliance",
		"color": Color(0.3, 0.5, 0.8),
		"icon": "PLUNDER",
		"desc": "[b]Pirate Alliance[/b]\n\n[color=orange]Special Mechanic: Plunder & Slave Trade[/color]\n\nVictories yield bonus gold and capture prisoners as slaves:\n- Assign slaves to mines/farms for extra output\n- Buy and sell slaves on the black market\n- Dark elves can convert slaves into elite troops\n\n[color=yellow]Unique Troops:[/color] Pirate Cutlass / Musketeer / Cannoneer\n\n[color=gray]Difficulty: ★★★ Economy playstyle[/color]",
		"start_bonus": "Starting gold +30, Black Market unlocked",
	},
	2: {  # DARK_ELF
		"name": "Dark Elf Council",
		"color": Color(0.5, 0.2, 0.7),
		"icon": "SHADOW",
		"desc": "[b]Dark Elf Council[/b]\n\n[color=orange]Special Mechanic: Slave Altar & Shadow Conversion[/color]\n\nConvert slaves into elite Dark Elf warriors at the Shadow Altar:\n- Every 5 slaves yields 1 Dark Elf Warrior\n- Altar sacrifice every 3 turns boosts army ATK\n- Shadow Walker requires training unlock\n\n[color=yellow]Unique Troops:[/color] Shadow Walker / Dark Elf Assassin / Cold Lizard Rider / Dark Elf Warrior\n\n[color=gray]Difficulty: ★★★ Strategic playstyle[/color]",
		"start_bonus": "Starting slaves +3, Shadow Essence +2",
	},
}


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_MAIN_MENU
	# Load CJK font
	_cjk_font = load("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	# Load pixel art assets
	_bg_texture = _safe_load("res://assets/ui/main_menu_bg.png")
	_logo_texture = _safe_load("res://assets/ui/main_menu_logo.png")
	for fid in CREST_PATHS:
		var tex = _safe_load(CREST_PATHS[fid])
		if tex:
			_crest_textures[fid] = tex
	_build_ui()
	_show_title()


func _safe_load(path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	return null


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

	# Full-screen background — pixel art image or fallback solid color
	if _bg_texture:
		var bg_img := TextureRect.new()
		bg_img.name = "Background"
		bg_img.texture = _bg_texture
		bg_img.anchor_right = 1.0
		bg_img.anchor_bottom = 1.0
		bg_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		root.add_child(bg_img)
	else:
		var bg := ColorRect.new()
		bg.name = "Background"
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		bg.color = Color(0.03, 0.03, 0.06, 1.0)
		root.add_child(bg)

	_build_title_panel()
	_build_faction_panel()
	_build_loading_label()
	_build_credits_panel()


func _build_title_panel() -> void:
	title_panel = PanelContainer.new()
	title_panel.name = "TitlePanel"
	# Center it
	title_panel.anchor_left = 0.5
	title_panel.anchor_right = 0.5
	title_panel.anchor_top = 0.5
	title_panel.anchor_bottom = 0.5
	title_panel.offset_left = -220
	title_panel.offset_right = 220
	title_panel.offset_top = -200
	title_panel.offset_bottom = 200
	var style: StyleBox = UITheme.make_content_style() if UITheme else null
	if not style:
		var sf := StyleBoxFlat.new()
		sf.bg_color = Color(0.08, 0.06, 0.12, 0.80)
		sf.border_color = Color(0.6, 0.3, 0.1)
		sf.set_border_width_all(2)
		sf.set_corner_radius_all(12)
		sf.set_content_margin_all(24)
		style = sf
	title_panel.add_theme_stylebox_override("panel", style)
	root.add_child(title_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	title_panel.add_child(vbox)

	# Logo image or fallback text title
	if _logo_texture:
		var logo_rect := TextureRect.new()
		logo_rect.texture = _logo_texture
		logo_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		logo_rect.custom_minimum_size = Vector2(380, 120)
		vbox.add_child(logo_rect)
	else:
		var title := Label.new()
		title.text = "DARK TIDE"
		_apply_font_to_label(title)
		title.add_theme_font_size_override("font_size", 42)
		title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.15))
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 20)
	vbox.add_child(sep)

	# Buttons
	btn_new_game = _make_menu_button("New Campaign")
	btn_new_game.pressed.connect(_on_new_game)
	vbox.add_child(btn_new_game)

	btn_continue = _make_menu_button("Continue")
	btn_continue.pressed.connect(_on_continue)
	vbox.add_child(btn_continue)

	btn_settings = _make_menu_button("Settings")
	btn_settings.pressed.connect(_on_settings)
	vbox.add_child(btn_settings)

	btn_credits = _make_menu_button("Credits")
	btn_credits.pressed.connect(_on_credits)
	vbox.add_child(btn_credits)

	# CG Gallery button
	var btn_gallery := _make_menu_button("CG Gallery")
	btn_gallery.pressed.connect(_on_cg_gallery)
	vbox.add_child(btn_gallery)

	# Version
	version_label = Label.new()
	version_label.text = "v3.7.0-pixel"
	_apply_font_to_label(version_label)
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(version_label)

	# NG+ indicator
	if NgPlusManager.is_ngplus():
		var ngplus_label := Label.new()
		ngplus_label.text = "NG+%d  (Total Wins: %d)" % [NgPlusManager.get_level(), NgPlusManager.get_total_wins()]
		_apply_font_to_label(ngplus_label)
		ngplus_label.add_theme_font_size_override("font_size", 13)
		ngplus_label.add_theme_color_override("font_color", Color(0.85, 0.65, 0.15))
		ngplus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(ngplus_label)


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
	var fstyle: StyleBox = UITheme.make_info_panel_style() if UITheme else null
	if not fstyle:
		var sf := StyleBoxFlat.new()
		sf.bg_color = Color(0.05, 0.04, 0.08, 0.97)
		sf.border_color = Color(0.5, 0.3, 0.15)
		sf.set_border_width_all(2)
		sf.set_corner_radius_all(10)
		sf.set_content_margin_all(16)
		fstyle = sf
	faction_panel.add_theme_stylebox_override("panel", fstyle)
	root.add_child(faction_panel)

	_build_faction_panel_content()


func _build_faction_panel_content() -> void:
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 20)
	faction_panel.add_child(main_hbox)

	# Left side: faction list
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	left_vbox.custom_minimum_size = Vector2(300, 0)
	main_hbox.add_child(left_vbox)

	var header := Label.new()
	header.text = "Choose Your Faction"
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

	# Create faction buttons with crest icons
	for fid in FACTION_DISPLAY.keys():
		var fdata: Dictionary = FACTION_DISPLAY[fid]
		var btn_hbox := HBoxContainer.new()
		btn_hbox.add_theme_constant_override("separation", 8)

		# Crest icon inside button
		var btn := Button.new()
		btn.text = "  %s  %s" % [fdata["icon"], fdata["name"]]
		btn.custom_minimum_size = Vector2(280, 56)
		if _cjk_font:
			btn.add_theme_font_override("font", _cjk_font)
		btn.add_theme_font_size_override("font_size", 15)
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

	btn_back = _make_menu_button("Back")
	btn_back.custom_minimum_size = Vector2(120, 38)
	btn_back.pressed.connect(_on_back_to_title)
	btn_row.add_child(btn_back)

	btn_confirm = _make_menu_button("Start Campaign")
	btn_confirm.custom_minimum_size = Vector2(160, 38)
	btn_confirm.disabled = true
	btn_confirm.pressed.connect(_on_confirm_faction)
	btn_row.add_child(btn_confirm)

	# Map mode toggle
	var map_row := HBoxContainer.new()
	map_row.add_theme_constant_override("separation", 8)
	map_row.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.add_child(map_row)
	var map_toggle := CheckBox.new()
	map_toggle.text = "Fixed Map (55 territories, 7 nations)"
	map_toggle.button_pressed = false
	if _cjk_font:
		map_toggle.add_theme_font_override("font", _cjk_font)
	map_toggle.add_theme_font_size_override("font_size", 12)
	map_toggle.toggled.connect(func(pressed): _use_fixed_map = pressed)
	map_row.add_child(map_toggle)

	# Right side: faction preview with crest + description
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 12)
	main_hbox.add_child(right_vbox)

	# Faction crest display area
	var crest_center := CenterContainer.new()
	crest_center.custom_minimum_size = Vector2(0, 140)
	right_vbox.add_child(crest_center)

	faction_crest_display = TextureRect.new()
	faction_crest_display.custom_minimum_size = Vector2(128, 128)
	faction_crest_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	faction_crest_display.visible = false
	crest_center.add_child(faction_crest_display)

	# Description panel
	faction_preview_panel = PanelContainer.new()
	faction_preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.06, 0.05, 0.1, 0.9)
	preview_style.border_color = Color(0.3, 0.25, 0.2)
	preview_style.set_border_width_all(1)
	preview_style.set_corner_radius_all(8)
	preview_style.set_content_margin_all(16)
	faction_preview_panel.add_theme_stylebox_override("panel", preview_style)
	right_vbox.add_child(faction_preview_panel)

	faction_desc_label = RichTextLabel.new()
	faction_desc_label.bbcode_enabled = true
	faction_desc_label.fit_content = false
	faction_desc_label.scroll_active = true
	_apply_font_to_rtl(faction_desc_label)
	faction_desc_label.add_theme_font_size_override("normal_font_size", 14)
	faction_desc_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.88))
	faction_desc_label.text = "[center][color=gray]Select a faction from the left[/color][/center]"
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
	loading_label.text = "Generating World..."
	loading_label.add_theme_font_size_override("font_size", 20)
	loading_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.2))
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.visible = false
	root.add_child(loading_label)


func _build_credits_panel() -> void:
	credits_panel = PanelContainer.new()
	credits_panel.name = "CreditsPanel"
	credits_panel.anchor_left = 0.5
	credits_panel.anchor_right = 0.5
	credits_panel.anchor_top = 0.5
	credits_panel.anchor_bottom = 0.5
	credits_panel.offset_left = -320
	credits_panel.offset_right = 320
	credits_panel.offset_top = -260
	credits_panel.offset_bottom = 260
	credits_panel.visible = false
	var cstyle := StyleBoxFlat.new()
	cstyle.bg_color = Color(0.06, 0.05, 0.1, 0.95)
	cstyle.border_color = Color(0.6, 0.3, 0.1)
	cstyle.set_border_width_all(2)
	cstyle.set_corner_radius_all(12)
	cstyle.set_content_margin_all(20)
	credits_panel.add_theme_stylebox_override("panel", cstyle)
	root.add_child(credits_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 12)
	credits_panel.add_child(outer_vbox)

	# Title
	var cred_title := Label.new()
	cred_title.text = "CREDITS"
	_apply_font_to_label(cred_title)
	cred_title.add_theme_font_size_override("font_size", 28)
	cred_title.add_theme_color_override("font_color", Color(0.85, 0.55, 0.15))
	cred_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer_vbox.add_child(cred_title)

	var sep := HSeparator.new()
	outer_vbox.add_child(sep)

	# Scrollable credits content
	credits_scroll = ScrollContainer.new()
	credits_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(credits_scroll)

	var cred_rtl := RichTextLabel.new()
	cred_rtl.bbcode_enabled = true
	cred_rtl.fit_content = true
	cred_rtl.scroll_active = false
	_apply_font_to_rtl(cred_rtl)
	cred_rtl.add_theme_font_size_override("normal_font_size", 14)
	cred_rtl.add_theme_color_override("default_color", Color(0.85, 0.85, 0.88))
	cred_rtl.text = _get_credits_text()
	credits_scroll.add_child(cred_rtl)

	# Back button
	var btn_row := CenterContainer.new()
	outer_vbox.add_child(btn_row)
	btn_credits_back = _make_menu_button("Back")
	btn_credits_back.custom_minimum_size = Vector2(140, 38)
	btn_credits_back.pressed.connect(_on_credits_back)
	btn_row.add_child(btn_credits_back)


func _get_credits_text() -> String:
	return """[center][color=orange][b]DARK TIDE[/b][/color]
[color=gray]暗潮 — Sengoku Rance Style Turn-Based Strategy[/color][/center]

[color=yellow][b]Game Design & Programming[/b][/color]
magicy565

[color=yellow][b]Art Direction[/b][/color]
Character Illustrations & Chibi Animations
UI Design & Pixel Art Assets

[color=yellow][b]Systems Design[/b][/color]
Combat System (Sengoku Rance 07 style)
Strategic Map (Total War: Warhammer style)
Faction AI & Diplomacy
Weather & Season System
Espionage & Intelligence Network
Supply Logistics
Hero Leveling & Equipment Forge

[color=yellow][b]Characters[/b][/color]
[color=#cc6666]Rin (凛)[/color] — Sworn Knight
[color=#6666cc]Yukino (雪乃)[/color] — White Lily Priestess
[color=#cc6633]Momiji (紅葉)[/color] — Maple Cavalry
[color=#66cccc]Hyouka (冰華)[/color] — Temple Guardian
[color=#33cc99]Suirei (翠玲)[/color] — Moonlight Archer
[color=#9966cc]Gekka (月華)[/color] — Lunar Attendant
[color=#669966]Hakagure (叶隐)[/color] — Shadow Shinobi
[color=#6699cc]Sou (蒼)[/color] — Star Disciple
[color=#cc66cc]Shion (紫苑)[/color] — Chrono Guardian
[color=#cc3333]Homura (焔)[/color] — Flame Dancer
[color=#3399cc]Sara (沙羅)[/color] — Desert Wanderer
[color=#cc9933]Mei (芽衣)[/color] — Alchemist
[color=#cc6699]Kaede (楓)[/color] — Blade Dancer
[color=#cc3366]Akane (茜)[/color] — Blood Moon
[color=#ff9966]Hanabi (花火)[/color] — Fireworks Master
[color=#33cccc]Hibiki (響)[/color] — Sound Weaver
[color=#cc9966]Youya (陽夜)[/color] — Dawn Seeker
[color=#3366cc]Shion Pirate (紫苑·海盗)[/color] — Corsair

[color=yellow][b]Engine[/b][/color]
Godot Engine 4.2+
GDScript

[color=yellow][b]Special Thanks[/b][/color]
Sengoku Rance (AliceSoft) — for the timeless battle system design
Total War: Warhammer (Creative Assembly) — for the strategic map inspiration
The Godot community — for the incredible open-source engine

[center][color=gray]© 2026 Dark Tide Project[/color][/center]"""


# ═══════════════════════════════════════════════════════════════
#                       PHASE SWITCHING
# ═══════════════════════════════════════════════════════════════

func _show_title() -> void:
	_phase = "title"
	title_panel.visible = true
	faction_panel.visible = false
	loading_label.visible = false
	credits_panel.visible = false
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
		EventBus.message_log.emit("[color=red]Failed to load save[/color]")
		_show_title()


func _on_settings() -> void:
	var sp = get_tree().root.find_child("SettingsPanel", true, false)
	if sp and sp.has_method("toggle_settings"):
		sp.toggle_settings()


func _on_credits() -> void:
	_phase = "credits"
	title_panel.visible = false
	faction_panel.visible = false
	loading_label.visible = false
	credits_panel.visible = true


func _on_credits_back() -> void:
	_show_title()


func _on_cg_gallery() -> void:
	if CGGalleryPanel != null:
		CGGalleryPanel.show_gallery()


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
	game_started.emit(_selected_faction, _use_fixed_map)
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
	# Show faction crest
	if _crest_textures.has(_selected_faction):
		faction_crest_display.texture = _crest_textures[_selected_faction]
		faction_crest_display.visible = true
	else:
		faction_crest_display.visible = false
	# Update description text
	var text: String = fdata["desc"]
	text += "\n\n[color=lime]Starting Bonus: %s[/color]" % fdata["start_bonus"]
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
