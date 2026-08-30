class_name BellPickup
extends Node2D
## Something worth leaving the bell for, in Temple Bell's second phase.
##
## All four spawn outside the strike ring, because the cost of collecting is
## being out of range when the next mark lands. A pickup that spawned inside the
## ring would be free, and free is not a decision.

enum Kind { COIN, BURST, FOCUS, DOUBLE }

const VALUES := {Kind.COIN: 150, Kind.BURST: 0, Kind.FOCUS: 0, Kind.DOUBLE: 0}
const TEXTURES := {
	Kind.COIN: "res://assets/game/acorn_storm/sunfruit.png",
	Kind.BURST: "res://assets/game/wind_leaf/chime.png",
	Kind.FOCUS: "res://assets/game/ui/star_on.png",
	Kind.DOUBLE: "res://assets/game/firefly/mote.png",
}
const TINTS := {
	Kind.COIN: Color(1, 0.92, 0.55),
	Kind.BURST: Color(0.7, 0.95, 1.0),
	Kind.FOCUS: Color(0.7, 1.0, 0.75),
	Kind.DOUBLE: Color(1.0, 0.65, 0.85),
}
const LABELS := {
	Kind.COIN: "", Kind.BURST: "CHIME BURST",
	Kind.FOCUS: "FOCUS", Kind.DOUBLE: "DOUBLE",
}

var kind: Kind = Kind.COIN

@onready var _sprite: Sprite2D = $Sprite
@onready var _halo: Sprite2D = $Halo

var _phase: float = 0.0


func _ready() -> void:
	_phase = randf() * TAU
	_sprite.texture = load(TEXTURES[kind])
	_sprite.modulate = TINTS[kind]
	# Powerups wear a halo so they never read as just another coin.
	_halo.visible = kind != Kind.COIN
	_halo.modulate = TINTS[kind]
	_halo.modulate.a = 0.5


func _process(delta: float) -> void:
	_phase += delta * 3.0
	_sprite.position.y = sin(_phase) * 2.0
	_sprite.scale = Vector2.ONE * (1.0 + 0.12 * sin(_phase * 1.5))
	if _halo.visible:
		_halo.rotation += delta * 1.4
		_halo.scale = Vector2.ONE * (1.1 + 0.15 * sin(_phase))


func value() -> int:
	return VALUES[kind]


func label() -> String:
	return LABELS[kind]
