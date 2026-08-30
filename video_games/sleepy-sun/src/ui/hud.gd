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

const METER_ICONS := {
	&"dusk": "res://assets/game/ui/icon_sun.png",
	&"time": "res://assets/game/ui/icon_clock.png",
	&"crop": "res://assets/game/ui/icon_wheat.png",
	&"lantern": "res://assets/game/ui/icon_lantern.png",
	&"far bank": "res://assets/game/ui/icon_flag.png",
	&"chamber": "res://assets/game/ui/icon_door.png",
}

@onready var _score: Label = $Root/Score
@onready var _multiplier: Label = $Root/Multiplier
@onready var _meter: ProgressBar = $Root/Meter
@onready var _meter_icon: TextureRect = $Root/MeterIcon
@onready var _stamina: ProgressBar = $Root/Stamina
@onready var _pips: HBoxContainer = $Root/Pips
@onready var _toast: Label = $Root/Toast
@onready var _prompt: Label = $Root/Prompt
@onready var _alarm: TextureRect = $Root/Alarm

var _shown_score: float = 0.0
var _target_score: int = 0
var _toast_tween: Tween
var _multiplier_value: int = 1
var _alarm_pulse: float = 0.0


func _ready() -> void:
	_meter.visible = false
	_meter_icon.visible = false
	_stamina.visible = false
	_pips.visible = false
	_toast.modulate.a = 0.0
	_prompt.modulate.a = 0.0
	_multiplier.visible = false
	_alarm.modulate.a = 0.0


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
func set_meter(ratio: float, kind: StringName = &"time") -> void:
	_meter.visible = true
	_meter.value = clampf(ratio, 0.0, 1.0) * 100.0
	var path: String = METER_ICONS.get(kind, METER_ICONS[&"time"])
	var icon := load(path)
	if icon != null:
		_meter_icon.texture = icon
		_meter_icon.visible = true


func hide_meter() -> void:
	_meter.visible = false
	_meter_icon.visible = false


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
