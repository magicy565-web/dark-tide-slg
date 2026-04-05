## ai_faction_dark_elf.gd - 黑暗精灵议会AI (战国兰斯风格)
## 特性：情报网络、奴隶经济、魔法战术、暗影刺杀
extends "res://systems/faction/ai_factions/ai_faction_base.gd"

func _init() -> void:
	super._init(2, "dark_elf") # FactionConfig.FactionType.DARK_ELF = 2

# ═══════════════════════════════════════════════════════════
# 覆盖：策略决定 (暗精灵重视情报和时机)
# ═══════════════════════════════════════════════════════════
func _decide_strategy(player_id: int) -> void:
	var slaves: int = ResourceManager.get_slaves(player_id) if ResourceManager != null else 0
	var intel: int = EspionageSystem.get_intel(player_id)
	
	if _retreat_mode:
		_current_strategy = "defensive"
	elif intel >= 50:
		# 情报充足时，精准打击
		_current_strategy = "aggressive"
	elif slaves < 3:
		# 奴隶不足时，优先内政
		_current_strategy = "economic"
	elif _military_score > 0.6:
		_current_strategy = "balanced"
	else:
		_current_strategy = "economic"

# ═══════════════════════════════════════════════════════════
# 覆盖：内政 (暗精灵优先研究和奴隶)
# ═══════════════════════════════════════════════════════════
func _execute_domestic(player_id: int) -> void:
	if GameManager == null:
		return
	
	var owned_tiles: Array = GameManager.get_domestic_tiles(player_id)
	if owned_tiles.is_empty():
		return
	
	# 暗精灵优先：学院 > 奴隶市场 > 城防 > 苦役营 > 训练场
	var de_priority: Array = ["academy", "slave_market", "fortification", "labor_camp", "training_ground"]
	
	_try_build_priority(player_id, owned_tiles, de_priority)
	
	# 暗精灵使用奴隶增强经济
	_manage_slaves(player_id, owned_tiles)
	
	# 适量招募
	if _military_score < 0.5:
		_try_recruit(player_id, owned_tiles)

func _manage_slaves(player_id: int, owned_tiles: Array) -> void:
	# 奴隶管理：将奴隶分配到苦役营
	if SlaveManager == null:
		return
	var slaves: int = ResourceManager.get_slaves(player_id) if ResourceManager != null else 0
	if slaves > 5:
		# 奴隶充足时，尝试转化为资源
		for tile in owned_tiles:
			if tile.get("buildings", {}).has("labor_camp"):
				# 苦役营激活
				break

# ═══════════════════════════════════════════════════════════
# 覆盖：军事 (暗精灵精准战术)
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
			_dark_elf_precision_strike(player_id, armies)
		"defensive":
			_dark_elf_fortify(player_id, armies)
		"economic":
			_military_hold(player_id, armies)
		_:
			_dark_elf_tactical(player_id, armies)

func _dark_elf_precision_strike(player_id: int, armies: Array) -> void:
	# 精准打击：利用情报选择最佳目标
	for army in armies:
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		if attackable.is_empty():
			_advance_army(player_id, army)
			continue
		
		# 优先攻击孤立的高价值目标
		var best_target: int = _find_isolated_target(attackable, player_id)
		if best_target >= 0:
			await GameManager.action_attack_with_army(army["id"], best_target)
			break
		
		_advance_army(player_id, army)

func _find_isolated_target(attackable: Array, player_id: int) -> int:
	var best_idx: int = -1
	var best_score: float = -999.0
	
	for tile_idx in attackable:
		if tile_idx >= GameManager.tiles.size():
			continue
		if tile_idx < 0 or tile_idx >= GameManager.tiles.size():
			return
		var tile: Dictionary = GameManager.tiles[tile_idx]
		var score: float = 0.0
		
		# 孤立目标加分（相邻没有其他敌方援军）
		var support_count: int = 0
		if GameManager.adjacency.has(tile_idx):
			for nb_idx in GameManager.adjacency[tile_idx]:
				if nb_idx < GameManager.tiles.size():
					var nb: Dictionary = GameManager.tiles[nb_idx]
					if nb.get("owner_id", -1) >= 0 and nb["owner_id"] != player_id:
						support_count += 1
		
		# 孤立目标（支援少）加分
		score += float(5 - support_count) * 3.0
		
		# 高价值目标加分
		match tile.get("type", -1):
			GameManager.TileType.CORE_FORTRESS:
				score += 25.0
			GameManager.TileType.LIGHT_STRONGHOLD:
				score += 12.0
		
		# 弱守备加分
		var garrison: int = tile.get("garrison", 0)
		score += float(15 - garrison) * 0.6
		
		if score > best_score:
			best_score = score
			best_idx = tile_idx
	
	return best_idx if best_score > 0.0 else -1

func _dark_elf_fortify(player_id: int, armies: Array) -> void:
	# 防御时加强城防
	for army in armies:
		var tile_idx: int = army.get("tile_index", -1)
		if tile_idx < 0:
			continue
		if not _is_important_tile(tile_idx):
			_retreat_to_core(player_id, army)

func _dark_elf_tactical(player_id: int, armies: Array) -> void:
	# 战术模式：谨慎进攻，确保优势
	for army in armies:
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		if attackable.is_empty():
			_advance_army(player_id, army)
			continue
		
		var army_power: int = GameManager.get_army_combat_power(army["id"])
		var best_target: int = _find_best_attack_target(attackable, player_id)
		
		if best_target >= 0:
			var garrison: int = GameManager.tiles[best_target].get("garrison", 0)
			# 暗精灵需要1.3倍优势才进攻
			if army_power > garrison * 1.3:
				await GameManager.action_attack_with_army(army["id"], best_target)
				break
		
		_advance_army(player_id, army)

# ═══════════════════════════════════════════════════════════
# 覆盖：外交 (暗精灵主动外交)
# ═══════════════════════════════════════════════════════════
func _execute_diplomacy(player_id: int) -> void:
	if DiplomacyManager == null:
		return
	
	# 暗精灵有50%概率尝试外交
	if randf() > 0.5:
		return
	
	# 优先与海盗改善关系
	if ResourceManager != null and ResourceManager.can_afford(player_id, {"gold": 80}):
		var pirate_fid: int = 1 # FactionData.FactionID.PIRATE
		var relations: Dictionary = DiplomacyManager.get_all_relations(player_id)
		if not relations.get(pirate_fid, {}).get("allied", false):
			GameManager.action_diplomacy(player_id, pirate_fid, "tribute")
