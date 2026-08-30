class_name PatrolBird
extends Node2D
## A patrolling bird with a visible cone of sight.
##
## The cone is drawn, not implied. A stealth game where the player has to guess
## what the guard can see is a frustrating stealth game, and on an arcade
## cabinet nobody has the patience to learn it by dying. So the cone is on
## screen, and it changes colour as suspicion builds: white -> amber -> red.
##
## Detection is a slow fill rather than a trip-wire, which gives the player the
## half second they need to duck into the grass.

signal spotted_player

const VISION_RANGE := 78.0
const VISION_HALF_ANGLE := 0.58    ## radians, ~33 degrees
## Full suspicion in ~0.31s. Being seen is a mistake, not a negotiation.
const ALERT_RISE := 3.2
const ALERT_FALL := 0.9
const INVESTIGATE_SECONDS := 2.6
## How close counts as arrived. Below this the bird holds position and holds
## facing -- see _move().
const ARRIVE_RADIUS := 6.0

const COLOR_CALM := Color(1, 1, 1, 0.13)
const COLOR_SUSPICIOUS := Color(1, 0.78, 0.35, 0.22)
const COLOR_ALARMED := Color(1, 0.35, 0.3, 0.32)

@export var speed: float = 42.0
@export var waypoints: PackedVector2Array = PackedVector2Array()

## Set by the minigame: takes the bird's global position and returns whether the
## player is actually visible from there (concealment and cover both applied).
var can_see: Callable = func(_from: Vector2, _facing: Vector2) -> bool: return false

var alert: float = 0.0
var facing: Vector2 = Vector2.RIGHT

@onready var _cone: Polygon2D = $Cone
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _mark: Label = $Mark

var _index: int = 0
var _pause: float = 0.0
var _investigating: float = 0.0
var _investigate_point: Vector2 = Vector2.ZERO
var _enabled: bool = true


func _ready() -> void:
	_cone.polygon = _build_cone()
	_cone.color = COLOR_CALM
	_mark.text = ""
	_sprite.play(&"fly")
	if waypoints.size() > 0:
		global_position = waypoints[0]


func _physics_process(delta: float) -> void:
	if not _enabled:
		return
	_move(delta)
	_look(delta)
	_paint()


func _move(delta: float) -> void:
	var goal: Vector2
	if _investigating > 0.0:
		_investigating -= delta
		goal = _investigate_point
		# Arrived: hover here and keep looking the way we came. Previously this
		# only shortened the timer and then fell through to the movement code
		# below, where direction_to() on a near-zero distance returns a unit
		# vector built from floating-point residue -- so facing, and the vision
		# cone with it, flipped every single frame. That was the twitch.
		if global_position.distance_to(goal) <= ARRIVE_RADIUS:
			_investigating = minf(_investigating, 0.6)
			_apply_facing()
			return
	elif waypoints.size() < 2:
		return
	else:
		if _pause > 0.0:
			_pause -= delta
			return
		goal = waypoints[_index]
		if global_position.distance_to(goal) <= ARRIVE_RADIUS:
			_index = (_index + 1) % waypoints.size()
			_pause = 0.5
			return

	# move_toward rather than a raw step, so a fast bird cannot overshoot the
	# goal and spend the next frame turning around to come back.
	var previous := global_position
	global_position = global_position.move_toward(goal, speed * delta)
	var travelled := global_position - previous
	if travelled.length_squared() > 0.0001:
		facing = travelled.normalized()
	_apply_facing()


func _apply_facing() -> void:
	# The sprite is drawn nose-up, so rotate from -Y.
	_sprite.rotation = facing.angle() + PI * 0.5
	_cone.rotation = facing.angle() + PI * 0.5


func _look(delta: float) -> void:
	var seen: bool = can_see.call(global_position, facing)
	if seen:
		alert = minf(alert + ALERT_RISE * delta, 1.0)
		if alert >= 1.0:
			_raise_alarm()
	else:
		alert = maxf(alert - ALERT_FALL * delta, 0.0)


func _paint() -> void:
	if alert < 0.35:
		_cone.color = COLOR_CALM
		_mark.text = ""
	elif alert < 0.99:
		_cone.color = COLOR_CALM.lerp(COLOR_SUSPICIOUS, (alert - 0.35) / 0.64)
		_mark.text = "?"
		_mark.modulate = Color(1, 0.85, 0.4)
	else:
		_cone.color = COLOR_ALARMED
		_mark.text = "!"
		_mark.modulate = Color(1, 0.4, 0.35)
	_sprite.speed_scale = lerpf(1.0, 2.0, alert)


func _raise_alarm() -> void:
	_enabled = false
	spotted_player.emit()


## Called when the player sprints nearby: the bird breaks patrol to come and
## look. Sprinting is fast but it is not free.
func investigate(point: Vector2) -> void:
	if _investigating > 0.0 or alert >= 1.0:
		return
	_investigate_point = point
	_investigating = INVESTIGATE_SECONDS
	alert = maxf(alert, 0.4)


func reset() -> void:
	alert = 0.0
	_investigating = 0.0
	_enabled = true
	_mark.text = ""
	_cone.color = COLOR_CALM


func sees_point(point: Vector2) -> bool:
	var to_point := point - global_position
	if to_point.length() > VISION_RANGE:
		return false
	return absf(facing.angle_to(to_point)) <= VISION_HALF_ANGLE


static func _build_cone() -> PackedVector2Array:
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 10
	for i in steps + 1:
		var angle := lerpf(-VISION_HALF_ANGLE, VISION_HALF_ANGLE, float(i) / steps)
		# Built pointing up (-Y) so the node rotation matches the sprite.
		points.append(Vector2(sin(angle), -cos(angle)) * VISION_RANGE)
	return points
