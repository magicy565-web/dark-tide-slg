## test_victory_conditions.gd — Tests for victory conditions, hero roster, story data integrity
extends RefCounted

const FactionData = preload("res://systems/faction/faction_data.gd")

func _assert(condition: bool, msg: String) -> String:
	return "PASS" if condition else msg

# ── 1. Domination threshold ──

func test_dominance_victory_pct_is_075() -> String:
	return _assert(BalanceConfig.DOMINANCE_VICTORY_PCT == 0.75, "DOMINANCE_VICTORY_PCT should be 0.75, got %f" % BalanceConfig.DOMINANCE_VICTORY_PCT)

# ── 2. Harem victory constants ──

func test_harem_victory_submission_min_is_7() -> String:
	return _assert(FactionData.HAREM_VICTORY_SUBMISSION_MIN == 7, "HAREM_VICTORY_SUBMISSION_MIN should be 7, got %d" % FactionData.HAREM_VICTORY_SUBMISSION_MIN)

# ── 3. Hero roster completeness ──

func test_heroes_count_is_18() -> String:
	return _assert(FactionData.HEROES.size() == 18, "HEROES should have 18 entries, got %d" % FactionData.HEROES.size())

func test_all_18_hero_ids_present() -> String:
	var expected_ids: Array = [
		"rin", "yukino", "momiji", "hyouka",
		"suirei", "gekka", "hakagure",
		"sou", "shion", "homura",
		"shion_pirate", "youya",
		"hibiki", "sara", "mei", "kaede", "akane", "hanabi",
	]
	for hid in expected_ids:
		if not FactionData.HEROES.has(hid):
			return "Hero '%s' missing from HEROES dict" % hid
	return "PASS"

# ── 4. Hero data integrity ──

func test_hero_data_has_required_fields() -> String:
	var required_fields: Array = ["name", "faction", "troop", "atk", "def", "int", "spd", "capture_chance", "active", "passive", "preferred_gift"]
	for hero_id in FactionData.HEROES:
		var hero: Dictionary = FactionData.HEROES[hero_id]
		for field in required_fields:
			if not hero.has(field):
				return "Hero '%s' missing field '%s'" % [hero_id, field]
	return "PASS"

func test_hero_atk_positive() -> String:
	for hero_id in FactionData.HEROES:
		var hero: Dictionary = FactionData.HEROES[hero_id]
		if hero.get("atk", 0) <= 0:
			return "Hero '%s' ATK should be positive" % hero_id
	return "PASS"

func test_hero_capture_chance_valid_range() -> String:
	for hero_id in FactionData.HEROES:
		var hero: Dictionary = FactionData.HEROES[hero_id]
		var cc: float = hero.get("capture_chance", -1.0)
		if cc < 0.0 or cc > 1.0:
			return "Hero '%s' capture_chance %.2f out of [0,1] range" % [hero_id, cc]
	return "PASS"

# ── 5. Exclusive endings ──

func test_story_files_have_exclusive_ending() -> String:
	var story_files: Dictionary = {
		"rin":      "res://systems/story/data/rin_story.gd",
		"yukino":   "res://systems/story/data/yukino_story.gd",
		"momiji":   "res://systems/story/data/momiji_story.gd",
		"hyouka":   "res://systems/story/data/hyouka_story.gd",
		"suirei":   "res://systems/story/data/suirei_story.gd",
		"gekka":    "res://systems/story/data/gekka_story.gd",
		"hakagure": "res://systems/story/data/hakagure_story.gd",
		"sou":      "res://systems/story/data/sou_story.gd",
		"shion":    "res://systems/story/data/shion_story.gd",
		"homura":   "res://systems/story/data/homura_story.gd",
		"hibiki":   "res://systems/story/data/hibiki_story.gd",
		"sara":     "res://systems/story/data/sara_story.gd",
		"mei":      "res://systems/story/data/mei_story.gd",
		"kaede":    "res://systems/story/data/kaede_story.gd",
		"akane":    "res://systems/story/data/akane_story.gd",
		"hanabi":   "res://systems/story/data/hanabi_story.gd",
	}
	for hero_id in story_files:
		var script: GDScript = load(story_files[hero_id])
		var src: String = script.source_code
		if not src.contains("\"exclusive_ending\""):
			return "Story file for '%s' missing 'exclusive_ending' section" % hero_id
	return _assert(story_files.size() == 16, "Expected 16 story data files, got %d" % story_files.size())

# ── 6. Balance config ──

func test_starting_gold_is_600() -> String:
	return _assert(BalanceConfig.STARTING_GOLD == 600, "STARTING_GOLD should be 600, got %d" % BalanceConfig.STARTING_GOLD)

func test_cannon_atk_is_17() -> String:
	var cannon_def: Dictionary = FactionData.SHARED_UNIT_DEFS.get("cannon", {})
	return _assert(cannon_def.get("atk", 0) == 17, "cannon ATK should be 17, got %d" % cannon_def.get("atk", 0))
