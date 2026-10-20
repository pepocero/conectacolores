extends Node

enum Sfx {
	SELECT,
	CONNECT,
	COMPLETE,
	INVALID,
	HINT,
}

var _players: Dictionary = {}
var _streams: Dictionary = {}


func _ready() -> void:
	_streams[Sfx.SELECT] = _make_tone(880.0, 0.06, 0.22)
	_streams[Sfx.CONNECT] = _make_tone(660.0, 0.12, 0.28)
	_streams[Sfx.COMPLETE] = _make_arpeggio([523.25, 659.25, 783.99, 1046.5], 0.09, 0.3)
	_streams[Sfx.INVALID] = _make_tone(180.0, 0.1, 0.2)
	_streams[Sfx.HINT] = _make_tone(990.0, 0.08, 0.18)

	for sfx: int in _streams.keys():
		var player := AudioStreamPlayer.new()
		player.stream = _streams[sfx]
		player.bus = "Master"
		add_child(player)
		_players[sfx] = player


func play(sfx: Sfx) -> void:
	if not SettingsManager.sound_enabled:
		return
	if not _players.has(sfx):
		return
	var player: AudioStreamPlayer = _players[sfx]
	player.stop()
	player.play()


func vibrate(duration_ms: int = 20) -> void:
	if not SettingsManager.vibration_enabled:
		return
	if DisplayServer.is_touchscreen_available():
		Input.vibrate_handheld(duration_ms)


func _make_tone(freq: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in sample_count:
		var t := float(i) / float(sample_rate)
		var envelope := 1.0
		var attack := 0.01
		var release := duration * 0.35
		if t < attack:
			envelope = t / attack
		elif t > duration - release:
			envelope = maxf(0.0, (duration - t) / release)

		var sample := sin(TAU * freq * t) * volume * envelope
		var pcm := clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, pcm)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _make_arpeggio(freqs: Array, note_duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var total_duration := note_duration * float(freqs.size())
	var sample_count := int(total_duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i: int in sample_count:
		var t := float(i) / float(sample_rate)
		var note_index := mini(int(t / note_duration), freqs.size() - 1)
		var local_t := t - float(note_index) * note_duration
		var freq: float = freqs[note_index]
		var envelope := 1.0
		if local_t < 0.01:
			envelope = local_t / 0.01
		elif local_t > note_duration * 0.6:
			envelope = maxf(0.0, (note_duration - local_t) / (note_duration * 0.4))

		var sample := sin(TAU * freq * local_t) * volume * envelope
		var pcm := clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, pcm)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
