#!/usr/bin/env python3
"""Generate stand-in pixel art for everything not yet hand-drawn.

Nothing in the game references a missing file, so the whole adventure is
playable today. Every placeholder is a straight file swap: drop a real PNG at
the same path with the same dimensions and no code changes are needed.
See docs/ASSET_REQUESTS.md for the list of what to draw.

    pip install pillow
    python3 tools/make_placeholders.py

Outputs are committed; re-run only after editing this file.
"""

from __future__ import annotations

import random
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except ImportError:  # pragma: no cover - dependency hint only
    sys.exit("This script needs Pillow:  pip install pillow")

OUT = Path(__file__).resolve().parent.parent / "assets" / "game"

# Dusk palette shared by every placeholder so the four minigames read as one game.
P = {
    "water_deep":  (34, 76, 112, 255),
    "water_mid":   (46, 100, 141, 255),
    "water_light": (72, 133, 173, 255),
    "foam":        (176, 214, 232, 255),
    "sand":        (196, 168, 116, 255),
    "sand_dark":   (160, 133, 88, 255),
    "grass":       (74, 122, 60, 255),
    "grass_dark":  (56, 94, 46, 255),
    "grass_lit":   (99, 152, 72, 255),
    "tall":        (86, 140, 62, 255),
    "tall_dark":   (58, 100, 44, 255),
    "hedge":       (43, 78, 42, 255),
    "rock":        (118, 118, 128, 255),
    "rock_dark":   (86, 86, 98, 255),
    "cave_floor":  (74, 66, 84, 255),
    "cave_dark":   (52, 46, 62, 255),
    "cave_wall":   (38, 34, 46, 255),
    "bird":        (54, 58, 76, 255),
    "bird_light":  (92, 98, 122, 255),
    "beak":        (226, 160, 70, 255),
    "sun":         (255, 209, 102, 255),
    "sun_dark":    (240, 160, 76, 255),
    "petal":       (255, 226, 150, 255),
    "chime":       (214, 226, 236, 255),
    "wood":        (140, 100, 62, 255),
    "wood_dark":   (104, 72, 44, 255),
    "line":        (238, 238, 238, 255),
    "shadow":      (0, 0, 0, 70),
    "ink":         (28, 26, 38, 255),
    "panel":       (44, 40, 60, 235),
    "panel_edge":  (128, 118, 158, 255),
}
PLATE_COLORS = {
    "red":    (217, 83, 79, 255),
    "blue":   (79, 143, 217, 255),
    "green":  (92, 184, 92, 255),
    "yellow": (240, 196, 25, 255),
    "purple": (155, 89, 182, 255),
}
CLEAR = (0, 0, 0, 0)


def canvas(w: int, h: int, fill=CLEAR) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (w, h), fill)
    return img, ImageDraw.Draw(img)


# The project is stripped to one minigame, so most of what the drawing
# functions below can produce is not wanted on disk. Rather than gut each
# function -- they are the record of how every sprite was made, and the other
# games are coming back one at a time -- `save()` writes only what is in use.
# Adding a game means adding its sprites here.
KEEP = {
    "player/idle_down.png", "player/idle_left.png", "player/idle_right.png",
    "player/idle_up.png",
    "shared/water_0.png", "shared/water_1.png", "shared/water_2.png",
    "shared/ripple.png",
    "wind_leaf/leaf.png", "wind_leaf/chime.png",
    "village/ground_0.png", "village/tree.png",
    "decor/reed.png", "decor/lilypad.png", "decor/dragonfly.png",
    "decor/sparkle.png", "decor/dust.png",
    "ui/icon_flag.png", "ui/icon_clock.png", "ui/pip.png", "ui/panel.png",
    "ui/vignette.png", "ui/alarm_frame.png", "ui/shadow_small.png",
    "ui/scrim.png",
}


def save(img: Image.Image, rel: str) -> None:
    if rel not in KEEP:
        return
    path = OUT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def speckle(draw, rng, w, h, color, count):
    for _ in range(count):
        draw.point((rng.randrange(w), rng.randrange(h)), color)


# --------------------------------------------------------------------------- water

def water_tiles():
    """Three tileable 32x32 frames; cycling them makes the river shimmer."""
    for frame in range(3):
        img, d = canvas(32, 32, P["water_mid"])
        rng = random.Random(1000 + frame)
        for y in range(32):
            band = (y + frame * 3) % 12
            if band < 2:
                d.line([(0, y), (31, y)], fill=P["water_deep"])
            elif band == 6:
                d.line([(0, y), (31, y)], fill=P["water_light"])
        # short highlight dashes that drift with the frame
        for _ in range(9):
            x = rng.randrange(0, 28)
            y = rng.randrange(0, 32)
            d.line([(x, y), (x + rng.randrange(1, 4), y)], fill=P["water_light"])
        save(img, f"shared/water_{frame}.png")


def ripple():
    img, d = canvas(32, 32)
    d.ellipse([4, 10, 27, 21], outline=P["foam"])
    d.ellipse([9, 13, 22, 18], outline=P["water_light"])
    save(img, "shared/ripple.png")


def chime():
    img, d = canvas(16, 16)
    d.line([(3, 2), (12, 2)], fill=P["wood"])
    for i, x in enumerate((4, 7, 10)):
        d.line([(x, 3), (x, 8 + i)], fill=P["chime"])
        d.point((x, 9 + i), P["foam"])
    save(img, "wind_leaf/chime.png")


def leaf_shadow():
    img, d = canvas(32, 16)
    d.ellipse([1, 3, 30, 12], fill=P["shadow"])
    save(img, "shared/shadow.png")


# ---------------------------------------------------------------------- tall grass

def village_tiles():
    for variant in range(2):
        img, d = canvas(32, 32, P["grass"])
        rng = random.Random(120 + variant)
        speckle(d, rng, 32, 32, P["grass_dark"], 34)
        speckle(d, rng, 32, 32, P["grass_lit"], 20)
        save(img, f"village/ground_{variant}.png")

    img, d = canvas(32, 32, (184, 155, 114, 255))
    rng = random.Random(130)
    speckle(d, rng, 32, 32, (160, 132, 94, 255), 44)
    speckle(d, rng, 32, 32, (206, 180, 140, 255), 22)
    save(img, "village/path.png")


def tree():
    img, d = canvas(32, 48)
    d.rectangle([14, 32, 18, 45], fill=P["wood_dark"])
    d.ellipse([2, 4, 30, 36], fill=P["grass_dark"])
    d.ellipse([5, 6, 26, 30], fill=P["hedge"])
    d.ellipse([8, 8, 20, 20], fill=P["grass"])
    d.ellipse([2, 43, 30, 47], fill=P["shadow"])
    save(img, "village/tree.png")


def ui_bits():
    img, d = canvas(24, 24, CLEAR)
    d.rounded_rectangle([0, 0, 23, 23], radius=5, fill=P["panel"], outline=P["panel_edge"])
    save(img, "ui/panel.png")

    for name, fill in (("star_on", P["sun"]), ("star_off", (70, 66, 88, 255))):
        img, d = canvas(16, 16)
        d.polygon([(8, 1), (10, 6), (15, 6), (11, 9), (13, 14),
                   (8, 11), (3, 14), (5, 9), (1, 6), (6, 6)], fill=fill)
        save(img, f"ui/{name}.png")

    img, d = canvas(16, 16)
    d.rounded_rectangle([1, 3, 14, 13], radius=3, fill=(238, 238, 238, 255),
                        outline=P["ink"])
    d.line([(4, 8), (11, 8)], fill=P["ink"])
    save(img, "ui/key_prompt.png")

    img, d = canvas(16, 8)
    d.ellipse([0, 0, 15, 7], fill=P["shadow"])
    save(img, "ui/shadow_small.png")


# ------------------------------------------------------------------ card draw

def hud_icons():
    """A meter needs to say what it is measuring. An icon does that without a
    word, which is the whole point of this round."""
    W = (255, 255, 255, 255)

    img, d = canvas(9, 9)                                   # sun (dusk)
    d.ellipse([2, 2, 6, 6], fill=W)
    for dx, dy in ((0, -4), (0, 4), (-4, 0), (4, 0)):
        d.point((4 + dx, 4 + dy), W)
    save(img, "ui/icon_sun.png")

    img, d = canvas(9, 9)                                   # clock (timed round)
    d.ellipse([0, 0, 8, 8], outline=W)
    d.line([(4, 4), (4, 2)], fill=W)
    d.line([(4, 4), (6, 5)], fill=W)
    save(img, "ui/icon_clock.png")

    img, d = canvas(9, 9)                                   # wheat (crop)
    d.line([(4, 8), (4, 1)], fill=W)
    for y in (2, 4, 6):
        d.line([(4, y), (2, y - 1)], fill=W)
        d.line([(4, y), (6, y - 1)], fill=W)
    save(img, "ui/icon_wheat.png")

    img, d = canvas(9, 9)                                   # lantern
    d.rectangle([3, 0, 5, 1], fill=W)
    d.rectangle([2, 2, 6, 7], fill=W)
    d.rectangle([3, 3, 5, 6], fill=(28, 26, 40, 255))
    save(img, "ui/icon_lantern.png")

    img, d = canvas(9, 9)                                   # flag (far bank)
    d.line([(2, 8), (2, 0)], fill=W)
    d.polygon([(3, 1), (8, 3), (3, 5)], fill=W)
    save(img, "ui/icon_flag.png")

    img, d = canvas(9, 9)                                   # doorway (chambers)
    d.rectangle([1, 1, 7, 8], fill=W)
    d.rectangle([3, 4, 5, 8], fill=(28, 26, 40, 255))
    save(img, "ui/icon_door.png")

    img, d = canvas(7, 7)                                   # sequence pip
    d.ellipse([0, 0, 6, 6], fill=W)
    save(img, "ui/pip.png")


def alarm_frame():
    """Red pulse in from the screen edges. Drawn as a frame that is opaque at the
    border and clear in the middle, so it never covers what you are looking at."""
    img, _ = canvas(480, 270)
    px = img.load()
    for y in range(270):
        for x in range(480):
            edge = min(x / 104.0, (479 - x) / 104.0, y / 62.0, (269 - y) / 62.0)
            a = max(0.0, 1.0 - edge) ** 1.7
            px[x, y] = (255, 60, 48, int(a * 235))
    save(img, "ui/alarm_frame.png")


def scrim():
    """A soft dark band along the bottom. Titles and prompts have to sit over
    whatever the scene happens to be doing; a scrim buys legibility without
    putting a hard box around the text."""
    img, _ = canvas(480, 120)
    px = img.load()
    for y in range(120):
        # Nearly linear: a steep curve leaves the text sitting in the faint part
        # of the gradient, which is exactly where it needs the help.
        a = (y / 119.0) ** 0.9
        for x in range(480):
            px[x, y] = (10, 7, 20, int(a * 215))
    save(img, "ui/scrim.png")


def vignette():
    """A soft dark frame on every screen. Costs nothing and stops the pixel art
    from ending in a hard rectangle against the bezel."""
    img, _ = canvas(480, 270)
    px = img.load()
    for y in range(270):
        for x in range(480):
            edge = min(x / 160.0, (479 - x) / 160.0, y / 96.0, (269 - y) / 96.0)
            a = max(0.0, 1.0 - edge) ** 2.4
            px[x, y] = (8, 6, 16, int(a * 150))
    save(img, "ui/vignette.png")


# --------------------------------------------------------------------- decor
#
# Small pieces that do not affect play. They exist so each scene reads as a
# place rather than a play area with the mechanics sitting on it.

def decor_motes():
    img, d = canvas(4, 4)                                   # dust
    d.ellipse([0, 0, 3, 3], fill=(255, 250, 235, 255))
    save(img, "decor/dust.png")

    img, d = canvas(8, 8)                                   # sparkle
    d.line([(4, 0), (4, 7)], fill=(255, 255, 255, 255))
    d.line([(0, 4), (7, 4)], fill=(255, 255, 255, 255))
    d.point((4, 4), (255, 255, 255, 255))
    save(img, "decor/sparkle.png")

    img, d = canvas(3, 3)                                   # star
    d.point((1, 1), (255, 255, 255, 255))
    d.point((0, 1), (255, 255, 255, 160))
    d.point((2, 1), (255, 255, 255, 160))
    d.point((1, 0), (255, 255, 255, 160))
    d.point((1, 2), (255, 255, 255, 160))
    save(img, "decor/star.png")

    img, d = canvas(8, 8)                                   # falling petal
    d.ellipse([1, 2, 6, 5], fill=(255, 190, 205, 255))
    d.ellipse([2, 3, 5, 4], fill=(255, 225, 235, 255))
    save(img, "decor/petal.png")

    img, d = canvas(8, 8)                                   # falling leaf
    d.polygon([(4, 0), (7, 4), (4, 7), (1, 4)], fill=(196, 132, 58, 255))
    d.line([(4, 1), (4, 6)], fill=(140, 90, 40, 255))
    save(img, "decor/leaf.png")


def decor_props():
    rng = random.Random(300)

    img, d = canvas(16, 40)                                 # reed
    for x, lean in ((5, -2), (8, 1), (11, -1)):
        d.line([(x, 39), (x + lean, 6)], fill=P["hedge"], width=2)
        d.ellipse([x + lean - 2, 2, x + lean + 2, 9], fill=(120, 96, 54, 255))
    save(img, "decor/reed.png")

    img, d = canvas(24, 16)                                 # lily pad
    d.ellipse([0, 1, 23, 14], fill=P["grass_dark"])
    d.ellipse([2, 2, 21, 12], fill=P["grass"])
    d.polygon([(12, 8), (23, 6), (23, 10)], fill=(20, 40, 60, 0))
    save(img, "decor/lilypad.png")

    img, d = canvas(16, 10)                                 # dragonfly
    d.line([(3, 5), (12, 5)], fill=(90, 150, 170, 255))
    d.ellipse([1, 3, 5, 7], fill=(120, 200, 220, 255))
    for wx in (6, 9):
        d.ellipse([wx, 0, wx + 5, 4], fill=(200, 235, 245, 150))
        d.ellipse([wx, 5, wx + 5, 9], fill=(200, 235, 245, 150))
    save(img, "decor/dragonfly.png")

    img, d = canvas(12, 16)                                 # cave crystal
    d.polygon([(6, 0), (11, 8), (6, 15), (1, 8)], fill=(140, 190, 230, 220))
    d.polygon([(6, 2), (9, 8), (6, 12)], fill=(210, 240, 255, 230))
    save(img, "decor/crystal.png")

    img, d = canvas(16, 8)                                  # floor rubble
    for _ in range(7):
        x, y = rng.randrange(1, 14), rng.randrange(2, 7)
        d.ellipse([x, y, x + rng.randrange(1, 3), y + 1], fill=P["cave_dark"])
    save(img, "decor/rubble.png")

    img, d = canvas(16, 16)                                 # squirrel silhouette
    d.ellipse([4, 6, 12, 14], fill=(38, 30, 26, 255))
    d.ellipse([8, 2, 13, 8], fill=(38, 30, 26, 255))
    d.polygon([(4, 12), (0, 4), (3, 3), (6, 10)], fill=(38, 30, 26, 255))
    save(img, "decor/squirrel.png")

    img, d = canvas(24, 24)                                 # moon
    d.ellipse([0, 0, 23, 23], fill=(238, 240, 220, 255))
    d.ellipse([6, 5, 11, 10], fill=(216, 220, 200, 255))
    d.ellipse([13, 13, 18, 18], fill=(216, 220, 200, 255))
    save(img, "decor/moon.png")

    img, d = canvas(64, 16)                                 # mist band
    px = img.load()
    for y in range(16):
        for x in range(64):
            a = (1.0 - abs(y - 8) / 8.0) ** 1.5
            px[x, y] = (210, 225, 235, int(a * 70))
    save(img, "decor/mist.png")

    img, d = canvas(12, 20)                                 # hanging lantern
    d.line([(6, 0), (6, 4)], fill=P["wood_dark"])
    d.rectangle([2, 4, 9, 15], fill=(214, 96, 74, 255))
    d.rectangle([4, 6, 7, 13], fill=(255, 226, 150, 255))
    d.rectangle([2, 15, 9, 17], fill=P["wood_dark"])
    save(img, "decor/lantern_hang.png")

    img, d = canvas(16, 28)                                 # scarecrow
    d.line([(8, 27), (8, 6)], fill=P["wood_dark"], width=2)
    d.line([(1, 12), (14, 12)], fill=P["wood_dark"], width=2)
    d.ellipse([4, 2, 11, 9], fill=(206, 176, 96, 255))
    d.polygon([(2, 4), (13, 4), (8, 0)], fill=(150, 110, 60, 255))
    d.rectangle([5, 12, 10, 20], fill=(180, 78, 70, 255))
    save(img, "decor/scarecrow.png")

    img, d = canvas(32, 16)                                 # fence
    d.line([(0, 6), (31, 6)], fill=P["wood"], width=2)
    d.line([(0, 11), (31, 11)], fill=P["wood"], width=2)
    for x in (4, 16, 28):
        d.line([(x, 1), (x, 15)], fill=P["wood_dark"], width=2)
    save(img, "decor/fence.png")

    img, d = canvas(48, 24)                                 # cloud shadow
    px = img.load()
    import math as _m
    for y in range(24):
        for x in range(48):
            dx, dy = (x - 24) / 24.0, (y - 12) / 12.0
            a = max(0.0, 1.0 - _m.sqrt(dx * dx + dy * dy)) ** 1.6
            px[x, y] = (10, 14, 30, int(a * 70))
    save(img, "decor/cloud.png")


def main() -> None:
    water_tiles(); ripple(); leaf_shadow()
    chime()
    village_tiles(); tree()
    ui_bits(); hud_icons(); alarm_frame(); vignette(); scrim()
    decor_motes(); decor_props()
    made = sorted(p.relative_to(OUT).as_posix() for p in OUT.rglob("*.png"))
    print(f"assets/game now holds {len(made)} sprites")


if __name__ == "__main__":
    main()
