extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")

## strategic_resource_manager.gd - Strategic resource consumption (v0.7)

# Track permanent upgrades per player
var _permanent_upgrades: Dictionary = {}  # player_id -> { upgrade_id: bool }

func _ready() -> void:
	pass

func reset() -> void:
	_permanent_upgrades.clear()

func init_player(player_id: int) -> void:
	_permanent_upgrades[player_id] = {}

func has_upgrade(player_id: int, upgrade_id: String) -> bool:
	if not _permanent_upgrades.has(player_id):
		return false
	return _permanent_upgrades[player_id].get(upgrade_id, false)

func get_available_actions(player_id: int) -> Array:
	## Returns list of available strategic resource actions for UI.
	## Each: { "id": String, "resource": String, "cost": int, "desc": String, "can_afford": bool, "already_done": bool }
	var result: Array = []
	for res_key in FactionData.STRATEGIC_RESOURCE_COSTS:
		var actions: Dictionary = FactionData.STRATEGIC_RESOURCE_COSTS[res_key]
		for action_id in actions:
			var action: Dictionary = actions[action_id]
			var cost_amount: int = action["cost"]
			var already: bool = has_upgrade(player_id, action_id)
			# Skip one-time upgrades that are already done
			var is_permanent: bool = action_id in ["arcane_enhance", "iron_charge", "gun_enhance", "gunpowder_assault", "altar_boost", "ultimate_unlock"]
			result.append({
				"id": action_id,
				"resource": res_key,
				"cost": cost_amount,
				"desc": action["desc"],
				"can_afford": ResourceManager.get_resource(player_id, res_key) >= cost_amount,
				"already_done": already and is_permanent,
				"is_permanent": is_permanent,
			})
	return result

func execute_action(player_id: int, action_id: String) -> bool:
	## Execute a strategic resource action. Returns true on success.
	# Find the action in STRATEGIC_RESOURCE_COSTS
	var res_key: String = ""
	var action_data: Dictionary = {}
	for rk in FactionData.STRATEGIC_RESOURCE_COSTS:
		if FactionData.STRATEGIC_RESOURCE_COSTS[rk].has(action_id):
			res_key = rk
			action_data = FactionData.STRATEGIC_RESOURCE_COSTS[rk][action_id]
			break

	if res_key == "" or action_data.is_empty():
		return false

	var cost: int = action_data["cost"]
	if ResourceManager.get_resource(player_id, res_key) < cost:
		EventBus.message_log.emit("[color=red]%s 不足![/color]" % res_key)
		return false

	# Check if permanent and already done
	if has_upgrade(player_id, action_id):
		EventBus.message_log.emit("该升级已完成!")
		return false

	# 扣除前再次验证余额充足（防止并发/竞态导致资源不足）
	var pre_balance: int = ResourceManager.get_resource(player_id, res_key)
	if pre_balance < cost:
		EventBus.message_log.emit("[color=red]资源不足，操作已取消[/color]")
		return false

	ResourceManager.apply_delta(player_id, {res_key: -cost})
	EventBus.strategic_resource_consumed.emit(player_id, res_key, cost)

	# Apply effect
	match action_id:
		# ── Magic Crystal ──
		"mana_jammer":
			# Craft item: add to inventory
			ItemManager.add_item(player_id, "mana_jammer_crafted")
			# Actually just give a buff that halves mage effects
			BuffManager.add_buff(player_id, "mana_jammer", "mage_weaken", 0.5, 5, "strategic")
			EventBus.message_log.emit("[color=purple]制造了法力干扰器! 魔法师屏障/法术效果减半(5回合)[/color]")

		"arcane_enhance":
			_permanent_upgrades[player_id]["arcane_enhance"] = true
			EventBus.message_log.emit("[color=purple]奥术强化! 全军攻击永久+5[/color]")

		# ── War Horse ──
		"forced_march":
			BuffManager.add_buff(player_id, "forced_march", "dice_bonus", 3, 1, "strategic")
			EventBus.message_log.emit("[color=green]强行军! 本回合骰子+3[/color]")

		"iron_charge":
			_permanent_upgrades[player_id]["iron_charge"] = true
			EventBus.message_log.emit("[color=purple]铁骑冲锋! 骑兵首轮攻击×2(永久)[/color]")

		# ── Gunpowder ──
		"siege_boost":
			BuffManager.add_buff(player_id, "siege_boost", "siege_mult", 2.0, 1, "strategic")
			EventBus.message_log.emit("[color=green]攻城强化! 本回合城防削减×2[/color]")

		"blast_barrel":
			# Craft explosive barrel item
			if not ItemManager.add_item(player_id, "blast_barrel_crafted"):
				# If inventory full, apply as immediate buff
				BuffManager.add_buff(player_id, "blast_barrel", "wall_damage", 15, 1, "strategic")
			EventBus.message_log.emit("[color=green]制造了爆破桶! 下次攻城直接削减15城防[/color]")

		"gun_enhance":
			_permanent_upgrades[player_id]["gun_enhance"] = true
			EventBus.message_log.emit("[color=purple]火器强化! 炮击手/火枪手攻击永久+5[/color]")

		"gunpowder_assault":
			_permanent_upgrades[player_id]["gunpowder_assault"] = true
			EventBus.message_log.emit("[color=purple]火药攻势! 攻打任何据点无视城防(永久)[/color]")

		# ── Shadow Essence ──
		"altar_boost":
			_permanent_upgrades[player_id]["altar_boost"] = true
			EventBus.message_log.emit("[color=purple]暗影祭坛! 祭坛工位效果×2(永久)[/color]")

		"relic_upgrade":
			# Delegate to RelicManager
			if RelicManager.upgrade_relic(player_id):
				pass  # RelicManager handles messaging
			else:
				# Refund if upgrade failed
				ResourceManager.apply_delta(player_id, {res_key: cost})
				return false

		"ultimate_unlock":
			_permanent_upgrades[player_id]["ultimate_unlock"] = true
			EventBus.message_log.emit("[color=purple]终极兵种解锁! 可在核心据点招募终极单位[/color]")

		"shadow_dominion":
			# All NPC obedience +30
			NpcManager.boost_all_obedience(player_id, 30)
			EventBus.message_log.emit("[color=purple]暗影统御! 所有奴隶NPC服从度+30[/color]")

	return true

# ── Convenience getters for combat/production integration ──

func get_permanent_atk_bonus(player_id: int) -> int:
	## Returns permanent attack bonus from arcane_enhance.
	if has_upgrade(player_id, "arcane_enhance"):
		return 5
	return 0

func get_gun_unit_atk_bonus(player_id: int) -> int:
	## Returns +5 atk bonus for gunner/bombardier if gun_enhance is active.
	if has_upgrade(player_id, "gun_enhance"):
		return 5
	return 0

func is_cavalry_charge_upgraded(player_id: int) -> bool:
	## Returns true if cavalry first-strike is upgraded to ×2.
	return has_upgrade(player_id, "iron_charge")

func ignores_walls(player_id: int) -> bool:
	## Returns true if gunpowder_assault is active (ignore city walls).
	return has_upgrade(player_id, "gunpowder_assault")

func is_ultimate_unlocked(player_id: int) -> bool:
	return has_upgrade(player_id, "ultimate_unlock")

func get_altar_multiplier(player_id: int) -> float:
	## Returns altar effect multiplier (1.0 or 2.0).
	if has_upgrade(player_id, "altar_boost"):
		return 2.0
	return 1.0


# ═══════════════ SAVE / LOAD ═══════════════

func to_save_data() -> Dictionary:
	return {
		"permanent_upgrades": _permanent_upgrades.duplicate(true),
	}


func from_save_data(data: Dictionary) -> void:
	_permanent_upgrades = data.get("permanent_upgrades", {}).duplicate(true)
	# Fix int keys after JSON round-trip (player_id keys become strings)
	var keys_to_fix: Array = []
	for k in _permanent_upgrades:
		if k is String and k.is_valid_int():
			keys_to_fix.append(k)
	for k in keys_to_fix:
		_permanent_upgrades[int(k)] = _permanent_upgrades[k]
		_permanent_upgrades.erase(k)
