## terrain_tile_bridge.gd
## v1.4.0 — 地形-地块深度连接系统
## 作为地形系统与地块所有子系统（战斗/生产/移动/建筑/天气/视野/改造）的统一桥接层。
## 所有需要地形信息的系统应通过此模块查询，而不是直接读取 FactionData.TERRAIN_DATA。
extends Node

# ══════════════════════════════════════════════════════════════════════════════
# 1. 地形改造系统 — 允许玩家花费资源改变地块地形
# ══════════════════════════════════════════════════════════════════════════════

## 地形改造配方：key=目标地形, value=改造条件与费用
const TERRAIN_TRANSFORM_RECIPES: Dictionary = {
	# 平原 ← 可由荒原/沼泽改造而来
	FactionData.TerrainType.PLAINS: {
		"name": "开垦平原",
		"icon": "🌾",
		"desc": "将荒原或沼泽开垦为肥沃平原，大幅提升农业产出",
		"from_terrains": [FactionData.TerrainType.WASTELAND, FactionData.TerrainType.SWAMP],
		"cost": {"gold": 60, "iron": 20},
		"ap_cost": 2,
		"turns_required": 3,
		"min_tile_level": 1,
		"production_bonus_on_complete": {"food": 2},
	},
	# 森林 ← 可由平原/荒原人工造林
	FactionData.TerrainType.FOREST: {
		"name": "人工造林",
		"icon": "🌲",
		"desc": "在平原或荒原种植树木，形成防御森林",
		"from_terrains": [FactionData.TerrainType.PLAINS, FactionData.TerrainType.WASTELAND],
		"cost": {"gold": 40, "food": 30},
		"ap_cost": 1,
		"turns_required": 4,
		"min_tile_level": 1,
		"production_bonus_on_complete": {"iron": 1},
	},
	# 沿海 ← 不可人工改造（地理限制）
	# 河川 ← 不可人工改造（地理限制）
	# 荒原 ← 可由平原过度开发退化
	FactionData.TerrainType.WASTELAND: {
		"name": "过度开发（退化）",
		"icon": "🏜️",
		"desc": "警告：过度开发导致土地退化为荒原，产出大幅下降",
		"from_terrains": [FactionData.TerrainType.PLAINS],
		"cost": {},
		"ap_cost": 0,
		"turns_required": 0,
		"min_tile_level": 0,
		"is_degradation": true,  # 标记为退化（负面改造）
		"trigger_condition": "over_exploitation",
	},
}

## 筑路系统：在地块间建造道路，降低移动消耗
const ROAD_BUILD_COST: Dictionary = {
	"gold": 30, "iron": 10, "ap": 1, "turns": 2,
}
## 道路对移动力的修正（覆盖地形移动消耗）
const ROAD_MOVE_COST_OVERRIDE: Dictionary = {
	FactionData.TerrainType.PLAINS:       1,  # 无变化
	FactionData.TerrainType.FOREST:       1,  # 2→1（节省1点）
	FactionData.TerrainType.MOUNTAIN:     2,  # 3→2（节省1点）
	FactionData.TerrainType.SWAMP:        2,  # 3→2（节省1点）
	FactionData.TerrainType.WASTELAND:    1,  # 无变化
	FactionData.TerrainType.RIVER:        1,  # 2→1（桥梁）
	FactionData.TerrainType.VOLCANIC:     2,  # 3→2（节省1点）
	FactionData.TerrainType.RUINS:        1,  # 2→1（清理废墟）
	FactionData.TerrainType.COASTAL:      1,  # 无变化
	FactionData.TerrainType.FORTRESS_WALL:1,  # 无变化
}

# ══════════════════════════════════════════════════════════════════════════════
# 2. 地形-生产深度修正表
#    区分具体资源类型（金/粮/铁/木材/魔晶），而非单一 production_mult
# ══════════════════════════════════════════════════════════════════════════════

const TERRAIN_RESOURCE_MODS: Dictionary = {
	FactionData.TerrainType.PLAINS: {
		"gold_mult": 1.0, "food_mult": 1.3, "iron_mult": 0.8,
		"wood_bonus": 0,  "magic_crystal_mult": 0.5,
		"pop_growth_mult": 1.2,  # 平原人口增长快
		"building_cost_mult": 1.0,
		"desc": "粮食产出+30%，人口增长+20%",
	},
	FactionData.TerrainType.FOREST: {
		"gold_mult": 0.8, "food_mult": 0.9, "iron_mult": 0.9,
		"wood_bonus": 3,  "magic_crystal_mult": 1.0,
		"pop_growth_mult": 0.9,
		"building_cost_mult": 0.9,  # 木材充足，建造费用-10%
		"desc": "木材+3/回，建造费用-10%",
	},
	FactionData.TerrainType.MOUNTAIN: {
		"gold_mult": 0.9, "food_mult": 0.5, "iron_mult": 1.8,
		"wood_bonus": 0,  "magic_crystal_mult": 1.5,
		"pop_growth_mult": 0.7,
		"building_cost_mult": 1.3,  # 山地建造困难，费用+30%
		"desc": "铁矿产出+80%，魔晶+50%，粮食-50%，建造费+30%",
	},
	FactionData.TerrainType.SWAMP: {
		"gold_mult": 0.6, "food_mult": 0.7, "iron_mult": 0.7,
		"wood_bonus": 1,  "magic_crystal_mult": 0.8,
		"pop_growth_mult": 0.6,
		"building_cost_mult": 1.5,  # 沼泽建造极难，费用+50%
		"desc": "所有产出大幅下降，建造费+50%",
	},
	FactionData.TerrainType.COASTAL: {
		"gold_mult": 1.4, "food_mult": 1.1, "iron_mult": 0.9,
		"wood_bonus": 0,  "magic_crystal_mult": 0.8,
		"pop_growth_mult": 1.3,  # 沿海贸易繁荣
		"building_cost_mult": 1.0,
		"desc": "金币产出+40%，人口增长+30%（贸易繁荣）",
	},
	FactionData.TerrainType.FORTRESS_WALL: {
		"gold_mult": 0.7, "food_mult": 0.8, "iron_mult": 1.0,
		"wood_bonus": 0,  "magic_crystal_mult": 0.5,
		"pop_growth_mult": 0.8,
		"building_cost_mult": 0.8,  # 已有基础设施，建造费-20%
		"desc": "城墙地形：建造费-20%，但产出受限",
	},
	FactionData.TerrainType.RIVER: {
		"gold_mult": 1.1, "food_mult": 1.2, "iron_mult": 0.9,
		"wood_bonus": 1,  "magic_crystal_mult": 0.7,
		"pop_growth_mult": 1.1,
		"building_cost_mult": 1.1,  # 河流建造需要防水处理
		"desc": "粮食+20%，金币+10%（水运便利）",
	},
	FactionData.TerrainType.RUINS: {
		"gold_mult": 0.5, "food_mult": 0.4, "iron_mult": 0.6,
		"wood_bonus": 0,  "magic_crystal_mult": 2.0,  # 遗迹魔力丰富
		"pop_growth_mult": 0.5,
		"building_cost_mult": 0.7,  # 利用遗迹材料，建造费-30%
		"desc": "魔晶产出×2，建造费-30%，但基础产出极低",
	},
	FactionData.TerrainType.WASTELAND: {
		"gold_mult": 0.7, "food_mult": 0.4, "iron_mult": 0.8,
		"wood_bonus": 0,  "magic_crystal_mult": 0.5,
		"pop_growth_mult": 0.5,
		"building_cost_mult": 1.2,
		"desc": "粮食-60%，人口增长-50%",
	},
	FactionData.TerrainType.VOLCANIC: {
		"gold_mult": 0.5, "food_mult": 0.2, "iron_mult": 2.5,  # 火山铁矿极丰富
		"wood_bonus": 0,  "magic_crystal_mult": 1.2,
		"pop_growth_mult": 0.3,
		"building_cost_mult": 1.8,  # 极端环境建造极难
		"desc": "铁矿产出×2.5，但粮食-80%，建造费+80%",
	},
}

# ══════════════════════════════════════════════════════════════════════════════
# 3. 地形-天气交叉修正表
#    特定地形+特定天气组合产生额外效果
# ══════════════════════════════════════════════════════════════════════════════

## 地形+天气组合的额外修正
## key: [terrain_type, weather_type] → 额外效果
const TERRAIN_WEATHER_CROSS_MODS: Dictionary = {
	# 森林+干旱 = 火灾风险
	"FOREST_DROUGHT": {
		"terrain": FactionData.TerrainType.FOREST,
		"weather": 5,  # Weather.DROUGHT
		"atk_mult_mod": 0.0, "def_mult_mod": -0.15,
		"food_mult_mod": -0.3, "gold_mult_mod": 0.0,
		"move_cost_add": 0,
		"attrition_add": 0.03,  # 额外减员（火灾）
		"special": "forest_fire_risk",
		"desc": "森林干旱：火灾风险+，防御-15%，减员+3%",
	},
	# 沼泽+大雪 = 冰封沼泽（移动变容易）
	"SWAMP_SNOW": {
		"terrain": FactionData.TerrainType.SWAMP,
		"weather": 4,  # Weather.SNOW
		"atk_mult_mod": 0.0, "def_mult_mod": 0.0,
		"food_mult_mod": -0.2, "gold_mult_mod": 0.0,
		"move_cost_add": -1,  # 冰封后移动变容易
		"attrition_add": 0.02,
		"special": "frozen_swamp",
		"desc": "冰封沼泽：移动消耗-1，但减员+2%",
	},
	# 山地+大雪 = 雪崩风险
	"MOUNTAIN_SNOW": {
		"terrain": FactionData.TerrainType.MOUNTAIN,
		"weather": 4,  # Weather.SNOW
		"atk_mult_mod": -0.10, "def_mult_mod": 0.10,
		"food_mult_mod": -0.4, "gold_mult_mod": -0.2,
		"move_cost_add": 1,  # 雪地山地更难行进
		"attrition_add": 0.04,
		"special": "avalanche_risk",
		"desc": "雪山：雪崩风险，移动+1，减员+4%，防御+10%",
	},
	# 河川+季风 = 洪水
	"RIVER_MONSOON": {
		"terrain": FactionData.TerrainType.RIVER,
		"weather": 6,  # Weather.MONSOON
		"atk_mult_mod": -0.20, "def_mult_mod": -0.10,
		"food_mult_mod": 0.20,  # 洪水带来肥沃土壤
		"gold_mult_mod": -0.30,
		"move_cost_add": 2,  # 洪水使河流难以渡过
		"attrition_add": 0.01,
		"special": "flood",
		"desc": "洪水：渡河消耗+2，金币-30%，但粮食+20%",
	},
	# 沿海+暴风 = 海浪封港
	"COASTAL_STORM": {
		"terrain": FactionData.TerrainType.COASTAL,
		"weather": 3,  # Weather.STORM
		"atk_mult_mod": -0.10, "def_mult_mod": 0.0,
		"food_mult_mod": -0.1, "gold_mult_mod": -0.4,  # 港口关闭
		"move_cost_add": 1,
		"attrition_add": 0.0,
		"special": "harbor_closed",
		"desc": "暴风封港：金币-40%，港口关闭，移动+1",
	},
	# 火山+干旱 = 火山活跃（极端危险）
	"VOLCANIC_DROUGHT": {
		"terrain": FactionData.TerrainType.VOLCANIC,
		"weather": 5,  # Weather.DROUGHT
		"atk_mult_mod": 0.15, "def_mult_mod": -0.20,
		"food_mult_mod": -0.5, "gold_mult_mod": 0.0,
		"move_cost_add": 1,
		"attrition_add": 0.08,  # 极高减员
		"special": "volcanic_eruption_risk",
		"desc": "火山活跃：减员+8%，攻击+15%，防御-20%",
	},
	# 平原+季风 = 丰收
	"PLAINS_MONSOON": {
		"terrain": FactionData.TerrainType.PLAINS,
		"weather": 6,  # Weather.MONSOON
		"atk_mult_mod": 0.0, "def_mult_mod": 0.0,
		"food_mult_mod": 0.40,  # 季风带来丰收
		"gold_mult_mod": 0.10,
		"move_cost_add": 0,
		"attrition_add": 0.0,
		"special": "harvest_season",
		"desc": "平原季风：粮食+40%，金币+10%（丰收）",
	},
	# 荒原+干旱 = 沙漠化
	"WASTELAND_DROUGHT": {
		"terrain": FactionData.TerrainType.WASTELAND,
		"weather": 5,  # Weather.DROUGHT
		"atk_mult_mod": 0.0, "def_mult_mod": -0.10,
		"food_mult_mod": -0.5, "gold_mult_mod": -0.2,
		"move_cost_add": 0,
		"attrition_add": 0.04,
		"special": "desertification",
		"desc": "沙漠化：粮食-50%，减员+4%",
	},
}

# ══════════════════════════════════════════════════════════════════════════════
# 4. 地形-视野系统
#    计算地块的实际视野范围（地形基础 + 天气修正 + 建筑加成）
# ══════════════════════════════════════════════════════════════════════════════

## 建筑对视野的加成
const BUILDING_VISIBILITY_BONUS: Dictionary = {
	"watchtower": 2,
	"lighthouse": 3,
	"scout_post": 1,
	"signal_tower": 2,
}

## 计算指定地块的实际视野范围
static func get_tile_visibility(tile: Dictionary) -> int:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
	var base_visibility: int = terrain_data.get("visibility_range", 2)

	# 天气修正
	var weather_mod: int = 0
	if WeatherSystem != null and WeatherSystem.has_method("get_visibility_modifier"):
		weather_mod = WeatherSystem.get_visibility_modifier()

	# 建筑加成
	var building_bonus: int = 0
	var bld_id: String = tile.get("building_id", "")
	if bld_id in BUILDING_VISIBILITY_BONUS:
		building_bonus = BUILDING_VISIBILITY_BONUS[bld_id]

	# 道路加成（道路网络提升侦察效率）
	var road_bonus: int = 1 if tile.get("has_road", false) else 0

	# 特殊标志处理
	if weather_mod == -99:
		# 浓雾：视野减半
		return max(1, int(base_visibility / 2) + building_bonus)

	return max(1, base_visibility + weather_mod + building_bonus + road_bonus)


## 判断地块是否具有伏击地形优势
static func has_ambush_terrain(tile: Dictionary) -> bool:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
	var flags: Array = terrain_data.get("special_flags", [])
	return "ambush_terrain" in flags or "cover_terrain" in flags


## 计算伏击成功率加成（地形 + 天气 + 技能）
static func get_ambush_bonus(tile: Dictionary) -> float:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
	var flags: Array = terrain_data.get("special_flags", [])

	var bonus: float = 0.0
	if "ambush_terrain" in flags:
		bonus += 0.25  # 森林/沼泽基础伏击加成25%
	if "cover_terrain" in flags:
		bonus += 0.15  # 掩体地形15%

	# 天气加成
	if WeatherSystem != null and WeatherSystem.has_method("get_combat_modifiers"):
		var weather_mods: Dictionary = WeatherSystem.get_combat_modifiers()
		bonus += weather_mods.get("ambush_bonus", 0.0)

	# 地形+天气交叉效果
	var cross_mod: Dictionary = get_terrain_weather_cross_mod(tile)
	if cross_mod.get("special", "") == "forest_fire_risk":
		bonus -= 0.10  # 火灾降低伏击效果

	return clamp(bonus, 0.0, 0.75)

# ══════════════════════════════════════════════════════════════════════════════
# 5. 地形-移动系统
#    统一计算移动消耗（地形 + 道路 + 天气 + 季节）
# ══════════════════════════════════════════════════════════════════════════════

## 获取地块的实际移动消耗
static func get_tile_move_cost(tile: Dictionary) -> int:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
	var base_cost: int = terrain_data.get("move_cost", 1)

	# 道路覆盖
	if tile.get("has_road", false):
		base_cost = ROAD_MOVE_COST_OVERRIDE.get(terrain_type, base_cost)

	# 天气额外消耗
	var weather_extra: int = 0
	if WeatherSystem != null and WeatherSystem.has_method("get_movement_cost_modifier"):
		weather_extra = WeatherSystem.get_movement_cost_modifier()

	# 地形+天气交叉修正
	var cross_mod: Dictionary = get_terrain_weather_cross_mod(tile)
	var cross_extra: int = cross_mod.get("move_cost_add", 0)

	return max(1, base_cost + weather_extra + cross_extra)


## 判断指定兵种是否被禁止进入该地形
static func is_unit_banned(tile: Dictionary, unit_type: String) -> bool:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
	var unit_mods: Dictionary = terrain_data.get("unit_mods", {})
	# 标准化兵种名称（去除前缀）
	var base_type: String = unit_type.replace("light_", "").replace("dark_", "").replace("neutral_", "")
	return unit_mods.get(base_type, {}).get("ban", false)

# ══════════════════════════════════════════════════════════════════════════════
# 6. 地形-生产统一计算接口
# ══════════════════════════════════════════════════════════════════════════════

## 获取地块的地形生产修正（整合地形+天气+季节+道路+改造状态）
static func get_tile_production_mods(tile: Dictionary) -> Dictionary:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var base_mods: Dictionary = TERRAIN_RESOURCE_MODS.get(terrain_type, TERRAIN_RESOURCE_MODS[FactionData.TerrainType.PLAINS]).duplicate()

	# 天气生产修正
	if WeatherSystem != null and WeatherSystem.has_method("get_production_modifiers"):
		var weather_prod: Dictionary = WeatherSystem.get_production_modifiers()
		base_mods["gold_mult"] *= weather_prod.get("gold_mult", 1.0)
		base_mods["food_mult"] *= weather_prod.get("food_mult", 1.0)
		base_mods["iron_mult"] *= weather_prod.get("iron_mult", 1.0)

		# 河川/沿海地形的天气特殊修正
		if terrain_type in [FactionData.TerrainType.RIVER, FactionData.TerrainType.COASTAL]:
			var river_coastal_mult: float = weather_prod.get("river_coastal_production_mult", 1.0)
			base_mods["gold_mult"] *= river_coastal_mult
			base_mods["food_mult"] *= river_coastal_mult

	# 地形+天气交叉修正
	var cross_mod: Dictionary = get_terrain_weather_cross_mod(tile)
	if not cross_mod.is_empty():
		base_mods["gold_mult"] *= (1.0 + cross_mod.get("gold_mult_mod", 0.0))
		base_mods["food_mult"] *= (1.0 + cross_mod.get("food_mult_mod", 0.0))

	# 道路加成：道路网络提升贸易效率
	if tile.get("has_road", false):
		base_mods["gold_mult"] *= 1.10  # 道路带来+10%金币（贸易）

	# 地形改造状态加成
	var transform_bonus: Dictionary = tile.get("terrain_transform_bonus", {})
	for key in transform_bonus:
		if key in base_mods:
			base_mods[key] += transform_bonus[key]

	return base_mods


## 获取地块的建造费用修正系数
static func get_building_cost_mult(tile: Dictionary) -> float:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var base_mult: float = TERRAIN_RESOURCE_MODS.get(terrain_type, {}).get("building_cost_mult", 1.0)

	# 天气影响建造（暴风/大雪增加建造难度）
	if WeatherSystem != null:
		var current_weather = WeatherSystem.current_weather
		if current_weather in [3, 4]:  # STORM, SNOW
			base_mult *= 1.20  # 恶劣天气建造费+20%

	return base_mult


## 获取地块的人口增长修正
static func get_pop_growth_mult(tile: Dictionary) -> float:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var base_mult: float = TERRAIN_RESOURCE_MODS.get(terrain_type, {}).get("pop_growth_mult", 1.0)

	# 季节影响人口增长
	if WeatherSystem != null:
		var current_season = WeatherSystem.current_season
		if current_season == 0:  # SPRING
			base_mult *= 1.10  # 春季人口增长+10%
		elif current_season == 3:  # WINTER
			base_mult *= 0.85  # 冬季人口增长-15%

	return base_mult

# ══════════════════════════════════════════════════════════════════════════════
# 7. 地形-战斗统一计算接口
# ══════════════════════════════════════════════════════════════════════════════

## 获取地块的完整战斗修正（地形+天气+交叉效果）
static func get_tile_combat_mods(tile: Dictionary) -> Dictionary:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})

	var atk_mult: float = terrain_data.get("atk_mult", 1.0)
	var def_mult: float = terrain_data.get("def_mult", 1.0)
	var attrition: float = terrain_data.get("attrition_pct", 0.0)

	# 天气战斗修正
	if WeatherSystem != null and WeatherSystem.has_method("get_combat_modifiers"):
		var weather_mods: Dictionary = WeatherSystem.get_combat_modifiers()
		atk_mult *= (1.0 + weather_mods.get("atk_mod", 0) / 10.0)
		def_mult *= (1.0 + weather_mods.get("def_mod", 0) / 10.0)

	# 地形+天气交叉修正
	var cross_mod: Dictionary = get_terrain_weather_cross_mod(tile)
	if not cross_mod.is_empty():
		atk_mult *= (1.0 + cross_mod.get("atk_mult_mod", 0.0))
		def_mult *= (1.0 + cross_mod.get("def_mult_mod", 0.0))
		attrition += cross_mod.get("attrition_add", 0.0)

	return {
		"atk_mult": atk_mult,
		"def_mult": def_mult,
		"attrition_pct": attrition,
		"ambush_bonus": get_ambush_bonus(tile),
		"unit_mods": terrain_data.get("unit_mods", {}),
		"special_flags": terrain_data.get("special_flags", []),
	}


## 计算地形减员（每回合）
static func calculate_terrain_attrition(tile: Dictionary, garrison: int) -> int:
	if garrison <= 0:
		return 0
	var mods: Dictionary = get_tile_combat_mods(tile)
	var attrition_pct: float = mods.get("attrition_pct", 0.0)
	if attrition_pct <= 0.0:
		return 0
	return max(1, int(garrison * attrition_pct))

# ══════════════════════════════════════════════════════════════════════════════
# 8. 地形-地块升级限制系统
# ══════════════════════════════════════════════════════════════════════════════

## 地形对地块升级的限制和加成
const TERRAIN_UPGRADE_MODS: Dictionary = {
	FactionData.TerrainType.PLAINS: {
		"max_level_bonus": 0,       # 无额外等级上限
		"upgrade_cost_mult": 1.0,
		"allowed_buildings": [],    # 空=无限制
		"forbidden_buildings": [],
		"special_unlock": [],
		"desc": "标准升级路径",
	},
	FactionData.TerrainType.FOREST: {
		"max_level_bonus": 0,
		"upgrade_cost_mult": 0.9,   # 木材充足，升级费-10%
		"allowed_buildings": [],
		"forbidden_buildings": ["market", "port"],  # 森林不适合建市场和港口
		"special_unlock": ["lumber_camp", "ranger_post"],
		"desc": "木材充足升级费-10%，可建伐木场和游骑兵哨所",
	},
	FactionData.TerrainType.MOUNTAIN: {
		"max_level_bonus": 1,       # 山地要塞可多升1级
		"upgrade_cost_mult": 1.3,
		"allowed_buildings": [],
		"forbidden_buildings": ["farm", "granary"],  # 山地不适合农业
		"special_unlock": ["mine_shaft", "mountain_fortress"],
		"desc": "要塞等级上限+1，可建矿井和山地要塞",
	},
	FactionData.TerrainType.SWAMP: {
		"max_level_bonus": -1,      # 沼泽地块等级上限-1
		"upgrade_cost_mult": 1.5,
		"allowed_buildings": [],
		"forbidden_buildings": ["cavalry_stable", "market", "granary"],
		"special_unlock": ["swamp_hideout", "poison_lab"],
		"desc": "等级上限-1，建造费+50%，可建沼泽巢穴和毒药工坊",
	},
	FactionData.TerrainType.COASTAL: {
		"max_level_bonus": 0,
		"upgrade_cost_mult": 1.0,
		"allowed_buildings": [],
		"forbidden_buildings": [],
		"special_unlock": ["harbor", "lighthouse", "fishing_dock"],
		"desc": "可建港口、灯塔和渔码头",
	},
	FactionData.TerrainType.FORTRESS_WALL: {
		"max_level_bonus": 1,
		"upgrade_cost_mult": 0.8,   # 已有基础设施
		"allowed_buildings": [],
		"forbidden_buildings": ["farm"],
		"special_unlock": ["arrow_tower", "moat", "command_center"],
		"desc": "等级上限+1，升级费-20%，可建箭塔/护城河/指挥中心",
	},
	FactionData.TerrainType.RIVER: {
		"max_level_bonus": 0,
		"upgrade_cost_mult": 1.1,
		"allowed_buildings": [],
		"forbidden_buildings": [],
		"special_unlock": ["bridge", "mill", "river_port"],
		"desc": "可建桥梁、水磨坊和河港",
	},
	FactionData.TerrainType.RUINS: {
		"max_level_bonus": 0,
		"upgrade_cost_mult": 0.7,   # 遗迹材料可利用
		"allowed_buildings": [],
		"forbidden_buildings": ["farm", "granary"],
		"special_unlock": ["relic_vault", "mage_tower", "arcane_lab"],
		"desc": "升级费-30%，可建遗物库、法师塔和秘法实验室",
	},
	FactionData.TerrainType.WASTELAND: {
		"max_level_bonus": -1,
		"upgrade_cost_mult": 1.2,
		"allowed_buildings": [],
		"forbidden_buildings": ["farm", "granary", "market"],
		"special_unlock": ["outpost", "desert_camp"],
		"desc": "等级上限-1，可建前哨站和荒漠营地",
	},
	FactionData.TerrainType.VOLCANIC: {
		"max_level_bonus": -1,
		"upgrade_cost_mult": 1.8,
		"allowed_buildings": [],
		"forbidden_buildings": ["farm", "granary", "market", "cavalry_stable"],
		"special_unlock": ["forge_of_flames", "obsidian_quarry"],
		"desc": "等级上限-1，建造费+80%，可建烈焰锻炉和黑曜石采石场",
	},
}


## 检查地形是否允许建造指定建筑
static func is_building_allowed_by_terrain(tile: Dictionary, building_id: String) -> Dictionary:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var upgrade_mods: Dictionary = TERRAIN_UPGRADE_MODS.get(terrain_type, {})
	var forbidden: Array = upgrade_mods.get("forbidden_buildings", [])
	if building_id in forbidden:
		var terrain_name: String = FactionData.TERRAIN_DATA.get(terrain_type, {}).get("name", "未知地形")
		return {"allowed": false, "reason": "%s地形不允许建造 %s" % [terrain_name, building_id]}
	return {"allowed": true}


## 获取地形解锁的特殊建筑列表
static func get_terrain_special_buildings(tile: Dictionary) -> Array:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	return TERRAIN_UPGRADE_MODS.get(terrain_type, {}).get("special_unlock", [])


## 获取地块的最大等级（受地形影响）
static func get_max_tile_level(tile: Dictionary, base_max_level: int = 5) -> int:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var bonus: int = TERRAIN_UPGRADE_MODS.get(terrain_type, {}).get("max_level_bonus", 0)
	return max(1, base_max_level + bonus)


## 获取地块的升级费用修正
static func get_upgrade_cost_mult(tile: Dictionary) -> float:
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	return TERRAIN_UPGRADE_MODS.get(terrain_type, {}).get("upgrade_cost_mult", 1.0)

# ══════════════════════════════════════════════════════════════════════════════
# 9. 地形改造执行系统
# ══════════════════════════════════════════════════════════════════════════════

## 存储进行中的地形改造任务：tile_idx → {target_terrain, turns_remaining, recipe}
var _transform_tasks: Dictionary = {}

## 开始地形改造
func start_terrain_transform(tile_idx: int, target_terrain: int) -> Dictionary:
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return {"success": false, "reason": "无效地块"}

	var tile: Dictionary = GameManager.tiles[tile_idx]
	var pid: int = GameManager.get_human_player_id()

	# 检查是否已有改造任务
	if tile_idx in _transform_tasks:
		return {"success": false, "reason": "该地块已有改造任务进行中"}

	# 查找改造配方
	var recipe: Dictionary = TERRAIN_TRANSFORM_RECIPES.get(target_terrain, {})
	if recipe.is_empty():
		return {"success": false, "reason": "该地形类型无法通过改造获得"}

	# 检查当前地形是否可改造
	var current_terrain: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	if current_terrain not in recipe.get("from_terrains", []):
		var terrain_name: String = FactionData.TERRAIN_DATA.get(current_terrain, {}).get("name", "当前地形")
		return {"success": false, "reason": "%s 无法改造为目标地形" % terrain_name}

	# 检查地块等级
	if tile.get("level", 1) < recipe.get("min_tile_level", 1):
		return {"success": false, "reason": "地块等级不足（需要 Lv%d）" % recipe["min_tile_level"]}

	# 检查行动点
	var player: Dictionary = GameManager.get_player_by_id(pid)
	if player.get("ap", 0) < recipe.get("ap_cost", 1):
		return {"success": false, "reason": "行动点不足"}

	# 检查资源
	var cost: Dictionary = recipe.get("cost", {})
	for res_key in cost:
		if ResourceManager.get_resource(pid, res_key) < cost[res_key]:
			return {"success": false, "reason": "资源不足（%s）" % res_key}

	# 扣除资源和行动点
	if not cost.is_empty():
		var neg_cost: Dictionary = {}
		for k in cost:
			neg_cost[k] = -cost[k]
		ResourceManager.apply_delta(pid, neg_cost)
	player["ap"] -= recipe.get("ap_cost", 1)

	# 记录改造任务
	_transform_tasks[tile_idx] = {
		"target_terrain": target_terrain,
		"turns_remaining": recipe.get("turns_required", 3),
		"recipe": recipe,
		"pid": pid,
	}

	var target_name: String = FactionData.TERRAIN_DATA.get(target_terrain, {}).get("name", "目标地形")
	EventBus.message_log.emit("[color=cyan]【地形改造】开始将地块 #%d 改造为 %s，需要 %d 回合[/color]" % [
		tile_idx, target_name, recipe.get("turns_required", 3)
	])

	if EventBus.has_signal("terrain_transform_started"):
		EventBus.terrain_transform_started.emit(tile_idx, current_terrain, target_terrain)

	return {"success": true, "turns_required": recipe.get("turns_required", 3)}


## 开始筑路
func start_road_construction(tile_idx: int) -> Dictionary:
	if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
		return {"success": false, "reason": "无效地块"}

	var tile: Dictionary = GameManager.tiles[tile_idx]
	if tile.get("has_road", false):
		return {"success": false, "reason": "该地块已有道路"}

	var pid: int = GameManager.get_human_player_id()
	var player: Dictionary = GameManager.get_player_by_id(pid)

	if player.get("ap", 0) < ROAD_BUILD_COST["ap"]:
		return {"success": false, "reason": "行动点不足"}
	if ResourceManager.get_resource(pid, "gold") < ROAD_BUILD_COST["gold"]:
		return {"success": false, "reason": "金币不足"}
	if ResourceManager.get_resource(pid, "iron") < ROAD_BUILD_COST["iron"]:
		return {"success": false, "reason": "铁矿不足"}

	player["ap"] -= ROAD_BUILD_COST["ap"]
	ResourceManager.apply_delta(pid, {"gold": -ROAD_BUILD_COST["gold"], "iron": -ROAD_BUILD_COST["iron"]})

	# 记录筑路任务（复用 _transform_tasks，特殊标记）
	_transform_tasks[tile_idx] = {
		"target_terrain": -1,  # -1 表示筑路
		"turns_remaining": ROAD_BUILD_COST["turns"],
		"recipe": {"name": "筑路"},
		"pid": pid,
		"is_road": true,
	}

	EventBus.message_log.emit("[color=yellow]【筑路】开始在地块 #%d 修建道路，需要 %d 回合[/color]" % [tile_idx, ROAD_BUILD_COST["turns"]])
	if EventBus.has_signal("road_construction_started"):
		EventBus.road_construction_started.emit(tile_idx)

	return {"success": true}


## 每回合处理：推进改造进度
func process_turn() -> void:
	var completed: Array = []

	for tile_idx in _transform_tasks:
		var task: Dictionary = _transform_tasks[tile_idx]
		task["turns_remaining"] -= 1

		if task["turns_remaining"] <= 0:
			completed.append(tile_idx)
			_complete_transform(tile_idx, task)

	for tile_idx in completed:
		_transform_tasks.erase(tile_idx)

	# 处理地形减员
	_process_terrain_attrition()


## 完成地形改造
func _complete_transform(tile_idx: int, task: Dictionary) -> void:
	var tile: Dictionary = GameManager.tiles[tile_idx]

	if task.get("is_road", false):
		# 完成筑路
		tile["has_road"] = true
		EventBus.message_log.emit("[color=lime]【筑路完成】地块 #%d 的道路建设完成！移动消耗降低[/color]" % tile_idx)
		if EventBus.has_signal("road_construction_completed"):
			EventBus.road_construction_completed.emit(tile_idx)
		# 更新 terrain_move_cost
		tile["terrain_move_cost"] = get_tile_move_cost(tile)
		return

	# 完成地形改造
	var old_terrain: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var new_terrain: int = task["target_terrain"]
	tile["terrain"] = new_terrain

	# 应用改造完成奖励
	var recipe: Dictionary = task.get("recipe", {})
	var bonus: Dictionary = recipe.get("production_bonus_on_complete", {})
	if not bonus.is_empty():
		if not tile.has("terrain_transform_bonus"):
			tile["terrain_transform_bonus"] = {}
		for key in bonus:
			tile["terrain_transform_bonus"][key] = tile["terrain_transform_bonus"].get(key, 0) + bonus[key]

	# 更新 terrain_move_cost
	tile["terrain_move_cost"] = get_tile_move_cost(tile)

	var old_name: String = FactionData.TERRAIN_DATA.get(old_terrain, {}).get("name", "旧地形")
	var new_name: String = FactionData.TERRAIN_DATA.get(new_terrain, {}).get("name", "新地形")
	EventBus.message_log.emit("[color=gold]【地形改造完成】地块 #%d：%s → %s！[/color]" % [tile_idx, old_name, new_name])

	if EventBus.has_signal("terrain_transform_completed"):
		EventBus.terrain_transform_completed.emit(tile_idx, old_terrain, new_terrain)

	# 刷新地块显示
	if EventBus.has_signal("tile_data_changed"):
		EventBus.tile_data_changed.emit(tile_idx)


## 每回合处理地形减员
func _process_terrain_attrition() -> void:
	var pid: int = GameManager.get_human_player_id()
	for i in range(GameManager.tiles.size()):
		var tile: Dictionary = GameManager.tiles[i]
		if tile.get("owner_id", -1) != pid:
			continue
		var garrison: int = tile.get("garrison", 0)
		if garrison <= 0:
			continue
		var attrition: int = calculate_terrain_attrition(tile, garrison)
		if attrition > 0:
			tile["garrison"] = max(0, garrison - attrition)
			var terrain_name: String = FactionData.TERRAIN_DATA.get(tile.get("terrain", 0), {}).get("name", "")
			EventBus.message_log.emit("[color=orange]【地形减员】据点 #%d（%s）：驻军减少 %d 人[/color]" % [i, terrain_name, attrition])
			if EventBus.has_signal("terrain_attrition_applied"):
				EventBus.terrain_attrition_applied.emit(i, terrain_name, attrition)

# ══════════════════════════════════════════════════════════════════════════════
# 10. 地形+天气交叉修正查询
# ══════════════════════════════════════════════════════════════════════════════

## 获取当前地形+天气的交叉修正
static func get_terrain_weather_cross_mod(tile: Dictionary) -> Dictionary:
	if WeatherSystem == null:
		return {}
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var current_weather: int = WeatherSystem.current_weather

	# 构建查询键
	var terrain_names: Dictionary = {
		FactionData.TerrainType.FOREST: "FOREST",
		FactionData.TerrainType.SWAMP: "SWAMP",
		FactionData.TerrainType.MOUNTAIN: "MOUNTAIN",
		FactionData.TerrainType.RIVER: "RIVER",
		FactionData.TerrainType.COASTAL: "COASTAL",
		FactionData.TerrainType.VOLCANIC: "VOLCANIC",
		FactionData.TerrainType.PLAINS: "PLAINS",
		FactionData.TerrainType.WASTELAND: "WASTELAND",
	}
	var weather_names: Dictionary = {0: "CLEAR", 1: "RAIN", 2: "FOG", 3: "STORM", 4: "SNOW", 5: "DROUGHT", 6: "MONSOON"}
	var terrain_key: String = terrain_names.get(terrain_type, "")
	var weather_key: String = weather_names.get(current_weather, "")
	if terrain_key.is_empty() or weather_key.is_empty():
		return {}

	var cross_key: String = terrain_key + "_" + weather_key
	return TERRAIN_WEATHER_CROSS_MODS.get(cross_key, {})

# ══════════════════════════════════════════════════════════════════════════════
# 11. 存档支持
# ══════════════════════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	return {
		"transform_tasks": _transform_tasks.duplicate(true),
	}

func from_save_data(data: Dictionary) -> void:
	_transform_tasks = data.get("transform_tasks", {})
	# 恢复整数键（JSON 序列化后键变为字符串）
	var fixed: Dictionary = {}
	for k in _transform_tasks:
		fixed[int(k)] = _transform_tasks[k]
	_transform_tasks = fixed
