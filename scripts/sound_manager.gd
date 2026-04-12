extends Node

## Procedural sound manager - generates all game sounds from code
## No external audio files needed!

var audio_players: Dictionary = {}
var music_player: AudioStreamPlayer


func _ready() -> void:
	GameManager.play_sound.connect(_on_play_sound)
	_setup_music()


func _setup_music() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -12.0
	music_player.bus = "Master"
	add_child(music_player)


func _on_play_sound(sound_name: String) -> void:
	match sound_name:
		"collect_salt":
			_play_tone(800.0, 0.08, -8.0)
			_play_tone(1200.0, 0.06, -10.0, 0.05)
		"chili":
			_play_tone(300.0, 0.15, -6.0)
			_play_tone(600.0, 0.1, -8.0, 0.08)
			_play_tone(900.0, 0.08, -10.0, 0.14)
		"shield":
			_play_tone(500.0, 0.2, -8.0)
			_play_tone(700.0, 0.15, -10.0, 0.1)
		"shield_hit":
			_play_tone(200.0, 0.12, -6.0)
			_play_tone(150.0, 0.1, -8.0, 0.06)
		"oil":
			_play_tone(400.0, 0.15, -8.0)
			_play_tone(500.0, 0.12, -10.0, 0.08)
		"jump":
			_play_tone(400.0, 0.08, -10.0)
			_play_tone(600.0, 0.06, -12.0, 0.04)
		"die":
			_play_tone(400.0, 0.3, -6.0)
			_play_tone(300.0, 0.25, -6.0, 0.1)
			_play_tone(200.0, 0.3, -4.0, 0.2)
			_play_tone(100.0, 0.4, -4.0, 0.35)
		"enemy_kill":
			_play_tone(600.0, 0.08, -8.0)
			_play_tone(800.0, 0.06, -8.0, 0.04)
			_play_tone(1000.0, 0.06, -10.0, 0.08)
		"boss_appear":
			_play_tone(150.0, 0.4, -4.0)
			_play_tone(100.0, 0.3, -4.0, 0.2)
			_play_tone(80.0, 0.5, -2.0, 0.4)
		"boss_hit":
			_play_tone(250.0, 0.12, -6.0)
			_play_tone(200.0, 0.1, -6.0, 0.06)
		"boss_defeat":
			_play_tone(400.0, 0.15, -6.0)
			_play_tone(500.0, 0.12, -6.0, 0.1)
			_play_tone(600.0, 0.1, -6.0, 0.18)
			_play_tone(800.0, 0.1, -6.0, 0.25)
			_play_tone(1000.0, 0.15, -6.0, 0.32)
		"achievement":
			_play_tone(600.0, 0.12, -8.0)
			_play_tone(800.0, 0.1, -8.0, 0.1)
			_play_tone(1000.0, 0.12, -8.0, 0.18)
			_play_tone(1200.0, 0.15, -8.0, 0.26)
		"purchase":
			_play_tone(500.0, 0.1, -8.0)
			_play_tone(700.0, 0.08, -8.0, 0.06)
			_play_tone(900.0, 0.1, -8.0, 0.12)
		"stumble":
			_play_tone(300.0, 0.1, -8.0)
			_play_tone(200.0, 0.12, -6.0, 0.05)
		"hit":
			_play_tone(150.0, 0.15, -4.0)
			_play_tone(100.0, 0.2, -4.0, 0.08)


func _play_tone(freq: float, duration: float, volume_db: float, delay: float = 0.0) -> void:
	if delay > 0.0:
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(_create_tone_player.bind(freq, duration, volume_db))
	else:
		_create_tone_player(freq, duration, volume_db)


func _create_tone_player(freq: float, duration: float, volume_db: float) -> void:
	var player := AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = duration + 0.05
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_rate: float = stream.mix_rate
	var total_samples: int = int(duration * sample_rate)

	for i in range(total_samples):
		var t: float = float(i) / sample_rate
		var envelope: float = 1.0 - (t / duration)
		envelope = envelope * envelope
		var sample: float = sin(TAU * freq * t) * envelope * 0.3
		# Add slight harmonics for richer sound
		sample += sin(TAU * freq * 2.0 * t) * envelope * 0.1
		sample += sin(TAU * freq * 3.0 * t) * envelope * 0.05
		playback.push_frame(Vector2(sample, sample))

	# Auto cleanup
	var cleanup_timer := get_tree().create_timer(duration + 0.1)
	cleanup_timer.timeout.connect(player.queue_free)
