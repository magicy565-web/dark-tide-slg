## hero_detail_panel.gd - Hero Details panel UI for Dark Tide SLG (v1.0)
## Detailed hero info: stats breakdown, affection, equipment, skills, leveling.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")
const HeroLevelData = preload("res://systems/hero/hero_level_data.gd")
const CounterMatrix = preload("res://systems/combat/counter_matrix.gd")

## Archetype display names for counter section
const _ARCHETYPE_LABELS := {
	"infantry": "步兵", "heavy_infantry": "重步", "cavalry": "骑兵",
	"archer": "弓手", "gunner": "火枪", "mage": "法师", "assassin": "刺客",
	"berserker": "狂战", "priest": "祭司", "artillery": "炮兵", "tank": "坦克",
	"undead_infantry": "亡灵", "mech": "机甲", "boss": "Boss", "fodder": "杂兵",
}

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
var _gift_option_btn: OptionButton = null
var _gift_give_btn: Button = null

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	layer = 6  # Above hero_panel (layer 4)
	_build_ui(); _connect_signals(); hide_panel()

func _connect_signals() -> void:
	EventBus.hero_affection_changed.connect(_on_hero_affection_changed)
	EventBus.hero_leveled_up.connect(_on_hero_leveled_up)
	EventBus.hero_exp_gained.connect(_on_hero_exp_changed)
	EventBus.open_hero_detail_requested.connect(_on_open_hero_detail_requested)
	EventBus.heroine_submission_changed.connect(_on_hero_submission_changed)

func _on_open_hero_detail_requested(hero_id: String) -> void:
	show_panel(hero_id)

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
	header_label.text = "Hero Details"
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
	# Clean up any open equip picker overlay
	var old_overlay := root.get_node_or_null("EquipPickerOverlay")
	if old_overlay != null:
		old_overlay.queue_free()

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
	header_label.text = hero_def.get("name", "Hero Details")
	var tl := Label.new()
	tl.text = "Faction: %s  |  Troop: %s" % [hero_def.get("faction", "?"), hero_def.get("troop", "?")]
	tl.add_theme_font_size_override("font_size", 13)
	tl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_add(tl)

	# ── Counter Matrix (兵种克制) ──
	var troop_type: String = hero_def.get("troop", "")
	if troop_type != "":
		_add(HSeparator.new())
		_add(_make_section("兵种克制"))
		var summary: Dictionary = CounterMatrix.get_counter_summary(troop_type)
		var base_disp: String = _ARCHETYPE_LABELS.get(summary.get("base_type", ""), summary.get("base_type", "?"))
		var type_lbl := Label.new()
		type_lbl.text = "基础兵种: %s" % base_disp
		type_lbl.add_theme_font_size_override("font_size", 13)
		type_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		_add(type_lbl)
		# Strong against
		var strong: Array = summary.get("strong_vs", [])
		if not strong.is_empty():
			var strong_row := HBoxContainer.new()
			strong_row.add_theme_constant_override("separation", 6)
			_add(strong_row)
			var strong_prefix := Label.new()
			strong_prefix.text = "克制:"
			strong_prefix.add_theme_font_size_override("font_size", 12)
			strong_prefix.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
			strong_prefix.custom_minimum_size = Vector2(40, 0)
			strong_row.add_child(strong_prefix)
			for s in strong:
				var s_name: String = _ARCHETYPE_LABELS.get(s.get("type", ""), s.get("type", ""))
				var s_lbl := Label.new()
				if s.get("hard", false):
					s_lbl.text = "★%s" % s_name
					s_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
				else:
					s_lbl.text = "%s" % s_name
					s_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.4))
				s_lbl.add_theme_font_size_override("font_size", 12)
				strong_row.add_child(s_lbl)
		else:
			var no_strong := Label.new()
			no_strong.text = "克制: 无"
			no_strong.add_theme_font_size_override("font_size", 12)
			no_strong.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			_add(no_strong)
		# Weak against
		var weak: Array = summary.get("weak_vs", [])
		if not weak.is_empty():
			var weak_row := HBoxContainer.new()
			weak_row.add_theme_constant_override("separation", 6)
			_add(weak_row)
			var weak_prefix := Label.new()
			weak_prefix.text = "弱于:"
			weak_prefix.add_theme_font_size_override("font_size", 12)
			weak_prefix.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
			weak_prefix.custom_minimum_size = Vector2(40, 0)
			weak_row.add_child(weak_prefix)
			for w in weak:
				var w_name: String = _ARCHETYPE_LABELS.get(w.get("type", ""), w.get("type", ""))
				var w_lbl := Label.new()
				if w.get("hard", false):
					w_lbl.text = "★%s" % w_name
					w_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
				else:
					w_lbl.text = "%s" % w_name
					w_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
				w_lbl.add_theme_font_size_override("font_size", 12)
				weak_row.add_child(w_lbl)
		else:
			var no_weak := Label.new()
			no_weak.text = "弱于: 无"
			no_weak.add_theme_font_size_override("font_size", 12)
			no_weak.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
			_add(no_weak)

	# ── Level & EXP ──
	_add(HSeparator.new())
	var level: int = leveled_stats.get("level", 1)
	var exp_info: Dictionary = HeroLeveling.get_exp_to_next_level(_hero_id)
	var lr := HBoxContainer.new()
	lr.add_theme_constant_override("separation", 8)
	_add(lr)
	var ll := Label.new()
	ll.text = "Level: %d" % level; ll.add_theme_font_size_override("font_size", 15)
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
	_add(_make_section("Stats"))
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
	_add(_make_section("Affection"))
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
				"passive_upgrade": ut.append("Passive Upgrade")
				"unique_event": ut.append("Unique Event")
				"second_active_skill": ut.append("Second Skill")
				"exclusive_ending": ut.append("Exclusive Ending")
		var ul := Label.new()
		ul.text = "Unlocked: %s" % ", ".join(ut)
		ul.add_theme_font_size_override("font_size", 11)
		ul.add_theme_color_override("font_color", Color(0.5, 0.7, 0.4))
		_add(ul)
	var rl := Label.new()
	rl.text = "Threshold: 3=Passive  5=Event  7=Skill  10=Ending"
	rl.add_theme_font_size_override("font_size", 10)
	rl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_add(rl)

	# ── Gift Giving ──
	if _hero_id in HeroSystem.recruited_heroes:
		var can_gift: bool = HeroSystem.can_give_gift(_hero_id)
		var gift_options: Array = HeroSystem.get_gift_options(_hero_id)
		var gift_row := HBoxContainer.new()
		gift_row.add_theme_constant_override("separation", 8)
		_add(gift_row)
		_gift_option_btn = OptionButton.new()
		_gift_option_btn.custom_minimum_size = Vector2(200, 28)
		_gift_option_btn.add_theme_font_size_override("font_size", 12)
		for i in range(gift_options.size()):
			var g: Dictionary = gift_options[i]
			var pref_tag: String = " [偏好!]" if g.get("is_preferred", false) else ""
			_gift_option_btn.add_item("%s (%d金)%s" % [g.get("name", "?"), g.get("cost", 0), pref_tag], i)
			_gift_option_btn.set_item_metadata(i, g.get("id", ""))
			if not g.get("can_afford", false):
				_gift_option_btn.set_item_disabled(i, true)
		_gift_option_btn.disabled = not can_gift or gift_options.is_empty()
		gift_row.add_child(_gift_option_btn)
		_gift_give_btn = Button.new()
		_gift_give_btn.text = "赠礼"
		_gift_give_btn.custom_minimum_size = Vector2(56, 28)
		_gift_give_btn.add_theme_font_size_override("font_size", 12)
		_gift_give_btn.disabled = not can_gift or gift_options.is_empty()
		_gift_give_btn.pressed.connect(_on_give_gift)
		gift_row.add_child(_gift_give_btn)
		if not can_gift:
			var gift_hint := Label.new()
			gift_hint.text = "冷却中" if _hero_id in HeroSystem.recruited_heroes else ""
			gift_hint.add_theme_font_size_override("font_size", 11)
			gift_hint.add_theme_color_override("font_color", Color(0.6, 0.4, 0.4))
			gift_row.add_child(gift_hint)

	# ── Submission (pirate faction only) ──
	var _pid: int = GameManager.get_human_player_id()
	var _faction_id: int = GameManager.get_player_faction(_pid)
	if _faction_id == FactionData.FactionID.PIRATE:
		_add(HSeparator.new())
		_add(_make_section("Submission"))
		var submission: int = HeroSystem.get_submission(_hero_id)
		var sub_color: Color
		if submission < 3:
			sub_color = Color(1.0, 0.3, 0.3)   # red
		elif submission <= 6:
			sub_color = Color(1.0, 0.85, 0.3)   # yellow
		else:
			sub_color = Color(0.3, 1.0, 0.4)    # green
		var sub_text: String = "Submission: %d/10" % submission
		if submission >= 7:
			sub_text += "  ✓ Submitted"
		var sub_label := Label.new()
		sub_label.text = sub_text
		sub_label.add_theme_font_size_override("font_size", 13)
		sub_label.add_theme_color_override("font_color", sub_color)
		_add(sub_label)

	# ── Equipment (SR07 single slot) ──
	_add(HSeparator.new())
	_add(_make_section("Equipment"))
	var equip_details: Array = HeroSystem.get_hero_equipment_details(_hero_id)
	var ei: Dictionary = equip_details[0] if not equip_details.is_empty() else {"equip_id": "", "slot_key": "item"}
	var eid: String = ei.get("equip_id", "")
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 8)
	_add(sr)
	var snl := Label.new()
	snl.text = "Item:"
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
		bu.text = "Unequip"; bu.custom_minimum_size = Vector2(56, 24)
		bu.add_theme_font_size_override("font_size", 11)
		bu.pressed.connect(_on_unequip.bind(_hero_id, "item"))
		sr.add_child(bu)
	else:
		var eml := Label.new()
		eml.text = "-- Empty --"; eml.add_theme_font_size_override("font_size", 13)
		eml.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		eml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sr.add_child(eml)
		var be := Button.new()
		be.text = "Equip"; be.custom_minimum_size = Vector2(56, 24)
		be.add_theme_font_size_override("font_size", 11)
		be.pressed.connect(_show_equip_picker.bind(_hero_id, "item"))
		sr.add_child(be)

	# ── Active Skills ──
	_add(HSeparator.new())
	_add(_make_section("Active Skill"))
	var skill_data: Dictionary = HeroSystem.get_hero_skill_data(_hero_id)
	if not skill_data.is_empty():
		_add_skill(skill_data)
	else:
		var nsl := Label.new()
		nsl.text = "No active skill"; nsl.add_theme_font_size_override("font_size", 12)
		nsl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_add(nsl)
	# Second skill (affection 7 unlock)
	var sk2_name: String = combat_stats.get("active_2", "")
	if sk2_name != "":
		var sk2_def: Dictionary = FactionData.HERO_SKILL_DEFS.get(sk2_name, {})
		if not sk2_def.is_empty():
			var s2l := Label.new()
			s2l.text = "[Second Skill]"; s2l.add_theme_font_size_override("font_size", 12)
			s2l.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
			_add(s2l)
			var s2d: Dictionary = sk2_def.duplicate(); s2d["name"] = sk2_name
			_add_skill(s2d)

	# ── Passive Skills ──
	_add(HSeparator.new())
	_add(_make_section("Passive Skills"))
	var lp: Array = combat_stats.get("level_passives", [])
	var ep: Array = combat_stats.get("equipment_passives", [])
	if lp.is_empty() and ep.is_empty():
		var npl := Label.new()
		npl.text = "No unlocked passives"; npl.add_theme_font_size_override("font_size", 12)
		npl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		_add(npl)
	else:
		for p in lp:
			var pn: String = p.get("id", p.get("name", "?")) if p is Dictionary else str(p)
			var pd: String = p.get("desc", "") if p is Dictionary else ""
			var pl := Label.new()
			pl.text = "  [Level] %s%s" % [pn, (" - " + pd) if pd != "" else ""]
			pl.add_theme_font_size_override("font_size", 12)
			pl.add_theme_color_override("font_color", Color(0.5, 0.8, 0.6))
			pl.autowrap_mode = TextServer.AUTOWRAP_WORD
			_add(pl)
		for epp in ep:
			var epl := Label.new()
			epl.text = "  [Equip] %s" % str(epp)
			epl.add_theme_font_size_override("font_size", 12)
			epl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.9))
			_add(epl)

func _add_skill(sd: Dictionary) -> void:
	var sl := Label.new()
	sl.text = "%s  [%s]  Power: %.0f  Cooldown: %d turns" % [sd.get("name", "?"), sd.get("type", "?"), sd.get("power", 0), sd.get("cooldown", 0)]
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
			cl.text = "  Status: Ready"; cl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			cl.text = "  Cooldown: %d turns" % sd.get("cooldown_remaining", 0)
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
	bl.text = "(Base:%d + Level:%d + Equip:%d)" % [base, lvl, eq]
	bl.add_theme_font_size_override("font_size", 11)
	bl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	row.add_child(bl)

# ═══════════════ CALLBACKS ═══════════════

func _on_give_gift() -> void:
	if _gift_option_btn == null or _hero_id == "":
		return
	var selected_idx: int = _gift_option_btn.get_selected_id()
	var gift_id: String = _gift_option_btn.get_item_metadata(selected_idx)
	if gift_id == "":
		return
	var result: Dictionary = HeroSystem.give_gift(_hero_id, gift_id)
	if result.get("ok", false):
		EventBus.message_log.emit("赠礼成功!")
	else:
		EventBus.message_log.emit("[color=red]%s[/color]" % result.get("desc", "赠礼失败"))
	_refresh()

func _on_unequip(hero_id: String, slot_key: String) -> void:
	var result: Dictionary = HeroSystem.unequip_item(hero_id, slot_key)
	if result.get("ok", false):
		EventBus.message_log.emit("Equipment removed"); _refresh()
	else:
		EventBus.message_log.emit("[color=red]%s[/color]" % result.get("reason", "Unequip failed"))

func _show_equip_picker(hero_id: String, slot_key: String) -> void:
	## Show a popup listing available equipment from inventory that matches the given slot.
	# Clean up any existing picker overlay first
	var existing_overlay := root.get_node_or_null("EquipPickerOverlay")
	if existing_overlay != null:
		existing_overlay.queue_free()
	var pid: int = GameManager.get_human_player_id()
	var all_equip: Array = ItemManager.get_equipment_items(pid)
	var matching: Array = all_equip
	if matching.is_empty():
		EventBus.message_log.emit("[color=yellow]No equipment in inventory[/color]")
		return
	# Build popup overlay
	var overlay := Control.new()
	overlay.name = "EquipPickerOverlay"
	overlay.anchor_right = 1.0; overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var popup_dim := ColorRect.new()
	popup_dim.anchor_right = 1.0; popup_dim.anchor_bottom = 1.0
	popup_dim.color = Color(0, 0, 0, 0.4)
	popup_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	popup_dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			overlay.queue_free()
	)
	overlay.add_child(popup_dim)
	var popup_panel := PanelContainer.new()
	popup_panel.anchor_left = 0.25; popup_panel.anchor_right = 0.75
	popup_panel.anchor_top = 0.2; popup_panel.anchor_bottom = 0.8
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.07, 0.13, 0.98)
	ps.border_color = Color(0.6, 0.45, 0.25)
	ps.set_border_width_all(2); ps.set_corner_radius_all(8); ps.set_content_margin_all(12)
	popup_panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(popup_panel)
	var pvbox := VBoxContainer.new()
	pvbox.add_theme_constant_override("separation", 6)
	popup_panel.add_child(pvbox)
	var title_row := HBoxContainer.new()
	pvbox.add_child(title_row)
	var title_lbl := Label.new()
	title_lbl.text = "Select Equipment"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.4))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)
	var btn_popup_close := Button.new()
	btn_popup_close.text = "X"; btn_popup_close.custom_minimum_size = Vector2(30, 30)
	btn_popup_close.add_theme_font_size_override("font_size", 14)
	btn_popup_close.pressed.connect(func(): overlay.queue_free())
	title_row.add_child(btn_popup_close)
	pvbox.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pvbox.add_child(scroll)
	var list_vbox := VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 4)
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_vbox)
	for eq in matching:
		var eq_id: String = eq.get("item_id", "")
		var eq_def: Dictionary = FactionData.EQUIPMENT_DEFS.get(eq_id, {})
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list_vbox.add_child(row)
		var name_lbl := Label.new()
		name_lbl.text = eq.get("name", eq_id)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", _get_rarity_color(eq.get("rarity", "common")))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var eq_stats: Dictionary = eq_def.get("stats", {})
		if not eq_stats.is_empty():
			var sp: Array = []
			for k in eq_stats: sp.append("+%d%s" % [eq_stats[k], k.to_upper()])
			var stat_lbl := Label.new()
			stat_lbl.text = " ".join(sp); stat_lbl.add_theme_font_size_override("font_size", 11)
			stat_lbl.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
			row.add_child(stat_lbl)
		var passive: String = eq_def.get("passive", "none")
		if passive != "none":
			var pas_lbl := Label.new()
			pas_lbl.text = "[%s]" % passive; pas_lbl.add_theme_font_size_override("font_size", 10)
			pas_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9))
			row.add_child(pas_lbl)
		var equip_btn := Button.new()
		equip_btn.text = "Equip"; equip_btn.custom_minimum_size = Vector2(56, 24)
		equip_btn.add_theme_font_size_override("font_size", 11)
		equip_btn.pressed.connect(func():
			var result: Dictionary = HeroSystem.equip_item(hero_id, eq_id)
			if result.get("ok", false):
				EventBus.message_log.emit("Equip success")
			else:
				EventBus.message_log.emit("[color=red]%s[/color]" % result.get("reason", "Equip failed"))
			overlay.queue_free()
			_refresh()
		)
		row.add_child(equip_btn)

func _on_hero_affection_changed(hero_id: String, _val: int) -> void:
	if _visible and _hero_id == hero_id: _refresh()

func _on_hero_leveled_up(hero_id: String, _new_level: int) -> void:
	if _visible and _hero_id == hero_id: _refresh()

func _on_hero_exp_changed(hero_id: String, _amount: int, _new_total: int) -> void:
	if _visible and _hero_id == hero_id: _refresh()

func _on_hero_submission_changed(hero_id: String, _new_value: int) -> void:
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
