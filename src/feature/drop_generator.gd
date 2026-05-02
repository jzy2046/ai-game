extends Node
# DropGenerator - Feature Layer
# NOTE: No class_name - autoload singleton, accessed via DropGenerator globally
# Implements drop table RNG logic

## Signals

## State
var _drop_tables: Dictionary = {}
var _rng: RandomNumberGenerator
# Cached autoload reference
var _item_registry: Node = null

#region Public API

func generate_drops(floor: int) -> Dictionary:
	## Generate random drops based on floor level
	var gold: int = 10 + floor * 5
	var materials: Dictionary = {"enhancement_stone": 1 + floor / 2}
	var equipment: Array = []

	# Equipment drop chance (10% base, +5% per floor)
	var drop_chance: float = 0.1 + floor * 0.05
	if _rng.randf() < drop_chance:
		if _item_registry and _item_registry.has_method("get_all_equipment_ids"):
			var equipment_ids: Array = _item_registry.get_all_equipment_ids()
			if equipment_ids.size() > 0:
				var random_id: String = equipment_ids[_rng.randi_range(0, equipment_ids.size() - 1)]
				equipment.append(random_id)

	return {
		gold = gold,
		materials = materials,
		equipment = equipment,
	}

#endregion

#region Lifecycle

func _ready():
	_item_registry = get_node("/root/ItemRegistry")
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

#endregion