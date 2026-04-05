## story_event_system.gd - Story event progression manager for all heroines (v2.0)
## Manages route branching (training/pure_love), event sequencing, triggers,
## deep story branching with player choices, and integration with HeroSystem.
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Signals ──
signal story_choice_requested(hero_id: String, event_id: String, choices: Array)

# ── Character story data references ──
# Lazy-loaded per character to avoid massive upfront memory cost.
var _story_cache: Dictionary = {}  # hero_id -> story data dictionary

# ── Progression state (serialized by save system) ──
# hero_id -> { "route": String, "current_event": int, "completed_events": Array, "flags": Dictionary }
var story_progress: Dictionary = {}

# ── Choice history (serialized by save system) ──
# hero_id -> { event_id -> choice_index }
var _choice_history: Dictionary = {}

# ── Pending choice state ──
# Stores events waiting for player choice resolution.
# hero_id -> { "event_id": String, "event": Dictionary }
var _pending_choices: Dictionary = {}

# ── Reentrant guard ──
# Prevents chain-triggering when event effects change affection/corruption
var _processing_effects: bool = false

# ── Route constants ──
const ROUTE_TRAINING := "training"       # 调教路线 (hostile capture)
const ROUTE_PURE_LOVE := "pure_love"     # 纯爱路线 (post-defeat join)
const ROUTE_FRIENDLY := "friendly"       # 友好路线 (early pure love, neutral chars)
const ROUTE_NEUTRAL := "neutral"         # 中立路线 (quest chain, neutral chars)
const ROUTE_HOSTILE := "hostile"         # 敌对路线 (neutral char conquest)

# Routes that auto-trigger (conquest chain - battle/capture events)
const AUTO_TRIGGER_ROUTES: Array = ["hostile"]
# Routes that require manual trigger from mission panel
const MANUAL_TRIGGER_ROUTES: Array = ["training", "pure_love", "neutral", "friendly"]

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
	"epilogue": "res://systems/story/data/epilogue_events.gd",
}

# ═══════════════ LIFECYCLE ═══════════════

func _ready() -> void:
	_connect_signals()


func reset() -> void:
	story_progress.clear()
	_story_cache.clear()
	_choice_history.clear()
	_pending_choices.clear()


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
	# Story data scripts expose a const EVENTS dictionary
	var data: Dictionary = {}
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


## Get all flags for a hero. Used by combat resolver and other systems.
func get_hero_flags(hero_id: String) -> Dictionary:
	return story_progress.get(hero_id, {}).get("flags", {}).duplicate()


## Clear (remove) a story flag for a hero.
func clear_flag(hero_id: String, flag: String) -> void:
	if story_progress.has(hero_id):
		story_progress[hero_id]["flags"].erase(flag)


## Get the choice history for a hero.
func get_choice_history(hero_id: String) -> Dictionary:
	return _choice_history.get(hero_id, {}).duplicate()


## Check if a choice event is pending for a hero.
func has_pending_choice(hero_id: String) -> bool:
	return _pending_choices.has(hero_id)


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
	# Don't trigger new events while a choice is pending
	if _pending_choices.has(hero_id):
		return {}
	if not check_trigger(hero_id):
		return {}
	var event: Dictionary = get_next_event(hero_id)
	if event.is_empty():
		return {}
	# Check if event has choices — if so, store as pending and emit choice request
	var choices: Array = event.get("choices", [])
	if not choices.is_empty():
		var event_id: String = event.get("id", "")
		_pending_choices[hero_id] = {"event_id": event_id, "event": event}
		# Emit both the local signal and EventBus signal for UI
		story_choice_requested.emit(hero_id, event_id, choices)
		EventBus.story_choice_requested.emit(hero_id, event_id, choices)
	else:
		# Non-choice events: auto-complete to advance progress and prevent re-triggering
		complete_current_event(hero_id)
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
		# Sengoku Rance style: show reward summary in message log
		_emit_event_reward_summary(hero_id, event)
		# Check if route is complete
		if prog["current_event"] >= events.size():
			var hero_name: String = _get_hero_display_name(hero_id)
			EventBus.message_log.emit("[color=gold]★ %s 的故事路线已全部完成。[/color]" % hero_name)
			EventBus.story_route_completed.emit(hero_id, route)


## Emit a Sengoku Rance-style reward summary after event completion.
func _emit_event_reward_summary(hero_id: String, event: Dictionary) -> void:
	var effects: Dictionary = event.get("effects", {})
	if effects.is_empty():
		return
	var hero_name: String = _get_hero_display_name(hero_id)
	var parts: Array = []
	for key in effects:
		var val = effects[key]
		match key:
			"affection":
				if val > 0:
					parts.append("[color=#88ccff]好感度 +%d[/color]" % val)
				elif val < 0:
					parts.append("[color=#ff8888]好感度 %d[/color]" % val)
			"corruption":
				if val > 0:
					parts.append("[color=#cc88ff]调教度 +%d[/color]" % val)
			"submission":
				if val > 0:
					parts.append("[color=#ff88aa]臣民度 +%d[/color]" % val)
			"prestige":
				if val > 0:
					parts.append("[color=#ffcc44]威望 +%d[/color]" % val)
			"gold":
				if val > 0:
					parts.append("[color=#ffdd66]黄金 +%d[/color]" % val)
			"soldiers":
				if val > 0:
					parts.append("[color=#88ff88]兵力 +%d[/color]" % val)
			"unlock_skill":
				parts.append("[color=#44ffcc]解锁技能: %s[/color]" % str(val))
			"set_flag":
				# Only show meaningful flags (not internal ones)
				if val is Dictionary:
					for f in val:
						if not f.begins_with("_"):
							parts.append("[color=#aaaaff]标记: %s[/color]" % f)
	if parts.is_empty():
		return
	EventBus.message_log.emit("【%s】事件奖励：%s" % [hero_name, " / ".join(parts)])


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
			"submission_min":
				var submission: int = int(get_flag(hero_id, "submission", 0))
				if submission < trigger[key]:
					return false
			"prestige_min":
				var prestige: int = int(get_flag(hero_id, "prestige", 0))
				if prestige < trigger[key]:
					return false
			"prev_event":
				if not is_event_completed(hero_id, trigger[key]):
					return false
			"flag":
				var flag_data: Dictionary = trigger[key]
				for flag_key in flag_data:
					if get_flag(hero_id, flag_key) != flag_data[flag_key]:
						return false
			"requires_flag":
				# Can be a single string or array of strings — ALL must be set (truthy)
				var req_flags = trigger[key]
				if req_flags is String:
					req_flags = [req_flags]
				for rf in req_flags:
					if not get_flag(hero_id, rf, false):
						return false
			"excludes_flag":
				# Can be a single string or array of strings — NONE may be set (truthy)
				var exc_flags = trigger[key]
				if exc_flags is String:
					exc_flags = [exc_flags]
				for ef in exc_flags:
					if get_flag(hero_id, ef, false):
						return false
			"affection_or_corruption":
				# Trigger if affection >= X OR corruption >= Y
				var aff_threshold: int = trigger[key].get("affection_min", 999)
				var cor_threshold: int = trigger[key].get("corruption_min", 999)
				var aff: int = HeroSystem.hero_affection.get(hero_id, 0)
				var cor: int = HeroSystem.hero_corruption.get(hero_id, 0)
				if aff < aff_threshold and cor < cor_threshold:
					return false
			"affection_or_submission":
				var aff_threshold2: int = trigger[key].get("affection_min", 999)
				var sub_threshold: int = trigger[key].get("submission_min", 999)
				var aff2: int = HeroSystem.hero_affection.get(hero_id, 0)
				var sub: int = int(get_flag(hero_id, "submission", 0))
				if aff2 < aff_threshold2 and sub < sub_threshold:
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
				# Respect affection cap if set (e.g. puppet path)
				var cap: int = int(get_flag(hero_id, "affection_cap", 10))
				HeroSystem.hero_affection[hero_id] = clampi(current + effects[key], 0, cap)
				EventBus.hero_affection_changed.emit(hero_id, HeroSystem.hero_affection[hero_id])
			"corruption":
				var cur_cor: int = HeroSystem.hero_corruption.get(hero_id, 0)
				HeroSystem.hero_corruption[hero_id] = clampi(cur_cor + effects[key], 0, 10)
			"submission":
				set_flag(hero_id, "submission",
					clampi(int(get_flag(hero_id, "submission", 0)) + effects[key], 0, 10))
			"prestige":
				set_flag(hero_id, "prestige",
					clampi(int(get_flag(hero_id, "prestige", 0)) + effects[key], 0, 10))
			"training_progress":
				set_flag(hero_id, "training_progress",
					get_flag(hero_id, "training_progress", 0) + effects[key])
			"loyalty":
				set_flag(hero_id, "loyalty",
					get_flag(hero_id, "loyalty", 0) + effects[key])
			"gold":
				ResourceManager.apply_delta(pid, {"gold": effects[key]})
			"soldiers":
				if effects[key] > 0:
					ResourceManager.add_army(pid, effects[key])
				else:
					ResourceManager.remove_army(pid, -effects[key])
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
			"clear_flag":
				# Can be a single string or array of strings
				var flags_to_clear = effects[key]
				if flags_to_clear is String:
					flags_to_clear = [flags_to_clear]
				for f in flags_to_clear:
					clear_flag(hero_id, f)
			"set_affection_cap":
				set_flag(hero_id, "affection_cap", effects[key])
			# Fix #11: Handle "unlock" field — switches hero to the specified route
			# Used by exclusive_ending trigger events across all heroines
			# BUG FIX B8: 处理 unlock_cg 效果键，将 CG 解锁逻辑从 UI 层下沉到数据层
			"unlock_cg":
				var cg_to_unlock: String = effects[key]
				if cg_to_unlock != "" and CGManager != null:
					CGManager.unlock_cg(cg_to_unlock, hero_id)
			"unlock":
				var unlock_target: String = effects[key]
				var prog: Dictionary = story_progress.get(hero_id, {})
				if not prog.is_empty() and unlock_target != "":
					var current_route: String = prog.get("route", "")
					if current_route != unlock_target:
						# Switch to the unlocked route (e.g. exclusive_ending)
						prog["route"] = unlock_target
						prog["current_event"] = 0
						# Preserve flags and completed events across route switch
						var hero_name: String = HeroSystem.get_hero_name(hero_id) if HeroSystem and HeroSystem.has_method("get_hero_name") else hero_id
						EventBus.message_log.emit("[color=gold]★ %s 的专属结局已解锁！[/color]" % hero_name)
						if EventBus.has_signal("story_route_completed"):
							EventBus.story_route_completed.emit(hero_id, current_route)
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
	var route: String = story_progress.get(hero_id, {}).get("route", "")
	if route in MANUAL_TRIGGER_ROUTES:
		EventBus.message_log.emit("[color=orchid]新任务可用: %s[/color]" % _get_hero_display_name(hero_id))
		return
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
			story_progress[hero_id]["completed_events"] = []
			var old_flags: Dictionary = story_progress[hero_id].get("flags", {})
			var preserved := {}
			for keep_key in ["loyalty", "training_progress", "affection"]:
				if old_flags.has(keep_key):
					preserved[keep_key] = old_flags[keep_key]
			story_progress[hero_id]["flags"] = preserved
	else:
		# 首次招募，无俘虏记录：根据阵营初始化路线
		if faction == "neutral":
			_init_progress(hero_id, ROUTE_NEUTRAL)
		else:
			_init_progress(hero_id, ROUTE_PURE_LOVE)
	var route: String = story_progress.get(hero_id, {}).get("route", "")
	if route in MANUAL_TRIGGER_ROUTES:
		EventBus.message_log.emit("[color=orchid]新任务可用: %s[/color]" % _get_hero_display_name(hero_id))
		return
	try_trigger_next(hero_id)


func _on_affection_changed(hero_id: String, _new_value: int) -> void:
	# Check if affection threshold triggers next event
	var route: String = story_progress.get(hero_id, {}).get("route", "")
	if route in MANUAL_TRIGGER_ROUTES:
		# Only notify if a mission actually became available (trigger conditions now met)
		if check_trigger(hero_id):
			var hero_name: String = _get_hero_display_name(hero_id)
			var next_event: Dictionary = get_next_event(hero_id)
			var event_name: String = next_event.get("name", "新任务")
			EventBus.message_log.emit("[color=orchid]★ 新任务解锁：%s 「%s」——打开据点面板可执行[/color]" % [hero_name, event_name])
			if EventBus.has_signal("mission_available"):
				EventBus.mission_available.emit(hero_id, next_event)
		return
	try_trigger_next(hero_id)


func _on_story_choice_made(hero_id: String, event_id: String, choice_index: int) -> void:
	resolve_story_choice(hero_id, event_id, choice_index)


## Called by UI when player selects a story choice.
## Resolves the pending choice, applies the selected choice's effects, sets flags,
## records the choice in history, and completes the event.
func resolve_story_choice(hero_id: String, event_id: String, choice_index: int) -> void:
	# Look up the event — prefer pending choice, fall back to event_by_id
	var event: Dictionary = {}
	if _pending_choices.has(hero_id) and _pending_choices[hero_id]["event_id"] == event_id:
		event = _pending_choices[hero_id]["event"]
		_pending_choices.erase(hero_id)
	else:
		event = get_event_by_id(hero_id, event_id)
	if event.is_empty():
		push_warning("StoryEventSystem: resolve_story_choice — event not found: %s/%s" % [hero_id, event_id])
		return
	var choices: Array = event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		push_warning("StoryEventSystem: resolve_story_choice — invalid choice_index %d for %s" % [choice_index, event_id])
		return
	var choice: Dictionary = choices[choice_index]
	# Record choice in history
	if not _choice_history.has(hero_id):
		_choice_history[hero_id] = {}
	_choice_history[hero_id][event_id] = choice_index
	# Set choice flag for future branching
	set_flag(hero_id, "choice_%s" % event_id, choice_index)
	# Apply choice-specific effects
	var choice_effects: Dictionary = choice.get("effects", {})
	if not choice_effects.is_empty():
		_apply_event_effects(hero_id, {"effects": choice_effects})
	# Now complete the current event (applies base event effects and advances)
	complete_current_event(hero_id)


# ═══════════════ MISSION PANEL SUPPORT ═══════════════

## Get hero display name for UI.
func _get_hero_display_name(hero_id: String) -> String:
	# Map hero_id to display names
	var names: Dictionary = {
		"rin": "凛", "yukino": "雪乃", "momiji": "红叶",
		"hyouka": "冰華", "suirei": "翠玲", "gekka": "月華",
		"hakagure": "叶隐", "sou": "蒼", "shion": "紫苑",
		"homura": "焔", "hibiki": "響", "sara": "沙罗",
		"mei": "冥", "kaede": "枫", "akane": "朱音", "hanabi": "花火",
	}
	return names.get(hero_id, hero_id)


## Returns ALL missions across all heroes with their status, for the mission panel UI.
func get_available_missions() -> Array:
	var missions: Array = []
	for hero_id in story_progress:
		var prog: Dictionary = story_progress[hero_id]
		var route: String = prog.get("route", "")
		# Only include manual-trigger routes
		if route not in MANUAL_TRIGGER_ROUTES:
			continue
		var events: Array = get_route_events(hero_id, route)
		var current_idx: int = prog.get("current_event", 0)
		var completed: Array = prog.get("completed_events", [])

		# Get hero display name
		var hero_name: String = _get_hero_display_name(hero_id)

		for i in range(events.size()):
			var event: Dictionary = events[i]
			var event_id: String = event.get("id", "")
			var status: String = "locked"

			if event_id in completed:
				status = "completed"
			elif i == current_idx:
				# Check if trigger conditions are met
				if _evaluate_trigger(hero_id, event.get("trigger", {})):
					status = "available"
				else:
					status = "locked"
			# Future events beyond current are locked

			missions.append({
				"hero_id": hero_id,
				"hero_name": hero_name,
				"event_id": event_id,
				"event_name": event.get("name", "???"),
				"route": route,
				"status": status,
				"event_data": event,
			})
	return missions


## Trigger the next available event for a hero manually (from mission panel).
## Returns the event data if successful, empty dict otherwise.
func manually_trigger_event(hero_id: String) -> Dictionary:
	if _processing_effects:
		return {}
	if _pending_choices.has(hero_id):
		return {}
	var prog: Dictionary = story_progress.get(hero_id, {})
	if prog.is_empty():
		return {}
	var route: String = prog.get("route", "")
	if route not in MANUAL_TRIGGER_ROUTES:
		push_warning("StoryEventSystem: Cannot manually trigger auto-trigger route '%s'" % route)
		return {}
	# Check trigger conditions
	if not check_trigger(hero_id):
		return {}
	var event: Dictionary = get_next_event(hero_id)
	if event.is_empty():
		return {}
	# Same logic as try_trigger_next but explicitly for manual trigger
	var choices: Array = event.get("choices", [])
	if not choices.is_empty():
		var event_id: String = event.get("id", "")
		_pending_choices[hero_id] = {"event_id": event_id, "event": event}
		story_choice_requested.emit(hero_id, event_id, choices)
		EventBus.story_choice_requested.emit(hero_id, event_id, choices)
	else:
		complete_current_event(hero_id)
	EventBus.story_event_triggered.emit(hero_id, event)
	return event


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
	# Only auto-trigger events on AUTO_TRIGGER_ROUTES (hostile/conquest)
	# Manual routes (training/pure_love/neutral/friendly) require mission panel
	for hero_id in story_progress:
		if hero_id in orphaned:
			continue
		var route: String = story_progress[hero_id].get("route", "")
		if route in MANUAL_TRIGGER_ROUTES:
			continue  # Skip — player must trigger via mission panel
		try_trigger_next(hero_id)


# ═══════════════ SAVE / LOAD ═══════════════

func get_save_data() -> Dictionary:
	return {
		"story_progress": story_progress.duplicate(true),
		"choice_history": _choice_history.duplicate(true),
	}


func load_save_data(data: Dictionary) -> void:
	story_progress = data.get("story_progress", {}).duplicate(true)
	_choice_history = data.get("choice_history", {}).duplicate(true)
	_pending_choices.clear()


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


# ═══════════════ MISSING METHOD STUBS (v5.3 audit) ═══════════════

## Called by grand_event_director — records a global event in the story log.
func record_event(event_id: String, event_name: String) -> void:
	if not story_progress.has("_global_events"):
		story_progress["_global_events"] = []
	# BUG FIX B3: current_turn 不存在，应为 turn_number
	story_progress["_global_events"].append({"id": event_id, "name": event_name, "turn": GameManager.turn_number if GameManager != null else 0})
