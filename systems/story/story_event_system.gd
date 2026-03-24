## story_event_system.gd - Story event progression manager for all heroines (v1.0)
## Manages route branching (training/pure_love), event sequencing, triggers,
## and integration with HeroSystem affection/capture state.
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Character story data references ──
# Lazy-loaded per character to avoid massive upfront memory cost.
var _story_cache: Dictionary = {}  # hero_id -> story data dictionary

# ── Progression state (serialized by save system) ──
# hero_id -> { "route": String, "current_event": int, "completed_events": Array, "flags": Dictionary }
var story_progress: Dictionary = {}

# ── Reentrant guard ──
# Prevents chain-triggering when event effects change affection/corruption
var _processing_effects: bool = false

# ── Route constants ──
const ROUTE_TRAINING := "training"       # 调教路线 (hostile capture)
const ROUTE_PURE_LOVE := "pure_love"     # 纯爱路线 (post-defeat join)
const ROUTE_FRIENDLY := "friendly"       # 友好路线 (early pure love, neutral chars)
const ROUTE_NEUTRAL := "neutral"         # 中立路线 (quest chain, neutral chars)
const ROUTE_HOSTILE := "hostile"         # 敌对路线 (neutral char conquest)

# ── Data file mapping ──
const STORY_DATA_FILES: Dictionary = {
	"rin":      "res://systems/story/data/rin_story.gd",
	"yukino":   "res://systems/story/data/yukino_story.gd",
	"momiji":   "res://systems/story/data/momiji_story.gd",
	"hyouka":   "res://systems/story/data/hyouka_story.gd",
	"suirei":   "res://systems/story/data/suirei_story.gd",
	"gekka":    "res://systems/story/data/gekka_story.gd",
	"hakagure": "res://systems/story/data/hakagure_story.gd",
	"sou":      "res://systems/story/data/sou_story.gd",
	"shion":    "res://systems/story/data/shion_story.gd",
	"homura":   "res://systems/story/data/homura_story.gd",
	"hibiki":   "res://systems/story/data/hibiki_story.gd",
	"sara":     "res://systems/story/data/sara_story.gd",
	"mei":      "res://systems/story/data/mei_story.gd",
	"kaede":    "res://systems/story/data/kaede_story.gd",
	"akane":    "res://systems/story/data/akane_story.gd",
	"hanabi":   "res://systems/story/data/hanabi_story.gd",
}

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	_connect_signals()


func reset() -> void:
	story_progress.clear()
	_story_cache.clear()


func _connect_signals() -> void:
	EventBus.hero_captured.connect(_on_hero_captured)
	EventBus.hero_recruited.connect(_on_hero_recruited)
	EventBus.hero_affection_changed.connect(_on_affection_changed)
	if EventBus.has_signal("story_choice_made"):
		EventBus.story_choice_made.connect(_on_story_choice_made)


# ═══════════════ STORY DATA LOADING ═══════════════

## Lazy-load a character's story data. Returns the full event dictionary.
func _get_story_data(hero_id: String) -> Dictionary:
	if _story_cache.has(hero_id):
		return _story_cache[hero_id]
	var path: String = STORY_DATA_FILES.get(hero_id, "")
	if path == "":
		push_warning("StoryEventSystem: No story data file for hero '%s'" % hero_id)
		return {}
	if not ResourceLoader.exists(path):
		push_warning("StoryEventSystem: Story data file not found: %s" % path)
		return {}
	var script: GDScript = load(path)
	if script == null:
		push_warning("StoryEventSystem: Failed to load story script: %s" % path)
		return {}
	# Story data scripts expose a static EVENTS dictionary
	var data: Dictionary = script.get("EVENTS") if script.has_method("get") else {}
	if data.is_empty():
		# Try instantiating the class to get EVENTS const
		var instance = script.new()
		if instance and "EVENTS" in instance:
			data = instance.EVENTS
	_story_cache[hero_id] = data
	return data


# ═══════════════ PROGRESSION MANAGEMENT ═══════════════

## Initialize story progress for a hero when first encountered.
func _init_progress(hero_id: String, route: String) -> void:
	if story_progress.has(hero_id):
		return
	story_progress[hero_id] = {
		"route": route,
		"current_event": 0,
		"completed_events": [],
		"flags": {},
	}


## Get current progress for a hero.
func get_progress(hero_id: String) -> Dictionary:
	return story_progress.get(hero_id, {})


## Get the active route for a hero.
func get_route(hero_id: String) -> String:
	return story_progress.get(hero_id, {}).get("route", "")


## Check if a specific event has been completed.
func is_event_completed(hero_id: String, event_id: String) -> bool:
	var prog: Dictionary = story_progress.get(hero_id, {})
	return event_id in prog.get("completed_events", [])


## Set a story flag for a hero (used by choices/branching).
func set_flag(hero_id: String, flag: String, value: Variant = true) -> void:
	if story_progress.has(hero_id):
		story_progress[hero_id]["flags"][flag] = value


## Get a story flag.
func get_flag(hero_id: String, flag: String, default: Variant = null) -> Variant:
	return story_progress.get(hero_id, {}).get("flags", {}).get(flag, default)


# ═══════════════ EVENT RETRIEVAL ═══════════════

## Get all events for a hero on a specific route.
func get_route_events(hero_id: String, route: String) -> Array:
	var data: Dictionary = _get_story_data(hero_id)
	return data.get(route, [])


## Get the next event for a hero based on current progress.
func get_next_event(hero_id: String) -> Dictionary:
	var prog: Dictionary = story_progress.get(hero_id, {})
	if prog.is_empty():
		return {}
	var route: String = prog.get("route", "")
	var current_idx: int = prog.get("current_event", 0)
	var events: Array = get_route_events(hero_id, route)
	if current_idx >= events.size():
		return {}  # All events completed for this route
	return events[current_idx]


## Get a specific event by ID.
func get_event_by_id(hero_id: String, event_id: String) -> Dictionary:
	var data: Dictionary = _get_story_data(hero_id)
	for route_key in data:
		var events: Array = data[route_key]
		for event in events:
			if event.get("id", "") == event_id:
				return event
	return {}


# ═══════════════ EVENT TRIGGERING ═══════════════

## 跳过事件：标记为完成但不播放（用于自动跳过中间事件）
func skip_event(hero_id: String) -> void:
	var prog: Dictionary = story_progress.get(hero_id, {})
	if prog.is_empty():
		return
	var route: String = prog.get("route", "")
	var current_idx: int = prog.get("current_event", 0)
	var events: Array = get_route_events(hero_id, route)
	if current_idx >= events.size():
		return
	var event: Dictionary = events[current_idx]
	var event_id: String = event.get("id", "event_%d" % current_idx)
	prog["completed_events"].append(event_id)
	prog["current_event"] = current_idx + 1
	# 不播放效果，仅标记完成
	EventBus.story_event_completed.emit(hero_id, event_id)
	if prog["current_event"] >= events.size():
		EventBus.story_route_completed.emit(hero_id, route)


## Check if the next event for a hero should trigger.
func check_trigger(hero_id: String) -> bool:
	var event: Dictionary = get_next_event(hero_id)
	if event.is_empty():
		return false
	var trigger: Dictionary = event.get("trigger", {})
	if _evaluate_trigger(hero_id, trigger):
		return true
	# 自动跳过卡住的中间事件：如果当前事件因 prev_event 未完成而阻塞，
	# 但后续事件的其他条件（如好感度）已远超阈值，则静默完成当前事件
	if trigger.has("prev_event") and not is_event_completed(hero_id, trigger["prev_event"]):
		var prog: Dictionary = story_progress.get(hero_id, {})
		var route: String = prog.get("route", "")
		var current_idx: int = prog.get("current_event", 0)
		var events: Array = get_route_events(hero_id, route)
		# 检查后续事件(N+2)的条件是否已满足（排除 prev_event 检查）
		if current_idx + 1 < events.size():
			var next_event: Dictionary = events[current_idx + 1]
			var next_trigger: Dictionary = next_event.get("trigger", {})
			var next_conditions_met: bool = true
			for key in next_trigger:
				if key == "prev_event":
					continue  # 跳过前置事件检查
				var temp_trigger: Dictionary = {key: next_trigger[key]}
				if not _evaluate_trigger(hero_id, temp_trigger):
					next_conditions_met = false
					break
			if next_conditions_met and not next_trigger.is_empty():
				push_warning("StoryEventSystem: 自动跳过卡住的事件 hero=%s idx=%d" % [hero_id, current_idx])
				skip_event(hero_id)
				return check_trigger(hero_id)
	return false


## Attempt to trigger the next story event for a hero.
## Returns the event data if triggered, empty dict otherwise.
func try_trigger_next(hero_id: String) -> Dictionary:
	# Guard against reentrant calls from effect-triggered signals
	if _processing_effects:
		return {}
	if not check_trigger(hero_id):
		return {}
	var event: Dictionary = get_next_event(hero_id)
	if event.is_empty():
		return {}
	# Emit signal for UI to display the event
	EventBus.story_event_triggered.emit(hero_id, event)
	return event


## Mark current event as completed and advance to next.
func complete_current_event(hero_id: String) -> void:
	var prog: Dictionary = story_progress.get(hero_id, {})
	if prog.is_empty():
		return
	var route: String = prog.get("route", "")
	var current_idx: int = prog.get("current_event", 0)
	var events: Array = get_route_events(hero_id, route)
	if current_idx < events.size():
		var event: Dictionary = events[current_idx]
		var event_id: String = event.get("id", "event_%d" % current_idx)
		prog["completed_events"].append(event_id)
		prog["current_event"] = current_idx + 1
		# Apply event effects
		_apply_event_effects(hero_id, event)
		# Emit completion signal
		EventBus.story_event_completed.emit(hero_id, event_id)
		# Check if route is complete
		if prog["current_event"] >= events.size():
			EventBus.story_route_completed.emit(hero_id, route)


# ═══════════════ TRIGGER EVALUATION ═══════════════

func _evaluate_trigger(hero_id: String, trigger: Dictionary) -> bool:
	if trigger.is_empty():
		return true  # No conditions = always available
	# Check each condition
	for key in trigger:
		match key:
			"hero_captured":
				if hero_id not in HeroSystem.captured_heroes and hero_id not in HeroSystem.recruited_heroes:
					return false
			"hero_recruited":
				if hero_id not in HeroSystem.recruited_heroes:
					return false
			"affection_min":
				if HeroSystem.hero_affection.get(hero_id, 0) < trigger[key]:
					return false
			"corruption_min":
				if HeroSystem.hero_corruption.get(hero_id, 0) < trigger[key]:
					return false
			"prev_event":
				if not is_event_completed(hero_id, trigger[key]):
					return false
			"flag":
				var flag_data: Dictionary = trigger[key]
				for flag_key in flag_data:
					if get_flag(hero_id, flag_key) != flag_data[flag_key]:
						return false
			"turn_min":
				if GameManager.turn_number < trigger[key]:
					return false
			"tiles_min":
				var pid: int = GameManager.get_human_player_id()
				if GameManager.count_tiles_owned(pid) < trigger[key]:
					return false
			"threat_min":
				if ThreatManager.get_threat() < trigger[key]:
					return false
			"order_min":
				if OrderManager.get_order() < trigger[key]:
					return false
	return true


# ═══════════════ EFFECT APPLICATION ═══════════════

func _apply_event_effects(hero_id: String, event: Dictionary) -> void:
	var effects: Dictionary = event.get("effects", {})
	if effects.is_empty():
		return
	_processing_effects = true  # Guard: prevent reentrant triggering from signal handlers
	var pid: int = GameManager.get_human_player_id()
	for key in effects:
		match key:
			"affection":
				var current: int = HeroSystem.hero_affection.get(hero_id, 0)
				HeroSystem.hero_affection[hero_id] = clampi(current + effects[key], 0, 10)
				EventBus.hero_affection_changed.emit(hero_id, HeroSystem.hero_affection[hero_id])
			"training_progress":
				set_flag(hero_id, "training_progress",
					get_flag(hero_id, "training_progress", 0) + effects[key])
			"loyalty":
				set_flag(hero_id, "loyalty",
					get_flag(hero_id, "loyalty", 0) + effects[key])
			"gold":
				ResourceManager.apply_delta(pid, {"gold": effects[key]})
			"soldiers":
				ResourceManager.add_army(pid, effects[key])
			"iron":
				ResourceManager.apply_delta(pid, {"iron": effects[key]})
			"food":
				ResourceManager.apply_delta(pid, {"food": effects[key]})
			"slaves":
				ResourceManager.apply_delta(pid, {"slaves": effects[key]})
			"order":
				OrderManager.change_order(effects[key])
			"threat":
				ThreatManager.change_threat(effects[key])
			"unlock_skill":
				set_flag(hero_id, "skill_unlocked_" + effects[key], true)
			"set_flag":
				var flag_dict: Dictionary = effects[key]
				for f in flag_dict:
					set_flag(hero_id, f, flag_dict[f])
	_processing_effects = false  # Release guard
	# 延迟检查：效果处理期间被跳过的事件触发，在效果完成后重新检查
	call_deferred("_check_deferred_triggers", hero_id)


## 延迟触发检查：在效果处理完毕后重新尝试触发下一个事件
func _check_deferred_triggers(hero_id: String) -> void:
	try_trigger_next(hero_id)


# ═══════════════ SIGNAL HANDLERS ═══════════════

func _on_hero_captured(hero_id: String) -> void:
	# Skip heroes without story data (e.g. faction auto-join heroes like shion_pirate, youya)
	if hero_id not in STORY_DATA_FILES:
		return
	# Determine if this is a main heroine (training route) or neutral (hostile route)
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	var faction: String = hero_data.get("faction", "")
	if faction == "neutral":
		_init_progress(hero_id, ROUTE_HOSTILE)
	else:
		_init_progress(hero_id, ROUTE_TRAINING)
	# Try to trigger the first event
	try_trigger_next(hero_id)


func _on_hero_recruited(hero_id: String) -> void:
	# Skip heroes without story data
	if hero_id not in STORY_DATA_FILES:
		return
	var hero_data: Dictionary = FactionData.HEROES.get(hero_id, {})
	var faction: String = hero_data.get("faction", "")
	# 如果已有进度且当前为调教路线，切换到纯爱路线（俘虏后招募的路线转换）
	if story_progress.has(hero_id):
		if story_progress[hero_id]["route"] == ROUTE_TRAINING:
			story_progress[hero_id]["route"] = ROUTE_PURE_LOVE
			story_progress[hero_id]["current_event"] = 0
	else:
		# 首次招募，无俘虏记录：根据阵营初始化路线
		if faction == "neutral":
			_init_progress(hero_id, ROUTE_NEUTRAL)
		else:
			_init_progress(hero_id, ROUTE_PURE_LOVE)
	try_trigger_next(hero_id)


func _on_affection_changed(hero_id: String, new_value: int) -> void:
	# Check if affection threshold triggers next event
	try_trigger_next(hero_id)


func _on_story_choice_made(hero_id: String, event_id: String, choice_index: int) -> void:
	var event: Dictionary = get_event_by_id(hero_id, event_id)
	if event.is_empty():
		return
	var choices: Array = event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		return
	var choice: Dictionary = choices[choice_index]
	# Apply choice-specific effects
	var choice_effects: Dictionary = choice.get("effects", {})
	if not choice_effects.is_empty():
		_apply_event_effects(hero_id, {"effects": choice_effects})
	# Set choice flag for future branching
	set_flag(hero_id, "choice_%s" % event_id, choice_index)


# ═══════════════ TURN PROCESSING ═══════════════

## Called each turn to check for auto-triggering story events.
func process_story_turn() -> void:
	# 清理pass：跳过无有效剧情数据的hero_id，防止孤立进度导致错误
	var orphaned: Array = []
	for hero_id in story_progress:
		var data: Dictionary = _get_story_data(hero_id)
		if data.is_empty():
			orphaned.append(hero_id)
	for hero_id in orphaned:
		push_warning("StoryEventSystem: hero_id '%s' 无有效剧情数据，跳过处理" % hero_id)
	# Check all heroes with active story progress
	for hero_id in story_progress:
		if hero_id in orphaned:
			continue
		try_trigger_next(hero_id)


# ═══════════════ SAVE / LOAD ═══════════════

func get_save_data() -> Dictionary:
	return {
		"story_progress": story_progress.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	story_progress = data.get("story_progress", {}).duplicate(true)


## Aliases for SaveManager compatibility
func to_save_data() -> Dictionary:
	return get_save_data()


func from_save_data(data: Dictionary) -> void:
	load_save_data(data)


# ═══════════════ DEBUG / QUERY ═══════════════

## Get total event count for a hero across all routes.
func get_total_events(hero_id: String) -> int:
	var data: Dictionary = _get_story_data(hero_id)
	var total: int = 0
	for route_key in data:
		total += data[route_key].size()
	return total


## Get completion percentage for a hero's current route.
func get_completion_percent(hero_id: String) -> float:
	var prog: Dictionary = story_progress.get(hero_id, {})
	if prog.is_empty():
		return 0.0
	var route: String = prog.get("route", "")
	var events: Array = get_route_events(hero_id, route)
	if events.is_empty():
		return 0.0
	return float(prog.get("current_event", 0)) / float(events.size()) * 100.0
