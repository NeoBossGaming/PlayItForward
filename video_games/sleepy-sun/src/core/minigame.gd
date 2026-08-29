class_name MiniGame
extends Node2D
## Base class every minigame extends. The whole contract is three things:
##
##   1. Router calls begin() once the fade-in has finished.
##   2. The minigame plays out however it likes.
##   3. It calls finish(), which emits `finished` and hands control back.
##
## Nothing in a minigame ever changes scenes or touches Game directly, so each
## one can be run standalone in the editor (F6) or from tests/smoke_test.gd.

signal finished(result: MiniGameResult)

## Identifier matching an entry in Game.MINIGAMES.
@export var id: StringName = &""
## Score a competent player should land near. Drives the rank on the results screen.
@export var par_score: int = 1000

var elapsed: float = 0.0
var running: bool = false

var _finished: bool = false


func _process(delta: float) -> void:
	if running:
		elapsed += delta


## Called by Router after the screen has faded in. Override this, not _ready().
func begin() -> void:
	running = true


## Ends the minigame exactly once. Later calls are ignored, so a race between
## "timer ran out" and "player reached the goal" cannot double-report a score.
func finish(score: int, stats: Dictionary = {}) -> void:
	if _finished:
		return
	_finished = true
	running = false
	set_process_input(false)
	set_process_unhandled_input(false)
	finished.emit(MiniGameResult.new(id, score, elapsed, stats))


func is_finished() -> bool:
	return _finished
