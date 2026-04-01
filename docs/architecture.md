# Dark Tide SLG - Architecture Overview

## Autoload Loading Order (79 singletons)

Godot loads autoloads top-to-bottom as listed in `project.godot`.
The order matters because later autoloads may reference earlier ones in `_ready()`.

```
 #  Singleton Name                  Source Path
── ────────────────────────────────  ──────────────────────────────────────────────
 1  UILayerRegistry                 autoloads/ui_layer_registry.gd
 2  PanelManager                    autoloads/panel_manager.gd
 3  EventBus                        autoloads/event_bus.gd
 4  GameData                        autoloads/game_data.gd
 5  BalanceConfig                   systems/balance/balance_config.gd
 6  ResourceManager                 systems/economy/resource_manager.gd
 7  SlaveManager                    systems/economy/slave_manager.gd
 8  BuffManager                     systems/economy/buff_manager.gd
 9  ItemManager                     systems/economy/item_manager.gd
10  RelicManager                    systems/economy/relic_manager.gd
11  ProductionCalculator            systems/economy/production_calculator.gd
12  TileDevelopment                 systems/economy/tile_development.gd
13  OrderManager                    systems/values/order_manager.gd
14  ThreatManager                   systems/values/threat_manager.gd
15  BuildingRegistry                systems/building/building_registry.gd
16  OrcMechanic                     systems/faction/orc_mechanic.gd
17  PirateMechanic                  systems/faction/pirate_mechanic.gd
18  DarkElfMechanic                 systems/faction/dark_elf_mechanic.gd
19  FactionManager                  systems/faction/faction_manager.gd
20  LightFactionAI                  systems/faction/light_faction_ai.gd
21  AllianceAI                      systems/faction/alliance_ai.gd
22  EvilFactionAI                   systems/faction/evil_faction_ai.gd
23  DiplomacyManager                systems/faction/diplomacy_manager.gd
24  NpcManager                      systems/npc/npc_manager.gd
25  QuestManager                    systems/npc/quest_manager.gd
26  StrategicResourceManager        systems/economy/strategic_resource_manager.gd
27  RecruitManager                  systems/combat/recruit_manager.gd
28  CombatAbilities                 systems/combat/combat_abilities.gd
29  CombatResolver                  systems/combat/combat_resolver.gd
30  CommanderIntervention            systems/combat/commander_intervention.gd
31  ResearchManager                 systems/building/research_manager.gd
32  HeroSystem                      systems/hero/hero_system.gd
33  HeroLeveling                    systems/hero/hero_leveling.gd
34  EventRegistry                   systems/event/event_registry.gd
35  EffectResolver                  systems/event/effect_resolver.gd
36  EventSystem                     systems/event/event_system.gd
37  AIScaling                       systems/faction/ai_scaling.gd
38  AIStrategicPlanner              systems/faction/ai_strategic_planner.gd
39  SaveManager                     autoloads/save_manager.gd
40  ModManager                      systems/mod/mod_manager.gd
41  GameManager                     autoloads/game_manager.gd
42  SupplySystem                    systems/strategic/supply_system.gd
43  SiegeSystem                     systems/strategic/siege_system.gd
44  NeutralFactionAI                systems/faction/neutral_faction_ai.gd
45  BalanceManager                  systems/balance/balance_manager.gd
46  QuestJournal                    systems/quest/quest_journal.gd
47  AudioManager                    autoloads/audio_manager.gd
48  TutorialManager                 systems/tutorial/tutorial_manager.gd
49  StoryEventSystem                systems/story/story_event_system.gd
50  NgPlusManager                   systems/ngplus/ngplus_manager.gd
51  UITheme                         autoloads/ui_theme_manager.gd
52  ColorTheme                      autoloads/color_theme.gd
53  MarchSystem                     systems/march/march_system.gd
54  HeroSkillsAdvanced              systems/hero/hero_skills_advanced.gd
55  EnchantmentSystem               systems/hero/enchantment_system.gd
56  EnvironmentSystem               systems/combat/environment_system.gd
57  TreatySystem                    systems/faction/treaty_system.gd
58  SupplyLogistics                 systems/strategic/supply_logistics.gd
59  EquipmentForge                  systems/hero/equipment_forge.gd
60  EspionageSystem                 systems/faction/espionage_system.gd
61  WeatherSystem                   systems/world/weather_system.gd
62  CGManager                       autoloads/cg_manager.gd
63  CGGalleryPanel                  scenes/ui/system/cg_gallery_panel.gd
64  VnDirector                      systems/story/vn_director.gd
65  BattleCutin                     systems/combat/battle_cutin.gd
66  FactionDestructionEvents        systems/event/faction_destruction_events.gd
67  SeasonalEvents                  systems/event/seasonal_events.gd
68  CharacterInteractionEvents      systems/event/character_interaction_events.gd
69  GrandEventDirector              systems/event/grand_event_director.gd
70  DynamicSituationEvents          systems/event/dynamic_situation_events.gd
71  SceneAudioDirector              systems/audio/scene_audio_director.gd
72  CrisisCountdown                 systems/event/crisis_countdown.gd
73  ExpandedRandomEvents            systems/event/expanded_random_events.gd
74  ExtraEventsV5                   systems/event/extra_events_v5.gd
75  QuestProgressTracker            systems/quest/quest_progress_tracker.gd
76  EventScheduler                  systems/event/event_scheduler.gd
77  AssetLoader                     autoloads/asset_loader.gd
```

## System Dependency Graph

```
                          ┌─────────────┐
                          │  EventBus   │  (global signal hub)
                          └──────┬──────┘
                                 │ signals flow to all systems
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
        v                        v                        v
┌───────────────┐      ┌─────────────────┐      ┌────────────────┐
│  GameManager  │─────>│ ResourceManager │      │   SaveManager  │
│  (orchestrator)│      │ SlaveManager    │      │  (serializes   │
│               │      │ BuffManager     │      │   all systems) │
│ - turn flow   │      │ ItemManager     │      └────────────────┘
│ - map/tiles   │      │ RelicManager    │
│ - armies      │      │ StrategicRes.   │
│ - AP system   │      │ ProductionCalc  │
│ - win cond.   │      │ TileDevelopment │
└───┬───┬───┬───┘      └─────────────────┘
    │   │   │
    │   │   └──────────────────────────────────┐
    │   │                                      │
    v   v                                      v
┌──────────────┐  ┌───────────────────┐  ┌───────────────────┐
│   Combat     │  │   Faction/AI      │  │   Event Pipeline  │
│              │  │                   │  │                   │
│ CombatRes.   │  │ FactionManager    │  │ EventRegistry     │
│ CombatAbil.  │  │ LightFactionAI    │  │ EventScheduler    │
│ Commander    │  │ AllianceAI        │  │ EventSystem       │
│ RecruitMgr   │  │ EvilFactionAI     │  │ EffectResolver    │
│ Environ.Sys  │  │ NeutralFactionAI  │  │ SeasonalEvents    │
│ SiegeSystem  │  │ AIScaling         │  │ CrisisCountdown   │
│ BattleCutin  │  │ AIStrategicPlan.  │  │ GrandEventDir.    │
│              │  │ DiplomacyMgr      │  │ DynamicSituation  │
│              │  │ TreatySystem      │  │ FactionDestruct.  │
│              │  │ EspionageSystem   │  │ CharacterInteract.│
│              │  │ OrcMechanic       │  │ ExpandedRandom    │
│              │  │ PirateMechanic    │  │ ExtraEventsV5     │
│              │  │ DarkElfMechanic   │  │                   │
└──────────────┘  └───────────────────┘  └───────────────────┘
    │                                          │
    v                                          v
┌──────────────┐  ┌───────────────────┐  ┌───────────────────┐
│   Hero       │  │   Quest/Story     │  │   UI / Presenta.  │
│              │  │                   │  │                   │
│ HeroSystem   │  │ QuestManager      │  │ UILayerRegistry   │
│ HeroLeveling │  │ QuestJournal      │  │ PanelManager      │
│ HeroSkillAdv │  │ QuestProgressTrk  │  │ UITheme           │
│ Enchantment  │  │ StoryEventSystem  │  │ ColorTheme        │
│ EquipForge   │  │ VnDirector        │  │ CGManager         │
│              │  │ NpcManager        │  │ CGGalleryPanel    │
└──────────────┘  └───────────────────┘  │ AudioManager      │
                                         │ SceneAudioDir.    │
                                         │ TutorialManager   │
                                         └───────────────────┘
```

## Signal Flow Diagram

```
EventBus (central signal hub)
│
├── turn_started(player_id)
│   ├── -> QuestProgressTracker.tick_all()
│   ├── -> EventScheduler.begin_turn()
│   ├── -> EventRegistry.begin_turn()
│   └── -> UI overlays (HUD, quest tracker, supply overlay)
│
├── turn_ended(player_id)
│   ├── -> ResourceManager (production collection)
│   ├── -> SupplySystem / SupplyLogistics
│   └── -> WeatherSystem
│
├── resources_changed(player_id)
│   └── -> HUD, resource displays
│
├── army_changed(player_id, army_data)
│   └── -> Army panel, board visuals
│
├── combat_started / combat_ended
│   ├── -> CombatResolver
│   ├── -> BattleCutin
│   └── -> Combat UI popup
│
├── order_changed / threat_changed
│   └── -> HUD gauges, AI decisions
│
├── quest_updated / quest_completed
│   └── -> Quest journal panel, notification bar
│
├── message_log(text)
│   └── -> HUD message log, notification bar
│
└── (many more domain-specific signals)

GameManager orchestrates the turn loop:
  begin_turn() -> [AI turns -> human turn] -> end_turn()
  Each phase emits EventBus signals consumed by subsystems and UI.
```

## System Directory Descriptions

| Directory | Purpose |
|---|---|
| `autoloads/` | Core infrastructure singletons: GameManager (orchestrator), SaveManager (serialization), EventBus (signal hub), AudioManager, UI theming, CG gallery, asset loading, panel management. |
| `systems/audio/` | Scene-specific audio direction (SceneAudioDirector). Background music and SFX context switching. |
| `systems/balance/` | BalanceConfig (constants/tuning values) and BalanceManager (runtime balance adjustments). Single source of truth for game balance numbers. |
| `systems/building/` | BuildingRegistry (building definitions and effects) and ResearchManager (tech tree progression). |
| `systems/combat/` | Combat resolution pipeline: CombatResolver, CombatAbilities, CommanderIntervention, RecruitManager, EnvironmentSystem (terrain/weather combat modifiers), SiegeSystem, BattleCutin (visual effects), multi-route battles. |
| `systems/economy/` | Resource lifecycle: ResourceManager, SlaveManager, BuffManager, ItemManager, RelicManager, StrategicResourceManager, ProductionCalculator, TileDevelopment. Handles gold/food/iron/pop and special resources. |
| `systems/event/` | Event pipeline (9 subsystems): EventRegistry (master index), EventScheduler (weighted selection), EventSystem (base events), EffectResolver (event outcome application), plus SeasonalEvents, CrisisCountdown, GrandEventDirector, DynamicSituationEvents, FactionDestructionEvents, CharacterInteractionEvents, ExpandedRandomEvents, ExtraEventsV5. |
| `systems/faction/` | Faction mechanics: FactionManager, 3 evil-faction mechanics (Orc/Pirate/DarkElf), 4 AI controllers (Light/Alliance/Evil/Neutral), AIScaling, AIStrategicPlanner, DiplomacyManager, TreatySystem, EspionageSystem. |
| `systems/hero/` | Hero management: HeroSystem (recruitment, stats, equipment), HeroLeveling, HeroSkillsAdvanced, EnchantmentSystem, EquipmentForge. |
| `systems/map/` | Map generation and territory: FixedMapData (55-territory hand-designed map), NationSystem (nation-level territory control), territory effects. |
| `systems/march/` | Army movement: MarchSystem handles multi-turn army marches across the map. |
| `systems/mod/` | ModManager for loading user mods. |
| `systems/ngplus/` | New Game Plus: NgPlusManager tracks cross-run progression and unlocks. |
| `systems/npc/` | NPC and neutral faction quests: NpcManager (NPC definitions), QuestManager (neutral faction quest chains). |
| `systems/quest/` | Quest aggregation: QuestJournal (main/side/challenge/character quests), QuestProgressTracker (cross-system quest coordination and milestones). |
| `systems/story/` | Narrative systems: StoryEventSystem (hero story routes with branching), VnDirector (visual novel dialog presentation). |
| `systems/strategic/` | Strategic layer: SupplySystem (supply lines), SupplyLogistics (advanced logistics), SiegeSystem (siege warfare). |
| `systems/tutorial/` | TutorialManager: guided onboarding and contextual hints. |
| `systems/values/` | Core game gauges: OrderManager (public order), ThreatManager (external threat level). |
| `systems/web/` | Web/online features (if any). |
| `systems/world/` | World simulation: WeatherSystem (weather effects on gameplay). |
| `scenes/board/` | Game board scene: hex/node map rendering, tile visuals, army tokens. |
| `scenes/ui/` | All UI scenes: panels, overlays, dialogs, combat views, HUD, menus. |
