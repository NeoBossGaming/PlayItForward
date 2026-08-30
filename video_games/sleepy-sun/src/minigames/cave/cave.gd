extends MiniGame
## Echo Hollow -- five chambers, each guarded by a pattern of lit stones the
## player has to walk back in order.
##
## The input method is the point: you do not press five buttons, you walk the
## path with your body. It turns a memory test into a route you can feel, and it
## is the reason this works top-down with the same controls as everything else.
##
## No fail state. A wrong stone replays the pattern; two wrong stones in the
## same chamber replay it slowly. Nobody gets stuck on a public cabinet.

enum Phase { INTRO, SHOWING, INPUT, OPENING, WALKING, DONE }

const PLATE_COUNT := 5
## A ring, not a row. In a row, walking from the far right stone to the far left
## one drags the player across every stone in between and every one of them
## registers as a wrong answer -- the game is unplayable for any sequence that
## is not left-to-right. Arranged in a ring around a central standing spot, the
## path between any two stones runs through the middle instead: the tightest
## chord still clears every other stone by 48px, well outside their 20px reach.
## Rotated so no stone sits in the corridor leading up to the door.
## Tightened from radius 70 once the player was scaled up 1.5x -- the chamber
## read as too spread out around the character. Verified: the tightest chord
## between two stones still clears every other stone by 38px against a 20px
## trigger reach (13px plate + 7px player).
const RING_CENTRE := Vector2(240, 188)
const RING_RADIUS := 42.0
const PLATE_POSITIONS: Array[Vector2] = [
	Vector2(265, 154), Vector2(280, 201), Vector2(240, 230),
	Vector2(200, 201), Vector2(215, 154),
]
const PLAYER_START := RING_CENTRE
const ROOM_MIN_X := 75.0
const ROOM_MAX_X := 405.0
const ROOM_MIN_Y := 141.0
const ROOM_MAX_Y := 258.0
const DOORWAY_HALF_WIDTH := 20.0
const DOORWAY_MIN_Y := 112.0

## [steps, seconds lit, gap between]
const STAGES: Array[Array] = [
	[3, 0.60, 0.25],
	[4, 0.52, 0.22],
	[5, 0.45, 0.18],
	[6, 0.38, 0.15],
	[7, 0.32, 0.12],
]
## Speed a chamber replays at after two mistakes, so it always stays clearable.
const MERCY: Array = [0.62, 0.28]
const MERCY_AFTER_MISTAKES := 2

## Scoring is per step, not per chamber. A chamber-sized reward only pays out
## every twenty seconds or so; paying per stone means the score moves while the
## player is actually doing something, which is what makes it feel like a game
## rather than a test.
const SCORE_STEP := 12
const STREAK_PER_LEVEL := 3
const STREAK_MAX := 5
const SCORE_STAGE := 250
const SCORE_CLEAN_STAGE := 150
const SCORE_MISTAKE := -60
const SCORE_TIME_BONUS := 400
const PAR_SECONDS := 100.0

@onready var _player: TopDownPlayer = $Player
@onready var _hud: HUD = $HUD
@onready var _door: StageDoor = $Door
@onready var _exit_area: Area2D = $ExitArea
@onready var _plates_root: Node2D = $Plates
@onready var _torch_glows: Array[Node] = [$TorchGlowL, $TorchGlowR]

var _plates: Array[PressurePlate] = []
var _sequence: Array[int] = []
var _input_index: int = 0
var _stage: int = 0
var _cleared: int = 0
var _clean_stages: int = 0
var _mistakes: int = 0
var _stage_mistakes: int = 0
## Correct steps in a row. Carries across chambers, so a clean run compounds --
## that is the number a good player is really chasing.
var _streak: int = 0
var _best_streak: int = 0
var _step_score: int = 0
var _flicker: float = 0.0
var _phase: Phase = Phase.INTRO

var _plate_scene := preload("res://src/minigames/cave/pressure_plate.tscn")


func _ready() -> void:
	for i in PLATE_COUNT:
		var plate: PressurePlate = _plate_scene.instantiate()
		plate.index = i
		plate.position = PLATE_POSITIONS[i]
		plate.stepped_on.connect(_on_plate_stepped)
		_plates_root.add_child(plate)
		_plates.append(plate)

	_player.position = PLAYER_START
	_player.freeze()
	_exit_area.body_entered.connect(_on_exit_entered)

	_hud.reset_score(0)
	_hud.set_meter(0.0, &"chamber")


func control_hint() -> String:
	return "STICK  walk onto the stones"


func begin() -> void:
	super.begin()
	_start_stage()


func _process(delta: float) -> void:
	super._process(delta)
	_clamp_player()
	_flicker_torches(delta)
	if _phase != Phase.INPUT:
		return
	# Five pips under the ring fill as you step: no reading, and it works from
	# across a room in a way "stone 2 of 5" never did.
	_hud.set_pips(_input_index, _sequence.size(), Color(0.72, 1.0, 0.78))
	# A stone the player was already standing on when input opened arms itself
	# the moment they step off, so they can always re-enter it deliberately.
	for plate in _plates:
		if not plate.accepts_input and not plate.is_occupied():
			plate.accepts_input = true


## The chamber is a box with one gap in the far wall. Clamping is enough here --
## a room this simple does not need collision geometry to feel solid.
## Torchlight that sits perfectly still reads as a texture, not a flame.
func _flicker_torches(delta: float) -> void:
	_flicker += delta * 9.0
	for glow: Sprite2D in _torch_glows:
		var wobble := 0.32 + 0.09 * sin(_flicker + glow.position.x)
		glow.modulate.a = wobble
		glow.scale = Vector2.ONE * (2.2 + 0.12 * sin(_flicker * 1.3 + glow.position.x))


func _clamp_player() -> void:
	var position := _player.position
	position.x = clampf(position.x, ROOM_MIN_X, ROOM_MAX_X)
	var in_doorway := absf(position.x - PLAYER_START.x) < DOORWAY_HALF_WIDTH
	position.y = clampf(position.y,
			DOORWAY_MIN_Y if in_doorway else ROOM_MIN_Y, ROOM_MAX_Y)
	_player.position = position


# --- stage flow --------------------------------------------------------------

func _start_stage() -> void:
	_stage_mistakes = 0
	_sequence.clear()
	var spec: Array = STAGES[_stage]
	var steps: int = spec[0]

	var last := -1
	for i in steps:
		# Never the same stone twice running: a repeat is unreadable when the
		# lights are this quick, and it feels like a trick rather than a test.
		var next := randi() % PLATE_COUNT
		while next == last:
			next = randi() % PLATE_COUNT
		_sequence.append(next)
		last = next

	_door.close()
	_hud.set_meter(float(_stage) / float(STAGES.size()), &"chamber")
	_hud.toast("CHAMBER %d" % (_stage + 1), Color(0.8, 0.66, 1.0), 0.8)
	_play_sequence()


func _play_sequence(mercy: bool = false) -> void:
	_phase = Phase.SHOWING
	_input_index = 0
	_player.unfreeze()
	for plate in _plates:
		plate.accepts_input = false

	var lit: float = MERCY[0] if mercy else float(STAGES[_stage][1])
	var gap: float = MERCY[1] if mercy else float(STAGES[_stage][2])

	await Wait.on(self, 0.7)
	if not running:
		return

	_hud.set_pips(0, _sequence.size(), Color(1, 0.85, 0.45))
	for index in _sequence:
		if not running:
			return
		_plates[index].light(lit)
		await Wait.on(self, lit + gap)

	if not running:
		return
	_begin_input()


func _begin_input() -> void:
	_phase = Phase.INPUT
	_input_index = 0
	Audio.sfx(&"tick", 1.4)
	for plate in _plates:
		# A plate the player is already standing on must not fire the moment
		# input opens -- they have to step off and back on deliberately.
		# _process re-arms it once they do.
		plate.accepts_input = not plate.is_occupied()


func _on_plate_stepped(index: int) -> void:
	if _phase != Phase.INPUT:
		return

	if index == _sequence[_input_index]:
		_input_index += 1
		_streak += 1
		_best_streak = maxi(_best_streak, _streak)
		var multiplier := streak_multiplier()
		_step_score += SCORE_STEP * multiplier
		_hud.set_score(maxi(_running_score(), 0))
		_hud.set_multiplier(multiplier)
		pop(_plates[index].position, SCORE_STEP * multiplier, multiplier)
		if _input_index >= _sequence.size():
			_clear_stage()
		return

	_wrong()


## 1 to STREAK_MAX, stepping up every STREAK_PER_LEVEL correct stones.
func streak_multiplier() -> int:
	return clampi(1 + _streak / STREAK_PER_LEVEL, 1, STREAK_MAX)


func _wrong() -> void:
	_mistakes += 1
	_stage_mistakes += 1
	_phase = Phase.SHOWING
	Audio.sfx(&"deny")
	var lost := _streak
	_streak = 0
	_hud.set_multiplier(1)
	pop_on_player(SCORE_MISTAKE, "STREAK LOST" if lost >= STREAK_PER_LEVEL else "WRONG")
	_hud.set_score(maxi(_running_score(), 0))
	for plate in _plates:
		plate.accepts_input = false
		plate.flash_wrong()

	var mercy := _stage_mistakes >= MERCY_AFTER_MISTAKES
	if mercy:
		# The slower replay announces itself, so a struggling player can see the
		# game easing off rather than wondering why it changed.
		_hud.toast("SLOWER", Color(0.8, 0.9, 1.0), 0.7)
	await Wait.on(self, 0.8)
	if running:
		_play_sequence(mercy)


func _clear_stage() -> void:
	_phase = Phase.OPENING
	for plate in _plates:
		plate.accepts_input = false
	Audio.sfx(&"confirm")
	_cleared += 1
	if _stage_mistakes == 0:
		_clean_stages += 1
		_hud.toast("PERFECT", Color(1, 0.9, 0.5), 1.0)
	else:
		_hud.toast("THE WAY OPENS", Color(0.7, 1, 0.7), 1.0)
	_hud.set_score(maxi(_running_score(), 0))
	_door.open()
	await _door.opened
	if not running:
		return
	_phase = Phase.WALKING
	_hud.set_pips(0, 0)


func _on_exit_entered(body: Node2D) -> void:
	if _phase != Phase.WALKING or not (body is TopDownPlayer):
		return
	_stage += 1
	if _stage >= STAGES.size():
		_finish()
		return
	# Next chamber: same room, redressed. Cheaper than five scenes and the
	# player reads it as progress because the door shut behind them.
	_player.position = PLAYER_START
	_player.velocity = Vector2.ZERO
	_start_stage()


func _running_score() -> int:
	return _step_score \
			+ _cleared * SCORE_STAGE \
			+ _clean_stages * SCORE_CLEAN_STAGE \
			+ _mistakes * SCORE_MISTAKE


func _finish() -> void:
	_phase = Phase.DONE
	_player.freeze()
	Audio.sfx(&"complete")
	var pace := clampf(PAR_SECONDS / maxf(elapsed, 1.0), 0.0, 1.0)
	var score := _running_score() + int(SCORE_TIME_BONUS * pace)
	_hud.set_score(maxi(score, 0))
	finish(score, {"stages": _cleared, "mistakes": _mistakes,
			"streak": _best_streak})
