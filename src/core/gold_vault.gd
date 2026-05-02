extends Node
class_name GoldVault

## GoldVault - Core Layer
## Implements unlimited gold stack management

## Signals
signal gold_changed(new_amount: int)

## State
var _gold_amount: int = 0

#region Public API

func get_gold() -> int:
	return _gold_amount

func add_gold(amount: int) -> int:
	## Add gold (unlimited stack)
	if amount <= 0:
		return _gold_amount

	_gold_amount += amount
	emit_signal("gold_changed", _gold_amount)
	return _gold_amount

func can_spend(amount: int) -> bool:
	return _gold_amount >= amount

func spend(amount: int) -> bool:
	## Spend gold atomically
	if not can_spend(amount):
		return false

	_gold_amount -= amount
	emit_signal("gold_changed", _gold_amount)
	return true

func set_gold(amount: int) -> void:
	_gold_amount = amount

#endregion