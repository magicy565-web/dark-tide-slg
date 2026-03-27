## event_bus.gd - Signal bus for 暗潮 SLG
extends Node

# ── Core game flow ──
signal turn_started(player_id: int)
signal turn_ended(player_id: int)
signal game_over(winner_id: int)

# ── Dice & Movement ──
signal dice_rolled(player_id: int, value: int)
signal reachable_computed(tile_indices: Array)
signal player_moving(player_id: int, path: Array)
signal player_arrived(player_id: int, tile_index: int)

# ── Resource changes ──
signal resources_changed(player_id: int)
signal army_changed(player_id: int, new_count: int)

# LEGACY: connected in hud.gd for backward compat (never emitted — triggers _update_player_info)
signal gold_changed(player_id: int, new_amount: int)
# LEGACY: connected in hud.gd for backward compat (never emitted — triggers _update_player_info)
signal charm_changed(player_id: int, new_amount: int)

# ── Territory ──
signal tile_captured(player_id: int, tile_index: int)
signal tile_lost(player_id: int, tile_index: int)
signal building_constructed(player_id: int, tile_index: int, building_id: String)
signal building_upgraded(player_id: int, tile_index: int, building_id: String, new_level: int)
signal territory_changed(tile_index: int, new_owner_id: int)
signal conquest_choice_made(tile_index: int, choice_type: String)
signal conquest_choice_selected(choice_index: int)

# ── Strategic Resources ──
signal strategic_resource_changed(player_id: int, resource_key: String, new_amount: int)

# ── NPC Obedience ──
signal npc_obedience_changed(player_id: int, npc_id: String, new_value: int)
signal npc_available_for_recapture(player_id: int, npc_id: String)  # NPC逃跑冷却结束，可重新捕获

# ── Quests ──
signal quest_triggered(player_id: int, quest_id: String, quest_data: Dictionary)

# ── Faction Recruitment ──
signal faction_recruited(player_id: int, faction_id: int)

# ── Choice Events ──
signal choice_event_triggered(player_id: int, event_data: Dictionary)

# ── Combat ──
signal combat_started(attacker_id: int, tile_index: int)
signal combat_result(attacker_id: int, defender_desc: String, won: bool)
signal tactical_orders_requested(player_id: int, tile_index: int)  # Pre-battle orders UI
signal tactical_orders_confirmed(player_id: int)  # Orders set, proceed with combat

# ── Combat演出 SFX hooks (v3.0) ──
signal sfx_attack(unit_class: String, is_crit: bool)
signal sfx_unit_killed(side: String)
signal sfx_hero_knockout(hero_name: String)
signal sfx_round_start(round_num: int)
signal sfx_battle_result(winner: String)
signal unit_routed(unit_type: String, side: String)
signal unit_morale_changed(unit_type: String, side: String, new_morale: int)
signal combat_view_requested(battle_result: Dictionary)
signal combat_view_closed()
signal combat_intervention_phase(state: Dictionary)
signal combat_intervention_chosen(intervention_type: int, target: Variant)

# ── Fog of war ──
signal fog_updated(player_id: int)

# ── Faction specific ──
signal waaagh_changed(player_id: int, new_value: int)
signal frenzy_started(player_id: int)
signal frenzy_ended(player_id: int)
# LEGACY: connected in notification_bar.gd — emitted by OrderManager/DiplomacyManager on rebellion
signal rebellion_occurred(tile_index: int)
signal expedition_spawned(tile_index: int)

# ── Order / Threat ──
signal order_changed(new_value: int)
signal threat_changed(new_value: int)

# ── Events ──
signal event_triggered(player_id: int, event_name: String, description: String)
signal item_acquired(player_id: int, item_name: String)
signal item_used(player_id: int, item_name: String)

# ── UI ──
signal message_log(text: String)
signal show_event_popup(title: String, description: String, choices: Array)
signal event_choice_selected(choice_index: int)
# LEGACY: connected in event_popup.gd — emitted to force-close popup from game logic
signal hide_event_popup()

# ── Plunder & Slave allocation ──
signal plunder_changed(player_id: int, new_value: int)

# ── Pirate faction (v2.0) ──
signal infamy_changed(player_id: int, new_value: int)
signal rum_morale_changed(player_id: int, new_value: int)
signal black_market_refreshed(player_id: int, item_count: int)

# ── Pirate Harem System (后宫收集) ──
signal heroine_submission_changed(hero_id: String, new_value: int)
signal harem_progress_updated(recruited: int, submitted: int, total: int)
signal harem_victory_achieved()

# ── Light faction ──
signal alliance_formed(threat_level: int)

# ── Neutral quests ──
signal neutral_quest_step_completed(player_id: int, faction_id: int, step: int)
signal quest_combat_requested(player_id: int, neutral_faction: int, enemy_soldiers: int)
signal neutral_faction_free_item(player_id: int, faction_id: int, item_id: String)

# ── Neutral territory & vassal ──
signal neutral_territory_attacked(neutral_faction_id: int, tile_index: int, attacker_id: int)
signal neutral_faction_vassalized(player_id: int, neutral_faction_id: int)

# ── Relics ──
signal relic_selected(player_id: int, relic_id: String)

# ── Strategic resources ──
signal strategic_resource_consumed(player_id: int, resource: String, amount: int)

# ── Temporary buffs ──
signal temporary_buff_applied(player_id: int, buff_id: String, duration: int)
signal temporary_buff_expired(player_id: int, buff_id: String)

# ── Hero System (v0.8.2) ──
signal hero_captured(hero_id: String)
signal hero_recruited(hero_id: String)
signal hero_affection_changed(hero_id: String, new_value: int)
signal hero_released(hero_id: String)

# ── Event System (v0.8.2) ──
signal event_choice_made(event_id: String, choice_index: int)
signal event_combat_requested(player_id: int, enemy_soldiers: int, event_id: String)

# ── Training / Research (v0.8.5) ──
signal tech_effects_applied(player_id: int)

# ── AI Scaling (v0.8.5) ──
signal ai_threat_changed(faction_key: String, new_threat: int, new_tier: int)

# ── Troop / Military (Phase 3) ──
signal rebel_spawned(tile_index: int)
signal wanderer_spawned(tile_index: int)

# ── Taming / Neutral Faction (v1.0) ──
signal taming_changed(player_id: int, faction_tag: String, new_level: int)

# ── Territory Map (v0.9.2) ──
signal territory_selected(tile_index: int)
signal territory_deselected()
signal army_deployed(player_id: int, army_id: int, from_tile: int, to_tile: int)
signal army_created(player_id: int, army_id: int, tile_index: int)
signal army_disbanded(player_id: int, army_id: int)
signal army_selected(army_id: int)
signal board_ready()

# ── Tutorial ──
signal tutorial_step(step_id: String)
# KEPT: tutorial system compat — tutorial_manager has its own local signal but this may be needed
signal tutorial_completed()

# ── Balance / Difficulty (v3.0) ──
# KEPT: emitted in balance_manager.gd — no listeners yet but expected for settings UI
signal difficulty_changed(difficulty_key: String)

# ── Settings ──
signal settings_closed()

# ── Quest Journal (v2.4) ──
signal quest_journal_updated()
signal challenge_battle_requested(challenge_id: String, battle_data: Dictionary)
signal challenge_battle_resolved(challenge_id: String, won: bool)

# ── Story Event System (v1.0) ──
signal story_event_triggered(hero_id: String, event_data: Dictionary)
signal story_event_completed(hero_id: String, event_id: String)
signal story_route_completed(hero_id: String, route: String)
signal story_choice_made(hero_id: String, event_id: String, choice_index: int)
signal story_choice_requested(hero_id: String, event_id: String, choices: Array)

# ── Hero Leveling (v3.1) ──
signal hero_leveled_up(hero_id: String, new_level: int)
signal hero_passive_unlocked(hero_id: String, passive_id: String)
signal hero_exp_gained(hero_id: String, amount: int, new_total: int)

# ── UI Panel Requests ──
signal open_hero_detail_requested(hero_id: String)

# ── Diplomacy & Treaties (v3.4) ──
signal treaty_signed(player_id: int, treaty_type: String, target_faction: int)
signal treaty_broken(player_id: int, treaty_type: String, target_faction: int)
signal treaty_expired(player_id: int, treaty_type: String, target_faction: int)
signal tribute_received(player_id: int, from_faction: int, gold: int)
signal light_peace_offered(gold_offered: int)
signal light_extorted(player_id: int, gold: int)

# ── Tile Development Path (v3.5) ──
signal tile_path_chosen(tile_idx: int, path: int)
signal tile_building_built(tile_idx: int, building_id: String)
