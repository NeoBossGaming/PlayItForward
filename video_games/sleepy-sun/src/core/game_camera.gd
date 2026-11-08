class_name GameCamera
extends Camera2D
## Speed felt rather than seen: a rumble and a slow push-in that both rise
## with whatever the game calls "fast".
##
## Racing games widen the field of view as you accelerate. This zooms IN
## instead, because zooming out would shrink the player -- and the character
## reading too small is a note this project has already had twice.
##
## Everything here is capped low on purpose. The game under it is a precision
## lane hop; a camera that fights the player's aim is worse than no camera.

## Zoom at full speed. Set to 1.0 to turn the push-in off entirely.
##
## Measured cost, rather than assumed: at 480x270 upscaled 3x, no zoom other
## than 1.0 can keep one game pixel on exactly three screen pixels. Sampling
## vertical colour runs, 24% were off the 3x grid with no camera at all (from
## sprites sitting at fractional positions), 32% at zoom 1.0 and 34% at 1.03.
## So it does cost some pixel fidelity -- but it is invisible in a still frame
## at native resolution, and the zoom eases over the whole 62-second crossing,
## so the grid re-lands slowly rather than shimmering. Kept small for that
## reason: the banks creeping a few pixels inward is the whole effect.
@export var max_zoom: float = 1.03
## Peak rumble, in whole pixels. Snapped, so it never introduces the same
## fractional-pixel problem the zoom has to be careful about.
@export var max_shake: float = 1.0
@export var shake_hz: float = 7.0
## How quickly the camera follows a change in intensity. Slow, so the push-in
## is something you notice having happened rather than something you watch.
@export var ease_speed: float = 1.4

var _intensity: float = 0.0
var _target: float = 0.0
var _clock: float = 0.0
var _home: Vector2


func _ready() -> void:
	_home = position
	zoom = Vector2.ONE


## 0 is a standing start, 1 is flat out. Call it every frame; it is eased here.
func set_intensity(value: float) -> void:
	_target = clampf(value, 0.0, 1.0)


func _process(delta: float) -> void:
	_clock += delta
	_intensity = move_toward(_intensity, _target, ease_speed * delta)

	var z := lerpf(1.0, max_zoom, _intensity)
	zoom = Vector2(z, z)

	# Two offset sines rather than one, so the rumble does not read as a
	# tidy oscillation, and rounded so the world never lands on half a pixel.
	var amount := max_shake * _intensity
	var shake := Vector2(
		sin(_clock * shake_hz * TAU) * amount,
		sin(_clock * shake_hz * 1.37 * TAU + 1.1) * amount * 0.7)
	position = _home + shake.round()
