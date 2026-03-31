## nation_system.gd
## Manages nation-level mechanics: territory tracking, bonuses, capitals, borders.
## Works with the fixed map data to provide strategic depth through nation control.

class_name NationSystem
extends RefCounted

const FactionData = preload("res://systems/faction/faction_data.gd")
const FixedMapData = preload("res://systems/map/fixed_map_data.gd")

# ---------------------------------------------------------------------------
# Nation bonus definitions
# ---------------------------------------------------------------------------

const NATION_BONUSES: Dictionary = {
	"human_kingdom": {
		"name": "王国繁荣",
		"description": "所有领地+20%金币收入，驻军每回合自动补充+2",
		"effects": {
			"gold_income_mult": 1.2,
			"garrison_replenish": 2,
		},
	},
	"elven_domain": {
		"name": "自然庇护",
		"description": "控制区域内所有森林地形+30%防御，全军获得隐匿",
		"effects": {
			"forest_def_mult": 1.3,
			"stealth": true,
		},
	},
	"mage_alliance": {
		"name": "奥术共鸣",
		"description": "+3法力/回合，所有魔法单位攻击力+2",
		"effects": {
			"mana_per_turn": 3,
			"magic_unit_atk_bonus": 2,
		},
	},
	"orc_horde": {
		"name": "WAAAGH!狂潮",
		"description": "WAAAGH上限+50，所有兽人单位攻击力+1",
		"effects": {
			"waaagh_cap_bonus": 50,
			"orc_unit_atk_bonus": 1,
		},
	},
	"pirate_coalition": {
		"name": "海上霸权",
		"description": "+50%掠夺收入，黑市折扣30%",
		"effects": {
			"plunder_income_mult": 1.5,
			"black_market_discount": 0.3,
		},
	},
	"dark_elf_clan": {
		"name": "暗影支配",
		"description": "奴隶上限+20，暗影精华+2/回合",
		"effects": {
			"slave_cap_bonus": 20,
			"shadow_essence_per_turn": 2,
		},
	},
	"neutral": {
		"name": "",
		"description": "中立地带无统一加成",
		"effects": {},
	},
}

# Capital loss morale penalty applied to all territories of the nation.
const CAPITAL_LOSS_MORALE_PENALTY: int = -15

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------

## Tracks current owner (player_id) of each territory. {tile_id: player_id}
var territory_owners: Dictionary = {}

## Cached: which player controls each nation fully. {nation_id: player_id} or absent.
var nation_controllers: Dictionary = {}

## Cached: active bonuses per player. {player_id: [nation_id, ...]}
var active_bonuses: Dictionary = {}

## Reference to EventBus for emitting signals (set externally).
var event_bus: Node = null

# ---------------------------------------------------------------------------
# Initialization
# ---------------------------------------------------------------------------

## Initialize the nation system with default territory ownership from fixed map data.
func initialize(p_event_bus: Node = null) -> void:
	event_bus = p_event_bus
	territory_owners.clear()
	nation_controllers.clear()
	active_bonuses.clear()

	for t in FixedMapData.TERRITORIES:
		# Default owner based on faction
		territory_owners[t["id"]] = _faction_string_to_owner(t["faction"])

	_recalculate_nation_control()

# ---------------------------------------------------------------------------
# Territory ownership
# ---------------------------------------------------------------------------

## Update the owner of a territory and recalculate nation control.
func set_territory_owner(tile_id: int, new_owner: int) -> void:
	var old_owner: int = territory_owners.get(tile_id, -1)
	if old_owner == new_owner:
		return
	territory_owners[tile_id] = new_owner

	# Check if this is a capital
	var territory: Dictionary = _get_territory(tile_id)
	if territory.size() > 0 and territory["is_capital"]:
		if event_bus:
			event_bus.nation_capital_captured.emit(new_owner, territory["nation_id"], tile_id)

	_recalculate_nation_control()

## Get the current owner of a territory.
func get_territory_owner(tile_id: int) -> int:
	return territory_owners.get(tile_id, -1)

# ---------------------------------------------------------------------------
# Nation control tracking
# ---------------------------------------------------------------------------

## Recalculate which players control entire nations, and emit signals as needed.
func _recalculate_nation_control() -> void:
	var old_controllers: Dictionary = nation_controllers.duplicate()
	nation_controllers.clear()

	for nation_id in FixedMapData.NATION_IDS:
		if nation_id == "neutral":
			continue
		var territory_ids: Array = FixedMapData.get_nation_territory_ids(nation_id)
		if territory_ids.is_empty():
			continue

		var first_owner: int = territory_owners.get(territory_ids[0], -1)
		if first_owner == -1:
			continue

		var all_same: bool = true
		for tid in territory_ids:
			if territory_owners.get(tid, -1) != first_owner:
				all_same = false
				break

		if all_same:
			nation_controllers[nation_id] = first_owner

	# Emit signals for changes
	if event_bus:
		# Check for newly conquered nations
		for nation_id in nation_controllers:
			if not old_controllers.has(nation_id) or old_controllers[nation_id] != nation_controllers[nation_id]:
				var player_id: int = nation_controllers[nation_id]
				event_bus.nation_conquered.emit(player_id, nation_id)
				event_bus.nation_bonus_activated.emit(player_id, nation_id)
				_add_active_bonus(player_id, nation_id)

		# Check for lost nations
		for nation_id in old_controllers:
			if not nation_controllers.has(nation_id) or nation_controllers[nation_id] != old_controllers[nation_id]:
				var player_id: int = old_controllers[nation_id]
				event_bus.nation_lost.emit(player_id, nation_id)
				event_bus.nation_bonus_deactivated.emit(player_id, nation_id)
				_remove_active_bonus(player_id, nation_id)

## Check if a player controls an entire nation.
func is_nation_controlled_by(nation_id: String, player_id: int) -> bool:
	return nation_controllers.get(nation_id, -1) == player_id

## Get the player who controls a nation, or -1.
func get_nation_controller(nation_id: String) -> int:
	return nation_controllers.get(nation_id, -1)

# ---------------------------------------------------------------------------
# Nation bonuses
# ---------------------------------------------------------------------------

func _add_active_bonus(player_id: int, nation_id: String) -> void:
	if not active_bonuses.has(player_id):
		active_bonuses[player_id] = []
	if nation_id not in active_bonuses[player_id]:
		active_bonuses[player_id].append(nation_id)

func _remove_active_bonus(player_id: int, nation_id: String) -> void:
	if active_bonuses.has(player_id):
		active_bonuses[player_id].erase(nation_id)

## Get all active nation bonuses for a player.
func get_active_bonuses(player_id: int) -> Array:
	var result: Array = []
	for nation_id in active_bonuses.get(player_id, []):
		if NATION_BONUSES.has(nation_id):
			result.append({
				"nation_id": nation_id,
				"bonus": NATION_BONUSES[nation_id],
			})
	return result

## Get the bonus data for a specific nation (regardless of control).
func get_nation_bonus(nation_id: String) -> Dictionary:
	return NATION_BONUSES.get(nation_id, {})

## Check if a player has a specific nation bonus active.
func has_nation_bonus(player_id: int, nation_id: String) -> bool:
	return nation_id in active_bonuses.get(player_id, [])

## Get the combined effects of all active bonuses for a player.
func get_combined_effects(player_id: int) -> Dictionary:
	var combined: Dictionary = {}
	for nation_id in active_bonuses.get(player_id, []):
		var bonus: Dictionary = NATION_BONUSES.get(nation_id, {})
		var effects: Dictionary = bonus.get("effects", {})
		for key in effects:
			if combined.has(key):
				# Additive for numeric, OR for bool
				if typeof(effects[key]) == TYPE_FLOAT or typeof(effects[key]) == TYPE_INT:
					combined[key] = combined[key] + effects[key]
				elif typeof(effects[key]) == TYPE_BOOL:
					combined[key] = combined[key] or effects[key]
			else:
				combined[key] = effects[key]
	return combined

# ---------------------------------------------------------------------------
# Border detection
# ---------------------------------------------------------------------------

## Get all border territories (territories adjacent to a different nation).
func get_border_territories(nation_id: String) -> Array:
	var result: Array = []
	var nation_tiles: Array = FixedMapData.get_nation_territory_ids(nation_id)
	var nation_tile_set: Dictionary = {}
	for tid in nation_tiles:
		nation_tile_set[tid] = true

	for t in FixedMapData.TERRITORIES:
		if t["nation_id"] != nation_id:
			continue
		for conn_id in t["connections"]:
			if not nation_tile_set.has(conn_id):
				result.append(t["id"])
				break

	return result

## Get pairs of nations that share a border, with the connecting tile IDs.
func get_nation_borders() -> Array:
	var borders: Dictionary = {}  # "a_b" -> {nation_a, nation_b, tiles: []}
	for t in FixedMapData.TERRITORIES:
		for conn_id in t["connections"]:
			var neighbor: Dictionary = _get_territory(conn_id)
			if neighbor.size() == 0:
				continue
			if t["nation_id"] != neighbor["nation_id"]:
				var a: String = t["nation_id"]
				var b: String = neighbor["nation_id"]
				var key: String = a + "_" + b if a < b else b + "_" + a
				if not borders.has(key):
					borders[key] = {
						"nation_a": a if a < b else b,
						"nation_b": b if a < b else a,
						"tiles": [],
					}
				if t["id"] not in borders[key]["tiles"]:
					borders[key]["tiles"].append(t["id"])
	var result: Array = []
	for key in borders:
		result.append(borders[key])
	return result

## Emit a border_conflict signal when armies clash at a nation border.
func notify_border_conflict(tile_id: int) -> void:
	var territory: Dictionary = _get_territory(tile_id)
	if territory.size() == 0:
		return
	for conn_id in territory["connections"]:
		var neighbor: Dictionary = _get_territory(conn_id)
		if neighbor.size() > 0 and neighbor["nation_id"] != territory["nation_id"]:
			if event_bus:
				event_bus.border_conflict.emit(territory["nation_id"], neighbor["nation_id"], tile_id)
			break

# ---------------------------------------------------------------------------
# Nation power calculation
# ---------------------------------------------------------------------------

## Calculate the power score of a nation based on its territories.
func calculate_nation_power(nation_id: String) -> Dictionary:
	var power: Dictionary = {
		"total_level": 0,
		"total_garrison": 0,
		"total_city_def": 0,
		"resource_count": 0,
		"territory_count": 0,
		"has_capital": false,
		"power_score": 0,
	}

	for t in FixedMapData.TERRITORIES:
		if t["nation_id"] != nation_id:
			continue
		power["territory_count"] += 1
		power["total_level"] += t["level"]
		power["total_garrison"] += t["garrison_base"]
		power["total_city_def"] += t["city_def"]
		if t["resource_type"] != "":
			power["resource_count"] += 1
		if t["is_capital"]:
			power["has_capital"] = true

	# Power score: weighted sum
	power["power_score"] = (
		power["total_level"] * 10
		+ power["total_garrison"] * 5
		+ power["total_city_def"] * 2
		+ power["resource_count"] * 15
		+ (50 if power["has_capital"] else 0)
	)

	return power

## Get controlled territory count for a player within a specific nation.
func get_player_nation_control_count(player_id: int, nation_id: String) -> Dictionary:
	var nation_tiles: Array = FixedMapData.get_nation_territory_ids(nation_id)
	var controlled: int = 0
	for tid in nation_tiles:
		if territory_owners.get(tid, -1) == player_id:
			controlled += 1
	return {"controlled": controlled, "total": nation_tiles.size()}

# ---------------------------------------------------------------------------
# Nation-wide events
# ---------------------------------------------------------------------------

## Spread rebellion within a nation: if one territory rebels, adjacent tiles in
## the same nation have a chance to also rebel.
func spread_rebellion_in_nation(tile_id: int, rebellion_chance: float = 0.3) -> Array:
	var territory: Dictionary = _get_territory(tile_id)
	if territory.size() == 0:
		return []

	var nation_id: String = territory["nation_id"]
	var spread_tiles: Array = []

	for conn_id in territory["connections"]:
		var neighbor: Dictionary = _get_territory(conn_id)
		if neighbor.size() == 0:
			continue
		if neighbor["nation_id"] != nation_id:
			continue
		if randf() < rebellion_chance:
			spread_tiles.append(conn_id)

	return spread_tiles

## Apply capital loss penalty: when a nation's capital is captured, all remaining
## territories of that nation suffer a morale penalty.
func get_capital_loss_penalty(nation_id: String) -> int:
	var capital: Variant = FixedMapData.get_nation_capital(nation_id)
	if capital == null:
		return 0
	# Check if capital is controlled by its original faction
	var capital_owner: int = territory_owners.get(capital["id"], -1)
	var original_faction: int = _faction_string_to_owner(capital["faction"])
	if capital_owner != original_faction:
		return CAPITAL_LOSS_MORALE_PENALTY
	return 0

# ---------------------------------------------------------------------------
# Summary & display
# ---------------------------------------------------------------------------

## Get a summary of all nations for display purposes.
func get_nations_summary() -> Array:
	var result: Array = []
	for nation_id in FixedMapData.NATION_IDS:
		var nation_name: String = FixedMapData.NATION_NAMES.get(nation_id, "")
		var power: Dictionary = calculate_nation_power(nation_id)
		var controller: int = nation_controllers.get(nation_id, -1)
		var bonus: Dictionary = NATION_BONUSES.get(nation_id, {})
		result.append({
			"nation_id": nation_id,
			"nation_name": nation_name,
			"controller": controller,
			"power": power,
			"bonus_name": bonus.get("name", ""),
			"bonus_description": bonus.get("description", ""),
			"border_territories": get_border_territories(nation_id),
		})
	return result

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _get_territory(tile_id: int) -> Dictionary:
	if tile_id >= 0 and tile_id < FixedMapData.TERRITORIES.size():
		return FixedMapData.TERRITORIES[tile_id]
	return {}

func _faction_string_to_owner(faction: String) -> int:
	match faction:
		"ORC":
			return FactionData.FactionID.ORC
		"PIRATE":
			return FactionData.FactionID.PIRATE
		"DARK_ELF":
			return FactionData.FactionID.DARK_ELF
		"HUMAN":
			return 100
		"HIGH_ELF":
			return 101
		"MAGE":
			return 102
		"BANDIT":
			return 200
		"NEUTRAL":
			return -1
		_:
			return -1
