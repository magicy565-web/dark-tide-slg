## pirate_mechanic.gd - 海盗派系完整机制 (v2.0 — 掠夺经济 / 黑市 / 性奴隶 / 恶名)
##
## 海盗是中间势力，在光明与黑暗阵营之间游走:
##   - 金币为王: 一切围绕掠夺与金币运转
##   - 性奴隶系统: 可赎回、调教、黑市出售
##   - 前期较弱: 必须通过掠夺发展，建立据点后解锁高级兵种
##   - 雇佣兵: 金币可雇佣佣兵部队(弱于本阵营兵种)
##
## v2.0 新增:
##   - 海盗恶名系统 (Infamy, 0-100)
##   - 朗姆酒士气系统 (Rum Morale)
##   - 藏宝图探索 (Treasure Hunting)
##   - 走私航线 (Smuggling Routes, 被动收入)
##   - AI海盗突袭队 (Raid Parties)
##   - 扩展黑市 (多物品库存)
##   - 性奴隶调教与容量系统
##   - 雇佣兵系统
extends Node
const FactionData = preload("res://systems/faction/faction_data.gd")


# ══════════════════════════════════════════════════════════════════════════════
# STATE VARIABLES
# ══════════════════════════════════════════════════════════════════════════════

# ── 性奴隶系统 ──
var _sex_slaves: Dictionary = {}         # player_id -> int (性奴隶数量)
var _slave_training: Dictionary = {}     # player_id -> { slave_index: training_value }

# ── 恶名系统 ──
var _infamy: Dictionary = {}             # player_id -> int (0-100, 声望/恶名值)

# ── 掠夺系统 ──
var _plunder_streak: Dictionary = {}     # player_id -> int (连续掠夺回合数)
var _bonus_plunder: Dictionary = {}      # player_id -> int (累积额外掠夺值)

# ── 朗姆酒士气 ──
var _rum_morale: Dictionary = {}         # player_id -> int (0-100, 朗姆酒提供的士气)

# ── 藏宝图 ──
var _treasure_maps: Dictionary = {}      # player_id -> Array of { tile_index, reward_type, reward_value }

# ── 走私航线 ──
var _smuggle_routes: Dictionary = {}     # player_id -> Array of [tile_a, tile_b] 对

# ── 黑市 ──
var _market_item: Dictionary = {}        # 兼容旧API: 当前单件商品
var _market_stock: Dictionary = {}       # player_id -> Array of items (多物品黑市库存)

# ── AI突袭队 ──
var _raid_parties: Dictionary = {}       # player_id -> Array of { tile_index, strength, turns_left }

# ── 掠夺连击本回合是否更新标记 ──
var _plunder_streak_updated_this_turn: Dictionary = {}  # player_id -> bool


# ══════════════════════════════════════════════════════════════════════════════
# CONSTANTS — 性奴隶调教
# ══════════════════════════════════════════════════════════════════════════════

const TRAINING_PER_TURN: int = 10        # 每回合基础调教进度
const TRAINING_MAX: int = 100            # 调教上限
const SLAVE_BASE_SELL_PRICE: int = 25    # 未调教奴隶出售价
const SLAVE_TRAINED_PRICE_MULT: float = 4.0  # 满调教出售价 = 25 * 4 = 100金
const SLAVE_RANSOM_BASE: int = 50        # 向光明阵营赎回基础价
const SLAVE_RANSOM_RELATION_MULT: float = 2.0  # 高好感度 = 高赎金

# ── 性奴隶容量 ──
const SEX_SLAVE_BASE_CAPACITY: int = 3
const SEX_SLAVE_PER_TERRITORY: int = 2
const SEX_SLAVE_PER_BLACK_MARKET: int = 3  # 每个黑市建筑增加容量


# ══════════════════════════════════════════════════════════════════════════════
# CONSTANTS — 恶名系统 (海盗恶名 0-100)
# ══════════════════════════════════════════════════════════════════════════════

const INFAMY_PER_PLUNDER: int = 5
const INFAMY_PER_RANSOM: int = -3        # 赎回降低恶名
const INFAMY_PER_TRADE: int = -2         # 交易降低恶名
const INFAMY_DECAY_PER_TURN: int = 2     # 每回合自然衰减
const INFAMY_HIGH_THRESHOLD: int = 70    # 光明阵营拒绝交易
const INFAMY_LOW_THRESHOLD: int = 30     # 黑暗阵营不信任


# ══════════════════════════════════════════════════════════════════════════════
# CONSTANTS — 朗姆酒士气
# ══════════════════════════════════════════════════════════════════════════════

const RUM_MORALE_PER_BARREL: int = 15
const RUM_DECAY_PER_TURN: int = 5
const RUM_ATK_BONUS_THRESHOLD: int = 50  # 50以上: 全军ATK+2
const RUM_HIGH_MORALE_ATK: int = 2
const RUM_DRUNK_THRESHOLD: int = 90      # 90以上: ATK+4 但 DEF-2 (醉酒作战)
const RUM_DRUNK_ATK: int = 4
const RUM_DRUNK_DEF_PENALTY: int = -2


# ══════════════════════════════════════════════════════════════════════════════
# CONSTANTS — 藏宝图系统
# ══════════════════════════════════════════════════════════════════════════════

const TREASURE_MAP_DROP_CHANCE: float = 0.15  # 战斗胜利后15%概率获得藏宝图
const TREASURE_REWARDS: Array = [
	{"type": "gold", "min": 50, "max": 200},
	{"type": "item", "id": "rare_weapon"},
	{"type": "mercenary", "count": 5},
	{"type": "sex_slave", "count": 2},
	{"type": "rum", "value": 30},
]


# ══════════════════════════════════════════════════════════════════════════════
# CONSTANTS — 走私航线
# ══════════════════════════════════════════════════════════════════════════════

const SMUGGLE_INCOME_PER_ROUTE: int = 8  # 每条航线每回合金币收入
const MAX_SMUGGLE_ROUTES: int = 3


# ══════════════════════════════════════════════════════════════════════════════
# CONSTANTS — AI突袭队
# ══════════════════════════════════════════════════════════════════════════════

const AI_RAID_SPAWN_CHANCE: float = 0.25    # 每回合25%概率生成突袭队
const AI_RAID_MIN_STRENGTH: int = 4
const AI_RAID_MAX_STRENGTH: int = 10
const AI_RAID_DURATION: int = 3             # 突袭队存活回合数
const AI_RAID_LOOT_ON_DEFEAT: int = 40      # 击败突袭队获得金币
const AI_MAX_RAID_PARTIES: int = 4          # 最大同时突袭队数量


# ══════════════════════════════════════════════════════════════════════════════
# MARKET ITEMS POOL — 黑市商品库
# ══════════════════════════════════════════════════════════════════════════════

## 武器类: 攻击提升
const MARKET_ITEMS_WEAPONS: Array = [
	{"name": "走私军火", "desc": "战力+15", "effect": "atk_boost", "value": 15, "price": 60, "category": "weapon"},
	{"name": "黑火药", "desc": "下次攻击伤害+25", "effect": "atk_boost", "value": 25, "price": 80, "category": "weapon"},
	{"name": "毒刃", "desc": "攻击附带毒伤+10", "effect": "atk_boost", "value": 10, "price": 45, "category": "weapon"},
	{"name": "火焰弹", "desc": "范围伤害+20", "effect": "atk_boost", "value": 20, "price": 70, "category": "weapon"},
]

## 补给类: 粮草/铁矿
const MARKET_ITEMS_SUPPLIES: Array = [
	{"name": "朗姆酒桶", "desc": "朗姆酒士气+15", "effect": "rum", "value": 15, "price": 30, "category": "supply"},
	{"name": "铁锚碎片", "desc": "铁矿+5", "effect": "iron", "value": 5, "price": 35, "category": "supply"},
	{"name": "干粮包", "desc": "粮草+10", "effect": "food", "value": 10, "price": 25, "category": "supply"},
]

## 特殊类: 功能性道具
const MARKET_ITEMS_SPECIAL: Array = [
	{"name": "藏宝图", "desc": "获得一张藏宝图", "effect": "treasure_map", "value": 1, "price": 50, "category": "special"},
	{"name": "望远镜", "desc": "侦查范围+2回合", "effect": "scout_range", "value": 2, "price": 40, "category": "special"},
	{"name": "海图", "desc": "走私航线收入+3本回合", "effect": "smuggle_boost", "value": 3, "price": 55, "category": "special"},
	{"name": "黑旗", "desc": "恶名+10", "effect": "infamy", "value": 10, "price": 20, "category": "special"},
]

## 消耗品类
const MARKET_ITEMS_CONSUMABLES: Array = [
	{"name": "烟雾弹", "desc": "撤退成功率+50%", "effect": "escape_bonus", "value": 50, "price": 35, "category": "consumable"},
	{"name": "治疗药剂", "desc": "战后恢复HP+30", "effect": "heal", "value": 30, "price": 40, "category": "consumable"},
]

## 性奴隶相关道具
const MARKET_ITEMS_SLAVE: Array = [
	{"name": "调教鞭", "desc": "全体性奴隶调教+20", "effect": "slave_train_all", "value": 20, "price": 65, "category": "slave"},
	{"name": "魅惑香", "desc": "下次捕获性奴隶+1", "effect": "slave_capture_bonus", "value": 1, "price": 45, "category": "slave"},
]

## 兼容旧版: 完整商品列表 (合并所有分类)
const MARKET_ITEMS: Array = [
	{"name": "走私军火", "desc": "战力+15", "effect": "atk_boost", "value": 15, "price": 60},
	{"name": "海盗旗", "desc": "威望+3", "effect": "prestige", "value": 3, "price": 40},
	{"name": "朗姆酒桶", "desc": "粮草+8", "effect": "food", "value": 8, "price": 30},
	{"name": "黑火药", "desc": "下次攻击伤害+25", "effect": "atk_boost", "value": 25, "price": 80},
	{"name": "藏宝图", "desc": "金币+80", "effect": "gold", "value": 80, "price": 50},
	{"name": "铁锚碎片", "desc": "铁矿+5", "effect": "iron", "value": 5, "price": 35},
]


# ══════════════════════════════════════════════════════════════════════════════
# MERCENARY DEFS — 雇佣兵定义
# ══════════════════════════════════════════════════════════════════════════════

const MERCENARY_TYPES: Array = [
	{"id": "merc_swordsman", "name": "佣兵剑士", "atk": 4, "hp": 35, "cost": 30, "count": 10},
	{"id": "merc_archer", "name": "佣兵弓手", "atk": 5, "hp": 25, "cost": 35, "count": 8},
	{"id": "merc_heavy", "name": "佣兵重甲", "atk": 3, "hp": 50, "cost": 45, "count": 6},
	{"id": "merc_assassin", "name": "佣兵刺客", "atk": 8, "hp": 20, "cost": 60, "count": 4},
]


# ══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	pass


func reset() -> void:
	# 性奴隶
	_sex_slaves.clear()
	_slave_training.clear()
	# 恶名
	_infamy.clear()
	# 掠夺
	_plunder_streak.clear()
	_bonus_plunder.clear()
	# 朗姆酒
	_rum_morale.clear()
	# 藏宝图
	_treasure_maps.clear()
	# 走私
	_smuggle_routes.clear()
	# 黑市
	_market_item = {}
	_market_stock.clear()
	# AI突袭
	_raid_parties.clear()
	# 掠夺连击标记
	_plunder_streak_updated_this_turn.clear()


func init_player(player_id: int) -> void:
	_sex_slaves[player_id] = 1           # 开局1名性奴隶
	_slave_training[player_id] = {}
	_infamy[player_id] = 20              # 起始恶名: 20 (小有名气)
	_plunder_streak[player_id] = 0
	_bonus_plunder[player_id] = 0
	_rum_morale[player_id] = 50          # v3.0.1: 30→50 起始朗姆酒士气 (前期ATK+2)
	_treasure_maps[player_id] = []
	_smuggle_routes[player_id] = []
	_market_stock[player_id] = []
	_raid_parties[player_id] = []
	_plunder_streak_updated_this_turn[player_id] = false


# ══════════════════════════════════════════════════════════════════════════════
# TURN TICK — 主入口 (每回合调用)
# ══════════════════════════════════════════════════════════════════════════════

func tick(player_id: int) -> void:
	## 每回合为海盗玩家调用: 刷新黑市、衰减恶名/士气、调教奴隶、走私收入、藏宝图检查
	if not _sex_slaves.has(player_id):
		return

	# ── 刷新黑市库存 ──
	_refresh_market(player_id)

	# ── 恶名自然衰减 ──
	_tick_infamy_decay(player_id)

	# ── 朗姆酒士气衰减 ──
	_tick_rum_decay(player_id)

	# ── 性奴隶调教进度 ──
	tick_slave_training(player_id)

	# ── 走私航线被动收入 ──
	_tick_smuggle_income(player_id)

	# ── 掠夺连续回合检查 ──
	_tick_plunder_streak(player_id)


# ══════════════════════════════════════════════════════════════════════════════
# SEX SLAVE SYSTEM — 性奴隶系统
# ══════════════════════════════════════════════════════════════════════════════

## 获取玩家性奴隶数量
func get_sex_slaves(player_id: int) -> int:
	return _sex_slaves.get(player_id, 0)


## 获取性奴隶容量上限
## 公式: 基础3 + 领地数*2 + 黑市建筑数*3
func get_sex_slave_capacity(player_id: int) -> int:
	var territory_count: int = _count_territory(player_id)
	var black_markets: int = _count_building(player_id, "black_market")
	return SEX_SLAVE_BASE_CAPACITY + territory_count * SEX_SLAVE_PER_TERRITORY + black_markets * SEX_SLAVE_PER_BLACK_MARKET


## 添加性奴隶 (受容量限制). 返回实际添加数量.
func add_sex_slaves(player_id: int, count: int) -> int:
	var capacity: int = get_sex_slave_capacity(player_id)
	var current: int = _sex_slaves.get(player_id, 0)
	var space: int = maxi(capacity - current, 0)
	var added: int = mini(count, space)
	if added > 0:
		_sex_slaves[player_id] = current + added
		# 为新奴隶初始化调教进度
		var training: Dictionary = _slave_training.get(player_id, {})
		for i in range(added):
			var idx: int = current + i
			training[idx] = 0
		_slave_training[player_id] = training
		EventBus.message_log.emit("[color=pink]捕获性奴隶 +%d (当前: %d/%d)[/color]" % [
			added, _sex_slaves[player_id], capacity])
	elif count > 0 and space <= 0:
		EventBus.message_log.emit("[color=pink]性奴隶容量已满! (%d/%d)[/color]" % [current, capacity])
	return added


## 消耗性奴隶 (用于调教等). 返回是否成功.
func consume_sex_slaves(player_id: int, count: int) -> bool:
	var current: int = _sex_slaves.get(player_id, 0)
	if current < count:
		EventBus.message_log.emit("[color=red]性奴隶不足! 需要%d, 仅有%d[/color]" % [count, current])
		return false
	# BUG FIX: Don't decrement _sex_slaves here; _remove_slave_at_index already does it
	# _sex_slaves[player_id] = current - count  -- REMOVED: was causing double decrement
	# 移除对应调教数据 (从最低调教值的开始移除)
	var training: Dictionary = _slave_training.get(player_id, {})
	for _i in range(count):
		var lowest_idx: int = _find_lowest_trained_slave(player_id)
		if lowest_idx >= 0:
			_remove_slave_at_index(player_id, lowest_idx)
	# If _remove_slave_at_index didn't remove enough (no training data), fix count directly
	var after: int = _sex_slaves.get(player_id, 0)
	if after > current - count:
		_sex_slaves[player_id] = maxi(current - count, 0)
	EventBus.message_log.emit("[color=red]消耗性奴隶 -%d (剩余: %d)[/color]" % [count, _sex_slaves.get(player_id, 0)])
	return true


## 获取指定奴隶的调教值 (0-100)
func get_slave_training(player_id: int, slave_index: int) -> int:
	var training: Dictionary = _slave_training.get(player_id, {})
	return training.get(slave_index, 0)


## 每回合调教所有性奴隶
func tick_slave_training(player_id: int) -> void:
	var slave_count: int = _sex_slaves.get(player_id, 0)
	if slave_count <= 0:
		return
	var training: Dictionary = _slave_training.get(player_id, {})
	var any_trained: bool = false
	for i in range(slave_count):
		var current: int = training.get(i, 0)
		if current < TRAINING_MAX:
			training[i] = mini(current + TRAINING_PER_TURN, TRAINING_MAX)
			any_trained = true
			if training[i] >= TRAINING_MAX and current < TRAINING_MAX:
				EventBus.message_log.emit("[color=pink]性奴隶 #%d 调教完成! 出售价值最高![/color]" % i)
	_slave_training[player_id] = training
	if any_trained:
		EventBus.message_log.emit("[color=pink]性奴隶调教中... 全体调教进度 +%d[/color]" % TRAINING_PER_TURN)


## 根据调教值计算出售价格
func get_slave_sell_price(training_value: int) -> int:
	# 线性插值: 0调教 = 25金, 100调教 = 100金
	var ratio: float = float(clampi(training_value, 0, TRAINING_MAX)) / float(TRAINING_MAX)
	var price: int = int(float(SLAVE_BASE_SELL_PRICE) * (1.0 + ratio * (SLAVE_TRAINED_PRICE_MULT - 1.0)))
	return price


## 在黑市出售指定性奴隶. 返回获得金币数.
func sell_sex_slave(player_id: int, slave_index: int) -> int:
	var slave_count: int = _sex_slaves.get(player_id, 0)
	if slave_count <= 0 or slave_index < 0 or slave_index >= slave_count:
		EventBus.message_log.emit("没有可出售的性奴隶!")
		return 0
	var training: Dictionary = _slave_training.get(player_id, {})
	var training_value: int = training.get(slave_index, 0)
	var price: int = get_slave_sell_price(training_value)

	# 移除该奴隶, 重新整理索引
	_remove_slave_at_index(player_id, slave_index)

	# 发放金币
	ResourceManager.apply_delta(player_id, {"gold": price})
	add_infamy(player_id, INFAMY_PER_TRADE)
	EventBus.message_log.emit("[color=gold]黑市出售性奴隶! 调教值%d, 获得%d金[/color]" % [training_value, price])
	EventBus.resources_changed.emit(player_id)
	return price


## 向光明阵营赎回性奴隶. 返回获得金币数 (受好感度与恶名影响).
func ransom_sex_slave(player_id: int) -> int:
	var slave_count: int = _sex_slaves.get(player_id, 0)
	if slave_count <= 0:
		EventBus.message_log.emit("没有性奴隶可以赎回!")
		return 0

	# 优先赎回调教值最低的 (赎回价格不受调教影响)
	var lowest_idx: int = _find_lowest_trained_slave(player_id)

	# 计算赎金: 基础50, 好感度加成, 恶名减成
	var base: int = SLAVE_RANSOM_BASE
	var relation_mult: float = _get_light_faction_relation_mult(player_id)
	var infamy_mult: float = 1.0 - float(get_infamy(player_id)) * 0.005  # 恶名越高赎金越低
	infamy_mult = maxf(infamy_mult, 0.3)
	var price: int = maxi(int(float(base) * relation_mult * infamy_mult), 10)

	# 移除奴隶
	_remove_slave_at_index(player_id, lowest_idx)

	# 发放金币与调整恶名
	ResourceManager.apply_delta(player_id, {"gold": price})
	add_infamy(player_id, INFAMY_PER_RANSOM)
	EventBus.message_log.emit("[color=gold]赎回性奴隶! 获得%d金 (好感x%.1f, 恶名影响x%.1f)[/color]" % [
		price, relation_mult, infamy_mult])
	EventBus.resources_changed.emit(player_id)
	return price


## 在黑市出售调教值最高的性奴隶. 返回获得金币数.
func sell_sex_slave_at_market(player_id: int) -> int:
	var slave_count: int = _sex_slaves.get(player_id, 0)
	if slave_count <= 0:
		EventBus.message_log.emit("没有性奴隶可以出售!")
		return 0
	var highest_idx: int = _find_highest_trained_slave(player_id)
	return sell_sex_slave(player_id, highest_idx)


## 内部: 移除指定索引的奴隶并重新整理训练字典
func _remove_slave_at_index(player_id: int, slave_index: int) -> void:
	var slave_count: int = _sex_slaves.get(player_id, 0)
	var training: Dictionary = _slave_training.get(player_id, {})
	# 将后面的奴隶往前移
	var new_training: Dictionary = {}
	var new_idx: int = 0
	for i in range(slave_count):
		if i == slave_index:
			continue
		new_training[new_idx] = training.get(i, 0)
		new_idx += 1
	_slave_training[player_id] = new_training
	_sex_slaves[player_id] = maxi(slave_count - 1, 0)


## 内部: 查找调教值最低的奴隶索引
func _find_lowest_trained_slave(player_id: int) -> int:
	var training: Dictionary = _slave_training.get(player_id, {})
	var slave_count: int = _sex_slaves.get(player_id, 0)
	if slave_count <= 0:
		return -1
	var lowest_idx: int = 0
	var lowest_val: int = TRAINING_MAX + 1
	for i in range(slave_count):
		var val: int = training.get(i, 0)
		if val < lowest_val:
			lowest_val = val
			lowest_idx = i
	return lowest_idx


## 内部: 查找调教值最高的奴隶索引
func _find_highest_trained_slave(player_id: int) -> int:
	var training: Dictionary = _slave_training.get(player_id, {})
	var slave_count: int = _sex_slaves.get(player_id, 0)
	if slave_count <= 0:
		return -1
	var highest_idx: int = 0
	var highest_val: int = -1
	for i in range(slave_count):
		var val: int = training.get(i, 0)
		if val > highest_val:
			highest_val = val
			highest_idx = i
	return highest_idx


## 内部: 获取与光明阵营的好感度乘数
func _get_light_faction_relation_mult(_player_id: int) -> float:
	if DiplomacyManager != null and DiplomacyManager.has_method("is_light_ceasefire_active"):
		# 停战中视为友好(x1.5), 否则中立(x1.0)
		if DiplomacyManager.is_light_ceasefire_active():
			return 1.5
	return 1.0


# ══════════════════════════════════════════════════════════════════════════════
# INFAMY SYSTEM — 海盗恶名 (0-100)
# ══════════════════════════════════════════════════════════════════════════════

## 获取恶名值
func get_infamy(player_id: int) -> int:
	return _infamy.get(player_id, 0)


## 增减恶名 (clamped 0-100)
func add_infamy(player_id: int, amount: int) -> void:
	var current: int = _infamy.get(player_id, 0)
	_infamy[player_id] = clampi(current + amount, 0, 100)
	EventBus.infamy_changed.emit(player_id, _infamy[player_id])
	if amount > 0:
		EventBus.message_log.emit("[color=red]恶名上升 +%d (当前: %d)[/color]" % [amount, _infamy[player_id]])
	elif amount < 0:
		EventBus.message_log.emit("[color=green]恶名下降 %d (当前: %d)[/color]" % [amount, _infamy[player_id]])


## 恶名>=70: 光明阵营拒绝交易
func is_high_infamy(player_id: int) -> bool:
	return get_infamy(player_id) >= INFAMY_HIGH_THRESHOLD


## 恶名<=30: 黑暗阵营不信任
func is_low_infamy(player_id: int) -> bool:
	return get_infamy(player_id) <= INFAMY_LOW_THRESHOLD


## 恶名影响交易价格乘数
## 恶名0: x1.2 (良好声誉, 价格优惠)
## 恶名50: x1.0 (正常)
## 恶名100: x0.7 (恶名昭著, 被加价)
func get_infamy_trade_mult(player_id: int) -> float:
	var inf: float = float(get_infamy(player_id))
	return 1.2 - inf * 0.005


## 内部: 每回合恶名自然衰减
func _tick_infamy_decay(player_id: int) -> void:
	var current: int = _infamy.get(player_id, 0)
	if current > 0:
		var decay: int = mini(current, INFAMY_DECAY_PER_TURN)
		_infamy[player_id] = current - decay
		EventBus.infamy_changed.emit(player_id, _infamy[player_id])


# ══════════════════════════════════════════════════════════════════════════════
# RUM MORALE SYSTEM — 朗姆酒士气 (0-100)
# ══════════════════════════════════════════════════════════════════════════════

## 获取朗姆酒士气值
func get_rum_morale(player_id: int) -> int:
	return _rum_morale.get(player_id, 0)


## 消耗朗姆酒桶, 士气+15
func use_rum(player_id: int) -> void:
	var current: int = _rum_morale.get(player_id, 0)
	_rum_morale[player_id] = mini(current + RUM_MORALE_PER_BARREL, 100)
	EventBus.rum_morale_changed.emit(player_id, _rum_morale[player_id])
	EventBus.message_log.emit("[color=orange]开了一桶朗姆酒! 船员士气 +%d (当前: %d)[/color]" % [
		RUM_MORALE_PER_BARREL, _rum_morale[player_id]])


## 获取朗姆酒战斗加成 {"atk": X, "def": Y}
func get_rum_combat_bonus(player_id: int) -> Dictionary:
	var morale: int = get_rum_morale(player_id)
	if morale >= RUM_DRUNK_THRESHOLD:
		# 醉酒: ATK+4 但 DEF-2
		return {"atk": RUM_DRUNK_ATK, "def": RUM_DRUNK_DEF_PENALTY}
	elif morale >= RUM_ATK_BONUS_THRESHOLD:
		# 高士气: ATK+2
		return {"atk": RUM_HIGH_MORALE_ATK, "def": 0}
	return {"atk": 0, "def": 0}


## 在战斗前将朗姆酒加成应用到所有部队
func apply_rum_bonus_to_units(player_id: int, units: Array) -> void:
	var bonus: Dictionary = get_rum_combat_bonus(player_id)
	if bonus["atk"] == 0 and bonus["def"] == 0:
		return
	for unit in units:
		if unit is Dictionary:
			unit["atk"] = unit.get("atk", 0) + bonus["atk"]
			unit["def"] = unit.get("def", 0) + bonus["def"]
	var morale: int = get_rum_morale(player_id)
	if morale >= RUM_DRUNK_THRESHOLD:
		EventBus.message_log.emit("[color=orange]醉酒作战! 全军ATK+%d, DEF%d![/color]" % [
			RUM_DRUNK_ATK, RUM_DRUNK_DEF_PENALTY])
	elif morale >= RUM_ATK_BONUS_THRESHOLD:
		EventBus.message_log.emit("[color=orange]朗姆酒加持! 全军ATK+%d![/color]" % RUM_HIGH_MORALE_ATK)


## 内部: 每回合朗姆酒士气衰减
func _tick_rum_decay(player_id: int) -> void:
	var current: int = _rum_morale.get(player_id, 0)
	if current > 0:
		var decay: int = mini(current, RUM_DECAY_PER_TURN)
		_rum_morale[player_id] = current - decay
		EventBus.rum_morale_changed.emit(player_id, _rum_morale[player_id])


# ══════════════════════════════════════════════════════════════════════════════
# BLACK MARKET — 黑市 (扩展版, 多物品库存)
# ══════════════════════════════════════════════════════════════════════════════

## 刷新黑市库存 (每回合调用). 根据黑市建筑等级生成1-3件商品.
func _refresh_market(player_id: int) -> void:
	var black_market_level: int = _get_black_market_level(player_id)
	# 物品数量: 等级0=1件, 等级1=2件, 等级2+=3件
	var item_count: int = clampi(1 + black_market_level, 1, 3)

	# 从所有分类中随机选取
	var all_items: Array = []
	all_items.append_array(MARKET_ITEMS_WEAPONS)
	all_items.append_array(MARKET_ITEMS_SUPPLIES)
	all_items.append_array(MARKET_ITEMS_SPECIAL)
	all_items.append_array(MARKET_ITEMS_CONSUMABLES)
	all_items.append_array(MARKET_ITEMS_SLAVE)

	var stock: Array = []
	var used_indices: Array = []
	for _i in range(item_count):
		if all_items.is_empty() or used_indices.size() >= all_items.size():
			break
		var idx: int = randi() % all_items.size()
		# 避免重复
		var attempts: int = 0
		while idx in used_indices and attempts < 20:
			idx = randi() % all_items.size()
			attempts += 1
		used_indices.append(idx)
		stock.append(all_items[idx].duplicate())
	_market_stock[player_id] = stock

	# 兼容旧API: 设置 _market_item 为第一件商品
	if stock.size() > 0:
		_market_item = stock[0].duplicate()
	else:
		_market_item = {}

	# 日志
	var names: String = ""
	for i in range(stock.size()):
		if i > 0:
			names += ", "
		names += "%s(%d金)" % [stock[i]["name"], stock[i]["price"]]
	EventBus.message_log.emit("黑市今日商品: %s" % names)


## 获取当前黑市库存
func get_market_stock(player_id: int) -> Array:
	return _market_stock.get(player_id, []).duplicate(true)


## 购买黑市指定索引商品. 返回是否成功.
func buy_market_item(player_id: int, item_index: int = -1) -> bool:
	# 兼容旧API: item_index=-1 时购买第一件 (或唯一一件)
	var stock: Array = _market_stock.get(player_id, [])

	# 旧API兼容: 如果没有多物品库存, 使用 _market_item
	if stock.is_empty():
		if _market_item.is_empty():
			EventBus.message_log.emit("黑市暂无商品")
			return false
		var price: int = _market_item["price"]
		if not ResourceManager.spend(player_id, {"gold": price}):
			EventBus.message_log.emit("金币不足! 需要%d金" % price)
			return false
		_apply_market_effect(player_id, _market_item)
		EventBus.message_log.emit("购买了 %s!" % _market_item["name"])
		_market_item = {}
		return true

	# 多物品库存逻辑
	if item_index < 0:
		item_index = 0
	if item_index >= stock.size():
		EventBus.message_log.emit("该商品已售罄或索引无效!")
		return false

	var item: Dictionary = stock[item_index]
	var price: int = item["price"]

	# 恶名影响价格
	var trade_mult: float = get_infamy_trade_mult(player_id)
	var final_price: int = maxi(int(float(price) / trade_mult), 1)

	if not ResourceManager.spend(player_id, {"gold": final_price}):
		EventBus.message_log.emit("金币不足! 需要%d金 (恶名调整: x%.2f)" % [final_price, trade_mult])
		return false

	_apply_market_effect(player_id, item)
	EventBus.message_log.emit("[color=gold]购买了 %s! (花费%d金)[/color]" % [item["name"], final_price])
	stock.remove_at(item_index)
	_market_stock[player_id] = stock
	EventBus.resources_changed.emit(player_id)
	return true


## 兼容旧API: 获取单件黑市商品
func get_market_item() -> Dictionary:
	return _market_item.duplicate()


## 内部: 获取玩家最高等级黑市建筑
func _get_black_market_level(player_id: int) -> int:
	var max_level: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			var bid: String = tile.get("building_id", "")
			if bid == "black_market" or bid == "smugglers_den":
				var lvl: int = tile.get("building_level", 1)
				max_level = maxi(max_level, lvl)
	return max_level


## 内部: 应用商品效果
func _apply_market_effect(player_id: int, item: Dictionary) -> void:
	var effect: String = item.get("effect", "")
	var value: int = item.get("value", 0)
	match effect:
		"atk_boost":
			var player: Dictionary = GameManager.get_player_by_id(player_id)
			player["atk_bonus"] = player.get("atk_bonus", 0) + value
		"prestige":
			ResourceManager.apply_delta(player_id, {"prestige": value})
		"food":
			ResourceManager.apply_delta(player_id, {"food": value})
		"gold":
			ResourceManager.apply_delta(player_id, {"gold": value})
		"iron":
			ResourceManager.apply_delta(player_id, {"iron": value})
		"rum":
			# 直接增加朗姆酒士气
			var current: int = _rum_morale.get(player_id, 0)
			_rum_morale[player_id] = mini(current + value, 100)
			EventBus.rum_morale_changed.emit(player_id, _rum_morale[player_id])
		"treasure_map":
			# 添加一张随机藏宝图
			_generate_treasure_map(player_id)
		"scout_range":
			var player: Dictionary = GameManager.get_player_by_id(player_id)
			player["scout_bonus_turns"] = player.get("scout_bonus_turns", 0) + value
		"smuggle_boost":
			# 本回合走私收入临时加成
			var bonus_income: int = get_smuggle_routes(player_id).size() * value
			if bonus_income > 0:
				ResourceManager.apply_delta(player_id, {"gold": bonus_income})
				EventBus.message_log.emit("[color=gold]海图加成! 走私额外收入 +%d金[/color]" % bonus_income)
		"infamy":
			add_infamy(player_id, value)
		"escape_bonus":
			var player: Dictionary = GameManager.get_player_by_id(player_id)
			player["escape_bonus"] = player.get("escape_bonus", 0) + value
		"heal":
			var player: Dictionary = GameManager.get_player_by_id(player_id)
			player["post_combat_heal"] = player.get("post_combat_heal", 0) + value
		"slave_train_all":
			# 全体性奴隶调教 +value
			_train_all_slaves_bonus(player_id, value)
		"slave_capture_bonus":
			var player: Dictionary = GameManager.get_player_by_id(player_id)
			player["slave_capture_bonus"] = player.get("slave_capture_bonus", 0) + value
			EventBus.message_log.emit("[color=pink]魅惑香生效! 下次捕获性奴隶 +%d[/color]" % value)


## 内部: 给全体奴隶额外调教值
func _train_all_slaves_bonus(player_id: int, bonus: int) -> void:
	var slave_count: int = _sex_slaves.get(player_id, 0)
	if slave_count <= 0:
		EventBus.message_log.emit("没有性奴隶可以调教!")
		return
	var training: Dictionary = _slave_training.get(player_id, {})
	for i in range(slave_count):
		var current: int = training.get(i, 0)
		training[i] = mini(current + bonus, TRAINING_MAX)
	_slave_training[player_id] = training
	EventBus.message_log.emit("[color=pink]调教鞭生效! 全体性奴隶调教 +%d[/color]" % bonus)


# ══════════════════════════════════════════════════════════════════════════════
# PLUNDER ECONOMY — 掠夺经济
# ══════════════════════════════════════════════════════════════════════════════

## 获取掠夺值 (领地基础 + 累积奖励)
func get_plunder_value(player_id: int) -> int:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.PIRATE]
	var owned: int = GameManager.count_tiles_owned(player_id)
	return params["plunder_base_per_tile"] * owned + _bonus_plunder.get(player_id, 0)


## 增加累积掠夺值
func add_plunder_bonus(player_id: int, amount: int) -> void:
	_bonus_plunder[player_id] = _bonus_plunder.get(player_id, 0) + amount
	EventBus.plunder_changed.emit(player_id, get_plunder_value(player_id))


## 战斗胜利后的掠夺金币. 返回获得金币数.
func on_combat_win_plunder(player_id: int, enemy_strength: int) -> int:
	var loot_mult: float = get_loot_multiplier(player_id)
	var streak: int = _plunder_streak.get(player_id, 0)
	# 连续掠夺加成: 每连续回合+10%
	var streak_mult: float = 1.0 + float(streak) * 0.1

	# 基础掠夺: 敌方战力 * 3
	var base_gold: int = enemy_strength * 3
	var total_gold: int = int(float(base_gold) * loot_mult * streak_mult)

	ResourceManager.apply_delta(player_id, {"gold": total_gold})
	add_infamy(player_id, INFAMY_PER_PLUNDER)
	_plunder_streak[player_id] = streak + 1
	_plunder_streak_updated_this_turn[player_id] = true
	add_plunder_bonus(player_id, int(float(total_gold) * 0.1))

	EventBus.message_log.emit("[color=gold]海盗掠夺! 获得%d金 (敌方战力%d, 掠夺x%.1f, 连击x%.1f)[/color]" % [
		total_gold, enemy_strength, loot_mult, streak_mult])
	EventBus.resources_changed.emit(player_id)
	return total_gold


## 攻占要塞的大额金币奖励
func on_stronghold_captured(player_id: int) -> void:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.PIRATE]
	var plunder: int = get_plunder_value(player_id)
	var bonus_gold: int = plunder * params["stronghold_capture_plunder_mult"]
	ResourceManager.apply_delta(player_id, {"gold": bonus_gold})
	add_infamy(player_id, INFAMY_PER_PLUNDER * 3)
	EventBus.message_log.emit("[color=gold]海盗掠夺! 攻占要塞奖励%d金 (掠夺值%d x %d)[/color]" % [
		bonus_gold, plunder, params["stronghold_capture_plunder_mult"]])
	EventBus.resources_changed.emit(player_id)


## 获取掠夺倍率 (基础1.0, 走私者巢穴+0.5)
func get_loot_multiplier(player_id: int) -> float:
	var mult: float = 1.0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id and tile.get("building_id", "") == "smugglers_den":
			mult += 0.5
			break  # 只叠加一次
	# 高恶名额外掠夺加成
	if is_high_infamy(player_id):
		mult += 0.3
	return mult


## 内部: 掠夺连击衰减 (无战斗则重置)
func _tick_plunder_streak(player_id: int) -> void:
	# BUG修复: 如果本回合没有掠夺(连击值未被on_combat_win_plunder更新),
	# 重置连击计数器。使用标记位来追踪本回合是否有战斗发生。
	# 连击由 on_combat_win_plunder 累加并设置标记。
	# 如果标记不存在，说明本回合无战斗，重置连击。
	if _plunder_streak_updated_this_turn.get(player_id, false):
		_plunder_streak_updated_this_turn[player_id] = false
	else:
		if _plunder_streak.get(player_id, 0) > 0:
			EventBus.message_log.emit("[color=gray]无掠夺回合, 掠夺连击重置 (此前连续%d回合)[/color]" % _plunder_streak.get(player_id, 0))
			_plunder_streak[player_id] = 0


# ══════════════════════════════════════════════════════════════════════════════
# TREASURE HUNTING — 藏宝图系统
# ══════════════════════════════════════════════════════════════════════════════

## 战斗胜利后检查是否获得藏宝图 (15%概率)
func on_combat_win_treasure_check(player_id: int) -> void:
	var roll: float = randf()
	if roll <= TREASURE_MAP_DROP_CHANCE:
		_generate_treasure_map(player_id)
		EventBus.message_log.emit("[color=yellow]发现藏宝图! 去探索宝藏吧![/color]")


## 获取玩家持有的藏宝图列表
func get_treasure_maps(player_id: int) -> Array:
	return _treasure_maps.get(player_id, []).duplicate(true)


## 探索指定藏宝图. 返回奖励内容 Dictionary.
func explore_treasure(player_id: int, map_index: int) -> Dictionary:
	var maps: Array = _treasure_maps.get(player_id, [])
	if map_index < 0 or map_index >= maps.size():
		EventBus.message_log.emit("无效的藏宝图!")
		return {}

	var treasure_map: Dictionary = maps[map_index]
	maps.remove_at(map_index)
	_treasure_maps[player_id] = maps

	# 根据奖励类型发放
	var reward: Dictionary = _resolve_treasure_reward(player_id, treasure_map)
	return reward


## 内部: 生成一张随机藏宝图
func _generate_treasure_map(player_id: int) -> void:
	var maps: Array = _treasure_maps.get(player_id, [])
	if TREASURE_REWARDS.is_empty() or GameManager.tiles.is_empty():
		return
	var reward_template: Dictionary = TREASURE_REWARDS[randi() % TREASURE_REWARDS.size()]
	var tile_index: int = randi() % GameManager.tiles.size()
	var new_map: Dictionary = {
		"tile_index": tile_index,
		"reward_type": reward_template.get("type", "gold"),
		"reward_value": 0,
	}
	# 根据模板设置奖励值
	match reward_template.get("type", "gold"):
		"gold":
			new_map["reward_value"] = randi_range(
				reward_template.get("min", 50), reward_template.get("max", 200))
		"mercenary":
			new_map["reward_value"] = reward_template.get("count", 5)
		"sex_slave":
			new_map["reward_value"] = reward_template.get("count", 2)
		"rum":
			new_map["reward_value"] = reward_template.get("value", 30)
		"item":
			new_map["reward_value"] = 1
			new_map["item_id"] = reward_template.get("id", "rare_weapon")
	maps.append(new_map)
	_treasure_maps[player_id] = maps


## 内部: 解析藏宝图奖励并发放
func _resolve_treasure_reward(player_id: int, treasure_map: Dictionary) -> Dictionary:
	var reward_type: String = treasure_map.get("reward_type", "gold")
	var reward_value: int = treasure_map.get("reward_value", 50)
	var result: Dictionary = {"type": reward_type, "value": reward_value}

	match reward_type:
		"gold":
			ResourceManager.apply_delta(player_id, {"gold": reward_value})
			EventBus.message_log.emit("[color=gold]藏宝图: 发现宝箱! 获得%d金![/color]" % reward_value)
		"mercenary":
			# 直接添加佣兵到军队 (使用默认佣兵剑士)
			var merc_def: Dictionary = {}
			for m in MERCENARY_TYPES:
				if m["id"] == "merc_swordsman":
					merc_def = m
					break
			if not merc_def.is_empty():
				var merc_inst: Dictionary = _create_mercenary_instance(merc_def, reward_value)
				var army_ref: Array = RecruitManager._get_army_ref(player_id)
				army_ref.append(merc_inst)
				RecruitManager._sync_army_count(player_id)
				EventBus.army_changed.emit(player_id, RecruitManager.get_total_soldiers(player_id))
			result["unit_id"] = "merc_swordsman"
			EventBus.message_log.emit("[color=gold]藏宝图: 发现流浪佣兵%d名! 已加入军队[/color]" % reward_value)
		"sex_slave":
			var added: int = add_sex_slaves(player_id, reward_value)
			result["actual_added"] = added
			EventBus.message_log.emit("[color=pink]藏宝图: 发现被囚禁的奴隶! 获得性奴隶 +%d[/color]" % added)
		"rum":
			var current: int = _rum_morale.get(player_id, 0)
			_rum_morale[player_id] = mini(current + reward_value, 100)
			EventBus.rum_morale_changed.emit(player_id, _rum_morale[player_id])
			EventBus.message_log.emit("[color=orange]藏宝图: 发现陈年朗姆酒! 士气 +%d[/color]" % reward_value)
		"item":
			var item_id: String = treasure_map.get("item_id", "rare_weapon")
			result["item_id"] = item_id
			# 应用稀有武器效果
			var player: Dictionary = GameManager.get_player_by_id(player_id)
			player["atk_bonus"] = player.get("atk_bonus", 0) + 15
			EventBus.message_log.emit("[color=gold]藏宝图: 发现稀有武器! ATK+15![/color]")

	EventBus.resources_changed.emit(player_id)
	return result


# ══════════════════════════════════════════════════════════════════════════════
# SMUGGLING ROUTES — 走私航线 (被动收入)
# ══════════════════════════════════════════════════════════════════════════════

## 建立走私航线 (需要两个港口格子). 返回是否成功.
func establish_smuggle_route(player_id: int, tile_a: int, tile_b: int) -> bool:
	var routes: Array = _smuggle_routes.get(player_id, [])
	if routes.size() >= MAX_SMUGGLE_ROUTES:
		EventBus.message_log.emit("走私航线已达上限 (%d/%d)!" % [routes.size(), MAX_SMUGGLE_ROUTES])
		return false

	# 检查两个格子是否属于玩家且为港口
	var tile_a_data: Dictionary = _get_tile_data(tile_a)
	var tile_b_data: Dictionary = _get_tile_data(tile_b)
	if tile_a_data.is_empty() or tile_b_data.is_empty():
		EventBus.message_log.emit("无效的格子索引!")
		return false
	if tile_a_data.get("owner_id", -1) != player_id or tile_b_data.get("owner_id", -1) != player_id:
		EventBus.message_log.emit("两个港口都必须是你的领地!")
		return false

	# 检查是否已存在相同航线
	for route in routes:
		if (route[0] == tile_a and route[1] == tile_b) or (route[0] == tile_b and route[1] == tile_a):
			EventBus.message_log.emit("该航线已存在!")
			return false

	routes.append([tile_a, tile_b])
	_smuggle_routes[player_id] = routes
	EventBus.message_log.emit("[color=gold]建立走私航线! 每回合收入 +%d金 (总航线: %d)[/color]" % [
		SMUGGLE_INCOME_PER_ROUTE, routes.size()])
	return true


## 获取走私航线列表
func get_smuggle_routes(player_id: int) -> Array:
	return _smuggle_routes.get(player_id, []).duplicate(true)


## 获取走私被动收入总额
func get_smuggle_income(player_id: int) -> int:
	var routes: Array = _smuggle_routes.get(player_id, [])
	return routes.size() * SMUGGLE_INCOME_PER_ROUTE


## 销毁指定走私航线 (领地丢失时调用)
func destroy_smuggle_route(player_id: int, route_index: int) -> void:
	var routes: Array = _smuggle_routes.get(player_id, [])
	if route_index >= 0 and route_index < routes.size():
		var route: Array = routes[route_index]
		routes.remove_at(route_index)
		_smuggle_routes[player_id] = routes
		EventBus.message_log.emit("[color=red]走私航线被摧毁! 剩余航线: %d[/color]" % routes.size())


## 内部: 每回合结算走私收入
func _tick_smuggle_income(player_id: int) -> void:
	# 检查航线是否仍然有效 (两端领地是否仍属于玩家)
	var routes: Array = _smuggle_routes.get(player_id, [])
	var valid_routes: Array = []
	for route in routes:
		var tile_a: Dictionary = _get_tile_data(route[0])
		var tile_b: Dictionary = _get_tile_data(route[1])
		if tile_a.get("owner_id", -1) == player_id and tile_b.get("owner_id", -1) == player_id:
			valid_routes.append(route)
		else:
			EventBus.message_log.emit("[color=red]走私航线因领地丢失而中断![/color]")
	_smuggle_routes[player_id] = valid_routes

	var income: int = valid_routes.size() * SMUGGLE_INCOME_PER_ROUTE
	if income > 0:
		ResourceManager.apply_delta(player_id, {"gold": income})
		EventBus.message_log.emit("[color=gold]走私收入: +%d金 (%d条航线)[/color]" % [income, valid_routes.size()])
		EventBus.resources_changed.emit(player_id)


# ══════════════════════════════════════════════════════════════════════════════
# AI RAIDING SYSTEM — AI海盗突袭队
# ══════════════════════════════════════════════════════════════════════════════

## AI海盗回合: 生成突袭队, 管理现有突袭队
func ai_tick(player_id: int) -> void:
	var raids: Array = _raid_parties.get(player_id, [])

	# 更新现有突袭队
	var active_raids: Array = []
	for raid in raids:
		raid["turns_left"] = raid.get("turns_left", 0) - 1
		if raid["turns_left"] > 0:
			active_raids.append(raid)
		else:
			EventBus.message_log.emit("海盗突袭队撤退了 (格子%d)" % raid.get("tile_index", -1))
	_raid_parties[player_id] = active_raids

	# 尝试生成新突袭队
	if active_raids.size() < AI_MAX_RAID_PARTIES:
		var roll: float = randf()
		if roll <= AI_RAID_SPAWN_CHANCE:
			_spawn_raid_party(player_id)


## 内部: 生成新的突袭队
func _spawn_raid_party(player_id: int) -> void:
	var raids: Array = _raid_parties.get(player_id, [])
	var strength: int = randi_range(AI_RAID_MIN_STRENGTH, AI_RAID_MAX_STRENGTH)
	if GameManager.tiles.is_empty():
		return
	var tile_index: int = randi() % GameManager.tiles.size()
	var raid: Dictionary = {
		"tile_index": tile_index,
		"strength": strength,
		"turns_left": AI_RAID_DURATION,
	}
	raids.append(raid)
	_raid_parties[player_id] = raids
	EventBus.message_log.emit("[color=red]海盗突袭队出现! 战力%d, 位置: 格子%d[/color]" % [strength, tile_index])


## 获取所有活跃突袭队 (供UI显示)
func get_active_raids() -> Array:
	var all_raids: Array = []
	for player_id in _raid_parties:
		var raids: Array = _raid_parties[player_id]
		for raid in raids:
			var entry: Dictionary = raid.duplicate()
			entry["owner_id"] = player_id
			all_raids.append(entry)
	return all_raids


## 突袭队被击败. 返回金币掠夺奖励.
func on_raid_defeated(player_id: int, raid_index: int) -> int:
	# 从指定玩家的突袭队中查找并移除
	if not _raid_parties.has(player_id):
		return 0
	var raids: Array = _raid_parties[player_id]
	if raid_index >= 0 and raid_index < raids.size():
		var raid: Dictionary = raids[raid_index]
		raids.remove_at(raid_index)
		_raid_parties[player_id] = raids
		var loot: int = AI_RAID_LOOT_ON_DEFEAT + raid.get("strength", 0) * 3
		ResourceManager.apply_delta(player_id, {"gold": loot})
		EventBus.message_log.emit("[color=gold]击败海盗突袭队! 获得%d金![/color]" % loot)
		return loot
	return 0


# ══════════════════════════════════════════════════════════════════════════════
# MERCENARY SYSTEM — 雇佣兵系统
# ══════════════════════════════════════════════════════════════════════════════

## 获取雇佣兵费用乘数 (基础2.0, 恶名/建筑可降低)
func get_mercenary_cost_mult(player_id: int) -> float:
	var base_mult: float = 2.0
	# 高恶名降低雇佣费 (臭名远扬的海盗有更多佣兵愿意追随)
	var infamy: int = get_infamy(player_id)
	if infamy >= INFAMY_HIGH_THRESHOLD:
		base_mult -= 0.5
	elif infamy >= 50:
		base_mult -= 0.3
	# 黑市建筑降低费用
	var bm_level: int = _get_black_market_level(player_id)
	base_mult -= float(bm_level) * 0.15
	return maxf(base_mult, 0.8)


## 获取可雇佣佣兵列表 (附带调整后的价格)
func get_available_mercenaries(player_id: int) -> Array:
	var cost_mult: float = get_mercenary_cost_mult(player_id)
	var result: Array = []
	for merc in MERCENARY_TYPES:
		var entry: Dictionary = merc.duplicate()
		entry["adjusted_cost"] = maxi(int(float(merc["cost"]) * cost_mult), 1)
		result.append(entry)
	return result


## 雇佣佣兵到指定格子的军队中 (或创建新军队).
## 返回 true 表示成功, false 表示无法负担或无效类型.
func hire_mercenary(player_id: int, merc_type: String, tile_index: int) -> bool:
	# 1. 验证佣兵类型存在
	var available: Array = get_available_mercenaries(player_id)
	var merc_entry: Dictionary = {}
	for entry in available:
		if entry["id"] == merc_type:
			merc_entry = entry
			break
	if merc_entry.is_empty():
		EventBus.message_log.emit("[color=red]无效的佣兵类型: %s[/color]" % merc_type)
		return false

	# 2. 检查金币是否足够
	var gold_cost: int = merc_entry["adjusted_cost"]
	if not ResourceManager.can_afford(player_id, {"gold": gold_cost}):
		EventBus.message_log.emit("[color=red]金币不足! 雇佣%s需要%d金[/color]" % [merc_entry["name"], gold_cost])
		return false

	# 3. 扣除金币
	ResourceManager.try_spend(player_id, {"gold": gold_cost})

	# 4. 创建佣兵部队实例并加入军队
	var soldier_count: int = merc_entry.get("count", 5)
	var merc_instance: Dictionary = _create_mercenary_instance(merc_entry, soldier_count)
	var army_ref: Array = RecruitManager._get_army_ref(player_id)
	army_ref.append(merc_instance)
	RecruitManager._sync_army_count(player_id)

	# 5. 发出信号
	EventBus.message_log.emit("[color=gold]雇佣了 %s (%d兵)! 花费%d金[/color]" % [
		merc_entry["name"], soldier_count, gold_cost])
	EventBus.resources_changed.emit(player_id)
	EventBus.army_changed.emit(player_id, RecruitManager.get_total_soldiers(player_id))

	return true


## 内部: 从佣兵定义创建部队实例 (佣兵不在 TroopRegistry 中, 需自建).
func _create_mercenary_instance(merc_def: Dictionary, soldiers: int = -1) -> Dictionary:
	var count: int = soldiers if soldiers > 0 else merc_def.get("count", 5)
	var hp: int = merc_def.get("hp", 25)
	var hp_per_soldier: int = maxi(hp / maxi(merc_def.get("count", 5), 1), 3)
	return {
		"troop_id": merc_def["id"],
		"soldiers": count,
		"max_soldiers": merc_def.get("count", 5),
		"hp_per_soldier": hp_per_soldier,
		"total_hp": count * hp_per_soldier,
		"max_hp": merc_def.get("count", 5) * hp_per_soldier,
		"commander_id": "",
		"experience": 0,
		"ability_used": false,
		"is_mercenary": true,
		"name": merc_def.get("name", "佣兵"),
		"atk": merc_def.get("atk", 4),
	}


# ══════════════════════════════════════════════════════════════════════════════
# HELPER UTILITIES — 内部工具方法
# ══════════════════════════════════════════════════════════════════════════════

## 内部: 计算玩家领地数量
func _count_territory(player_id: int) -> int:
	var count: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id:
			count += 1
	return count


## 内部: 计算玩家拥有的指定建筑数量
func _count_building(player_id: int, building_id: String) -> int:
	var count: int = 0
	for tile in GameManager.tiles:
		if tile.get("owner_id", -1) == player_id and tile.get("building_id", "") == building_id:
			count += 1
	return count


## 内部: 安全获取格子数据
func _get_tile_data(tile_index: int) -> Dictionary:
	if tile_index >= 0 and tile_index < GameManager.tiles.size():
		return GameManager.tiles[tile_index]
	return {}


# ══════════════════════════════════════════════════════════════════════════════
# BACKWARD COMPATIBILITY — 旧API兼容包装
# ══════════════════════════════════════════════════════════════════════════════

## 旧版: 出售奴隶 (兼容 SlaveManager 调用)
func sell_slave(player_id: int) -> bool:
	var slave_count: int = _sex_slaves.get(player_id, 0)
	if slave_count <= 0:
		# 回退到旧的 ResourceManager 逻辑
		var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.PIRATE]
		var slaves: int = ResourceManager.get_slaves(player_id)
		if slaves <= 0:
			EventBus.message_log.emit("没有奴隶可出售!")
			return false
		SlaveManager.remove_slaves(player_id, 1)
		ResourceManager.apply_delta(player_id, {"gold": params["slave_sell_price"]})
		EventBus.message_log.emit("出售1名奴隶，获得%d金" % params["slave_sell_price"])
		return true
	# 使用新系统: 出售调教值最高的性奴隶
	var gold: int = sell_sex_slave_at_market(player_id)
	return gold > 0


## 旧版: 购买奴隶 (兼容 SlaveManager 调用)
func buy_slave(player_id: int) -> bool:
	var params: Dictionary = FactionData.FACTION_PARAMS[FactionData.FactionID.PIRATE]
	var price: int = params["slave_buy_price"]
	if not ResourceManager.can_afford(player_id, {"gold": price}):
		EventBus.message_log.emit("金币不足! 购买奴隶需要%d金" % price)
		return false
	var cap: int = ResourceManager.get_slave_capacity(player_id)
	var current: int = ResourceManager.get_slaves(player_id)
	if current >= cap:
		EventBus.message_log.emit("奴隶容量已满!")
		return false
	ResourceManager.spend(player_id, {"gold": price})
	SlaveManager.add_slaves(player_id, 1)
	EventBus.message_log.emit("购买1名奴隶，花费%d金" % price)
	return true


# ══════════════════════════════════════════════════════════════════════════════
# SAVE / LOAD
# ══════════════════════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	return {
		# 性奴隶
		"sex_slaves": _sex_slaves.duplicate(true),
		"slave_training": _slave_training.duplicate(true),
		# 恶名
		"infamy": _infamy.duplicate(true),
		# 掠夺
		"plunder_streak": _plunder_streak.duplicate(true),
		"bonus_plunder": _bonus_plunder.duplicate(true),
		# 朗姆酒
		"rum_morale": _rum_morale.duplicate(true),
		# 藏宝图
		"treasure_maps": _treasure_maps.duplicate(true),
		# 走私
		"smuggle_routes": _smuggle_routes.duplicate(true),
		# 黑市
		"market_item": _market_item.duplicate(true),
		"market_stock": _market_stock.duplicate(true),
		# AI突袭
		"raid_parties": _raid_parties.duplicate(true),
		# 掠夺连击本回合更新标记
		"plunder_streak_updated_this_turn": _plunder_streak_updated_this_turn.duplicate(true),
	}


static func _fix_int_keys(dict: Dictionary) -> void:
	var fix_keys = []
	for k in dict.keys():
		if k is String and k.is_valid_int():
			fix_keys.append(k)
	for k in fix_keys:
		dict[int(k)] = dict[k]
		dict.erase(k)


func from_save_data(data: Dictionary) -> void:
	# 性奴隶 (带旧版兼容)
	_sex_slaves = data.get("sex_slaves", {}).duplicate(true)
	_fix_int_keys(_sex_slaves)
	_slave_training = data.get("slave_training", {}).duplicate(true)
	_fix_int_keys(_slave_training)
	for pid in _slave_training:
		if _slave_training[pid] is Dictionary:
			_fix_int_keys(_slave_training[pid])
	# 恶名
	_infamy = data.get("infamy", {}).duplicate(true)
	_fix_int_keys(_infamy)
	# 掠夺
	_plunder_streak = data.get("plunder_streak", {}).duplicate(true)
	_fix_int_keys(_plunder_streak)
	# 旧版兼容: bonus_plunder
	if data.has("bonus_plunder"):
		_bonus_plunder = data.get("bonus_plunder", {}).duplicate(true)
		_fix_int_keys(_bonus_plunder)
	else:
		_bonus_plunder = {}
	# 朗姆酒
	_rum_morale = data.get("rum_morale", {}).duplicate(true)
	_fix_int_keys(_rum_morale)
	# 藏宝图
	_treasure_maps = data.get("treasure_maps", {}).duplicate(true)
	_fix_int_keys(_treasure_maps)
	# 走私
	_smuggle_routes = data.get("smuggle_routes", {}).duplicate(true)
	_fix_int_keys(_smuggle_routes)
	# 黑市
	_market_item = data.get("market_item", {}).duplicate(true)
	_fix_int_keys(_market_item)
	_market_stock = data.get("market_stock", {}).duplicate(true)
	_fix_int_keys(_market_stock)
	# AI突袭
	_raid_parties = data.get("raid_parties", {}).duplicate(true)
	_fix_int_keys(_raid_parties)
	_plunder_streak_updated_this_turn = data.get("plunder_streak_updated_this_turn", {}).duplicate(true)
	_fix_int_keys(_plunder_streak_updated_this_turn)
	# Fix int values in market_stock after JSON round-trip
	for pid in _market_stock:
		if _market_stock[pid] is Array:
			for item in _market_stock[pid]:
				if item is Dictionary:
					if item.has("price"):
						item["price"] = int(item["price"])
					if item.has("value"):
						item["value"] = int(item["value"])
	# Fix int values in _market_item after JSON round-trip
	if _market_item.has("price"):
		_market_item["price"] = int(_market_item["price"])
	if _market_item.has("value"):
		_market_item["value"] = int(_market_item["value"])
	# Fix int values in raid_parties after JSON round-trip
	for pid in _raid_parties:
		if _raid_parties[pid] is Array:
			for party in _raid_parties[pid]:
				if party is Dictionary:
					if party.has("tile_index"):
						party["tile_index"] = int(party["tile_index"])
					if party.has("strength"):
						party["strength"] = int(party["strength"])
					if party.has("turns_left"):
						party["turns_left"] = int(party["turns_left"])
	# Fix int values in treasure_maps after JSON round-trip
	for pid in _treasure_maps:
		if _treasure_maps[pid] is Array:
			for tmap in _treasure_maps[pid]:
				if tmap is Dictionary:
					if tmap.has("tile_index"):
						tmap["tile_index"] = int(tmap["tile_index"])
					if tmap.has("reward_value"):
						tmap["reward_value"] = int(tmap["reward_value"])
	# Fix int values in smuggle_routes after JSON round-trip
	for pid in _smuggle_routes:
		if _smuggle_routes[pid] is Array:
			for i in range(_smuggle_routes[pid].size()):
				var route = _smuggle_routes[pid][i]
				if route is Array:
					for j in range(route.size()):
						route[j] = int(route[j])
