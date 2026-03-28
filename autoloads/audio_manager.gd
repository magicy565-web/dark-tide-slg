## audio_manager.gd - Sound & Music system for 暗潮 SLG (v2.0)
## Manages BGM, SFX, and ambient sounds. Works without actual audio files
## by providing the interface; audio files can be added later.
## Generates procedural click sound so the game is not completely silent.
extends Node

# ── Volume settings (0.0 to 1.0) ──
var bgm_volume: float = 0.7
var sfx_volume: float = 0.8
var ambient_volume: float = 0.5
var master_muted: bool = false

# ── Audio bus names ──
const BUS_MASTER := "Master"
const BUS_BGM := "BGM"
const BUS_SFX := "SFX"
const BUS_AMBIENT := "Ambient"

# ── BGM track IDs ──
enum BGMTrack {
	TITLE,
	FACTION_SELECT,
	OVERWORLD_CALM,
	OVERWORLD_TENSE,
	COMBAT_NORMAL,
	COMBAT_BOSS,
	VICTORY,
	DEFEAT,
	EVENT,
}

# ── SFX IDs ──
enum SFX {
	UI_CLICK,
	UI_CONFIRM,
	UI_CANCEL,
	UI_HOVER,
	COMBAT_ATTACK,
	COMBAT_DEFEND,
	COMBAT_CRITICAL,
	COMBAT_DEATH,
	COMBAT_SIEGE,
	COMBAT_ABILITY,
	MAP_CAPTURE,
	MAP_LOST,
	MAP_DEPLOY,
	RESOURCE_GAIN,
	RESOURCE_SPEND,
	RESEARCH_COMPLETE,
	BUILD_COMPLETE,
	HERO_CAPTURE,
	HERO_RECRUIT,
	EVENT_TRIGGER,
	WAAAGH,
	LEVEL_UP,
	TURN_START,
	TURN_END,
	VICTORY,
	DEFEAT,
}

# ── Audio file paths (populated by _init_audio_paths) ──
var _bgm_paths: Dictionary = {}
var _sfx_paths: Dictionary = {}

# ── Players ──
var _bgm_player: AudioStreamPlayer
var _bgm_player_next: AudioStreamPlayer  # For crossfade
var _sfx_players: Array = []
const MAX_SFX_PLAYERS: int = 8
var _ambient_player: AudioStreamPlayer

# ── State ──
var _current_bgm: int = -1
var _crossfading: bool = false

# ── Procedural audio cache ──
var _procedural_click: AudioStream = null
var _procedural_confirm: AudioStream = null

# ── String-based SFX lookup (for play_sfx_by_name) ──
var _sfx_name_map: Dictionary = {}


func _ready() -> void:
	_init_audio_paths()
	_build_sfx_name_map()
	_setup_audio_buses()
	_setup_players()
	_generate_procedural_sounds()
	_connect_signals()


func _init_audio_paths() -> void:
	_bgm_paths = {
		BGMTrack.TITLE: "res://assets/audio/bgm/title.ogg",
		BGMTrack.FACTION_SELECT: "res://assets/audio/bgm/faction_select.ogg",
		BGMTrack.OVERWORLD_CALM: "res://assets/audio/bgm/overworld_calm.ogg",
		BGMTrack.OVERWORLD_TENSE: "res://assets/audio/bgm/overworld_tense.ogg",
		BGMTrack.COMBAT_NORMAL: "res://assets/audio/bgm/combat_normal.ogg",
		BGMTrack.COMBAT_BOSS: "res://assets/audio/bgm/combat_boss.ogg",
		BGMTrack.VICTORY: "res://assets/audio/bgm/victory.ogg",
		BGMTrack.DEFEAT: "res://assets/audio/bgm/defeat.ogg",
		BGMTrack.EVENT: "res://assets/audio/bgm/event.ogg",
	}
	_sfx_paths = {
		SFX.UI_CLICK: "res://assets/audio/sfx/ui_click.ogg",
		SFX.UI_CONFIRM: "res://assets/audio/sfx/ui_confirm.ogg",
		SFX.UI_CANCEL: "res://assets/audio/sfx/ui_cancel.ogg",
		SFX.UI_HOVER: "res://assets/audio/sfx/ui_hover.ogg",
		SFX.COMBAT_ATTACK: "res://assets/audio/sfx/combat_attack.ogg",
		SFX.COMBAT_DEFEND: "res://assets/audio/sfx/combat_defend.ogg",
		SFX.COMBAT_CRITICAL: "res://assets/audio/sfx/combat_critical.ogg",
		SFX.COMBAT_DEATH: "res://assets/audio/sfx/combat_death.ogg",
		SFX.COMBAT_SIEGE: "res://assets/audio/sfx/combat_siege.ogg",
		SFX.COMBAT_ABILITY: "res://assets/audio/sfx/combat_ability.ogg",
		SFX.MAP_CAPTURE: "res://assets/audio/sfx/map_capture.ogg",
		SFX.MAP_LOST: "res://assets/audio/sfx/map_lost.ogg",
		SFX.MAP_DEPLOY: "res://assets/audio/sfx/map_deploy.ogg",
		SFX.RESOURCE_GAIN: "res://assets/audio/sfx/resource_gain.ogg",
		SFX.RESOURCE_SPEND: "res://assets/audio/sfx/resource_spend.ogg",
		SFX.RESEARCH_COMPLETE: "res://assets/audio/sfx/research_complete.ogg",
		SFX.BUILD_COMPLETE: "res://assets/audio/sfx/building_complete.ogg",
		SFX.HERO_CAPTURE: "res://assets/audio/sfx/hero_capture.ogg",
		SFX.HERO_RECRUIT: "res://assets/audio/sfx/hero_recruit.ogg",
		SFX.EVENT_TRIGGER: "res://assets/audio/sfx/event_trigger.ogg",
		SFX.WAAAGH: "res://assets/audio/sfx/waaagh.ogg",
		SFX.LEVEL_UP: "res://assets/audio/sfx/level_up.ogg",
		SFX.TURN_START: "res://assets/audio/sfx/turn_start.ogg",
		SFX.TURN_END: "res://assets/audio/sfx/turn_end.ogg",
		SFX.VICTORY: "res://assets/audio/sfx/victory.ogg",
		SFX.DEFEAT: "res://assets/audio/sfx/defeat.ogg",
	}


func _build_sfx_name_map() -> void:
	## Map human-readable string names to SFX enum values for play_sfx_by_name()
	_sfx_name_map = {
		"ui_click": SFX.UI_CLICK,
		"ui_confirm": SFX.UI_CONFIRM,
		"ui_cancel": SFX.UI_CANCEL,
		"ui_hover": SFX.UI_HOVER,
		"combat_attack": SFX.COMBAT_ATTACK,
		"combat_defend": SFX.COMBAT_DEFEND,
		"combat_critical": SFX.COMBAT_CRITICAL,
		"combat_death": SFX.COMBAT_DEATH,
		"combat_siege": SFX.COMBAT_SIEGE,
		"combat_ability": SFX.COMBAT_ABILITY,
		"capture": SFX.MAP_CAPTURE,
		"map_capture": SFX.MAP_CAPTURE,
		"map_lost": SFX.MAP_LOST,
		"map_deploy": SFX.MAP_DEPLOY,
		"resource_gain": SFX.RESOURCE_GAIN,
		"resource_spend": SFX.RESOURCE_SPEND,
		"research_complete": SFX.RESEARCH_COMPLETE,
		"build_complete": SFX.BUILD_COMPLETE,
		"hero_capture": SFX.HERO_CAPTURE,
		"recruit": SFX.HERO_RECRUIT,
		"hero_recruit": SFX.HERO_RECRUIT,
		"event_trigger": SFX.EVENT_TRIGGER,
		"waaagh": SFX.WAAAGH,
		"level_up": SFX.LEVEL_UP,
		"turn_start": SFX.TURN_START,
		"turn_end": SFX.TURN_END,
		"combat_start": SFX.COMBAT_ATTACK,
		"victory": SFX.VICTORY,
		"defeat": SFX.DEFEAT,
	}


func _generate_procedural_sounds() -> void:
	## Generate simple procedural audio for UI feedback so the game is not silent.
	## These are used as fallbacks when .ogg files do not exist.
	_procedural_click = _make_click_tone(800.0, 0.06)
	_procedural_confirm = _make_click_tone(1000.0, 0.1)


## Create a short sine-wave "click" tone as an AudioStreamWAV.
static func _make_click_tone(freq: float, duration: float, sample_rate: int = 22050) -> AudioStreamWAV:
	var num_samples: int = int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(num_samples * 2)  # 16-bit mono
	for i in range(num_samples):
		var t: float = float(i) / sample_rate
		# Envelope: quick attack, fast decay
		var envelope: float = clampf(1.0 - t / duration, 0.0, 1.0)
		envelope *= envelope  # quadratic decay
		var sample_val: float = sin(TAU * freq * t) * envelope * 0.4
		var s16: int = clampi(int(sample_val * 32767.0), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _setup_audio_buses() -> void:
	# Check if buses already exist (from .tres), if not create them
	if AudioServer.get_bus_index("BGM") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "BGM")
		AudioServer.set_bus_send(AudioServer.get_bus_index("BGM"), "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Master")
	if AudioServer.get_bus_index("Ambient") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Ambient")
		AudioServer.set_bus_send(AudioServer.get_bus_index("Ambient"), "Master")


func _setup_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = BUS_BGM
	_bgm_player.volume_db = linear_to_db(bgm_volume)
	add_child(_bgm_player)

	_bgm_player_next = AudioStreamPlayer.new()
	_bgm_player_next.name = "BGMPlayerNext"
	_bgm_player_next.bus = BUS_BGM
	_bgm_player_next.volume_db = -80.0
	add_child(_bgm_player_next)

	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = BUS_SFX
		player.volume_db = linear_to_db(sfx_volume)
		add_child(player)
		_sfx_players.append(player)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.bus = BUS_AMBIENT
	_ambient_player.volume_db = linear_to_db(ambient_volume)
	add_child(_ambient_player)


func _connect_signals() -> void:
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_result.connect(_on_combat_result)
	EventBus.game_over.connect(_on_game_over)
	EventBus.tile_captured.connect(_on_tile_captured)
	EventBus.tile_lost.connect(_on_tile_lost)
	EventBus.hero_captured.connect(_on_hero_captured)
	EventBus.tech_effects_applied.connect(_on_research_complete)
	EventBus.waaagh_changed.connect(_on_waaagh_changed)
	EventBus.event_triggered.connect(_on_event_triggered)
	EventBus.hero_recruited.connect(_on_hero_recruited)
	EventBus.hero_leveled_up.connect(_on_hero_leveled_up)
	# Combat SFX signals
	EventBus.sfx_attack.connect(_on_sfx_attack)
	EventBus.sfx_unit_killed.connect(_on_sfx_unit_killed)
	EventBus.sfx_hero_knockout.connect(_on_sfx_hero_knockout)
	EventBus.sfx_round_start.connect(_on_sfx_round_start)
	EventBus.sfx_battle_result.connect(_on_sfx_battle_result)


# ═══════════════ BGM ═══════════════

func play_bgm(track: int, crossfade: float = 1.0) -> void:
	if track == _current_bgm:
		return
	if not _bgm_paths.has(track):
		_current_bgm = track
		return  # No audio file path registered

	var path: String = _bgm_paths[track]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: BGM file not found: %s (track=%d)" % [path, track])
		_current_bgm = track
		return

	var stream = load(path)
	if stream == null:
		push_warning("AudioManager: Failed to load BGM file: %s (track=%d)" % [path, track])
		return

	_current_bgm = track

	if crossfade > 0.0 and _bgm_player.playing:
		_crossfade_bgm(stream, crossfade)
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = linear_to_db(bgm_volume)
		_bgm_player.play()


func stop_bgm(fade_time: float = 0.5) -> void:
	_current_bgm = -1
	if fade_time > 0.0:
		var tween := create_tween()
		tween.tween_property(_bgm_player, "volume_db", -80.0, fade_time)
		tween.tween_callback(_bgm_player.stop)
	else:
		_bgm_player.stop()


func _crossfade_bgm(new_stream: AudioStream, duration: float) -> void:
	_bgm_player_next.stream = new_stream
	_bgm_player_next.volume_db = -80.0
	_bgm_player_next.play()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_bgm_player, "volume_db", -80.0, duration)
	tween.tween_property(_bgm_player_next, "volume_db", linear_to_db(bgm_volume), duration)
	tween.set_parallel(false)
	tween.tween_callback(_swap_bgm_players)


func _swap_bgm_players() -> void:
	_bgm_player.stop()
	var temp := _bgm_player
	_bgm_player = _bgm_player_next
	_bgm_player_next = temp


# ═══════════════ SFX ═══════════════

func play_sfx(sfx_id: int) -> void:
	if master_muted:
		return
	if not _sfx_paths.has(sfx_id):
		return  # No audio file path registered

	var stream: AudioStream = null
	var path: String = _sfx_paths[sfx_id]
	if ResourceLoader.exists(path):
		stream = load(path)

	# Fallback to procedural sounds if file not found
	if stream == null:
		stream = _get_procedural_fallback(sfx_id)
	if stream == null:
		return

	# Find available player
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume)
			player.play()
			return

	# All busy, override oldest
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


# ═══════════════ UI AUDIO HELPERS ═══════════════

func play_ui_click() -> void:
	play_sfx(SFX.UI_CLICK)


func play_ui_confirm() -> void:
	play_sfx(SFX.UI_CONFIRM)


func play_ui_cancel() -> void:
	play_sfx(SFX.UI_CANCEL)


## Get a procedural fallback sound for common SFX when .ogg files are missing.
func _get_procedural_fallback(sfx_id: int) -> AudioStream:
	match sfx_id:
		SFX.UI_CLICK, SFX.UI_HOVER:
			return _procedural_click
		SFX.UI_CONFIRM:
			return _procedural_confirm
		SFX.UI_CANCEL:
			return _procedural_click
	return null


## Play an SFX by string name (e.g. "turn_start", "capture", "recruit").
## Returns true if the sound was found and played.
func play_sfx_by_name(sfx_name: String) -> bool:
	if _sfx_name_map.has(sfx_name):
		play_sfx(_sfx_name_map[sfx_name])
		return true
	push_warning("AudioManager: Unknown SFX name '%s'" % sfx_name)
	return false


## Play music by BGMTrack enum or track name string.
func play_music(track) -> void:
	if track is int:
		play_bgm(track)
	elif track is String:
		var track_map: Dictionary = {
			"title": BGMTrack.TITLE,
			"faction_select": BGMTrack.FACTION_SELECT,
			"overworld_calm": BGMTrack.OVERWORLD_CALM,
			"overworld_tense": BGMTrack.OVERWORLD_TENSE,
			"combat_normal": BGMTrack.COMBAT_NORMAL,
			"combat_boss": BGMTrack.COMBAT_BOSS,
			"victory": BGMTrack.VICTORY,
			"defeat": BGMTrack.DEFEAT,
			"event": BGMTrack.EVENT,
		}
		if track_map.has(track):
			play_bgm(track_map[track])
		else:
			push_warning("AudioManager: Unknown music track name '%s'" % track)


## Stop currently playing music.
func stop_music(fade_time: float = 0.5) -> void:
	stop_bgm(fade_time)


## Set volume for a named bus ("Master", "BGM", "SFX", "Ambient").
## value is 0.0 to 1.0 (linear).
func set_volume(bus_name: String, value: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		push_warning("AudioManager: Audio bus '%s' not found" % bus_name)
		return
	var vol: float = clampf(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(vol))
	# Keep internal state in sync
	match bus_name:
		"BGM":
			bgm_volume = vol
			_bgm_player.volume_db = linear_to_db(vol)
		"SFX":
			sfx_volume = vol
			for player in _sfx_players:
				player.volume_db = linear_to_db(vol)
		"Ambient":
			ambient_volume = vol
			_ambient_player.volume_db = linear_to_db(vol)
		"Master":
			pass  # Master bus volume is set directly on AudioServer


# ═══════════════ VOLUME CONTROL ═══════════════

func set_bgm_volume(vol: float) -> void:
	bgm_volume = clampf(vol, 0.0, 1.0)
	_bgm_player.volume_db = linear_to_db(bgm_volume)

func set_sfx_volume(vol: float) -> void:
	sfx_volume = clampf(vol, 0.0, 1.0)
	for player in _sfx_players:
		player.volume_db = linear_to_db(sfx_volume)

func set_ambient_volume(vol: float) -> void:
	ambient_volume = clampf(vol, 0.0, 1.0)
	_ambient_player.volume_db = linear_to_db(ambient_volume)

func toggle_mute() -> void:
	master_muted = not master_muted
	AudioServer.set_bus_mute(0, master_muted)


# ═══════════════ SIGNAL HANDLERS ═══════════════

func _on_turn_started(_pid: int) -> void:
	play_sfx(SFX.TURN_START)
	# Switch BGM based on threat level
	if ThreatManager.get_threat() >= 60:
		play_bgm(BGMTrack.OVERWORLD_TENSE)
	else:
		play_bgm(BGMTrack.OVERWORLD_CALM)

func _on_combat_started(_atk_id: int, _tile: int) -> void:
	play_bgm(BGMTrack.COMBAT_NORMAL, 0.5)

func _on_combat_result(_atk_id: int, _desc: String, won: bool) -> void:
	if won:
		play_sfx(SFX.COMBAT_ATTACK)
	play_bgm(BGMTrack.OVERWORLD_CALM, 1.0)

func _on_game_over(_winner: int) -> void:
	if _winner == GameManager.get_human_player_id():
		play_bgm(BGMTrack.VICTORY, 0.3)
	else:
		play_bgm(BGMTrack.DEFEAT, 0.3)

func _on_tile_captured(_pid: int, _tile: int) -> void:
	play_sfx(SFX.MAP_CAPTURE)

func _on_tile_lost(_pid: int, _tile: int) -> void:
	play_sfx(SFX.MAP_LOST)

func _on_hero_captured(_hero_id: String) -> void:
	play_sfx(SFX.HERO_CAPTURE)

func _on_research_complete(_pid: int) -> void:
	play_sfx(SFX.RESEARCH_COMPLETE)

func _on_waaagh_changed(_pid: int, value: int) -> void:
	if value >= 80:
		play_sfx(SFX.WAAAGH)

func _on_event_triggered(_pid: int, _name: String, _desc: String) -> void:
	play_sfx(SFX.EVENT_TRIGGER)

func _on_hero_recruited(_hero_id: String) -> void:
	play_sfx(SFX.HERO_RECRUIT)

func _on_hero_leveled_up(_hero_id: String, _new_level: int) -> void:
	play_sfx(SFX.LEVEL_UP)


# ═══════════════ COMBAT SFX SIGNAL HANDLERS ═══════════════

func _on_sfx_attack(_unit_class: String, is_crit: bool) -> void:
	if is_crit:
		play_sfx(SFX.COMBAT_CRITICAL)
	else:
		play_sfx(SFX.COMBAT_ATTACK)

func _on_sfx_unit_killed(_side: String) -> void:
	play_sfx(SFX.COMBAT_DEATH)

func _on_sfx_hero_knockout(_hero_name: String) -> void:
	play_sfx(SFX.COMBAT_DEATH)

func _on_sfx_round_start(_round_num: int) -> void:
	play_sfx(SFX.TURN_START)

func _on_sfx_battle_result(winner: String) -> void:
	if winner == "player":
		play_sfx(SFX.VICTORY)
	else:
		play_sfx(SFX.DEFEAT)


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"bgm_volume": bgm_volume,
		"sfx_volume": sfx_volume,
		"ambient_volume": ambient_volume,
		"master_muted": master_muted,
	}

func from_save_data(data: Dictionary) -> void:
	bgm_volume = data.get("bgm_volume", 0.7)
	sfx_volume = data.get("sfx_volume", 0.8)
	ambient_volume = data.get("ambient_volume", 0.5)
	master_muted = data.get("master_muted", false)
	set_bgm_volume(bgm_volume)
	set_sfx_volume(sfx_volume)
	set_ambient_volume(ambient_volume)
	if master_muted:
		AudioServer.set_bus_mute(0, true)
