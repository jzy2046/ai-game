extends Node
class_name DungeonDriver

## DungeonDriver - Feature Layer
## Implements floor progression logic

## Signals
signal floor_complete(floor: int)
signal floor_advanced(new_floor: int)
signal enemies_spawned(floor: int, count: int)

## State
var _floor_enemies: Array = []  # Active enemies on current floor
var _enemies_defeated: int = 0
var _total_enemies: int = 0

#region Public API

func start_floor(floor: int) -> void:
	## Spawn enemies for floor
	var enemy_count: int = _get_enemy_count(floor)
	_total_enemies = enemy_count
	_enemies_defeated = 0
	_floor_enemies.clear()

	for i in range(enemy_count):
		var enemy: Dictionary = EnemyController.spawn_enemy(floor)
		_floor_enemies.append(enemy.id)

	emit_signal("enemies_spawned", floor, enemy_count)

	# Start combat with first enemy
	if _floor_enemies.size() > 0:
		_start_next_combat()

func advance_to_next() -> void:
	## Advance to next floor after current complete
	var current: int = DungeonProgress.get_current_floor()
	DungeonProgress.advance_floor()
	emit_signal("floor_advanced", DungeonProgress.get_current_floor())

	# Start next floor
	start_floor(DungeonProgress.get_current_floor())

func is_floor_complete() -> bool:
	return _enemies_defeated >= _total_enemies

func on_enemy_defeated(enemy_id: String) -> void:
	## Handle enemy defeat signal
	_enemies_defeated += 1

	# Check floor completion
	if is_floor_complete():
		emit_signal("floor_complete", DungeonProgress.get_current_floor())

		# Check if boss floor
		if DungeonProgress.is_boss_floor(DungeonProgress.get_current_floor()):
			# Boss floor - pause for victory feedback
			await get_tree().create_timer(1.0).timeout
			advance_to_next()
		else:
			# Normal floor - start next combat
			_start_next_combat()

#region Lifecycle

func _ready():
	# Connect to EnemyController
	EnemyController.enemy_defeated.connect(_on_enemy_defeated_signal)

	# Start first floor
	start_floor(DungeonProgress.get_current_floor())

#endregion

#region Internal

func _on_enemy_defeated_signal(enemy_id: String, rewards: Dictionary) -> void:
	on_enemy_defeated(enemy_id)

func _start_next_combat() -> void:
	## Start combat with next enemy in queue
	_floor_enemies = _floor_enemies.filter(func(id): return EnemyController.get_enemy_state(id) != EnemyController.EnemyState.DEFEATED)

	if _floor_enemies.size() > 0:
		var next_enemy_id: String = _floor_enemies[0]
		var enemy_data: Dictionary = EnemyController.get_enemy_data(next_enemy_id)
		CombatEngine.start_battle(enemy_data)
	elif not is_floor_complete():
		# Spawn more enemies if needed
		start_floor(DungeonProgress.get_current_floor())

func _get_enemy_count(floor: int) -> int:
	## Enemy count per floor (stepped: 1, 2, 3, 4)
	if floor <= 2:
		return 1
	elif floor <= 4:
		return 2
	elif floor <= 7:
		return 3
	else:
		return 4

#endregion