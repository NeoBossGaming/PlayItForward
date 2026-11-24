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
    "ui/stick.png", "ui/button.png", "ui/arrow.png",
    # --- Acorn Storm ---
    "acorn_storm/acorn.png", "acorn_storm/sunfruit.png",
    "acorn_storm/mark_danger.png", "acorn_storm/mark_good.png",
    "acorn_storm/clearing.png", "acorn_storm/canopy_shade.png",
    "acorn_storm/rock.png", "acorn_storm/squirrel.png",
    "acorn_storm/canopy.png", "acorn_storm/burst.png",
    "acorn_storm/prize.png", "wind_leaf/chime_gold.png", "decor/spark.png",
    "ui/icon_leaf.png",
    # Jump poses, derived from the idle frames -- see player_jump_frames().
    *(f"player/jump_{d}_{i}.png"
      for d in ("down", "up", "left", "right") for i in (0, 1, 2)),
    "shared/water.png", "shared/water_depth.png", "shared/bank_edge.png",
    *(f"shared/water_glints_{i}.png" for i in range(4)),
    "shared/ripple.png",
    # (water_0..2 were the striped tiles; shared/water.png replaced all three)
    "wind_leaf/leaf_0.png", "wind_leaf/leaf_1.png", "wind_leaf/leaf_2.png",
    "wind_leaf/leaf_3.png",
    "wind_leaf/leaf_sink_0.png", "wind_leaf/leaf_sink_1.png",
    "wind_leaf/leaf_sink_2.png",
    "wind_leaf/chime.png",
    "wind_leaf/hornet.png", "wind_leaf/heron.png", "wind_leaf/dive_shadow.png",
    "village/ground_0.png", "village/tree.png", "village/treeline.png",
    "decor/reed.png", "decor/dragonfly.png", "decor/glint.png",
    "decor/foam.png", "decor/twig.png", "decor/driftleaf.png",
    "decor/streak.png",
    "decor/dust.png",
    # --- Hush Meadow ---
    "hush_meadow/meadow.png", "hush_meadow/meadow_shade.png",
    "hush_meadow/grass_0.png", "hush_meadow/grass_1.png",
    "hush_meadow/grass_2.png", "hush_meadow/grass_cover.png",
    "hush_meadow/bird_0.png", "hush_meadow/bird_1.png",
    "hush_meadow/dew.png", "hush_meadow/dew_gold.png",
    "hush_meadow/petal.png", "hush_meadow/hedge.png", "hush_meadow/rock.png",
    "hush_meadow/mote.png",
    "ui/icon_eye.png",
    "ui/icon_flag.png", "ui/icon_clock.png", "ui/pip.png",
    "ui/heart_full.png", "ui/heart_half.png", "ui/heart_empty.png",
    "ui/vignette.png", "ui/alarm_frame.png", "ui/shadow_small.png",
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


# --------------------------------------------------------------------------- grain
#
# What makes a sprite read as pixel art rather than as a photograph is GRAIN:
# how often the colour changes from one pixel to the next along a row. Not the
# palette -- every sprite here was already four to six colours, and the two
# grounds that looked "too realistic" were among the smallest palettes in the
# project. What they had was thousands of single-pixel random strokes, and fine
# random grain is exactly what a camera produces.
#
#     sprite                          mean run of identical pixels
#     shared/water.png (Riverleap)    20.0 px   <- the one that looks right
#     acorn_storm/clearing.png         2.0 px   <- before this section existed
#     hush_meadow/grass_cover.png      1.7 px, 208 alpha levels
#
# So the large layers are now built by these rules, and each game's suite
# asserts the result with the same measurement (mean_run below):
#
#   * Shapes, then motifs. A few big hard-edged zones, then a handful of small
#     hand-defined tufts STAMPED at random places. Detail comes from repeating
#     deliberate shapes, never from per-pixel randomness.
#   * Nothing alone. No lone pixel in a zone map; every mark is a cluster.
#   * Ordered dither, never random alpha. A soft edge is two or three fixed
#     alpha steps with a regular 4x4 Bayer pattern between them, in a narrow
#     band -- so edges are hard and the dither is a texture, not static.

BAYER4 = ((0, 8, 2, 10), (12, 4, 14, 6), (3, 11, 1, 9), (15, 7, 13, 5))


def bayer(x: int, y: int) -> float:
    """The ordered-dither threshold for this pixel, in (0, 1)."""
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def mean_run(img: Image.Image) -> float:
    """Mean run of identical pixels along a row -- the grain measurement.
    Riverleap's water is 20; anything under ~5 reads as noise at 3x."""
    px = img.convert("RGBA").load()
    w, h = img.size
    changes = sum(px[x, y] != px[x + 1, y] for y in range(h) for x in range(w - 1))
    return float("inf") if changes == 0 else (h * (w - 1)) / float(changes)


def wrapped_field(rng, W, H, octaves, stretch=1.0):
    """A seamless smooth field in -1..1: soft bumps that wrap at the edges.

    `octaves` is [(count, min_radius, max_radius, weight)]. `stretch` widens
    every bump into a horizontal swathe -- round zones were what made the first
    clearing read as a pond full of lily pads, and a swathe reads as grass
    combed by the wind."""
    field = [[0.0] * W for _ in range(H)]
    for count, rmin, rmax, scale in octaves:
        for _ in range(count):
            cx, cy = rng.randrange(W), rng.randrange(H)
            r = rng.randrange(rmin, rmax)
            rx = int(r * stretch)
            weight = rng.uniform(-1.0, 1.0) * scale
            for y in range(-r, r + 1):
                for x in range(-rx, rx + 1):
                    d2 = (x * x) / float(rx * rx) + (y * y) / float(r * r)
                    if d2 >= 1.0:
                        continue
                    field[(cy + y) % H][(cx + x) % W] += weight * (1.0 - d2) ** 2
    peak = max(abs(v) for row in field for v in row) or 1.0
    return [[v / peak for v in row] for row in field]


def stamp(px, W, H, motif, x0, y0, ink, wrap=True):
    """Draw a hand-defined motif (rows of characters, "." for nothing), looking
    each character up in `ink`. Wraps by default, so tiles stay seamless."""
    for my, row in enumerate(motif):
        for mx, ch in enumerate(row):
            if ch not in ink:
                continue
            x, y = x0 + mx, y0 + my
            if wrap:
                x, y = x % W, y % H
            elif not (0 <= x < W and 0 <= y < H):
                continue
            px[x, y] = ink[ch]


def despeckle(img: Image.Image, wrap=True) -> None:
    """No pixel on its own. One unlike both horizontal neighbours, which agree
    with each other, takes their colour; so does one unlike all four."""
    px = img.load()
    src = img.copy().load()
    W, H = img.size

    def at(x, y):
        if wrap:
            return src[x % W, y % H]
        return src[x, y] if 0 <= x < W and 0 <= y < H else CLEAR

    for y in range(H):
        for x in range(W):
            c, l, r, u, d = at(x, y), at(x - 1, y), at(x + 1, y), at(x, y - 1), at(x, y + 1)
            if l == r and c != l:
                px[x, y] = l
            elif c != l and c != r and c != u and c != d and u == d:
                px[x, y] = u


def stepped(v, x, y, cuts, band):
    """How many of `cuts` the value is past. Within +-band of a cut the answer
    is decided by the Bayer threshold, so a step has a narrow, regular dither
    edge instead of a soft one. Keep the band narrow: dither is the costliest
    texture there is by the grain measurement, a checkerboard being a run of 1."""
    level = 0
    for cut in cuts:
        if v >= cut + band:
            level += 1
        elif v > cut - band:
            if (v - (cut - band)) / (2.0 * band) > bayer(x, y):
                level += 1
            break
        else:
            break
    return level


def retro_ground(seed, W, zones, ink, cuts, tufts, tuft_count, extras=(),
                 octaves=((26, 10, 24, 1.0), (34, 4, 9, 0.40)), stretch=2.2):
    """A seamless ground tile: three close zones, then stamped tufts.

    The zones (dark, base, lit) are deliberately close in value. Their job is
    to give the ground SHAPE; at high contrast they read as camouflage and
    give the tile's repeat away. The contrast lives in the tufts instead,
    drawn from `ink` ("s" shadow, "h" highlight), which are few and deliberate.
    `extras` is [(motif, count, [ink, ...])] for flowers, earth and the like."""
    rng = random.Random(seed)
    field = wrapped_field(rng, W, W, octaves, stretch)
    img, _ = canvas(W, W)
    px = img.load()
    for y in range(W):
        for x in range(W):
            v = field[y][x]
            px[x, y] = zones[0] if v < cuts[0] else (zones[2] if v > cuts[1] else zones[1])
    # Cleaned BEFORE the tufts go down: a tuft's thin tips are the motif, and
    # a cleanup pass after stamping erases them to dots.
    despeckle(img)
    px = img.load()
    for _ in range(tuft_count):
        stamp(px, W, W, rng.choice(tufts), rng.randrange(W), rng.randrange(W), ink)
    for motif, count, inks in extras:
        for _ in range(count):
            chosen = rng.choice(inks)
            stamp(px, W, W, motif, rng.randrange(W), rng.randrange(W), chosen)
    return img


def shade_layer(seed, W, lit, dark, lit_alpha, dark_alpha, cuts, band, octaves,
                stretch=1.0):
    """The second, larger ground layer that beats against the first so the
    grid never shows: light and shadow in two hard alpha steps each, with an
    ordered-dither edge between steps. Replaces a smooth falloff with 24-30
    alpha levels, which read as an airbrush over pixel art."""
    rng = random.Random(seed)
    field = wrapped_field(rng, W, W, octaves, stretch)
    img, _ = canvas(W, W)
    px = img.load()
    for y in range(W):
        for x in range(W):
            v = field[y][x]
            if v >= 0.0:
                n = stepped(v, x, y, cuts, band)
                if n:
                    px[x, y] = (*lit, lit_alpha[n - 1])
            else:
                n = stepped(-v, x, y, cuts, band)
                if n:
                    px[x, y] = (*dark, dark_alpha[n - 1])
    return img


# --------------------------------------------------------------------------- water

def water_tiles():
    """The river surface, as three layers on deliberately different periods.

    Two lessons are baked in here and both cost a round to learn.

    The first: no mark may span the tile and nothing may align into rows --
    continuous lines read as corrugated metal, not water -- and there is no
    flipbook on the BASE. An earlier version cycled three base frames that each
    shifted the pattern 3px, so at 4fps the whole river teleported four times a
    second. The base is one still image and stays that way.

    The second is what this pass is about. A 64px tile across a 504px river is
    forty visible repeats, and no amount of detail inside one tile hides a grid
    that regular. Three things fix it together:

      * the base goes to 192px, so the grid repeats about four times, not forty
      * a separate depth layer at 256px drifts at a DIFFERENT fraction of the
        current. Different size and different speed means the two patterns beat
        against each other on a period long enough that no repeat is ever
        visible. This is the one that actually does the work -- a bigger tile
        on its own only makes the grid bigger.
      * the glints animate in place: same positions every frame, only the alpha
        rising and falling. Nothing translates, so the teleport cannot return.
    """
    import math as _m

    # --- the surface ------------------------------------------------------
    rng = random.Random(4100)
    W = H = 192
    img, d = canvas(W, H, P["water_mid"])

    def blob(cx, cy, rx, ry, colour):
        """An ellipse that wraps at the edges, so the tile stays seamless."""
        for y in range(-ry, ry + 1):
            span = int(rx * (1.0 - (y / float(ry)) ** 2) ** 0.5)
            for x in range(-span, span + 1):
                img.putpixel(((cx + x) % W, (cy + y) % H), colour)

    shade = (40, 88, 126, 255)

    # Large-scale structure first. At 192px the tile is big enough to hold
    # actual current shapes rather than only speckle, and without them a bigger
    # tile is just more of the same mush -- which is the other way to look
    # repetitive.
    for _ in range(7):
        cx, cy = rng.randrange(W), rng.randrange(H)
        length = rng.randrange(40, 90)
        drift = rng.uniform(-0.25, 0.25)
        tone = shade if rng.random() < 0.6 else P["water_deep"]
        for i in range(length):
            x = cx + i
            y = cy + int(_m.sin(i / 14.0) * 4.0 + i * drift)
            blob(x % W, y % H, rng.randrange(5, 11), rng.randrange(2, 4), tone)

    # Then the mottling, scaled up with the tile so the density is unchanged.
    for _ in range(99):
        blob(rng.randrange(W), rng.randrange(H),
             rng.randrange(4, 13), rng.randrange(1, 4), shade)
    for _ in range(36):
        blob(rng.randrange(W), rng.randrange(H),
             rng.randrange(3, 8), rng.randrange(1, 3), P["water_deep"])
    for _ in range(108):
        blob(rng.randrange(W), rng.randrange(H),
             rng.randrange(3, 9), rng.randrange(1, 3), P["water_mid"])

    # Short broken streaks. Never aligned, never full width -- the whole
    # difference between "water" and "stripes".
    for _ in range(198):
        x, y = rng.randrange(W), rng.randrange(H)
        length = rng.randrange(3, 9)
        colour = P["water_light"] if rng.random() < 0.82 else P["foam"]
        for i in range(length):
            img.putpixel(((x + i) % W, y), colour)
    save(img, "shared/water.png")

    # --- depth: the layer that kills the grid -----------------------------
    # Very soft and very low contrast, because it is not meant to be seen as a
    # texture at all. Its job is to make two identical surface tiles sit on
    # different shades so the eye stops finding the repeat.
    rng = random.Random(4150)
    DW = DH = 256
    field = [[0.0] * DW for _ in range(DH)]
    for _ in range(26):
        cx, cy = rng.randrange(DW), rng.randrange(DH)
        radius = rng.randrange(34, 86)
        weight = rng.uniform(-1.0, 1.0)
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                d2 = (x * x + y * y) / float(radius * radius)
                if d2 >= 1.0:
                    continue
                falloff = (1.0 - d2) ** 2
                field[(cy + y) % DH][(cx + x) % DW] += weight * falloff
    peak = max(abs(v) for row in field for v in row) or 1.0
    img, _ = canvas(DW, DH)
    for y in range(DH):
        for x in range(DW):
            v = field[y][x] / peak
            if v >= 0.0:
                colour, a = P["water_light"][:3], v * 46.0
            else:
                colour, a = P["water_deep"][:3], -v * 64.0
            if a < 2.0:
                continue
            img.putpixel((x, y), (*colour, int(a)))
    save(img, "shared/water_depth.png")

    # --- the glints, animated in place ------------------------------------
    rng = random.Random(4200)
    GW = GH = 128
    streaks = []
    for _ in range(72):
        streaks.append((rng.randrange(GW), rng.randrange(GH),
                        rng.randrange(4, 12), rng.randrange(40, 95),
                        rng.uniform(0.0, _m.tau)))
    FRAMES = 4
    for frame in range(FRAMES):
        img, _ = canvas(GW, GH)
        phase = frame / float(FRAMES) * _m.tau
        for x, y, length, alpha, offset in streaks:
            # Only the brightness moves. Positions are identical in every
            # frame, which is what makes this safe where a base flipbook was
            # not: there is nothing to teleport.
            pulse = 0.55 + 0.45 * _m.sin(phase + offset)
            for i in range(length):
                t = min(i, length - 1 - i) / max(1.0, (length - 1) / 2.0)
                a = alpha * min(1.0, t + 0.35) * pulse
                if a < 3.0:
                    continue
                img.putpixel(((x + i) % GW, y), (206, 232, 246, int(a)))
        save(img, f"shared/water_glints_{frame}.png")


def bank_edge():
    """The waterline: grass, a wet lip, then shallows dissolving into the river.

    Three attempts. A ruler-straight cut; then sand so wide and bright it read
    as a dirt path; then shallows that were the right idea but drawn as an
    opaque rectangle, which simply moved the straight edge a few pixels right.

    The fix is that the water side has to end in *alpha*, not in a colour --
    the shallows fade to nothing across the last third of the tile and the
    river shows through, so there is no boundary to see. Dithered, because at
    this palette a smooth ramp bands.

    Drawn for the LEFT bank (land left, water right); the right bank uses the
    same tile with flip_h.
    """
    import math as _m
    W, H = 24, 32
    img, d = canvas(W, H)
    rng = random.Random(4300)
    wet = (104, 92, 68, 255)
    shallow = (86, 148, 182)
    for y in range(H):
        # Tileable: the profile is a sine over the tile height, so row 31
        # meets row 0 with no step. Verified numerically, not by eye.
        base = 9.0 + 2.6 * _m.sin(y / H * _m.tau) + 1.2 * _m.sin(y / H * _m.tau * 3.0)
        lip = int(base) + rng.randrange(0, 2)
        for x in range(W):
            if x < lip - 1:
                img.putpixel((x, y), P["grass"])
            elif x < lip:
                img.putpixel((x, y), P["grass_dark"])
            elif x < lip + 1:
                img.putpixel((x, y), wet)
            else:
                # Fade out over whatever is left of the tile.
                t = (x - lip - 1) / max(1.0, float(W - lip - 2))
                a = int(200 * (1.0 - t) ** 1.5)
                if a <= 4:
                    continue
                # Dither the tail so the ramp does not band.
                if a < 70 and ((x + y) % 2) == 0:
                    continue
                img.putpixel((x, y), (*shallow, a))
        # Broken foam right on the lip -- never a continuous line, or it is
        # just the straight edge again in a different colour.
        if rng.random() < 0.5:
            img.putpixel((min(W - 1, lip + 1), y), (*P["foam"][:3], 205))
    save(img, "shared/bank_edge.png")


def ripple():
    img, d = canvas(32, 32)
    d.ellipse([4, 10, 27, 21], outline=P["foam"])
    d.ellipse([9, 13, 22, 18], outline=P["water_light"])
    save(img, "shared/ripple.png")


def lotus_pads():
    """The thing you stand on.

    A lotus pad: a foreshortened disc with a wedge notch and veins radiating
    from it. The notch is not decoration -- it gives the pad an orientation,
    so the wobble that warns you it is about to sink reads as rotation rather
    than as a shimmer.

    The first version walked a highlight around the rim across the four frames.
    At 4fps that is a full lap a second, which is a loading spinner, and it is
    exactly what it looked like. The light now sits where every other lit thing
    in this scene is lit from -- the top left -- and the animation moves the
    *shape* instead: the pad breathes and its lit edge creeps a pixel. Nothing
    travels around the rim any more, so nothing can read as a spinner.
    """
    import math as _m
    W, H = 32, 26
    CX, CY, RX = 16.0, 13.0, 15.0

    rim = (26, 116, 56, 255)
    body = (52, 162, 80, 255)
    lit = (104, 202, 100, 255)
    vein = (38, 138, 66, 255)
    hot = (198, 240, 148, 255)

    def pad(ry, breath, submerge=0.0, alpha=1.0, name="x"):
        img, _ = canvas(W, H)
        for y in range(H):
            for x in range(W):
                dx, dy = (x + 0.5 - CX) / RX, (y + 0.5 - CY) / ry
                d = _m.sqrt(dx * dx + dy * dy)
                if d > 1.0:
                    continue
                # Angle in the pad's own space, not the screen's: the disc is
                # foreshortened, so a wedge measured in raw pixels comes out
                # far wider at the sides than intended.
                ang = _m.atan2(dy, dx)
                if abs(ang) < 0.17 and d > 0.10:          # the wedge notch
                    continue
                if d > 0.88:
                    c = rim
                else:
                    spoke = abs(_m.sin(ang * 4.0))
                    if spoke < 0.16 and d > 0.22:
                        c = vein
                    elif dx + dy < -0.45 + breath:
                        c = lit
                    else:
                        c = body
                # A fixed glint, upper left, where the light is. It only
                # breathes with the pad; it never travels.
                if d > 0.52 and d < 0.92 and -2.5 < ang < -1.5:
                    c = hot
                if submerge > 0.0:
                    water = (46, 100, 141)
                    c = tuple(int(c[i] * (1.0 - submerge) + water[i] * submerge)
                              for i in range(3)) + (c[3],)
                img.putpixel((x, y), (c[0], c[1], c[2], int(c[3] * alpha)))
        save(img, name)

    # Float: the pad breathes a pixel and its lit edge creeps, nothing more.
    for f in range(4):
        phase = f / 4.0 * _m.tau
        pad(10.0 + 0.6 * _m.sin(phase), 0.07 * _m.sin(phase + 1.2),
            name=f"wind_leaf/leaf_{f}.png")

    # Sink: tipping under, flattening and taking the water's colour with it.
    for f in range(3):
        t = (f + 1) / 3.0
        pad(10.0 * (1.0 - 0.55 * t), 0.0, submerge=0.55 * t,
            alpha=1.0 - 0.45 * t, name=f"wind_leaf/leaf_sink_{f}.png")


def hazards():
    """What the river throws at you, and what warns you it is coming.

    Both hazards FLY. That is not decoration, it is the fix for a design bug:
    the jumpable hazard used to be a driftwood log sweeping down a lane, which
    meant a 56px solid passing straight over the lily pads -- nonsense to look
    at, and a layering fight to implement. Something in the air never touches
    the pads at all, and the draw order becomes a statement of the rule rather
    than a problem to manage: jump and you are drawn over it, stay down and it
    is drawn over you, because it hits you.

    They must be unmistakable from each other, because they want opposite
    reactions -- you jump the hornet, and jumping does nothing against the
    heron. So they share no cue: the hornet is small, striped and hot yellow;
    the heron is large, plain and dark blue-grey. Stripes appear nowhere else
    in the game.
    """
    import math as _m
    rng = random.Random(4700)

    # --- river hornet ---------------------------------------------------
    # Flying head-on down the river at you, so it is drawn from BEHIND and
    # above: a fat striped abdomen, wings swept out either side. Seen head-on
    # it stays wide and legible while it closes, where a side-on insect would
    # be a thin smear.
    #
    # Not a bird, deliberately. The heron already owns "bird", and the two
    # must be told apart in the half second there is to react.
    W, H = 26, 20
    img, d = canvas(W, H)
    dark = (38, 30, 16, 255)
    amber = (248, 196, 48, 255)
    cx = W // 2

    # Wings first, so the body sits on top of them. Pale and barely there --
    # a blur, not a shape.
    d.polygon([(cx - 3, 8), (0, 2), (2, 11)], fill=(226, 236, 248, 150))
    d.polygon([(cx + 3, 8), (W - 1, 2), (W - 3, 11)], fill=(226, 236, 248, 150))

    d.ellipse([cx - 6, 5, cx + 5, H - 2], fill=amber)      # abdomen
    # Two bands, not three, and one pixel each. At this size a heavier stripe
    # turns the whole insect dark, and dark is what it must not be -- it has
    # to carry over water that is already dark.
    for band in (11, 15):
        d.rectangle([cx - 6, band, cx + 5, band], fill=dark)
    d.ellipse([cx - 4, 1, cx + 3, 7], fill=dark)           # thorax and head
    d.point((cx - 2, 3), (255, 92, 48, 255))               # two hot eyes
    d.point((cx + 1, 3), (255, 92, 48, 255))
    d.line([(cx - 3, 1), (cx - 5, 0)], fill=dark)          # antennae
    d.line([(cx + 2, 1), (cx + 4, 0)], fill=dark)
    d.polygon([(cx - 1, H - 2), (cx, H - 1), (cx + 1, H - 2)], fill=dark)
    save(img, "wind_leaf/hornet.png")

    # --- heron ----------------------------------------------------------
    W, H = 28, 34
    img, d = canvas(W, H)
    body = (54, 62, 84, 255)
    light = (96, 106, 134, 255)
    d.polygon([(14, 6), (21, 20), (14, 30), (7, 20)], fill=body)   # body
    d.polygon([(14, 8), (19, 20), (14, 26)], fill=light)
    d.polygon([(7, 14), (0, 4), (4, 20)], fill=body)               # wings
    d.polygon([(21, 14), (27, 4), (24, 20)], fill=body)
    d.ellipse([11, 1, 17, 8], fill=light)                          # head
    d.polygon([(14, 30), (12, 34), (16, 34)], fill=(226, 160, 70, 255))
    d.point((13, 4), (24, 22, 34, 255))
    save(img, "wind_leaf/heron.png")

    # --- the mark that warns you ----------------------------------------
    # Jumping does not save you from a dive, so THIS SPRITE IS THE DODGE. If
    # it cannot be seen in time the hazard is simply unfair.
    #
    # It has now failed in both directions. A dark blob is invisible on dark
    # water -- but the soft pale ring that replaced it was invisible too, for
    # the opposite reason: the river surface is covered in pale horizontal
    # glints at exactly that value, and the ring dissolved into them.
    #
    # So: hot orange-red, which nothing else in the scene uses (water blue,
    # pads green, log brown); HARD edges, with a near-black outline on both
    # sides so it separates from any background value rather than relying on
    # being lighter; and reticle ticks outside it, because a plain circle on
    # water reads as a ripple -- which the game already uses to mean something
    # else -- while a reticle reads as a thing about to land here.
    W = H = 40
    img, _ = canvas(W, H)
    px = img.load()
    bright = (255, 92, 48)
    outline = (26, 14, 10)
    for y in range(H):
        for x in range(W):
            dx, dy = (x + 0.5 - W / 2) / (W / 2), (y + 0.5 - H / 2) / (H / 2)
            d = _m.sqrt(dx * dx + dy * dy)
            if d > 1.0:
                continue
            # Reticle ticks: four stubs on the axes, outside the ring.
            if d > 0.86:
                on_axis = abs(dx) < 0.16 or abs(dy) < 0.16
                if on_axis:
                    px[x, y] = bright + (235,)
                continue
            if d > 0.80:
                px[x, y] = outline + (225,)
            elif d > 0.60:
                px[x, y] = bright + (255,)
            elif d > 0.53:
                px[x, y] = outline + (225,)
            else:
                # Barely-there wash, so the pad underneath stays readable.
                px[x, y] = (60, 16, 10, 48)
    save(img, "wind_leaf/dive_shadow.png")


def heart_segments():
    """Five of these are the health bar. Full, half and empty.

    Drawn as blocky segments rather than literal hearts: at 11x9 a heart is
    mush, and a segmented bar is what Neo asked for anyway.
    """
    W, H = 11, 9
    shell = (34, 30, 48, 255)
    edge = (92, 86, 118, 255)
    full = (236, 84, 92, 255)
    full_lit = (255, 142, 136, 255)

    def seg(fill_to: float, name: str):
        img, d = canvas(W, H)
        d.rectangle([0, 0, W - 1, H - 1], fill=shell, outline=edge)
        cut = int(round((W - 2) * fill_to))
        if cut > 0:
            d.rectangle([1, 1, cut, H - 2], fill=full)
            d.rectangle([1, 1, cut, 2], fill=full_lit)
        save(img, f"ui/{name}.png")

    seg(1.0, "heart_full")
    seg(0.5, "heart_half")
    seg(0.0, "heart_empty")


def player_jump_frames():
    """Jump poses, derived from the hand-drawn player rather than invented.

    The jump used to be *faked*: `walk_right` frame 1, paused and mirrored,
    with squash and stretch applied in code. That was a workaround for there
    being no drawn frames, and it showed -- the character slid through the air
    mid-stride, and the mirroring existed only because the two walk sets are
    not mirrors of each other.

    These are real frames, but they are NOT drawn from scratch. The player art
    is hand-drawn with its own palette and shading; an invented character would
    read as a different person. So each pose cuts the existing idle frame into
    bands -- everything above the skirt hem, and the legs below it -- and
    MOVES them. Not resamples: the first attempt scaled the bands and the legs
    simply dissolved, because at this size they are four pixels tall and there
    is nothing there to resample. Translation keeps every pixel exactly as it
    was drawn, which is the whole point of deriving these rather than drawing
    new ones.

    Three frames, the minimum that reads as a jump:

        0  crouch    body sunk into the legs           -- the push off
        1  airborne  legs tucked up and split apart    -- the hang
        2  land      body sunk deepest, stance widest  -- the impact

    The airborne frame deliberately leaves empty pixels under the feet: the
    sprite's origin is at the character's feet, so a gap there is what reads
    as being off the ground.
    """
    from PIL import Image

    def leg_top(img):
        """The skirt hem is the widest row low on the figure; legs start under
        it. Found rather than hard-coded, because it sits at a different row
        in the front-on and side-on sets."""
        px = img.load()
        lower = []
        for y in range(img.height // 2, img.height):
            n = sum(1 for x in range(img.width) if px[x, y][3] > 0)
            if n:
                lower.append((n, y))
        if not lower:
            return img.height - 4
        return min(max(lower)[1] + 1, img.height - 1)

    def bounds(img):
        px = img.load()
        ys = [y for y in range(img.height)
              if any(px[x, y][3] > 0 for x in range(img.width))]
        return (ys[0], ys[-1]) if ys else (0, img.height - 1)

    def flare_hem(body, rows, amount):
        """Widen the bottom rows of the body band -- the skirt hem.

        This is the cue that actually sells the pose. At 32x32 the skirt is
        most of the silhouette and the legs are nearly hidden behind it, so
        moving the legs around barely registers; a skirt lifting as the
        character leaves the ground registers immediately, and it is what a
        skirt really does.
        """
        if amount <= 0 or body.height <= rows:
            return body
        W = body.width
        out = body.copy()
        hem = body.crop((0, body.height - rows, W, body.height))
        wide = hem.resize((W + amount * 2, rows), Image.NEAREST)
        out.alpha_composite(Image.new("RGBA", (W, rows), (0, 0, 0, 0)),
                            (0, body.height - rows))
        out.alpha_composite(wide.crop((amount, 0, amount + W, rows)),
                            (0, body.height - rows))
        return out

    def pose(src, body_dy, legs_dy, split, lift, squash, flare=0):
        img = Image.open(src).convert("RGBA")
        W, H = img.size
        top, bottom = bounds(img)
        cut = leg_top(img)

        body = img.crop((0, top, W, cut))
        legs = img.crop((0, cut, W, bottom + 1))

        # The body is ~24px tall, so it survives losing a row or two; this is
        # what makes a crouch read as compressed rather than merely lowered.
        if squash and body.height > squash + 2:
            body = body.resize((W, body.height - squash), Image.NEAREST)
        body = flare_hem(body, 4, flare)

        out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        legs_y = cut + legs_dy - lift
        body_y = (cut - body.height) + body_dy - lift

        px = legs.load()
        xs = [x for x in range(W)
              if any(px[x, y][3] > 0 for y in range(legs.height))]
        if split and xs:
            # Legs apart: cut the leg block down the middle and push the halves
            # outward. At this size one or two pixels of separation is the
            # difference between "airborne" and "standing still in the air".
            mid = (min(xs) + max(xs)) // 2 + 1
            out.alpha_composite(legs.crop((0, 0, mid, legs.height)),
                                (-split, legs_y))
            out.alpha_composite(legs.crop((mid, 0, W, legs.height)),
                                (mid + split, legs_y))
        else:
            out.alpha_composite(legs, (0, legs_y))
        out.alpha_composite(body, (0, body_y))
        return out

    # legs_dy is measured from the body's hem, so anything negative pulls the
    # legs up BEHIND the skirt and they vanish -- which is exactly what the
    # first version did. It read as the character having no legs at all, and
    # with the code-side stretch on top the whole figure became a smear. The
    # legs have to stay visible; the airborne read comes from lifting the whole
    # figure off the bottom of the cell and splitting the feet, not from
    # hiding them.
    #
    #        body_dy legs_dy split lift squash flare
    POSES = {
        0: (2, 0, 0, 0, 2, 0),    # crouch: body sunk into the legs
        1: (0, 0, 2, 3, 0, 2),    # airborne: lifted clear, feet apart, hem up
        2: (3, 0, 1, 0, 3, 1),    # land: deepest fold, widest stance
    }
    for facing in ("down", "up", "left", "right"):
        src = OUT / "player" / f"idle_{facing}.png"
        if not src.exists():
            continue
        for index, args in POSES.items():
            save(pose(src, *args), f"player/jump_{facing}_{index}.png")


def control_pictograms():
    """The stick and the button, for the card that teaches the controls.

    Both are drawn NEUTRAL -- the stick upright, the button unpressed -- and
    the tilt and the press are applied in code on the card. That is how
    everything else in this project animates, and it means the whole lesson
    needs two sprites rather than six.

    Chunky and high contrast on purpose: this is read from a few feet back by
    someone who has not decided to play yet.
    """
    # --- joystick -------------------------------------------------------
    W, H = 20, 24
    img, d = canvas(W, H)
    shaft = (62, 58, 82, 255)
    base = (38, 35, 52, 255)
    ball = (236, 92, 78, 255)
    ball_lit = (255, 150, 132, 255)
    d.ellipse([1, H - 8, W - 2, H - 1], fill=base)          # base plate
    d.ellipse([3, H - 7, W - 4, H - 3], fill=(54, 50, 70, 255))
    d.rectangle([W // 2 - 2, 8, W // 2 + 1, H - 6], fill=shaft)
    d.ellipse([W // 2 - 6, 1, W // 2 + 5, 12], fill=ball)   # ball top
    d.ellipse([W // 2 - 4, 2, W // 2 + 1, 7], fill=ball_lit)
    save(img, "ui/stick.png")

    # --- button ---------------------------------------------------------
    W = H = 16
    img, d = canvas(W, H)
    d.ellipse([0, 2, W - 1, H - 1], fill=(38, 35, 52, 255))  # the well
    d.ellipse([1, 1, W - 2, H - 3], fill=(250, 196, 64, 255))
    d.ellipse([3, 2, W - 6, H - 8], fill=(255, 232, 150, 255))
    save(img, "ui/button.png")

    # --- direction arrow ------------------------------------------------
    # The stick on its own says "there is a stick"; it does not say which way
    # to push it. Drawn pointing RIGHT and mirrored in code for the left.
    W, H = 9, 12
    img, d = canvas(W, H)
    d.polygon([(0, 0), (W - 1, H // 2), (0, H - 1)], fill=(255, 236, 170, 255))
    d.polygon([(2, 3), (W - 4, H // 2), (2, H - 4)], fill=(255, 255, 230, 255))
    save(img, "ui/arrow.png")


def _acorn_floor_v1(rng):
    """Acorn Storm's first clearing floor and shade layer. Writes nothing.

    Kept for two reasons. It is the record of what NOISE looks like: 1,500
    single-pixel blades and a 30-level alpha falloff, mean run 2.0 px, which
    is what Neo meant by "too realistic for a 2d pixel game". And the canopy
    is drawn after it from the same random stream, so its draws must still
    happen for the canopy to stay byte-identical. Its file names are not in
    KEEP, so save() discards both images.
    """
    # --- the clearing floor -----------------------------------------------
    # 160px, not 32. The river taught this the hard way: a small tile across a
    # wide field is a visible grid no amount of detail inside one tile hides.
    #
    # Texture is BLADES, not blobs. The first version laid down wide flat
    # ellipses, and tiled across the screen it read as a pond covered in lily
    # pads rather than as grass -- big hard-edged ovals are what a lily pad
    # looks like from above, which this project has unfortunately drawn before
    # and knows well. Short strokes at low contrast read as ground cover, and
    # they have no shape large enough for the eye to match across the tile
    # seam, which is the other half of why the grid disappeared.
    W = H = 160
    img, _ = canvas(W, H, P["grass"])
    px = img.load()

    def soft_patch(cx, cy, r, colour, strength):
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                d2 = (x * x + y * y) / float(r * r)
                if d2 >= 1.0:
                    continue
                if rng.random() > strength * (1.0 - d2):
                    continue
                px[(cx + x) % W, (cy + y) % H] = colour

    # Broad, very low contrast variation first, so the field is not flat.
    for _ in range(14):
        soft_patch(rng.randrange(W), rng.randrange(H), rng.randrange(18, 40),
                   P["grass_dark"], 0.5)
    for _ in range(12):
        soft_patch(rng.randrange(W), rng.randrange(H), rng.randrange(14, 34),
                   P["grass_lit"], 0.45)

    # Then the blades. Mostly upright, one to three pixels, in both directions
    # from the base tone so the texture reads at a distance without any one
    # stroke being visible.
    for _ in range(1500):
        x, y = rng.randrange(W), rng.randrange(H)
        length = rng.randrange(1, 4)
        lean = rng.choice((-1, 0, 0, 1))
        tone = P["grass_lit"] if rng.random() < 0.5 else P["grass_dark"]
        for i in range(length):
            px[(x + lean * i) % W, (y - i) % H] = tone
    # A little bare earth showing through.
    for _ in range(90):
        x, y = rng.randrange(W), rng.randrange(H)
        for i in range(rng.randrange(1, 4)):
            px[(x + i) % W, y] = (104, 92, 62, 255)
    save(img, "acorn_storm/clearing_v1.png")

    # --- the shade layer --------------------------------------------------
    # 224px against the floor's 160, drifting at a different rate. Two periods
    # that never line up is what actually killed the river's grid; a bigger
    # tile on its own only makes the grid bigger.
    #
    # Kept light. At its first strength it turned the whole clearing into a
    # dark green soup that the player and both ground marks had to fight to
    # be seen against -- and the marks are the game.
    DW = DH = 224
    field = [[0.0] * DW for _ in range(DH)]
    for _ in range(22):
        cx, cy = rng.randrange(DW), rng.randrange(DH)
        radius = rng.randrange(30, 78)
        weight = rng.uniform(-1.0, 1.0)
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                d2 = (x * x + y * y) / float(radius * radius)
                if d2 >= 1.0:
                    continue
                field[(cy + y) % DH][(cx + x) % DW] += weight * (1.0 - d2) ** 2
    peak = max(abs(v) for row in field for v in row) or 1.0
    img, _ = canvas(DW, DH)
    for y in range(DH):
        for x in range(DW):
            v = field[y][x] / peak
            colour = (236, 244, 206) if v >= 0 else (28, 44, 24)
            a = abs(v) * (26 if v >= 0 else 30)
            if a < 2.0:
                continue
            img.putpixel((x, y), (*colour, int(a)))
    save(img, "acorn_storm/canopy_shade_v1.png")


def acorn_storm_ground():
    """The clearing floor and the shade through the leaves, at retro grain.

    Mown grass in big hard-edged swathes, with short tufts stamped over it and
    a little bare earth -- see the grain section at the top of this file for
    the rules, and acorn_test.gd for the assertion that holds them.

    The two-period rule is unchanged: 160px floor under a 224px shade layer
    that drifts with the wind, so the repeat never lines up.
    """
    # Short and wide: this is mown grass, and Hush Meadow's tall tufts are
    # what tells the two games apart at a glance.
    short_tufts = [
        ["h.h", ".s."],
        ["h..h", ".ss."],
        [".h.h", "h.s.", ".ss."],
        ["h.h.h", ".sss."],
    ]
    earth = {"e": (104, 92, 62, 255), "d": (86, 76, 52, 255)}
    img = retro_ground(
        5200, 160,
        zones=[(66, 110, 54, 255), P["grass"], (84, 136, 66, 255)],
        ink={"s": (52, 88, 44, 255), "h": (110, 160, 78, 255)},
        cuts=(-0.28, 0.20), tufts=short_tufts, tuft_count=120,
        extras=[(["eee.", "deee", ".dd."], 5, [earth]),
                ([".ee", "eed", "dd."], 5, [earth])])
    save(img, "acorn_storm/clearing.png")

    # Kept light, as the first version learned: at full strength it turned
    # the clearing into a soup that both ground marks had to fight -- and the
    # marks are the game.
    img = shade_layer(
        5250, 224, lit=(236, 244, 206), dark=(28, 44, 24),
        lit_alpha=(14, 24), dark_alpha=(18, 30), cuts=(0.28, 0.58), band=0.035,
        octaves=[(22, 30, 78, 1.0), (16, 10, 22, 0.25)], stretch=1.2)
    save(img, "acorn_storm/canopy_shade.png")


def acorn_storm_art():
    """The clearing, and the two things that fall into it.

    The marks on the ground are the important part. Riverleap's dive marker
    had to be redrawn twice to learn that a soft pale ring vanishes into a busy
    background, and that colour on its own is not a cue you can rely on -- not
    on a scuffed cabinet screen and not for a colourblind player.

    So the two marks here differ by SHAPE first and colour second:

        danger -- a hard-edged ring with reticle ticks, hot orange-red, open
                  in the middle so you can see what is under it
        good   -- a filled soft disc with a bright rim, gold

    One is an outline, one is a solid. That reads at a glance even in
    greyscale, which is the test worth applying.
    """
    import math as _m
    rng = random.Random(5100)

    # --- the danger mark --------------------------------------------------
    W = H = 34
    img, d = canvas(W, H)
    px = img.load()
    hot = (255, 92, 48)
    edge = (26, 14, 10)
    for y in range(H):
        for x in range(W):
            dx, dy = (x + 0.5 - W / 2) / (W / 2), (y + 0.5 - H / 2) / (H / 2)
            dist = _m.sqrt(dx * dx + dy * dy)
            if dist > 1.0:
                continue
            if dist > 0.86:
                if abs(dx) < 0.16 or abs(dy) < 0.16:      # reticle ticks
                    px[x, y] = hot + (235,)
            elif dist > 0.78:
                px[x, y] = edge + (225,)
            elif dist > 0.56:
                px[x, y] = hot + (255,)
            elif dist > 0.48:
                px[x, y] = edge + (225,)
    save(img, "acorn_storm/mark_danger.png")

    # --- the good mark ----------------------------------------------------
    # Solid where the other is hollow. Even with the colour stripped out, a
    # filled disc and an open ring are not the same shape.
    img, d = canvas(W, H)
    px = img.load()
    gold = (255, 206, 92)
    gold_rim = (255, 240, 190)
    for y in range(H):
        for x in range(W):
            dx, dy = (x + 0.5 - W / 2) / (W / 2), (y + 0.5 - H / 2) / (H / 2)
            dist = _m.sqrt(dx * dx + dy * dy)
            if dist > 0.86:
                continue
            if dist > 0.74:
                px[x, y] = gold_rim + (250,)
            else:
                # Opaque enough to actually read as gold. The first version
                # faded to about half alpha over green grass and came out a
                # pale sage blob -- legible as a shape, useless as a promise
                # that something good lands here.
                px[x, y] = gold + (int(235 - 70 * dist),)
    save(img, "acorn_storm/mark_good.png")

    # --- acorn ------------------------------------------------------------
    W = H = 18
    img, d = canvas(W, H)
    d.ellipse([3, 6, 14, 17], fill=(176, 122, 62, 255))
    d.ellipse([5, 8, 11, 13], fill=(206, 156, 92, 255))
    d.rectangle([2, 2, 15, 8], fill=(96, 66, 40, 255))
    d.rectangle([3, 3, 14, 5], fill=(122, 86, 52, 255))
    d.rectangle([8, 0, 9, 3], fill=(72, 50, 30, 255))
    save(img, "acorn_storm/acorn.png")

    # --- sunfruit ---------------------------------------------------------
    # Bright and round against a brown, angular acorn: the pair has to be
    # separable in peripheral vision while you are watching something else.
    img, d = canvas(W, H)
    d.ellipse([2, 3, 15, 16], fill=P["sun_dark"])
    d.ellipse([3, 4, 13, 14], fill=P["sun"])
    d.ellipse([5, 6, 9, 10], fill=(255, 248, 218, 255))
    d.line([(9, 3), (11, 0)], fill=P["hedge"])
    d.polygon([(9, 2), (13, 1), (10, 4)], fill=(96, 150, 70, 255))
    save(img, "acorn_storm/sunfruit.png")

    # --- the clearing floor and its shade ---------------------------------
    # Redrawn at retro grain in acorn_storm_ground(). The first versions still
    # RUN, because everything below is drawn from this same random stream:
    # skip their draws and the canopy silently re-randomises.
    _acorn_floor_v1(rng)

    # --- rock -------------------------------------------------------------
    W, H = 22, 16
    img, d = canvas(W, H)
    d.ellipse([0, 4, W - 1, H - 1], fill=P["rock_dark"])
    d.ellipse([1, 2, W - 4, H - 4], fill=P["rock"])
    d.ellipse([4, 4, W - 10, H - 9], fill=(146, 146, 156, 255))
    save(img, "acorn_storm/rock.png")

    # --- squirrel, up in the canopy ---------------------------------------
    W, H = 16, 14
    img, d = canvas(W, H)
    body = (150, 96, 58, 255)
    d.ellipse([3, 5, 12, 13], fill=body)
    d.ellipse([8, 2, 14, 8], fill=body)                    # head
    d.polygon([(4, 10), (0, 3), (3, 2), (6, 8)], fill=(176, 122, 72, 255))
    d.point((12, 4), (24, 18, 14, 255))
    save(img, "acorn_storm/squirrel.png")

    # --- the canopy overhead ----------------------------------------------
    # The roof the storm comes out of: one band across the top of the screen,
    # 512 wide for a 480 viewport so it can sway without running out of art.
    #
    # It does NOT tile, and that is the point. It was 112 wide and repeated
    # horizontally first, which put four copies of the same silhouette across
    # the screen -- the exact grid the river spent a whole round killing, and
    # unnecessary here because the clearing does not scroll. A band that is
    # simply wider than the screen has no period to find.
    W, H = 512, 76
    img, d = canvas(W, H)
    px = img.load()
    dark = (24, 44, 28)
    mid = (36, 62, 38)
    lit = (52, 84, 48)

    def leaf_blob(cx, cy, r, colour):
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                if x * x + y * y > r * r:
                    continue
                tx, ty = cx + x, cy + y
                if ty < 0 or ty >= H or tx < 0 or tx >= W:
                    continue
                px[tx, ty] = colour + (255,)

    # A solid base across the top third first: the blobs alone left pinholes
    # of sky inside the mass, which reads as a bad composite rather than as
    # leaves. Only the BOTTOM edge of this band is supposed to be ragged.
    d.rectangle([0, 0, W - 1, int(H * 0.38)], fill=dark + (255,))

    # Every blob is opaque and the ragged edge comes from the blobs
    # themselves -- overlapping circles scallop the bottom on their own.
    # The first version thinned the lower pixels instead, first by alpha and
    # then by dither; one came out as grey haze over the sky and the other as
    # a band of static. Neither looked like leaves, and both were solving a
    # problem the silhouette already solved.
    for _ in range(120):
        leaf_blob(rng.randrange(W), rng.randrange(-6, int(H * 0.60)),
                  rng.randrange(10, 22), dark)
    for _ in range(140):
        leaf_blob(rng.randrange(W), rng.randrange(-4, int(H * 0.54)),
                  rng.randrange(6, 15), mid)
    for _ in range(120):
        leaf_blob(rng.randrange(W), rng.randrange(-2, int(H * 0.46)),
                  rng.randrange(3, 9), lit)
    # A few clumps hanging below the mass, so the edge is broken rather than
    # merely curved. Kept sparse: a row of them at a similar height stopped
    # reading as stray leaves and became a second row of dots under the first.
    for _ in range(22):
        leaf_blob(rng.randrange(W), rng.randrange(int(H * 0.56), int(H * 0.80)),
                  rng.randrange(4, 9), dark if rng.random() < 0.6 else mid)
    # Close the pinholes. Overlapping circles leave one- and two-pixel gaps
    # of sky inside the mass, and at 3x screen scale those are three to six
    # bright pixels winking out of a dark canopy. Per column, walk down from
    # the top and fill any gap of two pixels or less, which seals the mass
    # while leaving the hanging clumps -- separated by much more than that --
    # detached.
    for x in range(W):
        y = 0
        last_solid = -1
        while y < H:
            if px[x, y][3] > 0:
                last_solid = y
            elif y - last_solid > 2:
                break
            y += 1
        for fill_y in range(last_solid + 1):
            if px[x, fill_y][3] == 0:
                px[x, fill_y] = dark + (255,)
    save(img, "acorn_storm/canopy.png")

    # --- a catch / impact flash -------------------------------------------
    # One white-hot disc, tinted by whoever spawns it. Deliberately not either
    # of the two marks: a flash that looked like a telegraph would mean the
    # moment of resolution and the moment of warning share a shape.
    W = H = 24
    img, _ = canvas(W, H)
    px = img.load()
    for y in range(H):
        for x in range(W):
            dx, dy = (x + 0.5 - W / 2) / (W / 2), (y + 0.5 - H / 2) / (H / 2)
            dist = _m.sqrt(dx * dx + dy * dy)
            if dist > 1.0:
                continue
            px[x, y] = (255, 252, 238, int(255 * (1.0 - dist) ** 1.4))
    save(img, "acorn_storm/burst.png")


def golden_prize():
    """The rare one. Both games hand out the same idea in their own shape.

    It has to read as SPECIAL within a quarter of a second and from a few
    feet back, against a busy scene, without being mistaken for the thing
    the player already collects every few seconds. Three cues, none of
    which the ordinary pickups use: a white-hot core (nothing else in
    either game is white), a hard gold rim, and four radiating points.

    Deliberately NOT just a yellow version of the normal pickup. Riverleap's
    chimes are already pale and Acorn Storm's sunfruit is already gold; a
    brighter one of either would read as "another one of those" at exactly
    the moment it should not.
    """
    import math as _m

    def star(size, rays, ray_len):
        img, _ = canvas(size, size)
        px = img.load()
        c = (size - 1) / 2.0
        core = size * 0.26
        for y in range(size):
            for x in range(size):
                dx, dy = x - c, y - c
                dist = _m.sqrt(dx * dx + dy * dy)
                if dist <= core:
                    # White-hot centre fading to gold at the rim.
                    k = dist / max(core, 0.001)
                    px[x, y] = (255, int(255 - 40 * k), int(246 - 110 * k), 255)
                elif dist <= core + 1.6:
                    px[x, y] = (236, 170, 54, 255)          # hard rim
        # Four points, drawn after so they sit over the disc.
        for i in range(rays):
            ang = i * (2 * _m.pi / rays)
            for step in range(int(ray_len * size)):
                t = step / float(max(int(ray_len * size) - 1, 1))
                r = core + 1.0 + step
                x = int(round(c + _m.cos(ang) * r))
                y = int(round(c + _m.sin(ang) * r))
                if 0 <= x < size and 0 <= y < size:
                    # Long and bright. The first pass had short faint rays
                    # and the prize read as "a slightly whiter sunfruit" in
                    # the air, which is the one thing it must not be: the
                    # player has to want it before it lands, not recognise it
                    # afterwards.
                    a = int(255 * (1.0 - t) ** 0.45)
                    if a > 8:
                        px[x, y] = (255, 246, 214, a)
                        # Two pixels wide near the core, so the rays read as
                        # beams rather than as stray dots at 3x screen scale.
                        if t < 0.45:
                            for ox, oy in ((1, 0), (0, 1)):
                                nx, ny = x + ox, y + oy
                                if 0 <= nx < size and 0 <= ny < size \
                                        and px[nx, ny][3] == 0:
                                    px[nx, ny] = (255, 246, 214, int(a * 0.7))
        return img

    save(star(26, 4, 0.44), "wind_leaf/chime_gold.png")

    # --- Acorn Storm's prize: a GOLDEN ACORN ------------------------------
    # Same silhouette as an ordinary acorn, in gold. It used to be the star
    # above, which was unmistakable in the air -- and Neo asked for the
    # opposite: "make the acorns kinda hard to distinguish from the golden
    # ball so that's also part of the challenge (but not too hard)".
    #
    # The ambiguity is deliberately only in the AIR. On the ground the marks
    # still differ by shape (hot ring = move, gold disc = take it), so a
    # player who checks always has a reliable answer and the game never lies
    # to them. What it costs is a glance, which is the challenge that was
    # asked for. A four-point sparkle rides on top so "not too hard" holds:
    # it is the same shape as an acorn, not the same object.
    W = H = 20
    img, d = canvas(W, H)
    gold_dark, gold, gold_lit = (186, 138, 40, 255), (236, 190, 72, 255), (255, 236, 160, 255)
    d.ellipse([3, 7, 16, 19], fill=gold_dark)          # nut
    d.ellipse([5, 9, 13, 15], fill=gold)
    d.ellipse([6, 10, 10, 13], fill=gold_lit)          # highlight
    d.rectangle([2, 2, 17, 9], fill=(142, 104, 30, 255))   # cap
    d.rectangle([3, 3, 16, 6], fill=gold)
    d.rectangle([9, 0, 10, 3], fill=(120, 88, 26, 255))    # stalk
    # The one cue that is not an acorn: a hard four-point glint.
    px = img.load()
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        for step in (1, 2):
            x, y = 9 + dx * step, 12 + dy * step
            if 0 <= x < W and 0 <= y < H:
                px[x, y] = (255, 252, 226, 255 if step == 1 else 150)
    px[9, 12] = (255, 255, 248, 255)
    save(img, "acorn_storm/prize.png")

    # A spark the prize sheds as it travels, and throws on collection.
    img, _ = canvas(6, 6)
    px = img.load()
    for y in range(6):
        for x in range(6):
            d = _m.sqrt((x - 2.5) ** 2 + (y - 2.5) ** 2)
            if d <= 2.6:
                px[x, y] = (255, 248, 214, int(255 * (1.0 - d / 2.6)))
    save(img, "decor/spark.png")


def treeline():
    """Distant trees past the bank, as the slowest parallax layer.

    Deliberately dark, low contrast and detail-free. It is scenery at a
    distance and its whole job is to move slower than the bank in front of
    it; anything legible here would compete with five lanes of gameplay.
    Tiles vertically.
    """
    import math as _m
    W, H = 24, 32
    img, _ = canvas(W, H, (34, 58, 38, 255))
    rng = random.Random(4600)
    dark = (26, 46, 32)
    mid = (40, 68, 44)
    # Canopies placed on a vertical rhythm that divides H, so it tiles.
    for i in range(4):
        cy = i * (H / 4.0) + rng.uniform(-1.5, 1.5)
        cx = rng.uniform(4.0, 19.0)
        r = rng.uniform(4.5, 8.0)
        tone = dark if rng.random() < 0.55 else mid
        for y in range(H):
            for x in range(W):
                dy = min(abs(y - cy), abs(y - cy + H), abs(y - cy - H))
                if _m.sqrt((x - cx) ** 2 + dy ** 2) <= r:
                    img.putpixel((x, y), (*tone, 255))
    save(img, "village/treeline.png")


def chime():
    img, d = canvas(16, 16)
    d.line([(3, 2), (12, 2)], fill=P["wood"])
    for i, x in enumerate((4, 7, 10)):
        d.line([(x, 3), (x, 8 + i)], fill=P["chime"])
        d.point((x, 9 + i), P["foam"])
    save(img, "wind_leaf/chime.png")


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
    """A top-down tree that reads as a tree.

    The old one filled the canopy with grass_dark over hedge -- both nearly
    black -- and baked a shadow ellipse into the sprite. On a green bank it
    read as a stain, which is exactly what Neo saw. This one is lit from the
    top left, keeps the darkest tone to a thin rim, and carries no shadow:
    the scene draws that separately so it can sit on the ground beside the
    trunk rather than inside the sprite.
    """
    import math as _m
    W = H = 40
    img, d = canvas(W, H)
    cx, cy, r = 20.0, 19.0, 17.0

    # A soft cast shadow on the ground, offset away from the light, drawn
    # before anything else. This is what makes the tree sit ON the bank
    # rather than float as a sticker.
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx - 3.5) / 17.0, (y - cy - 6.0) / 9.0
            dist = _m.sqrt(dx * dx + dy * dy)
            if dist < 1.0:
                img.putpixel((x, y), (18, 34, 22, int(86 * (1.0 - dist) ** 0.6)))

    # Trunk, so the canopy overlaps it.
    d.rectangle([18, 22, 21, 35], fill=P["wood_dark"])
    d.rectangle([18, 22, 19, 35], fill=P["wood"])

    # These have to separate from the BANK, which is P["grass"] (74,122,60).
    # The first attempt used that exact value for canopy_mid, so the tree
    # vanished into the ground it was standing on -- the opposite failure to
    # the near-black blob it replaced, and just as unreadable.
    canopy_rim = (40, 76, 42, 255)
    canopy_mid = (96, 146, 70, 255)
    canopy_lit = (134, 182, 86, 255)
    canopy_hot = (176, 212, 112, 255)

    for y in range(H):
        for x in range(W):
            dx, dy = x - cx, y - cy
            dist = _m.sqrt(dx * dx + dy * dy)
            # A lumpy outline, so it is a crown and not a ball.
            lump = r + 2.2 * _m.sin(_m.atan2(dy, dx) * 5.0) \
                     + 1.4 * _m.sin(_m.atan2(dy, dx) * 9.0 + 1.1)
            if dist > lump:
                continue
            if dist > lump - 2.0:
                img.putpixel((x, y), canopy_rim)
                continue
            # Light from the top left.
            shade = (-dx - dy) / (r * 1.6) + 0.5
            if shade > 0.74:
                img.putpixel((x, y), canopy_hot)
            elif shade > 0.48:
                img.putpixel((x, y), canopy_lit)
            else:
                img.putpixel((x, y), canopy_mid)

    # A few darker gaps so the canopy has some texture rather than banding.
    rng = random.Random(4400)
    for _ in range(26):
        x, y = rng.randrange(W), rng.randrange(H)
        if img.getpixel((x, y))[3] == 0:
            continue
        img.putpixel((x, y), canopy_mid if rng.random() < 0.5 else canopy_rim)
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

    img, d = canvas(9, 9)                                   # leaf (vitality)
    # One leaf rather than a two-leaf sprout: at nine pixels the sprout's
    # stem and two tiny flags came out looking like an aerial.
    d.polygon([(8, 0), (8, 5), (6, 7), (3, 7), (1, 5), (1, 3)], fill=W)
    d.line([(0, 8), (7, 1)], fill=(28, 26, 38, 255))
    save(img, "ui/icon_leaf.png")

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

    # A soft round glint for the water. The sparkle above is a hard plus sign
    # and on the river it read as a crosshair, not a highlight.
    img, d = canvas(6, 4)
    d.ellipse([0, 1, 5, 2], fill=(226, 244, 252, 210))
    d.point((2, 1), (255, 255, 255, 255))
    d.point((3, 2), (255, 255, 255, 255))
    save(img, "decor/glint.png")

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
    # P["hedge"] (43,78,42) is nearly black against the water; these sat on
    # the bank looking like scratches. Lit stalks, darker only on one side.
    for x, lean, tone in ((5, -2, (86, 134, 62)), (8, 1, (104, 156, 72)),
                          (11, -1, (72, 116, 54))):
        d.line([(x, 39), (x + lean, 6)], fill=(*tone, 255), width=2)
        d.line([(x + 1, 39), (x + lean + 1, 7)], fill=(58, 96, 48, 255))
        d.ellipse([x + lean - 2, 2, x + lean + 2, 9], fill=(170, 134, 72, 255))
        d.ellipse([x + lean - 1, 3, x + lean + 1, 6], fill=(206, 172, 96, 255))
    save(img, "decor/reed.png")

    # --- what a current actually carries ---------------------------------
    # The lily pads that used to live here were static dark-green blobs in
    # open water. Lily pads grow in still water, and these competed with the
    # leaves you stand on. Replaced with three things a river would carry,
    # all of which drift and so reinforce the current instead of denying it.

    img, d = canvas(20, 6)                                  # foam streak
    for x in range(20):
        t = 1.0 - abs(x - 9.5) / 9.5
        a = int(150 * t ** 0.7)
        d.point((x, 2), (*P["foam"][:3], a))
        if rng.random() < 0.55:
            d.point((x, 1 + rng.randrange(0, 3)), (*P["foam"][:3], a // 2))
    save(img, "decor/foam.png")

    img, d = canvas(30, 3)                                  # speed streak
    # Longer and thinner than the foam: at speed these are drawn stretched
    # and in numbers, which is the 2D version of the speed lines a racing
    # game draws when the world starts going past quickly.
    for x in range(30):
        t = 1.0 - abs(x - 14.5) / 14.5
        a = int(190 * t ** 0.6)
        d.point((x, 1), (*P["foam"][:3], a))
        if 6 < x < 23:
            d.point((x, 0), (*P["foam"][:3], a // 3))
    save(img, "decor/streak.png")

    img, d = canvas(14, 6)                                  # twig
    d.line([(0, 4), (13, 2)], fill=(104, 78, 48, 255))
    d.line([(0, 5), (13, 3)], fill=(74, 54, 34, 255))
    d.line([(6, 3), (9, 0)], fill=(104, 78, 48, 255))
    save(img, "decor/twig.png")

    img, d = canvas(10, 8)                                  # fallen leaf
    d.polygon([(5, 0), (9, 4), (5, 7), (1, 4)], fill=(178, 142, 64, 255))
    d.polygon([(5, 1), (7, 4), (5, 6)], fill=(214, 180, 92, 255))
    d.line([(2, 4), (8, 4)], fill=(120, 92, 44, 255))
    save(img, "decor/driftleaf.png")

    img, d = canvas(16, 10)                                 # dragonfly
    # Was a grey-blue smear that read as dirt floating on the river. The body
    # is now bright and saturated and the wings are paler than the water
    # behind them, so it reads as a thing in the air rather than a stain.
    for wx in (6, 9):
        d.ellipse([wx, 0, wx + 5, 4], fill=(236, 250, 255, 120))
        d.ellipse([wx, 5, wx + 5, 9], fill=(236, 250, 255, 120))
    d.line([(3, 5), (13, 5)], fill=(72, 196, 214, 255))
    d.line([(3, 4), (11, 4)], fill=(140, 240, 250, 255))
    d.ellipse([1, 3, 5, 7], fill=(120, 230, 240, 255))
    d.point((2, 4), (255, 255, 255, 255))
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


# ---------------------------------------------------------------- hush meadow

def _hush_floor_v1(rng):
    """Hush Meadow's first floor, shade, cover disc and clumps. Writes nothing.

    Kept for the same two reasons as _acorn_floor_v1(): it is the record of
    what noise looks like -- 2,100 single-pixel blades (mean run 1.8 px), and a
    cover disc airbrushed through 208 alpha levels (1.7 px) -- and the hedge is
    drawn after it from the same random stream. Its names are not in KEEP.
    """
    import math as _m
    # Cooler and bluer than Acorn Storm's clearing on purpose. Two games on
    # mown green at 480px wide would read as the same place.
    MEADOW      = (62, 108, 72, 255)
    MEADOW_DARK = (44, 84, 58, 255)
    MEADOW_LIT  = (88, 140, 88, 255)
    STEM        = (74, 124, 70, 255)
    # Well below MEADOW_DARK (44, 84, 58). At its first value it was within a
    # few points of the ground tone and the clump had no base at all -- and
    # the dark gap between stems is the entire reason a clump reads as
    # something you can be inside rather than a smear on the grass.
    STEM_DARK   = (22, 46, 32, 255)
    STEM_LIT    = (132, 178, 104, 255)
    SEEDHEAD    = (198, 206, 140, 255)

    # --- the meadow floor -------------------------------------------------
    # 176px against the shade layer's 240, and the two scroll at different
    # rates. Different size AND different speed is the thing that actually
    # kills a grid; a bigger tile on its own only makes the grid bigger.
    W = H = 176
    img, _ = canvas(W, H, MEADOW)
    px = img.load()

    def soft_patch(cx, cy, r, colour, strength):
        for y in range(-r, r + 1):
            for x in range(-r, r + 1):
                d2 = (x * x + y * y) / float(r * r)
                if d2 >= 1.0:
                    continue
                if rng.random() > strength * (1.0 - d2):
                    continue
                px[(cx + x) % W, (cy + y) % H] = colour

    for _ in range(16):
        soft_patch(rng.randrange(W), rng.randrange(H), rng.randrange(20, 44),
                   MEADOW_DARK, 0.5)
    for _ in range(13):
        soft_patch(rng.randrange(W), rng.randrange(H), rng.randrange(16, 36),
                   MEADOW_LIT, 0.45)

    # Blades: short upright strokes, no mark long enough for the eye to match
    # across a seam. Denser than the clearing's -- this is unmown meadow.
    for _ in range(2100):
        x, y = rng.randrange(W), rng.randrange(H)
        length = rng.randrange(1, 5)
        lean = rng.choice((-1, 0, 0, 1))
        tone = MEADOW_LIT if rng.random() < 0.5 else MEADOW_DARK
        for i in range(length):
            px[(x + lean * i) % W, (y - i) % H] = tone

    # Flowers, a few. They are the thing that says "meadow" rather than
    # "lawn", and they are single pixels so they cannot form a pattern.
    # Dimmer and fewer than the first pass, which put 150 near-white pixels on
    # the field and made the meadow look like a star chart.
    for _ in range(80):
        x, y = rng.randrange(W), rng.randrange(H)
        px[x, y] = rng.choice((
            (186, 192, 152, 255), (176, 164, 184, 255), (196, 186, 132, 255)))
    save(img, "hush_meadow/meadow_v1.png")

    # --- the shade layer --------------------------------------------------
    # Cloud shadow crossing the meadow. Kept light: the game's readability
    # rests on seeing where the grass patches are, and a dark soup over the
    # top of them costs exactly the thing the player needs.
    DW = DH = 240
    field = [[0.0] * DW for _ in range(DH)]
    for _ in range(20):
        cx, cy = rng.randrange(DW), rng.randrange(DH)
        radius = rng.randrange(34, 84)
        weight = rng.uniform(-1.0, 1.0)
        for y in range(-radius, radius + 1):
            for x in range(-radius, radius + 1):
                d2 = (x * x + y * y) / float(radius * radius)
                if d2 >= 1.0:
                    continue
                field[(cy + y) % DH][(cx + x) % DW] += weight * (1.0 - d2) ** 2
    peak = max(abs(v) for row in field for v in row) or 1.0
    img, _ = canvas(DW, DH)
    for y in range(DH):
        for x in range(DW):
            v = field[y][x] / peak
            colour = (232, 242, 210) if v >= 0 else (24, 42, 30)
            a = abs(v) * (24 if v >= 0 else 30)
            if a < 2.0:
                continue
            img.putpixel((x, y), (*colour, int(a)))
    save(img, "hush_meadow/meadow_shade_v1.png")

    # --- the cover disc ---------------------------------------------------
    # White, so the game tints it. Soft-edged so overlapping clumps merge into
    # one patch instead of showing their seams.
    #
    # A plain radial falloff was the first attempt and it was a mistake: it
    # peaks at one pixel in the middle and fades the whole way out, so the
    # patch has no EDGE, and where the patch ends is the only thing about it
    # the player actually needs to know. This is flat across the middle and
    # then drops off fast, which gives the boundary something to be.
    CW, CH = 64, 44
    img, _ = canvas(CW, CH)
    px = img.load()
    PLATEAU = 0.52
    for y in range(CH):
        for x in range(CW):
            dx = (x + 0.5 - CW / 2.0) / (CW / 2.0)
            dy = (y + 0.5 - CH / 2.0) / (CH / 2.0)
            dist = _m.sqrt(dx * dx + dy * dy)
            if dist >= 1.0:
                continue
            a = 1.0 if dist <= PLATEAU else \
                (1.0 - (dist - PLATEAU) / (1.0 - PLATEAU)) ** 1.1
            px[x, y] = (255, 255, 255, int(a * 255))
    save(img, "hush_meadow/grass_cover_v1.png")

    # --- three grass clumps -----------------------------------------------
    # 28 x 34: taller than wide, which is most of why it reads as standing up.
    for variant in range(3):
        GW, GH = 28, 34
        img, _ = canvas(GW, GH)
        px = img.load()
        base_y = GH - 3
        stems = 13 + variant * 2

        # The dark base first -- the gap between stems, which is the part that
        # says "you could be in there".
        for y in range(GH - 11, GH):
            for x in range(GW):
                dx = (x + 0.5 - GW / 2.0) / (GW / 2.0 - 1.0)
                dy = (y - (GH - 11)) / 11.0
                if dx * dx + (1.0 - dy) * (1.0 - dy) * 0.5 > 1.0:
                    continue
                if rng.random() < 0.34:
                    continue
                px[x, y] = STEM_DARK

        # Then the stems, fanning out, with a lit tip on most of them. Heights
        # vary a lot on purpose: an even top edge reads as a hedge.
        for i in range(stems):
            spread = (i / float(stems - 1)) * 2.0 - 1.0
            x0 = int(GW / 2 + spread * (GW / 2 - 3) * rng.uniform(0.55, 1.0))
            height = int(rng.uniform(0.45, 1.0) * (GH - 6))
            lean = spread * rng.uniform(0.10, 0.34)
            for step in range(height):
                x = int(round(x0 + lean * step))
                y = base_y - step
                if not (0 <= x < GW and 0 <= y < GH):
                    continue
                near_tip = step > height - 4
                px[x, y] = STEM_LIT if near_tip else (
                    STEM if rng.random() < 0.72 else STEM_DARK)
            # A seedhead on some, which is the detail that reads at 3x.
            if rng.random() < 0.45:
                tx = int(round(x0 + lean * height))
                ty = base_y - height
                for oy in range(-2, 1):
                    if 0 <= tx < GW and 0 <= ty + oy < GH:
                        px[tx, ty + oy] = SEEDHEAD
        save(img, "hush_meadow/grass_v1_%d.png" % variant)


def hush_meadow_ground():
    """The meadow, its cloud shadow, and the cover a patch is built from.

    Cooler and bluer than Acorn Storm's clearing, and UNMOWN: taller fan tufts
    and a scatter of flowers, each a deliberate two-by-two bud rather than a
    lone bright pixel. The first pass put 150 near-white single pixels on the
    field and it looked like a star chart; these are dim and few for the same
    reason.

    And NOT crosses. They were five-pixel plus signs for one round, and in a
    capture the meadow was sprinkled with small copies of the dew mote -- a
    four-point sparkle whose whole job is to say "dew is in this patch" from
    across the field. On this ground a cross means that and nothing else.

    176px floor under a 240px shade layer, scrolling at different rates, so
    the two periods never line up -- hush_test.gd asserts both halves of that.
    """
    fans = [
        ["h.h.h", ".sss."],
        [".h.h.", "h.s.h", ".sss."],
        ["h..h", ".ss."],
        ["h...h", ".h.h.", "..s.."],
        [".h..", "h.h.", ".ss."],
        ["..h.", ".h.h", ".ss."],
    ]
    flowers = [{"p": (186, 192, 152, 255), "c": (214, 196, 128, 255)},
               {"p": (176, 164, 184, 255), "c": (214, 196, 128, 255)}]
    img = retro_ground(
        7800, 176,
        zones=[(55, 99, 67, 255), (62, 108, 72, 255), (70, 118, 78, 255)],
        ink={"s": (42, 80, 56, 255), "h": (98, 148, 94, 255)},
        cuts=(-0.30, 0.18), tufts=fans, tuft_count=200,
        extras=[(["pp", "cp"], 9, flowers)])
    save(img, "hush_meadow/meadow.png")

    # Cloud shadow. Kept light: the game rests on seeing where the patches
    # are, and a dark soup over them costs exactly what the player needs.
    img = shade_layer(
        7850, 240, lit=(232, 242, 210), dark=(24, 42, 30),
        lit_alpha=(14, 24), dark_alpha=(18, 32), cuts=(0.28, 0.58), band=0.035,
        octaves=[(20, 34, 84, 1.0), (14, 12, 26, 0.25)], stretch=1.4)
    save(img, "hush_meadow/meadow_shade.png")

    # --- the cover disc ---------------------------------------------------
    # White, so the game tints it, and drawn slightly SMALLER than the
    # concealment rect (PATCH_HALF in patch.gd): anywhere that looks like
    # cover has to BE cover.
    #
    # Where the patch ENDS is the only thing about it the player needs to
    # know, so this is a hard-edged ellipse: solid to 80% of the radius, then
    # a rim dithered with the Bayer pattern from full to nothing. Two alpha
    # levels, 0 and 255. The version before was a radial airbrush through 208
    # of them, which had no edge at all and read as a photograph's shadow.
    CW, CH = 64, 44
    CORE = 0.80
    img, _ = canvas(CW, CH)
    px = img.load()
    for y in range(CH):
        for x in range(CW):
            dx = (x + 0.5 - CW / 2.0) / (CW / 2.0)
            dy = (y + 0.5 - CH / 2.0) / (CH / 2.0)
            dist = (dx * dx + dy * dy) ** 0.5
            if dist >= 1.0:
                continue
            if dist <= CORE or 1.0 - (dist - CORE) / (1.0 - CORE) > bayer(x, y):
                px[x, y] = (255, 255, 255, 255)
    save(img, "hush_meadow/grass_cover.png")

    # --- three grass clumps -----------------------------------------------
    # 28 x 34, taller than wide, which is most of why it reads as growth
    # standing up rather than a stain on the ground. hush_test.gd measures the
    # concealment rect against this size, so it does not change.
    #
    # Built from a few WIDE blades -- six pixels at the root, never under two
    # at the tip -- over one solid body, not thirteen one-pixel stems. Every
    # blade edge costs two colour changes per row, and the stem version spent
    # them so freely it measured 2.0 px, the grain of static. What says "you
    # could be in there" now is the dark skirt along the root, and the dark
    # cover disc the game lays under every patch.
    #
    # Seed chosen from a handful for all three clearing 6 px; the structure is
    # what moved them there from 2, the seed only picks among its results.
    STEM_DARK = (22, 46, 32, 255)
    STEM      = (74, 124, 70, 255)
    STEM_BACK = (52, 94, 56, 255)
    STEM_LIT  = (132, 178, 104, 255)
    SEEDHEAD  = (198, 206, 140, 255)
    GW, GH = 28, 34
    rng = random.Random(7792)

    def blade(px, x0, base_y, width, height, lean, colour, tip):
        """Tapered, solid, and never narrower than two pixels: a SHAPE."""
        for step in range(height):
            t = step / float(max(height - 1, 1))
            w = max(2, int(round(width * (1.0 - t * 0.75))))
            left = int(round(x0 + lean * t - w / 2.0))
            y = base_y - step
            for x in range(left, left + w):
                if 0 <= x < GW and 0 <= y < GH:
                    px[x, y] = tip if step >= height - 3 else colour

    for variant in range(3):
        img, _ = canvas(GW, GH)
        px = img.load()
        base_y = GH - 4

        # The dark root: a skirt along the bottom, wider than the blades, so
        # the clump stands IN something. The blades cover all but its rim.
        for y in range(GH - 5, GH - 1):
            half = (GW / 2.0 - 1.0) * (0.78 + 0.22 * (y - (GH - 5)) / 3.0)
            for x in range(GW):
                if abs(x + 0.5 - GW / 2.0) <= half:
                    px[x, y] = STEM_DARK

        # The back row, fanning out. Heights vary a lot on purpose: an even
        # top edge reads as a hedge.
        blades = []
        count = (4, 5, 4)[variant]
        for i in range(count):
            spread = (i / float(count - 1)) * 2.0 - 1.0
            x0 = GW / 2.0 + spread * (GW / 2.0 - 5) * rng.uniform(0.7, 1.0)
            height = int(rng.uniform(0.55, 1.0) * (GH - 6))
            lean = spread * rng.uniform(2.0, 6.0)
            blades.append((x0, height, lean))
        for x0, height, lean in blades:
            blade(px, x0, base_y, 6, height, lean, STEM_BACK, STEM_BACK)

        # Below where the blades part, the stand is one solid body -- a mass,
        # not a row of sticks -- so the only gaps are up where the tips fan.
        for y in range(base_y - 9, base_y + 1):
            row = [x for x in range(GW)
                   if px[x, y][3] > 0 and px[x, y] != STEM_DARK]
            if row:
                for x in range(min(row), max(row) + 1):
                    px[x, y] = STEM_BACK

        # Two front blades, one each side, so the lit tips frame the clump
        # rather than speckling it.
        for x0, height, lean in (blades[0], blades[-1]):
            short = int(height * rng.uniform(0.6, 0.85))
            blade(px, x0 + rng.choice((-1, 1)), base_y + 1, 6, short,
                  lean * 0.8, STEM, STEM_LIT)

        # One seedhead, on the tallest: the detail that reads at 3x.
        x0, height, lean = max(blades, key=lambda b: b[1])
        tx, ty = int(round(x0 + lean)), base_y - height + 1
        for oy in (-1, 0):
            for ox in (-1, 0):
                if 0 <= tx + ox < GW and 0 <= ty + oy < GH:
                    px[tx + ox, ty + oy] = SEEDHEAD

        despeckle(img, wrap=False)
        save(img, "hush_meadow/grass_%d.png" % variant)


def hush_meadow_art():
    """Hush Meadow: a meadow that scrolls past you, and the cover growing in it.

    The sprite that has to work here is the grass clump, because the player's
    entire survival is the question "am I inside a patch". A clump has to read
    as something you can be INSIDE, seen from directly above, which is not
    what a handful of blades does on its own. Three things together get there:

      * it is taller than it is wide, so it reads as growth standing up rather
        than as a stain on the ground
      * the base is dark. The shadow between stems is the cue that there is a
        gap down there big enough to stand in
      * the silhouette is ragged, because a smooth oval is a bush, and a bush
        is a thing you walk around rather than into

    Under every clump the game also lays `grass_cover.png`, a hard-edged dark
    ellipse. The parked version borrowed `village/glow.png` for this and it is
    worth drawing on purpose: blades over green do not read as cover by
    themselves, and a hiding place the player cannot see is worse than no
    hiding place at all. It is drawn white so the game can tint it, and it is
    drawn slightly SMALLER than the concealment rect the game uses -- see
    PATCH_HALF in hush_meadow.gd. Anywhere that looks like cover has to BE
    cover; the reverse is a game that lies to you at the only moment it
    matters.

    The floor, shade, cover disc and clumps are drawn in hush_meadow_ground();
    what is left here is the objects, which already had pixel-art grain.
    """
    import math as _m
    rng = random.Random(7700)

    # --- the floor, its shade, the cover disc and the clumps --------------
    # Redrawn at retro grain in hush_meadow_ground(). The first versions still
    # RUN, because the hedge below is drawn from this same random stream:
    # skip their draws and it silently re-randomises.
    _hush_floor_v1(rng)

    # --- the patrol bird --------------------------------------------------
    # Drawn NOSE-UP, because PatrolBird._apply_facing() rotates from -Y.
    #
    # Facing has to be legible at a glance: this is a stealth game and which
    # way a bird is looking is the single most important fact on the screen.
    # So the head end carries two cues that the tail end cannot -- a pale head
    # and a bright beak -- rather than relying on the silhouette, which at 18
    # pixels is nearly symmetrical either way round.
    for frame in range(2):
        BW, BH = 20, 22
        img, d = canvas(BW, BH)
        lift = 0 if frame == 0 else 3          # wings up, then level
        d.polygon([(10, 3), (14, 9), (12, 19), (8, 19), (6, 9)],
                  fill=P["bird"])                              # body
        # Wings, swept back. The two frames differ only in how far down the
        # tips sit, so nothing translates and the flap cannot read as a jitter.
        d.polygon([(7, 8), (1, 11 + lift), (2, 14 + lift), (8, 13)],
                  fill=P["bird_light"])
        d.polygon([(13, 8), (19, 11 + lift), (18, 14 + lift), (12, 13)],
                  fill=P["bird_light"])
        d.polygon([(8, 18), (10, 21), (12, 18)], fill=P["bird"])   # tail
        d.ellipse([7, 1, 12, 7], fill=(146, 152, 176, 255))        # pale head
        d.polygon([(10, 0), (8, 3), (12, 3)], fill=P["beak"])      # beak
        d.point((8, 4), P["ink"])
        d.point((11, 4), P["ink"])
        save(img, "hush_meadow/bird_%d.png" % frame)

    # --- dew, and the golden one ------------------------------------------
    # Cool blue-white, deliberately outside the gold vocabulary the other two
    # games use: Riverleap's chimes are pale and Acorn Storm's sunfruit is
    # gold, so a third warm pickup would read as one of theirs.
    def droplet(bulb, mid, rim, glint):
        DWW, DHH = 11, 14
        img, d = canvas(DWW, DHH)
        d.polygon([(5, 0), (2, 7), (8, 7)], fill=bulb)        # the point
        d.ellipse([1, 4, 9, 13], fill=bulb)                   # the bulb
        d.ellipse([2, 6, 7, 11], fill=mid)
        d.ellipse([3, 7, 5, 9], fill=rim)                     # highlight
        if glint:
            # Four points, the same cue the other prizes carry. Same
            # silhouette as ordinary dew -- telling it apart is a glance, not
            # a different object, exactly as the golden acorn works.
            px = img.load()
            for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
                for step in range(1, 4):
                    x, y = 5 + dx * step, 8 + dy * step * 1.1
                    x, y = int(x), int(y)
                    if 0 <= x < DWW and 0 <= y < DHH and px[x, y][3] == 0:
                        px[x, y] = (255, 246, 206, int(230 - step * 56))
        return img

    save(droplet((142, 196, 224, 255), (196, 228, 244, 255),
                 (246, 253, 255, 255), False), "hush_meadow/dew.png")
    save(droplet((206, 158, 52, 255), (244, 206, 96, 255),
                 (255, 246, 198, 255), True), "hush_meadow/dew_gold.png")

    # --- petal, the open-ground pickup ------------------------------------
    PW, PH = 11, 11
    img, d = canvas(PW, PH)
    d.polygon([(5, 0), (9, 4), (7, 10), (3, 10), (1, 4)], fill=P["petal"])
    d.polygon([(5, 2), (7, 5), (5, 8), (3, 5)], fill=(255, 244, 206, 255))
    save(img, "hush_meadow/petal.png")

    # --- sight blockers ---------------------------------------------------
    # Hedges and rocks are what _line_blocked() samples against, so they have
    # to look solid: something you cannot see past has to look like something
    # you cannot see past, or being safe feels arbitrary.
    HW, HH = 30, 22
    img, d = canvas(HW, HH)
    d.ellipse([0, 5, HW - 1, HH - 1], fill=(30, 58, 34, 255))
    d.ellipse([2, 2, HW - 5, HH - 5], fill=P["hedge"])
    px = img.load()
    for _ in range(170):
        x, y = rng.randrange(HW), rng.randrange(HH)
        if px[x, y][3] == 0:
            continue
        px[x, y] = (58, 100, 54, 255) if rng.random() < 0.6 else (34, 64, 38, 255)
    for _ in range(14):
        x, y = rng.randrange(3, HW - 3), rng.randrange(2, 9)
        px[x, y] = (214, 206, 162, 255)          # a few pale buds on top
    save(img, "hush_meadow/hedge.png")

    RW, RH = 24, 18
    img, d = canvas(RW, RH)
    d.ellipse([0, 5, RW - 1, RH - 1], fill=P["rock_dark"])
    d.ellipse([1, 2, RW - 5, RH - 5], fill=P["rock"])
    d.ellipse([5, 4, RW - 12, RH - 10], fill=(148, 148, 158, 255))
    save(img, "hush_meadow/rock.png")

    # --- the "something is in here" mote ----------------------------------
    # Drawn white so the game tints it: cool for dew, gold for the prize.
    #
    # It started as decor/glint.png, which is a horizontal streak, and on a
    # real frame it read as a stray UI line sitting on the grass rather than
    # as something to go and get. A four-point sparkle is the shape every
    # other "this is worth having" cue in the project already uses.
    MW = MH = 11
    img, _ = canvas(MW, MH)
    px = img.load()
    c = (MW - 1) / 2.0
    for y in range(MH):
        for x in range(MW):
            dx, dy = x - c, y - c
            dist = _m.sqrt(dx * dx + dy * dy)
            if dist <= 1.4:
                px[x, y] = (255, 255, 255, 255)
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        for step in range(2, 6):
            x, y = int(c + dx * step), int(c + dy * step)
            if 0 <= x < MW and 0 <= y < MH:
                px[x, y] = (255, 255, 255, int(250 - (step - 2) * 55))
    save(img, "hush_meadow/mote.png")

    # --- the nerve meter's icon -------------------------------------------
    # An eye, because what the bar measures is being looked at.
    WHITE = (255, 255, 255, 255)
    img, d = canvas(9, 9)
    d.polygon([(0, 4), (4, 1), (8, 4), (4, 7)], fill=WHITE)
    d.ellipse([3, 3, 5, 5], fill=(28, 26, 38, 255))
    save(img, "ui/icon_eye.png")


def main() -> None:
    water_tiles(); bank_edge(); ripple()
    lotus_pads(); chime(); hazards()
    village_tiles(); tree(); treeline()
    ui_bits(); hud_icons(); heart_segments(); alarm_frame(); vignette(); scrim()
    player_jump_frames(); control_pictograms(); acorn_storm_art()
    golden_prize(); hush_meadow_art()
    acorn_storm_ground(); hush_meadow_ground()
    decor_motes(); decor_props()
    made = sorted(p.relative_to(OUT).as_posix() for p in OUT.rglob("*.png"))
    print(f"assets/game now holds {len(made)} sprites")


if __name__ == "__main__":
    main()
