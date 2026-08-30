extends MiniGame
## Riverstrike -- stand on the bank and spear what swims past.
##
## Rewritten from the original angling version, which asked the player to wait
## for a bite. Waiting is the wrong verb for a cabinet: the machine should be
## loud and busy the whole sixty seconds.
##
## The harpoon always fires straight up, so **standing in the right place IS
## aiming** -- one button, no aim stick fighting the movement stick, and it
## reads instantly from across a room. The skill is that the bolt takes time to
## travel, so a moving fish has to be led. One bolt spears everything in its
## path, which is the big-reward moment worth chasing, and bottles stop a bolt
## dead, which turns them from a flat penalty into moving cover to shoot around.
##
## No fail state: the round ends on its clock and the score floors at zero.

const ROUND_SECONDS := 60.0

const BANK_Y := 239.0
const BANK_MIN_X := 30.0
const BANK_MAX_X := 450.0

const WATER_TOP := 30.0
const LANES: Array[float] = [54.0, 87.0, 120.0, 153.0, 186.0]

const BOLT_SPEED := 465.0
const BOLT_RADIUS := 9.0
const RELOAD_SECONDS := 0.45

const SPAWN_INTERVAL := 1.25
const PLASTIC_CHANCE := 0.30
const RARE_CHANCE := 0.20

const SCORE_PLASTIC := -100
## One bolt through two fish doubles, three trebles. The reason to hold fire and
## wait for a line to form up rather than shooting the moment anything appears.
const MULTIKILL_LABELS := {2: "DOUBLE!", 3: "TRIPLE!", 4: "QUAD!"}

@onready var _player: TopDownPlayer = $Player
@onready var _hud: HUD = $HUD
@onready var _launcher: Sprite2D = $Player/Launcher
@onready var _aim: Sprite2D = $Aim
@onready var _bolts_root: Node2D = $Bolts
@onready var _swimmers_root: Node2D = $Swimmers
@onready var _reload_bar: ProgressBar = $ReloadLayer/Reload

var _time_left: float = ROUND_SECONDS
var _reload: float = 0.0
var _spawn_timer: float = 0.0

var _score: int = 0
var _fish: int = 0
var _plastic: int = 0
var _best_multikill: int = 0

var _swimmer_scene := preload("res://src/minigames/harpoon/swimmer.tscn")
var _bolt_texture := preload("res://assets/game/harpoon/bolt.png")


func _ready() -> void:
	_player.position = Vector2(320, BANK_Y)
	_player.set_facing(&"up")
	_player.freeze()
	_reload_bar.visible = false

	_hud.reset_score(0)


func control_hint() -> String:
	return "STICK  move      BUTTON  fire"


func begin() -> void:
	super.begin()
	_player.unfreeze()
	_hud.toast("FIRE!", Color(0.8, 0.95, 1.0), 0.7)


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_time_left = maxf(_time_left - delta, 0.0)
	_hud.set_meter(_time_left / ROUND_SECONDS, &"time")
	if _time_left <= 0.0:
		_finish()
		return

	_player.position.x = clampf(_player.position.x, BANK_MIN_X, BANK_MAX_X)
	_player.position.y = BANK_Y
	# The firing lane follows the player, because the lane is the aim.
	_aim.position.x = _player.position.x

	_tick_reload(delta)
	_tick_spawns(delta)
	_tick_bolts(delta)
	_cull_swimmers()


func _unhandled_input(event: InputEvent) -> void:
	if running and event.is_action_pressed(&"act"):
		_fire()


# --- firing ------------------------------------------------------------------

func _tick_reload(delta: float) -> void:
	if _reload <= 0.0:
		_reload_bar.visible = false
		return
	_reload = maxf(_reload - delta, 0.0)
	_reload_bar.visible = true
	_reload_bar.value = (1.0 - _reload / RELOAD_SECONDS) * 100.0
	_launcher.modulate = Color(0.6, 0.6, 0.7) if _reload > 0.0 else Color.WHITE


func _fire() -> void:
	if _reload > 0.0:
		return
	_reload = RELOAD_SECONDS
	_launcher.modulate = Color(0.6, 0.6, 0.7)
	Audio.sfx(&"cast", 1.5)

	var bolt := Sprite2D.new()
	bolt.texture = _bolt_texture
	bolt.position = Vector2(_player.position.x, BANK_Y - 20.0)
	bolt.z_index = 6
	bolt.set_meta(&"hits", [])
	_bolts_root.add_child(bolt)

	var kick := create_tween()
	kick.tween_property(_launcher, "position:y", -27.0, 0.05)
	kick.tween_property(_launcher, "position:y", -22.0, 0.14)


func _tick_bolts(delta: float) -> void:
	for child in _bolts_root.get_children():
		var bolt := child as Sprite2D
		if bolt == null:
			continue
		bolt.position.y -= BOLT_SPEED * delta
		_check_bolt(bolt)
		if bolt.position.y < WATER_TOP - 18.0:
			_resolve(bolt)


func _check_bolt(bolt: Sprite2D) -> void:
	var hits: Array = bolt.get_meta(&"hits")
	for child in _swimmers_root.get_children():
		var swimmer := child as Swimmer
		if swimmer == null or swimmer.hooked or swimmer in hits:
			continue
		if swimmer.position.distance_to(bolt.position) > BOLT_RADIUS + 9.0:
			continue

		swimmer.hooked = true
		hits.append(swimmer)
		if swimmer.is_plastic():
			# A bottle stops the bolt dead. That is what makes plastic a hazard
			# to shoot around rather than just a thing not to shoot.
			swimmer.impale(bolt.position, true)
			_resolve(bolt)
			return
		swimmer.impale(bolt.position, false)


func _resolve(bolt: Sprite2D) -> void:
	var hits: Array = bolt.get_meta(&"hits")
	var fish_hit := 0
	var gained := 0

	# Each catch pops its own value where it was speared, so a multi-kill reads
	# as three separate wins landing at once rather than one lump sum.
	for swimmer: Swimmer in hits:
		if swimmer.is_plastic():
			_plastic += 1
			gained += SCORE_PLASTIC
			pop(swimmer.position, SCORE_PLASTIC, 1, "BOTTLE")
			Audio.sfx(&"trash")
		else:
			_fish += 1
			fish_hit += 1
			gained += swimmer.value()
			pop(swimmer.position, swimmer.value())
		swimmer.sink_away()

	if fish_hit >= 2:
		gained *= fish_hit
		_best_multikill = maxi(_best_multikill, fish_hit)
		_hud.toast(MULTIKILL_LABELS.get(fish_hit, "x%d" % fish_hit),
				Color(1, 0.9, 0.45), 0.9)
		_hud.set_multiplier(fish_hit)
		Audio.sfx(&"complete", 1.3)
		# The one place hit-stop is used. It stays special by being rare.
		Juice.shake(self, 4.0)
		Juice.hit_stop(self, 0.06)
	elif fish_hit == 1:
		Audio.sfx(&"catch")

	_score = maxi(_score + gained, 0)
	_hud.set_score(_score)
	bolt.queue_free()


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
		swimmer.speed = randf_range(20.0, 29.0)
	elif roll < PLASTIC_CHANCE + RARE_CHANCE:
		swimmer.kind = Swimmer.Kind.FISH_RARE
		swimmer.speed = randf_range(54.0, 72.0)
	else:
		swimmer.kind = Swimmer.Kind.FISH_COMMON
		swimmer.speed = randf_range(29.0, 44.0)

	swimmer.direction = 1.0 if randf() < 0.5 else -1.0
	swimmer.position = Vector2(
		-30.0 if swimmer.direction > 0.0 else 510.0,
		LANES[randi() % LANES.size()])
	swimmer.z_index = 2
	_swimmers_root.add_child(swimmer)


func _cull_swimmers() -> void:
	for child in _swimmers_root.get_children():
		var swimmer := child as Swimmer
		if swimmer == null or swimmer.hooked:
			continue
		if swimmer.position.x < -60.0 or swimmer.position.x > 540.0:
			swimmer.queue_free()


func _finish() -> void:
	_player.freeze()
	Audio.sfx(&"complete")
	_hud.clear_prompt()
	finish(_score, {"fish": _fish, "plastic": _plastic,
			"multikill": _best_multikill})
