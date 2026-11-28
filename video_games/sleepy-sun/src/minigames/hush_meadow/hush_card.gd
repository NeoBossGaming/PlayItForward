class_name HushCard
extends StartCard
## Hush Meadow's opening lesson.
##
## Four slides, and the fourth is the game. A player who leaves this card
## knowing "grass hides me, birds see in a cone, dew is only in the grass and
## dew is the only thing that calms me down" knows everything Hush Meadow
## does.
##
## Built from REAL game objects -- an actual MeadowPatch, an actual PatrolBird
## with its actual cone polygon, an actual dew going through its actual reveal
## -- so the lesson cannot drift away from what the game does. A diagram would
## be free to.

const PICKUP := preload("res://src/minigames/hush_meadow/pickup.tscn")
const BIRD := preload("res://src/minigames/hush_meadow/bird.tscn")

## The layers the game puts these on, so the slides stack the same way play
## does: blades over the player, cone over everything.
const Z_FIGURE := 10
const Z_PATCH := 14
## The real player stands here behind the card, visible through the backdrop
## on purpose. Slide art keeps clear of her, or the slide reads as having one
## more character on it than it has -- which is exactly how the last game's
## card came out before its rows were moved.
const SHE_IS_AT := Vector2(240, 164)

var _rng := RandomNumberGenerator.new()


func slide_count() -> int:
	return 4


func build_slide(index: int) -> void:
	_rng.seed = 90210 + index
	match index:
		0: _slide_controls()
		1: _slide_cover()
		2: _slide_eyes()
		3: _slide_dew()


func _patch(at: Vector2) -> MeadowPatch:
	var patch := MeadowPatch.build(_rng, at)
	patch.z_index = Z_PATCH
	art(patch)
	return patch


func _slide_controls() -> void:
	# "go with it" until the meadow started carrying her -- after which it was
	# advice to ride off the bottom edge, the one thing that hurts.
	slide_title("HUSH MEADOW", "the meadow carries you. walk against it.")
	# High on the card, clear of the player: she stands in the middle of the
	# field and is visible through the backdrop, and a row of text through her
	# is how the last game's card got reported as a bug.
	build_row(74.0, true, "STICK", "move", &"jump_right")
	# The button tosses a pebble now; there is no sprint. One word, the length
	# "sprint" was: "toss a pebble" ran its last letters into the player
	# standing behind the card, which is the row-through-her bug again.
	build_row(122.0, false, "BUTTON", "pebble", &"jump_up", true)


## Two figures, one in and one out, because the lesson is the DIFFERENCE and a
## player shown them one at a time has to remember rather than compare. The
## hidden one is at the same alpha TopDownPlayer.set_concealed() uses in play.
func _slide_cover() -> void:
	slide_title("TALL GRASS HIDES YOU", "and slows you down. nothing is free.")
	_patch(Vector2(138, 132))
	# Feet a little behind the patch's centre, so her head and shoulders show
	# over the blades as they do in play. At the centre itself the solid
	# clumps -- drawn as shapes since the art went to pixel grain, not as thin
	# stems she showed through -- covered all of her but her shoes, and a slide
	# about the DIFFERENCE between two figures had one.
	var inside := figure(Vector2(138, 121), &"jump_down", 1.3, Z_FIGURE)
	pose(inside, 0)
	inside.modulate.a = 0.5
	var outside := figure(Vector2(348, 132), &"jump_down", 1.3, Z_FIGURE)
	pose(outside, 0)


## A real bird and its real cone. Aimed straight at her, held calm, because the
## point is the shape of what it can see rather than what happens next.
func _slide_eyes() -> void:
	# Both answers to a cone: go round it, or turn it. The pebble is taught
	# here rather than on the controls slide, where one word is all there is
	# room for -- this is where a player is asking what to do about a bird.
	slide_title("BIRDS SEE IN A CONE", "walk behind them, or toss a pebble.")
	var bird: PatrolBird = BIRD.instantiate()
	bird.position = Vector2(152, 92)
	art(bird)
	# art() adds it to a slide that is already in the tree, so the bird is
	# ready by the time this line runs. It used to connect to `ready` here
	# instead -- after the signal had already fired -- so the face() never
	# happened, and the slide teaching "birds see in a cone" showed the cone
	# pointing up and away from the girl it was meant to be looking at.
	if bird.is_node_ready():
		bird.face(Vector2.DOWN)
	else:
		bird.ready.connect(func() -> void: bird.face(Vector2.DOWN),
				CONNECT_ONE_SHOT)
	var seen := figure(Vector2(152, 158), &"jump_down", 1.3, Z_FIGURE)
	pose(seen, 0)


## The one that matters. Dew is not on the slide until the figure is in the
## grass, exactly as it is not on the meadow until the player is -- so the rule
## is demonstrated rather than described.
func _slide_dew() -> void:
	slide_title("SHIMMERING GRASS HOLDS DEW",
			"dew is the only thing that calms you down.")
	var patch := _patch(Vector2(158, 132))
	var dew: MeadowPickup = PICKUP.instantiate()
	dew.kind = MeadowPickup.Kind.DEW
	dew.patch = patch
	dew.position = Vector2(26, -4)
	patch.add_child(dew)
	# The same trap as the bird on the slide before: the patch is already in
	# the tree, so the dew is ready the moment it is added, and connecting to
	# `ready` afterwards meant the reveal never ran. The one slide that
	# demonstrates the rule the game hangs on showed no dew at all.
	if dew.is_node_ready():
		dew.reveal()
	else:
		dew.ready.connect(dew.reveal, CONNECT_ONE_SHOT)
	patch.mark_dew()
	var who := figure(Vector2(140, 132), &"jump_down", 1.3, Z_FIGURE)
	pose(who, 0)
	who.modulate.a = 0.5
