# 触控输入系统 (Touch Input System)

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: 掌控节奏 + 爽感反馈

## Overview

触控输入系统是游戏的输入处理基础设施层，负责检测、解析和路由所有触摸事件到正确的UI层级和游戏对象。它从屏幕捕获原始触摸事件，识别手势类型（点击、长按、拖拽），将触摸坐标映射到UI布局系统的安全区域坐标系，然后将事件路由到对应的UI元素或游戏系统（按钮点击 → 按钮回调，战斗区域点击 → 战斗系统，拖拽手势 → 滚动列表或特殊交互）。

从玩家视角，触控输入系统让"我点哪里，哪里就响应"成为现实。每次点击按钮都有即时反馈，每次滑动列表都流畅跟随手指，每次长按都触发预期操作。玩家感受的是流畅的掌控感——无需担心"点了没反应"或"点了错误按钮"。触控输入系统支撑支柱"掌控节奏"——玩家可以快速点击推进地牢、长按查看详情、滑动浏览装备列表，所有交互都准确响应。

系统覆盖范围：
- **点击检测**: 单次触摸按下和释放，判定为点击或长按
- **手势识别**: 区分tap（短按）、hold（长按）、swipe（滑动）
- **事件路由**: 根据触摸坐标判断命中哪个UI层级，阻断或传递事件
- **坐标映射**: 将屏幕坐标转换为UI布局系统的安全区域坐标系

系统不定义UI元素的视觉样式（UI布局系统职责），不定义按钮回调逻辑（各下游系统职责），只负责**输入层**——检测、识别、路由。

## Player Fantasy

触控输入系统支撑的核心玩家幻想是：

> **"我的手指是游戏的遥控器"** — 每次触摸屏幕，游戏都能准确理解我的意图。点击按钮？立刻响应。长按查看详情？细节弹出。滑动浏览装备？列表流畅跟随。玩家不需要"瞄准"按钮，不需要"等待"响应——手指触碰即行动，游戏即理解。这种流畅的掌控感让玩家专注于"做什么"而非"怎么操作"。

这支撑支柱**掌控节奏**：
- 玩家可以快速点击推进地牢 —— tap手势快速识别，不等待长按判定
- 玩家可以长按查看装备详情 —— hold手势在预期时间触发详情面板
- 玩家可以滑动浏览装备列表 —— swipe手势流畅滚动，不卡顿
- 玩家可以跳过战斗动画 —— 点击"跳过"按钮即时响应，无需等待动画帧

这支撑支柱**爽感反馈**：
- 每次触摸成功都有视觉/震动反馈确认 —— 点击按钮触发bounce动画和震动脉冲
- 手势识别准确让玩家感受"我掌控了" —— 正确区分tap和hold，无误触

这支撑支柱**稳定成长**：
- 输入响应一致性 —— 每次点击相同按钮都产生相同结果，无随机响应延迟
- 操作可预期 —— 玩家知道"长按多久会触发详情"，知道"滑动多快会切换"

**参考**: 梦幻西游手游 —— 触控响应流畅，按钮点击即时反馈；Clicker Heroes —— 快速点击推进的核心交互依赖精准的tap检测。

**Direct system**: 玩家直接与触控输入互动——每次点击、每次滑动、每次长按都是与这个系统的交互。触控输入是玩家与游戏的核心桥梁，玩家每秒都在与它交互。

## Detailed Design

### Core Rules

#### Rule 1: Touch Event Detection — Capture Raw Screen Touch

系统监听Godot的 `InputEventScreenTouch` 和 `InputEventScreenDrag` 事件：

| Event Type | Godot Class | Trigger Condition |
|------------|-------------|-------------------|
| Touch Down | `InputEventScreenTouch` (pressed=true) | 手指首次触碰屏幕 |
| Touch Up | `InputEventScreenTouch` (pressed=false) | 手指离开屏幕 |
| Touch Move | `InputEventScreenDrag` | 手指在屏幕上移动（拖拽） |

**检测流程**:
1. 在UI Root节点注册 `_input(event)` 或 `_unhandled_input(event)`
2. 过滤非触摸事件（键盘、鼠标）
3. 记录触摸开始时间戳和初始位置
4. 跟踪拖拽距离和时间

---

#### Rule 2: Gesture Classification — Tap/Hold/Swipe Detection

**手势分类阈值**:

| Gesture | Detection Condition | Threshold |
|---------|---------------------|-----------|
| **Tap** | Touch duration < TAP_DURATION_MAX 且 drag distance < SWIPE_DISTANCE_MIN | 短按快速释放 |
| **Hold** | Touch duration ≥ HOLD_DURATION_MIN 且仍在屏幕上 | 长按触发 |
| **Swipe** | Drag distance ≥ SWIPE_DISTANCE_MIN | 滑动距离超阈值 |

**阈值参数** (Tuning Knobs):
- `TAP_DURATION_MAX`: 300ms — 超过此时间不判定为tap
- `HOLD_DURATION_MIN`: 500ms — 长按触发时间
- `SWIPE_DISTANCE_MIN`: 30px — 滑动判定最小距离

**分类流程**:
```
On TouchDown:
  start_time = current_time
  start_position = touch_position
  gesture = "pending"

On TouchMove:
  drag_distance = |touch_position - start_position|
  if drag_distance >= SWIPE_DISTANCE_MIN:
    gesture = "swipe"

On TouchUp:
  duration = current_time - start_time
  if gesture == "pending":
    if duration < TAP_DURATION_MAX:
      gesture = "tap"
    else:
      gesture = "hold_candidate" (hold在TouchDown时已触发)
```

---

#### Rule 3: Coordinate Mapping — Safe Area Offset

触摸坐标从屏幕坐标系映射到UI布局系统的安全区域坐标系：

**映射公式**:
```
safe_area_offset_top = UILayoutSystem.get_hud_top_bar_safe_rect().position.y
safe_area_offset_bottom = screen_height - UILayoutSystem.get_hud_bottom_bar_safe_rect().end.y

mapped_y = touch_y  # 通常不需要偏移，因为Godot坐标已是屏幕坐标
```

**坐标使用**: 
- 触摸坐标直接用于命中检测 (`Control.get_global_rect().has_point(touch_position)`)
- UI布局系统已处理安全区域，触摸坐标无需额外偏移

---

#### Rule 4: Event Routing — Layer Priority and Target Detection

**路由优先级** (从高到低):

| Priority | Layer | Routing Behavior |
|----------|-------|------------------|
| 1 (Highest) | ModalLayer | 如果Modal显示，事件只路由到Modal内的Control节点 |
| 2 | ToastLayer | Toast通知可接收点击（关闭通知） |
| 3 | HUDLayer | HUD按钮接收点击，战斗区域点击传递到GameplayLayer |
| 4 | GameplayLayer | 战斗区域点击路由到战斗系统 |
| 5 (Lowest) | BackgroundLayer | 背景不接收点击事件 |

**命中检测流程**:
1. 获取触摸坐标 `touch_position`
2. 从高优先级Layer开始遍历
3. 对每个Layer内的Control节点调用 `get_global_rect().has_point(touch_position)`
4. 找到首个命中节点 → 触发该节点的 `gui_input` 信号
5. 如果ModalLayer激活但触摸在Modal外 → 忽略事件（modal blocking）

---

#### Rule 5: Modal Layer Input Blocking — HUD Ignore When Modal Active

当Modal面板显示时，HUD和Gameplay层的按钮输入被阻断：

**阻断机制**:
- Modal显示时，设置HUDLayer和GameplayLayer的 `mouse_filter = MOUSE_FILTER_IGNORE`
- Modal关闭时，恢复 `mouse_filter = MOUSE_FILTER_STOP`
- 这确保Modal显示时，玩家点击HUD按钮不会意外触发

**例外**: ToastLayer不受Modal阻断（紧急通知可关闭）

---

#### Rule 6: Touch Target Validation — Minimum Size Check

系统验证触摸目标满足最小尺寸要求：

**验证流程**:
1. 获取UI元素的 `get_global_rect().size`
2. 计算 `effective_touch_size = element_size * ui_scale_factor`
3. 验证 `effective_touch_size >= min_touch_target` (44pt iOS / 48dp Android)
4. 如果不足 → 记录警告日志，元素仍可接收点击但用户体验可能受影响

**设计约束**: 此规则在开发阶段验证，非运行时强制放大（UI布局系统已确保设计尺寸满足最小要求）

---

#### Rule 7: Touch Feedback Trigger — Signal Emission

每次成功的触摸事件触发反馈信号：

| Event | Signal Emitted | Target System |
|-------|----------------|---------------|
| Tap detected | `touch_tap(position, target)` | 震动反馈系统, 视觉反馈系统 |
| Tap on button | `button_clicked(position)` (conditional) | 视觉反馈系统, 音效系统 |
| Hold detected | `touch_hold(position, target)` | 震动反馈系统 |
| Swipe detected | `touch_swipe(direction, distance)` | 滚动列表系统 |

**按钮点击信号**:
当 `touch_tap` 的目标节点为按钮类型（Control节点且可点击）时，额外发出 `button_clicked(position)` 信号：
```gdscript
func on_tap_detected(position: Vector2, target: Control):
    emit_signal("touch_tap", position, target.name)
    if target is Button or target.clickable:
        emit_signal("button_clicked", position)
```

**反馈系统订阅**: 震动反馈系统和视觉反馈系统订阅 `touch_tap` 和 `button_clicked` 信号，触发相应的震动和动画反馈。音效系统订阅 `button_clicked` 信号播放UI点击音效。

---

### States and Transitions

触控输入系统有以下状态：

| State | Description | Entry Condition | Exit Condition |
|-------|-------------|-----------------|----------------|
| **Idle** | 无触摸活动 | 初始状态 / TouchUp后 | TouchDown事件 |
| **TouchPending** | 触摸开始，等待手势分类 | TouchDown | Tap/Hold/Swipe判定 |
| **TapDetected** | 短按释放，判定为点击 | TouchUp + duration < TAP_MAX | 事件路由完成 → Idle |
| **HoldDetected** | 长按阈值达到 | duration ≥ HOLD_MIN | TouchUp → Idle |
| **SwipeDetected** | 滑动距离超阈值 | drag_distance ≥ SWIPE_MIN | TouchUp → Idle |
| **Routing** | 事件正在路由到目标 | 手势判定完成 | 目标回调完成 → Idle |

**状态转换图**:
```
Idle → TouchPending (TouchDown)
TouchPending → TapDetected (TouchUp, short duration)
TouchPending → HoldDetected (duration >= HOLD_MIN)
TouchPending → SwipeDetected (drag_distance >= SWIPE_MIN)
TapDetected → Routing → Idle
HoldDetected → Routing → Idle (on TouchUp)
SwipeDetected → Routing → Idle (on TouchUp)
```

---

### Interactions with Other Systems

| System | Direction | Interface | Data Flow |
|--------|-----------|-----------|-----------|
| **UI布局系统** (Upstream) | Inbound | `get_hud_top_bar_safe_rect()`, `get_hud_bottom_bar_safe_rect()`, `get_gameplay_area_rect()` | 提供安全区域坐标和层级容器 |
| **震动反馈系统** (Downstream) | Outbound | Signal: `touch_tap(position)`, `touch_hold(position)` | 触控触发震动反馈 |
| **视觉反馈系统** (Downstream) | Outbound | Signal: `touch_tap(position)` | 触控触发视觉bounce动画 |
| **战斗系统** (Downstream) | Outbound | Signal: `touch_combat_area(position)` | 战斗区域点击传递 |
| **装备槽系统** (Downstream) | Outbound | Signal: `touch_equipment_slot(slot_id)` | 装备槽点击传递 |
| **装备强化系统** (Downstream) | Outbound | Signal: `touch_enhance_button()` | 强化按钮点击传递 |
| **地牢推进系统** (Downstream) | Outbound | Signal: `touch_advance_button()` | 推进按钮点击传递 |

## Formulas

### Formula 1: Tap Duration Threshold

Tap手势的最大持续时间阈值：

`tap_duration = current_time - touch_start_time`

**判定条件**: `tap_duration < TAP_DURATION_MAX` → Tap手势

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| touch_start_time | `t_start` | float | ms | 触摸按下时的时间戳 |
| current_time | `t_curr` | float | ms | 触摸释放时的时间戳 |
| tap_duration | `dur` | float | 0–300ms | 触摸持续时间 |
| TAP_DURATION_MAX | — | int | 300ms (constant) | Tap判定最大持续时间阈值 |

**Output Range:** 0ms (瞬间点击) to 300ms (边界tap)
**Example:** 玩家在150ms内按下并释放 → `dur = 150ms < 300ms` → Tap ✓

---

### Formula 2: Hold Duration Threshold

Hold手势的最小持续时间阈值：

`hold_duration = current_time - touch_start_time`

**判定条件**: `hold_duration ≥ HOLD_DURATION_MIN` → Hold手势触发

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| touch_start_time | `t_start` | float | ms | 触摸按下时的时间戳 |
| current_time | `t_curr` | float | ms | 当前时间（仍在触摸） |
| hold_duration | `dur` | float | 500ms+ | 触摸持续时间 |
| HOLD_DURATION_MIN | — | int | 500ms (constant) | Hold触发最小持续时间阈值 |

**Output Range:** 500ms (最小hold) to 无上限（玩家持续长按）
**Example:** 玩家按下后保持550ms → `dur = 550ms ≥ 500ms` → Hold触发

---

### Formula 3: Swipe Distance Threshold

Swipe手势的最小滑动距离阈值：

`swipe_distance = |current_position - touch_start_position|`

**判定条件**: `swipe_distance ≥ SWIPE_DISTANCE_MIN` → Swipe手势

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| touch_start_position | `p_start` | Vector2 | px | 触摸按下时的屏幕坐标 |
| current_position | `p_curr` | Vector2 | px | 当前触摸坐标（拖拽中） |
| swipe_distance | `dist` | float | 0–500px+ | 滑动距离（欧几里得距离） |
| SWIPE_DISTANCE_MIN | — | int | 30px (constant) | Swipe判定最小距离阈值 |

**Output Range:** 0px (无移动) to 屏幕宽度（极端滑动）
**Example:** 玩家从(100, 200)滑动到(150, 200) → `dist = 50px ≥ 30px` → Swipe ✓

---

### Formula 4: Swipe Direction Calculation

Swipe方向判定（用于滚动列表）：

`swipe_direction = atan2(delta_y, delta_x)` → 判定为 horizontal/vertical/up/down

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| delta_x | `dx` | float | px | 水平移动距离 |
| delta_y | `dy` | float | px | 垂直移动距离 |
| swipe_direction | `dir` | float | -π–π rad | 滑动角度 |

**Direction Mapping:**
| Angle Range | Direction | Use Case |
|-------------|-----------|----------|
| -π/4 to π/4 | Right | 列表向右滚动（罕见） |
| π/4 to 3π/4 | Down | 列表向下滚动 |
| -3π/4 to -π/4 | Up | 列表向上滚动 |
| 3π/4 to π 或 -π to -3π/4 | Left | 列表向左滚动（罕见） |

**MVP使用**: 主要是Up/Down方向用于装备列表滚动。

---

### Formula 5: Touch Target Validation (Reference from UI布局系统)

触摸目标有效尺寸验证（引用UI布局系统公式）：

`effective_touch_size = element_size * ui_scale_factor`

**判定条件**: `effective_touch_size >= min_touch_target`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| element_size | `es` | float | px | UI元素在设计分辨率下的尺寸 |
| ui_scale_factor | `scale` | float | 1.0–1.33 | UI缩放比例（来自UI布局系统） |
| effective_touch_size | `ets` | float | px | 元素在当前屏幕上的实际尺寸 |
| min_touch_target_ios | — | int | 44pt (constant) | iOS最小触摸尺寸 |
| min_touch_target_android | — | int | 48dp (constant) | Android最小触摸尺寸 |

**Output Range:** 应满足 `ets >= 44pt` (iOS) 或 `ets >= 48dp` (Android)
**Note:** 此公式在UI布局系统已定义，触控输入系统引用进行验证。

## Edge Cases

### Touch Detection Edge Cases

- **If 多点触摸同时发生 (two fingers touch)**: 只处理首个触摸点，忽略后续触摸。Rationale: MVP是单触控游戏，多触控场景极少；只处理首触确保核心交互不被打断。

- **If 触摸按下但未释放 (用户忘记松手)**: 500ms后触发Hold手势，继续等待TouchUp。无超时强制释放（用户可能有意长按）。Rationale: 自然行为，用户最终会松手或触发Hold。

- **If TouchDown事件丢失 (系统异常)**: 无法检测后续手势。如果TouchUp事件到达但无匹配TouchDown，忽略事件并记录警告。Rationale: 异常情况不应触发假响应。

- **If 触摸坐标超出屏幕范围 (edge case)**: Godot API保证坐标在屏幕内；如果异常值，clamp到屏幕边界。Rationale: 防御性处理，确保命中检测不崩溃。

### Gesture Classification Edge Cases

- **If Tap和Hold阈值同时满足 (duration = 500ms, 恰好边界)**: Hold优先判定（Hold在500ms时触发，Tap需<300ms）。无冲突。Rationale: Hold阈值高于Tap，时间上不会同时满足。

- **If Tap和Swipe同时满足 (duration < 300ms, distance > 30px)**: Swipe优先判定（滑动意图比点击意图更明确）。Rationale: 快速滑动手势应被识别为Swipe，不是Tap。

- **If Hold和Swipe同时满足 (duration > 500ms, distance > 30px)**: Swipe优先判定（移动意图比静止长按更明确）。Rationale: 用户在长按期间移动手指，意图是滑动而非查看详情。

- **If 触摸在ModalLayer和ToastLayer边界**: ToastLayer优先级高于Modal（紧急通知可关闭）。如果触摸命中ToastLayer元素，触发Toast关闭；否则路由到Modal。Rationale: Toast是紧急信息，需要可关闭。

### Event Routing Edge Cases

- **If 触摸在ModalLayer外但Modal激活**: 事件被忽略（modal blocking），HUD和Gameplay按钮不响应。Rationale: Modal全屏时，玩家应专注于Modal内容，不应意外触发HUD操作。

- **If 触摸命中无回调的UI元素**: 事件被消费但不触发任何回调。记录DEBUG日志（开发阶段检测未绑定回调的按钮）。Rationale: 防止事件穿透到下层，但不执行空操作。

- **If 触摸命中多个重叠UI元素**: 命中检测按z_index排序，首个命中元素接收事件。Rationale: 上层元素遮挡下层，符合视觉层级预期。

- **If Modal关闭动画进行中时触摸发生**: 动画期间Modal仍激活，事件路由到Modal。动画完成后恢复HUD响应。Rationale: 动画期间Modal仍是当前状态，防止动画中断意外触发HUD。

### Touch Target Edge Cases

- **If 触摸目标尺寸小于最小阈值**: 元素仍接收点击（不阻止），但记录WARNING日志提示UI设计问题。Rationale: UI布局系统应在设计阶段验证尺寸；运行时不强制阻断以避免功能缺失。

- **If 触摸坐标刚好在按钮边界**: `has_point()` 使用像素级边界，边界点视为命中。Rationale: 精确边界检测，无模糊区域。

- **If 触摸命中禁用状态按钮 (disabled button)**: 事件被消费但不触发回调。按钮视觉状态为灰色，触摸无响应。Rationale: 禁用按钮不应触发功能，但消费事件防止穿透。

### Feedback Edge Cases

- **If 震动反馈系统不可用 (设备不支持)**: 触控信号仍发射，震动系统处理静默失败。触控系统不阻塞。Rationale: 触控核心功能不受震动可选功能影响。

- **If 视觉反馈系统订阅失败**: 触控信号发射但无bounce动画。触控系统记录订阅失败警告，但不中断触摸处理。Rationale: 触控核心功能不受视觉可选功能影响。

- **If 快速连续点击 (spamming tap)**: 每次Tap独立触发回调，不合并或阻止。回调系统自行处理重复请求（如防止重复强化）。Rationale: 触控系统只检测手势，不判断回调有效性。

### System State Edge Cases

- **If UI布局系统初始化失败**: 触控系统使用fallback安全区域值（`sa_top = 44`, `sa_bot = 34`）。坐标映射使用fallback，命中检测正常进行。Rationale: UI布局失败不应阻断所有交互。

- **If 游戏暂停时触摸发生**: 触控系统暂停处理，事件队列累积。恢复时处理最新事件，旧事件丢弃。Rationale: 暂停期间不响应触摸，防止意外操作。

## Dependencies

### Upstream Dependencies (Required for TouchInputSystem)

| System | Dependency Type | Interface | Critical? |
|--------|----------------|-----------|-----------|
| **UI布局系统** | Hard | `get_hud_top_bar_safe_rect()`, `get_hud_bottom_bar_safe_rect()`, `get_gameplay_area_rect()`, layer containers | Yes — TouchInputSystem cannot route events without layer hierarchy |

### Horizontal Dependencies (Parallel systems)

| System | Dependency Type | Interface | Critical? |
|--------|----------------|-----------|-----------|
| **Godot Input API** | Hard | `InputEventScreenTouch`, `InputEventScreenDrag`, `_input()` | Yes — Built-in engine API, always available |

### Downstream Dependencies (Systems that depend on TouchInputSystem)

| System | Dependency Type | Interface | Status |
|--------|----------------|-----------|--------|
| **震动反馈系统** | Soft | Signal: `touch_tap(position)`, `touch_hold(position)` | Approved |
| **视觉反馈系统** | Soft | Signal: `touch_tap(position)`, `button_clicked(position)` | Designed |
| **音效系统** | Soft | Signal: `button_clicked(position)` | Designed (Vertical Slice) |
| **战斗系统** | Hard | Signal: `touch_combat_area(position)` | Designed |
| **装备槽系统** | Hard | Signal: `touch_equipment_slot(slot_id)` | Designed |
| **装备强化系统** | Hard | Signal: `touch_enhance_button()` | Designed |
| **地牢推进系统** | Hard | Signal: `touch_advance_button()` | Designed |

### Interface Contracts

TouchInputSystem guarantees these contracts to downstream systems:

1. **Gesture Signals**: Every detected Tap/Hold/Swipe emits corresponding signal with position and target metadata.

2. **Event Consumption**: Touch events are consumed (not passed to `_unhandled_input`) when successfully routed to a UI element.

3. **Modal Blocking**: When ModalLayer is active, HUD and Gameplay layer events are blocked — no signals emitted for those layers.

4. **State Consistency**: TouchInputSystem maintains consistent state (Idle → TouchPending → TapDetected → Routing → Idle) with no orphan states.

### Dependency Graph

```
    [Godot Input API] ────→ [TouchInputSystem] ────→ [震动反馈系统]
                                    │                       │
                                    │                       ↓
                                    +──────────────────→ [视觉反馈系统]
                                    │
                                    +──────────────────→ [战斗系统]
                                    │
                                    +──────────────────→ [装备槽系统]
                                    │
                                    +──────────────────→ [装备强化系统]
                                    │
                                    +──────────────────→ [地牢推进系统]
                                    ↑
                            [UI布局系统]
```

### Dependency Notes

- **UI布局系统**: TouchInputSystem queries layer hierarchy and safe area rects from UILayoutSystem. If UILayoutSystem is unavailable, fallback values are used.

- **震动反馈系统**: TouchInputSystem emits `touch_tap` and `touch_hold` signals. VibrationFeedbackSystem subscribes to trigger tactile feedback.

- **视觉反馈系统**: TouchInputSystem emits `touch_tap` signal. VisualFeedbackSystem subscribes to trigger bounce animations.

- **Gameplay systems (战斗, 装备槽, etc.)**: TouchInputSystem routes touch events to these systems via signals. Each system defines its own callback logic.

## Tuning Knobs

| Knob | Type | Range | Default | Effect |
|------|------|-------|---------|--------|
| `TAP_DURATION_MAX` | int | 200–500ms | 300ms | Tap判定最大持续时间。Higher = 更宽松的tap判定，更多点击被识别为tap而非hold；Lower = 更严格，快速点击才能触发tap。 |
| `HOLD_DURATION_MIN` | int | 400–800ms | 500ms | Hold触发最小持续时间。Higher = 需要更长长按才能触发；Lower = 快速触发hold，可能误判tap为hold。 |
| `SWIPE_DISTANCE_MIN` | int | 20–50px | 30px | Swipe判定最小滑动距离。Higher = 需要更大幅度滑动才能触发；Lower = 轻微移动即判定swipe，可能误判tap为swipe。 |
| `MODAL_BLOCKING_ENABLED` | bool | true/false | true | Modal显示时是否阻断HUD和Gameplay层输入。true = 专注Modal内容；false = Modal外点击仍触发HUD（不推荐）。 |
| `SAFE_AREA_FALLBACK_TOP` | int | 0–100px | 44px | UI布局系统失败时的顶部安全区域fallback值。 |
| `SAFE_AREA_FALLBACK_BOTTOM` | int | 0–50px | 34px | UI布局系统失败时的底部安全区域fallback值。 |
| `TOUCH_TARGET_MIN_IOS` | int | 44–60pt | 44pt | iOS平台最小触摸目标尺寸（引用UI布局系统常量）。 |
| `TOUCH_TARGET_MIN_ANDROID` | int | 48–64dp | 48dp | Android平台最小触摸目标尺寸（引用UI布局系统常量）。 |
| `GESTURE_PRIORITY_TAP_SWIPE` | String | tap/swipe | swipe | Tap和Swipe同时满足时的优先级。swipe = 滑动意图优先；tap = 点击意图优先（不推荐，可能误判）。 |
| `GESTURE_PRIORITY_HOLD_SWIPE` | String | hold/swipe | swipe | Hold和Swipe同时满足时的优先级。swipe = 滑动意图优先；hold = 长按意图优先（不推荐）。 |
| `MULTITOUCH_POLICY` | String | first/all | first | 多点触摸处理策略。first = 只处理首个触摸；all = 处理所有触摸（MVP不支持）。 |
| `TOUCH_FEEDBACK_SIGNAL_ENABLED` | bool | true/false | true | 是否发射触控反馈信号。true = 震动和视觉系统接收信号；false = 无反馈信号（调试模式）。 |

### Tuning Knob Configuration File

All knobs defined in `assets/data/tuning/touch_input_config.json`:

```json
{
  "version": "1.0.0",
  "gesture_thresholds": {
    "tap_duration_max": 300,
    "hold_duration_min": 500,
    "swipe_distance_min": 30
  },
  "modal_blocking": {
    "enabled": true
  },
  "safe_area_fallback": {
    "top": 44,
    "bottom": 34
  },
  "touch_target_minimum": {
    "ios": 44,
    "android": 48
  },
  "gesture_priority": {
    "tap_swipe": "swipe",
    "hold_swipe": "swipe"
  },
  "multitouch": {
    "policy": "first"
  },
  "feedback": {
    "signal_enabled": true
  }
}
```

### Balance Impact Analysis

| Knob Group | Increased Value Effect | Decreased Value Effect |
|------------|----------------------|------------------------|
| Gesture thresholds | More gestures classified (easier detection) | Fewer gestures classified (stricter detection) |
| Modal blocking | Player focuses on Modal content | Accidental HUD clicks during Modal |
| Safe area fallback | Larger fallback buffer (safer) | Smaller buffer (may overlap with system UI) |
| Touch target minimum | Larger buttons (easier to hit) | Smaller buttons (harder to hit, violates platform guidelines) |

### Safe Tuning Ranges

- **TAP_DURATION_MAX**: 250–350ms is the "comfort zone" where taps are easily detected without confusing with hold.
- **HOLD_DURATION_MIN**: 400–600ms balances quick hold trigger vs. accurate tap detection.
- **SWIPE_DISTANCE_MIN**: 25–40px provides clear swipe intent without requiring exaggerated movement.
- **Platform touch targets**: Must not be lowered below platform guidelines (44pt iOS, 48dp Android).

## Visual/Audio Requirements

### Visual Feedback Triggered by TouchInputSystem

触控输入系统**不直接产生视觉效果**，它通过信号触发下游系统的视觉反馈：

| Touch Event | Visual Effect Triggered | Owner System |
|-------------|------------------------|--------------|
| **Tap detected** | Button bounce animation (scale 1.05x → 1.0x) | 视觉反馈系统 |
| **Hold detected** | Detail panel fade-in | 装备槽系统 (callback) |
| **Swipe detected** | List scroll animation | 装备列表系统 |

**信号发射**: `touch_tap(position, target)` → 视觉反馈系统订阅 → 触发bounce

### Audio Feedback Triggered by TouchInputSystem

触控输入系统**不直接播放音效**，它通过信号触发音效系统：

| Touch Event | Audio Effect Triggered | Owner System |
|-------------|-----------------------|--------------|
| **Tap detected** | Button click sound (soft "tap") | 音效系统 |
| **Hold detected** | Detail open sound (subtle "pop") | 音效系统 |

**信号发射**: `touch_tap(position)` → 音效系统订阅 → 播放对应音效

### TouchInputSystem's Own Visual Requirement

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| **调试可视化** | 开发阶段显示触摸坐标debug overlay（可选） | Dev-only，生产环境禁用 |
| **无生产视觉** | 系统在运行时无可见UI元素 | Infrastructure layer |

## UI Requirements

### System UI Requirements

触控输入系统是基础设施层，**不直接向玩家展示任何UI界面**。

| Requirement | Specification | Priority |
|-------------|---------------|----------|
| **无自有UI** | 系统在运行时无可见元素，不渲染任何Control节点 | — |
| **调试overlay** | 开发阶段可选显示 `TouchDebugOverlay`：当前触摸坐标、手势状态、命中元素名称 | Dev-only |

### Downstream System UI Constraints

触控输入系统定义以下约束，下游UI系统必须遵守：

| Constraint | Specification | Target Systems |
|------------|---------------|----------------|
| **最小触摸尺寸** | 所有可点击元素 `effective_size >= 44pt` (iOS) / `48dp` (Android) | 所有UI系统 |
| **手势响应一致性** | Tap/Hold/Swipe行为由本系统判定，下游系统不自行检测手势 | 所有交互系统 |
| **Modal阻断规则** | Modal显示时，下游系统不应尝试绕过阻断处理意外点击 | 装备强化系统等 |

### Debug Overlay Specification (Dev-only)

如果启用调试overlay，显示以下信息：

| Element | Display |
|---------|---------|
| **触摸坐标** | "Touch: (x, y)" |
| **当前手势状态** | "State: Idle/TapDetected/HoldDetected/SwipeDetected" |
| **命中元素** | "Target: [node_name]" (如果命中UI元素) |
| **命中层级** | "Layer: ModalLayer/HUDLayer/GameplayLayer" |

**显示位置**: 屏幕右上角（避开HUD数值显示区域）
**启用方式**: 设置 `touch_debug_overlay_enabled = true` (config文件)

## Acceptance Criteria

### Gesture Detection Criteria

**AC-F1-01: Tap Detection — Short Duration**
**GIVEN** 触摸持续时间 150ms，滑动距离 0px，**WHEN** TouchUp事件到达，**THEN** 手势判定为Tap。

**AC-F1-02: Tap Detection — Boundary Duration**
**GIVEN** 触摸持续时间 299ms，滑动距离 0px，**WHEN** TouchUp事件到达，**THEN** 手势判定为Tap（<300ms边界）。

**AC-F1-03: Tap Detection — Exceed Threshold**
**GIVEN** 触摸持续时间 350ms，滑动距离 0px，**WHEN** TouchUp事件到达，**THEN** 手势判定为Hold候选（非Tap）。

**AC-F2-01: Hold Detection**
**GIVEN** 触摸持续时间 500ms，仍在屏幕上，**WHEN** 持续时间检测，**THEN** Hold手势触发，发射 `touch_hold` 信号。

**AC-F2-02: Hold Detection — Exceed Threshold**
**GIVEN** 触摸持续时间 800ms，**WHEN** 持续时间检测，**THEN** Hold已触发（500ms时首次触发）。

**AC-F3-01: Swipe Detection — Minimum Distance**
**GIVEN** 滑动距离 30px，**WHEN** TouchMove检测，**THEN** 手势判定为Swipe。

**AC-F3-02: Swipe Detection — Below Threshold**
**GIVEN** 滑动距离 20px，**WHEN** TouchMove检测，**THEN** 手势仍为pending（未达Swipe阈值）。

**AC-F3-03: Swipe Direction — Up**
**GIVEN** 滑动从(100, 300)到(100, 200)（delta_y = -100），**WHEN** 方向计算，**THEN** 方向判定为Up。

**AC-F3-04: Swipe Direction — Down**
**GIVEN** 滑动从(100, 200)到(100, 300)（delta_y = 100），**WHEN** 方向计算，**THEN** 方向判定为Down。

### Gesture Priority Criteria

**AC-PRI-01: Tap vs Swipe Conflict**
**GIVEN** 触摸持续时间 100ms，滑动距离 50px，**WHEN** 手势判定，**THEN** Swipe优先，判定为Swipe而非Tap。

**AC-PRI-02: Hold vs Swipe Conflict**
**GIVEN** 触摸持续时间 600ms，滑动距离 40px，**WHEN** 手势判定，**THEN** Swipe优先，判定为Swipe而非Hold。

### Event Routing Criteria

**AC-ROUT-01: Modal Layer Blocking**
**GIVEN** ModalLayer激活，触摸坐标在ModalLayer外（HUD区域），**WHEN** 事件路由，**THEN** 事件被忽略，HUD按钮无响应。

**AC-ROUT-02: Modal Layer Active**
**GIVEN** ModalLayer激活，触摸坐标命中Modal内按钮，**WHEN** 事件路由，**THEN** 事件路由到Modal按钮，触发按钮回调。

**AC-ROUT-03: HUD Layer Routing**
**GIVEN** ModalLayer未激活，触摸坐标命中HUD按钮，**WHEN** 事件路由，**THEN** 事件路由到HUD按钮，发射对应信号。

**AC-ROUT-04: Gameplay Layer Routing**
**GIVEN** ModalLayer未激活，触摸坐标在战斗区域，**WHEN** 事件路由，**THEN** 事件路由到战斗系统，发射 `touch_combat_area` 信号。

**AC-ROUT-05: Layer Priority**
**GIVEN** ToastLayer和ModalLayer同时有元素，触摸命中ToastLayer通知，**WHEN** 事件路由，**THEN** ToastLayer优先，触发通知关闭。

### Touch Target Criteria

**AC-TARGET-01: Valid Touch Target**
**GIVEN** 按钮尺寸 100px，ui_scale_factor = 1.0，**WHEN** 验证触摸目标，**THEN** `effective_size = 100px >= 44pt` ✓。

**AC-TARGET-02: Invalid Touch Target Warning**
**GIVEN** 按钮尺寸 40px，ui_scale_factor = 1.0，**WHEN** 验证触摸目标，**THEN** `effective_size = 40px < 44pt`，WARNING日志记录。

### State Management Criteria

**AC-STATE-01: Idle to TouchPending**
**GIVEN** 状态Idle，**WHEN** TouchDown事件到达，**THEN** 状态转换到TouchPending。

**AC-STATE-02: TouchPending to TapDetected**
**GIVEN** 状态TouchPending，duration < 300ms，**WHEN** TouchUp事件到达，**THEN** 状态转换到TapDetected。

**AC-STATE-03: TapDetected to Idle**
**GIVEN** 状态TapDetected，**WHEN** 事件路由完成，**THEN** 状态转换到Idle。

**AC-STATE-04: TouchPending to HoldDetected**
**GIVEN** 状态TouchPending，duration >= 500ms，**WHEN** 持续时间检测，**THEN** 状态转换到HoldDetected。

### Signal Emission Criteria

**AC-SIG-01: Tap Signal**
**GIVEN** Tap手势判定，触摸命中按钮，**WHEN** 手势完成，**THEN** 发射 `touch_tap(position, "button_name")` 信号。

**AC-SIG-02: Hold Signal**
**GIVEN** Hold手势判定，**WHEN** Hold触发（500ms），**THEN** 发射 `touch_hold(position)` 信号。

**AC-SIG-03: Swipe Signal**
**GIVEN** Swipe手势判定，方向Up，距离50px，**WHEN** Swipe检测，**THEN** 发射 `touch_swipe("up", 50)` 信号。

### Edge Cases Criteria

**AC-EC-01: Multi-touch Handling**
**GIVEN** 两个手指同时触摸屏幕，**WHEN** TouchDown事件到达，**THEN** 只处理首个触摸点，忽略第二个。

**AC-EC-02: Touch Up Without Down**
**GIVEN** TouchUp事件到达但无匹配TouchDown，**WHEN** 事件处理，**THEN** 忽略事件，记录WARNING日志。

**AC-EC-03: Disabled Button Touch**
**GIVEN** 触摸命中禁用状态按钮，**WHEN** 事件路由，**THEN** 事件被消费，不触发回调。

**AC-EC-04: UI Layout System Fallback**
**GIVEN** UI布局系统初始化失败，**WHEN** 触控系统启动，**THEN** 使用fallback安全区域值 `sa_top = 44, sa_bot = 34`。

## Open Questions

| # | Question | Owner | Target Resolution | Status |
|---|----------|-------|-------------------|--------|
| 1 | Should hold gesture trigger repeatedly (e.g., hold-and-scroll) or only once? | Systems Designer | Before 装备列表系统 design | Open |
| 2 | Should swipe gesture have velocity threshold (fast swipe vs slow drag)? | Systems Designer | Before 装备列表系统 design | Open |
| 3 | Should multi-touch be supported for future features (e.g., pinch zoom)? | Game Designer | Post-MVP feature planning | Open |
| 4 | Should touch input system debounce rapid taps (prevent spam)? | Systems Designer | Before 装备强化系统 design | Open |
| 5 | Should touch events be queued during pause and processed on resume? | Technical Director | During architecture review | Open |
| 6 | Should the system support touch pressure sensitivity (iOS 3D Touch)? | Technical Director | Post-MVP platform feature | Open |
| 7 | Should gesture thresholds be adjustable per-button (some buttons need faster tap)? | UX Designer | Before UI implementation | Open |
| 8 | Should debug overlay be available in production build (hidden toggle)? | Tools Programmer | Before production release | Open |

### Resolution Notes

- **Q1 Decision Framework**: Hold triggers once at threshold. If continuous action needed (scroll), use Swipe + repeated callbacks. Hold = detail view, not continuous action.

- **Q2 Needs UX Input**: Velocity threshold could distinguish "intent to scroll" from "slow drag". For MVP, distance-only is simpler; velocity can be added later.

- **Q4 Needs Coordination**: Debounce policy affects 强化系统's "prevent duplicate enhancement" logic. Touch system detects each tap; callback system handles debounce.