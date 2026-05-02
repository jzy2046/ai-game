extends Node
class_name FeedbackCoordinator

## FeedbackCoordinator - Presentation Layer
## Implements multi-system feedback orchestration

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

#region Public API

func trigger_feedback(event_name: String, tier: int, data: Dictionary) -> void:
	## Trigger coordinated feedback across systems
	tier = clampi(tier, 1, 6)

	# Particle feedback
	var particle_preset: String = _get_particle_preset(event_name)
	if not particle_preset.is_empty():
		var position: Vector2 = data.get("position", Vector2(360, 640))
		ParticlePool.spawn_preset(particle_preset, position, tier)

	# Vibration feedback
	var vibration_pattern: String = _get_vibration_pattern(event_name)
	if not vibration_pattern.is_empty():
		VibrationController.vibrate(vibration_pattern, tier)

	# Audio feedback
	var sfx_name: String = _get_sfx_name(event_name)
	if not sfx_name.is_empty():
		AudioPool.play_sfx(sfx_name)

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

#region Internal

func _get_particle_preset(event_name: String) -> String:
	## Map event to particle preset
	var preset_map: Dictionary = {
		EVENT_HIT: ParticlePool.PRESET_HIT_FLASH,
		EVENT_GOLD_GAIN: ParticlePool.PRESET_GOLD_BURST,
		EVENT_ENHANCEMENT: ParticlePool.PRESET_ENHANCEMENT_FLASH,
		EVENT_LEVEL_UP: ParticlePool.PRESET_LEVEL_UP,
		EVENT_VICTORY: ParticlePool.PRESET_VICTORY_SPARKLE,
		EVENT_FLOOR_COMPLETE: ParticlePool.PRESET_VICTORY_SPARKLE,
	}
	return preset_map.get(event_name, "")

func _get_vibration_pattern(event_name: String) -> String:
	## Map event to vibration pattern
	var pattern_map: Dictionary = {
		EVENT_HIT: VibrationController.PATTERN_LIGHT_IMPACT,
		EVENT_ENHANCEMENT: VibrationController.PATTERN_ENHANCEMENT_SUCCESS,
		EVENT_LEVEL_UP: VibrationController.PATTERN_LEVEL_UP,
		EVENT_VICTORY: VibrationController.PATTERN_VICTORY,
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