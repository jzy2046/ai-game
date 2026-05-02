# 装备槽系统

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-05-01
> **Implements Pillar**: 多元成长 + 稳定成长

## Overview

装备槽系统是游戏的装备数据管理层，负责管理玩家的装备槽位分配和背包存储。它作为物品数据库（静态定义）和存档系统（持久化状态）之间的桥梁，为战斗系统提供已装备物品的攻击/防御数值查询接口，为强化系统提供待强化物品的槽位状态。

该系统管理两部分数据：
- **装备槽位**：6个预定义槽位（MAIN_HAND, OFF_HAND, HEAD, BODY, ACCESSORY_1, ACCESSORY_2）的当前装备分配
- **装备背包**：玩家持有但未装备的装备物品列表

装备槽系统不存储装备的静态属性（这是物品数据库的职责），也不存储强化等级（这是存档系统的职责）。它仅管理"哪个槽位装备了什么物品ID"和"背包中有哪些物品ID"的映射关系。当玩家装备、卸下或更换装备时，装备槽系统更新槽位映射并通知存档系统保存状态变化。

**MVP范围**：6槽位装备系统，支持装备、卸下、更换操作。背包容量不限制（简化设计）。装备操作通过UI界面触发，战斗系统通过接口查询装备状态。

## Player Fantasy

装备槽系统支撑的核心玩家幻想是：

> **"我的配置，我的战力"** — 玩家每次打开装备界面，看到的不是随机分配，而是自己精心选择的结果。每个槽位的装备都是玩家主动决策的产物。这种"掌控感"服务于支柱"多元成长"：不同装备组合带来不同数值效果，玩家可以根据当前需求（推进层级 vs 生存能力）调整配置。

**锚定时刻**：第一次获得稀有装备的时刻。玩家击败第5层BOSS，获得一件 EPIC 护甲。打开装备界面，看到当前槽位已有一件 UNCOMMON 护甲。玩家犹豫片刻：换上新护甲？还是先强化现有护甲？最终选择换装 — 立刻看到战力数值跳升。这一刻，玩家感到"我的决策带来了成长"。

**装备槽作为"成长可见性"的载体**：
- 装备界面是玩家查看自身成长状态的主要入口
- 每个槽位装备的稀有度颜色（Common棕色 → Epic橙色）直观展示成长进度
- 空槽位提醒玩家"还有成长空间"，激励继续推进

**参考时刻**：Idle Slayer — 装备界面简洁但信息清晰，玩家一眼看出当前配置是否最优，换装决策无需犹豫。

**支柱对应**：
- 多元成长：6槽位允许不同装备组合，玩家根据需求选择攻击型或防御型配置
- 稳定成长：装备一旦获得就永久属于玩家，装备槽配置不会丢失（存档系统保障）
- 掌控节奏：玩家决定何时换装、何时强化，没有强制装备路径

## Detailed Design

### Core Rules

#### Rule 1: Equipment Slot Schema

装备槽系统管理6个预定义槽位，槽位枚举与物品数据库一致：

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

**数据结构**:
```gdscript
# EquipmentSlotManager (Autoload singleton)
var equipped_slots: Dictionary = {}  # { slot: equipment_id }
var inventory: Array[String] = []    # [equipment_id, ...]
```

**槽位状态**:
- **空槽**: `equipped_slots[slot]` 未定义或为 `null`
- **已装备**: `equipped_slots[slot] = equipment_id`

---

#### Rule 2: Equip Operation

玩家将装备从背包装备到槽位。

**操作流程**:
| Step | Action | Validation |
|------|--------|------------|
| 1 | 玩家选择背包中的装备 | 检查装备存在于 `inventory` |
| 2 | 玩家选择目标槽位 | 检查槽位兼容性 `ItemDatabase.is_equipment_compatible_with_slot(id, slot)` |
| 3 | 检查目标槽位状态 | 若已装备 → 执行交换（Rule 4）；若空 → 直接装备 |
| 4 | 执行装备分配 | `equipped_slots[slot] = equipment_id` |
| 5 | 从背包移除 | `inventory.erase(equipment_id)` |
| 6 | 发出信号通知 | `emit_signal("slot_changed", slot, equipment_id)` |
| 7 | 触发存档保存 | SaveManager收到信号 → critical save |

**接口规范**:
```gdscript
func equip_item(equipment_id: String, target_slot: EquipmentSlot) -> bool:
    # Returns true if successful, false if validation failed
```

---

#### Rule 3: Unequip Operation

玩家将装备从槽位卸下到背包。

**操作流程**:
| Step | Action | Validation |
|------|--------|------------|
| 1 | 玩家选择已装备槽位 | 检查槽位不为空 |
| 2 | 执行卸下操作 | 将 `equipped_slots[slot]` 的装备ID添加到 `inventory` |
| 3 | 清空槽位 | `equipped_slots[slot] = null` 或删除键 |
| 4 | 发出信号通知 | `emit_signal("slot_changed", slot, null)` |
| 5 | 触发存档保存 | SaveManager收到信号 → critical save |

**接口规范**:
```gdscript
func unequip_slot(slot: EquipmentSlot) -> bool:
    # Returns true if successful, false if slot was empty
```

---

#### Rule 4: Swap Operation

玩家将装备装备到已占用槽位，原装备交换到背包。

**操作流程**:
| Step | Action | Effect |
|------|--------|--------|
| 1 | 验证新装备兼容性 | `ItemDatabase.is_equipment_compatible_with_slot(new_id, slot)` |
| 2 | 获取原装备ID | `old_id = equipped_slots[slot]` |
| 3 | 原装备加入背包 | `inventory.append(old_id)` |
| 4 | 新装备占据槽位 | `equipped_slots[slot] = new_id` |
| 5 | 新装备从背包移除 | `inventory.erase(new_id)` |
| 6 | 发出信号通知 | `emit_signal("slot_changed", slot, new_id)` |
| 7 | 触发存档保存 | SaveManager收到信号 → critical save |

**接口规范**:
```gdscript
func swap_equipment(new_equipment_id: String, target_slot: EquipmentSlot) -> bool:
    # Returns true if successful. Automatically unequips old item to inventory.
```

---

#### Rule 5: Equipment Acquisition

玩家获得新装备（来自掉落或其他来源）。

**操作流程**:
| Step | Action | Source |
|------|--------|--------|
| 1 | 接收装备ID | 装备掉落系统调用 `acquire_equipment(equipment_id)` |
| 2 | 添加到背包 | `inventory.append(equipment_id)` |
| 3 | 发出信号通知 | `emit_signal("equipment_acquired", equipment_id)` |
| 4 | 触发存档保存 | SaveManager收到信号 → critical save |

**接口规范**:
```gdscript
func acquire_equipment(equipment_id: String) -> void:
    # Called by EquipmentDropSystem when player receives new equipment
```

---

#### Rule 6: Slot Compatibility Validation

装备操作必须验证槽位兼容性。使用物品数据库提供的接口：

```gdscript
func can_equip_in_slot(equipment_id: String, slot: EquipmentSlot) -> bool:
    return ItemDatabase.is_equipment_compatible_with_slot(equipment_id, slot)
```

**兼容性矩阵 (from ItemDatabase)**:
| Slot | Allowed Types |
|------|---------------|
| MAIN_HAND | WEAPON |
| OFF_HAND | WEAPON, ARMOR (盾牌) |
| HEAD | ARMOR |
| BODY | ARMOR |
| ACCESSORY_1, ACCESSORY_2 | ACCESSORY |

---

#### Rule 7: Query Interface for Combat System

战斗系统需要查询已装备物品以计算玩家攻击/防御数值。

**接口规范**:
```gdscript
func get_equipped_items() -> Dictionary:
    # Returns { slot: { equipment_id: String, enhancement_level: int } }
    # enhancement_level fetched from SaveManager data
```

**战斗系统调用流程**:
```gdscript
# Combat system usage
var equipped = EquipmentSlotManager.get_equipped_items()
var total_attack = 0
for slot in equipped:
    var item_data = equipped[slot]
    total_attack += ItemDatabase.calculate_enhanced_attack(
        item_data.equipment_id,
        item_data.enhancement_level
    )
```

---

#### Rule 8: Initial State and Defaults

新游戏时装备槽系统初始化为空状态。

**默认状态**:
| Field | Default Value |
|-------|---------------|
| `equipped_slots` | `{}` (所有槽位空) |
| `inventory` | `[]` (背包空) |

**初始化时机**: 存档系统返回新游戏默认数据时，EquipmentSlotManager根据数据初始化。

---

### States and Transitions

装备槽系统本身无复杂状态转换，但每个槽位有二元状态：

| Slot State | Description | Condition |
|------------|-------------|-----------|
| **Empty** | 槽位无装备 | `equipped_slots[slot] == null` 或键不存在 |
| **Equipped** | 槽位有装备 | `equipped_slots[slot] == equipment_id` |

**状态转换**:
```
Empty → Equipped (equip operation)
Equipped → Empty (unequip operation)
Equipped → Equipped (swap operation — different equipment_id)
```

---

### Interactions with Other Systems

| System | Data Flow | Interface Owner |
|--------|-----------|-----------------|
| **物品数据库** (Upstream) | Slot compatibility check, equipment definition lookup | EquipmentSlotManager calls `is_equipment_compatible_with_slot(id, slot)` |
| **存档系统** (Upstream/Downstream) | Load: slots/inventory data → Save: slot change notification | EquipmentSlotManager emits `slot_changed`, SaveManager listens |
| **战斗系统** (Downstream) | Equipped items → attack/defense calculation | CombatSystem calls `get_equipped_items()` |
| **装备掉落系统** (Downstream) | New equipment → add to inventory | EquipmentDropSystem calls `acquire_equipment(id)` |
| **强化系统** (Downstream) | Check if equipment is equipped before enhancement | EnhancementSystem queries slot state |
| **数值显示系统** (Downstream) | Slot assignments → UI display | StatDisplaySystem calls `get_equipped_items()` for HUD |

## Formulas

### Formula 1: Total Equipped Count

计算已装备槽位数量，用于UI显示装备进度。

The total equipped count formula is defined as:

`equipped_count = count(equipped_slots[slot] != null for each slot in EquipmentSlot)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| equipped_slots | — | Dictionary | — | Current slot assignments |
| slot | — | EquipmentSlot enum | 0–5 | Individual slot index |
| equipped_count | `ec` | int | 0–6 | Number of filled slots |

**Output Range:** 0 (new game) to 6 (all slots equipped)

**Example:**
Player has Iron Blade in MAIN_HAND, Leather Vest in BODY, Iron Helm in HEAD:
```
equipped_count = count(MAIN_HAND!=null, OFF_HAND==null, HEAD!=null, BODY!=null, ACCESSORY_1==null, ACCESSORY_2==null)
             = count(true, false, true, true, false, false)
             = 3
```

---

### Formula 2: Empty Slot Count

计算空槽位数量，用于UI提示玩家还有成长空间。

The empty slot count formula is defined as:

`empty_slot_count = TOTAL_SLOT_COUNT - equipped_count`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| TOTAL_SLOT_COUNT | — | int | 6 (constant) | Total number of equipment slots |
| equipped_count | `ec` | int | 0–6 | Number of filled slots |
| empty_slot_count | `esc` | int | 0–6 | Number of empty slots |

**Output Range:** 6 (new game) to 0 (all slots equipped)

**Example:**
Player has 3 equipped slots:
```
empty_slot_count = 6 - 3 = 3
```

---

### Formula 3: Inventory Item Count

计算背包中未装备的装备数量。

The inventory item count formula is defined as:

`inventory_count = len(inventory)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| inventory | — | Array[String] | — | List of unequipped equipment IDs |
| inventory_count | `ic` | int | 0–∞ | Number of items in inventory |

**Output Range:** 0 (empty) to unbounded (MVP: no inventory limit)

**Example:**
Player has 2 Iron Blades and 1 Ring of Power in inventory:
```
inventory_count = len(["equip_weapon_iron_blade", "equip_weapon_iron_blade_2", "equip_accessory_ring_power"])
              = 3
```

---

### Formula 4: Total Equipment Owned

计算玩家拥有的装备总数（已装备 + 背包）。

The total equipment owned formula is defined as:

`total_equipment = equipped_count + inventory_count`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| equipped_count | `ec` | int | 0–6 | Number of equipped items |
| inventory_count | `ic` | int | 0–∞ | Number of items in inventory |
| total_equipment | `te` | int | 0–∞ | Total equipment owned |

**Output Range:** 0 (new game) to unbounded

**Example:**
Player has 3 equipped items and 5 in inventory:
```
total_equipment = 3 + 5 = 8
```

## Edge Cases

### Edge Case 1: Equip to Incompatible Slot

**Scenario**: 玩家尝试将WEAPON类型装备装备到BODY槽位。

**Expected Behavior**:
- 验证失败，`equip_item()` 返回 `false`
- UI显示提示："此装备无法装备到该槽位"
- 槽位状态不变，装备仍在背包中
- 不触发存档保存

**Test**: 尝试装备Iron Blade到BODY槽位 → 验证操作失败，提示显示，状态不变。

---

### Edge Case 2: Unequip Empty Slot

**Scenario**: 玩家点击一个空槽位的"卸下"按钮。

**Expected Behavior**:
- `unequip_slot()` 检测槽位为空，返回 `false`
- UI显示提示："该槽位无装备"或按钮禁用（预防性）
- 状态不变

**Test**: 调用 `unequip_slot(OFF_HAND)` 当OFF_HAND为空 → 验证返回false，状态不变。

---

### Edge Case 3: Equip Item Not in Inventory

**Scenario**: `equip_item()` 被调用时装备ID不在 `inventory` 中（数据不一致或外部调用错误）。

**Expected Behavior**:
- 验证失败，返回 `false`
- 日志警告："Equipment [id] not found in inventory"
- 状态不变，不触发存档

**Test**: 调用 `equip_item("invalid_id", MAIN_HAND)` → 验证返回false，日志记录。

---

### Edge Case 4: Inventory Contains Duplicate Equipment IDs

**Scenario**: 玩家获得两件相同ID的装备（例如两件Iron Blade），背包含有两个相同的ID字符串。

**Expected Behavior**:
- 允许重复ID存在（MVP设计）
- `inventory.erase(id)` 只移除一个实例（Godot Array行为）
- 每件装备有独立的强化等级（存档系统通过数组索引或UUID区分）

**Note**: MVP阶段简化设计，未来版本可能需要装备实例UUID来区分同名装备。

**Test**: 获得两件Iron Blade → 验证背包含有两个"equip_weapon_iron_blade" → 装备一件 → 验证背包仍有一件。

---

### Edge Case 5: All Slots Empty at Game Start

**Scenario**: 新游戏启动时所有槽位为空。

**Expected Behavior**:
- `equipped_slots = {}` (空字典)
- `inventory = []` (空数组)
- `equipped_count = 0`
- `empty_slot_count = 6`
- UI显示6个空槽位，无装备图标

**Test**: 新游戏启动 → 验证所有槽位为空，计数正确。

---

### Edge Case 6: Player Attempts to Equip While Inventory Empty

**Scenario**: 背包为空时玩家打开装备界面并尝试装备操作。

**Expected Behavior**:
- UI预防性禁用装备按钮（背包列表为空时无可装备项）
- 或显示提示："背包无装备可装备"

**Test**: 背包空时打开装备界面 → 验证装备按钮禁用或提示显示。

---

### Edge Case 7: Save Data Corruption - Missing Equipment ID

**Scenario**: 存档数据中的 `equipped_slots` 包含一个不存在的装备ID（例如旧版本装备被删除）。

**Expected Behavior**:
- 加载时检测到无效ID
- 日志警告："Equipment [id] not found in ItemDatabase, removing from slot"
- 清空该槽位（设为null）
- 继续加载其他槽位
- 不创建新游戏（仅移除无效数据）

**Test**: 存档包含无效装备ID → 加载 → 验证槽位清空，日志记录，其他数据正常。

---

### Edge Case 8: Enhancement Level Query for Unequipped Item

**Scenario**: UI尝试显示背包中装备的强化等级，但该装备从未被强化。

**Expected Behavior**:
- 从存档系统查询 `enhancement_levels[id]`
- 若不存在 → 默认返回 `0`（未强化）
- UI显示 "+0" 或不显示强化等级

**Test**: 查询未强化装备的强化等级 → 验证返回0。

## Dependencies

### Upstream Dependencies (本系统依赖)

| System | Type | Interface | Notes |
|--------|------|-----------|-------|
| **物品数据库** | Hard | `is_equipment_compatible_with_slot(id, slot)`, `get_equipment(id)` | 验证槽位兼容性和获取装备定义 |
| **存档系统** | Hard | `equipment.slots`, `equipment.inventory`, `enhancement_levels` | 加载/保存装备状态数据 |

**Constraint from 物品数据库 GDD**:
- EquipmentSlot枚举定义: MAIN_HAND, OFF_HAND, HEAD, BODY, ACCESSORY_1, ACCESSORY_2
- Slot-type compatibility matrix定义槽位允许的装备类型
- Equipment definition包含type, slot, rarity, base_attack, base_defense

**Constraint from 存档系统 GDD**:
- 存档数据结构包含 `equipment.slots`, `equipment.inventory`, `equipment.enhancement_levels`
- Slot change是critical event → 100ms内保存
- SaveManager监听 `slot_changed` 信号触发保存

---

### Downstream Dependencies (依赖本系统)

| System | Type | Interface Used | Notes |
|--------|------|---------------|-------|
| **战斗系统** | Hard | `get_equipped_items()` | 查询已装备物品计算攻击/防御数值 |
| **装备掉落系统** | Hard | `acquire_equipment(id)` | 新装备加入背包 |
| **强化公式系统** | Hard | `is_equipment_equipped(id)`, `get_equipped_items()` | 检查装备状态以决定强化目标 |
| **数值显示系统** | Soft | `get_equipped_items()` | HUD显示装备状态和总战力 |
| **装备强化系统** | Soft | `is_equipment_equipped(id)` | 强化界面需要检查装备是否已装备 |

**Interface Contracts**:
- EquipmentSlotManager保证返回数据格式: `{ slot: { equipment_id: String, enhancement_level: int } }`
- `slot_changed` 信号携带: `(slot: EquipmentSlot, equipment_id: String or null)`
- `equipment_acquired` 信号携带: `(equipment_id: String)`

---

### External Dependencies (非游戏系统)

| Dependency | Type | Usage |
|------------|------|-------|
| **Godot Dictionary** | Hard | 槽位映射存储 |
| **Godot Array** | Hard | 背包列表存储 |
| **Godot Signal** | Hard | 事件通知机制 |

## Tuning Knobs

| Knob | Default | Safe Range | Unit | What It Affects | Extreme Behavior |
|------|---------|------------|------|-----------------|------------------|
| **TOTAL_SLOT_COUNT** | 6 | 4–12 | slots | 装备槽位总数 | 太少：装备种类受限，成长线单一；太多：UI拥挤，玩家决策负担 |
| **MAX_INVENTORY_CAPACITY** | ∞ (unlimited) | 50–∞ | items | 背包容量上限 | 太低：频繁丢弃/出售，挫败感；太高：无压力，失去管理乐趣 |

**MVP Configuration**:
- `TOTAL_SLOT_COUNT = 6` (固定，与ItemDatabase EquipmentSlot枚举一致)
- `MAX_INVENTORY_CAPACITY = ∞` (不限制，简化设计)

---

### Future Expansion Knobs (Post-MVP)

| Knob | Default | Safe Range | Unit | What It Affects | Notes |
|------|---------|------------|------|-----------------|-------|
| **SLOT_UNLOCK_COST_FLOOR_N** | TBD | 0–1000 | gold | 解锁第N个槽位的费用 | 预留扩展：饰品槽可能需要解锁 |
| **INVENTORY_SORT_MODE** | AUTO_RARITY | — | enum | 背包默认排序方式 | 预留扩展：按稀有度/类型/等级排序 |

---

### Knob Configuration File

MVP阶段无配置文件，所有值使用硬编码常量。未来扩展可添加:

```json
{
  "version": "1.0.0",
  "slots": {
    "total_count": 6,
    "unlock_sequence": [MAIN_HAND, OFF_HAND, HEAD, BODY, ACCESSORY_1, ACCESSORY_2]
  },
  "inventory": {
    "max_capacity": -1,
    "sort_mode": "AUTO_RARITY"
  }
}
```

## Visual/Audio Requirements

### Visual Requirements

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| **装备成功闪光** | 槽位短暂白色闪光 (0.15s) + 装备图标弹跳入场动画 | 视觉反馈确认装备操作成功 |
| **卸下动画** | 装备图标缩小淡出 (0.2s) + 槽位短暂灰暗 | 区别于装备动画，表示"空出"状态 |
| **交换动画** | 原装备向背包移动 + 新装备从背包向槽位移动 (0.3s流畅过渡) | 双向流动效果，视觉清晰 |
| **新装备获得特效** | 装备图标从屏幕中央飞向背包位置 + 金色粒子跟随 | 服务于支柱"爽感反馈"，获得时刻是锚点 |
| **槽位空状态视觉** | 空槽位显示灰色虚线框 + "+"图标 | 提示玩家"可装备"，激励填充 |
| **装备稀有度边框** | 槽位中装备图标边框颜色对应稀有度（对齐ItemDatabase颜色） | 可视化成长进度 |

### Audio Requirements

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| **装备音效** | Post-MVP（音效系统负责） | MVP阶段无声效，后续添加装备"咔嗒"声 |
| **卸下音效** | Post-MVP | MVP阶段无声效 |
| **获得装备音效** | Post-MVP | MVP阶段无声效，后续添加"叮"声（稀有度越高音效越响亮） |

## UI Requirements

| Requirement | Specification | Priority |
|-------------|---------------|----------|
| **装备界面入口** | 主界面显示"装备"按钮，点击打开装备界面 | MVP |
| **槽位网格布局** | 6槽位按2行3列排列：上排(MAIN_HAND, OFF_HAND, HEAD)，下排(BODY, ACCESSORY_1, ACCESSORY_2) | MVP |
| **背包列表** | 背包装备以列表形式显示，支持滚动，按稀有度排序（高→低） | MVP |
| **装备详情悬浮** | 点击装备显示详情面板（名称、稀有度、攻击/防御、强化等级） | MVP |
| **装备/卸下按钮** | 详情面板显示"装备"或"卸下"按钮，根据当前状态切换 | MVP |
| **战力总览** | 装备界面顶部显示总攻击/防御数值（已装备装备数值之和） | MVP |
| **空槽位提示** | 空槽位显示"+ 点击装备"文字提示 | MVP |
| **槽位兼容性反馈** | 尝试装备不兼容装备时显示"无法装备到此槽位"提示 | MVP |

## Acceptance Criteria

### Equip Operation Criteria

- **GIVEN** 玩家背包有Iron Blade (`equip_weapon_iron_blade`)，MAIN_HAND槽位为空，**WHEN** 调用 `equip_item("equip_weapon_iron_blade", MAIN_HAND)`，**THEN** 函数返回 `true`，`equipped_slots[MAIN_HAND] = "equip_weapon_iron_blade"`，`inventory` 不包含该ID，`slot_changed` 信号发出。

- **GIVEN** 玩家背包有Iron Blade，BODY槽位为空，**WHEN** 尝试 `equip_item("equip_weapon_iron_blade", BODY)`，**THEN** 函数返回 `false`，槽位状态不变，背包不变，无信号发出，UI显示"无法装备"提示。

- **GIVEN** 背包为空，**WHEN** 尝试 `equip_item("equip_weapon_iron_blade", MAIN_HAND)`，**THEN** 函数返回 `false`，日志警告，状态不变。

---

### Unequip Operation Criteria

- **GIVEN** MAIN_HAND槽位已装备Iron Blade，**WHEN** 调用 `unequip_slot(MAIN_HAND)`，**THEN** 函数返回 `true`，`equipped_slots[MAIN_HAND] = null`，`inventory` 包含 `"equip_weapon_iron_blade"`，`slot_changed` 信号发出。

- **GIVEN** OFF_HAND槽位为空，**WHEN** 调用 `unequip_slot(OFF_HAND)`，**THEN** 函数返回 `false`，状态不变，无信号发出。

---

### Swap Operation Criteria

- **GIVEN** MAIN_HAND槽位已装备Iron Blade，背包有Shadow Dagger (`equip_weapon_shadow_dagger`)，**WHEN** 调用 `swap_equipment("equip_weapon_shadow_dagger", MAIN_HAND)`，**THEN** `equipped_slots[MAIN_HAND] = "equip_weapon_shadow_dagger"`，`inventory` 包含Iron Blade但不包含Shadow Dagger。

---

### Equipment Acquisition Criteria

- **GIVEN** 装备掉落系统触发，**WHEN** 调用 `acquire_equipment("equip_weapon_dragon_slayer")`，**THEN** `inventory` 包含 `"equip_weapon_dragon_slayer"`，`equipment_acquired` 信号发出，SaveManager收到critical save触发。

---

### Query Interface Criteria

- **GIVEN** MAIN_HAND装备Iron Blade +3，HEAD装备Iron Helm +0，**WHEN** 调用 `get_equipped_items()`，**THEN** 返回 `{ MAIN_HAND: { equipment_id: "equip_weapon_iron_blade", enhancement_level: 3 }, HEAD: { equipment_id: "equip_armor_iron_helm", enhancement_level: 0 } }`。

---

### Counting Formula Criteria

- **GIVEN** 3槽位已装备（MAIN_HAND, HEAD, BODY），**WHEN** 计算 `equipped_count`，**THEN** 结果为 `3`。

- **GIVEN** 3槽位已装备，**WHEN** 计算 `empty_slot_count`，**THEN** 结果为 `6 - 3 = 3`。

- **GIVEN** 背包有5件装备，**WHEN** 计算 `inventory_count`，**THEN** 结果为 `5`。

- **GIVEN** 3槽位已装备，背包有5件装备，**WHEN** 计算 `total_equipment`，**THEN** 结果为 `3 + 5 = 8`。

---

### Initial State Criteria

- **GIVEN** 新游戏启动，存档系统返回默认数据，**WHEN** EquipmentSlotManager初始化，**THEN** `equipped_slots = {}`，`inventory = []`，`equipped_count = 0`，`empty_slot_count = 6`。

---

### Edge Case Criteria

- **GIVEN** 存档数据包含无效装备ID `"equip_invalid_xyz"`，**WHEN** 加载存档，**THEN** 无效ID从槽位移除，日志警告记录，其他槽位正常加载。

- **GIVEN** 装备从未被强化（`enhancement_levels` 中不存在该ID），**WHEN** 查询强化等级，**THEN** 返回 `0`。

## Open Questions

| Question | Owner | Target Resolution | Status |
|----------|-------|-------------------|--------|
| **是否需要装备实例UUID？** | Systems Designer | MVP后评估 | Open — MVP允许重复ID，未来版本区分同名装备需UUID |
| **背包是否需要容量上限？** | Economy Designer | MVP后评估 | Open — MVP无限制，未来版本可能添加上限+扩展机制 |
| **是否需要装备快捷装备（一键最优）？** | UX Designer | 原型验证时 | Open — 简化装备流程，但可能减少决策乐趣 |
| **是否需要装备对比功能？** | UX Designer | 原型验证时 | Open — 悬停对比待装备与已装备的数值差异 |
| **饰品槽是否需要解锁？** | Game Designer | MVP后评估 | Open — MVP默认解锁所有6槽位，未来可能添加解锁机制 |
| **是否需要装备锁定功能（防止误卸）？** | UX Designer | Post-MVP | Open — 防止玩家误卸重要装备 |