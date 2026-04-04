## human_kingdom_events.gd — 人类王国专属事件链 (v1.1)
## 天城王朝七大事件：贵族内乱、女骑士巡逻、红叶合作、圣战号召、冰华死守、雪乃追随、女王演讲
##
## 依赖（均已在 project.godot 注册为 Autoload）：
##   EventBus, GameManager, ThreatManager, ResourceManager,
##   HeroSystem, HumanKingdomAI
##
## 调用方：HumanKingdomAI（条件触发）+ LightFactionAI.tick_light_factions()（每回合 tick）
extends Node

# ═══════════════════════════════════════════════════════════
# 事件 ID 常量
# ═══════════════════════════════════════════════════════════

const EVT_NOBLE_CRISIS      : String = "human_noble_crisis"
const EVT_KNIGHT_PATROL     : String = "human_knight_patrol"
const EVT_KOUYOU_CONTACT    : String = "human_kouyou_contact"
const EVT_HOLY_CRUSADE      : String = "human_holy_crusade"
const EVT_BINGHUA_LAST_STAND: String = "human_binghua_last_stand"
const EVT_SNOW_MESSENGER    : String = "human_snow_messenger"
const EVT_QUEEN_SPEECH      : String = "human_queen_speech"

const KNIGHT_PATROL_COOLDOWN: int = 3
const CRUSADE_BUFF_DURATION : int = 5

# ═══════════════════════════════════════════════════════════
# 状态
# ═══════════════════════════════════════════════════════════

var _triggered_once: Array = []
var _patrol_cooldown: int = 0
var _crusade_buff_turns: int = 0
var _crusade_buff_active: bool = false

# ═══════════════════════════════════════════════════════════
# 初始化 & 持久化
# ═══════════════════════════════════════════════════════════

func reset() -> void:
	_triggered_once.clear()
	_patrol_cooldown = 0
	_crusade_buff_turns = 0
	_crusade_buff_active = false


func to_save_data() -> Dictionary:
	return {
		"triggered_once": _triggered_once.duplicate(),
		"patrol_cooldown": _patrol_cooldown,
		"crusade_buff_turns": _crusade_buff_turns,
		"crusade_buff_active": _crusade_buff_active,
	}


func from_save_data(data: Dictionary) -> void:
	_triggered_once      = data.get("triggered_once", [])
	_patrol_cooldown     = data.get("patrol_cooldown", 0)
	_crusade_buff_turns  = data.get("crusade_buff_turns", 0)
	_crusade_buff_active = data.get("crusade_buff_active", false)

# ═══════════════════════════════════════════════════════════
# 每回合 tick（由 LightFactionAI.tick_light_factions() 调用）
# ═══════════════════════════════════════════════════════════

func tick(player_id: int) -> void:
	if _patrol_cooldown > 0:
		_patrol_cooldown -= 1
	_tick_crusade_buff()
	_check_knight_patrol(player_id)
	_check_queen_speech(player_id)


func _tick_crusade_buff() -> void:
	if not _crusade_buff_active:
		return
	_crusade_buff_turns -= 1
	if _crusade_buff_turns <= 0:
		_crusade_buff_active = false
		EventBus.message_log.emit("[color=gray][圣战] 圣战加成已结束，人类单位恢复正常属性。[/color]")


func _check_knight_patrol(player_id: int) -> void:
	if _patrol_cooldown > 0:
		return
	if ThreatManager.get_threat() < 30:
		return
	_patrol_cooldown = KNIGHT_PATROL_COOLDOWN
	trigger_knight_patrol_event(player_id)


func _check_queen_speech(player_id: int) -> void:
	if EVT_QUEEN_SPEECH in _triggered_once:
		return
	if ThreatManager.get_threat() < 70:
		return
	trigger_queen_speech_event(player_id)

# ═══════════════════════════════════════════════════════════
# 事件 A：贵族内乱
# ═══════════════════════════════════════════════════════════

func trigger_noble_crisis_event(player_id: int, noble_name: String) -> void:
	_log_separator()
	EventBus.message_log.emit("[color=yellow]【内政事件】贵族抗命[/color]")
	EventBus.message_log.emit("贵族 [color=white]%s[/color] 拒绝响应征召令。" % noble_name)
	EventBus.message_log.emit("")
	EventBus.message_log.emit("[A] 利用矛盾：花费30金，煽动其彻底叛离（动员度-20，守军-3）")
	EventBus.message_log.emit("[B] 静观其变：2回合后女王镇压，动员度自然恢复")
	_log_separator()
	_push_player_choice(EVT_NOBLE_CRISIS, player_id, {
		"noble_name": noble_name,
		"options": [
			{"id": "exploit", "label": "利用矛盾", "cost": {"gold": 30}},
			{"id": "wait",    "label": "静观其变",  "cost": {}},
		]
	})


func resolve_noble_crisis(player_id: int, choice: String, data: Dictionary) -> void:
	match choice:
		"exploit":
			if ResourceManager.can_afford(player_id, {"gold": 30}):
				ResourceManager.apply_delta(player_id, {"gold": -30})
				_reduce_nearest_human_garrison(3)
				HumanKingdomAI.force_mobilize(-20)
				EventBus.message_log.emit("[color=green][事件结果] %s 宣布独立！人类王国陷入短暂内乱。[/color]" % data.get("noble_name", ""))
			else:
				EventBus.message_log.emit("[color=red][事件结果] 金币不足，无法实施煽动计划。[/color]")
		"wait":
			EventBus.message_log.emit("[color=gray][事件结果] 静观其变。2回合后，女王镇压了叛乱，秩序恢复。[/color]")


func _reduce_nearest_human_garrison(amount: int) -> void:
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != 0:
			continue
		if tile.get("owner_id", -1) >= 0:
			continue
		if tile.get("type", -1) != GameManager.TileType.CORE_FORTRESS:
			continue
		tile["garrison"] = maxi(2, tile.get("garrison", 0) - amount)
		return

# ═══════════════════════════════════════════════════════════
# 事件 B：女骑士巡逻
# ═══════════════════════════════════════════════════════════

func trigger_knight_patrol_event(player_id: int) -> void:
	var threat: int = ThreatManager.get_threat()
	var patrol_power: int = 12 if threat >= 60 else 8
	var hero_label: String = "凛" if threat >= 60 else "圣殿骑士小队"
	_log_separator()
	EventBus.message_log.emit("[color=red]【光明方事件】女骑士巡逻[/color]")
	EventBus.message_log.emit("%s 率 %d 名骑士出现在您的边境附近！" % [hero_label, patrol_power])
	EventBus.message_log.emit("")
	EventBus.message_log.emit("[A] 迎战：与巡逻队正面交战（敌 %d 兵）" % patrol_power)
	EventBus.message_log.emit("[B] 撤退：放弃一处边境据点，威胁 -2")
	_log_separator()
	_push_player_choice(EVT_KNIGHT_PATROL, player_id, {
		"patrol_power": patrol_power,
		"hero_label": hero_label,
		"options": [
			{"id": "fight",   "label": "迎战"},
			{"id": "retreat", "label": "撤退"},
		]
	})


func resolve_knight_patrol(player_id: int, choice: String, data: Dictionary) -> void:
	match choice:
		"fight":
			var power: int = data.get("patrol_power", 8)
			EventBus.message_log.emit("[color=yellow][战斗开始] 与 %s 的巡逻队交战！[/color]" % data.get("hero_label", "骑士"))
			# 触发事件战斗（通过 EventBus 通知 GameManager）
			EventBus.event_combat_requested.emit(player_id, power, EVT_KNIGHT_PATROL)
		"retreat":
			_abandon_nearest_border_tile(player_id)
			ThreatManager.change_threat(-2)
			EventBus.message_log.emit("[color=gray][撤退] 放弃边境据点，威胁 -2。[/color]")


func _abandon_nearest_border_tile(player_id: int) -> void:
	var player_tiles: Array = GameManager.get_domestic_tiles(player_id)
	for tile in player_tiles:
		var tile_idx: int = tile["index"]
		if not GameManager.adjacency.has(tile_idx):
			continue
		for nb_idx in GameManager.adjacency[tile_idx]:
			if nb_idx >= GameManager.tiles.size():
				continue
			if GameManager.tiles[nb_idx].get("light_faction", -1) == 0:
				tile["owner_id"] = -1
				tile["garrison"] = 0
				EventBus.tile_lost.emit(player_id, tile_idx)
				EventBus.message_log.emit("[撤退] 放弃据点 #%d" % tile_idx)
				return

# ═══════════════════════════════════════════════════════════
# 事件 C：红叶的合作提案
# ═══════════════════════════════════════════════════════════

func trigger_kouyou_contact_event(player_id: int) -> void:
	if EVT_KOUYOU_CONTACT in _triggered_once:
		return
	_triggered_once.append(EVT_KOUYOU_CONTACT)
	_log_separator()
	EventBus.message_log.emit("[color=cyan]【外交事件】银甲公爵夫人来访[/color]")
	EventBus.message_log.emit("银甲公爵夫人·[color=white]红叶[/color] 的密使带来了一封信：")
	EventBus.message_log.emit('"与其在战场上消耗彼此，不如谈一笔对双方都有利的买卖。"')
	EventBus.message_log.emit("")
	EventBus.message_log.emit("[A] 接受合作：红叶加入您的阵营，人类王国动员度 -15")
	EventBus.message_log.emit("[B] 拒绝：维持敌对，人类动员度 +5，威望 +5")
	_log_separator()
	_push_player_choice(EVT_KOUYOU_CONTACT, player_id, {
		"options": [
			{"id": "accept", "label": "接受合作"},
			{"id": "reject", "label": "拒绝"},
		]
	})


func resolve_kouyou_contact(player_id: int, choice: String, _data: Dictionary) -> void:
	match choice:
		"accept":
			# recruit_hero 只接受 hero_id，不需要 player_id
			HeroSystem.recruit_hero("kouyou")
			HumanKingdomAI.force_mobilize(-15)
			EventBus.message_log.emit("[color=green][外交成功] 红叶带着她的骑兵卫队加入了您的阵营！[/color]")
		"reject":
			HumanKingdomAI.force_mobilize(5)
			ResourceManager.apply_delta(player_id, {"prestige": 5})
			EventBus.message_log.emit("[color=yellow][外交拒绝] 红叶冷冷一笑，转身离去。人类王国更加团结，动员度 +5。[/color]")

# ═══════════════════════════════════════════════════════════
# 事件 D：圣战号召
# ═══════════════════════════════════════════════════════════

func trigger_holy_crusade_event(player_id: int) -> void:
	if EVT_HOLY_CRUSADE in _triggered_once:
		return
	_triggered_once.append(EVT_HOLY_CRUSADE)
	_crusade_buff_active = true
	_crusade_buff_turns = CRUSADE_BUFF_DURATION
	# 通过 EventBus 通知 UI/GameManager 施加 buff
	EventBus.temporary_buff_applied.emit(0, "human_crusade_buff", CRUSADE_BUFF_DURATION)
	_log_separator()
	EventBus.message_log.emit("[color=red]【圣战号召】女王千姬的演讲[/color]")
	EventBus.message_log.emit('"天城的子民们！黑暗的浪潮已经逼近我们的家园，但只要圣殿的旗帜还在飘扬，我们就不会倒下！"')
	EventBus.message_log.emit("全体人类单位 ATK/DEF +1，持续 %d 回合！" % CRUSADE_BUFF_DURATION)
	EventBus.message_log.emit("")
	EventBus.message_log.emit("[A] 全力迎战：与圣战军队正面决战（敌 20 兵，凛+冰华）")
	EventBus.message_log.emit("[B] 战略撤退：放弃2处据点，威胁 -10")
	_log_separator()
	_push_player_choice(EVT_HOLY_CRUSADE, player_id, {
		"options": [
			{"id": "fight",   "label": "全力迎战"},
			{"id": "retreat", "label": "战略撤退"},
		]
	})


func resolve_holy_crusade(player_id: int, choice: String, _data: Dictionary) -> void:
	match choice:
		"fight":
			EventBus.message_log.emit("[color=red][圣战决战] 凛与冰华率20名精锐骑士向您的核心据点发动总攻！[/color]")
			EventBus.event_combat_requested.emit(player_id, 20, EVT_HOLY_CRUSADE)
		"retreat":
			_abandon_two_border_tiles(player_id)
			ThreatManager.change_threat(-10)
			EventBus.message_log.emit("[color=gray][战略撤退] 放弃了2处边境据点，圣战压力暂时缓解。威胁 -10。[/color]")


func _abandon_two_border_tiles(player_id: int) -> void:
	var player_tiles: Array = GameManager.get_domestic_tiles(player_id)
	var abandoned: int = 0
	for tile in player_tiles:
		if abandoned >= 2:
			break
		var tile_idx: int = tile["index"]
		if not GameManager.adjacency.has(tile_idx):
			continue
		for nb_idx in GameManager.adjacency[tile_idx]:
			if nb_idx >= GameManager.tiles.size():
				continue
			if GameManager.tiles[nb_idx].get("light_faction", -1) == 0:
				tile["owner_id"] = -1
				tile["garrison"] = 0
				abandoned += 1
				EventBus.tile_lost.emit(player_id, tile_idx)
				EventBus.message_log.emit("[撤退] 放弃据点 #%d" % tile_idx)
				break

# ═══════════════════════════════════════════════════════════
# 事件 E：冰华死守令
# ═══════════════════════════════════════════════════════════

func trigger_binghua_last_stand_event(player_id: int, fortress_tile: int) -> void:
	if EVT_BINGHUA_LAST_STAND in _triggered_once:
		return
	_triggered_once.append(EVT_BINGHUA_LAST_STAND)
	_log_separator()
	EventBus.message_log.emit("[color=red]【特殊事件】铁壁死守令[/color]")
	EventBus.message_log.emit("铁壁女伯爵·[color=white]冰华[/color] 面对三面包围，只说了一句话：")
	EventBus.message_log.emit('"此地，我守。"')
	EventBus.message_log.emit("银冠要塞城防×2，守军 +5！")
	EventBus.message_log.emit("")
	EventBus.message_log.emit("[A] 强攻：正面突破冰华的防线（城防加倍，难度大幅提升）")
	EventBus.message_log.emit("[B] 围困：切断补给，3回合后自动陷落（冰华被俘）")
	_log_separator()
	_push_player_choice(EVT_BINGHUA_LAST_STAND, player_id, {
		"fortress_tile": fortress_tile,
		"options": [
			{"id": "assault", "label": "强攻"},
			{"id": "siege",   "label": "围困"},
		]
	})


func resolve_binghua_last_stand(player_id: int, choice: String, data: Dictionary) -> void:
	var fortress_tile: int = data.get("fortress_tile", -1)
	match choice:
		"assault":
			EventBus.message_log.emit("[color=red][强攻] 您的军队向银冠要塞发动猛攻！冰华亲自上阵迎战……[/color]")
			EventBus.event_combat_requested.emit(player_id, 15, EVT_BINGHUA_LAST_STAND)
		"siege":
			EventBus.message_log.emit("[color=gray][围困] 切断了银冠要塞的补给线。守军每回合 -3，3回合后陷落……[/color]")
			if fortress_tile >= 0 and fortress_tile < GameManager.tiles.size():
				GameManager.tiles[fortress_tile]["siege_countdown"] = 3
				GameManager.tiles[fortress_tile]["siege_drain"] = 3

# ═══════════════════════════════════════════════════════════
# 事件 F：雪乃追随（凛被俘后自动触发）
# ═══════════════════════════════════════════════════════════

func trigger_snow_messenger_event(player_id: int) -> void:
	if EVT_SNOW_MESSENGER in _triggered_once:
		return
	_triggered_once.append(EVT_SNOW_MESSENGER)
	_log_separator()
	EventBus.message_log.emit("[color=cyan]【角色事件】王宫神官的追随[/color]")
	EventBus.message_log.emit("王宫神官·[color=white]雪乃[/color] 独自来到您的营地：")
	EventBus.message_log.emit('"凛大人在哪里，我就在哪里。请允许我留下来……照顾她。"')
	EventBus.message_log.emit("雪乃自动加入您的阵营！（凛的好感度获取速度 +50%）")
	_log_separator()
	HeroSystem.recruit_hero("yukino")
	EventBus.message_log.emit("[color=green][角色加入] 雪乃加入了您的阵营！[/color]")

# ═══════════════════════════════════════════════════════════
# 事件 G：女王演讲（圣战前置）
# ═══════════════════════════════════════════════════════════

func trigger_queen_speech_event(player_id: int) -> void:
	if EVT_QUEEN_SPEECH in _triggered_once:
		return
	_triggered_once.append(EVT_QUEEN_SPEECH)
	_log_separator()
	EventBus.message_log.emit("[color=yellow]【预警事件】女王的宣言[/color]")
	EventBus.message_log.emit("女王·[color=white]千姬[/color] 在王都广场发表公开宣言：")
	EventBus.message_log.emit('"黑暗的势力已经逼近我们的家园。天城王朝的子民们，是时候拿起武器了。"')
	EventBus.message_log.emit("[警告] 威胁值再提升10点，将触发圣战号召！")
	_log_separator()
	HumanKingdomAI.force_mobilize(20)

# ═══════════════════════════════════════════════════════════
# 统一事件解析入口（供 UI 层调用）
# ═══════════════════════════════════════════════════════════

func resolve_event(event_id: String, player_id: int, choice: String, data: Dictionary) -> void:
	match event_id:
		EVT_NOBLE_CRISIS:
			resolve_noble_crisis(player_id, choice, data)
		EVT_KNIGHT_PATROL:
			resolve_knight_patrol(player_id, choice, data)
		EVT_KOUYOU_CONTACT:
			resolve_kouyou_contact(player_id, choice, data)
		EVT_HOLY_CRUSADE:
			resolve_holy_crusade(player_id, choice, data)
		EVT_BINGHUA_LAST_STAND:
			resolve_binghua_last_stand(player_id, choice, data)
		_:
			push_warning("HumanKingdomEvents: 未知事件 ID: %s" % event_id)

# ═══════════════════════════════════════════════════════════
# 查询接口
# ═══════════════════════════════════════════════════════════

func is_crusade_buff_active() -> bool:
	return _crusade_buff_active


func get_crusade_buff_turns_remaining() -> int:
	return _crusade_buff_turns


func is_event_triggered(event_id: String) -> bool:
	return event_id in _triggered_once

# ═══════════════════════════════════════════════════════════
# 内部工具
# ═══════════════════════════════════════════════════════════

func _push_player_choice(event_id: String, player_id: int, event_data: Dictionary) -> void:
	event_data["event_id"] = event_id
	event_data["player_id"] = player_id
	EventBus.human_event_choice_requested.emit(event_id, player_id, event_data)


func _log_separator() -> void:
	EventBus.message_log.emit("═══════════════════════════════")
