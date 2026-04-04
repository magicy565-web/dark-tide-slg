## ai_faction_pirate.gd - 暗黑海盗AI (战国兰斯风格)
## 特性：掠夺经济、炮击战术、海上机动、黑市贸易
extends "res://systems/faction/ai_factions/ai_faction_base.gd"

const PirateMechanic = preload("res://systems/faction/pirate_mechanic.gd")

func _init() -> void:
	super._init(1, "pirate") # FactionConfig.FactionType.PIRATE = 1

# ═══════════════════════════════════════════════════════════
# 覆盖：策略决定 (海盗重视经济和机会主义)
# ═══════════════════════════════════════════════════════════
func _decide_strategy(player_id: int) -> void:
	var gold: int = ResourceManager.get_gold(player_id) if ResourceManager != null else 0
	var plunder: int = PirateMechanic.get_plunder(player_id) if PirateMechanic != null else 0
	
	if _retreat_mode:
		_current_strategy = "defensive"
	elif gold < 100:
		# 缺钱时优先掠夺
		_current_strategy = "aggressive"
	elif plunder >= 30:
		# 掠夺值高时，激进扩张
		_current_strategy = "aggressive"
	elif _economy_score > 0.6:
		# 经济良好时，稳健发展
		_current_strategy = "economic"
	else:
		_current_strategy = "balanced"

# ═══════════════════════════════════════════════════════════
# 覆盖：内政 (海盗优先经济)
# ═══════════════════════════════════════════════════════════
func _execute_domestic(player_id: int) -> void:
	if GameManager == null:
		return
	
	var owned_tiles: Array = GameManager.get_domestic_tiles(player_id)
	if owned_tiles.is_empty():
		return
	
	# 海盗优先：商会 > 仓库 > 奴隶市场 > 训练场
	var pirate_priority: Array = ["merchant_guild", "warehouse", "slave_market", "training_ground", "fortification"]
	
	_try_build_priority(player_id, owned_tiles, pirate_priority)
	
	# 海盗经济充裕时多招募
	if _economy_score > 0.5:
		_try_recruit(player_id, owned_tiles)

# ═══════════════════════════════════════════════════════════
# 覆盖：军事 (海盗机会主义进攻)
# ═══════════════════════════════════════════════════════════
func _execute_military(player_id: int) -> void:
	if GameManager == null:
		return
	
	var armies: Array = GameManager.get_player_armies(player_id)
	if armies.is_empty():
		_create_initial_army(player_id)
		return
	
	match _current_strategy:
		"aggressive":
			_pirate_raid(player_id, armies)
		"defensive":
			_military_defend(player_id, armies)
		"economic":
			_military_hold(player_id, armies)
		_:
			_pirate_opportunistic(player_id, armies)

func _pirate_raid(player_id: int, armies: Array) -> void:
	# 掠夺模式：优先攻击资源丰富的地块
	for army in armies:
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		if attackable.is_empty():
			_advance_army(player_id, army)
			continue
		
		# 海盗优先攻击矿场、农场、港口
		var best_target: int = _find_pirate_raid_target(attackable)
		if best_target >= 0:
			await GameManager.action_attack_with_army(army["id"], best_target)
			break
		
		_advance_army(player_id, army)

func _find_pirate_raid_target(attackable: Array) -> int:
	var best_idx: int = -1
	var best_score: float = -999.0
	
	for tile_idx in attackable:
		if tile_idx >= GameManager.tiles.size():
			continue
		var tile: Dictionary = GameManager.tiles[tile_idx]
		var score: float = 0.0
		
		# 海盗优先资源地块
		match tile.get("type", -1):
			GameManager.TileType.MINE_TILE:
				score += 20.0
			GameManager.TileType.FARM_TILE:
				score += 15.0
			GameManager.TileType.HARBOR:
				score += 25.0  # 港口最高价值
			GameManager.TileType.TRADING_POST:
				score += 20.0
			GameManager.TileType.CORE_FORTRESS:
				score += 30.0
			GameManager.TileType.LIGHT_STRONGHOLD:
				score += 15.0
		
		# 弱守备加分
		var garrison: int = tile.get("garrison", 0)
		score += float(15 - garrison) * 0.8
		
		if score > best_score:
			best_score = score
			best_idx = tile_idx
	
	return best_idx if best_score > 0.0 else -1

func _pirate_opportunistic(player_id: int, armies: Array) -> void:
	# 机会主义：只攻击明显弱小的目标
	for army in armies:
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		if attackable.is_empty():
			_advance_army(player_id, army)
			continue
		
		var army_power: int = GameManager.get_army_combat_power(army["id"])
		
		for tile_idx in attackable:
			if tile_idx >= GameManager.tiles.size():
				continue
			var garrison: int = GameManager.tiles[tile_idx].get("garrison", 0)
			# 只在有明显优势时进攻
			if army_power > garrison * 1.5:
				await GameManager.action_attack_with_army(army["id"], tile_idx)
				return
		
		_advance_army(player_id, army)

# ═══════════════════════════════════════════════════════════
# 覆盖：外交 (海盗偶尔谈判)
# ═══════════════════════════════════════════════════════════
func _execute_diplomacy(player_id: int) -> void:
	if DiplomacyManager == null:
		return
	
	# 海盗有30%概率尝试外交
	if randf() > 0.3:
		return
	
	# 尝试与暗精灵改善关系
	if ResourceManager != null and ResourceManager.can_afford(player_id, {"gold": 80}):
		var dark_elf_fid: int = 2 # FactionData.FactionID.DARK_ELF
		var relations: Dictionary = DiplomacyManager.get_all_relations(player_id)
		if not relations.get(dark_elf_fid, {}).get("hostile", false):
			GameManager.action_diplomacy(player_id, dark_elf_fid, "tribute")
