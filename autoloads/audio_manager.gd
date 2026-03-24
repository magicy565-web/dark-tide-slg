## audio_manager.gd - Sound & Music system for 暗潮 SLG (v1.5)
## Manages BGM, SFX, and ambient sounds. Works without actual audio files
## by providing the interface; audio files can be added later.
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
}

# ── Audio file paths (to be filled when assets are available) ──
var _bgm_paths: Dictionary = {
	# BGMTrack.TITLE: "res://assets/audio/bgm/title.ogg",
}

var _sfx_paths: Dictionary = {
	# SFX.UI_CLICK: "res://assets/audio/sfx/ui_click.wav",
}

# ── Players ──
var _bgm_player: AudioStreamPlayer
var _bgm_player_next: AudioStreamPlayer  # For crossfade
var _sfx_players: Array = []
const MAX_SFX_PLAYERS: int = 8
var _ambient_player: AudioStreamPlayer

# ── State ──
var _current_bgm: int = -1
var _crossfading: bool = false


func _ready() -> void:
	_setup_audio_buses()
	_setup_players()
	_connect_signals()


func _setup_audio_buses() -> void:
	# In a real Godot project, audio buses are set up in the Audio Bus Layout.
	# This creates them programmatically as fallback.
	pass


func _setup_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = BUS_MASTER
	_bgm_player.volume_db = linear_to_db(bgm_volume)
	add_child(_bgm_player)

	_bgm_player_next = AudioStreamPlayer.new()
	_bgm_player_next.name = "BGMPlayerNext"
	_bgm_player_next.bus = BUS_MASTER
	_bgm_player_next.volume_db = -80.0
	add_child(_bgm_player_next)

	for i in range(MAX_SFX_PLAYERS):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer_%d" % i
		player.bus = BUS_MASTER
		player.volume_db = linear_to_db(sfx_volume)
		add_child(player)
		_sfx_players.append(player)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.bus = BUS_MASTER
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
	EventBus.research_completed.connect(_on_research_complete)
	EventBus.waaagh_changed.connect(_on_waaagh_changed)
	EventBus.event_triggered.connect(_on_event_triggered)


# ═══════════════ BGM ═══════════════

func play_bgm(track: int, crossfade: float = 1.0) -> void:
	if track == _current_bgm:
		return
	if not _bgm_paths.has(track):
		_current_bgm = track
		return  # No audio file yet, just track state

	var stream = load(_bgm_paths[track])
	if stream == null:
		push_warning("AudioManager: Failed to load BGM file: %s (track=%d)" % [_bgm_paths[track], track])
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
		return  # No audio file yet

	var stream = load(_sfx_paths[sfx_id])
	if stream == null:
		push_warning("AudioManager: Failed to load SFX file: %s (sfx_id=%d)" % [_sfx_paths[sfx_id], sfx_id])
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

func _on_research_complete(_pid: int, _fid: int) -> void:
	play_sfx(SFX.RESEARCH_COMPLETE)

func _on_waaagh_changed(_pid: int, value: int) -> void:
	if value >= 80:
		play_sfx(SFX.WAAAGH)

func _on_event_triggered(_pid: int, _name: String, _desc: String) -> void:
	play_sfx(SFX.EVENT_TRIGGER)


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
