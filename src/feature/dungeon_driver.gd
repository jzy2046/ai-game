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
var _current_floor: int = 1
# Cached autoload references
var _enemy_controller: Node = null
var _dungeon_progress: Node = null
var _combat_engine: Node = null

#region Public API

func start_floor(floor: int) -> void:
	## Spawn enemies for floor
	_current_floor = floor
	var enemy_count: int = _get_enemy_count(floor)
	_total_enemies = enemy_count
	_enemies_defeated = 0
	_floor_enemies.clear()

	for i in range(enemy_count):
		if _enemy_controller and _enemy_controller.has_method("spawn_enemy"):
			var enemy: Dictionary = _enemy_controller.spawn_enemy(floor)
			_floor_enemies.append(enemy.id)

	emit_signal("enemies_spawned", floor, enemy_count)

	# Start combat with first enemy after brief delay
	if _floor_enemies.size() > 0:
		await get_tree().create_timer(0.3).timeout
		_start_next_combat()

func advance_to_next() -> void:
	## Advance to next floor after current complete
	_current_floor += 1
	emit_signal("floor_advanced", _current_floor)
	# Brief pause before next floor
	await get_tree().create_timer(1.0).timeout
	start_floor(_current_floor)

func is_floor_complete() -> bool:
	return _enemies_defeated >= _total_enemies

#endregion

#region Lifecycle

func _ready():
	# Cache autoload references
	_enemy_controller = get_node("/root/EnemyController")
	_dungeon_progress = get_node("/root/DungeonProgress")
	_combat_engine = get_node("/root/CombatEngine")

	# Connect to CombatEngine victory signal
	if _combat_engine and _combat_engine.has_signal("battle_victory"):
		_combat_engine.battle_victory.connect(_on_battle_victory)

	# Delay start to ensure all autoloads are initialized
	await get_tree().create_timer(0.5).timeout
	start_floor(1)

#endregion

#region Internal

func _on_battle_victory(enemy_id: String, rewards: Dictionary) -> void:
	## Handle battle victory from CombatEngine
	_enemies_defeated += 1

	# Give rewards
	_give_rewards(rewards)

	# Check floor completion
	if is_floor_complete():
		emit_signal("floor_complete", _current_floor)
		# Pause before advancing
		await get_tree().create_timer(1.0).timeout
		advance_to_next()
	else:
		# Brief pause then next enemy
		await get_tree().create_timer(0.5).timeout
		_start_next_combat()

func _give_rewards(rewards: Dictionary) -> void:
	## Award gold and materials to player
	var gold_vault: Node = get_node("/root/GoldVault")
	var material_inv: Node = get_node("/root/MaterialInventory")

	var gold: int = rewards.get("gold", 0)
	if gold > 0 and gold_vault and gold_vault.has_method("add_gold"):
		gold_vault.add_gold(gold)

	var materials: Dictionary = rewards.get("materials", {})
	for mat_id in materials:
		var amount: int = materials[mat_id]
		if amount > 0 and material_inv and material_inv.has_method("add_material"):
			material_inv.add_material(mat_id, amount)

func _start_next_combat() -> void:
	## Start combat with next enemy in queue
	# Remove defeated enemies from list
	var defeated_state: int = 2  # EnemyState.DEFEATED
	if _enemy_controller and _enemy_controller.has_method("get_enemy_state"):
		_floor_enemies = _floor_enemies.filter(func(id):
			return _enemy_controller.get_enemy_state(id) != defeated_state)

	if _floor_enemies.size() > 0:
		var next_enemy_id: String = _floor_enemies[0]
		if _enemy_controller and _enemy_controller.has_method("get_enemy_data"):
			var enemy_data: Dictionary = _enemy_controller.get_enemy_data(next_enemy_id)
			if _combat_engine and _combat_engine.has_method("start_battle"):
				_combat_engine.start_battle(enemy_data)
	elif not is_floor_complete():
		# Respawn if needed
		start_floor(_current_floor)

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