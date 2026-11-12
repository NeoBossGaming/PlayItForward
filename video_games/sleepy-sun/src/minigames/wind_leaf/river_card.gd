class_name RiverCard
extends StartCard
## Riverleap's opening lesson: the controls, the pads going under, and the two
## things that come at you.
##
## The hazard slides are here because a player should recognise a hornet and a
## heron the first time they see one rather than learning by losing a life --
## but each is still ALSO taught in play, by a prompt the first time it
## actually appears, because a hornet turns up 35s after this card is gone and
## a heron more than a minute after that.

const HORNET := preload("res://assets/game/wind_leaf/hornet.png")
const HERON := preload("res://assets/game/wind_leaf/heron.png")
const RING := preload("res://assets/game/wind_leaf/dive_shadow.png")
## The slides use the REAL pad, not a drawing of one. Its shake, its colour
## shift and its ripple are the lesson, and a picture of them would be free to
## drift away from what the game actually does.
const LEAF := preload("res://src/minigames/wind_leaf/leaf.tscn")


func slide_count() -> int:
	return 4


func build_slide(index: int) -> void:
	match index:
		0: _slide_controls()
		1: _slide_pads()
		2: _slide_hornet()
		3: _slide_heron()


func _pad(at: Vector2) -> RiverLeaf:
	var leaf: RiverLeaf = LEAF.instantiate()
	leaf.position = at
	art(leaf)
	return leaf


## 1. The two verbs. Both up at once and looping, because a slide is glanced
## at rather than watched, and whatever is on screen at that moment has to be
## the whole picture.
func _slide_controls() -> void:
	slide_title("RIVERLEAP", "ride the river. do not stop.")
	build_row(84.0, false, "PRESS", "jump on the spot", &"jump_up")
	build_row(142.0, true, "HOLD  +  PRESS", "hop across", &"jump_right")


## 2. What the pads do. A REAL pad, shaking and going under on a loop, with
## the character stepping off it in time -- the shake, the colour shift and
## the ripple are the lesson, and a drawing of them could drift from the game.
func _slide_pads() -> void:
	slide_title("THE PADS SINK", "it shakes first. hop off before it goes.")
	var doomed := _pad(Vector2(190, 132))
	var safe := _pad(Vector2(290, 132))
	var who := figure(Vector2(190, 128), &"jump_right")

	_slide_tick = func(_t: float) -> void:
		if not is_instance_valid(doomed) or not is_instance_valid(who):
			return
		# Only start the next shake once she is actually back on it, or the
		# loop restarts under her feet and she never settles anywhere.
		if doomed.state == RiverLeaf.State.STABLE \
				and absf(who.position.x - doomed.position.x) < 2.0:
			doomed.start_shake(1.1, 0.7)
		# Away for the whole of the pad's life, not just while it shakes.
		# Keyed on shake_amount() alone she walked back the instant it sank --
		# because a sunken pad is not shaking -- and stood on open water.
		var fleeing := doomed.state != RiverLeaf.State.STABLE
		var want := safe.position.x if fleeing else doomed.position.x
		who.position.x = move_toward(who.position.x, want, 260.0 * get_process_delta_time())
		var airborne := absf(who.position.x - want) > 2.0
		pose(who, 1 if airborne else 0)
		who.position.y = 128.0 - (8.0 if airborne else 0.0)


## 3. The hornet, flying straight down a lane at you.
func _slide_hornet() -> void:
	slide_title("HORNET", "JUMP it. you pass over the top.")
	var _pad_under := _pad(Vector2(240, 140))
	# The hornet goes in BEFORE her, so she is drawn over it -- which is the
	# rule the slide is teaching. Added after, it passed across her face and
	# the picture said the opposite of the caption.
	var bug := Sprite2D.new()
	bug.texture = HORNET
	bug.position = Vector2(240, 40)
	art(bug)
	var who := figure(Vector2(240, 136), &"jump_up")

	_slide_tick = func(t: float) -> void:
		if not is_instance_valid(bug) or not is_instance_valid(who):
			return
		var cycle := fmod(t, 2.0) / 2.0
		bug.position.y = lerpf(40.0, 210.0, cycle)
		bug.position.x = 240.0 + sin(t * 11.0) * 2.0
		bug.scale.x = 1.0 + sin(t * 46.0) * 0.12
		# Up while it crosses, down either side of that. The lift has to clear
		# the hornet's whole height, not just her feet, or at this size the
		# two simply overlap and the picture shows a collision rather than a
		# dodge -- which is the opposite of the caption.
		var over := cycle > 0.40 and cycle < 0.70
		who.position.y = 136.0 - (26.0 if over else 0.0)
		pose(who, 1 if over else (0 if cycle > 0.3 else 2))


## 4. The heron. The one jumping does not save you from, so the ring has to be
## the thing the player remembers.
func _slide_heron() -> void:
	slide_title("HERON", "the ring marks a dive. jumping will not help. MOVE.")
	var marked := _pad(Vector2(200, 140))
	var clear := _pad(Vector2(292, 140))
	# The ring is painted on the water, so it goes under her; the bird comes
	# down out of the sky, so it goes over everything.
	var ring := Sprite2D.new()
	ring.texture = RING
	ring.position = Vector2(200, 140)
	art(ring)
	var who := figure(Vector2(200, 136), &"jump_right")
	var bird := Sprite2D.new()
	bird.texture = HERON
	bird.position = Vector2(200, 60)
	bird.modulate.a = 0.0
	art(bird)

	_slide_tick = func(t: float) -> void:
		if not is_instance_valid(ring) or not is_instance_valid(who):
			return
		var cycle := fmod(t, 2.4) / 2.4
		if cycle < 0.6:                                  # the warning
			var k := cycle / 0.6
			ring.scale = Vector2.ONE * lerpf(1.5, 0.75, k)
			ring.modulate.a = (0.7 + 0.3 * k) * (0.82 + 0.18 * sin(t * 56.0))
			bird.modulate.a = 0.0
			bird.position.y = 60.0
		elif cycle < 0.78:                               # the dive
			var k := (cycle - 0.6) / 0.18
			bird.modulate.a = 1.0
			bird.position.y = lerpf(60.0, 134.0, k)
			ring.modulate.a = 0.9 * (1.0 - k)
		else:
			bird.modulate.a = maxf(0.0, 1.0 - (cycle - 0.78) / 0.1)
			ring.modulate.a = 0.0
		# She leaves well before it lands -- that is the whole lesson.
		var want := clear.position.x if cycle > 0.22 else marked.position.x
		who.position.x = move_toward(who.position.x, want, 300.0 * get_process_delta_time())
		var airborne := absf(who.position.x - want) > 2.0
		pose(who, 1 if airborne else 0)
		who.position.y = 136.0 - (10.0 if airborne else 0.0)
