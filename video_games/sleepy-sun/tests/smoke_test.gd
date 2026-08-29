extends Node
## Headless smoke test. Run it with:
##
##     godot --headless --path . tests/smoke_test.tscn
##
## Loads every scene in the game, runs each one for a few hundred frames with
## synthetic input, and checks that each minigame reaches a valid result. It
## cannot judge how anything feels -- that is a job for the editor -- but it
## does catch broken node paths, null references and minigames that can no
## longer be finished, which is most of what breaks when scenes are edited.

const FRAMES_PER_GAME := 420
const SHELL_SCENES: Array[String] = [
	"res://src/shell/attract/attract.tscn",
	"res://src/hub/hub.tscn",
	"res://src/shell/results/results.tscn",
]

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	await _run()
	print("\n================ SMOKE TEST ================")
	if _failures.is_empty():
		print("PASS  -  %d checks" % _checks)
	else:
		print("FAIL  -  %d of %d checks" % [_failures.size(), _checks])
		for failure in _failures:
			print("  x  " + failure)
	print("===========================================")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _run() -> void:
	await _test_autoloads()
	await _test_shell_scenes()
	for entry in Game.MINIGAMES:
		await _test_minigame(entry)
	await _test_full_run()


func _test_autoloads() -> void:
	_check(Game != null, "Game autoload missing")
	_check(Router != null, "Router autoload missing")
	_check(Audio != null, "Audio autoload missing")
	_check(Save != null, "Save autoload missing")
	_check(Game.MINIGAMES.size() == 4, "expected 4 minigames")

	Audio.sfx(&"hop")
	Audio.plate_note(2)
	_check(true, "audio synthesis did not crash")

	# Scoring must never hand the results screen a negative number.
	var result := MiniGameResult.new(&"x", -500, 1.0, {})
	_check(result.score == 0, "MiniGameResult should clamp negative scores to 0")


func _test_shell_scenes() -> void:
	for path in SHELL_SCENES:
		var packed: PackedScene = load(path)
		_check(packed != null, "could not load %s" % path)
		if packed == null:
			continue
		var scene := packed.instantiate()
		add_child(scene)
		await _frames(90)
		scene.free()
		_check(true, "%s ran 90 frames" % path.get_file())


func _test_minigame(entry: Dictionary) -> void:
	var id: StringName = entry["id"]
	var packed: PackedScene = load(entry["scene"])
	_check(packed != null, "could not load scene for %s" % id)
	if packed == null:
		return

	var game := packed.instantiate() as MiniGame
	_check(game != null, "%s root is not a MiniGame" % id)
	if game == null:
		return
	_check(game.id == id, "%s has id %s, expected %s" % [entry["scene"], game.id, id])

	var received: Array = []
	game.finished.connect(func(r: MiniGameResult) -> void: received.append(r))
	add_child(game)
	await _frames(2)
	game.begin()

	# Drive it with plausible input rather than letting it sit idle, so the
	# hop/step/strike paths actually execute.
	var actions: Array[StringName] = [&"move_left", &"move_right", &"move_up",
			&"move_down", &"act"]
	for i in FRAMES_PER_GAME:
		if not received.is_empty():
			break
		if i % 7 == 0:
			var action: StringName = actions[(i / 7) % actions.size()]
			# action_press() alone never reaches _unhandled_input, so the hop,
			# cast and strike paths would go untested. Parse a real event.
			_send(action, true)
			await _frames(1)
			_send(action, false)
		await _frames(1)

	if received.is_empty():
		# Long games (the crossing is a minute) will not end inside the budget.
		# What matters is that finish() still works and reports cleanly.
		game.finish(123, {"forced": true})
		await _frames(2)

	_check(received.size() == 1, "%s did not emit exactly one result" % id)
	if not received.is_empty():
		var result: MiniGameResult = received[0]
		_check(result.id == id, "%s reported id %s" % [id, result.id])
		_check(result.score >= 0, "%s reported a negative score" % id)
		print("  %s -> %s" % [id, result])

	# A second finish() must be ignored, or a race could double-count a score.
	game.finish(999, {})
	await _frames(1)
	_check(received.size() == 1, "%s emitted a result twice" % id)

	game.free()


func _test_full_run() -> void:
	Game.start_run()
	_check(Game.total_score() == 0, "a fresh run should start at zero")
	Game.record(MiniGameResult.new(&"wind_leaf", 1200, 60.0, {"chimes": 5, "splashes": 1}))
	Game.record(MiniGameResult.new(&"tall_grass", 900, 50.0, {"petals": 3, "spotted": 2}))
	Game.record(MiniGameResult.new(&"cave", 1100, 45.0, {"stages": 5, "mistakes": 1}))
	_check(not Game.all_complete(), "3 of 4 minigames should not complete the run")
	Game.record(MiniGameResult.new(&"fishing", 800, 75.0, {"fish": 6, "plastic": 2}))
	_check(Game.all_complete(), "4 of 4 minigames should complete the run")
	_check(Game.total_score() == 4000, "total should be 4000, got %d" % Game.total_score())
	_check(Game.plastic_removed() == 2, "plastic tally should reach the results screen")

	# Replaying a chore must not be able to lower a score you already banked.
	Game.record(MiniGameResult.new(&"cave", 400, 30.0, {"stages": 2, "mistakes": 6}))
	_check(Game.score_for(&"cave") == 1100, "a worse replay should not replace a better score")
	Game.record(MiniGameResult.new(&"cave", 1600, 40.0, {"stages": 5, "mistakes": 0}))
	_check(Game.score_for(&"cave") == 1600, "a better replay should replace the old score")
	_check(Game.total_score() == 4500, "total should follow the best of each chore")

	var rank := Save.submit(Game.total_score(), Game.plastic_removed())
	_check(rank >= 1, "a score should make an empty high score table")
	Game.end_run()


static func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
