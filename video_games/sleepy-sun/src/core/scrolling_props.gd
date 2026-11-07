class_name ScrollingProps
extends Node2D
## Carries hand-placed children past the camera and wraps them around.
##
## There was a gap here. `ScrollingTexture` scrolls a region_rect, so anything
## parented to it never moves -- which is why Riverleap's trees sat perfectly
## still on a bank that was racing past them. `Decor` scrolls a field, but it
## generates its own identical motes and cannot carry a tree, a reed and a
## twig. This node moves its own children, whatever they are.

## Pixels per second. Positive Y carries children down the screen.
@export var scroll: Vector2 = Vector2(0, 50)
## The band children wrap within, in this node's local space: y from, y to.
## Wants to be a little outside the screen at both ends so nothing pops.
@export var span: Vector2 = Vector2(-48, 318)
## Fraction each child's speed may differ from `scroll`. A rigid block of
## props reads as a photograph being slid; a little variance reads as objects.
@export_range(0.0, 0.9) var speed_variance: float = 0.0
## Re-rolls a child's x within this band when it wraps. Zero keeps its own x.
@export var jitter_x: Vector2 = Vector2.ZERO
## Amplitude of a slow bob applied on top of the travel, for things afloat.
@export var bob: float = 0.0
## Radians per second of slow turn, for things afloat.
@export var spin: float = 0.0

var _rng := RandomNumberGenerator.new()
var _props: Array[Node2D] = []


func _ready() -> void:
	_rng.randomize()
	for child in get_children():
		var prop := child as Node2D
		if prop == null:
			continue
		prop.set_meta(&"speed", 1.0 + _rng.randf_range(-speed_variance, speed_variance))
		prop.set_meta(&"phase", _rng.randf() * TAU)
		prop.set_meta(&"base_y", prop.position.y)
		if spin != 0.0:
			prop.set_meta(&"turn", _rng.randf_range(-1.0, 1.0))
		_props.append(prop)


func _process(delta: float) -> void:
	var height := span.y - span.x
	if height <= 0.0:
		return
	for prop in _props:
		if not is_instance_valid(prop):
			continue
		var speed: float = prop.get_meta(&"speed", 1.0)
		prop.position += scroll * speed * delta

		if bob != 0.0 or spin != 0.0:
			var phase: float = float(prop.get_meta(&"phase")) + delta
			prop.set_meta(&"phase", phase)
			if spin != 0.0:
				prop.rotation += spin * float(prop.get_meta(&"turn", 1.0)) * delta

		# Wrap rather than respawn, so the band never thins out.
		if prop.position.y > span.y:
			prop.position.y -= height
			_rejitter(prop)
		elif prop.position.y < span.x:
			prop.position.y += height
			_rejitter(prop)

		if bob != 0.0:
			var phase: float = prop.get_meta(&"phase", 0.0)
			prop.position.x += sin(phase * 1.3) * bob * delta


func _rejitter(prop: Node2D) -> void:
	if jitter_x == Vector2.ZERO:
		return
	prop.position.x = _rng.randf_range(jitter_x.x, jitter_x.y)
