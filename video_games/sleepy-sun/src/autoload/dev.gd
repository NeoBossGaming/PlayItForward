extends Node
## The whole debug surface, now that the menu is gone.
##
## A polish round is a loop of play, change, play. The three things worth a key
## during that loop are "start over right now", "show me that again slowly" and
## -- since there is a second game -- "take me to the other one"; everything
## else the old menu did belonged to a shell that no longer exists.
##
## Inert outside a debug build, so an exported cabinet cannot reach it.

const SLOW_SCALE := 0.35

## Where the games live, one per folder.
const GAMES_DIR := "res://src/minigames"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_input(false)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"slowmo"):
		Engine.time_scale = 1.0 if Engine.time_scale < 1.0 else SLOW_SCALE
		print("slow motion: %s" % ("ON" if Engine.time_scale < 1.0 else "off"))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"next_game"):
		_cycle_game()
		get_viewport().set_input_as_handled()


## --- the game cycle ----------------------------------------------------------
##
## There is no Router any more: each game starts itself and reloads itself on
## replay, so without this the boot scene is the only game reachable without a
## terminal. That was fine with one game and is not with eight coming.
##
## This is a DEBUG key rather than a menu on purpose. A picker would be the
## first brick of the shell that was deliberately parked, and an exported
## cabinet must not grow one by accident -- `_ready()` turns this whole script
## off outside a debug build.

func _cycle_game() -> void:
	var games := discover_games()
	if games.size() < 2:
		print("only %d game found under %s -- nothing to cycle to"
				% [games.size(), GAMES_DIR])
		return

	var here := ""
	if get_tree().current_scene != null:
		here = get_tree().current_scene.scene_file_path
	# Not found means we are somewhere that is not a game -- a test harness, or
	# a scene opened by hand -- so the first game is as good an answer as any.
	var index := games.find(here)
	var next: String = games[(index + 1) % games.size()] if index >= 0 else games[0]

	# A single per-process flag, so arriving at the next game after this one's
	# lesson would skip ITS intro entirely -- which is the thing you are most
	# likely to have pressed this key to look at. Each switch teaches the game
	# it lands on, and any button still skips the card.
	#
	# It stays per-process rather than per-game because `tutorial_seen` is
	# explicitly a stand-in for the parked shell's idea of a new player, and
	# that is where the distinction belongs.
	StartCard.tutorial_seen = false
	Engine.time_scale = 1.0
	print("game: %s" % next.get_file().get_basename())
	get_tree().change_scene_to_file(next)


## Every minigame, sorted, as scene paths.
##
## Discovered rather than listed, by the convention the project already keeps:
## **one game per folder under src/minigames/, in a scene named after its
## folder.** `wind_leaf/wind_leaf.tscn` is a game; `wind_leaf/leaf.tscn` and
## `acorn_storm/faller.tscn` are the pieces one is built from.
##
## Same move `tools/run_tests.sh` makes for `tests/*_test.tscn`, for the same
## reason: adding game three should mean adding a folder, not editing a list in
## a file nobody thinks to look at. tests/cabinet_test.gd checks that the
## convention is actually held, because a folder and scene whose names disagree
## would simply never appear here and nothing else would say so.
##
## Called from the keypress and not from `_ready()`: listing `res://` is a
## debug-build affordance -- at export a `.tscn` becomes a `.scn` behind a
## remap -- and keeping the scan in the handler means an exported build, where
## input is off, never runs it at all.
static func discover_games() -> PackedStringArray:
	var found := PackedStringArray()
	var root := DirAccess.open(GAMES_DIR)
	if root == null:
		return found
	var folders := root.get_directories()
	folders.sort()
	for folder in folders:
		var scene := "%s/%s/%s.tscn" % [GAMES_DIR, folder, folder]
		if ResourceLoader.exists(scene):
			found.append(scene)
	return found
