class_name MiniGame
extends Node2D
## Base class every minigame extends. The whole contract is three things:
##
##   1. Something calls begin().
##   2. The minigame plays out however it likes.
##   3. It calls finish(), which emits `finished` and hands control back.
##
## The cabinet shell that used to do step 1 -- the card draw, the lore cutscene,
## the intro card -- is parked while one game at a time gets finished properly,
## so for now the game starts itself. The contract is unchanged, which is the
## point of having one: the shell can be put back in front of it without the
## game knowing.

signal finished(result: MiniGameResult)

## ln 2, spelled out because GDScript has no LN2 and a missing constant in a
## static function takes the whole class down with it -- MiniGame failed to
## register and every game in the project stopped parsing.
const LN_2 := 0.6931471805599453

## Short identifier for this game. Used by saves and test output.
@export var id: StringName = &""
## Score a competent player should land near.
@export var par_score: int = 1000

var elapsed: float = 0.0
var running: bool = false

var _finished: bool = false
var _popup_scene: PackedScene = preload("res://src/ui/score_popup.tscn")
var _popup_root: Node2D


func _process(delta: float) -> void:
	if running:
		elapsed += delta


## Where a game actually starts. Override this, not _ready(), so that setup and
## the first frame of play stay separable.
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
	finished.emit(MiniGameResult.new(id, score, elapsed, stats,
			normalised_score(score)))


## This run as 0-1000, for a table shared across games that score on wildly
## different scales. Override it: the default assumes par_score is a decent
## run, which is true of a fixed-length game and useless for an endless one.
func normalised_score(raw: int) -> int:
	if par_score <= 0:
		return 0
	return clampi(int(500.0 * float(raw) / float(par_score)), 0, 1000)


## What an ENDLESS game should normalise on instead: how long you lasted.
## Their raw scores are unbounded and accelerate, so two of them compared on
## points would be comparing their scoring rates rather than their players.
##
## Par scores 500 and it saturates without ever reaching 1000 -- twice par is
## 750, four times is 937 -- which is the same "approach but never arrive"
## shape the difficulty curves use, and for the same reason: there has to be
## something left to chase.
static func normalised_from_duration(seconds: float, par_seconds: float) -> int:
	if par_seconds <= 0.0:
		return 0
	return clampi(int(1000.0 * (1.0 - exp(-LN_2 * maxf(seconds, 0.0) / par_seconds))),
			0, 1000)


## The shape every game's difficulty takes: gentle and linear up to a ceiling,
## then exponential toward 1 without ever arriving.
##
## Riverleap arrived at this after two rounds of tuning and it is not specific
## to a river -- the first minute has to be survivable by somebody who has not
## worked out the controls, and after that there has to be no ceiling. Each
## game passes its own three numbers; the shape is shared so that stretching
## one game's curve is a change to three constants rather than a redesign.
static func curve(seconds: float, gentle_seconds: float, gentle_ceiling: float,
		steep_tau: float) -> float:
	var gentle := gentle_ceiling * clampf(seconds / maxf(gentle_seconds, 0.001), 0.0, 1.0)
	var steep := (1.0 - gentle_ceiling) \
			* (1.0 - exp(-maxf(seconds - gentle_seconds, 0.0) / maxf(steep_tau, 0.001)))
	return gentle + steep


func is_finished() -> bool:
	return _finished
