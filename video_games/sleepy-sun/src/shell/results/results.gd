extends Node2D
## End of one credit. Counts the four scores up one at a time, then the total.
##
## The count-up is not decoration: it is the few seconds in which a player
## decides whether to pay again, and it is where the cabinet says what the money
## was actually for.

const ROW_DELAY := 0.55
const RETURN_SECONDS := 26.0

@onready var _rows: VBoxContainer = $UI/Panel/Rows
@onready var _total: Label = $UI/Panel/Total
@onready var _rank: Label = $UI/Rank
@onready var _flavour: Label = $UI/Flavour
@onready var _hint: Label = $UI/Hint
@onready var _sun: Sprite2D = $World/Sun

var _timeout: float = 0.0
var _leaving: bool = false
var _bob: float = 0.0


func _ready() -> void:
	_rank.text = ""
	_flavour.text = ""
	_total.text = ""
	_hint.modulate.a = 0.0
	for child in _rows.get_children():
		child.queue_free()
	_play_summary()


func _process(delta: float) -> void:
	_bob += delta
	_sun.position.y = 63.0 + sin(_bob * 1.4) * 3.0
	_sun.rotation = sin(_bob * 0.6) * 0.05

	_timeout += delta
	if not _leaving and (_timeout > RETURN_SECONDS
			or (_timeout > 3.0 and Input.is_action_just_pressed(&"act"))
			or (_timeout > 3.0 and Input.is_action_just_pressed(&"start"))):
		_leaving = true
		Router.go_to_attract()


func _play_summary() -> void:
	# Only the three games that were dealt, or the rank would compare a
	# three-game score against eight games' worth of par and always read GENTLE.
	var par := Game.playlist_par()
	for id: StringName in Game.playlist:
		await Wait.on(self, ROW_DELAY)
		var entry := Game.definition(id)
		var result: MiniGameResult = Game.results.get(id)
		_add_row(String(entry["title"]), result, entry["color"])
		Audio.sfx(&"tick", 1.0 + 0.12 * _rows.get_child_count())

	await Wait.on(self, 0.5)
	var total := Game.total_score()
	_total.text = "TOTAL   %d" % total
	Audio.sfx(&"complete")

	# The rank and the finale cutscene the player just watched come from the
	# same table in Lore, so a beaming sun can never be followed by a WARM stamp.
	var tier := Lore.tier_for(float(total) / maxf(float(par), 1.0))
	_rank.text = Lore.tier_name(tier)
	_rank.modulate = Lore.tier_color(tier)

	# The rank slams in rather than appearing. It is the one number the player
	# came for, and it should arrive like a stamp.
	_rank.pivot_offset = _rank.size / 2.0
	_rank.scale = Vector2(2.6, 2.6)
	var stamp := create_tween()
	stamp.tween_property(_rank, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	stamp.tween_callback(func() -> void: Juice.shake(self, 3.0))

	var place := Save.submit(total, Game.plastic_removed())
	_flavour.text = _flavour_text(place)

	await Wait.on(self, 0.6)
	create_tween().tween_property(_hint, "modulate:a", 1.0, 0.4)


func _flavour_text(place: int) -> String:
	var lines := PackedStringArray()
	if place > 0:
		lines.append("NEW BEST  -  #%d on this cabinet" % place)
	# What the run actually carried to the sun, in its own words. The gifts are
	# the through-line of the cutscenes, so the summary ends on them too.
	var gifts := PackedStringArray()
	for id: StringName in Game.playlist:
		var gift := String(Game.definition(id).get("gift", ""))
		if gift != "":
			gifts.append(gift)
	if not gifts.is_empty():
		lines.append("You brought it " + " + ".join(gifts) + ".")
	var plastic := Game.plastic_removed()
	if plastic > 0:
		lines.append("%d bottle%s pulled out of the river"
				% [plastic, "" if plastic == 1 else "s"])
	lines.append("Thank you. Your credit becomes a donation.")
	return "\n".join(lines)


func _add_row(title: String, result: MiniGameResult, color: Color) -> void:
	# Column widths are tight because Press Start 2P is roughly twice the width
	# of the vector font this used to use: 122 + 116 + 48 fits the 322px panel
	# with room for the separators, and anything wider runs off the screen.
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 6)

	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = 122.0
	_style(name_label, &"Heading", color)
	row.add_child(name_label)

	var detail := Label.new()
	detail.custom_minimum_size.x = 116.0
	if result == null:
		detail.text = "not played"
		_style(detail, &"Small", Color(0.6, 0.6, 0.7))
	else:
		detail.text = _detail_for(result)
		_style(detail, &"Small")
	row.add_child(detail)

	var score_label := Label.new()
	score_label.text = "%d" % (result.score if result != null else 0)
	score_label.custom_minimum_size.x = 48.0
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style(score_label, &"Heading")
	row.add_child(score_label)

	_rows.add_child(row)
	row.modulate.a = 0.0
	row.position.x = 14.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(row, "modulate:a", 1.0, 0.22)
	tween.tween_property(row, "position:x", 0.0, 0.25) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## One line per minigame saying what actually happened, in that game's own terms.
static func _detail_for(result: MiniGameResult) -> String:
	var stats := result.stats
	match result.id:
		&"wind_leaf":
			return "%s, %s" % [_count(stats, "chimes", "chime"),
					_count(stats, "splashes", "splash", "splashes")]
		&"tall_grass":
			return "%s, %s" % [_count(stats, "gathered", "find"),
					"safe at dusk" if stats.get("safe", false) else "caught out"]
		&"cave":
			return "%s, %s" % [_count(stats, "stages", "chamber"),
					_count(stats, "mistakes", "slip")]
		&"harpoon":
			var line := "%s, %s" % [_count(stats, "fish", "fish", "fish"),
					_count(stats, "plastic", "bottle")]
			if int(stats.get("multikill", 0)) >= 2:
				line += ", x%d shot" % int(stats["multikill"])
			return line
		&"acorn_storm":
			return "%s, %s" % [_count(stats, "fruit", "sunfruit", "sunfruit"),
					_count(stats, "hits", "knock")]
		&"firefly":
			return "%s, best x%d" % [_count(stats, "flies", "firefly", "fireflies"),
					int(stats.get("best_multiplier", 1))]
		&"temple_bell":
			return "%s, chain %d, %s" % [
					_count(stats, "perfect", "perfect", "perfect"),
					int(stats.get("chain", 0)), _count(stats, "coins", "coin")]
		&"crow_watch":
			return "%s saved, %s scared" % [_count(stats, "crop", "crop"),
					_count(stats, "scares", "crow")]
	return "%.0fs" % result.duration


static func _count(stats: Dictionary, key: String, singular: String,
		plural: String = "") -> String:
	var value := int(stats.get(key, 0))
	if plural == "":
		plural = singular + "s"
	return "%d %s" % [value, singular if value == 1 else plural]


## Everything text-shaped goes through the theme, so restyling the whole game
## stays a one-file edit in src/ui/game_theme.tres.
static func _style(label: Label, variation: StringName, color := Color.TRANSPARENT) -> void:
	label.theme_type_variation = variation
	if color.a > 0.0:
		label.add_theme_color_override(&"font_color", color)
