# 装备强化系统

> **Status**: Designed
> **Author**: User + agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: 爽感反馈, 稳定成长, 掌控节奏

## Overview

装备强化系统是游戏的强化操作执行层，负责接收玩家强化请求、验证资源充足性、调用成本公式系统计算费用、执行资源扣除、更新装备强化等级，并触发视觉反馈。它是强化公式系统（成本计算）和存档系统（等级持久化）之间的操作桥梁。

**核心职责**:
1. **请求验证**: 检查装备存在、等级未达上限、资源充足
2. **成本获取**: 调用强化公式系统 `calculate_total_cost(equipment_id, current_level)` 获取金币和材料消耗
3. **资源扣除**: 通过货币系统扣除金币，通过材料系统扣除材料
4. **等级更新**: 调用存档系统更新 `enhancement_levels[equipment_instance_id]`
5. **反馈触发**: 发出 `enhancement_completed` 信号供视觉反馈系统响应

**数据流**:
```
玩家点击强化 → EnhancementSystem.enhance(equipment_instance_id)
              → EnhancementFormulaSystem.calculate_total_cost()
              → CurrencySystem.can_afford() + MaterialSystem.can_remove_bulk()
              → (验证通过) CurrencySystem.remove_currency() + MaterialSystem.remove_material()
              → SaveSystem.update_enhancement_level()
              → emit enhancement_completed(instance_id, old_level, new_level)
```

**MVP范围**: 强化等级0→10，单次强化操作，必定成功，无成功率机制。强化界面从装备槽系统或背包选择装备。

**支柱支撑**:
- 爽感反馈: 强化成功时发出信号触发视觉反馈（粒子爆发、数字飞溅）
- 稳定成长: 必定成功，强化等级永久保存，每次操作都是确定的进步
- 掌控节奏: 玩家决定何时强化、强化哪件装备，无自动强化

**ADR引用**: 无现有ADR。实现层架构决策（如Autoload单例vs场景脚本）将在 `/architecture-decision` 中定义。

## Player Fantasy

**核心幻想**: "一键强化，数值暴涨" — 玩家每次点击强化按钮，看到金币和材料化为能量流入装备，强化等级跳动上升，装备数值（攻击/防御）瞬间跳升。爽感来自于"变强"的可视化：数字飞溅、粒子爆发、屏幕震动。玩家是成长的主人，无需担心失败，只需要享受稳定的进步。

**锚定时刻**: 第一次将COMMON武器强化到+5的时刻。玩家刚获得50个Enhancement Stone，打开强化界面，选中Iron Blade（攻击力10）。点击"强化"按钮，看到100金币和1个材料化为金色能量流入武器，武器图标爆发粒子，攻击力跳升到15（+5 = 10 * 1.5）。玩家感受"我的武器变强了！"，立刻想试试能否推进更深层级。

**必定成功的承诺**:
- 强化永远成功，没有失败风险
- 每次点击都是确定的进步，支撑支柱"稳定成长"
- 玩家可以提前计算成本，知道"还需要多少金币/材料就能强化"
- 强化等级永久保存，存档系统保障进度不丢失

**强化节奏掌控**:
- 玩家决定何时强化：获得新材料时立刻强化？还是积累到一定数量再强化？
- 玩家决定强化顺序：先强化COMMON装备快速成长？还是先强化EPIC装备长期投资？
- 支柱"掌控节奏"：没有自动强化，每次强化都是玩家主动决策

**参考时刻**:
- 暗黑破坏神：强化成功的音效和视觉反馈（但没有失败风险）
- Idle Slayer：装备强化界面简洁，点击强化立刻看到数值变化
- 梦幻西游手游：强化必定成功，玩家可以规划强化路径

**支柱对应**:
- 爽感反馈：强化成功时粒子爆发、数字飞溅、屏幕震动（由视觉反馈系统执行）
- 稳定成长：必定成功，成本可预测，进度永久保存
- 掌控节奏：玩家决定强化时机和顺序，无自动强化
- 多元成长：不同稀有度装备强化成本不同，玩家有多条强化策略路线

## Detailed Design

### Core Rules

**Rule 1: Enhancement Request Entry Point**

玩家通过强化界面发起强化请求。

**入口接口**:
```gdscript
func enhance(equipment_instance_id: String) -> EnhancementResult
```

**参数**:
- `equipment_instance_id`: 装备实例唯一ID（格式: `equipment_id_timestamp_suffix`）
- 返回值: `EnhancementResult` 枚举 { SUCCESS, INVALID_EQUIPMENT, MAX_LEVEL, INSUFFICIENT_GOLD, INSUFFICIENT_MATERIALS }

**调用时机**: 玩家在强化界面点击"强化"按钮。

---

**Rule 2: Equipment Validation**

强化请求首先验证装备有效性。

**验证步骤**:
| Step | Validation | Failure Result |
|------|-----------|----------------|
| 1 | `equipment_instance_id` 存在于存档系统 | INVALID_EQUIPMENT |
| 2 | 获取 `equipment_id` 从存档 `equipment_definitions[instance_id]` | INVALID_EQUIPMENT |
| 3 | `equipment_id` 存在于物品数据库 | INVALID_EQUIPMENT |
| 4 | 获取当前强化等级 `current_level = SaveSystem.enhancement_levels[instance_id]` | 默认0（未强化） |
| 5 | 验证 `current_level < MAX_ENHANCEMENT_LEVEL (10)` | MAX_LEVEL |

---

**Rule 3: Cost Calculation from 强化公式系统**

调用强化公式系统获取强化成本。

**成本查询**:
```gdscript
var cost = EnhancementFormulaSystem.calculate_total_cost(equipment_id, current_level)
# cost = { gold: int, materials: { material_id: quantity } }
```

**成本结构**:
- `gold`: 金币消耗（基于BASE_GOLD_COST、稀有度乘数、装备成本系数）
- `materials`: 材料消耗字典 `{ "mat_enhance_stone_common": quantity }`

**MVP材料**: 仅使用 `mat_enhance_stone_common`（Enhancement Stone），数量 = `current_level + 1`

---

**Rule 4: Resource Validation**

验证玩家资源是否充足。

**金币验证**:
```gdscript
var gold_sufficient = CurrencySystem.can_afford("mat_currency_gold", cost.gold)
```

**材料验证**:
```gdscript
var materials_sufficient = MaterialSystem.can_remove_bulk(cost.materials)
```

**验证结果**:
| Condition | Result |
|-----------|--------|
| 金币不足 | INSUFFICIENT_GOLD |
| 材料不足 | INSUFFICIENT_MATERIALS |
| 两者均不足 | INSUFFICIENT_GOLD (优先报告金币不足) |
| 两者充足 | 继续执行 |

---

**Rule 5: Resource Consumption**

验证通过后执行资源扣除。

**金币扣除**:
```gdscript
CurrencySystem.remove_currency("mat_currency_gold", cost.gold)
# Triggers currency_removed signal, SaveSystem critical save
```

**材料扣除**:
```gdscript
for material_id in cost.materials:
    MaterialSystem.remove_material(material_id, cost.materials[material_id])
# Triggers material_removed signal, SaveSystem critical save
```

**扣除顺序**: 金币先扣 → 材料后扣（金币为主要消耗，材料为辅助）

---

**Rule 6: Enhancement Level Update**

更新装备强化等级。

**等级更新**:
```gdscript
var new_level = current_level + 1
SaveSystem.update_enhancement_level(equipment_instance_id, new_level)
```

**存档结构**: `equipment.enhancement_levels[instance_id] = new_level`

**数值变化触发**: 
- 若装备已装备在槽位 → 发出 `slot_stats_changed` 信号通知战斗系统重新计算攻击/防御
- 若装备在背包 → 无战斗系统通知，仅更新存档

---

**Rule 7: Enhancement Completion and Feedback Signal**

强化完成后发出反馈信号。

**信号定义**:
```gdscript
signal enhancement_completed(equipment_instance_id: String, old_level: int, new_level: int)
```

**信号订阅者**:
- 视觉反馈系统: 触发粒子爆发、数字飞溅、屏幕震动
- 数值显示系统: 更新装备界面显示的强化等级和数值
- UI系统: 更新强化按钮状态、显示新等级

---

**Rule 8: Bulk Enhancement (Post-MVP Feature)**

MVP不支持批量强化（一次性强化多级）。后续版本可能添加"强化到目标等级"功能。

**MVP限制**: 每次操作仅强化 +1 级，玩家需多次点击。

---

**Rule 9: Equipment Location Query**

强化系统需要查询装备当前所在位置（已装备或背包）。

**查询接口**:
```gdscript
func get_equipment_location(equipment_instance_id: String) -> EquipmentLocation
# EquipmentLocation enum: { EQUIPPED, INVENTORY, UNKNOWN }
```

**用途**:
- EQUIPPED: 需通知战斗系统重新计算属性
- INVENTORY: 无战斗系统通知

---

**Rule 10: Enhancement Preview Query**

提供强化预览接口供UI显示成本和预期结果。

**预览接口**:
```gdscript
func get_enhancement_preview(equipment_instance_id: String) -> Dictionary
# Returns: {
#   current_level: int,
#   target_level: int,
#   gold_cost: int,
#   material_costs: { material_id: quantity },
#   current_attack: int,
#   projected_attack: int,
#   current_defense: int,
#   projected_defense: int
# }
```

**用途**: 强化界面显示"本次强化需要X金币，强化后攻击力变为Y"。

---

### States and Transitions

装备强化系统本身无复杂状态机，但每次强化请求有内部流程状态：

| State | Description | Entry | Exit |
|-------|-------------|-------|------|
| **Idle** | 无强化请求，等待玩家操作 | 初始化/请求完成 | `enhance()` 被调用 |
| **Validating** | 验证装备和资源 | 收到请求 | 验证完成 |
| **Executing** | 执行资源扣除和等级更新 | 验证通过 | 扣除完成 |
| **Completing** | 发出完成信号 | 执行完成 | 信号发出 |

**Transition Table**:
| Current | Trigger | Next | Action |
|---------|---------|------|--------|
| Idle | `enhance(instance_id)` | Validating | 开始验证 |
| Validating | 验证失败 | Idle | 返回错误结果，不执行扣除 |
| Validating | 验证通过 | Executing | 开始资源扣除 |
| Executing | 扣除失败（异常） | Idle | 返回错误（理论上不应发生，已预验证） |
| Executing | 扣除成功 | Completing | 更新强化等级 |
| Completing | 信号发出 | Idle | 返回成功结果 |

---

### Interactions with Other Systems

**上游依赖**:

| System | Interface Used | Data Flow |
|--------|---------------|-----------|
| **强化公式系统** | `calculate_total_cost(equipment_id, level)` | 获取金币和材料成本 |
| **强化公式系统** | `can_enchant(equipment_id, level)` | 验证是否可强化（等级未达上限） |
| **货币系统** | `can_afford(currency_id, amount)` | 验证金币充足 |
| **货币系统** | `remove_currency(currency_id, amount)` | 执行金币扣除 |
| **材料系统** | `can_remove_bulk(requirements)` | 验证材料充足 |
| **材料系统** | `remove_material(material_id, amount)` | 执行材料扣除 |
| **存档系统** | `get_equipment_definition(instance_id)` | 获取装备ID |
| **存档系统** | `get_enhancement_level(instance_id)` | 获取当前强化等级 |
| **存档系统** | `update_enhancement_level(instance_id, level)` | 更新强化等级 |
| **物品数据库** | `get_equipment(equipment_id)` | 获取装备基础属性 |
| **装备槽系统** | `is_equipment_equipped(instance_id)` | 查询装备位置 |

**下游依赖**:

| System | Signal/Interface | Data Flow |
|--------|-----------------|-----------|
| **视觉反馈系统** | `enhancement_completed` signal | 触发粒子、震动、数字飞溅 |
| **数值显示系统** | `enhancement_completed` signal | 更新UI显示 |
| **战斗系统** | `slot_stats_changed` signal | 重新计算攻击/防御（若装备已装备） |

## Formulas

### F1: Enhanced Attack Calculation

The enhanced attack calculation formula is defined as:

`enhanced_attack = floor(base_attack * (1 + enhancement_level * ENHANCEMENT_ATTACK_MULTIPLIER))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_attack | `BA` | int | 10–100+ | Equipment base attack from ItemDatabase |
| enhancement_level | `L` | int | 0–10 | Current enhancement level |
| ENHANCEMENT_ATTACK_MULTIPLIER | `EAM` | float | 0.1 (registry) | Attack multiplier per level |
| enhanced_attack | `EA` | int | 10–200+ | Final attack after enhancement |

**Output Range:** 
- Minimum: `floor(10 * (1 + 0 * 0.1)) = 10` (base attack at +0)
- Maximum: `floor(100 * (1 + 10 * 0.1)) = 200` (100 base attack at +10)

**Example:**
Iron Blade (base_attack = 10) at +5:
```
enhanced_attack = floor(10 * (1 + 5 * 0.1))
               = floor(10 * 1.5)
               = 15
```

Iron Blade (base_attack = 10) at +10:
```
enhanced_attack = floor(10 * (1 + 10 * 0.1))
               = floor(10 * 2.0)
               = 20
```

Guardian Plate (base_attack = 20, EPIC) at +10:
```
enhanced_attack = floor(20 * (1 + 10 * 0.1))
               = floor(20 * 2.0)
               = 40
```

---

### F2: Enhanced Defense Calculation

The enhanced defense calculation formula is defined as:

`enhanced_defense = floor(base_defense * (1 + enhancement_level * ENHANCEMENT_DEFENSE_MULTIPLIER))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_defense | `BD` | int | 0–100+ | Equipment base defense from ItemDatabase |
| enhancement_level | `L` | int | 0–10 | Current enhancement level |
| ENHANCEMENT_DEFENSE_MULTIPLIER | `EDM` | float | 0.1 (registry) | Defense multiplier per level |
| enhanced_defense | `ED` | int | 0–200+ | Final defense after enhancement |

**Output Range:**
- Minimum: `floor(0 * (1 + L * 0.1)) = 0` (weapons have no defense)
- Maximum: `floor(100 * (1 + 10 * 0.1)) = 200` (100 base defense at +10)

**Example:**
Iron Blade (base_defense = 0) at +10:
```
enhanced_defense = floor(0 * 2.0) = 0 (weapons no defense)
```

Guardian Plate (base_defense = 50, EPIC) at +5:
```
enhanced_defense = floor(50 * (1 + 5 * 0.1))
               = floor(50 * 1.5)
               = 75
```

Guardian Plate (base_defense = 50) at +10:
```
enhanced_defense = floor(50 * 2.0) = 100
```

---

### F3: Enhancement Cost Preview (Delegated to 强化公式系统)

Cost preview is calculated by calling 强化公式系统 interfaces:

**Gold Cost Query**:
```gdscript
gold_cost = EnhancementFormulaSystem.calculate_gold_cost(equipment_id, current_level)
```

**Material Cost Query**:
```gdscript
material_costs = EnhancementFormulaSystem.calculate_material_cost(equipment_id, current_level)
```

**Reference**: See `design/gdd/enhancement-formula-system.md` for full formula definitions:
- Formula 1: Gold Cost per Enhancement Level
- Formula 2: Material Cost per Enhancement Level

---

### F4: Cumulative Cost to Target Level (Delegated)

Cumulative cost calculation for planning purposes:

```gdscript
cumulative_cost = EnhancementFormulaSystem.calculate_cumulative_cost(equipment_id, current_level, target_level)
# Returns: { gold: int, materials: { material_id: int } }
```

**Reference**: See `design/gdd/enhancement-formula-system.md` Formula 3 (Cumulative Gold) and Formula 4 (Cumulative Material).

---

### Summary Table: Enhancement Preview Examples

| Equipment | Level | Gold Cost | Material Cost | Attack Before | Attack After | Defense Before | Defense After |
|-----------|-------|-----------|---------------|---------------|--------------|----------------|---------------|
| Iron Blade (COMMON, base=10/0) | +0→+1 | 100 | 1 | 10 | 11 | 0 | 0 |
| Iron Blade | +5→+6 | 600 | 6 | 15 | 16 | 0 | 0 |
| Iron Blade | +9→+10 | 1000 | 10 | 19 | 20 | 0 | 0 |
| Guardian Plate (EPIC, base=20/50, EC=2.5) | +0→+1 | 750 | 1 | 20 | 22 | 50 | 55 |
| Guardian Plate | +5→+6 | 4500 | 6 | 30 | 32 | 75 | 80 |
| Guardian Plate | +9→+10 | 7500 | 10 | 38 | 40 | 95 | 100 |

## Edge Cases

### E1: Invalid Equipment Instance ID

**场景**: `enhance()` 被调用时 `equipment_instance_id` 不存在于存档系统。

**处理**: 存档系统查询返回 `null`，强化系统返回 `INVALID_EQUIPMENT`，日志警告，无资源扣除，无状态变更。

---

### E2: Equipment Already at Max Level

**场景**: 装备已强化到 +10，玩家尝试继续强化。

**处理**: `can_enchant()` 返回 `false`，强化系统返回 `MAX_LEVEL`，UI显示"+10 MAX"，无资源扣除。

---

### E3: Insufficient Gold Only

**场景**: 玩家有足够的材料，但金币不足。

**处理**: `can_afford()` 返回 `false`，强化系统返回 `INSUFFICIENT_GOLD`，UI显示金币缺口，无资源扣除。

---

### E4: Insufficient Materials Only

**场景**: 玩家有足够的金币，但材料不足。

**处理**: `can_remove_bulk()` 返回 `false`，强化系统返回 `INSUFFICIENT_MATERIALS`，UI显示材料缺口，无资源扣除。

---

### E5: Both Gold and Materials Insufficient

**场景**: 金币和材料均不足。

**处理**: 优先返回 `INSUFFICIENT_GOLD`（金币为主要消耗），UI同时显示两种缺口，无资源扣除。

---

### E6: Resource Deduction Fails After Validation (Edge Case)

**场景**: 验证通过但实际扣除失败（并发操作导致资源被消耗）。

**处理**: 返回 `RESOURCE_DEDUCTION_FAILED`，日志错误，状态不变。MVP单线程操作，理论上不发生。

---

### E7: Equipment Definition Missing from ItemDatabase

**场景**: 装备实例存在于存档，但 `equipment_id` 对应的定义不存在于ItemDatabase。

**处理**: 返回 `INVALID_EQUIPMENT`，日志错误，装备显示为"未知装备"，强化按钮禁用。

---

### E8: SaveSystem Update Enhancement Level Fails

**场景**: 资源扣除成功，但存档系统更新强化等级失败。

**处理**: 资源已扣除（不可撤销），返回 `SUCCESS`，发出信号，存档系统后台重试持久化。

---

### E9: Enhancement Completed Signal with No Subscriber

**场景**: 视觉反馈系统尚未实现，信号发出但无订阅者。

**处理**: 信号正常发出，UI直接更新显示，不检查订阅者。信号机制预留后续接入。

---

### E10: Enhancing Equipped Equipment vs Inventory Equipment

**场景**: 装备在槽位中或背包中，强化处理差异。

**处理**: EQUIPPED → 发出 `slot_stats_changed` 通知战斗系统；INVENTORY → 无战斗通知，仅更新存档。

---

### E11: Rapid Successive Enhancement Requests

**场景**: 玩家快速连续点击强化按钮。

**处理**: 每次点击独立处理，顺序执行。第一次完成后第二次开始新验证和成本计算。无队列机制。

---

### E12: Enhancement During Combat

**场景**: 玩家在战斗进行中打开强化界面并尝试强化。

**处理**: MVP建议战斗期间禁止强化界面，避免战斗中属性突变。若允许打开，强化正常执行并触发属性重算。

## Dependencies

### Upstream Dependencies (本系统依赖)

| System | Type | Interface | Data Flow |
|--------|------|-----------|-----------|
| **强化公式系统** | Hard | `calculate_total_cost(id, level)`, `can_enchant(id, level)` | 获取金币和材料成本，验证是否可强化 |
| **货币系统** | Hard | `can_afford(currency_id, amount)`, `remove_currency(currency_id, amount)` | 验证和扣除金币 |
| **材料系统** | Hard | `can_remove_bulk(requirements)`, `remove_material(id, amount)` | 验证和扣除材料 |
| **存档系统** | Hard | `get_equipment_definition(instance_id)`, `get_enhancement_level(instance_id)`, `update_enhancement_level(instance_id, level)` | 获取装备ID、当前等级、更新等级 |
| **物品数据库** | Hard | `get_equipment(equipment_id)` | 获取装备基础属性（攻击/防御）用于预览计算 |
| **装备槽系统** | Soft | `is_equipment_equipped(instance_id)` | 查询装备位置（已装备或背包） |

**Interface Contracts**:
- 强化公式系统返回 `{ gold: int, materials: { material_id: quantity } }`
- 货币系统 `remove_currency()` 发出 `currency_removed` 信号，触发存档
- 材料系统 `remove_material()` 发出 `material_removed` 信号，触发存档
- 存档系统 `update_enhancement_level()` 为critical trigger，100ms内保存

---

### Downstream Dependencies (依赖本系统)

| System | Type | Interface/Signal | Data Flow |
|--------|------|-----------------|-----------|
| **视觉反馈系统** | Hard | `enhancement_completed(instance_id, old_level, new_level)` | 触发粒子爆发、数字飞溅、屏幕震动 |
| **数值显示系统** | Hard | `enhancement_completed` signal | 更新UI显示强化等级和数值 |
| **战斗系统** | Soft | `slot_stats_changed` signal | 重新计算攻击/防御（仅当装备已装备） |
| **音效系统** | Soft | `enhancement_completed` signal | 播放强化成功音效（Vertical Slice） |

**Signal Contracts**:
- `enhancement_completed(instance_id: String, old_level: int, new_level: new_level)`
- `slot_stats_changed(slot: EquipmentSlot)` (若已装备装备强化)

## Tuning Knobs

本系统无独立 tuning knobs。所有强化成本 knobs 由强化公式系统定义。

**Referenced Tuning Knobs (from 强化公式系统)**:
| Knob | Value | Source | Effect on This System |
|------|-------|--------|----------------------|
| BASE_GOLD_COST | 100 | 强化公式系统 | 金币成本基准 |
| BASE_MATERIAL_COST | 1 | 强化公式系统 | 材料成本基准 |
| MAX_ENHANCEMENT_LEVEL | 10 | ItemDatabase | 强化等级上限 |

**Referenced Tuning Knobs (from ItemDatabase)**:
| Knob | Value | Source | Effect on This System |
|------|-------|--------|----------------------|
| ENHANCEMENT_ATTACK_MULTIPLIER | 0.1 | ItemDatabase | 每级攻击力增幅 |
| ENHANCEMENT_DEFENSE_MULTIPLIER | 0.1 | ItemDatabase | 每级防御力增幅 |

## Visual/Audio Requirements

### Visual Feedback Moments

| 触发时机 | 预期视觉效果 | 实现归属 |
|---------|-------------|---------|
| 强化成功 | 粒子爆发（金光从装备图标中心扩散） | 视觉反馈系统 |
| 等级跳升 | 强化等级数字飞溅（+5 → +6 bounce动画） | 数值显示系统 |
| 属性跳升 | 攻击/防御数字飞溅（15 → 16 绿色飞溅） | 数值显示系统 |
| 达到+10 | 屏幕震动 + 大型粒子爆发 + 文字弹出"MAX!" | 视觉反馈系统 |
| 金币扣除 | 金币从HUD流向装备图标（能量流动画） | 视觉反馈系统 |

### Audio Feedback Moments (音效系统负责)

| 触发时机 | 预期音效 | 实现归属 |
|---------|---------|---------|
| 强化成功 | 强化音效（金属碰撞 + 能量充能） | 音效系统 |
| 达到+10 | 传奇音效（长音 + 庆祝感） | 音效系统 |

**MVP简化**: 音效系统为Vertical Slice，MVP阶段无声效。发出信号供后续接入。

## UI Requirements

| 元素 | 功能 | 显示时机 | 交互 |
|-----|------|---------|-----|
| **强化按钮** | 发起强化请求 | 强化界面 | 点击触发强化 |
| **成本显示** | 显示金币和材料消耗 | 强化界面 | 无交互（信息展示） |
| **预览显示** | 显示强化前后属性对比 | 强化界面 | 无交互（信息展示） |
| **结果提示** | 显示强化成功/失败 | 强化完成 | 自动消失或确认关闭 |

**布局要求**: 
- 强化按钮满足最小触控目标（44pt iOS / 48dp Android）
- 成本显示：金币图标+数量，材料图标+数量，缺口红色标记

## Acceptance Criteria

### Enhancement Success Path

**AC1**: GIVEN Iron Blade (COMMON) at +0 with sufficient gold/materials, WHEN `enhance(instance_id)` called, THEN returns SUCCESS, level becomes +1, `enhancement_completed` signal emits.

**AC2**: GIVEN Iron Blade at +9 with sufficient resources, WHEN `enhance()` called, THEN returns SUCCESS, level becomes +10, screen shake triggered (MAX level).

**AC3**: GIVEN Iron Blade at +10, WHEN `enhance()` called, THEN returns MAX_LEVEL, no resource deduction, UI shows "+10 MAX".

### Resource Validation

**AC4**: GIVEN player has 50 gold (cost=100), WHEN `enhance()` called, THEN returns INSUFFICIENT_GOLD, no resource deduction.

**AC5**: GIVEN player has 0 materials (cost=1), WHEN `enhance()` called, THEN returns INSUFFICIENT_MATERIALS, no resource deduction.

**AC6**: GIVEN player has sufficient gold but insufficient materials, WHEN `enhance()` called, THEN returns INSUFFICIENT_MATERIALS.

### Equipment Validation

**AC7**: GIVEN invalid instance_id "fake_123", WHEN `enhance()` called, THEN returns INVALID_EQUIPMENT, no state change.

**AC8**: GIVEN instance_id exists but equipment_id not in ItemDatabase, WHEN `enhance()` called, THEN returns INVALID_EQUIPMENT, log error.

### Stat Calculation

**AC9**: GIVEN Iron Blade (base_attack=10) at +5, WHEN `get_enhancement_preview()` called, THEN projected_attack = 15 (10 * 1.5).

**AC10**: GIVEN Guardian Plate (base_defense=50) at +10, WHEN preview calculated, THEN projected_defense = 100 (50 * 2.0).

### Signal Emission

**AC11**: GIVEN enhancement succeeds, WHEN operation completes, THEN `enhancement_completed(instance_id, 0, 1)` signal emits.

**AC12**: GIVEN equipped equipment enhanced, WHEN operation completes, THEN `slot_stats_changed(MAIN_HAND)` signal emits.

## Open Questions

**OQ1**: Should enhancement preview show cumulative cost to +10 or only next level cost?

**OQ2**: Should there be a confirmation dialog for high-level enhancement (e.g., +9→+10 costs 7500 gold)?

**OQ3**: Should enhancing an equipped item animate the equipment icon in the slot, or only in the enhancement panel?

**OQ4**: Should enhancement UI allow selecting equipment from both inventory and equipped slots?

**OQ5**: Should there be a "Enhance All" button for bulk enhancement of same-type equipment?

**OQ6**: Should enhancement level affect equipment sell value (if selling implemented)?

**OQ7**: Should reaching +10 trigger a permanent visual marker on equipment icon (gold border)?

**OQ8**: Should enhancement history be tracked for analytics (which equipment, levels, timestamps)?