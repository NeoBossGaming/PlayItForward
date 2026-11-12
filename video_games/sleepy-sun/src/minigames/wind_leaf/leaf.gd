class_name RiverLeaf
extends Node2D
## One lily pad in Riverleap.
##
## The shake is the whole game: it is the only warning the player gets, so it
## has to be unmistakable at a glance from across a room. Hence a rotation
## wobble AND a colour shift AND a widening ripple -- three redundant cues, so
## it still reads on a scuffed cabinet screen or to a colourblind player.

signal sank(lane: int)

enum State { STABLE, SHAKING, SINKING, GONE, RISING }

const SINK_TIME := 0.30
const RISE_TIME := 0.45

@export var lane: int = 0

## Where this pad sits in the swell. Set from the lane so the five pads bob in
## sequence and the eye reads one wave crossing the river, rather than five
## pads twitching on their own timers -- which is what a random phase gave.
var wave_phase: float = 0.0
## Radians per second of that swell. The game raises it with the current.
var wave_speed: float = 2.0

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _ripple: Sprite2D = $Ripple

var state: State = State.STABLE
var _timer: float = 0.0
var _duration: float = 0.0
var _shake_seed: float = 0.0
var _respawn_delay: float = 2.2


## How much faster the float cycle runs while the pad is about to go under.
## The animation speeding up is a fourth warning cue alongside the wobble, the
## colour shift and the ripple -- redundant on purpose, because this is the
## only thing the game ever asks the player to read in a hurry.
const SHAKE_ANIM_SCALE := 3.2


func _ready() -> void:
	_shake_seed = randf() * TAU
	_ripple.modulate.a = 0.0
	_sprite.scale = Vector2(2.0, 2.0)
	# Pads all drawing the same frame at the same instant reads as one object
	# repeated five times; an offset start reads as five pads.
	_sprite.play(&"float")
	_sprite.frame = randi() % 4


func _process(delta: float) -> void:
	_timer += delta
	match state:
		State.SHAKING:
			_process_shaking(delta)
		State.SINKING:
			_process_sinking()
		State.GONE:
			if _timer >= _respawn_delay:
				_begin_rising()
		State.RISING:
			_process_rising()
		State.STABLE:
			_ride_the_swell()


## A pad afloat is never still. Vertical bob, a little sway and a slow roll,
## all on one phase -- so when the five lanes are given phases a fifth of a
## cycle apart, the swell visibly travels across the river.
func _ride_the_swell() -> void:
	var t := wave_phase + Time.get_ticks_msec() / 1000.0 * wave_speed
	_sprite.position.y = sin(t) * 3.0
	_sprite.position.x = sin(t * 0.5) * 1.4
	_sprite.rotation = sin(t + 0.6) * 0.05


## The pad coming apart under you. This is the only thing the game ever asks
## the player to read in a hurry, so it is deliberately over-played: the old
## version topped out at about 15 degrees of roll and four pixels of sway,
## which read as a loose floor tile rather than as something being taken by the
## river.
##
## The vertical judder is the addition that changes its character. Without it
## the pad only ever moved side to side, and side-to-side is what *rattling*
## looks like; a thing being pulled under moves down as well, and fights it.
func _process_shaking(delta: float) -> void:
	var progress := clampf(_timer / _duration, 0.0, 1.0)
	# Wobble accelerates as the leaf runs out of time.
	var intensity := lerpf(0.6, 3.1, progress)
	_sprite.rotation = sin(_timer * 30.0 + _shake_seed) * 0.17 * intensity
	_sprite.position.x = sin(_timer * 38.0) * 3.1 * intensity
	# Detuned against the sway so the two never lock into a tidy circle, and
	# biased downward -- it is being dragged under, not bounced.
	_sprite.position.y = sin(_timer * 25.0 + 1.3) * 1.9 * intensity \
			+ progress * 1.6
	# Dipping and recovering, losing the fight by degrees.
	var dip := 1.0 - 0.09 * progress * (0.5 + 0.5 * sin(_timer * 21.0))
	_sprite.scale = Vector2(2.0 * dip, 2.0 * dip)
	# Red above 1.0 on purpose. modulate MULTIPLIES, and the pad is green -- so
	# a tint of (1.0, 0.4, 0.3) cannot make it red, it can only make it dark
	# olive. Pushing the red channel past 1 actually lifts what little red the
	# pad has, so it goes warm rather than merely dim. "Shifts toward red" is
	# one of the four warning cues and it should be true.
	_sprite.modulate = Color(1, 1, 1).lerp(Color(1.45, 0.45, 0.34), progress)

	_ripple.modulate.a = 0.3 + 0.6 * progress
	_ripple.scale = Vector2.ONE * lerpf(1.4, 3.4, progress)
	_ripple.rotation += delta * 2.0
	_sprite.speed_scale = lerpf(1.0, SHAKE_ANIM_SCALE, progress)

	if progress >= 1.0:
		_begin_sinking()


## How hard this pad is shaking right now, 0 when it is not. The player reads
## this to sway with it -- a pad thrashing under a character standing perfectly
## still reads as two unrelated objects sharing a screen.
func shake_amount() -> float:
	if state != State.SHAKING:
		return 0.0
	return clampf(_timer / _duration, 0.0, 1.0)


func _process_sinking() -> void:
	var progress := clampf(_timer / SINK_TIME, 0.0, 1.0)
	if _sprite.animation != &"sink":
		_sprite.speed_scale = 1.0
		_sprite.play(&"sink")
	_sprite.scale = Vector2.ONE * lerpf(2.0, 1.2, progress)
	_sprite.modulate.a = 1.0 - progress
	_ripple.modulate.a = (1.0 - progress) * 0.5
	if progress >= 1.0:
		_enter(State.GONE)
		_sprite.visible = false
		_ripple.modulate.a = 0.0


func _process_rising() -> void:
	var progress := clampf(_timer / RISE_TIME, 0.0, 1.0)
	_sprite.scale = Vector2.ONE * lerpf(1.2, 2.0, progress)
	_sprite.modulate = Color(1, 1, 1, progress)
	if progress >= 1.0:
		_enter(State.STABLE)
		_sprite.scale = Vector2(2.0, 2.0)
		_sprite.modulate = Color.WHITE


func _begin_sinking() -> void:
	_sprite.scale = Vector2(2.0, 2.0)
	_sprite.position = Vector2.ZERO
	_enter(State.SINKING)
	Audio.sfx(&"splash", 1.35)
	sank.emit(lane)


func _begin_rising() -> void:
	_enter(State.RISING)
	_sprite.visible = true
	_sprite.rotation = 0.0
	_sprite.position = Vector2.ZERO
	_sprite.modulate = Color(1, 1, 1, 0.0)
	_sprite.speed_scale = 1.0
	_sprite.play(&"float")


func _enter(new_state: State) -> void:
	state = new_state
	_timer = 0.0


## Begins the warning. `telegraph` is how long the player has to get clear.
func start_shake(telegraph: float, respawn_delay: float) -> void:
	if state != State.STABLE:
		return
	_duration = maxf(telegraph, 0.15)
	_respawn_delay = respawn_delay
	_enter(State.SHAKING)
	Audio.sfx(&"shake", randf_range(0.9, 1.1))


## True while the leaf can still be stood on. A shaking leaf still holds you --
## that is the tension. Once it starts sinking it does not.
func is_standable() -> bool:
	return state == State.STABLE or state == State.SHAKING or state == State.RISING


## True if landing here is not about to drop you in the water.
func is_safe() -> bool:
	return state == State.STABLE or state == State.RISING


func is_available() -> bool:
	return state != State.SINKING and state != State.GONE
