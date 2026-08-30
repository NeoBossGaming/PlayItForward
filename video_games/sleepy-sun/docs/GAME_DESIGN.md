# Sleepy Sun — Design & Planning Document

**Adventure 1 for the Play It Forward arcade cabinet**
Godot 4.6 · GL Compatibility · target hardware Raspberry Pi 4/5

---

## 1. What this is and how it fits the cabinet

The Play It Forward proposal (§2.4.1) describes the whole cabinet experience as
**one** Godot application built around a state machine:

```
Idle / Attract  →  Payment Wait  →  Gameplay  →  Results  →  Idle / Attract
```

One cabinet hosts one **adventure**. *Sleepy Sun* is the first. This document
covers the adventure and the shell around it; it does **not** cover payment,
which is Phase 2 and is deliberately absent from the code (see §11).

What is built today:

```
Boot → Attract → Card draw → game 1 → game 2 → game 3 → Results → Attract
                     ↑ the "Payment Wait" step slots in here
```

`tests/flow_test.gd` asserts that exact loop on every run, which is the
proposal's Phase 1 acceptance criterion — *the full loop plays start to finish
on ordinary hardware, without needing real money to test it*.

---

## 2. Session shape

**One credit deals you three minigames from a pool of eight, and you cannot lose.**

| | |
|---|---|
| Length | roughly 4 minutes |
| Structure | slot-machine card draw, then the three dealt games in order |
| Failure | **none** — mistakes cost score and seconds, never the run |
| Scoring | one total across the three, a rank, and a local high-score table |

### Why a card draw and not a hub

The first build had a village hub you walked around to pick chores. It was
calm, it was slow, and it made four minigames feel like errands. A cabinet in a
mall needs the opposite: a stranger who has just paid should be *playing* within
eight seconds.

So: press start, three cards spin, they stop one at a time, and you are in.
The staggered stop is the whole trick — three simultaneous stops is a random
number, a left-to-right stagger is a slot machine, and the pause before the
last card is where the tension lives.

**The pool is eight so the draw means something.** Drawing 3 of 4 barely
shuffles; 3 of 8 is 56 different hands, and it is why the cabinet is worth a
second credit.

### Why no fail state

The cabinet sits unattended in front of people who have never seen it and have
already paid. A game over thirty seconds in is a machine that took someone's
money and gave them nothing. Every minigame turns failure into a **setback**:
you go back in the water, the pattern replays, you get knocked down for half a
second. The floor is "you finish and score modestly"; the ceiling is where the
skill lives.

`tests/soak_test.gd` proves every game can be completed, every run.

### Scoring must stay on one scale

All eight games are tuned so a strong run lands in the **2,500–4,500** band.
This is not cosmetic. The session total feeds one shared high-score table, so
if one card paid 90,000 and another paid 3,000 the table would only record
which cards you were dealt. An early build of Temple Bell did exactly that
(88,350 against a par of 2,100) and it was caught by measuring the soak test's
bot scores, not by reading the code.

`par_score` is set on each minigame scene at roughly **60 % of a near-perfect
scripted run**. The results rank compares the session total against the sum of
par **for the three cards dealt** (`Game.playlist_par()`) — comparing against
all eight would rank every run GENTLE.

| Rank | Threshold |
|---|---|
| RADIANT | ≥ 1.15 × par |
| BRIGHT | ≥ 0.90 × par |
| WARM | ≥ 0.65 × par |
| GENTLE | below |

---

## 3. The fantasy

The sun is nodding off before it has finished setting, and the evening's chores
are dealt to you three at a time.

Deliberately thin. It exists to give eight unrelated minigames a reason to sit
together and to give the cabinet a mascot whose state is readable at a glance.
No cutscenes, no text anyone has to read.

---

## 4. Technical baseline

| Decision | Value | Why |
|---|---|---|
| Base resolution | **480 × 270** | ×4 is exactly 1080p |
| Stretch | `canvas_items`, `keep`, **integer** | pixel-perfect at any size |
| Texture filter | **Nearest** (project-wide) | it is pixel art |
| Renderer | GL Compatibility | what a Pi 4/5 can drive |
| Player sprite | **1.5×** (≈18 × 43 px) | ~3.8 % of screen width at 480 wide |

**The resolution drop was the second attempt at this.** Round 2 scaled the
sprite 1.5× and kept 640×360; the character still read as too small. The clue
was *"I can't cover a lot of the screen"* — a bigger sprite does not help when
the field is still 640px wide, because crossing it takes exactly as long. So the
whole viewport went to 480×270 and **every play field shrank with it**: Acorn
Storm from 544×232 to 408×174, Crow Watch 528×216 to 396×162, Echo Hollow's
stone ring from radius 56 to 42. Hazard speeds scaled to match so timings feel
identical, but the player's base speed was deliberately held ~20% above a
proportional rescale, so the character covers meaningfully more ground per
second than before.

Fonts scaled by 0.8 rather than 0.75, so text stays comfortably readable at
cabinet distance.

Whenever the cave ring moves, **re-verify it numerically**: the tightest chord
between two stones must clear every other stone by more than the trigger reach
(plate radius + player radius). At radius 42 that is 28.9px against 15px. This
is the check that caught the original unplayable row layout.

### Art pipeline

Every hand-drawn sprite is **32 × 32 pixel art exported at a huge
nearest-neighbour upscale** — up to 4128 × 4128, roughly 68 MB of VRAM for one
frame on a Pi. `tools/normalize_assets.py` recovers the real grid (the upscale
factor is the GCD of the run lengths of identical rows and columns) and writes
true-resolution copies to `assets/game/`. Originals are never touched; each
source folder carries a `.gdignore` so Godot skips the huge versions.

`tools/make_placeholders.py` fills every remaining gap in one dusk palette.
Both scripts' outputs are committed, so opening the project needs no build step
and no Python. **Swapping in real art is a file replacement** — same path, same
dimensions, no code change. See `docs/ASSET_REQUESTS.md`.

### Stamina

Sprinting is a resource in the three games built around getting somewhere in
time (**Hush Meadow**, **Crow Watch**, **Acorn Storm**). It lives on
`TopDownPlayer`, so all three get it from one place.

| | |
|---|---|
| Drain | 0.42/s — about 2.4 s of continuous sprint |
| Regen | 0.30/s — about 3.3 s back to full |
| Recover-to | **0.45** before sprinting is allowed again after bottoming out |

Sprint is a **burst, not the default**: base speed stays walkable so a player
who never sprints can still finish. The recover-to threshold is the part that
matters and it was wrong first time round at 0.15 — the meter refilled past it
in half a second and the player simply stutter-sprinted forever, which is the
exact thing it exists to prevent. It has to be a real rest to be a real
decision. Exactly one of drain or regen runs per frame, so the meter can never
do both at once.

The HUD bar is shown only by those three games, and it is pushed once at start
because `stamina_changed` does not fire while the meter sits full.

### Input

| Action | Keyboard | Joypad | Used for |
|---|---|---|---|
| `move_*` | arrows + WASD | D-pad, stick | walking, hopping, aiming |
| `act` | Space, Enter | A | jump, sprint, fire, strike, confirm |
| `back` | Esc | B | cancel |
| `start` | Enter, `1` | Start | begin a run |
| `insert_credit` | `5` | — | MAME coin key; **the payment hook** |
| `debug_menu` | `F3` | — | the playtest menu, debug builds only |

One stick and one button run all eight games. That is the control panel worth
building: fewer holes to drill, fewer parts to fail unattended.

---

## 5. Architecture

```
src/
├── autoload/   Game (run + playlist), Router (scenes), Audio (synth), Save
├── core/       minigame contract, player controller, scrolling backdrops, timers
├── shell/      boot, attract, draw (the card table), results
├── minigames/  wind_leaf, tall_grass, cave, harpoon,
│               acorn_storm, firefly, temple_bell, crow_watch
└── ui/         the shared HUD
```

### The minigame contract

```gdscript
class_name MiniGame extends Node2D
signal finished(result: MiniGameResult)
@export var id: StringName
@export var par_score: int
func begin() -> void          # Router calls this once the fade-in is done
func finish(score, stats)     # emits `finished`, exactly once, ever
```

A minigame never changes scenes, never writes to `Game`, and does not know the
card table exists. Consequences worth having: every game runs standalone with
**F6**, the tests can instance one in isolation, and `finish()` is idempotent so
a race between "the timer ran out" and "the player reached the goal" cannot
double-report a score.

### Adding a ninth minigame

1. Scene whose root script `extends MiniGame`; set `id` and `par_score`.
2. Instance `src/ui/hud.tscn` and `src/core/player.tscn`.
3. Call `finish(score, stats)` when it ends.
4. One entry in `Game.MINIGAMES`; one `card_icon_<id>.png` in `assets/game/ui/`.
5. A `_detail_for()` case in `results.gd`, and a driver in `soak_test.gd`.

The draw, the attract cards, the results row and all three suites pick it up
from the registry automatically.

### Audio

No `.wav` files ship. `Audio` synthesises every cue at startup — sine, square,
triangle and noise with a fast attack and exponential decay, which reads as a
blip rather than a beep. Fifteen named cues plus five pitched notes for the cave
stones. ~40 ms at boot, nothing at runtime. Replacing it with real samples means
changing the body of `sfx()`; callers stay the same.

---

## 6. The shell

### 6.1 Attract
Dusk village, the mascot dozing, an NPC wandering. Cycles **title → three
random game cards → local high scores**. Eight cards would take 40 seconds to
loop past, which is longer than anyone stands and reads.

**The idle screen is interactive**: the stick makes the sun look that way and
rings the wind chimes, the button rings them and flips the panel. None of it
starts a game. On a public cabinet the first touch is what turns a passer-by
into a player, and a machine that visibly responds before you have paid is a
machine worth paying.

### 6.2 The card table (`src/shell/draw/`)
One scene, two modes:

- **DEAL** — three cards spin through the eight faces and stop left to right.
  A player should catch glimpses of games they want and hope it lands there.
- **ADVANCE** — between games: finished cards stamped with their score, the
  next card flipped up and pulsing, running total. Skippable with the button,
  because a repeat player should never sit through a reveal they understand.

45 seconds of no input anywhere returns the cabinet to attract.

### 6.3 Results
Rows count up, then the total, then a rank stamp. Each row says what happened in
that game's own terms ("4 chimes, 1 splash"). Bottles pulled from the river are
tallied separately, and the last line is the point of the whole machine: *your
credit becomes a donation*. Those few seconds are when someone decides whether
to pay again.

---

## 7. The minigames

All eight are top-down and share one player controller and one sprite set.
Tuning constants live at the top of each script.

### 7.1 Riverleap (`wind_leaf`) — *hop*
Five drifting leaves; cross the river. A leaf's life is
`STABLE → SHAKING → SINKING → GONE → RISING`, and leaves always come back, so
the row can never be wiped out.

**The shake is the game**, so it is telegraphed three redundant ways at once —
an accelerating wobble, a shift toward red, and a widening ripple. Redundant
because it has to read on a scuffed screen, from a few feet back, to someone who
may not separate red from green.

**The director never corners you**: before a leaf is chosen to shake it checks
that a lane reachable in one hop will still be safe.

| Progress | Shake interval | Telegraph | At once |
|---|---|---|---|
| 0–33 % | 2.40 s | 1.10 s | 1 |
| 33–66 % | 1.60 s | 0.80 s | 1–2 |
| 66–100 % | 0.90 s | 0.55 s | 2 |

Hops take 0.26 s plus a 0.10 s cooldown — enough weight that the river cannot be
crossed by drumming the stick, small enough not to feel sticky.

**Chimes chain.** Each is +80 × a multiplier that steps up every two chimes to
×5. Splashing costs 150 points **and** the chain, so going in the water hurts
twice. Chimes always scored; in the first build they had no pickup feedback at
all, which is why they felt like scenery.

### 7.2 Hush Meadow (`tall_grass`) — *forage under threat*

Reworked from an objective run (five sections, one petal each, touch a tree) to
a **timed forage**. The tree was a stop rather than an ending, and one petal per
section turned the whole meadow into a corridor.

Birds patrol with **visible cones of sight**. Detection is a fill, not a
trip-wire, but it is now fast: `ALERT_RISE` 3.2 confirms you in ~0.31 s, down
from ~0.67 s. Being seen is a mistake, not a negotiation.

Grass hides you completely and is slow (50 px/s vs 70 in the open). Sprinting is
fast, costs stamina, and rustles loudly enough that a bird within 72 px breaks
patrol to investigate.

**Three pickups, pulling in three directions:**

| | Value | Why it exists |
|---|---|---|
| Sunpetal | 110 | sits still; what you get for showing up |
| Drifting seed | 200 | moves, so taking one means going where the wind is going |
| Dew | 160 | **invisible until you stand inside a grass patch** |

Dew is the one that does real work. It gives cover a reason to be *entered*
rather than only hidden in, so the cautious route and the greedy route overlap
for the first time.

The **nerve bonus** applies to all three: a pickup taken close to a bird's eye
pays ×2 or ×3. Without it the optimal play is to crawl through grass forever.

**The roost scramble** is the ending. In the last 6 seconds every bird converges
and a `DUSK — GET TO COVER` warning fires; when the bar empties you must be
inside a grass patch or lose 40 % of your haul. It turns the end of a round from
a stop into a decision — one more grab, or get to grass — at exactly the moment
the player is most tempted to push their luck.

Spotted at any point: the bird swoops, you restart the current section, −100.

### 7.3 Echo Hollow (`cave`) — *memorise*
Five chambers of lit stones you walk back with your body, not with buttons.
Each stone has its own colour **and its own note**, so the pattern can be
memorised by ear — players who hum it back do better, and it stays solvable for
someone who cannot separate the colours.

| Chamber | Steps | Lit | Gap |
|---|---|---|---|
| 1 | 3 | 0.60 s | 0.25 s |
| 2 | 4 | 0.52 s | 0.22 s |
| 3 | 5 | 0.45 s | 0.18 s |
| 4 | 6 | 0.38 s | 0.15 s |
| 5 | 7 | 0.32 s | 0.12 s |

**The stones sit in a ring, not a row.** In a row, walking from the far right
stone to the far left drags you across every stone between and each registers
as wrong — unplayable for any sequence that is not left-to-right. This was
caught by `soak_test.gd`, not by inspection. In a ring the path between any two
stones runs through the middle; the tightest chord clears every other stone by
38 px against a 20 px trigger reach.

**Per-step streak scoring**: +12 × a multiplier stepping up every 3 correct
stones to ×5, carried **across chambers** so a clean run compounds. A wrong
stone zeroes the streak and costs 60. Chamber clear +250, flawless +150. Paying
per stone means the score moves while the player is doing something, rather than
every twenty seconds.

Mercy: a second mistake in a chamber replays it at chamber-1 speed.

### 7.4 Riverstrike (`harpoon`) — *shoot*
Rewritten from the original angling game, which asked the player to wait for a
bite. Waiting is the wrong verb for a cabinet.

The harpoon **fires straight up**, so *standing in the right place is aiming* —
one button, no aim stick fighting the movement stick, readable instantly. The
skill is that the bolt takes time to travel (620 px/s), so a moving fish must be
**led**.

- **Multi-kill**: one bolt spears everything in its path — 2 fish ×2, 3 ×3.
  The reason to hold fire and wait for a line to form.
- **Bottles block.** A bolt that hits plastic stops dead and costs 100, which
  turns bottles into moving cover to shoot around rather than a flat penalty.
- Fish 100, rare fish 200, reload 0.45 s, round 60 s.

### 7.5 Acorn Storm (`acorn_storm`) — *dodge*
The simplest game in the pool on purpose: things fall, one kind hurts, one kind
is good. No rules to read, which makes it the best card to be dealt first.

Everything about to land is telegraphed by a ring tightening onto the spot —
the same warning grammar as the shaking leaf, so the cabinet teaches one visual
language rather than eight. Player speed is raised to 108 here; it should feel
frantic. A hit is a 0.6 s stun and −80, never an ending. Fruit combo ×1–×5.

The warning is 1.5 s: an early build used 1.05 s and fruit landed faster than
anyone could cross the field, so the good half of the game was decoration.

### 7.6 Firefly Lantern (`firefly`) — *greed*
Your lantern shrinks constantly; fireflies refill it. **The multiplier is tied
to how small your light has got** (×1–×4), so playing safe means topping up
early and scoring nothing. The high score demands running on a sliver of lantern
in near-total darkness. Safe play and good play pull in opposite directions.

A guttered lantern relights at minimum and costs 120 — no death.

*Implementation note:* the night is a `CanvasModulate`, and fireflies live on
their **own CanvasLayer** because `CanvasModulate` tints only its own canvas.
Without that the one thing you are meant to see glowing in the dark rendered as
a grey dot; additive blending did not save it, because the tint applies after
the blend.

### 7.7 Temple Bell (`temple_bell`) — *timing, then multitasking*

The only non-movement verb in the pool, which is why it earns its slot: after two
movement cards, one that asks for something else makes the draw feel varied.

Two phases, because one verb for a whole minute is thin.

- **Phase 1 (0–25 s)** — rooted at the bell. Marks close on a ring; hit `act` as
  they land. Tempo 1.1 → 1.9 beats/s. Perfect +12, Good +6, chain to ×3.
  Striking into empty air breaks the chain, so mashing costs.
- **Phase 2 (25–55 s)** — the player is freed and the arena starts dropping
  coins and powerups outside the ring.

**A strike only registers inside the ring.** That single rule is what makes
phase 2 a multitask rather than a free bonus round: every trip out is beats you
are not there to hit, and the ring dims when you are out of range so the state
is never ambiguous.

| Pickup | Effect |
|---|---|
| Coin | +150, the reason to leave at all |
| Chime Burst | clears every mark on screen and scores each as a Good hit |
| Focus | hit window ×1.9 for 6 s |
| Double | score ×2 for 6 s |

**Phase 2 eases the tempo off (1.3 → 1.9) rather than piling on**, and pickups
spawn only 8–45 px beyond the strike range. The first version did the opposite —
1.9 → 2.6 with pickups scattered across the arena — and the soak bot correctly
never left the bell once, because a round trip cost five or six marks. The phase
had collapsed back into phase 1 with extra scenery. The difficulty in phase 2 is
the split attention, not the speed.

### 7.8 Crow Watch (`crow_watch`) — *defend*
Crows dive at a 5 × 3 rice field, telegraphed by a descending crow and a growing
shadow. Sprint into one before it lands to scare it off; a landed crow eats for
1.1 s before taking a bite, so there is always a second chance.

**The crop tally is both the objective and the clock, and it only goes down.**
A player can watch themselves losing, which is a far stronger pull than a number
that only climbs. Scare +50 with a chain multiplier; every surviving crop is
worth 70 at the end.

An early build had dives arriving faster than anyone could cross the field —
the bot finished with **zero** crop saved, so the headline mechanic paid nothing.

---

## 7b. Debug mode

`src/autoload/debug_menu.gd`, opened with **F3**, and **completely inert unless
`OS.is_debug_build()`** — it does not even listen for the key in a release
build, so it cannot appear on an exported cabinet.

- Jump straight into any of the 8 games. This deals a **one-card hand**, so
  Router's normal flow still runs and still ends at Results — it is a side door,
  not a replacement. **The card draw itself is untouched.**
- Force the next hand (`Game.forced_hand`), restart the current minigame, skip
  to Results, toggle slow motion (`Engine.time_scale` 0.35), clear local scores.

## 8. Art & audio direction

Dusk palette throughout, so eight environments read as one evening. Everything
on a 32 px grid; sprite origins at the feet.

Legibility rules that came out of the build:

- **Never encode a rule in colour alone.** The shaking leaf wobbles *and*
  reddens *and* ripples; the cave stones have notes; the bird cone shows `?`
  and `!` as well as changing hue.
- **Telegraph before consequence, always** — and use the *same* telegraph. The
  growing ring means "this lands here" in three different games.
- **The HUD states the rule once**, in plain words, always on screen.

---

## 9. Testing

```
tools/run_tests.sh          # or GODOT=/path/to/godot tools/run_tests.sh
```

| Suite | What it proves |
|---|---|
| `smoke_test.gd` | every scene loads and runs; all 8 emit exactly one result; `finish()` cannot fire twice; 40 draws deal 3 distinct, valid cards; **the three cards on the table actually display the hand that was dealt** |
| `soak_test.gd` | each of the 8 driven to its **own natural ending**, plus four regressions: drowning in Riverleap cannot be escaped by holding a direction; a bird's vision cone holds steady while investigating; stamina drains to empty and gates the next sprint; the meadow's roost scramble fires and resolves |
| `flow_test.gd` | the real loop through real scene changes: attract → draw → 3 dealt games → results → attract |

The soak suite is the one that matters. A minigame that cannot be completed
still looks fine in the editor and still passes a short smoke run. It has now
caught: the unplayable cave row layout, a `set_meta(key, null)` crash in Crow
Watch (Godot *deletes* the key), Crow Watch saving zero crop, Acorn Storm's
unreachable fruit, the Temple Bell scoring blowout, and — most usefully — the
fact that the bot **never once left the bell** in Temple Bell's first phase 2,
which is how the round-trip economics turned out to be broken.

A note on test isolation: the high-score table lives in `user://` and survives
between runs, so any assertion about ranking has to `Save.clear()` first or it
depends on whatever a previous run left behind.

**A visual pass is not optional.** Render every screen under `xvfb-run` and look
at it. Assertions caught none of these: the draw heading printing over the
middle card, Temple Bell's target ring rendering invisible because `_process`
overwrote the scene's scale, the fireflies above, the stamina bar never
appearing because its signal does not fire while the meter sits full, and Temple
Bell's phase 2 opening with the player 4px outside the strike range.

One trap when capturing: under `xvfb-run` the frame rate is not pinned, so
targeting a moment by frame count is unreliable — too few frames and the reels
are still spinning, too many and the table hands off to Router and frees the
capture harness. Poll for the state you want instead.

Two notes for reading test output:

- Synthetic input must be a parsed `InputEventAction`. `Input.action_press()`
  only sets the polled state and never reaches `_unhandled_input`, so the hop,
  fire and strike paths go silently untested.
- `ObjectDB instances leaked at exit` naming `AudioStreamWAV` is the mixer's
  shutdown ordering, not a leak — the voice pool is a fixed eight.

**What the tests cannot judge is feel.** Every knob is a named constant at the
top of its script.

---

## 10. Running it

```bash
godot --path video_games/sleepy-sun            # play
godot --path video_games/sleepy-sun --editor   # edit
tools/run_tests.sh                             # test
```

`F6` runs whichever minigame scene is open, standalone.

---

## 11. Deferred work, with the hook points named

**Payment / QRIS (Phase 2).** Not written — no HTTP, no stubs, no dead code.
`Game.REQUIRE_CREDIT` is the gate; `attract.gd::_begin_run()` carries the marked
comment where a dynamic QRIS charge is created and polled; the `insert_credit`
action (coin key `5`) is the input path. The step slots between Attract and the
card draw.

**Session logging & the public donation report (Phase 6).** Nothing is written
outside `user://`. `Save` is the natural home for a per-session record to
reconcile against the gateway ledger.

**Online leaderboard.** `Save` is local-only by choice; a shared board needs a
backend and a moderation story for names.

**Attract-mode demo.** A bot-played loop behind the attract panels would sell
the game better than a description — the soak drivers are most of that work.

**Pi performance pass.** Single-draw-call backdrops and a handful of sprites,
biggest texture 192×160, but it has not run on real hardware. Measure first.

**A ninth minigame / a second adventure.** The contract is adventure-agnostic.

**Audio pass.** See §5.

---

## 12. Open questions

1. **Are the pars right?** They are set at ~60 % of a scripted bot, which is
   superhuman at Temple Bell and Echo Hollow and underplays Riverleap's chimes,
   Firefly's greed loop and Hush Meadow's stealth entirely. A human pass will
   move them.
2. **Cabinet orientation.** Built for landscape 16:9.
3. **Is three cards the right hand?** `Game.PLAYLIST_SIZE` is one constant.
   Four cards is ~5 minutes and a fuller session; two is higher throughput.
4. **Price per credit**, which decides whether three games is generous.
5. **Language.** English throughout; very little text, all in one place per screen.
6. **Is stamina tuned right?** 2.4 s of sprint and a 1.5 s enforced rest is a
   guess. It is three `@export`s on `TopDownPlayer`, so it can be tried live in
   the inspector.
7. **Does Hush Meadow need a wider meadow?** It is five sections at 420 px, but
   the round is now timed rather than traversal-based, so the far end may never
   be reached. Worth watching whether the last two sections see any play.
