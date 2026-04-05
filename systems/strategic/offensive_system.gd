## offensive_system.gd — 据点进攻系统
## 处理据点主动发起的特殊进攻行动：突袭、渗透、掠夺等。
extends Node

# ── 进攻行动定义 ──
const OFFENSIVE_ACTIONS: Dictionary = {
	"raid": {
		"name": "突袭",
		"desc": "快速突袭相邻据点，掠夺资源。成功率70%，获得金币+铁矿，但可能触发反击",
		"cost": {"ap": 1},
		"range": 1,
		"success_rate": 0.70,
		"effects": {
			"gold_steal": 30,
			"iron_steal": 15,
			"counterattack_chance": 0.40,
		},
		"cooldown": 3,
	},
	"infiltrate": {
		"name": "渗透",
		"desc": "派遣特务渗透敌方据点，破坏建筑或窃取情报。成功率60%，降低目标产出3回合",
		"cost": {"ap": 2},
		"range": 2,
		"success_rate": 0.60,
		"effects": {
			"target_production_mult": 0.5,
			"target_production_turns": 3,
			"detection_chance": 0.50,
		},
		"cooldown": 5,
	},
	"plunder": {
		"name": "掠夺",
		"desc": "大规模掠夺行动，获得大量资源但有高风险被拦截。成功率50%，获得金币+粮食+奴隶",
		"cost": {"ap": 2, "garrison": 5},
		"range": 3,
		"success_rate": 0.50,
		"effects": {
			"gold_steal": 80,
			"food_steal": 40,
			"slave_steal": 10,
			"interception_chance": 0.60,
		},
		"cooldown": 7,
	},
	"sabotage": {
		"name": "破坏",
		"desc": "破坏目标据点的建筑或城防。成功率65%，降低目标城防值或摧毁一座建筑",
		"cost": {"ap": 1, "iron": 20},
		"range": 2,
		"success_rate": 0.65,
		"effects": {
			"wall_damage": 20,
			"building_destroy_chance": 0.30,
		},
		"cooldown": 4,
	},
	"propaganda": {
		"name": "宣传",
		"desc": "在目标据点进行宣传活动，降低敌方秩序。成功率80%，目标秩序-15，持续2回合",
		"cost": {"ap": 1, "gold": 20},
		"range": 4,
		"success_rate": 0.80,
		"effects": {
			"target_order_change": -15,
			"target_order_turns": 2,
		},
		"cooldown": 3,
	}
}

# ── 状态存储 ──
# { tile_index: { "action_id": { "last_used_turn": int, "cooldown_remaining": int } } }
var _action_cooldowns: Dictionary = {}

# ── 进攻历史记录 ──
# { attacker_tile: { defender_tile: { "last_action": str, "success": bool, "timestamp": int } } }
var _attack_history: Dictionary = {}

func get_action_cooldown(tile_idx: int, action_id: String) -> int:
	if not _action_cooldowns.has(tile_idx):
		_action_cooldowns[tile_idx] = {}
	return _action_cooldowns[tile_idx].get(action_id, 0)

func can_perform_action(tile_idx: int, action_id: String, target_tile_idx: int) -> Dictionary:
	if not OFFENSIVE_ACTIONS.has(action_id):
		return {"can": false, "reason": "未知行动"}
	
	var action = OFFENSIVE_ACTIONS[action_id]
	var tile = GameManager.tiles[tile_idx]
	var target_tile = GameManager.tiles[target_tile_idx]
	
	# 检查距离
	var distance = _calculate_distance(tile_idx, target_tile_idx)
	if distance > action["range"]:
		return {"can": false, "reason": "目标距离过远"}
	
	# 检查冷却
	var cooldown = get_action_cooldown(tile_idx, action_id)
	if cooldown > 0:
		return {"can": false, "reason": "行动冷却中 (%d回合)" % cooldown}
	
	# 检查费用
	var cost = action.get("cost", {})
	var pid = tile.get("owner_id", -1)
	if pid < 0:
		return {"can": false, "reason": "据点无主"}
	
	var res_cost = {}
	if cost.has("gold"): res_cost["gold"] = cost["gold"]
	if cost.has("iron"): res_cost["iron"] = cost["iron"]
	if cost.has("food"): res_cost["food"] = cost["food"]
	
	if not res_cost.is_empty():
		if not ResourceManager.can_afford(pid, res_cost):
			return {"can": false, "reason": "资源不足"}
	
	# 检查驻军费用
	if cost.has("garrison"):
		var garrison = tile.get("garrison", 0)
		if garrison < cost["garrison"]:
			return {"can": false, "reason": "驻军不足"}
	
	# 检查 AP 费用
	if cost.has("ap"):
		if GameManager.current_ap < cost["ap"]:
			return {"can": false, "reason": "行动力不足"}
	
	return {"can": true}

func perform_action(tile_idx: int, action_id: String, target_tile_idx: int) -> Dictionary:
	var check = can_perform_action(tile_idx, action_id, target_tile_idx)
	if not check["can"]:
		return {"success": false, "reason": check["reason"]}
	
	var action = OFFENSIVE_ACTIONS[action_id]
	var tile = GameManager.tiles[tile_idx]
	var target_tile = GameManager.tiles[target_tile_idx]
	var pid = tile.get("owner_id", -1)
	
	# 扣除费用
	var cost = action.get("cost", {})
	var res_cost = {}
	if cost.has("gold"): res_cost["gold"] = cost["gold"]
	if cost.has("iron"): res_cost["iron"] = cost["iron"]
	if cost.has("food"): res_cost["food"] = cost["food"]
	
	if not res_cost.is_empty():
		ResourceManager.spend(pid, res_cost)
	
	if cost.has("garrison"):
		tile["garrison"] = tile.get("garrison", 0) - cost["garrison"]
	
	if cost.has("ap"):
		GameManager.current_ap -= cost["ap"]
		EventBus.ap_changed.emit(pid, GameManager.current_ap)
	
	# 执行行动
	var result = _execute_action(tile_idx, action_id, target_tile_idx)
	
	# 设置冷却
	if not _action_cooldowns.has(tile_idx):
		_action_cooldowns[tile_idx] = {}
	_action_cooldowns[tile_idx][action_id] = action.get("cooldown", 3)
	
	# 记录历史
	_record_attack(tile_idx, target_tile_idx, action_id, result["success"])
	
	# 发射 EventBus 信号
	if EventBus.has_signal("offensive_action_performed"):
		EventBus.offensive_action_performed.emit(tile_idx, action_id, target_tile_idx, result)
	
	return result

func _execute_action(tile_idx: int, action_id: String, target_tile_idx: int) -> Dictionary:
	var action = OFFENSIVE_ACTIONS[action_id]
	var success = randf() < action["success_rate"]
	var tile = GameManager.tiles[tile_idx]
	var target_tile = GameManager.tiles[target_tile_idx]
	var pid = tile.get("owner_id", -1)
	var target_pid = target_tile.get("owner_id", -1)
	
	var result = {"success": success, "action": action_id, "log": ""}
	
	if not success:
		result["log"] = "[color=red]%s 失败![/color]" % action["name"]
		EventBus.message_log.emit(result["log"])
		return result
	
	match action_id:
		"raid":
			var gold = action["effects"]["gold_steal"]
			var iron = action["effects"]["iron_steal"]
			ResourceManager.gain(pid, {"gold": gold, "iron": iron})
			result["log"] = "[color=yellow]突袭成功! 获得 %d 金币, %d 铁矿[/color]" % [gold, iron]
			
			# 检查反击
			if randf() < action["effects"]["counterattack_chance"]:
				result["log"] += "\n[color=orange]敌方进行了反击![/color]"
				# 触发反击事件
				EventBus.message_log.emit("[color=orange]据点 #%d 遭到反击![/color]" % tile_idx)
		
		"infiltrate":
			var target_mult = action["effects"]["target_production_mult"]
			var turns = action["effects"]["target_production_turns"]
			_apply_target_debuff(target_tile_idx, target_mult, turns)
			result["log"] = "[color=cyan]渗透成功! 目标产出降低 3 回合[/color]"
			
			if randf() < action["effects"]["detection_chance"]:
				result["log"] += "\n[color=orange]特务被发现了![/color]"
				# 触发外交事件
				EventBus.message_log.emit("[color=red]据点 #%d 的渗透被发现![/color]" % target_tile_idx)
		
		"plunder":
			var gold = action["effects"]["gold_steal"]
			var food = action["effects"]["food_steal"]
			var slaves = action["effects"]["slave_steal"]
			ResourceManager.gain(pid, {"gold": gold, "food": food, "slaves": slaves})
			result["log"] = "[color=yellow]掠夺成功! 获得 %d 金币, %d 粮食, %d 奴隶[/color]" % [gold, food, slaves]
			
			if randf() < action["effects"]["interception_chance"]:
				result["log"] += "\n[color=red]掠夺队伍被拦截, 损失 50%% 收获![/color]"
				ResourceManager.spend(pid, {"gold": gold/2, "food": food/2})
		
		"sabotage":
			var wall_dmg = action["effects"]["wall_damage"]
			target_tile["wall_hp"] = max(target_tile.get("wall_hp", 0) - wall_dmg, 0)
			result["log"] = "[color=orange]破坏成功! 目标城防降低 %d[/color]" % wall_dmg
			
			if randf() < action["effects"]["building_destroy_chance"]:
				if target_tile.get("building_id", "") != "":
					target_tile["building_id"] = ""
					target_tile["building_level"] = 0
					result["log"] += "\n[color=red]建筑被摧毁![/color]"
		
		"propaganda":
			var order_change = action["effects"]["target_order_change"]
			var turns = action["effects"]["target_order_turns"]
			if GameManager.governance_system:
				for i in range(turns):
					GameManager.governance_system.change_order(target_tile_idx, order_change)
			result["log"] = "[color=cyan]宣传成功! 目标秩序下降[/color]"
	
	EventBus.message_log.emit(result["log"])
	return result

func _calculate_distance(from_idx: int, to_idx: int) -> int:
	# 使用曼哈顿距离或邻接关系计算
	if from_idx == to_idx:
		return 0
	
	# 简单 BFS 距离计算
	var visited = {from_idx: 0}
	var queue = [from_idx]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		if current == to_idx:
			return visited[current]
		
		if GameManager.adjacency.has(current):
			for neighbor in GameManager.adjacency[current]:
				if not visited.has(neighbor):
					visited[neighbor] = visited[current] + 1
					queue.append(neighbor)
	
	return 999  # 无法到达

func _apply_target_debuff(tile_idx: int, mult: float, turns: int) -> void:
	# 标记目标地块在指定回合内产出降低
	var tile = GameManager.tiles[tile_idx]
	if not tile.has("debuffs"):
		tile["debuffs"] = {}
	tile["debuffs"]["production_mult"] = {"mult": mult, "turns_remaining": turns}

func _record_attack(attacker_idx: int, defender_idx: int, action_id: String, success: bool) -> void:
	if not _attack_history.has(attacker_idx):
		_attack_history[attacker_idx] = {}
	_attack_history[attacker_idx][defender_idx] = {
		"last_action": action_id,
		"success": success,
		"timestamp": GameManager.turn_number,
	}

func process_turn() -> void:
	# 每回合递减冷却
	for tile_idx in _action_cooldowns:
		for action_id in _action_cooldowns[tile_idx]:
			if _action_cooldowns[tile_idx][action_id] > 0:
				_action_cooldowns[tile_idx][action_id] -= 1
	
	# 处理目标地块的 debuff
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.has("debuffs") and tile["debuffs"].has("production_mult"):
			var debuff = tile["debuffs"]["production_mult"]
			if debuff["turns_remaining"] > 0:
				debuff["turns_remaining"] -= 1
			else:
				tile["debuffs"].erase("production_mult")

func get_available_actions(tile_idx: int) -> Array:
	var result = []
	for action_id in OFFENSIVE_ACTIONS:
		var action = OFFENSIVE_ACTIONS[action_id]
		var cooldown = get_action_cooldown(tile_idx, action_id)
		result.append({
			"id": action_id,
			"name": action["name"],
			"desc": action["desc"],
			"cooldown": cooldown,
			"range": action["range"],
		})
	return result
