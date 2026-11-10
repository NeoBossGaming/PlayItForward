class_name RiverHazard
extends Node2D
## Something the river throws at you. Two kinds, and they deliberately want
## opposite reactions -- otherwise every threat collapses into one button
## pressed on a rhythm.
##
##   LOG   -- driftwood sweeping down a lane. Jump and it passes underneath.
##   HERON -- a dive onto a lane. Jumping does NOT save you; get out of the way.
##
## The hazard knows when it is crossing the player's row. It does not know
## whether that is a hit -- wind_leaf.gd owns that, because only it knows where
## the player is and whether they are off the water.

enum Kind { LOG, HERON }

signal spent(hazard: RiverHazard)

const LOG_TEXTURE := preload("res://assets/game/wind_leaf/log.png")
const HERON_TEXTURE := preload("res://assets/game/wind_leaf/heron.png")
const SHADOW_TEXTURE := preload("res://assets/game/wind_leaf/dive_shadow.png")

## How tall the strike window is, in pixels of travel. Generous on purpose: a
## hazard you can only dodge on one exact frame is a coin toss, not a skill.
const STRIKE_BAND := 16.0
## How far the heron falls onto its mark.
const DIVE_FROM := 86.0
const DIVE_TIME := 0.22

var kind: Kind = Kind.LOG
var lane: int = 0
var row_y: float = 174.0
## Pixels per second, for a log. The heron uses `telegraph` instead.
var speed: float = 140.0
## Seconds the heron's shadow grows before it strikes.
var telegraph: float = 0.9

var _sprite: Sprite2D
var _shadow: Sprite2D
var _clock: float = 0.0
var _resolved: bool = false
var _striking: bool = false


func _ready() -> void:
	if kind == Kind.LOG:
		_sprite = Sprite2D.new()
		_sprite.name = "Body"
		_sprite.texture = LOG_TEXTURE
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
	if kind == Kind.LOG:
		_tick_log(delta)
	else:
		_tick_heron(delta)


## True only while this hazard is crossing the player's row.
func is_striking() -> bool:
	return _striking


## A log can be jumped. A dive cannot -- that is the whole difference between
## the two, and the reason jumping in place is worth having as its own verb.
func is_dodgeable_by_jumping() -> bool:
	return kind == Kind.LOG


func mark_resolved() -> void:
	_resolved = true


func _tick_log(delta: float) -> void:
	position.y += speed * delta
	_sprite.rotation = sin(_clock * 1.7) * 0.07
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
