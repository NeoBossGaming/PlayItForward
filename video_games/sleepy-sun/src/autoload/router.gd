extends Node
## Scene changes with a fade, and the one place minigame results are collected.
##
## Minigames never change scenes themselves: they emit `finished` and Router
## decides what happens next. That keeps every minigame runnable standalone.

const ATTRACT := "res://src/shell/attract/attract.tscn"
const DRAW := "res://src/shell/draw/draw.tscn"
const RESULTS := "res://src/shell/results/results.tscn"

const FADE_TIME := 0.35

signal scene_ready(scene: Node)

var _fade: ColorRect
var _busy: bool = false
var _pending: String = ""
var _draw_deals: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)

	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.04, 0.08, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.visible = false
	layer.add_child(_fade)


## Queues rather than drops a request that arrives mid-transition. Dropping it
## meant a START pressed during the attract screen's fade-in vanished, and
## because the attract screen had already latched "starting" the cabinet then
## ignored every later press until it timed out. On a public machine the press
## that gets swallowed is usually somebody's first one.
func change_scene(path: String) -> void:
	if _busy:
		_pending = path
		return
	_busy = true
	await _fade_to(1.0)

	if get_tree().change_scene_to_file(path) != OK:
		push_error("Router: could not load scene %s" % path)
		_busy = false
		await _fade_to(0.0)
		_flush_pending()
		return

	# change_scene_to_file is deferred; current_scene is only valid after it runs.
	await get_tree().process_frame
	await get_tree().process_frame

	var scene := get_tree().current_scene
	if scene is MiniGame:
		var game := scene as MiniGame
		game.finished.connect(_on_minigame_finished.bind(game), CONNECT_ONE_SHOT)

	Game.poke()
	await _fade_to(0.0)
	_busy = false
	scene_ready.emit(scene)

	# Hand control over only once the screen is actually visible.
	if scene is MiniGame:
		(scene as MiniGame).begin()

	_flush_pending()


func _flush_pending() -> void:
	if _pending == "":
		return
	var next := _pending
	_pending = ""
	change_scene(next)


## True while a transition is running. Screens use it to avoid acting twice on
## one press; it is never a reason to discard input.
func is_busy() -> bool:
	return _busy


func play_minigame(id: StringName) -> void:
	var entry := Game.definition(id)
	if entry.is_empty():
		push_error("Router: unknown minigame %s" % id)
		return
	await change_scene(entry["scene"])


## Plays whatever card the session is currently on.
func play_current() -> void:
	await play_minigame(Game.current_id())


## Opens the card table. `deal` shuffles a fresh hand; otherwise the cards are
## already dealt and this is the between-games beat that shows the running score
## and flips up whatever is next.
func go_to_draw(deal: bool = false) -> void:
	_draw_deals = deal
	await change_scene(DRAW)


## True when the draw scene should shuffle rather than advance. Read by draw.gd
## on ready, because scene arguments cannot be passed through change_scene.
func draw_should_deal() -> bool:
	return _draw_deals


func go_to_attract() -> void:
	Game.run_active = false
	await change_scene(ATTRACT)


func go_to_results() -> void:
	Game.end_run()
	await change_scene(RESULTS)


func _on_minigame_finished(result: MiniGameResult, _game: MiniGame) -> void:
	Game.record(result)
	Game.advance()
	Audio.sfx(&"complete")
	# A beat on the finished game's own screen before the scene changes, so the
	# last thing that happened is still readable when the score lands.
	await Wait.on(self, 1.4)
	if Game.all_complete():
		await go_to_results()
	else:
		await go_to_draw(false)


func _fade_to(alpha: float) -> void:
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished
	_fade.visible = alpha > 0.01
