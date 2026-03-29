## combat_view.gd - Sengoku Rance 07 style battle visualization (v3.0)
## Full presentation system: screen shake, card physics, class projectiles, kill cutscenes,
## passive banners, combo counter, round transitions, hero KO, AoE highlight
extends CanvasLayer

const FactionData = preload("res://systems/faction/faction_data.gd")
const CounterMatrix = preload("res://systems/combat/counter_matrix.gd")
const ChibiLoader = preload("res://systems/combat/chibi_sprite_loader.gd")
const VfxLoaderRef = preload("res://systems/combat/vfx_loader.gd")

## Archetype display names for counter indicator labels
const ARCHETYPE_LABELS := {
	"infantry": "步兵", "heavy_infantry": "重步", "cavalry": "骑兵",
	"archer": "弓手", "gunner": "火枪", "mage": "法师", "assassin": "刺客",
	"berserker": "狂战", "priest": "祭司", "artillery": "炮兵", "tank": "坦克",
	"undead_infantry": "亡灵", "mech": "机甲", "boss": "Boss", "fodder": "杂兵",
}

signal combat_view_closed()
signal ultimate_vfx_finished(hero_id: String)
signal awakening_vfx_finished(hero_id: String)

# ── Layout constants ──
const CARD_W := 180.0
const CARD_H := 130.0
const CARD_GAP := 6.0
const BAR_W := 140.0
const BAR_H := 8.0
const HP_BAR_H := 7.0
const HERO_BAR_H := 4.0
const SCREEN_W := 1280.0
const SCREEN_H := 720.0
const CENTER_X := 640.0
const DIVIDER_X := 640.0
const GRID_TOP := 140.0
const TURN_BAR_Y := 100.0
const TURN_ICON_SIZE := 40.0
const MAX_ROUNDS := 8
const CLOCK_Y := 540.0
const LOG_TOP := 570.0
const ANIM_BASE_SPEED := 0.4

# ── Shake / juice constants ──
const SHAKE_LIGHT := 3.0
const SHAKE_MEDIUM := 6.0
const SHAKE_HEAVY := 12.0
const SHAKE_CRIT := 18.0
const CARD_BOUNCE_PX := 4.0
const KILL_SLOWMO_SCALE := 0.3
const KILL_FLASH_DURATION := 0.12
const COMBO_DECAY_TIME := 2.5

# ── Class colors ──
const CLASS_COLORS := {
	"ashigaru": Color(0.55, 0.6, 0.45),
	"samurai":  Color(0.75, 0.5, 0.3),
	"cavalry":  Color(0.5, 0.35, 0.7),
	"archer":   Color(0.35, 0.65, 0.35),
	"cannon":   Color(0.65, 0.35, 0.35),
	"ninja":    Color(0.3, 0.4, 0.55),
	"mage":     Color(0.45, 0.3, 0.7),
	"special":  Color(0.7, 0.6, 0.25),
	"priest":   Color(0.65, 0.55, 0.75),
	"mage_unit":Color(0.45, 0.3, 0.7),
}

const CLASS_ABBR := {
	"ashigaru":"ASH","samurai":"SAM","cavalry":"CAV","archer":"ARC",
	"cannon":"CAN","ninja":"NIN","mage":"MAG","special":"SPE",
	"priest":"PRI","mage_unit":"MAG",
}

# ── Projectile styles per class ──
const PROJ_STYLES := {
	"ashigaru": {"type": "slash", "color": Color(1, 0.6, 0.3, 0.9), "width": 3.0, "particles": 4},
	"samurai":  {"type": "slash", "color": Color(1, 0.85, 0.4, 0.95), "width": 4.0, "particles": 6},
	"cavalry":  {"type": "charge", "color": Color(0.8, 0.5, 1.0, 0.9), "width": 5.0, "particles": 8},
	"archer":   {"type": "arrow", "color": Color(0.6, 1.0, 0.5, 0.9), "width": 2.0, "particles": 3},
	"cannon":   {"type": "cannonball", "color": Color(1, 0.7, 0.2, 0.95), "width": 6.0, "particles": 12},
	"ninja":    {"type": "shuriken", "color": Color(0.4, 0.9, 0.7, 0.85), "width": 2.0, "particles": 5},
	"mage":     {"type": "magic", "color": Color(0.6, 0.3, 1.0, 0.9), "width": 4.0, "particles": 10},
	"priest":   {"type": "magic", "color": Color(1, 0.8, 1.0, 0.85), "width": 3.0, "particles": 8},
	"special":  {"type": "slash", "color": Color(1, 0.9, 0.4, 0.95), "width": 4.0, "particles": 7},
	"mage_unit":{"type": "magic", "color": Color(0.6, 0.3, 1.0, 0.9), "width": 4.0, "particles": 10},
}

# ── Battle background mapping (terrain -> pixel art bg) ──
const BATTLE_BG_PATHS := {
	0: "res://assets/ui/battle_bg_ruins.png",    # PLAINS -> ruins (default)
	1: "res://assets/ui/battle_bg_forest.png",   # FOREST
	2: "res://assets/ui/battle_bg_volcano.png",  # MOUNTAIN -> volcano
	3: "res://assets/ui/battle_bg_forest.png",   # SWAMP -> forest variant
	4: "res://assets/ui/battle_bg_harbor.png",   # COASTAL -> harbor
	5: "res://assets/ui/battle_bg_ruins.png",    # FORTRESS_WALL -> ruins
	6: "res://assets/ui/battle_bg_harbor.png",   # RIVER -> harbor variant
	7: "res://assets/ui/battle_bg_temple.png",   # RUINS -> temple
	8: "res://assets/ui/battle_bg_desert.png",   # WASTELAND -> desert
	9: "res://assets/ui/battle_bg_volcano.png",  # VOLCANIC -> volcano
}
var _bg_texture_rect: TextureRect = null

# ── State ──
var _battle_state: Dictionary = {}
var _action_log: Array = []
var _log_index: int = 0
var _playing: bool = false
var _auto_play: bool = true
var _speed_mult: float = 1.0
var _current_round: int = 0
var _captured_heroes: Array = []
var _combo_count: int = 0
var _combo_side: String = ""
var _combo_timer: float = 0.0
var _last_attack_time: float = 0.0
var _total_atk_damage: int = 0
var _total_def_damage: int = 0
var _kills_atk: int = 0
var _kills_def: int = 0
var _is_finishing: bool = false
var _playback_generation: int = 0
var _is_player_battle: bool = false
var _waiting_for_command: bool = false

# ── Buff/debuff tracking (side -> slot -> Array[String]) ──
var _active_buffs: Dictionary = {}
var _dot_timers: Dictionary = {}  # side -> slot -> float (accumulator for DoT particles)

# ── Unit tracking (side -> slot -> dict with live data) ──
var _live_units: Dictionary = {"attacker": {}, "defender": {}}

# ── Chibi video player refs (side -> slot -> VideoStreamPlayer) ──
var _chibi_players: Dictionary = {"attacker": {}, "defender": {}}
# ── Chibi hero mapping (side -> slot -> hero_id string) ──
var _chibi_hero_map: Dictionary = {"attacker": {}, "defender": {}}
# ── Chibi current state tracking (side -> slot -> state string) ──
var _chibi_current_state: Dictionary = {"attacker": {}, "defender": {}}
const CHIBI_SIZE := Vector2(48, 48)

# ── UI refs ──
var root: Control
var shake_container: Control  # wraps everything for screen shake
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
var result_stats: Label
var anim_layer: Control
var combo_label: Label
var damage_tracker_atk: Label
var damage_tracker_def: Label
var round_splash: Label
var passive_banner: PanelContainer
var passive_banner_label: Label
var vignette: ColorRect
var screen_flash: ColorRect
var side_label_atk: Label
var side_label_def: Label
var vs_label: Label
var _vs_tween: Tween = null

# Card panels indexed: attacker_cards[slot] and defender_cards[slot]
var attacker_cards: Dictionary = {}
var defender_cards: Dictionary = {}

# Shake state
var _shake_intensity: float = 0.0
var _shake_decay: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _intervention_panel = null  # CombatInterventionPanel instance
var _cmd_bar: HBoxContainer = null  # Interactive command bar
var _cmd_continue_btn: Button = null
var _cmd_auto_btn: Button = null
var _cmd_retreat_btn: Button = null
func _ready() -> void:
	layer = 20
	visible = false
	_build_ui()
	EventBus.combat_started.connect(_on_combat_started)
	_setup_intervention_panel()
	set_process(true)
func _process(delta: float) -> void:
	if not visible:
		return
	# Screen shake decay
	if _shake_intensity > 0.1:
		_shake_intensity = lerp(_shake_intensity, 0.0, _shake_decay * delta)
		_shake_offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		if shake_container:
			shake_container.position = _shake_offset
	elif shake_container and shake_container.position != Vector2.ZERO:
		shake_container.position = Vector2.ZERO
		_shake_intensity = 0.0

	# Combo timer decay
	if _combo_count > 0:
		_combo_timer -= delta
		if _combo_timer <= 0:
			_combo_count = 0
			if combo_label:
				combo_label.visible = false

	# DoT persistent particles (poison/burn)
	for side_key in _active_buffs.keys():
		if not _active_buffs[side_key] is Dictionary:
			continue
		for slot_key in _active_buffs[side_key].keys():
			var buffs: Array = _active_buffs[side_key][slot_key]
			var has_dot := buffs.has("poison") or buffs.has("burn")
			if not has_dot:
				continue
			if not _dot_timers.has(side_key):
				_dot_timers[side_key] = {}
			if not _dot_timers[side_key].has(slot_key):
				_dot_timers[side_key][slot_key] = 0.0
			_dot_timers[side_key][slot_key] += delta
			if _dot_timers[side_key][slot_key] >= 0.8 / _speed_mult:
				_dot_timers[side_key][slot_key] = 0.0
				var pos := _get_card_center(side_key, slot_key)
				var density := _particle_density_mult()
				if buffs.has("poison"):
					for i in range(max(1, int(2 * density))):
						_spawn_dot_particle(pos, Color(0.2, 0.85, 0.3, 0.7))
				if buffs.has("burn"):
					for i in range(max(1, int(2 * density))):
						_spawn_dot_particle(pos, Color(1.0, 0.3, 0.15, 0.7))
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

	# Vignette / darkened edge overlay (atmosphere)
	bg = ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = ColorTheme.BG_COMBAT
	root.add_child(bg)

	# Pixel art battle background (loaded dynamically per terrain)
	_bg_texture_rect = TextureRect.new()
	_bg_texture_rect.name = "BattleBg"
	_bg_texture_rect.anchor_right = 1.0
	_bg_texture_rect.anchor_bottom = 1.0
	_bg_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_texture_rect.modulate = Color(1, 1, 1, 0.35)  # dim so UI stays readable
	_bg_texture_rect.visible = false
	root.add_child(_bg_texture_rect)

	# Shake container wraps all gameplay UI
	shake_container = Control.new()
	shake_container.name = "ShakeContainer"
	shake_container.anchor_right = 1.0
	shake_container.anchor_bottom = 1.0
	shake_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shake_container)

	# Title
	title_label = _make_label("COMBAT", 30, ColorTheme.TEXT_TITLE, Vector2(0, 8), Vector2(SCREEN_W, 38))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shake_container.add_child(title_label)

	# Terrain + round info
	terrain_label = _make_label("Terrain: Plains", 13, Color(0.6, 0.6, 0.5), Vector2(40, 50), Vector2(300, 20))
	shake_container.add_child(terrain_label)
	round_label = _make_label("Round 0/%d" % MAX_ROUNDS, 13, Color(0.85, 0.75, 0.55), Vector2(SCREEN_W - 200, 50), Vector2(160, 20))
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shake_container.add_child(round_label)

	# Decorative line under title
	var title_line := ColorRect.new()
	title_line.position = Vector2(CENTER_X - 300, 44)
	title_line.size = Vector2(600, 1)
	title_line.color = Color(0.7, 0.55, 0.3, 0.4)
	shake_container.add_child(title_line)

	# Turn order bar
	_build_turn_bar()

	# Side labels with faction power tracking
	side_label_atk = _make_label("[ATTACKER]", 18, ColorTheme.SIDE_ATTACKER, Vector2(60, GRID_TOP - 32), Vector2(260, 28))
	shake_container.add_child(side_label_atk)
	side_label_def = _make_label("[DEFENDER]", 18, ColorTheme.SIDE_DEFENDER, Vector2(SCREEN_W - 320, GRID_TOP - 32), Vector2(260, 28))
	side_label_def.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shake_container.add_child(side_label_def)

	# Damage trackers under side labels
	damage_tracker_atk = _make_label("Total DMG: 0", 11, Color(0.7, 0.55, 0.4), Vector2(60, GRID_TOP - 14), Vector2(200, 16))
	shake_container.add_child(damage_tracker_atk)
	damage_tracker_def = _make_label("Total DMG: 0", 11, Color(0.4, 0.55, 0.7), Vector2(SCREEN_W - 260, GRID_TOP - 14), Vector2(200, 16))
	damage_tracker_def.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shake_container.add_child(damage_tracker_def)

	# VS divider
	var vs_lbl := _make_label("V S", 36, Color(1, 0.35, 0.25, 0.9), Vector2(CENTER_X - 36, GRID_TOP + 130), Vector2(72, 44))
	vs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shake_container.add_child(vs_lbl)
	vs_label = vs_lbl

	# Divider line with glow effect
	var divider := ColorRect.new()
	divider.position = Vector2(CENTER_X - 1, GRID_TOP - 10)
	divider.size = Vector2(2, 410)
	divider.color = Color(0.5, 0.4, 0.3, 0.5)
	shake_container.add_child(divider)
	# Glow behind divider
	var div_glow := ColorRect.new()
	div_glow.position = Vector2(CENTER_X - 8, GRID_TOP - 10)
	div_glow.size = Vector2(16, 410)
	div_glow.color = Color(0.5, 0.35, 0.2, 0.08)
	shake_container.add_child(div_glow)

	# Card grid
	_build_card_grid()

	# Battle clock
	_build_clock_bar()

	# Log panel
	_build_log_panel()

	# Control buttons
	_build_buttons()

	# Interactive command bar (shown at round start for human player battles)
	_build_command_bar()

	# Result overlay
	_build_result_panel()

	# Overlay effects layer
	_build_overlay_effects()
func _build_turn_bar() -> void:
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(CENTER_X - 240, TURN_BAR_Y - 5)
	bar_bg.size = Vector2(480, TURN_ICON_SIZE + 10)
	bar_bg.color = ColorTheme.BG_PRIMARY
	shake_container.add_child(bar_bg)
	# Border accent
	var bar_border := ColorRect.new()
	bar_border.position = Vector2(CENTER_X - 240, TURN_BAR_Y - 5)
	bar_border.size = Vector2(480, 1)
	bar_border.color = Color(0.7, 0.55, 0.3, 0.4)
	shake_container.add_child(bar_border)
	var bar_border_b := ColorRect.new()
	bar_border_b.position = Vector2(CENTER_X - 240, TURN_BAR_Y + TURN_ICON_SIZE + 4)
	bar_border_b.size = Vector2(480, 1)
	bar_border_b.color = Color(0.7, 0.55, 0.3, 0.4)
	shake_container.add_child(bar_border_b)

	turn_bar_container = HBoxContainer.new()
	turn_bar_container.position = Vector2(CENTER_X - 228, TURN_BAR_Y)
	turn_bar_container.add_theme_constant_override("separation", 4)
	shake_container.add_child(turn_bar_container)
func _build_card_grid() -> void:
	var atk_front_x := CENTER_X - CARD_GAP - CARD_W
	var atk_back_x := atk_front_x - CARD_GAP - CARD_W
	var def_front_x := CENTER_X + CARD_GAP
	var def_back_x := def_front_x + CARD_W + CARD_GAP

	for i in range(3):
		var y := GRID_TOP + float(i) * (CARD_H + CARD_GAP)
		var card_a := _create_card(Vector2(atk_front_x, y))
		shake_container.add_child(card_a)
		attacker_cards[i] = card_a
		var card_d := _create_card(Vector2(def_front_x, y))
		shake_container.add_child(card_d)
		defender_cards[i] = card_d

	for i in range(2):
		var y := GRID_TOP + float(i) * (CARD_H + CARD_GAP) + (CARD_H + CARD_GAP) * 0.5
		var card_a := _create_card(Vector2(atk_back_x, y))
		shake_container.add_child(card_a)
		attacker_cards[3 + i] = card_a
		var card_d := _create_card(Vector2(def_back_x, y))
		shake_container.add_child(card_d)
		defender_cards[3 + i] = card_d
func _create_card(pos: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	panel.size = Vector2(CARD_W, CARD_H)
	var style := _make_card_style(Color(0.10, 0.10, 0.14, 0.85), Color(0.22, 0.22, 0.28))
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 1)
	margin.add_child(vbox)

	# Row 1: class tab + commander id + buff indicators
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	vbox.add_child(top_row)

	var class_tab := ColorRect.new()
	class_tab.name = "ClassTab"
	class_tab.custom_minimum_size = Vector2(6, 15)
	class_tab.color = Color(0.35, 0.35, 0.35)
	top_row.add_child(class_tab)

	var cmd_lbl := Label.new()
	cmd_lbl.name = "CmdLabel"
	cmd_lbl.text = ""
	cmd_lbl.add_theme_font_size_override("font_size", 10)
	cmd_lbl.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	top_row.add_child(cmd_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var buff_lbl := Label.new()
	buff_lbl.name = "BuffLabel"
	buff_lbl.text = ""
	buff_lbl.add_theme_font_size_override("font_size", 10)
	top_row.add_child(buff_lbl)

	# Row 2: Troop name
	var name_lbl := Label.new()
	name_lbl.name = "TroopName"
	name_lbl.text = "Empty"
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.78))
	vbox.add_child(name_lbl)

	# Row 3: soldier count
	var count_lbl := Label.new()
	count_lbl.name = "SoldierCount"
	count_lbl.text = ""
	count_lbl.add_theme_font_size_override("font_size", 10)
	count_lbl.add_theme_color_override("font_color", Color(0.8, 0.75, 0.6))
	vbox.add_child(count_lbl)

	# Row 4: HP bar (enhanced with bg glow)
	var bar_container := Control.new()
	bar_container.name = "BarContainer"
	bar_container.custom_minimum_size = Vector2(BAR_W, HP_BAR_H + 2)
	vbox.add_child(bar_container)

	var bar_bg := ColorRect.new()
	bar_bg.name = "BarBG"
	bar_bg.position = Vector2(0, 1)
	bar_bg.size = Vector2(BAR_W, HP_BAR_H)
	bar_bg.color = Color(0.12, 0.12, 0.16)
	bar_container.add_child(bar_bg)

	# Ghost bar (shows previous HP, drains slowly → "damage flash" effect)
	var bar_ghost := ColorRect.new()
	bar_ghost.name = "BarGhost"
	bar_ghost.position = Vector2(0, 1)
	bar_ghost.size = Vector2(BAR_W, HP_BAR_H)
	bar_ghost.color = Color(0.9, 0.3, 0.2, 0.6)
	bar_container.add_child(bar_ghost)

	var bar_fill := ColorRect.new()
	bar_fill.name = "BarFill"
	bar_fill.position = Vector2(0, 1)
	bar_fill.size = Vector2(BAR_W, HP_BAR_H)
	bar_fill.color = Color(0.3, 0.75, 0.3)
	bar_container.add_child(bar_fill)

	# Row 5: stats line
	var stats_lbl := Label.new()
	stats_lbl.name = "Stats"
	stats_lbl.text = ""
	stats_lbl.add_theme_font_size_override("font_size", 9)
	stats_lbl.add_theme_color_override("font_color", Color(0.52, 0.56, 0.62))
	vbox.add_child(stats_lbl)

	# Row 6: passive + morale
	var bot_row := HBoxContainer.new()
	bot_row.add_theme_constant_override("separation", 4)
	vbox.add_child(bot_row)

	var passive_lbl := Label.new()
	passive_lbl.name = "PassiveLabel"
	passive_lbl.text = ""
	passive_lbl.add_theme_font_size_override("font_size", 9)
	passive_lbl.add_theme_color_override("font_color", Color(0.45, 0.5, 0.55))
	bot_row.add_child(passive_lbl)

	var morale_spacer := Control.new()
	morale_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot_row.add_child(morale_spacer)

	var morale_lbl := Label.new()
	morale_lbl.name = "MoraleLabel"
	morale_lbl.text = "士气: 100"
	morale_lbl.add_theme_font_size_override("font_size", 9)
	morale_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	bot_row.add_child(morale_lbl)

	# Row 7: Archetype badge (counter matrix base type)
	var archetype_lbl := Label.new()
	archetype_lbl.name = "ArchetypeLabel"
	archetype_lbl.text = ""
	archetype_lbl.add_theme_font_size_override("font_size", 9)
	archetype_lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.5))
	archetype_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(archetype_lbl)

	# Death/capture overlay (hidden by default)
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

	# Chibi video player overlay (top-right corner of card)
	var chibi_container := Control.new()
	chibi_container.name = "ChibiContainer"
	chibi_container.position = Vector2(CARD_W - CHIBI_SIZE.x - 2, 2)
	chibi_container.size = CHIBI_SIZE
	chibi_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chibi_container.visible = false
	panel.add_child(chibi_container)

	var chibi_video := VideoStreamPlayer.new()
	chibi_video.name = "ChibiVideo"
	chibi_video.size = CHIBI_SIZE
	chibi_video.expand = true
	chibi_video.loop = true
	chibi_video.autoplay = false
	chibi_video.volume_db = -80.0  # silent
	chibi_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chibi_container.add_child(chibi_video)

	# Fallback static TextureRect (for heroes without video)
	var chibi_tex := TextureRect.new()
	chibi_tex.name = "ChibiFallback"
	chibi_tex.custom_minimum_size = CHIBI_SIZE
	chibi_tex.size = CHIBI_SIZE
	chibi_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chibi_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chibi_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chibi_tex.visible = false
	chibi_container.add_child(chibi_tex)

	# Tooltip shows counter summary on hover
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.tooltip_text = ""

	return panel
func _build_clock_bar() -> void:
	clock_container = Control.new()
	clock_container.position = Vector2(CENTER_X - 200, CLOCK_Y)
	clock_container.size = Vector2(400, 22)
	shake_container.add_child(clock_container)

	var clk_lbl := _make_label("Battle Progress", 10, Color(0.55, 0.55, 0.5), Vector2(0, -15), Vector2(400, 14))
	clk_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_container.add_child(clk_lbl)

	var seg_w := 400.0 / MAX_ROUNDS
	for i in range(MAX_ROUNDS):
		var seg := ColorRect.new()
		seg.name = "Seg%d" % i
		seg.position = Vector2(float(i) * seg_w + 1, 0)
		seg.size = Vector2(seg_w - 2, 14)
		seg.color = Color(0.12, 0.12, 0.16)
		clock_container.add_child(seg)
func _build_log_panel() -> void:
	var log_panel := PanelContainer.new()
	log_panel.position = Vector2(30, LOG_TOP)
	log_panel.size = Vector2(880, 130)
	var ls := _make_card_style(Color(0.05, 0.05, 0.09, 0.94), Color(0.22, 0.22, 0.28))
	log_panel.add_theme_stylebox_override("panel", ls)
	shake_container.add_child(log_panel)

	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size", 12)
	log_panel.add_child(log_text)
func _build_buttons() -> void:
	var container := VBoxContainer.new()
	container.position = Vector2(940, LOG_TOP)
	container.add_theme_constant_override("separation", 6)
	shake_container.add_child(container)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 6)
	container.add_child(row1)

	btn_play = _make_btn("▶ Play", _on_play)
	row1.add_child(btn_play)
	btn_step = _make_btn("-> Step", _on_step)
	row1.add_child(btn_step)
	btn_skip = _make_btn("⏭ Skip", _on_skip)
	row1.add_child(btn_skip)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 6)
	container.add_child(row2)

	btn_speed = _make_btn("1x", _on_speed_toggle)
	btn_speed.custom_minimum_size = Vector2(50, 0)
	row2.add_child(btn_speed)

	btn_auto = _make_btn("Auto", _on_auto_toggle)
	btn_auto.custom_minimum_size = Vector2(50, 0)
	row2.add_child(btn_auto)

	btn_close = _make_btn("Close", _on_close)
	btn_close.visible = false
	row2.add_child(btn_close)

func _build_command_bar() -> void:
	_cmd_bar = HBoxContainer.new()
	_cmd_bar.name = "CommandBar"
	_cmd_bar.position = Vector2(CENTER_X - 240, SCREEN_H - 60)
	_cmd_bar.add_theme_constant_override("separation", 12)
	_cmd_bar.visible = false
	_cmd_bar.z_index = 80
	shake_container.add_child(_cmd_bar)

	# Background panel behind the command bar
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(CENTER_X - 260, SCREEN_H - 68)
	bar_bg.size = Vector2(520, 52)
	bar_bg.color = ColorTheme.PHASE_BG
	bar_bg.z_index = 79
	bar_bg.name = "CommandBarBg"
	bar_bg.visible = false
	shake_container.add_child(bar_bg)

	_cmd_continue_btn = _make_btn("Continue >>", _on_cmd_continue)
	_cmd_continue_btn.custom_minimum_size = Vector2(140, 36)
	_cmd_continue_btn.add_theme_color_override("font_color", Color(0.85, 0.9, 0.7))
	_cmd_bar.add_child(_cmd_continue_btn)

	_cmd_auto_btn = _make_btn("Auto (all)", _on_cmd_auto)
	_cmd_auto_btn.custom_minimum_size = Vector2(120, 36)
	_cmd_auto_btn.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	_cmd_bar.add_child(_cmd_auto_btn)

	_cmd_retreat_btn = _make_btn("Retreat", _on_cmd_retreat)
	_cmd_retreat_btn.custom_minimum_size = Vector2(100, 36)
	_cmd_retreat_btn.add_theme_color_override("font_color", Color(0.95, 0.6, 0.5))
	_cmd_bar.add_child(_cmd_retreat_btn)

func _show_command_bar() -> void:
	_waiting_for_command = true
	_cmd_bar.visible = true
	# Also show the background
	var bar_bg = shake_container.get_node_or_null("CommandBarBg")
	if bar_bg:
		bar_bg.visible = true

func _hide_command_bar() -> void:
	_waiting_for_command = false
	_cmd_bar.visible = false
	var bar_bg = shake_container.get_node_or_null("CommandBarBg")
	if bar_bg:
		bar_bg.visible = false

func _on_cmd_continue() -> void:
	## Advance one round then pause again at next round_start
	_hide_command_bar()
	_playing = true
	_playback_generation += 1
	btn_play.text = "|| Pause"
	_play_next()

func _on_cmd_auto() -> void:
	## Resume full auto-play for all remaining rounds
	_hide_command_bar()
	_is_player_battle = false  # disable further pauses
	_auto_play = true
	btn_auto.text = "Auto"
	_playing = true
	_playback_generation += 1
	btn_play.text = "|| Pause"
	_play_next()

func _on_cmd_retreat() -> void:
	## Skip to end — the result is already determined by the resolver, so just skip playback
	_hide_command_bar()
	_on_skip()

func _build_result_panel() -> void:
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(340, 270)
	result_panel.size = Vector2(600, 140)
	result_panel.visible = false
	var rs := _make_card_style(ColorTheme.BG_RESULT, ColorTheme.ACCENT_GOLD)
	rs.border_width_top = 3; rs.border_width_bottom = 3
	rs.border_width_left = 3; rs.border_width_right = 3
	result_panel.add_theme_stylebox_override("panel", rs)
	shake_container.add_child(result_panel)

	var rvbox := VBoxContainer.new()
	rvbox.add_theme_constant_override("separation", 8)
	result_panel.add_child(rvbox)

	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 32)
	rvbox.add_child(result_label)

	result_stats = Label.new()
	result_stats.name = "ResultStats"
	result_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_stats.add_theme_font_size_override("font_size", 13)
	result_stats.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	rvbox.add_child(result_stats)
func _build_overlay_effects() -> void:
	# Animation layer
	anim_layer = Control.new()
	anim_layer.name = "AnimLayer"
	anim_layer.anchor_right = 1.0
	anim_layer.anchor_bottom = 1.0
	anim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(anim_layer)

	# Combo counter (top center)
	combo_label = _make_label("", 40, Color(1, 0.85, 0.2), Vector2(CENTER_X - 100, 62), Vector2(200, 48))
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.visible = false
	combo_label.z_index = 50
	root.add_child(combo_label)

	# Round splash (big centered text)
	round_splash = _make_label("", 64, Color(1, 0.92, 0.7, 0.9), Vector2(0, SCREEN_H * 0.35), Vector2(SCREEN_W, 80))
	round_splash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_splash.visible = false
	round_splash.z_index = 60
	root.add_child(round_splash)

	# Passive skill banner
	passive_banner = PanelContainer.new()
	passive_banner.position = Vector2(CENTER_X - 200, GRID_TOP + 170)
	passive_banner.size = Vector2(400, 36)
	passive_banner.visible = false
	passive_banner.z_index = 55
	var pbs := _make_card_style(Color(0.08, 0.1, 0.2, 0.92), Color(0.4, 0.5, 0.9))
	pbs.border_width_top = 2; pbs.border_width_bottom = 2
	pbs.border_width_left = 2; pbs.border_width_right = 2
	passive_banner.add_theme_stylebox_override("panel", pbs)
	root.add_child(passive_banner)

	passive_banner_label = Label.new()
	passive_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	passive_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	passive_banner_label.add_theme_font_size_override("font_size", 16)
	passive_banner_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	passive_banner.add_child(passive_banner_label)

	# Screen flash overlay
	screen_flash = ColorRect.new()
	screen_flash.name = "ScreenFlash"
	screen_flash.anchor_right = 1.0
	screen_flash.anchor_bottom = 1.0
	screen_flash.color = Color(1, 1, 1, 0)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_flash.z_index = 70
	root.add_child(screen_flash)

	# Vignette darkening
	vignette = ColorRect.new()
	vignette.name = "Vignette"
	vignette.anchor_right = 1.0
	vignette.anchor_bottom = 1.0
	vignette.color = Color(0, 0, 0, 0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_index = 65
	root.add_child(vignette)
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
	_combo_count = 0
	_combo_side = ""
	_total_atk_damage = 0
	_total_def_damage = 0
	_kills_atk = 0
	_kills_def = 0
	_is_finishing = false
	_is_player_battle = battle_result.get("player_controlled", false)
	_waiting_for_command = false
	if _is_player_battle:
		_auto_play = false
		btn_auto.text = "Manual"
	log_text.clear()
	result_panel.visible = false
	btn_close.visible = false
	btn_play.text = "▶ Play"
	combo_label.visible = false
	passive_banner.visible = false
	damage_tracker_atk.text = "Total DMG: 0"
	damage_tracker_def.text = "Total DMG: 0"

	title_label.text = battle_result.get("title", "COMBAT")
	terrain_label.text = "Terrain: %s" % _get_terrain_name(battle_result.get("terrain", 0))
	round_label.text = "Round 0/%d" % MAX_ROUNDS

	# Load terrain-specific battle background
	var terrain_id = battle_result.get("terrain", 0)
	if typeof(terrain_id) == TYPE_STRING:
		terrain_id = int(terrain_id)
	var bg_path: String = BATTLE_BG_PATHS.get(terrain_id, BATTLE_BG_PATHS[0])
	if ResourceLoader.exists(bg_path):
		_bg_texture_rect.texture = load(bg_path)
		_bg_texture_rect.visible = true
	else:
		_bg_texture_rect.visible = false

	# Initialize live unit data
	_live_units = {"attacker": {}, "defender": {}}
	_active_buffs = {"attacker": {}, "defender": {}}
	_dot_timers = {"attacker": {}, "defender": {}}
	var atk_units: Array = battle_result.get("attacker_units_initial", [])
	var def_units: Array = battle_result.get("defender_units_initial", [])
	_populate_cards(attacker_cards, atk_units, "attacker")
	_populate_cards(defender_cards, def_units, "defender")
	_update_clock(0)
	_update_turn_bar()

	# Intro animation: cards slide in from sides
	_intro_animation()

	# Start VS label pulse animation
	if _vs_tween and _vs_tween.is_valid():
		_vs_tween.kill()
	_vs_tween = create_tween().set_loops()
	_vs_tween.tween_property(vs_label, "modulate:a", 0.5, 1.2).set_trans(Tween.TRANS_SINE)
	_vs_tween.tween_property(vs_label, "modulate:a", 0.9, 1.2).set_trans(Tween.TRANS_SINE)

	# Delay auto-play to let intro finish
	if _auto_play:
		get_tree().create_timer(0.8).timeout.connect(func():
			if visible:
				_on_play()
		)
	elif _is_player_battle:
		# For interactive combat: auto-start playback after intro, it will pause at round_start
		get_tree().create_timer(0.8).timeout.connect(func():
			if visible and not _playing:
				_on_play()
		)

func _populate_cards(cards: Dictionary, units: Array, side: String) -> void:
	for slot_idx in cards.keys():
		var card: PanelContainer = cards[slot_idx]
		var vbox: VBoxContainer = card.get_child(0).get_child(0)
		var class_tab: ColorRect = vbox.get_child(0).get_child(0)
		var cmd_lbl: Label = vbox.get_child(0).get_child(1)
		var buff_lbl: Label = vbox.get_child(0).get_child(3)
		var name_lbl: Label = vbox.get_node("TroopName")
		var count_lbl: Label = vbox.get_node("SoldierCount")
		var bar_container: Control = vbox.get_node("BarContainer")
		var bar_ghost: ColorRect = bar_container.get_node("BarGhost")
		var bar_fill: ColorRect = bar_container.get_node("BarFill")
		var stats_lbl: Label = vbox.get_node("Stats")
		var passive_lbl: Label = vbox.get_child(5).get_child(0)
		var morale_lbl: Label = vbox.get_child(5).get_child(2)
		var overlay: Label = card.get_node("OverlayLabel")
		overlay.visible = false
		card.modulate = Color.WHITE

		var unit: Dictionary = {}
		if slot_idx < units.size() and units[slot_idx] != null:
			unit = units[slot_idx]

		if unit.is_empty():
			name_lbl.text = "Empty"
			cmd_lbl.text = ""
			buff_lbl.text = ""
			count_lbl.text = ""
			stats_lbl.text = ""
			passive_lbl.text = ""
			morale_lbl.text = ""
			bar_fill.size.x = 0
			bar_ghost.size.x = 0
			class_tab.color = Color(0.18, 0.18, 0.18)
			var empty_s := _make_card_style(Color(0.06, 0.06, 0.09, 0.5), Color(0.15, 0.15, 0.18))
			card.add_theme_stylebox_override("panel", empty_s)
			card.tooltip_text = ""
			_live_units[side].erase(slot_idx)
			if _active_buffs.has(side):
				_active_buffs[side][slot_idx] = []
		else:
			_live_units[side][slot_idx] = unit.duplicate()
			if _active_buffs.has(side):
				_active_buffs[side][slot_idx] = []
			var uclass: String = unit.get("class", "ashigaru")
			var cc: Color = CLASS_COLORS.get(uclass, Color(0.3, 0.3, 0.35))
			class_tab.color = cc
			var card_style := _make_card_style(cc.darkened(0.65), cc.darkened(0.25))
			card.add_theme_stylebox_override("panel", card_style)

			cmd_lbl.text = str(unit.get("commander_id", ""))
			buff_lbl.text = ""
			var troop_name := _get_troop_display_name(unit.get("troop_id", ""))
			name_lbl.text = troop_name
			name_lbl.add_theme_color_override("font_color", cc.lightened(0.5))

			var soldiers: int = unit.get("soldiers", 0)
			var max_soldiers: int = unit.get("max_soldiers", soldiers)
			count_lbl.text = "Troops: %d/%d" % [soldiers, max_soldiers]
			var ratio: float = float(soldiers) / max(1, max_soldiers)
			bar_fill.size.x = BAR_W * ratio
			bar_ghost.size.x = BAR_W * ratio
			bar_fill.color = _hp_color(ratio)

			stats_lbl.text = "ATK:%d DEF:%d SPD:%d" % [unit.get("atk", 0), unit.get("def", 0), unit.get("spd", 0)]
			var passive_name: String = unit.get("passive", "")
			passive_lbl.text = passive_name if passive_name != "" else ""

			var unit_morale: int = unit.get("morale", 100)
			var unit_routed: bool = unit.get("is_routed", false)
			if unit_routed:
				morale_lbl.text = "溃逃!"
				morale_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_RED)
			else:
				morale_lbl.text = "士气: %d" % unit_morale
				if unit_morale >= 70:
					morale_lbl.add_theme_color_override("font_color", ColorTheme.HP_HIGH)
				elif unit_morale >= 30:
					morale_lbl.add_theme_color_override("font_color", ColorTheme.HP_MID)
				else:
					morale_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)

			# Archetype badge from counter matrix
			var archetype_lbl: Label = vbox.get_node_or_null("ArchetypeLabel")
			if archetype_lbl:
				var troop_id: String = unit.get("troop_id", "")
				var base_type: String = CounterMatrix.TYPE_MAP.get(troop_id, "")
				if base_type != "":
					var display: String = ARCHETYPE_LABELS.get(base_type, base_type)
					archetype_lbl.text = "[%s]" % display
					archetype_lbl.add_theme_color_override("font_color", CLASS_COLORS.get(uclass, Color(0.6, 0.55, 0.45)).lightened(0.3))
				else:
					archetype_lbl.text = ""

			# Set counter summary tooltip
			var troop_id_tip: String = unit.get("troop_id", "")
			if troop_id_tip != "":
				var summary: Dictionary = CounterMatrix.get_counter_summary(troop_id_tip)
				var tip_lines: Array = []
				var base_disp: String = ARCHETYPE_LABELS.get(summary.get("base_type", ""), summary.get("base_type", ""))
				tip_lines.append("兵种: %s" % base_disp)
				var strong: Array = summary.get("strong_vs", [])
				if not strong.is_empty():
					var names: Array = []
					for s in strong:
						var t_name: String = ARCHETYPE_LABELS.get(s.get("type", ""), s.get("type", ""))
						names.append(("★" if s.get("hard", false) else "") + t_name)
					tip_lines.append("克制: %s" % ", ".join(names))
				var weak: Array = summary.get("weak_vs", [])
				if not weak.is_empty():
					var names: Array = []
					for w in weak:
						var w_name: String = ARCHETYPE_LABELS.get(w.get("type", ""), w.get("type", ""))
						names.append(("★" if w.get("hard", false) else "") + w_name)
					tip_lines.append("弱于: %s" % ", ".join(names))
				card.tooltip_text = "\n".join(tip_lines)
			else:
				card.tooltip_text = ""

		# ── Chibi video/sprite loading ──
		var chibi_container: Control = card.get_node_or_null("ChibiContainer")
		if chibi_container:
			var chibi_video: VideoStreamPlayer = chibi_container.get_node_or_null("ChibiVideo")
			var chibi_tex: TextureRect = chibi_container.get_node_or_null("ChibiFallback")
			if unit.is_empty():
				chibi_container.visible = false
				if chibi_video:
					chibi_video.stop()
				if chibi_tex:
					chibi_tex.texture = null
					chibi_tex.visible = false
				_chibi_players[side].erase(slot_idx)
				_chibi_hero_map[side].erase(slot_idx)
				_chibi_current_state[side].erase(slot_idx)
			else:
				var cmd_id: String = str(unit.get("commander_id", ""))
				if cmd_id != "" and ChibiLoader.has_chibi(cmd_id):
					_chibi_hero_map[side][slot_idx] = cmd_id
					chibi_container.visible = true
					# Prefer video, fallback to PNG
					if ChibiLoader.has_video(cmd_id):
						var stream := ChibiLoader.load_video(cmd_id, "idle")
						if stream and chibi_video:
							chibi_video.stream = stream
							chibi_video.loop = true
							chibi_video.play()
							chibi_video.visible = true
							if chibi_tex:
								chibi_tex.visible = false
							_chibi_players[side][slot_idx] = chibi_video
							_chibi_current_state[side][slot_idx] = "idle"
						else:
							chibi_container.visible = false
					elif ChibiLoader.has_png(cmd_id):
						var idle_tex := ChibiLoader.load_png(cmd_id, "idle")
						if idle_tex and chibi_tex:
							chibi_tex.texture = idle_tex
							chibi_tex.visible = true
							if chibi_video:
								chibi_video.visible = false
							_chibi_players[side][slot_idx] = chibi_tex
							_chibi_current_state[side][slot_idx] = "idle"
						else:
							chibi_container.visible = false
					else:
						chibi_container.visible = false
				else:
					chibi_container.visible = false

func _update_card_soldiers(side: String, slot_idx: int, soldiers: int, max_soldiers: int) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var vbox: VBoxContainer = card.get_child(0).get_child(0)
	var count_lbl: Label = vbox.get_node("SoldierCount")
	var bar_container: Control = vbox.get_node("BarContainer")
	var bar_ghost: ColorRect = bar_container.get_node("BarGhost")
	var bar_fill: ColorRect = bar_container.get_node("BarFill")

	count_lbl.text = "Troops: %d/%d" % [soldiers, max_soldiers]
	var ratio: float = float(soldiers) / max(1, max_soldiers)
	var spd := ANIM_BASE_SPEED / _speed_mult

	# Ghost bar stays at old width, then drains after delay (SR07-style damage flash)
	var old_width: float = bar_fill.size.x
	var new_width: float = BAR_W * ratio

	# Immediately snap the fill bar
	var tw_fill := create_tween()
	tw_fill.tween_property(bar_fill, "size:x", new_width, spd * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	bar_fill.color = _hp_color(ratio)

	# Ghost bar drains after a delay
	if old_width > new_width:
		bar_ghost.size.x = old_width
		var tw_ghost := create_tween()
		tw_ghost.tween_interval(spd * 0.6)
		tw_ghost.tween_property(bar_ghost, "size:x", new_width, spd * 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)

	# Update live tracking
	if _live_units[side].has(slot_idx):
		_live_units[side][slot_idx]["soldiers"] = soldiers

	if soldiers <= 0:
		_play_kill_cutscene(side, slot_idx)

func _update_card_morale(side: String, slot_idx: int, morale: int, is_routed: bool) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var vbox: VBoxContainer = card.get_child(0).get_child(0)
	var morale_lbl: Label = vbox.get_child(5).get_child(2)

	if is_routed:
		morale_lbl.text = "溃逃!"
		morale_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_RED)
	else:
		morale_lbl.text = "士气: %d" % morale
		if morale >= 70:
			morale_lbl.add_theme_color_override("font_color", ColorTheme.HP_HIGH)
		elif morale >= 30:
			morale_lbl.add_theme_color_override("font_color", ColorTheme.HP_MID)
		else:
			morale_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)

func _apply_death_overlay(side: String, slot_idx: int) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var overlay: Label = card.get_node_or_null("OverlayLabel")
	if overlay == null:
		return

	var unit_data: Dictionary = _live_units[side].get(slot_idx, {})
	var cmd_id = unit_data.get("commander_id", "")
	var is_captured := false
	for hero_id in _captured_heroes:
		if str(hero_id) == str(cmd_id):
			is_captured = true
			break

	if is_captured:
		overlay.text = "CAPTURED"
		overlay.add_theme_color_override("font_color", Color(0.3, 0.5, 1.0))
		# Blue chain flash effect for capture
		_spawn_capture_chains(side, slot_idx)
	else:
		overlay.text = "ANNIHILATED"
		overlay.add_theme_color_override("font_color", Color(1.0, 0.25, 0.15))
	overlay.visible = true

	# Desaturate + dim with tween (v4.6: enhanced fade-out for dramatic death)
	var tw := create_tween()
	tw.tween_property(card, "modulate", Color(0.5, 0.15, 0.15, 0.9), 0.1 / _speed_mult).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate", Color(0.3, 0.3, 0.3, 0.5), 0.3 / _speed_mult).set_ease(Tween.EASE_IN)

	# Count kills
	if side == "attacker":
		_kills_def += 1
	else:
		_kills_atk += 1

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
	for ch in turn_bar_container.get_children():
		ch.queue_free()

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
			if icons_added == 0:
				icon.color = cc
			else:
				icon.color = cc.darkened(0.35)
			turn_bar_container.add_child(icon)

			var icon_lbl := Label.new()
			icon_lbl.text = abbr
			icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			icon_lbl.size = Vector2(TURN_ICON_SIZE, TURN_ICON_SIZE)
			icon_lbl.add_theme_font_size_override("font_size", 14)
			if icons_added == 0:
				icon_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
			else:
				icon_lbl.add_theme_color_override("font_color", Color.WHITE)
			icon.add_child(icon_lbl)

			# Gold pulse border for current action
			if icons_added == 0:
				var border := _make_border_rect(TURN_ICON_SIZE, TURN_ICON_SIZE, Color(1, 0.85, 0.3))
				icon.add_child(border)
				# Pulse animation on current icon
				var tw := icon.create_tween().set_loops()
				tw.tween_property(border, "modulate:a", 0.4, 0.5)
				tw.tween_property(border, "modulate:a", 1.0, 0.5)

			# Side dot
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
			var t: float = float(i) / max(1, MAX_ROUNDS - 1)
			var target_color: Color
			if t < 0.4:
				target_color = Color(0.2, 0.7, 0.3)
			elif t < 0.7:
				target_color = Color(0.8, 0.75, 0.2)
			else:
				target_color = Color(0.8, 0.25, 0.2)
			# Animated color transition
			if i == round_num - 1:
				var tw := create_tween()
				tw.tween_property(seg, "color", target_color, 0.3 / _speed_mult)
			else:
				seg.color = target_color
		else:
			seg.color = Color(0.12, 0.12, 0.16)
# ═══════════════════════════════════════════════════════════
#                    ATTACK ANIMATIONS (v3.0)
# ═══════════════════════════════════════════════════════════
func _animate_attack(source_side: String, source_slot: int, target_side: String, target_slot: int, damage: int, max_soldiers: int, is_aoe: bool = false) -> void:
	var from_pos := _get_card_center(source_side, source_slot)
	var to_pos := _get_card_center(target_side, target_slot)
	var unit_data: Dictionary = _live_units[source_side].get(source_slot, {})
	var uclass: String = unit_data.get("class", "ashigaru")
	var proj: Dictionary = PROJ_STYLES.get(uclass, PROJ_STYLES["ashigaru"])

	# SFX hook
	EventBus.sfx_attack.emit(uclass, damage > max_soldiers * 0.4)

	var is_crit := damage > max_soldiers * 0.4
	var is_heavy := damage > max_soldiers * 0.6

	# 1. Glow source card (attacker highlight)
	_glow_card(source_side, source_slot)

	# 2. Card lunge toward target (source card nudges forward)
	_lunge_card(source_side, source_slot, target_side)

	# 3. Draw class-specific projectile
	match proj["type"]:
		"slash":
			_draw_projectile_slash(from_pos, to_pos, proj)
		"arrow":
			_draw_projectile_arrow(from_pos, to_pos, proj)
		"charge":
			_draw_projectile_charge(from_pos, to_pos, proj)
		"cannonball":
			_draw_projectile_cannonball(from_pos, to_pos, proj)
		"magic":
			_draw_projectile_magic(from_pos, to_pos, proj)
		"shuriken":
			_draw_projectile_shuriken(from_pos, to_pos, proj)

	# 4. Impact effects on target (delayed to sync with projectile arrival)
	var impact_delay := 0.18 / _speed_mult
	var vfx_type: String = proj["type"]
	get_tree().create_timer(impact_delay).timeout.connect(func():
		# VFX texture overlay at impact point
		_spawn_attack_vfx(to_pos, vfx_type, is_crit)
		# Flash target card
		var flash_color := Color(1, 0.15, 0.1, 0.6) if is_heavy else Color(1, 0.25, 0.15, 0.45)
		_flash_card(target_side, target_slot, flash_color)
		# Bounce target card (recoil)
		_bounce_card(target_side, target_slot, source_side)
		# Impact particles
		_spawn_impact_particles(to_pos, proj, is_crit)
		# Screen shake
		if is_heavy:
			_screen_shake(SHAKE_HEAVY, 8.0)
		elif is_crit:
			_screen_shake(SHAKE_MEDIUM, 10.0)
		else:
			_screen_shake(SHAKE_LIGHT, 12.0)
	)

	# 5. Damage number (slightly after impact)
	get_tree().create_timer(impact_delay + 0.06 / _speed_mult).timeout.connect(func():
		_spawn_damage_number(to_pos, damage, max_soldiers, is_crit)
	)

	# 5b. Counter relationship floating text
	var target_data: Dictionary = _live_units[target_side].get(target_slot, {})
	var src_troop: String = unit_data.get("troop_id", "")
	var tgt_troop: String = target_data.get("troop_id", "")
	if src_troop != "" and tgt_troop != "":
		var counter_info: Dictionary = CounterMatrix.get_counter(src_troop, tgt_troop)
		var advantage: String = counter_info.get("advantage", "neutral")
		if advantage != "neutral":
			get_tree().create_timer(impact_delay + 0.12 / _speed_mult).timeout.connect(func():
				_spawn_counter_indicator(to_pos, counter_info)
			)

	# 6. Update combo
	_update_combo(source_side, damage)

	# 7. Track total damage
	if source_side == "attacker":
		_total_atk_damage += damage
		damage_tracker_atk.text = "Total DMG: %d" % _total_atk_damage
	else:
		_total_def_damage += damage
		damage_tracker_def.text = "Total DMG: %d" % _total_def_damage
func _lunge_card(side: String, slot_idx: int, target_side: String) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var original_pos := card.position
	var lunge_dir := 1.0 if side == "attacker" else -1.0
	if target_side == side:
		lunge_dir = 0.0  # self-targeting (heal etc)
	var lunge_offset := Vector2(lunge_dir * 8.0, 0)
	var spd := 0.12 / _speed_mult
	var tw := create_tween()
	tw.tween_property(card, "position", original_pos + lunge_offset, spd).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(card, "position", original_pos, spd * 1.5).set_ease(Tween.EASE_IN_OUT)

func _draw_projectile_slash(from_pos: Vector2, to_pos: Vector2, proj: Dictionary) -> void:
	# Fast diagonal slash lines
	var spd := 0.2 / _speed_mult
	var color: Color = proj["color"]
	var width: float = proj["width"]

	# Main attack line
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.add_point(from_pos)
	line.add_point(from_pos)
	anim_layer.add_child(line)

	var tw := create_tween()
	tw.tween_method(func(t: float):
		if is_instance_valid(line):
			line.set_point_position(1, from_pos.lerp(to_pos, t))
	, 0.0, 1.0, spd)
	tw.tween_property(line, "modulate:a", 0.0, spd * 0.4)
	tw.tween_callback(func():
		if is_instance_valid(line): line.queue_free()
	)

	# Cross slash decoration (appears at target)
	get_tree().create_timer(spd * 0.7).timeout.connect(func():
		_draw_slash_cross(to_pos, color, width)
	)
func _draw_slash_cross(pos: Vector2, color: Color, width: float) -> void:
	for angle in [0.7, -0.7]:
		var slash := Line2D.new()
		slash.width = width * 0.8
		slash.default_color = color
		var offset := Vector2(cos(angle), sin(angle)) * 25.0
		slash.add_point(pos - offset)
		slash.add_point(pos + offset)
		anim_layer.add_child(slash)
		var tw := create_tween()
		tw.tween_property(slash, "modulate:a", 0.0, 0.25 / _speed_mult)
		tw.tween_callback(func():
			if is_instance_valid(slash): slash.queue_free()
		)

func _draw_projectile_arrow(from_pos: Vector2, to_pos: Vector2, proj: Dictionary) -> void:
	# Arced projectile (parabola)
	var spd := 0.28 / _speed_mult
	var color: Color = proj["color"]
	var dot := ColorRect.new()
	dot.size = Vector2(6, 3)
	dot.color = color
	dot.position = from_pos
	dot.z_index = 40
	anim_layer.add_child(dot)

	# Trail line
	var trail := Line2D.new()
	trail.width = 1.5
	trail.default_color = Color(color.r, color.g, color.b, 0.5)
	anim_layer.add_child(trail)

	var tw := create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(dot): return
		var p := from_pos.lerp(to_pos, t)
		# Add arc
		p.y -= sin(t * PI) * 50.0
		dot.position = p
		if is_instance_valid(trail):
			trail.add_point(p)
			if trail.get_point_count() > 20:
				trail.remove_point(0)
	, 0.0, 1.0, spd)
	tw.tween_callback(func():
		if is_instance_valid(dot): dot.queue_free()
		if is_instance_valid(trail):
			var tw2 := create_tween()
			tw2.tween_property(trail, "modulate:a", 0.0, 0.15 / _speed_mult)
			tw2.tween_callback(trail.queue_free)
	)

func _draw_projectile_charge(from_pos: Vector2, to_pos: Vector2, proj: Dictionary) -> void:
	# Wide charge effect — thick rushing line with afterimage
	var spd := 0.15 / _speed_mult
	var color: Color = proj["color"]
	var width: float = proj["width"]

	# Afterimage trail (wide semi-transparent)
	var trail := Line2D.new()
	trail.width = width * 3.0
	trail.default_color = Color(color.r, color.g, color.b, 0.25)
	trail.add_point(from_pos)
	trail.add_point(from_pos)
	anim_layer.add_child(trail)

	# Main impact line
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.add_point(from_pos)
	line.add_point(from_pos)
	anim_layer.add_child(line)

	var tw := create_tween()
	tw.tween_method(func(t: float):
		if is_instance_valid(line):
			var p := from_pos.lerp(to_pos, t)
			line.set_point_position(1, p)
		if is_instance_valid(trail):
			trail.set_point_position(1, from_pos.lerp(to_pos, t))
	, 0.0, 1.0, spd)
	tw.tween_property(line, "modulate:a", 0.0, spd * 0.3)
	tw.tween_callback(func():
		if is_instance_valid(line): line.queue_free()
	)
	# Trail fades slower
	var tw2 := create_tween()
	tw2.tween_interval(spd)
	tw2.tween_property(trail, "modulate:a", 0.0, spd * 1.5)
	tw2.tween_callback(func():
		if is_instance_valid(trail): trail.queue_free()
	)

func _draw_projectile_cannonball(from_pos: Vector2, to_pos: Vector2, proj: Dictionary) -> void:
	# Large projectile with screen shake on impact
	var spd := 0.25 / _speed_mult
	var color: Color = proj["color"]

	var ball := ColorRect.new()
	ball.size = Vector2(10, 10)
	ball.color = color
	ball.position = from_pos - Vector2(5, 5)
	ball.z_index = 42
	anim_layer.add_child(ball)

	var tw := create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(ball): return
		var p := from_pos.lerp(to_pos, t)
		p.y -= sin(t * PI) * 30.0
		ball.position = p - Vector2(5, 5)
		# Grow slightly as it travels
		var s := 10.0 + t * 6.0
		ball.size = Vector2(s, s)
	, 0.0, 1.0, spd)
	tw.tween_callback(func():
		if is_instance_valid(ball): ball.queue_free()
		# Explosion flash at impact
		_draw_explosion(to_pos, color, 35.0)
		_screen_shake(SHAKE_MEDIUM, 8.0)
	)
func _draw_explosion(pos: Vector2, color: Color, radius: float) -> void:
	var explosion := ColorRect.new()
	explosion.size = Vector2(radius * 2, radius * 2)
	explosion.position = pos - Vector2(radius, radius)
	explosion.color = Color(color.r, color.g, color.b, 0.7)
	explosion.z_index = 45
	anim_layer.add_child(explosion)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(explosion, "size", Vector2(radius * 3, radius * 3), 0.2 / _speed_mult)
	tw.tween_property(explosion, "position", pos - Vector2(radius * 1.5, radius * 1.5), 0.2 / _speed_mult)
	tw.tween_property(explosion, "color:a", 0.0, 0.3 / _speed_mult)
	tw.chain().tween_callback(func():
		if is_instance_valid(explosion): explosion.queue_free()
	)

func _draw_projectile_magic(from_pos: Vector2, to_pos: Vector2, proj: Dictionary) -> void:
	# Glowing orb with trailing sparkles
	var spd := 0.3 / _speed_mult
	var color: Color = proj["color"]

	var orb := ColorRect.new()
	orb.size = Vector2(12, 12)
	orb.color = color
	orb.position = from_pos - Vector2(6, 6)
	orb.z_index = 42
	anim_layer.add_child(orb)

	# Glow halo
	var halo := ColorRect.new()
	halo.size = Vector2(24, 24)
	halo.color = Color(color.r, color.g, color.b, 0.2)
	halo.position = from_pos - Vector2(12, 12)
	halo.z_index = 41
	anim_layer.add_child(halo)

	var tw := create_tween()
	tw.tween_method(func(t: float):
		if not is_instance_valid(orb): return
		var p := from_pos.lerp(to_pos, t)
		# Slight sine wobble
		p.y += sin(t * PI * 3) * 8.0
		orb.position = p - Vector2(6, 6)
		if is_instance_valid(halo):
			halo.position = p - Vector2(12, 12)
		# Spawn sparkle trail
		if int(t * 20) % 3 == 0:
			_spawn_sparkle(p, color)
	, 0.0, 1.0, spd)
	tw.tween_callback(func():
		if is_instance_valid(orb): orb.queue_free()
		if is_instance_valid(halo): halo.queue_free()
		# Magic burst at target
		_draw_magic_burst(to_pos, color)
	)
func _spawn_sparkle(pos: Vector2, color: Color) -> void:
	var sparkle := ColorRect.new()
	sparkle.size = Vector2(3, 3)
	sparkle.color = Color(color.r, color.g, color.b, 0.7)
	sparkle.position = pos + Vector2(randf_range(-6, 6), randf_range(-6, 6))
	sparkle.z_index = 40
	anim_layer.add_child(sparkle)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sparkle, "position:y", sparkle.position.y - 15, 0.3 / _speed_mult)
	tw.tween_property(sparkle, "modulate:a", 0.0, 0.3 / _speed_mult)
	tw.chain().tween_callback(func():
		if is_instance_valid(sparkle): sparkle.queue_free()
	)
func _draw_magic_burst(pos: Vector2, color: Color) -> void:
	# Ring expanding outward
	for i in range(8):
		var angle := float(i) / 8.0 * TAU
		var particle := ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.color = Color(color.r, color.g, color.b, 0.8)
		particle.position = pos
		particle.z_index = 43
		anim_layer.add_child(particle)
		var target_pos := pos + Vector2(cos(angle), sin(angle)) * 30.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(particle, "position", target_pos, 0.25 / _speed_mult).set_ease(Tween.EASE_OUT)
		tw.tween_property(particle, "modulate:a", 0.0, 0.3 / _speed_mult)
		tw.chain().tween_callback(func():
			if is_instance_valid(particle): particle.queue_free()
		)

func _draw_projectile_shuriken(from_pos: Vector2, to_pos: Vector2, proj: Dictionary) -> void:
	# Fast spinning projectile
	var spd := 0.18 / _speed_mult
	var color: Color = proj["color"]

	var star := ColorRect.new()
	star.size = Vector2(8, 8)
	star.color = color
	star.pivot_offset = Vector2(4, 4)
	star.position = from_pos - Vector2(4, 4)
	star.z_index = 42
	anim_layer.add_child(star)

	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(t: float):
		if not is_instance_valid(star): return
		star.position = from_pos.lerp(to_pos, t) - Vector2(4, 4)
	, 0.0, 1.0, spd)
	tw.tween_property(star, "rotation", TAU * 3, spd)
	tw.chain().tween_callback(func():
		if is_instance_valid(star): star.queue_free()
	)

func _spawn_attack_vfx(pos: Vector2, proj_type: String, is_crit: bool) -> void:
	var tex: Texture2D = VfxLoaderRef.load_attack_vfx(proj_type)
	if tex == null:
		return
	var vfx_size: Vector2 = VfxLoaderRef.get_attack_vfx_size(proj_type)
	if is_crit:
		vfx_size *= 1.35

	var sprite := TextureRect.new()
	sprite.texture = tex
	sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	sprite.custom_minimum_size = vfx_size
	sprite.size = vfx_size
	sprite.position = pos - vfx_size * 0.5
	sprite.pivot_offset = vfx_size * 0.5
	sprite.modulate = Color(1, 1, 1, 0)
	sprite.z_index = 43
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim_layer.add_child(sprite)

	var dur := 0.35 / _speed_mult
	var tw := create_tween().set_parallel(true)
	# Fade in quickly
	tw.tween_property(sprite, "modulate:a", 1.0, dur * 0.2)
	# Scale burst
	sprite.scale = Vector2(0.6, 0.6) if not is_crit else Vector2(0.5, 0.5)
	tw.tween_property(sprite, "scale", Vector2(1.1, 1.1) if is_crit else Vector2.ONE, dur * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Slight rotation jitter for organic feel
	sprite.rotation = randf_range(-0.08, 0.08)
	# Fade out
	tw.chain().tween_property(sprite, "modulate:a", 0.0, dur * 0.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		if is_instance_valid(sprite): sprite.queue_free()
	)

func _spawn_impact_particles(pos: Vector2, proj: Dictionary, is_crit: bool) -> void:
	var count: int = proj.get("particles", 4)
	if is_crit:
		count = int(count * 1.5)
	var color: Color = proj.get("color", Color(1, 0.5, 0.3))
	for i in range(count):
		var particle := ColorRect.new()
		var sz := randf_range(2.0, 5.0) if not is_crit else randf_range(3.0, 7.0)
		particle.size = Vector2(sz, sz)
		particle.color = Color(color.r + randf_range(-0.1, 0.1), color.g, color.b, 0.9)
		particle.position = pos + Vector2(randf_range(-8, 8), randf_range(-8, 8))
		particle.z_index = 44
		anim_layer.add_child(particle)

		var target := pos + Vector2(randf_range(-35, 35), randf_range(-40, 10))
		var dur := randf_range(0.25, 0.5) / _speed_mult
		var tw := create_tween().set_parallel(true)
		tw.tween_property(particle, "position", target, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(particle, "modulate:a", 0.0, dur * 1.2)
		tw.chain().tween_callback(func():
			if is_instance_valid(particle): particle.queue_free()
		)
# ═══════════════════════════════════════════════════════════
#                  SCREEN EFFECTS & JUICE
# ═══════════════════════════════════════════════════════════
func _screen_shake(intensity: float, decay_rate: float) -> void:
	if intensity > _shake_intensity:
		_shake_intensity = intensity
	_shake_decay = decay_rate

func _screen_flash_effect(color: Color, duration: float) -> void:
	if not is_instance_valid(screen_flash):
		return
	screen_flash.color = color
	var tw := create_tween()
	tw.tween_property(screen_flash, "color:a", 0.0, duration / _speed_mult).set_ease(Tween.EASE_OUT)

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
	tw.tween_callback(func():
		if is_instance_valid(flash): flash.queue_free()
	)

func _glow_card(side: String, slot_idx: int) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var glow := _make_border_rect(CARD_W, CARD_H, Color(1, 0.85, 0.3, 0.9))
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(glow)
	# Brief brighten
	var original_mod := card.modulate
	var tw := create_tween()
	tw.tween_property(card, "modulate", Color(1.3, 1.25, 1.1), 0.08 / _speed_mult)
	tw.tween_property(card, "modulate", original_mod, 0.15 / _speed_mult)
	# Glow fade
	var tw2 := create_tween()
	tw2.tween_property(glow, "modulate:a", 0.0, (ANIM_BASE_SPEED + 0.15) / _speed_mult)
	tw2.tween_callback(func():
		if is_instance_valid(glow): glow.queue_free()
	)

func _bounce_card(side: String, slot_idx: int, attacker_side: String) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var original_pos := card.position
	# Recoil direction: away from attacker
	var recoil_dir := -1.0 if attacker_side == "attacker" else 1.0
	if attacker_side == side:
		recoil_dir = 0.0
	var bounce_offset := Vector2(recoil_dir * CARD_BOUNCE_PX, randf_range(-2, 2))
	var spd := 0.08 / _speed_mult
	var tw := create_tween()
	tw.tween_property(card, "position", original_pos + bounce_offset, spd).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(card, "position", original_pos, spd * 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)

func _spawn_damage_number(pos: Vector2, damage: int, max_soldiers: int, is_crit: bool = false) -> void:
	var lbl := Label.new()
	if is_crit:
		lbl.text = "-%d!" % damage
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT)
	elif damage > max_soldiers * 0.3:
		lbl.text = "-%d" % damage
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_color", ColorTheme.FLASH_GAIN)
	else:
		lbl.text = "-%d" % damage
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)

	lbl.position = pos + Vector2(randf_range(-24, -8), -35)
	lbl.z_index = 100
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim_layer.add_child(lbl)

	var spd := 0.9 / _speed_mult
	var rise := -50.0 if is_crit else -35.0
	var tw := create_tween()
	if is_crit:
		# Crit: pop in big then shrink, with longer hang time
		tw.tween_property(lbl, "scale", Vector2(1.4, 1.4), 0.08 / _speed_mult)
		tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.12 / _speed_mult).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.set_parallel(true)
		tw.tween_property(lbl, "position:y", lbl.position.y + rise, spd).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 0.0, spd * 1.1)
	else:
		tw.set_parallel(true)
		tw.tween_property(lbl, "position:y", lbl.position.y + rise, spd).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 0.0, spd)
	tw.chain().tween_callback(func():
		if is_instance_valid(lbl): lbl.queue_free()
	)

func _spawn_counter_indicator(pos: Vector2, counter_info: Dictionary) -> void:
	## Spawn a floating label showing the counter relationship during combat.
	var advantage: String = counter_info.get("advantage", "neutral")
	var atk_mult: float = counter_info.get("atk_mult", 1.0)
	var lbl := Label.new()
	match advantage:
		"hard_counter":
			lbl.text = "克制! x%.1f" % atk_mult
			lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
			lbl.add_theme_font_size_override("font_size", 16)
		"strong":
			lbl.text = "优势 x%.1f" % atk_mult
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
			lbl.add_theme_font_size_override("font_size", 14)
		"weak":
			lbl.text = "被克! x%.1f" % atk_mult
			lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
			lbl.add_theme_font_size_override("font_size", 14)
		_:
			lbl.queue_free()
			return
	lbl.position = pos + Vector2(randf_range(10, 30), -55)
	lbl.z_index = 101
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anim_layer.add_child(lbl)
	var spd := 1.2 / _speed_mult
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 40.0, spd).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, spd)
	tw.chain().tween_callback(func():
		if is_instance_valid(lbl): lbl.queue_free()
	)

func _flash_passive(side: String, slot_idx: int, desc: String = "") -> void:
	var pos := _get_card_center(side, slot_idx)
	# Detect passive type from description keywords
	if "反击" in desc or "counter" in desc.to_lower() or "背刺" in desc or "backstab" in desc.to_lower():
		# Counter/backstab — red-orange flash + slash particles
		_flash_card(side, slot_idx, Color(1.0, 0.4, 0.2, 0.4))
		for i in range(3):
			_spawn_sparkle(pos + Vector2(randf_range(-15, 15), randf_range(-10, 10)), Color(1.0, 0.5, 0.2))
	elif "治" in desc or "heal" in desc.to_lower() or "复活" in desc or "revive" in desc.to_lower() or "回复" in desc or "regen" in desc.to_lower():
		# Healing — green glow
		_flash_card(side, slot_idx, Color(0.2, 0.9, 0.4, 0.35))
		for i in range(5):
			_spawn_sparkle(pos + Vector2(randf_range(-20, 20), randf_range(-15, 15)), Color(0.3, 1.0, 0.5))
	elif "防" in desc or "guard" in desc.to_lower() or "铁壁" in desc or "iron_wall" in desc.to_lower() or "方阵" in desc or "phalanx" in desc.to_lower() or "结界" in desc or "barrier" in desc.to_lower():
		# Defense — blue shield flash
		_flash_card(side, slot_idx, Color(0.2, 0.4, 1.0, 0.4))
		for i in range(4):
			_spawn_sparkle(pos + Vector2(randf_range(-18, 18), randf_range(-12, 12)), Color(0.4, 0.6, 1.0))
	elif "灼烧" in desc or "burn" in desc.to_lower() or "炼狱" in desc or "inferno" in desc.to_lower() or "引爆" in desc or "detonate" in desc.to_lower() or "火焰" in desc or "flame" in desc.to_lower():
		# Fire — orange-red burn
		_flash_card(side, slot_idx, Color(1.0, 0.35, 0.1, 0.4))
		for i in range(5):
			_spawn_sparkle(pos + Vector2(randf_range(-20, 20), randf_range(-15, 15)), Color(1.0, 0.4, 0.15))
	elif "闪避" in desc or "dodge" in desc.to_lower() or "隐身" in desc or "stealth" in desc.to_lower() or "幻影" in desc or "phantom" in desc.to_lower():
		# Evasion — white fade
		_flash_card(side, slot_idx, Color(1.0, 1.0, 1.0, 0.25))
		for i in range(3):
			_spawn_sparkle(pos + Vector2(randf_range(-24, 24), randf_range(-18, 18)), Color(0.9, 0.95, 1.0))
	elif "暴击" in desc or "crit" in desc.to_lower() or "致命" in desc or "lethal" in desc.to_lower() or "穿甲" in desc or "pierce" in desc.to_lower():
		# Crit/pierce — gold burst
		_flash_card(side, slot_idx, Color(1.0, 0.85, 0.2, 0.4))
		for i in range(5):
			_spawn_sparkle(pos + Vector2(randf_range(-20, 20), randf_range(-15, 15)), Color(1.0, 0.9, 0.3))
	elif "法" in desc or "magic" in desc.to_lower() or "奥术" in desc or "arcane" in desc.to_lower() or "魔导" in desc or "sorcery" in desc.to_lower():
		# Magic — purple glow
		_flash_card(side, slot_idx, Color(0.6, 0.3, 1.0, 0.35))
		for i in range(5):
			_spawn_sparkle(pos + Vector2(randf_range(-20, 20), randf_range(-15, 15)), Color(0.7, 0.4, 1.0))
	else:
		# Default — blue
		_flash_card(side, slot_idx, Color(0.3, 0.55, 1.0, 0.35))
		for i in range(4):
			_spawn_sparkle(pos + Vector2(randf_range(-20, 20), randf_range(-15, 15)), Color(0.5, 0.7, 1.0))

func _show_passive_banner(text: String, side: String) -> void:
	if not is_instance_valid(passive_banner):
		return
	passive_banner_label.text = text
	var side_color: Color
	if side == "attacker":
		side_color = Color(1.0, 0.85, 0.5)
		passive_banner_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	else:
		side_color = Color(0.5, 0.7, 1.0)
		passive_banner_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))

	passive_banner.visible = true
	passive_banner.modulate = Color(1, 1, 1, 0)
	passive_banner.scale = Vector2(0.8, 0.8)
	passive_banner.pivot_offset = passive_banner.size * 0.5

	var spd := 0.15 / _speed_mult
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(passive_banner, "modulate:a", 1.0, spd).set_ease(Tween.EASE_OUT)
	tw.tween_property(passive_banner, "scale", Vector2(1.0, 1.0), spd).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_interval(0.8 / _speed_mult)
	tw.chain().tween_property(passive_banner, "modulate:a", 0.0, 0.2 / _speed_mult)
	tw.chain().tween_callback(func():
		passive_banner.visible = false
	)

func _show_round_splash(round_num: int) -> void:
	EventBus.sfx_round_start.emit(round_num)
	if not is_instance_valid(round_splash):
		return
	round_splash.text = "Round %d" % round_num
	round_splash.visible = true
	round_splash.modulate = Color(1, 1, 1, 0)
	round_splash.scale = Vector2(2.0, 2.0)
	round_splash.pivot_offset = Vector2(SCREEN_W * 0.5, 40)

	var spd := 0.2 / _speed_mult
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(round_splash, "modulate:a", 1.0, spd).set_ease(Tween.EASE_OUT)
	tw.tween_property(round_splash, "scale", Vector2(1.0, 1.0), spd * 1.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_interval(0.6 / _speed_mult)
	tw.chain().set_parallel(true)
	tw.chain().tween_property(round_splash, "modulate:a", 0.0, 0.3 / _speed_mult)
	tw.chain().tween_property(round_splash, "position:y", round_splash.position.y - 25, 0.3 / _speed_mult)
	tw.chain().tween_property(round_splash, "scale", Vector2(0.85, 0.85), 0.3 / _speed_mult)
	tw.chain().tween_callback(func():
		round_splash.visible = false
		round_splash.position.y = SCREEN_H * 0.35
	)

	# Vignette pulse (brief screen dim for atmosphere)
	if is_instance_valid(vignette):
		var tw_vig := create_tween()
		tw_vig.tween_property(vignette, "color:a", 0.25, 0.15 / _speed_mult).set_ease(Tween.EASE_OUT)
		tw_vig.tween_property(vignette, "color:a", 0.0, 0.6 / _speed_mult).set_ease(Tween.EASE_IN)

	# Subtle screen flash for round start
	_screen_flash_effect(Color(0.8, 0.7, 0.5, 0.12), 0.4)

	# Horizontal light sweep line
	var sweep := ColorRect.new()
	sweep.size = Vector2(SCREEN_W, 2)
	sweep.position = Vector2(0, SCREEN_H * 0.5)
	sweep.color = Color(1, 0.9, 0.7, 0.4)
	sweep.z_index = 58
	anim_layer.add_child(sweep)
	var sweep_tw := create_tween()
	sweep_tw.tween_property(sweep, "position:y", -10.0, 0.6 / _speed_mult).set_ease(Tween.EASE_IN)
	sweep_tw.tween_callback(func(): if is_instance_valid(sweep): sweep.queue_free())

func _play_kill_cutscene(side: String, slot_idx: int) -> void:
	EventBus.sfx_unit_killed.emit(side)
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		_apply_death_overlay(side, slot_idx)
		return

	# Heavy screen shake
	_screen_shake(SHAKE_HEAVY, 6.0)

	# White screen flash (enhanced - brighter and longer)
	_screen_flash_effect(Color(1, 0.95, 0.9, 0.45), 0.35)

	# Brief slow-motion effect
	Engine.time_scale = KILL_SLOWMO_SCALE
	get_tree().create_timer(0.3 * KILL_SLOWMO_SCALE).timeout.connect(func():
		Engine.time_scale = 1.0
	)

	# Brief vignette darkening
	if is_instance_valid(vignette):
		vignette.color = Color(0, 0, 0, 0.3)
		var tw_v := create_tween()
		tw_v.tween_property(vignette, "color:a", 0.0, 0.6 / _speed_mult)

	# Check if this is the last unit on the dying side for extra drama
	var remaining_alive := 0
	for s_key in _live_units[side].keys():
		if s_key != slot_idx:
			var u: Dictionary = _live_units[side][s_key]
			if u.get("soldiers", 0) > 0:
				remaining_alive += 1
	var is_last_kill := remaining_alive == 0

	# Extra dramatic zoom pulse for last unit killed
	if is_last_kill and is_instance_valid(cards[slot_idx]):
		var card: PanelContainer = cards[slot_idx]
		var orig_scale := card.scale
		card.pivot_offset = card.size * 0.5
		var tw_zoom := create_tween()
		tw_zoom.tween_property(card, "scale", Vector2(1.15, 1.15), 0.1 / _speed_mult).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw_zoom.tween_property(card, "scale", orig_scale, 0.2 / _speed_mult).set_ease(Tween.EASE_IN_OUT)
		# Extra heavy shake for final kill
		_screen_shake(SHAKE_CRIT, 5.0)
		_screen_flash_effect(Color(1, 0.85, 0.7, 0.55), 0.45)

	# Apply death overlay with delay for dramatic effect
	get_tree().create_timer(0.1 / _speed_mult).timeout.connect(func():
		_apply_death_overlay(side, slot_idx)
	)

	# Spawn "ANNIHILATED" / "CAPTURED" text particles flying outward
	var pos := _get_card_center(side, slot_idx)
	for i in range(6):
		var particle := ColorRect.new()
		particle.size = Vector2(randf_range(3, 8), randf_range(3, 8))
		particle.color = Color(1, 0.3, 0.2, 0.8)
		particle.position = pos
		particle.z_index = 50
		anim_layer.add_child(particle)
		var angle := randf() * TAU
		var dist := randf_range(20, 60)
		var target_pos := pos + Vector2(cos(angle), sin(angle)) * dist
		var tw := create_tween().set_parallel(true)
		tw.tween_property(particle, "position", target_pos, 0.4 / _speed_mult).set_ease(Tween.EASE_OUT)
		tw.tween_property(particle, "modulate:a", 0.0, 0.5 / _speed_mult)
		tw.chain().tween_callback(func():
			if is_instance_valid(particle): particle.queue_free()
		)

func _play_hero_knockout(side: String, slot_idx: int, hero_name: String) -> void:
	EventBus.sfx_hero_knockout.emit(hero_name)
	# Extra dramatic effect for hero KO
	_screen_shake(SHAKE_CRIT, 5.0)
	_screen_flash_effect(Color(0.8, 0.2, 0.1, 0.4), 0.5)

	# Red flash on the card
	_flash_card(side, slot_idx, Color(1.0, 0.1, 0.05, 0.7))

	# "KO" overlay text on card
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if cards.has(slot_idx):
		var card: PanelContainer = cards[slot_idx]
		var ko_label := Label.new()
		ko_label.text = "K.O."
		ko_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ko_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ko_label.anchor_right = 1.0
		ko_label.anchor_bottom = 1.0
		ko_label.add_theme_font_size_override("font_size", 42)
		ko_label.add_theme_color_override("font_color", Color(1, 0.15, 0.1))
		ko_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ko_label.z_index = 52
		ko_label.modulate = Color(1, 1, 1, 0)
		ko_label.scale = Vector2(2.0, 2.0)
		ko_label.pivot_offset = Vector2(CARD_W * 0.5, CARD_H * 0.5)
		card.add_child(ko_label)

		var tw_ko := create_tween()
		tw_ko.set_parallel(true)
		tw_ko.tween_property(ko_label, "modulate:a", 1.0, 0.1 / _speed_mult).set_ease(Tween.EASE_OUT)
		tw_ko.tween_property(ko_label, "scale", Vector2(1.0, 1.0), 0.2 / _speed_mult).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw_ko.chain().tween_interval(1.2 / _speed_mult)
		tw_ko.chain().tween_property(ko_label, "modulate:a", 0.0, 0.4 / _speed_mult)
		tw_ko.chain().tween_callback(func():
			if is_instance_valid(ko_label): ko_label.queue_free()
		)

		# Card crack visual effect (diagonal crack lines across card)
		_spawn_card_cracks(card)

	# Show knockout banner
	if is_instance_valid(passive_banner):
		passive_banner_label.text = "Hero KO! — %s" % hero_name
		passive_banner_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
		passive_banner.visible = true
		passive_banner.modulate = Color(1, 1, 1, 0)
		passive_banner.scale = Vector2(0.5, 0.5)
		passive_banner.pivot_offset = passive_banner.size * 0.5
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(passive_banner, "modulate:a", 1.0, 0.15 / _speed_mult)
		tw.tween_property(passive_banner, "scale", Vector2(1.1, 1.1), 0.15 / _speed_mult).set_trans(Tween.TRANS_BACK)
		tw.chain().tween_property(passive_banner, "scale", Vector2(1.0, 1.0), 0.1 / _speed_mult)
		tw.chain().tween_interval(1.0 / _speed_mult)
		tw.chain().tween_property(passive_banner, "modulate:a", 0.0, 0.3 / _speed_mult)
		tw.chain().tween_callback(func():
			passive_banner.visible = false
		)

func _update_combo(side: String, damage: int) -> void:
	if side == _combo_side:
		_combo_count += 1
	else:
		_combo_count = 1
		_combo_side = side
	_combo_timer = COMBO_DECAY_TIME

	if _combo_count >= 2 and is_instance_valid(combo_label):
		var combo_color: Color = Color(1, 0.85, 0.2) if side == "attacker" else Color(0.4, 0.7, 1.0)
		combo_label.text = "%d HIT" % _combo_count if _combo_count < 5 else "%d HIT!" % _combo_count
		combo_label.add_theme_color_override("font_color", combo_color)
		combo_label.visible = true
		# Pop animation
		combo_label.scale = Vector2(1.3, 1.3)
		combo_label.pivot_offset = Vector2(100, 24)
		var tw := create_tween()
		tw.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.15 / _speed_mult).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

		# Extra effects for big combos
		if _combo_count >= 5:
			combo_label.add_theme_font_size_override("font_size", 48)
			_screen_flash_effect(Color(combo_color.r, combo_color.g, combo_color.b, 0.06), 0.2)
		elif _combo_count >= 3:
			combo_label.add_theme_font_size_override("font_size", 44)
		else:
			combo_label.add_theme_font_size_override("font_size", 40)

func _highlight_aoe_targets(target_side: String, slots: Array) -> void:
	for slot_idx in slots:
		_flash_card(target_side, slot_idx, Color(0.9, 0.4, 0.1, 0.35))
		# Ring effect around each target
		var pos := _get_card_center(target_side, slot_idx)
		var ring := ColorRect.new()
		ring.size = Vector2(CARD_W + 10, CARD_H + 10)
		ring.position = pos - ring.size * 0.5
		ring.color = Color(1, 0.6, 0.2, 0.3)
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.z_index = 35
		anim_layer.add_child(ring)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(ring, "size", ring.size + Vector2(20, 20), 0.3 / _speed_mult)
		tw.tween_property(ring, "position", ring.position - Vector2(10, 10), 0.3 / _speed_mult)
		tw.tween_property(ring, "color:a", 0.0, 0.4 / _speed_mult)
		tw.chain().tween_callback(func():
			if is_instance_valid(ring): ring.queue_free()
		)
# ═══════════════════════════════════════════════════════════
#                      LOG PLAYBACK
# ═══════════════════════════════════════════════════════════
func _on_play() -> void:
	if _playing:
		_playing = false
		_playback_generation += 1
		btn_play.text = "▶ Play"
		return
	_playing = true
	_playback_generation += 1
	btn_play.text = "⏸ Pause"
	_play_next()

func _play_next() -> void:
	if not visible or not _playing or _log_index >= _action_log.size():
		_finish_playback()
		return
	var entry: Dictionary = _action_log[_log_index]
	_apply_log_entry(entry)
	_log_index += 1
	_update_turn_bar()

	# Interactive combat: pause at round_start for human player battles
	var action: String = entry.get("action", "")
	if action == "round_start" and _is_player_battle:
		_playing = false
		_playback_generation += 1
		btn_play.text = "▶ Play"
		_show_command_bar()
		return

	# Vary delay based on action type for rhythm
	var base_delay := ANIM_BASE_SPEED + 0.18
	match action:
		"round_start":
			base_delay = 1.0  # longer pause for round splash
		"death":
			base_delay = 0.7  # dramatic pause for kills
		"attack":
			var damage: int = entry.get("damage", 0)
			var max_s: int = entry.get("max_soldiers", 1)
			if damage > max_s * 0.5:
				base_delay = 0.55  # heavier hits get slightly more time
		"passive", "ability":
			base_delay = 0.5
		"intervention":
			base_delay = 0.8
		"ultimate":
			base_delay = 2.0  # full cinematic sequence
		"awakening":
			base_delay = 1.2  # awakening burst animation

	var delay := base_delay / _speed_mult
	var gen := _playback_generation
	get_tree().create_timer(delay).timeout.connect(func():
		if gen == _playback_generation:
			_play_next()
	)

func _on_step() -> void:
	_playing = false
	_playback_generation += 1
	btn_play.text = "▶ Play"
	if _log_index < _action_log.size():
		_apply_log_entry(_action_log[_log_index])
		_log_index += 1
		_update_turn_bar()
	if _log_index >= _action_log.size():
		_finish_playback()

func _on_skip() -> void:
	Engine.time_scale = 1.0
	_playing = false
	_playback_generation += 1
	_is_finishing = true
	# Apply all remaining entries without animations
	while _log_index < _action_log.size():
		var entry: Dictionary = _action_log[_log_index]
		var action: String = entry.get("action", "")
		var side: String = entry.get("side", "")
		var slot_idx: int = entry.get("slot", -1)
		var remaining: int = entry.get("remaining_soldiers", 0)
		var max_s: int = entry.get("max_soldiers", remaining)
		var round_num: int = entry.get("round", 0)
		var damage: int = entry.get("damage", 0)
		var target_side: String = entry.get("target_side", "")
		var target_slot: int = entry.get("target_slot", -1)

		if round_num > 0:
			_current_round = round_num
			round_label.text = "Round %d/%d" % [round_num, MAX_ROUNDS]
			_update_clock(round_num)

		if action == "attack" and target_slot >= 0:
			_update_card_soldiers_instant(target_side, target_slot, remaining, max_s)
			if side == "attacker":
				_total_atk_damage += damage
			else:
				_total_def_damage += damage
		elif action == "death" and slot_idx >= 0:
			_apply_death_overlay(side, slot_idx)

		_log_index += 1

	damage_tracker_atk.text = "Total DMG: %d" % _total_atk_damage
	damage_tracker_def.text = "Total DMG: %d" % _total_def_damage
	_is_finishing = false
	_finish_playback()
func _update_card_soldiers_instant(side: String, slot_idx: int, soldiers: int, max_soldiers: int) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var vbox: VBoxContainer = card.get_child(0).get_child(0)
	var count_lbl: Label = vbox.get_node("SoldierCount")
	var bar_container: Control = vbox.get_node("BarContainer")
	var bar_ghost: ColorRect = bar_container.get_node("BarGhost")
	var bar_fill: ColorRect = bar_container.get_node("BarFill")

	count_lbl.text = "Troops: %d/%d" % [soldiers, max_soldiers]
	var ratio: float = float(soldiers) / max(1, max_soldiers)
	bar_fill.size.x = BAR_W * ratio
	bar_ghost.size.x = BAR_W * ratio
	bar_fill.color = _hp_color(ratio)

	if _live_units[side].has(slot_idx):
		_live_units[side][slot_idx]["soldiers"] = soldiers
	if soldiers <= 0:
		_apply_death_overlay(side, slot_idx)

func _on_close() -> void:
	Engine.time_scale = 1.0
	_playing = false
	_playback_generation += 1
	_hide_command_bar()
	_is_player_battle = false
	visible = false
	_combo_count = 0
	combo_label.visible = false
	# Clean up anim_layer children (projectiles, particles, explosions)
	if anim_layer:
		for child in anim_layer.get_children():
			child.queue_free()
	if _vs_tween and _vs_tween.is_valid():
		_vs_tween.kill()
		_vs_tween = null
	# Clean up chibi video players and refs
	_chibi_cleanup()
	combat_view_closed.emit()

func _on_speed_toggle() -> void:
	if _speed_mult < 1.5:
		_speed_mult = 2.0
		btn_speed.text = "2x"
	elif _speed_mult < 2.5:
		_speed_mult = 3.0
		btn_speed.text = "3x"
	else:
		_speed_mult = 1.0
		btn_speed.text = "1x"

func _on_auto_toggle() -> void:
	_auto_play = not _auto_play
	btn_auto.text = "Auto" if _auto_play else "Manual"

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
	var is_aoe: bool = entry.get("is_aoe", false)

	# Round transition with splash
	if round_num > 0 and round_num != _current_round:
		_current_round = round_num
		round_label.text = "Round %d/%d" % [round_num, MAX_ROUNDS]
		_update_clock(round_num)

	var log_line: String = ""
	match action:
		"round_start":
			log_line = "[color=#666]═══════ Round %d ═══════[/color]" % round_num
			_show_round_splash(round_num)

		"attack":
			var is_crit := damage > max_s * 0.4
			var dmg_color := "#fa4" if is_crit else "#f88"
			log_line = "[color=#dda]%s[/color] → %s [color=%s](-%d troops)[/color]" % [desc, target_name, dmg_color, damage]
			if target_slot >= 0:
				_update_card_soldiers(target_side, target_slot, remaining, max_s)
				var entry_morale: int = entry.get("target_morale", -1)
				var entry_routed: bool = entry.get("target_is_routed", false)
				if entry_morale >= 0:
					_update_card_morale(target_side, target_slot, entry_morale, entry_routed)
				_animate_attack(side, slot_idx, target_side, target_slot, damage, max_s, is_aoe)
				# Chibi: attacker shows attack pose, target shows hurt pose
				_set_chibi_state(side, slot_idx, "attack", 0.6)
				_set_chibi_state(target_side, target_slot, "hurt", 0.5)

				# AoE: check for additional targets in same log batch
				if is_aoe:
					var aoe_slots := [target_slot]
					# Look ahead for more AoE hits in the same round from same unit
					var look := _log_index + 1
					while look < _action_log.size():
						var next_entry: Dictionary = _action_log[look]
						if next_entry.get("action", "") != "attack" or next_entry.get("slot", -1) != slot_idx or next_entry.get("side", "") != side:
							break
						var ns: int = next_entry.get("target_slot", -1)
						if ns >= 0 and ns != target_slot:
							aoe_slots.append(ns)
						look += 1
					if aoe_slots.size() > 1:
						_highlight_aoe_targets(target_side, aoe_slots)

		"passive":
			log_line = "[color=#8cf][Passive][/color] %s" % desc
			if slot_idx >= 0:
				_flash_passive(side, slot_idx, desc)
				_show_passive_banner(desc, side)
				_detect_and_apply_buff(side, slot_idx, desc)
				if remaining > 0:
					_update_card_soldiers(side, slot_idx, remaining, max_s)

		"ability":
			log_line = "[color=#fc8][Skill][/color] %s" % desc
			if slot_idx >= 0:
				_glow_card(side, slot_idx)
				_show_passive_banner(desc, side)
				# Chibi: caster shows cast pose
				_set_chibi_state(side, slot_idx, "cast", 0.8)
				# Ability-type visual effects
				var ability_type: String = entry.get("ability_type", "")
				if ability_type == "":
					ability_type = _detect_ability_type(desc)
				var ability_target_side: String = entry.get("target_side", side)
				var ability_target_slot: int = entry.get("target_slot", slot_idx)
				_play_ability_vfx(ability_type, ability_target_side, ability_target_slot, side, slot_idx)
				# Apply buff/debuff tracking from abilities too
				if ability_type in ["buff", "debuff"]:
					_detect_and_apply_buff(ability_target_side, ability_target_slot, desc)

		"siege":
			log_line = "[color=#f88][Siege][/color] %s" % desc
			_screen_shake(SHAKE_MEDIUM, 8.0)
			_spawn_siege_debris()

		"intervention":
			log_line = "[color=gold]%s[/color]" % desc
			_screen_shake(SHAKE_LIGHT, 6.0)
			_show_passive_banner(desc, "attacker")

		"ultimate":
			var hero_id: String = entry.get("hero_id", "")
			var skill_name: String = VfxLoaderRef.get_skill_name(hero_id)
			if skill_name == "":
				skill_name = desc
			log_line = "[color=#ff4][Ultimate][/color] %s - %s" % [desc, skill_name]
			if slot_idx >= 0:
				_glow_card(side, slot_idx)
				_set_chibi_state(side, slot_idx, "cast", 1.8)
			if not _is_finishing and hero_id != "":
				play_ultimate_vfx(hero_id)

		"awakening":
			var hero_id: String = entry.get("hero_id", "")
			log_line = "[color=#f8f][Awakening][/color] %s" % desc
			if slot_idx >= 0:
				if not _is_finishing and hero_id != "":
					play_awakening_vfx(hero_id, side, slot_idx)
				else:
					_glow_card(side, slot_idx)

		"death":
			log_line = "[color=#f44][Annihilate][/color] %s" % desc
			if slot_idx >= 0:
				# Chibi: show defeated pose
				_chibi_defeat(side, slot_idx)
				# Kill cutscene handles death overlay
				if not _is_finishing:
					_play_kill_cutscene(side, slot_idx)
				else:
					_apply_death_overlay(side, slot_idx)

			# Check for hero knockout
			var hero_ko: String = entry.get("hero_knocked_out", "")
			if hero_ko != "":
				_play_hero_knockout(side, slot_idx, hero_ko)

		_:
			log_line = desc if desc != "" else str(entry)

	if log_line != "":
		log_text.append_text(log_line + "\n")

func _finish_playback() -> void:
	_playing = false
	_hide_command_bar()
	btn_play.text = "▶ Play"
	btn_close.visible = true

	var winner: String = _battle_state.get("winner", "")
	EventBus.sfx_battle_result.emit(winner)

	# Dramatic result reveal
	result_panel.visible = true
	result_panel.modulate = Color(1, 1, 1, 0)
	result_panel.scale = Vector2(0.7, 0.7)
	result_panel.pivot_offset = result_panel.size * 0.5

	if winner == "attacker":
		result_label.text = "ATTACKER WINS!"
		result_label.add_theme_color_override("font_color", Color(1, 0.88, 0.3))
		_screen_flash_effect(Color(1, 0.9, 0.5, 0.15), 0.5)
		_chibi_victory("attacker")
	elif winner == "defender":
		result_label.text = "DEFENDER WINS!"
		result_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1))
		_screen_flash_effect(Color(0.3, 0.5, 1.0, 0.1), 0.5)
		_chibi_victory("defender")
	else:
		result_label.text = "BATTLE END"
		result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	# Stats summary with kill/survivor counts
	var atk_survivors := 0
	var def_survivors := 0
	var atk_final_arr: Array = _battle_state.get("attacker_units_final", [])
	var def_final_arr: Array = _battle_state.get("defender_units_final", [])
	for u in atk_final_arr:
		if u != null and u.get("soldiers", 0) > 0:
			atk_survivors += 1
	for u in def_final_arr:
		if u != null and u.get("soldiers", 0) > 0:
			def_survivors += 1
	result_stats.text = "ATK Damage: %d  |  DEF Damage: %d  |  Rounds: %d\nKills: ATK %d / DEF %d  |  Alive: ATK %d / DEF %d" % [
		_total_atk_damage, _total_def_damage, _current_round,
		_kills_atk, _kills_def, atk_survivors, def_survivors
	]

	# Animated reveal
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(result_panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_property(result_panel, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	_screen_shake(SHAKE_MEDIUM, 8.0)

	# Apply final unit states
	var atk_final: Array = _battle_state.get("attacker_units_final", [])
	var def_final: Array = _battle_state.get("defender_units_final", [])
	_populate_cards(attacker_cards, atk_final, "attacker")
	_populate_cards(defender_cards, def_final, "defender")

	for slot in attacker_cards.keys():
		if slot < atk_final.size() and atk_final[slot] != null:
			if atk_final[slot].get("soldiers", 0) <= 0:
				_apply_death_overlay("attacker", slot)
	for slot in defender_cards.keys():
		if slot < def_final.size() and def_final[slot] != null:
			if def_final[slot].get("soldiers", 0) <= 0:
				_apply_death_overlay("defender", slot)

# ═══════════════════════════════════════════════════════════
#                   CHIBI VIDEO HELPERS
# ═══════════════════════════════════════════════════════════

## Switch a card's chibi to a new state (video or PNG fallback).
## For play-once states (attack/cast/hurt), auto-reverts to idle after video ends.
## For permanent states (defeated/victory), stays in that state.
func _set_chibi_state(side: String, slot_idx: int, state: String, revert_delay: float = 0.5) -> void:
	var hero_id: String = _chibi_hero_map[side].get(slot_idx, "")
	if hero_id.is_empty():
		return
	if not _chibi_players.has(side) or not _chibi_players[side].has(slot_idx):
		return

	var current_state: String = _chibi_current_state[side].get(slot_idx, "idle")
	# Don't interrupt defeated state
	if current_state == "defeated":
		return

	var player = _chibi_players[side][slot_idx]
	if player == null or not is_instance_valid(player):
		return

	_chibi_current_state[side][slot_idx] = state

	if player is VideoStreamPlayer:
		var stream := ChibiLoader.load_video(hero_id, state)
		if stream:
			player.stream = stream
			player.loop = ChibiLoader.is_loop_state(state)
			player.play()

			# For play-once states, revert to idle when done
			if not player.loop and state != "defeated" and state != "victory":
				# Connect finished signal for revert
				var callable := func():
					if is_instance_valid(player) and _chibi_hero_map[side].get(slot_idx, "") == hero_id:
						if _chibi_current_state[side].get(slot_idx, "") == state:
							_set_chibi_idle(side, slot_idx)
				if not player.finished.is_connected(callable):
					# Disconnect previous one-shot connections
					for conn in player.finished.get_connections():
						player.finished.disconnect(conn["callable"])
					player.finished.connect(callable, CONNECT_ONE_SHOT)
	elif player is TextureRect:
		# PNG fallback: swap texture
		var tex := ChibiLoader.load_png(hero_id, state)
		if tex:
			player.texture = tex
			# Revert to idle after delay for non-permanent states
			if state != "defeated" and state != "victory" and revert_delay > 0.0:
				var tw := create_tween()
				tw.tween_interval(revert_delay / _speed_mult)
				tw.tween_callback(func():
					if is_instance_valid(player) and _chibi_hero_map[side].get(slot_idx, "") == hero_id:
						if _chibi_current_state[side].get(slot_idx, "") == state:
							_set_chibi_idle(side, slot_idx)
				)

## Revert chibi to idle (looping).
func _set_chibi_idle(side: String, slot_idx: int) -> void:
	var hero_id: String = _chibi_hero_map[side].get(slot_idx, "")
	if hero_id.is_empty():
		return
	if not _chibi_players.has(side) or not _chibi_players[side].has(slot_idx):
		return

	var player = _chibi_players[side][slot_idx]
	if player == null or not is_instance_valid(player):
		return

	_chibi_current_state[side][slot_idx] = "idle"

	if player is VideoStreamPlayer:
		var stream := ChibiLoader.load_video(hero_id, "idle")
		if stream:
			# Clear any pending finished connections
			for conn in player.finished.get_connections():
				player.finished.disconnect(conn["callable"])
			player.stream = stream
			player.loop = true
			player.play()
	elif player is TextureRect:
		var tex := ChibiLoader.load_png(hero_id, "idle")
		if tex:
			player.texture = tex

## Show defeat state: switch to defeated animation + fade out.
func _chibi_defeat(side: String, slot_idx: int) -> void:
	_set_chibi_state(side, slot_idx, "defeated", 0.0)
	# Fade out the chibi container
	if _chibi_players.has(side) and _chibi_players[side].has(slot_idx):
		var player = _chibi_players[side][slot_idx]
		if player and is_instance_valid(player):
			var container = player.get_parent()
			if container:
				var tw := create_tween()
				tw.tween_interval(0.3 / _speed_mult)
				tw.tween_property(container, "modulate:a", 0.3, 0.5 / _speed_mult)

## Show victory pose for all surviving units on a side.
func _chibi_victory(side: String) -> void:
	if not _chibi_players.has(side):
		return
	for slot_idx in _chibi_players[side].keys():
		var current: String = _chibi_current_state[side].get(slot_idx, "")
		if current != "defeated":
			_chibi_current_state[side][slot_idx] = ""  # clear to allow override
			_set_chibi_state(side, slot_idx, "victory", 0.0)

## Stop all chibi videos and clean up.
func _chibi_cleanup() -> void:
	for side in ["attacker", "defender"]:
		if _chibi_players.has(side):
			for slot_idx in _chibi_players[side].keys():
				var player = _chibi_players[side][slot_idx]
				if player is VideoStreamPlayer and is_instance_valid(player):
					player.stop()
					for conn in player.finished.get_connections():
						player.finished.disconnect(conn["callable"])
	_chibi_players = {"attacker": {}, "defender": {}}
	_chibi_hero_map = {"attacker": {}, "defender": {}}
	_chibi_current_state = {"attacker": {}, "defender": {}}
	ChibiLoader.clear_cache()

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
	s.corner_radius_top_left = 5; s.corner_radius_top_right = 5
	s.corner_radius_bottom_left = 5; s.corner_radius_bottom_right = 5
	return s

func _make_border_rect(w: float, h: float, color: Color) -> ColorRect:
	var outer := ColorRect.new()
	outer.size = Vector2(w, h)
	outer.position = Vector2.ZERO
	outer.color = Color(color.r, color.g, color.b, color.a * 0.35)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return outer

func _hp_color(ratio: float) -> Color:
	return ColorTheme.hp_color(ratio)

func _get_terrain_name(terrain) -> String:
	var tdata: Dictionary = FactionData.TERRAIN_DATA.get(terrain, {})
	return tdata.get("name", "Plains")

func _get_troop_display_name(troop_id: String) -> String:
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

func _setup_intervention_panel() -> void:
	var InterventionPanel = load("res://scenes/ui/combat_intervention_panel.gd")
	_intervention_panel = InterventionPanel.new()
	get_tree().root.call_deferred("add_child", _intervention_panel)
	EventBus.combat_intervention_phase.connect(_on_intervention_phase)
	_intervention_panel.intervention_decided.connect(_on_intervention_decided)
	_intervention_panel.intervention_skipped.connect(_on_intervention_skipped)

func _on_intervention_phase(state: Dictionary) -> void:
	# Panel shows during combat resolution (before combat_view playback).
	# The combat_view may not be visible yet -- that's fine, the panel is independent.
	_intervention_panel.show_panel(state)

func _on_intervention_decided(intervention_type: int, target: Variant) -> void:
	EventBus.combat_intervention_chosen.emit(intervention_type, target)

func _on_intervention_skipped() -> void:
	# Emit with -1 type to signal skip
	EventBus.combat_intervention_chosen.emit(-1, null)

func _intro_animation() -> void:
	# Cards slide in from the sides with staggered timing
	var delay_step := 0.06
	var slide_dist := 80.0

	# Attacker cards slide from left
	for slot_idx in attacker_cards.keys():
		var card: PanelContainer = attacker_cards[slot_idx]
		var target_pos := card.position
		card.position = target_pos + Vector2(-slide_dist, 0)
		card.modulate = Color(1, 1, 1, 0)
		var delay := float(slot_idx) * delay_step
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "position", target_pos, 0.35).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(delay)

	# Defender cards slide from right
	for slot_idx in defender_cards.keys():
		var card: PanelContainer = defender_cards[slot_idx]
		var target_pos := card.position
		card.position = target_pos + Vector2(slide_dist, 0)
		card.modulate = Color(1, 1, 1, 0)
		var delay := float(slot_idx) * delay_step
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "position", target_pos, 0.35).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(card, "modulate:a", 1.0, 0.25).set_delay(delay)

	# VS text punch-in
	# (VS label is already added; we animate it)
	# Title flash
	_screen_flash_effect(Color(0.9, 0.8, 0.5, 0.1), 0.5)
# ═══════════════════════════════════════════════════════════
#                 UTILITY & MISSING EFFECTS
# ═══════════════════════════════════════════════════════════

func _particle_density_mult() -> float:
	if _speed_mult >= 3.0:
		return 0.4
	elif _speed_mult >= 2.0:
		return 0.7
	return 1.0

func _spawn_dot_particle(pos: Vector2, color: Color) -> void:
	var p := ColorRect.new()
	p.size = Vector2(3, 3)
	p.color = color
	p.position = pos + Vector2(randf_range(-18, 18), randf_range(-12, 12))
	p.z_index = 38
	anim_layer.add_child(p)
	var dur := randf_range(0.5, 0.9) / _speed_mult
	var tw := create_tween().set_parallel(true)
	tw.tween_property(p, "position:y", p.position.y - randf_range(15, 30), dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(func():
		if is_instance_valid(p): p.queue_free()
	)

func _spawn_capture_chains(side: String, slot_idx: int) -> void:
	var center := _get_card_center(side, slot_idx)
	var chain_color := Color(0.3, 0.5, 1.0, 0.6)
	# Draw 4 diagonal chain lines converging on center
	for i in range(4):
		var angle := float(i) / 4.0 * TAU + PI * 0.25
		var line := ColorRect.new()
		line.size = Vector2(40, 2)
		line.color = chain_color
		line.pivot_offset = Vector2(0, 1)
		line.rotation = angle
		line.position = center + Vector2(cos(angle), sin(angle)) * 45.0
		line.z_index = 46
		line.modulate = Color(1, 1, 1, 0)
		anim_layer.add_child(line)
		var tw := create_tween()
		tw.tween_property(line, "modulate:a", 1.0, 0.15 / _speed_mult).set_ease(Tween.EASE_OUT)
		tw.tween_property(line, "position", center + Vector2(cos(angle), sin(angle)) * 10.0, 0.2 / _speed_mult).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.4 / _speed_mult)
		tw.tween_property(line, "modulate:a", 0.0, 0.3 / _speed_mult)
		tw.tween_callback(func():
			if is_instance_valid(line): line.queue_free()
		)
	# Blue flash on card
	_flash_card(side, slot_idx, Color(0.3, 0.5, 1.0, 0.3))

func _spawn_siege_debris() -> void:
	var density := _particle_density_mult()
	var count: int = maxi(3, int(8 * density))
	for i in range(count):
		var debris := ColorRect.new()
		var sz := randf_range(3.0, 7.0)
		debris.size = Vector2(sz, sz)
		debris.color = Color(
			randf_range(0.35, 0.55),
			randf_range(0.25, 0.4),
			randf_range(0.15, 0.25),
			0.8
		)
		debris.position = Vector2(randf_range(100, SCREEN_W - 100), -10)
		debris.z_index = 39
		anim_layer.add_child(debris)
		var fall_dur := randf_range(0.6, 1.2) / _speed_mult
		var target_y := randf_range(GRID_TOP + 50, GRID_TOP + 280)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(debris, "position:y", target_y, fall_dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(debris, "position:x", debris.position.x + randf_range(-30, 30), fall_dur)
		tw.tween_property(debris, "rotation", randf_range(-PI, PI), fall_dur)
		tw.chain().tween_property(debris, "modulate:a", 0.0, 0.3 / _speed_mult)
		tw.chain().tween_callback(func():
			if is_instance_valid(debris): debris.queue_free()
		)

func _detect_and_apply_buff(side: String, slot_idx: int, desc: String) -> void:
	if not _active_buffs.has(side) or not _active_buffs[side].has(slot_idx):
		return
	var buffs: Array = _active_buffs[side][slot_idx]
	# Detect buff types from description text
	if "灼烧" in desc or "炼狱" in desc or "burn" in desc.to_lower() or "inferno" in desc.to_lower():
		if not buffs.has("burn"):
			buffs.append("burn")
	if "毒" in desc or "poison" in desc.to_lower():
		if not buffs.has("poison"):
			buffs.append("poison")
	if "ATK+" in desc or "攻击" in desc or "atk_up" in desc.to_lower():
		if not buffs.has("atk_up"):
			buffs.append("atk_up")
	if "DEF+" in desc or "防御" in desc or "铁壁" in desc or "def_up" in desc.to_lower() or "iron_wall" in desc.to_lower():
		if not buffs.has("def_up"):
			buffs.append("def_up")
	if "SPD+" in desc or "迅捷" in desc or "spd_up" in desc.to_lower():
		if not buffs.has("spd_up"):
			buffs.append("spd_up")
	if "SPD-" in desc or "减速" in desc or "slow" in desc.to_lower():
		if not buffs.has("slow"):
			buffs.append("slow")
	_update_buff_label(side, slot_idx)

func _update_buff_label(side: String, slot_idx: int) -> void:
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		return
	var card: PanelContainer = cards[slot_idx]
	var vbox: VBoxContainer = card.get_child(0).get_child(0)
	var top_row: HBoxContainer = vbox.get_child(0) as HBoxContainer
	var buff_lbl: Label = top_row.get_node("BuffLabel") if top_row and top_row.has_node("BuffLabel") else null
	if buff_lbl == null:
		return
	if not _active_buffs.has(side) or not _active_buffs[side].has(slot_idx):
		buff_lbl.text = ""
		return
	var buffs: Array = _active_buffs[side][slot_idx]
	if buffs.is_empty():
		buff_lbl.text = ""
		return
	# Map buff keys to short indicators
	var icons: Array[String] = []
	for b in buffs:
		match b:
			"burn": icons.append("BRN")
			"poison": icons.append("PSN")
			"atk_up": icons.append("ATK+")
			"def_up": icons.append("DEF+")
			"spd_up": icons.append("SPD+")
			"slow": icons.append("SPD-")
			_: icons.append("✦")
	buff_lbl.text = " ".join(icons)
	# Make buff indicators more prominent
	buff_lbl.add_theme_font_size_override("font_size", 11)
	# Color the label based on dominant buff type
	if buffs.has("burn"):
		buff_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_WARNING)
	elif buffs.has("poison"):
		buff_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_SUCCESS)
	elif buffs.has("atk_up"):
		buff_lbl.add_theme_color_override("font_color", ColorTheme.ACCENT_GOLD_BRIGHT)
	elif buffs.has("def_up"):
		buff_lbl.add_theme_color_override("font_color", ColorTheme.SIDE_DEFENDER)
	else:
		buff_lbl.add_theme_color_override("font_color", ColorTheme.TEXT_DIM)

	# Spawn visual buff/debuff arrow indicators on the card
	var has_any_buff := false
	var has_any_debuff := false
	for b in buffs:
		if b in ["atk_up", "def_up", "spd_up"]:
			has_any_buff = true
		if b in ["slow"]:
			has_any_debuff = true
	if has_any_buff:
		_spawn_buff_arrow_indicator(card, true)
	if has_any_debuff:
		_spawn_buff_arrow_indicator(card, false)

	# Pulsing overlay for poison
	if buffs.has("poison"):
		_spawn_dot_pulsing_overlay(card, Color(0.2, 0.85, 0.3, 0.12))
	# Pulsing overlay for burn
	if buffs.has("burn"):
		_spawn_dot_pulsing_overlay(card, Color(1.0, 0.45, 0.1, 0.12))

# ═══════════════════════════════════════════════════════════
#            ABILITY VFX & ENHANCED VISUAL EFFECTS
# ═══════════════════════════════════════════════════════════

func _detect_ability_type(desc: String) -> String:
	## Infer ability type from description text when not explicitly provided.
	if "治" in desc or "回复" in desc or "治愈" in desc or "恢复" in desc or "heal" in desc.to_lower() or "regen" in desc.to_lower() or "revive" in desc.to_lower():
		return "heal"
	if "范围" in desc or "全体" in desc or "aoe" in desc.to_lower():
		return "aoe"
	if "攻击" in desc or "伤害" in desc or "斩" in desc or "打击" in desc or "damage" in desc.to_lower() or "strike" in desc.to_lower():
		return "damage"
	if "减速" in desc or "弱化" in desc or "诅咒" in desc or "减" in desc or "毒" in desc or "灼" in desc or "debuff" in desc.to_lower() or "slow" in desc.to_lower() or "poison" in desc.to_lower() or "burn" in desc.to_lower() or "curse" in desc.to_lower():
		return "debuff"
	if "强化" in desc or "鼓舞" in desc or "加速" in desc or "增" in desc or "护盾" in desc or "buff" in desc.to_lower() or "boost" in desc.to_lower() or "shield" in desc.to_lower():
		return "buff"
	return "damage"

func _play_ability_vfx(ability_type: String, target_side: String, target_slot: int, source_side: String, source_slot: int) -> void:
	## Dispatch ability visual effects based on type.
	match ability_type:
		"heal":
			_vfx_heal_sparkles(target_side, target_slot)
		"damage":
			_vfx_ability_impact_ring(target_side, target_slot)
		"aoe":
			_vfx_ability_impact_ring(target_side, target_slot)
			# Also flash adjacent slots for AoE feel
			for offset in [-1, 1]:
				var adj_slot: int = target_slot + offset
				if adj_slot >= 0 and adj_slot < 5:
					_vfx_ability_impact_ring(target_side, adj_slot)
		"buff":
			_vfx_buff_arrows(target_side, target_slot, true)
		"debuff":
			_vfx_buff_arrows(target_side, target_slot, false)

func _vfx_heal_sparkles(side: String, slot_idx: int) -> void:
	## Green sparkle particles rising upward on the healed unit.
	var pos := _get_card_center(side, slot_idx)
	var density := _particle_density_mult()
	var count := maxi(4, int(10 * density))
	for i in range(count):
		var sparkle := ColorRect.new()
		var sz := randf_range(2.0, 5.0)
		sparkle.size = Vector2(sz, sz)
		sparkle.color = Color(
			randf_range(0.2, 0.4),
			randf_range(0.8, 1.0),
			randf_range(0.3, 0.6),
			0.85
		)
		sparkle.position = pos + Vector2(randf_range(-CARD_W * 0.4, CARD_W * 0.4), randf_range(-CARD_H * 0.3, CARD_H * 0.3))
		sparkle.z_index = 45
		anim_layer.add_child(sparkle)
		var rise := randf_range(35, 65)
		var dur := randf_range(0.5, 0.9) / _speed_mult
		var delay := randf_range(0.0, 0.2) / _speed_mult
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sparkle, "position:y", sparkle.position.y - rise, dur).set_delay(delay).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(sparkle, "position:x", sparkle.position.x + randf_range(-10, 10), dur).set_delay(delay)
		tw.tween_property(sparkle, "modulate:a", 0.0, dur * 0.9).set_delay(delay)
		tw.chain().tween_callback(func():
			if is_instance_valid(sparkle): sparkle.queue_free()
		)
	# Green card flash
	_flash_card(side, slot_idx, Color(0.2, 0.9, 0.4, 0.3))

func _vfx_ability_impact_ring(side: String, slot_idx: int) -> void:
	## Large impact ring expanding outward from target for damage/AoE abilities.
	var pos := _get_card_center(side, slot_idx)
	# Inner ring
	var ring_inner := ColorRect.new()
	ring_inner.size = Vector2(10, 10)
	ring_inner.position = pos - Vector2(5, 5)
	ring_inner.color = Color(1.0, 0.6, 0.2, 0.7)
	ring_inner.z_index = 46
	ring_inner.pivot_offset = Vector2(5, 5)
	anim_layer.add_child(ring_inner)
	var tw1 := create_tween().set_parallel(true)
	tw1.tween_property(ring_inner, "size", Vector2(CARD_W * 1.2, CARD_H * 1.2), 0.3 / _speed_mult).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw1.tween_property(ring_inner, "position", pos - Vector2(CARD_W * 0.6, CARD_H * 0.6), 0.3 / _speed_mult).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw1.tween_property(ring_inner, "color:a", 0.0, 0.35 / _speed_mult)
	tw1.chain().tween_callback(func():
		if is_instance_valid(ring_inner): ring_inner.queue_free()
	)
	# Outer ring (delayed)
	var ring_outer := ColorRect.new()
	ring_outer.size = Vector2(6, 6)
	ring_outer.position = pos - Vector2(3, 3)
	ring_outer.color = Color(1.0, 0.85, 0.4, 0.5)
	ring_outer.z_index = 45
	anim_layer.add_child(ring_outer)
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(ring_outer, "size", Vector2(CARD_W * 1.5, CARD_H * 1.5), 0.35 / _speed_mult).set_delay(0.05 / _speed_mult).set_ease(Tween.EASE_OUT)
	tw2.tween_property(ring_outer, "position", pos - Vector2(CARD_W * 0.75, CARD_H * 0.75), 0.35 / _speed_mult).set_delay(0.05 / _speed_mult).set_ease(Tween.EASE_OUT)
	tw2.tween_property(ring_outer, "color:a", 0.0, 0.4 / _speed_mult).set_delay(0.05 / _speed_mult)
	tw2.chain().tween_callback(func():
		if is_instance_valid(ring_outer): ring_outer.queue_free()
	)
	# Impact flash + shake
	_flash_card(side, slot_idx, Color(1.0, 0.5, 0.15, 0.5))
	_screen_shake(SHAKE_LIGHT, 12.0)

func _vfx_buff_arrows(side: String, slot_idx: int, is_buff: bool) -> void:
	## Golden upward arrows for buff, red downward arrows for debuff.
	var pos := _get_card_center(side, slot_idx)
	var density := _particle_density_mult()
	var count := maxi(3, int(6 * density))
	var arrow_color: Color
	var direction: float
	var arrow_text: String
	if is_buff:
		arrow_color = Color(1.0, 0.85, 0.2, 0.9)
		direction = -1.0  # upward
		arrow_text = "^"
	else:
		arrow_color = Color(1.0, 0.2, 0.15, 0.9)
		direction = 1.0   # downward
		arrow_text = "v"

	for i in range(count):
		var arrow := Label.new()
		arrow.text = arrow_text
		arrow.add_theme_font_size_override("font_size", 18)
		arrow.add_theme_color_override("font_color", arrow_color)
		arrow.position = pos + Vector2(randf_range(-CARD_W * 0.35, CARD_W * 0.35), randf_range(-CARD_H * 0.2, CARD_H * 0.2))
		arrow.z_index = 47
		arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anim_layer.add_child(arrow)
		var travel := direction * randf_range(30, 55)
		var dur := randf_range(0.5, 0.8) / _speed_mult
		var delay := float(i) * 0.04 / _speed_mult
		var tw := create_tween().set_parallel(true)
		tw.tween_property(arrow, "position:y", arrow.position.y + travel, dur).set_delay(delay).set_ease(Tween.EASE_OUT)
		tw.tween_property(arrow, "modulate:a", 0.0, dur * 0.85).set_delay(delay)
		tw.chain().tween_callback(func():
			if is_instance_valid(arrow): arrow.queue_free()
		)
	# Card glow in buff/debuff color
	_flash_card(side, slot_idx, Color(arrow_color.r, arrow_color.g, arrow_color.b, 0.3))

func _spawn_card_cracks(card: PanelContainer) -> void:
	## Draw diagonal crack lines across a card for hero KO visual.
	var crack_color := Color(0.9, 0.2, 0.1, 0.7)
	# Generate 3 random crack lines
	for i in range(3):
		var crack := Line2D.new()
		crack.width = randf_range(1.5, 3.0)
		crack.default_color = crack_color
		crack.z_index = 51
		# Random start and end within card bounds
		var start_x := randf_range(0, CARD_W * 0.3)
		var start_y := randf_range(0, CARD_H)
		var end_x := randf_range(CARD_W * 0.7, CARD_W)
		var end_y := randf_range(0, CARD_H)
		# Add some jagged intermediate points
		crack.add_point(Vector2(start_x, start_y))
		var mid_count := randi_range(2, 4)
		for j in range(mid_count):
			var t := float(j + 1) / float(mid_count + 1)
			var mx: float = lerp(start_x, end_x, t) + randf_range(-12, 12)
			var my: float = lerp(start_y, end_y, t) + randf_range(-8, 8)
			crack.add_point(Vector2(mx, my))
		crack.add_point(Vector2(end_x, end_y))
		crack.modulate = Color(1, 1, 1, 0)
		card.add_child(crack)
		# Animate crack appearing
		var delay := float(i) * 0.06 / _speed_mult
		var tw := create_tween()
		tw.tween_interval(delay)
		tw.tween_property(crack, "modulate:a", 1.0, 0.08 / _speed_mult)
		tw.tween_interval(1.5 / _speed_mult)
		tw.tween_property(crack, "modulate:a", 0.0, 0.5 / _speed_mult)
		tw.tween_callback(func():
			if is_instance_valid(crack): crack.queue_free()
		)

func _spawn_buff_arrow_indicator(card: PanelContainer, is_buff: bool) -> void:
	## Spawn a small persistent arrow indicator on the card edge.
	var indicator := Label.new()
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.z_index = 48
	if is_buff:
		indicator.text = "^"
		indicator.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3, 0.8))
		indicator.position = Vector2(CARD_W - 18, 2)
	else:
		indicator.text = "v"
		indicator.add_theme_color_override("font_color", Color(0.9, 0.2, 0.15, 0.8))
		indicator.position = Vector2(CARD_W - 18, CARD_H - 18)
	indicator.add_theme_font_size_override("font_size", 14)
	card.add_child(indicator)
	# Pulse the indicator then remove
	var tw := create_tween().set_loops(3)
	tw.tween_property(indicator, "modulate:a", 0.3, 0.3 / _speed_mult)
	tw.tween_property(indicator, "modulate:a", 1.0, 0.3 / _speed_mult)
	# Remove after pulsing
	get_tree().create_timer(2.0 / _speed_mult).timeout.connect(func():
		if is_instance_valid(indicator): indicator.queue_free()
	)

func _spawn_dot_pulsing_overlay(card: PanelContainer, color: Color) -> void:
	## Spawn a pulsing color overlay on a card for DoT effects (poison/burn).
	var overlay := ColorRect.new()
	overlay.size = card.size
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 36
	card.add_child(overlay)
	# Pulse 3 times then remove
	var tw := create_tween().set_loops(3)
	tw.tween_property(overlay, "color:a", color.a * 2.5, 0.35 / _speed_mult).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(overlay, "color:a", color.a * 0.5, 0.35 / _speed_mult).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(2.2 / _speed_mult).timeout.connect(func():
		if is_instance_valid(overlay):
			var tw_fade := create_tween()
			tw_fade.tween_property(overlay, "color:a", 0.0, 0.2 / _speed_mult)
			tw_fade.tween_callback(func():
				if is_instance_valid(overlay): overlay.queue_free()
			)
	)

# ═══════════════════════════════════════════════════════════
#                  ULTIMATE / AWAKENING VFX
# ═══════════════════════════════════════════════════════════

func play_ultimate_vfx(hero_id: String) -> void:
	## Full-screen cinematic ultimate skill VFX sequence.
	var tex: Texture2D = VfxLoaderRef.load_vfx(hero_id)
	var skill_color: Color = VfxLoaderRef.get_skill_color(hero_id)
	var skill_name: String = VfxLoaderRef.get_skill_name(hero_id)

	# Container CanvasLayer above everything (layer 25, combat view is 20)
	var vfx_layer := CanvasLayer.new()
	vfx_layer.layer = 25
	add_child(vfx_layer)

	# Full-screen root control
	var vfx_root := Control.new()
	vfx_root.anchor_right = 1.0
	vfx_root.anchor_bottom = 1.0
	vfx_root.mouse_filter = Control.MOUSE_FILTER_STOP
	vfx_layer.add_child(vfx_root)

	# Black dimming overlay
	var dim := ColorRect.new()
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.color = Color(0, 0, 0, 0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vfx_root.add_child(dim)

	# VFX texture display
	var vfx_rect := TextureRect.new()
	vfx_rect.texture = tex
	vfx_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	vfx_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vfx_rect.anchor_right = 1.0
	vfx_rect.anchor_bottom = 1.0
	vfx_rect.modulate = Color(1, 1, 1, 0)
	vfx_rect.pivot_offset = Vector2(SCREEN_W * 0.5, SCREEN_H * 0.5)
	vfx_rect.scale = Vector2(0.8, 0.8)
	vfx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vfx_root.add_child(vfx_rect)

	# Skill name label (gold, large, centered)
	var name_lbl := Label.new()
	name_lbl.text = skill_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.anchor_left = 0.2
	name_lbl.anchor_right = 0.8
	name_lbl.anchor_top = 0.42
	name_lbl.anchor_bottom = 0.58
	name_lbl.add_theme_font_size_override("font_size", 48)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	name_lbl.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	name_lbl.add_theme_constant_override("outline_size", 4)
	name_lbl.modulate = Color(1, 1, 1, 0)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vfx_root.add_child(name_lbl)

	# Color tint bar at top and bottom for cinematic letterbox feel
	var bar_top := ColorRect.new()
	bar_top.anchor_right = 1.0
	bar_top.size = Vector2(SCREEN_W, 50)
	bar_top.color = Color(skill_color.r, skill_color.g, skill_color.b, 0.0)
	bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vfx_root.add_child(bar_top)

	var bar_bot := ColorRect.new()
	bar_bot.anchor_right = 1.0
	bar_bot.anchor_bottom = 1.0
	bar_bot.anchor_top = 1.0
	bar_bot.offset_top = -50
	bar_bot.color = Color(skill_color.r, skill_color.g, skill_color.b, 0.0)
	bar_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vfx_root.add_child(bar_bot)

	var spd := _speed_mult

	# Phase 1: Screen darkens (0.2s)
	var tw_dim := create_tween()
	tw_dim.tween_property(dim, "color:a", 0.5, 0.2 / spd)
	tw_dim.parallel().tween_property(bar_top, "color:a", 0.6, 0.2 / spd)
	tw_dim.parallel().tween_property(bar_bot, "color:a", 0.6, 0.2 / spd)

	# Phase 2: VFX image fades in with scale bounce (0.3s, starts at 0.2s)
	var tw_vfx := create_tween()
	tw_vfx.tween_interval(0.2 / spd)
	tw_vfx.tween_property(vfx_rect, "modulate:a", 1.0, 0.2 / spd).set_ease(Tween.EASE_OUT)
	tw_vfx.parallel().tween_property(vfx_rect, "scale", Vector2(1.05, 1.05), 0.2 / spd).set_ease(Tween.EASE_OUT)
	tw_vfx.tween_property(vfx_rect, "scale", Vector2(1.0, 1.0), 0.1 / spd).set_ease(Tween.EASE_IN_OUT)

	# Phase 3: Skill name appears (0.2s, starts at 0.4s)
	var tw_name := create_tween()
	tw_name.tween_interval(0.4 / spd)
	tw_name.tween_property(name_lbl, "modulate:a", 1.0, 0.2 / spd).set_ease(Tween.EASE_OUT)

	# Phase 4: Hold with subtle pulse (0.8s, starts at 0.6s)
	var tw_pulse := create_tween().set_loops(2)
	tw_pulse.tween_interval(0.6 / spd)
	tw_pulse.tween_property(vfx_rect, "scale", Vector2(1.02, 1.02), 0.2 / spd).set_ease(Tween.EASE_IN_OUT)
	tw_pulse.tween_property(vfx_rect, "scale", Vector2(1.0, 1.0), 0.2 / spd).set_ease(Tween.EASE_IN_OUT)

	# Screen shake for impact
	_screen_shake(SHAKE_HEAVY, 6.0)

	# Phase 5: Fade out everything (0.3s, starts at ~1.5s)
	var total_hold := (0.6 + 0.8) / spd
	var tw_out := create_tween()
	tw_out.tween_interval(total_hold)
	tw_out.tween_property(dim, "color:a", 0.0, 0.3 / spd)
	tw_out.parallel().tween_property(vfx_rect, "modulate:a", 0.0, 0.3 / spd)
	tw_out.parallel().tween_property(name_lbl, "modulate:a", 0.0, 0.2 / spd)
	tw_out.parallel().tween_property(bar_top, "color:a", 0.0, 0.3 / spd)
	tw_out.parallel().tween_property(bar_bot, "color:a", 0.0, 0.3 / spd)

	# Cleanup
	var cleanup_delay := total_hold + 0.35 / spd
	get_tree().create_timer(cleanup_delay).timeout.connect(func():
		if is_instance_valid(vfx_layer):
			vfx_layer.queue_free()
		ultimate_vfx_finished.emit(hero_id)
	)


func play_awakening_vfx(hero_id: String, side: String, slot_idx: int) -> void:
	## Awakening burst effect on a hero's card with color flash and text.
	var skill_color: Color = VfxLoaderRef.get_skill_color(hero_id)
	var cards: Dictionary = attacker_cards if side == "attacker" else defender_cards
	if not cards.has(slot_idx):
		awakening_vfx_finished.emit(hero_id)
		return
	var card: PanelContainer = cards[slot_idx]
	var card_center := _get_card_center(side, slot_idx)
	var spd := _speed_mult

	# 1. Flash the hero card with awakening color
	var flash := ColorRect.new()
	flash.size = card.size
	flash.color = Color(skill_color.r, skill_color.g, skill_color.b, 0.8)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 50
	card.add_child(flash)

	var tw_flash := create_tween().set_loops(3)
	tw_flash.tween_property(flash, "color:a", 0.2, 0.1 / spd)
	tw_flash.tween_property(flash, "color:a", 0.8, 0.1 / spd)

	# 2. Scale burst effect (1.0 -> 1.5 -> 1.1)
	var orig_scale := card.scale
	var orig_pivot := card.pivot_offset
	card.pivot_offset = card.size * 0.5
	var tw_scale := create_tween()
	tw_scale.tween_property(card, "scale", Vector2(1.5, 1.5), 0.15 / spd).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_scale.tween_property(card, "scale", Vector2(1.1, 1.1), 0.2 / spd).set_ease(Tween.EASE_IN_OUT)
	tw_scale.tween_property(card, "scale", orig_scale, 0.15 / spd).set_ease(Tween.EASE_IN_OUT)

	# 3. Show "覚醒!" text above hero
	var awaken_lbl := Label.new()
	awaken_lbl.text = "覚醒!"
	awaken_lbl.add_theme_font_size_override("font_size", 28)
	awaken_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	awaken_lbl.add_theme_color_override("font_outline_color", Color(0.15, 0.0, 0.0))
	awaken_lbl.add_theme_constant_override("outline_size", 3)
	awaken_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	awaken_lbl.position = Vector2(card_center.x - 40, card_center.y - CARD_H * 0.5 - 40)
	awaken_lbl.modulate = Color(1, 1, 1, 0)
	awaken_lbl.z_index = 55
	awaken_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(anim_layer):
		anim_layer.add_child(awaken_lbl)
	else:
		root.add_child(awaken_lbl)

	var tw_text := create_tween()
	tw_text.tween_property(awaken_lbl, "modulate:a", 1.0, 0.1 / spd)
	tw_text.tween_property(awaken_lbl, "position:y", awaken_lbl.position.y - 20, 0.6 / spd).set_ease(Tween.EASE_OUT)
	tw_text.parallel().tween_property(awaken_lbl, "modulate:a", 0.0, 0.3 / spd).set_delay(0.4 / spd)

	# 4. Particle burst in hero's element color
	var density := _particle_density_mult() if has_method("_particle_density_mult") else 1.0
	var particle_count := int(12 * density)
	for i in range(particle_count):
		var p := ColorRect.new()
		p.size = Vector2(4, 4)
		p.color = Color(skill_color.r, skill_color.g, skill_color.b, 0.9)
		p.position = card_center
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.z_index = 52
		if is_instance_valid(anim_layer):
			anim_layer.add_child(p)
		else:
			root.add_child(p)
		var angle := TAU * float(i) / float(particle_count)
		var dist := randf_range(40.0, 90.0)
		var target_pos := card_center + Vector2(cos(angle), sin(angle)) * dist
		var tw_p := create_tween()
		tw_p.tween_property(p, "position", target_pos, 0.4 / spd).set_ease(Tween.EASE_OUT)
		tw_p.parallel().tween_property(p, "modulate:a", 0.0, 0.5 / spd).set_ease(Tween.EASE_IN)
		tw_p.tween_callback(func():
			if is_instance_valid(p): p.queue_free()
		)

	# Screen shake for awakening impact
	_screen_shake(SHAKE_MEDIUM, 8.0)

	# Chibi: cast pose during awakening
	_set_chibi_state(side, slot_idx, "cast", 1.0)

	# Cleanup
	get_tree().create_timer(1.0 / spd).timeout.connect(func():
		if is_instance_valid(flash): flash.queue_free()
		if is_instance_valid(awaken_lbl): awaken_lbl.queue_free()
		card.pivot_offset = orig_pivot
		awakening_vfx_finished.emit(hero_id)
	)

# ═══════════════════════════════════════════════════════════
#                      SAVE / LOAD
# ═══════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	return {}

func from_save_data(_data: Dictionary) -> void:
	pass
