#!/usr/bin/env python3
"""Prepares upload-ready copies of card and pack artwork for Roblox.

Never modifies the source files. For every entry in MAPPING it reads
assets/source/<source> and writes assets/processed/<target>:

  * Resized so the longest side is at most 1024 px. Roblox downsamples larger images on
    upload anyway, so this only removes wasted bytes and memory.
  * Alpha "snapped": the uploaded art has its card body at alpha 251-253 (about 1% see-through),
    which in 3D sends the image down Roblox's transparent render path (sorting/flicker). Alpha
    >= SNAP_THRESHOLD becomes 255; fully transparent pixels stay 0; softer anti-aliased edges
    below the threshold are kept as they are.
  * Verified: the four corners must be fully transparent (no baked checkerboard or
    background), otherwise the script stops and reports the file.
  * Thumbnails: every card also gets a THUMB_SIDE copy in <folder>/thumbs/ for small UI
    tiles (backpack grid, binder, pack summary), which only show the art at ~150-200 px.

Usage (repository root):  python3 scripts/assets/process_card_art.py
Requires Pillow (pip install pillow).
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCE = os.path.join(ROOT, "assets", "source")
OUTPUT = os.path.join(ROOT, "assets", "processed")
MAX_SIDE = 1024
THUMB_SIDE = 384
SNAP_THRESHOLD = 250

# source path (under assets/source) -> processed path (under assets/processed)
MAPPING = {
    "Pack 1/sandy 001.png": "pack1/card_001_sandy.png",
    "Pack 1/boba 002.png": "pack1/card_002_boba.png",
    "Pack 1/Sky 003.png": "pack1/card_003_sky.png",
    "Pack 1/Kingston 004.png": "pack1/card_004_kingston.png",
    "Pack 1/Aurora 005.png": "pack1/card_005_aurora.png",
    "Pack 1/Frost 006.png": "pack1/card_006_frost.png",
    "Pack 1/obal.png": "pack1/pack_front.png",
}


def process(src_rel: str, dst_rel: str) -> str:
    src = os.path.join(SOURCE, src_rel)
    dst = os.path.join(OUTPUT, dst_rel)
    image = Image.open(src)
    if image.mode != "RGBA":
        raise SystemExit(f"{src_rel}: expected RGBA with a real alpha channel, got {image.mode}")
    alpha = image.getchannel("A")
    w, h = image.size
    corners = [alpha.getpixel(p) for p in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
    if max(corners) > 8:
        raise SystemExit(f"{src_rel}: corners are not transparent {corners} - baked background?")

    alpha = alpha.point(lambda a: 255 if a >= SNAP_THRESHOLD else a)
    image.putalpha(alpha)
    scale = min(1.0, MAX_SIDE / max(w, h))
    if scale < 1.0:
        image = image.resize((round(w * scale), round(h * scale)), Image.LANCZOS)

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    image.save(dst, optimize=True)
    report = f"{src_rel} ({w}x{h}) -> {dst_rel} {image.size[0]}x{image.size[1]} {os.path.getsize(dst) // 1024} KB"

    if os.path.basename(dst_rel).startswith("card_"):
        thumb_rel = os.path.join(os.path.dirname(dst_rel), "thumbs", os.path.basename(dst_rel))
        thumb = os.path.join(OUTPUT, thumb_rel)
        tw, th = image.size
        tscale = THUMB_SIDE / max(tw, th)
        small = image.resize((round(tw * tscale), round(th * tscale)), Image.LANCZOS)
        os.makedirs(os.path.dirname(thumb), exist_ok=True)
        small.save(thumb, optimize=True)
        report += f"; thumb {small.size[0]}x{small.size[1]} {os.path.getsize(thumb) // 1024} KB"
    return report


def main() -> None:
    for src_rel, dst_rel in MAPPING.items():
        print(process(src_rel, dst_rel))


if __name__ == "__main__":
    sys.exit(main())
