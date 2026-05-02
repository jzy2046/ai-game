# 视觉反馈系统 (Visual Feedback System)

> **Status**: Designed
> **Author**: User + agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: 爽感反馈

## Overview

视觉反馈系统是游戏的感官反馈协调层，负责接收游戏事件、统一调度粒子、震动、数值动画和音效的同步触发，创造"爽感反馈"支柱的核心体验——感官三重奏。它不产生视觉效果本身，而是作为指挥家，确保粒子系统（视觉）、震动反馈系统（触觉）、数值显示系统（信息）和音效系统（听觉）在同一时刻、按正确节奏协同工作。

**核心职责**:
1. **事件监听**: 订阅战斗、强化、掉落、地牢推进、UI等系统的信号，识别反馈触发时机
2. **反馈预设映射**: 将游戏事件映射到反馈预设（如"敌人击败"→Gold Burst粒子+Medium Pulse震动+金币音效+数值bounce）
3. **同步调度**: 协调粒子、震动、数值动画的触发顺序和延迟，确保感官反馈节奏一致
4. **分层叠加处理**: 当多事件并发时，按优先级分层调度（粒子分层延迟，震动合并最高Tier）
5. **跳过模式压缩**: 玩家选择跳过战斗时，压缩反馈时长（粒子最小时长0.3秒，震动压缩为单段）

**数据流**:
```
战斗系统 emit enemy_defeated → VisualFeedbackSystem.on_enemy_defeated()
                              → 计算Tier (gold_reward)
                              → ParticleSystem.emit_particle("gold_burst", tier, position)
                              → VibrationSystem.request_vibration("medium_pulse", tier)
                              → StatDisplaySystem.trigger_currency_bounce(amount)
                              → (音效系统播放 coin_collect.wav)

强化系统 emit enhancement_completed → VisualFeedbackSystem.on_enhancement_completed()
                                    → 计算Tier (enhancement_level)
                                    → ParticleSystem.emit_particle("enhancement_flash", tier, position)
                                    → VibrationSystem.request_vibration("celebration_burst", tier)
                                    → StatDisplaySystem.trigger_stat_bounce(old, new)
                                    → (音效系统播放 enhance_success.wav)
```

**MVP范围**: 6种反馈预设（敌人击败、Boss击败、装备掉落、强化成功、地牢房间完成、UI点击），每种预设定义粒子+震动+数值+音效的组合和节奏。

**支柱支撑**:
- 爽感反馈: 感官三重奏（视觉+触觉+听觉）让每次进步都是一场庆祝
- 稳定成长: 反馈强度映射进步量级（Tier系统），玩家通过感官感知"这次进步有多大"
- 掌控节奏: 跳过模式下压缩反馈时长，观看模式下完整播放，玩家控制反馈节奏

## Player Fantasy

**核心幻想**: "进步是一场感官交响" — 每次击败敌人、每次强化成功、每次获得稀有装备，游戏都会以粒子爆发、设备震动、数值跳动、音效响起的方式回应玩家。这不是单一的视觉闪烁，而是视觉+触觉+听觉+信息的四重感官叠加。玩家不是"知道进步"，而是"感受进步"——从眼睛看到粒子炸裂、手掌感到设备脉冲、耳朵听到庆祝音效、大脑看到数值跳动。

**锚定时刻**: 第一次Boss击败的时刻。玩家苦战击败Floor 15的Boss，看到Victory Sparkle粒子全屏闪烁，设备连续震动两次（Heavy Impact），金币数字从500飞升到3600（数字飞升动画），胜利音效响起。这四个感官输入同时到达，玩家大脑接收到"大胜利"的强烈信号——这不是普通的敌人击败，而是里程碑时刻。玩家感受："我做到大事了！"

**感官三重奏的节奏感**:
- **同步触发**: 粒子、震动、音效在同一帧触发，创造"瞬间爆发"的冲击感
- **分层延迟**: Boss击败时，先播Victory粒子（高优先级），延迟0.3秒后播Gold粒子（低优先级），形成"胜利→奖励"的叙事节奏
- **震动合并**: 触觉简洁不疲劳——Boss击败只触发一次Heavy Impact震动，而非连续多次震动

**跳过模式的节奏压缩**:
- 玩家选择跳过战斗时，反馈时长压缩：粒子最小时长0.3秒，震动压缩为单段
- 玩家仍获得感官反馈，但节奏快速，不拖慢结算
- 玩家选择观看战斗时，反馈完整播放——享受完整感官体验

**参考时刻**:
- 暗黑破坏神：击杀后金币粒子爆发+音效+震动（如有）同时触发，击杀有"重量感"
- Idle Slayer：强化成功时全屏庆祝特效，让进步成为"仪式"
- Clicker Heroes：数值暴涨时的飞升动画，让数字成为爽感载体

**支柱对应**:
- 爽感反馈：感官三重奏让进步不可忽视——玩家无法错过每次成长
- 稳定成长：Tier系统让反馈强度映射进步量级——玩家通过感官知道"这次进步有多大"
- 掌控节奏：跳过模式压缩反馈，观看模式完整播放——玩家控制感官体验的节奏
- 多元成长：不同事件有不同预设（击败=Gold，强化=Enhancement，掉落=Rare），感官语言区分成长类型

## Detailed Design

### Core Rules

**Rule 1: Feedback Preset Definition**

视觉反馈系统定义6种反馈预设，每种预设映射粒子+震动+数值+音效的组合：

| Preset Name | Trigger Event | Particle | Vibration | Stat Display | Audio | Tier Calculation |
|-------------|--------------|----------|-----------|--------------|-------|------------------|
| **Enemy Defeated** | `enemy_defeated` signal | Gold Burst | Medium Pulse | Currency bounce | coin_collect.wav | `floor(log10(gold))` |
| **Boss Defeated** | `boss_defeated` signal | Victory Sparkle + Gold Burst (layered) | Heavy Impact | Currency bounce + Floor advance | victory.wav + coin.wav | Victory Tier 4, Gold auto |
| **Equipment Drop** | `equipment_dropped` signal | Rare Drop Glow (if RARE+) | Heavy Impact | Comparison panel | rare_drop.wav | Fixed Tier 3 (if RARE+) |
| **Enhancement Success** | `enhancement_completed` signal | Enhancement Flash | Celebration Burst | Stat bounce + Preview panel | enhance_success.wav | `floor(level/3)+1` |
| **Dungeon Room Complete** | `floor_completed` signal | Victory Sparkle | Medium Pulse | Floor number bounce | victory.wav | Based on floor type |
| **UI Button Click** | UI button pressed | UI Popup Burst | Light Tap | None | button_click.wav | Fixed Tier 1 |

---

**Rule 2: Event Subscription and Signal Routing**

视觉反馈系统订阅上游系统信号：

| Signal Source | Signal Name | Handler Method |
|---------------|-------------|----------------|
| 战斗系统 | `enemy_defeated(enemy_id, gold_reward, position)` | `on_enemy_defeated()` |
| 战斗系统 | `boss_defeated(boss_id, gold_reward, drops, position)` | `on_boss_defeated()` |
| 装备掉落系统 | `equipment_dropped(equipment_instance, rarity, position)` | `on_equipment_dropped()` |
| 装备强化系统 | `enhancement_completed(equipment_id, old_level, new_level, position)` | `on_enhancement_completed()` |
| 地牢推进系统 | `floor_completed(floor_id, floor_type)` | `on_floor_completed()` |
| UI系统 | `button_clicked(button_position)` | `on_button_clicked()` |

---

**Rule 3: Tier Calculation and Pass-through**

视觉反馈系统计算Tier并传递给下游系统：

**Gold Tier**: `tier = clamp(floor(log10(gold_reward)), 1, 5)`
**Enhancement Tier**: `tier = clamp(floor(enhancement_level / 3) + 1, 1, 5)`
**Floor Tier**: Based on floor type (normal=2, elite=3, boss=4)

**传递规则**:
- 粒子系统: 接收Tier，控制粒子数量和持续时间
- 震动反馈系统: 接收Tier，选择预设和时长
- 数值显示系统: 接收变化量，选择动画强度(small/medium/large)

---

**Rule 4: Synchronization Order**

同一事件触发多反馈时，遵守**触觉领先原则**：

| Step | Action | Timing |
|------|--------|--------|
| 1 | 触发震动 | 立即 (Frame 0) |
| 2 | 触发粒子 | 立即 (Frame 0) |
| 3 | 触发数值动画 | 立即 (Frame 0) |
| 4 | 触发音效 | 立即 (Frame 0) |

**同步实现**: 所有调用在同一帧内完成，震动和粒子在视觉上同时出现。

---

**Rule 5: Layered Feedback for Composite Events**

复合事件（Boss击败）触发分层反馈：

**Boss Defeated分层流程**:
```
Frame 0:   触发 Heavy Impact 震动（合并策略）
           触发 Victory Sparkle 粒子 (Tier 4)
           触发 Floor number bounce
           播放 victory.wav
Frame 300ms: 触发 Gold Burst 粒子 (Tier auto-calculated)
             触发 Currency bounce
             播放 coin_collect.wav
```

**分层原则**:
- 高优先级反馈先触发
- 低优先级反馈延迟触发（粒子系统定义的layer_delay）
- 震动合并为最高Tier，不分层

---

**Rule 6: Skip Mode Compression**

跳过战斗模式下的反馈压缩：

**压缩规则**:
- 粒子: 最小可见时长0.3秒（粒子系统Rule 5）
- 震动: 压缩为单段（震动反馈系统Rule 6）
- 数值: 动画时长压缩至0.2秒
- 音效: 播放但不等待完成

**跳过模式触发**: 战斗系统调用 `VisualFeedbackSystem.set_skip_mode(true)`，反馈系统传递给粒子系统和震动系统。

---

**Rule 7: Performance Budget Monitoring**

视觉反馈系统不直接管理性能预算，但监控下游系统状态：

**监控指标**:
- 粒子系统: `ParticleSystem.get_active_count()` ≤ 200
- 震动系统: `VibrationSystem.is_vibration_enabled()` 检查

**拒绝策略**: 若粒子系统返回 `false`（超出预算），反馈系统记录日志但不重试。震动合并天然避免超频。

---

**Rule 8: Feedback Preset Registry**

反馈预设存储在配置文件：

**Registry路径**: `assets/data/config/feedback_presets.json`

**配置结构**:
```json
{
  "presets": {
    "enemy_defeated": {
      "particle": "gold_burst",
      "vibration": "medium_pulse",
      "stat_display": "currency_bounce",
      "audio": "coin_collect.wav",
      "layer_delay_ms": 0
    },
    "boss_defeated": {
      "particle": ["victory_sparkle", "gold_burst"],
      "vibration": "heavy_impact",
      "stat_display": ["floor_bounce", "currency_bounce"],
      "audio": ["victory.wav", "coin_collect.wav"],
      "layer_delay_ms": [0, 300]
    }
  }
}
```

---

### States and Transitions

视觉反馈系统是协调层，本身无复杂状态：

| State | Description | Entry | Exit |
|-------|-------------|-------|------|
| **Idle** | 无反馈活动 | 初始化/反馈完成 | 信号触发 |
| **Processing** | 正在调度反馈 | 信号触发 | 调度完成 |
| **SkipMode** | 跳过模式激活 | `set_skip_mode(true)` | `set_skip_mode(false)` |

**Transition Table**:
| Current | Trigger | Next | Action |
|---------|---------|------|--------|
| Idle | Signal received | Processing | 开始调度反馈 |
| Processing | 调度完成 | Idle | 等待下一个信号 |
| Idle | `set_skip_mode(true)` | SkipMode | 记录跳过模式 |
| SkipMode | Signal received | SkipMode | 调度压缩反馈 |
| SkipMode | `set_skip_mode(false)` | Idle | 恢复正常模式 |

---

### Interactions with Other Systems

**上游依赖**:

| System | Signal Subscribed | Handler |
|--------|------------------|---------|
| 战斗系统 | `enemy_defeated` | `on_enemy_defeated()` |
| 战斗系统 | `boss_defeated` | `on_boss_defeated()` |
| 装备掉落系统 | `equipment_dropped` | `on_equipment_dropped()` |
| 装备强化系统 | `enhancement_completed` | `on_enhancement_completed()` |
| 地牢推进系统 | `floor_completed` | `on_floor_completed()` |
| UI系统 | `button_clicked` | `on_button_clicked()` |

**下游依赖**:

| System | Interface Called | Call Context |
|--------|-----------------|--------------|
| 粒子系统 | `emit_particle(preset, tier, position)` | 每个反馈预设 |
| 震动反馈系统 | `request_vibration(preset, tier)` | 每个反馈预设 |
| 震动反馈系统 | `set_skip_mode(enabled)` | 跳过模式切换 |
| 数值显示系统 | `trigger_currency_bounce(amount)` | 金币变化 |
| 数值显示系统 | `trigger_stat_bounce(old, new)` | 属性变化 |
| 数值显示系统 | `display_comparison(old, new)` | 装备掉落对比 |
| 音效系统 | `play_sound(sound_id)` (Post-MVP) | 每个反馈预设 |

## Formulas

### F1: Gold Tier Calculation (Pass-through to Particle/Vibration)

The gold tier formula is passed through from dependency systems:

`gold_tier = clamp(floor(log10(gold_reward)), 1, 5)`

**Reference**: See 粒子系统 Formula 1, 震动反馈系统 Formula 2.

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| gold_reward | int | 1–10000+ | Gold amount from enemy defeat |
| gold_tier | int | 1–5 | Tier level for particle/vibration intensity |

---

### F2: Enhancement Tier Calculation (Pass-through)

`enhancement_tier = clamp(floor(enhancement_level / 3) + 1, 1, 5)`

**Reference**: See 粒子系统 Formula 2, 震动反馈系统 Formula 3.

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| enhancement_level | int | 0–10 | Equipment enhancement level |
| enhancement_tier | int | 1–5 | Tier level for feedback intensity |

---

### F3: Layer Delay Calculation

Layer delay for composite events (Boss defeated):

`layer_delay_ms[layer] = LAYER_DELAY_TABLE[layer]`

**Layer Delay Table:**
| Layer | Event | Delay (ms) | Description |
|-------|-------|------------|-------------|
| 1 | Victory Sparkle | 0 | Immediate |
| 2 | Gold Burst | 300 | Post-victory reward |

---

### F4: Skip Mode Duration Compression

Skip mode compresses feedback duration:

`skip_duration = min(duration, MIN_VISIBLE_DURATION)`

**Variables:**
| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| duration | float | 0.5–1.2s | Normal feedback duration |
| MIN_VISIBLE_DURATION | float | 0.3s | Minimum visible feedback |
| skip_duration | float | 0.3s | Compressed duration |

---

### Summary Table: Feedback Preset Examples

| Event | Gold/Level | Tier | Particle | Vibration | Layer Delay |
|-------|------------|------|----------|-----------|-------------|
| Enemy (gold=50) | 50 | 1 | Gold Burst (8-12) | Light Tap 50ms | 0ms |
| Enemy (gold=500) | 500 | 2 | Gold Burst (20-30) | Medium 100ms | 0ms |
| Boss (gold=5000) | 5000 | 3 | Victory+Gold layered | Heavy 300ms | Victory 0ms, Gold 300ms |
| Enhancement +1 | +1 | 1 | Enhancement (8-12) | Medium 150ms | 0ms |
| Enhancement +10 | +10 | 4 | Enhancement (80-120) | Celebration 450ms | 0ms |

## Edge Cases

### E1: Multiple Simultaneous Signals

**场景**: Boss击败时同时触发 `boss_defeated` + `equipment_dropped` (稀有掉落) + 多个 `enemy_defeated`。

**处理**: 
- Boss defeated: 触发 Victory Sparkle + Heavy Impact (Tier 4)
- Equipment dropped (RARE): 触发 Rare Drop Glow (Tier 3, Layer 1)
- Enemy defeated: 震动合并到 Heavy Impact，粒子按layer_delay播放
- 结果: Victory + Rare Drop 立即播放，Gold Burst 延迟300ms播放

---

### E2: Particle Budget Exceeded

**场景**: 当前粒子数=180，新事件请求Tier 4粒子(60-80个)，总粒子数将超200预算。

**处理**: 粒子系统返回 `false`，反馈系统记录日志，不重试，震动和数值动画正常触发。

---

### E3: Vibration Disabled in Settings

**场景**: 玩家关闭震动设置，但事件触发震动请求。

**处理**: 震动反馈系统返回 `false`，粒子、数值、音效正常触发，震动跳过。

---

### E4: Skip Mode During Layered Feedback

**场景**: 跳过战斗模式下，Boss defeated触发分层反馈。

**处理**: 
- Victory Sparkle: 最小时长0.3秒
- Heavy Impact: 压缩为单段200ms
- Gold Burst: 延迟300ms后触发，最小时长0.3秒
- 总时长: 约0.6秒（压缩）

---

### E5: Signal Before System Initialization

**场景**: 战斗系统在视觉反馈系统初始化前发出 `enemy_defeated` 信号。

**处理**: 信号被忽略（未订阅），反馈系统初始化后订阅信号，后续事件正常处理。

---

### E6: Unknown Event Type

**场景**: 上游系统发出未定义的事件信号。

**处理**: 反馈系统记录警告，不触发反馈，不阻塞系统。

---

### E7: Scene Transition During Feedback

**场景**: 反馈正在播放（粒子活跃），玩家触发场景切换。

**处理**: 
- 地牢推进系统调用 `ParticleSystem.cancel_all()`
- 震动系统进入Cooldown状态
- 反馈系统恢复Idle，等待新场景信号

---

### E8: Zero Gold Reward

**场景**: 特殊敌人击败后金币奖励=0。

**处理**: 反馈系统跳过Gold Burst和Currency bounce，触发极简反馈（无奖励视觉）。

---

### E9: RARE+ Equipment Drop

**场景**: 装备掉落系统触发 `equipment_dropped`，但装备为COMMON。

**处理**: COMMON装备不触发Rare Drop Glow粒子，只触发简单的获得提示（MVP简化处理）。

---

### E10: Concurrent Enhancement Requests

**场景**: 玩家快速连续强化多个装备，多个 `enhancement_completed` 信号并发。

**处理**: 每个信号独立处理，粒子分层（间隔0.1秒），震动合并最高Tier。

## Dependencies

### Upstream Dependencies (信号订阅)

| System | Signal | Handler | Critical? |
|--------|--------|---------|-----------|
| 战斗系统 | `enemy_defeated` | `on_enemy_defeated()` | Yes |
| 战斗系统 | `boss_defeated` | `on_boss_defeated()` | Yes |
| 装备掉落系统 | `equipment_dropped` | `on_equipment_dropped()` | Yes |
| 装备强化系统 | `enhancement_completed` | `on_enhancement_completed()` | Yes |
| 地牢推进系统 | `floor_completed` | `on_floor_completed()` | Yes |
| UI系统 | `button_clicked` | `on_button_clicked()` | Soft |

---

### Downstream Dependencies (接口调用)

| System | Interface | Call Frequency | Critical? |
|--------|-----------|----------------|-----------|
| 粒子系统 | `emit_particle(preset, tier, pos)` | Per event | Yes |
| 粒子系统 | `cancel_all()` | Scene transition | Yes |
| 震动反馈系统 | `request_vibration(preset, tier)` | Per event | Yes |
| 震动反馈系统 | `set_skip_mode(enabled)` | Skip mode toggle | Yes |
| 数值显示系统 | `trigger_currency_bounce(amount)` | Currency change | Yes |
| 数值显示系统 | `trigger_stat_bounce(old, new)` | Stat change | Yes |
| 数值显示系统 | `display_comparison(old, new)` | Equipment drop | Yes |
| 音效系统 | `play_sound(sound_id)` (Post-MVP) | Per event | Soft |

---

### Dependency Notes

- 视觉反馈系统是协调层，不存储状态，不依赖存档系统
- Tier计算公式来自粒子系统和震动反馈系统定义
- 分层延迟参数来自粒子系统 layer_delay 定义

## Tuning Knobs

本系统引用的 tuning knobs 来自下游系统：

| Knob | Value | Source | Effect on This System |
|------|-------|--------|----------------------|
| LAYER_DELAY_GOLD | 300ms | 粒子系统 | Boss defeated时Gold Burst延迟 |
| LAYER_DELAY_VICTORY | 0ms | 粒子系统 | Victory Sparkle立即播放 |
| MIN_VISIBLE_DURATION | 0.3s | 粒子系统 | 跳过模式最小时长 |
| VIBRATION_MIN_INTERVAL | 200ms | 震动反馈系统 | 震动合并间隔 |
| ANIMATION_DURATION_SMALL | 0.2s | 数值显示系统 | 小变化动画时长 |
| ANIMATION_DURATION_LARGE | 0.6s | 数值显示系统 | 大变化动画时长 |

**本系统无独立 tuning knobs** — 所有参数由下游系统定义。

## Visual/Audio Requirements

### Visual Feedback Coordination

| Event | Particle | Vibration | Stat Display | Timing |
|-------|----------|-----------|--------------|--------|
| Enemy Defeated | Gold Burst | Medium Pulse | Currency bounce | Synchronous (Frame 0) |
| Boss Defeated | Victory (0ms) → Gold (300ms) | Heavy Impact (merged) | Floor + Currency bounce | Layered |
| Equipment Drop (RARE+) | Rare Drop Glow | Heavy Impact | Comparison panel | Synchronous |
| Enhancement Success | Enhancement Flash | Celebration Burst | Stat bounce + Preview | Synchronous |
| Floor Complete | Victory Sparkle | Medium Pulse | Floor bounce | Synchronous |
| UI Click | UI Popup Burst | Light Tap | None | Synchronous |

---

### Audio Requirements (音效系统 Post-MVP)

| Event | Audio | Owned By | Notes |
|-------|-------|----------|-------|
| Enemy Defeated | coin_collect.wav | 音效系统 | MVP silent |
| Boss Defeated | victory.wav + coin.wav | 音效系统 | MVP silent |
| Equipment Drop | rare_drop.wav | 音效系统 | MVP silent |
| Enhancement Success | enhance_success.wav | 音效系统 | MVP silent |
| Floor Complete | victory.wav | 音效系统 | MVP silent |
| UI Click | button_click.wav | 音效系统 | MVP silent |

**MVP简化**: 音效系统为Vertical Slice，MVP阶段发出信号供后续接入。

## UI Requirements

视觉反馈系统本身无直接UI界面。反馈通过粒子、震动、数值动画呈现。

### Skip Mode Toggle (Optional UI)

| Setting | UI Element | Default | Description |
|---------|------------|---------|-------------|
| Skip Mode | Hidden (战斗系统控制) | Off | 战斗系统通过 `set_skip_mode()` 控制 |

**MVP范围**: 跳过模式由战斗系统控制，无独立UI。

---

### Feedback Intensity (Optional Setting)

| Setting | UI Element | Default | Description |
|---------|------------|---------|-------------|
| Feedback Intensity | 设置选项 | Normal | 可选：Off / Minimal / Normal / Maximum |

**MVP范围**: MVP不实现反馈强度设置，由下游系统（粒子、震动）的设置间接控制。

## Acceptance Criteria

### Feedback Synchronization

**AC1**: GIVEN enemy defeated with gold=500, WHEN `on_enemy_defeated()` called, THEN Tier=2, Gold Burst + Medium Pulse + Currency bounce triggered synchronously (same frame).

**AC2**: GIVEN boss defeated with gold=5000, WHEN `on_boss_defeated()` called, THEN Victory Sparkle (0ms) + Gold Burst (300ms delayed), Heavy Impact vibration (merged), Floor + Currency bounce triggered.

**AC3**: GIVEN enhancement completed at +10, WHEN `on_enhancement_completed()` called, THEN Tier=4, Enhancement Flash + Celebration Burst + Stat bounce triggered synchronously.

---

### Tier Calculation

**AC4**: GIVEN gold=50, WHEN Tier calculated, THEN `floor(log10(50))` = 1 → Tier 1.

**AC5**: GIVEN gold=500, WHEN Tier calculated, THEN `floor(log10(500))` = 2 → Tier 2.

**AC6**: GIVEN enhancement_level=+10, WHEN Tier calculated, THEN `floor(10/3)+1` = 4 → Tier 4.

---

### Layered Feedback

**AC7**: GIVEN boss defeated with layered preset, WHEN feedback triggered, THEN Victory Sparkle at Frame 0, Gold Burst at Frame 300ms.

**AC8**: GIVEN layered feedback with vibration, WHEN triggered, THEN single Heavy Impact vibration (merged), no multiple vibration events.

---

### Skip Mode

**AC9**: GIVEN skip mode enabled, WHEN `on_enemy_defeated()` called, THEN particle duration ≤ 0.3s, vibration compressed to single segment.

**AC10**: GIVEN skip mode disabled, WHEN `on_enemy_defeated()` called, THEN normal particle duration (0.5-1.2s), full vibration sequence.

---

### Performance Monitoring

**AC11**: GIVEN particle budget exceeded (ParticleSystem returns false), WHEN feedback triggered, THEN feedback system logs warning, vibration and stat display still trigger.

**AC12**: GIVEN vibration disabled, WHEN feedback triggered, THEN vibration returns false, particle and stat display still trigger.

---

### Signal Handling

**AC13**: GIVEN unknown event signal received, WHEN handler called, THEN warning logged, no feedback triggered, system not blocked.

**AC14**: GIVEN signal before system initialized, WHEN received, THEN signal ignored, subsequent events handled normally.

---

### Equipment Drop

**AC15**: GIVEN equipment dropped (RARE), WHEN `on_equipment_dropped()` called, THEN Rare Drop Glow + Heavy Impact + Comparison panel triggered.

**AC16**: GIVEN equipment dropped (COMMON), WHEN `on_equipment_dropped()` called, THEN no Rare Drop Glow, simple notification (MVP behavior).

## Open Questions

**OQ1**: Should feedback presets be data-driven (JSON config) or hardcoded in GDScript?

**OQ2**: Should visual feedback system provide a "feedback intensity" setting independent of particle/vibration settings?

**OQ3**: Should layered feedback delays be customizable per event type (not fixed 300ms)?

**OQ4**: Should audio feedback timing be coordinated by visual feedback system or handled independently by 音效系统?

**OQ5**: Should feedback system track "feedback history" for analytics (which events triggered most)?

**OQ6**: Should there be a "feedback preview" mode for designers to test presets without gameplay?

**OQ7**: Should feedback presets support "conditional layers" (e.g., Gold Burst only if gold > 1000)?

**OQ8**: Should skip mode compression be configurable (min duration per event type)?