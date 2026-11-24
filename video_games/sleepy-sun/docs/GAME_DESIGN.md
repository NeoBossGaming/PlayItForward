# Sleepy Sun — Design & Planning Document

**Status: three games.** Four earlier rounds built eight minigames, a
card draw, an attract screen, a results screen and seventeen cutscenes. All of
it works and all of it is in `main`'s history — but none of it was *finished*,
because the budget was always split eight ways.

So the project is now one game at a time, each polished until it is genuinely
good: **Riverleap**, then **Acorn Storm**, then **Hush Meadow** — and only then
the shell that holds them. Everything still parked is listed in §10, with the
commit it lives in.

---

## 1. What this is

**Play It Forward** is a charity arcade cabinet. One cabinet hosts one
*adventure* made of minigames; Sleepy Sun is the first adventure.

The constraints that shape every decision:

| Constraint | Consequence |
|---|---|
| It sits unattended in a public space | Playable by someone who has never seen it, with no instructions |
| The player has already paid | **No fail state** — *amended for the two endless games, see §5.* A game over thirty seconds in is a machine that took money and gave nothing. Riverleap now has five lives, chosen deliberately, with a gentle first minute as the compromise |
| One stick, one button | Every verb has to fit that |
| Raspberry Pi 4/5 | 480 × 270 internal, GL Compatibility renderer |
| The money is a donation | The cabinet says so when the run ends |

---

## 2. The fantasy — The Waking

> The sun slept straight through the dawn. It has overslept before, but never
> this long, and never with the bell unrung. The valley is doing the waking by
> hand.

Each minigame gathers one **gift** for the sleeping sun. Riverleap's is **the
river chimes**: the sun has always woken to them, and the wind has stopped, so
somebody has to cross the river and ring them by hand.

The lore is written and parked (§9). It belongs with the shell, because a
cutscene with nothing on either side of it is just a delay.

---

## 3. Technical baseline

| Decision | Value | Why |
|---|---|---|
| Base resolution | **480 × 270** | ×4 is exactly 1080p |
| Stretch | `canvas_items`, `keep`, **integer** | pixel-perfect at any size |
| Texture filter | **Nearest** (project-wide) | it is pixel art |
| Renderer | GL Compatibility | what a Pi 4/5 can drive |
| Engine | **Godot 4.7** | and the tests must run on it, not on whatever is handy |
| Player sprite | **1.5×** (≈18 × 43 px) | ~3.8 % of screen width at 480 wide |

The resolution drop was the second attempt at making the player read. Scaling
the sprite alone did nothing, because a bigger character on a 640px field still
takes exactly as long to cross it. The viewport went to 480 × 270 and the play
fields shrank with it.

Fonts: **Press Start 2P** (titles, numbers) and **Pixelify Sans** (body), both
OFL, licences shipped alongside in `assets/game/fonts/`. Press Start 2P is about
twice the width of a normal face, so columns are tight; Pixelify Sans is
unreadable below 11 px, which is a hard floor. All text goes through
`src/ui/game_theme.tres` — restyling the game is a one-file edit.

### Art pipeline

`tools/normalize_assets.py` recovers true-resolution copies from hugely
upscaled hand-drawn exports. `tools/make_placeholders.py` fills the gaps; its
`KEEP` set lists exactly which sprites the stripped project wants, so re-running
it cannot resurrect art for a parked game. Both scripts' outputs are committed,
so opening the project needs no build step.

Several sprites in one game are drawn from **one random stream**, in order. A
redrawn sprite that takes a different number of draws re-randomises every
sprite after it, silently. That is why `_acorn_floor_v1()` and
`_hush_floor_v1()` still run when the floors they drew are gone: their names
are not in `KEEP`, so nothing is written, but their draws keep the canopy and
the hedge byte-identical. After any regeneration, `git status` should list only
the sprites you meant to change.

---

## 4. Architecture

```
src/
├── autoload/   Audio (synth), Save (local scores), Dev (two debug keys)
├── core/       minigame contract, player controller, decor, juice, timers
├── minigames/  wind_leaf
└── ui/         HUD, theme, score popup, run card
```

There is no Router, no Game singleton and no shell. The game is the main scene;
it starts itself and loops.

### The minigame contract

```gdscript
class_name MiniGame extends Node2D
signal finished(result: MiniGameResult)
@export var id: StringName
@export var par_score: int
func begin() -> void          # something calls this
func finish(score, stats)     # emits `finished`, exactly once, ever
```

Unchanged from when the shell existed, which is the point of having one: the
card draw can be put back in front of it without the game knowing. `finish()`
is idempotent, so a race between "the crossing ended" and "the timer ran out"
cannot double-report a score.

**Riverleap self-starts only when it is the current scene**
(`get_tree().current_scene == self`). The soak test instances it as a child and
drives `begin()` itself, and must not get a run card or a scene reload out of
the bargain.

### Running it

`project.godot` boots straight into `wind_leaf.tscn` — no boot scene, no
attract. During a polish round the loop is play, change, play, and every second
of shell between those is friction.

- **F5** restarts instantly, from anywhere.
- **F4** switches to the next game.
- **F3** toggles slow motion (0.35×), for looking at a frame of animation.

That is the whole debug surface, and all three keys are inert outside a debug
build.

**F4 exists because there is no Router any more.** Each game starts itself and
reloads itself on replay, so with two games the boot scene was the only one
reachable without a terminal — and six more are coming. It is deliberately a
debug key rather than a picker: a picker would be the first brick of the shell
that was parked on purpose, and an exported cabinet must not grow one by
accident.

`Dev` finds the games rather than listing them, by the convention below, and
clears `StartCard.tutorial_seen` on the way so the game you land on teaches its
own lesson. Without that, arriving at Acorn Storm after Riverleap's card would
skip Acorn Storm's intro entirely — which is the thing you are most likely to
have pressed the key to look at.

### Score feedback

- **Gains pop at the object** — the chime that scored, not a corner of the HUD.
- **Losses pop on the player**, and they *shake* instead of drifting, so a loss
  cannot be mistaken for a win at a glance.
- **Nothing permanent on screen is a sentence.** Score, a meter bar with an
  icon, and a multiplier badge that only appears above ×1.

---

## 5. What every game inherits

Riverleap was built first and alone, so a fair amount of what looks like
Riverleap is actually *the cabinet*. This section is the part the second game
did not have to rediscover, written down so the third does not either.

### The difficulty curve has one shape

`MiniGame.curve(seconds, gentle_seconds, gentle_ceiling, steep_tau)` — a gentle
linear climb to a ceiling, then an exponential approach to 1 that never
arrives. Each game passes its own three numbers; the shape is shared.

The shape encodes two decisions. The gentle opening is **the compromise that
buys a fail state**: a stranger who has not worked out the controls still gets
a real go for their credit. The ceiling that is never reached is **what a good
player is chasing**: there is always a next thirty seconds that is worse than
this one.

One curve, not a dozen tuned constants, is also what makes a game tunable at
all. Everything reads `_intensity` — spawn rates, speeds, how many things are
in the air at once, how fast a bar drains — so stretching the curve eases all
of them together and keeps their relationships intact. Riverleap's opening was
lengthened twice by changing two numbers.

### Nothing happens until the world is up to speed

Every game has a **launch**: a second or three after GO where the scene gets
going and nothing is thrown at the player. Riverleap's river accelerates from
a standstill; Acorn Storm's gale builds and the canopy starts to thrash.

The pattern, in both:

```gdscript
func launch_factor() -> float:       # 0 at the gun, 1 once up to speed
    return smoothstep(0.0, LAUNCH_SECONDS, elapsed)

func play_time() -> float:           # the clock the difficulty runs on
    return maxf(elapsed - LAUNCH_SECONDS, 0.0)

func sequence_started() -> bool:     # the gate everything spawning reads
    return elapsed >= LAUNCH_SECONDS
```

`play_time()` rather than `elapsed` matters: without it the "gentle first
minute" is a gentle fifty-seven seconds, and every debut clock is early.

### A thing that is about to happen is marked on the ground

Both games warn with a **hard-edged mark that tightens onto the spot**, and
both learned the same lessons getting there:

- **Colour alone is not a cue.** Riverleap's dive marker was redrawn twice
  before it was legible; Acorn Storm's two marks differ by *shape* first — an
  open ticked ring against a filled disc — and are checked in greyscale.
- **A plain circle reads as a ripple**, which these games already use to mean
  something else. Ticks outside the ring fix it.
- **The tightening is the clock.** Nothing else on screen says how long is
  left, so the mark has to carry it on its own.

### Draw order is a rule, and it is expressed in z

Where something is drawn says what it is. In Riverleap an airborne player
passes over a hornet; in Acorn Storm a falling body passes over the player and
its ground mark goes under them.

**Godot's child `z_index` is relative: it accumulates up the parent chain.**
This shipped inverted once, with every constant in the file correct and only
the scene wrong — so both suites resolve effective z by walking the chain
rather than reading the constants back. Containers for things that set their
own layers carry no `z_index` at all.

### The director never corners you

Each game defines what "cornered" means for it — Riverleap, a row with no
reachable safe pad; Acorn Storm, no reachable spot clear of what is landing —
and the director **rejects a placement that would create one** rather than
throwing it and hoping.

The guarantee is deliberately **instantaneous, not predictive**: could the
player get somewhere from where they are *now*. That is the only promise a
director can keep, and both suites assert it every frame of a driven run while
ignoring the fraction of a second after the player has committed to a move of
their own.

### Two layers on different periods, or the ground looks tiled

No shaders anywhere (§3), so repetition is beaten with geometry: a large base
tile plus a second layer on a **different tile size and a different scroll
rate**, so their periods never align. Riverleap's water is 192 px at 0.45×
under 256 px at 0.38×; Acorn Storm's clearing is 160 px under a 224 px shade
layer drifting with the wind.

A bigger tile on its own only makes the grid bigger. And anything that must
be *wider than the screen* — Acorn Storm's canopy band — should simply be drawn
wider than the screen, because a tile with no period is the cheapest fix there
is.

### The ground is drawn in shapes, not grain

Neo, on the two games after Riverleap: *"the assets look too realistic for a
2d pixel game."* It was not the palette — every sprite was already four to six
colours. It was **grain**: how often the colour changes from one pixel to the
next along a row. Riverleap's water is a few big deliberate blobs and short
streaks, a mean run of **20 px**. Acorn Storm's clearing and Hush Meadow's
meadow were thousands of single-pixel random strokes, **2.0 and 1.8 px**, and
fine random grain is exactly what a camera produces. Every check passed,
because nothing was asking.

The rules every large layer is now built by, in `tools/make_placeholders.py`:

- **Shapes, then motifs.** A few big hard-edged zones from a thresholded field,
  close together in value so they give the ground shape without reading as
  camouflage; then a handful of small hand-defined tufts *stamped* at random
  places. Detail is repetition of deliberate shapes, never per-pixel chance.
- **Nothing alone.** No lone pixel in a zone map; every mark is a cluster.
- **Ordered dither, never random alpha.** A soft edge is two fixed alpha steps
  with a 4×4 Bayer pattern between them, in a narrow band. The cover disc went
  from 208 alpha levels to 2.

Targets: a ground or shade tile **≥ 10 px**, a grass clump or cover disc
**≥ 6 px**. `SoakBase.mean_run()` measures the imported texture, and both
suites assert it on their layers. It is the only objective check on "does this
look retro", and it found the problem.

Two things the pictures caught and the number could not: a tuft cleanup pass
run after stamping erased every tuft's tips to dots, and five-pixel cross
flowers sprinkled Hush Meadow with small copies of the dew mote — the one cross
on that ground that is supposed to mean something.

### Speed is sold with the camera, not with shake

`GameCamera` pushes **in** as pressure rises and kicks briefly when something
happens. Widening the field of view is the most reliable way to express speed;
shake expresses impact, so a constant tremble reads as an earthquake rather
than as pace. Shake is in fractions of a game pixel and never rounded.

### The opening card, then 3-2-1

`StartCard` owns the backdrop, the page dots, the skip, the pacing and the
countdown; each game supplies its slides by overriding `slide_count()` and
`build_slide()`. Slides use the **real game objects** — a real lily pad, a real
faller — so the lesson cannot drift away from what the game does.

A first-timer is taught; a replay goes straight to the countdown; and
`note_idle()` re-arms the lesson once the results card has sat untouched long
enough that whoever presses next is probably a different person. A cabinet runs
all day, so a flag set once per process would teach the first player of the
morning and nobody else.

### The folder name is load-bearing

**One game per folder under `src/minigames/`, in a scene named after its
folder.** `wind_leaf/wind_leaf.tscn` is a game; `wind_leaf/leaf.tscn` and
`acorn_storm/faller.tscn` are pieces one is built from. Test suites follow the
same idea: `tests/*_test.tscn`, one per game.

Two things discover by it rather than holding a list — `Dev`'s game cycle and
`tools/run_tests.sh` — so adding game three means adding a folder, not editing
files nobody thinks to look at. With six games still to return, a
hand-maintained list would rot.

The catch is that a folder whose scene is named something else is **silently
unreachable**: it runs, its own suite passes, and the cycle simply never offers
it. `tests/cabinet_test.gd` exists to turn that silence into a failure, and was
verified by breaking the convention on purpose and watching it fail.

### Every run ends with a letter

`MiniGameResult` carries a `normalised` 0-1000; `src/core/rank.gd` bands it
into **D C B A S SS**, and `RunCard` stamps the letter in once the score has
finished counting.

It is cut from the normalised number rather than the raw score on purpose. Raw
scores are per-game and unbounded -- Riverleap pays tens of thousands for a
long run, a fixed-length game pays hundreds -- so a letter cut from them would
grade the game rather than the player. Par is 500, so **a par run is a B**, a
good one an A, a strong one an S, and SS is several times par.

"Best yet" is compared **by band, not by number**, so two runs inside SS do not
both claim it.

### The rare golden prize

About one run in five ends with one, in every game: a golden chime in
Riverleap, a shining ball in Acorn Storm. `src/core/golden.gd` owns the
once-per-run roll, the window it may appear in, and the collect effect (white
flash, sparks, camera kick, a rising three-note fanfare). Each game supplies
only the sprite and how the thing travels.

**It scores nothing and nothing branches on it.** What it is for has not been
decided yet; quietly making it worth points would be deciding.

Two things that look like details and are not:

- **"One in ten" means collected, not offered**, and bots are the wrong
  instrument for measuring it. The roll sat at 34% for a round because bots
  collected under half of what they were offered; a person who sees SOMETHING
  BRIGHT and a glowing ball simply goes and gets it, and Neo caught one on his
  first run. A reward whose whole appeal is that a player will always chase it
  cannot be calibrated against players who do not. The roll is now 0.13, close
  to the rate it is meant to produce, with a small allowance for runs that end
  before the prize is due.
- **It is a gift, not a dexterity test.** It lands inside 55% of a sunfruit's
  reachable range, falls 40% slower, and has a wider catch radius. The roll is
  what makes it rare. "Something bright appeared and I could not get to it" is
  a worse non-event than never seeing one at all.
- **In Acorn Storm, telling it apart is now part of the game.** It began as a
  white-hot star, unmistakable in the air -- and Neo asked for the opposite:
  *"make the acorns kinda hard to distinguish from the golden ball so that's
  also part of the challenge (but not too hard)."* So the prize is a **golden
  acorn**: the same silhouette as the thing that hurts you, in gold, with a
  four-point glint and only a slight size difference.

  The ambiguity is deliberately confined to the **air**. On the ground the
  marks still differ by shape -- hot ticked ring means move, filled disc means
  take it -- so a player who checks always gets a straight answer and the game
  never lies to them. What the change costs is a glance, which is exactly the
  challenge that was asked for. A third mark shape would have crossed the
  line, because it would make the player learn a new symbol in the half second
  they have to act.

### Endless games are compared on how long you lasted

`MiniGameResult` carries a `normalised` field, 0–1000, alongside the raw score,
so games on wildly different scales can share one table. A fixed-length game
normalises on `par_score`; an **endless** one must not, because its score is
unbounded and accelerating, and two endless games compared on points compare
their scoring rates rather than their players.

`MiniGame.normalised_from_duration(seconds, par_seconds)` gives par 500 and
saturates without reaching 1000 — twice par is 750, four times is 937. The
same "approach but never arrive" shape as the difficulty curves, for the same
reason.

---

## 6. Riverleap (`wind_leaf`) — *hop*

Five drifting leaves on a river that never ends. **Ride it for as long as you
can hold on.** A leaf's life is `STABLE → SHAKING → SINKING → GONE → RISING`,
and leaves always come back, so the row can never be wiped out.

There is no far bank. The run ends when the river has taken all five lives.

### Why it has a fail state at all

This reverses §1's no-fail-state rule, knowingly. Stripped of decoration the
old 62-second crossing was **one binary choice — left or right — repeated for a
minute**, with nothing for a good player to reach for; it is the weakness the
previous version of this section flagged and asked to be answered by playing.
It was played, and the answer was *"still not high octane enough… so pro
players can actually enjoy this game too."*

The compromise is the **shape** of the curve rather than the absence of a
ceiling: the first minute is gentle enough that a stranger who has not worked
the controls out still gets a real go for their credit, and only then does it
turn steep.

### One number drives everything

`intensity_at(seconds)` in `wind_leaf.gd` — shallow for a minute, then steep,
approaching but never reaching 1:

```
gentle := 0.30 * min(t / 60, 1)
steep  := 0.70 * (1 - exp(-max(t - 60, 0) / 90))
```

≈0.12 at 30 s, 0.24 at 60 s, 0.48 at 120 s, 0.65 at 180 s — stretched once
already, because a beginner was getting about 90 seconds. **Both numbers
lengthen the climb without touching the ceiling**, so the late game is exactly
as nasty and simply takes longer to arrive.

This is the whole reason it is one curve rather than a dozen tuned constants:
the shake interval, the telegraph, how many pads go at once, the regen delay
and every hazard clock all read it, so stretching it eases all of them
together and keeps their relationships intact. Everything speed- or
difficulty-linked reads this one value and nothing else:

| | t=0 | t=60 | late |
|---|---|---|---|
| current | **204 px/s** | 290 | → 480 |
| hornet airspeed | *(none yet)* | 150 → 260 | → 360 |
| heron telegraph | *(none yet)* | — | 1.45 s → 0.50 s |
| shake interval | 2.6 s | 1.7 s | 0.40 s |
| shake telegraph | 1.15 s | 0.85 s | 0.30 s |
| pads shaking at once | 1 | 1–2 | 3 |
| hornet interval (from 35 s) | — | 4.5 s | 1.1 s |
| heron interval (from 100 s) | — | — | 2.4 s |
| survival pay | 20/s | ~30/s | 85/s |

### Three things to read, wanting three different reactions

If every threat collapses into one button pressed on a rhythm there is no game,
so each of these is answered differently:

| | Reaction |
|---|---|
| **a pad shaking** | hop off it |
| **a river hornet** (from 35 s) | **jump** — it passes underneath you |
| **a diving heron** (from 100 s) | jumping will **not** save you; get out of the lane |

### Why the river stopped looking tiled

The surface was one **64 px** tile across a 504 px river — about **forty
visible repeats**, and no amount of detail inside a tile hides a grid that
regular. Three things fix it, and the order of importance is not the obvious
one:

1. **A second period that never lines up.** `water_depth.png` is **256 px**
   drifting at **0.38×** the current, under a surface that is **192 px** at
   **0.45×**. Different size *and* different speed means the two patterns beat
   against each other over a distance no player will ever watch. **This is the
   one that does the work** — a bigger tile on its own would only have made
   the grid bigger. The soak suite asserts the two rates stay different,
   because setting them equal brings the grid straight back and nothing else
   would catch it.
2. **Fewer repeats.** The surface goes 64 → **192 px**, so ~40 repeats become
   ~4, and at that size the tile can hold actual current shapes rather than
   only speckle.
3. **Animation, in the one place it is safe.** The base stays a still image.
   An early version cycled three base frames that each shifted the pattern
   3 px, so at 4 fps the whole river teleported four times a second. Only the
   **glints** animate, across four frames whose streaks share identical
   positions and differ solely in alpha — nothing translates, so nothing can
   teleport.

**A note on evidence.** The claim "it looks less tiled" was checked with a
self-difference measurement at the tile period, and that measurement came back
**inconclusive — it found no standout repeat in the old water either**. So the
case for this change rests on the arithmetic (forty repeats to four, plus a
second period) and on looking at it, not on that number. Recorded here so
nobody later mistakes it for a measured result.

### Pads come back faster as the pace rises, then stop improving

A sunken pad used to stay gone for a flat **2.2 s** whether the river was
ambling or tearing along — and late on, with three pads going at once, that is
most of the row missing most of the time. `regen_delay()` now decays toward a
floor: **1.50 s** at the start, 1.04 s at intensity 0.3, 0.83 s at 0.6, 0.71 s
at 1.0, approaching 0.65 without reaching it.

Exponential decay to a floor is the "fast improvement, then plateau" shape
wanted here, and unlike an actual logarithm it cannot run away toward zero. It
is forgiveness at both ends: a beginner spends less time facing a hole, and the
late game keeps a usable row despite the churn.

### The row sits low on purpose

`ROW_Y` is **206** of 270. The river *upstream* of the player is the only place
a hazard can be seen coming, so a low row buys reaction time — a hornet at top
airspeed is on screen about 0.53 s before it strikes rather than 0.44 s, and
the first one a player ever meets gives 1.27 s rather than 1.05 s. It costs the
late game nothing, which makes it the cheapest forgiveness available.

Anything needing this number must **read** it. It was once copied into six
other places, including four in the test suite, and a test holding its own copy
would have gone on passing while measuring a row the game no longer used.

### Walking up to it: the card, then 3-2-1

A ~5 s card over the still river, then a racing-style countdown, then play.

**Four slides**, about 2.2 s each: the controls, the pads going under, the
hornet, the heron. Page dots underneath, any button skips the lot.

**The slides use the real game objects, not drawings of them.** The sinking
pad is an actual `RiverLeaf` put through `start_shake()`; the ring, the hornet
and the heron are the sprites the river uses. A diagram would be free to drift
away from what the game does; this cannot.

**They are also still taught in play.** A hornet does not turn up until 35 s
into a run and a heron more than a minute after that, so the slide gets them
recognised and a one-line `HUD.prompt()` the first time each appears does the
rest — the small bottom line, not a centre toast, because it fires at the
instant the player needs to be looking at the river.

**Within a slide, everything is up at once and loops.** Somebody glances up at
a random moment; whatever is on screen then has to be the whole picture. On
the controls slide the stick carries an arrow either side, lighting with the
lean — a stick alone says "there is a stick", not which way to push it.

**Draw order inside a slide is the lesson.** Three of these were wrong first
time and each said the opposite of its own caption: the hornet was added after
the figure so it crossed her face instead of passing under her feet, and the
heron's ring was painted over her when in the river it is on the water beneath
her. The hazard that can be jumped goes in *before* the figure, the ring goes
in before her, and the diving bird goes in after everything.

A fourth was worse because it looked fine in motion: the figure fled the
sinking pad on `shake_amount()`, which is zero once the pad has actually gone
under — so she walked straight back and stood on open water. She now stays
away for the whole of that pad's life and only returns when it is `STABLE`.

**Full card the first time, countdown only on a replay** (~12 s against ~3 s).
`StartCard.tutorial_seen` is a `static var`, so it survives the
`reload_current_scene()` that replay uses, and is deliberately **not** saved to
disk — a player returning tomorrow is still a stranger to the controls.

On its own that would teach the first player of the morning and nobody else,
since a cabinet runs all day. So `note_idle()` clears the flag when the results
card sat untouched for 30 s, on the assumption the last player wandered off.
**It is a heuristic**, wrong in both directions sometimes; it fails harmlessly
either way and the alternative is a tutorial almost nobody sees. It is not a
real session boundary and should not be read as one.

Two things that cost time here and are worth not repeating:

- **`set_anchors_preset()` does not resolve a Control's rect until the next
  layout pass.** The countdown numerals set their pivot and centring straight
  after it, against a rect that was still zero-sized, so they scaled about the
  screen corner and flew off it — created and freed exactly on schedule, just
  never anywhere visible. They now set `size`, `position` and `pivot_offset`
  explicitly.
- **Headless at `--fixed-fps 60` is not real time.** It runs unthrottled, so
  the countdown's 2.5 s of game time passes in about 3 ms of wall clock. Any
  test timing a card with `Time.get_ticks_msec()` measures nothing; the suite
  accumulates `get_process_delta_time()` instead.

### The river launches, and nothing happens until it has

It does not start at 204 px/s, it gets there over **three seconds**, on a
`smoothstep` from rest. **The game proper waits for it**: the pad director,
the hazards, chime spawning and the wind all stand down until the river is up
to speed, and the difficulty curve and every hazard debut clock measure from
`play_time()` — seconds of play — rather than from the gun, so the gentle
first minute is a real first minute of play.

That gate is not only taste. Chimes drift at a fraction of the current, so one
released at the gun visibly **hung** at the top of the screen waiting for the
water to catch up. The soak suite asserts the whole run-up stays quiet. Dropped straight into full speed the game reads as
starting mid-sentence: you are already in the current with no sense of having
been taken by it. A straight ramp would arrive at cruise with a visible corner
on it, so the ease matters as much as the ramp.

`current_speed()` is `cruise_speed() * launch_factor()`, and the split is
load-bearing: "how fast is the water moving" and "where is the difficulty
curve" are different questions, and the suite asks the second one of a game
whose clock has barely started. Fold them together and the curve becomes
unmeasurable. Hornets read neither — they fly, so they do not stall on the
start line.

### Two different promises about a hazard

These look redundant and they are not. Collapsing them loses the second one:

| | asks | guaranteed by |
|---|---|---|
| **reaction floor** | can a hazard I *know* be dodged? | ≥ 0.40 s on screen at top airspeed |
| **debut ramp** | can a hazard I have *never seen* be learned? | ≥ 0.90 s for the first ones |

A hornet on its debut used to fly at ~261 px/s — about 0.67 s on screen. That
clears the floor comfortably and was still too fast the first time, which is
what Neo reported. The player's clock does not start when the hazard appears;
it starts when they work out what it is.

So each hazard eases in from **its own debut** rather than from the global
curve: the first ones are slow, arrive further apart so they can be met one at
a time, and reach their real pace over the following forty seconds. The heron
gets the longer end of this (1.45 s of ring, against 0.95 s before), because
jumping does not save you from a dive — the ring *is* the dodge, and the
shortest warning in the game was landing on the dive players had least idea
how to read.

### Both hazards fly, and that is load-bearing

The jumpable hazard was a driftwood log for one round. It was wrong twice over:
a 56 px solid sweeping down a lane passed straight **over** the lily pads,
which is nonsense to look at, and it made draw order a permanent fight.

Putting it in the air removes the problem rather than disguising it. Nothing
above the water touches the pads, so the ordering stops being something to
manage and becomes the statement of the rule:

| | drawn |
|---|---|
| jumping | **player over the hazard** — clearing it looks like clearing it |
| grounded | **hazard over the player** — which is what being hit looks like |

Two traps live here, and both have already been sprung:

- **Godot's `z_index` on a child is relative to its parent.** `hazard.tscn`
  carried its own `z_index = 25` on top of the `Hazards` container's 25, so
  hazards resolved to **50** and drew over the airborne player — the rule
  shipped inverted while the whole suite passed, because the constants in
  `wind_leaf.gd` were right and only the scene was wrong. The layer belongs to
  the container; a hazard carries none of its own.
- **A hornet flies at its own airspeed, not the river's.** That is not
  tidiness. Tied to the current, a hazard at 480 px/s arrives in 0.38 s, under
  the reaction floor the suite enforces — it was rejected on exactly that. A
  flying thing has no reason to care how fast the water runs, so the warning
  stays inside human reaction time however wild the river gets. It is
  therefore *slower* than the late river, which is correct: it holds its line
  while the current tears past beneath it.

**The shake tops out around 10° of roll** with lateral sway, a **vertical
judder** and a scale dip — the judder being the one
that changes its character, because side-to-side alone is what *rattling*
looks like, and a thing being pulled under moves down as well and fights it.
The player sways with it: a pad thrashing under a character standing perfectly
still reads as two unrelated objects sharing a screen. That sway is written to
the sprite's own offset and never to the player's position, which the hop tween
and the recovery bob already drive.

Those numbers have been up and down: ±15° was called too weak, ±30° too much,
and this is a third of the latter — slightly *below* the version that was too
weak. That is deliberate. The shake no longer carries the warning alone: the
judder, the dip, the warmer red and the wider ripple all post-date the ±15°
version and all remain, and at this amplitude the **colour and the ripple
lead** while the motion supports. If it ever reads too subtle, raise these
three numbers rather than re-adding amplitude somewhere else.

**The shake is telegraphed three redundant ways at once** — an accelerating
wobble, a shift toward red, and a widening ripple — because it has to read on a
scuffed screen, from a few feet back, to someone who may not separate red from
green. The heron's warning is a **ring that tightens on its mark**, not a dark
blob: a dark blob on dark water is exactly the thing nobody sees coming.

### Controls: moving costs two inputs

- **`act` alone** → jump in place, airborne ~0.32 s. Its only purpose is the
  hang time, which is how a hornet passes under you.
- **`act` while holding a direction** → hop to that lane, 0.26 s plus a 0.10 s
  cooldown. Enough weight that the river cannot be crossed by drumming the
  stick, small enough not to feel sticky. A 0.16 s input buffer means a press
  during a hop is honoured on landing.
- **A direction alone moves nothing — but it still turns you.** The character
  faces wherever the stick points, hop or no hop. Without that she stared
  upstream while the player was plainly asking to go left, and the controls
  felt unhooked from the character even though they were working correctly.
  Mechanically, moving still costs two inputs: that is the change that makes
  everything else harder, and the gentle first minute exists to absorb it.

### How the director chooses which pad falls

Random, **with the player's position as a veto rather than a bias.**

`_pick_shake_lane()` builds a list of every lane whose pad is currently
`STABLE` *and* which passes `_leaves_escape_route()`, then picks **uniformly at
random** among them. The escape check is the player-aware half: it looks at the
three lanes reachable in one hop — `_lane-1`, `_lane`, `_lane+1` — and requires
at least one of them, other than the lane about to shake, to still be available
(pad safe *and* no heron diving on it).

So it never aims at the player and never spares them either. **Their own lane
is exactly as likely as any other.** The only thing it refuses is a choice that
would leave them nowhere to go. That is why a run can be unlucky but not
unwinnable, and why a frame-perfect bot never dies: that is the guarantee
working, not a bug.

### The river comes for you, more so as it goes

`_pick_shake_lane()` used to pick uniformly among eligible lanes, so your own
pad was a flat **1 in 5** for a whole run and most of it was watching other
pads sink somewhere else -- pretty, and not very threatening. It now ramps to
**2 in 3** by the end, from *exactly* the uniform share, so the opening is the
draw it replaced rather than an approximation of it:

```gdscript
var own := lerpf(1.0 / float(candidates.size()), OWN_LANE_SHARE, _intensity)
```

The eligibility rule needed no change -- a lane the player cannot escape from
was never a candidate -- but **the time did**. `SHAKE_TELEGRAPH` bottoms out at
0.30 s, which is fine for a pad across the row and is an unreactable eviction
notice under your own feet, where it has to cover a reaction *plus* the 0.26 s
the hop itself takes. Your own pad now always gets at least
`OWN_TELEGRAPH_FLOOR` (0.60 s). Uniform selection had hidden that behind a
1-in-5 chance; at 2-in-3 it would have been the whole late game, and
unsurvivable.

One mercy the design gets for free: once your pad goes you are in the water,
and that lane is not `STABLE` -- so not a candidate -- for a couple of seconds.
The share can rise all it likes; the duty cycle caps how often it can actually
happen.

### The director never corners you

The oldest guarantee in the game, and now the easiest to break: **two**
directors place things, and each one checking the rule alone is not enough — a
heron on one lane plus two pads shaking on the others leaves the player
choosing between drowning and being hit. So both ask the same question,
`_lane_available()`: the pad holds *and* nothing is diving on it.

A hornet does **not** disqualify a lane. A lane with a hornet coming down it is
still somewhere you can stand, because you can jump it — that is the entire
reason jumping in place is a verb. A dive takes its lane away from everyone, so
it is only allowed when the player is still left a lane they can reach in one
hop and actually stand on.

### Lives and scoring

Five lives, tracked internally in **halves**: a hazard takes 2, going in the
water takes 1. Water staying a half keeps the original forgiveness for the
mistake beginners make constantly, and reserves the real cost for the things
you are meant to be dodging. Losing one brings a flash, a camera kick, the
chain, and a 1.1 s mercy window so a single hornet cannot cost three lives.

Score is two halves:

- **Chimes** — +80 × a chain multiplier stepping up every three chimes to ×5.
  Splashing costs 150 **and** the chain, so water hurts twice.
- **Survival** — paid per second and **scaled by intensity**, 20/s early rising
  to 85/s late. The last thirty seconds of a good run are worth more than the
  first two minutes, which is what gives a skilled player something to chase.

**Open question, not solved here:** an endless game produces unbounded scores.
Measured runs land between ~5,000 and ~19,000, against the **2,500–4,500** band
the eight games were tuned into for a shared high-score table. `par_score` stays
as a nominal 1,800 for the shell's sake; settle it when the card draw returns.

### The river

Everything scrolls, in one direction, at a fraction of one number:
`CURRENT_START` → `CURRENT_END` in `wind_leaf.gd`, now **68 → 240 px/s** —
opening at double the old river's 34, because "an aggressive river, not just a
calm one" was the literal ask. `LAYER_SPEEDS` in the same file is the whole
parallax stack:

| Layer | × current |
|---|---|
| treeline, past the bank | 0.35 |
| water depth | 0.38 |
| water surface | 0.45 |
| water glints | 0.60 |
| river litter | 0.50 |
| speed streaks | 1.25 |
| bank, waterline, bank props | 1.00 |

Different speeds in the **same** direction is the oldest depth cue in 2D, and
it is what sells travelling rather than sliding. Nothing in the scene sets its
own speed any more.

### Two scroll bugs worth never repeating

**`ScrollingTexture` and `ScrollingProps` disagreed on what a positive number
meant.** The texture one advances a `region_rect` offset, which slides content
*up*; the props one adds to `position.y`, which moves children *down*. Both
were set to `(0, 46)`, so the grass and the shoreline crawled backwards past
the trees standing on them, at 2.8 px/frame each way. It survived a soak run
and three rounds of screenshots; it took a player to say the grass looked
wrong. `ScrollingTexture` now negates internally so **positive Y means down**
everywhere, and `tests/soak_test.gd` drives both scrollers and fails if they
ever disagree again.

**Freezing the water to stop a pixel-snap tick made it look dead.** The real
culprit the round before had been the three-frame flipbook jumping 3px four
times a second, not slow drift. A surface that does not move at all reads as a
sticker over the river. The base layer moves again; the measured frame-to-frame
change over the water went 3.9 (frozen) → 17 early → 21 late, and the curve is
*flat*, which is the difference between flowing and strobing.

Three things about the surface are worth not undoing:

- **No mark spans the tile.** The first water tile drew a full-width dark line
  every 12 rows out of a 32px tile. Continuous lines read as corrugated metal;
  32 is not divisible by 12, so the pattern also broke at every seam; and the
  three "shimmer" frames each shifted the bands 3px at 4fps, so the stripes
  teleported four times a second. It is now one 64px tile of broken streaks and
  soft mottling, seam-checked numerically, with **no flipbook at all**.
- **The base layer is pinned at zero, not merely slow.** Textures snap a whole
  pixel at a time under nearest filtering, and one game pixel is three on
  screen at 1080p, so a surface creeping at 4 px/s ticks visibly once a quarter
  second. Anything slow here either does not move or twinkles while it does.
  Life comes from `WaterGlints` drifting over the top, the twinkling glint
  field, and the litter.
- **The shoreline ends in alpha, not in a colour.** Three attempts: a straight
  vertical cut; sand so wide and bright it read as a dirt path; then shallows
  drawn as an opaque rectangle, which simply moved the straight edge a few
  pixels right. The tile now fades out across its last third and the river
  shows through, and `BankLeft`/`BankRight` stop *short* of the fade — when
  they did not, the fade revealed grass and hid the cut rather than removing it.

`src/core/scrolling_props.gd` exists because `ScrollingTexture` scrolls a
`region_rect`, so anything parented to it never moves: that is why the trees
used to stand perfectly still on a bank racing past them. It carries
hand-placed children and wraps them; the litter and the speed streaks use the
same node.

### Selling speed

The techniques here are the standard ones, and they were researched rather than
guessed: **camera distance is the strongest lever** (widening the field of view,
or equivalently moving the camera closer, is repeatedly cited as the simplest
effective speed cue), **shake should be small and event-driven** rather than
constant, **peripheral motion** is where speed is read, and **you fake speed
rather than raising it**, because raising real velocity breaks balance. So
`CROSSING_SECONDS` and the difficulty bands have never moved.

Beyond the parallax: **streaks** stretch and brighten with the current and are
**weighted toward the banks**, because peripheral motion is where speed is read
and the middle of the river is where the player is reading pads. **Chimes
arrive twice as often** by the end. `src/core/game_camera.gd` supplies a 1.06
push-in; it zooms *in* rather than out because zooming out would shrink a
character already called too small twice. `max_zoom = 1.0` turns it off and the
measured pixel-fidelity cost is in that file.

**The shake had to be rebuilt.** The first attempt was ±1 *game* pixel at 7 Hz
and rounded, which at 3× screen scale snapped three screen pixels at a time,
dozens of times a second, across the whole world. Neo called it an earthquake
and he was right. Two things fix it: a third of a game pixel is exactly one
screen pixel, so working in fractions and **never rounding** lands in the one-
to-two screen pixels a light shake is supposed to be; and a constant sine is
the wrong shape, so most of the shake now arrives as **bursts that decay**
(`kick()` on a landing, a sinking pad, a splash) with only a trace continuous.
Measured after: peak offset 1.15 screen px, largest per-frame step 0.45 px.
`shake_scale = 0.0` turns all of it off, which constant shake should always
allow.

### The wake

The pads and the player hold their screen position, so without something else
the river slides past them and they read as moored rather than travelling. Each
pad and the player shed **foam that streams downstream and fades**, more often
and further as the current rises. It is the cue that says "this is moving
through the water", and it is why the pads did not need to be rebuilt into a
streaming row to stop looking anchored.

The crossing meter also left the top-right corner, where at 77×7 px it was
small enough to finish a run without noticing, and became a band across the
top with a marker riding the fill.

### The hop has a pose

There are no drawn jump frames, and inventing some would not match the
hand-drawn set, so the jump is **posed procedurally** in
`src/core/player_controller.gd` — `start_jump()`, `set_jump_progress()`,
`land()`, `cancel_jump()`. It lives on the shared controller, not in Riverleap,
so any later game that jumps gets the same weight:

- the walk clip paused on a mid-stride frame, because a tucked, legs-apart pose
  reads as airborne where a looping walk reads as running on the spot;
- stretched while climbing and while dropping, neutral at the apex, which is
  where a real body is least deformed;
- a lean into the direction of travel, peaking at the apex;
- the shadow shrinking and fading — the only thing telling the player how high
  they are;
- a hard squash on touchdown recovering over 0.17 s. **This is the part that
  sells the weight**, and it is the one to protect if anything here is tuned;
- a few warm motes kicked up at the feet on take-off and landing.

It always poses from **one clip, mirrored** (`walk_right` frame 1, with
`flip_h`). The two side walk sets are not mirrors of each other: `walk_right_*`
strides in three of its four frames and `walk_left_*` keeps the legs together
in all four. Posing from `walk_<facing>` therefore gave a stride hopping one
way and none hopping the other, which is exactly what it looked like.

The arc went from 11 px to 18 px at the same time. At 11 the hop was a slide
with a shadow: a quarter of a second is not long enough for a pose to register
unless the movement under it is legible too.

Left side-on after a hop, the character used to stay that way indefinitely,
which read as having stopped caring about the far bank. Half a second after the
last hop they turn back upstream.

### The pads

`wind_leaf/leaf_*.png` is a lotus pad: a foreshortened disc with a wedge notch
and veins radiating from it. The notch is mechanical, not decorative — it gives
the pad an orientation, so the wobble that warns you it is about to sink reads
as rotation instead of as a shimmer. Four float frames carry a highlight round
the rim; three sink frames tip it under. Pads start on a random frame, because
five pads drawing the same frame at the same instant read as one object
repeated five times.

**The pads ride one swell.** Each is given a wave phase a fifth of a cycle from
its neighbours, so the bob reads as a single swell crossing the river rather
than five pads twitching on their own timers -- which is what a random phase
gave. The soak suite asserts the phases stay distinct and that they show up as
real spread in where the pads sit.

**The glint does not travel.** It used to walk around the rim across the four
frames, which at 4 fps is a full lap a second: a loading spinner, and that is
exactly what it looked like. The light now sits top-left like everything else
lit in this scene and the frames animate the *shape* instead.

The float cycle also runs up to 3.2× faster while a pad is shaking. That is a
*fourth* warning cue on top of the wobble, the colour shift and the widening
ripple — all four stay, because this is the only thing the game ever asks the
player to read in a hurry.

### The weakness that was answered, and what is left of it

This section used to read: *"stripped of decoration this is one binary choice —
left or right — repeated for a full minute,"* with five candidate answers and
the note that nothing was committed until it had been played. It was played.
The endless redesign took **three** of the five: intensify rather than fill
(the curve), a second verb (jump in place), and threats that are not pads
(logs, herons). Two are still open and still unclaimed:

1. **Make chimes the game, not the sprinkles.** If they spawned in chosen lanes
   and the chain required consecutive pickups, every hop becomes *routing* —
   which lane do I want to be in three seconds from now — rather than a
   reaction. This is the strongest remaining idea, and it is the one that would
   reward planning instead of reflexes.
2. **Leaf variety**: one that sinks on landing, one that springs you two lanes.

### How hard it actually is

Measured by the soak bot, which reacts in 3 frames with perfect information,
run against a copy of itself slowed to human reaction lag.

Re-measured after the curve was stretched, the row dropped and regen sped up.
**Three trials per lag**, means in brackets; read them as bands, since the
spread within one lag is wider than the gap between some of them.

| Bot reaction lag | Survives | Score |
|---|---|---|
| 50 ms (frame-perfect) | **never dies** (capped at 7 min) | — |
| 133 ms (expert, anticipating) | 245–312 s (276) | 17k–22k |
| 216 ms (average human) | 225–252 s (241) | 13k–16k |
| 300 ms (slow) | 98–158 s (118) | 4k–8k |
| no input at all | ~77 s | ~2.9k |

The target was a beginner at roughly two minutes, against ~90 s before, and the
mean landed at 118 s. The expert band went **up** (212–238 s → 245–312 s)
rather than down, which is the point: the climb got longer, the game did not
get flatter. Each round of easing has lifted the expert band most, which makes
sense — a player who reads hazards well gains most from anything that buys
reading time.

**The guarantee is instantaneous, not predictive, and that limit is real.**
`_leaves_escape_route()` is evaluated against where the player is standing when
a pad is chosen; nothing can evaluate it against where they might hop next. Over
long runs the bot does occasionally hop into a corner — diagnosed precisely as
`lane=0, pads=[SHAKING, SHAKING, STABLE, GONE, GONE]`, landed that same frame,
with a safe lane two hops away that it had just moved away from. Both pads were
telegraphing before the hop, so the information was on screen; it moved toward
the edge on stale information and ran out of room against the wall.

The suite therefore asserts that the **directors never create** a corner, and
ignores the third of a second after a landing. Asserting a flat zero would be
asserting something the code does not promise, and the first bad hop would have
blamed the director for it.

Two things worth reading off that table. **A perfect reactor never dying is not
a bug** — it is exactly what a strict never-corner guarantee promises, and it
means the skill ceiling is set by human reaction rather than by a wall. And
**every trial at every lag has recorded zero cornered frames**, through every
round of tuning, which is the number that actually matters: the game got much
faster without ever becoming unfair.

---

## 7. Acorn Storm (`acorn_storm`) — *dodge, catch*

Stand in a clearing under an oak in a gale. Things fall out of the canopy.
Acorns hurt; sunfruit is the only thing keeping you alive.

**The bar is always going down.** It drains slowly at first and faster the
longer you last, catching sunfruit is the only way to put anything back, and
the run ends when it empties. There is no clock and no round.

### Why the bar replaced a sixty-second round

The parked version of this game was a fixed round with a score, and it had a
hole in it: **fruit was optional**. Dodging alone was a perfectly good
strategy, so the "catch" half of a dodge-and-catch game never mattered — you
could play the whole minute without once choosing to go somewhere.

A draining bar makes fruit the thing keeping you alive rather than the thing
adding to a number. Every design consequence below follows from that one
change, and the biggest is this: **an unreachable fruit now costs a life, not
some points.** Whether the player could physically have got there moved from a
nicety to the single most important property in the game, and it is the first
thing `tests/acorn_test.gd` asserts.

It is also the second game to take a fail state, for the reason §6 gives: it
is what a good player is for. The compromise is the same — a gentle opening.

### The bar, exactly

| | effect |
|---|---|
| time passing | drains at `lerp(0.0085, 0.082, intensity)` per second |
| catching sunfruit | `+0.092`, up to `×1.35` on a full combo |
| taking an acorn | `−0.14`, plus a 0.55 s stun and the lost points |

Starts at 0.68, not full: a bar that opens at 100% gives the first fruit
nothing to do, and the player learns what fruit is **for** by watching it move.

The stun is the worse half of a hit. You cannot catch while you are seeing
stars, so the drain carries on and the fruit that was going to save you lands
somewhere you are not. A hit costs more than a hit.

It uses the HUD's **continuous meter**, not the segmented heart bar Riverleap
uses — a drain reads as a falling fill, and five discrete chunks would hide
exactly the slow slide the game is about — with a leaf icon beside it so the
bar never needs a word.

### The game was getting smaller as it got harder

The first version of this section called the shrinking reachable area the
reason "the late game is hard". That was wrong, and it is the most useful
mistake in this document.

Fruit must land within walking reach, and reach is `speed x (fall - reaction)`,
so every cut to the fall time also cut the circle the player worked in:

| | fall | reach | mean trip |
|---|---|---|---|
| early | 1.60 s | 120 px | **62 px** |
| mid | 1.27 s | 90 px | 50 px |
| late | 0.95 s | 60 px | **37 px** |

In a field 388 px wide the late game was a shuffle inside a 98 px circle. The
game got *smaller* as it got harder -- which is why it played flat, and why
the sprint button never mattered. **Every check in the suite passed the whole
time**, because every fruit really was reachable: reachability was never the
problem, and nothing was measuring size.

Two changes fix it, and they are really one. The gale **carries the player
too** (`SPEED`, 92 to 185 px/s), which is what lets the fall drop to 0.85 s
without the field collapsing. And the distance roll is **directed**: an
exponent that falls with intensity drags the mean out toward the edge of what
is reachable, so late fruit is a committed run rather than a drift.

Reach itself cannot be made to rise, which is worth knowing before anyone
tries again: a reaction costs a flat 0.30 s whatever happens, so a 0.85 s fall
leaves 0.55 s of travel against 1.30 s early. No sane walking speed covers a
handicap that size -- chasing one put the player at 240 px/s across a 388 px
field. Biasing *within* the circle does what enlarging it could not.

Mean trip now runs **66 74 78 77**, and `tests/acorn_test.gd` asserts that the
second half of a run beats the first.

### A safety clamp quietly herded the player into the wall

The second distribution bug in this game, and the same shape as the first.

A sunfruit's spot was a uniform direction **clamped** into `FIELD`. A clamp
maps a whole half-plane of directions onto the boundary, so with the player
against the right wall: half of every roll got flattened, the mean landing x
came out at **409 against a field centre of 240**, and **every** accepted spot
was in the outer quarter of the field. One drift to an edge and the rest of
the run happened there -- which is exactly how Neo described it.

Two fixes, because they do different jobs. Candidates outside the field are
now **rejected and resampled** rather than clamped, which stops the pile-up;
and the direction is **pulled toward the centre** in proportion to how far
off-centre the player is (`CENTRE_PULL`), which is what actually brings them
back. Rejection alone would only stop the game pushing outward.

Worth generalising: **a clamp is not a neutral safety net.** It does not drop
the out-of-range cases, it piles them all on the limit, and the result is a
distribution with a spike exactly where nobody looks. Both of this game's
distribution bugs -- the shrinking bubble and this one -- were invisible for
the same reason: every test measured a *distance from the player*, and none
measured *where on the field things actually land*.

### Fall time is the number everything hangs off

`lerp(1.60, 0.95, intensity)` seconds from the canopy to the ground.

A player walks at 92 px/s, and before they have reacted they have not moved,
so the radius they can actually cover is

```
reach(fall) = 92 × (fall − 0.30)        # 0.30 s is a slow human's reaction
```

which is **120 px early and 60 px late**, in a clearing 388 px wide. The
fraction of the field you can get to collapses as the run goes on, and that —
not "more acorns" — is why the late game is hard.

Three rules fall straight out of it:

- **Sunfruit lands within reach, every time.** Chosen from the player's
  position, at a distance between 26 px (or it is not a trip worth making) and
  `reach × 0.82` (the margin pays for the diagonal, the field clamp, and
  nobody running in a straight line). In the open field it would land wherever
  it liked, the player would watch most of it fall, and the bar would empty
  through no decision of theirs.
- **Acorns aim at where you will BE** — your position carried forward by a
  quarter of your own travel early and most of it late — and are then
  scattered by a random offset that shrinks from 74 px to 18 px. The scatter
  is what makes standing still survivable at the start and fatal at the end:
  a stationary player is hit whenever the roll lands inside the acorn's
  14 px, about 4% of throws early and about 60% late.

  The first version threw into a *ring* around the player whose inner radius
  never went below the hit radius, so a player who never moved could not be
  hit **at all** — the exact opposite of the rule it was written for. Nothing
  in a screenshot shows that; the suite found it by running a motionless bot
  for 45 seconds and reporting zero hits.
- **Except when that would corner you.** Before an acorn is placed, the
  director samples the disc the player can reach — including the spot they are
  already standing on, because staying put is an escape and the one good
  players use most — and asks whether any of it is clear of everything
  arriving at about that moment. If not, it picks again, up to twelve times,
  reaching slightly further out each time. Being cornered is this game's
  version of Riverleap's whole row going under at once: not difficulty, an
  unwinnable frame.

  **The question is asked when the acorn is thrown, and only then.** Asked
  again every frame of its flight it answers "no" as a matter of arithmetic —
  a fifth of a second before it lands there is nowhere anyone could get to,
  which is what a hazard *is* rather than a failure to leave a way out. The
  first version of the test asked per frame and reported dead ends that were
  simply acorns about to land on a player who had not moved.

- **And never stacked on a sunfruit.** A hot ring drawn over a gold disc says
  "danger" and "take it" about the same square of grass, and a player cannot
  act on that. A placement that would stack the two is passed over when there
  is any other — a preference, not a refusal, because an acorn aims at the
  player and a player standing on a fruit has to be a target like anywhere
  else. Measured at 2% of frames; the suite fails above 4%.

### The first sunfruit lands before the first acorn

Always. "Gold is good" has to be learned before "red hurts", or the first
lesson the game teaches costs a life. The first acorns also fall 38% slower
and come singly, easing off across the first fourteen seconds of play.

### Two marks, and they differ by shape

An **open ticked ring** for an acorn, a **filled gold disc** for sunfruit.
Both tighten onto the spot as the thing falls, so the mark is the warning and
the clock at once.

Colour is the second cue, never the first. Riverleap's dive marker was redrawn
twice to learn that — and the greyscale test is the one that means anything,
because a cabinet screen gets scuffed and some players do not see red.

### High octane without a scrolling world

Riverleap gets its pace from a river moving at 480 px/s. This game is played
standing still in a clearing, so the ground cannot move — a clearing that
scrolled would read as a conveyor belt. Everything that moves here is **wind**:

- the canopy sways harder and faster as the gale builds
- dappled shade travels through the leaves across the ground
- torn leaves blow across the field, their speed driven by the same number
- gusts every `lerp(4.4, 1.3, intensity)` seconds shove the camera's **zoom**,
  not its position — what a gust has to read as is forward pressure, and a
  camera that shook would read as an impact
- a squirrel pops out of the canopy above each acorn as it is thrown, so the
  eye has somewhere to go before the mark appears

### How hard it actually is

Raised twice more after shipping, both times on "still too easy".

**The curve first.** Full pressure now arrives inside 90 s rather than past
three minutes, with five acorns in the air instead of four, thrown faster and
aimed tighter. Six at once was tried and backed off: at that density there was
no safe route to a sunfruit, chasing stopped paying for itself, and the game
slid back toward "just dodge" -- the exact failure the draining bar exists to
fix. **Density has a ceiling set by the fruit having to stay worth going for.**

**Then the rate, not the curve.** Fruit, acorns and the drain all climb
together at the top end, so there is more to do every second and less room to
coast. Moving them in step is the point: the drain alone would be harsher
without being busier, and the fruit alone would be easier. The ratio between
supply and drain is preserved, so a flawless player still cannot be killed by
arithmetic.

Bots at three reaction times, five runs each, chasing fruit and dodging:

| reaction | mean | worst run | at launch |
|---|---|---|---|
| 133 ms | 84 s | 71 s | 200 s+ (never died) |
| 216 ms | 63 s | 51 s | 188 s |
| 300 ms | 49 s | 40 s | 123 s |

A 300 ms player is a stranger who has not worked out the controls. They get
about fifty seconds here against **126 s in Riverleap** -- the two games are
deliberately not equally hard, and the normalised table accounts for it
through each game's own `PAR_SECONDS` rather than by matching their lengths.

**A perfect reactor does not die**, and that is what the two guarantees above
promise: fruit always lands within reach, and there is always somewhere to
stand. The ceiling is human reaction, not a wall. Riverleap has the same
property for the same reason.

Two notes on measuring it, both of which cost a round:

- **One run is an anecdote.** The first measurement had a 133 ms bot dying
  sooner than a 300 ms one. With five runs per lag it still did, until the bot
  stopped re-choosing its target every frame — a bot that dithers dithers
  *worse* the faster it reacts, which is a fact about the bot and nothing at
  all about the game. A player picks a fruit and goes; the bot now does too,
  and the ordering came out monotonic.
- **The bot is not a player.** It knows every landing spot exactly and to the
  millisecond. The lag models reaction, not reading a field, so treat these as
  an upper bound on an equivalent human.

### Par moves with the difficulty, and that coupling is easy to miss

`PAR_SECONDS` is what the letter on the results card is cut from. Making the
game harder without moving it silently regrades everybody: at the old par of
120 s a strong 90 s run came out a **C**, which reads as the rank being
broken rather than as the game being hard.

| run | par 120 | par 75 |
|---|---|---|
| 60 s | C | C |
| 90 s | **C** | B |
| 120 s | B | **A** |
| 150 s | B | **S** |

**Anything that changes how long a run lasts has to move this too.**

### Scoring

70 per sunfruit at ×1, up to ×4 on a chain of twelve; a hit costs 60 and the
chain. Survival pays `lerp(6, 26, intensity)` per second, so the last half
minute of a long run is worth more than its first two.

The reported number is the sum. The **normalised** 0–1000 that goes alongside
it is computed from how long the bar was held up, against a 75 s par — see
§5, *Endless games are compared on how long you lasted*.

### What the pictures caught that the tests could not

Four things, in one round, none of which any assertion would have noticed:

- **The clearing read as a pond.** Its texture was wide flat hard-edged
  ellipses, which is what a lily pad looks like from above — a shape this
  project has drawn before and should have recognised. Short grass strokes at
  low contrast fixed it, and killed the visible tile seam as a side effect:
  there is no shape large enough for the eye to match across the join.
- **Both ground marks were washed out.** Their alpha ramped up from 0.45 as
  the thing fell, which put the warning at its faintest exactly when it is
  needed — the hot ring came out muddy brown over the grass and the gold disc
  came out a pale sage blob, which is word for word the failure Riverleap's
  dive marker had twice. They now start at 0.82.
- **The shade layer had turned the clearing into soup**, dark enough that the
  player and both marks had to fight to be seen against it.
- **The intro slides drew the figure under the ground marks**, because a slide
  figure defaults to z 0 while a real faller carries its own 4 and 40. The
  slide teaching the draw-order rule was showing it backwards, and on one
  slide the character was entirely hidden inside a gold disc.

Which is the same lesson Riverleap recorded and worth repeating: **use the
picture for what it looks like and the test for what happened.** Neither
substitutes for the other, and this round needed both in opposite directions
again — the pictures caught four things 175 passing checks did not, and the
tests caught an un-hittable player that looked perfectly fine.

---

## 8. Hush Meadow (`hush_meadow`) — *forage*

A meadow that slides down the screen and off the bottom while you work it, and
carries you with it. Endless; the run ends when the **nerve meter** fills.

Game three, and the first one restored from the parked eight rather than built
from nothing. What came back was `PatrolBird` — a drawn cone of sight,
suspicion as a slow fill, and a fix for a facing twitch — and one line from the
old header, flagged there as the important one and never actually load-bearing:
**dew only appears once you are standing inside a grass patch**. Everything
else, including the five-section meadow and the following camera, was thrown
away.

### The two decisions the rest falls out of

**The meadow scrolls, and she rides it.** Grass drifts down and leaves, so the
patch you are standing in has a few seconds left in it — and so do you, because
standing still rides you to the bottom edge. Cover is a route, not a den, and
the meadow is a current to walk against. It is also what keeps this game from
being Acorn Storm with different sprites — that one is a bounded field you move
around inside, and so was the parked version of this one.

**Nerve rises always, and only pickups bring it down.** Standing in grass
nearly freezes the rise; it never lowers it. Hiding buys time and never
progress, so a player who only hides loses slowly rather than living forever —
which is the hole every "cover restores you" stealth design has.

Together they make one loop:

> run to a patch → hidden, the rise freezes → dew reveals *because* you are
> inside → collect it, nerve drops → the patch is already sliding off → cross
> open ground to the next one, exposed, with a cone sweeping toward you.

Structurally this is Acorn Storm's loop — a meter that runs out on its own and
a pickup that is the only thing holding it back — which is the part of that
game that works. What is new is that the pickup is **somewhere you have to go**
rather than something that comes to you.

| state | nerve |
|---|---|
| open ground, unseen | +0.022/s → +0.070/s |
| inside a bird's cone | **+0.42/s** |
| inside grass | +0.016/s — frozen, never lowered |
| pinned against the bottom edge | **+0.75/s** — overrides grass and cones |
| dew collected | −0.42 |
| petal collected | −0.09 |
| spotted | +0.18, a swoop, a stun, −100 points |

Note what the two ends of the open rate do to the value of cover: early,
hiding is worth about 1.4× standing in the open; late it is worth 4.4×. Cover
mattering **more** as the meadow runs out of it falls out of those two numbers
rather than needing a rule of its own.

### The meadow is spaced, not counted

The director held a target *number* of live patches for a round, and it does
not work. Each new patch is planted above the last, so the queue stretches
hundreds of pixels off the top of the screen and most of the quota sits
somewhere nobody can see: a target of **seven measured as 2.2 patches actually
on the field**, and lowering it to three changed almost nothing.

Density in **space** is the right control for a scrolling world — the river
works the same way. `PATCH_GAP` runs **46 px → 92 px** of meadow between stands
of grass: 3.6 patches on the field early, 2.8 late, and cover from 69 px away
from an average spot to 108 px.

It was 52 → 128 while the meadow ran at 18 → 52 px/s, and the gap had to move
with the scroll, because patches **arrive** at `scroll / gap` per second. When
the scroll slowed to 16 → 38 for the change below, the old gap starved the
meadow — late dew worth 0.98× the open rise — and even at 100 the bots found 9 %
less dew per second than before, which is exactly how far arrivals had fallen.
46 → 92 puts arrivals back where they were. The late game's thinning is gentler
in space than it was (108 px, not 191) because the pressure moved: holding your
ground against 38 px/s is now most of it.

### Where the late game's pressure is allowed to come from

Not from the meter and not from the meadow being sparser still, because both
are capped by an arithmetic floor: **the dew on offer has to be worth more
nerve per second than the open meadow costs**, at every point on the curve, or
a run ends on a sum rather than on anything the player did. That check sat at
**0.97×** once and would have shipped exactly that game.

Birds were the obvious remaining lever and they are a trap. Going from five to
seven does shorten runs — but it shortens the *foraging* run and lengthens the
*hiding* one, because crossing open ground is precisely what birds punish. It
pays the cautious player and undoes the thing the design is for. Birds stayed
at **1 → 5**.

### The guarantee, with a second half

Every game here rejects a placement that would corner the player. This one's
version is harder, because cover **expires**:

> there is always a patch she can reach at walking pace, minus a slow human's
> reaction time, that will **still be on the field when she arrives**, and that
> is not currently inside a cone.

Reaching it is a walk, plus a wait for anything not on the field yet. She and
the patches ride the same meadow, so relative to the grass she is only ever
walking: distance over `WALK`. But the field stops her at its top edge, so a
patch still above it is not a short walk away — it is a wait at that edge for
the meadow to bring it down. `reach_time()` takes the longer of the two.

That second term is not the old interception coming back; for anything already
on the field it is zero. It is what the first distance-only version missed, and
the bot found it the hard way: it walked up to the top edge to wait for grass
that had not arrived, which is where birds come in, and died in ten seconds.

The floor is checked **every frame**, not only while topping the meadow up,
and that distinction is the whole fix. Late on the meadow holds three patches,
so the quota is met while all three are behind her, under an eye, or about to
go over the edge: the count is fine and there is nowhere to go. It measured as
a 2.03 s dead end before the check moved.

### She rides the meadow, and the bottom edge bites

Neo, after playing it: *"the player does not follow the scrolling, rather goes
up along with the camera — I think this is a bug."* It was. `_scroll_world()`
moved patches, props, blockers, pickups and birds, the camera is fixed, and the
player was not in the list — so the ground slid out from under a figure pinned
to the screen and grass passed through her like scenery. Things on the ground
move with the ground. `hush_test.gd` now checks she moves exactly as far as a
patch does, and it was verified by deleting the one line that carries her.

The fix Neo chose has a second half. Carried, a player who never touches the
stick reaches the bottom edge about six seconds after GO, so the edge became the
meadow's one boundary: **pinned against it, nerve rises at 0.75/s** — nearly
twice what a bird's eye costs, in grass or out, because riding a patch down to
the edge and sitting in it is exactly the safe corner this design removes. The
HUD's edge alarm comes on from the first pinned frame and the first pin of a
run says KEEP UP once. One push of the stick gets her off.

This closed a real hole. Standing still used to be free — fresh cover arrived
on its own — and now it costs ground, which is the relationship Riverleap has
with its river and the reason Neo keeps citing that game as the one that feels
right.

What changed with it, and why each number moved:

- **`WALK` 70 → 85, `SCROLL` 18 → 52 became 16 → 38.** Before, standing still
  on screen meant being lifted up through the meadow for free at the scroll
  speed, so her approach to new cover — which always arrives from the top — was
  walk *plus* scroll: 122 px/s late. Riding takes that lift away. At the old
  numbers she would have made 18 px/s of headway late on; now it is 47. A faster
  walk (92) was measured and bought nothing, so it was not kept.
- **`MERCY_SECONDS` 1.1 → 1.6.** After a spotting the bird swoops onto her, then
  flies back along its lane. While she was pinned to the screen the meadow's
  drift separated them during her mercy window; once they rode it together, a
  bird whose lane ran the way she fled followed her with its cone on her and
  caught her again the moment mercy ran out — 0.65 s of movement after the
  stun, 55 px, inside a 78 px cone. Found in a traced run that died at 13 s.
- **The bottom edge costs a stranger something.** A player who touches nothing
  lasts **6 seconds** once the meadow is up to speed (the run is over about 8 s
  after GO), against 35 s before. That is the
  direct price of the rule Neo chose, and it is the one number here that runs
  against the gentle-opening principle in §5. The alarm and KEEP UP are what
  stand between a confused first-timer and it. If it proves harsh at the
  cabinet, `NERVE_PINNED` is the single knob.

### Two things that were invisible until somebody looked

**Dew in an overlapped patch never revealed.** The reveal compared the patch
against the one `patch_at()` returns, and `patch_at()` answers with the first
match. Patches overlap, so wherever two stands of grass touched, the single
rule this game is built on failed silently. It is asked of each patch now.

**A patch holding dew has to be visible from outside it.** Dew is invisible
until you are inside, so with nothing marking which patch is worth entering
there is no way to *choose* one — and since the meadow carries fresh cover to
you anyway, the best play is to stand still and let it arrive. The first
marker shaded the cover disc, which lies under thirty-odd blades at 58 % alpha
on dark green and could not be seen at all. It is a pale mote **above** the
grass now, gold for the prize. What it says is that something is there, never
what: walking in is still the only way to find out.

### How hard it actually is

Bots at three reaction times, **twenty runs each**:

| | 133 ms | 216 ms | 300 ms |
|---|---|---|---|
| survived | 108 s | 85 s | 95 s |

Pooled: mean 96 s, median 84 s, ten of the sixty at the suite's 170 s cap.
`PAR_SECONDS` is **95**, set from that table, so par (a minute and a half) is a
B and twice par, just over three minutes, is an S. It was 120 against a table
of 119 / 119 / 108 before she rode the meadow; runs are shorter now because
holding your ground is no longer free, which is the point, and par moved with
them so nobody is silently regraded.

Sixty runs, not the suite's eighteen, because eighteen swing too much to set a
number from: the unchanged old build read 119 s on 4.7 and 136 s on 4.6 at the
216 ms column. The comparison that was stable was **rates per 100 s of
survival** — and by those the riding meadow is nearly the same game as before:

| per 100 s | watched | spotted | dew | petals | pinned |
|---|---|---|---|---|---|
| before riding | 3.3 s | 10.1 | 19.6 | 20.2 | — |
| riding, as shipped | 2.9 s | 9.1 | 19.2 | 21.6 | 0.17 s |

Early deaths did not get more common: runs ending inside 45 s were 8 % of sixty
against 17 % of eighteen before.

Reaction time matters less here than in either other game, and that is honest
rather than a tuning failure: nothing in this game has to be dodged on reflex.
What it costs you is route planning — which patch, by which line, past which
cone.

The strategy claim is measured on **dew per second**, not on how long a run
lasted. Survival time cannot carry it: six pairs of whole runs on one unchanged
build gave hiding 61 s / 87 s / 96 s against foraging 137 s / 102 s / 88 s, so
the claim came out true, false and true on the same code. Dew rate is stable
and is the claim anyway, since dew is the only thing that lowers the meter:
foraging finds **0.180 dew/s against hiding's 0.043** (0.177 against 0.062
before riding — a hider who rides her patch to the edge now pays for it).

---

## 9. Testing

```
tools/run_tests.sh          # or GODOT=/path/to/godot tools/run_tests.sh
```

One suite per game, discovered automatically — `tools/run_tests.sh` runs every
`tests/*_test.tscn` and sums their exit codes, so adding a game means adding a
file rather than editing the script. They stand on `tests/soak_base.gd`, which
holds the parts that are not about any particular game: check counting,
reporting, input synthesis, frame pumping, and `effective_z()`.

That split happened when the second game arrived. With eight coming, a hundred
checks copied eight times would have drifted apart within a round.

### What Riverleap's suite holds

`tests/riverleap_test.gd`, 101 checks. It used to prove that the game could be
**finished**; Riverleap is endless, so that property no longer exists and six
others took its place:

- **The opening is survivable** — a competent bot must last ≥ 45 s. This is
  "gentle first minute" turned into an assertion, and it is what fails if a
  later tuning pass makes the opening brutal.
- **A run does end** — a bot that never touches the controls must lose all five
  lives and report exactly once. Losing is the endless loop's only exit.
- **Hazards can be reacted to** — measured on standalone hazards at the worst
  case the game can produce: a hornet at its top airspeed must be on
  screen ≥ 0.40 s before it strikes, and a heron's ring must be up for its
  **full** telegraph. A hazard that cannot be dodged is the single worst thing
  this redesign could ship and it is invisible in a screenshot.
- **The player is never cornered** — asserted every frame of a driven run,
  computed in the test from the pads and hazards rather than asked of the game,
  so a bug in the game's own version of that question cannot hide behind it.
- **Jumping puts you over the hazard** — and standing puts it over you. The
  test resolves **effective** z by walking the parent chain, because that rule
  shipped inverted once while the constants it is built from were all correct:
  only the scene was wrong, and a constants check passes happily on the broken
  build. Verified by re-breaking it and watching this fail.
- **A hit knocks you into the water, and costs one life, not two.** Whether
  someone was thrown off a pad is a question about state over time, which a
  screenshot of one frame cannot answer — and the mercy window that stops the
  following splash charging again is easy to break and invisible until a
  player counts their hearts.

Plus the curve's shape, and the regressions this game has already had, because
a bug that got through once will get through again. Newer: the own-lane share
at both ends of the curve, and that every own-pad shake leaves a safe
neighbour **and** enough warning to reach it -- computed in the test from the
row, not by asking the game.

### What Acorn Storm's suite holds

`tests/acorn_test.gd`. Its first assertion is the one the file exists for:

- **Every sunfruit is reachable** — measured from where the player was standing
  when it spawned, at *walking* pace, minus a slow human's reaction time, and
  sampled across the whole curve because the reachable radius shrinks with the
  fall time and the failure would only appear late. The sprint is deliberately
  not in that calculation: a guarantee that depends on stamina the player may
  already have spent is not a guarantee.
- **The player is never cornered** — checked at the moment each acorn is
  thrown, over a hundred throws across five points on the curve, and
  **computed in the test** from the field rather than by calling the game's
  own `escape_exists()`. A test that asks the game whether the game is right
  cannot catch the game being wrong; Riverleap's suite records the same
  reasoning for the same check. It also counts how many placements the
  director *rejected*: a flood of them would mean the field is so crowded that
  the escape rule is throttling the game rather than protecting the player,
  which passes the cornering check while breaking the game.
- **Fruit can outpace the drain** — at four points on the curve, the fruit on
  offer must be worth more bar per second than the drain takes. Without this a
  run could end on arithmetic rather than on anything the player did, and no
  other check would notice.
- **The first sunfruit lands before the first acorn**, over repeated runs.
- **The mean trip grows across a run.** Measured per intensity band and pooled
  into halves, because a dozen fruit a band differ by several pixels on noise
  alone -- a strict band-over-band rule failed on a 4% wobble while the run as
  a whole was 23% up. This is the check that would have caught the shrinking
  bubble, and it did not exist because nothing was asking about size.
- **The two marks are rarely stacked** on the same patch of grass, since a
  ring over a disc is a square the player cannot read.
- **A motionless player gets hit.** Not asserted directly, but the idle run's
  reported hit count is what exposed an aim rule that could not touch somebody
  standing still.
- **Ignoring fruit is fatal** — a bot that dodges perfectly and never catches
  anything must die, and a bot that chases must last meaningfully longer. This
  is the assertion that the parked version of this game would have failed, and
  the whole reason the bar exists.
- **The drain is gentle and then it is not** — asserted as a shape across the
  curve, not as two numbers.
- The launch stays quiet, draw order resolves correctly up the parent chain, a
  run ends exactly once, and the card is skipped on a replay.

Both suites run bots at **133 / 216 / 300 ms of reaction lag**, because a bot
that reacts on the frame a thing spawns measures a game a machine plays rather
than the one a person does.

### What Hush Meadow's suite holds

`tests/hush_test.gd`. Its first assertion is the one the file exists for:

- **Reachable, surviving, unwatched cover always exists** — the scroller's
  version of "never cornered", and strictly harder than either other game's
  because cover **expires**. Computed in the test from the patches, the scroll
  rate and the cones: a walk to the patch, or a wait for one not yet on the
  field, whichever is longer. A
  momentary gap is allowed and a long one is not: the instant a patch crosses
  the bottom edge there can honestly be a beat with nothing usable, and
  asserting zero gaps would report dead ends on a game that has none. It also
  counts the director's **rescue** placements, because a flood of them means
  the meadow is too sparse to play and the floor is propping the game up
  rather than protecting the player.
- **Dew only shows in cover**, and only to somebody actually inside the patch
  holding it. This is the rule the whole game hangs off, and the check caught
  it failing wherever two patches overlapped.
- **The concealment rect is never smaller than what is drawn.** Written
  against the clump sprite's real size rather than against the constants, and
  it immediately caught grass drawn 32 px above centre inside a rect that hid
  26 — six pixels of what looked like cover that was decoration. Anywhere that
  looks like cover has to be cover; the other way round is a game that lies to
  the player at the only moment it matters.
- **Dew can outpace the nerve rise**, at four points on the curve, or a run
  ends on arithmetic rather than on anything the player did. It sat at 0.97×
  once.
- **Hiding is not a strategy** — measured on **dew per second**, not on how
  long runs lasted, and the reason why is its own lesson below.
- **A hovering bird's facing does not twitch**, which is a regression test for
  a bug the restored file already carried a fix for.
- **Cover gets further away across a run** — probed from fixed points, because
  the forage bot walks toward the nearest patch by definition and so cannot
  measure one.
- **She rides the meadow** — after a second, she has moved exactly as far as a
  patch has. The regression test for Neo's report, and the reason the suite's
  reach maths may treat her as only walking. Verified by deleting the line that
  carries her: it fails with the bug's own description.
- **The edge bites** — pinned at the bottom, nerve rises well above a bird's
  rate, the alarm is on, and a third of a second of pushing up frees her.
  Verified by setting the pinned rate to the seen rate.
- **The art is pixel art** — every large layer's mean run, measured on the
  imported texture. Acorn Storm's suite holds the same check for its two.
- Plus the curve, the two ground layers staying on different periods and
  rates, grass drawing over a concealed player, a cone being on her long
  enough to react to, the golden being catchable, and a run ending once.

The bots carry more judgement than they did, and each piece was added because a
traced death showed the bot doing something no person would: it re-decides
when pinned (after its reaction time, as a person notices the alarm), never
walks *down* to a patch that will carry it onto the edge, keeps a berth from
birds rather than only from where they are looking, and does not wait at the
top edge for grass that has not arrived. Without them the difficulty table
measured a bot sitting on the edge.

### And a third suite, for what sits between them

`tests/cabinet_test.gd` holds the properties that belong to no single game, so
neither game's suite can: every minigame folder yields exactly one reachable
game and nothing that is not a game is picked up; every game's root extends
`MiniGame`, reports a non-empty `id` that no other game shares, and declares a
positive `par_score`; and the boot scene in `project.godot` is one of them, so a
rename cannot quietly leave the project opening a blank window.

Eight notes that cost real time to learn:

- **A screenshot is not a substitute for an assertion, and vice versa.** This
  round needed both, in opposite directions. The inverted draw order was
  invisible to 65 passing checks and obvious in one capture; the knockback
  looked broken in six captures and was proved correct by one assertion. Use
  the picture for *what it looks like* and the test for *what happened*.
- **GDScript lambdas capture local variables by VALUE.** A counter
  incremented inside a `signal.connect(func(): n += 1)` callback stays zero
  outside it, which is indistinguishable from a signal that never fired. The
  suites count into an Array, whose reference is captured. This has now been
  walked into twice: the second time it was a `var ended := false` set by a
  `finished` handler, which did not fail anything — it just ran every bot for
  its full time limit and turned a ninety-second suite into a ten-minute one.
- **A headless Godot whose main scene fails to parse does not exit — it
  spins.** Two "runs" of the new suite burned fifteen minutes each at 99% CPU
  and produced an empty log, which looks exactly like a slow machine or a hung
  test, and sent two rounds of fixes at problems that were not there. The
  script had never run at all. Two habits come out of it: pipe the engine's
  output to a file **unfiltered** (a `grep` in the pipeline buffers everything
  until the process ends, and it never ends), and syntax-check a new script
  with `--check-only --script` before running it, ignoring the autoload
  identifiers that check cannot see. The suite itself now prints each step as
  it starts, so a hang names itself.
- **GDScript type inference is a parse error, not a warning.** `for ring in
  [1.0, 0.72, 0.42]` makes `ring` a Variant, every expression built from it
  untyped, and the whole script fails to load — taking the scene's script with
  it. That was the actual cause of the spin above.
- **Passing checks do not mean the thing is any good.** Acorn Storm shipped
  with every assertion green and was no fun, because the suite proved fruit
  was always *reachable* and nothing asked whether the player ever had to
  *move*. The game halved the ground it used over a run and no test noticed,
  because no test was about size. Assertions cover the properties somebody
  thought to name -- when something feels wrong and everything passes, the
  missing check is usually the whole answer.
- **A measurement needs enough of the thing to measure.** Own-pad shakes are
  rate-limited by the game itself: once your pad goes you are in the water and
  that lane cannot be picked again for a couple of seconds. Three short
  windows yielded eight samples, and the first instinct -- top the player's
  lives up so they survive -- changed nothing, because lives were never the
  limit. Find the real limit before working around the wrong one.
- **Lag models reacting, not tracking -- and a lagged bot cannot stand
  still.** Four rounds went into a flaky "can a prize be caught" check that
  came out 1/4, 2/4, 4/4 at random. The prize was fine. A bot with 216 ms of
  lag gets its "stop" command 23 px after it should have stopped, and its
  correction equally late, so it orbits a 24 px catch radius and collection --
  which is tested on the landing frame alone -- becomes a coin flip. It was
  measured within **2.1 px** of a prize collecting nothing. A person tracks a
  falling object and waits under it. Lag belongs on reactions to new
  information; whether a slow player can get there in time is a separate
  question that `reach()` already answers.
- **Do not route a test through a heuristic it is not testing.** The same
  check also failed because the chase bot *abandoned* the prize in its last
  half second: margin shrinks as a target nears the ground, so an ordinary
  sunfruit out-ranked it at the worst moment. Three attempts went into fixing
  the bot before the obvious point landed -- the bot was never the thing under
  test, and the check now walks straight at the prize.
- **A game with no difficulty measurement cannot be tuned, only guessed at.**
  Riverleap went four rounds without one: its bot reacted instantly, so "too
  steep" could not be turned into a number. The first real measurement showed
  it was never especially lethal -- a 216 ms bot survived the whole cap, and a
  300 ms stranger lasted more than twice as long as in Acorn Storm. The
  complaint was about the *ramp*, not the ceiling, and without the numbers the
  obvious fix would have been to lower a ceiling that was not the problem.
  **"Too hard" and "ramps too fast" are different complaints.**
- **Syntax-check a new test before running it, every time.** This document
  already says a headless Godot whose main scene fails to parse spins forever
  instead of exiting. It happened again anyway -- five minutes of a pegged CPU
  and an empty log -- because a new constant collided with one already in the
  file. The lesson was written down and still not applied; `--check-only
  --script` costs a second.
- **A suite that prints an engine error and passes is lying to you.** The
  results card dereferenced a null viewport on *every* replay press, in both
  4.6 and 4.7, for several rounds. Nothing failed, for two compounding
  reasons: no test drove the end-of-run path at all -- every suite instances
  its game as a CHILD, and the card only appears when the game is the running
  scene -- and even when an error is printed, the exit code only reflects the
  check tally. `tools/run_tests.sh` now fails the run on any engine error,
  and `tests/cabinet_test.gd` drives the card for every game.
- **A test of a teardown has to tear something down.** The first version of
  that card test pressed the button and passed with the bug deliberately
  restored, because the card stayed parented to the test node: nothing was
  destroyed, so `get_viewport()` was fine. The handler now removes the card
  from the tree, as a scene reload does, and re-breaking the fix fails the
  run. **Verify a regression test by re-breaking the thing it is for** --
  otherwise it is a test of the happy path wearing a bug report's name.
- **Ask a guarantee at the moment it is made.** The cornering check started
  out sampling every frame and reported dead ends on a game that had none: an
  acorn a fifth of a second from landing leaves nobody anywhere to go, by
  arithmetic. Two rounds went into "fixing" that before the question turned
  out to be the wrong one. A guarantee is about a decision, so test it where
  the decision is taken.
- **A harness that stands an object up alone can hide what it does in place.**
  Acorn Storm's intro slides were checked by building the card on its own and
  screenshotting it, which looked right. Over the actual game the player
  character stands at the centre of the clearing — directly under the card's
  text, making a third figure on a slide whose whole point is two. Nothing saw
  it until there was a key that switched games and the card came up over a
  running scene.
- **A measurement of the director must not be cut short by the game.** Three
  of Acorn Storm's checks jump the clock to the end of the curve and then
  count what spawns; left alone, the bar empties partway through and the game
  stops spawning, so the sample is diluted by seconds of nothing. They pin the
  bar open while they measure. A sample that quietly stops being a sample is
  the same class of bug as a test that passes for the wrong reason.
- **The bot has to hold the stick a frame before it presses the button.**
  `_unhandled_input` reads the direction with `Input.is_action_pressed` at the
  instant the `act` event arrives, so a hold and a press on the same frame comes
  out as a jump in place and the bot never leaves its lane — a suite that passes
  while testing nothing.

- **Synthetic input must be a parsed `InputEventAction`.** `Input.action_press()`
  only sets the polled state and never reaches `_unhandled_input`, so the hop —
  which is read by event — would go silently untested.
- **A visual pass is not optional.** Render it under `xvfb-run` and look at it.
  Assertions caught none of: the invisible target ring, grey fireflies, a
  heading printed over a card, a missing stamina bar, vignette banding, or the
  jump pose being too small to see. Under `xvfb-run` the frame rate is not
  pinned, so target a moment by polling for state, not by counting frames, and
  the process may not exit cleanly after `get_tree().quit()` — the screenshots
  are still written, so capture in the background and reap it.

- **Put the lag on the decision, not on the steering.** A bot whose whole
  steering vector is delayed is not a slow player, it is a bad walker, and it
  produced a difficulty table reading 47 s / 59 s / 35 s across *rising*
  reaction times — pure noise. A person tracks what they chose continuously;
  the delay is in noticing there is something new to choose. Worse, a bot that
  re-decides every frame turns lag into **commitment**: the laggier bot stuck
  with one target longer and so played *better*. It re-decides only when its
  target is gone, it has arrived, or something is looking at it.
- **A delayed decision can name something that is already gone.** The lag
  queue holds node references, and a reaction time is easily long enough for
  the dew it named to be collected. Assigning a freed instance into a typed
  `Node2D` throws at the assignment, and passing one to a typed *parameter*
  throws at the call — so `is_instance_valid()` inside the callee is too late.
  Both read as every bot "surviving" 0.0 seconds.
- **Pick the quantity that is stable, not the one that sounds like the
  claim.** "Hiding is not a strategy" is naturally a statement about how long
  runs last — and six pairs of whole runs on one unchanged build gave hiding
  61 s / 87 s / 96 s against foraging 137 s / 102 s / 88 s. The claim came out
  true, false and true on the same code, and two rounds of tuning went into
  chasing that variance. Dew per second is stable, and since dew is the only
  thing that lowers the meter it is the same claim. **If a measurement swings
  more than the effect you are tuning, stop tuning and change the
  measurement.**
- **A sample that is skipped is a sample that is biased.** The "cover gets
  further away" probe returned infinity when nothing was in range and the
  caller skipped it — which threw away exactly the frames the late meadow is
  made of, so the measurement only ever saw the moments cover happened to be
  near. A meadow that doubles its distance to cover measured flat at 93 px
  against 90 px. The worst case has to be *recorded* as a number, not dropped.
- **Check the syntax, then run only if it passed.** This document already says
  twice that a headless Godot whose main scene fails to parse spins at 99 %
  CPU on an empty log. It happened a third time, in the same session that
  wrote the second warning down — because the check and the run went into one
  shell line, the check printed its failure, and the run started anyway. A
  safeguard that does not gate anything is not a safeguard. `tools/` now has
  the two in the right order.
- **Verify an anchor before you edit on it.** Three scripted edits in a row
  aborted on a string that did not match, each one costing a full suite run to
  notice. Read the file, then edit.

- **Compare against a baseline measured the same way.** "Runs got 30 %
  shorter" meant nothing until the unchanged build was checked out into a
  worktree and run through the identical instrumentation. That comparison
  overturned the first explanation (the bots had lived in the upper half of the
  field all along) and pointed at the real one.
- **Rates per unit time are stable where run lengths are not.** Ten runs per
  reaction time swung ±25 s, enough that a strictly faster walk measured
  *worse*. Watched-seconds, spottings, dew and edge-time per 100 s of survival
  were steady across every sample and said the riding meadow was nearly the
  same game as before -- and the one rate that had moved, dew, named the cause:
  arrivals had fallen with the scroll.
- **Trace the deaths before tuning the numbers.** Every early death was printed
  frame by frame, and none was what it looked like from the summary. One was
  the bot oscillating on the edge, one was a missing term in the game's own
  reach maths (a patch above the field is a wait, not a walk), and one was a
  mercy window that a change of reference frame had quietly shortened.
- **A change of reference frame moves things far from where you changed it.**
  Carrying the player was one line. It also removed a free lift toward new
  cover, starved the meadow of arrivals once the scroll slowed, made a
  distance-only reach wrong at the top edge, and took away the drift that used
  to separate a swooping bird from her during mercy. Each surfaced as a
  measurement or a trace, never as a failing check.
- **The spin happened a fourth time.** A scratch scene copied into a baseline
  worktree called a function the old code did not have, and a headless Godot
  sat at 99 % CPU for the full ten-minute timeout. `run_tests.sh` gates its own
  suites; anything run by hand needs the same `--check-only` first.
- **A cold import cache is not a failure.** On a fresh clone the first import
  errors because the theme loads before its fonts exist, so every suite passed
  and the run said FAILED. `run_tests.sh` now warms a cold cache with one
  unjudged import; the judged one still reports anything that stays broken.

---

## 10. Parked, not cancelled

All present in `main` at `876d449` and restorable with
`git checkout 876d449 -- <path>`:

- **Five minigames.** Echo Hollow (walk a remembered pattern), Riverstrike
  (lead a moving fish, bottles block the bolt), Firefly Lantern (your
  multiplier is how little light you have left), Temple Bell (rhythm, then
  rhythm while running errands), Crow Watch (defend a field whose tally only
  goes down). Riverleap, Acorn Storm and Hush Meadow have come back.
- **The shell**: slot-machine card draw, attract screen with idle states,
  results screen with a rank stamp.
- **The lore**: eight gifts, seventeen cutscenes as data (`src/data/lore.gd`),
  and a finale with three endings chosen by score.
- **Scoring across games**: all eight were tuned into one 2,500–4,500 band so a
  shared high-score table records skill rather than which cards you were dealt.
  This matters again the moment a second game returns.
- QRIS payment seam, session logging, backend leaderboard, cabinet hardware.
