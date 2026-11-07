extends Node
## Riverleap soak. Run it with:
##
##     godot --headless --fixed-fps 60 --path . tests/soak_test.tscn
##
## The one suite, now that the project is one game. It proves the thing most
## worth protecting: that the game can actually be *finished*. It drives
## Riverleap with scripted input until the crossing ends on its own, rather
## than forcing finish() -- a minigame that cannot be completed still looks
## fine in the editor and still survives a short run.
##
## It also carries the regressions this game has already had, because a bug
## that got through once will get through again.

const SCENE := "res://src/minigames/wind_leaf/wind_leaf.tscn"
const MAX_SECONDS := 200.0

var _failures: PackedStringArray = []
var _checks: int = 0
var _held: Array[StringName] = []
var _taps_to_release: Array[StringName] = []
var _reacted_to_lane: int = -1


func _ready() -> void:
	await _test_contract()
	await _test_crossing()
	await _test_drowning_is_not_escapable()

	print("\n================= SOAK TEST =================")
	if _failures.is_empty():
		print("PASS  -  %d checks, Riverleap reached its own ending" % _checks)
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

## The parts of the old smoke suite still worth having with one game: the scene
## loads, it reports once, and it cannot be made to report twice.
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

	# A race between "the crossing ended" and "the timer ran out" must not be
	# able to report a score twice.
	game.finish(999, {})
	await _frames(1)
	_check(received.size() == 1, "a second finish() should be ignored")

	game.free()
	await _frames(2)


# --- the crossing ------------------------------------------------------------

func _test_crossing() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	var received: Array = []
	game.finished.connect(func(r: MiniGameResult) -> void: received.append(r))
	add_child(game)
	await _frames(3)
	game.begin()

	var clock := 0.0
	while received.is_empty() and clock < MAX_SECONDS:
		for action in _taps_to_release:
			_release(action)
		_taps_to_release.clear()
		_drive(game)
		await _frames(1)
		clock += get_process_delta_time()
	_release_all()

	_checks += 1
	if received.is_empty():
		_failures.append("Riverleap never finished on its own within %ds"
				% int(MAX_SECONDS))
	else:
		var result: MiniGameResult = received[0]
		print("  wind_leaf   finished naturally after %5.1fs  score %5d  %s"
				% [result.duration, result.score, result.stats])
		_check(result.score > 0, "Riverleap finished with a score of %d" % result.score)
		_check(int(result.stats.get("chimes", 0)) > 0,
				"a whole crossing collected no chimes -- they are unreachable")
	game.free()
	await _frames(2)


## Hop away whenever the leaf underfoot starts shaking. The crossing is on a
## timer, so this only has to avoid drowning the whole way.
func _drive(game: MiniGame) -> void:
	var leaves: Array = game.get_node("Leaves").get_children()
	var lane: int = game.get("_lane")
	var current := leaves[lane] as RiverLeaf
	if current.state != RiverLeaf.State.SHAKING:
		_reacted_to_lane = -1
		return
	if _reacted_to_lane == lane:
		return
	for offset: int in [-1, 1]:
		var target: int = lane + offset
		if target >= 0 and target < leaves.size() and (leaves[target] as RiverLeaf).is_safe():
			_reacted_to_lane = lane
			_tap(&"move_right" if offset > 0 else &"move_left")
			return


# --- regressions -------------------------------------------------------------

## The bug that made drowning optional: _unhandled_input refused to hop in the
## water, but the input buffer drained from _process and fired the queued hop
## anyway, lifting the player straight back out. Holding a direction meant
## never getting wet.
func _test_drowning_is_not_escapable() -> void:
	var game := (load(SCENE) as PackedScene).instantiate() as MiniGame
	add_child(game)
	await _frames(3)
	game.begin()
	await _frames(4)

	# Queue a hop, then drown on the same frame the buffer is still live.
	_send(&"move_right", true)
	await _frames(1)
	_send(&"move_right", false)
	game.call("_fall_in")
	var lane_at_splash: int = game.get("_lane")

	# Hold the direction across the whole recovery, which is what used to work.
	_hold(&"move_left")
	for i in 40:
		await _frames(1)
	var still_wet: bool = game.get("_in_water")
	_release_all()

	_check(still_wet, "drowning is escapable again: a buffered or held direction "
			+ "lifted the player out of the water (lane %d)" % lane_at_splash)
	if still_wet:
		print("  wind_leaf   drowning holds under a held direction")
	game.free()
	await _frames(2)


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


## A press this frame and a release the next, so both edges are seen.
func _tap(action: StringName) -> void:
	_hold(action)
	_taps_to_release.append(action)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
