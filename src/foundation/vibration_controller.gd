extends Node
class_name VibrationController

## VibrationController - Foundation Layer
## Implements: ADR-0002 Signal Architecture (vibration pattern)
## Mobile-only vibration feedback

## Signals

## Constants
const PATTERN_LIGHT_IMPACT: String = "Light Impact"
const PATTERN_HEAVY_IMPACT: String = "Heavy Impact"
const PATTERN_ENHANCEMENT_SUCCESS: String = "Enhancement Success"
const PATTERN_LEVEL_UP: String = "Level Up"
const PATTERN_VICTORY: String = "Victory"

## Pattern durations (ms)
const DURATION_LIGHT: int = 50
const DURATION_MEDIUM: int = 100
const DURATION_HEAVY: int = 200
const DURATION_VICTORY: int = 300

## State
var _vibration_capable: bool = false
var _last_vibration_time: float = 0.0
var _pattern_library: Dictionary = {}

#region Public API

func vibrate(pattern_name: String, tier: int = 1) -> void:
	## Trigger vibration pattern with intensity tier (1-4)
	if not _vibration_capable:
		return

	# Prevent spam (min 100ms between vibrations)
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_vibration_time < 0.1:
		return

	var base_duration: int = _pattern_library.get(pattern_name, DURATION_LIGHT)
	# Tier scales duration
	var scaled_duration: int = base_duration * tier
	scaled_duration = mini(scaled_duration, 500)  # Cap to 500ms

	OS.vibrate(scaled_duration)
	_last_vibration_time = now

func is_supported() -> bool:
	return _vibration_capable

func merge_patterns(pattern_names: Array) -> void:
	## Merge multiple patterns into single vibration
	if not _vibration_capable:
		return

	var total_duration: int = 0
	for pattern in pattern_names:
		total_duration += _pattern_library.get(pattern, DURATION_LIGHT)

	total_duration = mini(total_duration, 1000)  # Cap to 1s
	OS.vibrate(total_duration)

#endregion

#region Lifecycle

func _ready():
	_check_vibration_support()
	_setup_pattern_library()

#endregion

#region Internal

func _check_vibration_support() -> void:
	## Check if device supports vibration (mobile only)
	_vibration_capable = OS.has_feature("mobile")

func _setup_pattern_library() -> void:
	_pattern_library = {
		PATTERN_LIGHT_IMPACT: DURATION_LIGHT,
		PATTERN_HEAVY_IMPACT: DURATION_HEAVY,
		PATTERN_ENHANCEMENT_SUCCESS: DURATION_MEDIUM,
		PATTERN_LEVEL_UP: DURATION_HEAVY,
		PATTERN_VICTORY: DURATION_VICTORY,
	}

#endregion