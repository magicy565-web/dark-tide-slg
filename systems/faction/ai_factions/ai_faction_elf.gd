## ai_faction_elf.gd - 精灵族AI (战国兰斯风格)
## 特性：魔法屏障、远程优势、孤立主义、自然魔法
## 精灵族是光明阵营，由 LightFactionAI 管理防御，
## 此文件提供精灵族作为玩家可选势力时的辅助AI逻辑参考。
extends "res://systems/faction/ai_factions/ai_faction_base.gd"

const FactionData = preload("res://systems/faction/faction_data.gd")

func _init() -> void:
	## FactionConfig.FactionType.HIGH_ELF = 4
	super._init(4, "elf_ai")

# ═══════════════════════════════════════════════════════════
# 精灵族特有：内政优先级
# ═══════════════════════════════════════════════════════════
func _get_building_priority() -> Array:
	## 精灵族优先建造学院（魔法研究）和要塞（防御）
	return ["academy", "fortification", "training_ground", "warehouse"]

# ═══════════════════════════════════════════════════════════
# 精灵族特有：军事策略（孤立主义，优先防御）
# ═══════════════════════════════════════════════════════════
func _score_attack_target(player_id: int, army: Dictionary, tile: Dictionary) -> float:
	## 精灵族进攻评分：极度保守，只攻击孤立的弱小目标
	var score: float = 0.0
	var tile_idx: int = tile.get("index", -1)

	# 精灵族不主动进攻，除非被威胁
	var threat_level: int = ThreatManager.get_threat() if ThreatManager != null else 0
	if threat_level < 40:
		return -99.0  # 威胁低时不主动进攻

	# 基础地块价值
	match tile.get("type", -1):
		GameManager.TileType.CORE_FORTRESS: score += 15.0
		GameManager.TileType.LIGHT_STRONGHOLD: score += 10.0
		GameManager.TileType.MINE_TILE: score += 5.0
		_: score += 1.0

	# 精灵族偏好孤立目标（支援少的地块）
	var support_count: int = 0
	if tile_idx >= 0 and GameManager.adjacency.has(tile_idx):
		for nb in GameManager.adjacency[tile_idx]:
			if nb < GameManager.tiles.size() and GameManager.tiles[nb]["owner_id"] >= 0 and GameManager.tiles[nb]["owner_id"] != player_id:
				support_count += 1
	score += float(4 - support_count) * 3.0  # 孤立目标大幅加分

	# 精灵族避免攻打强敌
	var army_power: float = float(GameManager.get_army_combat_power(army["id"]))
	var def_power: float = float(tile.get("garrison", 0)) * 8.0
	if def_power > army_power * 1.1:
		score -= 20.0  # 精灵族极度谨慎

	return score

# ═══════════════════════════════════════════════════════════
# 精灵族特有：外交倾向（孤立主义，拒绝大多数外交）
# ═══════════════════════════════════════════════════════════
func _get_diplomacy_priority() -> float:
	## 精灵族外交优先级极低（孤立主义）
	return 0.1

# ═══════════════════════════════════════════════════════════
# 精灵族特有：屏障恢复（与LightFactionAI协同）
# ═══════════════════════════════════════════════════════════
func _try_restore_barriers(player_id: int) -> void:
	## 尝试恢复魔法屏障（精灵族核心防御机制）
	if LightFactionAI == null:
		return
	var owned_tiles: Array = GameManager.get_domestic_tiles(player_id)
	for tile in owned_tiles:
		var tile_idx: int = tile.get("index", -1)
		if tile_idx < 0:
			continue
		# 检查屏障是否失效
		if not LightFactionAI.is_barrier_active(tile_idx):
			var ley_bonus: int = LightFactionAI.get_ley_line_bonus(tile_idx)
			if ley_bonus >= 3:
				LightFactionAI._barrier_active[tile_idx] = true
				EventBus.message_log.emit("[精灵族] 魔法屏障恢复 #%d" % tile_idx)
