## combat_view.gd - Sengoku Rance style battle visualization (v1.5)
## Shows 5v5 formation grid with animated combat resolution
extends CanvasLayer

const FactionData = preload("res://systems/faction/faction_data.gd")

signal combat_view_closed()

# ── Layout constants ──
const SLOT_SIZE := Vector2(140, 80)
const SLOT_GAP := 8.0
const GRID_OFFSET_LEFT := 40.0
const GRID_OFFSET_RIGHT := 700.0
const GRID_TOP := 160.0
const BAR_HEIGHT := 6.0
const ANIM_SPEED := 0.4

# ── Unit slot colors by class ──
const CLASS_COLORS := {
	"ashigaru": Color(0.5, 0.55, 0.4),
	"samurai": Color(0.65, 0.45, 0.3),
	"cavalry": Color(0.4, 0.35, 0.6),
	"archer": Color(0.35, 0.55, 0.35),
	"cannon": Color(0.55, 0.35, 0.35),
	"ninja": Color(0.3, 0.3, 0.45),
	"mage": Color(0.35, 0.3, 0.6),
	"special": Color(0.6, 0.5, 0.2),
}

# ── State ──
var _battle_state: Dictionary = {}
var _action_log: Array = []
var _log_index: int = 0
var _playing: bool = false
var _auto_play: bool = true

# ── UI refs ──
var root: Control
var bg: ColorRect
var title_label: Label
var terrain_label: Label
var round_label: Label

var attacker_slots: Array = []  # Array of PanelContainer (5 slots)
var defender_slots: Array = []

var log_text: RichTextLabel
var btn_play: Button
var btn_step: Button
var btn_skip: Button
var btn_close: Button

var result_panel: PanelContainer
var result_label: Label


func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()
	EventBus.combat_started.connect(_on_combat_started)


# ═══════════════ UI CONSTRUCTION ═══════════════

func _build_ui() -> void:
	root = Control.new()
	root.name = "CombatViewRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# Dark background
	bg = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.05, 0.06, 0.1, 0.95)
	root.add_child(bg)

	# Title
	title_label = Label.new()
	title_label.text = "战斗"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 20)
	title_label.size = Vector2(1280, 40)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	root.add_child(title_label)

	# Terrain info
	terrain_label = Label.new()
	terrain_label.text = "地形: 平原"
	terrain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terrain_label.position = Vector2(0, 60)
	terrain_label.size = Vector2(1280, 24)
	terrain_label.add_theme_font_size_override("font_size", 16)
	terrain_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.6))
	root.add_child(terrain_label)

	# Round counter
	round_label = Label.new()
	round_label.text = "回合 0/12"
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.position = Vector2(0, 90)
	round_label.size = Vector2(1280, 30)
	round_label.add_theme_font_size_override("font_size", 20)
	round_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6))
	root.add_child(round_label)

	# VS divider
	var vs_label := Label.new()
	vs_label.text = "VS"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.position = Vector2(560, 250)
	vs_label.size = Vector2(160, 50)
	vs_label.add_theme_font_size_override("font_size", 36)
	vs_label.add_theme_color_override("font_color", Color(1, 0.4, 0.3))
	root.add_child(vs_label)

	# Build formation grids
	_build_formation_grid(true)   # Attacker (left)
	_build_formation_grid(false)  # Defender (right)

	# Battle log
	var log_panel := PanelContainer.new()
	log_panel.position = Vector2(40, 460)
	log_panel.size = Vector2(900, 180)
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.08, 0.08, 0.12, 0.9)
	log_style.border_color = Color(0.3, 0.3, 0.35)
	log_style.border_width_top = 1
	log_style.border_width_bottom = 1
	log_style.border_width_left = 1
	log_style.border_width_right = 1
	log_style.corner_radius_top_left = 4
	log_style.corner_radius_top_right = 4
	log_style.corner_radius_bottom_left = 4
	log_style.corner_radius_bottom_right = 4
	log_panel.add_theme_stylebox_override("panel", log_style)
	root.add_child(log_panel)

	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size", 14)
	log_panel.add_child(log_text)

	# Control buttons
	_build_buttons()

	# Result overlay
	_build_result_panel()


func _build_formation_grid(is_attacker: bool) -> void:
	var x_offset: float = GRID_OFFSET_LEFT if is_attacker else GRID_OFFSET_RIGHT
	var slots_ref: Array = attacker_slots if is_attacker else defender_slots
	var side_label := Label.new()
	side_label.text = "进攻方" if is_attacker else "防御方"
	side_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	side_label.position = Vector2(x_offset, GRID_TOP - 35)
	side_label.size = Vector2(SLOT_SIZE.x * 3 + SLOT_GAP * 2, 30)
	side_label.add_theme_font_size_override("font_size", 18)
	side_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.5) if is_attacker else Color(0.5, 0.7, 0.9))
	root.add_child(side_label)

	# Front row: 3 slots
	for i in range(3):
		var slot := _create_unit_slot(
			Vector2(x_offset + float(i) * (SLOT_SIZE.x + SLOT_GAP), GRID_TOP),
			is_attacker
		)
		root.add_child(slot)
		slots_ref.append(slot)

	# Back row: 2 slots (centered)
	var back_offset_x: float = x_offset + (SLOT_SIZE.x + SLOT_GAP) * 0.5
	for i in range(2):
		var slot := _create_unit_slot(
			Vector2(back_offset_x + float(i) * (SLOT_SIZE.x + SLOT_GAP), GRID_TOP + SLOT_SIZE.y + SLOT_GAP),
			is_attacker
		)
		root.add_child(slot)
		slots_ref.append(slot)


func _create_unit_slot(pos: Vector2, _is_attacker: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = SLOT_SIZE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_width_left = 1
	style.border_width_right = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Unit name
	var name_lbl := Label.new()
	name_lbl.name = "UnitName"
	name_lbl.text = "空"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.75))
	vbox.add_child(name_lbl)

	# Stats line (ATK/DEF/SPD)
	var stats_lbl := Label.new()
	stats_lbl.name = "Stats"
	stats_lbl.text = ""
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 11)
	stats_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	vbox.add_child(stats_lbl)

	# HP bar background
	var bar_bg := ColorRect.new()
	bar_bg.name = "BarBG"
	bar_bg.custom_minimum_size = Vector2(120, BAR_HEIGHT)
	bar_bg.color = Color(0.2, 0.2, 0.2)
	vbox.add_child(bar_bg)

	# HP bar fill (child of bar_bg)
	var bar_fill := ColorRect.new()
	bar_fill.name = "BarFill"
	bar_fill.size = Vector2(120, BAR_HEIGHT)
	bar_fill.color = Color(0.3, 0.75, 0.3)
	bar_bg.add_child(bar_fill)

	# Soldier count
	var count_lbl := Label.new()
	count_lbl.name = "SoldierCount"
	count_lbl.text = ""
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(count_lbl)

	return panel


func _build_buttons() -> void:
	var btn_container := HBoxContainer.new()
	btn_container.position = Vector2(960, 480)
	btn_container.add_theme_constant_override("separation", 8)
	root.add_child(btn_container)

	btn_play = Button.new()
	btn_play.text = "播放"
	btn_play.pressed.connect(_on_play)
	btn_container.add_child(btn_play)

	btn_step = Button.new()
	btn_step.text = "单步"
	btn_step.pressed.connect(_on_step)
	btn_container.add_child(btn_step)

	btn_skip = Button.new()
	btn_skip.text = "跳过"
	btn_skip.pressed.connect(_on_skip)
	btn_container.add_child(btn_skip)

	btn_close = Button.new()
	btn_close.text = "关闭"
	btn_close.pressed.connect(_on_close)
	btn_close.visible = false
	btn_container.add_child(btn_close)


func _build_result_panel() -> void:
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(400, 280)
	result_panel.size = Vector2(480, 100)
	result_panel.visible = false
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	rs.border_color = Color(0.8, 0.6, 0.2)
	rs.border_width_top = 2
	rs.border_width_bottom = 2
	rs.border_width_left = 2
	rs.border_width_right = 2
	rs.corner_radius_top_left = 6
	rs.corner_radius_top_right = 6
	rs.corner_radius_bottom_left = 6
	rs.corner_radius_bottom_right = 6
	result_panel.add_theme_stylebox_override("panel", rs)
	root.add_child(result_panel)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 28)
	result_panel.add_child(result_label)


# ═══════════════ BATTLE DISPLAY ═══════════════

func show_battle(battle_result: Dictionary) -> void:
	## Display a battle from CombatSystem result.
	## battle_result: { winner, attacker_units, defender_units, log, terrain, rounds }
	visible = true
	_battle_state = battle_result
	_action_log = battle_result.get("log", [])
	_log_index = 0
	_playing = false
	log_text.clear()
	result_panel.visible = false
	btn_close.visible = false

	# Set title
	title_label.text = battle_result.get("title", "战斗")

	# Set terrain
	var terrain_name: String = _get_terrain_name(battle_result.get("terrain", 0))
	terrain_label.text = "地形: %s" % terrain_name
	round_label.text = "回合 0/12"

	# Initialize unit displays
	_display_units(attacker_slots, battle_result.get("attacker_units_initial", []))
	_display_units(defender_slots, battle_result.get("defender_units_initial", []))

	if _auto_play:
		_on_play()


func _display_units(slots: Array, units: Array) -> void:
	for i in range(slots.size()):
		var slot: PanelContainer = slots[i]
		var vbox: VBoxContainer = slot.get_child(0)
		var name_lbl: Label = vbox.get_node("UnitName")
		var stats_lbl: Label = vbox.get_node("Stats")
		var bar_bg: ColorRect = vbox.get_node("BarBG")
		var bar_fill: ColorRect = bar_bg.get_node("BarFill")
		var count_lbl: Label = vbox.get_node("SoldierCount")

		if i < units.size() and units[i] != null:
			var unit: Dictionary = units[i]
			var troop_name: String = _get_troop_display_name(unit.get("troop_id", ""))
			name_lbl.text = troop_name
			stats_lbl.text = "ATK:%d DEF:%d SPD:%d" % [unit.get("atk", 0), unit.get("def", 0), unit.get("spd", 0)]
			var soldiers: int = unit.get("soldiers", 0)
			var max_soldiers: int = unit.get("max_soldiers", soldiers)
			count_lbl.text = "%d/%d" % [soldiers, max_soldiers]

			var ratio: float = float(soldiers) / max(1, max_soldiers)
			bar_fill.size.x = 120.0 * ratio
			bar_fill.color = _hp_color(ratio)

			# Color slot by class
			var unit_class: String = unit.get("class", "ashigaru")
			var slot_color: Color = CLASS_COLORS.get(unit_class, Color(0.2, 0.2, 0.25))
			var style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate()
			style.bg_color = slot_color.darkened(0.5)
			style.border_color = slot_color.lightened(0.2)
			slot.add_theme_stylebox_override("panel", style)
		else:
			name_lbl.text = "空"
			stats_lbl.text = ""
			count_lbl.text = ""
			bar_fill.size.x = 0
			var empty_style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate()
			empty_style.bg_color = Color(0.1, 0.1, 0.12, 0.5)
			empty_style.border_color = Color(0.2, 0.2, 0.22)
			slot.add_theme_stylebox_override("panel", empty_style)


func _update_unit_slot(slot: PanelContainer, soldiers: int, max_soldiers: int) -> void:
	var vbox: VBoxContainer = slot.get_child(0)
	var bar_bg: ColorRect = vbox.get_node("BarBG")
	var bar_fill: ColorRect = bar_bg.get_node("BarFill")
	var count_lbl: Label = vbox.get_node("SoldierCount")

	count_lbl.text = "%d/%d" % [soldiers, max_soldiers]
	var ratio: float = float(soldiers) / max(1, max_soldiers)
	# Animate bar
	var tween := create_tween()
	tween.tween_property(bar_fill, "size:x", 120.0 * ratio, ANIM_SPEED)
	bar_fill.color = _hp_color(ratio)

	if soldiers <= 0:
		# Death effect: flash red then dim
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate()
		style.bg_color = Color(0.4, 0.1, 0.1, 0.8)
		slot.add_theme_stylebox_override("panel", style)
		var name_lbl: Label = vbox.get_node("UnitName")
		name_lbl.add_theme_color_override("font_color", Color(0.5, 0.3, 0.3))


func _hp_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.3, 0.75, 0.3)
	elif ratio > 0.3:
		return Color(0.8, 0.7, 0.2)
	else:
		return Color(0.8, 0.2, 0.2)


# ═══════════════ LOG PLAYBACK ═══════════════

func _on_play() -> void:
	_playing = true
	btn_play.text = "暂停"
	_play_next()


func _play_next() -> void:
	if not _playing or _log_index >= _action_log.size():
		_finish_playback()
		return
	_apply_log_entry(_action_log[_log_index])
	_log_index += 1
	# Schedule next action
	get_tree().create_timer(ANIM_SPEED + 0.15).timeout.connect(_play_next)


func _on_step() -> void:
	_playing = false
	btn_play.text = "播放"
	if _log_index < _action_log.size():
		_apply_log_entry(_action_log[_log_index])
		_log_index += 1
	if _log_index >= _action_log.size():
		_finish_playback()


func _on_skip() -> void:
	_playing = false
	# Apply all remaining log entries instantly
	while _log_index < _action_log.size():
		_apply_log_entry(_action_log[_log_index])
		_log_index += 1
	_finish_playback()


func _on_close() -> void:
	visible = false
	combat_view_closed.emit()


func _apply_log_entry(entry: Dictionary) -> void:
	var action: String = entry.get("action", "")
	var side: String = entry.get("side", "")
	var slot_idx: int = entry.get("slot", -1)
	var damage: int = entry.get("damage", 0)
	var remaining: int = entry.get("remaining_soldiers", 0)
	var max_s: int = entry.get("max_soldiers", remaining)
	var round_num: int = entry.get("round", 0)
	var desc: String = entry.get("desc", "")

	if round_num > 0:
		round_label.text = "回合 %d/12" % round_num

	# Build log text
	var log_line: String = ""
	match action:
		"attack":
			var target_side: String = entry.get("target_side", "")
			var target_slot: int = entry.get("target_slot", -1)
			log_line = "[color=#dda]%s[/color] 攻击 → %s (-%d兵)" % [desc, entry.get("target_name", ""), damage]
			# Update target slot
			var target_slots: Array = attacker_slots if target_side == "attacker" else defender_slots
			if target_slot >= 0 and target_slot < target_slots.size():
				_update_unit_slot(target_slots[target_slot], remaining, max_s)
				_flash_slot(target_slots[target_slot], Color(1, 0.3, 0.2, 0.6))
		"passive":
			log_line = "[color=#8cf]被动[/color] %s" % desc
			if slot_idx >= 0:
				var slots: Array = attacker_slots if side == "attacker" else defender_slots
				if slot_idx < slots.size():
					_flash_slot(slots[slot_idx], Color(0.3, 0.6, 1, 0.4))
		"ability":
			log_line = "[color=#fc8]技能[/color] %s" % desc
		"siege":
			log_line = "[color=#f88]攻城[/color] %s" % desc
		"round_start":
			log_line = "[color=#aaa]─── 第%d回合 ───[/color]" % round_num
		"death":
			log_line = "[color=#f44]歼灭[/color] %s 全军覆没!" % desc
		_:
			log_line = desc if desc != "" else str(entry)

	if log_line != "":
		log_text.append_text(log_line + "\n")


func _flash_slot(slot: PanelContainer, color: Color) -> void:
	var flash := ColorRect.new()
	flash.size = slot.size
	flash.color = color
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, ANIM_SPEED)
	tween.tween_callback(flash.queue_free)


func _finish_playback() -> void:
	_playing = false
	btn_play.text = "播放"
	btn_close.visible = true

	# Show result
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

	# Display final unit states
	_display_units(attacker_slots, _battle_state.get("attacker_units_final", []))
	_display_units(defender_slots, _battle_state.get("defender_units_final", []))


# ═══════════════ HELPERS ═══════════════

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
	if FactionData.UNIT_DEFS.has(troop_id):
		return FactionData.UNIT_DEFS[troop_id].get("name", troop_id)
	if FactionData.LIGHT_UNIT_DEFS.has(troop_id):
		return FactionData.LIGHT_UNIT_DEFS[troop_id].get("name", troop_id)
	return troop_id


func _on_combat_started(_attacker_id: int, _tile_index: int) -> void:
	# Combat view will be shown explicitly by GameManager after resolution
	pass


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {}

func from_save_data(_data: Dictionary) -> void:
	pass
