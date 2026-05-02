extends Node
class_name EnemyController

## EnemyController - Core Layer
## Implements: ADR-0008 Enemy State Machine
## TR IDs: TR-state-001, TR-state-002

## Signals
signal enemy_spawned(enemy_id: String, enemy_data: Dictionary)
signal enemy_state_changed(enemy_id: String, new_state: int)
signal enemy_defeated(enemy_id: String, rewards: Dictionary)
signal enemy_health_changed(enemy_id: String, new_hp: int)

## Constants
const SPAWNING_DURATION: float = 0.3
const DEFEATED_DURATION: float = 0.5
const BASE_ENEMY_POWER: int = 100
const POWER_INCREMENT: int = 50

## State enum
enum EnemyState { SPAWNING, ALIVE, DEFEATED }

## State
var _active_enemies: Dictionary = {}  # {enemy_id: {state, timer, data}}
var _enemy_counter: int = 0

#region Public API

func spawn_enemy(floor: int) -> Dictionary:
	## Spawn enemy scaled to floor level
	var enemy_id: String = "enemy_%d_%d" % [floor, _enemy_counter]
	_enemy_counter += 1

	# Calculate stats
	var recommended_power: int = BASE_ENEMY_POWER + floor * POWER_INCREMENT
	var max_hp: int = recommended_power * 2

	var enemy_data: Dictionary = {
		id = enemy_id,
		floor = floor,
		recommended_power = recommended_power,
		current_hp = max_hp,
		max_hp = max_hp,
		state = EnemyState.SPAWNING,
		rewards = _calculate_rewards(floor),
	}

	_active_enemies[enemy_id] = enemy_data

	# Start SPAWNING timer
	_start_state_timer(enemy_id, EnemyState.ALIVE, SPAWNING_DURATION)

	emit_signal("enemy_spawned", enemy_id, enemy_data)
	return enemy_data

func get_enemy_state(enemy_id: String) -> int:
	## Returns enemy state enum (-1 if not found)
	if not _active_enemies.has(enemy_id):
		return -1
	return _active_enemies[enemy_id].state

func get_enemy_data(enemy_id: String) -> Dictionary:
	return _active_enemies.get(enemy_id, {})

func apply_damage(enemy_id: String, damage: int) -> void:
	## Apply damage to enemy (called by CombatEngine)
	if not _active_enemies.has(enemy_id):
		return

	var enemy: Dictionary = _active_enemies[enemy_id]
	if enemy.state != EnemyState.ALIVE:
		return

	enemy.current_hp -= damage
	enemy.current_hp = maxi(enemy.current_hp, 0)

	emit_signal("enemy_health_changed", enemy_id, enemy.current_hp)

	if enemy.current_hp <= 0:
		defeat_enemy(enemy_id)

func defeat_enemy(enemy_id: String) -> void:
	## Transition enemy to DEFEATED state
	if not _active_enemies.has(enemy_id):
		return

	var enemy: Dictionary = _active_enemies[enemy_id]
	if enemy.state != EnemyState.ALIVE:
		return

	enemy.state = EnemyState.DEFEATED
	emit_signal("enemy_state_changed", enemy_id, EnemyState.DEFEATED)

	# Start DEFEATED timer (rewards after animation)
	_start_state_timer(enemy_id, -1, DEFEATED_DURATION, true)  # -1 = final state

func get_rewards(enemy_id: String) -> Dictionary:
	## Get rewards for defeated enemy
	if not _active_enemies.has(enemy_id):
		return {}
	return _active_enemies[enemy_id].get("rewards", {})

func get_state() -> Dictionary:
	return {
		active = _active_enemies.keys(),
		counter = _enemy_counter,
	}

func set_state(state: Dictionary) -> void:
	_enemy_counter = state.get("counter", 0)

#endregion

#region Internal

func _start_state_timer(enemy_id: String, next_state: int, duration: float, emit_rewards: bool = false) -> void:
	## Create timer for state transition
	var timer := Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	timer.timeout.connect(_on_state_timer_complete.bind(enemy_id, next_state, emit_rewards))
	add_child(timer)
	timer.start()

func _on_state_timer_complete(enemy_id: String, next_state: int, emit_rewards: bool) -> void:
	## Handle state timer completion
	if not _active_enemies.has(enemy_id):
		return

	var enemy: Dictionary = _active_enemies[enemy_id]

	if next_state != -1:
		enemy.state = next_state
		emit_signal("enemy_state_changed", enemy_id, next_state)

	if emit_rewards:
		var rewards: Dictionary = enemy.get("rewards", {})
		emit_signal("enemy_defeated", enemy_id, rewards)

		# Check if boss floor
		if DungeonProgress.is_boss_floor(enemy.floor):
			DungeonProgress.mark_boss_defeated(enemy.floor)

		# Cleanup
		_active_enemies.erase(enemy_id)

func _calculate_rewards(floor: int) -> Dictionary:
	## Calculate rewards based on floor (simplified for MVP)
	var gold: int = 10 + floor * 5
	var stone: int = 1 + floor / 2

	return {
		gold = gold,
		materials = {
			enhancement_stone = stone,
		},
		equipment_drops = [],  # Handled by DropGenerator
	}

#endregion