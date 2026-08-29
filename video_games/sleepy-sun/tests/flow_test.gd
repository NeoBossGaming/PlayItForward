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

const STEP_TIMEOUT := 25.0
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
	await _expect("Hub", "village hub after pressing start")
	_check(Game.run_active, "pressing start should open a run")

	for entry in Game.MINIGAMES:
		await _play_chore(entry)

	_check(Game.all_complete(), "all four chores should be recorded")
	_check(Game.total_score() > 0, "a finished run should have scored something")

	await _walk_to_sun()
	await _expect("Results", "results screen after waking the sun")

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


func _play_chore(entry: Dictionary) -> void:
	var id: StringName = entry["id"]
	var hub := _scene()
	var portal := _find_portal(hub, id)
	if portal == null:
		_failures.append("no portal in the hub for %s" % id)
		return

	var player: Node2D = hub.get_node("Player")
	var arrived := await _walk(player, portal.position + Vector2(0, 12), hub)
	_check(arrived, "could walk to the %s signpost" % id)
	_tap(&"act")

	await _expect_minigame(id)
	var game := _scene() as MiniGame
	if game == null:
		return
	# What is under test here is the transition, not the minigame -- the soak
	# test already plays each one properly.
	game.finish(500, {})
	await _expect("Hub", "return to the hub after %s" % id)
	_check(Game.has_played(id), "%s should be recorded on the run" % id)


func _walk_to_sun() -> void:
	var hub := _scene()
	var player: Node2D = hub.get_node("Player")
	var sun: Node2D = hub.get_node("World/SunArea")
	var arrived := await _walk(player, sun.position + Vector2(0, 18), hub)
	_check(arrived, "could walk up to the sun once every chore was done")
	_tap(&"act")


# --- helpers -----------------------------------------------------------------

func _scene() -> Node:
	return get_tree().current_scene


func _find_portal(hub: Node, id: StringName) -> Node2D:
	for child in hub.get_node("Portals").get_children():
		if child.get("minigame_id") == id:
			return child
	return null


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
			_check(true, "%s minigame opened from the hub" % id)
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
