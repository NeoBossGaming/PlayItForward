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


func _init(p_id: StringName = &"", p_score: int = 0, p_duration: float = 0.0,
		p_stats: Dictionary = {}) -> void:
	id = p_id
	score = maxi(p_score, 0)
	duration = p_duration
	stats = p_stats


func _to_string() -> String:
	return "MiniGameResult(%s, score=%d, %.1fs, %s)" % [id, score, duration, stats]
