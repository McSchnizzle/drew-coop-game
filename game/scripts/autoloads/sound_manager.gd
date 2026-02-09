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


func _on_player_died(_player_id: int, _position: Vector2) -> void:
	_play(_player_died_player)


func _on_wave_started(_wave_number: int, _enemy_count: int) -> void:
	_play(_wave_started_player)


func _on_wave_cleared(_wave_number: int) -> void:
	_play(_wave_cleared_player)


func _on_ability_activated(_player_id: int, _ability: String, _position: Vector2, _direction: Vector2) -> void:
	_play(_ability_player)


func _on_revive_completed(_rescuer_id: int, _target_id: int) -> void:
	_play(_revive_player)


func _on_status_applied(_entity_id: int, _effect_name: String, _duration: float) -> void:
	_play(_status_player)


func _play(player: AudioStreamPlayer) -> void:
	if player and player.stream:
		player.play()
