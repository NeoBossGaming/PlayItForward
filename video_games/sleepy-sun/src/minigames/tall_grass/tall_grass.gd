extends MiniGame
## Hush Meadow -- cross three meadow sections gathering sunpetals without being
## seen by the birds patrolling overhead.
##
## Tall grass hides you completely, so the safe route is obvious; what makes it
## a game is that the safe route is slow and the petals are never on it. Holding
## the action button sprints, which is how you cover open ground in time -- but
## it rustles, and a bird close enough to hear will break patrol to come and
## look. That trade is the entire minigame.
##
## No fail state. Being spotted returns you to the start of the current section
## and costs points. Petals you already picked up stay picked up.

const SECTIONS := 3
const SECTION_WIDTH := 560.0
const LEVEL_HEIGHT := 360.0
const MARGIN := 34.0

const SCORE_PETAL := 300
const SCORE_ARRIVAL := 400
const SCORE_SPOTTED := -100
const SCORE_TIME_BONUS := 400
const PAR_SECONDS := 95.0

const SPRINT_NOISE_RADIUS := 96.0

@onready var _player: TopDownPlayer = $Player
@onready var _camera: Camera2D = $Player/Camera
@onready var _hud: HUD = $HUD
@onready var _grass_root: Node2D = $Grass
@onready var _props_root: Node2D = $Props
@onready var _birds_root: Node2D = $Birds
@onready var _petals_root: Node2D = $Petals
@onready var _goal: Sprite2D = $Goal

var _birds: Array[PatrolBird] = []
var _grass_areas: Array[Rect2] = []
var _blockers: Array[Rect2] = []
var _section_starts: PackedVector2Array = PackedVector2Array()

var _petals: int = 0
var _spotted: int = 0
var _section: int = 0
var _concealed: bool = false
var _recovering: bool = false

var _rng := RandomNumberGenerator.new()

var _bird_scene := preload("res://src/minigames/tall_grass/bird.tscn")
var _petal_texture := preload("res://assets/game/tall_grass/petal.png")
var _grass_textures: Array[Texture2D] = []
var _hedge_texture := preload("res://assets/game/tall_grass/hedge.png")
var _cover_texture := preload("res://assets/game/village/glow.png")
var _rock_texture := preload("res://assets/game/tall_grass/rock.png")


func _ready() -> void:
	_rng.randomize()
	for i in 3:
		_grass_textures.append(load("res://assets/game/tall_grass/grass_%d.png" % i))

	_player.can_sprint = true
	_player.freeze()
	_build_level()
	_player.position = _section_starts[0]

	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(SECTION_WIDTH * SECTIONS)
	_camera.limit_bottom = int(LEVEL_HEIGHT)

	_hud.set_title("Hush Meadow")
	_hud.reset_score(0)
	_update_objective()


func begin() -> void:
	super.begin()
	_player.unfreeze()
	_hud.toast("STAY LOW", Color(0.75, 1, 0.7), 0.9)


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_player.position = _player.position.clamp(
		Vector2(MARGIN, MARGIN + 12.0),
		Vector2(SECTION_WIDTH * SECTIONS - MARGIN, LEVEL_HEIGHT - MARGIN))

	_update_concealment()
	_update_birds()
	_check_pickups()
	_check_goal()
	_section = clampi(int(_player.position.x / SECTION_WIDTH), 0, SECTIONS - 1)


# --- concealment and sight ---------------------------------------------------

func _update_concealment() -> void:
	var feet := _player.position
	var hidden := false
	for area in _grass_areas:
		if area.has_point(feet):
			hidden = true
			break
	if hidden != _concealed:
		_concealed = hidden
		_player.set_concealed(hidden)
	# Grass is safety, and safety is slow. Crossing open ground is the risk.
	_player.speed = 56.0 if hidden else 78.0


func _update_birds() -> void:
	if _recovering:
		return
	# Sprinting rustles. Any bird close enough breaks patrol to come and look.
	if _player.sprinting and not _recovering:
		for bird in _birds:
			if bird.global_position.distance_to(_player.position) < SPRINT_NOISE_RADIUS:
				bird.investigate(_player.position)

	# Rustling in the grass is quieter, but not silent.
	if _concealed and _player.is_moving and _player.sprinting:
		_hud.prompt("rustle...")
	else:
		_hud.clear_prompt()


## Given to every bird as its `can_see` callable. One place decides visibility,
## so what the cone shows and what the bird knows can never drift apart.
func _visible_from(from: Vector2, facing: Vector2) -> bool:
	if _concealed or _recovering or not running:
		return false
	var to_player := _player.position - from
	var distance := to_player.length()
	if distance > PatrolBird.VISION_RANGE or distance < 0.01:
		return false
	if absf(facing.angle_to(to_player)) > PatrolBird.VISION_HALF_ANGLE:
		return false
	return not _line_blocked(from, _player.position)


## Sampled line-of-sight against the rocks and hedges. Cheaper than physics
## raycasts and precise enough at this scale -- and it keeps the Pi budget free.
func _line_blocked(from: Vector2, to: Vector2) -> bool:
	const SAMPLES := 8
	for i in range(1, SAMPLES):
		var point := from.lerp(to, float(i) / SAMPLES)
		for blocker in _blockers:
			if blocker.has_point(point):
				return true
	return false


func _on_bird_spotted(bird: PatrolBird) -> void:
	if _recovering or not running:
		return
	_recovering = true
	_spotted += 1
	Audio.sfx(&"spotted")
	_hud.toast("SPOTTED!", Color(1, 0.45, 0.4), 1.0)
	_hud.set_score(_current_score())
	_player.freeze()

	# The bird swoops, and you wake up back at the start of this stretch. You
	# keep every petal you already found.
	var swoop := create_tween()
	swoop.tween_property(bird, "global_position", _player.position, 0.35) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	swoop.tween_interval(0.25)
	swoop.tween_callback(_return_to_checkpoint)


func _return_to_checkpoint() -> void:
	_player.position = _section_starts[_section]
	_player.velocity = Vector2.ZERO
	for bird in _birds:
		bird.reset()
	_recovering = false
	if running:
		_player.unfreeze()


# --- objectives --------------------------------------------------------------

func _check_pickups() -> void:
	for petal: Sprite2D in _petals_root.get_children():
		petal.rotation += get_process_delta_time() * 1.4
		if petal.position.distance_to(_player.position) < 16.0:
			_petals += 1
			Audio.sfx(&"pickup")
			_hud.toast("+%d" % SCORE_PETAL, Color(1, 0.9, 0.55), 0.6)
			_hud.set_score(_current_score())
			_update_objective()
			petal.queue_free()


func _check_goal() -> void:
	var ready_to_leave := _petals >= SECTIONS
	_goal.modulate = Color(1, 1, 1) if ready_to_leave else Color(0.5, 0.5, 0.55)
	if not ready_to_leave:
		return
	if _player.position.distance_to(_goal.position) < 26.0:
		_finish()


func _update_objective() -> void:
	_hud.set_meter(float(_petals) / float(SECTIONS), "sunpetals")
	if _petals >= SECTIONS:
		_hud.set_objective("All petals found. Reach the hollow tree.")
	else:
		_hud.set_objective("Gather %d sunpetal%s. Keep out of the birds' sight."
				% [SECTIONS - _petals, "" if SECTIONS - _petals == 1 else "s"])


func _current_score() -> int:
	return _petals * SCORE_PETAL + _spotted * SCORE_SPOTTED


func _finish() -> void:
	_player.freeze()
	Audio.sfx(&"complete")
	var pace := clampf(PAR_SECONDS / maxf(elapsed, 1.0), 0.0, 1.0)
	var score := _current_score() + SCORE_ARRIVAL + int(SCORE_TIME_BONUS * pace)
	_hud.set_score(maxi(score, 0))
	finish(score, {"petals": _petals, "spotted": _spotted})


# --- level construction ------------------------------------------------------

## Each section is generated fresh so the meadow is never memorised, but under
## fixed rules: a petal always sits in the far half, there is always grass
## within reach of it, and no bird ever patrols across the section entrance.
func _build_level() -> void:
	for section in SECTIONS:
		var left := section * SECTION_WIDTH
		_section_starts.append(Vector2(left + MARGIN + 8.0, LEVEL_HEIGHT * 0.5))
		_build_grass(left)
		_build_props(left)
		_build_petal(left)
		_build_birds(left, section)

	_goal.position = Vector2(SECTION_WIDTH * SECTIONS - 52.0, LEVEL_HEIGHT * 0.5)


func _build_grass(left: float) -> void:
	# Jittered grid: clumps read as cover, an even scatter reads as decoration.
	for column in 5:
		for row in 3:
			if _rng.randf() < 0.22:
				continue
			var centre := Vector2(
				left + 80.0 + column * 100.0 + _rng.randf_range(-22.0, 22.0),
				70.0 + row * 105.0 + _rng.randf_range(-18.0, 18.0))
			# Shaded ground under the clump. Blades alone do not read against
			# green at this resolution, and a hiding place the player cannot
			# see is worse than no hiding place at all. Soft-edged so
			# overlapping clumps merge into one patch instead of showing seams.
			var cover := Sprite2D.new()
			cover.texture = _cover_texture
			cover.position = centre
			cover.scale = Vector2(1.15, 0.85)
			cover.modulate = Color(0.16, 0.30, 0.13, 0.42)
			cover.z_index = 2
			_grass_root.add_child(cover)

			var clump := _rng.randi_range(3, 5)
			for i in clump:
				var offset := Vector2(_rng.randf_range(-20.0, 20.0),
						_rng.randf_range(-14.0, 14.0))
				var blade := Sprite2D.new()
				blade.texture = _grass_textures[_rng.randi() % 3]
				blade.position = centre + offset
				blade.z_index = 8
				_grass_root.add_child(blade)
			_grass_areas.append(Rect2(centre - Vector2(30, 22), Vector2(60, 44)))


func _build_props(left: float) -> void:
	for i in _rng.randi_range(2, 3):
		var is_hedge := _rng.randf() < 0.5
		var prop := Sprite2D.new()
		prop.texture = _hedge_texture if is_hedge else _rock_texture
		prop.position = Vector2(
			left + _rng.randf_range(120.0, SECTION_WIDTH - 90.0),
			_rng.randf_range(80.0, LEVEL_HEIGHT - 70.0))
		prop.z_index = 4
		_props_root.add_child(prop)
		_blockers.append(Rect2(prop.position - Vector2(16, 14), Vector2(32, 28)))


func _build_petal(left: float) -> void:
	var petal := Sprite2D.new()
	petal.texture = _petal_texture
	petal.z_index = 6
	# Far half of the section, so every petal is worth a detour.
	petal.position = Vector2(
		left + _rng.randf_range(SECTION_WIDTH * 0.5, SECTION_WIDTH - 70.0),
		_rng.randf_range(70.0, LEVEL_HEIGHT - 60.0))
	_petals_root.add_child(petal)


func _build_birds(left: float, section: int) -> void:
	# One bird in the first stretch, two after: the difficulty curve is density.
	var count := 1 if section == 0 else 2
	for i in count:
		var bird: PatrolBird = _bird_scene.instantiate()
		var vertical := _rng.randf() < 0.45
		# Patrols stay clear of the section entrance so re-entry is never a trap.
		var lane_x := left + _rng.randf_range(180.0, SECTION_WIDTH - 70.0)
		var lane_y := _rng.randf_range(80.0, LEVEL_HEIGHT - 70.0)
		if vertical:
			bird.waypoints = PackedVector2Array([
				Vector2(lane_x, 70.0), Vector2(lane_x, LEVEL_HEIGHT - 60.0)])
		else:
			bird.waypoints = PackedVector2Array([
				Vector2(left + 150.0, lane_y),
				Vector2(left + SECTION_WIDTH - 50.0, lane_y)])
		bird.speed = _rng.randf_range(34.0, 52.0)
		bird.can_see = _visible_from
		bird.spotted_player.connect(_on_bird_spotted.bind(bird))
		_birds_root.add_child(bird)
		_birds.append(bird)
