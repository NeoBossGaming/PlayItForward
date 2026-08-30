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
	"res://src/shell/draw/draw.tscn",
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
	await _test_card_deal()
	await _test_lore()
	await _test_cutscene_player()
	for entry in Game.MINIGAMES:
		await _test_minigame(entry)
	await _test_full_run()


func _test_autoloads() -> void:
	_check(Game != null, "Game autoload missing")
	_check(Router != null, "Router autoload missing")
	_check(Audio != null, "Audio autoload missing")
	_check(Save != null, "Save autoload missing")
	_check(Game.MINIGAMES.size() == 8, "expected 8 minigames in the pool")

	# The draw has to deal a legal hand every time or a session can open on a
	# duplicate card, or on a game that is not in the pool at all.
	for attempt in 40:
		var hand := Game.draw_playlist()
		_check(hand.size() == Game.PLAYLIST_SIZE,
				"draw dealt %d cards, expected %d" % [hand.size(), Game.PLAYLIST_SIZE])
		var seen: Array[StringName] = []
		for id in hand:
			_check(not (id in seen), "draw dealt %s twice" % id)
			_check(not Game.definition(id).is_empty(), "draw dealt unknown id %s" % id)
			seen.append(id)

	# The debug menu must never be showing on its own. On the cabinet this is an
	# exported release build where it does not even listen for the key, but a
	# visible-by-default overlay would be a bad surprise either way.
	var debug_menu := get_node_or_null(^"/root/DebugMenu")
	_check(debug_menu != null, "DebugMenu autoload missing")
	if debug_menu != null:
		_check(not debug_menu.visible, "the debug menu should start hidden")

	Audio.sfx(&"hop")
	Audio.plate_note(2)
	_check(true, "audio synthesis did not crash")

	# Scoring must never hand the results screen a negative number.
	var result := MiniGameResult.new(&"x", -500, 1.0, {})
	_check(result.score == 0, "MiniGameResult should clamp negative scores to 0")


## The card table is the front door of the cabinet, so it is worth proving that
## what it shows is what was dealt -- not just that the deal itself is legal.
func _test_card_deal() -> void:
	Game.start_run()
	Router.set("_draw_deals", true)
	var draw := (load("res://src/shell/draw/draw.tscn") as PackedScene).instantiate()
	add_child(draw)

	# Poll for the reels to stop rather than waiting a fixed number of frames.
	# The table hands off to Router about 1.5s after the last card lands, and
	# that scene change would free this test out from under itself.
	var cards: Array = []
	for i in 170:
		await _frames(1)
		cards = draw.get_node("Cards").get_children()
		var dealt := cards.size() == Game.PLAYLIST_SIZE
		for card in cards:
			if card.id == &"":
				dealt = false
		if dealt:
			break
	_check(cards.size() == Game.PLAYLIST_SIZE,
			"the table should lay out %d cards" % Game.PLAYLIST_SIZE)
	var shown: Array[StringName] = []
	for i in mini(cards.size(), Game.playlist.size()):
		var id: StringName = cards[i].id
		_check(id == Game.playlist[i],
				"card %d shows %s but the hand says %s" % [i + 1, id, Game.playlist[i]])
		_check(not (id in shown), "card %d repeats %s" % [i + 1, id])
		shown.append(id)
	draw.free()
	await _frames(2)


## The lore is a data table of texture paths, and a typo in one of them is
## invisible until that exact cutscene plays in front of somebody. Loading every
## path any cutscene can ask for is the single most valuable check in this file.
func _test_lore() -> void:
	var paths := Lore.every_texture_path()
	_check(paths.size() > 20, "lore should name plenty of sprites, found %d" % paths.size())
	for path in paths:
		_check(ResourceLoader.exists(path), "lore names a texture that is not on disk: %s" % path)
		if ResourceLoader.exists(path):
			_check(load(path) != null, "lore names a texture that will not load: %s" % path)

	for entry in Game.MINIGAMES:
		var id: StringName = entry["id"]
		_check(String(entry.get("gift", "")) != "", "%s has no gift for the sun" % id)
		var lists: Array[Array] = [Lore.before(id), Lore.after(id, true),
				Lore.after(id, false)]
		for shots in lists:
			_check(shots.size() >= 2, "%s has a cutscene with fewer than 2 shots" % id)
			var seconds := 0.0
			for shot: Dictionary in shots:
				seconds += float(shot["seconds"])
				_check(String(shot["caption"]) != "", "%s has a shot with no caption" % id)
				_check((shot["sky"] as Array).size() == 2,
						"%s has a shot without a two-colour sky" % id)
				_check(not (shot["actors"] as Array).is_empty(),
						"%s has a shot with nothing in it" % id)
			# Neo asked for roughly five seconds a side. Anything much longer is
			# a repeat player standing at a cabinet waiting to play.
			_check(seconds >= 4.0 and seconds <= 6.5,
					"%s has a cutscene running %.1fs, expected about 5" % [id, seconds])

	# The finale and the results stamp read the same table, so these thresholds
	# are the ones the rank uses too.
	_check(Lore.tier_for(1.4) == 0, "1.4x par should be the top tier")
	_check(Lore.tier_for(1.0) == 1, "1.0x par should be the second tier")
	_check(Lore.tier_for(0.7) == 2, "0.7x par should be the third tier")
	_check(Lore.tier_for(0.1) == 3, "0.1x par should be the bottom tier")
	_check(Lore.tier_name(0) == "RADIANT", "top tier should still be RADIANT")

	# The finale names the hand that was actually dealt.
	var hand: Array[StringName] = [&"wind_leaf", &"temple_bell", &"cave"]
	for tier in 4:
		var finale := Lore.finale(tier, hand)
		_check(finale.size() >= 4, "finale tier %d is too short" % tier)
		var joined := ""
		for shot: Dictionary in finale:
			joined += String(shot["caption"]) + " "
		_check(joined.contains("the dawn bell"),
				"finale tier %d should name the gifts the run brought" % tier)
	_check(Lore.finale(0, []).size() >= 4, "the finale must survive an empty hand")


## Plays one of each kind end to end, and proves the skip rule: a press in the
## first second is swallowed (it is usually the tail of the press that started
## the game), a press after it ends the scene.
func _test_cutscene_player() -> void:
	var packed: PackedScene = load("res://src/ui/cutscene.tscn")
	_check(packed != null, "could not load the cutscene scene")
	if packed == null:
		return

	var samples: Array[Array] = [
		Lore.before(&"wind_leaf"),
		Lore.after(&"temple_bell", true),
		Lore.finale(0, [&"firefly", &"harpoon", &"crow_watch"]),
	]
	for shots in samples:
		var scene: Cutscene = packed.instantiate()
		add_child(scene)
		var over := [false]
		scene.done.connect(func() -> void: over[0] = true)
		scene.play(shots)
		for i in 900:
			if over[0]:
				break
			await _frames(1)
		_check(over[0], "a cutscene never finished on its own")

	# Skipping. The finale is the longest thing in the game, so if a skip works
	# anywhere it works here.
	var skippable: Cutscene = packed.instantiate()
	add_child(skippable)
	var done := [false]
	skippable.done.connect(func() -> void: done[0] = true)
	skippable.play(Lore.finale(3, [&"cave"]))
	await _frames(20)                       # ~0.3s: still inside the dead zone
	_send(&"act", true)
	await _frames(2)
	_send(&"act", false)
	await _frames(20)
	_check(not done[0], "a press in the first second should not skip a cutscene")

	await _frames(70)                       # now past SKIP_AFTER
	_send(&"act", true)
	await _frames(2)
	_send(&"act", false)
	for i in 90:
		if done[0]:
			break
		await _frames(1)
	_check(done[0], "a press after the first second should skip a cutscene")


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
	_check(Game.playlist.is_empty(), "a fresh run should have no hand yet")

	# A session is over when the dealt hand is played out, not when every game
	# in the pool has been.
	Game.playlist = [&"wind_leaf", &"tall_grass", &"cave"]
	Game.playlist_index = 0
	_check(Game.current_id() == &"wind_leaf", "the first card should be up first")
	Game.advance()
	Game.advance()
	_check(not Game.all_complete(), "2 of 3 cards played is not a finished run")
	Game.advance()
	_check(Game.all_complete(), "3 of 3 cards played finishes the run")
	_check(Game.playlist_par() > 0, "the dealt hand should have a par to rank against")
	Game.record(MiniGameResult.new(&"wind_leaf", 1200, 60.0, {"chimes": 5, "splashes": 1}))
	Game.record(MiniGameResult.new(&"tall_grass", 900, 50.0, {"petals": 3, "spotted": 2}))
	Game.record(MiniGameResult.new(&"cave", 1100, 45.0, {"stages": 5, "mistakes": 1}))
	Game.record(MiniGameResult.new(&"harpoon", 800, 75.0, {"fish": 6, "plastic": 2}))
	_check(Game.total_score() == 4000, "total should be 4000, got %d" % Game.total_score())
	_check(Game.plastic_removed() == 2, "plastic tally should reach the results screen")

	# Replaying a chore must not be able to lower a score you already banked.
	Game.record(MiniGameResult.new(&"cave", 400, 30.0, {"stages": 2, "mistakes": 6}))
	_check(Game.score_for(&"cave") == 1100, "a worse replay should not replace a better score")
	Game.record(MiniGameResult.new(&"cave", 1600, 40.0, {"stages": 5, "mistakes": 0}))
	_check(Game.score_for(&"cave") == 1600, "a better replay should replace the old score")
	_check(Game.total_score() == 4500, "total should follow the best of each chore")

	# user:// survives between runs, so without this the assertion depends on
	# whatever previous runs happened to leave in the table.
	Save.clear()
	_check(Save.best() == 0, "clearing should empty the high score table")
	var rank := Save.submit(Game.total_score(), Game.plastic_removed())
	_check(rank == 1, "the only score in an empty table should rank first")
	Game.end_run()


static func _send(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
