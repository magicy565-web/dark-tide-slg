## inventory_panel.gd - Inventory Panel UI for Dark Tide SLG (v1.0)
## Shows player inventory (consumables + equipment), item details, use/discard, and relic display.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── State ──
var _visible: bool = false
var _current_tab: String = "all"  # "all", "consumable", "equipment", "relic", "heroes"
var _selected_item_index: int = -1

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var capacity_label: Label
var btn_close: Button
var tab_container: HBoxContainer
var btn_tab_all: Button
var btn_tab_consumable: Button
var btn_tab_equipment: Button
var btn_tab_relic: Button
var btn_tab_heroes: Button
var hero_equip_container: VBoxContainer
var item_scroll: ScrollContainer
var item_container: VBoxContainer
var detail_panel: PanelContainer
var detail_container: VBoxContainer
var _item_nodes: Array = []

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	layer = UILayerRegistry.LAYER_INFO_PANELS; _build_ui(); _connect_signals(); hide_panel()

func _connect_signals() -> void:
	EventBus.item_acquired.connect(_on_item_changed)
	EventBus.item_used.connect(_on_item_changed)
	EventBus.resources_changed.connect(_on_resources_changed)

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.game_active:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_I:
			if _visible: hide_panel()
			else: show_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _visible:
			hide_panel(); get_viewport().set_input_as_handled()

# ═══════════════ BUILD UI ═══════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "InventoryRoot"
	root.anchor_right = 1.0; root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0; dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0, 0, 0, 0.5)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	main_panel = PanelContainer.new()
	main_panel.anchor_right = 1.0; main_panel.anchor_bottom = 1.0
	main_panel.offset_left = 30; main_panel.offset_right = -30
	main_panel.offset_top = 30; main_panel.offset_bottom = -30
	var style := StyleBoxFlat.new()
	style.bg_color = ColorTheme.BG_SECONDARY
	style.border_color = ColorTheme.BORDER_DEFAULT
	style.set_border_width_all(2); style.set_corner_radius_all(10); style.set_content_margin_all(12)
	main_panel.add_theme_stylebox_override("panel", style)
	root.add_child(main_panel)
	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	main_panel.add_child(outer_vbox)

	# Header
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(header_row)
	header_label = Label.new()
	header_label.text = "Inventory"
	header_label.add_theme_font_size_override("font_size", ColorTheme.FONT_HEADING + 2)
	header_label.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)
	capacity_label = Label.new()
	capacity_label.add_theme_font_size_override("font_size", 14)
	capacity_label.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	header_row.add_child(capacity_label)
	btn_close = Button.new()
	btn_close.text = "X"; btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)

	# Tabs
	tab_container = HBoxContainer.new()
	tab_container.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(tab_container)
	btn_tab_all = _make_tab_button("All")
	btn_tab_all.pressed.connect(func(): _switch_tab("all"))
	tab_container.add_child(btn_tab_all)
	btn_tab_consumable = _make_tab_button("Consumable")
	btn_tab_consumable.pressed.connect(func(): _switch_tab("consumable"))
	tab_container.add_child(btn_tab_consumable)
	btn_tab_equipment = _make_tab_button("Equipment")
	btn_tab_equipment.pressed.connect(func(): _switch_tab("equipment"))
	tab_container.add_child(btn_tab_equipment)
	btn_tab_relic = _make_tab_button("Relic")
	btn_tab_relic.pressed.connect(func(): _switch_tab("relic"))
	tab_container.add_child(btn_tab_relic)
	btn_tab_heroes = _make_tab_button("Heroes")
	btn_tab_heroes.pressed.connect(func(): _switch_tab("heroes"))
	tab_container.add_child(btn_tab_heroes)
	outer_vbox.add_child(HSeparator.new())

	# Content: left list + right detail
	var content_hbox := HBoxContainer.new()
	content_hbox.add_theme_constant_override("separation", 10)
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(content_hbox)
	item_scroll = ScrollContainer.new()
	item_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_hbox.add_child(item_scroll)
	item_container = VBoxContainer.new()
	item_container.add_theme_constant_override("separation", 4)
	item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_scroll.add_child(item_container)

	detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size = Vector2(320, 0); detail_panel.visible = false
	var ds := StyleBoxFlat.new()
	ds.bg_color = ColorTheme.BG_SECONDARY
	ds.border_color = ColorTheme.BORDER_DEFAULT
	ds.set_border_width_all(1); ds.set_corner_radius_all(6); ds.set_content_margin_all(12)
	detail_panel.add_theme_stylebox_override("panel", ds)
	content_hbox.add_child(detail_panel)
	var dscroll := ScrollContainer.new()
	dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(dscroll)
	detail_container = VBoxContainer.new()
	detail_container.add_theme_constant_override("separation", 6)
	detail_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dscroll.add_child(detail_container)

# ═══════════════ PUBLIC API ═══════════════

func show_panel() -> void:
	_visible = true; root.visible = true
	_selected_item_index = -1; detail_panel.visible = false; _refresh()

func hide_panel() -> void:
	AudioManager.play_ui_cancel()
	_visible = false; root.visible = false

func is_panel_visible() -> bool:
	return _visible

# ═══════════════ TABS ═══════════════

func _switch_tab(tab: String) -> void:
	AudioManager.play_ui_click()
	_current_tab = tab; _selected_item_index = -1; detail_panel.visible = false; _refresh()

func _update_tab_highlight() -> void:
	var m: Dictionary = {"all": btn_tab_all, "consumable": btn_tab_consumable, "equipment": btn_tab_equipment, "relic": btn_tab_relic, "heroes": btn_tab_heroes}
	for key in m:
		if key == _current_tab: m[key].add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT)
		else: m[key].remove_theme_color_override("font_color")

# ═══════════════ REFRESH ═══════════════

func _refresh() -> void:
	_update_tab_highlight(); _refresh_list(); _refresh_capacity()

func _refresh_capacity() -> void:
	var pid: int = GameManager.get_human_player_id()
	capacity_label.text = "Capacity: %d/%d" % [ItemManager.get_inventory_size(pid), ItemManager.MAX_ITEMS]

func _refresh_list() -> void:
	for node in _item_nodes:
		if is_instance_valid(node): node.queue_free()
	_item_nodes.clear()
	if _current_tab == "relic":
		_build_relic_display(); return
	if _current_tab == "heroes":
		_refresh_hero_equip_tab(); return
	var pid: int = GameManager.get_human_player_id()
	var items: Array
	match _current_tab:
		"consumable": items = ItemManager.get_consumables(pid)
		"equipment": items = ItemManager.get_equipment_items(pid)
		_: items = ItemManager.get_inventory(pid)
	if items.is_empty():
		var lbl := Label.new()
		lbl.text = "Inventory empty" if _current_tab != "equipment" else "No unequipped items"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_container.add_child(lbl); _item_nodes.append(lbl); return
	for i in range(items.size()):
		var card := _build_item_row(items[i], i)
		item_container.add_child(card); _item_nodes.append(card)

func _build_item_row(item: Dictionary, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = ColorTheme.BG_CARD; s.border_color = ColorTheme.BORDER_DIM
	s.set_border_width_all(1); s.set_corner_radius_all(4); s.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", s)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)
	# Item icon
	var icon_name: String = item.get("icon", "")
	var icon_path: String = ItemManager.get_icon_path(icon_name) if icon_name != "" else ""
	if icon_path != "":
		var icon_tex: Texture2D = load(icon_path)
		if icon_tex != null:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(36, 36)
			hbox.add_child(icon_rect)
		else:
			hbox.add_child(_make_icon_placeholder(item))
	else:
		hbox.add_child(_make_icon_placeholder(item))
	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "???")
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", _get_rarity_color(item.get("rarity", "common")))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)
	var type_lbl := Label.new()
	var tt: String = item.get("type", "unknown")
	match tt:
		"consumable": type_lbl.text = "[Consumable]"
		"equipment": type_lbl.text = "[Equipment]"
		_: type_lbl.text = "[%s]" % tt
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
	hbox.add_child(type_lbl)
	var btn_detail := Button.new()
	btn_detail.text = "Details"; btn_detail.custom_minimum_size = Vector2(60, 26)
	btn_detail.add_theme_font_size_override("font_size", 12)
	btn_detail.pressed.connect(_on_select_item.bind(index, item))
	hbox.add_child(btn_detail)
	return card

func _build_relic_display() -> void:
	var pid: int = GameManager.get_human_player_id()
	var relic: Dictionary = RelicManager.get_relic(pid)
	if relic.is_empty():
		var lbl := Label.new()
		lbl.text = "No relic selected"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
		item_container.add_child(lbl); _item_nodes.append(lbl); return
	var card := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.08, 0.15, 0.95); s.border_color = Color(0.6, 0.4, 0.8)
	s.set_border_width_all(2); s.set_corner_radius_all(6); s.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", s)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)
	var upgraded: bool = relic.get("upgraded", false)
	var nl := Label.new()
	nl.text = relic.get("name", "???") + (" [+]" if upgraded else "")
	nl.add_theme_font_size_override("font_size", 18)
	nl.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
	vbox.add_child(nl)
	var dl := Label.new()
	dl.text = relic.get("desc", ""); dl.add_theme_font_size_override("font_size", 13)
	dl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(dl)
	var effects: Dictionary = relic.get("effect", {})
	if not effects.is_empty():
		var parts: Array = []
		for key in effects: parts.append("%s: %s" % [key, str(effects[key])])
		var el := Label.new()
		el.text = "Effect: %s%s" % [", ".join(parts), " (Doubled)" if upgraded else ""]
		el.add_theme_font_size_override("font_size", 12)
		el.add_theme_color_override("font_color", Color(0.6, 0.8, 0.5))
		vbox.add_child(el)
	if not upgraded:
		var bu := Button.new()
		bu.text = "Upgrade Relic (5 Shadow Essence)"; bu.custom_minimum_size = Vector2(180, 30)
		bu.add_theme_font_size_override("font_size", 12)
		bu.pressed.connect(_on_upgrade_relic)
		vbox.add_child(bu)
	item_container.add_child(card); _item_nodes.append(card)

func _refresh_hero_equip_tab() -> void:
	## SR07-style hero equipment overview: each hero card shows equipped item with swap buttons.
	for c in _item_nodes:
		if is_instance_valid(c): c.queue_free()
	_item_nodes.clear()
	detail_panel.visible = false

	var pid: int = GameManager.get_human_player_id()
	var heroes: Array = HeroSystem.get_recruited_heroes(pid)
	if heroes.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No heroes recruited."
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		item_container.add_child(empty_lbl)
		_item_nodes.append(empty_lbl)
		return

	# Section header
	var header := Label.new()
	header.text = "Hero Equipment (%d heroes)" % heroes.size()
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	item_container.add_child(header)
	_item_nodes.append(header)

	for hero_id in heroes:
		var hero_data: Dictionary = HeroSystem.get_hero_info(hero_id)
		if hero_data.is_empty():
			continue
		var card := PanelContainer.new()
		var cs := ColorTheme.make_panel_style(
			Color(0.08, 0.08, 0.12, 0.85),
			Color(0.3, 0.3, 0.38), 1, 6, 6
		)
		card.add_theme_stylebox_override("panel", cs)
		item_container.add_child(card)
		_item_nodes.append(card)

		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		card.add_child(hb)

		# Hero name + class
		var info_vbox := VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 2)
		info_vbox.custom_minimum_size.x = 120
		hb.add_child(info_vbox)

		var name_lbl := Label.new()
		name_lbl.text = hero_data.get("name", hero_id)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_HEADING)
		info_vbox.add_child(name_lbl)

		var class_lbl := Label.new()
		class_lbl.text = "Lv%d %s" % [hero_data.get("level", 1), hero_data.get("class", "???")]
		class_lbl.add_theme_font_size_override("font_size", 10)
		class_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
		info_vbox.add_child(class_lbl)

		# Equipped item display
		var equip_data: Dictionary = HeroSystem.get_hero_equipment(hero_id)
		var equip_id: String = equip_data.get("item", "")

		var equip_vbox := VBoxContainer.new()
		equip_vbox.add_theme_constant_override("separation", 2)
		equip_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(equip_vbox)

		if equip_id != "":
			var eq_def: Dictionary = FactionData.EQUIPMENT_DEFS.get(equip_id, {})
			var eq_hb := HBoxContainer.new()
			eq_hb.add_theme_constant_override("separation", 4)
			equip_vbox.add_child(eq_hb)

			# Item icon
			var icon_name: String = eq_def.get("icon", "")
			if icon_name != "":
				var icon_path: String = "res://assets/icons/items/%s.webp" % icon_name
				if ResourceLoader.exists(icon_path):
					var tex: Texture2D = load(icon_path)
					if tex:
						var tex_rect := TextureRect.new()
						tex_rect.texture = tex
						tex_rect.custom_minimum_size = Vector2(28, 28)
						tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
						tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						eq_hb.add_child(tex_rect)

			var eq_name := Label.new()
			eq_name.text = eq_def.get("name", equip_id)
			eq_name.add_theme_font_size_override("font_size", 12)
			eq_name.add_theme_color_override("font_color", _get_rarity_color(eq_def.get("rarity", "common")))
			eq_hb.add_child(eq_name)

			# Stats summary
			var stats: Dictionary = eq_def.get("stats", {})
			if not stats.is_empty():
				var parts: Array = []
				for key in stats:
					parts.append("%s+%d" % [key.to_upper(), stats[key]])
				var stat_lbl := Label.new()
				stat_lbl.text = " ".join(parts)
				stat_lbl.add_theme_font_size_override("font_size", 10)
				stat_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
				equip_vbox.add_child(stat_lbl)
		else:
			var empty := Label.new()
			empty.text = "-- Empty --"
			empty.add_theme_font_size_override("font_size", 12)
			empty.add_theme_color_override("font_color", ColorTheme.TEXT_MUTED)
			equip_vbox.add_child(empty)

		# Action buttons
		var btn_hb := VBoxContainer.new()
		btn_hb.add_theme_constant_override("separation", 2)
		hb.add_child(btn_hb)

		if equip_id != "":
			var unequip_btn := Button.new()
			unequip_btn.text = "Unequip"
			unequip_btn.custom_minimum_size = Vector2(70, 24)
			unequip_btn.add_theme_font_size_override("font_size", 10)
			unequip_btn.pressed.connect(_on_hero_unequip.bind(hero_id))
			btn_hb.add_child(unequip_btn)

		# Equip from inventory button (only if inventory has equipment)
		var avail_equip: Array = ItemManager.get_equipment_items(pid)
		if not avail_equip.is_empty():
			var equip_btn := Button.new()
			equip_btn.text = "Equip..."
			equip_btn.custom_minimum_size = Vector2(70, 24)
			equip_btn.add_theme_font_size_override("font_size", 10)
			equip_btn.pressed.connect(_on_hero_equip_picker.bind(hero_id))
			btn_hb.add_child(equip_btn)


func _on_hero_unequip(hero_id: String) -> void:
	HeroSystem.unequip_item(hero_id, "item")
	AudioManager.play_ui_click()
	_refresh_hero_equip_tab()


func _on_hero_equip_picker(hero_id: String) -> void:
	## Show equipment picker in the detail panel for this hero.
	var pid: int = GameManager.get_human_player_id()
	var avail: Array = ItemManager.get_equipment_items(pid)
	if avail.is_empty():
		return
	detail_panel.visible = true
	for c in detail_container.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "Select Equipment"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", ColorTheme.TEXT_GOLD)
	detail_container.add_child(title)
	detail_container.add_child(HSeparator.new())

	for item in avail:
		var item_id: String = item.get("item_id", "")
		var eq_def: Dictionary = FactionData.EQUIPMENT_DEFS.get(item_id, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		detail_container.add_child(row)

		# Icon
		var icon_name: String = eq_def.get("icon", item.get("icon", ""))
		if icon_name != "":
			var icon_path: String = "res://assets/icons/items/%s.webp" % icon_name
			if ResourceLoader.exists(icon_path):
				var tex: Texture2D = load(icon_path)
				if tex:
					var tex_rect := TextureRect.new()
					tex_rect.texture = tex
					tex_rect.custom_minimum_size = Vector2(32, 32)
					tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
					tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					row.add_child(tex_rect)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info_vbox)

		var name_lbl := Label.new()
		name_lbl.text = eq_def.get("name", item_id)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", _get_rarity_color(eq_def.get("rarity", "common")))
		info_vbox.add_child(name_lbl)

		var stats: Dictionary = eq_def.get("stats", {})
		if not stats.is_empty():
			var parts: Array = []
			for key in stats:
				parts.append("%s+%d" % [key.to_upper(), stats[key]])
			var stat_lbl := Label.new()
			stat_lbl.text = " ".join(parts)
			stat_lbl.add_theme_font_size_override("font_size", 10)
			stat_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
			info_vbox.add_child(stat_lbl)

		var eq_btn := Button.new()
		eq_btn.text = "Equip"
		eq_btn.custom_minimum_size = Vector2(60, 26)
		eq_btn.add_theme_font_size_override("font_size", 11)
		eq_btn.pressed.connect(_on_hero_equip_confirm.bind(hero_id, item_id))
		row.add_child(eq_btn)


func _on_hero_equip_confirm(hero_id: String, equip_id: String) -> void:
	HeroSystem.equip_item(hero_id, equip_id)
	AudioManager.play_ui_click()
	_refresh_hero_equip_tab()

# ═══════════════ DETAIL VIEW ═══════════════

func _on_select_item(index: int, item: Dictionary) -> void:
	AudioManager.play_ui_click()
	_selected_item_index = index; detail_panel.visible = true; _refresh_detail(item)

func _refresh_detail(item: Dictionary) -> void:
	for child in detail_container.get_children(): child.queue_free()
	var item_id: String = item.get("item_id", "")
	var item_type: String = item.get("type", "unknown")
	# Detail icon (larger)
	var detail_icon_name: String = item.get("icon", "")
	var detail_icon_path: String = ItemManager.get_icon_path(detail_icon_name) if detail_icon_name != "" else ""
	if detail_icon_path != "":
		var detail_icon_tex: Texture2D = load(detail_icon_path)
		if detail_icon_tex != null:
			var detail_icon := TextureRect.new()
			detail_icon.texture = detail_icon_tex
			detail_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			detail_icon.custom_minimum_size = Vector2(0, 80)
			detail_container.add_child(detail_icon)
	var nl := Label.new()
	nl.text = item.get("name", "???"); nl.add_theme_font_size_override("font_size", 18)
	nl.add_theme_color_override("font_color", _get_rarity_color(item.get("rarity", "common")))
	detail_container.add_child(nl)
	var dl := Label.new()
	dl.text = item.get("desc", "No description"); dl.add_theme_font_size_override("font_size", 13)
	dl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_container.add_child(dl)
	detail_container.add_child(HSeparator.new())
	if item_type == "consumable":
		var eff: Dictionary = FactionData.ITEM_DEFS.get(item_id, {}).get("effect", {})
		if not eff.is_empty():
			var parts: Array = []
			for key in eff: parts.append("%s: %s" % [key, str(eff[key])])
			var el := Label.new()
			el.text = "Effect: %s" % ", ".join(parts)
			el.add_theme_font_size_override("font_size", 12)
			el.add_theme_color_override("font_color", Color(0.5, 0.8, 0.5))
			detail_container.add_child(el)
	elif item_type == "equipment":
		var ed: Dictionary = FactionData.EQUIPMENT_DEFS.get(item_id, {})
		var stats: Dictionary = ed.get("stats", {})
		for key in stats:
			var sl := Label.new()
			sl.text = "  %s: +%d" % [key.to_upper(), stats[key]]
			sl.add_theme_font_size_override("font_size", 12)
			sl.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
			detail_container.add_child(sl)
		var passive: String = ed.get("passive", "none")
		if passive != "none":
			var pl := Label.new()
			pl.text = "Passive: %s" % passive; pl.add_theme_font_size_override("font_size", 12)
			pl.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))
			detail_container.add_child(pl)
	# Action buttons
	detail_container.add_child(HSeparator.new())
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	detail_container.add_child(btn_row)
	if item_type == "consumable":
		var bu := Button.new()
		bu.text = "Use"; bu.custom_minimum_size = Vector2(80, 30)
		bu.add_theme_font_size_override("font_size", 13)
		bu.pressed.connect(_on_use_item.bind(item_id))
		btn_row.add_child(bu)
	elif item_type == "equipment":
		var equip_hero_vbox := VBoxContainer.new()
		equip_hero_vbox.add_theme_constant_override("separation", 4)
		btn_row.add_child(equip_hero_vbox)
		var pid: int = GameManager.get_human_player_id()
		var heroes: Array = HeroSystem.get_recruited_heroes(pid)
		if heroes.is_empty():
			var il := Label.new()
			il.text = "No recruited heroes to equip"
			il.add_theme_font_size_override("font_size", 11)
			il.add_theme_color_override("font_color", Color(0.6, 0.6, 0.5))
			equip_hero_vbox.add_child(il)
		else:
			var equip_title := Label.new()
			equip_title.text = "Equip to hero:"
			equip_title.add_theme_font_size_override("font_size", 12)
			equip_title.add_theme_color_override("font_color", ColorTheme.TEXT_HEADING)
			equip_hero_vbox.add_child(equip_title)
			for hid in heroes:
				var hero_def: Dictionary = FactionData.HEROES.get(hid, {})
				var hero_name: String = hero_def.get("name", hid)
				var hbtn := Button.new()
				hbtn.text = "Equip to %s" % hero_name
				hbtn.custom_minimum_size = Vector2(140, 26)
				hbtn.add_theme_font_size_override("font_size", 11)
				hbtn.pressed.connect(_on_equip_to_hero.bind(hid, item_id))
				equip_hero_vbox.add_child(hbtn)
	var bd := Button.new()
	bd.text = "Discard"; bd.custom_minimum_size = Vector2(80, 30)
	bd.add_theme_font_size_override("font_size", 13)
	bd.pressed.connect(_on_discard_item.bind(item_id))
	btn_row.add_child(bd)

# ═══════════════ CALLBACKS ═══════════════

func _on_use_item(item_id: String) -> void:
	AudioManager.play_ui_confirm()
	ItemManager.use_item(GameManager.get_human_player_id(), item_id)
	_selected_item_index = -1; detail_panel.visible = false; _refresh()

func _on_equip_to_hero(hero_id: String, equip_id: String) -> void:
	AudioManager.play_ui_confirm()
	var result: Dictionary = HeroSystem.equip_item(hero_id, equip_id)
	if result.get("ok", false):
		var hero_def: Dictionary = FactionData.HEROES.get(hero_id, {})
		EventBus.message_log.emit("%s equipped successfully" % hero_def.get("name", hero_id))
	else:
		EventBus.message_log.emit("[color=red]%s[/color]" % result.get("reason", "Equip failed"))
	_selected_item_index = -1; detail_panel.visible = false; _refresh()

func _on_discard_item(item_id: String) -> void:
	AudioManager.play_ui_click()
	var pid: int = GameManager.get_human_player_id()
	ItemManager.remove_item(pid, item_id)
	var defs: Dictionary = FactionData.ITEM_DEFS.get(item_id, FactionData.EQUIPMENT_DEFS.get(item_id, {}))
	EventBus.message_log.emit("Discarded %s" % defs.get("name", item_id))
	_selected_item_index = -1; detail_panel.visible = false; _refresh()

func _on_upgrade_relic() -> void:
	AudioManager.play_ui_confirm()
	RelicManager.upgrade_relic(GameManager.get_human_player_id()); _refresh()

func _on_item_changed(_pid: int, _item_name: String) -> void:
	if _visible: _refresh()

func _on_resources_changed(_pid: int) -> void:
	if _visible: _refresh_capacity()

func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: hide_panel()

# ═══════════════ HELPERS ═══════════════

func _make_tab_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text; btn.custom_minimum_size = Vector2(90, 34)
	btn.add_theme_font_size_override("font_size", ColorTheme.FONT_BODY)
	btn.add_theme_stylebox_override("normal", ColorTheme.make_button_style_flat("normal"))
	btn.add_theme_stylebox_override("hover", ColorTheme.make_button_style_flat("hover"))
	return btn

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary": return Color(1.0, 0.7, 0.1)
		"rare": return Color(0.4, 0.6, 1.0)
	return ColorTheme.TEXT_DIM

func _make_icon_placeholder(item: Dictionary) -> ColorRect:
	var placeholder := ColorRect.new()
	placeholder.custom_minimum_size = Vector2(36, 36)
	var tt: String = item.get("type", "unknown")
	match tt:
		"consumable": placeholder.color = Color(0.2, 0.35, 0.2, 0.8)
		"equipment": placeholder.color = Color(0.2, 0.2, 0.4, 0.8)
		_: placeholder.color = Color(0.2, 0.2, 0.2, 0.8)
	return placeholder
