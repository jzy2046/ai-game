# 战斗系统

> **Status**: Designed
> **Author**: [user + agents]
> **Last Updated**: 2026-05-01
> **Implements Pillar**: 爽感反馈、稳定成长、掌控节奏

## Overview

战斗系统是游戏的核心战斗逻辑层，负责自动战斗流程的驱动、伤害计算、敌人HP消耗、战斗状态管理，以及"跳过战斗"机制的实现。它从物品数据库获取玩家攻击力/防御力数值，从敌人系统获取敌人实例数据，按固定频率（每秒攻击次数）计算伤害并应用，直到所有敌人HP降至0触发战斗胜利。

战斗系统是**自动战斗引擎** — 玩家不手动操作攻击，系统自动按时间tick计算伤害。战斗过程可观看（数值实时变化、击败动画）或跳过（快速结算，直接进入掉落展示）。跳过机制服务于支柱"掌控节奏"，让玩家决定参与深度。

**数据流程**：
1. 战斗开始 → 敌人系统生成敌人实例
2. 循环tick → 计算玩家攻击伤害 → 应用到敌人HP
3. HP归零 → 触发击败事件 → 敌人进入DEFEATED状态
4. 所有敌人击败 → 战斗胜利 → 触发掉落结算

**MVP范围**：单回合自动战斗，无技能/大招系统，无玩家主动操作。跳过战斗直接结算，无惩罚。

## Player Fantasy

战斗是玩家"掌控感"与"爽感"的交汇点。玩家可以选择观看战斗动画、欣赏数值变化的视觉反馈，或者选择跳过战斗、快速推进层级进度。两种选择都是正确的玩法 — 支柱"掌控节奏"承诺玩家有权决定自己的参与深度。

**核心幻想**：
> **"我的节奏，我的战斗"** — 玩家可以认真观看每次伤害数字跳动，感受敌人HP逐步下降的征服感；也可以选择跳过，快速推进到下一个层级，追求效率。战斗系统不强迫玩家等待，也不惩罚跳过 — 玩家的选择就是游戏的节奏。

**锚定时刻**：第一次决定"跳过战斗"的时刻。玩家推进到第5层，刚获得一件新装备想试试效果。战斗开始后，玩家决定这次认真观看 — 看到伤害数字飞溅、敌人HP条缩短、击败时粒子爆发。下一层，玩家累了或赶时间，点击"跳过"按钮 — 战斗瞬间结算，掉落直接展示。玩家感到"游戏尊重我的选择"。

**爽感与效率的平衡**：
- 观看战斗：视觉爽感 — 数值飞溅、粒子爆发、屏幕震动。适合想体验"征服感"的时刻。
- 跳过战斗：效率爽感 — 快速推进、立即掉落、节省时间。适合想"再推一层试试"的时刻。

**参考时刻**：Idle Slayer — 玩家可以选择观看自动战斗或点击"快速战斗"跳过。跳过不会惩罚，观看不强制。这种尊重玩家节奏的设计让玩家感到"游戏是工具，我掌控它"。

**支柱对应**：
- 爽感反馈：伤害数字飞溅、击败粒子爆发（观看时）
- 稳定成长：战斗结果可预期（足够数值=胜利，无随机失败）
- 掌控节奏：跳过按钮让玩家决定参与深度

## Detailed Design

### Core Rules

**Rule 1: Combat Initiation**

战斗在玩家进入层级时启动。启动流程：

| Step | Action | System |
|------|--------|--------|
| 1 | 玩家选择进入层级 | 地牢推进系统 |
| 2 | 调用 `spawn_enemies_for_floor(floor_id)` | 敌人系统 |
| 3 | 获取玩家攻击力/防御力 | 物品数据库 + 存档系统 |
| 4 | 进入战斗状态 | 战斗系统 |

**玩家属性获取**:
```gdscript
player_attack = sum(ItemDatabase.calculate_enhanced_attack(equip_id, level) for each equipped slot)
player_defense = sum(ItemDatabase.calculate_enhanced_defense(equip_id, level) for each equipped slot)
```

---

**Rule 2: Damage Calculation per Tick**

战斗按固定频率执行攻击tick。

`damage_per_tick = floor(player_attack * ATTACK_VARIANCE_FACTOR * random_range(0.9, 1.1))`

**攻击机制**:
- 每秒攻击次数 = `HITS_PER_SECOND` (registry: 2.0 hits/sec)
- 每tick间隔 = `1.0 / HITS_PER_SECOND` = 0.5秒
- 每次攻击选择一个存活敌人作为目标
- 目标选择策略: 循环轮换（按敌人实例顺序）

**伤害应用**:
```gdscript
func apply_damage_to_enemy(enemy: EnemyInstance, damage: int):
    enemy.current_health = max(0, enemy.current_health - damage)
    emit_signal("damage_applied", enemy, damage)
    if enemy.current_health <= 0:
        trigger_enemy_defeat(enemy)
```

---

**Rule 3: Enemy Defeat Trigger**

敌人HP归零时触发击败流程：

| Event | Action | System |
|-------|--------|--------|
| HP ≤ 0 | 敌人状态 → DEFEATED | 敌人系统 |
| 触发 `enemy_defeated` 信号 | 播放击败动画 + 粒子效果 | 视觉反馈系统 |
| 动画完成 (0.5s) | 标记敌人击败完成 | 战斗系统 |

**击败信号携带数据**:
```gdscript
signal enemy_defeated(enemy_id: String, enemy_rarity: Rarity, position: Vector2)
```

---

**Rule 4: Combat Victory Condition**

战斗胜利条件：所有敌人进入DEFEATED状态。

`combat_victory = all(enemy.state == DEFEATED for enemy in enemies)`

胜利流程：
1. 检测所有敌人击败
2. 战斗状态 → VICTORY
3. 等待击败动画完成 (最多0.5s)
4. 触发掉落结算
5. 战斗状态 → DROP_RESOLUTION
6. 显示掉落面板
7. 战斗状态 → COMPLETE

---

**Rule 5: Skip Combat Mechanism**

玩家可选择跳过战斗，快速结算。

**跳过触发**: 点击"跳过"按钮 → 立即进入快速结算模式

**快速结算流程**:
| Step | Action | Timing |
|------|--------|--------|
| 1 | 暂停tick计时器 | 即时 |
| 2 | 所有敌人HP设为0 | 即时 |
| 3 | 所有敌人状态 → DEFEATED | 即时 |
| 4 | 播放简化击败动画 | 0.3s (压缩版) |
| 5 | 触发掉落结算 | 即时 |
| 6 | 显示掉落面板 | 即时 |

**跳过无惩罚**: 跳过不影响掉落结果、不影响进度记录。跳过仅压缩视觉展示时间。

---

**Rule 6: Combat Timer Management**

战斗使用 Timer节点驱动tick。

**Timer配置**:
```gdscript
var combat_timer: Timer
combat_timer.wait_time = 1.0 / HITS_PER_SECOND  # 0.5秒
combat_timer.one_shot = false  # 循环触发
combat_timer.autostart = true  # 战斗开始自动启动
```

**Timer事件**:
```gdscript
func _on_combat_timer_timeout():
    if combat_state != CombatState.IN_PROGRESS:
        return
    var damage = calculate_damage()
    var target = select_next_target()
    apply_damage_to_enemy(target, damage)
```

---

**Rule 7: Query Interface**

`CombatSystem` 提供以下接口：

| Method | Return | Purpose |
|--------|--------|---------|
| `start_combat(floor_id)` | void | 启动层级战斗 |
| `get_combat_state()` | CombatState | 返回当前战斗状态 |
| `get_remaining_enemies()` | int | 返回存活敌人数量 |
| `skip_combat()` | void | 触发跳过结算 |
| `is_combat_complete()` | bool | 检查战斗是否完成 |

---

### States and Transitions

**Combat System States**:

| State | Description | Entry Condition | Exit Condition |
|-------|-------------|-----------------|----------------|
| **Idle** | 无战斗，等待进入 | 战斗完成 | 玩家进入层级 |
| **Spawning** | 敌人入场动画播放 | `start_combat()` | 入场动画完成 (0.3s × N enemies) |
| **InProgress** | 战斗tick进行中 | 敌人入场完成 | 所有敌人击败 或 玩家跳过 |
| **Victory** | 战斗胜利，等待动画 | 所有敌人击败 | 击败动画完成 |
| **DropResolution** | 掉落结算展示 | 胜利动画完成 | 掉落面板关闭 |
| **Complete** | 战斗完成 | 掉落面板关闭 | 无（返回Idle等待下一层） |

**State Transition Diagram**:

```
Idle → Spawning (start_combat)
Spawning → InProgress (spawn animations complete)
InProgress → Victory (all enemies defeated) OR SkipCombat (player clicks skip)
SkipCombat → DropResolution (instant settlement)
Victory → DropResolution (defeat animations complete)
DropResolution → Complete (drop panel closed)
Complete → Idle (ready for next floor)
```

---

### Interactions with Other Systems

| System | Data Flow | Interface Owner |
|--------|-----------|-----------------|
| **敌人系统** (Upstream) | EnemyInstance → current_health, attack, defense | CombatSystem calls `damage_enemy()`, receives `enemy_defeated` signal |
| **物品数据库** (Upstream) | Equipment → attack/defense stats | CombatSystem calls `calculate_enhanced_attack/defense()` |
| **存档系统** (Upstream) | Equipment slots → equipped item IDs + enhancement levels | CombatSystem queries slot assignments |
| **视觉反馈系统** (Downstream) | Damage event → number splash, particles | VisualFeedbackSystem receives `damage_applied`, `enemy_defeated` signals |
| **粒子系统** (Downstream) | Defeat event → particle burst | ParticleSystem spawns based on `enemy_rarity` |
| **掉落表系统** (Downstream) | Combat victory → drop resolution | DropTableSystem receives `combat_victory` signal (Post-MVP) |
| **装备掉落系统** (Downstream) | Victory → drop panel display | EquipmentDropSystem receives `combat_complete` signal |
| **地牢推进系统** (Downstream) | Combat complete → floor unlock | DungeonPushSystem receives `combat_complete` signal |

## Formulas

### Formula 1: Damage per Tick

The damage per tick formula is defined as:

`damage_per_tick = floor(player_attack * ATTACK_VARIANCE_FACTOR * random_range(0.9, 1.1))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| player_attack | `pa` | int | 10–1000 | 玩家总攻击力（装备攻击力之和） |
| ATTACK_VARIANCE_FACTOR | `avf` | float | 1.0 | 基础伤害系数（常量） |
| random_range | `rr` | float | 0.9–1.1 | 随机波动范围 |
| damage_per_tick | `dpt` | int | 9–1100 | 每tick伤害值 |

**Output Range:** player_attack × 0.9 to player_attack × 1.1

**Example:** 玩家攻击力100:
```
dpt = floor(100 * 1.0 * random_range(0.9, 1.1))
    = floor(100 * 0.93)  # 假设随机值为0.93
    = 93
```

---

### Formula 2: Combat Duration Estimation

估算战斗持续时间（用于离线收益计算）。

`combat_duration = sum(enemy.max_health for enemy in enemies) / (player_attack * HITS_PER_SECOND)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| enemy.max_health | `ehp` | int | 50–500 per enemy | 单敌人最大生命值 |
| player_attack | `pa` | int | 10–1000 | 玩家攻击力 |
| HITS_PER_SECOND | `hps` | float | 2.0 (registry) | 每秒攻击次数 |
| combat_duration | `cd` | float | 2.5–50 | 战斗时长（秒） |

**Output Range:** Single enemy (50HP): ~2.5s at attack=100; Multiple enemies (4 × 500HP): ~50s at attack=100

**Example:** 第5层2敌人（HP各250），玩家攻击力100:
```
cd = (250 + 250) / (100 * 2.0) = 500 / 200 = 2.5秒
```

---

### Formula 3: Tick Interval

计算攻击tick的时间间隔。

`tick_interval = 1.0 / HITS_PER_SECOND`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| HITS_PER_SECOND | `hps` | float | 2.0 (registry) | 每秒攻击次数 |
| tick_interval | `ti` | float | 0.5秒 | 每tick时间间隔 |

**Output:** 0.5秒

---

### Formula 4: Expected Ticks per Enemy

估算击败单个敌人所需的攻击次数。

`expected_ticks = floor(enemy.max_health / damage_per_tick)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| enemy.max_health | `ehp` | int | 50–500 | 敌人最大生命值 |
| damage_per_tick | `dpt` | int | 9–1100 | 每tick伤害值 |
| expected_ticks | `et` | int | 1–55 | 预计攻击次数 |

**Example:** Slime (HP=50), 玩家攻击力100:
```
et = floor(50 / 93) = floor(0.54) = 1  # 一次攻击击败
```

## Edge Cases

### Edge Case 1: Zero Player Attack

**Scenario**: 玩家未装备任何武器或装备攻击力为0。

**Expected Behavior**:
- damage_per_tick = 0
- 战斗无法进行，敌人HP不下降
- 显示"无法战斗"提示，建议玩家装备武器
- 玩家可跳过战斗，但仍无法击败敌人（需装备才能推进）

**Test**: 无装备 → 验证战斗显示提示，跳过无法推进。

---

### Edge Case 2: Skip Combat During Spawning

**Scenario**: 玩家在敌人入场动画期间点击跳过。

**Expected Behavior**:
- 立即中断入场动画
- 敌人状态直接设为 DEFEATED
- 进入快速结算流程
- 播放压缩版击败动画（0.3s）

**Test**: 入场动画期间点击跳过 → 验证立即结算。

---

### Edge Case 3: All Enemies Defeated Simultaneously

**Scenario**: 高伤害玩家一次攻击击败多个敌人。

**Expected Behavior**:
- 按目标顺序逐个应用伤害
- 每个敌人HP归零后 → 状态 DEFEATED
- 继续攻击下一个存活敌人
- 所有敌人击败后 → Victory状态

**Test**: 玩家攻击1000，敌人HP各50 → 验证逐个击败。

---

### Edge Case 4: Combat Timer Paused Unexpectedly

**Scenario**: Timer因系统事件暂停（如应用切后台）。

**Expected Behavior**:
- 战斗计时器暂停
- 敌人HP状态保持不变
- 应用恢复前台时，Timer恢复
- 战斗继续正常进行

**Test**: 战斗中途切后台 → 验证恢复后战斗继续。

---

### Edge Case 5: Damage Applied to Defeated Enemy

**Scenario**: 敌人已进入DEFEATED状态，但伤害仍被应用。

**Expected Behavior**:
- 仅对 ALIVE 状态敌人应用伤害
- DEFEATED敌人忽略伤害
- 不触发额外击败事件

**Test**: 敌人击败后，验证不再接受伤害。

---

### Edge Case 6: Skip Button Pressed Multiple Times

**Scenario**: 玩家快速多次点击跳过按钮。

**Expected Behavior**:
- 第一次点击触发跳过流程
- 后续点击被忽略（按钮禁用）
- 防止重复结算

**Test**: 快速点击跳过多次 → 验证仅结算一次。

---

### Edge Case 7: Combat Duration Exceeds Expected

**Scenario**: 战斗持续时间超过预期（低攻击力vs高HP敌人）。

**Expected Behavior**:
- 战斗正常进行，直到胜利
- 不设置战斗超时上限（MVP阶段允许长战斗）
- 玩家可选择跳过快速结束

**Test**: 攻击力10 vs 敌人HP500 → 验证战斗可进行至胜利（或跳过）。

## Dependencies

### Upstream Dependencies (本系统依赖)

| System | Type | Interface | Notes |
|--------|------|-----------|-------|
| **敌人系统** | Hard | `spawn_enemies_for_floor()`, `damage_enemy()`, `is_enemy_defeated()` | 提供敌人实例和HP管理接口 |
| **物品数据库** | Hard | `calculate_enhanced_attack()`, `calculate_enhanced_defense()` | 提供装备攻击力/防御力计算 |
| **存档系统** | Soft | Equipment slots query | 提供装备槽配置（实际由装备槽系统管理） |

**Constraint from 敌人系统 GDD**:
- 敌人实例有 `current_health`, `max_health`, `attack`, `defense`, `state`
- 敌人状态转换: SPAWNING (0.3s) → ALIVE → DEFEATED (0.5s)
- 击败触发 `enemy_defeated` 信号

**Constraint from 物品数据库 GDD**:
- `calculate_enhanced_attack(id, level)` 返回强化后攻击力
- `calculate_enhanced_defense(id, level)` 返回强化后防御力
- `ENHANCEMENT_ATTACK_MULTIPLIER` = 0.1

---

### Downstream Dependencies (依赖本系统)

| System | Type | Interface Used | Notes |
|--------|------|---------------|-------|
| **视觉反馈系统** | Hard | `damage_applied` signal, `enemy_defeated` signal | 触发伤害数字飞溅、击败粒子 |
| **粒子系统** | Soft | Enemy defeat position, rarity | 生成击败粒子效果 |
| **掉落表系统** | Soft | `combat_victory` signal | 战斗胜利后触发掉落解析 |
| **装备掉落系统** | Hard | `combat_complete` signal | 掉落面板展示触发 |
| **地牢推进系统** | Hard | `is_combat_complete()` | 战斗完成后推进解锁 |
| **收益计算系统** | Soft | `combat_duration` | 离线收益计算需要战斗时长 |
| **音效系统** | Soft | `damage_applied`, `enemy_defeated` | 播放战斗音效（Post-MVP） |

---

### External Dependencies (非游戏系统)

| Dependency | Type | Usage |
|------------|------|-------|
| **Godot Timer** | Hard | 战斗tick驱动 |
| **Godot Signal** | Hard | 事件传播（damage_applied, enemy_defeated, combat_complete） |
| **Godot Tween** | Soft | 伤害数字动画（通过视觉反馈系统） |

## Tuning Knobs

| Knob | Default | Safe Range | Unit | What It Affects | Extreme Behavior |
|------|---------|------------|------|-----------------|------------------|
| **HITS_PER_SECOND** | 2.0 (registry) | 1.0–4.0 | hits/sec | 战斗速度，每秒攻击次数 | 太低：战斗拖沓；太高：战斗太快，视觉反馈来不及 |
| **ATTACK_VARIANCE_FACTOR** | 1.0 | 0.8–1.5 | ratio | 基础伤害系数 | 太低：伤害过低，战斗过长；太高：伤害过高，战斗太短 |
| **RANDOM_DAMAGE_MIN** | 0.9 | 0.8–1.0 | ratio | 伤害随机波动下限 | 太低：伤害不稳定，难以预测战斗时长 |
| **RANDOM_DAMAGE_MAX** | 1.1 | 1.0–1.3 | ratio | 伤害随机波动上限 | 太高：伤害波动大，视觉体验不稳定 |
| **SKIP_ANIMATION_DURATION** | 0.3 | 0.1–0.5 | seconds | 跳过战斗压缩动画时长 | 太短：无视觉反馈；太长：跳过体验拖沓 |
| **VICTORY_DELAY** | 0.5 | 0.3–1.0 | seconds | 胜利后等待动画完成时间 | 太短：击败动画被截断；太长：胜利反馈拖沓 |

### Knob Configuration File

All knobs are defined in `assets/data/tuning/combat_config.json`:

```json
{
  "version": "1.0.0",
  "attack": {
    "variance_factor": 1.0,
    "random_min": 0.9,
    "random_max": 1.1
  },
  "timing": {
    "hits_per_second": 2.0
  },
  "skip": {
    "animation_duration": 0.3
  },
  "victory": {
    "delay": 0.5
  }
}
```

## Visual/Audio Requirements

### Visual Requirements

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| **伤害数字飞溅** | 每次tick伤害时显示 `-N` 数字，字体大小随伤害值变化（大伤害=大字体） | 通过视觉反馈系统实现 |
| **敌人HP条动画** | HP下降时HP条平滑缩短，而非跳跃式变化 | 使用 Tween 实现平滑过渡 |
| **击败闪光效果** | 敌人击败时短暂闪光（白色叠加）后缩小消失 | 0.3秒闪光 + 0.2秒缩小 |
| **胜利庆祝动画** | 所有敌人击败后，屏幕边缘金色粒子喷射 | 1秒粒子效果 |
| **跳过战斗简化** | 跳过时无逐个击败动画，直接显示总伤害数字和胜利提示 | 压缩视觉反馈 |

### Audio Requirements

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| **战斗音效** | Post-MVP（音效系统负责） | MVP阶段无声效 |
| **击败音效** | Post-MVP | MVP阶段无声效 |
| **胜利音效** | Post-MVP | MVP阶段无声效 |

## UI Requirements

| Requirement | Specification | Priority |
|-------------|---------------|----------|
| **跳过按钮** | 战斗进行中显示"跳过"按钮，点击触发快速结算 | MVP |
| **敌人HP条** | 每个敌人显示当前HP/最大HP的进度条 | MVP |
| **战斗进度显示** | 显示 "Enemies: N/M"（存活/总数） | MVP |
| **战斗时长显示** | 可选：显示战斗已进行时间（秒） | Post-MVP |
| **胜利提示** | 战斗胜利时显示"Victory!"文字 | MVP |

## Acceptance Criteria

### Combat Initiation Criteria

- **GIVEN** 玩家进入第1层，**WHEN** `start_combat(1)` 调用，**THEN** 敌人生成，战斗进入 Spawning 状态，入场动画播放。
- **GIVEN** 玩家装备Iron Blade +0 (attack=10)，**WHEN** 战斗开始，**THEN** `player_attack = 10`。

---

### Damage Application Criteria

- **GIVEN** 玩家攻击力100，HITS_PER_SECOND=2.0，**WHEN** 战斗进行中，**THEN** 每0.5秒触发一次攻击tick。
- **GIVEN** 敌人HP=50，玩家攻击力100，**WHEN** 伤害应用 `damage=93`（随机），**THEN** `enemy.current_health = max(0, 50-93) = 0`，敌人进入 DEFEATED 状态。
- **GIVEN** 敌人 ALIVE 状态，**WHEN** HP归零，**THEN** 触发 `enemy_defeated` 信号，携带 `{enemy_id, rarity, position}`。

---

### Combat Victory Criteria

- **GIVEN** 战斗中有3敌人，2已击败，1存活，**WHEN** 第3敌人击败，**THEN** 战斗状态 → VICTORY。
- **GIVEN** 战斗胜利，**WHEN** 击败动画完成 (0.5s)，**THEN** 触发掉落结算，状态 → DROP_RESOLUTION。

---

### Skip Combat Criteria

- **GIVEN** 战斗进行中，敌人HP各250，**WHEN** 玩家点击跳过按钮，**THEN** 所有敌人HP设为0，状态 DEFEATED，战斗状态 → DropResolution。
- **GIVEN** 跳过战斗，**WHEN** 结算完成，**THEN** 跳过按钮禁用，无法再次点击。
- **GIVEN** 敌人入场动画期间，**WHEN** 玩家点击跳过，**THEN** 入场动画中断，直接进入快速结算。

---

### Timer Management Criteria

- **GIVEN** 战斗进行中，**WHEN** Timer timeout触发，**THEN** 计算伤害，选择目标，应用伤害。
- **GIVEN** 战斗中途应用切后台，**WHEN** 应用恢复前台，**THEN** Timer恢复，战斗继续。

---

### UI Criteria

- **GIVEN** 战斗进行中，**WHEN** 显示UI，**THEN** 跳过按钮可见可点击，敌人HP条显示，战斗进度显示 "Enemies: N/M"。
- **GIVEN** 战斗胜利，**WHEN** 显示UI，**THEN** 显示 "Victory!" 文字，掉落面板弹出。

## Open Questions

| Question | Owner | Target Resolution | Status |
|----------|-------|-------------------|--------|
| **跳过战斗是否需要动画过渡？** | UX Designer | 原型验证时 | Open — MVP可能简化为直接结算 |
| **是否需要战斗失败机制？** | Game Designer | MVP后评估 | Open — 当前设计无失败（玩家必胜），如需挑战感可考虑"逃跑失败" |
| **是否需要战斗速度调节（慢速/正常/快速）？** | UX Designer | Post-MVP | Open — 增加参与深度控制 |
| **是否需要大招/技能系统？** | Game Designer | Post-MVP | Open — 增加战斗主动参与 |
| **跳过按钮位置是否固定？** | UI Designer | UI设计时 | Open — 需UX spec定义位置 |
| **伤害数字是否需要颜色变化（暴击金色/普通白色）？** | Art Director | 原型验证时 | Open — 增加视觉区分 |