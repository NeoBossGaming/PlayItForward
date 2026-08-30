extends MiniGame
## Temple Bell -- strike on the beat, and it only gets faster.
##
## Two phases, because one verb for a whole minute is thin:
##
##   Phase 1  rooted at the bell. Pure rhythm, learn the timing.
##   Phase 2  free to move, and the arena starts dropping coins and powerups.
##
## **A strike only registers while you are inside the ring.** That single rule is
## what makes phase 2 a multitask instead of a free bonus round: every trip out
## for a pickup is beats you are not there to hit, and Chime Burst exists so a
## trip that went badly is recoverable.
##
## Everything is driven by a game clock rather than an audio stream -- there is
## no music track to sync to, so there is no drift to lose to, and the
## synthesised tone is played *by* the beat instead of the beat chasing it.
##
## No fail state: a missed beat breaks the chain and nothing else.

const ROUND_SECONDS := 55.0
## When the player is let off the leash.
const PHASE_TWO_AT := 25.0
const ARENA := Rect2(30, 50, 420, 190)

const BELL := Vector2(240, 140)
const RING_RADIUS := 52.0
const SPAWN_RADIUS := 158.0
const APPROACH_SECONDS := 1.6      ## how long a marker takes to reach the ring

## Beats per second at the start and end of each phase. Phase 2 picks up where
## phase 1 left off and keeps climbing.
const TEMPO_PHASE_ONE := Vector2(1.1, 1.9)
## Phase 2 *eases off* the tempo rather than piling on. At 1.9-2.6 beats/s a
## round trip to a pickup cost five or six marks, so leaving the bell was never
## worth it and the phase collapsed back into phase 1 with extra scenery. The
## difficulty in phase 2 is the split attention, not the speed.
const TEMPO_PHASE_TWO := Vector2(1.3, 1.9)

## How far from the bell a strike still counts. Slightly wider than the ring so
## the boundary is forgiving rather than a knife edge.
const STRIKE_RANGE := RING_RADIUS + 22.0

## Pickups sit just beyond the strike ring -- far enough that fetching one costs
## a mark or two, close enough that the trip is a decision rather than a
## sacrifice.
const PICKUP_MIN_REACH := 8.0
const PICKUP_MAX_REACH := 45.0
const PICKUP_INTERVAL := Vector2(2.2, 1.4)
const PICKUP_RADIUS := 14.0
const POWERUP_SECONDS := 6.0
const FOCUS_WINDOW_BONUS := 1.9

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
@onready var _pickups_root: Node2D = $Pickups

var _time_left: float = ROUND_SECONDS
var _beat_timer: float = 1.2

var _score: int = 0
var _perfect: int = 0
var _good: int = 0
var _missed: int = 0
var _chain: int = 0
var _best_chain: int = 0
var _phase_two: bool = false
var _pickup_timer: float = 2.0
var _coins: int = 0
var _focus_left: float = 0.0
var _double_left: float = 0.0

var _marker_texture := preload("res://assets/game/temple_bell/marker.png")
var _pickup_scene := preload("res://src/minigames/temple_bell/pickup.tscn")


func _ready() -> void:
	_hud.set_title("Temple Bell")
	_hud.reset_score(0)
	_hud.set_objective("Strike as each mark touches the ring.")
	_player.freeze()
	_player.set_facing(&"up")
	# Quicker on his feet than the walking games: phase 2 is a dash out and back,
	# and it has to fit between two beats.
	_player.speed = 95.0


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

	if not _phase_two and elapsed >= PHASE_TWO_AT:
		_begin_phase_two()

	_ring.scale = Vector2.ONE * (RING_SCALE + 0.06 * sin(elapsed * 6.0))
	_tick_beats(delta)
	_tick_markers(delta)

	if _phase_two:
		_player.position = _player.position.clamp(ARENA.position, ARENA.end)
		_tick_pickups(delta)
		_tick_powerups(delta)
		# In range or not is the whole tension, so it is never ambiguous.
		var in_range := _in_strike_range()
		_ring.modulate.a = 0.75 if in_range else 0.3
		_hud.set_objective("PHASE 2  -  %s" % ("in range, strike!" if in_range
				else "get back to the bell!"))


func _unhandled_input(event: InputEvent) -> void:
	if running and event.is_action_pressed(&"act"):
		_strike()


## Beats speed up steadily. The player is never asked to learn a pattern, only
## to keep up, which is the right kind of hard for a minute at a cabinet.
func _tempo() -> float:
	if not _phase_two:
		return lerpf(TEMPO_PHASE_ONE.x, TEMPO_PHASE_ONE.y,
				clampf(elapsed / PHASE_TWO_AT, 0.0, 1.0))
	var t := clampf((elapsed - PHASE_TWO_AT) / (ROUND_SECONDS - PHASE_TWO_AT), 0.0, 1.0)
	return lerpf(TEMPO_PHASE_TWO.x, TEMPO_PHASE_TWO.y, t)


func _in_strike_range() -> bool:
	return not _phase_two or _player.position.distance_to(BELL) <= STRIKE_RANGE


func _begin_phase_two() -> void:
	_phase_two = true
	_player.unfreeze()
	Audio.sfx(&"complete", 1.2)
	_hud.toast("PHASE 2  -  MOVE!", Color(1, 0.85, 0.5), 1.4)


# --- phase two: coins and powerups ------------------------------------------

func _tick_pickups(delta: float) -> void:
	_pickup_timer -= delta
	if _pickup_timer <= 0.0:
		var t := clampf((elapsed - PHASE_TWO_AT) / (ROUND_SECONDS - PHASE_TWO_AT), 0.0, 1.0)
		_pickup_timer = lerpf(PICKUP_INTERVAL.x, PICKUP_INTERVAL.y, t)
		_spawn_pickup()

	for child in _pickups_root.get_children():
		var pickup := child as BellPickup
		if pickup == null:
			continue
		if pickup.position.distance_to(_player.position) < PICKUP_RADIUS:
			_take(pickup)


## Always outside the ring: a pickup you could reach without leaving the bell
## would cost nothing, and the cost is the point.
func _spawn_pickup() -> void:
	var pickup: BellPickup = _pickup_scene.instantiate()
	var roll := randf()
	if roll < 0.55:
		pickup.kind = BellPickup.Kind.COIN
	elif roll < 0.78:
		pickup.kind = BellPickup.Kind.BURST
	elif roll < 0.90:
		pickup.kind = BellPickup.Kind.FOCUS
	else:
		pickup.kind = BellPickup.Kind.DOUBLE

	for attempt in 24:
		var reach := STRIKE_RANGE + randf_range(PICKUP_MIN_REACH, PICKUP_MAX_REACH)
		var point := BELL + Vector2(reach, 0).rotated(randf() * TAU)
		pickup.position = point
		if ARENA.grow(-8.0).has_point(point):
			break
	_pickups_root.add_child(pickup)


func _take(pickup: BellPickup) -> void:
	match pickup.kind:
		BellPickup.Kind.COIN:
			_coins += 1
			_score += pickup.value() * (2 if _double_left > 0.0 else 1)
			_hud.set_score(_score)
			Audio.sfx(&"pickup", 1.2)
			_hud.toast("+%d" % pickup.value(), Color(1, 0.92, 0.55), 0.4)
		BellPickup.Kind.BURST:
			_chime_burst()
		BellPickup.Kind.FOCUS:
			_focus_left = POWERUP_SECONDS
			Audio.sfx(&"confirm", 1.4)
			_hud.toast("FOCUS", Color(0.7, 1, 0.75), 0.8)
		BellPickup.Kind.DOUBLE:
			_double_left = POWERUP_SECONDS
			Audio.sfx(&"confirm", 1.7)
			_hud.toast("DOUBLE", Color(1, 0.65, 0.85), 0.8)
	pickup.queue_free()


## Clears every mark on screen and pays each as a Good hit -- the safety net that
## makes an ambitious trip away from the bell worth attempting.
func _chime_burst() -> void:
	var cleared := 0
	for child in _markers_root.get_children():
		var marker := child as Sprite2D
		if marker == null or marker.has_meta(&"spent"):
			continue
		marker.set_meta(&"spent", true)
		cleared += 1
		_good += 1
		_score += SCORE_GOOD * chain_multiplier() * (2 if _double_left > 0.0 else 1)
		_pop(marker)
	_hud.set_score(_score)
	Audio.sfx(&"chime", 1.5)
	_hud.toast("CHIME BURST  x%d" % cleared, Color(0.7, 0.95, 1.0), 1.0)


func _tick_powerups(delta: float) -> void:
	_focus_left = maxf(_focus_left - delta, 0.0)
	_double_left = maxf(_double_left - delta, 0.0)


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
	if not _in_strike_range():
		Audio.sfx(&"deny", 0.9)
		_hud.toast("TOO FAR", Color(0.8, 0.7, 0.7), 0.4)
		return

	_swing()
	var marker := _closest_marker()
	if marker == null:
		return
	var window := WINDOW_GOOD * (FOCUS_WINDOW_BONUS if _focus_left > 0.0 else 1.0)
	var perfect_window := WINDOW_PERFECT * (FOCUS_WINDOW_BONUS if _focus_left > 0.0 else 1.0)
	var error: float = absf(float(marker.get_meta(&"life")) - APPROACH_SECONDS)
	if error > window:
		# Striking into empty air still breaks the chain -- mashing must cost.
		_break_chain()
		Audio.sfx(&"deny", 1.6)
		return

	marker.set_meta(&"spent", true)
	_chain += 1
	_best_chain = maxi(_best_chain, _chain)
	var multiplier := chain_multiplier()

	var doubler := 2 if _double_left > 0.0 else 1
	if error <= perfect_window:
		_perfect += 1
		_score += SCORE_PERFECT * multiplier * doubler
		_hud.toast("PERFECT   x%d" % multiplier, Color(1, 0.9, 0.5), 0.4)
		Audio.plate_note(2)
	else:
		_good += 1
		_score += SCORE_GOOD * multiplier * doubler
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
			"chain": _best_chain, "coins": _coins})
