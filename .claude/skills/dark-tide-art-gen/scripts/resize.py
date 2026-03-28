#!/usr/bin/env python3
"""Resize generated images. Supports pixel-art (NEAREST) and smooth (LANCZOS) modes."""
import sys
from pathlib import Path
from PIL import Image

def resize(src: str, dst: str, size: int = 128, mode: str = "pixel"):
    resampler = Image.NEAREST if mode == "pixel" else Image.LANCZOS
    img = Image.open(src)
    img_out = img.resize((size, size), resampler)
    img_out.save(dst)
    print(f"OK {Path(dst).name}: {img.size} -> ({size},{size}) [{mode}]")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: resize.py <src> <dst> [size=128] [mode=pixel|smooth]")
        sys.exit(1)
    resize(
        sys.argv[1], sys.argv[2],
        int(sys.argv[3]) if len(sys.argv) > 3 else 128,
        sys.argv[4] if len(sys.argv) > 4 else "pixel",
    )
