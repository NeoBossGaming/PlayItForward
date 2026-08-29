class_name HubPortal
extends Area2D
## One signposted minigame entrance in the village.
##
## Shows its name on approach, lights a star once its minigame has been played,
## and reports the interaction upward. It never loads a scene itself.

signal entered(id: StringName)

@export var minigame_id: StringName = &""

@onready var _label: Label = $Label
@onready var _score_label: Label = $ScoreLabel
@onready var _star: Sprite2D = $Star
@onready var _sign: Sprite2D = $Sign

var _player_inside: bool = false
var _bob: float = 0.0


func _ready() -> void:
	_bob = randf() * TAU
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var entry := Game.definition(minigame_id)
	_label.text = String(entry.get("title", "?"))
	_label.modulate = entry.get("color", Color.WHITE)
	refresh()


func _process(delta: float) -> void:
	_bob += delta * 2.4
	_star.position.y = -40.0 + sin(_bob) * 2.0
	# The prompt only floats up when you are close enough to act on it.
	_label.modulate.a = move_toward(_label.modulate.a,
			1.0 if _player_inside else 0.55, delta * 4.0)


func refresh() -> void:
	var played := Game.has_played(minigame_id)
	_star.texture = load("res://assets/game/ui/star_%s.png" % ("on" if played else "off"))
	_score_label.visible = played
	if played:
		_score_label.text = "%d" % Game.score_for(minigame_id)
	# A finished chore reads as finished: its signpost stops competing for attention.
	_sign.modulate = Color(0.62, 0.62, 0.7) if played else Color.WHITE


func is_player_inside() -> bool:
	return _player_inside


func try_enter() -> bool:
	if not _player_inside:
		return false
	entered.emit(minigame_id)
	return true


func _on_body_entered(body: Node2D) -> void:
	if body is TopDownPlayer:
		_player_inside = true
		Audio.sfx(&"tick")


func _on_body_exited(body: Node2D) -> void:
	if body is TopDownPlayer:
		_player_inside = false
