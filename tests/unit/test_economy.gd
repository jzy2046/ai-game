# GUT Test Configuration
extends GutTest

var _material_inventory: MaterialInventory
var _gold_vault: GoldVault

func before_all():
	await get_tree().create_timer(0.1).timeout
	_material_inventory = MaterialInventory
	_gold_vault = GoldVault

func before_each():
	# Reset state
	if _material_inventory:
		_material_inventory._material_stacks = {
			"enhancement_stone": 0,
			"crystal_essence": 0,
			"celestial_shard": 0,
		}
	if _gold_vault:
		_gold_vault._gold_amount = 0

# Material Inventory Tests

func test_add_material_basic():
	var material_id := "enhancement_stone"
	var count: int = 10

	var result: int = _material_inventory.add_material(material_id, count)

	assert_eq(result, 10, "Add material should return new stack count")
	assert_eq(_material_inventory.get_stack(material_id), 10, "Stack should be updated")

func test_add_material_cumulative():
	var material_id := "enhancement_stone"

	_material_inventory.add_material(material_id, 5)
	var result: int = _material_inventory.add_material(material_id, 10)

	assert_eq(result, 15, "Cumulative addition should work")

func test_add_material_overflow_cap():
	# max_stack for enhancement_stone is 999
	var material_id := "enhancement_stone"

	# Add to near cap
	_material_inventory.add_material(material_id, 900)
	# Add overflow
	var result: int = _material_inventory.add_material(material_id, 200)

	assert_eq(result, 999, "Stack should cap at max_stack")

func test_can_remove_bulk_sufficient():
	_material_inventory.add_material("enhancement_stone", 10)
	_material_inventory.add_material("crystal_essence", 5)

	var requirements := {
		"enhancement_stone": 5,
		"crystal_essence": 3,
	}

	assert_true(_material_inventory.can_remove_bulk(requirements), "Should return true when sufficient")

func test_can_remove_bulk_insufficient():
	_material_inventory.add_material("enhancement_stone", 3)

	var requirements := {
		"enhancement_stone": 10,
	}

	assert_false(_material_inventory.can_remove_bulk(requirements), "Should return false when insufficient")

func test_remove_bulk_atomic():
	_material_inventory.add_material("enhancement_stone", 20)

	var requirements := {"enhancement_stone": 10}
	var result: bool = _material_inventory.remove_bulk(requirements)

	assert_true(result, "Remove bulk should succeed")
	assert_eq(_material_inventory.get_stack("enhancement_stone"), 10, "Stack should be reduced")

func test_remove_bulk_partial_failure():
	_material_inventory.add_material("enhancement_stone", 5)

	var requirements := {"enhancement_stone": 10}
	var result: bool = _material_inventory.remove_bulk(requirements)

	assert_false(result, "Remove bulk should fail when insufficient")
	assert_eq(_material_inventory.get_stack("enhancement_stone"), 5, "Stack should remain unchanged on failure")

# Gold Vault Tests

func test_add_gold_basic():
	var result: int = _gold_vault.add_gold(100)

	assert_eq(result, 100, "Add gold should return new amount")
	assert_eq(_gold_vault.get_gold(), 100, "Gold amount should be updated")

func test_add_gold_cumulative():
	_gold_vault.add_gold(50)
	var result: int = _gold_vault.add_gold(75)

	assert_eq(result, 125, "Cumulative gold addition should work")

func test_can_spend_sufficient():
	_gold_vault.add_gold(100)

	assert_true(_gold_vault.can_spend(50), "Should return true when sufficient")
	assert_true(_gold_vault.can_spend(100), "Should return true for exact amount")

func test_can_spend_insufficient():
	_gold_vault.add_gold(50)

	assert_false(_gold_vault.can_spend(100), "Should return false when insufficient")

func test_spend_success():
	_gold_vault.add_gold(100)

	var result: bool = _gold_vault.spend(30)

	assert_true(result, "Spend should succeed")
	assert_eq(_gold_vault.get_gold(), 70, "Gold should be reduced")

func test_spend_failure():
	_gold_vault.add_gold(20)

	var result: bool = _gold_vault.spend(50)

	assert_false(result, "Spend should fail when insufficient")
	assert_eq(_gold_vault.get_gold(), 20, "Gold should remain unchanged on failure")