extends MiniGame
## Temple Bell -- strike on the beat, and it only gets faster.
##
## The only game in the pool that is not about moving, which is exactly why it
## earns its slot: after two or three movement games in a row a card that asks
## for something else entirely makes the draw feel worth spinning.
##
## Markers close in on a ring around the bell and the player hits `act` as they
## land. Everything is driven by a game clock rather than an audio stream --
## there is no music track to sync to, so there is no drift to lose to, and the
## synthesised tone is played *by* the beat instead of the beat chasing it.
##
## No fail state: a missed beat breaks the chain and nothing else.

const ROUND_SECONDS := 55.0

const BELL := Vector2(320, 186)
const RING_RADIUS := 68.0
const SPAWN_RADIUS := 210.0
const APPROACH_SECONDS := 1.6      ## how long a marker takes to reach the ring

## Beats per second, eased across the round. The ramp is the difficulty.
const TEMPO := Vector2(1.1, 2.4)

## The ring sprite is 48px wide and has to sit at RING_RADIUS, so its scale is
## derived rather than authored -- the earlier hard-coded pulse overwrote the
## scene's scale and hid the ring entirely behind the bell.
const RING_SCALE := RING_RADIUS * 2.0 / 48.0

const WINDOW_PERFECT := 0.09
const WINDOW_GOOD := 0.20

## Small per-beat values on purpose: a 55-second round is roughly 95 beats, so
## anything larger runs away from every other game in the pool.
const SCORE_PERFECT := 12
const SCORE_GOOD := 6
const CHAIN_PER_LEVEL := 6
const CHAIN_MAX := 3

@onready var _player: TopDownPlayer = $Player
@onready var _hud: HUD = $HUD
@onready var _bell: Sprite2D = $Bell
@onready var _ring: Sprite2D = $Ring
@onready var _markers_root: Node2D = $Markers

var _time_left: float = ROUND_SECONDS
var _beat_timer: float = 1.2

var _score: int = 0
var _perfect: int = 0
var _good: int = 0
var _missed: int = 0
var _chain: int = 0
var _best_chain: int = 0

var _marker_texture := preload("res://assets/game/temple_bell/marker.png")


func _ready() -> void:
	_hud.set_title("Temple Bell")
	_hud.reset_score(0)
	_hud.set_objective("Strike as each mark touches the ring.")
	_player.freeze()
	_player.set_facing(&"right")


func begin() -> void:
	super.begin()
	_hud.toast("LISTEN", Color(1, 0.85, 0.55), 0.8)


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_time_left = maxf(_time_left - delta, 0.0)
	_hud.set_meter(_time_left / ROUND_SECONDS, "%ds left" % ceili(_time_left))
	if _time_left <= 0.0:
		_finish()
		return

	_ring.scale = Vector2.ONE * (RING_SCALE + 0.06 * sin(elapsed * 6.0))
	_tick_beats(delta)
	_tick_markers(delta)


func _unhandled_input(event: InputEvent) -> void:
	if running and event.is_action_pressed(&"act"):
		_strike()


## Beats speed up steadily. The player is never asked to learn a pattern, only
## to keep up, which is the right kind of hard for sixty seconds at a cabinet.
func _tempo() -> float:
	return lerpf(TEMPO.x, TEMPO.y, 1.0 - _time_left / ROUND_SECONDS)


func _tick_beats(delta: float) -> void:
	_beat_timer -= delta
	if _beat_timer > 0.0:
		return
	_beat_timer = 1.0 / _tempo()
	_spawn_marker()


func _spawn_marker() -> void:
	var angle := randf() * TAU
	var marker := Sprite2D.new()
	marker.texture = _marker_texture
	marker.position = BELL + Vector2.RIGHT.rotated(angle) * SPAWN_RADIUS
	marker.set_meta(&"angle", angle)
	marker.set_meta(&"life", 0.0)
	marker.z_index = 6
	_markers_root.add_child(marker)


func _tick_markers(delta: float) -> void:
	for child in _markers_root.get_children():
		var marker := child as Sprite2D
		if marker == null or marker.has_meta(&"spent"):
			continue
		var life: float = float(marker.get_meta(&"life")) + delta
		marker.set_meta(&"life", life)

		var t := life / APPROACH_SECONDS
		var angle: float = marker.get_meta(&"angle")
		var radius := lerpf(SPAWN_RADIUS, RING_RADIUS, minf(t, 1.4))
		marker.position = BELL + Vector2.RIGHT.rotated(angle) * radius
		# Brightens as it arrives, so the eye is drawn to whichever is next.
		marker.modulate = Color(1, 1, 1).lerp(Color(1, 0.75, 0.6), clampf(t, 0.0, 1.0))
		marker.scale = Vector2.ONE * lerpf(0.7, 1.25, clampf(t, 0.0, 1.0))

		if life > APPROACH_SECONDS + WINDOW_GOOD:
			_miss(marker)


## The marker closest to landing, and how far off the beat it is (signed).
func _closest_marker() -> Sprite2D:
	var best: Sprite2D = null
	var best_error := INF
	for child in _markers_root.get_children():
		var marker := child as Sprite2D
		if marker == null or marker.has_meta(&"spent"):
			continue
		var error: float = absf(float(marker.get_meta(&"life")) - APPROACH_SECONDS)
		if error < best_error:
			best_error = error
			best = marker
	return best


func _strike() -> void:
	_swing()
	var marker := _closest_marker()
	if marker == null:
		return
	var error: float = absf(float(marker.get_meta(&"life")) - APPROACH_SECONDS)
	if error > WINDOW_GOOD:
		# Striking into empty air still breaks the chain -- mashing must cost.
		_break_chain()
		Audio.sfx(&"deny", 1.6)
		return

	marker.set_meta(&"spent", true)
	_chain += 1
	_best_chain = maxi(_best_chain, _chain)
	var multiplier := chain_multiplier()

	if error <= WINDOW_PERFECT:
		_perfect += 1
		_score += SCORE_PERFECT * multiplier
		_hud.toast("PERFECT   x%d" % multiplier, Color(1, 0.9, 0.5), 0.4)
		Audio.plate_note(2)
	else:
		_good += 1
		_score += SCORE_GOOD * multiplier
		_hud.toast("GOOD   x%d" % multiplier, Color(0.8, 0.95, 1.0), 0.35)
		Audio.plate_note(0)

	_hud.set_score(_score)
	_pop(marker)


func _miss(marker: Sprite2D) -> void:
	marker.set_meta(&"spent", true)
	_missed += 1
	_break_chain()
	var tween := create_tween()
	tween.tween_property(marker, "modulate:a", 0.0, 0.2)
	tween.tween_callback(marker.queue_free)


func _break_chain() -> void:
	if _chain >= CHAIN_PER_LEVEL:
		_hud.toast("CHAIN BROKEN", Color(1, 0.5, 0.45), 0.6)
	_chain = 0


func chain_multiplier() -> int:
	return clampi(1 + _chain / CHAIN_PER_LEVEL, 1, CHAIN_MAX)


func _pop(marker: Sprite2D) -> void:
	var tween := create_tween()
	tween.tween_property(marker, "scale", Vector2(2.2, 2.2), 0.16)
	tween.parallel().tween_property(marker, "modulate:a", 0.0, 0.16)
	tween.tween_callback(marker.queue_free)


func _swing() -> void:
	var tween := create_tween()
	tween.tween_property(_bell, "rotation", randf_range(-0.10, 0.10), 0.05)
	tween.tween_property(_bell, "rotation", 0.0, 0.45) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _finish() -> void:
	Audio.sfx(&"complete")
	finish(_score, {"perfect": _perfect, "good": _good, "missed": _missed,
			"chain": _best_chain})
