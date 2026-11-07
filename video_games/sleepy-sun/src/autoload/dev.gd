extends Node
## The whole debug surface, now that the menu is gone.
##
## A polish round is a loop of play, change, play. The two things worth a key
## during that loop are "start over right now" and "show me that again slowly";
## everything else the old menu did -- pick a game, force a hand, watch a
## cutscene -- belonged to a shell that no longer exists.
##
## Inert outside a debug build, so an exported cabinet cannot reach it.

const SLOW_SCALE := 0.35


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
