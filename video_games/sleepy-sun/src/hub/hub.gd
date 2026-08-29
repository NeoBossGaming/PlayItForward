extends Node2D
## Sunset Village: the minigame selection screen.
##
## Deliberately a place you walk around rather than a menu you scroll. It costs
## a few seconds per selection but it is what makes four separate minigames feel
## like one adventure, and it gives the mascot somewhere to visibly wake up as
## chores get done.
##
## Chores can be done in any order. Finishing all four lights the sun; walking
## up to it ends the run.

const WORLD_RECT := Rect2(24, 100, 592, 240)

@onready var _player: TopDownPlayer = $Player
@onready var _sun: Sprite2D = $World/Sun
@onready var _sun_glow: Sprite2D = $World/SunGlow
@onready var _sun_area: Area2D = $World/SunArea
@onready var _hud: HUD = $HUD
@onready var _stars: Node2D = $UI/Stars

var _portals: Array[HubPortal] = []
var _leaving: bool = false
var _bob: float = 0.0


func _ready() -> void:
	for child in $Portals.get_children():
		if child is HubPortal:
			_portals.append(child)

	_hud.set_title("Sunset Village")
	_hud.reset_score(Game.total_score())
	_refresh()

	# Coming back from a chore, stand at that chore's signpost rather than
	# teleporting to the village entrance -- the walk back reads as continuous.
	var last := _last_played_portal()
	if last != null:
		_player.position = last.position + Vector2(0, 34)
		_celebrate(last)


func _process(delta: float) -> void:
	_bob += delta
	_sun.position.y = 74.0 + sin(_bob * 1.6) * 3.0
	_sun_glow.position = _sun.position
	_sun_glow.rotation += delta * 0.25

	_player.position = _player.position.clamp(WORLD_RECT.position, WORLD_RECT.end)
	_update_prompt()

	if Game.idle_seconds() > Game.IDLE_TIMEOUT and not _leaving:
		_leaving = true
		Router.go_to_attract()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or not event.is_action_pressed(&"act"):
		return
	for portal in _portals:
		if portal.is_player_inside() and not Game.has_played(portal.minigame_id):
			_enter(portal.minigame_id)
			return
	# Replaying a finished chore is allowed -- the better score is the one kept.
	for portal in _portals:
		if portal.is_player_inside():
			_enter(portal.minigame_id)
			return
	if Game.all_complete() and _sun_area.overlaps_body(_player):
		_finish_run()


func _enter(id: StringName) -> void:
	_leaving = true
	_player.freeze()
	Audio.sfx(&"confirm")
	Router.play_minigame(id)


func _finish_run() -> void:
	_leaving = true
	_player.freeze()
	Audio.sfx(&"complete")
	Router.go_to_results()


func _update_prompt() -> void:
	if _leaving:
		return
	for portal in _portals:
		if portal.is_player_inside():
			var entry := Game.definition(portal.minigame_id)
			var verb := "PLAY AGAIN" if Game.has_played(portal.minigame_id) else "PLAY"
			_hud.prompt("%s  %s" % [verb, String(entry["title"]).to_upper()])
			return
	if Game.all_complete() and _sun_area.overlaps_body(_player):
		_hud.prompt("WAKE THE SUN  -  finish the adventure")
		return

	var left := Game.MINIGAMES.size() - Game.completed_count()
	if left > 0:
		_hud.set_objective("%d chore%s left before dusk" % [left, "" if left == 1 else "s"])
		_hud.clear_prompt()
	else:
		_hud.set_objective("The sun is ready. Go and wake it.")
		_hud.clear_prompt()


func _refresh() -> void:
	for portal in _portals:
		portal.refresh()

	# The mascot is the progress bar: it brightens and grows with every chore.
	var progress := float(Game.completed_count()) / float(Game.MINIGAMES.size())
	var frame := 2 - clampi(int(progress * 2.999), 0, 2)
	_sun.texture = load("res://assets/game/village/sun_%d.png" % frame)
	_sun.scale = Vector2.ONE * lerpf(1.5, 2.4, progress)
	_sun_glow.modulate.a = lerpf(0.10, 0.55, progress)
	_sun_glow.scale = Vector2.ONE * lerpf(2.0, 3.4, progress)

	for i in Game.MINIGAMES.size():
		var star := _stars.get_child(i) as Sprite2D
		var id: StringName = Game.MINIGAMES[i]["id"]
		star.texture = load("res://assets/game/ui/star_%s.png"
				% ("on" if Game.has_played(id) else "off"))


func _last_played_portal() -> HubPortal:
	# Game.results preserves insertion order, so the last key is the last played.
	if Game.results.is_empty():
		return null
	var last_id: StringName = Game.results.keys().back()
	for portal in _portals:
		if portal.minigame_id == last_id:
			return portal
	return null


func _celebrate(portal: HubPortal) -> void:
	var result: MiniGameResult = Game.results.get(portal.minigame_id)
	if result == null:
		return
	_hud.toast("+%d" % result.score, Color(1, 0.87, 0.5), 1.0)
	_hud.set_score(Game.total_score())

	var tween := create_tween()
	tween.tween_property(_sun_glow, "modulate:a", 0.9, 0.3)
	tween.tween_property(_sun_glow, "modulate:a", _sun_glow.modulate.a, 0.6)
