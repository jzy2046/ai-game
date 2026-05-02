# ADR-0006: Touch Input Routing

## Status
Accepted

## Context
Mobile touch-only game requires gesture detection and layer routing for UI events. GDD defines thresholds:
- TAP_DURATION_MAX = 300ms
- HOLD_DURATION_MIN = 500ms
- SWIPE_DISTANCE_MIN = 30px

TouchRouter must handle:
- Layer priority (game=0, popup=1, modal=2)
- Modal blocking (lower layers blocked when modal active)
- Gesture differentiation (tap, hold, swipe)
- Button detection (emit button_clicked when target is Control node)

## Decision

### Layer Routing Architecture

```gdscript
class_name TouchRouter extends Node

enum Layer { GAME = 0, POPUP = 1, MODAL = 2 }

var _active_layer: Layer = Layer.GAME
var _modal_stack: Array[Control] = []
var _layer_nodes: Dictionary = {
    Layer.GAME: [],
    Layer.POPUP: [],
    Layer.MODAL: [],
}
```

### Touch Processing Pattern

```gdscript
func _input(event: InputEvent) -> void:
    if not event is InputEventScreenTouch and not event is InputEventScreenDrag:
        return
    
    # Block lower layers if modal active
    var target_nodes: Array = _layer_nodes[_active_layer]
    
    if event is InputEventScreenTouch:
        if event.pressed:
            _handle_touch_press(event.position, target_nodes)
        else:
            _handle_touch_release(event.position, target_nodes)

func _handle_touch_press(pos: Vector2, nodes: Array) -> void:
    # Find topmost node containing pos
    var hit_node: Control = _find_hit_node(pos, nodes)
    
    # Record gesture start
    _gesture_state = {
        start_pos = pos,
        start_time = Time.get_ticks_msec(),
        target = hit_node,
    }

func _handle_touch_release(pos: Vector2, nodes: Array) -> void:
    var duration: int = Time.get_ticks_msec() - _gesture_state.start_time
    var distance: float = pos.distance_to(_gesture_state.start_pos)
    
    # Determine gesture type
    if duration < TAP_DURATION_MAX and distance < SWIPE_DISTANCE_MIN:
        emit_signal("touch_tap", pos, _gesture_state.target.name)
        if _gesture_state.target is Button:
            emit_signal("button_clicked", pos)
    elif duration >= HOLD_DURATION_MIN and distance < SWIPE_DISTANCE_MIN:
        emit_signal("touch_hold", pos, _gesture_state.target.name)
    elif distance >= SWIPE_DISTANCE_MIN:
        emit_signal("touch_swipe", _gesture_state.start_pos, pos)
```

### Modal Blocking Pattern

```gdscript
func push_modal(modal: Control) -> void:
    _modal_stack.append(modal)
    _active_layer = Layer.MODAL
    _layer_nodes[Layer.MODAL] = [modal]

func pop_modal() -> void:
    _modal_stack.pop_back()
    if _modal_stack.size() > 0:
        _active_layer = Layer.MODAL
        _layer_nodes[Layer.MODAL] = [_modal_stack.back()]
    else:
        _active_layer = Layer.GAME
```

### Constants (from GDD)

```gdscript
const TAP_DURATION_MAX: int = 300  # ms
const HOLD_DURATION_MIN: int = 500  # ms
const SWIPE_DISTANCE_MIN: float = 30.0  # pixels
```

## Consequences

### Positive
- Layer priority prevents accidental touch-through
- Modal stack supports nested modals (modal on modal)
- Gesture thresholds from GDD ensure consistent feel

### Negative
- Fixed 3 layers (extensible but requires code change)
- Button detection requires node type check (runtime cost minimal)

### Risks
- None — Input API stable in Godot 4.x

## ADR Dependencies
- ADR-0002 (Signal Architecture — touch_tap/button_clicked signal naming)

## Engine Compatibility

| Domain | Engine Version | Risk | Verified |
|--------|---------------|------|----------|
| InputEvent | Godot 4.x | LOW | ✅ input.md |
| Control | Godot 4.x | LOW | ✅ ui.md |

## GDD Requirements Addressed

| TR ID | Requirement | Decision |
|-------|-------------|----------|
| TR-input-001 | Touch gesture thresholds | TAP_DURATION_MAX=300ms, HOLD_DURATION_MIN=500ms, SWIPE_DISTANCE_MIN=30px |
| TR-input-002 | Layer routing | 3-layer enum with priority, _active_layer determines hit targets |
| TR-input-003 | Modal blocking | push_modal/pop_modal updates _active_layer, blocks lower layers |