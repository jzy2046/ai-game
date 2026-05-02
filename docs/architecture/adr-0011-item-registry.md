# ADR-0011: Item Registry Ownership Model

## Status
Accepted

## Context
24 GDDs reference equipment and material definitions. Without central registry:
- Equipment stats defined in multiple GDDs risk inconsistency
- Rarity modifiers scattered across systems
- Enhancement formula needs base stats from authoritative source

Architecture Principle 1: "Single Source of Truth for Data"

## Decision

### Registry Pattern

```gdscript
class_name ItemRegistry extends Node

# Singleton access (via autoload, not global EventBus)
# Alternative: Instance in scene tree, passed via dependency injection

var _equipment_db: Dictionary = {}  # {equipment_id: EquipmentDefinition}
var _material_db: Dictionary = {}  # {material_id: MaterialDefinition}
var _rarity_modifiers: Dictionary = {}  # {rarity: {attack_mult, defense_mult}}

# Equipment Definition Schema
# {
#   id: String,
#   name: String,
#   slot: int,  # 0-5 (matches EquipmentManager slots)
#   rarity: int,  # 0-4 (Common to Legendary)
#   base_attack: int,
#   base_defense: int,
#   base_power: int,
#   icon: String,  # Resource path
# }

# Material Definition Schema
# {
#   id: String,
#   name: String,
#   stackable: bool,
#   max_stack: int,
#   rarity: int,
# }
```

### API Pattern

```gdscript
func get_equipment(equipment_id: String) -> Dictionary:
    if not _equipment_db.has(equipment_id):
        push_warning("Equipment ID not found: " + equipment_id)
        return {}  # Graceful empty return
    return _equipment_db[equipment_id]

func get_material(material_id: String) -> Dictionary:
    if not _material_db.has(material_id):
        push_warning("Material ID not found: " + material_id)
        return {}
    return _material_db[material_id]

func get_rarity_multiplier(rarity: int) -> Dictionary:
    return _rarity_modifiers.get(rarity, {})

func get_enhanced_stats(equipment_id: String, level: int) -> Dictionary:
    var base: Dictionary = get_equipment(equipment_id)
    if base.is_empty():
        return {}
    
    return {
        attack = EnhancementCalculator.calc_enhanced_stat(base.base_attack, level),
        defense = EnhancementCalculator.calc_enhanced_stat(base.base_defense, level),
        power = EnhancementCalculator.calc_enhanced_stat(base.base_power, level),
    }
```

### Data Loading Pattern

```gdscript
func _ready():
    # Load from JSON data file (not hardcoded)
    var data_file: FileAccess = FileAccess.open("res://data/equipment.json", FileAccess.READ)
    if data_file.get_error() == OK:
        var json: String = data_file.get_as_text()
        _equipment_db = JSON.parse_string(json)
    
    var material_file: FileAccess = FileAccess.open("res://data/materials.json", FileAccess.READ)
    if material_file.get_error() == OK:
        _material_db = JSON.parse_string(material_file.get_as_text())
    
    # Rarity modifiers from constants
    _rarity_modifiers = {
        0: {attack_mult = 1.0, defense_mult = 1.0},  # Common
        1: {attack_mult = 1.1, defense_mult = 1.1},  # Uncommon
        2: {attack_mult = 1.2, defense_mult = 1.2},  # Rare
        3: {attack_mult = 1.5, defense_mult = 1.5},  # Epic
        4: {attack_mult = 2.0, defense_mult = 2.0},  # Legendary
    }
```

### Ownership Rules

| Data Type | Owner | Consumers |
|-----------|-------|-----------|
| Equipment definitions | ItemRegistry | EnemyController (drops), DropGenerator (tables), EnhancementCalculator (base stats), EquipmentManager (equipped) |
| Material definitions | ItemRegistry | MaterialInventory (stacks), EnhancementCalculator (requirements) |
| Rarity modifiers | ItemRegistry | DropGenerator (weights), EquipmentManager (display) |

**Violations**: Any module defining equipment stats directly (without calling ItemRegistry) violates Architecture Principle 1.

## Consequences

### Positive
- Single source of truth for all item data
- JSON data files allow tuning without code changes
- Graceful empty returns prevent crashes on missing IDs

### Negative
- Registry must be loaded before any consumer (boot order dependency)
- JSON parsing at boot adds startup time (minimal for MVP data size)

### Risks
- **Data file missing**: Graceful empty return, game may lack content
- **Autoload vs DI**: Autoload chosen for simplicity, DI would be cleaner

## ADR Dependencies
- None (Core layer — Registry is foundation for other Core modules)

## Engine Compatibility

| Domain | Engine Version | Risk | Verified |
|--------|---------------|------|----------|
| JSON | Godot 4.x | LOW | ✅ stable |
| FileAccess | Godot 4.4+ | MEDIUM | ✅ ADR-0001 pattern |

## GDD Requirements Addressed

| TR ID | Requirement | Decision |
|-------|-------------|----------|
| TR-regist-001 | Registry ownership model | ItemRegistry owns all equipment/material definitions, consumers query via get_equipment()/get_material() |