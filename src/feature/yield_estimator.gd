extends Node
class_name YieldEstimator

## YieldEstimator - Feature Layer (Static)
## Implements offline yield calculation
## Pure math - no state

## Constants
const GOLD_PER_SECOND: float = 10.0
const MATERIAL_PER_SECOND: float = 0.5
const MAX_OFFLINE_MATERIAL_STACK: int = 500

## Static Functions

static func estimate_yield(duration: float, floor: int) -> Dictionary:
	## Calculate offline yield capped to max
	# Cap duration
	duration = minf(duration, TimeTracker.MAX_ALLOWED_OFFLINE)

	# Gold yield
	var gold_yield: int = floori(GOLD_PER_SECOND * duration * (1.0 + floor * 0.1))

	# Material yield with cap
	var raw_material: int = floori(MATERIAL_PER_SECOND * duration)
	var capped_material: int = mini(raw_material, MAX_OFFLINE_MATERIAL_STACK)

	return {
		gold = gold_yield,
		enhancement_stone = capped_material,
	}