## dark_elf_mechanic.gd - Dark Elf Council specific mechanics
## ═══════════════════════════════════════════════════════════════════════════
## [DEV POLICY] AI-ONLY FACTION — DO NOT DEVELOP FOR PLAYER
## This file handles DARK ELF faction AI behavior exclusively.
## The DARK_ELF faction is NOT selectable by the player (see main_menu.gd).
## Do NOT add new player-facing mechanics, UI hooks, or HUD integrations.
## Maintenance only: bug fixes for AI correctness are acceptable.
## ═══════════════════════════════════════════════════════════════════════════
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Persistent altar ATK bonus accumulated from sacrifices ──
var _altar_atk_bonus: Dictionary = {}   # player_id -> int

# ── Shadow Network (fog of war removal for enemy armies) ──
var _shadow_network_active: Dictionary = {}  # player_id -> bool

# ── Assassination cooldown ──
var _assassination_cooldown: Dictionary = {}  # player_id -> int (turns remaining)

# ── Corruption (convert neutral tiles) ──
var _corruption_targets: Dictionary = {}     # player_id -> Array of { tile_index: int, turns_left: int }


func _ready() -> void:
	pass


func reset() -> void:
	_altar_atk_bonus.clear()
	_shadow_network_active.clear()
	_assassination_cooldown.clear()
	_corruption_targets.clear()


func init_player(player_id: int) -> void:
	_altar_atk_bonus[player_id] = 0
	_shadow_network_active[player_id] = false
	_assassination_cooldown[player_id] = 0
	_corruption_targets[player_id] = []


func get_altar_atk_bonus(player_id: int) -> int:
	return _altar_atk_bonus.get(player_id, 0)


# ═══════════════ TURN TICK ═══════════════

func tick(player_id: int) -> void:
	## Called each turn for Dark Elf players.
	# Altar tick (sacrifice cycle + atk bonus)
	var altar_result: Dictionary = SlaveManager.tick_altar(player_id)
	if altar_result.get("atk_bonus", 0) > 0:
		EventBus.message_log.emit("[color=purple]祭坛效果: 全军攻击+%d (本回合)[/color]" % altar_result.get("atk_bonus", 0))
	# Apply shadow essence production from altar sacrifices
	var shadow_gain: int = altar_result.get("shadow_essence", 0)
	if shadow_gain > 0:
		ResourceManager.apply_delta(player_id, {"shadow_essence": shadow_gain})
		EventBus.message_log.emit("[color=purple]祭坛产出: +%d 暗影精华[/color]" % shadow_gain)
	if altar_result.get("sacrificed", false):
		# BUG修复: 祭坛攻击加成上限为+10，防止无限叠加
		_altar_atk_bonus[player_id] = mini(_altar_atk_bonus.get(player_id, 0) + 1, 10)
		EventBus.message_log.emit("[color=purple]永久祭坛加成: +%d 全局攻击[/color]" % _altar_atk_bonus[player_id])
		# Sync slave count after sacrifice
		var current_slaves: int = SlaveManager.get_total_slaves(player_id)
		ResourceManager.set_resource(player_id, "slaves", current_slaves)

	# ── Shadow Network upkeep ──
	_tick_shadow_network(player_id)

	# ── Assassination cooldown ──
	if _assassination_cooldown.get(player_id, 0) > 0:
		_assassination_cooldown[player_id] -= 1

	# ── Corruption progress ──
	_tick_corruption(player_id)


# ═══════════════ COMBAT SLAVE BONUS ═══════════════

func on_combat_win(player_id: int) -> void:
	## Dark Elf: +1 slave on any combat win.
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.DARK_ELF]
	var bonus: int = params["combat_slave_bonus"]
	var cap: int = ResourceManager.get_slave_capacity(player_id)
	var current: int = ResourceManager.get_slaves(player_id)
	if current < cap:
		ResourceManager.apply_delta(player_id, {"slaves": bonus})
		SlaveManager.sync_slave_count(player_id)
		EventBus.message_log.emit("[color=purple]黑暗精灵俘获+%d奴隶![/color]" % bonus)
	else:
		EventBus.message_log.emit("奴隶容量已满，无法俘获更多")


# ═══════════════ COMBAT ATK BONUS ═══════════════

func get_combat_atk_bonus(player_id: int) -> int:
	## Returns total extra ATK from altar slaves + permanent sacrifice bonus.
	var alloc: Dictionary = SlaveManager.get_allocation(player_id)
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.DARK_ELF]
	var altar_slaves: int = alloc.get("altar", 0)
	var per_slave: int = params["slave_altar_atk_per_slave"]
	return altar_slaves * per_slave + _altar_atk_bonus.get(player_id, 0)


# ═══════════════ SLAVE ALLOCATION HELPERS ═══════════════

func has_altar_unlocked(player_id: int) -> bool:
	## Check if Temple of Agony is built.
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id and tile.get("building_id", "") == "temple_of_agony":
			return true
	return false


func allocate_to_mine(player_id: int) -> bool:
	return SlaveManager.allocate_slave(player_id, "mine")


func allocate_to_farm(player_id: int) -> bool:
	return SlaveManager.allocate_slave(player_id, "farm")


func allocate_to_altar(player_id: int) -> bool:
	if not has_altar_unlocked(player_id):
		EventBus.message_log.emit("需要先建造痛苦神殿才能使用祭坛!")
		return false
	return SlaveManager.allocate_slave(player_id, "altar")


# ═══════════════ SHADOW NETWORK (fog of war removal) ═══════════════

## Toggle the Shadow Network on/off. Costs 10g/turn upkeep when active.
func toggle_shadow_network(player_id: int) -> bool:
	var active: bool = _shadow_network_active.get(player_id, false)
	if active:
		_shadow_network_active[player_id] = false
		EventBus.message_log.emit("[color=purple]暗影情报网已关闭[/color]")
		return true
	# Check if player can afford the upkeep
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.DARK_ELF]
	var upkeep: int = params.get("shadow_network_upkeep", 10)
	if not ResourceManager.can_afford(player_id, {"gold": upkeep}):
		EventBus.message_log.emit("[color=red]金币不足! 暗影情报网需要每回合%d金维护费[/color]" % upkeep)
		return false
	_shadow_network_active[player_id] = true
	EventBus.message_log.emit("[color=purple]暗影情报网已启动! 可以看到所有敌方军队位置 (每回合-%d金)[/color]" % upkeep)
	return true


## Returns whether the Shadow Network is active for this player.
func is_shadow_network_active(player_id: int) -> bool:
	return _shadow_network_active.get(player_id, false)


## Internal: deduct shadow network upkeep at start of turn.
func _tick_shadow_network(player_id: int) -> void:
	if not _shadow_network_active.get(player_id, false):
		return
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.DARK_ELF]
	var upkeep: int = params.get("shadow_network_upkeep", 10)
	if not ResourceManager.can_afford(player_id, {"gold": upkeep}):
		_shadow_network_active[player_id] = false
		EventBus.message_log.emit("[color=red]金币不足! 暗影情报网被迫关闭![/color]")
		return
	ResourceManager.apply_delta(player_id, {"gold": -upkeep})
	EventBus.message_log.emit("[color=purple]暗影情报网运行中: -%d金 (敌方军队位置已揭示)[/color]" % upkeep)


# ═══════════════ ASSASSINATION (spend AP to kill enemy hero) ═══════════════

## Check if assassination can be attempted this turn.
func can_assassinate(player_id: int) -> bool:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.DARK_ELF]
	var ap_cost: int = params.get("assassination_ap_cost", 2)
	var player: Dictionary = GameManager.get_player_by_id(player_id)
	if player.is_empty():
		return
	var current_ap: int = player.get("ap", 0)
	return current_ap >= ap_cost and _assassination_cooldown.get(player_id, 0) <= 0


## Attempt to assassinate an enemy hero. Costs 2 AP, 40% success, -20 rep.
## target_faction_id: the faction whose strongest hero to target.
## Returns a result dictionary with "success" key.
func attempt_assassination(player_id: int, target_faction_id: int) -> Dictionary:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.DARK_ELF]
	var ap_cost: int = params.get("assassination_ap_cost", 2)
	var success_chance: float = params.get("assassination_success_chance", 0.40)
	var rep_cost: int = params.get("assassination_rep_cost", -20)

	# Deduct AP
	var player: Dictionary = GameManager.get_player_by_id(player_id)
	if player.is_empty():
		return
	player["ap"] = player.get("ap", 0) - ap_cost
	EventBus.ap_changed.emit(player_id, player["ap"])

	# Apply reputation penalty
	ThreatManager.change_threat(-rep_cost)  # rep_cost is negative, negate for positive threat
	EventBus.message_log.emit("[color=purple]暗杀尝试! 声望损失: %d[/color]" % rep_cost)

	# Set cooldown (3 turns)
	_assassination_cooldown[player_id] = 3

	# Roll for success
	var roll: float = randf()
	if roll <= success_chance:
		EventBus.message_log.emit("[color=purple]>>> 暗杀成功! 敌方失去其最强指挥官! <<<[/color]")
		return {"success": true, "target_faction": target_faction_id}
	else:
		EventBus.message_log.emit("[color=gray]暗杀失败... 刺客被发现并逃离[/color]")
		return {"success": false, "target_faction": target_faction_id}


## Returns the assassination cooldown remaining.
func get_assassination_cooldown(player_id: int) -> int:
	return _assassination_cooldown.get(player_id, 0)


# ═══════════════ CORRUPTION (convert neutral tiles without combat) ═══════════════

## Start corrupting a neutral tile. Costs prestige, takes 3 turns.
func start_corruption(player_id: int, tile_index: int) -> bool:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.DARK_ELF]
	var prestige_cost: int = params.get("corruption_prestige_cost", 15)
	var turns: int = params.get("corruption_turns", 3)

	# Validate tile is neutral and not already being corrupted
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		EventBus.message_log.emit("[color=red]无效的地块索引![/color]")
		return false
	if tile_index < 0 or tile_index >= GameManager.tiles.size():
		return
	var tile: Dictionary = GameManager.tiles[tile_index]
	if tile.get("owner_id", -1) != -1:
		EventBus.message_log.emit("[color=red]该地块已有所属, 无法腐蚀![/color]")
		return false

	# Check if already being corrupted
	var targets: Array = _corruption_targets.get(player_id, [])
	for t in targets:
		if t.get("tile_index", -1) == tile_index:
			EventBus.message_log.emit("[color=red]该地块正在被腐蚀中![/color]")
			return false

	# Check prestige
	if not ResourceManager.can_afford(player_id, {"prestige": prestige_cost}):
		EventBus.message_log.emit("[color=red]威望不足! 需要%d威望[/color]" % prestige_cost)
		return false

	ResourceManager.spend(player_id, {"prestige": prestige_cost})
	targets.append({"tile_index": tile_index, "turns_left": turns})
	_corruption_targets[player_id] = targets
	EventBus.message_log.emit("[color=purple]开始腐蚀地块 #%d! 将在%d回合后完成 (花费%d威望)[/color]" % [tile_index, turns, prestige_cost])
	return true


## Get all tiles currently being corrupted by this player.
func get_corruption_targets(player_id: int) -> Array:
	return _corruption_targets.get(player_id, []).duplicate(true)


## Internal: tick corruption progress, complete any finished ones.
func _tick_corruption(player_id: int) -> void:
	var targets: Array = _corruption_targets.get(player_id, [])
	if targets.is_empty():
		return
	var completed: Array = []
	for target in targets:
		target["turns_left"] -= 1
		if target["turns_left"] <= 0:
			completed.append(target)
		else:
			EventBus.message_log.emit("[color=purple]腐蚀进行中: 地块 #%d 剩余%d回合[/color]" % [target["tile_index"], target["turns_left"]])

	for target in completed:
		var tile_index: int = target["tile_index"]
		if tile_index >= 0 and tile_index < GameManager.tiles.size():
			var tile: Dictionary = GameManager.tiles[tile_index]
			if tile.get("owner_id", -1) == -1:  # Still neutral
				tile["owner_id"] = player_id
				EventBus.message_log.emit("[color=purple]>>> 腐蚀完成! 地块 #%d 已归入暗精灵版图! <<<[/color]" % tile_index)
				EventBus.tile_captured.emit(tile_index, player_id)
			else:
				EventBus.message_log.emit("[color=gray]腐蚀目标 #%d 已被他人占领, 腐蚀失败[/color]" % tile_index)
		targets.erase(target)
	_corruption_targets[player_id] = targets


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"altar_atk_bonus": _altar_atk_bonus.duplicate(true),
		"shadow_network_active": _shadow_network_active.duplicate(true),
		"assassination_cooldown": _assassination_cooldown.duplicate(true),
		"corruption_targets": _corruption_targets.duplicate(true),
	}


func _fix_int_keys(dict: Dictionary) -> void:
	var fix_keys = []
	for k in dict.keys():
		if k is String and k.is_valid_int():
			fix_keys.append(k)
	for k in fix_keys:
		dict[int(k)] = dict[k]
		dict.erase(k)


func from_save_data(data: Dictionary) -> void:
	_altar_atk_bonus = data.get("altar_atk_bonus", {}).duplicate(true)
	_fix_int_keys(_altar_atk_bonus)
	_shadow_network_active = data.get("shadow_network_active", {}).duplicate(true)
	_fix_int_keys(_shadow_network_active)
	_assassination_cooldown = data.get("assassination_cooldown", {}).duplicate(true)
	_fix_int_keys(_assassination_cooldown)
	_corruption_targets = data.get("corruption_targets", {}).duplicate(true)
	_fix_int_keys(_corruption_targets)
	# Fix int values in corruption targets after JSON round-trip
	for pid in _corruption_targets:
		if _corruption_targets[pid] is Array:
			for target in _corruption_targets[pid]:
				if target is Dictionary:
					if target.has("tile_index"):
						target["tile_index"] = int(target["tile_index"])
					if target.has("turns_left"):
						target["turns_left"] = int(target["turns_left"])
