extends Node
## Procedurally generated sound effects.
##
## No .wav files ship with the project: every cue is a short synthesised tone
## built once at startup, so the game has audio feedback without waiting on an
## audio pass. Replacing this with real samples later means changing only the
## body of sfx() -- callers stay the same.

const SAMPLE_RATE := 22050
const VOICES := 8

enum Wave { SINE, SQUARE, TRIANGLE, NOISE }

## name -> [frequency Hz, seconds, wave, volume 0-1, pitch slide multiplier]
const LIBRARY := {
	&"hop":      [520.0, 0.10, Wave.TRIANGLE, 0.35, 1.6],
	&"splash":   [180.0, 0.35, Wave.NOISE,    0.30, 0.5],
	&"pickup":   [880.0, 0.14, Wave.SINE,     0.35, 1.9],
	&"shake":    [140.0, 0.18, Wave.TRIANGLE, 0.22, 0.9],
	&"step":     [220.0, 0.06, Wave.SQUARE,   0.14, 1.0],
	&"deny":     [160.0, 0.28, Wave.SQUARE,   0.30, 0.6],
	&"confirm":  [660.0, 0.12, Wave.SQUARE,   0.30, 1.5],
	&"door":     [110.0, 0.60, Wave.TRIANGLE, 0.30, 1.3],
	&"spotted":  [300.0, 0.30, Wave.SQUARE,   0.32, 0.45],
	&"cast":     [420.0, 0.16, Wave.TRIANGLE, 0.28, 0.7],
	&"catch":    [700.0, 0.20, Wave.SINE,     0.35, 1.7],
	&"trash":    [200.0, 0.24, Wave.SQUARE,   0.28, 0.55],
	&"complete": [660.0, 0.45, Wave.SINE,     0.35, 2.0],
	&"chime":    [990.0, 0.30, Wave.SINE,     0.28, 1.2],
	&"tick":     [440.0, 0.05, Wave.SQUARE,   0.18, 1.0],
}

## The five cave plates each get their own note, so the sequence is audible as
## well as visible -- players who hum it back do noticeably better.
const PLATE_NOTES := [392.0, 466.0, 523.0, 622.0, 698.0]

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		add_child(player)
		_players.append(player)
	for name: StringName in LIBRARY:
		var spec: Array = LIBRARY[name]
		_streams[name] = _build(spec[0], spec[1], spec[2], spec[3], spec[4])


func _exit_tree() -> void:
	# Drop the synthesised streams before the audio server tears down. Without
	# this they are still referenced when Godot reports leaked objects at exit,
	# and that noise would bury a real leak in the test output later.
	for player in _players:
		player.stop()
		player.stream = null
	_streams.clear()


func sfx(name: StringName, pitch: float = 1.0) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		return
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	player.stream = stream
	player.pitch_scale = clampf(pitch, 0.2, 4.0)
	player.play()


## Plays the note belonging to a cave pressure plate (0-4).
func plate_note(index: int) -> void:
	var freq: float = PLATE_NOTES[clampi(index, 0, PLATE_NOTES.size() - 1)]
	var key := StringName("plate_%d" % index)
	if not _streams.has(key):
		_streams[key] = _build(freq, 0.26, Wave.SINE, 0.32, 1.0)
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	player.stream = _streams[key]
	player.pitch_scale = 1.0
	player.play()


func _build(freq: float, seconds: float, wave: Wave, volume: float,
		slide: float) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * seconds)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 1000.0)
	var phase := 0.0

	for i in frames:
		var t := float(i) / float(frames)
		# Fast attack, exponential decay: reads as a "blip" rather than a beep.
		var envelope := minf(t / 0.02, 1.0) * pow(1.0 - t, 2.2)
		var current_freq: float = lerpf(freq, freq * slide, t)
		phase += current_freq / SAMPLE_RATE
		var sample := 0.0
		match wave:
			Wave.SINE:
				sample = sin(phase * TAU)
			Wave.SQUARE:
				sample = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			Wave.TRIANGLE:
				sample = absf(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0
			Wave.NOISE:
				sample = rng.randf_range(-1.0, 1.0)
		var value := int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
