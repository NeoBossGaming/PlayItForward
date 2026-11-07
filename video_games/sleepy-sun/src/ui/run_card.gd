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
func show_run(title: String, score: int, lines: Array, best: int) -> void:
	_build(title)
	_score.text = "0"
	await _count_to(score)

	for line: Array in lines:
		await Wait.on(self, ROW_DELAY)
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
