class_name PressurePlate
extends Area2D
## One of the five stones in Echo Hollow.
##
## Each plate owns a colour AND a note, so the sequence can be memorised by ear
## as well as by eye. Players who hum it back do noticeably better, and it means
## the puzzle still works for someone who cannot separate the colours.

signal stepped_on(index: int)

const COLOR_NAMES: Array[String] = ["red", "blue", "green", "yellow", "purple"]
const TINTS: Array[Color] = [
	Color(1.0, 0.42, 0.40), Color(0.42, 0.66, 1.0), Color(0.46, 0.88, 0.48),
	Color(1.0, 0.84, 0.24), Color(0.72, 0.48, 0.92),
]

@export var index: int = 0

@onready var _sprite: Sprite2D = $Sprite
@onready var _glow: Sprite2D = $Glow

var _off_texture: Texture2D
var _on_texture: Texture2D
var _player_on: bool = false
## Set false during playback so watching the sequence cannot register as input.
var accepts_input: bool = false


func _ready() -> void:
	_off_texture = load("res://assets/game/cave/plate_off.png")
	_on_texture = load("res://assets/game/cave/plate_on_%s.png" % COLOR_NAMES[index])
	_sprite.texture = _off_texture
	_glow.modulate = TINTS[index]
	_glow.modulate.a = 0.0
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not (body is TopDownPlayer):
		return
	_player_on = true
	if accepts_input:
		light(0.35)
		stepped_on.emit(index)


func _on_body_exited(body: Node2D) -> void:
	# Debounce: you have to step off before the same stone counts again, so
	# standing on a plate cannot spam the sequence.
	if body is TopDownPlayer:
		_player_on = false


func is_occupied() -> bool:
	return _player_on


## Lights the plate for `seconds`, with its own note.
func light(seconds: float, silent: bool = false) -> void:
	if not silent:
		Audio.plate_note(index)
	_sprite.texture = _on_texture

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_glow, "modulate:a", 0.85, 0.06)
	tween.tween_property(_glow, "scale", Vector2(1.5, 1.5), 0.10)
	tween.set_parallel(false)
	tween.tween_interval(seconds)
	tween.set_parallel(true)
	tween.tween_property(_glow, "modulate:a", 0.0, 0.16)
	tween.tween_property(_glow, "scale", Vector2(1.0, 1.0), 0.16)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void: _sprite.texture = _off_texture)


## Red flash on every plate at once: the "that was wrong" signal.
func flash_wrong() -> void:
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1, 0.35, 0.3), 0.08)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.35)
