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
| The player has already paid | **No fail state.** A game over thirty seconds in is a machine that took money and gave nothing |
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
crossed by drumming the stick, small enough not to feel sticky. A 0.16 s input
buffer means a press during a hop is honoured on landing.

**Chimes chain.** Each is +80 × a multiplier that steps up every two chimes to
×5. Splashing costs 150 points **and** the chain, so going in the water hurts
twice.

### The river

The player floats **with** the current, so in camera terms the water surface
does not translate at all and the banks are what fly past. All the speed lives
in one value — `CURRENT_START`/`CURRENT_END` in `wind_leaf.gd`, applied every
frame to the ground, the waterline strip and the bank props together. When it
was not one value, the water crawled at 14 px/s while the banks ran at 39–59
and the mismatch was the first thing a player noticed.

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
hand-placed children and wraps them, and the river litter uses the same node
with a bob and a slow turn.

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

### Known weakness, to be answered by playing

Stripped of decoration this is **one binary choice — left or right — repeated
for a full minute**. The telegraph work is good and the director is fair; none
of that changes the fact that the player makes roughly the same decision forty
times. Candidates, in rough order of cost:

1. **Shorten and intensify** — 62 s → ~35 s, with late-game pressure arriving
   much earlier. Removes the thin seconds rather than trying to fill them.
2. **Make chimes the game, not the sprinkles.** If they spawned in chosen lanes
   and the chain required consecutive pickups, every hop becomes *routing* —
   which lane do I want to be in three seconds from now — instead of "is this
   one red yet".
3. **A second axis**: leaves ahead as well as beside.
4. **A charged hop**: hold for a two-lane leap with a commitment beat.
5. **Leaf variety**: one that sinks on landing, one that springs you two lanes.

Nothing here is committed. The order of work is: play it, then decide.

---

## 6. Testing

```
tools/run_tests.sh          # or GODOT=/path/to/godot tools/run_tests.sh
```

One suite now, `tests/soak_test.gd`, and it proves the property most worth
protecting: **the game can actually be finished.** It drives Riverleap with
scripted input until the crossing ends on its own rather than forcing
`finish()`. A minigame that cannot be completed still looks fine in the editor
and still survives a short run. It also carries the regressions this game has
already had, because a bug that got through once will get through again.

Two notes that cost real time to learn:

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
