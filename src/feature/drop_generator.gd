extends Node
class_name DropGenerator

## DropGenerator - Feature Layer
## Implements drop table RNG logic

## Signals

## State
var _drop_tables: Dictionary = {}
var _rng: RandomNumberGenerator

#region Public API

func generate_drops(enemy_id: String, floor: int) -> Array:
	## Generate equipment drops for defeated enemy
	# MVP: Simplified drop logic
	var drops: Array = []

	# Drop chance based on floor
	var drop_chance: float = 0.3 + floor * 0.05  # 30% base + 5% per floor
	drop_chance = minf(drop_chance, 0.8)

	if _rng.randf() > drop_chance:
		return drops  # No drop

	# Random equipment from ItemRegistry
	var equipment_ids: Array = ItemRegistry.get_all_equipment_ids()
	if equipment_ids.is_empty():
		return drops

	var random_index: int = _rng.randi_range(0, equipment_ids.size() - 1)
	var equipment_id: String = equipment_ids[random_index]

	# Rarity weighted by floor
	var rarity: int = _roll_rarity(floor)

	drops.append({
		equipment_id = equipment_id,
		rarity = rarity,
	})

	return drops

func set_rng_seed(seed: int) -> void:
	## Set seed for reproducible drops (testing)
	_rng.seed = seed

#endregion

#region Lifecycle

func _ready():
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

#endregion

#region Internal

func _roll_rarity(floor: int) -> int:
	## Roll rarity weighted by floor level
	var weights: Dictionary = {
		0: 70 - floor * 3,  # Common (decreases with floor)
		1: 20,              # Uncommon
		2: 8 + floor,       # Rare (increases)
		3: 2 + floor / 2,   # Epic
		4: floor / 5,       # Legendary
	}

	# Normalize weights
	var total: int = 0
	for rarity in weights:
		total += weights[rarity]

	var roll: int = _rng.randi_range(1, total)
	var cumulative: int = 0

	for rarity in weights:
		cumulative += weights[rarity]
		if roll <= cumulative:
			return rarity

	return 0  # Default to Common

#endregion