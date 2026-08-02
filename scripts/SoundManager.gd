extends Node

const SAMPLE_RATE := 44100.0

var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = SAMPLE_RATE
	gen.buffer_length = 1.5
	player.stream = gen
	player.volume_db = -8.0
	add_child(player)

func play_tone(freq: float, duration: float) -> void:
	player.stop()
	player.play()
	var playback = player.get_stream_playback()
	_push_tone(playback, freq, duration)

func play_chime(freqs: Array, note_duration: float) -> void:
	player.stop()
	player.play()
	var playback = player.get_stream_playback()
	for freq in freqs:
		_push_tone(playback, freq, note_duration)

func _push_tone(playback, freq: float, duration: float) -> void:
	var total_frames := int(SAMPLE_RATE * duration)
	for i in range(total_frames):
		var t := float(i) / SAMPLE_RATE
		var envelope := 1.0 - (float(i) / float(total_frames))
		var sample := sin(t * freq * TAU) * 0.3 * envelope
		playback.push_frame(Vector2(sample, sample))
