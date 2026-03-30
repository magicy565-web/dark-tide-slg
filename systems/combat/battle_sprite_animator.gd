class_name BattleSpriteAnimator
## Programmatic battle animation system for pixel art sprites (方案A).
## Attach to a Sprite2D node. Provides 5 battle actions via Tween:
##   attack, hit, defeat, skill, victory
## Inspired by Sengoku Rance's single-sprite + code animation approach.
##
## Usage:
##   var anim = BattleSpriteAnimator.new()
##   sprite.add_child(anim)
##   anim.play_attack(target_global_pos)

extends Node

# ── Signals ──
signal animation_finished(anim_name: String)

# ── Configuration ──
@export var attack_lunge_distance: float = 40.0
@export var attack_rotation_deg: float = 15.0
@export var attack_duration: float = 0.35
@export var hit_shake_intensity: float = 6.0
@export var hit_flash_count: int = 3
@export var hit_duration: float = 0.3
@export var defeat_duration: float = 0.8
@export var skill_scale_peak: float = 1.3
@export var skill_duration: float = 0.6
@export var victory_bounce_height: float = 12.0
@export var victory_duration: float = 0.8

# ── Internal state ──
var _sprite: Sprite2D = null
var _origin_pos: Vector2 = Vector2.ZERO
var _origin_rotation: float = 0.0
var _origin_scale: Vector2 = Vector2.ONE
var _origin_modulate: Color = Color.WHITE
var _active_tween: Tween = null
var _is_animating: bool = false
var _is_defeated: bool = false

# ── Shader for flash/grayscale effects ──
var _flash_material: ShaderMaterial = null
var _grayscale_material: ShaderMaterial = null

# Particle container (optional, for skill/victory sparkles)
var _particle_parent: Node2D = null

func _ready() -> void:
	if get_parent() is Sprite2D:
		_sprite = get_parent() as Sprite2D
	else:
		push_warning("BattleSpriteAnimator: parent is not Sprite2D")
		return

	_origin_pos = _sprite.position
	_origin_rotation = _sprite.rotation
	_origin_scale = _sprite.scale
	_origin_modulate = _sprite.modulate

	_setup_shaders()

func _setup_shaders() -> void:
	# White flash shader
	var flash_code := """
shader_type canvas_item;
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = mix(tex, vec4(flash_color.rgb, tex.a), flash_amount);
}
"""
	var flash_shader := Shader.new()
	flash_shader.code = flash_code
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = flash_shader
	_flash_material.set_shader_parameter("flash_amount", 0.0)
	_flash_material.set_shader_parameter("flash_color", Color.WHITE)

	# Grayscale shader (for defeat)
	var gray_code := """
shader_type canvas_item;
uniform float gray_amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(tex.rgb, vec3(gray), gray_amount), tex.a);
}
"""
	var gray_shader := Shader.new()
	gray_shader.code = gray_code
	_grayscale_material = ShaderMaterial.new()
	_grayscale_material.shader = gray_shader
	_grayscale_material.set_shader_parameter("gray_amount", 0.0)

# ── Public API ──

## Idle breathing animation (subtle scale pulse, runs continuously)
func play_idle() -> void:
	if _is_defeated or _sprite == null:
		return
	_kill_active_tween()
	var tw := _create_tween().set_loops()
	tw.tween_property(_sprite, "scale", _origin_scale * 1.02, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_sprite, "scale", _origin_scale, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_active_tween = tw

## Attack: lunge toward target, rotate weapon swing, snap back.
func play_attack(target_global_pos: Vector2 = Vector2.ZERO) -> void:
	if _is_defeated or _sprite == null:
		return
	_kill_active_tween()
	_is_animating = true

	# Calculate lunge direction
	var dir := Vector2.RIGHT
	if target_global_pos != Vector2.ZERO:
		dir = (target_global_pos - _sprite.global_position).normalized()
	var lunge_offset := dir * attack_lunge_distance
	var rot_dir := 1.0 if dir.x >= 0 else -1.0
	var rot_rad := deg_to_rad(attack_rotation_deg) * rot_dir

	var t := attack_duration
	var tw := _create_tween()

	# Phase 1: Wind up (pull back slightly + rotate)
	tw.tween_property(_sprite, "position", _origin_pos - lunge_offset * 0.2, t * 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_sprite, "rotation", _origin_rotation - rot_rad * 0.5, t * 0.15)

	# Phase 2: Lunge forward + swing
	tw.tween_property(_sprite, "position", _origin_pos + lunge_offset, t * 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_sprite, "rotation", _origin_rotation + rot_rad, t * 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Phase 3: Hold briefly at peak
	tw.tween_interval(t * 0.1)

	# Phase 4: Snap back to origin
	tw.tween_property(_sprite, "position", _origin_pos, t * 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_sprite, "rotation", _origin_rotation, t * 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Phase 5: Small overshoot bounce
	tw.tween_property(_sprite, "position", _origin_pos - lunge_offset * 0.05, t * 0.08)
	tw.tween_property(_sprite, "position", _origin_pos, t * 0.07)

	tw.finished.connect(func(): _on_anim_done("attack"))
	_active_tween = tw

## Hit: flash white + shake (called on the unit receiving damage).
func play_hit(damage_ratio: float = 0.3) -> void:
	if _is_defeated or _sprite == null:
		return
	_kill_active_tween()
	_is_animating = true

	# Intensity scales with damage ratio
	var shake := hit_shake_intensity * clampf(damage_ratio * 2.0, 0.5, 2.0)
	var flashes := hit_flash_count
	var t := hit_duration

	# Apply flash shader
	_sprite.material = _flash_material

	var tw := _create_tween()

	# Flash white + shake simultaneously
	var flash_time := t / float(flashes * 2)
	for i in range(flashes):
		# Flash on
		tw.tween_method(_set_flash_amount, 0.0, 0.85, flash_time * 0.4)
		# Shake offset
		var shake_offset := Vector2(randf_range(-shake, shake), randf_range(-shake * 0.5, shake * 0.5))
		tw.parallel().tween_property(_sprite, "position", _origin_pos + shake_offset, flash_time * 0.4) \
			.set_trans(Tween.TRANS_QUAD)
		# Flash off
		tw.tween_method(_set_flash_amount, 0.85, 0.0, flash_time * 0.6)
		tw.parallel().tween_property(_sprite, "position", _origin_pos, flash_time * 0.6)

	# Brief red tint at end for heavy hits
	if damage_ratio > 0.4:
		_flash_material.set_shader_parameter("flash_color", Color(1.0, 0.3, 0.3, 1.0))
		tw.tween_method(_set_flash_amount, 0.0, 0.5, 0.08)
		tw.tween_method(_set_flash_amount, 0.5, 0.0, 0.12)
		tw.tween_callback(func(): _flash_material.set_shader_parameter("flash_color", Color.WHITE))

	# Ensure we return to origin
	tw.tween_property(_sprite, "position", _origin_pos, 0.05)
	tw.tween_callback(func(): _sprite.material = null)
	tw.finished.connect(func(): _on_anim_done("hit"))
	_active_tween = tw

## Block: shield flash + slight pushback (DEF > ATK scenario).
func play_block() -> void:
	if _is_defeated or _sprite == null:
		return
	_kill_active_tween()
	_is_animating = true

	var tw := _create_tween()
	# Slight pushback
	var push_back := _origin_pos + Vector2(0, -3.0)
	tw.tween_property(_sprite, "position", push_back, 0.06) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Shield flash (bright white-blue burst)
	_sprite.material = _flash_material
	_flash_material.set_shader_parameter("flash_color", Color(0.7, 0.85, 1.0, 1.0))
	tw.parallel().tween_method(_set_flash_amount, 0.0, 0.7, 0.06)
	tw.tween_method(_set_flash_amount, 0.7, 0.0, 0.12)

	# Return to origin with a firm settle
	tw.tween_property(_sprite, "position", _origin_pos, 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _sprite.material = null)

	# Spawn shield particle burst
	tw.tween_callback(func(): _spawn_block_particles())
	tw.finished.connect(func(): _on_anim_done("block"))
	_active_tween = tw

## Dodge: sidestep evasion (high SPD / ninja units).
func play_dodge(dodge_right: bool = true) -> void:
	if _is_defeated or _sprite == null:
		return
	_kill_active_tween()
	_is_animating = true

	var dodge_dir := 1.0 if dodge_right else -1.0
	var dodge_offset := Vector2(dodge_dir * 25.0, -8.0)
	var tw := _create_tween()

	# Quick sidestep
	tw.tween_property(_sprite, "position", _origin_pos + dodge_offset, 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Brief transparency (afterimage feel)
	tw.parallel().tween_property(_sprite, "modulate:a", 0.4, 0.08)

	# Hold
	tw.tween_interval(0.06)

	# Slide back to origin
	tw.tween_property(_sprite, "position", _origin_pos, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(_sprite, "modulate:a", 1.0, 0.14)

	tw.finished.connect(func(): _on_anim_done("dodge"))
	_active_tween = tw

## Dispatcher: pick the appropriate defender reaction based on context.
## reaction: "hit", "block", "dodge"
func play_hit_reaction(reaction: String = "hit", damage_ratio: float = 0.3) -> void:
	match reaction:
		"block":
			play_block()
		"dodge":
			play_dodge()
		_:
			play_hit(damage_ratio)

## Defeat: grayscale desaturation + fall + fade out.
func play_defeat() -> void:
	if _sprite == null:
		return
	_kill_active_tween()
	_is_animating = true
	_is_defeated = true

	var t := defeat_duration

	var tw := _create_tween()

	# Phase 1: Flash red briefly (death blow impact)
	_sprite.material = _flash_material
	_flash_material.set_shader_parameter("flash_color", Color(1.0, 0.2, 0.2, 1.0))
	tw.tween_method(_set_flash_amount, 0.0, 0.9, t * 0.1)
	tw.tween_method(_set_flash_amount, 0.9, 0.0, t * 0.1)

	# Switch to grayscale
	tw.tween_callback(func(): _sprite.material = _grayscale_material)

	# Phase 2: Desaturate to gray
	tw.tween_method(_set_gray_amount, 0.0, 1.0, t * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Phase 3: Tilt and fall
	var fall_dir := 1.0 if randf() > 0.5 else -1.0
	tw.parallel().tween_property(_sprite, "rotation", _origin_rotation + deg_to_rad(45.0 * fall_dir), t * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_sprite, "position", _origin_pos + Vector2(10.0 * fall_dir, 20.0), t * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Phase 4: Fade out
	tw.tween_property(_sprite, "modulate:a", 0.0, t * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tw.finished.connect(func(): _on_anim_done("defeat"))
	_active_tween = tw

## Skill: scale pulse + color burst + screen flash feel.
func play_skill(skill_color: Color = Color(0.6, 0.3, 1.0)) -> void:
	if _is_defeated or _sprite == null:
		return
	_kill_active_tween()
	_is_animating = true

	var t := skill_duration
	var peak_scale := _origin_scale * skill_scale_peak

	# Apply flash shader for color burst
	_sprite.material = _flash_material
	_flash_material.set_shader_parameter("flash_color", skill_color)

	var tw := _create_tween()

	# Phase 1: Charge up (subtle shrink + darken)
	tw.tween_property(_sprite, "scale", _origin_scale * 0.92, t * 0.15) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(_set_flash_amount, 0.0, 0.3, t * 0.15)

	# Phase 2: Burst outward (scale up + color flash)
	tw.tween_property(_sprite, "scale", peak_scale, t * 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_set_flash_amount, 0.3, 0.7, t * 0.12)

	# Phase 3: Hold at peak with pulsing glow
	tw.tween_method(_set_flash_amount, 0.7, 0.4, t * 0.15)
	tw.tween_method(_set_flash_amount, 0.4, 0.6, t * 0.1)

	# Spawn sparkle particles at peak
	tw.tween_callback(func(): _spawn_skill_particles(skill_color))

	# Phase 4: Release (scale back + fade color)
	tw.tween_property(_sprite, "scale", _origin_scale, t * 0.25) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_set_flash_amount, 0.6, 0.0, t * 0.25)

	# Phase 5: Small bounce settle
	tw.tween_property(_sprite, "scale", _origin_scale * 1.04, t * 0.1)
	tw.tween_property(_sprite, "scale", _origin_scale, t * 0.08)

	tw.tween_callback(func(): _sprite.material = null)
	tw.finished.connect(func(): _on_anim_done("skill"))
	_active_tween = tw

## Victory: joyful bounce + sparkle particles.
func play_victory() -> void:
	if _is_defeated or _sprite == null:
		return
	_kill_active_tween()
	_is_animating = true

	var t := victory_duration
	var tw := _create_tween()

	# Bounce sequence (3 bounces, decreasing height)
	for i in range(3):
		var height := victory_bounce_height * (1.0 - float(i) * 0.3)
		var bounce_t := t * 0.22 * (1.0 - float(i) * 0.15)

		# Up
		tw.tween_property(_sprite, "position:y", _origin_pos.y - height, bounce_t * 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Slight squash at peak
		tw.parallel().tween_property(_sprite, "scale", Vector2(_origin_scale.x * 0.95, _origin_scale.y * 1.08), bounce_t * 0.45)

		# Down
		tw.tween_property(_sprite, "position:y", _origin_pos.y, bounce_t * 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Landing squash
		tw.parallel().tween_property(_sprite, "scale", Vector2(_origin_scale.x * 1.08, _origin_scale.y * 0.92), bounce_t * 0.2)
		tw.tween_property(_sprite, "scale", _origin_scale, bounce_t * 0.15)

		# Spawn sparkles on landing
		if i == 0:
			tw.tween_callback(func(): _spawn_victory_sparkles())

	# Final settle
	tw.tween_property(_sprite, "position", _origin_pos, t * 0.1)
	tw.tween_property(_sprite, "scale", _origin_scale, t * 0.05)

	tw.finished.connect(func(): _on_anim_done("victory"))
	_active_tween = tw

## Reset sprite to original state (useful between battles).
func reset() -> void:
	_kill_active_tween()
	if _sprite:
		_sprite.position = _origin_pos
		_sprite.rotation = _origin_rotation
		_sprite.scale = _origin_scale
		_sprite.modulate = _origin_modulate
		_sprite.material = null
	_is_animating = false
	_is_defeated = false

## Check if any animation is currently playing.
func is_animating() -> bool:
	return _is_animating

## Update the origin position (call after repositioning the sprite).
func set_origin(pos: Vector2) -> void:
	_origin_pos = pos

# ── Private helpers ──

func _create_tween() -> Tween:
	return _sprite.create_tween()

func _kill_active_tween() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
	if _flash_material:
		_flash_material.set_shader_parameter("flash_color", Color.WHITE)
		_flash_material.set_shader_parameter("flash_amount", 0.0)
	if _sprite and not _is_defeated:
		_sprite.material = null

func _on_anim_done(anim_name: String) -> void:
	_is_animating = false
	animation_finished.emit(anim_name)

func _set_flash_amount(value: float) -> void:
	if _flash_material:
		_flash_material.set_shader_parameter("flash_amount", value)

func _set_gray_amount(value: float) -> void:
	if _grayscale_material:
		_grayscale_material.set_shader_parameter("gray_amount", value)

## Spawn colorful particles for skill activation.
func _spawn_skill_particles(color: Color) -> void:
	if _sprite == null:
		return
	var parent := _sprite.get_parent()
	if parent == null:
		return

	for i in range(8):
		var particle := _create_particle(color)
		parent.add_child(particle)
		particle.global_position = _sprite.global_position

		var angle := randf() * TAU
		var dist := randf_range(30.0, 60.0)
		var target_pos := particle.global_position + Vector2(cos(angle), sin(angle)) * dist

		var ptw := particle.create_tween()
		ptw.set_parallel(true)
		ptw.tween_property(particle, "global_position", target_pos, 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.tween_property(particle, "modulate:a", 0.0, 0.5)
		ptw.tween_property(particle, "scale", Vector2.ZERO, 0.5)
		ptw.chain().tween_callback(func(): if is_instance_valid(particle): particle.queue_free())

## Spawn golden sparkles for victory celebration.
func _spawn_victory_sparkles() -> void:
	if _sprite == null:
		return
	var parent := _sprite.get_parent()
	if parent == null:
		return

	var sparkle_colors := [
		Color(1.0, 0.9, 0.3),  # Gold
		Color(1.0, 1.0, 0.6),  # Light gold
		Color(0.9, 0.8, 0.2),  # Deep gold
		Color(1.0, 0.95, 0.8), # Cream
	]

	for i in range(12):
		var color: Color = sparkle_colors[i % sparkle_colors.size()]
		var particle := _create_particle(color)
		parent.add_child(particle)
		particle.global_position = _sprite.global_position + Vector2(
			randf_range(-20.0, 20.0), randf_range(-30.0, 5.0)
		)

		var rise := randf_range(25.0, 55.0)
		var drift := randf_range(-15.0, 15.0)
		var life := randf_range(0.5, 0.9)
		var target_pos := particle.global_position + Vector2(drift, -rise)

		var ptw := particle.create_tween()
		ptw.set_parallel(true)
		ptw.tween_property(particle, "global_position", target_pos, life) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.tween_property(particle, "modulate:a", 0.0, life * 0.8).set_delay(life * 0.3)
		ptw.tween_property(particle, "scale", Vector2(0.3, 0.3), life)
		ptw.chain().tween_callback(func(): if is_instance_valid(particle): particle.queue_free())

## Create a simple colored square particle (no texture dependency).
func _create_particle(color: Color) -> ColorRect:
	var p := ColorRect.new()
	var sz := randf_range(2.0, 5.0)
	p.size = Vector2(sz, sz)
	p.color = color
	p.pivot_offset = Vector2(sz / 2.0, sz / 2.0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## Spawn shield block particles (white-blue sparks in a defensive arc).
func _spawn_block_particles() -> void:
	if _sprite == null:
		return
	var parent := _sprite.get_parent()
	if parent == null:
		return
	var shield_colors := [
		Color(0.7, 0.85, 1.0),
		Color(0.9, 0.95, 1.0),
		Color(0.5, 0.7, 1.0),
	]
	for i in range(6):
		var color: Color = shield_colors[i % shield_colors.size()]
		var particle := _create_particle(color)
		parent.add_child(particle)
		particle.global_position = _sprite.global_position + Vector2(
			randf_range(-15.0, 15.0), randf_range(-20.0, 5.0)
		)
		var angle := randf_range(-PI * 0.6, PI * 0.6)  # front arc
		var dist := randf_range(15.0, 35.0)
		var target_pos := particle.global_position + Vector2(cos(angle), sin(angle)) * dist
		var life := randf_range(0.3, 0.5)
		var ptw := particle.create_tween()
		ptw.set_parallel(true)
		ptw.tween_property(particle, "global_position", target_pos, life) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ptw.tween_property(particle, "modulate:a", 0.0, life * 0.7).set_delay(life * 0.3)
		ptw.chain().tween_callback(func(): if is_instance_valid(particle): particle.queue_free())
