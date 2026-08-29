#!/usr/bin/env python3
"""Downscale the hand-drawn source art in assets/ to its true pixel-art resolution.

Every sprite Neo drew is 32x32 pixel art exported at a huge nearest-neighbour
upscale (up to 4128x4128, which is ~68 MB of VRAM per frame on a Raspberry Pi).
This script recovers the original grid and writes game-ready copies into
assets/game/, leaving assets/<source folders>/ completely untouched.

The block size is recovered by taking the GCD of the run lengths of identical
rows and identical columns: a nearest-neighbour upscale by N produces runs that
are all multiples of N.

    pip install pillow
    python3 tools/normalize_assets.py

Outputs are committed, so this only needs re-running when new art lands.
"""

from __future__ import annotations

import math
import shutil
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - dependency hint only
    sys.exit("This script needs Pillow:  pip install pillow")

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets"
OUT = SRC / "game"

# source -> destination, relative to assets/
COPIES: list[tuple[str, str]] = [
    ("player_sprite/player_idle/player_idle_down.png", "player/idle_down.png"),
    ("player_sprite/player_idle/player_idle_left.png", "player/idle_left.png"),
    ("player_sprite/player_idle/player_idle_right.png", "player/idle_right.png"),
    ("wind_leaf_game/leaf.png", "wind_leaf/leaf.png"),
    ("fishing_game/fish_1.png", "fishing/fish_1.png"),
    ("fishing_game/fish_2.png", "fishing/fish_2.png"),
    ("fishing_game/plastic_bottle.png", "fishing/plastic.png"),
]
for i in range(1, 5):
    COPIES.append((f"player_sprite/player_walking_down/player_walk_down_{i}.png",
                   f"player/walk_down_{i - 1}.png"))
for direction in ("left", "right", "up"):
    for i in range(4):
        COPIES.append((f"player_sprite/player_walking_{direction}/pixil-frame-{i}.png",
                       f"player/walk_{direction}_{i}.png"))
for i in range(1, 9):
    COPIES.append((f"ordering_game/stage_door/stage_door_{i}.png", f"cave/door_{i}.png"))
for i in range(1, 6):
    COPIES.append((f"village/house_{i}.png", f"village/house_{i}.png"))

# Folders whose raw contents Godot should never import.
GDIGNORE_DIRS = [
    "player_sprite", "fishing_game", "wind_leaf_game", "ordering_game", "village",
]


def run_lengths(rows) -> list[int]:
    """Lengths of consecutive identical rows in a list of hashable row keys."""
    out, i, n = [], 0, len(rows)
    while i < n:
        j = i + 1
        while j < n and rows[j] == rows[i]:
            j += 1
        out.append(j - i)
        i = j
    return out


def detect_block_size(img: Image.Image) -> int:
    """Recover the nearest-neighbour upscale factor, or 1 if the art is native."""
    px = img.load()
    w, h = img.size
    rows = [tuple(px[x, y] for x in range(w)) for y in range(h)]
    cols = [tuple(px[x, y] for y in range(h)) for x in range(w)]

    block = 0
    for length in run_lengths(rows) + run_lengths(cols):
        block = math.gcd(block, length)
    if block <= 1:
        return 1
    # Only trust a factor that divides both dimensions cleanly.
    while block > 1 and (w % block or h % block):
        block -= 1
    return max(block, 1)


def normalize(src: Path, dst: Path) -> str:
    img = Image.open(src).convert("RGBA")
    block = detect_block_size(img)
    dst.parent.mkdir(parents=True, exist_ok=True)
    if block == 1:
        shutil.copyfile(src, dst)
        return f"{src.name:34s} {img.size[0]}x{img.size[1]} native -> copied"
    small = img.resize((img.size[0] // block, img.size[1] // block), Image.NEAREST)
    small.save(dst)
    return f"{src.name:34s} {img.size[0]}x{img.size[1]} /{block} -> {small.size[0]}x{small.size[1]}"


def derive_idle_up() -> str:
    """No back-facing idle was drawn; hold frame 0 of the up walk cycle instead."""
    walk_up = OUT / "player/walk_up_0.png"
    idle_up = OUT / "player/idle_up.png"
    shutil.copyfile(walk_up, idle_up)
    return "idle_up.png derived from walk_up_0.png (placeholder - see ASSET_REQUESTS.md)"


def main() -> None:
    print(f"normalizing into {OUT.relative_to(ROOT)}/")
    missing = []
    for rel_src, rel_dst in COPIES:
        src = SRC / rel_src
        if not src.exists():
            missing.append(rel_src)
            continue
        print("  " + normalize(src, OUT / rel_dst))
    print("  " + derive_idle_up())

    for folder in GDIGNORE_DIRS:
        marker = SRC / folder / ".gdignore"
        if not marker.exists():
            marker.write_text("")
            print(f"  .gdignore -> assets/{folder}/ (keeps the huge originals out of Godot)")

    if missing:
        print("\nmissing sources (skipped):")
        for m in missing:
            print(f"  {m}")


if __name__ == "__main__":
    main()
