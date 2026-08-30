class_name Juice
extends RefCounted
## Screen shake, flashes and hit-stop.
##
## All static, all taking the node they act on, so nothing needs an autoload and
## a minigame can use them without wiring anything up. Kept deliberately small:
## juice that draws attention to itself stops being juice.

## Shakes a camera, or the whole scene if it has no camera. `amount` is pixels.
static func shake(node: Node, amount: float = 3.0, seconds: float = 0.22) -> void:
	var target := _shakeable(node)
	if target == null:
		return
	var origin: Vector2 = target.get_meta(&"shake_origin", target.position)
	target.set_meta(&"shake_origin", origin)

	var tween := target.create_tween()
	var steps := maxi(int(seconds / 0.04), 3)
	for i in steps:
		# Decaying, and alternating sides, so it reads as an impact rather than
		# a wobble.
		var falloff := amount * (1.0 - float(i) / steps)
		tween.tween_property(target, "position", origin + Vector2(
				randf_range(-falloff, falloff), randf_range(-falloff, falloff)), 0.04)
	tween.tween_property(target, "position", origin, 0.05)


## A full-screen colour wash that fades out fast. For impacts worth noticing.
static func flash(node: Node, colour: Color = Color(1, 1, 1, 0.5),
		seconds: float = 0.18) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	var rect := ColorRect.new()
	rect.color = colour
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	node.add_child(layer)

	var tween := node.create_tween()
	tween.tween_property(rect, "color:a", 0.0, seconds)
	tween.tween_callback(layer.queue_free)


## Freezes time briefly. Used sparingly -- on a multi-kill and nothing else --
## because it is the strongest tool here and it stops being special if it fires
## every few seconds.
static func hit_stop(node: Node, seconds: float = 0.07) -> void:
	if Engine.time_scale < 1.0:
		return                                    # debug slow-mo is on; leave it
	Engine.time_scale = 0.0001
	await node.get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


static func _shakeable(node: Node) -> Node2D:
	var camera := node.get_node_or_null(^"Player/Camera")
	if camera is Node2D:
		return camera
	return node as Node2D
