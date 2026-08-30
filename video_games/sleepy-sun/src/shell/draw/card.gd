class_name DrawCard
extends Node2D
## One card on the draw table.
##
## Three states it has to sell: spinning (a blur of faces), landing (a hard stop
## with a kick), and played (stamped with a score and stepped out of the way).
## The spin is deliberately face-cycling rather than a placeholder blur -- a
## player should catch glimpses of games they want and hope it lands there.

signal landed

const SPIN_FACE_SECONDS := 0.055
const LAND_KICK := 11.0

@onready var _frame: Sprite2D = $Frame
@onready var _icon: Sprite2D = $Icon
@onready var _title: Label = $Title
@onready var _blurb: Label = $Blurb
@onready var _score: Label = $Score
@onready var _number: Label = $Number

var id: StringName = &""

var _spinning: bool = false
var _spin_timer: float = 0.0
var _face: int = 0
var _home_y: float = 0.0


func _ready() -> void:
	_home_y = position.y
	_score.text = ""
	set_face_down()


func _process(delta: float) -> void:
	if not _spinning:
		return
	_spin_timer -= delta
	if _spin_timer > 0.0:
		return
	_spin_timer = SPIN_FACE_SECONDS
	_face = (_face + 1) % Game.MINIGAMES.size()
	_show(Game.MINIGAMES[_face])


func set_index(index: int) -> void:
	_number.text = "%d" % (index + 1)


func set_face_down() -> void:
	_icon.texture = load("res://assets/game/ui/card_icon_cave.png")
	_title.text = "?"
	_blurb.text = ""
	_icon.modulate = Color(0.4, 0.38, 0.5)
	_frame.modulate = Color(0.34, 0.32, 0.44)


func start_spin() -> void:
	_spinning = true
	_spin_timer = 0.0
	_face = randi() % Game.MINIGAMES.size()


## Stops on `card_id`. The kick and the thunk are what make a stop read as a
## stop rather than the animation simply ending.
func land_on(card_id: StringName) -> void:
	_spinning = false
	id = card_id
	_show(Game.definition(card_id))
	Audio.sfx(&"confirm", 0.75)

	var tween := create_tween()
	tween.tween_property(self, "position:y", _home_y + LAND_KICK, 0.07) \
			.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "position:y", _home_y, 0.34) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: landed.emit())


## Marks this card as already played, with what it scored.
func mark_played(score: int) -> void:
	_score.text = "%d" % score
	modulate = Color(0.62, 0.62, 0.70)
	scale = Vector2(0.88, 0.88)


## The card about to be played. Pulses so the eye lands on it immediately.
func mark_next() -> void:
	modulate = Color.WHITE
	scale = Vector2.ONE
	var tween := create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.45) \
			.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2.ONE, 0.45) \
			.set_trans(Tween.TRANS_SINE)


func _show(entry: Dictionary) -> void:
	if entry.is_empty():
		return
	var glyph := load("res://assets/game/ui/card_icon_%s.png" % entry["id"])
	if glyph != null:
		_icon.texture = glyph
	_title.text = String(entry["title"]).to_upper()
	_blurb.text = entry["blurb"]
	var colour: Color = entry["color"]
	_icon.modulate = colour
	_frame.modulate = colour.lerp(Color(0.16, 0.14, 0.22), 0.55)
