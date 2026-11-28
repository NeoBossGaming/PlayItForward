extends SoakBase
## Hush Meadow soak. Run it with:
##
##     godot --headless --fixed-fps 60 --path . tests/hush_test.tscn
##
## The harness it stands on -- check counting, input synthesis, frame pumping,
## reporting -- lives in soak_base.gd and is shared with every other game.
##
## **Cover that is still cover when you get there is the assertion this file
## exists for.** Riverleap guarantees a reachable safe pad and Acorn Storm a
## reachable clear spot; both are about SPACE. Here the meadow scrolls, so a
## patch expires, and the guarantee gains a second half: not just "can she get
## there" but "will it still be there when she arrives". That is a strictly
## harder promise and it is the one thing in this game that cannot be seen in
## a screenshot.
##
## Everything reachability-flavoured here is computed in the TEST from the
## patches, the scroll rate and the cones -- never by calling the game's own
## patch_is_usable(). A test that asks the game whether the game is right
## cannot catch the game being wrong; both other suites record the same
## reasoning for the same check.

const SCENE := "res://src/minigames/hush_meadow/hush_meadow.tscn"
const GAME := "res://src/minigames/hush_meadow/hush_meadow.gd"
const PATCH := "res://src/minigames/hush_meadow/patch.gd"

## Constants are READ from the game rather than copied. A test carrying its own
## copy of a number goes on passing after the game's changes -- while measuring
## something the game no longer does, which is worse than failing, because
## nothing tells you.
static func _const(name: String) -> Variant:
	return (load(GAME) as GDScript).get_script_constant_map()[name]

static func _patch_const(name: String) -> Variant:
	return (load(PATCH) as GDScript).get_script_constant_map()[name]

static func field() -> Rect2:
	return _const("FIELD")

static func launch_over() -> float:
	return _const("LAUNCH_SECONDS")

static func walk() -> float:
	return _const("WALK")

static func reaction() -> float:
	return _const("REACTION")

## A beginner should get at least this long out of their credit.
const OPENING_FLOOR := 45.0
## Nothing may run longer than this in the suite. A bot still holding its nerve
## here has proved everything any check asks of it, and letting the good ones
## run to their real end would put minutes on every run of the suite.
const MAX_SECONDS := 170.0
## Reaction times the bots are measured at, in milliseconds: a quick player, an
## average one, and somebody who has never seen the cabinet before.
const REACTIONS := [133, 216, 300]
## Runs per reaction time. One of anything in a game this random is an anecdote
## -- and four was still one: the table came out 83s / 58s / 72s across rising
## reaction times, which is noise wearing a measurement's clothes.
const TRIALS := 6
## How close the bot gets before it stops walking.
const ARRIVE := 7.0
## With nothing to walk at, the bot keeps itself above this fraction of the
## field. A little below the middle, which is about where a person stands.
const STATION := 0.48
## Seconds of life a patch should have left when the bot gets there, by
## preference. Below this it is a patch that delivers her onto the edge.
const SPARE_LIFE := 2.0
## Waiting in cover for a cone to look away is only worth it with this much
## room above the bottom edge.
const EDGE_ROOM := 14.0
## How wide a berth the bot gives a bird's body when choosing a route.
const BIRD_BERTH := 36.0
## The longest the player may be left with nowhere to go. Not zero: the instant
## a patch crosses the bottom edge there can honestly be a beat with nothing
## usable, and a player walking across open ground is MEANT to be exposed. A
## gap longer than this is a run that ended on arithmetic.
const COVER_GAP_LIMIT := 2.0
## What "no cover in sight from here" is worth when averaging how far cover is.
## Beyond the field's own diagonal: further than anywhere actually is.
const NO_COVER := 470.0

## How the bots play, which is the whole of what this suite can say about
## whether the design works.
enum Mode {
	STILL,      ## never touches the controls
	HIDE,       ## rides whatever patch it is in, and never goes looking
	FORAGE,     ## works the meadow: cover to cover, taking the dew
	PRIZE,      ## walks straight at the golden and nothing else
}

var _last_run: String = ""
var _last_dew: int = 0
var _last_spotted: int = 0
var _runs: int = 0
var _golden_runs: int = 0

## Each step is announced before it runs and timed after it. This suite drives
## several whole runs, and when one does not come back the only question worth
## asking is which -- without the trace, a hang and a slow machine look exactly
## the same from outside.
var _step_started: int = 0


func _step(name: String) -> void:
	var now := Time.get_ticks_msec()
	if _step_started > 0:
		print("  .. %.1fs" % (float(now - _step_started) / 1000.0))
	_step_started = now
	if not name.is_empty():
		print("  .. %s" % name)


func _ready() -> void:
	_step("contract");                    await _test_contract()
	_step("the curve");                   await _test_the_curve()
	_step("the ground cannot grid");      await _test_the_ground_cannot_grid()
	_step("cover is honest");             await _test_cover_is_honest()
	_step("draw order");                  await _test_draw_order()
	_step("the launch is quiet");         await _test_the_launch_is_quiet()
	_step("dew only shows in cover");     await _test_dew_only_shows_in_cover()
	_step("she rides the meadow");        await _test_she_rides_the_meadow()
	_step("the edge bites");             await _test_the_edge_bites()
	_step("there is no sprint");         await _test_there_is_no_sprint()
	_step("a pebble turns a head");      await _test_a_pebble_turns_a_head()
	_step("there is always cover");       await _test_there_is_always_cover()
	_step("dew outpaces the rise");       await _test_dew_can_outpace_the_rise()
	_step("a cone gives you time");       await _test_a_cone_gives_you_time()
	_step("birds do not twitch");         await _test_birds_do_not_twitch()
	_step("a run must end");              await _test_a_run_must_end()
	_step("hiding is not a strategy");    await _test_hiding_is_not_a_strategy()
	_step("the opening is survivable");   await _test_the_opening_is_survivable()
	_step("how hard it is");              await _test_how_hard_it_is()
	_step("cover thins out");             await _test_cover_thins_out()
	_step("the golden can be caught");    await _test_the_golden_can_be_caught()
	_step("the opening card");            await _test_the_opening_card()
	_step("the card shows what it says"); await _test_the_card_shows_what_it_says()
	_step("the art is pixel art");        await _test_the_art_is_pixel_art()
	_step("")

	get_tree().quit(report("HUSH MEADOW"))


# --- the contract ------------------------------------------------------------

func _test_contract() -> void:
	_check(Audio != null, "Audio autoload missing")

	var game: Node = await _start()
	_check(game.id == &"hush_meadow", "the game reports id %s" % game.id)
	_check(game.par_score > 0, "par_score must be positive")

	var results: Array = []
	game.finished.connect(func(r: MiniGameResult) -> void: results.append(r))
	# Fill the meter outright: the run must end, once, and report once.
	# Pinned AFTER the launch. Set before it, the meter is quietly refunded by
	# the first dew she walks over -- she starts inside a seeded patch -- and
	# the run then never ends, which reads as the ending being broken.
	await _play(game, launch_over() + 0.3)
	game._nerve = 1.0
	# Long enough for _flush()'s own hold before it reports.
	await _play(game, 2.4)
	_check(results.size() == 1,
			"a run whose nerve filled reported %d times, expected exactly one"
			% results.size())
	if results.size() == 1:
		var result: MiniGameResult = results[0]
		_check(result.score >= 0, "a result carried a negative score")
		_check(result.normalised >= 0 and result.normalised <= 1000,
				"normalised %d is outside 0-1000" % result.normalised)
	_drop(game)


func _test_the_curve() -> void:
	var curve: Callable = (load(GAME) as GDScript).get("intensity_at")
	var gentle: float = _const("GENTLE_SECONDS")
	var ceiling: float = _const("GENTLE_CEILING")
	_check(curve.call(0.0) == 0.0, "the curve must start at zero")
	_check(is_equal_approx(curve.call(gentle), ceiling),
			"the gentle stretch must land exactly on its ceiling")
	# Approaches 1 without arriving, which is what "there is always a next
	# thirty seconds that is worse than this one" means in arithmetic.
	var late: float = curve.call(900.0)
	_check(late < 1.0, "the curve reached %.4f -- it must never arrive" % late)
	_check(late > 0.9, "the curve only reached %.3f after fifteen minutes" % late)
	var a: float = curve.call(gentle + 10.0)
	var b: float = curve.call(gentle + 60.0)
	_check(b > a, "the curve must keep climbing after the gentle stretch")


## Two layers, two periods. Different tile size AND a different rate, or the
## ground grids -- setting the rates equal brings it straight back and nothing
## else in the suite would catch it.
func _test_the_ground_cannot_grid() -> void:
	var game: Node = await _start()
	await _play(game, 3.0)
	var ground: Vector2 = game._ground.texture.get_size()
	var shade: Vector2 = game._shade.texture.get_size()
	_check(ground != shade,
			"the two ground layers are both %s -- same period, visible grid"
			% ground)
	var rate: float = _const("SHADE_RATE")
	_check(not is_equal_approx(rate, 1.0),
			"the shade drifts at the ground's own rate, so the two patterns "
			+ "lock together and the grid comes back")
	_check(game._ground.scroll.y > 0.0, "the meadow is not moving")
	_check(not is_equal_approx(game._ground.scroll.y, game._shade.scroll.y),
			"both layers scroll at %.2f px/s" % game._ground.scroll.y)
	_drop(game)


## Anywhere that LOOKS like cover has to BE cover. The concealment rect must
## cover everything drawn, or the player steps into grass with a beak coming
## and finds out the edge was decoration.
func _test_cover_is_honest() -> void:
	var half: Vector2 = _patch_const("PATCH_HALF")
	var spread: Vector2 = _patch_const("SPREAD")
	var lift: float = _patch_const("DRAW_LIFT")
	var clump: Vector2 = (load("res://assets/game/hush_meadow/grass_0.png")
			as Texture2D).get_size()
	var drawn := Vector2(
		spread.x + clump.x * 0.5,
		spread.y + clump.y * 0.5 + lift)
	_check(half.x >= drawn.x,
			"a patch draws %.1fpx wide of centre but only hides %.1f"
			% [drawn.x, half.x])
	_check(half.y >= drawn.y,
			"a patch draws %.1fpx high of centre but only hides %.1f"
			% [drawn.y, half.y])


## Where something is drawn says what it is. Resolved up the parent chain,
## because child z_index is RELATIVE and this rule has shipped inverted once
## with every constant in the file correct and only the scene wrong.
func _test_draw_order() -> void:
	var game: Node = await _start()
	await _play(game, 2.0)
	var player := game._player as CanvasItem
	_check(not game._patches.is_empty(), "no patches were built")
	if game._patches.is_empty():
		_drop(game)
		return

	var patch: Node2D = game._patches[0]
	var blade: CanvasItem = null
	var disc: CanvasItem = null
	for child in patch.get_children():
		var item := child as CanvasItem
		if item == null or item is MeadowPickup:
			continue
		if disc == null:
			disc = item          # built first
		else:
			blade = item
	if blade != null:
		_check(effective_z(blade) > effective_z(player),
				"blades draw at z %d, under the player at %d -- standing in "
				% [effective_z(blade), effective_z(player)]
				+ "grass has to LOOK like standing in grass")
	if disc != null:
		_check(effective_z(disc) < effective_z(player),
				"the cover disc draws at z %d, over the player at %d"
				% [effective_z(disc), effective_z(player)])

	# The cone must clear the blades. A player who cannot see what is looking
	# at her is playing a guessing game.
	if not game._birds.is_empty():
		var cone := game._birds[0].get_node("Cone") as CanvasItem
		if blade != null:
			_check(effective_z(cone) > effective_z(blade),
					"a vision cone draws at z %d, under grass at z %d"
					% [effective_z(cone), effective_z(blade)])
	_drop(game)


## Nothing is thrown at the player while the meadow is still getting going.
func _test_the_launch_is_quiet() -> void:
	var game: Node = await _start()
	await _play(game, launch_over() * 0.6)
	_check(game._nerve <= 0.0001,
			"nerve reached %.3f during the launch" % game._nerve)
	_check(game.scroll_speed() < _const("SCROLL").x,
			"the meadow was already at full speed during the launch")
	await _play(game, launch_over())
	_check(game._nerve > 0.0, "nerve never started rising after the launch")
	_drop(game)


## The layers that fill the screen must not drift back to noise. The meadow
## shipped at a mean run of 1.8 px and the cover disc at 1.7 through 208 alpha
## levels -- the grain of a photograph -- and every check passed, because
## nothing was asking. Riverleap's water, the reference, is 20. A clump or a
## cover disc is small and has an outline, so it is held to less than a tile.
func _test_the_art_is_pixel_art() -> void:
	_check_grain("res://assets/game/hush_meadow/meadow.png", 10.0)
	_check_grain("res://assets/game/hush_meadow/meadow_shade.png", 10.0)
	for i in 3:
		_check_grain("res://assets/game/hush_meadow/grass_%d.png" % i, 6.0)
	_check_grain("res://assets/game/hush_meadow/grass_cover.png", 6.0)


# --- the rule the game is built on -------------------------------------------

## Dew is not on the meadow until the player is inside the patch holding it.
## That one rule is what makes cover somewhere to GO rather than only somewhere
## to hide, and the entire survival loop hangs off it.
func _test_dew_only_shows_in_cover() -> void:
	var game: Node = await _start()
	await _play(game, 1.0)

	var patch: MeadowPatch = null
	var dew: MeadowPickup = null
	for candidate in game._patches:
		# Must be a patch she can actually stand in. Patches are planted ABOVE
		# the field and scroll down, and _process clamps the player back
		# inside it -- so parking her on one that has not arrived yet puts her
		# below it and the dew correctly stays hidden, which looks exactly
		# like the rule being broken.
		if not field().has_point(candidate.position):
			continue
		for child in candidate.get_children():
			var pickup := child as MeadowPickup
			# Unrevealed: she starts in the middle of a seeded meadow and is
			# very likely standing in a patch already, so the first dew in the
			# list is often one she has legitimately just found.
			if pickup != null and pickup.kind == MeadowPickup.Kind.DEW \
					and not pickup.revealed:
				patch = candidate
				dew = pickup
				break
		if dew != null:
			break

	_check(dew != null, "no patch on the opening meadow carries any dew")
	if dew == null:
		_drop(game)
		return

	# Park her in the far corner. Nudging her a fixed distance off the patch
	# put her back inside it once the clamp had its say, so she collected the
	# very dew under test and the check crashed on a freed object.
	var f := field()
	var corner := Vector2(
		f.position.x + 6.0 if patch.position.x > f.get_center().x
				else f.end.x - 6.0,
		f.position.y + 6.0 if patch.position.y > f.get_center().y
				else f.end.y - 6.0)
	game._player.position = corner
	await _frames(3)
	_check(not patch.hides(game._player.position),
			"the player could not be moved out of the patch under test")
	_check(is_instance_valid(dew) and not dew.revealed,
			"dew revealed itself with nobody in the patch")
	if not is_instance_valid(dew):
		_drop(game)
		return
	_check(not dew.get_node("Sprite").visible,
			"hidden dew is still being drawn")

	game._player.position = patch.position
	await _frames(3)
	# hides(), not patch_at() == patch: patches overlap, so patch_at can
	# truthfully name a different one while she is standing in both.
	_check(patch.hides(game._player.position),
			"the player was not actually inside the patch under test")
	# Collected counts as shown. Dropped on the patch centre she is often
	# within the pickup radius of it, so the dew can reveal and be taken on
	# the same frame -- which is the rule working, and reading `revealed` off
	# the freed object afterwards is the test being wrong, not the game.
	var showed := not is_instance_valid(dew) or dew.revealed
	_check(showed, "dew stayed hidden with the player standing in it")
	_drop(game)


## The bug Neo reported: "the player does not follow the scrolling, rather goes
## up along with the camera". The meadow slid down while she stayed pinned to
## the screen, so grass passed through her like scenery. Things on the ground
## move with the ground -- and _catch_time() above is only correct because
## they do. Verified by re-breaking it.
func _test_she_rides_the_meadow() -> void:
	var game: Node = await _start()
	await _play(game, launch_over() + 0.5)
	# High on the field, so a second of drift cannot reach the clamp and stop
	# her for a reason that has nothing to do with riding.
	game._player.position = Vector2(field().get_center().x,
			field().position.y + 20.0)
	var patch: MeadowPatch = null
	for candidate in game._patches:
		if candidate.position.y < field().end.y - 60.0:
			patch = candidate
			break
	_check(patch != null, "no patch to compare her drift against")
	if patch == null:
		_drop(game)
		return
	var she_was: float = game._player.position.y
	var it_was := patch.position.y
	await _play(game, 1.0)
	var she_moved: float = game._player.position.y - she_was
	var it_moved := patch.position.y - it_was
	print("  riding     meadow moved %.1fpx in a second, she moved %.1fpx"
			% [it_moved, she_moved])
	_check(it_moved > 5.0, "the meadow only moved %.1fpx in a second" % it_moved)
	_check(absf(she_moved - it_moved) < 0.5,
			"the meadow moved %.1fpx and she moved %.1fpx -- the ground is "
			% [it_moved, she_moved] + "sliding out from under her")
	_drop(game)


## The price of riding, at the bottom of the SCREEN. Neo asked for the border
## to sit "a little offscreen, but the player still gets punished for doing
## so". So: the ground just above the bottom of the screen is free; past it the
## nerve climbs faster than under a bird's eye, in grass or out; she can be
## carried no more than OVERHANG below it; the alarm is up from the first
## frame; and one push of the stick brings her back.
func _test_the_edge_bites() -> void:
	var game: Node = await _start()
	await _play(game, launch_over() + 0.3)
	# Nothing can see her, so what is measured is the edge and only the edge.
	game._mercy = 99.0
	var overhang: float = _const("OVERHANG")

	game._nerve = 0.0
	game._player.position = Vector2(field().get_center().x, _edge_of(game) - 6.0)
	await _frames(1)
	_check(not game._over_edge,
			"6px above the bottom of the screen already counts as over the "
			+ "edge -- the border has not moved down")

	game._player.position = Vector2(field().get_center().x, _edge_of(game) + 200.0)
	await _frames(2)
	var edge := _edge_of(game)
	var y: float = game._player.position.y
	# A fixed few pixels, not a fraction of OVERHANG: read from the game, an
	# overhang set to zero would make this check ask for zero and pass.
	_check(y > edge + 4.0,
			"she stopped at %.1f, %.1fpx from the bottom of the screen -- the "
			% [y, y - edge] + "meadow should carry her a little way past it")
	_check(y <= edge + overhang + 0.5,
			"she went %.1fpx past the bottom of the screen, more than the %.0f "
			% [y - edge, overhang] + "it may carry her")
	_check(game._over_edge, "below the bottom of the screen is not counted as over the edge")
	var alarm: CanvasItem = game._hud.get_node("Root/Alarm")
	_check(alarm.modulate.a > 0.0, "over the edge with no alarm showing")

	var from: float = game._nerve
	var clock := 0.0
	while clock < 1.0:
		await _frames(1)
		clock += get_process_delta_time()
	var rate: float = (game._nerve - from) / clock
	print("  edge       %.0fpx below the screen at most; nerve %.2f/s there, %.2f/s seen"
			% [overhang, rate, float(_const("NERVE_SEEN"))])
	_check(rate > float(_const("NERVE_SEEN")) * 1.3,
			"over the edge raised nerve %.2f/s, barely more than a bird's "
			% rate + "eye does -- the boundary does not read as one")

	# One push brings her back.
	_hold(&"move_up")
	clock = 0.0
	while clock < 0.4:
		await _frames(1)
		clock += get_process_delta_time()
	_release_all()
	_check(not game._over_edge,
			"0.4s of pushing up did not bring her back over the edge")
	_drop(game)


## Neo: "remove sprint, it makes it so weird". Held while walking, the button
## makes her no faster -- the walk is the only pace there is.
func _test_there_is_no_sprint() -> void:
	var game: Node = await _start()
	await _play(game, launch_over() + 0.3)
	game._mercy = 99.0
	game._player.position = Vector2(field().position.x + 10.0, field().get_center().y)
	_hold(&"move_right")
	await _frames(1)
	_hold(&"act")
	await _play(game, 0.4)
	var from: float = game._player.position.x
	var clock := 0.0
	var fastest := 0.0
	while clock < 0.6:
		var x: float = game._player.position.x
		await _frames(1)
		var dt := get_process_delta_time()
		clock += dt
		fastest = maxf(fastest, (float(game._player.position.x) - x) / dt)
	_release_all()
	print("  no sprint  button held while walking: %.0f px/s, walk is %.0f"
			% [fastest, walk()])
	_check(not game._player.can_sprint, "the player can still sprint")
	_check(fastest <= walk() * 1.05,
			"holding the button while walking moved her at %.0f px/s, faster than "
			% fastest + "the %.0f walk -- the sprint is still in there" % walk())
	_check(float(game._player.position.x) > from,
			"she did not walk at all with the stick held")
	_drop(game)


## The button's new job. A pebble lands where she aims; a bird within earshot
## goes to look -- flies there with its cone on it -- and there is not another
## until it has recharged. Thrown through real input, stick then button, the
## way a person does it.
func _test_a_pebble_turns_a_head() -> void:
	var game: Node = await _start()
	await _play(game, launch_over() + 0.3)
	game._mercy = 99.0
	_check(not game._birds.is_empty(), "no bird to throw a pebble for")
	if game._birds.is_empty():
		_drop(game)
		return
	var bird: PatrolBird = game._birds[0]
	var range_px: float = _const("PEBBLE_RANGE")
	# Stand her so the pebble lands well inside the bird's earshot, in open
	# field, to the bird's left.
	var landing := Vector2(field().get_center().x, field().get_center().y - 20.0)
	bird.drift(landing + Vector2(70.0, -10.0) - bird.global_position)
	game._player.position = landing - Vector2(range_px, 0.0)
	var drift_before: float = game._player.position.y

	_hold(&"move_right")
	await _frames(1)
	_hold(&"act")
	await _frames(1)
	_release_all()
	_check(game._pebbles_thrown == 1,
			"pressing the button threw %d pebbles, expected one" % game._pebbles_thrown)
	_check(not game.toss_pebble(Vector2.RIGHT),
			"a second pebble went straight after the first -- it never has to "
			+ "recharge, so a bird can be kept busy forever")

	await _play(game, float(_const("PEBBLE_FLIGHT")) + 0.1)
	var looking := bird._investigating > 0.0
	var where: Vector2 = bird._investigate_point
	# Where it should have landed, carried as far down as the meadow has moved.
	var expected := landing + Vector2(0.0, float(game._player.position.y) - drift_before)
	_check(looking, "a pebble landed %.0fpx from a bird and it did not come to look"
			% landing.distance_to(bird.global_position))
	_check(where.distance_to(expected) < 12.0,
			"the bird went to look at %s, but the pebble landed near %s"
			% [where.round(), expected.round()])
	await _play(game, 0.8)
	var facing_it: float = bird.facing.dot((bird._investigate_point
			- bird.global_position).normalized())
	_check(bird.global_position.distance_to(bird._investigate_point) < 6.0
			or facing_it > 0.7,
			"the bird is not looking at the pebble (facing %.2f)" % facing_it)

	await _play(game, float(_const("PEBBLE_RECHARGE")))
	_check(game.toss_pebble(Vector2.LEFT), "no pebble ready after a full recharge")
	print("  pebble     a bird %.0fpx away went to look; recharge %.0fs"
			% [70.0, float(_const("PEBBLE_RECHARGE"))])
	_drop(game)


## The assertion this file exists for.
##
## Sampled every frame of a driven run and computed HERE from the patches, the
## scroll rate and the cones. "Usable" is: she can walk to it, it is still on
## the field when she arrives, and it is not currently under an eye.
##
## A momentary gap is allowed and a long one is not. Cover EXPIRES in this
## game, so the instant a patch crosses the bottom edge there can honestly be a
## beat with nothing usable, and asserting zero gaps would report dead ends on
## a game that has none -- the same false positive Acorn Storm's cornering
## check started out with. What matters is that no gap lasts long enough to be
## a run ending on arithmetic.
func _test_there_is_always_cover() -> void:
	var game: Node = await _start()
	var worst := 0.0
	var gap := 0.0
	var samples := 0
	var starved := 0
	var clock := 0.0
	var aim_at: Node2D = null

	while clock < 70.0 and is_instance_valid(game) and not game.is_finished():
		await _frames(1)
		var delta := get_process_delta_time()
		clock += delta
		# Pinned open while this measures. Left alone the bot dies partway
		# through and the rest of the sample is seconds of a stopped game -- a
		# sample that quietly stops being a sample is the same class of bug as
		# a test that passes for the wrong reason.
		game._nerve = minf(game._nerve, 0.4)
		aim_at = _choose(game, Mode.FORAGE)
		_drive(game, aim_at)
		if clock < launch_over():
			continue
		samples += 1
		if _usable_count(game, game._player.position) > 0:
			gap = 0.0
		else:
			starved += 1
			gap += delta
			worst = maxf(worst, gap)
	_release_all()

	print("  cover      %d of %d frames with nowhere to go, worst gap %.2fs"
			% [starved, samples, worst])
	_check(worst <= COVER_GAP_LIMIT,
			"the player was left with no reachable patch for %.2fs (limit %.2f)"
			% [worst, COVER_GAP_LIMIT])
	# A flood of rescue placements means the meadow has grown too sparse to
	# play and the floor is propping the game up rather than protecting the
	# player -- which passes the check above while breaking the game.
	var rescues: int = game._crowded_placements
	print("  director   %d rescue placements in %.0fs" % [rescues, clock])
	_check(rescues < 24,
			"the director had to rescue cover %d times in %.0fs -- the meadow "
			% [rescues, clock] + "is too sparse to play")
	_drop(game)


## Dew on offer has to be worth more nerve per second than the open meadow
## costs, at every point on the curve. Without this a run could end on
## arithmetic rather than on anything the player did, and no other check would
## notice.
func _test_dew_can_outpace_the_rise() -> void:
	var gap: Vector2 = _const("PATCH_GAP")
	var scroll: Vector2 = _const("SCROLL")
	var chance: float = _const("DEW_CHANCE")
	var calm: float = _const("DEW_CALM")
	var open: Vector2 = _const("NERVE_OPEN")
	for i in 4:
		var t := float(i) / 3.0
		var speed := lerpf(scroll.x, scroll.y, t)
		var spacing := lerpf(gap.x, gap.y, t)
		# The meadow grows one stand every `spacing` pixels and carries them
		# past at `speed`, so that is how many arrive per second.
		var per_second: float = speed / spacing
		var supply: float = per_second * chance * calm
		var rise := lerpf(open.x, open.y, t)
		_check(supply > rise * 1.2,
				"at intensity %.2f the meadow offers %.4f nerve/s of dew "
				% [t, supply] + "against a %.4f/s rise -- the run ends on "
				% rise + "arithmetic, not on anything the player did")
		if i == 0 or i == 3:
			print("  supply     i=%.2f  dew %.4f/s  vs rise %.4f/s  (x%.2f)"
					% [t, supply, rise, supply / maxf(rise, 0.0001)])


## A cone has to be on her long enough to be reacted to before it fills. A
## stealth game whose detection is faster than a person is a game that
## punishes you for something you could not have done anything about.
func _test_a_cone_gives_you_time() -> void:
	var fill := 1.0 / PatrolBird.ALERT_RISE
	_check(fill >= reaction(),
			"suspicion fills in %.2fs, inside the %.2fs reaction the rest of "
			% [fill, reaction()] + "this game is built around")
	print("  detection  %.2fs to fill, against a %.2fs reaction"
			% [fill, reaction()])


## A regression test, for a bug that is already fixed in bird.gd: calling
## direction_to() at near-zero distance rebuilds facing out of floating-point
## residue, so a hovering bird's cone flipped every single frame. Verified by
## re-breaking it.
func _test_birds_do_not_twitch() -> void:
	var game: Node = await _start()
	await _play(game, 2.0)
	if game._birds.is_empty():
		_check(false, "no birds to watch")
		_drop(game)
		return

	var bird: PatrolBird = game._birds[0]
	# Send it to investigate where it already is, which is exactly the state
	# that used to twitch.
	bird.investigate(bird.global_position)
	await _frames(4)
	var flips := 0
	var previous := bird.facing
	for i in 40:
		await _frames(1)
		if previous.dot(bird.facing) < 0.6:
			flips += 1
		previous = bird.facing
	_check(flips == 0,
			"a hovering bird's facing jumped %d times in 40 frames" % flips)
	_drop(game)


# --- what the bots say about it ----------------------------------------------

func _test_a_run_must_end() -> void:
	var held := await _bot(0, Mode.STILL, MAX_SECONDS)
	_check(held < MAX_SECONDS,
			"a bot that never touched the controls was still playing after "
			+ "%.0fs" % MAX_SECONDS)
	print("  ending     a motionless run died after %5.1fs  (%s)"
			% [held, _last_run])


## The design claim, turned into an assertion -- but measured on dew rather
## than on survival time.
##
## Survival time cannot carry this. Six pairs of whole runs on one unchanged
## build gave hiding 61s / 87s / 96s against foraging 137s / 102s / 88s: the
## claim came out true, false and true on the same code, because a run ends on
## one bad cascade and the cap truncates the good tail. Tuning a game against
## a number that noisy is how you spend an afternoon chasing your own
## variance.
##
## What IS stable is how much dew each way of playing finds per second, and
## that is the claim anyway: dew is the only thing that lowers the meter, so
## "hiding is not a strategy" means exactly "hiding does not find dew".
## Survival times are still printed, because they are what tuning needs -- but
## nothing is asserted on them.
func _test_hiding_is_not_a_strategy() -> void:
	# Hiding perfectly, collecting nothing, must still run out. This half is
	# arithmetic rather than a bot, and it is the half that has to be exactly
	# true: if NERVE_HIDDEN were zero there would be a corner of this game you
	# could sit in forever.
	var hidden: float = _const("NERVE_HIDDEN")
	_check(hidden > 0.0, "nerve does not rise at all in cover -- grass is a "
			+ "safe corner and a patient player never loses")
	var forever := INF if hidden <= 0.0 else 1.0 / hidden
	_check(forever < MAX_SECONDS,
			"perfect hiding and nothing else lasts %.0fs, which is not a "
			% forever + "delay, it is an answer")
	print("  hiding     doing nothing in cover runs out after %.0fs" % forever)

	const PAIRS := 4
	var hiding := 0.0
	var foraging := 0.0
	var hide_rate := 0.0
	var forage_rate := 0.0
	for trial in PAIRS:
		var held := await _bot(216, Mode.HIDE, MAX_SECONDS)
		hiding += held
		hide_rate += float(_last_dew) / maxf(held, 1.0)
		held = await _bot(216, Mode.FORAGE, MAX_SECONDS)
		foraging += held
		forage_rate += float(_last_dew) / maxf(held, 1.0)
	hiding /= float(PAIRS)
	foraging /= float(PAIRS)
	hide_rate /= float(PAIRS)
	forage_rate /= float(PAIRS)

	print("  strategy   hiding  %5.1fs  %.3f dew/s" % [hiding, hide_rate])
	print("             forage  %5.1fs  %.3f dew/s" % [foraging, forage_rate])
	_check(forage_rate > hide_rate * 1.25,
			"foraging found %.3f dew/s against hiding's %.3f -- going out for "
			% [forage_rate, hide_rate] + "it has to find more than sitting "
			+ "still does, or cover is a safe corner")


func _test_the_opening_is_survivable() -> void:
	var best := 0.0
	for trial in 5:
		best = maxf(best, await _bot(216, Mode.FORAGE, OPENING_FLOOR + 6.0))
	_check(best >= OPENING_FLOOR,
			"the best of five competent runs lasted %.1fs, under the %.0fs a "
			% [best, OPENING_FLOOR] + "stranger should get for their credit")


## The measurement without which "too hard" and "ramps too fast" cannot be told
## apart. A bot that reacts on the frame a thing happens measures a game a
## machine plays rather than the one a person does.
func _test_how_hard_it_is() -> void:
	var line := "  difficulty "
	for reaction_ms in REACTIONS:
		var total := 0.0
		var worst := MAX_SECONDS
		for trial in TRIALS:
			var held := await _bot(reaction_ms, Mode.FORAGE, MAX_SECONDS)
			total += held
			worst = minf(worst, held)
		var mean := total / float(TRIALS)
		line += " %dms %.0fs (worst %.0fs)  " % [reaction_ms, mean, worst]
		print("    %dms: %s" % [reaction_ms, _last_run])
		_check(mean > 18.0,
				"a %dms player averaged %.1fs -- that is a machine that took "
				% [reaction_ms, mean] + "a credit and gave nothing")
	print(line)


## The check that would catch the meadow becoming unplayable or staying
## generous forever: how far she has to go for cover must GROW across a run.
## Pooled into halves, because a handful of samples wobble on noise alone --
## a strict band-over-band rule failed on a 4% flutter in the last game while
## the run as a whole was 23% up.
##
## This is the "passing checks do not mean it is any good" check. Acorn Storm
## shipped with every assertion green and no fun because nothing was asking
## about distance.
func _test_cover_thins_out() -> void:
	var early: Array[float] = []
	var late: Array[float] = []
	var early_n: Array[float] = []
	var late_n: Array[float] = []
	var game: Node = await _start()
	var clock := 0.0
	var aim_at: Node2D = null

	# The bar is pinned open while this measures. Left alone the run ends part
	# way through and the sample is diluted by seconds of a stopped game -- a
	# sample that quietly stops being a sample is the same class of bug as a
	# test that passes for the wrong reason.
	while clock < 170.0 and is_instance_valid(game):
		await _frames(1)
		clock += get_process_delta_time()
		game._nerve = minf(game._nerve, 0.35)
		aim_at = _choose(game, Mode.FORAGE)
		_drive(game, aim_at)
		if clock < launch_over() + 2.0:
			continue
		# Probed from fixed points across the field, NOT from the player.
		# The first version of this check asked how far cover was from where
		# the bot was standing and reported 59px early against 55px late on a
		# meadow that does halve -- because the forage bot walks TOWARD the
		# nearest patch by definition, so that number is a fact about the bot
		# and cannot move. Do not route a test through a heuristic it is not
		# testing; this one is about the meadow, so it asks the meadow.
		var sparsity := _sparsity(game)
		var on_field := 0.0
		for patch in game._patches:
			if field().has_point(patch.position):
				on_field += 1.0
		# The ends of the run, not two halves of it: the curve spends its
		# middle in transition, and averaging that into both buckets is what
		# flattens a meadow that does visibly thin.
		if clock < 60.0:
			early.append(sparsity)
			early_n.append(on_field)
		elif clock > 120.0:
			late.append(sparsity)
			late_n.append(on_field)
	_release_all()
	_drop(game)

	var a := _mean(early)
	var b := _mean(late)
	print("  meadow     cover is %.0fpx from an average spot early -> %.0fpx late"
			% [a, b])
	print("             patches on the field %.1f early -> %.1f late"
			% [_mean(early_n), _mean(late_n)])
	_check(early.size() > 60 and late.size() > 60,
			"only %d/%d distance samples -- not enough to mean anything"
			% [early.size(), late.size()])
	_check(b > a * 1.15,
			"cover sat %.0fpx from an average spot early and %.0fpx late -- "
			% [a, b] + "the meadow never actually thins out, so there is no "
			+ "late game")


## A gift, not a dexterity test. Walked straight at, with NO lag: a bot with
## 216ms of lag gets its stop command 23px after it should have stopped and
## orbits the catch radius, so a collection check on it is a coin flip rather
## than a fact about the prize.
func _test_the_golden_can_be_caught() -> void:
	var caught := 0
	var offered := 0
	for trial in 4:
		var game: Node = await _start()
		# Pin the roll so this measures the prize rather than the dice.
		game._golden_at = 3.0
		var clock := 0.0
		while clock < 40.0 and is_instance_valid(game) and not game.is_finished():
			await _frames(1)
			clock += get_process_delta_time()
			game._nerve = minf(game._nerve, 0.3)
			_drive(game, _choose(game, Mode.PRIZE))
			if game._goldens > 0:
				break
		_release_all()
		if game._gold_live != null or game._goldens > 0:
			offered += 1
		caught += game._goldens
		_drop(game)
	print("  golden     offered %d of 4, caught %d" % [offered, caught])
	_check(offered >= 3,
			"the prize only appeared in %d of 4 pinned runs" % offered)
	_check(caught >= offered - 1,
			"a bot walking straight at the prize caught %d of %d"
			% [caught, offered])


func _test_the_opening_card() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(6)
	var cards := 0
	for child in game.get_children():
		if child is StartCard:
			cards += 1
	_check(cards == 0,
			"the suite built %d start cards -- the game must only show one "
			% cards + "when it IS the running scene")
	game.free()
	await _frames(2)


## The two slides that teach the cone and the dew, built inside a card that is
## really in the tree -- the only place their bug showed. Each set up its
## subject by connecting to `ready` AFTER adding it to a live slide, by which
## time the signal had fired: the bird looked up and away from the girl, and
## the dew never appeared, on the slides about exactly those two things. No
## check looked at either; a capture found both.
func _test_the_card_shows_what_it_says() -> void:
	var was_seen := StartCard.tutorial_seen
	StartCard.tutorial_seen = false
	var card := HushCard.new()
	add_child(card)
	await _frames(1)
	card._build()

	card._show_slide(2)
	var bird: PatrolBird = null
	for child in card._slide.get_children():
		if child is PatrolBird:
			bird = child
	_check(bird != null, "the cone slide has no bird on it")
	if bird != null:
		_check(bird.facing.dot(Vector2.DOWN) > 0.99,
				"the bird on the cone slide is looking along %s, not down at "
				% bird.facing + "the girl it is there to be looking at")

	card._show_slide(3)
	var dew: MeadowPickup = null
	for child in card._slide.get_children():
		if child is MeadowPatch and not child.is_queued_for_deletion():
			for inner in child.get_children():
				if inner is MeadowPickup:
					dew = inner
	_check(dew != null, "the dew slide has no dew on it")
	if dew != null:
		_check(dew.revealed, "the dew on the dew slide is never revealed -- the "
				+ "slide that demonstrates the game's rule shows nothing")

	card.queue_free()
	StartCard.tutorial_seen = was_seen
	await _frames(2)


# --- the bots ----------------------------------------------------------------

func _bot(reaction_ms: int, mode: Mode, limit: float) -> float:
	var game: Node = await _start()
	var lag := float(reaction_ms) / 1000.0
	var decisions: Array = []           # [due_time, target node]
	var clock := 0.0
	# An Array, not a bool. GDScript lambdas capture locals by VALUE, so
	# `ended = true` inside the callback leaves the outer one false -- which
	# does not fail, it just runs every bot for the full limit and turns a
	# two-minute suite into a ten-minute one.
	var ended: Array = []
	game.finished.connect(func(_r: MiniGameResult) -> void: ended.append(true))

	var aim_at: Node2D = null
	while ended.is_empty() and clock < limit and is_instance_valid(game):
		await _frames(1)
		var delta := get_process_delta_time()
		clock += delta
		if mode == Mode.STILL:
			continue
		# The lag is on WHICH thing it goes for, and nothing else. An earlier
		# version delayed the steering vector itself, which does not model a
		# slow player -- it models a bad walker, and it produced a difficulty
		# table that ran 47s / 59s / 35s across rising reaction times, i.e.
		# pure noise. A person tracks the thing they chose continuously; the
		# delay is in noticing there is something new to choose.
		# Cleared the moment it goes stale, BEFORE anything is passed it.
		# is_instance_valid() inside the callee is too late: handing a freed
		# object to a typed Node2D parameter re-checks its class at the call
		# itself and throws there.
		if not is_instance_valid(aim_at):
			aim_at = null
		# It only re-decides when it has to: its target is gone, it has
		# arrived, or something is looking at it. Re-choosing every frame made
		# the lag act as COMMITMENT rather than delay -- a laggier bot stuck
		# with one patch longer and so played BETTER, which is how the table
		# came out 99s / 125s / 106s across rising reaction times.
		# Typed: `game` is a plain Node here, so game._watched is a Variant and
		# everything built from it stops inferring -- a PARSE error, which
		# leaves a headless Godot spinning at 99% CPU on an empty log rather
		# than exiting. That is the third time in this project.
		# The edge is new information exactly as a cone is: the alarm comes
		# on, and a person notices it a reaction time later and moves.
		var settled: bool = is_instance_valid(aim_at) and not game._watched \
				and not game._over_edge and _toward(game, aim_at) != Vector2.ZERO
		if not settled and decisions.is_empty():
			decisions.append([clock + lag, _choose(game, mode)])
		while not decisions.is_empty() and float(decisions[0][0]) <= clock:
			# Through a Variant and an is_instance_valid(): the queue holds
			# node references, and a reaction time's worth of delay is easily
			# long enough for the dew it named to be collected or the patch to
			# scroll off. Assigning a freed instance straight into a typed
			# Node2D throws and kills the whole coroutine, which showed up as
			# every forage bot "surviving" 0.0 seconds.
			var chosen: Variant = decisions.pop_front()[1]
			aim_at = chosen if is_instance_valid(chosen) else null
		_drive(game, aim_at)
	_release_all()

	var held: float = game._survived
	_last_run = "%d dew, %d petals, %d spotted, %.1fs pinned" % [game._dew,
			game._petals, game._spotted, game._over_edge_time]
	_last_dew = game._dew
	_last_spotted = game._spotted
	_runs += 1
	_golden_runs += 1 if game._goldens > 0 else 0
	_drop(game)
	return held


## Which thing to walk at. Returns a live node so the bot keeps tracking it as
## the meadow carries it down the screen -- holding a stale POSITION would send
## it to where the patch used to be, which is a bug in the bot rather than a
## fact about the game.
func _choose(game: Node, mode: Mode) -> Node2D:
	var me: Vector2 = game._player.position

	if mode == Mode.PRIZE:
		return game._gold_live if is_instance_valid(game._gold_live) else null

	# Pinned against the bottom: nothing down here is worth it. No target, so
	# _drive() walks her up -- the one push of the stick the alarm asks for.
	# Without this the bot sat on the edge for over a second at a time, a
	# whole death's worth of nerve, which measured the bot and not the game.
	if game._over_edge:
		return null

	# Being looked at beats everything: the nearest grass, cone or no cone.
	if game._watched:
		var shelter := _best_patch(game, me, true)
		if shelter != null:
			return shelter

	var standing: MeadowPatch = game.patch_at(me)

	if mode == Mode.HIDE:
		# Rides whatever it is in, sitting in the middle of it where cover
		# lasts longest, and only looks for another when that one is leaving.
		if standing != null and standing.position.y < _edge_of(game) - 24.0:
			return standing
		return _best_patch(game, me, false)

	# Foraging. Anything revealed and close is taken on the way past.
	var loose := _nearest_loose(game, me)
	if loose != null and me.distance_to(loose.global_position) < 64.0:
		return loose

	if standing != null:
		# In cover: take the dew that revealed itself, then move on before the
		# patch goes over the edge.
		for child in standing.get_children():
			var dew := child as MeadowPickup
			if dew != null and dew.revealed and _clear_of_edge(game, dew):
				return dew
	# Nothing left where she is standing, so move on at once. An earlier
	# version waited for the patch to start leaving before looking for the
	# next one, which is the HIDE bot wearing a forager's name -- and it
	# measured as one, coming out slower than actually hiding.
	var rich := _best_patch(game, me, false, true)
	var goal := rich if rich != null else _best_patch(game, me, false)
	# But it waits in cover while the route there is being swept. Walking
	# straight out under a cone was costing three to six spottings a run at
	# 0.22 nerve each -- three dew's worth -- which is a bot that cannot route
	# rather than a game where foraging does not pay. A person watches the
	# bird and goes when it looks away.
	if standing != null and goal != null \
			and _route_watched(game, me, goal.position) \
			and _life_left(standing, game.scroll_speed(), _edge_of(game)) > 1.2 \
			and me.y < _edge_of(game) - EDGE_ROOM:
		return standing
	return goal


## Walks at `target`, or -- with nothing to walk at -- holds station.
##
## The meadow carries her, so standing still is no longer free: it rides her to
## the bottom edge. A person with nowhere in particular to go keeps herself off
## it, and a bot that did not would be measuring the edge rather than the
## meadow. Only with NO target, though: a bot riding the patch it chose is
## doing what a hider does, and _choose() already moves it on before that
## patch reaches the bottom.
##
## Short of full stick, which is a habit from when full stick sprinted; there is
## no sprint now and it changes nothing.
func _drive(game: Node, target: Node2D) -> void:
	var direction := _toward(game, target)
	if not is_instance_valid(target):
		var me: Vector2 = game._player.position
		if me.y > field().position.y + field().size.y * STATION:
			direction = Vector2(0.0, -0.8)
	_steer(direction)


## Steering, recomputed every frame from where the target is NOW.
func _toward(game: Node, target: Node2D) -> Vector2:
	if not is_instance_valid(target):
		return Vector2.ZERO
	var offset: Vector2 = target.global_position - game._player.position
	return Vector2.ZERO if offset.length() < ARRIVE else offset.normalized()


## The patch the bot should head for: usable, and then nearest. `urgent` drops
## the "not watched" requirement, because when a cone is already on you the
## nearest grass beats the safest grass.
func _best_patch(game: Node, from: Vector2, urgent: bool,
		want_dew: bool = false) -> MeadowPatch:
	var speed: float = game.scroll_speed()
	var best: MeadowPatch = null
	var best_time := INF
	for patch in game._patches:
		if patch == game.patch_at(from):
			continue
		var t := _catch_time(from, patch.position, speed)
		if not is_finite(t):
			continue
		if t + reaction() > _life_left(patch, speed, _edge_of(game)):
			continue
		if not urgent and _watched_spot(game, patch.position):
			continue
		# Walking THROUGH a cone to reach safe grass is how the bot was
		# getting caught five times a run. A person looks at the route, not
		# only at the destination, so this costs the route rather than
		# excluding it -- there has to always be somewhere to go.
		var cost := t
		if not urgent and _route_watched(game, from, patch.position):
			cost += 6.0
		# A bird NEAR it is a cone about to turn that way. A person keeps clear
		# of birds, not only of where they are looking this frame -- and since
		# the meadow started carrying her, climbing to meet new cover takes her
		# up to where birds arrive. Without this the bot walked under the same
		# bird three times in ten seconds to reach grass at the top edge.
		if not urgent and _bird_near(game, patch.position, PatrolBird.VISION_RANGE):
			cost += 5.0
		if not urgent and _route_near_bird(game, from, patch.position):
			cost += 3.0
		# Not on the field yet. She cannot go up to meet it -- the field stops
		# her at its top edge -- so choosing it means standing at that edge in
		# the open until it arrives, which is where birds come in. Every early
		# death traced in the riding meadow started that way. A person waits
		# in the cover she has until the new grass is actually there.
		if not urgent and patch.position.y < field().position.y:
			cost += 4.0
		# A shimmering patch is worth going out of the way for, which is what
		# foraging IS. The bot reads the dew directly; the player reads the
		# shimmer that marks it -- same information, see MeadowPatch.mark_dew.
		# Somewhere she can STAY. A patch she reaches just before it reaches
		# the bottom is a patch that carries her onto the edge; the guarantee
		# counts it as usable, and it is, but a person does not walk DOWN to
		# one. As a cost rather than a rule the bot oscillated: walk down to a
		# low patch, get pinned, walk up, choose it again -- a run that died
		# at 7s on the edge with nothing looking at it.
		if not urgent and _life_left(patch, speed, _edge_of(game)) - t < SPARE_LIFE:
			continue
		if want_dew and not _holds_dew(patch):
			cost += 9.0
		if cost < best_time:
			best_time = cost
			best = patch
	return best


## Not down where taking it means standing on the edge. A person who has seen
## the alarm once leaves the last strip of the meadow alone.
func _clear_of_edge(game: Node, thing: Node2D) -> bool:
	return thing.global_position.y < _edge_of(game) - EDGE_ROOM


func _holds_dew(patch: MeadowPatch) -> bool:
	for child in patch.get_children():
		var dew := child as MeadowPickup
		if dew != null and dew.kind != MeadowPickup.Kind.PETAL:
			return true
	return false


## Does the straight line from `from` to `to` pass under an eye.
func _route_watched(game: Node, from: Vector2, to: Vector2) -> bool:
	for i in range(1, 7):
		if _watched_spot(game, from.lerp(to, float(i) / 7.0)):
			return true
	return false


func _bird_near(game: Node, point: Vector2, radius: float) -> bool:
	for bird in game._birds:
		if bird.global_position.distance_to(point) < radius:
			return true
	return false


## Does the straight line from `from` to `to` pass close under a bird, whichever
## way it is facing.
func _route_near_bird(game: Node, from: Vector2, to: Vector2) -> bool:
	for i in range(1, 7):
		if _bird_near(game, from.lerp(to, float(i) / 7.0), BIRD_BERTH):
			return true
	return false


func _nearest_loose(game: Node, from: Vector2) -> MeadowPickup:
	var best: MeadowPickup = null
	var best_d := INF
	for child in game._pickups_root.get_children():
		var petal := child as MeadowPickup
		if petal == null or not petal.revealed or not _clear_of_edge(game, petal):
			continue
		var d: float = petal.global_position.distance_to(from)
		if d < best_d:
			best_d = d
			best = petal
	return best


func _steer(direction: Vector2) -> void:
	const DEAD := 0.22
	if direction.x > DEAD:
		_hold(&"move_right"); _release(&"move_left")
	elif direction.x < -DEAD:
		_hold(&"move_left"); _release(&"move_right")
	else:
		_release(&"move_left"); _release(&"move_right")
	if direction.y > DEAD:
		_hold(&"move_down"); _release(&"move_up")
	elif direction.y < -DEAD:
		_hold(&"move_up"); _release(&"move_down")
	else:
		_release(&"move_up"); _release(&"move_down")
	# The button is left alone. It used to sprint; it tosses a pebble now, and
	# the bots do not throw them -- so the difficulty table is a player who
	# never uses it, which is the floor par should be set from.


# --- the guarantee, computed here --------------------------------------------
#
# Deliberately NOT game.patch_is_usable(). A test that asks the game whether
# the game is right cannot catch the game being wrong.

## Seconds for the player to get into a patch: the longer of walking there --
## distance over walking pace, since she and the patch ride the same meadow --
## and waiting for a patch still above the field to come down within reach,
## because the field's top edge stops her going up to meet it.
##
## This was an interception solve while she stood still and patches came at
## her. _test_she_rides_the_meadow() is what makes the walking half true -- if
## she stopped riding, this would silently be wrong again, and that check
## would be the one to fail. The waiting half is what the first version of the
## distance-only rule missed: a bot walked up to the top edge to wait for a
## patch that was not there yet, which is where the birds come in.
static func _catch_time(from: Vector2, target: Vector2, speed: float) -> float:
	var walking := from.distance_to(target) / walk()
	var half: Vector2 = _patch_const("PATCH_HALF")
	var entry := field().position.y - half.y
	if target.y >= entry:
		return walking
	if speed <= 0.0:
		return INF
	return maxf(walking, (entry - target.y) / speed)


## The bottom of the screen, worked out here from the camera's zoom rather than
## asked of the game's edge_y(). The camera pushes in as the meadow speeds up,
## so this rises from 270 to about 254 over a run.
static func _edge_of(game: Node) -> float:
	var half := float(ProjectSettings.get_setting(
			"display/window/size/viewport_height")) * 0.5
	return half + half / (game._camera as Camera2D).zoom.y


## Seconds before a patch reaches the bottom of the screen, where being in it
## stops counting -- being over the edge outranks being in grass.
static func _life_left(patch: MeadowPatch, speed: float, edge: float) -> float:
	if speed <= 0.0:
		return INF
	return maxf((edge - patch.position.y) / speed, 0.0)


func _watched_spot(game: Node, point: Vector2) -> bool:
	for bird in game._birds:
		var to_point: Vector2 = point - bird.global_position
		if to_point.length() > PatrolBird.VISION_RANGE:
			continue
		if absf(bird.facing.angle_to(to_point)) <= PatrolBird.VISION_HALF_ANGLE:
			return true
	return false


func _usable_count(game: Node, from: Vector2) -> int:
	var speed: float = game.scroll_speed()
	var count := 0
	for patch in game._patches:
		var t := _catch_time(from, patch.position, speed)
		if not is_finite(t) or t + reaction() > _life_left(patch, speed, _edge_of(game)):
			continue
		if _watched_spot(game, patch.position):
			continue
		count += 1
	return count


## How far cover is from an average place to be standing: the mean, over a grid
## of fixed probes, of the distance to the nearest usable patch. A property of
## the MEADOW rather than of whoever is walking around in it.
func _sparsity(game: Node) -> float:
	var f := field()
	var total := 0.0
	var found := 0
	for ix in 3:
		for iy in 2:
			var probe := Vector2(
				f.position.x + f.size.x * (0.2 + 0.3 * float(ix)),
				f.position.y + f.size.y * (0.3 + 0.4 * float(iy)))
			var d := _nearest_usable(game, probe, true)
			# A probe with no usable cover in sight counts as the worst case,
			# not as no reading. Returning INF and letting the caller skip the
			# sample threw away exactly the frames the late meadow is made of,
			# so the measurement only ever saw the moments cover happened to
			# be near -- and a meadow that does halve came out flat.
			total += NO_COVER if not is_finite(d) else minf(d, NO_COVER)
			found += 1
	return INF if found == 0 else total / float(found)


func _nearest_usable(game: Node, from: Vector2, on_field: bool = false) -> float:
	var speed: float = game.scroll_speed()
	var best := INF
	for patch in game._patches:
		# Patches are planted above the screen and count as usable the moment
		# they are -- she walks up and they come down. True for the guarantee,
		# useless for "how far is cover from here", where a patch 90px above
		# the top edge is not something anybody can see. Leaving them in made
		# the early meadow measure FURTHER from cover than the late one.
		if on_field and patch.position.y < field().position.y:
			continue
		var t := _catch_time(from, patch.position, speed)
		if not is_finite(t) or t + reaction() > _life_left(patch, speed, _edge_of(game)):
			continue
		if _watched_spot(game, patch.position):
			continue
		best = minf(best, from.distance_to(patch.position))
	return best


static func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


# --- plumbing ----------------------------------------------------------------

func _start() -> Node:
	var game := (load(SCENE) as PackedScene).instantiate()
	add_child(game)
	await _frames(2)
	game.begin()
	await _frames(1)
	return game


## Plays for `seconds` of GAME time. Headless at --fixed-fps 60 runs
## unthrottled, so a wall-clock assertion would measure nothing.
func _play(game: Node, seconds: float) -> void:
	var played := 0.0
	while played < seconds and is_instance_valid(game):
		await _frames(1)
		played += get_process_delta_time()


func _drop(game: Node) -> void:
	_release_all()
	if is_instance_valid(game):
		game.queue_free()
