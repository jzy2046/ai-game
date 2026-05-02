# GUT Test Configuration
extends GutTest

var _combat_engine: CombatEngine
var _equipment_manager: EquipmentManager

func before_all():
	await get_tree().create_timer(0.1).timeout
	_combat_engine = CombatEngine
	_equipment_manager = EquipmentManager

func before_each():
	if _combat_engine:
		_combat_engine._state = CombatEngine.CombatState.IDLE
		_combat_engine._enemy = {}
		_combat_engine._player_stats = {attack = 100, defense = 50, power = 100}
	if _equipment_manager:
		for i in range(6):
			_equipment_manager._equipped_slots[i] = {id = "", level = 0}

# TR-combat-001: Timer-driven combat loop
func test_hits_per_second_constant():
	assert_eq(CombatEngine.HITS_PER_SECOND, 2.0, "HITS_PER_SECOND should be 2.0")
	assert_eq(CombatEngine.HIT_INTERVAL, 0.5, "HIT_INTERVAL should be 0.5s")

func test_combat_state_enum():
	assert_eq(CombatEngine.CombatState.IDLE, 0, "IDLE should be 0")
	assert_eq(CombatEngine.CombatState.COMBAT, 1, "COMBAT should be 1")
	assert_eq(CombatEngine.CombatState.SKIPPING, 2, "SKIPPING should be 2")
	assert_eq(CombatEngine.CombatState.VICTORY, 3, "VICTORY should be 3")

# TR-combat-002: Damage variance formula
func test_damage_variance_range():
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345

	# Test variance bounds
	var variance_min: float = CombatEngine.DAMAGE_VARIANCE_MIN
	var variance_max: float = CombatEngine.DAMAGE_VARIANCE_MAX

	assert_eq(variance_min, 0.9, "Variance min should be 0.9")
	assert_eq(variance_max, 1.1, "Variance max should be 1.1")

func test_damage_calculation_base():
	var attacker_stats := {power = 100, defense = 0}
	var defender_stats := {defense = 20}

	# Base damage = power - defense
	var expected_base: int = 80

	# Test damage is within variance range
	for i in range(10):
		var damage: int = _combat_engine.calculate_damage(attacker_stats, defender_stats)
		assert_gt(damage, 0, "Damage should be positive")
		assert_lte(damage, floori(80 * 1.1), "Damage should not exceed variance max")

func test_damage_minimum_one():
	var attacker_stats := {power = 10, defense = 0}
	var defender_stats := {defense = 100}  # Higher defense than attack

	var damage: int = _combat_engine.calculate_damage(attacker_stats, defender_stats)

	assert_gte(damage, 1, "Minimum damage should be 1")

# TR-combat-003: Skip mechanism compression
func test_skip_batch_interval():
	assert_eq(CombatEngine.SKIP_BATCH_INTERVAL, 0.3, "Skip batch interval should be 0.3s")

func test_skip_batch_size():
	assert_eq(CombatEngine.SKIP_BATCH_SIZE, 5, "Skip batch size should be 5 hits")

func test_skip_preserves_total_hits():
	# Skip should compress timeline but not skip hits
	# Verification: skip mechanism calls damage_dealt for each hit
	# This is validated in integration tests
	pending("Skip mechanism integration test pending")

# Equipment Manager Tests

func test_equip_success():
	var equipment_id := "weapon_sword_001"
	var slot: int = 0

	var result: bool = _equipment_manager.equip(slot, equipment_id)

	assert_true(result, "Equip should succeed for compatible slot")
	assert_eq(_equipment_manager.get_equipped(slot), equipment_id, "Equipment should be equipped")

func test_equip_incompatible_slot():
	var equipment_id := "armor_helm_001"  # slot = 1
	var slot: int = 0  # Weapon slot

	var result: bool = _equipment_manager.equip(slot, equipment_id)

	assert_false(result, "Equip should fail for incompatible slot")

func test_unequip():
	var equipment_id := "weapon_sword_001"
	_equipment_manager.equip(0, equipment_id)

	_equipment_manager.unequip(0)

	assert_eq(_equipment_manager.get_equipped(0), "", "Slot should be empty after unequip")

func test_get_total_stats_empty():
	var stats: Dictionary = _equipment_manager.get_total_stats()

	assert_eq(stats.get("attack"), 0, "Empty slots should have 0 attack")
	assert_eq(stats.get("defense"), 0, "Empty slots should have 0 defense")

func test_get_total_stats_with_equipment():
	# Equip weapon with base_attack = 50
	_equipment_manager.equip(0, "weapon_sword_001")
	# Level 0 = no enhancement

	var stats: Dictionary = _equipment_manager.get_total_stats()

	assert_eq(stats.get("attack"), 50, "Total attack should include weapon base")

func test_enhancement_level_effect():
	_equipment_manager.equip(0, "weapon_sword_001")
	_equipment_manager.set_equipped_level(0, 5)

	var stats: Dictionary = _equipment_manager.get_total_stats()

	# Level 5: base * (1 + 5 * 0.1) = 50 * 1.5 = 75
	assert_eq(stats.get("attack"), 75, "Level 5 should add 50% to attack")