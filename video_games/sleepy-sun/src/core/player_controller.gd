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

signal started_moving
signal stopped_moving
signal stamina_changed(value: float, exhausted: bool)

var facing: StringName = &"down"
var sprinting: bool = false
var is_moving: bool = false
var stamina: float = 1.0
var exhausted: bool = false

@onready var anim: AnimatedSprite2D = $Anim
@onready var shadow: Sprite2D = $Shadow


func _ready() -> void:
	stamina = max_stamina


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


func _update_animation() -> void:
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
