extends Node
class_name ItemRegistry

## ItemRegistry - Core Layer
## Implements: ADR-0011 Item Registry Ownership Model
## TR IDs: TR-regist-001

## Signals
signal registry_loaded()

## Constants
const EQUIPMENT_PATH: String = "res://data/equipment.json"
const MATERIALS_PATH: String = "res://data/materials.json"
const MAX_ENHANCEMENT_LEVEL: int = 10
const ENHANCEMENT_ATTACK_MULTIPLIER: float = 0.1

## State
var _equipment_db: Dictionary = {}
var _material_db: Dictionary = {}
var _rarity_modifiers: Dictionary = {}

## Rarity enum
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

#region Public API

func get_equipment(equipment_id: String) -> Dictionary:
	## Get equipment definition by ID
	if not _equipment_db.has(equipment_id):
		push_warning("Equipment ID not found: %s" % equipment_id)
		return {}
	return _equipment_db[equipment_id]

func get_material(material_id: String) -> Dictionary:
	## Get material definition by ID
	if not _material_db.has(material_id):
		push_warning("Material ID not found: %s" % material_id)
		return {}
	return _material_db[material_id]

func get_rarity_modifier(rarity: int) -> Dictionary:
	## Get stat multiplier for rarity tier
	return _rarity_modifiers.get(rarity, {attack_mult = 1.0, defense_mult = 1.0})

func get_enhanced_stats(equipment_id: String, level: int) -> Dictionary:
	## Calculate enhanced stats for equipment at given level
	var base: Dictionary = get_equipment(equipment_id)
	if base.is_empty():
		return {}

	# Clamp level to max
	level = mini(level, MAX_ENHANCEMENT_LEVEL)

	var attack: int = _calc_enhanced_stat(base.get("base_attack", 0), level)
	var defense: int = _calc_enhanced_stat(base.get("base_defense", 0), level)
	var power: int = _calc_enhanced_stat(base.get("base_power", 0), level)

	return {
		attack = attack,
		defense = defense,
		power = power,
	}

func get_all_equipment_ids() -> Array:
	return _equipment_db.keys()

func get_all_material_ids() -> Array:
	return _material_db.keys()

#endregion

#region Lifecycle

func _ready():
	_load_data()
	_setup_rarity_modifiers()

#endregion

#region Internal

func _load_data() -> void:
	## Load equipment and materials from JSON files
	# Equipment
	var eq_file := FileAccess.open(EQUIPMENT_PATH, FileAccess.READ)
	if eq_file != null and eq_file.get_error() == OK:
		var json: String = eq_file.get_as_text()
		eq_file.close()
		var parsed: Variant = JSON.parse_string(json)
		if parsed is Dictionary:
			_equipment_db = parsed
		else:
			push_warning("Equipment JSON parse failed, using defaults")
			_setup_default_equipment()
	else:
		push_warning("Equipment file not found, using defaults")
		_setup_default_equipment()

	# Materials
	var mat_file := FileAccess.open(MATERIALS_PATH, FileAccess.READ)
	if mat_file != null and mat_file.get_error() == OK:
		var json: String = mat_file.get_as_text()
		mat_file.close()
		var parsed: Variant = JSON.parse_string(json)
		if parsed is Dictionary:
			_material_db = parsed
		else:
			push_warning("Materials JSON parse failed, using defaults")
			_setup_default_materials()
	else:
		push_warning("Materials file not found, using defaults")
		_setup_default_materials()

	emit_signal("registry_loaded")

func _setup_default_equipment() -> void:
	## MVP default equipment definitions
	_equipment_db = {
		"weapon_sword_001": {
			id = "weapon_sword_001",
			name = "Iron Sword",
			slot = 0,
			rarity = Rarity.COMMON,
			base_attack = 50,
			base_defense = 0,
			base_power = 50,
			icon = "res://assets/icons/weapon_sword.png",
		},
		"weapon_sword_002": {
			id = "weapon_sword_002",
			name = "Steel Sword",
			slot = 0,
			rarity = Rarity.UNCOMMON,
			base_attack = 75,
			base_defense = 0,
			base_power = 75,
			icon = "res://assets/icons/weapon_sword.png",
		},
		"armor_helm_001": {
			id = "armor_helm_001",
			name = "Iron Helm",
			slot = 1,
			rarity = Rarity.COMMON,
			base_attack = 0,
			base_defense = 30,
			base_power = 30,
			icon = "res://assets/icons/armor_helm.png",
		},
		"armor_chest_001": {
			id = "armor_chest_001",
			name = "Iron Chestplate",
			slot = 2,
			rarity = Rarity.COMMON,
			base_attack = 0,
			base_defense = 50,
			base_power = 50,
			icon = "res://assets/icons/armor_chest.png",
		},
		"armor_gloves_001": {
			id = "armor_gloves_001",
			name = "Iron Gloves",
			slot = 3,
			rarity = Rarity.COMMON,
			base_attack = 0,
			base_defense = 20,
			base_power = 20,
			icon = "res://assets/icons/armor_gloves.png",
		},
		"armor_boots_001": {
			id = "armor_boots_001",
			name = "Iron Boots",
			slot = 4,
			rarity = Rarity.COMMON,
			base_attack = 0,
			base_defense = 25,
			base_power = 25,
			icon = "res://assets/icons/armor_boots.png",
		},
		"accessory_ring_001": {
			id = "accessory_ring_001",
			name = "Copper Ring",
			slot = 5,
			rarity = Rarity.COMMON,
			base_attack = 10,
			base_defense = 10,
			base_power = 20,
			icon = "res://assets/icons/accessory_ring.png",
		},
	}

func _setup_default_materials() -> void:
	## MVP default material definitions
	_material_db = {
		"enhancement_stone": {
			id = "enhancement_stone",
			name = "Enhancement Stone",
			stackable = true,
			max_stack = 999,
			rarity = Rarity.COMMON,
		},
		"crystal_essence": {
			id = "crystal_essence",
			name = "Crystal Essence",
			stackable = true,
			max_stack = 200,
			rarity = Rarity.RARE,
		},
		"celestial_shard": {
			id = "celestial_shard",
			name = "Celestial Shard",
			stackable = true,
			max_stack = 50,
			rarity = Rarity.EPIC,
		},
	}

func _setup_rarity_modifiers() -> void:
	_rarity_modifiers = {
		Rarity.COMMON: {attack_mult = 1.0, defense_mult = 1.0},
		Rarity.UNCOMMON: {attack_mult = 1.1, defense_mult = 1.1},
		Rarity.RARE: {attack_mult = 1.2, defense_mult = 1.2},
		Rarity.EPIC: {attack_mult = 1.5, defense_mult = 1.5},
		Rarity.LEGENDARY: {attack_mult = 2.0, defense_mult = 2.0},
	}

func _calc_enhanced_stat(base: int, level: int) -> int:
	## Formula: floor(base * (1 + level * ENHANCEMENT_ATTACK_MULTIPLIER))
	var result: float = float(base) * (1.0 + float(level) * ENHANCEMENT_ATTACK_MULTIPLIER)
	return floori(result)

#endregion