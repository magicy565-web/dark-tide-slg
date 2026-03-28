---
name: dark-tide-art-gen
description: Batch generate game art assets for Dark Tide SLG using MuleRouter AI image generation. Use when creating or replacing item icons (pixel art or painterly), skill effect VFX (casting circles, impact effects, buff auras, animation frames), character portraits, battle backgrounds, or any visual asset for the game. Triggers on requests for game art, icons, sprites, VFX, effects, or visual assets for Dark Tide.
---

# Dark Tide Art Gen

Batch AI art generation for Dark Tide SLG game assets via MuleRouter Nano-Banana Pro API.

## Quick Start

Generate a single asset:
```bash
chmod +x scripts/gen_asset.sh
scripts/gen_asset.sh "/output/path/icon.png" "prompt text" "1:1" "2K"
```

Resize for pixel art (NEAREST neighbor preserves crisp pixels):
```bash
python scripts/resize.py source.png output.png 128 pixel
```

## Asset Types & Workflow

### 1. Pixel Art Item Icons
- Resolution: Generate at 1K, resize to 128x128 with `resize.py pixel`
- Aspect ratio: 1:1
- See `references/prompt_templates.md` → "Pixel Art Item Icons" prefix
- Existing icons: `assets/icons/items/` (29 items, all pixel art)

### 2. Skill Effect VFX (per character)
Each character needs 4 asset types per skill:
- **Casting circle** — magic circle / aura activation
- **Impact effect** — hit / damage / heal visual
- **Buff aura** — status effect overlay
- **3 animation frames** — sequence: charge → release → hit

- Resolution: 2K source
- Aspect ratio: 1:1
- See `references/prompt_templates.md` for each sub-type prefix
- Existing effects: `assets/effects/{character_name}/`

### 3. Character Portraits & Battle Backgrounds
- Portraits: 2K, 2:3 aspect ratio
- Backgrounds: 2K, 16:9 aspect ratio

## Batch Generation Pattern

Run 6-7 parallel jobs for throughput. Use `&` and `wait`:

```bash
scripts/gen_asset.sh "/out/item1.png" "prompt1" &
scripts/gen_asset.sh "/out/item2.png" "prompt2" &
scripts/gen_asset.sh "/out/item3.png" "prompt3" &
scripts/gen_asset.sh "/out/item4.png" "prompt4" &
scripts/gen_asset.sh "/out/item5.png" "prompt5" &
scripts/gen_asset.sh "/out/item6.png" "prompt6" &
wait
```

## Faction Color Reference

| Faction | Colors | Keywords |
|---------|--------|----------|
| Human 天城王朝 | Gold #DAA520 | golden, warm, sacred, white |
| Elf 银月议庭 | Green #006633 | emerald, silver, forest, nature |
| Mage 白塔同盟 | Blue #0047AB / Purple #7B2FBE | arcane, cosmic, deep blue |
| Pirate 深渊之牙 | Navy #1B2A4A / Gold | ocean blue, dark navy |
| Dark Elf 永夜议会 | Purple #3D0066 | deep violet, shadow, dark |
| Orc 铁牙氏族 | Red #8B0000 | dark red, iron gray, fire |
| Neutral | Brown #8B7D6B | earth, sandy, golden brown |

## Prompt Engineering Tips

- Always append `no text no words` to prevent AI-generated text on images
- Use `dark background` for VFX (compositing friendly)
- Use `black background` for item icons
- Use `white background` for character design sheets
- For full prompt templates, read `references/prompt_templates.md`

## Post-Processing

Pixel art resize (preserves sharp edges):
```bash
python scripts/resize.py src.png dst.png 128 pixel
```

Smooth resize (for non-pixel assets):
```bash
python scripts/resize.py src.png dst.png 256 smooth
```

Batch resize all PNGs in a directory:
```python
from pathlib import Path
from PIL import Image
for f in Path("src_dir").glob("*.png"):
    img = Image.open(f).resize((128, 128), Image.NEAREST)
    img.save(Path("dst_dir") / f.name)
```
