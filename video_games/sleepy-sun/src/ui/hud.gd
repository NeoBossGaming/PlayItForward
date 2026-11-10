class_name HUD
extends CanvasLayer
## In-game overlay. Everything permanent on it is a bar, a badge or a row of
## pips -- never a sentence.
##
## Instructions used to live up here for the whole round. Nobody reads a line
## that has been on screen for a minute, and on a cabinet it just becomes
## clutter. The rules moved to the intro card; scoring moved onto the objects
## that caused it. What is left is state you glance at: how you are doing, how
## long you have, and whether you are on a run.

## Only the meters the shipping games actually use. The other four icons went
## with their minigames; naming a file that is not on disk is a crash waiting
## for whoever adds the next meter.
## The crossing bar, as an explicit rectangle in viewport pixels.
##
## It used to be a ProgressBar laid out by anchors and the project theme, and
## Neo reported it running off the screen on his machine -- which I could not
## reproduce on either Godot 4.6 or 4.7, headless or windowed. Rather than keep
## hunting a phantom, it is now two ColorRects positioned from this one
## constant in code: no theme, no minimum size, no layout negotiation, nothing
## that can differ between engine versions. It is also narrower than the slab
## it replaced, which at 63% of the screen width read as overflowing whether it
## technically was or not.
const BAR := Rect2(96.0, 7.0, 216.0, 6.0)
const BAR_ICON_GAP := 5.0

## The health bar, laid out from one constant for the same reason the meter is:
## five segments at a fixed size and a fixed gap, positioned absolutely, with
## no container doing arithmetic on our behalf. Top-left, because the score
## already owns the top-right and that is where an arcade player looks for it.
##
## The art is 11x9 and is drawn at 2x, so each segment lands on whole viewport
## pixels and therefore on whole screen pixels at every integer window scale.
const LIFE_ORIGIN := Vector2(10.0, 6.0)
const LIFE_SEGMENT := Vector2(22.0, 18.0)
const LIFE_GAP := 3.0
## Breathing room between the segments and the plate behind them.
const LIFE_PAD := 3.0

const LIFE_TEXTURES := {
	0: preload("res://assets/game/ui/heart_empty.png"),
	1: preload("res://assets/game/ui/heart_half.png"),
	2: preload("res://assets/game/ui/heart_full.png"),
}

const METER_ICONS := {
	&"time": "res://assets/game/ui/icon_clock.png",
	&"far bank": "res://assets/game/ui/icon_flag.png",
}

@onready var _score: Label = $Root/Score
@onready var _multiplier: Label = $Root/Multiplier
@onready var _meter_track: ColorRect = $Root/MeterTrack
@onready var _meter_fill: ColorRect = $Root/MeterFill
@onready var _meter_icon: TextureRect = $Root/MeterIcon
@onready var _meter_mark: TextureRect = $Root/MeterMark
@onready var _stamina: ProgressBar = $Root/Stamina
@onready var _pips: HBoxContainer = $Root/Pips
@onready var _toast: Label = $Root/Toast
@onready var _prompt: Label = $Root/Prompt
@onready var _alarm: TextureRect = $Root/Alarm
@onready var _lives: Control = $Root/Lives
@onready var _timer: Label = $Root/Timer

var _shown_score: float = 0.0
var _target_score: int = 0
var _toast_tween: Tween
var _multiplier_value: int = 1
var _alarm_pulse: float = 0.0
var _life_segments: Array[TextureRect] = []
var _shown_halves: int = -1


func _ready() -> void:
	# The bar's geometry lives in BAR, not in the scene, so it is laid out here
	# and nowhere else.
	_meter_track.position = BAR.position
	_meter_track.size = BAR.size
	_meter_fill.position = BAR.position
	_meter_fill.size = Vector2(0.0, BAR.size.y)
	_meter_icon.size = Vector2(9.0, 9.0)
	_meter_icon.position = Vector2(BAR.end.x + BAR_ICON_GAP,
			BAR.position.y + (BAR.size.y - 9.0) * 0.5)
	_meter_mark.size = Vector2(7.0, 7.0)
	_build_lives()

	_meter_track.visible = false
	_meter_fill.visible = false
	_meter_mark.visible = false
	_meter_icon.visible = false
	_stamina.visible = false
	_pips.visible = false
	_toast.modulate.a = 0.0
	_prompt.modulate.a = 0.0
	_multiplier.visible = false
	_alarm.modulate.a = 0.0
	_lives.visible = false
	_timer.visible = false


func _process(delta: float) -> void:
	# Scores roll rather than snap; it makes a pickup feel like it landed.
	if not is_equal_approx(_shown_score, float(_target_score)):
		_shown_score = move_toward(_shown_score, float(_target_score),
				maxf(240.0, absf(_target_score - _shown_score) * 6.0) * delta)
		_score.text = "%d" % roundi(_shown_score)

	if _alarm.modulate.a > 0.001:
		_alarm_pulse += delta * 6.0
		_alarm.modulate.a = 0.28 + 0.22 * sin(_alarm_pulse)


func set_score(value: int) -> void:
	_target_score = value


## Snaps the counter without the roll -- used when a minigame first opens.
func reset_score(value: int) -> void:
	_target_score = value
	_shown_score = float(value)
	_score.text = "%d" % value


## The badge next to the score, replacing the old "CHAIN x3" sentences. Hidden
## at x1, so it only exists while it means something.
func set_multiplier(value: int) -> void:
	if value == _multiplier_value:
		return
	_multiplier_value = value
	_multiplier.visible = value > 1
	if value <= 1:
		return
	_multiplier.text = "x%d" % value
	_multiplier.scale = Vector2(1.5, 1.5)
	_multiplier.pivot_offset = _multiplier.size / 2.0
	create_tween().tween_property(_multiplier, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## `kind` picks the icon that sits beside the bar, so the bar never needs a word.
## The crossing bar. It used to be 77x7 tucked under the score in the corner,
## which is small enough that a player can finish a run without ever noticing
## there was a progress meter at all. It is now a band across the top with a
## marker riding the fill, because a goal you can watch yourself approaching
## is one of the better ways to make a scene feel like it is going somewhere.
func set_meter(ratio: float, kind: StringName = &"time") -> void:
	var value := clampf(ratio, 0.0, 1.0)
	_meter_track.visible = true
	_meter_fill.visible = true
	# Width is driven straight from the constant, so the fill cannot outrun the
	# track and the track cannot outrun the screen.
	_meter_fill.size = Vector2(BAR.size.x * value, BAR.size.y)

	_meter_mark.visible = true
	_meter_mark.position = Vector2(
			BAR.position.x + BAR.size.x * value - _meter_mark.size.x * 0.5,
			BAR.position.y + (BAR.size.y - _meter_mark.size.y) * 0.5)

	var path: String = METER_ICONS.get(kind, METER_ICONS[&"time"])
	var icon := load(path)
	if icon != null:
		_meter_icon.texture = icon
		_meter_icon.visible = true


func hide_meter() -> void:
	_meter_mark.visible = false
	_meter_track.visible = false
	_meter_fill.visible = false
	_meter_icon.visible = false


## --- lives -------------------------------------------------------------------

## Five segments and a plate behind them, all placed from the constants above.
## Built once; `set_lives` only ever swaps textures, so there is nothing to go
## wrong on the frame a life is lost.
func _build_lives() -> void:
	var span := LIFE_SEGMENT.x * 5.0 + LIFE_GAP * 4.0
	_lives.position = LIFE_ORIGIN - Vector2.ONE * LIFE_PAD
	_lives.size = Vector2(span, LIFE_SEGMENT.y) + Vector2.ONE * LIFE_PAD * 2.0

	var plate := ColorRect.new()
	plate.name = "Plate"
	plate.color = Color(0.07, 0.06, 0.12, 0.72)
	plate.size = _lives.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lives.add_child(plate)

	for i in 5:
		var segment := TextureRect.new()
		segment.texture = LIFE_TEXTURES[2]
		segment.stretch_mode = TextureRect.STRETCH_SCALE
		segment.position = Vector2(LIFE_PAD + float(i) * (LIFE_SEGMENT.x + LIFE_GAP),
				LIFE_PAD)
		segment.size = LIFE_SEGMENT
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lives.add_child(segment)
		_life_segments.append(segment)


## `halves` counts half-lives, so a segment can show full, half or empty. It is
## the losing of one that has to read, not the number itself: the segment that
## changed flashes and punches out, which is the only animation on the bar.
func set_lives(halves: int, max_halves: int = 10) -> void:
	_lives.visible = true
	var total := maxi(max_halves, 2)
	var left := clampi(halves, 0, total)
	var previous := _shown_halves
	_shown_halves = left

	for i in _life_segments.size():
		var segment := _life_segments[i]
		segment.visible = i * 2 < total
		var fill := clampi(left - i * 2, 0, 2)
		segment.texture = LIFE_TEXTURES[fill]
		# Only the last segment with anything in it gets to look urgent.
		var critical := left <= 2 and fill > 0
		segment.modulate = Color(1, 0.55, 0.5) if critical else Color.WHITE

	if previous < 0 or left >= previous:
		return
	# The segment that just changed -- the one holding the lowest remaining
	# half -- is the one worth drawing the eye to.
	var hit := clampi((maxi(left, 1) - 1) / 2, 0, _life_segments.size() - 1)
	var segment := _life_segments[hit]
	segment.pivot_offset = segment.size * 0.5
	segment.scale = Vector2(1.5, 1.5)
	create_tween().tween_property(segment, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_lives() -> void:
	_lives.visible = false


## --- survival clock ----------------------------------------------------------

## Counts up, not down, because in an endless game the number IS the score's
## other half. Small and under the score rather than across the top: it is a
## thing you check between hops, not something to watch.
func set_timer(seconds: float) -> void:
	_timer.visible = true
	var whole := int(seconds)
	_timer.text = "%d:%02d" % [whole / 60, whole % 60]


func hide_timer() -> void:
	_timer.visible = false


## A row of dots for sequence progress -- Echo Hollow's "stone 2 of 5" without
## the reading. Pass count 0 to hide it.
func set_pips(filled: int, count: int, colour := Color(0.8, 1.0, 0.85)) -> void:
	_pips.visible = count > 0
	if count <= 0:
		return
	while _pips.get_child_count() < count:
		var pip := TextureRect.new()
		pip.texture = load("res://assets/game/ui/pip.png")
		pip.custom_minimum_size = Vector2(7, 7)
		pip.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		_pips.add_child(pip)
	for i in _pips.get_child_count():
		var pip := _pips.get_child(i) as TextureRect
		pip.visible = i < count
		pip.modulate = colour if i < filled else Color(0.55, 0.53, 0.66, 0.85)


## Shown only by the games with sprint. Flashes red while spent, so the reason
## the player suddenly stopped accelerating is visible rather than mysterious.
func set_stamina(value: float, is_exhausted: bool) -> void:
	_stamina.visible = true
	_stamina.value = clampf(value, 0.0, 1.0) * 100.0
	_stamina.modulate = Color(1, 0.42, 0.38) if is_exhausted else Color(0.55, 0.9, 1.0)


func hide_stamina() -> void:
	_stamina.visible = false


## Red pulse in from the screen edges. Used for the meadow's dusk scramble --
## an alarm you feel at the edge of vision rather than a line you have to read.
func set_alarm(intensity: float) -> void:
	if intensity <= 0.0:
		_alarm.modulate.a = 0.0
	elif _alarm.modulate.a <= 0.001:
		_alarm.modulate.a = 0.3


## Big centred flash, for events that are not tied to an object: PHASE 2,
## CHIME BURST, DUSK. Per-object scoring goes through MiniGame.pop() instead.
func toast(text: String, color: Color = Color.WHITE, hold: float = 0.9) -> void:
	_toast.text = text
	_toast.modulate = color
	_toast.modulate.a = 0.0
	_toast.scale = Vector2(0.85, 0.85)
	_toast.pivot_offset = _toast.size / 2.0

	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.10)
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.set_parallel(false)
	_toast_tween.tween_interval(hold)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.25)


func prompt(text: String) -> void:
	if _prompt.text == text and _prompt.modulate.a > 0.5:
		return
	_prompt.text = text
	create_tween().tween_property(_prompt, "modulate:a", 1.0, 0.15)


func clear_prompt() -> void:
	if _prompt.modulate.a < 0.01:
		return
	_prompt.text = ""
	create_tween().tween_property(_prompt, "modulate:a", 0.0, 0.15)
