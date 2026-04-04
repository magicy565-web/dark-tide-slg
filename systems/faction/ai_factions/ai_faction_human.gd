## ai_faction_human.gd - 人类王国AI (战国兰斯风格)
## 特性：坚固城防、均衡军队、光明联盟、反击战术
extends "res://systems/faction/ai_factions/ai_faction_base.gd"

const LightFactionAI = preload("res://systems/faction/light_faction_ai.gd")

func _init() -> void:
	super._init(3, "human") # FactionConfig.FactionType.HUMAN = 3

# ═══════════════════════════════════════════════════════════
# 覆盖：策略决定 (人类重视防御和反击)
# ═══════════════════════════════════════════════════════════
func _decide_strategy(player_id: int) -> void:
	# 人类优先防御，受到攻击后反击
	var threat: int = ThreatManager.get_threat() if ThreatManager != null else 0
	
	if threat >= 60:
		# 高威胁时全力防御
		_current_strategy = "defensive"
	elif _military_score > 0.7 and threat < 30:
		# 军力充足且威胁低时，主动反击
		_current_strategy = "aggressive"
	elif _economy_score < 0.4:
		_current_strategy = "economic"
	else:
		_current_strategy = "balanced"

# ═══════════════════════════════════════════════════════════
# 覆盖：内政 (人类均衡发展)
# ═══════════════════════════════════════════════════════════
func _execute_domestic(player_id: int) -> void:
	if GameManager == null:
		return
	
	var owned_tiles: Array = GameManager.get_domestic_tiles(player_id)
	if owned_tiles.is_empty():
		return
	
	# 人类优先：城防 > 商会 > 训练场 > 苦役营 > 学院
	var human_priority: Array = ["fortification", "merchant_guild", "training_ground", "labor_camp", "academy"]
	
	# 优先修缮城墙
	_repair_walls(player_id, owned_tiles)
	
	_try_build_priority(player_id, owned_tiles, human_priority)
	
	# 均衡招募
	if _military_score < 0.6:
		_try_recruit(player_id, owned_tiles)

func _repair_walls(player_id: int, owned_tiles: Array) -> void:
	# 修缮受损城墙
	if LightFactionAI == null:
		return
	for tile in owned_tiles:
		var tile_idx: int = tile["index"]
		var wall_hp: int = LightFactionAI.get_wall_hp(tile_idx)
		# 城墙受损时修缮
		if wall_hp > 0 and wall_hp < 20:
			LightFactionAI.repair_wall(tile_idx, 5)

# ═══════════════════════════════════════════════════════════
# 覆盖：军事 (人类防御反击)
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
			_human_counter_attack(player_id, armies)
		"defensive":
			_human_fortify_defense(player_id, armies)
		"economic":
			_military_hold(player_id, armies)
		_:
			_human_balanced_ops(player_id, armies)

func _human_counter_attack(player_id: int, armies: Array) -> void:
	# 反击：优先攻击刚攻击过人类的势力
	for army in armies:
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		if attackable.is_empty():
			_advance_army(player_id, army)
			continue
		
		var army_power: int = GameManager.get_army_combat_power(army["id"])
		var best_target: int = _find_best_attack_target(attackable, player_id)
		
		if best_target >= 0:
			var garrison: int = GameManager.tiles[best_target].get("garrison", 0)
			# 人类在1.1倍优势时反击
			if army_power > garrison * 1.1:
				await GameManager.action_attack_with_army(army["id"], best_target)
				break
		
		_advance_army(player_id, army)

func _human_fortify_defense(player_id: int, armies: Array) -> void:
	# 防御：将军队集中到重要据点
	for army in armies:
		var tile_idx: int = army.get("tile_index", -1)
		if tile_idx < 0:
			continue
		
		# 如果在弱小地块，移动到核心
		if not _is_important_tile(tile_idx):
			_retreat_to_core(player_id, army)
		else:
			# 在重要地块驻守
			GameManager.action_guard_territory(player_id, tile_idx)

func _human_balanced_ops(player_id: int, armies: Array) -> void:
	# 均衡作战：守住核心，伺机进攻
	for army in armies:
		var attackable: Array = GameManager.get_army_attackable_tiles(army["id"])
		if attackable.is_empty():
			_advance_army(player_id, army)
			continue
		
		var army_power: int = GameManager.get_army_combat_power(army["id"])
		var best_target: int = _find_best_attack_target(attackable, player_id)
		
		if best_target >= 0:
			var garrison: int = GameManager.tiles[best_target].get("garrison", 0)
			# 人类需要1.4倍优势才主动进攻
			if army_power > garrison * 1.4:
				await GameManager.action_attack_with_army(army["id"], best_target)
				break
		
		# 否则驻守当前位置
		var cur_tile: int = army.get("tile_index", -1)
		if cur_tile >= 0 and _is_important_tile(cur_tile):
			GameManager.action_guard_territory(player_id, cur_tile)

# ═══════════════════════════════════════════════════════════
# 覆盖：外交 (人类积极外交)
# ═══════════════════════════════════════════════════════════
func _execute_diplomacy(player_id: int) -> void:
	if DiplomacyManager == null:
		return
	
	# 人类有70%概率尝试外交
	if randf() > 0.7:
		return
	
	# 优先与精灵族结盟
	if ResourceManager != null and ResourceManager.can_afford(player_id, {"gold": 100}):
		var elf_fid: int = 1 # FactionData.LightFaction.HIGH_ELVES
		var relations: Dictionary = DiplomacyManager.get_all_relations(player_id)
		if not relations.get(elf_fid, {}).get("allied", false):
			GameManager.action_diplomacy(player_id, elf_fid, "tribute")
	
	# 对邪恶势力发出警告
	var evil_factions: Array = [0, 1, 2] # ORC, PIRATE, DARK_ELF
	for fid in evil_factions:
		var relations: Dictionary = DiplomacyManager.get_all_relations(player_id)
		if relations.get(fid, {}).get("hostile", false):
			# 已经敌对，不需要外交
			continue
