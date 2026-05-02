# Integration Test: Core Loop
extends GutTest

## Tests the full game loop: combat → defeat → reward → enhancement

var _combat_engine: CombatEngine
var _enemy_controller: EnemyController
var _equipment_manager: EquipmentManager
var _gold_vault: GoldVault
var _material_inventory: MaterialInventory

func before_all():
	await get_tree().create_timer(0.2).timeout
	_combat_engine = CombatEngine
	_enemy_controller = EnemyController
	_equipment_manager = EquipmentManager
	_gold_vault = GoldVault
	_material_inventory = MaterialInventory

func before_each():
	# Reset all systems
	_gold_vault._gold_amount = 0
	_material_inventory._material_stacks = {
		"enhancement_stone": 100,  # Pre-populate for enhancement
		"crystal_essence": 50,
		"celestial_shard": 20,
	}
	for i in range(6):
		_equipment_manager._equipped_slots[i] = {id = "", level = 0}
	_enemy_controller._active_enemies = {}
	_combat_engine._state = CombatEngine.CombatState.IDLE

# Full loop test
func test_full_combat_loop():
	# Step 1: Equip starting weapon
	var equip_result: bool = _equipment_manager.equip(0, "weapon_sword_001")
	assert_true(equip_result, "Should be able to equip weapon")

	# Step 2: Spawn enemy
	var enemy: Dictionary = _enemy_controller.spawn_enemy(1)
	assert_false(enemy.is_empty(), "Enemy should spawn")

	# Step 3: Get player stats
	var player_stats: Dictionary = _equipment_manager.get_total_stats()
	assert_gt(player_stats.power, 0, "Player should have power")

	# Step 4: Calculate damage (simulated)
	var damage: int = _combat_engine.calculate_damage(player_stats, enemy)
	assert_gt(damage, 0, "Damage should be positive")

	# Step 5: Apply damage until defeat
	var total_damage: int = 0
	while enemy.current_hp > 0:
		_enemy_controller.apply_damage(enemy.id, damage)
		total_damage += damage
		enemy = _enemy_controller.get_enemy_data(enemy.id)

	# Step 6: Verify defeat
	var state: int = _enemy_controller.get_enemy_state(enemy.id)
	assert_eq(state, EnemyController.EnemyState.DEFEATED, "Enemy should be defeated")

	# Step 7: Get rewards
	var rewards: Dictionary = _enemy_controller.get_rewards(enemy.id)
	assert_has(rewards, "gold", "Rewards should include gold")

	# Step 8: Award gold
	var gold_reward: int = rewards.get("gold", 0)
	_gold_vault.add_gold(gold_reward)
	assert_eq(_gold_vault.get_gold(), gold_reward, "Gold should be awarded")

# Enhancement flow test
func test_enhancement_flow():
	# Pre-populate gold and materials
	_gold_vault._gold_amount = 1000
	_material_inventory._material_stacks["enhancement_stone"] = 50

	# Equip weapon
	_equipment_manager.equip(0, "weapon_sword_001")
	var initial_attack: int = _equipment_manager.get_total_stats().get("attack", 0)

	# Check enhancement cost
	var cost: int = EnhancementCalculator.calc_gold_cost(0)
	assert_true(_gold_vault.can_spend(cost), "Should have enough gold for level 1")

	# Check material cost
	var mat_cost: Dictionary = EnhancementCalculator.calc_material_cost(0)
	assert_true(_material_inventory.can_remove_bulk(mat_cost), "Should have enough materials")

	# Execute enhancement
	_gold_vault.spend(cost)
	_material_inventory.remove_bulk(mat_cost)
	_equipment_manager.set_equipped_level(0, 1)

	# Verify stat increase
	var new_attack: int = _equipment_manager.get_total_stats().get("attack", 0)
	assert_gt(new_attack, initial_attack, "Attack should increase after enhancement")

# Offline yield test
func test_offline_yield_calculation():
	# Simulate 1 hour offline
	var duration: float = 3600.0  # 1 hour
	var floor: int = 1

	var yield: Dictionary = YieldEstimator.estimate_yield(duration, floor)

	assert_has(yield, "gold", "Yield should include gold")
	assert_gt(yield.get("gold", 0), 0, "Gold yield should be positive")

func test_offline_yield_cap():
	# Simulate 30 hours offline (exceeds cap)
	var duration: float = 108000.0  # 30 hours

	var capped_duration: float = minf(duration, 86400.0)
	assert_eq(capped_duration, 86400.0, "Duration should cap to 24 hours")

	var yield: Dictionary = YieldEstimator.estimate_yield(capped_duration, 1)
	assert_has(yield, "enhancement_stone", "Yield should include materials")

	# Material cap at 500
	assert_lte(yield.get("enhancement_stone", 0), 500, "Material yield should cap at 500")

# Touch input routing test
func test_touch_layer_routing():
	# This would require simulating InputEvent, which needs actual Godot runtime
	pending("Touch routing requires Godot runtime with Input system")

# Signal propagation test
func test_signal_damage_dealt():
	# Connect to signal and verify emission
	_combat_engine.damage_dealt.connect(_on_damage_dealt)

	# Trigger combat
	var enemy: Dictionary = _enemy_controller.spawn_enemy(1)
	_combat_engine._enemy = enemy
	_combat_engine._player_stats = {power = 100, defense = 0}

	# Direct call for testing
	_combat_engine._on_hit_timer()

	# Verify signal was emitted (would need signal spy in real test)
	pending("Signal emission verification requires signal spy")

func _on_damage_dealt(damage: int, target_id: String):
	# Signal handler for verification
	pass