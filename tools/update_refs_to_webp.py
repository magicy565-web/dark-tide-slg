#!/usr/bin/env python3
"""
Dark Tide SLG — Update Godot resource references from .png to .webp
After running compress_assets.py --replace, run this to update all references.

Usage:
    python3 tools/update_refs_to_webp.py [--dry-run]
"""

import argparse
import os
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SCAN_EXTENSIONS = {".gd", ".tscn", ".tres", ".cfg", ".godot"}
ASSETS_DIR = PROJECT_ROOT / "assets"


def find_webp_files() -> set:
    """Collect all .webp files that have been converted."""
    webps = set()
    for webp in ASSETS_DIR.rglob("*.webp"):
        rel = str(webp.relative_to(PROJECT_ROOT)).replace("\\", "/")
        webps.add(rel)
    return webps


def find_source_files() -> list:
    """Find all Godot project files that may reference assets."""
    files = []
    for ext in SCAN_EXTENSIONS:
        files.extend(PROJECT_ROOT.rglob(f"*{ext}"))
    return sorted(files)


def update_references(dry_run: bool = False):
    webps = find_webp_files()
    if not webps:
        print("No .webp files found. Run compress_assets.py first.")
        return

    # Build mapping: "assets/foo/bar.png" -> "assets/foo/bar.webp"
    png_to_webp = {}
    for wp in webps:
        png_path = wp.rsplit(".", 1)[0] + ".png"
        png_to_webp[png_path] = wp

    source_files = find_source_files()
    total_replacements = 0
    modified_files = 0

    for src_file in source_files:
        try:
            content = src_file.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError):
            continue

        new_content = content
        file_replacements = 0

        for png_ref, webp_ref in png_to_webp.items():
            # Match both res:// and relative paths
            res_png = f"res://{png_ref}"
            res_webp = f"res://{webp_ref}"

            if res_png in new_content:
                new_content = new_content.replace(res_png, res_webp)
                file_replacements += new_content.count(res_webp)

            # Also match quoted relative paths
            if f'"{png_ref}"' in new_content:
                new_content = new_content.replace(f'"{png_ref}"', f'"{webp_ref}"')
                file_replacements += 1

        if file_replacements > 0:
            rel_path = src_file.relative_to(PROJECT_ROOT)
            if dry_run:
                print(f"  [DRY] {rel_path}: {file_replacements} replacements")
            else:
                src_file.write_text(new_content, encoding="utf-8")
                print(f"  {rel_path}: {file_replacements} replacements")
            total_replacements += file_replacements
            modified_files += 1

    print(f"\n{'[DRY RUN] ' if dry_run else ''}Updated {total_replacements} references in {modified_files} files")


def main():
    parser = argparse.ArgumentParser(description="Update Godot refs from .png to .webp")
    parser.add_argument("--dry-run", action="store_true", help="Show changes without writing")
    args = parser.parse_args()
    update_references(dry_run=args.dry_run)


if __name__ == "__main__":
    main()
