## ai_faction_base.gd - AI势力基类 (战国兰斯风格)
## 所有5个AI势力继承此类，提供通用的内政、外交、战争决策框架
extends RefCounted
class_name AIFactionBase

const FactionData = preload("res://systems/faction/faction_data.gd")
# FactionConfig is registered as autoload - use directly

# ── 势力标识 ──
var faction_type: int = -1
var faction_key: String = ""
var is_active: bool = true

# ── AI状态 ──
var _current_strategy: String = "balanced" # balanced, aggressive, defensive, economic
var _threat_level: int = 0
var _economy_score: float = 0.0
var _military_score: float = 0.0
var _turn_actions_taken: int = 0

# ── 内政记忆 ──
var _last_built: String = ""
var _expansion_target: int = -1
var _retreat_mode: bool = false

func _init(f_type: int, f_key: String) -> void:
	faction_type = f_type
	faction_key = f_key

# ═══════════════════════════════════════════════════════════
# 主回合入口
# ═══════════════════════════════════════════════════════════
func tick_turn(player_id: int) -> void:  ## BUG FIX: callers must await this if military actions are async
	if not is_active:
		return
	
	_turn_actions_taken = 0
	
	# 评估当前局势
	_assess_situation(player_id)
	
	# 决定本回合策略
	_decide_strategy(player_id)
	
	# 执行内政
	_execute_domestic(player_id)
	
	# 执行军事
	await _execute_military(player_id)
	
	# 执行外交
	_execute_diplomacy(player_id)

# ═══════════════════════════════════════════════════════════
# 局势评估
# ═══════════════════════════════════════════════════════════
func _assess_situation(player_id: int) -> void:
	# 评估威胁等级
	_threat_level = ThreatManager.get_threat() if ThreatManager != null else 0
	
	# 评估经济状况
	var gold: int = ResourceManager.get_gold(player_id) if ResourceManager != null else 0
	var food: int = ResourceManager.get_food(player_id) if ResourceManager != null else 0
	_economy_score = float(gold + food * 2) / 300.0
	_economy_score = clampf(_economy_score, 0.0, 1.0)
	
	# 评估军事力量
	var army: int = ResourceManager.get_army(player_id) if ResourceManager != null else 0
	_military_score = float(army) / 20.0
	_military_score = clampf(_military_score, 0.0, 1.0)
	
	# 检查是否需要撤退
	var config: Dictionary = FactionConfig.get_config(faction_type)
	var defense_threshold: float = config.get("ai_defense_threshold", 0.4)
	_retreat_mode = _military_score < defense_threshold

func _decide_strategy(player_id: int) -> void:
	var config: Dictionary = FactionConfig.get_config(faction_type)
	var aggression: float = config.get("ai_aggression", 0.5)
	var economy_priority: float = config.get("ai_economy_priority", 0.5)
	
	if _retreat_mode:
		_current_strategy = "defensive"
	elif _economy_score < 0.3:
		_current_strategy = "economic"
	elif _military_score > 0.7 and aggression > 0.6:
		_current_strategy = "aggressive"
	elif economy_priority > 0.6:
		_current_strategy = "economic"
	else:
		_current_strategy = "balanced"

# ═══════════════════════════════════════════════════════════
# 内政执行 (通用逻辑)
# ═══════════════════════════════════════════════════════════
func _execute_domestic(player_id: int) -> void:
	if GameManager == null:
		return
	
	var owned_tiles: Array = GameManager.get_domestic_tiles(player_id)
	if owned_tiles.is_empty():
		return
	
	# 根据策略决定内政重点
	match _current_strategy:
		"economic":
			_domestic_economy_focus(player_id, owned_tiles)
		"military", "aggressive":
			_domestic_military_focus(player_id, owned_tiles)
		"defensive":
			_domestic_defense_focus(player_id, owned_tiles)
		_: # balanced
			_domestic_balanced(player_id, owned_tiles)

func _domestic_economy_focus(player_id: int, owned_tiles: Array) -> void:
	# 优先建造经济建筑
	var eco_buildings: Array = ["merchant_guild", "labor_camp", "warehouse"]
	_try_build_priority(player_id, owned_tiles, eco_buildings)

func _domestic_military_focus(player_id: int, owned_tiles: Array) -> void:
	# 优先建造军事建筑
	var mil_buildings: Array = ["training_ground", "arena", "fortification"]
	_try_build_priority(player_id, owned_tiles, mil_buildings)
	# 同时招募兵力
	_try_recruit(player_id, owned_tiles)

func _domestic_defense_focus(player_id: int, owned_tiles: Array) -> void:
	# 优先加固防御
	var def_buildings: Array = ["fortification", "warehouse", "training_ground"]
	_try_build_priority(player_id, owned_tiles, def_buildings)

func _domestic_balanced(player_id: int, owned_tiles: Array) -> void:
	# 均衡发展：按势力优先级建造
	var config: Dictionary = FactionConfig.get_config(faction_type)
	var priority: Array = config.get("building_priority", ["training_ground", "merchant_guild"])
	_try_build_priority(player_id, owned_tiles, priority)
	_try_recruit(player_id, owned_tiles)

func _try_build_priority(player_id: int, owned_tiles: Array, building_list: Array) -> bool:
	# 尝试在最合适的地块建造优先级最高的建筑
	for building_id in building_list:
		for tile in owned_tiles:
			if _can_build_at(player_id, tile, building_id):
				_do_build(player_id, tile["index"], building_id)
				return true
	return false

func _can_build_at(player_id: int, tile: Dictionary, building_id: String) -> bool:
	## BUG FIX: Use BuildingRegistry.can_build_at which correctly checks tile["building_id"] field
	if BuildingRegistry == null:
		return false
	return BuildingRegistry.can_build_at(player_id, tile, building_id)

func _do_build(player_id: int, tile_index: int, building_id: String) -> void:
	if GameManager == null:
		return
	# BUG FIX: action_domestic expects building_id as String, not Dictionary
	GameManager.action_domestic(player_id, tile_index, "build", building_id)
	_last_built = building_id
	_turn_actions_taken += 1

func _try_recruit(player_id: int, owned_tiles: Array) -> bool:
	if GameManager == null or ResourceManager == null:
		return false
	
	var config: Dictionary = FactionConfig.get_config(faction_type)
	var recruit_gold: int = config.get("gold_per_recruit", 50)
	var recruit_iron: int = config.get("iron_per_recruit", 12)
	
	if not ResourceManager.can_afford(player_id, {"gold": recruit_gold, "iron": recruit_iron}):
		return false
	
	# 检查人口上限
	var army: int = ResourceManager.get_army(player_id)
	var pop_cap: int = GameManager.get_population_cap(player_id)
	if army >= pop_cap:
		return false
	
	# 在最前线的地块招募
	var best_tile: int = owned_tiles[0]["index"]
	for tile in owned_tiles:
		if _is_border_tile(tile["index"]):
			best_tile = tile["index"]
			break
	
	GameManager.action_domestic(player_id, best_tile, "recruit")
	_turn_actions_taken += 1
	return true

func _is_border_tile(tile_index: int) -> bool:
	if GameManager == null:
		return false
	if not GameManager.adjacency.has(tile_index):
		return false
	for nb_idx in GameManager.adjacency[tile_index]:
		if nb_idx < GameManager.tiles.size():
			var nb: Dictionary = GameManager.tiles[nb_idx]
			if nb.get("owner_id", -1) >= 0 and nb["owner_id"] != GameManager.get_human_player_id():
				return true
	return false

# ═══════════════════════════════════════════════════════════
# 军事执行 (通用逻辑)
# ═══════════════════════════════════════════════════════════
func _execute_military(player_id: int):
	if GameManager == null:
		return
	
	var armies: Array = GameManager.get_player_armies(player_id)
	if armies.is_empty():
		_create_initial_army(player_id)
		return
	
	match _current_strategy:
		"aggressive":
			await _military_attack(player_id, armies)
		"defensive":
			_military_defend(player_id, armies)
		"economic":
			_military_hold(player_id, armies)
		_: # balanced
			await _military_balanced(player_id, armies)

func _create_initial_army(player_id: int) -> void:
	var owned_tiles: Array = GameManager.get_domestic_tiles(player_id)
	if owned_tiles.is_empty():
		return
	var start_tile: int = owned_tiles[0]["index"]
	for tile in owned_tiles:
		if tile["type"] == GameManager.TileType.CORE_FORTRESS or tile["type"] == GameManager.TileType.DARK_BASE:
			start_tile = tile["index"]
			break
	GameManager.create_army(player_id, start_tile, faction_key + "军")

func _military_attack(player_id: int, armies: Array) -> void:
	# 进攻策略：找最弱的相邻敌方地块进攻
	for army in armies:
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		if attackable.is_empty():
			# 移动到前线
			_advance_army(player_id, army)
			continue
		
		var best_target: int = _find_best_attack_target(attackable, player_id)
		if best_target >= 0:
			await GameManager.action_attack_with_army(army["id"], best_target)
			break

func _military_defend(player_id: int, armies: Array) -> void:
	# 防御策略：守住最重要的地块
	for army in armies:
		var tile_idx: int = army.get("tile_index", -1)
		if tile_idx < 0:
			continue
		# 如果当前位置不是重要地块，移动到核心
		if not _is_important_tile(tile_idx):
			_retreat_to_core(player_id, army)

func _military_hold(player_id: int, armies: Array) -> void:
	# 保守策略：不主动进攻，只守住现有领土
	pass

func _military_balanced(player_id: int, armies: Array) -> void:
	# 均衡策略：有机会就进攻，受威胁就防御
	for army in armies:
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		if attackable.is_empty():
			_advance_army(player_id, army)
			continue
		
		var army_power: int = GameManager.get_army_combat_power(army["id"])
		var best_target: int = _find_best_attack_target(attackable, player_id)
		
		if best_target >= 0:
			var target_garrison: int = GameManager.tiles[best_target].get("garrison", 0)
			# 只在有优势时进攻
			if army_power > target_garrison * 1.2:
				await GameManager.action_attack_with_army(army["id"], best_target)
				break
		
		# 否则移动到更好的位置
		_advance_army(player_id, army)

func _find_best_attack_target(attackable: Array, player_id: int) -> int:
	var best_idx: int = -1
	var best_score: float = -999.0
	
	for tile_idx in attackable:
		if tile_idx >= GameManager.tiles.size():
			continue
		if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
			continue
		var tile: Dictionary = GameManager.tiles[tile_idx]
		var score: float = _score_attack_target(tile, player_id)
		if score > best_score:
			best_score = score
			best_idx = tile_idx
	
	return best_idx if best_score > 0.0 else -1

func _score_attack_target(tile: Dictionary, player_id: int) -> float:
	var score: float = 0.0
	
	# 弱守备加分
	var garrison: int = tile.get("garrison", 0)
	score += float(20 - garrison) * 0.5
	
	# 重要地块加分
	match tile.get("type", -1):
		GameManager.TileType.CORE_FORTRESS:
			score += 30.0
		GameManager.TileType.DARK_BASE, GameManager.TileType.LIGHT_STRONGHOLD:
			score += 15.0
		GameManager.TileType.MINE_TILE:
			score += 10.0
		GameManager.TileType.FARM_TILE:
			score += 8.0
	
	# 光明势力地块加分（对邪恶势力）
	if tile.get("light_faction", -1) >= 0:
		score += 5.0
	
	return score

func _advance_army(player_id: int, army: Dictionary) -> void:
	var deployable: Array = GameManager.get_army_deployable_tiles(army["id"])
	if deployable.is_empty():
		return
	
	# 找最靠近敌方的地块
	var best_tile: int = -1
	var best_score: float = -1.0
	
	for dtile in deployable:
		var score: float = 0.0
		if GameManager.adjacency.has(dtile):
			for nb in GameManager.adjacency[dtile]:
				if nb < GameManager.tiles.size():
					var nb_tile: Dictionary = GameManager.tiles[nb]
					if nb_tile.get("owner_id", -1) >= 0 and nb_tile["owner_id"] != player_id:
						score += 3.0
						if nb_tile.get("garrison", 0) < 5:
							score += 2.0
		if score > best_score:
			best_score = score
			best_tile = dtile
	
	if best_tile >= 0:
		GameManager.action_deploy_army(army["id"], best_tile)

func _is_important_tile(tile_index: int) -> bool:
	if tile_index >= GameManager.tiles.size():
		return false
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	var tile: Dictionary = GameManager.tiles[tile_index]
	return tile.get("type", -1) in [
		GameManager.TileType.CORE_FORTRESS,
		GameManager.TileType.DARK_BASE,
		GameManager.TileType.LIGHT_STRONGHOLD,
	]

func _retreat_to_core(player_id: int, army: Dictionary) -> void:
	var owned_tiles: Array = GameManager.get_domestic_tiles(player_id)
	for tile in owned_tiles:
		if tile.get("type", -1) == GameManager.TileType.CORE_FORTRESS:
			GameManager.action_deploy_army(army["id"], tile["index"])
			return

# ═══════════════════════════════════════════════════════════
# 外交执行 (通用逻辑)
# ═══════════════════════════════════════════════════════════
func _execute_diplomacy(player_id: int) -> void:
	if DiplomacyManager == null:
		return
	
	var config: Dictionary = FactionConfig.get_config(faction_type)
	var diplomacy_priority: float = config.get("ai_diplomacy_priority", 0.3)
	
	# 低概率触发外交行动
	if randf() > diplomacy_priority:
		return
	
	# 尝试与其他势力建立关系
	_try_diplomacy_action(player_id)

func _try_diplomacy_action(player_id: int) -> void:
	# 基础外交：尝试停火或结盟
	var config: Dictionary = FactionConfig.get_config(faction_type)
	var bias: Dictionary = config.get("diplomacy_bias", {})
	
	# 对友好势力尝试结盟
	for faction_key_str in bias:
		if bias[faction_key_str] == "friendly":
			var target_faction_id: int = _key_to_faction_id(faction_key_str)
			if target_faction_id >= 0:
				# 检查是否已经是盟友
				var relations: Dictionary = DiplomacyManager.get_all_relations(player_id)
				if not relations.get(target_faction_id, {}).get("allied", false):
					# 尝试提供贡品改善关系
					if ResourceManager.can_afford(player_id, {"gold": 80}):
						GameManager.action_diplomacy(player_id, target_faction_id, "tribute")
						return

func _key_to_faction_id(key: String) -> int:
	match key:
		"orc": return FactionData.FactionID.ORC
		"pirate": return FactionData.FactionID.PIRATE
		"dark_elf": return FactionData.FactionID.DARK_ELF
		"human": return FactionData.LightFaction.HUMAN_KINGDOM
		"high_elf": return FactionData.LightFaction.HIGH_ELVES
	return -1
