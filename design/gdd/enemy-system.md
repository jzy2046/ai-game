# 敌人系统

> **Status**: Designed
> **Author**: [user + agents]
> **Last Updated**: 2026-05-01
> **Implements Pillar**: 爽感反馈、稳定成长

## Overview

敌人系统是游戏的敌人数据定义和生成管理层，负责定义敌人类型的静态属性（生命值、攻击力、防御力、掉落配置）并根据地牢层级配置生成敌人实例。它为战斗系统提供敌人目标，为掉落表系统提供掉落来源，从地牢结构系统获取每层的敌人类型和数量配置。

敌人定义是静态数据模板，存储在 `assets/data/enemies/`。每个敌人类型有唯一ID、属性数值、稀有度、掉落权重表。敌人实例在战斗开始时按地牢层级配置生成，战斗结束后销毁（不持久化）。

**玩家体验**：虽然敌人系统是数据层，但玩家每次战斗都与敌人交互。敌人是"挑战"的化身 — 它的生命值决定战斗时长，它的数值决定玩家能否推进。敌人击败是爽感时刻：击败动画触发、掉落弹出、数值飞溅。支柱"爽感反馈"的实现依赖敌人作为视觉反馈的载体。

**MVP范围**：5-10种敌人类型，覆盖10层地牢难度曲线（推荐战力100-550）。敌人无复杂AI — 自动战斗模式下敌人是被动目标，仅响应玩家攻击和播放击败动画。

## Player Fantasy

敌人是玩家"征服感"的具象化。每次击败敌人都是一次胜利宣告 — 无论敌人强弱，击败它意味着"我足够强"。这种感觉服务于支柱"稳定成长"：敌人数值是可预期的挑战门槛，只要玩家装备足够，击败敌人必定成功，没有随机失败。

**核心幻想**：
> **"每个敌人都是成长的见证者"** — 第一层的史莱姆轻松击败，玩家感到"我已经比新手强"；第五层的暗影骑士需要认真强化装备才能应对，击败时感到"我终于到达了这个高度"。敌人是玩家成长的刻度尺，标记每个战力里程碑。

**锚定时刻**：第一次击败比预期更强的敌人。玩家装备刚强化到+5，进入第五层，看到"暗影骑士"的数值比自己高。犹豫片刻后推进战斗 — 自动战斗中敌人HP逐步下降，最后击败瞬间粒子爆发、数值飞溅。玩家感到"我战胜了它"。这种征服感让玩家想要"再推一层试试"。

**敌人多样性的作用**：不同敌人类型创造地牢探索的新鲜感。史莱姆、哥布林、骷髅、暗影骑士、巨龙 — 每个名称唤起不同的预期强度。玩家推进新层级时看到新敌人类型，产生"这次会遇到什么"的期待。虽然战斗是自动的，但敌人名称和外观变化维持探索乐趣。

**参考时刻**：Idle Slayer — 每个区域有独特敌人类型，玩家推进新区域时感到"新的挑战"，即使战斗机制相同。敌人名称和外观是探索反馈的主要载体。

## Detailed Design

### Core Rules

**Rule 1: Enemy Definition Schema**

敌人定义是静态数据模板，存储在 `assets/data/enemies/`。每个敌人类型的数据结构：

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | 唯一标识符，格式: `enemy_[name]` |
| `display_name` | String | 显示名称 |
| `description` | String | 描述文本 |
| `rarity` | Rarity | 稀有度枚举 (COMMON, UNCOMMON, RARE, EPIC) |
| `base_health` | int | 基础生命值 |
| `base_attack` | int | 基础攻击力 |
| `base_defense` | int | 基础防御力 |
| `power_rating` | int | 战力评估值（用于匹配地牢层级推荐战力） |
| `drop_table_id` | String | 掉落表ID |
| `visual_theme` | String | 视觉主题（颜色/风格） |
| `icon_path` | String | 图标资源路径 |

**示例**:
```json
{
  "id": "enemy_slime",
  "display_name": "Slime",
  "rarity": "COMMON",
  "base_health": 50,
  "base_attack": 5,
  "base_defense": 2,
  "power_rating": 100,
  "drop_table_id": "drop_table_floor_1_3",
  "visual_theme": "green_blob",
  "icon_path": "res://assets/art/icons/enemies/slime.png"
}
```

---

**Rule 2: Floor-Enemy Mapping**

地牢层级定义了每层可能出现的敌人类型（`enemy_types` 字段）。敌人系统在战斗开始时根据层级配置选择敌人。

**MVP敌人分布策略**:

| Floor Range | Enemy Types | Power Rating Range | Theme |
|-------------|-------------|---------------------|-------|
| 1-3 | Slime, Goblin | 100-200 | 新手区 (弱敌) |
| 4-6 | Skeleton, Orc | 250-400 | 中层区 (中敌) |
| 7-9 | Shadow Knight, Wraith | 450-550 | 深层区 (强敌) |
| 10 | Dragon Spawn | 550+ | 最终层 (强敌) |

**敌人-层级匹配规则**:
- `enemy.power_rating` ≈ `floor.recommended_power ± 20%`（允许波动）
- 高层可以出现低层敌人（"遗留敌人"），但数值按层级系数放大
- 低层不能出现高层敌人（避免新手遇到强敌）

---

**Rule 3: Enemy Instance Generation**

敌人实例在战斗开始时生成。生成流程：

1. 获取当前层级配置: `floor_data = DungeonSystem.get_floor_data(current_floor)`
2. 提取敌人类型列表: `enemy_types = floor_data.enemy_types`
3. 确定敌人数量: `enemy_count = floor_data.enemy_count`（来自地牢结构系统公式）
4. 随机选择敌人: 从 `enemy_types` 中随机选取 `enemy_count` 个敌人类型
5. 实例化敌人: 为每个选中类型创建 EnemyInstance

**EnemyInstance 数据**:
| Field | Type | Description |
|-------|------|-------------|
| `definition_id` | String | 引用的敌人定义ID |
| `current_health` | int | 当前生命值（战斗中变化） |
| `max_health` | int | 最大生命值（来自定义） |
| `attack` | int | 攻击力（来自定义） |
| `defense` | int | 防御力（来自定义） |
| `state` | EnemyState | 当前状态 (SPAWNING, ALIVE, DEFEATED) |

---

**Rule 4: Enemy Rarity and Visual Theme**

敌人稀有度决定视觉主题颜色（对齐 Art Bible）：

| Enemy Rarity | Visual Theme | Color Palette |
|--------------|--------------|---------------|
| COMMON | 绿色/棕色系 | Earthen tones |
| UNCOMMON | 蓝色系 | Cooler tones |
| RARE | 紫色系 | Soft Lavender |
| EPIC | 红色/橙色系 | Celebration Orange |

**视觉反馈强度**:
- COMMON敌人击败: 小粒子爆发 (10-20 particles)
- RARE敌人击败: 中粒子爆发 (30-50 particles) + 屏幕轻微震动
- EPIC敌人击败: 大粒子爆发 (50-100 particles) + 屏幕震动 + 数字飞溅

---

**Rule 5: Drop Configuration**

敌人定义中的 `drop_table_id` 指向掉落表系统的配置。敌人击败后：

1. 触发 `enemy_defeated` 信号
2. 调用 `DropTableSystem.resolve_drop(drop_table_id)`
3. 返回掉落物品列表
4. 装备掉落系统处理掉落展示

**掉落表分层**:
- 低层敌人 (1-3): 基础掉落表（COMMON装备，基础材料）
- 中层敌人 (4-6): 进阶掉落表（UNCOMMON装备，稀有材料）
- 高层敌人 (7-10): 高级掉落表（RARE/EPIC装备，高级材料）

---

**Rule 6: Query Interface**

`EnemyDatabase` 提供以下查询方法：

| Method | Return | Purpose |
|--------|--------|---------|
| `get_enemy(id)` | Dictionary | 获取单个敌人定义 |
| `get_enemy_by_rarity(rarity)` | Array | 按稀有度获取敌人列表 |
| `get_enemy_by_power_range(min, max)` | Array | 按战力范围获取敌人 |
| `get_all_enemy_ids()` | Array[String] | 获取所有敌人ID |
| `has_enemy(id)` | bool | 检查敌人是否存在 |
| `get_enemies_for_floor(floor_id)` | Array | 获取适合该层的敌人列表 |

---

### States and Transitions

**Enemy Instance States**:

| State | Description | Entry Condition | Exit Condition |
|-------|-------------|-----------------|----------------|
| **Spawning** | 正在生成，播放入场动画 | 战斗开始时生成 | 入场动画完成 (0.3s) |
| **Alive** | 存活，可被攻击 | Spawning动画完成 | HP降至0 |
| **Defeated** | 已击败，播放击败动画 | HP降至0 | 动画完成，触发掉落 |

**State Transition Diagram**:

```
Spawning (0.3s) → Alive (等待被击败) → Defeated (0.5s animation + drops) → Destroy
```

**Transition Rules**:
- Spawning → Alive: 固定0.3秒入场动画
- Alive → Defeated: `current_health <= 0`
- Defeated → Destroy: 固定0.5秒击败动画后，实例销毁

---

### Interactions with Other Systems

| System | Data Flow | Interface Owner |
|--------|-----------|-----------------|
| **地牢结构系统** (Upstream) | Floor → enemy_types → Enemy selection | EnemySystem reads `get_floor_data(floor_id).enemy_types` |
| **物品数据库** (Upstream) | Enemy definition → drop_table → Equipment/Material IDs | EnemySystem stores `drop_table_id`; DropTableSystem resolves via ItemDatabase |
| **战斗系统** (Downstream) | EnemyInstance → current_health → Damage application | CombatSystem calls `enemy.take_damage(amount)` |
| **掉落表系统** (Downstream) | Enemy → drop_table_id → Drop resolution | DropTableSystem receives `enemy.definition.drop_table_id` |
| **装备掉落系统** (Downstream) | Drop results → Equipment/Material acquisition | EquipmentDropSystem receives drop list from enemy defeat |
| **视觉反馈系统** (Downstream) | Enemy defeat → particle/shake trigger | VisualFeedbackSystem receives `enemy_defeated` signal |
| **粒子系统** (Downstream) | Defeat event → particle burst config | ParticleSystem spawns particles based on enemy rarity |

**接口规范** (定义给下游系统使用):
- `spawn_enemies_for_floor(floor_id: int) → Array[EnemyInstance]` 为指定层级生成敌人实例
- `get_enemy_definition(id: String) → Dictionary` 返回敌人定义数据
- `get_enemy_instance(instance_id: int) → EnemyInstance` 返回战斗中的敌人实例
- `damage_enemy(instance_id: int, amount: int) → void` 对敌人造成伤害
- `is_enemy_defeated(instance_id: int) → bool` 检查敌人是否已击败

## Formulas

### Formula 1: Enemy Power Rating Calculation

战力评估值用于匹配地牢层级推荐战力。

`power_rating = floor((base_health * HEALTH_POWER_WEIGHT) + (base_attack * ATTACK_POWER_WEIGHT) + (base_defense * DEFENSE_POWER_WEIGHT))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_health | `hp` | int | 50–500 | 基础生命值 |
| base_attack | `atk` | int | 5–100 | 基础攻击力 |
| base_defense | `def` | int | 0–50 | 基础防御力 |
| HEALTH_POWER_WEIGHT | `hp_w` | float | 0.5 | 生命值权重（常量） |
| ATTACK_POWER_WEIGHT | `atk_w` | float | 3.0 | 攻击力权重（常量） |
| DEFENSE_POWER_WEIGHT | `def_w` | float | 2.0 | 防御力权重（常量） |
| power_rating | `pr` | int | 100–550 | 战力评估值 |

**Output Range:** 100 (新手敌人) to 550 (最终层敌人)

**Example:** Slime (hp=50, atk=5, def=2):
```
pr = floor(50 * 0.5 + 5 * 3.0 + 2 * 2.0)
   = floor(25 + 15 + 4)
   = floor(44)
   = 44 → 调整为 100 (最低门槛)
```

---

### Formula 2: Enemy Scaling for High Floors

低层敌人出现在高层时，数值按层级系数放大。

`scaled_health = base_health * (1 + (floor_id - base_floor) * SCALING_FACTOR)`
`scaled_attack = base_attack * (1 + (floor_id - base_floor) * SCALING_FACTOR)`
`scaled_defense = base_defense * (1 + (floor_id - base_floor) * SCALING_FACTOR)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| floor_id | `f` | int | 1–10 | 当前层级 |
| base_floor | `bf` | int | 1–10 | 敌人原始层级 |
| SCALING_FACTOR | `sf` | float | 0.15 | 每层放大系数（常量） |
| scaled_health | `shp` | int | 50–1000 | 放大后生命值 |
| scaled_attack | `satk` | int | 5–200 | 放大后攻击力 |
| scaled_defense | `sdef` | int | 0–100 | 放大后防御力 |

**Example:** Goblin (base_floor=2, hp=80, atk=12, def=5) 在第6层:
```
shp = 80 * (1 + (6-2) * 0.15) = 80 * 1.6 = 128
satk = 12 * 1.6 = 19
sdef = 5 * 1.6 = 8
```

---

### Formula 3: Enemy Health for Combat Duration

设计敌人生命值确保战斗时长符合预期（per_enemy_time = 5.0秒 from dungeon-structure-system）。

`expected_health = player_attack * expected_combat_time / HITS_PER_SECOND`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| player_attack | `pa` | int | 10–1000 | 玩家攻击力 |
| expected_combat_time | `ect` | float | 5.0 | 目标战斗时长（秒） |
| HITS_PER_SECOND | `hps` | float | 2.0 | 每秒攻击次数（常量） |
| expected_health | `ehp` | int | 100–5000 | 设计生命值目标 |

**Example:** 玩家攻击力100，目标战斗5秒:
```
ehp = 100 * 5.0 / 2.0 = 250
```

---

### MVP Enemy List (8 enemies)

| ID | Name | Rarity | Floor Range | HP | ATK | DEF | Power Rating | Drop Table |
|----|------|--------|-------------|----|----|-----|---------------|------------|
| `enemy_slime` | Slime | COMMON | 1-3 | 50 | 5 | 2 | 100 | `drop_floor_1_3` |
| `enemy_goblin` | Goblin | COMMON | 1-3 | 80 | 12 | 5 | 120 | `drop_floor_1_3` |
| `enemy_skeleton` | Skeleton | UNCOMMON | 4-6 | 150 | 25 | 10 | 250 | `drop_floor_4_6` |
| `enemy_orc` | Orc | UNCOMMON | 4-6 | 200 | 35 | 15 | 350 | `drop_floor_4_6` |
| `enemy_shadow_knight` | Shadow Knight | RARE | 7-9 | 300 | 50 | 25 | 450 | `drop_floor_7_9` |
| `enemy_wraith` | Wraith | RARE | 7-9 | 350 | 60 | 20 | 500 | `drop_floor_7_9` |
| `enemy_dragon_spawn` | Dragon Spawn | EPIC | 10 | 500 | 80 | 40 | 550 | `drop_floor_10` |
| `enemy_giant_spider` | Giant Spider | UNCOMMON | 3-5 | 120 | 20 | 8 | 200 | `drop_floor_3_5` |

## Edge Cases

### Edge Case 1: Floor Configuration Has No Enemy Types

**Scenario**: 地牢层级配置 `enemy_types = []`（空列表）。

**Expected Behavior**:
- 使用 fallback 敌人列表: `[enemy_slime]`（默认新手敌人）
- 日志警告: "Floor [N] has empty enemy_types, using fallback"
- 战斗仍能进行，不会崩溃

**Test**: 配置层级 `enemy_types = []` → 验证战斗生成 Slime。

---

### Edge Case 2: Enemy Definition Missing Required Fields

**Scenario**: 敌人JSON定义缺少 `base_health` 或 `base_attack`。

**Expected Behavior**:
- 数据加载时验证失败
- 日志错误: "Enemy [id] missing required field [field]"
- 跳过该敌人定义，继续加载其他敌人
- 如果所有敌人都失败，使用 fallback 敌人列表

**Test**: 创建缺少 `base_health` 的敌人JSON → 验证加载跳过，日志记录。

---

### Edge Case 3: Enemy Instance ID Collision

**Scenario**: 同一场战斗中两个敌人实例获得相同ID。

**Expected Behavior**:
- 使用唯一ID生成器: `instance_id = floor_id * 1000 + random_suffix`
- 实例ID范围: 1001-10000（每层最多1000个实例）
- 碰撞概率极低（0.1%），但检测碰撞后重新生成

**Test**: 模拟ID碰撞 → 验证系统重新生成唯一ID。

---

### Edge Case 4: Enemy Defeated During Spawn Animation

**Scenario**: 玩家跳过战斗时，敌人可能在入场动画期间被标记击败。

**Expected Behavior**:
- Spawning状态可被中断 → 直接跳到 Defeated 状态
- 入场动画停止，播放击败动画
- 仍触发掉落结算

**Test**: 跳过战斗 → 验证敌人立即进入 Defeated 状态。

---

### Edge Case 5: Drop Table ID Missing

**Scenario**: 敌人定义 `drop_table_id` 指向不存在的掉落表。

**Expected Behavior**:
- 使用 fallback 掉落表: `drop_table_default`（基础掉落）
- 日志警告: "Enemy [id] drop_table_id [table] not found, using default"
- 掉落仍能结算，玩家获得基础奖励

**Test**: 配置不存在的 `drop_table_id` → 验证使用 fallback。

---

### Edge Case 6: Zero Enemies Spawned

**Scenario**: `enemy_count = 0` 或随机选择失败，导致无敌人生成。

**Expected Behavior**:
- 至少生成1个敌人（fallback）
- 日志警告: "Zero enemies spawned for floor [N], generating fallback"
- 强制生成 `enemy_slime` 作为默认

**Test**: 设置 `enemy_count = 0` → 验证生成 fallback 敌人。

---

### Edge Case 7: Power Rating Out of Range

**Scenario**: 计算出的 `power_rating < 100` 或 `> 550`。

**Expected Behavior**:
- Clamp到有效范围: `power_rating = clamp(pr, MIN_POWER_RATING, MAX_POWER_RATING)` 即 [100, 550]
- 日志警告（如果超出10%）
- 敌人仍能匹配层级配置

**Test**: 配置极端数值（hp=10, atk=1） → 验证 power_rating = 100。

---

### Edge Case 8: Duplicate Enemy IDs in Data

**Scenario**: 两个敌人定义使用相同ID。

**Expected Behavior**:
- 数据加载验证失败
- 日志错误: "Duplicate enemy ID [id] in files [file1] and [file2]"
- 拒绝加载，要求修复数据

**Test**: 创建重复ID的敌人 → 验证验证失败，拒绝加载。

## Dependencies

### Upstream Dependencies (本系统依赖)

| System | Type | Interface | Notes |
|--------|------|-----------|-------|
| **物品数据库** | Hard | `get_equipment(id)`, `get_material(id)` | 敌人掉落表需要物品ID来解析掉落内容 |
| **地牢结构系统** | Hard | `get_floor_data(floor_id).enemy_types`, `enemy_count` | 敌人生成需要层级配置 |

**Constraint from 物品数据库 GDD**:
- 敌人掉落表中的装备ID必须存在于物品数据库
- 材料ID必须存在于物品数据库
- 稀有度颜色映射必须对齐物品数据库的 Rarity 颜色

**Constraint from 地牢结构系统 GDD**:
- 敌人数量使用 `enemy_count(floor_id)` 公式结果
- 敌人类型从 `floor_data.enemy_types` 列表选择
- 敌人 power_rating 应匹配 `recommended_power(floor_id ± 20%)`

---

### Downstream Dependencies (依赖本系统)

| System | Type | Interface Used | Notes |
|--------|------|---------------|-------|
| **战斗系统** | Hard | `spawn_enemies_for_floor()`, `damage_enemy()`, `is_enemy_defeated()` | 战斗系统需要敌人实例作为攻击目标 |
| **掉落表系统** | Hard | `get_enemy_definition(id).drop_table_id` | 掉落表系统根据敌人掉落表ID计算掉落 |
| **装备掉落系统** | Hard | Enemy defeat → drop resolution | 掉落展示依赖敌人击败事件触发 |
| **地牢推进系统** | Soft | `get_enemies_for_floor(floor_id)` | 推进系统可能预览层级敌人配置 |
| **视觉反馈系统** | Hard | `enemy_defeated` signal, enemy rarity | 粒子效果强度根据敌人稀有度变化 |
| **粒子系统** | Soft | Enemy defeat position, particle count | 粒子生成位置和数量依赖敌人击败事件 |

---

### External Dependencies (非游戏系统)

| Dependency | Type | Usage |
|------------|------|-------|
| **Godot PackedScene** | Soft | 敌人实例化使用场景模板 |
| **Godot Timer/Tween** | Soft | 入场/击败动画使用 Tween |
| **Godot JSON parsing** | Soft | 敌人定义文件解析 |

## Tuning Knobs

| Knob | Default | Safe Range | Unit | What It Affects | Extreme Behavior |
|------|---------|------------|------|-----------------|------------------|
| **HEALTH_POWER_WEIGHT** | 0.5 | 0.3–1.0 | ratio | 生命值对战力评估的贡献 | 太低：HP高的敌人战力低估；太高：防御/攻击被忽略 |
| **ATTACK_POWER_WEIGHT** | 3.0 | 1.5–5.0 | ratio | 攻击力对战力评估的贡献 | 太低：攻击力敌人战力低估；太高：HP/防御被忽略 |
| **DEFENSE_POWER_WEIGHT** | 2.0 | 1.0–4.0 | ratio | 防御力对战力评估的贡献 | 太低：防御敌人战力低估；太高：HP/攻击被忽略 |
| **SCALING_FACTOR** | 0.15 | 0.10–0.25 | ratio | 低层敌人高层放大系数 | 太低：遗留敌人太弱无挑战；太高：遗留敌人过强卡进度 |
| **HITS_PER_SECOND** | 2.0 | 1.0–4.0 | hits/sec | 自动战斗攻击频率 | 太低：战斗拖沓；太高：战斗太快，爽感不足 |
| **SPAWN_ANIMATION_DURATION** | 0.3 | 0.15–0.5 | seconds | 敌人入场动画时长 | 太短：无视觉反馈；太长：战斗开始拖沓 |
| **DEFEAT_ANIMATION_DURATION** | 0.5 | 0.3–1.0 | seconds | 敌人击败动画时长 | 太短：爽感不足；太长：跳过战斗体验不流畅 |
| **MIN_POWER_RATING** | 100 | 50–150 | 战力点 | 敌人最低战力值 | 太低：新手敌人太弱无意义；太高：新手门槛过高 |
| **MAX_POWER_RATING** | 550 | 400–700 | 战力点 | 敌人最高战力值（MVP） | 太低：最终层挑战不足；太高：超出MVP地牢结构范围 |
| **ENEMY_COUNT_VARIANCE** | 0 | 0–1 | count | 敌人数量随机波动（±N） | 0：固定数量；1：可能±1敌人变化 |

### Knob Configuration File

All knobs are defined in `assets/data/tuning/enemy_config.json`:

```json
{
  "version": "1.0.0",
  "power_weights": {
    "health": 0.5,
    "attack": 3.0,
    "defense": 2.0
  },
  "scaling": {
    "factor": 0.15
  },
  "combat": {
    "hits_per_second": 2.0
  },
  "animations": {
    "spawn_duration": 0.3,
    "defeat_duration": 0.5
  },
  "limits": {
    "min_power_rating": 100,
    "max_power_rating": 550,
    "enemy_count_variance": 0
  }
}
```

## Visual/Audio Requirements

### Visual Requirements

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| **敌人入场动画** | Scale from 0.5→1.0 over 0.3s, bounce easing | 敌人从缩小状态弹跳入场 |
| **敌人击败动画** | Scale from 1.0→0.0 over 0.5s, fade-out + shake | 敌人缩小消失 + 屏幕轻微震动 |
| **敌人稀有度颜色** | 对齐 ItemDatabase Rarity 颜色（COMMON=Earthen Brown, RARE=Soft Lavender, EPIC=Celebration Orange） | 敌人名称/边框颜色 |
| **击败粒子效果** | COMMON: 10-20 particles; RARE: 30-50 particles; EPIC: 50-100 particles | 粒子数量根据稀有度变化 |
| **敌人图标风格** | 圆润造型，饱和色彩（对齐 Art Bible） | 避免尖锐/暗黑风格 |
| **敌人位置布局** | 多敌人时横向分布，间距至少 80px | 防止重叠 |

### Audio Requirements

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| **敌人击败音效** | Post-MVP（音效系统负责） | MVP阶段无声效 |
| **敌人入场音效** | Post-MVP | MVP阶段无声效 |

## UI Requirements

| Requirement | Specification | Priority |
|-------------|---------------|----------|
| **敌人名称显示** | 战斗开始时显示敌人 `display_name` | MVP |
| **敌人生命值显示** | HP条显示 `current_health / max_health` | MVP |
| **敌人数量显示** | HUD显示 "Enemies: N/M"（击败进度） | MVP |
| **敌人战力预览** | 战斗前显示敌人 `power_rating`（可选） | Post-MVP |
| **敌人稀有度标识** | 名称颜色根据 Rarity 变化 | MVP |

**下游系统 UI 约束**:
- 战斗系统必须调用 `get_enemy_instance()` 获取敌人数据用于 UI 显示
- 视觉反馈系统必须监听 `enemy_defeated` 信号触发粒子效果

## Acceptance Criteria

### Data Loading Criteria

- **GIVEN** 游戏启动，**WHEN** EnemyDatabase 初始化，**THEN** 所有敌人JSON文件加载成功，`get_all_enemy_ids()` 返回8个ID。
- **GIVEN** 敌人JSON包含无效字段，**WHEN** 加载验证，**THEN** 跳过该敌人，日志记录错误，其他敌人正常加载。
- **GIVEN** 敌人JSON包含重复ID，**WHEN** 加载验证，**THEN** 拒绝加载，日志记录冲突ID。

---

### Enemy Instance Generation Criteria

- **GIVEN** 第1层配置 `enemy_types = [enemy_slime, enemy_goblin]`, `enemy_count = 1`，**WHEN** `spawn_enemies_for_floor(1)` 调用，**THEN** 生成1个敌人实例，类型为 Slime 或 Goblin。
- **GIVEN** 第6层配置 `enemy_count = 2`，**WHEN** 生成敌人，**THEN** 生成2个敌人实例。
- **GIVEN** 第10层配置 `enemy_count = 4`，**WHEN** 生成敌人，**THEN** 生成4个敌人实例。
- **GIVEN** 层级配置 `enemy_types = []`，**WHEN** 生成敌人，**THEN** 使用 fallback 敌人（Slime），日志记录警告。

---

### Power Rating Criteria

- **GIVEN** Slime (hp=50, atk=5, def=2)，**WHEN** 计算战力评估值，**THEN** `power_rating = 100`（clamp到最低值）。
- **GIVEN** Dragon Spawn (hp=500, atk=80, def=40)，**WHEN** 计算战力评估值，**THEN** `power_rating = 550`（符合最终层门槛）。
- **GIVEN** 自定义敌人 (hp=10, atk=1, def=0)，**WHEN** 计算战力评估值，**THEN** `power_rating = 100`（clamp到最低值）。

---

### Enemy Scaling Criteria

- **GIVEN** Goblin (base_floor=2, hp=80) 在第6层出现，**WHEN** 计算放大生命值，**THEN** `scaled_health = 80 * (1 + 4 * 0.15) = 128`。
- **GIVEN** Slime (base_floor=1, atk=5) 在第5层出现，**WHEN** 计算放大攻击力，**THEN** `scaled_attack = 5 * (1 + 4 * 0.15) = 8`。

---

### State Transition Criteria

- **GIVEN** 敌人实例生成，**WHEN** 入场动画开始，**THEN** 状态为 SPAWNING，0.3秒后转为 ALIVE。
- **GIVEN** 敌人 ALIVE 状态，`current_health = 0`，**WHEN** 受到致命伤害，**THEN** 状态转为 DEFEATED。
- **GIVEN** 敌人 DEFEATED 状态，**WHEN** 动画完成，**THEN** 实例销毁，触发掉落结算。

---

### Interface Integration Criteria

- **GIVEN** 战斗系统调用 `damage_enemy(instance_id, 50)`，**WHEN** 敌人 ALIVE 状态，**THEN** `current_health -= 50`，返回更新后的 HP。
- **GIVEN** 视觉反馈系统监听 `enemy_defeated` 信号，**WHEN** EPIC敌人击败，**THEN** 信号携带 `{rarity: EPIC, position: Vector2}`，触发50-100粒子。
- **GIVEN** 掉落表系统请求敌人掉落表，**WHEN** 调用 `get_enemy_definition(id).drop_table_id`，**THEN** 返回有效掉落表ID。

---

### MVP Content Verification

- **GIVEN** EnemyDatabase 加载完成，**WHEN** 查询所有敌人，**THEN** 以下8个敌人存在：
  - `enemy_slime`
  - `enemy_goblin`
  - `enemy_skeleton`
  - `enemy_orc`
  - `enemy_shadow_knight`
  - `enemy_wraith`
  - `enemy_dragon_spawn`
  - `enemy_giant_spider`

## Open Questions

| Question | Owner | Target Resolution | Status |
|----------|-------|-------------------|--------|
| **是否需要敌人攻击动画？** | Game Designer | 原型验证时 | Open — MVP阶段敌人可能是静态目标，无主动攻击动画 |
| **是否需要敌人类型 Boss 分类？** | Game Designer | MVP后评估 | Open — MVP第10层Dragon Spawn可以是Boss，需要特殊击败动画 |
| **敌人是否需要元素属性（火/冰等）？** | Systems Designer | Post-MVP | Open — MVP阶段简化为纯数值对抗 |
| **敌人掉落是否需要"首次击杀奖励"？** | Economy Designer | MVP后评估 | Open — 增加推进吸引力 |
| **是否需要敌人行为差异化（有的敌人反击、有的逃跑）？** | AI Programmer | Post-MVP | Open — MVP阶段所有敌人行为相同（被动目标） |
| **敌人图标是否需要动态表情？** | Technical Artist | Vertical Slice | Open — 增加视觉趣味性 |