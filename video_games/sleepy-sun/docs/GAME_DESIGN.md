# Sleepy Sun — Design & Planning Document

**Status: stripped to one game.** Four earlier rounds built eight minigames, a
card draw, an attract screen, a results screen and seventeen cutscenes. All of
it works and all of it is in `main`'s history — but none of it was *finished*,
because the budget was always split eight ways.

So the project is now one game at a time: **Riverleap**, polished until it is
genuinely good, then the next one, and only then the shell that holds them.
Everything parked is listed in §7, with the commit it lives in.

---

## 1. What this is

**Play It Forward** is a charity arcade cabinet. One cabinet hosts one
*adventure* made of minigames; Sleepy Sun is the first adventure.

The constraints that shape every decision:

| Constraint | Consequence |
|---|---|
| It sits unattended in a public space | Playable by someone who has never seen it, with no instructions |
| The player has already paid | **No fail state** — *amended for Riverleap, see §5.* A game over thirty seconds in is a machine that took money and gave nothing. Riverleap now has five lives, chosen deliberately, with a gentle first minute as the compromise |
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

The lore is written and parked (§7). It belongs with the shell, because a
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
- **F3** toggles slow motion (0.35×), for looking at a frame of animation.

That is the whole debug surface, and it replaces a menu that was mostly about
choosing between games. Both keys are inert outside a debug build.

### Score feedback

- **Gains pop at the object** — the chime that scored, not a corner of the HUD.
- **Losses pop on the player**, and they *shake* instead of drifting, so a loss
  cannot be mistaken for a win at a glance.
- **Nothing permanent on screen is a sentence.** Score, a meter bar with an
  icon, and a multiplier badge that only appears above ×1.

---

## 5. Riverleap (`wind_leaf`) — *hop*

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

≈0.15 at 30 s, 0.30 at 60 s, 0.64 at 120 s, 0.82 at 180 s. Everything speed- or
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
run against a copy of itself slowed to human reaction lag. Every trial, at
every lag, recorded **zero** frames where the player had no reachable lane to
stand on — the never-corner guarantee holds over ~20 minutes of play.

Re-measured after the launch ramp and the hazard debut ramps. **Two trials per
lag**, so read these as a band rather than a figure — the spread within one lag
is wider than the gap between some of them, and the single passive run is one
sample and nothing more.

| Bot reaction lag | Survives | Score |
|---|---|---|
| 50 ms (frame-perfect) | **never dies** (capped at 7 min) | — |
| 133 ms (expert, anticipating) | 212–238 s | 18k–20k |
| 216 ms (average human) | 145–168 s | 9k–10k |
| 300 ms (slow) | 92–95 s | 4k–5k |
| no input at all | ~61 s | ~2.9k |

The gentler opening lifted the **expert** band most (140–216 s → 212–238 s),
which makes sense: a player who reads hazards well gains most from meeting them
one at a time and loses least to a slow start. The middle and slow bands moved
within their own noise.

Every trial at every lag, across three rounds of tuning, has recorded **zero
cornered frames**.

Two things worth reading off that table. **A perfect reactor never dying is not
a bug** — it is exactly what a strict never-corner guarantee promises, and it
means the skill ceiling is set by human reaction rather than by a wall. And
**every trial at every lag has recorded zero cornered frames**, through every
round of tuning, which is the number that actually matters: the game got much
faster without ever becoming unfair.

---

## 6. Testing

```
tools/run_tests.sh          # or GODOT=/path/to/godot tools/run_tests.sh
```

One suite now, `tests/soak_test.gd`. It used to prove that the game could be
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
a bug that got through once will get through again.

Three notes that cost real time to learn:

- **A screenshot is not a substitute for an assertion, and vice versa.** This
  round needed both, in opposite directions. The inverted draw order was
  invisible to 65 passing checks and obvious in one capture; the knockback
  looked broken in six captures and was proved correct by one assertion. Use
  the picture for *what it looks like* and the test for *what happened*.
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

---

## 7. Parked, not cancelled

All present in `main` at `876d449` and restorable with
`git checkout 876d449 -- <path>`:

- **Seven minigames.** Hush Meadow (stealth forage), Echo Hollow (walk a
  remembered pattern), Riverstrike (lead a moving fish, bottles block the bolt),
  Acorn Storm (dodge, catch), Firefly Lantern (your multiplier is how little
  light you have left), Temple Bell (rhythm, then rhythm while running errands),
  Crow Watch (defend a field whose tally only goes down).
- **The shell**: slot-machine card draw, attract screen with idle states,
  results screen with a rank stamp.
- **The lore**: eight gifts, seventeen cutscenes as data (`src/data/lore.gd`),
  and a finale with three endings chosen by score.
- **Scoring across games**: all eight were tuned into one 2,500–4,500 band so a
  shared high-score table records skill rather than which cards you were dealt.
  This matters again the moment a second game returns.
- QRIS payment seam, session logging, backend leaderboard, cabinet hardware.
