## hero_detail_panel.gd - 英雄详情面板 UI for 暗潮 SLG (v1.0)
## Detailed hero info: stats breakdown, affection, equipment, skills, leveling.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")
const HeroLevelData = preload("res://systems/hero/hero_level_data.gd")

# ── State ──
var _visible: bool = false
var _hero_id: String = ""

# ── UI refs ──
var root: Control
var dim_bg: ColorRect
var main_panel: PanelContainer
var header_label: Label
var btn_close: Button
var content_scroll: ScrollContainer
var content_container: VBoxContainer
var _content_nodes: Array = []

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	layer = 6  # Above hero_panel (layer 4)
	_build_ui(); _connect_signals(); hide_panel()

func _connect_signals() -> void:
	EventBus.hero_affection_changed.connect(_on_hero_affection_changed)
	EventBus.hero_leveled_up.connect(_on_hero_leveled_up)
	EventBus.hero_exp_gained.connect(_on_hero_exp_changed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and _visible:
			hide_panel(); get_viewport().set_input_as_handled()

# ═══════════════ BUILD UI ═══════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "HeroDetailRoot"
	root.anchor_right = 1.0; root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0; dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0, 0, 0, 0.55)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_bg.gui_input.connect(_on_dim_bg_input)
	root.add_child(dim_bg)

	main_panel = PanelContainer.new()
	main_panel.anchor_left = 0.15; main_panel.anchor_right = 0.85
	main_panel.anchor_top = 0.05; main_panel.anchor_bottom = 0.95
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.1, 0.98)
	style.border_color = Color(0.55, 0.4, 0.25)
	style.set_border_width_all(2); style.set_corner_radius_all(10); style.set_content_margin_all(14)
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
	header_label.text = "英雄详情"
	header_label.add_theme_font_size_override("font_size", 22)
	header_label.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(header_label)
	btn_close = Button.new()
	btn_close.text = "X"; btn_close.custom_minimum_size = Vector2(36, 36)
	btn_close.add_theme_font_size_override("font_size", 16)
	btn_close.pressed.connect(hide_panel)
	header_row.add_child(btn_close)
	outer_vbox.add_child(HSeparator.new())
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer_vbox.add_child(content_scroll)
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 6)
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(content_container)

# ═══════════════ PUBLIC API ═══════════════

func show_panel(hero_id: String = "") -> void:
	if hero_id != "": _hero_id = hero_id
	if _hero_id == "": return
	_visible = true; root.visible = true; _refresh()

func hide_panel() -> void:
	_visible = false; root.visible = false

func is_panel_visible() -> bool:
	return _visible

# ═══════════════ REFRESH ═══════════════

func _refresh() -> void:
	_clear_content()
	if _hero_id == "": return
	var hero_def: Dictionary = FactionData.HEROES.get(_hero_id, {})
	if hero_def.is_empty(): return
	var combat_stats: Dictionary = HeroSystem.get_hero_combat_stats(_hero_id)
	var leveled_stats: Dictionary = HeroLeveling.get_hero_stats(_hero_id)
	var equip_totals: Dictionary = HeroSystem.get_equipment_stat_totals(_hero_id)
	var affection: int = HeroSystem.hero_affection.get(_hero_id, 0)

	# ── Portrait area & Name ──
	var portrait := ColorRect.new()
	portrait.custom_minimum_size = Vector2(0, 60)
	portrait.color = Color(0.1, 0.08, 0.14, 0.8)
	_add(portrait)
	var nl := Label.new()
	nl.text = hero_def.get("name", _hero_id)
	nl.add_theme_font_size_override("font_size", 20)
	nl.add_theme_color_override("font_color", _get_faction_color(hero_def.get("faction", "")))
	_add(nl)
	header_label.text = hero_def.get("name", "英雄详情")
	var tl := Label.new()
	tl.text = "阵营: %s  |  兵种: %s" % [hero_def.get("faction", "?"), hero_def.get("troop", "?")]
	tl.add_theme_font_size_override("font_size", 13)
	tl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_add(tl)

	# ── Level & EXP ──
	_add(HSeparator.new())
	var level: int = leveled_stats.get("level", 1)
	var exp_info: Dictionary = HeroLeveling.get_exp_to_next_level(_hero_id)
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 8)
	_add(lr)
	var ll := Label.new()
	ll.text = "等级: %d" % level; ll.add_theme_font_size_override("font_size", 15)
	ll.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	lr.add_child(ll)
	var bar := ProgressBar.new()
	bar.min_value = 0; bar.max_value = maxi(exp_info.get("needed", 1), 1)
	bar.value = exp_info.get("current", 0)
	bar.custom_minimum_size = Vector2(200, 16); bar.show_percentage = false
	lr.add_child(bar)
	var el := Label.new()
	el.text = "EXP: %d/%d (%.0f%%)" % [exp_info.get("current", 0), exp_info.get("needed", 0), exp_info.get("progress_pct", 0.0)]
	el.add_theme_font_size_override("font_size", 11)
	el.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	lr.add_child(el)

	# ── Stats with breakdown (base + level + equipment) ──
	_add(HSeparator.new())
	_add(_make_section("属性"))
	var ba: int = hero_def.get("base_atk", hero_def.get("atk", 0))
	var bd: int = hero_def.get("base_def", hero_def.get("def", 0))
	var bs: int = hero_def.get("base_spd", hero_def.get("spd", 0))
	var bi: int = hero_def.get("base_int", hero_def.get("int", 0))
	_add_stat("ATK", combat_stats.get("atk", 0), ba, leveled_stats.get("atk", ba) - ba, equip_totals.get("atk", 0), Color(1.0, 0.5, 0.3))
	_add_stat("DEF", combat_stats.get("def", 0), bd, leveled_stats.get("def", bd) - bd, equip_totals.get("def", 0), Color(0.3, 0.7, 1.0))
	_add_stat("SPD", combat_stats.get("spd", 0), bs, leveled_stats.get("spd", bs) - bs, equip_totals.get("spd", 0), Color(0.3, 1.0, 0.5))
	_add_stat("INT", combat_stats.get("int_stat", bi), bi, leveled_stats.get("int_stat", bi) - bi, 0, Color(0.7, 0.4, 1.0))
	var hl := Label.new()
	hl.text = "HP: %d  |  MP: %d" % [combat_stats.get("hp", 0), combat_stats.get("mp", 0)]
	hl.add_theme_font_size_override("font_size", 12)
	hl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_add(hl)

	# ── Affection (0-10) ──
	_add(HSeparator.new())
	_add(_make_section("好感度"))
	var hearts: String = ""
	for i in range(10): hearts += "# " if i < affection else "o "
	var al := Label.new()
	al.text = "%d/10  %s" % [affection, hearts.strip_edges()]
	al.add_theme_font_size_override("font_size", 13)
	al.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	_add(al)
	var unlocks: Array = HeroSystem.get_affection_unlocks(_hero_id)
	if not unlocks.is_empty():
		var ut: Array = []
		for u in unlocks:
			match u:
				"passive_upgrade": ut.append("被动强化")
				"unique_event": ut.append("专属事件")
				"second_active_skill": ut.append("第二技能")
				"exclusive_ending": ut.append("专属结局")
		var ul := Label.new()
		ul.text = "已解锁: %s" % ", ".join(ut)
		ul.add_theme_font_size_override("font_size", 11)
		ul.add_theme_color_override("font_color", Color(0.5, 0.7, 0.4))
		_add(ul)
	var rl := Label.new()
	rl.text = "阈值: 3=被动强化  5=专属事件  7=第二技能  10=专属结局"
	rl.add_theme_font_size_override("font_size", 10)
	rl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_add(rl)

	# ── Equipment Slots ──
	_add(HSeparator.new())
	_add(_make_section("装备"))
	var equip_details: Array = HeroSystem.get_hero_equipment_details(_hero_id)
	var slot_names: Dictionary = {"weapon": "武器", "armor": "防具", "accessory": "饰品"}
	for ei in equip_details:
		var sk: String = ei.get("slot_key", "")
		var eid: String = ei.get("equip_id", "")
		var sr := HBoxContainer.new()
		sr.add_theme_constant_override("separation", 8)
		_add(sr)
		var snl := Label.new()
		snl.text = "%s:" % slot_names.get(sk, sk)
		snl.custom_minimum_size = Vector2(50, 0)
		snl.add_theme_font_size_override("font_size", 13)
		snl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		sr.add_child(snl)
		if eid != "":
			var enl := Label.new()
			enl.text = ei.get("name", eid)
			enl.add_theme_font_size_override("font_size", 13)
			enl.add_theme_color_override("font_color", _get_rarity_color(ei.get("rarity", "common")))
			enl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sr.add_child(enl)
			var eq_stats: Dictionary = ei.get("stats", {})
			if not eq_stats.is_empty():
				var sp: Array = []
				for k in eq_stats: sp.append("+%d%s" % [eq_stats[k], k.to_upper()])
				var esl := Label.new()
				esl.text = " ".join(sp); esl.add_theme_font_size_override("font_size", 11)
				esl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
				sr.add_child(esl)
			var bu := Button.new()
			bu.text = "卸下"; bu.custom_minimum_size = Vector2(56, 24)
			bu.add_theme_font_size_override("font_size", 11)
			bu.pressed.connect(_on_unequip.bind(_hero_id, sk))
			sr.add_child(bu)
		else:
			var eml := Label.new()
			eml.text = "-- 空 --"; eml.add_theme_font_size_override("font_size", 13)
			eml.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
			sr.add_child(eml)

	# ── Active Skills ──
	_add(HSeparator.new())
	_add(_make_section("主动技能"))
	var skill_data: Dictionary = HeroSystem.get_hero_skill_data(_hero_id)
	if not skill_data.is_empty():
		_add_skill(skill_data)
	else:
		var nsl := Label.new()
		nsl.text = "无主动技能"; nsl.add_theme_font_size_override("font_size", 12)
		nsl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_add(nsl)
	# Second skill (好感度7解锁)
	var sk2_name: String = combat_stats.get("active_2", "")
	if sk2_name != "":
		var sk2_def: Dictionary = FactionData.HERO_SKILL_DEFS.get(sk2_name, {})
		if not sk2_def.is_empty():
			var s2l := Label.new()
			s2l.text = "[第二技能]"; s2l.add_theme_font_size_override("font_size", 12)
			s2l.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
			_add(s2l)
			var s2d: Dictionary = sk2_def.duplicate(); s2d["name"] = sk2_name
			_add_skill(s2d)

	# ── Passive Skills ──
	_add(HSeparator.new())
	_add(_make_section("被动技能"))
	var lp: Array = combat_stats.get("level_passives", [])
	var ep: Array = combat_stats.get("equipment_passives", [])
	if lp.is_empty() and ep.is_empty():
		var npl := Label.new()
		npl.text = "无已解锁被动"; npl.add_theme_font_size_override("font_size", 12)
		npl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_add(npl)
	else:
		for p in lp:
			var pn: String = p.get("id", p.get("name", "?")) if p is Dictionary else str(p)
			var pd: String = p.get("desc", "") if p is Dictionary else ""
			var pl := Label.new()
			pl.text = "  [等级] %s%s" % [pn, (" - " + pd) if pd != "" else ""]
			pl.add_theme_font_size_override("font_size", 12)
			pl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6))
			pl.autowrap_mode = TextServer.AUTOWRAP_WORD
			_add(pl)
		for epp in ep:
			var epl := Label.new()
			epl.text = "  [装备] %s" % str(epp)
			epl.add_theme_font_size_override("font_size", 12)
			epl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.9))
			_add(epl)

func _add_skill(sd: Dictionary) -> void:
	var sl := Label.new()
	sl.text = "%s  [%s]  威力: %.0f  冷却: %d回合" % [sd.get("name", "?"), sd.get("type", "?"), sd.get("power", 0), sd.get("cooldown", 0)]
	sl.add_theme_font_size_override("font_size", 13)
	sl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	_add(sl)
	var desc: String = sd.get("desc", "")
	if desc != "":
		var dl := Label.new()
		dl.text = "  %s" % desc; dl.add_theme_font_size_override("font_size", 11)
		dl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_add(dl)
	if sd.has("ready"):
		var cl := Label.new()
		if sd["ready"]:
			cl.text = "  状态: 可用"; cl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			cl.text = "  冷却中: %d回合" % sd.get("cooldown_remaining", 0)
			cl.add_theme_color_override("font_color", Color(0.8, 0.4, 0.3))
		cl.add_theme_font_size_override("font_size", 11)
		_add(cl)

func _clear_content() -> void:
	for node in _content_nodes:
		if is_instance_valid(node): node.queue_free()
	_content_nodes.clear()

func _add(node: Control) -> void:
	content_container.add_child(node); _content_nodes.append(node)

# ═══════════════ STAT ROW ═══════════════

func _add_stat(name: String, total: int, base: int, lvl: int, eq: int, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_add(row)
	var nl := Label.new()
	nl.text = name; nl.custom_minimum_size = Vector2(40, 0)
	nl.add_theme_font_size_override("font_size", 14)
	nl.add_theme_color_override("font_color", color)
	row.add_child(nl)
	var vl := Label.new()
	vl.text = str(total); vl.custom_minimum_size = Vector2(30, 0)
	vl.add_theme_font_size_override("font_size", 14)
	vl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	row.add_child(vl)
	var bl := Label.new()
	bl.text = "(基础:%d + 等级:%d + 装备:%d)" % [base, lvl, eq]
	bl.add_theme_font_size_override("font_size", 11)
	bl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	row.add_child(bl)

# ═══════════════ CALLBACKS ═══════════════

func _on_unequip(hero_id: String, slot_key: String) -> void:
	var result: Dictionary = HeroSystem.unequip_item(hero_id, slot_key)
	if result.get("ok", false):
		EventBus.message_log.emit("已卸下装备"); _refresh()
	else:
		EventBus.message_log.emit("[color=red]%s[/color]" % result.get("reason", "卸下失败"))

func _on_hero_affection_changed(hero_id: String, _val: int) -> void:
	if _visible and _hero_id == hero_id: _refresh()

func _on_hero_leveled_up(hero_id: String, _new_level: int) -> void:
	if _visible and _hero_id == hero_id: _refresh()

func _on_hero_exp_changed(hero_id: String, _amount: int, _new_total: int) -> void:
	if _visible and _hero_id == hero_id: _refresh()

func _on_dim_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: hide_panel()

# ═══════════════ HELPERS ═══════════════

func _make_section(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text; lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.4))
	return lbl

func _get_faction_color(faction: String) -> Color:
	match faction:
		"human": return Color(0.3, 0.6, 1.0)
		"high_elf": return Color(0.3, 0.9, 0.4)
		"mage": return Color(0.7, 0.4, 1.0)
		"orc": return Color(0.9, 0.4, 0.2)
		"pirate": return Color(0.4, 0.6, 0.9)
		"dark_elf": return Color(0.6, 0.3, 0.8)
	return Color(0.8, 0.8, 0.85)

func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary": return Color(1.0, 0.7, 0.1)
		"rare": return Color(0.4, 0.6, 1.0)
	return Color(0.7, 0.7, 0.75)
