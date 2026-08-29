class_name Swimmer
extends Node2D
## Something drifting past under the water: a fish, or a bottle somebody threw in.
##
## Everything about a swimmer is a tell. Bottles move dead straight at a steady
## speed; fish weave and vary. Both are tinted down as if seen through water, so
## the player has to read the silhouette rather than the colour -- which is the
## skill the minigame is actually asking for.

enum Kind { FISH_COMMON, FISH_RARE, PLASTIC }

## Reading the silhouette is the skill, so it has to be readable: the first
## tint darkened already-dark fish against dark blue water.
const UNDERWATER_TINT := Color(0.88, 0.95, 1.0, 0.95)

const VALUES := {
	Kind.FISH_COMMON: 150,
	Kind.FISH_RARE: 300,
	Kind.PLASTIC: -100,
}

var kind: Kind = Kind.FISH_COMMON
var direction: float = 1.0
var speed: float = 40.0
var hooked: bool = false

@onready var _sprite: Sprite2D = $Sprite

var _weave_phase: float = 0.0
var _weave_amount: float = 0.0
var _base_y: float = 0.0


func _ready() -> void:
	_base_y = position.y
	_weave_phase = randf() * TAU
	# Bottles do not swim. That difference is deliberately readable at a glance.
	_weave_amount = 0.0 if kind == Kind.PLASTIC else randf_range(3.0, 8.0)
	_sprite.texture = load(_texture_path())
	_sprite.modulate = UNDERWATER_TINT
	_sprite.flip_h = direction < 0.0
	if kind == Kind.PLASTIC:
		_sprite.rotation = randf_range(-0.3, 0.3)


func _process(delta: float) -> void:
	if hooked:
		return
	position.x += direction * speed * delta
	_weave_phase += delta * 2.2
	position.y = _base_y + sin(_weave_phase) * _weave_amount
	if kind != Kind.PLASTIC:
		_sprite.rotation = sin(_weave_phase) * 0.12


func _texture_path() -> String:
	match kind:
		Kind.FISH_RARE:
			return "res://assets/game/fishing/fish_2.png"
		Kind.PLASTIC:
			return "res://assets/game/fishing/plastic.png"
	return "res://assets/game/fishing/fish_1.png"


func value() -> int:
	return VALUES[kind]


func is_plastic() -> bool:
	return kind == Kind.PLASTIC


## Pulled to the bank. Rises out of the water as it comes, hence the tint fade.
func reel_to(target: Vector2, seconds: float) -> Signal:
	hooked = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_sprite, "modulate", Color.WHITE, seconds * 0.6)
	tween.tween_property(_sprite, "scale", Vector2(1.25, 1.25), seconds)
	return tween.finished
