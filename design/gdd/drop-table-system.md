# 掉落表系统

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: 稳定成长 + 爽感反馈

## Overview

掉落表系统是游戏的掉落配置和解析层，负责定义敌人击败后的物品掉落规则。它作为敌人系统（掉落触发来源）和物品数据库（物品定义）之间的桥梁，为装备掉落系统提供具体的掉落物品ID列表。

掉落表定义两部分内容：
- **掉落池**：哪些物品可能掉落（装备ID、材料ID）
- **掉落权重**：每个物品的掉落概率权重，用于随机选择

掉落表系统不存储玩家的物品持有状态（这是存档系统的职责），不执行物品发放（这是装备掉落系统的职责），只提供"给定掉落表ID，解析出本次掉落的物品列表"的计算接口。敌人击败时，敌人系统传递 `drop_table_id`，掉落表系统根据权重随机选择物品，返回给装备掉落系统展示和发放。

**MVP范围**：按地牢层级分层的掉落表配置（floor 1-3 基础、floor 4-6 进阶、floor 7-10 高级），支持装备和材料掉落，使用权重随机选择而非复杂概率公式。掉落表数量约3-5个，覆盖10层地牢难度曲线。

## Player Fantasy

掉落表系统支撑的核心玩家幻想是：

> **"每次击败都有收获"** — 掉落表是"收获确定性"的保障层。玩家击败敌人时，掉落表确保必定获得收益（材料必定掉落，装备有概率掉落）。这种"确定性"服务于支柱"稳定成长"：玩家不会遇到"击败敌人却什么都没得到"的挫败体验。

**掉落表作为"收获预期"的配置者**：
- 材料必定掉落（每次击败至少获得 Enhancement Stone）
- 装备概率掉落（rarity 越高的装备掉率越低，但高层敌人掉率更高）
- 掉落表分层让玩家知道"高层敌人掉落更好"

**锚定时刻（间接）**：第一次击败高层敌人获得稀有装备。玩家推进到floor 7，击败Shadow Knight，掉落表解析出一件 RARE Dragon Slayer。装备图标弹出、粒子爆发、数值飞溅。这一刻，玩家感到"高层敌人果然掉落更好" — 掉落表配置支撑了这种预期。

**参考时刻**：Idle Slayer — 每次击败敌人都有材料掉落，装备掉落作为额外惊喜；暗黑破坏神 — 掉落表分层，玩家知道BOSS掉落稀有装备概率更高。

**支柱对应**：
- 稳定成长：材料必定掉落确保每次战斗都有收益，没有"白打"体验
- 爽感反馈：掉落表配置让高层掉落更稀有装备，掉落弹出时爽感更强
- 掌控节奏：玩家可以选择推进高层以获得更好掉落（风险-收益权衡）
- 多元成长：不同掉落池提供不同装备类型，玩家有收集目标

## Detailed Design

### Core Rules

#### Rule 1: Drop Table Definition Schema

掉落表定义是静态数据模板，存储在 `assets/data/drop_tables/`。每个掉落表的数据结构：

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | 唯一标识符，格式: `drop_table_[tier]` |
| `display_name` | String | 显示名称（如"Floor 1-3 基础掉落"） |
| `floor_range` | Array[int] | 适用层级范围 [min, max] |
| `guaranteed_drops` | Array | 必定掉落的物品（材料） |
| `weighted_drops` | Array | 权重掉落的物品池（装备） |
| `drop_count_min` | int | 最小掉落物品数量（不含必定掉落） |
| `drop_count_max` | int | 最大掉落物品数量（不含必定掉落） |

**Guaranteed Drop Entry**:
| Field | Type | Description |
|-------|------|-------------|
| `item_id` | String | 物品ID（材料） |
| `quantity` | int | 数量（可以是范围 min-max） |

**Weighted Drop Entry**:
| Field | Type | Description |
|-------|------|-------------|
| `item_id` | String | 物品ID（装备） |
| `weight` | int | 权重值（越大越容易掉落） |

---

#### Rule 2: Drop Resolution Process

掉落解析流程在敌人击败时触发：

| Step | Action | Description |
|------|--------|-------------|
| 1 | 接收掉落表ID | 从敌人系统获取 `drop_table_id` |
| 2 | 加载掉落表定义 | 从 DropTableDatabase 获取配置 |
| 3 | 添加必定掉落 | 将 `guaranteed_drops` 全部加入结果列表 |
| 4 | 随机选择装备掉落数量 | `roll_drop_count = random_int(min, max)` |
| 5 | 权重随机选择装备 | 从 `weighted_drops` 按权重随机选择 `roll_drop_count` 个装备（不重复） |
| 6 | 返回掉落列表 | 返回 `{ guaranteed: [...], weighted: [...] }` |

**权重随机选择算法**:
```gdscript
func weighted_random_select_unique(entries: Array, count: int) -> Array:
    var available_entries = entries.duplicate()
    var selected = []
    for i in range(count):
        if available_entries.size() == 0:
            break  # 没有更多可用物品
        var total_weight = sum(entry.weight for entry in available_entries)
        var roll = random_int(1, total_weight)
        var cumulative = 0
        for entry in available_entries:
            cumulative += entry.weight
            if roll <= cumulative:
                selected.append(entry.item_id)
                available_entries.erase(entry)  # 移除已选择项，防止重复
                break
    return selected
```

---

#### Rule 3: Guaranteed Drops (Materials)

MVP阶段每个掉落表都有必定掉落的材料，确保"每次击败都有收获"。

**配置规则**:
- Floor 1-3: 必定掉落 1-2个 Enhancement Stone
- Floor 4-6: 必定掉落 2-3个 Enhancement Stone + 有概率 1个 Crystal Essence
- Floor 7-10: 必定掉落 3-5个 Enhancement Stone + 必定 1个 Crystal Essence
- Floor 10 BOSS: 必定掉落 5-10个 Enhancement Stone + 必定 1个 Celestial Shard

---

#### Rule 4: Weighted Drops (Equipment)

装备掉落使用权重池，权重越高越容易掉落。

**权重配置原则**:
- COMMON 装备: 高权重（基础掉落池主力）
- UNCOMMON 装备: 中权重（进阶掉落池）
- RARE 装备: 低权重（稀有掉落）
- EPIC 装备: 极低权重（BOSS掉落池）

**权重数值范围**:
| Rarity | Weight Range | Notes |
|--------|--------------|-------|
| COMMON | 50-100 | 基础掉落池主力，掉落概率高 |
| UNCOMMON | 20-40 | 进阶掉落池，中等概率 |
| RARE | 5-15 | 稀有掉落，低概率 |
| EPIC | 1-5 | BOSS掉落池，极低概率 |

---

#### Rule 5: MVP Drop Table Definitions

**掉落表 1: Floor 1-3 基础掉落** (`drop_table_floor_1_3`)
| Field | Value |
|-------|-------|
| id | drop_table_floor_1_3 |
| floor_range | [1, 3] |
| guaranteed_drops | [{ mat_enhance_stone_common, qty: 1-2 }] |
| weighted_drops | [{ Iron Blade, weight=100 }, { Leather Vest, weight=80 }, { Iron Helm, weight=60 }] |
| drop_count_min | 0 |
| drop_count_max | 1 |

**掉落表 2: Floor 4-6 进阶掉落** (`drop_table_floor_4_6`)
| Field | Value |
|-------|-------|
| id | drop_table_floor_4_6 |
| floor_range | [4, 6] |
| guaranteed_drops | [{ mat_enhance_stone_common, qty: 2-3 }, { mat_enhance_crystal_essence, qty: 0-1, probability=0.3 }] |
| weighted_drops | [{ Shadow Dagger, weight=50 }, { Chain Mail, weight=40 }, { Ring of Power, weight=30 }] |
| drop_count_min | 0 |
| drop_count_max | 1 |

**掉落表 3: Floor 7-10 高级掉落** (`drop_table_floor_7_10`)
| Field | Value |
|-------|-------|
| id | drop_table_floor_7_10 |
| floor_range | [7, 10] |
| guaranteed_drops | [{ mat_enhance_stone_common, qty: 3-5 }, { mat_enhance_crystal_essence, qty: 1 }] |
| weighted_drops | [{ Dragon Slayer, weight=15 }, { Amulet of Vitality, weight=12 }, { Fate Pendant, weight=8 }, { Guardian Plate, weight=5 }] |
| drop_count_min | 0 |
| drop_count_max | 1 |

**掉落表 4: Floor 10 BOSS掉落** (`drop_table_floor_10_boss`)
| Field | Value |
|-------|-------|
| id | drop_table_floor_10_boss |
| floor_range | [10, 10] |
| guaranteed_drops | [{ mat_enhance_stone_common, qty: 5-10 }, { mat_enhance_celestial_shard, qty: 1 }] |
| weighted_drops | [{ Guardian Plate, weight=30 }, { Dragon Slayer, weight=25 }, { Fate Pendant, weight=20 }] |
| drop_count_min | 1 |
| drop_count_max | 2 |

---

#### Rule 6: Interface Methods

`DropTableSystem` 提供以下接口：

| Method | Parameters | Return | Purpose |
|--------|------------|--------|---------|
| `resolve_drop(drop_table_id)` | drop_table_id: String | Dictionary | 解析掉落，返回 `{ guaranteed: [...], weighted: [...] }` |
| `get_drop_table(id)` | id: String | Dictionary | 获取掉落表定义 |
| `get_drop_tables_for_floor(floor_id)` | floor_id: int | Array | 获取适用于该层的掉落表列表 |
| `has_drop_table(id)` | id: String | bool | 检查掉落表是否存在 |

**返回格式**:
```gdscript
{
    guaranteed: [
        { item_id: "mat_enhance_stone_common", quantity: 2 },
        { item_id: "mat_enhance_crystal_essence", quantity: 1 }
    ],
    weighted: [
        { item_id: "equip_weapon_shadow_dagger", quantity: 1 }
    ]
}
```

---

#### Rule 7: Drop Quantity Randomization

必定掉落的材料数量可以随机范围：

`quantity = random_int(min_quantity, max_quantity)`

**配置示例**: `{ mat_enhance_stone_common, quantity: 1-2 }` → 每次掉落 1 或 2 个

**Weighted drops 的 quantity 固定为 1**（每次只掉落1件装备，不掉落多件同装备）。

---

#### Rule 8: Duplicate Equipment Prevention

权重选择时，**不允许重复选择同一装备ID**。算法在 Rule 2 中定义。

---

### States and Transitions

掉落表系统是**无状态**的配置层。它不维护任何运行时状态，只响应查询请求并返回计算结果。

**调用流程**:
```
敌人击败 → enemy_defeated 信号
        → 战斗系统传递 drop_table_id
        → DropTableSystem.resolve_drop(id)
        → 加载配置 + 权重随机
        → 返回掉落列表
        → 装备掉落系统处理展示和发放
```

---

### Interactions with Other Systems

| System | Direction | Interface | Data Flow |
|--------|-----------|-----------|-----------|
| **敌人系统** | Upstream (Hard) | `enemy.drop_table_id` | 敌人定义包含掉落表ID，传递给本系统解析 |
| **物品数据库** | Upstream (Hard) | `get_equipment(id)`, `get_material(id)` | 验证掉落物品ID有效性，获取物品定义用于展示 |
| **装备掉落系统** | Downstream (Hard) | `resolve_drop(id)` | 接收掉落列表，处理物品发放和UI展示 |
| **战斗系统** | Downstream (Soft) | `combat_victory` 信号 | 战斗胜利触发掉落解析流程 |
| **视觉反馈系统** | Downstream (Soft) | — | 掉落弹出时的视觉效果由装备掉落系统触发 |

**Interface Contracts**:
- `resolve_drop()` 返回格式: `{ guaranteed: [{ item_id, quantity }], weighted: [{ item_id, quantity }] }`
- 所有返回的 `item_id` 必定存在于 物品数据库
- `guaranteed` 数组非空（材料必定掉落）
- `weighted` 数组可能为空（装备未掉落）

## Formulas

### Formula 1: Weight-Based Drop Probability

The probability of selecting a specific item in weighted random selection is defined as:

`drop_probability = item_weight / total_weight_pool`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| item_weight | `w_i` | int | 1-100 | Weight value for the specific item in the drop pool |
| total_weight_pool | `W` | int | — | Sum of all weights in the available drop pool |
| drop_probability | `P` | float | 0.0-1.0 | Probability of this item being selected in a single roll |

**Output Range:** 0.01 (EPIC item with weight=1 in large pool) to 0.50+ (COMMON item with high weight in small pool)

**Example:**
Floor 1-3 drop pool (Iron Blade weight=100, Leather Vest weight=80, Iron Helm weight=60):
```
total_weight_pool = 100 + 80 + 60 = 240

Iron Blade drop_probability = 100 / 240 = 0.417 (41.7%)
Leather Vest drop_probability = 80 / 240 = 0.333 (33.3%)
Iron Helm drop_probability = 60 / 240 = 0.250 (25.0%)
```

Floor 7-10 drop pool (Dragon Slayer weight=15, Amulet of Vitality weight=12, Fate Pendant weight=8, Guardian Plate weight=5):
```
total_weight_pool = 15 + 12 + 8 + 5 = 40

Dragon Slayer drop_probability = 15 / 40 = 0.375 (37.5%)
Guardian Plate drop_probability = 5 / 40 = 0.125 (12.5%)
```

---

### Formula 2: Material Quantity Randomization

The quantity of guaranteed material drops is defined as:

`quantity = random_int(min_quantity, max_quantity)`

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| min_quantity | int | 1-5 | Minimum quantity in the drop table definition |
| max_quantity | int | 2-10 | Maximum quantity in the drop table definition |
| quantity | int | min_quantity to max_quantity | Actual quantity rolled |

**Output Range:** Linear distribution between min and max values.

**Example:**
Floor 1-3 Enhancement Stone (min=1, max=2):
```
quantity = random_int(1, 2) → 1 or 2 (50% each)
```

Floor 10 BOSS Enhancement Stone (min=5, max=10):
```
quantity = random_int(5, 10) → 5, 6, 7, 8, 9, or 10 (equal probability)
```

---

### Formula 3: Equipment Drop Count per Battle

The number of equipment drops per enemy defeat is defined as:

`equipment_drop_count = random_int(drop_count_min, drop_count_max)`

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| drop_count_min | int | 0-1 | Minimum equipment drops from drop table |
| drop_count_max | int | 1-2 | Maximum equipment drops from drop table |
| equipment_drop_count | int | 0-2 | Actual number of equipment items dropped |

**Output Range:**
- Regular enemies (Floor 1-9): `random_int(0, 1)` → 0 or 1 equipment (50% each)
- BOSS (Floor 10): `random_int(1, 2)` → 1 or 2 equipment (50% each)

**Example:**
Floor 1-3 regular enemy:
```
equipment_drop_count = random_int(0, 1) → 0 (no equipment) or 1 (one equipment)
```

Floor 10 BOSS:
```
equipment_drop_count = random_int(1, 2) → 1 or 2 equipment (BOSS always drops at least 1)
```

---

### Summary Table: Drop Probabilities by Floor

| Floor Range | Pool Size | Top Item | Top Item Probability | Rare Item | Rare Item Probability |
|-------------|-----------|----------|---------------------|-----------|----------------------|
| 1-3 | 3 | Iron Blade (weight=100) | 41.7% | — | — |
| 4-6 | 3 | Shadow Dagger (weight=50) | 41.7% | Ring of Power (weight=30) | 25% |
| 7-10 | 4 | Dragon Slayer (weight=15) | 37.5% | Guardian Plate (weight=5) | 12.5% |
| 10 BOSS | 3 | Guardian Plate (weight=30) | 37.5% | Fate Pendant (weight=20) | 25% |

## Edge Cases

### Edge Case 1: Invalid Drop Table ID

**Scenario**: `resolve_drop()` 被调用时 `drop_table_id` 不存在于数据库。

**Expected Behavior**:
- 返回 `{ guaranteed: [], weighted: [] }` 空结果
- 日志警告："Drop table [id] not found"
- 装备掉落系统检测到空结果，不触发掉落展示
- 玩家仍获得战斗胜利，但无物品掉落（视为数据错误而非游戏崩溃）

**Test**: 调用 `resolve_drop("drop_table_invalid_xyz")` → 验证返回空列表，警告日志。

---

### Edge Case 2: Empty Weighted Drop Pool

**Scenario**: 掉落表定义的 `weighted_drops` 为空数组（无装备掉落池）。

**Expected Behavior**:
- `resolve_drop()` 正常处理 `guaranteed_drops`
- `weighted` 返回空数组
- 装备掉落系统只展示材料掉落，无装备弹出
- 符合设计意图（某些敌人可能只掉材料，不掉装备）

**Test**: 掉落表 weighted_drops=[] → 调用 `resolve_drop()` → 验证返回 `{ guaranteed: [...], weighted: [] }`。

---

### Edge Case 3: Drop Count Exceeds Pool Size

**Scenario**: `drop_count_max` 大于 `weighted_drops` 数组长度，无法选择足够装备。

**Expected Behavior**:
- 权重选择时，当 `available_entries.size() == 0`，停止选择
- 返回实际可选择的数量（小于 `drop_count_max`）
- 不抛出错误，自然降级
- 日志信息（可选）："Drop pool exhausted at [N] items"

**Example**: drop_count_max=3, weighted_drops.size()=2 → 返回最多2件装备。

**Test**: drop_count_max=3, pool size=2 → 验证返回最多2件装备，无错误。

---

### Edge Case 4: Invalid Item ID in Drop Table

**Scenario**: 掉落表定义包含一个不存在的 `item_id`（数据错误）。

**Expected Behavior**:
- 加载掉落表时验证所有 `item_id` 存在于 物品数据库
- 发现无效ID → 日志错误："Invalid item [id] in drop table [table_id]"
- 从掉落表中移除该条目（降级处理）
- 继续加载其他有效条目
- 不阻止掉落表使用（部分可用优于完全不可用）

**Test**: 掉落表包含无效装备ID → 加载 → 验证移除无效条目，其他条目可用。

---

### Edge Case 5: Missing Drop Table for Floor

**Scenario**: 敌人定义引用的 `drop_table_id` 不匹配任何掉落表的 `floor_range`。

**Expected Behavior**:
- 敌人系统在生成敌人时验证 `drop_table_id` 有效性
- 若无效 → 使用默认掉落表 `drop_table_floor_1_3` 作为fallback
- 日志警告："Enemy [id] references invalid drop table [drop_id], using default"
- 确保所有敌人都有掉落（无空掉落情况）

**Test**: 敌人 drop_table_id 无效 → 验证使用默认掉落表。

---

### Edge Case 6: Multiple Enemies in One Battle

**Scenario**: 一场战斗有多个敌人（enemy_count > 1），每个敌人有自己的 `drop_table_id`。

**Expected Behavior**:
- 每个敌人独立触发掉落解析（每个敌人击败时调用 `resolve_drop()`）
- 掉落结果合并展示（UI层面，由装备掉落系统处理）
- 掉落表系统不关心合并逻辑，只提供单敌人掉落解析

**Test**: 3个敌人 → 3次 `resolve_drop()` → 验证各自独立解析。

---

### Edge Case 7: Zero Weight Item

**Scenario**: 某装备的 `weight` 设置为0（配置错误）。

**Expected Behavior**:
- 权重计算时，weight=0 的条目永远不会被选中
- `total_weight_pool` 计算时不包含 weight=0 的条目
- 日志警告："Item [id] has weight=0 in drop table, will never drop"
- 不阻止掉落表使用，但该装备实际上不会掉落

**Test**: 某装备 weight=0 → 验证该装备概率为0%，永远不会被选中。

---

### Edge Case 8: All Items Have Zero Weight

**Scenario**: `weighted_drops` 中所有条目的 weight 都为0。

**Expected Behavior**:
- `total_weight_pool = 0`
- 权重选择算法检测到 `total_weight == 0`
- 返回空 `weighted` 数组
- 日志警告："Drop table [id] has no valid weighted entries"
- 降级为只返回 `guaranteed_drops`

**Test**: 所有装备 weight=0 → 验证返回只有材料，无装备。

## Dependencies

### Upstream Dependencies (Hard)

| System | Type | Interface | Description |
|--------|------|-----------|-------------|
| **敌人系统** | Hard | `enemy.drop_table_id` | 敌人定义包含掉落表ID引用。掉落表系统根据此ID解析掉落内容。 |
| **物品数据库** | Hard | `has_equipment(id)`, `has_material(id)` | 验证掉落表中的物品ID有效性。掉落解析返回的物品ID必须存在于物品数据库。 |

**Constraint from 敌人系统 GDD**:
- Enemy definition has `drop_table_id` field
- Drop resolution called via `DropTableSystem.resolve_drop(drop_table_id)`
- Drop tables tiered by floor: 1-3 basic, 4-6 mid, 7-10 high
- Each enemy type links to a specific drop table

**Constraint from 物品数据库 GDD**:
- 10 MVP equipment items defined
- 5 MVP materials defined
- Rarity system: COMMON, UNCOMMON, RARE, EPIC, LEGENDARY
- Equipment types: WEAPON, ARMOR, ACCESSORY
- Material categories: ENHANCEMENT, CURRENCY

---

### Downstream Dependencies (Hard)

| System | Type | Interface Used | Description |
|--------|------|---------------|-------------|
| **装备掉落系统** | Hard | `resolve_drop(drop_table_id) → Dictionary` | 装备掉落系统接收掉落列表，处理物品发放和掉落UI展示。 |

**Interface Contracts**:
- `resolve_drop()` returns `{ guaranteed: [{ item_id, quantity }], weighted: [{ item_id, quantity }] }`
- All `item_id` values exist in ItemDatabase
- `guaranteed` array is non-empty (materials always drop)
- `weighted` array may be empty (equipment may not drop)

---

### Downstream Dependencies (Soft)

| System | Type | Interface Used | Description |
|--------|------|---------------|-------------|
| **战斗系统** | Soft | — | 战斗胜利触发掉落解析流程（通过装备掉落系统）。掉落表系统不直接监听战斗信号。 |
| **视觉反馈系统** | Soft | — | 掉落弹出视觉效果由装备掉落系统触发。掉落表系统不直接调用视觉反馈。 |

---

### External Dependencies (Non-Game Systems)

| Dependency | Type | Usage |
|------------|------|-------|
| **Godot Dictionary** | Hard | 返回值数据结构 |
| **Godot Array** | Hard | 物品列表存储 |
| **Godot random_int()** | Hard | 随机数生成（权重选择、数量随机） |

---

### Dependency Graph

```
[敌人系统] ─────────────────────┐
    │                           │
    │ enemy.drop_table_id       │
    v                           v
[物品数据库] ────────→ [掉落表系统] ────────→ [装备掉落系统]
    │                           │
    │ validation                │ resolve_drop()
    v                           v
   (验证item_id存在)         (发放物品 + 展示UI)
```

## Tuning Knobs

### Drop Count Configuration

| Knob | Default | Range | Purpose |
|------|---------|-------|---------|
| `DROP_COUNT_MIN_REGULAR` | 0 | 0-1 | Regular enemies minimum equipment drops |
| `DROP_COUNT_MAX_REGULAR` | 1 | 1-2 | Regular enemies maximum equipment drops |
| `DROP_COUNT_MIN_BOSS` | 1 | 1-2 | BOSS minimum equipment drops |
| `DROP_COUNT_MAX_BOSS` | 2 | 1-3 | BOSS maximum equipment drops |

**Tuning guidance**: Increasing drop count makes players feel "rich" faster. MVP keeps it at 0-1 for regular enemies (50% chance of equipment), ensuring material drops remain the primary reward. BOSS always drops 1-2 equipment, creating a milestone reward.

---

### Weight Configuration by Rarity

| Knob | Default | Range | Purpose |
|------|---------|-------|---------|
| `WEIGHT_COMMON_BASE` | 100 | 50-150 | Base weight for COMMON equipment |
| `WEIGHT_UNCOMMON_BASE` | 40 | 20-60 | Base weight for UNCOMMON equipment |
| `WEIGHT_RARE_BASE` | 15 | 5-25 | Base weight for RARE equipment |
| `WEIGHT_EPIC_BASE` | 5 | 1-10 | Base weight for EPIC equipment |

**Tuning guidance**: Weight ratios create drop rarity feel. Current ratio (COMMON:UNCOMMON:RARE:EPIC = 100:40:15:5 ≈ 20:8:3:1) means COMMON is ~20x more likely than EPIC. Adjust base weights to change rarity feel — higher EPIC weight makes rarer items more accessible.

---

### Material Quantity Configuration

| Knob | Floor 1-3 | Floor 4-6 | Floor 7-10 | Floor 10 BOSS |
|------|-----------|-----------|------------|---------------|
| `MAT_STONE_MIN` | 1 | 2 | 3 | 5 |
| `MAT_STONE_MAX` | 2 | 3 | 5 | 10 |
| `MAT_CRYSTAL_MIN` | 0 | 0 | 1 | 0 |
| `MAT_CRYSTAL_MAX` | 0 | 1 | 1 | 0 |
| `MAT_CRYSTAL_PROBABILITY` | 0% | 30% | 100% | 0% |
| `MAT_CELESTIAL_MIN` | 0 | 0 | 0 | 1 |
| `MAT_CELESTIAL_MAX` | 0 | 0 | 0 | 1 |

**Tuning guidance**: Material quantity scales with floor to match强化成本增长. Floor 1-3 drops 1-2 stones (cost 100-200 gold), Floor 7-10 drops 3-5 stones (cost 1000+ gold). BOSS drops Celestial Shard (rare material for high-level enhancement).

---

### Session Feasibility Analysis

**Assumptions**:
- 3 enemies per battle session (typical)
- 50% equipment drop rate for regular enemies
- Each battle: 3 enemies × (1 material guaranteed + 0.5 equipment expected) = 3 materials + 1.5 equipment

**Per-session material yield**:
| Floor Range | Enhancement Stones | Crystal Essence | Celestial Shard |
|-------------|--------------------|-----------------|-----------------|
| 1-3 | 3-6 (avg 4.5) | 0 | 0 |
| 4-6 | 6-9 (avg 7.5) | 0-3 (avg 0.9) | 0 |
| 7-10 | 9-15 (avg 12) | 3 | 0 |
| 10 BOSS | 5-10 + 1 Celestial | — | 1 |

**Equipment enhancement feasibility**:
- Iron Blade +0→+10 total gold cost: 5500 gold (see 强化公式系统)
- Floor 1-3 session: ~4.5 stones + 1.5 equipment → covers ~4-5 enhancement attempts
- Material supply matches enhancement demand curve

**Risk**: Material quantity must be adjusted if强化成本公式changes. Run `/consistency-check` after any formula tuning.

## Visual/Audio Requirements

**None — this is a data layer.**

掉落表系统不直接呈现给玩家。所有视觉和音频反馈由下游系统负责：

| Aspect | Responsible System | Notes |
|--------|-------------------|-------|
| Drop popup animation | 装备掉落系统 | Equipment icons burst from defeated enemy |
| Material flyout | 装备掉落系统 | Enhancement Stones fly to inventory counter |
| Rarity color coding | 装备掉落系统 + 物品数据库 | COMMON=grey, UNCOMMON=green, RARE=blue, EPIC=purple |
| Drop sound effects | 音效系统 | Coin clink for materials, whoosh for equipment |
| Particle burst | 粒子系统 | Triggered by 装备掉落系统 on rare drop |

掉落表系统只提供 `{ item_id, quantity }` 数据。如何展示是装备掉落系统的职责。

## UI Requirements

**None — this is a data layer.**

掉落表系统没有直接UI。玩家不与掉落表交互 — 他们击败敌人，系统自动解析掉落表并返回物品。

任何UI需求由下游系统实现：
- **掉落展示UI**: 装备掉落系统负责（掉落弹出、物品飞入inventory）
- **掉落历史查看**: 存档系统负责（如果需要掉落记录）
- **掉落表调试工具**: 开发者工具（非玩家UI）

MVP阶段无需掉落表相关的玩家UI。

## Acceptance Criteria

### AC 1: Drop Resolution Correctness

**Test**: Call `resolve_drop("drop_table_floor_1_3")` 100 times.
**Pass**: 
- `guaranteed` array always contains `{ mat_enhance_stone_common, quantity: 1-2 }`
- `weighted` array size ∈ {0, 1} (matches drop_count 0-1)
- Every `item_id` in result exists in 物品数据库

---

### AC 2: Weight Probability Distribution

**Test**: Call `resolve_drop("drop_table_floor_1_3")` 1000 times, count equipment occurrences.
**Pass**:
- Iron Blade count ≈ 417 (41.7% ± 5% tolerance)
- Leather Vest count ≈ 333 (33.3% ± 5% tolerance)
- Iron Helm count ≈ 250 (25.0% ± 5% tolerance)

---

### AC 3: Boss Guaranteed Drops

**Test**: Call `resolve_drop("drop_table_floor_10_boss")` 50 times.
**Pass**:
- `guaranteed` always contains `{ mat_enhance_celestial_shard, quantity: 1 }`
- `weighted` size ∈ {1, 2} (BOSS always drops at least 1 equipment)

---

### AC 4: Invalid Drop Table Handling

**Test**: Call `resolve_drop("drop_table_invalid_xyz")`.
**Pass**:
- Returns `{ guaranteed: [], weighted: [] }`
- Warning logged: "Drop table drop_table_invalid_xyz not found"

---

### AC 5: Floor Range Query

**Test**: Call `get_drop_tables_for_floor(5)`.
**Pass**: Returns `[drop_table_floor_4_6]` (correct floor range match)

---

### AC 6: Duplicate Prevention

**Test**: Create drop table with `drop_count_max=3` but `weighted_drops.size()=2`.
**Pass**: `resolve_drop()` returns max 2 items (pool exhausted), no error thrown.

---

### AC 7: Zero Weight Handling

**Test**: Create drop table with one entry having `weight=0`.
**Pass**: That entry never appears in `weighted` results over 100 calls.

---

### AC 8: Integration with Item Database

**Test**: Drop table references non-existent `item_id`.
**Pass**: Entry removed from effective drop pool, warning logged.

## Open Questions

### OQ 1: Dynamic Drop Tables (Post-MVP)

**Question**: Should MVP support runtime drop table modification (e.g., event-specific boost)?
**Current decision**: No — MVP uses static JSON files. Dynamic tables are post-MVP feature.
**Impact**: System architecture can remain simple (load-on-startup). Post-MVP may need hot-reload capability.

---

### OQ 2: Drop Table Weighting Algorithm

**Question**: Should we use weighted random without replacement (current) or with replacement?
**Current decision**: Without replacement — prevents duplicate equipment in single drop.
**Impact**: "Without replacement" means rare items become slightly more likely in subsequent picks after common items are exhausted. This is acceptable for MVP.

---

### OQ 3: Material Drop Variance

**Question**: Floor 4-6 Crystal Essence has 30% probability. Should this be implemented as a separate probability roll or as a weight=0 entry with special flag?
**Current decision**: Implement as separate probability roll in `guaranteed_drops` array.
**Rationale**: Weighted drops are for equipment (variable pool). Probability-based materials belong in guaranteed drops with probability attribute.

---

### OQ 4: Multi-Enemy Battle Drop Aggregation

**Question**: When 3 enemies are defeated in one battle, should 装备掉落系统 aggregate drops into one display or show sequentially?
**Current decision**: Aggregation is UI-layer decision. Drop table system returns individual results; downstream system decides presentation.
**Impact**: This system remains agnostic to presentation. Open question moves to 装备掉落系统 GDD.

---

### OQ 5: Drop Table Data Format

**Question**: Should drop tables be JSON files or Godot Resource (.tres)?
**Current decision**: JSON files in `assets/data/drop_tables/` for MVP.
**Rationale**: JSON is easier to edit externally (balance tuning) and doesn't require Godot editor. Can convert to .tres post-MVP if needed.