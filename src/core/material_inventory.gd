extends Node
# MaterialInventory - Core Layer
# NOTE: No class_name - autoload singleton, accessed via MaterialInventory globally
## Implements material stack management
## Depends on: ItemRegistry, SaveManager

## Signals
signal material_changed(material_id: String, new_stack: int)
signal overflow_logged(material_id: String, overflow: int)

## Constants
const MAX_OFFLINE_MATERIAL_STACK: int = 500

## State
var _material_stacks: Dictionary = {}  # {material_id: count}
var _overflow_log: Array = []

#region Public API

func get_stack_count(material_id: String) -> int:
	## Returns current stack count for material
	return _material_stacks.get(material_id, 0)

func add_material(material_id: String, count: int) -> int:
	## Add materials, cap to max_stack, return new stack
	if count <= 0:
		return get_stack_count(material_id)

	# Get max stack from ItemRegistry (access via get_node for autoload)
	var item_registry: Node = get_node("/root/ItemRegistry")
	var material_def: Dictionary = item_registry.get_material(material_id) if item_registry else {}
	var max_stack: int = material_def.get("max_stack", 999)

	var current: int = get_stack_count(material_id)
	var new_stack: int = current + count

	# Check overflow
	if new_stack > max_stack:
		var overflow: int = new_stack - max_stack
		_overflow_log.append({material = material_id, overflow = overflow})
		emit_signal("overflow_logged", material_id, overflow)
		new_stack = max_stack

	_material_stacks[material_id] = new_stack
	emit_signal("material_changed", material_id, new_stack)
	return new_stack

func can_remove_bulk(requirements: Dictionary) -> bool:
	## Check if all materials have sufficient stacks
	for material_id in requirements:
		var required: int = requirements[material_id]
		var available: int = get_stack_count(material_id)
		if available < required:
			return false
	return true

func remove_bulk(requirements: Dictionary) -> bool:
	## Remove materials atomically (pre-check required)
	if not can_remove_bulk(requirements):
		return false

	for material_id in requirements:
		var required: int = requirements[material_id]
		var current: int = get_stack_count(material_id)
		var new_stack: int = current - required
		_material_stacks[material_id] = new_stack
		emit_signal("material_changed", material_id, new_stack)

	return true

func get_all_stacks() -> Dictionary:
	return _material_stacks.duplicate()

func set_all_stacks(stacks: Dictionary) -> void:
	_material_stacks = stacks.duplicate()

#endregion

#region Lifecycle

func _ready():
	# Initialize empty stacks for all materials
	var item_registry: Node = get_node("/root/ItemRegistry")
	if item_registry and item_registry.has_method("get_all_material_ids"):
		for material_id in item_registry.get_all_material_ids():
			_material_stacks[material_id] = 0

#endregion