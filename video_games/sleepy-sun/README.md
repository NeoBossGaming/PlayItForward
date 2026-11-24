# Sleepy Sun

The first adventure for the **Play It Forward** charity arcade cabinet, built in
Godot 4.7 for a Raspberry Pi 4/5.

**Right now this project is three games.** Four earlier rounds built eight
minigames and a whole cabinet shell around them; none of them got finished
properly, because the work was always split eight ways. So it was stripped back
to one, and games return **one at a time, each polished until it is genuinely
good**: **Riverleap**, then **Acorn Storm**, then **Hush Meadow**. Everything
still parked is in `main`'s history and listed at the end of
[`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

```bash
godot --path .              # play -- boots straight into Riverleap
godot --path . --editor     # edit
tools/run_tests.sh          # headless soak suites, one per game
```

There is no menu, by choice. The cabinet shell that picked games is parked, so
**F4 cycles between them** while you play — a debug key, not a picker, and inert
in an exported build. To open one directly:

```bash
godot --path . src/minigames/acorn_storm/acorn_storm.tscn
```

**Debug keys**, in debug builds only: **F5** restarts instantly, **F4** switches
to the next game, **F3** toggles slow motion.

## Riverleap — *hop*

The sun slept through the dawn, and it has always woken to the river chimes. The
wind has stopped, so somebody has to cross and ring them by hand.

Five leaves ride a river that never ends, and you hop between them for as long
as you can hold on. A pad that shakes is about to sink — telegraphed three ways
at once, because this has to read on a scuffed screen from a few feet back. Pads
always come back, so the row can never be wiped out. Hornets fly at you (jump
them) and herons dive (jumping will not help; move). The river takes all five
lives and the run is over.

**Controls** — stick or arrows/WASD plus the button to hop left and right;
button alone jumps on the spot. That is the whole game.

The river turns personal: early on your own pad is as likely to sink as any
other, and by the end two sinks in three are the one you are standing on.

## Acorn Storm — *dodge, catch*

Stand in a clearing under an oak in a gale. Things fall out of the canopy.

**The vitality bar never stops falling** — slowly at first, fast enough to empty
in twelve seconds by the end — and sunfruit is the only thing that fills it. A
hot ticked **ring** on the grass means an acorn is coming; a filled gold **disc**
means sunfruit. The two differ by shape before colour, so they separate at a
glance and in greyscale. Acorns aim at where you will be, so standing still goes
from unwise to fatal.

**Controls** — stick or arrows/WASD to move, button to sprint.

As the gale builds, things fall faster, land further away, *and you move
quicker* — so the clearing stays worth crossing instead of shrinking to a
shuffle.

## Hush Meadow — *forage*

A meadow that slides down the screen and off the bottom while you work it —
and carries you with it, so standing still drifts you toward the bottom edge,
where your nerve goes fast. Walk against it. Tall grass hides you completely; **dew only appears once you are standing
inside a patch**, and dew is the only thing that calms your nerve. So cover is
somewhere to go rather than somewhere to hide — and the patch you are hiding
in is already on its way off the screen.

Birds patrol with a visible cone of sight. Being seen is expensive rather than
fatal. The run ends when your nerve runs out, and the meadow gets harder as it
goes: it moves faster, its cover grows further apart, and there are five pairs
of eyes where there was one.

**Controls** — stick or arrows/WASD to move, button to sprint. Sprinting is
fast, costs stamina, and is loud enough that a bird will come and look.

## All three games

Every run ends with a **letter** — D through SS — stamped next to the score.
It is cut from a shared 0–1000 scale, so a grade means the same thing in every
game: a par run is a B, a good one an A.

About **one run in ten** also turns up a **golden prize** — a golden chime in
Riverleap, a golden acorn in Acorn Storm, a golden dew in Hush Meadow. The
acorn one deliberately looks
much like the thing that hurts you — spotting it is part of the challenge,
though the mark on the ground always tells you the truth. It scores nothing
and nothing depends on it yet; it is counted and saved, and what it unlocks is
still to be decided.

**Fonts** — Press Start 2P and Pixelify Sans, both under the SIL Open Font
License; the licence files ship beside them in `assets/game/fonts/`.

## Documentation

- [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) — the premise, the technical
  baseline, what every game inherits, a section per game, testing, and the
  full list of what is parked and where to find it.
- [`docs/ASSET_REQUESTS.md`](docs/ASSET_REQUESTS.md) — the art still to draw,
  with exact sizes. Everything on that list ships as a placeholder today.

**Art pipeline** — `tools/normalize_assets.py` recovers true-resolution copies
from hugely upscaled hand-drawn exports; `tools/make_placeholders.py` fills the
gaps. Both need `pillow`; their outputs are committed, so neither is needed just
to open the project.
