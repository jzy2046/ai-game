# 装备掉落系统

> **Status**: Designed
> **Author**: User + agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: 爽感反馈, 稳定成长, 掌控节奏

## Overview

装备掉落系统是战斗胜利后的奖励展示与发放层，负责将掉落表系统解析的物品结果转化为可视化奖励反馈并发放到玩家库存。战斗胜利时，战斗系统发出 `combat_complete` 信号，本系统接收后调用地牢结构系统获取该层的掉落表ID，调用掉落表系统 `resolve_drop()` 解析掉落物品，展示掉落面板（装备图标弹出、材料飞入计数器），玩家确认后将物品添加到存档系统，关闭面板后返回战斗系统的 DropResolution → Complete 流程。

本系统是"收获时刻"的可视化实现——每次战斗胜利都有材料必定掉落（稳定感），装备随机掉落（期待感），掉落面板用稀有度颜色编码和弹出动画强化"收获"的爽感。玩家点击确认继续推进，节奏由玩家掌控。

## Player Fantasy

**核心幻想**: "每次胜利都是收获庆典" — 掉落面板弹出是战斗胜利后的高潮时刻，玩家看到装备图标从击败敌人位置飞出、听到音效（后续版本）、看到稀有度颜色编码，在那一瞬间感受"我得到了什么"。

**情绪锚点**: 第一次看到 EPIC 装备图标弹出。玩家推进到 floor 10，击败 Shadow Knight BOSS，掉落面板弹出——Guardian Plate（EPIC 稀有度，紫色图标）从敌人位置飞出，伴随粒子爆发和屏幕震动。玩家点击图标预览属性，看到 `defense = 50`，心中计算"强化到+10会变成100防御"。这一刻，掉落面板完成了"惊喜+期待"的双重幻想。

**收获确定性与期待感**:
- 材料必定掉落（确定性） → 每次 UI 都会显示 Enhancement Stone 飞入计数器，稳定感
- 装备概率掉落（期待感） → 有时无装备（面板只显示材料），有时有装备（惊喜）
- 稀有度颜色编码（价值感知） → COMMON=棕色、RARE=紫色、EPIC=橙色，玩家一眼判断价值

**参考时刻**:
- 暗黑破坏神：BOSS击败后掉落物品从尸体飞出，图标弹出伴随音效，玩家点击图标查看属性
- Idle Slayer：每次击败自动弹出掉落，材料飞入计数器，装备图标短暂停留后消失

**支柱对应**:
- 爽感反馈：掉落图标弹出动画、粒子爆发（稀有掉落）、屏幕震动（BOSS掉落）
- 稳定成长：材料必定掉落确保每次战斗有收益，无"白打"体验
- 掌控节奏：玩家可选择点击装备查看详情，或直接点击"继续"快速推进

## Detailed Design

### Core Rules

**Rule 1: Combat Victory Trigger**

掉落流程由战斗胜利信号触发。

| Event | Action | Signal |
|-------|--------|--------|
| 战斗胜利 | Combat System发出 `combat_complete(floor_id, victory=true)` | combat_complete |
| 接收信号 | EquipmentDropSystem监听信号，触发掉落流程 | subscription |
| 状态检查 | 验证 `victory == true`，否则忽略 | — |

**信号订阅**:
```gdscript
func _ready():
    CombatSystem.combat_complete.connect(_on_combat_complete)

func _on_combat_complete(floor_id: int, victory: bool):
    if not victory:
        return  # 战斗失败（MVP无此情况）→ 无掉落
    start_drop_resolution(floor_id)
```

---

**Rule 2: Drop Resolution Process**

收到胜利信号后，解析掉落物品。

| Step | Action | System Call |
|------|--------|-------------|
| 1 | 获取掉落表ID | `get_drop_table_id_for_floor(floor_id)` 或敌人定义中的 `drop_table_id` |
| 2 | 调用掉落解析 | `DropTableSystem.resolve_drop(drop_table_id)` |
| 3 | 合并多敌人掉落 | 若战斗有多个敌人，合并所有掉落结果 |
| 4 | 验证物品有效性 | 对每个 `item_id` 调用 `ItemDatabase.has_equipment/has_material()` |
| 5 | 准备UI数据 | 构建显示数据结构 `{ items: [{ id, name, rarity, type, quantity }] }` |

**掉落结果合并**:
```gdscript
func aggregate_drops(enemy_drop_results: Array) -> Dictionary:
    var guaranteed_all = []
    var weighted_all = []
    for result in enemy_drop_results:
        guaranteed_all.append_array(result.guaranteed)
        weighted_all.append_array(result.weighted)
    return { guaranteed: guaranteed_all, weighted: weighted_all }
```

---

**Rule 3: Drop Panel Display**

掉落解析完成后，显示掉落面板。

| Step | Action | UI Layer |
|------|--------|----------|
| 1 | 创建掉落面板 | ModalLayer (阻断其他输入) |
| 2 | 显示材料掉落 | 材料图标飞入HUD计数器位置 |
| 3 | 显示装备掉落 | 装备图标从击败位置弹出 |
| 4 | 应用稀有度颜色 | 根据 rarity 应用颜色编码 |
| 5 | 启动弹出动画 | Tween animation (duration=0.3s) |
| 6 | 等待玩家确认 | 显示"继续"按钮 |

**面板层级**: ModalLayer → 掉落面板 → 阻断HUD和Gameplay层输入（参考UI布局系统）。

---

**Rule 4: Drop Item Animation**

每个掉落物品有独立的弹出动画。

**材料飞入动画**:
- 起始位置：击败敌人位置（或屏幕中央）
- 目标位置：HUD材料计数器位置
- 动画：飞入 + 缩小 + 数值更新
- 时长：0.5秒

**装备弹出动画**:
- 起始位置：击败敌人位置（或屏幕中央）
- 目标位置：掉落面板中央（停留供玩家查看）
- 动画：弹出 + bounce效果 + 稀有度颜色闪烁
- 时长：0.3秒弹出 + 停留
- 粒子效果：RARE/EPIC/LEGENDARY装备触发粒子爆发

**动画实现**:
```gdscript
func animate_material_drop(item_id: String, quantity: int, start_pos: Vector2):
    var target_pos = HUD.get_material_counter_position()
    var icon = create_material_icon(item_id)
    icon.position = start_pos
    var tween = create_tween()
    tween.tween_property(icon, "position", target_pos, 0.5)
    tween.tween_callback(func(): add_material_to_inventory(item_id, quantity))
```

---

**Rule 5: Player Interaction**

玩家可点击装备图标查看详情，或点击"继续"关闭面板。

| Interaction | Action | Result |
|-------------|--------|--------|
| 点击装备图标 | 显示装备属性tooltip | 显示 `name`, `attack`, `defense`, `rarity` |
| 点击"继续"按钮 | 关闭掉落面板 | 添加所有物品到库存 → 返回战斗流程 |
| 无交互超时 | (MVP不实现) | — |

**Tooltip内容**:
```
[Iron Blade +0]
Attack: 10
Defense: 0
Rarity: COMMON (棕色)
```

---

**Rule 6: Item Addition to Inventory**

玩家确认后，将物品添加到存档系统。

| Item Type | Addition Method | System |
|-----------|-----------------|--------|
| 材料 | `add_material(item_id, quantity)` | 材料系统或存档系统 |
| 装备 | `add_equipment_to_inventory(item_id)` | 存档系统（装备槽系统管理装备槽） |

**装备实例创建**:
```gdscript
func add_equipment_to_inventory(equipment_id: String):
    var instance_id = generate_instance_id()  # 如 "equip_weapon_iron_blade_001"
    SaveSystem.equipment_inventory.append(instance_id)
    SaveSystem.equipment_definitions[instance_id] = equipment_id
    SaveSystem.enhancement_levels[instance_id] = 0  # 新装备初始+0
```

---

**Rule 7: Panel Close and Flow Return**

掉落面板关闭后，返回战斗系统继续流程。

| Step | Action | Signal/Call |
|------|--------|-------------|
| 1 | 移除掉落面板 | ModalLayer移除面板节点 |
| 2 | 解除输入阻断 | ModalLayer不再阻断HUD/Gameplay |
| 3 | 通知战斗系统 | 发出 `drop_panel_closed` 信号或调用 `CombatSystem.complete_drop_resolution()` |
| 4 | 战斗状态转换 | Combat System: DropResolution → Complete → Idle |

---

**Rule 8: Empty Drop Handling**

当掉落解析返回空装备结果（只有材料）。

**场景**: `weighted: []`（无装备掉落）

**处理**:
- 面板仅显示材料飞入动画
- 不显示装备图标
- "继续"按钮直接显示，无装备预览
- 符合设计意图：装备是概率掉落，材料是必定掉落

---

**Rule 9: Multiple Enemy Drops Aggregation**

战斗中击败多个敌人时，合并掉落展示。

**场景**: 战斗有3个敌人，每个敌人独立掉落

**处理**:
- 每个敌人击败时独立调用 `resolve_drop(enemy.drop_table_id)`
- 等待所有敌人击败后（战斗进入Victory状态），合并掉落结果
- 面板一次性显示所有掉落（不逐个弹出）
- 材料数量叠加显示（如 3个Enhancement Stone → 显示 "Enhancement Stone x3"）
- 装备图标按稀有度排序显示（EPIC在前，COMMON在后）

---

**Rule 10: Query Interface**

`EquipmentDropSystem` 提供以下接口：

| Method | Return | Purpose |
|--------|--------|---------|
| `start_drop_resolution(floor_id)` | void | 触发掉落流程 |
| `is_drop_panel_active()` | bool | 检查掉落面板是否正在显示 |
| `get_current_drops()` | Dictionary | 获取当前掉落数据（用于测试） |
| `close_drop_panel()` | void | 强制关闭面板（跳过动画） |

---

### States and Transitions

掉落系统有独立状态机：

| State | Description | Entry | Exit |
|-------|-------------|-------|------|
| **Idle** | 无掉落流程，等待战斗胜利信号 | 初始化/面板关闭 | `combat_complete` 信号 |
| **Resolving** | 正在解析掉落（调用drop_table_system） | 收到信号 | 解析完成 |
| **Displaying** | 掉落面板正在显示动画 | 解析完成 | 动画完成 |
| **WaitingForInput** | 等待玩家点击"继续" | 动画完成 | 玩家点击 |
| **Closing** | 正在关闭面板（可选收尾动画） | 点击"继续" | 面板移除 |

**Transition Table**:
| Current | Trigger | Next | Action |
|---------|---------|------|--------|
| Idle | `combat_complete(true)` | Resolving | 调用 `resolve_drop()` |
| Resolving | 解析完成 | Displaying | 创建面板，启动动画 |
| Displaying | 动画完成 | WaitingForInput | 显示"继续"按钮 |
| WaitingForInput | 点击"继续" | Closing | 添加物品，通知战斗系统 |
| Closing | 面板移除 | Idle | 解除阻断 |

---

### Interactions with Other Systems

**上游依赖**:

| System | Data Flow | Interface |
|--------|-----------|-----------|
| **战斗系统** | `combat_complete` 信号 | subscription |
| **掉落表系统** | `resolve_drop(id)` → drop result | method call |
| **物品数据库** | equipment/material definitions | `get_equipment(id)`, `get_rarity_color(rarity)` |
| **敌人系统** | 敌人 `drop_table_id` | `enemy.drop_table_id` (通过战斗系统传递) |

**下游依赖**:

| System | Data Flow | Interface |
|--------|-----------|-----------|
| **存档系统** | 物品添加 | `add_material()`, `add_equipment_to_inventory()` |
| **材料系统** | 材料计数更新 | 材料计数器UI刷新 |
| **视觉反馈系统** | 粒子爆发触发 | `trigger_particle_burst(position, rarity)` |
| **粒子系统** | 粒子生成 | spawn particles on rare drop |
| **UI布局系统** | Modal Layer阻断 | ModalLayer激活 |

## Formulas

### F1: Drop Animation Duration

The animation duration formula for drop item display:

`animation_duration = POPUP_DURATION + (rarity_bonus if rarity >= RARE else 0)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| POPUP_DURATION | — | float | 0.3秒 | Base popup animation duration |
| rarity_bonus | — | float | 0.0–0.3秒 | Extra duration for rare items (particle effect) |
| rarity | — | Rarity enum | COMMON–LEGENDARY | Item rarity from ItemDatabase |

**Output Range:** 0.3秒–0.6秒

**Example:**
Iron Blade (COMMON):
```
animation_duration = 0.3 + 0 = 0.3秒
```

Dragon Slayer (RARE):
```
animation_duration = 0.3 + 0.15 = 0.45秒 (extra for particle)
```

Guardian Plate (EPIC):
```
animation_duration = 0.3 + 0.3 = 0.6秒 (max for legendary/epic particle burst)
```

---

### F2: Material Flight Duration

The material flight animation duration:

`flight_duration = MATERIAL_FLIGHT_BASE + distance_factor`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| MATERIAL_FLIGHT_BASE | — | float | 0.3秒 | Base flight time |
| distance_factor | — | float | 0.0–0.2秒 | Extra time based on distance |
| start_position | — | Vector2 | screen coordinates | Enemy defeat position |
| target_position | — | Vector2 | HUD counter position | Material counter location |

**Output Range:** 0.3秒–0.5秒

**Calculation**:
```gdscript
func calculate_flight_duration(start_pos: Vector2, target_pos: Vector2) -> float:
    var distance = start_pos.distance_to(target_pos)
    var max_distance = get_screen_diagonal() * 0.5  # 假设最大距离为半屏
    var distance_factor = (distance / max_distance) * 0.2
    return MATERIAL_FLIGHT_BASE + distance_factor
```

---

### F3: Material Quantity Aggregation

The total material quantity calculation for multi-enemy drops:

`total_quantity = sum(result.quantity for each result where result.item_id == target_item_id)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| result.quantity | — | int | 1–10 | Quantity from single enemy drop |
| target_item_id | — | String | — | Material ID being aggregated |
| total_quantity | — | int | 1–30 | Summed quantity across all enemies |

**Output Range:** 1–30 (assuming max 10 enemies × max 3 quantity each)

**Example:**
3 enemies drop Enhancement Stone:
```
enemy_1: { mat_enhance_stone_common, quantity: 2 }
enemy_2: { mat_enhance_stone_common, quantity: 1 }
enemy_3: { mat_enhance_stone_common, quantity: 2 }

total_quantity = 2 + 1 + 2 = 5
```

---

### F4: Drop Item Screen Position

The initial popup position for dropped items:

`popup_position = enemy_defeat_position + offset_random`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| enemy_defeat_position | — | Vector2 | screen coordinates | Where enemy was defeated |
| offset_random | — | Vector2 | (-30px, -30px) to (30px, 30px) | Random offset to avoid overlap |
| popup_position | — | Vector2 | screen coordinates | Starting position for animation |

**Output Range:** enemy_defeat_position ± 30px

**Purpose**: Multiple equipment drops from same enemy have slight position variation to avoid icon overlap.

---

### F5: Equipment Instance ID Generation

The instance ID generation pattern:

`instance_id = equipment_id + "_" + timestamp + "_" + random_suffix`

**Pattern:**
| Component | Format | Example |
|-----------|--------|---------|
| equipment_id | String | `equip_weapon_iron_blade` |
| timestamp | int | `202605021530` |
| random_suffix | int (3 digits) | `001` |
| instance_id | String | `equip_weapon_iron_blade_202605021530_001` |

**Rationale**: Unique ID for each equipment instance, allowing multiple copies of same equipment in inventory.

## Edge Cases

### E1: Invalid Drop Table ID

**场景**: 战斗胜利，但敌人定义的 `drop_table_id` 不存在或无效。

**处理**: 调用 `DropTableSystem.resolve_drop(invalid_id)` 返回空结果 `{ guaranteed: [], weighted: [] }`。本系统检测到空结果：
- 不显示掉落面板
- 直接通知战斗系统继续（跳过 DropResolution → Complete）
- 日志警告："Drop table [id] invalid, no drops displayed"

**玩家体验**: 战斗胜利但无掉落UI，直接进入下一层推进。虽有数据错误但流程不中断。

---

### E2: Empty Equipment Drop (Only Materials)

**场景**: `resolve_drop()` 返回 `weighted: []`（无装备掉落），`guaranteed: [materials]`。

**处理**: 正常流程：
- 显示材料飞入动画
- 不显示装备图标
- "继续"按钮直接显示
- 符合设计意图：装备概率掉落，材料必定掉落

**UI行为**: 掉落面板简化版（仅材料飞入，无装备停留）。

---

### E3: Invalid Item ID in Drop Result

**场景**: Drop Table返回的 `item_id` 不存在于 ItemDatabase。

**处理**:
- 验证阶段：对每个 `item_id` 调用 `has_equipment/has_material()`
- 无效ID → 移除该条目，不添加到显示列表
- 日志警告："Invalid item [id] in drop result, skipped"
- 其他有效物品正常显示

**玩家体验**: 掉落面板缺少某物品（数据错误），但其他物品正常显示。

---

### E4: Multiple Drops at Same Position

**场景**: 多个装备从同一敌人位置弹出，图标重叠。

**处理**: Rule 4 的 `offset_random` 变量：
- 每个装备图标应用随机偏移 (±30px)
- 确保图标分散显示，不重叠
- 偏移量计算：`offset = Vector2(random_range(-30, 30), random_range(-30, 30))`

**UI行为**: 多个装备图标从敌人位置向四周散射弹出。

---

### E5: Inventory Full (If Applicable)

**场景**: 玩家库存达到上限（MVP未定义上限）。

**处理**:
- MVP阶段：库存无上限（简化实现）
- 后续版本：若库存满，装备掉落仍添加（自动扩展库存）
- 材料掉落：堆叠到 max_stack，超出部分丢弃（日志警告）

**MVP简化**: 不实现库存上限，所有掉落物品自动添加。

---

### E6: Drop Panel Interrupted by App Close

**场景**: 掉落面板正在显示时，玩家关闭应用或切后台。

**处理**:
- 存档系统记录当前掉落状态（待添加物品列表）
- 下次启动时，恢复掉落面板或自动添加物品
- 存档策略：优先自动添加物品（跳过显示），避免卡在掉落流程

**存档恢复**: 启动时检测 `pending_drops` 存档字段，若有待处理掉落，直接添加到库存。

---

### E7: Duplicate Equipment (Same ID Multiple Times)

**场景**: 同一装备多次掉落（如两件 Iron Blade）。

**处理**: 正常流程：
- 每件装备生成独立实例ID（F5 formula）
- `equip_weapon_iron_blade_001`, `equip_weapon_iron_blade_002`
- 两件装备独立存在于库存
- 玩家可分别强化到不同等级

**UI显示**: 两件 Iron Blade 图标并列显示，各自有独立的 instance_id。

---

### E8: Rapid Equipment Icon Clicks

**场景**: 玩家快速点击装备图标多次。

**处理**:
- 第一次点击显示tooltip
- tooltip显示期间，后续点击无效果
- tooltip关闭后可再次点击

**UI行为**: Tooltip独占，防止多次触发。

---

### E9: Animation Interrupted by Skip

**场景**: 掉落动画正在播放时，玩家点击"继续"按钮。

**处理**:
- MVP简化：动画期间"继续"按钮禁用
- 动画完成后按钮激活
- 若需提前关闭（后续版本）：Tween停止，物品直接添加，面板关闭

**MVP行为**: 动画期间按钮禁用，确保动画完整播放。

---

### E10: No Valid Enemy Defeat Position

**场景**: 敌人击败位置不可用（如跳过战斗时敌人位置未定义）。

**处理**: Fallback位置：
- 使用屏幕中央作为popup起始位置
- `enemy_defeat_position = get_screen_center()` if invalid
- 动画正常播放，不影响显示

**场景**: 跳过战斗 → 敌人直接进入DEFEATED状态 → 位置可能为空或默认值。

---

### E11: Drop Panel Blocked by Higher Modal

**场景**: 掉落面板显示时，更高优先级的Modal出现（如强制通知）。

**处理**: 掉落面板在 ModalLayer，理论上无更高优先级Modal。若发生：
- 高优先级Modal覆盖掉落面板
- 输入阻断由高优先级Modal接管
- 等待高优先级Modal关闭后恢复掉落面板交互

**MVP风险**: 理论上不发生（掉落面板是最高优先级UI事件）。

---

### E12: Equipment Tooltip Timeout

**场景**: 玩家长时间不关闭tooltip（后续版本可能有timeout）。

**处理**: MVP简化：
- 无timeout，tooltip持续显示直到玩家点击关闭或点击其他图标
- 后续版本可添加：tooltip显示5秒后自动关闭

## Dependencies

### Upstream Dependencies (本系统依赖)

| System | Type | Interface | Data Flow |
|--------|------|-----------|-----------|
| **战斗系统** | Hard | `combat_complete` signal | `{ floor_id, victory }` 触发掉落流程 |
| **掉落表系统** | Hard | `resolve_drop(drop_table_id)` | 返回 `{ guaranteed: [...], weighted: [...] }` |
| **物品数据库** | Hard | `get_equipment(id)`, `get_material(id)`, `get_rarity_color(rarity)` | 物品定义、稀有度颜色 |
| **敌人系统** | Hard | `enemy.drop_table_id`, `enemy.position` | 掉落表ID引用、击败位置 |
| **UI布局系统** | Soft | ModalLayer, screen coordinates | 面板层级、位置参考 |

**Interface Contracts (本系统期望上游提供)**:
- `combat.combat_complete` signal: `{ floor_id: int, victory: bool }`
- `DropTableSystem.resolve_drop(id)` → `{ guaranteed: [{ item_id, quantity }], weighted: [{ item_id, quantity }] }`
- `ItemDatabase.get_equipment(id)` → `{ base_attack, base_defense, rarity, display_name, icon_path }`
- `ItemDatabase.get_rarity_color(rarity)` → `Color(hex)`
- `enemy.position` → `Vector2` (defeat animation position)

---

### Downstream Dependencies (依赖本系统)

| System | Type | Interface Used | Data Flow |
|--------|------|---------------|-----------|
| **存档系统** | Hard | `add_material()`, `add_equipment_to_inventory()` | 物品发放、库存更新 |
| **材料系统** | Soft | 材料计数器UI刷新 | 材料飞入后计数更新 |
| **装备强化系统** | Soft | 新装备进入库存 | 强化系统可操作新装备 |
| **战斗系统** | Hard | `drop_panel_closed` signal | 面板关闭后继续流程 |
| **视觉反馈系统** | Soft | 粒子爆发触发 | 稀有装备弹出时触发VFX |
| **粒子系统** | Soft | particle spawn | EPIC/LEGENDARY掉落触发粒子 |

**Interface Contracts (本系统向下游提供)**:
- 发出 `drop_panel_closed` signal → 战斗系统监听
- 发出 `material_added(item_id, quantity)` signal → 材料系统监听（可选）
- 发出 `equipment_added(instance_id, equipment_id)` signal → 装备槽系统监听（可选）

---

### Dependency Verification Checklist

**验证上游接口可用性**:
- [x] 战斗系统GDD已定义 `combat_complete` signal ✓
- [x] 战斗系统GDD已定义 DropResolution state ✓
- [x] 掉落表系统GDD已定义 `resolve_drop()` ✓
- [x] 物品数据库GDD已定义 `get_equipment()`, `get_rarity_color()` ✓
- [ ] 存档系统GDD是否已定义 `add_material()` (待验证)
- [ ] 存档系统GDD是否已定义 `add_equipment_to_inventory()` (待验证)

**验证下游依赖已记录**:
- [ ] 战斗系统GDD需监听 `drop_panel_closed` (待确认)
- [ ] 材料系统GDD需监听材料添加信号 (待设计)
- [ ] 存档系统GDD需定义物品添加接口 (待设计)

## Tuning Knobs

### G1: Popup Animation Duration

**参数名**: `POPUP_DURATION`

**当前值**: 0.3秒

**安全范围**: 0.2秒 – 0.5秒

**影响**: 装备图标弹出的基础动画时长。

- 过短(<0.2秒): 弹出太快，玩家来不及感知
- 过长(>0.5秒): 弹出拖沓，等待感强
- 推荐(0.3秒): 快速但有感知时间

**调整场景**: 若视觉反馈系统粒子效果延长，可配合延长至0.4秒。

---

### G2: Rarity Animation Bonus

**参数名**: `RARITY_ANIMATION_BONUS`

**当前值**: RARE=0.15秒, EPIC=0.3秒, LEGENDARY=0.3秒

**安全范围**: 0.0秒 – 0.5秒

**影响**: 稀有装备弹出的额外动画时间（粒子效果同步）。

- RARE: 0.15秒 (轻微粒子)
- EPIC: 0.3秒 (强粒子爆发)
- LEGENDARY: 0.3秒 (屏幕震动 + 粒子)

**调整场景**: 若粒子效果强度调整，同步调整此参数。

---

### G3: Material Flight Duration Base

**参数名**: `MATERIAL_FLIGHT_BASE`

**当前值**: 0.3秒

**安全范围**: 0.2秒 – 0.5秒

**影响**: 材料飞入计数器的基础时间。

- 过短(<0.2秒): 飞入太快，计数器跳变无感知
- 过长(>0.5秒): 飞入拖沓，等待材料结算
- 推荐(0.3秒): 快速飞入，计数器平滑更新

---

### G4: Material Flight Distance Factor

**参数名**: `MATERIAL_FLIGHT_DISTANCE_FACTOR`

**当前值**: 0.2秒

**安全范围**: 0.0秒 – 0.3秒

**影响**: 材料飞入动画根据距离增加的额外时间。

- 0.0秒: 所有材料统一时长（简化）
- 0.2秒: 远距离敌人掉落材料飞入更慢（自然感）
- 0.3秒: 距离差异明显

---

### G5: Drop Icon Position Offset Range

**参数名**: `DROP_OFFSET_RANGE`

**当前值**: 30px

**安全范围**: 10px – 50px

**影响**: 多装备弹出时的随机偏移范围。

- 过小(<10px): 多装备图标仍重叠
- 过大(>50px): 散射太开，超出掉落区域
- 推荐(30px): 适度分散，视觉清晰

---

### G6: Drop Panel Display Timeout (Post-MVP)

**参数名**: `DROP_PANEL_TIMEOUT`

**当前值**: None (MVP不实现)

**安全范围**: 3秒 – 10秒

**影响**: 掉落面板自动关闭的超时时间。

- 3秒: 快速自动关闭，玩家无需点击
- 10秒: 长时间停留，玩家有充足时间查看
- MVP: 无timeout，必须玩家点击"继续"

---

### G7: Tooltip Display Timeout (Post-MVP)

**参数名**: `TOOLTIP_TIMEOUT`

**当前值**: None (MVP不实现)

**安全范围**: 3秒 – 10秒

**影响**: 装备tooltip自动关闭的超时时间。

- 3秒: 快速自动关闭
- 5秒: 中等停留时间
- MVP: 无timeout，玩家点击关闭

---

### G8: Modal Layer Blocking Duration

**参数名**: `MODAL_BLOCKING_DURATION`

**当前值**: 整个掉落流程

**安全范围**: 掉落流程开始 → 结束

**影响**: ModalLayer阻断其他输入的时间窗口。

- 掉落开始: ModalLayer激活，阻断HUD/Gameplay
- 面板关闭: ModalLayer解除阻断
- 确保玩家无法在掉落期间进行其他操作

---

### G9: Particle Burst Intensity by Rarity

**参数名**: `PARTICLE_INTENSITY_RARE`, `PARTICLE_INTENSITY_EPIC`, `PARTICLE_INTENSITY_LEGENDARY`

**当前值**: RARE=30, EPIC=60, LEGENDARY=100 (particle count)

**安全范围**: 10 – 200

**影响**: 稀有装备弹出时的粒子数量。

- RARE: 30 (轻微闪烁)
- EPIC: 60 (明显爆发)
- LEGENDARY: 100 (屏幕震动级)

**调整场景**: 移动端性能预算限制，粒子数量需控制。

---

### G10: Screen Shake Intensity for Legendary

**参数名**: `SCREEN_SHAKE_LEGENDARY`

**当前值**: 5px amplitude

**安全范围**: 0px – 20px

**影响**: LEGENDARY装备掉落时的屏幕震动幅度。

- 0px: 无震动
- 5px: 轻微震动（MVP）
- 20px: 强震动（可能干扰视觉）

## Visual/Audio Requirements

### Visual Feedback Moments

| 触发时机 | 预期视觉效果 | 实现归属 |
|---------|-------------|---------|
| 战斗胜利 → DropResolution | 屏幕中央区域准备显示掉落 | 本系统UI |
| 装备图标弹出 | 图标从敌人位置弹出 + bounce动画 | 本系统 Tween |
| 稀有装备弹出 | 粒子爆发 + 稀有度颜色闪烁 | 粒子系统 (triggered by本系统) |
| LEGENDARY弹出 | 屏幕震动 + 强粒子 + 金色光芒 | 粒子系统 + 震动系统 |
| 材料飞入 | 图标飞向HUD计数器 + 缩小动画 | 本系统 Tween |
| 计数器更新 | 材料计数器数值跳变 + 数字飞溅 | 数值显示系统 |
| Tooltip显示 | 装备属性面板弹出 + 半透明背景 | 本系统UI |
| 面板关闭 | 面板淡出 + ModalLayer解除 | 本系统 Tween |

**稀有度视觉编码** (from ItemDatabase):
| Rarity | Color | Visual Cue |
|--------|-------|------------|
| COMMON | #8B6914 (Earthen Brown) | 无粒子，简单弹出 |
| UNCOMMON | #7CB342 (Verdant Growth) | 无粒子，绿色图标 |
| RARE | #9B7BB8 (Soft Lavender) | 30粒子爆发，紫色图标 |
| EPIC | #F27D16 (Celebration Orange) | 60粒子爆发，橙色图标 |
| LEGENDARY | #E5A50A (Golden Amber) | 100粒子 + 屏幕震动，金色图标 |

---

### Visual Performance Budget

| Visual Element | Particle Count | Draw Call Impact | Notes |
|----------------|---------------|------------------|-------|
| COMMON/UNCOMMON装备弹出 | 0 | 1 (icon only) | 无额外粒子 |
| RARE装备弹出 | 30 | +5-10 | 简单粒子爆发 |
| EPIC装备弹出 | 60 | +10-20 | 强粒子爆发 |
| LEGENDARY装备弹出 | 100 | +20-30 | 屏幕震动级 |
| 材料飞入动画 | 0 | 1 (icon) | 无粒子 |

**总粒子预算**: 单次掉落最多100粒子（LEGENDARY），控制在移动端性能预算内。

---

### Audio Feedback Moments (音效系统负责)

| 触发时机 | 预期音效 | 实现归属 |
|---------|---------|---------|
| 装备图标弹出 | 装备掉落音效（轻快） | 音效系统 |
| 稀有装备弹出 | 特殊掉落音效（惊喜感） | 音效系统 |
| LEGENDARY弹出 | 传奇掉落音效（震撼） | 音效系统 |
| 材料飞入 | 材料掉落音效（清脆） | 音效系统 |
| 计数器更新 | 数值跳变音效 | 音效系统 |
| Tooltip显示 | UI点击音效 | 音效系统 |
| 面板关闭 | UI关闭音效 | 音效系统 |

**MVP阶段**: 音效系统为Vertical Slice，MVP阶段可暂时无声效。本系统发出信号供音效系统后续接入。

---

### MVP Visual Simplifications

**MVP简化**:
- 无屏幕震动（LEGENDARY级别后续版本添加）
- 无音效（等待音效系统实现）
- 粒子效果简化（RARE及以上触发粒子，数量控制在30-60）
- Tooltip无动画（直接显示）

**后续版本扩展**:
- LEGENDARY屏幕震动
- 所有稀有级别音效
- Tooltip弹出动画
- 装备图标3D翻转效果

## UI Requirements

### UI Elements Owned by This System

| 元素 | 功能 | 显示时机 | 交互 |
|-----|------|---------|-----|
| **掉落面板** | 容器面板，包含所有掉落UI元素 | DropResolution状态 | Modal阻断 |
| **装备图标** | 显示掉落装备的图标 | weighted数组有内容时 | 点击显示tooltip |
| **材料图标** | 飞入动画素材 | guaranteed数组有内容时 | 无交互（飞入后消失） |
| **Tooltip面板** | 显示装备属性详情 | 点击装备图标时 | 点击关闭 |
| **继续按钮** | 玩家确认并关闭面板 | 动画完成后 | 点击关闭面板 |

---

### UI Layout Requirements

**掉落面板布局**:
- **层级**: ModalLayer (阻断其他输入)
- **锚点**: 屏幕中央，覆盖战斗区域
- **尺寸**: 自适应内容（装备图标数量决定宽度）

**装备图标排列**:
- 排列方式：按稀有度排序（EPIC → RARE → UNCOMMON → COMMON）
- 间距：80px (图标宽度60px + 边距20px)
- 最大一行：5个图标（超出换行）

**Tooltip定位**:
- 触发位置：跟随点击的装备图标
- 居中偏移：图标下方偏移30px
- 尺寸：200px宽 × 自适应高度

**继续按钮位置**:
- 锚点：面板底部中央
- 尺寸：满足最小触控目标 (44pt iOS / 48dp Android)
- 标签："继续"

---

### Touch Target Compliance

| UI元素 | 尺寸 | 平台要求 | 合规 |
|--------|------|----------|------|
| 装备图标 | 60×60px | 44pt/48dp | ✓ |
| 继续按钮 | 最小44×44pt | 44pt/48dp | ✓ |

---

### Data Binding Requirements

| UI元素 | 数据源 | 更新时机 |
|--------|--------|---------|
| 装备图标 | `weighted` 数组 | resolve_drop完成后 |
| 装备图标颜色 | `ItemDatabase.get_rarity_color(rarity)` | 图标创建时 |
| Tooltip内容 | `ItemDatabase.get_equipment(id)` | 点击图标时 |
| 材料飞入数量 | `guaranteed` 数组聚合 | resolve_drop完成后 |
| 继续按钮可用状态 | 动画完成状态 | Displaying → WaitingForInput |

---

### MVP UI Simplifications

**MVP简化**:
- 掉落面板：纯文本 + 图标组合，无复杂装饰
- Tooltip：纯文本显示属性，无动画
- 继续按钮：纯文本按钮，无图标

**后续版本扩展**:
- 掉落面板：添加背景装饰、边框光效
- Tooltip：添加弹出动画
- 继续按钮：添加图标、按压动画

---

### Debug UI (Dev-Only)

**开发调试UI** (不包含在正式版本):
- 强制掉落测试按钮：跳过战斗直接触发掉落面板
- 掉落结果log：显示resolve_drop返回的完整数据
- 强制稀有度按钮：指定掉落EPIC/LEGENDARY装备

## Acceptance Criteria

### AC1: Combat Victory Trigger

**场景**: 战斗胜利，战斗系统发出 `combat_complete` 信号。

**测试步骤**:
1. 启动战斗，击败敌人
2. 战斗系统发出 `combat_complete(floor_id, victory=true)`
3. 验证装备掉落系统接收信号并进入 Resolving 状态

**期望结果**: 掉落系统状态从 Idle → Resolving，调用 `resolve_drop()`。

---

### AC2: Drop Resolution Process

**场景**: 掉落系统调用掉落表系统解析掉落。

**测试步骤**:
1. 调用 `start_drop_resolution(floor_id)`
2. 验证调用 `DropTableSystem.resolve_drop(drop_table_id)`
3. 验证返回 `{ guaranteed: [...], weighted: [...] }`
4. 验证状态从 Resolving → Displaying

**期望结果**: 掉落解析完成，状态转换正确，数据结构符合预期。

---

### AC3: Drop Panel Display

**场景**: 掉落解析完成，掉落面板显示。

**测试步骤**:
1. resolve_drop返回有效掉落结果
2. 验证掉落面板节点创建
3. 验证ModalLayer激活（阻断其他输入）
4. 验证状态从 Resolving → Displaying

**期望结果**: 掉落面板可见，ModalLayer阻断生效，状态转换正确。

---

### AC4: Equipment Icon Display

**场景**: weighted数组包含装备掉落。

**测试步骤**:
1. weighted数组有内容（如 `[ { item_id: "equip_weapon_iron_blade", quantity: 1 } ]`）
2. 验证装备图标节点创建
3. 验证图标应用稀有度颜色（COMMON=棕色）
4. 验证图标位置在敌人击败位置附近（±30px偏移）
5. 验证弹出动画启动（duration=0.3s）

**期望结果**: 装备图标正确显示，稀有度颜色正确，动画启动。

---

### AC5: Material Animation

**场景**: guaranteed数组包含材料掉落。

**测试步骤**:
1. guaranteed数组有内容（如 `[ { item_id: "mat_enhance_stone_common", quantity: 2 } ]`）
2. 验证材料图标创建
3. 验证飞入动画启动（起始位置=敌人击败位置，目标=HUD计数器）
4. 验证动画时长在 0.3s–0.5s 范围内
5. 验证动画完成后材料图标移除

**期望结果**: 材料飞入动画正确播放，图标到达计数器位置后消失。

---

### AC6: Equipment Tooltip Display

**场景**: 玩家点击装备图标。

**测试步骤**:
1. 点击装备图标
2. 验证Tooltip面板显示
3. 验证Tooltip内容包含：name, attack, defense, rarity
4. 验证Tooltip位置在图标下方偏移30px

**期望结果**: Tooltip正确显示装备属性，位置正确。

---

### AC7: Tooltip Close

**场景**: 玩家点击Tooltip外部区域或再次点击图标。

**测试步骤**:
1. Tooltip显示中
2. 点击Tooltip外部区域或图标
3. 验证Tooltip隐藏/移除

**期望结果**: Tooltip正确关闭。

---

### AC8: Continue Button Display

**场景**: 掉落动画完成。

**测试步骤**:
1. 等待所有弹出动画完成
2. 验证"继续"按钮显示
3. 验证按钮位置在面板底部中央
4. 验证按钮尺寸满足最小触控目标（44×44pt）
5. 验证状态从 Displaying → WaitingForInput

**期望结果**: 继续按钮正确显示，尺寸合规，状态转换正确。

---

### AC9: Continue Button Click

**场景**: 玩家点击"继续"按钮。

**测试步骤**:
1. 点击"继续"按钮
2. 验证状态从 WaitingForInput → Closing
3. 验证物品添加到库存（调用存档系统）
4. 验证掉落面板移除
5. 验证ModalLayer解除阻断
6. 验证发出 `drop_panel_closed` 信号

**期望结果**: 物品添加成功，面板关闭，信号发出，状态返回Idle。

---

### AC10: Inventory Update - Material

**场景**: 材料添加到库存。

**测试步骤**:
1. guaranteed数组包含 Enhancement Stone × 3
2. 点击"继续"按钮
3. 验证调用存档系统 `add_material("mat_enhance_stone_common", 3)`
4. 验证存档中材料计数增加

**期望结果**: 材料正确添加到存档。

---

### AC11: Inventory Update - Equipment

**场景**: 装备添加到库存。

**测试步骤**:
1. weighted数组包含 Iron Blade × 1
2. 点击"继续"按钮
3. 验证调用存档系统 `add_equipment_to_inventory("equip_weapon_iron_blade")`
4. 验证存档中装备库存新增一个instance_id
5. 验证instance_id格式符合 `equipment_id_timestamp_suffix`

**期望结果**: 装备正确添加到存档，instance_id唯一。

---

### AC12: Combat Flow Return

**场景**: 掉落面板关闭后，战斗系统继续流程。

**测试步骤**:
1. 掉落面板关闭
2. 验证发出 `drop_panel_closed` 信号
3. 验证战斗系统接收信号并从 DropResolution → Complete
4. 验证战斗系统状态转换到 Idle

**期望结果**: 战斗系统正确接收信号并完成流程。

---

### AC13: Empty Equipment Drop

**场景**: weighted数组为空（无装备掉落）。

**测试步骤**:
1. resolve_drop返回 `{ guaranteed: [materials], weighted: [] }`
2. 验证掉落面板显示（仅材料飞入动画）
3. 验证无装备图标显示
4. 验证"继续"按钮直接显示

**期望结果**: 面板正常显示，无装备图标，流程正常完成。

---

### AC14: Invalid Drop Table ID

**场景**: drop_table_id无效或不存在。

**测试步骤**:
1. 调用 `resolve_drop("invalid_table_id")`
2. 验证返回空结果 `{ guaranteed: [], weighted: [] }`
3. 验证日志警告："Drop table invalid_table_id invalid"
4. 验证不掉落面板显示，直接通知战斗系统继续

**期望结果**: 无崩溃，流程继续，日志警告。

---

### AC15: Invalid Item ID in Drop Result

**场景**: drop result包含无效item_id。

**测试步骤**:
1. resolve_drop返回包含 `"invalid_item_id"`
2. 验证ItemDatabase.has_equipment/has_material返回false
3. 验证无效ID被移除，不显示
4. 验证日志警告："Invalid item invalid_item_id skipped"
5. 验证其他有效物品正常显示

**期望结果**: 无效物品跳过，其他物品正常，日志警告。

---

### AC16: State Transition Integrity

**场景**: 验证状态机转换完整性。

**测试步骤**:
1. 从Idle触发 combat_complete → Resolving
2. 从Resolving resolve完成 → Displaying
3. 从Displaying 动画完成 → WaitingForInput
4. 从WaitingForInput 点击继续 → Closing
5. 从Closing 面板移除 → Idle
6. 验证无跳过状态、无非法转换

**期望结果**: 所有状态转换按序发生，无非法跳转。

---

### AC17: Particle Effect Trigger

**场景**: RARE/EPIC/LEGENDARY装备弹出。

**测试步骤**:
1. weighted数组包含RARE装备
2. 验证弹出动画启动粒子效果（30粒子）
3. weighted数组包含EPIC装备
4. 验证弹出动画启动粒子效果（60粒子）
5. weighted数组包含LEGENDARY装备
6. 验证弹出动画启动粒子效果（100粒子）+ 屏幕震动（MVP后续版本）

**期望结果**: 粒子效果按稀有度正确触发，数量正确。

---

### AC18: Equipment Instance ID Uniqueness

**场景**: 同一装备多次掉落。

**测试步骤**:
1. 第一次掉落 Iron Blade → instance_id_1
2. 第二次掉落 Iron Blade → instance_id_2
3. 验证两个instance_id不同
4. 验证存档中两件装备独立存在
5. 验证两件装备可分别强化到不同等级

**期望结果**: 每次掉落生成唯一instance_id，装备独立管理。

---

### AC19: Modal Layer Blocking

**场景**: 掉落面板显示期间，其他输入被阻断。

**测试步骤**:
1. 掉落面板显示中（Displaying状态）
2. 尝试点击HUD按钮（如"跳过"）
3. 验证HUD按钮无响应（ModalLayer阻断）
4. 尝试点击战斗区域
5. 验证战斗区域无响应
6. 掉落面板关闭
7. 验证HUD和战斗区域恢复响应

**期望结果**: 掉落期间其他输入阻断，关闭后恢复。

## Open Questions

### OQ1: 战斗系统接口确认

**问题**: 战斗系统GDD中 `combat_complete` 信号的参数格式是否与本系统期望一致？

**当前假设**: `combat_complete(floor_id: int, victory: bool)`，包含 `floor_id` 用于查询掉落表。

**待确认**: 战斗系统GDD是否定义了相同的信号格式？是否需要传递 `enemy_ids` 或 `drop_table_ids` 数组（多敌人场景）？

**影响**: 若战斗系统信号格式不同，本系统需调整信号订阅逻辑。

---

### OQ2: 存档系统物品添加接口

**问题**: 存档系统GDD是否已定义 `add_material()` 和 `add_equipment_to_inventory()` 接口？

**当前假设**: 存档系统提供这两个方法，参数格式为 `(item_id: String, quantity: int)` 和 `(equipment_id: String)`。

**待确认**: 存档系统GDD（MVP系统#1）是否定义了这些接口？参数格式是否匹配？

**影响**: 若存档系统接口不同，本系统需调整调用方式。

---

### OQ3: 多敌人掉落时机

**问题**: 战斗中多个敌人击败时，掉落解析的触发时机？

**当前假设**: 所有敌人击败后，战斗进入Victory状态，统一触发掉落解析（合并所有敌人掉落）。

**待确认**: 战斗系统是否支持逐个敌人击败并逐个触发掉落？还是统一在战斗结束时触发？

**影响**: 若逐个触发，本系统需要多次解析掉落；若统一触发，本系统一次解析合并结果。当前设计假设统一触发。

---

### OQ4: 跳过战斗时的掉落处理

**问题**: 玩家跳过战斗（地牢推进系统skip功能），掉落如何处理？

**当前假设**: 跳过战斗后仍触发掉落解析（敌人已击败，掉落正常发放）。敌人击败位置fallback到屏幕中央。

**待确认**: 地牢推进系统GDD中"跳过战斗"是否仍触发 `combat_complete` 信号？跳过时敌人位置是否可用？

**影响**: 若跳过战斗不触发掉落，玩家会损失收益，不符合"稳定成长"支柱。当前设计假设跳过仍触发掉落。

---

### OQ5: 材料计数器UI归属

**问题**: HUD材料计数器的刷新由谁负责？

**当前假设**: 材料飞入动画完成后，本系统发出信号，材料系统或数值显示系统负责刷新计数器UI。

**待确认**: 材料系统GDD是否定义了计数器UI？数值显示系统GDD是否定义了材料计数刷新接口？

**影响**: 若计数器UI归属不明确，可能出现材料添加后UI不更新的问题。

---

### OQ6: 掉落面板超时关闭（Post-MVP）

**问题**: MVP阶段掉落面板无自动关闭，后续版本是否添加？

**当前决策**: MVP阶段掉落面板必须玩家点击"继续"关闭，无timeout。

**待确认**: 后续版本是否需要自动关闭？超时时间建议值？

**影响**: 若添加timeout，需设计超时后的默认行为（自动添加物品并关闭）。

---

### OQ7: LEGENDARY屏幕震动强度

**问题**: LEGENDARY装备掉落时的屏幕震动强度是否合适？

**当前假设**: `SCREEN_SHAKE_LEGENDARY = 5px` amplitude，轻微震动。

**待确认**: 震动反馈系统GDD是否定义了屏幕震动接口？5px是否在移动端舒适范围内？

**影响**: 若震动过强可能干扰视觉，过弱可能无感知。需原型测试验证。

---

### OQ8: 装备实例ID持久化策略

**问题**: 装备instance_id生成后如何持久化？

**当前假设**: instance_id存入 `SaveSystem.equipment_inventory` 数组和 `equipment_definitions` 字典。

**待确认**: 存档系统GDD是否定义了装备库存的数据结构？`equipment_definitions` 和 `enhancement_levels` 字典是否存在？

**影响**: 若存档结构不同，instance_id存储位置需调整。