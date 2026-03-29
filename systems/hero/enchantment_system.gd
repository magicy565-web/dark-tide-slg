## enchantment_system.gd — Equipment Enchantment System for 暗潮 SLG
## Autoload singleton: EnchantmentSystem
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")

# ---------------------------------------------------------------------------
# Enchantment definitions
# ---------------------------------------------------------------------------

var enchantments: Dictionary = {
	"fire_brand": {name = "烈焰", atk_bonus = 3, def_bonus = 0, spd_bonus = 0, mp_bonus = 0,
				   passive = "burn_on_hit", desc = "攻击附带灼烧"},
	"frost_edge": {name = "霜寒", atk_bonus = 0, def_bonus = 0, spd_bonus = 2, mp_bonus = 0,
				   passive = "slow_on_hit", desc = "攻击减速目标"},
	"vampiric": {name = "吸血", atk_bonus = 0, def_bonus = 0, spd_bonus = 0, mp_bonus = 0,
				 passive = "lifesteal_15", desc = "15%伤害转化为治疗"},
	"thunder": {name = "雷鸣", atk_bonus = 0, def_bonus = 0, spd_bonus = 0, mp_bonus = 0,
				passive = "chain_lightning", desc = "25%几率连锁闪电攻击相邻敌人"},
	"holy": {name = "神圣", atk_bonus = 2, def_bonus = 0, spd_bonus = 0, mp_bonus = 0,
			 passive = "anti_undead_50", desc = "对亡灵+50%伤害"},
	"shadow": {name = "暗影", atk_bonus = 0, def_bonus = 0, spd_bonus = 0, mp_bonus = 0,
			   passive = "crit_rate_up_20", desc = "暴击率+20%"},
	"guardian": {name = "守护", atk_bonus = 0, def_bonus = 4, spd_bonus = 0, mp_bonus = 0,
				 passive = "damage_reduce_10", desc = "受伤减免10%"},
	"berserker": {name = "狂战", atk_bonus = 5, def_bonus = -2, spd_bonus = 0, mp_bonus = 0,
				  passive = "rage_stack", desc = "每次受击ATK+1(最多+5)"},
	"windwalker": {name = "疾风", atk_bonus = 0, def_bonus = 0, spd_bonus = 4, mp_bonus = 0,
				   passive = "double_attack_15", desc = "15%几率二连击"},
	"arcane": {name = "奥术", atk_bonus = 0, def_bonus = 0, spd_bonus = 0, mp_bonus = 3,
			   passive = "spell_amp_20", desc = "技能伤害+20%"},
}

# ---------------------------------------------------------------------------
# State: hero_id -> enchantment_id
# ---------------------------------------------------------------------------
var _hero_enchantments: Dictionary = {}
# Runtime combat state: hero_id -> {rage_stacks: int, ...}
var _combat_state: Dictionary = {}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func enchant_equipment(hero_id: String, enchantment_id: String) -> bool:
	if not enchantments.has(enchantment_id):
		EventBus.message_log.emit("[附魔] 未知附魔: %s" % enchantment_id)
		return false
	if not HeroSystem.recruited_heroes.has(hero_id):
		EventBus.message_log.emit("[附魔] 英雄未招募: %s" % hero_id)
		return false
	_hero_enchantments[hero_id] = enchantment_id
	var ench: Dictionary = enchantments[enchantment_id]
	var hero_name: String = FactionData.HEROES.get(hero_id, {}).get("name", hero_id)
	EventBus.enchantment_changed.emit(hero_id, enchantment_id)
	EventBus.message_log.emit("[附魔] %s 装备附魔: %s — %s" % [hero_name, ench.get("name", ""), ench.get("desc", "")])
	return true


func remove_enchantment(hero_id: String) -> void:
	if _hero_enchantments.has(hero_id):
		_hero_enchantments.erase(hero_id)
		EventBus.enchantment_changed.emit(hero_id, "")
		var hero_name: String = FactionData.HEROES.get(hero_id, {}).get("name", hero_id)
		EventBus.message_log.emit("[附魔] %s 附魔已移除" % hero_name)


func get_hero_enchantment(hero_id: String) -> String:
	return _hero_enchantments.get(hero_id, "")


func get_enchantment_bonuses(hero_id: String) -> Dictionary:
	var ench_id: String = _hero_enchantments.get(hero_id, "")
	if ench_id.is_empty() or not enchantments.has(ench_id):
		return {"atk_bonus": 0, "def_bonus": 0, "spd_bonus": 0, "mp_bonus": 0, "passive": ""}
	var ench: Dictionary = enchantments[ench_id]
	return {
		"atk_bonus": ench.get("atk_bonus", 0),
		"def_bonus": ench.get("def_bonus", 0),
		"spd_bonus": ench.get("spd_bonus", 0),
		"mp_bonus": ench.get("mp_bonus", 0),
		"passive": ench.get("passive", ""),
	}


func apply_enchantment_in_combat(hero_id: String, action_result: Dictionary) -> Dictionary:
	var ench_id: String = _hero_enchantments.get(hero_id, "")
	if ench_id.is_empty() or not enchantments.has(ench_id):
		return action_result

	var ench: Dictionary = enchantments[ench_id]
	var passive: String = ench.get("passive", "")
	var extra_effects: Array = action_result.get("enchantment_effects", [])
	var damage_dealt: int = action_result.get("damage", 0)

	match passive:
		"burn_on_hit":
			if damage_dealt > 0:
				extra_effects.append({"type": "burn", "duration": 2, "dot": 1,
					"desc": "灼烧: 2回合每回合1伤害"})

		"slow_on_hit":
			if damage_dealt > 0:
				extra_effects.append({"type": "slow", "duration": 2, "spd_reduction": 2,
					"desc": "减速: SPD-2持续2回合"})

		"lifesteal_15":
			if damage_dealt > 0:
				var heal: int = maxi(1, int(float(damage_dealt) * 0.15))
				extra_effects.append({"type": "lifesteal", "heal": heal,
					"desc": "吸血: 回复%d兵" % heal})

		"chain_lightning":
			if damage_dealt > 0 and randf() < 0.25:
				var chain_dmg: int = maxi(1, int(float(damage_dealt) * 0.5))
				extra_effects.append({"type": "chain_lightning", "damage": chain_dmg,
					"desc": "连锁闪电: 相邻敌人受%d伤害" % chain_dmg})

		"anti_undead_50":
			var target_type: String = action_result.get("target_type", "")
			if "skeleton" in target_type or "undead" in target_type or "necro" in target_type:
				var bonus_dmg: int = int(float(damage_dealt) * 0.5)
				extra_effects.append({"type": "anti_undead", "bonus_damage": bonus_dmg,
					"desc": "神圣: 对亡灵+%d伤害" % bonus_dmg})

		"crit_rate_up_20":
			if damage_dealt > 0 and randf() < 0.20:
				var crit_bonus: int = damage_dealt
				extra_effects.append({"type": "critical", "bonus_damage": crit_bonus,
					"desc": "暴击: 额外%d伤害" % crit_bonus})

		"damage_reduce_10":
			var incoming: int = action_result.get("damage_taken", 0)
			if incoming > 0:
				var reduced: int = maxi(1, int(float(incoming) * 0.10))
				extra_effects.append({"type": "damage_reduce", "reduced": reduced,
					"desc": "守护: 减免%d伤害" % reduced})

		"rage_stack":
			if not _combat_state.has(hero_id):
				_combat_state[hero_id] = {"rage_stacks": 0}
			var incoming: int = action_result.get("damage_taken", 0)
			if incoming > 0:
				var stacks: int = _combat_state[hero_id].get("rage_stacks", 0)
				if stacks < 5:
					_combat_state[hero_id]["rage_stacks"] = stacks + 1
					extra_effects.append({"type": "rage_stack", "current_stacks": stacks + 1,
						"atk_bonus": 1, "desc": "狂战: ATK+1 (累计+%d)" % (stacks + 1)})

		"double_attack_15":
			if damage_dealt > 0 and randf() < 0.15:
				extra_effects.append({"type": "double_attack", "extra_damage": damage_dealt,
					"desc": "二连击: 额外%d伤害" % damage_dealt})

		"spell_amp_20":
			if action_result.get("is_skill", false) and damage_dealt > 0:
				var amp_bonus: int = int(float(damage_dealt) * 0.20)
				extra_effects.append({"type": "spell_amp", "bonus_damage": amp_bonus,
					"desc": "奥术: 技能伤害+%d" % amp_bonus})

	action_result["enchantment_effects"] = extra_effects
	return action_result


func get_rage_stacks(hero_id: String) -> int:
	return _combat_state.get(hero_id, {}).get("rage_stacks", 0)


# ---------------------------------------------------------------------------
# Battle lifecycle
# ---------------------------------------------------------------------------

func reset_combat_state() -> void:
	_combat_state.clear()


# ---------------------------------------------------------------------------
# Save / Load
# ---------------------------------------------------------------------------

func to_save_data() -> Dictionary:
	return {"hero_enchantments": _hero_enchantments.duplicate()}


func from_save_data(data: Dictionary) -> void:
	_hero_enchantments = data.get("hero_enchantments", {}).duplicate()
