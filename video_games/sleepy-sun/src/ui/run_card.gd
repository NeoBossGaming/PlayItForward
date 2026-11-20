class_name RunCard
extends CanvasLayer
## What you see when a run ends: the score, what made it, and your best.
##
## Stands in for the whole results screen while the shell is parked. It is
## deliberately small -- during a polish round the only thing that matters at
## the end of a run is being able to read what just happened and start another
## one immediately.

signal replay

const ROW_DELAY := 0.28
## Long enough that the last thing that happened is still on screen, short
## enough that nobody waits. A press before this is the tail of the run, not
## a request to restart.
const INPUT_DELAY := 0.7

var _root: Control
var _rows: VBoxContainer
var _score: Label
var _hint: Label
var _ready_for_input: bool = false
var _pulse: float = 0.0


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not _ready_for_input:
		return
	_pulse += delta * 3.0
	_hint.modulate.a = 0.55 + 0.45 * sin(_pulse)


func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	if event.is_action_pressed(&"act") or event.is_action_pressed(&"start") \
			or event.is_action_pressed(&"back"):
		_ready_for_input = false
		replay.emit()
		get_viewport().set_input_as_handled()


## `lines` is an array of [label, value] pairs, in the game's own words.
## `normalised` is the run on the shared 0-1000 scale, which is what the
## letter is cut from -- see src/core/rank.gd. `best_normalised` is the best
## this game has ever seen, so the card can say whether the letter is new.
func show_run(title: String, score: int, lines: Array, best: int,
		normalised: int = -1, best_normalised: int = 0) -> void:
	_build(title)
	_score.text = "0"
	await _count_to(score)
	if normalised >= 0:
		await _stamp_rank(normalised, best_normalised)

	for line: Array in lines:
		await Wait.on(self, ROW_DELAY)
		# A third element tints the row, so a game can mark one out without
		# needing its own card.
		if line.size() > 2:
			_add_row(String(line[0]), String(line[1]), line[2])
		else:
			_add_row(String(line[0]), String(line[1]))

	await Wait.on(self, ROW_DELAY)
	if score >= best and score > 0:
		# Double-spaced: Pixelify Sans kerns a single space so tight at 11px that
		# "NEW BEST" reads as one word.
		_add_row("NEW  BEST", "%d" % score, Color(1, 0.87, 0.45))
	else:
		_add_row("best", "%d" % best, Color(0.7, 0.72, 0.85))

	await Wait.on(self, INPUT_DELAY)
	_ready_for_input = true
	_hint.visible = true


## The letter lands like a stamp rather than appearing: it is the one thing
## the player came back for, and the whole point of a grade is the moment it
## hits. Same move the parked results screen used.
func _stamp_rank(normalised: int, best_normalised: int) -> void:
	await Wait.on(self, 0.25)
	var letter := Rank.letter(normalised)

	var label := _label(&"Display", Rank.colour(normalised))
	label.text = letter
	# Placed explicitly, never by anchor preset: a Control's rect is not
	# resolved until the next layout pass, and centring against a zero-size
	# rect is how the countdown numerals once flew off the screen.
	label.size = Vector2(120.0, 60.0)
	label.position = Vector2(348.0, 54.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.pivot_offset = label.size * 0.5
	label.rotation = -0.12
	_root.add_child(label)

	label.scale = Vector2(4.0, 4.0)
	label.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 1.0, 0.08)
	tween.tween_property(label, "scale", Vector2(1.6, 1.6), 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.sfx(&"complete", 1.0 + 0.12 * float(Rank.BANDS.size() - Rank.index(normalised)))

	if Rank.is_new_letter(normalised, best_normalised):
		await Wait.on(self, 0.3)
		var note := _label(&"Small", Rank.colour(normalised))
		note.text = "best yet"
		note.size = Vector2(120.0, 14.0)
		# Below the letter's SCALED extent, not its layout rect. The label is
		# 60 tall and ends up at 1.6x about its own centre, so it really
		# occupies y 36..132 -- a note placed against the unscaled box landed
		# on top of it.
		note.position = Vector2(348.0, 136.0)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_root.add_child(note)
		Audio.sfx(&"chime", 1.4)
	await Wait.on(self, 0.2)


## Counts up rather than printing. The few seconds a player spends watching a
## number climb is where they decide whether to go again.
func _count_to(score: int) -> void:
	var shown := 0
	var step := maxi(1, int(score / 28.0))
	while shown < score:
		shown = mini(shown + step, score)
		_score.text = "%d" % shown
		Audio.sfx(&"tick", 1.0 + 0.6 * (float(shown) / maxf(float(score), 1.0)))
		await Wait.on(self, 0.03)
	_score.text = "%d" % score
	Audio.sfx(&"complete")


func _build(title: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.08, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_root = dim

	var heading := _label(&"Title", Color(1, 0.89, 0.58))
	heading.text = title
	heading.set_anchors_preset(Control.PRESET_TOP_WIDE)
	heading.offset_top = 44.0
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dim.add_child(heading)

	_score = _label(&"Display", Color(1, 0.92, 0.62))
	_score.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_score.offset_top = 70.0
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dim.add_child(_score)

	_rows = VBoxContainer.new()
	_rows.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_rows.offset_left = 150.0
	_rows.offset_right = -150.0
	_rows.offset_top = 112.0
	_rows.add_theme_constant_override(&"separation", 2)
	dim.add_child(_rows)

	_hint = _label(&"Small", Color(0.86, 0.86, 0.96))
	_hint.text = "press any button"
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_hint.offset_top = -30.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.visible = false
	dim.add_child(_hint)


func _add_row(name: String, value: String, colour := Color(0.94, 0.93, 1.0)) -> void:
	var row := HBoxContainer.new()
	var left := _label(&"Small", colour)
	left.text = name
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var right := _label(&"Small", colour)
	right.text = value
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(right)
	_rows.add_child(row)

	row.modulate.a = 0.0
	create_tween().tween_property(row, "modulate:a", 1.0, 0.18)
	Audio.sfx(&"tick", 1.3)


static func _label(variation: StringName, colour: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.add_theme_color_override(&"font_color", colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
