## test_resource_manager.gd — Tests for ResourceManager
extends RefCounted

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg

func setup() -> void:
	ResourceManager.reset()

func test_init_player() -> String:
	ResourceManager.init_player(0, {"gold": 100, "food": 50, "iron": 25})
	var gold: int = ResourceManager.get_resource(0, "gold")
	return _assert(gold == 100, "Expected gold=100, got %d" % gold)

func test_apply_delta() -> String:
	ResourceManager.init_player(0, {"gold": 100, "food": 50, "iron": 25})
	ResourceManager.apply_delta(0, {"gold": 20, "food": -10})
	var gold: int = ResourceManager.get_resource(0, "gold")
	var food: int = ResourceManager.get_resource(0, "food")
	return _assert(gold == 120 and food == 40, "Expected gold=120 food=40, got gold=%d food=%d" % [gold, food])

func test_can_afford_true() -> String:
	ResourceManager.init_player(0, {"gold": 100, "food": 50})
	var result: bool = ResourceManager.can_afford(0, {"gold": 50, "food": 25})
	return _assert(result, "Should be able to afford")

func test_can_afford_false() -> String:
	ResourceManager.init_player(0, {"gold": 10, "food": 50})
	var result: bool = ResourceManager.can_afford(0, {"gold": 50})
	return _assert(not result, "Should not be able to afford")

func test_spend() -> String:
	ResourceManager.init_player(0, {"gold": 100})
	var spent: bool = ResourceManager.spend(0, {"gold": 30})
	var gold: int = ResourceManager.get_resource(0, "gold")
	return _assert(spent and gold == 70, "Expected spent=true gold=70, got spent=%s gold=%d" % [str(spent), gold])

func test_spend_insufficient() -> String:
	ResourceManager.init_player(0, {"gold": 10})
	var spent: bool = ResourceManager.spend(0, {"gold": 50})
	var gold: int = ResourceManager.get_resource(0, "gold")
	return _assert(not spent and gold == 10, "Should not spend when insufficient")

func test_set_resource() -> String:
	ResourceManager.init_player(0, {"gold": 0})
	ResourceManager.set_resource(0, "gold", 999)
	var gold: int = ResourceManager.get_resource(0, "gold")
	return _assert(gold == 999, "Expected gold=999, got %d" % gold)

func test_multiple_players() -> String:
	ResourceManager.init_player(0, {"gold": 100})
	ResourceManager.init_player(1, {"gold": 200})
	var g0: int = ResourceManager.get_resource(0, "gold")
	var g1: int = ResourceManager.get_resource(1, "gold")
	return _assert(g0 == 100 and g1 == 200, "Player resources should be independent")

func test_mana_initialized() -> String:
	ResourceManager.init_player(0, {"mana": 5})
	var mana: int = ResourceManager.get_resource(0, "mana")
	return _assert(mana == 5, "Expected mana=5, got %d" % mana)

func test_save_load_roundtrip() -> String:
	ResourceManager.init_player(0, {"gold": 42, "food": 13})
	var data: Dictionary = ResourceManager.to_save_data()
	ResourceManager.reset()
	ResourceManager.from_save_data(data)
	var gold: int = ResourceManager.get_resource(0, "gold")
	var food: int = ResourceManager.get_resource(0, "food")
	return _assert(gold == 42 and food == 13, "Save/load roundtrip failed: gold=%d food=%d" % [gold, food])

func test_unknown_player_returns_zero() -> String:
	ResourceManager.reset()
	var gold: int = ResourceManager.get_resource(99, "gold")
	return _assert(gold == 0, "Unknown player should return 0")
