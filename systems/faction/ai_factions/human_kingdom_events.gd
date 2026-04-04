## human_kingdom_events.gd — 人类王国专属事件链 (v1.0)
## 天城王朝五大事件链：贵族内乱、女骑士巡逻、红叶合作、圣战号召、冰华死守
## 依赖: event_bus.gd, resource_manager.gd, hero_system.gd, human_kingdom_ai.gd
extends Node

# ═══════════════════════════════════════════════════════════
# 事件 ID 常量
# ═══════════════════════════════════════════════════════════

const EVT_NOBLE_CRISIS      : String = "human_noble_crisis"
const EVT_KNIGHT_PATROL     : String = "human_knight_patrol"
const EVT_KOUYOU_CONTACT    : String = "human_kouyou_contact"
const EVT_HOLY_CRUSADE      : String = "human_holy_crusade"
const EVT_BINGHUA_LAST_STAND: String = "human_binghua_last_stand"
const EVT_SNOW_MESSENGER    : String = "human_snow_messenger"   # 雪乃追随事件
const EVT_QUEEN_SPEECH      : String = "human_queen_speech"     # 女王演讲（圣战前置）

## 骑士巡逻事件冷却（回合）
const KNIGHT_PATROL_COOLDOWN: int = 3

## 圣战全军 buff 持续回合
const CRUSADE_BUFF_DURATION: int = 5

## 圣战 ATK/DEF 加成
const CRUSADE_STAT_BONUS: int = 1  # +1 ATK/DEF（对应 10%）

# ═══════════════════════════════════════════════════════════
# 状态
# ═══════════════════════════════════════════════════════════

## 已触发的一次性事件集合
var _triggered_once: Array = []

## 骑士巡逻冷却
var _patrol_cooldown: int = 0

## 圣战 buff 剩余回合
var _crusade_buff_turns: int = 0

## 圣战 buff 是否激活
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
	_triggered_once     = data.get("triggered_once", [])
	_patrol_cooldown    = data.get("patrol_cooldown", 0)
	_crusade_buff_turns = data.get("crusade_buff_turns", 0)
	_crusade_buff_active = data.get("crusade_buff_active", false)

# ═══════════════════════════════════════════════════════════
# 每回合 tick（由 HumanKingdomAI 或 GameManager 调用）
# ═══════════════════════════════════════════════════════════

func tick(player_id: int) -> void:
	if _patrol_cooldown > 0:
		_patrol_cooldown -= 1
	_tick_crusade_buff()
	_check_knight_patrol(player_id)


func _tick_crusade_buff() -> void:
	if not _crusade_buff_active:
		return
	_crusade_buff_turns -= 1
	if _crusade_buff_turns <= 0:
		_crusade_buff_active = false
		EventBus.message_log.emit("[color=gray][圣战] 圣战加成已结束，人类单位恢复正常属性。[/color]")


func _check_knight_patrol(player_id: int) -> void:
	## 女骑士巡逻：威胁 ≥ 30，每3回合触发一次
	if _patrol_cooldown > 0:
		return
	var threat: int = ThreatManager.get_threat() if ThreatManager != null else 0
	if threat < 30:
		return
	_patrol_cooldown = KNIGHT_PATROL_COOLDOWN
	trigger_knight_patrol_event(player_id)

# ═══════════════════════════════════════════════════════════
# 事件 A：贵族内乱
# ═══════════════════════════════════════════════════════════

## 触发贵族内乱事件（由 HumanKingdomAI 调用）
func trigger_noble_crisis_event(player_id: int, noble_name: String) -> void:
	EventBus.message_log.emit("═══════════════════════════════")
	EventBus.message_log.emit("[color=yellow]【内政事件】贵族抗命[/color]")
	EventBus.message_log.emit("贵族 [color=white]%s[/color] 以"王都无权干涉领地内政"为由，拒绝响应征召令。" % noble_name)
	EventBus.message_log.emit("女王千姬正在考虑如何处置……")
	EventBus.message_log.emit("")
	EventBus.message_log.emit("[A] 利用矛盾：向该贵族秘密输送金币，煽动其彻底叛离王国")
	EventBus.message_log.emit("    → 效果：人类王国动员度 -20，该贵族领地守军 -3")
	EventBus.message_log.emit("[B] 静观其变：等待女王处置结果")
	EventBus.message_log.emit("    → 效果：2回合后人类王国恢复正常动员度")
	EventBus.message_log.emit("═══════════════════════════════")
	# 注册待处理事件（玩家选择由 UI 层处理）
	_push_player_choice(EVT_NOBLE_CRISIS, player_id, {
		"noble_name": noble_name,
		"options": [
			{"id": "exploit", "label": "利用矛盾", "cost": {"gold": 30}},
			{"id": "wait",    "label": "静观其变",  "cost": {}},
		]
	})


## 处理贵族内乱事件的玩家选择
func resolve_noble_crisis(player_id: int, choice: String, data: Dictionary) -> void:
	match choice:
		"exploit":
			if ResourceManager != null and ResourceManager.can_afford(player_id, {"gold": 30}):
				ResourceManager.apply_delta(player_id, {"gold": -30})
				# 该贵族领地守军减少
				_reduce_nearest_human_garrison(3)
				if HumanKingdomAI != null:
					HumanKingdomAI.force_mobilize(-20)
				EventBus.message_log.emit("[color=green][事件结果] 您的金币发挥了作用——%s 宣布独立！人类王国陷入短暂内乱。[/color]" % data.get("noble_name", ""))
			else:
				EventBus.message_log.emit("[color=red][事件结果] 金币不足，无法实施煽动计划。[/color]")
		"wait":
			EventBus.message_log.emit("[color=gray][事件结果] 您选择静观其变。2回合后，女王镇压了叛乱，人类王国秩序恢复。[/color]")


func _reduce_nearest_human_garrison(amount: int) -> void:
	if GameManager == null:
		return
	for tile in GameManager.tiles:
		if tile == null:
			continue
		if tile.get("light_faction", -1) != 0:  # HUMAN_FACTION_ID
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
	var threat: int = ThreatManager.get_threat() if ThreatManager != null else 0
	# 根据威胁等级决定巡逻规模
	var patrol_power: int = 8 if threat < 60 else 12
	var hero_label: String = "凛" if threat >= 60 else "圣殿骑士小队"
	EventBus.message_log.emit("═══════════════════════════════")
	EventBus.message_log.emit("[color=red]【光明方事件】女骑士巡逻[/color]")
	EventBus.message_log.emit("%s 率 %d 名骑士出现在您的边境附近！" % [hero_label, patrol_power])
	EventBus.message_log.emit("")
	EventBus.message_log.emit("[A] 迎战：与巡逻队正面交战")
	EventBus.message_log.emit("    → 战斗（敌 %d 兵，%s 参战）" % [patrol_power, hero_label])
	EventBus.message_log.emit("[B] 撤退：放弃一处边境据点，避免交战")
	EventBus.message_log.emit("    → 弃守最近边境据点，威胁 -2")
	EventBus.message_log.emit("═══════════════════════════════")
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
			EventBus.message_log.emit("[color=yellow][战斗开始] 与 %s 的巡逻队交战！（敌方兵力：%d）[/color]" % [
				data.get("hero_label", "骑士"), power])
			# 触发战斗（由 GameManager 处理）
			if GameManager != null and GameManager.has_method("action_trigger_patrol_battle"):
				GameManager.action_trigger_patrol_battle(player_id, power, data.get("hero_label", ""))
			else:
				# 降级：直接扣除玩家守军
				EventBus.message_log.emit("[战斗] 巡逻队对您的边境据点发动攻击，造成 %d 点伤害。" % int(power * 0.6))
		"retreat":
			_abandon_nearest_border_tile(player_id)
			if ThreatManager != null:
				ThreatManager.add_threat(-2)
			EventBus.message_log.emit("[color=gray][撤退] 您放弃了边境据点，避免了与骑士团的正面冲突。威胁 -2。[/color]")


func _abandon_nearest_border_tile(player_id: int) -> void:
	if GameManager == null:
		return
	var player_tiles: Array = GameManager.get_domestic_tiles(player_id)
	if player_tiles.is_empty():
		return
	# 找与人类据点相邻的玩家据点
	for tile in player_tiles:
		var tile_idx: int = tile["index"]
		if not GameManager.adjacency.has(tile_idx):
			continue
		for nb_idx in GameManager.adjacency[tile_idx]:
			if nb_idx >= GameManager.tiles.size():
				continue
			if GameManager.tiles[nb_idx].get("light_faction", -1) == 0:
				# 放弃该据点
				tile["owner_id"] = -1
				tile["garrison"] = 0
				EventBus.message_log.emit("[撤退] 放弃据点 #%d" % tile_idx)
				return

# ═══════════════════════════════════════════════════════════
# 事件 C：红叶的合作提案
# ═══════════════════════════════════════════════════════════

func trigger_kouyou_contact_event(player_id: int) -> void:
	if EVT_KOUYOU_CONTACT in _triggered_once:
		return
	_triggered_once.append(EVT_KOUYOU_CONTACT)
	EventBus.message_log.emit("═══════════════════════════════")
	EventBus.message_log.emit("[color=cyan]【外交事件】银甲公爵夫人来访[/color]")
	EventBus.message_log.emit("银甲公爵夫人·[color=white]红叶[/color] 的密使带来了一封信：")
	EventBus.message_log.emit("")
	EventBus.message_log.emit('"您的势力已引起了我的注意。我是个务实的人——')
	EventBus.message_log.emit(' 与其在战场上消耗彼此，不如谈一笔对双方都有利的买卖。"')
	EventBus.message_log.emit("")
	EventBus.message_log.emit("[A] 接受合作：红叶加入您的阵营（外交招募）")
	EventBus.message_log.emit("    → 红叶加入，人类王国动员度 -15（内部分裂）")
	EventBus.message_log.emit("    → 解锁红叶专属任务链")
	EventBus.message_log.emit("[B] 拒绝：维持敌对关系")
	EventBus.message_log.emit("    → 人类王国动员度 +5（团结一致），威望 +5")
	EventBus.message_log.emit("═══════════════════════════════")
	_push_player_choice(EVT_KOUYOU_CONTACT, player_id, {
		"options": [
			{"id": "accept", "label": "接受合作"},
			{"id": "reject", "label": "拒绝"},
		]
	})


func resolve_kouyou_contact(player_id: int, choice: String, _data: Dictionary) -> void:
	match choice:
		"accept":
			# 红叶加入
			if HeroSystem != null and HeroSystem.has_method("recruit_hero"):
				HeroSystem.recruit_hero(player_id, "kouyou")
			if HumanKingdomAI != null:
				HumanKingdomAI.force_mobilize(-15)
			EventBus.message_log.emit("[color=green][外交成功] 红叶带着她的骑兵卫队加入了您的阵营！[/color]")
			EventBus.message_log.emit("[color=gray][内部影响] 人类王国因公爵夫人叛离而陷入短暂混乱，动员度 -15。[/color]")
		"reject":
			if HumanKingdomAI != null:
				HumanKingdomAI.force_mobilize(5)
			if ResourceManager != null:
				ResourceManager.apply_delta(player_id, {"prestige": 5})
			EventBus.message_log.emit("[color=yellow][外交拒绝] 红叶冷冷一笑，转身离去。人类王国因此更加团结，动员度 +5。[/color]")

# ═══════════════════════════════════════════════════════════
# 事件 D：圣战号召
# ═══════════════════════════════════════════════════════════

func trigger_holy_crusade_event(player_id: int) -> void:
	if EVT_HOLY_CRUSADE in _triggered_once:
		return
	_triggered_once.append(EVT_HOLY_CRUSADE)
	# 激活圣战 buff
	_crusade_buff_active = true
	_crusade_buff_turns = CRUSADE_BUFF_DURATION
	# 对所有人类单位施加 ATK/DEF buff（通过 GameManager）
	if GameManager != null and GameManager.has_method("apply_faction_buff"):
		GameManager.apply_faction_buff(0, {"atk": CRUSADE_STAT_BONUS, "def": CRUSADE_STAT_BONUS, "turns": CRUSADE_BUFF_DURATION})
	EventBus.message_log.emit("═══════════════════════════════")
	EventBus.message_log.emit("[color=red]【圣战号召】女王千姬的演讲[/color]")
	EventBus.message_log.emit('"天城的子民们！黑暗的浪潮已经逼近我们的家园。')
	EventBus.message_log.emit(' 但只要圣殿的旗帜还在飘扬，我们就不会倒下！"')
	EventBus.message_log.emit("")
	EventBus.message_log.emit("全体人类单位 ATK/DEF +1，持续 %d 回合！" % CRUSADE_BUFF_DURATION)
	EventBus.message_log.emit("")
	EventBus.message_log.emit("[A] 全力迎战：与圣战军队正面决战")
	EventBus.message_log.emit("    → 大型战斗（敌 20 兵，凛+冰华双英雄参战）")
	EventBus.message_log.emit("[B] 战略撤退：主动放弃2处据点，换取喘息空间")
	EventBus.message_log.emit("    → 弃守2处边境据点，威胁 -10")
	EventBus.message_log.emit("═══════════════════════════════")
	_push_player_choice(EVT_HOLY_CRUSADE, player_id, {
		"options": [
			{"id": "fight",    "label": "全力迎战"},
			{"id": "retreat",  "label": "战略撤退"},
		]
	})


func resolve_holy_crusade(player_id: int, choice: String, _data: Dictionary) -> void:
	match choice:
		"fight":
			EventBus.message_log.emit("[color=red][圣战决战] 凛与冰华率20名精锐骑士向您的核心据点发动总攻！[/color]")
			if GameManager != null and GameManager.has_method("action_trigger_crusade_battle"):
				GameManager.action_trigger_crusade_battle(player_id, 20)
			else:
				EventBus.message_log.emit("[战斗] 圣战军队发动总攻，造成 12 点伤害。")
		"retreat":
			_abandon_two_border_tiles(player_id)
			if ThreatManager != null:
				ThreatManager.add_threat(-10)
			EventBus.message_log.emit("[color=gray][战略撤退] 您主动放弃了2处边境据点，暂时缓解了圣战压力。威胁 -10。[/color]")


func _abandon_two_border_tiles(player_id: int) -> void:
	if GameManager == null:
		return
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
				EventBus.message_log.emit("[撤退] 放弃据点 #%d" % tile_idx)
				break

# ═══════════════════════════════════════════════════════════
# 事件 E：冰华死守令
# ═══════════════════════════════════════════════════════════

func trigger_binghua_last_stand_event(player_id: int, fortress_tile: int) -> void:
	if EVT_BINGHUA_LAST_STAND in _triggered_once:
		return
	_triggered_once.append(EVT_BINGHUA_LAST_STAND)
	EventBus.message_log.emit("═══════════════════════════════")
	EventBus.message_log.emit("[color=red]【特殊事件】铁壁死守令[/color]")
	EventBus.message_log.emit("铁壁女伯爵·[color=white]冰华[/color] 站在银冠要塞的城墙上，")
	EventBus.message_log.emit("面对三面包围的敌军，她只说了一句话：")
	EventBus.message_log.emit("")
	EventBus.message_log.emit('"此地，我守。"')
	EventBus.message_log.emit("")
	EventBus.message_log.emit("银冠要塞城防×2，守军 +5！")
	EventBus.message_log.emit("")
	EventBus.message_log.emit("[A] 强攻：正面突破冰华的防线")
	EventBus.message_log.emit("    → 正常战斗（但城防加倍，难度大幅提升）")
	EventBus.message_log.emit("[B] 围困：切断补给，等待要塞自行陷落")
	EventBus.message_log.emit("    → 每回合守军 -3，3回合后自动陷落（冰华被俘）")
	EventBus.message_log.emit("═══════════════════════════════")
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
			if GameManager != null and GameManager.has_method("action_trigger_fortress_assault"):
				GameManager.action_trigger_fortress_assault(player_id, fortress_tile)
			else:
				EventBus.message_log.emit("[战斗] 强攻银冠要塞，城防加倍，战斗极为艰难。")
		"siege":
			EventBus.message_log.emit("[color=gray][围困] 您切断了银冠要塞的补给线。守军每回合 -3，3回合后要塞将自行陷落……[/color]")
			if fortress_tile >= 0 and GameManager != null:
				GameManager.tiles[fortress_tile]["siege_countdown"] = 3
				GameManager.tiles[fortress_tile]["siege_drain"] = 3

# ═══════════════════════════════════════════════════════════
# 事件 F：雪乃追随（凛被俘后自动触发）
# ═══════════════════════════════════════════════════════════

func trigger_snow_messenger_event(player_id: int) -> void:
	if EVT_SNOW_MESSENGER in _triggered_once:
		return
	_triggered_once.append(EVT_SNOW_MESSENGER)
	EventBus.message_log.emit("═══════════════════════════════")
	EventBus.message_log.emit("[color=cyan]【角色事件】王宫神官的追随[/color]")
	EventBus.message_log.emit("王宫神官·[color=white]雪乃[/color] 独自来到您的营地，")
	EventBus.message_log.emit("她的眼神中没有恐惧，只有坚定：")
	EventBus.message_log.emit("")
	EventBus.message_log.emit('"凛大人在哪里，我就在哪里。')
	EventBus.message_log.emit(' 请允许我留下来……照顾她。"')
	EventBus.message_log.emit("")
	EventBus.message_log.emit("雪乃自动加入您的阵营！")
	EventBus.message_log.emit("（雪乃的存在使凛的好感度获取速度 +50%）")
	EventBus.message_log.emit("═══════════════════════════════")
	# 雪乃自动加入（无需选择）
	if HeroSystem != null and HeroSystem.has_method("recruit_hero"):
		HeroSystem.recruit_hero(player_id, "yukino")
	EventBus.message_log.emit("[color=green][角色加入] 雪乃加入了您的阵营！[/color]")

# ═══════════════════════════════════════════════════════════
# 事件 G：女王演讲（圣战前置，威胁 70+ 时触发）
# ═══════════════════════════════════════════════════════════

func trigger_queen_speech_event(player_id: int) -> void:
	if EVT_QUEEN_SPEECH in _triggered_once:
		return
	var threat: int = ThreatManager.get_threat() if ThreatManager != null else 0
	if threat < 70:
		return
	_triggered_once.append(EVT_QUEEN_SPEECH)
	EventBus.message_log.emit("═══════════════════════════════")
	EventBus.message_log.emit("[color=yellow]【预警事件】女王的宣言[/color]")
	EventBus.message_log.emit("女王·[color=white]千姬[/color] 在王都广场发表公开宣言：")
	EventBus.message_log.emit("")
	EventBus.message_log.emit('"黑暗的势力已经逼近我们的家园。')
	EventBus.message_log.emit(' 天城王朝的子民们，是时候拿起武器了。"')
	EventBus.message_log.emit("")
	EventBus.message_log.emit("[警告] 威胁值再提升10点，将触发圣战号召！")
	EventBus.message_log.emit("═══════════════════════════════")
	# 人类王国动员度大幅提升
	if HumanKingdomAI != null:
		HumanKingdomAI.force_mobilize(20)

# ═══════════════════════════════════════════════════════════
# 工具方法
# ═══════════════════════════════════════════════════════════

func is_crusade_buff_active() -> bool:
	return _crusade_buff_active


func get_crusade_buff_turns_remaining() -> int:
	return _crusade_buff_turns


func is_event_triggered(event_id: String) -> bool:
	return event_id in _triggered_once


## 向玩家推送待选择事件（由 UI 层监听 EventBus 处理）
func _push_player_choice(event_id: String, player_id: int, event_data: Dictionary) -> void:
	event_data["event_id"] = event_id
	event_data["player_id"] = player_id
	if EventBus.has_signal("human_event_choice_requested"):
		EventBus.human_event_choice_requested.emit(event_id, player_id, event_data)


## 统一处理玩家选择结果（由 UI 层调用）
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
