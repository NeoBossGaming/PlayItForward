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

const TUTORIAL_SECONDS := 5.0
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


func _teach() -> void:
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)
	_skippable = true
	# Polled rather than slept, so a press cuts it short the moment it lands
	# instead of at the end of a fixed wait.
	var waited := 0.0
	while waited < TUTORIAL_SECONDS and not _skipped:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_skippable = false
	await _fade_lesson()


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
	# reads false here and gets the lesson built.
	if not tutorial_seen:
		_build_lesson()


func _build_lesson() -> void:
	var heading := _label(&"Title", Color(1, 0.89, 0.58))
	heading.text = "RIVERLEAP"
	heading.set_anchors_preset(Control.PRESET_TOP_WIDE)
	heading.offset_top = 26.0
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(heading)

	# Two rows, both up at once. The figure on each row is the player's own
	# art doing the move the row describes, so the card shows the actual thing
	# rather than a diagram of it.
	_build_row(78.0, false, "PRESS", "jump on the spot", &"jump_up")
	_build_row(140.0, true, "HOLD  +  PRESS", "hop across", &"jump_right")

	var note := _label(&"Small", Color(0.80, 0.82, 0.95))
	note.text = "the pads sink. keep moving."
	note.set_anchors_preset(Control.PRESET_TOP_WIDE)
	note.offset_top = 200.0
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(note)

	var hint := _label(&"Small", Color(0.86, 0.86, 0.96))
	hint.text = "press to start"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -28.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(hint)


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
		_root.add_child(stick)
		_stick_marks.append(stick)
		for side in [-1.0, 1.0]:
			var arrow := TextureRect.new()
			arrow.texture = ARROW
			arrow.position = Vector2(x + (-12.0 if side < 0.0 else 22.0), y + 4.0)
			arrow.size = Vector2(9, 12)
			arrow.flip_h = side < 0.0
			arrow.set_meta(&"side", side)
			arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_root.add_child(arrow)
			_arrows.append(arrow)
		x += 42.0

	var button := TextureRect.new()
	button.texture = BUTTON
	button.position = Vector2(x, y + 2.0)
	button.size = Vector2(16, 16)
	button.set_meta(&"home", y + 2.0)
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(button)
	_button_marks.append(button)

	var caption := _label(&"Heading", Color(1, 0.95, 0.80))
	caption.text = verb
	caption.position = Vector2(x + 30.0, y - 2.0)
	caption.size = Vector2(170, 20)
	_root.add_child(caption)

	var detail := _label(&"Small", Color(0.78, 0.80, 0.94))
	detail.text = what
	detail.position = Vector2(x + 30.0, y + 16.0)
	detail.size = Vector2(170, 16)
	_root.add_child(detail)

	var figure := AnimatedSprite2D.new()
	figure.sprite_frames = load("res://src/core/player_frames.tres")
	figure.position = Vector2(392.0, y + 18.0)
	figure.scale = Vector2(1.2, 1.2)
	figure.set_meta(&"clip", clip)
	_root.add_child(figure)
	_figures.append(figure)


static func _label(variation: StringName, colour: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.add_theme_color_override(&"font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
