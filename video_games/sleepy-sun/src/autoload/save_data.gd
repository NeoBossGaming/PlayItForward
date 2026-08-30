extends Node
## Local high score table, kept in user:// so it survives a cabinet reboot.
##
## Deliberately local-only. A shared/online leaderboard is Phase 2+ work and is
## listed in docs/GAME_DESIGN.md under deferred work.

const PATH := "user://sleepy_sun_scores.cfg"
const MAX_ENTRIES := 8

var _scores: Array[Dictionary] = []


func _ready() -> void:
	load_scores()


func load_scores() -> void:
	_scores.clear()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for entry: Variant in cfg.get_value("scores", "entries", []):
		if entry is Dictionary and entry.has("score"):
			_scores.append(entry)
	_sort()


func save_scores() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "entries", _scores)
	cfg.save(PATH)


## Returns the 1-based rank if the run made the table, or 0 if it did not.
func submit(score: int, plastic_removed: int = 0) -> int:
	_scores.append({
		"score": score,
		"plastic": plastic_removed,
		"when": Time.get_datetime_string_from_system(true),
	})
	_sort()
	if _scores.size() > MAX_ENTRIES:
		_scores.resize(MAX_ENTRIES)
	save_scores()
	for i in _scores.size():
		if _scores[i]["score"] == score:
			return i + 1
	return 0


## Wipes the local table. Used by the tests so a run's assertions do not depend
## on scores left behind by a previous run, and offered in the debug menu.
func clear() -> void:
	_scores.clear()
	save_scores()


func top(count: int = 5) -> Array[Dictionary]:
	return _scores.slice(0, count)


func best() -> int:
	return _scores[0]["score"] if not _scores.is_empty() else 0


func _sort() -> void:
	_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["score"]) > int(b["score"]))
