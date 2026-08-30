extends CanvasLayer
## Neo's playtest menu. F3, from any screen.
##
## Completely inert unless OS.is_debug_build(), so an exported cabinet build
## cannot show it no matter what somebody presses. It is a side door for tuning,
## not a replacement for the card draw -- jumping straight into a game just deals
## a one-card hand, so Router's normal flow still runs and still ends at Results.

const SLOW_SCALE := 0.35

enum Row { GAME, CUTSCENE, FORCE_HAND, RESTART, RESULTS, SLOWMO, CLEAR_SCORES, CLOSE }

## What the cutscene viewer steps through, in order: the four beats of one
## game's lore, then the three endings. Reviewing the story must not cost three
## full minigames, or it does not get reviewed.
const CUTSCENE_VIEWS: Array[String] = ["before", "after (met par)", "after (soft)",
		"finale RADIANT", "finale BRIGHT", "finale GENTLE"]

var _rows: Array[Dictionary] = []
var _index: int = 0
var _open: bool = false
var _forced_hand: Array[StringName] = []
var _hand_cursor: int = 0
var _cutscene_game: int = 0
var _cutscene_view: int = 0
var _viewing: bool = false

var _panel: ColorRect
var _title: Label
var _list: VBoxContainer
var _hint: Label


func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not OS.is_debug_build():
		# Not just hidden: it never listens for the key at all.
		set_process_input(false)
		return
	_build_ui()
	_build_rows()


func _build_ui() -> void:
	_panel = ColorRect.new()
	_panel.color = Color(0.05, 0.04, 0.09, 0.93)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_title = _label(&"Heading", Color(1, 0.85, 0.5))
	_title.text = "DEBUG  (debug builds only)"
	_title.position = Vector2(16, 10)
	_panel.add_child(_title)

	_list = VBoxContainer.new()
	_list.position = Vector2(16, 34)
	_list.add_theme_constant_override(&"separation", 1)
	_panel.add_child(_list)

	_hint = _label(&"Small", Color(0.7, 0.68, 0.82))
	_hint.text = "up/down  move    left/right  cycle    SPACE  choose    F3  close"
	_hint.position = Vector2(16, 250)
	_panel.add_child(_hint)


func _label(variation: StringName, colour: Color) -> Label:
	var label := Label.new()
	label.theme_type_variation = variation
	label.add_theme_color_override(&"font_color", colour)
	return label


func _build_rows() -> void:
	_rows.clear()
	for entry in Game.MINIGAMES:
		_rows.append({"kind": Row.GAME, "id": entry["id"],
				"text": "play  %s" % entry["title"]})
	_rows.append({"kind": Row.CUTSCENE, "text": ""})
	_rows.append({"kind": Row.FORCE_HAND, "text": ""})
	_rows.append({"kind": Row.RESTART, "text": "restart this minigame"})
	_rows.append({"kind": Row.RESULTS, "text": "skip to results"})
	_rows.append({"kind": Row.SLOWMO, "text": ""})
	_rows.append({"kind": Row.CLEAR_SCORES, "text": "clear local high scores"})
	_rows.append({"kind": Row.CLOSE, "text": "close"})


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	# While a cutscene is playing over the menu the menu is deaf: otherwise the
	# button used to skip the cutscene would immediately replay it.
	if _viewing:
		return
	if event.is_action_pressed(&"debug_menu"):
		_toggle()
		get_viewport().set_input_as_handled()
		return
	if not _open:
		return

	if event.is_action_pressed(&"move_down"):
		_index = (_index + 1) % _rows.size()
		_refresh()
	elif event.is_action_pressed(&"move_up"):
		_index = (_index - 1 + _rows.size()) % _rows.size()
		_refresh()
	elif _rows[_index]["kind"] == Row.CUTSCENE and (
			event.is_action_pressed(&"move_left")
			or event.is_action_pressed(&"move_right")):
		# Left picks the game, right picks which of its beats to watch, so
		# stepping through all 51 of them never leaves this row.
		if event.is_action_pressed(&"move_left"):
			_cutscene_game = (_cutscene_game + 1) % Game.MINIGAMES.size()
		else:
			_cutscene_view = (_cutscene_view + 1) % CUTSCENE_VIEWS.size()
		_refresh()
	elif event.is_action_pressed(&"act") or event.is_action_pressed(&"start"):
		_activate()
	elif event.is_action_pressed(&"back"):
		_toggle()
	else:
		return
	get_viewport().set_input_as_handled()


func _toggle() -> void:
	_open = not _open
	visible = _open
	# Pausing means a minigame is not still running underneath the menu.
	get_tree().paused = _open
	if _open:
		_refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	for i in _rows.size():
		var row := _rows[i]
		var text: String = row["text"]
		match row["kind"]:
			Row.FORCE_HAND:
				text = "force next hand:  %s" % (_hand_text() if not _forced_hand.is_empty()
						else "(off -- choose to add a card)")
			Row.SLOWMO:
				text = "slow motion:  %s" % ("ON" if Engine.time_scale < 1.0 else "off")
			Row.CUTSCENE:
				text = "watch lore:  %s  /  %s" % [
						Game.MINIGAMES[_cutscene_game]["title"],
						CUTSCENE_VIEWS[_cutscene_view]]
		var label := _label(&"Body", Color(1, 1, 1) if i == _index else Color(0.62, 0.6, 0.74))
		label.text = ("> " if i == _index else "  ") + text
		_list.add_child(label)


func _hand_text() -> String:
	var names := PackedStringArray()
	for id in _forced_hand:
		names.append(String(Game.definition(id).get("title", id)))
	return ", ".join(names)


func _activate() -> void:
	var row := _rows[_index]
	match row["kind"]:
		Row.GAME:
			_play_one(row["id"])
		Row.CUTSCENE:
			_watch_cutscene()
		Row.FORCE_HAND:
			_cycle_forced_hand()
		Row.RESTART:
			var scene := get_tree().current_scene
			if scene is MiniGame:
				_play_one((scene as MiniGame).id)
		Row.RESULTS:
			_close_and(func() -> void: Router.go_to_results())
		Row.SLOWMO:
			Engine.time_scale = 1.0 if Engine.time_scale < 1.0 else SLOW_SCALE
			_refresh()
		Row.CLEAR_SCORES:
			Save.clear()
			_refresh()
		Row.CLOSE:
			_toggle()


## Deals a one-card hand so the normal Router flow carries it: play, then
## straight to Results. The card draw itself is untouched.
func _play_one(id: StringName) -> void:
	_close_and(func() -> void:
		if not Game.run_active:
			Game.start_run()
		Game.playlist = [id]
		Game.playlist_index = 0
		Router.play_minigame(id))


## Plays the selected beat straight over whatever is on screen, without
## unpausing the game underneath it. The whole point is to be able to look at
## all fifty-one of them in a couple of minutes.
func _watch_cutscene() -> void:
	var id: StringName = Game.MINIGAMES[_cutscene_game]["id"]
	var shots: Array = []
	match _cutscene_view:
		0: shots = Lore.before(id)
		1: shots = Lore.after(id, true)
		2: shots = Lore.after(id, false)
		_:
			var hand: Array[StringName] = []
			for entry in Game.MINIGAMES.slice(0, Game.PLAYLIST_SIZE):
				hand.append(entry["id"])
			if not Game.playlist.is_empty():
				hand = Game.playlist.duplicate()
			shots = Lore.finale(_cutscene_view - 3, hand)
	if shots.is_empty():
		return
	# Router owns the cutscene layer, which sits below this menu -- so the menu
	# hides itself and lets it play, with the tree still paused underneath.
	_viewing = true
	visible = false
	await Router.play_cutscene(shots)
	_viewing = false
	visible = _open
	if _open:
		_refresh()


## Adds cards one at a time up to a full hand, then clears back to off.
func _cycle_forced_hand() -> void:
	var pool: Array[StringName] = []
	for entry in Game.MINIGAMES:
		if not (entry["id"] in _forced_hand):
			pool.append(entry["id"])
	if _forced_hand.size() >= Game.PLAYLIST_SIZE or pool.is_empty():
		_forced_hand.clear()
		Game.forced_hand.clear()
	else:
		_forced_hand.append(pool[_hand_cursor % pool.size()])
		_hand_cursor += 1
		Game.forced_hand = _forced_hand.duplicate()
	_refresh()


func _close_and(action: Callable) -> void:
	_open = false
	visible = false
	get_tree().paused = false
	action.call()
