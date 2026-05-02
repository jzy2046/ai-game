# 强化公式系统

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-05-01
> **Implements Pillar**: 稳定成长 + 爽感反馈

## Overview

强化公式系统是游戏的强化成本计算层，负责定义装备强化所需资源的计算公式。它作为物品数据库（静态装备定义）和装备强化系统（强化操作流程）之间的桥梁，为强化操作提供具体的金币消耗和材料消耗数值。

该系统定义两类成本公式：
- **金币成本公式**：计算每次强化所需的金币消耗，基于装备稀有度、当前强化等级、装备强化费用系数
- **材料成本公式**：计算每次强化所需的材料种类和数量（MVP阶段简化为单一材料类型）

强化公式系统不存储玩家的强化状态（这是存档系统的职责），不执行强化操作（这是装备强化系统的职责），只提供"如果强化这件装备到下一级，需要多少成本"的计算接口。玩家通过强化界面触发强化操作时，装备强化系统调用本系统的公式计算成本，验证资源充足后执行强化。

**MVP范围**：线性成本曲线，强化等级上限10级，金币为主要消耗，材料为辅助消耗。公式设计确保每次强化成本渐进增长，支撑支柱"稳定成长"（可预期的成本曲线）和"爽感反馈"（成本合理让玩家频繁强化，享受数值跳升）。

## Player Fantasy

强化公式系统支撑的核心玩家幻想是：

> **"成本透明，进步可期"** — 玩家每次打开强化界面，看到的不是随机费用或复杂公式，而是清晰、可预期的成本数字。+1级需要多少金币，+5级需要多少材料，玩家一眼就能算出。这种"透明感"服务于支柱"稳定成长"：没有隐藏成本，没有突然的价格暴涨，玩家可以提前规划强化路径，知道何时能达成下一个数值里程碑。

**锚定时刻**：第一次准备强化EPIC装备的时刻。玩家刚击败第5层BOSS，获得一件EPIC护甲。打开强化界面，看到+1强化需要300金币（比COMMON装备的100金币高3倍，符合稀有度乘数）。玩家犹豫片刻：先强化这件EPIC护甲？还是先把手里的COMMON武器升到+5积累材料？最终选择先强化COMMON武器 — 因为成本低，能立刻看到数值跳升的爽感反馈。这一刻，玩家感到"我的策略是对的"，成本曲线支撑了有意义的决策。

**强化公式作为"决策信心"的保障**：
- 成本渐进增长让玩家可以"先小后大" — 早期强化频繁，享受爽感反馈；后期强化谨慎，资源积累有意义
- 稀有度乘数让EPIC/LEGENDARY装备成为"值得投资"的目标，不是"太贵放弃"的负担
- 线性曲线避免了"突然贵10倍"的挫败感，支柱"稳定成长"的核心承诺

**参考时刻**：Idle Slayer — 强化成本清晰显示，玩家无需猜测；梦幻西游手游 — 强化费用渐进，玩家可以提前计算总投入。

**支柱对应**：
- 稳定成长：成本公式可预测，强化路径可规划，没有随机成本或失败风险
- 爽感反馈：早期强化成本低让玩家频繁强化，享受数值暴涨的视觉反馈
- 掌控节奏：玩家决定强化顺序（先COMMON还是先EPIC），成本曲线支撑策略选择
- 多元成长：不同稀有度成本不同，玩家有多条强化策略路线

## Detailed Design

### Core Rules

#### Rule 1: Gold Cost Formula

每次强化所需的金币消耗按线性公式计算：

```gdscript
gold_cost = floor(BASE_GOLD_COST * (current_level + 1) * rarity_multiplier * equipment_cost_coefficient)
```

**变量定义**:
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| BASE_GOLD_COST | int | 50–200 | tuning knob | 基础金币成本，用于COMMON装备+0→+1强化 |
| current_level | int | 0–9 | save data | 当前强化等级（强化+0→+1时current_level=0） |
| rarity_multiplier | float | 1.0–5.0 | ItemDatabase | 稀有度成本乘数，查询RARITY_COST_TABLE |
| equipment_cost_coefficient | float | 0.8–3.0 | ItemDatabase | 装备个体成本系数，从装备定义获取 |

**计算示例**:
Iron Blade (COMMON, cost_coefficient=1.0) +0→+1:
```
gold_cost = floor(100 * (0 + 1) * 1.0 * 1.0) = floor(100) = 100 gold
```

Guardian Plate (EPIC, cost_coefficient=2.5) +0→+1:
```
gold_cost = floor(100 * (0 + 1) * 3.0 * 2.5) = floor(750) = 750 gold
```

---

#### Rule 2: Material Cost Formula

每次强化所需的材料消耗按线性公式计算（MVP简化为单一材料类型）：

```gdscript
material_cost = floor(BASE_MATERIAL_COST * (current_level + 1) * MATERIAL_LEVEL_MULTIPLIER)
```

**变量定义**:
| Variable | Type | Range | Source | Description |
|----------|------|-------|--------|-------------|
| BASE_MATERIAL_COST | int | 1–3 | tuning knob | 基础材料数量，用于+0→+1强化 |
| current_level | int | 0–9 | save data | 当前强化等级 |
| MATERIAL_LEVEL_MULTIPLIER | float | 1.0–2.0 | tuning knob | 材料随等级增长的乘数 |

**MVP配置**: BASE_MATERIAL_COST=1, MATERIAL_LEVEL_MULTIPLIER=1.0（简化为每级固定1个材料）

**材料类型**: MVP使用 `mat_enhance_stone_common`（Enhancement Stone）作为唯一材料。

**计算示例**:
Iron Blade +0→+1:
```
material_cost = floor(1 * (0 + 1) * 1.0) = 1 Enhancement Stone
```

Guardian Plate +5→+6:
```
material_cost = floor(1 * (5 + 1) * 1.0) = 6 Enhancement Stones
```

---

#### Rule 3: Level Progression Rules

强化等级从0（未强化）开始，最高到10（MAX_ENHANCEMENT_LEVEL）。

**有效强化操作**:
| Current Level | Target Level | Valid? | Cost Calculation |
|---------------|--------------|--------|------------------|
| 0 | 1 | ✓ | current_level=0 |
| 1 | 2 | ✓ | current_level=1 |
| 9 | 10 | ✓ | current_level=9 |
| 10 | 11 | ✗ | 已达上限，拒绝强化 |
| -1 | 0 | ✗ | 无效等级，拒绝强化 |

**强化顺序**: 只能逐级强化，不能跳级（0→1→2→...→10）。不允许直接从+0强化到+5。

---

#### Rule 4: Rarity Multiplier Lookup

稀有度乘数从 物品数据库 定义中查询：

```gdscript
func get_rarity_cost_multiplier(rarity: Rarity) -> float:
    const RARITY_COST_TABLE = {
        Rarity.COMMON: 1.0,
        Rarity.UNCOMMON: 1.5,
        Rarity.RARE: 2.0,
        Rarity.EPIC: 3.0,
        Rarity.LEGENDARY: 5.0
    }
    return RARITY_COST_TABLE.get(rarity, 1.0)  # fallback to COMMON
```

**来源**: 此表定义在 物品数据库 GDD Rule 4，强化公式系统引用该表。

---

#### Rule 5: Equipment Cost Coefficient Lookup

装备个体成本系数从 物品数据库 装备定义中查询：

```gdscript
func get_equipment_cost_coefficient(equipment_id: String) -> float:
    var equipment = ItemDatabase.get_equipment(equipment_id)
    if equipment == null:
        return 1.0  # fallback
    return equipment.enhancement_cost_coefficient
```

**用途**: 允许同稀有度装备有不同成本（例如强力装备成本系数更高）。

---

#### Rule 6: Interface Methods

`EnhancementFormulaSystem` 提供以下查询接口：

| Method | Parameters | Return | Purpose |
|--------|------------|--------|---------|
| `calculate_gold_cost(equipment_id, current_level)` | equipment_id: String, current_level: int | int | 计算单次强化金币成本 |
| `calculate_material_cost(equipment_id, current_level)` | equipment_id: String, current_level: int | Dictionary | 计算单次强化材料成本 `{ material_id: quantity }` |
| `calculate_total_cost(equipment_id, current_level)` | equipment_id: String, current_level: int | Dictionary | 计算完整成本 `{ gold: int, materials: Dictionary }` |
| `can_enchant(equipment_id, current_level)` | equipment_id: String, current_level: int | bool | 检查是否可以强化（等级未达上限且装备有效） |

---

#### Rule 7: Input Validation Rules

**等级范围验证**:
```gdscript
func validate_level(current_level: int) -> bool:
    return current_level >= 0 and current_level < MAX_ENHANCEMENT_LEVEL
```

**装备ID验证**:
```gdscript
func validate_equipment(equipment_id: String) -> bool:
    return ItemDatabase.has_equipment(equipment_id)
```

**验证失败处理**:
- 等级超出范围 → 返回 `{ gold: -1, materials: {} }` 表示无效，日志警告
- 装备ID无效 → 返回 `{ gold: -1, materials: {} }` 表示无效，日志警告
- 已达上限 → `can_enchant()` 返回 `false`

---

#### Rule 8: Cumulative Cost Calculation (Helper)

为方便玩家规划，提供累计成本计算：

```gdscript
func calculate_cumulative_cost(equipment_id: String, from_level: int, to_level: int) -> Dictionary:
    var total_gold = 0
    var total_materials = {}
    
    for level in range(from_level, to_level):
        var cost = calculate_total_cost(equipment_id, level)
        total_gold += cost.gold
        for mat_id in cost.materials:
            total_materials[mat_id] = total_materials.get(mat_id, 0) + cost.materials[mat_id]
    
    return { gold: total_gold, materials: total_materials }
```

**用途**: 显示"从+0强化到+10需要多少资源"的总成本预览。

---

### States and Transitions

强化公式系统是**无状态**的计算层。它不维护任何游戏状态，只响应查询请求并返回计算结果。

**调用流程**:
```
装备强化系统 → 调用 calculate_total_cost(equipment_id, current_level)
             → EnhancementFormulaSystem 查询 ItemDatabase
             → 计算成本
             → 返回结果
             → 装备强化系统 验证资源 + 执行强化
```

系统本身无状态转换，但依赖 物品数据库 的静态数据和 存档系统 的当前强化等级数据。

---

### Interactions with Other Systems

| System | Direction | Interface | Data Flow |
|--------|-----------|-----------|-----------|
| **物品数据库** | Upstream (Hard) | `get_equipment(id)`, `get_rarity_cost_multiplier(rarity)` | 提供装备定义、稀有度乘数、个体成本系数 |
| **存档系统** | Upstream (Hard) | `equipment.enhancement_levels[id]` | 提供当前强化等级作为current_level输入 |
| **装备强化系统** | Downstream (Hard) | `calculate_total_cost(id, level)` | 强化系统调用公式计算成本，验证后执行强化 |
| **数值显示系统** | Downstream (Soft) | `calculate_cumulative_cost(id, 0, 10)` | UI显示总强化成本预览（规划界面） |
| **货币系统** | Downstream (Soft) | — | 强化系统扣除金币后通知货币系统更新 |
| **材料系统** | Downstream (Soft) | — | 强化系统扣除材料后通知材料系统更新 |

**Interface Contracts**:
- 所有cost计算方法返回格式为 `{ gold: int, materials: { material_id: int } }`
- 返回值`gold = -1`表示计算失败（无效输入）
- 材料Dictionary为空 `{}` 表示该强化不需要材料（MVP暂不使用此场景）

## Formulas

### Formula 1: Gold Cost per Enhancement Level

The gold cost per enhancement level formula is defined as:

`gold_cost = floor(BASE_GOLD_COST * (current_level + 1) * rarity_multiplier * equipment_cost_coefficient)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_GOLD_COST | `BGC` | int | 100 (default) | 基础金币成本，tuning knob |
| current_level | `L` | int | 0–9 | 当前强化等级 |
| rarity_multiplier | `RM` | float | 1.0–5.0 | 稀有度乘数，查询RARITY_COST_TABLE |
| equipment_cost_coefficient | `EC` | float | 0.8–3.0 | 装备个体成本系数 |
| gold_cost | `GC` | int | 50–30000+ | 单次强化金币消耗 |

**Output Range:** 
- Minimum: `floor(50 * 1 * 1.0 * 0.8) = 40` gold (low coefficient COMMON +0→+1)
- Maximum: `floor(200 * 10 * 5.0 * 3.0) = 30000` gold (high coefficient LEGENDARY +9→+10)

**Example:**
Iron Blade (COMMON, cost_coefficient=1.0) 强化 +0→+1:
```
gold_cost = floor(100 * (0 + 1) * 1.0 * 1.0)
          = floor(100)
          = 100 gold
```

Guardian Plate (EPIC, cost_coefficient=2.5) 强化 +5→+6:
```
gold_cost = floor(100 * (5 + 1) * 3.0 * 2.5)
          = floor(100 * 6 * 7.5)
          = floor(4500)
          = 4500 gold
```

---

### Formula 2: Material Cost per Enhancement Level

The material cost per enhancement level formula is defined as:

`material_cost = floor(BASE_MATERIAL_COST * (current_level + 1) * MATERIAL_LEVEL_MULTIPLIER)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_MATERIAL_COST | `BMC` | int | 1 (default) | 基础材料数量，tuning knob |
| current_level | `L` | int | 0–9 | 当前强化等级 |
| MATERIAL_LEVEL_MULTIPLIER | `MLM` | float | 1.0 (default) | 材料等级乘数，tuning knob |
| material_cost | `MC` | int | 1–10 | 单次强化材料消耗 |

**Output Range (MVP):**
- Minimum: `floor(1 * 1 * 1.0) = 1` Enhancement Stone (+0→+1)
- Maximum: `floor(1 * 10 * 1.0) = 10` Enhancement Stones (+9→+10)

**MVP简化**: 材料类型固定为 `mat_enhance_stone_common`，不考虑稀有度差异。

**Example:**
Iron Blade 强化 +0→+1:
```
material_cost = floor(1 * (0 + 1) * 1.0)
              = floor(1)
              = 1 Enhancement Stone
```

Guardian Plate 强化 +5→+6:
```
material_cost = floor(1 * (5 + 1) * 1.0)
              = floor(6)
              = 6 Enhancement Stones
```

---

### Formula 3: Cumulative Gold Cost to Target Level

The cumulative gold cost from level 0 to level N is defined as:

`cumulative_gold = Σ(floor(BASE_GOLD_COST * (L + 1) * RM * EC)) for L from 0 to N-1`

For linear progression with fixed rarity and coefficient, this simplifies to:

`cumulative_gold = floor(BASE_GOLD_COST * RM * EC * N * (N + 1) / 2)` (sum of arithmetic series)

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_GOLD_COST | `BGC` | int | 100 | 基础金币成本 |
| rarity_multiplier | `RM` | float | 1.0–5.0 | 稀有度乘数 |
| equipment_cost_coefficient | `EC` | float | 0.8–3.0 | 装备个体成本系数 |
| target_level | `N` | int | 1–10 | 目标强化等级 |
| cumulative_gold | `CG` | int | 100–165000+ | 累计金币成本 |

**Example:**
Iron Blade (COMMON, EC=1.0) 从+0强化到+10:
```
cumulative_gold = floor(100 * 1.0 * 1.0 * 10 * 11 / 2)
                = floor(100 * 55)
                = floor(5500)
                = 5500 gold
```

Guardian Plate (EPIC, EC=2.5) 从+0强化到+10:
```
cumulative_gold = floor(100 * 3.0 * 2.5 * 10 * 11 / 2)
                = floor(100 * 7.5 * 55)
                = floor(41250)
                = 41250 gold
```

---

### Formula 4: Cumulative Material Cost to Target Level

The cumulative material cost from level 0 to level N is defined as:

`cumulative_material = Σ(floor(BASE_MATERIAL_COST * (L + 1) * MLM)) for L from 0 to N-1`

For MVP with MLM=1.0, this simplifies to:

`cumulative_material = floor(BASE_MATERIAL_COST * N * (N + 1) / 2)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_MATERIAL_COST | `BMC` | int | 1 | 基础材料数量 |
| MATERIAL_LEVEL_MULTIPLIER | `MLM` | float | 1.0 | 材料等级乘数 |
| target_level | `N` | int | 1–10 | 目标强化等级 |
| cumulative_material | `CM` | int | 1–55 | 累计材料数量 |

**Example:**
从+0强化到+10:
```
cumulative_material = floor(1 * 10 * 11 / 2)
                     = floor(55)
                     = 55 Enhancement Stones
```

---

### Summary Table: Cost Examples for MVP Equipment

| Equipment | Rarity | EC | Level | Gold Cost | Material Cost |
|-----------|--------|-----|-------|-----------|---------------|
| Iron Blade | COMMON | 1.0 | +0→+1 | 100 | 1 |
| Iron Blade | COMMON | 1.0 | +5→+6 | 600 | 6 |
| Iron Blade | COMMON | 1.0 | +9→+10 | 1000 | 10 |
| Iron Blade | COMMON | 1.0 | 0→10 (cumulative) | 5500 | 55 |
| Guardian Plate | EPIC | 2.5 | +0→+1 | 750 | 1 |
| Guardian Plate | EPIC | 2.5 | +5→+6 | 4500 | 6 |
| Guardian Plate | EPIC | 2.5 | +9→+10 | 7500 | 10 |
| Guardian Plate | EPIC | 2.5 | 0→10 (cumulative) | 41250 | 55 |

## Edge Cases

### Edge Case 1: Invalid Equipment ID

**Scenario**: `calculate_total_cost()` 被调用时equipment_id不存在于物品数据库。

**Expected Behavior**:
- 查询 `ItemDatabase.get_equipment(id)` 返回 `null`
- 方法返回 `{ gold: -1, materials: {} }` 表示计算失败
- 日志警告："Equipment [id] not found in ItemDatabase"
- 装备强化系统检查返回值，gold=-1表示失败，拒绝强化操作

**Test**: 调用 `calculate_total_cost("equip_invalid_xyz", 0)` → 验证返回 `{ gold: -1, materials: {} }`，日志记录警告。

---

### Edge Case 2: Level Out of Range

**Scenario**: `calculate_total_cost()` 被调用时current_level超出有效范围（不在0–9内）。

**Expected Behavior**:
- 等级 < 0 → 视为数据损坏，返回 `{ gold: -1, materials: {} }`，日志错误："Invalid enhancement level: [L]"
- 等级 ≥ 10 → 已达上限，返回 `{ gold: -1, materials: {} }`，日志警告："Equipment already at max level"
- `can_enchant()` 对两种情况返回 `false`

**Test**: 
- 调用 `calculate_total_cost("equip_weapon_iron_blade", -1)` → 返回 `{ gold: -1 }`，错误日志
- 调用 `calculate_total_cost("equip_weapon_iron_blade", 10)` → 返回 `{ gold: -1 }`，警告日志

---

### Edge Case 3: Equipment at Max Level

**Scenario**: 装备已强化到+10，装备强化系统请求计算成本。

**Expected Behavior**:
- `can_enchant()` 返回 `false`
- `calculate_total_cost()` 返回 `{ gold: -1, materials: {} }`
- 装备强化系统检测到 `can_enchant=false`，不发起强化操作
- UI显示"已达最大强化等级"

**Test**: 调用 `can_enchant("equip_weapon_iron_blade", 10)` → 返回 `false`。

---

### Edge Case 4: Missing Equipment Cost Coefficient

**Scenario**: 物品数据库中装备定义缺少 `enhancement_cost_coefficient` 字段（数据不完整）。

**Expected Behavior**:
- `get_equipment_cost_coefficient()` 检测字段缺失
- 返回默认值 `1.0`（COMMON基准）
- 日志警告："Equipment [id] missing enhancement_cost_coefficient, using default 1.0"
- 继续计算，不中断强化流程

**Test**: 物品数据库某装备缺少字段 → 调用 `calculate_gold_cost()` → 验证使用默认值1.0计算。

---

### Edge Case 5: Negative Cost Result

**Scenario**: 由于异常输入组合（例如系数为负值），公式计算出负数成本。

**Expected Behavior**:
- `floor()` 结果为负数 → 检测异常，返回 `{ gold: -1, materials: {} }`
- 日志错误："Negative cost calculated: inputs [BGC, L, RM, EC]"
- 装备强化系统拒绝操作

**Note**: 正常数据下不应出现负数成本（所有输入应为正数）。此边缘情况防御数据损坏。

**Test**: 模拟 `equipment_cost_coefficient = -0.5` → 调用公式 → 验证返回 `{ gold: -1 }`。

---

### Edge Case 6: Cumulative Cost with Invalid Range

**Scenario**: `calculate_cumulative_cost()` 被调用时 `from_level > to_level` 或范围无效。

**Expected Behavior**:
- `from_level >= to_level` → 返回 `{ gold: 0, materials: {} }`（无强化发生）
- `to_level > MAX_ENHANCEMENT_LEVEL` → 只计算到上限，返回有效部分
- 日志警告如果范围超出上限

**Test**: 
- 调用 `calculate_cumulative_cost(id, 5, 3)` → 返回 `{ gold: 0 }`
- 调用 `calculate_cumulative_cost(id, 0, 15)` → 计算0→10部分，警告超出上限

---

### Edge Case 7: Material ID Not Found

**Scenario**: 材料系统查询 `mat_enhance_stone_common` 时ID不存在（数据未加载）。

**Expected Behavior**:
- 强化公式系统不负责材料验证（这是材料系统的职责）
- 计算材料成本时不检查材料是否存在
- 装备强化系统在扣除材料时验证，材料不存在 → 强化失败，日志错误

**Note**: 公式层只计算"需要多少"，不验证"是否拥有"或"是否存在"。验证是强化系统的职责。

**Test**: 材料数据未加载 → 调用 `calculate_material_cost()` → 返回 `{ mat_enhance_stone_common: 5 }`（正常计算，不验证存在性）。

---

### Edge Case 8: Rarity Not in RARITY_COST_TABLE

**Scenario**: 新增稀有度但未更新RARITY_COST_TABLE（未来扩展场景）。

**Expected Behavior**:
- `get_rarity_cost_multiplier()` 查表失败 → 返回默认值 `1.0`
- 日志警告："Rarity [value] not found in cost table, using default 1.0"
- 使用默认值继续计算，不中断

**Test**: 模拟稀有度值超出枚举 → 调用 `get_rarity_cost_multiplier()` → 返回 `1.0`，警告日志。

## Dependencies

### Upstream Dependencies (Hard)

| System | Type | Interface | Description |
|--------|------|-----------|-------------|
| **物品数据库** | Hard | `get_equipment(id) → Dictionary`, `RARITY_COST_TABLE` lookup | 提供装备定义、稀有度乘数表、个体成本系数。强化公式系统依赖此数据计算成本。 |
| **存档系统** | Hard | `equipment.enhancement_levels[id] → int` | 提供当前强化等级作为 `current_level` 输入。无此数据无法计算升级成本。 |

**Constraint from 物品数据库 GDD**:
- EquipmentSlot枚举定义已存在（MAIN_HAND, OFF_HAND, HEAD, BODY, ACCESSORY_1, ACCESSORY_2）
- 稀有度乘数表定义在Rule 4: COMMON=1.0, UNCOMMON=1.5, RARE=2.0, EPIC=3.0, LEGENDARY=5.0
- 每个装备有 `enhancement_cost_coefficient` 字段（默认1.0）

**Constraint from 存档系统 GDD**:
- 存档数据包含 `equipment.enhancement_levels = { equipment_id: level }`
- 强化等级数据持久化是存档系统的职责

---

### Upstream Dependencies (Soft)

| System | Type | Interface | Description |
|--------|------|-----------|-------------|
| **Godot Math Functions** | Soft | `floor()`, arithmetic operators | 内置数学函数，引擎API总是可用。 |

---

### Downstream Dependencies (Hard)

| System | Type | Interface Used | Description |
|--------|------|---------------|-------------|
| **装备强化系统** | Hard | `calculate_total_cost(id, level)`, `can_enchant(id, level)` | 强化系统调用公式计算成本，验证资源后执行强化。公式系统提供计算服务。 |
| **数值显示系统** | Hard | `calculate_cumulative_cost(id, 0, 10)` | UI显示总成本预览，帮助玩家规划强化路径。 |

**Interface Contracts**:
- 所有计算方法返回格式: `{ gold: int, materials: { material_id: quantity } }`
- `gold = -1` 表示计算失败（无效输入或已达上限）
- `materials = {}` 表示无材料消耗或计算失败

---

### Downstream Dependencies (Soft)

| System | Type | Interface Used | Description |
|--------|------|---------------|-------------|
| **货币系统** | Soft | — | 强化系统扣除金币后通知货币系统更新余额。公式系统不直接调用货币系统。 |
| **材料系统** | Soft | — | 强化系统扣除材料后通知材料系统更新库存。公式系统不直接调用材料系统。 |
| **视觉反馈系统** | Soft | — | 强化成功时的反馈触发由强化系统负责，公式系统只计算成本。 |

---

### External Dependencies (Non-Game Systems)

| Dependency | Type | Usage |
|------------|------|-------|
| **Godot Dictionary** | Hard | 返回值数据结构 |
| **Godot int/float** | Hard | 数值计算基础类型 |

---

### Dependency Graph

```
[存档系统] ──────────────┐
                         │
                         v
[物品数据库] ────────→ [强化公式系统] ────────→ [装备强化系统]
                         │                         │
                         │                         v
                         +───────────────────→ [数值显示系统]
                                                 (累计成本预览)
```

## Tuning Knobs

| Knob | Default | Safe Range | Unit | What It Affects | Extreme Behavior |
|------|---------|------------|------|-----------------|------------------|
| **BASE_GOLD_COST** | 100 | 50–200 | gold | 基础强化成本基准值 | 太低：强化太便宜，金币积累失去意义；太高：早期强化负担重，挫败感 |
| **BASE_MATERIAL_COST** | 1 | 1–3 | stones | 基础材料消耗数量 | 太低：材料系统无压力；太高：材料收集成为瓶颈，强化频率下降 |
| **MATERIAL_LEVEL_MULTIPLIER** | 1.0 | 1.0–2.0 | ratio | 材料随等级增长的速率 | 1.0=线性固定增长；2.0=后期材料需求翻倍 |
| **MAX_ENHANCEMENT_LEVEL** | 10 | 5–20 | levels | 强化等级上限（定义于物品数据库） | 太低：成长线过短；太高：数值膨胀，后期内容设计困难 |

---

### Referenced Tuning Knobs (Defined in 物品数据库)

| Knob | Value | Source GDD | Note |
|------|-------|------------|------|
| **ENHANCEMENT_ATTACK_MULTIPLIER** | 0.1 | item-database.md | 每级攻击力增长10%，影响强化收益感知 |
| **ENHANCEMENT_DEFENSE_MULTIPLIER** | 0.1 | item-database.md | 每级防御力增长10%，影响强化收益感知 |
| **RARITY_COST_MULTIPLIER_COMMON** | 1.0 | item-database.md | COMMON装备成本基准 |
| **RARITY_COST_MULTIPLIER_UNCOMMON** | 1.5 | item-database.md | UNCOMMON装备成本×1.5 |
| **RARITY_COST_MULTIPLIER_RARE** | 2.0 | item-database.md | RARE装备成本×2 |
| **RARITY_COST_MULTIPLIER_EPIC** | 3.0 | item-database.md | EPIC装备成本×3 |
| **RARITY_COST_MULTIPLIER_LEGENDARY** | 5.0 | item-database.md | LEGENDARY装备成本×5 |

---

### Session Feasibility Analysis

**假设**: 玩家每5分钟地牢run获得 ~500 gold。

**COMMON武器 (+0→+10) 总成本**: 5500 gold
- 需要约 11 次地牢run (55分钟游戏时间，分散在多次session)
- 平均每次session可强化 2-3 级

**EPIC护甲 (+0→+10) 总成本**: 41250 gold
- 需要约 83 次地牢run (415分钟游戏时间)
- 这是长期目标，支撑数周成长线

**材料消耗**:
- +0→+10 总材料: 55 Enhancement Stones
- 若每次run掉落 2-3 stones，需约 20-30 次run
- 材料比金币更容易积累，符合设计意图（金币为主消耗）

---

### Tuning Knob Configuration File

```json
{
  "version": "1.0.0",
  "enhancement_formula": {
    "base_gold_cost": 100,
    "base_material_cost": 1,
    "material_level_multiplier": 1.0,
    "max_enhancement_level": 10
  }
}
```

配置文件路径: `assets/data/tuning/enhancement_formula_config.json`

## Visual/Audio Requirements

强化公式系统是纯计算层，**无直接视觉/音频需求**。所有强化相关的视觉反馈由装备强化系统触发，视觉反馈系统执行。

**此系统为视觉反馈系统提供的数据支撑**:
- 成本数值 → 装备强化系统 → UI显示强化费用
- 累计成本 → 数值显示系统 → 规划界面显示总成本预览

**MVP阶段**: 强化公式系统只负责计算，不涉及视觉/音频实现。

---

## UI Requirements

| Requirement | Specification | Priority |
|-------------|---------------|----------|
| **强化成本显示** | 强化界面显示本次强化所需金币和材料数量 | MVP |
| **累计成本预览** | 规划界面显示从当前等级强化到+10的总成本 | MVP |
| **成本对比** | 显示不同装备强化成本的差异（玩家可比较强化策略） | MVP |
| **资源不足提示** | 当玩家资源不足时显示"金币不足"或"材料不足" | MVP |

**数据来源**:
- 单次成本: `calculate_total_cost(equipment_id, current_level)`
- 累计成本: `calculate_cumulative_cost(equipment_id, current_level, MAX_ENHANCEMENT_LEVEL)`

## Acceptance Criteria

### Gold Cost Calculation

- **GIVEN** Iron Blade (COMMON, cost_coefficient=1.0) at level 0, **WHEN** `calculate_gold_cost("equip_weapon_iron_blade", 0)` is called, **THEN** result is `100` gold.

- **GIVEN** Iron Blade at level 5, **WHEN** `calculate_gold_cost("equip_weapon_iron_blade", 5)` is called, **THEN** result is `600` gold.

- **GIVEN** Guardian Plate (EPIC, cost_coefficient=2.5) at level 0, **WHEN** `calculate_gold_cost("equip_armor_guardian_plate", 0)` is called, **THEN** result is `750` gold.

- **GIVEN** Guardian Plate at level 9, **WHEN** `calculate_gold_cost("equip_armor_guardian_plate", 9)` is called, **THEN** result is `7500` gold.

---

### Material Cost Calculation

- **GIVEN** any equipment at level 0, **WHEN** `calculate_material_cost(equipment_id, 0)` is called, **THEN** result is `{ "mat_enhance_stone_common": 1 }`.

- **GIVEN** any equipment at level 5, **WHEN** `calculate_material_cost(equipment_id, 5)` is called, **THEN** result is `{ "mat_enhance_stone_common": 6 }`.

- **GIVEN** any equipment at level 9, **WHEN** `calculate_material_cost(equipment_id, 9)` is called, **THEN** result is `{ "mat_enhance_stone_common": 10 }`.

---

### Cumulative Cost Calculation

- **GIVEN** Iron Blade from level 0 to 10, **WHEN** `calculate_cumulative_cost("equip_weapon_iron_blade", 0, 10)` is called, **THEN** result is `{ gold: 5500, materials: { "mat_enhance_stone_common": 55 } }`.

- **GIVEN** Guardian Plate from level 0 to 10, **WHEN** `calculate_cumulative_cost("equip_armor_guardian_plate", 0, 10)` is called, **THEN** result is `{ gold: 41250, materials: { "mat_enhance_stone_common": 55 } }`.

- **GIVEN** from_level > to_level (e.g., 5→3), **WHEN** `calculate_cumulative_cost(id, 5, 3)` is called, **THEN** result is `{ gold: 0, materials: {} }`.

---

### Input Validation

- **GIVEN** invalid equipment ID "equip_invalid_xyz", **WHEN** `calculate_total_cost("equip_invalid_xyz", 0)` is called, **THEN** result is `{ gold: -1, materials: {} }` and warning is logged.

- **GIVEN** invalid level -1, **WHEN** `calculate_total_cost("equip_weapon_iron_blade", -1)` is called, **THEN** result is `{ gold: -1, materials: {} }` and error is logged.

- **GIVEN** level 10 (at max), **WHEN** `calculate_total_cost("equip_weapon_iron_blade", 10)` is called, **THEN** result is `{ gold: -1, materials: {} }`.

- **GIVEN** level 10 (at max), **WHEN** `can_enchant("equip_weapon_iron_blade", 10)` is called, **THEN** result is `false`.

---

### Rarity Multiplier Lookup

- **GIVEN** Rarity.COMMON, **WHEN** `get_rarity_cost_multiplier(COMMON)` is called, **THEN** result is `1.0`.

- **GIVEN** Rarity.EPIC, **WHEN** `get_rarity_cost_multiplier(EPIC)` is called, **THEN** result is `3.0`.

- **GIVEN** invalid rarity value, **WHEN** `get_rarity_cost_multiplier(invalid_value)` is called, **THEN** result is `1.0` (fallback) and warning is logged.

---

### Interface Contract Compliance

- **GIVEN** any valid calculation, **WHEN** `calculate_total_cost()` returns, **THEN** the return value is a Dictionary with keys `gold` (int) and `materials` (Dictionary).

- **GIVEN** any calculation failure, **WHEN** `calculate_total_cost()` fails, **THEN** `gold` value is `-1`.

- **GIVEN** any valid calculation, **WHEN** `calculate_material_cost()` returns, **THEN** materials Dictionary contains `"mat_enhance_stone_common"` key with int value.

---

### Integration with 物品数据库

- **GIVEN** 物品数据库 loaded with MVP equipment, **WHEN** EnhancementFormulaSystem queries equipment definition, **THEN** `get_equipment_cost_coefficient()` returns correct values for all 10 MVP equipment.

- **GIVEN** 物品数据库 RARITY_COST_TABLE, **WHEN** EnhancementFormulaSystem queries rarity multiplier, **THEN** values match 物品数据库 GDD Rule 4 definitions.

---

### Performance

- **GIVEN** any calculation request, **WHEN** formula methods execute, **THEN** computation completes within 1ms (simple arithmetic operations).

- **GIVEN** cumulative cost from 0 to 10, **WHEN** `calculate_cumulative_cost()` executes, **THEN** computation completes within 5ms (10 iterations).

---

### No Hardcoded Values

- **GIVEN** EnhancementFormulaSystem implementation, **WHEN** code is reviewed, **THEN** all cost constants (BASE_GOLD_COST, BASE_MATERIAL_COST) are loaded from config file or tuning knobs, not hardcoded inline.

## Open Questions

| # | Question | Owner | Target Resolution | Status |
|---|----------|-------|-------------------|--------|
| 1 | Should material cost vary by equipment rarity? MVP simplifies to uniform material cost, but future versions may require rarity-based material multipliers. | Economy Designer | Post-MVP evaluation | Open |
| 2 | Should enhancement cost curve be linear or polynomial? MVP uses linear for predictability, but polynomial curves (e.g., cost = base * level^1.5) could create more nuanced progression. | Systems Designer | Post-MVP tuning | Open |
| 3 | How should cumulative cost preview handle partial enhancement? If player is at +3 and wants to see cost to +10, should UI show remaining 7 levels or total 10 levels? | UX Designer | During 强化系统 UI design | Open |
| 4 | Should BASE_GOLD_COST be per-equipment-type (weapons vs armor vs accessories) or uniform? MVP uses uniform, but weapons might warrant higher costs. | Economy Designer | Post-MVP tuning | Open |
| 5 | What is the gold-to-material exchange rate if player lacks materials but has excess gold? MVP may not include material purchase, but future versions might. | Economy Designer | Post-MVP feature planning | Open |