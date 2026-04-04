# Dark Tide SLG - Battle System & Presentation Improvements

## 1. Overview
This document outlines the planned improvements and fixes for the combat system (`combat_system.gd`) and the battle presentation system (`combat_view.gd`, `battle_vfx_controller.gd`) in the Dark Tide SLG project. The goal is to deepen the tactical mechanics, fix existing bugs, and enhance the visual feedback of the battle engine.

## 2. Combat System Improvements (`combat_system.gd`)

### 2.1 Bug Fixes
- **Damage Calculation Bug**: The `def_mult` from the counter matrix is currently multiplying the base damage. If `def_mult` is intended to reduce damage taken (e.g., 0.8 for 20% reduction), multiplying is correct, but the comment says "BUG FIX: def_mult should multiply, not divide. def_mult < 1.0 reduces damage taken." We need to ensure the counter matrix logic is sound.
- **Intervention Sync Bug**: In `_apply_intervention_results`, the defender units are synced, but we need to ensure that all intervention effects (like `forced_target`, `bait_target`, `is_alive` for retreats) are properly handled and propagated to the `BattleUnit` objects.
- **Ultimate Damage Sync**: In `_apply_ultimate_damage`, damage is applied to `hp` and then `_recalc_soldiers` is called. We need to ensure that if a unit dies from an ultimate, the proper death logging and morale cascades are triggered, which currently seems missing or incomplete compared to normal attacks.

### 2.2 Deepening Mechanics
- **Morale System Enhancement**: Expand the morale cascade system. Currently, a routing unit causes -10 morale to same-row allies and -5 to others. We will add a "Rally" mechanic where killing an enemy hero or wiping out an enemy unit grants a small morale boost to the surviving allies.
- **Flanking / Backstab Mechanics**: Introduce a flanking bonus. If the front row is empty, melee attacks against the back row gain a +20% damage bonus, simulating a collapsed frontline.
- **Weather / Environment Effects**: Hook into the terrain system to add dynamic weather effects (e.g., Rain reduces ranged damage, Fog reduces accuracy/dodge chance) if the data supports it, or lay the groundwork for it.

## 3. Battle Presentation Improvements (`combat_view.gd` & `battle_vfx_controller.gd`)

### 3.1 Bug Fixes
- **Chibi Video Playback**: Ensure that `VideoStreamPlayer` instances are properly cleaned up and don't leak connections. The current `_chibi_cleanup` handles some of this, but we need to ensure state transitions (idle -> attack -> cast) don't cause visual stuttering.
- **Combo Counter Shatter**: The `_combo_shatter` function creates particles but doesn't clean them up perfectly if the view is closed prematurely. Ensure all dynamically created nodes in `anim_layer` and `root` are tracked or safely freed.

### 3.2 Deepening Visuals
- **Dynamic Camera Work**: Enhance the `_camera_zoom` to include a slight pan towards the attacking unit before zooming into the target for critical hits and ultimates, creating a more dynamic "action camera" feel.
- **Enhanced Death Sequences**: For hero knockouts, add a slow-motion effect (using `Engine.time_scale`) coupled with a grayscale flash before the card shatters, emphasizing the loss of a commander.
- **Projectile Trails**: Improve the `_draw_projectile_*` functions by adding particle trails (using `CPUParticles2D` instead of just `Line2D` for better visual fidelity) for magic and cannonball attacks.
- **UI Polish**: Add hover tooltips for active buffs/debuffs on the unit cards, allowing players to see exactly what effects are currently applied and their remaining duration.

## 4. Implementation Plan
1. **Phase 4**: Modify `combat_system.gd` to implement the flanking bonus, fix ultimate death logging, and enhance the morale system.
2. **Phase 5**: Modify `combat_view.gd` and `battle_vfx_controller.gd` to add the dynamic camera panning, slow-motion hero deaths, and improved projectile trails.
3. **Testing**: Run a simulated battle (if possible via a test scene) or verify the code logic thoroughly to ensure no regressions.
