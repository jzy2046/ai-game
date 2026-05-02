extends Node
class_name ParticlePool

## ParticlePool - Foundation Layer
## Implements: ADR-0003 Particle System Pooling
## TR IDs: TR-particle-001, TR-particle-002, TR-particle-003

## Signals
signal particle_spawned(preset: String, position: Vector2, tier: int)

## Constants
const POOL_SIZE: int = 8
const MAX_TIER: int = 6

## Preset names
const PRESET_GOLD_BURST: String = "Gold Burst"
const PRESET_ENHANCEMENT_FLASH: String = "Enhancement Flash"
const PRESET_VICTORY_SPARKLE: String = "Victory Sparkle"
const PRESET_HIT_FLASH: String = "Hit Flash"
const PRESET_LEVEL_UP: String = "Level Up"

## State
var _pool: Array[GPUParticles2D] = []
var _preset_configs: Dictionary = {}
var _active_presets: Dictionary = {}  # {preset_name: [instances]}
var _layer_delays: Dictionary = {}

#region Public API

func spawn_preset(preset_name: String, position: Vector2, tier: int) -> void:
	## Spawn particle effect at position with intensity tier (1-6)
	tier = clampi(tier, 1, MAX_TIER)

	# Find idle instance from pool
	for particles in _pool:
		if not particles.emitting:
			_apply_preset(particles, preset_name, tier)
			particles.position = position
			particles.emitting = true

			# Track active
			if not _active_presets.has(preset_name):
				_active_presets[preset_name] = []
			_active_presets[preset_name].append(particles)

			emit_signal("particle_spawned", preset_name, position, tier)
			return

	# Pool exhausted - reuse oldest
	push_warning("Particle pool exhausted for preset: %s" % preset_name)
	if _active_presets.has(preset_name) and _active_presets[preset_name].size() > 0:
		var oldest: GPUParticles2D = _active_presets[preset_name].pop_front()
		oldest.restart(false)  # Godot 4.4+ keep_seed=false
		_apply_preset(oldest, preset_name, tier)
		oldest.position = position
		oldest.emitting = true
		_active_presets[preset_name].append(oldest)

func clear_all() -> void:
	## Stop all active particles
	for particles in _pool:
		particles.emitting = false
	for preset in _active_presets:
		_active_presets[preset].clear()

func set_layer_delay(preset_name: String, delay_ms: float) -> void:
	## Set delay for layered feedback events
	_layer_delays[preset_name] = delay_ms / 1000.0

#endregion

#region Lifecycle

func _ready():
	_create_pool()
	_setup_presets()

#endregion

#region Internal

func _create_pool() -> void:
	## Pre-instantiate GPUParticles2D pool
	for i in range(POOL_SIZE):
		var particles := GPUParticles2D.new()
		particles.emitting = false
		particles.one_shot = true
		particles.amount = 10
		particles.lifetime = 0.5
		particles.explosiveness = 0.8
		add_child(particles)
		_pool.append(particles)

func _setup_presets() -> void:
	## Configure preset defaults
	# Note: Full preset configs would load from resource file
	# MVP: Hardcoded defaults for each preset type
	_preset_configs = {
		PRESET_GOLD_BURST: {
			amount_curve = [10, 50, 100, 150, 200, 250],
			lifetime = 0.8,
			explosiveness = 0.8,
			color = Color.GOLD,
		},
		PRESET_ENHANCEMENT_FLASH: {
			amount_curve = [20, 40, 60, 80, 100, 120],
			lifetime = 0.3,
			explosiveness = 1.0,
			color = Color(0.5, 0.8, 1.0),  # Blue glow
		},
		PRESET_VICTORY_SPARKLE: {
			amount_curve = [30, 60, 90, 120, 150, 180],
			lifetime = 1.0,
			explosiveness = 0.5,
			color = Color(1.0, 0.9, 0.5),  # Yellow sparkle
		},
		PRESET_HIT_FLASH: {
			amount_curve = [5, 10, 15, 20, 25, 30],
			lifetime = 0.2,
			explosiveness = 1.0,
			color = Color.WHITE,
		},
		PRESET_LEVEL_UP: {
			amount_curve = [40, 80, 120, 160, 200, 240],
			lifetime = 1.5,
			explosiveness = 0.6,
			color = Color(0.2, 1.0, 0.2),  # Green
		},
	}

func _apply_preset(particles: GPUParticles2D, preset_name: String, tier: int) -> void:
	## Apply preset configuration to particle instance
	var config: Dictionary = _preset_configs.get(preset_name, {})
	if config.is_empty():
		return

	# Amount from tier curve
	var amount_curve: Array = config.get("amount_curve", [10])
	var amount: int = amount_curve[mini(tier - 1, amount_curve.size() - 1)]
	particles.amount = amount

	# Other properties
	particles.lifetime = config.get("lifetime", 0.5)
	particles.explosiveness = config.get("explosiveness", 0.8)

	# Color via modulate
	var color: Color = config.get("color", Color.WHITE)
	particles.modulate = color

#endregion