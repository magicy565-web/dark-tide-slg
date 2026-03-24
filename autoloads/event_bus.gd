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

# Legacy compat aliases (some board code may still emit these)
signal gold_changed(player_id: int, new_amount: int)
signal charm_changed(player_id: int, new_amount: int)

# ── Territory ──
signal tile_captured(player_id: int, tile_index: int)
signal tile_lost(player_id: int, tile_index: int)
signal building_constructed(player_id: int, tile_index: int, building_id: String)
signal building_upgraded(player_id: int, tile_index: int, building_id: String, new_level: int)
signal territory_changed(tile_index: int, new_owner_id: int)

# ── Strategic Resources ──
signal strategic_resource_changed(player_id: int, resource_key: String, new_amount: int)

# ── NPC Obedience ──
signal npc_obedience_changed(player_id: int, npc_id: String, new_value: int)

# ── Quests ──
signal quest_triggered(player_id: int, quest_id: String, quest_data: Dictionary)

# ── Faction Recruitment ──
signal faction_recruited(player_id: int, faction_id: int)

# ── Choice Events ──
signal choice_event_triggered(player_id: int, event_data: Dictionary)

# ── Combat ──
signal combat_started(attacker_id: int, tile_index: int)
signal combat_result(attacker_id: int, defender_desc: String, won: bool)

# ── Fog of war ──
signal fog_updated(player_id: int)

# ── Faction specific ──
signal waaagh_changed(player_id: int, new_value: int)
signal frenzy_started(player_id: int)
signal frenzy_ended(player_id: int)
signal rebellion_occurred(tile_index: int)
signal expedition_spawned(tile_index: int)

# ── Order / Threat ──
signal order_changed(new_value: int)
signal threat_changed(new_value: int)

# ── Events ──
signal event_triggered(player_id: int, event_name: String, description: String)
signal item_acquired(player_id: int, item_name: String)
signal item_used(player_id: int, item_name: String)

# ── Characters (kept for compat but not primary in 暗潮) ──
signal character_captured(player_id: int, char_id: String)
signal character_affinity_changed(player_id: int, char_id: String, new_level: int)
signal character_scene_unlocked(player_id: int, char_id: String, scene_id: String)

# ── UI ──
signal message_log(text: String)
signal show_event_popup(title: String, description: String, choices: Array)
signal event_choice_selected(choice_index: int)
signal hide_event_popup()
signal faction_selected(faction_id: int)

# ── Plunder & Slave allocation ──
signal plunder_changed(player_id: int, new_value: int)
signal slave_allocation_changed(player_id: int)

# ── Pirate faction (v2.0) ──
signal infamy_changed(player_id: int, new_value: int)
signal rum_morale_changed(player_id: int, new_value: int)
signal treasure_found(player_id: int, reward_type: String)
signal smuggle_route_changed(player_id: int, route_count: int)
signal raid_party_spawned(tile_index: int, strength: int)
signal raid_party_defeated(tile_index: int, loot: int)
signal sex_slave_trained(player_id: int, slave_index: int, training_value: int)
signal sex_slave_sold(player_id: int, gold_earned: int)
signal sex_slave_ransomed(player_id: int, gold_earned: int)
signal black_market_refreshed(player_id: int, item_count: int)

# ── Pirate Harem System (后宫收集) ──
signal heroine_submission_changed(hero_id: String, new_value: int)
signal harem_progress_updated(recruited: int, submitted: int, total: int)
signal harem_victory_achieved()

# ── Light faction ──
signal mana_pool_changed(new_value: int)
signal alliance_formed(threat_level: int)
signal city_wall_damaged(tile_index: int, remaining_hp: int)

# ── Neutral quests ──
signal neutral_quest_step_completed(player_id: int, faction_id: int, step: int)
signal quest_combat_requested(player_id: int, neutral_faction: int, enemy_soldiers: int)
signal quest_combat_resolved(player_id: int, neutral_faction: int, won: bool)
signal neutral_faction_free_item(player_id: int, faction_id: int, item_id: String)

# ── Neutral territory & vassal ──
signal neutral_territory_attacked(neutral_faction_id: int, tile_index: int, attacker_id: int)
signal neutral_faction_vassalized(player_id: int, neutral_faction_id: int)
signal vassal_territory_changed(player_id: int, neutral_faction_id: int, tile_index: int)

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
signal event_immobile_set(player_id: int)

# ── Training / Research (v0.8.5) ──
signal tech_effects_applied(player_id: int)
signal research_tree_loaded(player_id: int, faction_id: int)

# ── AI Scaling (v0.8.5) ──
signal ai_threat_changed(faction_key: String, new_threat: int, new_tier: int)

# ── Troop / Military (Phase 3) ──
signal troop_recruited(player_id: int, troop_id: String, soldiers: int)
signal troop_destroyed(player_id: int, troop_id: String)
signal garrison_changed(tile_index: int)
signal rebel_spawned(tile_index: int)
signal wanderer_spawned(tile_index: int)
signal wanderer_defeated(tile_index: int)
signal rebel_defeated(tile_index: int)

# ── Taming / Neutral Faction (v1.0) ──
signal taming_changed(player_id: int, faction_tag: String, new_level: int)
signal neutral_troop_unlocked(player_id: int, faction_tag: String, troop_id: String)
signal neutral_faction_rebelled(player_id: int, faction_tag: String)

# ── Territory Map (v0.9.2) ──
signal territory_selected(tile_index: int)
signal territory_deselected()
signal army_deployed(player_id: int, army_id: int, from_tile: int, to_tile: int)
signal army_created(player_id: int, army_id: int, tile_index: int)
signal army_disbanded(player_id: int, army_id: int)
signal army_selected(army_id: int)
signal board_ready()

# ── Audio ──
signal bgm_changed(track_id: int)
signal sfx_requested(sfx_id: int)

# ── Tutorial ──
signal tutorial_step(step_id: String)
signal tutorial_completed()

# ── Balance / Difficulty (v3.0) ──
signal difficulty_changed(difficulty_key: String)

# ── Combat View ──
signal combat_view_requested(battle_result: Dictionary)
signal combat_view_closed()

# ── Settings ──
signal settings_opened()
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
