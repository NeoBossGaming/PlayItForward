@tool
class_name ScrollingTexture
extends Sprite2D
## A tiling, optionally animated backdrop built from one small tile.
##
## Cheaper than a TileMapLayer for a full-screen ground or water surface (one
## draw call, no tileset resource) and it can scroll sub-pixel, which is what
## sells the river current in Riverleap.

## Extra tile frames. If set, the sprite cycles through them for a shimmer.
@export var frames: Array[Texture2D] = []
@export var frames_per_second: float = 5.0
## Pixels per second the texture drifts. Positive Y scrolls downstream.
@export var scroll: Vector2 = Vector2.ZERO
@export var area: Vector2i = Vector2i(704, 424):
	set(value):
		area = value
		_apply_area()

var _time: float = 0.0
var _offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	centered = true
	region_enabled = true
	_apply_area()


func _apply_area() -> void:
	if not region_enabled:
		return
	region_rect = Rect2(_offset, Vector2(area))


func _process(delta: float) -> void:
	if scroll != Vector2.ZERO:
		_offset += scroll * delta
		# Wrap on the tile size so the offset never grows without bound.
		if texture != null:
			var size := Vector2(texture.get_size())
			_offset.x = fposmod(_offset.x, size.x)
			_offset.y = fposmod(_offset.y, size.y)
		_apply_area()

	if frames.size() > 1 and frames_per_second > 0.0:
		_time += delta
		var index := int(_time * frames_per_second) % frames.size()
		if texture != frames[index]:
			texture = frames[index]
			_apply_area()


## Nudges the drift directly, for one-off pushes rather than constant flow.
func add_offset(delta_offset: Vector2) -> void:
	_offset += delta_offset
	_apply_area()
