## battle_vfx_controller.gd — Central visual feedback controller for battle animations
## v11.0 DEEP OPTIMIZATION:
##   - Label/particle object pools (eliminates per-hit GC pressure)
##   - Miss/dodge visual feedback ("MISS" floating label + dodge arc)
##   - Enhanced crit: gold ring burst + screen-edge vignette flash
##   - Adaptive playback pacing: speed_mult scales all timings uniformly
##   - Combo kill streak banner (3+ kills/round triggers COMBO KILL!)
##   - Buff/debuff icon symbols expanded with new spd/cleanse types
## Listens to EventBus signals (screen_shake, camera_zoom, combo_chain, skill_vfx,
## formation_detected) and drives all missing VFX systems:
##   1. Screen Shake (sine wave + decay)
##   2. Camera Zoom (smooth tween)
##   3. Damage Numbers (color-coded floating labels) [POOLED]
##   4. Combo Chain Playback (sequential hit visualization)
##   5. Round Transition Banner (slide-in "ROUND X")
##   6. Buff/Debuff Visual Indicators (icon overlays + pulse)
##   7. Critical Hit Indicator (gold sparkle burst + hit-freeze) [ENHANCED]
##   8. Formation Banner (formation name slide-in)
##   9. Miss/Dodge Indicator [NEW]
##  10. Combo Kill Streak Banner [NEW]
class_name BattleVfxController
extends Node

const SkillAnimationData = preload("res://systems/combat/skill_animation_data.gd")

# ── References (set by combat_view after instantiation) ──
var shake_target: Control = null      # The shake_container from CombatView
var overlay_parent: Control = null     # anim_layer for spawning VFX nodes
var root_control: Control = null       # CombatView root for full-screen overlays
var speed_mult: float = 1.0           # Playback speed multiplier from CombatView

# ── Screen Shake State ──
var _shake_time_remaining: float = 0.0
var _shake_intensity: float = 0.0
var _shake_frequency: float = 30.0    # Sine wave oscillations per second
var _shake_elapsed: float = 0.0
var _shake_initial_intensity: float = 0.0

# ── Shake intensity presets (pixels) ──
const SHAKE_LIGHT := 2.0
const SHAKE_MEDIUM := 5.0
const SHAKE_HEAVY := 10.0
const SHAKE_CRIT := 15.0

# ── Camera Zoom State ──
var _zoom_tween: Tween = null
var _is_zooming: bool = false

# ── Combo Chain State ──
var _combo_chain_active: bool = false
var _combo_hit_index: int = 0
var _combo_counter_label: Label = null

# ── Formation Banner ──
var _formation_banner: PanelContainer = null
var _formation_label: Label = null

# ── Round Banner ──
var _round_banner: PanelContainer = null
var _round_banner_label: Label = null

# ── Buff/Debuff overlay tracking: side -> slot -> Array[Control] ──
var _buff_overlays: Dictionary = {"attacker": {}, "defender": {}}

# ── v11.0: Label Object Pool ──
## Pre-allocated pool of Label nodes to avoid per-hit GC allocations.
const LABEL_POOL_SIZE := 32
var _label_pool: Array[Label] = []
var _label_pool_idx: int = 0

# ── v11.0: Particle pool ──
const PARTICLE_POOL_SIZE := 64
var _particle_pool: Array[ColorRect] = []
var _particle_pool_idx: int = 0

# ── v11.0: Combo kill streak tracking ──
var _kill_streak_count: int = 0
var _kill_streak_banner: Label = null

# ── v11.0: Vignette flash overlay (reused) ──
var _vignette_overlay: ColorRect = null

# ── Card position callback (set by combat_view) ──
var _get_card_center_fn: Callable = Callable()

# ── Constants ──
const SCREEN_W := 1280.0
const SCREEN_H := 720.0
const CENTER_X := 640.0

# ── Damage number colors ──
const DMG_COLOR_NORMAL := Color(1.0, 1.0, 1.0)
const DMG_COLOR_CRIT := Color(1.0, 0.9, 0.2)
const DMG_COLOR_HEAL := Color(0.3, 1.0, 0.5)
const DMG_COLOR_HEAVY := Color(1.0, 0.25, 0.2)
const DMG_COLOR_BLOCK := Color(0.6, 0.6, 0.6)


func _ready() -> void:
	_connect_signals()
	_build_formation_banner()
	_build_round_banner()
	_build_combo_counter()
	_build_kill_streak_banner()
	_init_label_pool()
	_init_particle_pool()
	_build_vignette_overlay()


# ── v11.0: Object Pool Initializers ──

func _init_label_pool() -> void:
	_label_pool.clear()
	for _i in range(LABEL_POOL_SIZE):
		var lbl := Label.new()
		lbl.visible = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.z_index = 100
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label_pool.append(lbl)


func _init_particle_pool() -> void:
	_particle_pool.clear()
	for _i in range(PARTICLE_POOL_SIZE):
		var p := ColorRect.new()
		p.visible = false
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.z_index = 80
		_particle_pool.append(p)


## Acquire a Label from the pool. Attaches to overlay_parent on first use.
func _acquire_label() -> Label:
	if overlay_parent == null:
		return Label.new()  # Fallback: unmanaged
	# Find next available (invisible) label in ring buffer
	for _i in range(LABEL_POOL_SIZE):
		_label_pool_idx = (_label_pool_idx + 1) % LABEL_POOL_SIZE
		var lbl: Label = _label_pool[_label_pool_idx]
		if not lbl.visible:
			if lbl.get_parent() == null:
				overlay_parent.add_child(lbl)
			return lbl
	# Pool exhausted: allocate a temporary one
	var fallback := Label.new()
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback.z_index = 100
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_parent.add_child(fallback)
	return fallback


## Acquire a ColorRect particle from the pool.
func _acquire_particle() -> ColorRect:
	if overlay_parent == null:
		return ColorRect.new()
	for _i in range(PARTICLE_POOL_SIZE):
		_particle_pool_idx = (_particle_pool_idx + 1) % PARTICLE_POOL_SIZE
		var p: ColorRect = _particle_pool[_particle_pool_idx]
		if not p.visible:
			if p.get_parent() == null:
				overlay_parent.add_child(p)
			return p
	# Fallback
	var fallback := ColorRect.new()
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback.z_index = 80
	overlay_parent.add_child(fallback)
	return fallback


## Return a pooled label to the pool (hide it, reset transforms).
func _release_label(lbl: Label) -> void:
	if not is_instance_valid(lbl): return
	lbl.visible = false
	lbl.modulate = Color.WHITE
	lbl.scale = Vector2.ONE
	lbl.position = Vector2.ZERO


## Return a pooled particle to the pool.
func _release_particle(p: ColorRect) -> void:
	if not is_instance_valid(p): return
	p.visible = false
	p.modulate = Color.WHITE
	p.scale = Vector2.ONE
	p.position = Vector2.ZERO


func _build_vignette_overlay() -> void:
	## Reusable full-screen vignette flash for crits.
	_vignette_overlay = ColorRect.new()
	_vignette_overlay.name = "VfxVignetteOverlay"
	_vignette_overlay.anchor_right = 1.0
	_vignette_overlay.anchor_bottom = 1.0
	_vignette_overlay.color = Color(1.0, 0.8, 0.1, 0.0)
	_vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_overlay.z_index = 70
	_vignette_overlay.visible = false
	add_child(_vignette_overlay)


func _process(delta: float) -> void:
	_process_screen_shake(delta)


# ═══════════════════════════════════════════════════════════
#                    SIGNAL CONNECTIONS
# ═══════════════════════════════════════════════════════════

func _connect_signals() -> void:
	EventBus.screen_shake_requested.connect(_on_screen_shake_requested)
	EventBus.camera_zoom_requested.connect(_on_camera_zoom_requested)
	EventBus.combo_chain_anim_requested.connect(_on_combo_chain_requested)
	EventBus.skill_vfx_requested.connect(_on_skill_vfx_requested)
	EventBus.formation_detected.connect(_on_formation_detected)
	EventBus.sfx_round_start.connect(_on_round_start)
	EventBus.sfx_buff_applied.connect(_on_buff_applied)
	EventBus.sfx_debuff_applied.connect(_on_debuff_applied)
	# v11.0: New signals
	if EventBus.has_signal("sfx_attack_miss"):
		EventBus.sfx_attack_miss.connect(_on_attack_miss)
	if EventBus.has_signal("sfx_combo_kill_streak"):
		EventBus.sfx_combo_kill_streak.connect(_on_combo_kill_streak)

# ═══════════════════════════════════════════════════════════
#                    1. SCREEN SHAKE SYSTEM
# ═══════════════════════════════════════════════════════════

func _on_screen_shake_requested(intensity: float, duration: float) -> void:
	start_screen_shake(intensity, duration)


## Start a sine-wave screen shake with exponential decay.
func start_screen_shake(intensity: float, duration: float) -> void:
	# Only override if new shake is stronger than remaining
	if intensity > _shake_intensity:
		_shake_intensity = intensity
		_shake_initial_intensity = intensity
	_shake_time_remaining = maxf(_shake_time_remaining, duration / maxf(speed_mult, 0.1))
	_shake_elapsed = 0.0


func _process_screen_shake(delta: float) -> void:
	if shake_target == null:
		return
	if _shake_time_remaining <= 0.0:
		if shake_target.position != Vector2.ZERO:
			shake_target.position = Vector2.ZERO
		_shake_intensity = 0.0
		return

	_shake_elapsed += delta
	_shake_time_remaining -= delta

	# Exponential decay envelope
	var decay_ratio: float = _shake_time_remaining / maxf(_shake_time_remaining + _shake_elapsed, 0.001)
	var current_intensity: float = _shake_initial_intensity * decay_ratio

	# Sine wave pattern for smooth oscillation
	var freq := _shake_frequency
	var offset_x: float = sin(_shake_elapsed * freq * TAU) * current_intensity
	var offset_y: float = cos(_shake_elapsed * freq * 0.7 * TAU) * current_intensity * 0.6

	shake_target.position = Vector2(offset_x, offset_y)
	_shake_intensity = current_intensity

	if _shake_time_remaining <= 0.0:
		shake_target.position = Vector2.ZERO
		_shake_intensity = 0.0

# ═══════════════════════════════════════════════════════════
#                    2. CAMERA ZOOM SYSTEM
# ═══════════════════════════════════════════════════════════

func _on_camera_zoom_requested(zoom_level: float, duration: float, target_pos: Vector2) -> void:
	start_camera_zoom(zoom_level, duration, target_pos)


## Smooth tween zoom toward a focal point, auto-return to 1.0.
func start_camera_zoom(zoom_level: float, duration: float, focal_pos: Vector2 = Vector2.ZERO) -> void:
	if shake_target == null or zoom_level <= 1.0:
		return
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_is_zooming = true

	# Use screen center if no focal point provided
	if focal_pos == Vector2.ZERO:
		focal_pos = Vector2(CENTER_X, SCREEN_H * 0.4)
	shake_target.pivot_offset = focal_pos

	var spd := maxf(speed_mult, 0.1)
	var push_time := duration * 0.3 / spd
	var hold_time := duration * 0.2 / spd
	var pull_time := duration * 0.5 / spd

	_zoom_tween = create_tween()
	_zoom_tween.tween_property(shake_target, "scale", Vector2(zoom_level, zoom_level), push_time) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_zoom_tween.tween_interval(hold_time)
	_zoom_tween.tween_property(shake_target, "scale", Vector2.ONE, pull_time) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_QUAD)
	_zoom_tween.finished.connect(func():
		_is_zooming = false
		if is_instance_valid(shake_target):
			shake_target.scale = Vector2.ONE
	)

# ═══════════════════════════════════════════════════════════
#                    3. DAMAGE NUMBER SYSTEM
# ═══════════════════════════════════════════════════════════

## v11.0: Spawn a floating damage number using the Label object pool.
## damage_type: "normal", "crit", "heal", "heavy", "block", "miss"
func spawn_damage_number(pos: Vector2, amount: int, damage_type: String = "normal") -> void:
	if overlay_parent == null:
		return

	var lbl := _acquire_label()
	var is_heal := damage_type == "heal"
	var prefix := "+" if is_heal else "-"
	var suffix := "!!" if damage_type == "crit" else ""
	if damage_type == "miss":
		lbl.text = "MISS"
	else:
		lbl.text = "%s%d%s" % [prefix, amount, suffix]

	# Color coding
	var color: Color
	var font_size: int
	match damage_type:
		"crit":
			color = DMG_COLOR_CRIT
			font_size = 28
		"heal":
			color = DMG_COLOR_HEAL
			font_size = 20
		"heavy":
			color = DMG_COLOR_HEAVY
			font_size = 22
		"block":
			color = DMG_COLOR_BLOCK
			font_size = 14
			lbl.text = "BLOCK"
		_:
			color = DMG_COLOR_NORMAL
			font_size = 16

	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.position = pos + Vector2(randf_range(-20, 20), -30)
	lbl.pivot_offset = Vector2(40, 12)
	lbl.modulate.a = 1.0
	lbl.scale = Vector2.ONE
	lbl.visible = true

	var spd := maxf(speed_mult, 0.1)
	var rise := -60.0 if damage_type == "crit" else (-20.0 if damage_type == "miss" else -40.0)
	var life := 0.9 / spd

	var tw := create_tween()
	if damage_type == "crit":
		# Crit: scale pulse 1.8x then settle, gold vignette flash
		tw.tween_property(lbl, "scale", Vector2(1.8, 1.8), 0.07 / spd)
		tw.tween_property(lbl, "scale", Vector2.ONE, 0.14 / spd) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.set_parallel(true)
		tw.tween_property(lbl, "position:y", lbl.position.y + rise, life) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(lbl, "modulate:a", 0.0, life * 0.9).set_delay(0.15 / spd)
		_flash_vignette(Color(1.0, 0.85, 0.1, 0.18), 0.12 / spd)
	elif damage_type == "miss":
		# Miss: drift sideways and fade quickly
		tw.set_parallel(true)
		tw.tween_property(lbl, "position", lbl.position + Vector2(randf_range(30, 60), -15), life * 0.7) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(lbl, "modulate:a", 0.0, life * 0.6).set_delay(0.05 / spd)
	else:
		tw.set_parallel(true)
		tw.tween_property(lbl, "position:y", lbl.position.y + rise, life) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(lbl, "modulate:a", 0.0, life * 0.85).set_delay(0.1 / spd)
	tw.chain().tween_callback(func():
		_release_label(lbl)
	)

# ═══════════════════════════════════════════════════════════
#                    4. COMBO CHAIN PLAYBACK
# ═══════════════════════════════════════════════════════════

func _on_combo_chain_requested(combo_id: String, hit_sequence: Array) -> void:
	if hit_sequence.is_empty() or _combo_chain_active:
		return
	_play_combo_chain(combo_id, hit_sequence)


## Play a sequential combo chain with per-hit VFX, shake, and counter display.
func _play_combo_chain(combo_id: String, hit_chain: Array) -> void:
	_combo_chain_active = true
	_combo_hit_index = 0

	# Show combo name from SkillAnimationData
	var combo_data: Dictionary = SkillAnimationData.get_combo_animation(combo_id)
	var combo_name: String = combo_data.get("name_cn", combo_id)
	_show_combo_name_banner(combo_name)

	# Process each hit step sequentially
	_process_next_combo_hit(hit_chain)


func _process_next_combo_hit(hit_chain: Array) -> void:
	if _combo_hit_index >= hit_chain.size():
		_combo_chain_active = false
		_hide_combo_counter()
		return

	var hit: Dictionary = hit_chain[_combo_hit_index]
	var delay_before: float = hit.get("delay_before", 0.1)
	var shake_mult: float = hit.get("screen_shake_mult", 1.0)
	var flash_color: Color = hit.get("flash_color", Color.WHITE)
	var particle_count: int = hit.get("particle_count", 6)

	_combo_hit_index += 1

	# Update combo counter display
	_update_combo_counter(_combo_hit_index)

	# Schedule this hit after its delay
	var spd := maxf(speed_mult, 0.1)
	var tw := create_tween()
	tw.tween_interval(delay_before / spd)
	tw.tween_callback(func():
		# Screen shake for this hit
		var base_shake := SHAKE_MEDIUM
		start_screen_shake(base_shake * shake_mult, 0.15)

		# Flash burst
		_spawn_hit_flash(flash_color)

		# Spawn particles at screen center (combo effects are screen-wide)
		_spawn_combo_particles(flash_color, particle_count)

		# Continue to next hit
		_process_next_combo_hit(hit_chain)
	)


func _show_combo_name_banner(combo_name: String) -> void:
	if overlay_parent == null:
		return
	var lbl := Label.new()
	lbl.text = combo_name
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.position = Vector2(CENTER_X - 120, SCREEN_H * 0.25)
	lbl.size = Vector2(240, 44)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 90
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.modulate.a = 0.0
	lbl.pivot_offset = Vector2(120, 22)
	overlay_parent.add_child(lbl)

	var spd := maxf(speed_mult, 0.1)
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.12 / spd)
	tw.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.08 / spd)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.1 / spd) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(1.0 / spd)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.3 / spd)
	tw.finished.connect(func():
		if is_instance_valid(lbl): lbl.queue_free()
	)


func _update_combo_counter(hit_num: int) -> void:
	if _combo_counter_label == null:
		return
	_combo_counter_label.text = "HIT %d" % hit_num
	_combo_counter_label.visible = true
	_combo_counter_label.modulate.a = 1.0

	# Pulse effect
	_combo_counter_label.scale = Vector2(1.3, 1.3)
	var tw := create_tween()
	tw.tween_property(_combo_counter_label, "scale", Vector2.ONE, 0.15) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _hide_combo_counter() -> void:
	if _combo_counter_label == null:
		return
	var tw := create_tween()
	tw.tween_interval(0.5 / maxf(speed_mult, 0.1))
	tw.tween_property(_combo_counter_label, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		if is_instance_valid(_combo_counter_label):
			_combo_counter_label.visible = false
	)


func _spawn_hit_flash(color: Color) -> void:
	if root_control == null:
		return
	var flash := ColorRect.new()
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	flash.color = Color(color.r, color.g, color.b, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 75
	root_control.add_child(flash)

	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.25, 0.04)
	tw.tween_property(flash, "color:a", 0.0, 0.1)
	tw.tween_callback(func():
		if is_instance_valid(flash): flash.queue_free()
	)


## v11.0: Reusable vignette flash for crits (no node allocation).
func _flash_vignette(color: Color, duration: float) -> void:
	if _vignette_overlay == null: return
	_vignette_overlay.color = Color(color.r, color.g, color.b, 0.0)
	_vignette_overlay.visible = true
	var tw := create_tween()
	tw.tween_property(_vignette_overlay, "color:a", color.a, duration * 0.3)
	tw.tween_property(_vignette_overlay, "color:a", 0.0, duration * 0.7)
	tw.tween_callback(func(): if is_instance_valid(_vignette_overlay): _vignette_overlay.visible = false)


## v11.0: Pooled combo particles.
func _spawn_combo_particles(color: Color, count: int) -> void:
	if overlay_parent == null:
		return
	var origin := Vector2(CENTER_X, SCREEN_H * 0.4)
	for _i in range(count):
		var p := _acquire_particle()
		var sz := randf_range(3.0, 6.0)
		p.size = Vector2(sz, sz)
		p.color = color
		p.pivot_offset = Vector2(sz / 2.0, sz / 2.0)
		p.position = origin + Vector2(randf_range(-30, 30), randf_range(-20, 20))
		p.modulate.a = 1.0
		p.scale = Vector2.ONE
		p.visible = true

		var angle := randf() * TAU
		var dist := randf_range(40.0, 100.0)
		var dest := p.position + Vector2(cos(angle), sin(angle)) * dist
		var life := randf_range(0.3, 0.6) / maxf(speed_mult, 0.1)

		var ptw := create_tween()
		ptw.set_parallel(true)
		ptw.tween_property(p, "position", dest, life) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.tween_property(p, "modulate:a", 0.0, life * 0.8).set_delay(life * 0.2)
		ptw.tween_property(p, "scale", Vector2.ZERO, life)
		ptw.chain().tween_callback(func():
			_release_particle(p)
		)

# ═══════════════════════════════════════════════════════════
#                    5. ROUND TRANSITION BANNER
# ═══════════════════════════════════════════════════════════

func _on_round_start(round_num: int) -> void:
	show_round_banner(round_num)


## Slide-in "ROUND X" banner between rounds.
func show_round_banner(round_num: int) -> void:
	if _round_banner == null or _round_banner_label == null:
		return
	_round_banner_label.text = "  ROUND %d  " % round_num
	_round_banner.visible = true
	_round_banner.modulate = Color(1, 1, 1, 0)
	_round_banner.position.x = -400.0  # Start off-screen left

	var spd := maxf(speed_mult, 0.1)
	var tw := create_tween()
	# Slide in from left
	tw.set_parallel(true)
	tw.tween_property(_round_banner, "position:x", CENTER_X - 150, 0.25 / spd) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(_round_banner, "modulate:a", 1.0, 0.15 / spd)
	# Hold
	tw.chain().tween_interval(0.6 / spd)
	# Slide out to right
	tw.tween_property(_round_banner, "position:x", SCREEN_W + 100, 0.25 / spd) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(_round_banner, "modulate:a", 0.0, 0.2 / spd)
	tw.tween_callback(func():
		if is_instance_valid(_round_banner):
			_round_banner.visible = false
	)

# ═══════════════════════════════════════════════════════════
#                    6. BUFF/DEBUFF VISUAL INDICATORS
# ═══════════════════════════════════════════════════════════

func _on_buff_applied(side: String, slot: int, buff_type: String) -> void:
	_show_buff_indicator(side, slot, buff_type, true)


func _on_debuff_applied(side: String, slot: int, debuff_type: String) -> void:
	_show_buff_indicator(side, slot, debuff_type, false)


## Show a buff/debuff icon overlay on the unit card with pulse animation.
func _show_buff_indicator(side: String, slot: int, effect_type: String, is_buff: bool) -> void:
	if overlay_parent == null or not _get_card_center_fn.is_valid():
		return

	var pos: Vector2 = _get_card_center_fn.call(side, slot)
	if pos == Vector2.ZERO:
		return

	# Create icon overlay
	var indicator := ColorRect.new()
	var sz := 16.0
	indicator.size = Vector2(sz, sz)
	indicator.pivot_offset = Vector2(sz / 2.0, sz / 2.0)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.z_index = 85

	# Color: blue-ish for buff, red-ish for debuff
	if is_buff:
		indicator.color = Color(0.3, 0.6, 1.0, 0.85)
	else:
		indicator.color = Color(1.0, 0.3, 0.2, 0.85)

	# Position above the card, stacked horizontally
	if not _buff_overlays[side].has(slot):
		_buff_overlays[side][slot] = []
	var stack_offset: float = _buff_overlays[side][slot].size() * 18.0
	indicator.position = pos + Vector2(-40 + stack_offset, -60)
	overlay_parent.add_child(indicator)
	_buff_overlays[side][slot].append(indicator)

	# Label inside the indicator
	var lbl := Label.new()
	lbl.text = _get_buff_symbol(effect_type)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(sz, sz)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.add_child(lbl)

	# Pulse animation on appear
	indicator.scale = Vector2(0.3, 0.3)
	indicator.modulate.a = 0.0
	var spd := maxf(speed_mult, 0.1)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(indicator, "scale", Vector2(1.2, 1.2), 0.12 / spd) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(indicator, "modulate:a", 1.0, 0.1 / spd)
	tw.chain().tween_property(indicator, "scale", Vector2.ONE, 0.08 / spd)

	# Auto-fade after duration
	var fade_tw := create_tween()
	fade_tw.tween_interval(3.0 / spd)
	fade_tw.tween_property(indicator, "modulate:a", 0.0, 0.4 / spd)
	fade_tw.tween_callback(func():
		if is_instance_valid(indicator):
			indicator.queue_free()
		if _buff_overlays.has(side) and _buff_overlays[side].has(slot):
			_buff_overlays[side][slot].erase(indicator)
	)


func _get_buff_symbol(effect_type: String) -> String:
	match effect_type:
		"atk_up", "attack", "atk": return "A"
		"def_up", "defense", "def": return "D"
		"morale_up", "morale": return "M"
		"heal", "regen": return "H"
		"poison": return "P"
		"burn": return "F"
		"stun": return "S"
		"slow", "spd_down", "spd": return "W"
		"shield", "barrier": return "G"
		"cleanse": return "C"
		"atk_down": return "a"
		"def_down": return "d"
		_: return "+"

# ═══════════════════════════════════════════════════════════
#                    7. CRITICAL HIT INDICATOR
# ═══════════════════════════════════════════════════════════

## Spawn a gold sparkle burst and brief hit-freeze for critical hits.
func show_crit_indicator(pos: Vector2) -> void:
	if overlay_parent == null:
		return

	# v11.0: Gold sparkle burst using particle pool + gold ring expansion
	var sparkle_colors := [
		Color(1.0, 0.9, 0.2),
		Color(1.0, 1.0, 0.5),
		Color(1.0, 0.8, 0.1),
		Color(1.0, 0.95, 0.7),
	]

	for i in range(12):
		var p := _acquire_particle()
		var sz := randf_range(2.0, 5.0)
		p.size = Vector2(sz, sz)
		p.color = sparkle_colors[i % sparkle_colors.size()]
		p.pivot_offset = Vector2(sz / 2.0, sz / 2.0)
		p.z_index = 95
		p.position = pos + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		p.modulate.a = 1.0
		p.scale = Vector2.ONE
		p.visible = true

		var angle := randf() * TAU
		var dist := randf_range(25.0, 75.0)
		var dest := p.position + Vector2(cos(angle), sin(angle)) * dist
		var life := randf_range(0.25, 0.5) / maxf(speed_mult, 0.1)

		var ptw := create_tween()
		ptw.set_parallel(true)
		ptw.tween_property(p, "position", dest, life) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.tween_property(p, "modulate:a", 0.0, life * 0.7).set_delay(life * 0.3)
		ptw.tween_property(p, "scale", Vector2(0.2, 0.2), life)
		ptw.chain().tween_callback(func():
			_release_particle(p)
		)

	# v11.0: Gold ring expansion (reuses a particle as a ring outline)
	_spawn_crit_ring(pos)

	# Hit-freeze: brief 0.05s engine pause effect via tween delay
	_do_hit_freeze(0.05)


## v11.0: Expanding gold ring for crit impact.
func _spawn_crit_ring(pos: Vector2) -> void:
	if overlay_parent == null: return
	var ring := ColorRect.new()
	ring.size = Vector2(8, 8)
	ring.color = Color(1.0, 0.9, 0.2, 0.9)
	ring.pivot_offset = Vector2(4, 4)
	ring.position = pos - Vector2(4, 4)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 96
	overlay_parent.add_child(ring)
	var spd := maxf(speed_mult, 0.1)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(8, 8), 0.35 / spd).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(ring, "modulate:a", 0.0, 0.35 / spd).set_delay(0.05 / spd)
	tw.chain().tween_callback(func(): if is_instance_valid(ring): ring.queue_free())


## Brief hit-freeze (pause) to emphasize impact. Resumes automatically.
func _do_hit_freeze(duration: float) -> void:
	var tree := get_tree()
	if tree == null:
		return
	# Use time scale for a micro-pause
	var original_scale: float = Engine.time_scale
	Engine.time_scale = 0.05
	var tw := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_interval(duration)
	tw.tween_callback(func():
		Engine.time_scale = original_scale
	)

# ═══════════════════════════════════════════════════════════
#                    8. FORMATION BANNER
# ═══════════════════════════════════════════════════════════

func _on_formation_detected(side: String, _formation_id: int, formation_name: String) -> void:
	show_formation_banner(side, formation_name)


## Show a formation name banner that slides in briefly.
func show_formation_banner(side: String, formation_name: String) -> void:
	if _formation_banner == null or _formation_label == null:
		return

	var side_label := "ATK" if side == "attacker" else "DEF"
	_formation_label.text = "  [%s] %s  " % [side_label, formation_name]

	# Color based on side
	if side == "attacker":
		_formation_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
	else:
		_formation_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))

	_formation_banner.visible = true
	_formation_banner.modulate = Color(1, 1, 1, 0)
	_formation_banner.position = Vector2(CENTER_X - 140, SCREEN_H * 0.22)
	_formation_banner.scale = Vector2(0.8, 0.8)
	_formation_banner.pivot_offset = Vector2(140, 18)

	var spd := maxf(speed_mult, 0.1)
	var tw := create_tween()
	# Pop in
	tw.set_parallel(true)
	tw.tween_property(_formation_banner, "modulate:a", 1.0, 0.15 / spd)
	tw.tween_property(_formation_banner, "scale", Vector2(1.05, 1.05), 0.15 / spd) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Settle
	tw.chain().tween_property(_formation_banner, "scale", Vector2.ONE, 0.08 / spd)
	# Hold
	tw.tween_interval(1.2 / spd)
	# Fade out
	tw.tween_property(_formation_banner, "modulate:a", 0.0, 0.3 / spd)
	tw.tween_callback(func():
		if is_instance_valid(_formation_banner):
			_formation_banner.visible = false
	)


## Handler for skill_vfx_requested — spawn particles at target with skill color.
## v11.0: Pooled skill VFX particles.
func _on_skill_vfx_requested(skill_id: String, _vfx_type: String, _source_pos: Vector2, target_pos: Vector2) -> void:
	if overlay_parent == null:
		return
	var color: Color = SkillAnimationData.get_skill_color(skill_id)
	var cfg: Dictionary = SkillAnimationData.get_skill_vfx(skill_id)
	var particle_count: int = cfg.get("particle_count", 6)

	# Spawn pooled particles at target position
	for _i in range(particle_count):
		var p := _acquire_particle()
		var sz := randf_range(2.0, 6.0)
		p.size = Vector2(sz, sz)
		p.color = color
		p.pivot_offset = Vector2(sz / 2.0, sz / 2.0)
		p.z_index = 80
		p.position = target_pos + Vector2(randf_range(-20, 20), randf_range(-15, 15))
		p.modulate.a = 1.0
		p.scale = Vector2.ONE
		p.visible = true

		var angle := randf() * TAU
		var dist := randf_range(30.0, 80.0)
		var dest := p.position + Vector2(cos(angle), sin(angle)) * dist
		var life := randf_range(0.3, 0.6) / maxf(speed_mult, 0.1)

		var ptw := create_tween()
		ptw.set_parallel(true)
		ptw.tween_property(p, "position", dest, life) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.tween_property(p, "modulate:a", 0.0, life * 0.7).set_delay(life * 0.3)
		ptw.tween_property(p, "scale", Vector2.ZERO, life)
		ptw.chain().tween_callback(func():
			_release_particle(p)
		)

	# Color flash for AoE skills
	if cfg.get("aoe", false):
		_spawn_hit_flash(color)

# ═══════════════════════════════════════════════════════════
#                    UI BUILDER HELPERS
# ═══════════════════════════════════════════════════════════

func _build_formation_banner() -> void:
	_formation_banner = PanelContainer.new()
	_formation_banner.name = "VfxFormationBanner"
	_formation_banner.position = Vector2(CENTER_X - 140, SCREEN_H * 0.22)
	_formation_banner.size = Vector2(280, 36)
	_formation_banner.visible = false
	_formation_banner.z_index = 88
	_formation_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.15, 0.92)
	style.border_color = Color(0.7, 0.55, 0.25, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	_formation_banner.add_theme_stylebox_override("panel", style)
	add_child(_formation_banner)

	_formation_label = Label.new()
	_formation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_formation_label.add_theme_font_size_override("font_size", 18)
	_formation_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_formation_label.add_theme_constant_override("outline_size", 2)
	_formation_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_formation_banner.add_child(_formation_label)


func _build_round_banner() -> void:
	_round_banner = PanelContainer.new()
	_round_banner.name = "VfxRoundBanner"
	_round_banner.position = Vector2(CENTER_X - 150, SCREEN_H * 0.38)
	_round_banner.size = Vector2(300, 48)
	_round_banner.visible = false
	_round_banner.z_index = 92
	_round_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.07, 0.04, 0.94)
	style.border_color = Color(0.85, 0.65, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_round_banner.add_theme_stylebox_override("panel", style)
	add_child(_round_banner)

	_round_banner_label = Label.new()
	_round_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_round_banner_label.add_theme_font_size_override("font_size", 28)
	_round_banner_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
	_round_banner_label.add_theme_constant_override("outline_size", 3)
	_round_banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_round_banner.add_child(_round_banner_label)


func _build_combo_counter() -> void:
	_combo_counter_label = Label.new()
	_combo_counter_label.name = "VfxComboCounter"
	_combo_counter_label.text = "HIT 1"
	_combo_counter_label.position = Vector2(CENTER_X - 60, SCREEN_H * 0.32)
	_combo_counter_label.size = Vector2(120, 36)
	_combo_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_counter_label.add_theme_font_size_override("font_size", 24)
	_combo_counter_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	_combo_counter_label.add_theme_constant_override("outline_size", 3)
	_combo_counter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_combo_counter_label.z_index = 91
	_combo_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_counter_label.visible = false
	_combo_counter_label.pivot_offset = Vector2(60, 18)
	add_child(_combo_counter_label)

# ═══════════════════════════════════════════════════════════
#                    CLEANUP
# ═══════════════════════════════════════════════════════════

func cleanup() -> void:
	_shake_time_remaining = 0.0
	_shake_intensity = 0.0
	_combo_chain_active = false
	_kill_streak_count = 0
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_is_zooming = false
	# Clear buff overlays
	for side in _buff_overlays:
		for slot in _buff_overlays[side]:
			for ctrl in _buff_overlays[side][slot]:
				if is_instance_valid(ctrl):
					ctrl.queue_free()
		_buff_overlays[side] = {}
	# v11.0: Return all pooled nodes to hidden state
	for lbl in _label_pool:
		if is_instance_valid(lbl): _release_label(lbl)
	for p in _particle_pool:
		if is_instance_valid(p): _release_particle(p)


# ═══════════════════════════════════════════════════════════
#              9. MISS / DODGE INDICATOR (v11.0)
# ═══════════════════════════════════════════════════════════

## Show a "MISS" floating label at the target's screen position.
func _on_attack_miss(side: String, slot: int) -> void:
	if not _get_card_center_fn.is_valid(): return
	var pos: Vector2 = _get_card_center_fn.call(side, slot)
	if pos == Vector2.ZERO: return
	spawn_damage_number(pos, 0, "miss")


# ═══════════════════════════════════════════════════════════
#             10. COMBO KILL STREAK BANNER (v11.0)
# ═══════════════════════════════════════════════════════════

func _build_kill_streak_banner() -> void:
	_kill_streak_banner = Label.new()
	_kill_streak_banner.name = "VfxKillStreakBanner"
	_kill_streak_banner.text = "COMBO KILL!"
	_kill_streak_banner.position = Vector2(CENTER_X - 100, SCREEN_H * 0.15)
	_kill_streak_banner.size = Vector2(200, 44)
	_kill_streak_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kill_streak_banner.add_theme_font_size_override("font_size", 30)
	_kill_streak_banner.add_theme_color_override("font_color", Color(1.0, 0.4, 0.1))
	_kill_streak_banner.add_theme_constant_override("outline_size", 4)
	_kill_streak_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_kill_streak_banner.z_index = 93
	_kill_streak_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kill_streak_banner.visible = false
	_kill_streak_banner.pivot_offset = Vector2(100, 22)
	add_child(_kill_streak_banner)


## Triggered when attacker kills >= COMBO_KILL_THRESHOLD units in one round.
func _on_combo_kill_streak(kill_count: int) -> void:
	_kill_streak_count = kill_count
	_show_kill_streak_banner(kill_count)


func _show_kill_streak_banner(kill_count: int) -> void:
	if _kill_streak_banner == null: return
	_kill_streak_banner.text = "%d COMBO KILL!" % kill_count if kill_count > 2 else "COMBO KILL!"
	_kill_streak_banner.visible = true
	_kill_streak_banner.modulate.a = 0.0
	_kill_streak_banner.scale = Vector2(0.5, 0.5)

	var spd := maxf(speed_mult, 0.1)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_kill_streak_banner, "modulate:a", 1.0, 0.1 / spd)
	tw.tween_property(_kill_streak_banner, "scale", Vector2(1.2, 1.2), 0.12 / spd) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.chain().tween_property(_kill_streak_banner, "scale", Vector2.ONE, 0.08 / spd)
	tw.tween_interval(1.0 / spd)
	tw.tween_property(_kill_streak_banner, "modulate:a", 0.0, 0.3 / spd)
	tw.tween_callback(func():
		if is_instance_valid(_kill_streak_banner): _kill_streak_banner.visible = false
	)
	start_screen_shake(SHAKE_MEDIUM, 0.25)
