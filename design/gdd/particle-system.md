# 粒子系统 (Particle System)

> **Status**: Approved
> **Author**: user + agents
> **Last Updated**: 2026-05-01
> **Implements Pillar**: 爽感反馈

## Overview

粒子系统是游戏的视觉反馈基础设施层，负责管理和播放所有粒子效果。它提供统一的粒子播放接口，让其他系统（视觉反馈系统、战斗系统、强化系统）能够触发粒子爆发来庆祝玩家的进步时刻。粒子系统管理粒子池、控制性能预算、定义粒子预设模板，确保移动端60fps流畅运行。

从玩家视角，粒子系统是"进步的视觉语言"。每次击败敌人时金币粒子爆发、每次强化成功时金色闪光炸裂、每次获得稀有装备时紫色粒子飞溅——这些视觉反馈让进步"炸"出存在感。粒子是游戏支柱"爽感反馈"的核心载体，玩家不需要意识到粒子系统的存在，但每次看到粒子爆发，都会感受到"我变强了"的满足感。

MVP阶段粒子系统管理以下粒子预设：
- **Gold Burst**: 金币爆发 — 敌人击败、金币获得
- **Enhancement Flash**: 强化闪光 — 装备强化成功
- **Rare Drop Glow**: 稀有掉落光效 — 稀有装备获得
- **Victory Sparkle**: 胜利闪烁 — 地牢房间完成、Boss击败
- **UI Popup Burst**: UI弹出粒子 — 按钮点击、面板打开

粒子系统使用 Godot 4.6 的 GPUParticles2D 实现，配合 ParticleProcessMaterial 定义粒子行为曲线。所有粒子预设存储在 `assets/data/particles/` 目录，支持热更新和设计师调整。

## Player Fantasy

粒子系统支撑的核心玩家幻想是：

> **"每次进步都是一场庆祝的交响"** — 粒子不是装饰，而是进步的掌声。金币爆发是"你获得财富"，强化闪光是"你变得更强"，稀有掉落光效是"你发现了宝藏"。每次粒子触发都是游戏对玩家进步的即时认可，创造一种"游戏在为我庆祝"的共享胜利感。

这支撑支柱**爽感反馈**：
- 每次操作都伴随粒子爆发，让进步"炸"出存在感
- 粒子是进步的统一视觉语言 — 不同系统有不同粒子"乐器"（金币 = 金色爆发，强化 = 闪光，稀有 = 紫色光晕）
- 多系统叠加时粒子"合奏"（Boss击败触发金币+掉落+胜利闪烁三重粒子）

这支撑支柱**稳定成长**：
- 粒子强度随进度增长 — +1强化是闪光，+10强化是光爆瀑布，粒子强度映射玩家投入
- 每次粒子触发都是进步的"证据"，玩家看到就知道"我确实进步了"

这支撑支柱**掌控节奏**：
- 玩家选择跳过战斗时粒子简洁快速，玩家选择观看时粒子丰富完整
- 粒子播放不强制等待 — 粒子是进步的伴奏，不是进度条

**参考**: 暗黑破坏神 — 每次击杀后金币粒子爆发飞出，让"获得"成为可感知的瞬间；梦幻西游手游 — 升级时全屏粒子庆祝，让里程碑成为记忆点。

## Detailed Design

### Core Rules

**Rule 1: 粒子预设定义**
粒子系统提供5种预设模板，每种预设定义粒子数量、颜色、形状、运动曲线、持续时间：
- **Gold Burst**: 金色圆形粒子，向外爆发，重力下落，8-12个粒子（Tier 1）
- **Enhancement Flash**: 白色闪光粒子，中心聚拢后扩散，12-18个粒子
- **Rare Drop Glow**: 紫色光晕粒子，旋转上升，缓慢消散，15-25个粒子
- **Victory Sparkle**: 多色星形粒子，全屏分布，闪烁消散，20-30个粒子
- **UI Popup Burst**: 小型白色粒子，从点击位置向四周扩散，4-6个粒子

**Rule 2: 触发事件映射**
其他系统调用粒子播放接口时，粒子系统根据事件类型自动选择预设：
- 敌人击败 → `Gold Burst`（Tier由敌人金币奖励决定）
- Boss击败 → `Victory Sparkle` + `Gold Burst`（分层叠加，见Rule 4）
- 装备强化成功 → `Enhancement Flash`（Tier由强化等级决定）
- 稀有装备掉落 → `Rare Drop Glow`（固定Tier 3）
- 地牢房间完成 → `Victory Sparkle`（Tier由房间类型决定）
- 按钮点击/面板打开 → `UI Popup Burst`（固定Tier 1）

**Rule 3: 粒子强度分级**
每种预设支持6级强度（Tier 1-6），Tier决定粒子数量和视觉冲击力：
| Tier | 粒子数量 | 适用场景 |
|------|---------|---------|
| 1 | 8-12 | 小额金币获得（<100）、+1强化 |
| 2 | 20-30 | 中额金币（100-500）、+3强化 |
| 3 | 40-50 | 大额金币（500-1000）、稀有掉落 |
| 4 | 60-80 | Boss金币（>1000）、+7强化 |
| 5 | 80-120 | 全房间胜利、+10强化 |
| 6 | 120-200 | 全地牢通关、传说掉落（超出MVP） |

调用方传入Tier参数，或粒子系统根据奖励数值自动计算。

**Rule 4: 分层叠加规则**
当多个事件同时触发粒子时，粒子系统按优先级分层播放：
- **优先级排序**: Rare Drop > Enhancement > Victory > Gold/UI
- **最大并发层数**: 3层（超过3层时，低优先级粒子被跳过）
- **分层示例**: Boss击败时，先播Victory Sparkle（高优先级），延迟0.2秒后播Gold Burst（低优先级），形成"胜利→奖励"的节奏感
- **避免遮挡**: 高优先级粒子使用较大粒子尺寸或中心位置，低优先级使用小粒子或边缘位置

**Rule 5: 粒子持续时间**
粒子播放有最小可见时长和最大总时长约束：
- **最小可见时长**: 0.3秒（即使跳过战斗，粒子也必须播放0.3秒才能取消）
- **最大总时长**: Tier 1-2: 0.5秒 / Tier 3-4: 0.8秒 / Tier 5-6: 1.2秒
- **淡出曲线**: 最后20%时间使用ease-out曲线淡出，避免突然消失
- **自动清理**: 粒子播放完毕后自动回收至粒子池

**Rule 6: 取消与打断规则**
粒子可在特定情况下被取消或打断：
- **场景切换**: 进入新地牢房间时，当前房间所有粒子立即停止并清理
- **跳过战斗**: 玩家选择跳过战斗时，Gold Burst粒子播放0.3秒最小时长后停止
- **性能紧急**: 当粒子总数超过200（Rule 8性能预算）时，低优先级粒子被强制停止
- **取消动画**: 被取消的粒子使用0.1秒快速淡出，而非立即消失

**Rule 7: 技术实现（GPUParticles2D + Pooling）**
粒子系统使用Godot 4.6的GPUParticles2D实现，配合粒子池管理：
- **GPUParticles2D**: 利用GPU批量渲染，移动端性能优于CPUParticles2D
- **粒子池**: 预加载5个Emitter实例（每类型1个），播放时激活，结束后回收
- **Texture Atlas**: 所有粒子纹理打包在128x128纹理图集，减少材质切换
- **ProcessMaterial**: 每种预设使用独立的ParticleProcessMaterial资源，定义运动曲线、颜色渐变、重力参数
- **调用接口**: `emit_particle(event_type: String, tier: int, position: Vector2) → void`

**Rule 8: 性能预算**
粒子系统遵守移动端性能约束：
- **最大粒子总数**: 200个活跃粒子（跨所有Emitter）
- **最大Emitter数量**: 4个并发Emitter
- **Draw Call限制**: 粒子渲染不超过10 Draw Calls（使用Texture Atlas减少材质切换）
- **帧时间预算**: 粒子更新不超过2ms/帧（避免拖慢主循环）
- **性能监控**: 每秒检查活跃粒子数，超过预算时触发Rule 6取消逻辑

### States and Transitions

粒子系统本身无复杂状态，但每个Emitter实例有生命周期状态：

| State | Description | Transitions |
|-------|-------------|-------------|
| **Idle** | Emitter在粒子池中，未激活 | → Emitting (调用emit_particle) |
| **Emitting** | Emitter激活，正在发射粒子 | → Fading (粒子数量达标或时长结束) |
| **Fading** | Emitter停止发射，粒子正在淡出 | → Idle (粒子全部消失，回收至池) |
| **Cancelled** | Emitter被强制取消（场景切换/性能紧急） | → Idle (快速淡出后回收) |

**状态转换触发条件**:
- Idle → Emitting: 收到`emit_particle`调用
- Emitting → Fading: 播放时长达到`max_duration - fade_time`
- Emitting → Fading: 粒子数量达到Tier上限
- Fading → Idle: 所有粒子alpha值降至0
- Any → Cancelled: 收到`cancel_all()`调用或性能紧急

### Interactions with Other Systems

| System | Interaction Type | Description |
|--------|-----------------|-------------|
| **战斗系统** | Upstream (Caller) | 敌人击败时调用`emit_particle("gold_burst", tier, position)` |
| **装备强化系统** | Upstream (Caller) | 强化成功时调用`emit_particle("enhancement_flash", tier, position)` |
| **装备掉落系统** | Upstream (Caller) | 稀有掉落时调用`emit_particle("rare_drop_glow", 3, position)` |
| **地牢推进系统** | Upstream (Caller) | 房间完成时调用`emit_particle("victory_sparkle", tier, center_pos)` |
| **UI系统** | Upstream (Caller) | 按钮点击时调用`emit_particle("ui_popup", 1, click_pos)` |
| **视觉反馈系统** | Downstream (Coordinator) | 视觉反馈系统协调粒子+震动+数值显示的同步节奏 |
| **震动反馈系统** | Peer (同步触发) | 同一事件同时触发粒子+震动，由视觉反馈系统协调调用顺序 |

**接口定义**:
```gdscript
# ParticleSystem提供的公共接口
func emit_particle(event_type: String, tier: int, position: Vector2) -> void
func cancel_all() -> void  # 场景切换时调用
func get_active_count() -> int  # 性能监控使用
```

## Formulas

### Formula 1: 金币粒子强度计算 (Gold Tier Calculation)

**目的**: 根据敌人金币奖励金额，自动计算Gold Burst粒子应使用的Tier等级。

**公式**:
```
gold_tier = clamp(floor(log10(gold_reward)), 1, 5)
```

**变量定义**:
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `gold_reward` | int | 1 - 10000+ | 敌人击败后获得的金币数量 |
| `gold_tier` | int | 1 - 5 | 输出的粒子强度等级 |

**计算示例**:
- gold_reward = 50 → log10(50) ≈ 1.7 → floor → 1 → **Tier 1**
- gold_reward = 500 → log10(500) ≈ 2.7 → floor → 2 → **Tier 2**
- gold_reward = 5000 → log10(5000) ≈ 3.7 → floor → 3 → **Tier 3**

**逻辑**: 每10倍金币增长提升1级Tier，确保粒子强度与奖励量级匹配。Tier 6保留给特殊事件（全地牢通关），金币奖励不触发Tier 6。

---

### Formula 2: 强化粒子强度计算 (Enhancement Tier Calculation)

**目的**: 根据装备强化等级，计算Enhancement Flash粒子应使用的Tier等级。

**公式**:
```
enhancement_tier = clamp(floor(enhancement_level / 3) + 1, 1, 5)
```

**变量定义**:
| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `enhancement_level` | int | 0 - 10 | 装备当前强化等级（+0到+10） |
| `enhancement_tier` | int | 1 - 5 | 输出的粒子强度等级 |

**计算示例**:
- enhancement_level = +1 → 1/3 ≈ 0 → floor → 0 + 1 → **Tier 1**
- enhancement_level = +3 → 3/3 = 1 → floor → 1 + 1 → **Tier 2**
- enhancement_level = +6 → 6/3 = 2 → floor → 2 + 1 → **Tier 3**
- enhancement_level = +9 → 9/3 = 3 → floor → 3 + 1 → **Tier 4**
- enhancement_level = +10 → 10/3 ≈ 3.3 → floor → 3 + 1 → **Tier 4**

**逻辑**: 每3级强化提升1级粒子强度。+10强化（最高级）触发Tier 5（对应80-120粒子光爆瀑布效果）。

---

### Formula 3: 粒子数量计算 (Particle Count Calculation)

**目的**: 根据Tier等级，计算Emitter应发射的粒子数量。

**公式**:
```
particle_count = tier_base_count[tier] + randi_range(0, tier_variance[tier])
```

**常量表**:
| Tier | Base Count | Variance | Range |
|------|------------|----------|-------|
| 1 | 8 | 4 | 8-12 |
| 2 | 20 | 10 | 20-30 |
| 3 | 40 | 10 | 40-50 |
| 4 | 60 | 20 | 60-80 |
| 5 | 80 | 40 | 80-120 |
| 6 | 120 | 80 | 120-200 |

**变量定义**:
| Variable | Type | Description |
|----------|------|-------------|
| `particle_count` | int | 最终发射粒子数量 |
| `tier` | int | 输入的强度等级 (1-6) |
| `tier_base_count[tier]` | int | 该Tier的基础粒子数 |
| `tier_variance[tier]` | int | 该Tier的随机变化范围 |

---

### Formula 4: 粒子持续时间计算 (Duration Calculation)

**目的**: 根据Tier等级，计算粒子从发射到完全消失的总时间。

**公式**:
```
total_duration = tier_duration[tier]
fade_time = total_duration * 0.2
emit_duration = total_duration - fade_time
```

**常量表**:
| Tier | Total Duration | Fade Time | Emit Duration |
|------|---------------|-----------|---------------|
| 1 | 0.5s | 0.1s | 0.4s |
| 2 | 0.5s | 0.1s | 0.4s |
| 3 | 0.8s | 0.16s | 0.64s |
| 4 | 0.8s | 0.16s | 0.64s |
| 5 | 1.2s | 0.24s | 0.96s |
| 6 | 1.2s | 0.24s | 0.96s |

**变量定义**:
| Variable | Type | Unit | Description |
|----------|------|------|-------------|
| `total_duration` | float | seconds | 粒子从发射到完全消失的总时长 |
| `fade_time` | float | seconds | 淡出阶段时长（最后20%时间） |
| `emit_duration` | float | seconds | 粒子发射阶段时长 |
| `tier` | int | - | 输入的强度等级 |

---

### Formula 5: 性能预算阈值检查 (Performance Budget Check)

**目的**: 检查当前活跃粒子数是否超过性能预算，触发取消逻辑。

**公式**:
```
performance_status = "ok" if active_particles <= 200 else "warning" if active_particles <= 250 else "critical"
```

**阈值表**:
| Status | Active Particles | Action |
|--------|-----------------|--------|
| **ok** | 0 - 200 | 正常播放，无限制 |
| **warning** | 201 - 250 | 新粒子请求被拒绝（返回false） |
| **critical** | > 250 | 立即触发Rule 6取消逻辑，停止低优先级Emitter |

**变量定义**:
| Variable | Type | Description |
|----------|------|-------------|
| `active_particles` | int | 当前所有Emitter活跃粒子总数 |
| `performance_status` | enum | 输出的性能状态标识 |

---

### Formula 6: 分层叠加延迟计算 (Layering Delay Calculation)

**目的**: 当多个粒子同时触发时，计算各层的播放延迟，创造节奏感。

**公式**:
```
layer_delay[layer] = layer_base_delay[layer]
```

**常量表**:
| Layer (Priority) | Delay | Example |
|------------------|-------|---------|
| 1 (Rare Drop) | 0.0s | 立即播放 |
| 2 (Enhancement) | 0.1s | 短延迟 |
| 3 (Victory) | 0.2s | 中延迟 |
| 4 (Gold/UI) | 0.3s | 长延迟 |

**逻辑**: 高优先级粒子先播，低优先级延迟后播，避免视觉混乱。延迟时间固定，不随Tier变化。

## Edge Cases

### Edge Case 1: 同一位置多事件并发触发

**场景**: Boss击败时，在同一位置触发Victory Sparkle + Gold Burst + Rare Drop Glow（如Boss掉落稀有装备）。

**处理方式**:
- Victory Sparkle（优先级Layer 1）立即播放，位置居中
- Rare Drop Glow（优先级Layer 1）立即播放，位置偏移+50px向上，形成"胜利光环+掉落光效"双中心
- Gold Burst（优先级Layer 4）延迟0.3秒播放，位置偏移-30px向下，避免遮挡高优先级粒子
- 总层数检查：3层 ≤ 最大并发限制（Rule 4），全部允许播放
- 若掉落稀有+强化成功同时发生（Boss击败后玩家立即强化掉落装备），超过3层 → Gold Burst被跳过

**玩家视角**: 先看到胜利光效闪烁，然后稀有掉落紫光上升，最后金币爆发喷出——形成"胜利→惊喜→奖励"的三段式视觉叙事。

---

### Edge Case 2: 场景切换时粒子正在播放

**场景**: 玩家进入新地牢房间，但上一个房间的Gold Burst粒子仍在播放。

**处理方式**:
- 地牢推进系统调用`ParticleSystem.cancel_all()`
- 所有活跃Emitter立即切换到Cancelled状态
- 正在播放的粒子使用0.1秒快速淡出（而非立即消失）
- 粒子池清空，所有Emitter回到Idle状态
- 新房间粒子系统重新初始化，可接收新的emit请求

**玩家视角**: 房间切换瞬间，上一个房间的粒子"温柔地消散"，而非突然消失。避免视觉断裂感。

---

### Edge Case 3: 粒子请求超出性能预算

**场景**: 当前活跃粒子数=180，新请求要求播放Tier 4 Gold Burst（60-80粒子），总粒子数将超过200预算。

**处理方式**:
- `emit_particle()`检查当前活跃粒子数：`active_particles = 180`
- 预估新增粒子：`estimated = 180 + 70 (Tier 4平均值) = 250`
- 250 > 200 → 进入warning状态
- **拒绝新请求**: `emit_particle()`返回`false`（调用方需处理拒绝情况）
- 若active_particles > 250 → 进入critical状态 → 立即触发取消逻辑，停止低优先级Emitter（Gold/UI层）
- 粒子数降至安全范围后，重新接受新请求

**调用方处理**: 视觉反馈系统收到`false`返回值 → 可选择降低Tier重试（如Tier 4降为Tier 2，减少粒子数）或跳过该粒子。

---

### Edge Case 4: 强化等级为+0（首次装备）

**场景**: 玩家首次获得装备，强化等级=+0，调用Enhancement Flash粒子。

**处理方式**:
- `enhancement_level = 0` → Formula 2计算：0/3 = 0 → floor → 0 + 1 = **Tier 1**
- 播放Tier 1 Enhancement Flash（8-12粒子，小型闪光）
- **首次装备不强化**: +0装备不触发强化粒子，只有强化成功（+0→+1）才触发
- 边界情况：若系统收到`enhancement_level=0`的强化请求 → 视为无效请求，返回`false`

**逻辑**: 强化粒子只在强化成功时触发，装备首次获得不触发强化粒子（装备掉落系统会触发Rare Drop Glow）。

---

### Edge Case 5: 金币奖励金额为0

**场景**: 特殊敌人（如训练假人）击败后金币奖励=0，不应触发Gold Burst粒子。

**处理方式**:
- `gold_reward = 0` → Formula 1计算：log10(0) = undefined
- **前置检查**: 战斗系统调用`emit_particle("gold_burst", auto_tier, position)`前，先检查`gold_reward > 0`
- 若`gold_reward = 0` → **跳过粒子调用**，粒子系统不参与
- 粒子系统不处理"金额为0"的边界情况，由调用方负责过滤无效请求

**调用方处理**: 战斗系统在敌人击败事件中，先判断金币奖励金额，金额>0才调用粒子系统。

---

### Edge Case 6: 粒子池耗尽（极端情况）

**场景**: 性能预算正常，但Emitter池中所有Emitter都在使用（MVP预加载5个Emitter，极端情况下可能全部激活）。

**处理方式**:
- MVP设计：预加载5个Emitter（每种预设1个）
- 最大并发Emitter限制=4（Rule 8）
- 情况不可能发生：Emitter池数量(5) > 最大并发(4)
- **若未来扩展新增预设类型**，Emitter池数量需同步增加
- 扩展时边界处理：若Emitter池耗尽 → 新请求等待最早完成的Emitter回收（队列等待）

**MVP阶段**: 此边界情况不会发生，但设计需为扩展预留处理逻辑。

---

### Edge Case 7: 玩家跳过战斗时的粒子节奏

**场景**: 玩家选择跳过战斗，战斗系统快速结算，粒子系统需在压缩时间内完成反馈。

**处理方式**:
- 跳过战斗时，战斗系统调用`emit_particle("gold_burst", tier, position)`
- 粒子系统正常播放，但遵守最小可见时长=0.3秒（Rule 5）
- 0.3秒后，战斗系统可调用`cancel_all()`停止粒子，进入下一结算
- **节奏压缩**: 跳过模式下，粒子只播最小时长，不播完整duration（Tier 1的0.5秒被压缩到0.3秒）
- 玩家选择观看战斗 → 粒子播完整duration，不提前取消

**玩家视角**: 跳过战斗时，粒子"闪一下就消失"——快速反馈但不拖慢节奏。观看战斗时，粒子完整播放——享受视觉冲击。

## Dependencies

### Upstream Dependencies (Systems Particle System Depends On)

粒子系统属于Foundation层，无上游依赖。它可独立于其他游戏逻辑系统进行设计和实现。

| Dependency | Status | GDD Location | Notes |
|------------|--------|--------------|-------|
| **None** | N/A | N/A | 粒子系统是基础设施层，独立于游戏逻辑 |

**说明**: 粒子系统不依赖存档系统（不保存粒子状态）、不依赖战斗系统（被动接收调用）、不依赖UI系统（粒子是独立视觉层）。粒子预设、Tier参数、性能预算都在粒子系统内部定义。

---

### Downstream Dependencies (Systems That Depend On Particle System)

以下系统依赖粒子系统提供视觉反馈接口：

| Dependent System | Priority | GDD Status | How It Uses Particle System |
|-----------------|----------|------------|----------------------------|
| **视觉反馈系统** | MVP | Not Started | 协调粒子+震动+数值显示的同步触发，是粒子系统的主要调用协调者 |
| **战斗系统** | MVP | Not Started | 敌人击败时调用`emit_particle("gold_burst", tier, position)` |
| **装备强化系统** | MVP | Not Started | 强化成功时调用`emit_particle("enhancement_flash", tier, position)` |
| **装备掉落系统** | MVP | Not Started | 稀有掉落时调用`emit_particle("rare_drop_glow", 3, position)` |
| **地牢推进系统** | MVP | Not Started | 房间完成时调用`emit_particle("victory_sparkle", tier, center_pos)`；房间切换时调用`cancel_all()` |
| **UI系统** | MVP | Not Started | 按钮点击时调用`emit_particle("ui_popup", 1, click_pos)` |

---

### Interface Contract (承诺给下游系统的接口)

粒子系统向下游系统提供以下稳定接口：

```gdscript
# ParticleSystem 公共接口
class_name ParticleSystem

## 发射粒子
## @param event_type: 事件类型字符串 ("gold_burst" | "enhancement_flash" | "rare_drop_glow" | "victory_sparkle" | "ui_popup")
## @param tier: 强度等级 (1-6)，0表示自动计算（仅gold_burst支持）
## @param position: 粒子发射位置（世界坐标或屏幕坐标，由UI系统决定）
## @return: true=成功发射，false=超出性能预算或无效请求
func emit_particle(event_type: String, tier: int, position: Vector2) -> bool

## 取消所有活跃粒子（场景切换时调用）
func cancel_all() -> void

## 获取当前活跃粒子数（性能监控使用）
func get_active_count() -> int
```

**接口稳定性承诺**:
- `emit_particle`接口签名在MVP阶段冻结，不增加参数
- 若需扩展（如自定义颜色、形状），使用可选字典参数或新接口，不修改现有接口
- 下游系统可依赖接口返回值（`bool`）处理性能拒绝情况

---

### Data Flow Diagram

```
上游系统 → 粒子系统 → 下游系统

战斗系统 ─────┐
装备强化系统 ─┤
装备掉落系统 ─┼──→ emit_particle(event, tier, pos) ──→ ParticleSystem ──→ GPUParticles2D渲染
地牢推进系统 ─┤                        cancel_all()         ↑
UI系统 ───────┘                                              │
                                                              │
视觉反馈系统 ←── get_active_count() ←───────────────────────┘
                (协调粒子+震动+数值显示的节奏)
```

**数据流说明**:
- **输入流**: 多个上游系统调用`emit_particle`，传入事件类型、强度等级、位置
- **输出流**: 粒子系统渲染粒子到屏幕，不向下游返回数据（只返回成功/失败状态）
- **协调流**: 视觉反馈系统查询`get_active_count()`监控性能状态，协调调用节奏

## Tuning Knobs

### Knob Category 1: 粒子数量

| Knob ID | Variable Name | Default Value | Safe Range | Gameplay Effect | Tuning Notes |
|---------|---------------|---------------|------------|-----------------|--------------|
| `TK-PARTICLE-BASE-1` | `tier_base_count[1]` | 8 | 4-15 | Tier 1粒子基础数量 | 降低会削弱小额奖励视觉冲击，提高会增加低端设备负担 |
| `TK-PARTICLE-BASE-2` | `tier_base_count[2]` | 20 | 12-30 | Tier 2粒子基础数量 | 中额奖励的视觉强度 |
| `TK-PARTICLE-BASE-3` | `tier_base_count[3]` | 40 | 25-60 | Tier 3粒子基础数量 | 稀有掉落的视觉强度，过高会遮挡其他UI元素 |
| `TK-PARTICLE-BASE-4` | `tier_base_count[4]` | 60 | 40-100 | Tier 4粒子基础数量 | Boss奖励强度 |
| `TK-PARTICLE-BASE-5` | `tier_base_count[5]` | 80 | 50-150 | Tier 5粒子基础数量 | 全房间胜利强度，过高会触发性能预算限制 |
| `TK-PARTICLE-BASE-6` | `tier_base_count[6]` | 120 | 80-200 | Tier 6粒子基础数量 | 传说级事件，MVP阶段不使用 |

**调优建议**: 初期使用默认值，测试时观察：
- 低端设备是否在Tier 5时出现卡顿 → 降低base_count
- Tier 1-2视觉冲击是否足够 → 增加base_count
- 粒子是否遮挡重要UI（装备详情、数值显示） → 降低base_count或调整位置偏移

---

### Knob Category 2: 粒子持续时间

| Knob ID | Variable Name | Default Value | Safe Range | Gameplay Effect | Tuning Notes |
|---------|---------------|---------------|------------|-----------------|--------------|
| `TK-DURATION-T1T2` | `tier_duration[1,2]` | 0.5s | 0.3-0.8s | Tier 1-2总时长 | 过短会导致粒子"一闪而过"，过长会拖慢跳过战斗节奏 |
| `TK-DURATION-T3T4` | `tier_duration[3,4]` | 0.8s | 0.5-1.2s | Tier 3-4总时长 | 稀有/Boss奖励的视觉持续时间 |
| `TK-DURATION-T5T6` | `tier_duration[5,6]` | 1.2s | 0.8-2.0s | Tier 5-6总时长 | 全房间胜利/传说级时长 |
| `TK-FADE-RATIO` | `fade_time_ratio` | 0.2 | 0.1-0.3 | 淡出时间占比 | 增大会让粒子消散更慢，减少会让粒子突然消失 |

**调优建议**: 持续时间影响节奏感：
- 跳过战斗测试：粒子是否在0.3秒最小时长内完成可见反馈
- 观看战斗测试：粒子是否完整播放，消散是否自然（调整fade_ratio）

---

### Knob Category 3: 性能预算

| Knob ID | Variable Name | Default Value | Safe Range | Gameplay Effect | Tuning Notes |
|---------|---------------|---------------|------------|-----------------|--------------|
| `TK-MAX-PARTICLES` | `max_active_particles` | 200 | 100-300 | 最大活跃粒子数 | 低端设备降低至100，高端设备可提升至300 |
| `TK-MAX-EMITTERS` | `max_concurrent_emitters` | 4 | 2-6 | 最大并发Emitter数 | 降低会限制分层叠加效果，提高会增加Draw Calls |
| `TK-PERF-WARNING` | `warning_threshold` | 250 | 200-300 | 性能预警阈值 | 超过此值开始拒绝新请求 |
| `TK-PERF-CRITICAL` | `critical_threshold` | 250 | warning+50 | 性能紧急阈值 | 超过此值触发强制取消 |

**调优建议**: 性能预算需在目标设备上实测：
- 目标设备（iOS/Android中端）测试：Tier 5+多并发是否触发warning/critical
- 若频繁触发warning → 降低max_particles或调整tier_base_count
- 若从未触发warning → 可适当提高预算，增强视觉效果

---

### Knob Category 4: 分层叠加延迟

| Knob ID | Variable Name | Default Value | Safe Range | Gameplay Effect | Tuning Notes |
|---------|---------------|---------------|------------|-----------------|--------------|
| `TK-LAYER-DELAY-1` | `layer_delay[1]` | 0.0s | 0.0s | Layer 1延迟（立即） | 高优先级立即播放，不可调整 |
| `TK-LAYER-DELAY-2` | `layer_delay[2]` | 0.1s | 0.05-0.15s | Layer 2延迟 | 端延迟创造"先高后低"节奏 |
| `TK-LAYER-DELAY-3` | `layer_delay[3]` | 0.2s | 0.1-0.3s | Layer 3延迟 | 中延迟，Victory→Gold的间隔 |
| `TK-LAYER-DELAY-4` | `layer_delay[4]` | 0.3s | 0.2-0.5s | Layer 4延迟 | 长延迟，低优先级最后播放 |

**调优建议**: 延迟时间影响视觉叙事节奏：
- Boss击败测试：Victory→Gold的延迟是否形成"胜利→奖励"的叙事感
- 延迟过短：所有粒子同时爆发，视觉混乱
- 延迟过长：玩家感知断裂，"胜利后等太久才看到金币"

---

### Knob Category 5: 最小可见时长

| Knob ID | Variable Name | Default Value | Safe Range | Gameplay Effect | Tuning Notes |
|---------|---------------|---------------|------------|-----------------|--------------|
| `TK-MIN-VISIBLE` | `min_visible_duration` | 0.3s | 0.2-0.5s | 跳过战斗时的最小时长 | 过短会导致玩家看不到粒子，过长会拖慢跳过节奏 |

**调优建议**: 此参数直接影响"掌控节奏"支柱：
- 跳过战斗必须播放最小时长，确保玩家获得视觉反馈
- 若最小时长=0 → 跳过战斗无视觉反馈 → 玩家感知"什么都没发生"
- 最小时长过长 → 跳过战斗变慢 → 与"掌控节奏"冲突

---

### Tuning Knob Configuration File

所有调优参数存储在 `assets/data/config/particle_config.json`，格式如下：

```json
{
  "particle_counts": {
    "tier_base": [8, 20, 40, 60, 80, 120],
    "tier_variance": [4, 10, 10, 20, 40, 80]
  },
  "durations": {
    "tier_duration": [0.5, 0.5, 0.8, 0.8, 1.2, 1.2],
    "fade_ratio": 0.2,
    "min_visible": 0.3
  },
  "performance": {
    "max_particles": 200,
    "max_emitters": 4,
    "warning_threshold": 250,
    "critical_threshold": 250
  },
  "layering": {
    "layer_delay": [0.0, 0.1, 0.2, 0.3]
  }
}
```

**热更新支持**: 粒子系统启动时读取JSON文件，运行时可直接修改文件调整参数（无需重新编译）。设计师可在测试时实时调整效果。

## Visual/Audio Requirements

### Visual Requirements

**粒子预设视觉规格**:

| Preset Name | Particle Shape | Size Range | Color | Motion Curve | Gravity | Fade Type |
|-------------|---------------|------------|-------|--------------|---------|-----------|
| **Gold Burst** | Circle (filled) | 8-16px | #E5A50A (Golden Amber) | Burst outward → gravity fall | 150 (downward) | Alpha fade + shrink |
| **Enhancement Flash** | Circle (glow) | 12-24px | #FFFFFF (white) → #E5A50A (fade to gold) | Center gather → outward burst | 0 (no gravity) | Alpha fade + glow decay |
| **Rare Drop Glow** | Ring (hollow) | 16-32px | #9B7BB8 (Soft Lavender) | Spiral upward | -50 (upward drift) | Alpha fade + ring shrink |
| **Victory Sparkle** | Star (4-point) | 10-20px | Multi: #E5A50A, #F27D16, #FFFFFF | Random scatter → float | 20 (slow drift) | Alpha fade + rotation |
| **UI Popup Burst** | Circle (filled) | 4-8px | #FFFFFF (white) | Quick outward burst | 0 (no gravity) | Alpha fade (fast) |

---

**粒子动画曲线**:

所有粒子使用Godot ParticleProcessMaterial定义运动曲线：

- **Gold Burst**:
  - Initial Velocity: 200-400 (radial outward)
  - Velocity Curve: ease-out (slows as particles fall)
  - Scale Curve: 1.0 → 0.5 (particles shrink over time)
  - Color Ramp: #E5A50A (100% opacity) → #E5A50A (0% opacity)

- **Enhancement Flash**:
  - Initial Velocity: -50 (inward gather for first 0.1s)
  - Velocity Curve: 0 → 300 (burst outward after gather)
  - Scale Curve: 0.5 → 1.0 → 0.3 (grow → shrink)
  - Color Ramp: #FFFFFF → #E5A50A (white to gold fade)

- **Rare Drop Glow**:
  - Initial Velocity: 50 (upward)
  - Angular Velocity: 30-60 (spiral rotation)
  - Scale Curve: 1.0 → 0.2 (ring shrinks)
  - Color Ramp: #9B7BB8 (80% opacity) → #9B7BB8 (0% opacity)

- **Victory Sparkle**:
  - Initial Velocity: 100-200 (random scatter)
  - Gravity: 20 (slow upward drift)
  - Scale Curve: 1.0 → 0.5 → 0 (shrink to vanish)
  - Color Ramp: Multi-color gradient (gold → orange → white)

- **UI Popup Burst**:
  - Initial Velocity: 80-120 (quick outward)
  - Lifetime: 0.2-0.3s (short)
  - Scale Curve: 1.0 → 0 (fast shrink)
  - Color Ramp: #FFFFFF (100%) → #FFFFFF (0%)

---

**粒子纹理规格**:

| Texture Name | Atlas Position | Dimensions | Format | Notes |
|--------------|---------------|------------|--------|-------|
| `particle_circle.png` | 0,0 | 32x32 | PNG (RGBA) | Solid circle, used for Gold Burst, UI Popup |
| `particle_ring.png` | 32,0 | 32x32 | PNG (RGBA) | Hollow ring, used for Rare Drop Glow |
| `particle_star.png` | 64,0 | 32x32 | PNG (RGBA) | 4-point star, used for Victory Sparkle |
| `particle_glow.png` | 96,0 | 32x32 | PNG (RGBA) | Glow circle with gradient edge, used for Enhancement Flash |

**Texture Atlas Total**: 128x128px (4 textures packed)

---

### Audio Requirements

**粒子系统本身不播放音效**。音效由音效系统负责，粒子系统只触发视觉反馈。

| Particle Event | Audio Event | Owned By | Notes |
|----------------|-------------|----------|-------|
| Gold Burst播放 | `coin_collect.wav` | 音效系统 | 战斗系统同时触发粒子+音效，音效系统独立播放 |
| Enhancement Flash播放 | `enhance_success.wav` | 音效系统 | 强化系统同时触发粒子+音效 |
| Rare Drop Glow播放 | `rare_drop.wav` | 音效系统 | 装备掉落系统触发粒子+音效 |
| Victory Sparkle播放 | `victory.wav` | 音效系统 | 地牢推进系统触发粒子+音效 |
| UI Popup播放 | `button_click.wav` | 音效系统 | UI系统触发粒子+音效 |

**同步协调**: 视觉反馈系统负责协调粒子+音效+震动的同步触发顺序（见视觉反馈系统GDD）。

---

### Art Bible Alignment

粒子颜色和风格必须与 `design/art/art-bible.md` 保持一致：

- **Golden Amber (#E5A50A)**: 主要奖励色，用于Gold Burst、Enhancement Flash淡出
- **Celebration Orange (#F27D16)**: Victory Sparkle的次要色
- **Soft Lavender (#9B7BB8)**: 稀有掉落专属色，用于Rare Drop Glow
- **White (#FFFFFF)**: 强化闪光和UI粒子的中性色

**粒子风格**: 所有粒子使用简洁几何形状（圆形、环形、星形），符合Art Bible的"可读性优先"原则。粒子不使用复杂纹理或照片级渲染，保持"扁平+轻微光效"的风格。

## UI Requirements

粒子系统本身无直接UI界面。粒子是纯视觉渲染层，不包含菜单、面板、HUD元素。

### UI System Interaction

粒子系统与UI系统的交互是单向调用：

| Interaction | Direction | Description |
|-------------|-----------|-------------|
| UI Popup Burst触发 | UI系统 → 粒子系统 | 按钮点击、面板打开时，UI系统调用`emit_particle("ui_popup", 1, click_pos)` |
| 粒子位置坐标 | UI系统 → 粒子系统 | UI系统传入屏幕坐标（如按钮中心位置），粒子系统在CanvasLayer渲染 |

### Particle Rendering Layer

粒子系统使用独立的CanvasLayer进行渲染：

- **CanvasLayer层级**: Layer 5 (高于游戏世界Layer 0，低于HUD Layer 10)
- **目的**: 粒子渲染在游戏场景之上，但被HUD UI元素（如数值显示、装备详情面板）覆盖
- **避免遮挡**: 高优先级粒子（Rare Drop Glow, Victory Sparkle）渲染在中心位置，但HUD面板使用更高Layer确保可读性

### Position Coordinate System

粒子位置坐标由调用方传入，粒子系统不做坐标转换：

| Caller | Coordinate System | Example |
|--------|------------------|---------|
| 战斗系统 | 世界坐标（敌人位置） | `emit_particle("gold_burst", 3, enemy.position)` |
| UI系统 | 屏幕坐标（按钮位置） | `emit_particle("ui_popup", 1, button.global_position)` |
| 强化系统 | 屏幕坐标（强化面板中心） | `emit_particle("enhancement_flash", 4, panel_center)` |
| 地牢推进系统 | 屏幕坐标（房间中心） | `emit_particle("victory_sparkle", 5, screen_center)` |

**坐标转换**: 若调用方传入世界坐标，粒子系统使用`CanvasLayer`的`get_canvas_transform()`转换为屏幕坐标进行渲染。

### No Config UI

MVP阶段粒子系统不提供玩家配置界面。所有调优参数存储在`particle_config.json`，由设计师在开发时调整。

**未来扩展**: 若需玩家可配置粒子强度（如"粒子特效：高/中/低"），增加设置界面选项，调用`set_quality_level(level)`接口调整tier_base_count参数。MVP阶段不实现。

---

### Summary

粒子系统无UI界面，只提供渲染服务。UI系统是粒子系统的调用方，负责触发UI Popup粒子并传入屏幕坐标。粒子渲染使用独立CanvasLayer (Layer 5)，确保不遮挡HUD UI元素 (Layer 10)。

## Acceptance Criteria

### Acceptance Criteria: 功能正确性

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-PARTICLE-001` | 5种预设粒子可正确触发 | 手动测试：触发每种事件类型，观察粒子形状和颜色 | Gold Burst=金色圆形，Enhancement Flash=白色闪光，Rare Drop Glow=紫色光晕，Victory Sparkle=多色星形，UI Popup=小型白色 |
| `AC-PARTICLE-002` | Tier参数正确控制粒子数量 | 单元测试：调用emit_particle传入Tier 1-6，验证particle_count在规定范围内 | Tier 1粒子数在8-12，Tier 2在20-30，...，Tier 5在80-120 |
| `AC-PARTICLE-003` | 金币奖励自动计算Tier | 单元测试：传入gold_reward=50/500/5000，验证gold_tier=1/2/3 | gold_reward=50→Tier 1，gold_reward=500→Tier 2，gold_reward=5000→Tier 3 |
| `AC-PARTICLE-004` | 强化等级自动计算Tier | 单元测试：传入enhancement_level=+1/+3/+6/+10，验证enhancement_tier | +1→Tier 1，+3→Tier 2，+6→Tier 3，+10→Tier 4 |
| `AC-PARTICLE-005` | 分层叠加正确延迟 | 手动测试：Boss击败触发Victory+Gold，验证延迟间隔 | Victory立即播放，Gold延迟0.3秒播放 |
| `AC-PARTICLE-006` | 最大并发层数=3 | 单元测试：模拟4层同时触发，验证低优先级粒子被跳过 | Layer 4粒子请求返回false，或被跳过 |

---

### Acceptance Criteria: 性能预算

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-PARTICLE-007` | 活跃粒子数≤200 | 性能测试：触发Tier 5粒子，验证active_particles | active_particles≤200（正常状态） |
| `AC-PARTICLE-008` | 性能warning触发拒绝 | 单元测试：模拟active_particles=180，请求Tier 4粒子 | emit_particle返回false，粒子不发射 |
| `AC-PARTICLE-009` | 性能critical触发取消 | 单元测试：模拟active_particles=260，验证取消逻辑 | 低优先级Emitter被停止，粒子快速淡出 |
| `AC-PARTICLE-010` | 并发Emitter数≤4 | 性能测试：触发多个粒子，验证emitter_count | 并发Emitter数量≤4 |

---

### Acceptance Criteria: 取消与打断

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-PARTICLE-011` | cancel_all立即生效 | 手动测试：粒子播放中调用cancel_all() | 所有粒子在0.1秒内淡出消失 |
| `AC-PARTICLE-012` | 场景切换自动取消 | 集成测试：粒子播放中触发房间切换 | 上房间粒子消散，新房间粒子系统初始化完成 |
| `AC-PARTICLE-013` | 跳过战斗遵守最小时长 | 手动测试：跳过战斗时观察Gold Burst | 粒子播放至少0.3秒后才可取消 |
| `AC-PARTICLE-014` | 淡出曲线ease-out | 视觉测试：观察粒子消散过程 | 粒子alpha值逐渐下降，最后20%时间使用ease-out曲线 |

---

### Acceptance Criteria: 视觉表现

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-PARTICLE-015` | 粒子不遮挡重要UI | 视觉测试：Tier 5粒子播放时观察装备详情面板 | 装备详情面板文字清晰可读，粒子不覆盖关键信息 |
| `AC-PARTICLE-016` | 粒子颜色与Art Bible一致 | 视觉测试：对比粒子颜色与art-bible.md定义 | Gold Burst=#E5A50A，Victory Sparkle=#F27D16，Rare Drop Glow=#9B7BB8 |
| `AC-PARTICLE-017` | 粒子运动曲线自然 | 视觉测试：观察Gold Burst下落过程 | 粒子有重力感，下落加速，落地附近消散 |

---

### Acceptance Criteria: 支柱支持

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-PARTICLE-018` | 爽感反馈支柱验证 | Playtest：10名玩家测试，询问"击杀敌人时是否感到满足" | ≥80%玩家回答"金币粒子爆发让我感到满足" |
| `AC-PARTICLE-019` | 掌控节奏支柱验证 | Playtest：跳过战斗测试，询问"跳过时是否有反馈" | ≥80%玩家回答"跳过时粒子闪了一下，我知道获得了奖励" |
| `AC-PARTICLE-020` | 稳定成长支柱验证 | Playtest：强化测试，询问"+1和+10强化粒子是否不同" | ≥80%玩家回答"+10粒子更强，我知道这是大进步" |

---

### Acceptance Criteria: 技术实现

| AC ID | Criterion | Test Method | Pass Condition |
|-------|-----------|-------------|----------------|
| `AC-PARTICLE-021` | GPUParticles2D实现 | 代码审查：检查ParticleSystem使用GPUParticles2D而非CPUParticles2D | 代码使用GPUParticles2D节点 |
| `AC-PARTICLE-022` | 粒子池预加载 | 单元测试：启动ParticleSystem，验证Emitter池数量 | 预加载Emitter数量=5 |
| `AC-PARTICLE-023` | Texture Atlas使用 | 代码审查：检查粒子纹理是否使用Texture Atlas | 所有粒子纹理在128x128图集内 |
| `AC-PARTICLE-024` | 配置文件热更新 | 手动测试：修改particle_config.json，重启游戏验证参数生效 | 修改tier_base_count后，粒子数量变化 |

---

### Acceptance Criteria Summary

- **Total Criteria**: 24
- **Blocking Criteria**: AC-001 to AC-014 (功能正确性+性能预算+取消打断)
- **Advisory Criteria**: AC-015 to AC-020 (视觉表现+支柱验证)
- **Technical Criteria**: AC-021 to AC-024 (技术实现验证)

**MVP Completion Definition**: 粒子系统通过所有Blocking Criteria (AC-001至AC-014)，Advisory Criteria由设计师Playtest验证，Technical Criteria由代码审查验证。

## Open Questions

### Open Question 1: 粒子池动态扩容

**问题**: MVP阶段预加载5个Emitter（每种预设1个），但若未来新增预设类型（如"Combo Burst"、"Critical Hit Flash"），Emitter池如何扩容？

**当前设计**: 预加载数量=预设类型数量，最大并发=4，池容量(5) > 最大并发(4)，不会出现池耗尽。

**选项**:
- **Option A (静态扩容)**: 新增预设时，手动修改预加载数量（如6个预设→预加载6个Emitter）
- **Option B (动态扩容)**: Emitter池检测到新预设类型时，自动创建新Emitter实例
- **Option C (复用策略)**: 新预设复用现有Emitter（如Combo Burst复用Gold Burst的Emitter，只修改ProcessMaterial）

**决策时间**: 需新增预设类型时决定（MVP阶段不涉及）。

---

### Open Question 2: 粒子与数值显示的同步节奏

**问题**: 金币粒子爆发时，数值显示系统同时显示"+500金币"数字弹出。两者的播放节奏如何同步？

**当前设计**: 视觉反馈系统负责协调（见视觉反馈系统GDD），粒子系统不处理同步。

**不确定性**: 
- 数值弹出应该在粒子播放中还是播放后？
- Tier 5大额奖励时，数值弹出是否需要多次弹出（如"+1000"分两次显示"+500 +500"）？
- 数值弹出与粒子分层叠加的节奏如何配合？

**决策时间**: 数值显示系统GDD设计时，视觉反馈系统GDD设计时解决。

---

### Open Question 3: 性能预算动态调整

**问题**: 当前性能预算固定（max_particles=200），但不同设备性能差异大（低端设备可能需要降低预算）。

**当前设计**: 预算固定，通过调优knob手动调整（低端设备测试后修改particle_config.json）。

**选项**:
- **Option A (设备检测)**: 游戏启动时检测设备性能等级（低端/中端/高端），自动调整max_particles
- **Option B (动态降级)**: 运行时监测帧率，帧率<45fps时自动降低max_particles，恢复60fps后恢复预算
- **Option C (固定预算)**: MVP阶段使用固定预算，Post-MVP根据测试反馈调整

**决策时间**: 移动端性能测试后决定（MVP阶段使用Option C固定预算）。

---

### Open Question 4: 粒子与震动反馈的触发顺序

**问题**: 同一事件（如Boss击败）触发Victory Sparkle粒子+震动反馈。两者的触发顺序如何？

**当前设计**: 视觉反馈系统负责协调（见视觉反馈系统GDD），粒子系统和震动反馈系统不直接交互。

**不确定性**:
- 粒子先播还是震动先触发？（视觉优先 vs 触觉优先）
- 分层叠加时，震动是否同步分层？（Victory震动→Gold震动）
- 震动强度是否与粒子Tier对应？（Tier 5粒子=强震动）

**决策时间**: 震动反馈系统GDD设计时，视觉反馈系统GDD设计时解决。

---

### Open Question 5: 跳过战斗时的粒子+数值+震动完整节奏

**问题**: 跳过战斗时，粒子播放最小时长(0.3s)，数值弹出和震动如何配合？

**当前设计**: 粒子系统遵守min_visible_duration，数值和震动由视觉反馈系统协调。

**不确定性**:
- 跳过模式下，数值弹出是否也压缩时长？（快速弹出→消失）
- 震动是否在跳过模式下省略？（跳过=快速结算，无需触觉反馈）
- 三者（粒子+数值+震动）在跳过模式下的完整节奏定义

**决策时间**: 视觉反馈系统GDD设计时解决，可能需要战斗系统GDD定义"跳过模式"的结算流程。

---

### Resolution Timeline

| Open Question | Blocking System | Resolution Timing |
|---------------|-----------------|-------------------|
| OQ-1 粒子池扩容 | 无（未来扩展） | Post-MVP新增预设类型时 |
| OQ-2 粒子数值同步 | 数值显示系统、视觉反馈系统 | 数值显示系统GDD设计时 |
| OQ-3 性能预算动态调整 | 无（设备适配） | 移动端性能测试后 |
| OQ-4 粒子震动顺序 | 震动反馈系统、视觉反馈系统 | 震动反馈系统GDD设计时 |
| OQ-5 跳过模式节奏 | 视觉反馈系统、战斗系统 | 视觉反馈系统GDD设计时 |