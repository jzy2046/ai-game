# ADR-0008: Enemy State Machine

## Status
Accepted

## Context
Enemy lifecycle requires state transitions with timing. GDD defines:
- States: SPAWNING → ALIVE → DEFEATED
- SPAWNING duration: 0.3s (entrance animation)
- DEFEATED duration: 0.5s (death animation before rewards)
- Rewards emitted on DEFEATED transition completion

## Decision

### State Enum Pattern

```gdscript
class_name EnemyController extends Node

enum EnemyState { SPAWNING, ALIVE, DEFEATED }

var _active_enemies: Dictionary = {}  # {enemy_id: {state, timer, data}}
var _state_timers: Dictionary = {
    EnemyState.SPAWNING: 0.3,
    EnemyState.DEFEATED: 0.5,
}

const SPAWNING_DURATION: float = 0.3
const DEFEATED_DURATION: float = 0.5
```

### Spawn Pattern

```gdscript
func spawn_enemy(floor: int) -> Dictionary:
    var enemy_id: String = "enemy_%d_%d" % [floor, randi()]
    
    # Calculate stats from floor
    var recommended_power: int = 100 + floor * 50  # From GDD
    var enemy_data: Dictionary = {
        id = enemy_id,
        floor = floor,
        recommended_power = recommended_power,
        current_hp = recommended_power * 2,  # HP = 2× power
        max_hp = recommended_power * 2,
        state = EnemyState.SPAWNING,
        rewards = _calculate_rewards(floor),
    }
    
    _active_enemies[enemy_id] = enemy_data
    
    # Start SPAWNING timer
    var spawn_timer: Timer = Timer.new()
    spawn_timer.wait_time = SPAWNING_DURATION
    spawn_timer.one_shot = true
    spawn_timer.timeout.connect(_on_spawn_complete.bind(enemy_id))
    add_child(spawn_timer)
    spawn_timer.start()
    
    return enemy_data
```

### State Transition Pattern

```gdscript
func _on_spawn_complete(enemy_id: String) -> void:
    var enemy: Dictionary = _active_enemies[enemy_id]
    enemy.state = EnemyState.ALIVE
    emit_signal("enemy_state_changed", enemy_id, EnemyState.ALIVE)

func defeat_enemy(enemy_id: String) -> Dictionary:
    var enemy: Dictionary = _active_enemies[enemy_id]
    
    if enemy.state != EnemyState.ALIVE:
        push_error("Cannot defeat enemy not in ALIVE state: " + enemy_id)
        return {}
    
    enemy.state = EnemyState.DEFEATED
    
    # Start DEFEATED timer before rewards
    var defeat_timer: Timer = Timer.new()
    defeat_timer.wait_time = DEFEATED_DURATION
    defeat_timer.one_shot = true
    defeat_timer.timeout.connect(_on_defeat_complete.bind(enemy_id))
    add_child(defeat_timer)
    defeat_timer.start()
    
    return {}  # Rewards emitted on timer completion

func _on_defeat_complete(enemy_id: String) -> void:
    var enemy: Dictionary = _active_enemies[enemy_id]
    emit_signal("enemy_defeated", enemy_id, enemy.rewards)
    _active_enemies.erase(enemy_id)  # Cleanup
```

### State Query API

```gdscript
func get_enemy_state(enemy_id: String) -> int:
    if not _active_enemies.has(enemy_id):
        return -1  # Not found
    return _active_enemies[enemy_id].state
```

### Constants

```gdscript
const SPAWNING_DURATION: float = 0.3  # seconds
const DEFEATED_DURATION: float = 0.5  # seconds
const BASE_ENEMY_POWER: int = 100
const POWER_INCREMENT: int = 50  # per floor
```

## Consequences

### Positive
- Timer-based transitions ensure consistent animation timing
- Rewards emit after DEFEATED animation (player sees death before reward)
- State enum prevents invalid state transitions

### Negative
- Timer instances created per enemy (cleanup on defeat)
- State stored in Dictionary (not typed, but flexible)

### Risks
- None — Timer and state enum patterns are standard Godot

## ADR Dependencies
- ADR-0002 (Signal Architecture — enemy_defeated, enemy_state_changed signals)

## Engine Compatibility

| Domain | Engine Version | Risk | Verified |
|--------|---------------|------|----------|
| Timer | Godot 4.x | LOW | ✅ stable |

## GDD Requirements Addressed

| TR ID | Requirement | Decision |
|-------|-------------|----------|
| TR-state-001 | Enemy state machine | Enum {SPAWNING, ALIVE, DEFEATED} with transition rules |
| TR-state-002 | State transition timing | SPAWNING=0.3s, DEFEATED=0.5s, rewards after timer |