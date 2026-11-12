class_name StartCard
extends CanvasLayer
## What you see when you walk up to the cabinet: the lesson, then 3-2-1-GO.
##
## Deliberately the same object as RunCard in a different mood -- same build
## shape, same fonts, same pacing helper -- because they are the two ends of
## the same run and should not look like they came from different games.
##
## **This class is the card, not the lesson.** It owns the backdrop, the page
## dots, the skip, the pacing and the countdown; each game supplies its own
## slides by extending it and overriding `slide_count()` and `build_slide()`.
## Riverleap's four slides lived in here while it was the only game, and the
## second game would otherwise have started by either copying all of this or
## adding a game name to match on.
##
## **Everything on a slide is visible at once and loops.** No sequencing
## within a slide: somebody glances up at a random moment, and whatever is on
## screen then has to be the whole picture. Between slides is fine -- that is
## what the dots are for.

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


## --- what a game overrides ---------------------------------------------------

## How many slides this game teaches. 0 means no lesson at all, which is what
## the base class on its own does.
func slide_count() -> int:
	return 0


## Build slide `index` into `_slide`. Use `slide_title()`, `figure()`,
## `build_row()` and `pose()`; set `_slide_tick` for per-frame animation.
func build_slide(_index: int) -> void:
	pass


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
	if not tutorial_seen and slide_count() > 0:
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


## Each slide holds briefly and hands over to the next, and any press skips
## the lot.
func _teach() -> void:
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
	_skippable = true
	var count := slide_count()
	for index in count:
		_show_slide(index)
		# Polled rather than slept, so a press cuts it short the moment it
		# lands instead of at the end of a fixed wait.
		var waited := 0.0
		while waited < SLIDE_SECONDS and not _skipped:
			await get_tree().process_frame
			waited += get_process_delta_time()
		if _skipped:
			break
		if index < count - 1:
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

	build_slide(index)
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
	var label := label(&"Title", colour)
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
	var count := slide_count()
	var span := float(count) * 10.0
	for i in count:
		var dot := ColorRect.new()
		dot.size = Vector2(6, 3)
		dot.position = Vector2(240.0 - span * 0.5 + float(i) * 10.0, 232.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(dot)
		_dots.append(dot)

	var hint := label(&"Small", Color(0.86, 0.86, 0.96))
	hint.text = "press to start"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -26.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(hint)


## Headings and captions are placed EXPLICITLY rather than by anchor preset:
## a Control's rect is not resolved until the next layout pass, and the
## countdown numerals already went missing once for trusting it.
func slide_title(text: String, sub: String) -> void:
	var heading := label(&"Title", Color(1, 0.89, 0.58))
	heading.text = text
	heading.size = Vector2(480, 24)
	heading.position = Vector2(0, 26)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slide.add_child(heading)

	var caption := label(&"Small", Color(0.82, 0.84, 0.96))
	caption.text = sub
	caption.size = Vector2(440, 18)
	caption.position = Vector2(20, 200)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slide.add_child(caption)


## One of the player's own drawn frames, held rather than played, so a slide
## illustrates the game with the game's art instead of a picture of it.
func figure(at: Vector2, clip: StringName, scale: float = 1.3) -> AnimatedSprite2D:
	var who := AnimatedSprite2D.new()
	who.sprite_frames = load("res://src/core/player_frames.tres")
	who.position = at
	who.scale = Vector2(scale, scale)
	who.set_meta(&"clip", clip)
	_slide.add_child(who)
	return who


## Puts a node on the current slide. Subclasses use this rather than reaching
## for `_slide`, so the slide can be rebuilt without them knowing.
func art(node: Node) -> Node:
	_slide.add_child(node)
	return node


## Hold one frame of a jump clip. The figures on these slides are posed by
## hand rather than played, so they stay in step with whatever they illustrate.
func pose(who: AnimatedSprite2D, index: int) -> void:
	var clip: StringName = who.get_meta(&"clip")
	if who.sprite_frames == null or not who.sprite_frames.has_animation(clip):
		return
	if who.animation != clip:
		who.play(clip)
	who.pause()
	who.frame = clampi(index, 0, who.sprite_frames.get_frame_count(clip) - 1)


func build_row(y: float, with_stick: bool, verb: String, what: String,
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

	var caption := label(&"Heading", Color(1, 0.95, 0.80))
	caption.text = verb
	caption.position = Vector2(x + 30.0, y - 2.0)
	caption.size = Vector2(170, 20)
	_slide.add_child(caption)

	var detail := label(&"Small", Color(0.78, 0.80, 0.94))
	detail.text = what
	detail.position = Vector2(x + 30.0, y + 16.0)
	detail.size = Vector2(170, 16)
	_slide.add_child(detail)

	var who := figure(Vector2(392.0, y + 18.0), clip, 1.2)
	_figures.append(who)


static func label(variation: StringName, colour: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.add_theme_color_override(&"font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
