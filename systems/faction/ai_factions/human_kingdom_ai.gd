## human_kingdom_ai.gd — 人类王国 AI 行为系统 (v1.0)
## 天城王朝：防守反击型 AI，城防依赖，英雄驱动，官僚迟缓
## 依赖: ai_faction_base.gd, light_faction_ai.gd, diplomacy_manager.gd
extends Node

# ═══════════════════════════════════════════════════════════
# 常量
# ═══════════════════════════════════════════════════════════

## 人类王国的光明阵营 ID（对应 FactionData.LightFaction.HUMAN_KINGDOM）
const HUMAN_FACTION_ID: int = 0

## 动员度阈值
const MOBILIZATION_ALERT: int    = 30   # 戒备：开始外交、边境增援
const MOBILIZATION_WAR: int      = 60   # 战争动员：凛出击
const MOBILIZATION_CRUSADE: int  = 80   # 圣战：全面战争

## 城墙相关
const WALL_REGEN_BASE: int       = 3    # 基础城墙每回合恢复量
const WALL_REGEN_BONUS: int      = 3    # 人类额外城墙恢复（文档：双倍）
const WALL_REPAIR_THRESHOLD: int = 15   # 城墙 HP 低于此值时优先修缮
const WALL_REPAIR_AMOUNT: int    = 8    # 每次修缮量

## 边境增援
const REINFORCE_MIN_INTERIOR: int = 4   # 内部据点守军低于此值时不抽调
const REINFORCE_BATCH: int        = 2   # 每次增援量

## 英雄出击
const RIN_DEPLOY_THREAT: int     = 60   # 凛出击的威胁阈值
const KOUYOU_CONTACT_THREAT: int = 40   # 红叶接触玩家的威胁阈值
const KOUYOU_CONTACT_PRESTIGE: int = 30 # 红叶接触玩家所需的玩家威望

## 动员度计算
const MOBILIZATION_THREAT_MULT: float  = 1.1
const MOBILIZATION_ATTACK_BONUS: int   = 5   # 每被攻击1回合额外+5

## 反击优势阈值（人类需要多大优势才主动出击）
const COUNTER_ATTACK_RATIO: float = 1.1  # 1.1倍优势即可反击（较激进）
const BALANCED_ATTACK_RATIO: float = 1.4 # 均衡模式需要1.4倍

# ═══════════════════════════════════════════════════════════
# 状态变量
# ═══════════════════════════════════════════════════════════

## 动员度（0-100）：人类王国的核心状态，驱动所有行为
var _mobilization: int = 0

## 连续被攻击回合数（用于加速动员）
var _turns_under_attack: int = 0

## 凛是否已出击（本局）
var _rin_deployed: bool = false

## 红叶是否已发出接触事件
var _kouyou_contacted: bool = false

## 圣战是否已触发（本局，一次性）
var _crusade_triggered: bool = false

## 贵族内乱事件冷却（回合数）
var _noble_crisis_cooldown: int = 0

## 上一回合记录的玩家据点数（用于检测攻击）
var _last_player_tile_count: int = 0

# ═══════════════════════════════════════════════════════════
# 初始化 & 重置
# ═══════════════════════════════════════════════════════════

func _ready() -> void:
	pass


func reset() -> void:
	_mobilization = 0
	_turns_under_attack = 0
	_rin_deployed = false
	_kouyou_contacted = false
	_crusade_triggered = false
	_noble_crisis_cooldown = 0
	_last_player_tile_count = 0


func to_save_data() -> Dictionary:
	return {
		"mobilization": _mobilization,
		"turns_under_attack": _turns_under_attack,
		"rin_deployed": _rin_deployed,
		"kouyou_contacted": _kouyou_contacted,
		"crusade_triggered": _crusade_triggered,
		"noble_crisis_cooldown": _noble_crisis_cooldown,
	}


func from_save_data(data: Dictionary) -> void:
	_mobilization          = data.get("mobilization", 0)
	_turns_under_attack    = data.get("turns_under_attack", 0)
	_rin_deployed          = data.get("rin_deployed", false)
	_kouyou_contacted      = data.get("kouyou_contacted", false)
	_crusade_triggered     = data.get("crusade_triggered", false)
	_noble_crisis_cooldown = data.get("noble_crisis_cooldown", 0)

# ═══════════════════════════════════════════════════════════
# 主入口：每回合调用
# ═══════════════════════════════════════════════════════════

## 人类王国 AI 每回合主循环。由 LightFactionAI 或 GameManager 调用。
func tick(player_id: int) -> void:
	# Phase 0: 评估状态
	_update_mobilization()
	_check_attack_status()
	_tick_cooldowns()

	# Phase 1: 防御（每回合必执行）
	_phase_defense(player_id)

	# Phase 2: 外交（动员度 ≥ ALERT）
	if _mobilization >= MOBILIZATION_ALERT:
		_phase_diplomacy(player_id)

	# Phase 3: 军事行动（动员度 ≥ WAR）
	if _mobilization >= MOBILIZATION_WAR:
		_phase_military(player_id)

	# Phase 4: 殊死抵抗（动员度 ≥ CRUSADE，一次性）
	if _mobilization >= MOBILIZATION_CRUSADE and not _crusade_triggered:
		_phase_crusade(player_id)

	# Phase 5: 特色事件检查
	_check_special_events(player_id)

# ═══════════════════════════════════════════════════════════
# Phase 0: 状态评估
# ═══════════════════════════════════════════════════════════

func _update_mobilization() -> void:
	var threat: int = ThreatManager.get_threat() if ThreatManager != null else 0
	var raw: float = float(threat) * MOBILIZATION_THREAT_MULT
	raw += float(_turns_under_attack) * MOBILIZATION_ATTACK_BONUS
	_mobilization = clampi(int(raw), 0, 100)
	EventBus.human_mobilization_changed.emit(_mobilization)


func _check_attack_status() -> void:
	## 检测玩家本回合是否攻占了人类据点（通过比较据点数变化）
	var current_player_tiles: int = _count_player_tiles_adjacent_to_human()
	if current_player_tiles > _last_player_tile_count:
		_turns_under_attack += 1
	else:
		_turns_under_attack = maxi(0, _turns_under_attack - 1)
	_last_player_tile_count = current_player_tiles


func _count_player_tiles_adjacent_to_human() -> int:
	## 统计与人类据点相邻的玩家据点数量（衡量压力）
	if GameManager == null:
		return 0
	var count: int = 0
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if not GameManager.adjacency.has(tile["index"]):
			continue
		for nb_idx in GameManager.adjacency[tile["index"]]:
			if nb_idx < GameManager.tiles.size():
				var nb: Dictionary = GameManager.tiles[nb_idx]
				if nb.get("owner_id", -1) >= 0:
					count += 1
					break
	return count


func _tick_cooldowns() -> void:
	if _noble_crisis_cooldown > 0:
		_noble_crisis_cooldown -= 1

# ═══════════════════════════════════════════════════════════
# Phase 1: 防御行动
# ═══════════════════════════════════════════════════════════

func _phase_defense(player_id: int) -> void:
	_regen_and_repair_walls()
	_reinforce_border_tiles()
	_guard_capital()


func _regen_and_repair_walls() -> void:
	## 人类城墙每回合额外恢复（双倍基础量）
	if LightFactionAI == null:
		return
	LightFactionAI.regen_walls()  # 基础恢复（已在 LightFactionAI 中实现）
	# 额外恢复：人类专属
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		var tile_idx: int = tile["index"]
		var wall_hp: int = LightFactionAI.get_wall_hp(tile_idx)
		if wall_hp <= 0:
			continue
		# 额外城墙恢复
		LightFactionAI.repair_wall(tile_idx, WALL_REGEN_BONUS)
		# 优先修缮受损严重的城墙
		if wall_hp < WALL_REPAIR_THRESHOLD:
			LightFactionAI.repair_wall(tile_idx, WALL_REPAIR_AMOUNT)
			EventBus.message_log.emit("[人类王国] 紧急修缮城墙 #%d（城防 %d → %d）" % [
				tile_idx, wall_hp, LightFactionAI.get_wall_hp(tile_idx)])


func _reinforce_border_tiles() -> void:
	## 将内部多余守军向最弱边境据点输送
	if GameManager == null:
		return
	var border_tiles: Array = []
	var interior_tiles: Array = []
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue  # 已被玩家占领
		var is_border: bool = _is_border_tile(tile)
		if is_border:
			border_tiles.append(tile)
		else:
			interior_tiles.append(tile)
	if border_tiles.is_empty() or interior_tiles.is_empty():
		return
	# 按守军从少到多排序边境据点
	border_tiles.sort_custom(func(a, b): return a.get("garrison", 0) < b.get("garrison", 0))
	var weakest_border: Dictionary = border_tiles[0]
	for interior in interior_tiles:
		var interior_garrison: int = interior.get("garrison", 0)
		if interior_garrison <= REINFORCE_MIN_INTERIOR:
			continue
		if weakest_border.get("garrison", 0) >= interior_garrison:
			continue
		var transfer: int = mini(REINFORCE_BATCH, interior_garrison - REINFORCE_MIN_INTERIOR)
		interior["garrison"] -= transfer
		weakest_border["garrison"] += transfer
		EventBus.message_log.emit("[人类王国] 内部守军增援边境 #%d (+%d兵)" % [
			weakest_border["index"], transfer])
		break


func _guard_capital() -> void:
	## 圣殿骑士团固守王都，不参与边境增援
	## 王都 tile 类型为 CORE_FORTRESS，light_faction = HUMAN
	if GameManager == null:
		return
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("type", -1) != GameManager.TileType.CORE_FORTRESS:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		# 确保王都守军不低于最低值
		var capital_min: int = 12 if _mobilization >= MOBILIZATION_WAR else 8
		if tile.get("garrison", 0) < capital_min:
			tile["garrison"] = capital_min
			EventBus.message_log.emit("[人类王国] 圣殿骑士团加强王都守备（%d兵）" % capital_min)

# ═══════════════════════════════════════════════════════════
# Phase 2: 外交行动
# ═══════════════════════════════════════════════════════════

func _phase_diplomacy(player_id: int) -> void:
	_try_ally_with_elves()
	_try_arms_trade_with_mage()
	_try_warn_player(player_id)
	_try_kouyou_contact(player_id)


func _try_ally_with_elves() -> void:
	## 尝试与高等精灵结盟（每3回合检查一次）
	if DiplomacyManager == null or ResourceManager == null:
		return
	var elf_fid: int = 1  # FactionData.LightFaction.HIGH_ELVES
	var human_pid: int = -10  # 人类王国的伪玩家ID
	var relations: Dictionary = DiplomacyManager.get_all_relations(human_pid)
	if relations.get(elf_fid, {}).get("allied", false):
		return  # 已结盟
	# 人类向精灵提供贡品
	if GameManager.get_current_turn() % 3 == 0:
		EventBus.message_log.emit("[color=orange][人类外交] 天城王朝向银月议庭派遣使节，寻求军事同盟。[/color]")
		DiplomacyManager.improve_relation(human_pid, elf_fid, 15)


func _try_arms_trade_with_mage() -> void:
	## 威胁 ≥ 30 时向法师公会输送铁矿（触发 DiplomacyManager 的军火交易）
	var threat: int = ThreatManager.get_threat() if ThreatManager != null else 0
	if threat >= 30 and DiplomacyManager != null:
		DiplomacyManager.process_ai_trade_routes(threat)


func _try_warn_player(player_id: int) -> void:
	## 对玩家发出外交警告（每5回合一次）
	if GameManager == null:
		return
	if GameManager.get_current_turn() % 5 != 0:
		return
	var warning_messages: Array = [
		"[color=yellow][人类外交] 女王千姬警告：若继续扩张，天城王朝将视之为宣战行为！[/color]",
		"[color=yellow][人类外交] 铁壁女伯爵冰华传信：北方边境已全面戒备，请勿轻举妄动！[/color]",
		"[color=yellow][人类外交] 圣殿骑士团长凛发出警告：骑士团已做好出击准备！[/color]",
	]
	var msg_idx: int = (GameManager.get_current_turn() / 5) % warning_messages.size()
	EventBus.message_log.emit(warning_messages[msg_idx])


func _try_kouyou_contact(player_id: int) -> void:
	## 红叶接触玩家（威胁 40+，威望 ≥ 30，一次性）
	if _kouyou_contacted:
		return
	var threat: int = ThreatManager.get_threat() if ThreatManager != null else 0
	if threat < KOUYOU_CONTACT_THREAT:
		return
	var prestige: int = ResourceManager.get_resource(player_id, "prestige") if ResourceManager != null else 0
	if prestige < KOUYOU_CONTACT_PRESTIGE:
		return
	_kouyou_contacted = true
	# 触发红叶接触事件（由事件系统处理）
	EventBus.message_log.emit("[color=cyan][外交事件] 银甲公爵夫人·红叶派遣密使，希望与您秘密会面……[/color]")
	if HumanKingdomEvents != null:
		HumanKingdomEvents.trigger_kouyou_contact_event(player_id)

# ═══════════════════════════════════════════════════════════
# Phase 3: 军事行动
# ═══════════════════════════════════════════════════════════

func _phase_military(player_id: int) -> void:
	_deploy_rin_if_ready(player_id)
	_coordinate_with_elves(player_id)
	_binghua_defend_north()


func _deploy_rin_if_ready(player_id: int) -> void:
	## 凛率圣殿骑士联军出击玩家最弱边境据点
	if _rin_deployed:
		return
	var threat: int = ThreatManager.get_threat() if ThreatManager != null else 0
	if threat < RIN_DEPLOY_THREAT:
		return
	# 找玩家最弱的边境据点
	var target_tile: int = _find_weakest_player_border_tile()
	if target_tile < 0:
		return
	_rin_deployed = true
	EventBus.message_log.emit("[color=red][人类王国] 圣殿骑士团长·凛率联军出击！目标：据点 #%d[/color]" % target_tile)
	EventBus.human_hero_deployed.emit("rin", target_tile)
	# 发起进攻（兵力：基础8 + 动员度加成）
	var assault_power: int = 8 + int(float(_mobilization - MOBILIZATION_WAR) / 10.0)
	_launch_assault(target_tile, assault_power, "rin")


func _find_weakest_player_border_tile() -> int:
	## 找与人类据点相邻的玩家据点中守军最少的
	if GameManager == null:
		return -1
	var candidates: Array = []
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) < 0:
			continue  # 不是玩家据点
		var tile_idx: int = tile["index"]
		if not GameManager.adjacency.has(tile_idx):
			continue
		# 检查是否与人类据点相邻
		for nb_idx in GameManager.adjacency[tile_idx]:
			if nb_idx >= GameManager.tiles.size():
				continue
			var nb: Dictionary = GameManager.tiles[nb_idx]
			if nb.get("light_faction", -1) == HUMAN_FACTION_ID and nb.get("owner_id", -1) < 0:
				candidates.append(tile)
				break
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a, b): return a.get("garrison", 0) < b.get("garrison", 0))
	return candidates[0]["index"]


func _launch_assault(target_tile: int, power: int, hero_id: String) -> void:
	## 发起进攻（创建临时攻击军队）
	if GameManager == null:
		return
	# 从最近的人类据点抽调兵力
	var source_tile: int = _find_nearest_human_tile_to(target_tile)
	if source_tile < 0:
		return
	var source: Dictionary = GameManager.tiles[source_tile]
	var available: int = maxi(0, source.get("garrison", 0) - 5)
	var actual_power: int = mini(power, available)
	if actual_power <= 0:
		return
	source["garrison"] -= actual_power
	# 触发战斗（由 GameManager 处理）
	if GameManager.has_method("action_light_faction_attack"):
		GameManager.action_light_faction_attack(source_tile, target_tile, actual_power, hero_id)
	else:
		# 降级处理：直接修改目标守军
		var target: Dictionary = GameManager.tiles[target_tile]
		target["garrison"] = maxi(0, target.get("garrison", 0) - actual_power)
		EventBus.message_log.emit("[人类王国] 圣殿骑士联军攻击据点 #%d，造成 %d 点伤害" % [target_tile, actual_power])


func _find_nearest_human_tile_to(target_idx: int) -> int:
	## 找距离目标最近的人类据点
	if GameManager == null:
		return -1
	var best_tile: int = -1
	var best_garrison: int = 0
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		var g: int = tile.get("garrison", 0)
		if g > best_garrison:
			best_garrison = g
			best_tile = tile["index"]
	return best_tile


func _coordinate_with_elves(player_id: int) -> void:
	## 威胁 60+ 时与精灵族协同出击
	var threat: int = ThreatManager.get_threat() if ThreatManager != null else 0
	if threat < 60:
		return
	if GameManager == null or GameManager.get_current_turn() % 4 != 0:
		return
	EventBus.message_log.emit("[color=orange][联军行动] 天城王朝与银月议庭联合远征队集结完毕！[/color]")
	# 精灵族在相邻人类边境据点提供支援
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		if _is_border_tile(tile):
			tile["garrison"] = tile.get("garrison", 0) + 2
			EventBus.message_log.emit("[联军行动] 精灵游侠增援人类边境 #%d (+2兵)" % tile["index"])
			break  # 每次只增援一个据点


func _binghua_defend_north() -> void:
	## 冰华守卫银冠要塞区域（不离开，只加固）
	if GameManager == null:
		return
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		# 银冠要塞：type = LIGHT_STRONGHOLD，且标记为北方
		if tile.get("type", -1) == GameManager.TileType.LIGHT_STRONGHOLD:
			var current: int = tile.get("garrison", 0)
			if current < 10:
				tile["garrison"] = 10
				EventBus.message_log.emit("[人类王国] 铁壁女伯爵·冰华加固银冠要塞守备（%d兵）" % 10)

# ═══════════════════════════════════════════════════════════
# Phase 4: 殊死抵抗（圣战）
# ═══════════════════════════════════════════════════════════

func _phase_crusade(player_id: int) -> void:
	_crusade_triggered = true
	EventBus.message_log.emit("[color=red][圣战号召] 女王千姬亲自发表演讲：'天城的子民们，为了光明而战！'[/color]")
	EventBus.message_log.emit("[color=red][圣战号召] 全体人类单位 ATK/DEF +10%，持续5回合！[/color]")
	# 触发圣战事件（由 HumanKingdomEvents 处理选项）
	if HumanKingdomEvents != null:
		HumanKingdomEvents.trigger_holy_crusade_event(player_id)
	# 强制动员所有贵族领主
	_force_noble_mobilization()
	# 凛+冰华双英雄出击
	if not _rin_deployed:
		var target: int = _find_weakest_player_border_tile()
		if target >= 0:
			_rin_deployed = true
			EventBus.human_hero_deployed.emit("rin", target)
			EventBus.human_hero_deployed.emit("binghua", target)
			_launch_assault(target, 20, "rin_binghua")


func _force_noble_mobilization() -> void:
	## 圣战时强制所有人类据点守军补充到最大值
	if GameManager == null:
		return
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		var cap: int = tile.get("garrison_cap", 10)
		tile["garrison"] = cap
	EventBus.message_log.emit("[color=red][圣战] 贵族领主全面动员，所有据点守军补满！[/color]")

# ═══════════════════════════════════════════════════════════
# Phase 5: 特色事件检查
# ═══════════════════════════════════════════════════════════

func _check_special_events(player_id: int) -> void:
	_check_noble_crisis(player_id)
	_check_binghua_last_stand(player_id)


func _check_noble_crisis(player_id: int) -> void:
	## 贵族内乱事件（威胁 < 60 时随机触发，冷却10回合）
	if _noble_crisis_cooldown > 0:
		return
	var threat: int = ThreatManager.get_threat() if ThreatManager != null else 0
	if threat >= MOBILIZATION_WAR:
		return  # 战时不内乱
	if randf() > 0.12:  # 12% 概率每回合触发
		return
	_noble_crisis_cooldown = 10
	var noble_names: Array = ["南境伯爵·枫", "东海侯·浪华", "西山公·铁心"]
	var noble: String = noble_names[randi() % noble_names.size()]
	EventBus.message_log.emit("[color=gray][内政事件] 贵族 %s 拒绝响应王都征召令，人类王国动员度暂时下降！[/color]" % noble)
	EventBus.human_noble_defected.emit(noble)
	# 动员度临时-10（下回合自然恢复）
	_mobilization = maxi(0, _mobilization - 10)
	if HumanKingdomEvents != null:
		HumanKingdomEvents.trigger_noble_crisis_event(player_id, noble)


func _check_binghua_last_stand(player_id: int) -> void:
	## 冰华死守令：银冠要塞被三面包围时触发
	if GameManager == null:
		return
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		if tile.get("type", -1) != GameManager.TileType.LIGHT_STRONGHOLD:
			continue
		# 检查是否三面被围
		var surrounded_sides: int = 0
		var tile_idx: int = tile["index"]
		if GameManager.adjacency.has(tile_idx):
			for nb_idx in GameManager.adjacency[tile_idx]:
				if nb_idx < GameManager.tiles.size():
					if GameManager.tiles[nb_idx].get("owner_id", -1) >= 0:
						surrounded_sides += 1
		if surrounded_sides >= 3:
			# 触发冰华死守令（一次性）
			if not tile.get("binghua_last_stand", false):
				tile["binghua_last_stand"] = true
				tile["garrison"] = tile.get("garrison", 0) + 5
				if LightFactionAI != null:
					LightFactionAI.repair_wall(tile_idx, 20)
				EventBus.message_log.emit("[color=red][铁壁死守] 冰华宣布死守令！银冠要塞城防×2，守军+5！[/color]")
				if HumanKingdomEvents != null:
					HumanKingdomEvents.trigger_binghua_last_stand_event(player_id, tile_idx)

# ═══════════════════════════════════════════════════════════
# 工具方法
# ═══════════════════════════════════════════════════════════

func get_mobilization_level() -> int:
	return _mobilization


func force_mobilize(amount: int) -> void:
	## 外部调用：强制增加动员度（用于事件触发）
	_mobilization = clampi(_mobilization + amount, 0, 100)
	EventBus.human_mobilization_changed.emit(_mobilization)


func is_rin_deployed() -> bool:
	return _rin_deployed


func reset_rin_deployment() -> void:
	## 凛被俘后重置出击状态（下次可再次出击）
	_rin_deployed = false


func get_human_border_tiles() -> Array:
	## 返回所有人类边境据点
	var result: Array = []
	if GameManager == null:
		return result
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		if _is_border_tile(tile):
			result.append(tile)
	return result


func _is_border_tile(tile: Dictionary) -> bool:
	## 判断据点是否为边境（相邻有玩家据点）
	var tile_idx: int = tile["index"]
	if not GameManager.adjacency.has(tile_idx):
		return false
	for nb_idx in GameManager.adjacency[tile_idx]:
		if nb_idx < GameManager.tiles.size():
			if GameManager.tiles[nb_idx].get("owner_id", -1) >= 0:
				return true
	return false
