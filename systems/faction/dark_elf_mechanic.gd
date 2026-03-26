## dark_elf_mechanic.gd - Dark Elf Council specific mechanics
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

# ── Persistent altar ATK bonus accumulated from sacrifices ──
var _altar_atk_bonus: Dictionary = {}   # player_id -> int


func _ready() -> void:
	pass


func reset() -> void:
	_altar_atk_bonus.clear()


func init_player(player_id: int) -> void:
	_altar_atk_bonus[player_id] = 0


func get_altar_atk_bonus(player_id: int) -> int:
	return _altar_atk_bonus.get(player_id, 0)


# ═══════════════ TURN TICK ═══════════════

func tick(player_id: int) -> void:
	## Called each turn for Dark Elf players.
	# Altar tick (sacrifice cycle + atk bonus)
	var altar_result: Dictionary = SlaveManager.tick_altar(player_id)
	if altar_result.get("atk_bonus", 0) > 0:
		EventBus.message_log.emit("[color=purple]祭坛效果: 全军攻击+%d (本回合)[/color]" % altar_result.get("atk_bonus", 0))
	if altar_result.get("sacrificed", false):
		# BUG修复: 祭坛攻击加成上限为+10，防止无限叠加
		_altar_atk_bonus[player_id] = mini(_altar_atk_bonus.get(player_id, 0) + 1, 10)
		EventBus.message_log.emit("[color=purple]永久祭坛加成: +%d 全局攻击[/color]" % _altar_atk_bonus[player_id])
		# Sync slave count after sacrifice
		var current_slaves: int = SlaveManager.get_total_slaves(player_id)
		ResourceManager.set_resource(player_id, "slaves", current_slaves)


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


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"altar_atk_bonus": _altar_atk_bonus.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_altar_atk_bonus = data.get("altar_atk_bonus", {}).duplicate(true)
