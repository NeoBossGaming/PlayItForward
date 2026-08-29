class_name Wait
extends RefCounted
## Timers that belong to a node instead of to the scene tree.
##
## `get_tree().create_timer()` outlives the node that started it, so a scene
## change during an `await` leaves an orphaned SceneTreeTimer and a coroutine
## that never resumes. Parenting the timer to the node means both die together,
## which matters here because Router can swap scenes at any moment.

## await Wait.on(self, 0.5)
static func on(node: Node, seconds: float) -> Signal:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(seconds, 0.001)
	timer.autostart = true
	node.add_child(timer)
	timer.timeout.connect(timer.queue_free, CONNECT_ONE_SHOT)
	return timer.timeout
