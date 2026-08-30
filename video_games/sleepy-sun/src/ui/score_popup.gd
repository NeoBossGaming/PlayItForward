class_name ScorePopup
extends Node2D
## A number that floats up from the thing that caused it.
##
## Feedback used to land in the middle of the screen no matter what produced it,
## which meant the player had to work out *why* they had just scored. Popping the
## number at the chime, the fish, the crow tells them in the same glance.
##
## Gains rise from the object. Losses pop on the player, because that is who the
## penalty happened to, and they shake rather than drift so the two never read as
## the same event.

const RISE := 22.0
const LIFE := 0.85

@onready var _label: Label = $Label

var amount: int = 0
var multiplier: int = 1
var is_penalty: bool = false
## Optional word shown above the number, e.g. NERVE or DOUBLE.
var caption: String = ""


func _ready() -> void:
	var text := ""
	if caption != "":
		text += caption + "\n"
	text += ("%d" % amount) if amount < 0 else ("+%d" % amount)
	if multiplier > 1:
		text += " x%d" % multiplier
	_label.text = text
	_label.theme_type_variation = &"ScorePop"
	_label.add_theme_color_override(&"font_color",
			Color(1, 0.45, 0.42) if is_penalty else Color(1, 0.93, 0.6))

	z_index = 60
	scale = Vector2(0.4, 0.4)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.14) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if is_penalty:
		# A short hard shake, so a loss never reads like a gain.
		var shake := create_tween()
		for i in 4:
			shake.tween_property(_label, "position:x", 5.0 if i % 2 == 0 else -5.0, 0.045)
		shake.tween_property(_label, "position:x", 0.0, 0.05)
	else:
		var drift := create_tween()
		drift.tween_property(self, "position:y", position.y - RISE, LIFE) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var fade := create_tween()
	fade.tween_interval(LIFE * 0.55)
	fade.tween_property(self, "modulate:a", 0.0, LIFE * 0.45)
	fade.tween_callback(queue_free)
