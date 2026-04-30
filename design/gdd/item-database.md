# 物品数据库 (Item Database)

> **Status**: Approved
> **Author**: user + agents
> **Last Updated**: 2026-04-30
> **Approved**: 2026-04-30 (Solo mode — no design-review)
> **Implements Pillar**: 多元成长 + 稳定成长

## Overview

物品数据库是游戏的经济数据基础设施层，负责定义和管理所有物品的静态属性数据。它存储装备和材料的定义数据，为依赖系统（装备槽系统、强化公式系统、掉落表系统、战斗系统等）提供物品属性的统一查询接口。

物品数据库不存储玩家的物品持有状态（这是存档系统的职责），只存储物品的"模板"定义。例如，物品数据库定义"铁剑"的基础攻击力为10、稀有度为Common；存档系统存储玩家当前持有1件铁剑、强化等级为+3。

MVP阶段物品数据库定义:
- **装备**: 5-10种，涵盖武器、护甲等类型
- **材料**: 3-5种，用于装备强化消耗
- **属性**: 攻击力、防御力、稀有度、强化费用系数等

玩家通过掉落获得装备、通过强化提升装备属性、通过切换装备优化战斗效果，都与物品数据库的定义数据交互。支柱"多元成长"的实现依赖物品数据库提供多样化的装备选择。

## Player Fantasy

物品数据库支撑的核心玩家幻想是：

> **"每件装备都是成长的见证"** — 玩家从地牢获得的每一件装备、每一份材料，都是可感知的进步。装备的属性数值清晰可见，强化后的数值增长明确显示。玩家知道这件装备能带来什么，知道强化后会变成什么 — 可预期、可量化、无惊喜的不确定性（只有确定性的爽感）。

这支撑支柱"多元成长"：
- 不同装备有不同属性组合，玩家可以根据战斗需求选择装备
- 材料收集是另一条成长线，为强化提供资源
- 未来扩展（词缀、技能）预留了更多成长方向

这支撑支柱"稳定成长"：
- 装备属性是固定定义，强化必定成功带来可预期的数值增长
- 玩家不会因为"不知道这件装备好不好"而产生焦虑
- 所有装备都有明确用途，没有"垃圾装备"概念（即使是Common也能强化）

**参考**: 暗黑破坏神 — 装备属性清晰，玩家一眼看出装备是否值得使用；梦幻西游手游 — 装备成长线明确，强化路径清晰。

## Detailed Design

### Core Rules

#### Rule 1: Equipment Definition Schema

装备定义是静态数据模板，存储在 `assets/data/equipment/`。每个装备物品的数据结构：

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | 唯一标识符，格式: `equip_[type]_[name]` |
| `display_name` | String | 本化显示名称 |
| `description` | String | 描述文本 |
| `type` | EquipmentType | 枚举: WEAPON, ARMOR, ACCESSORY |
| `slot` | EquipmentSlot | 枚举: MAIN_HAND, OFF_HAND, HEAD, BODY, ACCESSORY_1, ACCESSORY_2 |
| `rarity` | Rarity | 枚举: COMMON, UNCOMMON, RARE, EPIC, LEGENDARY |
| `base_attack` | int | 基础攻击力 (>= 0) |
| `base_defense` | int | 基础防御力 (>= 0) |
| `enhancement_cost_coefficient` | float | 强化费用系数 |
| `icon_path` | String | 图标资源路径 |

**示例**:
```json
{
  "id": "equip_weapon_iron_blade",
  "display_name": "Iron Blade",
  "type": "WEAPON",
  "slot": "MAIN_HAND",
  "rarity": "COMMON",
  "base_attack": 10,
  "base_defense": 0,
  "enhancement_cost_coefficient": 1.0,
  "icon_path": "res://assets/art/icons/equipment/iron_blade.png"
}
```

#### Rule 2: Equipment Slot Enumeration

```gdscript
enum EquipmentSlot {
    MAIN_HAND,   # 主武器
    OFF_HAND,    # 副手（盾牌/副武器）
    HEAD,        # 头部
    BODY,        # 身体
    ACCESSORY_1, # 饰品槽1
    ACCESSORY_2  # 饰品槽2
}
```

**槽位-类型兼容矩阵**:
| Slot | Allowed Types |
|------|---------------|
| MAIN_HAND | WEAPON |
| OFF_HAND | WEAPON, ARMOR (盾牌) |
| HEAD | ARMOR |
| BODY | ARMOR |
| ACCESSORY_1, ACCESSORY_2 | ACCESSORY |

#### Rule 3: Material Definition Schema

材料定义存储在 `assets/data/materials/`：

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | 唯一标识符，格式: `mat_[category]_[name]` |
| `display_name` | String | 显示名称 |
| `description` | String | 描述文本 |
| `category` | MaterialCategory | 枚举: ENHANCEMENT, CURRENCY, CRAFTING |
| `rarity` | Rarity | 稀有度 |
| `max_stack` | int | 最大堆叠数量 (0 = 无限) |
| `icon_path` | String | 图标路径 |

**示例**:
```json
{
  "id": "mat_enhance_stone_common",
  "display_name": "Enhancement Stone",
  "category": "ENHANCEMENT",
  "rarity": "COMMON",
  "max_stack": 999,
  "icon_path": "res://assets/art/icons/materials/enhance_stone_common.png"
}
```

#### Rule 4: Rarity System

**稀有度枚举**:
```gdscript
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }
```

**稀有度颜色映射 (Art Bible)**:
| Rarity | Color | Hex |
|--------|-------|-----|
| COMMON | Earthen Brown | #8B6914 |
| UNCOMMON | Verdant Growth | #7CB342 |
| RARE | Soft Lavender | #9B7BB8 |
| EPIC | Celebration Orange | #F27D16 |
| LEGENDARY | Golden Amber | #E5A50A |

**稀有度强化费用乘数**:
| Rarity | Cost Multiplier |
|--------|-----------------|
| COMMON | 1.0 |
| UNCOMMON | 1.5 |
| RARE | 2.0 |
| EPIC | 3.0 |
| LEGENDARY | 5.0 |

#### Rule 5: Definition vs Instance Boundary

**ItemDatabase owns**: 静态定义（模板）
**Save system owns**: 玩家实例（持有状态）

```
Definition (ItemDatabase):
  "equip_weapon_iron_blade" → { base_attack: 10, rarity: COMMON }

Instance (Save data):
  equipment.inventory = ["equip_weapon_iron_blade", ...]
  equipment.slots = { "MAIN_HAND": "equip_weapon_iron_blade" }
  equipment.enhancement_levels = { "equip_weapon_iron_blade": 3 }
```

**计算属性永不存储** — 均在runtime计算:
```gdscript
func get_equipment_attack(equipment_id: String, enhancement_level: int) -> int:
    var def = ItemDatabase.get_equipment(equipment_id)
    return floor(def.base_attack * (1 + enhancement_level * 0.1))
```

#### Rule 6: Data Storage Format

**目录结构**:
```
assets/
  data/
    equipment/
      weapons.json
      armor.json
      accessories.json
    materials/
      enhancement.json
      currency.json
    rarity_config.json
```

**JSON文件格式**: 每个文件包含 `version` 和 `items` 数组。

#### Rule 7: Query Interface

`ItemDatabase` 提供以下查询方法：

| Method | Return | Purpose |
|--------|--------|---------|
| `get_equipment(id)` | Dictionary | 获取单个装备定义 |
| `get_material(id)` | Dictionary | 获取单个材料定义 |
| `get_equipment_by_type(type)` | Array | 按类型获取装备列表 |
| `get_equipment_by_rarity(rarity)` | Array | 按稀有度获取装备列表 |
| `get_all_equipment_ids()` | Array[String] | 获取所有装备ID（掉落表配置用） |
| `has_equipment(id)` | bool | 检查装备是否存在 |
| `is_equipment_compatible_with_slot(id, slot)` | bool | 检查槽位兼容性 |
| `calculate_enhanced_attack(id, level)` | int | 计算强化后攻击力 |
| `calculate_enhanced_defense(id, level)` | int | 计算强化后防御力 |
| `get_rarity_color(rarity)` | Color | 获取稀有度颜色（UI用） |

#### Rule 8: MVP Equipment List (10 items)

**Weapons (3)**:
| ID | Name | Rarity | Slot | Attack | Defense | Cost Coeff |
|----|------|--------|------|--------|---------|------------|
| `equip_weapon_iron_blade` | Iron Blade | COMMON | MAIN_HAND | 10 | 0 | 1.0 |
| `equip_weapon_shadow_dagger` | Shadow Dagger | UNCOMMON | MAIN_HAND | 18 | 0 | 1.5 |
| `equip_weapon_dragon_slayer` | Dragon Slayer | RARE | MAIN_HAND | 35 | 0 | 2.5 |

**Armor (4)**:
| ID | Name | Rarity | Slot | Attack | Defense | Cost Coeff |
|----|------|--------|------|--------|---------|------------|
| `equip_armor_leather_vest` | Leather Vest | COMMON | BODY | 0 | 8 | 1.0 |
| `equip_armor_chain_mail` | Chain Mail | UNCOMMON | BODY | 0 | 15 | 1.5 |
| `equip_armor_guardian_plate` | Guardian Plate | EPIC | BODY | 5 | 50 | 2.5 |
| `equip_armor_iron_helm` | Iron Helm | COMMON | HEAD | 0 | 5 | 1.0 |

**Accessories (3)**:
| ID | Name | Rarity | Slot | Attack | Defense | Cost Coeff |
|----|------|--------|------|--------|---------|------------|
| `equip_accessory_ring_power` | Ring of Power | UNCOMMON | ACCESSORY_1/2 | 5 | 2 | 1.2 |
| `equip_accessory_amulet_vitality` | Amulet of Vitality | RARE | ACCESSORY_1/2 | 0 | 15 | 2.0 |
| `equip_accessory_fate_pendant` | Fate Pendant | EPIC | ACCESSORY_1/2 | 10 | 10 | 2.8 |

#### Rule 9: MVP Materials List (5 items)

**Enhancement Materials (3)**:
| ID | Name | Rarity | Category | Max Stack |
|----|------|--------|----------|-----------|
| `mat_enhance_stone_common` | Enhancement Stone | COMMON | ENHANCEMENT | 999 |
| `mat_enhance_crystal_essence` | Crystal Essence | RARE | ENHANCEMENT | 99 |
| `mat_enhance_celestial_shard` | Celestial Shard | EPIC | ENHANCEMENT | 50 |

**Currency (2)**:
| ID | Name | Rarity | Category | Max Stack |
|----|------|--------|----------|-----------|
| `mat_currency_gold` | Gold | COMMON | CURRENCY | 0 (无限) |
| `mat_currency_gem` | Gem | RARE | CURRENCY | 9999 |

---

### States and Transitions

物品数据库是静态数据层，**无状态转换**。

数据加载流程：
1. Game Start → `_ready()` → 加载所有JSON文件
2. 解析JSON → 存入内存Dictionary
3. 构建索引（按类型、按稀有度）
4. 验证ID格式和唯一性
5. 数据就绪，等待查询请求

---

### Interactions with Other Systems

| System | Data Flow | Interface |
|--------|-----------|-----------|
| **存档系统** (Upstream) | 存档 → 物品ID → ItemDatabase查询定义 | `get_equipment(id)`, `get_material(id)` |
| **战斗系统** (Downstream) | ItemDatabase → base_attack/base_defense → 战斗计算 | `calculate_enhanced_attack(id, level)` |
| **强化系统** (Downstream) | ItemDatabase → enhancement_cost_coefficient → 计算强化费用 | `get_equipment(id).enhancement_cost_coefficient` |
| **掉落表系统** (Downstream) | ItemDatabase → 所有装备ID → 配置掉落表 | `get_all_equipment_ids()` |
| **装备槽系统** (Downstream) | ItemDatabase → slot/type → 检查兼容性 | `is_equipment_compatible_with_slot(id, slot)` |
| **数值显示系统** (Downstream) | ItemDatabase → rarity/color → UI显示 | `get_rarity_color(rarity)` |
| **敌人系统** (Downstream) | ItemDatabase → 装备定义 → 敌人掉落配置 | `get_equipment(id)` |

## Formulas

### Formula 1: Enhanced Attack

The enhanced attack formula is defined as:

`enhanced_attack = floor(base_attack * (1 + enhancement_level * ENHANCEMENT_ATTACK_MULTIPLIER))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_attack | — | int | 0–1000+ | Equipment's base attack value from definition |
| enhancement_level | — | int | 0–10 (MVP) | Current enhancement level of the equipment instance |
| ENHANCEMENT_ATTACK_MULTIPLIER | — | float | 0.1 (constant) | Per-level attack multiplier; defined in tuning knobs |

**Output Range:** Same as base_attack range at +0; up to 2x base_attack at +10 enhancement. Returns 0 if base_attack is 0.

**Constants:**
| Constant | Value | Purpose |
|----------|-------|---------|
| ENHANCEMENT_ATTACK_MULTIPLIER | 0.1 | Each enhancement level adds 10% to base attack |

**Example:**
Iron Blade +3 (COMMON weapon, base_attack = 10):
```
enhanced_attack = floor(10 * (1 + 3 * 0.1))
                = floor(10 * 1.3)
                = floor(13)
                = 13
```

Guardian Plate +5 (EPIC armor, base_attack = 5):
```
enhanced_attack = floor(5 * (1 + 5 * 0.1))
                = floor(5 * 1.5)
                = floor(7.5)
                = 7
```

---

### Formula 2: Enhanced Defense

The enhanced defense formula is defined as:

`enhanced_defense = floor(base_defense * (1 + enhancement_level * ENHANCEMENT_DEFENSE_MULTIPLIER))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_defense | — | int | 0–1000+ | Equipment's base defense value from definition |
| enhancement_level | — | int | 0–10 (MVP) | Current enhancement level of the equipment instance |
| ENHANCEMENT_DEFENSE_MULTIPLIER | — | float | 0.1 (constant) | Per-level defense multiplier; defined in tuning knobs |

**Output Range:** Same as base_defense range at +0; up to 2x base_defense at +10 enhancement. Returns 0 if base_defense is 0.

**Constants:**
| Constant | Value | Purpose |
|----------|-------|---------|
| ENHANCEMENT_DEFENSE_MULTIPLIER | 0.1 | Each enhancement level adds 10% to base defense |

**Example:**
Iron Blade +3 (COMMON weapon, base_defense = 0):
```
enhanced_defense = floor(0 * (1 + 3 * 0.1))
                 = floor(0)
                 = 0
```

Guardian Plate +5 (EPIC armor, base_defense = 50):
```
enhanced_defense = floor(50 * (1 + 5 * 0.1))
                 = floor(50 * 1.5)
                 = floor(75)
                 = 75
```

---

### Formula 3: Rarity Enhancement Cost Multiplier Lookup

The rarity enhancement cost multiplier is defined as:

`rarity_cost_multiplier = RARITY_COST_TABLE[rarity]`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| rarity | — | Rarity enum | COMMON–LEGENDARY | Equipment rarity from definition |

**Lookup Table:**
| Rarity | Multiplier | Rationale |
|--------|------------|-----------|
| COMMON | 1.0 | Baseline cost |
| UNCOMMON | 1.5 | +50% for rarity tier |
| RARE | 2.0 | 2x baseline |
| EPIC | 3.0 | 3x baseline |
| LEGENDARY | 5.0 | 5x baseline |

**Output Range:** 1.0 to 5.0 (discrete values per rarity tier).

**Note:** This formula returns the **rarity-based cost multiplier only**. The Enhancement System GDD defines the complete cost formula that combines this multiplier with the equipment's individual `enhancement_cost_coefficient` and other factors.

**Example:**
Iron Blade (COMMON):
```
rarity_cost_multiplier = RARITY_COST_TABLE[COMMON] = 1.0
```

Guardian Plate (EPIC):
```
rarity_cost_multiplier = RARITY_COST_TABLE[EPIC] = 3.0
```

---

### Summary Table: Formula Outputs for MVP Items

| Equipment | Enhancement | Base Atk | Enhanced Atk | Base Def | Enhanced Def | Rarity Mult |
|-----------|-------------|----------|--------------|----------|--------------|-------------|
| Iron Blade | +0 | 10 | 10 | 0 | 0 | 1.0 |
| Iron Blade | +3 | 10 | 13 | 0 | 0 | 1.0 |
| Iron Blade | +10 | 10 | 20 | 0 | 0 | 1.0 |
| Guardian Plate | +0 | 5 | 5 | 50 | 50 | 3.0 |
| Guardian Plate | +5 | 5 | 7 | 50 | 75 | 3.0 |
| Guardian Plate | +10 | 5 | 10 | 50 | 100 | 3.0 |

## Edge Cases

### Data Query Edge Cases

- **If `get_equipment()` is called with an invalid or unknown ID**: Return `null` and log a warning. Rationale: Downstream systems should handle missing data gracefully rather than crashing; returning null allows callers to check and fall back to defaults.

- **If `get_material()` is called with an invalid or unknown ID**: Return `null` and log a warning. Rationale: Same as equipment — allows graceful degradation in UI and gameplay systems.

- **If `has_equipment()` returns false for an ID that matches the naming pattern but doesn't exist**: The system correctly reports false. Rationale: Pattern matching is not validation; only IDs present in loaded data are valid.

- **If `get_all_equipment_ids()` is called before data is fully loaded**: Return an empty array and log an error. Rationale: Prevents partial data leaks; caller must retry or fail gracefully.

### Slot Compatibility Edge Cases

- **If `is_equipment_compatible_with_slot()` is called with mismatched types (e.g., WEAPON for BODY slot)**: Return `false`. Rationale: Enforces slot-type constraints defined in Rule 2; UI should prevent invalid equips before this check.

- **If an accessory is queried for a non-accessory slot**: Return `false`. Rationale: ACCESSORY_1 and ACCESSORY_2 are the only valid slots for accessories.

- **If a WEAPON is queried for OFF_HAND**: Return `true` only if the weapon type supports dual-wielding (future feature). For MVP, return `true` for all WEAPON types in OFF_HAND to allow shield/weapon flexibility. Rationale: MVP scope allows simple off-hand weapons; future dual-wield restrictions will be handled by a separate property.

### Enhancement Calculation Edge Cases

- **If `calculate_enhanced_attack()` is called with `enhancement_level` outside 0–10 range**: Clamp to valid range (0–10) and log a warning. Rationale: Prevents invalid calculations while still producing a usable result.

- **If `calculate_enhanced_attack()` is called with `base_attack = 0`**: Return `0` immediately without calculation. Rationale: Mathematically correct and avoids unnecessary floating-point operations.

- **If `calculate_enhanced_defense()` is called with `base_defense = 0`**: Return `0` immediately without calculation. Rationale: Same as attack — armor with no defense stat should not produce spurious values.

- **If enhancement level is negative (data corruption)**: Treat as `0` and log an error. Rationale: Defensive programming against save data corruption.

### Rarity Edge Cases

- **If `get_rarity_color()` is called with an invalid Rarity enum value**: Return COMMON color (Earthen Brown #8B6914) and log a warning. Rationale: UI must always have a color to display; falling back to the most common rarity is the safest default.

- **If equipment JSON defines a rarity string that doesn't match the Rarity enum**: Fail data validation on startup; do not load the item. Rationale: Invalid rarity breaks color coding and cost calculations; must be fixed in data.

### Data Loading Edge Cases

- **If a JSON file is missing or unreadable**: Log an error, skip that file, and continue loading others. The game remains playable with partial data. Rationale: Missing one category file (e.g., accessories.json) should not crash the entire game.

- **If a JSON file contains duplicate IDs**: Fail validation and log which IDs are duplicated. Do not proceed with data load. Rationale: Duplicate IDs cause undefined behavior in lookups; this is a data authoring error that must be fixed.

- **If an equipment definition is missing a required field**: Log the specific equipment ID and missing field, skip that item, continue loading. Rationale: One bad item should not block the entire category.

- **If data files are loaded twice (e.g., scene reload)**: Clear existing data before reloading. Rationale: Prevents stale data and ID conflicts from accumulating.

### Slot-Type Compatibility Matrix Edge Cases

- **If a new EquipmentType is added without updating the compatibility matrix**: All slots return `false` for that type. Rationale: Fail-safe behavior; new types must explicitly declare slot compatibility.

## Dependencies

### Upstream Dependencies (Hard)

| System | Interface | Description |
|--------|-----------|-------------|
| **存档系统 (Save System)** | `get_equipment(id)`, `get_material(id)` | Provides equipment instance IDs and enhancement levels from save data. ItemDatabase resolves IDs to definitions. |

### Upstream Dependencies (Soft)

| System | Interface | Description |
|--------|-----------|-------------|
| **Godot ResourceLoader** | `load(path)` | Built-in engine resource loading for JSON files. Non-blocking dependency — engine API always available. |

### Downstream Dependencies (Hard)

These systems cannot function without ItemDatabase:

| System | Required Interface | Usage |
|--------|-------------------|-------|
| **战斗系统 (Combat System)** | `calculate_enhanced_attack(id, level)`, `calculate_enhanced_defense(id, level)` | Resolves equipment stats for damage calculation. |
| **装备槽系统 (Equipment Slot System)** | `is_equipment_compatible_with_slot(id, slot)`, `get_equipment(id)` | Validates equip actions and displays item info. |
| **强化公式系统 (Enhancement Formula System)** | `get_equipment(id).enhancement_cost_coefficient`, rarity cost multiplier lookup | Calculates enhancement costs. |
| **掉落表系统 (Drop Table System)** | `get_all_equipment_ids()`, `get_equipment_by_rarity(rarity)` | Configures which items can drop. |
| **数值显示系统 (Stat Display System)** | `get_rarity_color(rarity)`, `get_equipment(id)` | Renders item tooltips and inventory UI. |

### Downstream Dependencies (Soft)

These systems benefit from ItemDatabase but have fallback behaviors:

| System | Required Interface | Fallback Behavior |
|--------|-------------------|-------------------|
| **敌人系统 (Enemy System)** | `get_equipment(id)` | Enemies can drop items by ID; if lookup fails, enemy still functions but drops nothing. |
| **装备掉落系统 (Equipment Drop System)** | `get_equipment_by_rarity(rarity)`, `get_all_equipment_ids()` | Can use hardcoded fallback lists if database unavailable. |
| **材料系统 (Material System)** | `get_material(id)` | Materials are queried similarly to equipment; fallback is no material display. |

### Interface Contracts

ItemDatabase guarantees these contracts to downstream systems:

1. **Immutability**: Equipment and material definitions do not change at runtime. All returned dictionaries are read-only snapshots.

2. **Null Safety**: All query methods return valid data or `null` — never throw exceptions for missing IDs.

3. **ID Format Stability**: IDs follow the pattern `equip_[type]_[name]` for equipment and `mat_[category]_[name]` for materials. This format is stable across versions.

4. **Load Order Independence**: All query methods work after `_ready()` completes. Calling before load completes returns empty results.

### Dependency Graph

```
                    [Godot ResourceLoader]
                            |
                            v
    [存档系统 (Save System)] → [ItemDatabase] → [战斗系统]
                                     |
                                     +------→ [装备槽系统]
                                     |
                                     +------→ [强化公式系统]
                                     |
                                     +------→ [掉落表系统]
                                     |
                                     +------→ [数值显示系统]
                                     |
                                     +------→ [敌人系统] (soft)
                                     |
                                     +------→ [装备掉落系统] (soft)
                                     |
                                     +------→ [材料系统] (soft)
```

## Tuning Knobs

| Knob | Type | Range | Default | Effect |
|------|------|-------|---------|--------|
| `ENHANCEMENT_ATTACK_MULTIPLIER` | float | 0.05 – 0.25 | 0.1 | Per-level attack boost. Higher = faster power growth per enhancement. Affects damage curve and gold sink value. |
| `ENHANCEMENT_DEFENSE_MULTIPLIER` | float | 0.05 – 0.25 | 0.1 | Per-level defense boost. Higher = faster survivability growth. Affects tankiness and healing gold sink. |
| `MAX_ENHANCEMENT_LEVEL` | int | 5 – 20 | 10 | Maximum enhancement level. Higher = longer progression tail. Affects endgame power ceiling. |
| `RARITY_COST_MULTIPLIER_COMMON` | float | 0.5 – 2.0 | 1.0 | Enhancement cost multiplier for COMMON items. Lower = cheaper to upgrade basic gear. |
| `RARITY_COST_MULTIPLIER_UNCOMMON` | float | 1.0 – 3.0 | 1.5 | Enhancement cost multiplier for UNCOMMON items. |
| `RARITY_COST_MULTIPLIER_RARE` | float | 1.5 – 4.0 | 2.0 | Enhancement cost multiplier for RARE items. |
| `RARITY_COST_MULTIPLIER_EPIC` | float | 2.0 – 5.0 | 3.0 | Enhancement cost multiplier for EPIC items. Higher = steeper cost for high-tier gear. |
| `RARITY_COST_MULTIPLIER_LEGENDARY` | float | 3.0 – 10.0 | 5.0 | Enhancement cost multiplier for LEGENDARY items. Highest cost tier for prestige items. |
| `MAX_STACK_ENHANCEMENT_COMMON` | int | 99 – 999 | 999 | Max stack for common enhancement materials. Higher = less inventory pressure for early-game farming. |
| `MAX_STACK_ENHANCEMENT_RARE` | int | 50 – 200 | 99 | Max stack for rare enhancement materials. |
| `MAX_STACK_ENHANCEMENT_EPIC` | int | 20 – 100 | 50 | Max stack for epic enhancement materials. Lower = forces frequent upgrades or sales. |
| `MAX_STACK_CURRENCY_GOLD` | int | 0 – 9999999 | 0 | Max stack for gold (0 = unlimited). Unlimited prevents gold cap frustration in idle games. |
| `MAX_STACK_CURRENCY_GEM` | int | 1000 – 99999 | 9999 | Max stack for premium currency. Forces spending decisions at high accumulation. |

### Tuning Knob Configuration File

All knobs are defined in `assets/data/tuning/item_database_config.json`:

```json
{
  "version": "1.0.0",
  "enhancement": {
    "attack_multiplier": 0.1,
    "defense_multiplier": 0.1,
    "max_level": 10
  },
  "rarity_cost_multipliers": {
    "COMMON": 1.0,
    "UNCOMMON": 1.5,
    "RARE": 2.0,
    "EPIC": 3.0,
    "LEGENDARY": 5.0
  },
  "stack_limits": {
    "enhancement_common": 999,
    "enhancement_rare": 99,
    "enhancement_epic": 50,
    "currency_gold": 0,
    "currency_gem": 9999
  }
}
```

### Balance Impact Analysis

| Knob Group | Increased Value Effect | Decreased Value Effect |
|------------|----------------------|------------------------|
| Enhancement multipliers | Faster power growth, shorter progression curve, reduced long-term engagement | Slower power growth, longer progression curve, may frustrate players |
| Rarity cost multipliers | Rare items become gold sinks, prestige for dedicated players | Rare items become accessible, reduced differentiation between tiers |
| Stack limits | More inventory space, less pressure to use/sell | Inventory management pressure, frequent upgrades/sales required |

### Safe Tuning Ranges

- **Enchantment multipliers**: 0.08–0.15 is the "comfort zone" where each level feels meaningful but doesn't trivialize content.
- **Rarity multipliers**: Keep EPIC and LEGENDARY at 2x+ the COMMON baseline to maintain tier prestige.
- **Stack limits**: For idle games, unlimited gold (0) is recommended; limit premium currency to create scarcity.

## Acceptance Criteria

### Data Loading

- **GIVEN** the game starts, **WHEN** ItemDatabase initializes, **THEN** all equipment JSON files are loaded and parsed without errors.
- **GIVEN** the game starts, **WHEN** ItemDatabase initializes, **THEN** all material JSON files are loaded and parsed without errors.
- **GIVEN** a JSON file is missing, **WHEN** ItemDatabase loads data, **THEN** the missing file is logged and the game continues with remaining data.
- **GIVEN** a JSON file contains invalid syntax, **WHEN** ItemDatabase loads data, **THEN** the parse error is logged with file path and line number.
- **GIVEN** equipment definitions contain duplicate IDs, **WHEN** ItemDatabase validates data, **THEN** validation fails and all duplicates are reported.
- **GIVEN** all data files are loaded, **WHEN** loading completes, **THEN** `get_all_equipment_ids()` returns exactly 10 equipment IDs.
- **GIVEN** all data files are loaded, **WHEN** loading completes, **THEN** `get_all_material_ids()` returns exactly 5 material IDs.

### Query Methods

- **GIVEN** a valid equipment ID `equip_weapon_iron_blade`, **WHEN** `get_equipment()` is called, **THEN** the returned dictionary contains `base_attack = 10`, `base_defense = 0`, `rarity = COMMON`.
- **GIVEN** a valid material ID `mat_enhance_stone_common`, **WHEN** `get_material()` is called, **THEN** the returned dictionary contains `category = ENHANCEMENT`, `max_stack = 999`.
- **GIVEN** an invalid equipment ID `equip_invalid_xyz`, **WHEN** `get_equipment()` is called, **THEN** `null` is returned and a warning is logged.
- **GIVEN** an invalid material ID `mat_invalid_xyz`, **WHEN** `get_material()` is called, **THEN** `null` is returned and a warning is logged.
- **GIVEN** equipment type `WEAPON`, **WHEN** `get_equipment_by_type(WEAPON)` is called, **THEN** exactly 3 weapons are returned.
- **GIVEN** rarity `RARE`, **WHEN** `get_equipment_by_rarity(RARE)` is called, **THEN** exactly 2 RARE items are returned (Dragon Slayer, Amulet of Vitality).
- **GIVEN** a valid equipment ID, **WHEN** `has_equipment()` is called, **THEN** `true` is returned.
- **GIVEN** an invalid equipment ID, **WHEN** `has_equipment()` is called, **THEN** `false` is returned.

### Slot Compatibility

- **GIVEN** equipment `equip_weapon_iron_blade` (WEAPON type), **WHEN** `is_equipment_compatible_with_slot(id, MAIN_HAND)` is called, **THEN** `true` is returned.
- **GIVEN** equipment `equip_weapon_iron_blade` (WEAPON type), **WHEN** `is_equipment_compatible_with_slot(id, BODY)` is called, **THEN** `false` is returned.
- **GIVEN** equipment `equip_armor_leather_vest` (ARMOR type, BODY slot), **WHEN** `is_equipment_compatible_with_slot(id, BODY)` is called, **THEN** `true` is returned.
- **GIVEN** equipment `equip_armor_leather_vest` (ARMOR type, BODY slot), **WHEN** `is_equipment_compatible_with_slot(id, HEAD)` is called, **THEN** `false` is returned.
- **GIVEN** equipment `equip_accessory_ring_power` (ACCESSORY type), **WHEN** `is_equipment_compatible_with_slot(id, ACCESSORY_1)` is called, **THEN** `true` is returned.
- **GIVEN** equipment `equip_accessory_ring_power` (ACCESSORY type), **WHEN** `is_equipment_compatible_with_slot(id, ACCESSORY_2)` is called, **THEN** `true` is returned.
- **GIVEN** equipment `equip_accessory_ring_power` (ACCESSORY type), **WHEN** `is_equipment_compatible_with_slot(id, MAIN_HAND)` is called, **THEN** `false` is returned.

### Enhancement Calculation

- **GIVEN** Iron Blade (base_attack = 10) at enhancement level 0, **WHEN** `calculate_enhanced_attack()` is called, **THEN** the result is `10`.
- **GIVEN** Iron Blade (base_attack = 10) at enhancement level 3, **WHEN** `calculate_enhanced_attack()` is called, **THEN** the result is `13`.
- **GIVEN** Iron Blade (base_attack = 10) at enhancement level 10, **WHEN** `calculate_enhanced_attack()` is called, **THEN** the result is `20`.
- **GIVEN** Iron Blade (base_defense = 0) at enhancement level 5, **WHEN** `calculate_enhanced_defense()` is called, **THEN** the result is `0`.
- **GIVEN** Guardian Plate (base_defense = 50) at enhancement level 5, **WHEN** `calculate_enhanced_defense()` is called, **THEN** the result is `75`.
- **GIVEN** enhancement level -1 (invalid), **WHEN** `calculate_enhanced_attack()` is called, **THEN** the level is clamped to 0 and a warning is logged.
- **GIVEN** enhancement level 15 (exceeds max), **WHEN** `calculate_enhanced_attack()` is called, **THEN** the level is clamped to 10 and a warning is logged.

### Rarity Color Mapping

- **GIVEN** rarity `COMMON`, **WHEN** `get_rarity_color()` is called, **THEN** the result is `Color("#8B6914")`.
- **GIVEN** rarity `UNCOMMON`, **WHEN** `get_rarity_color()` is called, **THEN** the result is `Color("#7CB342")`.
- **GIVEN** rarity `RARE`, **WHEN** `get_rarity_color()` is called, **THEN** the result is `Color("#9B7BB8")`.
- **GIVEN** rarity `EPIC`, **WHEN** `get_rarity_color()` is called, **THEN** the result is `Color("#F27D16")`.
- **GIVEN** rarity `LEGENDARY`, **WHEN** `get_rarity_color()` is called, **THEN** the result is `Color("#E5A50A")`.
- **GIVEN** an invalid rarity value, **WHEN** `get_rarity_color()` is called, **THEN** the result is `Color("#8B6914")` (COMMON fallback) and a warning is logged.

### ID Format Validation

- **GIVEN** an equipment ID not matching pattern `equip_[type]_[name]`, **WHEN** data is loaded, **THEN** validation fails and the malformed ID is reported.
- **GIVEN** a material ID not matching pattern `mat_[category]_[name]`, **WHEN** data is loaded, **THEN** validation fails and the malformed ID is reported.
- **GIVEN** an equipment ID with invalid type segment, **WHEN** data is loaded, **THEN** validation fails and the invalid type is reported.
- **GIVEN** a material ID with invalid category segment, **WHEN** data is loaded, **THEN** validation fails and the invalid category is reported.

### MVP Content Verification

- **GIVEN** ItemDatabase is loaded, **WHEN** equipment is queried, **THEN** all 10 MVP equipment items are present:
  - `equip_weapon_iron_blade`
  - `equip_weapon_shadow_dagger`
  - `equip_weapon_dragon_slayer`
  - `equip_armor_leather_vest`
  - `equip_armor_chain_mail`
  - `equip_armor_guardian_plate`
  - `equip_armor_iron_helm`
  - `equip_accessory_ring_power`
  - `equip_accessory_amulet_vitality`
  - `equip_accessory_fate_pendant`
- **GIVEN** ItemDatabase is loaded, **WHEN** materials are queried, **THEN** all 5 MVP materials are present:
  - `mat_enhance_stone_common`
  - `mat_enhance_crystal_essence`
  - `mat_enhance_celestial_shard`
  - `mat_currency_gold`
  - `mat_currency_gem`

## Open Questions

| # | Question | Owner | Target Resolution | Status |
|---|----------|-------|-------------------|--------|
| 1 | Should ItemDatabase support runtime hot-reload for debugging purposes (e.g., modifying JSON during playtest)? | Technical Director | Before production implementation | Open |
| 2 | How should localization be handled for display_name and description fields — inline in JSON or separate localization files? | Narrative Lead | Before localization sprint | Open |
| 3 | Should future equipment types (e.g., TWO_HANDED, DUAL_WIELD) require a new slot or reuse existing slots with special rules? | Game Designer | Before equipment expansion | Open |
| 4 | What is the data migration strategy if a future version changes the ID format (e.g., adding prefix for game version)? | Technical Director | Before first major version update | Open |
| 5 | Should ItemDatabase cache computed values (enhanced stats) or compute on every query? Performance vs. memory trade-off. | Technical Director | During architecture review | Open |
| 6 | Are there plans for equipment sets (set bonuses) in future versions? This would require a new `set_id` field. | Game Designer | Before set bonus implementation | Open |
| 7 | Should the rarity color mapping be configurable or remain hardcoded to Art Bible colors? | Art Director | Before production polish | Open |
| 8 | What happens if a player's save data references an equipment ID that was removed in a game update? | Save System Lead | During save system design | Open |

### Resolution Notes

- **Q5 Decision Framework**: Cache if queries exceed 100/second (unlikely in MVP idle game). Compute-on-demand for MVP to minimize complexity.
- **Q8 Needs Coordination**: This question must be resolved jointly with Save System before production implementation. Downstream systems (Equipment Slot System, Combat System) depend on this behavior.