extends Node
# TouchRouter - Core Layer
# NOTE: No class_name - autoload singleton, accessed via TouchRouter globally
## Implements: ADR-0006 Touch Input Routing
## TR IDs: TR-input-001, TR-input-002, TR-input-003

## Signals
signal touch_tap(position: Vector2, target: String)
signal button_clicked(position: Vector2)
signal touch_hold(position: Vector2, target: String)
signal touch_swipe(start_pos: Vector2, end_pos: Vector2)

## Constants
const TAP_DURATION_MAX: int = 300  # ms
const HOLD_DURATION_MIN: int = 500  # ms
const SWIPE_DISTANCE_MIN: float = 30.0  # pixels

## Layer enum
enum Layer { GAME = 0, POPUP = 1, MODAL = 2 }

## State
var _active_layer: Layer = Layer.GAME
var _modal_stack: Array = []
var _layer_nodes: Dictionary = {
	Layer.GAME: [],
	Layer.POPUP: [],
	Layer.MODAL: [],
}
var _gesture_state: Dictionary = {}

#region Public API

func register_layer(layer: Layer, nodes: Array) -> void:
	## Register nodes for touch routing at specific layer
	_layer_nodes[layer] = nodes

func push_modal(modal: Control) -> void:
	## Push modal and block lower layers
	_modal_stack.append(modal)
	_active_layer = Layer.MODAL
	_layer_nodes[Layer.MODAL] = [modal]

func pop_modal() -> void:
	## Pop modal and restore previous layer state
	if _modal_stack.size() > 0:
		_modal_stack.pop_back()

	if _modal_stack.size() > 0:
		_active_layer = Layer.MODAL
		_layer_nodes[Layer.MODAL] = [_modal_stack.back()]
	else:
		_active_layer = Layer.GAME

func get_active_layer() -> Layer:
	return _active_layer

#endregion

#region Lifecycle

func _ready():
	# TouchRouter handles unhandled input
	set_process_unhandled_input(true)

#endregion

#region Input Processing

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Touch start
		_gesture_state = {
			start_pos = event.position,
			start_time = Time.get_ticks_msec(),
			target = _find_hit_node(event.position),
		}
	else:
		# Touch end - determine gesture
		if _gesture_state.is_empty():
			return

		var duration: int = Time.get_ticks_msec() - _gesture_state.start_time
		var distance: float = event.position.distance_to(_gesture_state.start_pos)

		var target_name: String = _gesture_state.get("target", "")
		if target_name.is_empty():
			target_name = "screen"

		# Gesture classification
		if duration < TAP_DURATION_MAX and distance < SWIPE_DISTANCE_MIN:
			emit_signal("touch_tap", event.position, target_name)
			# Check if target is Button (emit button_clicked)
			if _is_button(_gesture_state.target):
				emit_signal("button_clicked", event.position)

		elif duration >= HOLD_DURATION_MIN and distance < SWIPE_DISTANCE_MIN:
			emit_signal("touch_hold", event.position, target_name)

		elif distance >= SWIPE_DISTANCE_MIN:
			emit_signal("touch_swipe", _gesture_state.start_pos, event.position)

		_gesture_state.clear()

func _handle_drag(event: InputEventScreenDrag) -> void:
	# Drag tracking for potential swipe
	if not _gesture_state.is_empty():
		_gesture_state.current_pos = event.position

#endregion

#region Internal

func _find_hit_node(position: Vector2) -> Control:
	## Find topmost node containing position in active layer
	var nodes: Array = _layer_nodes.get(_active_layer, [])

	for node in nodes:
		if node is Control:
			var rect: Rect2 = node.get_global_rect()
			if rect.has_point(position):
				return node

	return null

func _is_button(node: Control) -> bool:
	## Check if node is a Button type
	if node == null:
		return false
	return node is Button

#endregion