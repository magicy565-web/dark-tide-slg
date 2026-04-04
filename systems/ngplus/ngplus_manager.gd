## ngplus_manager.gd - New Game Plus system (v1.0)
## Tracks completion count and provides carry-over bonuses.
extends Node

const MAX_NGPLUS: int = 5
const BONUS_GOLD_PER_LEVEL: int = 50
const BONUS_AP_PER_LEVEL: int = 1  # only at NG+1 and NG+3
const AI_STAT_BONUS_PCT: float = 0.10  # +10% per NG+ level
const AFFECTION_CARRY_OVER: int = 3    # heroes with lv10 start at this

# Persistent state (saved to user://ngplus.json)
var _ngplus_level: int = 0
var _completed_heroes: Array = []  # hero_ids that reached affection 10
var _total_wins: int = 0
var _last_clear_score: int = 0  # v4.7: Score from last clear, used by NGPlusShop

func _ready() -> void:
	_load_persistent()


func get_level() -> int:
	return _ngplus_level


func get_total_wins() -> int:
	return _total_wins


func get_bonus_gold() -> int:
	return _ngplus_level * BONUS_GOLD_PER_LEVEL


func get_bonus_ap() -> int:
	if _ngplus_level >= 3:
		return 2
	elif _ngplus_level >= 1:
		return 1
	return 0


func get_ai_stat_mult() -> float:
	return 1.0 + _ngplus_level * AI_STAT_BONUS_PCT


func get_hero_carry_over_affection(hero_id: String) -> int:
	if hero_id in _completed_heroes:
		return AFFECTION_CARRY_OVER
	return 0


func get_completed_heroes() -> Array:
	return _completed_heroes.duplicate()


func is_ngplus() -> bool:
	return _ngplus_level > 0


## Called when player wins. Records progress and increments NG+ level.
func on_victory() -> void:
	_total_wins += 1
	# Record all heroes at affection 10
	for hero_id in HeroSystem.hero_affection:
		if HeroSystem.hero_affection[hero_id] >= 10 and hero_id not in _completed_heroes:
			_completed_heroes.append(hero_id)
	_ngplus_level = mini(_ngplus_level + 1, MAX_NGPLUS)
	# v4.7: Calculate and save final score for NGPlusShop
	var final_score: int = _calculate_victory_score()
	_last_clear_score = final_score
	EventBus.message_log.emit("[color=gold]通关得分: %d 分 (可在下周目开局兑换奖励)[/color]" % final_score)
	_save_persistent()


## v7.0: Calculate the final victory score based on game state (enhanced scoring).
func _calculate_victory_score() -> int:
	var score: int = 500  # Base score for winning
	# Bonus: heroes at affection 10 (+100 each)
	var max_affection_heroes: int = 0
	for hero_id in HeroSystem.hero_affection:
		if HeroSystem.hero_affection[hero_id] >= 10:
			score += 100
			max_affection_heroes += 1
	# Bonus: territories controlled (+10 per territory)
	if GameManager != null:
		var pid: int = GameManager.get_human_player_id()
		var owned: int = GameManager.get_cached_owned_tiles(pid).size() if GameManager.has_method("get_cached_owned_tiles") else 0
		score += owned * 10
	# Bonus: turn efficiency (faster clear = more points)
	var turn_bonus: int = maxi(0, 300 - GameManager.turn_number * 3) if GameManager != null else 0
	score += turn_bonus
	# Bonus: resources remaining (+1 per 10 gold)
	if ResourceManager != null and GameManager != null:
		var pid2: int = GameManager.get_human_player_id()
		var gold_left: int = ResourceManager.get_resource(pid2, "gold")
		score += gold_left / 10
	# Bonus: prestige earned (+1 per prestige)
	if ResourceManager != null and GameManager != null:
		var pid3: int = GameManager.get_human_player_id()
		var prestige: int = ResourceManager.get_resource(pid3, "prestige")
		score += prestige
	# Bonus: NG+ level multiplier
	score = int(float(score) * (1.0 + float(_ngplus_level) * 0.1))
	# v1.1: Hard mode bonus (挑战剧本通关得分×1.5)
	if NGPlusShop != null and NGPlusShop.is_hard_mode_active():
		score = int(float(score) * 1.5)
	# Log score breakdown
	EventBus.message_log.emit("[color=gold]得分明细: 基础500 + 英雄好感%d + 领地%d + 速通%d + 资源+威望[/color]" % [
		max_affection_heroes * 100, (score - 500 - max_affection_heroes * 100 - turn_bonus) / 10 * 10, turn_bonus])
	return score


## v4.7: Get the score from the last clear (for NGPlusShop).
func get_last_clear_score() -> int:
	return _last_clear_score


## v4.7: Initialize NGPlusShop with last clear score at game start.
func init_ngplus_shop() -> void:
	if _last_clear_score > 0:
		NGPlusShop.initialize(_last_clear_score)
		EventBus.message_log.emit("[color=gold]NG+得分商店已开启！上周目得分: %d 分[/color]" % _last_clear_score)


## Apply NG+ bonuses at game start.
func apply_bonuses(player_id: int) -> void:
	if _ngplus_level <= 0:
		return
	# Gold bonus
	var gold_bonus: int = get_bonus_gold()
	if gold_bonus > 0:
		ResourceManager.apply_delta(player_id, {"gold": gold_bonus})
		EventBus.message_log.emit("[color=gold]NG+%d: 起始金币 +%d[/color]" % [_ngplus_level, gold_bonus])
	# AP bonus applied via get_bonus_ap() in calculate_action_points
	# Hero affection carry-over
	var carried: int = 0
	for hero_id in _completed_heroes:
		if HeroSystem.hero_affection.get(hero_id, 0) < AFFECTION_CARRY_OVER:
			HeroSystem.hero_affection[hero_id] = AFFECTION_CARRY_OVER
			carried += 1
	if carried > 0:
		EventBus.message_log.emit("[color=gold]NG+%d: %d名英雄好感度继承 (Lv%d)[/color]" % [_ngplus_level, carried, AFFECTION_CARRY_OVER])
	EventBus.message_log.emit("[color=gold]NG+%d: 敌方AI增强 +%d%%[/color]" % [_ngplus_level, int(_ngplus_level * AI_STAT_BONUS_PCT * 100)])


# ── Persistence (separate from save games) ──

const NGPLUS_PATH: String = "user://ngplus.json"

func _save_persistent() -> void:
	var data: Dictionary = {
		"ngplus_level": _ngplus_level,
		"completed_heroes": _completed_heroes.duplicate(),
		"total_wins": _total_wins,
		"last_clear_score": _last_clear_score,  # v4.7
	}
	var file := FileAccess.open(NGPLUS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _load_persistent() -> void:
	if not FileAccess.file_exists(NGPLUS_PATH):
		return
	var file := FileAccess.open(NGPLUS_PATH, FileAccess.READ)
	if not file:
		return
	var text: String = file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var data: Variant = json.data
	if data is Dictionary:
		_ngplus_level = data.get("ngplus_level", 0)
		_completed_heroes = data.get("completed_heroes", [])
		_total_wins = data.get("total_wins", 0)
		_last_clear_score = data.get("last_clear_score", 0)  # v4.7


func reset_ngplus() -> void:
	## Debug/cheat: reset NG+ progress.
	_ngplus_level = 0
	_completed_heroes.clear()
	_total_wins = 0
	_last_clear_score = 0  # v4.7
	_save_persistent()
