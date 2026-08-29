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

One cabinet hosts one **adventure**, and an adventure is several short minigames
tied together. *Sleepy Sun* is the first adventure. This document covers the
adventure and the shell around it; it does **not** cover payment, which is
Phase 2 work and is deliberately absent from the code (see §11).

What is built today:

```
Boot  →  Attract  →  Village hub  ⇄  four minigames  →  Results  →  Attract
                        (the "Payment Wait" step sits between Attract and Hub)
```

This satisfies the proposal's Phase 1 acceptance criterion — *the full loop plays
start to finish on ordinary hardware, without needing real money to test it* —
and `tests/flow_test.gd` asserts exactly that loop on every run.

---

## 2. Session shape

**One credit buys the entire adventure, and the player cannot lose it.**

| | |
|---|---|
| Length | roughly 5–8 minutes |
| Structure | village hub, four chores in **any order**, then a short finale |
| Failure | **none** — mistakes cost points and seconds, never the run |
| Scoring | one total across all four, plus a rank and a local high-score table |

The no-fail rule is not a difficulty setting, it is a venue decision. The cabinet
sits unattended in a mall or a school event, in front of people who have never
seen it before and who have already paid. A game-over screen thirty seconds in
is a machine that took someone's money and gave them nothing. So every minigame
turns failure into a **setback**: you go back in the water, you get carried to
the start of the stretch, the pattern replays. The floor is "you finish and score
modestly"; the ceiling is where the skill lives.

Every minigame is still winnable *badly*, which is what keeps a score
meaningful. `tests/soak_test.gd` proves each one can be completed, every run.

### Scoring at a glance

| Minigame | Par | Where points come from | Where they go |
|---|---|---|---|
| Riverleap | 1600 | arrival 1000, chimes +50, pace up to +600 | splash −75 |
| Hush Meadow | 1700 | petals +300 each, arrival 400, pace up to +400 | spotted −100 |
| Echo Hollow | 1800 | chamber +250, flawless chamber +150, pace up to +400 | slip −60 |
| Still Water | 1400 | fish +150, rare fish +300, 3-catch streak +50 | bottle −100 |

Par is the score a competent player should land near. The results screen ranks
the run against the sum of the four pars: **RADIANT** ≥ 1.15×, **BRIGHT** ≥ 0.90×,
**WARM** ≥ 0.65×, **GENTLE** below that. A scripted bot playing near-perfectly
scores about 6900 against a par sum of 6500, so RADIANT is genuinely hard and
GENTLE is not an insult.

Scores floor at zero. Nobody watches a negative number count up.

---

## 3. The fantasy

The sun is nodding off before it has finished setting. Four small evening chores
around the village gather the light it needs to go down properly and sleep.

That is the whole story, and it is deliberately thin. It exists to do three
things: justify a hub you walk around instead of a menu you scroll, give the four
unrelated minigames a reason to sit together, and give the cabinet a mascot —
the sun — whose state doubles as the progress bar. It brightens, grows and wakes
up as chores get finished. No cutscenes, no text the player has to read.

The tone is quiet and warm rather than frantic. The proposal calls for
"high-rhythm and fast-paced" minigames, and each individual game does move
quickly, but the frame around them is calm on purpose: a charity cabinet in a
public space reads better as inviting than as aggressive.

---

## 4. Technical baseline

| Decision | Value | Why |
|---|---|---|
| Base resolution | **640 × 360** | ×3 is exactly 1080p; 32px sprites read well at ~20 tiles across |
| Stretch | `canvas_items`, `keep`, **integer** scale | pixel-perfect at any window size, no shimmer |
| Texture filter | **Nearest** (project-wide) | it is pixel art |
| Renderer | GL Compatibility | what the Pi 4/5 can actually drive |
| Engine | Godot 4.6 | matches `config/features` |

### Art pipeline

Every sprite Neo drew is **32 × 32 pixel art exported at a huge
nearest-neighbour upscale** — up to 4128 × 4128 for the idle frame, which alone
would be ~68 MB of VRAM per frame on a Pi.

`tools/normalize_assets.py` recovers the original grid (the upscale factor is the
GCD of the run lengths of identical rows and columns) and writes true-resolution
copies into `assets/game/`. The originals in `assets/player_sprite/`,
`assets/fishing_game/` and so on are **never touched**; each of those folders
gets a `.gdignore` so Godot does not import the huge versions. Deleting those
five files restores them to the editor.

`tools/make_placeholders.py` fills every remaining gap with flat-colour stand-ins
in the same dusk palette. Both scripts' outputs are committed, so opening the
project needs no build step and no Python.

**Swapping in real art is a file replacement.** Same path, same dimensions, no
code change. `docs/ASSET_REQUESTS.md` lists what to draw, with sizes.

### Input

Bound for keyboard now and a USB arcade encoder later — an encoder enumerates as
either a keyboard or a gamepad, so both are wired from the start.

| Action | Keyboard | Joypad | Used for |
|---|---|---|---|
| `move_*` | arrows + WASD | D-pad, left stick | walking, hopping, stepping on stones |
| `act` | Space, Enter | A | jump, interact, confirm, cast, strike, sprint |
| `back` | Esc | B | cancel |
| `start` | Enter, `1` | Start | begin a run |
| `insert_credit` | `5` | — | MAME-standard coin key; **the payment hook** |

One button plus a stick runs the entire adventure. That is the control panel
worth building: fewer holes to drill, fewer parts to fail unattended.

---

## 5. Architecture

```
src/
├── autoload/
│   ├── game_state.gd    Game    run state, scores, the minigame registry
│   ├── router.gd        Router  scene changes, fades, result collection
│   ├── audio.gd         Audio   procedurally synthesised sound effects
│   └── save_data.gd     Save    local high scores in user://
├── core/
│   ├── minigame.gd            the contract every minigame implements
│   ├── minigame_result.gd     what a minigame hands back
│   ├── player_controller.gd   the one player controller, used by all five scenes
│   ├── scrolling_texture.gd   tiling/animated backdrops without a TileSet
│   └── wait.gd                node-owned timers
├── shell/     boot, attract, results
├── hub/       Sunset Village
├── minigames/ wind_leaf, tall_grass, cave, fishing
└── ui/        the shared HUD
```

### The minigame contract

The entire interface between a minigame and the rest of the game is:

```gdscript
class_name MiniGame extends Node2D

signal finished(result: MiniGameResult)

@export var id: StringName
@export var par_score: int

func begin() -> void          # Router calls this once the fade-in is done
func finish(score, stats)     # emits `finished`, exactly once, ever
```

A minigame never changes scenes, never writes to `Game`, and never knows the hub
exists. Router loads it, waits for `finished`, records the result and goes back
to the village. Consequences worth having:

- Any minigame runs standalone in the editor with **F6**.
- The test suite can instance one in isolation and play it.
- `finish()` is idempotent, so a race between "the timer ran out" and "the player
  reached the goal" cannot double-report a score.

### Adding a fifth minigame

1. Make a scene whose root script `extends MiniGame`; set `id` and `par_score`.
2. Instance `src/ui/hud.tscn` and `src/core/player.tscn` into it.
3. Call `finish(score, stats)` when it ends.
4. Add one entry to `Game.MINIGAMES` and one `HubPortal` to `hub.tscn`.
5. Add a `_detail_for()` case in `results.gd` so its stats get a one-line summary.

Nothing else. The hub star, the attract how-to card, the results row and all
three test suites pick it up from the registry automatically.

### Audio

No `.wav` files ship. `Audio` synthesises every cue at startup — sine, square,
triangle and noise with a fast attack and an exponential decay, which reads as a
"blip" rather than a beep. Fifteen named cues plus five pitched notes for the
cave stones. It costs about 40 ms at boot and nothing at runtime, and it means
the game has audio feedback without waiting on an audio pass. Replacing it with
real samples means changing the body of `sfx()`; every caller stays the same.

---

## 6. The shell

### 6.1 Attract / idle

Dusk village, the sun mascot dozing, an NPC wandering the path. Panels cycle
every five seconds: **title → one how-to card per minigame → local high scores →
repeat**, under a pulsing `PRESS START`.

**The idle screen is interactive.** Moving the stick makes the sun look that way
and rings the wind chimes; the button rings them and flips to the next panel.
None of it starts a game. It exists because on a public cabinet the first touch
is what turns a passer-by into a player, and a machine that visibly responds
before you have paid is a machine worth paying.

The how-to cards matter more than they look. Nobody reads instructions at an
arcade cabinet, but they will absorb one sentence per game while deciding whether
to play, and every minigame's rules are then reinforced by its own HUD line.

### 6.2 Sunset Village (the hub / minigame selection)

A place you walk around, not a menu you scroll. Four signposted chores plus the
sun on its hill. Walk up to a signpost, the prompt floats up, press the button.

- Chores can be done **in any order**.
- A finished chore lights its star, shows its score, and its signpost dims so it
  stops competing for attention.
- A finished chore can be **replayed**; the better score is the one kept.
- Coming back from a chore puts you at that signpost rather than the village
  entrance, so the walk reads as continuous.
- The sun brightens, grows and wakes across three frames as chores get done — it
  is the progress bar.
- All four done → walk to the sun to end the run.
- 45 seconds of no input anywhere returns the cabinet to attract.

Costing a few seconds per selection is the point: it is what makes four unrelated
minigames feel like one adventure.

### 6.3 Results

Rows count up one at a time, then the total, then a rank stamp. Each row says
what actually happened in that game's own terms ("4 chimes, 0 splashes"), a new
personal best is called out, and the bottles pulled out of the river are tallied
separately — a small good deed rather than only a penalty.

The last line is the point of the whole machine: *your credit becomes a donation*.
Those few seconds while the numbers roll are when someone decides whether to pay
again, and they are the only moment the cabinet gets to say what the money is for.
30-second timeout back to attract.

---

## 7. The minigames

All four are top-down and share one player controller and one sprite set.

### 7.1 Riverleap (`wind_leaf`)

**Hop between five drifting leaves and reach the far bank.**

The leaves carry you downstream, so the camera rides with them: the leaf row
holds a fixed screen position while the banks scroll past and the far shore
slides in at the end. Left/Right hops between the five lanes — a 0.26 s arc with
a scale pop and a shrinking shadow, with a 0.16 s input buffer so a press during
a hop still lands.

A leaf's life is `STABLE → SHAKING → SINKING → GONE → RISING → STABLE`. Leaves
always come back after 2.2 s, so the row can never be wiped out.

**The shake is the whole game**, so it is telegraphed three redundant ways at
once — a rotation wobble that accelerates, a colour shift toward red, and a
widening ripple. Redundant because it has to read on a scuffed cabinet screen,
from a few feet back, to someone who may not separate red from green.

Difficulty ramps with distance:

| Progress | Shake interval | Telegraph | At once |
|---|---|---|---|
| 0–33 % | 2.40 s | 1.10 s | 1 |
| 33–66 % | 1.60 s | 0.80 s | 1–2 |
| 66–100 % | 0.90 s | 0.55 s | 2 |

**The director never corners you.** Before a leaf is chosen to shake, it checks
that at least one lane reachable in a single hop will still be safe. Without that
rule the game is losable to luck alone, which in a no-fail game just means an
unearned splash.

*Splash (no-fail):* standing on a sinking leaf, or hopping into a gone lane,
floats you for 1.25 s before a leaf lifts you back up. Costs time and 75 points.
The river never stops moving, so a splash is expensive but never fatal.

Wind chimes drift down the lanes as +50 pickups — the reason to take risks, and
where the game's name comes from.

*Tuning lives in the constants at the top of `wind_leaf.gd`.*

### 7.2 Hush Meadow (`tall_grass`)

**Cross three meadow sections gathering sunpetals without being seen.**

Birds patrol overhead with a **visible cone of sight**. The cone is drawn, not
implied — a stealth game where you have to guess what the guard can see is a
frustrating one, and nobody at a cabinet will learn it by dying. Detection is a
fill, not a trip-wire: white → amber (`?`) → red (`!`), roughly two thirds of a
second of exposure, which is the half-second you need to duck into cover.

Tall grass hides you completely and is drawn over you while you are in it.
So the safe route is obvious — and slow (56 px/s in grass vs 78 in the open).

**Cover has to be visible from across the room.** The first pass drew thin blades
on green ground and the hiding places effectively vanished; a stealth game whose
safe route you cannot see is not a stealth game. Clumps now carry a solid dark
base, dense blades and a soft shaded footprint on the ground, soft-edged so
overlapping clumps merge into one patch instead of showing seams.

**Holding the button sprints**, at 1.75×. That is how you cross open ground in
time, but it rustles, and any bird within 96 px breaks patrol to come and look.
Fast, safe, cheap: pick two. That trade is the minigame.

Line of sight is blocked by rocks and hedges, sampled along the line rather than
raycast — precise enough at this scale and it keeps the Pi budget free.

Sections are generated fresh each run under fixed rules, so the meadow is never
memorised: the petal always sits in the far half (every petal is worth a detour),
and no bird patrols across a section entrance (re-entry is never a trap).
One bird in the first stretch, two after — the difficulty curve is density.

*Spotted (no-fail):* the bird swoops, you wake at the start of the current
section, −100. **Petals you already picked up stay picked up**, so progress is
never lost — only time.

### 7.3 Echo Hollow (`cave`)

**Five chambers, each guarded by a pattern of lit stones you have to walk back.**

You do not press five buttons; you walk the path with your body. That turns a
memory test into a route you can *feel*, and it is why this works top-down with
the same stick-and-button as everything else.

Each stone has its own colour **and its own note**, so the pattern can be
memorised by ear as well as by eye — players who hum it back do noticeably
better, and it keeps the puzzle solvable for someone who cannot separate the
colours.

| Chamber | Steps | Lit | Gap |
|---|---|---|---|
| 1 | 3 | 0.60 s | 0.25 s |
| 2 | 4 | 0.52 s | 0.22 s |
| 3 | 5 | 0.45 s | 0.18 s |
| 4 | 6 | 0.38 s | 0.15 s |
| 5 | 7 | 0.32 s | 0.12 s |

Never the same stone twice running: at these speeds a repeat is unreadable and
feels like a trick rather than a test.

**The stones sit in a ring, not a row.** In a row, walking from the far right
stone to the far left one drags you across every stone in between and each one
registers as a wrong answer — the game is unplayable for any sequence that is not
left-to-right. This was caught by `tests/soak_test.gd` during the build, not by
inspection. Arranged in a ring around a central standing spot, the path between
any two stones runs through the middle instead; the tightest chord still clears
every other stone by 48 px, well outside their 20 px reach.

Clearing a chamber opens the door — Neo's eight hand-drawn `stage_door` frames,
a stone slab retracting upward: frame 1 is the full slab, frame 8 is four pixels.
So the sequence runs closed → open as drawn and `reversed` stays off. Because the
slab shrinks from the bottom within a fixed 192×160 canvas, a plain centred
sprite already reads as retracting; no anchoring work was needed. Walk through
and the next chamber starts.

*Mistake (no-fail):* the stones flash red, −60, the pattern replays. **A second
mistake in the same chamber replays it at chamber-1 speed.** Nobody gets stuck
on a public cabinet.

### 7.4 Still Water (`fishing`)

**Cast into the river and strike when something nudges the float.** 75 seconds.

Hold the button to cast — the power meter runs up *and back down*, so a long cast
is a timed press rather than a hold, and the long water is where the rare fish
are. Release to arc the float out.

Fish and bottles drift past in five lanes. When something comes within reach the
float dips and a `!` appears; you have 0.45 s to strike.

**A bite tells you something is there, not what.** The silhouette in the water is
the only way to tell a fish from a bottle, and it is visible *before* the bite —
so a player who looks before they strike scores, and a player who mashes the
button feeds on plastic. Everything about a swimmer is a tell: bottles run dead
straight at a steady 24–34 px/s, fish weave and vary. Both are tinted as if seen
through water, so it has to be read as a shape, not a colour.

| Catch | Value |
|---|---|
| Common fish | +150 |
| Rare fish (faster, further out) | +300 |
| Plastic bottle | −100 |
| Three clean catches in a row | +50 |

The streak bonus exists so that reading the water beats casting blind by more
than the plastic penalty alone.

*No fail:* the score floors at zero and the round ends on its own clock. Bottles
you pull out are counted separately and shown on the results screen — the
cabinet's whole point is turning play into something useful, and this is the one
minigame where that lands inside the fiction.

---

## 8. Art & audio direction

Dusk palette throughout — deep blue-violet shadows, warm amber light — so four
different environments read as one evening. The placeholder generator uses the
same palette, which is why the game looks coherent before any of the real art
exists.

Everything is on a 32 px grid. Sprite origins are at the character's feet, so
positioning against ground features and Y-sorting both work without per-scene
fudging.

Legibility rules that came out of the build and are worth keeping:

- **Never encode a rule in colour alone.** The shaking leaf wobbles *and* reddens
  *and* ripples; the cave stones have notes as well as colours; the bird cone
  shows `?` and `!` as well as changing hue.
- **Telegraph before consequence, always.** Every hazard has a visible warning
  with enough time to react at walking speed.
- **The HUD says the rule, once.** One objective line per minigame, in plain
  words, always on screen.

Audio is synthesised (§5). A real pass would want: a soft ambient bed per
minigame, water and wind loops, and a short jingle on the results screen. None of
it is required for the game to work.

---

## 9. Testing

Three headless suites, all runnable over SSH or in CI:

```
tools/run_tests.sh            # or GODOT=/path/to/godot tools/run_tests.sh
```

| Suite | What it proves |
|---|---|
| `tests/smoke_test.gd` | every scene loads and runs under synthetic input; each minigame emits exactly one result; `finish()` cannot fire twice; scores never go negative |
| `tests/soak_test.gd` | each minigame can actually be **completed**, by playing it properly to its own ending — not by forcing `finish()` |
| `tests/flow_test.gd` | the full cabinet loop through real scene changes: attract → start → hub → all four chores → sun → results → attract |

The soak test is the one that matters most. A minigame that cannot be completed
still looks fine in the editor and still passes a short smoke run. Two real bugs
came out of these suites during the build and are documented where they were
fixed: the cave's row-versus-ring layout (§7.3), and Router silently dropping a
`START` pressed during a fade, which left the attract screen permanently dead
until it timed out.

One note when reading test output: synthetic input must be sent as a parsed
`InputEventAction`, not `Input.action_press()`. The latter only sets the polled
action state and never reaches `_unhandled_input`, so the hop, cast and strike
paths go silently untested.

Godot may print `ObjectDB instances leaked at exit` naming `AudioStreamWAV` /
`AudioStreamPlaybackWAV`. That is the audio mixer's shutdown ordering, not a leak
— the voice pool is a fixed eight players and nothing accumulates during play.

Feel and layout were checked by rendering each screen under `xvfb-run` and
looking at it. That pass caught what no assertion would have: portal labels
floating over the village houses, the results total printed on top of its own
rows, `1 splashes`, a bare strip above the fishing water, and the grass problem
in §7.2. Worth repeating after any layout change.

**What the tests cannot judge is feel.** Hop timing, bird speed, cast arc,
sequence tempo: those need a human at the keyboard. Every one of them is a named
constant at the top of its minigame's script.

---

## 10. Running it

```bash
godot --path video_games/sleepy-sun            # play
godot --path video_games/sleepy-sun --editor   # edit
tools/run_tests.sh                             # test
```

`F6` in the editor runs whichever minigame scene is open, standalone.

---

## 11. Deferred work, with the hook points named

Out of scope for this session, listed so nothing gets rediscovered later.

**Payment / QRIS (proposal §2.4.2, Phase 2).** Not written — no HTTP, no stubs,
no dead code. Two seams are in place:
- `Game.REQUIRE_CREDIT` (currently `false`) is the gate.
- `attract.gd::_begin_run()` carries the marked comment where a dynamic QRIS
  charge gets created and polled before `Game.start_run()` is allowed.
- The `insert_credit` action (coin key `5`) already exists as the input path.

The state machine already has the shape for it: Attract → *(Payment Wait)* → Hub.
Inserting the step means adding one scene between them and flipping the constant.

**Session logging & the public donation report (Phase 6).** Nothing is written
outside `user://` today. `Save` is the natural place for a per-session record —
timestamp, duration, total score — to be reconciled against the gateway ledger.

**Online leaderboard.** `Save` is deliberately local-only. A shared board needs a
backend and a moderation story for names; not worth it before the pilot.

**Attract-mode demo.** A recorded or bot-played loop of a minigame behind the
attract panels would sell the game better than a description. The soak test's
drivers are most of the work already done.

**Pi performance pass.** Everything is single-draw-call backdrops and a handful
of sprites, and the biggest textures are now 192×160, but it has not been run on
real hardware. Measure before optimising.

**A second adventure.** The `MiniGame` contract and the hub are adventure-agnostic;
a second one is a new hub scene plus a new registry, not an engine change.

**Audio pass.** See §8.

---

## 12. Open questions

1. **Cabinet orientation.** Built for landscape 16:9. A portrait (tate) monitor
   would suit Riverleap but hurt Hush Meadow and Still Water.
2. **Session length.** A full run is roughly 5–8 minutes. If the pilot venue
   wants higher throughput, the honest lever is cutting Still Water's 75-second
   round and Riverleap's 62-second crossing, not adding a fail state.
3. **Price per credit**, which determines whether "one credit = four minigames"
   is generous or wrong. A per-minigame credit is a registry change, not a
   rewrite, if it turns out to matter.
4. **Language.** English throughout. An Indonesian pass is a strings file away —
   there is very little text, and it is all in one place per screen.
