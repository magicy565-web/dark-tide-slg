## governance_system.gd — 据点治理与政策系统
## 处理据点的公共秩序、政策激活、治理行动等逻辑。
extends Node

# ── 政策定义 ──
const POLICIES: Dictionary = {
	"tax_hike": {
		"name": "增缴税收",
		"desc": "本回合产出+50%, 但公共秩序-15",
		"cost": {"ap": 0},
		"effects": {"gold_mult": 1.5, "order_change": -15},
		"duration": 1,
	},
	"festival": {
		"name": "举办庆典",
		"desc": "公共秩序+20, 吸引流民(+5兵), 消耗50金",
		"cost": {"gold": 50, "ap": 1},
		"effects": {"order_change": 20, "garrison_bonus": 5},
		"duration": 0,
	},
	"martial_law": {
		"name": "军事管制",
		"desc": "公共秩序不再下降, 驻军防御+5, 但金币产出-30%",
		"cost": {"ap": 1},
		"effects": {"order_freeze": true, "def_bonus": 5, "gold_mult": 0.7},
		"duration": 3,
	},
	"forced_labor": {
		"name": "强制劳役",
		"desc": "建筑建造/升级费用-30%, 但公共秩序-10",
		"cost": {"ap": 1},
		"effects": {"build_discount": 0.3, "order_change": -10},
		"duration": 5,
	}
}

# ── 治理行动 ──
const GOVERNANCE_ACTIONS: Dictionary = {
	"suppress": {
		"name": "镇压动荡",
		"desc": "消耗10兵力, 立即恢复25点公共秩序",
		"cost": {"garrison": 10, "ap": 1},
		"effects": {"order_change": 25},
	},
	"relief": {
		"name": "赈灾救济",
		"desc": "消耗30粮食, 恢复15点公共秩序, 提升民心",
		"cost": {"food": 30, "ap": 1},
		"effects": {"order_change": 15, "popularity_bonus": 5},
	}
}

# ── 防御策略 ──
const DEFENSE_STRATEGIES: Dictionary = {
	"fortify_walls": {
		"name": "加固城防",
		"desc": "消耗20铁, 立即恢复20点城防值",
		"cost": {"iron": 20, "ap": 1},
		"effects": {"wall_repair": 20},
	},
	"scorch_earth": {
		"name": "坚壁清野",
		"desc": "敌军围攻时每回合额外损失5%兵力, 但本据点产出归零",
		"cost": {"ap": 1},
		"effects": {"siege_attrition": 0.05, "production_zero": true},
		"duration": 5,
	},
	"militia_draft": {
		"name": "紧急征召",
		"desc": "消耗10金, 立即获得5点驻军, 但公共秩序-10",
		"cost": {"gold": 10, "ap": 1},
		"effects": {"garrison_bonus": 5, "order_change": -10},
	}
}

# ── 状态存储 ──
# { tile_index: { "active_policies": { policy_id: turns_remaining }, "popularity": float } }
var _tile_governance: Dictionary = {}

func get_governance_data(tile_idx: int) -> Dictionary:
	if not _tile_governance.has(tile_idx):
		_tile_governance[tile_idx] = {
			"active_policies": {},
			"popularity": 50.0, # 0-100
		}
	return _tile_governance[tile_idx]

func activate_policy(tile_idx: int, policy_id: String) -> bool:
	if not POLICIES.has(policy_id): return false
	var policy = POLICIES[policy_id]
	var data = get_governance_data(tile_idx)
	
	# 检查费用
	if not _check_and_spend_cost(policy.get("cost", {})):
		return false
	
	data["active_policies"][policy_id] = policy["duration"]
	
	# 立即生效的效果
	if policy["effects"].has("order_change"):
		change_order(tile_idx, policy["effects"]["order_change"])
	if policy["effects"].has("garrison_bonus"):
		var tile = GameManager.tiles[tile_idx]
		tile["garrison"] = tile.get("garrison", 0) + policy["effects"]["garrison_bonus"]
		
	EventBus.message_log.emit("[color=cyan]据点 #%d 激活政策: %s[/color]" % [tile_idx, policy["name"]])
	return true

func execute_action(tile_idx: int, action_id: String) -> bool:
	if not GOVERNANCE_ACTIONS.has(action_id): return false
	var action = GOVERNANCE_ACTIONS[action_id]
	
	# 检查费用
	if not _check_and_spend_cost(action.get("cost", {})):
		return false
	
	if action["effects"].has("order_change"):
		change_order(tile_idx, action["effects"]["order_change"])
	if action["effects"].has("popularity_bonus"):
		var data = get_governance_data(tile_idx)
		data["popularity"] = clampf(data["popularity"] + action["effects"]["popularity_bonus"], 0, 100)
		
	EventBus.message_log.emit("[color=cyan]据点 #%d 执行治理: %s[/color]" % [tile_idx, action["name"]])
	return true

func activate_strategy(tile_idx: int, strategy_id: String) -> bool:
	if not DEFENSE_STRATEGIES.has(strategy_id): return false
	var strategy = DEFENSE_STRATEGIES[strategy_id]
	var data = get_governance_data(tile_idx)
	
	# 检查费用
	if not _check_and_spend_cost(strategy.get("cost", {})):
		return false
	
	if strategy.has("duration") and strategy["duration"] > 0:
		data["active_policies"][strategy_id] = strategy["duration"]
	
	# 立即生效的效果
	var effects = strategy["effects"]
	if effects.has("wall_repair"):
		var tile = GameManager.tiles[tile_idx]
		tile["wall_hp"] = min(tile.get("wall_hp", 0) + effects["wall_repair"], tile.get("max_wall_hp", 50))
	if effects.has("garrison_bonus"):
		var tile = GameManager.tiles[tile_idx]
		tile["garrison"] = tile.get("garrison", 0) + effects["garrison_bonus"]
	if effects.has("order_change"):
		change_order(tile_idx, effects["order_change"])
		
	EventBus.message_log.emit("[color=cyan]据点 #%d 部署防御策略: %s[/color]" % [tile_idx, strategy["name"]])
	return true

func _check_and_spend_cost(cost: Dictionary) -> bool:
	var pid = GameManager.get_human_player_id()
	# Convert cost to ResourceManager format
	var res_cost = {}
	if cost.has("gold"): res_cost["gold"] = cost["gold"]
	if cost.has("iron"): res_cost["iron"] = cost["iron"]
	if cost.has("food"): res_cost["food"] = cost["food"]
	
	if not res_cost.is_empty():
		if not ResourceManager.can_afford(pid, res_cost):
			EventBus.message_log.emit("[color=red]资源不足![/color]")
			return false
		ResourceManager.spend(pid, res_cost)
	
	# AP cost
	if cost.has("ap") and cost["ap"] > 0:
		if GameManager.current_ap < cost["ap"]:
			EventBus.message_log.emit("[color=red]行动力不足![/color]")
			return false
		GameManager.current_ap -= cost["ap"]
		EventBus.ap_changed.emit(GameManager.current_ap)
		
	return true

func change_order(tile_idx: int, amount: float) -> void:
	var tile = GameManager.tiles[tile_idx]
	var current_order = tile.get("public_order", 0.8)
	var new_order = clampf(current_order + (amount / 100.0), 0.0, 1.0)
	tile["public_order"] = new_order
	
	# v1.2.0: Also affect global order (scaled)
	if OrderManager != null:
		var global_delta: int = int(amount / 5.0) # 5 tile order = 1 global order
		if global_delta != 0:
			OrderManager.change_order(global_delta)
			
	EventBus.order_changed.emit(tile_idx, new_order)

func process_turn() -> void:
	for tile_idx in _tile_governance:
		var data = _tile_governance[tile_idx]
		var policies = data["active_policies"]
		var to_remove = []
		for p_id in policies:
			if policies[p_id] > 0:
				policies[p_id] -= 1
				if policies[p_id] == 0:
					to_remove.append(p_id)
		
		for p_id in to_remove:
			policies.erase(p_id)
			EventBus.message_log.emit("[color=gray]据点 #%d 政策过期: %s[/color]" % [tile_idx, POLICIES[p_id]["name"]])

func get_policy_modifiers(tile_idx: int) -> Dictionary:
	var mods = {"gold_mult": 1.0, "def_bonus": 0, "order_freeze": false, "build_discount": 0.0}
	var data = get_governance_data(tile_idx)
	for p_id in data["active_policies"]:
		var effects = POLICIES[p_id]["effects"]
		if effects.has("gold_mult"): mods["gold_mult"] *= effects["gold_mult"]
		if effects.has("def_bonus"): mods["def_bonus"] += effects["def_bonus"]
		if effects.has("order_freeze"): mods["order_freeze"] = mods["order_freeze"] or effects["order_freeze"]
		if effects.has("build_discount"): mods["build_discount"] = maxf(mods["build_discount"], effects["build_discount"])
	return mods
