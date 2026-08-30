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
var _popup_scene: PackedScene = preload("res://src/ui/score_popup.tscn")
var _intro_scene: PackedScene = preload("res://src/ui/intro_card.tscn")
var _popup_root: Node2D


func _process(delta: float) -> void:
	if running:
		elapsed += delta


## Router's entry point. Shows the intro card, then starts the game -- so every
## minigame gets an intro for free and none of them has to know it exists.
## Tests call begin() directly and skip straight to play.
func enter() -> void:
	var card: IntroCard = _intro_scene.instantiate()
	add_child(card)
	card.play(id, control_hint())
	await card.dismissed
	if is_inside_tree() and not _finished:
		begin()


## What the controls do in *this* game, shown on the intro card. Overridden by
## the games whose button does something other than nothing.
func control_hint() -> String:
	return "STICK  move"


## Called once the intro is gone. Override this, not _ready().
func begin() -> void:
	running = true


# --- score feedback ----------------------------------------------------------
#
# Every minigame reports scoring the same way, and it always appears where the
# thing that caused it happened. Gains rise off the object; penalties pop on the
# player, shaking rather than drifting, so a loss can never be mistaken for a win.

## A gain, at the object that produced it.
func pop(at: Vector2, amount: int, multiplier: int = 1, caption: String = "") -> void:
	_spawn_popup(at, amount, multiplier, false, caption)


## A loss, on the player -- they are who it happened to.
func pop_on_player(amount: int, caption: String = "") -> void:
	var player := _find_player()
	var at := player.position if player != null else Vector2(240, 135)
	_spawn_popup(at + Vector2(0, -26), amount, 1, true, caption)


func _spawn_popup(at: Vector2, amount: int, multiplier: int, penalty: bool,
		caption: String) -> void:
	if _popup_root == null or not is_instance_valid(_popup_root):
		_popup_root = Node2D.new()
		_popup_root.name = "Popups"
		_popup_root.z_index = 60
		add_child(_popup_root)
	var popup: ScorePopup = _popup_scene.instantiate()
	popup.amount = amount
	popup.multiplier = multiplier
	popup.is_penalty = penalty
	popup.caption = caption
	popup.position = at
	_popup_root.add_child(popup)


func _find_player() -> Node2D:
	var node := get_node_or_null(^"Player")
	return node as Node2D


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
