class_name SoakBase
extends Node
## Shared harness for every game's soak suite.
##
## Riverleap's suite grew to a hundred checks while it was the only game in the
## project. With seven more coming, the parts that are not about any particular
## game -- counting checks, synthesising input, pumping frames, reporting --
## belong in one place rather than copied eight times and drifting apart.
##
## A suite extends this, runs its own `_test_*` coroutines from `_ready()`, and
## ends with `get_tree().quit(report("NAME"))`.

var _failures: PackedStringArray = []
var _checks: int = 0
var _held: Array[StringName] = []


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


## Prints the tally and returns the exit code, so a suite's last line can be
## `get_tree().quit(report("RIVERLEAP"))`.
func report(title: String) -> int:
	print("\n================= %s =================" % title)
	if _failures.is_empty():
		print("PASS  -  %d checks" % _checks)
	else:
		print("FAIL  -  %d of %d checks" % [_failures.size(), _checks])
		for failure in _failures:
			print("  x  " + failure)
	print("============================================")
	return 0 if _failures.is_empty() else 1


# --- input synthesis ---------------------------------------------------------
#
# Input.action_press() only sets the polled action state; it never travels
# through _input/_unhandled_input. Riverleap's hop is read by event, so
# synthetic input has to be parsed as a real event or the whole game goes
# untested -- and the same will be true of anything else read by event.

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


## What Godot will actually sort by: z_index accumulates up the parent chain
## for as long as the nodes are relative, which is the default and the thing
## that once hid an inverted draw order behind a set of entirely correct
## constants. Any game whose rules are expressed in layering needs this.
static func effective_z(node: CanvasItem) -> int:
	var total := node.z_index
	var parent := node.get_parent()
	while node.z_as_relative and parent is CanvasItem:
		node = parent as CanvasItem
		total += node.z_index
		parent = node.get_parent()
	return total


## --- grain ------------------------------------------------------------------
##
## Mean run of identical pixels along a row: the one objective check on "does
## this read as pixel art". Riverleap's water is 20; Acorn Storm's clearing and
## Hush Meadow's meadow shipped at 2.0 and 1.8 -- single-pixel random strokes,
## which is the grain of a photograph -- and every check passed, because
## nothing was asking. See the grain section of tools/make_placeholders.py.
##
## Read from the IMPORTED texture, because that is what gets drawn. Every
## fully transparent pixel counts as the same nothing: the importer's
## fix_alpha_border bleeds colour into them, and an invisible difference is
## not grain.
static func mean_run(path: String) -> float:
	var image := (load(path) as Texture2D).get_image()
	if image.is_compressed():
		image.decompress()
	var width := image.get_width()
	var height := image.get_height()
	var changes := 0
	for y in height:
		var previous := _visible(image.get_pixel(0, y))
		for x in range(1, width):
			var here := _visible(image.get_pixel(x, y))
			if here != previous:
				changes += 1
			previous = here
	if changes == 0:
		return INF
	return float(height * (width - 1)) / float(changes)


static func _visible(colour: Color) -> Color:
	return Color(0, 0, 0, 0) if colour.a8 == 0 else colour


## Asserts a large layer has not drifted back to noise, and prints what it
## measured so a near miss is visible before it is a failure.
func _check_grain(path: String, at_least: float) -> void:
	var run := mean_run(path)
	print("  grain      %5.1f px  (needs %4.1f)  %s"
			% [run, at_least, path.get_file()])
	_check(run >= at_least,
			"%s has a mean run of %.1f px, under %.1f -- fine random grain is "
			% [path.get_file(), run, at_least]
			+ "what reads as a photograph rather than as pixel art")


## Timing note for every suite that follows: headless at `--fixed-fps 60` runs
## UNTHROTTLED. Several seconds of game time pass in a few milliseconds of wall
## clock, so `Time.get_ticks_msec()` measures nothing useful. Accumulate
## `get_process_delta_time()` across awaited frames instead.
##
## And count into an Array, never an int: GDScript lambdas capture locals by
## value, so `n += 1` inside a signal callback leaves the outer `n` at zero,
## which looks exactly like a signal that never fired.
