extends Node
class_name AudioPool

## AudioPool - Polish Layer
## Implements: ADR-0004 Audio System Pooling
## TR IDs: TR-audio-001, TR-audio-002

## Signals

## Constants
const SFX_POOL_SIZE: int = 8
const UI_POOL_SIZE: int = 2

## State
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _sfx_library: Dictionary = {}

#region Public API

func play_sfx(name: String, volume_db: float = 0.0) -> void:
	## Play SFX from pool
	var stream: AudioStream = _sfx_library.get(name)
	if stream == null:
		push_warning("SFX not found: %s" % name)
		return

	for player in _sfx_pool:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return

	push_warning("SFX pool exhausted: %s" % name)

func play_ui(name: String) -> void:
	## Play UI sound from UI pool
	var stream: AudioStream = _sfx_library.get(name)
	if stream == null:
		return

	for player in _ui_pool:
		if not player.playing:
			player.stream = stream
			player.play()
			return

func play_music(stream: AudioStream, fade_time: float = 1.0) -> void:
	## Play music with fade transition
	if _music_player.playing and fade_time > 0:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, fade_time)
		await tween.finished

	_music_player.stream = stream
	_music_player.volume_db = -80.0
	_music_player.play()

	if fade_time > 0:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", 0.0, fade_time)

func play_layered(base_sfx: String, boss_sfx: String, delay_ms: float) -> void:
	## Play base SFX immediately, boss SFX after delay
	play_sfx(base_sfx)

	var timer := Timer.new()
	timer.wait_time = delay_ms / 1000.0
	timer.one_shot = true
	timer.timeout.connect(play_sfx.bind(boss_sfx))
	add_child(timer)
	timer.start()

func stop_all() -> void:
	## Stop all audio
	for player in _sfx_pool + _ui_pool:
		player.stop()
	_music_player.stop()

#endregion

#region Lifecycle

func _ready():
	_create_pools()
	_load_library()
	_configure_buses()

#endregion

#region Internal

func _create_pools() -> void:
	# SFX pool
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_sfx_pool.append(player)

	# UI pool
	for i in range(UI_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = &"UI"
		add_child(player)
		_ui_pool.append(player)

	# Music player
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	add_child(_music_player)

func _load_library() -> void:
	## Load SFX library (MVP: placeholder paths)
	# Real implementation loads from assets/audio/
	_sfx_library = {
		"hit_light": null,  # preload("res://assets/audio/sfx/hit_light.wav")
		"hit_heavy": null,
		"gold_collect": null,
		"enhance_success": null,
		"victory": null,
		"defeat": null,
		"button_click": null,
		"floor_complete": null,
	}

func _configure_buses() -> void:
	## Audio bus layout
	# MVP: Uses default Master bus
	# Real implementation loads AudioBusLayout.tres
	AudioServer.add_bus()  # Music
	AudioServer.set_bus_name(1, &"Music")
	AudioServer.set_bus_volume_db(1, -6.0)

	AudioServer.add_bus()  # SFX
	AudioServer.set_bus_name(2, &"SFX")

	AudioServer.add_bus()  # UI
	AudioServer.set_bus_name(3, &"UI")
	AudioServer.set_bus_volume_db(3, -3.0)

#endregion