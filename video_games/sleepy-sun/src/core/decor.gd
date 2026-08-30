class_name Decor
extends Node2D
## Drifting background particles: dust, petals, leaves, fireflies, sparkles.
##
## Every scene wants some, and eight hand-rolled versions would drift apart, so
## there is one. Deliberately not a GPUParticles2D: at this scale a handful of
## sprites is cheaper on a Pi, and it keeps the whole thing legible and tunable
## from one script.

@export var texture: Texture2D
@export var count: int = 14
## Pixels per second. Positive Y falls, negative Y rises.
@export var drift: Vector2 = Vector2(-8.0, 10.0)
@export var area: Rect2 = Rect2(0, 0, 480, 270)
@export var tint: Color = Color(1, 1, 1, 0.5)
@export var scale_range: Vector2 = Vector2(0.7, 1.2)
## How far a mote swings side to side as it travels.
@export var sway: float = 6.0
@export var spin: bool = false
## Fade in and out over their life instead of popping at the edges.
@export var twinkle: bool = false

var _motes: Array[Sprite2D] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	if texture == null:
		return
	for i in count:
		var mote := Sprite2D.new()
		mote.texture = texture
		mote.modulate = tint
		mote.scale = Vector2.ONE * _rng.randf_range(scale_range.x, scale_range.y)
		mote.position = Vector2(
			_rng.randf_range(area.position.x, area.end.x),
			_rng.randf_range(area.position.y, area.end.y))
		mote.set_meta(&"phase", _rng.randf() * TAU)
		mote.set_meta(&"speed", _rng.randf_range(0.7, 1.35))
		add_child(mote)
		_motes.append(mote)


func _process(delta: float) -> void:
	for mote in _motes:
		var phase: float = float(mote.get_meta(&"phase")) + delta
		var speed: float = mote.get_meta(&"speed")
		mote.set_meta(&"phase", phase)

		mote.position += drift * speed * delta
		mote.position.x += sin(phase * 1.6) * sway * delta
		if spin:
			mote.rotation += delta * speed
		if twinkle:
			mote.modulate.a = tint.a * (0.45 + 0.55 * absf(sin(phase * 1.9)))

		# Wrap around rather than respawn, so the field never thins out.
		if mote.position.y > area.end.y + 8.0:
			mote.position = Vector2(_rng.randf_range(area.position.x, area.end.x),
					area.position.y - 8.0)
		elif mote.position.y < area.position.y - 8.0:
			mote.position = Vector2(_rng.randf_range(area.position.x, area.end.x),
					area.end.y + 8.0)
		if mote.position.x < area.position.x - 8.0:
			mote.position.x = area.end.x + 8.0
		elif mote.position.x > area.end.x + 8.0:
			mote.position.x = area.position.x - 8.0
