# Dark Tide SLG: Internal Affairs & Economy Fix Report

## Overview
Following a comprehensive scan of all 39 functional modules within the `.gd` repository, a deep analysis of the internal affairs, economy, and strategic stronghold systems was conducted. The investigation revealed a cluster of 10 critical bugs that severely compromised the game's economic loop, policy application, and save data integrity.

All 10 issues have been successfully repaired, verified, and pushed to the `main` branch.

## Summary of Fixes

### 1. Missing `GameManager.current_ap` Property (Crash Fix)
**Issue:** Multiple strategic subsystems (`governance_system`, `fortress_system`, `cave_system`, `village_system`, and UI panels) relied on `GameManager.current_ap` to validate and deduct action points (AP). However, this property was never defined in `game_manager.gd`, causing hard runtime crashes whenever a player attempted to execute a stronghold action.
**Fix:** Implemented `current_ap` as a computed property in `game_manager.gd` with a getter and setter that correctly reads and writes the active human player's AP pool.

### 2. Economy Modifiers Scope Bug (Critical Logic Fix)
**Issue:** In `production_calculator.gd`, the logic blocks applying Governance policy modifiers, Morale/Corruption multipliers, Tile Development Path bonuses, Adjacency spillovers, and Seasonal bonuses were mistakenly nested inside the `if station_type != ""` check. This meant these critical economy modifiers only applied to resource station tiles, while regular villages, strongholds, and event tiles received no bonuses or penalties whatsoever.
**Fix:** Moved all five modifier blocks outside the `station_type` check to the main tile loop scope, ensuring they correctly apply to all owned tiles.

### 3. Governance `gold_mult` Resource Scope
**Issue:** The `tax_hike` governance policy description stated "产出+50%" (all production +50%), but the code in `production_calculator.gd` only multiplied gold output.
**Fix:** Updated the logic to apply the governance `gold_mult` factor to all three primary resources: gold, food, and iron.

### 4. Governance Panel Invalid `continue` Crash
**Issue:** The `_refresh()` function in `governance_panel.gd` used the `continue` keyword for a bounds-check early exit. Because this was outside of a loop, it triggered a GDScript parse error, crashing the game whenever the governance panel was opened.
**Fix:** Replaced the invalid `continue` statement with a standard `return` and removed duplicate bounds-checking logic.

### 5. Festival Policy Lingering Bug
**Issue:** Governance policies with `duration = 0` (such as "Festival", which grants instant public order and garrison bonuses) were being stored in the `active_policies` dictionary with 0 turns remaining. Because the turn processor ignores 0-duration policies, they never expired, permanently blocking players from re-activating them.
**Fix:** Updated `governance_system.gd` so that `duration = 0` policies are applied instantly and are never stored in the active policies dictionary.

### 6. Suppress Action Missing Garrison Cost
**Issue:** The "Suppress" (`suppress`) governance action costs 10 garrison troops to restore public order. However, `_check_and_spend_cost` in `governance_system.gd` silently ignored the `garrison` cost key, making the action completely free.
**Fix:** Added specific handling for the `garrison` cost key, validating against the player's current army size and deducting the troops via `ResourceManager.remove_army()`.

### 7. Save/Load Data Wipe (6 Subsystems)
**Issue:** Six strategic subsystems (`governance_system`, `morale_corruption_system`, `development_path_system`, `village_system`, `fortress_system`, and `cave_system`) store per-tile data in dictionaries using the integer `tile_idx` as keys. When Godot serializes dictionaries to JSON, it converts all integer keys to strings. Upon loading, the `from_save_data()` functions failed to convert these string keys back to integers. As a result, subsequent `get_*_data(tile_idx)` calls failed to find matching keys and silently created fresh default data, completely wiping all saved progress for governance policies, morale, development paths, village buildings, fortress walls, and cave exploration.
**Fix:** Patched the `from_save_data()` function in all six affected subsystems to iterate over the loaded JSON dictionary and explicitly cast string keys back to integers before populating the state dictionaries.

### 8. Invalid Void Return in Integer Function
**Issue:** In `tile_development.gd`, the `_get_tile_level(tile_idx: int) -> int` function contained a redundant inner bounds check that simply executed `return` (returning void/null). If triggered, any caller attempting to use the result in arithmetic would encounter a fatal null operand crash.
**Fix:** Removed the redundant inner bounds check, as the outer bounds check safely handles the logic and guarantees a valid integer return.

## Conclusion
The internal affairs and economy modules are now fully functional. Action point deduction works universally across all stronghold types, economy modifiers correctly scale production across the entire empire, UI crashes have been resolved, and save/load operations now accurately preserve all strategic progression.
