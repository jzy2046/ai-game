# GUT Test Configuration
extends GutTest

var _item_registry: ItemRegistry

func before_all():
	# Wait for autoload to initialize
	await get_tree().create_timer(0.1).timeout
	_item_registry = ItemRegistry

func before_each():
	# Ensure registry is loaded
	if _item_registry:
		await _item_registry.registry_loaded

# TR-regist-001: Registry ownership model
func test_get_equipment_returns_definition():
	var equipment_id := "weapon_sword_001"

	var result: Dictionary = _item_registry.get_equipment(equipment_id)

	assert_false(result.is_empty(), "Known equipment ID should return non-empty dict")
	assert_eq(result.get("id"), equipment_id, "Equipment should have correct ID")
	assert_has(result, "base_attack", "Equipment should have base_attack")
	assert_has(result, "slot", "Equipment should have slot")

func test_get_equipment_unknown_returns_empty():
	var unknown_id := "nonexistent_equipment"

	var result: Dictionary = _item_registry.get_equipment(unknown_id)

	assert_true(result.is_empty(), "Unknown equipment ID should return empty dict")

func test_get_material_returns_definition():
	var material_id := "enhancement_stone"

	var result: Dictionary = _item_registry.get_material(material_id)

	assert_false(result.is_empty(), "Known material ID should return non-empty dict")
	assert_eq(result.get("id"), material_id, "Material should have correct ID")
	assert_has(result, "stackable", "Material should have stackable field")
	assert_has(result, "max_stack", "Material should have max_stack")

# TR-enhance-001: Enhancement formula
func test_enhanced_stat_calculation():
	var base: int = 100
	var level: int = 5
	var multiplier: float = 0.1

	# Formula: floor(base * (1 + level * multiplier))
	var expected: int = floori(100.0 * (1.0 + 5.0 * 0.1))  # = floor(150) = 150
	var result: int = EnhancementCalculator.calc_enhanced_stat(base, level, multiplier)

	assert_eq(result, expected, "Enhanced stat should match formula")

func test_enhanced_stat_level_10():
	# Level 10 should double the stat (×2)
	var base: int = 50
	var level: int = 10

	var result: int = EnhancementCalculator.calc_enhanced_stat(base, level)

	assert_eq(result, 100, "Level 10 should double base stat")

func test_enhanced_stat_level_0():
	# Level 0 should return base unchanged
	var base: int = 100
	var level: int = 0

	var result: int = EnhancementCalculator.calc_enhanced_stat(base, level)

	assert_eq(result, base, "Level 0 should return base stat")

# TR-enhance-002: Material cost tiers
func test_material_cost_level_1():
	var level: int = 1

	var result: Dictionary = EnhancementCalculator.calc_material_cost(level)

	assert_has(result, "enhancement_stone", "Level 1 should require enhancement_stone")
	assert_eq(result.get("enhancement_stone"), 2, "Level 1 should require 2 stones")
	assert_false(result.has("crystal_essence"), "Level 1 should not require crystal_essence")

func test_material_cost_level_5():
	var level: int = 5

	var result: Dictionary = EnhancementCalculator.calc_material_cost(level)

	assert_has(result, "crystal_essence", "Level 5 should require crystal_essence")

func test_material_cost_level_8():
	var level: int = 8

	var result: Dictionary = EnhancementCalculator.calc_material_cost(level)

	assert_has(result, "celestial_shard", "Level 8 should require celestial_shard")

func test_max_enhancement_level():
	var max_level: int = 10

	assert_false(EnhancementCalculator.can_enhance(max_level), "Level 10 should not be enhanceable")
	assert_true(EnhancementCalculator.can_enhance(9), "Level 9 should be enhanceable")