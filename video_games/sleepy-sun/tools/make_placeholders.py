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

def harpoon_bolt():
    """Drawn pointing up, which is the only way it ever flies."""
    img, d = canvas(12, 32)
    d.line([(6, 31), (6, 8)], fill=(196, 186, 200, 255))
    d.line([(5, 31), (5, 10)], fill=(140, 132, 150, 255))
    d.polygon([(6, 0), (10, 9), (6, 7), (2, 9)], fill=(232, 228, 240, 255))
    d.line([(3, 26), (6, 22)], fill=(150, 120, 80, 255))
    d.line([(9, 26), (6, 22)], fill=(150, 120, 80, 255))
    save(img, "harpoon/bolt.png")


def harpoon_launcher():
    img, d = canvas(16, 16)
    d.rectangle([6, 4, 9, 15], fill=P["wood_dark"])
    d.rectangle([3, 6, 12, 9], fill=(150, 142, 160, 255))
    d.rectangle([5, 0, 10, 6], fill=(196, 186, 200, 255))
    save(img, "harpoon/launcher.png")


def aim_guide():
    """A dotted line up the firing lane, so where the shot goes is never a
    guess -- the skill is meant to be leading a moving fish, not aiming."""
    img, d = canvas(3, 32)
    for y in range(0, 32, 6):
        d.line([(1, y), (1, y + 2)], fill=(255, 255, 255, 110))
    save(img, "harpoon/aim.png")


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


# ------------------------------------------------------------------ card draw

def card_art():
    """Frame and icon for the draw table. Tinted per game in code, so these are
    drawn neutral -- shape carries the identity, colour carries the game."""
    img, d = canvas(100, 136)
    d.rounded_rectangle([0, 0, 99, 135], radius=6, fill=(255, 255, 255, 255))
    d.rounded_rectangle([2, 2, 97, 133], radius=5, fill=(28, 26, 40, 235))
    d.rounded_rectangle([6, 6, 93, 129], radius=4, outline=(255, 255, 255, 90))
    save(img, "ui/card_frame.png")

    # One glyph per game, drawn white so the card tints it. A shared generic
    # icon made every card look the same from across a room, which defeats the
    # point of a draw you are supposed to read at a glance.
    W = (255, 255, 255, 255)

    img, d = canvas(32, 32)                                    # wind_leaf: a leaf
    d.ellipse([2, 10, 29, 21], fill=W)
    d.line([(2, 16), (29, 16)], fill=(28, 26, 40, 255))
    save(img, "ui/card_icon_wind_leaf.png")

    img, d = canvas(32, 32)                                    # tall_grass: blades
    for x, top in ((9, 6), (16, 3), (23, 8)):
        d.line([(x, 28), (x - 2, top)], fill=W, width=3)
    save(img, "ui/card_icon_tall_grass.png")

    img, d = canvas(32, 32)                                    # cave: ring of stones
    import math as _m
    for i in range(5):
        a = _m.tau * i / 5 - _m.pi / 2
        cx, cy = 16 + _m.cos(a) * 10, 16 + _m.sin(a) * 10
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=W)
    save(img, "ui/card_icon_cave.png")

    img, d = canvas(32, 32)                                    # harpoon: bolt
    d.polygon([(16, 2), (23, 13), (16, 10), (9, 13)], fill=W)
    d.rectangle([14, 10, 17, 29], fill=W)
    save(img, "ui/card_icon_harpoon.png")

    img, d = canvas(32, 32)                                    # acorn_storm: acorn
    d.ellipse([8, 11, 23, 29], fill=W)
    d.rectangle([6, 5, 25, 13], fill=W)
    d.rectangle([14, 1, 17, 6], fill=W)
    save(img, "ui/card_icon_acorn_storm.png")

    img, d = canvas(32, 32)                                    # firefly: glowing mote
    d.ellipse([11, 11, 20, 20], fill=W)
    for dx, dy in ((0, -11), (0, 11), (-11, 0), (11, 0),
                   (-8, -8), (8, -8), (-8, 8), (8, 8)):
        d.ellipse([16 + dx - 2, 16 + dy - 2, 16 + dx + 2, 16 + dy + 2], fill=W)
    save(img, "ui/card_icon_firefly.png")

    img, d = canvas(32, 32)                                    # temple_bell: bell
    d.rectangle([14, 2, 17, 6], fill=W)
    d.pieslice([5, 5, 26, 26], 180, 360, fill=W)
    d.rectangle([5, 15, 26, 24], fill=W)
    d.rectangle([3, 23, 28, 27], fill=W)
    save(img, "ui/card_icon_temple_bell.png")

    img, d = canvas(32, 32)                                    # crow_watch: bird
    d.polygon([(16, 8), (29, 19), (16, 15), (3, 19)], fill=W)
    d.polygon([(14, 14), (18, 14), (16, 26)], fill=W)
    save(img, "ui/card_icon_crow_watch.png")


# --------------------------------------------------------------- acorn storm

def acorn():
    img, d = canvas(16, 16)
    d.ellipse([3, 5, 12, 15], fill=(176, 122, 62, 255))
    d.rectangle([2, 2, 13, 7], fill=(96, 66, 40, 255))
    d.rectangle([7, 0, 8, 3], fill=(72, 50, 30, 255))
    d.line([(5, 9), (5, 13)], fill=(206, 156, 92, 255))
    save(img, "acorn_storm/acorn.png")


def sunfruit():
    img, d = canvas(16, 16)
    d.ellipse([2, 3, 13, 14], fill=P["sun_dark"])
    d.ellipse([3, 4, 11, 12], fill=P["sun"])
    d.ellipse([5, 6, 8, 9], fill=(255, 245, 210, 255))
    d.line([(8, 3), (10, 0)], fill=P["hedge"])
    save(img, "acorn_storm/sunfruit.png")


def impact_marker():
    """The growing ring that says an acorn is about to land here. Same warning
    language as the shaking leaf: telegraph, then consequence."""
    img, d = canvas(32, 32)
    d.ellipse([2, 8, 29, 23], outline=(255, 120, 90, 255))
    d.ellipse([6, 11, 25, 20], outline=(255, 180, 140, 160))
    save(img, "acorn_storm/impact.png")


# ------------------------------------------------------------------- firefly

def firefly_mote():
    img, d = canvas(16, 16)
    d.ellipse([4, 4, 11, 11], fill=(255, 246, 170, 255))
    d.ellipse([6, 6, 9, 9], fill=(255, 255, 240, 255))
    save(img, "firefly/mote.png")


def lantern():
    img, d = canvas(16, 24)
    d.rectangle([5, 0, 10, 3], fill=P["wood_dark"])
    d.rectangle([3, 4, 12, 19], fill=(196, 150, 70, 255))
    d.rectangle([5, 6, 10, 17], fill=(255, 232, 150, 255))
    d.rectangle([3, 19, 12, 22], fill=P["wood_dark"])
    save(img, "firefly/lantern.png")


# ---------------------------------------------------------------- temple bell

def bell():
    img, d = canvas(48, 48)
    d.rectangle([22, 2, 25, 8], fill=P["wood_dark"])
    d.pieslice([6, 6, 41, 42], 180, 360, fill=(184, 146, 74, 255))
    d.rectangle([6, 24, 41, 38], fill=(184, 146, 74, 255))
    d.rectangle([4, 36, 43, 41], fill=(150, 116, 56, 255))
    d.pieslice([12, 12, 35, 34], 180, 360, fill=(214, 178, 98, 255))
    save(img, "temple_bell/bell.png")


def beat_ring():
    img, d = canvas(48, 48)
    d.ellipse([1, 1, 46, 46], outline=(255, 240, 190, 255))
    d.ellipse([3, 3, 44, 44], outline=(255, 240, 190, 120))
    save(img, "temple_bell/ring.png")


def beat_marker():
    img, d = canvas(16, 16)
    d.ellipse([1, 1, 14, 14], fill=(255, 255, 255, 255))
    d.ellipse([4, 4, 11, 11], fill=(240, 120, 110, 255))
    save(img, "temple_bell/marker.png")


# ----------------------------------------------------------------- crow watch

def rice_tile():
    """Three states of one crop tile: full, half eaten, bare."""
    stalks = ((10, 3), (6, 2), (0, 0))
    for state, (count, height_bonus) in enumerate(stalks):
        img, d = canvas(32, 32)
        rng = random.Random(200 + state)
        d.ellipse([1, 20, 30, 31], fill=(120, 96, 58, 255))
        for _ in range(count):
            x = rng.randrange(4, 28)
            base = 27 - rng.randrange(0, 3)
            top = base - rng.randrange(10, 14 + height_bonus * 3)
            d.line([(x, base), (x + rng.choice((-1, 0, 1)), top)],
                   fill=(206, 186, 88, 255) if rng.random() < 0.6 else (168, 150, 66, 255))
            d.point((x, top - 1), (240, 226, 140, 255))
        save(img, f"crow_watch/rice_{state}.png")


# ------------------------------------------------------------------ HUD icons

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


# ------------------------------------------------------------------------ lore

def lore_art():
    """The handful of sprites the cutscenes need that no minigame already has.

    Everything else in the seventeen cutscenes is composed from sprites that
    were already on disk, which is the whole reason the lore could ship without
    waiting on art.
    """
    import math as _m

    # The RADIANT face. sun_0..2 cover awake / drowsy / asleep; none of them is
    # *delighted*, and the top-tier finale is the one moment that needs it.
    img, d = canvas(48, 48)
    for i in range(16):
        a = _m.tau * i / 16
        d.line([(24 + _m.cos(a) * 16, 24 + _m.sin(a) * 16),
                (24 + _m.cos(a) * 23, 24 + _m.sin(a) * 23)],
               fill=P["sun_dark"], width=2)
    d.ellipse([6, 6, 41, 41], fill=P["sun_dark"])
    d.ellipse([8, 8, 39, 39], fill=P["sun"])
    d.ellipse([9, 9, 38, 38], fill=(255, 232, 158, 255))
    for cx in (17, 30):                                     # happy closed eyes
        d.arc([cx - 4, 18, cx + 4, 26], 200, 340, fill=P["ink"], width=2)
    d.chord([16, 26, 32, 38], 0, 180, fill=P["ink"])        # open grin
    d.chord([20, 33, 28, 38], 0, 180, fill=(226, 118, 118, 255))
    for cx in (12, 35):                                     # blush
        d.ellipse([cx - 3, 27, cx + 3, 31], fill=(255, 168, 132, 120))
    save(img, "village/sun_beaming.png")

    # One ray, drawn pointing up from its base. The finale rotates copies of it
    # around the sun rather than baking a burst into a texture, so the same
    # sprite works for three rays or twelve.
    img, d = canvas(8, 40)
    for y in range(40):
        t = y / 39.0
        half = max(0.5, 3.5 * t)
        a = int(230 * (1.0 - t) ** 0.7)
        d.line([(4 - half, y), (4 + half, y)], fill=(255, 236, 176, a))
    save(img, "decor/ray.png")

    # Horizon silhouette. Wide enough that two side by side cover the screen,
    # with a soft crest so it reads as land rather than a bar.
    img, d = canvas(256, 64)
    for x in range(256):
        h = 22 + 10 * _m.sin(x / 41.0) + 5 * _m.sin(x / 13.0 + 1.7)
        d.line([(x, 64 - h), (x, 63)], fill=(26, 28, 46, 255))
        d.point((x, int(64 - h)), (44, 48, 72, 255))
    save(img, "decor/hill.png")

    # A note, for the chimes and the bell. The only way to draw sound.
    img, d = canvas(8, 8)
    d.ellipse([0, 4, 4, 7], fill=(255, 255, 255, 255))
    d.line([(4, 6), (4, 0)], fill=(255, 255, 255, 255))
    d.line([(4, 0), (7, 1)], fill=(255, 255, 255, 255))
    save(img, "decor/note.png")


def main() -> None:
    water_tiles(); ripple(); splash(); bank_tiles(); leaf_shadow()
    chime()
    meadow_tiles(); grass_tufts(); hedge(); rock(); bird(); petal()
    cave_tiles(); pressure_plates(); torch()
    harpoon_bolt(); harpoon_launcher(); aim_guide()
    village_tiles(); signpost(); tree(); sun_mascot(); glow()
    ui_bits(); card_art(); hud_icons(); alarm_frame(); vignette(); scrim()
    decor_motes(); decor_props()
    acorn(); sunfruit(); impact_marker()
    firefly_mote(); lantern()
    bell(); beat_ring(); beat_marker()
    rice_tile()
    lore_art()
    made = sorted(p.relative_to(OUT).as_posix() for p in OUT.rglob("*.png"))
    print(f"assets/game now holds {len(made)} sprites")


if __name__ == "__main__":
    main()
