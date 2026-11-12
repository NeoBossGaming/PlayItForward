class_name Faller
extends Node2D
## One thing coming out of the canopy, and the mark on the ground it is coming
## down onto.
##
## The node sits AT the landing spot for its whole life, so "where will this
## hit" is never a calculation -- it is this node's position. The body is a
## child that starts up at the canopy and comes down to meet it.
##
## **The two kinds differ by SHAPE first and colour second.** Danger is an open
## ticked ring, good is a filled disc. Riverleap's dive marker had to be
## redrawn twice to learn that a mark distinguished only by colour is not
## distinguished at all -- not on a scuffed cabinet screen, and not for a
## colourblind player. Checking it in greyscale is the test worth applying.
##
## Draw order is the game's other rule and it is expressed here, once:
##
##   mark (Z_MARK = 4)  --  painted on the clearing, under everything
##   player (20)        --  set by the game
##   body (Z_BODY = 40) --  in the air, over everything
##
## Godot child z_index is RELATIVE: it adds up the parent chain. These two
## numbers are therefore only correct while the container holding fallers sits
## at z 0, which is what tests/acorn_test.gd checks by resolving the chain
## rather than by reading the constants back.

signal landed(faller: Faller)

enum Kind { ACORN, SUNFRUIT }

const Z_MARK := 4
const Z_BODY := 40

## How close the player has to be, in pixels, when it arrives. The two are
## deliberately not equal: a near miss should read as a miss, and a near catch
## should read as a catch. Generous on the good one, tight on the bad one --
## the cabinet should feel fair rather than exacting.
const HIT_RADIUS := 14.0
const CATCH_RADIUS := 18.0

## Where the body starts. The canopy's underside, so everything falls out of
## the leaves rather than out of nowhere -- which also means a thing landing
## at the bottom of the field falls further than one landing at the top, at
## the same speed, and reads as depth for free.
const CANOPY_Y := 58.0

const TEXTURES := {
	Kind.ACORN: preload("res://assets/game/acorn_storm/acorn.png"),
	Kind.SUNFRUIT: preload("res://assets/game/acorn_storm/sunfruit.png"),
}
const MARKS := {
	Kind.ACORN: preload("res://assets/game/acorn_storm/mark_danger.png"),
	Kind.SUNFRUIT: preload("res://assets/game/acorn_storm/mark_good.png"),
}

var kind: Kind = Kind.ACORN
## Seconds from spawn to impact. Set by the game from its difficulty curve;
## it is the single number that decides whether a fruit can be reached.
var fall_seconds: float = 1.5
var life: float = 0.0
var resolved: bool = false

var _mark: Sprite2D
var _body: Sprite2D
var _drop: float = 0.0


func setup(p_kind: Kind, at: Vector2, seconds: float) -> void:
	kind = p_kind
	position = at
	fall_seconds = maxf(seconds, 0.05)
	_drop = maxf(at.y - CANOPY_Y, 40.0)

	_mark = Sprite2D.new()
	_mark.texture = MARKS[kind]
	_mark.z_index = Z_MARK
	add_child(_mark)

	_body = Sprite2D.new()
	_body.texture = TEXTURES[kind]
	_body.z_index = Z_BODY
	_body.position = Vector2(0.0, -_drop)
	add_child(_body)
	_apply(0.0)


## 0 at the canopy, 1 at the ground.
func progress() -> float:
	return clampf(life / fall_seconds, 0.0, 1.0)


func seconds_left() -> float:
	return maxf(fall_seconds - life, 0.0)


func radius() -> float:
	return CATCH_RADIUS if kind == Kind.SUNFRUIT else HIT_RADIUS


func _process(delta: float) -> void:
	if resolved:
		return
	life += delta
	var t := progress()
	_apply(t)
	if t >= 1.0:
		resolved = true
		landed.emit(self)


## Drives the fall by hand, for the opening card -- whose slides loop, and so
## cannot let a faller simply land once and leave an empty picture. The card
## uses REAL fallers rather than drawings of them, so what it teaches cannot
## drift away from what the game does; this is what lets it.
func set_progress(t: float) -> void:
	var clamped := clampf(t, 0.0, 1.0)
	life = clamped * fall_seconds
	_apply(clamped)


func _apply(t: float) -> void:
	# Accelerating, so the last third of the drop is the fast part -- which is
	# also the part the mark has finished warning about.
	_body.position.y = -_drop * (1.0 - t * t)
	_body.scale = Vector2.ONE * lerpf(1.45, 0.9, t)
	_body.rotation = t * (5.5 if kind == Kind.ACORN else 2.2)

	# The ring tightening onto the spot IS the countdown; nothing else on
	# screen says how long is left.
	_mark.scale = Vector2.ONE * lerpf(1.55, 0.72, t)
	# Nearly opaque from the moment it appears. It started at 0.45 and ramped,
	# which put the warning at its FAINTEST exactly when the player needs to
	# see it -- over a green clearing the hot ring came out muddy brown and the
	# gold disc came out a pale sage blob, which is the same failure Riverleap's
	# dive marker had twice. A warning that fades up is a warning that arrives
	# late.
	var base := 0.82 + 0.18 * t
	if kind == Kind.ACORN and t > 0.62:
		# Only the dangerous one flashes, and only once it is nearly here. A
		# mark that strobed for its whole life would be noise rather than a
		# warning.
		base *= 0.74 + 0.26 * sin(life * 42.0)
	_mark.modulate.a = base


## Drops the mark and lets the body carry on for a beat, for a catch or a hit
## that has already been scored.
func clear_mark() -> void:
	if _mark != null:
		_mark.visible = false
