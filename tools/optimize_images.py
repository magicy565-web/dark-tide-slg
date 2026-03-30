#!/usr/bin/env python3
"""
Image optimization script for Dark Tide SLG.

Optimizes PNG files under assets/ by:
  - Re-saving PNGs with optimize=True to reduce file size without quality loss
  - Resizing icon images that exceed 256x256 (icons/buildings, icons/items, icons/skills, etc.)
  - NOT modifying dimensions of character art, backgrounds, effects, or VFX

Usage:
    python3 tools/optimize_images.py [--dry-run] [--icon-max 256]

    --dry-run    Show what would be done without modifying files
    --icon-max   Maximum icon dimension (default: 256)
"""

import argparse
import os
import sys
from pathlib import Path

from PIL import Image

ASSETS_ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")

# Directories whose images are icons and may be resized
ICON_DIRS = {"icons", "military_icons", "resource_icons", "territory_icons"}

# Directories whose images should NEVER be resized (only file-size optimized)
NO_RESIZE_CATEGORIES = {"characters", "effects", "vfx", "map/backgrounds", "ui/battle_bg", "sprites"}


def is_icon_path(rel_path: str) -> bool:
    """Return True if the image lives under an icon directory."""
    parts = set(rel_path.split("/"))
    return bool(parts & ICON_DIRS)


def should_skip_resize(rel_path: str) -> bool:
    """Return True if the image should not be resized (characters, backgrounds, effects, etc.)."""
    for prefix in NO_RESIZE_CATEGORIES:
        if rel_path.startswith(prefix):
            return True
    return False


def optimize_png(fpath: str, rel_path: str, icon_max: int, dry_run: bool) -> dict:
    """Optimize a single PNG file. Returns a result dict."""
    original_size = os.path.getsize(fpath)
    result = {
        "path": rel_path,
        "original_size_kb": round(original_size / 1024, 2),
        "new_size_kb": None,
        "saved_kb": 0,
        "resized": False,
        "action": "skipped",
    }

    try:
        img = Image.open(fpath)
    except Exception as e:
        result["action"] = f"error: {e}"
        return result

    width, height = img.size
    fmt = img.format
    resized = False

    # Only resize icons that are too large
    if is_icon_path(rel_path) and not should_skip_resize(rel_path):
        if width > icon_max or height > icon_max:
            img.thumbnail((icon_max, icon_max), Image.LANCZOS)
            resized = True

    if dry_run:
        if resized:
            result["action"] = f"would resize to {img.size[0]}x{img.size[1]} and optimize"
        else:
            result["action"] = "would optimize (no resize)"
        img.close()
        return result

    # Save with optimization
    save_kwargs = {"optimize": True}
    if img.mode in ("RGBA", "LA", "PA"):
        save_kwargs["format"] = "PNG"
    elif img.mode == "P":
        save_kwargs["format"] = "PNG"
    else:
        save_kwargs["format"] = "PNG"

    try:
        img.save(fpath, **save_kwargs)
    except Exception as e:
        result["action"] = f"save error: {e}"
        img.close()
        return result

    img.close()

    new_size = os.path.getsize(fpath)
    saved = original_size - new_size
    result["new_size_kb"] = round(new_size / 1024, 2)
    result["saved_kb"] = round(saved / 1024, 2)
    result["resized"] = resized
    result["action"] = "optimized" + (" + resized" if resized else "")

    return result


def main():
    parser = argparse.ArgumentParser(description="Optimize image assets for Dark Tide SLG")
    parser.add_argument("--dry-run", action="store_true", help="Preview changes without modifying files")
    parser.add_argument("--icon-max", type=int, default=256, help="Max icon dimension (default: 256)")
    args = parser.parse_args()

    if not os.path.isdir(ASSETS_ROOT):
        print(f"Error: assets directory not found at {ASSETS_ROOT}")
        sys.exit(1)

    print(f"{'[DRY RUN] ' if args.dry_run else ''}Scanning {ASSETS_ROOT}...")
    print(f"Icon max dimension: {args.icon_max}x{args.icon_max}")
    print()

    results = []
    total_saved = 0
    total_resized = 0
    total_optimized = 0
    errors = []

    for root, dirs, files in os.walk(ASSETS_ROOT):
        for fname in sorted(files):
            if not fname.lower().endswith(".png"):
                continue

            fpath = os.path.join(root, fname)
            rel_path = os.path.relpath(fpath, ASSETS_ROOT)

            result = optimize_png(fpath, rel_path, args.icon_max, args.dry_run)
            results.append(result)

            if "error" in result["action"]:
                errors.append(result)
            elif result["action"] != "skipped":
                total_optimized += 1
                if result.get("resized"):
                    total_resized += 1
                if result.get("saved_kb", 0) > 0:
                    total_saved += result["saved_kb"]

    # Print summary
    print("=" * 60)
    print(f"{'[DRY RUN] ' if args.dry_run else ''}Optimization Summary")
    print("=" * 60)
    print(f"Files processed:   {len(results)}")
    print(f"Files optimized:   {total_optimized}")
    print(f"Icons resized:     {total_resized}")
    if not args.dry_run:
        print(f"Total saved:       {round(total_saved / 1024, 2)} MB ({round(total_saved, 2)} KB)")
    if errors:
        print(f"Errors:            {len(errors)}")
        for e in errors:
            print(f"  - {e['path']}: {e['action']}")
    print()

    # Show top savings
    if not args.dry_run:
        top_savings = sorted([r for r in results if r["saved_kb"] > 0], key=lambda x: -x["saved_kb"])[:20]
        if top_savings:
            print("Top 20 files by savings:")
            for r in top_savings:
                print(f"  {r['path']}: {r['original_size_kb']}KB -> {r['new_size_kb']}KB (saved {r['saved_kb']}KB){' [resized]' if r['resized'] else ''}")

    # Show resized icons
    if args.dry_run:
        resized_list = [r for r in results if r.get("resized") or "would resize" in r.get("action", "")]
        if resized_list:
            print(f"\nIcons that would be resized ({len(resized_list)}):")
            for r in resized_list:
                print(f"  {r['path']}: {r['action']}")


if __name__ == "__main__":
    main()
