## tile_development.gd — Tile Development Path System
## Each owned tile must choose ONE of three development paths.
## Paths are mutually exclusive and have different progression trees.
## This creates genuine economic tradeoffs: military power vs economic growth vs cultural influence.
extends Node

# Development paths
enum DevPath { UNDEVELOPED, MILITARY, ECONOMIC, CULTURAL }

# Each tile gets a limited number of building slots based on tile level
# Lv1: 1 slot, Lv2: 2 slots, Lv3: 3 slots, Lv4: 3 slots, Lv5: 4 slots
const SLOTS_PER_LEVEL: Array = [1, 2, 3, 3, 4]

# Path bonuses that scale with investment (number of path-specific buildings)
const PATH_BONUSES: Dictionary = {
	DevPath.MILITARY: {
		"name": "军事要塞",
		"desc": "强化军事能力, 但经济产出降低",
		"per_building": {
			"garrison_bonus": 3,        # +3 garrison cap per military building
			"recruit_discount": 0.05,   # -5% recruit cost per building
			"def_bonus": 1,             # +1 DEF to units recruited here
		},
		"global_penalty": {
			"gold_mult": 0.85,          # -15% gold production
			"food_mult": 0.90,          # -10% food production
		},
		"tier_unlocks": {  # at N military buildings, unlock special
			2: "elite_training_local",    # recruit T2 units here
			3: "fortress_walls",          # +15 wall HP
			4: "war_academy",             # recruit T3 units, +2 ATK all units from this tile
		},
	},
	DevPath.ECONOMIC: {
		"name": "商业中心",
		"desc": "最大化经济产出, 但军事防御薄弱",
		"per_building": {
			"gold_bonus": 8,            # +8 gold/turn per economic building
			"trade_bonus": 0.10,        # +10% trade income per building
			"iron_bonus": 2,            # +2 iron/turn per building
		},
		"global_penalty": {
			"garrison_cap_mult": 0.70,  # -30% garrison capacity
			"def_mult": 0.85,           # -15% DEF for defenders
		},
		"tier_unlocks": {
			2: "trade_hub",              # +25% income from ALL adjacent tiles
			3: "merchant_guild_hq",      # can recruit mercenaries (gold instead of iron)
			4: "economic_hegemon",       # +50% gold production, adjacent tiles +15% gold
		},
	},
	DevPath.CULTURAL: {
		"name": "文化圣地",
		"desc": "提升声望和秩序, 影响外交和英雄关系",
		"per_building": {
			"order_bonus": 5,           # +5 public order per cultural building
			"prestige_bonus": 1,        # +1 prestige/turn per building
			"hero_exp_bonus": 0.10,     # +10% hero EXP per building
		},
		"global_penalty": {
			"iron_mult": 0.80,          # -20% iron production
			"recruit_cost_mult": 1.15,  # +15% recruit cost
		},
		"tier_unlocks": {
			2: "sacred_ground",          # +2 affection gain rate for heroes stationed here
			3: "diplomatic_center",      # -20% diplomacy costs, +10 reputation cap
			4: "cultural_beacon",        # adjacent tiles auto-gain +3 order/turn, hero skills cooldown -1
		},
	},
}

# Buildings available per path (each costs gold + iron, takes 1 slot)
const PATH_BUILDINGS: Dictionary = {
	DevPath.MILITARY: [
		{"id": "barracks", "name": "兵营", "cost_gold": 120, "cost_iron": 30,
		 "effect": {"garrison": 5, "recruit_speed": 1}, "desc": "驻军+5, 征兵速度+1"},
		{"id": "armory", "name": "军械库", "cost_gold": 200, "cost_iron": 60,
		 "effect": {"atk_bonus": 1, "def_bonus": 1}, "desc": "本地部队ATK+1, DEF+1"},
		{"id": "watchtower_mil", "name": "哨塔", "cost_gold": 80, "cost_iron": 15,
		 "effect": {"vision": 2, "ambush_immune": true}, "desc": "视野+2, 免疫奇袭"},
		{"id": "siege_workshop", "name": "攻城工坊", "cost_gold": 300, "cost_iron": 80,
		 "effect": {"siege_bonus": 0.30}, "desc": "攻城伤害+30%"},
		{"id": "training_ground", "name": "练兵场", "cost_gold": 250, "cost_iron": 40,
		 "effect": {"exp_bonus": 0.25, "morale_start": 10}, "desc": "英雄EXP+25%, 初始士气+10"},
	],
	DevPath.ECONOMIC: [
		{"id": "marketplace", "name": "市场", "cost_gold": 100, "cost_iron": 10,
		 "effect": {"gold_per_turn": 12}, "desc": "+12金/回合"},
		{"id": "warehouse", "name": "仓库", "cost_gold": 150, "cost_iron": 25,
		 "effect": {"storage_mult": 1.5, "iron_per_turn": 3}, "desc": "仓储x1.5, +3铁/回合"},
		{"id": "slave_market_eco", "name": "奴隶市场", "cost_gold": 180, "cost_iron": 20,
		 "effect": {"slave_income": 0.3, "gold_per_turn": 6}, "desc": "奴隶产出+30%, +6金"},
		{"id": "trade_post_eco", "name": "贸易站", "cost_gold": 200, "cost_iron": 15,
		 "effect": {"trade_income_mult": 1.25, "food_per_turn": 5}, "desc": "贸易+25%, +5粮"},
		{"id": "bank", "name": "钱庄", "cost_gold": 400, "cost_iron": 30,
		 "effect": {"gold_per_turn": 20, "interest": 0.02}, "desc": "+20金/回合, 存款+2%/回合"},
	],
	DevPath.CULTURAL: [
		{"id": "temple", "name": "神殿", "cost_gold": 150, "cost_iron": 20,
		 "effect": {"order": 8, "prestige_per_turn": 1}, "desc": "秩序+8, +1威望/回合"},
		{"id": "academy_cul", "name": "学院", "cost_gold": 200, "cost_iron": 25,
		 "effect": {"research_speed": 0.15, "hero_exp": 0.15}, "desc": "研究+15%, 英雄EXP+15%"},
		{"id": "arena_cul", "name": "竞技场", "cost_gold": 250, "cost_iron": 35,
		 "effect": {"order": 5, "morale_global": 5, "gold_per_turn": 5}, "desc": "秩序+5, 全军士气+5, +5金"},
		{"id": "monument", "name": "纪念碑", "cost_gold": 180, "cost_iron": 40,
		 "effect": {"prestige_per_turn": 2, "order": 3}, "desc": "+2威望/回合, 秩序+3"},
		{"id": "hero_shrine", "name": "英雄祠", "cost_gold": 300, "cost_iron": 30,
		 "effect": {"affection_bonus": 1, "hero_skill_cd": -1}, "desc": "好感+1/回合, 技能冷却-1"},
	],
}

# Tile development state storage
# Key: tile_index (int), Value: { "path": DevPath, "buildings": Array[String], "committed": bool }
var _tile_dev: Dictionary = {}


func get_tile_development(tile_idx: int) -> Dictionary:
	if not _tile_dev.has(tile_idx):
		_tile_dev[tile_idx] = {"path": DevPath.UNDEVELOPED, "buildings": [], "committed": false}
	return _tile_dev[tile_idx]


func get_available_slots(tile_idx: int) -> int:
	var tile_level: int = _get_tile_level(tile_idx)
	var max_slots: int = SLOTS_PER_LEVEL[mini(tile_level - 1, SLOTS_PER_LEVEL.size() - 1)]
	var used: int = get_tile_development(tile_idx)["buildings"].size()
	return maxi(max_slots - used, 0)


func choose_path(tile_idx: int, path: int) -> bool:
	var dev: Dictionary = get_tile_development(tile_idx)
	if dev["committed"]:
		return false  # Already committed to a path
	if path == DevPath.UNDEVELOPED:
		return false
	dev["path"] = path
	dev["committed"] = true
	_tile_dev[tile_idx] = dev
	EventBus.tile_path_chosen.emit(tile_idx, path)
	return true


func can_build(tile_idx: int, building_id: String) -> Dictionary:
	var dev: Dictionary = get_tile_development(tile_idx)
	if not dev["committed"]:
		return {"can": false, "reason": "未选择发展路线"}
	if get_available_slots(tile_idx) <= 0:
		return {"can": false, "reason": "建筑槽位已满"}
	if building_id in dev["buildings"]:
		return {"can": false, "reason": "已建造此建筑"}
	# Check if building belongs to chosen path
	var path_buildings: Array = PATH_BUILDINGS.get(dev["path"], [])
	var found: bool = false
	var cost_gold: int = 0
	var cost_iron: int = 0
	for bld in path_buildings:
		if bld["id"] == building_id:
			found = true
			cost_gold = bld["cost_gold"]
			cost_iron = bld["cost_iron"]
			break
	if not found:
		return {"can": false, "reason": "此建筑不属于当前发展路线"}
	return {"can": true, "cost_gold": cost_gold, "cost_iron": cost_iron}


func build(tile_idx: int, building_id: String) -> bool:
	var check: Dictionary = can_build(tile_idx, building_id)
	if not check["can"]:
		return false
	var dev: Dictionary = get_tile_development(tile_idx)
	dev["buildings"].append(building_id)
	_tile_dev[tile_idx] = dev
	EventBus.tile_building_built.emit(tile_idx, building_id)
	return true


func get_tile_path_effects(tile_idx: int) -> Dictionary:
	var dev: Dictionary = get_tile_development(tile_idx)
	var effects: Dictionary = {}
	if dev["path"] == DevPath.UNDEVELOPED:
		return effects

	var path_data: Dictionary = PATH_BONUSES.get(dev["path"], {})
	var num_buildings: int = dev["buildings"].size()

	# Per-building bonuses (scaled)
	var per_bld: Dictionary = path_data.get("per_building", {})
	for key in per_bld:
		effects[key] = per_bld[key] * num_buildings

	# Global penalties (constant once path is chosen)
	var penalties: Dictionary = path_data.get("global_penalty", {})
	for key in penalties:
		effects[key] = penalties[key]

	# Tier unlocks
	var tier_unlocks: Dictionary = path_data.get("tier_unlocks", {})
	for threshold in tier_unlocks:
		if num_buildings >= threshold:
			effects[tier_unlocks[threshold]] = true

	# Individual building effects
	var path_buildings: Array = PATH_BUILDINGS.get(dev["path"], [])
	for built_id in dev["buildings"]:
		for bld_def in path_buildings:
			if bld_def["id"] == built_id:
				for key in bld_def["effect"]:
					if effects.has(key):
						if typeof(effects[key]) == TYPE_FLOAT or typeof(effects[key]) == TYPE_INT:
							effects[key] = effects[key] + bld_def["effect"][key]
						else:
							effects[key] = bld_def["effect"][key]
					else:
						effects[key] = bld_def["effect"][key]

	return effects


func get_adjacent_effects(tile_idx: int) -> Dictionary:
	## Get effects that spill over to adjacent tiles from this tile's development
	var dev: Dictionary = get_tile_development(tile_idx)
	var effects: Dictionary = {}
	var num_buildings: int = dev["buildings"].size()

	if dev["path"] == DevPath.ECONOMIC and num_buildings >= 2:
		effects["gold_mult_adjacent"] = 1.25  # trade_hub
	if dev["path"] == DevPath.ECONOMIC and num_buildings >= 4:
		effects["gold_mult_adjacent"] = 1.50  # economic_hegemon stacks
	if dev["path"] == DevPath.CULTURAL and num_buildings >= 4:
		effects["order_per_turn_adjacent"] = 3  # cultural_beacon

	return effects


func get_path_name(path: int) -> String:
	match path:
		DevPath.MILITARY:
			return "军事要塞"
		DevPath.ECONOMIC:
			return "商业中心"
		DevPath.CULTURAL:
			return "文化圣地"
		_:
			return "未开发"


func get_path_buildings_list(path: int) -> Array:
	return PATH_BUILDINGS.get(path, [])


# Save/Load support
func to_save_data() -> Dictionary:
	return {"tile_dev": _tile_dev.duplicate(true)}


func from_save_data(data: Dictionary) -> void:
	_tile_dev = data.get("tile_dev", {})
	# Fix int keys after JSON round-trip (keys become strings)
	var keys_to_fix: Array = []
	for k in _tile_dev:
		if k is String and k.is_valid_int():
			keys_to_fix.append(k)
	for k in keys_to_fix:
		_tile_dev[int(k)] = _tile_dev[k]
		_tile_dev.erase(k)


func _get_tile_level(tile_idx: int) -> int:
	if tile_idx >= 0 and tile_idx < GameManager.tiles.size():
		return GameManager.tiles[tile_idx].get("level", 1)
	return 1
