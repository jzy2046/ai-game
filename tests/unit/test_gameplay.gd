# GUT Test Configuration
extends GutTest

var _enemy_controller: EnemyController
var _dungeon_progress: DungeonProgress

func before_all():
	await get_tree().create_timer(0.1).timeout
	_enemy_controller = EnemyController
	_dungeon_progress = DungeonProgress

func before_each():
	if _dungeon_progress:
		_dungeon_progress._current_floor = 1
		_dungeon_progress._unlocked_floors = [1]
		_dungeon_progress._boss_defeated = {}
	if _enemy_controller:
		_enemy_controller._active_enemies = {}
		_enemy_controller._enemy_counter = 0

# TR-state-001: Enemy state machine
func test_enemy_state_enum_values():
	assert_eq(EnemyController.EnemyState.SPAWNING, 0, "SPAWNING should be 0")
	assert_eq(EnemyController.EnemyState.ALIVE, 1, "ALIVE should be 1")
	assert_eq(EnemyController.EnemyState.DEFEATED, 2, "DEFEATED should be 2")

func test_spawn_enemy_creates_instance():
	var enemy: Dictionary = _enemy_controller.spawn_enemy(1)

	assert_false(enemy.is_empty(), "Spawn should return non-empty dict")
	assert_has(enemy, "id", "Enemy should have ID")
	assert_has(enemy, "state", "Enemy should have state")
	assert_eq(enemy.state, EnemyController.EnemyState.SPAWNING, "Initial state should be SPAWNING")

func test_spawn_enemy_scales_by_floor():
	var enemy_floor_1: Dictionary = _enemy_controller.spawn_enemy(1)
	var enemy_floor_5: Dictionary = _enemy_controller.spawn_enemy(5)

	var power_1: int = enemy_floor_1.get("recommended_power", 0)
	var power_5: int = enemy_floor_5.get("recommended_power", 0)

	assert_gt(power_5, power_1, "Higher floor enemies should have more power")
	# Formula: 100 + floor * 50
	assert_eq(power_1, 150, "Floor 1 power should be 150")
	assert_eq(power_5, 350, "Floor 5 power should be 350")

# TR-state-002: State transition timing
func test_spawning_duration_constant():
	assert_eq(EnemyController.SPAWNING_DURATION, 0.3, "SPAWNING_DURATION should be 0.3s")

func test_defeated_duration_constant():
	assert_eq(EnemyController.DEFEATED_DURATION, 0.5, "DEFEATED_DURATION should be 0.5s")

func test_enemy_hp_formula():
	var enemy: Dictionary = _enemy_controller.spawn_enemy(1)

	var recommended_power: int = enemy.get("recommended_power", 0)
	var max_hp: int = enemy.get("max_hp", 0)

	# HP = 2× power
	assert_eq(max_hp, recommended_power * 2, "Enemy HP should be 2× recommended_power")

func test_apply_damage_reduces_hp():
	var enemy: Dictionary = _enemy_controller.spawn_enemy(1)

	# Simulate damage
	var initial_hp: int = enemy.current_hp
	_enemy_controller.apply_damage(enemy.id, 50)

	var updated_enemy: Dictionary = _enemy_controller.get_enemy_data(enemy.id)
	assert_lt(updated_enemy.current_hp, initial_hp, "HP should decrease after damage")

func test_damage_kill_transitions_state():
	var enemy: Dictionary = _enemy_controller.spawn_enemy(1)
	var max_hp: int = enemy.max_hp

	# Apply lethal damage
	_enemy_controller.apply_damage(enemy.id, max_hp + 10)

	var state: int = _enemy_controller.get_enemy_state(enemy.id)
	assert_eq(state, EnemyController.EnemyState.DEFEATED, "Enemy should transition to DEFEATED when HP ≤ 0")

# Dungeon Progress Tests

func test_get_current_floor():
	assert_eq(_dungeon_progress.get_current_floor(), 1, "Initial floor should be 1")

func test_advance_floor():
	_dungeon_progress.advance_floor()

	assert_eq(_dungeon_progress.get_current_floor(), 2, "Floor should advance to 2")
	assert_true(_dungeon_progress.is_floor_unlocked(2), "Floor 2 should be unlocked")

func test_boss_floor_detection():
	assert_true(_dungeon_progress.is_boss_floor(5), "Floor 5 should be boss floor")
	assert_true(_dungeon_progress.is_boss_floor(10), "Floor 10 should be boss floor")
	assert_false(_dungeon_progress.is_boss_floor(3), "Floor 3 should not be boss floor")

func test_checkpoint_set():
	_dungeon_progress._current_floor = 5
	_dungeon_progress.set_checkpoint(3)

	assert_eq(_dungeon_progress.get_checkpoint(), 3, "Checkpoint should be set to 3")

func test_checkpoint_cannot_exceed_current():
	_dungeon_progress._current_floor = 2
	_dungeon_progress.set_checkpoint(5)  # Should fail silently

	assert_ne(_dungeon_progress.get_checkpoint(), 5, "Checkpoint should not exceed current floor")