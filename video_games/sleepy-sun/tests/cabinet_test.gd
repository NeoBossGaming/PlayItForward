extends SoakBase
## Cabinet soak -- the properties that belong to no single game. Run it with:
##
##     godot --headless --fixed-fps 60 --path . tests/cabinet_test.tscn
##
## Neither game's own suite can hold these, because each of them is about how
## the games sit together: that every one of them is reachable, that they do
## not collide, and that the boot scene is one of them.
##
## The load-bearing one is discovery. `Dev` finds games by a convention --
## **one game per folder under src/minigames/, in a scene named after its
## folder** -- and a folder whose scene is named anything else simply would not
## appear in the F4 cycle. Nothing else in the project would say so: the game
## would run perfectly well, be covered by its own suite, and be unreachable.

const GAMES_DIR := "res://src/minigames"


func _ready() -> void:
	await _test_every_game_is_discovered()
	await _test_the_games_do_not_collide()
	await _test_the_boot_scene_is_a_game()
	await _test_the_rank_bands_cover_everything()
	await _test_saves_do_not_mix_games()
	await _test_the_golden_prize_is_rare_but_real()

	get_tree().quit(report("CABINET"))


## Every folder yields exactly one game, and nothing that is not a game is
## picked up. The second half matters as much as the first: `leaf.tscn` and
## `faller.tscn` live beside the games they belong to, and a looser rule that
## swept up every scene in the folder would drop the player into a lily pad.
func _test_every_game_is_discovered() -> void:
	var games := Dev.discover_games()
	var folders := _game_folders()

	_check(folders.size() >= 2,
			"only %d folder under %s -- this suite is checking nothing"
			% [folders.size(), GAMES_DIR])
	_check(games.size() == folders.size(),
			"%d of the %d folders under %s produced a game. A folder whose "
			% [games.size(), folders.size(), GAMES_DIR]
			+ "scene is not named after it is silently unreachable: it runs, "
			+ "its own suite passes, and the game cycle never offers it.")

	for folder in folders:
		var expected := "%s/%s/%s.tscn" % [GAMES_DIR, folder, folder]
		_check(expected in games,
				"%s is missing from the game cycle -- expected %s"
				% [folder, expected])

	# Sorted, so the cycle is in a stable order rather than whatever the
	# filesystem happened to hand back.
	var sorted := games.duplicate()
	sorted.sort()
	_check(games == sorted, "the discovered games are not in a stable order")

	# Pieces are not games.
	for scene in ["res://src/minigames/wind_leaf/leaf.tscn",
			"res://src/minigames/acorn_storm/faller.tscn"]:
		if not ResourceLoader.exists(scene):
			continue
		_check(not (scene in games),
				"%s was discovered as a game -- it is a piece one is built from"
				% scene)

	print("  games       %d found: %s" % [games.size(),
			", ".join(_names(games))])


## Each one loads, is a MiniGame, and says who it is. The ids are what saves
## and score tables key on, so two games sharing one would silently merge their
## records.
func _test_the_games_do_not_collide() -> void:
	var seen: Dictionary = {}
	for scene in Dev.discover_games():
		var packed := load(scene) as PackedScene
		_check(packed != null, "%s did not load" % scene)
		if packed == null:
			continue
		# Instantiated but NOT added to the tree: _ready() would start the
		# game, and this is a question about what the scene declares rather
		# than about what it does.
		var game := packed.instantiate()
		_check(game is MiniGame,
				"%s's root does not extend MiniGame, so the contract the "
				% scene + "cabinet drives every game through does not apply "
				+ "to it")
		if game is MiniGame:
			var id: StringName = game.id
			_check(not String(id).is_empty(),
					"%s reports an empty id" % scene)
			_check(not seen.has(id),
					"%s and %s both report the id '%s' -- saves and score "
					% [scene, seen.get(id, "?"), id] + "tables key on it")
			seen[id] = scene
			_check(game.par_score > 0,
					"%s reports par_score %d; normalised_score() divides by it"
					% [scene, game.par_score])
		game.free()
	await _frames(1)


## The boot scene has to be a game. Nothing else checks it, and a path left
## behind by a rename gives a blank window with an error in the log rather
## than anything that looks like a failure.
func _test_the_boot_scene_is_a_game() -> void:
	var boot := String(ProjectSettings.get_setting("application/run/main_scene", ""))
	_check(not boot.is_empty(), "project.godot sets no main scene")
	var games := Dev.discover_games()
	_check(boot in games,
			"the project boots into %s, which is not one of the games (%s)"
			% [boot, ", ".join(_names(games))])
	print("  boots into  %s" % boot.get_file().get_basename())
	await _frames(1)


## The letter table has to be total and ordered: every possible normalised
## score gets exactly one band, better scores never get worse letters, and no
## band is unreachable (a band nobody can land in is a letter that does not
## exist).
func _test_the_rank_bands_cover_everything() -> void:
	var seen: Dictionary = {}
	var previous := -1
	var outside := -1
	var went_backwards := -1
	# Swept, then asserted ONCE. Checking inside the loop put two thousand
	# entries on the tally and buried every other check in the suite -- a
	# check count should say how many things are guaranteed, not how many
	# times a loop ran.
	for value in range(0, 1001):
		var index := Rank.index(value)
		if index < 0 or index >= Rank.BANDS.size():
			outside = value
		elif previous >= 0 and index > previous:
			went_backwards = value
		previous = index
		seen[Rank.letter(value)] = true
	_check(outside < 0,
			"normalised %d fell outside the band table" % outside)
	_check(went_backwards < 0,
			"normalised %d lands in a worse band than %d did"
			% [went_backwards, went_backwards - 1])

	for band: Array in Rank.BANDS:
		_check(seen.has(String(band[1])),
				"no score between 0 and 1000 earns a %s -- the band is "
				% band[1] + "unreachable, so the letter does not exist")
	_check(Rank.letter(0) == "D" and Rank.letter(1000) == "SS",
			"the ends of the scale are %s and %s"
			% [Rank.letter(0), Rank.letter(1000)])

	# A par run is a B: normalised_from_duration() puts par at 500.
	_check(Rank.letter(500) == "B",
			"a par run earns %s, not the B the bands are built around"
			% Rank.letter(500))
	# And "new letter" compares bands, not numbers.
	_check(Rank.is_new_letter(760, 740),
			"crossing from S's band into the one above did not read as new")
	_check(not Rank.is_new_letter(999, 900),
			"two scores inside SS both claimed a new letter")
	print("  ranks       %s" % " ".join(PackedStringArray(
			Rank.BANDS.map(func(b: Array) -> String:
				return "%s>=%d" % [b[1], b[0]]))))
	await _frames(1)


## Two games, two tables. They shared one while there was one game, and when
## the second arrived both kept writing to it -- so a card showed the other
## game's best, and two incomparable scales were sorted together.
func _test_saves_do_not_mix_games() -> void:
	Save.clear()
	Save.submit(&"wind_leaf", 9000, 700)
	Save.submit(&"acorn_storm", 300, 480)

	_check(Save.best(&"wind_leaf") == 9000,
			"wind_leaf's best came back as %d" % Save.best(&"wind_leaf"))
	_check(Save.best(&"acorn_storm") == 300,
			"acorn_storm's best came back as %d -- the big score from the "
			% Save.best(&"acorn_storm") + "other game is leaking across")
	_check(Save.best(&"nothing_here") == 0,
			"a game with no runs reported a best")

	# The letter comes from normalised, which is not the sort key, so a later
	# run with fewer points but a longer life must still raise the best rank.
	Save.submit(&"acorn_storm", 120, 820)
	_check(Save.best(&"acorn_storm") == 300,
			"a lower-scoring run replaced the best score")
	_check(Save.best_normalised(&"acorn_storm") == 820,
			"best_normalised came back as %d, so a better RANK earned on a "
			% Save.best_normalised(&"acorn_storm") + "lower score was lost")

	Save.clear()
	_check(Save.best(&"wind_leaf") == 0, "clear() left scores behind")
	print("  saves       kept apart per game, best rank tracked separately")
	await _frames(1)


## "About one run in five" is a claim about runs that END with one, not about
## runs that are offered one: a run can finish before the prize is due, and a
## prize that falls still has to be caught. Both of those sit between the roll
## and the thing the player experiences, so the roll is tuned against this
## rather than set to 0.2 and hoped over.
##
## Measured on the roll alone here. The two losses above only ever reduce it,
## so this is the ceiling -- and the floor that matters is that it is not so
## rare nobody ever sees one.
func _test_the_golden_prize_is_rare_but_real() -> void:
	var runs := 20000
	var offered := 0
	var total := 0.0
	for i in runs:
		var at := Golden.roll()
		if at >= 0.0:
			offered += 1
			total += at
			_check_window(at)
	var rate := float(offered) / float(runs)
	_check(absf(rate - Golden.CHANCE) < 0.02,
			"the prize was offered on %.0f%% of runs against the %.0f%% it "
			% [rate * 100.0, Golden.CHANCE * 100.0] + "declares")
	_check(rate > 0.2 and rate < 0.5,
			"an offer rate of %.0f%% cannot land near one collected run in "
			% (rate * 100.0) + "five: too low and nobody sees one, too high "
			+ "and it stops being rare")
	_check(_window_breaks == 0,
			"%d prizes were scheduled outside the window they declare"
			% _window_breaks)
	# The window has to sit inside a run an ordinary player actually reaches.
	# A prize due at 90s in a game whose average run is 85s is a reward for
	# being good, which is the opposite of what a lucky drop is for.
	_check(Golden.WINDOW.y < 80.0,
			"the prize can be scheduled as late as %.0fs, past the point an "
			% Golden.WINDOW.y + "ordinary run reaches")
	_check(Golden.WINDOW.x > 8.0,
			"the prize can arrive %.0fs in, before the player has met the "
			% Golden.WINDOW.x + "ordinary version of it")
	print("  golden      offered on %.0f%% of runs, %.0f-%.0fs in (mean %.0fs)"
			% [rate * 100.0, Golden.WINDOW.x, Golden.WINDOW.y,
					total / maxf(float(offered), 1.0)])
	await _frames(1)


var _window_breaks: int = 0


func _check_window(at: float) -> void:
	if at < Golden.WINDOW.x or at > Golden.WINDOW.y:
		_window_breaks += 1


func _game_folders() -> PackedStringArray:
	var root := DirAccess.open(GAMES_DIR)
	if root == null:
		return PackedStringArray()
	var folders := root.get_directories()
	folders.sort()
	return folders


static func _names(scenes: PackedStringArray) -> PackedStringArray:
	var out := PackedStringArray()
	for scene in scenes:
		out.append(scene.get_file().get_basename())
	return out
