class_name HUD
extends CanvasLayer
## Shared in-game overlay: objective, score, a progress meter, toasts, prompts.
##
## Every minigame instances this and talks to it through these methods, so all
## four read the same way to a player who has only just walked up to the cabinet.

@onready var _title: Label = $Root/Top/Title
@onready var _objective: Label = $Root/Top/Objective
@onready var _score: Label = $Root/Top/Score
@onready var _meter: ProgressBar = $Root/Meter
@onready var _meter_label: Label = $Root/MeterLabel
@onready var _toast: Label = $Root/Toast
@onready var _prompt: Label = $Root/Prompt

var _shown_score: float = 0.0
var _target_score: int = 0
var _toast_tween: Tween


func _ready() -> void:
	_meter.visible = false
	_meter_label.visible = false
	_toast.modulate.a = 0.0
	_prompt.modulate.a = 0.0


func _process(delta: float) -> void:
	# Scores roll rather than snap; it makes a pickup feel like it landed.
	if not is_equal_approx(_shown_score, float(_target_score)):
		_shown_score = move_toward(_shown_score, float(_target_score),
				maxf(240.0, absf(_target_score - _shown_score) * 6.0) * delta)
		_score.text = "%d" % roundi(_shown_score)


func set_title(text: String) -> void:
	_title.text = text.to_upper()


func set_objective(text: String) -> void:
	_objective.text = text


func set_score(value: int) -> void:
	_target_score = value


## Snaps the counter without the roll -- used when a minigame first opens.
func reset_score(value: int) -> void:
	_target_score = value
	_shown_score = float(value)
	_score.text = "%d" % value


func set_meter(ratio: float, label: String = "") -> void:
	_meter.visible = true
	_meter.value = clampf(ratio, 0.0, 1.0) * 100.0
	_meter_label.visible = label != ""
	_meter_label.text = label


func hide_meter() -> void:
	_meter.visible = false
	_meter_label.visible = false


## Big centred flash. Used for "SPOTTED!", "+150", "STAGE 3" and so on.
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
