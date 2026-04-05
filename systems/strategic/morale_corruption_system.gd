## morale_corruption_system.gd — 民心与腐败系统
## 追踪据点的民心值（0-100）和腐败值（0-100），影响产出、秩序和叛乱概率。
extends Node

# ── 民心与腐败数据 ──
# { tile_idx: { "morale": float, "corruption": float } }
var _morale_data: Dictionary = {}

const MORALE_DEFAULT: float = 50.0
const CORRUPTION_DEFAULT: float = 20.0

# ── 民心影响系数 ──
const MORALE_PRODUCTION_MULT: Dictionary = {
	0: 0.5,    # 民心 0-20: 产出 -50%
	20: 0.75,  # 民心 20-40: 产出 -25%
	40: 1.0,   # 民心 40-60: 产出 正常
	60: 1.15,  # 民心 60-80: 产出 +15%
	80: 1.3,   # 民心 80-100: 产出 +30%
}

# ── 腐败影响系数 ──
const CORRUPTION_PRODUCTION_MULT: Dictionary = {
	0: 1.0,    # 腐败 0-20: 产出 正常
	20: 0.9,   # 腐败 20-40: 产出 -10%
	40: 0.75,  # 腐败 40-60: 产出 -25%
	60: 0.5,   # 腐败 60-80: 产出 -50%
	80: 0.25,  # 腐败 80-100: 产出 -75%
}

# ── 民心与秩序关系 ──
const MORALE_ORDER_BONUS: Dictionary = {
	0: -20,    # 民心 0-20: 秩序 -20
	20: -10,   # 民心 20-40: 秩序 -10
	40: 0,     # 民心 40-60: 秩序 0
	60: 10,    # 民心 60-80: 秩序 +10
	80: 20,    # 民心 80-100: 秩序 +20
}

# ── 腐败与秩序关系 ──
const CORRUPTION_ORDER_PENALTY: Dictionary = {
	0: 0,      # 腐败 0-20: 秩序 0
	20: -5,    # 腐败 20-40: 秩序 -5
	40: -10,   # 腐败 40-60: 秩序 -10
	60: -15,   # 腐败 60-80: 秩序 -15
	80: -25,   # 腐败 80-100: 秩序 -25
}

func _ready() -> void:
	pass

func reset() -> void:
	_morale_data.clear()

func get_morale_data(tile_idx: int) -> Dictionary:
	if not _morale_data.has(tile_idx):
		_morale_data[tile_idx] = {
			"morale": MORALE_DEFAULT,
			"corruption": CORRUPTION_DEFAULT,
		}
	return _morale_data[tile_idx]

func get_morale(tile_idx: int) -> float:
	return get_morale_data(tile_idx)["morale"]

func get_corruption(tile_idx: int) -> float:
	return get_morale_data(tile_idx)["corruption"]

func change_morale(tile_idx: int, delta: float) -> void:
	var data = get_morale_data(tile_idx)
	data["morale"] = clampf(data["morale"] + delta, 0.0, 100.0)
	EventBus.message_log.emit("[color=cyan]据点 #%d 民心变化: %.0f[/color]" % [tile_idx, data["morale"]])

func change_corruption(tile_idx: int, delta: float) -> void:
	var data = get_morale_data(tile_idx)
	data["corruption"] = clampf(data["corruption"] + delta, 0.0, 100.0)
	EventBus.message_log.emit("[color=orange]据点 #%d 腐败变化: %.0f[/color]" % [tile_idx, data["corruption"]])

func get_production_multiplier(tile_idx: int) -> float:
	var morale = get_morale(tile_idx)
	var corruption = get_corruption(tile_idx)
	
	var morale_mult = _get_bracket_value(morale, MORALE_PRODUCTION_MULT)
	var corruption_mult = _get_bracket_value(corruption, CORRUPTION_PRODUCTION_MULT)
	
	return morale_mult * corruption_mult

func get_order_modifier(tile_idx: int) -> int:
	var morale = get_morale(tile_idx)
	var corruption = get_corruption(tile_idx)
	
	var morale_bonus = _get_bracket_value(morale, MORALE_ORDER_BONUS)
	var corruption_penalty = _get_bracket_value(corruption, CORRUPTION_ORDER_PENALTY)
	
	return int(morale_bonus + corruption_penalty)

func _get_bracket_value(value: float, bracket_dict: Dictionary) -> float:
	# 根据值所在的区间，返回对应的系数
	var keys = bracket_dict.keys()
	keys.sort()
	
	for i in range(keys.size() - 1):
		if value >= keys[i] and value < keys[i + 1]:
			# 线性插值
			var k1 = keys[i]
			var k2 = keys[i + 1]
			var v1 = bracket_dict[k1]
			var v2 = bracket_dict[k2]
			var t = (value - k1) / (k2 - k1)
			return lerp(v1, v2, t)
	
	# 超过最大值
	return bracket_dict[keys[-1]]

func process_turn() -> void:
	# 每回合自然变化
	for tile_idx in _morale_data:
		var data = _morale_data[tile_idx]
		
		# 民心自然恢复（向50靠拢）
		if data["morale"] < 50:
			data["morale"] = minf(data["morale"] + 1.0, 50.0)
		elif data["morale"] > 50:
			data["morale"] = maxf(data["morale"] - 1.0, 50.0)
		
		# 腐败自然增加（除非有反腐措施）
		data["corruption"] = minf(data["corruption"] + 0.5, 100.0)

func apply_morale_event(tile_idx: int, event_type: String) -> void:
	# 根据事件类型改变民心
	match event_type:
		"building_constructed":
			change_morale(tile_idx, 5.0)
		"garrison_increased":
			change_morale(tile_idx, 3.0)
		"tax_increase":
			change_morale(tile_idx, -10.0)
		"celebration":
			change_morale(tile_idx, 15.0)
		"plague":
			change_morale(tile_idx, -20.0)
		"enemy_raid":
			change_morale(tile_idx, -15.0)
		"victory":
			change_morale(tile_idx, 10.0)

func apply_corruption_event(tile_idx: int, event_type: String) -> void:
	# 根据事件类型改变腐败
	match event_type:
		"high_tax":
			change_corruption(tile_idx, 10.0)
		"noble_appointed":
			change_corruption(tile_idx, 15.0)
		"anti_corruption_campaign":
			change_corruption(tile_idx, -20.0)
		"investigation":
			change_corruption(tile_idx, -10.0)

func to_save_data() -> Dictionary:
	return {
		"morale_data": _morale_data.duplicate(true),
	}

func from_save_data(data: Dictionary) -> void:
	_morale_data = data.get("morale_data", {}).duplicate(true)
