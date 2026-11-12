extends SoakBase
## Acorn Storm soak. Run it with:
##
##     godot --headless --fixed-fps 60 --path . tests/acorn_test.tscn
##
## The harness it stands on -- check counting, input synthesis, frame pumping,
## reporting -- lives in soak_base.gd and is shared with every other game.
##
## **The reaction floor is the assertion this file exists for.** In the fixed
## round this game replaced, a fruit that fell out of reach cost some points;
## with a bar that never stops draining it costs a life, so "could the player
## have got there" is now a survival property rather than a nicety. Everything
## else here is secondary to it.
##
## Three more properties it holds: the launch is quiet, the first sunfruit
## lands before the first acorn, and there is always somewhere to stand.

const SCENE := "res://src/minigames/acorn_storm/acorn_storm.tscn"
const GAME := "res://src/minigames/acorn_storm/acorn_storm.gd"

## How long the gale takes to get up, read off the game.
static func launch_over() -> float:
	return _const("LAUNCH_SECONDS")

static func field() -> Rect2:
	return _const("FIELD")

## Constants are READ from the game rather than copied. A test carrying its
## own copy of a number goes on passing after the game's changes -- while
## measuring something the game no longer does, which is worse than failing
## because nothing tells you.
static func _const(name: String) -> Variant:
	return (load(GAME) as GDScript).get_script_constant_map()[name]

## A beginner should get at least this long out of their credit, bar and all.
const OPENING_FLOOR := 40.0
## Nothing may run longer than this in the suite. A bot still holding the bar
## up here has proved everything any check asks of it, and letting the good
## ones run to their real end would put minutes on every run of the suite.
const MAX_SECONDS := 200.0
## Reaction times the bots are measured at, in milliseconds: a quick player,
## an average one, and somebody who has never seen the cabinet before.
const REACTIONS := [133, 216, 300]
## Runs per reaction time. One of anything in a game this random is an anecdote.
const TRIALS := 5

## What the last bot run did, so a survival number that looks wrong can be
## explained rather than guessed at.
var _last_run: String = ""
## The sunfruit the bot is currently going for. A player picks one and goes;
## a bot that re-chooses every frame is not modelling anything.
var _target: int = 0


## Each step is announced before it runs and timed after it. This suite drives
## several whole runs, and when one of them does not come back the only
## question worth asking is which -- without the trace, a hang and a slow
## machine look exactly the same from outside.
var _step_started: int = 0


func _step(name: String) -> void:
	var now := Time.get_ticks_msec()
	if _step_started > 0:
		print("  .. %.1fs" % (float(now - _step_started) / 1000.0))
	_step_started = now
	if not name.is_empty():
		print("  .. %s" % name)


func _ready() -> void:
	_step("contract");                        await _test_contract()
	_step("the curve");                       await _test_the_curve()
	_step("draw order");                      await _test_draw_order()
	_step("the launch is quiet");             await _test_the_launch_is_quiet()
	_step("gold before red");                 await _test_gold_before_red()
	_step("fruit is reachable");              await _test_fruit_is_always_reachable()
	_step("never cornered");                  await _test_there_is_always_somewhere_to_stand()
	_step("marks do not stack");              await _test_marks_do_not_stack()
	_step("the drain");                       await _test_the_bar_drains_gently_then_not()
	_step("fruit outpaces the drain");        await _test_fruit_can_outpace_the_drain()
	_step("a run must end");                  await _test_a_run_must_end()
	_step("ignoring fruit is fatal");         await _test_ignoring_fruit_is_fatal()
	_step("the opening is survivable");       await _test_the_opening_is_survivable()
	_step("the opening card");                await _test_the_opening_card()
	_step("")

	get_tree().quit(report("ACORN STORM"))


# --- the contract ------------------------------------------------------------

func _test_contract() -> void:
	_check(Audio != null, "Audio autoload missing")

	var game: Node = await _start()
	_check(game.id == &"acorn_storm", "the game reports id %s" % game.id)

	var results: Array = []
	game.finished.connect(func(r: MiniGameResult) -> void: results.append(r))
	# Empty the bar outright: the run must end, once, and report once.
	game._vitality = 0.0
	await _play(game, 2.2)
	_check(results.size() == 1,
			"a run that lost its bar reported %d times, expected exactly one"
			% results.size())
	if results.size() == 1:
		var result: MiniGameResult = results[0]
		_check(result.score >= 0, "a result carried a negative score")
		_check(result.normalised >= 0 and result.normalised <= 1000,
				"normalised score %d is outside 0-1000" % result.normalised)
		_check(result.stats.has("survived") and result.stats.has("fruit"),
				"the result is missing the stats the run card reads")
	# A second collapse must change nothing.
	game._collapse()
	await _frames(4)
	_check(results.size() == 1,
			"collapsing twice reported %d times" % results.size())
	_drop(game)


## Endless games normalise on how long you lasted, not on points, because two
## of them compared on points would be comparing their scoring rates.
func _test_the_curve() -> void:
	var script := load(GAME) as GDScript
	var gentle_seconds: float = _const("GENTLE_SECONDS")
	var gentle_ceiling: float = _const("GENTLE_CEILING")

	var previous := -1.0
	for second in range(0, 300, 5):
		var value: float = script.intensity_at(float(second))
		_check(value >= previous,
				"the curve went backwards at %ds (%.3f after %.3f)"
				% [second, value, previous])
		_check(value < 1.0, "the curve reached %.3f at %ds -- it must approach "
				% [value, second] + "1 without arriving, or there is nothing "
				+ "left to get harder")
		previous = value

	# Shape, not magic numbers: the gentle stretch ends at its own ceiling.
	_check(is_equal_approx(script.intensity_at(gentle_seconds), gentle_ceiling),
			"the curve reads %.3f at the end of its gentle stretch, not the "
			% script.intensity_at(gentle_seconds) + "%.3f ceiling it declares"
			% gentle_ceiling)
	_check(script.intensity_at(gentle_seconds * 0.5) < gentle_ceiling * 0.6,
			"the opening half of the gentle stretch is already past half its "
			+ "ceiling -- it is not gentle")

	# And it is normalised on duration, not points.
	var par: float = _const("PAR_SECONDS")
	var at_par := MiniGame.normalised_from_duration(par, par)
	var at_double := MiniGame.normalised_from_duration(par * 2.0, par)
	_check(absi(at_par - 500) <= 2,
			"a par run normalised to %d, expected about 500" % at_par)
	_check(at_double > at_par and at_double < 1000,
			"twice par normalised to %d -- it must be better than par and "
			% at_double + "still short of the top")


## The rule the game is read by: the mark is painted on the ground and goes
## under everything, the body is in the air and goes over everything.
##
## Resolved up the parent chain rather than read off the nodes, because
## z_index is RELATIVE -- which is how Riverleap once drew a hazard over an
## airborne player while every constant in the file said otherwise.
func _test_draw_order() -> void:
	var game: Node = await _start()
	await _play(game, launch_over() + 3.5)
	var seen := 0
	for child in game._fallers.get_children():
		var faller := child as Faller
		if faller == null or faller.get_child_count() < 2:
			continue
		seen += 1
		var mark := effective_z(faller.get_child(0) as CanvasItem)
		var body := effective_z(faller.get_child(1) as CanvasItem)
		var player := effective_z(game._player)
		_check(mark < player,
				"a ground mark resolved to z %d against the player's %d -- it "
				% [mark, player] + "is painted on the clearing and must go "
				+ "under them")
		_check(body > player,
				"a falling body resolved to z %d against the player's %d -- it "
				% [body, player] + "is in the air and must go over them")
	_check(seen > 0, "nothing was falling 3.5s in, so draw order went unchecked")
	_drop(game)


## Nothing is thrown at a player who has not been shown the field yet. The
## canopy thrashes, the camera pushes in, and only then does the storm start.
func _test_the_launch_is_quiet() -> void:
	var game: Node = await _start()
	var fallers := 0
	var ticks := 0
	while game.elapsed < launch_over() - 0.05:
		await _frames(1)
		ticks += 1
		fallers = maxi(fallers, game._fallers.get_child_count())
	_check(ticks > 30, "the launch window was over in %d frames -- nothing "
			% ticks + "was measured")
	_check(fallers == 0,
			"%d things were already falling during the %.1fs run-up"
			% [fallers, launch_over()])
	_check(game.launch_factor() < 1.0,
			"the gale was already at full strength before the launch ended")
	await _play(game, 3.0)
	_check(game.launch_factor() >= 0.999,
			"the gale never reached full strength after the launch")
	print("  launch      quiet for the whole %.1fs run-up" % launch_over())
	_drop(game)


## "Gold is good" has to be learned before "red hurts", or the first lesson
## this game teaches costs a life.
func _test_gold_before_red() -> void:
	for run in 3:
		var game: Node = await _start()
		await _play(game, launch_over() + 8.0)
		_check(game._first_fruit_at >= 0.0,
				"no sunfruit had landed 8s into play")
		_check(game._first_acorn_at < 0.0
				or game._first_fruit_at < game._first_acorn_at,
				"the first acorn landed at %.2fs and the first sunfruit at "
				% game._first_acorn_at + "%.2fs -- the player meets the thing "
				% game._first_fruit_at + "that hurts before the thing that helps")
		_drop(game)


## THE assertion. Every sunfruit must land somewhere the player could actually
## have got to, measured from where they were standing when it spawned, at
## WALKING pace, minus a slow human's reaction time.
##
## Sampled across the whole curve, because the reachable radius shrinks with
## the fall time and the failure would only appear late.
func _test_fruit_is_always_reachable() -> void:
	var worst := 0.0
	var checked := 0
	var failures := 0
	for intensity in [0.0, 60.0, 140.0, 240.0]:
		var game: Node = await _start()
		# Jump the clock rather than play four minutes: the director reads the
		# curve, so this is the same director it would be at that moment.
		game.elapsed = launch_over() + intensity
		var seen: Dictionary = {}
		var played := 0.0
		while played < 20.0:
			await _frames(1)
			# Held up by hand. These are measurements of the DIRECTOR, and at
			# the far end of the curve an untouched bar empties in about nine
			# seconds -- the game would stop spawning halfway through and the
			# sample would quietly be of nothing.
			game._vitality = 1.0
			played += get_process_delta_time()
			var standing: Vector2 = game._player.position
			for child in game._fallers.get_children():
				var faller := child as Faller
				if faller == null or seen.has(faller.get_instance_id()):
					continue
				seen[faller.get_instance_id()] = true
				if faller.kind != Faller.Kind.SUNFRUIT:
					continue
				checked += 1
				var distance := standing.distance_to(faller.position)
				var could_reach: float = game.reach(faller.fall_seconds)
				worst = maxf(worst, distance / maxf(could_reach, 0.001))
				if distance > could_reach:
					failures += 1
					if failures <= 2:
						_check(false,
								"a sunfruit landed %.0fpx away with %.2fs of "
								% [distance, faller.fall_seconds]
								+ "fall -- a walking player covers %.0fpx in "
								% could_reach + "that, so it was never "
								+ "catchable, and with the bar draining an "
								+ "uncatchable fruit costs a life")
		_drop(game)
	_check(checked > 50,
			"only %d sunfruit were measured -- not enough to claim anything"
			% checked)
	_check(failures == 0,
			"%d of %d sunfruit landed out of walking reach" % [failures, checked])
	print("  reach       %d sunfruit, worst used %.0f%% of the walk" \
			% [checked, worst * 100.0])


## Being cornered is this game's version of Riverleap's whole row going under:
## not difficulty, an unwinnable frame. The director rejects a placement that
## leaves nowhere to go, and this is the check that it actually does.
##
## Instantaneous, not predictive. It asks whether somewhere reachable is clear
## RIGHT NOW, which is the only promise a director can keep.
func _test_there_is_always_somewhere_to_stand() -> void:
	var cornered := 0
	var throws := 0
	var skipped := 0
	var tightest := 999.0
	# Five points on the curve and a long window at each: early on the
	# director holds itself to ONE acorn in the air at a time, so three short
	# samples produced twenty throws in total -- not enough to claim a
	# guarantee about every one of them.
	for offset: float in [0.0, 60.0, 120.0, 200.0, 280.0]:
		var game: Node = await _start()
		game.elapsed = launch_over() + offset
		var seen: Dictionary = {}
		var lag := 0.216
		var decisions: Array = []
		var clock := 0.0
		var aim := Vector2.ZERO
		var played := 0.0
		while played < 18.0:
			await _frames(1)
			game._vitality = 1.0          # see _test_fruit_is_always_reachable
			var delta := get_process_delta_time()
			played += delta
			clock += delta
			decisions.append([clock + lag, _decide(game, true)])
			while not decisions.is_empty() and float(decisions[0][0]) <= clock:
				aim = decisions.pop_front()[1]
			_steer(aim)

			# The question is asked when an acorn is THROWN, because that is
			# the moment the director decides. Asked again every frame of its
			# flight it answers "no" as a matter of arithmetic -- 0.2s before
			# it lands there is nowhere anyone could get to, which is what a
			# hazard IS rather than a failure to leave one a way out.
			for child in game._fallers.get_children():
				var acorn := child as Faller
				if acorn == null or seen.has(acorn.get_instance_id()):
					continue
				seen[acorn.get_instance_id()] = true
				if acorn.kind != Faller.Kind.ACORN:
					continue
				throws += 1
				var room := _escape_room(game, acorn)
				tightest = minf(tightest, room)
				if room < 0.0:
					cornered += 1
					if cornered <= 2:
						_check(false,
								"an acorn was thrown with %.2fs of fall and "
								% acorn.fall_seconds + "left the player "
								+ "nowhere reachable to stand")
		skipped += game._skipped_acorns
		_release_all()
		_drop(game)
	_check(throws > 60, "only %d acorns were thrown" % throws)
	_check(cornered == 0,
			"%d of %d acorns were thrown into a field with no escape"
			% [cornered, throws])
	# Rejections are the mechanism, so a flood of them means the field is too
	# crowded for the rule rather than the rule working.
	_check(skipped < 40,
			"the director gave up on %d acorn placements -- the field is so "
			% skipped + "crowded that the escape rule is throttling the game "
			+ "rather than protecting the player")
	print("  escape      %d acorns, all left a way out (tightest %.0fpx spare)"
			% [throws, tightest])


## How much room to spare the player had when `acorn` was thrown, in pixels.
## Negative means there was nowhere at all.
##
## Computed HERE, from the field, rather than by calling the game's own
## escape_exists(). A test that asks the game whether the game is right cannot
## catch the game being wrong -- Riverleap's suite records the same reasoning
## for the same check.
func _escape_room(game: Node, acorn: Faller) -> float:
	var speed: float = game._player.speed
	var reaction: float = _const("REACTION_FLOOR")
	var margin: float = _const("ESCAPE_MARGIN")
	var window: float = _const("ESCAPE_WINDOW")
	var bounds: Rect2 = field()
	var standing: Vector2 = game._player.position
	var radius: float = speed * maxf(acorn.fall_seconds - reaction, 0.0)

	var blockers: Array[Vector2] = []
	for child in game._fallers.get_children():
		var other := child as Faller
		if other == null or other.resolved or other.kind != Faller.Kind.ACORN:
			continue
		if other.seconds_left() <= acorn.fall_seconds + window:
			blockers.append(other.position)

	# Standing still counts, and so does anywhere on a ring the player could
	# walk to. Sixteen directions rather than the game's twelve, deliberately:
	# a finer sweep than the one being checked.
	var best := -1.0
	for ring: float in [0.0, 1.0, 0.8, 0.6, 0.4]:
		for step in 16:
			var spot := standing \
					+ Vector2.RIGHT.rotated(float(step) * TAU / 16.0) * radius * ring
			if not bounds.has_point(spot):
				continue
			var room := 9999.0
			for blocker in blockers:
				room = minf(room, spot.distance_to(blocker)
						- Faller.HIT_RADIUS - margin)
			best = maxf(best, room)
			if ring <= 0.0:
				break
	return best


## Two marks of different kinds on the same patch of grass say "danger" and
## "take it" about the same square, and a player cannot act on that. The
## director passes over such a placement when it has any other.
##
## Not asserted to zero: an acorn aims at the PLAYER, and a player standing on
## a fruit has to be a target like anywhere else, so the rule is a preference
## and the test measures how often it fails to find an alternative.
func _test_marks_do_not_stack() -> void:
	var stacked := 0
	var samples := 0
	var separation: float = _const("MARK_SEPARATION")
	for offset: float in [20.0, 120.0, 240.0]:
		var game: Node = await _start()
		game.elapsed = launch_over() + offset
		var played := 0.0
		while played < 12.0:
			await _frames(1)
			game._vitality = 1.0
			played += get_process_delta_time()
			samples += 1
			for child in game._fallers.get_children():
				var acorn := child as Faller
				if acorn == null or acorn.resolved \
						or acorn.kind != Faller.Kind.ACORN:
					continue
				for other in game._fallers.get_children():
					var fruit := other as Faller
					if fruit == null or fruit.resolved \
							or fruit.kind != Faller.Kind.SUNFRUIT:
						continue
					if absf(fruit.seconds_left() - acorn.seconds_left()) > 0.55:
						continue
					if acorn.position.distance_to(fruit.position) < separation:
						stacked += 1
						break
				break
		_drop(game)
	var rate := float(stacked) / float(maxi(samples, 1))
	_check(samples > 1500, "only %d frames were sampled" % samples)
	_check(rate < 0.04,
			"the two marks were stacked on %.1f%% of frames -- often enough "
			% (rate * 100.0) + "that a player regularly cannot tell whether a "
			+ "patch of grass is worth standing on")
	print("  marks       stacked on %.1f%% of frames" % (rate * 100.0))


## Very low at first, much steeper later -- the shape Neo asked for, asserted
## as a shape rather than as two numbers.
func _test_the_bar_drains_gently_then_not() -> void:
	var game: Node = await _start()
	var previous := -1.0
	for seconds in [0.0, 30.0, 60.0, 120.0, 240.0]:
		game._intensity = game.intensity_at(seconds)
		var rate: float = game.drain_rate()
		_check(rate > previous,
				"the drain did not rise between %.0fs and the point before it"
				% seconds)
		previous = rate

	game._intensity = 0.0
	var opening: float = 1.0 / float(game.drain_rate())
	game._intensity = 1.0
	var endgame: float = 1.0 / float(game.drain_rate())
	_check(opening > 60.0,
			"a full bar empties in %.0fs with nothing done at all -- the "
			% opening + "opening is supposed to be nearly free")
	_check(endgame < 20.0,
			"a full bar still lasts %.0fs at full pressure -- the late game "
			% endgame + "has no teeth")
	print("  drain       full bar lasts %.0fs early, %.0fs late"
			% [opening, endgame])
	_drop(game)


## The other half of the same question: the bar can be held up, at every point
## on the curve, by a player who catches what is offered. If fruit stops
## arriving fast enough to beat the drain, the run ends on arithmetic rather
## than on anything the player did.
func _test_fruit_can_outpace_the_drain() -> void:
	for offset in [0.0, 60.0, 150.0, 240.0]:
		var game: Node = await _start()
		game.elapsed = launch_over() + offset
		var seen: Dictionary = {}
		var fruit := 0
		var played := 0.0
		while played < 14.0:
			await _frames(1)
			game._vitality = 1.0          # see _test_fruit_is_always_reachable
			played += get_process_delta_time()
			for child in game._fallers.get_children():
				var faller := child as Faller
				if faller == null or seen.has(faller.get_instance_id()):
					continue
				seen[faller.get_instance_id()] = true
				if faller.kind == Faller.Kind.SUNFRUIT:
					fruit += 1
		var offered: float = float(fruit) / played * game.FRUIT_GAIN
		var lost: float = game.drain_rate()
		_check(offered > lost * 1.15,
				"at %.0fs in, the fruit on offer is worth %.3f bar a second "
				% [offset, offered] + "against a %.3f drain -- a player who "
				% lost + "caught every single one would still lose")
		_drop(game)
	print("  supply      fruit outpaces the drain across the curve")


## A run ends, and a bot that does nothing at all does not end it instantly.
func _test_a_run_must_end() -> void:
	var game: Node = await _start()
	var results: Array = []
	game.finished.connect(func(r: MiniGameResult) -> void: results.append(r))
	var played := 0.0
	while results.is_empty() and played < MAX_SECONDS:
		await _frames(1)
		played += get_process_delta_time()
	_check(not results.is_empty(),
			"a motionless player survived %.0fs -- the drain cannot end a run"
			% played)
	if not results.is_empty():
		var result: MiniGameResult = results[0]
		print("  ending      idle run died after %5.1fs  score %5d  %s"
				% [result.duration, result.score, result.stats])
	_drop(game)


## The point of the drain. A bot that dodges perfectly and never takes a fruit
## must die; a bot that chases fruit must last meaningfully longer. If the
## first survives, the catching half of the game is decoration again -- which
## is the exact failure the fixed round had.
func _test_ignoring_fruit_is_fatal() -> void:
	var dodger: float = await _bot(216, false, 150.0)
	_check(dodger < 140.0,
			"a bot that never touched a sunfruit held on for %.0fs -- the bar "
			% dodger + "is not forcing anyone to catch anything")
	var chaser: float = await _bot(216, true, MAX_SECONDS)
	_check(chaser > dodger * 1.2,
			"chasing fruit bought %.0fs against %.0fs for ignoring it -- "
			% [chaser, dodger] + "catching is not paying for itself")
	print("  fruit       ignoring it: %.0fs      chasing it: %.0fs  (%s)"
			% [dodger, chaser, _last_run])


## The opening has to be survivable by somebody still working out which way is
## which. Measured at three reaction times, the slowest of which is a stranger.
func _test_the_opening_is_survivable() -> void:
	var line := ""
	for reaction: int in REACTIONS:
		# Three runs, not one. The first measurement had a 300ms bot outlasting
		# a 133ms one, which is not a finding about the game -- it is what one
		# sample of a run full of random placements looks like.
		var total := 0.0
		var worst := 9999.0
		for trial in TRIALS:
			var held: float = await _bot(reaction, true, MAX_SECONDS)
			total += held
			worst = minf(worst, held)
		var mean := total / float(TRIALS)
		line += "%dms %.0fs (worst %.0fs)   " % [reaction, mean, worst]
		if reaction == REACTIONS[-1]:
			_check(mean >= OPENING_FLOOR,
					"a %dms player held on %.0fs on average, under the %.0fs a "
					% [reaction, mean, OPENING_FLOOR] + "stranger should get "
					+ "for their credit")
			_check(worst >= OPENING_FLOOR * 0.6,
					"a %dms player's worst run was %.0fs -- the floor is a "
					% [reaction, worst] + "promise about a credit, not about "
					+ "an average")
	print("  difficulty  " + line.strip_edges())


## The opening card: the lesson, then 3-2-1-GO.
##
## The first check is the load-bearing one. The suite instances the game as a
## CHILD and calls begin() itself, so it must never meet the card -- if that
## guard breaks, every test in this file waits out a countdown it cannot see.
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

	# Timed in GAME seconds. Headless at --fixed-fps 60 runs unthrottled, so a
	# wall-clock assertion here would measure nothing and pass by accident.
	StartCard.tutorial_seen = true
	var replay_s: float = await _time_card()
	_check(replay_s >= StartCard.BEAT * 3.0,
			"the countdown ran %.2fs, under the %.2fs its own beats need"
			% [replay_s, StartCard.BEAT * 3.0])

	StartCard.tutorial_seen = false
	var first_s: float = await _time_card()
	var lesson_s := float(AcornCard.new().slide_count()) * StartCard.SLIDE_SECONDS
	_check(first_s > replay_s + lesson_s * 0.6,
			"a first-timer waited %.2fs against a repeat player's %.2fs -- "
			% [first_s, replay_s] + "the slides are barely being shown")
	print("  start card  first run %.1fs, replay %.1fs" % [first_s, replay_s])
	StartCard.tutorial_seen = false
	await _frames(2)


## Counts in an Array because GDScript lambdas capture locals by VALUE -- an
## int incremented inside the callback stays zero outside it, which looks
## exactly like a signal that never fired.
func _time_card() -> float:
	var card := AcornCard.new()
	add_child(card)
	var done: Array = []
	card.finished.connect(func() -> void: done.append(true))
	card.play()
	var seconds := 0.0
	while done.is_empty() and seconds < 30.0:
		await _frames(1)
		seconds += get_process_delta_time()
	_check(done.size() == 1,
			"the card reported %d times, expected exactly one" % done.size())
	return seconds


# --- the bot -----------------------------------------------------------------

## Plays a whole run and returns how long it held on.
##
## The lag is the point. A bot that reacts on the same frame as the spawn
## measures the game a machine plays, not the one a person does, and this
## game's whole difficulty is how far you can get before something lands.
func _bot(reaction_ms: int, chase: bool, limit: float) -> float:
	var game: Node = await _start()
	var lag := float(reaction_ms) / 1000.0
	var decisions: Array = []           # [due_time, direction]
	_target = 0
	var clock := 0.0
	var aim := Vector2.ZERO
	# An Array, not a bool. GDScript lambdas capture locals by VALUE, so
	# `ended = true` inside the callback leaves the outer one false -- which
	# does not fail, it just runs every bot for the full limit and turns a
	# ninety-second suite into a ten-minute one.
	var ended: Array = []
	game.finished.connect(func(_r: MiniGameResult) -> void: ended.append(true))

	while ended.is_empty() and clock < limit:
		await _frames(1)
		var delta := get_process_delta_time()
		clock += delta
		decisions.append([clock + lag, _decide(game, chase)])
		while not decisions.is_empty() and float(decisions[0][0]) <= clock:
			aim = decisions.pop_front()[1]
		_steer(aim)
	_release_all()
	var held: float = game._survived
	_last_run = "%d fruit, %d hits, %d missed" % [game._fruit, game._hits,
			game._missed]
	_drop(game)
	return held


## Away from anything about to land on us, and toward the sunfruit it can most
## comfortably make. The two are BLENDED rather than ranked: pure flight means
## the bot never eats while anything is in the air, which late on is always,
## and a bot that cannot eat cannot tell us whether eating pays.
func _decide(game: Node, chase: bool) -> Vector2:
	var standing: Vector2 = game._player.position
	var threat := Vector2.ZERO
	var fruit_at := Vector2.ZERO
	var best_margin := -999.0
	var next_target := 0

	for child in game._fallers.get_children():
		var faller := child as Faller
		if faller == null or faller.resolved:
			continue
		var offset := standing - faller.position
		var distance := offset.length()
		if faller.kind == Faller.Kind.ACORN:
			# Earlier and wider than the hit itself: by the time it is 14px
			# away there is no time left to be anywhere else.
			if faller.seconds_left() < 1.0 and distance < Faller.HIT_RADIUS + 24.0:
				# Weighted by closeness, so two acorns resolve to the gap
				# between them rather than to whichever was seen first.
				threat += offset.normalized() * (1.0 + 30.0 / maxf(distance, 6.0))
		elif chase:
			# How much room to spare, not how soon -- the soonest fruit is
			# often the one there is no chance of reaching.
			var margin: float = game.reach(faller.seconds_left()) * 1.5 - distance
			# A fruit already being chased keeps a head start, so the bot
			# does not change its mind every frame. Without this it dithered
			# between two targets and reached neither -- and the dithering got
			# WORSE the faster it reacted, which is why the measurement came
			# out saying a 133ms player does worse than a 216ms one.
			if faller.get_instance_id() == _target:
				margin += 40.0
			if margin > best_margin:
				best_margin = margin
				fruit_at = faller.position
				next_target = faller.get_instance_id()

	_target = next_target if best_margin > 0.0 else 0
	var want := Vector2.ZERO
	if best_margin > 0.0:
		want = (fruit_at - standing).normalized()
	elif threat == Vector2.ZERO:
		# Nothing to do: drift back toward the middle, where more of the field
		# is within reach of whatever comes next.
		var middle: Rect2 = field()
		want = (middle.get_center() - standing) * 0.02
	if threat != Vector2.ZERO:
		want = (threat.normalized() * 1.6 + want).normalized()
	return want


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
	# Sprint only when it is worth spending; the controller handles the rest.
	if direction.length() > 0.6:
		_hold(&"act")
	else:
		_release(&"act")


# --- plumbing ----------------------------------------------------------------

func _start() -> Node:
	var game := (load(SCENE) as PackedScene).instantiate()
	add_child(game)
	await _frames(2)
	game.begin()
	await _frames(1)
	return game


## Plays for `seconds` of GAME time.
func _play(game: Node, seconds: float) -> void:
	var played := 0.0
	while played < seconds and is_instance_valid(game):
		await _frames(1)
		played += get_process_delta_time()


func _drop(game: Node) -> void:
	_release_all()
	if is_instance_valid(game):
		game.queue_free()
