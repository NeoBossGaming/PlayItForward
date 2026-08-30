extends MiniGame
## Acorn Storm -- squirrels pelt the clearing; dodge the acorns, catch the fruit.
##
## The simplest game in the pool on purpose. Somebody who has never touched the
## cabinet should understand it in one second of watching: things fall, one kind
## hurts, one kind is good. No rules to read, which makes it the best card to be
## dealt first.
##
## Everything that is about to land is telegraphed by a ring on the ground that
## grows as it comes -- the same warning language as Riverleap's shaking leaf,
## deliberately reused so the cabinet teaches one visual grammar rather than
## four.
##
## No fail state: a hit is a stun and some points, never an ending.

const ROUND_SECONDS := 60.0
const FIELD := Rect2(36, 72, 408, 174)

## Warning time from spawn to impact. Has to be long enough to actually cross
## the field for a fruit, or the good half of the game is decoration.
const FALL_SECONDS := 1.5
const STUN_SECONDS := 0.6

const SCORE_FRUIT := 65
const SCORE_HIT := -80
const COMBO_PER_LEVEL := 3
const COMBO_MAX := 4

## Spawn interval eases from the first value to the second across the round.
const ACORN_INTERVAL := Vector2(0.85, 0.30)
const FRUIT_INTERVAL := Vector2(1.90, 1.30)

@onready var _player: TopDownPlayer = $Player
@onready var _hud: HUD = $HUD
@onready var _falling_root: Node2D = $Falling

var _time_left: float = ROUND_SECONDS
var _acorn_timer: float = 0.0
var _fruit_timer: float = 0.6
var _stun: float = 0.0

var _score: int = 0
var _fruit: int = 0
var _hits: int = 0
var _combo: int = 0
var _best_combo: int = 0

var _acorn_texture := preload("res://assets/game/acorn_storm/acorn.png")
var _fruit_texture := preload("res://assets/game/acorn_storm/sunfruit.png")
var _impact_texture := preload("res://assets/game/acorn_storm/impact.png")


func _ready() -> void:
	_player.position = FIELD.get_center()
	# Faster than the walking games: this one is pure dodging and it should feel
	# frantic rather than deliberate.
	_player.speed = 92.0
	_player.can_sprint = true
	_player.stamina_changed.connect(_hud.set_stamina)
	# stamina_changed only fires when the meter moves, so the bar would be
	# invisible until the first sprint without this.
	_hud.set_stamina(1.0, false)
	_player.freeze()
	_hud.reset_score(0)


func control_hint() -> String:
	return "STICK  move      BUTTON  sprint"


func begin() -> void:
	super.begin()
	_player.unfreeze()
	_hud.toast("LOOK UP!", Color(1, 0.8, 0.5), 0.8)


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_time_left = maxf(_time_left - delta, 0.0)
	_hud.set_meter(_time_left / ROUND_SECONDS, &"time")
	if _time_left <= 0.0:
		_finish()
		return

	_tick_stun(delta)
	_player.position = _player.position.clamp(FIELD.position, FIELD.end)
	_tick_spawns(delta)
	_tick_falling(delta)


func _tick_stun(delta: float) -> void:
	if _stun <= 0.0:
		return
	_stun -= delta
	if _stun <= 0.0:
		_player.unfreeze()
		_player.anim.modulate = Color.WHITE
	else:
		_player.anim.modulate = Color(1, 0.6, 0.6, 0.6 + 0.4 * sin(_stun * 40.0))


## Difficulty is density: the same falling objects, closer together.
func _pressure() -> float:
	return 1.0 - _time_left / ROUND_SECONDS


func _tick_spawns(delta: float) -> void:
	var pressure := _pressure()

	_acorn_timer -= delta
	if _acorn_timer <= 0.0:
		_acorn_timer = lerpf(ACORN_INTERVAL.x, ACORN_INTERVAL.y, pressure) \
				* randf_range(0.75, 1.25)
		_spawn(true)

	_fruit_timer -= delta
	if _fruit_timer <= 0.0:
		_fruit_timer = lerpf(FRUIT_INTERVAL.x, FRUIT_INTERVAL.y, pressure) \
				* randf_range(0.8, 1.2)
		_spawn(false)


func _spawn(is_acorn: bool) -> void:
	var landing := Vector2(
		randf_range(FIELD.position.x + 12.0, FIELD.end.x - 12.0),
		randf_range(FIELD.position.y + 12.0, FIELD.end.y - 12.0))

	var marker := Sprite2D.new()
	marker.texture = _impact_texture
	marker.position = landing
	marker.modulate = Color(1, 0.55, 0.4, 0.85) if is_acorn \
			else Color(1, 0.88, 0.45, 0.85)
	marker.scale = Vector2(0.25, 0.25)
	marker.z_index = 1

	var falling := Sprite2D.new()
	falling.texture = _acorn_texture if is_acorn else _fruit_texture
	falling.position = landing + Vector2(0, -128.0)
	falling.z_index = 12
	falling.scale = Vector2(1.4, 1.4)

	var holder := Node2D.new()
	holder.set_meta(&"acorn", is_acorn)
	holder.set_meta(&"landing", landing)
	holder.set_meta(&"life", 0.0)
	holder.add_child(marker)
	holder.add_child(falling)
	_falling_root.add_child(holder)


func _tick_falling(delta: float) -> void:
	for child in _falling_root.get_children():
		var holder := child as Node2D
		if holder == null or holder.get_child_count() < 2:
			continue
		var life: float = float(holder.get_meta(&"life")) + delta
		holder.set_meta(&"life", life)

		var t := clampf(life / FALL_SECONDS, 0.0, 1.0)
		var landing: Vector2 = holder.get_meta(&"landing")
		var marker := holder.get_child(0) as Sprite2D
		var falling := holder.get_child(1) as Sprite2D

		# The ring tightening onto the spot is the countdown.
		marker.scale = Vector2.ONE * lerpf(0.25, 0.8, t)
		marker.modulate.a = 0.4 + 0.5 * t
		falling.position = landing + Vector2(0, -128.0 * (1.0 - t * t))
		falling.scale = Vector2.ONE * lerpf(1.4, 0.85, t)

		if t >= 1.0:
			_land(holder, landing, bool(holder.get_meta(&"acorn")))


func _land(holder: Node2D, landing: Vector2, is_acorn: bool) -> void:
	var caught := _player.position.distance_to(landing) < 16.0
	if is_acorn:
		if caught and _stun <= 0.0:
			_take_hit()
		else:
			Audio.sfx(&"step", randf_range(0.7, 0.9))
	elif caught:
		_catch(landing)
	else:
		# A missed fruit does not break the combo -- only being hit does. The
		# player should be chasing fruit, not punished for one that fell wide.
		Audio.sfx(&"tick", 0.6)
	holder.queue_free()


func _catch(at: Vector2) -> void:
	_fruit += 1
	_combo += 1
	_best_combo = maxi(_best_combo, _combo)
	var multiplier := combo_multiplier()
	_score += SCORE_FRUIT * multiplier
	_hud.set_score(_score)
	Audio.sfx(&"pickup", 1.0 + 0.08 * multiplier)
	_hud.set_multiplier(multiplier)
	pop(at, SCORE_FRUIT * multiplier, multiplier)
	_flash(at, Color(1, 0.9, 0.5))


func _take_hit() -> void:
	_hits += 1
	_combo = 0
	_score = maxi(_score + SCORE_HIT, 0)
	_stun = STUN_SECONDS
	_player.freeze()
	_hud.set_score(_score)
	_hud.set_multiplier(1)
	Audio.sfx(&"deny", 0.8)
	Juice.shake(self, 3.5)
	pop_on_player(SCORE_HIT, "BONK")


func combo_multiplier() -> int:
	return clampi(1 + _combo / COMBO_PER_LEVEL, 1, COMBO_MAX)


func _flash(at: Vector2, colour: Color) -> void:
	var flash := Sprite2D.new()
	flash.texture = _impact_texture
	flash.position = at
	flash.modulate = colour
	flash.z_index = 13
	_falling_root.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "scale", Vector2(1.6, 1.6), 0.22)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.22)
	tween.tween_callback(flash.queue_free)


func _finish() -> void:
	_player.freeze()
	Audio.sfx(&"complete")
	finish(_score, {"fruit": _fruit, "hits": _hits, "combo": _best_combo})
