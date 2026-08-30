# Sleepy Sun

The first adventure for the **Play It Forward** charity arcade cabinet: a
slot-machine card draw and eight short minigames, built in Godot 4.6 for a
Raspberry Pi 4/5.

```bash
godot --path .              # play
godot --path . --editor     # edit
tools/run_tests.sh          # headless test suite
```

**Controls** — stick or arrows/WASD to move, `Space` to act (and to sprint, where
there is a stamina bar), `Enter`/`1` to start, `5` to insert a credit. One stick
and one button run the whole adventure.

**`F3` opens the debug menu** — jump into any game, force the next hand, watch
any cutscene without playing for it, slow motion, clear scores. It only exists in
debug builds, never on the cabinet.

**The adventure** — the sun slept straight through the dawn, and the valley is
doing the waking by hand. One credit deals you **three games from a pool of
eight**, and you cannot lose it. Press start, the cards spin, and you are
playing. Each game brings the sun one thing that might wake it, a short cutscene
either side says what and why, and the ending changes with how the run went.

| | What you do | What it brings the sun |
|---|---|---|
| **Riverleap** | Hop between drifting leaves. The ones that shake are about to sink. | the river chimes |
| **Hush Meadow** | Forage before dusk, then get into cover. Closer to a bird pays more. | a handful of yesterday |
| **Echo Hollow** | Watch the stones light up, then walk the same path back. | the sun's own name |
| **Riverstrike** | Fire harpoons straight up. Lead the fish; bottles stop the bolt. | a river clear enough to look in |
| **Acorn Storm** | Dodge the falling acorns, catch the sunfruit between them. | breakfast |
| **Firefly Lantern** | Your light is dying. The darker it gets, the more they pay. | a borrowed light |
| **Temple Bell** | Strike on the beat, then do it while running for pickups. | the dawn bell |
| **Crow Watch** | Crows are diving on the rice. Scare them off before they land. | the harvest offering |

Cutscenes are skippable with any button after a second, so a repeat player is
never held up by a story they have already seen.

**Fonts** — Press Start 2P and Pixelify Sans, both under the SIL Open Font
License; the licence files ship beside them in `assets/game/fonts/`.

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
