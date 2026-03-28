## combat_popup.gd - Battle result display + Pre-battle Tactical Orders for Dark Tide SLG
## Shows combat outcome with attacker/defender info, losses, and loot.
## Also provides the Commander Tactical Orders panel shown before combat begins.
extends CanvasLayer
const FactionData = preload("res://systems/faction/faction_data.gd")
const CombatResolver = preload("res://systems/combat/combat_resolver.gd")
const CounterMatrix = preload("res://systems/combat/counter_matrix.gd")

## Archetype display names for counter indicators
const _ARCHETYPE_LABELS := {
	"infantry": "步兵", "heavy_infantry": "重步", "cavalry": "骑兵",
	"archer": "弓手", "gunner": "火枪", "mage": "法师", "assassin": "刺客",
	"berserker": "狂战", "priest": "祭司", "artillery": "炮兵", "tank": "坦克",
	"undead_infantry": "亡灵", "mech": "机甲", "boss": "Boss", "fodder": "杂兵",
}

# ── State ──
var _visible: bool = false
var _queue: Array = []  # Queue of combat results to show
var _orders_visible: bool = false
var _orders_player_id: int = -1

# ── UI refs: Result popup ──
var root: Control
var dim_bg: ColorRect
var popup_panel: PanelContainer
var title_label: Label
var result_label: RichTextLabel
var btn_dismiss: Button

# ── UI refs: Tactical Orders panel ──
var _orders_root: Control
var _orders_dim_bg: ColorRect
var _orders_panel: PanelContainer
var _directive_buttons: Array = []  # Array of Button
var _selected_directive: int = CombatResolver.TacticalDirective.NONE
var _skill_timing_options: Dictionary = {}  # hero_id -> OptionButton
var _protected_option: OptionButton
var _decoy_option: OptionButton
var _btn_confirm_orders: Button
var _btn_skip_orders: Button

var _tween: Tween = null
var _orders_tween: Tween = null


# placeholder: filled in by _build_orders_ui
# ── Directive metadata for UI ──
const _DIRECTIVE_UI: Array = [
	{"id": CombatResolver.TacticalDirective.NONE, "label": "无指令", "desc": "不使用战术指令"},
	{"id": CombatResolver.TacticalDirective.ALL_OUT, "label": "猛攻", "desc": "ATK+25% DEF-15% 最速先制"},
	{"id": CombatResolver.TacticalDirective.HOLD_LINE, "label": "坚守", "desc": "DEF+25% ATK-15% 超时=我方胜"},
	{"id": CombatResolver.TacticalDirective.GUERRILLA, "label": "游击", "desc": "后排ATK+30% 前排DEF+15% 后排被保护"},
	{"id": CombatResolver.TacticalDirective.FOCUS_FIRE, "label": "集火", "desc": "ATK+10% 全军集火最弱敌"},
	{"id": CombatResolver.TacticalDirective.AMBUSH, "label": "奇袭", "desc": "首回合ATK+40%先制 之后ATK-10%"},
]

const _TIMING_LABELS: Array = [
	{"value": 0, "label": "自动"},
	{"value": 1, "label": "立即 (第1回合)"},
	{"value": 4, "label": "中盘 (第4回合)"},
	{"value": 8, "label": "收割 (第8回合)"},
]


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	layer = 6
	_build_ui()
	_build_orders_ui()
	_connect_signals()
	hide_popup()
	_hide_orders_panel()


func _connect_signals() -> void:
	EventBus.combat_result.connect(_on_combat_result)
	EventBus.tactical_orders_requested.connect(_on_tactical_orders_requested)


# ═══════════════════════════════════════════════════════════════
#                    BUILD UI: RESULT POPUP
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "CombatRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	dim_bg = ColorRect.new()
	dim_bg.anchor_right = 1.0
	dim_bg.anchor_bottom = 1.0
	dim_bg.color = Color(0.0, 0.0, 0.0, 0.55)
	dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim_bg)

	popup_panel = PanelContainer.new()
	popup_panel.anchor_left = 0.5
	popup_panel.anchor_right = 0.5
	popup_panel.anchor_top = 0.5
	popup_panel.anchor_bottom = 0.5
	popup_panel.offset_left = -280
	popup_panel.offset_right = 280
	popup_panel.offset_top = -180
	popup_panel.offset_bottom = 180
	var style: StyleBox = UITheme.make_info_panel_style() if UITheme else null
	if not style:
		var sf := StyleBoxFlat.new()
		sf.bg_color = Color(0.06, 0.04, 0.1, 0.97)
		sf.border_color = Color(0.8, 0.3, 0.1)
		sf.set_border_width_all(2)
		sf.set_corner_radius_all(10)
		sf.set_content_margin_all(16)
		style = sf
	popup_panel.add_theme_stylebox_override("panel", style)
	root.add_child(popup_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	popup_panel.add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "Battle Result"
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Result content
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	result_label = RichTextLabel.new()
	result_label.bbcode_enabled = true
	result_label.fit_content = true
	result_label.scroll_active = false
	result_label.add_theme_font_size_override("normal_font_size", 14)
	result_label.add_theme_color_override("default_color", Color(0.85, 0.85, 0.88))
	scroll.add_child(result_label)

	# Dismiss
	btn_dismiss = Button.new()
	btn_dismiss.text = "OK"
	btn_dismiss.custom_minimum_size = Vector2(140, 38)
	btn_dismiss.add_theme_font_size_override("font_size", 15)
	btn_dismiss.pressed.connect(_on_dismiss)
	vbox.add_child(btn_dismiss)
	# Center the button
	btn_dismiss.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


# ═══════════════════════════════════════════════════════════════
#              BUILD UI: TACTICAL ORDERS PANEL
# ═══════════════════════════════════════════════════════════════

func _build_orders_ui() -> void:
	_orders_root = Control.new()
	_orders_root.name = "TacticalOrdersRoot"
	_orders_root.anchor_right = 1.0
	_orders_root.anchor_bottom = 1.0
	_orders_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_orders_root)

	_orders_dim_bg = ColorRect.new()
	_orders_dim_bg.anchor_right = 1.0
	_orders_dim_bg.anchor_bottom = 1.0
	_orders_dim_bg.color = Color(0.0, 0.0, 0.05, 0.65)
	_orders_dim_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_orders_root.add_child(_orders_dim_bg)

	_orders_panel = PanelContainer.new()
	_orders_panel.anchor_left = 0.5
	_orders_panel.anchor_right = 0.5
	_orders_panel.anchor_top = 0.5
	_orders_panel.anchor_bottom = 0.5
	_orders_panel.offset_left = -320
	_orders_panel.offset_right = 320
	_orders_panel.offset_top = -260
	_orders_panel.offset_bottom = 260
	var style2: StyleBox = UITheme.make_info_panel_style() if UITheme else null
	if not style2:
		var sf := StyleBoxFlat.new()
		sf.bg_color = Color(0.04, 0.03, 0.08, 0.97)
		sf.border_color = Color(0.2, 0.6, 0.9)
		sf.set_border_width_all(2)
		sf.set_corner_radius_all(10)
		sf.set_content_margin_all(14)
		style2 = sf
	_orders_panel.add_theme_stylebox_override("panel", style2)
	_orders_root.add_child(_orders_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 6)
	_orders_panel.add_child(main_vbox)

	# Title
	var orders_title := Label.new()
	orders_title.text = "战术指令 - Commander Orders"
	orders_title.add_theme_font_size_override("font_size", 20)
	orders_title.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	orders_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(orders_title)

	main_vbox.add_child(HSeparator.new())

	# Scrollable content area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	main_vbox.add_child(scroll)

	var content_vbox := VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 6)
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content_vbox)

	# ── Section 1: Directives ──
	var dir_label := Label.new()
	dir_label.text = "战术指令 (选择一项):"
	dir_label.add_theme_font_size_override("font_size", 15)
	dir_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	content_vbox.add_child(dir_label)

	_directive_buttons.clear()
	for i in range(_DIRECTIVE_UI.size()):
		var d: Dictionary = _DIRECTIVE_UI[i]
		var btn := Button.new()
		btn.text = "%s - %s" % [d["label"], d["desc"]]
		btn.add_theme_font_size_override("font_size", 13)
		btn.custom_minimum_size = Vector2(580, 30)
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)  # NONE selected by default
		var idx: int = i
		btn.pressed.connect(_on_directive_selected.bind(idx))
		content_vbox.add_child(btn)
		_directive_buttons.append(btn)

	content_vbox.add_child(HSeparator.new())

	# ── Section 2: Skill Timing ──
	var timing_label := Label.new()
	timing_label.text = "技能时机 (每个英雄):"
	timing_label.add_theme_font_size_override("font_size", 15)
	timing_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	content_vbox.add_child(timing_label)

	# Placeholder: populated dynamically when orders are requested
	var timing_container := VBoxContainer.new()
	timing_container.name = "SkillTimingContainer"
	timing_container.add_theme_constant_override("separation", 4)
	content_vbox.add_child(timing_container)

	content_vbox.add_child(HSeparator.new())

	# ── Section 3: Formation Priority ──
	var form_label := Label.new()
	form_label.text = "阵型优先级:"
	form_label.add_theme_font_size_override("font_size", 15)
	form_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	content_vbox.add_child(form_label)

	var form_grid := GridContainer.new()
	form_grid.columns = 2
	form_grid.add_theme_constant_override("h_separation", 8)
	form_grid.add_theme_constant_override("v_separation", 4)
	content_vbox.add_child(form_grid)

	var prot_lbl := Label.new()
	prot_lbl.text = "重点保护 (受击-50%):"
	prot_lbl.add_theme_font_size_override("font_size", 13)
	form_grid.add_child(prot_lbl)

	_protected_option = OptionButton.new()
	_protected_option.add_theme_font_size_override("font_size", 13)
	_protected_option.custom_minimum_size = Vector2(200, 28)
	form_grid.add_child(_protected_option)

	var decoy_lbl := Label.new()
	decoy_lbl.text = "诱饵 (受击+100%):"
	decoy_lbl.add_theme_font_size_override("font_size", 13)
	form_grid.add_child(decoy_lbl)

	_decoy_option = OptionButton.new()
	_decoy_option.add_theme_font_size_override("font_size", 13)
	_decoy_option.custom_minimum_size = Vector2(200, 28)
	form_grid.add_child(_decoy_option)

	content_vbox.add_child(HSeparator.new())

	# ── Section 4: Counter Preview ──
	var counter_label := Label.new()
	counter_label.text = "兵种克制预览:"
	counter_label.add_theme_font_size_override("font_size", 15)
	counter_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	content_vbox.add_child(counter_label)

	var counter_container := VBoxContainer.new()
	counter_container.name = "CounterPreviewContainer"
	counter_container.add_theme_constant_override("separation", 3)
	content_vbox.add_child(counter_container)

	# ── Buttons row ──
	main_vbox.add_child(HSeparator.new())

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(btn_row)

	_btn_confirm_orders = Button.new()
	_btn_confirm_orders.text = "确认出击"
	_btn_confirm_orders.custom_minimum_size = Vector2(140, 36)
	_btn_confirm_orders.add_theme_font_size_override("font_size", 15)
	_btn_confirm_orders.pressed.connect(_on_confirm_orders)
	btn_row.add_child(_btn_confirm_orders)

	_btn_skip_orders = Button.new()
	_btn_skip_orders.text = "跳过 (默认)"
	_btn_skip_orders.custom_minimum_size = Vector2(140, 36)
	_btn_skip_orders.add_theme_font_size_override("font_size", 15)
	_btn_skip_orders.pressed.connect(_on_skip_orders)
	btn_row.add_child(_btn_skip_orders)


# ═══════════════════════════════════════════════════════════════
#                       PUBLIC API
# ═══════════════════════════════════════════════════════════════

func show_combat_result(data: Dictionary) -> void:
	var won: bool = data.get("won", false)
	var attacker: String = data.get("attacker_name", "Attacker")
	var defender: String = data.get("defender_name", "Defender")
	var atk_losses: int = data.get("attacker_losses", 0)
	var def_losses: int = data.get("defender_losses", 0)
	var atk_power: int = data.get("attacker_power", 0)
	var def_power: int = data.get("defender_power", 0)
	var tile_name: String = data.get("tile_name", "")
	var loot_gold: int = data.get("loot_gold", 0)
	var slaves_captured: int = data.get("slaves_captured", 0)
	var hero_captured: String = data.get("hero_captured", "")

	if won:
		title_label.text = "Victory!"
		title_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		title_label.text = "Defeat..."
		title_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))

	var text: String = ""

	# Battle location
	if tile_name != "":
		text += "[center][color=gray]%s[/color][/center]\n\n" % tile_name

	# Power comparison
	text += "[color=cyan]%s[/color] (Power: %d)  vs  [color=red]%s[/color] (Power: %d)\n\n" % [attacker, atk_power, defender, def_power]

	# Separator line
	text += "[color=gray]━━━━━━━━━━━━━━━━━━━━━━━━[/color]\n\n"

	# Losses
	text += "Our losses: [color=yellow]%d[/color] troops\n" % atk_losses
	text += "Enemy losses: [color=yellow]%d[/color] troops\n" % def_losses

	# Loot
	if won:
		text += "\n[color=gold]Loot:[/color]\n"
		if loot_gold > 0:
			text += "  Gold +%d\n" % loot_gold
		if slaves_captured > 0:
			text += "  Slaves +%d\n" % slaves_captured
		if hero_captured != "":
			var hero_name: String = FactionData.HEROES.get(hero_captured, {}).get("name", hero_captured)
			text += "  [color=orchid]Hero captured: %s[/color]\n" % hero_name

	result_label.text = text
	_show_animated()


func hide_popup() -> void:
	_visible = false
	root.visible = false
	# Show next queued result
	if not _queue.is_empty():
		var next: Dictionary = _queue.pop_front()
		call_deferred("show_combat_result", next)


# ═══════════════════════════════════════════════════════════════
#                 TACTICAL ORDERS: PUBLIC API
# ═══════════════════════════════════════════════════════════════

func show_tactical_orders(player_id: int, _tile_index: int) -> void:
	## Display the pre-battle tactical orders panel.
	_orders_player_id = player_id
	_selected_directive = CombatResolver.TacticalDirective.NONE

	# Reset directive button states
	for i in range(_directive_buttons.size()):
		_directive_buttons[i].button_pressed = (i == 0)

	# Populate hero skill timing dropdowns
	_populate_skill_timing(player_id)

	# Populate protected/decoy slot dropdowns
	_populate_formation_slots(player_id)

	# Populate counter preview for player units
	_populate_counter_preview(player_id)

	_show_orders_animated()


func _populate_skill_timing(player_id: int) -> void:
	## Build skill timing dropdown for each hero in the player's army.
	_skill_timing_options.clear()
	var container: VBoxContainer = _orders_panel.find_child("SkillTimingContainer", true, false)
	if container == null:
		return
	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	var heroes: Array = HeroSystem.get_heroes_for_player(player_id) if HeroSystem else []
	if heroes.is_empty():
		var no_hero_lbl := Label.new()
		no_hero_lbl.text = "(无英雄在军中)"
		no_hero_lbl.add_theme_font_size_override("font_size", 12)
		no_hero_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		container.add_child(no_hero_lbl)
		return

	for hero in heroes:
		var hero_id: String = hero.get("id", "")
		var hero_name: String = hero.get("name", hero_id)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)

		var lbl := Label.new()
		lbl.text = hero_name + ":"
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.custom_minimum_size = Vector2(120, 0)
		hbox.add_child(lbl)

		var opt := OptionButton.new()
		opt.add_theme_font_size_override("font_size", 12)
		opt.custom_minimum_size = Vector2(180, 26)
		for t in _TIMING_LABELS:
			opt.add_item(t["label"])
		opt.selected = 0  # Auto by default
		hbox.add_child(opt)

		container.add_child(hbox)
		_skill_timing_options[hero_id] = opt


func _populate_formation_slots(player_id: int) -> void:
	## Fill protected/decoy dropdowns with unit names from the army.
	_protected_option.clear()
	_decoy_option.clear()

	_protected_option.add_item("无", 0)
	_decoy_option.add_item("无", 0)

	var units: Array = RecruitManager.get_combat_units(player_id) if RecruitManager else []
	for i in range(units.size()):
		var u: Dictionary = units[i]
		var label: String = "Slot %d: %s (%d兵)" % [i, u.get("type", "?"), u.get("count", u.get("soldiers", 0))]
		_protected_option.add_item(label, i + 1)
		_decoy_option.add_item(label, i + 1)

	_protected_option.selected = 0
	_decoy_option.selected = 0


func _populate_counter_preview(player_id: int) -> void:
	## Build counter relationship indicators for each unit in the player's army.
	var container: VBoxContainer = _orders_panel.find_child("CounterPreviewContainer", true, false)
	if container == null:
		return
	for child in container.get_children():
		child.queue_free()

	var units: Array = RecruitManager.get_combat_units(player_id) if RecruitManager else []
	if units.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(无部队)"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		container.add_child(empty_lbl)
		return

	for i in range(units.size()):
		var u: Dictionary = units[i]
		var troop_id: String = u.get("type", "")
		if troop_id == "":
			continue
		var summary: Dictionary = CounterMatrix.get_counter_summary(troop_id)
		var base_type: String = summary.get("base_type", "")
		var base_disp: String = _ARCHETYPE_LABELS.get(base_type, base_type)
		var troop_name: String = u.get("name", troop_id)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		container.add_child(row)

		# Unit name + archetype
		var name_lbl := Label.new()
		name_lbl.text = "%s [%s]" % [troop_name, base_disp]
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		name_lbl.custom_minimum_size = Vector2(150, 0)
		row.add_child(name_lbl)

		# Strong against (green arrows)
		var strong: Array = summary.get("strong_vs", [])
		for s in strong:
			var s_name: String = _ARCHETYPE_LABELS.get(s.get("type", ""), s.get("type", ""))
			var s_lbl := Label.new()
			if s.get("hard", false):
				s_lbl.text = "▲▲%s" % s_name
				s_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
			else:
				s_lbl.text = "▲%s" % s_name
				s_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.4))
			s_lbl.add_theme_font_size_override("font_size", 11)
			row.add_child(s_lbl)

		# Spacer
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(8, 0)
		row.add_child(spacer)

		# Weak against (red arrows)
		var weak: Array = summary.get("weak_vs", [])
		for w in weak:
			var w_name: String = _ARCHETYPE_LABELS.get(w.get("type", ""), w.get("type", ""))
			var w_lbl := Label.new()
			if w.get("hard", false):
				w_lbl.text = "▼▼%s" % w_name
				w_lbl.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			else:
				w_lbl.text = "▼%s" % w_name
				w_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
			w_lbl.add_theme_font_size_override("font_size", 11)
			row.add_child(w_lbl)


# ═══════════════════════════════════════════════════════════════
#                       CALLBACKS
# ═══════════════════════════════════════════════════════════════

func _on_combat_result(attacker_id: int, defender_desc: String, won: bool) -> void:
	# Only show popup for human player combats
	if attacker_id != GameManager.get_human_player_id():
		return
	# Build basic data from signal
	var data := {
		"won": won,
		"attacker_name": GameManager.get_player_by_id(attacker_id).get("name", "Player") if GameManager.get_player_by_id(attacker_id) else "Player",
		"defender_name": defender_desc,
	}
	if _visible:
		_queue.append(data)
	else:
		show_combat_result(data)


func _on_dismiss() -> void:
	_hide_animated()


func _on_tactical_orders_requested(player_id: int, tile_index: int) -> void:
	if player_id != GameManager.get_human_player_id():
		# AI doesn't use the UI — auto-confirm with defaults
		EventBus.tactical_orders_confirmed.emit(player_id)
		return
	show_tactical_orders(player_id, tile_index)


func _on_directive_selected(index: int) -> void:
	## Radio-button behavior: deselect all others, select this one.
	_selected_directive = _DIRECTIVE_UI[index]["id"]
	for i in range(_directive_buttons.size()):
		_directive_buttons[i].button_pressed = (i == index)


func _on_confirm_orders() -> void:
	## Apply selected orders to GameManager and signal combat to proceed.
	GameManager.set_tactical_directive(_selected_directive)

	# Skill timing
	for hero_id in _skill_timing_options:
		var opt: OptionButton = _skill_timing_options[hero_id]
		var sel: int = opt.selected
		if sel >= 0 and sel < _TIMING_LABELS.size():
			var round_num: int = _TIMING_LABELS[sel]["value"]
			GameManager.set_skill_timing(hero_id, round_num)

	# Protected slot: option index 0 = none, 1+ = slot index
	var prot_sel: int = _protected_option.selected
	if prot_sel > 0:
		GameManager.set_protected_slot(prot_sel - 1)
	else:
		GameManager.set_protected_slot(-1)

	# Decoy slot
	var decoy_sel: int = _decoy_option.selected
	if decoy_sel > 0:
		GameManager.set_decoy_slot(decoy_sel - 1)
	else:
		GameManager.set_decoy_slot(-1)

	_hide_orders_panel()
	EventBus.tactical_orders_confirmed.emit(_orders_player_id)


func _on_skip_orders() -> void:
	## Skip orders — clear everything and proceed.
	GameManager.clear_tactical_orders()
	_hide_orders_panel()
	EventBus.tactical_orders_confirmed.emit(_orders_player_id)


# ═══════════════════════════════════════════════════════════════
#                       ANIMATION
# ═══════════════════════════════════════════════════════════════

func _show_animated() -> void:
	_visible = true
	root.visible = true
	dim_bg.modulate.a = 0.0
	popup_panel.modulate.a = 0.0
	popup_panel.scale = Vector2(0.85, 0.85)

	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim_bg, "modulate:a", 1.0, 0.2)
	_tween.tween_property(popup_panel, "modulate:a", 1.0, 0.3)
	_tween.tween_property(popup_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_animated() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim_bg, "modulate:a", 0.0, 0.15)
	_tween.tween_property(popup_panel, "modulate:a", 0.0, 0.15)
	_tween.chain().tween_callback(hide_popup)


func _show_orders_animated() -> void:
	_orders_visible = true
	_orders_root.visible = true
	_orders_dim_bg.modulate.a = 0.0
	_orders_panel.modulate.a = 0.0
	_orders_panel.scale = Vector2(0.85, 0.85)

	if _orders_tween:
		_orders_tween.kill()
	_orders_tween = create_tween().set_parallel(true)
	_orders_tween.tween_property(_orders_dim_bg, "modulate:a", 1.0, 0.2)
	_orders_tween.tween_property(_orders_panel, "modulate:a", 1.0, 0.3)
	_orders_tween.tween_property(_orders_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_orders_panel() -> void:
	_orders_visible = false
	_orders_root.visible = false
