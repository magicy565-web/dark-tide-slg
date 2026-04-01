## hero_panel.gd - Hero management UI for Dark Tide SLG (v0.9.1)
## Provides hero list, detail view, equipment management, and prison management
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── State ──
var _visible: bool = false
var _current_tab: String = "roster"  # "roster", "prison", "detail"
var _selected_hero_id: String = ""

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button

# Tab buttons
var tab_container: HBoxContainer
var btn_tab_roster: Button
var btn_tab_prison: Button

# Content area
var content_scroll: ScrollContainer
var content_container: VBoxContainer

# Detail panel (right side)
var detail_panel: PanelContainer
var detail_container: VBoxContainer
var detail_visible: bool = false

# Cached hero data
var _hero_nodes: Array = []


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_HERO_PANEL
	_build_ui()
	_connect_signals()
	hide_panel()


func _connect_signals() -> void:
	EventBus.hero_captured.connect(_on_hero_changed)
	EventBus.hero_recruited.connect(_on_hero_changed)
	EventBus.hero_affection_changed.connect(_on_hero_affection_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.game_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H:
			if _visible:
				hide_panel()
			else:
				show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			hide_panel()
			get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════
#                          BUILD UI
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "HeroRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dim background
	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.5)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	# Main panel - takes most of the screen
	main_panel = PanelContainer.new()
	main_panel.anchor_right = 1.0
	main_panel.anchor_bottom = 1.0
	main_panel.offset_left = 30
	main_panel.offset_right = -30
	main_panel.offset_top = 30
	main_panel.offset_bottom = -30
	var style: StyleBox
	if UITheme.frame_content:
		style = UITheme.make_content_style()
	else:
		var sf := StyleBoxFlat.new()
		sf.bg_color = ColorTheme.BG_SECONDARY
		sf.border_color = ColorTheme.BORDER_DEFAULT
		sf.set_border_width_all(2)
		sf.set_corner_radius_all(10)
		sf.set_content_margin_all(12)
		style = sf
	main_panel.add_theme_stylebox_override("panel", style)
	root.add_child(main_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	main_panel.add_child(outer_vbox)

	# Header row
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header_row)

	header_label = Label.new()
	header_label.text = "Hero Management"
	header_label.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING + 2)
	header_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)

	btn_close = Button.new()
	btn_close.text = "X"
	btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	# Tab buttons
	tab_container = HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(tab_container)

	btn_tab_roster = _make_tab_button("Roster")
	btn_tab_roster.pressed.connect(_on_tab_roster)
	tab_container.add_child(btn_tab_roster)

	btn_tab_prison = _make_tab_button("Prison")
	btn_tab_prison.pressed.connect(_on_tab_prison)
	tab_container.add_child(btn_tab_prison)

	# Separator
	var sep := HSeparator.new()
	outer_vbox.add_child(sep)

	# Content area: split into list (left) + detail (right)
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 10)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_hbox)

	# Left: scrollable hero list
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_child(content_scroll)

	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 4)
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(content_container)

	# Right: detail panel
	detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(380, 0)
	detail_panel.visible = false
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = ColorTheme.BG_SECONDARY
	detail_style.border_color = ColorTheme.BORDER_DEFAULT
	detail_style.set_border_width_all(1)
	detail_style.set_corner_radius_all(6)
	detail_style.set_content_margin_all(12)
	detail_panel.add_theme_stylebox_override("panel", detail_style)
	content_hbox.add_child(detail_panel)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(detail_scroll)

	detail_container = VBoxContainer.new()
	detail_container.add_theme_constant_override("separation", 6)
	detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_container)


# ═══════════════════════════════════════════════════════════════
#                       PUBLIC API
# ═══════════════════════════════════════════════════════════════

func show_panel() -> void:
	_visible = true
	root.visible = true
	ColorTheme.animate_panel_open(main_panel)
	_current_tab = "roster"
	_refresh_list()
	_update_tab_highlight()


func hide_panel() -> void:
	AudioManager.play_ui_cancel()
	_visible = false
	root.visible = false
	_selected_hero_id = ""


func is_panel_visible() -> bool:
	return _visible


# ═══════════════════════════════════════════════════════════════
#                       TAB MANAGEMENT
# ═══════════════════════════════════════════════════════════════

func _on_tab_roster() -> void:
	AudioManager.play_ui_click()
	_current_tab = "roster"
	_selected_hero_id = ""
	detail_panel.visible = false
	_refresh_list()
	_update_tab_highlight()


func _on_tab_prison() -> void:
	AudioManager.play_ui_click()
	_current_tab = "prison"
	_selected_hero_id = ""
	detail_panel.visible = false
	_refresh_list()
	_update_tab_highlight()


func _update_tab_highlight() -> void:
	_set_tab_active(btn_tab_roster, _current_tab == "roster")
	_set_tab_active(btn_tab_prison, _current_tab == "prison")


func _set_tab_active(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT)
		var style := StyleBoxFlat.new()
		style.bg_color = ColorTheme.BTN_NORMAL_BG
		style.border_color = ColorTheme.ACCENT_GOLD
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", style)
	else:
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_stylebox_override("normal")


# ═══════════════════════════════════════════════════════════════
#                       LIST REFRESH
# ═══════════════════════════════════════════════════════════════

func _refresh_list() -> void:
	_clear_list()

	if _current_tab == "roster":
		_build_roster_list()
	elif _current_tab == "prison":
		_build_prison_list()


func _clear_list() -> void:
	for node in _hero_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_hero_nodes.clear()


func _build_roster_list() -> void:
	var pid: int = GameManager.get_human_player_id()
	var recruited: Array = HeroSystem.get_recruited_heroes(pid)

	if recruited.is_empty():
		var lbl := _make_info_label("No recruited heroes")
		content_container.add_child(lbl)
		_hero_nodes.append(lbl)
		return

	# Header
	var header := _make_info_label("Recruited Heroes (%d)" % recruited.size(), Color(0.8, 0.7, 0.4))
	content_container.add_child(header)
	_hero_nodes.append(header)

	for hero_id in recruited:
		var card := _build_hero_card(hero_id, "recruited")
		content_container.add_child(card)
		_hero_nodes.append(card)


func _build_prison_list() -> void:
	var pid: int = GameManager.get_human_player_id()
	var prisoners: Array = HeroSystem.get_prison_heroes(pid)

	if prisoners.is_empty():
		var lbl := _make_info_label("No prisoners")
		content_container.add_child(lbl)
		_hero_nodes.append(lbl)
		return

	var prison_cap: int = HeroSystem.PRISON_CAPACITY if "PRISON_CAPACITY" in HeroSystem else FactionData.PRISON_CAPACITY
	var header := _make_info_label("Prisoners (%d/%d)" % [prisoners.size(), prison_cap], Color(0.8, 0.5, 0.3))
	content_container.add_child(header)
	_hero_nodes.append(header)

	for hero_id in prisoners:
		var card := _build_hero_card(hero_id, "prison")
		content_container.add_child(card)
		_hero_nodes.append(card)


# ═══════════════════════════════════════════════════════════════
#                       HERO CARD
# ═══════════════════════════════════════════════════════════════

func _build_hero_card(hero_id: String, context: String) -> PanelContainer:
	var hero_def: Dictionary = FactionData.HEROES.get(hero_id, {})
	var combat_stats: Dictionary = HeroSystem.get_hero_combat_stats(hero_id) if HeroSystem.has_method("get_hero_combat_stats") else {}
	var affection: int = HeroSystem.get_affection(hero_id) if HeroSystem.has_method("get_affection") else 0

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 72)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = ColorTheme.BG_CARD
	card_style.border_color = ColorTheme.BORDER_DIM
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card_style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", card_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# Left: portrait thumbnail
	var portrait_path: String = FactionData.HERO_PORTRAITS.get(hero_id, "") if "HERO_PORTRAITS" in FactionData else ""
	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		var portrait_tex: Texture2D = load(portrait_path)
		if portrait_tex != null:
			var portrait := TextureRect.new()
			portrait.texture = portrait_tex
			portrait.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.custom_minimum_size = Vector2(56, 56)
			hbox.add_child(portrait)
		else:
			var portrait_placeholder := ColorRect.new()
			portrait_placeholder.custom_minimum_size = Vector2(56, 56)
			portrait_placeholder.color = _get_faction_color(hero_def.get("faction", "")) * 0.4
			hbox.add_child(portrait_placeholder)
	else:
		var portrait_placeholder := ColorRect.new()
		portrait_placeholder.custom_minimum_size = Vector2(56, 56)
		portrait_placeholder.color = _get_faction_color(hero_def.get("faction", "")) * 0.4
		hbox.add_child(portrait_placeholder)

	# Info column
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Name + faction
	var name_text: String = hero_def.get("name", hero_id)
	var faction_text: String = hero_def.get("faction", "")
	var name_color: Color = _get_faction_color(faction_text)

	var name_lbl := Label.new()
	name_lbl.text = "%s  [%s]" % [name_text, faction_text]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", name_color)
	info_vbox.add_child(name_lbl)

	# Stats line
	var atk: int = combat_stats.get("atk", hero_def.get("base_atk", 0))
	var def_val: int = combat_stats.get("def", hero_def.get("base_def", 0))
	var int_val: int = combat_stats.get("int", hero_def.get("base_int", 0))
	var spd: int = combat_stats.get("spd", hero_def.get("base_spd", 0))

	var aff_bonuses: Dictionary = _get_affection_bonuses(hero_id)
	var stats_lbl := RichTextLabel.new()
	stats_lbl.bbcode_enabled = true
	stats_lbl.fit_content = true
	stats_lbl.scroll_active = false
	stats_lbl.custom_minimum_size = Vector2(0, 18)
	stats_lbl.add_theme_font_size_override("normal_font_size", 12)
	var stats_text: String = ""
	stats_text += _format_stat_with_bonus("ATK", atk, aff_bonuses["atk"])
	stats_text += "  " + _format_stat_with_bonus("DEF", def_val, aff_bonuses["def"])
	stats_text += "  INT:%d  SPD:%d" % [int_val, spd]
	if aff_bonuses["atk"] > 0 or aff_bonuses["def"] > 0:
		stats_text = stats_text.replace("(+", "[color=lime](+").replace(")", ")[/color]")
	stats_lbl.clear()
	stats_lbl.append_text("[color=#b3b3bf]%s[/color]" % stats_text)
	info_vbox.add_child(stats_lbl)

	# Affection / corruption
	if context == "recruited":
		var aff_text: String = "Affection: "
		for i in range(5):
			if i < affection:
				aff_text += "[color=red]♥[/color]"
			else:
				aff_text += "[color=gray]♡[/color]"
		var aff_lbl := RichTextLabel.new()
		aff_lbl.bbcode_enabled = true
		aff_lbl.fit_content = true
		aff_lbl.scroll_active = false
		aff_lbl.clear()
		aff_lbl.append_text(aff_text)
		aff_lbl.custom_minimum_size = Vector2(0, 20)
		aff_lbl.add_theme_font_size_override("normal_font_size", 12)
		info_vbox.add_child(aff_lbl)
	elif context == "prison":
		var corruption: int = HeroSystem.get_corruption(hero_id) if HeroSystem.has_method("get_corruption") else 0
		var corrupt_max: int = hero_def.get("corrupt_threshold", 100)
		var corrupt_lbl := Label.new()
		corrupt_lbl.text = "Corruption: %d/%d" % [corruption, corrupt_max]
		corrupt_lbl.add_theme_font_size_override("font_size", 12)
		corrupt_lbl.add_theme_color_override("font_color", Color(0.7, 0.4, 0.6))
		info_vbox.add_child(corrupt_lbl)

	# Right: action buttons
	var btn_vbox := VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(btn_vbox)

	# Detail button
	var btn_detail := Button.new()
	btn_detail.text = "Detail"
	btn_detail.custom_minimum_size = Vector2(80, 28)
	btn_detail.add_theme_font_size_override("font_size", 12)
	btn_detail.pressed.connect(_on_hero_detail.bind(hero_id))
	btn_vbox.add_child(btn_detail)

	if context == "prison":
		# Recruit button
		var can_recruit: bool = HeroSystem.can_recruit(hero_id) if HeroSystem.has_method("can_recruit") else false
		var btn_recruit := Button.new()
		btn_recruit.text = "Recruit"
		btn_recruit.custom_minimum_size = Vector2(80, 28)
		btn_recruit.add_theme_font_size_override("font_size", 12)
		btn_recruit.disabled = not can_recruit
		btn_recruit.pressed.connect(_on_recruit_hero.bind(hero_id))
		btn_vbox.add_child(btn_recruit)

		# Release button
		var btn_release := Button.new()
		btn_release.text = "Release"
		btn_release.custom_minimum_size = Vector2(80, 28)
		btn_release.add_theme_font_size_override("font_size", 12)
		btn_release.pressed.connect(_on_release_hero.bind(hero_id))
		btn_vbox.add_child(btn_release)

		# Execute button (red)
		var btn_execute := Button.new()
		btn_execute.text = "Execute"
		btn_execute.custom_minimum_size = Vector2(80, 28)
		btn_execute.add_theme_font_size_override("font_size", 12)
		btn_execute.add_theme_color_override("font_color", ColorTheme.TEXT_RED)
		btn_execute.pressed.connect(_on_execute_hero.bind(hero_id))
		btn_vbox.add_child(btn_execute)

		# Ransom button (gold)
		var btn_ransom := Button.new()
		btn_ransom.text = "Ransom"
		btn_ransom.custom_minimum_size = Vector2(80, 28)
		btn_ransom.add_theme_font_size_override("font_size", 12)
		btn_ransom.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
		btn_ransom.pressed.connect(_on_ransom_hero.bind(hero_id))
		btn_vbox.add_child(btn_ransom)

		# Exile button (gray)
		var btn_exile := Button.new()
		btn_exile.text = "Exile"
		btn_exile.custom_minimum_size = Vector2(80, 28)
		btn_exile.add_theme_font_size_override("font_size", 12)
		btn_exile.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		btn_exile.pressed.connect(_on_exile_hero.bind(hero_id))
		btn_vbox.add_child(btn_exile)

	elif context == "recruited":
		# Gift button (increase affection)
		var btn_gift := Button.new()
		btn_gift.text = "Gift"
		btn_gift.custom_minimum_size = Vector2(80, 28)
		btn_gift.add_theme_font_size_override("font_size", 12)
		btn_gift.pressed.connect(_on_gift_hero.bind(hero_id))
		btn_vbox.add_child(btn_gift)

	return card


# ═══════════════════════════════════════════════════════════════
#                    DETAIL VIEW
# ═══════════════════════════════════════════════════════════════

func _on_hero_detail(hero_id: String) -> void:
	AudioManager.play_ui_click()
	_selected_hero_id = hero_id
	detail_panel.visible = true
	_refresh_detail()


func _refresh_detail() -> void:
	# Clear detail
	for child in detail_container.get_children():
		child.queue_free()

	if _selected_hero_id == "":
		return

	var hero_def: Dictionary = FactionData.HEROES.get(_selected_hero_id, {})
	var combat_stats: Dictionary = HeroSystem.get_hero_combat_stats(_selected_hero_id) if HeroSystem.has_method("get_hero_combat_stats") else {}

	# Name header
	var name_lbl := Label.new()
	name_lbl.text = hero_def.get("name", _selected_hero_id)
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", _get_faction_color(hero_def.get("faction", "")))
	detail_container.add_child(name_lbl)

	# Portrait in detail view
	var detail_portrait_path: String = FactionData.HERO_PORTRAITS.get(_selected_hero_id, "") if "HERO_PORTRAITS" in FactionData else ""
	if detail_portrait_path != "" and ResourceLoader.exists(detail_portrait_path):
		var detail_portrait_tex: Texture2D = load(detail_portrait_path)
		if detail_portrait_tex != null:
			var detail_portrait := TextureRect.new()
			detail_portrait.texture = detail_portrait_tex
			detail_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			detail_portrait.custom_minimum_size = Vector2(0, 140)
			detail_container.add_child(detail_portrait)

	# Description
	var desc_lbl := RichTextLabel.new()
	desc_lbl.bbcode_enabled = true
	desc_lbl.fit_content = true
	desc_lbl.scroll_active = false
	desc_lbl.clear()
	desc_lbl.append_text(hero_def.get("desc", ""))
	desc_lbl.custom_minimum_size = Vector2(0, 40)
	desc_lbl.add_theme_font_size_override("normal_font_size", 12)
	desc_lbl.add_theme_color_override("default_color", ColorTheme.TEXT_DIM)
	detail_container.add_child(desc_lbl)

	var sep := HSeparator.new()
	detail_container.add_child(sep)

	# Stats
	var stats_title := _make_info_label("Stats", Color(0.85, 0.75, 0.4))
	detail_container.add_child(stats_title)

	var atk: int = combat_stats.get("atk", hero_def.get("base_atk", 0))
	var def_val: int = combat_stats.get("def", hero_def.get("base_def", 0))
	var int_val: int = combat_stats.get("int", hero_def.get("base_int", 0))
	var spd: int = combat_stats.get("spd", hero_def.get("base_spd", 0))

	var detail_aff_bonuses: Dictionary = _get_affection_bonuses(_selected_hero_id)
	_add_stat_row("ATK", atk, Color(1.0, 0.5, 0.3), detail_aff_bonuses["atk"])
	_add_stat_row("DEF", def_val, Color(0.3, 0.7, 1.0), detail_aff_bonuses["def"])
	_add_stat_row("INT", int_val, Color(0.7, 0.4, 1.0), 0)
	_add_stat_row("SPD", spd, Color(0.3, 1.0, 0.5), 0)

	# Skill section
	var sep2 := HSeparator.new()
	detail_container.add_child(sep2)

	var skill_title := _make_info_label("Active Skill", Color(0.85, 0.75, 0.4))
	detail_container.add_child(skill_title)

	var skill_data: Dictionary = FactionData.HERO_SKILL_DEFS.get(_selected_hero_id, {}) if "HERO_SKILL_DEFS" in FactionData else {}
	if not skill_data.is_empty():
		var skill_name_lbl := Label.new()
		skill_name_lbl.text = "%s (CD: %d turns)" % [skill_data.get("desc", "???"), skill_data.get("cooldown", 0)]
		skill_name_lbl.add_theme_font_size_override("font_size", 12)
		skill_name_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		skill_name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		detail_container.add_child(skill_name_lbl)

		# Cooldown status
		if HeroSystem.has_method("is_skill_ready"):
			var ready: bool = HeroSystem.is_skill_ready(_selected_hero_id)
			var cd_lbl := Label.new()
			if ready:
				cd_lbl.text = "Status: Ready"
				cd_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
			else:
				var remaining: int = HeroSystem.get_skill_cooldown(_selected_hero_id) if HeroSystem.has_method("get_skill_cooldown") else 0
				cd_lbl.text = "Cooldown: %d turns" % remaining
				cd_lbl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.3))
			cd_lbl.add_theme_font_size_override("font_size", 11)
			detail_container.add_child(cd_lbl)
	else:
		var no_skill := _make_info_label("No skill data", Color(0.5, 0.5, 0.55))
		detail_container.add_child(no_skill)

	# Equipment section
	var sep3 := HSeparator.new()
	detail_container.add_child(sep3)

	var equip_title := _make_info_label("Equipment", Color(0.85, 0.75, 0.4))
	detail_container.add_child(equip_title)

	_build_equipment_slots()


func _build_equipment_slots() -> void:
	# SR07-style: single item slot per hero
	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 8)
	detail_container.add_child(slot_row)

	var slot_lbl := Label.new()
	slot_lbl.text = "Item:"
	slot_lbl.custom_minimum_size = Vector2(50, 0)
	slot_lbl.add_theme_font_size_override("font_size", 12)
	slot_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	slot_row.add_child(slot_lbl)

	var equip_id: String = ""
	if HeroSystem.has_method("get_hero_equipment"):
		var equips: Dictionary = HeroSystem.get_hero_equipment(_selected_hero_id)
		equip_id = equips.get("item", "")

	if equip_id != "":
		var equip_def: Dictionary = FactionData.EQUIPMENT_DEFS.get(equip_id, {}) if "EQUIPMENT_DEFS" in FactionData else {}
		var equip_name := Label.new()
		equip_name.text = equip_def.get("name", equip_id)
		equip_name.add_theme_font_size_override("font_size", 12)
		var rarity: String = equip_def.get("rarity", "common")
		equip_name.add_theme_color_override("font_color", _get_rarity_color(rarity))
		equip_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_row.add_child(equip_name)

		var btn_unequip := Button.new()
		btn_unequip.text = "Unequip"
		btn_unequip.custom_minimum_size = Vector2(56, 24)
		btn_unequip.add_theme_font_size_override("font_size", 11)
		btn_unequip.pressed.connect(_on_unequip.bind(_selected_hero_id, "item"))
		slot_row.add_child(btn_unequip)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "-- Empty --"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_row.add_child(empty_lbl)

		var btn_equip := Button.new()
		btn_equip.text = "Equip"
		btn_equip.custom_minimum_size = Vector2(56, 24)
		btn_equip.add_theme_font_size_override("font_size", 11)
		btn_equip.pressed.connect(_on_equip_slot.bind(_selected_hero_id, "item"))
		slot_row.add_child(btn_equip)


# ═══════════════════════════════════════════════════════════════
#                       ACTION CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_recruit_hero(hero_id: String) -> void:
	AudioManager.play_ui_confirm()
	var pid: int = GameManager.get_human_player_id()
	if HeroSystem.has_method("recruit_hero"):
		var result: bool = HeroSystem.recruit_hero(hero_id)
		if result:
			EventBus.message_log.emit("[color=lime]%s has joined your faction![/color]" % FactionData.HEROES.get(hero_id, {}).get("name", hero_id))
			_refresh_list()
			detail_panel.visible = false
		else:
			EventBus.message_log.emit("[color=red]Recruitment conditions not met[/color]")


func _on_release_hero(hero_id: String) -> void:
	AudioManager.play_ui_click()
	if HeroSystem.has_method("release_hero"):
		HeroSystem.release_hero(hero_id)
		EventBus.message_log.emit("%s has been released" % FactionData.HEROES.get(hero_id, {}).get("name", hero_id))
		_refresh_list()
		detail_panel.visible = false


func _on_execute_hero(hero_id: String) -> void:
	AudioManager.play_ui_confirm()
	if HeroSystem.has_method("execute_prisoner"):
		var result: bool = HeroSystem.execute_prisoner(hero_id)
		if result:
			var hero_name: String = FactionData.HEROES.get(hero_id, {}).get("name", hero_id)
			EventBus.message_log.emit("[color=red]%s has been executed![/color]" % hero_name)
			_refresh_list()
			detail_panel.visible = false
		else:
			EventBus.message_log.emit("[color=red]Execution failed[/color]")


func _on_ransom_hero(hero_id: String) -> void:
	AudioManager.play_ui_confirm()
	if HeroSystem.has_method("ransom_prisoner"):
		var result: bool = HeroSystem.ransom_prisoner(hero_id)
		if result:
			var hero_name: String = FactionData.HEROES.get(hero_id, {}).get("name", hero_id)
			EventBus.message_log.emit("[color=yellow]%s has been ransomed![/color]" % hero_name)
			_refresh_list()
			detail_panel.visible = false
		else:
			EventBus.message_log.emit("[color=red]Ransom failed[/color]")


func _on_exile_hero(hero_id: String) -> void:
	AudioManager.play_ui_click()
	if HeroSystem.has_method("exile_prisoner"):
		var result: bool = HeroSystem.exile_prisoner(hero_id)
		if result:
			var hero_name: String = FactionData.HEROES.get(hero_id, {}).get("name", hero_id)
			EventBus.message_log.emit("%s has been exiled" % hero_name)
			_refresh_list()
			detail_panel.visible = false
		else:
			EventBus.message_log.emit("[color=red]Exile failed[/color]")


func _on_gift_hero(hero_id: String) -> void:
	AudioManager.play_ui_click()
	var pid: int = GameManager.get_human_player_id()
	# Gift costs 10 gold
	if ResourceManager.can_afford(pid, {"gold": 10}):
		ResourceManager.spend(pid, {"gold": 10})
		if HeroSystem.has_method("increase_affection"):
			HeroSystem.increase_affection(hero_id, 1)
		EventBus.message_log.emit("Gave a gift to %s (-10 gold)" % FactionData.HEROES.get(hero_id, {}).get("name", hero_id))
		_refresh_list()
		if _selected_hero_id == hero_id:
			_refresh_detail()
	else:
		EventBus.message_log.emit("[color=red]Not enough gold (need 10)[/color]")


func _on_equip_slot(hero_id: String, _slot: String = "") -> void:
	AudioManager.play_ui_click()
	var pid: int = GameManager.get_human_player_id()
	var inventory: Array = ItemManager.get_equipment_items(pid) if ItemManager.has_method("get_equipment_items") else []

	if inventory.is_empty():
		EventBus.message_log.emit("[color=yellow]No equippable items in inventory[/color]")
		return

	if inventory.size() == 1:
		_do_equip_item(hero_id, inventory[0].get("item_id", ""))
	else:
		_show_equip_selection_popup(hero_id, inventory)


func _show_equip_selection_popup(hero_id: String, items: Array) -> void:
	## Display a popup allowing the player to choose which item to equip.
	# Remove any existing popup
	var existing = root.find_child("EquipPopup", false, false)
	if existing:
		existing.queue_free()

	var popup_bg := PanelContainer.new()
	popup_bg.name = "EquipPopup"
	popup_bg.anchor_left = 0.5
	popup_bg.anchor_top = 0.5
	popup_bg.anchor_right = 0.5
	popup_bg.anchor_bottom = 0.5
	popup_bg.custom_minimum_size = Vector2(280, 0)
	popup_bg.offset_left = -140
	popup_bg.offset_top = -100
	popup_bg.offset_right = 140
	popup_bg.offset_bottom = 100

	var style := StyleBoxFlat.new()
	style.bg_color = ColorTheme.BG_SECONDARY
	style.border_color = ColorTheme.BORDER_HIGHLIGHT
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	popup_bg.add_theme_stylebox_override("panel", style)
	root.add_child(popup_bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	popup_bg.add_child(vbox)

	var title := Label.new()
	title.text = "Select Equipment"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", ColorTheme.FONT_SUBHEADING)
	title.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	for item in items:
		var item_id: String = item.get("item_id", "")
		var equip_def: Dictionary = {}
		if "EQUIPMENT_DEFS" in FactionData:
			equip_def = FactionData.EQUIPMENT_DEFS.get(item_id, {})
		var item_name: String = equip_def.get("name", item_id)
		var item_desc: String = equip_def.get("desc", "")

		var btn := Button.new()
		btn.text = item_name
		btn.tooltip_text = item_desc
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var captured_id: String = item_id
		btn.pressed.connect(func():
			_do_equip_item(hero_id, captured_id)
			popup_bg.queue_free()
		)
		vbox.add_child(btn)

	var btn_cancel := Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.pressed.connect(func(): popup_bg.queue_free())
	vbox.add_child(btn_cancel)


func _do_equip_item(hero_id: String, equip_id: String) -> void:
	if HeroSystem.has_method("equip_item"):
		var result: Dictionary = HeroSystem.equip_item(hero_id, equip_id)
		if result.get("ok", false):
			var equip_def: Dictionary = FactionData.EQUIPMENT_DEFS.get(equip_id, {})
			EventBus.message_log.emit("[color=lime]Equipped %s[/color]" % equip_def.get("name", equip_id))
			_refresh_detail()
		else:
			EventBus.message_log.emit("[color=red]Equip failed[/color]")


func _on_unequip(hero_id: String, slot: String) -> void:
	AudioManager.play_ui_click()
	if HeroSystem.has_method("unequip_item"):
		var result: Dictionary = HeroSystem.unequip_item(hero_id, slot)
		if result.get("ok", false):
			EventBus.message_log.emit("Equipment removed")
			_refresh_detail()
		else:
			EventBus.message_log.emit("[color=red]Inventory full, cannot unequip[/color]")


func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()


# ═══════════════════════════════════════════════════════════════
#                       SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_hero_changed(_hero_id: String) -> void:
	if _visible:
		_refresh_list()


func _on_hero_affection_changed(_hero_id: String, _val: int) -> void:
	if _visible and _selected_hero_id == _hero_id:
		_refresh_detail()


# ═══════════════════════════════════════════════════════════════
#                          HELPERS
# ═══════════════════════════════════════════════════════════════

func _add_stat_row(stat_name: String, value: int, color: Color, bonus: int = 0) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	detail_container.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = stat_name
	name_lbl.custom_minimum_size = Vector2(40, 0)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	row.add_child(name_lbl)

	# Bar
	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(160, 16)
	bar_bg.color = ColorTheme.BG_DARK
	row.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	var fill_width: float = clampf(float(value) / 20.0, 0.0, 1.0) * 160.0
	bar_fill.custom_minimum_size = Vector2(fill_width, 16)
	bar_fill.color = color * 0.7
	bar_fill.position = Vector2.ZERO
	# Note: ColorRect in HBox won't overlap; use as visual indicator
	row.add_child(bar_fill)

	var val_lbl := Label.new()
	if bonus > 0:
		val_lbl.text = "%d(+%d)" % [value, bonus]
	else:
		val_lbl.text = str(value)
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", color)
	row.add_child(val_lbl)

	if bonus > 0:
		var bonus_lbl := Label.new()
		bonus_lbl.text = " +%d" % bonus
		bonus_lbl.add_theme_font_size_override("font_size", 11)
		bonus_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		row.add_child(bonus_lbl)


func _make_tab_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 34)
	btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	btn.add_theme_stylebox_override("normal", ColorTheme.make_button_style_flat("normal"))
	btn.add_theme_stylebox_override("hover", ColorTheme.make_button_style_flat("hover"))
	return btn


func _make_info_label(text: String, color: Color = ColorTheme.TEXT_MUTED) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _get_faction_color(faction: String) -> Color:
	return ColorTheme.get_faction_color(faction)


func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary": return Color(1.0, 0.7, 0.1)
		"rare": return Color(0.4, 0.6, 1.0)
		"common": return ColorTheme.TEXT_DIM
		_: return ColorTheme.TEXT_DIM

func _get_affection_bonuses(hero_id: String) -> Dictionary:
	var aff: int = HeroSystem.hero_affection.get(hero_id, 0) if "hero_affection" in HeroSystem else 0
	var atk_bonus: int = 0
	var def_bonus: int = 0
	if aff >= 10:
		atk_bonus = 4; def_bonus = 3
	elif aff >= 8:
		atk_bonus = 3; def_bonus = 2
	elif aff >= 5:
		atk_bonus = 2; def_bonus = 1
	elif aff >= 3:
		atk_bonus = 1
	return {"atk": atk_bonus, "def": def_bonus}

func _format_stat_with_bonus(stat_name: String, base_val: int, bonus: int) -> String:
	if bonus > 0:
		return "%s:%d(+%d)" % [stat_name, base_val, bonus]
	return "%s:%d" % [stat_name, base_val]
