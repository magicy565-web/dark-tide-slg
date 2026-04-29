extends RefCounted
class_name FactionTacticalAIProfiles

## FactionTacticalAIProfiles
## 实战 AI 性格表。
## 不同势力通过目标偏好、行动偏好、站位偏好打出不同风格。

const DEFAULT_PROFILE_ID := "rebel_event"

const PROFILES: Dictionary = {
	"rebel_event": {
		"profile_id": "rebel_event",
		"style_name": "混乱叛军",
		"description": "事件敌人。偷袭低血、弓手骚扰、首领鼓舞；低血低士气时会撤退。",
		"target_weights": {"kill": 36, "low_hp": 28, "low_def": 10, "backline": 12, "healer": 12, "leader": -4, "nearest": 8, "threat": 8},
		"action_weights": {"damage": 30, "skill": 14, "control": 8, "buff": 10, "heal": 0, "survival": 10, "retreat": 22, "wait": -28},
		"position_weights": {"flank": 18, "hold_line": -8, "protect_backline": 0, "keep_distance": 8, "avoid_threat": 8, "objective": 4},
		"thresholds": {"retreat_hp_pct": 25, "panic_morale": 35, "heal_ally_hp_pct": 0, "aoe_min_targets": 2, "preferred_distance": 3}
	},
	"human_militia_guard": {
		"profile_id": "human_militia_guard",
		"style_name": "地方守备",
		"description": "村庄/哨点。守点、保护后排、依托地形，不主动追击太远。",
		"target_weights": {"kill": 18, "low_hp": 12, "low_def": 6, "backline": 0, "healer": 8, "leader": 6, "nearest": 20, "threat": 22},
		"action_weights": {"damage": 18, "skill": 8, "control": 12, "buff": 6, "heal": 16, "survival": 28, "retreat": 8, "wait": -6},
		"position_weights": {"flank": -12, "hold_line": 32, "protect_backline": 24, "keep_distance": 4, "avoid_threat": 14, "objective": 30},
		"thresholds": {"retreat_hp_pct": 18, "panic_morale": 20, "heal_ally_hp_pct": 50, "aoe_min_targets": 2, "preferred_distance": 2}
	},
	"human_regular_army": {
		"profile_id": "human_regular_army",
		"style_name": "王国正规军",
		"description": "城堡/正式交战。前排成线、弓手集火、牧师治疗、骑士突击。",
		"target_weights": {"kill": 22, "low_hp": 18, "low_def": 10, "backline": 10, "healer": 20, "leader": 16, "nearest": 8, "threat": 26},
		"action_weights": {"damage": 22, "skill": 16, "control": 14, "buff": 12, "heal": 24, "survival": 20, "retreat": 4, "wait": -12},
		"position_weights": {"flank": 6, "hold_line": 30, "protect_backline": 28, "keep_distance": 10, "avoid_threat": 12, "objective": 22},
		"thresholds": {"retreat_hp_pct": 12, "panic_morale": 10, "heal_ally_hp_pct": 55, "aoe_min_targets": 2, "preferred_distance": 3}
	},
	"orc_horde": {
		"profile_id": "orc_horde",
		"style_name": "兽人部落",
		"description": "压迫进攻。低血不撤，优先贴脸、围攻、冲锋。",
		"target_weights": {"kill": 22, "low_hp": 14, "low_def": 18, "backline": 8, "healer": 12, "leader": 4, "nearest": 22, "threat": 12},
		"action_weights": {"damage": 36, "skill": 18, "control": 10, "buff": 10, "heal": 0, "survival": 2, "retreat": -30, "wait": -36},
		"position_weights": {"flank": 8, "hold_line": -8, "protect_backline": -4, "keep_distance": -22, "avoid_threat": -12, "objective": 8, "surround": 26},
		"thresholds": {"retreat_hp_pct": 0, "panic_morale": 0, "heal_ally_hp_pct": 0, "aoe_min_targets": 2, "preferred_distance": 1}
	},
	"pirate_raider": {
		"profile_id": "pirate_raider",
		"style_name": "暗夜海盗",
		"description": "机会主义。远程先制、侧翼偷袭、重视低血和收益目标。",
		"target_weights": {"kill": 32, "low_hp": 22, "low_def": 16, "backline": 12, "healer": 16, "leader": 6, "nearest": 4, "threat": 10, "loot_value": 16},
		"action_weights": {"damage": 26, "skill": 18, "control": 12, "buff": 4, "heal": 0, "survival": 10, "retreat": 8, "wait": -14},
		"position_weights": {"flank": 24, "hold_line": -12, "protect_backline": 6, "keep_distance": 14, "avoid_threat": 10, "objective": 10},
		"thresholds": {"retreat_hp_pct": 20, "panic_morale": 25, "heal_ally_hp_pct": 0, "aoe_min_targets": 2, "preferred_distance": 4}
	},
	"dark_elf_assassin": {
		"profile_id": "dark_elf_assassin",
		"style_name": "暗精灵议会",
		"description": "刺杀控制。绕后、暗杀后排、优先牧师/法师。",
		"target_weights": {"kill": 28, "low_hp": 20, "low_def": 12, "backline": 32, "healer": 30, "leader": 12, "nearest": -8, "threat": 18},
		"action_weights": {"damage": 24, "skill": 26, "control": 24, "buff": 6, "heal": 0, "survival": 16, "retreat": 10, "wait": -20},
		"position_weights": {"flank": 34, "hold_line": -20, "protect_backline": 0, "keep_distance": 12, "avoid_threat": 16, "objective": 6, "backstab": 30},
		"thresholds": {"retreat_hp_pct": 20, "panic_morale": 10, "heal_ally_hp_pct": 0, "aoe_min_targets": 2, "preferred_distance": 2}
	},
	"high_elf_precision": {
		"profile_id": "high_elf_precision",
		"style_name": "高等精灵",
		"description": "精准远程。风筝、先制、保护法师，偏好安全距离。",
		"target_weights": {"kill": 24, "low_hp": 16, "low_def": 18, "backline": 8, "healer": 18, "leader": 14, "nearest": 0, "threat": 22},
		"action_weights": {"damage": 24, "skill": 20, "control": 16, "buff": 10, "heal": 12, "survival": 20, "retreat": 8, "wait": -12},
		"position_weights": {"flank": 8, "hold_line": 14, "protect_backline": 24, "keep_distance": 30, "avoid_threat": 16, "objective": 10},
		"thresholds": {"retreat_hp_pct": 18, "panic_morale": 10, "heal_ally_hp_pct": 50, "aoe_min_targets": 2, "preferred_distance": 4}
	},
	"mage_coven": {
		"profile_id": "mage_coven",
		"style_name": "法师公会",
		"description": "法力管理和 AOE。优先打密集目标，保护脆皮法师。",
		"target_weights": {"kill": 18, "low_hp": 12, "low_def": 14, "backline": 8, "healer": 18, "leader": 18, "nearest": -4, "threat": 22, "cluster": 34},
		"action_weights": {"damage": 22, "skill": 32, "control": 24, "buff": 16, "heal": 8, "survival": 18, "retreat": 10, "wait": 2},
		"position_weights": {"flank": -4, "hold_line": 6, "protect_backline": 30, "keep_distance": 28, "avoid_threat": 22, "objective": 8},
		"thresholds": {"retreat_hp_pct": 22, "panic_morale": 10, "heal_ally_hp_pct": 45, "aoe_min_targets": 2, "preferred_distance": 4}
	}
}

static func get_profile(profile_id: String) -> Dictionary:
	return PROFILES.get(profile_id, PROFILES[DEFAULT_PROFILE_ID])

static func get_profile_for_faction(faction_id: String) -> Dictionary:
	for profile_id in PROFILES.keys():
		var profile: Dictionary = PROFILES[profile_id]
		if str(profile.get("profile_id", "")) == faction_id or str(profile.get("faction_id", "")) == faction_id:
			return profile
	return PROFILES[DEFAULT_PROFILE_ID]
