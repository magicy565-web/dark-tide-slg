#!/usr/bin/env python3
"""
Dark Tide SLG — Batch PNG→WebP Asset Compressor
Converts PNG assets to WebP format with quality tiers based on asset type.
Generates a manifest of conversions for Godot import remapping.

Usage:
    python3 tools/compress_assets.py [--dry-run] [--quality 80] [--min-size 50000]
    python3 tools/compress_assets.py --report  # Size report only, no conversion
"""

import argparse
import json
import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

# Placeholder — filled in main()
PROJECT_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = PROJECT_ROOT / "assets"
MANIFEST_PATH = PROJECT_ROOT / "tools" / "compress_manifest.json"

# ═══════════════ QUALITY TIERS ═══════════════

QUALITY_TIERS = {
    # Large effect/VFX frames: aggressive compression (lossy OK for particle effects)
    "effects": {"quality": 70, "method": 6, "min_size": 100_000},
    # Character animations: moderate compression (preserve detail)
    "characters/animations": {"quality": 75, "method": 6, "min_size": 100_000},
    # Character designs/portraits: high quality (key visual assets)
    "characters/designs": {"quality": 85, "method": 6, "min_size": 50_000},
    "characters/heads": {"quality": 85, "method": 6, "min_size": 50_000},
    "characters/chibi": {"quality": 80, "method": 6, "min_size": 50_000},
    "characters/battles": {"quality": 80, "method": 6, "min_size": 50_000},
    # Icons: lossless (small files, pixel-perfect matters)
    "icons": {"quality": 100, "method": 6, "lossless": True, "min_size": 0},
    # UI elements: lossless
    "ui": {"quality": 100, "method": 6, "lossless": True, "min_size": 0},
    # Map tiles: moderate
    "map": {"quality": 80, "method": 6, "min_size": 10_000},
    # VFX sprites: aggressive
    "vfx": {"quality": 70, "method": 6, "min_size": 50_000},
    # Sprites: moderate
    "sprites": {"quality": 80, "method": 6, "min_size": 10_000},
    # Default fallback
    "_default": {"quality": 80, "method": 6, "min_size": 50_000},
}


def get_tier(rel_path: str) -> dict:
    """Determine quality tier based on relative asset path."""
    rel_lower = rel_path.replace("\\", "/").lower()
    # Check most specific paths first
    for prefix in sorted(QUALITY_TIERS.keys(), key=len, reverse=True):
        if prefix.startswith("_"):
            continue
        if rel_lower.startswith(prefix) or f"/{prefix}" in rel_lower:
            return QUALITY_TIERS[prefix]
    return QUALITY_TIERS["_default"]


# ═══════════════ CONVERSION ═══════════════

def convert_single(png_path: str, webp_path: str, tier: dict) -> dict:
    """Convert a single PNG to WebP. Returns result dict."""
    from PIL import Image

    result = {
        "src": png_path,
        "dst": webp_path,
        "src_size": os.path.getsize(png_path),
        "dst_size": 0,
        "saved": 0,
        "ratio": 0.0,
        "status": "ok",
        "error": "",
    }
    try:
        img = Image.open(png_path)
        # Ensure RGBA for transparency support
        if img.mode not in ("RGBA", "RGB"):
            img = img.convert("RGBA")

        save_kwargs = {
            "quality": tier.get("quality", 80),
            "method": tier.get("method", 6),
        }
        if tier.get("lossless", False):
            save_kwargs["lossless"] = True

        os.makedirs(os.path.dirname(webp_path), exist_ok=True)
        img.save(webp_path, "WEBP", **save_kwargs)
        img.close()

        result["dst_size"] = os.path.getsize(webp_path)
        result["saved"] = result["src_size"] - result["dst_size"]
        result["ratio"] = (
            result["dst_size"] / result["src_size"] if result["src_size"] > 0 else 0
        )
    except Exception as e:
        result["status"] = "error"
        result["error"] = str(e)
    return result


def collect_pngs(assets_dir: Path, min_size_override: int = None) -> list:
    """Collect all PNG files eligible for conversion."""
    files = []
    for png in assets_dir.rglob("*.png"):
        rel = str(png.relative_to(assets_dir))
        tier = get_tier(rel)
        min_size = min_size_override if min_size_override is not None else tier["min_size"]
        if png.stat().st_size >= min_size:
            webp = png.with_suffix(".webp")
            files.append({
                "png": str(png),
                "webp": str(webp),
                "rel": rel,
                "tier": tier,
                "size": png.stat().st_size,
            })
    return sorted(files, key=lambda f: -f["size"])


# ═══════════════ REPORTING ═══════════════

def print_report(files: list):
    """Print size analysis report without converting."""
    by_dir = {}
    total_size = 0
    for f in files:
        parts = f["rel"].split("/")
        dir_key = parts[0] if len(parts) > 1 else "_root"
        if dir_key not in by_dir:
            by_dir[dir_key] = {"count": 0, "size": 0}
        by_dir[dir_key]["count"] += 1
        by_dir[dir_key]["size"] += f["size"]
        total_size += f["size"]

    print(f"\n{'Directory':<30} {'Files':>6} {'Size':>10} {'% Total':>8}")
    print("=" * 58)
    for d in sorted(by_dir, key=lambda k: -by_dir[k]["size"]):
        info = by_dir[d]
        pct = info["size"] / total_size * 100 if total_size > 0 else 0
        print(f"{d:<30} {info['count']:>6} {info['size']/1024/1024:>8.1f}MB {pct:>7.1f}%")
    print("=" * 58)
    print(f"{'TOTAL':<30} {len(files):>6} {total_size/1024/1024:>8.1f}MB {'100.0':>7}%")

    # Estimated savings
    print("\n--- Estimated savings (based on typical WebP compression) ---")
    est_savings = {
        "effects": 0.35,
        "characters/animations": 0.40,
        "characters/designs": 0.50,
        "characters/heads": 0.50,
        "characters/chibi": 0.45,
        "characters/battles": 0.45,
        "icons": 0.70,
        "ui": 0.70,
        "map": 0.45,
        "vfx": 0.35,
        "sprites": 0.45,
        "_default": 0.45,
    }
    total_est = 0
    for f in files:
        tier_name = "_default"
        for prefix in sorted(QUALITY_TIERS.keys(), key=len, reverse=True):
            if prefix.startswith("_"):
                continue
            if f["rel"].lower().startswith(prefix):
                tier_name = prefix
                break
        ratio = est_savings.get(tier_name, 0.45)
        total_est += f["size"] * ratio
    print(f"Estimated output size: ~{total_est/1024/1024:.0f}MB")
    print(f"Estimated savings:    ~{(total_size - total_est)/1024/1024:.0f}MB ({(1 - total_est/total_size)*100:.0f}% reduction)")


# ═══════════════ MAIN ═══════════════

def main():
    parser = argparse.ArgumentParser(description="Dark Tide SLG asset compressor")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be converted")
    parser.add_argument("--report", action="store_true", help="Print size report only")
    parser.add_argument("--quality", type=int, help="Override quality for all tiers")
    parser.add_argument("--min-size", type=int, default=None, help="Override minimum file size (bytes)")
    parser.add_argument("--workers", type=int, default=4, help="Parallel workers")
    parser.add_argument("--replace", action="store_true", help="Delete original PNGs after conversion")
    parser.add_argument("--dir", type=str, default=None, help="Only process this subdirectory")
    args = parser.parse_args()

    target_dir = ASSETS_DIR / args.dir if args.dir else ASSETS_DIR
    if not target_dir.exists():
        print(f"ERROR: {target_dir} does not exist")
        sys.exit(1)

    files = collect_pngs(target_dir, args.min_size)
    print(f"Found {len(files)} PNG files eligible for conversion")

    if args.report:
        print_report(files)
        return

    if args.dry_run:
        for f in files[:20]:
            tier = f["tier"]
            q = args.quality if args.quality else tier["quality"]
            ll = " [lossless]" if tier.get("lossless") else ""
            print(f"  {f['rel']:60s} {f['size']/1024:>7.0f}KB  q={q}{ll}")
        if len(files) > 20:
            print(f"  ... and {len(files) - 20} more")
        return

    # Apply quality override
    if args.quality:
        for f in files:
            f["tier"] = dict(f["tier"])
            f["tier"]["quality"] = args.quality
            if args.quality >= 100:
                f["tier"]["lossless"] = True

    print(f"Converting with {args.workers} workers...")
    start = time.time()
    results = []
    errors = []

    with ProcessPoolExecutor(max_workers=args.workers) as executor:
        futures = {}
        for f in files:
            fut = executor.submit(convert_single, f["png"], f["webp"], f["tier"])
            futures[fut] = f

        done_count = 0
        for fut in as_completed(futures):
            res = fut.result()
            done_count += 1
            if res["status"] == "error":
                errors.append(res)
            else:
                results.append(res)
            if done_count % 50 == 0 or done_count == len(files):
                print(f"  [{done_count}/{len(files)}] processed")

    elapsed = time.time() - start
    total_src = sum(r["src_size"] for r in results)
    total_dst = sum(r["dst_size"] for r in results)
    total_saved = total_src - total_dst

    print(f"\n{'='*60}")
    print(f"Converted: {len(results)} files in {elapsed:.1f}s")
    print(f"Original:  {total_src/1024/1024:.1f}MB")
    print(f"WebP:      {total_dst/1024/1024:.1f}MB")
    print(f"Saved:     {total_saved/1024/1024:.1f}MB ({total_saved/total_src*100:.0f}% reduction)")

    if errors:
        print(f"\nErrors: {len(errors)}")
        for e in errors[:5]:
            print(f"  {e['src']}: {e['error']}")

    # Save manifest
    manifest = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "total_files": len(results),
        "total_src_bytes": total_src,
        "total_dst_bytes": total_dst,
        "savings_bytes": total_saved,
        "files": [
            {
                "src": os.path.relpath(r["src"], PROJECT_ROOT),
                "dst": os.path.relpath(r["dst"], PROJECT_ROOT),
                "src_size": r["src_size"],
                "dst_size": r["dst_size"],
            }
            for r in results
        ],
    }
    with open(MANIFEST_PATH, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nManifest saved to {MANIFEST_PATH}")

    # Delete originals if requested
    if args.replace:
        deleted = 0
        for r in results:
            if r["status"] == "ok" and os.path.exists(r["dst"]):
                os.remove(r["src"])
                deleted += 1
        print(f"Deleted {deleted} original PNG files")
        print("NOTE: You must update all .tscn/.gd references from .png to .webp")


if __name__ == "__main__":
    main()
