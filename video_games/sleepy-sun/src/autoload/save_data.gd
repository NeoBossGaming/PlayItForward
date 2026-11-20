extends Node
## Local high score table, kept in user:// so it survives a cabinet reboot.
##
## Deliberately local-only. A shared/online leaderboard is Phase 2+ work and is
## listed in docs/GAME_DESIGN.md under deferred work.
##
## **Keyed by game.** It was one flat table while there was one game, and when
## the second arrived both kept calling `submit(score)` and `best()` against
## it -- so Acorn Storm's results card was showing Riverleap's best, and the
## two games' scales (tens of thousands against hundreds) were being sorted
## together. Nothing failed; it just quietly meant nothing.
##
## Each entry also carries its `normalised` 0-1000, because a letter cannot be
## recovered from a raw score after the fact and "your best rank" is the part
## that makes this progression rather than a label.

const PATH := "user://sleepy_sun_scores.cfg"
const MAX_ENTRIES := 8

## id -> Array[Dictionary], best first.
var _scores: Dictionary = {}


func _ready() -> void:
	load_scores()


func load_scores() -> void:
	_scores.clear()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	# Entries from before the table was keyed are dropped rather than migrated
	# into one game or the other. There is no way to tell which game they came
	# from, and guessing would seed a game with a score nobody set on it.
	for id: String in cfg.get_section_keys("games") if cfg.has_section("games") else []:
		var entries: Array[Dictionary] = []
		for entry: Variant in cfg.get_value("games", id, []):
			if entry is Dictionary and entry.has("score"):
				entries.append(entry)
		_scores[StringName(id)] = entries
		_sort(StringName(id))


func save_scores() -> void:
	var cfg := ConfigFile.new()
	for id: StringName in _scores:
		cfg.set_value("games", String(id), _scores[id])
	cfg.save(PATH)


## Returns the 1-based place if the run made that game's table, or 0 if not.
func submit(id: StringName, score: int, normalised: int = 0,
		goldens: int = 0) -> int:
	var entries: Array[Dictionary] = _scores.get(id, [] as Array[Dictionary])
	entries.append({
		"score": score,
		"normalised": normalised,
		"goldens": goldens,
		"when": Time.get_datetime_string_from_system(true),
	})
	_scores[id] = entries
	_sort(id)
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
	save_scores()
	for i in entries.size():
		if int(entries[i]["score"]) == score:
			return i + 1
	return 0


## Wipes the local table. Used by the tests so a run's assertions do not depend
## on scores left behind by a previous run, and offered in the debug menu.
func clear() -> void:
	_scores.clear()
	save_scores()


func top(id: StringName, count: int = 5) -> Array[Dictionary]:
	var entries: Array[Dictionary] = _scores.get(id, [] as Array[Dictionary])
	return entries.slice(0, count)


func best(id: StringName) -> int:
	var entries: Array[Dictionary] = _scores.get(id, [] as Array[Dictionary])
	return int(entries[0]["score"]) if not entries.is_empty() else 0


## The best NORMALISED score, which is what a letter is cut from. Not simply
## the top entry's: the table is sorted by raw score, and the two can disagree
## for an endless game whose normalised number comes from how long you lasted
## rather than from the points.
func best_normalised(id: StringName) -> int:
	var top_value := 0
	for entry: Dictionary in _scores.get(id, [] as Array[Dictionary]):
		top_value = maxi(top_value, int(entry.get("normalised", 0)))
	return top_value


## Every golden prize this cabinet has ever handed out, across both games.
## What they are FOR is not decided yet; counting them is.
func goldens(id: StringName = &"") -> int:
	var total := 0
	for key: StringName in _scores:
		if id != &"" and key != id:
			continue
		for entry: Dictionary in _scores[key]:
			total += int(entry.get("goldens", 0))
	return total


func _sort(id: StringName) -> void:
	var entries: Array[Dictionary] = _scores.get(id, [] as Array[Dictionary])
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["score"]) > int(b["score"]))
