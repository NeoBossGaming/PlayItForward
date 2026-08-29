extends Node
## Entry point. Exists only so the main scene is something stable that hands
## straight over to Router -- swapping the opening screen never touches
## project.godot.


func _ready() -> void:
	await get_tree().process_frame
	Router.go_to_attract()
