## weather_system.gd - Weather & Season system for 暗潮 SLG
## Rotates seasons every 5 turns; rolls weighted random weather each turn.
## Emits signals via EventBus; other systems query modifiers via public methods.
class_name WeatherSystem
extends Node

# ── Season IDs ──
enum Season { SPRING, SUMMER, AUTUMN, WINTER }

# ── Weather IDs ──
enum Weather { CLEAR, RAIN, FOG, STORM, SNOW, DROUGHT, MONSOON }

# ── Constants ──
const TURNS_PER_SEASON: int = 5

# ── State ──
var current_season: Season = Season.SPRING
var current_weather: Weather = Weather.CLEAR
var current_turn: int = 0
var season_turn: int = 0  # turn index within the current season (0..4)

## Tracks tiles with active burn debuff: { tile_index: int -> turns_remaining: int }
var burning_tiles: Dictionary = {}

# ─────────────────────────────────────────────
# Season metadata
# ─────────────────────────────────────────────

const SEASON_DATA: Dictionary = {
	Season.SPRING: {
		"id": Season.SPRING,
		"name": "春",
		"food_mult": 1.20,
		"gold_mult": 1.0,
		"iron_mult": 1.0,
		"morale_recovery": 1,
		"movement_ap_extra": 0,
		"cavalry_atk_mod": 0,
		"cavalry_spd_mod": 0,
		"heavy_armor_def_mod": 0,
		"siege_def_mult": 1.0,
		"supply_attrition_mult": 1.0,
		"visibility_mod": 0,
	},
	Season.SUMMER: {
		"id": Season.SUMMER,
		"name": "夏",
		"food_mult": 1.0,
		"gold_mult": 1.15,
		"iron_mult": 1.0,
		"morale_recovery": 0,
		"movement_ap_extra": 0,
		"cavalry_atk_mod": 2,
		"cavalry_spd_mod": 0,
		"heavy_armor_def_mod": -1,
		"siege_def_mult": 1.0,
		"supply_attrition_mult": 1.0,
		"visibility_mod": 0,
	},
	Season.AUTUMN: {
		"id": Season.AUTUMN,
		"name": "秋",
		"food_mult": 1.30,   # harvest bonus
		"gold_mult": 1.0,
		"iron_mult": 1.20,
		"morale_recovery": 0,
		"movement_ap_extra": 0,
		"cavalry_atk_mod": 0,
		"cavalry_spd_mod": 0,
		"heavy_armor_def_mod": 0,
		"siege_def_mult": 1.0,
		"supply_attrition_mult": 1.0,
		"visibility_mod": 1,
	},
	Season.WINTER: {
		"id": Season.WINTER,
		"name": "冬",
		"food_mult": 0.70,
		"gold_mult": 1.0,
		"iron_mult": 1.0,
		"morale_recovery": 0,
		"movement_ap_extra": 1,
		"cavalry_atk_mod": 0,
		"cavalry_spd_mod": -2,
		"heavy_armor_def_mod": 0,
		"siege_def_mult": 1.20,
		"supply_attrition_mult": 1.50,
		"visibility_mod": 0,
	},
}

# ─────────────────────────────────────────────
# Weather metadata
# ─────────────────────────────────────────────

const WEATHER_DATA: Dictionary = {
	Weather.CLEAR: {
		"id": Weather.CLEAR,
		"name": "晴朗",
		"atk_mod": 0,
		"def_mod": 0,
		"spd_mod": 0,
		"ranged_atk_mod": 0,
		"cavalry_atk_mod": 0,
		"siege_def_mod": 0,
		"movement_ap_extra": 0,
		"visibility_mod": 0,
		"food_mult": 1.0,
		"gold_mult": 1.0,
		"iron_mult": 1.0,
		"cavalry_charge_disabled": false,
		"fire_attacks_nullified": false,
		"fire_attacks_bonus": 0.0,
		"naval_blocked": false,
		"supply_convoy_loss_chance": 0.0,
		"ambush_bonus": 0.0,
		"attrition_exposed": false,
		"river_coastal_production_mult": 1.0,
		"siege_wall_hp_mult": 1.0,
		"forest_burn": false,
		"morale_start_bonus": 5,
	},
	Weather.RAIN: {
		"id": Weather.RAIN,
		"name": "雨天",
		"atk_mod": 0, "def_mod": 0, "spd_mod": 0,
		"ranged_atk_mod": -2, "cavalry_atk_mod": 0, "siege_def_mod": 0,
		"movement_ap_extra": 0, "visibility_mod": 0,
		"food_mult": 1.0, "gold_mult": 1.0, "iron_mult": 1.0,
		"cavalry_charge_disabled": true,
		"fire_attacks_nullified": true,
		"fire_attacks_bonus": 0.0,
		"naval_blocked": false,
		"supply_convoy_loss_chance": 0.0,
		"ambush_bonus": 0.0,
		"attrition_exposed": false,
		"river_coastal_production_mult": 1.0,
		"siege_wall_hp_mult": 1.0,
		"forest_burn": false,
	},
	Weather.FOG: {
		"id": Weather.FOG,
		"name": "浓雾",
		"atk_mod": 0, "def_mod": 0, "spd_mod": 0,
		"ranged_atk_mod": -3, "cavalry_atk_mod": 0, "siege_def_mod": 0,
		"movement_ap_extra": 0, "visibility_mod": -99,  # sentinel: halve visibility
		"food_mult": 1.0, "gold_mult": 1.0, "iron_mult": 1.0,
		"cavalry_charge_disabled": false,
		"fire_attacks_nullified": false,
		"fire_attacks_bonus": 0.0,
		"naval_blocked": false,
		"supply_convoy_loss_chance": 0.0,
		"ambush_bonus": 0.50,
		"attrition_exposed": false,
		"river_coastal_production_mult": 1.0,
		"siege_wall_hp_mult": 1.0,
		"forest_burn": false,
	},
	Weather.STORM: {
		"id": Weather.STORM,
		"name": "暴风",
		"atk_mod": -1, "def_mod": 0, "spd_mod": 0,
		"ranged_atk_mod": -2, "cavalry_atk_mod": 0, "siege_def_mod": 0,
		"movement_ap_extra": 1, "visibility_mod": 0,
		"food_mult": 1.0, "gold_mult": 1.0, "iron_mult": 1.0,
		"cavalry_charge_disabled": false,
		"fire_attacks_nullified": false,
		"fire_attacks_bonus": 0.0,
		"naval_blocked": true,
		"supply_convoy_loss_chance": 0.10,
		"ambush_bonus": 0.0,
		"attrition_exposed": false,
		"river_coastal_production_mult": 1.0,
		"siege_wall_hp_mult": 1.0,
		"forest_burn": false,
	},
	Weather.SNOW: {
		"id": Weather.SNOW,
		"name": "大雪",
		"atk_mod": 0, "def_mod": 0, "spd_mod": -2,
		"ranged_atk_mod": 0, "cavalry_atk_mod": 0, "siege_def_mod": 0,
		"movement_ap_extra": 1, "visibility_mod": 0,
		"food_mult": 1.0, "gold_mult": 1.0, "iron_mult": 1.0,
		"cavalry_charge_disabled": true,
		"fire_attacks_nullified": false,
		"fire_attacks_bonus": 0.0,
		"naval_blocked": false,
		"supply_convoy_loss_chance": 0.0,
		"ambush_bonus": 0.0,
		"attrition_exposed": true,
		"river_coastal_production_mult": 1.0,
		"siege_wall_hp_mult": 1.0,
		"forest_burn": false,
	},
	Weather.DROUGHT: {
		"id": Weather.DROUGHT,
		"name": "干旱",
		"atk_mod": 0, "def_mod": 0, "spd_mod": 0,
		"ranged_atk_mod": 0, "cavalry_atk_mod": 0, "siege_def_mod": 0,
		"movement_ap_extra": 0, "visibility_mod": 0,
		"food_mult": 0.60,  # -40%
		"gold_mult": 1.10, "iron_mult": 1.0,
		"cavalry_charge_disabled": false,
		"fire_attacks_nullified": false,
		"fire_attacks_bonus": 0.30,
		"naval_blocked": false,
		"supply_convoy_loss_chance": 0.0,
		"ambush_bonus": 0.0,
		"attrition_exposed": false,
		"river_coastal_production_mult": 1.0,
		"siege_wall_hp_mult": 1.0,
		"forest_burn": true,
	},
	Weather.MONSOON: {
		"id": Weather.MONSOON,
		"name": "季风",
		"atk_mod": 0, "def_mod": 0, "spd_mod": 0,
		"ranged_atk_mod": -1, "cavalry_atk_mod": 0, "siege_def_mod": 0,
		"movement_ap_extra": 0, "visibility_mod": 0,
		"food_mult": 1.0, "gold_mult": 1.0, "iron_mult": 1.0,
		"cavalry_charge_disabled": false,
		"fire_attacks_nullified": false,
		"fire_attacks_bonus": 0.0,
		"naval_blocked": false,
		"supply_convoy_loss_chance": 0.0,
		"ambush_bonus": 0.0,
		"attrition_exposed": false,
		"river_coastal_production_mult": 0.50,  # -50% on river/coastal
		"siege_wall_hp_mult": 0.80,             # -20% wall HP
		"forest_burn": false,
	},
}

# ─────────────────────────────────────────────
# Weather roll weights per season
# Each array entry is [Weather, weight].
# ─────────────────────────────────────────────

const WEATHER_WEIGHTS: Dictionary = {
	Season.SPRING: [
		[Weather.CLEAR,   40],
		[Weather.RAIN,    25],
		[Weather.FOG,     15],
		[Weather.STORM,   10],
		[Weather.MONSOON, 10],
	],
	Season.SUMMER: [
		[Weather.CLEAR,   35],
		[Weather.RAIN,    15],
		[Weather.FOG,     10],
		[Weather.STORM,   15],
		[Weather.DROUGHT, 25],
	],
	Season.AUTUMN: [
		[Weather.CLEAR,   45],
		[Weather.RAIN,    20],
		[Weather.FOG,     20],
		[Weather.STORM,   15],
	],
	Season.WINTER: [
		[Weather.CLEAR,   25],
		[Weather.RAIN,    10],
		[Weather.FOG,     15],
		[Weather.STORM,   15],
		[Weather.SNOW,    35],
	],
}

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────

func _ready() -> void:
	current_season = Season.SPRING
	current_weather = Weather.CLEAR
	current_turn = 0
	season_turn = 0


# ─────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────

## Call once per game turn to advance seasons and roll new weather.
func advance_turn() -> void:
	current_turn += 1
	season_turn += 1

	# --- Tick burning tiles ---
	var expired: Array = []
	for tile_idx in burning_tiles:
		burning_tiles[tile_idx] -= 1
		if burning_tiles[tile_idx] <= 0:
			expired.append(tile_idx)
	for tile_idx in expired:
		burning_tiles.erase(tile_idx)

	# --- Season rotation ---
	var season_changed_flag: bool = false
	if season_turn >= TURNS_PER_SEASON:
		season_turn = 0
		var prev_season := current_season
		current_season = ((current_season as int + 1) % 4) as Season
		season_changed_flag = true
		var sdata := get_current_season()
		if EventBus:
			EventBus.season_changed.emit(current_season as int, sdata)
		if current_season != prev_season:
			_log("Season changed to %s" % sdata.get("name", ""))

	# --- Weather roll ---
	var prev_weather := current_weather
	current_weather = _roll_weather()
	var wdata := get_current_weather()
	if EventBus:
		EventBus.weather_changed.emit(current_weather as int, wdata)
	if current_weather != prev_weather or season_changed_flag:
		_log("Weather: %s" % wdata.get("name", ""))

	# --- Drought forest burn ---
	if current_weather == Weather.DROUGHT and WEATHER_DATA[Weather.DROUGHT]["forest_burn"]:
		# Signal consumers should mark affected forest tiles via burning_tiles
		# We expose an API so tile systems can register burns.
		pass


## Register a tile as burning (e.g. from drought). Production -50% for duration turns.
func mark_tile_burning(tile_index: int, duration: int = 3) -> void:
	burning_tiles[tile_index] = duration


## Returns dict with all burning tiles and their remaining turns.
func get_burning_tiles() -> Dictionary:
	return burning_tiles.duplicate()


## Returns a full description dict for the current season.
func get_current_season() -> Dictionary:
	return SEASON_DATA[current_season].duplicate()


## Returns a full description dict for the current weather.
func get_current_weather() -> Dictionary:
	var d: Dictionary = WEATHER_DATA[current_weather].duplicate()
	d["turn"] = current_turn
	d["season_turn"] = season_turn
	return d


## Combined combat modifiers from both season and weather.
func get_combat_modifiers() -> Dictionary:
	var s: Dictionary = SEASON_DATA[current_season]
	var w: Dictionary = WEATHER_DATA[current_weather]
	var mods: Dictionary = {
		"atk_mod":         w["atk_mod"],
		"def_mod":         w["def_mod"] + s["heavy_armor_def_mod"],
		"spd_mod":         w["spd_mod"] + s["cavalry_spd_mod"],
		"ranged_atk_mod":  w["ranged_atk_mod"],
		"cavalry_atk_mod": w["cavalry_atk_mod"] + s["cavalry_atk_mod"],
		"siege_def_mod":   w["siege_def_mod"],
		"siege_def_mult":  s["siege_def_mult"],
		"cavalry_charge_disabled": w["cavalry_charge_disabled"],
		"fire_attacks_nullified":  w["fire_attacks_nullified"],
		"fire_attacks_bonus":      w["fire_attacks_bonus"],
		"naval_blocked":           w["naval_blocked"],
		"supply_convoy_loss_chance": w["supply_convoy_loss_chance"],
		"supply_attrition_mult":    s["supply_attrition_mult"],
		"ambush_bonus":            w["ambush_bonus"],
		"attrition_exposed":       w["attrition_exposed"],
		"morale_recovery":         s["morale_recovery"],
		"morale_start_bonus":      w.get("morale_start_bonus", 0),
	}
	# Cross-system interaction: winter + storm = blizzard
	if current_season == Season.WINTER and current_weather == Weather.STORM:
		mods["spd_mod"] -= 3  # blizzard: all_spd_mod -3
	return mods


## Combined production multipliers from both season and weather.
func get_production_modifiers() -> Dictionary:
	var s: Dictionary = SEASON_DATA[current_season]
	var w: Dictionary = WEATHER_DATA[current_weather]
	return {
		"gold_mult": s["gold_mult"] * w["gold_mult"],
		"food_mult": s["food_mult"] * w["food_mult"],
		"iron_mult": s["iron_mult"] * w["iron_mult"],
		"river_coastal_production_mult": w["river_coastal_production_mult"],
		"siege_wall_hp_mult": w["siege_wall_hp_mult"],
		"forest_burn": w["forest_burn"],
	}


## Extra AP cost to movement from season + weather combined.
func get_movement_cost_modifier() -> int:
	var s: Dictionary = SEASON_DATA[current_season]
	var w: Dictionary = WEATHER_DATA[current_weather]
	return (s["movement_ap_extra"] as int) + (w["movement_ap_extra"] as int)


## Visibility range adjustment. Returns additive int; -99 sentinel means "halve base".
func get_visibility_modifier() -> int:
	var s: Dictionary = SEASON_DATA[current_season]
	var w: Dictionary = WEATHER_DATA[current_weather]
	# Fog uses -99 sentinel to mean "halve"; otherwise additive.
	if w["visibility_mod"] == -99:
		return -99
	return (s["visibility_mod"] as int) + (w["visibility_mod"] as int)


# ─────────────────────────────────────────────
# Internal helpers
# ─────────────────────────────────────────────

func _roll_weather() -> Weather:
	# Weather persistence: 30% chance current weather persists
	if current_turn > 0 and (randi() % 100) < 30:
		return current_weather

	var table: Array = WEATHER_WEIGHTS[current_season]
	var total_weight: int = 0
	for entry in table:
		total_weight += entry[1] as int

	var roll: int = randi() % total_weight
	var cumulative: int = 0
	for entry in table:
		cumulative += entry[1] as int
		if roll < cumulative:
			return entry[0] as Weather

	# Fallback (should not reach here)
	return Weather.CLEAR


func _log(text: String) -> void:
	if EventBus and EventBus.has_signal("message_log"):
		EventBus.message_log.emit("[Weather] " + text)
