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


def save(img: Image.Image, rel: str) -> None:
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


def splash():
    for frame in range(2):
        img, d = canvas(32, 32)
        spread = 6 + frame * 5
        d.ellipse([16 - spread, 14 - spread // 2, 16 + spread, 14 + spread // 2],
                  outline=P["foam"])
        for dx, dy in ((-7, -6), (7, -6), (0, -9), (-4, -8), (4, -8)):
            d.point((16 + dx, 16 + dy - frame * 2), P["foam"])
        save(img, f"shared/splash_{frame}.png")


def bank_tiles():
    """Riverbank edge. `bank_top` has water below it, `bank_bottom` above."""
    rng = random.Random(7)
    img, d = canvas(32, 32, P["sand"])
    d.rectangle([0, 0, 31, 9], fill=P["grass"])
    for x in range(32):
        d.point((x, 9 + rng.randrange(0, 3)), P["grass_dark"])
    speckle(d, rng, 32, 32, P["sand_dark"], 26)
    save(img, "shared/bank_top.png")

    img2 = img.transpose(Image.FLIP_TOP_BOTTOM)
    save(img2, "shared/bank_bottom.png")


# ----------------------------------------------------------------------- wind leaf

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

def meadow_tiles():
    for variant in range(2):
        img, d = canvas(32, 32, P["grass"])
        rng = random.Random(20 + variant)
        speckle(d, rng, 32, 32, P["grass_dark"], 40)
        speckle(d, rng, 32, 32, P["grass_lit"], 24)
        for _ in range(6):
            x, y = rng.randrange(1, 30), rng.randrange(1, 29)
            d.line([(x, y), (x, y + 2)], fill=P["grass_dark"])
        save(img, f"tall_grass/ground_{variant}.png")


def grass_tufts():
    """Three tufts of tall grass. These are cover, not decoration: on green
    ground, thin blades vanish, and a stealth game whose safe route is invisible
    is not a stealth game. So each tuft gets a solid dark base, dense blades and
    lit tips."""
    for variant in range(3):
        img, d = canvas(32, 32)
        rng = random.Random(40 + variant)
        # Dark mass at the root, so a clump has a visible footprint.
        d.ellipse([2, 20, 29, 31], fill=P["tall_dark"])
        for _ in range(54):
            x = rng.randrange(1, 31)
            base = 31 - rng.randrange(0, 5)
            top = base - rng.randrange(12, 25)
            lean = rng.choice((-2, -1, 0, 0, 1, 2))
            roll = rng.random()
            shade = P["tall_dark"] if roll < 0.5 else (
                P["tall"] if roll < 0.85 else P["hedge"])
            d.line([(x, base), (x + lean, top)], fill=shade)
            if roll > 0.8:
                d.point((x + lean, top - 1), P["grass_lit"])
        save(img, f"tall_grass/grass_{variant}.png")


def hedge():
    img, d = canvas(32, 32)
    rng = random.Random(60)
    d.rounded_rectangle([0, 8, 31, 31], radius=5, fill=P["hedge"])
    # Lumpy crown, so it reads as a solid bush rather than a flat block.
    for cx, cy, r in ((6, 10, 6), (15, 7, 8), (25, 10, 6)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=P["hedge"])
        d.ellipse([cx - r + 2, cy - r + 1, cx + r - 3, cy + r - 4],
                  fill=P["tall_dark"])
    speckle(d, rng, 32, 32, P["grass_dark"], 34)
    for _ in range(22):
        d.point((rng.randrange(1, 31), rng.randrange(9, 30)), P["tall_dark"])
    save(img, "tall_grass/hedge.png")


def rock():
    img, d = canvas(32, 32)
    d.polygon([(6, 28), (9, 14), (16, 8), (24, 13), (27, 28)], fill=P["rock"])
    d.polygon([(6, 28), (9, 14), (16, 8), (16, 28)], fill=P["rock_dark"])
    d.ellipse([4, 26, 28, 31], fill=P["shadow"])
    save(img, "tall_grass/rock.png")


def bird():
    """Top-down bird, wings up and wings down."""
    for frame, spread in enumerate((11, 5)):
        img, d = canvas(32, 32)
        d.ellipse([13, 9, 18, 24], fill=P["bird"])          # body, nose up
        d.polygon([(15, 12), (16, 8), (17, 12)], fill=P["beak"])
        d.polygon([(13, 13), (13 - spread, 16), (13, 21)], fill=P["bird_light"])
        d.polygon([(18, 13), (18 + spread, 16), (18, 21)], fill=P["bird_light"])
        d.polygon([(14, 23), (16, 29), (17, 23)], fill=P["bird"])   # tail
        save(img, f"tall_grass/bird_{frame}.png")


def petal():
    img, d = canvas(16, 16)
    d.ellipse([5, 1, 10, 8], fill=P["petal"])
    d.ellipse([1, 5, 8, 10], fill=P["sun"])
    d.ellipse([7, 5, 14, 10], fill=P["sun"])
    d.ellipse([5, 7, 10, 14], fill=P["petal"])
    d.ellipse([6, 6, 9, 9], fill=P["sun_dark"])
    save(img, "tall_grass/petal.png")


# ---------------------------------------------------------------------------- cave

def cave_tiles():
    img, d = canvas(32, 32, P["cave_floor"])
    rng = random.Random(80)
    speckle(d, rng, 32, 32, P["cave_dark"], 46)
    for _ in range(4):
        x, y = rng.randrange(2, 28), rng.randrange(2, 28)
        d.line([(x, y), (x + rng.randrange(2, 6), y)], fill=P["cave_dark"])
    save(img, "cave/floor.png")

    img, d = canvas(32, 32, P["cave_wall"])
    rng = random.Random(81)
    for y in range(0, 32, 8):
        d.line([(0, y), (31, y)], fill=P["cave_dark"])
        offset = 0 if (y // 8) % 2 == 0 else 8
        for x in range(offset, 32, 16):
            d.line([(x, y), (x, y + 7)], fill=P["cave_dark"])
    speckle(d, rng, 32, 32, P["cave_floor"], 18)
    save(img, "cave/wall.png")


def pressure_plates():
    def plate(top, glow: bool):
        img, d = canvas(32, 32)
        d.polygon([(16, 6), (29, 16), (16, 26), (3, 16)], fill=P["cave_dark"])
        inset = 3 if glow else 4
        d.polygon([(16, 6 + inset), (29 - inset, 16), (16, 26 - inset), (3 + inset, 16)],
                  fill=top)
        if glow:
            d.polygon([(16, 11), (24, 16), (16, 21), (8, 16)],
                      fill=tuple(min(255, c + 45) for c in top[:3]) + (255,))
        return img

    save(plate((92, 84, 104, 255), False), "cave/plate_off.png")
    for name, color in PLATE_COLORS.items():
        save(plate(color, True), f"cave/plate_on_{name}.png")


def torch():
    for frame, h in enumerate((7, 9)):
        img, d = canvas(16, 32)
        d.rectangle([6, 16, 9, 31], fill=P["wood_dark"])
        d.polygon([(8, 16 - h), (12, 17), (8, 20), (4, 17)], fill=P["sun_dark"])
        d.polygon([(8, 19 - h), (10, 17), (8, 19), (6, 17)], fill=P["sun"])
        save(img, f"cave/torch_{frame}.png")


# ------------------------------------------------------------------------- fishing

def bobber():
    for frame, dip in enumerate((0, 3)):
        img, d = canvas(16, 16)
        d.ellipse([4, 4 + dip, 11, 11 + dip], fill=(228, 76, 76, 255))
        d.pieslice([4, 4 + dip, 11, 11 + dip], 180, 360, fill=P["line"])
        d.point((7, 3 + dip), P["ink"])
        save(img, f"fishing/bobber_{frame}.png")


def rod():
    img, d = canvas(32, 32)
    d.line([(4, 28), (26, 5)], fill=P["wood"])
    d.line([(4, 28), (8, 24)], fill=P["wood_dark"])
    d.point((26, 5), P["line"])
    save(img, "fishing/rod.png")


def catch_marker():
    img, d = canvas(16, 16)
    d.rectangle([6, 2, 9, 10], fill=(255, 240, 120, 255))
    d.rectangle([6, 12, 9, 15], fill=(255, 240, 120, 255))
    save(img, "fishing/alert.png")


# ------------------------------------------------------------------- village / hub

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


def signpost():
    img, d = canvas(32, 32)
    d.rectangle([14, 14, 17, 30], fill=P["wood_dark"])
    d.rectangle([3, 6, 28, 16], fill=P["wood"])
    d.rectangle([3, 6, 28, 16], outline=P["wood_dark"])
    for y in (9, 12):
        d.line([(7, y), (24, y)], fill=P["wood_dark"])
    d.ellipse([2, 28, 29, 31], fill=P["shadow"])
    save(img, "village/signpost.png")


def tree():
    img, d = canvas(32, 48)
    d.rectangle([14, 32, 18, 45], fill=P["wood_dark"])
    d.ellipse([2, 4, 30, 36], fill=P["grass_dark"])
    d.ellipse([5, 6, 26, 30], fill=P["hedge"])
    d.ellipse([8, 8, 20, 20], fill=P["grass"])
    d.ellipse([2, 43, 30, 47], fill=P["shadow"])
    save(img, "village/tree.png")


def sun_mascot():
    """Three frames: awake, drowsy, asleep. The hub's progress meter."""
    eyes = [
        [((17, 22), (19, 25)), ((28, 22), (30, 25))],   # open
        [((17, 23), (19, 24)), ((28, 23), (30, 24))],   # half
        [((16, 24), (20, 24)), ((27, 24), (31, 24))],   # closed
    ]
    for frame in range(3):
        img, d = canvas(48, 48)
        for i in range(12):                              # rays
            import math
            a = math.tau * i / 12 + frame * 0.08
            x0, y0 = 24 + math.cos(a) * 16, 24 + math.sin(a) * 16
            x1, y1 = 24 + math.cos(a) * 22, 24 + math.sin(a) * 22
            d.line([(x0, y0), (x1, y1)], fill=P["sun_dark"])
        d.ellipse([7, 7, 40, 40], fill=P["sun_dark"])
        d.ellipse([9, 9, 38, 38], fill=P["sun"])
        for (a, b) in eyes[frame]:
            d.rectangle([a[0], a[1], b[0], b[1]], fill=P["ink"])
        if frame == 2:
            d.arc([20, 28, 28, 34], 200, 340, fill=P["sun_dark"])   # small snore mouth
        else:
            d.arc([19, 27, 29, 34], 0, 180, fill=P["ink"])
        save(img, f"village/sun_{frame}.png")


# ------------------------------------------------------------------------------ UI

def glow():
    """Soft radial falloff, tinted at use site. Additive-blended in the hub."""
    img, _ = canvas(64, 64)
    px = img.load()
    for y in range(64):
        for x in range(64):
            d = (((x - 31.5) ** 2 + (y - 31.5) ** 2) ** 0.5) / 31.5
            a = max(0.0, 1.0 - d) ** 2.2
            px[x, y] = (255, 226, 160, int(a * 255))
    save(img, "village/glow.png")


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


def main() -> None:
    water_tiles(); ripple(); splash(); bank_tiles(); leaf_shadow()
    chime()
    meadow_tiles(); grass_tufts(); hedge(); rock(); bird(); petal()
    cave_tiles(); pressure_plates(); torch()
    bobber(); rod(); catch_marker()
    village_tiles(); signpost(); tree(); sun_mascot(); glow()
    ui_bits()
    made = sorted(p.relative_to(OUT).as_posix() for p in OUT.rglob("*.png"))
    print(f"assets/game now holds {len(made)} sprites")


if __name__ == "__main__":
    main()
