class_name StageDoor
extends Node2D
## The cave door, animated from Neo's eight hand-drawn stage_door frames.
##
## `reversed` is here because the frames' order is a guess until someone looks
## at them in the editor: if door_1 turns out to be the open state, flip this
## in the inspector instead of renaming eight files.

signal opened

const FRAME_COUNT := 8

@export var reversed: bool = false
@export var open_seconds: float = 0.9

@onready var _sprite: Sprite2D = $Sprite

var _textures: Array[Texture2D] = []
var is_open: bool = false


func _ready() -> void:
	for i in range(1, FRAME_COUNT + 1):
		_textures.append(load("res://assets/game/cave/door_%d.png" % i))
	if reversed:
		_textures.reverse()
	_set_frame(0)


func _set_frame(index: int) -> void:
	_sprite.texture = _textures[clampi(index, 0, FRAME_COUNT - 1)]


func open() -> void:
	if is_open:
		return
	is_open = true
	Audio.sfx(&"door")
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void: _set_frame(int(t)),
			0.0, float(FRAME_COUNT - 1), open_seconds)
	tween.tween_callback(func() -> void: opened.emit())


func close() -> void:
	is_open = false
	_set_frame(0)
