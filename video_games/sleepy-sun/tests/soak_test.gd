extends Node
## Completability soak. Run it with:
##
##     godot --headless --fixed-fps 60 --path . tests/soak_test.tscn
##
## The smoke test proves the minigames run. This one proves they can actually be
## *finished*: it drives each one with scripted input until it reaches its own
## ending, rather than forcing finish(). That is the property most worth
## protecting, because a minigame that cannot be completed still looks fine in
## the editor and still passes a short smoke run.
##
## It reaches into a couple of private fields (the cave's generated sequence,
## the meadow's petal nodes) because it has to play the games competently, not
## just poke at them.

const MAX_SECONDS_PER_GAME := 200.0
const ARRIVE_RADIUS := 7.0

## Ordinals of cave.gd's Phase enum.
const CAVE_INPUT := 2
const CAVE_WALKING := 4

var _failures: PackedStringArray = []
var _checks_run: int = 0
var _held: Array[StringName] = []
var _taps_to_release: Array[StringName] = []
var _reacted_to_lane: int = -1


func _ready() -> void:
	await _play(&"wind_leaf", _drive_wind_leaf)
	await _test_drowning_is_not_escapable()
	await _play(&"tall_grass", _drive_tall_grass)
	await _play(&"cave", _drive_cave)
	await _play(&"harpoon", _drive_harpoon)
	await _play(&"acorn_storm", _drive_acorn_storm)
	await _play(&"firefly", _drive_firefly)
	await _play(&"temple_bell", _drive_temple_bell)
	await _play(&"crow_watch", _drive_crow_watch)

	print("\n================= SOAK TEST =================")
	if _failures.is_empty():
		print("PASS  -  all %d minigames reached their own ending"
				% Game.MINIGAMES.size())
	else:
		print("FAIL")
		for failure in _failures:
			print("  x  " + failure)
	print("============================================")
	get_tree().quit(0 if _failures.is_empty() else 1)


func _play(id: StringName, driver: Callable) -> void:
	var entry := Game.definition(id)
	var game := (load(entry["scene"]) as PackedScene).instantiate() as MiniGame
	var received: Array = []
	game.finished.connect(func(r: MiniGameResult) -> void: received.append(r))
	add_child(game)
	await _frames(3)
	game.begin()

	var clock := 0.0
	while received.is_empty() and clock < MAX_SECONDS_PER_GAME:
		for action in _taps_to_release:
			_release(action)
		_taps_to_release.clear()
		driver.call(game)
		await _frames(1)
		clock += get_process_delta_time()
	_release_all()

	if received.is_empty():
		_failures.append("%s never finished on its own within %ds"
				% [id, int(MAX_SECONDS_PER_GAME)])
	else:
		var result: MiniGameResult = received[0]
		print("  %-11s finished naturally after %5.1fs  score %5d  %s"
				% [id, result.duration, result.score, result.stats])
		if result.score <= 0:
			_failures.append("%s finished with a score of %d" % [id, result.score])
	game.free()
	await _frames(2)


# --- input synthesis ---------------------------------------------------------
#
# Input.action_press() only sets the polled action state; it never travels
# through _input/_unhandled_input. Half the game reads input by event (hops,
# casts, strikes), so synthetic input has to be parsed as a real event or those
# code paths are silently never exercised.

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


## Presses the direction keys that move `from` toward `to`, exactly as a player
## leaning on the stick would.
func _steer(from: Vector2, to: Vector2) -> bool:
	var delta := to - from
	_release(&"move_left")
	_release(&"move_right")
	_release(&"move_up")
	_release(&"move_down")
	if delta.length() < ARRIVE_RADIUS:
		return true
	if absf(delta.x) > 3.0:
		_hold(&"move_right" if delta.x > 0.0 else &"move_left")
	if absf(delta.y) > 3.0:
		_hold(&"move_down" if delta.y > 0.0 else &"move_up")
	return false


# --- per-game drivers --------------------------------------------------------

## Hop away whenever the leaf underfoot starts shaking. Crossing is on a timer,
## so this only has to avoid drowning the whole way.
func _drive_wind_leaf(game: MiniGame) -> void:
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


## Walk to each petal in turn, then to the tree. Makes no attempt to dodge the
## birds -- being caught is a setback, not an ending, so a clumsy player still
## has to be able to finish.
func _drive_tall_grass(game: MiniGame) -> void:
	var player: Node2D = game.get_node("Player")
	var petals: Array = game.get_node("Petals").get_children()
	var target: Vector2 = game.get_node("Goal").position
	if not petals.is_empty():
		var nearest: Node2D = petals[0]
		for petal: Node2D in petals:
			if petal.position.distance_to(player.position) \
					< nearest.position.distance_to(player.position):
				nearest = petal
		target = nearest.position
	_steer(player.position, target)


## Watch the sequence, then walk it back. Reads the generated pattern directly,
## which is the only way a script can play a memory game.
func _drive_cave(game: MiniGame) -> void:
	var player: Node2D = game.get_node("Player")
	var phase: int = game.get("_phase")
	var plates: Array = game.get_node("Plates").get_children()

	if phase == CAVE_WALKING:
		_steer(player.position, Vector2(320, 168))
		return
	if phase != CAVE_INPUT:
		_release_all()
		return

	var sequence: Array = game.get("_sequence")
	var index: int = game.get("_input_index")
	if index >= sequence.size():
		return
	# Straight at the stone: the ring layout means the path between any two
	# stones passes through the middle of the chamber, not over a third stone.
	var plate: Node2D = plates[sequence[index]]
	_steer(player.position, plate.position)


## Line up under the nearest fish and fire. The round ends on its own clock, so
## this only has to prove the shot path works and can score.
func _drive_harpoon(game: MiniGame) -> void:
	var player: Node2D = game.get_node("Player")
	var best: Node2D = null
	var best_distance := INF
	for child in game.get_node("Swimmers").get_children():
		if child.get("hooked") or child.get("kind") == 2:      # skip bottles
			continue
		var distance: float = absf(child.position.x - player.position.x)
		if distance < best_distance:
			best_distance = distance
			best = child
	if best == null:
		_release_all()
		return
	# Lead the target: aim where it will be by the time the bolt arrives.
	var flight: float = (player.position.y - best.position.y) / 620.0
	var lead: float = best.position.x + best.get("direction") * best.get("speed") * flight
	if _steer(Vector2(player.position.x, 0.0), Vector2(lead, 0.0)):
		_tap(&"act")


## Walk onto whatever sunfruit is closest to landing; ignore the acorns, since
## being hit is a setback rather than an ending.
func _drive_acorn_storm(game: MiniGame) -> void:
	var player: Node2D = game.get_node("Player")
	var target := Vector2.ZERO
	var best := -1.0
	for holder in game.get_node("Falling").get_children():
		if holder.get_child_count() < 2 or not holder.has_meta(&"acorn"):
			continue
		if bool(holder.get_meta(&"acorn")):
			continue
		var life: float = float(holder.get_meta(&"life"))
		if life > best:
			best = life
			target = holder.get_meta(&"landing")
	if best < 0.0:
		_release_all()
		return
	_steer(player.position, target)


## Chase the nearest firefly. Ignores the greed loop entirely -- a bot that
## always tops up its lantern is the worst case, so if this can finish, anyone can.
func _drive_firefly(game: MiniGame) -> void:
	var player: Node2D = game.get_node("Player")
	var flies: Array = game.get_node("FliesLayer/Flies").get_children()
	if flies.is_empty():
		_release_all()
		return
	var nearest: Node2D = flies[0]
	for fly: Node2D in flies:
		if fly.position.distance_to(player.position) \
				< nearest.position.distance_to(player.position):
			nearest = fly
	_steer(player.position, nearest.position)


## Strike whenever a marker is inside the hit window.
func _drive_temple_bell(game: MiniGame) -> void:
	const APPROACH := 1.6
	const WINDOW := 0.20
	for marker in game.get_node("Markers").get_children():
		if marker.has_meta(&"spent"):
			continue
		if absf(float(marker.get_meta(&"life")) - APPROACH) <= WINDOW * 0.5:
			_tap(&"act")
			return


## Run at whichever crow is closest to landing.
func _drive_crow_watch(game: MiniGame) -> void:
	var player: Node2D = game.get_node("Player")
	var target: Node2D = null
	var best := -1.0
	for holder in game.get_node("Crows").get_children():
		if holder.get_child_count() < 2:
			continue
		var life: float = float(holder.get_meta(&"life"))
		if life > best:
			best = life
			target = holder.get_child(1)
	if target == null:
		_release_all()
		return
	_hold(&"act")                       # sprint
	_steer(player.position, target.position)


## Regression test for the bug that made drowning optional: _unhandled_input
## refused to hop in the water, but the input buffer drained from _process and
## fired the queued hop anyway, lifting the player straight back out.
func _test_drowning_is_not_escapable() -> void:
	var entry := Game.definition(&"wind_leaf")
	var game := (load(entry["scene"]) as PackedScene).instantiate() as MiniGame
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

	_checks_run += 1
	if not still_wet:
		_failures.append("drowning is still escapable: a buffered/held direction "
				+ "lifted the player out of the water (lane %d)" % lane_at_splash)
	else:
		print("  %-11s drowning holds under a held direction" % "wind_leaf")
	game.free()
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
