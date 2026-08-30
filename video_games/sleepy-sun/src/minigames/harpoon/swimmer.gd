class_name Swimmer
extends Node2D
## Something drifting past under the water: a fish, or a bottle somebody threw in.
##
## Everything about a swimmer is a tell. Bottles move dead straight at a steady
## speed; fish weave and vary. Both are tinted as if seen through water, so the
## player reads the silhouette rather than the colour -- which matters more now
## that a bottle will stop a harpoon dead instead of merely costing points.

enum Kind { FISH_COMMON, FISH_RARE, PLASTIC }

## Reading the silhouette is the skill, so it has to be readable: the first
## tint darkened already-dark fish against dark blue water.
const UNDERWATER_TINT := Color(0.88, 0.95, 1.0, 0.95)

const VALUES := {
	Kind.FISH_COMMON: 100,
	Kind.FISH_RARE: 200,
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
			return "res://assets/game/harpoon/fish_2.png"
		Kind.PLASTIC:
			return "res://assets/game/harpoon/plastic.png"
	return "res://assets/game/harpoon/fish_1.png"


func value() -> int:
	return VALUES[kind]


func is_plastic() -> bool:
	return kind == Kind.PLASTIC


## Speared. Snaps to the bolt and stops swimming; `stopper` marks a bottle,
## which is the thing that halts the bolt rather than being carried along by it.
func impale(at: Vector2, stopper: bool) -> void:
	hooked = true
	position = Vector2(position.x, at.y)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1, 1, 1, 1), 0.06)
	tween.parallel().tween_property(_sprite, "scale",
			Vector2(0.8, 1.25) if stopper else Vector2(1.25, 0.8), 0.06)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.12)


## Scored and gone. Drifts up out of frame so the kill is visible for a beat.
func sink_away() -> void:
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 26.0, 0.35) \
			.set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)
