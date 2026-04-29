extends RefCounted
class_name TacticalAIAction

## TacticalAIAction
## AI 决策结果对象。
## 只描述“要做什么”，不直接执行移动/扣血/动画。

var kind: String = "wait"          # wait / move / retreat / skill / move_skill / heal / buff
var actor_id: String = ""
var target_id: String = ""
var skill_id: String = ""
var from_tile: Vector2i = Vector2i.ZERO
var to_tile: Vector2i = Vector2i.ZERO
var score: float = 0.0
var reason: String = ""
var debug: Dictionary = {}

func _init(
	p_kind: String = "wait",
	p_actor_id: String = "",
	p_target_id: String = "",
	p_skill_id: String = "",
	p_from_tile: Vector2i = Vector2i.ZERO,
	p_to_tile: Vector2i = Vector2i.ZERO,
	p_score: float = 0.0,
	p_reason: String = ""
) -> void:
	kind = p_kind
	actor_id = p_actor_id
	target_id = p_target_id
	skill_id = p_skill_id
	from_tile = p_from_tile
	to_tile = p_to_tile
	score = p_score
	reason = p_reason

func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"actor_id": actor_id,
		"target_id": target_id,
		"skill_id": skill_id,
		"from_tile": from_tile,
		"to_tile": to_tile,
		"score": score,
		"reason": reason,
		"debug": debug
	}
