class_name MeadowPickup
extends Node2D
## Something worth grabbing in Hush Meadow.
##
## Three kinds, and they exist to pull the player in three different directions.
## Petals sit still and reward showing up. Seeds drift, so taking one means going
## wherever the wind is taking it, which is rarely where you wanted to be. Dew is
## invisible until you are standing in a grass patch, which finally gives cover a
## reason to be entered rather than only hidden in -- the safe route and the
## greedy route overlap for the first time.

enum Kind { PETAL, SEED, DEW }

const VALUES := {Kind.PETAL: 110, Kind.SEED: 200, Kind.DEW: 160}
const TEXTURES := {
	Kind.PETAL: "res://assets/game/tall_grass/petal.png",
	Kind.SEED: "res://assets/game/firefly/mote.png",
	Kind.DEW: "res://assets/game/wind_leaf/chime.png",
}

var kind: Kind = Kind.PETAL
var drift: Vector2 = Vector2.ZERO
## Dew stays hidden until the player is inside the grass patch holding it.
var revealed: bool = true

@onready var _sprite: Sprite2D = $Sprite

var _phase: float = 0.0


func _ready() -> void:
	_phase = randf() * TAU
	_sprite.texture = load(TEXTURES[kind])
	match kind:
		Kind.SEED:
			_sprite.modulate = Color(0.85, 1.0, 0.75)
			_sprite.scale = Vector2(1.2, 1.2)
		Kind.DEW:
			_sprite.modulate = Color(0.7, 0.95, 1.0)
	if kind == Kind.DEW:
		revealed = false
		_sprite.visible = false


func _process(delta: float) -> void:
	_phase += delta
	position += drift * delta
	_sprite.rotation = sin(_phase * 1.6) * 0.25
	_sprite.position.y = sin(_phase * 2.4) * 1.5
	if kind == Kind.SEED:
		# Seeds bob more, so a moving pickup never reads as a static one.
		_sprite.position.y += sin(_phase * 4.1) * 1.5


## Called when the player enters the grass patch this dew is hiding in.
func reveal() -> void:
	if revealed:
		return
	revealed = true
	_sprite.visible = true
	_sprite.scale = Vector2(0.3, 0.3)
	Audio.sfx(&"chime", 1.5)
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.15, 1.15), 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.12)


func value() -> int:
	return VALUES[kind]


func label() -> String:
	match kind:
		Kind.SEED:
			return "SEED"
		Kind.DEW:
			return "DEW"
	return ""
