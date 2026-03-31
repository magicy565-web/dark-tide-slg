## vn_director.gd - Visual Novel scene director for cinematic story presentation (v1.0)
## Orchestrates multi-portrait dialogues, screen effects, and auto-BGM.
## Works on top of StoryDialog for enhanced presentation.
extends Node

# Portrait positions
enum PortraitSlot { LEFT, RIGHT, CENTER }

# Screen effect types
enum ScreenEffect { NONE, FLASH_WHITE, FLASH_RED, SHAKE_LIGHT, SHAKE_HEAVY,
	TINT_RAGE, TINT_SAD, TINT_HAPPY, TINT_DARK, VIGNETTE, FADE_BLACK, FADE_WHITE }

# Mood -> BGM mapping (keys used in story event data)
const MOOD_BGM := {
	"calm": "OVERWORLD_CALM",
	"tense": "OVERWORLD_TENSE",
	"battle": "COMBAT_NORMAL",
	"boss": "COMBAT_BOSS",
	"romantic": "EVENT",
	"sad": "EVENT",
	"victory": "VICTORY",
	"defeat": "DEFEAT",
	"dramatic": "COMBAT_CRISIS",
}

# Effect name -> enum lookup (for string-based calls from dialogue data)
const EFFECT_NAME_MAP := {
	"flash_white": ScreenEffect.FLASH_WHITE,
	"flash_red": ScreenEffect.FLASH_RED,
	"shake_light": ScreenEffect.SHAKE_LIGHT,
	"shake_heavy": ScreenEffect.SHAKE_HEAVY,
	"tint_rage": ScreenEffect.TINT_RAGE,
	"tint_sad": ScreenEffect.TINT_SAD,
	"tint_happy": ScreenEffect.TINT_HAPPY,
	"tint_dark": ScreenEffect.TINT_DARK,
	"vignette": ScreenEffect.VIGNETTE,
	"fade_black": ScreenEffect.FADE_BLACK,
	"fade_white": ScreenEffect.FADE_WHITE,
}

# ── State ──
var _left_hero: String = ""
var _right_hero: String = ""
var _left_expression: String = ""
var _right_expression: String = ""
var _active_speaker: int = PortraitSlot.LEFT
var _screen_tint: Color = Color(0, 0, 0, 0)
var _effect_overlay: ColorRect = null
var _vignette_overlay: ColorRect = null
var _is_playing_sequence: bool = false
var _sequence_queue: Array = []

# ── UI Refs (created on first use) ──
var _left_portrait: TextureRect = null
var _right_portrait: TextureRect = null
var _left_name: Label = null
var _right_name: Label = null
var _canvas: CanvasLayer = null
var _built: bool = false

# ── Tweens ──
var _effect_tween: Tween = null
var _portrait_tween_l: Tween = null
var _portrait_tween_r: Tween = null
var _sequence_tween: Tween = null
var _shake_tween: Tween = null


# ═══════════════════════════════════════════════════════════════
#                          LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	_connect_signals()


func _connect_signals() -> void:
	if EventBus.has_signal("vn_scene_started"):
		EventBus.vn_scene_started.connect(_on_vn_scene_started)
	if EventBus.has_signal("vn_scene_ended"):
		EventBus.vn_scene_ended.connect(_on_vn_scene_ended)
	if EventBus.has_signal("screen_effect_requested"):
		EventBus.screen_effect_requested.connect(_on_screen_effect_requested)


func _on_vn_scene_started(left_hero: String, right_hero: String, mood: String) -> void:
	setup_scene(left_hero, right_hero, mood)


func _on_vn_scene_ended() -> void:
	cleanup()


func _on_screen_effect_requested(effect_type: String, duration: float) -> void:
	play_effect_by_name(effect_type, duration)


# ═══════════════════════════════════════════════════════════════
#                     OVERLAY UI CONSTRUCTION
# ═══════════════════════════════════════════════════════════════

func _build_overlay_ui() -> void:
	if _built:
		return
	_built = true

	_canvas = CanvasLayer.new()
	_canvas.name = "VnDirectorCanvas"
	_canvas.layer = 7  # Above StoryDialog (layer 6)
	add_child(_canvas)

	# ── Effect overlay (flash / tint) ──
	_effect_overlay = ColorRect.new()
	_effect_overlay.name = "EffectOverlay"
	_effect_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_effect_overlay.offset_left = 0; _effect_overlay.offset_right = 0
	_effect_overlay.offset_top = 0; _effect_overlay.offset_bottom = 0
	_effect_overlay.color = Color(0, 0, 0, 0)
	_effect_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_overlay.visible = false
	_canvas.add_child(_effect_overlay)

	# ── Vignette overlay ──
	_vignette_overlay = ColorRect.new()
	_vignette_overlay.name = "VignetteOverlay"
	_vignette_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette_overlay.offset_left = 0; _vignette_overlay.offset_right = 0
	_vignette_overlay.offset_top = 0; _vignette_overlay.offset_bottom = 0
	_vignette_overlay.color = Color(0, 0, 0, 0)
	_vignette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette_overlay.visible = false
	_canvas.add_child(_vignette_overlay)

	# ── Left portrait (anchored left 2%-22%, vertical 15%-70%) ──
	_left_portrait = TextureRect.new()
	_left_portrait.name = "LeftPortrait"
	_left_portrait.anchor_left = 0.02; _left_portrait.anchor_right = 0.22
	_left_portrait.anchor_top = 0.15; _left_portrait.anchor_bottom = 0.70
	_left_portrait.offset_left = 0; _left_portrait.offset_right = 0
	_left_portrait.offset_top = 0; _left_portrait.offset_bottom = 0
	_left_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_left_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_left_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_portrait.visible = false
	_left_portrait.pivot_offset = Vector2(128, 256)  # Center-bottom pivot for scale
	_canvas.add_child(_left_portrait)

	# Left name label
	_left_name = Label.new()
	_left_name.name = "LeftName"
	_left_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_name.anchor_left = 0.02; _left_name.anchor_right = 0.22
	_left_name.anchor_top = 0.71; _left_name.anchor_bottom = 0.75
	_left_name.offset_left = 0; _left_name.offset_right = 0
	_left_name.offset_top = 0; _left_name.offset_bottom = 0
	_left_name.add_theme_font_size_override("font_size", 13)
	_left_name.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	_left_name.visible = false
	_canvas.add_child(_left_name)

	# ── Right portrait (anchored right 78%-98%, vertical 15%-70%, FLIPPED) ──
	_right_portrait = TextureRect.new()
	_right_portrait.name = "RightPortrait"
	_right_portrait.anchor_left = 0.78; _right_portrait.anchor_right = 0.98
	_right_portrait.anchor_top = 0.15; _right_portrait.anchor_bottom = 0.70
	_right_portrait.offset_left = 0; _right_portrait.offset_right = 0
	_right_portrait.offset_top = 0; _right_portrait.offset_bottom = 0
	_right_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_right_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_right_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_portrait.flip_h = true  # Mirror horizontally for right side
	_right_portrait.visible = false
	_right_portrait.pivot_offset = Vector2(128, 256)
	_canvas.add_child(_right_portrait)

	# Right name label
	_right_name = Label.new()
	_right_name.name = "RightName"
	_right_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_right_name.anchor_left = 0.78; _right_name.anchor_right = 0.98
	_right_name.anchor_top = 0.71; _right_name.anchor_bottom = 0.75
	_right_name.offset_left = 0; _right_name.offset_right = 0
	_right_name.offset_top = 0; _right_name.offset_bottom = 0
	_right_name.add_theme_font_size_override("font_size", 13)
	_right_name.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	_right_name.visible = false
	_canvas.add_child(_right_name)


# ═══════════════════════════════════════════════════════════════
#                       PUBLIC API
# ═══════════════════════════════════════════════════════════════

## Set up a two-character scene with mood-based BGM.
func setup_scene(left_hero: String, right_hero: String, mood: String = "") -> void:
	_build_overlay_ui()
	_left_hero = left_hero
	_right_hero = right_hero
	_left_expression = ""
	_right_expression = ""
	_active_speaker = PortraitSlot.LEFT

	# Show left portrait
	if left_hero != "":
		_load_portrait(PortraitSlot.LEFT, left_hero, "")
		_left_portrait.visible = true
		_left_name.visible = true
		_left_name.text = _get_hero_name(left_hero)
		_left_portrait.modulate.a = 0.0
		_left_name.modulate.a = 0.0
		if _portrait_tween_l:
			_portrait_tween_l.kill()
		_portrait_tween_l = create_tween().set_parallel(true)
		_portrait_tween_l.tween_property(_left_portrait, "modulate:a", 1.0, 0.3)
		_portrait_tween_l.tween_property(_left_name, "modulate:a", 1.0, 0.3)

	# Show right portrait
	if right_hero != "":
		_load_portrait(PortraitSlot.RIGHT, right_hero, "")
		_right_portrait.visible = true
		_right_name.visible = true
		_right_name.text = _get_hero_name(right_hero)
		_right_portrait.modulate.a = 0.0
		_right_name.modulate.a = 0.0
		if _portrait_tween_r:
			_portrait_tween_r.kill()
		_portrait_tween_r = create_tween().set_parallel(true)
		_portrait_tween_r.tween_property(_right_portrait, "modulate:a", 1.0, 0.3)
		_portrait_tween_r.tween_property(_right_name, "modulate:a", 1.0, 0.3)

	# Set default speaker highlighting
	_update_speaker_highlight()

	# Auto-BGM based on mood
	if mood != "":
		_switch_bgm_for_mood(mood)


## Highlight the active speaker, dim the other.
func set_speaker(slot: int) -> void:
	_build_overlay_ui()
	_active_speaker = slot
	_update_speaker_highlight()


## Change expression on a portrait with subtle animation.
func set_expression(slot: int, expression: String) -> void:
	_build_overlay_ui()
	var hero_id: String = _left_hero if slot == PortraitSlot.LEFT else _right_hero
	if hero_id == "":
		return

	var portrait: TextureRect = _left_portrait if slot == PortraitSlot.LEFT else _right_portrait
	var tween_ref: Tween = null

	# Store expression
	if slot == PortraitSlot.LEFT:
		if expression == _left_expression:
			return
		_left_expression = expression
	else:
		if expression == _right_expression:
			return
		_right_expression = expression

	# Quick scale-bounce to emphasize expression change
	var tw: Tween = create_tween()
	tw.tween_property(portrait, "scale", Vector2(1.08, 1.08), 0.06)
	tw.tween_callback(func(): _load_portrait(slot, hero_id, expression))
	tw.tween_property(portrait, "scale", Vector2(1.0, 1.0), 0.1)


## Play a screen effect by enum.
func play_effect(effect: int, duration: float = 0.3) -> void:
	_build_overlay_ui()
	match effect:
		ScreenEffect.NONE:
			return
		ScreenEffect.FLASH_WHITE:
			_play_flash(Color(1, 1, 1, 0.85), duration)
		ScreenEffect.FLASH_RED:
			_play_flash(Color(1, 0.15, 0.1, 0.7), duration)
		ScreenEffect.SHAKE_LIGHT:
			_play_shake(4.0, duration)
		ScreenEffect.SHAKE_HEAVY:
			_play_shake(12.0, duration)
		ScreenEffect.TINT_RAGE:
			_play_tint(Color(0.6, 0.05, 0.05, 0.3), duration)
		ScreenEffect.TINT_SAD:
			_play_tint(Color(0.1, 0.15, 0.4, 0.3), duration)
		ScreenEffect.TINT_HAPPY:
			_play_tint(Color(0.4, 0.3, 0.1, 0.2), duration)
		ScreenEffect.TINT_DARK:
			_play_tint(Color(0.0, 0.0, 0.0, 0.5), duration)
		ScreenEffect.VIGNETTE:
			_play_vignette(duration)
		ScreenEffect.FADE_BLACK:
			_play_fade(Color(0, 0, 0, 1), duration)
		ScreenEffect.FADE_WHITE:
			_play_fade(Color(1, 1, 1, 1), duration)


## Play a screen effect by string name (from dialogue data).
func play_effect_by_name(effect_name: String, duration: float = 0.3) -> void:
	if EFFECT_NAME_MAP.has(effect_name):
		play_effect(EFFECT_NAME_MAP[effect_name], duration)
	else:
		push_warning("VnDirector: Unknown effect name '%s'" % effect_name)


## Execute a sequence of VN commands.
## Each command is a Dictionary: { "cmd": String, ... params }
## Supported cmds: "show_portrait", "set_speaker", "set_expression",
##   "play_effect", "wait", "set_mood", "fade_out", "fade_in"
func play_sequence(commands: Array) -> void:
	_build_overlay_ui()
	_sequence_queue = commands.duplicate()
	_is_playing_sequence = true
	_execute_next_command()


## Reset all VN director state and hide overlays.
func cleanup() -> void:
	_left_hero = ""
	_right_hero = ""
	_left_expression = ""
	_right_expression = ""
	_active_speaker = PortraitSlot.LEFT
	_screen_tint = Color(0, 0, 0, 0)
	_is_playing_sequence = false
	_sequence_queue.clear()

	# Kill all active tweens
	if _effect_tween:
		_effect_tween.kill()
		_effect_tween = null
	if _portrait_tween_l:
		_portrait_tween_l.kill()
		_portrait_tween_l = null
	if _portrait_tween_r:
		_portrait_tween_r.kill()
		_portrait_tween_r = null
	if _sequence_tween:
		_sequence_tween.kill()
		_sequence_tween = null
	if _shake_tween:
		_shake_tween.kill()
		_shake_tween = null

	if not _built:
		return

	# Hide and reset overlays
	_effect_overlay.color = Color(0, 0, 0, 0)
	_effect_overlay.visible = false
	_vignette_overlay.color = Color(0, 0, 0, 0)
	_vignette_overlay.visible = false

	# Hide portraits
	_left_portrait.visible = false
	_left_portrait.texture = null
	_left_portrait.scale = Vector2(1, 1)
	_left_name.visible = false
	_left_name.text = ""
	_right_portrait.visible = false
	_right_portrait.texture = null
	_right_portrait.scale = Vector2(1, 1)
	_right_name.visible = false
	_right_name.text = ""

	# Reset canvas position (in case of shake)
	if _canvas:
		_canvas.offset = Vector2.ZERO


## Check if a VN scene is currently active (has portraits showing).
func is_scene_active() -> bool:
	return _left_hero != "" or _right_hero != ""


## Switch BGM for a given mood tag.
func switch_mood(mood: String) -> void:
	_switch_bgm_for_mood(mood)


# ═══════════════════════════════════════════════════════════════
#                     INTERNAL: PORTRAITS
# ═══════════════════════════════════════════════════════════════

func _load_portrait(slot: int, hero_id: String, expression: String) -> void:
	var tex: Texture2D = CGManager.load_head_texture(hero_id, expression)
	if tex == null:
		return
	if slot == PortraitSlot.LEFT:
		_left_portrait.texture = tex
	else:
		_right_portrait.texture = tex


func _update_speaker_highlight() -> void:
	if not _built:
		return

	var active_l: bool = (_active_speaker == PortraitSlot.LEFT or _active_speaker == PortraitSlot.CENTER)
	var active_r: bool = (_active_speaker == PortraitSlot.RIGHT or _active_speaker == PortraitSlot.CENTER)

	# Active speaker: full brightness + slight scale up (1.05)
	# Inactive speaker: dimmed (0.5 brightness) + normal scale
	var target_mod_l: Color = Color(1, 1, 1, 1) if active_l else Color(0.5, 0.5, 0.5, 1)
	var target_scale_l: Vector2 = Vector2(1.05, 1.05) if active_l else Vector2(1.0, 1.0)
	var target_mod_r: Color = Color(1, 1, 1, 1) if active_r else Color(0.5, 0.5, 0.5, 1)
	var target_scale_r: Vector2 = Vector2(1.05, 1.05) if active_r else Vector2(1.0, 1.0)

	if _left_portrait.visible:
		if _portrait_tween_l:
			_portrait_tween_l.kill()
		_portrait_tween_l = create_tween().set_parallel(true)
		_portrait_tween_l.tween_property(_left_portrait, "modulate", target_mod_l, 0.2)
		_portrait_tween_l.tween_property(_left_portrait, "scale", target_scale_l, 0.2)
		_portrait_tween_l.tween_property(_left_name, "modulate:a", 1.0 if active_l else 0.5, 0.2)

	if _right_portrait.visible:
		if _portrait_tween_r:
			_portrait_tween_r.kill()
		_portrait_tween_r = create_tween().set_parallel(true)
		_portrait_tween_r.tween_property(_right_portrait, "modulate", target_mod_r, 0.2)
		_portrait_tween_r.tween_property(_right_portrait, "scale", target_scale_r, 0.2)
		_portrait_tween_r.tween_property(_right_name, "modulate:a", 1.0 if active_r else 0.5, 0.2)


# ═══════════════════════════════════════════════════════════════
#                     INTERNAL: SCREEN EFFECTS
# ═══════════════════════════════════════════════════════════════

func _play_flash(color: Color, duration: float) -> void:
	if _effect_tween:
		_effect_tween.kill()
	_effect_overlay.color = color
	_effect_overlay.visible = true
	_effect_tween = create_tween()
	_effect_tween.tween_property(_effect_overlay, "color:a", 0.0, duration)
	_effect_tween.tween_callback(func(): _effect_overlay.visible = false)


func _play_tint(color: Color, duration: float) -> void:
	if _effect_tween:
		_effect_tween.kill()
	_screen_tint = color
	_effect_overlay.color = Color(color.r, color.g, color.b, 0.0)
	_effect_overlay.visible = true
	_effect_tween = create_tween()
	# Fade in tint, hold, then fade out
	var fade_in: float = duration * 0.2
	var hold: float = duration * 0.6
	var fade_out: float = duration * 0.2
	_effect_tween.tween_property(_effect_overlay, "color:a", color.a, fade_in)
	_effect_tween.tween_interval(hold)
	_effect_tween.tween_property(_effect_overlay, "color:a", 0.0, fade_out)
	_effect_tween.tween_callback(func():
		_effect_overlay.visible = false
		_screen_tint = Color(0, 0, 0, 0)
	)


func _play_vignette(duration: float) -> void:
	# Simple vignette using border darkening (approximation without shader)
	_vignette_overlay.visible = true
	_vignette_overlay.color = Color(0, 0, 0, 0)
	if _effect_tween:
		_effect_tween.kill()
	_effect_tween = create_tween()
	_effect_tween.tween_property(_vignette_overlay, "color:a", 0.4, duration * 0.3)
	_effect_tween.tween_interval(duration * 0.4)
	_effect_tween.tween_property(_vignette_overlay, "color:a", 0.0, duration * 0.3)
	_effect_tween.tween_callback(func(): _vignette_overlay.visible = false)


func _play_fade(color: Color, duration: float) -> void:
	if _effect_tween:
		_effect_tween.kill()
	_effect_overlay.color = Color(color.r, color.g, color.b, 0.0)
	_effect_overlay.visible = true
	_effect_tween = create_tween()
	_effect_tween.tween_property(_effect_overlay, "color:a", color.a, duration)


func _play_shake(intensity: float, duration: float) -> void:
	if not _canvas:
		return
	if _shake_tween:
		_shake_tween.kill()
	var steps: int = int(duration / 0.03)
	_shake_tween = create_tween()
	for i in range(steps):
		var offset := Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		_shake_tween.tween_property(_canvas, "offset", offset, 0.03)
	_shake_tween.tween_property(_canvas, "offset", Vector2.ZERO, 0.05)


## Fade out all VN overlays (transition to black, then clear).
func fade_to_black(duration: float = 0.5) -> void:
	_build_overlay_ui()
	_play_fade(Color(0, 0, 0, 1), duration)


## Fade in from black (clear the fade overlay).
func fade_from_black(duration: float = 0.5) -> void:
	_build_overlay_ui()
	if _effect_tween:
		_effect_tween.kill()
	_effect_overlay.color = Color(0, 0, 0, 1)
	_effect_overlay.visible = true
	_effect_tween = create_tween()
	_effect_tween.tween_property(_effect_overlay, "color:a", 0.0, duration)
	_effect_tween.tween_callback(func(): _effect_overlay.visible = false)


# ═══════════════════════════════════════════════════════════════
#                     INTERNAL: BGM
# ═══════════════════════════════════════════════════════════════

func _switch_bgm_for_mood(mood: String) -> void:
	if not MOOD_BGM.has(mood):
		return
	var track_name: String = MOOD_BGM[mood]
	# Use AudioManager's BGMTrack enum via string lookup
	var track_map: Dictionary = {
		"OVERWORLD_CALM": AudioManager.BGMTrack.OVERWORLD_CALM,
		"OVERWORLD_TENSE": AudioManager.BGMTrack.OVERWORLD_TENSE,
		"COMBAT_NORMAL": AudioManager.BGMTrack.COMBAT_NORMAL,
		"COMBAT_BOSS": AudioManager.BGMTrack.COMBAT_BOSS,
		"COMBAT_CRISIS": AudioManager.BGMTrack.COMBAT_CRISIS,
		"EVENT": AudioManager.BGMTrack.EVENT,
		"VICTORY": AudioManager.BGMTrack.VICTORY,
		"DEFEAT": AudioManager.BGMTrack.DEFEAT,
	}
	if track_map.has(track_name):
		AudioManager.play_bgm(track_map[track_name], 1.0)


# ═══════════════════════════════════════════════════════════════
#                     INTERNAL: SEQUENCE EXECUTION
# ═══════════════════════════════════════════════════════════════

func _execute_next_command() -> void:
	if _sequence_queue.is_empty():
		_is_playing_sequence = false
		return

	var cmd: Dictionary = _sequence_queue.pop_front()
	var cmd_type: String = cmd.get("cmd", "")

	match cmd_type:
		"show_portrait":
			var slot: int = cmd.get("slot", PortraitSlot.LEFT)
			var hero_id: String = cmd.get("hero_id", "")
			var expression: String = cmd.get("expression", "")
			if slot == PortraitSlot.LEFT:
				_left_hero = hero_id
				_left_expression = expression
				_load_portrait(slot, hero_id, expression)
				_left_portrait.visible = true
				_left_name.visible = true
				_left_name.text = _get_hero_name(hero_id)
			else:
				_right_hero = hero_id
				_right_expression = expression
				_load_portrait(slot, hero_id, expression)
				_right_portrait.visible = true
				_right_name.visible = true
				_right_name.text = _get_hero_name(hero_id)
			_execute_next_command()

		"set_speaker":
			var slot: int = cmd.get("slot", PortraitSlot.LEFT)
			set_speaker(slot)
			_execute_next_command()

		"set_expression":
			var slot: int = cmd.get("slot", PortraitSlot.LEFT)
			var expression: String = cmd.get("expression", "")
			set_expression(slot, expression)
			_execute_next_command()

		"play_effect":
			var effect_name: String = cmd.get("effect", "")
			var duration: float = cmd.get("duration", 0.3)
			play_effect_by_name(effect_name, duration)
			# Wait for effect to finish before next command
			if _sequence_tween:
				_sequence_tween.kill()
			_sequence_tween = create_tween()
			_sequence_tween.tween_interval(duration)
			_sequence_tween.tween_callback(_execute_next_command)
			return  # Don't call _execute_next_command immediately

		"wait":
			var duration: float = cmd.get("duration", 0.5)
			if _sequence_tween:
				_sequence_tween.kill()
			_sequence_tween = create_tween()
			_sequence_tween.tween_interval(duration)
			_sequence_tween.tween_callback(_execute_next_command)
			return

		"set_mood":
			var mood: String = cmd.get("mood", "")
			_switch_bgm_for_mood(mood)
			_execute_next_command()

		"fade_out":
			var duration: float = cmd.get("duration", 0.5)
			fade_to_black(duration)
			if _sequence_tween:
				_sequence_tween.kill()
			_sequence_tween = create_tween()
			_sequence_tween.tween_interval(duration)
			_sequence_tween.tween_callback(_execute_next_command)
			return

		"fade_in":
			var duration: float = cmd.get("duration", 0.5)
			fade_from_black(duration)
			if _sequence_tween:
				_sequence_tween.kill()
			_sequence_tween = create_tween()
			_sequence_tween.tween_interval(duration)
			_sequence_tween.tween_callback(_execute_next_command)
			return

		_:
			push_warning("VnDirector: Unknown sequence command '%s'" % cmd_type)
			_execute_next_command()


# ═══════════════════════════════════════════════════════════════
#                          HELPERS
# ═══════════════════════════════════════════════════════════════

const FactionData = preload("res://systems/faction/faction_data.gd")

func _get_hero_name(hero_id: String) -> String:
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	return hero_data.get("name", hero_id)
