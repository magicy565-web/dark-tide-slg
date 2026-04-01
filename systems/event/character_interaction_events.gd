## character_interaction_events.gd - Events between recruited hero pairs (v1.0)
## Triggers relationship events based on hero combinations and affection.
extends Node

# ── Interaction definitions ──
var _interactions: Array = []

# ── Tracking: which interactions have fired ──
var _fired_interactions: Dictionary = {}  # interaction_id -> true (permanent ones)
var _repeatable_cooldowns: Dictionary = {}  # interaction_id -> turns_remaining

# ── Global cooldown between any character interaction events ──
var _global_cooldown: int = 0
const INTERACTION_COOLDOWN: int = 5

# ── Pending choice event ──
var _current_event: Dictionary = {}


func _ready() -> void:
	_register_interactions()
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.event_choice_selected.connect(_on_event_choice_selected)
	if EventRegistry:
		EventRegistry._register_source("character_interaction_events", _interactions, "character_interaction")


# ═══════════════ INTERACTION REGISTRATION ═══════════════

func _register_interactions() -> void:
	# --- Same-faction interactions ---
	_interactions.append({
		"id": "rin_yukino_sisters", "name": "旧日姐妹",
		"desc": "rin与yukino重逢，两位旧日姐妹回忆起过去的时光。她们的羁绊让彼此变得更加坚强。",
		"required_heroes": ["rin", "yukino"],
		"min_affection": 0, "permanent": true,
		"auto": true,
		"effects": {"hero_stat_bonus": [{"hero": "rin", "stat": "def", "value": 1}, {"hero": "yukino", "stat": "def", "value": 1}]},
	})
	_interactions.append({
		"id": "suirei_gekka_forest", "name": "森林之约",
		"desc": "精灵族的suirei与gekka在月光下订立森林之约。",
		"required_heroes": ["suirei", "gekka"],
		"min_affection": 0, "permanent": true,
		"choices": [
			{"text": "支持合作 (两人各+1ATK)", "effects": {"hero_stat_bonus": [{"hero": "suirei", "stat": "atk", "value": 1}, {"hero": "gekka", "stat": "atk", "value": 1}]}},
			{"text": "激发竞争 (一人+2ATK, 另一人-1ATK)", "effects": {"hero_stat_bonus": [{"hero": "suirei", "stat": "atk", "value": 2}, {"hero": "gekka", "stat": "atk", "value": -1}]}},
		]
	})
	_interactions.append({
		"id": "sou_shion_research", "name": "魔法研究",
		"desc": "sou与shion共同研究魔法，取得了突破性进展。",
		"required_heroes": ["sou", "shion"],
		"min_affection": 3, "permanent": true,
		"auto": true,
		"effects": {"tech_point": 1},
	})

	# --- Cross-faction interactions ---
	_interactions.append({
		"id": "rin_sou_sword_magic", "name": "剑与魔法",
		"desc": "rin的剑术与sou的魔法碰撞出奇妙的火花，两人互相学习。",
		"required_heroes": ["rin", "sou"],
		"min_affection": 0, "permanent": true,
		"auto": true,
		"effects": {"hero_stat_bonus": [{"hero": "rin", "stat": "int", "value": 1}, {"hero": "sou", "stat": "int", "value": 1}]},
	})
	_interactions.append({
		"id": "momiji_gekka_synergy", "name": "骑士与弓手",
		"desc": "momiji的骑兵冲锋配合gekka的精准射击，形成了完美的战术配合。",
		"required_heroes": ["momiji", "gekka"],
		"min_affection": 0, "permanent": true,
		"auto": true,
		"effects": {"combo_passive": "cavalry_ranger_synergy", "prestige": 3},
	})
	_interactions.append({
		"id": "yukino_akane_healers", "name": "治愈之心",
		"desc": "yukino与akane两位治愈者联手，为全军提供持续治疗。",
		"required_heroes": ["yukino", "akane"],
		"min_affection": 0, "permanent": false, "repeatable": true,
		"auto": true,
		"effects": {"heal_per_turn": 2, "duration": 3},
	})
	_interactions.append({
		"id": "hyouka_mei_tank_dps", "name": "铁壁与火力",
		"desc": "hyouka的铁壁防御配合mei的火力输出，成为战场上的最强搭档。",
		"required_heroes": ["hyouka", "mei"],
		"min_affection": 0, "permanent": true,
		"auto": true,
		"effects": {"combo_passive": "tank_dps_synergy"},
	})

	# --- Rivalry interactions ---
	_interactions.append({
		"id": "rin_homura_rivals", "name": "宿命之敌",
		"desc": "rin与homura之间有着深深的宿命羁绊，是决斗还是联手？",
		"required_heroes": ["rin", "homura"],
		"min_affection": 0, "permanent": true,
		"choices": [
			{"text": "决斗 (胜者ATK+2)", "effects": {"hero_stat_bonus": [{"hero": "rin", "stat": "atk", "value": 2}]}},
			{"text": "携手合作 (两人各+1ATK)", "effects": {"hero_stat_bonus": [{"hero": "rin", "stat": "atk", "value": 1}, {"hero": "homura", "stat": "atk", "value": 1}]}},
		]
	})
	_interactions.append({
		"id": "suirei_shion_nature_arcane", "name": "自然 vs 秘术",
		"desc": "suirei的自然魔法与shion的秘术产生冲突，你必须做出选择。",
		"required_heroes": ["suirei", "shion"],
		"min_affection": 0, "permanent": true,
		"choices": [
			{"text": "支持suirei (森林地形增益)", "effects": {"terrain_buff": "forest", "prestige": 3}},
			{"text": "支持shion (魔法增益)", "effects": {"buff": {"type": "magic_pct", "value": 15, "duration": 5}}},
		]
	})

	# --- Affection-gated interactions ---
	_interactions.append({
		"id": "late_night_talk", "name": "深夜密谈",
		"desc": "两位英雄在深夜进行了一场推心置腹的谈话，彼此都有所成长。",
		"required_heroes": ["any_pair"],
		"min_affection": 5, "permanent": false, "repeatable": true,
		"auto": true,
		"effects": {"lowest_stat_bonus": 1},
	})
	_interactions.append({
		"id": "loyalty_proof", "name": "忠诚之证",
		"desc": "这位英雄用行动证明了自己的忠诚，获得了永久的力量提升。",
		"required_heroes": ["any_single"],
		"min_affection": 7, "permanent": true,
		"auto": true,
		"effects": {"all_stats_bonus": 1},
	})
	_interactions.append({
		"id": "comrades_feast", "name": "战友之宴",
		"desc": "三位以上忠诚的战友聚在一起，共同举杯庆祝。全军士气高涨。",
		"required_heroes": ["any_three_plus"],
		"min_affection": 5, "permanent": false, "repeatable": true,
		"auto": true,
		"effects": {"buff": {"type": "morale", "value": 1, "duration": 1}},
	})

	# --- Special combinations ---
	_interactions.append({
		"id": "neutral_alliance", "name": "中立联盟",
		"desc": "hibiki、sara、mei三位中立阵营的领袖聚首，结成特殊同盟。",
		"required_heroes": ["hibiki", "sara", "mei"],
		"min_affection": 0, "permanent": true,
		"auto": true,
		"effects": {"prestige": 15, "unlock_building": "neutral_embassy"},
	})
	_interactions.append({
		"id": "shadow_path", "name": "影之道",
		"desc": "kaede与同伴研究暗影之道，大幅提升谍报成功率。",
		"required_heroes": ["kaede"],
		"min_affection": 0, "permanent": false, "repeatable": true,
		"auto": true,
		"effects": {"espionage_bonus": 20, "duration": 5},
	})
	_interactions.append({
		"id": "artillery_concert", "name": "轰鸣协奏",
		"desc": "hanabi指挥炮兵部队进行协同射击演练，炮兵战力大幅提升。",
		"required_heroes": ["hanabi"],
		"min_affection": 0, "permanent": false, "repeatable": true,
		"auto": true,
		"effects": {"unit_buff": {"unit_type": "cannon", "stat": "atk", "value": 2, "duration": 3}},
	})


# ═══════════════ TURN PROCESSING ═══════════════

func _on_turn_started(player_id: int) -> void:
	if player_id != 0:
		return

	# Tick down cooldowns
	if _global_cooldown > 0:
		_global_cooldown -= 1

	var expired_keys: Array = []
	for key in _repeatable_cooldowns:
		_repeatable_cooldowns[key] -= 1
		if _repeatable_cooldowns[key] <= 0:
			expired_keys.append(key)
	for key in expired_keys:
		_repeatable_cooldowns.erase(key)

	# Check for eligible interactions
	if _global_cooldown <= 0:
		_check_interactions()


func _check_interactions() -> void:
	var recruited: Array = _get_recruited_heroes()
	if recruited.size() < 1:
		return

	var recruited_set: Dictionary = {}
	for h in recruited:
		recruited_set[h] = true

	var affections: Dictionary = _get_hero_affections()

	for interaction in _interactions:
		var iid: String = interaction["id"]

		# Skip if already fired (permanent) or on cooldown (repeatable)
		if interaction.get("permanent", false) and _fired_interactions.has(iid):
			continue
		if _repeatable_cooldowns.has(iid):
			continue

		# Check hero requirements
		if not _check_hero_requirements(interaction, recruited_set, affections):
			continue

		# Fire this interaction
		_fire_interaction(interaction, recruited, affections)
		_global_cooldown = INTERACTION_COOLDOWN
		return  # Only one per turn check


func _check_hero_requirements(interaction: Dictionary, recruited_set: Dictionary, affections: Dictionary) -> bool:
	var required: Variant = interaction.get("required_heroes", [])
	var min_aff: int = interaction.get("min_affection", 0)

	if required is Array and required.size() > 0:
		var first: String = required[0]

		# Special "any" types
		if first == "any_pair":
			# Need any 2 heroes with affection >= min_aff
			var qualifying: Array = []
			for hero_id in recruited_set:
				if affections.get(hero_id, 0) >= min_aff:
					qualifying.append(hero_id)
			return qualifying.size() >= 2

		elif first == "any_single":
			# Need any hero with affection >= min_aff
			for hero_id in recruited_set:
				if affections.get(hero_id, 0) >= min_aff:
					return true
			return false

		elif first == "any_three_plus":
			# Need 3+ heroes with affection >= min_aff
			var qualifying: Array = []
			for hero_id in recruited_set:
				if affections.get(hero_id, 0) >= min_aff:
					qualifying.append(hero_id)
			return qualifying.size() >= 3

		else:
			# Specific heroes required
			for hero_id in required:
				if not recruited_set.has(hero_id):
					return false
				if affections.get(hero_id, 0) < min_aff:
					return false
			return true

	return false


func _fire_interaction(interaction: Dictionary, recruited: Array, affections: Dictionary) -> void:
	var iid: String = interaction["id"]

	if interaction.get("auto", false) or not interaction.has("choices"):
		# Auto-apply effects
		_apply_interaction_effects(interaction.get("effects", {}), recruited, affections)
		EventBus.message_log.emit("[color=pink][英雄互动] %s: %s[/color]" % [interaction["name"], interaction["desc"]])

		if interaction.get("permanent", false):
			_fired_interactions[iid] = true
		elif interaction.get("repeatable", false):
			_repeatable_cooldowns[iid] = INTERACTION_COOLDOWN
	else:
		# Choice-based
		_current_event = interaction
		var choice_texts: Array = []
		for c in interaction.get("choices", []):
			choice_texts.append(c["text"])
		EventBus.show_event_popup.emit(interaction["name"], interaction["desc"], choice_texts)
		EventBus.message_log.emit("[color=pink][英雄互动] %s[/color]" % interaction["name"])


# ═══════════════ CHOICE HANDLING ═══════════════

func _on_event_choice_selected(choice_index: int) -> void:
	if _current_event.is_empty():
		return

	var choices: Array = _current_event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		_current_event = {}
		return

	var effects: Dictionary = choices[choice_index].get("effects", {})
	var recruited: Array = _get_recruited_heroes()
	var affections: Dictionary = _get_hero_affections()
	_apply_interaction_effects(effects, recruited, affections)

	var iid: String = _current_event.get("id", "")
	if _current_event.get("permanent", false):
		_fired_interactions[iid] = true
	elif _current_event.get("repeatable", false):
		_repeatable_cooldowns[iid] = INTERACTION_COOLDOWN

	_current_event = {}


# ═══════════════ EFFECT APPLICATION ═══════════════

func _apply_interaction_effects(effects: Dictionary, recruited: Array, affections: Dictionary) -> void:
	var pid: int = GameManager.current_player_index if "current_player_index" in GameManager else 0

	# Route through centralized EffectResolver if available
	if EffectResolver:
		EffectResolver.resolve(effects, {
			"player_id": pid,
			"source": "hero_interaction",
			"event_id": _current_event.get("id", "interaction"),
			"recruited": recruited,
			"affections": affections,
		})
		return

	# Legacy fallback — Hero stat bonuses
	if effects.has("hero_stat_bonus"):
		for bonus in effects["hero_stat_bonus"]:
			var hero_id: String = bonus.get("hero", "")
			var stat: String = bonus.get("stat", "")
			var value: int = bonus.get("value", 0)
			if hero_id != "" and stat != "" and HeroSystem != null:
				if HeroSystem.has_method("add_stat_bonus"):
					HeroSystem.add_stat_bonus(hero_id, stat, value)
				EventBus.message_log.emit("[color=green]%s 的%s永久+%d[/color]" % [hero_id, stat.to_upper(), value])

	# Lowest stat bonus (for "any_pair" late night talk)
	if effects.has("lowest_stat_bonus"):
		var val: int = effects["lowest_stat_bonus"]
		# Pick two random qualifying heroes
		var qualifying: Array = []
		for h in recruited:
			if affections.get(h, 0) >= 5:
				qualifying.append(h)
		qualifying.shuffle()
		for i in range(mini(2, qualifying.size())):
			if HeroSystem != null and HeroSystem.has_method("add_stat_bonus"):
				HeroSystem.add_stat_bonus(qualifying[i], "lowest", val)
			EventBus.message_log.emit("[color=green]%s 最低属性+%d[/color]" % [qualifying[i], val])

	# All stats bonus (loyalty proof)
	if effects.has("all_stats_bonus"):
		var val: int = effects["all_stats_bonus"]
		# Pick one qualifying hero
		for h in recruited:
			if affections.get(h, 0) >= 7 and not _fired_interactions.has("loyalty_%s" % h):
				_fired_interactions["loyalty_%s" % h] = true
				for stat in ["atk", "def", "int", "spd"]:
					if HeroSystem != null and HeroSystem.has_method("add_stat_bonus"):
						HeroSystem.add_stat_bonus(h, stat, val)
				EventBus.message_log.emit("[color=green]%s 全属性+%d![/color]" % [h, val])
				break

	# Resource effects
	var res_delta := {}
	for key in ["gold", "food", "iron", "slaves", "prestige", "magic_crystal"]:
		if effects.has(key):
			res_delta[key] = effects[key]
	if not res_delta.is_empty():
		ResourceManager.apply_delta(pid, res_delta)

	# Buff
	if effects.has("buff"):
		var buff: Dictionary = effects["buff"]
		BuffManager.add_buff(pid, "interaction_%s" % buff.get("type", ""), buff.get("type", ""), buff.get("value", 0), buff.get("duration", 1), "hero_interaction")

	# Tech point
	if effects.has("tech_point"):
		EventBus.message_log.emit("[color=cyan]获得 %d 科技点[/color]" % effects["tech_point"])

	# Combo passive
	if effects.has("combo_passive"):
		EventBus.message_log.emit("[color=green]解锁战术配合: %s[/color]" % effects["combo_passive"])

	# Heal per turn
	if effects.has("heal_per_turn"):
		var heal: int = effects["heal_per_turn"]
		var dur: int = effects.get("duration", 3)
		EventBus.message_log.emit("[color=green]全军每回合治愈 +%d兵力 (持续%d回合)[/color]" % [heal, dur])

	# Espionage bonus
	if effects.has("espionage_bonus"):
		var bonus: int = effects["espionage_bonus"]
		var dur: int = effects.get("duration", 5)
		EventBus.message_log.emit("[color=cyan]谍报成功率 +%d%% (持续%d回合)[/color]" % [bonus, dur])

	# Unit buff
	if effects.has("unit_buff"):
		var ub: Dictionary = effects["unit_buff"]
		EventBus.message_log.emit("[color=green]%s部队 %s+%d (持续%d回合)[/color]" % [
			ub.get("unit_type", ""), ub.get("stat", "").to_upper(), ub.get("value", 0), ub.get("duration", 0)])

	# Unlock building
	if effects.has("unlock_building"):
		EventBus.message_log.emit("[color=green]解锁特殊建筑: %s[/color]" % effects["unlock_building"])

	# Terrain buff
	if effects.has("terrain_buff"):
		EventBus.message_log.emit("[color=green]获得地形增益: %s[/color]" % effects["terrain_buff"])


# ═══════════════ HELPER FUNCTIONS ═══════════════

func _get_recruited_heroes() -> Array:
	if HeroSystem != null and HeroSystem.has_method("get_recruited_heroes"):
		return HeroSystem.get_recruited_heroes()
	# Fallback: try accessing internal data
	if HeroSystem != null and "recruited_heroes" in HeroSystem:
		return HeroSystem.recruited_heroes.keys() if HeroSystem.recruited_heroes is Dictionary else HeroSystem.recruited_heroes
	return []


func _get_hero_affections() -> Dictionary:
	var result: Dictionary = {}
	var heroes: Array = _get_recruited_heroes()
	for h in heroes:
		if HeroSystem != null and HeroSystem.has_method("get_affection"):
			result[h] = HeroSystem.get_affection(h)
		elif HeroSystem != null and "hero_affection" in HeroSystem:
			result[h] = HeroSystem.hero_affection.get(h, 0)
		else:
			result[h] = 0
	return result


# ═══════════════ SAVE / LOAD ═══════════════

func get_save_data() -> Dictionary:
	return {
		"fired_interactions": _fired_interactions.duplicate(),
		"repeatable_cooldowns": _repeatable_cooldowns.duplicate(),
		"global_cooldown": _global_cooldown,
	}


func load_save_data(data: Dictionary) -> void:
	_fired_interactions = data.get("fired_interactions", {})
	_repeatable_cooldowns = data.get("repeatable_cooldowns", {})
	_global_cooldown = data.get("global_cooldown", 0)
