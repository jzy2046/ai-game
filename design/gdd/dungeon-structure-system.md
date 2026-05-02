# 地牢结构系统

> **Status**: Designed
> **Author**: [user + agents]
> **Last Updated**: 2026-05-01
> **Implements Pillar**: 爽感反馈、稳定成长、掌控节奏

## Overview

地牢结构系统是游戏的核心数据层，定义地牢的层级结构、每层属性（敌人配置、掉落规则、解锁条件）、以及层级间的依赖关系。它为地牢推进系统、战斗系统、敌人系统提供静态配置数据，同时与存档系统交互记录玩家的进度状态。

**数据结构定义**：
- **Floor**: 地牢的最小单位，每层有唯一ID、敌人类型配置、推荐战力、掉落权重表
- **Floor Group**: 多层组成一个区域，区域有主题和视觉风格
- **Unlock Rule**: 层级解锁条件（战力门槛、前置层级完成）

**玩家体验**：虽然玩家不直接与"数据结构"交互，但每次推进新层级、每次面对更强的敌人、每次期待更好的掉落，都源于这个系统定义的规则。玩家感受到的是"探索的节奏感" — 第一层熟悉敌人、第二层挑战更强对手、第五层期待稀有装备。

**技术边界**：本GDD定义数据结构和规则。具体的 Godot Resource 配置、场景组织属于架构决策，将在ADR中记录。

**ADR状态**：当前没有地牢架构ADR。建议GDD完成后运行 `/architecture-decision` 创建 "Dungeon Data Architecture" 记录 Godot 实现方案。

## Player Fantasy

地牢层级是玩家成长的刻度尺。第一层是新手体验，第三层是第一次挑战，第五层是真正考验。玩家通过层级推进节奏感受到自己的进步：曾经困难的敌人现在轻松击败，曾经遥不可及的层级现在触手可及。

这种感觉服务于支柱"稳定成长" — 每一层推进都是可见的进步，没有失败风险，只需要数值足够。地牢结构创造了一种"我比昨天更强"的可视化证据：昨天卡在第三层，今天轻松推进到第五层，这种进步感让玩家持续投入。

**参考时刻**: 暗黑破坏神中玩家第一次进入新区域的期待感 — 不知道会遇到什么，但知道自己的装备足够应对。这种"准备充分的探索"是目标体验。

## Detailed Design

### Core Rules

**1. Floor Definition (层级定义)**

| Attribute | Type | Description |
|-----------|------|-------------|
| `floor_id` | int | 层级唯一标识 (1-based) |
| `floor_name` | string | 显示名称 (如 "第一层 - 新手洞穴") |
| `recommended_power` | int | 推荐战力值（玩家数值的参考门槛） |
| `enemy_types` | array[enemy_id] | 本层可能出现的敌人类型 |
| `enemy_count` | int | 本层敌人数量 (固定或范围) |
| `drop_table_id` | string | 本层使用的掉落表ID |
| `visual_theme` | string | 视觉主题 (如 "cave", "forest") |
| `bgm_id` | string | 本层背景音乐ID (Post-MVP) |

**2. Floor Group (区域划分)**

MVP阶段简化为单一地牢，但数据结构预留区域扩展：

| Attribute | Type | Description |
|-----------|------|-------------|
| `group_id` | string | 区域唯一标识 (如 "beginner_cave") |
| `group_name` | string | 区域显示名称 |
| `floors` | array[floor_id] | 区域包含的层级ID列表 |
| `theme` | string | 区域主题 (视觉风格) |
| `unlock_condition` | condition | 区域解锁条件 |

**MVP区域配置**: 
- 区域1: "新手洞穴" — 层级 1-10
- 单一区域，无区域解锁条件

**3. Unlock Rules (解锁规则)**

| Rule ID | Condition | Effect |
|---------|-----------|--------|
| UNLOCK-01 | `player_power >= floor.recommended_power` | 可以进入该层（战力门槛） |
| UNLOCK-02 | `current_floor = N` 完成后 | `highest_floor = max(highest_floor, N+1)` |
| UNLOCK-03 | `highest_floor` 更新时 | 自动解锁 `highest_floor` 层 |

**Unlock Sequence**:
1. 玩家初始状态: `current_floor = 1`, `highest_floor = 1`, `unlocked_floors = [1]`
2. 完成第1层 → `highest_floor = 2`, `unlocked_floors = [1, 2]`
3. 完成第2层 → `highest_floor = 3`, `unlocked_floors = [1, 2, 3]`
4. 若玩家跳过战斗快速推进，仍需满足战力门槛才能进入下一层

**4. Floor Completion (层级完成)**

| Rule ID | Condition | Effect |
|---------|-----------|--------|
| COMP-01 | 战斗胜利 + 所有敌人击败 | 层级完成，触发掉落结算 |
| COMP-02 | 层级完成时 | `current_floor` 可推进至下一层 |
| COMP-03 | 层级完成时 | 触发存档系统的 `dungeon floor unlock` critical save |

### States and Transitions

**Floor States**:

| State | Description | Entry Condition | Exit Condition |
|-------|-------------|-----------------|----------------|
| **Locked** | 未解锁，玩家无法进入 | 初始状态，或未满足解锁条件 | 满足 UNLOCK-01 或 UNLOCK-03 |
| **Unlocked** | 已解锁，可进入但未完成 | 满足解锁条件 | 玩家选择进入该层 |
| **InProgress** | 玩家当前正在挑战 | 玩家进入该层开始战斗 | 战斗胜利或失败(不存在) |
| **Completed** | 已完成，可以重刷 | 战斗胜利，掉落结算完成 | 无退出（永久状态） |

**Player Progression States**:

| State | Description | `current_floor` | `highest_floor` |
|-------|-------------|-----------------|-----------------|
| **NewPlayer** | 新玩家状态 | 1 | 1 |
| **Progressing** | 正常推进中 | N (N ≤ highest_floor) | N |
| **Pushing** | 推进新层级 | highest_floor + 1 | 最高+1 (完成后) |
| **Revisiting** | 重刷已完成层级 | M (M < highest_floor) | 不变 |

**State Transition Diagram**:

```
NewPlayer → Progressing (完成第1层)
Progressing → Pushing (选择推进下一层)
Pushing → Progressing (完成新层级)
Progressing → Revisiting (选择返回低层)
Revisiting → Progressing (返回推进)
```

### Interactions with Other Systems

| System | Data Flow | Interface Owner |
|--------|-----------|-----------------|
| **存档系统** | Floor progress (current, highest, unlocked) → Save | DungeonSystem calls `SaveManager.save_dungeon_progress()` |
| **敌人系统** | Floor → enemy_types → Enemy spawn | DungeonSystem provides enemy config; EnemySystem spawns |
| **战斗系统** | Floor → recommended_power → Battle balance | DungeonSystem provides floor data; CombatSystem validates entry |
| **掉落表系统** | Floor → drop_table_id → Drop calculation | DungeonSystem provides drop table ID; DropTableSystem resolves |
| **地牢推进系统** | Player action → Floor transition | DungeonSystem validates transition; PushSystem executes |
| **离线收益系统** | highest_floor → offline farming target | DungeonSystem provides target floor; OfflineSystem calculates |

**接口规范** (定义给下游系统使用):
- `get_floor_data(floor_id: int) → FloorData` 返回指定层级的完整数据
- `get_current_floor() → int` 返回玩家当前所在层级
- `get_highest_floor() → int` 返回玩家最高解锁层级
- `get_unlocked_floors() → array[int]` 返回已解锁层级列表
- `can_enter_floor(floor_id: int) → bool` 检查玩家是否可进入该层
- `complete_floor(floor_id: int) → void` 标记层级完成，更新进度
- `set_current_floor(floor_id: int) → void` 设置当前层级（推进或返回）

## Formulas

**1. Recommended Power Scaling**

层级推荐战力按线性增长，确保玩家有清晰的战力目标。

`recommended_power(floor_id) = base_power + (floor_id - 1) * power_increment`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| floor_id | `f` | int | 1–10 | 层级ID |
| base_power | `bp` | int | 100 | 第1层基准战力（常量） |
| power_increment | `pi` | int | 50 | 每层战力增量（常量） |
| recommended_power | `rp` | int | 100–550 | 层级推荐战力 |

**Output Range:** 100 (第1层) to 550 (第10层)
**Example:** 第5层: `rp = 100 + (5-1) * 50 = 100 + 200 = 300`

---

**2. Enemy Count Scaling**

层级敌人数量按阶梯增长，初期简单后期挑战。

`enemy_count(floor_id) = base_count + floor((floor_id - 1) / count_step) * count_increment`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| floor_id | `f` | int | 1–10 | 层级ID |
| base_count | `bc` | int | 1 | 第1层敌人数量（常量） |
| count_step | `cs` | int | 3 | 每3层增加敌人数量（常量） |
| count_increment | `ci` | int | 1 | 每阶梯增加敌人数量（常量） |
| enemy_count | `ec` | int | 1–4 | 层级敌人数量 |

**Output Range:** 1 (层1-3) → 2 (层4-6) → 3 (层7-9) → 4 (层10)
**Example:** 第8层: `ec = 1 + floor(7/3) * 1 = 1 + 2 = 3`

---

**3. Floor Completion Time Estimate**

估算每层完成时间（用于离线收益计算）。

`estimated_completion_time(floor_id) = base_time + enemy_count(floor_id) * per_enemy_time`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| floor_id | `f` | int | 1–10 | 层级ID |
| base_time | `bt` | float | 2.0 | 基础时间（入场+结算）秒 |
| per_enemy_time | `pet` | float | 5.0 | 每敌人平均战斗时间秒 |
| estimated_completion_time | `ect` | float | 7–22 | 层级完成时间秒 |

**Output Range:** 7秒 (第1层) to 22秒 (第10层)
**Example:** 第5层 (2敌人): `ect = 2.0 + 2 * 5.0 = 12秒`

## Edge Cases

**1. Progress State Edge Cases**

- **If 玩家战力不足以进入下一层**: 显示"战力不足"提示，不能进入。玩家需要强化装备提升战力后才能推进。
- **If 玩家选择跳过战斗但战力不足**: 跳过功能仍可用（游戏允许跳过），但战后结算时不会推进到下一层。玩家仍停留在当前层。
- **If 玩家在第10层完成**: 无法推进到第11层（MVP只有10层）。显示"已到达地牢深处"提示，可选择重刷任意已解锁层。

**2. Save Data Edge Cases**

- **If 存档数据 `current_floor` > `highest_floor`**: 异常状态，修正为 `current_floor = highest_floor`。这是存档损坏或旧版本迁移的情况。
- **If 存档数据 `unlocked_floors` 缺失层级**: 异常状态，修正为 `unlocked_floors = [1...highest_floor]`（补齐缺失）。
- **If 存档数据 `highest_floor` > 10**: 异常状态，修正为 `highest_floor = 10`（MVP上限）。

**3. Floor Selection Edge Cases**

- **If 玩家选择返回已完成的低层**: 正常流程，`current_floor` 设置为目标层，敌人配置使用该层原始配置。
- **If 玩家选择未解锁的高层**: UI 不应显示未解锁层级选项。若通过异常手段请求，返回 `can_enter_floor = false`。
- **If 玩家连续快速点击推进**: 每次推进需等待当前层战斗完成。快速点击不会跳过战斗，排队等待当前战斗结束。

**4. Enemy Configuration Edge Cases**

- **If 层级 `enemy_types` 配置为空**: 异常配置，使用 fallback 配置（默认敌人类型）。
- **If 层级 `enemy_count` 配置为 0**: 异常配置，修正为 `enemy_count = 1`（至少1敌人）。
- **If 层级 `drop_table_id` 缺失**: 使用 fallback 掉落表（默认基础掉落）。

**5. Offline Farming Edge Cases**

- **If 离线挂机目标层未解锁**: 自动降级到 `highest_floor` 层（最高解锁层）作为挂机目标。
- **If 离线挂机目标层 > 10**: 修正为 `target_floor = 10`（MVP上限）。

## Dependencies

**Upstream Dependencies (本系统依赖)**

| System | Type | Interface | Notes |
|--------|------|-----------|-------|
| **存档系统** | Hard | `SaveManager.save_dungeon_progress()` | 存档系统定义了 `dungeon.current_floor`, `dungeon.highest_floor`, `dungeon.unlocked_floors` 数据结构，本系统必须遵守 |

**Constraint from 存档系统 GDD**:
- 数据结构必须使用存档系统定义的字段名
- 层级解锁必须触发存档系统的 critical save (100ms 内)

**Downstream Dependencies (依赖本系统)**

| System | Type | Interface Used | Notes |
|--------|------|---------------|-------|
| **敌人系统** | Hard | `get_floor_data(floor_id).enemy_types` | 敌人系统根据层级数据生成敌人 |
| **战斗系统** | Hard | `get_floor_data(floor_id).recommended_power` | 战斗系统检查战力门槛 |
| **掉落表系统** | Hard | `get_floor_data(floor_id).drop_table_id` | 掉落表系统根据层级ID计算掉落 |
| **地牢推进系统** | Hard | `can_enter_floor()`, `complete_floor()`, `set_current_floor()` | 推进系统调用本系统接口执行推进逻辑 |
| **离线收益系统** | Hard | `get_highest_floor()`, `estimated_completion_time()` | 离线系统计算挂机收益 |
| **装备掉落系统** | Soft | `get_floor_data(floor_id).drop_table_id` | 装备掉落通过掉落表系统间接关联 |

**External Dependencies (非游戏系统)**

| Dependency | Type | Usage |
|------------|------|-------|
| **Godot Resource (.tres)** | Soft | 层级配置文件格式（可选，也可用 JSON） |
| **Godot JSON parsing** | Soft | 配置文件解析 |

## Tuning Knobs

| Knob | Default | Safe Range | Unit | What It Affects | Extreme Behavior |
|------|---------|------------|------|-----------------|------------------|
| **base_power** | 100 | 50–200 | 战力点 | 第1层基准战力，影响所有层级门槛 | 太低：玩家轻松推进，失去挑战感；太高：新手门槛过高，挫败感 |
| **power_increment** | 50 | 30–100 | 战力点 | 每层战力增量，决定推进节奏 | 太低：层级间差异不明显；太高：推进难度陡增，成长断层 |
| **max_floor_count** | 10 | 5–20 | 层级 | MVP地牢总层数 | 太少：内容不足；太多：MVP时间预算超出 |
| **count_step** | 3 | 2–5 | 层级 | 敌人数量增加的阶梯间隔 | 太少：敌人数量快速增长；太多：高层敌人数量变化不明显 |
| **count_increment** | 1 | 1–2 | 敌人 | 每阶梯增加敌人数量 | 太高：战斗时间过长；太低：高层挑战感不足 |
| **base_time** | 2.0 | 1.0–5.0 | 秒 | 层级完成基础时间（入场+结算） | 太低：结算动画被压缩；太高：流程拖沓 |
| **per_enemy_time** | 5.0 | 3.0–10.0 | 秒 | 每敌人平均战斗时间 | 太低：战斗节奏太快；太高：离线收益估算偏低 |

## Visual/Audio Requirements

**Visual Requirements**

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| **层级背景主题** | 每个区域（Floor Group）有统一视觉风格 | MVP单一区域"新手洞穴"使用暖色洞穴背景 |
| **层级标识显示** | 层级进入时显示 `floor_name` 文字 | 字体遵循 Art Bible 圆润风格 |
| **层级推进动画** | 进入新层级时短动画过渡 | 0.3s fade-in + 0.1s floor number popup |
| **完成动画** | 层级完成时显示"Floor N Complete" | 粒子效果由粒子系统负责 |

**Audio Requirements**

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| None | 地牢结构系统不直接产生音效 | 层级战斗BGM由敌人/战斗系统负责 |

## UI Requirements

| Requirement | Specification | Priority |
|-------------|---------------|----------|
| **层级选择界面** | 显示已解锁层级列表，可选择返回任意已解锁层 | MVP |
| **当前层级显示** | HUD显示 `current_floor` 和 `highest_floor` | MVP |
| **战力门槛提示** | 进入未满足战力门槛层级时显示"战力不足" | MVP |
| **推进按钮状态** | 推进按钮根据 `can_enter_floor(next_floor)` 显示可用/禁用 | MVP |
| **层级进度条** | 可选：显示进度百分比 `current_floor / max_floor_count` | Post-MVP |

**下游系统 UI 约束**:
- 地牢推进系统必须使用 `can_enter_floor()` 验证推进按钮状态
- 离线收益系统显示挂机目标层时需调用 `get_highest_floor()`

## Acceptance Criteria

**Progress State Criteria**

- **GIVEN** 新玩家启动游戏，**WHEN** 初始化地牢系统，**THEN** `current_floor = 1`, `highest_floor = 1`, `unlocked_floors = [1]`。
- **GIVEN** 玩家战力 300，**WHEN** 检查第5层进入条件，**THEN** `recommended_power(5) = 300`，`can_enter_floor(5) = true`。
- **GIVEN** 玩家战力 250，**WHEN** 检查第5层进入条件，**THEN** `can_enter_floor(5) = false`（战力门槛不足）。

**Floor Completion Criteria**

- **GIVEN** 玩家在第3层战斗胜利，**WHEN** `complete_floor(3)` 被调用，**THEN** `highest_floor = 4`, `unlocked_floors = [1, 2, 3, 4]`, 存档系统触发 critical save。
- **GIVEN** 玩家在第10层战斗胜利，**WHEN** `complete_floor(10)` 被调用，**THEN** `highest_floor = 10`, 无第11层解锁，显示"已到达地牢深处"。

**Floor Selection Criteria**

- **GIVEN** 玩家当前在第5层，highest_floor = 8，**WHEN** 选择返回第3层，**THEN** `set_current_floor(3)` 成功，`current_floor = 3`, `highest_floor` 不变。
- **GIVEN** 玩家最高解锁第5层，**WHEN** 尝试进入第7层，**THEN** `can_enter_floor(7) = false`，UI不显示第7层选项。

**Enemy Configuration Criteria**

- **GIVEN** 第8层配置，**WHEN** 调用 `get_floor_data(8)`，**THEN** `enemy_count = 3`（层7-9阶梯），`recommended_power = 450`。
- **GIVEN** 第1层配置，**WHEN** 调用 `get_floor_data(1)`，**THEN** `enemy_count = 1`, `recommended_power = 100`。

**Save Data Integrity Criteria**

- **GIVEN** 存档数据 `current_floor = 5`, `highest_floor = 3`（异常），**WHEN** 系统加载存档，**THEN** 修正为 `current_floor = 3`, 记录异常日志。
- **GIVEN** 存档数据 `unlocked_floors = [1, 3, 5]`（缺失层级），**WHEN** 系统加载存档，**THEN** 修正为 `unlocked_floors = [1, 2, 3, 4, 5]`。

**Interface Integration Criteria**

- **GIVEN** 敌人系统请求第5层敌人配置，**WHEN** 调用 `get_floor_data(5).enemy_types`，**THEN** 返回敌人类型列表，敌人系统正确生成敌人。
- **GIVEN** 离线收益系统计算挂机收益，**WHEN** 调用 `get_highest_floor()` 和 `estimated_completion_time(floor_id)`，**THEN** 返回最高解锁层和预估完成时间，离线收益正确计算。

## Open Questions

| Question | Owner | Target Resolution | Status |
|----------|-------|-------------------|--------|
| **层级间是否有过渡房间？** | Level Designer | 原型验证时 | Open — MVP可能简化为直接推进 |
| **第10层完成后是否显示"通关"仪式？** | Game Designer | MVP后评估 | Open — MVP阶段可能简化 |
| **是否需要层级"首次奖励"（首次完成额外掉落）？** | Economy Designer | MVP后评估 | Open — 增加推进吸引力 |
| **是否需要层级间强制休息点？** | UX Designer | 原型验证时 | Open — 防止玩家推进太快失去兴趣 |