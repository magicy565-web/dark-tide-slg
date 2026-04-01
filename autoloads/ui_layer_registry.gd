## ui_layer_registry.gd — Central registry of all UI layer constants.
## Eliminates layer conflicts by defining a single source of truth.
## Autoload: UILayerRegistry
extends Node

# ═══════════════════════════════════════════════════════════════
#               PERSISTENT OVERLAYS (always visible)
# ═══════════════════════════════════════════════════════════════

const LAYER_HUD = 1
const LAYER_QUEST_TRACKER = 2
const LAYER_TILE_INDICATORS = 3
const LAYER_INTEL_OVERLAY = 4

# ═══════════════════════════════════════════════════════════════
#          MODAL PANELS (one at a time via PanelManager)
# ═══════════════════════════════════════════════════════════════

const LAYER_HERO_PANEL = 5
const LAYER_INFO_PANELS = 6       # Diplomacy, Inventory, Tech Tree, Pirate, Quest Journal,
                                   # Equipment Forge, Nation, Multi-Route, Mission,
                                   # Troop Training, Army Panel
const LAYER_EVENT_POPUP = 7
const LAYER_DETAIL_PANELS = 8     # Hero Detail, Territory Info
const LAYER_COMBAT_POPUP = 9
const LAYER_BATTLE_PREP = 10
const LAYER_STORY_DIALOG = 11

# ═══════════════════════════════════════════════════════════════
#                    SYSTEM OVERLAYS
# ═══════════════════════════════════════════════════════════════

const LAYER_SAVE_LOAD = 12
const LAYER_EVENT_MANAGER = 13
const LAYER_ACTION_VISUALIZER = 14
const LAYER_AI_INDICATOR = 15
const LAYER_NOTIFICATION = 16
const LAYER_CG_GALLERY = 17
const LAYER_SUPPLY_OVERLAY = 18
const LAYER_TILE_DEVELOPMENT = 19

# ═══════════════════════════════════════════════════════════════
#              COMBAT (full screen takeover)
# ═══════════════════════════════════════════════════════════════

const LAYER_COMBAT_VIEW = 20
const LAYER_WEATHER_HUD = 21
const LAYER_COMBAT_INTERVENTION = 25
const LAYER_FORMATION_PREVIEW = 30

# ═══════════════════════════════════════════════════════════════
#                  TOP-LEVEL SYSTEM
# ═══════════════════════════════════════════════════════════════

const LAYER_SETTINGS = 90
const LAYER_MAIN_MENU = 95
const LAYER_DEBUG_CONSOLE = 98
const LAYER_GAME_OVER = 100
