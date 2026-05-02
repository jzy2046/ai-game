# 地牢推进系统

> **Status**: Designed
> **Author**: User + agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: 爽感反馈, 掌控节奏, 稳定成长

## Overview

地牢推进系统是核心循环的流程编排层，协调玩家从"点击进入下一层"到"战斗胜利并解锁下一层"的完整链路。当玩家点击推进按钮时，本系统检查是否满足进入条件（战力达标、当前层已完成），触发战斗系统执行自动战斗（玩家可选跳过），监听战斗胜利信号后调用地牢结构系统完成当前层并解锁下一层。玩家通过本系统主动推进地牢深度，每次推进都是一次"期待→战斗→收获→解锁"的微循环，服务于"掌控节奏"支柱——玩家决定何时推进、是否跳过战斗、如何把控进度。

## Player Fantasy

**核心幻想**: "我主动推进，我掌控进度" — 每次点击推进都是玩家的主动选择，而非被动等待。

**情绪锚点**: 点击"下一层"按钮的那一刻。玩家在这一瞬间做出决定："我准备好了，我要看看下一层有什么"。这个点击不是机械操作，而是带有期待的主动行为——期待更强的敌人、期待更好的掉落、期待数值再一次暴涨。

**掌控感来源**:
- 玩家决定何时推进（不是自动推进）
- 玩家可以跳过战斗快速结算（不想看动画时）
- 玩家可以慢慢观看战斗过程（想享受过程时）
- 推进结果是确定的（战力达标就能进入，无失败风险）

**服务支柱**: 本系统直接服务"掌控节奏"支柱——推进速度由玩家决定，不是游戏强制。同时服务"稳定成长"支柱——每完成一层就是确定性的进步，不存在"推进失败"的概念。

## Detailed Design

### Core Rules

1. **触发条件**: 玩家点击"下一层"按钮触发推进请求。按钮仅当满足进入条件时可点击（不可点击时显示灰色并提示原因）。

2. **进入检查**: 收到推进请求后，系统检查:
   - `player_power >= recommended_power` (战力达标)
   - `current_floor.status == Completed` 或 `current_floor == 0` (首层无需前置)
   - 若不满足，显示提示并阻止推进，状态保持 Idle

3. **战斗触发**: 检查通过后，系统:
   - 调用 `dungeon_structure.set_current_floor(target_floor_id)`
   - 调用 `combat.start_combat(target_floor_id)`
   - 自身状态转入 `InCombat`

4. **战斗监听**: 系统订阅 `combat.combat_complete(floor_id, victory)` 信号，战斗结束时自动响应。

5. **胜利处理**: 收到 `combat_complete` 且 `victory == true`:
   - 调用 `dungeon_structure.complete_floor(floor_id)`
   - 若 `floor_id < max_floor_count`，调用 `dungeon_structure.unlock_floor(floor_id + 1)`
   - 触发掉落系统处理（由掉落系统监听 `floor_completed` 信号）
   - 状态转入 `ProcessingVictory`，0.5秒后转入 `Idle`

6. **跳过支持**: 战斗进行中玩家可点击"跳过"按钮:
   - 调用 `combat.skip_combat()`
   - 战斗系统立即结算并发出 `combat_complete` 信号
   - 本系统按规则5正常处理胜利

7. **阻塞处理**: 若战斗被中断（如玩家关闭游戏），系统状态保持 `InCombat`。下次启动时:
   - 检查存档中的 `current_floor` 和 `combat_state`
   - 若 `combat_state != Idle`，恢复战斗或自动结算（取决于存档策略）
   - 见存档系统边缘情况

8. **首层入口**: 玩家首次进入地牢时，`current_floor == 0`，允许直接进入第1层无需前置完成检查。

9. **最终层处理**: 当 `floor_id == max_floor_count` 且战斗胜利:
   - 调用 `complete_floor(floor_id)`
   - 不解锁下一层（无下一层）
   - 触发"地牢通关"事件（后续版本扩展，MVP仅记录完成）

### States and Transitions

| 当前状态 | 触发 | 下一状态 | 转换动作 |
|---------|------|---------|---------|
| Idle | 玩家点击推进按钮 | CheckingEntry | 无 |
| CheckingEntry | 检查失败 | Idle | 显示提示信息 |
| CheckingEntry | 检查通过 | InCombat | `set_current_floor()`, `start_combat()` |
| InCombat | `combat_complete(victory=true)` | ProcessingVictory | `complete_floor()`, `unlock_floor()` |
| InCombat | `combat_complete(victory=false)` | Idle | MVP无失败场景，预留 |
| InCombat | 玩家点击跳过 | InCombat | `skip_combat()` (状态不变，等待信号) |
| ProcessingVictory | 0.5秒定时器 | Idle | 清理UI，准备下一次推进 |
| Idle | 环境恢复信号 | CheckingEntry | 从存档恢复时的流程 |

### Interactions with Other Systems

**上游依赖**:

| 系统 | 数据流入 | 调用接口 | 信号订阅 |
|-----|---------|---------|---------|
| 地牢结构系统 | floor数据, recommended_power | `get_floor_data()`, `can_enter_floor()`, `set_current_floor()`, `complete_floor()`, `unlock_floor()` | 无 |
| 战斗系统 | combat_state | `start_combat()`, `skip_combat()` | `combat_complete(floor_id, victory)` |
| 敌人系统 | 间接（通过战斗系统） | 无直接调用 | 无 |

**下游依赖**:

| 系统 | 数据流出 | 发出信号 | 触发时机 |
|-----|---------|---------|---------|
| 装备掉落系统 | floor_id, victory | `floor_completed(floor_id)` | 战斗胜利后 |
| 收益计算系统 | floor_id, combat_duration | `floor_completed(floor_id)` | 战斗胜利后 |
| 视觉反馈系统 | floor_id, advancement_type | `floor_advanced(floor_id)` | 进入新楼层时 |
| 存档系统 | current_floor, advancement_state | 无（存档系统监听状态变化） | 状态转换时 |

**信号流向**:
- 本系统订阅: `combat_complete` (from Combat)
- 本系统发出: `floor_completed` (to Drop/Yield), `floor_advanced` (to Visual Feedback)

## Formulas

### F1: Recommended Power (引用地牢结构系统)

**公式**: `recommended_power = base_power + (floor_id - 1) * power_increment`

**变量定义**:
- `floor_id`: 目标楼层ID (1–10)
- `base_power`: 基础战力 = 100 (from registry)
- `power_increment`: 每层增量 = 50 (from registry)

**输出范围**: 100 (第1层) – 550 (第10层)

**示例**: 第5层 `recommended_power = 100 + (5-1) * 50 = 300`

**来源**: 此公式由地牢结构系统定义，本系统引用用于进入检查。

---

### F2: Entry Check Threshold

**公式**: `can_enter = (player_power >= recommended_power) AND (previous_floor_completed OR is_first_floor)`

**变量定义**:
- `player_power`: 玩家当前总战力 (来自装备槽系统)
- `recommended_power`: 目标层推荐战力 (来自F1)
- `previous_floor_completed`: 前一层状态 == Completed
- `is_first_floor`: `target_floor_id == 1`

**输出**: Boolean (true = 允许进入)

**示例**: 玩家战力=250, 目标第4层(推荐=250), 第3层已完成 → `can_enter = true`

---

### F3: Victory Processing Duration

**公式**: `victory_processing_time = VICTORY_DELAY + UI_cleanup_time`

**变量定义**:
- `VICTORY_DELAY`: 战斗胜利后的固定延迟 = 0.5秒 (from registry)
- `UI_cleanup_time`: UI清理动画时间 = 0.0秒 (MVP简化，无过渡动画)

**输出范围**: 0.5秒 (固定)

**用途**: ProcessingVictory状态持续时间，之后转入Idle。

---

### F4: Estimated Combat Duration (显示用途)

**公式**: `estimated_combat_time = base_time + enemy_count * per_enemy_time`

**变量定义**:
- `base_time`: 战斗基础时间 = 2.0秒 (from registry)
- `enemy_count`: 本层敌人数量 (来自敌人系统 `get_enemy_count(floor_id)`)
- `per_enemy_time`: 每敌人平均战斗时间 = 5.0秒 (from registry)

**输出范围**: 2.0秒 (1敌人) – 52.0秒 (10敌人)

**示例**: 第3层有3个敌人 → `estimated_time = 2.0 + 3 * 5.0 = 17.0秒`

**用途**: 在UI显示"预计战斗时间"，帮助玩家决定是否跳过。

---

### F5: Skip Time Saved

**公式**: `time_saved = estimated_combat_time - SKIP_ANIMATION_DURATION`

**变量定义**:
- `estimated_combat_time`: 来自F4
- `SKIP_ANIMATION_DURATION`: 跳过动画时长 = 0.3秒 (from registry)

**输出范围**: 1.7秒 – 51.7秒

**用途**: 显示"跳过可节省XX秒"，提供跳过按钮的价值信息。

## Edge Cases

### E1: 玩家战力恰好等于推荐战力

**场景**: `player_power == recommended_power` (边界值)

**处理**: 允许进入。战力比较使用 `>=` 运算符，边界值视为满足条件。

**UI显示**: 显示绿色"战力达标"提示，不显示警告。

---

### E2: 玩家战力低于推荐战力

**场景**: `player_power < recommended_power`

**处理**: 拒绝进入。状态保持 Idle，按钮显示灰色并禁用。

**UI显示**: 显示红色提示"战力不足，需要XX点"，其中 `XX = recommended_power - player_power`。

**信号**: 不触发任何推进信号，不调用战斗系统。

---

### E3: 战斗中应用被关闭

**场景**: 状态为 `InCombat` 时玩家关闭应用或切换到后台。

**处理**: 存档系统记录 `current_floor_id` 和 `advancement_state = InCombat`。下次启动时:
- 若存档中 `combat_state != Idle`，存档系统发出 `restore_combat` 信号
- 本系统收到信号，调用 `combat.start_combat(saved_floor_id)` 恢复战斗
- 战斗系统根据存档的敌人状态恢复战斗进度

**边缘分支**: 若存档策略选择"自动结算"而非"恢复战斗"，则启动时直接调用规则5胜利处理流程。

---

### E4: 跳过按钮被多次点击

**场景**: 状态为 `InCombat` 时玩家快速多次点击"跳过"按钮。

**处理**: 第一次点击调用 `combat.skip_combat()`，按钮立即禁用。后续点击无效果（按钮已禁用）。

**UI行为**: 跳过按钮点击后显示"已跳过"状态并禁用，防止重复调用。

---

### E5: 最终层战斗胜利

**场景**: `floor_id == max_floor_count` 且战斗胜利。

**处理**:
- 调用 `complete_floor(floor_id)`
- 不调用 `unlock_floor()` (无下一层)
- 状态转入 ProcessingVictory，0.5秒后转入 Idle
- 显示"地牢通关"提示（MVP仅文本提示，后续版本添加通关动画）

**UI显示**: 推进按钮隐藏或显示"已通关"状态，无下一层可推。

---

### E6: 首层入口无前置检查

**场景**: 玩家首次进入地牢，`current_floor == 0`。

**处理**: 规则2中 `previous_floor_completed` 检查被 `is_first_floor` 条件绕过。仅检查战力是否 >= 第1层推荐战力(100)。

**边界**: 第1层推荐战力=100，玩家初始战力可能低于100（取决于初始装备）。若低于100，按E2处理。

---

### E7: 离线后返回时战斗状态恢复

**场景**: 玩家离线期间战斗正在进行（InCombat状态存档）。

**处理**: 同E3，依赖存档系统的恢复策略。若存档系统选择"自动结算离线期间战斗"，则:
- 启动时直接进入胜利处理流程
- 计算离线期间的收益（由离线收益系统处理）
- 不重新播放战斗动画

**信号**: 存档系统发出 `offline_combat_resolved` 信号，本系统直接调用规则5。

---

### E8: 玩家战力暴涨后跳层推进

**场景**: 玩家强化装备后战力从100暴涨到400，理论上可跳过第2、3层直接进入第4层。

**处理**: **不允许跳层**。推进必须逐层进行，每层完成才能解锁下一层。即使战力足够，也必须按顺序完成第1层→第2层→第3层→第4层。

**规则约束**: 规则2中 `previous_floor_completed` 条件强制顺序推进。

**设计理由**: 服务"稳定成长"支柱，每层都是确定的进步，跳层会破坏成就感积累。

---

### E9: 推进按钮在战斗中被点击

**场景**: 状态为 `InCombat` 时玩家点击"下一层"按钮（按钮应已禁用）。

**处理**: 按钮在 CheckingEntry → ProcessingVictory 期间禁用。若UI实现遗漏导致按钮可点击，系统检查当前状态:
- 若状态 != Idle，拒绝推进请求
- 显示提示"当前战斗进行中"

**防御性设计**: 状态检查作为第一道防线，UI禁用作为第二道防线。

---

### E10: 快速连续点击推进按钮

**场景**: 玩家在 Idle 状态快速点击推进按钮多次。

**处理**: 第一次点击触发状态转换 Idle → CheckingEntry。后续点击时状态已不是 Idle，按E9处理（拒绝请求）。

**UI行为**: 点击后按钮立即禁用，直到状态回到 Idle。

---

### E11: 战斗系统未返回信号

**场景**: `start_combat()` 调用后，战斗系统因错误未发出 `combat_complete` 信号。

**处理**: 设置超时计时器 `combat_timeout = estimated_combat_time * 2`。若超时仍未收到信号:
- 强制调用 `combat.skip_combat()` 触发结算
- 记录错误日志
- 状态转入 ProcessingVictory

**防御性设计**: 超时机制防止系统卡死在 InCombat 状态。

---

### E12: 解锁楼层时地牢结构系统失败

**场景**: 调用 `unlock_floor(floor_id + 1)` 时地牢结构系统返回失败（如达到最大层数限制）。

**处理**: 第10层胜利时按E5处理（不调用unlock）。若其他层调用unlock失败:
- 记录错误日志
- 仍完成当前层 (`complete_floor`)
- 状态转入 Idle
- 下次推进时再次尝试unlock或显示错误提示

**边缘分支**: 若 unlock 失败是因 floor_id 越界，按E5处理。

## Dependencies

### Upstream Dependencies (本系统依赖的系统)

| 系统 | 依赖类型 | 依赖内容 | 接口/信号 |
|-----|---------|---------|---------|
| **地牢结构系统** | 数据依赖 | 楼层数据、推荐战力、解锁状态 | `get_floor_data()`, `can_enter_floor()`, `set_current_floor()`, `complete_floor()`, `unlock_floor()` |
| **战斗系统** | 流程依赖 | 战斗执行、跳过机制、胜利信号 | `start_combat()`, `skip_combat()`, `combat_complete` 信号 |
| **敌人系统** | 间接依赖 | 敌人数量（通过战斗系统） | 无直接调用 |
| **存档系统** | 数据依赖 | 状态持久化、离线恢复 | `save_state()`, `restore_state` 信号 |
| **装备槽系统** | 数据依赖 | 玩家总战力 | `get_total_power()` |

**接口契约** (本系统期望上游提供的接口):
- `dungeon_structure.can_enter_floor(floor_id)` → Boolean
- `dungeon_structure.complete_floor(floor_id)` → void
- `dungeon_structure.unlock_floor(floor_id)` → Boolean
- `combat.start_combat(floor_id)` → void
- `combat.skip_combat()` → void
- `combat` 发出 `combat_complete(floor_id, victory)` 信号
- `equipment_slots.get_total_power()` → Number

---

### Downstream Dependents (依赖本系统的系统)

| 系统 | 依赖类型 | 依赖内容 | 信号/接口 |
|-----|---------|---------|---------|
| **装备掉落系统** | 事件依赖 | 楠层完成事件、掉落触发 | `floor_completed(floor_id)` 信号 |
| **收益计算系统** | 事件依赖 | 楠层完成事件、收益计算触发 | `floor_completed(floor_id)` 信号 |
| **离线收益系统** | 事件依赖 | 楠层完成记录、离线收益计算 | 读取 `current_floor` 存档 |
| **视觉反馈系统** | 事件依赖 | 楠层进入事件、视觉反馈触发 | `floor_advanced(floor_id)` 信号 |
| **存档系统** | 状态依赖 | 推进状态、当前楼层 | 监听状态变化自动保存 |

**接口契约** (本系统向下游提供的信号):
- 发出 `floor_completed(floor_id)` → 战斗胜利、楼层完成时
- 发出 `floor_advanced(floor_id)` → 进入新楼层时
- 状态属性: `current_floor_id`, `advancement_state` (可被存档系统读取)

---

### Dependency Verification Checklist

**验证上游接口可用性**:
- [x] 地牢结构系统GDD已定义 `can_enter_floor()`, `complete_floor()`, `unlock_floor()`
- [x] 战斗系统GDD已定义 `start_combat()`, `skip_combat()`
- [x] 战斗系统GDD已定义 `combat_complete` 信号
- [x] 装备槽系统GDD已定义 `get_total_power()`
- [ ] 存档系统GDD已定义恢复机制 (待验证)

**验证下游依赖已记录**:
- [ ] 装备掉落系统GDD需订阅 `floor_completed` (待设计)
- [ ] 收益计算系统GDD需订阅 `floor_completed` (待设计)
- [ ] 离线收益系统GDD需读取 `current_floor` 存档 (待设计)
- [ ] 视觉反馈系统GDD需订阅 `floor_advanced` (待设计)

## Tuning Knobs

### G1: Victory Processing Duration

**参数名**: `victory_processing_duration`

**当前值**: 0.5秒

**安全范围**: 0.3秒 – 2.0秒

**影响**: ProcessingVictory状态的持续时间，影响胜利后的UI过渡速度。

- 过短(<0.3秒): 玩家来不及感知胜利反馈，体验匆忙
- 过长(>2.0秒): 玩家等待下一层推进的时间过长，破坏流畅感
- 推荐(0.5秒): 有足够时间显示胜利反馈，但不拖沓

**调整场景**: 若后续版本添加胜利动画，可延长至1.0-1.5秒配合动画时长。

---

### G2: Combat Timeout Multiplier

**参数名**: `combat_timeout_multiplier`

**当前值**: 2.0 (预估战斗时间的2倍)

**安全范围**: 1.5 – 3.0

**影响**: 超时计时器的触发时机，防止战斗系统卡死。

- 过低(<1.5): 可能正常战斗还未结束就触发超时，错误跳过
- 过高(>3.0): 系统卡死后等待时间过长，玩家体验差
- 推荐(2.0): 给予战斗系统足够的容错空间，同时防止长时间卡死

**调整场景**: 若战斗系统稳定性提升，可降低至1.5减少等待时间。

---

### G3: Entry Power Tolerance

**参数名**: `entry_power_tolerance`

**当前值**: 0 (精确匹配 `>= recommended_power`)

**安全范围**: -50 – +50 战力点

**影响**: 进入条件的宽松度。负值允许战力略低也能进入，正值要求战力更高。

- 负值(-50): 允许战力低于推荐50点也能进入，降低难度门槛
- 正值(+50): 要求战力高于推荐50点才能进入，提高挑战门槛
- 推荐(0): 精确匹配推荐战力，符合"稳定成长"支柱的确定性

**调整场景**: MVP阶段保持0，后续版本可考虑负值降低新手门槛。

---

### G4: Skip Button Availability

**参数名**: `skip_button_enabled`

**当前值**: true (战斗中可跳过)

**安全范围**: true / false

**影响**: 是否允许玩家跳过战斗动画。

- true: 玩家可跳过，服务"掌控节奏"支柱
- false: 强制观看战斗，增加沉浸感但降低掌控感
- 推荐(true): 服务"掌控节奏"支柱

**调整场景**: MVP保持true，后续版本可考虑根据楼层深度限制跳过（如高层战斗不可跳过）。

---

### G5: Offline Combat Resolution Policy

**参数名**: `offline_combat_policy`

**当前值**: "auto_resolve" (自动结算离线期间的战斗)

**可选值**: "restore" / "auto_resolve" / "discard"

**影响**: 离线期间战斗状态的恢复策略。

- "restore": 启动时恢复战斗，玩家继续观看
- "auto_resolve": 自动结算，玩家获得收益但不观看战斗
- "discard": 丢弃战斗状态，玩家需重新推进该层
- 推荐("auto_resolve"): 符合放置游戏惯例，玩家离线期间应有收益

**调整场景**: 若战斗视觉反馈成为核心卖点，可考虑"restore"让玩家观看。

---

### G6: Advancement Button Cooldown

**参数名**: `advancement_cooldown`

**当前值**: 0秒 (无冷却，状态回到Idle后立即可点击)

**安全范围**: 0秒 – 1.0秒

**影响**: 推进按钮点击后的冷却时间，防止快速连续推进。

- 0秒: 无冷却，玩家可连续快速推进
- 0.5秒: 有短暂冷却，给玩家思考"是否继续"的时间
- 1.0秒: 冷却较长，强制玩家放慢节奏
- 推荐(0秒): 符合"爽感反馈"支柱，连续推进有快感

**调整场景**: 若玩家反馈"推进太快缺乏期待感"，可增加0.3-0.5秒冷却。

---

### G7: Floor Completion Feedback Duration

**参数名**: `completion_feedback_duration`

**当前值**: 0.5秒 (ProcessingVictory时长内显示)

**安全范围**: 0.3秒 – 1.5秒

**影响**: 楠层完成时的视觉反馈显示时长。

- 过短(<0.3秒): 反馈不明显，玩家错过感知
- 过长(>1.5秒): 拖沓，影响下一层推进节奏
- 推荐(0.5秒): 配合ProcessingVictory时长，简洁有力

**调整场景**: 若后续版本添加完成动画，可延长至1.0秒。

---

### G8: Sequential Advancement Enforcement

**参数名**: `enforce_sequential_advancement`

**当前值**: true (强制顺序推进，不可跳层)

**可选值**: true / false

**影响**: 是否允许战力超标的玩家跳层推进。

- true: 必须逐层完成，服务"稳定成长"支柱
- false: 战力足够时可跳层，加快进度但破坏成就感积累
- 推荐(true): 服务"稳定成长"支柱

**调整场景**: MVP保持true，后续版本若玩家反馈"低层太无聊"可考虑开放跳层但有惩罚（如跳过层不掉落装备）。

## Visual/Audio Requirements

### Visual Feedback Moments (本系统触发)

| 触发时机 | 信号 | 预期视觉反馈 | 实现归属 |
|---------|------|-------------|---------|
| 进入新楼层 | `floor_advanced(floor_id)` | 楠层过渡动画、楼层编号显示 | 视觉反馈系统 |
| 战斗胜利 | `floor_completed(floor_id)` | 胜利闪光、完成标记 | 视觉反馈系统 |
| 战力不足拒绝进入 | 无信号 | 红色提示文本、按钮灰色 | 本系统UI |
| 战斗跳过 | `skip_combat()` | 快速结算动画（由战斗系统处理） | 战斗系统 |

**MVP简化**:
- 楠层过渡动画 → 简化为文本提示"进入第X层"
- 胜利闪光 → 简化为文本提示"战斗胜利"
- 战力不足提示 → 实现最低限度UI反馈

**视觉反馈系统依赖**: 需订阅 `floor_advanced` 和 `floor_completed` 信号。

---

### Audio Feedback Moments (本系统期望)

| 触发时机 | 预期音效 | 实现归属 |
|---------|---------|---------|
| 点击推进按钮 | 点击音效（轻快） | 音效系统 |
| 进入新楼层 | 过渡音效（上升感） | 音效系统 |
| 战斗胜利 | 胜利音效（满足感） | 音效系统 |
| 战力不足拒绝 | 拒绝音效（低沉/警告） | 音效系统 |
| 点击跳过按钮 | 点击音效（轻快） | 音效系统 |

**MVP阶段**: 音效系统为Vertical Slice，MVP阶段可暂时无声效。本系统发出信号供音效系统后续接入。

**音效系统依赖**: 需订阅 `floor_advanced` 和 `floor_completed` 信号。

---

### MVP Implementation Notes

**本系统自实现的视觉反馈** (不依赖视觉反馈系统):
- 战力不足提示文本: 红色字体，显示"战力不足，需要XX点"
- 推进按钮状态: 禁用时灰色，可点击时高亮
- 跳过按钮状态: 点击后显示"已跳过"

** delegated to 战斗系统**:
- 战斗过程中的所有视觉反馈
- 跳过结算动画

** delegated to 视觉反馈系统** (后续版本):
- 楠层过渡动画
- 胜利粒子效果
- 完成标记特效

---

### Performance Considerations

**视觉反馈性能预算**:
- 楠层过渡动画: 不超过0.5秒，无粒子效果(MVP)
- 胜利反馈: 不超过0.5秒，无粒子效果(MVP)
- 跳过结算: 不超过0.3秒 (战斗系统负责)

**移动端限制**: 无粒子效果(MVP)，后续版本由视觉反馈系统设计粒子预算。

## UI Requirements

### UI Elements Owned by This System

| 元素 | 功能 | 显示时机 | 交互 |
|-----|------|---------|-----|
| **推进按钮** | 触发进入下一层 | Idle状态，条件满足时 | 点击 → CheckingEntry |
| **跳过按钮** | 跳过战斗快速结算 | InCombat状态 | 点击 → skip_combat() |
| **战力不足提示** | 显示进入条件差距 | 条件不满足时 | 无交互，纯显示 |
| **当前楼层显示** | 显示当前所在楼层 | 常驻显示 | 无交互 |

**推进按钮状态**:
- 可点击: 绿色高亮，条件满足
- 禁用: 灰色，条件不满足或状态非Idle
- 过渡: 点击后显示"进入中..."，等待战斗开始

**跳过按钮状态**:
- 可点击: 战斗进行中
- 已跳过: 灰色，点击后显示"已跳过"
- 隐藏: 非战斗状态

---

### UI Layout Requirements

**锚点位置** (参考UI布局系统):
- 推进按钮: GameplayLayer中央下方，safe area内
- 跳过按钮: GameplayLayer右上角，战斗时显示
- 楠层显示: HUDLayer顶部中央
- 战力提示: 推进按钮附近，toast或inline

**触控目标大小** (参考UI布局系统):
- 推进按钮: 最小44pt (iOS) / 48dp (Android)
- 跳过按钮: 最小44pt (iOS) / 48dp (Android)

**响应式适配**: 推进按钮在不同屏幕尺寸保持居中，使用anchor点适配。

---

### Data Binding Requirements

| UI元素 | 数据源 | 更新时机 |
|-----|------|---------|
| 推进按钮可用状态 | `can_enter_floor(next_floor_id)` | 装备强化后战力变化、楠层完成后 |
| 当前楼层显示 | `current_floor_id` | 状态变化时 |
| 战力不足提示 | `recommended_power - player_power` | 点击推进按钮条件检查失败时 |
| 跳过按钮可用状态 | `advancement_state == InCombat` | 状态转换时 |

**数据流向**: 装备槽系统 → 战力变化 → 本系统重新检查 `can_enter` → 更新按钮状态。

---

### MVP UI Simplifications

**MVP阶段简化**:
- 推进按钮: 纯文本按钮"下一层"，无图标
- 跳过按钮: 纯文本按钮"跳过"，无图标
- 楠层显示: 纯文本"第X层"
- 战力提示: 纯文本"战力不足，需要XX"

**后续版本扩展**:
- 推进按钮: 添加图标、动画效果
- 跳过按钮: 添加图标、节省时间显示
- 楠层显示: 添加进度条、视觉装饰
- 战力提示: 添加toast动画、颜色变化

---

### Accessibility Requirements

**无障碍支持** (参考触控输入系统):
- 推进按钮、跳过按钮满足最小触控目标尺寸
- 按钮状态变化有视觉反馈（颜色、文字）
- 战力提示有清晰文本，不依赖颜色传递信息

**MVP阶段**: 满足基本触控尺寸和清晰文本，后续版本添加screen reader支持。

---

### Debug UI (Dev-Only)

**开发调试UI** (不包含在正式版本):
- 当前状态显示: 文本显示 `advancement_state`
- 信号监听log: 显示收到的信号
- 强制跳过按钮: 绕过状态检查直接推进（调试用）

**实现**: 通过Godot debug overlay或单独的debug scene。

## Acceptance Criteria

### AC1: Entry Check — Power Threshold

**测试条件**: 玩家战力 = 250, 目标楼层第4层(推荐=250)

**预期结果**: `can_enter == true`, 推进按钮可点击

**验证方法**: 手动设置玩家战力为250，点击推进按钮，验证进入战斗而非显示"战力不足"。

---

### AC2: Entry Check — Power Below Threshold

**测试条件**: 玩家战力 = 200, 目标楼层第4层(推荐=250)

**预期结果**: `can_enter == false`, 推进按钮禁用，显示"战力不足，需要50点"

**验证方法**: 手动设置玩家战力为200，点击推进按钮，验证显示战力不足提示。

---

### AC3: Entry Check — Boundary Value

**测试条件**: 玩家战力 = 249, 目标楼层第4层(推荐=250)

**预期结果**: `can_enter == false`, 显示"战力不足，需要1点"

**验证方法**: 设置战力为249（低于推荐1点），验证拒绝进入。

---

### AC4: Combat Trigger on Valid Entry

**测试条件**: 玩家战力达标，点击推进按钮

**预期结果**:
- 状态转换 Idle → CheckingEntry → InCombat
- 调用 `start_combat(floor_id)`
- 跳过按钮显示

**验证方法**: 点击推进按钮，观察战斗系统状态变化和跳过按钮出现。

---

### AC5: Victory Handling — Floor Completion

**测试条件**: 战斗胜利，收到 `combat_complete(floor_id=3, victory=true)` 信号

**预期结果**:
- 调用 `complete_floor(3)`
- 调用 `unlock_floor(4)`
- 发出 `floor_completed(3)` 信号
- 状态转换 InCombat → ProcessingVictory → Idle (0.5秒后)

**验证方法**: 触发战斗胜利，验证第3层状态变为Completed，第4层变为Unlocked。

---

### AC6: Victory Handling — Final Floor

**测试条件**: 战斗胜利，`floor_id = 10` (max_floor_count)

**预期结果**:
- 调用 `complete_floor(10)`
- 不调用 `unlock_floor`
- 显示"地牢通关"提示
- 推进按钮隐藏或显示"已通关"

**验证方法**: 完成第10层战斗，验证无第11层解锁，通关提示显示。

---

### AC7: Skip Button — Functional

**测试条件**: 战斗进行中，点击跳过按钮

**预期结果**:
- 调用 `skip_combat()`
- 战斗系统发出 `combat_complete` 信号
- 跳过按钮显示"已跳过"并禁用

**验证方法**: 战斗开始后点击跳过，验证战斗快速结束并显示胜利。

---

### AC8: Skip Button — Multiple Click Protection

**测试条件**: 战斗进行中，快速点击跳过按钮3次

**预期结果**: 仅第一次点击有效，后续点击无效果（按钮已禁用）

**验证方法**: 快速点击跳过按钮3次，验证战斗仅结算一次，无重复调用。

---

### AC9: State Transition — Sequence

**测试条件**: 正常推进流程（点击 → 战斗 → 胜利）

**预期结果**: 状态按顺序转换:
- Idle → CheckingEntry (点击)
- CheckingEntry → InCombat (检查通过)
- InCombat → ProcessingVictory (胜利)
- ProcessingVictory → Idle (0.5秒后)

**验证方法**: 使用debug UI观察状态变化，验证顺序正确。

---

### AC10: UI Button — Disabled During Combat

**测试条件**: 状态为 InCombat，点击推进按钮

**预期结果**: 推进按钮禁用，点击无效，显示提示"战斗进行中"（如果UI未正确禁用）

**验证方法**: 战斗开始后尝试点击推进按钮，验证无反应。

---

### AC11: Signal Emission — floor_completed

**测试条件**: 战斗胜利，楼层完成

**预期结果**: 发出 `floor_completed(floor_id)` 信号，装备掉落系统和收益计算系统收到信号

**验证方法**: 使用信号监听工具验证信号发出，下游系统正确响应。

---

### AC12: Signal Emission — floor_advanced

**测试条件**: 进入新楼层

**预期结果**: 发出 `floor_advanced(floor_id)` 信号，视觉反馈系统收到信号

**验证方法**: 点击推进按钮进入新层，验证视觉反馈系统响应。

---

### AC13: First Floor Entry — No Previous Check

**测试条件**: `current_floor == 0`, 玩家战力 >= 100, 点击进入第1层

**预期结果**: 允许进入，无"前一层未完成"检查

**验证方法**: 新玩家首次进入地牢，验证直接进入第1层。

---

### AC14: Sequential Advancement — No Skip Floor

**测试条件**: 玩家战力 = 400, 第1层已完成, 尝试直接进入第4层

**预期结果**: 拒绝进入，显示"第2层未完成"（需要逐层推进）

**验证方法**: 设置战力400，第1层完成，尝试直接推进到第4层，验证拒绝。

---

### AC15: Offline Combat — Auto Resolve

**测试条件**: 存档中有 `advancement_state = InCombat`, 离线后重新启动

**预期结果**: 自动结算战斗，按胜利处理流程，不恢复战斗画面

**验证方法**: 模拟离线场景，验证启动时直接显示胜利而非恢复战斗。

---

### AC16: Combat Timeout — Recovery

**测试条件**: `start_combat()` 调用后战斗系统无响应（模拟错误）

**预期结果**: 超时后调用 `skip_combat()` 强制结算

**验证方法**: 禁用战斗系统的信号发送，验证超时后自动结算。

---

### AC17: Victory Processing Timing

**测试条件**: 战斗胜利后

**预期结果**: ProcessingVictory状态持续0.5秒后转入Idle

**验证方法**: 使用计时器测量从胜利到Idle的时间，误差±0.1秒。

---

### AC18: UI Display — Floor Number

**测试条件**: 状态变化时

**预期结果**: 当前楼层显示正确更新

**验证方法**: 完成第3层后，验证UI显示"第4层"或"第3层已完成"。

---

### AC19: Advancement Button — State Restoration

**测试条件**: ProcessingVictory → Idle 状态转换后

**预期结果**: 推进按钮重新可点击（若下一层条件满足）

**验证方法**: 完成一层后，验证推进按钮从禁用恢复为可点击。

## Open Questions

### OQ1: 离线战斗恢复策略细节

**问题**: 存档系统应采用 "restore" 还是 "auto_resolve" 策略处理离线期间的战斗？

**影响**:
- restore: 玩家需观看战斗完成，但可能不记得离线前的状态
- auto_resolve: 玩家直接获得收益，但失去战斗体验

**当前假设**: MVP采用 "auto_resolve"，符合放置游戏惯例。

**需澄清**: 存档系统GDD设计时确定最终策略。

---

### OQ2: 战斗超时计时器触发时机

**问题**: 超时计时器应在 `start_combat()` 调用时启动，还是等待战斗系统确认进入InProgress状态？

**影响**:
- 调用时启动: 可能战斗系统正在Spawning阶段就触发超时
- 等待确认: 需战斗系统发出额外信号

**当前假设**: 调用时启动，超时时间足够长(2倍预估时间)覆盖Spawning阶段。

**需澄清**: 战斗系统GDD是否有"combat_started"信号可供监听。

---

### OQ3: 跳过按钮UI位置与战斗系统协调

**问题**: 跳过按钮由本系统UI管理，还是由战斗系统UI管理？

**影响**:
- 本系统管理: 统一推进流程UI，但需与战斗系统UI层协调
- 战斗系统管理: 战斗相关UI集中管理，但本系统需监听跳过状态

**当前假设**: 本系统管理跳过按钮，战斗系统仅提供 `skip_combat()` 接口。

**需澄清**: UI布局系统GDD的layer优先级和按钮归属规则。

---

### OQ4: 楠层过渡动画的视觉反馈系统集成

**问题**: "进入第X层"的过渡动画由视觉反馈系统实现，本系统仅发出信号？

**影响**:
- 视觉反馈系统实现: 统一视觉反馈管理，但本系统需等待动画完成才能进入战斗
- 本系统实现: 直接控制过渡，但视觉反馈逻辑分散

**当前假设**: MVP简化为文本提示，后续版本由视觉反馈系统实现动画。

**需澄清**: 视觉反馈系统GDD的信号处理时序（是否需要回调确认动画完成）。

---

### OQ5: 快速连续推进的节奏控制

**问题**: 是否需要限制玩家连续推进的速度（如每分钟最多推进N层）？

**影响**:
- 无限制: 玩家可快速推完所有可达层，体验可能过于仓促
- 有限制: 强制玩家放慢节奏，但可能破坏"爽感"

**当前假设**: MVP无限制，依赖战斗时间自然控制节奏。

**需澄清**: 后续版本是否需要添加冷却机制（参考G6 tuning knob）。

---

### OQ6: 战力显示刷新时机

**问题**: 装备强化后战力变化，推进按钮状态何时刷新？

**影响**:
- 实时刷新: 每次装备强化立即检查并更新按钮状态
- 定时刷新: 定期检查，可能有延迟
- 手动刷新: 玩家需切换界面才能看到更新

**当前假设**: 实时刷新，订阅装备槽系统战力变化信号。

**需澄清**: 装备槽系统GDD是否有战力变化信号。

---

### OQ7: 通关后的地牢重置

**问题**: 完成第10层后，是否允许玩家重置地牢重新挑战？

**影响**:
- 不重置: 游戏内容有限，玩家可能流失
- 可重置: 玩家可重复挑战，但需设计重置奖励机制

**当前假设**: MVP不重置，仅记录通关状态。

**需澄清**: 后续版本的地牢重置系统设计（多地牢区域或循环挑战机制）。

---

### OQ8: 推进按钮的触控反馈强度

**问题**: 推进按钮点击时是否需要震动反馈？

**影响**:
- 有震动: 增强点击感知，服务"爽感反馈"支柱
- 无震动: 简化实现，依赖视觉反馈

**当前假设**: MVP无震动，后续版本由震动反馈系统集成。

**需澄清**: 震动反馈系统GDD的触发时机和强度设计。