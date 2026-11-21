class_name Golden
extends RefCounted
## The rare one. A prize that turns up in roughly one run in five, in every
## game, and is counted when it is caught.
##
## What it is FOR is not decided yet -- Neo asked for the thing first and the
## meaning later. So this deliberately does nothing but appear, feel enormous,
## and increment a number that `Save` keeps. Nothing branches on it.
##
## Shared because both games want the same rule and six more are coming, and
## because "one run in five" has to mean the same thing in all of them. Each
## game supplies only the sprite and how the thing travels: a chime drifting
## down the river, a ball falling out of a canopy.

const SPARK := preload("res://assets/game/decor/spark.png")

## Chance that a run contains one at all. The target is **about one run in
## ten ending with one in your hands.**
##
## It sat at 0.34 for a round, tuned against bot runs that collected under
## half of what they were offered. That was the wrong instrument: a person who
## sees SOMETHING BRIGHT and a glowing ball goes and gets it, so a human
## converts nearly every offer, and Neo caught one on his first run. Bots
## under-collect, which makes them useless for calibrating a reward whose
## whole appeal is that a player will always chase it.
##
## So this is now set close to the rate it is meant to produce, with only a
## small allowance for runs that end before the prize is due.
const CHANCE := 0.13

## When in a run it may appear, in seconds of play. Starts after the opening
## so it is never the first thing a new player meets, and ends early enough
## that an ordinary run reaches it -- a window placed past the average run
## length would make the prize a reward for being good rather than lucky,
## which is the opposite of the point.
## Narrower than it was, because runs are much shorter now: a prize due at
## 65s in a game whose ordinary run is 60-90s is one that frequently never
## happens at all, which reads as the feature being broken rather than rare.
const WINDOW := Vector2(14.0, 45.0)


## The play-time this run's prize should appear at, or -1 for "not this run".
## Called once, at begin().
static func roll() -> float:
	if randf() >= CHANCE:
		return -1.0
	return randf_range(WINDOW.x, WINDOW.y)


## Everything that happens the moment one is caught: a white flash, a burst of
## sparks at the pickup, a camera kick and a rising three-note fanfare.
##
## Deliberately louder than anything else either game does. It is rare enough
## that most players will never see it twice, so the one time they do has to
## be unmistakable -- the ordinary pickup cues are a single tone and a small
## pop, and this must not read as one of those.
static func celebrate(host: Node, at: Vector2, camera: GameCamera = null) -> void:
	_flash(host)
	_sparks(host, at)
	if camera != null:
		camera.kick(1.0)
	fanfare(host)


## Three rising notes from one entry in the bank, spaced by a tween rather
## than by three cues -- the same trick the countdown uses for 3-2-1.
static func fanfare(host: Node) -> void:
	Audio.sfx(&"golden", 1.0)
	var tween := host.create_tween()
	tween.tween_interval(0.10)
	tween.tween_callback(func() -> void: Audio.sfx(&"golden", 1.26))
	tween.tween_interval(0.10)
	tween.tween_callback(func() -> void: Audio.sfx(&"golden", 1.5))
	tween.tween_interval(0.14)
	tween.tween_callback(func() -> void: Audio.sfx(&"chime", 1.6))


## A white wash over the whole screen, on its own layer so it covers the HUD
## too and does not care where the camera is looking.
static func _flash(host: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 70
	host.add_child(layer)
	var wash := ColorRect.new()
	wash.color = Color(1, 0.98, 0.9, 0.0)
	wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(wash)

	var tween := host.create_tween()
	tween.tween_property(wash, "color:a", 0.55, 0.05)
	tween.tween_property(wash, "color:a", 0.0, 0.38)
	tween.tween_callback(layer.queue_free)


## Sparks thrown outward from the pickup, in the world rather than on a layer,
## so they stay where it happened.
static func _sparks(host: Node, at: Vector2) -> void:
	var root := Node2D.new()
	root.z_index = 60
	host.add_child(root)
	for i in 16:
		var spark := Sprite2D.new()
		spark.texture = SPARK
		spark.position = at
		spark.scale = Vector2.ONE * randf_range(0.8, 2.2)
		spark.modulate = Color(1, 0.96, 0.78)
		root.add_child(spark)
		var away := Vector2.RIGHT.rotated(randf() * TAU) * randf_range(26.0, 74.0)
		var tween := host.create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", at + away, 0.5) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.5)
		tween.tween_property(spark, "scale", Vector2.ZERO, 0.5)
	var cleanup := host.create_tween()
	cleanup.tween_interval(0.6)
	cleanup.tween_callback(root.queue_free)


## A spark shed while the prize is still travelling, so it is visibly special
## before it is caught rather than only after.
static func trail(host: Node2D, at: Vector2) -> void:
	var spark := Sprite2D.new()
	spark.texture = SPARK
	spark.position = at + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	spark.z_index = 1
	spark.modulate = Color(1, 0.94, 0.72, 0.9)
	host.add_child(spark)
	var tween := host.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spark, "modulate:a", 0.0, 0.45)
	tween.tween_property(spark, "scale", Vector2(0.2, 0.2), 0.45)
	tween.chain().tween_callback(spark.queue_free)
