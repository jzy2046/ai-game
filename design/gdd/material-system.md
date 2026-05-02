# 材料系统 (Material System)

> **Status**: Approved (Revised 2026-05-02 — gold cost formulas deferred to 强化公式系统)
> **Author**: user + agents
> **Last Updated**: 2026-05-02
> **Approved**: 2026-04-30 (Solo mode — no design-review)
> **Implements Pillar**: 稳定成长 + 多元成长

## Overview

材料系统是游戏的材料管理逻辑层，负责处理材料的获取、消耗、堆叠管理和数量验证。它从物品数据库读取材料定义（如最大堆叠数、稀有度），从存档系统读取玩家的材料持有数据，为依赖系统（装备强化系统）提供材料数量的查询接口和消耗验证服务。

从玩家视角，材料系统让"收集"成为可感知的成长体验。玩家在地牢中获得材料掉落、设置离线挂机积累材料、强化装备时消耗材料——每次获得材料都有视觉反馈（粒子、数字飞溅），每次强化消耗都有明确的费用显示。材料是装备强化必需的资源，支撑支柱"稳定成长"——玩家知道强化需要什么材料、知道自己有多少材料、知道材料从哪里获得。

MVP阶段材料系统管理 物品数据库定义的5种材料：
- **强化材料** (3种): Enhancement Stone, Crystal Essence, Celestial Shard — 用于装备强化消耗
- **货币** (2种): Gold, Gem — 用于强化费用支付和未来扩展

材料系统不存储材料定义数据（物品数据库职责），不存储材料持有状态（存档系统职责），只提供运行时的材料操作逻辑。

## Player Fantasy

材料系统支撑的核心玩家幻想是：

> **"每次收获都是宝藏，每份材料都是力量"** — 玩家在地牢结束时看到材料图标飞入背包，数字堆叠跳动，感受到"收获满满的喜悦"；玩家在强化装备时看到材料化为能量流入装备，数值暴涨，感受到"我在变强的掌控感"。

这支撑支柱**爽感反馈**：
- 材料获得不是冷冰冰的数字更新，而是有视觉爆发：图标弹出、粒子飞溅、数字bounce动画
- 稀有材料出现时有特别的庆祝反馈（例如Celestial Shard掉落时屏幕闪光）
- 数量里程碑（100x、1000x Gold）触发额外视觉奖励

这支撑支柱**稳定成长**：
- 材料用途明确、可预期：玩家知道Enhancement Stone用于强化，Gold用于费用支付
- 玩家可以随时查看材料数量，知道"我有多少"和"还需要多少"
- 强化界面显示材料需求的进度条，玩家可以预测"再刷几次就能强化了"

这支撑支柱**掌控节奏**：
- 离线挂机时玩家可以设置目标（如"积累100个Enhancement Stone"），回来时看到进度达成
- 玩家可以选择优先刷哪种材料（通过选择地牢层级或挂机任务）

**参考**: 暗黑破坏神 — 材料掉落时的图标弹出和声音反馈；梦幻西游手游 — 材料收集进度明确，玩家知道目标在哪里。

## Detailed Design

### Core Rules

#### Rule 1: Material Quantity Storage — Runtime Cache from Save

MaterialSystem maintains an in-memory cache of material quantities, populated from SaveSystem on load and updated on every add/remove operation.

**Cache structure**: `Dictionary[String, int]` mapping material_id → current_quantity
- Cache populated by `SaveSystem.get_materials()` on game load
- Cache is **not** the authoritative store — SaveSystem owns persistence
- After each successful add/remove, MaterialSystem calls `SaveSystem.update_material(material_id, quantity)` to persist

---

#### Rule 2: Add Material — Stack-Limited with Overflow Handling

Adding materials MUST respect max_stack limit from ItemDatabase.

**Add Sequence**:
1. Validate material_id exists in ItemDatabase (`get_material(id)`)
2. If invalid: emit `material_add_failed(INVALID_MATERIAL_ID)`, return false
3. Get max_stack from ItemDatabase definition
4. Get category from ItemDatabase definition
5. If category == CURRENCY: delegate to CurrencySystem (Rule 9)
6. Calculate new_quantity = current_quantity + amount
7. If max_stack == 0 (unlimited): set new_quantity directly
8. If new_quantity > max_stack: apply overflow_policy (Rule 7)
9. Update cache and call `SaveSystem.update_material()`
10. Emit `material_added(material_id, added_amount, new_quantity)`
11. Check milestone triggers (Rule 8)

---

#### Rule 3: Remove Material — Quantity Validation Required

Removing materials MUST validate sufficient quantity before operation. Cannot remove more than owned.

**Remove Sequence**:
1. Validate material_id exists in ItemDatabase
2. If invalid: emit `material_remove_failed(INVALID_MATERIAL_ID)`, return false
3. Get category from ItemDatabase
4. If category == CURRENCY: delegate to CurrencySystem (Rule 9)
5. Get current_quantity from cache
6. If current_quantity < amount:
   - Emit `material_remove_failed(INSUFFICIENT_QUANTITY)`
   - Return false (no partial removal)
7. new_quantity = current_quantity - amount
8. Update cache and call `SaveSystem.update_material()`
9. Emit `material_removed(material_id, removed_amount, new_quantity)`

---

#### Rule 4: Check Quantity — Non-Negative Return

Quantity queries MUST return a non-negative integer, defaulting to 0 for unknown materials.

**Behavior**:
- If material_id in cache: return cached quantity
- If material_id not in cache: return 0 (never returns null)
- This allows UI to display "0" for materials player has never obtained

---

#### Rule 5: Can Remove — Boolean Validation for Pre-Check

Provide a boolean check method for systems that need to verify before attempting removal.

```gdscript
func can_remove(material_id: String, amount: int) -> bool
```

**Behavior**:
- Returns true if: material_id valid AND current_quantity >= amount
- Returns false if: material_id invalid OR current_quantity < amount
- Does NOT emit signals or modify state (pure check)

---

#### Rule 6: Bulk Check — Multi-Material Validation

Provide a bulk validation method for operations requiring multiple material types.

```gdscript
func can_remove_bulk(requirements: Dictionary) -> bool  # {material_id: amount, ...}
```

**Behavior**:
- Returns true ONLY if ALL materials satisfy quantity requirements
- Returns false if ANY material fails

---

#### Rule 7: Overflow Policy — CLAMP (Cap at Max Stack)

When add operation would exceed max_stack, apply overflow_policy:

| Policy | Behavior | MVP Use |
|--------|----------|---------|
| `CLAMP` | Cap at max_stack, discard excess | Default for enhancement materials |
| `DISCARD` | Refuse entire operation, emit overflow signal | Not used in MVP |

**MVP Default**: `CLAMP` for all enhancement materials.

**Overflow Signal**: `material_overflow(material_id, overflow_amount)` emitted when overflow occurs.

---

#### Rule 8: Milestone Triggers — Optional Visual Feedback

When material quantity crosses milestone thresholds, emit milestone signal for Visual Feedback System.

**Milestone Thresholds**:
- First acquisition: quantity changes from 0 to >0
- 100, 500, 1000 for COMMON materials
- 50, 100 for RARE materials
- 10, 25, 50 for EPIC materials

**Signal**: `material_milestone(material_id, milestone_type, quantity)`

---

#### Rule 9: Currency vs Material Routing — Delegate to CurrencySystem

MaterialSystem routes CURRENCY category materials (Gold, Gem) to CurrencySystem, does not manage currencies directly.

**Routing Logic**:
```gdscript
func add_material(material_id: String, amount: int) -> bool:
    var def = ItemDatabase.get_material(material_id)
    if def.category == "CURRENCY":
        return CurrencySystem.add_currency(material_id, amount)
    # ... enhancement material logic
```

**Why**: Currencies have different display location (HUD), different overflow behavior (Gold infinite), and may have different sourcing/sink patterns in future iterations.

---

### States and Transitions

MaterialSystem has **no complex state transitions**. It operates in a simple runtime model:

| State | Description | Available Operations |
|-------|-------------|---------------------|
| **Not Ready** | SaveSystem load not complete | None (should not happen) |
| **Ready** | Cache loaded from SaveSystem | All operations available |

Material instances have **no locked/unlocked states**:
- All materials are "unlocked" by default
- MVP does not include material discovery/unlock mechanics
- Quantity is the only per-material state: `int >= 0`

---

### Interactions with Other Systems

| System | Direction | Interface | Data Flow |
|--------|-----------|-----------|-----------|
| **存档系统** (Upstream) | Bidirectional | `get_materials()`, `update_material()` | MaterialSystem populates cache from SaveSystem; updates SaveSystem after each operation |
| **物品数据库** (Upstream) | Inbound | `get_material(id)` | MaterialSystem queries for max_stack, category, rarity; does NOT modify |
| **强化公式系统** (Upstream) | — | — | 强化公式系统 defines gold cost formulas; Material System does NOT calculate gold costs |
| **货币系统** (Horizontal) | Outbound | `add_currency()`, `remove_currency()` | MaterialSystem routes CURRENCY category operations |
| **装备强化系统** (Downstream) | Inbound | `get_quantity()`, `can_remove_bulk()`, `remove_material()` | Enhancement System checks and consumes materials; uses 强化公式系统 for gold costs |
| **掉落表系统** (Downstream) | Inbound | `add_material()` | Drop System awards materials after combat |
| **视觉反馈系统** (Downstream) | Outbound | Signals | Visual Feedback listens to material_added, material_milestone for effects |

## Formulas

### Formula 1: Material Drop Rate

The material drop rate formula determines the probability of material drops per enemy kill.

`material_drop_chance = BASE_DROP_RATE * floor_number * RARITY_MULTIPLIER`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_DROP_RATE | — | float | 0.10 (constant) | Base drop rate per enemy |
| floor_number | — | int | 1–5+ (MVP) | Current dungeon floor |
| RARITY_MULTIPLIER | — | float | 0.1–1.0 (constant) | Rarity-based multiplier: COMMON=1.0, RARE=0.3, EPIC=0.1 |

**Output Range:** 0.10 (floor 1, COMMON) to 0.30+ (floor 5+, COMMON). Capped at 1.0 (100%).

**Example:**
Floor 3, Enhancement Stone (COMMON):
```
drop_chance = 0.10 * 3 * 1.0 = 0.30 (30% per enemy)
```

Floor 5, Crystal Essence (RARE):
```
drop_chance = 0.10 * 5 * 0.3 = 0.15 (15% per enemy)
```

---

### Formula 2: Enhancement Gold Cost — Delegated to 强化公式系统

**Note**: Enhancement gold cost calculation is now owned by **强化公式系统** (Enhancement Formula System). Material System does not calculate gold costs; it only provides material quantity data.

**Reference**: For gold cost formulas and tuning knobs, see:
- `design/gdd/enhancement-formula-system.md` — Gold Cost Formula (Formula 1)
- `BASE_GOLD_COST` is defined in `强化公式系统` with value **100** (not 50)

**Material System's role**: Provide `get_quantity(mat_enhance_stone_common)` and material consumption services for 装备强化系统.

---

### Formula 3: Enhancement Stone Cost

The enhancement stone cost formula calculates the Enhancement Stone required for each level.

`stone_cost = floor(BASE_STONE_COST + (enhancement_level * LEVEL_STONE_INCREMENT))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_STONE_COST | — | int | 2 (constant) | Stones at +1 |
| enhancement_level | — | int | 1–10 | Target enhancement level |
| LEVEL_STONE_INCREMENT | — | int | 2 (constant) | Extra stones per level |

**Output Range:** 4 (at +1) to 22 (at +10). Stone cost does NOT scale by rarity.

**Example:**
+3 enhancement:
```
stone_cost = floor(2 + (3 * 2)) = floor(8) = 8
```

+10 enhancement:
```
stone_cost = floor(2 + (10 * 2)) = floor(22) = 22
```

---

### Formula 4: Crystal Essence Cost (Level 5+)

The crystal essence cost formula applies only for enhancement levels 5 and above.

`crystal_cost = 0 if enhancement_level < 5 else floor(BASE_CRYSTAL_COST + (enhancement_level - 5))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_CRYSTAL_COST | — | int | 1 (constant) | Crystals at +5 |
| enhancement_level | — | int | 1–10 | Target enhancement level |

**Output Range:** 0 (levels 1–4), 1 (at +5) to 6 (at +10).

**Example:**
+5 enhancement:
```
crystal_cost = floor(1 + (5 - 5)) = floor(1) = 1
```

+8 enhancement:
```
crystal_cost = floor(1 + (8 - 5)) = floor(4) = 4
```

---

### Formula 5: Celestial Shard Cost (Level 8+)

The celestial shard cost formula applies only for enhancement levels 8 and above.

`shard_cost = 0 if enhancement_level < 8 else floor(BASE_SHARD_COST + (enhancement_level - 8))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_SHARD_COST | — | int | 1 (constant) | Shards at +8 |
| enhancement_level | — | int | 1–10 | Target enhancement level |

**Output Range:** 0 (levels 1–7), 1 (at +8) to 3 (at +10).

**Example:**
+8 enhancement:
```
shard_cost = floor(1 + (8 - 8)) = floor(1) = 1
```

+10 enhancement:
```
shard_cost = floor(1 + (10 - 8)) = floor(3) = 3
```

## Edge Cases

- **If add_material is called with amount <= 0**: Operation fails immediately with INVALID_AMOUNT error code. No state change. Negative amounts cannot become accidental adds.

- **If remove_material is called with amount <= 0**: Operation fails immediately with INVALID_AMOUNT error code. No state change.

- **If material_id does not exist in ItemDatabase**: Operation fails with INVALID_MATERIAL_ID error code. MaterialSystem queries ItemDatabase first and rejects unknown materials.

- **If current_quantity >= max_stack and add_material is called**: CLAMP policy applies. New quantity capped at max_stack, excess discarded. `material_overflow` signal emitted with overflow_amount. No error code — operation succeeds but with partial result.

- **If max_stack == 0 (Gold/infinite)**: Overflow never occurs. Quantity unlimited. No overflow signal. No cap applied.

- **If remove_material is called with amount > current_quantity**: Operation fails with INSUFFICIENT_QUANTITY error code. No state change. No partial removal.

- **If can_remove_bulk is called with empty requirements dict**: Returns true (trivial case). All zero requirements satisfied.

- **If can_remove_bulk has one material insufficient**: Returns false. No indication of which material failed (Enhancement System should query individually to find deficit).

- **If add_material is called for CURRENCY category material**: MaterialSystem delegates to CurrencySystem.add_currency(). MaterialSystem does NOT update its own cache or emit signals for currencies. CurrencySystem handles the operation.

- **If SaveSystem.update_material() fails (persistence error)**: MaterialSystem logs error, keeps in-memory state, emits material_add_failed(SAVE_PERSISTENCE_FAILED). User can continue playing. Periodic save will retry. Data persists eventually.

- **If MaterialSystem initialized before SaveSystem load completes**: MaterialSystem is in "Not Ready" state. All operations return false with error code NOT_READY. SaveSystem emits load_complete signal to trigger MaterialSystem initialization.

- **If milestone threshold crossed in single operation (e.g., add 200 stones going from 50 to 250)**: All crossed milestones emit. For COMMON materials: 100 milestone emitted, then subsequent checks continue. Only one signal per milestone type per crossing.

## Dependencies

### Upstream Dependencies (Required for MaterialSystem to function)

| System | Dependency Type | Interface | Critical? |
|--------|----------------|-----------|-----------|
| **存档系统** | Hard | `get_materials()`, `update_material()` | Yes — MaterialSystem cannot operate without persistence |
| **物品数据库** | Hard | `get_material(id)` | Yes — MaterialSystem cannot validate materials without definitions |

### Horizontal Dependencies (Parallel systems, same layer)

| System | Dependency Type | Interface | Critical? |
|--------|----------------|-----------|-----------|
| **货币系统** | Soft (routing) | `add_currency()`, `remove_currency()` | Partial — MaterialSystem can operate without CurrencySystem but cannot route currency operations |

### Downstream Dependencies (Systems that depend on MaterialSystem)

| System | Dependency Type | Interface | Status |
|--------|----------------|-----------|--------|
| **装备强化系统** | Hard | `get_quantity()`, `can_remove_bulk()`, `remove_material()` | Not yet designed |
| **掉落表系统** | Hard | `add_material()` | Not yet designed |
| **视觉反馈系统** | Soft | Signals: `material_added`, `material_milestone` | Not yet designed |

### Dependency Notes

- **存档系统**: MaterialSystem's cache is populated from SaveSystem on load. Every successful add/remove triggers `update_material()` call to SaveSystem. This is bidirectional but SaveSystem is the authoritative owner of material instance data.

- **物品数据库**: MaterialSystem queries ItemDatabase for material definitions (max_stack, category, rarity) on every operation. This is read-only — MaterialSystem does NOT modify ItemDatabase.

- **货币系统**: MaterialSystem routes CURRENCY category operations (Gold, Gem) to CurrencySystem. This delegation means MaterialSystem's cache and signals do NOT apply to currencies. CurrencySystem is the authoritative handler for currencies.

- **装备强化系统** (future): Will call `can_remove_bulk()` before enhancement attempt, then call `remove_material()` for each material type. MaterialSystem provides atomic validation and consumption.

- **掉落表系统** (future): Will call `add_material()` when materials are awarded from combat or offline rewards. Drop System does NOT need to check max_stack — MaterialSystem handles overflow internally.

## Tuning Knobs

### Drop Rate Tuning

| Knob | Current Value | Safe Range | Effect of Change |
|------|---------------|------------|------------------|
| `BASE_DROP_RATE` | 0.10 | 0.05–0.30 | Higher = more materials per enemy. Too high = overflow spam, too low = grind frustration. |
| `RARITY_MULTIPLIER_COMMON` | 1.0 | 0.5–1.5 | Higher = more common materials. Should remain 1.0 as baseline. |
| `RARITY_MULTIPLIER_RARE` | 0.3 | 0.1–0.5 | Higher = easier to obtain rare materials. Too high = rare loses value. |
| `RARITY_MULTIPLIER_EPIC` | 0.1 | 0.05–0.2 | Higher = easier epic materials. Celestial Shard already 100% on floor 5 boss. |

### Enhancement Cost Tuning

**Note**: Gold cost tuning knobs (BASE_GOLD_COST) are now defined in **强化公式系统**. See `design/gdd/enhancement-formula-system.md` Tuning Knobs section.

| Knob | Current Value | Safe Range | Effect of Change |
|------|---------------|------------|------------------|
| `LEVEL_STONE_INCREMENT` | 2 | 1–3 | Higher = steep stone cost curve. Lower = flatter progression. |
| `BASE_STONE_COST` | 2 | 1–5 | Starting stone requirement. |
| `BASE_CRYSTAL_COST` | 1 | 1–2 | Crystal Essence entry cost at +5. |
| `BASE_SHARD_COST` | 1 | 1–2 | Celestial Shard entry cost at +8. |

### Stack Limit Tuning (Defined in ItemDatabase, referenced here)

| Knob | Current Value | Safe Range | Effect of Change |
|------|---------------|------------|------------------|
| `MAX_STACK_ENHANCEMENT_STONE` | 999 | 500–2000 | Lower = overflow pressure. Higher = hoarding allowed. |
| `MAX_STACK_CRYSTAL_ESSENCE` | 99 | 50–200 | Lower = overflow pressure for rare materials. |
| `MAX_STACK_CELESTIAL_SHARD` | 50 | 25–100 | Epic material capacity. |
| `MAX_STACK_GEM` | 9999 | 1000–99999 | Gem capacity. Gold is infinite (0). |

### Milestone Threshold Tuning

| Knob | Current Value | Safe Range | Effect of Change |
|------|---------------|------------|------------------|
| `MILESTONE_COMMON` | [100, 500, 1000] | Adjust thresholds | Higher = fewer celebrations. Lower = more frequent celebrations. |
| `MILESTONE_RARE` | [50, 100] | Adjust thresholds | Rare material milestones. |
| `MILESTONE_EPIC` | [10, 25, 50] | Adjust thresholds | Epic material milestones. |

### Overflow Policy Tuning

| Knob | Current Value | Options | Effect of Change |
|------|---------------|---------|------------------|
| `OVERFLOW_POLICY` | CLAMP | CLAMP, DISCARD | CLAMP = cap and discard excess. DISCARD = refuse entire operation (strict). |

### Interaction Notes

- **Gold cost tuning** is handled by 强化公式系统; Material System only provides material quantities.
- **Changing MAX_STACK** values affects overflow frequency. Lower values create pressure to use materials.
- **Drop rate knobs** interact with floor progression — higher floors naturally increase drops via floor_number multiplier.
- **Cost knobs** are linear per level. Non-linear scaling (future) would require formula changes, not just knob tuning.

## Visual/Audio Requirements

### Material Acquisition Feedback

When materials are added to inventory:

| Event | Visual Effect | Audio Effect |
|-------|---------------|--------------|
| **Common material added** | Icon flies from source to inventory slot, number bounce animation | Soft "pop" sound |
| **Rare material added** | Icon flies with golden trail, screen edge glow, larger number bounce | Celebratory chime |
| **Epic material added** | Icon flies with purple burst particles, screen flash, dramatic bounce | Epic drop sound (louder, distinctive) |
| **Currency added** | HUD number flies up and bounces, no icon animation | Coin "ka-ching" sound |

### Milestone Celebrations

When material quantity crosses milestone threshold:

| Milestone | Visual Effect | Audio Effect |
|-----------|---------------|--------------|
| **First acquisition** | Icon pulse in inventory, brief particle burst | First-time acquire sound |
| **100 COMMON** | Screen pulse, particle burst centered on inventory | Achievement ping |
| **1000 COMMON** | Larger screen pulse, golden particles, text popup "1000 Stones!" | Celebration burst |
| **50 RARE** | Purple glow, particle burst | Rare milestone sound |
| **50 EPIC** | Screen flash, epic particle burst, text popup | Epic milestone sound |

### Overflow Warning

When material addition exceeds max_stack:

| Event | Visual Effect | Audio Effect |
|-------|---------------|--------------|
| **Overflow** | Warning toast appears: "Enhancement Stone full (999)", icon shake | Warning "beep" sound |

## UI Requirements

### Material Display Locations

| Material Type | Display Location | Format |
|---------------|------------------|--------|
| **Gold** | HUD top bar | Number with coin icon, always visible |
| **Gem** | HUD top bar | Number with gem icon, always visible |
| **Enhancement materials** | Inventory screen | Grid layout with icon, quantity number, rarity color border |

### Enhancement Cost Preview UI

When player opens enhancement screen:

| Element | Display |
|---------|---------|
| **Material requirements** | List of materials with: icon, required amount, current amount (color: green if sufficient, red if deficit) |
| **"Need X more" indicator** | If deficit: red text "Need 5 more Enhancement Stones" |
| **Enhance button** | Disabled (grey) if any material insufficient; enabled (gold glow) if all sufficient |

### Material Acquisition Popup

When materials are awarded (combat end, offline reward):

| Element | Display |
|---------|---------|
| **Reward popup** | Modal showing material icons and quantities, each with fly-in animation |
| **Total summary** | "Materials acquired: 15 Gold, 3 Enhancement Stones" |

## Acceptance Criteria

### Core Rules

**AC-R2-01: Add Valid Material**
**GIVEN** ItemDatabase defines `mat_enhance_stone_common` with `max_stack: 999` and current quantity is 100, **WHEN** `add_material("mat_enhance_stone_common", 50)` is called, **THEN** `get_quantity("mat_enhance_stone_common")` returns 150 and `material_added` signal emits.

**AC-R2-02: Add Invalid Material ID**
**GIVEN** ItemDatabase does not contain `fake_material`, **WHEN** `add_material("fake_material", 10)` is called, **THEN** `material_add_failed` signal emits with INVALID_MATERIAL_ID and no state changes.

**AC-R3-01: Remove Valid Amount**
**GIVEN** `mat_enhance_stone_common` quantity is 100, **WHEN** `remove_material("mat_enhance_stone_common", 30)` is called, **THEN** `get_quantity("mat_enhance_stone_common")` returns 70 and `material_removed` signal emits.

**AC-R3-02: Remove Insufficient Quantity**
**GIVEN** `mat_enhance_stone_common` quantity is 10, **WHEN** `remove_material("mat_enhance_stone_common", 50)` is called, **THEN** `material_remove_failed` signal emits with INSUFFICIENT_QUANTITY and quantity remains 10.

**AC-R4-01: Check Unknown Material Returns Zero**
**GIVEN** `nonexistent_material` has never been added, **WHEN** `get_quantity("nonexistent_material")` is called, **THEN** returns 0 (never null, never negative).

**AC-R5-01: Can Remove Returns True**
**GIVEN** `mat_enhance_stone_common` quantity is 100, **WHEN** `can_remove("mat_enhance_stone_common", 50)` is called, **THEN** returns true with no signals emitted.

**AC-R5-02: Can Remove Returns False**
**GIVEN** `mat_enhance_stone_common` quantity is 10, **WHEN** `can_remove("mat_enhance_stone_common", 50)` is called, **THEN** returns false with no state changes.

**AC-R6-01: Bulk Check All Sufficient**
**GIVEN** `mat_enhance_stone_common: 100`, `mat_enhance_crystal_essence: 10`, **WHEN** `can_remove_bulk({"mat_enhance_stone_common": 50, "mat_enhance_crystal_essence": 5})` is called, **THEN** returns true.

**AC-R6-02: Bulk Check One Insufficient**
**GIVEN** `mat_enhance_stone_common: 100`, `mat_enhance_crystal_essence: 2`, **WHEN** `can_remove_bulk({"mat_enhance_stone_common": 50, "mat_enhance_crystal_essence": 10})` is called, **THEN** returns false.

**AC-R7-01: Overflow Clamps to Max Stack**
**GIVEN** `mat_enhance_stone_common` has `max_stack: 999` and current quantity is 990, **WHEN** `add_material("mat_enhance_stone_common", 20)` is called, **THEN** `get_quantity("mat_enhance_stone_common")` returns 999 and `material_overflow` signal emits with overflow_amount = 11.

**AC-R8-01: First Acquisition Milestone**
**GIVEN** `mat_enhance_crystal_essence` quantity is 0, **WHEN** `add_material("mat_enhance_crystal_essence", 5)` is called, **THEN** `material_milestone` signal emits with FIRST_ACQUISITION.

**AC-R9-01: Currency Routes to CurrencySystem**
**GIVEN** `mat_currency_gold` is category CURRENCY, **WHEN** `add_material("mat_currency_gold", 500)` is called, **THEN** CurrencySystem.add_currency is invoked and MaterialSystem cache is NOT updated.

### Formulas

**AC-F1-01: Drop Rate Floor 3 COMMON**
**GIVEN** BASE_DROP_RATE = 0.10, floor_number = 3, RARITY_MULTIPLIER_COMMON = 1.0, **WHEN** drop rate is calculated, **THEN** result = 0.30 (30%).

**AC-F2: Gold Cost — See 强化公式系统**
**Note**: Gold cost acceptance criteria are now defined in `design/gdd/enhancement-formula-system.md` (AC-F1, AC-F3). Material System does not calculate gold costs.

**AC-F3-01: Stone Cost +3**
**GIVEN** BASE_STONE_COST = 2, enhancement_level = 3, LEVEL_STONE_INCREMENT = 2, **WHEN** stone cost is calculated, **THEN** result = 8.

**AC-F4-01: Crystal Cost +5**
**GIVEN** BASE_CRYSTAL_COST = 1, enhancement_level = 5, **WHEN** crystal cost is calculated, **THEN** result = 1.

**AC-F5-01: Shard Cost +8**
**GIVEN** BASE_SHARD_COST = 1, enhancement_level = 8, **WHEN** shard cost is calculated, **THEN** result = 1.

### Edge Cases

**AC-EC-01: Zero Amount Fails**
**GIVEN** any valid material, **WHEN** `add_material(id, 0)` is called, **THEN** operation fails with INVALID_AMOUNT and no state changes.

**AC-EC-02: Persistence Failure Logged**
**GIVEN** SaveSystem.update_material returns failure, **WHEN** `add_material` succeeds in cache, **THEN** material_add_failed emits with SAVE_PERSISTENCE_FAILED and in-memory state is preserved.

### Integration

**AC-INT-01: SaveSystem Sync**
**GIVEN** MaterialSystem cache updates, **WHEN** add/remove succeeds, **THEN** SaveSystem.update_material is called exactly once.

**AC-INT-02: ItemDatabase Query for Stack**
**GIVEN** ItemDatabase defines max_stack, **WHEN** add approaches limit, **THEN** MaterialSystem queries ItemDatabase and applies CLAMP.

## Open Questions

| Question | Owner | Target Resolution |
|----------|-------|-------------------|
| **Should overflow discard trigger a confirmation dialog instead of silent discard?** | Game Designer | Before Drop System design |
| **Should milestone celebrations scale with material rarity? (Epic milestone more dramatic than Common)** | Art Director | Before Visual Feedback System design |
| **Should offline rewards cap material acquisition at max_stack, or auto-consume for enhancement?** | Systems Designer | Before Offline Reward System design |
| **Should material cost preview show deficit for ALL materials or only the first insufficient?** | UX Designer | Before UI layout system design |