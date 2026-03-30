# Asset Index - Dark Tide SLG

Last updated: 2026-03-30

Total asset files: 970

---

## Directory Structure Overview

```
assets/
  characters/          274 files - Hero character art and animations
    animations/          108 files - Chibi battle animation videos (.mp4)
    animations_ogv/       60 files - Chibi battle animations (.ogv, Godot-native)
    battles/               4 files - Full battle scene artwork
    chibi/               (18 subdirs) - Per-hero chibi PNG sprite sets
    designs/              19 files - Character design reference sheets
    heads/                 4 files - Character head/portrait crops
  effects/             110 files - Per-hero skill VFX (18 heroes x ~6 files each)
    {hero_name}/
      buff/                - Buff effect frames
      casting/             - Casting animation frames
      frames/              - Core animation frames (typically 3)
      impact/              - Impact effect frames
  fonts/                 1 file  - NotoSansCJKsc-Regular.otf
  icons/               246 files - Game icons organized by category
    buildings/            25 files - Building icons (lv1/lv2/lv3 per building)
    items/                30 files - Item icons
    skills/               30 files - Skill/ability icons
    troops/               24 files - Troop type icons (lv1/lv2/lv3)
    troops_light/         51 files - Light-style troop icons
    ui/                   70 files - UI element icons (buttons, bars, buffs, debuffs,
                                     crests, resources, terrain, panels)
  map/                 163 files - World map assets
    actions/              12 files - Map action icons
    backgrounds/           8 files - Map background tiles
    crests/                6 files - Faction crests (standard)
    crests_hd/             8 files - Faction crests (high-definition)
    decorations/          25 files - Map decorations
    faction_crests/        8 files - Faction crest variants
    map_decorations/       1 file  - Additional map decoration
    military_icons/        4 files - Military unit map icons
    resource_icons/        4 files - Resource icons for map overlay
    resources/             8 files - Resource node sprites
    settlements/          15 files - Settlement sprites (standard)
    settlements_hd/       15 files - Settlement sprites (high-definition)
    settlements_v3/       16 files - Settlement sprites (v3 redesign)
    terrain/              10 files - Terrain tiles (standard)
    terrain_hd/           10 files - Terrain tiles (high-definition)
    terrain_v3/           10 files - Terrain tiles (v3 redesign)
    ui_panels/             2 files - Map UI panel frames
  sprites/              17 files - Miscellaneous sprites
    light/                17 files - Light-themed sprite variants
  theme/                 1 file  - Godot theme resource
  ui/                   94 files - UI screens and HUD assets
    battle_bg/             6 files - Battle background scenes
    buttons/               5 files - Button sprites
    frames/               41 files - UI frame/border artwork
    icons_hd/              8 files - HD UI icons
    (root)                18 files - Backgrounds, panel frames, resource bar icons
  vfx/                  64 files - General visual effects
    attack/                8 files
    awakening/             1 file
    buff/                  4 files
    combo/                10 files
    debuff/                3 files
    formation/            10 files
    heal/                  2 files
    morale/                3 files
    passive/               5 files
    ultimate/             18 files
```

---

## Naming Conventions

### General Rules
- All lowercase with underscores: `snake_case.png`
- No spaces or special characters in filenames
- Hero directories use numbered prefix: `{NN}_{name}/` (e.g., `01_rin/`, `13_hibiki/`)

### Chibi Sprite States
Each complete chibi hero folder contains 6 PNG files named by state:
- `idle.png`, `attack.png`, `cast.png`, `hurt.png`, `defeated.png`, `victory.png`

Note: `08_sou` has an additional `walk.png` (7 files).

### Animation Files
- MP4 pattern: `{NN}_{name}_chibi_{state}.mp4`
- OGV pattern: `{NN}_{name}_chibi_{state}.ogv`
- States match chibi PNGs: idle, attack, cast, hurt, defeated, victory

### Building and Troop Icons
- Level-suffixed: `{name}_lv1.png`, `{name}_lv2.png`, `{name}_lv3.png`

### Map Asset Versions
- Standard (base): `map/terrain/`, `map/settlements/`, `map/crests/`
- High-definition: `map/terrain_hd/`, `map/settlements_hd/`, `map/crests_hd/`
- Version 3 redesign: `map/terrain_v3/`, `map/settlements_v3/`

### UI Icons
- Resource icons: `icon_{resource_name}.png` (in `assets/ui/`)
- Button icons: `btn_{action}.png` (in `assets/icons/ui/`)
- Buff/debuff icons: `buff_{name}.png` / `debuff_{name}.png` (in `assets/icons/ui/`)
- Faction crests: `crest_{faction}.png` (in `assets/icons/ui/`)

---

## Known Missing Assets

### Incomplete Chibi Sprite Sets
The following heroes only have a reference image (`*_ref_0.png`) and no battle sprites:
- `04_hyouka` - missing all 6 states
- `11_shion_pirate` - missing all 6 states
- `12_youya` - missing all 6 states
- `15_mei` - missing all 6 states
- `16_kaede` - missing all 6 states
- `18_hanabi` - missing all 6 states

### Missing Hero in HERO_FOLDERS Mapping
- ~~`14_sara` has chibi sprites on disk but is missing from the `HERO_FOLDERS` dictionary in `chibi_sprite_loader.gd`.~~ **Fixed** (added `"sara": "14_sara"` entry).

### OGV Coverage
Only 10 of 18 heroes have `.ogv` video animations. The remaining 8 rely on PNG fallback.

---

## Versioned / HD Asset Notes

Three map asset categories have multiple resolution variants:

| Category    | Standard | HD  | v3  |
|-------------|----------|-----|-----|
| Terrain     | 10 files | 10  | 10  |
| Settlements | 15 files | 15  | 16  |
| Crests      | 6 files  | 8   | n/a |

- **HD** variants are higher resolution versions of the same assets.
- **v3** variants are a visual redesign (different art style, not just higher resolution).
- The active variant used at runtime depends on the graphics quality setting.
- The `settlements_hd/` `_v2` alternates were archived (see below) as they are not referenced in code.

---

## Archived Assets (`assets/_archive/`)

Archived on 2026-03-30 during versioned-asset consolidation. These files are **not referenced** by any `.gd`, `.tscn`, or `.tres` file in the project. They are preserved here in case they are needed for future art iterations.

| Archive subdirectory | Files | Size | Reason |
|----------------------|-------|------|--------|
| `settlements_hd_v2/` | 15 | ~1.0 MB | Alternate `_v2` settlement HD sprites; code only loads the base name (`settlement_<name>.png`), never the `_v2` variant. |
| `terrain_tiles/` | 1 | ~5.5 MB | Standalone terrain tileset spritesheet; not referenced anywhere in code. Individual terrain tiles in `terrain/`, `terrain_hd/`, and `terrain_v3/` are used instead. |
| `territory_icons/` | 8 | ~656 KB | Versioned territory icon sets (`hd_icons_v0-v3`, `pixel_icons_v0-v3`); not referenced in any script or scene. |

**Total: 24 files, ~7.1 MB archived.**

To restore any archived asset, move it back to `assets/map/<original_dir>/` and re-import in the Godot editor.

---

## Character Design Size Inconsistencies

The standard character design resolution is **896 x 1344**. The following designs deviate:

| File | Resolution | Note |
|------|-----------|------|
| `02_yukino_A.png` | 1024 x 1440 | Larger than standard; will be scaled down by UI code at display time. |
| `05_suirei_B.png` | 768 x 1024 | Smaller than standard; may appear lower-quality when displayed at the same UI size. |

No GDScript display code hardcodes the 896x1344 dimensions -- portrait display uses `custom_minimum_size` constraints that scale any source image -- so these size differences do not cause runtime errors, only potential visual quality variation.

---

## Repaired Corrupted Effect Frames

The following effect frame PNGs were found truncated/corrupted and replaced with the nearest valid frame from the same sequence:

| Corrupted file | Replaced with |
|---------------|--------------|
| `assets/effects/gekka/frames/moonshield_f3_complete.png` | Copy of `moonshield_f2_expand.png` |
| `assets/effects/shion_pirate/frames/rapid_f1_aim.png` | Copy of `rapid_f3_hit.png` |
| `assets/effects/shion_pirate/frames/rapid_f2_fire.png` | Copy of `rapid_f3_hit.png` |

These are placeholder repairs. The frames should be re-exported from source artwork when available.
