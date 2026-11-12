class_name StartCard
extends CanvasLayer
## What you see when you walk up to the cabinet: the controls, then 3-2-1-GO.
##
## Deliberately the same object as RunCard in a different mood -- same build
## shape, same fonts, same pacing helper -- because they are the two ends of
## the same run and should not look like they came from different games.
##
## **Everything on the tutorial is visible at once and loops.** No sequencing
## between the two lessons: five seconds is not enough to show one thing and
## then another, and somebody glances up at a random moment. Whatever is on
## screen then has to be the whole picture.
##
## It teaches the stick and the button and nothing else. Hornets do not arrive
## until 35s into a run and herons not until 100s, so a card that explained
## them would be explaining something the player meets a minute and a half
## later, by which point they have forgotten it. Those are taught by a prompt
## at the moment they first appear instead.

signal finished

## How long each slide holds. Four slides at this plus their fades runs about
## nine seconds for a first-timer; a replay still skips all of it.
const SLIDE_SECONDS := 2.2
const BEAT := 0.7
## How long the results card may sit untouched before whoever presses next is
## assumed to be a different person. See `tutorial_seen`.
const STRANGER_AFTER_MS := 30000

## Survives `reload_current_scene()`, which is how replay works, so a retry
## goes straight to the countdown instead of re-teaching someone who just
## played. It is per-process, NOT saved to disk: a player returning tomorrow
## is still a stranger to the controls.
##
## A cabinet runs all day, so on its own this would mean only the first player
## of the morning ever saw the tutorial. `note_idle()` clears it again when the
## machine has been left alone -- a heuristic, and wrong in both directions
## sometimes, but it fails harmlessly either way and the alternative is a
## tutorial nobody sees.
static var tutorial_seen: bool = false

const STICK := preload("res://assets/game/ui/stick.png")
const BUTTON := preload("res://assets/game/ui/button.png")
const ARROW := preload("res://assets/game/ui/arrow.png")
const HORNET := preload("res://assets/game/wind_leaf/hornet.png")
const HERON := preload("res://assets/game/wind_leaf/heron.png")
const RING := preload("res://assets/game/wind_leaf/dive_shadow.png")
## The slides use the REAL pad, not a drawing of one. Its shake, its colour
## shift and its ripple are the lesson, and a picture of them would be free to
## drift away from what the game actually does.
const LEAF := preload("res://src/minigames/wind_leaf/leaf.tscn")
const SLIDES := 4

var _root: Control
var _skippable: bool = false
var _skipped: bool = false
var _clock: float = 0.0
var _button_marks: Array[TextureRect] = []
var _stick_marks: Array[TextureRect] = []
var _arrows: Array[TextureRect] = []
var _figures: Array[AnimatedSprite2D] = []
## Where the current slide's contents live, so a slide can be torn down
## without touching the backdrop or the page dots.
var _slide: Control
var _dots: Array[ColorRect] = []
## Set by each slide to its own per-frame animation. Lambdas capture node
## references fine -- it is captured *locals they mutate* that do not survive,
## which is why nothing here counts in one.
var _slide_tick: Callable = Callable()


## Call when the results card has been waiting: if it sat long enough that the
## last player has plainly wandered off, the next one gets the tutorial again.
static func note_idle(waited_ms: int) -> void:
	if waited_ms >= STRANGER_AFTER_MS:
		tutorial_seen = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_clock += delta
	if _slide_tick.is_valid():
		_slide_tick.call(_clock)
	# One cycle drives the whole card, so the button, the stick and the figures
	# are visibly doing the same thing at the same moment rather than three
	# unrelated loops.
	var beat := fmod(_clock, 0.9) / 0.9
	var pressed := beat > 0.45
	for mark in _button_marks:
		mark.position.y = mark.get_meta(&"home") + (2.0 if pressed else 0.0)
		mark.modulate = Color(1, 1, 1) if pressed else Color(0.78, 0.78, 0.86)
	# The stick leans one way and then the other across the cycle, so the card
	# shows that EITHER direction works rather than implying only one.
	var leaning_left := fmod(_clock, 1.8) < 0.9
	var lean := -1.0 if leaning_left else 1.0
	for mark in _stick_marks:
		mark.rotation = (0.38 if pressed else 0.1) * lean
	for arrow in _arrows:
		var mine: bool = (float(arrow.get_meta(&"side")) < 0.0) == leaning_left
		arrow.modulate.a = 1.0 if (mine and pressed) else 0.25
	for figure in _figures:
		if figure.sprite_frames == null:
			continue
		var clip: StringName = figure.get_meta(&"clip")
		if not figure.sprite_frames.has_animation(clip):
			continue
		if figure.animation != clip:
			figure.play(clip)
		figure.pause()
		# crouch -> airborne -> land, in step with the button.
		figure.frame = 0 if beat < 0.45 else (1 if beat < 0.8 else 2)


func _unhandled_input(event: InputEvent) -> void:
	if not _skippable or _skipped:
		return
	if event.is_action_pressed(&"act") or event.is_action_pressed(&"start") \
			or event.is_action_pressed(&"back"):
		_skipped = true
		get_viewport().set_input_as_handled()


## The whole opening: the lesson if this player needs it, then the countdown.
## Awaited by the game, which does not start until this returns.
func play() -> void:
	_build()
	if not tutorial_seen:
		tutorial_seen = true
		await _teach()
	# The lesson needs a dark backdrop to be read against; the countdown does
	# not, and the player should already be looking at the water. Done here
	# rather than at the end of the lesson so a replay -- which skips the
	# lesson entirely -- does not count down behind a near-opaque screen.
	create_tween().tween_property(_root, "color",
			Color(0.04, 0.03, 0.08, 0.30), 0.3)
	await _count_in()
	finished.emit()
	queue_free()


## Four slides: the controls, the pads going under, and the two things that
## come at you. Each holds briefly and hands over to the next.
##
## The hazard slides are here because a player should recognise a hornet and a
## heron the first time they see one rather than learning by losing a life --
## but they are still ALSO taught in play, by a prompt the first time each
## actually appears, because a hornet turns up 35s after this card is gone and
## a heron more than a minute after that.
func _teach() -> void:
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
	_skippable = true
	for index in SLIDES:
		_show_slide(index)
		# Polled rather than slept, so a press cuts it short the moment it
		# lands instead of at the end of a fixed wait.
		var waited := 0.0
		while waited < SLIDE_SECONDS and not _skipped:
			await get_tree().process_frame
			waited += get_process_delta_time()
		if _skipped:
			break
		if index < SLIDES - 1:
			await _fade_slide(0.14)
	_skippable = false
	await _fade_lesson()


## Clears whatever the last slide left and builds the next one.
func _show_slide(index: int) -> void:
	_slide_tick = Callable()
	_button_marks.clear()
	_stick_marks.clear()
	_arrows.clear()
	_figures.clear()
	for child in _slide.get_children():
		child.queue_free()
	_slide.modulate.a = 1.0

	match index:
		0: _slide_controls()
		1: _slide_pads()
		2: _slide_hornet()
		3: _slide_heron()
	for i in _dots.size():
		_dots[i].color = Color(1, 0.86, 0.5) if i == index \
				else Color(0.45, 0.45, 0.58)


func _fade_slide(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_slide, "modulate:a", 0.0, seconds)
	await tween.finished


func _fade_lesson() -> void:
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.2)
	await tween.finished
	for child in _root.get_children():
		child.queue_free()
	_button_marks.clear()
	_stick_marks.clear()
	_arrows.clear()
	_figures.clear()
	_dots.clear()
	_slide = null
	_slide_tick = Callable()
	_root.modulate.a = 1.0


## Three low beats and a higher, longer release -- the shape of a start light.
func _count_in() -> void:
	for n in [3, 2, 1]:
		Audio.sfx(&"count")
		_punch("%d" % n, Color(1, 0.92, 0.66))
		await Wait.on(self, BEAT)
	Audio.sfx(&"go")
	_punch("GO", Color(0.72, 1.0, 0.72))
	await Wait.on(self, 0.45)


func _punch(text: String, colour: Color) -> void:
	var label := _label(&"Title", colour)
	label.text = text
	# Sized and placed EXPLICITLY, not by anchors.
	#
	# set_anchors_preset() does not resolve a Control's rect until the next
	# layout pass, so pivot_offset and the centring were both computed against
	# a zero-size rect: the number scaled about the screen's top-left corner
	# and flew off it. It was being created and freed on schedule the whole
	# time -- it simply was not anywhere on screen.
	label.size = Vector2(480.0, 120.0)
	label.position = Vector2(0.0, 75.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.pivot_offset = label.size * 0.5
	_root.add_child(label)

	# Big and bright, and it HOLDS before it goes. The first version faded
	# across the whole beat, which meant the number spent most of its life
	# half-transparent over moving water.
	label.scale = Vector2(5.0, 5.0)
	var tween := create_tween()
	tween.tween_property(label, "scale", Vector2(3.2, 3.2), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(BEAT * 0.45)
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, BEAT * 0.3)
	tween.tween_property(label, "scale", Vector2(3.8, 3.8), BEAT * 0.3)
	tween.chain().tween_callback(label.queue_free)


# --- building it -------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_root = dim

	# play() flips tutorial_seen only after this runs, so a first-timer still
	# reads false here and gets the slides built.
	if tutorial_seen:
		return

	_slide = Control.new()
	_slide.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_slide)

	# Page dots and the skip hint sit outside the slide, so they survive the
	# fade between one slide and the next.
	var span := float(SLIDES) * 10.0
	for i in SLIDES:
		var dot := ColorRect.new()
		dot.size = Vector2(6, 3)
		dot.position = Vector2(240.0 - span * 0.5 + float(i) * 10.0, 232.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(dot)
		_dots.append(dot)

	var hint := _label(&"Small", Color(0.86, 0.86, 0.96))
	hint.text = "press to start"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -26.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(hint)


## Headings and captions are placed EXPLICITLY rather than by anchor preset:
## a Control's rect is not resolved until the next layout pass, and the
## countdown numerals already went missing once for trusting it.
func _slide_title(text: String, sub: String) -> void:
	var heading := _label(&"Title", Color(1, 0.89, 0.58))
	heading.text = text
	heading.size = Vector2(480, 24)
	heading.position = Vector2(0, 26)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slide.add_child(heading)

	var caption := _label(&"Small", Color(0.82, 0.84, 0.96))
	caption.text = sub
	caption.size = Vector2(440, 18)
	caption.position = Vector2(20, 200)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slide.add_child(caption)


func _figure(at: Vector2, clip: StringName, scale: float = 1.3) -> AnimatedSprite2D:
	var figure := AnimatedSprite2D.new()
	figure.sprite_frames = load("res://src/core/player_frames.tres")
	figure.position = at
	figure.scale = Vector2(scale, scale)
	figure.set_meta(&"clip", clip)
	_slide.add_child(figure)
	return figure


func _pad(at: Vector2) -> RiverLeaf:
	var leaf: RiverLeaf = LEAF.instantiate()
	leaf.position = at
	_slide.add_child(leaf)
	return leaf


# --- the four slides ---------------------------------------------------------

## 1. The two verbs. Both up at once and looping, because five seconds is not
## long enough to show one and then the other and somebody glances up at a
## random moment.
func _slide_controls() -> void:
	_slide_title("RIVERLEAP", "ride the river. do not stop.")
	_build_row(84.0, false, "PRESS", "jump on the spot", &"jump_up")
	_build_row(142.0, true, "HOLD  +  PRESS", "hop across", &"jump_right")


## 2. What the pads do. A REAL pad, shaking and going under on a loop, with
## the character stepping off it in time -- the shake, the colour shift and
## the ripple are the lesson, and a drawing of them could drift from the game.
func _slide_pads() -> void:
	_slide_title("THE PADS SINK", "it shakes first. hop off before it goes.")
	var doomed := _pad(Vector2(190, 132))
	var safe := _pad(Vector2(290, 132))
	var who := _figure(Vector2(190, 128), &"jump_right")

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
		_pose(who, 1 if airborne else 0)
		who.position.y = 128.0 - (8.0 if airborne else 0.0)


## 3. The hornet, flying straight down a lane at you.
func _slide_hornet() -> void:
	_slide_title("HORNET", "JUMP it. you pass over the top.")
	var _pad_under := _pad(Vector2(240, 140))
	# The hornet goes in BEFORE her, so she is drawn over it -- which is the
	# rule the slide is teaching. Added after, it passed across her face and
	# the picture said the opposite of the caption.
	var bug := Sprite2D.new()
	bug.texture = HORNET
	bug.position = Vector2(240, 40)
	_slide.add_child(bug)
	var who := _figure(Vector2(240, 136), &"jump_up")

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
		_pose(who, 1 if over else (0 if cycle > 0.3 else 2))


## 4. The heron. The one jumping does not save you from, so the ring has to be
## the thing the player remembers.
func _slide_heron() -> void:
	_slide_title("HERON", "the ring marks a dive. jumping will not help. MOVE.")
	var marked := _pad(Vector2(200, 140))
	var clear := _pad(Vector2(292, 140))
	# The ring is painted on the water, so it goes under her; the bird comes
	# down out of the sky, so it goes over everything.
	var ring := Sprite2D.new()
	ring.texture = RING
	ring.position = Vector2(200, 140)
	_slide.add_child(ring)
	var who := _figure(Vector2(200, 136), &"jump_right")
	var bird := Sprite2D.new()
	bird.texture = HERON
	bird.position = Vector2(200, 60)
	bird.modulate.a = 0.0
	_slide.add_child(bird)

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
		_pose(who, 1 if airborne else 0)
		who.position.y = 136.0 - (10.0 if airborne else 0.0)


## Hold one frame of a jump clip. The figures on these slides are posed by
## hand rather than played, so they stay in step with whatever they illustrate.
func _pose(figure: AnimatedSprite2D, index: int) -> void:
	var clip: StringName = figure.get_meta(&"clip")
	if figure.sprite_frames == null or not figure.sprite_frames.has_animation(clip):
		return
	if figure.animation != clip:
		figure.play(clip)
	figure.pause()
	figure.frame = clampi(index, 0, figure.sprite_frames.get_frame_count(clip) - 1)


func _build_row(y: float, with_stick: bool, verb: String, what: String,
		clip: StringName) -> void:
	var x := 96.0
	if with_stick:
		var stick := TextureRect.new()
		stick.texture = STICK
		stick.position = Vector2(x, y - 4.0)
		stick.size = Vector2(20, 24)
		stick.pivot_offset = Vector2(10, 22)      # swings from its base
		stick.set_meta(&"lean", 1.0)
		stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slide.add_child(stick)
		_stick_marks.append(stick)
		for side in [-1.0, 1.0]:
			var arrow := TextureRect.new()
			arrow.texture = ARROW
			arrow.position = Vector2(x + (-12.0 if side < 0.0 else 22.0), y + 4.0)
			arrow.size = Vector2(9, 12)
			arrow.flip_h = side < 0.0
			arrow.set_meta(&"side", side)
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_slide.add_child(arrow)
			_arrows.append(arrow)
		x += 42.0

	var button := TextureRect.new()
	button.texture = BUTTON
	button.position = Vector2(x, y + 2.0)
	button.size = Vector2(16, 16)
	button.set_meta(&"home", y + 2.0)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide.add_child(button)
	_button_marks.append(button)

	var caption := _label(&"Heading", Color(1, 0.95, 0.80))
	caption.text = verb
	caption.position = Vector2(x + 30.0, y - 2.0)
	caption.size = Vector2(170, 20)
	_slide.add_child(caption)

	var detail := _label(&"Small", Color(0.78, 0.80, 0.94))
	detail.text = what
	detail.position = Vector2(x + 30.0, y + 16.0)
	detail.size = Vector2(170, 16)
	_slide.add_child(detail)

	var figure := _figure(Vector2(392.0, y + 18.0), clip, 1.2)
	_figures.append(figure)


static func _label(variation: StringName, colour: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.add_theme_color_override(&"font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
