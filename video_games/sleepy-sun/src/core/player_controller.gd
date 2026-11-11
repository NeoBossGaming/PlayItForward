class_name TopDownPlayer
extends CharacterBody2D
## The one player controller, shared by the hub and all four minigames.
##
## Sprite origin sits at the character's feet (the AnimatedSprite2D is offset up
## by half its height), so positioning against ground features and sorting by Y
## both work without per-scene fudging.
##
## Riverleap drives this node with `input_enabled = false` and moves it by tween;
## everything else lets it read the input map directly.

const DIRECTIONS := {
	&"down": Vector2.DOWN,
	&"up": Vector2.UP,
	&"left": Vector2.LEFT,
	&"right": Vector2.RIGHT,
}

## Base walking speed. Held ~20% above a straight 0.75x rescale from 640x360 --
## the fields shrank with the viewport, so this makes the character cover
## noticeably more ground per second than before rather than the same amount.
@export var speed: float = 70.0
@export var sprint_multiplier: float = 1.75
@export var acceleration: float = 900.0
@export var friction: float = 1100.0
## When false the node ignores the input map entirely. Set velocity yourself.
@export var input_enabled: bool = true
## Allows sprinting with `act`, gated on stamina. On in the three games built
## around getting somewhere in time: Hush Meadow, Crow Watch, Acorn Storm.
@export var can_sprint: bool = false

## Stamina turns sprinting from a button you hold into a resource you spend.
## Base speed stays walkable, so a player who never sprints can still finish --
## the sprint is a burst for the moment that needs it.
@export var max_stamina: float = 1.0
@export var stamina_drain: float = 0.42      ## ~2.4s of continuous sprint
@export var stamina_regen: float = 0.30      ## ~3.3s back to full
## Once stamina bottoms out, this much has to come back before sprinting is
## allowed again -- roughly a second and a half of walking. Set low (0.15) this
## did nothing useful: the meter refilled past it in half a second and the
## player just stutter-sprinted forever, which is the exact thing it exists to
## stop. It has to be a real rest to be a real decision.
@export var stamina_recover_to: float = 0.45

## --- jump look ---------------------------------------------------------------
##
## A game that moves the player by tween (Riverleap hops between leaves) used to
## leave the sprite in its idle pose, so the character slid through the air
## standing still. For a while the fix was a POSE -- one paused walk frame,
## mirrored -- because there were no drawn jump frames.
##
## There are now: `jump_<facing>_0..2`, crouch / airborne / land, derived from
## the idle art so they keep the hand-drawn palette (see player_jump_frames()
## in tools/make_placeholders.py). The code-side squash, stretch and lean stay,
## because three frames alone cannot carry a quarter-second arc -- the frames
## give the pose, the scaling gives the weight. The landing squash is still the
## part that sells it.

## Radians the sprite leans into the hop at full tilt.
const JUMP_LEAN := 0.21
## How far the sprite stretches along its travel, as a fraction of normal.
## Cut from 0.17 once real jump frames existed: the frames now carry the pose,
## so the scaling only has to add weight. Left at 0.17 it fought them -- a
## narrower, taller sprite on top of an already-lifted pose read as the
## character being stretched rather than jumping.
const JUMP_STRETCH := 0.08
## How far it squashes on impact. Bigger than the stretch on purpose -- landings
## read as heavier than take-offs.
const LAND_SQUASH := 0.28
const LAND_RECOVER := 0.17

signal started_moving
signal stopped_moving
signal stamina_changed(value: float, exhausted: bool)

var facing: StringName = &"down"
var sprinting: bool = false
var is_moving: bool = false
var stamina: float = 1.0
var exhausted: bool = false
## True between start_jump() and land(). While it is set the normal walk/idle
## animation picker stands down, so it cannot fight the pose.
var jumping: bool = false

const _PUFF: Texture2D = preload("res://assets/game/decor/dust.png")

@onready var anim: AnimatedSprite2D = $Anim
@onready var shadow: Sprite2D = $Shadow

var _rest_scale := Vector2.ONE
var _rest_shadow := Vector2.ONE
var _landing_timer: float = 0.0


func _ready() -> void:
	stamina = max_stamina
	# The sprite is authored at 1.5x, so every squash and stretch is relative to
	# whatever the scene set rather than to 1.
	_rest_scale = anim.scale
	_rest_shadow = shadow.scale


func _physics_process(delta: float) -> void:
	if input_enabled:
		var direction := Input.get_vector(&"move_left", &"move_right",
				&"move_up", &"move_down")
		var wants_sprint := can_sprint and Input.is_action_pressed(&"act") \
				and direction != Vector2.ZERO
		sprinting = wants_sprint and not exhausted and stamina > 0.0
		var target := direction * speed * (sprint_multiplier if sprinting else 1.0)
		if direction == Vector2.ZERO:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		else:
			velocity = velocity.move_toward(target, acceleration * delta)
			set_facing_from_vector(direction)

	# Exactly one of these runs per frame, so the meter can never drain and
	# refill at the same time.
	if sprinting:
		_drain_stamina(delta)
	else:
		_recover_stamina(delta)

	move_and_slide()
	_update_animation()


func _drain_stamina(delta: float) -> void:
	if not can_sprint:
		return
	stamina -= stamina_drain * delta
	if stamina <= 0.0:
		stamina = 0.0
		exhausted = true
		sprinting = false
	stamina_changed.emit(stamina / max_stamina, exhausted)


func _recover_stamina(delta: float) -> void:
	if not can_sprint or (stamina >= max_stamina and not exhausted):
		return
	stamina = minf(stamina + stamina_regen * delta, max_stamina)
	if exhausted and stamina >= stamina_recover_to:
		exhausted = false
	stamina_changed.emit(stamina / max_stamina, exhausted)


## --- jumping -----------------------------------------------------------------

## How long the landing frame is held before the walk/idle picker takes over.
## Short: it is a beat of weight, not a pose to stand in.
const LAND_FRAME_TIME := 0.13
## Fraction of the arc spent in the crouch frame before the airborne one.
const CROUCH_UNTIL := 0.16

## Call once as the hop leaves the ground. `direction` is -1, 0 or 1 for the
## lean. There are real frames per facing now, so nothing is mirrored and
## nothing is posed from a walk clip.
func start_jump(direction: int = 0) -> void:
	jumping = true
	anim.flip_h = false
	_play_jump_frame(0)
	_puff(2, 0.45)
	set_jump_progress(0.0, direction)


## The jump clips are driven by the arc rather than by their own playback, so
## the pose always matches where the character actually is. Falls back to the
## idle clip if a facing has no jump set, so a half-finished art pass cannot
## crash the game.
func _play_jump_frame(index: int) -> void:
	var clip := StringName("jump_" + facing)
	if anim.sprite_frames == null or not anim.sprite_frames.has_animation(clip):
		return
	if anim.animation != clip:
		anim.play(clip)
	anim.pause()
	anim.frame = clampi(index, 0, anim.sprite_frames.get_frame_count(clip) - 1)


## Call every frame of the hop with `t` running 0 -> 1.
func set_jump_progress(t: float, direction: int = 0) -> void:
	if not jumping:
		return
	var height := sin(clampf(t, 0.0, 1.0) * PI)     # 0 at both ends, 1 at apex
	var vertical := cos(clampf(t, 0.0, 1.0) * PI)   # +1 rising, -1 falling
	_play_jump_frame(0 if t < CROUCH_UNTIL else 1)

	# Stretched while climbing and while dropping, neutral at the apex, which is
	# where a real body is least deformed.
	var stretch := JUMP_STRETCH * absf(vertical)
	anim.scale = Vector2(_rest_scale.x * (1.0 - stretch * 0.55),
			_rest_scale.y * (1.0 + stretch))
	anim.rotation = JUMP_LEAN * float(direction) * height

	# The shadow is the only thing telling the player how high they are.
	shadow.scale = _rest_shadow * (1.0 - height * 0.38)
	shadow.modulate.a = 0.75 - height * 0.4


## Call once on touchdown.
func land() -> void:
	if not jumping:
		return
	jumping = false
	anim.rotation = 0.0
	anim.flip_h = false
	shadow.scale = _rest_shadow
	shadow.modulate.a = 0.75
	_puff(3, 0.7)

	# Hold the landing frame for a beat. Without this the picker snaps back to
	# idle on the very next physics tick and the third frame is never seen.
	_play_jump_frame(2)
	_landing_timer = LAND_FRAME_TIME

	anim.scale = Vector2(_rest_scale.x * (1.0 + LAND_SQUASH),
			_rest_scale.y * (1.0 - LAND_SQUASH))
	create_tween().tween_property(anim, "scale", _rest_scale, LAND_RECOVER) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Drops the pose without the landing flourish, for a hop that ended in water
## rather than on a leaf. Safe to call when not jumping.
func cancel_jump() -> void:
	jumping = false
	_landing_timer = 0.0
	anim.rotation = 0.0
	anim.flip_h = false
	anim.scale = _rest_scale
	shadow.scale = _rest_shadow
	shadow.modulate.a = 0.75


## A few motes kicked up at the feet. Cheap, and it is what makes a landing
## land rather than merely stop.
func _puff(count: int, strength: float) -> void:
	for i in count:
		var mote := Sprite2D.new()
		mote.texture = _PUFF
		mote.position = Vector2(randf_range(-3.0, 3.0), randf_range(-1.0, 2.0))
		# Big and warm rather than small and white: at 4px a near-white mote is
		# invisible over both the water and a lit leaf, which is every surface
		# this game has.
		mote.modulate = Color(1, 0.96, 0.82, 0.85 * strength)
		mote.scale = Vector2.ONE * randf_range(1.6, 3.2)
		add_child(mote)
		var drift := Vector2(randf_range(-16.0, 16.0), randf_range(-10.0, -3.0)) * strength
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(mote, "position", mote.position + drift, 0.34)
		tween.tween_property(mote, "modulate:a", 0.0, 0.34)
		tween.chain().tween_callback(mote.queue_free)


func _update_animation() -> void:
	# The jump owns the sprite outright; letting the picker run would reset the
	# frame and unpause the clip every physics tick. The landing frame holds
	# the same claim for a beat after touchdown.
	if jumping:
		return
	if _landing_timer > 0.0:
		_landing_timer -= get_physics_process_delta_time()
		if _landing_timer > 0.0:
			return
		anim.play()
	# The jump pose mirrors the sprite; nothing else ever should, so clear it
	# here too rather than trusting every exit from the pose to tidy up.
	anim.flip_h = false
	var was_moving := is_moving
	is_moving = velocity.length() > 6.0
	if is_moving != was_moving:
		if is_moving:
			started_moving.emit()
		else:
			stopped_moving.emit()

	var wanted := StringName(("walk_" if is_moving else "idle_") + facing)
	if anim.animation != wanted:
		anim.play(wanted)
	# Sprinting reads as sprinting because the legs keep up with the speed.
	anim.speed_scale = sprint_multiplier if sprinting else 1.0


## Picks the four-direction facing from an arbitrary vector, preferring the
## dominant axis so diagonal movement does not flicker between two clips.
func set_facing_from_vector(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	if absf(direction.x) > absf(direction.y):
		facing = &"right" if direction.x > 0.0 else &"left"
	else:
		facing = &"down" if direction.y > 0.0 else &"up"


func set_facing(new_facing: StringName) -> void:
	if DIRECTIONS.has(new_facing):
		facing = new_facing


func freeze() -> void:
	input_enabled = false
	velocity = Vector2.ZERO


func unfreeze() -> void:
	input_enabled = true


## Used by Hush Meadow: the player dims and the shadow shrinks while hidden.
func set_concealed(concealed: bool) -> void:
	var target_alpha := 0.5 if concealed else 1.0
	anim.modulate.a = target_alpha
	shadow.modulate.a = 0.35 if concealed else 0.75
