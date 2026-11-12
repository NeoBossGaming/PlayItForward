extends MiniGame
## Acorn Storm -- stand under an oak in a gale for as long as you can.
##
## Things fall out of the canopy. Acorns hurt. Sunfruit is the only thing
## keeping you alive, because **the bar is always going down**. It drains
## slowly at first and faster the longer you last, so a run ends not when a
## clock runs out but when you can no longer feed it.
##
## That drain is the whole design, and it exists to fix the thing the fixed
## round got wrong: with a timer and a score, fruit was optional. Dodging
## alone was a perfectly good strategy and the "catch" half of a dodge-and-
## catch game never mattered. Now an unreachable fruit costs a life rather
## than some points, which is why the reaction floor in tests/acorn_test.gd is
## the single most important assertion in this file.
##
## **This is the second game to break the cabinet's no-fail-state rule**, for
## the same reason Riverleap did: without a way to lose there is nothing for a
## good player to chase. The compromise is the same too -- the opening minute
## is gentle enough that a stranger gets a real go for their credit.
##
## Two things to read, and they want opposite reactions:
##   * a hot ticked RING  -- an acorn. be somewhere else.
##   * a filled gold DISC -- sunfruit. be exactly there.
##
## See docs/GAME_DESIGN.md.

const FALLER := preload("res://src/minigames/acorn_storm/faller.tscn")

## The clearing, in feet-position terms: where the player may stand and where
## anything may land. Deliberately clear of the canopy band at the top, so a
## mark is never half-hidden under leaves.
const FIELD := Rect2(46, 106, 388, 132)

## --- the difficulty curve ----------------------------------------------------
##
## One number, `_intensity`, drives the drain, the spawn rates, the fall time
## and how many acorns may be in the air. The shape is MiniGame.curve(): a
## gentle linear opening to a ceiling, then exponential toward 1 without ever
## arriving. Riverleap arrived at it over two rounds of tuning; only the three
## numbers below are this game's.
##
##   t=30s -> 0.10   t=60s -> 0.21   t=120s -> 0.52   t=180s -> 0.70
const GENTLE_SECONDS := 75.0
const GENTLE_CEILING := 0.26
const STEEP_TAU := 135.0

## Nothing falls while the wind is still getting up. Shorter than Riverleap's
## three seconds because there is no scrolling world to accelerate -- what
## ramps here is the gale, and two seconds of the canopy starting to thrash is
## enough to say "look up" before the first thing does.
const LAUNCH_SECONDS := 2.0

## --- the vitality bar --------------------------------------------------------
##
## Starts short of full on purpose. A bar that opens at 100% gives the first
## fruit nothing to do, and the player learns what fruit is FOR by watching it
## move.
const VITALITY_START := 0.68
## Per second, at intensity 0 and 1. The opening is nearly free -- about a
## hundred seconds to empty if you never catch anything -- and the late game
## empties a full bar in roughly twelve.
const DRAIN := Vector2(0.0085, 0.082)
## What one sunfruit puts back, before the combo bonus. Two fruit a second is
## a lot to ask at the end; one is not quite enough.
const FRUIT_GAIN := 0.102
## What an acorn takes, on top of the stun -- which is the worse half, because
## you cannot catch while you are seeing stars.
const HIT_BITE := 0.14
const STUN_SECONDS := 0.55
## Below this the screen starts shouting.
const ALARM_BELOW := 0.26

## --- falling -----------------------------------------------------------------
##
## Fall time is the number everything else hangs off: shorten it and the
## reachable area around the player shrinks as the square of nothing in
## particular -- linearly, but the field does not, so the fraction of the
## clearing you can get to collapses. It is why the late game is hard and why
## it is not simply "more acorns".
const FALL_SECONDS := Vector2(1.60, 0.95)
## Before a player has reacted they have not moved, so the reach that matters
## is the fall time MINUS a reaction. 0.30s is a slow human; measuring against
## a fast one would be designing the game for me rather than for a stranger.
const REACTION_FLOOR := 0.30
## How much of the theoretically reachable radius fruit may actually use.
## The remainder pays for the diagonal, for the field clamp, and for the fact
## that nobody runs in a perfectly straight line.
const REACH_MARGIN := 0.82
## Fruit never lands in your lap -- it has to be worth a trip, or the catching
## half of the game is just standing still.
const FRUIT_MIN_TRIP := 26.0

const ACORN_INTERVAL := Vector2(1.25, 0.36)
const FRUIT_INTERVAL := Vector2(2.10, 0.92)
const ACORN_AT_ONCE := Vector2(1.0, 4.0)

## The first acorns come singly, slowly, and from further off. Learning that
## gold is good should not cost a life, so for the first stretch the bad half
## of the game is deliberately easy to dodge.
const DEBUT_SECONDS := 14.0
const DEBUT_FALL_BONUS := 1.38
## Acorns are thrown at where the player will BE -- their position carried
## forward by this much of their own travel -- and then scattered by a random
## offset within AIM_JITTER. Both numbers run from intensity 0 to 1.
##
## The jitter is what makes standing still survivable at the start and fatal
## at the end: a stationary player is hit whenever the roll lands inside the
## acorn's 14 px, which is about 4% of throws at 74 px of scatter and about
## 60% at 18 px. The first version threw into a RING around the player whose
## inner radius never went below the hit radius, which meant a player who
## never moved could not be hit at all -- the soak suite caught it by running
## a motionless bot for 45 seconds and reporting zero hits.
const AIM_JITTER := Vector2(74.0, 18.0)
## And the lead is what stops running in a straight line from working: late on,
## most of where you are going is where the acorn is already aimed.
const AIM_LEAD := Vector2(0.25, 0.85)
## Room an escape has to have around it before it counts as an escape.
const ESCAPE_MARGIN := 7.0
## How far apart two marks of DIFFERENT kinds have to be to be read as two
## marks. Roughly the width of one, since they are drawn up to 1.55x.
const MARK_SEPARATION := 30.0
## Placements tried before an acorn is thrown anyway, or skipped.
const AIM_ATTEMPTS := 12
## Only acorns arriving within this long count against an escape route. One
## landing two seconds from now is not blocking anything.
const ESCAPE_WINDOW := 0.9

## --- scoring -----------------------------------------------------------------
const SCORE_FRUIT := 70
const SCORE_HIT := -60
const COMBO_PER_LEVEL := 3
const COMBO_MAX := 4
## Per second, by intensity -- so the last half-minute of a long run is worth
## more than its first two.
const SCORE_PER_SECOND := Vector2(6.0, 26.0)
## A good run. Endless, so this is a DURATION; see normalised_score().
const PAR_SECONDS := 120.0

const Z_PLAYER := 20

@onready var _player: TopDownPlayer = $Player
@onready var _hud: HUD = $HUD
@onready var _fallers: Node2D = $Fallers
@onready var _camera: GameCamera = $Camera
@onready var _canopy: Sprite2D = $World/Canopy
@onready var _shade: ScrollingTexture = $World/Shade
@onready var _leaves: Decor = $World/Leaves
@onready var _squirrels: Node2D = $World/Squirrels

var _intensity: float = 0.0
var _vitality: float = VITALITY_START
var _survived: float = 0.0
var _survival_score: float = 0.0
var _stun: float = 0.0
var _gust_timer: float = 1.4
var _acorn_timer: float = 0.0
var _fruit_timer: float = 0.0
var _canopy_home: float = 0.0
var _ending: bool = false

var _score: int = 0
var _fruit: int = 0
var _hits: int = 0
var _missed: int = 0
var _combo: int = 0
var _best_combo: int = 0
## Counted rather than asserted away: if the director ever cannot find an
## acorn placement that leaves an escape, the test wants to know how often.
var _skipped_acorns: int = 0
var _first_fruit_at: float = -1.0
var _first_acorn_at: float = -1.0


func _ready() -> void:
	_player.position = Vector2(FIELD.get_center().x, FIELD.get_center().y)
	_player.speed = 92.0
	_player.can_sprint = true
	_player.z_index = Z_PLAYER
	_player.stamina_changed.connect(_hud.set_stamina)
	# stamina_changed only fires when the meter moves, so the bar would be
	# invisible until the first sprint without this.
	_hud.set_stamina(1.0, false)
	_player.freeze()

	_canopy_home = _canopy.position.x
	_hud.reset_score(0)
	_hud.hide_lives()
	_refresh_bar()

	# No shell in front of it for now, so the game starts itself -- but only
	# when it really is the scene being played. The soak suite instances it as
	# a child and drives begin() itself, and must not get a card or a scene
	# reload out of the bargain.
	if get_tree().current_scene == self:
		finished.connect(_on_run_finished)
		await get_tree().process_frame
		var card := AcornCard.new()
		add_child(card)
		await card.play()
		begin()


func control_hint() -> String:
	return "STICK  move      BUTTON  sprint"


func begin() -> void:
	super.begin()
	_player.unfreeze()
	_hud.toast("LOOK UP", Color(1, 0.86, 0.55), 1.2)
	# The first sunfruit lands before the first acorn, so "gold is good" is
	# learned before "red hurts". These two numbers are the whole of that
	# guarantee and acorn_test.gd checks the order it produces, not them.
	_fruit_timer = 0.35
	_acorn_timer = 0.35 + FALL_SECONDS.x * DEBUT_FALL_BONUS + 0.45


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_advance(delta)
	_tick_stun(delta)
	_player.position = _player.position.clamp(FIELD.position, FIELD.end)
	if _ending:
		return
	_tick_vitality(delta)
	_tick_spawns(delta)


## --- the world ---------------------------------------------------------------

func _advance(delta: float) -> void:
	_intensity = intensity_at(play_time())
	var gale := _intensity * launch_factor()

	_camera.set_intensity(gale)
	# The canopy thrashes, and it is the only thing on screen that can show
	# the wind -- the ground does not move in a game played standing still.
	_canopy.position.x = _canopy_home + sin(elapsed * lerpf(1.1, 3.4, gale)) \
			* lerpf(1.0, 6.0, gale)
	# The shade cast through the leaves travels with the wind. It is also the
	# anti-tiling layer: 224px against the clearing's 160, on a period that
	# never lines up, which is what actually killed the river's grid.
	_shade.scroll = Vector2(lerpf(-5.0, -26.0, gale), lerpf(2.0, 9.0, gale))
	_leaves.drift = Vector2(lerpf(-18.0, -96.0, gale), lerpf(22.0, 86.0, gale))

	if not sequence_started():
		return
	_gust_timer -= delta
	if _gust_timer <= 0.0:
		_gust_timer = lerpf(4.4, 1.3, _intensity) * randf_range(0.8, 1.25)
		_gust()


## A gust shoves the CAMERA'S ZOOM rather than its position: what it has to
## read as is wind, and a camera that shook would read as an impact.
func _gust() -> void:
	_camera.gust(lerpf(0.45, 1.0, _intensity))
	Audio.sfx(&"shake", randf_range(0.55, 0.8))
	for mote: Sprite2D in _leaves.get_children():
		mote.position.x += randf_range(-14.0, -4.0)


func _tick_stun(delta: float) -> void:
	if _stun <= 0.0:
		return
	_stun -= delta
	if _stun <= 0.0:
		_player.unfreeze()
		_player.anim.modulate = Color.WHITE
	else:
		_player.anim.modulate = Color(1, 0.6, 0.6, 0.6 + 0.4 * sin(_stun * 40.0))


## --- the bar -----------------------------------------------------------------

func _tick_vitality(delta: float) -> void:
	_survived += delta
	_survival_score += lerpf(SCORE_PER_SECOND.x, SCORE_PER_SECOND.y, _intensity) * delta
	_refresh_score()
	_hud.set_timer(_survived)

	_vitality = maxf(_vitality - drain_rate() * delta, 0.0)
	_refresh_bar()
	if _vitality <= 0.0:
		_collapse()


func drain_rate() -> float:
	return lerpf(DRAIN.x, DRAIN.y, _intensity)


## Green while there is room, amber as it goes, red when it is nearly out. The
## colour is doing work the length cannot: a bar you glance at twice a minute
## has to say "nearly gone" in the glance, not in the comparison.
const BAR_FULL := Color(0.56, 0.86, 0.46)
const BAR_LOW := Color(1.0, 0.45, 0.38)


func _refresh_bar() -> void:
	_hud.set_meter(_vitality, &"vitality",
			BAR_LOW.lerp(BAR_FULL, clampf(_vitality / 0.55, 0.0, 1.0)))
	_hud.set_alarm(1.0 if _vitality < ALARM_BELOW else 0.0)


func _refresh_score() -> void:
	_hud.set_score(maxi(_score + int(_survival_score), 0))


func _feed(amount: float) -> void:
	_vitality = clampf(_vitality + amount, 0.0, 1.0)
	_refresh_bar()


## --- the director ------------------------------------------------------------

func _tick_spawns(delta: float) -> void:
	if not sequence_started():
		return

	_fruit_timer -= delta
	if _fruit_timer <= 0.0:
		_fruit_timer = lerpf(FRUIT_INTERVAL.x, FRUIT_INTERVAL.y, _intensity) \
				* randf_range(0.85, 1.15)
		_spawn_fruit()

	_acorn_timer -= delta
	if _acorn_timer <= 0.0:
		_acorn_timer = lerpf(ACORN_INTERVAL.x, ACORN_INTERVAL.y, _intensity) \
				* randf_range(0.8, 1.2)
		if _acorns_falling() < int(round(lerpf(ACORN_AT_ONCE.x, ACORN_AT_ONCE.y,
				_intensity))):
			_spawn_acorn()


func fall_time(is_acorn: bool) -> float:
	var base := lerpf(FALL_SECONDS.x, FALL_SECONDS.y, _intensity)
	if is_acorn and debut() < 1.0:
		base *= lerpf(DEBUT_FALL_BONUS, 1.0, debut())
	return base


## 0 while acorns are still being introduced, 1 once they are not.
func debut() -> float:
	return clampf(play_time() / DEBUT_SECONDS, 0.0, 1.0)


## How far the player can actually get in `seconds`, at WALKING pace. The
## sprint is not in here on purpose: a guarantee that depends on stamina the
## player may have already spent is not a guarantee.
func reach(seconds: float) -> float:
	return _player.speed * maxf(seconds - REACTION_FLOOR, 0.0)


## Fruit lands WITHIN REACH, every time. This is the line that makes the
## catching half of the game real: out in the open field it would land wherever
## it liked, the player would watch most of it fall, and the bar would empty
## through no decision of theirs.
func _spawn_fruit() -> void:
	var seconds := fall_time(false)
	var limit := maxf(reach(seconds) * REACH_MARGIN, FRUIT_MIN_TRIP + 6.0)
	var best := Vector2.ZERO
	var best_clearance := -1.0
	for attempt in 8:
		var angle := randf() * TAU
		var distance := randf_range(FRUIT_MIN_TRIP, limit)
		var spot := (_player.position + Vector2.RIGHT.rotated(angle) * distance) \
				.clamp(FIELD.position, FIELD.end)
		# The clamp can drag a spot back toward the player, or onto a wall; if
		# it moved far, this candidate is not the one that was asked for.
		if _player.position.distance_to(spot) < FRUIT_MIN_TRIP:
			continue
		var clearance := _clearance(spot, seconds)
		if clearance > best_clearance:
			best_clearance = clearance
			best = spot
		# Far enough from anything dangerous that it is a real offer.
		if clearance > 28.0:
			break
	if best_clearance < 0.0:
		best = _player.position.clamp(FIELD.position, FIELD.end)
	_drop(Faller.Kind.SUNFRUIT, best, seconds)


## Acorns aim at where the player IS, loosely, and tighter as the run goes on.
## Standing still therefore stops working, which is the rule the game is
## actually built on -- but a placement that leaves no escape is rejected
## rather than thrown, because "you had nowhere to go" is not difficulty.
func _spawn_acorn() -> void:
	var seconds := fall_time(true)
	var jitter := lerpf(AIM_JITTER.x, AIM_JITTER.y, _intensity)
	var lead := lerpf(AIM_LEAD.x, AIM_LEAD.y, _intensity)
	var predicted := _player.position + _player.velocity * seconds * lead
	var fallback := Vector2.INF
	for attempt in AIM_ATTEMPTS:
		# sqrt() so the offset is spread evenly over the disc rather than
		# bunched at the middle, which would make every throw a near miss.
		#
		# Later attempts reach a little further out. With six throws all
		# drawn from the same tight disc, a crowded patch simply had no clear
		# spot in it and the stacking rule gave up about as often as it
		# worked; widening the search is what makes it a rule rather than a
		# coin flip, and it costs the aim almost nothing because the early
		# attempts -- the tight ones -- still win whenever they can.
		var spread := jitter * (1.0 + 0.09 * float(attempt))
		var offset := Vector2.RIGHT.rotated(randf() * TAU) * spread * sqrt(randf())
		var spot := (predicted + offset).clamp(FIELD.position, FIELD.end)
		if not escape_exists(seconds, spot):
			continue
		# A ring drawn on top of a disc says "danger" and "take it" about the
		# same square of grass. The player cannot act on that, so a placement
		# that stacks the two marks is passed over when there is any other --
		# but not refused outright, because acorns aim at the player and a
		# player standing on a fruit has to be a target like anywhere else.
		if _fruit_clear(spot, seconds):
			_drop(Faller.Kind.ACORN, spot, seconds)
			return
		if not fallback.is_finite():
			fallback = spot
	if fallback.is_finite():
		_drop(Faller.Kind.ACORN, fallback, seconds)
		return
	_skipped_acorns += 1


## Is this spot free of a sunfruit mark arriving at about the same moment?
func _fruit_clear(spot: Vector2, seconds: float) -> bool:
	for child in _fallers.get_children():
		var faller := child as Faller
		if faller == null or faller.resolved or faller.kind != Faller.Kind.SUNFRUIT:
			continue
		if absf(faller.seconds_left() - seconds) > 0.55:
			continue
		if spot.distance_to(faller.position) < MARK_SEPARATION:
			return false
	return true


func _drop(kind: Faller.Kind, at: Vector2, seconds: float) -> void:
	var faller: Faller = FALLER.instantiate()
	_fallers.add_child(faller)
	faller.setup(kind, at, seconds)
	faller.landed.connect(_on_landed)
	if kind == Faller.Kind.ACORN:
		_squirrel_above(at.x)


## A squirrel pops out of the canopy over the spot an acorn is coming from.
## The ground mark says where it will land; this says where it came from, and
## between them the player's eye has somewhere to go before the thing arrives.
func _squirrel_above(x: float) -> void:
	var squirrel := Sprite2D.new()
	squirrel.texture = preload("res://assets/game/acorn_storm/squirrel.png")
	squirrel.position = Vector2(clampf(x, 20.0, 460.0), 52.0)
	squirrel.flip_h = randf() < 0.5
	_squirrels.add_child(squirrel)
	var tween := create_tween()
	tween.tween_property(squirrel, "position:y", 62.0, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.25)
	tween.set_parallel(true)
	tween.tween_property(squirrel, "position:y", 44.0, 0.2)
	tween.tween_property(squirrel, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(squirrel.queue_free)


func _acorns_falling() -> int:
	var count := 0
	for child in _fallers.get_children():
		var faller := child as Faller
		if faller != null and not faller.resolved and faller.kind == Faller.Kind.ACORN:
			count += 1
	return count


## How far `spot` is from the nearest acorn arriving at about the same time.
## Used to keep fruit from being dangled on top of a hit.
func _clearance(spot: Vector2, seconds: float) -> float:
	var nearest := 999.0
	for child in _fallers.get_children():
		var faller := child as Faller
		if faller == null or faller.resolved or faller.kind != Faller.Kind.ACORN:
			continue
		if absf(faller.seconds_left() - seconds) > 0.45:
			continue
		nearest = minf(nearest, spot.distance_to(faller.position) - Faller.HIT_RADIUS)
	return nearest


## Is there anywhere the player can actually BE when this lands?
##
## Samples the disc they can reach in the time available and asks whether any
## of it is clear of every acorn arriving at about that moment. `extra` is a
## placement being CONSIDERED, counted as though it had already been thrown;
## leave it out to ask about the field as it currently stands.
##
## Being cornered is this game's version of Riverleap's "every pad in the row
## went at once": not difficulty, just an unwinnable frame.
##
## Instantaneous, not predictive -- it answers "could they get somewhere from
## where they are now", which is the only promise the director can keep.
func escape_exists(seconds: float, extra := Vector2.INF) -> bool:
	var radius := reach(seconds)
	var blockers: Array[Vector2] = []
	if extra.is_finite():
		blockers.append(extra)
	for child in _fallers.get_children():
		var faller := child as Faller
		if faller == null or faller.resolved or faller.kind != Faller.Kind.ACORN:
			continue
		if faller.seconds_left() <= seconds + ESCAPE_WINDOW:
			blockers.append(faller.position)

	# Rings rather than a grid: what matters is whether a direction is open,
	# and the player leaves from the middle.
	#
	# Ring 0 is where they are already standing, and leaving it out was a real
	# bug: a player standing somewhere perfectly safe, with too little time
	# left to go anywhere else, came out as "cornered". Staying put is an
	# escape -- it is the one every good player uses most.
	#
	# A plain array literal is untyped, so `ring` would be a Variant and every
	# expression built from it loses its type -- which in GDScript is a PARSE
	# error, not a warning, and takes the whole script down with it.
	var rings: Array[float] = [0.0, 1.0, 0.72, 0.42]
	for ring in rings:
		for step in 12:
			var spot := _player.position \
					+ Vector2.RIGHT.rotated(float(step) * TAU / 12.0) * radius * ring
			if not FIELD.has_point(spot):
				continue
			if ring <= 0.0 and step > 0:
				break                      # ring 0 is one point, not twelve
			var clear := true
			for blocker in blockers:
				if spot.distance_to(blocker) < Faller.HIT_RADIUS + ESCAPE_MARGIN:
					clear = false
					break
			if clear:
				return true
	return false


## --- landings ----------------------------------------------------------------

func _on_landed(faller: Faller) -> void:
	var at := faller.position
	var near := _player.position.distance_to(at) < faller.radius()
	if faller.kind == Faller.Kind.SUNFRUIT:
		if _first_fruit_at < 0.0:
			_first_fruit_at = play_time()
		if near:
			_catch(at)
		else:
			# A missed fruit does not break the combo. It has already cost the
			# player the bar it would have filled, and punishing it twice
			# would make reaching for a far one worse than ignoring it.
			_missed += 1
			Audio.sfx(&"tick", 0.6)
	else:
		if _first_acorn_at < 0.0:
			_first_acorn_at = play_time()
		if near and _stun <= 0.0:
			_take_hit(at)
		else:
			Audio.sfx(&"step", randf_range(0.7, 0.9))
	faller.clear_mark()
	faller.queue_free()


func _catch(at: Vector2) -> void:
	_fruit += 1
	_combo += 1
	_best_combo = maxi(_best_combo, _combo)
	var multiplier := combo_multiplier()
	_score += SCORE_FRUIT * multiplier
	_refresh_score()
	# A chain feeds the bar harder as well as scoring more, so the greedy line
	# through the field is also the one that keeps you alive.
	_feed(FRUIT_GAIN * lerpf(1.0, 1.35,
			float(multiplier - 1) / float(COMBO_MAX - 1)))
	_hud.set_multiplier(multiplier)
	Audio.sfx(&"pickup", 1.0 + 0.08 * multiplier)
	pop(at, SCORE_FRUIT * multiplier, multiplier)
	_flash(at, Color(1, 0.9, 0.5))


func _take_hit(at: Vector2) -> void:
	_hits += 1
	_combo = 0
	_score = maxi(_score + SCORE_HIT, -int(_survival_score))
	_stun = STUN_SECONDS
	_player.freeze()
	_player.cancel_jump()
	_refresh_score()
	_hud.set_multiplier(1)
	_feed(-HIT_BITE)
	Audio.sfx(&"hit", 0.9)
	_camera.kick(0.8)
	pop_on_player(SCORE_HIT, "BONK")
	_flash(at, Color(1, 0.6, 0.45))
	if _vitality <= 0.0:
		_collapse()


func combo_multiplier() -> int:
	return clampi(1 + _combo / COMBO_PER_LEVEL, 1, COMBO_MAX)


func _flash(at: Vector2, colour: Color) -> void:
	var flash := Sprite2D.new()
	flash.texture = preload("res://assets/game/acorn_storm/burst.png")
	flash.position = at
	flash.modulate = colour
	flash.z_index = Faller.Z_BODY
	_fallers.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector2(1.7, 1.7), 0.22)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.22)
	tween.tween_callback(flash.queue_free)


## --- the curve and the launch ------------------------------------------------

static func intensity_at(seconds: float) -> float:
	return MiniGame.curve(seconds, GENTLE_SECONDS, GENTLE_CEILING, STEEP_TAU)


## 0 at the gun, 1 once the gale is up.
func launch_factor() -> float:
	return smoothstep(0.0, LAUNCH_SECONDS, elapsed)


## Seconds of actual play. Nothing falls while the wind is still getting up,
## so the difficulty curve and the acorn debut both measure from the moment
## the game really starts -- otherwise the gentle opening is two seconds short.
func play_time() -> float:
	return maxf(elapsed - LAUNCH_SECONDS, 0.0)


func sequence_started() -> bool:
	return elapsed >= LAUNCH_SECONDS


## --- the end -----------------------------------------------------------------

func _collapse() -> void:
	if _ending:
		return
	_ending = true
	_vitality = 0.0
	_refresh_bar()
	_hud.set_multiplier(1)
	_hud.toast("THE STORM WINS", Color(1, 0.55, 0.45), 1.6)
	Audio.sfx(&"complete", 0.6)
	_camera.kick(1.0)
	_player.freeze()
	for child in _fallers.get_children():
		var faller := child as Faller
		if faller != null:
			faller.clear_mark()
	await Wait.on(self, 1.3)
	if is_finished():
		return
	var total := maxi(_score + int(_survival_score), 0)
	_hud.set_score(total)
	finish(total, {
		"fruit": _fruit,
		"hits": _hits,
		"missed": _missed,
		"chain": _best_combo,
		"survived": int(_survived),
		"skipped": _skipped_acorns,
	})


## Endless, so the comparable number is how long you held the bar up, not the
## points -- two endless games compared on points compare their scoring rates
## rather than their players.
func normalised_score(_raw: int) -> int:
	return normalised_from_duration(_survived, PAR_SECONDS)


## Stands in for the shell while it is parked: results, then straight back in.
func _on_run_finished(result: MiniGameResult) -> void:
	var best := Save.best()
	Save.submit(result.score)
	var card := RunCard.new()
	add_child(card)
	var shown_at := Time.get_ticks_msec()
	card.replay.connect(func() -> void:
		StartCard.note_idle(Time.get_ticks_msec() - shown_at)
		get_tree().reload_current_scene())
	var held := int(result.stats.get("survived", 0))
	card.show_run("ACORN STORM", result.score, [
		["held on", "%d:%02d" % [held / 60, held % 60]],
		["sunfruit", "%d" % int(result.stats.get("fruit", 0))],
		["best chain", "x%d" % maxi(int(result.stats.get("chain", 0)), 1)],
		["acorns taken", "%d" % int(result.stats.get("hits", 0))],
	], best)
