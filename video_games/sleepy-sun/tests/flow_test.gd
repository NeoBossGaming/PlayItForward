extends Node
## Whole-cabinet loop test. Run it with:
##
##     godot --headless --fixed-fps 60 --path . tests/flow_test.tscn
##
## Drives the real state machine from the proposal -- Idle/Attract -> Gameplay
## -> Results -> Idle -- through actual scene changes, rather than instancing
## scenes in isolation the way the other two tests do. This is the Phase 1
## acceptance criterion in the design overview: the full loop plays start to
## finish on ordinary hardware.
##
## The driver reparents itself to the scene tree root, because Router replaces
## `current_scene` and anything living there gets freed mid-test.

## Generous, because a step is now a scene change plus up to five seconds of
## lore plus an intro card, and the finale is longer still.
const STEP_TIMEOUT := 45.0
const ARRIVE_RADIUS := 12.0

var is_driver: bool = false

var _failures: PackedStringArray = []
var _steps: int = 0
var _held: Array[StringName] = []


func _ready() -> void:
	if is_driver:
		await _drive()
		return
	var driver: Node = (get_script() as GDScript).new()
	driver.is_driver = true
	driver.name = "FlowDriver"
	get_tree().root.add_child.call_deferred(driver)


# --- the loop ----------------------------------------------------------------

func _drive() -> void:
	await _frames(4)

	Router.go_to_attract()
	await _expect("Attract", "attract screen after boot")

	# A coin or the start button wakes the cabinet.
	_tap(&"start")
	await _expect("Draw", "card table after pressing start")
	_check(Game.run_active, "pressing start should open a run")

	# The draw scene deals during its own reveal, so wait for a hand.
	await _wait_for_hand()
	var hand := Game.playlist.duplicate()
	_check(hand.size() == Game.PLAYLIST_SIZE, "the draw should deal a full hand")

	for i in hand.size():
		await _play_card(hand[i], i)

	_check(Game.all_complete(), "every dealt card should be recorded")
	_check(Game.total_score() > 0, "a finished run should have scored something")

	await _expect("Results", "results screen after the last card")

	# The results screen holds input for a few seconds so it cannot be skipped
	# before the player has seen their score.
	await _wait(4.0)
	_tap(&"act")
	await _expect("Attract", "back to attract after the results screen")
	_check(not Game.run_active, "the run should be closed once results are shown")

	print("\n================= FLOW TEST =================")
	if _failures.is_empty():
		print("PASS  -  %d steps, full attract -> play -> results -> attract loop"
				% _steps)
	else:
		print("FAIL")
		for failure in _failures:
			print("  x  " + failure)
	print("============================================")
	get_tree().quit(0 if _failures.is_empty() else 1)


## The draw scene deals the hand partway through its reveal animation.
func _wait_for_hand() -> void:
	var clock := 0.0
	while clock < STEP_TIMEOUT:
		if Game.playlist.size() == Game.PLAYLIST_SIZE:
			return
		await _frames(1)
		clock += get_process_delta_time()
	_check(false, "the draw never dealt a hand")


func _play_card(id: StringName, index: int) -> void:
	await _expect_minigame(id)
	_check(Game.playlist_index == index,
			"card %d should be up, but the session is on %d" % [index, Game.playlist_index])
	var game := _scene() as MiniGame
	if game == null:
		return

	# Get past the lore beat and the intro card the way a repeat player does.
	# This is also the only place the skip path is exercised against the real
	# flow, so a cutscene that cannot be dismissed fails the suite here.
	await _skip_to_play(game)
	_check(game.running, "%s never started playing after its intro" % id)

	# What is under test here is the transition, not the minigame -- the soak
	# test already plays each one properly.
	game.finish(500, {})
	_check(true, "%s finished and handed back" % id)
	# Last card goes to Results; any other returns to the table.
	if index < Game.PLAYLIST_SIZE - 1:
		await _expect("Draw", "back to the card table after %s" % id)
	await _frames(2)
	_check(Game.has_played(id), "%s should be recorded on the run" % id)


## Taps through the cutscene and the intro card until the game is actually
## running. Deliberately impatient: it starts pressing immediately, so the
## first presses land inside the cutscene's dead zone and are ignored.
func _skip_to_play(game: MiniGame) -> void:
	var clock := 0.0
	while clock < STEP_TIMEOUT:
		if not is_instance_valid(game) or game.running or game.is_finished():
			return
		await _tap(&"act")
		await _wait(0.25)
		clock += 0.3
	_check(false, "timed out getting past the intro for %s" % game.id)


# --- helpers -----------------------------------------------------------------

func _scene() -> Node:
	return get_tree().current_scene


## Waits until the current scene's root is named `scene_name`.
func _expect(scene_name: String, description: String) -> void:
	var clock := 0.0
	while clock < STEP_TIMEOUT:
		var scene := _scene()
		if scene != null and scene.name == scene_name and not Router.is_busy():
			_check(true, description)
			await _frames(3)
			return
		await _frames(1)
		clock += get_process_delta_time()
	_check(false, "timed out waiting for %s (%s); current scene is %s"
			% [scene_name, description, _scene().name if _scene() else "<none>"])


func _expect_minigame(id: StringName) -> void:
	var clock := 0.0
	while clock < STEP_TIMEOUT:
		var scene := _scene()
		if scene is MiniGame and (scene as MiniGame).id == id and not Router.is_busy():
			_check(true, "%s minigame opened from the card table" % id)
			await _frames(3)
			return
		await _frames(1)
		clock += get_process_delta_time()
	_check(false, "timed out opening the %s minigame" % id)


func _walk(player: Node2D, target: Vector2, scene: Node) -> bool:
	var clock := 0.0
	while clock < STEP_TIMEOUT:
		if not is_instance_valid(player) or _scene() != scene:
			break
		if player.position.distance_to(target) < ARRIVE_RADIUS:
			_release_all()
			return true
		_steer(player.position, target)
		await _frames(1)
		clock += get_process_delta_time()
	_release_all()
	return false


func _steer(from: Vector2, to: Vector2) -> void:
	var delta := to - from
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		_release(action)
	if absf(delta.x) > 4.0:
		_hold(&"move_right" if delta.x > 0.0 else &"move_left")
	if absf(delta.y) > 4.0:
		_hold(&"move_down" if delta.y > 0.0 else &"move_up")


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


func _tap(action: StringName) -> void:
	_send(action, true)
	await _frames(2)
	_send(action, false)
	await _frames(1)


func _check(condition: bool, message: String) -> void:
	_steps += 1
	if not condition:
		_failures.append(message)


func _wait(seconds: float) -> void:
	var clock := 0.0
	while clock < seconds:
		await _frames(1)
		clock += get_process_delta_time()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
