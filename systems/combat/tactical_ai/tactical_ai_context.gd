extends RefCounted
class_name TacticalAIContext

## TacticalAIContext
## 实战 AI 的战斗上下文。输入单位使用 Dictionary，方便从 troop/army/Node 适配。

var board_size: Vector2i = Vector2i(8, 8)
var units: Array = []
var skill_db: Dictionary = {}
var terrain: Dictionary = {}      # Vector2i -> {blocked, danger, defense_bonus, tags}
var objectives: Array = []        # Vector2i[]
var threat_map: Dictionary = {}   # Vector2i -> score

func _init(p_units: Array = [], p_skill_db: Dictionary = {}, p_board_size: Vector2i = Vector2i(8, 8)) -> void:
	units = p_units
	skill_db = p_skill_db
	board_size = p_board_size

func get_unit(unit_id: String) -> Dictionary:
	for u in units:
		if str(u.get("id", "")) == unit_id:
			return u
	return {}

func get_allies(actor: Dictionary) -> Array:
	var result: Array = []
	var team: String = str(actor.get("team", ""))
	for u in units:
		if bool(u.get("is_dead", false)):
			continue
		if str(u.get("team", "")) == team and str(u.get("id", "")) != str(actor.get("id", "")):
			result.append(u)
	return result

func get_enemies(actor: Dictionary) -> Array:
	var result: Array = []
	var team: String = str(actor.get("team", ""))
	for u in units:
		if bool(u.get("is_dead", false)):
			continue
		if str(u.get("team", "")) != team:
			result.append(u)
	return result

func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < board_size.x and tile.y >= 0 and tile.y < board_size.y

func distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)

func get_occupied_tiles(ignore_unit_id: String = "") -> Array:
	var result: Array = []
	for u in units:
		if bool(u.get("is_dead", false)):
			continue
		if str(u.get("id", "")) == ignore_unit_id:
			continue
		result.append(u.get("tile", Vector2i.ZERO))
	return result

func is_tile_blocked(tile: Vector2i, ignore_unit_id: String = "") -> bool:
	if not in_bounds(tile):
		return true
	for t in get_occupied_tiles(ignore_unit_id):
		if t == tile:
			return true
	var terr: Dictionary = terrain.get(tile, {})
	return bool(terr.get("blocked", false))

func get_reachable_tiles(actor: Dictionary) -> Array:
	var start: Vector2i = actor.get("tile", Vector2i.ZERO)
	var move_range: int = int(actor.get("stats", {}).get("move", actor.get("move", 3)))
	var result: Array = []
	for y in range(board_size.y):
		for x in range(board_size.x):
			var t := Vector2i(x, y)
			if distance(start, t) <= move_range and not is_tile_blocked(t, str(actor.get("id", ""))):
				result.append(t)
	if not result.has(start):
		result.append(start)
	return result

func get_skill(skill_id: String) -> Dictionary:
	return skill_db.get(skill_id, {})

func get_skill_range(actor: Dictionary, skill_id: String) -> Vector2i:
	var skill: Dictionary = get_skill(skill_id)
	var min_r: int = int(skill.get("range_min", actor.get("stats", {}).get("range_min", 1)))
	var max_r: int = int(skill.get("range_max", actor.get("stats", {}).get("range_max", 1)))
	return Vector2i(min_r, max_r)

func can_skill_reach(actor: Dictionary, target: Dictionary, skill_id: String, from_tile: Variant = null) -> bool:
	var source_tile: Vector2i = actor.get("tile", Vector2i.ZERO) if from_tile == null else from_tile
	var target_tile: Vector2i = target.get("tile", Vector2i.ZERO)
	var r: Vector2i = get_skill_range(actor, skill_id)
	var d: int = distance(source_tile, target_tile)
	return d >= r.x and d <= r.y

func get_castable_skills(actor: Dictionary) -> Array:
	var result: Array = []
	var skills: Array = actor.get("skills", [])
	for skill_id in skills:
		if is_skill_available(actor, str(skill_id)):
			result.append(str(skill_id))
	if result.is_empty():
		result.append("basic_attack")
	return result

func is_skill_available(actor: Dictionary, skill_id: String) -> bool:
	var skill: Dictionary = get_skill(skill_id)
	if skill.is_empty() and skill_id != "basic_attack":
		return false
	var cooldowns: Dictionary = actor.get("cooldowns", {})
	if int(cooldowns.get(skill_id, 0)) > 0:
		return false
	var resources: Dictionary = actor.get("resources", {})
	var cost: Dictionary = skill.get("cost", {})
	for k in cost.keys():
		if int(resources.get(k, 0)) < int(cost[k]):
			return false
	return true

func estimate_damage(actor: Dictionary, target: Dictionary, skill_id: String = "") -> int:
	var atk: float = float(actor.get("stats", {}).get("atk", actor.get("atk", 1)))
	var df: float = float(target.get("stats", {}).get("def", target.get("def", 0)))
	var power: float = 1.0
	var atk_scale: float = 1.0
	var def_scale: float = 1.0
	if skill_id != "":
		var skill: Dictionary = get_skill(skill_id)
		power = float(skill.get("base_power", 1.0))
		atk_scale = float(skill.get("atk_scale", 1.0))
		def_scale = float(skill.get("def_scale", 1.0))
	return maxi(1, int(round(atk * atk_scale * power - df * def_scale)))

func hp_percent(unit: Dictionary) -> float:
	var max_hp: float = float(unit.get("max_hp", unit.get("stats", {}).get("max_hp", 1)))
	var hp: float = float(unit.get("hp", max_hp))
	if max_hp <= 0.0:
		return 0.0
	return hp / max_hp * 100.0
