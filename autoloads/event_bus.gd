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
signal ap_changed(player_id: int, new_ap: int)

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
signal hero_executed(hero_id: String)
signal hero_ransomed(hero_id: String)
signal hero_exiled(hero_id: String)
signal hero_stationed(hero_id: String, tile_index: int)
signal hero_unstationed(hero_id: String, tile_index: int)

# ── Event System (v0.8.2) ──
signal event_choice_made(event_id: String, choice_index: int)
signal event_combat_requested(player_id: int, enemy_soldiers: int, event_id: String)

# ── Training / Research (v0.8.5) ──
signal tech_effects_applied(player_id: int)

# ── AI Scaling (v0.8.5) ──
signal ai_threat_changed(faction_key: String, new_threat: int, new_tier: int)

# ── AI Strategic Planner (v4.0) ──
signal ai_strategy_changed(faction_key: String, new_strategy: int)
signal ai_coordinated_attack(target_tile: int, faction_keys: Array)

# ── Troop / Military (Phase 3) ──
signal rebel_spawned(tile_index: int)
signal wanderer_spawned(tile_index: int)

# ── Taming / Neutral Faction (v1.0) ──
signal taming_changed(player_id: int, faction_tag: String, new_level: int)

# ── Territory Map (v0.9.2) ──
signal territory_selected(tile_index: int)
signal territory_deselected()
signal army_deployed(player_id: int, army_id: int, from_tile: int, to_tile: int)

# ── Supply & Attrition ──
signal army_supply_changed(army_id: int, supply: int)
signal army_attrition(army_id: int, losses: Dictionary)
signal supply_depot_built(tile_index: int, player_id: int)
signal supply_depot_destroyed(tile_index: int)
signal army_created(player_id: int, army_id: int, tile_index: int)
signal army_disbanded(player_id: int, army_id: int)
signal army_selected(army_id: int)
signal board_ready()

# ── March System ──
signal army_march_started(army_id: int, path: Array)
signal army_march_step(army_id: int, from_tile: int, to_tile: int, progress: float)
signal army_march_arrived(army_id: int, tile_index: int)
signal army_march_cancelled(army_id: int)
signal army_march_intercepted(army_id: int, interceptor_id: int, tile_index: int)
signal army_supply_low(army_id: int, supply: float)

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
signal tile_tier3_reached(tile_idx: int, path: int, bonus: Dictionary)
signal tile_path_converted(tile_idx: int, old_path: int, new_path: int)

# ── Weather & Season System ──
signal season_changed(season_id: int, season_data: Dictionary)
signal weather_changed(weather_id: int, weather_data: Dictionary)

# ── Espionage & Intelligence (v4.1) ──
signal spy_operation_result(player_id: int, op_type: int, success: bool, details: Dictionary)
signal intel_changed(player_id: int, intel: int)
signal spy_captured(player_id: int, target_id: int)

# ── Formation Synergy & Tactics (v4.2) ──
signal formation_detected(side: String, formation_id: int, formation_name: String)
signal formation_clash(atk_formation: int, def_formation: int, effect: String)
signal tactical_combo_triggered(combo_id: String, description: String)

# ── Reputation & Diplomacy Depth (v4.3) ──
signal reputation_threshold_crossed(faction_key: String, old_level: String, new_level: String)
signal treaty_break_cascade(total_breaks: int)
signal treachery_debuff_applied(player_id: int, duration: int)

# ── Dynamic Diplomatic Events (SR07-style) ──
signal diplomatic_event_triggered(event_data: Dictionary)

# ── Hero Recruitment Events (SR07-style) ──
signal recruitment_event_triggered(event_data: Dictionary)
# event_data: {type: String, faction_id: int, title: String, description: String,
#   choices: [{text: String, callback: String}], event_id: String}
signal diplomatic_event_resolved(event_id: String, choice_index: int)

# ── Event Chains (v4.3) ──
signal event_chain_triggered(parent_id: String, chain_id: String, delay_turns: int)
signal event_chain_resolved(chain_id: String, choice_index: int)

# ── Veteran System (v4.3) ──
signal unit_promoted_veteran(unit_id: String, troop_id: String)
signal unit_promoted_elite(unit_id: String, troop_id: String)

# ── Tile Combat Bonuses (v4.3) ──
signal tile_combat_bonus_applied(tile_idx: int, path: int, bonuses: Dictionary)

# ── Hidden Hero & Story Window Notifications (v4.4) ──
signal hidden_hero_discovered(hero_id: String, hero_name: String, message: String)
signal story_window_triggered(window_id: String, title: String, narrative: String)
signal story_window_expired(window_id: String, title: String, consequence: String)

# ── Turn Phase Banner (v4.5) ──
signal phase_banner_requested(text: String, is_ai_turn: bool)

# ── Game Over Detailed (v4.5) ──
signal game_over_detailed(data: Dictionary)

# ── March System (v4.6) — additional signals ──
signal army_march_battle(army_id: int, tile_index: int)

# ── Supply Line & Territory Classification (v4.7) ──
signal supply_line_cut(player_id: int, isolated_tiles: Array)
signal supply_line_restored(player_id: int, tiles: Array)
signal territory_classified(player_id: int)

# ── Advanced Tactical Intelligence (v5.1) ──
signal ai_diversion_planned(faction_key: String, feint_tile: int, real_tile: int)
signal ai_concentration_started(faction_key: String, target_tile: int, army_count: int)
signal ai_strategic_retreat(army_id: int, from_tile: int, to_tile: int)

# ── Siege System (v5.0) ──
signal siege_started(attacker_army_id: int, tile_index: int, turns: int)
signal siege_progress(tile_index: int, wall_hp: float, morale: float, turns_left: int)
signal siege_ended(tile_index: int, result: String)
signal sortie_triggered(tile_index: int, defender_won: bool)
signal strategic_buff_changed(player_id: int, buffs: Dictionary)

# ── Hero Skills Advanced (v6.0) ──
signal ultimate_executed(hero_id: String, skill_name: String, result: Dictionary)
signal combo_executed(combo_id: int, combo_name: String, result: Dictionary)
signal hero_awakened(hero_id: String, stat_changes: Dictionary)
signal awakening_ended(hero_id: String)

# ── Enchantment System (v6.0) ──
signal enchantment_changed(hero_id: String, enchantment_id: String)

# ── Environment System (v6.0) ──
signal time_of_day_changed(time_id: int, time_data: Dictionary)
signal fatigue_changed(army_id: int, new_fatigue: int)
signal fatigue_desertion(army_id: int)
signal unit_promoted(unit_id: String, new_rank: String)
signal loot_generated(loot: Array)
signal loot_applied(loot: Array)

# ── Endgame Crisis System (v7.0) ──
signal crisis_started(crisis_type: String, crisis_data: Dictionary)
signal crisis_ended(crisis_type: String)
signal crisis_tick(crisis_type: String, turn_remaining: int, details: Dictionary)
signal crisis_quarantine_applied(tile_index: int, cost: int)

# ── Late-Game Prestige Actions (v7.0) ──
signal grand_festival_executed(player_id: int)
signal imperial_decree_executed(player_id: int)
signal forge_alliance_executed(player_id: int, target_faction: int)

# ── AI Indicator ──
signal ai_action_started(faction_key: String, action_type: String, detail: String)
signal ai_action_completed(faction_key: String, action_type: String, success: bool)
signal ai_turn_progress(faction_key: String, phase: int, total_phases: int)
signal ai_thinking(faction_key: String, is_thinking: bool)

# ── Debug Console ──
signal debug_command_executed(command: String, result: String)
signal debug_state_changed(key: String, value: Variant)
signal debug_log(level: String, message: String)

# ── Action Visualization ──
signal action_visualize_attack(attacker_tile: int, defender_tile: int, result: Dictionary)
signal action_visualize_deploy(army_id: int, from_tile: int, to_tile: int)
signal action_visualize_recruit(tile_index: int, troop_id: String, count: int)
signal action_visualize_build(tile_index: int, building_id: String)
signal action_visualize_research(tech_id: String, started: bool)

# ── Troop Training ──
signal troop_training_started(player_id: int, troop_id: String, turns_left: int)
signal troop_training_completed(player_id: int, troop_id: String)
signal troop_training_cancelled(player_id: int, troop_id: String)
signal troop_ability_unlocked(player_id: int, troop_id: String, ability_id: String)

# ── Task Panel ──
signal task_assigned(task_id: String, task_data: Dictionary)
signal task_progress_updated(task_id: String, progress: float)
signal task_completed(task_id: String)
signal task_panel_refresh_requested()

# ── Tile Indicators ──
signal tile_indicators_toggle(layer: String, visible: bool)
signal tile_indicator_refresh(tile_index: int)
signal tile_indicators_rebuild()

# ── Intel Overlay ──
signal intel_tile_scouted(player_id: int, tile_index: int, turns: int)
signal intel_tile_sabotaged(player_id: int, tile_index: int, turns: int)
signal intel_orders_intercepted(player_id: int, faction_key: String, orders: Array)
signal intel_hero_wounded(player_id: int, hero_id: String, turns: int)
signal intel_overlay_toggle(visible: bool)
signal intel_report_requested()
signal tile_tooltip_requested(tile_index: int)
signal tile_tooltip_dismissed()
