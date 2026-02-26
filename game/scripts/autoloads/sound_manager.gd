## Sound manager autoload — listens to Events signals and plays sounds.
## Infrastructure-only: uses AudioStreamPlayer with no stream as placeholders.
## Actual sound files will be added later. This carries over to 3D.
extends Node

# Audio players for different sound categories.
var _shoot_player: AudioStreamPlayer = null
var _melee_player: AudioStreamPlayer = null
var _enemy_died_player: AudioStreamPlayer = null
var _player_died_player: AudioStreamPlayer = null
var _wave_started_player: AudioStreamPlayer = null
var _wave_cleared_player: AudioStreamPlayer = null
var _ability_player: AudioStreamPlayer = null
var _revive_player: AudioStreamPlayer = null
var _status_player: AudioStreamPlayer = null

# Lobby music + UI click
var _music_player: AudioStreamPlayer = null
var _ui_click_player: AudioStreamPlayer = null
var _music_fade_tween: Tween = null


func _ready() -> void:
	_shoot_player = _create_audio_player("ShootSound")
	_melee_player = _create_audio_player("MeleeSound")
	_enemy_died_player = _create_audio_player("EnemyDiedSound")
	_player_died_player = _create_audio_player("PlayerDiedSound")
	_wave_started_player = _create_audio_player("WaveStartedSound")
	_wave_cleared_player = _create_audio_player("WaveClearedSound")
	_ability_player = _create_audio_player("AbilitySound")
	_revive_player = _create_audio_player("ReviveSound")
	_status_player = _create_audio_player("StatusSound")

	# Lobby music
	_music_player = _create_audio_player("LobbyMusic")
	_music_player.volume_db = -10.0
	var music_stream := load("res://assets/audio/lobby_music.mp3")
	if music_stream:
		music_stream.loop = true
		_music_player.stream = music_stream

	# Procedural UI click sound
	_ui_click_player = _create_audio_player("UIClick")
	_ui_click_player.volume_db = -6.0
	_ui_click_player.stream = _generate_click_sound()

	# Connect to Events signals. Each connection is guarded so missing signals
	# don't crash (future-proofing as signals are added).
	_connect_signal("enemy_died", _on_enemy_died)
	_connect_signal("player_died", _on_player_died)
	_connect_signal("wave_started", _on_wave_started)
	_connect_signal("wave_cleared", _on_wave_cleared)
	_connect_signal("ability_activated", _on_ability_activated)
	_connect_signal("revive_completed", _on_revive_completed)
	_connect_signal("status_applied", _on_status_applied)


func _connect_signal(signal_name: String, callable: Callable) -> void:
	if Events.has_signal(signal_name):
		Events.connect(signal_name, callable)


func _create_audio_player(player_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = "Master"
	add_child(player)
	return player


# ── Sound Hooks ──────────────────────────────────────────────────────────────
# Each hook is a placeholder that will play a sound once a stream is assigned.
# To add a real sound: load an AudioStream and assign it to the player's .stream
# property, then call .play().

func play_shoot() -> void:
	_play(_shoot_player)


func play_melee() -> void:
	_play(_melee_player)


func _on_enemy_died(_enemy_id: int, _killed_by: int, _clean_kill: bool) -> void:
	_play(_enemy_died_player)


func _on_player_died(_player_id: int, _position: Vector3) -> void:
	_play(_player_died_player)


func _on_wave_started(_wave_number: int, _enemy_count: int) -> void:
	_play(_wave_started_player)


func _on_wave_cleared(_wave_number: int) -> void:
	_play(_wave_cleared_player)


func _on_ability_activated(_player_id: int, _ability: String, _position: Vector3, _direction: Vector3) -> void:
	_play(_ability_player)


func _on_revive_completed(_rescuer_id: int, _target_id: int) -> void:
	_play(_revive_player)


func _on_status_applied(_entity_id: int, _effect_name: String, _duration: float) -> void:
	_play(_status_player)


func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()


# ── Lobby Music ──────────────────────────────────────────────────────────────

func play_lobby_music() -> void:
	if _music_player and _music_player.stream and not _music_player.playing:
		_music_player.volume_db = -10.0
		_music_player.play()


func stop_lobby_music() -> void:
	if not _music_player or not _music_player.playing:
		return
	# Fade out over 1.5 seconds
	if _music_fade_tween:
		_music_fade_tween.kill()
	_music_fade_tween = create_tween()
	_music_fade_tween.tween_property(_music_player, "volume_db", -40.0, 1.5)
	_music_fade_tween.tween_callback(_music_player.stop)


# ── UI Click ─────────────────────────────────────────────────────────────────

func play_ui_click() -> void:
	if _ui_click_player and _ui_click_player.stream:
		_ui_click_player.play()


func _generate_click_sound() -> AudioStreamWAV:
	var sample_rate := 44100
	var duration := 0.03  # 30ms
	var frequency := 1200.0
	var sample_count := int(sample_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count)

	for i in range(sample_count):
		var t := float(i) / sample_rate
		var envelope := 1.0 - (t / duration)  # Linear decay
		envelope *= envelope  # Quadratic for snappier decay
		var sample := sin(t * frequency * TAU) * envelope
		# Convert to unsigned 8-bit (0-255, 128 = silence)
		data[i] = int(clampf(sample * 127.0 + 128.0, 0.0, 255.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = data
	return wav
