class_name RiverHazard
extends Node2D
## Something that comes at you over the river. Two kinds, and they deliberately
## want opposite reactions -- otherwise every threat collapses into one button
## pressed on a rhythm.
##
##   HORNET -- flies down a lane at you. Jump and it passes underneath.
##   HERON  -- a dive onto a lane. Jumping does NOT save you; get out of the way.
##
## **Both of them fly, and that is load-bearing.** The jumpable hazard used to
## be a driftwood log sweeping down the lane, which meant a solid object
## passing straight over the lily pads: nonsense to look at, and a constant
## fight over draw order. Nothing in the air touches the pads, so the ordering
## stops being a problem to manage and becomes the statement of the rule --
## jump and you are drawn above it, stay down and it is drawn above you.
##
## The hazard knows when it is crossing the player's row. It does not know
## whether that is a hit -- wind_leaf.gd owns that, because only it knows where
## the player is and whether they are off the water.

enum Kind { HORNET, HERON }

signal spent(hazard: RiverHazard)

const HORNET_TEXTURE := preload("res://assets/game/wind_leaf/hornet.png")
const HERON_TEXTURE := preload("res://assets/game/wind_leaf/heron.png")
const SHADOW_TEXTURE := preload("res://assets/game/wind_leaf/dive_shadow.png")

## How tall the strike window is, in pixels of travel. Generous on purpose: a
## hazard you can only dodge on one exact frame is a coin toss, not a skill.
const STRIKE_BAND := 16.0
## How far the heron falls onto its mark.
const DIVE_FROM := 86.0
const DIVE_TIME := 0.22

var kind: Kind = Kind.HORNET
var lane: int = 0
## Where the player's row sits. Always set by the spawner from wind_leaf.gd's
## ROW_Y; this default only matters if something instances a hazard directly.
var row_y: float = 206.0
## Pixels per second, for a hornet. The heron uses `telegraph` instead.
##
## A hornet flies, so this is ITS airspeed and has nothing to do with how fast
## the river is running. That is not a detail: tying it to the current meant
## that once the river reached 480 px/s the hornet arrived in about a third of
## a second, which is less warning than a person can act on. Something in the
## air has no reason to care how fast the water moves, so the warning stays
## inside human reaction time however wild the river gets.
var speed: float = 300.0
## Seconds the heron's shadow grows before it strikes.
var telegraph: float = 0.9

var _sprite: Sprite2D
var _shadow: Sprite2D
var _lane_x: float = 0.0
var _clock: float = 0.0
var _resolved: bool = false
var _striking: bool = false


func _ready() -> void:
	_lane_x = position.x
	if kind == Kind.HORNET:
		_sprite = Sprite2D.new()
		_sprite.name = "Body"
		_sprite.texture = HORNET_TEXTURE
		add_child(_sprite)
	else:
		_shadow = Sprite2D.new()
		_shadow.name = "Warning"
		_shadow.texture = SHADOW_TEXTURE
		_shadow.position = Vector2(0.0, row_y - position.y)
		_shadow.scale = Vector2(0.3, 0.3)
		_shadow.modulate = Color(1, 1, 1, 0.0)
		add_child(_shadow)

		_sprite = Sprite2D.new()
		_sprite.name = "Body"
		_sprite.texture = HERON_TEXTURE
		_sprite.position = Vector2(0.0, row_y - position.y - DIVE_FROM)
		_sprite.modulate = Color(1, 1, 1, 0.0)
		add_child(_sprite)


func _process(delta: float) -> void:
	_clock += delta
	if kind == Kind.HORNET:
		_tick_hornet(delta)
	else:
		_tick_heron(delta)


## True only while this hazard is crossing the player's row.
func is_striking() -> bool:
	return _striking


## A hornet can be jumped. A dive cannot -- that is the whole difference
## between the two, and the reason jumping in place is worth having as a verb.
func is_dodgeable_by_jumping() -> bool:
	return kind == Kind.HORNET


func mark_resolved() -> void:
	_resolved = true


func _tick_hornet(delta: float) -> void:
	position.y += speed * delta
	# A weave rather than a wobble. An insect holding a dead straight line
	# reads as a thrown object; the drift is what makes it alive, and it is
	# small enough not to change which lane it is in.
	position.x = _lane_x + sin(_clock * 11.0) * 2.5
	_sprite.rotation = sin(_clock * 9.0) * 0.12
	# Wingbeat: too fast to resolve, which is the point -- it reads as a blur.
	_sprite.scale.x = 1.0 + sin(_clock * 46.0) * 0.12
	_striking = not _resolved and absf(position.y - row_y) <= STRIKE_BAND
	if position.y > row_y + 140.0:
		spent.emit(self)
		queue_free()


func _tick_heron(_delta: float) -> void:
	if _clock < telegraph:
		# The warning: a mark that tightens on the spot and pulses while it
		# does. It starts at 0.7 alpha rather than fading up from nothing --
		# the first third of a half-second telegraph is most of the reaction
		# time available, and spending it invisible wastes it.
		#
		# The pulse is not decoration. A static mark competes with a river full
		# of drifting glints; something blinking at 9 Hz does not.
		var t := _clock / telegraph
		_shadow.scale = Vector2.ONE * lerpf(1.5, 0.75, t)
		_shadow.modulate.a = lerpf(0.70, 1.0, t) \
				* (0.82 + 0.18 * sin(_clock * 56.0))
		return

	var fall := clampf((_clock - telegraph) / DIVE_TIME, 0.0, 1.0)
	_sprite.modulate.a = 1.0
	_sprite.position.y = row_y - position.y - DIVE_FROM * (1.0 - fall)
	_shadow.modulate.a = 0.95 * (1.0 - fall)
	_striking = not _resolved and fall >= 1.0

	if _clock > telegraph + DIVE_TIME + 0.45:
		spent.emit(self)
		queue_free()
