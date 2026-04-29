extends RefCounted
class_name TacticalThreatMap

## TacticalThreatMap
## 计算敌方威胁格，用于避免 AI 站进危险区。
## 第一版用曼哈顿距离 + 技能射程估算，不做寻路。

static func build_threat_map(ctx: TacticalAIContext, for_team: String) -> Dictionary:
	var map: Dictionary = {}
	for u in ctx.units:
		if bool(u.get("is_dead", false)):
			continue
		if str(u.get("team", "")) == for_team:
			continue
		var skills: Array = u.get("skills", ["basic_attack"])
		for skill_id in skills:
			var r: Vector2i = ctx.get_skill_range(u, str(skill_id))
			var origin: Vector2i = u.get("tile", Vector2i.ZERO)
			var threat: float = _estimate_unit_threat(u, ctx, str(skill_id))
			for y in range(ctx.board_size.y):
				for x in range(ctx.board_size.x):
					var t := Vector2i(x, y)
					var d: int = ctx.distance(origin, t)
					if d >= r.x and d <= r.y:
						map[t] = float(map.get(t, 0.0)) + threat
	return map

static func get_threat_at(map: Dictionary, tile: Vector2i) -> float:
	return float(map.get(tile, 0.0))

static func _estimate_unit_threat(unit: Dictionary, ctx: TacticalAIContext, skill_id: String) -> float:
	var st: Dictionary = unit.get("stats", {})
	var atk: float = float(st.get("atk", unit.get("atk", 1)))
	var spd: float = float(st.get("spd", unit.get("spd", 5)))
	var skill: Dictionary = ctx.get_skill(skill_id)
	var power: float = float(skill.get("base_power", 1.0))
	return atk * power * 2.0 + spd
