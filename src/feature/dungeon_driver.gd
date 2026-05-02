extends Node
# DungeonDriver - Feature Layer
# NOTE: No class_name - autoload singleton, accessed via DungeonDriver globally
# Implements floor progression logic

## Signals
signal floor_complete(floor: int)
signal floor_advanced(new_floor: int)
signal enemies_spawned(floor: int, count: int)

## State
var _floor_enemies: Array = []  # Active enemies on current floor
var _enemies_defeated: int = 0
var _total_enemies: int = 0
# Cached autoload references
var _enemy_controller: Node = null
var _dungeon_progress: Node = null
var _combat_engine: Node = null

#region Public API

func start_floor(floor: int) -> void:
	## Spawn enemies for floor
	var enemy_count: int = _get_enemy_count(floor)
	_total_enemies = enemy_count
	_enemies_defeated = 0
	_floor_enemies.clear()

	for i in range(enemy_count):
		if _enemy_controller and _enemy_controller.has_method("spawn_enemy"):
			var enemy: Dictionary = _enemy_controller.spawn_enemy(floor)
			_floor_enemies.append(enemy.id)

	emit_signal("enemies_spawned", floor, enemy_count)

	# Start combat with first enemy
	if _floor_enemies.size() > 0:
		_start_next_combat()

func advance_to_next() -> void:
	## Advance to next floor after current complete
	if _dungeon_progress and _dungeon_progress.has_method("get_current_floor"):
		var current: int = _dungeon_progress.get_current_floor()
		if _dungeon_progress.has_method("advance_floor"):
			_dungeon_progress.advance_floor()
		emit_signal("floor_advanced", _dungeon_progress.get_current_floor())

		# Start next floor
		start_floor(_dungeon_progress.get_current_floor())

func is_floor_complete() -> bool:
	return _enemies_defeated >= _total_enemies

func on_enemy_defeated(enemy_id: String) -> void:
	## Handle enemy defeat signal
	_enemies_defeated += 1

	# Check floor completion
	if is_floor_complete():
		if _dungeon_progress and _dungeon_progress.has_method("get_current_floor"):
			emit_signal("floor_complete", _dungeon_progress.get_current_floor())

			# Check if boss floor
			if _dungeon_progress.has_method("is_boss_floor"):
				if _dungeon_progress.is_boss_floor(_dungeon_progress.get_current_floor()):
					# Boss floor - pause for victory feedback
					await get_tree().create_timer(1.0).timeout
					advance_to_next()
				else:
					# Normal floor - start next combat
					_start_next_combat()

#region Lifecycle

func _ready():
	# Cache autoload references
	_enemy_controller = get_node("/root/EnemyController")
	_dungeon_progress = get_node("/root/DungeonProgress")
	_combat_engine = get_node("/root/CombatEngine")

	# Connect to EnemyController
	if _enemy_controller and _enemy_controller.has_signal("enemy_defeated"):
		_enemy_controller.enemy_defeated.connect(_on_enemy_defeated_signal)

	# Delay start to ensure all autoloads are initialized
	await get_tree().create_timer(0.5).timeout
	# Start first floor
	if _dungeon_progress and _dungeon_progress.has_method("get_current_floor"):
		start_floor(_dungeon_progress.get_current_floor())

#endregion

#region Internal

func _on_enemy_defeated_signal(enemy_id: String, rewards: Dictionary) -> void:
	on_enemy_defeated(enemy_id)

func _start_next_combat() -> void:
	## Start combat with next enemy in queue
	if _enemy_controller and _enemy_controller.has_method("get_enemy_state"):
		var defeated_state: int = 2  # EnemyController.EnemyState.DEFEATED
		_floor_enemies = _floor_enemies.filter(func(id): return _enemy_controller.get_enemy_state(id) != defeated_state)

	if _floor_enemies.size() > 0:
		var next_enemy_id: String = _floor_enemies[0]
		if _enemy_controller and _enemy_controller.has_method("get_enemy_data"):
			var enemy_data: Dictionary = _enemy_controller.get_enemy_data(next_enemy_id)
			if _combat_engine and _combat_engine.has_method("start_battle"):
				_combat_engine.start_battle(enemy_data)
	elif not is_floor_complete():
		# Spawn more enemies if needed
		if _dungeon_progress and _dungeon_progress.has_method("get_current_floor"):
			start_floor(_dungeon_progress.get_current_floor())

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