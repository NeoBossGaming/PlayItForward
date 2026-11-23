class_name MeadowPatch
extends Node2D
## One stand of tall grass: the only place in Hush Meadow you are not visible.
##
## A patch is built from several overlapping clumps over one soft dark disc.
## The disc is what makes the patch read as a PLACE rather than as decoration;
## blades over green do not, which the parked version of this game learned and
## then borrowed a glow sprite to fix.
##
## The one rule this file exists to hold:
##
##     the concealment rect is never smaller than what is drawn.
##
## Anywhere that looks like cover has to BE cover. The other way round is a
## game that lies to the player at the only moment it matters -- stepping into
## grass with a beak coming and finding out the edge was decoration. So the
## clumps are placed inside SPREAD and the rect is PATCH_HALF, which is
## deliberately the larger of the two, and hush_test.gd asserts it stays that
## way rather than trusting these two numbers to be edited together.

## Half-extent of the rect that actually hides you.
const PATCH_HALF := Vector2(34.0, 30.0)
## How far from the centre a clump may be planted. Plus the clump's own half
## width (14) and half height (17, drawn DRAW_LIFT high of its offset) this
## stays inside PATCH_HALF.
##
## The first numbers here did not: grass was drawn 32px above centre while the
## rect only hid 26, so six pixels of what looked like cover was decoration.
## hush_test.gd caught it, which is the entire reason that check is written
## against the sprite's real size rather than against these constants.
const SPREAD := Vector2(18.0, 7.0)
const CLUMPS := Vector2i(7, 10)
const DRAW_LIFT := 4.0

## Blades draw OVER the player, which is what makes standing in grass look
## like standing in grass. Relative to this node; see the z map in
## hush_meadow.gd.
const Z_BLADES := 0
const Z_COVER := -12

const COVER_TINT := Color(0.09, 0.20, 0.10, 0.58)
## Cool, towards the dew's own blue-white, and clearly not the prize's gold.
const DEW_TINT := Color(0.72, 0.93, 1.00, 0.80)
const PRIZE_TINT := Color(1.00, 0.86, 0.42, 0.90)
## Over the blades, so the mote is seen from outside the patch. That is the
## entire point of it.
const Z_MOTE := 4

var _disc: Sprite2D = null
var _glow: Tween = null
var _mote: Sprite2D = null

static var _glint: Texture2D = preload("res://assets/game/hush_meadow/mote.png")
static var _cover: Texture2D = preload("res://assets/game/hush_meadow/grass_cover.png")
static var _clumps: Array[Texture2D] = [
	preload("res://assets/game/hush_meadow/grass_0.png"),
	preload("res://assets/game/hush_meadow/grass_1.png"),
	preload("res://assets/game/hush_meadow/grass_2.png"),
]


## Built in code rather than from a scene: a patch is a random arrangement, so
## there is no fixed tree for a .tscn to hold.
static func build(rng: RandomNumberGenerator, at: Vector2) -> MeadowPatch:
	var patch := MeadowPatch.new()
	patch.position = at

	var disc := Sprite2D.new()
	disc.texture = _cover
	disc.modulate = COVER_TINT
	disc.z_index = Z_COVER
	patch.add_child(disc)
	patch._disc = disc

	# Planted back to front, so a clump nearer the bottom of the screen draws
	# over one behind it and the stand reads as having depth.
	var offsets: Array[Vector2] = []
	for i in rng.randi_range(CLUMPS.x, CLUMPS.y):
		offsets.append(Vector2(
			rng.randf_range(-SPREAD.x, SPREAD.x),
			rng.randf_range(-SPREAD.y, SPREAD.y)))
	offsets.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)

	for offset in offsets:
		var clump := Sprite2D.new()
		clump.texture = _clumps[rng.randi() % _clumps.size()]
		clump.position = offset - Vector2(0.0, DRAW_LIFT)
		clump.z_index = Z_BLADES
		patch.add_child(clump)

	return patch


## World-space rect that conceals the player.
func rect() -> Rect2:
	return Rect2(position - PATCH_HALF, PATCH_HALF * 2.0)


func hides(point: Vector2) -> bool:
	return rect().has_point(point)


## Seconds before this patch has scrolled off the bottom of the play field and
## stops being cover at all. The number the whole "can the player still get to
## cover" guarantee is built on, so it lives here rather than being recomputed
## by every caller.
func life_left(scroll_speed: float, bottom: float) -> float:
	if scroll_speed <= 0.0:
		return INF
	return maxf((bottom - position.y) / scroll_speed, 0.0)


## A patch holding dew shimmers, faintly and coolly.
##
## Without this the game has no foraging in it. Dew is invisible until you are
## inside the patch, so if nothing marks which patch is worth entering there is
## no way to CHOOSE one -- and since the meadow carries fresh cover to you
## anyway, the best play is to stand still and let it arrive. Measured exactly
## that way: a bot that only ever hid outlived one that worked the meadow,
## 72s to 64s, which is the safe corner this whole design exists to avoid.
##
## What it shows is that there is something here, never what. Walking in is
## still the only way to find out, so the reveal keeps its moment.
func mark_dew() -> void:
	_shimmer(DEW_TINT, 1.1)


## The same idea in gold, for the rare one. "Something bright appeared and I
## could not find it" is the same non-event as never seeing one at all.
func mark_prize() -> void:
	_shimmer(PRIZE_TINT, 0.55)


## Back to ordinary grass once whatever it was holding has been taken.
func clear_mark() -> void:
	if _glow != null and _glow.is_valid():
		_glow.kill()
	_glow = null
	if _mote != null:
		_mote.queue_free()
		_mote = null


## A mote over the stand, not a tint on the cover disc underneath it.
##
## The first version shaded the disc, and the disc lies under thirty-odd
## blades at 58% alpha on dark green: on a real frame there was no telling a
## patch holding dew from one that was not, which makes the choice the whole
## forage loop rests on invisible. A small bright thing ABOVE the grass reads
## from across the meadow, which is the job.
func _shimmer(tint: Color, period: float) -> void:
	if _mote == null:
		_mote = Sprite2D.new()
		_mote.texture = _glint
		_mote.z_index = Z_MOTE
		_mote.position = Vector2(0.0, -PATCH_HALF.y * 0.72)
		add_child(_mote)
	_mote.modulate = tint
	if _glow != null and _glow.is_valid():
		_glow.kill()
	_glow = create_tween().set_loops()
	_glow.tween_property(_mote, "scale", Vector2(1.25, 1.25), period) \
			.set_trans(Tween.TRANS_SINE)
	_glow.parallel().tween_property(_mote, "modulate:a", 1.0, period)
	_glow.tween_property(_mote, "scale", Vector2(0.7, 0.7), period) \
			.set_trans(Tween.TRANS_SINE)
	_glow.parallel().tween_property(_mote, "modulate:a", 0.45, period)
