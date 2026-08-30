class_name Cutscene
extends CanvasLayer
## Plays a list of shots from src/data/lore.gd.
##
## One player, seventeen cutscenes. A shot is a sky, a caption and some sprites
## told where to go; this file knows how to move them and nothing about what the
## story is, which is what keeps the lore editable without opening a scene.
##
## Letterboxed on purpose: the bars are the fastest way to tell a player "this
## is not the part where you press things". Skippable after a second, because a
## repeat player on an arcade cabinet has seen it and should never be held.

signal done

const BAR_HEIGHT := 26.0
## How long before a button press is allowed to skip. A press in the first
## moment is almost always the tail of the one that started the game, and
## swallowing the story because of it would be a bad trade.
const SKIP_AFTER := 1.0
const SKY_BLEND := 0.55
const FADE_IN := 0.28
const FADE_OUT := 0.26
const ACTOR_FADE := 0.3

@onready var _root: Control = $Root
@onready var _sky: TextureRect = $Root/Sky
@onready var _stage: Node2D = $Root/Stage
@onready var _bar_top: ColorRect = $Root/BarTop
@onready var _bar_bottom: ColorRect = $Root/BarBottom
@onready var _caption: Label = $Root/Caption
@onready var _skip: Label = $Root/Skip

var _gradient: Gradient
var _skipped: bool = false
var _clock: float = 0.0
## Sprites with a life of their own -- swaying, spinning -- which a tween cannot
## express because it would fight the position tween for the same property.
var _live: Array[Dictionary] = []


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS

	_gradient = Gradient.new()
	_gradient.set_color(0, Color(0.06, 0.07, 0.17))
	_gradient.set_color(1, Color(0.13, 0.15, 0.28))
	var texture := GradientTexture2D.new()
	texture.gradient = _gradient
	# 270 tall so one gradient step lands on one screen pixel: at nearest-filter
	# anything coarser bands visibly across a sky this large.
	texture.width = 2
	texture.height = 270
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	_sky.texture = texture

	_root.modulate.a = 0.0
	_caption.text = ""
	_skip.modulate.a = 0.0
	_bar_top.offset_bottom = 0.0
	_bar_bottom.offset_top = 0.0


func _process(delta: float) -> void:
	_clock += delta
	if _clock > SKIP_AFTER and _skip.modulate.a < 1.0 and not _skipped:
		_skip.modulate.a = minf(1.0, _skip.modulate.a + delta * 2.0)

	for entry in _live:
		var sprite: Sprite2D = entry["sprite"]
		if not is_instance_valid(sprite):
			continue
		entry["phase"] = float(entry["phase"]) + delta
		var phase: float = entry["phase"]
		var sway: float = entry["sway"]
		if sway != 0.0:
			sprite.position.x = sin(phase * 3.1) * sway
			sprite.position.y = sin(phase * 1.7) * sway * 0.4
		var spin: float = entry["spin"]
		if spin != 0.0:
			sprite.rotation += spin * delta


## Plays the whole sequence and returns once it is off the screen.
func play(shots: Array) -> void:
	if shots.is_empty():
		done.emit()
		queue_free()
		return

	var first: Dictionary = shots[0]
	_apply_sky(first.get("sky", [Color.BLACK, Color.BLACK]))

	var opening := create_tween()
	opening.set_parallel(true)
	opening.tween_property(_root, "modulate:a", 1.0, FADE_IN)
	opening.tween_property(_bar_top, "offset_bottom", BAR_HEIGHT, 0.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	opening.tween_property(_bar_bottom, "offset_top", -BAR_HEIGHT, 0.3) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for shot: Dictionary in shots:
		if _skipped:
			break
		await _play_shot(shot)

	await _close()


func _unhandled_input(event: InputEvent) -> void:
	if _skipped or _clock < SKIP_AFTER:
		return
	if event.is_action_pressed(&"act") or event.is_action_pressed(&"start") \
			or event.is_action_pressed(&"back"):
		_skipped = true
		get_viewport().set_input_as_handled()


func _play_shot(shot: Dictionary) -> void:
	var seconds: float = shot.get("seconds", 1.6)

	# The sky carries over between shots rather than cutting, so a cutscene
	# reads as one continuous dawn instead of three unrelated pictures.
	_blend_sky(shot.get("sky", []), minf(SKY_BLEND, seconds))

	for child in _stage.get_children():
		child.queue_free()
	_live.clear()

	for actor: Dictionary in shot.get("actors", []):
		_spawn(actor, seconds)

	_set_caption(String(shot.get("caption", "")))

	var cue: StringName = shot.get("sfx", &"")
	if cue != &"":
		Audio.sfx(cue, float(shot.get("sfx_pitch", 1.0)))

	await _hold(seconds)


func _set_caption(text: String) -> void:
	if _caption.text == text:
		return
	_caption.text = text
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.25)


func _apply_sky(sky: Array) -> void:
	if sky.size() < 2:
		return
	_gradient.set_color(0, sky[0])
	_gradient.set_color(1, sky[1])


func _blend_sky(sky: Array, seconds: float) -> void:
	if sky.size() < 2:
		return
	var from_top := _gradient.get_color(0)
	var from_bottom := _gradient.get_color(1)
	var to_top: Color = sky[0]
	var to_bottom: Color = sky[1]
	create_tween().tween_method(
		func(t: float) -> void:
			_gradient.set_color(0, from_top.lerp(to_top, t))
			_gradient.set_color(1, from_bottom.lerp(to_bottom, t)),
		0.0, 1.0, maxf(seconds, 0.05))


func _spawn(actor: Dictionary, seconds: float) -> void:
	var path: String = actor.get("tex", "")
	var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if texture == null:
		# Loud, because a missing path here is a hole in the story that only
		# shows up when that one cutscene plays in front of somebody.
		push_error("Cutscene: missing texture %s" % path)
		return
	var repeat: int = maxi(1, int(actor.get("repeat", 1)))
	var step: Vector2 = actor.get("step", Vector2.ZERO)
	for i in repeat:
		_spawn_one(actor, texture, step * float(i), seconds)


func _spawn_one(actor: Dictionary, texture: Texture2D, offset: Vector2,
		seconds: float) -> void:
	var at: Vector2 = actor.get("at", Vector2(240, 135)) + offset
	var to: Vector2 = actor.get("to", actor.get("at", Vector2(240, 135))) + offset
	var tint: Color = actor.get("tint", Color.WHITE)
	var start_scale: float = float(actor.get("scale", 1.0))
	var end_scale: float = float(actor.get("to_scale", start_scale))
	var delay: float = float(actor.get("delay", 0.0))
	var fade: String = String(actor.get("fade", "in"))

	# Two nodes, because the sprite's own sway and the shot's movement both want
	# to write `position`. The holder travels; the sprite wobbles inside it.
	var holder := Node2D.new()
	holder.position = at
	_stage.add_child(holder)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = Vector2.ONE * start_scale
	sprite.rotation = float(actor.get("rotation", 0.0))
	sprite.modulate = tint
	sprite.modulate.a = 0.0 if fade != "none" else tint.a
	holder.add_child(sprite)

	var sway: float = float(actor.get("sway", 0.0))
	var spin: float = float(actor.get("spin", 0.0))
	if sway != 0.0 or spin != 0.0:
		_live.append({"sprite": sprite, "sway": sway, "spin": spin, "phase": 0.0})

	var travel := maxf(0.1, (seconds - delay) * 0.95)
	var tween := create_tween()
	tween.set_parallel(true)

	if fade == "in":
		tween.tween_property(sprite, "modulate:a", tint.a, ACTOR_FADE).set_delay(delay)
	elif fade == "out":
		tween.tween_property(sprite, "modulate:a", tint.a, ACTOR_FADE * 0.6) \
				.set_delay(delay)
		tween.tween_property(sprite, "modulate:a", 0.0, travel * 0.6) \
				.set_delay(delay + travel * 0.4)

	if to != at:
		tween.tween_property(holder, "position", to, travel).set_delay(delay) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not is_equal_approx(end_scale, start_scale):
		tween.tween_property(sprite, "scale", Vector2.ONE * end_scale, travel) \
				.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _close() -> void:
	var out := create_tween()
	out.set_parallel(true)
	out.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	out.tween_property(_bar_top, "offset_bottom", 0.0, FADE_OUT)
	out.tween_property(_bar_bottom, "offset_top", 0.0, FADE_OUT)
	await out.finished
	_skipped = true
	done.emit()
	queue_free()


## Waits out a shot, but gives up the moment the player skips.
func _hold(seconds: float) -> void:
	var clock := 0.0
	while clock < seconds and not _skipped:
		await get_tree().process_frame
		clock += get_process_delta_time()
