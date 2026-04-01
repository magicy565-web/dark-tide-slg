## treaty_system.gd - Formal alliance, trade, and tribute mechanics (v4.3)
## Extends the diplomacy framework with structured treaties, reputation tracking, and AI logic.
extends Node

const FactionData = preload("res://systems/faction/faction_data.gd")

# ═══════════════════════════════════════════════════════════════
#                      ENUMS & CONSTANTS
# ═══════════════════════════════════════════════════════════════

enum TreatyType {
	CEASEFIRE,           # No attacks for N turns
	NON_AGGRESSION,      # Longer peace pact
	TRADE_AGREEMENT,     # +15% gold income for both parties
	MILITARY_ACCESS,     # Move through each other's territory
	DEFENSIVE_ALLIANCE,  # Help defend if attacked
	OFFENSIVE_ALLIANCE,  # Joint attacks, +10% ATK vs shared target
	VASSALAGE,           # One party pays tribute
	CONFEDERATION,       # Full merge (endgame)
}

const TREATY_NAMES: Dictionary = {
	TreatyType.CEASEFIRE: "停战协定",
	TreatyType.NON_AGGRESSION: "互不侵犯条约",
	TreatyType.TRADE_AGREEMENT: "贸易协定",
	TreatyType.MILITARY_ACCESS: "军事通行权",
	TreatyType.DEFENSIVE_ALLIANCE: "防御同盟",
	TreatyType.OFFENSIVE_ALLIANCE: "攻守同盟",
	TreatyType.VASSALAGE: "朝贡关系",
	TreatyType.CONFEDERATION: "邦联合并",
}

# Minimum reputation required to propose each treaty type
const TREATY_REP_THRESHOLD: Dictionary = {
	TreatyType.CEASEFIRE: -50,
	TreatyType.NON_AGGRESSION: -20,
	TreatyType.TRADE_AGREEMENT: 0,
	TreatyType.MILITARY_ACCESS: 10,
	TreatyType.DEFENSIVE_ALLIANCE: 25,
	TreatyType.OFFENSIVE_ALLIANCE: 40,
	TreatyType.VASSALAGE: -30,
	TreatyType.CONFEDERATION: 60,
}

# Reputation penalty when breaking each treaty type
const TREATY_BREAK_PENALTY: Dictionary = {
	TreatyType.CEASEFIRE: -20,
	TreatyType.NON_AGGRESSION: -25,
	TreatyType.TRADE_AGREEMENT: -20,
	TreatyType.MILITARY_ACCESS: -25,
	TreatyType.DEFENSIVE_ALLIANCE: -40,
	TreatyType.OFFENSIVE_ALLIANCE: -45,
	TreatyType.VASSALAGE: -30,
	TreatyType.CONFEDERATION: -50,
}

# Default durations (turns); -1 = permanent until broken
const TREATY_DEFAULT_DURATION: Dictionary = {
	TreatyType.CEASEFIRE: 5,
	TreatyType.NON_AGGRESSION: 10,
	TreatyType.TRADE_AGREEMENT: -1,
	TreatyType.MILITARY_ACCESS: 8,
	TreatyType.DEFENSIVE_ALLIANCE: -1,
	TreatyType.OFFENSIVE_ALLIANCE: -1,
	TreatyType.VASSALAGE: -1,
	TreatyType.CONFEDERATION: -1,
}

# Reputation tier thresholds and labels (ascending order)
const REPUTATION_TIERS: Array = [
	{"min": -100, "label": "唾弃"},
	{"min": -60,  "label": "敌视"},
	{"min": -20,  "label": "冷淡"},
	{"min": -5,   "label": "中立"},
	{"min": 20,   "label": "友善"},
	{"min": 50,   "label": "尊敬"},
	{"min": 80,   "label": "盟友"},
]

const REPUTATION_HONOR_PER_TURN: int = 5
const REPUTATION_DECAY_RATE: int = 1
const REPUTATION_MIN: int = -100
const REPUTATION_MAX: int = 100

# ═══════════════════════════════════════════════════════════════
#                      STATE
# ═══════════════════════════════════════════════════════════════

var _active_treaties: Array = []    # Array of TreatyData dicts
var _pending_proposals: Array = []  # Array of proposal dicts awaiting response
var _reputation: Dictionary = {}    # {faction_key: int} range -100..100
var _next_id: int = 1               # Auto-increment for treaty/proposal IDs

# ═══════════════════════════════════════════════════════════════
#                      LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	pass

func reset() -> void:
	_active_treaties.clear()
	_pending_proposals.clear()
	_reputation.clear()
	_next_id = 1

func init_faction(faction_key: String) -> void:
	## Initialize reputation entry for a faction if missing.
	if not _reputation.has(faction_key):
		_reputation[faction_key] = 0

# ═══════════════════════════════════════════════════════════════
#                  TREATY PROPOSAL & ACCEPTANCE
# ═══════════════════════════════════════════════════════════════

func propose_treaty(proposer_id: int, target_id: int, treaty_type: int, terms: Dictionary = {}) -> Dictionary:
	## Create a treaty proposal. Returns the proposal dict (with "id" and "valid" fields).
	## The caller should present this to the target for acceptance.
	var proposal_id: String = _generate_id("prop")
	var rep_key: String = _player_to_faction_key(target_id)
	var current_rep: int = get_reputation(rep_key)
	var threshold: int = TREATY_REP_THRESHOLD.get(treaty_type, 0)

	# Validate: reputation must meet threshold
	if current_rep < threshold:
		var t_name: String = TREATY_NAMES.get(treaty_type, "未知")
		EventBus.message_log.emit("[color=red]声望不足，无法提议%s (需要%d, 当前%d)[/color]" % [t_name, threshold, current_rep])
		return {"id": proposal_id, "valid": false, "reason": "reputation_too_low"}

	# Validate: cannot have duplicate active treaty of same type
	if has_treaty_type(proposer_id, target_id, treaty_type):
		return {"id": proposal_id, "valid": false, "reason": "already_exists"}

	# Validate: confederation requires existing defensive alliance
	if treaty_type == TreatyType.CONFEDERATION:
		if not has_treaty_type(proposer_id, target_id, TreatyType.DEFENSIVE_ALLIANCE):
			return {"id": proposal_id, "valid": false, "reason": "requires_defensive_alliance"}

	var duration: int = terms.get("duration", TREATY_DEFAULT_DURATION.get(treaty_type, -1))
	var reputation_stake: int = abs(TREATY_BREAK_PENALTY.get(treaty_type, -20))

	var proposal: Dictionary = {
		"id": proposal_id,
		"valid": true,
		"type": treaty_type,
		"proposer_id": proposer_id,
		"target_id": target_id,
		"terms": terms,
		"duration": duration,
		"reputation_stake": reputation_stake,
		"proposed_turn": _get_current_turn(),
	}
	_pending_proposals.append(proposal)
	var t_name: String = TREATY_NAMES.get(treaty_type, "未知")
	EventBus.message_log.emit("[color=yellow]已向对方提议: %s[/color]" % t_name)
	return proposal

func accept_treaty(proposal_id: String) -> bool:
	## Accept a pending proposal, creating an active treaty. Returns true on success.
	var proposal: Dictionary = _find_proposal(proposal_id)
	if proposal.is_empty():
		return false

	var treaty: Dictionary = _build_treaty_data(proposal)
	_active_treaties.append(treaty)
	_pending_proposals.erase(proposal)

	var t_name: String = TREATY_NAMES.get(treaty["type"], "未知")
	EventBus.message_log.emit("[color=green]%s 已签署![/color]" % t_name)
	EventBus.treaty_signed.emit(treaty["party_a"], t_name, treaty["party_b"])

	# Both parties gain a small reputation boost on signing
	var key_a: String = _player_to_faction_key(treaty["party_a"])
	var key_b: String = _player_to_faction_key(treaty["party_b"])
	modify_reputation(key_a, 5)
	modify_reputation(key_b, 5)
	return true

func reject_treaty(proposal_id: String) -> void:
	## Reject a pending proposal. Minor reputation impact.
	var proposal: Dictionary = _find_proposal(proposal_id)
	if proposal.is_empty():
		return
	_pending_proposals.erase(proposal)
	var t_name: String = TREATY_NAMES.get(proposal.get("type", -1), "未知")
	EventBus.message_log.emit("[color=gray]%s 提议被拒绝[/color]" % t_name)
	# Small reputation penalty for rejecting
	var rep_key: String = _player_to_faction_key(proposal.get("proposer_id", -1))
	modify_reputation(rep_key, -3)

func break_treaty(treaty_id: String, breaker_id: int) -> void:
	## Unilaterally break an active treaty. Incurs reputation penalty on the breaker.
	var treaty: Dictionary = _find_treaty(treaty_id)
	if treaty.is_empty():
		return

	var penalty: int = TREATY_BREAK_PENALTY.get(treaty["type"], -20)
	var t_name: String = TREATY_NAMES.get(treaty["type"], "未知")

	# Determine the other party
	var other_id: int = treaty["party_b"] if treaty["party_a"] == breaker_id else treaty["party_a"]

	# Apply reputation penalty to the breaker from the other party's perspective
	var breaker_key: String = _player_to_faction_key(breaker_id)
	modify_reputation(breaker_key, penalty)

	# Global treachery signal — other factions also lose trust
	@warning_ignore("integer_division")
	var cascade_penalty: int = penalty / 3
	for fkey in _reputation.keys():
		if fkey != breaker_key and fkey != _player_to_faction_key(other_id):
			modify_reputation(fkey, cascade_penalty)

	_remove_treaty(treaty_id)
	EventBus.message_log.emit("[color=red]%s 被撕毁! 声望 %d[/color]" % [t_name, penalty])
	EventBus.treaty_broken.emit(breaker_id, t_name, other_id)
	EventBus.treaty_break_cascade.emit(_count_broken_treaties(breaker_id))

func get_active_treaties(player_id: int) -> Array:
	## Return all active treaties involving a given player.
	var result: Array = []
	for t in _active_treaties:
		if t["party_a"] == player_id or t["party_b"] == player_id:
			result.append(t)
	return result

func get_treaties_with(player_a: int, player_b: int) -> Array:
	## Return all active treaties between two specific parties.
	var result: Array = []
	for t in _active_treaties:
		var matches_ab: bool = t["party_a"] == player_a and t["party_b"] == player_b
		var matches_ba: bool = t["party_a"] == player_b and t["party_b"] == player_a
		if matches_ab or matches_ba:
			result.append(t)
	return result

func has_treaty_type(player_a: int, player_b: int, type: int) -> bool:
	## Check whether a specific treaty type exists between two parties.
	for t in get_treaties_with(player_a, player_b):
		if t["type"] == type:
			return true
	return false

func get_pending_proposals(target_id: int) -> Array:
	## Return all pending proposals addressed to a target.
	var result: Array = []
	for p in _pending_proposals:
		if p["target_id"] == target_id:
			result.append(p)
	return result

# ═══════════════════════════════════════════════════════════════
#                  TURN PROCESSING & EFFECTS
# ═══════════════════════════════════════════════════════════════

func process_turn(player_id: int) -> void:
	## Called once per turn for a player. Expires treaties, applies effects, ticks reputation.
	_expire_treaties(player_id)
	_apply_treaty_effects(player_id)
	_collect_tribute(player_id)
	_tick_reputation(player_id)

func _apply_treaty_effects(player_id: int) -> void:
	## Apply per-turn bonuses from active treaties for the given player.
	for treaty in get_active_treaties(player_id):
		match treaty["type"]:
			TreatyType.TRADE_AGREEMENT:
				# +15% gold production handled via get_gold_bonus_percent() query
				pass
			TreatyType.DEFENSIVE_ALLIANCE:
				# Honor bonus for maintaining alliance
				var partner_key: String = _get_partner_key(treaty, player_id)
				modify_reputation(partner_key, REPUTATION_HONOR_PER_TURN)
			TreatyType.OFFENSIVE_ALLIANCE:
				var partner_key: String = _get_partner_key(treaty, player_id)
				modify_reputation(partner_key, REPUTATION_HONOR_PER_TURN)
			TreatyType.CONFEDERATION:
				# Confederation: honor + shared stat bonus (queried externally)
				var partner_key: String = _get_partner_key(treaty, player_id)
				modify_reputation(partner_key, REPUTATION_HONOR_PER_TURN + 2)
			TreatyType.NON_AGGRESSION:
				# Mild reputation gain for keeping the peace
				var partner_key: String = _get_partner_key(treaty, player_id)
				modify_reputation(partner_key, 2)
			_:
				pass

func _expire_treaties(player_id: int) -> void:
	## Decrement duration on timed treaties and remove expired ones.
	var expired: Array = []
	for treaty in _active_treaties:
		# Only tick duration from party_a's perspective to avoid double-counting
		if treaty["party_a"] != player_id:
			continue
		if treaty["duration"] == -1:
			continue
		treaty["duration"] -= 1
		if treaty["duration"] <= 0:
			expired.append(treaty)

	for treaty in expired:
		var t_name: String = TREATY_NAMES.get(treaty["type"], "未知")
		EventBus.message_log.emit("[color=gray]%s 已到期[/color]" % t_name)
		EventBus.treaty_expired.emit(treaty["party_a"], t_name, treaty["party_b"])
		_active_treaties.erase(treaty)

func _collect_tribute(player_id: int) -> void:
	## Process vassalage tribute payments. Vassal (party_b) pays lord (party_a).
	for treaty in _active_treaties:
		if treaty["type"] != TreatyType.VASSALAGE:
			continue
		# Tribute flows from party_b (vassal) to party_a (lord)
		var lord_id: int = treaty["party_a"]
		var vassal_id: int = treaty["party_b"]
		if lord_id != player_id and vassal_id != player_id:
			continue
		# Only process once per turn from the lord's turn
		if player_id != lord_id:
			continue

		var tribute_rate: float = treaty["terms"].get("tribute_rate", 0.20)
		var vassal_gold: int = _get_player_gold_income(vassal_id)
		var tribute_amount: int = int(vassal_gold * tribute_rate)
		if tribute_amount <= 0:
			continue

		# Transfer gold
		_transfer_gold(vassal_id, lord_id, tribute_amount)
		EventBus.message_log.emit("[color=gold]收到朝贡: %d 金币[/color]" % tribute_amount)
		EventBus.tribute_received.emit(lord_id, vassal_id, tribute_amount)

func _tick_reputation(player_id: int) -> void:
	## Natural reputation decay toward neutral for factions without active treaties.
	var treaty_partners: Dictionary = {}
	for treaty in get_active_treaties(player_id):
		var partner_key: String = _get_partner_key(treaty, player_id)
		treaty_partners[partner_key] = true

	for fkey in _reputation.keys():
		if treaty_partners.has(fkey):
			continue  # Active treaties handle their own reputation changes
		# Decay toward 0
		if _reputation[fkey] > 0:
			_reputation[fkey] = maxi(_reputation[fkey] - REPUTATION_DECAY_RATE, 0)
		elif _reputation[fkey] < 0:
			_reputation[fkey] = mini(_reputation[fkey] + REPUTATION_DECAY_RATE, 0)

# ═══════════════════════════════════════════════════════════════
#                  REPUTATION SYSTEM
# ═══════════════════════════════════════════════════════════════

func get_reputation(faction_key: String) -> int:
	## Return current reputation with a faction. Defaults to 0 if unknown.
	return _reputation.get(faction_key, 0)

func modify_reputation(faction_key: String, delta: int) -> void:
	## Adjust reputation with a faction, clamped to [-100, 100].
	if not _reputation.has(faction_key):
		_reputation[faction_key] = 0
	var old_val: int = _reputation[faction_key]
	_reputation[faction_key] = clampi(old_val + delta, REPUTATION_MIN, REPUTATION_MAX)
	var new_val: int = _reputation[faction_key]

	# Check for tier crossing
	var old_tier: String = _tier_label_for(old_val)
	var new_tier: String = _tier_label_for(new_val)
	if old_tier != new_tier:
		EventBus.reputation_threshold_crossed.emit(faction_key, old_tier, new_tier)
		EventBus.message_log.emit("[color=yellow]与 %s 的关系变为: %s[/color]" % [faction_key, new_tier])

func get_reputation_tier(faction_key: String) -> String:
	## Return the Chinese label for the current reputation tier.
	var val: int = get_reputation(faction_key)
	return _tier_label_for(val)

func _tier_label_for(value: int) -> String:
	## Internal: map a reputation integer to its tier label.
	var label: String = REPUTATION_TIERS[0]["label"]
	for tier in REPUTATION_TIERS:
		if value >= tier["min"]:
			label = tier["label"]
	return label

# ═══════════════════════════════════════════════════════════════
#                  TREATY EFFECT QUERIES
# ═══════════════════════════════════════════════════════════════

func get_gold_bonus_percent(player_id: int) -> float:
	## Total gold production bonus (%) from all trade agreements and confederation.
	var bonus: float = 0.0
	for treaty in get_active_treaties(player_id):
		if treaty["type"] == TreatyType.TRADE_AGREEMENT:
			bonus += 0.15
		elif treaty["type"] == TreatyType.CONFEDERATION:
			bonus += 0.05  # Confederation also provides minor trade bonus
	return bonus

func has_military_access(player_id: int, territory_owner_id: int) -> bool:
	## Check if player_id has military access through territory_owner_id's tiles.
	if has_treaty_type(player_id, territory_owner_id, TreatyType.MILITARY_ACCESS):
		return true
	if has_treaty_type(player_id, territory_owner_id, TreatyType.CONFEDERATION):
		return true
	return false

func get_defense_bonus(player_id: int) -> float:
	## Total DEF bonus from vassalage (as vassal) and confederation.
	var bonus: float = 0.0
	for treaty in get_active_treaties(player_id):
		if treaty["type"] == TreatyType.VASSALAGE and treaty["party_b"] == player_id:
			# Vassal receives +15% DEF from lord
			bonus += 0.15
		elif treaty["type"] == TreatyType.CONFEDERATION:
			bonus += 0.05
	return bonus

func get_attack_bonus(player_id: int, target_tile: int) -> float:
	## ATK bonus from offensive alliance when attacking a shared target.
	## target_tile is used to check if an ally is also attacking or adjacent.
	var bonus: float = 0.0
	for treaty in get_active_treaties(player_id):
		if treaty["type"] == TreatyType.OFFENSIVE_ALLIANCE:
			bonus += 0.10
		elif treaty["type"] == TreatyType.CONFEDERATION:
			bonus += 0.05
	return bonus

func get_confederation_stat_bonus(player_id: int) -> float:
	## Flat +5% all stats bonus if player has any confederation treaty.
	for treaty in get_active_treaties(player_id):
		if treaty["type"] == TreatyType.CONFEDERATION:
			return 0.05
	return 0.0

func get_vassalage_info(player_id: int) -> Array:
	## Return array of {lord_id, vassal_id, tribute_rate} for all vassalage treaties involving player.
	var result: Array = []
	for treaty in get_active_treaties(player_id):
		if treaty["type"] == TreatyType.VASSALAGE:
			result.append({
				"lord_id": treaty["party_a"],
				"vassal_id": treaty["party_b"],
				"tribute_rate": treaty["terms"].get("tribute_rate", 0.20),
				"treaty_id": treaty["id"],
			})
	return result

func is_attack_forbidden(attacker_id: int, defender_id: int) -> bool:
	## Returns true if any active treaty forbids attacking the defender.
	for treaty in get_treaties_with(attacker_id, defender_id):
		if treaty["type"] in [
			TreatyType.CEASEFIRE,
			TreatyType.NON_AGGRESSION,
			TreatyType.DEFENSIVE_ALLIANCE,
			TreatyType.OFFENSIVE_ALLIANCE,
			TreatyType.CONFEDERATION,
		]:
			return true
	return false

func get_defensive_allies(defender_id: int) -> Array:
	## Return IDs of all factions that must be notified (defensive alliance) when defender is attacked.
	var allies: Array = []
	for treaty in get_active_treaties(defender_id):
		if treaty["type"] in [TreatyType.DEFENSIVE_ALLIANCE, TreatyType.CONFEDERATION]:
			var ally_id: int = treaty["party_b"] if treaty["party_a"] == defender_id else treaty["party_a"]
			if ally_id != defender_id and ally_id not in allies:
				allies.append(ally_id)
	return allies

# ═══════════════════════════════════════════════════════════════
#                  AI TREATY LOGIC
# ═══════════════════════════════════════════════════════════════

func ai_evaluate_proposal(ai_id: int, proposal: Dictionary) -> bool:
	## AI decision: should we accept this treaty proposal?
	## Considers threat level, relative strength, reputation, and existing treaties.
	var proposer_id: int = proposal.get("proposer_id", -1)
	var treaty_type: int = proposal.get("type", -1)
	var proposer_key: String = _player_to_faction_key(proposer_id)
	var rep: int = get_reputation(proposer_key)

	# Base acceptance score starts from reputation (-100..100 mapped to -50..50)
	var score: float = float(rep) * 0.5

	# Threat modifier: higher threat from third parties makes alliances more attractive
	var threat: float = _ai_threat_score(ai_id)
	var strength_ratio: float = _ai_strength_ratio(ai_id, proposer_id)

	match treaty_type:
		TreatyType.CEASEFIRE:
			# Eagerly accept if losing (strength_ratio < 1.0)
			score += (1.0 - strength_ratio) * 40.0
			score += threat * 20.0
		TreatyType.NON_AGGRESSION:
			score += (1.0 - strength_ratio) * 30.0
			score += threat * 15.0
		TreatyType.TRADE_AGREEMENT:
			# Almost always beneficial, bias toward accepting
			score += 25.0
			# Weaker economy = more eager
			var ai_gold: int = _get_player_gold_income(ai_id)
			if ai_gold < 50:
				score += 20.0
		TreatyType.MILITARY_ACCESS:
			# Risky; only accept if trusted
			score += rep * 0.3
			if strength_ratio > 1.5:
				score -= 20.0  # Dominant AI doesn't need access
		TreatyType.DEFENSIVE_ALLIANCE:
			score += threat * 30.0
			score += (1.0 - strength_ratio) * 25.0
			# Common enemy bonus: if both share an aggressive neighbor
			if _share_common_enemy(ai_id, proposer_id):
				score += 30.0
		TreatyType.OFFENSIVE_ALLIANCE:
			score += threat * 20.0
			if _share_common_enemy(ai_id, proposer_id):
				score += 40.0
			if strength_ratio > 2.0:
				score -= 30.0  # Already dominant, no need
		TreatyType.VASSALAGE:
			# AI almost never willingly becomes vassal unless desperate
			if proposal.get("terms", {}).get("vassal_id", -1) == ai_id:
				score -= 50.0
				if strength_ratio < 0.3:
					score += 60.0  # Desperate: accept vassalage to survive
			else:
				# Being the lord is great
				score += 40.0
		TreatyType.CONFEDERATION:
			# Very high bar
			score += rep * 0.5
			if _share_common_enemy(ai_id, proposer_id):
				score += 25.0
			score -= 20.0  # Natural reluctance to merge

	# Existing treaty count penalty: too many treaties reduce willingness
	var existing_count: int = get_active_treaties(ai_id).size()
	score -= existing_count * 5.0

	# Random factor for unpredictability (range -10..10)
	score += randf_range(-10.0, 10.0)

	return score > 0.0

func ai_propose_treaties(ai_id: int) -> Array:
	## AI proactively proposes treaties based on current game state.
	## Returns an array of proposal dicts that were created.
	var proposals: Array = []
	var threat: float = _ai_threat_score(ai_id)
	var ai_gold: int = _get_player_gold_income(ai_id)
	var ai_key: String = _player_to_faction_key(ai_id)

	# Gather all potential partners (other player IDs)
	var partners: Array = _get_other_player_ids(ai_id)

	for partner_id in partners:
		var partner_key: String = _player_to_faction_key(partner_id)
		var rep: int = get_reputation(partner_key)
		var ratio: float = _ai_strength_ratio(ai_id, partner_id)

		# Already have many treaties? Stop proposing.
		if get_treaties_with(ai_id, partner_id).size() >= 3:
			continue

		# Priority 1: Ceasefire when losing a war
		if ratio < 0.6 and not has_treaty_type(ai_id, partner_id, TreatyType.CEASEFIRE):
			if not has_treaty_type(ai_id, partner_id, TreatyType.NON_AGGRESSION):
				var p: Dictionary = propose_treaty(ai_id, partner_id, TreatyType.CEASEFIRE)
				if p.get("valid", false):
					proposals.append(p)
				continue

		# Priority 2: Defensive alliance when threatened by third party
		if threat > 0.5 and rep >= 20:
			if not has_treaty_type(ai_id, partner_id, TreatyType.DEFENSIVE_ALLIANCE):
				if _share_common_enemy(ai_id, partner_id):
					var p: Dictionary = propose_treaty(ai_id, partner_id, TreatyType.DEFENSIVE_ALLIANCE)
					if p.get("valid", false):
						proposals.append(p)
					continue

		# Priority 3: Trade when economy is weak
		if ai_gold < 40 and rep >= 0:
			if not has_treaty_type(ai_id, partner_id, TreatyType.TRADE_AGREEMENT):
				var p: Dictionary = propose_treaty(ai_id, partner_id, TreatyType.TRADE_AGREEMENT)
				if p.get("valid", false):
					proposals.append(p)
				continue

		# Priority 4: Non-aggression pact with neutral+ rep and no existing peace treaty
		if rep >= -10 and ratio > 0.7 and ratio < 1.5:
			if not has_treaty_type(ai_id, partner_id, TreatyType.NON_AGGRESSION):
				if not has_treaty_type(ai_id, partner_id, TreatyType.CEASEFIRE):
					if randf() < 0.3:  # Don't always propose
						var p: Dictionary = propose_treaty(ai_id, partner_id, TreatyType.NON_AGGRESSION)
						if p.get("valid", false):
							proposals.append(p)

	return proposals

func _ai_threat_score(ai_id: int) -> float:
	## Estimate how threatened this AI faction feels. Range 0.0 (safe) to 1.0 (critical).
	## Uses tile count as a rough proxy for power.
	var ai_tiles: int = _get_player_tile_count(ai_id)
	if ai_tiles <= 0:
		return 1.0
	var max_enemy_tiles: int = 0
	for pid in _get_other_player_ids(ai_id):
		var t: int = _get_player_tile_count(pid)
		if t > max_enemy_tiles:
			max_enemy_tiles = t
	if max_enemy_tiles <= ai_tiles:
		return 0.1
	var ratio: float = float(max_enemy_tiles) / float(ai_tiles)
	return clampf((ratio - 1.0) / 2.0, 0.0, 1.0)

func _ai_strength_ratio(ai_id: int, other_id: int) -> float:
	## Return ratio of AI's power vs another player. >1.0 means AI is stronger.
	var ai_tiles: int = _get_player_tile_count(ai_id)
	var other_tiles: int = _get_player_tile_count(other_id)
	if other_tiles <= 0:
		return 10.0
	return float(ai_tiles) / float(other_tiles)

func _share_common_enemy(player_a: int, player_b: int) -> bool:
	## Heuristic: do both players have negative reputation with a third faction?
	for fkey in _reputation.keys():
		var key_a: String = _player_to_faction_key(player_a)
		var key_b: String = _player_to_faction_key(player_b)
		if fkey == key_a or fkey == key_b:
			continue
		if get_reputation(fkey) < -20:
			return true
	return false

# ═══════════════════════════════════════════════════════════════
#                  SAVE / LOAD
# ═══════════════════════════════════════════════════════════════

func to_save_data() -> Dictionary:
	## Serialize the entire treaty system state for save files.
	var treaty_list: Array = []
	for t in _active_treaties:
		treaty_list.append(t.duplicate(true))
	var proposal_list: Array = []
	for p in _pending_proposals:
		proposal_list.append(p.duplicate(true))
	return {
		"active_treaties": treaty_list,
		"pending_proposals": proposal_list,
		"reputation": _reputation.duplicate(),
		"next_id": _next_id,
	}

func from_save_data(data: Dictionary) -> void:
	## Restore treaty system state from save data.
	reset()
	if data.has("active_treaties"):
		for t in data["active_treaties"]:
			_active_treaties.append(t)
	if data.has("pending_proposals"):
		for p in data["pending_proposals"]:
			_pending_proposals.append(p)
	if data.has("reputation"):
		_reputation = data["reputation"].duplicate()
	if data.has("next_id"):
		_next_id = data["next_id"]

# ═══════════════════════════════════════════════════════════════
#                  INTERNAL HELPERS
# ═══════════════════════════════════════════════════════════════

func _generate_id(prefix: String) -> String:
	## Generate a unique string ID for treaties and proposals.
	var id: String = "%s_%d" % [prefix, _next_id]
	_next_id += 1
	return id

func _build_treaty_data(proposal: Dictionary) -> Dictionary:
	## Convert an accepted proposal into a full TreatyData dictionary.
	var treaty_id: String = _generate_id("treaty")
	return {
		"id": treaty_id,
		"type": proposal["type"],
		"party_a": proposal["proposer_id"],
		"party_b": proposal["target_id"],
		"terms": proposal.get("terms", {}),
		"duration": proposal.get("duration", -1),
		"signed_turn": _get_current_turn(),
		"reputation_stake": proposal.get("reputation_stake", 20),
	}

func _find_proposal(proposal_id: String) -> Dictionary:
	## Find a pending proposal by ID. Returns empty dict if not found.
	for p in _pending_proposals:
		if p.get("id", "") == proposal_id:
			return p
	return {}

func _find_treaty(treaty_id: String) -> Dictionary:
	## Find an active treaty by ID. Returns empty dict if not found.
	for t in _active_treaties:
		if t.get("id", "") == treaty_id:
			return t
	return {}

func _remove_treaty(treaty_id: String) -> void:
	## Remove a treaty from the active list by ID.
	for i in range(_active_treaties.size() - 1, -1, -1):
		if _active_treaties[i].get("id", "") == treaty_id:
			_active_treaties.remove_at(i)
			return

func _get_partner_key(treaty: Dictionary, player_id: int) -> String:
	## Given a treaty and one party, return the faction key of the OTHER party.
	var other_id: int = treaty["party_b"] if treaty["party_a"] == player_id else treaty["party_a"]
	return _player_to_faction_key(other_id)

func _count_broken_treaties(breaker_id: int) -> int:
	## Count how many treaties this player has broken (tracked via negative rep entries).
	## Approximation: each major negative rep likely came from a break.
	var count: int = 0
	var bkey: String = _player_to_faction_key(breaker_id)
	for fkey in _reputation.keys():
		if fkey != bkey and _reputation[fkey] < -15:
			count += 1
	return count

# ═══════════════════════════════════════════════════════════════
#               GAME ENGINE INTEGRATION HELPERS
# ═══════════════════════════════════════════════════════════════
# These functions bridge to the broader game engine (GameManager, ResourceManager).
# They are isolated here so the treaty logic remains testable even if autoloads shift.

func _get_current_turn() -> int:
	## Safely read the current turn number from GameManager.
	if Engine.has_singleton("GameManager"):
		var _gm_s = Engine.get_singleton("GameManager")
		return _gm_s.current_turn if "current_turn" in _gm_s else 0
	if is_instance_valid(get_node_or_null("/root/GameManager")):
		var _gm_n: Node = get_node("/root/GameManager")
		return _gm_n.current_turn if "current_turn" in _gm_n else 0
	return 0

func _player_to_faction_key(player_id: int) -> String:
	## Map a player ID to a faction key string for reputation lookups.
	## Falls back to "faction_<id>" if GameManager is unavailable.
	if is_instance_valid(get_node_or_null("/root/GameManager")):
		var gm: Node = get_node("/root/GameManager")
		if gm.has_method("get_player_faction"):
			var fid: int = gm.get_player_faction(player_id)
			match fid:
				FactionData.FactionID.ORC: return "orc_ai"
				FactionData.FactionID.PIRATE: return "pirate_ai"
				FactionData.FactionID.DARK_ELF: return "dark_elf_ai"
	return "faction_%d" % player_id

func _get_player_gold_income(player_id: int) -> int:
	## Read the player's current gold income from ResourceManager.
	if is_instance_valid(get_node_or_null("/root/ResourceManager")):
		var rm: Node = get_node("/root/ResourceManager")
		if rm.has_method("get_income"):
			return rm.get_income(player_id, "gold")
		if rm.has_method("get_resource"):
			return rm.get_resource(player_id, "gold")
	return 30  # Sensible fallback

func _transfer_gold(from_id: int, to_id: int, amount: int) -> void:
	## Transfer gold between two players via ResourceManager.
	if is_instance_valid(get_node_or_null("/root/ResourceManager")):
		var rm: Node = get_node("/root/ResourceManager")
		if rm.has_method("spend") and rm.has_method("add"):
			rm.spend(from_id, {"gold": amount})
			rm.add(to_id, {"gold": amount})

func _get_player_tile_count(player_id: int) -> int:
	## Count how many tiles a player owns (rough power estimate for AI).
	if is_instance_valid(get_node_or_null("/root/GameManager")):
		var gm: Node = get_node("/root/GameManager")
		var tiles: Array = gm.tiles if "tiles" in gm else []
		var count: int = 0
		for tile in tiles:
			if tile.get("owner_id", -1) == player_id:
				count += 1
		return count
	return 5  # Fallback

func _get_other_player_ids(exclude_id: int) -> Array:
	## Return all player IDs except the excluded one.
	if is_instance_valid(get_node_or_null("/root/GameManager")):
		var gm: Node = get_node("/root/GameManager")
		var all_ids: Array = gm.player_ids if "player_ids" in gm else []
		var result: Array = []
		for pid in all_ids:
			if pid != exclude_id:
				result.append(pid)
		return result
	return []

func _faction_display_name(treaty_type: int) -> String:
	## Return the localized display name for a treaty type.
	return TREATY_NAMES.get(treaty_type, "未知条约")
