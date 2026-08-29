extends MiniGame
## Riverleap -- hop between five drifting leaves and reach the far bank.
##
## The leaves carry the player downstream, so the camera rides with them: the
## leaf row holds a fixed screen position while the banks scroll past and the
## far shore slides in at the end. Leaves that shake are about to sink; leaves
## always come back, so the row can never be wiped out.
##
## No fail state. Going in the water costs about a second and a half and some
## points, then the river puts you back on a leaf. See docs/GAME_DESIGN.md #7.1.

const LANES := 5
const LANE_X: Array[float] = [141.0, 230.0, 320.0, 410.0, 499.0]
const ROW_Y := 232.0

const CROSSING_SECONDS := 62.0
const HOP_TIME := 0.26
## A short beat after landing before another hop can start, so the river cannot
## be crossed by drumming the stick. Small on purpose -- it should read as
## weight, not as the controls being sticky.
const HOP_COOLDOWN := 0.10
const HOP_HEIGHT := 15.0
const INPUT_BUFFER := 0.16
const RECOVERY_TIME := 1.4
const RESPAWN_DELAY := 2.2

## Difficulty bands by fraction of the river crossed:
## [progress_from, shake_interval, telegraph, max_simultaneous]
const BANDS: Array[Array] = [
	[0.00, 2.40, 1.10, 1],
	[0.33, 1.60, 0.80, 2],
	[0.66, 0.90, 0.55, 2],
]

const CHIME_INTERVAL := 2.5
const CHIME_SPEED := 62.0
const SCORE_ARRIVAL := 1500
const SCORE_CHIME := 80
const SCORE_SPLASH := -150
const SCORE_TIME_BONUS := 600
## Chimes collected back to back without a splash multiply. Going in the water
## therefore costs twice: the points, and the chain you were building.
const CHIME_CHAIN_STEP := 2
const CHIME_CHAIN_MAX := 5

@onready var _player: TopDownPlayer = $Player
@onready var _hud: HUD = $HUD
@onready var _leaves_root: Node2D = $Leaves
@onready var _chimes_root: Node2D = $Chimes
@onready var _far_bank: Sprite2D = $World/FarBank
@onready var _bank_left: ScrollingTexture = $World/BankLeft
@onready var _bank_right: ScrollingTexture = $World/BankRight

var _leaves: Array[RiverLeaf] = []
var _lane: int = 2
var _progress: float = 0.0

var _hopping: bool = false
var _in_water: bool = false
var _arriving: bool = false
var _buffered_direction: int = 0
var _buffer_timer: float = 0.0
var _recovery_timer: float = 0.0

var _shake_timer: float = 0.0
var _chime_timer: float = 0.0

var _chimes: int = 0
var _splashes: int = 0
var _chain: int = 0
var _best_chain: int = 0
var _score: int = 0
var _hop_cooldown: float = 0.0

var _leaf_scene := preload("res://src/minigames/wind_leaf/leaf.tscn")
var _chime_texture := preload("res://assets/game/wind_leaf/chime.png")


func _ready() -> void:
	for lane in LANES:
		var leaf: RiverLeaf = _leaf_scene.instantiate()
		leaf.lane = lane
		leaf.position = Vector2(LANE_X[lane], ROW_Y)
		leaf.sank.connect(_on_leaf_sank)
		_leaves_root.add_child(leaf)
		_leaves.append(leaf)

	_player.freeze()
	_player.position = Vector2(LANE_X[_lane], ROW_Y)
	_player.set_facing(&"up")

	_far_bank.visible = false
	_hud.set_title("Riverleap")
	_hud.set_objective("Cross the river. Shaking leaves are about to sink.")
	_hud.reset_score(0)
	_hud.set_meter(0.0, "far bank")


func begin() -> void:
	super.begin()
	_hud.toast("HOP!", Color(0.7, 1, 0.75), 0.7)


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_advance_river(delta)
	_tick_buffer(delta)
	_tick_director(delta)
	_tick_chimes(delta)
	_tick_recovery(delta)
	_check_footing()


func _unhandled_input(event: InputEvent) -> void:
	if not running or _in_water or _arriving:
		return
	if event.is_action_pressed(&"move_left"):
		_queue_hop(-1)
	elif event.is_action_pressed(&"move_right"):
		_queue_hop(1)


# --- river -------------------------------------------------------------------

func _advance_river(delta: float) -> void:
	if _arriving:
		return
	_progress = minf(_progress + delta / CROSSING_SECONDS, 1.0)
	_hud.set_meter(_progress, "far bank")

	# The banks scrolling past are what sells the leaves as moving at all.
	var speed := lerpf(52.0, 78.0, _progress)
	for bank: ScrollingTexture in [_bank_left, _bank_right]:
		bank.scroll = Vector2(0.0, speed)

	if _progress >= 1.0:
		_begin_arrival()


func _begin_arrival() -> void:
	if _arriving:
		return
	_arriving = true
	_hud.toast("THE FAR BANK!", Color(1, 0.9, 0.5), 1.2)

	_far_bank.visible = true
	_far_bank.position = Vector2(320, -80)
	var tween := create_tween()
	tween.tween_property(_far_bank, "position:y", 96.0, 2.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_land_ashore)


func _land_ashore() -> void:
	var tween := create_tween()
	tween.tween_property(_player, "position",
			Vector2(LANE_X[_lane], 122.0), 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_score_run)


func _score_run() -> void:
	Audio.sfx(&"complete")
	# Rewards finishing quickly, but the clock only starts mattering once the
	# crossing itself is done -- there is no way to lose by being slow.
	var pace := clampf(CROSSING_SECONDS * 1.35 / maxf(elapsed, 1.0), 0.0, 1.0)
	var score := SCORE_ARRIVAL \
			+ _score \
			+ _splashes * SCORE_SPLASH \
			+ int(SCORE_TIME_BONUS * pace)
	_hud.set_score(maxi(score, 0))
	finish(score, {"chimes": _chimes, "splashes": _splashes, "chain": _best_chain})


# --- hopping -----------------------------------------------------------------

func _queue_hop(direction: int) -> void:
	_buffered_direction = direction
	_buffer_timer = INPUT_BUFFER
	if not _hopping:
		_consume_buffer()


func _tick_buffer(delta: float) -> void:
	_hop_cooldown = maxf(_hop_cooldown - delta, 0.0)
	if _buffer_timer <= 0.0:
		return
	_buffer_timer -= delta
	if not _hopping:
		_consume_buffer()


func _consume_buffer() -> void:
	# _unhandled_input already refuses to queue a hop in the water, but the
	# buffer drains from _process, so a direction pressed in the 0.16s before
	# falling used to fire anyway and lift the player straight back out. That
	# made drowning optional as long as you were holding a direction.
	if _in_water or _arriving or _hop_cooldown > 0.0:
		return
	if _buffered_direction == 0 or _buffer_timer <= 0.0:
		return
	var target := _lane + _buffered_direction
	_buffered_direction = 0
	_buffer_timer = 0.0
	if target < 0 or target >= LANES:
		return
	_hop_to(target)


func _hop_to(target_lane: int) -> void:
	_player.set_facing(&"left" if target_lane < _lane else &"right")
	_hopping = true
	_lane = target_lane
	Audio.sfx(&"hop", randf_range(0.95, 1.1))

	var from := _player.position
	var to := Vector2(LANE_X[target_lane], ROW_Y)
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_player.position = from.lerp(to, t) + Vector2(0, -sin(t * PI) * HOP_HEIGHT)
			_player.shadow.scale = Vector2.ONE * (1.3 - sin(t * PI) * 0.45),
		0.0, 1.0, HOP_TIME)
	tween.tween_callback(_on_hop_landed)


func _on_hop_landed() -> void:
	_hopping = false
	_hop_cooldown = HOP_COOLDOWN
	_player.shadow.scale = Vector2(1.3, 1.3)
	_check_footing()


## The player is only ever unsupported for the instant a leaf goes out from
## under them, or when they land where a leaf used to be.
func _check_footing() -> void:
	if _in_water or _hopping or _arriving or not running:
		return
	if not _leaves[_lane].is_standable():
		_fall_in()


func _fall_in() -> void:
	_in_water = true
	_splashes += 1
	_recovery_timer = RECOVERY_TIME
	# Anything queued is void the moment you are in the water.
	_buffered_direction = 0
	_buffer_timer = 0.0
	Audio.sfx(&"splash")
	var lost := _chain
	_chain = 0
	_refresh_score()
	if lost >= CHIME_CHAIN_STEP:
		_hud.toast("SPLASH!  chain lost", Color(1, 0.5, 0.45), 0.9)
	else:
		_hud.toast("SPLASH  %d" % SCORE_SPLASH, Color(0.62, 0.85, 1.0), 0.8)
	_player.anim.modulate = Color(0.7, 0.85, 1.0, 0.85)
	_player.anim.play(&"idle_down")


func _tick_recovery(delta: float) -> void:
	if not _in_water:
		return
	# Bobbing in the current while a leaf comes back around.
	_player.position.y = ROW_Y + sin(Time.get_ticks_msec() / 160.0) * 2.0
	_recovery_timer -= delta
	if _recovery_timer > 0.0:
		return

	var rescue := _nearest_safe_lane(_lane)
	if rescue < 0:
		# Nothing safe yet -- keep bobbing and try again next frame.
		_recovery_timer = 0.15
		return

	_in_water = false
	_lane = rescue
	_player.anim.modulate = Color.WHITE
	_player.set_facing(&"up")
	Audio.sfx(&"hop", 0.8)
	create_tween().tween_property(_player, "position",
			Vector2(LANE_X[rescue], ROW_Y), 0.3).set_trans(Tween.TRANS_SINE)


func _nearest_safe_lane(from_lane: int) -> int:
	if _leaves[from_lane].is_safe():
		return from_lane
	for distance in range(1, LANES):
		for direction in [-1, 1]:
			var lane: int = from_lane + direction * distance
			if lane >= 0 and lane < LANES and _leaves[lane].is_safe():
				return lane
	return -1


# --- the director ------------------------------------------------------------

func _band() -> Array:
	var chosen: Array = BANDS[0]
	for band in BANDS:
		if _progress >= float(band[0]):
			chosen = band
	return chosen


func _tick_director(delta: float) -> void:
	if _arriving:
		return
	_shake_timer -= delta
	if _shake_timer > 0.0:
		return

	var band := _band()
	_shake_timer = float(band[1]) * randf_range(0.85, 1.15)
	var telegraph := float(band[2])
	var wanted: int = randi_range(1, int(band[3]))

	for i in wanted:
		var lane := _pick_shake_lane()
		if lane < 0:
			return
		_leaves[lane].start_shake(telegraph, RESPAWN_DELAY)


## Picks a leaf to shake without ever cornering the player: after this leaf
## starts shaking, at least one lane they can reach in one hop must still be
## safe. Without this rule the game becomes unwinnable by luck alone.
func _pick_shake_lane() -> int:
	var candidates: Array[int] = []
	for lane in LANES:
		if _leaves[lane].state != RiverLeaf.State.STABLE:
			continue
		if _leaves_escape_route(lane):
			candidates.append(lane)
	if candidates.is_empty():
		return -1
	return candidates[randi() % candidates.size()]


func _leaves_escape_route(shaking_lane: int) -> bool:
	for offset: int in [-1, 0, 1]:
		var lane := _lane + offset
		if lane < 0 or lane >= LANES or lane == shaking_lane:
			continue
		if _leaves[lane].is_safe():
			return true
	return false


func _on_leaf_sank(lane: int) -> void:
	if lane == _lane and not _in_water and not _hopping and not _arriving:
		_fall_in()


# --- chimes ------------------------------------------------------------------

func _tick_chimes(delta: float) -> void:
	if not _arriving:
		_chime_timer -= delta
		if _chime_timer <= 0.0:
			_chime_timer = CHIME_INTERVAL * randf_range(0.8, 1.3)
			_spawn_chime()

	for chime: Sprite2D in _chimes_root.get_children():
		if chime.has_meta(&"collected"):
			continue
		chime.position.y += CHIME_SPEED * delta
		chime.rotation = sin(chime.position.y / 18.0) * 0.3
		if chime.position.y > 400.0:
			chime.queue_free()
		elif not _in_water and chime.position.distance_to(_player.position) < 22.0:
			_collect(chime)


func _spawn_chime() -> void:
	var chime := Sprite2D.new()
	chime.texture = _chime_texture
	# The 16px art is nearly invisible against moving water at this resolution.
	chime.scale = Vector2(2.0, 2.0)
	chime.position = Vector2(LANE_X[randi() % LANES], -20.0)
	_chimes_root.add_child(chime)


func _collect(chime: Sprite2D) -> void:
	_chimes += 1
	_chain += 1
	_best_chain = maxi(_best_chain, _chain)
	var multiplier := chain_multiplier()
	_score += SCORE_CHIME * multiplier
	_refresh_score()

	Audio.sfx(&"chime", 1.0 + 0.08 * multiplier)
	# The chimes always scored; they just never said so, which is why they felt
	# like scenery. Now every pickup announces itself.
	if multiplier > 1:
		_hud.toast("+%d   x%d" % [SCORE_CHIME * multiplier, multiplier],
				Color(1, 0.92, 0.55), 0.7)
	else:
		_hud.toast("+%d" % SCORE_CHIME, Color(0.8, 1, 0.85), 0.55)

	var pop := create_tween()
	pop.tween_property(chime, "scale", Vector2(3.2, 3.2), 0.12)
	pop.parallel().tween_property(chime, "modulate:a", 0.0, 0.12)
	pop.tween_callback(chime.queue_free)
	chime.set_meta(&"collected", true)


## 1 to CHIME_CHAIN_MAX, stepping up every CHIME_CHAIN_STEP chimes.
func chain_multiplier() -> int:
	return clampi(1 + _chain / CHIME_CHAIN_STEP, 1, CHIME_CHAIN_MAX)


func _refresh_score() -> void:
	_score = maxi(_score, 0)
	_hud.set_score(maxi(_score + _splashes * SCORE_SPLASH, 0))
	if _chain >= CHIME_CHAIN_STEP:
		_hud.set_objective("CHAIN x%d  -  keep collecting, do not fall in"
				% chain_multiplier())
	else:
		_hud.set_objective("Cross the river. Shaking leaves are about to sink.")
