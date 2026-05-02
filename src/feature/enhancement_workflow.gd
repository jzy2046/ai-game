extends Control
# EnhancementWorkflow - Feature Layer
# NOTE: No class_name - autoload singleton, accessed via EnhancementWorkflow globally
# Implements enhancement UI flow

## Signals
signal enhancement_started(slot: int, current_level: int)
signal enhancement_complete(slot: int, new_level: int, new_stats: Dictionary)
signal enhancement_cancelled()

## State
var _current_slot: int = -1
# Cached autoload references
var _equipment_manager: Node = null
var _gold_vault: Node = null
var _material_inventory: Node = null
var _touch_router: Node = null
var _item_registry: Node = null

#region Public API

func start_enhancement(slot: int) -> void:
	## Begin enhancement flow for slot
	if _equipment_manager and _equipment_manager.has_method("get_equipped"):
		var equipment_id: String = _equipment_manager.get_equipped(slot)
		if equipment_id.is_empty():
			return

		if _equipment_manager.has_method("get_equipped_level"):
			var current_level: int = _equipment_manager.get_equipped_level(slot)
			_current_slot = slot
			emit_signal("enhancement_started", slot, current_level)

			# Check cost
			var gold_cost: int = EnhancementCalculator.calc_gold_cost(current_level)
			var mat_cost: Dictionary = EnhancementCalculator.calc_material_cost(current_level)

			if _gold_vault and _gold_vault.has_method("can_spend"):
				if not _gold_vault.can_spend(gold_cost):
					push_warning("Not enough gold for enhancement")
					return

			# Show confirmation (MVP: auto-confirm)
			_execute_enhancement(gold_cost, mat_cost)

func _execute_enhancement(gold_cost: int, mat_cost: Dictionary) -> void:
	## Execute enhancement transaction
	if _gold_vault and _gold_vault.has_method("spend"):
		_gold_vault.spend(gold_cost)

	if _material_inventory and _material_inventory.has_method("remove_bulk"):
		_material_inventory.remove_bulk(mat_cost)

	if _equipment_manager and _equipment_manager.has_method("set_equipped_level"):
		var current_level: int = _equipment_manager.get_equipped_level(_current_slot)
		var new_level: int = current_level + 1
		_equipment_manager.set_equipped_level(_current_slot, new_level)

		if _equipment_manager.has_method("get_total_stats"):
			var new_stats: Dictionary = _equipment_manager.get_total_stats()
			emit_signal("enhancement_complete", _current_slot, new_level, new_stats)

func get_preview(slot: int) -> Dictionary:
	## Return enhancement preview for slot
	if _equipment_manager and _equipment_manager.has_method("get_equipped"):
		var equipment_id: String = _equipment_manager.get_equipped(slot)
		if equipment_id.is_empty():
			return {}

		if _equipment_manager.has_method("get_equipped_level"):
			var current_level: int = _equipment_manager.get_equipped_level(slot)

			if _item_registry and _item_registry.has_method("get_equipment"):
				var base_def: Dictionary = _item_registry.get_equipment(equipment_id)
				if _item_registry.has_method("get_enhanced_stats"):
					var current_stats: Dictionary = _item_registry.get_enhanced_stats(equipment_id, current_level)
					var new_stats: Dictionary = _item_registry.get_enhanced_stats(equipment_id, current_level + 1)
					return {
						current_level = current_level,
						current_stats = current_stats,
						new_stats = new_stats,
						gold_cost = EnhancementCalculator.calc_gold_cost(current_level),
						mat_cost = EnhancementCalculator.calc_material_cost(current_level),
					}
	return {}

#endregion

#region Lifecycle

func _ready():
	# Cache autoload references
	_equipment_manager = get_node("/root/EquipmentManager")
	_gold_vault = get_node("/root/GoldVault")
	_material_inventory = get_node("/root/MaterialInventory")
	_touch_router = get_node("/root/TouchRouter")
	_item_registry = get_node("/root/ItemRegistry")
	hide()

#endregion