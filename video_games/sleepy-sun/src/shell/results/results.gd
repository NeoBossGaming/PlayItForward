extends Node2D
## End of one credit. Counts the four scores up one at a time, then the total.
##
## The count-up is not decoration: it is the few seconds in which a player
## decides whether to pay again, and it is where the cabinet says what the money
## was actually for.

const ROW_DELAY := 0.55
const RETURN_SECONDS := 26.0

## Fractions of the summed par score. Anything under `Gentle` still ranks.
const RANKS: Array[Array] = [
	[1.15, "RADIANT", Color(1, 0.87, 0.45)],
	[0.90, "BRIGHT", Color(0.95, 0.78, 0.42)],
	[0.65, "WARM", Color(0.78, 0.82, 0.6)],
	[0.00, "GENTLE", Color(0.7, 0.74, 0.85)],
]

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
	_sun.position.y = 84.0 + sin(_bob * 1.4) * 4.0
	_sun.rotation = sin(_bob * 0.6) * 0.05

	_timeout += delta
	if not _leaving and (_timeout > RETURN_SECONDS
			or (_timeout > 3.0 and Input.is_action_just_pressed(&"act"))
			or (_timeout > 3.0 and Input.is_action_just_pressed(&"start"))):
		_leaving = true
		Router.go_to_attract()


func _play_summary() -> void:
	var par := 0
	for entry in Game.MINIGAMES:
		await Wait.on(self, ROW_DELAY)
		var id: StringName = entry["id"]
		var result: MiniGameResult = Game.results.get(id)
		par += _par_for(id)
		_add_row(String(entry["title"]), result, entry["color"])
		Audio.sfx(&"tick", 1.0 + 0.12 * _rows.get_child_count())

	await Wait.on(self, 0.5)
	var total := Game.total_score()
	_total.text = "TOTAL   %d" % total
	Audio.sfx(&"complete")

	var ratio := float(total) / maxf(float(par), 1.0)
	for rank in RANKS:
		if ratio >= float(rank[0]):
			_rank.text = String(rank[1])
			_rank.modulate = rank[2]
			break

	var place := Save.submit(total, Game.plastic_removed())
	_flavour.text = _flavour_text(place)

	await Wait.on(self, 0.6)
	create_tween().tween_property(_hint, "modulate:a", 1.0, 0.4)


func _flavour_text(place: int) -> String:
	var lines := PackedStringArray()
	if place > 0:
		lines.append("NEW BEST  -  #%d on this cabinet" % place)
	var plastic := Game.plastic_removed()
	if plastic > 0:
		lines.append("%d bottle%s pulled out of the river"
				% [plastic, "" if plastic == 1 else "s"])
	lines.append("Thank you. Your credit becomes a donation.")
	return "\n".join(lines)


func _par_for(id: StringName) -> int:
	# Read from the packed scene so par lives with the minigame that defines it.
	var entry := Game.definition(id)
	var packed: PackedScene = load(entry["scene"])
	var state := packed.get_state()
	for i in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"par_score":
			return int(state.get_node_property_value(0, i))
	return 1000


func _add_row(title: String, result: MiniGameResult, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)

	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = 190.0
	_style(name_label, 12, color)
	row.add_child(name_label)

	var detail := Label.new()
	detail.custom_minimum_size.x = 120.0
	if result == null:
		detail.text = "not played"
		_style(detail, 10, Color(0.6, 0.6, 0.7))
	else:
		detail.text = _detail_for(result)
		_style(detail, 10, Color(0.78, 0.8, 0.9))
	row.add_child(detail)

	var score_label := Label.new()
	score_label.text = "%d" % (result.score if result != null else 0)
	score_label.custom_minimum_size.x = 70.0
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style(score_label, 14, Color(1, 0.87, 0.55))
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
			return "%s, spotted %d" % [_count(stats, "petals", "petal"),
					stats.get("spotted", 0)]
		&"cave":
			return "%s, %s" % [_count(stats, "stages", "chamber"),
					_count(stats, "mistakes", "slip")]
		&"fishing":
			return "%s, %s" % [_count(stats, "fish", "fish", "fish"),
					_count(stats, "plastic", "bottle")]
	return "%.0fs" % result.duration


static func _count(stats: Dictionary, key: String, singular: String,
		plural: String = "") -> String:
	var value := int(stats.get(key, 0))
	if plural == "":
		plural = singular + "s"
	return "%d %s" % [value, singular if value == 1 else plural]


static func _style(label: Label, size: int, color: Color) -> void:
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.07, 0.05, 0.11))
	label.add_theme_constant_override(&"outline_size", 5)
