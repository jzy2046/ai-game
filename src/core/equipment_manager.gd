extends Node
# EquipmentManager - Core Layer
# NOTE: No class_name - autoload singleton, accessed via EquipmentManager globally
# Implements equipment slot management
# Depends on: ItemRegistry, SaveManager

## Signals
signal equipment_changed(slot: int, equipment_id: String)
signal stats_updated(new_stats: Dictionary)

## Constants
const TOTAL_SLOT_COUNT: int = 6

## Slot enum
enum Slot { WEAPON, HELM, CHEST, GLOVES, BOOTS, ACCESSORY }

## State
var _equipped_slots: Dictionary = {}  # {slot: {id, level}}
var _slot_compatibility: Dictionary = {}  # Maps equipment.slot to manager slot
var _item_registry: Node = null  # Cached reference to ItemRegistry autoload

#region Public API

func equip(slot: int, equipment_id: String) -> bool:
	## Equip item to slot (checks compatibility)
	if slot < 0 or slot >= TOTAL_SLOT_COUNT:
		return false

	# Check slot compatibility via ItemRegistry
	if _item_registry and _item_registry.has_method("get_equipment"):
		var equipment_def: Dictionary = _item_registry.get_equipment(equipment_id)
		if equipment_def.is_empty():
			return false

		var equipment_slot: int = equipment_def.get("slot", -1)
		if equipment_slot != slot:
			push_warning("Equipment %s incompatible with slot %d" % [equipment_id, slot])
			return false

	_equipped_slots[slot] = {
		id = equipment_id,
		level = 0,
	}

	emit_signal("equipment_changed", slot, equipment_id)
	_emit_stats_update()
	return true

func unequip(slot: int) -> void:
	## Remove equipment from slot
	if slot < 0 or slot >= TOTAL_SLOT_COUNT:
		return

	_equipped_slots.erase(slot)
	emit_signal("equipment_changed", slot, "")
	_emit_stats_update()

func get_equipped(slot: int) -> String:
	## Returns equipment ID in slot, or empty string
	var equipped: Dictionary = _equipped_slots.get(slot, {})
	return equipped.get("id", "")

func get_equipped_level(slot: int) -> int:
	## Returns enhancement level of equipped item
	var equipped: Dictionary = _equipped_slots.get(slot, {})
	return equipped.get("level", 0)

func set_equipped_level(slot: int, level: int) -> void:
	## Set enhancement level (called by EnhancementWorkflow)
	if not _equipped_slots.has(slot):
		return

	_equipped_slots[slot].level = level
	_emit_stats_update()

func get_total_stats() -> Dictionary:
	## Sum all equipped + enhancement stats
	var total_attack: int = 0
	var total_defense: int = 0
	var total_power: int = 0

	for slot in _equipped_slots:
		var equipped: Dictionary = _equipped_slots[slot]
		var equipment_id: String = equipped.get("id", "")
		if equipment_id.is_empty():
			continue  # Skip empty slots
		var level: int = equipped.get("level", 0)
		if _item_registry and _item_registry.has_method("get_enhanced_stats"):
			var enhanced: Dictionary = _item_registry.get_enhanced_stats(equipment_id, level)
			total_attack += enhanced.get("attack", 0)
			total_defense += enhanced.get("defense", 0)
			total_power += enhanced.get("power", 0)

	return {
		attack = total_attack,
		defense = total_defense,
		power = total_power,
	}

func get_all_equipped() -> Dictionary:
	return _equipped_slots.duplicate()

func set_all_equipped(equipped: Dictionary) -> void:
	_equipped_slots = equipped.duplicate()
	_emit_stats_update()

#endregion

#region Lifecycle

func _ready():
	# Cache ItemRegistry reference
	_item_registry = get_node("/root/ItemRegistry")
	# Initialize all slots empty
	for i in range(TOTAL_SLOT_COUNT):
		_equipped_slots[i] = {id = "", level = 0}
	# Give player a starting weapon for MVP testing
	equip(0, "weapon_sword_001")

#endregion

#region Internal

func _emit_stats_update() -> void:
	var stats: Dictionary = get_total_stats()
	emit_signal("stats_updated", stats)

#endregion