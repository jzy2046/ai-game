# 震动反馈系统 (Vibration Feedback System)

> **Status**: Approved
> **Author**: user + agents
> **Last Updated**: 2026-05-01
> **Implements Pillar**: 爽感反馈

## Overview

震动反馈系统是游戏的触觉反馈基础设施层，负责管理和播放所有震动效果。它提供统一的震动触发接口，让其他系统（视觉反馈系统、战斗系统、强化系统）能够触发震动来强化玩家的进步时刻。震动反馈系统管理震动强度等级、控制震动持续时间、定义震动预设模板，确保移动端震动体验一致且不干扰玩家。

从玩家视角，震动反馈系统是"进步的触觉语言"。每次击败敌人时设备轻微震动、每次强化成功时震动增强、每次获得稀有装备时强烈震动——这些触觉反馈让进步"震"出存在感。震动是游戏支柱"爽感反馈"的核心触觉载体，玩家通过手掌感受到"我变强了"的物理反馈。

MVP阶段震动反馈系统管理以下震动预设：
- **Light Tap**: 轻触 — UI按钮点击、小额金币获得
- **Medium Pulse**: 中等脉冲 — 敌人击败、装备获得
- **Heavy Impact**: 强冲击 — Boss击败、稀有掉落
- **Celebration Burst**: 庆祝震动序列 — 强化成功、地牢房间完成

震动反馈系统使用 Godot 4.6 的 `OS.vibrate()` API 实现，配合震动预设定义震动时长和序列。由于 Godot 内置 API 不支持强度控制，震动强度通过时长和震动序列模拟（短震动=轻，长震动=重，多段震动=冲击）。所有震动预设存储在 `assets/data/config/vibration_config.json` 目录，支持热更新和设计师调整。

> **ADR Note**: 此系统暂无架构决策记录。震动API的实现细节（Android Vibrator vs iOS Taptic Engine、平台权限要求、插件选择）应在实现前通过 `/architecture-decision` 创建ADR，记录跨平台震动策略决策。

## Player Fantasy

震动反馈系统支撑的核心玩家幻想是：

> **"每一次进步都在掌心跳动"** — 震动是游戏对玩家成长的物理确认。当设备震动时，玩家感受到的不是"发生了一个事件"，而是"游戏在为我庆祝"。震动是视觉和听觉的触觉延伸——玩家看到粒子爆发、听到音效、同时感受到设备脉冲——三者叠加让进步"震"入身体感知。

这支撑支柱**爽感反馈**：
- 震动与粒子、音效形成感官三重奏（视觉+听觉+触觉），让进步不可忽视
- 震动是进步的"掌声"——每次震动都是游戏对玩家操作的物理回应
- 多系统叠加时震动"合奏"（Boss击败触发强震动+金币轻震动的节奏序列）

这支撑支柱**稳定成长**：
- 震动永远是正向信号——无"失败震动"、无惩罚性触觉反馈
- 震动强度映射进步量级——+1强化是轻脉冲，+10强化是强冲击，玩家通过震动感知"这次进步很大"

这支撑支柱**掌控节奏**：
- 玩家选择跳过战斗时震动简洁快速，玩家选择观看时震动丰富完整
- 震动不强制等待——震动是进步的伴奏，不是拖慢节奏的障碍
- 可选设置允许玩家调整震动强度（关闭/轻/中/强），支持个人偏好

**参考**: 暗黑破坏神 — 每次击杀后设备震动让"击中"有重量感；梦幻西游手游 — 升级时震动庆祝让里程碑有物理记忆点。

## Detailed Design

### Core Rules

**Rule 1: 震动预设定义**

震动系统提供4种预设模板，每种预设定义震动时长、震动序列（单震/多段）、间隔时间：

| Preset Name | Pattern | Duration(s) | Description | Particle Coordination |
|-------------|---------|-------------|-------------|----------------------|
| **Light Tap** | Single | 50ms | 轻触反馈 | UI Popup Burst (Tier 1) |
| **Medium Pulse** | Single | 150ms | 中等脉冲 | Gold Burst (Tier 1-3) |
| **Heavy Impact** | Double | 200ms + 100ms (gap 50ms) | 强冲击双震 | Gold Burst (Tier 4-5), Rare Drop Glow |
| **Celebration Burst** | Triple | 150ms + 100ms + 200ms (gap 50ms) | 三段庆祝震动序列 | Enhancement Flash, Victory Sparkle |

**强度模拟策略**: Godot API不支持强度参数，通过以下方式模拟：
- 短震动 (50ms) = 轻度强度 (Tier 1-2)
- 中震动 (150ms) = 中度强度 (Tier 3-4)
- 多段震动序列 = 重度强度 (Tier 5-6)

---

**Rule 2: 触发事件映射**

事件触发震动预设，与Particle System事件保持同步：

| Event | Vibration Preset | Duration | Particle Preset | Trigger Source |
|-------|-----------------|----------|-----------------|----------------|
| UI按钮点击 | Light Tap | 50ms | UI Popup Burst Tier 1 | UI系统 |
| 小额金币获得 (<100) | Light Tap | 50ms | Gold Burst Tier 1 | 战斗系统 |
| 中额金币获得 (100-500) | Medium Pulse | 100ms | Gold Burst Tier 2 | 战斗系统 |
| 大额金币获得 (500-1000) | Medium Pulse | 150ms | Gold Burst Tier 3 | 战斗系统 |
| Boss金币 (>1000) | Heavy Impact | 300ms total | Gold Burst Tier 4 | 战斗系统 |
| 敌人击败 (普通) | Medium Pulse | 150ms | Gold Burst Tier 1-2 | 战斗系统 |
| Boss击败 | Heavy Impact | 300ms | Victory Sparkle + Gold Burst | 战斗系统 |
| 稀有装备掉落 | Heavy Impact | 300ms | Rare Drop Glow Tier 3 | 装备掉落系统 |
| 装备强化成功 (+1~+3) | Medium Pulse | 150ms | Enhancement Flash Tier 1-2 | 强化系统 |
| 装备强化成功 (+4~+7) | Heavy Impact | 300ms | Enhancement Flash Tier 3-4 | 强化系统 |
| 装备强化成功 (+8~+10) | Celebration Burst | 450ms | Enhancement Flash Tier 5 | 强化系统 |
| 地牢房间完成 | Medium Pulse | 150ms | Victory Sparkle Tier 3-4 | 地牢推进系统 |
| 全地牢通关 | Celebration Burst | 450ms | Victory Sparkle Tier 5-6 | 地牢推进系统 |

---

**Rule 3: 震动强度分级**

震动强度分级与Particle System的6级Tier对应，通过时长和序列模拟强度：

| Tier | Vibration Pattern | Total Duration | Use Case | Particle Tier Match |
|------|-------------------|---------------|----------|---------------------|
| **1** | Light Tap (50ms) | 50ms | 小额奖励、UI点击 | Particle Tier 1 (8-12粒子) |
| **2** | Medium Pulse (100ms) | 100ms | 中额奖励、普通敌人 | Particle Tier 2 (20-30粒子) |
| **3** | Medium Pulse (150ms) | 150ms | 大额奖励、稀有掉落 | Particle Tier 3 (40-50粒子) |
| **4** | Heavy Impact (300ms) | 300ms | Boss击败、高强化 | Particle Tier 4 (60-80粒子) |
| **5** | Celebration Burst (450ms) | 450ms | 全房间胜利、+10强化 | Particle Tier 5 (80-120粒子) |
| **6** | Celebration Burst Extended (600ms) | 600ms | 全地牢通关、传说掉落 | Particle Tier 6 (120-200粒子) |

---

**Rule 4: 分层叠加规则**

当多个事件同时触发震动时，震动系统使用**合并策略**（不同于粒子系统的分层播放）：

- **合并原则**: 同一时刻多个震动请求 → 选择最高Tier震动，低Tier震动被合并
- **间隔规则**: 两次震动之间最小间隔 = 200ms（避免震动疲劳）
- **示例**: Boss击败触发 Victory Sparkle (Tier 4) + Gold Burst (Tier 2) → 只触发 Tier 4 Heavy Impact震动，Gold Burst震动被合并

**与粒子系统协调**: 粒子系统使用延迟分层播放，震动系统使用合并策略。同一事件触发时：
1. 粒子系统先播高优先级粒子
2. 震动系统触发合并后的最高Tier震动（无延迟）
3. 粒子系统延迟播低优先级粒子时，震动不再触发（已合并）

---

**Rule 5: 震动持续时间限制**

| Constraint | Value | Reason |
|------------|-------|--------|
| **最小震动时长** | 50ms | 低于50ms玩家难以感知 |
| **最大单震时长** | 200ms | iOS Taptic Engine限制 |
| **最大序列总时长** | 600ms | 防止震动过长导致手部不适 |
| **序列内最大段数** | 3段 | 多段震动超过3段会显得混乱 |
| **两次震动最小间隔** | 200ms | 避免震动疲劳 |

---

**Rule 6: 取消与打断规则**

| Trigger | Action | Implementation |
|---------|---------|---------------|
| **场景切换** | 取消当前震动，禁止新震动200ms | `cancel_all()` + cooldown timer |
| **跳过战斗** | 压缩震动序列（只触发第一段） | `set_skip_mode(true)` |
| **震动设置关闭** | 所有震动请求被忽略 | `is_vibration_enabled() == false` |
| **连续震动超频** | 合并后续震动请求 | 距离上次震动<200ms → 合并 |

---

**Rule 7: 技术实现**

震动系统使用Godot 4.6 `OS.vibrate()` API，配合震动队列和合并逻辑：

```gdscript
# VibrationSystem 公共接口
class_name VibrationSystem

## 请求震动
## @param preset: 预设名称 ("light_tap" | "medium_pulse" | "heavy_impact" | "celebration_burst")
## @param tier: 强度等级 (1-6)
## @return: true=成功触发，false=被合并或禁止
func request_vibration(preset: String, tier: int) -> bool

## 取消所有震动（场景切换时调用）
func cancel_all() -> void

## 设置跳过模式（压缩震动序列）
func set_skip_mode(enabled: bool) -> void

## 获取震动设置状态
func is_vibration_enabled() -> bool
```

**序列震动实现**: Godot不支持多段震动API，使用async/await实现序列：
```gdscript
# Heavy Impact: 200ms震动 → 50ms间隔 → 100ms震动
func _play_heavy_impact() -> void:
    OS.vibrate(200)
    await get_tree().create_timer(0.05).timeout
    OS.vibrate(100)
```

---

**Rule 8: 性能与UX约束**

| Constraint | Value | Reason |
|------------|-------|--------|
| **最大震动频率** | 3次/秒 | 防止震动疲劳和电池消耗 |
| **10秒内最大震动次数** | 15次 | 防止连续震动导致手部麻木 |
| **震动队列最大长度** | 5个请求 | 超过5个请求时，低Tier请求被丢弃 |

---

**Rule 9: 震动与粒子同步规则**

震动与粒子在同一事件触发时，遵守**触觉领先原则**：

| Event | Particle Timing | Vibration Timing | Sync Strategy |
|-------|-----------------|------------------|---------------|
| 敌人击败 | Gold Burst立即播放 | Medium Pulse立即触发 | 同步触发 |
| Boss击败 | Victory Sparkle立即 → Gold Burst延迟0.3s | Heavy Impact立即触发（合并） | 震动先触发 |
| 强化成功 | Enhancement Flash立即播放 | Celebration Burst立即触发 | 同步触发 |
| UI点击 | UI Popup Burst立即播放 | Light Tap立即触发 | 同步触发 |

---

**Rule 10: 震动配置存储**

震动预设和参数存储在 `assets/data/config/vibration_config.json`，支持热更新。

### States and Transitions

震动系统状态较简单，主要管理震动队列和冷却：

| State | Description | Transitions |
|-------|-------------|-------------|
| **Idle** | 无震动活动，队列清空 | → Vibrating (收到震动请求) |
| **Vibrating** | 正在播放震动序列 | → Idle (序列完成) / → Cooldown (场景切换调用cancel_all) |
| **Cooldown** | 场景切换后冷却期(200ms) | → Idle (冷却结束) |
| **Disabled** | 震动设置关闭 | → Idle (震动设置开启) |

**状态转换触发条件**:
- Idle → Vibrating: 收到`request_vibration()`调用且间隔>200ms
- Vibrating → Idle: 震动序列完成
- Vibrating → Cooldown: 收到`cancel_all()`调用
- Cooldown → Idle: 200ms冷却结束
- Any → Disabled: `set_vibration_enabled(false)`
- Disabled → Idle: `set_vibration_enabled(true)`

### Interactions with Other Systems

| System | Interaction Type | Description |
|--------|-----------------|-------------|
| **视觉反馈系统** | Downstream (Coordinator) | 视觉反馈系统协调震动+粒子+音效的同步触发，是震动系统的主要调用协调者 |
| **战斗系统** | Upstream (Caller) | 敌人击败时调用`request_vibration("medium_pulse", tier)` |
| **装备强化系统** | Upstream (Caller) | 强化成功时调用`request_vibration("celebration_burst", tier)` |
| **装备掉落系统** | Upstream (Caller) | 稀有掉落时调用`request_vibration("heavy_impact", 3)` |
| **地牢推进系统** | Upstream (Caller) | 房间完成时调用`request_vibration("medium_pulse", tier)`；房间切换时调用`cancel_all()` |
| **UI系统** | Upstream (Caller) | 按钮点击时调用`request_vibration("light_tap", 1)` |
| **粒子系统** | Peer (同步协调) | 同一事件同时触发震动+粒子，由视觉反馈系统协调调用顺序。震动使用合并策略，粒子使用分层延迟策略 |
| **存档系统** | Downstream (Settings) | 存档系统存储玩家震动设置偏好（开启/关闭/强度等级） |

## Formulas

震动系统不像粒子系统有复杂的数量计算公式，主要公式集中在时长计算和合并策略判断。

### Formula 1: 震动时长计算

**目的**: 根据震动预设，计算震动序列各段的时长和总时长。

**公式**:
```
total_duration = sum(segment_duration[i]) + sum(gap_duration[i])
```

**预设常量表**:
| Preset | Segments | Total Duration |
|--------|----------|---------------|
| **Light Tap** | 1段: [50ms] | 50ms |
| **Medium Pulse** | 1段: [100-150ms] | 100-150ms |
| **Heavy Impact** | 2段: [200ms, 100ms], gap: 50ms | 350ms |
| **Celebration Burst** | 3段: [150ms, 100ms, 200ms], gaps: 50ms, 50ms | 550ms |

---

### Formula 2: 金币震动强度计算

**目的**: 根据敌人金币奖励金额，自动计算震动Tier等级（与粒子系统Tier同步）。

**公式**:
```
vibration_tier = clamp(floor(log10(gold_reward)), 1, 5)
```

**变量定义**:
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `gold_reward` | int | 1 - 10000+ | 敌人击败后获得的金币数量 |
| `vibration_tier` | int | 1 - 5 | 输出的震动强度等级 |

**计算示例**:
- gold_reward = 50 → log10(50) ≈ 1.7 → floor → 1 → **Tier 1** (Light Tap)
- gold_reward = 500 → log10(500) ≈ 2.7 → floor → 2 → **Tier 2** (Medium Pulse 100ms)
- gold_reward = 5000 → log10(5000) ≈ 3.7 → floor → 3 → **Tier 3** (Medium Pulse 150ms)

---

### Formula 3: 强化震动强度计算

**目的**: 根据装备强化等级，计算震动Tier等级（与粒子系统同步）。

**公式**:
```
enhancement_vibration_tier = clamp(floor(enhancement_level / 3) + 1, 1, 5)
```

**变量定义**:
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `enhancement_level` | int | 0 - 10 | 装备当前强化等级（+0到+10） |
| `enhancement_vibration_tier` | int | 1 - 5 | 输出的震动强度等级 |

**计算示例**:
- enhancement_level = +1 → 1/3 ≈ 0 → floor → 0 + 1 → **Tier 1** (Medium Pulse 150ms)
- enhancement_level = +5 → 5/3 ≈ 1.7 → floor → 1 + 1 → **Tier 2** (Medium Pulse 150ms)
- enhancement_level = +10 → 10/3 ≈ 3.3 → floor → 3 + 1 → **Tier 4** (Celebration Burst)

---

### Formula 4: 震动间隔判断

**目的**: 判断当前震动请求是否应被合并（距离上次震动时间<最小间隔）。

**公式**:
```
should_merge = (current_time - last_vibration_time) < MIN_INTERVAL
```

**常量定义**:
| Constant | Value | Description |
|----------|-------|-------------|
| `MIN_INTERVAL` | 200ms | 两次震动最小间隔 |

**变量定义**:
| Variable | Type | Description |
|----------|------|-------------|
| `current_time` | float | 当前时间戳（秒） |
| `last_vibration_time` | float | 上次震动触发时间戳 |
| `should_merge` | bool | 输出：是否合并到上次震动 |

---

### Formula 5: 震动合并Tier选择

**目的**: 当多个震动请求合并时，选择最高Tier震动。

**公式**:
```
merged_tier = max(current_request_tier, pending_queue_tier)
```

**变量定义**:
| Variable | Type | Description |
|----------|------|-------------|
| `current_request_tier` | int | 当前震动请求的Tier |
| `pending_queue_tier` | int | 队列中等待震动的最高Tier |
| `merged_tier` | int | 输出：合并后触发的Tier |

---

### Formula 6: 跳过模式震动时长压缩

**目的**: 跳过战斗模式下，压缩多段震动序列为单段震动。

**公式**:
```
skip_mode_duration = first_segment_duration
```

**压缩示例**:
| Preset | Normal Duration | Skip Mode Duration |
|--------|-----------------|-------------------|
| **Celebration Burst** | 450ms (3段) | 150ms (仅第一段) |
| **Heavy Impact** | 350ms (2段) | 200ms (仅第一段) |

## Edge Cases

### Edge Case 1: 同一时刻多震动请求

**场景**: Boss击败时，同时触发 Victory震动 (Tier 4) + Gold震动 (Tier 2) + 稀有掉落震动 (Tier 3)。

**处理方式**:
- 震动系统收到3个请求：Tier 4, Tier 3, Tier 2
- 合并策略：选择最高Tier → 触发 Tier 4 Heavy Impact
- Tier 3和Tier 2震动被合并（不单独触发）
- 粒子系统分层播放：Victory → Delay → Gold → Delay → Rare Drop
- 震动只在第一个粒子(Victory)同步时触发，后续粒子播放时震动已结束

**玩家视角**: Boss击败时感受到一次强震动（Heavy Impact），与Victory粒子同步触发。随后看到金币粒子爆发和稀有掉落光效，但没有额外震动——视觉节奏丰富，触觉反馈简洁不疲劳。

---

### Edge Case 2: 震动设置关闭

**场景**: 玩家在设置中关闭震动，但游戏内仍触发震动请求。

**处理方式**:
- 存档系统读取震动设置：`vibration_enabled = false`
- VibrationSystem初始化时设置 `_enabled = false`
- 所有震动请求（战斗、强化、UI）调用`request_vibration()` → 返回`false`
- 粒子系统和音效系统正常工作，震动不触发
- 玩家重新开启震动 → `_enabled = true` → 震动恢复

**玩家视角**: 震动关闭时，仍能看到粒子效果、听到音效，只是没有触觉反馈。

---

### Edge Case 3: 场景切换时震动正在播放

**场景**: Celebration Burst正在播放三段震动序列（150ms→100ms→200ms），玩家触发场景切换进入新房间。

**处理方式**:
- 地牢推进系统调用`cancel_all()`
- VibrationSystem立即停止震动序列播放：
  - 若第一段震动正在播放 → 无法中途取消（Godot API限制），等待该段结束
  - 后续段震动被跳过（队列清空）
- 进入Cooldown状态，禁止新震动200ms
- 200ms后恢复Idle状态，接受新震动请求

**玩家视角**: 场景切换时，当前震动"自然结束第一段后停止"，没有突然截断的异常感。新房间开始有200ms无震动缓冲，避免震动重叠。

---

### Edge Case 4: 连续震动超频

**场景**: 玩家快速击败多个敌人（每秒3-4次击杀），震动请求频率超过3次/秒限制。

**处理方式**:
- 第1次击杀：距离上次震动>200ms → 触发 Medium Pulse (Tier 1)
- 第2次击杀：距离上次震动<200ms → 合并请求，记录Tier 2
- 第3次击杀：距离上次震动<200ms → 合并请求，记录Tier 2
- 当间隔达到200ms → 触发合并后的最高Tier (Tier 2 Medium Pulse)
- 后续击杀：重复合并逻辑

**玩家视角**: 快速击杀多个敌人时，震动不会每次都触发——系统合并震动请求，玩家感受到"间隔震动"而非"连续震动"，避免手部疲劳。

---

### Edge Case 5: iOS平台震动时长超限

**场景**: Celebration Burst震动序列总时长450ms，iOS Taptic Engine单震最大200ms。

**处理方式**:
- Heavy Impact和Celebration Burst都设计为分段震动，每段≤200ms
- Heavy Impact: 200ms → gap 50ms → 100ms（符合iOS限制）
- Celebration Burst: 150ms → gap 50ms → 100ms → gap 50ms → 200ms（符合iOS限制）
- iOS震动不会截断，因为每段时长≤200ms
- Android平台同样遵守此限制，确保跨平台一致性

**玩家视角**: iOS和Android玩家感受到相同的震动体验，没有平台差异导致的震动截断或过长问题。

---

### Edge Case 6: 跳过战斗模式下的震动节奏

**场景**: 玩家选择跳过战斗，战斗系统快速结算，震动系统需在压缩时间内完成反馈。

**处理方式**:
- 跳过模式开启：战斗系统调用`set_skip_mode(true)`
- 震动请求触发：Celebration Burst请求（正常450ms）
- 跳过模式处理：只触发第一段震动 (150ms)，后续段跳过
- 粒子同步：粒子同样只播最小时长(300ms)
- 触觉+视觉节奏压缩，结算速度加快

**玩家视角**: 跳过战斗时，震动"快速脉冲一下就结束"——快速反馈但不拖慢节奏。观看战斗时，震动完整播放三段序列——享受完整触觉体验。

---

### Edge Case 7: 低电量或省电模式

**场景**: 移动设备进入省电模式或电量<20%，震动可能被系统限制。

**处理方式**:
- VibrationSystem不检测设备电量或省电模式
- 震动触发依赖Godot `OS.vibrate()` API
- 若系统限制震动 → 震动不触发，粒子/音效正常工作
- 玩家可在设置中手动关闭震动以省电
- **不做主动检测**：电量检测超出MVP范围，震动效果依赖系统API行为

**玩家视角**: 低电量时震动可能不触发（系统行为），但粒子/音效正常显示，玩家仍能感知进步。玩家可主动关闭震动以省电。

## Dependencies

### Upstream Dependencies (Systems Vibration System Depends On)

震动系统属于Foundation层，无上游游戏逻辑依赖。但它依赖存档系统存储震动设置偏好。

| Dependency | Status | GDD Location | Notes |
|------------|--------|--------------|-------|
| **存档系统** | Approved | design/gdd/save-system.md | 存档系统存储震动设置偏好（开启/关闭/强度等级） |
| **Godot OS API** | N/A | N/A | 平层依赖：震动系统依赖Godot 4.6 `OS.vibrate()` API |

**说明**: 震动系统不依赖战斗系统、强化系统、粒子系统——它被动接收调用。震动预设、Tier参数、合并策略都在震动系统内部定义。

---

### Downstream Dependencies (Systems That Depend On Vibration System)

以下系统依赖震动系统提供触觉反馈接口：

| Dependent System | Priority | GDD Status | How It Uses Vibration System |
|-----------------|----------|------------|----------------------------|
| **视觉反馈系统** | MVP | Not Started | 协调震动+粒子+音效的同步触发，是震动系统的主要调用协调者 |
| **战斗系统** | MVP | Not Started | 敌人击败时调用`request_vibration("medium_pulse", tier)` |
| **装备强化系统** | MVP | Not Started | 强化成功时调用`request_vibration("celebration_burst", tier)` |
| **装备掉落系统** | MVP | Not Started | 稀有掉落时调用`request_vibration("heavy_impact", 3)` |
| **地牢推进系统** | MVP | Not Started | 房间完成时调用`request_vibration("medium_pulse", tier)`；房间切换时调用`cancel_all()` |
| **UI系统** | MVP | Not Started | 按钮点击时调用`request_vibration("light_tap", 1)` |

---

### Interface Contract (承诺给下游系统的接口)

震动系统向下游系统提供以下稳定接口：

```gdscript
# VibrationSystem 公共接口
class_name VibrationSystem

## 请求震动
## @param preset: 预设名称 ("light_tap" | "medium_pulse" | "heavy_impact" | "celebration_burst")
## @param tier: 强度等级 (1-6)
## @return: true=成功触发，false=被合并或禁止
func request_vibration(preset: String, tier: int) -> bool

## 取消所有震动（场景切换时调用）
func cancel_all() -> void

## 设置跳过模式（压缩震动序列）
func set_skip_mode(enabled: bool) -> void

## 设置震动开启/关闭
func set_vibration_enabled(enabled: bool) -> void

## 获取震动设置状态
func is_vibration_enabled() -> bool

## 设置震动强度等级
func set_vibration_strength(level: String) -> void  # "off" | "light" | "medium" | "strong"
```

**接口稳定性承诺**:
- `request_vibration`接口签名在MVP阶段冻结，不增加参数
- 若需扩展（如自定义震动序列），使用可选字典参数或新接口，不修改现有接口
- 下游系统可依赖接口返回值（`bool`）处理合并/禁止情况

---

### Data Flow Diagram

```
上游系统 → 震动系统 → 下游系统

战斗系统 ─────┐
装备强化系统 ─┤
装备掉落系统 ─┼──→ request_vibration(preset, tier) ──→ VibrationSystem ──→ OS.vibrate()
地牢推进系统 ─┤                        cancel_all()         ↑
UI系统 ───────┘                        set_skip_mode()      │
                                                              │
存档系统 ←── is_vibration_enabled() ←──────────────────────┘
             (震动设置偏好存储)
                                                              │
视觉反馈系统 ←── request_vibration() 返回值 ←───────────────┘
                (协调震动+粒子+音效的节奏)
```

**数据流说明**:
- **输入流**: 多个上游系统调用`request_vibration`，传入预设名称、强度等级
- **输出流**: 震动系统调用`OS.vibrate()`触发设备震动，返回成功/失败状态
- **设置流**: 存档系统读取/写入震动设置偏好（开启/关闭/强度）
- **协调流**: 视觉反馈系统根据返回值判断震动是否触发，协调粒子+音效的同步节奏

## Tuning Knobs

### Knob Category 1: 震动时长参数

| Knob ID | Variable Name | Default Value | Safe Range | Gameplay Effect | Tuning Notes |
|---------|---------------|---------------|------------|-----------------|--------------|
| `TK-VIBRATION-LIGHT` | `light_tap_duration` | 50ms | 30-80ms | Light Tap震动时长 | 过短玩家无法感知，过长拖慢UI节奏 |
| `TK-VIBRATION-MEDIUM-100` | `medium_pulse_100` | 100ms | 80-150ms | Medium Pulse Tier 2时长 | 中等奖励震动强度 |
| `TK-VIBRATION-MEDIUM-150` | `medium_pulse_150` | 150ms | 100-200ms | Medium Pulse Tier 3时长 | 大额奖励震动强度，接近iOS单震上限 |
| `TK-VIBRATION-HEAVY-1` | `heavy_impact_segment1` | 200ms | 150-200ms | Heavy Impact第一段 | iOS限制单震≤200ms |
| `TK-VIBRATION-HEAVY-2` | `heavy_impact_segment2` | 100ms | 50-150ms | Heavy Impact第二段 | 后续段震动 |
| `TK-VIBRATION-CELEBRATION-1` | `celebration_segment1` | 150ms | 100-200ms | Celebration Burst第一段 | 强化成功震动首段 |
| `TK-VIBRATION-CELEBRATION-2` | `celebration_segment2` | 100ms | 50-150ms | Celebration Burst第二段 | 中间段震动 |
| `TK-VIBRATION-CELEBRATION-3` | `celebration_segment3` | 200ms | 150-200ms | Celebration Burst第三段 | 结尾段震动 |

**调优建议**: 震动时长直接影响触觉强度感知：
- Light Tap时长测试：玩家是否感知到UI点击震动
- Heavy Impact时长测试：玩家是否感受到"冲击感"而非"普通震动"
- iOS平台测试：单震时长超过200ms是否被截断

---

### Knob Category 2: 震动间隔参数

| Knob ID | Variable Name | Default Value | Safe Range | Gameplay Effect | Tuning Notes |
|---------|---------------|---------------|------------|-----------------|--------------|
| `TK-VIBRATION-GAP` | `segment_gap` | 50ms | 30-100ms | 震动序列段间隔 | 间隔过短两段震动融合，间隔过长节奏断裂 |
| `TK-VIBRATION-INTERVAL` | `min_interval` | 200ms | 150-300ms | 两次震动最小间隔 | 防止震动疲劳，过短玩家手麻，过长反馈不连贯 |
| `TK-VIBRATION-COOLDOWN` | `scene_cooldown` | 200ms | 150-500ms | 场景切换后冷却时间 | 新房间开始前禁止震动的时间 |

**调优建议**: 间隔参数影响震动节奏感：
- 快速击杀测试：震动间隔是否避免手部疲劳
- Boss击败测试：多段震动间隔是否形成"冲击→回响"的节奏感
- 场景切换测试：冷却时间是否足够让玩家感知新房间开始

---

### Knob Category 3: 性能/频率约束

| Knob ID | Variable Name | Default Value | Safe Range | Gameplay Effect | Tuning Notes |
|---------|---------------|---------------|------------|-----------------|--------------|
| `TK-VIBRATION-MAX-FREQ` | `max_frequency_per_second` | 3 | 2-5 | 每秒最大震动次数 | 防止震动疲劳和电池消耗 |
| `TK-VIBRATION-MAX-10S` | `max_in_10_seconds` | 15 | 10-20 | 10秒内最大震动次数 | 防止连续震动导致手部麻木 |
| `TK-VIBRATION-QUEUE-MAX` | `queue_max_length` | 5 | 3-10 | 震动队列最大长度 | 超过5个请求时，低Tier请求被丢弃 |

**调优建议**: 频率约束保护玩家体验：
- 快速击杀场景测试：震动频率是否超标触发合并
- 连续战斗测试：10秒内震动次数是否超过15次
- 队列溢出测试：是否正确丢弃低Tier震动请求

---

### Knob Category 4: 震动强度设置

| Knob ID | Variable Name | Default Value | Safe Range | Gameplay Effect | Tuning Notes |
|---------|---------------|---------------|------------|-----------------|--------------|
| `TK-VIBRATION-STRENGTH-DEFAULT` | `default_strength` | "medium" | "off"/"light"/"medium"/"strong" | 默认震动强度等级 | 首次安装默认中等强度 |
| `TK-VIBRATION-LIGHT-MULTIPLIER` | `light_strength_multiplier` | 0.5 | 0.3-0.7 | "轻"强度时长倍数 | 震动时长减半 |
| `TK-VIBRATION-STRONG-MULTIPLIER` | `strong_strength_multiplier` | 1.3 | 1.1-1.5 | "强"强度时长倍数 | 震动时长增加，序列增加一段 |

**调优建议**: 强度设置满足玩家个人偏好：
- "轻"强度测试：玩家是否仍能感知震动但不明显
- "强"强度测试：震动是否过于强烈导致不适
- 设置切换测试：设置修改后震动效果是否正确变化

---

### Tuning Knob Configuration File

所有调优参数存储在 `assets/data/config/vibration_config.json`，格式如下：

```json
{
  "presets": {
    "light_tap": { "duration_ms": 50 },
    "medium_pulse_100": { "duration_ms": 100 },
    "medium_pulse_150": { "duration_ms": 150 },
    "heavy_impact": { "segments": [
      { "duration_ms": 200, "gap_ms": 50 },
      { "duration_ms": 100, "gap_ms": 0 }
    ]},
    "celebration_burst": { "segments": [
      { "duration_ms": 150, "gap_ms": 50 },
      { "duration_ms": 100, "gap_ms": 50 },
      { "duration_ms": 200, "gap_ms": 0 }
    ]}
  },
  "intervals": {
    "segment_gap_ms": 50,
    "min_interval_ms": 200,
    "scene_cooldown_ms": 200
  },
  "constraints": {
    "max_frequency_per_second": 3,
    "max_in_10_seconds": 15,
    "queue_max_length": 5
  },
  "strength_settings": {
    "default": "medium",
    "light_multiplier": 0.5,
    "strong_multiplier": 1.3
  }
}
```

**热更新支持**: 震动系统启动时读取JSON文件，运行时可直接修改文件调整参数（无需重新编译）。设计师可在测试时实时调整震动效果。

## Visual/Audio Requirements

### Visual Requirements

**震动系统本身不产生视觉效果**。震动是纯触觉反馈，视觉效果由粒子系统负责。

震动与视觉系统协调：

| Vibration Event | Visual System | Coordination |
|-----------------|--------------|--------------|
| Light Tap触发 | UI Popup Burst粒子 | 同步触发（视觉+触觉同时） |
| Medium Pulse触发 | Gold Burst粒子 | 同步触发，震动与粒子节奏一致 |
| Heavy Impact触发 | Victory Sparkle / Rare Drop Glow | 震动先触发（触觉领先0-50ms），粒子分层播放 |
| Celebration Burst触发 | Enhancement Flash粒子 | 同步触发，震动序列与粒子爆发同步 |

**视觉-触觉同步原则**:
- 震动与粒子同时触发时，震动时间≤粒子时间（震动不拖长视觉节奏）
- 合并震动策略确保：视觉有分层节奏（粒子分层播放），触觉简洁不疲劳（震动合并）

---

### Audio Requirements

**震动系统本身不播放音效**。音效由音效系统负责，震动系统只触发触觉反馈。

| Vibration Event | Audio Event | Owned By | Coordination |
|-----------------|-------------|----------|--------------|
| Light Tap触发 | `button_click.wav` | 音效系统 | 同步触发（视觉+触觉+听觉三重反馈） |
| Medium Pulse触发 | `coin_collect.wav` | 音效系统 | 同步触发，震动与音效节奏一致 |
| Heavy Impact触发 | `victory.wav` / `rare_drop.wav` | 音效系统 | 震动与音效同步，粒子分层播放 |
| Celebration Burst触发 | `enhance_success.wav` | 音效系统 | 震动序列与音效节奏同步 |

**感官三重奏**: 震动+粒子+音效形成完整的感官反馈：
- **视觉**: 粒子爆发让进步"炸"出存在感
- **听觉**: 音效让进步有声音确认
- **触觉**: 震动让进步"震"入身体感知

**同步协调**: 视觉反馈系统负责协调震动+粒子+音效的同步触发顺序（见视觉反馈系统GDD）。

---

### Art Bible Alignment

震动系统不涉及视觉设计，但触觉强度与视觉强度保持一致：
- **Tier对应**: 震动Tier与粒子Tier共享相同计算公式，确保触觉强度与视觉强度匹配
- **合并策略**: 震动合并避免疲劳，粒子分层保持视觉丰富度——两者各有分工，共同服务于"爽感反馈"支柱

---

### Platform Haptics Notes

**iOS Taptic Engine**:
- 提供Haptic Feedback API，支持预定义震动类型（轻/中/重）
- Godot 4.6 `OS.vibrate()` 在iOS上调用Taptic Engine
- 单震最大时长约200ms，超过可能被截断

**Android Vibrator**:
- 提供Vibrator API，支持自定义时长震动
- Godot 4.6 `OS.vibrate()` 在Android上调用Vibrator
- 支持更长震动时长，但用户体验建议≤200ms

**跨平台统一策略**:
- 所有震动预设遵守200ms单震限制
- 多段震动通过async/await实现，每段≤200ms
- iOS和Android玩家感受到相同的震动体验

## UI Requirements

震动系统本身无直接游戏UI界面。震动是纯触觉反馈层，不包含菜单、面板、HUD元素。

### Settings UI

震动系统通过游戏设置界面暴露震动控制选项：

| Setting Option | UI Element | Default Value | Description |
|---------------|------------|---------------|-------------|
| **震动开关** | Toggle开关 | 开启 | 开启/关闭所有震动反馈 |
| **震动强度** | 选项列表 | 中等 | 关闭/轻/中/强四个强度等级 |

**设置界面位置**: 游戏主菜单 → 设置 → 音效/震动设置页面

---

### UI System Interaction

震动系统与UI系统的交互是双向：

| Interaction | Direction | Description |
|-------------|-----------|-------------|
| UI按钮点击震动 | UI系统 → 震动系统 | 按钮点击时，UI系统调用`request_vibration("light_tap", 1)` |
| 震动设置修改 | 设置UI → 震动系统 | 玩家修改震动设置时，调用`set_vibration_enabled()`或`set_vibration_strength()` |
| 震动状态显示 | 震动系统 → 设置UI | 设置UI显示当前震动开关状态和强度等级 |

---

### Vibration Settings UI Design

**开关UI**:
- Toggle开关按钮：开启时显示绿色图标，关闭时显示灰色图标
- 开关文字："震动反馈"

**强度选择UI**:
- 选项列表：四个选项（关闭、轻、中、强）
- 当前选择高亮显示
- 强度文字：
  - 关闭：无震动
  - 轻：轻微震动
  - 中：标准震动（默认）
  - 强：强烈震动

**UI布局**: 震动设置位于音效设置下方，两者共享设置页面。

---

### No In-Game UI

MVP阶段震动系统不提供游戏内配置界面。震动设置只在主菜单设置页面中调整。

**未来扩展**: 若需游戏内快速调整震动强度（如战斗中临时关闭震动），可增加快捷菜单选项。MVP阶段不实现。

---

### Summary

震动系统无游戏内UI界面，只通过设置界面暴露震动开关和强度选项。设置修改后立即生效，存档系统持久化设置偏好。UI按钮点击触发Light Tap震动，形成交互的触觉反馈。

> **📌 UX Flag — 震动反馈系统**: This system has UI requirements (settings panel). In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the settings panel **before** writing epics. Stories that reference震动设置 UI should cite `design/ux/settings.md`, not the GDD directly.

## Acceptance Criteria

### Acceptance Criteria: 功能正确性

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-VIBRATION-001` | 4种预设震动可正确触发 | 手动测试：触发每种事件类型，观察设备震动 | Light Tap=50ms震动，Medium Pulse=100-150ms，Heavy Impact=两段震动，Celebration Burst=三段震动 |
| `AC-VIBRATION-002` | Tier参数正确控制震动时长 | 单元测试：调用request_vibration传入Tier 1-6，验证震动时长 | Tier 1=50ms，Tier 2=100ms，Tier 3=150ms，Tier 4=350ms，Tier 5=550ms |
| `AC-VIBRATION-003` | 金币奖励自动计算Tier | 单元测试：传入gold_reward=50/500/5000，验证vibration_tier | gold_reward=50→Tier 1，gold_reward=500→Tier 2，gold_reward=5000→Tier 3 |
| `AC-VIBRATION-004` | 强化等级自动计算Tier | 单元测试：传入enhancement_level=+1/+5/+10，验证震动预设 | +1→Medium Pulse，+5→Medium Pulse，+10→Celebration Burst |
| `AC-VIBRATION-005` | 合并策略正确选择最高Tier | 单元测试：模拟同时触发Tier 2+Tier 4请求 | 触发Tier 4震动，Tier 2被合并不触发 |
| `AC-VIBRATION-006` | 震动间隔200ms约束生效 | 单元测试：快速触发两次震动请求 | 第二次请求距离上次<200ms → 被合并 |

---

### Acceptance Criteria: 取消与打断

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-VIBRATION-007` | cancel_all立即生效 | 手动测试：震动序列播放中调用cancel_all() | 当前震动段自然结束，后续段被跳过 |
| `AC-VIBRATION-008` | 场景切换触发冷却 | 集成测试：震动播放中触发房间切换 | 震动取消，200ms冷却期禁止新震动 |
| `AC-VIBRATION-009` | 跳过模式压缩震动序列 | 手动测试：跳过战斗时观察Celebration Burst | 只触发第一段(150ms)，后续段跳过 |
| `AC-VIBRATION-010` | 震动设置关闭生效 | 手动测试：设置关闭震动后触发事件 | 震动不触发，粒子/音效正常 |

---

### Acceptance Criteria: 性能与频率

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-VIBRATION-011` | 最大震动频率≤3次/秒 | 单元测试：模拟每秒触发5次震动请求 | 第4-5次请求被合并或拒绝 |
| `AC-VIBRATION-012` | 10秒内震动次数≤15次 | 单元测试：模拟10秒内触发20次震动请求 | 第16-20次请求被合并或拒绝 |
| `AC-VIBRATION-013` | 震动队列最大长度=5 | 单元测试：队列中添加6个震动请求 | 第6个请求被丢弃或合并 |

---

### Acceptance Criteria: 跨平台兼容

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-VIBRATION-014` | iOS单震时长≤200ms | iOS真机测试：触发Heavy Impact震动 | 震动不被截断，两段震动正确播放 |
| `AC-VIBRATION-015` | Android震动正常触发 | Android真机测试：触发所有震动预设 | 震动正常触发，无异常 |
| `AC-VIBRATION-016` | 震动不阻塞帧率 | 性能测试：震动触发时监控帧时间 | 震动播放期间帧率≥60fps |

---

### Acceptance Criteria: 支柱支持

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-VIBRATION-017` | 爽感反馈支柱验证 | Playtest：10名玩家测试，询问"震动是否增强进步感受" | ≥80%玩家回答"震动让我更强感受到进步" |
| `AC-VIBRATION-018` | 掌控节奏支柱验证 | Playtest：跳过战斗测试，询问"跳过时震动是否合适" | ≥80%玩家回答"跳过时震动快速简洁，不拖慢节奏" |
| `AC-VIBRATION-019` | 震动不疲劳验证 | Playtest：连续战斗10分钟，询问"震动是否导致手部不适" | ≥80%玩家回答"震动频率合适，没有不适感" |

---

### Acceptance Criteria: 粒子同步

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-VIBRATION-020` | 震动与粒子同步触发 | 手动测试：敌人击败时观察震动和粒子 | 震动与Gold Burst粒子同时触发 |
| `AC-VIBRATION-021` | 合并震动不触发后续粒子震动 | 手动测试：Boss击败触发Victory+Gold粒子 | 震动只在Victory粒子时触发一次，Gold粒子播放时无额外震动 |

---

### Acceptance Criteria: 技术实现

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-VIBRATION-022` | Godot OS.vibrate()调用正确 | 代码审查：检查VibrationSystem使用OS.vibrate() | 代码使用OS.vibrate(duration_ms) |
| `AC-VIBRATION-023` | async/await序列震动实现 | 代码审查：检查多段震动实现方式 | 使用await实现震动序列，不阻塞主线程 |
| `AC-VIBRATION-024` | 配置文件热更新 | 手动测试：修改vibration_config.json，重启游戏验证参数生效 | 修改震动时长后，震动时长变化 |

---

### Acceptance Criteria Summary

- **Total Criteria**: 24
- **Blocking Criteria**: AC-001 to AC-016 (功能正确性+取消打断+性能频率+跨平台)
- **Advisory Criteria**: AC-017 to AC-021 (支柱验证+粒子同步)
- **Technical Criteria**: AC-022 to AC-024 (技术实现验证)

**MVP Completion Definition**: 震动系统通过所有Blocking Criteria (AC-001至AC-016)，Advisory Criteria由设计师Playtest验证，Technical Criteria由代码审查验证。

## Open Questions

### Open Question 1: iOS高级Haptic API支持

**问题**: Godot 4.6 `OS.vibrate()` 只支持简单震动，iOS Taptic Engine提供更高级的Haptic Feedback类型（UIImpactFeedbackGenerator、UINotificationFeedbackGenerator）。是否需要iOS原生插件支持高级震动？

**当前设计**: 使用Godot内置`OS.vibrate()`，通过时长和序列模拟强度。

**选项**:
- **Option A (内置API)**: MVP阶段使用`OS.vibrate()`，通过时长模拟强度，不开发iOS原生插件
- **Option B (iOS原生插件)**: 开发GDExtension插件，调用iOS Taptic Engine高级API，支持预定义震动类型（轻/中/重/成功/警告/失败）
- **Option C (第三方插件)**: 使用Godot Asset Store中的震动插件（如有）

**决策时间**: MVP阶段使用Option A（内置API），若测试发现iOS震动体验不佳，Post-MVP考虑Option B。

---

### Open Question 2: 震动与粒子精确同步机制

**问题**: 当前设计中震动与粒子"同步触发"，但实际执行可能有微小时间差（Godot帧调度、async震动序列）。是否需要精确同步机制？

**当前设计**: 震动调用`OS.vibrate()`立即执行，粒子调用`GPUParticles2D.emitting = true`立即执行，两者在同一帧内触发。

**不确定性**:
- async震动序列第一段与粒子第一帧是否同步？
- Godot帧调度是否导致震动与粒子有时间差？
- 是否需要`call_deferred()`或信号机制确保精确同步？

**决策时间**: 实现阶段验证震动与粒子同步效果，若有明显时间差，调整同步机制。

---

### Open Question 3: Android震动权限

**问题**: Android平台震动需要`VIBRATE`权限。是否需要在AndroidManifest.xml中声明权限？

**当前设计**: Godot导出Android APK时自动处理震动权限（Godot 4.x内置震动功能需要VIBRATE权限）。

**不确定性**:
- Godot 4.6导出配置是否自动包含VIBRATE权限？
- 若需手动配置，在哪个步骤添加？

**决策时间**: Android导出配置阶段验证权限是否正确声明，若需手动配置，创建ADR记录配置步骤。

---

### Open Question 4: 震动强度设置的视觉反馈

**问题**: 玩家在设置界面调整震动强度（关闭→轻→中→强）时，是否提供即时震动反馈让玩家感知强度差异？

**当前设计**: 设置界面修改震动强度后立即生效，但不触发震动反馈。

**选项**:
- **Option A (无即时反馈)**: 设置修改后不触发震动，玩家需在游戏中体验强度变化
- **Option B (即时反馈)**: 设置修改后触发一次对应强度的震动（关闭→无震动，轻→Light Tap，中→Medium Pulse，强→Heavy Impact），让玩家立即感知强度差异

**决策时间**: 设置界面UX设计时决定。Option B可能提供更好的设置体验，但增加震动次数。

---

### Open Question 5: 视觉反馈系统的完整协调机制

**问题**: 震动系统与粒子系统、音效系统由视觉反馈系统协调。视觉反馈系统的协调机制是什么？震动系统是否需要被动等待协调，还是主动提供接口供协调？

**当前设计**: 震动系统提供`request_vibration()`接口，视觉反馈系统调用接口并协调触发顺序。

**不确定性**:
- 视觉反馈系统如何协调震动+粒子+音效？
- 震动系统是否需要提供`get_vibration_status()`接口供协调？
- 触觉领先原则（震动先触发）如何在协调系统中实现？

**决策时间**: 视觉反馈系统GDD设计时解决。震动系统提供接口，协调机制由视觉反馈系统定义。

---

### Resolution Timeline

| Open Question | Blocking System | Resolution Timing |
|---------------|-----------------|-------------------|
| OQ-1 iOS高级Haptic API | 无（技术选择） | MVP阶段使用内置API，Post-MVP评估是否需要插件 |
| OQ-2 震动粒子精确同步 | 无（实现验证） | 实现阶段验证同步效果 |
| OQ-3 Android震动权限 | 无（导出配置） | Android导出配置阶段验证 |
| OQ-4 震动强度设置反馈 | 设置界面UX设计 | 设置界面UX设计时决定 |
| OQ-5 视觉反馈系统协调 | 视觉反馈系统 | 视觉反馈系统GDD设计时解决 |