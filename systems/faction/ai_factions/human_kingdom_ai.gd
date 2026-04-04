## human_kingdom_ai.gd — 人类王国 AI 行为系统 (v1.1)
## 天城王朝：防守反击型 AI，城防依赖，英雄驱动，官僚迟缓
##
## 依赖（均已在 project.godot 注册为 Autoload）：
##   EventBus, GameManager, ThreatManager, LightFactionAI,
##   ResourceManager, DiplomacyManager, HumanKingdomEvents
##
## 调用方：LightFactionAI.tick_light_factions()（每回合自动调用）
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")

# ═══════════════════════════════════════════════════════════
# 常量
# ═══════════════════════════════════════════════════════════

const HUMAN_FACTION_ID: int = 0  # FactionData.LightFaction.HUMAN_KINGDOM

## 动员度阈值
const MOBILIZATION_ALERT: int    = 30
const MOBILIZATION_WAR: int      = 60
const MOBILIZATION_CRUSADE: int  = 80

## 城墙
const WALL_REGEN_BONUS: int      = 3   # 人类专属额外城墙恢复
const WALL_REPAIR_THRESHOLD: int = 15  # 低于此值时紧急修缮
const WALL_REPAIR_AMOUNT: int    = 8

## 边境增援
const REINFORCE_MIN_INTERIOR: int = 4
const REINFORCE_BATCH: int        = 2

## 英雄出击阈值
const RIN_DEPLOY_THREAT: int        = 60
const KOUYOU_CONTACT_THREAT: int    = 40
const KOUYOU_CONTACT_PRESTIGE: int  = 30

## 动员度计算系数
const MOBILIZATION_THREAT_MULT: float = 1.1
const MOBILIZATION_ATTACK_BONUS: int  = 5

## 王都最低守备
const CAPITAL_MIN_GARRISON_PEACE: int = 8
const CAPITAL_MIN_GARRISON_WAR: int   = 12

# ═══════════════════════════════════════════════════════════
# 状态变量
# ═══════════════════════════════════════════════════════════

var _mobilization: int = 0
var _turns_under_attack: int = 0
var _rin_deployed: bool = false
var _kouyou_contacted: bool = false
var _crusade_triggered: bool = false
var _noble_crisis_cooldown: int = 0
var _last_player_tile_count: int = 0

# ═══════════════════════════════════════════════════════════
# 初始化 & 持久化
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
# 主入口：每回合由 LightFactionAI.tick_light_factions() 调用
# ═══════════════════════════════════════════════════════════

func tick(player_id: int) -> void:
	_update_mobilization()
	_check_attack_status()
	_tick_cooldowns()

	_phase_defense(player_id)

	if _mobilization >= MOBILIZATION_ALERT:
		_phase_diplomacy(player_id)

	if _mobilization >= MOBILIZATION_WAR:
		_phase_military(player_id)

	if _mobilization >= MOBILIZATION_CRUSADE and not _crusade_triggered:
		_phase_crusade(player_id)

	_check_special_events(player_id)

# ═══════════════════════════════════════════════════════════
# Phase 0: 状态评估
# ═══════════════════════════════════════════════════════════

func _update_mobilization() -> void:
	var threat: int = ThreatManager.get_threat()
	var raw: float = float(threat) * MOBILIZATION_THREAT_MULT
	raw += float(_turns_under_attack) * MOBILIZATION_ATTACK_BONUS
	_mobilization = clampi(int(raw), 0, 100)
	EventBus.human_mobilization_changed.emit(_mobilization)


func _check_attack_status() -> void:
	var current: int = _count_player_tiles_adjacent_to_human()
	if current > _last_player_tile_count:
		_turns_under_attack += 1
	else:
		_turns_under_attack = maxi(0, _turns_under_attack - 1)
	_last_player_tile_count = current


func _count_player_tiles_adjacent_to_human() -> int:
	var count: int = 0
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		var tile_idx: int = tile["index"]
		if not GameManager.adjacency.has(tile_idx):
			continue
		for nb_idx in GameManager.adjacency[tile_idx]:
			if nb_idx < GameManager.tiles.size():
				if GameManager.tiles[nb_idx].get("owner_id", -1) >= 0:
					count += 1
					break
	return count


func _tick_cooldowns() -> void:
	if _noble_crisis_cooldown > 0:
		_noble_crisis_cooldown -= 1

# ═══════════════════════════════════════════════════════════
# Phase 1: 防御
# ═══════════════════════════════════════════════════════════

func _phase_defense(_player_id: int) -> void:
	_regen_and_repair_walls()
	_reinforce_border_tiles()
	_guard_capital()


func _regen_and_repair_walls() -> void:
	## 人类城墙额外恢复（在 LightFactionAI.regen_walls 基础上叠加）
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
		# 额外恢复
		LightFactionAI.repair_wall(tile_idx, WALL_REGEN_BONUS)
		# 紧急修缮
		if wall_hp < WALL_REPAIR_THRESHOLD:
			LightFactionAI.repair_wall(tile_idx, WALL_REPAIR_AMOUNT)
			EventBus.message_log.emit("[人类王国] 紧急修缮城墙 #%d（城防 %d → %d）" % [
				tile_idx, wall_hp, LightFactionAI.get_wall_hp(tile_idx)])


func _reinforce_border_tiles() -> void:
	var border_tiles: Array = []
	var interior_tiles: Array = []
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		if _is_border_tile(tile):
			border_tiles.append(tile)
		else:
			interior_tiles.append(tile)
	if border_tiles.is_empty() or interior_tiles.is_empty():
		return
	border_tiles.sort_custom(func(a, b): return a.get("garrison", 0) < b.get("garrison", 0))
	var weakest_border: Dictionary = border_tiles[0]
	for interior in interior_tiles:
		var g: int = interior.get("garrison", 0)
		if g <= REINFORCE_MIN_INTERIOR:
			continue
		if weakest_border.get("garrison", 0) >= g:
			continue
		var transfer: int = mini(REINFORCE_BATCH, g - REINFORCE_MIN_INTERIOR)
		interior["garrison"] -= transfer
		weakest_border["garrison"] += transfer
		EventBus.message_log.emit("[人类王国] 内部守军增援边境 #%d (+%d兵)" % [
			weakest_border["index"], transfer])
		break


func _guard_capital() -> void:
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("type", -1) != GameManager.TileType.CORE_FORTRESS:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		var min_g: int = CAPITAL_MIN_GARRISON_WAR if _mobilization >= MOBILIZATION_WAR else CAPITAL_MIN_GARRISON_PEACE
		if tile.get("garrison", 0) < min_g:
			tile["garrison"] = min_g
			EventBus.message_log.emit("[人类王国] 圣殿骑士团加强王都守备（%d兵）" % min_g)

# ═══════════════════════════════════════════════════════════
# Phase 2: 外交
# ═══════════════════════════════════════════════════════════

func _phase_diplomacy(player_id: int) -> void:
	_try_ally_with_elves()
	_try_arms_trade_with_mage()
	_try_warn_player()
	_try_kouyou_contact(player_id)


func _try_ally_with_elves() -> void:
	var elf_fid: int = FactionData.LightFaction.HIGH_ELVES
	var human_pid: int = -10  # 人类王国的伪玩家ID
	var relations: Dictionary = DiplomacyManager.get_all_relations(human_pid)
	if relations.get(elf_fid, {}).get("allied", false):
		return
	if GameManager.get_current_turn() % 3 == 0:
		EventBus.message_log.emit("[color=orange][人类外交] 天城王朝向银月议庭派遣使节，寻求军事同盟。[/color]")
		DiplomacyManager.improve_relation(human_pid, elf_fid, 15)


func _try_arms_trade_with_mage() -> void:
	## v4.7 fix: process_ai_trade_routes is now called once per turn by GameManager (Phase 5e4b).
	## This function is intentionally a no-op here to avoid double-calling the route processor.
	pass  # Handled by GameManager._process_turn() Phase 5e4b


func _try_warn_player() -> void:
	if GameManager.get_current_turn() % 5 != 0:
		return
	var warning_messages: Array = [
		"[color=yellow][人类外交] 女王千姬警告：若继续扩张，天城王朝将视之为宣战行为！[/color]",
		"[color=yellow][人类外交] 铁壁女伯爵冰华传信：北方边境已全面戒备，请勿轻举妄动！[/color]",
		"[color=yellow][人类外交] 圣殿骑士团长凛发出警告：骑士团已做好出击准备！[/color]",
	]
	var idx: int = (GameManager.get_current_turn() / 5) % warning_messages.size()
	EventBus.message_log.emit(warning_messages[idx])


func _try_kouyou_contact(player_id: int) -> void:
	if _kouyou_contacted:
		return
	if ThreatManager.get_threat() < KOUYOU_CONTACT_THREAT:
		return
	var prestige: int = ResourceManager.get_resource(player_id, "prestige")
	if prestige < KOUYOU_CONTACT_PRESTIGE:
		return
	_kouyou_contacted = true
	EventBus.message_log.emit("[color=cyan][外交事件] 银甲公爵夫人·红叶派遣密使，希望与您秘密会面……[/color]")
	HumanKingdomEvents.trigger_kouyou_contact_event(player_id)

# ═══════════════════════════════════════════════════════════
# Phase 3: 军事
# ═══════════════════════════════════════════════════════════

func _phase_military(player_id: int) -> void:
	_deploy_rin_if_ready(player_id)
	_coordinate_with_elves()
	_binghua_defend_north()


func _deploy_rin_if_ready(_player_id: int) -> void:
	if _rin_deployed:
		return
	if ThreatManager.get_threat() < RIN_DEPLOY_THREAT:
		return
	var target_tile: int = _find_weakest_player_border_tile()
	if target_tile < 0:
		return
	_rin_deployed = true
	EventBus.message_log.emit("[color=red][人类王国] 圣殿骑士团长·凛率联军出击！目标：据点 #%d[/color]" % target_tile)
	EventBus.human_hero_deployed.emit("rin", target_tile)
	var assault_power: int = 8 + int(float(_mobilization - MOBILIZATION_WAR) / 10.0)
	_launch_assault(target_tile, assault_power)


func _find_weakest_player_border_tile() -> int:
	var candidates: Array = []
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) < 0:
			continue
		var tile_idx: int = tile["index"]
		if not GameManager.adjacency.has(tile_idx):
			continue
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


func _launch_assault(target_tile_idx: int, power: int) -> void:
	## 从最近的人类据点抽调兵力，直接削减玩家据点守军（与 human_kingdom_action 一致的方式）
	var source_idx: int = _find_nearest_human_tile_to(target_tile_idx)
	if source_idx < 0:
		return
	var source: Dictionary = GameManager.tiles[source_idx]
	var available: int = maxi(0, source.get("garrison", 0) - 5)
	var actual_power: int = mini(power, available)
	if actual_power <= 0:
		return
	source["garrison"] -= actual_power
	var target: Dictionary = GameManager.tiles[target_tile_idx]
	# 削减玩家守军（模拟进攻伤害，1:1 交换）
	var damage: int = actual_power
	target["garrison"] = maxi(0, target.get("garrison", 0) - damage)
	EventBus.message_log.emit("[人类王国] 圣殿骑士联军攻击据点 #%d，造成 %d 点伤害（剩余守军：%d）" % [
		target_tile_idx, damage, target.get("garrison", 0)])
	# 若玩家守军归零，据点被光明方收复
	if target.get("garrison", 0) <= 0:
		target["owner_id"] = -1
		EventBus.tile_lost.emit(0, target_tile_idx)
		EventBus.message_log.emit("[color=red][人类王国] 据点 #%d 被圣殿骑士团收复！[/color]" % target_tile_idx)


func _find_nearest_human_tile_to(_target_idx: int) -> int:
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


func _coordinate_with_elves() -> void:
	if ThreatManager.get_threat() < 60:
		return
	if GameManager.get_current_turn() % 4 != 0:
		return
	EventBus.message_log.emit("[color=orange][联军行动] 天城王朝与银月议庭联合远征队集结完毕！[/color]")
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
			break


func _binghua_defend_north() -> void:
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		if tile.get("type", -1) == GameManager.TileType.LIGHT_STRONGHOLD:
			if tile.get("garrison", 0) < 10:
				tile["garrison"] = 10
				EventBus.message_log.emit("[人类王国] 铁壁女伯爵·冰华加固银冠要塞守备（10兵）")

# ═══════════════════════════════════════════════════════════
# Phase 4: 圣战
# ═══════════════════════════════════════════════════════════

func _phase_crusade(player_id: int) -> void:
	_crusade_triggered = true
	EventBus.message_log.emit("[color=red][圣战号召] 女王千姬亲自发表演讲：'天城的子民们，为了光明而战！'[/color]")
	EventBus.message_log.emit("[color=red][圣战号召] 全体人类单位 ATK/DEF +10%，持续5回合！[/color]")
	HumanKingdomEvents.trigger_holy_crusade_event(player_id)
	_force_noble_mobilization()
	if not _rin_deployed:
		var target: int = _find_weakest_player_border_tile()
		if target >= 0:
			_rin_deployed = true
			EventBus.human_hero_deployed.emit("rin", target)
			EventBus.human_hero_deployed.emit("binghua", target)
			_launch_assault(target, 20)


func _force_noble_mobilization() -> void:
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
# Phase 5: 特色事件
# ═══════════════════════════════════════════════════════════

func _check_special_events(player_id: int) -> void:
	_check_noble_crisis(player_id)
	_check_binghua_last_stand(player_id)


func _check_noble_crisis(player_id: int) -> void:
	if _noble_crisis_cooldown > 0:
		return
	if ThreatManager.get_threat() >= MOBILIZATION_WAR:
		return
	if randf() > 0.12:
		return
	_noble_crisis_cooldown = 10
	var noble_names: Array = ["南境伯爵·枫", "东海侯·浪华", "西山公·铁心"]
	var noble: String = noble_names[randi() % noble_names.size()]
	EventBus.message_log.emit("[color=gray][内政事件] 贵族 %s 拒绝响应王都征召令，人类王国动员度暂时下降！[/color]" % noble)
	EventBus.human_noble_defected.emit(noble)
	_mobilization = maxi(0, _mobilization - 10)
	HumanKingdomEvents.trigger_noble_crisis_event(player_id, noble)


func _check_binghua_last_stand(player_id: int) -> void:
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != HUMAN_FACTION_ID:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		if tile.get("type", -1) != GameManager.TileType.LIGHT_STRONGHOLD:
			continue
		var surrounded_sides: int = 0
		var tile_idx: int = tile["index"]
		if GameManager.adjacency.has(tile_idx):
			for nb_idx in GameManager.adjacency[tile_idx]:
				if nb_idx < GameManager.tiles.size():
					if GameManager.tiles[nb_idx].get("owner_id", -1) >= 0:
						surrounded_sides += 1
		if surrounded_sides >= 3 and not tile.get("binghua_last_stand", false):
			tile["binghua_last_stand"] = true
			tile["garrison"] = tile.get("garrison", 0) + 5
			LightFactionAI.repair_wall(tile_idx, 20)
			EventBus.message_log.emit("[color=red][铁壁死守] 冰华宣布死守令！银冠要塞城防×2，守军+5！[/color]")
			HumanKingdomEvents.trigger_binghua_last_stand_event(player_id, tile_idx)

# ═══════════════════════════════════════════════════════════
# 公共接口
# ═══════════════════════════════════════════════════════════

func get_mobilization_level() -> int:
	return _mobilization


func force_mobilize(amount: int) -> void:
	_mobilization = clampi(_mobilization + amount, 0, 100)
	EventBus.human_mobilization_changed.emit(_mobilization)


func is_rin_deployed() -> bool:
	return _rin_deployed


func reset_rin_deployment() -> void:
	_rin_deployed = false


func get_human_border_tiles() -> Array:
	var result: Array = []
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
	var tile_idx: int = tile["index"]
	if not GameManager.adjacency.has(tile_idx):
		return false
	for nb_idx in GameManager.adjacency[tile_idx]:
		if nb_idx < GameManager.tiles.size():
			if GameManager.tiles[nb_idx].get("owner_id", -1) >= 0:
				return true
	return false
