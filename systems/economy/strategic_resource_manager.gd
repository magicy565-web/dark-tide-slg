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
			var is_permanent: bool = action_id in [
				"arcane_enhance", "iron_charge", "gun_enhance", "gunpowder_assault",
				"altar_boost", "ultimate_unlock",
				"trade_monopoly", "soul_resurrection", "arcane_mastery",
			]
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

	# Check if permanent and already done (only block re-purchase for permanent upgrades)
	var _is_permanent_action: bool = action_id in [
		"arcane_enhance", "iron_charge", "gun_enhance", "gunpowder_assault",
		"altar_boost", "ultimate_unlock",
		"trade_monopoly", "soul_resurrection", "arcane_mastery",
	]
	if _is_permanent_action and has_upgrade(player_id, action_id):
		EventBus.message_log.emit("该升级已完成!")
		return false

	# 扣除前再次验证余额充足（防止并发/竞态导致资源不足）
	var pre_balance: int = ResourceManager.get_resource(player_id, res_key)
	if pre_balance < cost:
		EventBus.message_log.emit("[color=red]资源不足，操作已取消[/color]")
		return false

	ResourceManager.apply_delta(player_id, {res_key: -cost})
	# FIX R2-A3: Defer signal until after action succeeds (relic_upgrade may refund)
	var _signal_deferred: bool = true

	# Apply effect
	match action_id:
		# ── Magic Crystal ──
		"unit_upgrade_lv3":
			# Consumed as an extra cost when upgrading a unit to Lv3 (handled by RecruitManager).
			# execute_action here only deducts the resource; the caller is responsible for
			# the actual unit upgrade logic.
			EventBus.message_log.emit("[color=cyan]消耗魔晶升级兵种Lv3[/color]")

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
		"cavalry_recruit":
			# Consumed as an extra cost when recruiting cavalry units (handled by RecruitManager).
			# execute_action here only deducts the resource; the caller is responsible for
			# the actual recruitment logic.
			EventBus.message_log.emit("[color=cyan]消耗战马招募骑兵[/color]")

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
				_signal_deferred = false
				return false

		"ultimate_unlock":
			_permanent_upgrades[player_id]["ultimate_unlock"] = true
			EventBus.message_log.emit("[color=purple]终极兵种解锁! 可在核心据点招募终极单位[/color]")

		"shadow_dominion":
			# All NPC obedience +30
			NpcManager.boost_all_obedience(player_id, 30)
			EventBus.message_log.emit("[color=purple]暗影统御! 所有奴隶NPC服从度+30[/color]")

		# ── Trade Goods ──
		"trade_caravan":
			# Deferred income: +60 gold next turn via buff
			BuffManager.add_buff(player_id, "trade_caravan", "gold_per_turn", 60, 1, "strategic")
			EventBus.message_log.emit("[color=green]商队出发! 下回合获得+60金[/color]")

		"buy_mercenaries":
			# Hire elite mercenaries (+5 army)
			ResourceManager.add_army(player_id, 5)
			EventBus.message_log.emit("[color=green]雇佣精锐佣兵! +5兵力[/color]")

		"trade_monopoly":
			_permanent_upgrades[player_id]["trade_monopoly"] = true
			EventBus.message_log.emit("[color=purple]贸易垄断! 金币收入永久+20%[/color]")

		# ── Soul Crystals ──
		"hero_empower":
			# Permanently boost a random hero's stats by +2
			if HeroSystem != null and HeroSystem.has_method("empower_random_hero"):
				HeroSystem.empower_random_hero(player_id, 2)
				EventBus.message_log.emit("[color=cyan]英雄强化! 随机英雄永久属性+2[/color]")
			else:
				# Fallback: apply as global atk buff
				BuffManager.add_buff(player_id, "hero_empower", "atk_mult", 1.1, -1, "strategic")
				EventBus.message_log.emit("[color=cyan]英雄强化! 全军攻击+10%(永久)[/color]")

		"soul_shield":
			# Soul shield: absorb first 30% damage for 3 turns
			BuffManager.add_buff(player_id, "soul_shield", "def_mult", 1.3, 3, "strategic")
			EventBus.message_log.emit("[color=cyan]灵魂护盾! 全军防御+30%(3回合)[/color]")

		"soul_resurrection":
			_permanent_upgrades[player_id]["soul_resurrection"] = true
			EventBus.message_log.emit("[color=purple]灵魂复活! 战斗阵亡士兵50%复活(永久)[/color]")

		# ── Arcane Dust ──
		"quick_build":
			# Next building completes instantly — apply as buff flag
			BuffManager.add_buff(player_id, "quick_build", "instant_build", true, 1, "strategic")
			EventBus.message_log.emit("[color=cyan]快速建造! 下一个建筑立即完工[/color]")

		"research_boost":
			# +50% research speed for 5 turns
			BuffManager.add_buff(player_id, "research_boost", "research_speed", 1.5, 5, "strategic")
			EventBus.message_log.emit("[color=cyan]研究加速! 研究速度+50%(5回合)[/color]")

		"arcane_mastery":
			_permanent_upgrades[player_id]["arcane_mastery"] = true
			EventBus.message_log.emit("[color=purple]奥术精通! 全军法术伤害永久+30%[/color]")

	# FIX R2-A3: Emit consumption signal only after action confirmed successful
	if _signal_deferred:
		EventBus.strategic_resource_consumed.emit(player_id, res_key, cost)
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

func get_trade_monopoly_gold_mult(player_id: int) -> float:
	## Returns +20% gold income multiplier if trade_monopoly is active.
	if has_upgrade(player_id, "trade_monopoly"):
		return 1.2
	return 1.0

func has_soul_resurrection(player_id: int) -> bool:
	## Returns true if soul_resurrection is active (50% troop revival after battle).
	return has_upgrade(player_id, "soul_resurrection")

func get_arcane_mastery_spell_mult(player_id: int) -> float:
	## Returns +30% spell damage multiplier if arcane_mastery is active.
	if has_upgrade(player_id, "arcane_mastery"):
		return 1.3
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
