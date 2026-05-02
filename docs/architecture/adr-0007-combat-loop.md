# ADR-0007: Combat Loop Architecture

## Status
Accepted

## Context
Auto-battle idle game requires timer-driven combat loop. GDD defines:
- HITS_PER_SECOND = 2.0 (hit frequency)
- Damage variance 0.9-1.1 (random multiplier)
- Skip mechanism compresses timeline to 0.3s batches
- Combat state machine: IDLE → COMBAT → VICTORY/DEFEAT

Key constraints:
- Timer-based, not frame-based (consistent speed)
- Skip must compress, not skip rewards
- Performance budget: combat updates minimal per-frame

## Decision

### Timer-Driven Loop

```gdscript
class_name CombatEngine extends Node

enum State { IDLE, COMBAT, SKIPPING, VICTORY, DEFEATED }

var _state: State = State.IDLE
var _hit_timer: Timer
var _enemy: Dictionary
var _player_stats: Dictionary
var _damage_queue: Array

const HITS_PER_SECOND: float = 2.0
const HIT_INTERVAL: float = 1.0 / HITS_PER_SECOND  # 0.5 seconds per hit

func _ready():
    _hit_timer = Timer.new()
    _hit_timer.wait_time = HIT_INTERVAL
    _hit_timer.one_shot = false
    _hit_timer.timeout.connect(_on_hit_timer)
    add_child(_hit_timer)

func start_battle(enemy: Dictionary) -> void:
    _enemy = enemy
    _player_stats = EquipmentManager.get_total_stats()
    _state = State.COMBAT
    _hit_timer.start()
    emit_signal("battle_started", enemy)
```

### Damage Calculation Pattern

```gdscript
func calculate_damage(attacker: Dictionary, defender: Dictionary) -> int:
    # Base damage = attacker power - defender defense (floor at 1)
    var base: int = max(1, attacker.power - defender.defense)
    
    # Apply variance (0.9 to 1.1)
    var variance: float = randf_range(0.9, 1.1)
    var final_damage: int = floor(base * variance)
    
    return final_damage

func _on_hit_timer() -> void:
    if _state != State.COMBAT and _state != State.SKIPPING:
        return
    
    var damage: int = calculate_damage(_player_stats, _enemy)
    _enemy.current_hp -= damage
    
    emit_signal("damage_dealt", damage, _enemy.id)
    emit_signal("enemy_health_changed", _enemy.id, _enemy.current_hp)
    
    if _enemy.current_hp <= 0:
        _end_battle(State.VICTORY)
```

### Skip Mechanism

```gdscript
func skip_battle() -> void:
    if _state != State.COMBAT:
        return
    
    _state = State.SKIPPING
    _hit_timer.stop()
    
    # Calculate remaining hits needed to defeat enemy
    var remaining_hp: int = _enemy.current_hp
    var avg_damage: int = calculate_damage(_player_stats, _enemy)  # Use base damage
    var hits_needed: int = ceil(remaining_hp / avg_damage)
    
    # Compress timeline: batch hits in 0.3s intervals
    var batch_timer: Timer = Timer.new()
    batch_timer.wait_time = 0.3
    batch_timer.one_shot = true
    batch_timer.timeout.connect(_process_skip_batch.bind(hits_needed))
    add_child(batch_timer)
    batch_timer.start()

func _process_skip_batch(remaining_hits: int) -> void:
    # Process multiple hits at once
    var batch_size: int = min(5, remaining_hits)  # 5 hits per batch
    
    for i in range(batch_size):
        var damage: int = calculate_damage(_player_stats, _enemy)
        _enemy.current_hp -= damage
        emit_signal("damage_dealt", damage, _enemy.id)
    
    if _enemy.current_hp <= 0:
        _end_battle(State.VICTORY)
    else:
        # Continue next batch
        var new_remaining: int = remaining_hits - batch_size
        var next_timer: Timer = Timer.new()
        next_timer.wait_time = 0.3
        next_timer.one_shot = true
        next_timer.timeout.connect(_process_skip_batch.bind(new_remaining))
        add_child(next_timer)
        next_timer.start()
```

### Constants

```gdscript
const HITS_PER_SECOND: float = 2.0
const SKIP_BATCH_INTERVAL: float = 0.3
const SKIP_BATCH_SIZE: int = 5
const DAMAGE_VARIANCE_MIN: float = 0.9
const DAMAGE_VARIANCE_MAX: float = 1.1
```

## Consequences

### Positive
- Timer-driven ensures consistent combat speed across devices
- Skip compresses time but preserves all hits/rewards
- Variance adds visual variety without changing average outcome

### Negative
- Skip creates multiple Timer instances (cleanup needed)
- Damage variance requires RNG (stateless, but affects determinism for testing)

### Risks
- **Timer precision**: Mobile timers may drift slightly — acceptable for idle game
- **Skip visual overload**: Fast damage events may overwhelm feedback system
  - Mitigation: FeedbackCoordinator has queue_limit, won't spawn unlimited particles

## ADR Dependencies
- ADR-0002 (Signal Architecture — damage_dealt, enemy_health_changed signals)
- ADR-0011 (Item Registry — EquipmentManager.get_total_stats())

## Engine Compatibility

| Domain | Engine Version | Risk | Verified |
|--------|---------------|------|----------|
| Timer | Godot 4.x | LOW | ✅ stable |
| randf_range | Godot 4.x | LOW | ✅ stable |

## GDD Requirements Addressed

| TR ID | Requirement | Decision |
|-------|-------------|----------|
| TR-combat-001 | Timer-driven combat loop | Timer.wait_time = HIT_INTERVAL (0.5s), HITS_PER_SECOND=2.0 |
| TR-combat-002 | Damage variance formula | randf_range(0.9, 1.1), floor(base * variance) |
| TR-combat-003 | Skip mechanism compression | 0.3s batches, 5 hits per batch, all rewards preserved |