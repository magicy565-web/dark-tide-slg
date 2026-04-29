extends RefCounted
class_name TacticalAOESimulator

## TacticalAOESimulator
## 预估 AOE 技能命中收益。

static func get_aoe_tiles(center: Vector2i, skill: Dictionary, ctx: TacticalAIContext) -> Array:
	var shape: String = str(skill.get("aoe_shape", "none"))
	var radius: int = int(skill.get("aoe_radius", 0))
	var result: Array = []
	if shape == "none" or radius <= 0:
		result.append(center)
		return result
	for y in range(ctx.board_size.y):
		for x in range(ctx.board_size.x):
			var t := Vector2i(x, y)
			var dist: int = ctx.distance(center, t)
			if shape == "diamond" and dist <= radius:
				result.append(t)
			elif shape == "square" and abs(center.x - t.x) <= radius and abs(center.y - t.y) <= radius:
				result.append(t)
	return result

static func score_aoe_center(actor: Dictionary, center: Vector2i, skill_id: String, ctx: TacticalAIContext) -> Dictionary:
	var skill: Dictionary = ctx.get_skill(skill_id)
	var tiles: Array = get_aoe_tiles(center, skill, ctx)
	var enemies_hit: int = 0
	var allies_hit: int = 0
	var estimated_damage: int = 0
	for u in ctx.units:
		if bool(u.get("is_dead", false)):
			continue
		if not tiles.has(u.get("tile", Vector2i.ZERO)):
			continue
		if str(u.get("team", "")) == str(actor.get("team", "")):
			allies_hit += 1
		else:
			enemies_hit += 1
			estimated_damage += ctx.estimate_damage(actor, u, skill_id)
	var score: float = float(estimated_damage) + float(enemies_hit) * 12.0 - float(allies_hit) * 20.0
	return {"score": score, "enemies_hit": enemies_hit, "allies_hit": allies_hit, "estimated_damage": estimated_damage, "tiles": tiles}
