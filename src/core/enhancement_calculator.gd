extends Node
class_name EnhancementCalculator

## EnhancementCalculator - Core Layer (Static)
## Implements: ADR-0009 Enhancement Formula Implementation
## TR IDs: TR-enhance-001, TR-enhance-002
## Pure math - no state

## Constants
const MAX_ENHANCEMENT_LEVEL: int = 10
const ENHANCEMENT_ATTACK_MULTIPLIER: float = 0.1
const ENHANCEMENT_COST_MULTIPLIER: float = 0.5
const BASE_GOLD_COST: int = 100

## Static Functions

static func calc_enhanced_stat(base: int, level: int, multiplier: float = ENHANCEMENT_ATTACK_MULTIPLIER) -> int:
	## Formula: floor(base * (1 + level * multiplier))
	level = mini(level, MAX_ENHANCEMENT_LEVEL)
	var result: float = float(base) * (1.0 + float(level) * multiplier)
	return floori(result)

static func calc_gold_cost(current_level: int) -> int:
	## Gold cost to enhance from current_level to current_level + 1
	# Formula: floor(BASE_GOLD_COST * (1 + current_level * COST_MULTIPLIER))
	var cost: float = BASE_GOLD_COST * (1.0 + float(current_level) * ENHANCEMENT_COST_MULTIPLIER)
	return floori(cost)

static func calc_material_cost(current_level: int) -> Dictionary:
	## Material requirements per level tier
	var requirements: Dictionary = {}

	# Base stone cost (increases with level)
	var stone_cost: int = current_level + 1
	requirements["enhancement_stone"] = stone_cost

	# Crystal Essence for levels 5-7 (current_level 4-6)
	if current_level >= 4:
		requirements["crystal_essence"] = floori(current_level / 2)

	# Celestial Shard for levels 8-10 (current_level 7-9)
	if current_level >= 7:
		requirements["celestial_shard"] = floori(current_level / 3)

	return requirements

static func can_enhance(current_level: int) -> bool:
	return current_level < MAX_ENHANCEMENT_LEVEL