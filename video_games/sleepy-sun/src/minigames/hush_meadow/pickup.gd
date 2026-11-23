class_name MeadowPickup
extends Node2D
## Something worth grabbing in Hush Meadow.
##
## Two kinds, and the difference between them is the whole design.
##
## A PETAL sits in the open. It pays points and takes a little off the nerve
## meter, and taking one means standing somewhere a bird can see you.
##
## DEW is invisible until you are standing inside the grass patch holding it,
## and it is the only thing that really calms you down. That one rule is what
## makes cover somewhere to GO rather than only somewhere to hide: hiding
## freezes the meter but never lowers it, so a player who only hides loses
## slowly and a player who forages has to keep stepping out of cover to find
## the next patch. The safe route and the greedy route are the same route.
##
## Dew is parented to its patch, so it scrolls with the grass it is hiding in
## without this file knowing the meadow moves at all.

enum Kind { PETAL, DEW, GOLD }

const VALUES := {Kind.PETAL: 90, Kind.DEW: 150, Kind.GOLD: 0}
const TEXTURES := {
	Kind.PETAL: "res://assets/game/hush_meadow/petal.png",
	Kind.DEW: "res://assets/game/hush_meadow/dew.png",
	Kind.GOLD: "res://assets/game/hush_meadow/dew_gold.png",
}

var kind: Kind = Kind.PETAL
var drift: Vector2 = Vector2.ZERO
## Dew stays hidden until the player is inside the grass patch holding it.
var revealed: bool = true
## The patch this is tucked inside, or null for something lying in the open.
var patch: MeadowPatch = null

@onready var _sprite: Sprite2D = $Sprite

var _phase: float = 0.0


func _ready() -> void:
	_phase = randf() * TAU
	_sprite.texture = load(TEXTURES[kind])
	if kind != Kind.PETAL:
		revealed = false
		_sprite.visible = false


func _process(delta: float) -> void:
	_phase += delta
	position += drift * delta
	_sprite.rotation = sin(_phase * 1.6) * 0.22
	_sprite.position.y = sin(_phase * 2.4) * 1.5
	if kind == Kind.GOLD:
		# Breathes, so a gold droplet is not just a recoloured one sitting
		# still. The glint on the sprite does the rest.
		var pulse := 1.0 + sin(_phase * 7.0) * 0.12
		_sprite.scale = Vector2(pulse, pulse)


## Called when the player enters the grass patch this is hiding in. The reveal
## is the reward for going into cover, so it gets a sound and a pop rather than
## simply switching visible on.
func reveal() -> void:
	if revealed:
		return
	revealed = true
	_sprite.visible = true
	_sprite.scale = Vector2(0.3, 0.3)
	Audio.sfx(&"chime", 1.5 if kind == Kind.DEW else 1.0)
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.15, 1.15), 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.12)


func value() -> int:
	return VALUES[kind]


func label() -> String:
	match kind:
		Kind.DEW:
			return "DEW"
		Kind.GOLD:
			return ""
	return ""
