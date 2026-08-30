extends MiniGame
## Hush Meadow -- forage the meadow before dusk without being seen.
##
## Reworked from an objective run (five petals, then touch a tree) into a timed
## forage. The tree was a stop, not an ending, and one petal per section made the
## whole meadow a corridor.
##
## Tall grass hides you completely and is slow. Sprinting is fast, costs stamina,
## and rustles loudly enough that a bird will break patrol to come and look.
## Three things push against playing safe:
##
##   * the dusk bar multiplies the final score, so dawdling is expensive
##   * a pickup taken near a bird's eye pays double or triple
##   * dew only appears once you are standing inside a grass patch
##
## The last of those is the important one: it means cover is somewhere to go, not
## just somewhere to hide, so the cautious route and the greedy route overlap.
##
## No fail state. Being spotted costs points and puts you back a section.

const SECTIONS := 5
const SECTION_WIDTH := 420.0
const LEVEL_HEIGHT := 270.0
const MARGIN := 26.0

const ROUND_SECONDS := 75.0
## Final score multiplier, from dusk (1.0) to instantly (2.0).
const DAYLIGHT_MAX_MULTIPLIER := 2.0

## The last stretch of the round, when every bird comes home to roost.
const SCRAMBLE_SECONDS := 6.0
## Fraction of the haul lost if dusk catches you standing in the open.
const CAUGHT_OUT_PENALTY := 0.4

const SCORE_SPOTTED := -100
const SPRINT_NOISE_RADIUS := 72.0
const NERVE_CLOSE := 30.0
const NERVE_NEAR := 60.0

const PICKUP_TARGET := 10          ## live pickups kept on the meadow at once
const PICKUP_RADIUS := 15.0

@onready var _player: TopDownPlayer = $Player
@onready var _camera: Camera2D = $Player/Camera
@onready var _hud: HUD = $HUD
@onready var _grass_root: Node2D = $Grass
@onready var _props_root: Node2D = $Props
@onready var _birds_root: Node2D = $Birds
@onready var _pickups_root: Node2D = $Pickups
@onready var _dusk: CanvasModulate = $Dusk
@onready var _fireflies: Node2D = $Fireflies

var _birds: Array[PatrolBird] = []
var _grass_areas: Array[Rect2] = []
var _blockers: Array[Rect2] = []
var _section_starts: PackedVector2Array = PackedVector2Array()

var _gathered: int = 0
var _spotted: int = 0
var _pickup_score: int = 0
var _best_nerve: int = 1
var _daylight: float = 1.0

var _section: int = 0
var _concealed: bool = false
var _recovering: bool = false
var _scrambling: bool = false

var _rng := RandomNumberGenerator.new()

var _bird_scene := preload("res://src/minigames/tall_grass/bird.tscn")
var _pickup_scene := preload("res://src/minigames/tall_grass/collectible.tscn")
var _grass_textures: Array[Texture2D] = []
var _hedge_texture := preload("res://assets/game/tall_grass/hedge.png")
var _rock_texture := preload("res://assets/game/tall_grass/rock.png")
var _cover_texture := preload("res://assets/game/village/glow.png")


func _ready() -> void:
	_rng.randomize()
	for i in 3:
		_grass_textures.append(load("res://assets/game/tall_grass/grass_%d.png" % i))

	_player.can_sprint = true
	_player.stamina_changed.connect(_hud.set_stamina)
	# stamina_changed only fires when the meter moves, so the bar would be
	# invisible until the first sprint without this.
	_hud.set_stamina(1.0, false)
	_player.freeze()
	_build_level()
	_player.position = _section_starts[0]

	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(SECTION_WIDTH * SECTIONS)
	_camera.limit_bottom = int(LEVEL_HEIGHT)

	_hud.reset_score(0)
	_update_objective()


func control_hint() -> String:
	return "STICK  move      BUTTON  sprint"


func begin() -> void:
	super.begin()
	_player.unfreeze()
	_hud.toast("FORAGE", Color(0.75, 1, 0.7), 0.9)


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_daylight = maxf(_daylight - delta / ROUND_SECONDS, 0.0)
	_light_the_evening()
	if not _scrambling and _daylight * ROUND_SECONDS <= SCRAMBLE_SECONDS:
		_begin_scramble()
	if _daylight <= 0.0:
		_finish()
		return

	_player.position = _player.position.clamp(
		Vector2(MARGIN, MARGIN + 9.0),
		Vector2(SECTION_WIDTH * SECTIONS - MARGIN, LEVEL_HEIGHT - MARGIN))

	_update_concealment()
	_update_birds()
	_tick_pickups()
	_section = clampi(int(_player.position.x / SECTION_WIDTH), 0, SECTIONS - 1)
	_update_objective()


# --- concealment and sight ---------------------------------------------------

## The daylight bar is also the lighting. Watching the meadow actually go
## orange and then blue is a much better clock than a number, and the fireflies
## coming out is the cue that the scramble is close.
func _light_the_evening() -> void:
	var t := 1.0 - _daylight
	_dusk.color = Color(1, 1, 1).lerp(Color(0.52, 0.46, 0.72), t * 0.85)
	if t > 0.45:
		_fireflies.modulate.a = minf((t - 0.45) / 0.4, 1.0)


func _update_concealment() -> void:
	var hidden := _grass_at(_player.position) >= 0
	if hidden != _concealed:
		_concealed = hidden
		_player.set_concealed(hidden)
	# Grass is safety, and safety is slow. Crossing open ground is the risk.
	_player.speed = 50.0 if hidden else 70.0


## Index of the grass patch the point is inside, or -1.
func _grass_at(point: Vector2) -> int:
	for i in _grass_areas.size():
		if _grass_areas[i].has_point(point):
			return i
	return -1


func _update_birds() -> void:
	if _recovering:
		return
	if _player.sprinting:
		for bird in _birds:
			if bird.global_position.distance_to(_player.position) < SPRINT_NOISE_RADIUS:
				bird.investigate(_player.position)


## Given to every bird as its `can_see` callable, so what the cone shows and what
## the bird knows can never drift apart.
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


## Sampled line of sight against rocks and hedges. Cheaper than raycasts and
## precise enough at this scale, which keeps the Pi budget free.
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
	Juice.flash(self, Color(1, 0.35, 0.3, 0.4))
	Juice.shake(self, 3.0)
	pop_on_player(SCORE_SPOTTED, "SPOTTED")
	_hud.set_score(_current_score())
	_player.freeze()

	var swoop := create_tween()
	swoop.tween_property(bird, "global_position", _player.position, 0.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	swoop.tween_interval(0.2)
	swoop.tween_callback(_return_to_checkpoint)


func _return_to_checkpoint() -> void:
	_player.position = _section_starts[_section]
	_player.velocity = Vector2.ZERO
	for bird in _birds:
		bird.reset()
	_recovering = false
	if running:
		_player.unfreeze()


# --- pickups -----------------------------------------------------------------

func _tick_pickups() -> void:
	var bounds := Rect2(MARGIN, MARGIN,
			SECTION_WIDTH * SECTIONS - MARGIN * 2.0, LEVEL_HEIGHT - MARGIN * 2.0)

	for child in _pickups_root.get_children():
		var pickup := child as MeadowPickup
		if pickup == null:
			continue

		# Seeds blow away; if one leaves the meadow it is simply replaced.
		if not bounds.has_point(pickup.position):
			pickup.queue_free()
			continue

		# Dew is hidden until the player is standing in the same patch.
		if not pickup.revealed:
			var patch: int = pickup.get_meta(&"patch", -1)
			if patch >= 0 and patch == _grass_at(_player.position):
				pickup.reveal()
			continue

		if pickup.position.distance_to(_player.position) < PICKUP_RADIUS:
			_collect(pickup)

	while _pickups_root.get_child_count() < PICKUP_TARGET:
		_spawn_pickup()


func _spawn_pickup() -> void:
	var pickup: MeadowPickup = _pickup_scene.instantiate()
	var roll := _rng.randf()

	if roll < 0.25 and not _grass_areas.is_empty():
		# Dew, tucked inside a random grass patch and invisible until entered.
		var patch := _rng.randi() % _grass_areas.size()
		pickup.kind = MeadowPickup.Kind.DEW
		pickup.position = _grass_areas[patch].get_center() \
				+ Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-8.0, 8.0))
		pickup.set_meta(&"patch", patch)
	elif roll < 0.55:
		pickup.kind = MeadowPickup.Kind.SEED
		pickup.position = _random_point()
		pickup.drift = Vector2(_rng.randf_range(-22.0, 22.0),
				_rng.randf_range(-14.0, 14.0))
	else:
		pickup.kind = MeadowPickup.Kind.PETAL
		pickup.position = _random_point()

	_pickups_root.add_child(pickup)


func _random_point() -> Vector2:
	return Vector2(
		_rng.randf_range(MARGIN + 10.0, SECTION_WIDTH * SECTIONS - MARGIN - 10.0),
		_rng.randf_range(MARGIN + 10.0, LEVEL_HEIGHT - MARGIN - 10.0))


func _collect(pickup: MeadowPickup) -> void:
	_gathered += 1
	var nerve := _nerve_multiplier(pickup.position)
	_best_nerve = maxi(_best_nerve, nerve)
	var gained := pickup.value() * nerve
	_pickup_score += gained

	Audio.sfx(&"pickup", 1.0 + 0.12 * nerve)
	pop(pickup.position, gained, nerve, "NERVE" if nerve > 1 else pickup.label())
	_hud.set_score(_current_score())
	pickup.queue_free()


## How close the nearest bird's eye was when the pickup was taken.
func _nerve_multiplier(at: Vector2) -> int:
	var closest := INF
	for bird in _birds:
		closest = minf(closest, bird.global_position.distance_to(at))
	if closest <= PatrolBird.VISION_RANGE + NERVE_CLOSE:
		return 3
	if closest <= PatrolBird.VISION_RANGE + NERVE_NEAR:
		return 2
	return 1


# --- the roost scramble ------------------------------------------------------

## The last six seconds. Every bird comes home across the meadow and the player
## has to be inside cover when the light goes. It turns the end of the round from
## a stop into a decision: one more grab, or get to grass.
func _begin_scramble() -> void:
	_scrambling = true
	Audio.sfx(&"spotted", 0.7)
	_hud.toast("DUSK -- GET TO COVER!", Color(1, 0.55, 0.4), 1.6)
	for bird in _birds:
		bird.investigate(_player.position)


func _update_objective() -> void:
	_hud.set_meter(_daylight, &"dusk")
	# The scramble warning is a red vignette pulsing in from the screen edges,
	# not a sentence -- nobody reads a sentence while panicking.
	_hud.set_alarm(1.0 if _scrambling and not _concealed else 0.0)


func _current_score() -> int:
	return maxi(_pickup_score + _spotted * SCORE_SPOTTED, 0)


## 1.0 at nightfall, DAYLIGHT_MAX_MULTIPLIER if you finished instantly.
func daylight_multiplier() -> float:
	return 1.0 + (DAYLIGHT_MAX_MULTIPLIER - 1.0) * _daylight


func _finish() -> void:
	_player.freeze()
	var caught_out := not _concealed
	var base := _current_score()
	if caught_out:
		base = int(base * (1.0 - CAUGHT_OUT_PENALTY))
		Audio.sfx(&"deny")
		_hud.toast("CAUGHT IN THE OPEN", Color(1, 0.45, 0.4), 1.4)
	else:
		Audio.sfx(&"complete")
		_hud.toast("SAFE IN THE GRASS", Color(0.75, 1, 0.75), 1.4)

	# Dusk has fallen, so the multiplier is whatever you banked along the way --
	# the daylight bonus is earned by gathering early, not by finishing early.
	var score := base
	_hud.set_score(maxi(score, 0))
	finish(score, {"gathered": _gathered, "spotted": _spotted,
			"nerve": _best_nerve, "safe": not caught_out})


# --- level construction ------------------------------------------------------

func _build_level() -> void:
	for section in SECTIONS:
		var left := section * SECTION_WIDTH
		_section_starts.append(Vector2(left + MARGIN + 6.0, LEVEL_HEIGHT * 0.5))
		_build_grass(left)
		_build_props(left)
		_build_birds(left, section)


func _build_grass(left: float) -> void:
	# Jittered grid: clumps read as cover, an even scatter reads as decoration.
	for column in 5:
		for row in 3:
			if _rng.randf() < 0.22:
				continue
			var centre := Vector2(
				left + 60.0 + column * 75.0 + _rng.randf_range(-16.0, 16.0),
				52.0 + row * 79.0 + _rng.randf_range(-13.0, 13.0))

			# Shaded ground under the clump. Blades alone do not read against
			# green, and a hiding place the player cannot see is worse than no
			# hiding place. Soft-edged so overlapping clumps merge cleanly.
			var cover := Sprite2D.new()
			cover.texture = _cover_texture
			cover.position = centre
			cover.scale = Vector2(1.05, 0.75)
			cover.modulate = Color(0.16, 0.30, 0.13, 0.42)
			cover.z_index = 2
			_grass_root.add_child(cover)

			for i in _rng.randi_range(3, 5):
				var blade := Sprite2D.new()
				blade.texture = _grass_textures[_rng.randi() % 3]
				blade.position = centre + Vector2(_rng.randf_range(-18.0, 18.0),
						_rng.randf_range(-13.0, 13.0))
				blade.z_index = 8
				_grass_root.add_child(blade)

			_grass_areas.append(Rect2(centre - Vector2(27, 20), Vector2(54, 40)))


func _build_props(left: float) -> void:
	for i in _rng.randi_range(2, 3):
		var prop := Sprite2D.new()
		prop.texture = _hedge_texture if _rng.randf() < 0.5 else _rock_texture
		prop.position = Vector2(
			left + _rng.randf_range(90.0, SECTION_WIDTH - 68.0),
			_rng.randf_range(60.0, LEVEL_HEIGHT - 52.0))
		prop.z_index = 4
		_props_root.add_child(prop)
		_blockers.append(Rect2(prop.position - Vector2(12, 11), Vector2(24, 21)))


func _build_birds(left: float, section: int) -> void:
	# One bird in the first stretch, two after: the difficulty curve is density.
	for i in (1 if section == 0 else 2):
		var bird: PatrolBird = _bird_scene.instantiate()
		var lane_x := left + _rng.randf_range(135.0, SECTION_WIDTH - 52.0)
		var lane_y := _rng.randf_range(60.0, LEVEL_HEIGHT - 52.0)
		if _rng.randf() < 0.45:
			bird.waypoints = PackedVector2Array([
				Vector2(lane_x, 52.0), Vector2(lane_x, LEVEL_HEIGHT - 45.0)])
		else:
			# Patrols stay clear of a section entrance, so re-entry after being
			# spotted is never a trap.
			bird.waypoints = PackedVector2Array([
				Vector2(left + 112.0, lane_y),
				Vector2(left + SECTION_WIDTH - 38.0, lane_y)])
		bird.speed = _rng.randf_range(26.0, 39.0)
		bird.can_see = _visible_from
		bird.spotted_player.connect(_on_bird_spotted.bind(bird))
		_birds_root.add_child(bird)
		_birds.append(bird)
