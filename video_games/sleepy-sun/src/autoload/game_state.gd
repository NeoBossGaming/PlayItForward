extends Node
## Run state for one credit: which minigames are done, what they scored.
##
## One credit buys the whole Sleepy Sun adventure. There is no fail state --
## mistakes cost score and seconds, never the run. See docs/GAME_DESIGN.md #2.

## Where a QRIS payment gate will sit in Phase 2. Left false so the cabinet is
## free to play during development; attract.gd has the matching seam.
const REQUIRE_CREDIT := false

## Seconds without any input before the cabinet gives up and returns to attract.
const IDLE_TIMEOUT := 45.0

const MINIGAMES: Array[Dictionary] = [
	{
		"id": &"wind_leaf",
		"title": "Riverleap",
		"blurb": "Hop between drifting leaves. Shaking ones are about to sink.",
		"scene": "res://src/minigames/wind_leaf/wind_leaf.tscn",
		"color": Color(0.42, 0.72, 0.45),
	},
	{
		"id": &"tall_grass",
		"title": "Hush Meadow",
		"blurb": "Gather sunpetals. Stay in the tall grass, out of sight of the birds.",
		"scene": "res://src/minigames/tall_grass/tall_grass.tscn",
		"color": Color(0.55, 0.78, 0.36),
	},
	{
		"id": &"cave",
		"title": "Echo Hollow",
		"blurb": "Watch the stones light up, then walk the same path back.",
		"scene": "res://src/minigames/cave/cave.tscn",
		"color": Color(0.66, 0.45, 0.82),
	},
	{
		"id": &"fishing",
		"title": "Still Water",
		"blurb": "Strike when a fish nudges the float. Bottles cost you.",
		"scene": "res://src/minigames/fishing/fishing.tscn",
		"color": Color(0.36, 0.64, 0.84),
	},
]

signal run_started
signal minigame_recorded(result: MiniGameResult)
signal run_finished(total: int)

var results: Dictionary = {}          ## StringName -> MiniGameResult
var run_active: bool = false
var run_started_at: float = 0.0

var _last_input_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_input_msec = Time.get_ticks_msec()


func _input(_event: InputEvent) -> void:
	_last_input_msec = Time.get_ticks_msec()


## Seconds since the player last touched any control.
func idle_seconds() -> float:
	return (Time.get_ticks_msec() - _last_input_msec) / 1000.0


func poke() -> void:
	_last_input_msec = Time.get_ticks_msec()


func start_run() -> void:
	results.clear()
	run_active = true
	run_started_at = Time.get_ticks_msec() / 1000.0
	poke()
	run_started.emit()


## Records a finished chore. A chore can be replayed from the hub, and the
## better attempt is the one kept -- replaying to chase a score should never be
## able to cost you the run you already had.
func record(result: MiniGameResult) -> void:
	var previous: MiniGameResult = results.get(result.id)
	if previous == null or result.score >= previous.score:
		results[result.id] = result
	minigame_recorded.emit(result)


func end_run() -> void:
	run_active = false
	run_finished.emit(total_score())


func has_played(id: StringName) -> bool:
	return results.has(id)


func score_for(id: StringName) -> int:
	var result: MiniGameResult = results.get(id)
	return result.score if result != null else 0


func total_score() -> int:
	var total := 0
	for result: MiniGameResult in results.values():
		total += result.score
	return total


func completed_count() -> int:
	return results.size()


func all_complete() -> bool:
	return results.size() >= MINIGAMES.size()


## Bottles pulled out of the river across the run. Flavour for the results
## screen -- it ties the fishing minigame to what the cabinet is actually for.
func plastic_removed() -> int:
	var result: MiniGameResult = results.get(&"fishing")
	return int(result.stats.get("plastic", 0)) if result != null else 0


func run_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0 - run_started_at


static func definition(id: StringName) -> Dictionary:
	for entry in MINIGAMES:
		if entry["id"] == id:
			return entry
	return {}
