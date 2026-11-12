class_name AcornCard
extends StartCard
## Acorn Storm's opening lesson.
##
## Three slides, and the middle one is the game: two marks appear on the
## ground and they are not the same shape. A player who leaves this card
## knowing only "ring bad, disc good" knows everything.
##
## The slides use REAL Fallers, not drawings of them, so the mark's tightening
## and its flash are exactly what the game does rather than an illustration
## free to drift away from it.

const FALLER := preload("res://src/minigames/acorn_storm/faller.tscn")
## The layer the game puts the player on. The slides use the same one, so the
## marks go under her and the falling bodies over her exactly as they do in
## play -- see StartCard.figure().
const Z_FIGURE := 20


func slide_count() -> int:
	return 3


func build_slide(index: int) -> void:
	match index:
		0: _slide_controls()
		1: _slide_marks()
		2: _slide_bar()


## A real faller, looping. `life` is driven by the slide rather than left to
## run, so it can hold at the interesting moment.
func _faller(kind: Faller.Kind, at: Vector2) -> Faller:
	var faller: Faller = FALLER.instantiate()
	art(faller)
	faller.setup(kind, at, 1.6)
	# Its own _process would land it once and leave an empty slide.
	faller.set_process(false)
	return faller


func _slide_controls() -> void:
	slide_title("ACORN STORM", "stand under the oak. do not stand still.")
	build_row(92.0, true, "STICK", "move", &"jump_right")
	build_row(148.0, false, "BUTTON", "sprint", &"jump_up", true)


## The one that matters. Both marks on screen at once, because the lesson is
## the DIFFERENCE between them and a player who sees them one at a time has
## to remember rather than compare.
func _slide_marks() -> void:
	slide_title("READ THE GROUND", "RING: acorn, move.      DISC: sunfruit, take it.")
	var bad := _faller(Faller.Kind.ACORN, Vector2(160, 150))
	var good := _faller(Faller.Kind.SUNFRUIT, Vector2(320, 150))
	# On the game's own player layer, so the marks go under her and the
	# falling bodies over her -- which is the draw-order rule the slide is
	# teaching. Left on the default she was drawn UNDER both marks and
	# vanished behind the gold disc entirely.
	var who := figure(Vector2(206, 146), &"jump_right", 1.3, Z_FIGURE)

	_slide_tick = func(t: float) -> void:
		if not is_instance_valid(bad) or not is_instance_valid(who):
			return
		var cycle := fmod(t, 2.4) / 2.4
		# Both run the same clock, so the two marks tighten side by side and
		# the only difference left between them is what they look like.
		bad.set_progress(cycle)
		good.set_progress(cycle)
		# Away from the ring and over to the disc, well before either lands --
		# and stopping BESIDE each rather than on top of it, because at this
		# size a figure standing on a 48px mark hides the mark, and the mark
		# is the entire lesson.
		var want := good.position.x - 26.0 if cycle > 0.25 \
				else bad.position.x + 46.0
		who.position.x = move_toward(who.position.x, want,
				300.0 * get_process_delta_time())
		var airborne := absf(who.position.x - want) > 2.0
		pose(who, 1 if airborne else 0)
		who.position.y = 146.0 - (9.0 if airborne else 0.0)


## Why any of it matters. The bar is the only thing on this card that is not
## an object in the game, so it is drawn plainly: it goes down on its own and
## a fruit is what puts it back.
func _slide_bar() -> void:
	slide_title("THE BAR ALWAYS FALLS", "sunfruit is the only thing that fills it.")

	var track := ColorRect.new()
	# Light enough to see the empty part: a bar whose track vanishes into the
	# backdrop only shows what is left, never what is missing.
	track.color = Color(0.26, 0.24, 0.34, 0.95)
	track.position = Vector2(132, 100)
	track.size = Vector2(216, 12)
	art(track)
	var fill := ColorRect.new()
	fill.color = Color(0.56, 0.86, 0.46)
	fill.position = track.position
	fill.size = Vector2(0, 12)
	art(fill)

	var good := _faller(Faller.Kind.SUNFRUIT, Vector2(268, 160))
	var who := figure(Vector2(180, 156), &"jump_right", 1.3, Z_FIGURE)

	_slide_tick = func(t: float) -> void:
		if not is_instance_valid(fill) or not is_instance_valid(good):
			return
		var cycle := fmod(t, 2.6) / 2.6
		# Falls for most of the loop, jumps back when she takes the fruit.
		var level := 0.82 - cycle * 0.72 if cycle < 0.78 else 0.9
		fill.size = Vector2(216.0 * clampf(level, 0.0, 1.0), 12.0)
		fill.color = Color(0.56, 0.86, 0.46) if level > 0.3 \
				else Color(1.0, 0.45, 0.38)
		good.set_progress(minf(cycle / 0.78, 1.0))
		good.visible = cycle < 0.80
		# Stops short of the fruit rather than standing on it, so both are
		# visible at the moment she takes it.
		var want := good.position.x - 22.0 if cycle > 0.18 else 180.0
		who.position.x = move_toward(who.position.x, want,
				280.0 * get_process_delta_time())
		var airborne := absf(who.position.x - want) > 2.0
		pose(who, 1 if airborne else 0)
		who.position.y = 156.0 - (9.0 if airborne else 0.0)
