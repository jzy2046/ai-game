# 时间追踪系统 (Time Tracking System)

> **Status**: Approved
> **Author**: user + agents
> **Last Updated**: 2026-04-30
> **Approved**: 2026-04-30 (Solo mode — direct completion)
> **Implements Pillar**: 稳定成长 + 掌控节奏

## Overview

时间追踪系统是游戏时间计算的逻辑层，负责计算离线时长、检测时间异常、累积游戏时长，并为依赖系统提供统一的时间查询接口。它不负责数据持久化 —— 存档系统（Save System）负责存储 `time_tracking` 字段，时间追踪系统负责计算和解释这些数据。

该系统是离线收益系统的基础设施：玩家返回游戏时，离线收益系统需要知道"玩家离开了多久"来计算挂机收益。时间追踪系统通过多源时间验证（系统时间 + 单调时间）确保计算结果的可靠性，防止玩家通过修改系统时钟获取不正当收益。

核心职责：
- 会话开始时初始化时间追踪
- 会话结束时更新累积游戏时长
- 计算离线时长（含异常检测和修正）
- 提供查询接口供其他系统调用

**架构定位**: Persistence 层（Core 子层），被 Save System 持有，为 Offline Reward System 提供服务。

## Player Fantasy

时间追踪系统是纯基础设施系统，玩家不直接与之交互，因此没有传统意义上的"Player Fantasy"。

然而，时间追踪系统支撑的**隐性玩家体验**是：

> **"我的进度在等待我回来"** — 玩家关闭游戏后，角色仍在"虚拟世界"中继续活动；玩家归来时，看到累积的离线收益，感到"我离开的时间被尊重了"。这种感觉支撑支柱"稳定成长"的核心承诺：玩家的每一分钟都有价值。

时间追踪系统的正确运作确保：
- 离线收益准确反映真实离线时间（不被篡改，不被低估）
- 异常情况被优雅处理（时间回退时收益为 0，而非负数或错误）
- 游戏时长被正确累积（成就系统可显示"已游玩 XX 小时")

时间追踪系统的失败会破坏这种隐性体验：如果离线时间计算错误，玩家可能获得过多收益（破坏"掌控节奏"）或过少收益（破坏"稳定成长"的公平感）。

**参考**: 梦幻西游手游 — 离线 8 小时后回来，获得合理的挂机收益，玩家感到"我的角色一直在为我努力"。

## Detailed Design

### Core Rules

#### Rule 1: Session Start — Initialize Time Tracking

**Rule**: 当会话开始（游戏启动或从后台恢复）时，时间追踪系统必须捕获当前时间源并初始化追踪状态。

**初始化序列**:
1. 从 Save System 读取 `time_tracking` 数据结构
2. 捕获当前系统时间: `session_start_system_time = Time.get_unix_time_from_system()`
3. 捕获当前单调时间: `session_start_monotonic = Time.get_ticks_msec()`
4. 存储上次保存的系统时间: `last_save_system_time = time_tracking.last_save_system_time`
5. 计算离线时长（Rule 3）
6. 重置会话累积时间: `session_accumulated_seconds = 0`

**数据结构（由 Save System 持有）**:
```json
{
  "time_tracking": {
    "last_save_system_time": 1714483200,
    "last_save_monotonic_offset": 3600000,
    "accumulated_playtime_seconds": 86400,
    "anomaly_count": 0,
    "last_anomaly_timestamp": null
  }
}
```

**TimeTrackingManager 内部状态**:
```gdscript
# 运行时状态（不持久化，每次会话重新计算）
var session_start_system_time: float  # Unix timestamp
var session_start_monotonic: int      # ticks msec
var session_accumulated_seconds: float = 0.0
var last_save_system_time: float      # 从 Save System 加载
var last_save_monotonic_offset: int   # 从 Save System 加载
var accumulated_playtime_seconds: float  # 从 Save System 加载
```

**具体要求**:
- 时间源捕获必须在游戏逻辑启动前完成
- 如果 Save System 无保存数据，使用默认值（见 Save System Rule 7）
- 离线时长计算结果提供给 Offline Reward System

**可测试性**:
- 单元测试: 启动游戏 → 验证 `session_start_system_time` 和 `session_start_monotonic` 已初始化
- 单元测试: 无存档启动 → 验证使用默认值
- 单元测试: 从后台恢复 → 验证重新初始化（非全新启动）

---

#### Rule 2: Session End — Calculate and Update Playtime

**Rule**: 当会话结束（游戏关闭或进入后台）时，时间追踪系统必须计算本次会话时长并更新累积游戏时长。

**结束序列**:
1. 捕获当前单调时间: `session_end_monotonic = Time.get_ticks_msec()`
2. 计算会话时长: `session_duration = (session_end_monotonic - session_start_monotonic) / 1000.0`
3. 应用会话时长上限（防止溢出）: `session_duration = min(session_duration, MAX_SESSION_DURATION)`
4. 更新累积时长: `accumulated_playtime_seconds += session_duration`
5. 更新 `last_save_system_time = Time.get_unix_time_from_system()`
6. 更新 `last_save_monotonic_offset = session_end_monotonic`
7. 将更新后的 `time_tracking` 数据返回给 Save System 进行持久化

**具体要求**:
- 会话时长使用单调时间计算（不受系统时钟修改影响）
- 如果会话时长超过 `MAX_SESSION_DURATION`（默认 12 小时），截断并记录异常
- 离线时长计算仅在 Session Start 时进行，Session End 时仅更新累积时长
- Save System 负责实际写入磁盘，Time Tracking 仅返回数据

**可测试性**:
- 单元测试: 正常退出游戏 → 验证 `accumulated_playtime_seconds` 增加正确值
- 单元测试: 快速启动并退出（<1 秒）→ 验证时长计算正确
- 单元测试: 会话时长超过 12 小时 → 验证截断到 MAX_SESSION_DURATION

---

#### Rule 3: Offline Duration Calculation — Multi-Source Validation

**Rule**: 离线时长必须通过异常检测规则计算，确保结果在合理范围内。

**计算公式**:
```
raw_offline_duration = current_system_time - last_save_system_time

# Step 1: 异常检测（见 Rule 4）
offline_duration = apply_anomaly_rules(raw_offline_duration)

# Step 2: 应用上限
offline_duration = min(offline_duration, MAX_FORWARD_JUMP, MAX_ALLOWED_OFFLINE)
```

**变量说明**:
| 变量 | 类型 | 来源 | 说明 |
|------|------|------|------|
| `current_system_time` | float | `Time.get_unix_time_from_system()` | 当前 Unix 时间戳 |
| `last_save_system_time` | float | Save System | 上次保存时的系统时间 |
| `raw_offline_duration` | float | 计算 | 未修正的离线时长（秒） |
| `offline_duration` | float | 计算 | 最终离线时长（秒） |
| `MAX_FORWARD_JUMP` | int | 常量 | 前向跳跃上限（7 天 = 604800 秒） |
| `MAX_ALLOWED_OFFLINE` | int | 调优参数 | 允许的最大离线收益时长（默认 24 小时） |

**计算时机**:
- 仅在 Session Start 时计算一次
- 计算结果缓存供 Offline Reward System 使用
- Session End 时不重新计算

**具体要求**:
- 异常检测优先于上限应用
- 检测到的异常必须记录到 `anomaly_count` 和 `last_anomaly_timestamp`
- 离线时长结果必须 >= 0

**可测试性**:
- 单元测试: 正常离线 2 小时 → 验证 `offline_duration = 7200`
- 单元测试: 离线 30 天 → 验证 `offline_duration = MAX_ALLOWED_OFFLINE`（24 小时）
- 单元测试: 系统时间回退 → 验证 `offline_duration = 0`

---

#### Rule 4: Anomaly Detection — Time Manipulation Mitigation

**Rule**: 系统必须检测并缓解时间异常，防止玩家通过修改系统时钟获益。

**异常类型和处理**:

| 异常类型 | 检测条件 | 处理方式 | 异常记录 |
|----------|----------|----------|----------|
| **时间回退** | `current_system_time < last_save_system_time` | 离线时长设为 0 | `anomaly_count += 1`, `last_anomaly_timestamp = current_system_time` |
| **时间前向跳跃 > 7 天** | `raw_offline_duration > 604800` | 离线时长截断到 7 天 | `anomaly_count += 1`, `last_anomaly_timestamp = current_system_time` |
| **会话时长溢出** | `session_duration > MAX_SESSION_DURATION` | 截断到 MAX_SESSION_DURATION | `anomaly_count += 1` |

**异常检测伪代码**:
```gdscript
func apply_anomaly_rules(raw_offline_duration: float) -> float:
    var offline_duration = raw_offline_duration
    
    # Rule 4a: 时间回退
    if raw_offline_duration < 0:
        offline_duration = 0
        _log_anomaly("time_backward", raw_offline_duration)
    
    # Rule 4b: 时间前向跳跃超过 7 天
    elif raw_offline_duration > MAX_FORWARD_JUMP:
        offline_duration = MAX_FORWARD_JUMP
        _log_anomaly("time_forward_jump", raw_offline_duration)
    
    return offline_duration

func _log_anomaly(anomaly_type: String, detected_value: float) -> void:
    anomaly_count += 1
    last_anomaly_timestamp = Time.get_unix_time_from_system()
    # 记录日志供调试（不影响游戏逻辑）
    print("[TimeTracking] Anomaly detected: %s, value: %.0f, count: %d" % [anomaly_type, detected_value, anomaly_count])
```

**具体要求**:
- MVP 阶段不惩罚异常，仅记录（未来可考虑减少离线收益）
- `anomaly_count` 和 `last_anomaly_timestamp` 由 Save System 持久化
- 异常记录用于调试和数据分析，不影响当前会话

**可测试性**:
- 单元测试: 设置系统时间回退 1 小时 → 验证 `offline_duration = 0`, `anomaly_count = 1`
- 单元测试: 设置系统时间前进 10 天 → 验证 `offline_duration = 604800`, `anomaly_count = 1`
- 单元测试: 连续多次异常 → 验证 `anomaly_count` 累积

---

#### Rule 5: Playtime Update — Accumulate Session Duration

**Rule**: 累积游戏时长必须在每次会话结束时更新，使用单调时间确保准确性。

**更新公式**:
```
session_duration = (session_end_monotonic - session_start_monotonic) / 1000.0
session_duration = min(session_duration, MAX_SESSION_DURATION)  # 防止溢出
accumulated_playtime_seconds = saved_accumulated_playtime_seconds + session_duration
```

**更新时机**:
- 游戏正常退出时
- 游戏进入后台时（移动端生命周期）
- 定期保存时（由 Save System 触发，每 60 秒）

**具体要求**:
- 使用单调时间计算，不受系统时钟修改影响
- 定期保存时也需要更新，防止意外崩溃导致时长丢失
- 时长上限防止异常情况（如设备挂起后恢复）

**可测试性**:
- 单元测试: 游玩 10 分钟后保存 → 验证 `accumulated_playtime_seconds` 增加 ~600 秒
- 单元测试: 模拟定期保存 → 验证时长已更新

---

#### Rule 6: Query Interface — Public API

**Rule**: 其他系统通过定义的接口查询时间数据，不直接访问内部状态。

**公共方法**:
```gdscript
# TimeTrackingManager.gd（单例，由 SaveManager 初始化）
class_name TimeTrackingManager

# 查询接口
func get_offline_duration() -> float      # 返回离线时长（秒）
func get_playtime() -> float              # 返回累积游戏时长（秒）
func get_last_save_time() -> float        # 返回上次保存的系统时间（Unix）
func get_session_duration() -> float      # 返回当前会话时长（秒，实时）
func get_anomaly_count() -> int           # 返回异常次数（供未来惩罚逻辑）
func has_time_anomaly() -> bool           # 返回当前会话是否有异常

# 信号
signal offline_duration_calculated(duration: float)  # 离线时长计算完成
signal playtime_updated(total_seconds: float)        # 累积时长更新
signal anomaly_detected(anomaly_type: String)        # 异常检测通知
```

**返回值约定**:
| 方法 | 返回类型 | 说明 |
|------|----------|------|
| `get_offline_duration()` | float | >= 0，已应用异常修正和上限 |
| `get_playtime()` | float | >= 0，包含所有历史会话时长 |
| `get_last_save_time()` | float | Unix 时间戳，0 表示新游戏 |
| `get_session_duration()` | float | >= 0，当前会话已游玩时长（实时计算） |
| `get_anomaly_count()` | int | >= 0，历史异常总数 |
| `has_time_anomaly()` | bool | 本会话是否检测到异常 |

**具体要求**:
- `get_session_duration()` 实时计算，不缓存
- 离线时长仅在 Session Start 时计算一次，后续调用返回缓存值
- 所有返回值 >= 0

**可测试性**:
- 单元测试: 调用 `get_offline_duration()` → 验证返回值与计算结果一致
- 单元测试: 游玩期间调用 `get_session_duration()` → 验证实时更新
- 单元测试: 新游戏调用 `get_last_save_time()` → 验证返回 0

---

#### Rule 7: Time Sources — Godot API Usage

**Rule**: 时间追踪系统使用以下 Godot API 作为时间源。

**时间源定义**:

| 时间源 | Godot API | 类型 | 特性 |
|--------|-----------|------|------|
| **系统时间** | `Time.get_unix_time_from_system()` | float | Unix 时间戳（秒），受系统时钟影响 |
| **单调时间** | `Time.get_ticks_msec()` | int | 毫秒级 ticks，不受系统时钟影响，会话内可靠 |

**使用原则**:
- **离线时长计算**: 使用系统时间（需要跨会话时间）
- **会话时长计算**: 使用单调时间（不受时钟修改影响）
- **保存时间戳**: 使用系统时间（需要持久化，跨会话可读）

**Godot 4.6 API 参考**:
```gdscript
# 系统时间（Unix 时间戳，秒级精度）
var system_time: float = Time.get_unix_time_from_system()

# 单调时间（毫秒级 ticks，从应用启动时开始）
var monotonic_time: int = Time.get_ticks_msec()

# 注意: get_ticks_msec() 返回 int，需要转换为秒时除以 1000.0
var monotonic_seconds: float = monotonic_time / 1000.0
```

**具体要求**:
- 不使用 `Time.get_ticks_usec()`（精度过高，MVP 不需要）
- 不使用 `OS.get_system_time_msecs()`（已弃用，使用 `Time` 类替代）
- 所有时间戳使用 UTC，不考虑本地时区

**可测试性**:
- 单元测试: 验证使用正确 API（检查导入和调用）
- 单元测试: 模拟 API 返回值 → 验证计算逻辑正确

---

### States and Transitions

时间追踪系统采用简化的状态模式：

```
 ┌─────────────┐    session_start    ┌──────────────┐
 │   Inactive  │ ───────────────────► │   Active     │
 │             │                      │              │
 └─────────────┘                      └──────────────┘
                                          │
                                          │ session_end
                                          ▼
                                      ┌──────────────┐
                                      │   Updating   │
                                      │              │
                                      └──────────────┘
                                          │
                                          │ data_returned
                                          ▼
                                      ┌──────────────┐
                                      │   Inactive   │
                                      │              │
                                      └──────────────┘
```

**状态说明**:

| 状态 | 描述 | 允许操作 |
|------|------|----------|
| **Inactive** | 游戏未运行或已完全退出 | 无 |
| **Active** | 游戏运行中，时间追踪活跃 | `get_session_duration()`, `get_playtime()` 等 |
| **Updating** | 会话结束，正在更新数据 | 无（阻塞） |

**转换触发**:

| 从 | 到 | 触发 | 说明 |
|----|----|------|------|
| Inactive | Active | `initialize()` | 游戏启动或从后台恢复 |
| Active | Updating | `finalize()` | 游戏退出或进入后台 |
| Updating | Inactive | 数据返回给 Save System | 完成持久化 |

---

### Interactions with Other Systems

| 系统 | 交互方式 | 方向 | 说明 |
|------|----------|------|------|
| **Save System** | 数据持有 | 双向 | Save System 持有 `time_tracking` 数据；Time Tracking 计算后返回更新数据 |
| **Offline Reward System** | 时间查询 | 出向 | 提供离线时长、上次保存时间供收益计算 |
| **UI System** | 显示时长 | 出向 | 提供游戏时长供 HUD 显示（未来：成就系统） |
| **Analytics System** | 异常日志 | 出向 | 提供异常次数供数据分析（未来） |

**数据流向**:
```
Session Start:
  Save System → Time Tracking（加载 time_tracking 数据）
  Time Tracking → Offline Reward System（提供 offline_duration）

Session End:
  Time Tracking → Save System（返回更新的 time_tracking 数据）
  Save System → Disk（持久化）
```

**通知模式**:
- Time Tracking 计算完成后发出信号 `offline_duration_calculated`
- Offline Reward System 监听信号并计算收益
- Save System 监听 `playtime_updated` 信号触发保存

## Formulas

### Offline Duration Calculation

```
raw_offline_duration = current_system_time - last_save_system_time

# Step 1: Apply anomaly rules
if raw_offline_duration < 0:
    anomaly_duration = 0
    anomaly_detected = true
elif raw_offline_duration > MAX_FORWARD_JUMP:
    anomaly_duration = MAX_FORWARD_JUMP
    anomaly_detected = true
else:
    anomaly_duration = raw_offline_duration
    anomaly_detected = false

# Step 2: Apply offline reward cap
offline_duration = min(anomaly_duration, MAX_ALLOWED_OFFLINE)

# Result: offline_duration in seconds (0 <= offline_duration <= MAX_ALLOWED_OFFLINE)
```

**变量表**:

| 变量 | 类型 | 单位 | 来源 | 范围 |
|------|------|------|------|------|
| `current_system_time` | float | 秒 | `Time.get_unix_time_from_system()` | >= 0 |
| `last_save_system_time` | float | 秒 | Save System（持久化） | >= 0 |
| `raw_offline_duration` | float | 秒 | 计算 | 任意（可能负数） |
| `anomaly_duration` | float | 秒 | 异常修正后 | 0 <= x <= 604800 |
| `offline_duration` | float | 秒 | 最终结果 | 0 <= x <= MAX_ALLOWED_OFFLINE |
| `MAX_FORWARD_JUMP` | int | 秒 | 常量 | 固定 604800（7 天） |
| `MAX_ALLOWED_OFFLINE` | int | 秒 | 调优参数 | 默认 86400（24 小时） |

**示例计算**:

| 场景 | raw_offline_duration | anomaly_duration | offline_duration |
|------|---------------------|------------------|------------------|
| 正常离线 2 小时 | 7200 | 7200 | 7200 |
| 系统时间回退 1 小时 | -3600 | 0 | 0 |
| 系统时间前进 10 天 | 864000 | 604800 | 86400（24h 上限） |
| 离线 30 天 | 2592000 | 604800 | 86400（24h 上限） |
| 正常离线 48 小时 | 172800 | 172800 | 86400（24h 上限） |

---

### Session Duration Calculation

```
session_end_monotonic = Time.get_ticks_msec()  # 毫秒
session_start_monotonic = stored at session start  # 毫秒

raw_session_duration = (session_end_monotonic - session_start_monotonic) / 1000.0

# Apply overflow protection
session_duration = min(raw_session_duration, MAX_SESSION_DURATION)
```

**变量表**:

| 变量 | 类型 | 单位 | 来源 | 范围 |
|------|------|------|------|------|
| `session_end_monotonic` | int | 毫秒 | `Time.get_ticks_msec()` | >= session_start |
| `session_start_monotonic` | int | 毫秒 | 会话启动时存储 | >= 0 |
| `raw_session_duration` | float | 秒 | 计算 | >= 0 |
| `session_duration` | float | 秒 | 最终结果 | 0 <= x <= MAX_SESSION_DURATION |
| `MAX_SESSION_DURATION` | int | 秒 | 常量 | 固定 43200（12 小时） |

**示例计算**:

| 场景 | session_start | session_end | raw_duration | session_duration |
|------|---------------|-------------|--------------|------------------|
| 正常游玩 30 分钟 | 0 | 1800000 | 1800 | 1800 |
| 快速启动退出（5 秒）| 0 | 5000 | 5 | 5 |
| 设备挂起后恢复（15 小时）| 0 | 54000000 | 54000 | 43200（截断） |

---

### Playtime Accumulation

```
accumulated_playtime_seconds = saved_accumulated_playtime_seconds + session_duration
```

**变量表**:

| 变量 | 类型 | 单位 | 来源 | 范围 |
|------|------|------|------|------|
| `saved_accumulated_playtime_seconds` | float | 秒 | Save System | >= 0 |
| `session_duration` | float | 秒 | 本次会话计算 | 0 <= x <= 43200 |
| `accumulated_playtime_seconds` | float | 秒 | 累积结果 | >= 0 |

---

### Anomaly Detection Formulas

**时间回退检测**:
```
backward_check = (current_system_time - last_save_system_time) < 0

if backward_check:
    anomaly_type = "time_backward"
    offline_duration = 0
```

**时间前向跳跃检测**:
```
forward_check = (current_system_time - last_save_system_time) > MAX_FORWARD_JUMP

if forward_check:
    anomaly_type = "time_forward_jump"
    offline_duration = MAX_FORWARD_JUMP  # 先截断到 7 天
```

**会话时长溢出检测**:
```
overflow_check = raw_session_duration > MAX_SESSION_DURATION

if overflow_check:
    anomaly_type = "session_overflow"
    session_duration = MAX_SESSION_DURATION
```

---

### Real-Time Session Duration Query

```
current_monotonic = Time.get_ticks_msec()
session_duration_now = (current_monotonic - session_start_monotonic) / 1000.0
```

- 用于 `get_session_duration()` 实时查询
- 不缓存，每次调用实时计算
- 不应用上限（仅在 Session End 时应用）

## Edge Cases

### Edge Case 1: App Killed Without Warning

**场景**: 移动端 OS 强制终止应用，未触发正常退出流程。

**预期行为**:
- 定期保存机制确保每 60 秒更新一次累积时长
- 下次启动时，离线时长从最后一次保存时间计算
- 丢失的会话时长不超过 60 秒（定期保存间隔）
- 异常不会记录（无法区分强制终止和正常离线）

**处理方式**:
- Save System 的定期保存规则（Rule 1）确保时长定期持久化
- Time Tracking 在定期保存时也更新 `accumulated_playtime_seconds`

**测试**: 强制终止应用 → 重启 → 验证时长损失 <= 60 秒。

---

### Edge Case 2: Time Manipulation — System Clock Forward

**场景**: 玩家修改系统时钟向前跳跃（如从周一跳到下周一）试图获取更多离线收益。

**预期行为**:
- 检测到 `raw_offline_duration > MAX_FORWARD_JUMP`（7 天）
- 离线时长截断到 7 天（604800 秒）
- 再应用 `MAX_ALLOWED_OFFLINE` 上限（24 小时）
- 最终离线时长 = 24 小时，与正常离线一致
- 记录异常到 `anomaly_count`

**处理方式**:
- 异常检测规则确保极端跳跃被截断
- 双重上限确保即使 7 天跳跃也只给 24 小时收益
- MVP 不惩罚异常，但记录供未来分析

**测试**: 设置系统时间前进 10 天 → 验证离线时长 = 24 小时，`anomaly_count = 1`。

---

### Edge Case 3: Time Manipulation — System Clock Backward

**场景**: 玩家修改系统时钟向后回退（如从周五退回到周一）试图重复获取收益或隐藏上次保存时间。

**预期行为**:
- 检测到 `current_system_time < last_save_system_time`
- 离线时长设为 0（不给任何离线收益）
- 记录异常到 `anomaly_count`
- 玩家不会获得额外收益，也不会损失已保存数据

**处理方式**:
- 时间回退是最明显的作弊行为，严格处理
- 离线时长 = 0 是安全的选择（不给收益，不报错）

**测试**: 设置系统时间回退 1 小时 → 验证离线时长 = 0，`anomaly_count = 1`。

---

### Edge Case 4: First Session — New Game

**场景**: 新玩家首次启动，无存档数据。

**预期行为**:
- Save System 返回默认值（见 Save System Rule 7）
- `last_save_system_time = 0`（或当前时间）
- `accumulated_playtime_seconds = 0`
- 离线时长计算结果为 0（新玩家无离线）
- 初始化当前时间作为会话起点

**处理方式**:
- 使用 Save System 定义的新游戏默认值
- Time Tracking 不区分新游戏和正常加载（统一处理）

**测试**: 删除存档启动 → 验证 `get_offline_duration() = 0`, `get_playtime() = 0`。

---

### Edge Case 5: Session Duration Overflow

**场景**: 设备挂起（如手机放口袋很久）导致单调时间累积过长。

**预期行为**:
- 检测到 `raw_session_duration > MAX_SESSION_DURATION`（12 小时）
- 截断会话时长到 12 小时
- 记录异常（`anomaly_count += 1`）
- 累积时长正常更新（使用截断后的值）

**处理方式**:
- 单调时间在设备挂起时可能继续累积
- 12 小时上限防止极端情况（不可能连续游玩 12 小时）
- 异常记录帮助识别设备问题

**测试**: 模拟单调时间前进 15 小时 → 验证会话时长 = 12 小时。

---

### Edge Case 6: Multiple Anomalies in One Session

**场景**: 玩家多次修改系统时钟，或同时触发多种异常。

**预期行为**:
- 每次检测到异常时 `anomaly_count += 1`
- 离线时长计算只执行一次（Session Start）
- 后续时钟修改不影响已计算的离线时长
- 会话时长使用单调时间，不受时钟修改影响

**处理方式**:
- 离线时长在会话开始时就固定（不重新计算）
- 单调时间保证会话时长不受干扰
- 异常计数累积供未来分析

**测试**: 会话中途修改系统时钟 → 验证离线时长不变，会话时长继续正确累积。

---

### Edge Case 7: Very Short Session (< 1 Second)

**场景**: 玩家快速启动并退出游戏，会话时长接近 0。

**预期行为**:
- `session_duration` 计算为 ~0 秒（如 0.5 秒）
- 正常累积（即使接近 0）
- 不触发任何异常或警告
- 离线时长正常计算（下次启动时）

**处理方式**:
- 短会话是正常行为，不特殊处理
- 时长可以是 0（不强制最小值）

**测试**: 启动并立即退出 → 验证累积时长增加约 0 秒，无异常。

---

### Edge Case 8: Monotonic Time Reset (Device Restart)

**场景**: 设备重启导致单调时间从 0 开始。

**预期行为**:
- 这只影响会话时长计算（如果会话跨重启）
- 正常情况下，应用关闭时已触发 Session End
- 如果异常关闭，下次启动是新会话（新单调时间起点）
- 不影响离线时长（使用系统时间）

**处理方式**:
- 单调时间仅在会话内有效，不跨会话
- 每次启动获取新的单调时间起点
- 这是设计预期，不是异常

**测试**: 重启设备后启动 → 验证新会话从单调时间 0 开始，无异常。

## Dependencies

### Upstream Dependencies

| 系统 | 依赖类型 | 说明 |
|------|----------|------|
| **Save System** | Hard | 持有 `time_tracking` 数据结构；提供加载接口；接收更新数据并持久化 |

**与 Save System 的交互**:
- Time Tracking **不直接读写文件**，所有数据通过 Save System 接口传递
- Save System Rule 5 定义了 `time_tracking` 数据结构，Time Tracking 使用该结构
- Save System Rule 9 定义了 `load_game()` 和 `save_game()` 接口，Time Tracking 调用这些接口
- Session Start: Time Tracking 从 Save System 获取 `time_tracking` 字段
- Session End: Time Tracking 返回更新后的 `time_tracking` 字段给 Save System

**数据所有权边界**:
| 数据 | 持有者 | 计算者 |
|------|--------|--------|
| `time_tracking.last_save_system_time` | Save System（持久化） | Time Tracking（更新） |
| `time_tracking.last_save_monotonic_offset` | Save System | Time Tracking |
| `time_tracking.accumulated_playtime_seconds` | Save System | Time Tracking |
| `time_tracking.anomaly_count` | Save System | Time Tracking |
| `time_tracking.last_anomaly_timestamp` | Save System | Time Tracking |

---

### Downstream Dependencies

| 系统 | 依赖类型 | 说明 |
|------|----------|------|
| **Offline Reward System（收益计算系统）** | Hard | 需要离线时长和上次保存时间计算离线收益 |
| **UI System** | Soft（未来） | 需要游戏时长显示 HUD（如"已游玩 XX 小时"） |
| **Achievement System** | Soft（未来） | 需要游戏时长解锁成就（如"累计游玩 100 小时"） |

**与 Offline Reward System 的交互**:
- Time Tracking 计算 `offline_duration` 后发出信号 `offline_duration_calculated`
- Offline Reward System 监听信号，使用时长计算收益
- Offline Reward System 也可调用 `get_offline_duration()` 和 `get_last_save_time()`

**依赖验证**:
- 如果 Save System 未初始化，Time Tracking 无法启动（必须先加载存档）
- 如果 Save System 加载失败，Time Tracking 使用默认值（新游戏状态）
- Offline Reward System 必须等待 Time Tracking 计算完成后再计算收益

---

### Dependency Graph

```
                    ┌─────────────────┐
                    │   Save System   │
                    │   (Persistence) │
                    └────────┬────────┘
                             │
                             │ provides time_tracking data
                             ▼
                    ┌─────────────────┐
                    │ Time Tracking   │
                    │   System        │
                    │  (Calculation)  │
                    └────────┬────────┘
                             │
                             │ provides offline_duration
                             ▼
                    ┌─────────────────┐
                    │ Offline Reward  │
                    │   System        │
                    └─────────────────┘
```

**架构说明**:
- Save System 是 Persistence 层的 Foundation（最底层）
- Time Tracking 是 Persistence 层的 Core（逻辑层）
- Offline Reward 是 Feature 层（业务层）
- 依赖方向：Foundation → Core → Feature（单向）

## Tuning Knobs

| 调优参数 | 默认值 | 范围 | 单位 | 说明 |
|----------|--------|------|------|------|
| `MAX_ALLOWED_OFFLINE` | 86400 | 3600 - 172800 | 秒 | 离线收益最大时长（默认 24 小时）；影响玩家回归时的收益上限 |
| `MAX_FORWARD_JUMP` | 604800 | 固定 | 秒 | 时间前向跳跃检测上限（7 天）；超出视为异常并截断 |
| `MAX_SESSION_DURATION` | 43200 | 21600 - 86400 | 秒 | 会话时长上限（默认 12 小时）；防止设备挂起导致溢出 |
| `ANOMALY_THRESHOLD` | 60 | 30 - 300 | 秒 | 会话内时间变化阈值；用于检测会话期间的时钟修改（MVP 仅记录） |
| `MAX_ANOMALY_COUNT` | 10 | 5 - 50 | 次 | 异常计数上限；超出后可采取行动（MVP 仅记录，未来可警告或惩罚） |

**调优参数详解**:

### MAX_ALLOWED_OFFLINE（离线收益上限）

**默认**: 24 小时（86400 秒）

**影响**:
- 玩家离线超过此时长时，收益不再累积
- 防止玩家长期不玩后获得过多收益（破坏"掌控节奏"）
- 同时鼓励玩家定期回归（每 24 小时收益上限）

**调优建议**:
- **增加**（如 48 小时）: 适合鼓励长周期玩家的游戏
- **减少**（如 12 小时）: 适合鼓励每日登录的游戏
- **注意事项**: 过高会破坏游戏平衡；过低会让回归玩家失望

**参考**: 梦幻西游手游离线挂机上限约 8-12 小时

---

### MAX_FORWARD_JUMP（时间跳跃上限）

**默认**: 7 天（604800 秒）

**影响**:
- 检测系统时间异常跳跃的上限
- 超出此值的跳跃被截断并记录异常
- 是硬编码的安全上限，不建议调整

**调优建议**:
- **不建议修改**: 7 天是合理的"最大可能离线时间"
- 如果修改，必须与 `MAX_ALLOWED_OFFLINE` 协调（前者不应小于后者）

---

### MAX_SESSION_DURATION（会话时长上限）

**默认**: 12 小时（43200 秒）

**影响**:
- 单次会话最大累积时长
- 防止设备挂起或异常导致的时长溢出
- 超出后截断并记录异常

**调优建议**:
- **增加**（如 24 小时）: 允许更长会话，但风险更高
- **减少**（如 6 小时）: 更严格，防止异常累积
- **注意事项**: 正常玩家极少连续游玩超过 6 小时

---

### ANOMALY_THRESHOLD（异常阈值）

**默认**: 60 秒

**影响**:
- 会话内系统时间变化超过此阈值时记录异常
- 用于检测会话期间的时钟修改
- MVP 仅记录，不影响游戏逻辑

**调优建议**:
- **增加**: 更宽松，减少误报（网络时间同步可能导致微小变化）
- **减少**: 更严格，更敏感检测作弊
- **注意事项**: 60 秒足够宽松，避免误报

---

### MAX_ANOMALY_COUNT（异常计数上限）

**默认**: 10 次

**影响**:
- 玩家累积异常达到此值时可采取行动
- MVP 仅记录，未来版本可考虑：
  - 显示警告信息
  - 减少离线收益
  - 限制某些功能

**调优建议**:
- MVP 不需要调整（不执行任何惩罚）
- 未来版本需根据数据分析确定合适值

---

**配置文件位置**:
- 建议存放于 `assets/data/config/time_tracking_config.json`
- 或作为 Save System 配置的一部分

**示例配置**:
```json
{
  "MAX_ALLOWED_OFFLINE": 86400,
  "MAX_FORWARD_JUMP": 604800,
  "MAX_SESSION_DURATION": 43200,
  "ANOMALY_THRESHOLD": 60,
  "MAX_ANOMALY_COUNT": 10
}
```

## Acceptance Criteria

### AC-1: Session Time Initialization

**GIVEN** 游戏启动时 Save System 已加载存档数据
**WHEN** TimeTrackingManager 初始化
**THEN** 必须捕获 `session_start_system_time` 和 `session_start_monotonic`
**AND** 从 Save System 获取 `last_save_system_time`, `accumulated_playtime_seconds`
**AND** 计算 `offline_duration` 并发出信号 `offline_duration_calculated`

**Pass**: 所有时间变量已初始化，离线时长已计算。
**Fail**: 时间变量未设置或离线时长未计算。

---

### AC-2: Offline Duration Calculation — Normal Case

**GIVEN** 上次保存时间为 2 小时前（`last_save_system_time = T - 7200`）
**WHEN** 当前系统时间 `current_system_time = T`
**THEN** 离线时长 `offline_duration = 7200`（2 小时）
**AND** `anomaly_count` 不增加

**Pass**: 离线时长正确为 7200 秒。
**Fail**: 离线时长不正确或异常计数增加。

---

### AC-3: Offline Duration Calculation — Time Backward

**GIVEN** 上次保存时间为 `last_save_system_time = T`
**WHEN** 当前系统时间 `current_system_time = T - 3600`（回退 1 小时）
**THEN** 离线时长 `offline_duration = 0`
**AND** `anomaly_count += 1`
**AND** `last_anomaly_timestamp` 更新为当前时间
**AND** 发出信号 `anomaly_detected("time_backward")`

**Pass**: 离线时长为 0，异常计数增加。
**Fail**: 离线时长为负数，或异常未记录。

---

### AC-4: Offline Duration Calculation — Time Forward Excessive

**GIVEN** 上次保存时间为 `last_save_system_time = T`
**WHEN** 当前系统时间 `current_system_time = T + 864000`（前进 10 天）
**THEN** 离线时长 `offline_duration = MAX_ALLOWED_OFFLINE`（24 小时）
**AND** `anomaly_count += 1`
**AND** 发出信号 `anomaly_detected("time_forward_jump")`

**Pass**: 离线时长截断到 24 小时，异常计数增加。
**Fail**: 离线时长为 10 天（604800 秒），或异常未记录。

---

### AC-5: Offline Duration Calculation — Over MAX_ALLOWED_OFFLINE

**GIVEN** 上次保存时间为 48 小时前（`last_save_system_time = T - 172800`）
**WHEN** 当前系统时间 `current_system_time = T`
**THEN** 离线时长 `offline_duration = MAX_ALLOWED_OFFLINE`（24 小时）
**AND** `anomaly_count` 不增加（非异常，正常上限）

**Pass**: 离线时长截断到 24 小时上限。
**Fail**: 离线时长为 48 小时（超出上限）。

---

### AC-6: Playtime Accumulation

**GIVEN** 游玩 10 分钟后游戏退出
**WHEN** TimeTrackingManager 执行 Session End 流程
**THEN** `accumulated_playtime_seconds` 增加 ~600 秒（10 分钟）
**AND** 更新后的数据返回给 Save System 持久化

**Pass**: 累积时长增加正确值（误差 < 1 秒）。
**Fail**: 累积时长不增加或增加错误值。

---

### AC-7: Real-Time Session Duration Query

**GIVEN** 游戏已运行 5 分钟
**WHEN** 调用 `get_session_duration()`
**THEN** 返回值 ~300 秒（5 分钟）
**AND** 每秒调用返回值递增约 1 秒

**Pass**: 返回值实时更新，反映当前会话时长。
**Fail**: 返回值固定不变或不正确。

---

### AC-8: Query Interface — All Methods

**GIVEN** TimeTrackingManager 已初始化
**WHEN** 调用以下方法:
- `get_offline_duration()`
- `get_playtime()`
- `get_last_save_time()`
- `get_session_duration()`
- `get_anomaly_count()`
- `has_time_anomaly()`

**THEN** 所有方法返回 >= 0 的值
**AND** 返回类型正确（float 或 int 或 bool）
**AND** 不抛出异常或崩溃

**Pass**: 所有方法返回正确类型和范围。
**Fail**: 任何方法返回负数、错误类型或抛出异常。

---

### AC-9: New Game Default Values

**GIVEN** 无存档（新游戏）
**WHEN** TimeTrackingManager 初始化
**THEN** `get_offline_duration() = 0`
**AND** `get_playtime() = 0`
**AND** `get_last_save_time() = 0`（或当前时间，取决于 Save System 默认）
**AND** `get_anomaly_count() = 0`

**Pass**: 新游戏使用正确默认值。
**Fail**: 默认值不正确或不存在。

---

### AC-10: Integration with Save System

**GIVEN** 游戏正常关闭
**WHEN** Time Tracking 完成 Session End 流程
**THEN** Save System 接收到更新后的 `time_tracking` 数据
**AND** Save System 成功持久化数据
**AND** 下次启动时数据正确加载

**Pass**: 数据完整传递并持久化。
**Fail**: 数据未传递或持久化失败。

---

### AC-11: Integration with Offline Reward System

**GIVEN** Time Tracking 完成离线时长计算
**WHEN** 发出信号 `offline_duration_calculated(duration)`
**THEN** Offline Reward System 接收到正确的时长值
**AND** Offline Reward System 正确计算离线收益

**Pass**: 离线时长正确传递给收益系统。
**Fail**: 信号未发出或值不正确。

---

### AC-12: Session Overflow Protection

**GIVEN** 设备挂起导致单调时间累积 15 小时
**WHEN** Time Tracking 计算会话时长
**THEN** `session_duration = MAX_SESSION_DURATION`（12 小时）
**AND** `anomaly_count += 1`
**AND** 发出信号 `anomaly_detected("session_overflow")`

**Pass**: 会话时长截断到上限。
**Fail**: 会话时长为 15 小时（超出上限）。

## Open Questions

1. **异常惩罚机制?**: MVP 仅记录异常，不执行任何惩罚。未来版本可考虑：累积异常超过阈值时减少离线收益，或显示警告提示。决策需要数据分析支持。

2. **游戏时长成就?**: MVP 不实现成就系统。未来版本可添加基于 `accumulated_playtime_seconds` 的成就（如"累计游玩 100 小时"）。需要与 Achievement System 协调。

3. **云同步影响?**: MVP 离线。未来如果实现云同步（iCloud/Google Play Games），时间追踪数据如何跨设备同步？可能需要服务器端时间验证。

4. **多时区支持?**: MVP 使用 UTC，不考虑玩家时区。如果未来需要显示本地时间（如"上次保存于北京时间 XX:XX"），需要额外处理。

5. **实时调试接口?**: MVP 不提供调试接口。未来版本可考虑：开发者模式显示时间追踪状态，便于调试异常检测逻辑。