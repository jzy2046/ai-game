# 收益计算系统

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: 稳定成长、掌控节奏

## Overview

收益计算系统是游戏的收益计算逻辑层，负责计算战斗收益（金币、材料、装备掉落预期）和离线收益（基于离线时长和战斗效率）。它从战斗系统获取战斗时长数据，从时间追踪系统获取离线时长，结合掉落表系统和物品数据库的配置，计算出玩家应获得的收益。

该系统是离线收益系统的上游依赖：离线收益系统不直接计算"玩家离开了多久能刷多少材料"，而是调用收益计算系统的接口获取"每秒预期收益"和"单层完成预期收益"，再乘以离线时长得到总收益。收益计算系统提供的是"收益计算引擎" — 输入时间和层级信息，输出预期收益列表。

**核心职责**：
- 计算单场战斗预期收益（金币、材料、装备掉落概率）
- 计算单层完成预期时间（基于敌人配置和玩家攻击力）
- 计算每秒平均收益率（用于离线收益换算）
- 提供收益查询接口供离线收益系统和UI系统调用

**架构定位**: Economy 层（Core 子层），为 离线收益系统（Feature 层）提供计算服务，依赖 战斗系统 和 时间追踪系统 的输出数据。

## Player Fantasy

收益计算系统是纯计算基础设施，玩家不直接与之交互。玩家感受到的是它所支撑的**离线收益体验**：

> **"我的进度在等待我回来"** — 玩家关闭游戏后，角色仍在"虚拟世界"中自动战斗刷材料；玩家归来时，看到累积的离线收益，感到"我离开的时间被尊重了"。这种感觉支撑支柱"稳定成长"的核心承诺：玩家的每一分钟都有价值。

收益计算系统通过提供准确的收益估算，确保：
- 离线收益反映玩家真实战力水平（攻击力越高，刷得越快）
- 离线收益与层级难度匹配（高层敌人掉落更好）
- 收益计算透明可预测（玩家知道"刷第1层1小时能得多少材料")

收益计算系统的失败会破坏这种隐性体验：如果离线收益计算错误，玩家可能获得过多收益（破坏"掌控节奏"）或过少收益（破坏"稳定成长"的公平感）。

**参考**: 梦幻西游手游 — 离线收益准确反映挂机时长和角色能力，玩家感到"收菜"是公平的。

## Detailed Design

### Core Rules

#### Rule 1: Yield Types and Categories

收益计算系统计算三类收益：

| Yield Type | Source | Calculation Basis |
|------------|--------|-------------------|
| **Gold** | 战斗胜利 | 基于敌人 defeated 数量和层级 |
| **Materials** | 掉落表 guaranteed drops | Enhancement Stones, Crystal Essence, Celestial Shard |
| **Equipment** | 掉落表 weighted drops | 按概率期望值计算（不模拟实际掉落）|

**收益单位**:
- Gold: 金币数量（整数）
- Materials: 材品ID → 数量映射
- Equipment: 装备ID → 概率期望值映射

---

#### Rule 2: Single Battle Yield Calculation

单场战斗的预期收益计算。

**计算流程**:
1. 获取敌人配置：`enemy_types`, `enemy_count` from 地牢结构系统
2. 获取掉落表：`drop_table_id` from 地牢结构系统
3. 解析掉落表：调用 DropTableSystem.resolve_drop()
4. 计算预期收益：
   - Guaranteed drops: 全部计入
   - Weighted drops: 按概率期望值计算

**期望值计算公式**:
```
expected_equipment_drop = sum(item.weight / total_weight * 1) for each weighted entry
```

**示例**: Floor 1-3 drop_table (Iron Blade weight=100, total_weight=240):
```
expected_iron_blade = 100/240 * 1 = 0.417 (约42%概率，期望值0.42件)
```

---

#### Rule 3: Floor Completion Time Calculation

单层完成预期时间（用于离线收益换算）。

**公式来源**: dungeon-structure-system.md Formula 3

```
estimated_completion_time(floor_id) = base_time + enemy_count(floor_id) * per_enemy_time
```

**变量**:
- base_time = 2.0 秒（registry）
- per_enemy_time = 5.0 秒（registry）
- enemy_count = 1-4 (by floor)

**输出范围**: 7秒 (Floor 1) to 22秒 (Floor 10)

---

#### Rule 4: Yield Per Second Calculation

计算每秒平均收益率（用于离线收益换算）。

**计算流程**:
1. 计算单层完成收益: `floor_yield(floor_id)`
2. 计算单层完成时间: `estimated_completion_time(floor_id)`
3. 计算每秒收益率: `yield_per_second = floor_yield / completion_time`

**公式**:
```
yield_per_second(floor_id) = floor_yield(floor_id) / estimated_completion_time(floor_id)
```

**收益组成**:
```
floor_yield(floor_id) = {
    gold: gold_per_enemy * enemy_count(floor_id),
    materials: guaranteed_drops from drop_table,
    equipment_expected: sum(weight/total_weight for each weighted entry)
}
```

---

#### Rule 5: Offline Yield Calculation

离线期间的预期收益计算。

**公式**:
```
offline_yield = yield_per_second(target_floor) * offline_duration
```

**参数**:
- `target_floor`: 离线挂机目标层级（默认 highest_floor 或玩家指定）
- `offline_duration`: 离线时长（from 时间追踪系统，上限 MAX_ALLOWED_OFFLINE = 86400秒）

**收益上限**:
- Gold: 无上限（但受 offline_duration 上限约束）
- Materials: 每种材料独立上限（防止堆积过多）
- Equipment: 不计入离线收益（MVP阶段离线只刷材料，不掉装备）

---

#### Rule 6: Interface Methods

收益计算系统提供以下接口：

| Method | Parameters | Return | Purpose |
|--------|------------|--------|---------|
| `calculate_floor_yield(floor_id)` | floor_id: int | Dictionary | 计算单层完成预期收益 |
| `calculate_yield_per_second(floor_id)` | floor_id: int | Dictionary | 计算每秒收益率 |
| `calculate_offline_yield(floor_id, duration)` | floor_id: int, duration: float | Dictionary | 计算离线收益 |
| `get_completion_time(floor_id)` | floor_id: int | float | 返回单层完成时间 |

**返回格式**:
```gdscript
{
    gold: 50,
    materials: {
        "mat_enhance_stone_common": 2,
        "mat_enhance_crystal_essence": 0
    },
    equipment_expected: {
        "equip_weapon_iron_blade": 0.42
    }
}
```

---

### States and Transitions

收益计算系统是**无状态**的计算层。它不维护运行时状态，只响应查询请求并返回计算结果。

**调用流程**:
```
离线收益系统请求 → YieldCalculationSystem.calculate_offline_yield(floor_id, duration)
                → 加载掉落表配置
                → 计算单层收益
                → 计算每秒收益率
                → 乘以离线时长
                → 返回收益字典
```

---

### Interactions with Other Systems

| System | Direction | Interface | Data Flow |
|--------|-----------|-----------|-----------|
| **战斗系统** | Upstream (Hard) | combat_duration formula | 提供战斗时长估算公式，本系统用于计算收益率 |
| **时间追踪系统** | Upstream (Hard) | get_offline_duration() | 提供离线时长，本系统用于计算离线收益 |
| **地牢结构系统** | Upstream (Hard) | get_floor_data(floor_id) | 提供层级配置（敌人数量、掉落表ID） |
| **掉落表系统** | Upstream (Hard) | resolve_drop(drop_table_id) | 提供掉落配置，本系统用于计算预期收益 |
| **物品数据库** | Upstream (Soft) | get_material(id), get_equipment(id) | 验证物品ID有效性，获取物品定义 |
| **离线收益系统** | Downstream (Hard) | calculate_offline_yield() | 接收收益计算结果，处理发放和展示 |
| **存档系统** | Downstream (Soft) | — | 离线收益发放后更新存档 |

**Interface Contracts**:
- `calculate_offline_yield()` 返回格式: `{ gold: int, materials: {item_id: qty}, equipment_expected: {item_id: probability} }`
- 所有 `item_id` 必定存在于物品数据库
- 返回值基于概率期望，不是实际掉落模拟

## Formulas

### Formula 1: Floor Completion Time

The floor completion time formula is defined as:

`estimated_completion_time(floor_id) = base_time + enemy_count(floor_id) * per_enemy_time`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| floor_id | `f` | int | 1–10 | 层级ID |
| base_time | `bt` | float | 2.0 秒 | 基础时间（入场+结算） |
| per_enemy_time | `pet` | float | 5.0 秒 | 每敌人平均战斗时间 |
| enemy_count | `ec` | int | 1–4 | 层级敌人数量（from 地牢结构系统） |
| estimated_completion_time | `ect` | float | 7–22 秒 | 层级完成时间 |

**Output Range:** 7秒 (Floor 1, 1 enemy) to 22秒 (Floor 10, 4 enemies)

**Example:** Floor 5 (2 enemies):
```
ect = 2.0 + 2 * 5.0 = 12秒
```

---

### Formula 2: Material Yield Per Floor

The material yield per floor formula is defined as:

`material_yield(floor_id) = guaranteed_materials(drop_table_id)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| floor_id | `f` | int | 1–10 | 层级ID |
| drop_table_id | `dt` | string | — | 掉落表ID（from 地牢结构系统） |
| guaranteed_materials | `gm` | Dictionary | — | 必定掉落材料列表 |
| material_yield | `my` | Dictionary | — | 材料收益 {item_id: quantity} |

**Output Range:** Floor 1-3: 1-2 Enhancement Stones; Floor 10 BOSS: 5-10 Stones + 1 Celestial Shard

**Example:** Floor 7-10 drop_table:
```
material_yield = {
    mat_enhance_stone_common: random_int(3, 5),
    mat_enhance_crystal_essence: 1
}
```

---

### Formula 3: Gold Yield Per Floor

The gold yield per floor formula is defined as:

`gold_yield(floor_id) = gold_per_enemy * enemy_count(floor_id)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| floor_id | `f` | int | 1–10 | 层级ID |
| gold_per_enemy | `gpe` | int | 10–50 | 单敌人金币掉落（by floor tier） |
| enemy_count | `ec` | int | 1–4 | 层级敌人数量 |
| gold_yield | `gy` | int | 10–200 | 层级金币收益 |

**Output Range:** Floor 1: ~10 gold; Floor 10: ~200 gold (4 enemies × 50 gold each)

**Example:** Floor 5 (2 enemies, gold_per_enemy=20):
```
gy = 20 * 2 = 40 gold
```

---

### Formula 4: Yield Per Second

The yield per second formula is defined as:

`yield_per_second(floor_id) = floor_yield(floor_id) / estimated_completion_time(floor_id)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| floor_id | `f` | int | 1–10 | 层级ID |
| floor_yield | `fy` | Dictionary | — | 单层总收益 {gold, materials, equipment_expected} |
| estimated_completion_time | `ect` | float | 7–22 秒 | 层级完成时间 |
| yield_per_second | `yps` | Dictionary | — | 每秒收益率 |

**Output Range:** Gold: ~0.8-1.4 gold/sec; Materials: ~0.14-0.45 stones/sec

**Example:** Floor 5 (gold_yield=40, completion_time=12s):
```
gold_yps = 40 / 12 = 3.33 gold/sec
material_yps = 2 / 12 = 0.17 stones/sec
```

---

### Formula 5: Offline Yield Calculation

The offline yield formula is defined as:

`offline_yield(target_floor, offline_duration) = yield_per_second(target_floor) * offline_duration`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| target_floor | `tf` | int | 1–10 | 离线挂机目标层级 |
| offline_duration | `od` | float | 0–86400 秒 | 离线时长（上限 MAX_ALLOWED_OFFLINE） |
| yield_per_second | `yps` | Dictionary | — | 每秒收益率 |
| offline_yield | `oy` | Dictionary | — | 离线总收益 |

**Output Range:** 0 (no offline) to MAX_ALLOWED_OFFLINE * floor_yield (24 hours offline)

**Example:** Floor 1 offline 2 hours (7200s):
```
gold_oy = 0.8 * 7200 = 5760 gold
material_oy = 0.14 * 7200 = 1008 Enhancement Stones
```

---

### Formula 6: Equipment Drop Probability Expectation

The equipment drop probability expectation formula is defined as:

`expected_equipment = item_weight / total_weight_pool`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| item_weight | `w` | int | 1–100 | 装备在掉落池中的权重 |
| total_weight_pool | `W` | int | — | 掉落池总权重 |
| expected_equipment | `ee` | float | 0.01–1.0 | 装备掉落概率期望 |

**Output Range:** 0.01 (EPIC rare) to 0.50+ (COMMON frequent)

**Example:** Floor 1-3 drop pool (Iron Blade weight=100, total=240):
```
expected_iron_blade = 100 / 240 = 0.417 (42% probability)
```

---

### Summary Table: Yield Rates by Floor

| Floor Range | Completion Time | Gold Yield | Gold/sec | Materials Yield | Stones/sec |
|-------------|-----------------|------------|----------|-----------------|------------|
| 1-3 | 7-12 秒 | 10-30 | 1.0-2.5 | 1-2 | 0.14-0.17 |
| 4-6 | 12-17 秒 | 40-90 | 3.3-5.3 | 2-4 | 0.17-0.24 |
| 7-10 | 17-22 秒 | 150-200 | 7.5-9.1 | 3-6 | 0.18-0.27 |

## Edge Cases

### Edge Case 1: Zero Offline Duration

**Scenario**: 离线时长为0（玩家刚离开又立即返回）。

**Expected Behavior**:
- offline_yield 返回 `{ gold: 0, materials: {}, equipment_expected: {} }`
- 无收益发放
- 不记录任何异常
- 离线收益系统正常处理空收益

**Test**: offline_duration=0 → 验证返回空收益字典。

---

### Edge Case 2: Offline Duration Exceeds MAX_ALLOWED_OFFLINE

**Scenario**: 离线时长超过上限（如玩家离线30天）。

**Expected Behavior**:
- 时间追踪系统已将 offline_duration 截断到 MAX_ALLOWED_OFFLINE (86400秒/24小时)
- 本系统使用截断后的时长计算收益
- 收益按24小时上限计算，不超出
- 无额外处理（上限由时间追踪系统负责）

**Test**: offline_duration=2592000 (30天) → 验证收益等于24小时收益。

---

### Edge Case 3: Invalid Floor ID

**Scenario**: 调用 calculate_floor_yield(floor_id) 时 floor_id 不存在（如 floor_id=15）。

**Expected Behavior**:
- 返回空收益字典 `{ gold: 0, materials: {}, equipment_expected: {} }`
- 日志警告："Floor [id] not found in yield calculation"
- 不抛出异常
- 离线收益系统检测到空收益，使用默认层级（floor 1）fallback

**Test**: floor_id=15 → 验证返回空收益，警告日志。

---

### Edge Case 4: Invalid Drop Table ID

**Scenario**: 地牢结构系统返回的 drop_table_id 不存在于掉落表系统。

**Expected Behavior**:
- 调用 DropTableSystem.resolve_drop(invalid_id) 返回空掉落
- 本系统检测到空掉落，material_yield = {}
- gold_yield 正常计算（金币掉落不依赖掉落表）
- 日志警告："Drop table [id] invalid for floor [floor_id]"
- 降级处理，只返回金币收益

**Test**: drop_table_id="invalid" → 验证返回金币收益，材料空。

---

### Edge Case 5: Zero Player Attack (Combat Impossible)

**Scenario**: 玩家攻击力为0（无装备或装备攻击力为0），无法战斗。

**Expected Behavior**:
- 战斗系统会处理此情况（战斗无法进行）
- 本系统不处理战斗逻辑，只计算收益
- yield_per_second 正常计算（基于掉落表配置，不依赖玩家攻击力）
- 实际战斗结果由战斗系统处理

**Note**: 收益计算假设战斗可完成，实际战斗失败由战斗系统处理。

**Test**: 玩家攻击力=0 → 验证 yield_per_second 正常计算。

---

### Edge Case 6: Material Quantity Exceeds Stack Limit

**Scenario**: 离线收益计算出的材料数量超过堆叠上限。

**Expected Behavior**:
- 本系统不处理堆叠上限（由材料系统负责）
- 返回计算出的原始数量
- 材料系统在发放时应用上限
- 不在本系统层面截断

**Test**: 离线24小时 → 计算出1000+ stones → 验证返回原始值。

---

### Edge Case 7: Multiple Enemies With Same Drop Table

**Scenario**: 层级有多个敌人，每个敌人使用相同掉落表。

**Expected Behavior**:
- 每个敌人独立触发掉落解析
- 离线收益按单层收益乘以时长（不乘以敌人数量）
- gold_yield = gold_per_enemy * enemy_count（金币累加）
- material_yield 使用掉落表的 guaranteed drops（不累加）

**Rationale**: 离线收益模拟"刷该层级N次"，每次击败所有敌人获得一次掉落。

**Test**: Floor 5 (2 enemies) → 验证 gold 累加，materials 不累加。

---

### Edge Case 8: Floor Not Yet Unlocked

**Scenario**: 离线收益请求的 target_floor 玩家尚未解锁。

**Expected Behavior**:
- 本系统不验证解锁状态（由地牢推进系统负责）
- 正常计算收益
- 离线收益系统在发放前验证解锁状态
- 若未解锁，使用 highest_floor 作为 fallback

**Note**: 解锁验证是离线收益系统的职责，本系统只提供计算。

**Test**: target_floor=10 when highest_floor=5 → 验证正常计算，发放逻辑由下游处理。

## Dependencies

### Upstream Dependencies (本系统依赖)

| System | Type | Interface | Notes |
|--------|------|-----------|-------|
| **战斗系统** | Hard | combat_duration formula | 提供战斗时长估算公式，本系统用于计算收益率 |
| **时间追踪系统** | Hard | get_offline_duration(), MAX_ALLOWED_OFFLINE | 提供离线时长和上限参数 |
| **地牢结构系统** | Hard | get_floor_data(floor_id), estimated_completion_time | 提供层级配置（敌人数量、掉落表ID、完成时间） |
| **掉落表系统** | Hard | resolve_drop(drop_table_id) | 提供掉落配置，本系统用于计算预期收益 |
| **物品数据库** | Soft | get_material(id), get_equipment(id) | 酷证物品ID有效性，获取物品定义 |

**Constraint from 战斗系统 GDD**:
- Formula 2: combat_duration = sum(enemy.max_health) / (player_attack * HITS_PER_SECOND)
- HITS_PER_SECOND = 2.0 hits/sec (registry)

**Constraint from 时间追踪系统 GDD**:
- MAX_ALLOWED_OFFLINE = 86400 秒 (24 hours)
- get_offline_duration() 返回已截断的离线时长

**Constraint from 地牢结构系统 GDD**:
- Formula 3: estimated_completion_time = base_time + enemy_count * per_enemy_time
- base_time = 2.0 秒 (registry)
- per_enemy_time = 5.0 秒 (registry)
- get_floor_data(floor_id) 返回 floor 配置

**Constraint from 掉落表系统 GDD**:
- resolve_drop(id) 返回 { guaranteed: [...], weighted: [...] }
- guaranteed drops 全部计入收益
- weighted drops 按概率期望值计算

---

### Downstream Dependencies (依赖本系统)

| System | Type | Interface Used | Notes |
|--------|------|---------------|-------|
| **离线收益系统** | Hard | calculate_offline_yield(), calculate_yield_per_second() | 接收收益计算结果，处理发放和展示 |

**Interface Contracts**:
- calculate_offline_yield(floor_id, duration) 返回 `{ gold: int, materials: {id: qty}, equipment_expected: {id: prob} }`
- calculate_yield_per_second(floor_id) 返回每秒收益率字典
- get_completion_time(floor_id) 返回 float (秒)

---

### External Dependencies (非游戏系统)

| Dependency | Type | Usage |
|------------|------|-------|
| **Godot Dictionary** | Hard | 返回值数据结构 |
| **Godot Array** | Hard | 物品列表存储 |
| **Godot Math Functions** | Hard | 除法、乘法计算 |

---

### Dependency Graph

```
[战斗系统] ─────────────────────┐
    │                           │
    │ combat_duration formula   │
    v                           v
[时间追踪系统] ────────→ [收益计算系统] ────────→ [离线收益系统]
    │                           │
    │ offline_duration          │ calculate_offline_yield()
    v                           v
[地牢结构系统]             (发放收益 + 展示UI)
    │
    │ floor_data
    v
[掉落表系统]
```

## Tuning Knobs

### Gold Yield Configuration

| Knob | Default | Range | Unit | What It Affects |
|------|---------|-------|------|-----------------|
| `GOLD_PER_ENEMY_FLOOR_1_3` | 10 | 5–20 | gold | Floor 1-3 单敌人金币掉落 |
| `GOLD_PER_ENEMY_FLOOR_4_6` | 20 | 15–30 | gold | Floor 4-6 单敌人金币掉落 |
| `GOLD_PER_ENEMY_FLOOR_7_10` | 50 | 40–60 | gold | Floor 7-10 单敌人金币掉落 |
| `GOLD_PER_ENEMY_FLOOR_10_BOSS` | 100 | 80–150 | gold | Floor 10 BOSS 金币掉落 |

**Tuning guidance**: 金币掉落随层级增长，确保高层收益更丰厚。MVP使用线性增长（10→20→50→100），支撑"稳定成长"支柱。

---

### Material Yield Configuration

| Knob | Default | Range | Unit | What It Affects |
|------|---------|-------|------|-----------------|
| `MAT_STONE_MIN_FLOOR_1_3` | 1 | 1–2 | stones | Floor 1-3 最少掉落 Enhancement Stones |
| `MAT_STONE_MAX_FLOOR_1_3` | 2 | 1–3 | stones | Floor 1-3 最多掉落 Enhancement Stones |
| `MAT_STONE_MIN_FLOOR_7_10` | 3 | 2–5 | stones | Floor 7-10 最少掉落 Enhancement Stones |
| `MAT_STONE_MAX_FLOOR_7_10` | 5 | 3–8 | stones | Floor 7-10 最多掉落 Enhancement Stones |

**Tuning guidance**: 材料数量已在掉落表系统定义，本系统直接引用掉落表配置。修改材料掉落应修改掉落表系统 tuning knobs。

---

### Offline Yield Cap Configuration

| Knob | Default | Range | Unit | What It Affects |
|------|---------|-------|------|-----------------|
| `MAX_OFFLINE_MATERIAL_STACK` | 500 | 100–1000 | stones | 离线材料收益上限（防止堆积过多） |

**Tuning guidance**: 离线收益上限防止玩家长期不玩后获得过多材料。上限由材料系统在发放时应用，本系统不截断。

---

### Yield Rate Summary

| Floor | Gold/sec | Stones/sec | Notes |
|-------|----------|------------|-------|
| 1-3 | 1.0–2.5 | 0.14–0.17 | 入门层级，收益适中 |
| 4-6 | 3.3–5.3 | 0.17–0.24 | 进阶级，收益提升 |
| 7-10 | 7.5–9.1 | 0.18–0.27 | 高级层，收益丰厚 |
| BOSS | 10+ | 0.5+ | BOSS奖励丰厚 |

---

### Session Feasibility Analysis

**Assumptions**:
- 离线24小时 (MAX_ALLOWED_OFFLINE = 86400秒)
- Floor 1 yield_per_second: gold=1.0, stones=0.14

**Offline 24h yield**:
| Floor | Gold Yield | Material Yield |
|-------|------------|----------------|
| 1 | ~864 gold | ~1200 stones |
| 5 | ~2880 gold | ~1500 stones |
| 10 | ~7800 gold | ~2400 stones |

**Material cap**: 500 stones per type → Floor 1 离线24h 会触发上限截断

**Balance verification**: 离线收益应低于手动游玩24h（避免鼓励挂机而非游玩）
- 手动游玩: 24h = 86400s / 7s/floor = ~12285 floors × 2 stones/floor = ~24570 stones
- 离线收益上限: 500 stones
- 离线收益约为手动的 2%，符合设计意图（鼓励回归但奖励游玩）

---

### Configuration File

All knobs defined in `assets/data/tuning/yield_config.json`:

```json
{
  "version": "1.0.0",
  "gold_per_enemy": {
    "floor_1_3": 10,
    "floor_4_6": 20,
    "floor_7_10": 50,
    "boss": 100
  },
  "offline_limits": {
    "max_material_stack": 500
  }
}
```

## Visual/Audio Requirements

**None — this is a calculation layer.**

收益计算系统不直接呈现给玩家。所有视觉和音频反馈由下游系统负责：

| Aspect | Responsible System | Notes |
|--------|-------------------|-------|
| 离线收益展示 | 离线收益系统 | "收菜"面板显示金币和材料数量 |
| 收益飞入动画 | 视觉反馈系统 | 材料飞入inventory计数器 |
| 收益音效 | 音效系统 | Post-MVP，金币入账音效 |

收益计算系统只提供 `{ gold: int, materials: {id: qty} }` 数据。如何展示是离线收益系统的职责。

## UI Requirements

**None — this is a calculation layer.**

收益计算系统没有直接UI。玩家不与收益计算交互 — 离线收益系统调用本系统获取计算结果，然后展示给玩家。

任何UI需求由下游系统实现：
- **离线收益面板**: 离线收益系统负责（"收菜"弹窗）
- **收益预览**: UX设计时确定（Post-MVP可选）
- **调试工具**: 开发者工具（非玩家UI）

MVP阶段无需收益计算相关的玩家UI。

## Acceptance Criteria

### AC 1: Floor Yield Calculation

**Test**: Call `calculate_floor_yield(1)` for Floor 1.
**Pass**:
- Returns `{ gold: ~10, materials: {mat_enhance_stone_common: 1-2}, equipment_expected: {...} }`
- All `item_id` exist in 物品数据库
- Gold value matches GOLD_PER_ENEMY_FLOOR_1_3 × enemy_count

---

### AC 2: Yield Per Second Calculation

**Test**: Call `calculate_yield_per_second(5)` for Floor 5.
**Pass**:
- Returns gold_per_sec = gold_yield / completion_time
- gold_per_sec ≈ 40/12 = 3.33 gold/sec
- materials_per_sec matches expected range

---

### AC 3: Offline Yield Calculation

**Test**: Call `calculate_offline_yield(1, 7200)` (Floor 1, 2 hours offline).
**Pass**:
- Returns gold ≈ 7200 gold
- Returns materials ≈ {mat_enhance_stone_common: 1000+}
- Materials may exceed MAX_OFFLINE_MATERIAL_STACK (handled by 材料系统)

---

### AC 4: Zero Duration Handling

**Test**: Call `calculate_offline_yield(1, 0)`.
**Pass**:
- Returns `{ gold: 0, materials: {}, equipment_expected: {} }`
- No warnings or errors

---

### AC 5: Invalid Floor ID Handling

**Test**: Call `calculate_floor_yield(15)` (invalid floor).
**Pass**:
- Returns empty yield dictionary
- Warning logged: "Floor 15 not found in yield calculation"

---

### AC 6: Completion Time Calculation

**Test**: Call `get_completion_time(5)`.
**Pass**:
- Returns 12.0 seconds (base_time + enemy_count × per_enemy_time)
- Matches formula: 2.0 + 2 × 5.0 = 12

---

### AC 7: Integration with Drop Table System

**Test**: calculate_floor_yield uses drop_table_floor_1_3.
**Pass**:
- Guaranteed drops included in materials
- Weighted drops converted to expected probabilities
- Example: Iron Blade expected ≈ 0.42

---

### AC 8: Integration with Time Tracking System

**Test**: 离线收益系统调用本系统，使用 get_offline_duration() 返回值。
**Pass**:
- offline_duration 已截断到 MAX_ALLOWED_OFFLINE
- 本系统使用截断值计算收益
- 收益不超过24小时上限

---

### AC 9: Gold Yield Scaling by Floor

**Test**: Compare gold_yield for Floor 1, 5, 10.
**Pass**:
- Floor 1: ~10 gold
- Floor 5: ~40 gold
- Floor 10: ~200 gold
- Scaling follows GOLD_PER_ENEMY configuration

---

### AC 10: Material Yield Scaling by Floor

**Test**: Compare material_yield for Floor 1, 7, 10 BOSS.
**Pass**:
- Floor 1: 1-2 Enhancement Stones
- Floor 7: 3-5 Enhancement Stones + 1 Crystal Essence
- Floor 10 BOSS: 5-10 Stones + 1 Celestial Shard
- Scaling follows drop_table configuration

## Open Questions

### OQ 1: Equipment Drops in Offline Yield

**Question**: Should offline yield include equipment drops (expected probabilities) or only materials?
**Current decision**: MVP阶段离线只刷材料，不掉装备。Equipment drops only from active gameplay.
**Impact**: 简化离线收益计算，避免装备堆积。Post-MVP可考虑"装备掉落预览"功能。

---

### OQ 2: Dynamic Yield Adjustment

**Question**: Should yield rates adjust based on player power or remain fixed?
**Current decision**: Yield rates fixed per floor (not dynamic). Player power affects combat_duration, not yield_per_second.
**Rationale**: 战斗系统已处理玩家攻击力vs敌人HP，收益计算使用固定掉落表配置。

---

### OQ 3: Offline Farming Target Floor Selection

**Question**: Should player be able to choose offline farming target floor, or default to highest_floor?
**Current decision**: Default to highest_floor. Player choice is Post-MVP feature.
**Impact**: 离线收益系统可添加"挂机目标层级选择"功能，本系统只提供计算。

---

### OQ 4: Material Cap Per Type vs Total Cap

**Question**: Should MAX_OFFLINE_MATERIAL_STACK apply per material type or to total materials?
**Current decision**: Per type (每种材料独立上限500)。
**Rationale**: Prevents stone hoarding, but allows multiple material types. 材料系统负责应用上限。

---

### OQ 5: Yield Calculation Method for Multiple Floors

**Question**: If player unlocks multiple floors, should offline yield use weighted average across floors?
**Current decision**: Single target floor only. No multi-floor averaging.
**Impact**: 简化计算。Post-MVP可考虑"挂机策略"让玩家分配时间到多个层级。

---

### OQ 6: Gold Sink Balance Verification

**Question**: Do offline gold yields match gold costs from 强化公式系统?
**Current decision**: Offline yield (864 gold/24h at Floor 1) << 强化成本 (5500 gold for +0→+10).
**Rationale**: 离线收益作为补充而非主要来源，鼓励手动游玩。
**Tuning**: Run `/consistency-check` after tuning to verify gold flow balance.