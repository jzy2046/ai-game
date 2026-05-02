extends Control
# DropHandler - Feature Layer
# NOTE: No class_name - autoload singleton, accessed via DropHandler globally
# Implements post-combat drop display and collection

## Signals
signal drops_collected(drops: Array)

## State
var _pending_drops: Array = []
var _current_drop: Dictionary = {}
# Cached autoload references
var _item_registry: Node = null
var _equipment_manager: Node = null
var _touch_router: Node = null

#region Public API

func show_drops(drops: Dictionary) -> void:
	## Display drop panel with rewards
	_pending_drops = []

	# Process gold
	var gold: int = drops.get("gold", 0)
	if gold > 0:
		_pending_drops.append({type = "gold", amount = gold})

	# Process materials
	var materials: Dictionary = drops.get("materials", {})
	for material_id in materials:
		var amount: int = materials[material_id]
		_pending_drops.append({type = "material", id = material_id, amount = amount})

	# Process equipment
	var equipment: Array = drops.get("equipment", [])
	for equipment_id in equipment:
		if _item_registry and _item_registry.has_method("get_equipment"):
			var equipment_def: Dictionary = _item_registry.get_equipment(equipment_id)
			_pending_drops.append({type = "equipment", id = equipment_id, def = equipment_def})

	# Show first drop
	_show_next_drop()

func collect_all() -> void:
	## Collect all pending drops
	for drop in _pending_drops:
		_collect_drop(drop)

	_pending_drops.clear()
	emit_signal("drops_collected", _pending_drops)
	hide()

#endregion

#region Lifecycle

func _ready():
	# Cache autoload references
	_item_registry = get_node("/root/ItemRegistry")
	_equipment_manager = get_node("/root/EquipmentManager")
	_touch_router = get_node("/root/TouchRouter")
	hide()

#endregion

#region Internal

func _show_next_drop() -> void:
	if _pending_drops.size() == 0:
		hide()
		return

	_current_drop = _pending_drops[0]
	# MVP: Just collect immediately
	_collect_drop(_current_drop)
	_pending_drops.remove_at(0)
	_show_next_drop()

func _collect_drop(drop: Dictionary) -> void:
	var drop_type: String = drop.get("type", "")

	if drop_type == "equipment":
		var equipment_id: String = drop.get("id", "")
		# Find empty slot
		if _equipment_manager and _equipment_manager.has_method("get_equipped"):
			for slot in range(6):
				if _equipment_manager.get_equipped(slot).is_empty():
					if _equipment_manager.has_method("equip"):
						_equipment_manager.equip(slot, equipment_id)
					break

#endregion