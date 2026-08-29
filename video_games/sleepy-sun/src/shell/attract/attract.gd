extends Node2D
## The cabinet's idle state, per the proposal's Idle/Attract -> Gameplay ->
## Results loop (Design Overview 2.4.1).
##
## Two jobs. It has to be readable from across a room -- so it cycles through
## the title, a how-to card per minigame, and the local high scores -- and it
## has to reward anyone who touches the controls before paying, because on a
## public cabinet that first touch is what turns a passer-by into a player.

const PANEL_SECONDS := 5.0

## Frames of the mascot's doze, held for these durations. He never fully wakes:
## that is the player's job.
const SUN_CYCLE: Array[float] = [1.6, 0.9, 2.4]

@onready var _sun: Sprite2D = $World/Sun
@onready var _wanderer: AnimatedSprite2D = $World/Wanderer
@onready var _panel_title: Label = $UI/Panel/Title
@onready var _panel_body: Label = $UI/Panel/Body
@onready var _panel_hint: Label = $UI/Panel/Hint
@onready var _press_start: Label = $UI/PressStart
@onready var _chimes: Node2D = $World/Chimes

var _sun_textures: Array[Texture2D] = []
var _sun_frame: int = 0
var _sun_timer: float = 0.0
var _sun_look: float = 0.0

var _panels: Array[Dictionary] = []
var _panel_index: int = 0
var _panel_timer: float = 0.0

var _wander_dir: float = 1.0
var _pulse: float = 0.0
var _starting: bool = false


func _ready() -> void:
	for i in 3:
		_sun_textures.append(load("res://assets/game/village/sun_%d.png" % i))
	_build_panels()
	_show_panel(0)
	_wanderer.play(&"walk_right")


func _process(delta: float) -> void:
	_animate_sun(delta)
	_animate_wanderer(delta)

	_pulse += delta * 3.0
	_press_start.modulate.a = 0.55 + 0.45 * sin(_pulse)

	_panel_timer += delta
	if _panel_timer >= PANEL_SECONDS:
		_show_panel((_panel_index + 1) % _panels.size())


func _unhandled_input(event: InputEvent) -> void:
	if _starting:
		return

	if event.is_action_pressed(&"start") or event.is_action_pressed(&"insert_credit"):
		_begin_run()
		return

	# --- Interactive idle -------------------------------------------------
	# Nothing here starts a game. It exists so touching the stick does
	# something visible immediately, which is what draws people in.
	if event.is_action_pressed(&"move_left"):
		_look(-1.0)
	elif event.is_action_pressed(&"move_right"):
		_look(1.0)
	elif event.is_action_pressed(&"move_up") or event.is_action_pressed(&"move_down"):
		_ring_chimes()
	elif event.is_action_pressed(&"act"):
		_ring_chimes()
		_show_panel((_panel_index + 1) % _panels.size())


func _begin_run() -> void:
	_starting = true

	# Phase 2 hook: a QRIS charge is created and polled here, and the run only
	# starts once it settles. Game.REQUIRE_CREDIT gates it. Deliberately not
	# implemented -- see docs/GAME_DESIGN.md, "Deferred work".
	if Game.REQUIRE_CREDIT:
		push_warning("Attract: credit required but no payment provider is wired up.")

	Audio.sfx(&"confirm")
	Game.start_run()
	Router.go_to_hub()


func _look(direction: float) -> void:
	_sun_look = direction
	Audio.sfx(&"chime", randf_range(0.9, 1.15))
	var tween := create_tween()
	tween.tween_property(_sun, "position:x", 528.0 + direction * 5.0, 0.12)
	tween.tween_property(_sun, "position:x", 528.0, 0.5) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _ring_chimes() -> void:
	Audio.sfx(&"chime", randf_range(1.0, 1.4))
	for chime: Node2D in _chimes.get_children():
		var tween := create_tween()
		tween.tween_property(chime, "rotation", randf_range(-0.35, 0.35), 0.10)
		tween.tween_property(chime, "rotation", 0.0, 0.7) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _animate_sun(delta: float) -> void:
	_sun_timer += delta
	if _sun_timer >= SUN_CYCLE[_sun_frame]:
		_sun_timer = 0.0
		_sun_frame = (_sun_frame + 1) % _sun_textures.size()
		_sun.texture = _sun_textures[_sun_frame]
	_sun.position.y = 78.0 + sin(Time.get_ticks_msec() / 700.0) * 3.0


func _animate_wanderer(delta: float) -> void:
	_wanderer.position.x += _wander_dir * 22.0 * delta
	if _wanderer.position.x > 560.0:
		_wander_dir = -1.0
		_wanderer.play(&"walk_left")
	elif _wanderer.position.x < 80.0:
		_wander_dir = 1.0
		_wanderer.play(&"walk_right")


func _build_panels() -> void:
	_panels.append({
		"title": "A PLAY IT FORWARD ADVENTURE",
		"body": "The sun is nodding off before it can set.\n"
			+ "Four evening chores. Gather the light it needs.",
		"hint": "Four minigames. You cannot lose -- only shine brighter.",
	})
	for entry in Game.MINIGAMES:
		_panels.append({
			"title": String(entry["title"]).to_upper(),
			"body": entry["blurb"],
			"hint": "",
			"color": entry["color"],
		})
	_panels.append({
		"title": "BEST RUNS",
		"body": _score_table(),
		"hint": "",
	})


func _score_table() -> String:
	var rows := Save.top(4)
	if rows.is_empty():
		return "No runs yet.\nBe the first."
	var lines := PackedStringArray()
	for i in rows.size():
		lines.append("%d.  %s" % [i + 1, _comma(int(rows[i]["score"]))])
	return "\n".join(lines)


static func _comma(value: int) -> String:
	var text := str(value)
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out


func _show_panel(index: int) -> void:
	_panel_index = index
	_panel_timer = 0.0
	var panel := _panels[index]
	_panel_title.text = panel["title"]
	_panel_title.modulate = panel.get("color", Color(1, 0.87, 0.55))
	_panel_body.text = panel["body"]
	_panel_hint.text = panel.get("hint", "")

	var tween := create_tween()
	$UI/Panel.modulate.a = 0.0
	tween.tween_property($UI/Panel, "modulate:a", 1.0, 0.25)
