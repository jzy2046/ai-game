extends Node
# FeedbackCoordinator - Presentation Layer
# NOTE: No class_name - autoload singleton, accessed via FeedbackCoordinator globally
# Implements multi-system feedback orchestration

## Signals

## Event types
const EVENT_HIT: String = "hit"
const EVENT_GOLD_GAIN: String = "gold_gain"
const EVENT_ENHANCEMENT: String = "enhancement"
const EVENT_LEVEL_UP: String = "level_up"
const EVENT_VICTORY: String = "victory"
const EVENT_DEFEAT: String = "defeat"
const EVENT_FLOOR_COMPLETE: String = "floor_complete"

## State
var _event_queue: Array = []
var _active_feedback: Dictionary = {}
# Cached autoload references
var _particle_pool: Node = null
var _vibration_controller: Node = null
var _audio_pool: Node = null

#region Public API

func trigger_feedback(event_name: String, tier: int, data: Dictionary) -> void:
	## Trigger coordinated feedback across systems
	tier = clampi(tier, 1, 6)

	# Particle feedback
	var particle_preset: String = _get_particle_preset(event_name)
	if not particle_preset.is_empty() and _particle_pool and _particle_pool.has_method("spawn_preset"):
		var position: Vector2 = data.get("position", Vector2(360, 640))
		_particle_pool.spawn_preset(particle_preset, position, tier)

	# Vibration feedback (disabled on desktop)
	var vibration_pattern: String = _get_vibration_pattern(event_name)
	if not vibration_pattern.is_empty() and _vibration_controller and _vibration_controller.has_method("vibrate"):
		_vibration_controller.vibrate(vibration_pattern, tier)

	# Audio feedback
	var sfx_name: String = _get_sfx_name(event_name)
	if not sfx_name.is_empty() and _audio_pool and _audio_pool.has_method("play_sfx"):
		_audio_pool.play_sfx(sfx_name)

func queue_layered(events: Array, base_delay: float = 0.3) -> void:
	## Queue sequential feedback with delays
	for i in range(events.size()):
		var event: Dictionary = events[i]
		var delay: float = event.get("delay", base_delay * i)

		var timer := Timer.new()
		timer.wait_time = delay
		timer.one_shot = true
		timer.timeout.connect(trigger_feedback.bind(event.name, event.tier, event.data))
		add_child(timer)
		timer.start()

func cancel_feedback(event_name: String) -> void:
	## Cancel pending feedback for event
	# MVP: Not implemented (future enhancement)
	pass

#endregion

#region Lifecycle

func _ready():
	# Cache autoload references
	_particle_pool = get_node("/root/ParticlePool")
	_vibration_controller = get_node("/root/VibrationController")
	_audio_pool = get_node("/root/AudioPool")

#endregion

#region Internal

func _get_particle_preset(event_name: String) -> String:
	## Map event to particle preset (use constant strings directly)
	var preset_map: Dictionary = {
		EVENT_HIT: "hit_flash",
		EVENT_GOLD_GAIN: "gold_burst",
		EVENT_ENHANCEMENT: "enhancement_flash",
		EVENT_LEVEL_UP: "level_up",
		EVENT_VICTORY: "victory_sparkle",
		EVENT_FLOOR_COMPLETE: "victory_sparkle",
	}
	return preset_map.get(event_name, "")

func _get_vibration_pattern(event_name: String) -> String:
	## Map event to vibration pattern (use constant strings directly)
	var pattern_map: Dictionary = {
		EVENT_HIT: "Light Impact",
		EVENT_ENHANCEMENT: "Enhancement Success",
		EVENT_LEVEL_UP: "Level Up",
		EVENT_VICTORY: "Victory",
	}
	return pattern_map.get(event_name, "")

func _get_sfx_name(event_name: String) -> String:
	## Map event to audio SFX name
	var sfx_map: Dictionary = {
		EVENT_HIT: "hit_light",
		EVENT_GOLD_GAIN: "gold_collect",
		EVENT_ENHANCEMENT: "enhance_success",
		EVENT_LEVEL_UP: "level_up",
		EVENT_VICTORY: "victory",
		EVENT_DEFEAT: "defeat",
		EVENT_FLOOR_COMPLETE: "floor_complete",
	}
	return sfx_map.get(event_name, "")

#endregion