# ADR-0005: UI Anchor and Safe Area Strategy

## Status
Accepted

## Context
Mobile game (iOS/Android) in portrait orientation. UI must adapt to:
- Multiple screen sizes (iPhone SE to iPad)
- Notches and dynamic islands (iOS)
- Status bars and gesture areas (Android)
- Safe area varies per device

Godot 4.x provides Control anchors and DisplayServer.get_safe_area(). Performance budget allows UI rendering but no expensive layout recalculations per frame.

## Decision

### Anchor Preset Strategy

Pre-defined anchor presets applied at boot, no runtime anchor recalculation.

```gdscript
class_name UILayoutManager extends Node

enum AnchorPreset {
    TOP_LEFT,
    TOP_RIGHT,
    BOTTOM_LEFT,
    BOTTOM_RIGHT,
    CENTER,
    TOP_CENTER,
    BOTTOM_CENTER,
    LEFT_CENTER,
    RIGHT_CENTER,
    FILL,  # Stretch to parent
}

var _presets: Dictionary = {
    AnchorPreset.TOP_LEFT: {
        anchor_left = 0.0, anchor_top = 0.0,
        anchor_right = 0.0, anchor_bottom = 0.0,
        grow_horizontal = Control.GROW_DIRECTION_BEGIN,
        grow_vertical = Control.GROW_DIRECTION_BEGIN,
    },
    AnchorPreset.TOP_RIGHT: {
        anchor_left = 1.0, anchor_top = 0.0,
        anchor_right = 1.0, anchor_bottom = 0.0,
        grow_horizontal = Control.GROW_DIRECTION_END,
        grow_vertical = Control.GROW_DIRECTION_BEGIN,
    },
    AnchorPreset.BOTTOM_CENTER: {
        anchor_left = 0.5, anchor_top = 1.0,
        anchor_right = 0.5, anchor_bottom = 1.0,
        grow_horizontal = Control.GROW_DIRECTION_BOTH,
        grow_vertical = Control.GROW_DIRECTION_END,
    },
    ...
}
```

### Apply Anchor Pattern

```gdscript
func apply_anchor(node: Control, preset: AnchorPreset) -> void:
    var config: Dictionary = _presets[preset]
    node.set_anchor(SIDE_LEFT, config.anchor_left)
    node.set_anchor(SIDE_TOP, config.anchor_top)
    node.set_anchor(SIDE_RIGHT, config.anchor_right)
    node.set_anchor(SIDE_BOTTOM, config.anchor_bottom)
    node.set_grow_direction(SIDE_HORIZONTAL, config.grow_horizontal)
    node.set_grow_direction(SIDE_VERTICAL, config.grow_vertical)

func apply_anchor_preset_name(node: Control, preset_name: String) -> void:
    # Convenience wrapper using Godot's built-in preset names
    # preset_name: "top_left", "center", "bottom_right", etc.
    node.set_anchors_preset(Control.PRESET_TOP_LEFT)  # etc.
```

### Safe Area Handling

```gdscript
var _safe_area: Rect2
var _screen_size: Vector2

func _ready():
    _screen_size = DisplayServer.screen_get_size(0)
    _safe_area = DisplayServer.get_safe_area(0)
    
    # Emit signal for UI to adapt
    emit_signal("safe_area_updated", _safe_area)

func get_safe_area() -> Rect2:
    return _safe_area

func get_safe_area_margins() -> Dictionary:
    # Returns margins to apply to root UI container
    return {
        top = _safe_area.position.y,
        bottom = _screen_size.y - (_safe_area.position.y + _safe_area.size.y),
        left = _safe_area.position.x,
        right = _screen_size.x - (_safe_area.position.x + _safe_area.size.x),
    }
```

### Root UI Container Pattern

```gdscript
# Main UI scene: SafeAreaContainer (full screen) → Actual UI nodes
class_name SafeAreaContainer extends Control

func _ready():
    var margins: Dictionary = UILayoutManager.get_safe_area_margins()
    
    # Apply margins as offsets from screen edges
    # This pushes content away from notch/status bar
    offset_top = margins.top
    offset_bottom = -margins.bottom  # Negative = push up from bottom
    offset_left = margins.left
    offset_right = -margins.right
```

### Screen Orientation

Game is portrait-only. No orientation change handling needed.

```gdscript
func get_screen_orientation() -> String:
    # Always "portrait" for this game
    return "portrait"
```

### Layout Update Timing

Safe area queried at boot only (does not change during session on mobile). Anchor presets applied at node creation (not per-frame).

## Consequences

### Positive
- One-time layout calculation (no per-frame overhead)
- Safe area handling prevents notch overlap
- Preset system simplifies node setup
- Portrait-only reduces complexity

### Negative
- No orientation change support (acceptable per GDD)
- Preset names must match UI design (requires coordination)
- Safe area may vary across devices (tested via margins)

### Risks
- **DisplayServer API**: Stable since Godot 4.0 ✅
- **iOS dynamic island**: Safe area updates correctly via DisplayServer
- **Android gesture bar**: Safe area includes gesture zone

## ADR Dependencies
- None (Foundation layer)

## Engine Compatibility

| Domain | Engine Version | Risk | Verified |
|--------|---------------|------|----------|
| Control anchors | Godot 4.x | LOW | ✅ stable |
| DisplayServer | Godot 4.x | LOW | ✅ stable |

## GDD Requirements Addressed

| TR ID | Requirement | Decision |
|-------|-------------|----------|
| TR-ui-001 | Anchor preset application | Preset enum + apply_anchor() |
| TR-ui-002 | Safe area handling | DisplayServer.get_safe_area() + margins |