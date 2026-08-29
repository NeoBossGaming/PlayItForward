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

@onready var _sprite: Sprite2D = $Sprite
@onready var _ripple: Sprite2D = $Ripple

var state: State = State.STABLE
var _timer: float = 0.0
var _duration: float = 0.0
var _shake_seed: float = 0.0
var _respawn_delay: float = 2.2


func _ready() -> void:
	_shake_seed = randf() * TAU
	_ripple.modulate.a = 0.0
	_sprite.scale = Vector2(2.0, 2.0)


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
			# Idle drift so a stable leaf never looks frozen next to a shaking one.
			_sprite.rotation = sin(Time.get_ticks_msec() / 900.0 + _shake_seed) * 0.04
			_sprite.position.y = sin(Time.get_ticks_msec() / 700.0 + _shake_seed) * 0.8


func _process_shaking(delta: float) -> void:
	var progress := clampf(_timer / _duration, 0.0, 1.0)
	# Wobble accelerates as the leaf runs out of time.
	var intensity := lerpf(0.5, 2.6, progress)
	_sprite.rotation = sin(_timer * 26.0 + _shake_seed) * 0.10 * intensity
	_sprite.position.x = sin(_timer * 34.0) * 1.6 * intensity
	_sprite.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.55, 0.45), progress)

	_ripple.modulate.a = 0.25 + 0.45 * progress
	_ripple.scale = Vector2.ONE * lerpf(1.4, 2.6, progress)
	_ripple.rotation += delta * 2.0

	if progress >= 1.0:
		_begin_sinking()


func _process_sinking() -> void:
	var progress := clampf(_timer / SINK_TIME, 0.0, 1.0)
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
	_enter(State.SINKING)
	Audio.sfx(&"splash", 1.35)
	sank.emit(lane)


func _begin_rising() -> void:
	_enter(State.RISING)
	_sprite.visible = true
	_sprite.rotation = 0.0
	_sprite.position = Vector2.ZERO
	_sprite.modulate = Color(1, 1, 1, 0.0)


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
