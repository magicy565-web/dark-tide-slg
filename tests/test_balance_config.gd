## test_balance_config.gd — Tests for BalanceConfig constants
extends RefCounted

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg

func test_xp_constants_positive() -> String:
	return _assert(BalanceConfig.COMBAT_XP_WIN > 0 and BalanceConfig.COMBAT_XP_LOSS >= 0, "XP constants should be non-negative")

func test_starting_gold_positive() -> String:
	return _assert(BalanceConfig.STARTING_GOLD > 0, "Starting gold should be positive")

func test_starting_food_positive() -> String:
	return _assert(BalanceConfig.STARTING_FOOD > 0, "Starting food should be positive")

func test_starting_iron_positive() -> String:
	return _assert(BalanceConfig.STARTING_IRON > 0, "Starting iron should be positive")

func test_max_troops_positive() -> String:
	return _assert(BalanceConfig.MAX_TROOPS_PER_ARMY > 0, "Max troops per army should be positive")

func test_tile_max_level_positive() -> String:
	return _assert(BalanceConfig.TILE_MAX_LEVEL > 0, "Tile max level should be positive")

func test_gold_per_node_level_monotonic() -> String:
	var arr: Array = BalanceConfig.GOLD_PER_NODE_LEVEL
	for i in range(1, arr.size()):
		if arr[i] < arr[i - 1]:
			return "Gold per node level not monotonic at index %d" % i
	return "PASS"

func test_food_per_soldier_positive() -> String:
	return _assert(BalanceConfig.FOOD_PER_SOLDIER > 0, "Food per soldier should be positive")

func test_tier_upkeep_exists() -> String:
	return _assert(BalanceConfig.TIER_GOLD_UPKEEP.size() > 0, "Tier upkeep should have entries")

func test_combat_xp_win_gt_loss() -> String:
	return _assert(BalanceConfig.COMBAT_XP_WIN >= BalanceConfig.COMBAT_XP_LOSS, "Win XP should be >= loss XP")

func test_order_prod_mult_exists() -> String:
	return _assert(BalanceConfig.ORDER_PROD_MULT.has("normal"), "ORDER_PROD_MULT should have 'normal' key")

func test_max_level_hero() -> String:
	return _assert(HeroLeveling.MAX_LEVEL > 0, "Hero max level should be positive")
