---
name: Dark Tide SLG Art Production
description: Batch AI art generation workflow for Dark Tide SLG game assets — pixel item icons, skill VFX, and character art.
initial_prompt: "继续做暗潮Dark Tide SLG的美术资源。仓库 https://github.com/magicy565-web/dark-tide-slg.git，需要生成游戏道具图标、技能特效、角色立绘等素材，使用MuleRouter API批量生成。"
---

## Unique Skills

| Skill Name | Purpose |
|------------|---------|
| dark-tide-art-gen | Batch AI art generation for game assets via MuleRouter Nano-Banana Pro |

## Project Context

- **Game**: 暗潮 Dark Tide — Japanese-style 2D SLG (Sengoku Rance reference)
- **Engine**: Godot 4.x, GDScript
- **Repo**: `dark-tide-slg` on GitHub, main branch
- **Art style**: Japanese 2D anime illustration (dark fantasy), with pixel art for item icons
- **18 heroines** across 6 factions (Human, Elf, Mage, Pirate, Dark Elf, Neutral)
- **Docs**: `docs/game_docs/13_美术.md` (art guide), `docs/game_docs/15_角色视觉设定.md` (character specs)

## Conventions

- Asset directories: `assets/icons/items/`, `assets/icons/buildings/`, `assets/icons/troops/`, `assets/icons/skills/`, `assets/icons/ui/`, `assets/effects/{character}/`, `assets/characters/`
- Effect subdirs per character: `casting/`, `impact/`, `buff/`, `frames/`
- Naming: snake_case for all asset filenames
- Item icons: 128x128 pixel art PNG, resized from 1K source with NEAREST neighbor
- Skill effects: 2K resolution source PNG
- Git config: user `magicy565` / `magicy565@users.noreply.github.com`

## Key Patterns

- **MuleRouter Nano-Banana Pro** is the primary image generation model — fast, high quality, supports 1K/2K output
- Run 6-7 parallel `gen_asset.sh` jobs with `&` + `wait` for batch throughput
- Always add `no text no words` to prompts to prevent unwanted text in generated images
- Use `dark background` for VFX compositing, `black background` for icons
- `git pull --rebase origin main` before push — remote may have concurrent changes
- Binary merge conflicts: resolve by copying our generated files over and `git add`

## Workflow

1. Clone repo with token auth, explore `docs/game_docs/` for requirements
2. Check existing assets in `assets/` to identify missing items
3. Use `dark-tide-art-gen` skill scripts for batch generation
4. Post-process (resize/crop) with Pillow
5. Copy to both repo `assets/` and `output/` for user download
6. Build HTML preview gallery, serve on port 8080, use `mcp__render__show`
7. Commit and push to GitHub

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Pixel art for item icons (128x128) | User preference — unified retro aesthetic |
| High-res Japanese style for skill VFX | Matches game's core art direction (Sengoku Rance reference) |
| Nano-Banana Pro over other models | Best quality-to-speed ratio for game art |
| 6-7 parallel jobs per batch | Balances API throughput without rate limiting |
| Faction-ordered production | User preferred batch by faction (Human → Elf → Mage → Pirate → DarkElf → Neutral) |

## Lessons

- Some AI-generated images include unwanted text despite "no text" in prompt — may need post-processing cleanup
- `gen_one.sh` must be called with absolute path (`/workspace/gen_one.sh`) when backgrounded — relative paths fail in subshells
- Remote repo may update between commit and push; always `git pull --rebase` before push
- Large binary pushes can timeout at 120s; use 300s timeout for git push
- When `uv` first runs it installs deps — only first call is slow, subsequent calls are fast
