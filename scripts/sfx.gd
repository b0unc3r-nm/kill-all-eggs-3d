extends Node

## Tiny procedural sound bank. No external audio files are required.

const SAMPLE_RATE := 44100
const PLAYER_POOL_SIZE := 14

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 918273
	for i in PLAYER_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_build_bank()


func play(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(sound_name):
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stop()
	player.stream = _streams[sound_name]
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


func stop_all() -> void:
	for player in _players:
		player.stop()


func _build_bank() -> void:
	_streams["shoot"] = _sweep(0.095, 980.0, 170.0, 0.46, 1, 0.34, 6.0, 0.002)
	_streams["hit"] = _sweep(0.055, 1450.0, 520.0, 0.28, 1, 0.26, 7.0, 0.001)
	_streams["flesh"] = _sweep(0.15, 260.0, 95.0, 0.72, 2, 0.38, 3.5, 0.002)
	_streams["egg_hit"] = _sweep(0.12, 190.0, 70.0, 0.82, 0, 0.34, 3.0, 0.002)
	_streams["egg_break"] = _sweep(0.32, 340.0, 55.0, 0.88, 0, 0.44, 2.2, 0.002)
	_streams["egg_land"] = _sweep(0.18, 105.0, 42.0, 0.68, 0, 0.42, 4.0, 0.003)
	_streams["hatch"] = _sweep(0.34, 115.0, 430.0, 0.58, 2, 0.35, 2.3, 0.005)
	_streams["hurt"] = _sweep(0.34, 245.0, 62.0, 0.44, 2, 0.48, 2.0, 0.002)
	_streams["jump"] = _sweep(0.14, 290.0, 580.0, 0.05, 0, 0.18, 2.5, 0.004)
	_streams["kill"] = _sweep(0.28, 650.0, 95.0, 0.45, 2, 0.34, 2.8, 0.002)
	_streams["wave"] = _sweep(0.52, 310.0, 940.0, 0.08, 0, 0.24, 1.5, 0.02)
	_streams["clear"] = _sweep(0.65, 520.0, 1320.0, 0.03, 0, 0.23, 1.6, 0.02)
	_streams["gameover"] = _sweep(1.15, 230.0, 48.0, 0.28, 2, 0.42, 1.25, 0.01)
	_streams["click"] = _sweep(0.06, 780.0, 390.0, 0.15, 1, 0.16, 4.0, 0.001)
	_streams["alien"] = _sweep(0.9, 130.0, 48.0, 0.6, 2, 0.42, 1.5, 0.025)
	_streams["alien_die"] = _sweep(0.7, 185.0, 38.0, 0.52, 2, 0.44, 1.7, 0.01)
	_streams["medkit_spawn"] = _sweep(0.45, 520.0, 920.0, 0.04, 0, 0.2, 1.8, 0.01)
	_streams["heal"] = _sweep(0.36, 430.0, 980.0, 0.02, 0, 0.24, 1.6, 0.004)
	_streams["medkit_expire"] = _sweep(0.3, 360.0, 180.0, 0.08, 0, 0.16, 2.2, 0.01)
	_streams["hug_screech"] = _sweep(0.36, 1180.0, 360.0, 0.5, 1, 0.36, 2.2, 0.004)
	_streams["hug_attach"] = _sweep(0.46, 760.0, 120.0, 0.66, 1, 0.48, 1.8, 0.005)
	_streams["struggle"] = _sweep(0.1, 220.0, 360.0, 0.72, 1, 0.26, 3.0, 0.002)
	_streams["hug_escape"] = _sweep(0.4, 300.0, 980.0, 0.2, 0, 0.3, 1.8, 0.004)
	_streams["infected"] = _sweep(1.4, 180.0, 40.0, 0.5, 2, 0.48, 1.2, 0.02)
	_streams["victory"] = _sweep(1.0, 420.0, 1180.0, 0.05, 0, 0.32, 1.5, 0.02)
	_streams["final_wave"] = _sweep(0.9, 220.0, 620.0, 0.25, 1, 0.34, 1.5, 0.01)


func _sweep(
	duration: float,
	freq_start: float,
	freq_end: float,
	noise_mix: float,
	waveform: int,
	volume: float,
	decay_power: float,
	attack: float
) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var progress := t / duration
		var frequency: float = lerpf(freq_start, freq_end, progress)
		phase += TAU * frequency / SAMPLE_RATE
		var osc := sin(phase)
		if waveform == 1:
			osc = 1.0 if osc >= 0.0 else -1.0
		elif waveform == 2:
			osc = fmod(phase / TAU, 1.0) * 2.0 - 1.0
		var noise := _rng.randf_range(-1.0, 1.0)
		var envelope: float = pow(maxf(0.0, 1.0 - progress), decay_power)
		if t < attack:
			envelope *= t / attack
		var sample := (osc * (1.0 - noise_mix) + noise * noise_mix) * envelope * volume
		var pcm := int(round(clampf(sample, -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 2, pcm)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
