## combat_view.gd - Sengoku Rance 07 style battle visualization (v2.0)
## 2-column mirrored formation with unit cards, turn order bar, attack animations
extends CanvasLayer

const FactionData = preload("res://systems/faction/faction_data.gd")

signal combat_view_closed()

# ── Layout constants ──
const CARD_W := 180.0
const CARD_H := 120.0
const CARD_GAP := 6.0
const BAR_W := 140.0
const BAR_H := 8.0
const HP_BAR_H := 6.0
const SCREEN_W := 1280.0
const SCREEN_H := 720.0
const CENTER_X := 640.0
const DIVIDER_X := 640.0
const GRID_TOP := 140.0
const TURN_BAR_Y := 100.0
const TURN_ICON_SIZE := 40.0
const MAX_ROUNDS := 12
const CLOCK_Y := 530.0
const LOG_TOP := 560.0
const ANIM_BASE_SPEED := 0.4

const CLASS_COLORS := {
	"ashigaru": Color(0.55, 0.6, 0.45),
	"samurai":  Color(0.7, 0.45, 0.3),
	"cavalry":  Color(0.45, 0.35, 0.65),
	"archer":   Color(0.35, 0.6, 0.35),
	"cannon":   Color(0.6, 0.35, 0.35),
	"ninja":    Color(0.3, 0.35, 0.5),
	"mage":     Color(0.4, 0.3, 0.65),
	"special":  Color(0.65, 0.55, 0.25),
	"priest":   Color(0.65, 0.55, 0.7),
	"mage_unit":Color(0.4, 0.3, 0.65),
}

const CLASS_ABBR := {
	"ashigaru":"足","samurai":"侍","cavalry":"骑","archer":"弓",
	"cannon":"砲","ninja":"忍","mage":"魔","special":"特",
	"priest":"僧","mage_unit":"魔",
}

# ── State ──
var _battle_state: Dictionary = {}
var _action_log: Array = []
var _log_index: int = 0
var _playing: bool = false
var _auto_play: bool = true
var _speed_mult: float = 1.0
var _current_round: int = 0
var _captured_heroes: Array = []

# ── Unit tracking (side -> slot -> dict with live data) ──
var _live_units: Dictionary = {"attacker": {}, "defender": {}}

# ── UI refs ──
var root: Control
var bg: ColorRect
var title_label: Label
var terrain_label: Label
var round_label: Label
var turn_bar_container: HBoxContainer
var clock_container: Control
var log_text: RichTextLabel
var btn_play: Button
var btn_step: Button
var btn_skip: Button
var btn_close: Button
var btn_speed: Button
var btn_auto: Button
var result_panel: PanelContainer
var result_label: Label
var anim_layer: Control  # overlay for attack lines + damage numbers

# Card panels indexed: attacker_cards[slot] and defender_cards[slot]
var attacker_cards: Dictionary = {}
var defender_cards: Dictionary = {}


func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()
	EventBus.combat_started.connect(_on_combat_started)


# ═══════════════════════════════════════════════════════════
#                       UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "CombatViewRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	bg = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.04, 0.05, 0.09, 0.96)
	root.add_child(bg)

	# Title
	title_label = _make_label("战斗", 28, Color(1, 0.9, 0.7), Vector2(0, 10), Vector2(SCREEN_W, 36))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title_label)

	# Terrain + round on same line
	terrain_label = _make_label("地形: 平原", 14, Color(0.65, 0.65, 0.55), Vector2(40, 48), Vector2(300, 20))
	root.add_child(terrain_label)
	round_label = _make_label("回合 0/12", 14, Color(0.85, 0.75, 0.55), Vector2(SCREEN_W - 200, 48), Vector2(160, 20))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(round_label)

	# Turn order bar
	_build_turn_bar()

	# Side labels
	var atk_lbl := _make_label("进攻方", 18, Color(0.95, 0.7, 0.5), Vector2(80, GRID_TOP - 30), Vector2(200, 26))
	root.add_child(atk_lbl)
	var def_lbl := _make_label("防御方", 18, Color(0.5, 0.7, 0.95), Vector2(SCREEN_W - 280, GRID_TOP - 30), Vector2(200, 26))
	def_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(def_lbl)

	# VS divider line
	var vs_lbl := _make_label("VS", 32, Color(1, 0.4, 0.3), Vector2(CENTER_X - 30, GRID_TOP + 120), Vector2(60, 40))
	vs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(vs_lbl)

	# Divider line
	var divider := ColorRect.new()
	divider.position = Vector2(CENTER_X - 1, GRID_TOP)
	divider.size = Vector2(2, 380)
	divider.color = Color(0.4, 0.35, 0.3, 0.6)
	root.add_child(divider)

	# Build card slots
	_build_card_grid()

	# Battle clock / advantage bar
	_build_clock_bar()

	# Battle log
	_build_log_panel()

	# Control buttons
	_build_buttons()

	# Result overlay
	_build_result_panel()

	# Animation overlay layer (on top of everything except result)
	anim_layer = Control.new()
	anim_layer.name = "AnimLayer"
	anim_layer.anchor_right = 1.0
	anim_layer.anchor_bottom = 1.0
	anim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(anim_layer)
	root.move_child(anim_layer, root.get_child_count() - 2)


func _build_turn_bar() -> void:
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(CENTER_X - 230, TURN_BAR_Y - 4)
	bar_bg.size = Vector2(460, TURN_ICON_SIZE + 8)
	bar_bg.color = Color(0.08, 0.08, 0.12, 0.85)
	root.add_child(bar_bg)

	turn_bar_container = HBoxContainer.new()
	turn_bar_container.position = Vector2(CENTER_X - 220, TURN_BAR_Y)
	turn_bar_container.add_theme_constant_override("separation", 4)
	root.add_child(turn_bar_container)


func _build_card_grid() -> void:
	# Attacker: front col (row=0, 3 slots) on RIGHT side, back col (row=1, 2 slots) on LEFT
	var atk_front_x := CENTER_X - CARD_GAP - CARD_W  # front close to center
	var atk_back_x := atk_front_x - CARD_GAP - CARD_W  # back further left
	# Defender: front col on LEFT side, back col on RIGHT
	var def_front_x := CENTER_X + CARD_GAP
	var def_back_x := def_front_x + CARD_W + CARD_GAP

	# Front row: 3 slots (slots 0,1,2)
	for i in range(3):
		var y := GRID_TOP + float(i) * (CARD_H + CARD_GAP)
		var card_a := _create_card(Vector2(atk_front_x, y))
		root.add_child(card_a)
		attacker_cards[i] = card_a
		var card_d := _create_card(Vector2(def_front_x, y))
		root.add_child(card_d)
		defender_cards[i] = card_d

	# Back row: 2 slots (slots 3,4)
	for i in range(2):
		var y := GRID_TOP + float(i) * (CARD_H + CARD_GAP) + (CARD_H + CARD_GAP) * 0.5
		var card_a := _create_card(Vector2(atk_back_x, y))
		root.add_child(card_a)
		attacker_cards[3 + i] = card_a
		var card_d := _create_card(Vector2(def_back_x, y))
		root.add_child(card_d)
		defender_cards[3 + i] = card_d


func _create_card(pos: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = Vector2(CARD_W, CARD_H)
	var style := _make_card_style(Color(0.12, 0.12, 0.16, 0.8), Color(0.25, 0.25, 0.3))
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 1)
	margin.add_child(vbox)

	# Row 1: class tab + commander id
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	vbox.add_child(top_row)

	var class_tab := ColorRect.new()
	class_tab.name = "ClassTab"
	class_tab.custom_minimum_size = Vector2(6, 14)
	class_tab.color = Color(0.4, 0.4, 0.4)
	top_row.add_child(class_tab)

	var cmd_lbl := Label.new()
	cmd_lbl.name = "CmdLabel"
	cmd_lbl.text = ""
	cmd_lbl.add_theme_font_size_override("font_size", 10)
	cmd_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	top_row.add_child(cmd_lbl)

	# Spacer pushes buff arrows to right
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var buff_lbl := Label.new()
	buff_lbl.name = "BuffLabel"
	buff_lbl.text = ""
	buff_lbl.add_theme_font_size_override("font_size", 10)
	top_row.add_child(buff_lbl)

	# Row 2: Troop name (bold colored by class)
	var name_lbl := Label.new()
	name_lbl.name = "TroopName"
	name_lbl.text = "空"
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	vbox.add_child(name_lbl)

	# Row 3: soldier count
	var count_lbl := Label.new()
	count_lbl.name = "SoldierCount"
	count_lbl.text = ""
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(count_lbl)

	# Row 4: HP bar
	var bar_bg := ColorRect.new()
	bar_bg.name = "BarBG"
	bar_bg.custom_minimum_size = Vector2(BAR_W, HP_BAR_H)
	bar_bg.color = Color(0.15, 0.15, 0.18)
	vbox.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.name = "BarFill"
	bar_fill.size = Vector2(BAR_W, HP_BAR_H)
	bar_fill.color = Color(0.3, 0.75, 0.3)
	bar_bg.add_child(bar_fill)

	# Row 5: stats line
	var stats_lbl := Label.new()
	stats_lbl.name = "Stats"
	stats_lbl.text = ""
	stats_lbl.add_theme_font_size_override("font_size", 9)
	stats_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	vbox.add_child(stats_lbl)

	# Row 6: passive + bottom row
	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 4)
	vbox.add_child(bot_row)

	var passive_lbl := Label.new()
	passive_lbl.name = "PassiveLabel"
	passive_lbl.text = ""
	passive_lbl.add_theme_font_size_override("font_size", 9)
	passive_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	bot_row.add_child(passive_lbl)

	# Death/capture overlay label (hidden by default)
	var overlay_lbl := Label.new()
	overlay_lbl.name = "OverlayLabel"
	overlay_lbl.text = ""
	overlay_lbl.visible = false
	overlay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay_lbl.anchor_right = 1.0
	overlay_lbl.anchor_bottom = 1.0
	overlay_lbl.add_theme_font_size_override("font_size", 28)
	overlay_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(overlay_lbl)

	return panel


func _build_clock_bar() -> void:
	clock_container = Control.new()
	clock_container.position = Vector2(CENTER_X - 200, CLOCK_Y)
	clock_container.size = Vector2(400, 20)
	root.add_child(clock_container)

	# Label
	var clk_lbl := _make_label("战况进度", 10, Color(0.6, 0.6, 0.55), Vector2(0, -14), Vector2(400, 14))
	clk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_container.add_child(clk_lbl)

	# 12 segments
	var seg_w := 400.0 / MAX_ROUNDS
	for i in range(MAX_ROUNDS):
		var seg := ColorRect.new()
		seg.name = "Seg%d" % i
		seg.position = Vector2(float(i) * seg_w + 1, 0)
		seg.size = Vector2(seg_w - 2, 14)
		seg.color = Color(0.15, 0.15, 0.18)
		clock_container.add_child(seg)


func _build_log_panel() -> void:
	var log_panel := PanelContainer.new()
	log_panel.position = Vector2(30, LOG_TOP)
	log_panel.size = Vector2(880, 140)
	var ls := _make_card_style(Color(0.06, 0.06, 0.1, 0.92), Color(0.25, 0.25, 0.3))
	log_panel.add_theme_stylebox_override("panel", ls)
	root.add_child(log_panel)

	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size", 12)
	log_panel.add_child(log_text)


func _build_buttons() -> void:
	var container := VBoxContainer.new()
	container.position = Vector2(940, LOG_TOP)
	container.add_theme_constant_override("separation", 6)
	root.add_child(container)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	container.add_child(row1)

	btn_play = _make_btn("播放", _on_play)
	row1.add_child(btn_play)
	btn_step = _make_btn("单步", _on_step)
	row1.add_child(btn_step)
	btn_skip = _make_btn("跳过", _on_skip)
	row1.add_child(btn_skip)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	container.add_child(row2)

	btn_speed = _make_btn("1x", _on_speed_toggle)
	btn_speed.custom_minimum_size = Vector2(50, 0)
	row2.add_child(btn_speed)

	btn_auto = _make_btn("自动", _on_auto_toggle)
	btn_auto.custom_minimum_size = Vector2(50, 0)
	row2.add_child(btn_auto)

	btn_close = _make_btn("关闭", _on_close)
	btn_close.visible = false
	row2.add_child(btn_close)


func _build_result_panel() -> void:
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(390, 300)
	result_panel.size = Vector2(500, 90)
	result_panel.visible = false
	var rs := _make_card_style(Color(0.08, 0.08, 0.12, 0.96), Color(0.85, 0.65, 0.2))
	rs.border_width_top = 2; rs.border_width_bottom = 2
	rs.border_width_left = 2; rs.border_width_right = 2
	result_panel.add_theme_stylebox_override("panel", rs)
	root.add_child(result_panel)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 28)
	result_panel.add_child(result_label)


# ═══════════════════════════════════════════════════════════
#                       BATTLE DISPLAY
# ═══════════════════════════════════════════════════════════

func show_battle(battle_result: Dictionary) -> void:
	visible = true
	_battle_state = battle_result
	_action_log = battle_result.get("log", [])
	_log_index = 0
	_playing = false
	_current_round = 0
	_captured_heroes = battle_result.get("captured_heroes", [])
	log_text.clear()
	result_panel.visible = false
	btn_close.visible = false
	btn_play.text = "播放"

	title_label.text = battle_result.get("title", "战斗")
	terrain_label.text = "地形: %s" % _get_terrain_name(battle_result.get("terrain", 0))
	round_label.text = "回合 0/%d" % MAX_ROUNDS

	# Initialize live unit data
	_live_units = {"attacker": {}, "defender": {}}
	var atk_units: Array = battle_result.get("attacker_units_initial", [])
	var def_units: Array = battle_result.get("defender_units_initial", [])
	_populate_cards(attacker_cards, atk_units, "attacker")
	_populate_cards(defender_cards, def_units, "defender")
	_update_clock(0)
	_update_turn_bar()

	if _auto_play:
		_on_play()


func _populate_cards(cards: Dictionary, units: Array, side: String) -> void:
	for slot_idx in cards.keys():
		var card: PanelContainer = cards[slot_idx]
		var vbox: VBoxContainer = card.get_child(0).get_child(0)  # margin -> vbox
		var class_tab: ColorRect = vbox.get_child(0).get_child(0)  # top_row -> class_tab
		var cmd_lbl: Label = vbox.get_child(0).get_child(1)
		var buff_lbl: Label = vbox.get_child(0).get_child(3)
		var name_lbl: Label = vbox.get_node("TroopName")
		var count_lbl: Label = vbox.get_node("SoldierCount")
		var bar_bg: ColorRect = vbox.get_node("BarBG")
		var bar_fill: ColorRect = bar_bg.get_node("BarFill")
		var stats_lbl: Label = vbox.get_node("Stats")
		var passive_lbl: Label = vbox.get_child(5).get_child(0)  # bot_row -> passive
		var overlay: Label = card.get_node("OverlayLabel")
		overlay.visible = false

		# Map slot index: front=0,1,2 (row=0), back=3,4 (row=1)
		var unit: Dictionary = {}
		if slot_idx < units.size() and units[slot_idx] != null:
			unit = units[slot_idx]

		if unit.is_empty():
			name_lbl.text = "空"
			cmd_lbl.text = ""
			buff_lbl.text = ""
			count_lbl.text = ""
			stats_lbl.text = ""
			passive_lbl.text = ""
			bar_fill.size.x = 0
			class_tab.color = Color(0.2, 0.2, 0.2)
			var empty_s := _make_card_style(Color(0.08, 0.08, 0.1, 0.5), Color(0.18, 0.18, 0.2))
			card.add_theme_stylebox_override("panel", empty_s)
			_live_units[side].erase(slot_idx)
		else:
			_live_units[side][slot_idx] = unit.duplicate()
			var uclass: String = unit.get("class", "ashigaru")
			var cc: Color = CLASS_COLORS.get(uclass, Color(0.3, 0.3, 0.35))
			class_tab.color = cc
			var card_style := _make_card_style(cc.darkened(0.6), cc.darkened(0.2))
			card.add_theme_stylebox_override("panel", card_style)

			cmd_lbl.text = str(unit.get("commander_id", ""))
			buff_lbl.text = ""
			var troop_name := _get_troop_display_name(unit.get("troop_id", ""))
			name_lbl.text = troop_name
			name_lbl.add_theme_color_override("font_color", cc.lightened(0.5))

			var soldiers: int = unit.get("soldiers", 0)
			var max_soldiers: int = unit.get("max_soldiers", soldiers)
			count_lbl.text = "兵力: %d/%d" % [soldiers, max_soldiers]
			var ratio := float(soldiers) / max(1, max_soldiers)
			bar_fill.size.x = BAR_W * ratio
			bar_fill.color = _hp_color(ratio)

			stats_lbl.text = "ATK:%d DEF:%d SPD:%d" % [unit.get("atk", 0), unit.get("def", 0), unit.get("spd", 0)]
			var passive_name: String = unit.get("passive", "")
			passive_lbl.text = passive_name if passive_name != "" else ""


func _update_card_soldiers(side: String, slot_idx: int, soldiers: int, max_soldiers: int) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var vbox: VBoxContainer = card.get_child(0).get_child(0)
	var count_lbl: Label = vbox.get_node("SoldierCount")
	var bar_bg: ColorRect = vbox.get_node("BarBG")
	var bar_fill: ColorRect = bar_bg.get_node("BarFill")

	count_lbl.text = "兵力: %d/%d" % [soldiers, max_soldiers]
	var ratio := float(soldiers) / max(1, max_soldiers)
	var spd := ANIM_BASE_SPEED / _speed_mult
	var tween := create_tween()
	tween.tween_property(bar_fill, "size:x", BAR_W * ratio, spd)
	bar_fill.color = _hp_color(ratio)

	# Update live tracking
	if _live_units[side].has(slot_idx):
		_live_units[side][slot_idx]["soldiers"] = soldiers

	if soldiers <= 0:
		_apply_death_overlay(side, slot_idx)


func _apply_death_overlay(side: String, slot_idx: int) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var overlay: Label = card.get_node("OverlayLabel")

	# Check if captured
	var unit_data: Dictionary = _live_units[side].get(slot_idx, {})
	var cmd_id = unit_data.get("commander_id", "")
	var is_captured := false
	for hero_id in _captured_heroes:
		if str(hero_id) == str(cmd_id):
			is_captured = true
			break

	if is_captured:
		overlay.text = "俘获"
		overlay.add_theme_color_override("font_color", Color(0.3, 0.5, 1.0))
	else:
		overlay.text = "歼灭"
		overlay.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	overlay.visible = true

	# Dim card
	card.modulate = Color(0.4, 0.4, 0.4, 0.8)


func _get_card_center(side: String, slot_idx: int) -> Vector2:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return Vector2(CENTER_X, GRID_TOP + 150)
	var card: PanelContainer = cards[slot_idx]
	return card.position + card.size * 0.5


# ═══════════════════════════════════════════════════════════
#                     TURN ORDER BAR
# ═══════════════════════════════════════════════════════════

func _update_turn_bar() -> void:
	# Clear existing icons
	for ch in turn_bar_container.get_children():
		ch.queue_free()

	# Collect upcoming actions from log (next 10 attack/passive/ability entries)
	var icons_added := 0
	var idx := _log_index
	while idx < _action_log.size() and icons_added < 10:
		var entry: Dictionary = _action_log[idx]
		var action: String = entry.get("action", "")
		if action in ["attack", "passive", "ability"]:
			var side: String = entry.get("side", "attacker")
			var slot: int = entry.get("slot", 0)
			var unit_data: Dictionary = _live_units[side].get(slot, {})
			var uclass: String = unit_data.get("class", "ashigaru")
			var cc: Color = CLASS_COLORS.get(uclass, Color(0.3, 0.3, 0.35))
			var abbr: String = CLASS_ABBR.get(uclass, "?")

			var icon := ColorRect.new()
			icon.custom_minimum_size = Vector2(TURN_ICON_SIZE, TURN_ICON_SIZE)
			icon.color = cc.darkened(0.3) if icons_added > 0 else cc
			turn_bar_container.add_child(icon)

			var icon_lbl := Label.new()
			icon_lbl.text = abbr
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon_lbl.size = Vector2(TURN_ICON_SIZE, TURN_ICON_SIZE)
			icon_lbl.add_theme_font_size_override("font_size", 14)
			icon_lbl.add_theme_color_override("font_color", Color.WHITE if icons_added > 0 else Color(1, 0.95, 0.6))
			icon.add_child(icon_lbl)

			# Gold border for current
			if icons_added == 0:
				var border := _make_border_rect(TURN_ICON_SIZE, TURN_ICON_SIZE, Color(1, 0.85, 0.3))
				icon.add_child(border)

			# Side indicator dot
			var dot := ColorRect.new()
			dot.size = Vector2(6, 6)
			dot.position = Vector2(2, 2)
			dot.color = Color(0.95, 0.6, 0.4) if side == "attacker" else Color(0.4, 0.6, 0.95)
			icon.add_child(dot)

			icons_added += 1
		idx += 1


func _update_clock(round_num: int) -> void:
	var seg_w := 400.0 / MAX_ROUNDS
	for i in range(MAX_ROUNDS):
		var seg_name := "Seg%d" % i
		var seg := clock_container.get_node_or_null(seg_name)
		if seg == null:
			continue
		if i < round_num:
			var t := float(i) / max(1, MAX_ROUNDS - 1)
			if t < 0.4:
				seg.color = Color(0.2, 0.7, 0.3)
			elif t < 0.7:
				seg.color = Color(0.8, 0.75, 0.2)
			else:
				seg.color = Color(0.8, 0.25, 0.2)
		else:
			seg.color = Color(0.15, 0.15, 0.18)


# ═══════════════════════════════════════════════════════════
#                    ATTACK ANIMATIONS
# ═══════════════════════════════════════════════════════════

func _animate_attack(source_side: String, source_slot: int, target_side: String, target_slot: int, damage: int, max_soldiers: int) -> void:
	var from_pos := _get_card_center(source_side, source_slot)
	var to_pos := _get_card_center(target_side, target_slot)

	# Determine attack type from class
	var unit_data: Dictionary = _live_units[source_side].get(source_slot, {})
	var uclass: String = unit_data.get("class", "ashigaru")

	# Draw attack line
	var line_color: Color
	var line_width := 2.0
	match uclass:
		"archer", "cannon":
			line_color = Color(1, 0.9, 0.3, 0.9)
		"mage", "mage_unit", "priest":
			line_color = Color(0.7, 0.3, 1.0, 0.9)
		"ninja":
			line_color = Color(0.3, 0.9, 0.4, 0.9)
		_:
			line_color = Color(1, 0.3, 0.2, 0.9)

	_draw_attack_line(from_pos, to_pos, line_color, line_width)

	# Flash target card red
	_flash_card(target_side, target_slot, Color(1, 0.2, 0.15, 0.5))

	# Glow source card gold
	_glow_card(source_side, source_slot)

	# Spawn damage number
	_spawn_damage_number(to_pos, damage, max_soldiers)


func _draw_attack_line(from_pos: Vector2, to_pos: Vector2, color: Color, width: float) -> void:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.add_point(from_pos)
	line.add_point(from_pos)  # will animate to target
	anim_layer.add_child(line)

	var spd := 0.3 / _speed_mult
	var tween := create_tween()
	tween.tween_method(func(t: float):
		if is_instance_valid(line):
			line.set_point_position(1, from_pos.lerp(to_pos, t))
	, 0.0, 1.0, spd)
	tween.tween_property(line, "modulate:a", 0.0, spd * 0.5)
	tween.tween_callback(func():
		if is_instance_valid(line):
			line.queue_free()
	)


func _flash_card(side: String, slot_idx: int, color: Color) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var flash := ColorRect.new()
	flash.size = card.size
	flash.color = color
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(flash)
	var spd := ANIM_BASE_SPEED / _speed_mult
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, spd)
	tw.tween_callback(flash.queue_free)


func _glow_card(side: String, slot_idx: int) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var glow := _make_border_rect(CARD_W, CARD_H, Color(1, 0.85, 0.3, 0.8))
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(glow)
	var spd := (ANIM_BASE_SPEED + 0.2) / _speed_mult
	var tw := create_tween()
	tw.tween_property(glow, "modulate:a", 0.0, spd)
	tw.tween_callback(glow.queue_free)


func _spawn_damage_number(pos: Vector2, damage: int, max_soldiers: int) -> void:
	var lbl := Label.new()
	lbl.text = "-%d" % damage
	var is_critical := damage > max_soldiers * 0.5
	lbl.add_theme_font_size_override("font_size", 22 if is_critical else 16)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.3) if is_critical else Color(1, 0.4, 0.3))
	lbl.position = pos + Vector2(-20, -30)
	lbl.z_index = 100
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim_layer.add_child(lbl)

	var spd := 0.8 / _speed_mult
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 40, spd)
	tw.tween_property(lbl, "modulate:a", 0.0, spd)
	tw.chain().tween_callback(lbl.queue_free)


func _flash_passive(side: String, slot_idx: int) -> void:
	_flash_card(side, slot_idx, Color(0.3, 0.6, 1.0, 0.4))


# ═══════════════════════════════════════════════════════════
#                      LOG PLAYBACK
# ═══════════════════════════════════════════════════════════

func _on_play() -> void:
	if _playing:
		_playing = false
		btn_play.text = "播放"
		return
	_playing = true
	btn_play.text = "暂停"
	_play_next()


func _play_next() -> void:
	if not _playing or _log_index >= _action_log.size():
		_finish_playback()
		return
	_apply_log_entry(_action_log[_log_index])
	_log_index += 1
	_update_turn_bar()
	var delay := (ANIM_BASE_SPEED + 0.18) / _speed_mult
	get_tree().create_timer(delay).timeout.connect(_play_next)


func _on_step() -> void:
	_playing = false
	btn_play.text = "播放"
	if _log_index < _action_log.size():
		_apply_log_entry(_action_log[_log_index])
		_log_index += 1
		_update_turn_bar()
	if _log_index >= _action_log.size():
		_finish_playback()


func _on_skip() -> void:
	_playing = false
	while _log_index < _action_log.size():
		_apply_log_entry(_action_log[_log_index])
		_log_index += 1
	_finish_playback()


func _on_close() -> void:
	visible = false
	combat_view_closed.emit()


func _on_speed_toggle() -> void:
	if _speed_mult == 1.0:
		_speed_mult = 2.0
		btn_speed.text = "2x"
	elif _speed_mult == 2.0:
		_speed_mult = 3.0
		btn_speed.text = "3x"
	else:
		_speed_mult = 1.0
		btn_speed.text = "1x"


func _on_auto_toggle() -> void:
	_auto_play = not _auto_play
	btn_auto.text = "自动" if _auto_play else "手动"


func _apply_log_entry(entry: Dictionary) -> void:
	var action: String = entry.get("action", "")
	var side: String = entry.get("side", "")
	var slot_idx: int = entry.get("slot", -1)
	var damage: int = entry.get("damage", 0)
	var remaining: int = entry.get("remaining_soldiers", 0)
	var max_s: int = entry.get("max_soldiers", remaining)
	var round_num: int = entry.get("round", 0)
	var desc: String = entry.get("desc", "")
	var target_side: String = entry.get("target_side", "")
	var target_slot: int = entry.get("target_slot", -1)
	var target_name: String = entry.get("target_name", "")

	if round_num > 0 and round_num != _current_round:
		_current_round = round_num
		round_label.text = "回合 %d/%d" % [round_num, MAX_ROUNDS]
		_update_clock(round_num)

	var log_line: String = ""
	match action:
		"attack":
			log_line = "[color=#dda]%s[/color] → %s [color=#f88](-%d兵)[/color]" % [desc, target_name, damage]
			if target_slot >= 0:
				_update_card_soldiers(target_side, target_slot, remaining, max_s)
				_animate_attack(side, slot_idx, target_side, target_slot, damage, max_s)
		"passive":
			log_line = "[color=#8cf]被动[/color] %s" % desc
			if slot_idx >= 0:
				_flash_passive(side, slot_idx)
				if remaining > 0:
					_update_card_soldiers(side, slot_idx, remaining, max_s)
		"ability":
			log_line = "[color=#fc8]技能[/color] %s" % desc
			if slot_idx >= 0:
				_glow_card(side, slot_idx)
		"siege":
			log_line = "[color=#f88]攻城[/color] %s" % desc
		"round_start":
			log_line = "[color=#777]════ 第%d回合 ════[/color]" % round_num
		"death":
			log_line = "[color=#f44]歼灭[/color] %s" % desc
			if slot_idx >= 0:
				_apply_death_overlay(side, slot_idx)
		_:
			log_line = desc if desc != "" else str(entry)

	if log_line != "":
		log_text.append_text(log_line + "\n")


func _finish_playback() -> void:
	_playing = false
	btn_play.text = "播放"
	btn_close.visible = true

	var winner: String = _battle_state.get("winner", "")
	result_panel.visible = true
	if winner == "attacker":
		result_label.text = "进攻方胜利!"
		result_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	elif winner == "defender":
		result_label.text = "防御方胜利!"
		result_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1))
	else:
		result_label.text = "战斗结束"
		result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	# Apply final unit states
	var atk_final: Array = _battle_state.get("attacker_units_final", [])
	var def_final: Array = _battle_state.get("defender_units_final", [])
	_populate_cards(attacker_cards, atk_final, "attacker")
	_populate_cards(defender_cards, def_final, "defender")

	# Re-apply death overlays for final state
	for slot in attacker_cards.keys():
		if slot < atk_final.size() and atk_final[slot] != null:
			if atk_final[slot].get("soldiers", 0) <= 0:
				_apply_death_overlay("attacker", slot)
	for slot in defender_cards.keys():
		if slot < def_final.size() and def_final[slot] != null:
			if def_final[slot].get("soldiers", 0) <= 0:
				_apply_death_overlay("defender", slot)


# ═══════════════════════════════════════════════════════════
#                        HELPERS
# ═══════════════════════════════════════════════════════════

func _make_label(text: String, size: int, color: Color, pos: Vector2, sz: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.size = sz
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	return lbl


func _make_btn(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)
	return btn


func _make_card_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg_color
	s.border_color = border_color
	s.border_width_top = 1; s.border_width_bottom = 1
	s.border_width_left = 1; s.border_width_right = 1
	s.corner_radius_top_left = 4; s.corner_radius_top_right = 4
	s.corner_radius_bottom_left = 4; s.corner_radius_bottom_right = 4
	return s


func _make_border_rect(w: float, h: float, color: Color) -> ColorRect:
	# Creates a visible border effect using a colored rect with transparency trick
	var outer := ColorRect.new()
	outer.size = Vector2(w, h)
	outer.position = Vector2.ZERO
	outer.color = Color(color.r, color.g, color.b, color.a * 0.3)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return outer


func _hp_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.3, 0.75, 0.3)
	elif ratio > 0.3:
		return Color(0.85, 0.75, 0.2)
	else:
		return Color(0.85, 0.2, 0.2)


func _get_terrain_name(terrain) -> String:
	match terrain:
		0: return "平原"
		1: return "森林"
		2: return "山地"
		3: return "沼泽"
		4: return "海岸"
		5: return "要塞"
	return "平原"


func _get_troop_display_name(troop_id: String) -> String:
	# UNIT_DEFS and LIGHT_UNIT_DEFS are nested by faction ID; iterate sub-dicts.
	for faction_id in FactionData.UNIT_DEFS:
		var faction_units: Dictionary = FactionData.UNIT_DEFS[faction_id]
		if faction_units.has(troop_id):
			return faction_units[troop_id].get("name", troop_id)
	for faction_id in FactionData.LIGHT_UNIT_DEFS:
		var faction_units: Dictionary = FactionData.LIGHT_UNIT_DEFS[faction_id]
		if faction_units.has(troop_id):
			return faction_units[troop_id].get("name", troop_id)
	return troop_id


func _on_combat_started(_attacker_id: int, _tile_index: int) -> void:
	pass


# ═══════════════════════════════════════════════════════════
#                      SAVE / LOAD
# ═══════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	return {}

func from_save_data(_data: Dictionary) -> void:
	pass
