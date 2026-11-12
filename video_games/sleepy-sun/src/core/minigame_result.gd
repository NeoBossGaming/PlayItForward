class_name MiniGameResult
extends RefCounted
## What a minigame hands back when it ends.
##
## Every minigame produces one of these, the hub reads it to light up a star,
## and the results screen reads the whole set. Adding a fifth minigame means
## returning one of these and nothing else.

var id: StringName
var score: int
var duration: float
var stats: Dictionary
## The same run expressed 0-1000, so games on wildly different scales can share
## one table. Riverleap is endless and pays tens of thousands; a fixed-length
## game pays hundreds. Comparing those raw would rank the games, not the
## players. See MiniGame.normalised_score().
var normalised: int


func _init(p_id: StringName = &"", p_score: int = 0, p_duration: float = 0.0,
		p_stats: Dictionary = {}, p_normalised: int = 0) -> void:
	id = p_id
	score = maxi(p_score, 0)
	duration = p_duration
	stats = p_stats
	normalised = clampi(p_normalised, 0, 1000)


func _to_string() -> String:
	return "MiniGameResult(%s, score=%d (%d/1000), %.1fs, %s)" \
			% [id, score, normalised, duration, stats]
