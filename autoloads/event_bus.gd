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
## Detailed combat result with casualty numbers and outcome metadata
signal combat_result_detailed(attacker_id: int, result: Dictionary)
## Army routed after defeat: forced to retreat to nearest safe tile
signal army_routed(player_id: int, army_id: int, from_tile: int, to_tile: int)
## Army disbanded (all troops wiped out)
signal army_disbanded_in_combat(player_id: int, army_id: int, tile_index: int)
signal tactical_orders_requested(player_id: int, tile_index: int)  # Pre-battle orders UI
signal tactical_orders_confirmed(player_id: int)  # Orders set, proceed with combat

# ── Combat演出 SFX hooks (v3.0) ──
signal sfx_attack(unit_class: String, is_crit: bool)
signal sfx_unit_killed(side: String)
signal sfx_hero_knockout(hero_name: String)
signal sfx_round_start(round_num: int)
signal sfx_battle_result(winner: String)
signal sfx_heal(side: String, slot: int)
signal sfx_buff_applied(side: String, slot: int, buff_type: String)
signal sfx_debuff_applied(side: String, slot: int, debuff_type: String)
signal sfx_block(side: String, slot: int)
signal sfx_dodge(side: String, slot: int)
signal sfx_morale_break(side: String, slot: int)
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
signal show_event_popup_with_source(title: String, description: String, choices: Array, source_type: String)  # BUG FIX B2
signal event_choice_selected(choice_index: int, source_type: String)  # FIX A6: source_type prevents race condition between subsystems
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

# ── Stronghold System (v1.2.0) ──
# 治理系统信号
signal governance_policy_activated(tile_idx: int, policy_id: String)
signal governance_action_executed(tile_idx: int, action_id: String)
signal governance_strategy_deployed(tile_idx: int, strategy_id: String)
signal governance_order_changed(tile_idx: int, old_order: float, new_order: float)

# 进攻系统信号
signal offensive_action_performed(attacker_idx: int, action_id: String, target_idx: int, result: Dictionary)
signal offensive_action_failed(tile_idx: int, action_id: String, reason: String)
signal offensive_cooldown_updated(tile_idx: int, action_id: String, cooldown_remaining: int)

# 民心腐败系统信号
signal morale_changed(tile_idx: int, old_morale: float, new_morale: float)
signal corruption_changed(tile_idx: int, old_corruption: float, new_corruption: float)
signal rebellion_risk_changed(tile_idx: int, risk_level: String)

# 发展路径系统信号
signal development_path_upgraded(tile_idx: int, path_id: String, new_level: int)
signal development_branch_chosen(tile_idx: int, path_id: String, branch: String)
signal development_points_changed(tile_idx: int, old_points: int, new_points: int)
signal milestone_unlocked(tile_idx: int, milestone_id: String)
signal synergy_bonus_changed(tile_idx: int, synergy_bonus: float)

# 据点面板信号
signal open_governance_panel_requested(tile_idx: int)
signal open_offensive_panel_requested(tile_idx: int)
signal open_development_panel_requested(tile_idx: int)
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
## Emitted when an army explicitly enters garrison (guard) stance.
signal army_garrisoned(army_id: int, tile_index: int)
## Emitted when an army leaves garrison stance.
signal army_ungarrisoned(army_id: int, tile_index: int)
## Emitted when troops are assigned to an army (recruit → army linkage).
signal army_troops_assigned(army_id: int, troop_id: String, soldiers: int)
## Emitted when a hero is assigned to an army via action_assign_hero_to_army.
signal army_hero_assigned(player_id: int, army_id: int, hero_id: String)
## Emitted when a hero is removed from an army via action_remove_hero_from_army.
signal army_hero_removed(player_id: int, army_id: int, hero_id: String)
## Emitted when an army is ready to march (has troops and is at a valid tile).
signal army_ready_to_march(army_id: int, tile_index: int)
## Emitted by GameManager to ask HUD to open recruit panel for a specific tile.
signal open_recruit_panel_requested(tile_index: int)
## Emitted by GameManager to ask HUD to open march planning for a specific army.
signal open_march_panel_requested(army_id: int)
## BUG FIX: Emitted by GameManager to ask HUD to open tile development panel for a specific tile.
signal open_domestic_panel_requested(tile_index: int)
## BUG FIX: Emitted by GameManager to ask HUD to open research panel.
signal open_research_panel_requested()

# ── Tutorial ──
signal tutorial_step(step_id: String)
# KEPT: tutorial system compat — tutorial_manager has its own local signal but this may be needed
signal tutorial_completed()
# ── Tutorial Level — 教程关卡专用信号 ──
## 教程关卡启动
signal tutorial_game_started()
## 玩家完成一个教程行动（内政、探索、居地升级等）
signal tutorial_domestic_done(action: String, tile_index: int)
## 玩家完成一次战斗（包括小兵、中立、光明阵营）
signal tutorial_combat_done(won: bool, target_tile: int)
## 玩家完成一次外交操作
signal tutorial_diplomacy_done(diplomacy_type: String)
## 玩家完成一次交易操作
signal tutorial_trade_done()
## 玩家完成地域压制操作
signal tutorial_suppression_done(tile_index: int)
## 玩家完成一个任务流程
signal tutorial_quest_done(quest_id: String)
## 玩家处理了一个事件
signal tutorial_event_handled(event_id: String)
## 玩家结束回合
signal tutorial_turn_ended(turn_number: int)

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

# ── Mission Panel (Sengoku Rance-style manual event trigger) ──
signal mission_execute_requested(hero_id: String)
signal mission_panel_refreshed()
signal mission_available(hero_id: String, event_data: Dictionary)  # Emitted when a new mission becomes available for a hero

# ── CG & Gallery System (v3.8) ──
signal cg_unlocked(cg_id: String, hero_id: String)
signal cg_displayed(cg_id: String, hero_id: String)
signal cg_gallery_opened()

# ── Hero Leveling (v3.1) ──
signal hero_leveled_up(hero_id: String, new_level: int)
signal hero_passive_unlocked(hero_id: String, passive_id: String)
signal hero_exp_gained(hero_id: String, amount: int, new_total: int)
signal hero_stat_changed(hero_id: String, stat_key: String, value: int)

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

# ── Multi-route Battle / 合战 (v4.8) ──
signal multi_route_battle_started(target_tile: int, route_count: int, attacker_ids: Array)
signal multi_route_phase_started(target_tile: int, route_index: int, attacker_id: int)
signal multi_route_phase_result(target_tile: int, route_index: int, attacker_won: bool, summary: Dictionary)
signal multi_route_battle_resolved(target_tile: int, defender_survived: bool, results: Array)
signal flanking_bonus_applied(target_tile: int, route_count: int, atk_bonus_pct: float)
signal pincer_bonus_applied(target_tile: int, def_reduction_pct: float)

# ── Extended Combo System / 组合技 (v4.8) ──
signal combo_cross_fire_triggered(side: String, atk_bonus_pct: float)
signal combo_shield_brothers_triggered(side: String, def_bonus: int)
signal combo_dark_ritual_triggered(side: String, sacrificed: int, atk_bonus: int)
signal combo_cavalry_sweep_triggered(side: String, morale_penalty: int)
signal combo_artillery_barrage_triggered(side: String, damage_pct: float)
signal combo_assassin_mark_triggered(side: String, target_unit: String)
signal combo_heroic_charge_triggered(side: String, hero_id: String)

# ── Skill Animation Events (v4.8) ──
signal skill_vfx_requested(skill_id: String, vfx_type: String, source_pos: Vector2, target_pos: Vector2)
signal screen_shake_requested(intensity: float, duration: float)
signal camera_zoom_requested(zoom_level: float, duration: float, target_pos: Vector2)
signal combo_chain_anim_requested(combo_id: String, hit_sequence: Array)

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
signal ai_skip_animations_requested()

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

# ── Direction A: Visual Presentation (v4.0) ──
signal hero_skill_activated(hero_id: String, skill_name: String, is_attacker: bool)
signal vn_scene_started(left_hero: String, right_hero: String, mood: String)
signal vn_scene_ended()
signal screen_effect_requested(effect_type: String, duration: float)
signal battle_cutin_requested(hero_id: String, skill_name: String, from_left: bool)
signal battle_cutin_finished()

# ── Direction B: Event Expansion (v4.0) ──
signal faction_destroyed(faction_id: String, destroyer_id: int)
signal seasonal_event_triggered(season: String, event_data: Dictionary)
signal grand_event_started(event_id: String)
signal grand_event_ended(event_id: String)
signal character_interaction_triggered(hero_a: String, hero_b: String, event_data: Dictionary)
signal dynamic_event_triggered(event_id: String, trigger_condition: String)

# ── Nation System (fixed map) ──
signal nation_conquered(player_id: int, nation_id: String)
signal nation_lost(player_id: int, nation_id: String)
signal nation_capital_captured(player_id: int, nation_id: String, tile_index: int)
signal nation_bonus_activated(player_id: int, nation_id: String)
signal nation_bonus_deactivated(player_id: int, nation_id: String)
signal border_conflict(nation_a: String, nation_b: String, tile_index: int)

# ── Province Quick Actions (v5.2) ──
## Emitted by province_info_panel when a quick action button is pressed.
## action: String — one of "recruit", "guard", "domestic", "explore", "ritual",
##                  "excavate", "block_supply", "fortify", "exploit",
##                  "train_elite", "upgrade_outpost", "upgrade_facility",
##                  "upgrade_walls", "build_market", "research", "diplomacy"
## tile_index: int — the tile the action targets
signal action_requested(action: String, tile_index: int)

# ── Human Kingdom AI (v1.0) ──
## Emitted when human kingdom mobilization level changes.
signal human_mobilization_changed(new_level: int)
## Emitted when a human hero is deployed to a tile for combat.
signal human_hero_deployed(hero_id: String, tile_index: int)
## Emitted when a noble defects or refuses mobilization order.
signal human_noble_defected(noble_name: String)
## Emitted when a human kingdom event requires player choice.
signal human_event_choice_requested(event_id: String, player_id: int, event_data: Dictionary)

# ── Quest Chain System (v1.0) ──
## 当一条任务链被激活时发射（首次满足触发条件）。
signal quest_chain_started(chain_id: String)
## 当整条任务链因超时或关键失败而失败时发射。
signal quest_chain_failed(chain_id: String, reason: String)
## 当链内某个节点从 LOCKED 变为 AVAILABLE 时发射。
signal quest_chain_node_unlocked(chain_id: String, node_id: String)
## 当链内某个节点从 AVAILABLE 变为 ACTIVE 时发射。
signal quest_chain_node_activated(chain_id: String, node_id: String)
## 当链内某个节点完成时发射。
signal quest_chain_node_completed(chain_id: String, node_id: String)
## 当链内某个节点失败时发射。
signal quest_chain_node_failed(chain_id: String, node_id: String)
## 当玩家在分支节点做出选择后发射。
signal quest_chain_branched(chain_id: String, parent_node_id: String, chosen_branch: String)
## 当整条任务链完成时发射。
signal quest_chain_completed(chain_id: String)
## 当任务链中的事件节点被触发时发射（附带弹窗数据）。
signal quest_chain_event_triggered(chain_id: String, node_id: String, popup_data: Dictionary)
## 当任务链需要玩家主动选择分支时发射（UI 应显示选择对话框）。
signal quest_chain_branch_requested(chain_id: String, node_id: String, options: Array)
## 当玩家通过 UI 选择了分支时发射（由 UI 层发射，QuestChainManager 监听）。
signal quest_chain_branch_chosen(chain_id: String, node_id: String, chosen_node_id: String)
## 当任务链奖励被发放时发射。
signal quest_chain_reward_applied(chain_id: String, node_id: String, reward: Dictionary)
## 当任务链设置了一个全局标记时发射。
signal quest_chain_flag_set(flag_id: String)
## 当任务链解锁了终局内容时发射。
signal quest_chain_endgame_unlocked(chain_id: String)
## 当任务链 UI 面板需要刷新时发射。
signal quest_chain_ui_refresh_requested()

# ── Chain Event Composer (v1.0) ──
## 当事件组合器的全局标记发生变化时发射。
signal chain_event_flag_changed(flag_id: String, value: Variant)
## 当一个事件序列完成时发射。
signal chain_event_sequence_completed(sequence_id: String)
## 当事件组合器处理了一个延迟事件时发射。
signal chain_event_delayed_fired(event_id: String)

# ── Cave System (v1.3.0) ──
## 洞穴探索事件触发
signal cave_explored(tile_idx: int, event_id: String, reward: Dictionary)
## 洞穴怪物被清剖
signal cave_cleared(tile_idx: int, monster_id: String, reward: Dictionary)
## 洞穴黑市购买
signal cave_black_market_purchased(tile_idx: int, item_id: String)
## 洞穴改造完成
signal cave_upgraded(tile_idx: int, upgrade_id: String)
## 洞穴等级提升
signal cave_level_up(tile_idx: int, new_level: int)
## 请求打开洞穴面板
signal open_cave_panel_requested(tile_idx: int)

# ── Village System (v1.3.0) ──
## 村庄建筑建造/升级
signal village_building_built(tile_idx: int, building_id: String, new_level: int)
## 村庄贸易协议签订
signal village_trade_started(tile_idx: int, trade_id: String)
## 村庄贸易协议到期
signal village_trade_expired(tile_idx: int, trade_id: String)
## 村庄民政行动执行
signal village_action_executed(tile_idx: int, action_id: String)
## 村庄等级提升
signal village_level_up(tile_idx: int, new_level: int)
## 村庄客栈招募到英雄
signal village_hero_available(tile_idx: int)
## 请求打开村庄面板
signal open_village_panel_requested(tile_idx: int)

# ── Fortress System (v1.3.0) ──
## 要塞城墙受到伤害
signal fortress_wall_damaged(tile_idx: int, damage: int, remaining_hp: int)
## 要塞城墙修缮
signal fortress_wall_repaired(tile_idx: int, new_hp: int, max_hp: int)
## 要塞防御工事建造/升级
signal fortress_building_built(tile_idx: int, building_id: String, new_level: int)
## 要塞驻军命令发布
signal fortress_order_issued(tile_idx: int, order_id: String)
## 要塞出城突袭执行
signal fortress_sortie_executed(tile_idx: int, damage_dealt: int)
## 要塞等级提升
signal fortress_level_up(tile_idx: int, new_level: int)
## 要塞防守胜利
signal fortress_defense_victory(tile_idx: int, prestige_gained: int)
## 请求打开要塞面板
signal open_fortress_panel_requested(tile_idx: int)

# ── Terrain-Tile Bridge System (v1.4.0) ──
## 地形改造开始
signal terrain_transform_started(tile_idx: int, from_terrain: int, to_terrain: int)
## 地形改造完成
signal terrain_transform_completed(tile_idx: int, old_terrain: int, new_terrain: int)
## 地形改造失败
signal terrain_transform_failed(tile_idx: int, reason: String)
## 筑路开始
signal road_construction_started(tile_idx: int)
## 筑路完成
signal road_construction_completed(tile_idx: int)
## 地形减员发生
signal terrain_attrition_applied(tile_idx: int, terrain_name: String, soldiers_lost: int)
## 地形+天气交叉效果触发
signal terrain_weather_cross_effect(tile_idx: int, cross_key: String, desc: String)
## 请求打开地形信息面板
signal open_terrain_info_panel_requested(tile_idx: int)
## 地形视野变化
signal terrain_visibility_changed(tile_idx: int, new_range: int)
## 地形伏击触发
signal terrain_ambush_triggered(tile_idx: int, ambush_bonus: float)
## 地块数据变化（地形改变后刷新显示）
signal tile_data_changed(tile_idx: int)
