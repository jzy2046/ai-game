# 音效系统

> **Status**: Designed
> **Author**: User + agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: 爽感反馈

## Overview

音效系统是游戏的听觉反馈基础设施层，负责音频资源的加载管理、AudioStreamPlayer池的维护、音效事件的订阅与播放调度、以及音频总线（Audio Bus）的音量控制。它接收战斗系统、强化系统、装备掉落系统、地牢推进系统、UI系统的游戏事件信号，将事件映射到对应的音效资源（AudioStream），通过对象池模式复用AudioStreamPlayer节点，确保高频音效（如金币拾取、点击反馈）的即时响应和低延迟播放。

**核心职责**:
1. **信号订阅**: 监听 `enemy_defeated`, `enhancement_completed`, `equipment_dropped`, `floor_completed`, `button_clicked` 等上游系统信号
2. **音效映射**: 将事件类型映射到音效资源ID（如 `enemy_defeated` → `sfx_coin_collect`）
3. **播放调度**: 从对象池获取可用AudioStreamPlayer，设置stream和bus，调用play()
4. **分层处理**: Boss击败等复合事件按分层时序播放（victory.wav → 300ms delay → coin.wav）
5. **音量控制**: 通过AudioServer管理Music/SFX/UI三类音频总线的音量和静音

**数据流**:
```
战斗系统 emit enemy_defeated → AudioSystem.on_enemy_defeated()
                              → 查询音效映射表获取 sfx_coin_collect
                              → 从SFX对象池获取可用player
                              → player.stream = preload("sfx_coin_collect.wav")
                              → player.bus = &"SFX"
                              → player.play()
```

**支柱支撑**:
- 爽感反馈: 听觉反馈与视觉、触觉同步，构成"感官三重奏"（粒子+震动+音效）
- 稳定成长: 强化成功音效强度随Tier变化，玩家通过听觉感知"这次进步有多大"
- 掌控节奏: 跳过模式下音效压缩播放，观看模式下完整播放

**ADR引用**: 音效系统实现层架构决策（AudioStreamPlayer池大小、总线配置、资源加载策略）将在 `/architecture-decision` 中定义，待创建。

**MVP范围**: 6种核心音效（敌人击败、Boss击败、装备掉落、强化成功、地牢房间完成、UI点击），使用预加载资源，对象池大小8个SFX player。

## Player Fantasy

**核心幻想**: "听觉是进步的证言" — 每次金币拾取的清脆声、每次强化成功的金属共鸣、每次Boss击败的胜利号角，都在告诉玩家"你做到了"。听觉是感官三重奏中最直接的情感通道——粒子爆发是视觉刺激，设备震动是触觉确认，而音效是大脑最本能的奖励信号。玩家不需要"看到进步"，只需要"听到进步"——音效就是成长的证明。

**锚定时刻**: 第一次强化成功到+5的时刻。玩家刚收集了足够的Enhancement Stone，打开强化界面选中Iron Blade。点击"强化"按钮，看到金币化为能量流入武器，紧接着听到金属碰撞的清脆声 + 能量充能的低频嗡鸣。攻击力数字跳升到15，屏幕震动，粒子爆发。这四个感官输入同时到达——玩家大脑接收"我的武器变强了"的强烈信号。听觉在视觉确认之前到达，是"进步"的第一证言。

**听觉三重奏的节奏感**:
- **同步触发**: 音效与粒子、震动在同一帧触发，创造"瞬间爆发"的冲击感
- **分层延迟**: Boss击败时，胜利号角（0ms）→ 金币声（300ms），形成"胜利→奖励"的叙事节奏
- **强度映射**: Tier越高，音效越响亮、越复杂（普通敌人=轻快金币声，Boss=宏大胜利号角）

**参考时刻**:
- 暗黑破坏神：击杀后金币音效+掉落音效同时触发，击杀有"重量感"
- Clicker Heroes：数值暴涨时的音效反馈，让数字成为爽感载体
- 消消乐：消除成功的清脆音效，每次操作都有听觉奖励

**支柱对应**:
- 爽感反馈：听觉三重奏让进步不可忽视——玩家无法错过每次成长的声音
- 稳定成长：Tier音效强度映射进步量级——玩家通过听觉知道"这次进步有多大"
- 掌控节奏：跳过模式压缩音效，观看模式完整播放——玩家控制听觉体验的节奏
- 多元成长：不同事件有不同音效（击败=金币，强化=金属，掉落=稀有），听觉语言区分成长类型

## Detailed Design

### Core Rules

**Rule 1: Audio Event Subscription**

音效系统订阅上游系统信号，识别音频触发时机：

| Signal Source | Signal Name | Handler Method | Audio Event |
|---------------|-------------|----------------|-------------|
| 战斗系统 | `enemy_defeated(enemy_id, gold_reward, position)` | `on_enemy_defeated()` | `sfx_coin_collect` |
| 战斗系统 | `boss_defeated(boss_id, gold_reward, drops, position)` | `on_boss_defeated()` | `sfx_victory` + `sfx_coin` (layered) |
| 装备掉落系统 | `equipment_dropped(equipment_instance, rarity, position)` | `on_equipment_dropped()` | `sfx_rare_drop` (RARE+ only) |
| 装备强化系统 | `enhancement_completed(equipment_id, old_level, new_level, position)` | `on_enhancement_completed()` | `sfx_enhance_success` |
| 地牢推进系统 | `floor_completed(floor_id, floor_type)` | `on_floor_completed()` | `sfx_victory` |
| UI系统 | `button_clicked(button_position)` | `on_button_clicked()` | `sfx_ui_click` |

---

**Rule 2: Audio Event Registry**

音效事件映射到音效资源ID：

| Audio Event ID | Sound Resource | Bus | Duration | Description |
|----------------|---------------|-----|----------|-------------|
| `sfx_coin_collect` | `coin_collect.wav` | SFX | 0.3s | Light coin pickup sound |
| `sfx_victory` | `victory.wav` | SFX | 1.0s | Victory fanfare |
| `sfx_rare_drop` | `rare_drop.wav` | SFX | 0.8s | Rare item drop shimmer |
| `sfx_enhance_success` | `enhance_success.wav` | SFX | 0.5s | Metallic clang + energy hum |
| `sfx_ui_click` | `button_click.wav` | UI | 0.15s | Light tap sound |

**Registry路径**: `assets/data/config/audio_registry.json`

---

**Rule 3: Audio Stream Player Pool**

音效系统使用对象池管理AudioStreamPlayer节点：

**Pool配置**:
- **SFX Pool**: 8 AudioStreamPlayer nodes (bus = &"SFX")
- **UI Pool**: 2 AudioStreamPlayer nodes (bus = &"UI")
- **池节点创建**: 在 `_ready()` 中预创建，作为子节点

**Pool实现**:
```gdscript
var _sfx_pool: Array[AudioStreamPlayer] = []
var _ui_pool: Array[AudioStreamPlayer] = []

func _ready() -> void:
    for i in range(8):
        var player := AudioStreamPlayer.new()
        player.bus = &"SFX"
        add_child(player)
        _sfx_pool.append(player)
    
    for i in range(2):
        var player := AudioStreamPlayer.new()
        player.bus = &"UI"
        add_child(player)
        _ui_pool.append(player)

func get_available_player(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
    for player in pool:
        if not player.playing:
            return player
    return null  # Pool exhausted
```

---

**Rule 4: SFX Playback Execution**

播放音效时从池获取player并执行：

**播放流程**:
```gdscript
func play_sfx(sound_id: String) -> void:
    var stream: AudioStream = _sound_registry[sound_id]
    var player: AudioStreamPlayer = get_available_player(_sfx_pool)
    if player == null:
        return  # Pool exhausted, skip sound
    player.stream = stream
    player.play()
```

**资源加载**: 使用 `preload()` 在启动时加载所有音效资源：
```gdscript
const SFX_COIN := preload("res://assets/audio/sfx/coin_collect.wav")
const SFX_VICTORY := preload("res://assets/audio/sfx/victory.wav")
const SFX_RARE_DROP := preload("res://assets/audio/sfx/rare_drop.wav")
const SFX_ENHANCE := preload("res://assets/audio/sfx/enhance_success.wav")
const SFX_UI_CLICK := preload("res://assets/audio/ui/button_click.wav")
```

---

**Rule 5: Layered Audio for Composite Events**

复合事件（Boss击败）触发分层音效：

**Boss Defeated分层流程**:
```
Frame 0:    播放 sfx_victory (胜利号角)
Frame 300ms: 播放 sfx_coin_collect (金币拾取)
```

**分层实现**:
```gdscript
func on_boss_defeated(boss_id: String, gold_reward: int, drops: Array, position: Vector2) -> void:
    play_sfx("sfx_victory")  # Immediate
    await get_tree().create_timer(0.3).timeout
    play_sfx("sfx_coin_collect")  # Delayed 300ms
```

**分层延迟**: 与视觉反馈系统 Rule 5 同步（粒子Gold Burst延迟300ms）。

---

**Rule 6: Audio Bus Configuration**

音频总线通过AudioServer管理：

**Bus结构**:
| Bus Name | Purpose | Default Volume | Mute Support |
|----------|---------|----------------|--------------|
| Master | 全局音量控制 | 0 dB | Yes |
| Music | 背景音乐（Post-MVP） | 0 dB | Yes |
| SFX | 游戏音效 | 0 dB | Yes |
| UI | UI交互音效 | -6 dB (quieter) | Yes |

**音量控制接口**:
```gdscript
func set_bus_volume(bus_name: StringName, volume_db: float) -> void:
    var bus_idx: int = AudioServer.get_bus_index(bus_name)
    AudioServer.set_bus_volume_db(bus_idx, volume_db)

func set_bus_mute(bus_name: StringName, mute: bool) -> void:
    var bus_idx: int = AudioServer.get_bus_index(bus_name)
    AudioServer.set_bus_mute(bus_idx, mute)
```

---

**Rule 7: Skip Mode Audio Compression**

跳过战斗模式下的音效压缩：

**压缩规则**:
- Boss defeated: 仅播放 `sfx_victory`，跳过 `sfx_coin_collect`
- 敌人击败: 正常播放 `sfx_coin_collect`（快速结算仍有音效）
- 音效时长不压缩（音效本身很短，无需截断）

**Skip Mode Flag**:
```gdscript
var _skip_mode: bool = false

func set_skip_mode(enabled: bool) -> void:
    _skip_mode = enabled

func on_boss_defeated(...) -> void:
    play_sfx("sfx_victory")
    if not _skip_mode:
        await get_tree().create_timer(0.3).timeout
        play_sfx("sfx_coin_collect")
```

---

**Rule 8: Audio Settings Interface**

音效系统提供音量设置接口：

| Method | Parameters | Return | Purpose |
|--------|------------|--------|---------|
| `set_master_volume(volume_db)` | float | void | 设置全局音量 |
| `set_sfx_volume(volume_db)` | float | void | 设置音效音量 |
| `set_ui_volume(volume_db)` | float | void | 设置UI音量 |
| `mute_all(mute)` | bool | void | 全局静音 |
| `is_audio_enabled()` | — | bool | 检查音频是否启用 |

---

### States and Transitions

音效系统无复杂状态，但维护内部状态标志：

| State | Description | Entry | Exit |
|-------|-------------|-------|------|
| **Idle** | 无播放活动 | 初始化/播放完成 | 信号触发 |
| **Playing** | 有活跃播放 | 信号触发 | 播放完成 |
| **SkipMode** | 跳过模式激活 | `set_skip_mode(true)` | `set_skip_mode(false)` |
| **Muted** | 全局静音 | `mute_all(true)` | `mute_all(false)` |

---

### Interactions with Other Systems

**上游依赖**:

| System | Signal Subscribed | Handler | Critical? |
|--------|------------------|---------|-----------|
| 战斗系统 | `enemy_defeated` | `on_enemy_defeated()` | Yes |
| 战斗系统 | `boss_defeated` | `on_boss_defeated()` | Yes |
| 装备掉落系统 | `equipment_dropped` | `on_equipment_dropped()` | Yes |
| 装备强化系统 | `enhancement_completed` | `on_enhancement_completed()` | Yes |
| 地牢推进系统 | `floor_completed` | `on_floor_completed()` | Yes |
| UI系统 | `button_clicked` | `on_button_clicked()` | Soft |
| 视觉反馈系统 | `set_skip_mode(enabled)` | `set_skip_mode()` | Yes |

**下游依赖**:

| System | Interface Provided | Purpose |
|--------|-------------------|---------|
| 存档系统 | `get_audio_settings()`, `save_audio_settings()` | 音量设置持久化 |
| 设置界面 | `set_master_volume()`, `set_sfx_volume()`, `mute_all()` | UI音量控制 |

## Formulas

### F1: Audio Pool Size Calculation

The audio pool size formula is defined as:

`pool_size = max_concurrent_events + buffer_capacity`

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| max_concurrent_events | int | 4–6 | Maximum simultaneous SFX events expected |
| buffer_capacity | int | 2–4 | Extra nodes for edge cases |
| pool_size | int | 6–10 | Total AudioStreamPlayer nodes in pool |

**Output Range:** MVP uses 8 (6 concurrent + 2 buffer)
**Example:** Normal combat: 2-3 enemy defeats concurrent, Boss defeat: 1 victory + 1 coin (layered) = 2 concurrent. Pool of 8 handles edge cases.

---

### F2: Audio Volume Scale

The volume scale formula for intensity mapping:

`volume_db = base_volume + (tier - 1) * TIER_VOLUME_INCREMENT`

**Variables:**
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| base_volume | float | 0 dB | Default volume for Tier 1 |
| tier | int | 1–5 | Intensity tier level |
| TIER_VOLUME_INCREMENT | float | 2 dB | Volume increase per tier |
| volume_db | float | 0–8 dB | Final volume for playback |

**Output Range:** Tier 1 = 0 dB, Tier 5 = 8 dB (noticeably louder but not overwhelming)

**Example:** Enhancement +10 (Tier 4):
```
volume_db = 0 + (4 - 1) * 2 = 6 dB
```

---

### F3: Layer Delay Duration

Layer delay for composite audio events:

`layer_delay_ms = LAYER_DELAY_TABLE[layer_index]`

**Layer Delay Table:**
| Layer | Event | Delay (ms) | Source |
|-------|-------|------------|--------|
| 1 | Victory sound | 0 | Immediate |
| 2 | Coin sound | 300 | Matches visual Gold Burst delay |

**Reference**: Matches 视觉反馈系统 Formula 3 (Layer Delay Calculation).

---

### F4: Pool Exhaustion Skip Priority

When pool is exhausted, prioritize which sounds to skip:

`priority_score = event_priority - wait_time_penalty`

**Priority Table:**
| Event | event_priority | Notes |
|-------|---------------|-------|
| Boss Defeated (Victory) | 10 | Highest - milestone moment |
| Enhancement Success | 8 | Important feedback |
| Equipment Drop (RARE+) | 7 | Celebratory |
| Floor Complete | 5 | Moderate |
| Enemy Defeated (Coin) | 3 | Common, skippable |
| UI Click | 1 | Lowest, cosmetic |

**Output:** If pool exhausted, skip lowest priority sound. UI clicks are first to skip.

---

### Summary Table: Audio Events and Properties

| Event | Sound | Duration | Volume (Tier 1) | Pool | Layer Delay |
|-------|-------|----------|-----------------|------|-------------|
| Enemy Defeated | coin_collect.wav | 0.3s | 0 dB | SFX | 0ms |
| Boss Defeated | victory.wav | 1.0s | 0 dB | SFX | Layer 1: 0ms |
| Boss Defeated (delayed) | coin_collect.wav | 0.3s | 0 dB | SFX | Layer 2: 300ms |
| Equipment Drop (RARE+) | rare_drop.wav | 0.8s | 0 dB | SFX | 0ms |
| Enhancement Success | enhance_success.wav | 0.5s | 0 dB + tier bonus | SFX | 0ms |
| Floor Complete | victory.wav | 1.0s | 0 dB | SFX | 0ms |
| UI Click | button_click.wav | 0.15s | -6 dB | UI | 0ms |

## Edge Cases

### E1: Pool Exhausted During High-Frequency Events

**场景**: Boss击败后快速结算多个敌人击败事件，SFX pool所有8个player都在播放。

**处理**:
- 检测pool耗尽 (`get_available_player()` 返回 null)
- 按优先级跳过最低优先级音效（UI Click优先跳过，Enemy Defeated次之）
- Boss Victory和Enhancement Success永不跳过（最高优先级）
- 不阻塞游戏流程，音效静默跳过

---

### E2: Audio Disabled in Player Settings

**场景**: 玩家在设置中关闭音频，但事件仍触发音效请求。

**处理**:
- 检查 `AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master"))`
- 若Master bus静音，直接返回，不播放任何音效
- 信号仍被接收，但播放逻辑被跳过
- UI显示音频关闭状态图标

---

### E3: Boss Defeated During Skip Mode

**场景**: 跳过战斗模式下Boss击败，分层音效应压缩。

**处理**:
- 播放 `sfx_victory`（胜利号角）
- 跳过延迟的 `sfx_coin_collect`（`_skip_mode = true`时不执行await后的代码）
- 仍保留胜利反馈，但无分层延迟
- 总音效时长: 1.0s（仅victory）而非 1.3s（victory + coin）

---

### E4: RARE Equipment Drop While Pool Busy

**场景**: RARE装备掉落时pool仅有1个可用player，但需要播放稀有掉落音效。

**处理**:
- RARE Drop优先级=7，高于Enemy Defeated(3)和UI Click(1)
- 若pool有可用player，正常播放
- 若pool耗尽，等待最低优先级音效完成（UI Click通常0.15s）
- 不强制打断正在播放的高优先级音效

---

### E5: Rapid UI Click Spamming

**场景**: 玩家快速连续点击UI按钮，触发大量 `button_clicked` 信号。

**处理**:
- UI pool仅2个player，连续点击会耗尽
- 第3+次点击音效被跳过
- 不排队、不延迟，直接跳过
- UI音效本身很短(0.15s)，自然恢复快

---

### E6: Audio Stream Resource Missing

**场景**: 音效资源文件不存在（`preload()` 返回 null 或路径错误）。

**处理**:
- 启动时验证所有preload资源存在
- 若资源缺失，记录错误日志，使用fallback静默
- 不阻塞游戏启动，仅该音效无反馈
- 开发阶段需验证所有音效文件存在

---

### E7: Scene Transition During Layered Audio

**场景**: Boss击败后播放victory音效，但玩家快速推进下一层触发场景切换，coin音效待播放。

**处理**:
- 场景切换时调用 `AudioSystem.cancel_all_sfx()`
- 停止所有活跃AudioStreamPlayer
- 取消待执行的延迟播放（await被打断）
- 进入新场景后音效系统恢复Idle

---

### E8: Enhancement Completed During Combat

**场景**: 战斗进行中玩家打开强化界面并强化装备，两个系统同时发出信号。

**处理**:
- Enhancement音效独立播放，不与Combat音效冲突
- Pool有足够容量（8 player），两音效并发播放
- Enhancement优先级=8，高于Enemy Defeated=3，确保播放
- 若pool耗尽，Enemy Defeated音效被跳过

---

### E9: Zero Volume Settings

**场景**: 玩家将音量滑块拖到最低（volume_db = -80 dB 或更低）。

**处理**:
- AudioServer支持负dB值，-80dB为静音
- 音效仍播放但不可闻
- 不视为静音模式，仍占用pool player
- 设置界面应将最低值映射到mute而非-80dB

---

### E10: Audio Settings Persistence

**场景**: 玩家修改音量设置后关闭游戏，设置应持久化。

**处理**:
- 音量设置存储在存档系统 `audio_settings` 字段
- 启动时读取并应用: `set_bus_volume()` from saved values
- 默认值: Master 0dB, SFX 0dB, UI -6dB
- 每次修改触发存档系统critical save

## Dependencies

### Upstream Dependencies (信号订阅)

| System | Signal | Handler | Critical? | GDD Reference |
|--------|--------|---------|-----------|---------------|
| 战斗系统 | `enemy_defeated(enemy_id, gold_reward, position)` | `on_enemy_defeated()` | Yes | combat-system.md |
| 战斗系统 | `boss_defeated(boss_id, gold_reward, drops, position)` | `on_boss_defeated()` | Yes | combat-system.md |
| 装备掉落系统 | `equipment_dropped(equipment_instance, rarity, position)` | `on_equipment_dropped()` | Yes | equipment-drop-system.md |
| 装备强化系统 | `enhancement_completed(equipment_id, old_level, new_level, position)` | `on_enhancement_completed()` | Yes | equipment-enhancement-system.md |
| 地牢推进系统 | `floor_completed(floor_id, floor_type)` | `on_floor_completed()` | Yes | dungeon-advancement-system.md |
| UI系统 | `button_clicked(button_position)` | `on_button_clicked()` | Soft | ui-layout-system.md |
| 视觉反馈系统 | `set_skip_mode(enabled)` | `set_skip_mode()` | Yes | visual-feedback-system.md |

**Signal Contracts**:
- 所有信号携带事件上下文参数（enemy_id, position等）
- 音效系统仅使用事件类型，不依赖具体参数值（Tier由视觉反馈系统计算）

---

### Downstream Dependencies (接口提供)

| System | Interface Used | Purpose | Critical? |
|--------|---------------|---------|-----------|
| 存档系统 | `get_audio_settings()`, `save_audio_settings(dict)` | 音量设置持久化 | Yes |
| 设置界面 | `set_master_volume(db)`, `set_sfx_volume(db)`, `set_ui_volume(db)`, `mute_all(bool)` | UI音量控制 | Yes |
| 视觉反馈系统 | 音效播放同步（无直接接口调用，通过信号协调） | 同步触发 | No |

---

### Engine Dependencies

| Dependency | Type | Usage | Notes |
|------------|------|-------|-------|
| AudioServer | Hard | Bus volume control, mute | Godot core API |
| AudioStreamPlayer | Hard | Sound playback | Pool pattern recommended |
| AudioStream | Hard | Sound resource | WAV/OGG format |
| preload() | Hard | Resource loading | Startup pre-load all SFX |

---

### Dependency Notes

- 音效系统不依赖粒子、震动、数值显示系统的返回值
- 音效系统是"消费者"角色，被动响应上游信号
- 存档系统提供音量设置的持久化接口
- 无双向依赖——音效系统不发出信号供其他系统订阅

## Tuning Knobs

| Knob | Default | Safe Range | Unit | What It Affects | Extreme Behavior |
|------|---------|------------|------|-----------------|------------------|
| **SFX_POOL_SIZE** | 8 | 4–12 | nodes | Concurrent SFX capacity | 太少：音效被跳过；太多：内存浪费 |
| **UI_POOL_SIZE** | 2 | 1–4 | nodes | Concurrent UI click capacity | 太少：UI点击无声；太多：不必要 |
| **TIER_VOLUME_INCREMENT** | 2 | 1–4 | dB | Volume increase per tier | 太低：Tier无区分；太高：高Tier过响 |
| **UI_BUS_BASE_VOLUME** | -6 | -12–0 | dB | UI sound relative volume | 太低：UI无声；太高：UI干扰游戏音效 |
| **LAYER_DELAY_COIN** | 300 | 100–500 | ms | Boss victory→coin delay | 太短：无叙事节奏；太长：拖沓 |
| **MASTER_VOLUME_DEFAULT** | 0 | -40–0 | dB | Default master volume | 太低：全部音效不可闻 |

### Knob Configuration File

All knobs defined in `assets/data/tuning/audio_config.json`:

```json
{
  "version": "1.0.0",
  "pools": {
    "sfx_pool_size": 8,
    "ui_pool_size": 2
  },
  "volume": {
    "tier_volume_increment": 2,
    "ui_bus_base_volume": -6,
    "master_volume_default": 0
  },
  "timing": {
    "layer_delay_coin_ms": 300
  }
}
```

### Knob Interaction Notes

- **SFX_POOL_SIZE + UI_POOL_SIZE**: Total AudioStreamPlayer nodes ≈ memory footprint
- **TIER_VOLUME_INCREMENT**: Affects perceived intensity difference between Tier 1 and Tier 5 events
- **LAYER_DELAY_COIN**: Must match visual feedback system's particle layer delay for sensory sync

## Visual/Audio Requirements

### Audio Event Specification

| Event | Sound File | Bus | Duration | Characteristics | Tier Effect |
|-------|------------|-----|----------|-----------------|-------------|
| **Enemy Defeated** | `coin_collect.wav` | SFX | 0.3s | Light, crisp coin sound. Bright tone, quick decay. | Volume +0–8dB by tier |
| **Boss Defeated (Victory)** | `victory.wav` | SFX | 1.0s | Triumphant fanfare. Brass-inspired, crescendo start, resolving end. | Fixed volume |
| **Boss Defeated (Coin)** | `coin_collect.wav` | SFX | 0.3s | Same as Enemy Defeated, played 300ms after victory. | Volume by gold tier |
| **Equipment Drop (RARE+)** | `rare_drop.wav` | SFX | 0.8s | Shimmer sound. Magical chime with sustain. Ethereal, celebratory. | Fixed volume |
| **Enhancement Success** | `enhance_success.wav` | SFX | 0.5s | Metallic clang + energy hum. Two-stage: impact then glow. | Volume +0–8dB by tier |
| **Floor Complete** | `victory.wav` | SFX | 1.0s | Same as Boss Victory. Celebratory end. | Fixed volume |
| **UI Click** | `button_click.wav` | UI | 0.15s | Light tap. Subtle, non-intrusive. Quick attack/decay. | Fixed volume |

---

### Audio Bus Layout

| Bus | Parent | Purpose | Default Volume | Mute Setting |
|-----|--------|---------|----------------|--------------|
| **Master** | — | Global control | 0 dB | Master mute toggle |
| **Music** | Master | Background music (Post-MVP) | 0 dB | Music mute toggle |
| **SFX** | Master | Game sound effects | 0 dB | SFX mute toggle |
| **UI** | Master | UI interaction sounds | -6 dB | UI mute toggle |

---

### Audio File Specifications

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| **Format** | WAV (uncompressed) | Short SFX, low memory footprint |
| **Sample Rate** | 44100 Hz | Standard mobile quality |
| **Bit Depth** | 16-bit | Adequate for short sounds |
| **Channels** | Mono | 2D non-spatial audio |
| **Max File Size** | 500 KB per sound | Total ~3.5 MB for 7 sounds |

---

### Sensory Synchronization

音效与视觉、触觉反馈的同步要求：

| Event | Audio | Visual (Particle) | Tactile (Vibration) | Sync Requirement |
|-------|-------|-------------------|--------------------|------------------|
| Enemy Defeated | coin_collect.wav | Gold Burst | Medium Pulse | Same frame (Frame 0) |
| Boss Defeated | victory.wav | Victory Sparkle | Heavy Impact | Same frame |
| Boss Defeated (delayed) | coin_collect.wav (300ms) | Gold Burst (300ms) | — | Delayed sync |
| Enhancement Success | enhance_success.wav | Enhancement Flash | Celebration Burst | Same frame |
| UI Click | button_click.wav | UI Popup Burst | Light Tap | Same frame |

**同步实现**: 所有音效调用与粒子/震动调用在同一帧内完成，无需额外延迟机制（除Boss分层）。

---

📌 **Asset Spec** — Audio requirements are defined. After the art bible is approved, run `/asset-spec system:audio-system` to produce per-sound specifications including duration, frequency characteristics, and generation prompts from this section.

## UI Requirements

音效系统本身无直接游戏内UI界面，但提供设置界面接口。

### Settings UI Integration

| Setting | UI Element | Range | Default | Description |
|---------|------------|-------|---------|-------------|
| **Master Volume** | Slider | 0–100% | 100% | 全局音量控制 |
| **SFX Volume** | Slider | 0–100% | 100% | 游戏音效音量 |
| **UI Volume** | Slider | 0–100% | 50% | UI点击音效音量 |
| **Master Mute** | Toggle | On/Off | Off | 全局静音开关 |

**Volume Mapping**: Slider percentage → dB via `volume_db = linear_to_db(percentage / 100.0)`
- 100% = 0 dB (full volume)
- 50% = -6 dB (half perceived volume)
- 0% = -80 dB (effectively mute)

---

### Audio Feedback Indicators

| Indicator | Element | Display Condition | Purpose |
|-----------|---------|-------------------|---------|
| **Audio Off Icon** | Icon overlay | Master mute = true | 告知玩家音频已关闭 |
| **Volume Level** | Numeric label | Settings screen | 显示当前音量百分比 |

---

### UI Requirements from Upstream Systems

| System | UI Element | Audio Requirement |
|--------|------------|-------------------|
| 触控输入系统 | All buttons | 每次点击触发 `sfx_ui_click` |
| 设置界面 | Volume sliders | 实时音量调整，无音效反馈 |

---

### Skip Mode UI (Optional)

| Setting | UI Element | Default | Description |
|---------|------------|---------|-------------|
| Skip Mode | Hidden | Off | 由战斗系统控制，音效系统接收flag |

**MVP范围**: 音效系统不直接控制UI，仅响应设置界面的音量调整。

## Acceptance Criteria

### Audio Playback Criteria

**AC1**: GIVEN enemy defeated event, WHEN `on_enemy_defeated()` called, THEN `sfx_coin_collect` plays from SFX pool, volume at base level (0 dB).

**AC2**: GIVEN boss defeated event, WHEN `on_boss_defeated()` called, THEN `sfx_victory` plays immediately, `sfx_coin_collect` plays after 300ms delay.

**AC3**: GIVEN enhancement completed at +10 (Tier 4), WHEN `on_enhancement_completed()` called, THEN `sfx_enhance_success` plays at volume 6 dB.

---

### Pool Management Criteria

**AC4**: GIVEN 8 concurrent SFX requests, WHEN all pool players active, THEN lowest priority sounds (UI Click) are skipped, higher priority sounds play.

**AC5**: GIVEN pool exhausted, WHEN Boss Victory requested, THEN Boss Victory always plays (priority 10), no skip.

**AC6**: GIVEN pool with available player, WHEN `get_available_player()` called, THEN returns available AudioStreamPlayer, not null.

---

### Volume Control Criteria

**AC7**: GIVEN Master volume slider at 50%, WHEN `set_master_volume()` called, THEN Master bus volume = -6 dB.

**AC8**: GIVEN Master mute enabled, WHEN `mute_all(true)` called, THEN all audio buses muted, `play_sfx()` returns without playing.

**AC9**: GIVEN Tier 3 event, WHEN volume calculated, THEN volume_db = 0 + (3-1) * 2 = 4 dB.

---

### Skip Mode Criteria

**AC10**: GIVEN skip mode enabled, WHEN `on_boss_defeated()` called, THEN `sfx_victory` plays, `sfx_coin_collect` skipped (no delayed play).

**AC11**: GIVEN skip mode disabled, WHEN `on_boss_defeated()` called, THEN both `sfx_victory` and delayed `sfx_coin_collect` play.

---

### Settings Persistence Criteria

**AC12**: GIVEN player changes Master volume to 70%, WHEN game restarted, THEN Master volume restored to 70% from saved settings.

**AC13**: GIVEN player mutes all audio, WHEN game restarted, THEN Master mute restored to true from saved settings.

---

### Sensory Sync Criteria

**AC14**: GIVEN enemy defeated, WHEN audio plays, THEN particle burst and vibration trigger on same frame (synchronous).

**AC15**: GIVEN boss defeated (layered), WHEN victory audio plays at Frame 0, THEN Victory Sparkle particle and Heavy Impact vibration also trigger at Frame 0.

---

### Edge Case Criteria

**AC16**: GIVEN audio resource missing, WHEN `play_sfx()` called, THEN error logged, no crash, game continues without that sound.

**AC17**: GIVEN scene transition, WHEN `cancel_all_sfx()` called, THEN all active AudioStreamPlayers stop, pending layered sounds cancelled.

## Open Questions

**OQ1**: Should audio system support pitch variation for variety? (e.g., random pitch shift ±5% for coin sounds to avoid repetitive identical sounds)

**OQ2**: Should there be a "audio preview" mode for designers to test sounds without gameplay?

**OQ3**: Should layered audio delays be customizable per event type (not fixed 300ms)?

**OQ4**: Should audio system emit a `audio_played` signal for analytics tracking (which sounds played most)?

**OQ5**: Should there be different sound variants for same event? (e.g., 3 different coin sounds randomly selected)

**OQ6**: Should UI click sound be disabled during rapid scrolling to avoid audio spam?

**OQ7**: Should background music be added (Post-MVP), and how would it interact with SFX priority?

**OQ8**: Should audio system support fade-in/fade-out transitions for music changes?