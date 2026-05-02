# ADR-0003: Particle System Pooling

## Status
Accepted

## Context
Visual feedback system requires particle effects for game events (hit, gold burst, victory, enhancement). Performance budget: 60fps, 50-100 draw calls, 200 max active particles. Target: mobile (iOS/Android).

Key constraints:
- GPUParticles2D in Godot 4.x
- 5 presets defined in GDD: Gold Burst, Enhancement Flash, Victory Sparkle, Hit Flash, Level Up
- Tier system (1-6) scales intensity
- Godot 4.4 added `.restart(keep_seed)` parameter (MEDIUM risk)

## Decision

### Pool Strategy: Pre-instantiated Pool

**NO runtime spawning.** Create particle instances at boot, reuse for all spawns.

```gdscript
class_name ParticlePool extends Node

const POOL_SIZE: int = 8  # 8 GPUParticles2D instances

var _pool: Array[GPUParticles2D] = []
var _preset_configs: Dictionary = {}  # Loaded from resource
var _active: Dictionary = {}  # {preset_name: [active_instances]}

func _ready():
    # Pre-create all instances
    for i in range(POOL_SIZE):
        var particles := GPUParticles2D.new()
        particles.emitting = false
        particles.one_shot = true  # Auto-stop after burst
        add_child(particles)
        _pool.append(particles)
    
    # Load preset configs
    _preset_configs = load("res://data/particle_presets.tres").data
```

### Preset Configuration Format

Stored as Resource file: `res://data/particle_presets.tres`

```gdscript
# Each preset: {texture, amount_curve, scale_curve, color_curve, lifetime, explosiveness}
{
    "Gold Burst": {
        texture: preload("res://assets/vfx/gold_particle.png"),
        amount_curve: Curve.new(),  # Tier 1=10, Tier 6=200
        lifetime: 0.8,
        explosiveness: 0.8
    },
    "Hit Flash": {
        texture: preload("res://assets/vfx/hit_flash.png"),
        amount_curve: Curve.new(),
        lifetime: 0.3,
        explosiveness: 1.0  # Instant burst
    },
    ...
}
```

### Spawn Pattern

```gdscript
func spawn_preset(preset_name: String, position: Vector2, tier: int) -> void:
    # Find idle instance from pool
    for particles in _pool:
        if not particles.emitting:
            # Apply preset config
            var config: Dictionary = _preset_configs[preset_name]
            particles.texture = config.texture
            particles.amount = config.amount_curve.sample(tier / 6.0)
            particles.lifetime = config.lifetime
            particles.position = position
            particles.emitting = true
            _active[preset_name].append(particles)
            return
    
    # Pool exhausted: reuse oldest active instance
    var oldest: GPUParticles2D = _active[preset_name].pop_front()
    oldest.restart(keep_seed = false)  # 4.4+ parameter
    oldest.position = position
```

### .restart() Parameter (Godot 4.4 MEDIUM Risk)

```gdscript
# Godot 4.4+ has keep_seed parameter
particles.restart(keep_seed = false)  # New random seed each restart

# Why false: We want varied particle appearance each spawn
# If true: Same seed = identical particle positions (used for looping effects)
```

### Layered Feedback Support

GDD defines `layer_delay` for composite events (e.g., Victory Sparkle then Gold Burst 300ms later).

```gdscript
func set_layer_delay(preset_name: String, delay_ms: float) -> void:
    # Queue delayed spawn
    var timer := Timer.new()
    timer.wait_time = delay_ms / 1000.0
    timer.one_shot = true
    timer.timeout.connect(func(): spawn_preset(preset_name, position, tier))
    add_child(timer)
    timer.start()
```

## Consequences

### Positive
- Zero runtime allocation (pool pre-created)
- Deterministic memory usage (8 instances × particle config)
- Fast spawn (no new node creation)
- 4.4 parameter handled correctly

### Negative
- Fixed pool size (8 may limit concurrent presets)
- Preset configs require tuning (amount curves per tier)
- Layered delay adds Timer overhead

### Risks
- **Pool exhaustion**: More than 8 concurrent presets
  - Mitigation: Reuse oldest instance (visual degradation acceptable)
- **Glow 4.6 change**: Glow processes before tonemapping
  - Mitigation: Particle shaders use standard emission, glow handled by engine post-process

## ADR Dependencies
- None (Foundation layer)

## Engine Compatibility

| Domain | Engine Version | Risk | Verified |
|--------|---------------|------|----------|
| GPUParticles2D | Godot 4.x | LOW | ✅ stable |
| .restart(keep_seed) | Godot 4.4+ | MEDIUM | ✅ breaking-changes.md |
| Glow pipeline | Godot 4.6 | MEDIUM | ✅ rendering.md |

## GDD Requirements Addressed

| TR ID | Requirement | Decision |
|-------|-------------|----------|
| TR-particle-001 | GPUParticles2D pooling strategy | Pre-instantiated pool (8 instances) |
| TR-particle-002 | Particle preset configuration | Resource file with curves per tier |
| TR-particle-003 | .restart(keep_seed) usage | keep_seed=false for varied appearance |