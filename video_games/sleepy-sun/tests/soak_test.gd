extends Node
## Riverleap soak. Run it with:
##
##     godot --headless --fixed-fps 60 --path . tests/soak_test.tscn
##
## The one suite, now that the project is one game.
##
## It used to prove that the game could be *finished*. Riverleap is endless
## now, so that property no longer exists and three others took its place:
## **the opening is survivable**, **a run does end**, and **everything thrown
## at the player can be reacted to**. The last of those is the one that matters
## most: a hazard that cannot be dodged is the single worst thing this redesign
## could ship, and it is invisible in a screenshot.
##
## It also carries the regressions this game has already had, because a bug
## that got through once will get through again.

const SCENE := "res://src/minigames/wind_leaf/wind_leaf.tscn"
const HAZARD := "res://src/minigames/wind_leaf/hazard.tscn"

## A passive bot loses a half-life roughly every time its own pad goes, so the
## run has to be given real room to end.
const MAX_SECONDS := 240.0
## "Gentle first minute", turned into a number. A beginner should get about
## this long out of their credit even while still working the controls out.
const OPENING_FLOOR := 45.0
## The fastest a hornet ever flies: the top of HORNET_SPEED. It is an airspeed,
## not the river's, which is exactly why it stays reactable at any current.
const FASTEST_HORNET := 360.0
## The least warning it may give at that speed before it is on you.
const HORNET_LEAD_FLOOR := 0.40
## And the least its FIRST ones may give, which is a different promise: the
## floor above asks whether a known threat can be dodged, this asks whether an
## unknown one can be learned. The clock a player actually runs on does not
## start when the hazard appears, it starts when they work out what it is.
const HORNET_DEBUT_FLOOR := 0.90
## How long the river takes to get up to speed.
const LAUNCH_OVER := 3.0

## The player's row, read off the game rather than copied. A test carrying its
## own 174 kept passing after the row moved to 206, while quietly measuring a
## row the game no longer used -- passing for the wrong reason is worse than
## failing, because nothing tells you.
static func row_y() -> float:
	return (load("res://src/minigames/wind_leaf/wind_leaf.gd") as GDScript) \
			.get_script_constant_map()["ROW_Y"]

var _failures: PackedStringArray = []
var _checks: int = 0
var _held: Array[StringName] = []


func _ready() -> void:
	await _test_contract()
	await _test_scrollers_agree()
	await _test_parallax_order()
	await _test_pads_ride_one_swell()
	await _test_the_curve()
	await _test_the_river_launches()
	await _test_the_launch_is_quiet()
	await _test_the_opening_card()
	await _test_a_new_player_is_taught_again()
	await _test_pads_come_back_faster()
	await _test_hazards_are_dodgeable()
	await _test_jumping_puts_you_over_a_hornet()
	await _test_the_first_hornet_is_readable()
	await _test_a_hit_knocks_you_into_the_water()
	await _test_the_opening_is_survivable()
	await _test_a_run_must_end()
	await _test_drowning_is_not_escapable()

	print("\n================= SOAK TEST =================")
	if _failures.is_empty():
		print("PASS  -  %d checks" % _checks)
	else:
		print("FAIL  -  %d of %d checks" % [_failures.size(), _checks])
		for failure in _failures:
			print("  x  " + failure)
	print("============================================")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


# --- the contract ------------------------------------------------------------

## The scene loads, it reports once, and it cannot be made to report twice.
func _test_contract() -> void:
	_check(Audio != null, "Audio autoload missing")
	_check(Save != null, "Save autoload missing")

	var result := MiniGameResult.new(&"x", -500, 1.0, {})
	_check(result.score == 0, "MiniGameResult should clamp a negative score to 0")

	var packed: PackedScene = load(SCENE)
	_check(packed != null, "could not load %s" % SCENE)
	if packed == null:
		return

	var game := packed.instantiate() as MiniGame
	_check(game != null, "the Riverleap scene root is not a MiniGame")
	if game == null:
		return
	_check(game.id == &"wind_leaf", "Riverleap reports id %s" % game.id)

	var received: Array = []
	game.finished.connect(func(r: MiniGameResult) -> void: received.append(r))
	add_child(game)
	await _frames(3)
	game.begin()
	await _frames(2)
	_check(game.running, "begin() should start the game running")

	game.finish(123, {"forced": true})
	await _frames(2)
	_check(received.size() == 1, "finish() should emit exactly one result")

	# A race between "the river took you" and anything else must not be able to
	# report a score twice.
	game.finish(999, {})
	await _frames(1)
	_check(received.size() == 1, "a second finish() should be ignored")

	game.free()
	await _frames(2)


## The two scrollers have to mean the same thing by a positive number.
##
## They did not, for a whole round. ScrollingTexture advances a region offset,
## which slides content UP; ScrollingProps adds to position.y, which moves
## children DOWN. Set to the same +46 the grass crawled backwards past the
## trees standing on it. Nothing caught it: the soak passed, the screenshots
## looked fine, and it took a player to say the grass looked wrong.
func _test_scrollers_agree() -> void:
	var texture := ScrollingTexture.new()
	texture.texture = load("res://assets/game/village/ground_0.png")
	texture.area = Vector2i(64, 64)
	texture.scroll = Vector2(0, 60)
	add_child(texture)

	var props := ScrollingProps.new()
	props.scroll = Vector2(0, 60)
	props.span = Vector2(-500, 500)          # far enough not to wrap in the window
	var marker := Sprite2D.new()
	marker.position = Vector2.ZERO
	props.add_child(marker)
	add_child(props)

	await _frames(2)
	var region_before: float = texture.region_rect.position.y
	var prop_before: float = marker.position.y
	await _frames(20)

	# Content moves down when the region offset DEcreases, and when a child's
	# position.y INcreases. Both must read "down" for the same positive scroll.
	var texture_down := region_before - texture.region_rect.position.y
	var props_down := marker.position.y - prop_before

	_check(texture_down > 0.0,
			"a positive scroll should move ScrollingTexture content down, got %.1f"
			% texture_down)
	_check(props_down > 0.0,
			"a positive scroll should move ScrollingProps children down, got %.1f"
			% props_down)
	_check(absf(texture_down - props_down) < 2.0,
			"the two scrollers disagree: texture moved %.1f, props moved %.1f"
			% [texture_down, props_down])
	if texture_down > 0.0 and props_down > 0.0:
		print("  scrollers    agree: +scroll moves content down in both")
	texture.free()
	props.free()
	await _frames(2)


## Every layer must ride the current in the SAME direction, ordered by
## distance. Measuring this from screenshots is hopeless -- the tiles repeat
## every 32 or 64px, so a correlation cannot tell a shift from its alias --
## but the speeds the game sets are exact, so assert those.
func _test_parallax_order() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(3)
	game.begin()
	# Past the launch before reading any speed: during the run-up every layer
	# is scaled toward zero, so the stack is ordered but the numbers are
	# meaningless and the absolute comparison below would be measuring nothing.
	game.set("elapsed", LAUNCH_OVER + 1.0)
	await _frames(4)

	var order := ["World/TreelineLeft", "World/WaterDepth", "World/Water",
			"World/BankLeft"]
	var speeds: Array[float] = []
	for path in order:
		var node := game.get_node_or_null(NodePath(path))
		_check(node != null, "parallax layer %s is missing" % path)
		if node == null:
			game.free()
			return
		speeds.append(node.scroll.y)

	for i in speeds.size():
		_check(speeds[i] > 0.0,
				"%s scrolls %.1f -- every layer must travel the same way as the "
				% [order[i], speeds[i]] + "rest, downstream toward the player")
	for i in speeds.size() - 1:
		_check(speeds[i] < speeds[i + 1],
				"parallax out of order: %s (%.1f) should be slower than %s (%.1f)"
				% [order[i], speeds[i], order[i + 1], speeds[i + 1]])
	# The surface and the depth beneath it must never share a rate. Different
	# tile sizes on different speeds is the entire reason the river stopped
	# looking tiled; set these equal and the visible grid comes straight back,
	# with nothing else in the suite to catch it.
	var surface: float = game.get_node("World/Water").scroll.y
	var depth: float = game.get_node("World/WaterDepth").scroll.y
	_check(absf(surface - depth) > 1.0,
			"the surface and depth layers both scroll at %.1f px/s -- they have "
			% surface + "to differ, or the two tile patterns lock together and "
			+ "the repeat becomes visible again")
	print("  parallax    %s" % [speeds])
	game.free()
	await _frames(2)


## The pads bob on one swell, a fifth of a cycle apart. If they ever share a
## phase they bob in unison and the river reads as five pads on one hinge; if
## the phases are random, as they were, it reads as five pads twitching. The
## wave only exists in the spacing.
func _test_pads_ride_one_swell() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(3)
	game.begin()
	await _frames(12)

	var pads: Array = game.get_node("Leaves").get_children()
	_check(pads.size() == 5, "expected 5 pads, found %d" % pads.size())

	var heights: Array[float] = []
	var phases: Array[float] = []
	for pad in pads:
		phases.append(pad.wave_phase)
		heights.append((pad.get_node("Sprite") as Node2D).position.y)

	for i in phases.size():
		for j in range(i + 1, phases.size()):
			_check(absf(phases[i] - phases[j]) > 0.4,
					"pads %d and %d share a swell phase (%.2f) -- they will bob "
					% [i, j, phases[i]] + "in unison instead of as a wave")

	# And the phases have to show up as actual spread in where the pads sit.
	var lo := heights[0]
	var hi := heights[0]
	for h in heights:
		lo = minf(lo, h)
		hi = maxf(hi, h)
	_check(hi - lo > 1.5,
			"the pads are level (spread %.2f px) -- the swell is not moving them"
			% (hi - lo))
	print("  swell       pad heights spread %.1f px across the row" % (hi - lo))
	game.free()
	await _frames(2)


# --- the difficulty curve ----------------------------------------------------

## One number drives the current, the pads and the hazards, so its shape is the
## whole game's difficulty. Asserted rather than eyeballed because a tuning
## change that flattens the opening or lets the curve run away is invisible
## until someone plays it.
func _test_the_curve() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(3)

	var previous := -1.0
	for seconds in [0.0, 15.0, 30.0, 60.0, 120.0, 180.0, 600.0]:
		var value: float = game.intensity_at(seconds)
		_check(value > previous,
				"intensity must keep climbing: %.3f at %.0fs is not above %.3f"
				% [value, seconds, previous])
		_check(value < 1.0,
				"intensity reached %.3f at %.0fs -- it must approach 1 without "
				% [value, seconds] + "arriving, or the late game has no headroom")
		previous = value

	# The gentle phase, which is the whole compromise over having lives at all:
	# a stranger's first credit still buys a real go.
	#
	# Asserted as a SHAPE, not against a magic number. It used to pin
	# intensity_at(60) to 0.30, which meant every tuning pass had to edit the
	# test to say what the code now said -- a test that agrees with whatever it
	# is given is not checking anything.
	var gentle_for: float = game.get_script().get_script_constant_map()["GENTLE_SECONDS"]
	var ceiling: float = game.get_script().get_script_constant_map()["GENTLE_CEILING"]
	var at_minute: float = game.intensity_at(gentle_for)
	_check(absf(at_minute - ceiling) < 0.02,
			"the gentle phase should hand over at %.2f intensity, got %.3f"
			% [ceiling, at_minute])
	_check(game.intensity_at(gentle_for * 0.5) < ceiling * 0.65,
			"the opening is not gentle: %.3f intensity halfway through the "
			% game.intensity_at(gentle_for * 0.5) + "gentle phase")

	# "Twice as fast" was the literal ask. The old river opened at 34 px/s.
	# cruise_speed(), not current_speed(): the second one is scaled by how far
	# into the launch the run is, and this game's clock has barely started. The
	# launch gets its own test below.
	game.set("_intensity", 0.0)
	var opening: float = game.cruise_speed()
	game.set("_intensity", 1.0)
	var late: float = game.cruise_speed()
	_check(opening >= 204.0,
			"the river opens at %.0f px/s -- it should start at three times the "
			% opening + "68 it ran at before, which is the whole 'aggressive "
			+ "from the first second' change")
	# Measured as the speed ADDED, not as a ratio. The ratio fell when the
	# opening tripled, which says nothing about whether the river still builds
	# -- and a ratio test would have demanded an unreadable 600+ px/s ceiling
	# to keep itself happy.
	_check(late - opening >= 250.0,
			"the river only gains %.0f px/s across a run (%.0f to %.0f) -- it has "
			% [late - opening, opening, late] + "to keep climbing, not just "
			+ "start fast")
	_check(late <= 520.0,
			"the river reaches %.0f px/s, past the point where the water strobes "
			% late + "rather than flows at this resolution")
	print("  curve       %.0f -> %.0f px/s, intensity %.2f at %.0fs"
			% [opening, late, at_minute, gentle_for])
	game.free()
	await _frames(2)


## The river is taken up to speed over the first few seconds rather than
## starting there. Asserted at the ends because the shape in between is a
## smoothstep and pinning its middle would just be writing the formula twice.
func _test_the_river_launches() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(3)

	game.set("elapsed", 0.0)
	var at_gun: float = game.launch_factor()
	_check(at_gun <= 0.01,
			"the river is already at %.0f%% speed on the first frame -- it is "
			% (at_gun * 100.0) + "meant to start from a standstill")

	game.set("elapsed", LAUNCH_OVER)
	# Explicitly typed: `game` is a MiniGame, so these Riverleap-only calls come
	# back as Variant and := has nothing to infer from.
	var half: float = game.launch_factor()
	_check(half >= 0.95,
			"the river is only at %.0f%% speed after the launch should be over"
			% (half * 100.0))

	# And the two speeds must actually differ during the launch, or the ramp is
	# wired up to nothing.
	game.set("elapsed", 0.6)
	game.set("_intensity", 0.0)
	var during: float = game.current_speed()
	var cruise: float = game.cruise_speed()
	_check(during < cruise * 0.6,
			"mid-launch the river runs at %.0f px/s against a cruise of %.0f -- "
			% [during, cruise] + "the ramp is not reaching the water")
	print("  launch      0%% -> %.0f%% over %.1fs, %.0f px/s at 0.6s"
			% [half * 100.0, LAUNCH_OVER, during])
	game.free()
	await _frames(2)


## Pads come back faster than they used to, faster still as the pace rises, and
## then stop improving. All three parts matter and each can break on its own:
## a flat curve is the old behaviour back, a runaway one eventually respawns
## pads instantly, and a curve going the wrong way would quietly make the late
## game impossible while every other test stayed green.
func _test_pads_come_back_faster() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(3)

	var samples: Array[float] = []
	for step in 6:
		game.set("_intensity", float(step) / 5.0)
		samples.append(game.regen_delay())

	# Quicker than the flat 2.2s it replaced, everywhere.
	for i in samples.size():
		_check(samples[i] < 2.2,
				"regen at intensity %.1f is %.2fs -- it has to beat the flat "
				% [float(i) / 5.0, samples[i]] + "2.2s it replaced")
	# Monotonic: faster pace, faster regen, never the other way.
	for i in samples.size() - 1:
		_check(samples[i + 1] < samples[i],
				"regen goes %.2fs -> %.2fs between intensity %.1f and %.1f -- "
				% [samples[i], samples[i + 1], float(i) / 5.0, float(i + 1) / 5.0]
				+ "it must only ever get quicker")
	# And it flattens: the last step must gain far less than the first.
	var first := samples[0] - samples[1]
	var last := samples[samples.size() - 2] - samples[samples.size() - 1]
	_check(last < first * 0.4,
			"regen improves by %.3fs at the end against %.3fs at the start -- "
			% [last, first] + "the gain is meant to shrink to nothing, not keep "
			+ "going")
	_check(samples[samples.size() - 1] > 0.3,
			"regen has fallen to %.2fs -- it must plateau above a floor, not "
			% samples[samples.size() - 1] + "approach zero")
	print("  regen       %.2fs -> %.2fs, flattening (%.3fs gain at the end)"
			% [samples[0], samples[samples.size() - 1], last])
	game.free()
	await _frames(2)


# --- hazards -----------------------------------------------------------------

## The assertion this whole round hangs on. Both hazards are measured
## standalone and **at the worst case the game can produce** -- a hornet at its
## top airspeed, a heron on its shortest telegraph -- because if
## they are reactable there they are reactable everywhere.
func _test_hazards_are_dodgeable() -> void:
	var hornet_hazard := (load(HAZARD) as PackedScene).instantiate() as RiverHazard
	hornet_hazard.kind = RiverHazard.Kind.HORNET
	hornet_hazard.lane = 2
	hornet_hazard.row_y = row_y()
	hornet_hazard.speed = FASTEST_HORNET
	hornet_hazard.position = Vector2(240.0, -60.0)
	add_child(hornet_hazard)

	var seen_at := -1.0
	var struck_at := -1.0
	var clock := 0.0
	while clock < 4.0:
		await _frames(1)
		clock += get_process_delta_time()
		if not is_instance_valid(hornet_hazard):
			break
		# On screen, rather than merely existing: it spawns above the viewport.
		if seen_at < 0.0 and hornet_hazard.position.y > 0.0:
			seen_at = clock
		if hornet_hazard.is_striking():
			struck_at = clock
			break

	_check(struck_at > 0.0 and seen_at > 0.0,
			"a hornet never reached the player's row within 4s")
	if struck_at > 0.0 and seen_at > 0.0:
		var lead := struck_at - seen_at
		_check(lead >= HORNET_LEAD_FLOOR,
				"a hornet at full speed is only on screen %.2fs before it hits -- "
				% lead + "under %.2fs there is nothing to react to" % HORNET_LEAD_FLOOR)
		print("  hornet      %.2fs of warning at %.0f px/s" % [lead, FASTEST_HORNET])
	if is_instance_valid(hornet_hazard):
		hornet_hazard.free()
	await _frames(2)

	# The heron's shortest telegraph, which is what it uses late on.
	var shortest := 0.50
	var heron := (load(HAZARD) as PackedScene).instantiate() as RiverHazard
	heron.kind = RiverHazard.Kind.HERON
	heron.lane = 2
	heron.row_y = row_y()
	heron.telegraph = shortest
	heron.position = Vector2(240.0, row_y())
	add_child(heron)

	var warned_at := -1.0
	var dived_at := -1.0
	clock = 0.0
	while clock < 4.0:
		await _frames(1)
		clock += get_process_delta_time()
		if not is_instance_valid(heron):
			break
		var warning := heron.get_node_or_null("Warning") as Sprite2D
		if warned_at < 0.0 and warning != null and warning.modulate.a > 0.2:
			warned_at = clock
		if heron.is_striking():
			dived_at = clock
			break

	_check(dived_at > 0.0 and warned_at > 0.0,
			"a heron never dived, or never showed a warning, within 4s")
	if dived_at > 0.0 and warned_at > 0.0:
		var lead := dived_at - warned_at
		# The ring has to be up for the full telegraph. Not "most of it": the
		# telegraph IS the dodge, since jumping does not help here.
		_check(lead >= shortest - 0.02,
				"a heron's warning only precedes the dive by %.2fs of its %.2fs "
				% [lead, shortest] + "telegraph -- jumping does not save you from "
				+ "this one, so the ring is the only way out")
		print("  heron       %.2fs of warning on a %.2fs telegraph" % [lead, shortest])
	if is_instance_valid(heron):
		heron.free()
	await _frames(2)


## Both hazards fly so that the draw order can simply BE the rule: jump and you
## are drawn over the hornet, stay down and it is drawn over you. That rule
## shipped backwards once and the whole suite passed through it, because the
## constants in wind_leaf.gd were right -- it was the SCENE that broke them.
## Godot makes a child's z_index relative to its parent, and both the Hazards
## container and the hazard's own root set 25, so hazards resolved to 50 and
## sailed over the airborne player at 30.
##
## So this test resolves the real tree rather than reading the constants back.
## A constants check would have passed on the broken build.
func _test_jumping_puts_you_over_a_hornet() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(3)
	game.begin()
	await _frames(2)

	game.call("_spawn_hazard", RiverHazard.Kind.HORNET, int(game.get("_lane")))
	await _frames(2)
	var hazards: Array = game.get_node("Hazards").get_children()
	_check(hazards.size() > 0, "no hornet spawned to test the draw order against")
	if hazards.is_empty():
		game.free()
		return
	var hazard_z := _effective_z(hazards[0])
	var player: Node2D = game.get_node("Player")

	game.call("_set_airborne", false)
	var grounded := _effective_z(player)
	game.call("_set_airborne", true)
	var airborne := _effective_z(player)

	_check(airborne > hazard_z,
			"a jumping player draws at z %d and the hornet at z %d -- jump over "
			% [airborne, hazard_z] + "something and you must be drawn ON TOP of "
			+ "it, or clearing it looks like being hit by it")
	_check(grounded < hazard_z,
			"a standing player draws at z %d and the hornet at z %d -- it has to "
			% [grounded, hazard_z] + "pass over you when you fail to jump, "
			+ "because that is what hitting you looks like")
	if airborne > hazard_z and grounded < hazard_z:
		print("  draw order  grounded %d < hornet %d < airborne %d"
				% [grounded, hazard_z, airborne])
	game.call("_set_airborne", false)
	game.free()
	await _frames(2)


## What Godot will actually sort by: z_index accumulates up the parent chain
## for as long as the nodes are relative, which is the default and the thing
## that made this bug invisible.
func _effective_z(node: CanvasItem) -> int:
	var total := node.z_index
	var parent := node.get_parent()
	while node.z_as_relative and parent is CanvasItem:
		node = parent as CanvasItem
		total += node.z_index
		parent = node.get_parent()
	return total


## Getting hit is not just losing a life where you stand: it throws you off the
## pad and you go in the water as well. Asserted rather than eyeballed, because
## "did she actually get knocked off?" is a question about state over time and
## a screenshot of one frame cannot answer it.
##
## It must also cost exactly ONE life. The drowning that follows the hit would
## normally charge its own half, and the mercy window is the only thing
## stopping a single hornet taking two bites -- which is easy to break and
## invisible until someone counts their hearts.
func _test_a_hit_knocks_you_into_the_water() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(3)
	game.begin()
	# Hazards are ignored entirely until the river is up to speed, so the
	# collision this test is about cannot happen during the run-up.
	game.set("elapsed", LAUNCH_OVER + 1.0)
	await _frames(4)

	var before: int = game.get("_life_halves")
	var lane: int = game.get("_lane")
	# Drop a hornet right on the row, in the player's lane, while they are
	# standing on it -- the exact case the knockback exists for.
	game.call("_spawn_hazard", RiverHazard.Kind.HORNET, lane)
	var hazards: Array = game.get_node("Hazards").get_children()
	_check(hazards.size() > 0, "no hornet spawned for the knockback test")
	if hazards.is_empty():
		game.free()
		return
	hazards[0].position.y = row_y()

	var wet := false
	for i in 90:
		await _frames(1)
		if bool(game.get("_in_water")):
			wet = true
			break
	var after: int = game.get("_life_halves")

	_check(wet, "a hornet hit left the player standing on the pad -- being hit "
			+ "has to knock you off it and into the river")
	_check(before - after == 2,
			"a hornet hit cost %d half-lives, expected 2 -- the splash that "
			% (before - after) + "follows a hit must be free, or one hornet "
			+ "takes two bites out of the same mistake")
	if wet and before - after == 2:
		print("  knockback   hit -> thrown into the water, one life, not two")
	game.free()
	await _frames(2)


## The first hornet you ever see must be slow enough to read.
##
## This is NOT the same promise as HORNET_LEAD_FLOOR and the two must not be
## collapsed into one: a hornet on its debut used to clear that floor easily at
## 0.67s and was still too fast the first time, which is what Neo reported.
## Measured through the game's own spawner at the moment of introduction, so a
## change to the ramp, the interval or the spawn height all show up here.
func _test_the_first_hornet_is_readable() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(3)
	game.begin()
	# Stand the clock at the hornet's introduction and ask for one.
	# `elapsed` counts from the gun; the hazard clocks count from the end of
	# the launch, so the debut moment is LAUNCH_OVER later on this clock.
	game.set("elapsed", LAUNCH_OVER + 35.0)
	game.set("_intensity", game.intensity_at(35.0))
	game.call("_spawn_hazard", RiverHazard.Kind.HORNET, 2)
	await _frames(1)

	var hazards: Array = game.get_node("Hazards").get_children()
	_check(hazards.size() > 0, "no hornet spawned at its introduction")
	if hazards.is_empty():
		game.free()
		return
	var hornet: RiverHazard = hazards[0]
	# On screen is from y=0; above that it is not warning anybody.
	var lead: float = (hornet.row_y - RiverHazard.STRIKE_BAND) / hornet.speed

	_check(lead >= HORNET_DEBUT_FLOOR,
			"the first hornet gives %.2fs of warning at %.0f px/s -- the first "
			% [lead, hornet.speed] + "one a player ever sees needs %.2fs to be "
			% HORNET_DEBUT_FLOOR + "learned from, not just dodged")
	if lead >= HORNET_DEBUT_FLOOR:
		print("  debut       first hornet %.2fs of warning at %.0f px/s"
				% [lead, hornet.speed])
	game.free()
	await _frames(2)


## The river comes up to speed before the game starts throwing things. A pad
## used to begin shaking on the very first frame, and a chime spawned at the
## gun visibly hung at the top of the screen, because chimes drift at a
## fraction of a current that was still nearly zero.
func _test_the_launch_is_quiet() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(3)
	game.begin()

	var disturbed := 0
	var hazards := 0
	var chimes := 0
	while game.elapsed < LAUNCH_OVER - 0.1:
		await _frames(1)
		for pad in game.get_node("Leaves").get_children():
			if pad.state != RiverLeaf.State.STABLE:
				disturbed += 1
		hazards = maxi(hazards, game.get_node("Hazards").get_child_count())
		chimes = maxi(chimes, game.get_node("Chimes").get_child_count())

	_check(disturbed == 0,
			"a pad was already going under %d frames into the launch -- nothing "
			% disturbed + "should be thrown at the player before the river is "
			+ "even up to speed")
	_check(hazards == 0, "%d hazards spawned during the launch" % hazards)
	_check(chimes == 0,
			"%d chimes spawned during the launch -- they drift at a fraction of "
			% chimes + "the current, so one released now just hangs there")
	if disturbed == 0 and hazards == 0 and chimes == 0:
		print("  launch gate calm water for the whole %.1fs run-up" % LAUNCH_OVER)
	game.free()
	await _frames(2)


## The opening card: the controls, then 3-2-1-GO.
##
## The first check here is the load-bearing one. The suite instances the game
## as a CHILD and calls begin() itself, so it must never meet the card -- if
## that guard breaks, every game instance in this file starts waiting eight
## seconds and the suite quietly takes minutes longer while still passing.
func _test_the_opening_card() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(6)
	var cards := 0
	for child in game.get_children():
		if child is StartCard:
			cards += 1
	_check(cards == 0,
			"the suite built %d start cards -- the game must only show one when "
			% cards + "it IS the running scene, or every test in this file "
			+ "waits out a countdown it cannot see")
	game.free()
	await _frames(2)

	# A repeat player skips the lesson and gets only the countdown.
	#
	# Timed in GAME seconds, never with Time.get_ticks_msec(). Headless at
	# --fixed-fps 60 runs unthrottled: the countdown's 2.5s of game time goes
	# by in about 3ms of wall clock, so a wall-clock assertion here measured
	# nothing and "passed" by accident in both directions.
	StartCard.tutorial_seen = true
	var replay_s := await _time_card()
	# Three beats plus the release. Anything less and the game starts before GO.
	var floor_s := StartCard.BEAT * 3.0
	_check(replay_s >= floor_s,
			"the countdown ran %.2fs, under the %.2fs its own beats need -- the "
			% [replay_s, floor_s] + "game would start before GO")
	_check(replay_s < StartCard.TUTORIAL_SECONDS,
			"a repeat player waited %.2fs, as long as the whole lesson -- the "
			% replay_s + "tutorial is not being skipped on replay")

	# And a first-timer gets markedly more than that.
	StartCard.tutorial_seen = false
	var first_s := await _time_card()
	_check(first_s > replay_s + 2.0,
			"a first-timer waited %.2fs against a repeat player's %.2fs -- the "
			% [first_s, replay_s] + "lesson is barely being shown")
	print("  start card  first run %.1fs, replay %.1fs" % [first_s, replay_s])
	StartCard.tutorial_seen = false
	await _frames(2)


## Runs one card through and returns how long it took in GAME seconds.
##
## play() is started and NOT awaited, so the frame loop below can run while it
## does; awaiting it directly would hand control back only at the end and
## leave nothing to count. The counter is an Array because GDScript lambdas
## capture locals by VALUE -- an `int` incremented inside the callback stays
## zero outside it, which looks exactly like a signal that never fired.
func _time_card() -> float:
	var card := StartCard.new()
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


## The cabinet runs all day, so "has this player seen the tutorial" cannot just
## be a flag set once per process -- that would teach the first player of the
## morning and nobody else.
func _test_a_new_player_is_taught_again() -> void:
	StartCard.tutorial_seen = true
	StartCard.note_idle(1000)
	_check(StartCard.tutorial_seen,
			"a 1s gap between runs reset the tutorial -- that is the same "
			+ "player pressing again, not a new one")

	StartCard.note_idle(StartCard.STRANGER_AFTER_MS + 1)
	_check(not StartCard.tutorial_seen,
			"the results card sat untouched for over %ds and the next player "
			% int(StartCard.STRANGER_AFTER_MS / 1000) + "still got no "
			+ "tutorial -- on a cabinet only the first player of the day "
			+ "would ever be taught")
	if not StartCard.tutorial_seen:
		print("  new player  taught again after %ds idle"
				% int(StartCard.STRANGER_AFTER_MS / 1000))
	StartCard.tutorial_seen = false


# --- playing it --------------------------------------------------------------

## The playability floor. A competent bot must get through the opening; if a
## later tuning pass makes the first minute brutal, this is what says so.
##
## It also watches the cornering invariant on every frame, because the two
## directors -- pads and hazards -- used to check it independently and could
## close every lane between them.
func _test_the_opening_is_survivable() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	var run := await _play(game, OPENING_FLOOR + 25.0, true, true)

	_check(run["survived"] >= OPENING_FLOOR,
			"a competent bot lasted only %.1fs with %d half-lives left -- the "
			% [run["survived"], run["lives"]]
			+ "opening is meant to be survivable for at least %.0fs"
			% OPENING_FLOOR)
	_check(run["cornered"] == 0,
			"the player had no reachable lane to stand on for %d frames, and "
			% run["cornered"] + "not straight after a hop -- so the pad and "
			+ "hazard directors cornered them between them rather than the "
			+ "player hopping into it")
	print("  opening     bot held on %.1fs, %d/10 half-lives left, %d dodges"
			% [run["survived"], run["lives"], run["dodged"]])
	game.free()
	await _frames(2)


## The river never runs out, so losing the last life is the only way out. A bot
## that never touches the controls has to reach it -- and report exactly once.
func _test_a_run_must_end() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	var run := await _play(game, MAX_SECONDS, false)

	var result: MiniGameResult = run["result"]
	_checks += 1
	if result == null:
		_failures.append("a passive run never ended within %ds -- losing every "
				% int(MAX_SECONDS) + "life is the endless loop's only exit")
	else:
		_check(run["lives"] == 0,
				"the run ended with %d half-lives still in hand" % run["lives"])
		_check(result.score > 0,
				"the run ended with a score of %d -- surviving at all should pay"
				% result.score)
		_check(int(result.stats.get("survived", 0)) > 0,
				"the result carries no survival time, which is half the score")
		print("  ending      passive run died after %5.1fs  score %5d  %s"
				% [result.duration, result.score, result.stats])
	game.free()
	await _frames(2)


# --- regressions -------------------------------------------------------------

## The bug that made drowning optional: _unhandled_input refused to hop in the
## water, but the input buffer drained from _process and fired the queued hop
## anyway, lifting the player straight back out. Holding a direction meant
## never getting wet.
##
## Now that moving takes a direction AND a button, the test hammers both for
## the whole recovery, which covers the old path and the new one.
func _test_drowning_is_not_escapable() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(3)
	game.begin()
	await _frames(4)

	game.call("_fall_in")
	var lane_at_splash: int = game.get("_lane")

	# Lean on the stick and mash the button across the whole recovery, which is
	# the input that used to work.
	_hold(&"move_left")
	var escaped := false
	for i in 50:
		_send(&"act", i % 2 == 0)
		await _frames(1)
		if not bool(game.get("_in_water")):
			escaped = true
			break
	_send(&"act", false)
	_release_all()

	_check(not escaped, "drowning is escapable again: a held direction and act "
			+ "lifted the player out of the water (lane %d)" % lane_at_splash)
	if not escaped:
		print("  wind_leaf   drowning holds under a held direction and act")
	game.free()
	await _frames(2)


# --- the bot -----------------------------------------------------------------
#
# The control change makes this a state machine where it used to be one tap.
# A direction on its own does nothing now; moving means holding the stick AND
# pressing act, and _unhandled_input reads the stick with
# Input.is_action_pressed at the instant the act event arrives -- so the hold
# has to land a frame BEFORE the press, or every hop comes out as a jump in
# place and the bot never leaves its lane. Three frames per action: hold,
# press, release.

## Returned by _bot_decide when there is nothing worth doing this frame.
const BOT_WAIT := 9

var _bot_phase: int = 0
## Seconds since the player last landed, or -1 before the first hop.
var _since_landing: float = -1.0


func _bot_step(game: MiniGame) -> void:
	if _bot_phase == 1:
		_send(&"act", true)
		_bot_phase = 2
		return
	if _bot_phase == 2:
		_send(&"act", false)
		_release_all()
		_bot_phase = 0
		return
	if bool(game.get("_hopping")) or bool(game.get("_in_water")) \
			or bool(game.get("_ending")):
		return

	var direction := _bot_decide(game)
	if direction == BOT_WAIT:
		return
	if direction != 0:
		_hold(&"move_left" if direction < 0 else &"move_right")
	_bot_phase = 1


## What a decent player does, in priority order: leave a lane something is
## diving on or whose pad is going, then deal with a hornet -- step around it if
## there is room, jump it if there is not.
##
## Deliberately not optimal. It only has to show that the opening is clearable
## by someone paying attention; if it had to be perfect to pass, the test would
## be measuring the bot instead of the game.
func _bot_decide(game: MiniGame) -> int:
	var lane: int = game.get("_lane")
	var pads: Array = game.get_node("Leaves").get_children()
	var hazards: Array = game.get_node("Hazards").get_children()

	if not _usable(pads, hazards, lane):
		for offset: int in [-1, 1]:
			if _usable(pads, hazards, lane + offset):
				return offset
		# Cornered. Leaving the water for a moment beats standing in it.
		return 0

	if _hornet_closing(hazards, lane):
		for offset: int in [-1, 1]:
			if _usable(pads, hazards, lane + offset) \
					and not _lane_has_hornet(hazards, lane + offset):
				return offset
		return 0

	return BOT_WAIT


## The cornering invariant, computed here from the pads and hazards rather than
## asked of the game, so that a bug in the game's own version of this question
## cannot hide behind it.
func _usable(pads: Array, hazards: Array, lane: int) -> bool:
	if lane < 0 or lane >= pads.size():
		return false
	if not (pads[lane] as RiverLeaf).is_safe():
		return false
	for hazard in hazards:
		if not is_instance_valid(hazard):
			continue
		# A hornet does not make a lane unusable -- you can jump it. A dive does.
		if hazard.lane == lane and not hazard.is_dodgeable_by_jumping():
			return false
	return true


## True when a hornet in this lane is close enough to act on. The window is
## sized off its own airspeed, so it means the same thing at 260 and at 420.
func _hornet_closing(hazards: Array, lane: int) -> bool:
	for hazard in hazards:
		if not is_instance_valid(hazard) or hazard.lane != lane:
			continue
		if not hazard.is_dodgeable_by_jumping():
			continue
		var lead: float = hazard.speed * 0.30 + 6.0
		if hazard.position.y > hazard.row_y - lead \
				and hazard.position.y < hazard.row_y + 8.0:
			return true
	return false


func _lane_has_hornet(hazards: Array, lane: int) -> bool:
	for hazard in hazards:
		if is_instance_valid(hazard) and hazard.lane == lane \
				and hazard.is_dodgeable_by_jumping():
			return true
	return false


## Drives a real run to its end or to `limit`. With `skilled` false nothing
## touches the controls, which is how the ending gets tested.
func _play(game: MiniGame, limit: float, skilled: bool,
		watch_corners := false) -> Dictionary:
	var received: Array = []
	game.finished.connect(func(r: MiniGameResult) -> void: received.append(r))
	add_child(game)
	await _frames(3)
	game.begin()

	_bot_phase = 0
	var cornered := 0
	var clock := 0.0
	var was_hopping := false
	_since_landing = -1.0
	while received.is_empty() and clock < limit:
		if skilled:
			_bot_step(game)
		var hopping := bool(game.get("_hopping"))
		if was_hopping and not hopping:
			_since_landing = 0.0
		elif _since_landing >= 0.0:
			_since_landing += get_process_delta_time()
		was_hopping = hopping
		if watch_corners and _is_cornered(game):
			cornered += 1
		await _frames(1)
		clock += get_process_delta_time()
	_release_all()

	return {
		"result": received[0] if not received.is_empty() else null,
		"survived": float(game.get("_survived")),
		"lives": int(game.get("_life_halves")),
		"dodged": int(game.get("_dodged")),
		"cornered": cornered,
	}


## How long after landing a corner is treated as the player's own doing rather
## than the director's. One hop plus a beat.
const JUST_LANDED := 0.35

## True when every lane the player could reach in one hop, their own included,
## is either sinking or being dived on.
##
## **The directors must never CREATE this, but a player can still hop into
## it**, and the difference matters. The guarantee in `_leaves_escape_route()`
## is evaluated against where the player is standing at the moment a pad is
## chosen; it cannot be evaluated against where they might go next. Measured
## over long runs, the only corners that occur are ones the bot hopped into
## within a frame or two of landing -- diagnosed as
## `lane=0, pads=[SHAKING, SHAKING, STABLE, GONE, GONE], landed 0.00s ago`,
## with a safe lane two hops away that it had moved away from.
##
## So this ignores the moments just after a landing. Asserting a flat zero
## would be asserting something the code does not promise, and the first time
## a bot made a bad hop the suite would blame the director.
func _is_cornered(game: MiniGame) -> bool:
	if bool(game.get("_in_water")) or bool(game.get("_ending")) \
			or bool(game.get("_hopping")):
		return false
	if _since_landing >= 0.0 and _since_landing < JUST_LANDED:
		return false
	var lane: int = game.get("_lane")
	var pads: Array = game.get_node("Leaves").get_children()
	var hazards: Array = game.get_node("Hazards").get_children()
	for offset: int in [-1, 0, 1]:
		if _usable(pads, hazards, lane + offset):
			return false
	return true


# --- input synthesis ---------------------------------------------------------
#
# Input.action_press() only sets the polled action state; it never travels
# through _input/_unhandled_input. The hop is read by event, so synthetic input
# has to be parsed as a real event or the whole game goes untested.

static func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _hold(action: StringName) -> void:
	if action in _held:
		return
	_send(action, true)
	_held.append(action)


func _release(action: StringName) -> void:
	if action in _held:
		_send(action, false)
		_held.erase(action)


func _release_all() -> void:
	for action in _held.duplicate():
		_release(action)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
