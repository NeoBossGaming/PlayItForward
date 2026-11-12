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


## Timing note for every suite that follows: headless at `--fixed-fps 60` runs
## UNTHROTTLED. Several seconds of game time pass in a few milliseconds of wall
## clock, so `Time.get_ticks_msec()` measures nothing useful. Accumulate
## `get_process_delta_time()` across awaited frames instead.
##
## And count into an Array, never an int: GDScript lambdas capture locals by
## value, so `n += 1` inside a signal callback leaves the outer `n` at zero,
## which looks exactly like a signal that never fired.
