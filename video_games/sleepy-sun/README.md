# Sleepy Sun

The first adventure for the **Play It Forward** charity arcade cabinet: a
slot-machine card draw and eight short minigames, built in Godot 4.6 for a
Raspberry Pi 4/5.

```bash
godot --path .              # play
godot --path . --editor     # edit
tools/run_tests.sh          # headless test suite
```

**Controls** — stick or arrows/WASD to move, `Space` to act, `Enter`/`1` to start,
`5` to insert a credit. One stick and one button run the whole adventure.

**The adventure** — one credit deals you **three games from a pool of eight**,
and you cannot lose it. Press start, the cards spin, and you are playing.

| | |
|---|---|
| **Riverleap** | Hop between drifting leaves. The ones that shake are about to sink. |
| **Hush Meadow** | Gather sunpetals before dusk. Closer to a bird pays more. |
| **Echo Hollow** | Watch the stones light up, then walk the same path back. |
| **Riverstrike** | Fire harpoons straight up. Lead the fish; bottles stop the bolt. |
| **Acorn Storm** | Dodge the falling acorns, catch the sunfruit between them. |
| **Firefly Lantern** | Your light is dying. The darker it gets, the more they pay. |
| **Temple Bell** | Strike on the beat. It only gets faster. |
| **Crow Watch** | Crows are diving on the rice. Scare them off before they land. |

**Documentation**

- [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) — the full design and planning
  document: session shape, architecture, per-minigame rules and tuning tables,
  testing, and the deferred work with its hook points.
- [`docs/ASSET_REQUESTS.md`](docs/ASSET_REQUESTS.md) — the art still to draw,
  with exact sizes. Everything on that list ships as a placeholder today.

**Art pipeline** — hand-drawn source art lives untouched in `assets/`;
`tools/normalize_assets.py` writes game-ready copies into `assets/game/` and
`tools/make_placeholders.py` fills the gaps. Both need `pillow`; their outputs
are committed, so neither is needed just to open the project.
