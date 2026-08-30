extends Node2D
## The card table: what one credit deals you, and the beat between games.
##
## Replaces the village hub. A hub you walk around is calm, and it made four
## minigames feel like errands; a cabinet needs the opposite. Three cards, a
## shuffle, and you are playing within eight seconds of pressing start.
##
## Two modes in one scene because they share a layout:
##   MODE_DEAL     shuffle and stop the three cards, left to right
##   MODE_ADVANCE  between games -- stamp what is done, flip up what is next

enum Mode { DEAL, ADVANCE }

const CARD_X: Array[float] = [80.0, 240.0, 400.0]
const CARD_Y := 162.0

const SPIN_BEFORE_FIRST := 0.85
const SPIN_BETWEEN := 0.55
const AFTER_DEAL_HOLD := 1.5
const ADVANCE_HOLD := 2.2

@onready var _cards_root: Node2D = $Cards
@onready var _heading: Label = $UI/Heading
@onready var _sub: Label = $UI/Sub
@onready var _total: Label = $UI/Total
@onready var _sun: Sprite2D = $World/Sun

var _cards: Array[DrawCard] = []
var _mode: Mode = Mode.DEAL
var _leaving: bool = false
var _bob: float = 0.0

var _card_scene := preload("res://src/shell/draw/card.tscn")


func _ready() -> void:
	_mode = Mode.DEAL if Router.draw_should_deal() else Mode.ADVANCE

	for i in Game.PLAYLIST_SIZE:
		var card: DrawCard = _card_scene.instantiate()
		card.position = Vector2(CARD_X[i], CARD_Y)
		# add_child first: set_index touches @onready refs, which are only
		# resolved once the card has entered the tree.
		_cards_root.add_child(card)
		card.set_index(i)
		_cards.append(card)

	_total.text = ""
	if _mode == Mode.DEAL:
		_run_deal()
	else:
		_run_advance()


func _process(delta: float) -> void:
	_bob += delta
	_sun.position.y = 24.0 + sin(_bob * 1.5) * 3.0

	if Game.idle_seconds() > Game.IDLE_TIMEOUT and not _leaving:
		_leaving = true
		Router.go_to_attract()


# --- dealing -----------------------------------------------------------------

func _run_deal() -> void:
	_heading.text = "YOUR HAND"
	_sub.text = "three games, dealt fresh"

	Game.draw_playlist()
	for card in _cards:
		card.start_spin()
	Audio.sfx(&"shake", 1.4)

	# Stopping the cards one at a time, left to right, is the whole trick. Three
	# simultaneous stops is a random number; a staggered stop is a slot machine,
	# and the pause before the last card is where the tension lives.
	await Wait.on(self, SPIN_BEFORE_FIRST)
	for i in _cards.size():
		if not is_inside_tree():
			return
		_cards[i].land_on(Game.playlist[i])
		if i < _cards.size() - 1:
			await Wait.on(self, SPIN_BETWEEN)

	await Wait.on(self, AFTER_DEAL_HOLD)
	_begin_next()


# --- between games -----------------------------------------------------------

func _run_advance() -> void:
	_heading.text = "NEXT UP"
	_sub.text = ""
	_total.text = "%d" % Game.total_score()

	for i in _cards.size():
		if i >= Game.playlist.size():
			continue
		var id: StringName = Game.playlist[i]
		_cards[i].land_on(id)
		if i < Game.playlist_index:
			_cards[i].mark_played(Game.score_for(id))
		elif i == Game.playlist_index:
			_cards[i].mark_next()
			_sub.text = String(Game.definition(id)["title"])

	await Wait.on(self, ADVANCE_HOLD)
	_begin_next()


func _begin_next() -> void:
	if _leaving:
		return
	_leaving = true
	if Game.all_complete():
		Router.go_to_results()
	else:
		Router.play_current()


func _unhandled_input(event: InputEvent) -> void:
	# Skipping ahead is allowed once the hand is visible -- a repeat player
	# should never be made to sit through the reveal they already understand.
	if _leaving or _mode == Mode.DEAL:
		return
	if event.is_action_pressed(&"act") or event.is_action_pressed(&"start"):
		_begin_next()
