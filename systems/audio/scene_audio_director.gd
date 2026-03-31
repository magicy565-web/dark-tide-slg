## scene_audio_director.gd - Automatic BGM switching based on game state (v1.0)
## Listens to game events and transitions music for atmospheric consistency.
extends Node

# Scene states that determine BGM
enum SceneState {
	TITLE, FACTION_SELECT, MAP_CALM, MAP_TENSE,
	COMBAT_NORMAL, COMBAT_BOSS, COMBAT_CRISIS, COMBAT_ADVANTAGE,
	EVENT, STORY, VICTORY, DEFEAT
}

var _current_state: int = SceneState.TITLE
var _combat_active: bool = false
var _suppress_auto: bool = false  # True when VnDirector is managing BGM

# Threat thresholds for map BGM
const THREAT_TENSE_THRESHOLD: int = 50
const THREAT_CRISIS_THRESHOLD: int = 80

func _ready() -> void:
	# Connect to game state signals
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_view_closed.connect(_on_combat_ended)
	EventBus.game_over.connect(_on_game_over)
	EventBus.vn_scene_started.connect(_on_vn_started)
	EventBus.vn_scene_ended.connect(_on_vn_ended)
	EventBus.grand_event_started.connect(_on_grand_event_started)
	EventBus.grand_event_ended.connect(_on_grand_event_ended)
	# Initial state
	_switch_state(SceneState.TITLE)


func _on_turn_started(player_id: int) -> void:
	if _combat_active or _suppress_auto:
		return
	# Check threat level for map BGM
	var threat: int = 0
	if ThreatManager:
		threat = ThreatManager.get_threat()
	if threat >= THREAT_CRISIS_THRESHOLD:
		_switch_state(SceneState.MAP_TENSE)
	elif threat >= THREAT_TENSE_THRESHOLD:
		_switch_state(SceneState.MAP_TENSE)
	else:
		_switch_state(SceneState.MAP_CALM)


func _on_combat_started(_attacker_id: int, _tile_index: int) -> void:
	_combat_active = true
	# Boss detection: check if defending tile has boss flag
	_switch_state(SceneState.COMBAT_NORMAL)


func _on_combat_ended() -> void:
	_combat_active = false
	_on_turn_started(0)  # Restore map BGM


func _on_game_over(winner_id: int) -> void:
	var human_id: int = GameManager.get_human_player_id() if GameManager else 0
	if winner_id == human_id:
		_switch_state(SceneState.VICTORY)
	else:
		_switch_state(SceneState.DEFEAT)


func _on_vn_started(_l: String, _r: String, _mood: String) -> void:
	_suppress_auto = true  # VnDirector handles BGM


func _on_vn_ended() -> void:
	_suppress_auto = false
	_on_turn_started(0)  # Restore appropriate BGM


func _on_grand_event_started(_event_id: String) -> void:
	_suppress_auto = true
	_switch_state(SceneState.EVENT)


func _on_grand_event_ended(_event_id: String) -> void:
	_suppress_auto = false
	_on_turn_started(0)


## Update combat BGM based on battle HP ratios (called from combat_view)
func update_combat_intensity(our_hp_ratio: float, enemy_hp_ratio: float, is_boss: bool = false) -> void:
	if not _combat_active:
		return
	if our_hp_ratio < 0.3:
		_switch_state(SceneState.COMBAT_CRISIS)
	elif enemy_hp_ratio < 0.3:
		_switch_state(SceneState.COMBAT_ADVANTAGE)
	elif is_boss:
		_switch_state(SceneState.COMBAT_BOSS)
	else:
		_switch_state(SceneState.COMBAT_NORMAL)


func _switch_state(new_state: int) -> void:
	if new_state == _current_state:
		return
	_current_state = new_state
	if not AudioManager:
		return
	match new_state:
		SceneState.TITLE:
			AudioManager.play_bgm(AudioManager.BGMTrack.TITLE)
		SceneState.FACTION_SELECT:
			AudioManager.play_bgm(AudioManager.BGMTrack.FACTION_SELECT)
		SceneState.MAP_CALM:
			AudioManager.play_bgm(AudioManager.BGMTrack.OVERWORLD_CALM)
		SceneState.MAP_TENSE:
			AudioManager.play_bgm(AudioManager.BGMTrack.OVERWORLD_TENSE)
		SceneState.COMBAT_NORMAL:
			AudioManager.play_bgm(AudioManager.BGMTrack.COMBAT_NORMAL)
		SceneState.COMBAT_BOSS:
			AudioManager.play_bgm(AudioManager.BGMTrack.COMBAT_BOSS)
		SceneState.COMBAT_CRISIS:
			AudioManager.play_bgm(AudioManager.BGMTrack.COMBAT_CRISIS)
		SceneState.COMBAT_ADVANTAGE:
			AudioManager.play_bgm(AudioManager.BGMTrack.COMBAT_ADVANTAGE)
		SceneState.EVENT:
			AudioManager.play_bgm(AudioManager.BGMTrack.EVENT)
		SceneState.STORY:
			AudioManager.play_bgm(AudioManager.BGMTrack.EVENT)
		SceneState.VICTORY:
			AudioManager.play_bgm(AudioManager.BGMTrack.VICTORY)
		SceneState.DEFEAT:
			AudioManager.play_bgm(AudioManager.BGMTrack.DEFEAT)
