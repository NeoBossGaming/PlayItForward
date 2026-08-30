class_name IntroCard
extends CanvasLayer
## The card you were dealt flies in and opens into the game's title card.
##
## Replaces the permanent objective line that used to sit at the top of every
## minigame. Nobody reads a sentence that has been on screen for forty seconds,
## but they will read one that arrives, holds, and leaves -- and putting it on
## the same card that was just dealt makes the draw and the game feel like one
## motion rather than two unrelated screens.
##
## Skippable with any button: a repeat player already knows the rules and should
## never be held up by them.

signal dismissed

## Where the cards sit on the draw table, so the flight starts from the right
## slot rather than from nowhere. Mirrors draw.gd's CARD_X / CARD_Y.
const TABLE_X: Array[float] = [80.0, 240.0, 400.0]
const TABLE_Y := 162.0

const FLY_TIME := 0.42
const OPEN_TIME := 0.26
const HOLD := 1.4

@onready var _dim: ColorRect = $Dim
@onready var _card: Control = $Card
@onready var _frame: NinePatchRect = $Card/Frame
@onready var _icon: TextureRect = $Card/Icon
@onready var _title: Label = $Card/Title
@onready var _rule: Label = $Card/Rule
@onready var _hint: Label = $Card/Hint

var _finished: bool = false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


## Plays the whole sequence and returns when the card is gone.
func play(id: StringName, control_hint: String) -> void:
	var entry := Game.definition(id)
	if entry.is_empty():
		dismissed.emit()
		return

	var colour: Color = entry["color"]
	_title.text = String(entry["title"]).to_upper()
	_rule.text = entry["blurb"]
	_hint.text = control_hint
	_icon.texture = load("res://assets/game/ui/card_icon_%s.png" % id)
	_icon.modulate = colour
	_frame.modulate = colour
	_title.add_theme_color_override(&"font_color", colour.lerp(Color.WHITE, 0.45))

	# Start as the small card, in the slot it was dealt to.
	var slot: int = clampi(Game.playlist_index, 0, TABLE_X.size() - 1)
	_card.pivot_offset = _card.size / 2.0
	_card.position = Vector2(TABLE_X[slot], TABLE_Y) - _card.size / 2.0
	_card.scale = Vector2(0.42, 0.42)
	_card.rotation = deg_to_rad(-4.0)
	_dim.modulate.a = 0.0
	_rule.modulate.a = 0.0
	_hint.modulate.a = 0.0

	var centre := Vector2(240, 135) - _card.size / 2.0

	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_property(_dim, "modulate:a", 1.0, FLY_TIME * 0.7)
	fly.tween_property(_card, "position", centre, FLY_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	fly.tween_property(_card, "scale", Vector2.ONE, FLY_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fly.tween_property(_card, "rotation", 0.0, FLY_TIME)
	await _wait(fly)
	if _finished:
		return
	Audio.sfx(&"confirm", 1.1)

	# Then it opens out: the rule and the control hint fade up.
	var open := create_tween()
	open.set_parallel(true)
	open.tween_property(_rule, "modulate:a", 1.0, OPEN_TIME)
	open.tween_property(_hint, "modulate:a", 1.0, OPEN_TIME)
	await _wait(open)
	if _finished:
		return

	await _hold_for(HOLD)
	_dismiss()


func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed(&"act") or event.is_action_pressed(&"start") \
			or event.is_action_pressed(&"back"):
		_dismiss()
		get_viewport().set_input_as_handled()


func _dismiss() -> void:
	if _finished:
		return
	_finished = true
	var out := create_tween()
	out.set_parallel(true)
	out.tween_property(_card, "scale", Vector2(1.25, 1.25), 0.18)
	out.tween_property(_card, "modulate:a", 0.0, 0.18)
	out.tween_property(_dim, "modulate:a", 0.0, 0.22)
	out.chain().tween_callback(func() -> void:
		dismissed.emit()
		queue_free())


## Awaits a tween, but gives up immediately if the card was skipped.
func _wait(tween: Tween) -> void:
	while tween.is_running() and not _finished:
		await get_tree().process_frame


func _hold_for(seconds: float) -> void:
	var clock := 0.0
	while clock < seconds and not _finished:
		await get_tree().process_frame
		clock += get_process_delta_time()
