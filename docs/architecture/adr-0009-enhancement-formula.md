# ADR-0009: Enhancement Formula Implementation

## Status
Accepted

## Context
Equipment enhancement provides player progression. GDD defines:
- Enhancement level cap: MAX_ENHANCEMENT_LEVEL = 10
- Stat multiplier: enhanced_stat = floor(base * (1 + level * ENHANCEMENT_ATTACK_MULTIPLIER))
- ENHANCEMENT_ATTACK_MULTIPLIER = 0.1 (10% per level)
- Gold cost formula: floor(base_cost * (1 + level * cost_multiplier))
- Material cost tiers: levels 1-4, 5-7, 8-10 require different materials

Key constraints:
- Enhancement always succeeds (no failure, no RNG)
- Material requirements must be pre-checkable
- Preview stats must match actual result exactly

## Decision

### Static Calculator Pattern

```gdscript
class_name EnhancementCalculator

# No state — pure static functions

const MAX_ENHANCEMENT_LEVEL: int = 10
const ENHANCEMENT_ATTACK_MULTIPLIER: float = 0.1
const ENHANCEMENT_COST_MULTIPLIER: float = 0.5  # 50% increase per level

static func calc_enhanced_stat(base: int, level: int, multiplier: float = ENHANCEMENT_ATTACK_MULTIPLIER) -> int:
    # Formula: floor(base * (1 + level * multiplier))
    var result: float = base * (1.0 + level * multiplier)
    return floori(result)

static func calc_gold_cost(base_cost: int, current_level: int) -> int:
    # Cost to enhance from current_level to current_level + 1
    # Formula: floor(base_cost * (1 + current_level * cost_multiplier))
    var cost: float = base_cost * (1.0 + current_level * ENHANCEMENT_COST_MULTIPLIER)
    return floori(cost)

static func calc_material_cost(current_level: int) -> Dictionary:
    # Material requirements per level tier
    var requirements: Dictionary = {}
    
    # Base enhancement stone cost (increases with level)
    var stone_cost: int = current_level + 1  # 1→11 stones over levels 0→10
    requirements["enhancement_stone"] = stone_cost
    
    # Tier 2: Crystal Essence for levels 5-7
    if current_level >= 4:  # Level 5+ requires crystal
        requirements["crystal_essence"] = floori(current_level / 2)  # 2-4 essence
    
    # Tier 3: Celestial Shard for levels 8-10
    if current_level >= 7:  # Level 8+ requires shard
        requirements["celestial_shard"] = floori(current_level / 3)  # 2-4 shards
    
    return requirements

static func can_enhance(current_level: int) -> bool:
    return current_level < MAX_ENHANCEMENT_LEVEL
```

### Usage Pattern

```gdscript
# EnhancementWorkflow calls calculator for preview and execution
func get_preview(slot: int) -> Dictionary:
    var equipped: Dictionary = EquipmentManager.get_equipped(slot)
    var base_attack: int = ItemRegistry.get_equipment(equipped.id).base_attack
    var current_level: int = equipped.level
    var new_level: int = current_level + 1
    
    var current_attack: int = EnhancementCalculator.calc_enhanced_stat(base_attack, current_level)
    var new_attack: int = EnhancementCalculator.calc_enhanced_stat(base_attack, new_level)
    var gold_cost: int = EnhancementCalculator.calc_gold_cost(100, current_level)  # BASE_GOLD_COST=100
    var material_cost: Dictionary = EnhancementCalculator.calc_material_cost(current_level)
    
    return {
        current_attack = current_attack,
        new_attack = new_attack,
        gold_cost = gold_cost,
        material_cost = material_cost,
    }
```

### Constants

```gdscript
const MAX_ENHANCEMENT_LEVEL: int = 10
const ENHANCEMENT_ATTACK_MULTIPLIER: float = 0.1
const ENHANCEMENT_COST_MULTIPLIER: float = 0.5
const BASE_GOLD_COST: int = 100
```

## Consequences

### Positive
- Pure static functions (no state, testable)
- Formula matches GDD exactly (floor(base * (1 + level * 0.1)))
- Material tiers explicit in code

### Negative
- Material cost formula is heuristic (not from GDD formula)
- BASE_GOLD_COST hardcoded (should be tuning knob)

### Risks
- None — Math operations are stable

## ADR Dependencies
- ADR-0011 (Item Registry — base_attack from ItemRegistry)

## Engine Compatibility

| Domain | Engine Version | Risk | Verified |
|--------|---------------|------|----------|
| floori | Godot 4.x | LOW | ✅ stable |

## GDD Requirements Addressed

| TR ID | Requirement | Decision |
|-------|-------------|----------|
| TR-enhance-001 | Enhancement formula | floor(base * (1 + level * 0.1)), MAX_LEVEL=10, MULTIPLIER=0.1 |
| TR-enhance-002 | Material cost tiers | Level 1-4: stone, 5-7: +essence, 8-10: +shard |