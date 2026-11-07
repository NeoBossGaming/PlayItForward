# Sleepy Sun

The first adventure for the **Play It Forward** charity arcade cabinet, built in
Godot 4.6 for a Raspberry Pi 4/5.

**Right now this project is one game.** Four earlier rounds built eight
minigames and a whole cabinet shell around them; none of them got finished
properly, because the work was always split eight ways. So it is stripped back
to **Riverleap**, which gets polished until it is genuinely good before anything
else returns. Everything parked is in `main`'s history and listed at the end of
[`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

```bash
godot --path .              # play -- boots straight into the game
godot --path . --editor     # edit
tools/run_tests.sh          # headless soak suite
```

**Controls** — stick or arrows/WASD to hop left and right. That is the whole
game.

**Debug keys**, in debug builds only: **F5** restarts instantly, **F3** toggles
slow motion.

## Riverleap

The sun slept through the dawn, and it has always woken to the river chimes. The
wind has stopped, so somebody has to cross and ring them by hand.

Five leaves drift downstream and you hop between them for about a minute. A leaf
that shakes is about to sink — telegraphed three ways at once, because this has
to read on a scuffed screen from a few feet back. Leaves always come back, so
the row can never be wiped out, and **you cannot lose**: going in the water
costs points and a second and a half, never the run. Chimes float past and chain
up to ×5; splashing costs the chain as well as the points.

**Fonts** — Press Start 2P and Pixelify Sans, both under the SIL Open Font
License; the licence files ship beside them in `assets/game/fonts/`.

## Documentation

- [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) — the premise, the technical
  baseline, how Riverleap works and where it is weak, testing, and the full list
  of what is parked and where to find it.
- [`docs/ASSET_REQUESTS.md`](docs/ASSET_REQUESTS.md) — the art still to draw,
  with exact sizes. Everything on that list ships as a placeholder today.

**Art pipeline** — `tools/normalize_assets.py` recovers true-resolution copies
from hugely upscaled hand-drawn exports; `tools/make_placeholders.py` fills the
gaps. Both need `pillow`; their outputs are committed, so neither is needed just
to open the project.
