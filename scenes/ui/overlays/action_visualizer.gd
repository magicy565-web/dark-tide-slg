## action_visualizer.gd — Action visualization overlay for board game actions.
## Provides animated visual feedback for attacks, deployments, recruits, builds,
## research, and turn transitions. Sits on CanvasLayer 7 (above board, below debug).
## Godot 4.2 GDScript — code-only, no .tscn needed.
extends Control

# ═══════════════════════════════════════════════════════════════
#                        SETTINGS
# ═══════════════════════════════════════════════════════════════

## Master toggle — disable to skip all visual effects.
var effects_enabled: bool = true
## Speed multiplier for all effect durations (higher = faster).
var effect_speed: float = 1.0

# ═══════════════════════════════════════════════════════════════
#                      CONSTANTS
# ═══════════════════════════════════════════════════════════════

const LAYER_INDEX: int = 7

# Duration bases (seconds) — divided by effect_speed at runtime.
const DUR_ATTACK: float = 1.6
const DUR_DEPLOY: float = 1.4
const DUR_RECRUIT: float = 1.2
const DUR_BUILD: float = 1.4
const DUR_RESEARCH: float = 1.5
const DUR_TURN_BANNER: float = 2.0
const DUR_FLOATING_TEXT: float = 1.0
const DUR_FLASH: float = 0.4

# Board layout estimation — used to map tile_index → screen position.
# The hex grid is roughly 6 columns; each tile ~120px apart on screen.
const BOARD_COLS: int = 6
const TILE_SCREEN_SPACING := Vector2(130.0, 110.0)
const BOARD_ORIGIN := Vector2(200.0, 180.0)

# Colors (supplement ColorTheme constants with effect-specific ones).
const COL_ATTACK_LINE := Color(0.95, 0.2, 0.15, 0.85)
const COL_ATTACK_FLASH := Color(0.9, 0.1, 0.05, 0.25)
const COL_DEPLOY_LINE := Color(0.3, 0.55, 1.0, 0.8)
const COL_DEPLOY_PULSE := Color(0.3, 0.6, 1.0, 0.5)
const COL_RECRUIT_GLOW := Color(0.3, 0.9, 0.35, 0.6)
const COL_BUILD_DUST := Color(0.7, 0.6, 0.4, 0.5)
const COL_RESEARCH_GLOW := Color(0.6, 0.35, 1.0, 0.65)
const COL_TURN_DIM := Color(0.0, 0.0, 0.0, 0.45)
const COL_VICTORY_TEXT := Color(1.0, 0.9, 0.25)
const COL_DEFEAT_TEXT := Color(1.0, 0.3, 0.25)

# ═══════════════════════════════════════════════════════════════
#                     EFFECT QUEUE
# ═══════════════════════════════════════════════════════════════

var _effect_queue: Array = []  # [{callable, params}]
var _playing: bool = false

# ═══════════════════════════════════════════════════════════════
#                      LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_connect_signals()


func _connect_signals() -> void:
	# Combat / attack
	if EventBus.has_signal("combat_result"):
		EventBus.combat_result.connect(_on_combat_result)
	# Territory capture flash
	if EventBus.has_signal("tile_captured"):
		EventBus.tile_captured.connect(_on_tile_captured)
	# Turn started — banner
	if EventBus.has_signal("turn_started"):
		EventBus.turn_started.connect(_on_turn_started)
	# Building
	if EventBus.has_signal("building_constructed"):
		EventBus.building_constructed.connect(_on_building_constructed)
	if EventBus.has_signal("building_upgraded"):
		EventBus.building_upgraded.connect(_on_building_upgraded)
	# Tech / research
	if EventBus.has_signal("tech_effects_applied"):
		EventBus.tech_effects_applied.connect(_on_tech_effects_applied)
	# Army deployment
	if EventBus.has_signal("army_deployed"):
		EventBus.army_deployed.connect(_on_army_deployed)
	# Army created (recruit)
	if EventBus.has_signal("army_created"):
		EventBus.army_created.connect(_on_army_created)
	# Siege
	if EventBus.has_signal("siege_started"):
		EventBus.siege_started.connect(_on_siege_started)
	# March system
	if EventBus.has_signal("army_march_started"):
		EventBus.army_march_started.connect(_on_march_started_vfx)
	if EventBus.has_signal("army_march_battle"):
		EventBus.army_march_battle.connect(_on_march_battle_vfx)
	if EventBus.has_signal("army_march_intercepted"):
		EventBus.army_march_intercepted.connect(_on_march_intercepted_vfx)
	if EventBus.has_signal("army_supply_low"):
		EventBus.army_supply_low.connect(_on_supply_low_vfx)
	if EventBus.has_signal("army_garrisoned"):
		EventBus.army_garrisoned.connect(_on_army_garrisoned_vfx)
	# Direct visualize signals (emitted by GameManager for specific actions)
	if EventBus.has_signal("action_visualize_deploy"):
		EventBus.action_visualize_deploy.connect(_on_action_visualize_deploy)
	if EventBus.has_signal("action_visualize_recruit"):
		EventBus.action_visualize_recruit.connect(_on_action_visualize_recruit)
	if EventBus.has_signal("action_visualize_build"):
		EventBus.action_visualize_build.connect(_on_action_visualize_build)
	# Army selected — show selection ring
	if EventBus.has_signal("army_selected"):
		EventBus.army_selected.connect(_on_army_selected_vfx)
	# Troops assigned — show recruit pulse
	if EventBus.has_signal("army_troops_assigned"):
		EventBus.army_troops_assigned.connect(_on_army_troops_assigned_vfx)


# ═══════════════════════════════════════════════════════════════
#                   PUBLIC API
# ═══════════════════════════════════════════════════════════════

## Main entry point — queues a visual effect by type string.
func play_effect(effect_type: String, params: Dictionary = {}) -> void:
	if not effects_enabled:
		return
	_effect_queue.append({"type": effect_type, "params": params})
	if not _playing:
		_play_next()


## Immediately skip / clear all pending effects.
func clear_effects() -> void:
	_effect_queue.clear()
	_playing = false
	for child in get_children():
		if child.has_meta("vfx"):
			child.queue_free()


# ═══════════════════════════════════════════════════════════════
#                   QUEUE RUNNER
# ═══════════════════════════════════════════════════════════════

func _play_next() -> void:
	if _effect_queue.is_empty():
		_playing = false
		return
	_playing = true
	var entry: Dictionary = _effect_queue.pop_front()
	var t: String = entry["type"]
	var p: Dictionary = entry["params"]
	var dur: float = 1.0
	match t:
		"attack":
			dur = _create_attack_effect(
				p.get("from_tile", 0), p.get("to_tile", 1), p.get("won", true))
		"deploy":
			dur = _create_deploy_effect(p.get("from_tile", 0), p.get("to_tile", 1))
		"recruit":
			dur = _create_recruit_effect(
				p.get("tile", 0), p.get("troop_name", "兵"), p.get("count", 1))
		"build":
			dur = _create_build_effect(p.get("tile", 0), p.get("building_name", ""))
		"research":
			dur = _create_research_effect(
				p.get("tech_name", ""), p.get("completed", false))
		"turn_banner":
			dur = _create_turn_banner(
				p.get("turn_number", 1), p.get("faction_name", ""))
		"capture_flash":
			dur = _create_capture_flash(p.get("tile", 0), p.get("player_id", 0))
		"march_start":
			dur = _create_march_start_effect(p.get("tile", 0))
		"march_battle":
			dur = _create_march_battle_effect(p.get("tile", 0))
		"march_intercept":
			dur = _create_march_intercept_effect(p.get("tile", 0))
		"supply_low":
			dur = _create_supply_low_effect(p.get("tile", 0), p.get("supply", 0.0))
		"garrison":
			dur = _create_garrison_effect(p.get("tile", 0))
		_:
			dur = 0.1
	# Overlap: start next effect slightly before current finishes.
	var overlap: float = max(dur * 0.25, 0.15)
	get_tree().create_timer(max(dur - overlap, 0.1) / effect_speed).timeout.connect(
		_play_next, CONNECT_ONE_SHOT)


# ═══════════════════════════════════════════════════════════════
#                   POSITION HELPER
# ═══════════════════════════════════════════════════════════════

## Estimate a 2D screen position from a tile index.
## This is approximate — the board is 3D but we project to a 2D hex grid.
func _estimate_screen_pos(tile_index: int) -> Vector2:
	var col: int = tile_index % BOARD_COLS
	var row: int = tile_index / BOARD_COLS
	var offset_x: float = (row % 2) * (TILE_SCREEN_SPACING.x * 0.5)
	return BOARD_ORIGIN + Vector2(
		col * TILE_SCREEN_SPACING.x + offset_x,
		row * TILE_SCREEN_SPACING.y)


## Duration helper — scales a base duration by effect_speed.
func _dur(base: float) -> float:
	return base / maxf(effect_speed, 0.1)


# ═══════════════════════════════════════════════════════════════
#              REUSABLE: FLOATING TEXT
# ═══════════════════════════════════════════════════════════════

func _create_floating_text(pos: Vector2, text: String, color: Color,
			duration: float = DUR_FLOATING_TEXT, font_size: int = 22) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = pos - Vector2(60, 15)
	lbl.custom_minimum_size = Vector2(120, 30)
	lbl.set_meta("vfx", true)
	add_child(lbl)

	var d: float = _dur(duration)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 60.0, d).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(lbl, "modulate:a", 0.0, d).set_ease(Tween.EASE_IN).set_delay(d * 0.5)
	tw.set_parallel(false)
	tw.tween_callback(_cleanup_effect.bind(lbl)).set_delay(0.01)
	return lbl


# ═══════════════════════════════════════════════════════════════
#              REUSABLE: LINE EFFECT
# ═══════════════════════════════════════════════════════════════

func _create_line_effect(from_pos: Vector2, to_pos: Vector2, color: Color,
			duration: float = 0.8, width: float = 3.0, dashed: bool = false) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.set_meta("vfx", true)
	if dashed:
		# Build dashed segments.
		var dir: Vector2 = (to_pos - from_pos)
		var length: float = dir.length()
		var step: float = 12.0
		var gap: float = 8.0
		var d: float = 0.0
		var drawing: bool = true
		var norm: Vector2 = dir.normalized()
		while d < length:
			var seg_end: float = minf(d + (step if drawing else gap), length)
			if drawing:
				line.add_point(from_pos + norm * d)
				line.add_point(from_pos + norm * seg_end)
			d = seg_end
			drawing = not drawing
	else:
		line.add_point(from_pos)
		line.add_point(to_pos)
	add_child(line)

	var dur: float = _dur(duration)
	var tw := create_tween()
	tw.tween_property(line, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN).set_delay(dur * 0.4)
	tw.tween_callback(_cleanup_effect.bind(line))
	return line


# ═══════════════════════════════════════════════════════════════
#              REUSABLE: SCREEN FLASH
# ═══════════════════════════════════════════════════════════════

func _create_screen_flash(color: Color, duration: float = DUR_FLASH) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_meta("vfx", true)
	add_child(rect)

	var d: float = _dur(duration)
	var tw := create_tween()
	tw.tween_property(rect, "color:a", 0.0, d).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_cleanup_effect.bind(rect))
	return rect


# ═══════════════════════════════════════════════════════════════
#              REUSABLE: PULSE RING
# ═══════════════════════════════════════════════════════════════

func _create_pulse_ring(center: Vector2, color: Color, duration: float = 0.6) -> Control:
	var ring := Control.new()
	ring.position = center
	ring.set_meta("vfx", true)
	ring.set_meta("ring_radius", 10.0)
	ring.set_meta("ring_color", color)
	add_child(ring)

	# We use a simple expanding ColorRect circle approximation via a Panel.
	# Instead, draw via a custom _draw on a dedicated node — but since we
	# want minimal overhead, use a flat ColorRect scaled outward.
	var dot := ColorRect.new()
	dot.color = color
	dot.custom_minimum_size = Vector2(20, 20)
	dot.size = Vector2(20, 20)
	dot.position = -Vector2(10, 10)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(dot)

	var d: float = _dur(duration)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(4.0, 4.0), d).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(dot, "color:a", 0.0, d).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(_cleanup_effect.bind(ring))
	return ring


# ═══════════════════════════════════════════════════════════════
#              EFFECT: ATTACK
# ═══════════════════════════════════════════════════════════════

## Returns total effect duration.
func _create_attack_effect(from_tile: int, to_tile: int, won: bool) -> float:
	var from_pos: Vector2 = _estimate_screen_pos(from_tile)
	var to_pos: Vector2 = _estimate_screen_pos(to_tile)
	var dur: float = _dur(DUR_ATTACK)

	# 1) Red dashed arrow line from attacker to defender.
	_create_line_effect(from_pos, to_pos, COL_ATTACK_LINE, dur * 0.7, 3.5, true)

	# 2) Sword clash icon text at midpoint.
	var mid: Vector2 = (from_pos + to_pos) * 0.5
	var clash_lbl := Label.new()
	clash_lbl.text = "⚔"
	clash_lbl.add_theme_font_size_override("font_size", 36)
	clash_lbl.add_theme_color_override("font_color", Color.WHITE)
	clash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clash_lbl.position = mid - Vector2(20, 20)
	clash_lbl.set_meta("vfx", true)
	add_child(clash_lbl)

	var tw_clash := create_tween()
	tw_clash.tween_property(clash_lbl, "scale", Vector2(1.5, 1.5), dur * 0.15).set_ease(Tween.EASE_OUT)
	tw_clash.tween_property(clash_lbl, "scale", Vector2(1.0, 1.0), dur * 0.1)
	tw_clash.tween_property(clash_lbl, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.2)
	tw_clash.tween_callback(_cleanup_effect.bind(clash_lbl))

	# 3) Screen edge flash (red tint).
	_create_screen_flash(COL_ATTACK_FLASH, dur * 0.35)

	# 4) Floating result text.
	var result_text: String = "胜利!" if won else "失败!"
	var result_color: Color = COL_VICTORY_TEXT if won else COL_DEFEAT_TEXT
	# Delay the result text slightly.
	get_tree().create_timer(dur * 0.4).timeout.connect(
		_create_floating_text.bind(to_pos, result_text, result_color, dur * 0.5, 26),
		CONNECT_ONE_SHOT)

	return dur


# ═══════════════════════════════════════════════════════════════
#              EFFECT: DEPLOY
# ═══════════════════════════════════════════════════════════════

func _create_deploy_effect(from_tile: int, to_tile: int) -> float:
	var from_pos: Vector2 = _estimate_screen_pos(from_tile)
	var to_pos: Vector2 = _estimate_screen_pos(to_tile)
	var dur: float = _dur(DUR_DEPLOY)

	# 1) Blue arrow line.
	_create_line_effect(from_pos, to_pos, COL_DEPLOY_LINE, dur * 0.8, 3.0, false)

	# 2) Troop silhouette moving along path.
	var silhouette := Label.new()
	silhouette.text = "🚩"
	silhouette.add_theme_font_size_override("font_size", 24)
	silhouette.position = from_pos - Vector2(12, 12)
	silhouette.set_meta("vfx", true)
	add_child(silhouette)

	var tw_move := create_tween()
	tw_move.tween_property(silhouette, "position",
		to_pos - Vector2(12, 12), dur * 0.65).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	tw_move.tween_property(silhouette, "modulate:a", 0.0, dur * 0.2)
	tw_move.tween_callback(_cleanup_effect.bind(silhouette))

	# 3) Arrival pulse at destination.
	get_tree().create_timer(dur * 0.6).timeout.connect(
		_create_pulse_ring.bind(to_pos, COL_DEPLOY_PULSE, dur * 0.35),
		CONNECT_ONE_SHOT)

	return dur


# ═══════════════════════════════════════════════════════════════
#              EFFECT: RECRUIT
# ═══════════════════════════════════════════════════════════════

func _create_recruit_effect(tile: int, troop_name: String, count: int) -> float:
	var pos: Vector2 = _estimate_screen_pos(tile)
	var dur: float = _dur(DUR_RECRUIT)

	# 1) Green sparkle — small expanding dots.
	for i in range(5):
		var dot := ColorRect.new()
		dot.color = COL_RECRUIT_GLOW
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size = Vector2(6, 6)
		dot.position = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.set_meta("vfx", true)
		add_child(dot)

		var tw_dot := create_tween()
		tw_dot.set_parallel(true)
		tw_dot.tween_property(dot, "position:y", dot.position.y - randf_range(20, 50),
			dur * 0.7).set_ease(Tween.EASE_OUT).set_delay(i * 0.05)
		tw_dot.tween_property(dot, "modulate:a", 0.0, dur * 0.5).set_delay(dur * 0.3 + i * 0.05)
		tw_dot.set_parallel(false)
		tw_dot.tween_callback(_cleanup_effect.bind(dot))

	# 2) Floating "+兵 xN" text.
	var text: String = "+%s x%d" % [troop_name, count]
	_create_floating_text(pos, text, ColorTheme.TEXT_SUCCESS if is_instance_valid(ColorTheme) else Color(0.4, 0.9, 0.4), dur * 0.8, 20)

	# 3) Brief glow pulse on tile.
	_create_pulse_ring(pos, COL_RECRUIT_GLOW, dur * 0.5)

	return dur


# ═══════════════════════════════════════════════════════════════
#              EFFECT: BUILD
# ═══════════════════════════════════════════════════════════════

func _create_build_effect(tile: int, building_name: String) -> float:
	var pos: Vector2 = _estimate_screen_pos(tile)
	var dur: float = _dur(DUR_BUILD)

	# 1) Hammer icon animation.
	var hammer := Label.new()
	hammer.text = "🔨"
	hammer.add_theme_font_size_override("font_size", 30)
	hammer.position = pos - Vector2(18, 35)
	hammer.set_meta("vfx", true)
	add_child(hammer)

	var tw_ham := create_tween()
	# Swing animation: rotate back and forth.
	tw_ham.tween_property(hammer, "rotation", deg_to_rad(-20.0), dur * 0.1)
	tw_ham.tween_property(hammer, "rotation", deg_to_rad(15.0), dur * 0.1)
	tw_ham.tween_property(hammer, "rotation", deg_to_rad(-15.0), dur * 0.1)
	tw_ham.tween_property(hammer, "rotation", 0.0, dur * 0.1)
	tw_ham.tween_property(hammer, "modulate:a", 0.0, dur * 0.3).set_delay(dur * 0.15)
	tw_ham.tween_callback(_cleanup_effect.bind(hammer))

	# 2) Construction dust particles.
	for i in range(6):
		var dust := ColorRect.new()
		dust.color = COL_BUILD_DUST
		dust.custom_minimum_size = Vector2(4, 4)
		dust.size = Vector2(4, 4)
		dust.position = pos + Vector2(randf_range(-20, 20), randf_range(-5, 5))
		dust.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dust.set_meta("vfx", true)
		add_child(dust)

		var tw_d := create_tween()
		tw_d.set_parallel(true)
		var target_y: float = dust.position.y - randf_range(25, 55)
		var target_x: float = dust.position.x + randf_range(-25, 25)
		tw_d.tween_property(dust, "position", Vector2(target_x, target_y),
			dur * 0.6).set_ease(Tween.EASE_OUT).set_delay(i * 0.04)
		tw_d.tween_property(dust, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.25 + i * 0.03)
		tw_d.set_parallel(false)
		tw_d.tween_callback(_cleanup_effect.bind(dust))

	# 3) "建造完成!" floating text.
	var display_name: String = building_name if building_name != "" else "建筑"
	var text: String = "建造完成! %s" % display_name
	_create_floating_text(pos + Vector2(0, 10), text,
		ColorTheme.TEXT_GOLD if is_instance_valid(ColorTheme) else Color(1.0, 0.85, 0.35),
		dur * 0.7, 18)

	return dur


# ═══════════════════════════════════════════════════════════════
#              EFFECT: RESEARCH
# ═══════════════════════════════════════════════════════════════

func _create_research_effect(tech_name: String, completed: bool) -> float:
	var dur: float = _dur(DUR_RESEARCH)
	var vp_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = vp_size * 0.5

	# 1) Book/scroll icon with glow.
	var icon := Label.new()
	icon.text = "📜"
	icon.add_theme_font_size_override("font_size", 40)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.position = center - Vector2(22, 80)
	icon.set_meta("vfx", true)
	add_child(icon)

	var tw_icon := create_tween()
	tw_icon.tween_property(icon, "scale", Vector2(1.3, 1.3), dur * 0.15).set_ease(Tween.EASE_OUT)
	tw_icon.tween_property(icon, "scale", Vector2(1.0, 1.0), dur * 0.1)
	tw_icon.tween_property(icon, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.3)
	tw_icon.tween_callback(_cleanup_effect.bind(icon))

	# 2) Banner text.
	var prefix: String = "研究完成: " if completed else "开始研究: "
	var banner_text: String = prefix + tech_name
	var banner_color: Color = COL_RESEARCH_GLOW if not completed else Color(0.9, 0.7, 1.0)

	var banner := Label.new()
	banner.text = banner_text
	banner.add_theme_font_size_override("font_size", 24)
	banner.add_theme_color_override("font_color", banner_color)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.custom_minimum_size = Vector2(400, 40)
	banner.position = center - Vector2(200, 30)
	banner.modulate.a = 0.0
	banner.set_meta("vfx", true)
	add_child(banner)

	var tw_banner := create_tween()
	tw_banner.tween_property(banner, "modulate:a", 1.0, dur * 0.15).set_ease(Tween.EASE_OUT)
	tw_banner.tween_interval(dur * 0.5)
	tw_banner.tween_property(banner, "modulate:a", 0.0, dur * 0.25).set_ease(Tween.EASE_IN)
	tw_banner.tween_callback(_cleanup_effect.bind(banner))

	# 3) Purple sparkle trail.
	for i in range(8):
		var sparkle := ColorRect.new()
		sparkle.color = COL_RESEARCH_GLOW
		sparkle.custom_minimum_size = Vector2(5, 5)
		sparkle.size = Vector2(5, 5)
		sparkle.position = center + Vector2(randf_range(-100, 100), randf_range(-60, 60))
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sparkle.set_meta("vfx", true)
		add_child(sparkle)

		var tw_s := create_tween()
		tw_s.set_parallel(true)
		tw_s.tween_property(sparkle, "position:y", sparkle.position.y - randf_range(30, 70),
			dur * 0.6).set_ease(Tween.EASE_OUT).set_delay(i * 0.06)
		tw_s.tween_property(sparkle, "modulate:a", 0.0, dur * 0.4).set_delay(dur * 0.25 + i * 0.04)
		tw_s.set_parallel(false)
		tw_s.tween_callback(_cleanup_effect.bind(sparkle))

	return dur


# ═══════════════════════════════════════════════════════════════
#              EFFECT: TURN BANNER
# ═══════════════════════════════════════════════════════════════

func _create_turn_banner(turn_number: int, faction_name: String) -> float:
	var dur: float = _dur(DUR_TURN_BANNER)
	var vp_size: Vector2 = get_viewport_rect().size
	var center: Vector2 = vp_size * 0.5

	# 1) Brief screen dim.
	var dim := ColorRect.new()
	dim.color = COL_TURN_DIM
	dim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.modulate.a = 0.0
	dim.set_meta("vfx", true)
	add_child(dim)

	var tw_dim := create_tween()
	tw_dim.tween_property(dim, "modulate:a", 1.0, dur * 0.12).set_ease(Tween.EASE_OUT)
	tw_dim.tween_interval(dur * 0.55)
	tw_dim.tween_property(dim, "modulate:a", 0.0, dur * 0.25).set_ease(Tween.EASE_IN)
	tw_dim.tween_callback(_cleanup_effect.bind(dim))

	# 2) Large centered "第N回合" text with scale animation.
	var turn_lbl := Label.new()
	turn_lbl.text = "第%d回合" % turn_number
	turn_lbl.add_theme_font_size_override("font_size", 48)
	turn_lbl.add_theme_color_override("font_color",
		ColorTheme.TEXT_GOLD if is_instance_valid(ColorTheme) else Color(1.0, 0.85, 0.35))
	turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_lbl.custom_minimum_size = Vector2(500, 60)
	turn_lbl.position = center - Vector2(250, 30)
	turn_lbl.scale = Vector2(0.6, 0.6)
	turn_lbl.pivot_offset = Vector2(250, 30)
	turn_lbl.modulate.a = 0.0
	turn_lbl.set_meta("vfx", true)
	add_child(turn_lbl)

	var tw_turn := create_tween()
	tw_turn.set_parallel(true)
	tw_turn.tween_property(turn_lbl, "scale", Vector2(1.0, 1.0), dur * 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw_turn.tween_property(turn_lbl, "modulate:a", 1.0, dur * 0.15).set_ease(Tween.EASE_OUT)
	tw_turn.set_parallel(false)
	tw_turn.tween_interval(dur * 0.45)
	tw_turn.set_parallel(true)
	tw_turn.tween_property(turn_lbl, "modulate:a", 0.0, dur * 0.2).set_ease(Tween.EASE_IN)
	tw_turn.tween_property(turn_lbl, "scale", Vector2(1.1, 1.1), dur * 0.2)
	tw_turn.set_parallel(false)
	tw_turn.tween_callback(_cleanup_effect.bind(turn_lbl))

	# 3) Faction crest watermark (subtle text-based if no texture).
	if faction_name != "":
		var crest := Label.new()
		crest.text = faction_name.to_upper()
		crest.add_theme_font_size_override("font_size", 72)
		crest.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.06))
		crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		crest.custom_minimum_size = Vector2(600, 90)
		crest.position = center - Vector2(300, 80)
		crest.set_meta("vfx", true)
		add_child(crest)

		# Try loading actual crest texture.
		var crest_tex: Texture2D = _safe_load_texture(
			"res://assets/map/crests_hd/crest_%s.png" % faction_name.to_lower())
		if crest_tex:
			var crest_sprite := TextureRect.new()
			crest_sprite.texture = crest_tex
			crest_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			crest_sprite.custom_minimum_size = Vector2(120, 120)
			crest_sprite.size = Vector2(120, 120)
			crest_sprite.position = center - Vector2(60, 120)
			crest_sprite.modulate = Color(1, 1, 1, 0.12)
			crest_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
			crest_sprite.set_meta("vfx", true)
			add_child(crest_sprite)
			# Fade out the texture crest; hide text version.
			crest.visible = false
			var tw_cs := create_tween()
			tw_cs.tween_property(crest_sprite, "modulate:a", 0.0, dur * 0.8).set_delay(dur * 0.15)
			tw_cs.tween_callback(_cleanup_effect.bind(crest_sprite))

		var tw_crest := create_tween()
		tw_crest.tween_property(crest, "modulate:a", 0.0, dur * 0.85).set_delay(dur * 0.1)
		tw_crest.tween_callback(_cleanup_effect.bind(crest))

	return dur


# ═══════════════════════════════════════════════════════════════
#              EFFECT: TERRITORY CAPTURE FLASH
# ═══════════════════════════════════════════════════════════════

func _create_capture_flash(tile: int, player_id: int) -> float:
	var pos: Vector2 = _estimate_screen_pos(tile)
	var dur: float = _dur(0.8)

	# Faction-colored pulse ring.
	var faction_color: Color = _get_faction_color_for_player(player_id)
	_create_pulse_ring(pos, faction_color, dur)
	_create_floating_text(pos, "占领!", faction_color, dur * 0.8, 20)

	return dur


# ═══════════════════════════════════════════════════════════════
#              SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_combat_result(_attacker_id: int, _defender_desc: String, won: bool) -> void:
	# We don't have exact tile info from this signal, so use a generic centered effect.
	var vp_size: Vector2 = get_viewport_rect().size
	var flash_color: Color = COL_ATTACK_FLASH if not won else Color(0.1, 0.3, 0.05, 0.2)
	_create_screen_flash(flash_color)
	var result_text: String = "胜利!" if won else "失败!"
	var result_color: Color = COL_VICTORY_TEXT if won else COL_DEFEAT_TEXT
	_create_floating_text(vp_size * 0.5, result_text, result_color, 1.2, 32)


func _on_tile_captured(player_id: int, tile_index: int) -> void:
	play_effect("capture_flash", {"tile": tile_index, "player_id": player_id})


func _on_turn_started(player_id: int) -> void:
	# Determine turn number from GameManager if available.
	var turn_num: int = 1
	var faction_name: String = ""
	if Engine.has_singleton("GameManager") or get_node_or_null("/root/GameManager"):
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			if "current_turn" in gm:
				turn_num = gm.current_turn
			elif "turn_number" in gm:
				turn_num = gm.turn_number
			if gm.has_method("get_player_faction_name"):
				faction_name = gm.get_player_faction_name(player_id)
	play_effect("turn_banner", {
		"turn_number": turn_num,
		"faction_name": faction_name,
	})


func _on_building_constructed(_player_id: int, tile_index: int, building_id: String) -> void:
	play_effect("build", {"tile": tile_index, "building_name": building_id})


func _on_building_upgraded(_player_id: int, tile_index: int, building_id: String, _new_level: int) -> void:
	play_effect("build", {"tile": tile_index, "building_name": building_id})


func _on_tech_effects_applied(_player_id: int) -> void:
	play_effect("research", {"tech_name": "", "completed": true})


func _on_army_deployed(_player_id: int, _army_id: int, from_tile: int, to_tile: int) -> void:
	play_effect("deploy", {"from_tile": from_tile, "to_tile": to_tile})


func _on_army_created(_player_id: int, _army_id: int, tile_index: int) -> void:
	play_effect("recruit", {"tile": tile_index, "troop_name": "军队", "count": 1})


func _on_siege_started(_attacker_army_id: int, tile_index: int, _turns: int) -> void:
	var pos: Vector2 = _estimate_screen_pos(tile_index)
	_create_floating_text(pos, "围攻开始!", Color(0.95, 0.5, 0.2), 1.5, 22)
	_create_pulse_ring(pos, Color(0.9, 0.3, 0.1, 0.5), 0.8)


func _on_march_started_vfx(army_id: int, path: Array) -> void:
	if path.is_empty(): return
	var tile: int = path[0]
	play_effect("march_start", {"tile": tile, "army_id": army_id})


func _on_march_battle_vfx(army_id: int, tile_index: int) -> void:
	play_effect("march_battle", {"tile": tile_index, "army_id": army_id})


func _on_march_intercepted_vfx(army_id: int, _interceptor_id: int, tile_index: int) -> void:
	play_effect("march_intercept", {"tile": tile_index, "army_id": army_id})


func _on_supply_low_vfx(army_id: int, supply: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if not gm: return
	var army: Dictionary = gm.get_army(army_id) if gm.has_method("get_army") else {}
	if army.is_empty(): return
	var tile: int = army.get("tile_index", -1)
	if tile < 0: return
	play_effect("supply_low", {"tile": tile, "supply": supply})


func _on_army_garrisoned_vfx(army_id: int, tile_index: int) -> void:
	play_effect("garrison", {"tile": tile_index, "army_id": army_id})


# ═══════════════════════════════════════════════════════════════
#              EFFECT: MARCH START
# ═══════════════════════════════════════════════════════════════

## Plays when an army begins a march order: a cyan pulse ring + floating text.
func _create_march_start_effect(tile: int) -> float:
	var pos: Vector2 = _estimate_screen_pos(tile)
	var dur: float = _dur(1.2)
	_create_pulse_ring(pos, Color(0.3, 0.75, 1.0, 0.6), dur * 0.5)
	_create_floating_text(pos, "行军!", Color(0.35, 0.8, 1.0), dur * 0.7, 20)
	return dur


# ═══════════════════════════════════════════════════════════════
#              EFFECT: MARCH BATTLE
# ═══════════════════════════════════════════════════════════════

## Plays when a marching army encounters a hostile tile: red flash + clash icon.
func _create_march_battle_effect(tile: int) -> float:
	var pos: Vector2 = _estimate_screen_pos(tile)
	var dur: float = _dur(1.6)
	# Red screen flash
	_create_screen_flash(Color(0.85, 0.1, 0.05, 0.22), dur * 0.35)
	# Clash icon at tile
	var clash := Label.new()
	clash.text = "⚔"
	clash.add_theme_font_size_override("font_size", 40)
	clash.add_theme_color_override("font_color", Color(1.0, 0.35, 0.1))
	clash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clash.position = pos - Vector2(22, 22)
	clash.set_meta("vfx", true)
	add_child(clash)
	var tw := create_tween()
	tw.tween_property(clash, "scale", Vector2(1.6, 1.6), dur * 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(clash, "scale", Vector2(1.0, 1.0), dur * 0.1)
	tw.tween_property(clash, "modulate:a", 0.0, dur * 0.45).set_delay(dur * 0.25)
	tw.tween_callback(_cleanup_effect.bind(clash))
	# Floating text
	_create_floating_text(pos, "遇敌!", Color(1.0, 0.4, 0.15), dur * 0.6, 22)
	return dur


# ═══════════════════════════════════════════════════════════════
#              EFFECT: MARCH INTERCEPT
# ═══════════════════════════════════════════════════════════════

## Plays when a marching army is intercepted: yellow warning flash + icon.
func _create_march_intercept_effect(tile: int) -> float:
	var pos: Vector2 = _estimate_screen_pos(tile)
	var dur: float = _dur(1.4)
	# Yellow-orange screen flash
	_create_screen_flash(Color(0.9, 0.75, 0.05, 0.18), dur * 0.3)
	# Warning icon
	var warn := Label.new()
	warn.text = "⚠"
	warn.add_theme_font_size_override("font_size", 38)
	warn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.1))
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.position = pos - Vector2(20, 20)
	warn.set_meta("vfx", true)
	add_child(warn)
	var tw := create_tween()
	tw.tween_property(warn, "scale", Vector2(1.5, 1.5), dur * 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(warn, "scale", Vector2(1.0, 1.0), dur * 0.1)
	tw.tween_property(warn, "modulate:a", 0.0, dur * 0.45).set_delay(dur * 0.3)
	tw.tween_callback(_cleanup_effect.bind(warn))
	_create_floating_text(pos, "拦截!", Color(1.0, 0.85, 0.1), dur * 0.55, 20)
	return dur


# ═══════════════════════════════════════════════════════════════
#              EFFECT: SUPPLY LOW
# ═══════════════════════════════════════════════════════════════

## Plays when an army's supply drops below the critical threshold.
func _create_supply_low_effect(tile: int, supply: float) -> float:
	var pos: Vector2 = _estimate_screen_pos(tile)
	var dur: float = _dur(1.3)
	var pct_text: String = "%d%%" % int(supply)
	_create_floating_text(pos, "⚠ 补给 " + pct_text, Color(0.95, 0.65, 0.1), dur * 0.7, 18)
	_create_pulse_ring(pos, Color(0.9, 0.6, 0.1, 0.45), dur * 0.4)
	return dur


# ═══════════════════════════════════════════════════════════════
#              EFFECT: GARRISON
# ═══════════════════════════════════════════════════════════════

## Plays when an army enters garrison stance: gold pulse ring + shield text.
func _create_garrison_effect(tile: int) -> float:
	var pos: Vector2 = _estimate_screen_pos(tile)
	var dur: float = _dur(1.2)
	_create_pulse_ring(pos, Color(1.0, 0.85, 0.2, 0.55), dur * 0.5)
	_create_floating_text(pos, "🛡 驻守", Color(1.0, 0.88, 0.25), dur * 0.7, 20)
	return dur


# ═══════════════════════════════════════════════════════════════
#              UTILITY
# ═══════════════════════════════════════════════════════════════

func _cleanup_effect(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()


func _safe_load_texture(path: String) -> Variant:
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _get_faction_color_for_player(player_id: int) -> Color:
	# Try to resolve via GameManager → faction name → ColorTheme color.
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("get_player_faction_name"):
		var fname: String = gm.get_player_faction_name(player_id)
		if fname != "":
			return ColorTheme.FACTION_COLORS.get(fname.to_lower(), ColorTheme.TEXT_GOLD)
	# Fallback: use player_id-based color from ColorTheme faction ID map.
	if player_id >= 0 and player_id < 3:
		var fid: int = -1
		if gm and gm.has_method("get_player_faction"):
			fid = gm.get_player_faction(player_id)
		if fid >= 0 and ColorTheme.FACTION_ID_COLORS.has(fid):
			return ColorTheme.FACTION_ID_COLORS[fid]
	return ColorTheme.ACCENT_GOLD


# ═══════════════════════════════════════════════════════════════
#   HANDLERS FOR DIRECT VISUALIZE SIGNALS (GameManager → VFX)
# ═══════════════════════════════════════════════════════════════

func _on_action_visualize_deploy(army_id: int, from_tile: int, to_tile: int) -> void:
	## Triggered by GameManager.action_deploy_army — show a deploy line effect.
	play_effect("deploy", {"from_tile": from_tile, "to_tile": to_tile})


func _on_action_visualize_recruit(tile_index: int, troop_id: String, count: int) -> void:
	## Triggered by GameManager recruit actions — show a recruit glow at the tile.
	play_effect("recruit", {"tile": tile_index, "troop_name": troop_id, "count": count})


func _on_action_visualize_build(tile_index: int, _building_id: String) -> void:
	## Triggered by GameManager.action_domestic build — show a build dust effect.
	play_effect("build", {"tile": tile_index, "building_name": _building_id})


func _on_army_selected_vfx(army_id: int) -> void:
	## Show a brief selection ring pulse at the army's current tile.
	if not GameManager.armies.has(army_id):
		return
	if not GameManager.armies.has(army_id):
		return
	var tile_idx: int = GameManager.armies[army_id].get("tile_index", -1)
	if tile_idx < 0:
		return
	var pos: Vector2 = _estimate_screen_pos(tile_idx)
	# Brief cyan ring pulse
	var ring := ColorRect.new()
	ring.size = Vector2(60, 60)
	ring.position = pos - Vector2(30, 30)
	ring.color = Color(0.3, 0.85, 1.0, 0.0)
	ring.set_meta("vfx", true)
	add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "color:a", 0.55, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "size", Vector2(80, 80), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "position", pos - Vector2(40, 40), 0.35).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_property(ring, "color:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(_cleanup_effect.bind(ring))


func _on_army_troops_assigned_vfx(army_id: int, _troop_id: String, _soldiers: int) -> void:
	## Show a green recruit pulse at the army's tile when troops are assigned.
	if not GameManager.armies.has(army_id):
		return
	if not GameManager.armies.has(army_id):
		return
	var tile_idx: int = GameManager.armies[army_id].get("tile_index", -1)
	if tile_idx < 0:
		return
	play_effect("recruit", {"tile": tile_idx, "troop_name": _troop_id, "count": _soldiers})
