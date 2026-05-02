# ADR-0002: Signal Architecture Pattern

## Status
Accepted

## Context
24 systems need to communicate across layers. GDDs define 17+ signals for game events. Godot provides built-in signal system. Two common patterns:
- **Direct subscription**: Node A.signal.connect(Node B.callback)
- **EventBus singleton**: Global object with signals, all nodes subscribe

Key constraints:
- Mobile performance budget (60fps, 16.6ms frame)
- GDDs already define signal names (snake_case past tense)
- Debugging needs to trace signal flow

## Decision

### Pattern: Direct Node-to-Node Subscription

**NO global EventBus singleton.** Each module owns its signals and exposes them to specific subscribers.

```gdscript
# Correct pattern (owner emits, subscriber connects)
class_name CombatEngine extends Node

signal damage_dealt(damage: int, target_id: String)
signal battle_started(enemy_data: Dictionary)

func _ready():
    # Owner does NOT connect its own signals
    # Consumers connect at their own _ready()
    pass

# Consumer subscribes directly
class_name FeedbackCoordinator extends Node

func _ready():
    var combat := %CombatEngine
    combat.damage_dealt.connect(_on_damage_dealt)

func _on_damage_dealt(damage: int, target_id: String):
    trigger_feedback("hit", damage_tier, {...})
```

### Signal Naming Convention

From GDDs, confirmed convention:
- **snake_case past tense**: `damage_dealt`, `enemy_defeated`, `enhancement_complete`
- **Exception**: State changes use `-ed` suffix: `floor_advanced`, `battle_started`
- **Payload**: Named parameters in signal definition (typed signals preferred)

### Connection Timing

- **Connection in subscriber's _ready()**: NOT in emitter's _ready()
- **Rationale**: Subscriber explicitly declares dependency, easier to trace
- **Disconnect on cleanup**: `signal.disconnect(callback)` before node removal

### Layer Crossing

Signals may cross layers UPWARD (Feature → Presentation) but NOT downward (Presentation → Feature).

```
Allowed:
  CombatEngine (Feature) → damage_dealt → FeedbackCoordinator (Presentation)

Forbidden:
  FeedbackCoordinator → trigger_x → CombatEngine  # Presentation should not command Feature
```

**Exception**: UI controls (TouchRouter → button_clicked → AudioPool) is horizontal within UI domain.

## Consequences

### Positive
- Typed signals with named parameters (GDScript 4.x)
- Dependencies visible in subscriber code (explicit connection)
- No hidden global dependencies (EventBus hides who listens)
- Debuggable: Godot debugger shows signal connections

### Negative
- Subscriber must know emitter node reference (requires scene tree awareness)
- Cannot broadcast to "anyone listening" (must know specific targets)
- Connection management in subscriber adds code

### Risks
- **Circular signal chains**: FeedbackCoordinator triggers event that loops back
  - Mitigation: Signals flow UPWARD only, no circular paths in architecture
- **Disconnected nodes leaking**: Old connections persist if node not properly freed
  - Mitigation: Use `queue_free()` or explicit disconnect in `_notification(NOTIFICATION_PREDELETE)`

## ADR Dependencies
- None (Foundation layer)

## Engine Compatibility

| Domain | Engine Version | Risk | Verified |
|--------|---------------|------|----------|
| Signal API | Godot 4.x | LOW | ✅ stable |
| Typed signals | Godot 4.2+ | LOW | ✅ stable |

## GDD Requirements Addressed

| TR ID | Requirement | Decision |
|-------|-------------|----------|
| TR-signal-001 | Signal naming convention | snake_case past tense, from GDDs |
| TR-signal-002 | Direct subscription vs EventBus | Direct subscription, no singleton |