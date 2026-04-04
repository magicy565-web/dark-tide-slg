## game_manager.gd - 暗潮 SLG orchestrator
## Delegates to subsystems: ResourceManager, FactionManager, OrderManager, ThreatManager, etc.
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")
const CombatSystem = preload("res://systems/combat/combat_system.gd")
const FixedMapData = preload("res://systems/map/fixed_map_data.gd")
const NationSystemClass = preload("res://systems/map/nation_system.gd")
const MultiRouteBattle = preload("res://systems/combat/multi_route_battle.gd")
const SkillAnimationData = preload("res://systems/combat/skill_animation_data.gd")
const TerritoryEffectsData = preload("res://systems/map/territory_effects.gd")
const TerritoryTypeSystem = preload("res://systems/map/territory_type_system.gd")

# ── Enums ──
enum TileType {
	LIGHT_STRONGHOLD, LIGHT_VILLAGE, DARK_BASE, MINE_TILE, FARM_TILE,
	WILDERNESS, EVENT_TILE, START, RESOURCE_STATION, CORE_FORTRESS, NEUTRAL_BASE,
	# v0.8.3 新增据点类型
	TRADING_POST, WATCHTOWER, RUINS, HARBOR, CHOKEPOINT
}

const TILE_NAMES: Dictionary = {
	TileType.LIGHT_STRONGHOLD: "光明要塞",
	TileType.LIGHT_VILLAGE: "光明村庄",
	TileType.DARK_BASE: "暗黑据点",
	TileType.MINE_TILE: "矿场",
	TileType.FARM_TILE: "农场",
	TileType.WILDERNESS: "荒野",
	TileType.EVENT_TILE: "事件点",
	TileType.START: "起点",
	TileType.RESOURCE_STATION: "资源站",
	TileType.CORE_FORTRESS: "核心要塞",
	TileType.NEUTRAL_BASE: "中立势力",
	TileType.TRADING_POST: "交易站",
	TileType.WATCHTOWER: "瞭望塔",
	TileType.RUINS: "遗迹",
	TileType.HARBOR: "港口",
	TileType.CHOKEPOINT: "关隘",
}

# ── Balance constants ──
const MAP_NODE_COUNT: int = 100
const BASE_AP: int = 2
const AP_PER_TILES: int = 7  # v4.6: 5→7 so +1 AP requires real expansion
const MAX_AP: int = 6
const COMBAT_POWER_PER_UNIT: int = BalanceConfig.COMBAT_POWER_PER_UNIT

# ── Army system constants (v0.9.2 → v2.1 unified with BalanceConfig) ──
# All values now delegate to BalanceConfig for single source of truth.
var MAX_ARMIES_BASE: int:
	get: return BalanceConfig.MAX_ARMIES_BASE
var MAX_ARMIES_UPGRADED: int:
	get: return BalanceConfig.MAX_ARMIES_UPGRADED
var MAX_TROOPS_PER_ARMY: int:
	get: return BalanceConfig.MAX_TROOPS_PER_ARMY

## v4.4: Effective max troops per army, considering garrison_bonus equipment passive.
func get_effective_max_troops(player_id: int) -> int:
	var base: int = BalanceConfig.MAX_TROOPS_PER_ARMY
	if player_id == get_human_player_id() and HeroSystem != null:
		for hid in HeroSystem.recruited_heroes:
			if HeroSystem.has_equipment_passive(hid, "garrison_bonus"):
				base += int(HeroSystem.get_equipment_passive_value(hid, "garrison_bonus"))
				break  # Only apply once
	return base
var MAX_HEROES_PER_ARMY: int:
	get: return BalanceConfig.MAX_HEROES_PER_ARMY

var UPGRADE_COSTS: Array:
	get: return BalanceConfig.UPGRADE_COSTS
var UPGRADE_PROD_MULT: Array:
	get: return BalanceConfig.UPGRADE_PROD_MULT
var MAX_TILE_LEVEL: int:
	get: return BalanceConfig.TILE_MAX_LEVEL

const PROD_RANGES: Dictionary = {
	TileType.LIGHT_STRONGHOLD: {"gold": [13, 17], "food": [2, 4], "iron": [4, 6], "pop": [3, 5]},
	TileType.LIGHT_VILLAGE:    {"gold": [8, 12], "food": [4, 6], "iron": [0, 2], "pop": [3, 5]},
	TileType.DARK_BASE:        {"gold": [6, 10], "food": [2, 3], "iron": [2, 4], "pop": [2, 4]},
	TileType.MINE_TILE:        {"gold": [2, 4], "food": [0, 1], "iron": [5, 8], "pop": [1, 2]},
	TileType.FARM_TILE:        {"gold": [2, 4], "food": [6, 9], "iron": [0, 1], "pop": [2, 3]},
	TileType.WILDERNESS:       {"gold": [1, 3], "food": [1, 2], "iron": [0, 1], "pop": [0, 1]},
	TileType.EVENT_TILE:       {"gold": [6, 10], "food": [2, 4], "iron": [0, 2], "pop": [1, 2]},
	TileType.START:            {"gold": [6, 9], "food": [2, 3], "iron": [1, 3], "pop": [2, 3]},
	TileType.RESOURCE_STATION: {"gold": [2, 3], "food": [0, 1], "iron": [1, 2], "pop": [0, 1]},
	TileType.CORE_FORTRESS:    {"gold": [15, 18], "food": [3, 5], "iron": [5, 7], "pop": [4, 6]},
	TileType.NEUTRAL_BASE:     {"gold": [6, 9], "food": [2, 3], "iron": [2, 4], "pop": [1, 3]},
	TileType.TRADING_POST:     {"gold": [10, 14], "food": [2, 3], "iron": [1, 2], "pop": [1, 2]},
	TileType.WATCHTOWER:       {"gold": [3, 5], "food": [1, 2], "iron": [1, 2], "pop": [1, 1]},
	TileType.RUINS:            {"gold": [4, 6], "food": [0, 1], "iron": [1, 3], "pop": [1, 1]},
	TileType.HARBOR:           {"gold": [8, 12], "food": [4, 7], "iron": [0, 1], "pop": [2, 3]},
	TileType.CHOKEPOINT:       {"gold": [3, 5], "food": [1, 2], "iron": [2, 5], "pop": [1, 2]},
}

# Light Alliance zone specs
const HUMAN_TILES: int = 14
const ELF_TILES: int = 7
const MAGE_TILES: int = 7
const DARK_TILES_EACH: int = 6
# Evil territory: per-faction sizes from FactionData (Orc:7 > Pirate:6 > DarkElf:5 = 18 ~18%)
const LIGHT_CORE_FORTRESS_COUNT: int = 7   # Only light fortresses placed in remaining pool
const OUTPOST_COUNT: int = 35
const RESOURCE_STATION_COUNT: int = 14
const NEUTRAL_BASE_COUNT: int = 10

# ── Core Fortress data ──
const CORE_FORTRESS_DEFS: Array = [
	# Light faction fortresses
	{
		"name": "奥德里安城", "faction": "human", "light_faction": 0,
		"garrison": 15, "wall_hp": 50,
		"effect": "adjacent_defense_20",
		"desc": "王都: 相邻2格人类据点防御+20%",
		"fall_effect": "human_morale_minus_30",
		"fall_desc": "攻破: 人类全据点士气-30%, 城防恢复减半",
	},
	{
		"name": "银冠要塞", "faction": "human", "light_faction": 0,
		"garrison": 10, "wall_hp": 35,
		"effect": "train_knight_per_turn",
		"desc": "每回合训练1骑士增援王都",
		"fall_effect": "stop_human_reinforcement",
		"fall_desc": "攻破: 人类停止自动增援",
	},
	{
		"name": "世界树圣地", "faction": "elf", "light_faction": 1,
		"garrison": 12, "wall_hp": 0,
		"effect": "barrier_double_leyline_hub",
		"desc": "魔法屏障×2; 树人守卫; 灵脉中枢",
		"fall_effect": "elf_lose_all_barriers",
		"fall_desc": "攻破: 精灵全据点失去屏障",
	},
	{
		"name": "奥术堡垒", "faction": "mage", "light_faction": 2,
		"garrison": 12, "wall_hp": 0,
		"effect": "mana_triple",
		"desc": "法力贡献×3; 大法师驻守",
		"fall_effect": "mana_pool_zero",
		"fall_desc": "攻破: 法力池归零且不再恢复",
	},
	{
		"name": "翡翠尖塔", "faction": "mage", "light_faction": 2,
		"garrison": 8, "wall_hp": 0,
		"effect": "mana_double_teleport",
		"desc": "法力贡献×2; 可施放传送",
		"fall_effect": "disable_teleport",
		"fall_desc": "攻破: 魔法师传送法术失效",
	},
	# Evil faction fortresses
	{
		"name": "碎骨王座", "faction": "orc", "evil_faction": 0,
		"garrison": 12, "wall_hp": 0,
		"effect": "waaagh_cap_plus_30",
		"desc": "WAAAGH!值上限+30; 可招募巨魔和战猪骑兵",
	},
	{
		"name": "深渊港", "faction": "pirate", "evil_faction": 1,
		"garrison": 10, "wall_hp": 0,
		"effect": "plunder_double_blackmarket",
		"desc": "掠夺值×2; 黑市自动运营; 可招募炮击手",
	},
	{
		"name": "永夜暗城", "faction": "dark_elf", "evil_faction": 2,
		"garrison": 14, "wall_hp": 0,
		"effect": "slave_cap_plus_10_temple_lv2",
		"desc": "奴隶上限+10; 苦痛神殿自带Lv2; 可招募冷蜥骑兵",
	},
	# New fortresses for expanded map
	{
		"name": "铁壁关", "faction": "human", "light_faction": 0,
		"garrison": 12, "wall_hp": 40,
		"effect": "chokepoint_defense_30",
		"desc": "关隘要塞: 驻军防御+30%, 相邻据点+10%",
		"fall_effect": "northern_route_open",
		"fall_desc": "攻破: 北方入侵路线开放",
	},
	{
		"name": "霜牙港", "faction": "pirate", "evil_faction": 1,
		"garrison": 10, "wall_hp": 0,
		"effect": "naval_supply_line",
		"desc": "北方海港: 海上补给线, 掠夺范围+1",
	},
	{
		"name": "月影祭坛", "faction": "dark_elf", "evil_faction": 2,
		"garrison": 11, "wall_hp": 0,
		"effect": "dark_ritual_shrine",
		"desc": "暗影祭坛: 每回合+1暗影精华, 黑暗仪式冷却-1",
	},
	{
		"name": "贤者之塔", "faction": "mage", "light_faction": 2,
		"garrison": 10, "wall_hp": 0,
		"effect": "sage_research",
		"desc": "贤者研究: 法力效率+25%, 可研究高级法术",
		"fall_effect": "sage_knowledge_lost",
		"fall_desc": "攻破: 高级法术研究中断",
	},
]

# ── Resource station type rotation ──
const STATION_TYPE_ROTATION: Array = ["magic_crystal", "war_horse", "gunpowder", "shadow_essence"]

# ── Event definitions (v0.7 binary choice system) ──
const EVENT_DEFS: Array = [
	# ── Universal events (1-10) ──
	{"id": 1, "name": "流民营地", "desc": "发现一群无家可归的难民",
		"option_a": {"label": "奴役: +3奴隶", "effects": {"slaves": 3}},
		"option_b": {"label": "屠杀: +2军队, 秩序-2", "effects": {"army": 2, "order": -2}}},
	{"id": 2, "name": "废弃矿洞", "desc": "发现一个废弃矿洞",
		"option_a": {"label": "深入开采: 60%+15铁 / 40%-2军队", "effects": {"iron": 15, "risk_army": -2, "success_rate": 0.6}},
		"option_b": {"label": "放弃", "effects": {}}},
	{"id": 3, "name": "瘟疫蔓延", "desc": "疫病在营地中蔓延",
		"option_a": {"label": "处决病奴: -3奴隶", "effects": {"slaves": -3}},
		"option_b": {"label": "隔离观察: -1军队/回合, 持续3回合", "effects": {"army_per_turn": -1, "duration": 3}}},
	{"id": 4, "name": "黑商来访", "desc": "一位神秘商人来访",
		"option_a": {"label": "购买: -50金, +随机道具", "effects": {"gold": -50, "random_item": 1}},
		"option_b": {"label": "劫掠: 70%+80金 / 30%-3军队", "effects": {"gold": 80, "risk_army": -3, "success_rate": 0.7}}},
	{"id": 5, "name": "远古遗迹", "desc": "发现远古遗迹入口",
		"option_a": {"label": "献祭探索: -5奴隶, +1遗物", "effects": {"slaves": -5, "relic": 1}},
		"option_b": {"label": "搜刮外围: +20铁 +10金", "effects": {"iron": 20, "gold": 10}}},
	{"id": 6, "name": "叛军残部", "desc": "遇到叛军残余势力",
		"option_a": {"label": "收编: +3军队, 秩序-1", "effects": {"army": 3, "order": -1}},
		"option_b": {"label": "招降: +2奴隶, 威望+3", "effects": {"slaves": 2, "prestige": 3}}},
	{"id": 7, "name": "暴风雪", "desc": "突如其来的暴风雪",
		"option_a": {"label": "原地驻扎: 无法移动, -5粮草", "effects": {"no_move": true, "food": -5}},
		"option_b": {"label": "强行军: 可移动, -2军队", "effects": {"army": -2}}},
	{"id": 8, "name": "奴隶献宝", "desc": "奴隶献上藏匿的财宝",
		"option_a": {"label": "收下: 70%+30金+10铁 / 30%-1奴隶", "effects": {"gold": 30, "iron": 10, "risk_slaves": -1, "success_rate": 0.7}},
		"option_b": {"label": "拒绝", "effects": {}}},
	{"id": 9, "name": "佣兵团", "desc": "遇到流浪佣兵团",
		"option_a": {"label": "雇佣: -80金, +5临时军队(5回合)", "effects": {"gold": -80, "temp_army": 5, "duration": 5}},
		"option_b": {"label": "放弃", "effects": {}}},
	{"id": 10, "name": "祭祀仪式", "desc": "发现古老祭坛",
		"option_a": {"label": "献祭: -2奴隶, +15%攻击(3回合)", "effects": {"slaves": -2, "atk_buff": 0.15, "duration": 3}},
		"option_b": {"label": "放弃: 秩序-2", "effects": {"order": -2}}},
	# ── Faction events (11-16) ──
	{"id": 11, "name": "内斗爆发", "desc": "部落内部爆发争斗", "faction": "orc",
		"option_a": {"label": "以力服人: -1军队, WAAAGH+15", "effects": {"army": -1, "waaagh": 15}},
		"option_b": {"label": "调解纷争: -3军队, 秩序+3", "effects": {"army": -3, "order": 3}}},
	{"id": 12, "name": "蘑菇酒宴", "desc": "部下要求举办蘑菇酒宴", "faction": "orc",
		"option_a": {"label": "狂欢: WAAAGH+20, 下回合无法移动", "effects": {"waaagh": 20, "no_move_next": true}},
		"option_b": {"label": "拒绝: +10粮草", "effects": {"food": 10}}},
	{"id": 13, "name": "沉船宝藏", "desc": "发现一艘沉船", "faction": "pirate",
		"option_a": {"label": "打捞: -10铁, +60金 +1道具", "effects": {"iron": -10, "gold": 60, "random_item": 1}},
		"option_b": {"label": "标记位置: 下次到访+30金", "effects": {"gold_next_visit": 30}}},
	{"id": 14, "name": "船员哗变", "desc": "船员不满要求加薪", "faction": "pirate",
		"option_a": {"label": "发放奖金: -30金", "effects": {"gold": -30}},
		"option_b": {"label": "镇压: -2军队, 掠夺+5", "effects": {"army": -2, "plunder": 5}}},
	{"id": 15, "name": "暗影低语", "desc": "黑暗中传来低语", "faction": "dark_elf",
		"option_a": {"label": "倾听: +1特殊NPC", "effects": {"special_npc": 1}},
		"option_b": {"label": "抵抗: -2奴隶, 秩序+2", "effects": {"slaves": -2, "order": 2}}},
	{"id": 16, "name": "议会阴谋", "desc": "议会中暗流涌动", "faction": "dark_elf",
		"option_a": {"label": "献祭刺探: -1奴隶, 揭示2格迷雾", "effects": {"slaves": -1, "reveal_fog": 2}},
		"option_b": {"label": "无视: 30%无事 / 70%失去1前哨", "effects": {"risk_outpost": -1, "success_rate": 0.3}}},
	# ── Light counterattack events (17-20) ──
	{"id": 17, "name": "圣骑士巡逻", "desc": "圣骑士部队出现在附近", "threat_min": 30,
		"option_a": {"label": "迎战: 与敌军(8)战斗", "effects": {"combat_enemy": 8}},
		"option_b": {"label": "撤退: 失去1前哨", "effects": {"lose_outpost": 1}}},
	{"id": 18, "name": "精灵诅咒", "desc": "精灵施放了诅咒", "threat_min": 30,
		"option_a": {"label": "花费解除: -20金", "effects": {"gold": -20}},
		"option_b": {"label": "忍受: -20%产出, 持续3回合", "effects": {"production_debuff": -0.2, "duration": 3}}},
	{"id": 19, "name": "奥术风暴", "desc": "法师塔释放奥术风暴", "threat_min": 30,
		"option_a": {"label": "硬扛: -4军队, 法师法力-20", "effects": {"army": -4, "mage_mana": -20}},
		"option_b": {"label": "躲避: -15%产出, 持续2回合", "effects": {"production_debuff": -0.15, "duration": 2}}},
	{"id": 20, "name": "光明联军通牒", "desc": "光明联军发出最后通牒", "threat_min": 30,
		"option_a": {"label": "无视: 威胁+10, 下回合被进攻", "effects": {"threat": 10, "attacked_next_turn": true}},
		"option_b": {"label": "妥协: 威胁-5, 2回合准备期", "effects": {"threat": -5, "prep_turns": 2}}},
]

# ── Item pool ──
const ITEM_POOL: Array = [
	{"id": "attack_totem", "name": "攻击图腾", "desc": "下次战斗攻击+30%", "effect": "atk_mult_1_3", "weight": 10},
	{"id": "iron_shield", "name": "铁壁盾牌", "desc": "下次战斗防御+30%", "effect": "def_mult_1_3", "weight": 10},
	{"id": "march_order", "name": "急行军令", "desc": "本回合骰子+2", "effect": "dice_bonus_2", "weight": 8},
	{"id": "gold_pouch", "name": "金币袋", "desc": "立即+50金币", "effect": "gold_50", "weight": 12},
	{"id": "ration_pack", "name": "军粮包", "desc": "立即+10粮草", "effect": "food_10", "weight": 12},
	{"id": "iron_ore", "name": "铁矿石", "desc": "立即+8铁矿", "effect": "iron_8", "weight": 12},
	{"id": "heal_potion", "name": "治愈药剂", "desc": "恢复3兵力", "effect": "heal_3", "weight": 8},
	{"id": "slave_shackle", "name": "奴隶枷锁", "desc": "下次战斗必定俘获1奴隶", "effect": "guaranteed_slave", "weight": 6},
]
# MAX_ITEMS removed – now managed by ItemManager.MAX_ITEMS

# ── Game state ──
var players: Array = []
var tiles: Array = []
var adjacency: Dictionary = {}
var current_player_index: int = 0
var game_active: bool = false
# Legacy - unused in action system
var dice_value: int = 0
var reachable_tiles: Array = []
var waiting_for_move: bool = false
var has_rolled: bool = false
var turn_number: int = 0
var _had_combat_this_turn: bool = false
var _prev_turn_had_combat: bool = false
var _ap_purchases_this_turn: int = 0
var _turn_cache: Dictionary = {}
var _active_territory_effects: Dictionary = {}  # Cached per-turn territory effects
var _sat_points: Dictionary = {}  # SAT (満足度) points: player_id -> int

# ── Fixed Map & Nation System (Direction D) ──
var use_fixed_map: bool = false
var nation_system: NationSystemClass = null  # Instantiated when use_fixed_map = true
var _guard_timers: Dictionary = {}  # tile_index -> { "player_id": int, "turns_remaining": int }

# ── Endgame Prestige Actions (v7.0) ──
var _last_grand_festival_turn: int = -999  # Turn when last grand festival was held
var _imperial_decree_used: bool = false     # Once per game
var _forge_alliance_used: bool = false      # Once per game

# ── Game Statistics (tracked for end-game score screen) ──
var game_stats: Dictionary = {
	"battles_won": 0,
	"battles_lost": 0,
	"capital_tile": -1,  # Starting tile index (set during init)
}

# ── Commander Tactical Orders (player session state) ──
# ── Pending random event choice (human player popup) ──
var _pending_choice_event: Dictionary = {}   # The event dict awaiting player choice
var _pending_choice_player: Dictionary = {}  # The player dict for that event
var _pending_event_queue: Array = []         # Queue of {event, player} if popup is busy
var _event_choice_connected: bool = false    # Guard against duplicate signal connections

# ── Unified event queue for EventScheduler (SR07-style sequential display) ──
var _scheduler_event_queue: Array = []       # Events selected by EventScheduler
var _scheduler_queue_connected: bool = false  # Guard for popup-closed signal

var _current_directive: int = 0  # CombatResolver.TacticalDirective.NONE
var _current_skill_timing: Dictionary = {}  # hero_id -> round number (0 = auto)
var _current_protected_slot: int = -1
var _current_decoy_slot: int = -1

# ── Army system state (v0.9.2) ──
# armies: { army_id: int -> { id, player_id, tile_index, name, troops: Array, heroes: Array } }
var armies: Dictionary = {}
var _next_army_id: int = 1
# Track which army is selected for current action (UI state)
var selected_army_id: int = -1

# Pre-battle slot assignment preferences per army
# army_id -> { troop_index: preferred_slot (0-5, where 0-2=front, 3-5=back) }
var army_slot_preferences: Dictionary = {}
# Temporary storage for slot prefs during combat resolution
var _combat_slot_prefs: Dictionary = {}

# Per-unit battle commands (set before combat)
# army_id -> { troop_index: UnitCommand enum value }
var army_unit_commands: Dictionary = {}
# Temporary storage for unit commands during combat resolution
var _combat_unit_commands: Dictionary = {}

# Player faction mapping
var _player_factions: Dictionary = {}   # player_id -> FactionData.FactionID

# ── Conquest choice state ──
var _pending_conquest_tile_index: int = -1
var _conquest_choice_connected: bool = false


## Set slot preference for a troop in an army (pre-battle formation assignment)
func set_troop_slot_preference(army_id: int, troop_index: int, slot: int) -> void:
	if not army_slot_preferences.has(army_id):
		army_slot_preferences[army_id] = {}
	army_slot_preferences[army_id][troop_index] = clampi(slot, 0, 5)


## Get slot preferences for an army
func get_army_slot_preferences(army_id: int) -> Dictionary:
	return army_slot_preferences.get(army_id, {})


## Clear slot preferences for an army
func clear_army_slot_preferences(army_id: int) -> void:
	army_slot_preferences.erase(army_id)


## Set per-unit command for pre-battle orders
func set_unit_command(army_id: int, troop_index: int, command: int) -> void:
	if not army_unit_commands.has(army_id):
		army_unit_commands[army_id] = {}
	army_unit_commands[army_id][troop_index] = command


## Get unit commands for an army
func get_army_unit_commands(army_id: int) -> Dictionary:
	return army_unit_commands.get(army_id, {})


## Clear unit commands
func clear_army_unit_commands(army_id: int) -> void:
	army_unit_commands.erase(army_id)


## Re-assign slot indices on attacker units based on player slot preferences.
## prefs: { troop_index(int) : preferred_slot(int 0-5) }
func _apply_slot_preferences_to_units(units: Array, prefs: Dictionary) -> void:
	if units.is_empty() or prefs.is_empty():
		return
	var pref_slots: Dictionary = {}  # slot -> unit index
	var unassigned: Array = []  # indices into units
	for i in range(units.size()):
		if prefs.has(i):
			var desired: int = prefs[i]
			if not pref_slots.has(desired):
				pref_slots[desired] = i
				units[i]["slot"] = desired
				units[i]["row"] = 0 if desired < 3 else 1
			else:
				unassigned.append(i)
		else:
			unassigned.append(i)
	# Assign remaining units to empty slots, preferring their current row
	var used: Dictionary = {}
	for s in pref_slots:
		used[s] = true
	for idx in unassigned:
		var cur_row: int = units[idx].get("row", 0)
		var start: int = 0 if cur_row == 0 else 3
		var end_s: int = 3 if cur_row == 0 else 6
		var placed: bool = false
		for s in range(start, end_s):
			if not used.has(s):
				units[idx]["slot"] = s
				units[idx]["row"] = 0 if s < 3 else 1
				used[s] = true
				placed = true
				break
		if not placed:
			for s in range(6):
				if not used.has(s):
					units[idx]["slot"] = s
					units[idx]["row"] = 0 if s < 3 else 1
					used[s] = true
					break


func _ready() -> void:
	if not _event_choice_connected:
		EventBus.event_choice_selected.connect(_on_random_event_choice)
		EventBus.event_combat_requested.connect(_on_event_combat_requested)
		# Fix #9: Connect province quick-action signal to central dispatcher
		EventBus.action_requested.connect(_on_action_requested)
		_event_choice_connected = true


# ═══════════════ PLAYER HELPERS ═══════════════

func get_human_player_id() -> int:
	for p in players:
		if not p.get("is_ai", true):
			return p["id"]
	return 0


func get_player_faction(player_id: int) -> int:
	return _player_factions.get(player_id, FactionData.FactionID.ORC)


func _get_faction_tag_for_player(player_id: int) -> String:
	var fid: int = get_player_faction(player_id)
	match fid:
		FactionData.FactionID.ORC: return "orc"
		FactionData.FactionID.PIRATE: return "pirate"
		FactionData.FactionID.DARK_ELF: return "dark_elf"
	return ""


func _get_faction_key(player_id: int) -> String:
	## Helper for AI indicator system — returns faction key string for signal emissions.
	return _get_faction_tag_for_player(player_id)


func _get_default_troop_id(faction_tag: String) -> String:
	## Returns the default (T1) infantry troop ID for a faction.
	## Used when seeding a newly created army with initial troops.
	match faction_tag:
		"orc": return "orc_warrior"
		"pirate": return "pirate_sailor"
		"dark_elf": return "dark_elf_soldier"
		"high_elf": return "high_elf_spearman"
		"mage": return "mage_apprentice"
		_: return "human_swordsman"


func get_player_by_id(player_id: int) -> Dictionary:
	for p in players:
		if p["id"] == player_id:
			return p
	push_warning("GameManager: get_player_by_id found no player with id=%d" % player_id)
	return {}


func sync_player_army(player_id: int) -> void:
	## Sync player dict army_count/combat_power from ResourceManager.
	var p: Dictionary = get_player_by_id(player_id)
	if p.is_empty():
		return
	p["army_count"] = ResourceManager.get_army(player_id)
	p["combat_power"] = p["army_count"] * COMBAT_POWER_PER_UNIT


func get_current_player() -> Dictionary:
	if players.is_empty():
		push_warning("GameManager: get_current_player called but players array is empty")
		return {}
	if current_player_index < 0 or current_player_index >= players.size():
		push_warning("GameManager: get_current_player invalid index %d (players size: %d)" % [current_player_index, players.size()])
		return {}
	return players[current_player_index]


func count_tiles_owned(player_id: int) -> int:
	var c: int = 0
	for tile in tiles:
		if tile.get("owner_id", -1) == player_id:
			c += 1
	return c


func count_strongholds_owned(player_id: int) -> int:
	var c: int = 0
	for tile in tiles:
		if tile.get("owner_id", -1) == player_id and tile.get("type", -1) == TileType.LIGHT_STRONGHOLD:
			c += 1
	return c


func get_total_strongholds() -> int:
	var c: int = 0
	for tile in tiles:
		if tile.get("type", -1) == TileType.LIGHT_STRONGHOLD:
			c += 1
	return c


func get_stronghold_progress(player_id: int) -> String:
	return "%d/%d" % [count_strongholds_owned(player_id), get_total_strongholds()]


func get_population_cap(player_id: int) -> int:
	var total_pop: int = BalanceConfig.BASE_POPULATION_CAP
	for tile in tiles:
		if tile.get("owner_id", -1) == player_id:
			var prod: Dictionary = tile.get("base_production", {})
			total_pop += prod.get("pop", 0)
			# Training ground bonus
			if tile.get("building_id", "") == "training_ground":
				total_pop += 2
	return total_pop


func calculate_action_points(player_id: int) -> int:
	var owned: int = count_tiles_owned(player_id)
	var ap: int = BASE_AP + owned / AP_PER_TILES + NgPlusManager.get_bonus_ap()
	return mini(ap, MAX_AP)


## BUG FIX R11: get_army_count was referenced by production_calculator but never defined
func get_army_count(player_id: int) -> int:
	var count: int = 0
	for army_id in armies:
		if armies[army_id].get("player_id", -1) == player_id:
			count += 1
	return count


func get_tile_production(tile: Dictionary) -> Dictionary:
	var base: Dictionary = tile.get("base_production", {})
	var level: int = maxi(tile.get("level", 1), 1)
	# BUG FIX R11: bounds-check level against UPGRADE_PROD_MULT size
	var level_idx: int = clampi(level - 1, 0, UPGRADE_PROD_MULT.size() - 1) if UPGRADE_PROD_MULT.size() > 0 else 0
	var mult: float = UPGRADE_PROD_MULT[level_idx] if UPGRADE_PROD_MULT.size() > 0 else 1.0
	# SR07: Apply garrison commander production bonus
	var cmd_bonus: Dictionary = HeroSystem.get_garrison_commander_bonus(tile.get("index", -1)) if HeroSystem != null else {}
	var cmd_mult: float = cmd_bonus.get("prod_mult", 1.0)
	# 战国兰斯式重构: 据点类型产出加成
	var type_prod_mult: float = 1.0
	var TTS = TerritoryTypeSystem
	if TTS != null:
		var prov_type: int = TTS.get_prov_type_from_tile(tile)
		var bonuses: Dictionary = TTS.get_bonuses(prov_type)
		type_prod_mult = bonuses.get("gold_mult", 1.0) if bonuses.has("gold_mult") else 1.0
		# 城镇金币加成、资源据点铁矿加成等均在此应用
		var food_mult: float = bonuses.get("food_mult", 1.0) if bonuses.has("food_mult") else 1.0
		var iron_mult: float = bonuses.get("iron_mult", 1.0) if bonuses.has("iron_mult") else 1.0
		return {
			"gold": int(float(base.get("gold", 0)) * mult * cmd_mult * type_prod_mult),
			"food": int(float(base.get("food", 0)) * mult * cmd_mult * food_mult),
			"iron": int(float(base.get("iron", 0)) * mult * cmd_mult * iron_mult),
			"pop":  base.get("pop", 0),
			"prov_type": prov_type,
		}
	return {
		"gold": int(float(base.get("gold", 0)) * mult * cmd_mult),
		"food": int(float(base.get("food", 0)) * mult * cmd_mult),
		"iron": int(float(base.get("iron", 0)) * mult * cmd_mult),
		"pop":  base.get("pop", 0),
	}


# ═══════════════ MAP GENERATION (100 nodes) ═══════════════

# Region definitions for the expanded map (6 provinces)
const MAP_REGIONS: Array = [
	{"id": "northern_wastes", "name": "北方荒原", "center": Vector3(13.0, 0, -1.5)},
	{"id": "deep_coast", "name": "深海沿岸", "center": Vector3(2.5, 0, -10.0)},
	{"id": "eternal_night", "name": "永夜密林", "center": Vector3(5.0, 0, -21.0)},
	{"id": "radiant_kingdom", "name": "光辉王国", "center": Vector3(13.0, 0, -10.0)},
	{"id": "eastern_highlands", "name": "东方高地", "center": Vector3(23.0, 0, -7.0)},
	{"id": "southern_ruins", "name": "南方废墟", "center": Vector3(20.0, 0, -21.0)},
]

func _assign_tile_region(pos: Vector3) -> Dictionary:
	## Return {"region_id": ..., "region_name": ...} for the nearest region.
	var best: Dictionary = MAP_REGIONS[0]
	var best_dist: float = INF
	for region in MAP_REGIONS:
		var d: float = pos.distance_to(region["center"])
		if d < best_dist:
			best_dist = d
			best = region
	return {"region_id": best["id"], "region_name": best["name"]}

func generate_map() -> void:
	tiles.clear()
	adjacency.clear()

	var positions: Array = _place_nodes()
	var all_edges: Array = _compute_all_edges(positions)
	var mst: Array = _build_mst(all_edges, positions.size())
	var final_edges: Array = _add_extra_edges(positions, mst)

	for edge in final_edges:
		var a: int = edge[0]
		var b: int = edge[1]
		if not adjacency.has(a):
			adjacency[a] = []
		if not adjacency.has(b):
			adjacency[b] = []
		if not adjacency[a].has(b):
			adjacency[a].append(b)
		if not adjacency[b].has(a):
			adjacency[b].append(a)

	_assign_tile_types(positions)


func generate_fixed_map() -> void:
	## Generate map from FixedMapData (55 hand-designed territories in 7 nations).
	tiles.clear()
	adjacency.clear()

	var type_map: Dictionary = {
		"FORTRESS": TileType.CORE_FORTRESS,
		"VILLAGE": TileType.LIGHT_VILLAGE,
		"OUTPOST": TileType.WATCHTOWER,
		"BANDIT": TileType.WILDERNESS,
		"RESOURCE": TileType.RESOURCE_STATION,
	}
	var faction_owner_map: Dictionary = {
		"HUMAN": 100, "HIGH_ELF": 101, "MAGE": 102,
		"ORC": FactionData.FactionID.ORC,
		"PIRATE": FactionData.FactionID.PIRATE,
		"DARK_ELF": FactionData.FactionID.DARK_ELF,
		"NEUTRAL": -1, "BANDIT": -1,
	}

	for t in FixedMapData.TERRITORIES:
		var tile: Dictionary = {
			"type": type_map.get(t["type"], TileType.WILDERNESS),
			"owner": faction_owner_map.get(t["faction"], -1),
			"position": t["position"],
			"position_3d": Vector3(t["position"].x * 0.02, 0.0, -t["position"].y * 0.02),
			"level": t["level"],
			"garrison": t["garrison_base"],
			"city_def": t.get("city_def", 0),
			"name": t["name"],
			"terrain": t.get("terrain", "PLAINS"),
			"buildings": [],
			"order": 80,
			"revealed": {},
			"nation_id": t["nation_id"],
			"is_capital": t.get("is_capital", false),
			"is_chokepoint": t.get("is_chokepoint", false),
			"resource_type": t.get("resource_type", ""),
			"description": t.get("description", ""),
		}
		tiles.append(tile)

	# Build adjacency from FixedMapData connections
	adjacency = FixedMapData.build_adjacency()

	# Initialize Nation System
	nation_system = NationSystemClass.new()
	nation_system.initialize(EventBus)

	use_fixed_map = true


func _place_nodes() -> Array:
	var positions: Array = []
	var cols: int = 11
	var rows: int = 10
	var spacing_x: float = 2.6
	var spacing_z: float = 2.6
	var jitter: float = 0.6

	for row in range(rows):
		for col in range(cols):
			var base_x: float = col * spacing_x
			var base_z: float = -row * spacing_z
			positions.append(Vector3(
				base_x + randf_range(-jitter, jitter),
				0.0,
				base_z + randf_range(-jitter, jitter)
			))

	while positions.size() > MAP_NODE_COUNT:
		positions.pop_back()
	return positions


func _compute_all_edges(positions: Array) -> Array:
	var edges: Array = []
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var dist: float = positions[i].distance_to(positions[j])
			edges.append([i, j, dist])
	edges.sort_custom(func(a, b): return a[2] < b[2])
	return edges


func _build_mst(sorted_edges: Array, node_count: int) -> Array:
	var parent: Array = []
	for i in range(node_count):
		parent.append(i)
	var mst_edges: Array = []
	for edge in sorted_edges:
		var a: int = edge[0]
		var b: int = edge[1]
		var ra: int = _find_root(parent, a)
		var rb: int = _find_root(parent, b)
		if ra != rb:
			parent[ra] = rb
			mst_edges.append([a, b])
			if mst_edges.size() == node_count - 1:
				break
	return mst_edges


func _find_root(parent: Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


func _find_troop_training_panel():
	## Locate the TroopTrainingPanel node in the scene tree.
	var scene = get_tree().current_scene
	if scene and "troop_training_panel" in scene and scene.troop_training_panel:
		return scene.troop_training_panel
	return null


func _add_extra_edges(positions: Array, mst: Array) -> Array:
	var edge_set: Dictionary = {}
	for edge in mst:
		var key: String = "%d_%d" % [mini(edge[0], edge[1]), maxi(edge[0], edge[1])]
		edge_set[key] = true

	var extras: Array = []
	var target_extras: int = int(positions.size() * 0.45)

	for i in range(positions.size()):
		var neighbors: Array = []
		for j in range(positions.size()):
			if i == j:
				continue
			neighbors.append([j, positions[i].distance_to(positions[j])])
		neighbors.sort_custom(func(a, b): return a[1] < b[1])

		for nb in neighbors:
			if extras.size() >= target_extras:
				break
			var j: int = nb[0]
			var key: String = "%d_%d" % [mini(i, j), maxi(i, j)]
			if not edge_set.has(key) and nb[1] < 7.0:
				edge_set[key] = true
				extras.append([i, j])
				break
		if extras.size() >= target_extras:
			break

	var result: Array = []
	result.append_array(mst)
	result.append_array(extras)
	return result


func _assign_tile_types(positions: Array) -> void:
	var count: int = positions.size()

	# Cluster tiles into zones by position
	# Top-right = Human Kingdom, Left = High Elves, Bottom = Fur Folk
	# Dark factions get corners/edges
	var indices: Array = range(count)

	# Sort by x then z for zone assignment
	var sorted_by_pos: Array = indices.duplicate()
	sorted_by_pos.sort_custom(func(a, b):
		var pa: Vector3 = positions[a]
		var pb: Vector3 = positions[b]
		return pa.x + pa.z * 0.5 < pb.x + pb.z * 0.5
	)

	var type_assign: Dictionary = {}
	var assigned: Dictionary = {}
	var idx_cursor: int = 0

	# ── Light Alliance zones ──
	# Human Kingdom: rightmost cluster -> strongholds + villages
	var human_zone: Array = _pick_cluster(sorted_by_pos, positions, HUMAN_TILES, Vector3(20.0, 0, -6.0), assigned)
	# First 3 are strongholds
	for i in range(human_zone.size()):
		assigned[human_zone[i]] = true
		if i < 3:
			type_assign[human_zone[i]] = TileType.LIGHT_STRONGHOLD
		else:
			type_assign[human_zone[i]] = TileType.LIGHT_VILLAGE

	# High Elves: top-left
	var elf_zone: Array = _pick_cluster(sorted_by_pos, positions, ELF_TILES, Vector3(3.0, 0, -1.0), assigned)
	for i in range(elf_zone.size()):
		assigned[elf_zone[i]] = true
		if i < 2:
			type_assign[elf_zone[i]] = TileType.LIGHT_STRONGHOLD
		else:
			type_assign[elf_zone[i]] = TileType.LIGHT_VILLAGE

	# Mage Tower: bottom-center (replaces Fur Folk)
	var mage_zone: Array = _pick_cluster(sorted_by_pos, positions, MAGE_TILES, Vector3(12.0, 0, -20.0), assigned)
	for i in range(mage_zone.size()):
		assigned[mage_zone[i]] = true
		if i < 2:
			type_assign[mage_zone[i]] = TileType.LIGHT_STRONGHOLD
		else:
			type_assign[mage_zone[i]] = TileType.LIGHT_VILLAGE

	# ── Dark faction starting zones (6 tiles each) ──
	var orc_zone: Array = _pick_cluster(sorted_by_pos, positions, DARK_TILES_EACH + 1, Vector3(0.0, 0, -14.0), assigned)
	var _orc_faction_map: Dictionary = {}
	for i in range(orc_zone.size()):
		assigned[orc_zone[i]] = true
		type_assign[orc_zone[i]] = TileType.DARK_BASE
		_orc_faction_map[orc_zone[i]] = "orc"

	var pirate_zone: Array = _pick_cluster(sorted_by_pos, positions, DARK_TILES_EACH, Vector3(24.0, 0, -20.0), assigned)
	var _pirate_faction_map: Dictionary = {}
	for i in range(pirate_zone.size()):
		assigned[pirate_zone[i]] = true
		type_assign[pirate_zone[i]] = TileType.DARK_BASE
		_pirate_faction_map[pirate_zone[i]] = "pirate"

	var delf_zone: Array = _pick_cluster(sorted_by_pos, positions, DARK_TILES_EACH - 1, Vector3(14.0, 0, -1.0), assigned)
	var _delf_faction_map: Dictionary = {}
	for i in range(delf_zone.size()):
		assigned[delf_zone[i]] = true
		type_assign[delf_zone[i]] = TileType.DARK_BASE
		_delf_faction_map[delf_zone[i]] = "dark_elf"

	# Store zone info for player placement
	_zone_cache = {
		"orc": orc_zone,
		"pirate": pirate_zone,
		"dark_elf": delf_zone,
	}

	# ── Remaining tiles: resource stations, neutral bases, mines, farms, events, wilderness ──
	var remaining: Array = []
	for i in range(count):
		if not assigned.has(i):
			remaining.append(i)
	remaining.shuffle()

	var ri: int = 0
	# ── Core Fortresses ──
	var fortress_count: int = mini(LIGHT_CORE_FORTRESS_COUNT, remaining.size() - ri)
	for j in range(fortress_count):
		if ri < remaining.size():
			type_assign[remaining[ri]] = TileType.CORE_FORTRESS
			ri += 1

	# ~10 resource stations (cycling through 4 strategic resource types)
	var station_count: int = mini(RESOURCE_STATION_COUNT, remaining.size() - ri)
	for j in range(station_count):
		if ri < remaining.size():
			type_assign[remaining[ri]] = TileType.RESOURCE_STATION
			ri += 1
	# ~6 neutral bases
	var neutral_count: int = mini(NEUTRAL_BASE_COUNT, remaining.size() - ri)
	for _j in range(neutral_count):
		if ri < remaining.size():
			type_assign[remaining[ri]] = TileType.NEUTRAL_BASE
			ri += 1
	# ~6 mines
	for _j in range(6):
		if ri < remaining.size():
			type_assign[remaining[ri]] = TileType.MINE_TILE
			ri += 1
	# ~6 farms
	for _j in range(6):
		if ri < remaining.size():
			type_assign[remaining[ri]] = TileType.FARM_TILE
			ri += 1
	# ~5 events
	for _j in range(5):
		if ri < remaining.size():
			type_assign[remaining[ri]] = TileType.EVENT_TILE
			ri += 1
	# v0.8.3: New tile subtypes
	# ~4 trading posts
	for _j in range(4):
		if ri < remaining.size():
			type_assign[remaining[ri]] = TileType.TRADING_POST
			ri += 1
	# ~4 watchtowers
	for _j in range(4):
		if ri < remaining.size():
			type_assign[remaining[ri]] = TileType.WATCHTOWER
			ri += 1
	# ~4 ruins
	for _j in range(4):
		if ri < remaining.size():
			type_assign[remaining[ri]] = TileType.RUINS
			ri += 1
	# ~3 harbors
	for _j in range(3):
		if ri < remaining.size():
			type_assign[remaining[ri]] = TileType.HARBOR
			ri += 1
	# ~6 chokepoints (strategic passes)
	for _j in range(6):
		if ri < remaining.size():
			type_assign[remaining[ri]] = TileType.CHOKEPOINT
			ri += 1
	# Rest = wilderness
	while ri < remaining.size():
		type_assign[remaining[ri]] = TileType.WILDERNESS
		ri += 1

	# Build tile data
	var station_idx: int = 0
	var neutral_faction_idx: int = 0
	var core_fortress_idx: int = 0
	var neutral_faction_keys: Array = [
		FactionData.NeutralFaction.IRONHAMMER_DWARF,
		FactionData.NeutralFaction.WANDERING_CARAVAN,
		FactionData.NeutralFaction.NECROMANCER,
		FactionData.NeutralFaction.FOREST_RANGER,
		FactionData.NeutralFaction.BLOOD_MOON_CULT,
		FactionData.NeutralFaction.GOBLIN_ENGINEER,
	]

	for i in range(count):
		var tile_type: int = type_assign.get(i, TileType.WILDERNESS)
		var garrison: int = 0
		var resource_station_type: String = ""
		var neutral_faction_id: int = -1
		var core_fortress_name: String = ""
		var core_fortress_effect: String = ""
		var core_fortress_wall_hp: int = 0
		var core_fortress_fall_effect: String = ""
		var original_faction: int = -1

		match tile_type:
			TileType.LIGHT_STRONGHOLD:
				garrison = randi_range(40, 65)
			TileType.LIGHT_VILLAGE:
				garrison = randi_range(15, 25)
			TileType.RESOURCE_STATION:
				garrison = randi_range(10, 20)
				resource_station_type = STATION_TYPE_ROTATION[station_idx % STATION_TYPE_ROTATION.size()]
				station_idx += 1
			TileType.CORE_FORTRESS:
				var fort_def: Dictionary = CORE_FORTRESS_DEFS[core_fortress_idx % CORE_FORTRESS_DEFS.size()]
				garrison = fort_def["garrison"]
				core_fortress_name = fort_def["name"]
				core_fortress_effect = fort_def["effect"]
				core_fortress_wall_hp = fort_def.get("wall_hp", 0)
				core_fortress_fall_effect = fort_def.get("fall_effect", "")
				if fort_def.has("evil_faction"):
					match fort_def["faction"]:
						"orc": original_faction = FactionData.FactionID.ORC
						"pirate": original_faction = FactionData.FactionID.PIRATE
						"dark_elf": original_faction = FactionData.FactionID.DARK_ELF
					# Light factions keep original_faction = -1
				core_fortress_idx += 1
			TileType.NEUTRAL_BASE:
				garrison = randi_range(15, 30)
				if neutral_faction_idx < neutral_faction_keys.size():
					neutral_faction_id = neutral_faction_keys[neutral_faction_idx]
					neutral_faction_idx += 1
			# v0.8.3: New tile subtypes
			TileType.TRADING_POST:
				garrison = randi_range(3, 6)
			TileType.WATCHTOWER:
				garrison = randi_range(3, 5)
			TileType.RUINS:
				garrison = randi_range(6, 10)
			TileType.HARBOR:
				garrison = randi_range(3, 6)
			TileType.CHOKEPOINT:
				garrison = randi_range(8, 12)

		var prod_range: Dictionary = PROD_RANGES.get(tile_type, PROD_RANGES[TileType.WILDERNESS])
		var base_prod: Dictionary = {
			"gold": randi_range(prod_range["gold"][0], prod_range["gold"][1]),
			"food": randi_range(prod_range["food"][0], prod_range["food"][1]),
			"iron": randi_range(prod_range["iron"][0], prod_range["iron"][1]),
			"pop":  randi_range(prod_range["pop"][0], prod_range["pop"][1]),
		}

		var tile_name: String = TILE_NAMES.get(tile_type, "未知") + " #" + str(i)
		if core_fortress_name != "":
			tile_name = core_fortress_name
		elif resource_station_type != "":
			for sdef in FactionData.RESOURCE_STATION_TYPES:
				if sdef["type"] == resource_station_type:
					tile_name = sdef["name"] + " #" + str(i)
					break
		elif neutral_faction_id >= 0:
			tile_name = FactionData.NEUTRAL_FACTION_NAMES.get(neutral_faction_id, "中立势力") + " #" + str(i)

		var _region_data: Dictionary = _assign_tile_region(positions[i])

		tiles.append({
			"index": i,
			"type": tile_type,
			"name": tile_name,
			"position_3d": positions[i],
			"owner_id": -1,
			"garrison": garrison,
			"revealed": {},
			"base_production": base_prod,
			"level": 1,
			"building_id": "",
			"building_level": 1,
			"light_faction": -1,
			"resource_station_type": resource_station_type,
			"neutral_faction_id": neutral_faction_id,
			"core_fortress_effect": core_fortress_effect,
			"core_fortress_wall_hp": core_fortress_wall_hp,
			"core_fortress_fall_effect": core_fortress_fall_effect,
			"original_faction": original_faction,
			# v0.8.3: Terrain system fields (assigned by _assign_terrain())
			"terrain": FactionData.TerrainType.PLAINS,
			"is_chokepoint": tile_type == TileType.CHOKEPOINT,
			"terrain_move_cost": 1,
			"named_outpost_id": "",
		"public_order": BalanceConfig.TILE_ORDER_DEFAULT,
			# Runtime fields used by subsystems (initialized for safety)
			"wall_hp": core_fortress_wall_hp,
			"alliance_def_bonus": 0,
			# Region data for strategic map display
			"region_id": _region_data["region_id"],
			"region_name": _region_data["region_name"],
			"is_region_border": false,
		})

	# Mark light faction ownership on tiles
	for idx in human_zone:
		tiles[idx]["light_faction"] = FactionData.LightFaction.HUMAN_KINGDOM
	for idx in elf_zone:
		tiles[idx]["light_faction"] = FactionData.LightFaction.HIGH_ELVES
	for idx in mage_zone:
		tiles[idx]["light_faction"] = FactionData.LightFaction.MAGE_TOWER

	# Mark dark faction original_faction on DARK_BASE tiles
	for idx in orc_zone:
		tiles[idx]["original_faction"] = FactionData.FactionID.ORC
	for idx in pirate_zone:
		tiles[idx]["original_faction"] = FactionData.FactionID.PIRATE
	for idx in delf_zone:
		tiles[idx]["original_faction"] = FactionData.FactionID.DARK_ELF

	# v0.8.3: Terrain & chokepoint assignment
	_assign_terrain()
	_assign_chokepoints()
	_fortify_region_borders()


var _zone_cache: Dictionary = {}


func _pick_cluster(sorted_indices: Array, positions: Array, count_needed: int, center: Vector3, already: Dictionary) -> Array:
	## Pick `count_needed` tiles closest to `center` that aren't already assigned.
	var candidates: Array = []
	for idx in sorted_indices:
		if already.has(idx):
			continue
		candidates.append([idx, positions[idx].distance_to(center)])
	candidates.sort_custom(func(a, b): return a[1] < b[1])
	var result: Array = []
	for c in candidates:
		if result.size() >= count_needed:
			break
		result.append(c[0])
	return result


# ═══════════════ TERRAIN ASSIGNMENT (v0.8.3) ═══════════════

func _assign_terrain() -> void:
	## Assign TerrainType to every tile based on zone and tile type.
	## Called after tile generation so tiles[] is populated.
	var named_outpost_pool: Array = FactionData.NAMED_OUTPOSTS.duplicate()
	named_outpost_pool.shuffle()

	for tile in tiles:
		var tt: int = tile["type"]
		var zone_key: String = _get_tile_zone_key(tile)

		# Forced terrain for specific tile types
		match tt:
			TileType.CORE_FORTRESS:
				tile["terrain"] = FactionData.TerrainType.FORTRESS_WALL
			TileType.LIGHT_STRONGHOLD:
				tile["terrain"] = _weighted_pick([0.15, 0.0, 0.10, 0.0, 0.0, 0.75])
			TileType.MINE_TILE:
				tile["terrain"] = FactionData.TerrainType.MOUNTAIN
			TileType.FARM_TILE:
				tile["terrain"] = FactionData.TerrainType.PLAINS
			TileType.HARBOR:
				tile["terrain"] = FactionData.TerrainType.COASTAL
			TileType.CHOKEPOINT:
				tile["terrain"] = _weighted_pick([0.0, 0.15, 0.55, 0.20, 0.0, 0.10])
				tile["is_chokepoint"] = true
			_:
				var weights: Array = FactionData.TERRAIN_ZONE_WEIGHTS.get(zone_key, FactionData.TERRAIN_ZONE_WEIGHTS["neutral"])
				tile["terrain"] = _weighted_pick(weights)

		# Cache move cost from terrain data
		var tdata: Dictionary = FactionData.TERRAIN_DATA.get(tile["terrain"], {})
		tile["terrain_move_cost"] = tdata.get("move_cost", 1)

		# Apply named outpost data to matching new tile types
		if tt in [TileType.TRADING_POST, TileType.WATCHTOWER, TileType.RUINS, TileType.HARBOR, TileType.CHOKEPOINT]:
			var type_key: String = _tile_type_to_named_key(tt)
			for ni in range(named_outpost_pool.size()):
				if named_outpost_pool[ni]["tile_type"] == type_key:
					var nd: Dictionary = named_outpost_pool[ni]
					tile["name"] = nd["name"]
					tile["named_outpost_id"] = nd["id"]
					tile["terrain"] = nd.get("terrain", tile["terrain"])
					tile["terrain_move_cost"] = FactionData.TERRAIN_DATA.get(tile["terrain"], {}).get("move_cost", 1)
					if nd.has("garrison"):
						tile["garrison"] = nd["garrison"]
					if nd.has("is_chokepoint"):
						tile["is_chokepoint"] = nd["is_chokepoint"]
					if nd.has("prod"):
						tile["base_production"] = nd["prod"].duplicate()
					named_outpost_pool.remove_at(ni)
					break

	# Apply chokepoint garrison bonus
	for tile in tiles:
		if tile["is_chokepoint"]:
			tile["garrison"] += FactionData.CHOKEPOINT_DATA["garrison_bonus"]


func _assign_chokepoints() -> void:
	## Identify additional natural chokepoints based on graph topology.
	## Tiles with low adjacency degree + defensive terrain become chokepoints.
	var existing_count: int = 0
	for tile in tiles:
		if tile["is_chokepoint"]:
			existing_count += 1

	var max_cp: int = FactionData.CHOKEPOINT_DATA["max_chokepoints"]
	if existing_count >= max_cp:
		return

	var candidates: Array = []
	for tile in tiles:
		if tile["is_chokepoint"]:
			continue
		if tile["type"] in [TileType.CORE_FORTRESS, TileType.NEUTRAL_BASE]:
			continue

		var degree: int = adjacency.get(tile["index"], []).size()
		if degree < FactionData.CHOKEPOINT_DATA["min_degree"] or degree > FactionData.CHOKEPOINT_DATA["max_degree"]:
			continue

		# Score: lower degree + defensive terrain = better chokepoint
		var score: float = (4.0 - float(degree)) * 2.0
		match tile["terrain"]:
			FactionData.TerrainType.MOUNTAIN:
				score += 3.0
			FactionData.TerrainType.FORTRESS_WALL:
				score += 2.5
			FactionData.TerrainType.FOREST:
				score += 1.5
			FactionData.TerrainType.SWAMP:
				score += 1.0
		candidates.append({"idx": tile["index"], "score": score})

	candidates.sort_custom(func(a, b): return a["score"] > b["score"])

	var to_add: int = mini(max_cp - existing_count, candidates.size())
	for ci in range(to_add):
		var idx: int = candidates[ci]["idx"]
		tiles[idx]["is_chokepoint"] = true
		tiles[idx]["garrison"] += FactionData.CHOKEPOINT_DATA["garrison_bonus"]


func _fortify_region_borders() -> void:
	## Boost garrison for tiles at region borders (connecting different regions).
	## These natural chokepoints between regions get extra defenders.
	for tile in tiles:
		var idx: int = tile["index"]
		var my_region: String = tile.get("region_id", "")
		if my_region == "":
			continue
		var neighbors: Array = adjacency.get(idx, [])
		var is_border: bool = false
		for nb in neighbors:
			if nb < tiles.size():
				var nb_region: String = tiles[nb].get("region_id", "")
				if nb_region != "" and nb_region != my_region:
					is_border = true
					break
		if is_border:
			# Border tiles get +3 garrison and are marked
			tile["garrison"] += 3
			tile["is_region_border"] = true
			# If not already a chokepoint and has low degree, mark as chokepoint
			if not tile["is_chokepoint"] and neighbors.size() <= 3:
				tile["is_chokepoint"] = true
				tile["garrison"] += 2


func _get_tile_zone_key(tile: Dictionary) -> String:
	## Determine which faction zone a tile belongs to for terrain weighting.
	if tile.get("light_faction", -1) == FactionData.LightFaction.HUMAN_KINGDOM:
		return "human"
	if tile.get("light_faction", -1) == FactionData.LightFaction.HIGH_ELVES:
		return "elf"
	if tile.get("light_faction", -1) == FactionData.LightFaction.MAGE_TOWER:
		return "mage"
	var of: int = tile.get("original_faction", -1)
	if of == FactionData.FactionID.ORC:
		return "orc"
	if of == FactionData.FactionID.PIRATE:
		return "pirate"
	if of == FactionData.FactionID.DARK_ELF:
		return "dark_elf"
	return "neutral"


func _weighted_pick(weights: Array) -> int:
	## Weighted random selection. Returns index (= TerrainType enum value).
	var total: float = 0.0
	for w in weights:
		total += w
	var roll: float = randf() * total
	var accum: float = 0.0
	for i in range(weights.size()):
		accum += weights[i]
		if roll <= accum:
			return i
	return weights.size() - 1


func _tile_type_to_named_key(tt: int) -> String:
	match tt:
		TileType.TRADING_POST: return "TRADING_POST"
		TileType.WATCHTOWER: return "WATCHTOWER"
		TileType.RUINS: return "RUINS"
		TileType.HARBOR: return "HARBOR"
		TileType.CHOKEPOINT: return "CHOKEPOINT"
	return ""


# ═══════════════ GAME FLOW ═══════════════

func start_game(chosen_faction: int = FactionData.FactionID.ORC, fixed_map: bool = false) -> void:
	## Call with faction ID to start a new game. fixed_map=true uses 55-territory hand-designed map.
	if fixed_map:
		generate_fixed_map()
	else:
		generate_map()
	players.clear()
	_player_factions.clear()
	armies.clear()
	_next_army_id = 1
	selected_army_id = -1
	_sat_points.clear()
	_pending_conquest_tile_index = -1
	_last_grand_festival_turn = -999
	_imperial_decree_used = false
	_forge_alliance_used = false
	turn_number = 0

	# Reset all subsystems
	ResourceManager.reset()
	SlaveManager.reset()
	FactionManager.reset()
	OrderManager.reset()
	ThreatManager.reset()
	BuffManager.reset()
	ItemManager.reset()
	RelicManager.reset()
	NpcManager.reset()
	QuestManager.reset()
	RecruitManager.reset()
	DiplomacyManager.reset()
	StrategicResourceManager.reset()
	AllianceAI.reset()
	EvilFactionAI.reset()
	LightFactionAI.reset()
	AIStrategicPlanner.reset()
	StoryEventSystem.reset()
	if EquipmentForge != null:
		EquipmentForge.reset()
	# OrcMechanic/PirateMechanic/DarkElfMechanic reset via FactionManager.reset() above

	# ── Create human player ──
	var human_start_res: Dictionary = FactionData.STARTING_RESOURCES[chosen_faction]
	var human_start_tile: int = _get_zone_start(chosen_faction)

	players.append({
		"id": 0, "name": FactionData.FACTION_NAMES[chosen_faction], "is_ai": false,
		"position": human_start_tile, "ap": BASE_AP,
		"color": FactionData.FACTION_COLORS[chosen_faction],
		"atk_bonus": 0, "def_bonus": 0,
		"combat_power": human_start_res["army"] * COMBAT_POWER_PER_UNIT,
		"army_count": human_start_res["army"],  # kept in sync with ResourceManager
	})
	_player_factions[0] = chosen_faction
	ResourceManager.init_player(0, human_start_res)
	SlaveManager.init_player(0, human_start_res.get("slaves", 0))
	FactionManager.init_faction(0, chosen_faction)
	if chosen_faction == FactionData.FactionID.PIRATE and HeroSystem != null:
		HeroSystem.init_pirate_mode()
	ItemManager.init_player(0)
	RelicManager.init_player(0)
	NpcManager.init_player(0)
	QuestManager.init_player(0)
	QuestJournal.init_journal(chosen_faction)
	RecruitManager.init_player(0)
	_give_starting_army(0, chosen_faction)
	DiplomacyManager.init_player(0)
	StrategicResourceManager.init_player(0)
	ResearchManager.init_player(0)
	if EquipmentForge != null:
		EquipmentForge.init_player(0)
	if chosen_faction == FactionData.FactionID.ORC:
		OrcMechanic.init_player(0)

	# Apply NG+ carry-over bonuses
	NgPlusManager.apply_bonuses(0)

	# Capture starting tiles for human
	var human_zone_key: String = _faction_zone_key(chosen_faction)
	for idx in _zone_cache.get(human_zone_key, []):
		tiles[idx]["owner_id"] = 0
		tiles[idx]["garrison"] = BalanceConfig.STARTING_GARRISON
		tiles[idx]["public_order"] = BalanceConfig.TILE_ORDER_DEFAULT

	# Create starting army for human player
	_create_starting_army(0, chosen_faction, human_start_tile)

	# Track capital tile for defeat condition
	game_stats = {"battles_won": 0, "battles_lost": 0, "capital_tile": human_start_tile}

	# ── Create rival dark faction AI players ──
	var rival_id: int = 1
	for fid in [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]:
		if fid == chosen_faction:
			continue
		var rival_res: Dictionary = FactionData.STARTING_RESOURCES[fid]
		var rival_start: int = _get_zone_start(fid)

		players.append({
			"id": rival_id, "name": FactionData.FACTION_NAMES[fid], "is_ai": true,
			"position": rival_start, "ap": BASE_AP,
			"color": FactionData.FACTION_COLORS[fid],
			"atk_bonus": 0, "def_bonus": 0,
			"combat_power": rival_res["army"] * COMBAT_POWER_PER_UNIT,
			"army_count": rival_res["army"],
		})
		_player_factions[rival_id] = fid
		ResourceManager.init_player(rival_id, rival_res)
		SlaveManager.init_player(rival_id, rival_res.get("slaves", 0))
		FactionManager.init_faction(rival_id, fid)
		FactionManager.register_rival(fid, rival_id)
		ItemManager.init_player(rival_id)
		RelicManager.init_player(rival_id)
		NpcManager.init_player(rival_id)
		QuestManager.init_player(rival_id)
		RecruitManager.init_player(rival_id)
		_give_starting_army(rival_id, fid)
		DiplomacyManager.init_player(rival_id)
		StrategicResourceManager.init_player(rival_id)
		ResearchManager.init_player(rival_id)
		if fid == FactionData.FactionID.ORC:
			OrcMechanic.init_player(rival_id)

		# Capture starting tiles for rival
		var zone_key: String = _faction_zone_key(fid)
		var _ai_gar_mult: float = BalanceManager.get_ai_garrison_mult()
		for idx in _zone_cache.get(zone_key, []):
			tiles[idx]["owner_id"] = rival_id
			tiles[idx]["garrison"] = int(float(BalanceConfig.STARTING_GARRISON) * _ai_gar_mult)
			tiles[idx]["public_order"] = BalanceConfig.TILE_ORDER_DEFAULT

		# Create starting army for rival
		_create_starting_army(rival_id, fid, rival_start)

		rival_id += 1

	# Reveal starting area for all players
	for p in players:
		_reveal_around(p["position"], p["id"])
		# Also reveal around each army
	for army_id in armies:
		var army: Dictionary = armies[army_id]
		_reveal_around(army["tile_index"], army["player_id"])

	# Initialize light faction defenses (walls, barriers, garrisons)
	LightFactionAI.init_light_defenses()

	# Initialize neutral faction territories and AI
	NeutralFactionAI.reset()
	NeutralFactionAI.init_neutral_territories()

	# Initialize garrison compositions for all non-player tiles (Phase 3)
	_init_light_garrisons()

	# Apply difficulty scaling to light/neutral garrisons
	var _diff_gar_mult: float = BalanceManager.get_ai_garrison_mult()
	if _diff_gar_mult != 1.0:
		for i in range(tiles.size()):
			var t: Dictionary = tiles[i]
			if t.get("owner_id", -1) < 0 and t.get("garrison", 0) > 0:
				t["garrison"] = maxi(1, int(float(t["garrison"]) * _diff_gar_mult))

	# Spawn initial wanderers on some unclaimed tiles
	_spawn_initial_wanderers()

	current_player_index = 0
	game_active = true
	has_rolled = false
	waiting_for_move = false
	_pending_event_queue.clear()
	_scheduler_event_queue.clear()

	# v3.0: Run balance audit on game start (dev mode)
	if OS.is_debug_build():
		BalanceManager.run_full_audit()

	EventBus.message_log.emit("═══ 暗潮 - %s 崛起! ═══" % FactionData.FACTION_NAMES[chosen_faction])
	EventBus.message_log.emit("难度: %s" % BalanceManager.get_diff()["label"])
	begin_turn()


func _faction_zone_key(fid: int) -> String:
	match fid:
		FactionData.FactionID.ORC: return "orc"
		FactionData.FactionID.PIRATE: return "pirate"
		FactionData.FactionID.DARK_ELF: return "dark_elf"
	return "orc"


## Create the initial army for a player at their starting tile.
func _create_starting_army(player_id: int, faction_id: int, start_tile: int) -> void:
	var faction_name: String = FactionData.FACTION_NAMES.get(faction_id, "军团")
	var army_name: String = "%s 主力军" % faction_name
	var army_id: int = create_army(player_id, start_tile, army_name)
	if army_id < 0:
		return
	# Transfer existing troop instances from RecruitManager to this army
	var existing_troops: Array = RecruitManager._get_army_ref(player_id)
	if not existing_troops.is_empty():
		armies[army_id]["troops"] = existing_troops.duplicate(true)


func _get_zone_start(fid: int) -> int:
	var key: String = _faction_zone_key(fid)
	var zone: Array = _zone_cache.get(key, [])
	if zone.is_empty():
		return 0
	return zone[0]


## Give a player their starting army based on faction. Uses GameData troop types.
func _give_starting_army(player_id: int, faction_id: int) -> void:
	var tag: String = _faction_zone_key(faction_id)
	# Collect T1 and T2 troops for this faction
	var t1_ids: Array = []
	var t2_ids: Array = []
	for tid in GameData.TROOP_TYPES:
		var td: Dictionary = GameData.TROOP_TYPES[tid]
		if td["faction"] == tag and td["category"] == GameData.TroopCategory.FACTION:
			if td.get("tier", 1) == 1:
				t1_ids.append(tid)
			elif td.get("tier", 1) == 2:
				t2_ids.append(tid)
	if t1_ids.is_empty():
		return
	# Give 1st T1 squad at full strength
	var inst1: Dictionary = GameData.create_troop_instance(t1_ids[0])
	RecruitManager._get_army_ref(player_id).append(inst1)
	# 2nd squad: prefer a different T1, else give a T2 at half strength
	if t1_ids.size() >= 2:
		var inst2: Dictionary = GameData.create_troop_instance(t1_ids[1])
		RecruitManager._get_army_ref(player_id).append(inst2)
	elif not t2_ids.is_empty():
		var td2: Dictionary = GameData.get_troop_def(t2_ids[0])
		@warning_ignore("integer_division")
		var half: int = maxi(2, td2["max_soldiers"] / 2)
		var inst2: Dictionary = GameData.create_troop_instance(t2_ids[0], half)
		RecruitManager._get_army_ref(player_id).append(inst2)
	else:
		# Fallback: duplicate T1 but at 60% strength
		var td1: Dictionary = GameData.get_troop_def(t1_ids[0])
		var reduced: int = maxi(2, int(td1["max_soldiers"] * 0.6))
		var inst2: Dictionary = GameData.create_troop_instance(t1_ids[0], reduced)
		RecruitManager._get_army_ref(player_id).append(inst2)
	RecruitManager._sync_army_count(player_id)

	# Apply difficulty scaling to AI starting troops
	if player_id != get_human_player_id():
		var _ai_troop_mult: float = BalanceManager.get_ai_garrison_mult()
		if _ai_troop_mult != 1.0:
			for troop in RecruitManager._get_army_ref(player_id):
				var scaled: int = maxi(2, int(float(troop.get("soldiers", 1)) * _ai_troop_mult))
				troop["soldiers"] = scaled

## Initialize garrisons for light faction tiles using GameData templates.
func _init_light_garrisons() -> void:
	# Map light_faction int → garrison template tag
	var _lf_tag: Dictionary = {
		FactionData.LightFaction.HUMAN_KINGDOM: "human",
		FactionData.LightFaction.HIGH_ELVES: "elf",
		FactionData.LightFaction.MAGE_TOWER: "mage",
	}
	# Map neutral_faction_id int → garrison template id
	var _nf_template: Dictionary = {
		FactionData.NeutralFaction.IRONHAMMER_DWARF: "neutral_dwarf",
		FactionData.NeutralFaction.NECROMANCER: "neutral_necro",
		FactionData.NeutralFaction.FOREST_RANGER: "neutral_ranger",
		FactionData.NeutralFaction.BLOOD_MOON_CULT: "neutral_blood",
		FactionData.NeutralFaction.GOBLIN_ENGINEER: "neutral_goblin",
	}
	for i in range(tiles.size()):
		var tile: Dictionary = tiles[i]
		var owner_id: int = tile.get("owner_id", -1)
		if owner_id >= 0:
			continue  # Owned by a player (evil faction), skip
		var tile_type: int = tile.get("type", -1)
		var lf_id: int = tile.get("light_faction", -1)
		var template_id: String = ""
		if lf_id >= 0 and _lf_tag.has(lf_id):
			var tag: String = _lf_tag[lf_id]
			match tile_type:
				TileType.CORE_FORTRESS:
					template_id = tag + "_fortress"
				TileType.LIGHT_STRONGHOLD:
					template_id = tag + "_stronghold"
				_:
					template_id = tag + "_village"
		elif tile_type == TileType.NEUTRAL_BASE:
			var nf_id: int = tile.get("neutral_faction_id", -1)
			if _nf_template.has(nf_id):
				template_id = _nf_template[nf_id]
		elif tile_type == TileType.EVENT_TILE:
			# Event tiles with pre-existing garrison → bandit camps
			if tile.get("garrison", 0) > 0:
				template_id = "bandit_weak" if tile["garrison"] < 6 else "bandit_strong"
		if template_id != "" and GameData.GARRISON_TEMPLATES.has(template_id):
			RecruitManager.set_garrison_from_template(i, template_id)


## Spawn wanderer armies on a few unclaimed bandit/event tiles at game start.
func _spawn_initial_wanderers() -> void:
	var unclaimed: Array = []
	for i in range(tiles.size()):
		var tile: Dictionary = tiles[i]
		if tile.get("owner_id", -1) < 0:
			var tt: int = tile.get("type", -1)
			if tt == TileType.EVENT_TILE or tt == TileType.WILDERNESS:
				unclaimed.append(i)
	# Spawn wanderers on ~20% of unclaimed bandit/event tiles
	unclaimed.shuffle()
	@warning_ignore("integer_division")
	var count: int = maxi(1, unclaimed.size() / 5)
	for j in range(mini(count, unclaimed.size())):
		RecruitManager.spawn_wanderer(unclaimed[j])
		EventBus.wanderer_spawned.emit(unclaimed[j])


# ═══════════════ TURN CACHE ═══════════════

## Pre-compute frequently accessed per-turn data to avoid redundant iteration.
func _build_turn_cache() -> void:
	_turn_cache.clear()
	# ── owned_tiles: player_id -> Array of tile indices ──
	var owned: Dictionary = {}
	for i in range(tiles.size()):
		var t: Dictionary = tiles[i]
		if t == null:
			continue
		var oid: int = t.get("owner_id", -1)
		if oid < 0:
			continue
		if not owned.has(oid):
			owned[oid] = []
		owned[oid].append(i)
	_turn_cache["owned_tiles"] = owned

	# ── frontier_tiles: player_id -> Array of tile indices adjacent to enemy tiles ──
	var frontier: Dictionary = {}
	for pid_key in owned:
		frontier[pid_key] = []
		for tidx in owned[pid_key]:
			var neighbors: Array = adjacency.get(tidx, [])
			var is_frontier: bool = false
			for nb in neighbors:
				if nb >= 0 and nb < tiles.size() and tiles[nb] != null:
					var nb_owner: int = tiles[nb].get("owner_id", -1)
					if nb_owner >= 0 and nb_owner != pid_key:
						is_frontier = true
						break
			if is_frontier:
				frontier[pid_key].append(tidx)
	_turn_cache["frontier_tiles"] = frontier

	# ── building_effects: player_id -> Dictionary of aggregated building effects ──
	var bld_eff: Dictionary = {}
	for p in players:
		var p_id: int = p["id"]
		bld_eff[p_id] = BuildingRegistry.get_all_player_building_effects(p_id)
	_turn_cache["building_effects"] = bld_eff

	# ── army_counts: player_id -> total soldiers ──
	var army_cts: Dictionary = {}
	for p in players:
		var p_id: int = p["id"]
		army_cts[p_id] = ResourceManager.get_army(p_id)
	_turn_cache["army_counts"] = army_cts


## Return owned tile indices for a player from the turn cache, or compute on demand.
func get_cached_owned_tiles(pid: int) -> Array:
	if _turn_cache.has("owned_tiles"):
		var owned: Dictionary = _turn_cache["owned_tiles"]
		if owned.has(pid):
			return owned[pid]
	# Fallback: compute without cache
	var result: Array = []
	for i in range(tiles.size()):
		var t: Dictionary = tiles[i]
		if t != null and t.get("owner_id", -1) == pid:
			result.append(i)
	return result


## Return aggregated building effects for a player from the turn cache, or compute on demand.
func get_cached_building_effects(pid: int) -> Dictionary:
	if _turn_cache.has("building_effects"):
		var bld: Dictionary = _turn_cache["building_effects"]
		if bld.has(pid):
			return bld[pid]
	# Fallback: compute without cache
	return BuildingRegistry.get_all_player_building_effects(pid)



## Calculate territory adjacency synergy bonus (控制相邻领地的协同加成)
func _calculate_adjacency_synergy(pid: int) -> Dictionary:
	var bonus: Dictionary = {"gold": 0, "food": 0, "iron": 0}
	var owned_set: Dictionary = {}
	for tidx in get_cached_owned_tiles(pid):
		owned_set[tidx] = true

	# For each owned tile, count how many adjacent tiles are also owned
	var total_adj_pairs: int = 0
	for tidx in owned_set:
		if not adjacency.has(tidx):
			continue
		for nb in adjacency[tidx]:
			if owned_set.has(nb):
				total_adj_pairs += 1
	# Each pair counted twice (A->B and B->A), so divide by 2
	@warning_ignore("integer_division")
	total_adj_pairs = total_adj_pairs / 2

	# Each adjacency pair gives +2 gold, +1 food
	bonus["gold"] = total_adj_pairs * 2
	bonus["food"] = total_adj_pairs * 1
	return bonus

# ═══════════════ TURN MANAGEMENT ═══════════════

func begin_turn() -> void:
	if not game_active:
		return
	if players.is_empty() or current_player_index < 0 or current_player_index >= players.size():
		return

	# ── EventScheduler: reset candidate pool for new turn ──
	if EventScheduler:
		EventScheduler.begin_turn()

	var player: Dictionary = players[current_player_index]
	var pid: int = player["id"]
	var faction_id: int = get_player_faction(pid)

	# ── Guard timer tick (decrement and expire) ──
	_tick_guard_timers(pid)

	# ── March System: advance all marching armies for this player ──
	# This is the ONLY place process_marches() is called. It advances each
	# marching army by one step, handles interception, supply, and attrition.
	if MarchSystem != null:
		var march_events: Array = MarchSystem.process_marches(pid)
		for evt in march_events:
			match evt.get("type", ""):
				"arrived":
					# Army arrived: update its state and refresh tile visual
					var aid: int = evt.get("army_id", -1)
					if armies.has(aid):
						armies[aid]["state"] = "idle"
						_reveal_around(evt.get("tile_index", -1), pid)
				"battle":
					# Army hit an enemy/neutral tile: state becomes in_combat, trigger attack
					var aid: int = evt.get("army_id", -1)
					var btile: int = evt.get("tile_index", -1)
					if armies.has(aid) and btile >= 0:
						armies[aid]["state"] = "in_combat"
						# Deferred attack so march events finish processing first
						call_deferred("action_attack_with_army", aid, btile)
				"intercepted":
					# Army intercepted: state becomes in_combat, trigger counter-attack
					var aid: int = evt.get("army_id", -1)
					var iid: int = evt.get("interceptor_army_id", -1)
					if armies.has(aid):
						armies[aid]["state"] = "in_combat"
						if iid >= 0:
							EventBus.action_visualize_attack.emit(
								armies[aid].get("tile_index", -1),
								armies.get(iid, {}).get("tile_index", -1),
								{"won": false, "army_id": aid, "intercepted": true})

	# ── Phase 0: Build per-turn cache ──
	_build_turn_cache()

	# ── Territory Effects (国効果) evaluation ──
	_active_territory_effects = _evaluate_territory_effects(pid)
	if pid == get_human_player_id():
		var active_ids: Array = _active_territory_effects.get("_active_ids", [])
		if not active_ids.is_empty():
			var eff_names: Array = []
			for eid in active_ids:
				var eff_data: Dictionary = BalanceConfig.TERRITORY_EFFECTS.get(eid, {})
				eff_names.append("[color=cyan]%s[/color]" % eff_data.get("name", eid))
			EventBus.message_log.emit("领地效果: %s" % ", ".join(eff_names))

	# Auto-save at turn start
	if pid == get_human_player_id():
		var _settings_node = get_tree().get_root().find_child("SettingsPanel", true, false)
		var _auto_save_on: bool = true
		if _settings_node and _settings_node.has_method("get_setting"):
			_auto_save_on = _settings_node.get_setting("auto_save") != false
		if _auto_save_on:
			SaveManager.auto_save()

	player["ap"] = calculate_action_points(pid)
	player["atk_bonus"] = 0
	player["def_bonus"] = 0
	_ap_purchases_this_turn = 0
	# Legacy state reset (board compat)
	has_rolled = false
	waiting_for_move = false
	dice_value = 0
	reachable_tiles.clear()
	_prev_turn_had_combat = _had_combat_this_turn
	_had_combat_this_turn = false

	if pid == get_human_player_id():
		turn_number += 1

	# ── Phase 0b: Timed Story Windows check (限時劇情窗口) ──
	if pid == get_human_player_id():
		EventSystem.check_timed_story_windows(pid, turn_number)

	# ── Phase 1: Faction tick ──
	FactionManager.tick_faction(pid, faction_id, _prev_turn_had_combat)

	# ── Phase 1b: Process deferred effects ──
	_process_deferred_effects(pid, player)

	# ── Phase 2: Production ──
	var income: Dictionary = ProductionCalculator.calculate_turn_income(pid)

	# ── Taming synergy: Caravan gold income bonus (全领地金币+30%) ──
	var caravan_taming: int = QuestManager.get_taming_level(pid, "neutral_caravan")
	if caravan_taming >= 9:
		var gold_bonus: int = maxi(1, int(float(income.get("gold", 0)) * 0.3))
		income["gold"] = income.get("gold", 0) + gold_bonus

	# ── Taming synergy: Goblin build discount (建造-20%) applied elsewhere ──

	# ── Territory adjacency synergy ──
	var synergy: Dictionary = _calculate_adjacency_synergy(pid)
	if synergy["gold"] > 0 or synergy["food"] > 0:
		income["gold"] += synergy["gold"]
		income["food"] += synergy["food"]
		if pid == get_human_player_id() and (synergy["gold"] > 0 or synergy["food"] > 0):
			EventBus.message_log.emit("[color=cyan]领地协同: 金+%d 粮+%d[/color]" % [synergy["gold"], synergy["food"]])

	# ── Territory effect income bonuses (国効果) ──
	if _active_territory_effects.get("gold_income_pct", 0.0) > 0.0:
		income["gold"] = int(float(income["gold"]) * (1.0 + _active_territory_effects["gold_income_pct"]))
	if _active_territory_effects.get("food_income_pct", 0.0) > 0.0:
		income["food"] = int(float(income["food"]) * (1.0 + _active_territory_effects["food_income_pct"]))
	if _active_territory_effects.get("iron_income_pct", 0.0) > 0.0:
		income["iron"] = int(float(income["iron"]) * (1.0 + _active_territory_effects["iron_income_pct"]))
	# Prestige per turn from territory effects
	var te_prestige: int = _active_territory_effects.get("prestige_per_turn", 0)
	if te_prestige > 0:
		income["prestige"] = income.get("prestige", 0) + te_prestige

	# ── Phase 2a2: Endgame Crisis — Famine food reduction (v7.0) ──
	if EventSystem.is_famine_active():
		var famine_mult: float = EventSystem.get_famine_food_mult()
		income["food"] = int(float(income["food"]) * famine_mult)

	# ── Phase 2b: Recalculate research speed (building effects may have changed) ──
	ResearchManager.update_research_speed(pid)

	# ── Phase 2c: Supply line & territory classification ──
	SupplySystem.recalculate_supply_lines(pid)
	SupplySystem.classify_territories(pid)
	SupplySystem.apply_isolation_penalties(pid)
	SupplySystem.apply_rear_order_recovery(pid)

	if income.values().any(func(v): return v != 0):
		ResourceManager.apply_delta(pid, income)
		var msg: String = "%s 产出: 金%d 粮%d 铁%d" % [
			player["name"], income["gold"], income["food"], income["iron"]]
		if income.get("prestige", 0) > 0:
			msg += " 威望%d" % income["prestige"]
		# Strategic resource income display
		for sres in FactionData.STRATEGIC_RESOURCES:
			if income.get(sres, 0) > 0:
				msg += " %s+%d" % [sres, income[sres]]
				EventBus.strategic_resource_changed.emit(pid, sres, ResourceManager.get_resource(pid, sres))
		EventBus.message_log.emit(msg)

	# ── Phase 3: Food upkeep (base + military upkeep from T2+ troops) ──
	var food_needed: int = ProductionCalculator.calculate_food_upkeep(pid)
	# Add military upkeep from tier-based troop maintenance
	var military_upkeep: int = GameData.get_army_upkeep(RecruitManager._get_army_ref(pid))
	food_needed += military_upkeep
	var current_food: int = ResourceManager.get_resource(pid, "food")
	if food_needed > 0:
		if current_food >= food_needed:
			ResourceManager.apply_delta(pid, {"food": -food_needed})
			EventBus.message_log.emit("%s 军粮消耗: %d粮 (剩余%d)" % [
				player["name"], food_needed, ResourceManager.get_resource(pid, "food")])
		else:
			var deficit: int = food_needed - current_food
			var food_rate: float = FactionData.FACTION_PARAMS[faction_id]["food_per_soldier"]
			var deserters: int = ceili(float(deficit) / maxf(food_rate, 0.5))
			deserters = mini(deserters, ResourceManager.get_army(pid) - 1)
			ResourceManager.set_resource(pid, "food", 0)
			if deserters > 0:
				ResourceManager.remove_army(pid, deserters)
				player["army_count"] = ResourceManager.get_army(pid)
				player["combat_power"] = player["army_count"] * COMBAT_POWER_PER_UNIT
				EventBus.message_log.emit("[color=red]%s 粮草不足! %d名士兵逃亡[/color]" % [
					player["name"], deserters])

	# ── Phase 3b: Gold upkeep — 军饷 (army gold maintenance) ──
	var gold_upkeep: int = ProductionCalculator.calculate_gold_upkeep(pid)
	if gold_upkeep > 0:
		var current_gold: int = ResourceManager.get_resource(pid, "gold")
		if current_gold >= gold_upkeep:
			ResourceManager.apply_delta(pid, {"gold": -gold_upkeep})
			EventBus.message_log.emit("%s 军饷支出: %d金 (剩余%d)" % [
				player["name"], gold_upkeep, ResourceManager.get_resource(pid, "gold")])
		else:
			# Can't pay full salary — drain all gold + apply combat debuff
			var deficit: int = gold_upkeep - current_gold
			ResourceManager.set_resource(pid, "gold", 0)
			# Apply "unpaid" debuff: -15% ATK/DEF for 1 turn
			var penalty_mult: float = 1.0 - BalanceConfig.GOLD_DEFICIT_COMBAT_PENALTY
			BuffManager.add_buff(pid, "unpaid_atk", "atk_mult", penalty_mult, 1, "unpaid_troops")
			BuffManager.add_buff(pid, "unpaid_def", "def_mult", penalty_mult, 1, "unpaid_troops")
			EventBus.message_log.emit("[color=red]%s 军饷不足! 欠饷%d金，士气低落(ATK/DEF-%.0f%%)[/color]" % [
				player["name"], deficit, BalanceConfig.GOLD_DEFICIT_COMBAT_PENALTY * 100.0])

	# ── Phase 4: Threat decay & timers ──
	if pid == get_human_player_id():
		ThreatManager.tick_decay()
		# Territory effect: threat decay bonus
		var te_threat_bonus: int = _active_territory_effects.get("threat_decay_bonus", 0)
		if te_threat_bonus > 0:
			ThreatManager.change_threat(-te_threat_bonus)
		# BUG FIX: tick_timers() was never called, causing expeditions/bosses to
		# fire every eligible turn instead of on their intended interval (3/5 turns).
		ThreatManager.tick_timers()
		# BUG FIX: check_dominance() was never called, so controlling 50%+ nodes
		# didn't increase threat as designed in 03_战略设定.
		ThreatManager.check_dominance(count_tiles_owned(pid), tiles.size())
		OrderManager.tick_turn()

		# ── Phase 4a: Tile Development Path — per-turn order/prestige bonuses ──
		for tidx in get_cached_owned_tiles(pid):
			var td_effects: Dictionary = TileDevelopment.get_tile_path_effects(tidx)
			var td_order: int = int(td_effects.get("order_bonus", 0))
			if td_order > 0:
				var t: Dictionary = tiles[tidx]
				var cur_po: float = t.get("public_order", BalanceConfig.TILE_ORDER_DEFAULT)
				t["public_order"] = minf(cur_po + float(td_order) * 0.01, 1.0)

	# ── Phase 4b: Troop per-turn passive effects (regen, self_destruct, etc.) ──
	_tick_troop_passives(pid)

	# ── Phase 4b2: Building-based wall repair (fortification) ──
	# Only buildings that can repair walls: fortification, watchtower, etc.
	for tidx in get_cached_owned_tiles(pid):
		var tile: Dictionary = tiles[tidx]
		if tile == null:
			continue
		var _bld: String = tile.get("building_id", "")
		if _bld == "":
			continue
		# Quick filter: only fortification (Lv2+) provides wall repair
		if _bld != "fortification":
			continue
		var _bld_lvl: int = tile.get("building_level", 1)
		var _bld_eff: Dictionary = BuildingRegistry.get_building_effects(_bld, _bld_lvl)
		var repair_amt: int = int(_bld_eff.get("wall_repair_per_turn", 0))
		if repair_amt > 0:
			LightFactionAI.repair_wall(tile["index"], repair_amt)

	# ── Phase 4b3: Siege processing (v5.0) ──
	SiegeSystem.process_sieges(pid)

	# ── Phase 4c: Dark Elf slave conversion tick ──
	var _de_ftag: String = _get_faction_tag_for_player(pid)
	if _de_ftag == "dark_elf":
		var converted: int = SlaveManager.tick_conversion(pid)
		if converted > 0:
			# Create T1 de_samurai troops from converted slaves
			for _c in range(converted):
				var inst: Dictionary = GameData.create_troop_instance("de_samurai")
				if not inst.is_empty():
					RecruitManager.reinforce_army(pid, [inst])
			EventBus.message_log.emit("[color=purple]奴隶转化完成! +%d 暗精灵战士[/color]" % converted)

	# ── Phase 5: Rebellion check ──
	if pid == get_human_player_id():
		OrderManager.try_rebellion()
		# Phase 3: Rebel army spawning on low-order tiles
		_check_rebel_spawns(pid)

	# ── Phase 5b: Buff expiry ──
	BuffManager.tick_buffs(pid)

	# ── Phase 5b1: Mana regeneration from buildings (Arcane Institute Lv3) ──
	var bld_effects: Dictionary = get_cached_building_effects(pid)
	var mana_regen_amt: int = int(bld_effects.get("mana_regen", 0))
	if mana_regen_amt > 0:
		var current_mana: int = ResourceManager.get_resource(pid, "mana")
		ResourceManager.set_resource(pid, "mana", current_mana + mana_regen_amt)
		EventBus.message_log.emit("[color=blue]魔导研究院: 法力回复 +%d[/color]" % mana_regen_amt)

	# ── Phase 5b2: Research progress ──
	if pid == get_human_player_id():
		ResearchManager.process_turn(pid)

	# ── Phase 5b3: Troop training progress (v3.4) ──
	if pid == get_human_player_id():
		var _ttp = _find_troop_training_panel()
		if _ttp and _ttp.has_method("process_turn"):
			_ttp.process_turn()

	# ── Phase 5b4: Equipment forge crafting progress (v3.6) ──
	if EquipmentForge != null:
		EquipmentForge.process_turn(pid)

	# ── Phase 5c: NPC obedience decay/growth ──
	NpcManager.tick_all(pid, turn_number)

	# ── Phase 5c2: Story event progression check ──
	if pid == get_human_player_id():
		StoryEventSystem.process_story_turn()

	# ── Phase 5c2b: Event cooldown tick & event processing ──
	if pid == get_human_player_id():
		EventSystem.tick_event_cooldowns()
		EventSystem.process_turn_start()

	# ── Phase 5c2c: Roll random events → submit to EventScheduler (SR07 flow) ──
	if pid == get_human_player_id():
		var rolled_events: Array = EventSystem.roll_events()
		for rev in rolled_events:
			if EventScheduler:
				EventScheduler.submit_candidate(
					rev.get("id", "random_%d" % randi()),
					"event_system",
					EventScheduler.PRIORITY_LOW,
					rev.get("weight", 1.0),
					rev
				)
			else:
				# Fallback: direct fire if EventScheduler missing
				var player_for_event: Dictionary = get_player_by_id(pid)
				_show_random_event_popup(player_for_event, rev)
				EventBus.message_log.emit("[color=yellow]随机事件: %s[/color]" % rev.get("name", "事件"))

	# ── Phase 5c2d: Endgame Crisis check (v7.0) ──
	if pid == get_human_player_id():
		EventSystem.check_endgame_crisis()

	# ── Phase 6b: New Event Systems (v4.0) ──
	# NOTE: These systems submit candidates to EventScheduler via their
	# _on_turn_started signal connections (triggered by EventBus.turn_started).
	# No explicit calls needed here; resolve_turn() happens after turn_started.emit.

	# ── Phase 6c: EventScheduler resolution moved to after turn_started.emit ──
	# (see below, after EventBus.turn_started.emit)

	# ── Phase 5c3: Harem cooldown tick ──
	if pid == get_human_player_id() and HeroSystem != null:
		HeroSystem.tick_harem_cooldowns()
		HeroSystem.tick_cooldowns()
		HeroSystem.tick_gift_cooldowns()
		# BUG FIX: process_prison_turn() was never called, so captured heroes never
		# accumulated corruption and could never be recruited. Call it each turn.
		HeroSystem.process_prison_turn()

	# ── Phase 5c4: Per-tile public order drift ──
	# Only tick once per round cycle, not once per player
	if pid == get_human_player_id():
		tick_tile_public_order()

	# ── Phase 5d: Taming neglect / gift cooldown tick ──
	QuestManager.tick_turn(pid)

	# ── Phase 5e: Conquered faction rebellion ──
	DiplomacyManager.tick_rebellion(pid)

	# ── Phase 5e2: Ceasefire timer tick ──
	DiplomacyManager.tick_ceasefire(pid)

	# ── Phase 5e3: Treaty system tick (tribute, trade, NAP, alliance) ──
	DiplomacyManager.tick_treaties(pid)

	# ── Phase 5e4: Light faction diplomacy tick (ceasefire, peace offers) ──
	DiplomacyManager.tick_light_diplomacy()

	# ── Phase 5e5: Reputation decay ──
	DiplomacyManager.tick_reputation_decay()

	# ── Phase 5e6: SR07-style dynamic diplomatic events ──
	if pid == get_human_player_id():
		DiplomacyManager.process_diplomatic_events(pid)

	# ── Phase 5e7: SR07-style hero recruitment events ──
	if pid == get_human_player_id() and HeroSystem != null:
		HeroSystem.process_recruitment_events(pid)

	# ── Phase 5f: Alliance AI actions ──
	AllianceAI.tick(ThreatManager.get_threat())

	# ── Phase 5g: Unrecruited evil faction AI ──
	AIStrategicPlanner.process_turn(pid)
	EvilFactionAI.tick(pid)

	# ── Phase 5g2: AI pirate raiding parties ──
	PirateMechanic.ai_tick(pid)

	# ── Phase 5g: Light faction passive regen (wall, barrier, mana) ──
	LightFactionAI.tick_light_factions()

	# ── Phase 5g3: Neutral faction AI (territory patrol & vassal production) ──
	if pid == get_human_player_id():
		NeutralFactionAI.tick()
		# Add vassal production income (base resources + faction-specific unique resources)
		var vassal_income: Dictionary = NeutralFactionAI.get_vassal_production(pid)
		var has_basic: bool = vassal_income["gold"] > 0 or vassal_income["food"] > 0 or vassal_income["iron"] > 0
		var has_strategic: bool = (vassal_income.get("gunpowder", 0) > 0
			or vassal_income.get("shadow_essence", 0) > 0
			or vassal_income.get("magic_crystal", 0) > 0
			or vassal_income.get("war_horse", 0) > 0)
		if has_basic or has_strategic or vassal_income.get("prestige", 0) > 0:
			# Apply all resources via apply_delta (supports all resource keys)
			var delta: Dictionary = {}
			for key in vassal_income:
				if vassal_income[key] > 0:
					delta[key] = vassal_income[key]
			if delta.size() > 0:
				ResourceManager.apply_delta(pid, delta)
			# Log message
			var msg: String = "[color=cyan]附庸贡献: 金%d 粮%d 铁%d" % [
				vassal_income["gold"], vassal_income["food"], vassal_income["iron"]]
			var extras: Array = []
			if vassal_income.get("gunpowder", 0) > 0:
				extras.append("火药%d" % vassal_income["gunpowder"])
			if vassal_income.get("shadow_essence", 0) > 0:
				extras.append("暗影%d" % vassal_income["shadow_essence"])
			if vassal_income.get("magic_crystal", 0) > 0:
				extras.append("魔晶%d" % vassal_income["magic_crystal"])
			if vassal_income.get("war_horse", 0) > 0:
				extras.append("战马%d" % vassal_income["war_horse"])
			if vassal_income.get("prestige", 0) > 0:
				extras.append("威望%d" % vassal_income["prestige"])
			if extras.size() > 0:
				msg += " " + " ".join(extras)
			msg += "[/color]"
			EventBus.message_log.emit(msg)

	# ── Phase 5g4: Weather, Supply & Espionage turn processing ──
	if Engine.get_main_loop() is SceneTree:
		var _sys_root: Node = (Engine.get_main_loop() as SceneTree).root
		if _sys_root.has_node("WeatherSystem"):
			_sys_root.get_node("WeatherSystem").advance_turn()
		if _sys_root.has_node("SupplySystem"):
			_sys_root.get_node("SupplySystem").process_turn(pid)
		if _sys_root.has_node("EspionageSystem"):
			_sys_root.get_node("EspionageSystem").process_turn(pid)
		if _sys_root.has_node("SupplyLogistics"):
			_sys_root.get_node("SupplyLogistics").process_turn(pid)

	# ── Phase 5h: Supply line attrition (v0.9.2) ──
	_tick_supply_lines(pid)
	_tick_terrain_attrition(pid)

	# ── Phase 6: Threat events (expedition / boss) ──
	if pid == get_human_player_id():
		# Light ceasefire suppresses expeditions
		if not DiplomacyManager.is_light_ceasefire_active():
			if ThreatManager.should_spawn_expedition():
				_spawn_expedition()
			if ThreatManager.should_spawn_boss():
				EventBus.message_log.emit("[color=red]光明联盟发动绝望反击! 强力boss出现![/color]")

	# ── Sync army count from ResourceManager ──
	sync_player_army(pid)

	# ── Clear per-turn cache ──
	_turn_cache.clear()

	# Force-close any lingering event popup before starting the new turn
	EventBus.hide_event_popup.emit()
	EventBus.turn_started.emit(pid)

	# ── Phase 6c: EventScheduler — resolve weighted event selection (SR07 flow) ──
	# All event systems have now submitted candidates via _on_turn_started.
	# EventScheduler selects max 2 per turn (critical bypasses limit).
	# This is the ONE place events actually fire as popups.
	if EventScheduler and not player["is_ai"]:
		var selected_events: Array = EventScheduler.resolve_turn()
		for evt in selected_events:
			var evt_data: Dictionary = evt.get("data", {})
			_queue_scheduler_event(evt_data)
			EventBus.message_log.emit("[color=yellow]事件: %s[/color]" % evt_data.get("name", evt_data.get("title", evt.get("id", ""))))
		_process_scheduler_event_queue()

	EventBus.message_log.emit("══ %s 的回合 (第%d回合, AP:%d) ══" % [player["name"], turn_number, player["ap"]])

	# ── Phase banner for UI feedback (v4.5) ──
	if pid == get_human_player_id():
		EventBus.phase_banner_requested.emit("Your Turn - Turn %d" % turn_number, false)
	else:
		EventBus.phase_banner_requested.emit("Enemy Turn - %s..." % player["name"], true)

	# Turn milestone events (Rance 07 style)
	if pid == get_human_player_id():
		if turn_number == 15:
			EventBus.message_log.emit("[color=yellow]═══ 第15回合 — 光明联盟开始组织防线 ═══[/color]")
		elif turn_number == 30:
			EventBus.message_log.emit("[color=orange]═══ 第30回合 — 战局进入白热化! ═══[/color]")
			EventBus.message_log.emit("所有敌方据点驻军+3!")
			for t in tiles:
				if t["owner_id"] != pid and t["owner_id"] >= 0:
					t["garrison"] += 3
		elif turn_number == 40:
			EventBus.message_log.emit("[color=red]═══ 第40回合 — 终末时代降临! ═══[/color]")
			EventBus.message_log.emit("[color=yellow]终末危机现已激活! 瘟疫、叛乱、远古入侵或饥荒可能随时爆发。[/color]")
			EventBus.message_log.emit("[color=cyan]威望行动已解锁: 盛大祭典 / 帝国法令 / 铸造联盟[/color]")
		elif turn_number == 45:
			EventBus.message_log.emit("[color=red]═══ 第45回合 — 光明联盟孤注一掷! ═══[/color]")
			EventBus.message_log.emit("敌方全据点驻军+5, 但你获得100金作为战争赔偿!")
			for t in tiles:
				if t["owner_id"] != pid and t["owner_id"] >= 0:
					t["garrison"] += 5
			ResourceManager.apply_delta(pid, {"gold": 100})
		elif turn_number == 55 and BalanceConfig.TURN_LIMIT > 0:
			EventBus.message_log.emit("[color=red][b]═══ 最终警告: 仅剩%d回合! ═══[/b][/color]" % (BalanceConfig.TURN_LIMIT - turn_number))

	# Turn limit warning (ターン制限)
	if pid == get_human_player_id() and BalanceConfig.TURN_LIMIT > 0:
		var remaining: int = BalanceConfig.TURN_LIMIT - turn_number
		if remaining <= 0:
			EventBus.message_log.emit("[color=red][b]回合超限! 下回合将判定失败![/b][/color]")
		elif remaining <= BalanceConfig.TURN_LIMIT_WARNING:
			EventBus.message_log.emit("[color=yellow]剩余回合: %d/%d — 加快进攻节奏![/color]" % [remaining, BalanceConfig.TURN_LIMIT])
		elif remaining <= BalanceConfig.TURN_LIMIT_WARNING * 2:
			EventBus.message_log.emit("剩余回合: %d/%d" % [remaining, BalanceConfig.TURN_LIMIT])

	# ── Hidden Heroes check (秘密英雄 — turn start) ──
	if pid == get_human_player_id() and HeroSystem != null:
		HeroSystem.check_hidden_hero_conditions(pid)

	if player["is_ai"]:
		run_ai_turn()


func end_turn() -> void:
	if not game_active:
		return
	# BUG FIX: bounds check before accessing players array
	if players.is_empty() or current_player_index < 0 or current_player_index >= players.size():
		return
	var player: Dictionary = players[current_player_index]
	waiting_for_move = false
	reachable_tiles.clear()
	selected_army_id = -1
	EventBus.turn_ended.emit(player["id"])

	# Auto-save at end of human player's turn if setting enabled
	if player["id"] == get_human_player_id():
		var settings_node = get_tree().get_root().find_child("SettingsPanel", true, false)
		var auto_save_on: bool = false
		if settings_node and settings_node.has_method("get_setting"):
			auto_save_on = settings_node.get_setting("auto_save") == true
		if auto_save_on:
			SaveManager.auto_save()

	if players.is_empty():
		return
	current_player_index = (current_player_index + 1) % players.size()
	begin_turn()


# ═══════════════ LATE-GAME PRESTIGE ACTIONS (v7.0) ═══════════════

## Grand Festival: Costs 200g, +15 order to all territories, +3 affection to all heroes.
## Can be used once per 10 turns.
func action_grand_festival() -> bool:
	var pid: int = get_human_player_id()
	if not game_active:
		EventBus.message_log.emit("[color=red]游戏未在进行中。[/color]")
		return false

	# Cooldown check
	var cooldown: int = BalanceConfig.GRAND_FESTIVAL_COOLDOWN
	if turn_number - _last_grand_festival_turn < cooldown:
		var remaining: int = cooldown - (turn_number - _last_grand_festival_turn)
		EventBus.message_log.emit("[color=red]盛大祭典冷却中! 还需%d回合。[/color]" % remaining)
		return false

	# Cost check
	var cost: int = BalanceConfig.GRAND_FESTIVAL_COST_GOLD
	var gold: int = ResourceManager.get_resource(pid, "gold")
	if gold < cost:
		EventBus.message_log.emit("[color=red]金币不足! 盛大祭典需要%d金。[/color]" % cost)
		return false

	# Apply effects
	ResourceManager.apply_delta(pid, {"gold": -cost})
	_last_grand_festival_turn = turn_number

	# +15 order to all owned territories (as public_order percentage)
	var order_bonus: float = float(BalanceConfig.GRAND_FESTIVAL_ORDER_BONUS) / 100.0
	var owned_tiles: Array = get_cached_owned_tiles(pid)
	for tidx in owned_tiles:
		var tile: Dictionary = tiles[tidx]
		var cur_po: float = tile.get("public_order", BalanceConfig.TILE_ORDER_DEFAULT)
		tile["public_order"] = minf(cur_po + order_bonus, 1.0)

	# Also apply to global order
	OrderManager.change_order(BalanceConfig.GRAND_FESTIVAL_ORDER_BONUS)

	# +3 affection to all recruited heroes
	var aff_bonus: int = BalanceConfig.GRAND_FESTIVAL_AFFECTION_BONUS
	if HeroSystem != null:
		for hero_id in HeroSystem.recruited_heroes:
			HeroSystem.add_affection(hero_id, aff_bonus)

	EventBus.grand_festival_executed.emit(pid)
	EventBus.message_log.emit("[color=green][b]═══ 盛大祭典! ═══[/b][/color]")
	EventBus.message_log.emit("[color=green]花费%d金，全领地秩序+%d，所有英雄好感+%d![/color]" % [
		cost, BalanceConfig.GRAND_FESTIVAL_ORDER_BONUS, aff_bonus])
	return true


## Imperial Decree: Costs 3 AP + 100g, permanently reduces threat by 20. Once per game.
func action_imperial_decree() -> bool:
	var pid: int = get_human_player_id()
	if not game_active:
		EventBus.message_log.emit("[color=red]游戏未在进行中。[/color]")
		return false

	if _imperial_decree_used:
		EventBus.message_log.emit("[color=red]帝国法令每局游戏只能颁布一次![/color]")
		return false

	# Cost check: AP
	var player: Dictionary = {}
	for p in players:
		if p["id"] == pid:
			player = p
			break
	if player.is_empty():
		return false

	var ap_cost: int = BalanceConfig.IMPERIAL_DECREE_COST_AP
	var gold_cost: int = BalanceConfig.IMPERIAL_DECREE_COST_GOLD
	var current_ap: int = player.get("ap", 0)
	if current_ap < ap_cost:
		EventBus.message_log.emit("[color=red]行动点不足! 帝国法令需要%dAP。[/color]" % ap_cost)
		return false

	var gold: int = ResourceManager.get_resource(pid, "gold")
	if gold < gold_cost:
		EventBus.message_log.emit("[color=red]金币不足! 帝国法令需要%d金。[/color]" % gold_cost)
		return false

	# Apply effects
	player["ap"] -= ap_cost
	EventBus.ap_changed.emit(pid, player["ap"])
	ResourceManager.apply_delta(pid, {"gold": -gold_cost})
	ThreatManager.change_threat(-BalanceConfig.IMPERIAL_DECREE_THREAT_REDUCTION)
	_imperial_decree_used = true

	EventBus.imperial_decree_executed.emit(pid)
	EventBus.message_log.emit("[color=green][b]═══ 帝国法令! ═══[/b][/color]")
	EventBus.message_log.emit("[color=green]花费%dAP + %d金，威胁值永久降低%d![/color]" % [
		ap_cost, gold_cost, BalanceConfig.IMPERIAL_DECREE_THREAT_REDUCTION])
	return true


## Forge Alliance: Costs 150g, auto-alliance with weakest surviving faction. Once per game.
func action_forge_alliance() -> bool:
	var pid: int = get_human_player_id()
	if not game_active:
		EventBus.message_log.emit("[color=red]游戏未在进行中。[/color]")
		return false

	if _forge_alliance_used:
		EventBus.message_log.emit("[color=red]铸造联盟每局游戏只能使用一次![/color]")
		return false

	var cost: int = BalanceConfig.FORGE_ALLIANCE_COST_GOLD
	var gold: int = ResourceManager.get_resource(pid, "gold")
	if gold < cost:
		EventBus.message_log.emit("[color=red]金币不足! 铸造联盟需要%d金。[/color]" % cost)
		return false

	# Find weakest surviving faction (fewest tiles, excluding human player)
	var faction_tile_counts: Dictionary = {}  # faction_id -> tile_count
	for t in tiles:
		var owner_id: int = t.get("owner_id", -1)
		if owner_id > 0:  # Exclude unowned (-1) and human player (0)
			faction_tile_counts[owner_id] = faction_tile_counts.get(owner_id, 0) + 1

	if faction_tile_counts.is_empty():
		EventBus.message_log.emit("[color=red]没有存活的势力可以结盟![/color]")
		return false

	# Find the faction with fewest tiles
	var weakest_id: int = -1
	var min_tiles: int = 999
	for fid in faction_tile_counts:
		if faction_tile_counts[fid] < min_tiles:
			min_tiles = faction_tile_counts[fid]
			weakest_id = fid

	if weakest_id < 0:
		return false

	# Apply effects
	ResourceManager.apply_delta(pid, {"gold": -cost})
	_forge_alliance_used = true

	# Force-create a military alliance bypassing normal diplomatic checks
	# (this is a special prestige action, not a normal treaty)
	var alliance_duration: int = BalanceConfig.ALLIANCE_EVIL_DURATION
	var treaty := {
		"type": "alliance",
		"target": weakest_id,
		"turns_left": alliance_duration,
	}
	DiplomacyManager._get_player_treaties(pid).append(treaty)
	EventBus.treaty_signed.emit(pid, "alliance", weakest_id)

	# Get faction name for display
	var faction_name: String = "未知势力"
	for p in players:
		if p["id"] == weakest_id:
			faction_name = p.get("name", "势力%d" % weakest_id)
			break

	EventBus.forge_alliance_executed.emit(pid, weakest_id)
	EventBus.message_log.emit("[color=green][b]═══ 铸造联盟! ═══[/b][/color]")
	EventBus.message_log.emit("[color=green]花费%d金，与%s (最弱势力, %d地块) 建立军事同盟![/color]" % [
		cost, faction_name, min_tiles])
	return true


## Process deferred tile and turn effects (gold_next_visit, attacked_next_turn, etc.)
func _process_deferred_effects(player_id: int, player: Dictionary) -> void:
	# 1. Process deferred attacks scheduled for this turn
	if player.has("deferred_attacks"):
		var remaining: Array = []
		for atk in player["deferred_attacks"]:
			atk["turns_delay"] -= 1
			if atk["turns_delay"] <= 0:
				# Execute the deferred attack
				var tile_idx: int = atk["tile_index"]
				if tile_idx >= 0 and tile_idx < tiles.size():
					var target_tile: Dictionary = tiles[tile_idx]
					if target_tile["owner_id"] == player_id:
						var saved_garrison: int = target_tile["garrison"]
						target_tile["garrison"] = atk["strength"]
						_resolve_combat(player, target_tile, "伏击部队")
						target_tile["garrison"] = saved_garrison
						EventBus.message_log.emit("[color=red]预定的袭击已发生! (兵力: %d)[/color]" % atk["strength"])
					# else: tile no longer owned, attack fizzles
			else:
				remaining.append(atk)
		if remaining.is_empty():
			player.erase("deferred_attacks")
		else:
			player["deferred_attacks"] = remaining

	# 2. Check gold_next_visit on the player's current position
	var pos: int = player.get("position", -1)
	if pos >= 0 and pos < tiles.size():
		var tile: Dictionary = tiles[pos]
		# BUG FIX R15: null check on tile
		if tile != null and tile.has("deferred_effects"):
			var def_fx: Dictionary = tile["deferred_effects"]
			if def_fx.has("gold_next_visit"):
				var fx: Dictionary = def_fx["gold_next_visit"]
				if fx["player_id"] == player_id:
					var gold_val: int = fx["value"]
					ResourceManager.apply_delta(player_id, {"gold": gold_val})
					EventBus.message_log.emit("[color=yellow]触发延迟效果: 获得 %d 金币![/color]" % gold_val)
					def_fx.erase("gold_next_visit")
			# Clean up empty deferred_effects
			if def_fx.is_empty():
				tile.erase("deferred_effects")

	# 3. Tick down duration-based deferred tile effects
	# BUG FIX R7: Only tick global deferred effects once per turn cycle (player_id == 0),
	# not once per player, to prevent N× faster decay in multiplayer.
	if player_id == 0:
		for tile in tiles:
			# BUG FIX R13: null check on tile
			if tile == null:
				continue
			if not tile.has("deferred_effects"):
				continue
			var to_remove: Array = []
			for key in tile["deferred_effects"]:
				var fx: Dictionary = tile["deferred_effects"][key]
				if fx.has("turns_remaining") and fx["turns_remaining"] > 0:
					fx["turns_remaining"] -= 1
					if fx["turns_remaining"] <= 0:
						to_remove.append(key)
			for key in to_remove:
				tile["deferred_effects"].erase(key)
			if tile["deferred_effects"].is_empty():
				tile.erase("deferred_effects")


## Phase 4b: Apply per-turn passive effects to a player's troops.
func _tick_troop_passives(player_id: int) -> void:
	var tick_result: Dictionary = CombatAbilities.tick_per_round_passives(player_id)
	for detail in tick_result.get("details", []):
		EventBus.message_log.emit("  %s" % detail)
	# Subtract food savings from zero_food troops (already deducted from total)
	var food_saved: int = tick_result.get("food_cost_reduction", 0)
	if food_saved > 0:
		ResourceManager.apply_delta(player_id, {"food": food_saved})


## Phase 3: Check rebel army spawns on low-order player tiles.
func _check_rebel_spawns(player_id: int) -> void:
	var order: int = OrderManager.get_order()
	if order > 25:
		return  # No rebels when order is acceptable
	for i in range(tiles.size()):
		var tile: Dictionary = tiles[i]
		if tile.get("owner_id", -1) != player_id:
			continue
		# Only spawn on tiles without existing rebels
		if RecruitManager.get_rebel(i).size() > 0:
			continue
		# 10% chance per low-order tile per turn
		if randi() % 100 < 10:
			if RecruitManager.try_spawn_rebel(i, order):
				EventBus.rebel_spawned.emit(i)
				EventBus.message_log.emit("[color=red]叛军在%s起义![/color]" % tile.get("name", "据点%d" % i))


func _spawn_expedition() -> void:
	## Light Alliance sends an army to recapture a player-owned tile.
	var human_id: int = get_human_player_id()
	var owned: Array = []
	for tile in tiles:
		if tile.get("owner_id", -1) == human_id and tile.get("type", -1) != TileType.DARK_BASE:
			owned.append(tile)
	if owned.is_empty():
		return
	var target: Dictionary = owned[randi() % owned.size()]
	var strength: int = randi_range(30, 60)
	EventBus.message_log.emit("[color=orange]光明联盟远征军(战力%d)进攻 %s![/color]" % [strength, target["name"]])
	# Auto-resolve: compare garrison
	if target["garrison"] >= strength:
		target["garrison"] -= int(strength * BalanceConfig.EXPEDITION_DEFEND_LOSS_MULT)
		EventBus.message_log.emit("驻军成功抵御进攻! (驻军剩余%d)" % target["garrison"])
	else:
		target["owner_id"] = -1
		target["garrison"] = int(strength * BalanceConfig.EXPEDITION_CAPTURE_GARRISON_MULT)
		EventBus.message_log.emit("[color=red]%s 被光明联盟夺回![/color]" % target["name"])
		EventBus.tile_lost.emit(human_id, target["index"])
		OrderManager.on_tile_lost()


# ═══════════════ ARMY SYSTEM (v0.9.2) ═══════════════

func get_max_armies(player_id: int) -> int:
	## Returns max army count for a player. Base 3, upgradable via buildings and research.
	var cap: int = BalanceConfig.MAX_ARMIES_BASE

	# Check buildings: each Lv3 training_ground adds +1 army slot (max +1)
	var training_lv3_count: int = 0
	for tile in tiles:
		if tile.get("owner_id", -1) == player_id:
			var bld: String = tile.get("building_id", "")
			var bld_lv: int = tile.get("building_level", 0)
			if bld == "training_ground" and bld_lv >= 3:
				training_lv3_count += 1

	if training_lv3_count > 0:
		cap += 1  # First Lv3 training ground unlocks +1 army slot

	# Check research: completed "logistics_mastery" tech grants +1 army slot
	if ResearchManager and ResearchManager.has_method("is_completed"):
		if ResearchManager.is_completed(player_id, "logistics_mastery"):
			cap += 1

	# Check faction-specific bonuses
	var faction_id: int = get_player_faction(player_id)
	if faction_id == FactionData.FactionID.ORC:
		# Orcs with WAAAGH! >= frenzy threshold get +1 temporary army
		if OrcMechanic and OrcMechanic.has_method("get_waaagh"):
			if OrcMechanic.get_waaagh(player_id) >= BalanceConfig.WAAAGH_FRENZY_THRESHOLD:
				cap += 1

	return mini(cap, BalanceConfig.MAX_ARMIES_UPGRADED)


func get_player_armies(player_id: int) -> Array:
	## Returns all armies belonging to a player.
	var result: Array = []
	for army_id in armies:
		if armies[army_id]["player_id"] == player_id:
			result.append(armies[army_id])
	return result


func get_army(army_id: int) -> Dictionary:
	## Returns an army by ID, or empty dict if not found.
	return armies.get(army_id, {})


func get_army_at_tile(tile_index: int) -> Dictionary:
	## Returns the army stationed at a tile, or empty dict if none.
	for army_id in armies:
		if armies[army_id]["tile_index"] == tile_index:
			return armies[army_id]
	return {}


func get_army_at_tile_for_player(tile_index: int, player_id: int) -> Dictionary:
	## Returns the army belonging to player at a specific tile.
	for army_id in armies:
		var army: Dictionary = armies[army_id]
		if army["tile_index"] == tile_index and army["player_id"] == player_id:
			return army
	return {}


func create_army(player_id: int, tile_index: int, army_name: String = "") -> int:
	## Creates a new army at the given tile. Returns army_id or -1 on failure.
	if tile_index < 0 or tile_index >= tiles.size():
		return -1
	if tiles[tile_index]["owner_id"] != player_id:
		EventBus.message_log.emit("只能在己方领地创建军团!")
		return -1
	# Check max armies
	var current_armies: Array = get_player_armies(player_id)
	if current_armies.size() >= get_max_armies(player_id):
		EventBus.message_log.emit("军团数已达上限(%d)!" % get_max_armies(player_id))
		return -1
	# Check no army already at this tile (skip for internal split operations)
	if not get_army_at_tile(tile_index).is_empty():
		# Allow co-location if the existing army belongs to the same player (split scenario)
		var existing: Dictionary = get_army_at_tile(tile_index)
		if existing.get("player_id", -1) != player_id:
			EventBus.message_log.emit("该地域已有军团驻扎!")
			return -1

	var army_id: int = _next_army_id
	_next_army_id += 1

	if army_name.is_empty():
		var player: Dictionary = get_player_by_id(player_id)
		army_name = "%s 第%d军团" % [player.get("name", ""), current_armies.size() + 1]

	armies[army_id] = {
		"id": army_id,
		"player_id": player_id,
		"tile_index": tile_index,
		"name": army_name,
		"troops": [],   # Array of troop instances (from GameData.create_troop_instance)
		"heroes": [],   # Array of hero_id strings
		"state": "idle",  # idle | marching | garrisoned | in_combat
	}

	# ── Seed initial troops from tile garrison pool ──
	# Pull up to 2 default infantry squads from the tile's garrison count so the
	# army is immediately combat-ready without requiring a separate recruit step.
	var tile_data: Dictionary = tiles[tile_index]
	var garrison_pool: int = tile_data.get("garrison", 0)
	if garrison_pool > 0 and GameData != null and GameData.has_method("create_troop_instance"):
		var faction_tag: String = _get_faction_tag_for_player(player_id)
		var default_troop_id: String = _get_default_troop_id(faction_tag)
		var squads_to_seed: int = mini(2, garrison_pool)
		for _i in range(squads_to_seed):
			var instance: Dictionary = GameData.create_troop_instance(default_troop_id)
			if not instance.is_empty():
				armies[army_id]["troops"].append(instance)
				EventBus.army_troops_assigned.emit(army_id, default_troop_id, instance.get("soldiers", 0))
		tile_data["garrison"] = maxi(0, garrison_pool - squads_to_seed)

	var troop_count: int = armies[army_id]["troops"].size()
	EventBus.message_log.emit("[color=cyan]创建军团: %s (驻扎于 %s, 初始兵种%d队)[/color]" % [
		army_name, tiles[tile_index]["name"], troop_count])
	EventBus.army_created.emit(player_id, army_id, tile_index)
	if troop_count > 0:
		EventBus.army_ready_to_march.emit(army_id, tile_index)
	return army_id


func disband_army(army_id: int) -> bool:
	## Disbands an army, returning troops to garrison and heroes to pool.
	if not armies.has(army_id):
		return false
	var army: Dictionary = armies[army_id]
	var tile_index: int = army["tile_index"]
	var player_id: int = army["player_id"]

	# Return troops to tile garrison count
	var total_soldiers: int = 0
	for troop in army["troops"]:
		total_soldiers += troop.get("soldiers", 0)
	if tile_index >= 0 and tile_index < tiles.size():
		tiles[tile_index]["garrison"] += total_soldiers

	# BUG FIX R7: Return heroes to the hero pool so they aren't lost
	for hero_id in army.get("heroes", []):
		if HeroSystem and HeroSystem.has_method("unassign_hero_from_army"):
			HeroSystem.unassign_hero_from_army(hero_id)
		elif HeroSystem:
			# Fallback: just make sure the hero is still in recruited_heroes
			if hero_id not in HeroSystem.recruited_heroes:
				HeroSystem.recruited_heroes.append(hero_id)

	EventBus.message_log.emit("解散军团: %s (兵力%d归入驻军, 英雄%d人归队)" % [army["name"], total_soldiers, army.get("heroes", []).size()])
	EventBus.army_disbanded.emit(player_id, army_id)

	if selected_army_id == army_id:
		selected_army_id = -1
	armies.erase(army_id)
	return true


func get_army_combat_power(army_id: int) -> int:
	## Returns total combat power of an army based on its troops.
	if not armies.has(army_id):
		return 0
	var army: Dictionary = armies[army_id]
	var power: int = 0
	for troop in army["troops"]:
		var soldiers: int = troop.get("soldiers", 0)
		var atk: int = troop.get("atk", 10)
		# BUG FIX: integer division truncated per-unit power to 0 for small units
		# (e.g. 2 soldiers × 4 ATK / 10 = 0). Use float division then convert.
		power += int(float(soldiers * atk) / 10.0)
	# Add hero combat bonus
	for hero_id in army["heroes"]:
		power += BalanceConfig.HERO_BASE_COMBAT_POWER  # Base hero power contribution
	return maxi(1, power)


func get_army_soldier_count(army_id: int) -> int:
	## Returns total soldiers in an army.
	if not armies.has(army_id):
		return 0
	var total: int = 0
	for troop in armies[army_id]["troops"]:
		total += troop.get("soldiers", 0)
	return total


## Merge two armies on the same tile (free action, no AP cost)
func action_merge_armies(source_id: int, target_id: int) -> bool:
	if not armies.has(source_id) or not armies.has(target_id):
		EventBus.message_log.emit("Invalid army!")
		return false
	var source: Dictionary = armies[source_id]
	var target: Dictionary = armies[target_id]
	if source["tile_index"] != target["tile_index"]:
		EventBus.message_log.emit("军队必须在同一领地才能合并!")
		return false
	if source["player_id"] != target["player_id"]:
		return false

	# Transfer troops from source to target (BUG FIX: remove transferred troops from source)
	var max_troops: int = get_effective_max_troops(target["player_id"])
	var transferred_troops: Array = []
	for troop in source.get("troops", []):
		if target.get("troops", []).size() >= max_troops:
			EventBus.message_log.emit("目标军队编制已满! 部分兵种留在原军队")
			break
		target["troops"].append(troop)
		transferred_troops.append(troop)
	for troop in transferred_troops:
		source["troops"].erase(troop)

	# Transfer heroes (BUG FIX: remove transferred heroes from source)
	var transferred_heroes: Array = []
	for hero_id in source.get("heroes", []):
		if target.get("heroes", []).size() < MAX_HEROES_PER_ARMY:
			target["heroes"].append(hero_id)
			transferred_heroes.append(hero_id)
	for hero_id in transferred_heroes:
		source["heroes"].erase(hero_id)

	# Remove source if empty
	if source.get("troops", []).is_empty():
		armies.erase(source_id)
		EventBus.message_log.emit("军队合并完成: %s -> %s" % [source["name"], target["name"]])
	else:
		EventBus.message_log.emit("部分兵力合并到 %s (部分兵种超编留原地)" % target["name"])

	sync_player_army(target["player_id"])
	return true


## Split an army: move half the troops to a new army on the same tile
func action_split_army(army_id: int) -> bool:
	if not armies.has(army_id):
		return false
	var army: Dictionary = armies[army_id]
	var pid: int = army["player_id"]
	var troops: Array = army.get("troops", [])

	if troops.size() < 2:
		EventBus.message_log.emit("兵力不足, 无法分割!")
		return false

	# Check army cap
	var current_count: int = get_player_armies(pid).size()
	var max_cap: int = get_max_armies(pid)
	if current_count >= max_cap:
		EventBus.message_log.emit("军队数量已达上限 (%d/%d)!" % [current_count, max_cap])
		return false

	# Create new army on same tile
	var new_name: String = army["name"] + "分队"
	var new_id: int = create_army(pid, army["tile_index"], new_name)
	if new_id <= 0:
		EventBus.message_log.emit("分割失败!")
		return false

	# Move half the troops to new army
	@warning_ignore("integer_division")
	var split_count: int = troops.size() / 2
	var new_army: Dictionary = armies[new_id]
	new_army["troops"] = []
	for i in range(split_count):
		new_army["troops"].append(troops.pop_back())

	EventBus.message_log.emit("军队分割: %s -> %s (%d个编队)" % [army["name"], new_name, split_count])
	sync_player_army(pid)
	return true


## Reinforce an army at owned tile: restore depleted units (1 AP)
func action_reinforce_army(player_id: int, army_id: int) -> bool:
	if not armies.has(army_id):
		return false
	var player: Dictionary = get_player_by_id(player_id)
	if player.get("ap", 0) < 1:
		EventBus.message_log.emit("行動力不足!")
		return false
	var army: Dictionary = armies[army_id]
	if army["player_id"] != player_id:
		return false
	var tile_idx: int = army.get("tile_index", -1)
	if tile_idx < 0 or tiles[tile_idx]["owner_id"] != player_id:
		EventBus.message_log.emit("军队必须在己方领地!")
		return false

	# Reinforce: restore each depleted troop by up to 2 soldiers
	var total_restored: int = 0
	var troops: Array = army.get("troops", [])
	for troop in troops:
		var current: int = troop.get("soldiers", 0)
		var max_sol: int = troop.get("max_soldiers", current)
		if current < max_sol:
			var restore: int = mini(2, max_sol - current)
			# Cost: 5 gold + 2 food per soldier restored
			var cost: Dictionary = {"gold": restore * 5, "food": restore * 2}
			if ResourceManager.can_afford(player_id, cost):
				ResourceManager.apply_delta(player_id, {"gold": -cost["gold"], "food": -cost["food"]})
				troop["soldiers"] = current + restore
				total_restored += restore

	if total_restored > 0:
		player["ap"] -= 1
		EventBus.message_log.emit("军队补充: +%d兵 (消耗金%d 粮%d)" % [total_restored, total_restored * 5, total_restored * 2])
		sync_player_army(player_id)
		EventBus.ap_changed.emit(player_id, player["ap"])
		return true
	else:
		EventBus.message_log.emit("所有部队已满编或资源不足!")
		return false


## Upgrade a troop type in army (e.g., ashigaru -> samurai) — 1 AP + resources
func action_upgrade_troop(player_id: int, army_id: int, troop_index: int) -> bool:
	if not armies.has(army_id):
		return false
	var player: Dictionary = get_player_by_id(player_id)
	if player.get("ap", 0) < 1:
		EventBus.message_log.emit("行動力不足!")
		return false
	var army: Dictionary = armies[army_id]
	var troops: Array = army.get("troops", [])
	if troop_index < 0 or troop_index >= troops.size():
		return false

	var troop: Dictionary = troops[troop_index]
	var current_id: String = troop.get("troop_id", "")

	# Get upgrade path
	var upgrade_id: String = _get_troop_upgrade(current_id)
	if upgrade_id == "":
		EventBus.message_log.emit("该兵种无法升级!")
		return false

	# Upgrade cost
	var cost: Dictionary = {"gold": 40, "iron": 15}
	if not ResourceManager.can_afford(player_id, cost):
		EventBus.message_log.emit("资源不足! 需要金%d 铁%d" % [cost["gold"], cost["iron"]])
		return false

	# Apply upgrade
	ResourceManager.apply_delta(player_id, {"gold": -cost["gold"], "iron": -cost["iron"]})
	var new_data: Dictionary = GameData.TROOP_TYPES.get(upgrade_id, {})
	if new_data.is_empty():
		return false

	var old_name: String = troop.get("name", current_id)
	troop["troop_id"] = upgrade_id
	troop["name"] = new_data.get("name", upgrade_id)
	troop["atk"] = new_data.get("atk", troop["atk"])
	troop["def"] = new_data.get("def", troop["def"])
	troop["spd"] = new_data.get("spd", troop.get("spd", 5))
	troop["max_soldiers"] = new_data.get("max_soldiers", troop["max_soldiers"])
	if new_data.has("passive"):
		troop["passive"] = new_data["passive"]

	player["ap"] -= 1
	EventBus.message_log.emit("兵种升格: %s -> %s (金-%d 铁-%d)" % [old_name, troop["name"], cost["gold"], cost["iron"]])
	EventBus.ap_changed.emit(player_id, player["ap"])
	return true


## Get the upgrade path for a troop type
func _get_troop_upgrade(troop_id: String) -> String:
	# Upgrade paths: T1 -> T2 -> T3
	var upgrade_table: Dictionary = {
		# Orc upgrades
		"orc_ashigaru": "orc_samurai",
		"orc_samurai": "orc_cavalry",
		# Pirate upgrades
		"pirate_ashigaru": "pirate_archer",
		"pirate_archer": "pirate_cannon",
		# Dark Elf upgrades
		"de_samurai": "de_ninja",
		"de_ninja": "de_cavalry",
		# Generic upgrades
		"ashigaru": "samurai",
		"samurai": "cavalry",
		"archer": "ninja",
		"militia": "knight",
		# Human upgrades (for conquered units)
		"human_ashigaru": "human_samurai",
		"human_samurai": "human_cavalry",
	}
	return upgrade_table.get(troop_id, "")


func get_army_deployable_tiles(army_id: int) -> Array:
	## Returns adjacent owned tiles where this army can deploy (move) to.
	if not armies.has(army_id):
		return []
	var army: Dictionary = armies[army_id]
	var player_id: int = army["player_id"]
	var from_tile: int = army["tile_index"]
	var result: Array = []
	if not adjacency.has(from_tile):
		return result
	for nb_idx in adjacency[from_tile]:
		if nb_idx < 0 or nb_idx >= tiles.size():
			continue
		if tiles[nb_idx]["owner_id"] == player_id:
			# Check no army already there
			if get_army_at_tile(nb_idx).is_empty():
				result.append(nb_idx)
	return result


func get_army_attackable_tiles(army_id: int) -> Array:
	## Returns adjacent enemy/neutral tiles this army can attack.
	if not armies.has(army_id):
		return []
	var army: Dictionary = armies[army_id]
	var player_id: int = army["player_id"]
	var from_tile: int = army["tile_index"]
	var result: Array = []
	if not adjacency.has(from_tile):
		return result
	for nb_idx in adjacency[from_tile]:
		if nb_idx < 0 or nb_idx >= tiles.size():
			continue
		if tiles[nb_idx]["owner_id"] != player_id:
			result.append(nb_idx)
	return result


func action_deploy_army(army_id: int, target_tile: int) -> bool:
	## Move an army to an adjacent owned tile. Costs 1 AP.
	## Also cancels any active march order (manual deploy overrides march).
	if not armies.has(army_id):
		return false
	var army: Dictionary = armies[army_id]
	var player_id: int = army["player_id"]
	var player: Dictionary = get_player_by_id(player_id)
	if target_tile < 0 or target_tile >= tiles.size():
		return false
	var required_ap: int = tiles[target_tile].get("terrain_move_cost", 1)
	if player.is_empty() or player["ap"] < required_ap:
		EventBus.message_log.emit("[color=red]行动点不足! 部署需要 %d AP。[/color]" % required_ap)
		return false
	var deployable: Array = get_army_deployable_tiles(army_id)
	if not deployable.has(target_tile):
		EventBus.message_log.emit("[color=red]无法部署到该地域! 目标必须是相邻的己方领地且无其他军队驻扎。[/color]")
		return false

	# Cancel any active march order — manual deploy takes priority
	if MarchSystem != null and MarchSystem.is_army_marching(army_id):
		MarchSystem.cancel_march_order(army_id)
		EventBus.message_log.emit("[color=yellow]手动部署已取消当前行军命令。[/color]")

	var from_tile: int = army["tile_index"]
	army["tile_index"] = target_tile
	var move_ap: int = tiles[target_tile].get("terrain_move_cost", 1)
	player["ap"] -= move_ap

	# Update army state
	army["state"] = "idle"

	_reveal_around(target_tile, player_id)

	# Terrain-aware feedback
	var terrain_tag: String = ""
	var terrain_cost: int = tiles[target_tile].get("terrain_move_cost", 1)
	if terrain_cost > 1:
		terrain_tag = " [%s, 耗%dAP]" % [tiles[target_tile].get("terrain_type", "地形"), terrain_cost]
	EventBus.message_log.emit("[color=cyan]%s 部署到 %s%s[/color]" % [army["name"], tiles[target_tile]["name"], terrain_tag])

	EventBus.army_deployed.emit(player_id, army_id, from_tile, target_tile)
	EventBus.action_visualize_deploy.emit(army_id, from_tile, target_tile)
	EventBus.ap_changed.emit(player_id, player["ap"])
	return true


func action_buy_ap(player_id: int) -> Dictionary:
	## Purchase 1 extra AP with gold. Cost escalates each purchase.
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty():
		return {"success": false, "reason": "玩家不存在"}
	if _ap_purchases_this_turn >= BalanceConfig.AP_BUY_MAX_PER_TURN:
		return {"success": false, "reason": "本回合已达购买上限(%d次)" % BalanceConfig.AP_BUY_MAX_PER_TURN}

	var cost: int = BalanceConfig.AP_BUY_BASE_COST + _ap_purchases_this_turn * BalanceConfig.AP_BUY_COST_SCALE
	var current_gold: int = ResourceManager.get_resource(player_id, "gold")
	if current_gold < cost:
		return {"success": false, "reason": "金币不足(需要%d金, 当前%d金)" % [cost, current_gold]}

	ResourceManager.apply_delta(player_id, {"gold": -cost})
	player["ap"] += 1
	_ap_purchases_this_turn += 1

	var next_cost: int = BalanceConfig.AP_BUY_BASE_COST + _ap_purchases_this_turn * BalanceConfig.AP_BUY_COST_SCALE
	EventBus.message_log.emit("[color=#ffcc44]花费 %d 金购买1行动力 (AP:%d, 下次费用:%d金)[/color]" % [cost, player["ap"], next_cost])
	EventBus.resources_changed.emit(player_id)
	return {"success": true, "cost": cost, "new_ap": player["ap"], "next_cost": next_cost}


func action_forced_march(_army_id: int, _target_tile: int) -> bool:
	## DEPRECATED: Forced march replaced by AP purchase system.
	## Kept for backward compatibility — calls action_buy_ap instead.
	var pid: int = -1
	if armies.has(_army_id):
		pid = armies[_army_id]["player_id"]
	if pid < 0:
		return false
	var result: Dictionary = action_buy_ap(pid)
	return result.get("success", false)


func action_guard_territory(pid: int, tile_index: int) -> bool:
	## Place a guard order on one of the player's own tiles. Costs 1 AP.
	## Grants garrison +20% defense and +50% DEF during combat for 1 turn.
	var player: Dictionary = get_player_by_id(pid)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_index]
	if tile["owner_id"] != pid:
		EventBus.message_log.emit("只能防守自己的领地!")
		return false
	player["ap"] -= 1
	_guard_timers[tile_index] = {"player_id": pid, "turns_remaining": 1}
	var tile_name: String = tile.get("name", TILE_NAMES.get(tile["type"], "领地"))
	EventBus.message_log.emit("[color=cyan]%s 已部署防御! (驻军防御+20%%, 战斗DEF+50%%, 持续1回合)[/color]" % tile_name)
	return true


func _tick_guard_timers(pid: int) -> void:
	## Decrement guard timers for the current player and remove expired ones.
	var to_erase: Array = []
	for tile_index in _guard_timers:
		var guard: Dictionary = _guard_timers[tile_index]
		if guard["player_id"] != pid:
			continue
		guard["turns_remaining"] -= 1
		if guard["turns_remaining"] <= 0:
			to_erase.append(tile_index)
	for key in to_erase:
		_guard_timers.erase(key)


## ── SAT (満足度) System ──

func get_sat_points(pid: int) -> int:
	return _sat_points.get(pid, 0)


func action_sat_event(pid: int, hero_id: String) -> bool:
	## Free action (costs 0 AP). Spends 1 SAT point to trigger a hero affection event.
	## Increases hero affection by 1 and grants small rewards scaling with affection.
	## Works for ALL factions with faction-appropriate flavor text.
	if _sat_points.get(pid, 0) < BalanceConfig.SAT_EVENT_COST:
		EventBus.message_log.emit("[color=red]満足度不足! (需要%d)[/color]" % BalanceConfig.SAT_EVENT_COST)
		return false
	if HeroSystem == null or hero_id not in HeroSystem.recruited_heroes:
		EventBus.message_log.emit("[color=red]该英雄未在麾下![/color]")
		return false

	# Consume SAT
	_sat_points[pid] = _sat_points.get(pid, 0) - BalanceConfig.SAT_EVENT_COST

	# Get current affection and increase
	var current_aff: int = HeroSystem.hero_affection.get(hero_id, 0)
	var new_aff: int = mini(current_aff + BalanceConfig.SAT_EVENT_AFFECTION_GAIN, FactionData.AFFECTION_MAX)
	HeroSystem.hero_affection[hero_id] = new_aff
	EventBus.hero_affection_changed.emit(hero_id, new_aff)

	# Calculate rewards scaling with affection
	var gold_reward: int = BalanceConfig.SAT_REWARD_GOLD_BASE + BalanceConfig.SAT_REWARD_GOLD_PER_AFF * new_aff
	ResourceManager.apply_delta(pid, {"gold": gold_reward})

	# Morale buff via BuffManager
	@warning_ignore("integer_division")
	var morale_val: int = BalanceConfig.SAT_REWARD_MORALE_BUFF + (new_aff / 3)
	var morale_dur: int = BalanceConfig.SAT_REWARD_MORALE_DURATION
	BuffManager.apply_buff(pid, "sat_morale", {"morale_boost": morale_val}, morale_dur)

	# Faction-aware flavor text
	var hero_name: String = HeroSystem.get_hero_display_name(hero_id) if HeroSystem != null and HeroSystem.has_method("get_hero_display_name") else hero_id
	var faction_tag: String = _get_faction_tag_for_player(pid)
	var flavor: String
	match faction_tag:
		"pirate":
			flavor = "【船上宴会】与 %s 畅饮!" % hero_name
		"orc":
			flavor = "【训练场】与 %s 切磋武艺!" % hero_name
		"dark_elf":
			flavor = "【暗影仪式】与 %s 共修暗术!" % hero_name
		_:
			flavor = "【训练时光】与 %s 共同训练!" % hero_name
	EventBus.message_log.emit("[color=pink]%s 好感度→%d, +%d金, 士気+%d(%d回合)[/color]" % [
		flavor, new_aff, gold_reward, morale_val, morale_dur])
	return true


func action_gift_hero(hero_id: String) -> Dictionary:
	## Universal gift-giving action. Costs 30g, +1 affection, 1/turn cooldown per hero.
	## Works for ALL factions — delegates to HeroSystem gift system.
	var pid: int = get_human_player_id()
	if HeroSystem == null or hero_id not in HeroSystem.recruited_heroes:
		return {"ok": false, "desc": "英雄未在麾下"}
	if not HeroSystem.can_give_gift(hero_id):
		if HeroSystem.hero_affection.get(hero_id, 0) >= FactionData.AFFECTION_MAX:
			return {"ok": false, "desc": "好感度已满"}
		return {"ok": false, "desc": "赠礼冷却中 (每回合限1次)"}
	if not ResourceManager.can_afford(pid, {"gold": 30}):
		return {"ok": false, "desc": "金币不足 (需要30金)"}

	ResourceManager.spend(pid, {"gold": 30})
	var current_aff: int = HeroSystem.hero_affection.get(hero_id, 0)
	var new_aff: int = mini(current_aff + 1, FactionData.AFFECTION_MAX)
	HeroSystem.hero_affection[hero_id] = new_aff
	HeroSystem._gift_cooldowns[hero_id] = FactionData.GIFT_COOLDOWN_TURNS
	EventBus.hero_affection_changed.emit(hero_id, new_aff)

	var hero_name: String = HeroSystem.get_hero_display_name(hero_id) if HeroSystem != null and HeroSystem.has_method("get_hero_display_name") else hero_id
	EventBus.message_log.emit("[color=pink]赠礼 %s! -30金, 好感度+1 (当前: %d)[/color]" % [hero_name, new_aff])
	return {"ok": true, "desc": "赠礼成功", "affection": new_aff}


func action_attack_with_army(army_id: int, target_tile_index: int) -> bool:
	## Attack a target tile with a specific army. Costs 1 AP.
	if not armies.has(army_id):
		return false
	var army: Dictionary = armies[army_id]
	var total_soldiers: int = 0
	for troop in army.get("troops", []):
		total_soldiers += troop.get("soldiers", 0)
	if total_soldiers <= 0:
		EventBus.message_log.emit("军团没有士兵, 无法进攻!")
		return false
	var player_id: int = army["player_id"]
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if target_tile_index < 0 or target_tile_index >= tiles.size():
		return false

	var tile: Dictionary = tiles[target_tile_index]
	# BUG FIX R15: null check on tile
	if tile == null:
		return false
	if tile["owner_id"] == player_id:
		EventBus.message_log.emit("不能攻击自己的领地!")
		return false

	# Verify adjacency from army's current tile
	var attackable: Array = get_army_attackable_tiles(army_id)
	if not attackable.has(target_tile_index):
		EventBus.message_log.emit("目标必须与军团所在地域相邻!")
		return false

	# ── Siege check (v5.0): Fortified tiles require siege ──
	if SiegeSystem.is_tile_fortified(target_tile_index):
		var existing_siege: Dictionary = SiegeSystem.get_siege_at_tile(target_tile_index)
		if existing_siege.is_empty():
			# No active siege — start one instead of immediate combat
			player["ap"] -= 1
			SiegeSystem.start_siege(army_id, target_tile_index)
			EventBus.player_arrived.emit(player_id, target_tile_index)
			EventBus.ap_changed.emit(player_id, player["ap"])
			return true  # BUG FIX R10: Return true since AP was consumed for siege start
		elif existing_siege.get("wall_hp", 1.0) > 0.0:
			if existing_siege.get("turns_remaining", 1) > 0:
				# Siege ongoing, walls not breached yet
				EventBus.message_log.emit("[color=yellow]围攻进行中，城壁尚未崩塌! (剩余%d回合)[/color]" % existing_siege.get("turns_remaining", 0))
				return false
			else:
				# BUG FIX R10: Siege expired but walls not breached — siege fizzles,
				# don't auto-trigger assault without storm penalty.
				SiegeSystem.lift_siege(existing_siege.get("siege_id", ""))
				EventBus.message_log.emit("[color=yellow]围攻超时，城壁未被攻破。围攻解除。[/color]")
				return false
		# else: wall_hp <= 0 → proceed with final assault (attacker ATK bonus applied below)

	player["ap"] -= 1
	_had_combat_this_turn = true
	_combat_slot_prefs = get_army_slot_preferences(army_id)
	_combat_unit_commands = get_army_unit_commands(army_id)

	# Determine defender description
	var defender_desc: String = _get_defender_desc(tile)

	# Apply threat garrison bonus for light faction tiles
	var original_garrison: int = tile["garrison"]
	if tile.get("light_faction", -1) >= 0:
		var bonus: float = ThreatManager.get_garrison_bonus()
		if bonus > 0.0:
			tile["garrison"] = int(float(original_garrison) * (1.0 + bonus))

	# Apply guard territory garrison bonus (+20% garrison)
	var _guard_data: Dictionary = _guard_timers.get(target_tile_index, {})
	if not _guard_data.is_empty() and _guard_data.get("player_id", -1) == tile.get("owner_id", -2):
		tile["garrison"] = int(float(tile["garrison"]) * 1.2)
		EventBus.message_log.emit("[color=cyan]防御部署生效! 驻军防御+20%%[/color]")

	# Resolve combat: army vs garrison
	var won: bool = await _resolve_army_combat(army, tile, defender_desc)

	# Always restore garrison to original before post-combat processing
	# (_capture_tile computes new garrison from this value)
	tile["garrison"] = original_garrison

	EventBus.action_visualize_attack.emit(army["tile_index"], target_tile_index, {"won": won, "army_id": army_id})

	if won:
		# Army moves into captured tile
		var from_tile: int = army["tile_index"]
		_capture_tile(player, tile)
		army["tile_index"] = target_tile_index
		_reveal_around(target_tile_index, player_id)

		# Handle special tile captures
		if tile["type"] == TileType.LIGHT_STRONGHOLD or tile["type"] == TileType.CORE_FORTRESS:
			var faction_id: int = get_player_faction(player_id)
			FactionManager.on_stronghold_captured(player_id, faction_id)
		# Handle neutral quest on capture
		var nf_id: int = tile.get("neutral_faction_id", -1)
		if nf_id >= 0:
			_handle_neutral_quest(player, nf_id)
		check_win_condition()
		EventBus.army_deployed.emit(player_id, army_id, from_tile, target_tile_index)

	EventBus.player_arrived.emit(player_id, target_tile_index)
	return won


## v5.0: Storm the walls of a besieged tile. Costs 2 AP. Triggers combat with DEF penalty.
func action_storm_walls(army_id: int, tile_index: int) -> bool:
	if not armies.has(army_id):
		return false
	var army: Dictionary = armies[army_id]
	var player_id: int = army["player_id"]
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < SiegeSystem.STORM_AP_COST:
		EventBus.message_log.emit("强攻需要%d行动点!" % SiegeSystem.STORM_AP_COST)
		return false
	var siege: Dictionary = SiegeSystem.get_siege_at_tile(tile_index)
	if siege.is_empty():
		EventBus.message_log.emit("该据点没有进行中的围攻!")
		return false
	# Mark as stormed (applies DEF penalty in combat) and remove siege
	SiegeSystem.storm_walls(siege["siege_id"])
	# Spend extra AP (action_attack_with_army costs 1 more AP internally)
	player["ap"] -= (SiegeSystem.STORM_AP_COST - 1)
	return await action_attack_with_army(army_id, tile_index)


## Direction C: Multi-route coordinated attack (合战). 2-4 armies attack one tile simultaneously.
## Each army fights in sequence; defender carries damage between phases.
## Costs 1 AP per participating army (from each army's owner).
func action_multi_route_attack(army_ids: Array, target_tile_index: int) -> bool:
	var validation: Dictionary = MultiRouteBattle.validate_multi_route(
		army_ids, target_tile_index,
		func(aid): return armies.get(aid, {})
	)
	if not validation["valid"]:
		EventBus.message_log.emit("[color=red]合战失败: %s[/color]" % validation["reason"])
		return false

	var tile: Dictionary = tiles[target_tile_index]
	if tile.get("owner_id", -1) == armies[army_ids[0]]["player_id"]:
		EventBus.message_log.emit("不能对自己的领地发动合战!")
		return false

	# Build routes
	var directions: Array = [
		MultiRouteBattle.Direction.NORTH, MultiRouteBattle.Direction.SOUTH,
		MultiRouteBattle.Direction.EAST, MultiRouteBattle.Direction.WEST,
	]
	var routes: Array = []
	for i in range(army_ids.size()):
		var army: Dictionary = armies[army_ids[i]]
		var terrain_str: String = tile.get("terrain", "plains").to_lower()
		routes.append(MultiRouteBattle.create_route(army, directions[i], terrain_str))

	# Build defender data
	var defender_data: Dictionary = {
		"units": [{"soldiers": tile["garrison"], "base_def": tile.get("city_def", 5)}],
		"garrison": tile["garrison"],
	}

	var battle_ctx: Dictionary = MultiRouteBattle.create_battle(routes, defender_data, target_tile_index)
	if battle_ctx.is_empty():
		return false

	MultiRouteBattle.prepare_routes(battle_ctx)

	# Consume 1 AP from each army's owner
	var owners_charged: Dictionary = {}
	for aid in army_ids:
		var army: Dictionary = armies[aid]
		var pid: int = army["player_id"]
		if not owners_charged.has(pid):
			var p: Dictionary = get_player_by_id(pid)
			if p.get("ap", 0) < 1:
				EventBus.message_log.emit("[color=red]%s 行动力不足, 无法参加合战[/color]" % p.get("name", ""))
				return false
			p["ap"] -= 1
			owners_charged[pid] = true
			EventBus.ap_changed.emit(pid, p["ap"])

	_had_combat_this_turn = true
	EventBus.message_log.emit("[color=gold]═══ 合战开始! %d路军团协同进攻 %s ═══[/color]" % [army_ids.size(), tile.get("name", "目标")])

	# Resolve each route's combat phase sequentially
	var any_won: bool = false
	for i in range(battle_ctx["route_count"]):
		var route: Dictionary = battle_ctx["routes"][i]
		var army: Dictionary = armies[route["army_id"]]
		var dir_name: String = MultiRouteBattle.DIRECTION_NAMES_CN.get(route["direction"], "")
		EventBus.message_log.emit("[color=cyan]第%d路(%s路) %s 发起进攻![/color]" % [i + 1, dir_name, army.get("name", "军团")])

		# Use existing combat resolution
		var phase_won: bool = await _resolve_army_combat(army, tile, tile.get("name", "守军"))
		var phase_result: Dictionary = {
			"attacker_won": phase_won,
			"defender_remaining_soldiers": tile["garrison"],
			"attacker_losses": 0,
			"defender_losses": 0,
			"rounds_fought": 8,
		}

		var more_phases: bool = MultiRouteBattle.record_phase_result(battle_ctx, i, phase_result)
		if phase_won:
			any_won = true
		if not more_phases:
			break

	# Get summary
	var summary: Dictionary = MultiRouteBattle.get_battle_summary(battle_ctx)
	var defender_survived: bool = summary.get("defender_survived", true)

	if not defender_survived or any_won:
		# First winning army captures the tile
		for aid in army_ids:
			var army: Dictionary = armies[aid]
			var player: Dictionary = get_player_by_id(army["player_id"])
			_capture_tile(player, tile)
			army["tile_index"] = target_tile_index
			_reveal_around(target_tile_index, army["player_id"])
			break
		check_win_condition()
		EventBus.message_log.emit("[color=gold]合战胜利! %s 已攻陷![/color]" % tile.get("name", "目标"))
	else:
		EventBus.message_log.emit("[color=red]合战失败! %s 守住了阵地。[/color]" % tile.get("name", "守军"))

	return any_won


## v5.0: Aggregate strategic resource buffs for a player.
func get_strategic_buffs(player_id: int) -> Dictionary:
	return SiegeSystem.get_strategic_buffs(player_id)


func _get_defender_desc(tile: Dictionary) -> String:
	## Returns a localized defender description for a tile.
	match tile["type"]:
		TileType.LIGHT_STRONGHOLD:
			return "光明联盟要塞守军"
		TileType.CORE_FORTRESS:
			return tile.get("name", "核心要塞") + "守军"
		TileType.NEUTRAL_BASE:
			var nf_name: String = FactionData.NEUTRAL_FACTION_NAMES.get(tile.get("neutral_faction_id", -1), "中立势力")
			return nf_name + "守军"
		_:
			if tile["owner_id"] >= 0:
				var _p = get_player_by_id(tile["owner_id"])
				return (_p.get("name", "敌军") if not _p.is_empty() else "敌军") + "据点"
	return "守军"


func _resolve_army_combat(army: Dictionary, tile: Dictionary, defender_desc: String) -> bool:
	## Resolves combat between an army and a tile's garrison using CombatSystem.
	## Returns true if army wins.
	var player: Dictionary = get_player_by_id(army["player_id"])
	var pid: int = army["player_id"]

	# Auto-save before combat
	var def_owner_id: int = tile.get("owner_id", -1)
	if pid == get_human_player_id() or def_owner_id == get_human_player_id():
		var _settings_node = get_tree().get_root().find_child("SettingsPanel", true, false)
		var _auto_save_on: bool = true
		if _settings_node and _settings_node.has_method("get_setting"):
			_auto_save_on = _settings_node.get_setting("auto_save") != false
		if _auto_save_on:
			SaveManager.auto_save()

	# BUG FIX: reset enchantment combat state to prevent rage stacks persisting across battles
	if EnchantmentSystem and EnchantmentSystem.has_method("reset_combat_state"):
		EnchantmentSystem.reset_combat_state()

	# Build attacker army dict for CombatSystem
	var attacker_units: Array = []
	var slot_idx: int = 0
	for troop in army["troops"]:
		if troop.get("soldiers", 0) <= 0:
			continue
		# BUG FIX: assign heroes round-robin to unit slots, not just first hero to slot 0
		var _cmd_id: String = "generic"
		if army["heroes"].size() > 0 and slot_idx < army["heroes"].size():
			_cmd_id = army["heroes"][slot_idx]
		var _unit_dict: Dictionary = {
			"id": "att_%d" % slot_idx,
			"commander_id": _cmd_id,
			"troop_id": troop.get("troop_id", "infantry"),
			# BUG FIX: troop instances don't have atk/def keys; look up from troop definition
			"atk": GameData.get_troop_def(troop.get("troop_id", "")).get("base_atk", 5) + player.get("atk_bonus", 0),
			"def": GameData.get_troop_def(troop.get("troop_id", "")).get("base_def", 5) + player.get("def_bonus", 0),
			"spd": GameData.get_troop_def(troop.get("troop_id", "")).get("base_spd", 5),
			"int": GameData.get_troop_def(troop.get("troop_id", "")).get("base_int", 5),
			"soldiers": troop.get("soldiers", 0),
			"max_soldiers": troop.get("max_soldiers", troop.get("soldiers", 0)),
			"row": troop.get("row", 0 if slot_idx < 3 else 1),
			"slot": slot_idx,
			"passive": troop.get("passive", ""),
		}
		# v4.4: Inject hero combat stats & equipment passives for CombatSystem v2
		if _cmd_id != "generic" and _cmd_id != "" and HeroSystem != null:
			var _hero_stats: Dictionary = HeroSystem.get_hero_combat_stats(_cmd_id)
			if not _hero_stats.is_empty():
				_unit_dict["hero_data"] = {
					"id": _cmd_id,
					"hp": _hero_stats.get("hp", 20),
					"mp": _hero_stats.get("mp", 10),
					"troop_specialty": _hero_stats.get("troop", ""),
					"equipment_passives": _hero_stats.get("equipment_passives", []),
				}
				# Apply hero stat bonuses to the unit
				_unit_dict["atk"] += _hero_stats.get("atk", 0)
				_unit_dict["def"] += _hero_stats.get("def", 0)
				_unit_dict["spd"] += _hero_stats.get("spd", 0)
				_unit_dict["int"] += _hero_stats.get("int_stat", 0)
		attacker_units.append(_unit_dict)
		slot_idx += 1

	# Build defender army dict from garrison
	var defender_units: Array = []
	var garrison_troops: Array = []
	if RecruitManager != null and RecruitManager.has_method("get_garrison"):
		garrison_troops = RecruitManager.get_garrison(tile.get("index", 0))

	if not garrison_troops.is_empty():
		slot_idx = 0
		for gt in garrison_troops:
			if gt.get("soldiers", 0) <= 0:
				continue
			defender_units.append({
				"id": "def_%d" % slot_idx,
				"commander_id": "generic",
				"troop_id": gt.get("troop_id", "infantry"),
				# BUG FIX: garrison troop instances don't have atk/def; look up from definition
				"atk": GameData.get_troop_def(gt.get("troop_id", "")).get("base_atk", 5),
				"def": GameData.get_troop_def(gt.get("troop_id", "")).get("base_def", 5),
				"spd": GameData.get_troop_def(gt.get("troop_id", "")).get("base_spd", 5),
				"int": GameData.get_troop_def(gt.get("troop_id", "")).get("base_int", 5),
				"soldiers": gt.get("soldiers", 0),
				"max_soldiers": gt.get("max_soldiers", gt.get("soldiers", 0)),
				"row": gt.get("row", 0 if slot_idx < 3 else 1),
				"slot": slot_idx,
				"passive": gt.get("passive", ""),
			})
			slot_idx += 1
	else:
		# Fallback: create generic garrison units from tile["garrison"] count
		var gar: int = tile.get("garrison", 0)
		if gar > 0:
			# Split garrison into front-row squads of ~10 soldiers each
			var squads: int = clampi(ceili(float(gar) / 10.0), 1, 3)
			var per_squad: int = gar / squads
			for i in range(squads):
				var s: int = maxi(0, per_squad if i < squads - 1 else gar - per_squad * (squads - 1))
				defender_units.append({
					"id": "def_%d" % i,
					"commander_id": "generic",
					"troop_id": "human_ashigaru",
					"atk": 4, "def": 6, "spd": 4, "int": 3,
					"soldiers": s, "max_soldiers": s,
					"row": 0, "slot": i,
					"passive": "fort_def_3",
				})

	if attacker_units.is_empty():
		return false
	if defender_units.is_empty():
		return true  # Undefended tile

	# Determine terrain and siege
	var terrain_enum: int = tile.get("terrain", 0)  # Already int enum from FactionData.TerrainType
	var is_siege: bool = tile.get("wall_hp", 0) > 0 or tile.get("core_fortress_wall_hp", 0) > 0
	var city_def: int = tile.get("wall_hp", tile.get("core_fortress_wall_hp", 0))

	# Apply faction-specific ATK bonuses to attacker units
	var faction_id: int = get_player_faction(pid)
	if faction_id == FactionData.FactionID.ORC:
		OrcMechanic.apply_waaagh_bonus_to_units(pid, attacker_units)
	elif faction_id == FactionData.FactionID.PIRATE:
		PirateMechanic.apply_rum_bonus_to_units(pid, attacker_units)

	# v4.4: Apply consumable item buffs to attacker units before combat
	var _atk_mult: float = BuffManager.get_atk_multiplier(pid)
	var _def_mult: float = BuffManager.get_def_multiplier(pid)
	if _atk_mult != 1.0 or _def_mult != 1.0:
		for au in attacker_units:
			if _atk_mult != 1.0:
				au["atk"] = int(ceil(float(au["atk"]) * _atk_mult))
			if _def_mult != 1.0:
				au["def"] = int(ceil(float(au["def"]) * _def_mult))

	# v4.4: Apply wall_damage buff to siege (blast_barrel, etc.)
	var _wall_dmg_buff: int = BuffManager.get_buff_value(pid, "wall_damage") as int
	if _wall_dmg_buff > 0 and city_def > 0:
		city_def = maxi(0, city_def - _wall_dmg_buff)
		EventBus.message_log.emit("[color=orange]爆破桶削减城防 -%d (剩余%d)[/color]" % [_wall_dmg_buff, city_def])

	# v4.4: Relic first_hit_immune — reduce attacker losses by adding DEF bonus
	var _has_first_hit: bool = RelicManager.has_first_hit_immune(pid)

	# v4.4: mage_weaken buff — halve ATK of enemy mage-type units
	var _mage_weaken: bool = BuffManager.get_buff_value(pid, "mage_weaken") as bool
	if _mage_weaken:
		for du in defender_units:
			var _du_troop: String = du.get("troop_id", "").to_lower()
			if _du_troop.find("mage") != -1 or _du_troop.find("apprentice") != -1:
				du["atk"] = int(float(du.get("atk", 5)) * 0.5)
		EventBus.message_log.emit("[color=blue]法力干扰器生效: 敌方法师攻击减半![/color]")

	# Guard territory DEF bonus: +50% DEF for all defender units on guarded tile
	var _guard_tile_idx: int = tile.get("index", -1)
	var _guard_info: Dictionary = _guard_timers.get(_guard_tile_idx, {})
	if not _guard_info.is_empty() and _guard_info.get("player_id", -1) == tile.get("owner_id", -2):
		for du in defender_units:
			du["def"] = int(ceil(float(du.get("def", 5)) * 1.5))
		EventBus.message_log.emit("[color=cyan]防御部署生效! 守军DEF+50%%[/color]")

	# SR07: Garrison commander DEF bonus
	var _cmd_bonus: Dictionary = HeroSystem.get_garrison_commander_bonus(tile.get("index", -1)) if HeroSystem != null else {}
	if _cmd_bonus.get("def_mult", 1.0) > 1.0:
		for du in defender_units:
			du["def"] = int(ceil(float(du.get("def", 5)) * _cmd_bonus["def_mult"]))
		if _cmd_bonus.get("garrison_add", 0) > 0 and not defender_units.is_empty():
			defender_units[0]["soldiers"] += _cmd_bonus["garrison_add"]
			defender_units[0]["max_soldiers"] += _cmd_bonus["garrison_add"]
		EventBus.message_log.emit("[color=cyan]驻防武将%s增援! DEF+25%%, 守军+%d[/color]" % [_cmd_bonus.get("hero_name", ""), _cmd_bonus.get("garrison_add", 0)])

	var attacker_data: Dictionary = {"units": attacker_units, "player_id": pid}

	# ── Siege combat modifiers (v5.0) ──
	var _siege_at_tile: Dictionary = SiegeSystem.get_siege_at_tile(tile.get("index", -1))
	if not _siege_at_tile.is_empty():
		if _siege_at_tile.get("stormed", false):
			# Storm penalty: attacker DEF -30%
			for au in attacker_units:
				au["def"] = int(ceil(float(au.get("def", 5)) * (1.0 - SiegeSystem.STORM_DEF_PENALTY)))
			EventBus.message_log.emit("[color=red]强攻惩罚: 攻方DEF-%.0f%%[/color]" % (SiegeSystem.STORM_DEF_PENALTY * 100.0))
		elif _siege_at_tile.get("wall_hp", 1.0) <= 0.0:
			# Final assault bonus: attacker ATK +20%
			for au in attacker_units:
				au["atk"] = int(ceil(float(au.get("atk", 5)) * (1.0 + SiegeSystem.ASSAULT_ATK_BONUS)))
			EventBus.message_log.emit("[color=green]城壁崩塌! 攻方ATK+%.0f%%[/color]" % (SiegeSystem.ASSAULT_ATK_BONUS * 100.0))

	# Apply pre-battle slot preferences for human player
	if not _combat_slot_prefs.is_empty() and pid == get_human_player_id():
		_apply_slot_preferences_to_units(attacker_units, _combat_slot_prefs)
		_combat_slot_prefs = {}
	# Inject per-unit battle commands for human player
	if not _combat_unit_commands.is_empty() and pid == get_human_player_id():
		attacker_data["unit_commands"] = _combat_unit_commands
		_combat_unit_commands = {}
	var defender_data: Dictionary = {"units": defender_units}
	var node_data: Dictionary = {
		"terrain": terrain_enum,
		"is_siege": is_siege,
		"city_def": city_def,
	}

	EventBus.combat_started.emit(pid, tile.get("index", 0))

	# Run CombatSystem
	var combat: CombatSystem = CombatSystem.new()
	# Enable Commander Intervention for human player
	var is_human: bool = pid == get_human_player_id()
	if is_human:
		combat.player_controlled = true
		var hero_list: Array = []
		for au in attacker_units:
			if au.get("commander_id", "generic") != "generic":
				hero_list.append({"id": au["commander_id"], "passives": au.get("passive", "").split(",")})
		CommanderIntervention.initialize_for_battle(attacker_units, hero_list)
	var result: Dictionary = await combat.resolve_battle(attacker_data, defender_data, node_data)

	# Add title for combat view display
	result["title"] = "%s 进攻 %s" % [army.get("name", "军团"), defender_desc]

	# Request combat view visualization (human player only)
	if pid == get_human_player_id():
		EventBus.combat_view_requested.emit(result)

	var won: bool = result.get("winner", "defender") == "attacker"
	var att_losses: Dictionary = result.get("attacker_losses", {})
	var def_losses: Dictionary = result.get("defender_losses", {})
	var captured_heroes: Array = result.get("captured_heroes", [])

	# v4.4: Consume one-use combat buffs after battle
	if _atk_mult != 1.0:
		BuffManager.consume_buff(pid, "atk_mult")
	if _def_mult != 1.0:
		BuffManager.consume_buff(pid, "def_mult")
	if _wall_dmg_buff > 0:
		BuffManager.consume_buff(pid, "wall_damage")
	if BuffManager.has_guaranteed_slave(pid) and won:
		BuffManager.consume_buff(pid, "guaranteed_slave")

	# v4.4: Relic first_hit_immune — reduce attacker losses by 30%
	if _has_first_hit and won:
		for key in att_losses:
			att_losses[key] = maxi(0, att_losses[key] - int(float(att_losses[key]) * 0.3))
		EventBus.message_log.emit("[color=purple]暗影斗篷: 进攻方损失减少30%![/color]")

	# Apply losses to attacker army troops
	# BUG FIX: match by slot index instead of troop_id to handle duplicate troop types
	for i in range(mini(army["troops"].size(), attacker_units.size())):
		var au: Dictionary = attacker_units[i]
		if att_losses.has(au["id"]):
			army["troops"][i]["soldiers"] = maxi(0, army["troops"][i]["soldiers"] - att_losses[au["id"]])

	if won:
		tile["garrison"] = 0
		tile["wall_hp"] = 0
		if RecruitManager != null and RecruitManager.has_method("clear_garrison_troops"):
			RecruitManager.clear_garrison_troops(tile.get("index", 0))
		EventBus.message_log.emit("[color=green]%s 攻克 %s![/color]" % [army["name"], defender_desc])

		# v4.4: Slave capture on v2 victory
		var _slaves_captured: int = 1
		# Relic: victory_slave_bonus
		var _relic_slave: int = RelicManager.get_victory_slave_bonus(pid)
		if _relic_slave > 0:
			_slaves_captured += _relic_slave
		# Buff: guaranteed_slave (already consumed above)
		if BuffManager.has_buff(pid, "item_slave"):
			_slaves_captured = maxi(_slaves_captured, 2)
		if SlaveManager.has_method("add_slaves"):
			SlaveManager.add_slaves(pid, _slaves_captured)
			if _slaves_captured > 1:
				EventBus.message_log.emit("俘获 %d 名奴隶" % _slaves_captured)

		# Handle captured heroes
		for hero_id in captured_heroes:
			if HeroSystem != null:
				HeroSystem.attempt_capture(str(hero_id))
	else:
		# Garrison takes losses but survives
		# BUG FIX: match by slot index to handle duplicate troop types correctly
		if not garrison_troops.is_empty():
			for i in range(mini(garrison_troops.size(), defender_units.size())):
				var gt = garrison_troops[i]
				var du = defender_units[i]
				if def_losses.has(du["id"]):
					gt["soldiers"] = maxi(0, gt["soldiers"] - def_losses[du["id"]])
		else:
			var total_def_lost: int = 0
			for key in def_losses:
				total_def_lost += def_losses[key]
			tile["garrison"] = maxi(1, tile["garrison"] - total_def_lost)
		EventBus.message_log.emit("[color=red]%s 进攻 %s 失败! (军团撤回)[/color]" % [army["name"], defender_desc])

	EventBus.combat_result.emit(pid, defender_desc, won)
	_record_battle_stat(pid, won)

	# BUG FIX R7: Remove zombie troops with 0 soldiers from army after combat
	var surviving_troops: Array = []
	for troop in army["troops"]:
		if troop.get("soldiers", 0) > 0:
			surviving_troops.append(troop)
	army["troops"] = surviving_troops

	# ── 英雄经验 (v3.1) ──
	_grant_hero_combat_exp(pid, result, won)

	# ── Hidden Heroes: record battle victory and check conditions ──
	if won and pid == get_human_player_id() and HeroSystem != null:
		HeroSystem.record_battle_victory()
		HeroSystem.check_hidden_hero_conditions(pid)

	# ── 战斗战利品掉落 (v3.5) ──
	if won and pid == get_human_player_id():
		ItemManager.grant_random_loot(pid)

	_cleanup_army_troops(army)
	return won


func _terrain_to_combat_enum(terrain: String) -> int:
	## Convert terrain string to CombatSystem.Terrain enum.
	match terrain:
		"plains": return 0   # CombatSystem.Terrain.PLAINS
		"forest": return 1   # CombatSystem.Terrain.FOREST
		"mountain": return 2 # CombatSystem.Terrain.MOUNTAIN
		"swamp": return 3    # CombatSystem.Terrain.SWAMP
		"coastal": return 4  # BUG FIX: was missing, defaulting to PLAINS
		"wall": return 5     # CombatSystem.Terrain.FORTRESS
	return 0


func _apply_army_losses(army: Dictionary, loss_ratio: float) -> void:
	## Apply proportional losses to all troops in an army.
	for troop in army["troops"]:
		var loss: int = maxi(1, int(float(troop["soldiers"]) * loss_ratio))
		troop["soldiers"] = maxi(0, troop["soldiers"] - loss)


func _cleanup_army_troops(army: Dictionary) -> void:
	## Remove troops with 0 soldiers from army. Disband if empty.
	var alive_troops: Array = []
	for troop in army["troops"]:
		if troop.get("soldiers", 0) > 0:
			alive_troops.append(troop)
	army["troops"] = alive_troops
	# If army has no troops left, disband it
	if army["troops"].is_empty():
		EventBus.message_log.emit("[color=red]%s 全军覆没![/color]" % army["name"])
		disband_army(army["id"])


# ── 英雄经验辅助 (v3.1) ──

func _get_player_hero_ids(player_id: int) -> Array:
	## Returns all hero IDs across all armies belonging to the player.
	var hero_ids: Array = []
	for army_id in armies:
		var army: Dictionary = armies[army_id]
		if army["player_id"] == player_id:
			for hero_id in army.get("heroes", []):
				if hero_id not in hero_ids:
					hero_ids.append(hero_id)
	return hero_ids


func _grant_hero_combat_exp(pid: int, result: Dictionary, attacker_wins: bool) -> void:
	## Grants hero EXP to all heroes in the player's armies after combat.
	var hero_ids: Array = _get_player_hero_ids(pid)
	if hero_ids.is_empty():
		return

	# Base EXP from win/loss
	var hero_exp_base: int = BalanceConfig.HERO_EXP_COMBAT_WIN if attacker_wins else BalanceConfig.HERO_EXP_COMBAT_LOSS
	# Bonus for kills (if available in result)
	var enemy_killed: int = result.get("enemy_troops_killed", result.get("troops_killed", 0))
	hero_exp_base += enemy_killed * BalanceConfig.HERO_EXP_PER_KILL
	# Boss bonus if defeated a hero-led army
	if result.get("defeated_hero", false) or result.get("enemy_hero_id", "") != "":
		hero_exp_base += BalanceConfig.HERO_EXP_BOSS_BONUS
	# 败方经验减半（从失败中学习，但收益只有胜方的50%）
	if not attacker_wins:
		hero_exp_base = int(float(hero_exp_base) * 0.5)
	# Apply difficulty multiplier
	hero_exp_base = int(float(hero_exp_base) * BalanceManager.get_player_xp_mult())

	# Grant to all heroes in the participating armies
	for hero_id in hero_ids:
		var level_result: Dictionary = HeroLeveling.grant_hero_exp(hero_id, hero_exp_base)
		if level_result.get("leveled_up", false):
			EventBus.message_log.emit("[color=yellow][升级] %s 升至 Lv%d！[/color]" % [
				FactionData.HEROES.get(hero_id, {}).get("name", hero_id),
				level_result.get("new_level", 1)])
			for p in level_result.get("unlocked_passives", []):
				EventBus.message_log.emit("[color=cyan][技能] %s 解锁被动: %s[/color]" % [
					FactionData.HEROES.get(hero_id, {}).get("name", hero_id),
					p.get("name", p.get("passive_id", ""))])

	# Shared battle affection: heroes in winning battles gain +1 affection
	if attacker_wins and HeroSystem != null:
		for hero_id in hero_ids:
			var current_aff: int = HeroSystem.hero_affection.get(hero_id, 0)
			if current_aff < FactionData.AFFECTION_MAX:
				HeroSystem.hero_affection[hero_id] = mini(current_aff + 1, FactionData.AFFECTION_MAX)
				EventBus.hero_affection_changed.emit(hero_id, HeroSystem.hero_affection[hero_id])


func _get_terrain_atk_modifier(terrain: String) -> float:
	match terrain:
		"plains": return 1.0
		"forest": return 0.85
		"mountain": return 0.75
		"swamp": return 0.80
		"coastal": return 1.0
		"wall": return 0.70
	return 1.0


func _get_terrain_def_modifier(terrain: String) -> float:
	match terrain:
		"plains": return 1.0
		"forest": return 1.25
		"mountain": return 1.40
		"swamp": return 0.90
		"coastal": return 1.0
		"wall": return 1.50
	return 1.0


func _find_owned_path(from: int, to: int, player_id: int, max_hops: int) -> Array:
	## BFS to find a path through owned tiles within max_hops.
	var parent_map: Dictionary = {from: -1}
	var depth_map: Dictionary = {from: 0}
	var queue: Array = [from]
	while queue.size() > 0:
		var current: int = queue.pop_front()
		var depth: int = depth_map[current]
		if current == to:
			break
		if depth >= max_hops:
			continue
		if not adjacency.has(current):
			continue
		for neighbor in adjacency[current]:
			if parent_map.has(neighbor):
				continue
			# Intermediate tiles must be owned; final tile can be anything
			if neighbor != to and (neighbor >= tiles.size() or tiles[neighbor]["owner_id"] != player_id):
				continue
			parent_map[neighbor] = current
			depth_map[neighbor] = depth + 1
			queue.append(neighbor)
	if not parent_map.has(to):
		return []
	var path: Array = []
	var cur: int = to
	while cur != from:
		path.push_front(cur)
		cur = parent_map[cur]
	return path


func calculate_supply_line(_army_id: int) -> int:
	## DEPRECATED (v3.3): Supply lines simplified to territory-based check.
	## Always returns 0 (safe). Kept for backward compatibility (UI references).
	return 0


func _tick_supply_lines(player_id: int) -> void:
	## Simplified supply: armies on unowned tiles take attrition.
	## Overextension: too many soldiers relative to territory causes strain.
	var player_armies: Array = get_player_armies(player_id)
	if player_armies.is_empty():
		return

	# Check overextension (global check)
	var total_soldiers: int = ResourceManager.get_army(player_id)
	var owned_tiles: int = count_tiles_owned(player_id)
	var supply_cap: int = owned_tiles * BalanceConfig.SUPPLY_OVEREXTENSION_THRESHOLD
	var overextended: bool = total_soldiers > supply_cap

	if overextended:
		var surplus_pct: float = float(total_soldiers - supply_cap) / float(maxi(total_soldiers, 1))
		var attrition_pct: float = BalanceConfig.SUPPLY_OVEREXTENSION_ATTRITION * surplus_pct * 10.0
		attrition_pct = minf(attrition_pct, 0.05)  # Cap at 5%
		# Apply to all troops
		for army in player_armies:
			for troop in army.get("troops", []):
				var loss: int = maxi(0, int(float(troop["soldiers"]) * attrition_pct))
				if loss > 0:
					troop["soldiers"] = maxi(1, troop["soldiers"] - loss)
		if attrition_pct > 0.005:
			EventBus.message_log.emit("[color=orange]兵力过度扩张! (%d兵/%d地块上限) 每回合损耗%.1f%%[/color]" % [total_soldiers, supply_cap, attrition_pct * 100.0])
		for army in player_armies:
			_cleanup_army_troops(army)

	# Per-army: check if on enemy territory
	for army in player_armies:
		var tile_idx: int = army.get("tile_index", -1)
		if tile_idx < 0 or tile_idx >= tiles.size():
			continue
		if tiles[tile_idx]["owner_id"] != player_id and tiles[tile_idx]["owner_id"] >= 0:
			# In enemy territory — flat attrition
			for troop in army.get("troops", []):
				var loss: int = maxi(1, int(float(troop["soldiers"]) * BalanceConfig.SUPPLY_ENEMY_TERRITORY_ATTRITION))
				troop["soldiers"] = maxi(1, troop["soldiers"] - loss)
			EventBus.message_log.emit("[color=orange]%s 在敌方领土! 补给困难,损失%.0f%%兵力[/color]" % [army.get("name", "军团"), BalanceConfig.SUPPLY_ENEMY_TERRITORY_ATTRITION * 100.0])
			_cleanup_army_troops(army)


func _tick_terrain_attrition(player_id: int) -> void:
	var player_armies: Array = get_player_armies(player_id)
	for army in player_armies:
		if army.is_empty():
			continue
		var tile_idx: int = army.get("tile_index", -1)
		if tile_idx < 0 or tile_idx >= tiles.size():
			continue
		var terrain_type: int = tiles[tile_idx].get("terrain", FactionData.TerrainType.PLAINS)
		var tdata: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
		var attrition: float = tdata.get("attrition_pct", 0.0)
		if attrition <= 0.0:
			continue
		var tname: String = tdata.get("name", "未知")
		for troop in army.get("troops", []):
			var soldiers: int = troop.get("soldiers", 0)
			if soldiers <= 0:
				continue
			var loss: int = maxi(1, int(float(soldiers) * attrition))
			troop["soldiers"] = maxi(1, soldiers - loss)
			# Update HP if it exists
			var hpp: int = troop.get("hp_per_soldier", 5)
			troop["total_hp"] = troop["soldiers"] * hpp
		EventBus.message_log.emit("[color=orange]军队在%s中损失兵力 (%.0f%%减员/回合)[/color]" % [tname, attrition * 100.0])


func select_army(army_id: int) -> void:
	## Select an army for the current player's actions.
	if not armies.has(army_id):
		selected_army_id = -1
		return
	selected_army_id = army_id
	var army: Dictionary = armies[army_id]
	EventBus.territory_selected.emit(army["tile_index"])


func deselect_army() -> void:
	selected_army_id = -1
	EventBus.territory_deselected.emit()


# ═══════════════ MOVEMENT ═══════════════

# Legacy action (pre-v0.8)
func roll_dice() -> void:
	if not game_active or has_rolled:
		return
	var player: Dictionary = players[current_player_index]
	if player["is_ai"] or player["ap"] < 1:
		return

	dice_value = randi_range(1, 6)
	var bonus_moves: int = BuffManager.get_dice_bonus(player["id"])
	if bonus_moves > 0:
		dice_value += bonus_moves

	has_rolled = true
	player["ap"] -= 1
	EventBus.dice_rolled.emit(player["id"], dice_value)
	EventBus.message_log.emit("%s 掷出了 %d" % [player["name"], dice_value])

	reachable_tiles = compute_reachable(player["position"], dice_value)
	waiting_for_move = true
	EventBus.reachable_computed.emit(reachable_tiles)


func compute_reachable(from: int, max_steps: int) -> Array:
	var visited: Dictionary = {from: 0}
	var queue: Array = [from]
	var result: Array = []
	while queue.size() > 0:
		var current: int = queue.pop_front()
		var depth: int = visited[current]
		if depth >= max_steps:
			continue
		if not adjacency.has(current):
			continue
		for neighbor in adjacency[current]:
			if neighbor < 0 or neighbor >= tiles.size():
				continue
			if not visited.has(neighbor):
				visited[neighbor] = depth + 1
				queue.append(neighbor)
				result.append(neighbor)
	return result


# Legacy action (pre-v0.8)
func select_move_target(target_index: int) -> void:
	if not waiting_for_move or not game_active:
		return
	if not reachable_tiles.has(target_index):
		return

	var player: Dictionary = players[current_player_index]
	waiting_for_move = false
	reachable_tiles.clear()

	var path: Array = _find_path(player["position"], target_index)
	if path.is_empty():
		return

	for tile_idx in path:
		_reveal_around(tile_idx, player["id"])

	player["position"] = target_index
	EventBus.player_moving.emit(player["id"], path)
	EventBus.message_log.emit("%s 移动到 %s" % [player["name"], tiles[target_index]["name"]])

	await get_tree().create_timer(0.6).timeout
	if not game_active:
		return
	_resolve_arrival(player, tiles[target_index])


func _find_path(from: int, to: int) -> Array:
	var parent_map: Dictionary = {from: -1}
	var queue: Array = [from]
	while queue.size() > 0:
		var current: int = queue.pop_front()
		if current == to:
			break
		if not adjacency.has(current):
			continue
		for neighbor in adjacency[current]:
			if neighbor < 0 or neighbor >= tiles.size():
				continue
			if not parent_map.has(neighbor):
				parent_map[neighbor] = current
				queue.append(neighbor)
	if not parent_map.has(to):
		return []
	var path: Array = []
	var cur: int = to
	while cur != from:
		path.push_front(cur)
		cur = parent_map[cur]
	return path


func calculate_attack_route(from: int, to: int) -> Array:
	## A* weighted pathfinding using terrain move costs.
	## Returns array of tile indices from start to goal (excluding start).
	if from < 0 or to < 0 or from >= tiles.size() or to >= tiles.size():
		return []
	if from == to:
		return []
	# Open set: Array of [tile_index, f_score]
	var open_set: Array = [[from, 0.0]]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {from: 0.0}
	var closed: Dictionary = {}
	while open_set.size() > 0:
		# Find lowest f_score (linear scan — fine for 55-tile maps)
		var best_idx: int = 0
		for i in range(1, open_set.size()):
			if open_set[i][1] < open_set[best_idx][1]:
				best_idx = i
		var current: int = open_set[best_idx][0]
		open_set.remove_at(best_idx)
		if current == to:
			break
		if closed.has(current):
			continue
		closed[current] = true
		if not adjacency.has(current):
			continue
		for neighbor in adjacency[current]:
			if neighbor < 0 or neighbor >= tiles.size():
				continue
			if closed.has(neighbor):
				continue
			var n_tile: Dictionary = tiles[neighbor]
			var terrain_type: int = n_tile.get("terrain", FactionData.TerrainType.PLAINS)
			var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
			var move_cost: float = float(terrain_data.get("move_cost", 1))
			# Chokepoints add extra cost for route planning
			if n_tile.get("is_chokepoint", false):
				move_cost += 1.0
			var tentative_g: float = g_score[current] + move_cost
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				var h: float = _heuristic_cost(neighbor, to)
				open_set.append([neighbor, tentative_g + h])
	# Reconstruct path
	if not came_from.has(to):
		return []
	var path: Array = []
	var cur: int = to
	while came_from.has(cur):
		path.push_front(cur)
		cur = came_from[cur]
	return path

func _heuristic_cost(from: int, to: int) -> float:
	## Euclidean distance heuristic for A*.
	if from < 0 or from >= tiles.size() or to < 0 or to >= tiles.size():
		return 0.0
	var fp: Vector3 = tiles[from]["position_3d"]
	var tp: Vector3 = tiles[to]["position_3d"]
	return Vector3(fp.x - tp.x, 0, fp.z - tp.z).length() * 0.5

func get_route_to_target(army_id: int, target_tile: int) -> Array:
	## Convenience: get attack route from army's current tile to target.
	var army: Dictionary = get_army(army_id)
	if army.is_empty():
		return []
	return calculate_attack_route(army["tile_index"], target_tile)

func get_chokepoints_between(from: int, to: int) -> Array:
	## Returns chokepoint tiles along the optimal route.
	var route: Array = calculate_attack_route(from, to)
	var cps: Array = []
	for idx in route:
		if tiles[idx].get("is_chokepoint", false):
			cps.append(idx)
	return cps

func get_all_chokepoint_tiles() -> Array:
	## Returns indices of all chokepoint tiles on the map.
	var result: Array = []
	for tile in tiles:
		if tile.get("is_chokepoint", false):
			result.append(tile["index"])
	return result

func get_chokepoint_strategic_value(tile_idx: int) -> float:
	## Score how strategically important a chokepoint is.
	if tile_idx < 0 or tile_idx >= tiles.size():
		return 0.0
	var tile: Dictionary = tiles[tile_idx]
	if not tile.get("is_chokepoint", false):
		return 0.0
	var score: float = 0.0
	# Low degree = more bottleneck-like
	var degree: int = adjacency.get(tile_idx, []).size()
	score += (4.0 - clampf(float(degree), 1.0, 4.0)) * 3.0
	# Defensive terrain bonus
	var terrain_type: int = tile.get("terrain", FactionData.TerrainType.PLAINS)
	var terrain_data: Dictionary = FactionData.TERRAIN_DATA.get(terrain_type, {})
	score += terrain_data.get("def_mult", 1.0) * 2.0
	# Faction separation: borders between different owners are more valuable
	var owner_ids: Array = []
	for nb in adjacency.get(tile_idx, []):
		var noid: int = tiles[nb].get("owner_id", -1)
		if noid not in owner_ids:
			owner_ids.append(noid)
	if owner_ids.size() >= 2:
		score += 3.0  # Contested border
	# Garrison strength
	score += float(tile.get("garrison", 0)) * 0.1
	return score


# ═══════════════ ARRIVAL RESOLUTION ═══════════════

func _resolve_arrival(player: Dictionary, tile: Dictionary) -> void:
	var tile_type: int = tile["type"]
	var tile_idx: int = tile["index"]

	# ── Wanderer encounter ──
	var wanderer_troops: Array = RecruitManager.get_wanderer(tile_idx)
	if not wanderer_troops.is_empty():
		EventBus.message_log.emit("[color=orange]遭遇流浪军![/color]")
		var won: bool = _resolve_combat_vs_npc(player, tile, RecruitManager.get_wanderer_combat_units(tile_idx), "流浪军")
		if won:
			RecruitManager.clear_wanderer(tile_idx)
			EventBus.message_log.emit("击败流浪军!")
		else:
			EventBus.message_log.emit("被流浪军击退!")
			EventBus.player_arrived.emit(player["id"], tile_idx)
			check_win_condition()
			return  # Cannot proceed to tile after losing

	# ── Rebel encounter ──
	var rebel_troops: Array = RecruitManager.get_rebel(tile_idx)
	if not rebel_troops.is_empty():
		EventBus.message_log.emit("[color=red]遭遇叛军![/color]")
		var won: bool = _resolve_combat_vs_npc(player, tile, RecruitManager.get_rebel_combat_units(tile_idx), "叛军")
		if won:
			RecruitManager.clear_rebel(tile_idx)
			EventBus.message_log.emit("镇压叛军成功!")
		else:
			EventBus.message_log.emit("叛军击退了你的部队!")
			EventBus.player_arrived.emit(player["id"], tile_idx)
			check_win_condition()
			return

	match tile_type:
		TileType.LIGHT_STRONGHOLD:
			if tile["owner_id"] != player["id"]:
				_handle_stronghold(player, tile)
			else:
				EventBus.message_log.emit("这是你的要塞，可在此招募军队")
		TileType.LIGHT_VILLAGE:
			if tile["owner_id"] != player["id"]:
				_handle_village(player, tile)
		TileType.DARK_BASE:
			if tile["owner_id"] != player["id"] and tile["owner_id"] >= 0:
				_handle_rival_base(player, tile)
			elif tile["owner_id"] < 0:
				_capture_tile(player, tile)
		TileType.MINE_TILE, TileType.FARM_TILE:
			if tile["owner_id"] != player["id"]:
				if tile["garrison"] > 0:
					var won: bool = _resolve_combat(player, tile, "守军")
					if won:
						_capture_tile(player, tile)
				else:
					_capture_tile(player, tile)
		TileType.WILDERNESS:
			if tile["owner_id"] < 0:
				_capture_tile(player, tile)
			if randf() < 0.2:
				_trigger_event(player, tile)
		TileType.EVENT_TILE:
			_trigger_event(player, tile)
			if tile["owner_id"] < 0:
				_capture_tile(player, tile)
		TileType.RESOURCE_STATION:
			if tile["owner_id"] != player["id"]:
				if tile["garrison"] > 0:
					var won: bool = _resolve_combat(player, tile, "资源站守军")
					if won:
						_capture_tile(player, tile)
						var stype: String = tile.get("resource_station_type", "")
						if stype != "":
							EventBus.message_log.emit("占领资源站! 每回合获得 %s" % stype)
				else:
					_capture_tile(player, tile)
		TileType.CORE_FORTRESS:
			if tile["owner_id"] != player["id"]:
				_handle_stronghold(player, tile)
		TileType.NEUTRAL_BASE:
			var nf_id: int = tile.get("neutral_faction_id", -1)
			if tile["owner_id"] != player["id"]:
				if tile["garrison"] > 0:
					var won: bool = _resolve_combat(player, tile, "中立势力守军")
					if won:
						_capture_tile(player, tile)
						if nf_id >= 0:
							_handle_neutral_quest(player, nf_id)
				else:
					_capture_tile(player, tile)
					if nf_id >= 0:
						_handle_neutral_quest(player, nf_id)
			else:
				# Already own this tile - check quest progress
				if nf_id >= 0:
					_handle_neutral_quest(player, nf_id)

	EventBus.player_arrived.emit(player["id"], tile["index"])
	check_win_condition()


func _handle_neutral_quest(player: Dictionary, neutral_faction_id: int) -> void:
	var pid: int = player["id"]
	var ftag: String = QuestManager._resolve_faction_tag(neutral_faction_id)
	var step: int = QuestManager.get_quest_step(pid, neutral_faction_id)
	var fname: String = QuestManager._get_faction_name(ftag)

	if step == 0:
		# Start the quest chain
		QuestManager.start_quest(pid, neutral_faction_id)
		return

	# Check if current step can advance
	var check: Dictionary = QuestManager.check_quest_triggers(pid, neutral_faction_id)
	if not check.get("can_advance", false):
		EventBus.message_log.emit("%s 任务条件未满足: %s" % [fname, check.get("missing", "")])
		return

	# Handle combat triggers — initiate quest combat instead of auto-advancing
	if check.get("requires_combat", false):
		var enemy_strength: int = check.get("enemy_strength", 5)
		QuestManager.set_pending_combat(pid, neutral_faction_id, enemy_strength)
		EventBus.quest_combat_requested.emit(pid, neutral_faction_id, enemy_strength)
		EventBus.message_log.emit("%s 任务战斗! 敌兵力: %d" % [fname, enemy_strength])
		return

	# Deduct costs and apply rewards (delegated to quest_manager)
	QuestManager.deduct_step_costs(pid, neutral_faction_id)
	QuestManager.apply_step_rewards(pid, neutral_faction_id)

	# Advance the quest (this also adds taming +3)
	QuestManager.advance_quest(pid, neutral_faction_id)

	# Check if quest is now complete
	var new_step: int = QuestManager.get_quest_step(pid, neutral_faction_id)
	if new_step >= 3:
		QuestManager.complete_quest(pid, neutral_faction_id)
		# Vassalize the neutral faction — their territory stays independent but production goes to player
		NeutralFactionAI.vassalize(pid, neutral_faction_id)


func _handle_village(player: Dictionary, tile: Dictionary) -> void:
	if tile["owner_id"] >= 0 and tile["owner_id"] != player["id"]:
		var won: bool = _resolve_combat(player, tile, "村庄守军")
		if won:
			_capture_tile(player, tile)
	else:
		var gold_gain: int = randi_range(30, 80)
		var faction_id: int = get_player_faction(player["id"])
		if faction_id == FactionData.FactionID.PIRATE:
			gold_gain = int(float(gold_gain) * PirateMechanic.get_loot_multiplier(player["id"]))
		ResourceManager.apply_delta(player["id"], {"gold": gold_gain})
		EventBus.message_log.emit("%s 劫掠村庄，获得 %d 金币" % [player["name"], gold_gain])
		_capture_tile(player, tile)


func _handle_stronghold(player: Dictionary, tile: Dictionary) -> void:
	var defender_name: String
	if tile["owner_id"] >= 0:
		var _p = get_player_by_id(tile["owner_id"])
		defender_name = (_p.get("name", "敌军") if _p else "敌军") + "的要塞守军"
	else:
		defender_name = "光明联盟要塞守军"

	# Apply threat garrison bonus temporarily for combat calculation
	var bonus: float = ThreatManager.get_garrison_bonus()
	var original_garrison: int = tile["garrison"]
	if bonus > 0.0:
		tile["garrison"] = int(float(original_garrison) * (1.0 + bonus))

	var won: bool = _resolve_combat(player, tile, defender_name)

	# Restore original garrison so the bonus doesn't stack permanently
	tile["garrison"] = original_garrison

	if won:
		_capture_tile(player, tile)
		var faction_id: int = get_player_faction(player["id"])
		FactionManager.on_stronghold_captured(player["id"], faction_id)
		EventBus.message_log.emit("要塞被攻占!")


func _handle_rival_base(player: Dictionary, tile: Dictionary) -> void:
	var rival_id: int = tile["owner_id"]
	var rival: Dictionary = get_player_by_id(tile["owner_id"])
	var won: bool = _resolve_combat(player, tile, rival.get("name", "敌军") + "据点")
	if won:
		_capture_tile(player, tile)
		# Check if rival faction is eliminated
		if rival_id >= 0:
			var rival_has_tiles: bool = false
			for t in tiles:
				if t["owner_id"] == rival_id:
					rival_has_tiles = true
					break
			if not rival_has_tiles:
				var rival_fid: int = get_player_faction(rival_id)
				FactionManager.mark_faction_dead(rival_fid, player["id"])
				EventBus.faction_destroyed.emit(rival_id, player["id"])


# ═══════════════ COMMANDER TACTICAL ORDERS ═══════════════

func get_player_tactical_orders() -> Dictionary:
	## Returns current tactical orders set by the player.
	## These are stored in session variables and set via UI before combat.
	return {
		"tactical_directive": _current_directive,
		"skill_timing": _current_skill_timing.duplicate(),
		"protected_slot": _current_protected_slot,
		"decoy_slot": _current_decoy_slot,
	}


func set_tactical_directive(directive: int) -> void:
	_current_directive = directive


func set_skill_timing(hero_id: String, round_num: int) -> void:
	## Set when a hero's active skill should fire.
	## round_num: 0=auto, 1=round 1, 4=round 4, 8=round 8
	if round_num <= 0:
		_current_skill_timing.erase(hero_id)
	else:
		_current_skill_timing[hero_id] = round_num


func set_protected_slot(slot: int) -> void:
	_current_protected_slot = slot


func set_decoy_slot(slot: int) -> void:
	_current_decoy_slot = slot


func clear_tactical_orders() -> void:
	## Reset all tactical orders to defaults.
	_current_directive = 0
	_current_skill_timing.clear()
	_current_protected_slot = -1
	_current_decoy_slot = -1


# ═══════════════ COMBAT ═══════════════

func _resolve_combat(player: Dictionary, tile: Dictionary, defender_desc: String) -> bool:
	var pid: int = player["id"]
	var faction_id: int = get_player_faction(pid)
	var army: int = ResourceManager.get_army(pid)

	# Auto-save before combat
	var def_player_id_check: int = tile.get("owner_id", -1)
	if pid == get_human_player_id() or def_player_id_check == get_human_player_id():
		var _settings_node = get_tree().get_root().find_child("SettingsPanel", true, false)
		var _auto_save_on: bool = true
		if _settings_node and _settings_node.has_method("get_setting"):
			_auto_save_on = _settings_node.get_setting("auto_save") != false
		if _auto_save_on:
			SaveManager.auto_save()

	# Neutral territory reinforcement: adjacent neutral tiles send aid before battle
	var nf_id: int = tile.get("neutral_faction_id", -1)
	if nf_id >= 0 and tile["owner_id"] < 0:
		NeutralFactionAI.reinforce_on_attack(tile["index"])

	# Build attacker data for CombatResolver
	var atk_units: Array = RecruitManager.get_combat_units(pid)
	if atk_units.is_empty():
		# Fallback: generic infantry if no specific composition
		atk_units = [{"type": _get_faction_tag_for_player(pid) + "_ashigaru" if _get_faction_tag_for_player(pid) != "" else "orc_ashigaru", "atk": COMBAT_POWER_PER_UNIT + player.get("atk_bonus", 0), "def": 5, "spd": 4, "count": army, "special": ""}]
	var attacker_data: Dictionary = {
		"player_id": pid,
		"faction_id": faction_id,
		"units": atk_units,
	}

	# Pass slot preferences for the CombatResolver path
	if not _combat_slot_prefs.is_empty() and pid == get_human_player_id():
		attacker_data["slot_preferences"] = _combat_slot_prefs
		_combat_slot_prefs = {}

	# Territory effect combat bonuses
	var te_atk: int = _active_territory_effects.get("atk_bonus", 0)
	var te_def: int = _active_territory_effects.get("def_bonus", 0)
	var te_spd: int = _active_territory_effects.get("spd_bonus", 0)
	if te_atk > 0 or te_def > 0 or te_spd > 0:
		attacker_data["territory_atk_bonus"] = te_atk
		attacker_data["territory_def_bonus"] = te_def
		attacker_data["territory_spd_bonus"] = te_spd

	# Inject Commander Tactical Orders for human player
	if pid == get_human_player_id():
		var orders: Dictionary = get_player_tactical_orders()
		attacker_data.merge(orders)

	# Build defender data
	var def_player_id: int = tile.get("owner_id", -1)
	var def_units: Array = []
	# Try composed garrison first (Phase 3 troop system)
	var garrison_units: Array = RecruitManager.get_garrison_combat_units(tile["index"])
	if not garrison_units.is_empty():
		def_units = garrison_units
	elif tile["garrison"] > 0:
		def_units.append({"type": "human_ashigaru", "atk": 4, "def": 6, "spd": 4, "count": tile["garrison"], "special": "fort_def_3"})
	if def_player_id >= 0 and def_player_id != pid:
		var defender_player: Dictionary = get_player_by_id(def_player_id)
		var def_army: int = int(float(defender_player.get("army_count", 0)) * BalanceConfig.DEFENDER_ARMY_CONTRIBUTION)
		if def_army > 0:
			def_units.append({"type": "human_ashigaru", "atk": COMBAT_POWER_PER_UNIT, "def": 5, "spd": 4, "count": def_army, "special": ""})

	var defender_data: Dictionary = {
		"player_id": def_player_id,
		"faction_id": get_player_faction(def_player_id) if def_player_id >= 0 else -1,
		"units": def_units,
	}

	# SR07: Garrison commander DEF bonus (legacy combat path)
	var _cmd_bonus2: Dictionary = HeroSystem.get_garrison_commander_bonus(tile.get("index", -1)) if HeroSystem != null else {}
	if _cmd_bonus2.get("def_mult", 1.0) > 1.0:
		for du in def_units:
			if du.has("def"):
				du["def"] = int(ceil(float(du.get("def", 5)) * _cmd_bonus2["def_mult"]))
		if _cmd_bonus2.get("garrison_add", 0) > 0 and not def_units.is_empty():
			def_units[0]["count"] = def_units[0].get("count", 0) + _cmd_bonus2["garrison_add"]
		EventBus.message_log.emit("[color=cyan]驻防武将%s增援! DEF+25%%, 守军+%d[/color]" % [_cmd_bonus2.get("hero_name", ""), _cmd_bonus2.get("garrison_add", 0)])

	EventBus.combat_started.emit(pid, tile["index"])
	_had_combat_this_turn = true

	var result: Dictionary = CombatResolver.resolve_combat(attacker_data, defender_data, tile)
	var attacker_wins: bool = result.get("winner", "defender") == "attacker"
	var attacker_losses: int = result.get("attacker_losses", 1)
	var defender_losses: int = result.get("defender_losses", 0)
	var slaves_captured: int = result.get("slaves_captured", 0)

	# Grant experience to surviving troops (dynamic based on enemy composition)
	var atk_exp: int = result.get("attacker_exp", BalanceConfig.COMBAT_XP_WIN if attacker_wins else BalanceConfig.COMBAT_XP_LOSS)
	CombatAbilities.grant_combat_experience(pid, atk_exp)

	# ── 英雄经验 (v3.1) ──
	_grant_hero_combat_exp(pid, result, attacker_wins)

	# ── Hidden Heroes: record battle victory and check conditions ──
	if attacker_wins and pid == get_human_player_id() and HeroSystem != null:
		HeroSystem.record_battle_victory()
		HeroSystem.check_hidden_hero_conditions(pid)

	# 防守方英雄也获得経験：胜利获得全额，失败获得50%（从战斗中学习）
	if def_player_id >= 0 and def_player_id != pid:
		var defender_wins: bool = not attacker_wins
		_grant_hero_combat_exp(def_player_id, result, defender_wins)

	# Dissolve slave_fodder troops (Dark Elf T0 consumable)
	if result.get("slave_fodder_dissolved", 0) > 0:
		CombatAbilities.dissolve_slave_fodder(pid)

	# Zero_food victory recovery (skeleton +2 soldiers on win)
	if attacker_wins and result.get("zero_food_recovery", 0) > 0:
		CombatAbilities.apply_zero_food_recovery(pid)

	# Necromancer taming synergy: resurrect 20% of fallen as skeletons
	var necro_res: int = result.get("necro_resurrect", 0)
	if necro_res > 0 and attacker_wins:
		var skel_inst: Dictionary = GameData.create_troop_instance("neutral_skeleton", necro_res)
		if not skel_inst.is_empty():
			RecruitManager.reinforce_army(pid, [skel_inst])
			EventBus.message_log.emit("亡灵复活: +%d骷髅兵" % necro_res)

	# Log combat details
	for detail in result.get("details", []):
		EventBus.message_log.emit("  %s" % detail)

	if attacker_wins:
		ResourceManager.remove_army(pid, maxi(attacker_losses, 1))
		sync_player_army(pid)
		tile["garrison"] = maxi(0, tile["garrison"] - defender_losses)
		if slaves_captured > 0:
			ResourceManager.apply_delta(pid, {"slaves": slaves_captured})
			SlaveManager.sync_slave_count(pid)
			EventBus.message_log.emit("俘获 %d 名奴隶!" % slaves_captured)
			# Orc: convert captured slaves to sex slaves for breeding
			if _get_faction_tag_for_player(pid) == "orc":
				OrcMechanic.on_battle_capture_slaves(pid, slaves_captured)
			# Dark Elf auto-conversion: queue captured slaves for troop conversion
			elif _get_faction_tag_for_player(pid) == "dark_elf":
				var fp: Dictionary = GameData.get_faction_passive("dark_elf")
				var conv_turns: int = fp.get("slave_conversion_turns", 3)
				SlaveManager.queue_conversion(pid, slaves_captured, conv_turns)
		EventBus.message_log.emit("%s 战胜了 %s!" % [player["name"], defender_desc])
		FactionManager.on_combat_win(pid, faction_id)
		ThreatManager.on_army_destroyed()
		# WAAAGH! gain: per-unit + per-kill (doc §3.1)
		if _get_faction_tag_for_player(pid) == "orc":
			var orc_count: int = atk_units.size()
			var enemy_destroyed: int = maxi(1, int(ceil(float(defender_losses) / maxf(float(def_units.size()), 1.0))))
			OrcMechanic.on_combat_result(pid, orc_count, enemy_destroyed)
		# Pirate: plunder gold + sex slave capture + treasure map check
		elif _get_faction_tag_for_player(pid) == "pirate":
			var enemy_strength: int = 0
			for du in def_units:
				enemy_strength += du.get("count", 0)
			PirateMechanic.on_combat_win_plunder(pid, maxi(enemy_strength, 1))
			PirateMechanic.on_combat_win_treasure_check(pid)
			if slaves_captured > 0:
				PirateMechanic.add_sex_slaves(pid, slaves_captured)
		# ── 战斗战利品掉落 (v3.5) ──
		if pid == get_human_player_id():
			ItemManager.grant_random_loot(pid)
			# Enhanced Rance 07-style battle drops
			var drop_roll: float = randf()
			var drop_chance: float = 0.15  # 15% base
			# Higher chance vs strongholds/fortresses
			if tile["type"] == TileType.LIGHT_STRONGHOLD or tile["type"] == TileType.CORE_FORTRESS:
				drop_chance += 0.15
			# Higher chance if we have more soldiers killed (tougher fight = better loot)
			if defender_losses > 10:
				drop_chance += 0.10
			if drop_roll < drop_chance:
				var rare_roll: float = randf()
				var loot_msg: String = ""
				if rare_roll < 0.10:
					# Rare drop: equipment for heroes
					var rare_items: Array = ["shadow_blade", "iron_shield", "war_banner", "healing_scroll", "siege_ram"]
					var item_id: String = rare_items[randi() % rare_items.size()]
					ItemManager.add_item(pid, item_id)
					loot_msg = "[color=purple]稀有战利品: %s[/color]" % item_id
				elif rare_roll < 0.40:
					# Uncommon: strategic resources
					var res_types: Array = ["magic_crystal", "war_horse", "gunpowder", "shadow_essence"]
					var res_type: String = res_types[randi() % res_types.size()]
					var res_amt: int = randi_range(1, 3)
					ResourceManager.apply_delta(pid, {res_type: res_amt})
					loot_msg = "[color=blue]战利品: %s ×%d[/color]" % [res_type, res_amt]
				else:
					# Common: bonus gold/iron
					var bonus_gold: int = randi_range(10, 30)
					var bonus_iron: int = randi_range(3, 10)
					ResourceManager.apply_delta(pid, {"gold": bonus_gold, "iron": bonus_iron})
					loot_msg = "战利品: 金+%d, 铁+%d" % [bonus_gold, bonus_iron]
				EventBus.message_log.emit(loot_msg)
		EventBus.combat_result.emit(pid, defender_desc, true)
		_record_battle_stat(pid, true)
		return true
	else:
		ResourceManager.remove_army(pid, maxi(attacker_losses, 1))
		# Apply retreat/defeat losses to actual troop soldiers
		RecruitManager.apply_combat_losses(pid, maxi(attacker_losses, 1))
		sync_player_army(pid)
		EventBus.message_log.emit("%s 攻打 %s 失败! 损失 %d 步兵" % [player["name"], defender_desc, attacker_losses])
		_check_elimination(player)
		EventBus.combat_result.emit(pid, defender_desc, false)
		_record_battle_stat(pid, false)
		return false


## Combat against NPC units (wanderers, rebels) using pre-built combat unit arrays.
func _resolve_combat_vs_npc(player: Dictionary, tile: Dictionary, npc_units: Array, npc_desc: String) -> bool:
	var pid: int = player["id"]
	var faction_id: int = get_player_faction(pid)

	var atk_units: Array = RecruitManager.get_combat_units(pid)
	if atk_units.is_empty():
		var army: int = ResourceManager.get_army(pid)
		atk_units = [{"type": "orc_ashigaru", "atk": COMBAT_POWER_PER_UNIT + player.get("atk_bonus", 0), "def": 5, "spd": 4, "count": army, "special": ""}]

	var attacker_data: Dictionary = {
		"player_id": pid,
		"faction_id": faction_id,
		"units": atk_units,
	}

	# Inject Commander Tactical Orders for human player
	if pid == get_human_player_id():
		var orders: Dictionary = get_player_tactical_orders()
		attacker_data.merge(orders)

	var defender_data: Dictionary = {
		"player_id": -1,
		"faction_id": -1,
		"units": npc_units,
	}

	EventBus.combat_started.emit(pid, tile["index"])
	_had_combat_this_turn = true

	var result: Dictionary = CombatResolver.resolve_combat(attacker_data, defender_data, tile)
	var attacker_wins: bool = result.get("winner", "defender") == "attacker"
	var attacker_losses: int = result.get("attacker_losses", 1)
	var slaves_captured: int = result.get("slaves_captured", 0)

	# Grant experience
	var atk_exp: int = result.get("attacker_exp", BalanceConfig.COMBAT_XP_WIN if attacker_wins else BalanceConfig.COMBAT_XP_LOSS)
	CombatAbilities.grant_combat_experience(pid, atk_exp)

	# ── 英雄经验 (v3.1) ──
	_grant_hero_combat_exp(pid, result, attacker_wins)

	# ── Hidden Heroes: record battle victory and check conditions ──
	if attacker_wins and pid == get_human_player_id() and HeroSystem != null:
		HeroSystem.record_battle_victory()
		HeroSystem.check_hidden_hero_conditions(pid)

	# Dissolve slave_fodder
	if result.get("slave_fodder_dissolved", 0) > 0:
		CombatAbilities.dissolve_slave_fodder(pid)

	# Zero_food recovery
	if attacker_wins and result.get("zero_food_recovery", 0) > 0:
		CombatAbilities.apply_zero_food_recovery(pid)

	# Necro resurrect
	var necro_res: int = result.get("necro_resurrect", 0)
	if necro_res > 0 and attacker_wins:
		var skel_inst: Dictionary = GameData.create_troop_instance("neutral_skeleton", necro_res)
		if not skel_inst.is_empty():
			RecruitManager.reinforce_army(pid, [skel_inst])
			EventBus.message_log.emit("亡灵复活: +%d骷髅兵" % necro_res)

	for detail in result.get("details", []):
		EventBus.message_log.emit("  %s" % detail)

	if attacker_wins:
		ResourceManager.remove_army(pid, maxi(attacker_losses, 1))
		sync_player_army(pid)
		if slaves_captured > 0:
			ResourceManager.apply_delta(pid, {"slaves": slaves_captured})
			SlaveManager.sync_slave_count(pid)
			EventBus.message_log.emit("俘获 %d 名奴隶!" % slaves_captured)
			# Orc: convert captured slaves to sex slaves for breeding
			if _get_faction_tag_for_player(pid) == "orc":
				OrcMechanic.on_battle_capture_slaves(pid, slaves_captured)
			# Dark Elf auto-conversion: queue captured slaves for troop conversion
			elif _get_faction_tag_for_player(pid) == "dark_elf":
				var fp: Dictionary = GameData.get_faction_passive("dark_elf")
				var conv_turns: int = fp.get("slave_conversion_turns", 3)
				SlaveManager.queue_conversion(pid, slaves_captured, conv_turns)
		EventBus.message_log.emit("%s 击败了 %s!" % [player["name"], npc_desc])
		# WAAAGH! gain for NPC combat
		if _get_faction_tag_for_player(pid) == "orc":
			OrcMechanic.on_combat_result(pid, atk_units.size(), 1)
		# Pirate: plunder gold + sex slave capture + treasure map check
		elif _get_faction_tag_for_player(pid) == "pirate":
			var enemy_strength: int = 0
			for nu in npc_units:
				enemy_strength += nu.get("count", 0)
			PirateMechanic.on_combat_win_plunder(pid, maxi(enemy_strength, 1))
			PirateMechanic.on_combat_win_treasure_check(pid)
			if slaves_captured > 0:
				PirateMechanic.add_sex_slaves(pid, slaves_captured)
		# ── 战斗战利品掉落 (v3.5) ──
		if pid == get_human_player_id():
			ItemManager.grant_random_loot(pid)
		EventBus.combat_result.emit(pid, npc_desc, true)
		_record_battle_stat(pid, true)
		return true
	else:
		ResourceManager.remove_army(pid, maxi(attacker_losses, 1))
		# Apply retreat/defeat losses to actual troop soldiers
		RecruitManager.apply_combat_losses(pid, maxi(attacker_losses, 1))
		sync_player_army(pid)
		EventBus.message_log.emit("%s 败于 %s! 损失 %d 兵" % [player["name"], npc_desc, attacker_losses])
		_check_elimination(player)
		EventBus.combat_result.emit(pid, npc_desc, false)
		_record_battle_stat(pid, false)
		return false


# ═══════════════ EVENT COMBAT HANDLER (v5.1) ═══════════════

## Themed enemy templates for event combat.
## Maps enemy_type tag (from event effects) → unit composition generator.
## Each template returns an Array of unit dicts compatible with CombatResolver.
const EVENT_ENEMY_TEMPLATES: Dictionary = {
	# --- Humanoid enemies ---
	"rebels":    {"name": "叛军",     "comp": [{"type": "human_ashigaru", "atk": 5, "def": 4, "spd": 4, "pct": 0.6, "row": "front", "passive": "none"},
	                                            {"type": "human_archer",   "atk": 6, "def": 2, "spd": 5, "pct": 0.4, "row": "back",  "passive": "ranged_2"}]},
	"bandits":   {"name": "山贼",     "comp": [{"type": "bandit_fighter",  "atk": 6, "def": 3, "spd": 6, "pct": 0.5, "row": "front", "passive": "ambush"},
	                                            {"type": "bandit_archer",   "atk": 5, "def": 2, "spd": 7, "pct": 0.3, "row": "back",  "passive": "ranged_2"},
	                                            {"type": "bandit_boss",     "atk": 8, "def": 5, "spd": 5, "pct": 0.2, "row": "front", "passive": "taunt"}]},
	"elite_guard": {"name": "精锐亲卫", "comp": [{"type": "elite_samurai",  "atk": 8, "def": 7, "spd": 5, "pct": 0.5, "row": "front", "passive": "counter_25"},
	                                              {"type": "elite_cavalry",  "atk": 9, "def": 5, "spd": 8, "pct": 0.3, "row": "front", "passive": "charge_bonus"},
	                                              {"type": "elite_archer",   "atk": 7, "def": 4, "spd": 6, "pct": 0.2, "row": "back",  "passive": "ranged_2"}]},
	"assassins": {"name": "死士",     "comp": [{"type": "shadow_assassin", "atk": 9, "def": 2, "spd": 9, "pct": 0.6, "row": "front", "passive": "critical_25"},
	                                            {"type": "poison_blade",    "atk": 7, "def": 3, "spd": 8, "pct": 0.4, "row": "front", "passive": "poison_2"}]},
	"pirates":   {"name": "海盗叛军", "comp": [{"type": "pirate_ashigaru", "atk": 6, "def": 4, "spd": 6, "pct": 0.5, "row": "front", "passive": "none"},
	                                            {"type": "pirate_gunner",   "atk": 8, "def": 2, "spd": 4, "pct": 0.3, "row": "back",  "passive": "ranged_2"},
	                                            {"type": "pirate_captain",  "atk": 9, "def": 6, "spd": 5, "pct": 0.2, "row": "front", "passive": "command_bonus"}]},
	# --- Monster enemies ---
	"undead":    {"name": "亡灵",     "comp": [{"type": "skeleton_warrior", "atk": 5, "def": 6, "spd": 3, "pct": 0.5, "row": "front", "passive": "undead_resist"},
	                                            {"type": "zombie_horde",    "atk": 4, "def": 8, "spd": 2, "pct": 0.3, "row": "front", "passive": "taunt"},
	                                            {"type": "wraith",          "atk": 7, "def": 2, "spd": 7, "pct": 0.2, "row": "back",  "passive": "magic_attack"}]},
	"beasts":    {"name": "地穴兽",   "comp": [{"type": "cave_spider",     "atk": 6, "def": 3, "spd": 7, "pct": 0.5, "row": "front", "passive": "poison_2"},
	                                            {"type": "cave_broodmother","atk": 8, "def": 6, "spd": 4, "pct": 0.2, "row": "front", "passive": "taunt"},
	                                            {"type": "cave_lurker",     "atk": 5, "def": 2, "spd": 8, "pct": 0.3, "row": "back",  "passive": "ambush"}]},
	"demons":    {"name": "恶魔",     "comp": [{"type": "lesser_demon",    "atk": 7, "def": 5, "spd": 5, "pct": 0.4, "row": "front", "passive": "fire_attack"},
	                                            {"type": "demon_guard",     "atk": 6, "def": 8, "spd": 3, "pct": 0.3, "row": "front", "passive": "taunt"},
	                                            {"type": "warlock",         "atk": 9, "def": 2, "spd": 6, "pct": 0.3, "row": "back",  "passive": "magic_attack"}]},
	"elementals": {"name": "元素体", "comp": [{"type": "fire_elemental",   "atk": 8, "def": 4, "spd": 6, "pct": 0.5, "row": "front", "passive": "fire_attack"},
	                                           {"type": "ice_elemental",    "atk": 6, "def": 7, "spd": 4, "pct": 0.5, "row": "front", "passive": "frost_slow"}]},
	"constructs": {"name": "远古傀儡", "comp": [{"type": "stone_golem",    "atk": 7, "def": 10, "spd": 2, "pct": 0.4, "row": "front", "passive": "taunt"},
	                                             {"type": "iron_automaton", "atk": 9, "def": 7, "spd": 3, "pct": 0.3, "row": "front", "passive": "counter_25"},
	                                             {"type": "arcane_turret",  "atk": 10, "def": 3, "spd": 5, "pct": 0.3, "row": "back",  "passive": "ranged_2"}]},
	# --- Cultist enemies ---
	"cultists":  {"name": "邪教徒",   "comp": [{"type": "cultist_zealot",  "atk": 5, "def": 3, "spd": 5, "pct": 0.4, "row": "front", "passive": "frenzy"},
	                                            {"type": "cultist_priest",  "atk": 3, "def": 4, "spd": 4, "pct": 0.3, "row": "back",  "passive": "heal_2"},
	                                            {"type": "summoned_fiend",  "atk": 8, "def": 5, "spd": 6, "pct": 0.3, "row": "front", "passive": "fire_attack"}]},
}

## Build themed enemy units from a template and total soldier count.
func _build_event_enemy_units(enemy_type: String, total_soldiers: int) -> Array:
	var template: Dictionary = EVENT_ENEMY_TEMPLATES.get(enemy_type, {})
	if template.is_empty():
		# Fallback: generic infantry
		return [{"type": "human_ashigaru", "atk": 5, "def": 4, "spd": 4, "count": total_soldiers, "special": "none", "row": "front"}]

	var comp: Array = template["comp"]
	var units: Array = []
	var remaining: int = total_soldiers

	for i in range(comp.size()):
		var c: Dictionary = comp[i]
		var count: int
		if i == comp.size() - 1:
			count = remaining  # Last unit gets the rest
		else:
			count = maxi(1, int(total_soldiers * c["pct"]))
			remaining -= count

		if count <= 0:
			continue
		units.append({
			"type": c["type"],
			"atk": c["atk"],
			"def": c["def"],
			"spd": c["spd"],
			"count": count,
			"special": c.get("passive", "none"),
			"row": c.get("row", "front"),
			"int_stat": c.get("int_stat", 0),
		})
	return units

## Handle event combat signal — builds themed enemy army and runs combat.
func _on_event_combat_requested(player_id: int, enemy_soldiers: int, event_id: String) -> void:
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty():
		return

	# Parse explicit enemy_type from "event_id::enemy_type" format, or infer from event_id
	var actual_event_id: String = event_id
	var enemy_type: String = ""
	if "::" in event_id:
		var parts: PackedStringArray = event_id.split("::")
		actual_event_id = parts[0]
		enemy_type = parts[1]
	else:
		enemy_type = _infer_enemy_type_from_event(event_id)
	var enemy_desc: String = EVENT_ENEMY_TEMPLATES.get(enemy_type, {}).get("name", "敌军")
	var npc_units: Array = _build_event_enemy_units(enemy_type, enemy_soldiers)

	# Find a suitable tile for combat context (use player's current tile or a dummy)
	var pid: int = player_id
	var tile: Dictionary = {"index": -1, "terrain": FactionData.TerrainType.PLAINS, "garrison": 0, "owner_id": -1, "city_def": 0}
	# Try to use the player's current position tile for terrain effects
	for t in tiles:
		if t.get("owner_id", -1) == pid:
			tile = t
			break

	var won: bool = _resolve_combat_vs_npc(player, tile, npc_units, "事件: " + enemy_desc)

	# Apply event combat rewards/penalties based on outcome
	if won:
		EventBus.message_log.emit("[color=green]事件战斗胜利! 击败了%s (%d兵)[/color]" % [enemy_desc, enemy_soldiers])
	else:
		EventBus.message_log.emit("[color=red]事件战斗失败... %s击退了我们[/color]" % enemy_desc)

## Infer enemy type from event_id naming convention.
func _infer_enemy_type_from_event(event_id: String) -> String:
	# Chain events and standalone events use descriptive IDs
	if "tomb" in event_id or "undead" in event_id or "blood_moon" in event_id:
		return "undead"
	elif "mine" in event_id and "boom" in event_id:
		return "beasts"
	elif "mine" in event_id or "bandit" in event_id:
		return "bandits"
	elif "betrayal" in event_id or "guard" in event_id or "conspiracy" in event_id or "purge" in event_id:
		return "elite_guard"
	elif "assassin" in event_id:
		return "assassins"
	elif "ritual" in event_id or "dark" in event_id or "demon" in event_id:
		return "cultists"
	elif "pirate" in event_id or "mutiny" in event_id:
		return "pirates"
	elif "weapon" in event_id or "forging" in event_id or "guardian" in event_id:
		return "constructs"
	elif "mana" in event_id or "element" in event_id:
		return "elementals"
	elif "schism" in event_id or "underground" in event_id:
		return "rebels"
	elif "heir" in event_id or "noble" in event_id or "feud" in event_id:
		return "rebels"
	elif "princess" in event_id:
		return "elite_guard"
	elif "night_raid" in event_id or "border" in event_id:
		return "bandits"
	# Default fallback
	return "rebels"


func _capture_tile(player: Dictionary, tile: Dictionary) -> void:
	var old_owner: int = tile["owner_id"]
	if old_owner >= 0 and old_owner != player["id"]:
		EventBus.tile_lost.emit(old_owner, tile["index"])
		OrderManager.on_tile_lost()
	tile["owner_id"] = player["id"]
	@warning_ignore("integer_division")
	tile["garrison"] = maxi(BalanceConfig.CAPTURE_MIN_GARRISON, tile["garrison"] / 2)
	tile["public_order"] = BalanceConfig.TILE_ORDER_DEFAULT
	EventBus.tile_captured.emit(player["id"], tile["index"])
	_reveal_around(tile["index"], player["id"])
	OrderManager.on_tile_captured()
	ThreatManager.on_tile_captured()
	# Update nation system ownership (fixed map mode)
	if use_fixed_map and nation_system != null:
		nation_system.set_territory_owner(tile["index"], player["id"])
	# Notify neutral faction AI of territory loss
	NeutralFactionAI.on_tile_captured(tile["index"], player["id"])
	# Territory conquest events (領地征服事件)
	_check_conquest_events(player["id"], tile["index"])
	# Hidden Heroes check after tile capture (秘密英雄)
	if player["id"] == get_human_player_id() and HeroSystem != null:
		HeroSystem.check_hidden_hero_conditions(player["id"])
	# SAT (満足度) points on tile capture
	var _sat_gain: int = BalanceConfig.SAT_GAIN_NORMAL
	var _cap_tile_type: int = tile.get("type", TileType.WILDERNESS)
	if _cap_tile_type == TileType.CORE_FORTRESS or _cap_tile_type == TileType.LIGHT_STRONGHOLD:
		_sat_gain = BalanceConfig.SAT_GAIN_FORTRESS
	_sat_points[player["id"]] = _sat_points.get(player["id"], 0) + _sat_gain
	if player["id"] == get_human_player_id():
		EventBus.message_log.emit("[color=pink]満足度+%d (計%d)[/color]" % [_sat_gain, _sat_points[player["id"]]])
	# Post-conquest choice (occupy / pillage / plunder)
	_show_conquest_choice(player, tile)


func _show_conquest_choice(player: Dictionary, tile: Dictionary) -> void:
	## Shows the post-conquest choice popup for human players.
	if player["id"] != get_human_player_id():
		# AI auto-occupies
		_apply_conquest_choice(tile, "occupy")
		return

	_pending_conquest_tile_index = tile["index"]

	# Calculate base loot for display
	var base_loot: Dictionary = _calculate_conquest_loot(tile, player["id"])
	var is_pirate: bool = _get_faction_tag_for_player(player["id"]) == "pirate"
	var pirate_tag: String = " [color=#ffcc44](海盗+25%%)[/color]" if is_pirate else ""

	var occ_g: int = int(float(base_loot["gold"]) * BalanceConfig.CONQUEST_OCCUPY_GOLD_MULT)
	var occ_f: int = int(float(base_loot["food"]) * BalanceConfig.CONQUEST_OCCUPY_GOLD_MULT)
	var occ_i: int = int(float(base_loot["iron"]) * BalanceConfig.CONQUEST_OCCUPY_GOLD_MULT)

	var pil_g: int = int(float(base_loot["gold"]) * BalanceConfig.CONQUEST_PILLAGE_GOLD_MULT)
	var pil_f: int = int(float(base_loot["food"]) * BalanceConfig.CONQUEST_PILLAGE_GOLD_MULT)
	var pil_i: int = int(float(base_loot["iron"]) * BalanceConfig.CONQUEST_PILLAGE_GOLD_MULT)

	var plu_g: int = int(float(base_loot["gold"]) * BalanceConfig.CONQUEST_PLUNDER_GOLD_MULT)
	var plu_f: int = int(float(base_loot["food"]) * BalanceConfig.CONQUEST_PLUNDER_GOLD_MULT)
	var plu_i: int = int(float(base_loot["iron"]) * BalanceConfig.CONQUEST_PLUNDER_GOLD_MULT)

	var title: String = "占领 %s" % tile["name"]
	var desc: String = "[color=#aaaacc]你的军队已经攻下了此地。如何处置？[/color]%s" % pirate_tag
	var choices: Array = [
		{"text": "占领 — 恢复秩序 (治安+20%%, %d金/%d粮/%d铁)" % [occ_g, occ_f, occ_i]},
		{"text": "洗劫 — 搜刮财物 (治安-40%%, %d金/%d粮/%d铁)" % [pil_g, pil_f, pil_i]},
		{"text": "掳掠 — 纵兵劫掠 (治安-70%%, %d金/%d粮/%d铁, +25%%HP, H事件)" % [plu_g, plu_f, plu_i]},
	]

	if not _conquest_choice_connected:
		EventBus.conquest_choice_selected.connect(_on_conquest_choice)
		_conquest_choice_connected = true

	EventBus.show_event_popup.emit(title, desc, choices)


func _on_conquest_choice(choice_index: int) -> void:
	if _pending_conquest_tile_index < 0:
		return
	var tile_idx: int = _pending_conquest_tile_index
	_pending_conquest_tile_index = -1

	var tile: Dictionary = tiles[tile_idx]
	match choice_index:
		0:
			_apply_conquest_choice(tile, "occupy")
		1:
			_apply_conquest_choice(tile, "pillage")
		2:
			_apply_conquest_choice(tile, "plunder")
		_:
			_apply_conquest_choice(tile, "occupy")


func _apply_conquest_choice(tile: Dictionary, choice: String) -> void:
	var pid: int = tile["owner_id"]
	var base_loot: Dictionary = _calculate_conquest_loot(tile, pid)
	var mult: float = 1.0
	var delta := {"gold": 0, "food": 0, "iron": 0}

	match choice:
		"occupy":
			tile["public_order"] = clampf(BalanceConfig.TILE_ORDER_DEFAULT + BalanceConfig.CONQUEST_OCCUPY_ORDER_BONUS, 0.0, 1.0)
			mult = BalanceConfig.CONQUEST_OCCUPY_GOLD_MULT
			delta["gold"] = int(float(base_loot["gold"]) * mult)
			delta["food"] = int(float(base_loot["food"]) * mult)
			delta["iron"] = int(float(base_loot["iron"]) * mult)
			EventBus.message_log.emit("[color=green]占领 %s — 秩序恢复，获得 %d金/%d粮/%d铁[/color]" % [tile["name"], delta["gold"], delta["food"], delta["iron"]])
		"pillage":
			tile["public_order"] = clampf(BalanceConfig.TILE_ORDER_DEFAULT - BalanceConfig.CONQUEST_PILLAGE_ORDER_PENALTY, 0.0, 1.0)
			mult = BalanceConfig.CONQUEST_PILLAGE_GOLD_MULT
			delta["gold"] = int(float(base_loot["gold"]) * mult)
			delta["food"] = int(float(base_loot["food"]) * mult)
			delta["iron"] = int(float(base_loot["iron"]) * mult)
			# v4.4: 洗劫有30%概率掉落道具
			if randf() < 0.3:
				ItemManager.grant_random_loot(pid)
			EventBus.message_log.emit("[color=yellow]洗劫 %s — 大肆搜刮，获得 %d金/%d粮/%d铁，治安骤降[/color]" % [tile["name"], delta["gold"], delta["food"], delta["iron"]])
		"plunder":
			tile["public_order"] = clampf(BalanceConfig.TILE_ORDER_DEFAULT - BalanceConfig.CONQUEST_PLUNDER_ORDER_PENALTY, 0.0, 1.0)
			mult = BalanceConfig.CONQUEST_PLUNDER_GOLD_MULT
			delta["gold"] = int(float(base_loot["gold"]) * mult)
			delta["food"] = int(float(base_loot["food"]) * mult)
			delta["iron"] = int(float(base_loot["iron"]) * mult)
			# 25% HP recovery for all soldiers
			var army: int = ResourceManager.get_army(pid)
			var heal: int = maxi(1, int(float(army) * BalanceConfig.CONQUEST_PLUNDER_HP_RECOVERY))
			ResourceManager.add_army(pid, heal)
			sync_player_army(pid)
			# v4.4: 掳掠必定掉落道具
			ItemManager.grant_random_loot(pid)
			EventBus.message_log.emit("[color=red]掳掠 %s — 纵兵劫掠，获得 %d金/%d粮/%d铁，回复 %d 兵力[/color]" % [tile["name"], delta["gold"], delta["food"], delta["iron"], heal])
			# Trigger random H CG event
			EventBus.message_log.emit("[color=#ff69b4]掳掠中发生了特殊事件...[/color]")
			EventBus.event_triggered.emit(pid, "plunder_h_event", "掳掠中的特殊遭遇")

	ResourceManager.apply_delta(pid, delta)
	EventBus.conquest_choice_made.emit(tile["index"], choice)
	EventBus.resources_changed.emit(pid)


func _calculate_conquest_loot(tile: Dictionary, pid: int) -> Dictionary:
	## Returns base loot dict {gold, food, iron} from CONQUEST_LOOT_TABLE.
	## Applies tile level scaling and pirate faction +25% bonus.
	var tile_type: int = tile.get("type", 5)  # default WILDERNESS
	var entry: Dictionary = BalanceConfig.CONQUEST_LOOT_TABLE.get(tile_type, {"gold": 5, "food": 2, "iron": 2})
	var level: int = maxi(tile.get("level", 1), 1)
	var level_mult: float = 1.0 + (level - 1) * 0.25  # Lv1=1.0, Lv2=1.25, Lv3=1.5 ...

	var loot := {
		"gold": int(float(entry.get("gold", 5)) * level_mult),
		"food": int(float(entry.get("food", 2)) * level_mult),
		"iron": int(float(entry.get("iron", 2)) * level_mult),
	}

	# Pirate faction: +25% conquest loot
	if _get_faction_tag_for_player(pid) == "pirate":
		var bonus: float = 1.0 + BalanceConfig.PIRATE_CONQUEST_LOOT_BONUS
		loot["gold"] = int(float(loot["gold"]) * bonus)
		loot["food"] = int(float(loot["food"]) * bonus)
		loot["iron"] = int(float(loot["iron"]) * bonus)

	return loot


## Check and trigger conquest events when capturing a tile
func _check_conquest_events(pid: int, tile_index: int) -> void:
	var tile: Dictionary = tiles[tile_index]
	var tile_type: int = tile["type"]
	var tile_name: String = tile["name"]
	var owned_count: int = count_tiles_owned(pid)

	# Core Fortress conquest event
	if tile_type == TileType.CORE_FORTRESS:
		EventBus.message_log.emit("[color=gold]═══ 核心要塞陷落: %s ═══[/color]" % tile_name)
		EventBus.message_log.emit("[color=gold]攻占核心要塞! 敌方士气大幅动摇![/color]")
		# Bonus: all enemy garrisons lose 10% soldiers
		for i in range(tiles.size()):
			if tiles[i]["owner_id"] != pid and tiles[i]["owner_id"] >= 0:
				var loss: int = maxi(1, int(float(tiles[i]["garrison"]) * 0.10))
				tiles[i]["garrison"] = maxi(0, tiles[i]["garrison"] - loss)
		ResourceManager.apply_delta(pid, {"prestige": 10})
		EventBus.message_log.emit("威望+10! 敌方全据点驻军-10%!")

	# Light Stronghold conquest
	elif tile_type == TileType.LIGHT_STRONGHOLD:
		EventBus.message_log.emit("[color=cyan]═══ 光明要塞攻陷: %s ═══[/color]" % tile_name)
		# Check if this completes a faction's territory
		var light_faction: int = tile.get("light_faction", -1)
		if light_faction >= 0:
			var faction_tiles_remaining: int = 0
			for t in tiles:
				if t.get("light_faction", -1) == light_faction and t["owner_id"] != pid:
					faction_tiles_remaining += 1
			if faction_tiles_remaining == 0:
				var faction_name: String = _get_light_faction_name(light_faction)
				EventBus.message_log.emit("[color=gold]═══ 势力征服! %s 光明势力已被完全消灭! ═══[/color]" % faction_name)
				ResourceManager.apply_delta(pid, {"prestige": 25, "gold": 100})
				EventBus.message_log.emit("征服奖励: 威望+25, 金+100!")
				# Capture chance for faction leader
				var leader_id: String = _get_light_faction_leader(light_faction)
				if leader_id != "" and HeroSystem != null and leader_id not in HeroSystem.captured_heroes and leader_id not in HeroSystem.recruited_heroes:
					HeroSystem.attempt_capture(leader_id, 0.75)

	# Milestone events based on total tiles owned
	if owned_count == 10:
		EventBus.message_log.emit("[color=yellow]═══ 暗潮崛起 ═══[/color]")
		EventBus.message_log.emit("[color=yellow]控制10个据点! 大陆开始感受到暗潮的威胁...[/color]")
		ResourceManager.apply_delta(pid, {"prestige": 5})
	elif owned_count == 20:
		EventBus.message_log.emit("[color=yellow]═══ 暗潮汹涌 ═══[/color]")
		EventBus.message_log.emit("[color=yellow]控制20个据点! 光明联盟开始恐慌![/color]")
		ResourceManager.apply_delta(pid, {"prestige": 10, "gold": 50})
	elif owned_count == 30:
		EventBus.message_log.emit("[color=orange]═══ 暗潮席卷 ═══[/color]")
		EventBus.message_log.emit("[color=orange]控制30个据点! 大陆半数已沦陷, 最终决战即将到来![/color]")
		ResourceManager.apply_delta(pid, {"prestige": 20, "gold": 100, "iron": 50})
	elif owned_count == 40:
		EventBus.message_log.emit("[color=red]═══ 暗潮吞噬 ═══[/color]")
		EventBus.message_log.emit("[color=red]控制40个据点! 光明仅存最后的抵抗...[/color]")
		ResourceManager.apply_delta(pid, {"prestige": 30, "gold": 200})

	# Harbor conquest: fleet bonus
	if tile_type == TileType.HARBOR:
		EventBus.message_log.emit("[color=cyan]港口占领: %s — 海上补给线开通![/color]" % tile_name)
		ResourceManager.apply_delta(pid, {"food": 20})

	# Trading Post: merchant bonus
	if tile_type == TileType.TRADING_POST:
		EventBus.message_log.emit("[color=gold]交易站占领: %s — 商人蜂拥而至![/color]" % tile_name)
		ResourceManager.apply_delta(pid, {"gold": 30})

	# Ruins: discovery event
	if tile_type == TileType.RUINS:
		EventBus.message_log.emit("[color=purple]遗迹占领: %s — 发现古代知识![/color]" % tile_name)
		if randf() < 0.5:
			ResourceManager.apply_delta(pid, {"prestige": 5})
			EventBus.message_log.emit("古代文献: 威望+5!")
		else:
			ItemManager.grant_random_loot(pid)
			EventBus.message_log.emit("遗迹宝物: 获得随机物品!")


## Helper: get light faction display name
func _get_light_faction_name(light_faction: int) -> String:
	return FactionData.LIGHT_FACTION_NAMES.get(light_faction, "未知势力")


## Helper: get the hero_id of the faction leader
func _get_light_faction_leader(light_faction: int) -> String:
	match light_faction:
		0: return "human_leader"
		1: return "elf_leader"
		2: return "mage_leader"
		_: return ""


func tick_tile_public_order() -> void:
	## Called each turn. Drifts tile public_order toward natural cap.
	for tile in tiles:
		if tile == null:
			continue
		if tile.get("owner_id", -1) < 0:
			continue
		var order: float = tile.get("public_order", BalanceConfig.TILE_ORDER_DEFAULT)
		if order >= BalanceConfig.TILE_ORDER_NATURAL_CAP:
			continue  # Already at or above natural cap, no drift
		var drift: float = BalanceConfig.TILE_ORDER_DRIFT_PER_TURN
		# Garrison bonus
		if tile.get("garrison", 0) > 5:
			drift += BalanceConfig.TILE_ORDER_GARRISON_DRIFT
		# Building bonus
		var bld_level: int = tile.get("building_level", 0)
		drift += bld_level * BalanceConfig.TILE_ORDER_BUILDING_DRIFT
		# SR07: Garrison commander order bonus
		var _cmd_order: Dictionary = HeroSystem.get_garrison_commander_bonus(tile.get("index", -1)) if HeroSystem != null else {}
		drift += _cmd_order.get("order_bonus", 0)
		order = minf(order + drift, BalanceConfig.TILE_ORDER_NATURAL_CAP)
		tile["public_order"] = clampf(order, 0.0, 1.0)


func _check_elimination(player: Dictionary) -> void:
	if ResourceManager.get_army(player["id"]) <= 0:
		EventBus.message_log.emit("%s 的军队被彻底消灭了!" % player["name"])
		check_win_condition()


# ═══════════════ RECRUITMENT ═══════════════

# Legacy action (pre-v0.8)
func recruit_army() -> void:
	if not game_active:
		return
	var player: Dictionary = players[current_player_index]
	if player["is_ai"] or player["ap"] < 1:
		return

	var pid: int = player["id"]
	var faction_id: int = get_player_faction(pid)
	var params: Dictionary = FactionData.FACTION_PARAMS[faction_id]
	var gold_cost: int = params["recruit_cost_gold"]
	var iron_cost: int = params["recruit_cost_iron"]

	# Training ground discount
	# BUG FIX R12: bounds check before tiles[] access
	var pos: int = player.get("position", -1)
	if pos < 0 or pos >= tiles.size():
		EventBus.message_log.emit("无效位置, 无法招募!")
		return
	var tile: Dictionary = tiles[pos]
	if tile.get("building_id", "") == "training_ground":
		var bld_level: int = tile.get("building_level", 1)
		var bld_effects: Dictionary = BuildingRegistry.get_building_effects("training_ground", bld_level)
		gold_cost = maxi(0, gold_cost - bld_effects.get("recruit_discount", 10))

	if not ResourceManager.can_afford(pid, {"gold": gold_cost, "iron": iron_cost}):
		EventBus.message_log.emit("资源不足! 需要 %d金 %d铁" % [gold_cost, iron_cost])
		return

	if tile["owner_id"] != pid:
		EventBus.message_log.emit("只能在自己的领地招募!")
		return

	var pop_cap: int = get_population_cap(pid)
	if ResourceManager.get_army(pid) >= pop_cap:
		EventBus.message_log.emit("已达人口上限 (%d)!" % pop_cap)
		return

	ResourceManager.spend(pid, {"gold": gold_cost, "iron": iron_cost})
	ResourceManager.add_army(pid, 1)
	player["army_count"] = ResourceManager.get_army(pid)
	player["combat_power"] = player["army_count"] * COMBAT_POWER_PER_UNIT
	player["ap"] -= 1

	EventBus.message_log.emit("%s 招募了1个步兵! (金-%d 铁-%d)" % [player["name"], gold_cost, iron_cost])
	EventBus.action_visualize_recruit.emit(player["position"], "infantry", 1)


func can_recruit() -> bool:
	if not game_active:
		return false
	var player: Dictionary = players[current_player_index]
	if player["ap"] < 1:
		return false
	var pid: int = player["id"]
	var faction_id: int = get_player_faction(pid)
	var params: Dictionary = FactionData.FACTION_PARAMS[faction_id]
	var gold_cost: int = params["recruit_cost_gold"]
	var iron_cost: int = params["recruit_cost_iron"]
	# BUG FIX R12: bounds check before tiles[] access
	var pos: int = player.get("position", -1)
	if pos < 0 or pos >= tiles.size():
		return false
	var tile: Dictionary = tiles[pos]
	if tile.get("building_id", "") == "training_ground":
		var bld_level: int = tile.get("building_level", 1)
		var bld_effects: Dictionary = BuildingRegistry.get_building_effects("training_ground", bld_level)
		gold_cost = maxi(0, gold_cost - bld_effects.get("recruit_discount", 10))
	if not ResourceManager.can_afford(pid, {"gold": gold_cost, "iron": iron_cost}):
		return false
	if tile["owner_id"] != pid:
		return false
	if ResourceManager.get_army(pid) >= get_population_cap(pid):
		return false
	return true


# ═══════════════ UPGRADE ═══════════════

# Legacy action (pre-v0.8)
func upgrade_tile() -> void:
	if not game_active:
		return
	var player: Dictionary = players[current_player_index]
	if player["is_ai"] or player["ap"] < 1:
		return

	var tile: Dictionary = tiles[player["position"]]
	if tile["owner_id"] != player["id"]:
		EventBus.message_log.emit("只能升级自己的领地!")
		return
	if tile["level"] >= MAX_TILE_LEVEL:
		EventBus.message_log.emit("领地已达最高等级!")
		return

	if tile["level"] >= UPGRADE_COSTS.size():
		return
	var cost: Array = UPGRADE_COSTS[tile["level"]]
	if not ResourceManager.can_afford(player["id"], {"gold": cost[0], "iron": cost[1]}):
		EventBus.message_log.emit("资源不足! 升级需要 %d金 %d铁" % [cost[0], cost[1]])
		return

	ResourceManager.spend(player["id"], {"gold": cost[0], "iron": cost[1]})
	player["ap"] -= 1
	tile["level"] += 1

	OrderManager.on_tile_upgraded()
	EventBus.message_log.emit("%s 升级到Lv%d!" % [tile["name"], tile["level"]])
	EventBus.tile_captured.emit(player["id"], tile["index"])


func can_upgrade() -> bool:
	if not game_active:
		return false
	var player: Dictionary = players[current_player_index]
	if player["ap"] < 1:
		return false
	var tile: Dictionary = tiles[player["position"]]
	if tile["owner_id"] != player["id"]:
		return false
	if tile["level"] >= MAX_TILE_LEVEL:
		return false
	if tile["level"] >= UPGRADE_COSTS.size():
		return false
	var cost: Array = UPGRADE_COSTS[tile["level"]]
	return ResourceManager.can_afford(player["id"], {"gold": cost[0], "iron": cost[1]})


# ═══════════════ BUILDING ═══════════════

# Legacy action (pre-v0.8)
func build_on_tile(building_id: String) -> void:
	if not game_active:
		return
	var player: Dictionary = players[current_player_index]
	if player["is_ai"] or player["ap"] < 1:
		return

	var tile: Dictionary = tiles[player["position"]]
	if not BuildingRegistry.can_build_at(player["id"], tile, building_id):
		EventBus.message_log.emit("无法在此建造!")
		return

	var existing_bld: String = tile.get("building_id", "")
	var is_upgrade: bool = (existing_bld == building_id and existing_bld != "")
	var target_level: int = 1
	if is_upgrade:
		target_level = tile.get("building_level", 1) + 1

	var cost: Dictionary = BuildingRegistry.get_building_cost(building_id, target_level)
	if not ResourceManager.spend(player["id"], cost):
		EventBus.message_log.emit("资源不足!")
		return

	player["ap"] -= 1
	tile["building_id"] = building_id
	tile["building_level"] = target_level

	var bname: String = BuildingRegistry.get_building_name(building_id, target_level)
	BuildingRegistry.apply_building_effects(player["id"], building_id, tile)
	EventBus.building_constructed.emit(player["id"], tile["index"], building_id)
	EventBus.action_visualize_build.emit(tile["index"], building_id)
	if is_upgrade:
		EventBus.message_log.emit("%s 升级了 %s 至 Lv%d" % [player["name"], bname, target_level])
	else:
		EventBus.message_log.emit("%s 在 %s 建造了 %s" % [player["name"], tile["name"], bname])


func can_build_any() -> bool:
	if not game_active:
		return false
	var player: Dictionary = players[current_player_index]
	if player["ap"] < 1:
		return false
	var tile: Dictionary = tiles[player["position"]]
	var available: Array = BuildingRegistry.get_available_buildings_for(player["id"], tile)
	for b in available:
		if b["can_build"]:
			return true
	return false


# ═══════════════ INTERACTION ═══════════════

# Legacy action (pre-v0.8)
func interact_with_tile() -> void:
	if not game_active:
		return
	var player: Dictionary = players[current_player_index]
	if player["is_ai"] or player["ap"] < 1:
		return
	var tile: Dictionary = tiles[player["position"]]

	# Building interaction
	if tile["owner_id"] == player["id"] and tile.get("building_id", "") != "":
		var bld: String = tile["building_id"]
		player["ap"] -= 1
		match bld:
			"war_pit":
				OrcMechanic.convert_slave_to_army(player["id"])
			"black_market":
				PirateMechanic.buy_market_item(player["id"])
			_:
				EventBus.message_log.emit("使用了 %s" % BuildingRegistry.get_building_name(bld))
		return

	# Tile type interaction
	match tile["type"]:
		TileType.EVENT_TILE:
			player["ap"] -= 1
			_trigger_event(player, tile)
		_:
			EventBus.message_log.emit("此处没有可交互的对象")


func can_interact() -> bool:
	if not game_active:
		return false
	var player: Dictionary = players[current_player_index]
	if player["ap"] < 1:
		return false
	var tile: Dictionary = tiles[player["position"]]
	if tile["owner_id"] == player["id"] and tile.get("building_id", "") != "":
		return true
	if tile["type"] == TileType.EVENT_TILE:
		return true
	return false


# ═══════════════ EVENTS ═══════════════

func _trigger_event(player: Dictionary, _tile: Dictionary) -> void:
	# Filter for faction-specific and threat-gated events
	var valid_events: Array = []
	var player_faction_name: String = ""
	match GameManager.get_player_faction(player["id"]):
		FactionData.FactionID.ORC: player_faction_name = "orc"
		FactionData.FactionID.PIRATE: player_faction_name = "pirate"
		FactionData.FactionID.DARK_ELF: player_faction_name = "dark_elf"
	for evt in EVENT_DEFS:
		if evt.has("faction") and evt["faction"] != player_faction_name:
			continue
		if evt.has("threat_min") and ThreatManager.get_threat() < evt["threat_min"]:
			continue
		valid_events.append(evt)
	if valid_events.is_empty():
		return
	var event: Dictionary = valid_events[randi() % valid_events.size()]
	EventBus.event_triggered.emit(player["id"], event["name"], event["desc"])
	EventBus.message_log.emit("[事件] %s: %s" % [event["name"], event["desc"]])

	# v0.7: Binary choice system - AI picks option_a, human triggers popup
	if player.get("is_ai", true):
		_apply_choice_event(player, event, "a")
	else:
		# Human player: show popup and wait for choice
		EventBus.choice_event_triggered.emit(player["id"], event)
		_show_random_event_popup(player, event)


func _apply_choice_event(player: Dictionary, event: Dictionary, choice: String) -> void:
	var option: Dictionary = event.get("option_a", {}) if choice != "b" else event.get("option_b", {})
	var label: String = option.get("label", "")
	var effects: Dictionary = option.get("effects", {})
	EventBus.message_log.emit("选择: %s" % label)

	# If effects contain "risk_army", it's a risk/reward gamble: success gives rewards, failure
	# gives penalty. Process risk_army FIRST to determine outcome, then conditionally apply others.
	var _risk_failed: bool = false
	if effects.has("risk_army"):
		var success_rate: float = effects.get("success_rate", 1.0)
		var risk_value = effects["risk_army"]
		if randf() > success_rate:
			_risk_failed = true
			ResourceManager.remove_army(player["id"], abs(risk_value))
			player["army_count"] = ResourceManager.get_army(player["id"])
			player["combat_power"] = player["army_count"] * COMBAT_POWER_PER_UNIT
			EventBus.message_log.emit("失败! 损失 %d 军队" % abs(risk_value))
		else:
			EventBus.message_log.emit("成功!")

	for key in effects:
		var value = effects[key]
		# Skip risk_army meta keys (already processed above)
		if key in ["risk_army", "success_rate"]:
			continue
		# If risk_army failed, skip reward effects (risk/reward is mutually exclusive)
		if _risk_failed and key in ["gold", "iron", "food", "slaves", "army", "item", "random_item", "prestige", "plunder", "waaagh"]:
			continue
		match key:
			"slaves":
				ResourceManager.apply_delta(player["id"], {"slaves": value})
			"army":
				ResourceManager.add_army(player["id"], value)
			"order":
				OrderManager.change_order(value)
			"gold":
				ResourceManager.apply_delta(player["id"], {"gold": value})
			"iron":
				ResourceManager.apply_delta(player["id"], {"iron": value})
			"food":
				ResourceManager.apply_delta(player["id"], {"food": value})
			"prestige":
				ResourceManager.apply_delta(player["id"], {"prestige": value})
			"waaagh":
				OrcMechanic.add_waaagh(player["id"], value)
			"plunder":
				ResourceManager.apply_delta(player["id"], {"gold": value * 10})
				EventBus.message_log.emit("掠夺值转化为 %d 金币" % (value * 10))
			"threat":
				ThreatManager.change_threat(value)
			"item":
				ItemManager.add_item(player["id"], ItemManager.get_random_item())
			"random_item":
				_give_random_item(player)
			"temp_army":
				BuffManager.add_buff(player["id"], "temp_army", "temp_army", value, effects.get("duration", 3), "event")
				ResourceManager.add_army(player["id"], value)
				EventBus.message_log.emit("获得 %d 临时军队 (%d 回合)" % [value, effects.get("duration", 3)])
			"no_move", "no_move_next":
				BuffManager.add_buff(player["id"], "no_move", "no_move", 1, effects.get("duration", 1), "event")
				EventBus.message_log.emit("无法移动 %d 回合" % effects.get("duration", 1))
			"atk_buff":
				BuffManager.add_buff(player["id"], "atk_buff", "atk_mult", 1.0 + value, effects.get("duration", 3), "event")
				EventBus.message_log.emit("攻击力+%.0f%% 持续 %d 回合" % [value * 100, effects.get("duration", 3)])
			"risk_army":
				pass  # Handled above, before the loop
			"mage_mana":
				pass  # Mage mana effects handled by light faction system
			"relic":
				if value > 0:
					EventBus.message_log.emit("获得遗物!")
			"production_debuff":
				BuffManager.add_buff(player["id"], "prod_debuff", "production_mult", 1.0 + value, effects.get("duration", 3), "event")
				EventBus.message_log.emit("产出%.0f%% 持续 %d 回合" % [value * 100, effects.get("duration", 3)])
			"success_rate", "duration":
				pass  # Meta keys, not actual effects
			"risk_slaves":
				var success_rate: float = effects.get("success_rate", 1.0)
				if randf() > success_rate:
					var loss: int = abs(value)
					# BUG FIX: removed duplicate ResourceManager.apply_delta - SlaveManager handles it
					SlaveManager.remove_slaves(player["id"], loss)
					EventBus.message_log.emit("失败! 损失 %d 奴隶" % loss)
				else:
					EventBus.message_log.emit("成功!")
			"risk_outpost":
				var success_rate2: float = effects.get("success_rate", 1.0)
				if randf() > success_rate2:
					var owned_tiles: Array = []
					for t in tiles:
						if t["owner_id"] == player["id"] and t["type"] == TileType.DARK_BASE:
							owned_tiles.append(t)
					if owned_tiles.size() > 0:
						var lost_tile: Dictionary = owned_tiles[randi() % owned_tiles.size()]
						lost_tile["owner_id"] = -1
						EventBus.message_log.emit("失去前哨: %s" % lost_tile["name"])
				else:
					EventBus.message_log.emit("安然无恙")
			"lose_outpost":
				var owned_tiles2: Array = []
				for t in tiles:
					if t["owner_id"] == player["id"] and t["type"] == TileType.DARK_BASE:
						owned_tiles2.append(t)
				if owned_tiles2.size() > 0:
					var lost_tile: Dictionary = owned_tiles2[randi() % owned_tiles2.size()]
					lost_tile["owner_id"] = -1
					EventBus.message_log.emit("失去前哨: %s" % lost_tile["name"])
				else:
					EventBus.message_log.emit("没有可失去的前哨")
			"combat_enemy":
				var enemy_strength: int = int(value)
				if player["position"] < 0 or player["position"] >= tiles.size():
					EventBus.message_log.emit("无效位置，跳过战斗")
				else:
					var enemy_tile: Dictionary = tiles[player["position"]]
					var saved_garrison: int = enemy_tile["garrison"]
					enemy_tile["garrison"] = enemy_strength
					_resolve_combat(player, enemy_tile, "敌军巡逻队")
					enemy_tile["garrison"] = saved_garrison
					EventBus.message_log.emit("战斗结束!")
			"reveal_fog":
				var count: int = int(abs(value))
				var unrevealed: Array = []
				for t in tiles:
					if not t["revealed"].get(player["id"], false):
						unrevealed.append(t["index"])
				unrevealed.shuffle()
				for j in range(mini(count, unrevealed.size())):
					_reveal_around(unrevealed[j], player["id"])
				EventBus.message_log.emit("揭示了 %d 格迷雾" % mini(count, unrevealed.size()))
			"special_npc":
				var available_npcs: Array = NpcManager.get_available_npcs_for_faction(get_player_faction(player["id"]))
				if available_npcs.size() > 0:
					var npc_id: String = available_npcs[randi() % available_npcs.size()]
					if NpcManager.capture_npc(player["id"], npc_id):
						EventBus.message_log.emit("获得特殊NPC!")
					else:
						EventBus.message_log.emit("NPC已在队伍中")
				else:
					EventBus.message_log.emit("没有可获得的NPC")
			"gold_next_visit":
				# Store a gold bonus that triggers on next visit to a specific tile
				var tile_idx: int = player.get("position", 0)
				if tile_idx < 0 or tile_idx >= tiles.size():
					push_warning("GameManager: gold_next_visit tile_idx %d out of bounds" % tile_idx)
				else:
					if not tiles[tile_idx].has("deferred_effects"):
						tiles[tile_idx]["deferred_effects"] = {}
					tiles[tile_idx]["deferred_effects"]["gold_next_visit"] = {
						"player_id": player["id"],
						"value": int(value),
						"turns_remaining": effects.get("duration", -1),
					}
					EventBus.message_log.emit("下次访问此据点时获得 %d 金币" % int(value))
			"attacked_next_turn":
				# Schedule an enemy attack at the start of next turn
				# BUG FIX: value is boolean true, use meaningful attack strength
				if not player.has("deferred_attacks"):
					player["deferred_attacks"] = []
				var attack_strength: int = randi_range(30, 50) if (value is bool or int(abs(value)) <= 1) else int(abs(value))
				player["deferred_attacks"].append({
					"strength": attack_strength,
					"turns_delay": 1,
					"tile_index": player.get("position", 0),
				})
				EventBus.message_log.emit("[color=red]下回合将遭到 %d 兵力的袭击![/color]" % attack_strength)
			"prep_turns":
				# Grant a preparation buff for N turns (defense bonus)
				var duration: int = int(abs(value))
				BuffManager.add_buff(player["id"], "prep_defense", "def_mult", 1.3, duration, "event")
				EventBus.message_log.emit("获得备战状态: 防御+30%% 持续 %d 回合" % duration)
			"army_per_turn":
				BuffManager.add_buff(player["id"], "army_per_turn", "army_per_turn", value, effects.get("duration", 3), "event")
				EventBus.message_log.emit("每回合军队变化 %d, 持续 %d 回合" % [value, effects.get("duration", 3)])
			_:
				print("[WARNING] Unknown event effect key: %s = %s" % [key, str(value)])


# ═══════════════ ITEMS ═══════════════

func _give_random_item(player: Dictionary) -> void:
	## Delegate to ItemManager for random item acquisition.
	var item_id: String = ItemManager.get_random_item()
	if ItemManager.add_item(player["id"], item_id):
		var item_def: Dictionary = FactionData.ITEM_DEFS.get(item_id, {})
		EventBus.item_acquired.emit(player["id"], item_def.get("name", item_id))


func use_item(item_id: String) -> void:
	## Delegate to ItemManager for item usage.
	if not game_active:
		return
	var player: Dictionary = players[current_player_index]
	if player["is_ai"]:
		return
	var pid: int = player["id"]
	if ItemManager.use_item(pid, item_id):
		var item_name: String = item_id
		if FactionData.ITEM_DEFS.has(item_id):
			item_name = FactionData.ITEM_DEFS[item_id].get("name", item_id)
		EventBus.item_used.emit(pid, item_name)


# ═══════════════ FOG OF WAR ═══════════════

func _reveal_around(tile_index: int, player_id: int) -> void:
	if tile_index < 0 or tile_index >= tiles.size():
		return
	var tdata: Dictionary = FactionData.TERRAIN_DATA.get(tiles[tile_index].get("terrain", FactionData.TerrainType.PLAINS), {})
	var vis_range: int = tdata.get("visibility_range", 2)
	# Apply building visibility_bonus from the source tile (Watch Tower, Scout Tower, etc.)
	var tile_effects: Dictionary = BuildingRegistry.get_tile_building_effects(tiles[tile_index])
	vis_range += int(tile_effects.get("visibility_bonus", 0))
	var visited: Dictionary = {tile_index: 0}
	var queue: Array = [tile_index]
	while queue.size() > 0:
		var current: int = queue.pop_front()
		var depth: int = visited[current]
		if not tiles[current].has("revealed"):
			tiles[current]["revealed"] = {}
		tiles[current]["revealed"][player_id] = true
		if depth < vis_range:
			var neighbors: Array = adjacency.get(current, [])
			for neighbor in neighbors:
				if not visited.has(neighbor) and neighbor >= 0 and neighbor < tiles.size():
					visited[neighbor] = depth + 1
					queue.append(neighbor)
	EventBus.fog_updated.emit(player_id)


func is_revealed_for(tile_index: int, player_id: int) -> bool:
	# BUG FIX R15: null check + safe "revealed" access
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var _rv_tile = tiles[tile_index]
	if _rv_tile == null:
		return false
	return _rv_tile.get("revealed", {}).get(player_id, false)


# ═══════════════ ACTION SYSTEM (v0.8) ═══════════════

func get_attackable_tiles(player_id: int) -> Array:
	## Returns tiles that can be attacked (enemy/uncaptured tiles adjacent to owned tiles).
	var result: Array = []
	var owned_indices: Dictionary = {}
	for tile in tiles:
		# BUG FIX R15: null check
		if tile == null:
			continue
		if tile["owner_id"] == player_id:
			owned_indices[tile["index"]] = true

	var seen: Dictionary = {}
	for tile in tiles:
		# BUG FIX R15: null check
		if tile == null:
			continue
		if tile["owner_id"] == player_id:
			if adjacency.has(tile["index"]):
				for nb_idx in adjacency[tile["index"]]:
					if seen.has(nb_idx):
						continue
					seen[nb_idx] = true
					if nb_idx < tiles.size() and not owned_indices.has(nb_idx):
						result.append(tiles[nb_idx])
	return result


func get_domestic_tiles(player_id: int) -> Array:
	## Returns owned tiles where domestic actions (recruit/upgrade/build) are possible.
	var result: Array = []
	for tile in tiles:
		# BUG FIX R15: null check
		if tile == null:
			continue
		if tile["owner_id"] == player_id:
			result.append(tile)
	return result


func get_diplomacy_targets(player_id: int) -> Array:
	## Returns available diplomacy targets with taming level info.
	var result: Array = []
	var seen_factions: Dictionary = {}
	for tile in tiles:
		if tile.get("neutral_faction_id", -1) >= 0:
			var nf_id: int = tile["neutral_faction_id"]
			if seen_factions.has(nf_id):
				continue
			seen_factions[nf_id] = true
			var recruited: bool = QuestManager.is_faction_recruited(player_id, nf_id)
			var step: int = QuestManager.get_quest_step(player_id, nf_id)
			var taming: int = QuestManager.get_taming_level(player_id, nf_id)
			var tier: String = QuestManager.get_taming_tier(player_id, nf_id)
			var unlocked: Array = QuestManager.get_unlocked_neutral_troops(player_id, nf_id)
			var ftag: String = QuestManager._resolve_faction_tag(nf_id)
			var max_steps: int = 3
			if QuestManager.NEUTRAL_FACTIONS.has(ftag):
				max_steps = QuestManager.NEUTRAL_FACTIONS[ftag]["quest_chain"].size()
			result.append({
				"type": "neutral",
				"tile_index": tile["index"],
				"faction_id": nf_id,
				"name": QuestManager._get_faction_name(ftag),
				"quest_step": step,
				"max_steps": max_steps,
				"recruited": recruited,
				"tile_owned": tile["owner_id"] == player_id,
				"taming_level": taming,
				"taming_tier": tier,
				"unlocked_troops": unlocked,
			})
	return result


func get_explorable_tiles(player_id: int) -> Array:
	## Returns owned tiles that can be explored.
	var result: Array = []
	for tile in tiles:
		# BUG FIX R15: null check
		if tile == null:
			continue
		if tile["owner_id"] == player_id:
			result.append(tile)
	return result


func action_attack(player_id: int, target_tile_index: int) -> bool:
	## Execute an attack action on a target tile. Costs 1 AP.
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		return false
	if ResourceManager.get_army(player_id) <= 0:
		EventBus.message_log.emit("没有士兵, 无法进攻!")
		return false
	if target_tile_index < 0 or target_tile_index >= tiles.size():
		return false

	var tile: Dictionary = tiles[target_tile_index]
	# BUG FIX R15: null check on tile
	if tile == null:
		return false
	if tile["owner_id"] == player_id:
		EventBus.message_log.emit("不能攻击自己的领地!")
		return false

	# Verify adjacency to an owned tile
	var adjacent_to_owned: bool = false
	if adjacency.has(target_tile_index):
		for nb_idx in adjacency[target_tile_index]:
			if nb_idx < tiles.size() and tiles[nb_idx]["owner_id"] == player_id:
				adjacent_to_owned = true
				break
	if not adjacent_to_owned:
		EventBus.message_log.emit("目标必须与己方领地相邻!")
		return false

	player["ap"] -= 1
	_had_combat_this_turn = true

	# Determine defender description
	var defender_desc: String = "守军"
	match tile["type"]:
		TileType.LIGHT_STRONGHOLD:
			defender_desc = "光明联盟要塞守军"
		TileType.CORE_FORTRESS:
			defender_desc = tile.get("name", "核心要塞") + "守军"
		TileType.NEUTRAL_BASE:
			var nf_name: String = FactionData.NEUTRAL_FACTION_NAMES.get(tile.get("neutral_faction_id", -1), "中立势力")
			defender_desc = nf_name + "守军"
		_:
			if tile["owner_id"] >= 0:
				var _p3 = get_player_by_id(tile["owner_id"])
				defender_desc = (_p3.get("name", "敌军") if _p3 else "敌军") + "据点"

	# Apply threat garrison bonus for light faction tiles
	var original_garrison: int = tile["garrison"]
	if tile.get("light_faction", -1) >= 0:
		var bonus: float = ThreatManager.get_garrison_bonus()
		if bonus > 0.0:
			tile["garrison"] = int(float(original_garrison) * (1.0 + bonus))

	var won: bool = _resolve_combat(player, tile, defender_desc)

	# Always restore garrison to original before post-combat processing
	tile["garrison"] = original_garrison

	EventBus.action_visualize_attack.emit(player.get("position", -1), target_tile_index, {"won": won})

	if won:
		_capture_tile(player, tile)
		_reveal_around(target_tile_index, player_id)
		# Handle special tile captures
		if tile["type"] == TileType.LIGHT_STRONGHOLD or tile["type"] == TileType.CORE_FORTRESS:
			var faction_id: int = get_player_faction(player_id)
			FactionManager.on_stronghold_captured(player_id, faction_id)
		# Handle neutral quest on capture
		var nf_id: int = tile.get("neutral_faction_id", -1)
		if nf_id >= 0:
			_handle_neutral_quest(player, nf_id)
		check_win_condition()

	EventBus.player_arrived.emit(player_id, target_tile_index)
	return won


func action_domestic(player_id: int, target_tile_index: int, domestic_type: String, building_id: String = "") -> bool:
	## Execute a domestic action. domestic_type: "recruit", "upgrade", "build"
	## Costs 1 AP.
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		return false
	if target_tile_index < 0 or target_tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[target_tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能在自己的领地进行内政!")
		return false

	var pid: int = player_id
	var faction_id: int = get_player_faction(pid)

	match domestic_type:
		"recruit":
			var params: Dictionary = FactionData.FACTION_PARAMS[faction_id]
			var gold_cost: int = params["recruit_cost_gold"]
			var iron_cost: int = params["recruit_cost_iron"]
			if tile.get("building_id", "") == "training_ground":
				var bld_level: int = tile.get("building_level", 1)
				var bld_effects: Dictionary = BuildingRegistry.get_building_effects("training_ground", bld_level)
				gold_cost = maxi(0, gold_cost - bld_effects.get("recruit_discount", 10))
			if not ResourceManager.can_afford(pid, {"gold": gold_cost, "iron": iron_cost}):
				EventBus.message_log.emit("资源不足! 需要 %d金 %d铁" % [gold_cost, iron_cost])
				return false
			if ResourceManager.get_army(pid) >= get_population_cap(pid):
				EventBus.message_log.emit("已达人口上限!")
				return false
			ResourceManager.spend(pid, {"gold": gold_cost, "iron": iron_cost})
			ResourceManager.add_army(pid, 1)
			player["ap"] -= 1
			sync_player_army(pid)
			EventBus.message_log.emit("在 %s 招募了1个步兵" % tile["name"])
			EventBus.action_visualize_recruit.emit(target_tile_index, "infantry", 1)
			return true

		"upgrade":
			if tile["level"] >= MAX_TILE_LEVEL:
				EventBus.message_log.emit("领地已达最高等级!")
				return false
			if tile["level"] >= UPGRADE_COSTS.size():
				return false
			var cost: Array = UPGRADE_COSTS[tile["level"]]
			if not ResourceManager.can_afford(pid, {"gold": cost[0], "iron": cost[1]}):
				EventBus.message_log.emit("资源不足!")
				return false
			ResourceManager.spend(pid, {"gold": cost[0], "iron": cost[1]})
			player["ap"] -= 1
			tile["level"] += 1
			OrderManager.on_tile_upgraded()
			EventBus.message_log.emit("%s 升级到Lv%d!" % [tile["name"], tile["level"]])
			return true

		"build":
			if building_id == "":
				return false
			if not BuildingRegistry.can_build_at(pid, tile, building_id):
				EventBus.message_log.emit("无法在此建造!")
				return false
			var existing_bld: String = tile.get("building_id", "")
			var is_bld_upgrade: bool = (existing_bld == building_id and existing_bld != "")
			var target_level: int = 1
			if is_bld_upgrade:
				target_level = tile.get("building_level", 1) + 1
			var bld_cost: Dictionary = BuildingRegistry.get_building_cost(building_id, target_level)
			if not ResourceManager.spend(pid, bld_cost):
				EventBus.message_log.emit("资源不足!")
				return false
			player["ap"] -= 1
			tile["building_id"] = building_id
			tile["building_level"] = target_level
			BuildingRegistry.apply_building_effects(pid, building_id, tile)
			EventBus.building_constructed.emit(pid, target_tile_index, building_id)
			EventBus.action_visualize_build.emit(target_tile_index, building_id)
			EventBus.message_log.emit("建造了 %s" % BuildingRegistry.get_building_name(building_id, target_level))
			return true

	return false


func action_diplomacy(player_id: int, target_faction_id: int, diplomacy_type: String = "neutral_quest") -> bool:
	## Execute a diplomacy action. Supports neutral quest progression and Sengoku Rance-style
	## negotiation options: alliance_proposal, tribute, trade_agreement, ceasefire, demand_surrender.
	## Neutral quest costs 1 AP; other types cost 1 AP + resources.
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行動力不足!")
		return false

	match diplomacy_type:
		"neutral_quest":
			# Original behavior: advance neutral faction quest chain
			player["ap"] -= 1
			_handle_neutral_quest(player, target_faction_id)
			EventBus.ap_changed.emit(player_id, player["ap"])
			return true

		"alliance_proposal":
			# Propose alliance with an evil faction. Costs 50 gold, success based on reputation.
			if DiplomacyManager.is_orc_player(player_id):
				EventBus.message_log.emit("[color=red]兽人部落无法提出同盟![/color]")
				return false
			if not ResourceManager.can_afford(player_id, {"gold": 50}):
				EventBus.message_log.emit("[color=red]金币不足! 同盟提案需要50金[/color]")
				return false
			var rel: Dictionary = DiplomacyManager.get_all_relations(player_id).get(target_faction_id, {})
			if rel.get("recruited", false):
				EventBus.message_log.emit("该势力已被收编!")
				return false
			if rel.get("hostile", false):
				EventBus.message_log.emit("[color=red]敌对势力无法结盟! 先改善关系[/color]")
				return false
			player["ap"] -= 1
			ResourceManager.spend(player_id, {"gold": 50})
			# Success chance based on reputation: base 40% + 1% per reputation point
			var faction_key: String = DiplomacyManager._faction_to_ai_key(target_faction_id) if DiplomacyManager.has_method("_faction_to_ai_key") else ""
			var rep: int = DiplomacyManager.get_reputation(faction_key) if faction_key != "" else 0
			var success_chance: float = clampf(0.4 + float(rep) * 0.01, 0.1, 0.9)
			if randf() < success_chance:
				DiplomacyManager.sign_alliance(player_id, target_faction_id)
				if faction_key != "":
					DiplomacyManager.change_reputation(faction_key, 10)
				EventBus.message_log.emit("[color=green]同盟提案成功! 与%s结成同盟[/color]" % FactionData.FACTION_NAMES.get(target_faction_id, "???"))
			else:
				EventBus.message_log.emit("[color=yellow]同盟提案被拒绝! (-50金)[/color]")
			EventBus.ap_changed.emit(player_id, player["ap"])
			return true

		"tribute":
			# Pay gold to improve relations and reduce threat. Costs 80 gold.
			var tribute_cost: int = 80
			if not ResourceManager.can_afford(player_id, {"gold": tribute_cost}):
				EventBus.message_log.emit("[color=red]金币不足! 纳贡需要%d金[/color]" % tribute_cost)
				return false
			player["ap"] -= 1
			ResourceManager.spend(player_id, {"gold": tribute_cost})
			# Improve relations
			DiplomacyManager.improve_relation(player_id, target_faction_id, 15)
			# Reduce threat by 5 if targeting light-aligned faction concept
			ThreatManager.change_threat(-5)
			var fname: String = FactionData.FACTION_NAMES.get(target_faction_id, "???")
			EventBus.message_log.emit("[color=green]向%s纳贡%d金! 关系+15, 威胁-5[/color]" % [fname, tribute_cost])
			EventBus.ap_changed.emit(player_id, player["ap"])
			return true

		"trade_agreement":
			# Exchange resources: spend gold to gain food+iron or vice versa. Costs 1 AP.
			if DiplomacyManager.has_treaty(player_id, "trade", target_faction_id):
				EventBus.message_log.emit("已有通商协定!")
				return false
			var trade_gold_cost: int = 60
			if not ResourceManager.can_afford(player_id, {"gold": trade_gold_cost}):
				EventBus.message_log.emit("[color=red]金币不足! 通商协定需要%d金[/color]" % trade_gold_cost)
				return false
			player["ap"] -= 1
			ResourceManager.spend(player_id, {"gold": trade_gold_cost})
			# Immediate resource exchange: gain food and iron
			var food_gain: int = 40
			var iron_gain: int = 15
			ResourceManager.apply_delta(player_id, {"food": food_gain, "iron": iron_gain})
			# Also try to set up ongoing trade treaty
			DiplomacyManager.sign_trade(player_id, target_faction_id)
			var fname: String = FactionData.FACTION_NAMES.get(target_faction_id, "???")
			EventBus.message_log.emit("[color=green]与%s达成贸易! -%d金, +%d粮, +%d铁[/color]" % [fname, trade_gold_cost, food_gain, iron_gain])
			EventBus.ap_changed.emit(player_id, player["ap"])
			return true

		"ceasefire":
			# Temporary non-aggression for 3 turns. Costs 1 AP + 60 gold.
			var ceasefire_cost: int = 60
			if DiplomacyManager.is_ceasefire_active(player_id, target_faction_id):
				EventBus.message_log.emit("停战协议仍在生效中!")
				return false
			if not ResourceManager.can_afford(player_id, {"gold": ceasefire_cost}):
				EventBus.message_log.emit("[color=red]金币不足! 停战需要%d金[/color]" % ceasefire_cost)
				return false
			player["ap"] -= 1
			ResourceManager.spend(player_id, {"gold": ceasefire_cost})
			# Use DiplomacyManager ceasefire but with 3-turn duration
			if not DiplomacyManager._ceasefire.has(player_id):
				DiplomacyManager._ceasefire[player_id] = {}
			DiplomacyManager._ceasefire[player_id][target_faction_id] = 3
			if DiplomacyManager._relations.has(player_id) and DiplomacyManager._relations[player_id].has(target_faction_id):
				DiplomacyManager._relations[player_id][target_faction_id]["ceasefire_active"] = true
			var fname: String = FactionData.FACTION_NAMES.get(target_faction_id, "???")
			EventBus.message_log.emit("[color=cyan]与%s达成停战! 3回合内互不侵犯 (-%d金)[/color]" % [fname, ceasefire_cost])
			EventBus.ap_changed.emit(player_id, player["ap"])
			return true

		"demand_surrender":
			# If player controls 70%+ of all tiles, demand enemy surrender.
			var total_tiles: int = tiles.size()
			var player_tiles: int = count_tiles_owned(player_id)
			var control_pct: float = float(player_tiles) / float(maxi(1, total_tiles))
			if control_pct < 0.70:
				EventBus.message_log.emit("[color=red]领地不足70%%! 当前控制%.0f%%, 无法要求投降[/color]" % (control_pct * 100.0))
				return false
			var rel: Dictionary = DiplomacyManager.get_all_relations(player_id).get(target_faction_id, {})
			if rel.get("recruited", false):
				EventBus.message_log.emit("该势力已被收编!")
				return false
			player["ap"] -= 1
			# Success chance: 50% base + 1% per percentage point above 70%
			var bonus_pct: float = (control_pct - 0.70) * 100.0
			var surrender_chance: float = clampf(0.5 + bonus_pct * 0.01, 0.5, 0.95)
			if randf() < surrender_chance:
				DiplomacyManager.recruit_by_diplomacy(player_id, target_faction_id)
				EventBus.message_log.emit("[color=gold]%s 屈服于你的绝对优势, 无条件投降![/color]" % FactionData.FACTION_NAMES.get(target_faction_id, "???"))
			else:
				EventBus.message_log.emit("[color=red]%s 拒绝投降! 他们选择战斗到底![/color]" % FactionData.FACTION_NAMES.get(target_faction_id, "???"))
			EventBus.ap_changed.emit(player_id, player["ap"])
			return true

		_:
			EventBus.message_log.emit("[color=red]未知外交类型: %s[/color]" % diplomacy_type)
			return false


func _get_diplomacy_options(pid: int, target_faction_id: int) -> Array:
	## Returns which diplomacy options are available for the given player and target faction.
	## Each entry: { "id": String, "name": String, "cost": String, "desc": String, "available": bool }
	var options: Array = []
	var player: Dictionary = get_player_by_id(pid)
	if player.is_empty():
		return options

	var has_ap: bool = player["ap"] >= 1
	var gold: int = ResourceManager.get_resource(pid, "gold")

	# Check if target is a neutral faction (quest-based diplomacy)
	var is_neutral: bool = false
	for tile in tiles:
		if tile.get("neutral_faction_id", -1) == target_faction_id:
			is_neutral = true
			break

	if is_neutral:
		options.append({
			"id": "neutral_quest",
			"name": "外交交渉",
			"cost": "1 AP",
			"desc": "推进中立势力任务链",
			"available": has_ap,
		})
		return options

	# Evil faction diplomacy options
	var rel: Dictionary = DiplomacyManager.get_all_relations(pid).get(target_faction_id, {})
	var recruited: bool = rel.get("recruited", false)
	var hostile: bool = rel.get("hostile", false)

	if recruited:
		return options  # No options for already-recruited factions

	# Alliance proposal (non-orc, non-hostile, 50 gold)
	if not DiplomacyManager.is_orc_player(pid) and not hostile:
		options.append({
			"id": "alliance_proposal",
			"name": "同盟提案",
			"cost": "50金",
			"desc": "提议军事同盟 (成功率取决于声望)",
			"available": has_ap and gold >= 50,
		})

	# Tribute (80 gold, improve relations)
	options.append({
		"id": "tribute",
		"name": "纳贡",
		"cost": "80金",
		"desc": "纳贡改善关系+15, 威胁-5",
		"available": has_ap and gold >= 80,
	})

	# Trade agreement (60 gold)
	var has_trade: bool = DiplomacyManager.has_treaty(pid, "trade", target_faction_id)
	if not has_trade:
		options.append({
			"id": "trade_agreement",
			"name": "通商协定",
			"cost": "60金",
			"desc": "交换资源: +40粮 +15铁",
			"available": has_ap and gold >= 60,
		})

	# Ceasefire (60 gold, 3 turns)
	var ceasefire_active: bool = DiplomacyManager.is_ceasefire_active(pid, target_faction_id)
	if not ceasefire_active:
		options.append({
			"id": "ceasefire",
			"name": "停战协定",
			"cost": "60金",
			"desc": "3回合互不侵犯",
			"available": has_ap and gold >= 60,
		})

	# Demand surrender (70%+ territory control)
	var total_tiles: int = tiles.size()
	var player_tiles: int = count_tiles_owned(pid)
	var control_pct: float = float(player_tiles) / float(maxi(1, total_tiles))
	if control_pct >= 0.70:
		options.append({
			"id": "demand_surrender",
			"name": "要求投降",
			"cost": "1 AP",
			"desc": "凭绝对优势要求敌方投降 (控制%.0f%%)" % (control_pct * 100.0),
			"available": has_ap,
		})

	return options


## Interrogate a captured hero (1 AP) — Rance 07 尋問 system
func action_interrogate_hero(hero_id: String) -> bool:
	var pid: int = get_human_player_id()
	var player: Dictionary = get_player_by_id(pid)
	if player.get("ap", 0) < 1:
		EventBus.message_log.emit("行動力不足!")
		return false

	if HeroSystem == null:
		EventBus.message_log.emit("[color=red]英雄系统未初始化![/color]")
		return false

	var result: Dictionary = HeroSystem.interrogate_hero(hero_id)
	if not result["ok"]:
		EventBus.message_log.emit(result["result"])
		return false

	player["ap"] -= 1

	# Apply rewards
	var rewards: Dictionary = result.get("rewards", {})
	var delta: Dictionary = {}
	for key in ["gold", "food", "iron", "prestige"]:
		if rewards.has(key):
			delta[key] = rewards[key]
	if not delta.is_empty():
		ResourceManager.apply_delta(pid, delta)

	# Special rewards
	if rewards.has("soldiers"):
		ResourceManager.add_army(pid, rewards["soldiers"])
		sync_player_army(pid)

	if rewards.has("reveal_tiles"):
		var hidden_tiles: Array = []
		for i in range(tiles.size()):
			if not tiles[i].get("revealed", {}).get(pid, false):
				hidden_tiles.append(i)
		hidden_tiles.shuffle()
		var reveal_count: int = mini(rewards["reveal_tiles"], hidden_tiles.size())
		for i in range(reveal_count):
			tiles[hidden_tiles[i]]["revealed"][pid] = true
		if reveal_count > 0:
			EventBus.message_log.emit("揭示了 %d 个未知区域!" % reveal_count)

	EventBus.ap_changed.emit(pid, player["ap"])
	return true


func action_explore(player_id: int, target_tile_index: int) -> bool:
	## Explore an owned tile. Can trigger events, find items, reveal fog. Costs 1 AP.
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		return false
	if target_tile_index < 0 or target_tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[target_tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能探索自己的领地!")
		return false

	player["ap"] -= 1
	_reveal_around(target_tile_index, player_id)

	# Random exploration outcomes (weighted)
	var roll: float = randf()
	if roll < 0.35:
		# Trigger an event
		_trigger_event(player, tile)
	elif roll < 0.55:
		# Find an item
		_give_random_item(player)
	elif roll < 0.70:
		# Find NPC
		var available_npcs: Array = NpcManager.get_available_npcs_for_faction(get_player_faction(player_id))
		if available_npcs.size() > 0:
			var npc_id: String = available_npcs[randi() % available_npcs.size()]
			if NpcManager.capture_npc(player_id, npc_id):
				EventBus.message_log.emit("探索中发现了特殊人物!")
			else:
				ResourceManager.apply_delta(player_id, {"gold": randi_range(10, 30)})
				EventBus.message_log.emit("探索获得少量金币")
		else:
			ResourceManager.apply_delta(player_id, {"gold": randi_range(10, 30)})
			EventBus.message_log.emit("探索获得少量金币")
	elif roll < 0.85:
		# Resource bonus
		var bonus_type: Array = ["gold", "food", "iron"]
		var chosen: String = bonus_type[randi() % bonus_type.size()]
		var amount: int = randi_range(5, 20)
		ResourceManager.apply_delta(player_id, {chosen: amount})
		EventBus.message_log.emit("探索发现资源: %s+%d" % [chosen, amount])
	else:
		# Nothing found
		EventBus.message_log.emit("探索无果，但扩展了视野")

	EventBus.player_arrived.emit(player_id, target_tile_index)
	return true


# ═══════════════ PROVINCE QUICK ACTIONS (v5.2) ═══════════════
## Central dispatcher for province_info_panel quick-action buttons.
## Connected to EventBus.action_requested in _ready().
func _on_action_requested(action: String, tile_index: int) -> void:
	var pid: int = get_human_player_id()
	match action:
		"recruit":
			if has_method("open_recruit_panel"):
				open_recruit_panel(tile_index)
		"domestic":
			if has_method("open_domestic_panel"):
				open_domestic_panel(tile_index)
		"explore":
			action_explore(pid, tile_index)
		"guard":
			action_guard_territory(pid, tile_index)
		"ritual":
			action_ritual(pid, tile_index)
		"excavate":
			action_excavate(pid, tile_index)
		"block_supply":
			action_block_supply(pid, tile_index)
		"fortify":
			action_fortify(pid, tile_index)
		"exploit":
			action_exploit(pid, tile_index)
		"train_elite":
			action_train_elite(pid, tile_index)
		"upgrade_outpost":
			action_upgrade_outpost(pid, tile_index)
		"upgrade_facility":
			action_upgrade_facility(pid, tile_index)
		"upgrade_walls":
			action_upgrade_walls(pid, tile_index)
		"build_market":
			action_build_market(pid, tile_index)
		"research":
			if has_method("open_research_panel"):
				open_research_panel()
		"diplomacy":
			action_diplomacy(pid, -1)
		_:
			EventBus.message_log.emit("[color=yellow]未知行动: %s[/color]" % action)


## 举行仪式：消耗魔晶获得暗影精华和秩序加成。适用于法术居点。消耗 1 AP。
func action_ritual(player_id: int, tile_index: int) -> bool:
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能在自己的领地举行仪式!")
		return false
	player["ap"] -= 1
	# 消耗魔晶换取暗影精华和秩序
	var has_crystal: bool = ResourceManager.get_resource(player_id, "magic_crystal") >= 1
	if has_crystal:
		ResourceManager.apply_delta(player_id, {"magic_crystal": -1, "shadow_essence": 2})
		OrderManager.change_order(3)
		EventBus.message_log.emit("[color=orchid][仪式] 消耗 1 魔晶，获得 +2 暗影精华，秩序+3。[/color]")
	else:
		# 无魔晶时仅获得少量秩序加成
		OrderManager.change_order(2)
		EventBus.message_log.emit("[color=orchid][仪式] 秩序+2。（魔晶不足，暗影精华产出减少）[/color]")
	# 25% 概率触发随机事件
	if randf() < 0.25:
		_trigger_event(player, tile)
	return true


## 发掘运址：对古迹居点进行考古发掘，获得资源或遗物。消耗 1 AP。
func action_excavate(player_id: int, tile_index: int) -> bool:
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能在自己的领地发掘!")
		return false
	player["ap"] -= 1
	_reveal_around(tile_index, player_id)
	var roll: float = randf()
	if roll < 0.20:
		# 发现遗物
		_give_random_item(player)
		EventBus.message_log.emit("[color=gold][发掘] 发现古代遗物![/color]")
	elif roll < 0.50:
		# 发现鐵矿和金币
		var iron_amt: int = randi_range(15, 35)
		var gold_amt: int = randi_range(10, 25)
		ResourceManager.apply_delta(player_id, {"iron": iron_amt, "gold": gold_amt})
		EventBus.message_log.emit("[color=gold][发掘] 发现古代宝藏：铁+%d，金币+%d[/color]" % [iron_amt, gold_amt])
	elif roll < 0.70:
		# 触发事件
		_trigger_event(player, tile)
		EventBus.message_log.emit("[发掘] 发现了某种古代遗迹…")
	else:
		# 无收获
		EventBus.message_log.emit("[发掘] 没有发现任何有价値的东西。")
	return true


## 封锁补给：封锁指定居点的补给线，降低敌方的簮食产出并提升威望。消耗 1 AP。
func action_block_supply(player_id: int, tile_index: int) -> bool:
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能封锁自己领地的补给线!")
		return false
	player["ap"] -= 1
	# 封锁补给：降低附近敌方簮食产出，提升威望
	var nearby_enemies: int = 0
	for neighbor_idx in _get_neighbors(tile_index):
		if neighbor_idx >= 0 and neighbor_idx < tiles.size():
			var ntile: Dictionary = tiles[neighbor_idx]
			if ntile["owner_id"] != player_id and ntile["owner_id"] >= 0:
				nearby_enemies += 1
	if nearby_enemies > 0:
		# 对每个相邻敌方居点施加簮食减少
		for eid in range(players.size()):
			var ep: Dictionary = players[eid]
			if ep.get("is_ai", true) and ep["id"] != player_id:
				ResourceManager.apply_delta(ep["id"], {"food": -nearby_enemies * 3})
		ThreatManager.change_threat(nearby_enemies * 2)
		EventBus.message_log.emit("[color=cyan][封锁补给] 封锁%d个敌方居点的补给线，敌方簮食共减少%d。[/color]" % [nearby_enemies, nearby_enemies * 3])
	else:
		EventBus.message_log.emit("[封锁补给] 附近没有敌方居点可以封锁。")
	return true


## 加固防线：对前线居点进行工事加固，提升城防并降低威胁。消耗 1 AP。
func action_fortify(player_id: int, tile_index: int) -> bool:
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能加固自己的领地!")
		return false
	player["ap"] -= 1
	var wall_boost: int = 10
	var current_wall: int = tile.get("wall_hp", 0)
	tile["wall_hp"] = current_wall + wall_boost
	ThreatManager.change_threat(-2)
	var tile_name: String = tile.get("name", TILE_NAMES.get(tile["type"], "领地"))
	EventBus.message_log.emit("[color=cyan][加固] %s 城防+%d，威胁-2。[/color]" % [tile_name, wall_boost])
	return true


## 开采资源：对资源居点加大开采力度，获得额外资源。消耗 1 AP。
func action_exploit(player_id: int, tile_index: int) -> bool:
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能开采自己的领地!")
		return false
	player["ap"] -= 1
	# 根据居点类型决定开采资源类型
	var tile_type: int = tile.get("type", 0)
	var resource_type: String = "gold"
	var amount: int = randi_range(15, 30)
	match tile_type:
		3: # 矿山
			resource_type = "iron"
			amount = randi_range(20, 40)
		4: # 農田
			resource_type = "food"
			amount = randi_range(20, 40)
		_:
			resource_type = "gold"
			amount = randi_range(15, 30)
	ResourceManager.apply_delta(player_id, {resource_type: amount})
	EventBus.message_log.emit("[color=yellow][开采] %s+%d[/color]" % [resource_type, amount])
	return true


## 训练精锐：对居点内的部队进行精锐训练，提升战斗力。消耗 1 AP。
func action_train_elite(player_id: int, tile_index: int) -> bool:
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能训练自己领地的部队!")
		return false
	player["ap"] -= 1
	# 训练精锐：消耗簮食获得临时战斗加成
	var food_cost: int = 10
	var has_food: bool = ResourceManager.get_resource(player_id, "food") >= food_cost
	if has_food:
		ResourceManager.apply_delta(player_id, {"food": -food_cost})
		# 添加临时 buff
		if BuffManager != null and BuffManager.has_method("add_buff"):
			BuffManager.add_buff(player_id, "elite_training", "atk_pct", 15, 2, "train_elite")
		EventBus.message_log.emit("[color=lime][精锐训练] 消耗簮食%d，全军 ATK+15%% 持续 2 回合。[/color]" % food_cost)
	else:
		EventBus.message_log.emit("[精锐训练] 簮食不足，无法训练。")
		player["ap"] += 1  # 退还 AP
		return false
	return true


## 升级前哨：对前哨居点进行升级改造，提升偵查范围和防御。消耗 1 AP。
func action_upgrade_outpost(player_id: int, tile_index: int) -> bool:
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能升级自己的前哨!")
		return false
	player["ap"] -= 1
	var iron_cost: int = 20
	var has_iron: bool = ResourceManager.get_resource(player_id, "iron") >= iron_cost
	if has_iron:
		ResourceManager.apply_delta(player_id, {"iron": -iron_cost})
		var current_level: int = tile.get("outpost_level", 0)
		tile["outpost_level"] = mini(current_level + 1, 3)
		_reveal_around(tile_index, player_id)  # 升级后扩大视野
		EventBus.message_log.emit("[color=cyan][升级前哨] 消耗铁矿%d，前哨升级至 Lv%d，视野扩大。[/color]" % [iron_cost, tile["outpost_level"]])
	else:
		EventBus.message_log.emit("[升级前哨] 铁矿不足（需要 %d）。" % iron_cost)
		player["ap"] += 1
		return false
	return true


## 升级设施：对工业/资源居点升级生产设施，提升资源产出。消耗 1 AP。
func action_upgrade_facility(player_id: int, tile_index: int) -> bool:
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能升级自己的设施!")
		return false
	player["ap"] -= 1
	var gold_cost: int = 30
	var has_gold: bool = ResourceManager.get_resource(player_id, "gold") >= gold_cost
	if has_gold:
		ResourceManager.apply_delta(player_id, {"gold": -gold_cost})
		var current_level: int = tile.get("facility_level", 0)
		tile["facility_level"] = mini(current_level + 1, 3)
		EventBus.message_log.emit("[color=yellow][升级设施] 消耗金币%d，设施升级至 Lv%d，资源产出提升。[/color]" % [gold_cost, tile["facility_level"]])
	else:
		EventBus.message_log.emit("[升级设施] 金币不足（需要 %d）。" % gold_cost)
		player["ap"] += 1
		return false
	return true


## 升级城墙：对城堡居点建造更堆实的防御工事。消耗 1 AP。
func action_upgrade_walls(player_id: int, tile_index: int) -> bool:
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能升级自己的城墙!")
		return false
	player["ap"] -= 1
	var iron_cost: int = 25
	var has_iron: bool = ResourceManager.get_resource(player_id, "iron") >= iron_cost
	if has_iron:
		ResourceManager.apply_delta(player_id, {"iron": -iron_cost})
		var wall_boost: int = 20
		tile["wall_hp"] = tile.get("wall_hp", 0) + wall_boost
		var tile_name: String = tile.get("name", TILE_NAMES.get(tile["type"], "领地"))
		EventBus.message_log.emit("[color=cyan][升级城墙] %s 城防+%d。[/color]" % [tile_name, wall_boost])
	else:
		EventBus.message_log.emit("[升级城墙] 铁矿不足（需要 %d）。" % iron_cost)
		player["ap"] += 1
		return false
	return true


## 建造市场：在城镇居点建造市场，提升金币收入。消耗 1 AP。
func action_build_market(player_id: int, tile_index: int) -> bool:
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or player["ap"] < 1:
		EventBus.message_log.emit("行动点不足!")
		return false
	if tile_index < 0 or tile_index >= tiles.size():
		return false
	var tile: Dictionary = tiles[tile_index]
	if tile["owner_id"] != player_id:
		EventBus.message_log.emit("只能在自己的领地建造市场!")
		return false
	player["ap"] -= 1
	var gold_cost: int = 40
	var has_gold: bool = ResourceManager.get_resource(player_id, "gold") >= gold_cost
	if has_gold:
		ResourceManager.apply_delta(player_id, {"gold": -gold_cost})
		# 建造市场：每回合额外获得金币
		tile["market_built"] = true
		var tile_name: String = tile.get("name", TILE_NAMES.get(tile["type"], "领地"))
		EventBus.message_log.emit("[color=yellow][建造市场] %s 市场建造完成，每回合额外获得 +5 金币。[/color]" % tile_name)
		EventBus.building_constructed.emit(player_id, tile_index, "market")
	else:
		EventBus.message_log.emit("[建造市场] 金币不足（需要 %d）。" % gold_cost)
		player["ap"] += 1
		return false
	return true


# ═══════════════ WIN CONDITION ═══════════════

func _record_battle_stat(player_id: int, won: bool) -> void:
	if player_id == get_human_player_id():
		if won:
			game_stats["battles_won"] = game_stats.get("battles_won", 0) + 1
		else:
			game_stats["battles_lost"] = game_stats.get("battles_lost", 0) + 1


func _compute_end_game_score(player_id: int, victory_type: String) -> Dictionary:
	## Compute detailed score breakdown for the end-game screen.
	var owned: int = count_tiles_owned(player_id)
	var heroes: int = HeroSystem.recruited_heroes.size() if HeroSystem != null else 0
	var b_won: int = game_stats.get("battles_won", 0)
	var b_lost: int = game_stats.get("battles_lost", 0)
	var turns: int = turn_number

	var territory_score: int = owned * BalanceConfig.SCORE_PER_NODE
	var hero_score: int = heroes * BalanceConfig.SCORE_PER_HERO
	var battle_score: int = b_won * BalanceConfig.SCORE_PER_BATTLE_WON + b_lost * BalanceConfig.SCORE_PER_BATTLE_LOST
	var turn_score: int = maxi(0, (BalanceConfig.TURN_LIMIT - turns)) * BalanceConfig.SCORE_PER_TURN if BalanceConfig.TURN_LIMIT > 0 else turns * BalanceConfig.SCORE_PER_TURN
	var subtotal: int = maxi(0, territory_score + hero_score + battle_score + turn_score)
	var multiplier: float = BalanceConfig.VICTORY_SCORE_MULTIPLIER.get(victory_type, 1.0)
	var final_score: int = int(float(subtotal) * multiplier)

	return {
		"territory_score": territory_score,
		"hero_score": hero_score,
		"battle_score": battle_score,
		"turn_score": turn_score,
		"subtotal": subtotal,
		"multiplier": multiplier,
		"final_score": final_score,
		"territories_owned": owned,
		"territories_total": tiles.size(),
		"heroes_recruited": heroes,
		"battles_won": b_won,
		"battles_lost": b_lost,
		"turns_taken": turns,
		"victory_type": victory_type,
	}


func check_win_condition() -> void:
	if not game_active:
		return

	var human_id: int = get_human_player_id()
	var human_faction: int = _player_factions.get(human_id, -1)
	var human_tiles: int = count_tiles_owned(human_id)

	# ── Defeat: Capital Lost ──
	if BalanceConfig.CAPITAL_LOSS_DEFEAT and game_stats.get("capital_tile", -1) >= 0:
		var cap_idx: int = game_stats["capital_tile"]
		if cap_idx < tiles.size() and tiles[cap_idx]["owner_id"] != human_id:
			game_active = false
			EventBus.message_log.emit("[color=red]═══ 首都沦陷! ═══[/color]")
			EventBus.message_log.emit("[color=red]你的首都已被敌军攻占, 暗潮势力土崩瓦解![/color]")
			var score_data: Dictionary = _compute_end_game_score(human_id, "Defeat")
			EventBus.game_over.emit(-1)
			EventBus.game_over_detailed.emit({"winner_id": -1, "is_victory": false, "reason": "Capital Lost", "victory_type": "", "score": score_data})
			return

	# ── Defeat: Turn Limit Exceeded (ターン制限) ──
	if BalanceConfig.TURN_LIMIT > 0 and turn_number > BalanceConfig.TURN_LIMIT:
		game_active = false
		EventBus.message_log.emit("[color=red]═══ 回合超限! ═══[/color]")
		EventBus.message_log.emit("[color=red]暗潮势力未能在%d回合内完成目标, 光明联盟集结反攻![/color]" % BalanceConfig.TURN_LIMIT)
		var score_data: Dictionary = _compute_end_game_score(human_id, "Defeat")
		EventBus.game_over.emit(-1)
		EventBus.game_over_detailed.emit({"winner_id": -1, "is_victory": false, "reason": "Turn Limit Exceeded", "victory_type": "", "score": score_data})
		return

	# ── Defeat: All Armies Lost ──
	var has_any_army: bool = false
	for army_id in armies:
		if armies[army_id]["player_id"] == human_id:
			has_any_army = true
			break
	if human_tiles > 0 and not has_any_army:
		# Only trigger if no garrison remains either (avoid false trigger at game start)
		var has_garrison: bool = false
		for tile in tiles:
			# BUG FIX R13: null check on tile
			if tile == null:
				continue
			if tile["owner_id"] == human_id and tile.get("garrison", 0) > 0:
				has_garrison = true
				break
		if not has_garrison:
			game_active = false
			EventBus.message_log.emit("[color=red]═══ 全军覆没! ═══[/color]")
			EventBus.message_log.emit("[color=red]所有军队已被消灭, 无力再战![/color]")
			var score_data: Dictionary = _compute_end_game_score(human_id, "Defeat")
			EventBus.game_over.emit(-1)
			EventBus.game_over_detailed.emit({"winner_id": -1, "is_victory": false, "reason": "All armies destroyed", "victory_type": "", "score": score_data})
			return

	# ── Victory Path 1: Conquest (攻占所有光明联盟要塞) ──
	var total_sh: int = 0
	var human_sh: int = 0
	for tile in tiles:
		# BUG FIX R13: null check on tile
		if tile == null:
			continue
		if tile["type"] == TileType.LIGHT_STRONGHOLD or tile["type"] == TileType.CORE_FORTRESS:
			total_sh += 1
			if tile["owner_id"] == human_id:
				human_sh += 1

	if total_sh > 0 and human_sh >= total_sh:
		game_active = false
		EventBus.message_log.emit("[color=gold]═══ 征服胜利! ═══[/color]")
		EventBus.message_log.emit("[color=gold]所有光明联盟要塞已被攻占! 暗潮统治大陆![/color]")
		# Speed clear bonus
		if BalanceConfig.TURN_LIMIT > 0:
			var turns_saved: int = maxi(0, BalanceConfig.TURN_LIMIT - turn_number)
			var speed_bonus: int = turns_saved * BalanceConfig.SPEED_CLEAR_BONUS_PER_TURN
			if speed_bonus > 0:
				ResourceManager.apply_delta(human_id, {"prestige": speed_bonus})
				EventBus.message_log.emit("[color=gold]速通奖励: %d回合完成 (节省%d回合), +%d威望![/color]" % [turn_number, turns_saved, speed_bonus])
		NgPlusManager.on_victory()
		var score_data: Dictionary = _compute_end_game_score(human_id, "Conquest Victory")
		EventBus.game_over.emit(human_id)
		EventBus.game_over_detailed.emit({"winner_id": human_id, "is_victory": true, "reason": "", "victory_type": "Conquest Victory", "score": score_data})
		return

	# ── Victory Path 2: Domination (控制75%以上地图节点) ──
	var total_tiles: int = tiles.size()
	var domination_threshold: float = BalanceConfig.DOMINANCE_VICTORY_PCT
	if total_tiles > 0 and float(human_tiles) / float(total_tiles) >= domination_threshold:
		game_active = false
		EventBus.message_log.emit("[color=gold]═══ 支配胜利! ═══[/color]")
		EventBus.message_log.emit("[color=gold]控制了 %d/%d 个节点 (%.0f%%), 无人可以抵挡暗潮![/color]" % [
			human_tiles, total_tiles, float(human_tiles) / float(total_tiles) * 100.0])
		# Speed clear bonus
		if BalanceConfig.TURN_LIMIT > 0:
			var turns_saved: int = maxi(0, BalanceConfig.TURN_LIMIT - turn_number)
			var speed_bonus: int = turns_saved * BalanceConfig.SPEED_CLEAR_BONUS_PER_TURN
			if speed_bonus > 0:
				ResourceManager.apply_delta(human_id, {"prestige": speed_bonus})
				EventBus.message_log.emit("[color=gold]速通奖励: %d回合完成 (节省%d回合), +%d威望![/color]" % [turn_number, turns_saved, speed_bonus])
		NgPlusManager.on_victory()
		var score_data: Dictionary = _compute_end_game_score(human_id, "Domination Victory")
		EventBus.game_over.emit(human_id)
		EventBus.game_over_detailed.emit({"winner_id": human_id, "is_victory": true, "reason": "", "victory_type": "Domination Victory", "score": score_data})
		return

	# ── Victory Path 3: Shadow Dominion (暗影统治 — 威胁值100 + 拥有终极兵种) ──
	var threat: int = ThreatManager.get_threat()
	var has_ultimate: bool = false
	for army_id in armies:
		var army: Dictionary = armies[army_id]
		if army["player_id"] != human_id:
			continue
		for troop in army["troops"]:
			var tid: String = troop.get("troop_id", "")
			if tid in ["beast_ultimate", "leviathan_ultimate", "shadow_dragon_ultimate"]:
				has_ultimate = true
				break
			# Also check GameData for ultimate category
			if GameData.TROOP_TYPES.has(tid):
				var td: Dictionary = GameData.TROOP_TYPES[tid]
				if td.get("category", -1) == GameData.TroopCategory.ULTIMATE:
					has_ultimate = true
					break
		if has_ultimate:
			break

	if threat >= 100 and has_ultimate:
		game_active = false
		EventBus.message_log.emit("[color=purple]═══ 暗影统治! ═══[/color]")
		EventBus.message_log.emit("[color=purple]威胁值达到极限, 终极兵器已觉醒! 大陆在暗潮中沉沦![/color]")
		# Speed clear bonus
		if BalanceConfig.TURN_LIMIT > 0:
			var turns_saved: int = maxi(0, BalanceConfig.TURN_LIMIT - turn_number)
			var speed_bonus: int = turns_saved * BalanceConfig.SPEED_CLEAR_BONUS_PER_TURN
			if speed_bonus > 0:
				ResourceManager.apply_delta(human_id, {"prestige": speed_bonus})
				EventBus.message_log.emit("[color=gold]速通奖励: %d回合完成 (节省%d回合), +%d威望![/color]" % [turn_number, turns_saved, speed_bonus])
		NgPlusManager.on_victory()
		var score_data: Dictionary = _compute_end_game_score(human_id, "Shadow Domination")
		EventBus.game_over.emit(human_id)
		EventBus.game_over_detailed.emit({"winner_id": human_id, "is_victory": true, "reason": "", "victory_type": "Shadow Domination", "score": score_data})
		return

	# ── Victory Path 4: Pirate Harem Collection (海盗后宫收集胜利) ──
	if human_faction == FactionData.FactionID.PIRATE and HeroSystem != null and HeroSystem.check_harem_victory():
		game_active = false
		EventBus.message_log.emit("[color=pink]═══ 后宫胜利! ═══[/color]")
		EventBus.message_log.emit("[color=pink]所有角色都已臣服于你的魅力! 海盗王的后宫建立完成![/color]")
		EventBus.message_log.emit("[color=pink]大陆上每一位女性都将成为你的收藏...[/color]")
		# Speed clear bonus
		if BalanceConfig.TURN_LIMIT > 0:
			var turns_saved: int = maxi(0, BalanceConfig.TURN_LIMIT - turn_number)
			var speed_bonus: int = turns_saved * BalanceConfig.SPEED_CLEAR_BONUS_PER_TURN
			if speed_bonus > 0:
				ResourceManager.apply_delta(human_id, {"prestige": speed_bonus})
				EventBus.message_log.emit("[color=gold]速通奖励: %d回合完成 (节省%d回合), +%d威望![/color]" % [turn_number, turns_saved, speed_bonus])
		NgPlusManager.on_victory()
		var score_data: Dictionary = _compute_end_game_score(human_id, "Harem Victory")
		EventBus.game_over.emit(human_id)
		EventBus.game_over_detailed.emit({"winner_id": human_id, "is_victory": true, "reason": "", "victory_type": "Harem Victory", "score": score_data})
		return

	# ── Victory Path 5: Diplomatic Victory (与所有存活势力结盟) ──
	var surviving_rivals: Array = []
	for idx in range(players.size()):
		var pid: int = players[idx]["id"]
		if pid == human_id:
			continue
		if count_tiles_owned(pid) > 0:
			surviving_rivals.append(pid)
	if surviving_rivals.size() > 0:
		var all_allied: bool = true
		for rival_pid in surviving_rivals:
			var rival_faction: int = _player_factions.get(rival_pid, -1)
			if not DiplomacyManager.has_treaty(human_id, "alliance", rival_faction):
				all_allied = false
				break
		if all_allied:
			game_active = false
			EventBus.message_log.emit("[color=cyan]═══ 外交胜利! ═══[/color]")
			EventBus.message_log.emit("[color=cyan]所有存活势力已与你缔结同盟! 暗潮联邦统一大陆![/color]")
			NgPlusManager.on_victory()
			var score_data: Dictionary = _compute_end_game_score(human_id, "Diplomatic Victory")
			EventBus.game_over.emit(human_id)
			EventBus.game_over_detailed.emit({"winner_id": human_id, "is_victory": true, "reason": "", "victory_type": "Diplomatic Victory", "score": score_data})
			return

	# ── Victory Path 6: Survival Victory (存活N回合且首都未失) ──
	if BalanceConfig.SURVIVAL_TURN_GOAL > 0 and turn_number >= BalanceConfig.SURVIVAL_TURN_GOAL:
		var cap_idx: int = game_stats.get("capital_tile", -1)
		var capital_held: bool = cap_idx >= 0 and cap_idx < tiles.size() and tiles[cap_idx]["owner_id"] == human_id
		if capital_held:
			game_active = false
			EventBus.message_log.emit("[color=green]═══ 生存胜利! ═══[/color]")
			EventBus.message_log.emit("[color=green]在%d回合的漫长战争中屹立不倒! 首都固若金汤![/color]" % turn_number)
			NgPlusManager.on_victory()
			var score_data: Dictionary = _compute_end_game_score(human_id, "Survival Victory")
			EventBus.game_over.emit(human_id)
			EventBus.game_over_detailed.emit({"winner_id": human_id, "is_victory": true, "reason": "", "victory_type": "Survival Victory", "score": score_data})
			return

	# ── Defeat: Elimination ──
	if human_tiles <= 0:
		game_active = false
		EventBus.message_log.emit("[color=red]你的势力已被消灭...[/color]")
		var score_data: Dictionary = _compute_end_game_score(human_id, "Defeat")
		EventBus.game_over.emit(-1)
		EventBus.game_over_detailed.emit({"winner_id": -1, "is_victory": false, "reason": "Your faction was eliminated", "victory_type": "", "score": score_data})
		return

	# ── Defeat: All evil factions eliminated (rival AI wins) ──
	# Only trigger if the human player also has no path to victory
	# (i.e., the human is the last dark faction standing is handled by elimination above)
	var all_rivals_dead: bool = true
	for pid in range(1, players.size()):
		if pid == human_id:
			continue
		if count_tiles_owned(pid) > 0:
			all_rivals_dead = false
			break
	if all_rivals_dead and human_tiles <= 0:
		game_active = false
		EventBus.message_log.emit("[color=red]所有暗黑势力已被光明联盟消灭...[/color]")
		var score_data: Dictionary = _compute_end_game_score(human_id, "Defeat")
		EventBus.game_over.emit(-1)
		EventBus.game_over_detailed.emit({"winner_id": -1, "is_victory": false, "reason": "All dark factions were destroyed", "victory_type": "", "score": score_data})


# ═══════════════ TERRITORY EFFECTS (国効果) ═══════════════

func _evaluate_territory_effects(pid: int) -> Dictionary:
	var result: Dictionary = {}
	var active_effects: Array = []
	var owned: Array = get_cached_owned_tiles(pid)

	# Count tiles by type
	var type_counts: Dictionary = {}
	for tidx in owned:
		var ttype: int = tiles[tidx]["type"]
		type_counts[ttype] = type_counts.get(ttype, 0) + 1

	for effect_id in BalanceConfig.TERRITORY_EFFECTS:
		var eff: Dictionary = BalanceConfig.TERRITORY_EFFECTS[effect_id]
		var qualifies: bool = false
		var multiplier: int = 1

		if eff.get("per_tile", false):
			# Per-tile effect (e.g., core fortress: each one adds bonus)
			if effect_id == "core_fortress_control":
				var count: int = type_counts.get(TileType.CORE_FORTRESS, 0)
				if count > 0:
					qualifies = true
					multiplier = count
		elif eff.has("required_type"):
			var req_count: int = eff["required_count"]
			var actual: int = type_counts.get(eff["required_type"], 0)
			if actual >= req_count:
				qualifies = true

		if qualifies:
			active_effects.append(effect_id)
			var effects: Dictionary = eff["effect"]
			for key in effects:
				if key.ends_with("_pct"):
					result[key] = result.get(key, 0.0) + float(effects[key]) * multiplier
				elif effects[key] is bool:
					result[key] = true
				else:
					result[key] = result.get(key, 0) + int(effects[key]) * multiplier

	result["_active_ids"] = active_effects

	# ── Fixed map mode: merge per-territory special effects from TerritoryEffectsData ──
	if use_fixed_map:
		var owned_tiles: Array = get_cached_owned_tiles(pid) if owned.is_empty() else owned
		for tidx in owned_tiles:
			var te: Dictionary = TerritoryEffectsData.TERRITORY_SPECIAL_EFFECTS.get(tidx, {})
			if te.is_empty() or (te.get("requires_control", false) and tiles[tidx].get("owner_id", -1) != pid):
				continue
			var mods: Dictionary = te.get("modifiers", {})
			for key in mods:
				if mods[key] is float:
					result[key] = result.get(key, 0.0) + mods[key]
				elif mods[key] is int:
					result[key] = result.get(key, 0) + mods[key]
				elif mods[key] is bool:
					result[key] = true
			active_effects.append(te.get("effect_id", "territory_%d" % tidx))
		# Merge nation bonuses
		if nation_system != null:
			var nation_effects: Dictionary = nation_system.get_combined_effects(pid)
			for key in nation_effects:
				if nation_effects[key] is float:
					result[key] = result.get(key, 0.0) + nation_effects[key]
				elif nation_effects[key] is int:
					result[key] = result.get(key, 0) + nation_effects[key]
				elif nation_effects[key] is bool:
					result[key] = true

	return result


# ═══════════════ AI ═══════════════

func run_ai_turn() -> void:
	var player: Dictionary = players[current_player_index]
	if not player["is_ai"] or not game_active:
		return
	var pid: int = player["id"]
	var _fk: String = _get_faction_key(pid)
	var _total_phases: int = 6  # Phases 0-5 in generic AI

	EventBus.message_log.emit("%s 正在行动..." % player["name"])
	EventBus.ai_thinking.emit(_fk, true)
	EventBus.ai_turn_progress.emit(_fk, 0, _total_phases)

	# Orc AI: use aggressive WAAAGH-driven strategy instead of generic AI
	var faction_id: int = get_player_faction(pid)
	if faction_id == FactionData.FactionID.ORC:
		await _run_orc_ai(pid)
		return

	while player["ap"] > 0 and game_active:
		await get_tree().create_timer(0.4).timeout
		if not game_active:
			return

		var did_action: bool = false

		# ── Phase 0: Create army if we have none but own tiles ──
		var ai_armies: Array = get_player_armies(pid)
		if ai_armies.is_empty():
			var owned_tiles: Array = get_domestic_tiles(pid)
			if not owned_tiles.is_empty():
				var best_tile: int = owned_tiles[0]["index"]
				# Prefer core fortress or stronghold
				for ot in owned_tiles:
					if ot["type"] == TileType.CORE_FORTRESS or ot["type"] == TileType.DARK_BASE:
						best_tile = ot["index"]
						break
				var new_id: int = create_army(pid, best_tile, player["name"] + "軍")
				if new_id > 0:
					ai_armies = get_player_armies(pid)

		# ── Phase 0.5: Strategic tactical assessment ──
		var _ai_faction_key: String = ""
		match faction_id:
			FactionData.FactionID.ORC: _ai_faction_key = "orc_ai"
			FactionData.FactionID.PIRATE: _ai_faction_key = "pirate_ai"
			FactionData.FactionID.DARK_ELF: _ai_faction_key = "dark_elf_ai"
		var _tactical_plan: Dictionary = {}
		if _ai_faction_key != "":
			_tactical_plan = AIStrategicPlanner.get_tactical_plan(_ai_faction_key)
			var _plan_type: String = _tactical_plan.get("type", "normal")
			# Execute concentration before attacks
			if _plan_type == "concentration":
				AIStrategicPlanner.execute_concentration(_ai_faction_key)
			# Execute retreats before attacks
			if _plan_type == "retreat":
				for _rt_idx in _tactical_plan.get("tiles", []):
					AIStrategicPlanner.execute_retreat(_ai_faction_key, _rt_idx)

		# ── Phase 1: Attack with armies (prioritize high-value targets) ──
		EventBus.ai_action_started.emit(_fk, "attack", "Evaluating targets")
		for army in ai_armies:
			if player["ap"] <= 0:
				break
			var attackable: Array = get_army_attackable_tiles(army["id"])
			if attackable.is_empty():
				continue
			var army_power: int = get_army_combat_power(army["id"])
			if army_power < 3:
				continue
			# Score all targets
			var best_tile_idx: int = -1
			var best_score: float = -999.0
			for nb_idx in attackable:
				var score: float = _ai_score_attack(player, tiles[nb_idx], army)
				if score > best_score:
					best_score = score
					best_tile_idx = nb_idx
			if best_score > 0.0 and best_tile_idx >= 0:
				# Siege-aware: check if target is fortified before attacking
				var _skip_attack: bool = false
				if SiegeSystem.is_tile_fortified(best_tile_idx):
					# If another army already sieging, deploy to support instead
					if SiegeSystem.is_tile_under_siege(best_tile_idx):
						var existing_siege: Dictionary = SiegeSystem.get_siege_at_tile(best_tile_idx)
						if existing_siege.get("attacker_player_id", -1) == pid:
							_skip_attack = true  # Our siege, don't start another
					else:
						# Evaluate siege cost — only start if worth it
						var siege_info: Dictionary = AIStrategicPlanner.evaluate_siege_cost(best_tile_idx)
						if not siege_info.get("worth_sieging", true):
							# Check commitment level
							var commitments: Dictionary = AIStrategicPlanner.get_active_commitments("")
							if commitments.get("overcommitted", false):
								_skip_attack = true  # Too many sieges already
				if not _skip_attack:
					await action_attack_with_army(army["id"], best_tile_idx)
					EventBus.ai_action_completed.emit(_fk, "attack", true)
					ai_armies = get_player_armies(pid)  # Refresh after combat
					did_action = true
					break  # Re-evaluate after attack

		if did_action:
			continue

		EventBus.ai_action_completed.emit(_fk, "attack", false)
		EventBus.ai_turn_progress.emit(_fk, 1, _total_phases)

		# ── Phase 2: Deploy armies toward frontlines ──
		EventBus.ai_action_started.emit(_fk, "deploy", "Moving armies to front")
		ai_armies = get_player_armies(pid)  # Refresh after possible combat
		for army in ai_armies:
			if player["ap"] <= 0:
				break
			var attackable: Array = get_army_attackable_tiles(army["id"])
			if not attackable.is_empty():
				continue  # Already on frontline
			var deployable: Array = get_army_deployable_tiles(army["id"])
			if deployable.is_empty():
				continue
			# Score deploy targets: prefer tiles adjacent to enemies, especially weak ones
			var best_deploy: int = -1
			var best_deploy_score: float = -1.0
			for dtile in deployable:
				var dscore: float = 0.0
				if adjacency.has(dtile):
					for nb in adjacency[dtile]:
						if nb < tiles.size() and tiles[nb]["owner_id"] >= 0 and tiles[nb]["owner_id"] != pid:
							dscore += 3.0  # Adjacent to enemy
							if tiles[nb].get("garrison", 0) < 5:
								dscore += 2.0  # Weak garrison
						elif nb < tiles.size() and tiles[nb]["owner_id"] < 0:
							dscore += 0.5  # Adjacent to neutral
				if dscore > best_deploy_score:
					best_deploy_score = dscore
					best_deploy = dtile
			if best_deploy >= 0:
				action_deploy_army(army["id"], best_deploy)
				EventBus.ai_action_completed.emit(_fk, "deploy", true)
				did_action = true
				break

		if did_action:
			continue

		EventBus.ai_action_completed.emit(_fk, "deploy", false)
		EventBus.ai_turn_progress.emit(_fk, 2, _total_phases)

		# ── Phase 3: Recruit troops if under capacity ──
		EventBus.ai_action_started.emit(_fk, "recruit", "Recruiting troops")
		var owned_tiles: Array = get_domestic_tiles(pid)
		if owned_tiles.size() > 0:
			faction_id = get_player_faction(pid)
			var params: Dictionary = FactionData.FACTION_PARAMS.get(faction_id, {})
			var recruit_gold: int = params.get("recruit_cost_gold", 50)
			var recruit_iron: int = params.get("recruit_cost_iron", 10)
			if ResourceManager.can_afford(pid, {"gold": recruit_gold, "iron": recruit_iron}):
				# Recruit at the tile where an army is stationed (or first owned tile)
				var recruit_tile: int = owned_tiles[0]["index"]
				for army in ai_armies:
					if army["troops"].size() < MAX_TROOPS_PER_ARMY:
						recruit_tile = army["tile_index"]
						break
				action_domestic(pid, recruit_tile, "recruit")
				EventBus.ai_action_completed.emit(_fk, "recruit", true)
				continue

		EventBus.ai_turn_progress.emit(_fk, 3, _total_phases)

		# ── Phase 4: Create additional armies if possible ──
		EventBus.ai_action_started.emit(_fk, "create_army", "Creating armies")
		if ai_armies.size() < MAX_ARMIES_BASE and owned_tiles.size() > 1:
			# Create new army on a tile without an army that's near the front
			for ot in owned_tiles:
				var existing: Dictionary = get_army_at_tile(ot["index"])
				if not existing.is_empty():
					continue
				# Check if near front
				if adjacency.has(ot["index"]):
					for nb in adjacency[ot["index"]]:
						if nb < tiles.size() and tiles[nb]["owner_id"] != pid:
							var new_id: int = create_army(pid, ot["index"], player["name"] + "第%d軍" % (ai_armies.size() + 1))
							if new_id > 0:
								did_action = true
							break
				if did_action:
					break
			if did_action:
				continue

		EventBus.ai_action_completed.emit(_fk, "create_army", false)
		EventBus.ai_turn_progress.emit(_fk, 4, _total_phases)

		# ── Phase 4b: Guard border tiles (30% chance if border tile has low garrison) ──
		EventBus.ai_action_started.emit(_fk, "guard", "Guarding borders")
		if not owned_tiles.is_empty() and randf() < 0.30:
			for ot in owned_tiles:
				if _guard_timers.has(ot["index"]):
					continue  # Already guarded
				if not adjacency.has(ot["index"]):
					continue
				var is_border: bool = false
				for nb in adjacency[ot["index"]]:
					if nb < tiles.size() and tiles[nb]["owner_id"] >= 0 and tiles[nb]["owner_id"] != pid:
						is_border = true
						break
				if is_border and ot.get("garrison", 0) < 8:
					action_guard_territory(pid, ot["index"])
					EventBus.ai_action_completed.emit(_fk, "guard", true)
					did_action = true
					break
			if did_action:
				continue

		# ── Phase 4c: Diplomacy with non-hostile factions (10% chance) ──
		EventBus.ai_action_started.emit(_fk, "diplomacy", "Diplomatic negotiations")
		if randf() < 0.10:
			var evil_factions: Array = [FactionData.FactionID.ORC, FactionData.FactionID.PIRATE, FactionData.FactionID.DARK_ELF]
			var my_faction: int = get_player_faction(pid)
			for fid in evil_factions:
				if fid == my_faction:
					continue
				var rel: Dictionary = DiplomacyManager.get_all_relations(pid).get(fid, {})
				if rel.get("recruited", false) or rel.get("hostile", false):
					continue
				# AI tries tribute to improve relations (if affordable)
				if ResourceManager.can_afford(pid, {"gold": 80}):
					action_diplomacy(pid, fid, "tribute")
					EventBus.ai_action_completed.emit(_fk, "diplomacy", true)
					did_action = true
					break
			if did_action:
				continue

		EventBus.ai_turn_progress.emit(_fk, 5, _total_phases)

		# ── Phase 5: Explore for resources/events ──
		EventBus.ai_action_started.emit(_fk, "explore", "Exploring territory")
		if not owned_tiles.is_empty():
			var explore_tile: Dictionary = owned_tiles[randi() % owned_tiles.size()]
			action_explore(pid, explore_tile["index"])
			EventBus.ai_action_completed.emit(_fk, "explore", true)
			continue

		# No valid action, break
		break

	# ── Siege management phase: process existing AI sieges ──
	_ai_manage_sieges(pid)

	EventBus.ai_turn_progress.emit(_fk, _total_phases, _total_phases)
	EventBus.ai_thinking.emit(_fk, false)

	await get_tree().create_timer(0.3).timeout
	if game_active:
		end_turn()


func _ai_manage_sieges(player_id: int) -> void:
	## AI siege management: for each active siege, decide storm / continue / lift.
	var sieges: Array = SiegeSystem.get_player_sieges(player_id)
	for siege in sieges:
		var siege_id: String = siege.get("siege_id", "")
		if siege_id == "":
			continue
		var wall_hp: float = siege.get("wall_hp", 100.0)
		var defender_morale: float = siege.get("defender_morale", 100.0)
		var army_id: int = siege.get("attacker_army_id", -1)

		# Calculate army health percentage
		var army_health_pct: float = _get_army_health_pct(army_id)

		# Storm if: wall_hp < 20 OR defender_morale < 20
		if wall_hp < 20.0 or defender_morale < 20.0:
			SiegeSystem.storm_walls(siege_id)
			EventBus.message_log.emit("[AI] 发起强攻! (墙HP:%.0f 士气:%.0f)" % [wall_hp, defender_morale])
			continue

		# Lift if: army health < 40%
		if army_health_pct < 0.4:
			SiegeSystem.lift_siege(siege_id)
			EventBus.message_log.emit("[AI] 撤围 — 军队损耗过大 (%.0f%%)" % (army_health_pct * 100.0))
			continue

		# Continue otherwise — do nothing, siege progresses naturally


func _get_army_health_pct(army_id: int) -> float:
	## Returns army health as 0.0-1.0 based on soldiers / max_soldiers.
	if not armies.has(army_id):
		return 0.0
	var army: Dictionary = armies[army_id]
	var total_soldiers: int = 0
	var total_max: int = 0
	for troop in army.get("troops", []):
		total_soldiers += troop.get("soldiers", 0)
		total_max += troop.get("max_soldiers", troop.get("soldiers", 0))
	if total_max <= 0:
		return 0.0
	return float(total_soldiers) / float(total_max)


func _ai_score_attack(player: Dictionary, tile: Dictionary, army: Dictionary = {}) -> float:
	var score: float = 0.0
	match tile["type"]:
		TileType.LIGHT_STRONGHOLD: score += 10.0
		TileType.CORE_FORTRESS: score += 12.0
		TileType.LIGHT_VILLAGE: score += 5.0
		TileType.RESOURCE_STATION: score += 6.0
		TileType.NEUTRAL_BASE: score += 4.0
		TileType.MINE_TILE, TileType.FARM_TILE: score += 3.0
		TileType.HARBOR, TileType.TRADING_POST: score += 4.0
		TileType.CHOKEPOINT: score += 7.0
		_: score += 1.0

	# Consider army strength vs garrison
	var army_power: float = 0.0
	if not army.is_empty():
		army_power = float(get_army_combat_power(army["id"]))
	else:
		army_power = float(player.get("combat_power", 0))

	var def_power: float = float(tile.get("garrison", 0)) * 8.0
	if def_power > army_power * 1.2:
		score -= 15.0  # Way too strong, avoid
	elif def_power > army_power * 0.8:
		score -= 8.0
	elif def_power > army_power * 0.5:
		score -= 3.0
	elif def_power < army_power * 0.3:
		score += 3.0  # Easy target bonus

	# Bonus for tiles that would connect territory
	var pid: int = player["id"]
	var tile_idx: int = tile.get("index", -1)
	if tile_idx >= 0 and adjacency.has(tile_idx):
		var friendly_neighbors: int = 0
		for nb in adjacency[tile_idx]:
			if nb < tiles.size() and tiles[nb]["owner_id"] == pid:
				friendly_neighbors += 1
		score += friendly_neighbors * 1.5  # Connecting territory is valuable

	# Chokepoint strategic awareness
	if tile.get("is_chokepoint", false):
		# Inflate perceived defense at chokepoints
		def_power *= 1.3
		# Add strategic value bonus
		score += get_chokepoint_strategic_value(tile_idx) * 0.5
		# If on contested border, even more valuable
		if tile["owner_id"] != pid and tile["owner_id"] >= 0:
			score += 2.0

	# ── Siege-aware scoring ──
	if SiegeSystem.is_tile_fortified(tile_idx):
		var siege_info: Dictionary = AIStrategicPlanner.evaluate_siege_cost(tile_idx)
		var siege_turns: int = siege_info.get("siege_turns", 0)
		score -= float(siege_turns) * 4.0  # Penalty for time cost
		# If army is weak, extra penalty for attrition
		if army_power < def_power * 0.8:
			score -= 10.0  # Can't sustain attrition
		# If ally already sieging this tile, bonus for joining
		if SiegeSystem.is_tile_under_siege(tile_idx):
			var existing_siege: Dictionary = SiegeSystem.get_siege_at_tile(tile_idx)
			if existing_siege.get("attacker_player_id", -1) != pid:
				score += 8.0  # Join existing ally siege
		# If supply-cutting value is high, still attack (strategic override)
		var supply_score: float = AIStrategicPlanner.score_supply_cut_attack("", tile_idx)
		if supply_score > 15.0:
			score += supply_score * 0.5  # Strategic value overrides fortress penalty

	return score


# ═══════════════════════════════════════════════════════════════════════════════
# Orc AI: Aggressive WAAAGH-driven strategy
# ═══════════════════════════════════════════════════════════════════════════════

func _run_orc_ai(player_id: int) -> void:
	## Orc AI: aggressive WAAAGH-driven strategy.
	## Prioritises constant warfare over defense; quantity over quality.
	var player: Dictionary = get_player_by_id(player_id)
	if player.is_empty() or not game_active:
		return

	var _fk: String = _get_faction_key(player_id)
	var _total_phases: int = 7  # Phases 0-6 in orc AI

	EventBus.ai_thinking.emit(_fk, true)
	EventBus.ai_turn_progress.emit(_fk, 0, _total_phases)

	var waaagh: int = OrcMechanic.get_waaagh(player_id)
	var in_frenzy: bool = OrcMechanic.is_in_frenzy(player_id)

	# ── Phase 0: Create army if we have none ──
	var ai_armies: Array = get_player_armies(player_id)
	if ai_armies.is_empty():
		var owned: Array = get_domestic_tiles(player_id)
		if not owned.is_empty():
			var best_tile: int = owned[0]["index"]
			for ot in owned:
				if ot["type"] == TileType.CORE_FORTRESS or ot["type"] == TileType.DARK_BASE:
					best_tile = ot["index"]
					break
			create_army(player_id, best_tile, player["name"] + "WAAAGH軍")
			ai_armies = get_player_armies(player_id)

	# ── Main action loop ──
	var idle_count: int = 0
	while player["ap"] > 0 and game_active:
		await get_tree().create_timer(0.35).timeout
		if not game_active:
			return

		# Refresh state each iteration
		waaagh = OrcMechanic.get_waaagh(player_id)
		in_frenzy = OrcMechanic.is_in_frenzy(player_id)
		ai_armies = get_player_armies(player_id)
		var did_action: bool = false

		# ── Phase 0.5: Orc tactical intelligence ──
		# Orcs prefer concentration (WAAAGH buildup), rarely use feint (20%)
		if not in_frenzy:
			var orc_plan: Dictionary = AIStrategicPlanner.get_tactical_plan("orc_ai")
			var orc_plan_type: String = orc_plan.get("type", "normal")
			if orc_plan_type == "concentration":
				AIStrategicPlanner.execute_concentration("orc_ai")
			elif orc_plan_type == "retreat":
				for orc_rt_idx in orc_plan.get("tiles", []):
					AIStrategicPlanner.execute_retreat("orc_ai", orc_rt_idx)

		# ── Phase 1: AGGRESSIVE ATTACKS (primary behavior) ──
		EventBus.ai_action_started.emit(_fk, "attack", "WAAAGH! Attacking")
		# Orc aggression threshold based on WAAAGH: higher WAAAGH = attack even bad odds
		var aggression_threshold: float = 0.0
		if waaagh < 30:
			aggression_threshold = -5.0  # Desperate for WAAAGH, attack anything
		elif waaagh >= 60:
			aggression_threshold = 5.0   # High WAAAGH, confident strikes
		if in_frenzy:
			aggression_threshold = 10.0  # Frenzy: attack everything

		for army in ai_armies:
			if player["ap"] <= 0:
				break
			var attackable: Array = get_army_attackable_tiles(army["id"])
			if attackable.is_empty():
				continue
			# Orcs attack even with low combat power (unlike generic AI which needs >= 3)
			var army_power: int = get_army_combat_power(army["id"])
			if army_power < 1:
				continue

			# Score each target with orc-specific logic
			var best_tile_idx: int = -1
			var best_score: float = aggression_threshold
			for nb_idx in attackable:
				var score: float = _orc_score_attack(army, tiles[nb_idx], waaagh, in_frenzy)
				if score > best_score:
					best_score = score
					best_tile_idx = nb_idx

			if best_tile_idx >= 0:
				# Siege-aware: Orcs check fortifications (but are more tolerant)
				var _orc_skip: bool = false
				if SiegeSystem.is_tile_fortified(best_tile_idx) and not in_frenzy:
					if SiegeSystem.is_tile_under_siege(best_tile_idx):
						var existing_siege: Dictionary = SiegeSystem.get_siege_at_tile(best_tile_idx)
						if existing_siege.get("attacker_player_id", -1) == player_id:
							_orc_skip = true  # Already our siege
					else:
						var siege_info: Dictionary = AIStrategicPlanner.evaluate_siege_cost(best_tile_idx)
						if not siege_info.get("worth_sieging", true):
							_orc_skip = true
				if not _orc_skip:
					await action_attack_with_army(army["id"], best_tile_idx)
					EventBus.ai_action_completed.emit(_fk, "attack", true)
					ai_armies = get_player_armies(player_id)  # Refresh after combat
					did_action = true
					break  # Re-evaluate after attack

		if did_action:
			continue

		EventBus.ai_action_completed.emit(_fk, "attack", false)
		EventBus.ai_turn_progress.emit(_fk, 1, _total_phases)

		# ── Phase 2: Deploy armies toward enemy territory (offensive positions) ──
		EventBus.ai_action_started.emit(_fk, "deploy", "Repositioning forces")
		ai_armies = get_player_armies(player_id)
		for army in ai_armies:
			if player["ap"] <= 0:
				break
			# Skip armies already on the front line
			var attackable: Array = get_army_attackable_tiles(army["id"])
			if not attackable.is_empty():
				continue
			var deployable: Array = get_army_deployable_tiles(army["id"])
			if deployable.is_empty():
				continue
			# Orc deploy: pick tile closest to enemies, prefer hostile over neutral
			var best_deploy: int = -1
			var best_deploy_score: float = -1.0
			for dtile in deployable:
				var dscore: float = 0.0
				if adjacency.has(dtile):
					for nb in adjacency[dtile]:
						if nb < tiles.size() and tiles[nb]["owner_id"] >= 0 and tiles[nb]["owner_id"] != player_id:
							dscore += 5.0  # Adjacent to enemy player
							if tiles[nb].get("garrison", 0) < 5:
								dscore += 3.0  # Weak garrison = juicy target
						elif nb < tiles.size() and tiles[nb]["owner_id"] < 0:
							dscore += 3.0  # Adjacent to neutral (more aggressive than generic)
				if dscore > best_deploy_score:
					best_deploy_score = dscore
					best_deploy = dtile
			if best_deploy >= 0:
				action_deploy_army(army["id"], best_deploy)
				EventBus.ai_action_completed.emit(_fk, "deploy", true)
				did_action = true
				break

		if did_action:
			continue

		EventBus.ai_action_completed.emit(_fk, "deploy", false)
		EventBus.ai_turn_progress.emit(_fk, 2, _total_phases)

		# ── Phase 3: Create additional armies (quantity over quality) ──
		EventBus.ai_action_started.emit(_fk, "create_army", "Raising new WAAAGH!")
		ai_armies = get_player_armies(player_id)
		var owned_tiles: Array = get_domestic_tiles(player_id)
		if ai_armies.size() < get_max_armies(player_id) and owned_tiles.size() > 0:
			# Prefer frontier tiles for army creation
			var created: bool = false
			var best_spawn: int = -1
			var best_spawn_score: float = 0.0
			for ot in owned_tiles:
				var existing: Dictionary = get_army_at_tile(ot["index"])
				if not existing.is_empty():
					continue
				var sscore: float = 0.0
				if adjacency.has(ot["index"]):
					for nb in adjacency[ot["index"]]:
						if nb < tiles.size() and tiles[nb]["owner_id"] != player_id:
							sscore += 3.0
				if sscore > best_spawn_score:
					best_spawn_score = sscore
					best_spawn = ot["index"]
			if best_spawn >= 0:
				var new_id: int = create_army(player_id, best_spawn, player["name"] + "第%d WAAAGH!" % (ai_armies.size() + 1))
				if new_id > 0:
					did_action = true
			if did_action:
				continue

		EventBus.ai_action_completed.emit(_fk, "create_army", false)
		EventBus.ai_turn_progress.emit(_fk, 3, _total_phases)

		# ── Phase 4: Recruit troops - prefer cheap units to fill armies fast ──
		EventBus.ai_action_started.emit(_fk, "recruit", "Recruiting horde")
		if not owned_tiles.is_empty():
			var recruited: bool = false
			for army in ai_armies:
				if player["ap"] <= 0:
					break
				if army["troops"].size() >= MAX_TROOPS_PER_ARMY:
					continue
				var recruit_tile: Dictionary = _get_tile_dict(army["tile_index"])
				if recruit_tile.is_empty() or recruit_tile["owner_id"] != player_id:
					# Army not on owned tile, use first owned tile instead
					recruit_tile = owned_tiles[0]
				var available: Array = RecruitManager.get_available_units(player_id, recruit_tile)
				if available.is_empty():
					continue
				# Sort by gold cost ascending - Orcs want cheap hordes
				var cheapest: Dictionary = available[0]
				for u in available:
					if u.get("cost", {}).get("gold", 9999) < cheapest.get("cost", {}).get("gold", 9999):
						cheapest = u
				# Use action_domestic recruit to spend AP and resources properly
				if ResourceManager.can_afford(player_id, cheapest.get("cost", {})):
					action_domestic(player_id, recruit_tile["index"], "recruit")
					EventBus.ai_action_completed.emit(_fk, "recruit", true)
					recruited = true
					break
			if recruited:
				continue

		EventBus.ai_turn_progress.emit(_fk, 4, _total_phases)

		# ── Phase 5: Convert slaves to army (Orc war pit) ──
		EventBus.ai_action_started.emit(_fk, "convert_slaves", "Converting slaves")
		if ResourceManager.get_slaves(player_id) > 0:
			OrcMechanic.convert_slave_to_army(player_id)
			EventBus.ai_action_completed.emit(_fk, "convert_slaves", true)
			# BUG FIX R10: Slave conversion doesn't cost AP - limit to 3 conversions
			# per turn to avoid infinite loop, then fall through to explore/break.
			idle_count += 1
			if idle_count > 3:
				idle_count = 0  # Reset so subsequent AP actions aren't blocked
				pass  # Fall through to Phase 6 (explore) or break
			else:
				continue

		EventBus.ai_turn_progress.emit(_fk, 5, _total_phases)

		# ── Phase 6: Explore only if nothing else to do (Orcs dislike idle turns) ──
		EventBus.ai_action_started.emit(_fk, "explore", "Exploring territory")
		if not owned_tiles.is_empty():
			var explore_tile: Dictionary = owned_tiles[randi() % owned_tiles.size()]
			action_explore(player_id, explore_tile["index"])
			EventBus.ai_action_completed.emit(_fk, "explore", true)
			continue

		# No valid action, break
		break

	# ── Siege management phase for Orc AI ──
	_ai_manage_sieges(player_id)

	EventBus.ai_turn_progress.emit(_fk, _total_phases, _total_phases)
	EventBus.ai_thinking.emit(_fk, false)

	await get_tree().create_timer(0.3).timeout
	if game_active:
		end_turn()


func _orc_score_attack(army: Dictionary, tile: Dictionary, waaagh: int, in_frenzy: bool) -> float:
	## Orc-specific attack scoring. More aggressive than generic _ai_score_attack.
	## Prefers weak targets, bonuses for high WAAAGH, strategic value, and desperation.
	var score: float = 0.0

	# Base tile value (same priorities but boosted)
	match tile["type"]:
		TileType.CORE_FORTRESS: score += 15.0  # Orcs love capturing fortresses
		TileType.LIGHT_STRONGHOLD: score += 12.0
		TileType.CHOKEPOINT: score += 8.0
		TileType.RESOURCE_STATION: score += 6.0
		TileType.LIGHT_VILLAGE: score += 5.0
		TileType.NEUTRAL_BASE: score += 4.0
		TileType.HARBOR, TileType.TRADING_POST: score += 4.0
		TileType.MINE_TILE, TileType.FARM_TILE: score += 3.0
		_: score += 2.0

	# Army strength vs garrison - Orcs tolerate worse odds
	var army_power: float = float(get_army_combat_power(army["id"]))
	var def_power: float = float(tile.get("garrison", 0)) * 8.0
	if def_power > army_power * 1.5:
		score -= 10.0  # Even Orcs avoid suicidal attacks (but threshold is higher)
	elif def_power > army_power * 1.0:
		score -= 4.0   # Unfavorable but Orcs don't mind
	elif def_power > army_power * 0.5:
		score -= 1.0
	elif def_power < army_power * 0.3:
		score += 5.0   # Easy prey - Orcs love stomping the weak

	# WAAAGH aggression bonus: more WAAAGH = more reckless
	score += float(waaagh) * 0.15

	# Frenzy bonus: massive aggression boost during frenzy (1.5x damage active)
	if in_frenzy:
		score += 8.0

	# Desperate for WAAAGH: if low, attack anything to generate combat WAAAGH
	if waaagh < 30:
		score += 8.0

	# Territory connection bonus
	var tile_idx: int = tile.get("index", -1)
	if tile_idx >= 0 and adjacency.has(tile_idx):
		var friendly_neighbors: int = 0
		for nb in adjacency[tile_idx]:
			if nb < tiles.size() and tiles[nb]["owner_id"] == army["player_id"]:
				friendly_neighbors += 1
		score += friendly_neighbors * 1.0  # Less weight than generic AI (Orcs don't care about clean borders)

	# ── Siege-aware scoring for Orc AI ──
	if tile_idx >= 0 and SiegeSystem.is_tile_fortified(tile_idx):
		var siege_info: Dictionary = AIStrategicPlanner.evaluate_siege_cost(tile_idx)
		var siege_turns: int = siege_info.get("siege_turns", 0)
		# Orcs penalize fortifications less than generic AI (they're reckless)
		score -= float(siege_turns) * 2.0
		# But even Orcs respect strong walls when weak
		if army_power < def_power * 0.6:
			score -= 6.0
		# Ally already sieging? Join the WAAAGH!
		if SiegeSystem.is_tile_under_siege(tile_idx):
			score += 6.0
		# Frenzy overrides caution
		if in_frenzy:
			score += 5.0

	return score


func _get_tile_dict(tile_index: int) -> Dictionary:
	## Returns tile dictionary by index, or empty dict if invalid.
	if tile_index >= 0 and tile_index < tiles.size():
		return tiles[tile_index]
	return {}


# ═══════════════ RANDOM EVENT POPUP (Human Player Choice UI) ═══════════════

func _show_random_event_popup(player: Dictionary, event: Dictionary) -> void:
	## Format and display a random event via EventPopup for the human player.
	if not _pending_choice_event.is_empty():
		# Another event popup is active — queue this one
		_pending_event_queue.append({"event": event, "player": player})
		return

	_pending_choice_event = event
	_pending_choice_player = player

	var title: String = event.get("name", "未知事件")
	var desc: String = event.get("desc", "")
	var choices: Array = _format_event_choices(event)
	EventBus.show_event_popup.emit(title, desc, choices)


func _format_event_choices(event: Dictionary) -> Array:
	## Convert event choice data into EventPopup-compatible array format.
	## Handles both "choices" array format and "option_a"/"option_b" format.
	if event.has("choices") and event["choices"] is Array and event["choices"].size() > 0:
		var result: Array = []
		for c in event["choices"]:
			if c is Dictionary:
				result.append({"text": c.get("text", "选择")})
			else:
				result.append({"text": str(c)})
		return result

	# Fallback: option_a / option_b format
	var result: Array = []
	if event.has("option_a"):
		var oa: Dictionary = event["option_a"]
		result.append({"text": oa.get("label", "选项A")})
	if event.has("option_b"):
		var ob: Dictionary = event["option_b"]
		result.append({"text": ob.get("label", "选项B")})

	if result.is_empty():
		result.append({"text": "确认"})
	return result


func _on_random_event_choice(choice_index: int) -> void:
	## Callback when the human player selects a choice in the EventPopup.
	if _pending_choice_event.is_empty():
		return  # Not our event (might be conquest/world event)

	var event: Dictionary = _pending_choice_event
	var player: Dictionary = _pending_choice_player
	_pending_choice_event = {}
	_pending_choice_player = {}

	# Map choice index to "a"/"b" or apply via event_system
	if event.has("choices") and event["choices"] is Array:
		# Use event_system's apply_choice
		var event_id = event.get("id", "")
		if str(event_id) != "" and EventSystem:
			EventSystem.apply_choice(event_id, choice_index)
	else:
		# option_a / option_b format
		var choice_key: String = "a" if choice_index == 0 else "b"
		_apply_choice_event(player, event, choice_key)

	# Process queued events
	if not _pending_event_queue.is_empty():
		var next: Dictionary = _pending_event_queue.pop_front()
		call_deferred("_show_random_event_popup", next["player"], next["event"])


# ═══════════════ EVENTSCHEDULER UNIFIED QUEUE (SR07 sequential display) ═══════════════

func _queue_scheduler_event(event_data: Dictionary) -> void:
	## Add an event selected by EventScheduler to the unified display queue.
	_scheduler_event_queue.append(event_data)


func _process_scheduler_event_queue() -> void:
	## Show events from the scheduler queue one-by-one sequentially.
	## Each event popup is shown after the previous one is closed.
	if _scheduler_event_queue.is_empty():
		return
	var evt: Dictionary = _scheduler_event_queue.pop_front()
	var title: String = evt.get("name", evt.get("title", "事件"))
	var desc: String = evt.get("description", evt.get("desc", ""))
	var choices: Array = evt.get("choices", [])

	# Format choices for popup compatibility
	var formatted_choices: Array = []
	for c in choices:
		if c is Dictionary:
			formatted_choices.append(c)
		elif c is String:
			formatted_choices.append({"text": c})
		else:
			formatted_choices.append({"text": str(c)})

	if formatted_choices.is_empty():
		formatted_choices.append({"text": "确认"})

	# Route through the existing _show_random_event_popup for choice handling
	# if the event has original data (id, choices with effects) from event_system
	if evt.has("id") and evt.has("choices") and evt["choices"] is Array:
		var first_choice = evt["choices"][0] if evt["choices"].size() > 0 else null
		if first_choice is Dictionary and first_choice.has("effects"):
			# This is a full event dict from event_system — use existing choice handler
			var player_for_event: Dictionary = get_player_by_id(get_human_player_id())
			_show_random_event_popup(player_for_event, evt)
			return

	# For events that don't need choice effect handling (pure display events),
	# emit the popup directly
	EventBus.show_event_popup.emit(title, desc, formatted_choices)

	# Connect to event_choice_selected to show the next queued event
	if not _scheduler_queue_connected and not _scheduler_event_queue.is_empty():
		_scheduler_queue_connected = true
		EventBus.event_choice_selected.connect(_on_scheduler_event_choice, CONNECT_ONE_SHOT)


func _on_scheduler_event_choice(_choice_index: int) -> void:
	## Callback to process the next event in the scheduler queue after a popup closes.
	_scheduler_queue_connected = false
	if not _scheduler_event_queue.is_empty():
		call_deferred("_process_scheduler_event_queue")


# ═══════════════ MISSING METHOD STUBS (v5.3 audit) ═══════════════
## Called by province_info_panel fallback — delegates to action_explore.
func execute_explore(tile_index: int) -> void:
	action_explore(get_human_player_id(), tile_index)

## Called by province_info_panel fallback — opens recruit UI for a tile.
func open_recruit_panel(tile_index: int) -> void:
	## Delegate to the HUD's domestic recruit flow, pre-selecting the given tile.
	var pid: int = get_human_player_id()
	if tile_index < 0 or tile_index >= tiles.size():
		EventBus.message_log.emit("[color=red]无效地块，无法打开征兵面板[/color]")
		return
	if tiles[tile_index].get("owner_id", -1) != pid:
		EventBus.message_log.emit("[color=red]只能在己方领地征兵![/color]")
		return
	# Signal the HUD to open the recruit panel for this tile.
	# The HUD listens on EventBus.open_recruit_panel_requested.
	if EventBus.has_signal("open_recruit_panel_requested"):
		EventBus.open_recruit_panel_requested.emit(tile_index)
	else:
		EventBus.message_log.emit("[color=cyan]征兵面板 → 据点 #%d[/color]" % tile_index)

## Called by province_info_panel fallback — opens domestic management UI.
func open_domestic_panel(tile_index: int) -> void:
	EventBus.message_log.emit("[color=cyan]内政面板 → 据点 #%d[/color]" % tile_index)

## Called by province_info_panel — opens research UI.
func open_research_panel() -> void:
	EventBus.message_log.emit("[color=cyan]研究面板已打开[/color]")

## Called by grand_event_director — returns all faction dictionaries.
func get_all_factions() -> Array:
	return players.duplicate()

## Called by espionage_system — returns current turn number.
func get_current_turn() -> int:
	return current_turn if "current_turn" in self else turn_number if "turn_number" in self else 0

## Called by event_system — returns espionage level for a player.
func get_espionage_level(player_id: int) -> int:
	var p: Dictionary = get_player_by_id(player_id)
	return p.get("espionage_level", 0)

## Called by intel_overlay — returns faction display name.
func get_faction_name(faction_id: int) -> String:
	var p: Dictionary = get_player_by_id(faction_id)
	return p.get("name", "未知势力")

## Called by faction_destruction_events — returns tiles owned by a player.
func get_player_tiles(player_id: int) -> Array:
	var result: Array = []
	for i in range(tiles.size()):
		if tiles[i].get("owner_id", -1) == player_id:
			result.append(i)
	return result

## Called by intel_overlay — returns tile index at a screen position.
func get_tile_at_position(screen_pos: Vector2) -> int:
	# Delegate to board if available
	if BoardManager != null and BoardManager.has_method("get_tile_at_position"):
		return BoardManager.get_tile_at_position(screen_pos)
	return -1

## Called by intel_overlay — checks if a tile is visible to a player.
func is_tile_visible(player_id: int, tile_index: int) -> bool:
	if FogManager != null and FogManager.has_method("is_visible"):
		return FogManager.is_visible(player_id, tile_index)
	return true  # Default: all visible if no fog system
