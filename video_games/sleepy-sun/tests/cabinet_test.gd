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
