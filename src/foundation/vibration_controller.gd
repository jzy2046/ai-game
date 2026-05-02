extends Node
# VibrationController - Foundation Layer
# NOTE: No class_name - autoload singleton, accessed via VibrationController globally
# Implements: ADR-0002 Signal Architecture (vibration pattern)
# Mobile-only vibration feedback - DISABLED on desktop for compilation

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
	## Trigger vibration pattern - DISABLED (desktop compilation issue)
	# TODO: Enable on mobile builds
	pass

func is_supported() -> bool:
	return _vibration_capable

func merge_patterns(pattern_names: Array) -> void:
	## Merge multiple patterns - DISABLED (desktop compilation issue)
	# TODO: Enable on mobile builds
	pass

#endregion

#region Lifecycle

func _ready():
	_check_vibration_support()
	_setup_pattern_library()

#endregion

#region Internal

func _check_vibration_support() -> void:
	## Check if device supports vibration (mobile only)
	_vibration_capable = false  # Disabled for desktop compilation

func _setup_pattern_library() -> void:
	_pattern_library = {
		PATTERN_LIGHT_IMPACT: DURATION_LIGHT,
		PATTERN_HEAVY_IMPACT: DURATION_HEAVY,
		PATTERN_ENHANCEMENT_SUCCESS: DURATION_MEDIUM,
		PATTERN_LEVEL_UP: DURATION_HEAVY,
		PATTERN_VICTORY: DURATION_VICTORY,
	}

#endregion