# 货币系统 (Currency System)

> **Status**: Approved
> **Author**: user + agents
> **Last Updated**: 2026-05-01
> **Approved**: 2026-05-01 (Solo mode — no design-review)
> **Implements Pillar**: 稳定成长 + 多元成长

## Overview

货币系统是游戏的货币管理逻辑层，负责处理金币和宝石的获取、消耗和数量管理。它从存档系统读取玩家的货币持有数据，为依赖系统（装备强化系统、材料系统路由、离线收益系统）提供货币数量的查询接口和操作服务。

从玩家视角，货币系统让"财富积累"成为可感知的成长体验。玩家在HUD顶部随时看到金币数量，每次击败敌人获得金币时数字跳动上升，每次强化装备花费金币时数字减少但有清晰的费用显示。金币是游戏的主要货币，用于装备强化费用支付；宝石是高级货币（MVP暂无用途，预留未来扩展）。货币系统支撑支柱"稳定成长"——玩家知道自己有多少财富，知道强化需要花费多少，知道金币从哪里获得。

MVP阶段货币系统管理2种货币：
- **Gold (金币)**: 主要货币，无限堆叠，用于装备强化费用
- **Gem (宝石)**: 高级货币，堆叠上限9999，MVP暂无消耗用途，预留未来扩展

货币系统不存储货币定义数据（物品数据库职责），不存储货币持有状态（存档系统职责），只提供运行时的货币操作逻辑，并接收材料系统的路由委托。

## Player Fantasy

货币系统支撑的核心玩家幻想是：

> **"金币如宝库般流入，如燃料般流出"** — 每次击败敌人，金币爆发飞向计数器，数字跳动上升，玩家感受"财富积累的满足感"；每次强化装备，金币化为能量流出，数值暴涨，玩家感受"财富转化为力量的掌控感"。

这支撑支柱**爽感反馈**：
- 金币获得不是冷冰冰的数字更新，而是有视觉爆发：金币图标从敌人处飞出，数字bounce动画上升
- HUD金币显示实时更新，每次变化都有微小动画反馈
- 大量金币获得（如离线收益）触发特殊庆祝（金光闪烁、数字飞跃）

这支撑支柱**稳定成长**：
- 金币数量永远可见（HUD顶部常驻显示），玩家知道"我有多少"
- 强化费用明确显示，玩家可以预测"再刷几次就够了"
- 离线挂机期间金币自动积累，回来时看到明确的收益数字

这支撑支柱**掌控节奏**：
- 玩家可以选择优先积累金币（选择更低层级快速刷怪）还是优先强化装备（花费金币提升数值）
- 离线挂机设置时可以预期回来时的金币数量

**参考**: 暗黑破坏神 — 每次击杀后金币爆发飞出；梦幻西游手游 — 离线收益回来时的金币积累展示。

## Detailed Design

### Core Rules

#### Rule 1: Currency Registry — Definition from ItemDatabase

CurrencySystem maintains currency definitions loaded from ItemDatabase (CURRENCY category). Each currency has:
- `currency_id`: String (e.g., `mat_currency_gold`, `mat_currency_gem`)
- `display_name`: String
- `max_stack`: int (0 = infinite, >0 = cap)
- `icon_path`: String
- `category`: CURRENCY (fixed)

---

#### Rule 2: Balance Storage — Runtime Cache from SaveSystem

CurrencySystem maintains an in-memory cache of currency balances, populated from SaveSystem on load.

**Cache structure**: `Dictionary[String, int]` mapping currency_id → balance
- Cache populated by `SaveSystem.get_currencies()` on game load
- Cache is NOT authoritative — SaveSystem owns persistence
- After each successful add/remove, call `SaveSystem.update_currency()` to persist

---

#### Rule 3: Add Currency — Stack-Limited for Gem, Unlimited for Gold

**Add Sequence**:
1. Validate currency_id exists in ItemDatabase (category == CURRENCY)
2. If invalid: emit `currency_add_failed(UNKNOWN_CURRENCY)`, return false
3. Validate amount > 0 (zero/negative rejected)
4. Get max_stack from ItemDatabase
5. If max_stack == 0 (Gold/infinite): new_balance = current + amount (no cap)
6. If max_stack > 0 (Gem): new_balance = min(current + amount, max_stack), calculate overflow
7. Update cache and call `SaveSystem.update_currency()`
8. Emit `currency_added(currency_id, amount, new_balance)`
9. If overflow occurred: emit `currency_overflow(currency_id, overflow_amount)`
10. Trigger SaveSystem Critical save (currency change is Critical trigger)

---

#### Rule 4: Remove Currency — Quantity Validation Required

**Remove Sequence**:
1. Validate currency_id exists in ItemDatabase
2. If invalid: emit `currency_remove_failed(UNKNOWN_CURRENCY)`, return false
3. Validate amount > 0
4. Get current_balance from cache
5. If current_balance < amount:
   - Emit `currency_remove_failed(INSUFFICIENT_BALANCE)`
   - Return false (no partial deduction)
6. new_balance = current_balance - amount
7. Update cache and call `SaveSystem.update_currency()`
8. Emit `currency_removed(currency_id, amount, new_balance)`
9. Trigger SaveSystem Critical save

---

#### Rule 5: Check Balance — Non-Negative Return

`get_balance(currency_id)` returns current balance, 0 if currency_id not initialized. Never returns null, never negative.

---

#### Rule 6: Can Afford — Boolean Pre-Check

`can_afford(currency_id, amount)` returns `current_balance >= amount`. Pure query, no side effects.

---

#### Rule 7: Overflow Handling — Cap and Discard

When add exceeds max_stack (Gem capped at 9999):
- Balance clamped to max_stack
- Excess discarded (lost, not converted)
- `currency_overflow` signal emitted with discarded amount
- Warning logged for debugging

---

#### Rule 8: Gem Dormant in MVP — Obtainable but Not Spendable

**MVP Gem behavior**:
| Aspect | MVP Behavior |
|--------|--------------|
| Obtainable | No source in MVP (no drops, no rewards) |
| Spendable | No sink in MVP (check fails, UI shows "Coming Soon") |
| Starting amount | 0 |
| Display | HUD with Gem icon, count "0", grayed out or tooltip |

**Rationale**: Gem economy deferred to future iteration. Prevents player confusion about unusable currency. Data persistence enabled for future expansion.

---

#### Rule 9: MaterialSystem Routing — Receive Delegated Operations

When MaterialSystem detects CURRENCY category:
- MaterialSystem calls `CurrencySystem.add_currency(id, amount)` or `CurrencySystem.remove_currency(id, amount)`
- MaterialSystem does NOT update its own cache for currencies
- CurrencySystem handles all logic, emits signals, returns result to MaterialSystem

---

### States and Transitions

CurrencySystem has **no gameplay states** — currencies are always available.

| State | Description | Operations Available |
|-------|-------------|---------------------|
| **Not Initialized** | SaveSystem load not complete | None (error returned) |
| **Initialized** | Cache loaded from SaveSystem | All operations available |

---

### Interactions with Other Systems

| System | Direction | Interface | Data Flow |
|--------|-----------|-----------|-----------|
| **存档系统** (Upstream) | Bidirectional | `get_currencies()`, `update_currency()` | CurrencySystem loads on init; updates after each operation; Critical trigger for save |
| **物品数据库** (Upstream) | Inbound | `get_material(id)` | CurrencySystem queries for max_stack, category |
| **材料系统** (Horizontal) | Inbound | `add_currency()`, `remove_currency()` | MaterialSystem routes CURRENCY operations; CurrencySystem is authoritative |
| **装备强化系统** (Downstream) | Inbound | `can_afford()`, `remove_currency()` | Enhancement System checks gold availability before enhancement |
| **掉落表系统** (Downstream) | Inbound | `add_currency()` | Drop System awards gold after combat |
| **离线收益系统** (Downstream) | Inbound | `add_currency()` | Offline Rewards System awards accumulated gold |
| **数值显示系统** (Downstream) | Outbound | Signals | HUD subscribes to `currency_changed` for UI updates |

## Formulas

### Formula 1: Gold Drop from Enemy Kill

The gold drop formula calculates Gold awarded per enemy kill.

`gold_drop = floor(BASE_GOLD_PER_ENEMY * floor_number * luck_multiplier)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_GOLD_PER_ENEMY | — | int | 5 (constant) | Base gold at floor 1 |
| floor_number | — | int | 1–5+ (MVP) | Current dungeon floor |
| luck_multiplier | — | float | 1.0–1.5 | Luck stat bonus (future) |

**Output Range:** 5 (floor 1) to 30+ (floor 5+). Linear scaling per floor.

**Example:**
Floor 3, no luck bonus:
```
gold_drop = floor(5 * 3 * 1.0) = 15
```

Floor 5, 20% luck bonus:
```
gold_drop = floor(5 * 5 * 1.2) = 30
```

---

### Formula 2: Gold Drop from Boss Kill

Boss kills award 10x base gold.

`boss_gold_drop = floor(BASE_GOLD_PER_ENEMY * floor_number * 10)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| BASE_GOLD_PER_ENEMY | — | int | 5 (constant) | Base gold at floor 1 |
| floor_number | — | int | 1–5+ (MVP) | Current dungeon floor |
| BOSS_MULTIPLIER | — | int | 10 (constant) | Boss gold multiplier |

**Output Range:** 50 (floor 1 boss) to 300+ (floor 5+ boss).

**Example:**
Floor 5 boss:
```
boss_gold_drop = floor(5 * 5 * 10) = 250
```

---

### Formula 3: Offline Gold Reward

Offline gold reward calculated from time away and floor farming rate.

`offline_gold = floor(GOLD_PER_MINUTE * offline_minutes * OFFLINE_EFFICIENCY)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| GOLD_PER_MINUTE | — | int | Derived from floor 1 rates | Gold earned per minute at farming floor |
| offline_minutes | — | int | 0–720 | Minutes since last session (capped at 12h) |
| OFFLINE_EFFICIENCY | — | float | 0.5 (constant) | 50% efficiency for offline earnings |

**Output Range:** 0 (no offline time) to capped at 12 hours worth of gold.

**Example:**
8 hours offline (480 minutes), floor 1 farming (15 gold/min from 3 enemies):
```
offline_gold = floor(15 * 480 * 0.5) = 3600
```

---

**Note**: Enhancement gold cost formulas are defined in 材料系统 GDD (Formula 2). CurrencySystem does NOT define cost formulas — it executes costs requested by Enhancement System.

## Edge Cases

- **If add_currency is called with amount <= 0**: Operation fails with INVALID_AMOUNT error. No state change. Negative amounts cannot become accidental adds.

- **If remove_currency is called with amount <= 0**: Operation fails with INVALID_AMOUNT error. No state change.

- **If currency_id does not exist in ItemDatabase**: Operation fails with UNKNOWN_CURRENCY error. CurrencySystem validates currency_id against ItemDatabase CURRENCY category.

- **If current_balance >= max_stack (Gem) and add_currency is called**: Overflow occurs. Balance capped at max_stack (9999), excess discarded, `currency_overflow` signal emitted with discarded amount.

- **If max_stack == 0 (Gold/infinite)**: Overflow never occurs. Balance unlimited. No overflow signal.

- **If remove_currency is called with amount > current_balance**: Operation fails with INSUFFICIENT_BALANCE error. No partial deduction. Balance unchanged.

- **If MaterialSystem routes CURRENCY operation**: CurrencySystem handles the operation fully. MaterialSystem cache and signals do NOT update for currencies.

- **If SaveSystem.update_currency() fails**: CurrencySystem logs error, keeps in-memory state, emits `currency_persist_failed` signal. User can continue playing. Periodic save retries.

- **If CurrencySystem initialized before SaveSystem load**: CurrencySystem in "Not Initialized" state. Operations return NOT_INITIALIZED error. SaveSystem emits load_complete to trigger initialization.

- **If balance reaches 0**: UI displays "0" (not empty). Balance 0 is valid state. No special handling needed.

- **If Gem spend attempted in MVP**: `can_afford("mat_currency_gem", amount)` returns false (balance = 0). UI shows "Coming Soon" tooltip. Remove fails with INSUFFICIENT_BALANCE.

- **If offline_minutes exceeds MAX_OFFLINE_HOURS (12)**: Offline gold capped at 12-hour equivalent. Excess time ignored. Player cannot accumulate more than 12 hours offline gold.

## Dependencies

### Upstream Dependencies (Required for CurrencySystem)

| System | Dependency Type | Interface | Critical? |
|--------|----------------|-----------|-----------|
| **存档系统** | Hard | `get_currencies()`, `update_currency()` | Yes — CurrencySystem cannot operate without persistence |

### Horizontal Dependencies (Parallel systems)

| System | Dependency Type | Interface | Critical? |
|--------|----------------|-----------|-----------|
| **物品数据库** | Hard | `get_material(id)` (CURRENCY category) | Yes — CurrencySystem needs max_stack from definitions |
| **材料系统** | Soft (routing) | Receives delegated add/remove calls | Partial — MaterialSystem routes to CurrencySystem |

### Downstream Dependencies (Systems that depend on CurrencySystem)

| System | Dependency Type | Interface | Status |
|--------|----------------|-----------|--------|
| **装备强化系统** | Hard | `can_afford()`, `remove_currency()` | Not yet designed |
| **掉落表系统** | Hard | `add_currency()` | Not yet designed |
| **离线收益系统** | Hard | `add_currency()` | Not yet designed |
| **数值显示系统** | Soft | Signals: `currency_changed` | Not yet designed |

### Dependency Notes

- **存档系统**: CurrencySystem's cache populated from SaveSystem on load. Every successful add/remove triggers `update_currency()` call. Currency change is marked as **Critical trigger** in SaveSystem for immediate save.

- **物品数据库**: CurrencySystem queries ItemDatabase for max_stack and category validation. Only CURRENCY category materials are handled by CurrencySystem.

- **材料系统**: MaterialSystem Rule 9 routes CURRENCY operations to CurrencySystem. MaterialSystem acts as a pass-through, does NOT store or emit for currencies.

- **装备强化系统** (future): Will call `can_afford("mat_currency_gold", cost)` before enhancement attempt, then call `remove_currency()` to pay cost.

- **掉落表系统** (future): Will call `add_currency("mat_currency_gold", drop_amount)` when gold is awarded from combat.

- **离线收益系统** (future): Will call `add_currency("mat_currency_gold", accumulated_gold)` when player returns. Offline gold capped at 12 hours.

## Tuning Knobs

### Gold Drop Tuning

| Knob | Current Value | Safe Range | Effect of Change |
|------|---------------|------------|------------------|
| `BASE_GOLD_PER_ENEMY` | 5 | 1–20 | Higher = faster gold accumulation. Too high = inflation, too low = grind frustration. |
| `BOSS_MULTIPLIER` | 10 | 5–20 | Higher = larger boss rewards. Creates milestone moments. |
| `luck_multiplier_base` | 1.0 | 1.0–1.5 | Higher = luck stat more impactful on gold. Future stat integration. |

### Offline Reward Tuning

| Knob | Current Value | Safe Range | Effect of Change |
|------|---------------|------------|------------------|
| `OFFLINE_EFFICIENCY` | 0.5 | 0.25–0.75 | Higher = more gold while away. Lower = incentive to play actively. |
| `MAX_OFFLINE_HOURS` | 12 | 6–24 | Higher = can accumulate longer offline. Lower = frequent check-in incentive. |

### Gem Cap Tuning

| Knob | Current Value | Safe Range | Effect of Change |
|------|---------------|------------|------------------|
| `MAX_GEM_STACK` | 9999 | 1000–99999 | Gem storage capacity. MVP unused but affects future expansion. |

### Interaction Notes

- **BASE_GOLD_PER_ENEMY** interacts with floor progression — higher floors multiply base gold.
- **OFFLINE_EFFICIENCY** balances active vs idle play. 0.5 = offline earns half of active rate.
- **MAX_OFFLINE_HOURS** prevents excessive accumulation from long absences.
- **Gem knobs** have no MVP gameplay impact but affect data persistence and future expansion.

## Visual/Audio Requirements

### Gold Acquisition Feedback

When gold is added to balance:

| Event | Visual Effect | Audio Effect |
|-------|---------------|--------------|
| **Small gold gain (1–50)** | HUD number briefly pulses, subtle bounce | Soft coin "clink" |
| **Medium gold gain (51–500)** | Gold icon flies from source to HUD, number animates up | Coin cascade sound |
| **Large gold gain (501+)** | Multiple gold icons burst, HUD number flies up dramatically, screen edge gold glow | "Ka-ching" burst sound |
| **Offline gold reward** | Modal popup with gold summary, number animates from 0 to total, gold particle shower | Celebration jingle |

### Gold Spending Feedback

When gold is removed (enhancement cost):

| Event | Visual Effect | Audio Effect |
|-------|---------------|--------------|
| **Enhancement cost paid** | Gold streams from HUD to equipment icon, brief HUD number shrink | Purchase "confirm" sound |

### Gem Display (MVP Dormant)

| Event | Visual Effect | Audio Effect |
|-------|---------------|--------------|
| **Gem icon hover** | Tooltip "Coming Soon" or grayed out state | None (dormant) |

## UI Requirements

### HUD Currency Display

| Currency | Location | Format | Behavior |
|----------|----------|--------|----------|
| **Gold** | HUD top bar, left side | Icon + number (compact: 1.2K, 5.3M) | Always visible, animates on change |
| **Gem** | HUD top bar, right side | Icon + number | Grayed out if 0, tooltip "Coming Soon" |

### Enhancement Cost Preview

When player opens enhancement screen:

| Element | Display |
|---------|---------|
| **Gold cost** | Icon + cost amount, current balance shown below |
| **"Need X more" indicator** | Red text if deficit: "Need 500 more Gold" |
| **Enhance button** | Disabled if insufficient gold |

### Offline Reward Summary

When player returns from offline:

| Element | Display |
|---------|---------|
| **Gold earned** | Large animated number: "You earned 3,600 Gold!" |
| **Time away** | "While you were away (8 hours):" |

## Open Questions

| Question | Owner | Target Resolution |
|----------|-------|-------------------|
| **Should offline gold efficiency scale with progression (higher floors = better offline rate)?** | Systems Designer | Before Offline Reward System design |
| **Should Gold have a visual "overflow" effect when reaching milestone amounts (1M, 10M)?** | Art Director | Before Visual Feedback System design |
| **Should Gem be gifted to new players as teaser (e.g., 10 gems on first login)?** | Game Designer | Before production sprint planning |
| **Should large gold numbers (millions) use abbreviated display in HUD?** | UX Designer | Before UI layout system design |

## Acceptance Criteria

### Core Rules

**AC-R3-01: Add Gold — Unlimited Stack**
**GIVEN** player has 1,000,000 gold, **WHEN** `add_currency("mat_currency_gold", 500)` is called, **THEN** balance becomes 1,000,500 and `currency_added` signal emits.

**AC-R3-02: Add Gem — Capped at 9999**
**GIVEN** player has 9,950 gems, **WHEN** `add_currency("mat_currency_gem", 100)` is called, **THEN** balance becomes 9,999, `currency_overflow` signal emits with 51 discarded.

**AC-R4-01: Remove Gold — Success**
**GIVEN** player has 500 gold, **WHEN** `remove_currency("mat_currency_gold", 200)` is called, **THEN** balance becomes 300 and `currency_removed` signal emits.

**AC-R4-02: Remove Gold — Insufficient Balance**
**GIVEN** player has 100 gold, **WHEN** `remove_currency("mat_currency_gold", 200)` is called, **THEN** operation fails, balance unchanged, `currency_remove_failed` emits.

**AC-R5-01: Get Balance — Unknown Returns Zero**
**GIVEN** no balance for `mat_currency_gem`, **WHEN** `get_balance("mat_currency_gem")` is called, **THEN** returns 0 (never null).

**AC-R6-01: Can Afford — True**
**GIVEN** player has 150 gold, **WHEN** `can_afford("mat_currency_gold", 100)` is called, **THEN** returns true, no state change.

**AC-R6-02: Can Afford — False**
**GIVEN** player has 50 gold, **WHEN** `can_afford("mat_currency_gold", 100)` is called, **THEN** returns false.

**AC-R8-01: Gem Dormant in MVP**
**GIVEN** player has 0 gems, **WHEN** `can_afford("mat_currency_gem", 1)` is called, **THEN** returns false (no MVP source).

**AC-R9-01: MaterialSystem Routing**
**GIVEN** MaterialSystem receives `add_material("mat_currency_gold", 50)`, **WHEN** category detected as CURRENCY, **THEN** MaterialSystem delegates to CurrencySystem, MaterialSystem cache NOT updated.

### Formulas

**AC-F1-01: Gold Drop Floor 3**
**GIVEN** BASE_GOLD_PER_ENEMY = 5, floor = 3, luck = 1.0, **WHEN** gold drop calculated, **THEN** result = 15.

**AC-F2-01: Boss Gold Floor 4**
**GIVEN** BASE_GOLD_PER_ENEMY = 5, floor = 4, **WHEN** boss gold calculated, **THEN** result = 200.

**AC-F3-01: Offline Gold 8 Hours**
**GIVEN** GOLD_PER_MINUTE = 15, offline_minutes = 480, OFFLINE_EFFICIENCY = 0.5, **WHEN** offline gold calculated, **THEN** result = 3600.

**AC-F3-02: Offline Gold Capped at 12 Hours**
**GIVEN** offline_minutes = 900 (15h), **WHEN** offline gold calculated, **THEN** capped at 720 minutes, result = 5400.

### Edge Cases

**AC-EC-01: Invalid Amount Zero**
**GIVEN** any currency, **WHEN** `add_currency(id, 0)` called, **THEN** fails with INVALID_AMOUNT.

**AC-EC-02: Unknown Currency**
**GIVEN** currency_id not in ItemDatabase, **WHEN** `add_currency` called, **THEN** fails with UNKNOWN_CURRENCY.

**AC-EC-03: Balance Zero Display**
**GIVEN** player has 0 gold, **WHEN** UI queries balance, **THEN** displays "0" (not empty).

### Integration

**AC-INT-01: SaveSystem Critical Trigger**
**GIVEN** successful add/remove, **WHEN** operation completes, **THEN** SaveSystem.update_currency called immediately (Critical trigger).

**AC-INT-02: ItemDatabase Category Check**
**GIVEN** material id not CURRENCY category, **WHEN** `add_currency` called, **THEN** fails with UNKNOWN_CURRENCY.

## Open Questions

| Question | Owner | Target Resolution |
|----------|-------|-------------------|
| **Should offline gold efficiency scale with progression (higher floors = better offline rate)?** | Systems Designer | Before Offline Reward System design |
| **Should Gold have a visual "overflow" effect when reaching milestone amounts (1M, 10M)?** | Art Director | Before Visual Feedback System design |
| **Should Gem be gifted to new players as teaser (e.g., 10 gems on first login)?** | Game Designer | Before production sprint planning |
| **Should large gold numbers (millions) use abbreviated display in HUD?** | UX Designer | Before UI layout system design |