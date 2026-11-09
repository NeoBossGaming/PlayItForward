class_name GameCamera
extends Camera2D
## Speed you feel: a push-in that grows with the current, a very small constant
## tremble, and short bursts when something actually happens.
##
## Widening the field of view -- or equivalently moving the camera closer -- is
## the most reliable way to sell speed, so the push-in is the main effect here.
## Zooming IN rather than out, because zooming out would shrink a character
## that has twice been called too small.
##
## The shake is the part that went wrong before. It was +/-1 GAME pixel at 7Hz
## and rounded, so at 3x screen scale it snapped three screen pixels at a time,
## dozens of times a second, over the whole world: an earthquake, not a rumble.
## Two things fix it. A third of a game pixel is exactly one screen pixel, so
## working in fractions of a game pixel gives the one-to-two screen pixels a
## light shake is supposed to be -- which means never rounding. And a constant
## sine is the wrong shape anyway: shake reads as impact, so most of it now
## comes in bursts that decay, and only a trace of it is continuous.

## Zoom at full speed. 1.0 turns the push-in off.
##
## Measured cost, rather than assumed: at 480x270 upscaled 3x, no zoom other
## than 1.0 keeps one game pixel on exactly three screen pixels. Sampling
## vertical colour runs, 24% were off the 3x grid with no camera at all (from
## sprites at fractional positions), 32% at zoom 1.0 and 34% at 1.03.
@export var max_zoom: float = 1.06

## Scales everything that shakes. 0.0 is a clean, still camera -- worth having
## as one number, because constant shake is a real accessibility problem.
@export_range(0.0, 2.0) var shake_scale: float = 1.0
## The always-on tremble at full speed, in game pixels. 0.4 is a bit over one
## screen pixel; the research figure for a light shake is one to two.
@export var speed_shake: float = 0.4
## Ceiling for an event burst, in game pixels.
@export var burst_shake: float = 1.3
## Seconds for a burst to fall away. Short on purpose -- a hit, not a wobble.
@export var burst_decay: float = 0.12
@export var ease_speed: float = 1.4

var _intensity: float = 0.0
var _target: float = 0.0
var _trauma: float = 0.0
var _clock: float = 0.0
var _home: Vector2


func _ready() -> void:
	_home = position
	zoom = Vector2.ONE


## 0 is a standing start, 1 is flat out. Call every frame; it is eased here.
func set_intensity(value: float) -> void:
	_target = clampf(value, 0.0, 1.0)


## A thing happened. 0.3 is a footstep, 1.0 is going in the water.
func kick(amount: float = 0.5) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	_intensity = move_toward(_intensity, _target, ease_speed * delta)
	_trauma = maxf(_trauma - delta / maxf(burst_decay, 0.01), 0.0)

	var z := lerpf(1.0, max_zoom, _intensity)
	zoom = Vector2(z, z)

	# Squaring the trauma is the usual trick: a burst falls off fast at first,
	# so it reads as an impact rather than as a fade.
	var amount := (speed_shake * _intensity + burst_shake * _trauma * _trauma) \
			* shake_scale
	if amount <= 0.0:
		position = _home
		return

	# Two detuned sines so it never settles into a tidy oscillation, and
	# deliberately NOT rounded: fractions of a game pixel are what keep this a
	# tremble instead of a jolt.
	position = _home + Vector2(
		sin(_clock * 2.7 * TAU) * amount,
		sin(_clock * 3.9 * TAU + 1.1) * amount * 0.75)
