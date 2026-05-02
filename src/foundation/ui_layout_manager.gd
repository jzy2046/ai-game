extends Node
class_name UILayoutManager

## UILayoutManager - Foundation Layer
## Implements: ADR-0005 UI Anchor and Safe Area Strategy
## TR IDs: TR-ui-001, TR-ui-002

## Signals
signal safe_area_updated(safe_area: Rect2)

## Constants
const ANCHOR_TOP_LEFT: String = "top_left"
const ANCHOR_TOP_RIGHT: String = "top_right"
const ANCHOR_BOTTOM_LEFT: String = "bottom_left"
const ANCHOR_BOTTOM_RIGHT: String = "bottom_right"
const ANCHOR_CENTER: String = "center"
const ANCHOR_TOP_CENTER: String = "top_center"
const ANCHOR_BOTTOM_CENTER: String = "bottom_center"

## State
var _safe_area: Rect2 = Rect2()
var _screen_size: Vector2 = Vector2()
var _anchor_presets: Dictionary = {}

#region Public API

func apply_anchor(node: Control, preset_name: String) -> void:
	## Apply anchor preset to control node
	var preset_enum: int = _get_preset_enum(preset_name)
	node.set_anchors_preset(preset_enum)

	# Apply grow direction based on preset
	if preset_name.contains("top"):
		node.set_grow_direction_preset(Control.GROW_DIRECTION_BEGIN)
	elif preset_name.contains("bottom"):
		node.set_grow_direction_preset(Control.GROW_DIRECTION_END)
	elif preset_name == ANCHOR_CENTER:
		node.set_grow_direction_preset(Control.GROW_DIRECTION_BOTH)

func get_safe_area() -> Rect2:
	return _safe_area

func get_safe_area_margins() -> Dictionary:
	## Returns margins from screen edges to safe area
	var top: float = _safe_area.position.y
	var bottom: float = _screen_size.y - (_safe_area.position.y + _safe_area.size.y)
	var left: float = _safe_area.position.x
	var right: float = _screen_size.x - (_safe_area.position.x + _safe_area.size.x)

	return {
		top = top,
		bottom = bottom,
		left = left,
		right = right,
	}

func get_screen_orientation() -> String:
	## Returns current orientation (portrait or landscape)
	if _screen_size.x > _screen_size.y:
		return "landscape"
	return "portrait"

func get_screen_size() -> Vector2:
	return _screen_size

#endregion

#region Lifecycle

func _ready():
	_update_screen_info()

#endregion

#region Internal

func _update_screen_info() -> void:
	## Get screen size and safe area from DisplayServer
	_screen_size = DisplayServer.screen_get_size(0)
	_safe_area = DisplayServer.get_safe_area(0)
	emit_signal("safe_area_updated", _safe_area)

func _get_preset_enum(preset_name: String) -> int:
	## Convert preset name to Godot enum
	var preset_map: Dictionary = {
		ANCHOR_TOP_LEFT: Control.PRESET_TOP_LEFT,
		ANCHOR_TOP_RIGHT: Control.PRESET_TOP_RIGHT,
		ANCHOR_BOTTOM_LEFT: Control.PRESET_BOTTOM_LEFT,
		ANCHOR_BOTTOM_RIGHT: Control.PRESET_BOTTOM_RIGHT,
		ANCHOR_CENTER: Control.PRESET_CENTER,
		ANCHOR_TOP_CENTER: Control.PRESET_CENTER_TOP,
		ANCHOR_BOTTOM_CENTER: Control.PRESET_CENTER_BOTTOM,
	}
	return preset_map.get(preset_name, Control.PRESET_TOP_LEFT)

#endregion