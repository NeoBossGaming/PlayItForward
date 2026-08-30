extends Node
## Scene changes with a fade, and the one place minigame results are collected.
##
## Minigames never change scenes themselves: they emit `finished` and Router
## decides what happens next. That keeps every minigame runnable standalone.

const ATTRACT := "res://src/shell/attract/attract.tscn"
const DRAW := "res://src/shell/draw/draw.tscn"
const RESULTS := "res://src/shell/results/results.tscn"

const FADE_TIME := 0.35

## A score at or above this fraction of par gets the confident telling of what
## just happened rather than the gentle one. Slightly under par still counts:
## the split is between "that went well" and "that went quietly", never between
## passing and failing.
const MET_PAR := 0.9

signal scene_ready(scene: Node)

var _fade: ColorRect
var _busy: bool = false
var _pending: String = ""
var _draw_deals: bool = false
var _cutscene_scene: PackedScene = preload("res://src/ui/cutscene.tscn")


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

	# Hand control over only once the screen is actually visible. enter() plays
	# the intro card first and calls begin() when it is done.
	if scene is MiniGame:
		(scene as MiniGame).enter()

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
	# A beat on the finished game's own screen before anything else happens, so
	# the last thing that happened is still readable when the score lands.
	await Wait.on(self, 1.4)

	var met_par := result.score >= int(Game.par_for(result.id) * MET_PAR)
	await play_cutscene(Lore.after(result.id, met_par))

	if Game.all_complete():
		await play_cutscene(Lore.finale(run_tier(), Game.playlist.duplicate()))
		await go_to_results()
	else:
		await go_to_draw(false)


## How the run went, as an index into Lore.TIERS. The results screen reads the
## same number for its rank stamp, so the sun the player sees and the word they
## are given can never disagree.
func run_tier() -> int:
	var par := maxf(float(Game.playlist_par()), 1.0)
	return Lore.tier_for(float(Game.total_score()) / par)


## Plays a cutscene over whatever is currently on screen and returns when it is
## gone. It hangs off Router rather than off the scene so it survives the scene
## being freed underneath it, and sits below the fade layer so a transition
## started mid-cutscene still covers it.
func play_cutscene(shots: Array) -> void:
	if shots.is_empty():
		return
	var scene: Cutscene = _cutscene_scene.instantiate()
	add_child(scene)
	scene.play(shots)
	await scene.done


func _fade_to(alpha: float) -> void:
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, FADE_TIME)
	await tween.finished
	_fade.visible = alpha > 0.01
