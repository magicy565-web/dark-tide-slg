# 暗潮 SLG (Dark Tide SLG)

A dark-fantasy strategy game built with **Godot 4.2** (GDScript).

Players command one of three evil factions — Orcs, Pirates, or Dark Elves — on a
hex-based strategic map inspired by *Total War: Warhammer* and *Sengoku Rance*.
Build settlements, recruit armies, manage diplomacy, and conquer the forces of
light through military, economic, or shadow-dominance victory paths.

## Architecture

```
autoloads/          Core singletons (EventBus, GameManager, SaveManager, etc.)
systems/
  audio/            BGM/SFX management and scene-aware music switching
  balance/          Centralized tuning constants (BalanceConfig) and audit tools
  building/         Building & research registries
  combat/           Battle resolution, abilities, recruitment, environment
  economy/          Resources, production, buffs, items, relics, slaves
  event/            Event registry, scheduler, grand events, seasonal events
  faction/          Faction data, AI (evil/light/neutral/alliance), diplomacy
  hero/             Hero leveling, skills, enchantments, equipment forge
  map/              Procedural map generation
  march/            Army march/movement system
  mod/              Mod loading and version management
  ngplus/           New Game+ progression
  npc/              NPC and quest management
  quest/            Quest journal and progress tracking
  story/            Story events and visual-novel director
  strategic/        Supply lines, siege, logistics
  tutorial/         Guided tutorial system
  values/           Order (public order) and threat tracking
  world/            Weather and seasonal systems
scenes/
  board/            3D hex map, camera, army visualization
  ui/               HUD, panels, combat view, dialogs, overlays
assets/             Art, audio, and data assets
shaders/            Visual effect shaders
tools/              Editor and development utilities
tests/              Automated tests
docs/               Design documents
```

## Getting started

1. Install [Godot 4.2](https://godotengine.org/download/) (standard or .NET).
2. Open the project: **Project > Import** and select the `project.godot` file.
3. Press **F5** to run. The main scene is `scenes/main.tscn`.

## License

All rights reserved. License terms TBD.
