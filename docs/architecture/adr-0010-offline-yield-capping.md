# ADR-0010: Offline Yield Capping

## Status
Accepted

## Context
Offline rewards must be capped to prevent:
- Excessive accumulation from extended absence
- Time cheating (system clock manipulation)
- Server sync issues (this game is offline-only)

GDD defines:
- MAX_ALLOWED_OFFLINE = 86400s (24 hours max yield)
- MAX_FORWARD_JUMP = 7 days (anomaly threshold)
- MAX_OFFLINE_MATERIAL_STACK = 500 (material cap)

## Decision

### Dual-Source Time Pattern

```gdscript
class_name TimeTracker extends Node

var _session_start: int  # Time.get_ticks_usec() at boot
var _last_save_time: int  # OS.get_system_time_msecs() from save file
var _anomaly_log: Array

const MAX_ALLOWED_OFFLINE: int = 86400  # 24 hours in seconds
const MAX_FORWARD_JUMP: int = 604800  # 7 days in seconds
const MAX_OFFLINE_MATERIAL_STACK: int = 500

func _ready():
    _session_start = Time.get_ticks_usec()

func get_offline_duration() -> float:
    var current_system_time: int = OS.get_system_time_msecs()
    var raw_offline_ms: int = current_system_time - _last_save_time
    var raw_offline_seconds: float = raw_offline_ms / 1000.0
    
    # Check for anomaly
    if detect_anomaly(raw_offline_seconds):
        log_anomaly("forward_jump")
        return MAX_ALLOWED_OFFLINE  # Cap to 24h
    
    # Cap to MAX_ALLOWED_OFFLINE
    return min(raw_offline_seconds, MAX_ALLOWED_OFFLINE)

func detect_anomaly(raw_duration: float) -> bool:
    # Forward jump: offline > 7 days
    if raw_duration > MAX_FORWARD_JUMP:
        return true
    
    # Backward jump: negative duration (clock moved backward)
    if raw_duration < 0:
        log_anomaly("backward_jump")
        return true
    
    return false

func log_anomaly(type: String) -> void:
    _anomaly_log.append({
        type = type,
        timestamp = Time.get_datetime_string_from_system(),
        raw_duration = raw_duration,
    })
```

### Yield Calculation with Caps

```gdscript
class_name YieldEstimator

static func estimate_yield(duration: float, floor: int) -> Dictionary:
    # Cap duration first
    var capped_duration: float = min(duration, TimeTracker.MAX_ALLOWED_OFFLINE)
    
    # Calculate gold yield (per-second rate from combat system)
    var gold_per_second: float = 10.0  # From combat system average
    var gold_yield: int = floori(gold_per_second * capped_duration)
    
    # Calculate material yield with stack cap
    var material_per_second: float = 0.5  # Average drop rate
    var raw_material_yield: int = floori(material_per_second * capped_duration)
    var capped_material_yield: int = min(raw_material_yield, TimeTracker.MAX_OFFLINE_MATERIAL_STACK)
    
    return {
        gold = gold_yield,
        enhancement_stone = capped_material_yield,
    }
```

### Constants

```gdscript
const MAX_ALLOWED_OFFLINE: int = 86400  # seconds (24h)
const MAX_FORWARD_JUMP: int = 604800  # seconds (7 days)
const MAX_OFFLINE_MATERIAL_STACK: int = 500
```

## Consequences

### Positive
- Dual-source time prevents simple clock manipulation
- Anomaly logging provides audit trail for debugging
- Material cap prevents hoarding

### Negative
- Determined players can still exploit (dual-source only heuristic)
- Material cap may frustrate players returning after genuine long absence

### Risks
- **Time API stability**: Time.get_ticks_usec() is monotonic (stable)
- **OS.get_system_time_msecs()**: System clock, may be modified by user

## ADR Dependencies
- None (Foundation layer — TimeTracker owns time state)

## Engine Compatibility

| Domain | Engine Version | Risk | Verified |
|--------|---------------|------|----------|
| Time API | Godot 4.x | LOW | ✅ stable |
| OS API | Godot 4.x | LOW | ✅ stable |

## GDD Requirements Addressed

| TR ID | Requirement | Decision |
|-------|-------------|----------|
| TR-offline-001 | Offline duration capping | MAX_ALLOWED_OFFLINE=86400s, anomaly detection at 7 days |
| TR-offline-002 | Offline material stack cap | MAX_OFFLINE_MATERIAL_STACK=500, min(raw, cap) |