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

## How many minigames one credit deals. Drawn from a pool of eight, so the same
## three almost never come up twice -- that unpredictability is the point of the
## card draw and the reason the pool is worth keeping deep.
const PLAYLIST_SIZE := 3

## `blurb` is the rule line the intro card teaches the game with. `gift` is what
## that game brings back to the sleeping sun -- lore, used by the cutscenes and
## by the results screen, and deliberately kept separate so neither can crowd
## the other out. See docs/GAME_DESIGN.md #10.
const MINIGAMES: Array[Dictionary] = [
	{
		"id": &"wind_leaf",
		"title": "Riverleap",
		"blurb": "Hop between drifting leaves. Shaking ones are about to sink.",
		"gift": "the river chimes",
		"scene": "res://src/minigames/wind_leaf/wind_leaf.tscn",
		"color": Color(0.42, 0.72, 0.45),
	},
	{
		"id": &"tall_grass",
		"title": "Hush Meadow",
		"blurb": "Gather sunpetals before dusk. Stay out of the birds' sight.",
		"gift": "a handful of yesterday",
		"scene": "res://src/minigames/tall_grass/tall_grass.tscn",
		"color": Color(0.55, 0.78, 0.36),
	},
	{
		"id": &"cave",
		"title": "Echo Hollow",
		"blurb": "Watch the stones light up, then walk the same path back.",
		"gift": "the sun's own name",
		"scene": "res://src/minigames/cave/cave.tscn",
		"color": Color(0.66, 0.45, 0.82),
	},
	{
		"id": &"harpoon",
		"title": "Riverstrike",
		"blurb": "Line up and fire. Lead the fish, spear the line, dodge the bottles.",
		"gift": "a river clear enough to look in",
		"scene": "res://src/minigames/harpoon/harpoon.tscn",
		"color": Color(0.36, 0.64, 0.84),
	},
	{
		"id": &"acorn_storm",
		"title": "Acorn Storm",
		"blurb": "Dodge the falling acorns. Catch the sunfruit between them.",
		"gift": "breakfast",
		"scene": "res://src/minigames/acorn_storm/acorn_storm.tscn",
		"color": Color(0.86, 0.56, 0.30),
	},
	{
		"id": &"firefly",
		"title": "Firefly Lantern",
		"blurb": "Your light is dying. The darker it gets, the more they are worth.",
		"gift": "a borrowed light",
		"scene": "res://src/minigames/firefly/firefly.tscn",
		"color": Color(0.95, 0.85, 0.42),
	},
	{
		"id": &"temple_bell",
		"title": "Temple Bell",
		"blurb": "Strike on the beat. It only gets faster.",
		"gift": "the dawn bell",
		"scene": "res://src/minigames/temple_bell/temple_bell.tscn",
		"color": Color(0.90, 0.42, 0.44),
	},
	{
		"id": &"crow_watch",
		"title": "Crow Watch",
		"blurb": "Crows are diving on the rice. Scare them off before they land.",
		"gift": "the harvest offering",
		"scene": "res://src/minigames/crow_watch/crow_watch.tscn",
		"color": Color(0.52, 0.56, 0.72),
	},
]

signal run_started
signal minigame_recorded(result: MiniGameResult)
signal run_finished(total: int)

var results: Dictionary = {}          ## StringName -> MiniGameResult
var run_active: bool = false
var run_started_at: float = 0.0

## The three minigames dealt for this credit, in the order they will be played.
var playlist: Array[StringName] = []
var playlist_index: int = 0
## Set by the debug menu to pin the next draw. Empty in a normal session, and
## never set at all in a release build -- the debug menu is inert there.
var forced_hand: Array[StringName] = []

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
	playlist.clear()
	playlist_index = 0
	run_active = true
	run_started_at = Time.get_ticks_msec() / 1000.0
	poke()
	run_started.emit()


## Deals the session. Sampling without replacement, so a draw can never show the
## same game on two cards.
func draw_playlist(count: int = PLAYLIST_SIZE) -> Array[StringName]:
	if not forced_hand.is_empty():
		playlist = forced_hand.duplicate()
		playlist_index = 0
		return playlist

	var pool: Array[StringName] = []
	for entry in MINIGAMES:
		pool.append(entry["id"])
	pool.shuffle()
	playlist = pool.slice(0, mini(count, pool.size()))
	playlist_index = 0
	return playlist


func current_id() -> StringName:
	if playlist_index < 0 or playlist_index >= playlist.size():
		return &""
	return playlist[playlist_index]


func advance() -> void:
	playlist_index += 1


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


## Sum of par for the games actually dealt. The results rank compares against
## this, not against the whole pool -- otherwise every run would rank GENTLE.
func playlist_par() -> int:
	var total := 0
	for id in playlist:
		total += par_for(id)
	return total


## Par lives on the minigame scene itself, so it stays next to the design it
## describes rather than in a table that drifts out of date.
static func par_for(id: StringName) -> int:
	var entry := definition(id)
	if entry.is_empty():
		return 1000
	var packed: PackedScene = load(entry["scene"])
	if packed == null:
		return 1000
	var state := packed.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"par_score":
			return int(state.get_node_property_value(0, i))
	return 1000


## True once every dealt card has been played -- not every game in the pool.
func all_complete() -> bool:
	return not playlist.is_empty() and playlist_index >= playlist.size()


## Bottles pulled out of the river across the run. Flavour for the results
## screen -- it ties Riverstrike to what the cabinet is actually for.
func plastic_removed() -> int:
	var result: MiniGameResult = results.get(&"harpoon")
	return int(result.stats.get("plastic", 0)) if result != null else 0


func run_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0 - run_started_at


static func definition(id: StringName) -> Dictionary:
	for entry in MINIGAMES:
		if entry["id"] == id:
			return entry
	return {}
