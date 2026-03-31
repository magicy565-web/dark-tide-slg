## battle_cutin.gd - Hero skill cut-in animation during combat (v1.0)
## Displays dramatic portrait + skill name when heroes use active abilities.
## Triggered via EventBus signals from combat resolution.
extends Node

# Cut-in animation for hero active skills during combat

const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Duration constants ──
const CUTIN_DURATION: float = 1.5
const SLIDE_IN_TIME: float = 0.2
const HOLD_TIME: float = 0.9
const SLIDE_OUT_TIME: float = 0.25
const FLASH_DURATION: float = 0.1

# ── UI refs ──
var _canvas: CanvasLayer = null
var _portrait_rect: TextureRect = null
var _skill_name_label: Label = null
var _skill_effect_label: Label = null
var _slash_line: ColorRect = null
var _bg_flash: ColorRect = null
var _built: bool = false
var _is_playing: bool = false

# ── Tweens ──
var _cutin_tween: Tween = null
var _flash_tween: Tween = null


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	if EventBus.has_signal("hero_skill_activated"):
		EventBus.hero_skill_activated.connect(_on_hero_skill_activated)
	if EventBus.has_signal("battle_cutin_requested"):
		EventBus.battle_cutin_requested.connect(_on_battle_cutin_requested)


func _on_hero_skill_activated(hero_id: String, skill_name: String, is_attacker: bool) -> void:
	play_cutin(hero_id, skill_name, is_attacker)


func _on_battle_cutin_requested(hero_id: String, skill_name: String, from_left: bool) -> void:
	play_cutin(hero_id, skill_name, from_left)


# ═══════════════════════════════════════════════════════════════
#                     BUILD UI (lazy)
# ═══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	if _built:
		return
	_built = true

	_canvas = CanvasLayer.new()
	_canvas.name = "BattleCutinCanvas"
	_canvas.layer = 8  # Above VN director (layer 7)
	add_child(_canvas)

	# ── Background flash (fullscreen) ──
	_bg_flash = ColorRect.new()
	_bg_flash.name = "BGFlash"
	_bg_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_flash.offset_left = 0; _bg_flash.offset_right = 0
	_bg_flash.offset_top = 0; _bg_flash.offset_bottom = 0
	_bg_flash.color = Color(1, 1, 1, 0)
	_bg_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_flash.visible = false
	_canvas.add_child(_bg_flash)

	# ── Diagonal slash line decoration ──
	_slash_line = ColorRect.new()
	_slash_line.name = "SlashLine"
	_slash_line.anchor_left = 0.0; _slash_line.anchor_right = 1.0
	_slash_line.anchor_top = 0.3; _slash_line.anchor_bottom = 0.7
	_slash_line.offset_left = 0; _slash_line.offset_right = 0
	_slash_line.offset_top = 0; _slash_line.offset_bottom = 0
	_slash_line.color = Color(1.0, 0.85, 0.3, 0.15)
	_slash_line.rotation = -0.12  # Slight diagonal tilt (~7 degrees)
	_slash_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slash_line.visible = false
	_canvas.add_child(_slash_line)

	# ── Portrait rect (centered vertically, slides from side) ──
	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "CutinPortrait"
	_portrait_rect.anchor_left = 0.05; _portrait_rect.anchor_right = 0.35
	_portrait_rect.anchor_top = 0.15; _portrait_rect.anchor_bottom = 0.85
	_portrait_rect.offset_left = 0; _portrait_rect.offset_right = 0
	_portrait_rect.offset_top = 0; _portrait_rect.offset_bottom = 0
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.visible = false
	_canvas.add_child(_portrait_rect)

	# ── Skill name label (large bold text) ──
	_skill_name_label = Label.new()
	_skill_name_label.name = "SkillNameLabel"
	_skill_name_label.anchor_left = 0.35; _skill_name_label.anchor_right = 0.95
	_skill_name_label.anchor_top = 0.35; _skill_name_label.anchor_bottom = 0.55
	_skill_name_label.offset_left = 0; _skill_name_label.offset_right = 0
	_skill_name_label.offset_top = 0; _skill_name_label.offset_bottom = 0
	_skill_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skill_name_label.add_theme_font_size_override("font_size", 36)
	_skill_name_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	# Glow effect via outline
	_skill_name_label.add_theme_constant_override("outline_size", 4)
	_skill_name_label.add_theme_color_override("font_outline_color", Color(1.0, 0.7, 0.2, 0.6))
	_skill_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_name_label.visible = false
	_canvas.add_child(_skill_name_label)

	# ── Skill effect subtitle ──
	_skill_effect_label = Label.new()
	_skill_effect_label.name = "SkillEffectLabel"
	_skill_effect_label.anchor_left = 0.35; _skill_effect_label.anchor_right = 0.95
	_skill_effect_label.anchor_top = 0.55; _skill_effect_label.anchor_bottom = 0.65
	_skill_effect_label.offset_left = 0; _skill_effect_label.offset_right = 0
	_skill_effect_label.offset_top = 0; _skill_effect_label.offset_bottom = 0
	_skill_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_effect_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skill_effect_label.add_theme_font_size_override("font_size", 16)
	_skill_effect_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7, 0.8))
	_skill_effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_effect_label.visible = false
	_canvas.add_child(_skill_effect_label)


# ═══════════════════════════════════════════════════════════════
#                       PUBLIC API
# ═══════════════════════════════════════════════════════════════

## Play a hero skill cut-in animation.
## hero_id: hero performing the skill
## skill_name: display name of the skill
## from_left: true if attacker (slides from left), false if defender (slides from right)
func play_cutin(hero_id: String, skill_name: String, from_left: bool = true) -> void:
	if _is_playing:
		return  # Don't overlap cut-ins
	_build_ui()
	_is_playing = true

	# Load portrait texture
	var tex: Texture2D = CGManager.load_head_texture(hero_id, "serious")
	if tex == null:
		tex = CGManager.load_head_texture(hero_id, "")
	if tex == null:
		# No portrait available, skip cut-in gracefully
		_is_playing = false
		if EventBus.has_signal("battle_cutin_finished"):
			EventBus.battle_cutin_finished.emit()
		return

	_portrait_rect.texture = tex
	_portrait_rect.flip_h = not from_left  # Flip when coming from right

	# Get hero name for subtitle
	var hero_name: String = _get_hero_name(hero_id)
	_skill_name_label.text = skill_name
	_skill_effect_label.text = hero_name

	# Position elements based on direction
	if from_left:
		_portrait_rect.anchor_left = 0.05; _portrait_rect.anchor_right = 0.35
		_skill_name_label.anchor_left = 0.35; _skill_name_label.anchor_right = 0.95
		_skill_effect_label.anchor_left = 0.35; _skill_effect_label.anchor_right = 0.95
	else:
		_portrait_rect.anchor_left = 0.65; _portrait_rect.anchor_right = 0.95
		_skill_name_label.anchor_left = 0.05; _skill_name_label.anchor_right = 0.65
		_skill_effect_label.anchor_left = 0.05; _skill_effect_label.anchor_right = 0.65

	# Reset offsets
	_portrait_rect.offset_left = 0; _portrait_rect.offset_right = 0
	_portrait_rect.offset_top = 0; _portrait_rect.offset_bottom = 0

	# Start animation
	_animate_cutin(from_left)


## Check if a cut-in is currently playing.
func is_playing() -> bool:
	return _is_playing


# ═══════════════════════════════════════════════════════════════
#                     INTERNAL: ANIMATION
# ═══════════════════════════════════════════════════════════════

func _animate_cutin(from_left: bool) -> void:
	if _cutin_tween:
		_cutin_tween.kill()

	# Initial state: everything hidden/offset
	var slide_offset: float = 400.0 if from_left else -400.0
	_portrait_rect.position.x += slide_offset
	_portrait_rect.modulate.a = 0.0
	_portrait_rect.visible = true

	_skill_name_label.modulate.a = 0.0
	_skill_name_label.visible = true
	_skill_effect_label.modulate.a = 0.0
	_skill_effect_label.visible = true

	_slash_line.modulate.a = 0.0
	_slash_line.visible = true

	# Background flash
	_bg_flash.color = Color(1, 1, 1, 0)
	_bg_flash.visible = true

	_cutin_tween = create_tween()

	# Phase 1: Flash + slide in (SLIDE_IN_TIME)
	_cutin_tween.set_parallel(true)
	_cutin_tween.tween_property(_bg_flash, "color:a", 0.6, FLASH_DURATION)
	_cutin_tween.tween_property(_portrait_rect, "position:x", _portrait_rect.position.x - slide_offset, SLIDE_IN_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_cutin_tween.tween_property(_portrait_rect, "modulate:a", 1.0, SLIDE_IN_TIME * 0.5)
	_cutin_tween.tween_property(_slash_line, "modulate:a", 1.0, SLIDE_IN_TIME)
	_cutin_tween.tween_property(_skill_name_label, "modulate:a", 1.0, SLIDE_IN_TIME).set_delay(0.05)
	_cutin_tween.tween_property(_skill_effect_label, "modulate:a", 1.0, SLIDE_IN_TIME).set_delay(0.1)

	# Phase 2: Flash fade out (parallel with hold)
	_cutin_tween.set_parallel(false)
	_cutin_tween.tween_property(_bg_flash, "color:a", 0.0, FLASH_DURATION * 2)

	# Phase 3: Hold
	_cutin_tween.tween_interval(HOLD_TIME)

	# Phase 4: Slide out
	_cutin_tween.set_parallel(true)
	var out_offset: float = -300.0 if from_left else 300.0
	_cutin_tween.tween_property(_portrait_rect, "position:x", _portrait_rect.position.x - slide_offset + out_offset, SLIDE_OUT_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_cutin_tween.tween_property(_portrait_rect, "modulate:a", 0.0, SLIDE_OUT_TIME)
	_cutin_tween.tween_property(_slash_line, "modulate:a", 0.0, SLIDE_OUT_TIME)
	_cutin_tween.tween_property(_skill_name_label, "modulate:a", 0.0, SLIDE_OUT_TIME * 0.8)
	_cutin_tween.tween_property(_skill_effect_label, "modulate:a", 0.0, SLIDE_OUT_TIME * 0.8)

	# Phase 5: Cleanup
	_cutin_tween.set_parallel(false)
	_cutin_tween.tween_callback(_cleanup_cutin)


func _cleanup_cutin() -> void:
	_is_playing = false
	_portrait_rect.visible = false
	_portrait_rect.texture = null
	_portrait_rect.position = Vector2.ZERO
	_skill_name_label.visible = false
	_skill_name_label.text = ""
	_skill_effect_label.visible = false
	_skill_effect_label.text = ""
	_slash_line.visible = false
	_bg_flash.visible = false
	_bg_flash.color = Color(1, 1, 1, 0)

	# Emit finished signal
	if EventBus.has_signal("battle_cutin_finished"):
		EventBus.battle_cutin_finished.emit()


# ═══════════════════════════════════════════════════════════════
#                          HELPERS
# ═══════════════════════════════════════════════════════════════

func _get_hero_name(hero_id: String) -> String:
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	return hero_data.get("name", hero_id)
