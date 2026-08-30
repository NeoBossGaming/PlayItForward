extends MiniGame
## Crow Watch -- crows dive on the rice; get there before they land.
##
## The one game in the pool whose score goes **down** if you do nothing. The
## crop tally is both the objective and the clock, so a player can watch
## themselves losing in real time, and "I nearly saved that one" is a far
## stronger pull to play again than a number that only ever climbs.
##
## Every dive is telegraphed by a shadow growing on the target tile, same
## grammar as Acorn Storm and Riverleap.
##
## No fail state: crops run out at worst, and the round still pays what you saved.

const ROUND_SECONDS := 60.0
const FIELD := Rect2(42, 81, 396, 162)

const CROP_COLUMNS := 5
const CROP_ROWS := 3
const CROP_HEALTH := 2            ## bites before a tile is stripped bare

const DIVE_SECONDS := Vector2(2.4, 1.5)   ## warning time, eased across the round
const DIVE_INTERVAL := Vector2(2.0, 0.9)
const SCARE_RADIUS := 24.0
const EAT_SECONDS := 1.1

const SCORE_SCARE := 50
const SCORE_CROP_SAVED := 70
const CHAIN_PER_LEVEL := 3
const CHAIN_MAX := 5

@onready var _player: TopDownPlayer = $Player
@onready var _hud: HUD = $HUD
@onready var _crops_root: Node2D = $Crops
@onready var _crows_root: Node2D = $Crows

var _crops: Array[Sprite2D] = []
var _time_left: float = ROUND_SECONDS
var _dive_timer: float = 0.8

var _score: int = 0
var _scares: int = 0
var _chain: int = 0
var _best_chain: int = 0

var _crop_textures: Array[Texture2D] = []
var _crow_textures: Array[Texture2D] = []
var _shadow_texture := preload("res://assets/game/ui/shadow_small.png")


func _ready() -> void:
	for i in 3:
		_crop_textures.append(load("res://assets/game/crow_watch/rice_%d.png" % i))
	for i in 2:
		_crow_textures.append(load("res://assets/game/tall_grass/bird_%d.png" % i))

	_build_field()
	_player.can_sprint = true
	_player.stamina_changed.connect(_hud.set_stamina)
	# stamina_changed only fires when the meter moves, so the bar would be
	# invisible until the first sprint without this.
	_hud.set_stamina(1.0, false)
	_player.speed = 80.0
	_player.position = FIELD.get_center()
	_player.freeze()

	_hud.reset_score(0)


func control_hint() -> String:
	return "STICK  move      BUTTON  sprint"


func begin() -> void:
	super.begin()
	_player.unfreeze()
	_hud.toast("SHOO!", Color(1, 0.85, 0.5), 0.7)
	_update_meter()


func _process(delta: float) -> void:
	super._process(delta)
	if not running:
		return

	_time_left = maxf(_time_left - delta, 0.0)
	if _time_left <= 0.0:
		_finish()
		return

	_player.position = _player.position.clamp(FIELD.position, FIELD.end)
	_tick_dives(delta)
	_tick_crows(delta)


func _build_field() -> void:
	for row in CROP_ROWS:
		for column in CROP_COLUMNS:
			var crop := Sprite2D.new()
			crop.texture = _crop_textures[0]
			crop.position = Vector2(
				FIELD.position.x + 33.0 + column * (FIELD.size.x - 66.0) / (CROP_COLUMNS - 1),
				FIELD.position.y + 23.0 + row * (FIELD.size.y - 46.0) / (CROP_ROWS - 1))
			crop.set_meta(&"health", CROP_HEALTH)
			crop.z_index = 2
			_crops_root.add_child(crop)
			_crops.append(crop)


func _pressure() -> float:
	return 1.0 - _time_left / ROUND_SECONDS


func _tick_dives(delta: float) -> void:
	_dive_timer -= delta
	if _dive_timer > 0.0:
		return
	_dive_timer = lerpf(DIVE_INTERVAL.x, DIVE_INTERVAL.y, _pressure()) \
			* randf_range(0.75, 1.25)
	_launch_dive()


func _launch_dive() -> void:
	var living := _living_crops()
	if living.is_empty():
		return
	var target: Sprite2D = living[randi() % living.size()]

	var crow := Sprite2D.new()
	crow.texture = _crow_textures[0]
	crow.position = target.position + Vector2(randf_range(-68.0, 68.0), -113.0)
	crow.z_index = 14
	crow.scale = Vector2(1.4, 1.4)

	var shadow := Sprite2D.new()
	shadow.texture = _shadow_texture
	shadow.position = target.position
	shadow.scale = Vector2(0.5, 0.5)
	shadow.modulate = Color(0.1, 0.08, 0.14, 0.4)
	shadow.z_index = 3

	var holder := Node2D.new()
	holder.set_meta(&"target", target)
	holder.set_meta(&"life", 0.0)
	holder.set_meta(&"eating", 0.0)
	holder.set_meta(&"landed", false)
	holder.set_meta(&"start", crow.position)
	holder.set_meta(&"warning", lerpf(DIVE_SECONDS.x, DIVE_SECONDS.y, _pressure()))
	holder.add_child(shadow)
	holder.add_child(crow)
	_crows_root.add_child(holder)
	Audio.sfx(&"shake", 1.6)


func _tick_crows(delta: float) -> void:
	for child in _crows_root.get_children():
		var holder := child as Node2D
		if holder == null or holder.get_child_count() < 2:
			continue
		# A crow that has already been scared is on its way out; leave it alone.
		if holder.get_meta(&"fleeing", false):
			continue
		var target := holder.get_meta(&"target") as Sprite2D
		if target == null or not is_instance_valid(target):
			holder.queue_free()
			continue

		var shadow := holder.get_child(0) as Sprite2D
		var crow := holder.get_child(1) as Sprite2D
		var landed: bool = holder.get_meta(&"landed")

		# Scaring works right up to the moment it flies off with a mouthful.
		if _player.position.distance_to(crow.position) < SCARE_RADIUS:
			_scare(holder, crow)
			continue

		if not landed:
			var life: float = float(holder.get_meta(&"life")) + delta
			holder.set_meta(&"life", life)
			var warning: float = holder.get_meta(&"warning")
			var t := clampf(life / warning, 0.0, 1.0)
			var start: Vector2 = holder.get_meta(&"start")
			crow.position = start.lerp(target.position, t)
			crow.texture = _crow_textures[int(life * 9.0) % 2]
			shadow.scale = Vector2.ONE * lerpf(0.5, 2.0, t)
			shadow.modulate.a = 0.35 + 0.45 * t
			if t >= 1.0:
				holder.set_meta(&"landed", true)
				Audio.sfx(&"deny", 1.2)
			continue

		var eating: float = float(holder.get_meta(&"eating")) + delta
		holder.set_meta(&"eating", eating)
		crow.position.y = target.position.y + sin(eating * 22.0) * 2.0
		if eating >= EAT_SECONDS:
			_bite(target)
			_chain = 0
			holder.queue_free()


func _scare(holder: Node2D, crow: Sprite2D) -> void:
	_scares += 1
	_chain += 1
	_best_chain = maxi(_best_chain, _chain)
	var multiplier := chain_multiplier()
	_score += SCORE_SCARE * multiplier
	_hud.set_score(_score)
	Audio.sfx(&"spotted", 1.4)
	_hud.set_multiplier(multiplier)
	pop(crow.position, SCORE_SCARE * multiplier, multiplier)

	# Flees the way it came, so a scare reads as a win rather than a vanish.
	# set_meta(key, null) deletes the key in Godot, so flag it instead.
	holder.set_meta(&"fleeing", true)
	var away := crow.position + (crow.position - _player.position).normalized() * 90.0
	away.y -= 90.0
	var tween := create_tween()
	tween.tween_property(crow, "position", away, 0.45).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(holder, "modulate:a", 0.0, 0.45)
	tween.tween_callback(holder.queue_free)


func _bite(crop: Sprite2D) -> void:
	var health := int(crop.get_meta(&"health")) - 1
	crop.set_meta(&"health", health)
	crop.texture = _crop_textures[clampi(CROP_HEALTH - health, 0, 2)]
	Audio.sfx(&"trash", 0.9)
	Juice.shake(self, 3.0)
	Juice.flash(self, Color(1, 0.4, 0.32, 0.28))
	_hud.set_multiplier(1)
	pop(crop.position, 0, 1, "EATEN")
	_update_meter()


func chain_multiplier() -> int:
	return clampi(1 + _chain / CHAIN_PER_LEVEL, 1, CHAIN_MAX)


func _living_crops() -> Array[Sprite2D]:
	var alive: Array[Sprite2D] = []
	for crop in _crops:
		if int(crop.get_meta(&"health")) > 0:
			alive.append(crop)
	return alive


func _crop_health_total() -> int:
	var total := 0
	for crop in _crops:
		total += maxi(int(crop.get_meta(&"health")), 0)
	return total


func _update_meter() -> void:
	var total := _crop_health_total()
	var max_total := _crops.size() * CROP_HEALTH
	_hud.set_meter(float(total) / float(max_total), &"crop")


func _finish() -> void:
	_player.freeze()
	Audio.sfx(&"complete")
	var saved := _crop_health_total()
	var score := _score + saved * SCORE_CROP_SAVED
	_hud.set_score(score)
	_hud.toast("CROP SAVED  +%d" % (saved * SCORE_CROP_SAVED), Color(1, 0.9, 0.5), 1.2)
	finish(score, {"crop": saved, "scares": _scares, "chain": _best_chain})
