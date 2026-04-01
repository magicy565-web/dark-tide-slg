## event_system.gd - Random event engine with 20 events and 2-choice system (v0.8.7)
## Hooks into GameManager turn loop. Handles DOT, combat, lose_node, reveal,
## immobile, temp_soldiers, debuff, gold_delayed, special_npc effects.
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")
const SideQuestData = preload("res://systems/quest/side_quest_data.gd")

# Event structure: { id, name, desc, condition, repeatable, choices: [{text, effects}] }
var _events := []
var _triggered_this_turn := []

# ── Deduplication: non-repeatable events fire at most once per game ──
var _triggered_ids: Dictionary = {}  # event_id -> true

# ── DOT (damage-over-time) active effects ──
# Array of { "resource_key": String, "delta": int, "remaining": int }
var _active_dots: Array = []

# ── Delayed gold grants (pirate shipwreck "标记" effect) ──
var _pending_gold: int = 0

# ── Immobile flag: set by events, cleared at start of next event phase ──
var _immobile_this_turn: bool = false

# ── Temporary soldiers granted by mercenaries (expire after 3 turns) ──
# Array of { "count": int, "remaining": int }
var _temp_soldier_batches: Array = []

# ── Pending event queue (events rolled, awaiting player choices) ──
var _pending_events: Array = []

# ── Event cooldowns (prevents same event firing too frequently) ──
var _event_cooldowns: Dictionary = {}  # event_id -> int (turns remaining)
const EVENT_COOLDOWN_TURNS: int = 5

# ── Event Chain System (v4.3): tracks choices for cascading follow-up events ──
# { parent_event_id: { "choice": int, "turn": int } }
var _event_chain_history: Dictionary = {}
# Pending chain events: [ { "event": Dictionary, "trigger_turn": int } ]
var _pending_chain_events: Array = []


func _ready() -> void:
	_register_events()
	register_world_events()
	if EventRegistry:
		EventRegistry._register_source("event_system", _events, "base")


func reset() -> void:
	_triggered_this_turn.clear()
	_triggered_ids.clear()
	_active_dots.clear()
	_pending_gold = 0
	_immobile_this_turn = false
	_temp_soldier_batches.clear()
	_pending_events.clear()
	_event_cooldowns.clear()
	_world_events.clear()
	_world_event_triggered_ids.clear()
	_event_chain_history.clear()
	_pending_chain_events.clear()
	_active_story_windows.clear()
	_story_window_notifications.clear()
	_active_crisis.clear()
	_invasion_tile = -1


# ═══════════════ EVENT REGISTRATION ═══════════════
# "repeatable": true means universal events that can fire every game.
# Non-repeatable (faction/threat events) fire at most once per game.

func _register_events() -> void:
	# === UNIVERSAL EVENTS (1-10) - repeatable ===
	_events.append({
		"id": "refugee_camp", "name": "流民营地",
		"desc": "发现一群无家可归的难民。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "奴役 (+3奴隶)", "effects": {"slaves": 3}},
			{"text": "屠杀 (+2兵力, 秩序-2)", "effects": {"soldiers": 2, "order": -2}},
		]
	})
	_events.append({
		"id": "abandoned_mine", "name": "废弃矿洞",
		"desc": "洞穴深处传来微光。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "探索 (60%+15铁, 40%损失2兵)", "effects": {"type": "gamble", "success_rate": 0.6, "success": {"iron": 15}, "fail": {"soldiers": -2}}},
			{"text": "放弃", "effects": {}},
		]
	})
	_events.append({
		"id": "plague", "name": "瘟疫蔓延",
		"desc": "领地内爆发疫病。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "隔离 (-3奴隶)", "effects": {"slaves": -3}},
			{"text": "不管 (-1兵/回合x3)", "effects": {"type": "dot", "soldiers": -1, "duration": 3}},
		]
	})
	_events.append({
		"id": "black_trader", "name": "黑商来访",
		"desc": "一位神秘商人提出交易。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "交易 (-50金, +随机道具)", "effects": {"gold": -50, "item": "random"}},
			{"text": "抢劫 (70%+80金, 30%损3兵)", "effects": {"type": "gamble", "success_rate": 0.7, "success": {"gold": 80}, "fail": {"soldiers": -3}}},
		]
	})
	_events.append({
		"id": "ancient_ruins", "name": "远古遗迹",
		"desc": "发现一座上古废墟。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "挖掘 (-5奴隶, +1遗物)", "effects": {"slaves": -5, "relic": true}},
			{"text": "炸毁 (+20铁+10金)", "effects": {"iron": 20, "gold": 10}},
		]
	})
	_events.append({
		"id": "rebel_remnant", "name": "叛军残部",
		"desc": "遭遇一支溃败的叛军。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "收编 (+3兵, 秩序-1)", "effects": {"soldiers": 3, "order": -1}},
			{"text": "消灭 (+2奴隶, 威望+3)", "effects": {"slaves": 2, "prestige": 3}},
		]
	})
	_events.append({
		"id": "blizzard", "name": "暴风雪",
		"desc": "极端天气席卷全图。",
		"condition": "turn_gte_5", "repeatable": true,
		"choices": [
			{"text": "固守 (本回合不可移动, -5粮)", "effects": {"food": -5, "immobile": true}},
			{"text": "强行军 (-2兵)", "effects": {"soldiers": -2}},
		]
	})
	_events.append({
		"id": "slave_treasure", "name": "奴隶献宝",
		"desc": "一名奴隶声称知道宝藏位置。",
		"condition": "has_slaves", "repeatable": true,
		"choices": [
			{"text": "信任 (70%+30金+10铁, 30%-1奴隶)", "effects": {"type": "gamble", "success_rate": 0.7, "success": {"gold": 30, "iron": 10}, "fail": {"slaves": -1}}},
			{"text": "无视", "effects": {}},
		]
	})
	_events.append({
		"id": "mercenaries", "name": "佣兵团",
		"desc": "一队佣兵愿意为金币而战。",
		"condition": "gold_gte_80", "repeatable": true,
		"choices": [
			{"text": "雇佣 (-80金, +5临时兵)", "effects": {"gold": -80, "temp_soldiers": 5}},
			{"text": "拒绝", "effects": {}},
		]
	})
	_events.append({
		"id": "blood_ritual", "name": "祭祀仪式",
		"desc": "部下要求举行血祭。",
		"condition": "has_slaves", "repeatable": true,
		"choices": [
			{"text": "允许 (-2奴隶, ATK+15% 3回合)", "effects": {"slaves": -2, "buff": {"type": "atk_pct", "value": 15, "duration": 3}}},
			{"text": "拒绝 (秩序-2)", "effects": {"order": -2}},
		]
	})

	# === FACTION EVENTS (11-16) - once per game ===
	_events.append({
		"id": "orc_infighting", "name": "内斗爆发",
		"desc": "两个头目争夺权力。",
		"condition": "faction_orc", "repeatable": false,
		"choices": [
			{"text": "决斗裁决 (-1兵, WAAAGH+15)", "effects": {"soldiers": -1, "waaagh": 15}},
			{"text": "镇压 (-3兵, 秩序+3)", "effects": {"soldiers": -3, "order": 3}},
		]
	})
	_events.append({
		"id": "orc_mushroom", "name": "蘑菇酒宴",
		"desc": "部落发现大量蘑菇酒。",
		"condition": "faction_orc", "repeatable": false,
		"choices": [
			{"text": "豪饮 (WAAAGH+20, 下回合不可动)", "effects": {"waaagh": 20, "immobile": true}},
			{"text": "储存 (+10粮)", "effects": {"food": 10}},
		]
	})
	_events.append({
		"id": "pirate_shipwreck", "name": "沉船宝藏",
		"desc": "发现一艘沉没的商船。",
		"condition": "faction_pirate", "repeatable": false,
		"choices": [
			{"text": "打捞 (-10铁, +60金+1道具)", "effects": {"iron": -10, "gold": 60, "item": "random"}},
			{"text": "标记 (下次+30金)", "effects": {"gold_delayed": 30}},
		]
	})
	_events.append({
		"id": "pirate_mutiny", "name": "船员哗变",
		"desc": "部分手下不满分赃。",
		"condition": "faction_pirate", "repeatable": false,
		"choices": [
			{"text": "让步 (-30金)", "effects": {"gold": -30}},
			{"text": "处决 (-2兵, 掠夺+5)", "effects": {"soldiers": -2, "plunder": 5}},
		]
	})
	_events.append({
		"id": "de_whisper", "name": "暗影低语",
		"desc": "奴隶中传出诡异耳语。",
		"condition": "faction_dark_elf", "repeatable": false,
		"choices": [
			{"text": "调查 (+1特殊NPC)", "effects": {"special_npc": true}},
			{"text": "处决传播者 (-2奴隶, 秩序+2)", "effects": {"slaves": -2, "order": 2}},
		]
	})
	_events.append({
		"id": "de_conspiracy", "name": "议会阴谋",
		"desc": "暗精灵内部有人密谋叛变。",
		"condition": "faction_dark_elf", "repeatable": false,
		"choices": [
			{"text": "先发制人 (-1奴隶, 揭示2迷雾)", "effects": {"slaves": -1, "reveal": 2}},
			{"text": "静观 (30%无事, 70%失1据点)", "effects": {"type": "gamble", "success_rate": 0.3, "success": {}, "fail": {"lose_node": true}}},
		]
	})

	# === NEW SYSTEM EVENTS (21-26) - repeatable, leverage morale/reputation/gifts/AI ===
	_events.append({
		"id": "morale_surge", "name": "士气高涨",
		"desc": "连胜的消息传遍领地，士兵们斗志昂扬。",
		"condition": "order_above_60", "repeatable": true,
		"choices": [
			{"text": "举行庆功宴 (-30金, 秩序+5)", "effects": {"gold": -30, "order": 5}},
			{"text": "趁势进军 (+3兵力)", "effects": {"soldiers": 3}},
		]
	})
	_events.append({
		"id": "reputation_crisis", "name": "声望危机",
		"desc": "你的残暴行径引起周边势力的恐惧与敌意。",
		"condition": "reputation_below_minus30", "repeatable": true,
		"choices": [
			{"text": "派遣使者修复关系 (-50金, 声望+15)", "effects": {"gold": -50, "reputation_all": 15}},
			{"text": "无视流言 (威胁+10)", "effects": {"threat": 10}},
		]
	})
	_events.append({
		"id": "foreign_caravan", "name": "异族商队",
		"desc": "一支来自远方的商队请求通行和贸易。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "友好贸易 (-20金, 声望+10, +随机道具)", "effects": {"gold": -20, "reputation_all": 10, "item": "random"}},
			{"text": "劫掠商队 (+80金, 声望-15)", "effects": {"gold": 80, "reputation_all": -15}},
		]
	})
	_events.append({
		"id": "deserters", "name": "叛逃士兵",
		"desc": "一群敌方逃兵请求庇护。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "收编 (+4兵力, 秩序-3)", "effects": {"soldiers": 4, "order": -3}},
			{"text": "拒绝 (秩序+2)", "effects": {"order": 2}},
		]
	})
	_events.append({
		"id": "hero_letter", "name": "英雄密信",
		"desc": "牢中的俘虏托人带来一封信。",
		"condition": "has_prisoners", "repeatable": true,
		"choices": [
			{"text": "接受请求 (腐化+2)", "effects": {"corruption_boost": 2}},
			{"text": "无视 (威望+2)", "effects": {"prestige": 2}},
		]
	})
	_events.append({
		"id": "storm", "name": "暴风雨来袭",
		"desc": "一场猛烈的风暴席卷领地。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "加固防御 (-20铁, 所有据点+5城防)", "effects": {"iron": -20, "wall_boost": 5}},
			{"text": "趁风突袭 (+5兵力, -10粮)", "effects": {"soldiers": 5, "food": -10}},
		]
	})

	# === LIGHT COUNTER EVENTS (17-20) - once per game ===
	_events.append({
		"id": "knight_patrol", "name": "女骑士巡逻",
		"desc": "人类女骑士率队突袭边境。",
		"condition": "threat_gte_30", "repeatable": false,
		"choices": [
			{"text": "迎战 (战斗: 敌8兵)", "effects": {"type": "combat", "enemy_soldiers": 8}},
			{"text": "撤退 (放弃边境据点)", "effects": {"lose_node": true}},
		]
	})
	_events.append({
		"id": "elf_curse", "name": "精灵诅咒",
		"desc": "精灵法师对领地施加诅咒。",
		"condition": "threat_gte_30", "repeatable": false,
		"choices": [
			{"text": "解咒 (-20金)", "effects": {"gold": -20}},
			{"text": "硬扛 (产出-20% 3回合)", "effects": {"debuff": {"type": "income_pct", "value": -20, "duration": 3}}},
		]
	})
	_events.append({
		"id": "arcane_storm", "name": "奥术风暴",
		"desc": "法师族释放区域魔法风暴。",
		"condition": "threat_gte_50", "repeatable": false,
		"choices": [
			{"text": "魔法防护 (-3魔晶)", "effects": {"magic_crystal": -3}},
			{"text": "硬抗 (-4兵全军)", "effects": {"soldiers": -4}},
		]
	})
	_events.append({
		"id": "holy_crusade", "name": "圣战号召",
		"desc": "三族联军发起十字军东征。",
		"condition": "threat_gte_80", "repeatable": false,
		"choices": [
			{"text": "全力迎战 (大型战斗)", "effects": {"type": "combat", "enemy_soldiers": 20}},
			{"text": "战略撤退 (放弃2据点, 威胁-10)", "effects": {"lose_nodes": 2, "threat": -10}},
		]
	})

	# ═══════════════ EVENT CHAINS (v4.3) ═══════════════
	# Chain events are follow-ups that trigger N turns after the parent event,
	# based on which choice the player made. This creates multi-turn narrative arcs.

	# Chain: plague → aftermath
	_events.append({
		"id": "plague_aftermath", "name": "瘟疫余波",
		"desc": "瘟疫过后，幸存者中出现了两种声音。",
		"condition": "chain:plague", "repeatable": false,
		"chain_parent": "plague",
		"choices": [
			{"text": "建设医馆 (-80金, 秩序+8, 该地块治安+20%)",
			 "effects": {"gold": -80, "order": 8}},
			{"text": "招募幸存者 (+5兵力, 但部队ATK-10% 3回合)",
			 "effects": {"soldiers": 5, "buff": {"type": "atk_pct", "value": -10, "duration": 3}}},
		]
	})

	# Chain: refugee_camp → integration
	_events.append({
		"id": "refugee_integration", "name": "难民安置",
		"desc": "之前收容的难民已在领地定居，他们提出了请求。",
		"condition": "chain:refugee_camp:0", "repeatable": false,
		"chain_parent": "refugee_camp", "chain_choice": 0,
		"choices": [
			{"text": "分配土地 (-30金, +8粮/回合x5)", "effects": {"gold": -30, "type": "dot", "food": 8, "duration": 5}},
			{"text": "编入劳役 (+5奴隶, 秩序-3)", "effects": {"slaves": 5, "order": -3}},
		]
	})

	# Chain: refugee_camp (chose kill) → haunting
	_events.append({
		"id": "refugee_haunting", "name": "冤魂作祟",
		"desc": "被屠杀的难民的怨念弥漫在领地上空。",
		"condition": "chain:refugee_camp:1", "repeatable": false,
		"chain_parent": "refugee_camp", "chain_choice": 1,
		"choices": [
			{"text": "举行祭祀安魂 (-3奴隶, 秩序+5)", "effects": {"slaves": -3, "order": 5}},
			{"text": "无视 (士气-10全军, 声望-10)", "effects": {"reputation_all": -10, "buff": {"type": "morale_pct", "value": -10, "duration": 3}}},
		]
	})

	# Chain: black_trader → return visit
	_events.append({
		"id": "trader_return", "name": "商人的回礼",
		"desc": "之前的神秘商人再次出现，这次带来了更珍贵的货物。",
		"condition": "chain:black_trader:0", "repeatable": false,
		"chain_parent": "black_trader", "chain_choice": 0,
		"choices": [
			{"text": "购买秘药 (-100金, 随机英雄永久ATK+2)", "effects": {"gold": -100, "hero_stat_boost": {"stat": "atk", "value": 2}}},
			{"text": "换取情报 (-60金, 揭示4格迷雾)", "effects": {"gold": -60, "reveal": 4}},
		]
	})

	# Chain: black_trader (chose rob) → revenge
	_events.append({
		"id": "trader_revenge", "name": "商人的复仇",
		"desc": "被抢劫的商人雇佣了一队佣兵前来报复。",
		"condition": "chain:black_trader:1", "repeatable": false,
		"chain_parent": "black_trader", "chain_choice": 1,
		"choices": [
			{"text": "迎战 (战斗: 敌10兵)", "effects": {"type": "combat", "enemy_soldiers": 10}},
			{"text": "赔偿 (-120金, 声望+5)", "effects": {"gold": -120, "reputation_all": 5}},
		]
	})

	# Chain: ancient_ruins (chose dig) → curse of the ancients
	_events.append({
		"id": "ruins_curse", "name": "远古诅咒",
		"desc": "挖掘遗迹释放了远古封印中的力量。",
		"condition": "chain:ancient_ruins:0", "repeatable": false,
		"chain_parent": "ancient_ruins", "chain_choice": 0,
		"choices": [
			{"text": "封印力量 (-3魔晶, 获得强力遗物)", "effects": {"magic_crystal": -3, "relic": true}},
			{"text": "吸收力量 (全军ATK+20% 5回合, 但秩序-8)", "effects": {"order": -8, "buff": {"type": "atk_pct", "value": 20, "duration": 5}}},
		]
	})

	# Chain: blood_ritual → divine retribution
	_events.append({
		"id": "ritual_retribution", "name": "神罚降临",
		"desc": "频繁的血祭引来了光明诸神的注意。",
		"condition": "chain:blood_ritual:0", "repeatable": false,
		"chain_parent": "blood_ritual", "chain_choice": 0,
		"choices": [
			{"text": "加强祭坛 (-5奴隶, +3暗影精华, 威胁+10)", "effects": {"slaves": -5, "shadow_essence": 3, "threat": 10}},
			{"text": "暂停祭祀 (秩序+5, 失去ATK增益)", "effects": {"order": 5}},
		]
	})

	# Chain: mercenaries → veteran mercenaries offer permanent contract
	_events.append({
		"id": "merc_contract", "name": "佣兵长约",
		"desc": "之前雇佣的佣兵队长对你产生了敬意，提出永久效力。",
		"condition": "chain:mercenaries:0", "repeatable": false,
		"chain_parent": "mercenaries", "chain_choice": 0,
		"choices": [
			{"text": "签约 (-200金, 永久+8精锐兵)", "effects": {"gold": -200, "soldiers": 8}},
			{"text": "拒绝但推荐 (+3威望, 声望+10)", "effects": {"prestige": 3, "reputation_all": 10}},
		]
	})


	# ═══════════════ REGION-SPECIFIC EVENTS (v5.0) ═══════════════
	# 15 new events tied to map regions for the expanded 90-110 tile map.

	# === Northern Wastes (5 events) — Orc territory ===
	_events.append({
		"id": "nw_orc_civil_war", "name": "兽人内战",
		"desc": "北方荒原上两支兽人氏族爆发了全面战争，战火蔓延至你的领地边境。",
		"condition": "faction_orc", "repeatable": false,
		"choices": [
			{"text": "支持强者 (-3兵, WAAAGH+25, 获得2奴隶)", "effects": {"soldiers": -3, "waaagh": 25, "slaves": 2}},
			{"text": "坐山观虎斗 (+15金, 威胁-5)", "effects": {"gold": 15, "threat": -5}},
		]
	})
	_events.append({
		"id": "nw_waaagh_surge", "name": "WAAAGH!浪潮",
		"desc": "北方荒原的兽人部落发出战争呐喊，WAAAGH!能量如潮水般涌来。",
		"condition": "faction_orc", "repeatable": true,
		"choices": [
			{"text": "顺势狂暴 (WAAAGH+30, 全军ATK+15% 3回合, 秩序-5)", "effects": {"waaagh": 30, "order": -5, "buff": {"type": "atk_pct", "value": 15, "duration": 3}}},
			{"text": "引导能量 (WAAAGH+15, +2暗影精华)", "effects": {"waaagh": 15, "shadow_essence": 2}},
		]
	})
	_events.append({
		"id": "nw_frozen_supplies", "name": "冰封补给",
		"desc": "北方荒原的极寒冻结了一批运输中的补给物资。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "派兵挖掘 (-2兵, +20粮+15铁)", "effects": {"soldiers": -2, "food": 20, "iron": 15}},
			{"text": "放弃补给", "effects": {}},
		]
	})
	_events.append({
		"id": "nw_troll_migration", "name": "巨魔迁徙",
		"desc": "一群北方巨魔正在穿过你的领地，它们可以被征服或驱赶。",
		"condition": "faction_orc", "repeatable": false,
		"choices": [
			{"text": "征服巨魔 (战斗: 敌6兵, 胜利+4精锐兵)", "effects": {"type": "combat", "enemy_soldiers": 6}},
			{"text": "用食物引导 (-15粮, +3兵)", "effects": {"food": -15, "soldiers": 3}},
		]
	})
	_events.append({
		"id": "nw_bone_totems", "name": "白骨图腾",
		"desc": "荒原深处发现远古兽人的白骨图腾阵，散发着原始的力量。",
		"condition": "faction_orc", "repeatable": false,
		"choices": [
			{"text": "祭拜图腾 (-3奴隶, 全军永久DEF+2)", "effects": {"slaves": -3, "buff": {"type": "def_flat", "value": 2, "duration": 99}}},
			{"text": "拆除取骨 (+25铁, WAAAGH+10)", "effects": {"iron": 25, "waaagh": 10}},
		]
	})

	# === Deep Coast (5 events) — Pirate territory ===
	_events.append({
		"id": "dc_pirate_raid", "name": "海盗劫船",
		"desc": "深海海域出现一艘满载货物的商船，是否出手劫掠？",
		"condition": "faction_pirate", "repeatable": true,
		"choices": [
			{"text": "全速追击 (70%+80金+1道具, 30%损3兵)", "effects": {"type": "gamble", "success_rate": 0.7, "success": {"gold": 80, "item": "random"}, "fail": {"soldiers": -3}}},
			{"text": "假扮商船接近 (-20金, +50金+2奴隶)", "effects": {"gold": 30, "slaves": 2}},
		]
	})
	_events.append({
		"id": "dc_sea_storm", "name": "深海风暴",
		"desc": "一场毁灭性的海上风暴席卷了深海海岸。",
		"condition": "faction_pirate", "repeatable": true,
		"choices": [
			{"text": "趁风暴偷袭敌港 (+60金, -3兵, 威胁+5)", "effects": {"gold": 60, "soldiers": -3, "threat": 5}},
			{"text": "加固港口 (-30铁, 所有据点+8城防)", "effects": {"iron": -30, "wall_boost": 8}},
		]
	})
	_events.append({
		"id": "dc_smuggler_offer", "name": "走私者的提议",
		"desc": "一位走私商人带来了一批违禁品，提出秘密交易。",
		"condition": "faction_pirate", "repeatable": false,
		"choices": [
			{"text": "接受交易 (-40金, +3火药+2魔晶)", "effects": {"gold": -40, "gunpowder": 3, "magic_crystal": 2}},
			{"text": "扣押货物 (+60金, 声望-10)", "effects": {"gold": 60, "reputation_all": -10}},
		]
	})
	_events.append({
		"id": "dc_kraken_sighting", "name": "海怪出没",
		"desc": "深海中出现了传说中的海怪，沿岸渔民惊恐不已。",
		"condition": "faction_pirate", "repeatable": false,
		"choices": [
			{"text": "猎杀海怪 (战斗: 敌12兵, 胜利+3暗影精华)", "effects": {"type": "combat", "enemy_soldiers": 12}},
			{"text": "祭祀安抚 (-5奴隶, 全军ATK+20% 5回合)", "effects": {"slaves": -5, "buff": {"type": "atk_pct", "value": 20, "duration": 5}}},
		]
	})
	_events.append({
		"id": "dc_sunken_armory", "name": "海底武器库",
		"desc": "潜水员在深海发现了一座沉没的古代武器库。",
		"condition": "faction_pirate", "repeatable": false,
		"choices": [
			{"text": "打捞武器 (-20铁, +5火药+全军ATK+10% 3回合)", "effects": {"iron": -20, "gunpowder": 5, "buff": {"type": "atk_pct", "value": 10, "duration": 3}}},
			{"text": "标记位置卖给矮人 (+100金, 声望+5)", "effects": {"gold": 100, "reputation_all": 5}},
		]
	})

	# === Eternal Night (5 events) — Dark Elf territory ===
	_events.append({
		"id": "en_dark_ritual", "name": "暗黑仪式",
		"desc": "永夜之地的古老祭坛突然复苏，暗影能量在空气中震荡。",
		"condition": "faction_dark_elf", "repeatable": false,
		"choices": [
			{"text": "举行大祭 (-5奴隶, +5暗影精华, 全军INT+3 5回合)", "effects": {"slaves": -5, "shadow_essence": 5, "buff": {"type": "int_flat", "value": 3, "duration": 5}}},
			{"text": "封印祭坛 (秩序+8, +30金)", "effects": {"order": 8, "gold": 30}},
		]
	})
	_events.append({
		"id": "en_slave_revolt", "name": "奴隶暴动",
		"desc": "永夜之地的奴隶矿场爆发了大规模暴动。",
		"condition": "faction_dark_elf", "repeatable": true,
		"choices": [
			{"text": "血腥镇压 (-2兵, -5奴隶, 秩序+10, 威望+5)", "effects": {"soldiers": -2, "slaves": -5, "order": 10, "prestige": 5}},
			{"text": "做出让步 (-20金, 秩序+3, 奴隶产出+20% 5回合)", "effects": {"gold": -20, "order": 3, "buff": {"type": "slave_efficiency", "value": 20, "duration": 5}}},
		]
	})
	_events.append({
		"id": "en_shadow_beast", "name": "暗影巨兽",
		"desc": "一头从虚空中召唤出的暗影巨兽在永夜之地游荡，威胁着所有生灵。",
		"condition": "faction_dark_elf", "repeatable": false,
		"choices": [
			{"text": "驯服巨兽 (战斗: 敌10兵, 胜利+8精锐兵)", "effects": {"type": "combat", "enemy_soldiers": 10}},
			{"text": "引导至敌方领地 (-2暗影精华, 威胁+15, 敌全军-3兵)", "effects": {"shadow_essence": -2, "threat": 15}},
		]
	})
	_events.append({
		"id": "en_void_rift", "name": "虚空裂隙",
		"desc": "永夜之地出现了一道连接虚空的裂隙，散发着诡异的光芒。",
		"condition": "faction_dark_elf", "repeatable": false,
		"choices": [
			{"text": "汲取虚空之力 (-3魔晶, +8暗影精华, 秩序-8)", "effects": {"magic_crystal": -3, "shadow_essence": 8, "order": -8}},
			{"text": "封闭裂隙 (+5魔晶, 秩序+5)", "effects": {"magic_crystal": 5, "order": 5}},
		]
	})
	_events.append({
		"id": "en_ancient_library", "name": "暗精灵古图书馆",
		"desc": "在永夜深处发现了一座被遗忘的暗精灵古代图书馆。",
		"condition": "faction_dark_elf", "repeatable": false,
		"choices": [
			{"text": "研读禁忌知识 (随机英雄永久INT+3, 秩序-5)", "effects": {"hero_stat_boost": {"stat": "int", "value": 3}, "order": -5}},
			{"text": "搜刮卷轴变卖 (+80金, +2魔晶)", "effects": {"gold": 80, "magic_crystal": 2}},
		]
	})

	# ═══════════════ HERO-SPECIFIC ENCOUNTERS (12 events) ═══════════════

	_events.append({
		"id": "hero_rivalry", "name": "英雄对立",
		"desc": "两名招募的英雄因理念不合爆发了激烈争执，整个营地都能听到她们的争吵声。",
		"condition": "has_multiple_heroes", "repeatable": true,
		"choices": [
			{"text": "调解双方 (秩序+3, 两人好感-1)", "effects": {"order": 3, "corruption_boost": -1}},
			{"text": "让她们决斗解决 (+5威望, -1兵)", "effects": {"prestige": 5, "soldiers": -1}},
		]
	})
	_events.append({
		"id": "hero_training_event", "name": "英雄切磋",
		"desc": "一位英雄主动提出要指导另一位英雄的战斗技巧，两人在训练场上热火朝天地对练。",
		"condition": "has_multiple_heroes", "repeatable": true,
		"choices": [
			{"text": "鼓励训练 (-10粮, 随机英雄ATK+1)", "effects": {"food": -10, "hero_stat_boost": {"stat": "atk", "value": 1}}},
			{"text": "让她们休息 (秩序+2)", "effects": {"order": 2}},
		]
	})
	_events.append({
		"id": "hero_homesick", "name": "思乡之情",
		"desc": "一名被俘的英雄整夜望着窗外的月亮，低声呢喃着故乡的名字。看守报告她情绪极不稳定。",
		"condition": "has_prisoners", "repeatable": true,
		"choices": [
			{"text": "安慰她 (+腐化1, 秩序+2)", "effects": {"corruption_boost": 1, "order": 2}},
			{"text": "加强看守 (-2兵, 威望+3)", "effects": {"soldiers": -2, "prestige": 3}},
		]
	})
	_events.append({
		"id": "hero_confession", "name": "英雄的告白",
		"desc": "一位与你关系亲密的英雄在深夜来访，面红耳赤地表示有话要说。",
		"condition": "has_multiple_heroes", "repeatable": false,
		"choices": [
			{"text": "认真倾听 (随机英雄好感+2, 威望+5)", "effects": {"affection_boost": 2, "prestige": 5}},
			{"text": "婉拒她 (秩序+5)", "effects": {"order": 5}},
		]
	})
	_events.append({
		"id": "hero_duel_request", "name": "决斗请求",
		"desc": "一位好胜的英雄向另一位发出了正式的决斗挑战书，要求在全军面前一决高下。",
		"condition": "has_multiple_heroes", "repeatable": true,
		"choices": [
			{"text": "允许决斗 (随机英雄ATK+2, -1兵)", "effects": {"hero_stat_boost": {"stat": "atk", "value": 2}, "soldiers": -1}},
			{"text": "禁止决斗 (秩序+3, 威望-2)", "effects": {"order": 3, "prestige": -2}},
		]
	})
	_events.append({
		"id": "hero_cooking", "name": "英雄的料理",
		"desc": "一位英雄兴致勃勃地在营地里搭起了炊灶，声称要为全军做一顿大餐。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "让她做 (70%秩序+5, 30%-3兵食物中毒)", "effects": {"type": "gamble", "success_rate": 0.7, "success": {"order": 5}, "fail": {"soldiers": -3}}},
			{"text": "委婉拒绝 (秩序+1)", "effects": {"order": 1}},
		]
	})
	_events.append({
		"id": "hero_nightmare", "name": "英雄的噩梦",
		"desc": "深夜里，一位英雄被噩梦惊醒，尖叫声惊动了整个营地。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "亲自安慰 (腐化+1, 秩序+3)", "effects": {"corruption_boost": 1, "order": 3}},
			{"text": "命令她安静 (秩序-2, 威望+2)", "effects": {"order": -2, "prestige": 2}},
		]
	})
	_events.append({
		"id": "hero_artifact_find", "name": "英雄的遗物",
		"desc": "一位英雄在战场废墟中发现了与自己过去相关的神秘遗物，它散发着奇异的光芒。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "允许她保留 (随机英雄永久DEF+2)", "effects": {"hero_stat_boost": {"stat": "def", "value": 2}}},
			{"text": "收归军用 (+1遗物)", "effects": {"relic": true}},
		]
	})
	_events.append({
		"id": "hero_jealousy", "name": "英雄的嫉妒",
		"desc": "两位英雄因为你对另一方的\"偏心\"而产生嫌隙，气氛变得微妙起来。",
		"condition": "has_multiple_heroes", "repeatable": true,
		"choices": [
			{"text": "分别安抚 (-20金, 秩序+5)", "effects": {"gold": -20, "order": 5}},
			{"text": "不予理会 (秩序-3)", "effects": {"order": -3}},
		]
	})
	_events.append({
		"id": "hero_sacrifice", "name": "英雄的请命",
		"desc": "一位英雄主动请缨执行一项极其危险的侦察任务，这可能关乎战局的走向。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "批准出击 (60%揭示6迷雾+20金, 40%损3兵)", "effects": {"type": "gamble", "success_rate": 0.6, "success": {"reveal": 6, "gold": 20}, "fail": {"soldiers": -3}}},
			{"text": "不许冒险 (秩序+3)", "effects": {"order": 3}},
		]
	})
	_events.append({
		"id": "hero_festival", "name": "英雄的庆典",
		"desc": "英雄们提议举办一场军中庆典来鼓舞士气，但这需要不少物资。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "举办庆典 (-50金, -15粮, 秩序+10, 全军ATK+10% 3回合)", "effects": {"gold": -50, "food": -15, "order": 10, "buff": {"type": "atk_pct", "value": 10, "duration": 3}}},
			{"text": "节省物资 (+5威望)", "effects": {"prestige": 5}},
		]
	})
	_events.append({
		"id": "hero_secret", "name": "英雄的秘密",
		"desc": "一位英雄在深夜找到你，犹豫再三后透露了一个关于自己过去的黑暗秘密。",
		"condition": "has_multiple_heroes", "repeatable": false,
		"choices": [
			{"text": "接受她的过去 (腐化+2, 秩序+5)", "effects": {"corruption_boost": 2, "order": 5}},
			{"text": "将此事公开 (威望+8, 秩序-5)", "effects": {"prestige": 8, "order": -5}},
		]
	})

	# ═══════════════ SEASONAL/WEATHER EVENTS (8 events) ═══════════════

	_events.append({
		"id": "harsh_winter", "name": "严酷寒冬",
		"desc": "一场百年不遇的暴风雪席卷了整片领地，粮食消耗急剧上升。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "开放粮仓 (-30粮, 秩序+5)", "effects": {"food": -30, "order": 5}},
			{"text": "实行配给 (秩序-5, -3粮/回合x3)", "effects": {"order": -5, "type": "dot", "food": -3, "duration": 3}},
		]
	})
	_events.append({
		"id": "spring_bloom", "name": "春回大地",
		"desc": "温暖的春风吹过领地，万物复苏，田野中百花齐放。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "扩大耕种 (-20金, +8粮/回合x3)", "effects": {"gold": -20, "type": "dot", "food": 8, "duration": 3}},
			{"text": "举办春祭 (-10粮, 秩序+8)", "effects": {"food": -10, "order": 8}},
		]
	})
	_events.append({
		"id": "summer_drought", "name": "夏日旱灾",
		"desc": "烈日炙烤大地，河流干涸，田地龟裂，粮食产量骤降。",
		"condition": "turn_gte_5", "repeatable": true,
		"choices": [
			{"text": "修建水渠 (-30铁, -20金, 秩序+5)", "effects": {"iron": -30, "gold": -20, "order": 5}},
			{"text": "强征粮食 (-5奴隶, +15粮, 秩序-5)", "effects": {"slaves": -5, "food": 15, "order": -5}},
		]
	})
	_events.append({
		"id": "autumn_harvest", "name": "丰收之秋",
		"desc": "今年的收成出乎意料地好，仓库堆满了金黄的粮食。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "储存粮食 (+40粮)", "effects": {"food": 40}},
			{"text": "出售余粮 (+60金, 秩序+3)", "effects": {"gold": 60, "order": 3}},
		]
	})
	_events.append({
		"id": "earthquake", "name": "大地震动",
		"desc": "一场剧烈的地震撼动了领地，多处建筑出现裂缝，城墙也受到了损害。",
		"condition": "turn_gte_5", "repeatable": true,
		"choices": [
			{"text": "紧急修缮 (-40铁, -20金, 所有据点+3城防)", "effects": {"iron": -40, "gold": -20, "wall_boost": 3}},
			{"text": "趁乱掠夺 (+30金, 秩序-8)", "effects": {"gold": 30, "order": -8}},
		]
	})
	_events.append({
		"id": "eclipse", "name": "日蚀降临",
		"desc": "天空忽然暗下来，一轮黑日悬于苍穹。士兵们惊恐不安，但暗精灵的力量似乎得到了增幅。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "安抚军心 (-20金, 秩序+5)", "effects": {"gold": -20, "order": 5}},
			{"text": "利用黑暗 (全军ATK+15% 2回合, 秩序-5)", "effects": {"order": -5, "buff": {"type": "atk_pct", "value": 15, "duration": 2}}},
		]
	})
	_events.append({
		"id": "monsoon", "name": "暴雨季节",
		"desc": "连绵不断的暴雨让道路泥泞不堪，行军速度大幅下降。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "就地扎营 (本回合不可移动, 秩序+3)", "effects": {"immobile": true, "order": 3}},
			{"text": "冒雨行军 (-3兵, 威胁-5)", "effects": {"soldiers": -3, "threat": -5}},
		]
	})
	_events.append({
		"id": "meteor_shower", "name": "流星雨",
		"desc": "壮丽的流星雨划过夜空，坠落处发现了罕见的陨石矿脉。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "开采陨铁 (-5奴隶, +40铁, +2魔晶)", "effects": {"slaves": -5, "iron": 40, "magic_crystal": 2}},
			{"text": "供奉祈愿 (秩序+10, 威望+8)", "effects": {"order": 10, "prestige": 8}},
		]
	})

	# ═══════════════ DIPLOMATIC EVENTS (8 events) ═══════════════

	_events.append({
		"id": "spy_discovered", "name": "间谍现形",
		"desc": "侍卫在营地中抓获了一名敌方间谍，此人掌握着大量情报。",
		"condition": "threat_gte_30", "repeatable": false,
		"choices": [
			{"text": "策反为双面间谍 (揭示4迷雾, 威胁-5)", "effects": {"reveal": 4, "threat": -5}},
			{"text": "公开处决 (秩序+8, 威望+5)", "effects": {"order": 8, "prestige": 5}},
		]
	})
	_events.append({
		"id": "defector_arrives", "name": "敌将来投",
		"desc": "一位敌方指挥官携带部下前来投诚，声称对旧主失望透顶。",
		"condition": "threat_gte_30", "repeatable": false,
		"choices": [
			{"text": "接纳来降 (+6兵, 声望-10, 威胁+5)", "effects": {"soldiers": 6, "reputation_all": -10, "threat": 5}},
			{"text": "拒绝并遣返 (声望+10, 威望+5)", "effects": {"reputation_all": 10, "prestige": 5}},
		]
	})
	_events.append({
		"id": "border_skirmish", "name": "边境冲突",
		"desc": "边境巡逻队与邻国势力发生了小规模交火，局势可能升级。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "全面反击 (战斗: 敌6兵, 威胁+5)", "effects": {"type": "combat", "enemy_soldiers": 6}},
			{"text": "派遣使者缓和 (-30金, 声望+10)", "effects": {"gold": -30, "reputation_all": 10}},
		]
	})
	_events.append({
		"id": "peace_envoy", "name": "求和使者",
		"desc": "敌方派来使者递交和平协议，条件是归还部分领土和资源。",
		"condition": "threat_gte_50", "repeatable": false,
		"choices": [
			{"text": "接受和平 (威胁-20, -30金, 声望+15)", "effects": {"threat": -20, "gold": -30, "reputation_all": 15}},
			{"text": "斩杀来使 (威望+10, 威胁+10, 声望-20)", "effects": {"prestige": 10, "threat": 10, "reputation_all": -20}},
		]
	})
	_events.append({
		"id": "trade_dispute", "name": "贸易纠纷",
		"desc": "两个友好势力的商人在你的领地内发生了严重的贸易纠纷，双方都要求你主持公道。",
		"condition": "always", "repeatable": true,
		"choices": [
			{"text": "公正裁决 (-20金, 声望+10, 秩序+3)", "effects": {"gold": -20, "reputation_all": 10, "order": 3}},
			{"text": "从中牟利 (+50金, 声望-10)", "effects": {"gold": 50, "reputation_all": -10}},
		]
	})
	_events.append({
		"id": "hostage_exchange", "name": "俘虏交换",
		"desc": "敌方提议交换战俘，他们手中有你的一批士兵。",
		"condition": "has_prisoners", "repeatable": false,
		"choices": [
			{"text": "同意交换 (+5兵, 声望+10)", "effects": {"soldiers": 5, "reputation_all": 10}},
			{"text": "拒绝交换 (秩序-3, 威望+5)", "effects": {"order": -3, "prestige": 5}},
		]
	})
	_events.append({
		"id": "assassination_attempt", "name": "暗杀阴谋",
		"desc": "侍卫在你的寝室中发现了毒药和暗器——有人试图暗杀你。",
		"condition": "threat_gte_30", "repeatable": false,
		"choices": [
			{"text": "展开大清洗 (-3奴隶, 秩序+10, 威望+8)", "effects": {"slaves": -3, "order": 10, "prestige": 8}},
			{"text": "秘密调查 (-30金, 揭示3迷雾, 威胁-5)", "effects": {"gold": -30, "reveal": 3, "threat": -5}},
		]
	})
	_events.append({
		"id": "alliance_betrayal", "name": "盟友背叛",
		"desc": "情报显示你的一个盟友正在暗中与敌方接触，密谋倒戈。",
		"condition": "threat_gte_50", "repeatable": false,
		"choices": [
			{"text": "先发制人 (战斗: 敌8兵, 威望+10)", "effects": {"type": "combat", "enemy_soldiers": 8}},
			{"text": "外交施压 (-50金, 声望+5, 威胁-10)", "effects": {"gold": -50, "reputation_all": 5, "threat": -10}},
		]
	})

	# ═══════════════ ECONOMIC EVENTS (8 events) ═══════════════

	_events.append({
		"id": "gold_rush", "name": "金矿发现",
		"desc": "探矿队在领地深处发现了一条富含黄金的矿脉！",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "大规模开采 (-5奴隶, +15金/回合x5)", "effects": {"slaves": -5, "type": "dot", "gold": 15, "duration": 5}},
			{"text": "秘密储备 (+80金, 威望+5)", "effects": {"gold": 80, "prestige": 5}},
		]
	})
	_events.append({
		"id": "famine", "name": "饥荒蔓延",
		"desc": "连续的灾害导致大面积饥荒，领地内到处是饥民的哀号。",
		"condition": "turn_gte_5", "repeatable": true,
		"choices": [
			{"text": "开放军粮 (-30粮, 秩序+8, +3兵)", "effects": {"food": -30, "order": 8, "soldiers": 3}},
			{"text": "封锁消息 (秩序-10, 声望-10)", "effects": {"order": -10, "reputation_all": -10}},
		]
	})
	_events.append({
		"id": "arms_dealer", "name": "军火商人",
		"desc": "一位来自远方的军火商人展示了一批精良的武器装备，开价不菲。",
		"condition": "gold_gte_80", "repeatable": true,
		"choices": [
			{"text": "大量购入 (-100金, 全军ATK+15% 5回合)", "effects": {"gold": -100, "buff": {"type": "atk_pct", "value": 15, "duration": 5}}},
			{"text": "仅购少量 (-40金, +15铁)", "effects": {"gold": -40, "iron": 15}},
		]
	})
	_events.append({
		"id": "slave_rebellion", "name": "奴隶大起义",
		"desc": "暗精灵领地内的奴隶们在一位神秘领袖的带领下发动了大规模起义。",
		"condition": "faction_dark_elf", "repeatable": false,
		"choices": [
			{"text": "铁血镇压 (-5兵, -8奴隶, 秩序+15)", "effects": {"soldiers": -5, "slaves": -8, "order": 15}},
			{"text": "谈判安抚 (-50金, 秩序+5, 奴隶产出+10% 5回合)", "effects": {"gold": -50, "order": 5, "buff": {"type": "slave_efficiency", "value": 10, "duration": 5}}},
		]
	})
	_events.append({
		"id": "pirate_raid_coast", "name": "海岸劫掠",
		"desc": "一支不明来历的海盗舰队袭击了沿海领地，烧杀抢掠。",
		"condition": "faction_pirate", "repeatable": false,
		"choices": [
			{"text": "出海迎战 (战斗: 敌10兵, 胜利+80金)", "effects": {"type": "combat", "enemy_soldiers": 10}},
			{"text": "加固海防 (-30铁, 所有据点+10城防)", "effects": {"iron": -30, "wall_boost": 10}},
		]
	})
	_events.append({
		"id": "orc_blood_moon", "name": "血月狂潮",
		"desc": "天空中升起血红色的月亮，兽人战士们陷入了疯狂的战斗狂热。",
		"condition": "faction_orc", "repeatable": false,
		"choices": [
			{"text": "释放狂暴 (全军ATK+25% 3回合, DEF-15% 3回合, WAAAGH+20)", "effects": {"waaagh": 20, "buff": {"type": "atk_pct", "value": 25, "duration": 3}}},
			{"text": "克制部队 (WAAAGH+10, 秩序+5)", "effects": {"waaagh": 10, "order": 5}},
		]
	})
	_events.append({
		"id": "ancient_library_discovery", "name": "远古图书馆",
		"desc": "在偏远山区发现了一座保存完好的远古图书馆，里面藏有大量失传的知识。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "派学者研究 (-40金, 随机英雄永久INT+2)", "effects": {"gold": -40, "hero_stat_boost": {"stat": "int", "value": 2}}},
			{"text": "搬回变卖 (+60金, +20铁)", "effects": {"gold": 60, "iron": 20}},
		]
	})
	_events.append({
		"id": "cursed_treasure", "name": "诅咒宝藏",
		"desc": "探险队发现了一座散发着不祥气息的宝库，财宝堆积如山，但空气中弥漫着诅咒的力量。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "冒险取宝 (60%+120金+1遗物, 40%-5兵+产出-20% 3回合)", "effects": {"type": "gamble", "success_rate": 0.6, "success": {"gold": 120, "relic": true}, "fail": {"soldiers": -5, "debuff": {"type": "income_pct", "value": -20, "duration": 3}}}},
			{"text": "封印宝库 (秩序+5, 威望+5)", "effects": {"order": 5, "prestige": 5}},
		]
	})

	# ═══════════════ NARRATIVE MINI-CHAINS (4 chains x 3 events = 12 events) ═══════════════

	# Chain 1: "流浪先知" (The Wandering Prophet)
	_events.append({
		"id": "wandering_prophet", "name": "流浪先知",
		"desc": "一位衣衫褴褛的老者来到领地，自称能预见未来，开始在集市上布道。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "允许布道 (秩序-3, 威望+5)", "effects": {"order": -3, "prestige": 5}},
			{"text": "驱逐先知 (秩序+3, 声望-5)", "effects": {"order": 3, "reputation_all": -5}},
		]
	})
	_events.append({
		"id": "prophet_gathering", "name": "先知的信众",
		"desc": "那位先知已经聚集了大批信徒，他们日夜在营地外举行祈祷仪式，影响了军队的秩序。",
		"condition": "chain:wandering_prophet:0", "repeatable": false,
		"chain_parent": "wandering_prophet", "chain_choice": 0,
		"choices": [
			{"text": "加入祈祷 (-20金, 全军DEF+10% 3回合, 秩序+5)", "effects": {"gold": -20, "order": 5, "buff": {"type": "def_pct", "value": 10, "duration": 3}}},
			{"text": "限制集会 (秩序+3, 声望-5)", "effects": {"order": 3, "reputation_all": -5}},
		]
	})
	_events.append({
		"id": "prophet_revelation", "name": "先知的预言",
		"desc": "先知发出了最终的预言——他声称看见了领地未来的命运，信徒们屏息以待。",
		"condition": "chain:prophet_gathering:0", "repeatable": false,
		"chain_parent": "prophet_gathering", "chain_choice": 0,
		"choices": [
			{"text": "信任预言 (揭示6迷雾, 秩序+8, +1遗物)", "effects": {"reveal": 6, "order": 8, "relic": true}},
			{"text": "揭穿骗局 (+40金, 威望+10, 声望-10)", "effects": {"gold": 40, "prestige": 10, "reputation_all": -10}},
		]
	})

	# Chain 2: "龙之目击" (Dragon Sighting)
	_events.append({
		"id": "dragon_rumor", "name": "龙之传闻",
		"desc": "边境的农民报告在山脉上方看到了巨大的飞行生物，恐慌开始蔓延。",
		"condition": "turn_gte_5", "repeatable": false,
		"choices": [
			{"text": "派遣斥候调查 (-10金, -2兵)", "effects": {"gold": -10, "soldiers": -2}},
			{"text": "安抚民心 (秩序+3)", "effects": {"order": 3}},
		]
	})
	_events.append({
		"id": "dragon_scouting", "name": "龙巢勘察",
		"desc": "斥候确认了龙的存在——一头年迈但仍然强大的巨龙盘踞在北方山脉中。",
		"condition": "chain:dragon_rumor:0", "repeatable": false,
		"chain_parent": "dragon_rumor", "chain_choice": 0,
		"choices": [
			{"text": "准备讨伐 (-30铁, -20金, +5兵)", "effects": {"iron": -30, "gold": -20, "soldiers": 5}},
			{"text": "尝试交涉 (-3魔晶)", "effects": {"magic_crystal": -3}},
		]
	})
	_events.append({
		"id": "dragon_confrontation_fight", "name": "屠龙之战",
		"desc": "大军向龙巢进发，一场史诗级的战斗即将展开。",
		"condition": "chain:dragon_scouting:0", "repeatable": false,
		"chain_parent": "dragon_scouting", "chain_choice": 0,
		"choices": [
			{"text": "全力进攻 (战斗: 敌15兵, 胜利+5暗影精华+1遗物)", "effects": {"type": "combat", "enemy_soldiers": 15}},
			{"text": "设置陷阱 (70%+100金+1遗物, 30%损5兵)", "effects": {"type": "gamble", "success_rate": 0.7, "success": {"gold": 100, "relic": true}, "fail": {"soldiers": -5}}},
		]
	})
	_events.append({
		"id": "dragon_confrontation_talk", "name": "龙的契约",
		"desc": "使者小心翼翼地进入龙巢，巨龙的金色瞳孔注视着这个渺小的来客。",
		"condition": "chain:dragon_scouting:1", "repeatable": false,
		"chain_parent": "dragon_scouting", "chain_choice": 1,
		"choices": [
			{"text": "缔结盟约 (全军ATK+20% 5回合, 威望+15)", "effects": {"prestige": 15, "buff": {"type": "atk_pct", "value": 20, "duration": 5}}},
			{"text": "索取龙鳞 (+50铁, +3暗影精华, 威望+10)", "effects": {"iron": 50, "shadow_essence": 3, "prestige": 10}},
		]
	})

	# Chain 3: "瘟疫医生" (The Plague Doctor)
	_events.append({
		"id": "plague_spreads", "name": "疫病蔓延",
		"desc": "一种不明疫病在领地中迅速扩散，士兵和平民纷纷倒下。",
		"condition": "always", "repeatable": false,
		"choices": [
			{"text": "严格隔离 (-3兵, 秩序+5)", "effects": {"soldiers": -3, "order": 5}},
			{"text": "寻求外援 (-30金)", "effects": {"gold": -30}},
		]
	})
	_events.append({
		"id": "plague_doctor_arrives", "name": "瘟疫医生",
		"desc": "一位戴着鸟嘴面具的神秘医生出现在领地门前，声称能治愈瘟疫。",
		"condition": "chain:plague_spreads", "repeatable": false,
		"chain_parent": "plague_spreads",
		"choices": [
			{"text": "信任医生 (-50金)", "effects": {"gold": -50}},
			{"text": "搜查此人 (-10金, -1兵)", "effects": {"gold": -10, "soldiers": -1}},
		]
	})
	_events.append({
		"id": "plague_cure_real", "name": "神医的灵药",
		"desc": "瘟疫医生确实是一位真正的名医，他调配的药物迅速控制了疫情。",
		"condition": "chain:plague_doctor_arrives:0", "repeatable": false,
		"chain_parent": "plague_doctor_arrives", "chain_choice": 0,
		"choices": [
			{"text": "留下任命为军医 (+3兵, 秩序+10, 全军DEF+5% 5回合)", "effects": {"soldiers": 3, "order": 10, "buff": {"type": "def_pct", "value": 5, "duration": 5}}},
			{"text": "厚礼送走 (声望+15, 秩序+5)", "effects": {"reputation_all": 15, "order": 5}},
		]
	})
	_events.append({
		"id": "plague_cure_fake", "name": "瘟疫骗子",
		"desc": "搜查发现此人是个骗子，\"灵药\"不过是染色的糖水，真正的目的是盗取军中物资。",
		"condition": "chain:plague_doctor_arrives:1", "repeatable": false,
		"chain_parent": "plague_doctor_arrives", "chain_choice": 1,
		"choices": [
			{"text": "处决骗子 (+20金, 秩序+8, 威望+5)", "effects": {"gold": 20, "order": 8, "prestige": 5}},
			{"text": "流放了事 (秩序+3, 声望+5)", "effects": {"order": 3, "reputation_all": 5}},
		]
	})

	# Chain 4: "地下抵抗军" (Underground Resistance)
	_events.append({
		"id": "resistance_rumors", "name": "地下暗流",
		"desc": "情报人员发现敌方领地内部存在一支秘密抵抗组织，对现任统治者心怀不满。",
		"condition": "threat_gte_30", "repeatable": false,
		"choices": [
			{"text": "秘密接触 (-20金)", "effects": {"gold": -20}},
			{"text": "向敌方告密 (声望+10, 威胁-5)", "effects": {"reputation_all": 10, "threat": -5}},
		]
	})
	_events.append({
		"id": "resistance_contact", "name": "地下接头",
		"desc": "你的密使与抵抗组织的领袖成功接头，对方提出了合作条件。",
		"condition": "chain:resistance_rumors:0", "repeatable": false,
		"chain_parent": "resistance_rumors", "chain_choice": 0,
		"choices": [
			{"text": "提供武器 (-30铁, -20金)", "effects": {"iron": -30, "gold": -20}},
			{"text": "提供情报 (揭示3迷雾)", "effects": {"reveal": 3}},
		]
	})
	_events.append({
		"id": "resistance_recruit", "name": "起义爆发",
		"desc": "在你的支援下，抵抗组织发动了起义，敌方后方陷入混乱。",
		"condition": "chain:resistance_contact:0", "repeatable": false,
		"chain_parent": "resistance_contact", "chain_choice": 0,
		"choices": [
			{"text": "趁机进攻 (+8兵, 威胁-10, 揭示4迷雾)", "effects": {"soldiers": 8, "threat": -10, "reveal": 4}},
			{"text": "收编抵抗军 (+5兵, 声望+10)", "effects": {"soldiers": 5, "reputation_all": 10}},
		]
	})
	_events.append({
		"id": "resistance_expose", "name": "里应外合",
		"desc": "你提供的情报帮助抵抗组织策划了一次精准的破坏行动。",
		"condition": "chain:resistance_contact:1", "repeatable": false,
		"chain_parent": "resistance_contact", "chain_choice": 1,
		"choices": [
			{"text": "配合夹击 (战斗: 敌8兵, 威胁-10)", "effects": {"type": "combat", "enemy_soldiers": 8}},
			{"text": "静待时机 (威胁-15, 声望+5)", "effects": {"threat": -15, "reputation_all": 5}},
		]
	})


# ═══════════════ CONDITION CHECKS ═══════════════

func check_condition(event: Dictionary) -> bool:
	var pid: int = GameManager.get_human_player_id()
	var faction_id: int = GameManager.get_player_faction(pid)
	var cond: String = event["condition"]

	# v4.3: Chain condition format: "chain:parent_id" or "chain:parent_id:choice_index"
	if cond.begins_with("chain:"):
		var parts: PackedStringArray = cond.split(":")
		var parent_id: String = parts[1] if parts.size() > 1 else ""
		if not _event_chain_history.has(parent_id):
			return false
		# If specific choice required, check it
		if parts.size() > 2:
			var required_choice: int = int(parts[2])
			if _event_chain_history[parent_id].get("choice", -1) != required_choice:
				return false
		# Check delay: chain events fire 2-4 turns after parent
		var parent_turn: int = _event_chain_history[parent_id].get("turn", 0)
		var delay: int = GameManager.turn_number - parent_turn
		if delay < BalanceConfig.EVENT_CHAIN_DELAY_MIN:
			return false
		if delay > BalanceConfig.EVENT_CHAIN_DELAY_MAX + 2:
			return false  # Expired: too long since parent
		return true

	match cond:
		"always":
			return true
		"turn_gte_5":
			return GameManager.turn_number >= 5
		"has_slaves":
			return ResourceManager.get_resource(pid, "slaves") > 0
		"gold_gte_80":
			return ResourceManager.get_resource(pid, "gold") >= 80
		"faction_orc":
			return faction_id == FactionData.FactionID.ORC
		"faction_pirate":
			return faction_id == FactionData.FactionID.PIRATE
		"faction_dark_elf":
			return faction_id == FactionData.FactionID.DARK_ELF
		"threat_gte_30":
			return ThreatManager.get_threat() >= 30
		"threat_gte_50":
			return ThreatManager.get_threat() >= 50
		"threat_gte_80":
			return ThreatManager.get_threat() >= 80
		"order_above_60":
			return OrderManager.get_order() >= 60
		"reputation_below_minus30":
			var reps: Dictionary = DiplomacyManager.get_all_reputations()
			for faction_key in reps:
				if reps[faction_key] < -30:
					return true
			return false
		"has_prisoners":
			return HeroSystem.captured_heroes.size() > 0
		"has_multiple_heroes":
			return HeroSystem.recruited_heroes.size() >= 2 or (HeroSystem.recruited_heroes.size() >= 1 and HeroSystem.captured_heroes.size() >= 1)
	return false


# ═══════════════ EVENT ROLLING ═══════════════

## Roll for random events this turn (called during Events phase).
## Respects deduplication: non-repeatable events only fire once per game.
func roll_events(max_events: int = 2) -> Array:
	_triggered_this_turn.clear()
	var eligible := []
	for event in _events:
		# Skip non-repeatable events already triggered this game
		if not event.get("repeatable", false) and _triggered_ids.has(event["id"]):
			continue
		# Skip events still on cooldown
		if _event_cooldowns.get(event["id"], 0) > 0:
			continue
		if not check_condition(event):
			# BUG修复: 不满足条件的非重复事件不应标记为已触发，否则条件
			# 后续满足时也无法触发（如faction_orc事件在选择兽人后永远无法触发）
			continue
		eligible.append(event)
	eligible.shuffle()
	var triggered := []
	for i in range(mini(max_events, eligible.size())):
		var ev: Dictionary = eligible[i]
		triggered.append(ev)
		_triggered_this_turn.append(ev["id"])
		# Mark non-repeatable events as used
		if not ev.get("repeatable", false):
			_triggered_ids[ev["id"]] = true
		# Set cooldown for repeatable events
		if ev.get("repeatable", false):
			_event_cooldowns[ev["id"]] = EVENT_COOLDOWN_TURNS
	return triggered


func tick_event_cooldowns() -> void:
	## Decrement all event cooldowns by 1. Called once per turn.
	var keys_to_erase: Array = []
	for event_id in _event_cooldowns:
		_event_cooldowns[event_id] -= 1
		if _event_cooldowns[event_id] <= 0:
			keys_to_erase.append(event_id)
	for key in keys_to_erase:
		_event_cooldowns.erase(key)


## Returns true if the player is immobilised this turn by an event effect.
func is_immobile() -> bool:
	return _immobile_this_turn


# ═══════════════ WORLD EVENTS (from SideQuestData) ═══════════════

## World events registered from SideQuestData.WORLD_EVENTS.
## These are non-repeatable narrative events checked each turn.
var _world_events: Array = []
var _world_event_triggered_ids: Dictionary = {}  # event_id -> true


func register_world_events() -> void:
	## Load world events from SideQuestData and register them for per-turn checking.
	_world_events.clear()
	_world_event_triggered_ids.clear()
	if SideQuestData.WORLD_EVENTS.is_empty():
		return
	for we in SideQuestData.WORLD_EVENTS:
		_world_events.append(we)


func check_world_events() -> Array:
	## Check and trigger world events this turn. Returns triggered events.
	var triggered: Array = []
	var pid: int = GameManager.get_human_player_id()
	for we in _world_events:
		var eid: String = we.get("id", "")
		if _world_event_triggered_ids.has(eid):
			continue
		# Evaluate trigger conditions
		var trigger: Dictionary = we.get("trigger", {})
		if not _check_world_event_trigger(trigger, pid):
			continue
		# Trigger the event
		_world_event_triggered_ids[eid] = true
		triggered.append(we)
		# Show event popup
		var popup_data: Dictionary = {
			"title": we.get("name", ""),
			"desc": we.get("desc", ""),
		}
		# Route through EventScheduler instead of direct popup
		if EventScheduler:
			EventScheduler.submit_candidate(
				eid,
				"world_event",
				EventScheduler.PRIORITY_HIGH,
				1.5,
				{"name": popup_data.get("title", ""), "description": popup_data.get("desc", ""), "choices": [], "source_type": "world_event"}
			)
		elif EventBus.has_signal("show_event_popup"):
			EventBus.show_event_popup.emit(popup_data.get("title", ""), popup_data.get("desc", ""), [])
		# Apply player effects
		var effects: Dictionary = we.get("effects", {})
		if not effects.is_empty():
			_apply_world_event_effects(effects, pid)
		# Apply AI effects to AI factions
		var ai_effects: Dictionary = we.get("ai_effects", {})
		if not ai_effects.is_empty():
			_apply_ai_effects(ai_effects)
		EventBus.message_log.emit("[color=cyan][世界事件] %s[/color]" % we.get("name", ""))
	return triggered


func _check_world_event_trigger(trigger: Dictionary, player_id: int) -> bool:
	for key in trigger:
		match key:
			"turn_min":
				if GameManager.turn_number < trigger[key]:
					return false
			"tiles_min":
				var c: int = 0
				for tile in GameManager.tiles:
					if tile.get("owner_id", -1) == player_id:
						c += 1
				if c < trigger[key]:
					return false
			"threat_min":
				if ThreatManager.get_threat() < trigger[key]:
					return false
			"battles_won_min":
				var stats: Dictionary = QuestJournal.get_stats() if QuestJournal.has_method("get_stats") else {}
				if stats.get("battles_won", 0) < trigger[key]:
					return false
			"side_quest_completed":
				if not QuestJournal.has_method("_is_completed"):
					return false
				if not QuestJournal._is_completed(QuestJournal._side_progress, trigger[key]):
					return false
			"turn_max":
				if GameManager.turn_number > trigger[key]:
					return false
			"random_chance":
				if randf() > trigger[key]:
					return false
			"orc_faction_exists":
				if not FactionManager.is_faction_alive(FactionData.FactionID.ORC):
					return false
			"pirate_faction_exists":
				if not FactionManager.is_faction_alive(FactionData.FactionID.PIRATE):
					return false
			"dark_elf_faction_exists":
				if not FactionManager.is_faction_alive(FactionData.FactionID.DARK_ELF):
					return false
			_:
				return false
	return true


func _apply_world_event_effects(effects: Dictionary, player_id: int) -> void:
	# Route through centralized EffectResolver if available
	if EffectResolver:
		EffectResolver.resolve(effects, {"player_id": player_id, "source": "world_event", "event_id": "world"})
		return

	# Legacy fallback
	for key in effects:
		match key:
			"gold":
				ResourceManager.apply_delta(player_id, {"gold": effects[key]})
			"food":
				ResourceManager.apply_delta(player_id, {"food": effects[key]})
			"iron":
				ResourceManager.apply_delta(player_id, {"iron": effects[key]})
			"prestige":
				ResourceManager.apply_delta(player_id, {"prestige": effects[key]})
			"order":
				OrderManager.change_order(effects[key])
			"threat":
				ThreatManager.change_threat(effects[key])
			"soldiers":
				if effects[key] > 0:
					ResourceManager.add_army(player_id, effects[key])
				else:
					ResourceManager.remove_army(player_id, -effects[key])
			"reveal":
				_apply_reveal(player_id, effects[key])
			"buff":
				var buff: Dictionary = effects[key]
				BuffManager.add_buff(player_id, "world_%s" % buff.get("type", ""), buff.get("type", ""), buff.get("value", 0), buff.get("duration", 1), "world_event")


func _apply_ai_effects(ai_effects: Dictionary) -> void:
	## Apply effects to all AI factions.
	var ai_ids: Array = GameManager.get_ai_player_ids() if GameManager.has_method("get_ai_player_ids") else []
	for ai_id in ai_ids:
		for key in ai_effects:
			match key:
				"soldiers":
					if ai_effects[key] > 0:
						ResourceManager.add_army(ai_id, ai_effects[key])
					else:
						ResourceManager.remove_army(ai_id, -ai_effects[key])
				"gold":
					ResourceManager.apply_delta(ai_id, {"gold": ai_effects[key]})
				"threat":
					ThreatManager.change_threat(ai_effects[key])
				"order":
					OrderManager.change_order(ai_effects[key])
				"buff":
					var buff: Dictionary = ai_effects[key]
					BuffManager.add_buff(ai_id, "world_ai_%s" % buff.get("type", ""), buff.get("type", ""), buff.get("value", 0), buff.get("duration", 1), "world_event")


## Called by GameManager at the start of the event phase each turn.
## Processes DOTs, delayed gold, temp soldier expiry, then rolls new events.
func process_turn_start() -> void:
	# Clear previous immobile flag
	_immobile_this_turn = false

	var pid: int = GameManager.get_human_player_id()

	# ── Tick active DOTs ──
	var remaining_dots: Array = []
	for dot in _active_dots:
		var key: String = dot["resource_key"]
		var delta: int = dot["delta"]
		if key == "soldiers":
			if delta < 0:
				ResourceManager.remove_army(pid, -delta)
				EventBus.message_log.emit("[color=yellow]瘟疫持续: 损失%d名士兵 (剩余%d回合)[/color]" % [-delta, dot["remaining"] - 1])
			else:
				ResourceManager.add_army(pid, delta)
		else:
			ResourceManager.apply_delta(pid, {key: delta})
		dot["remaining"] -= 1
		if dot["remaining"] > 0:
			remaining_dots.append(dot)
	_active_dots = remaining_dots

	# ── Grant delayed gold ──
	if _pending_gold > 0:
		ResourceManager.apply_delta(pid, {"gold": _pending_gold})
		EventBus.message_log.emit("[color=green]延迟金币到账: +%d金[/color]" % _pending_gold)
		_pending_gold = 0

	# ── Expire temp soldiers ──
	var remaining_batches: Array = []
	for batch in _temp_soldier_batches:
		batch["remaining"] -= 1
		if batch["remaining"] <= 0:
			# Temp soldiers leave — clamp to prevent negative army
			var current_army: int = ResourceManager.get_army(pid)
			var count: int = mini(batch["count"], maxi(0, current_army - 1))
			if count > 0:
				ResourceManager.remove_army(pid, count)
				EventBus.message_log.emit("[color=yellow]佣兵合同到期: %d名临时士兵离开[/color]" % count)
		else:
			remaining_batches.append(batch)
	_temp_soldier_batches = remaining_batches

	# ── Check world events ──
	check_world_events()


# ═══════════════ CHOICE APPLICATION ═══════════════

## Apply the chosen effect from an event.
## Routes all effects through EffectResolver for centralized handling.
func apply_choice(event_id: String, choice_index: int) -> Dictionary:
	var event: Dictionary = {}
	for e in _events:
		if e["id"] == event_id:
			event = e
			break
	if event.is_empty() or choice_index >= event["choices"].size():
		push_warning("EventSystem: apply_choice failed for event_id='%s' choice_index=%d" % [event_id, choice_index])
		return {"ok": false}

	var effects: Dictionary = event["choices"][choice_index]["effects"]
	var result := {"ok": true, "applied": []}
	var pid: int = GameManager.get_human_player_id()

	# Delegate to EffectResolver if available; otherwise fall back to legacy inline code
	if EffectResolver:
		var ctx: Dictionary = {
			"player_id": pid,
			"source": "event",
			"event_id": event_id,
		}
		var resolved: Array = EffectResolver.resolve(effects, ctx)

		# Map EffectResolver results back to legacy result format
		for entry in resolved:
			result["applied"].append(entry.get("message", ""))
		if ctx.has("gamble_result"):
			result["gamble_result"] = ctx["gamble_result"]
		# Check if combat was emitted (combat type returns empty dict after signal)
		for entry in resolved:
			if entry.get("key", "") == "combat":
				result["combat"] = true
				result["enemy_soldiers"] = entry.get("value", 0)
		# Soldier change for legacy consumers
		for entry in resolved:
			if entry.get("key", "") == "soldiers":
				result["soldier_change"] = entry.get("value", 0)
	else:
		# ── Legacy fallback (kept for safety if EffectResolver is not loaded) ──
		# Handle gamble type
		if effects.get("type") == "gamble":
			if randf() <= effects["success_rate"]:
				effects = effects["success"]
				result["gamble_result"] = "success"
			else:
				effects = effects["fail"]
				result["gamble_result"] = "fail"

		if effects.get("type") == "dot":
			var dot_duration: int = effects.get("duration", 3)
			for key in ["soldiers", "gold", "food", "iron"]:
				if effects.has(key):
					_active_dots.append({"resource_key": key, "delta": effects[key], "remaining": dot_duration})
					result["applied"].append("DOT %s: %+d/回合 x%d" % [key, effects[key], dot_duration])
			EventBus.event_choice_made.emit(event_id, choice_index)
			return result

		if effects.get("type") == "combat":
			var enemy_count: int = effects.get("enemy_soldiers", 8)
			result["combat"] = true
			result["enemy_soldiers"] = enemy_count
			var combat_id: String = event_id
			var enemy_type: String = effects.get("enemy_type", "")
			if enemy_type != "":
				combat_id = event_id + "::" + enemy_type
			EventBus.event_combat_requested.emit(pid, enemy_count, combat_id)
			result["applied"].append("combat: vs %d enemy soldiers" % enemy_count)
			EventBus.event_choice_made.emit(event_id, choice_index)
			return result

		var res_delta := {}
		for key in ["gold", "food", "iron", "slaves", "prestige", "magic_crystal", "shadow_essence", "gunpowder"]:
			if effects.has(key):
				res_delta[key] = effects[key]
				result["applied"].append("%s: %+d" % [key, effects[key]])
		if not res_delta.is_empty():
			ResourceManager.apply_delta(pid, res_delta)
		if effects.has("order"):
			OrderManager.change_order(effects["order"])
			result["applied"].append("order: %+d" % effects["order"])
		if effects.has("threat"):
			ThreatManager.change_threat(effects["threat"])
			result["applied"].append("threat: %+d" % effects["threat"])
		if effects.has("soldiers"):
			if effects["soldiers"] > 0:
				ResourceManager.add_army(pid, effects["soldiers"])
			else:
				ResourceManager.remove_army(pid, -effects["soldiers"])
			result["soldier_change"] = effects["soldiers"]
			result["applied"].append("soldiers: %+d" % effects["soldiers"])
		if effects.has("waaagh"):
			if OrcMechanic != null and OrcMechanic.has_method("add_waaagh"):
				OrcMechanic.add_waaagh(pid, effects["waaagh"])
			result["applied"].append("waaagh: %+d" % effects["waaagh"])
		if effects.has("plunder"):
			if PirateMechanic != null and PirateMechanic.has_method("add_plunder_bonus"):
				PirateMechanic.add_plunder_bonus(pid, effects["plunder"])
			result["applied"].append("plunder: %+d" % effects["plunder"])
		if effects.has("buff"):
			var buff: Dictionary = effects["buff"]
			BuffManager.add_buff(pid, "event_%s" % event_id, buff.get("type", "atk_pct"), buff.get("value", 0), buff.get("duration", 1), "event")
			result["applied"].append("buff: %s" % buff.get("type", ""))
		if effects.has("debuff"):
			var debuff: Dictionary = effects["debuff"]
			BuffManager.add_buff(pid, "event_debuff_%s" % event_id, debuff.get("type", "income_pct"), debuff.get("value", 0), debuff.get("duration", 1), "event")
			result["applied"].append("debuff: %s" % debuff.get("type", ""))
		if effects.get("immobile", false):
			_immobile_this_turn = true
			result["applied"].append("immobile")
		if effects.has("temp_soldiers"):
			ResourceManager.add_army(pid, effects["temp_soldiers"])
			_temp_soldier_batches.append({"count": effects["temp_soldiers"], "remaining": 3})
			result["applied"].append("temp_soldiers: +%d" % effects["temp_soldiers"])
		if effects.has("gold_delayed"):
			_pending_gold += effects["gold_delayed"]
			result["applied"].append("gold_delayed: +%d" % effects["gold_delayed"])
		if effects.has("lose_node") and effects["lose_node"]:
			_apply_lose_nodes(pid, 1)
			result["applied"].append("lose_node: -1")
		if effects.has("lose_nodes"):
			_apply_lose_nodes(pid, effects["lose_nodes"])
			result["applied"].append("lose_nodes: -%d" % effects["lose_nodes"])
		if effects.has("reveal"):
			_apply_reveal(pid, effects["reveal"])
			result["applied"].append("reveal: %d" % effects["reveal"])
		if effects.has("item") and effects["item"] == "random":
			ItemManager.grant_random_loot(pid)
			result["applied"].append("item: random")
		if effects.has("relic") and effects["relic"]:
			if not RelicManager.has_relic(pid):
				RelicManager.generate_relic_choices()
			else:
				ResourceManager.apply_delta(pid, {"prestige": 10})
			result["applied"].append("relic: +1")
		if effects.has("special_npc") and effects["special_npc"]:
			result["applied"].append("special_npc: +1")
		if effects.has("reputation_all"):
			var reps: Dictionary = DiplomacyManager.get_all_reputations()
			for faction_key in reps:
				DiplomacyManager.change_reputation(faction_key, effects["reputation_all"])
			result["applied"].append("reputation_all: %+d" % effects["reputation_all"])
		if effects.has("corruption_boost"):
			var boost_val: int = effects["corruption_boost"]
			for hid in HeroSystem.captured_heroes:
				HeroSystem.hero_corruption[hid] = clampi(HeroSystem.hero_corruption.get(hid, 0) + boost_val, 0, 100)
			result["applied"].append("corruption_boost: +%d" % boost_val)
		if effects.has("wall_boost"):
			var boost_amount: int = effects["wall_boost"]
			for tile in GameManager.tiles:
				if tile.get("owner_id", -1) == pid and LightFactionAI.has_wall(tile["index"]):
					LightFactionAI.repair_wall(tile["index"], boost_amount)
			result["applied"].append("wall_boost: +%d" % boost_amount)
		if effects.has("hero_stat_boost"):
			result["applied"].append("hero_stat_boost")

	# v4.3: Record event choice for chain system
	_event_chain_history[event_id] = {
		"choice": choice_index,
		"turn": GameManager.turn_number,
	}

	EventBus.event_choice_made.emit(event_id, choice_index)
	return result


# ═══════════════ EFFECT HELPERS ═══════════════

func _apply_lose_nodes(player_id: int, count: int) -> void:
	## Remove the outermost (border) tiles from the player. They become neutral.
	var border_tiles: Array = _get_border_tiles(player_id)
	border_tiles.shuffle()
	var lost: int = 0
	for i in range(mini(count, border_tiles.size())):
		var tile: Dictionary = border_tiles[i]
		tile["owner_id"] = -1
		tile["garrison"] = 0
		EventBus.tile_lost.emit(player_id, tile["index"])
		OrderManager.on_tile_lost()
		lost += 1
	if lost > 0:
		EventBus.message_log.emit("[color=red]事件导致失去 %d 个据点![/color]" % lost)


func _get_border_tiles(player_id: int) -> Array:
	## Get tiles owned by player that border non-owned tiles.
	var result: Array = []
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) != player_id:
			continue
		var neighbors: Array = GameManager.adjacency.get(tile["index"], [])
		for n_idx in neighbors:
			if n_idx < GameManager.tiles.size():
				if GameManager.tiles[n_idx].get("owner_id", -1) != player_id:
					result.append(tile)
					break
	return result


func _apply_reveal(player_id: int, count: int) -> void:
	## Reveal unrevealed tiles for the player.
	var unrevealed: Array = []
	for t in GameManager.tiles:
		if not t.get("revealed", {}).get(player_id, false):
			unrevealed.append(t["index"])
	unrevealed.shuffle()
	var revealed_count: int = 0
	for i in range(mini(count, unrevealed.size())):
		var tile_idx: int = unrevealed[i]
		# BUG FIX: ensure "revealed" dict exists before writing
		if not GameManager.tiles[tile_idx].has("revealed"):
			GameManager.tiles[tile_idx]["revealed"] = {}
		GameManager.tiles[tile_idx]["revealed"][player_id] = true
		# Also reveal neighbors
		var neighbors: Array = GameManager.adjacency.get(tile_idx, [])
		for n_idx in neighbors:
			if n_idx < GameManager.tiles.size():
				if not GameManager.tiles[n_idx].has("revealed"):
					GameManager.tiles[n_idx]["revealed"] = {}
				GameManager.tiles[n_idx]["revealed"][player_id] = true
		revealed_count += 1
	if revealed_count > 0:
		EventBus.fog_updated.emit(player_id)
		EventBus.message_log.emit("揭示了 %d 格迷雾" % revealed_count)


# ═══════════════ TIMED STORY WINDOWS (限時劇情窗口) ═══════════════
# Sengoku Rance-style timed events: miss the turn window, miss the content.
# Status: "pending" → "triggered" (rewards applied) or "expired" (miss applied).

var _active_story_windows: Dictionary = {}  # window_id -> { "status": String, "triggered_turn": int }
var _story_window_notifications: Array = []  # pending notifications for UI


func _init_story_windows() -> void:
	## Initialize all timed story windows as pending.
	_active_story_windows.clear()
	for w in BalanceConfig.TIMED_STORY_WINDOWS:
		_active_story_windows[w["id"]] = {"status": "pending", "triggered_turn": -1}


func check_timed_story_windows(player_id: int, current_turn: int) -> void:
	## Check all timed story windows. Trigger eligible ones, expire missed ones.
	if _active_story_windows.is_empty():
		_init_story_windows()

	for w in BalanceConfig.TIMED_STORY_WINDOWS:
		var wid: String = w["id"]
		var status: String = _active_story_windows.get(wid, {}).get("status", "pending")
		if status != "pending":
			continue

		var turn_min: int = w["turn_range"][0]
		var turn_max: int = w["turn_range"][1]

		# Window expired — apply miss consequence
		if current_turn > turn_max:
			_apply_miss_consequence(player_id, w)
			_active_story_windows[wid] = {"status": "expired", "triggered_turn": current_turn}
			_story_window_notifications.append({
				"type": "expired",
				"id": wid,
				"title": w["title"],
				"desc": w.get("miss_consequence", {}).get("desc", "窗口已过期"),
				"priority": w.get("priority", 1),
			})
			EventBus.story_window_expired.emit(wid, w["title"], w.get("miss_consequence", {}).get("desc", "机会已失"))
			EventBus.message_log.emit("[color=red][限时事件过期] %s — %s[/color]" % [
				w["title"], w.get("miss_consequence", {}).get("desc", "机会已失")])
			continue

		# Not yet in window
		if current_turn < turn_min:
			continue

		# In window — check conditions
		if not _check_story_window_conditions(player_id, w.get("conditions", {})):
			continue

		# All conditions met — trigger the window
		_apply_story_window_rewards(player_id, w)
		_active_story_windows[wid] = {"status": "triggered", "triggered_turn": current_turn}
		_story_window_notifications.append({
			"type": "triggered",
			"id": wid,
			"title": w["title"],
			"desc": w.get("narrative_text", ""),
			"priority": w.get("priority", 1),
		})
		EventBus.story_window_triggered.emit(wid, w["title"], w.get("narrative_text", ""))
		EventBus.message_log.emit("[color=green][限时事件触发] %s[/color]" % w["title"])
		# Route timed story windows through EventScheduler with CRITICAL priority
		if EventScheduler:
			EventScheduler.submit_candidate(
				wid,
				"timed_story_window",
				EventScheduler.PRIORITY_CRITICAL,
				2.0,
				{"name": w["title"], "description": w.get("narrative_text", ""), "choices": [], "source_type": "timed_story_window"}
			)
		elif EventBus.has_signal("show_event_popup"):
			EventBus.show_event_popup.emit(w["title"], w.get("narrative_text", ""), [])


func get_story_window_status() -> Dictionary:
	## Returns current status of all timed story windows.
	return _active_story_windows.duplicate(true)


func get_pending_story_notifications() -> Array:
	## Returns and clears pending story window notifications.
	var result: Array = _story_window_notifications.duplicate(true)
	_story_window_notifications.clear()
	return result


func get_active_windows_hint(current_turn: int) -> Array:
	## Returns vague hints about currently available windows (creates urgency).
	var hints: Array = []
	for w in BalanceConfig.TIMED_STORY_WINDOWS:
		var wid: String = w["id"]
		var status: String = _active_story_windows.get(wid, {}).get("status", "pending")
		if status != "pending":
			continue
		var turn_min: int = w["turn_range"][0]
		var turn_max: int = w["turn_range"][1]
		# Only hint about windows that are active or imminent (within 3 turns)
		if current_turn >= turn_min and current_turn <= turn_max:
			var remaining: int = turn_max - current_turn
			var urgency: String = "充裕" if remaining > 5 else ("紧迫" if remaining > 2 else "即将过期")
			hints.append({
				"priority": w.get("priority", 1),
				"hint": _get_vague_hint(w),
				"urgency": urgency,
				"turns_remaining": remaining,
			})
		elif current_turn >= turn_min - 3 and current_turn < turn_min:
			hints.append({
				"priority": w.get("priority", 1),
				"hint": "隐约感到有事即将发生...",
				"urgency": "预兆",
				"turns_remaining": turn_max - current_turn,
			})
	# Sort by priority descending
	hints.sort_custom(func(a, b): return a["priority"] > b["priority"])
	return hints


func _get_vague_hint(window: Dictionary) -> String:
	## Generate a vague hint for a timed window without spoiling details.
	var wid: String = window["id"]
	match wid:
		"merchant_caravan":
			return "远方传来商队的铃铛声..."
		"border_refugees":
			return "边境隐约传来求救的呼声..."
		"ancient_ruins_expedition":
			return "某处遗迹散发着古老的气息..."
		"alliance_proposal":
			return "一位实力强大的武者似乎在关注你..."
		"dark_ritual_warning":
			return "暗影中涌动着不祥的能量..."
		"harvest_festival":
			return "田野中弥漫着丰收的气息..."
		"weapon_smiths_offer":
			return "锻造的火焰在远方闪耀..."
		"final_prophecy":
			return "天际出现了奇异的星象..."
		"pirate_king_negotiation":
			return "海面上出现了海盗王的旗帜..."
		"scholar_conclave":
			return "各地学者似乎在筹备一场盛会..."
	return "命运的齿轮正在转动..."


# ── Timed Story Window Condition Helpers ──

func _check_story_window_conditions(player_id: int, conditions: Dictionary) -> bool:
	## Check all conditions for a timed story window. Returns true if ALL are met.
	if conditions.is_empty():
		return true

	for key in conditions:
		match key:
			"tile_control":
				if _count_player_tiles(player_id) < conditions[key]:
					return false
			"army_strength":
				if ResourceManager.get_army(player_id) < conditions[key]:
					return false
			"prestige_min":
				if ResourceManager.get_resource(player_id, "prestige") < conditions[key]:
					return false
			"hero_required":
				if not HeroSystem.has_method("is_hero_recruited"):
					return false
				if not HeroSystem.is_hero_recruited(conditions[key]):
					return false
			"faction_state":
				if not FactionManager.has_method("get_faction_state"):
					return false
				if FactionManager.get_faction_state(player_id) != conditions[key]:
					return false
			"tile_type_count":
				var req: Dictionary = conditions[key]
				var req_type: int = req.get("type", -1)
				var req_count: int = req.get("count", 1)
				if _count_player_tiles_of_type(player_id, req_type) < req_count:
					return false
			"resource_min":
				var res_reqs: Dictionary = conditions[key]
				for res_key in res_reqs:
					if ResourceManager.get_resource(player_id, res_key) < res_reqs[res_key]:
						return false
			"espionage_level":
				# Check via spy/intel system; fallback to prestige-based approximation
				var esp_level: int = 0
				if GameManager.has_method("get_espionage_level"):
					esp_level = GameManager.get_espionage_level(player_id)
				else:
					# Approximate: prestige / 50 as espionage tier
					@warning_ignore("integer_division")
					esp_level = int(ResourceManager.get_resource(player_id, "prestige") / 50)
				if esp_level < conditions[key]:
					return false
			"tile_index_owned":
				var tidx: int = conditions[key]
				if tidx < 0 or tidx >= GameManager.tiles.size():
					return false
				if GameManager.tiles[tidx].get("owner_id", -1) != player_id:
					return false
	return true


func _count_player_tiles(player_id: int) -> int:
	var count: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			count += 1
	return count


func _count_player_tiles_of_type(player_id: int, tile_type: int) -> int:
	var count: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id and tile.get("type", -1) == tile_type:
			count += 1
	return count


# ── Timed Story Window Reward Application ──

func _apply_story_window_rewards(player_id: int, window: Dictionary) -> void:
	var rewards: Dictionary = window.get("rewards", {})
	var res_delta: Dictionary = {}

	for key in rewards:
		match key:
			"gold", "food", "iron", "prestige":
				res_delta[key] = rewards[key]
			"soldiers":
				if rewards[key] > 0:
					ResourceManager.add_army(player_id, rewards[key])
				else:
					ResourceManager.remove_army(player_id, -rewards[key])
				EventBus.message_log.emit("[color=green]  奖励: 兵力%+d[/color]" % rewards[key])
			"order":
				OrderManager.change_order(rewards[key])
				EventBus.message_log.emit("[color=green]  奖励: 秩序%+d[/color]" % rewards[key])
			"hero_recruit":
				EventBus.message_log.emit("[color=green]  奖励: 英雄 %s 加入![/color]" % rewards[key])
				if HeroSystem.has_method("force_recruit_hero"):
					HeroSystem.force_recruit_hero(player_id, rewards[key])
			"troop_unlock":
				EventBus.message_log.emit("[color=green]  奖励: 解锁兵种 %s![/color]" % rewards[key])
				if RecruitManager.has_method("unlock_troop"):
					RecruitManager.unlock_troop(player_id, rewards[key])
			"army_atk_buff":
				var buff: Dictionary = rewards[key]
				BuffManager.add_buff(player_id, "story_%s" % window["id"], buff.get("type", "atk_pct"), buff.get("value", 0), buff.get("duration", 5), "story_window")
				EventBus.message_log.emit("[color=green]  奖励: 全军ATK+%d%% %d回合[/color]" % [buff.get("value", 0), buff.get("duration", 5)])
			"enemy_debuff":
				var debuff: Dictionary = rewards[key]
				var ai_ids: Array = GameManager.get_ai_player_ids() if GameManager.has_method("get_ai_player_ids") else []
				for ai_id in ai_ids:
					BuffManager.add_buff(ai_id, "story_debuff_%s" % window["id"], debuff.get("type", "atk_pct"), debuff.get("value", 0), debuff.get("duration", 5), "story_window")
				EventBus.message_log.emit("[color=green]  奖励: 敌军被削弱![/color]")
			"research_bonus":
				if ResearchManager.has_method("add_bonus_points"):
					ResearchManager.add_bonus_points(rewards[key])
				else:
					# Fallback: grant prestige equivalent
					@warning_ignore("integer_division")
					res_delta["prestige"] = res_delta.get("prestige", 0) + int(rewards[key] / 2)
				EventBus.message_log.emit("[color=green]  奖励: 研究进度+%d[/color]" % rewards[key])
			"hero_xp":
				if HeroSystem.has_method("grant_xp_all"):
					HeroSystem.grant_xp_all(player_id, rewards[key])
				EventBus.message_log.emit("[color=green]  奖励: 全英雄经验+%d[/color]" % rewards[key])

	if not res_delta.is_empty():
		ResourceManager.apply_delta(player_id, res_delta)
		var parts: Array = []
		for k in res_delta:
			parts.append("%s%+d" % [k, res_delta[k]])
		EventBus.message_log.emit("[color=green]  奖励: %s[/color]" % ", ".join(parts))


# ── Timed Story Window Miss Consequence Application ──

func _apply_miss_consequence(player_id: int, window: Dictionary) -> void:
	var consequence: Dictionary = window.get("miss_consequence", {})
	var ctype: String = consequence.get("type", "nothing")

	match ctype:
		"nothing":
			pass
		"enemy_buff":
			var ai_ids: Array = GameManager.get_ai_player_ids() if GameManager.has_method("get_ai_player_ids") else []
			for ai_id in ai_ids:
				BuffManager.add_buff(ai_id, "missed_%s" % window["id"],
					consequence.get("buff_type", "atk_pct"),
					consequence.get("value", 10),
					consequence.get("duration", 5),
					"story_window_miss")
		"resource_loss":
			var res_delta: Dictionary = {}
			for key in ["gold", "food", "iron", "prestige"]:
				if consequence.has(key):
					res_delta[key] = consequence[key]
			if not res_delta.is_empty():
				ResourceManager.apply_delta(player_id, res_delta)
		"hero_lost":
			EventBus.message_log.emit("[color=red]  %s[/color]" % consequence.get("desc", "英雄流失"))
			# Apply a compensatory enemy buff (the hero strengthens them)
			var ai_ids: Array = GameManager.get_ai_player_ids() if GameManager.has_method("get_ai_player_ids") else []
			for ai_id in ai_ids:
				BuffManager.add_buff(ai_id, "missed_hero_%s" % window["id"],
					"atk_pct", 5, 8, "story_window_miss")

# ── Endgame Crisis System (v7.0) ──
# Tracks the currently active crisis event (max 1 at a time).
# { "type": String, "turn_started": int, "duration": int, "affected_tiles": Array,
#   "quarantined_tiles": Array }
var _active_crisis: Dictionary = {}
# Tiles where the Ancient Evil invasion army is stationed (crisis_invasion)
var _invasion_tile: int = -1


## Check and possibly trigger an endgame crisis. Called once per human turn.
func check_endgame_crisis() -> void:
	var turn: int = GameManager.turn_number
	if turn < BalanceConfig.CRISIS_START_TURN:
		return
	# Max 1 active crisis at a time
	if not _active_crisis.is_empty():
		_tick_active_crisis()
		return

	# Roll for crisis: base 5% + 1% per turn past threshold
	var turns_past: int = turn - BalanceConfig.CRISIS_START_TURN
	var chance: int = BalanceConfig.CRISIS_BASE_CHANCE_PCT + turns_past * BalanceConfig.CRISIS_CHANCE_INCREASE_PCT
	var roll: int = randi() % 100
	if roll >= chance:
		return

	# Pick a random crisis type
	var crisis_types: Array = ["crisis_plague", "crisis_rebellion", "crisis_invasion", "crisis_famine"]
	var chosen: String = crisis_types[randi() % crisis_types.size()]
	_start_crisis(chosen)


func _start_crisis(crisis_type: String) -> void:
	var pid: int = GameManager.get_human_player_id()
	var turn: int = GameManager.turn_number
	match crisis_type:
		"crisis_plague":
			_start_crisis_plague(pid, turn)
		"crisis_rebellion":
			_start_crisis_rebellion(pid, turn)
		"crisis_invasion":
			_start_crisis_invasion(pid, turn)
		"crisis_famine":
			_start_crisis_famine(pid, turn)


func _start_crisis_plague(pid: int, turn: int) -> void:
	var owned: Array = GameManager.get_cached_owned_tiles(pid)
	if owned.is_empty():
		return
	# Pick a random owned tile as plague origin
	var target_idx: int = owned[randi() % owned.size()]
	_active_crisis = {
		"type": "crisis_plague",
		"turn_started": turn,
		"duration": BalanceConfig.CRISIS_PLAGUE_DURATION,
		"affected_tiles": [target_idx],
		"quarantined_tiles": [],
	}
	# Apply initial troop loss
	_apply_plague_damage([target_idx])
	EventBus.crisis_started.emit("crisis_plague", _active_crisis.duplicate(true))
	EventBus.message_log.emit("[color=red][b]═══ 终末危机: 瘟疫爆发! ═══[/b][/color]")
	EventBus.message_log.emit("[color=red]瘟疫在第%d号地块爆发! 驻军损失30%%。下回合将蔓延至相邻地块![/color]" % target_idx)
	EventBus.message_log.emit("[color=yellow]花费%d金可隔离每个受影响地块，持续%d回合。[/color]" % [
		BalanceConfig.CRISIS_PLAGUE_QUARANTINE_COST, BalanceConfig.CRISIS_PLAGUE_DURATION])


func _apply_plague_damage(tile_indices: Array) -> void:
	for tidx in tile_indices:
		if tidx < 0 or tidx >= GameManager.tiles.size():
			continue
		var tile: Dictionary = GameManager.tiles[tidx]
		var garrison: int = tile.get("garrison", 0)
		if garrison > 0:
			var loss: int = maxi(1, int(float(garrison) * BalanceConfig.CRISIS_PLAGUE_TROOP_LOSS_PCT))
			tile["garrison"] = maxi(0, garrison - loss)
			EventBus.message_log.emit("[color=red]  瘟疫: 第%d号地块驻军损失%d人[/color]" % [tidx, loss])


func _start_crisis_rebellion(pid: int, turn: int) -> void:
	var owned: Array = GameManager.get_cached_owned_tiles(pid)
	var low_order_tiles: Array = []
	for tidx in owned:
		# BUG FIX R14: bounds & null check on tile access
		if tidx < 0 or tidx >= GameManager.tiles.size():
			continue
		var tile = GameManager.tiles[tidx]
		if tile == null:
			continue
		var po: float = tile.get("public_order", BalanceConfig.TILE_ORDER_DEFAULT)
		if po < BalanceConfig.CRISIS_REBELLION_ORDER_THRESHOLD:
			low_order_tiles.append(tidx)
	if low_order_tiles.is_empty():
		# If no low-order tiles, pick 2 random tiles with lowest order
		var sorted_tiles: Array = owned.duplicate()
		sorted_tiles.sort_custom(func(a, b):
			# BUG FIX R14: safe tile access in sort lambda
			var tile_a = GameManager.tiles[a] if a >= 0 and a < GameManager.tiles.size() else null
			var tile_b = GameManager.tiles[b] if b >= 0 and b < GameManager.tiles.size() else null
			var po_a: float = tile_a.get("public_order", BalanceConfig.TILE_ORDER_DEFAULT) if tile_a != null else 1.0
			var po_b: float = tile_b.get("public_order", BalanceConfig.TILE_ORDER_DEFAULT) if tile_b != null else 1.0
			return po_a < po_b)
		low_order_tiles = sorted_tiles.slice(0, mini(2, sorted_tiles.size()))

	_active_crisis = {
		"type": "crisis_rebellion",
		"turn_started": turn,
		"duration": 1,  # Instant — rebel armies spawn and must be reconquered
		"affected_tiles": low_order_tiles.duplicate(),
		"quarantined_tiles": [],
	}
	# Spawn rebel armies — flip tiles to unowned with garrison
	for tidx in low_order_tiles:
		# BUG FIX R14: bounds & null check
		if tidx < 0 or tidx >= GameManager.tiles.size():
			continue
		var tile = GameManager.tiles[tidx]
		if tile == null:
			continue
		tile["owner_id"] = -1
		tile["garrison"] = BalanceConfig.CRISIS_REBELLION_ARMY_STRENGTH
		tile["public_order"] = 0.0
		EventBus.rebel_spawned.emit(tidx)
	EventBus.crisis_started.emit("crisis_rebellion", _active_crisis.duplicate(true))
	EventBus.message_log.emit("[color=red][b]═══ 终末危机: 大规模叛乱! ═══[/b][/color]")
	EventBus.message_log.emit("[color=red]%d个低秩序地块爆发叛乱! 叛军已占据这些据点(兵力%d)，必须重新征服![/color]" % [
		low_order_tiles.size(), BalanceConfig.CRISIS_REBELLION_ARMY_STRENGTH])
	# Rebellion is instant — clear crisis immediately
	_active_crisis.clear()


func _start_crisis_invasion(pid: int, turn: int) -> void:
	# Find a map-edge tile (tile with fewest adjacencies, or unowned tile)
	var best_tile: int = -1
	var best_degree: int = 999
	for i in range(GameManager.tiles.size()):
		var tile: Dictionary = GameManager.tiles[i]
		if tile["owner_id"] != pid:
			var degree: int = GameManager.adjacency.get(i, []).size()
			if degree < best_degree:
				best_degree = degree
				best_tile = i
	if best_tile < 0:
		# Fallback: pick first unowned tile
		for i in range(GameManager.tiles.size()):
			# BUG FIX R15: null check on tile
			var _inv_tile = GameManager.tiles[i]
			if _inv_tile == null:
				continue
			if _inv_tile.get("owner_id", -1) != pid:
				best_tile = i
				break
	if best_tile < 0:
		return  # Player owns everything, skip

	var tile: Dictionary = GameManager.tiles[best_tile]
	tile["owner_id"] = -1
	tile["garrison"] = BalanceConfig.CRISIS_INVASION_ARMY_STRENGTH
	_invasion_tile = best_tile
	_active_crisis = {
		"type": "crisis_invasion",
		"turn_started": turn,
		"duration": 99,  # Lasts until defeated
		"affected_tiles": [best_tile],
		"quarantined_tiles": [],
	}
	EventBus.crisis_started.emit("crisis_invasion", _active_crisis.duplicate(true))
	EventBus.message_log.emit("[color=red][b]═══ 终末危机: 远古邪灵入侵! ═══[/b][/color]")
	EventBus.message_log.emit("[color=red]一支强大的远古邪灵军队(兵力%d)出现在第%d号地块! 击败它将获得传奇奖励![/color]" % [
		BalanceConfig.CRISIS_INVASION_ARMY_STRENGTH, best_tile])


func _start_crisis_famine(pid: int, turn: int) -> void:
	_active_crisis = {
		"type": "crisis_famine",
		"turn_started": turn,
		"duration": BalanceConfig.CRISIS_FAMINE_DURATION,
		"affected_tiles": [],
		"quarantined_tiles": [],
	}
	EventBus.crisis_started.emit("crisis_famine", _active_crisis.duplicate(true))
	EventBus.message_log.emit("[color=red][b]═══ 终末危机: 严重饥荒! ═══[/b][/color]")
	EventBus.message_log.emit("[color=red]饥荒席卷全境! 粮食产出减半，持续%d回合。合理管理军队否则将大量逃亡![/color]" % [
		BalanceConfig.CRISIS_FAMINE_DURATION])


func _tick_active_crisis() -> void:
	if _active_crisis.is_empty():
		return

	var crisis_type: String = _active_crisis["type"]
	_active_crisis["duration"] -= 1
	var remaining: int = _active_crisis["duration"]

	match crisis_type:
		"crisis_plague":
			_tick_plague(remaining)
		"crisis_invasion":
			_tick_invasion()
		"crisis_famine":
			_tick_famine(remaining)
		# crisis_rebellion is instant — no tick needed

	EventBus.crisis_tick.emit(crisis_type, remaining, _active_crisis.duplicate(true))

	if remaining <= 0:
		_end_crisis(crisis_type)


func _tick_plague(remaining: int) -> void:
	var pid: int = GameManager.get_human_player_id()
	# Spread to adjacent tiles (unless quarantined)
	var current_affected: Array = _active_crisis.get("affected_tiles", [])
	var quarantined: Array = _active_crisis.get("quarantined_tiles", [])
	var new_affected: Array = current_affected.duplicate()

	for tidx in current_affected:
		if tidx in quarantined:
			continue
		var neighbors: Array = GameManager.adjacency.get(tidx, [])
		for ntidx in neighbors:
			if ntidx in new_affected or ntidx in quarantined:
				continue
			if ntidx >= 0 and ntidx < GameManager.tiles.size():
				var ntile: Dictionary = GameManager.tiles[ntidx]
				if ntile["owner_id"] == pid:
					new_affected.append(ntidx)
					EventBus.message_log.emit("[color=red]  瘟疫蔓延至第%d号地块![/color]" % ntidx)

	# Apply damage to all non-quarantined affected tiles
	var damage_tiles: Array = []
	for tidx in new_affected:
		if tidx not in quarantined:
			damage_tiles.append(tidx)
	_apply_plague_damage(damage_tiles)
	_active_crisis["affected_tiles"] = new_affected

	if remaining > 0:
		EventBus.message_log.emit("[color=yellow]瘟疫剩余%d回合。花费%d金/地块可隔离。[/color]" % [
			remaining, BalanceConfig.CRISIS_PLAGUE_QUARANTINE_COST])


func _tick_invasion() -> void:
	# Check if invasion tile has been reconquered
	if _invasion_tile >= 0 and _invasion_tile < GameManager.tiles.size():
		var tile: Dictionary = GameManager.tiles[_invasion_tile]
		var pid: int = GameManager.get_human_player_id()
		if tile["owner_id"] == pid or tile.get("garrison", 0) <= 0:
			# Player defeated the Ancient Evil — grant legendary rewards
			ResourceManager.apply_delta(pid, {
				"gold": BalanceConfig.CRISIS_INVASION_REWARD_GOLD,
			})
			var current_prestige: int = ResourceManager.get_resource(pid, "prestige")
			ResourceManager.set_resource(pid, "prestige",
				current_prestige + BalanceConfig.CRISIS_INVASION_REWARD_PRESTIGE)
			EventBus.message_log.emit("[color=green][b]远古邪灵被击败! 获得传奇奖励: %d金, %d威望![/b][/color]" % [
				BalanceConfig.CRISIS_INVASION_REWARD_GOLD, BalanceConfig.CRISIS_INVASION_REWARD_PRESTIGE])
			_active_crisis["duration"] = 0  # End crisis
			_invasion_tile = -1


func _tick_famine(_remaining: int) -> void:
	EventBus.message_log.emit("[color=red]饥荒持续中: 粮食产出减半 (剩余%d回合)[/color]" % _remaining)


## Check if famine crisis is active (called by ProductionCalculator)
func is_famine_active() -> bool:
	return not _active_crisis.is_empty() and _active_crisis.get("type", "") == "crisis_famine"


## Get famine production multiplier
func get_famine_food_mult() -> float:
	if is_famine_active():
		return BalanceConfig.CRISIS_FAMINE_PRODUCTION_MULT
	return 1.0


## Quarantine a plague-affected tile (player action, costs gold)
func quarantine_plague_tile(tile_index: int) -> bool:
	if _active_crisis.is_empty() or _active_crisis.get("type", "") != "crisis_plague":
		return false
	var affected: Array = _active_crisis.get("affected_tiles", [])
	var quarantined: Array = _active_crisis.get("quarantined_tiles", [])
	if tile_index not in affected or tile_index in quarantined:
		return false

	var pid: int = GameManager.get_human_player_id()
	var cost: int = BalanceConfig.CRISIS_PLAGUE_QUARANTINE_COST
	var gold: int = ResourceManager.get_resource(pid, "gold")
	if gold < cost:
		EventBus.message_log.emit("[color=red]金币不足! 隔离需要%d金。[/color]" % cost)
		return false

	ResourceManager.apply_delta(pid, {"gold": -cost})
	quarantined.append(tile_index)
	_active_crisis["quarantined_tiles"] = quarantined
	EventBus.crisis_quarantine_applied.emit(tile_index, cost)
	EventBus.message_log.emit("[color=green]第%d号地块已隔离 (花费%d金)，瘟疫不再从此蔓延。[/color]" % [tile_index, cost])
	return true


func _end_crisis(crisis_type: String) -> void:
	EventBus.crisis_ended.emit(crisis_type)
	match crisis_type:
		"crisis_plague":
			EventBus.message_log.emit("[color=green]瘟疫已消退。[/color]")
		"crisis_famine":
			EventBus.message_log.emit("[color=green]饥荒已结束，粮食产出恢复正常。[/color]")
		"crisis_invasion":
			pass  # Handled in _tick_invasion
	_active_crisis.clear()
	_invasion_tile = -1


## Get the active crisis data (for UI/save)
func get_active_crisis() -> Dictionary:
	return _active_crisis.duplicate(true)




func to_save_data() -> Dictionary:
	return {
		"triggered_this_turn": _triggered_this_turn.duplicate(true),
		"triggered_ids": _triggered_ids.duplicate(true),
		"active_dots": _active_dots.duplicate(true),
		"pending_gold": _pending_gold,
		"immobile_this_turn": _immobile_this_turn,
		"temp_soldier_batches": _temp_soldier_batches.duplicate(true),
		"world_event_triggered_ids": _world_event_triggered_ids.duplicate(true),
		"event_cooldowns": _event_cooldowns.duplicate(true),
		"event_chain_history": _event_chain_history.duplicate(true),
		"pending_chain_events": _pending_chain_events.duplicate(true),
		"active_story_windows": _active_story_windows.duplicate(true),
		"active_crisis": _active_crisis.duplicate(true),
		"invasion_tile": _invasion_tile,
	}


func from_save_data(data: Dictionary) -> void:
	_triggered_this_turn = data.get("triggered_this_turn", []).duplicate(true)
	_triggered_ids = data.get("triggered_ids", {}).duplicate(true)
	_active_dots = data.get("active_dots", []).duplicate(true)
	_pending_gold = data.get("pending_gold", 0)
	_immobile_this_turn = data.get("immobile_this_turn", false)
	_temp_soldier_batches = data.get("temp_soldier_batches", []).duplicate(true)
	_world_event_triggered_ids = data.get("world_event_triggered_ids", {}).duplicate(true)
	_event_cooldowns = data.get("event_cooldowns", {}).duplicate(true)
	_event_chain_history = data.get("event_chain_history", {}).duplicate(true)
	_pending_chain_events = data.get("pending_chain_events", []).duplicate(true)
	_active_story_windows = data.get("active_story_windows", {}).duplicate(true)
	_active_crisis = data.get("active_crisis", {}).duplicate(true)
	_invasion_tile = data.get("invasion_tile", -1)
	_story_window_notifications.clear()
	# Re-register world events from data file so check_world_events() works
	register_world_events()
