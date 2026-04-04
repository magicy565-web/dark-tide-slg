## ai_faction_orc.gd - 兽人部落AI (战国兰斯风格)
## 特性：WAAAGH!战争狂热、近战爆发、数量优势、低外交
extends "res://systems/faction/ai_factions/ai_faction_base.gd"

func _init() -> void:
	super._init(0, "orc") # FactionConfig.FactionType.ORC = 0

# ═══════════════════════════════════════════════════════════
# 覆盖：策略决定 (兽人倾向进攻)
# ═══════════════════════════════════════════════════════════
func _decide_strategy(player_id: int) -> void:
	# 兽人只有两种策略：进攻或WAAAGH!狂暴进攻
	var orc_node: Node = _get_orc_mechanic()
	var waaagh: int = orc_node.get_waaagh(player_id) if orc_node != null else 0
	
	if _retreat_mode and _military_score < 0.2:
		_current_strategy = "defensive"
	elif waaagh >= 50:
		_current_strategy = "aggressive" # WAAAGH!触发，全力进攻
	else:
		_current_strategy = "balanced"

# ═══════════════════════════════════════════════════════════
# 覆盖：内政 (兽人优先军事)
# ═══════════════════════════════════════════════════════════
func _execute_domestic(player_id: int) -> void:
	if GameManager == null:
		return
	
	var owned_tiles: Array = GameManager.get_domestic_tiles(player_id)
	if owned_tiles.is_empty():
		return
	
	# 兽人优先：竞技场 > 训练场 > 苦役营 > 奴隶市场
	var orc_priority: Array = ["arena", "training_ground", "labor_camp", "slave_market", "fortification"]
	
	# 如果WAAAGH!值高，优先招募
	var orc_node: Node = _get_orc_mechanic()
	var waaagh: int = orc_node.get_waaagh(player_id) if orc_node != null else 0
	if waaagh >= 30:
		_try_recruit(player_id, owned_tiles)
	
	_try_build_priority(player_id, owned_tiles, orc_priority)
	
	# 确保始终有足够兵力
	_try_recruit(player_id, owned_tiles)

# ═══════════════════════════════════════════════════════════
# 覆盖：军事 (兽人激进进攻)
# ═══════════════════════════════════════════════════════════
func _execute_military(player_id: int) -> void:
	if GameManager == null:
		return
	
	var armies: Array = GameManager.get_player_armies(player_id)
	if armies.is_empty():
		_create_initial_army(player_id)
		return
	
	var orc_node: Node = _get_orc_mechanic()
	var waaagh: int = orc_node.get_waaagh(player_id) if orc_node != null else 0
	
	if waaagh >= 50:
		# WAAAGH!模式：无视伤亡全力进攻
		_orc_waaagh_assault(player_id, armies)
	elif _current_strategy == "defensive":
		_military_defend(player_id, armies)
	else:
		# 标准兽人进攻：找最弱目标
		_orc_standard_attack(player_id, armies)

func _orc_waaagh_assault(player_id: int, armies: Array) -> void:
	# WAAAGH!突击：不管敌方强度直接进攻
	for army in armies:
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		if attackable.is_empty():
			_advance_army(player_id, army)
			continue
		
		# 选择最高价值目标（不管守备强度）
		var best_target: int = _find_best_attack_target(attackable, player_id)
		if best_target >= 0:
			await GameManager.action_attack_with_army(army["id"], best_target)
			# WAAAGH!消耗
			var orc_node2: Node = _get_orc_mechanic()
			if orc_node2 != null:
				orc_node2.add_waaagh(player_id, -20)
			break

func _orc_standard_attack(player_id: int, armies: Array) -> void:
	# 标准进攻：优先攻击弱小目标
	for army in armies:
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		if attackable.is_empty():
			_advance_army(player_id, army)
			continue
		
		var army_power: int = GameManager.get_army_combat_power(army["id"])
		var best_target: int = _find_best_attack_target(attackable, player_id)
		
		if best_target >= 0:
			var target_garrison: int = GameManager.tiles[best_target].get("garrison", 0)
			# 兽人在1.0倍兵力时就进攻（比基类更激进）
			if army_power > target_garrison * 0.9:
				await GameManager.action_attack_with_army(army["id"], best_target)
				break
		
		_advance_army(player_id, army)

# ═══════════════════════════════════════════════════════════
func _get_orc_mechanic() -> Node:
	if Engine.get_main_loop() is SceneTree:
		var root: Node = (Engine.get_main_loop() as SceneTree).root
		if root.has_node("OrcMechanic"):
			return root.get_node("OrcMechanic")
	return null

# 覆盖：外交 (兽人几乎不外交)
# ═══════════════════════════════════════════════════════════
func _execute_diplomacy(player_id: int) -> void:
	# 兽人极少外交，只在极端情况下才停火
	if _military_score < 0.15 and randf() < 0.2:
		# 濒死时尝试停火
		if DiplomacyManager != null:
			var human_pid: int = GameManager.get_human_player_id()
			DiplomacyManager.offer_ceasefire(player_id, human_pid)
