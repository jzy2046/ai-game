extends Node
# UILayoutManager - Foundation Layer
# NOTE: No class_name - autoload singleton, accessed via UILayoutManager globally
# Implements: ADR-0005 UI Anchor and Safe Area Strategy
# Safe area disabled for desktop compilation

## Signals
signal safe_area_updated(safe_area: Rect2)

## Constants
const ANCHOR_TOP_LEFT: String = "top_left"
const ANCHOR_TOP_RIGHT: String = "top_right"
const ANCHOR_BOTTOM_LEFT: String = "bottom_left"
const ANCHOR_BOTTOM_RIGHT: String = "bottom_right"
const ANCHOR_CENTER: String = "center"

## State
var _screen_size: Vector2 = Vector2.ZERO
var _safe_area: Rect2 = Rect2()
var _scale_factor: float = 1.0

#region Public API

func get_screen_size() -> Vector2:
	return _screen_size

func get_safe_area() -> Rect2:
	return _safe_area

func get_scale_factor() -> float:
	return _scale_factor

func apply_anchor_preset(control: Control, preset_name: String) -> void:
	## Apply anchor preset to control
	var preset: int = _get_preset_enum(preset_name)
	control.set_anchors_preset(preset)

func apply_safe_area_margins(control: Control) -> void:
	## Apply safe area margins to control
	# Disabled for desktop - use full screen
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, _screen_size)
	var margin_left: float = screen_rect.position.x - _safe_area.position.x
	var margin_right: float = screen_rect.end.x - _safe_area.end.x
	var margin_top: float = screen_rect.position.y - _safe_area.position.y
	var margin_bottom: float = screen_rect.end.y - _safe_area.end.y

	control.offset_left = margin_left
	control.offset_right = -margin_right
	control.offset_top = margin_top
	control.offset_bottom = -margin_bottom

#endregion

#region Lifecycle

func _ready():
	_update_screen_info()

#endregion

#region Internal

func _update_screen_info() -> void:
	## Get screen size - safe area disabled for desktop
	_screen_size = Vector2(720, 1280)  # Default mobile resolution
	_safe_area = Rect2(Vector2.ZERO, _screen_size)  # Full screen
	emit_signal("safe_area_updated", _safe_area)

func _get_preset_enum(preset_name: String) -> int:
	## Convert preset name to Godot enum
	var preset_map: Dictionary = {
		ANCHOR_TOP_LEFT: Control.PRESET_TOP_LEFT,
		ANCHOR_TOP_RIGHT: Control.PRESET_TOP_RIGHT,
		ANCHOR_BOTTOM_LEFT: Control.PRESET_BOTTOM_LEFT,
		ANCHOR_BOTTOM_RIGHT: Control.PRESET_BOTTOM_RIGHT,
		ANCHOR_CENTER: Control.PRESET_CENTER,
	}
	return preset_map.get(preset_name, Control.PRESET_CENTER)

#endregion