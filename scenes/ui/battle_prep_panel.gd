## battle_prep_panel.gd - Sengoku Rance 07-style battle preparation screen.
## Full-screen overlay for assigning heroes to formation slots before attacking.
## Shows 6-slot grid (3 front, 3 back), enemy garrison preview, and confirm/cancel.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")
const ChibiLoader = preload("res://systems/combat/chibi_sprite_loader.gd")

signal battle_confirmed(army_id: int, target_tile: int, slot_assignments: Dictionary)
signal battle_cancelled()

const PANEL_WIDTH := 960.0
const PANEL_HEIGHT := 600.0
const SLOT_SIZE := Vector2(140, 110)

var _army_id: int = -1
var _target_tile: int = -1
var _army: Dictionary = {}
var _slot_assignments: Dictionary = {}  # { slot_idx: { "troop_index": int, "hero_id": String } }
var _selected_slot: int = -1

var dimmer: ColorRect
var root: PanelContainer
var title_label: Label
var slot_panels: Array = []
var slot_labels: Array = []
var hero_list_container: VBoxContainer
var enemy_container: VBoxContainer
var confirm_btn: Button
var cancel_btn: Button
var formation_label: Label

func _ready() -> void:
	layer = UILayerRegistry.LAYER_BATTLE_PREP
	visible = false
	_build_ui()

# ═══════════════════════════════════════════════════
#                    PUBLIC API
# ═══════════════════════════════════════════════════

func show_panel(army_id: int, target_tile_index: int) -> void:
	# Audio trigger for opening battle prep
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("open_panel")
	_army_id = army_id
	_target_tile = target_tile_index
	_army = GameManager.get_army(army_id)
	_selected_slot = -1
	_init_slot_assignments()
	visible = true
	_refresh()

func hide_panel() -> void:
	visible = false
	_selected_slot = -1

func _init_slot_assignments() -> void:
	_slot_assignments.clear()
	var troops: Array = _army.get("troops", [])
	var heroes: Array = _army.get("heroes", [])
	for i in range(mini(troops.size(), 6)):
		var hid: String = heroes[i] if i < heroes.size() else ""
		_slot_assignments[i] = { "troop_index": i, "hero_id": hid }

# ═══════════════════════════════════════════════════
#                    BUILD UI
# ═══════════════════════════════════════════════════

func _build_ui() -> void:
	dimmer = ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.6)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dimmer)

	root = PanelContainer.new()
	root.anchor_left = 0.5; root.anchor_right = 0.5
	root.anchor_top = 0.5; root.anchor_bottom = 0.5
	root.offset_left = -PANEL_WIDTH * 0.5; root.offset_right = PANEL_WIDTH * 0.5
	root.offset_top = -PANEL_HEIGHT * 0.5; root.offset_bottom = PANEL_HEIGHT * 0.5
	root.add_theme_stylebox_override("panel", ColorTheme.make_panel_style(
		ColorTheme.BG_SECONDARY, ColorTheme.ACCENT_GOLD, 2, 6, 12))
	add_child(root)

	var mvbox := VBoxContainer.new()
	mvbox.add_theme_constant_override("separation", 8)
	root.add_child(mvbox)

	title_label = _make_label("Battle Preparation", 20, ColorTheme.TEXT_GOLD)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mvbox.add_child(title_label)
	mvbox.add_child(_make_hsep())

	# ── Content: left army | separator | right enemy ──
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mvbox.add_child(hbox)
	_build_left_side(hbox)
	_build_vsep(hbox)
	_build_right_side(hbox)

	# ── Bottom buttons ──
	mvbox.add_child(_make_hsep())
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mvbox.add_child(btn_row)

	cancel_btn = _make_styled_button("Cancel", Color(0.5, 0.2, 0.2))
	cancel_btn.custom_minimum_size.x = 130
	cancel_btn.pressed.connect(_on_cancel)
	btn_row.add_child(cancel_btn)
	confirm_btn = _make_styled_button("Attack!", ColorTheme.ACCENT_GOLD)
	confirm_btn.custom_minimum_size.x = 180
	confirm_btn.add_theme_font_size_override("font_size", 18)
	confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(confirm_btn)

func _build_left_side(parent: HBoxContainer) -> void:
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	left.add_theme_constant_override("separation", 6)
	parent.add_child(left)
	left.add_child(_make_label("YOUR ARMY", 16, ColorTheme.TEXT_HEADING, HORIZONTAL_ALIGNMENT_CENTER))

	var gl := HBoxContainer.new()
	gl.add_theme_constant_override("separation", 8)
	gl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(gl)

	# Formation grid
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 4)
	gl.add_child(gv)
	gv.add_child(_make_label("Front Row", 11, ColorTheme.TEXT_DIM))
	var front := HBoxContainer.new()
	front.add_theme_constant_override("separation", 4)
	gv.add_child(front)
	for i in range(3):
		front.add_child(_create_slot_panel(i))
	gv.add_child(_make_label("Back Row", 11, ColorTheme.TEXT_DIM))
	var back := HBoxContainer.new()
	back.add_theme_constant_override("separation", 4)
	gv.add_child(back)
	for i in range(3, 6):
		back.add_child(_create_slot_panel(i))

	# Formation bonus indicator
	formation_label = _make_label("Formation: --", 12, ColorTheme.TEXT_GOLD)
	formation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	formation_label.custom_minimum_size.x = 300
	gv.add_child(formation_label)

	# Hero assignment list
	var lp := PanelContainer.new()
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.add_theme_stylebox_override("panel", ColorTheme.make_panel_style(
		ColorTheme.BG_DARK, ColorTheme.BORDER_DIM, 1, 4, 4))
	gl.add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	lp.add_child(lv)
	lv.add_child(_make_label("Assign Hero", 13, ColorTheme.TEXT_GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(sc)
	hero_list_container = VBoxContainer.new()
	hero_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_list_container.add_theme_constant_override("separation", 3)
	sc.add_child(hero_list_container)

func _build_right_side(parent: HBoxContainer) -> void:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.8
	right.add_theme_constant_override("separation", 6)
	parent.add_child(right)
	right.add_child(_make_label("ENEMY DEFENSE", 16, ColorTheme.TEXT_WARNING, HORIZONTAL_ALIGNMENT_CENTER))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	enemy_container = VBoxContainer.new()
	enemy_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_container.add_theme_constant_override("separation", 4)
	sc.add_child(enemy_container)

func _build_vsep(parent: HBoxContainer) -> void:
	var vsep := VSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = ColorTheme.BORDER_DIM
	s.set_content_margin_all(0)
	s.content_margin_left = 1; s.content_margin_right = 1
	vsep.add_theme_stylebox_override("separator", s)
	parent.add_child(vsep)

func _create_slot_panel(idx: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = SLOT_SIZE
	p.add_theme_stylebox_override("panel", _slot_style(false))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(ev): _on_slot_input(ev, idx))
	p.mouse_entered.connect(func(): _on_slot_hover(p, true))
	p.mouse_exited.connect(func(): _on_slot_hover(p, false))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 1)
	p.add_child(vb)
	# Chibi preview overlay (top-right corner of slot)
	var chibi_tex := TextureRect.new()
	chibi_tex.name = "ChibiPreview"
	chibi_tex.custom_minimum_size = Vector2(48, 48)
	chibi_tex.size = Vector2(48, 48)
	chibi_tex.position = Vector2(SLOT_SIZE.x - 52, 2)
	chibi_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chibi_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chibi_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chibi_tex.visible = false
	p.add_child(chibi_tex)
	# Troop class icon overlay (bottom-left corner)
	var class_icon := TextureRect.new()
	class_icon.name = "ClassIcon"
	class_icon.custom_minimum_size = Vector2(20, 20)
	class_icon.size = Vector2(20, 20)
	class_icon.position = Vector2(4, SLOT_SIZE.y - 24)
	class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	class_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_icon.visible = false
	p.add_child(class_icon)
	slot_panels.append(p)
	slot_labels.append(vb)
	return p

# ═══════════════════════════════════════════════════
#                    REFRESH
# ═══════════════════════════════════════════════════

func _refresh() -> void:
	var army_name: String = _army.get("name", "Army")
	var tile: Dictionary = GameManager.tiles[_target_tile] if _target_tile >= 0 and _target_tile < GameManager.tiles.size() else {}
	title_label.text = "Battle Preparation - %s vs %s" % [army_name, tile.get("name", "Tile %d" % _target_tile)]
	_refresh_slots()
	_refresh_enemy()
	if _selected_slot >= 0:
		_refresh_hero_list()
	else:
		_clear_container(hero_list_container)

func _refresh_slots() -> void:
	var troops: Array = _army.get("troops", [])
	for si in range(6):
		var vb: VBoxContainer = slot_labels[si] if si < slot_labels.size() else null
		if not vb:
			continue
		_clear_container(vb)
		# BUG FIX R14: bounds check on slot_panels before access
		if si < slot_panels.size():
			slot_panels[si].add_theme_stylebox_override("panel", _slot_style(si == _selected_slot))
		# Update chibi preview
		var chibi_preview: TextureRect = slot_panels[si].get_node_or_null("ChibiPreview") if si < slot_panels.size() else null
		if not _slot_assignments.has(si):
			vb.add_child(_make_label("(empty)", 11, ColorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
			if chibi_preview:
				chibi_preview.visible = false
			continue
		var asgn: Dictionary = _slot_assignments[si]
		var ti: int = asgn.get("troop_index", -1)
		var hid: String = asgn.get("hero_id", "")
		# Load chibi for assigned hero
		if chibi_preview:
			if hid != "" and ChibiLoader.has_png(hid):
				var idle_tex := ChibiLoader.load_png(hid, "idle")
				if idle_tex:
					chibi_preview.texture = idle_tex
					chibi_preview.visible = true
					# Enlarge chibi when slot is selected
					if si == _selected_slot:
						chibi_preview.custom_minimum_size = Vector2(64, 64)
						chibi_preview.size = Vector2(64, 64)
						chibi_preview.position = Vector2(SLOT_SIZE.x - 68, 2)
					else:
						chibi_preview.custom_minimum_size = Vector2(48, 48)
						chibi_preview.size = Vector2(48, 48)
						chibi_preview.position = Vector2(SLOT_SIZE.x - 52, 2)
				else:
					chibi_preview.visible = false
			else:
				chibi_preview.visible = false
		# Troop info
		if ti >= 0 and ti < troops.size():
			var troop: Dictionary = troops[ti]
			var td: Dictionary = GameData.get_troop_def(troop.get("troop_id", ""))
			vb.add_child(_make_label(td.get("name", troop.get("troop_id", "???")), 11, ColorTheme.TEXT_GOLD))
			vb.add_child(_make_label("%d/%d" % [troop.get("soldiers", 0), troop.get("max_soldiers", 0)], 10, ColorTheme.TEXT_NORMAL))
			vb.add_child(_make_label("ATK:%d DEF:%d" % [td.get("base_atk", 0), td.get("base_def", 0)], 9, ColorTheme.TEXT_DIM))
		# Hero badge
		if hid != "":
			var st: Dictionary = HeroSystem.get_hero_combat_stats(hid) if HeroSystem.has_method("get_hero_combat_stats") else {}
			var hl := _make_label("%s Lv%d" % [st.get("name", hid), st.get("level", 0)], 10, ColorTheme.ACCENT_GOLD_BRIGHT)
			hl.clip_text = true
			vb.add_child(hl)
			vb.add_child(_make_label("A%d D%d S%d" % [st.get("atk", 0), st.get("def", 0), st.get("spd", 0)], 9, ColorTheme.TEXT_DIM))
		else:
			vb.add_child(_make_label("[No Hero]", 9, ColorTheme.TEXT_MUTED))
	_update_formation_label()

func _refresh_enemy() -> void:
	_clear_container(enemy_container)
	var garrison: Array = RecruitManager.get_garrison(_target_tile) if RecruitManager and RecruitManager.has_method("get_garrison") else []
	if garrison.is_empty():
		enemy_container.add_child(_make_label("No garrison detected", 13, ColorTheme.TEXT_MUTED, HORIZONTAL_ALIGNMENT_CENTER))
		return
	for troop in garrison:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", ColorTheme.make_panel_style(
			ColorTheme.BG_CARD, ColorTheme.BORDER_CARD, 1, 4, 6))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		enemy_container.add_child(card)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 1)
		card.add_child(vb)
		var td: Dictionary = GameData.get_troop_def(troop.get("troop_id", ""))
		vb.add_child(_make_label(td.get("name", troop.get("troop_id", "???")), 13, ColorTheme.TEXT_WARNING))
		vb.add_child(_make_label("Soldiers: %d" % troop.get("soldiers", 0), 11, ColorTheme.TEXT_NORMAL))
		vb.add_child(_make_label("ATK:%d  DEF:%d  SPD:%d" % [td.get("base_atk", 0), td.get("base_def", 0), td.get("base_spd", 0)], 10, ColorTheme.TEXT_DIM))
		var cmd: String = troop.get("commander_id", "")
		if cmd != "":
			var cs: Dictionary = HeroSystem.get_hero_combat_stats(cmd) if HeroSystem.has_method("get_hero_combat_stats") else {}
			vb.add_child(_make_label("Cmd: %s" % cs.get("name", cmd), 10, ColorTheme.TEXT_RED))

func _refresh_hero_list() -> void:
	_clear_container(hero_list_container)
	if _selected_slot < 0:
		return
	var assigned: Array = _get_assigned_hero_ids()
	var cur_hero: String = _slot_assignments.get(_selected_slot, {}).get("hero_id", "")
	var clear := _make_styled_button("-- Remove Hero --", Color(0.5, 0.25, 0.25))
	clear.add_theme_font_size_override("font_size", 11)
	clear.pressed.connect(_on_clear_hero)
	hero_list_container.add_child(clear)
	for hid in _army.get("heroes", []):
		if hid == "" or (hid in assigned and hid != cur_hero):
			continue
		var st: Dictionary = HeroSystem.get_hero_combat_stats(hid) if HeroSystem.has_method("get_hero_combat_stats") else {}
		var txt: String = "%s Lv%d (A%d/D%d)" % [st.get("name", hid), st.get("level", 0), st.get("atk", 0), st.get("def", 0)]
		var btn := _make_styled_button(txt, ColorTheme.ACCENT_GOLD)
		btn.add_theme_font_size_override("font_size", 11)
		btn.pressed.connect(_on_hero_selected.bind(hid))
		hero_list_container.add_child(btn)
	if hero_list_container.get_child_count() <= 1:
		hero_list_container.add_child(_make_label("No heroes available", 11, ColorTheme.TEXT_MUTED))

# ═══════════════════════════════════════════════════
#                  INPUT HANDLERS
# ═══════════════════════════════════════════════════

func _on_slot_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if AudioManager and AudioManager.has_method("play_sfx_by_name"):
			AudioManager.play_sfx_by_name("button_click")
		_selected_slot = idx
		_refresh()

func _on_slot_hover(panel: PanelContainer, entering: bool) -> void:
	var idx: int = slot_panels.find(panel)
	if idx == _selected_slot:
		return
	if entering:
		panel.add_theme_stylebox_override("panel", ColorTheme.make_panel_style(
			Color(0.14, 0.12, 0.2), ColorTheme.ACCENT_GOLD, 1, 4, 6))
	else:
		panel.add_theme_stylebox_override("panel", _slot_style(false))

func _on_hero_selected(hero_id: String) -> void:
	# Audio trigger for hero slot assignment
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("slot_assign")
	if _selected_slot >= 0 and _slot_assignments.has(_selected_slot):
		_slot_assignments[_selected_slot]["hero_id"] = hero_id
	_selected_slot = -1
	_refresh()

func _on_clear_hero() -> void:
	if _selected_slot >= 0 and _slot_assignments.has(_selected_slot):
		_slot_assignments[_selected_slot]["hero_id"] = ""
	_selected_slot = -1
	_refresh()

func _on_confirm() -> void:
	# Audio trigger for battle confirmation
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("ui_confirm")
	hide_panel()
	battle_confirmed.emit(_army_id, _target_tile, _slot_assignments.duplicate(true))

func _on_cancel() -> void:
	# Audio trigger for cancel
	if AudioManager and AudioManager.has_method("play_sfx_by_name"):
		AudioManager.play_sfx_by_name("ui_cancel")
	hide_panel()
	battle_cancelled.emit()

# ═══════════════════════════════════════════════════
#              FORMATION DETECTION
# ═══════════════════════════════════════════════════

func _detect_formation() -> Dictionary:
	## Analyzes current slot assignments to determine formation type and bonuses.
	## Returns { "name": String, "desc": String, "front_count": int, "back_count": int }
	var front_count: int = 0
	var back_count: int = 0
	for si in _slot_assignments:
		if si < 3:
			front_count += 1
		else:
			back_count += 1

	var formation_name: String = "Standard"
	var desc_parts: Array = []

	# Base row bonuses (always active)
	if front_count > 0:
		desc_parts.append("Front: ATK+10%% DEF+5%%")
	if back_count > 0:
		desc_parts.append("Back: DEF+15%%, Ranged ATK+10%%")

	# Named formation patterns
	if front_count == 3 and back_count == 0:
		formation_name = "Wall Formation"
		desc_parts.append("Wall: Front DEF+10%%")
	elif front_count == 0 and back_count == 3:
		formation_name = "Turtle Formation"
		desc_parts.append("Turtle: DEF+20%%, ATK-15%%")
	elif front_count == 1 and back_count == 2:
		formation_name = "Ranged Focus"
		desc_parts.append("Ranged Focus: Back ATK+5%%")
	elif front_count == 2 and back_count == 1:
		formation_name = "Standard"
	else:
		formation_name = "Custom"

	# Flanking warning
	if front_count > 0 and front_count < 3:
		desc_parts.append("WARNING: Gap in front row - enemy flanking ATK+15%%!")

	return {
		"name": formation_name,
		"desc": " | ".join(desc_parts),
		"front_count": front_count,
		"back_count": back_count,
	}

func _update_formation_label() -> void:
	if not formation_label:
		return
	var info: Dictionary = _detect_formation()
	formation_label.text = "Formation: %s (%dF/%dB)\n%s" % [
		info["name"], info["front_count"], info["back_count"], info["desc"]]

# ═══════════════════════════════════════════════════
#                    HELPERS
# ═══════════════════════════════════════════════════

func _get_assigned_hero_ids() -> Array:
	var ids: Array = []
	for si in _slot_assignments:
		var h: String = _slot_assignments[si].get("hero_id", "")
		if h != "":
			ids.append(h)
	return ids

func _clear_container(c: Control) -> void:
	if c:
		for ch in c.get_children():
			ch.queue_free()

func _slot_style(selected: bool) -> StyleBoxFlat:
	var bc: Color = ColorTheme.ACCENT_GOLD_BRIGHT if selected else ColorTheme.BORDER_DIM
	return ColorTheme.make_panel_style(ColorTheme.BG_CARD, bc, 2 if selected else 1, 4, 6)

func _make_label(text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	return l

func _make_hsep() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = ColorTheme.BORDER_DIM
	s.set_content_margin_all(0)
	s.content_margin_top = 1; s.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", s)
	return sep

func _make_styled_button(text: String, accent: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_stylebox_override("normal", ColorTheme.make_panel_style(ColorTheme.BG_DARK, accent, 1, 4, 8))
	btn.add_theme_stylebox_override("hover", ColorTheme.make_panel_style(Color(0.14, 0.12, 0.2), accent.lightened(0.3), 1, 4, 8))
	btn.add_theme_stylebox_override("pressed", ColorTheme.make_panel_style(ColorTheme.BG_PRIMARY, accent, 2, 4, 8))
	btn.add_theme_color_override("font_color", ColorTheme.TEXT_NORMAL)
	btn.add_theme_color_override("font_hover_color", ColorTheme.TEXT_GOLD)
	btn.add_theme_font_size_override("font_size", 15)
	return btn

func _safe_load(path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	return null
