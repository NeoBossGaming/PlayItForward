extends MiniGame
## Firefly Lantern -- your light is dying, and the dark is where the points are.
##
## A greed loop. The lantern shrinks constantly and every firefly refills a
## little of it, so playing safe means topping up early and scoring almost
## nothing. The multiplier is tied directly to how small your light has got, so
## the high score demands running on a sliver of lantern in near total darkness.
## Safe play and good play pull in opposite directions -- that tension is the
## whole game.
##
## Lighting is an additively blended sprite over a CanvasModulate rather than a
## PointLight2D: predictable under GL Compatibility, cheap on a Pi, and it still
## works headlessly for the tests.
##
## No fail state: a guttered lantern relights at minimum and costs points.

const ROUND_SECONDS := 60.0
const FIELD := Rect2(30, 54, 420, 198)

const LIGHT_MAX := 1.0
const LIGHT_MIN := 0.16
const LIGHT_DRAIN := 0.115         ## per second
const LIGHT_PER_FLY := 0.17
const LIGHT_START := 0.85

## Lantern scale at full and at empty. Also the radius fireflies are visible in.
const GLOW_SCALE := Vector2(3.5, 1.2)

const SCORE_FLY := 40
const SCORE_GUTTER := -120
const FLY_TARGET := 14             ## how many are alive at once

@onready var _player: TopDownPlayer = $Player
@onready var _hud: HUD = $HUD
@onready var _glow: Sprite2D = $Player/Glow
@onready var _lantern: Sprite2D = $Player/Lantern
## Fireflies live on their own CanvasLayer. CanvasModulate tints only its own
## canvas, and the night filter was turning the one thing the player is meant
## to see glowing in the dark into a grey dot -- additive blending did not
## save it, because the tint applies after the blend.
@onready var _flies_root: Node2D = $FliesLayer/Flies

var _time_left: float = ROUND_SECONDS
var _light: float = LIGHT_START

var _score: int = 0
var _flies: int = 0
var _gutters: int = 0
var _best_multiplier: int = 1

var _mote_texture := preload("res://assets/game/firefly/mote.png")
var _mote_material := preload("res://src/minigames/firefly/additive.tres")


func _ready() -> void:
	_player.position = FIELD.get_center()
	_player.freeze()
	for i in FLY_TARGET:
		_spawn_fly()

	_hud.set_title("Firefly Lantern")
	_hud.reset_score(0)
	_hud.set_objective("Catch fireflies. The dimmer your lantern, the more they pay.")


func begin() -> void:
	super.begin()
	_player.unfreeze()
	_hud.toast("MIND THE DARK", Color(1, 0.95, 0.6), 0.9)


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_time_left = maxf(_time_left - delta, 0.0)
	if _time_left <= 0.0:
		_finish()
		return

	_light -= LIGHT_DRAIN * delta
	if _light <= 0.0:
		_gutter()

	_player.position = _player.position.clamp(FIELD.position, FIELD.end)
	_update_light()
	_tick_flies(delta)


## 1 at a full lantern, up to 4 when it is nearly out.
func light_multiplier() -> int:
	var darkness := 1.0 - clampf((_light - LIGHT_MIN) / (LIGHT_MAX - LIGHT_MIN), 0.0, 1.0)
	return clampi(1 + int(darkness * 3.999), 1, 4)


func _update_light() -> void:
	var t := clampf(_light / LIGHT_MAX, 0.0, 1.0)
	var radius := lerpf(GLOW_SCALE.y, GLOW_SCALE.x, t)
	_glow.scale = Vector2(radius, radius)
	_glow.modulate.a = lerpf(0.55, 0.95, t)
	_lantern.modulate = Color(1, 1, 1).lerp(Color(0.55, 0.5, 0.6), 1.0 - t)

	var multiplier := light_multiplier()
	_best_multiplier = maxi(_best_multiplier, multiplier)
	_hud.set_meter(t, "lantern   x%d" % multiplier)


func _tick_flies(delta: float) -> void:
	for child in _flies_root.get_children():
		var fly := child as Sprite2D
		if fly == null:
			continue
		var drift: Vector2 = fly.get_meta(&"drift")
		fly.position += drift * delta
		# Bounce off the field edge rather than escaping it.
		if fly.position.x < FIELD.position.x or fly.position.x > FIELD.end.x:
			drift.x = -drift.x
		if fly.position.y < FIELD.position.y or fly.position.y > FIELD.end.y:
			drift.y = -drift.y
		fly.set_meta(&"drift", drift)
		fly.position = fly.position.clamp(FIELD.position, FIELD.end)

		var phase: float = float(fly.get_meta(&"phase")) + delta * 3.4
		fly.set_meta(&"phase", phase)
		# Fireflies pulse, which is the only reason they are findable in the dark.
		fly.modulate.a = 0.45 + 0.55 * absf(sin(phase))
		fly.scale = Vector2.ONE * (1.0 + 0.25 * sin(phase))

		if fly.position.distance_to(_player.position) < 15.0:
			_catch(fly)

	while _flies_root.get_child_count() < FLY_TARGET:
		_spawn_fly()


func _spawn_fly() -> void:
	var fly := Sprite2D.new()
	fly.texture = _mote_texture
	fly.material = _mote_material
	fly.scale = Vector2(1.5, 1.5)
	fly.position = Vector2(
		randf_range(FIELD.position.x, FIELD.end.x),
		randf_range(FIELD.position.y, FIELD.end.y))
	fly.set_meta(&"drift", Vector2(randf_range(-20.0, 20.0), randf_range(-15.0, 15.0)))
	fly.set_meta(&"phase", randf() * TAU)
	fly.z_index = 8
	_flies_root.add_child(fly)


func _catch(fly: Sprite2D) -> void:
	_flies += 1
	var multiplier := light_multiplier()
	_score += SCORE_FLY * multiplier
	_light = minf(_light + LIGHT_PER_FLY, LIGHT_MAX)
	_hud.set_score(_score)
	Audio.sfx(&"pickup", 1.0 + 0.1 * multiplier)
	if multiplier > 1:
		_hud.toast("+%d   x%d" % [SCORE_FLY * multiplier, multiplier],
				Color(1, 0.96, 0.6), 0.5)
	fly.queue_free()


func _gutter() -> void:
	_gutters += 1
	_light = LIGHT_MIN
	_score = maxi(_score + SCORE_GUTTER, 0)
	_hud.set_score(_score)
	Audio.sfx(&"deny", 0.7)
	_hud.toast("THE LANTERN GUTTERS", Color(0.8, 0.7, 0.5), 0.9)


func _finish() -> void:
	_player.freeze()
	Audio.sfx(&"complete")
	finish(_score, {"flies": _flies, "gutters": _gutters,
			"best_multiplier": _best_multiplier})
