extends Node
# DungeonProgress - Core Layer
# NOTE: No class_name - autoload singleton, accessed via DungeonProgress globally
## Implements floor tracking and checkpoint management

## Signals
signal floor_changed(new_floor: int)
signal checkpoint_set(floor: int)
signal boss_defeated(floor: int)

## Constants
const MAX_FLOOR: int = 10

## State
var _current_floor: int = 1
var _checkpoint_floor: int = 1
var _unlocked_floors: Array = [1]
var _boss_defeated: Dictionary = {}  # {floor: bool}

## Boss floor mapping (floor 5 and 10 are boss floors)
const BOSS_FLOORS: Array = [5, 10]

#region Public API

func get_current_floor() -> int:
	return _current_floor

func get_checkpoint() -> int:
	return _checkpoint_floor

func advance_floor() -> void:
	## Advance to next floor (emit floor_changed)
	if _current_floor >= MAX_FLOOR:
		return

	_current_floor += 1

	# Unlock next floor
	if not _unlocked_floors.has(_current_floor):
		_unlocked_floors.append(_current_floor)

	emit_signal("floor_changed", _current_floor)

func set_checkpoint(floor: int) -> void:
	## Set checkpoint (for restart)
	if floor > _current_floor:
		return
	_checkpoint_floor = floor
	emit_signal("checkpoint_set", floor)

func is_boss_floor(floor: int) -> bool:
	return BOSS_FLOORS.has(floor)

func mark_boss_defeated(floor: int) -> void:
	_boss_defeated[floor] = true
	emit_signal("boss_defeated", floor)

func is_floor_unlocked(floor: int) -> bool:
	return _unlocked_floors.has(floor)

func get_state() -> Dictionary:
	return {
		current_floor = _current_floor,
		checkpoint = _checkpoint_floor,
		unlocked = _unlocked_floors,
		boss_defeated = _boss_defeated,
	}

func set_state(state: Dictionary) -> void:
	_current_floor = state.get("current_floor", 1)
	_checkpoint_floor = state.get("checkpoint", 1)
	_unlocked_floors = state.get("unlocked", [1])
	_boss_defeated = state.get("boss_defeated", {})

#endregion