extends MiniGame
## Riverleap -- ride an endless river for as long as you can hold on.
##
## There is no far bank any more. The river never ends: it just gets angrier,
## and the run is over when it has taken all five of your lives. Score comes
## from chimes and from how long you lasted, and the per-second rate climbs
## with the danger, so the last thirty seconds of a good run are worth more
## than the first two minutes.
##
## **This breaks the cabinet's no-fail-state rule on purpose** (design doc #1),
## because without a way to lose there is nothing for a good player to chase.
## The compromise is the shape of the difficulty curve: the first minute is
## gentle enough that a stranger who has not worked out the controls still gets
## a real go for their credit, and only then does it turn steep.
##
## Three things to read, and they want three different reactions:
##   * a pad shaking  -- hop off it
##   * a log          -- jump; it passes underneath you
##   * a heron diving -- jumping will not save you, get out of the lane
##
## See docs/GAME_DESIGN.md #5.

const LANES := 5
const LANE_X: Array[float] = [106.0, 173.0, 240.0, 307.0, 374.0]
const ROW_Y := 174.0

## --- the difficulty curve ----------------------------------------------------
##
## One number, `_intensity`, drives the current, the pads and the hazards. It
## is shaped to the decision above: shallow for the first minute, then steep,
## approaching but never reaching 1.
##
##   t=30s -> 0.15   t=60s -> 0.30   t=120s -> 0.64   t=180s -> 0.82
##
## Beginner 45-60s, a decent player 2-3 minutes, an expert longer.
const GENTLE_SECONDS := 60.0
const GENTLE_CEILING := 0.30
const STEEP_TAU := 90.0

## The shore's speed. The start is double what the crossing used to run at --
## an aggressive river rather than a calm one -- and it keeps climbing.
const CURRENT_START := 68.0
const CURRENT_END := 240.0

## Every scrolling layer is a fraction of the current, so the whole scene is
## one parallax stack driven by one number. Different speeds in the SAME
## direction is the oldest depth cue in 2D and it is what this scene never
## had: distance behind, the surface you float on in the middle, the shore
## you are passing at full speed.
const LAYER_SPEEDS := {
	"World/TreelineLeft": 0.35,
	"World/TreelineRight": 0.35,
	"World/Water": 0.45,
	"World/WaterGlints": 0.60,
	"World/RiverLitter": 0.50,
	"World/Streaks": 1.25,
	"World/BankLeft": 1.0,
	"World/BankEdgeLeft": 1.0,
	"World/BankPropsLeft": 1.0,
	"World/BankRight": 1.0,
	"World/BankEdgeRight": 1.0,
	"World/BankPropsRight": 1.0,
}
const HOP_TIME := 0.26
## A jump that goes nowhere. Slightly longer than a hop so the hang time is
## usable as a dodge, which is the only reason it exists.
const JUMP_TIME := 0.32
## A short beat after landing before another hop can start, so the river cannot
## be crossed by drumming the stick. Small on purpose -- it should read as
## weight, not as the controls being sticky.
const HOP_COOLDOWN := 0.10
## The arc has to be tall enough to read as a jump in the quarter-second it
## lasts. At 11 it was a slide with a shadow.
const HOP_HEIGHT := 18.0
const INPUT_BUFFER := 0.16
## Seconds after the last hop before the character turns back upstream.
const FACE_UPSTREAM_AFTER := 0.5
const RECOVERY_TIME := 1.4
const RESPAWN_DELAY := 2.2

## Pads, as continuous functions of intensity rather than three fixed bands.
const SHAKE_INTERVAL := Vector2(2.6, 0.40)
const SHAKE_TELEGRAPH := Vector2(1.15, 0.30)
const SHAKE_AT_ONCE := Vector2(1.0, 3.0)

## --- hazards -----------------------------------------------------------------
##
## Both arrive late enough that the opening is purely pad-hopping: long enough
## to learn that jump moves you and jump-with-a-direction moves you sideways,
## before anything is thrown at you.
const LOG_FROM_SECONDS := 35.0
const LOG_INTERVAL := Vector2(4.5, 1.1)
## Logs travel a shade faster than the river, so they close on you rather than
## hanging alongside -- and so the jump has to be timed, not held.
const LOG_SPEED_FACTOR := 1.15

const HERON_FROM_SECONDS := 100.0
const HERON_INTERVAL := Vector2(5.5, 2.4)
const HERON_TELEGRAPH := Vector2(0.95, 0.50)

## --- lives -------------------------------------------------------------------
##
## Tracked in halves. A hazard takes a whole life; going in the water takes
## half, which keeps the original forgiveness for the mistake beginners make
## constantly and reserves the real cost for the things you are dodging.
const MAX_LIFE_HALVES := 10
const DAMAGE_HAZARD := 2
const DAMAGE_WATER := 1
## Seconds of mercy after taking a hit, so one log cannot cost three lives.
const INVULNERABLE_TIME := 1.1

## A wake is the thing that makes an object holding its screen position read
## as moving THROUGH the water rather than anchored in it. The pads and the
## player keep their place on screen, so without this the river slides past
## them and they look moored. Spawn rate and reach both rise with the current.
const WAKE_INTERVAL := 0.16
const WAKE_LIFE := 0.5

const CHIME_INTERVAL := 2.5
const SCORE_CHIME := 80
const SCORE_SPLASH := -150
## Survival pays per second, and the rate climbs with the danger. This is what
## gives a skilled player something to chase: the tail of a long run is worth
## far more than its opening.
const SCORE_PER_SECOND := Vector2(20.0, 85.0)
## Chimes collected back to back without a splash multiply. Going in the water
## therefore costs twice: the points, and the chain you were building.
const CHIME_CHAIN_STEP := 3
const CHIME_CHAIN_MAX := 5

@onready var _player: TopDownPlayer = $Player
@onready var _hud: HUD = $HUD
@onready var _leaves_root: Node2D = $Leaves
@onready var _chimes_root: Node2D = $Chimes
@onready var _hazards_root: Node2D = $Hazards

@onready var _camera: GameCamera = $Camera
@onready var _streaks: ScrollingProps = $World/Streaks

var _leaves: Array[RiverLeaf] = []
var _lane: int = 2
## 0 at the start, approaching 1. Everything difficulty- or speed-linked reads
## this and nothing else.
var _intensity: float = 0.0

var _hopping: bool = false
var _airborne: bool = false
var _in_water: bool = false
var _ending: bool = false
var _life_halves: int = MAX_LIFE_HALVES
var _invulnerable: float = 0.0
var _survived: float = 0.0
var _survival_score: float = 0.0
var _buffered_direction: int = 0
var _buffer_timer: float = 0.0
var _recovery_timer: float = 0.0

var _shake_timer: float = 0.0
var _chime_timer: float = 0.0
var _wake_timer: float = 0.0
var _log_timer: float = 0.0
var _heron_timer: float = 0.0
var _hazards: Array[RiverHazard] = []

var _chimes: int = 0
var _dodged: int = 0
var _splashes: int = 0
var _chain: int = 0
var _best_chain: int = 0
var _score: int = 0
var _hop_cooldown: float = 0.0
var _idle_facing_timer: float = 0.0

var _leaf_scene := preload("res://src/minigames/wind_leaf/leaf.tscn")
var _hazard_scene := preload("res://src/minigames/wind_leaf/hazard.tscn")
var _wake_texture := preload("res://assets/game/decor/foam.png")
var _wake_root: Node2D
var _chime_texture := preload("res://assets/game/wind_leaf/chime.png")


func _ready() -> void:
	for lane in LANES:
		var leaf: RiverLeaf = _leaf_scene.instantiate()
		leaf.lane = lane
		# A fifth of a cycle apart, so the bob reads as one swell crossing the
		# river rather than five pads on their own timers.
		leaf.wave_phase = float(lane) * TAU / float(LANES)
		leaf.position = Vector2(LANE_X[lane], ROW_Y)
		leaf.sank.connect(_on_leaf_sank)
		_leaves_root.add_child(leaf)
		_leaves.append(leaf)

	_player.freeze()
	_player.position = Vector2(LANE_X[_lane], ROW_Y)
	_player.set_facing(&"up")

	_hud.reset_score(0)
	_hud.hide_meter()
	_hud.set_lives(_life_halves, MAX_LIFE_HALVES)

	# No shell in front of it for now, so the game starts itself and loops on
	# its own -- but only when it really is the scene being played. The soak
	# test instances it as a child and drives begin() itself, and must not get
	# a run card or a scene reload out of the bargain.
	if get_tree().current_scene == self:
		finished.connect(_on_run_finished)
		await get_tree().process_frame
		begin()


func begin() -> void:
	super.begin()
	_hud.toast("HOLD ON", Color(0.8, 0.95, 1.0), 1.4)
	_log_timer = LOG_FROM_SECONDS
	_heron_timer = HERON_FROM_SECONDS


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_advance_river(delta)
	_tick_buffer(delta)
	_tick_director(delta)
	_tick_hazards(delta)
	_tick_chimes(delta)
	_tick_recovery(delta)
	_tick_facing(delta)
	_tick_wakes(delta)
	_tick_survival(delta)
	_check_footing()


## One button. Pressed alone it jumps on the spot, which is how you let a log
## pass underneath; pressed while leaning on the stick it carries you to the
## next pad. A direction on its own no longer does anything -- moving costs two
## inputs now, which is most of why this is harder than it was.
func _unhandled_input(event: InputEvent) -> void:
	if not running or _in_water or _ending:
		return
	if not event.is_action_pressed(&"act"):
		return
	var direction := 0
	if Input.is_action_pressed(&"move_left"):
		direction -= 1
	if Input.is_action_pressed(&"move_right"):
		direction += 1
	_queue_hop(direction)


# --- river -------------------------------------------------------------------

## Shallow for the first minute, then steep, approaching but never reaching 1.
## Written out rather than tabled because it is the single number the whole
## game's difficulty hangs off, and it should be readable in one glance.
static func intensity_at(seconds: float) -> float:
	var gentle := GENTLE_CEILING * clampf(seconds / GENTLE_SECONDS, 0.0, 1.0)
	var steep := (1.0 - GENTLE_CEILING) \
			* (1.0 - exp(-maxf(seconds - GENTLE_SECONDS, 0.0) / STEEP_TAU))
	return gentle + steep


func _advance_river(_delta: float) -> void:
	if _ending:
		return
	_intensity = intensity_at(elapsed)

	# One current, every layer a fraction of it. Nothing in the scene sets its
	# own speed any more -- two scrollers disagreeing is how the grass ended up
	# crawling backwards past the trees standing on it.
	var speed := current_speed()
	for path in LAYER_SPEEDS:
		var layer := get_node_or_null(NodePath(path))
		if layer != null:
			layer.scroll = Vector2(0.0, speed * float(LAYER_SPEEDS[path]))

	# Streaks stretch and multiply with the current. More of them, longer,
	# and moving faster is three cues for the price of one.
	var rush := _intensity
	# Weighted toward the banks: peripheral motion is where speed is read, and
	# the middle of the river is where the player is reading pads.
	for streak: Node2D in _streaks.get_children():
		var edge := clampf(absf(streak.position.x - 240.0) / 160.0, 0.0, 1.0)
		streak.scale = Vector2(lerpf(0.55, 1.9, rush) * lerpf(0.65, 1.25, edge), 1.0)
		streak.modulate.a = lerpf(0.10, 0.55, rush) * lerpf(0.55, 1.0, edge)

	_camera.set_intensity(rush)

	# The swell quickens with the river.
	var swell := lerpf(1.8, 3.4, rush)
	for leaf in _leaves:
		leaf.wave_speed = swell


func current_speed() -> float:
	return lerpf(CURRENT_START, CURRENT_END, _intensity)


## --- lives and the end ------------------------------------------------------

func _tick_survival(delta: float) -> void:
	if _ending:
		return
	_survived += delta
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	# The rate climbs with the danger, so a long run's tail is where the score
	# actually comes from.
	_survival_score += lerpf(SCORE_PER_SECOND.x, SCORE_PER_SECOND.y,
			_intensity) * delta
	_refresh_score()
	_hud.set_timer(_survived)


## `halves` is 1 for going in the water, 2 for being hit. Returns true if it
## landed -- during the mercy window after a hit it does not.
func _take_damage(halves: int, reason: String) -> bool:
	if _ending or _invulnerable > 0.0:
		return false
	_life_halves = maxi(_life_halves - halves, 0)
	_invulnerable = INVULNERABLE_TIME
	_hud.set_lives(_life_halves, MAX_LIFE_HALVES)
	_hud.set_alarm(1.0 if _life_halves <= 2 else 0.0)
	_camera.kick(1.0 if halves >= DAMAGE_HAZARD else 0.6)
	Juice.flash(_player.anim, Color(1, 0.5, 0.5), 0.22)

	var lost := _chain
	_chain = 0
	pop_on_player(SCORE_SPLASH, reason if lost < CHIME_CHAIN_STEP else "CHAIN LOST")
	_refresh_score()

	if _life_halves <= 0:
		_end_run()
	return true


## The river never runs out, so this is the only way a run ends.
func _end_run() -> void:
	if _ending:
		return
	_ending = true
	_hud.toast("THE RIVER TAKES YOU", Color(1, 0.55, 0.45), 1.6)
	Audio.sfx(&"complete", 0.6)
	_player.freeze()
	await Wait.on(self, 1.3)
	if _finished:
		return
	var total := _score + int(_survival_score)
	_hud.set_score(maxi(total, 0))
	finish(total, {
		"chimes": _chimes,
		"splashes": _splashes,
		"chain": _best_chain,
		"survived": int(_survived),
		"dodged": _dodged,
	})


## Stands in for the shell while it is parked: results, then straight back in.
## How long you lasted leads, because in an endless game that is the thing you
## are actually competing on and the number you will try to beat next credit.
func _on_run_finished(result: MiniGameResult) -> void:
	var best := Save.best()
	Save.submit(result.score)
	var card := RunCard.new()
	add_child(card)
	card.replay.connect(func() -> void: get_tree().reload_current_scene())
	var held := int(result.stats.get("survived", 0))
	card.show_run("RIVERLEAP", result.score, [
		["held on", "%d:%02d" % [held / 60, held % 60]],
		["chimes", "%d" % int(result.stats.get("chimes", 0))],
		["best chain", "x%d" % maxi(int(result.stats.get("chain", 0)), 1)],
		["dodged", "%d" % int(result.stats.get("dodged", 0))],
		["splashes", "%d" % int(result.stats.get("splashes", 0))],
	], best)


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
	# _unhandled_input already refuses to act in the water, but the buffer
	# drains from _process, so a press in the 0.16s before falling used to fire
	# anyway and lift the player straight back out. That made drowning optional
	# as long as you were holding a direction.
	if _in_water or _ending or _hop_cooldown > 0.0:
		return
	if _buffer_timer <= 0.0:
		return
	var direction := _buffered_direction
	_buffered_direction = 0
	_buffer_timer = 0.0

	# A jump with no direction, or into the bank, goes straight up. It still
	# gets you off the water for a moment, which is the point of it.
	var target := _lane + direction
	if direction == 0 or target < 0 or target >= LANES:
		_jump_in_place()
		return
	_hop_to(target)


## Straight up and down. The only reason this exists is the hang time: a log
## passes underneath you, and nothing else in the game gives you that.
func _jump_in_place() -> void:
	_hopping = true
	_airborne = true
	_idle_facing_timer = FACE_UPSTREAM_AFTER
	Audio.sfx(&"hop", randf_range(1.15, 1.3))
	_player.start_jump(0)

	var from := _player.position
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_player.position = from + Vector2(0, -sin(t * PI) * HOP_HEIGHT * 1.15)
			_player.set_jump_progress(t, 0),
		0.0, 1.0, JUMP_TIME)
	tween.tween_callback(_on_hop_landed)


func _hop_to(target_lane: int) -> void:
	var direction := 1 if target_lane > _lane else -1
	_player.set_facing(&"left" if direction < 0 else &"right")
	_hopping = true
	_airborne = true
	_lane = target_lane
	_idle_facing_timer = FACE_UPSTREAM_AFTER
	Audio.sfx(&"hop", randf_range(0.95, 1.1))

	# The arc is this game's; the pose is the player controller's, so any game
	# that jumps gets the same weight out of it.
	_player.start_jump(direction)

	var from := _player.position
	var to := Vector2(LANE_X[target_lane], ROW_Y)
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_player.position = from.lerp(to, t) + Vector2(0, -sin(t * PI) * HOP_HEIGHT)
			_player.set_jump_progress(t, direction),
		0.0, 1.0, HOP_TIME)
	tween.tween_callback(_on_hop_landed)


func _on_hop_landed() -> void:
	_hopping = false
	_airborne = false
	_hop_cooldown = HOP_COOLDOWN
	_player.land()
	_camera.kick(0.28)
	_check_footing()


## Left after a hop, the character stays side-on indefinitely, which reads as
## the player having stopped paying attention to the far bank. A beat after the
## last hop they turn back upstream, which is where they are actually going.
func _tick_facing(delta: float) -> void:
	if _hopping or _in_water or _ending:
		return
	if _idle_facing_timer <= 0.0:
		return
	_idle_facing_timer -= delta
	if _idle_facing_timer <= 0.0:
		_player.set_facing(&"up")


## The player is only ever unsupported for the instant a leaf goes out from
## under them, or when they land where a leaf used to be.
func _check_footing() -> void:
	if _in_water or _hopping or _ending or not running:
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
	if not _take_damage(DAMAGE_WATER, "SPLASH"):
		# Inside the mercy window after a hit: still a splash, still costs the
		# points, just not another slice of the health bar.
		_chain = 0
		_refresh_score()
		pop_on_player(SCORE_SPLASH, "SPLASH")
	_player.cancel_jump()
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


# --- hazards -----------------------------------------------------------------

func _tick_hazards(delta: float) -> void:
	if _ending:
		return

	_log_timer -= delta
	if elapsed >= LOG_FROM_SECONDS and _log_timer <= 0.0:
		_log_timer = lerpf(LOG_INTERVAL.x, LOG_INTERVAL.y, _intensity) \
				* randf_range(0.8, 1.2)
		_spawn_log()

	_heron_timer -= delta
	if elapsed >= HERON_FROM_SECONDS and _heron_timer <= 0.0:
		_heron_timer = lerpf(HERON_INTERVAL.x, HERON_INTERVAL.y, _intensity) \
				* randf_range(0.8, 1.2)
		_spawn_heron()

	for hazard in _hazards.duplicate():
		if not is_instance_valid(hazard):
			_hazards.erase(hazard)
			continue
		if not hazard.is_striking():
			continue
		hazard.mark_resolved()
		if hazard.lane != _lane:
			_dodged += 1
			continue
		# A log passes under a jump. A dive does not -- that is the whole
		# reason the two exist, and why one button has two meanings.
		if hazard.is_dodgeable_by_jumping() and _airborne:
			_dodged += 1
			Audio.sfx(&"hop", 1.4)
			continue
		_take_damage(DAMAGE_HAZARD,
				"LOG" if hazard.kind == RiverHazard.Kind.LOG else "HERON")


## Riverleap's oldest guarantee is that the director never corners you. There
## are two directors placing things now -- pads and hazards -- and each one
## checking the rule on its own is not enough: a heron on one lane plus two
## pads shaking on the others leaves the player choosing between drowning and
## being hit. So both ask the same question, and this is it.
##
## A lane is available if the pad holds AND nothing is diving on it. A log does
## NOT disqualify a lane: a lane with a log sweeping down it is still somewhere
## you can stand, because you can jump a log. That is the entire reason jumping
## in place is a verb.
func _lane_available(lane: int) -> bool:
	if lane < 0 or lane >= LANES:
		return false
	return _leaves[lane].is_safe() and not _lane_dived_on(lane)


## Only the hazards that jumping does not save you from take a lane away.
func _lane_dived_on(lane: int) -> bool:
	for hazard in _hazards:
		if is_instance_valid(hazard) and hazard.lane == lane \
				and not hazard.is_dodgeable_by_jumping():
			return true
	return false


## Any hazard at all, jumpable or not. This one exists to stop two hazards
## stacking in a single lane, which reads as one unfair hazard rather than two
## fair ones.
func _lane_threatened(lane: int) -> bool:
	for hazard in _hazards:
		if is_instance_valid(hazard) and hazard.lane == lane:
			return true
	return false


func _spawn_hazard(kind: RiverHazard.Kind, lane: int) -> void:
	var hazard: RiverHazard = _hazard_scene.instantiate()
	hazard.kind = kind
	hazard.lane = lane
	hazard.row_y = ROW_Y
	hazard.speed = current_speed() * LOG_SPEED_FACTOR
	hazard.telegraph = lerpf(HERON_TELEGRAPH.x, HERON_TELEGRAPH.y, _intensity)
	hazard.position = Vector2(LANE_X[lane],
			-40.0 if kind == RiverHazard.Kind.LOG else ROW_Y)
	hazard.spent.connect(func(h: RiverHazard) -> void: _hazards.erase(h))
	_hazards_root.add_child(hazard)
	_hazards.append(hazard)


func _spawn_log() -> void:
	var lane := _pick_hazard_lane(true)
	if lane < 0:
		return
	_spawn_hazard(RiverHazard.Kind.LOG, lane)


func _spawn_heron() -> void:
	var lane := _pick_hazard_lane(false)
	if lane < 0:
		return
	_spawn_hazard(RiverHazard.Kind.HERON, lane)


## `dodgeable` is the whole of the difference between the two hazards here.
##
## A log may go anywhere unoccupied, the player's own lane included: it is
## always fair, because jumping clears it. A dive takes its lane away from
## everyone, so it is only allowed if the player is still left with a lane they
## can reach in one hop and actually stand on -- wherever the dive goes, not
## just when it goes on top of them. Getting that wrong is how the game becomes
## unwinnable by luck, which is worse than it being hard.
func _pick_hazard_lane(dodgeable: bool) -> int:
	var options: Array[int] = []
	for lane in LANES:
		options.append(lane)
	options.shuffle()
	for lane in options:
		if _lane_threatened(lane):
			continue
		if dodgeable:
			return lane
		var escapes := 0
		for neighbour in [_lane - 1, _lane, _lane + 1]:
			if neighbour == lane:
				continue
			if _lane_available(neighbour):
				escapes += 1
		if escapes > 0:
			return lane
	return -1


# --- the director ------------------------------------------------------------

func _tick_director(delta: float) -> void:
	if _ending:
		return
	_shake_timer -= delta
	if _shake_timer > 0.0:
		return

	_shake_timer = lerpf(SHAKE_INTERVAL.x, SHAKE_INTERVAL.y, _intensity) \
			* randf_range(0.85, 1.15)
	var telegraph := lerpf(SHAKE_TELEGRAPH.x, SHAKE_TELEGRAPH.y, _intensity)
	var ceiling := int(round(lerpf(SHAKE_AT_ONCE.x, SHAKE_AT_ONCE.y, _intensity)))

	for i in randi_range(1, maxi(ceiling, 1)):
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


## Asks _lane_available rather than is_safe, so a lane a heron has claimed does
## not count as an escape. Checking only the pad is how the two directors used
## to corner the player between them.
func _leaves_escape_route(shaking_lane: int) -> bool:
	for offset: int in [-1, 0, 1]:
		var lane := _lane + offset
		if lane == shaking_lane:
			continue
		if _lane_available(lane):
			return true
	return false


func _on_leaf_sank(lane: int) -> void:
	if lane == _lane and not _in_water and not _hopping and not _ending:
		_fall_in()


# --- chimes ------------------------------------------------------------------

func _tick_chimes(delta: float) -> void:
	if not _ending:
		_chime_timer -= delta
		if _chime_timer <= 0.0:
			# Up to twice as often by the end of the crossing.
			var rate := lerpf(1.0, 0.5, _intensity)
			_chime_timer = CHIME_INTERVAL * rate * randf_range(0.8, 1.3)
			_spawn_chime()

	for chime: Sprite2D in _chimes_root.get_children():
		if chime.has_meta(&"collected"):
			continue
		chime.position.y += _chime_speed() * delta
		chime.rotation = sin(chime.position.y / 18.0) * 0.3
		if chime.position.y > 300.0:
			chime.queue_free()
		elif not _in_water and chime.position.distance_to(_player.position) < 18.0:
			_collect(chime)


## Foam shed behind every pad and behind the player, streaming downstream and
## fading. Cheap -- a handful alive at once -- and it is what tells the eye
## that these things are travelling rather than moored in a river sliding past.
func _tick_wakes(delta: float) -> void:
	if _ending:
		return
	var rush := _rush()
	_wake_timer -= delta
	if _wake_timer > 0.0:
		return
	_wake_timer = WAKE_INTERVAL / lerpf(1.0, 2.1, rush)

	if _wake_root == null or not is_instance_valid(_wake_root):
		_wake_root = Node2D.new()
		_wake_root.name = "Wakes"
		_wake_root.z_index = 3
		add_child(_wake_root)

	for leaf in _leaves:
		if leaf.is_standable():
			_shed_wake(leaf.position + Vector2(randf_range(-14.0, 14.0), 20.0), rush, 0.5)
	if not _in_water:
		_shed_wake(_player.position + Vector2(randf_range(-5.0, 5.0), 4.0), rush, 0.85)


func _shed_wake(at: Vector2, rush: float, strength: float) -> void:
	var wake := Sprite2D.new()
	wake.texture = _wake_texture
	wake.position = at
	wake.scale = Vector2(lerpf(0.5, 1.1, rush), 0.8)
	wake.modulate = Color(1, 1, 1, 0.42 * strength)
	_wake_root.add_child(wake)

	var travel := lerpf(22.0, 54.0, rush)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(wake, "position:y", at.y + travel, WAKE_LIFE)
	tween.tween_property(wake, "modulate:a", 0.0, WAKE_LIFE)
	tween.tween_property(wake, "scale:x", wake.scale.x * 1.6, WAKE_LIFE)
	tween.chain().tween_callback(wake.queue_free)


## 0 at the start of the crossing, 1 at the end. Everything speed-linked reads
## this rather than recomputing the lerp.
func _rush() -> float:
	return clampf(_intensity, 0.0, 1.0)


## Chimes drift with the river, a shade faster than the surface so they still
## close on the player rather than hanging alongside.
func _chime_speed() -> float:
	return current_speed() * 0.85


func _spawn_chime() -> void:
	var chime := Sprite2D.new()
	chime.texture = _chime_texture
	# The 16px art is nearly invisible against moving water at this resolution.
	chime.scale = Vector2(2.0, 2.0)
	chime.position = Vector2(LANE_X[randi() % LANES], -16.0)
	_chimes_root.add_child(chime)


func _collect(chime: Sprite2D) -> void:
	_chimes += 1
	_chain += 1
	_best_chain = maxi(_best_chain, _chain)
	var multiplier := chain_multiplier()
	_score += SCORE_CHIME * multiplier
	_refresh_score()

	Audio.sfx(&"chime", 1.0 + 0.08 * multiplier)
	# The number rises off the chime itself, so it is obvious what scored.
	pop(chime.position, SCORE_CHIME * multiplier, multiplier)

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
	_hud.set_multiplier(chain_multiplier())
