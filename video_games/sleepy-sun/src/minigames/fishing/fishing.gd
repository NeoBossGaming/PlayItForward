extends MiniGame
## Still Water -- cast into the river and strike when something nudges the float.
##
## The tension is that a bite tells you *something* is there, not *what*. The
## silhouette in the water is the only way to tell a fish from a bottle, and it
## is visible before the bite -- so a player who looks before they strike scores,
## and a player who mashes the button loses points to plastic.
##
## No fail state. The round is a fixed 75 seconds, the score floors at zero, and
## the bottles you do pull out get counted on the results screen as a small good
## deed rather than only a penalty.

enum State { READY, CHARGING, CAST, BITING, REELING }

const ROUND_SECONDS := 75.0

const BANK_Y := 312.0
const BANK_MIN_X := 56.0
const BANK_MAX_X := 584.0

const WATER_TOP := 62.0
const LANES: Array[float] = [78.0, 118.0, 158.0, 198.0, 238.0]

const CAST_MIN_DISTANCE := 70.0
const CAST_MAX_DISTANCE := 230.0
const CHARGE_RATE := 260.0
const CAST_TIME := 0.45

const CATCH_RADIUS := 20.0
const STRIKE_WINDOW := 0.45
const REEL_TIME := 0.55

const SPAWN_INTERVAL := 1.15
const PLASTIC_CHANCE := 0.34
const RARE_CHANCE := 0.18

const SCORE_STREAK_BONUS := 50

@onready var _player: TopDownPlayer = $Player
@onready var _hud: HUD = $HUD
@onready var _bobber: Sprite2D = $Bobber
@onready var _alert: Sprite2D = $Bobber/Alert
@onready var _line: Line2D = $Line
@onready var _swimmers_root: Node2D = $Swimmers
@onready var _power: ProgressBar = $PowerLayer/Power

var _state: State = State.READY
var _charge: float = CAST_MIN_DISTANCE
var _charge_direction: float = 1.0
var _bite_timer: float = 0.0
var _biter: Swimmer = null
var _spawn_timer: float = 0.0
var _time_left: float = ROUND_SECONDS

var _score: int = 0
var _fish: int = 0
var _plastic: int = 0
var _streak: int = 0

var _swimmer_scene := preload("res://src/minigames/fishing/swimmer.tscn")
var _bobber_textures: Array[Texture2D] = []


func _ready() -> void:
	for i in 2:
		_bobber_textures.append(load("res://assets/game/fishing/bobber_%d.png" % i))
	_bobber.visible = false
	_alert.visible = false
	_line.visible = false
	_power.visible = false

	_player.position = Vector2(320, BANK_Y)
	_player.set_facing(&"up")
	_player.freeze()

	_hud.set_title("Still Water")
	_hud.reset_score(0)
	_hud.set_objective("Hold the button to cast. Strike when the float dips.")


func begin() -> void:
	super.begin()
	_player.unfreeze()
	_hud.toast("CAST OFF", Color(0.7, 0.9, 1.0), 0.8)


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_time_left = maxf(_time_left - delta, 0.0)
	_hud.set_meter(_time_left / ROUND_SECONDS, "%ds left" % ceili(_time_left))
	if _time_left <= 0.0:
		_finish()
		return

	_tick_spawns(delta)
	_cull_swimmers()

	match _state:
		State.READY:
			_tick_ready()
		State.CHARGING:
			_tick_charging(delta)
		State.CAST:
			_tick_cast(delta)
		State.BITING:
			_tick_biting(delta)

	_update_line()
	_player.position.x = clampf(_player.position.x, BANK_MIN_X, BANK_MAX_X)
	_player.position.y = BANK_Y


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event.is_action_pressed(&"act"):
		match _state:
			State.READY:
				_begin_charge()
			State.BITING:
				_strike()
			State.CAST:
				# Reeling in early: no catch, but you get the line back at once
				# instead of waiting for something to swim past.
				_reset_line()
	elif event.is_action_released(&"act") and _state == State.CHARGING:
		_release_cast()


# --- casting -----------------------------------------------------------------

func _tick_ready() -> void:
	_player.input_enabled = true
	_hud.prompt("HOLD to cast")


func _begin_charge() -> void:
	_state = State.CHARGING
	_charge = CAST_MIN_DISTANCE
	_charge_direction = 1.0
	_player.freeze()
	_power.visible = true
	_power.value = 0.0
	Audio.sfx(&"cast", 0.8)
	_hud.prompt("RELEASE to cast")


## The meter runs up and back down, so a long cast is a timed press rather than
## a hold -- and a long cast is where the rarer fish are.
func _tick_charging(delta: float) -> void:
	_charge += _charge_direction * CHARGE_RATE * delta
	if _charge >= CAST_MAX_DISTANCE:
		_charge = CAST_MAX_DISTANCE
		_charge_direction = -1.0
	elif _charge <= CAST_MIN_DISTANCE:
		_charge = CAST_MIN_DISTANCE
		_charge_direction = 1.0
	_power.value = (_charge - CAST_MIN_DISTANCE) \
			/ (CAST_MAX_DISTANCE - CAST_MIN_DISTANCE) * 100.0


func _release_cast() -> void:
	_state = State.CAST
	_power.visible = false
	Audio.sfx(&"cast")
	_hud.clear_prompt()

	var target := Vector2(_player.position.x,
			clampf(BANK_Y - _charge, WATER_TOP, BANK_Y - CAST_MIN_DISTANCE))
	_bobber.visible = true
	_bobber.texture = _bobber_textures[0]
	_line.visible = true

	var from := _player.position + Vector2(0, -18)
	var tween := create_tween()
	tween.tween_method(
		func(t: float) -> void:
			_bobber.position = from.lerp(target, t) + Vector2(0, -sin(t * PI) * 26.0),
		0.0, 1.0, CAST_TIME)
	tween.tween_callback(func() -> void: Audio.sfx(&"splash", 1.6))


func _tick_cast(_delta: float) -> void:
	var closest := _closest_swimmer()
	if closest == null:
		return
	_biter = closest
	_state = State.BITING
	_bite_timer = STRIKE_WINDOW
	_bobber.texture = _bobber_textures[1]
	_alert.visible = true
	Audio.sfx(&"tick", 1.8)


func _tick_biting(delta: float) -> void:
	_bite_timer -= delta
	_alert.modulate.a = 0.45 + 0.55 * absf(sin(_bite_timer * 22.0))
	# A bite is lost if the fish swims out of reach, not only if time runs out.
	if _bite_timer <= 0.0 or _biter == null or not is_instance_valid(_biter) \
			or _biter.position.distance_to(_bobber.position) > CATCH_RADIUS * 1.6:
		_miss()


func _closest_swimmer() -> Swimmer:
	var best: Swimmer = null
	var best_distance := CATCH_RADIUS
	for child in _swimmers_root.get_children():
		var swimmer := child as Swimmer
		if swimmer == null or swimmer.hooked:
			continue
		var distance := swimmer.position.distance_to(_bobber.position)
		if distance < best_distance:
			best_distance = distance
			best = swimmer
	return best


# --- striking ----------------------------------------------------------------

func _strike() -> void:
	if _biter == null or not is_instance_valid(_biter):
		_miss()
		return
	_state = State.REELING
	_alert.visible = false

	var swimmer := _biter
	_biter = null
	var landing := _player.position + Vector2(0, -20)
	await swimmer.reel_to(landing, REEL_TIME)
	if not running:
		return
	_land(swimmer)


func _land(swimmer: Swimmer) -> void:
	var value := swimmer.value()
	if swimmer.is_plastic():
		_plastic += 1
		_streak = 0
		Audio.sfx(&"trash")
		_hud.toast("%d  BOTTLE" % value, Color(0.75, 0.78, 0.85), 0.8)
	else:
		_fish += 1
		_streak += 1
		# Consecutive clean catches pay a small bonus, so reading the water
		# beats casting blind by more than the plastic penalty alone.
		if _streak >= 3:
			value += SCORE_STREAK_BONUS
			_hud.toast("+%d  STREAK x%d" % [value, _streak], Color(1, 0.9, 0.5), 0.9)
		else:
			_hud.toast("+%d" % value, Color(0.75, 1, 0.8), 0.7)
		Audio.sfx(&"catch", 1.0 + 0.06 * _streak)

	_score = maxi(_score + value, 0)
	_hud.set_score(_score)
	swimmer.queue_free()
	_reset_line()


func _miss() -> void:
	if _state == State.BITING:
		Audio.sfx(&"deny", 1.4)
		_streak = 0
	_biter = null
	_alert.visible = false
	_bobber.texture = _bobber_textures[0]
	_state = State.CAST


func _reset_line() -> void:
	_state = State.READY
	_biter = null
	_bobber.visible = false
	_alert.visible = false
	_line.visible = false
	_player.unfreeze()


func _update_line() -> void:
	if not _line.visible:
		return
	_line.points = PackedVector2Array([
		_player.position + Vector2(0, -18), _bobber.position])


# --- the river ---------------------------------------------------------------

func _tick_spawns(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = SPAWN_INTERVAL * randf_range(0.7, 1.3)

	var swimmer: Swimmer = _swimmer_scene.instantiate()
	var roll := randf()
	if roll < PLASTIC_CHANCE:
		swimmer.kind = Swimmer.Kind.PLASTIC
		swimmer.speed = randf_range(24.0, 34.0)
	elif roll < PLASTIC_CHANCE + RARE_CHANCE:
		swimmer.kind = Swimmer.Kind.FISH_RARE
		swimmer.speed = randf_range(62.0, 84.0)
	else:
		swimmer.kind = Swimmer.Kind.FISH_COMMON
		swimmer.speed = randf_range(34.0, 52.0)

	swimmer.direction = 1.0 if randf() < 0.5 else -1.0
	swimmer.position = Vector2(
		-40.0 if swimmer.direction > 0.0 else 680.0,
		LANES[randi() % LANES.size()])
	swimmer.z_index = 2
	_swimmers_root.add_child(swimmer)


func _cull_swimmers() -> void:
	for child in _swimmers_root.get_children():
		var swimmer := child as Swimmer
		if swimmer == null or swimmer.hooked:
			continue
		if swimmer.position.x < -80.0 or swimmer.position.x > 720.0:
			swimmer.queue_free()


func _finish() -> void:
	_player.freeze()
	Audio.sfx(&"complete")
	_hud.clear_prompt()
	finish(_score, {"fish": _fish, "plastic": _plastic})
