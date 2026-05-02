# 数值显示系统 (Stat Display System)

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-05-02
> **Implements Pillar**: 爽感反馈 + 稳定成长

## Overview

数值显示系统是游戏的数值呈现层，负责格式化、着色和动画化所有游戏数值的显示。它从物品数据库获取装备属性定义，从货币系统订阅数值变化信号，为UI层提供统一的数值显示接口——包括装备属性面板、HUD货币显示、强化结果预览和地牢层级统计等所有数值元素。

从玩家视角，数值显示系统让"成长"成为可见可感的体验。每次装备属性变化、每次金币增减、每次强化完成，数字都以bounce动画和颜色编码呈现。玩家看到攻击力从10变为13，看到金币从500飞升至3600——这种视觉反馈是支柱"爽感反馈"的核心实现。数值显示系统不仅是数据呈现，更是"数值暴涨"爽感的载体。

系统覆盖范围：
- **装备属性显示**: 武器/护甲的攻击力、防御力，强化等级，稀有度颜色编码
- **货币显示**: HUD金币数量（含紧凑格式1.2K），宝石数量
- **强化结果**: 强化后的属性变化预览（旧值→新值，增量）
- **战斗/地牢统计**: 当前层级、敌人战力、战斗时长等

系统不存储数值数据（存档系统职责），不计算数值（物品数据库/战斗系统职责），只负责**呈现层**——格式化、着色、动画化。

## Player Fantasy

数值显示系统支撑的核心玩家幻想是：

> **"数字跳起来，我能看到变强"** — 每次数值变化都不是冷冰冰的数字跳变，而是有生命的视觉事件。攻击力涨了？数字bounce弹跳。金币多了？HUD数字飞升。强化完成了？属性对比弹出，增量数字闪烁。玩家不是"知道变强"，而是"看到变强"——数字本身就是爽感。

这支撑支柱**爽感反馈**：
- 所有数值变化都有动画反馈：bounce弹跳、颜色闪烁、数字飞升
- 稀有度颜色编码让装备品质一目了然：COMMON棕色、RARE紫色、EPIC橙色
- 强化结果预览展示"旧值→新值"对比，增量用醒目颜色突出

这支撑支柱**稳定成长**：
- 数值永远清晰可见，玩家知道"我现在有多强"
- 强化预览让玩家知道"强化后有多强"——可预期、无惊喜的不确定性
- HUD货币实时显示，玩家知道"我有多少资源"

这支撑支柱**掌控节奏**：
- 玩家可以选择关注哪些数值：装备属性、货币积累、地牢进度
- 数值显示不强制打断玩家，而是作为信息层随时可查

**参考**: Clicker Heroes — 数字暴涨时的飞升动画；暗黑破坏神 — 装备属性对比界面，新旧值清晰对比；梦幻西游手游 — 强化预览显示"强化后属性"。

**Direct system**: 玩家直接与数值显示互动——查看装备面板、观察HUD货币、阅读强化结果预览。数值显示是玩家每秒都能看到的信息层，不是隐藏的后台系统。

## Detailed Design

### Core Rules

#### Rule 1: Number Formatting — Compact Display for Large Values

数值显示系统对大数值使用紧凑格式，保持UI简洁：

| Value Range | Format | Example |
|-------------|--------|---------|
| 0–999 | 整数显示 | 500 → "500" |
| 1,000–999,999 | K格式 | 5,200 → "5.2K" |
| 1,000,000+ | M格式 | 3,600,000 → "3.6M" |

**格式化方法**: `format_number(value: int) -> String`
- 自动选择格式，无手动配置
- 无小数位的整数直接显示（如1000 → "1K"不是"1.0K"）
- 小数位仅在有有效小数时显示（如1200 → "1.2K"）

---

#### Rule 2: Rarity Color Coding — From ItemDatabase Colors

所有装备相关数值使用稀有度颜色编码，颜色来自物品数据库的Art Bible定义：

| Rarity | Hex | Usage in Stat Display |
|--------|-----|----------------------|
| COMMON | #8B6914 (Earthen Brown) | 装备名称、属性值（低阶） |
| UNCOMMON | #7CB342 (Verdant Growth) | 装备名称、属性值 |
| RARE | #9B7BB8 (Soft Lavender) | 装备名称、属性值、强化预览高亮 |
| EPIC | #F27D16 (Celebration Orange) | 装备名称、属性值、强化成功庆祝 |
| LEGENDARY | #E5A50A (Golden Amber) | 装备名称、属性值、特殊边框光效 |

**应用范围**:
- 装备名称文本
- 装备属性数值（可选，MVP可简化为统一白色）
- 强化成功时的属性增量高亮

---

#### Rule 3: Bounce Animation — All Value Changes Trigger Feedback

所有数值变化触发bounce动画反馈：

| Event | Animation | Duration |
|-------|-----------|----------|
| 小变化 (1–50) | 微小bounce弹跳 | 0.2s |
| 中变化 (51–500) | bounce弹跳 + 颜色闪烁 | 0.4s |
| 大变化 (501+) | 大bounce + 数字飞升效果 | 0.6s |
| 强化完成 | 属性对比面板弹出，增量闪烁 | 1.0s |

**Bounce参数**:
- 弹跳强度: small=1.05x, medium=1.15x, large=1.25x scale
- 弹跳曲线: ease_out_back (Godot Tween ease type)
- 数字飞升: 从原位置向上升移20px后回落

---

#### Rule 4: Equipment Attribute Display Format

装备属性面板显示格式：

**基础属性**:
```
[装备名称] (稀有度颜色)
攻击力: [数值] (+[强化增量] 强化颜色)
防御力: [数值] (+[强化增量] 强化颜色)
强化等级: +[等级]
```

**强化预览**:
```
强化预览 (+[新等级]):
攻击力: [旧值] → [新值] (+[增量] 绿色高亮)
防御力: [旧值] → [新值] (+[增量] 绿色高亮)
费用: [金币图标] [费用数量]
```

**属性增量颜色**:
- 正增量: 绿色 (#7CB342 — Verdant Growth)
- 无增量: 灰色 (#666666)
- (无负增量 — 强化必定成功)

---

#### Rule 5: Currency Display Format

货币显示格式：

| Currency | Format | Position |
|----------|--------|----------|
| Gold | 图标 + 数值（紧凑格式） | HUD左上 |
| Gem | 图标 + 数值 | HUD右上 |

**变化动画**:
- 金币增加: 数字bounce + 金色闪光
- 金币减少: 数字收缩动画（强化费用支付时）
- 大额变化(500+): 数字飞升 + 边缘金光

**零值显示**:
- Gold 0: 显示"0"，不隐藏
- Gem 0: 显示"0"，灰化图标 + tooltip "Coming Soon"

---

#### Rule 6: Comparison Display — Before/After Format

对比显示用于强化预览和装备切换对比：

**格式**: `[旧值] → [新值] (+增量)` 或 `[旧值] → [新值] (-减量)`
- 增量用绿色高亮
- 减量用红色高亮（装备切换对比时可能出现）
- 新值用粗体强调

**触发场景**:
- 强化预览面板（强化系统调用）
- 装备切换对比（装备槽系统调用）
- 装备掉落对比（掉落系统调用 — 新装备 vs 当前装备）

---

#### Rule 7: Dungeon/Floor Stats Display

地牢层级统计显示：

| Stat | Format | Position |
|------|--------|----------|
| Current Floor | "第X层" | HUD中央或地牢入口UI |
| Enemy Power | 敌人战力数值 | 战斗预览UI |
| Battle Time | "战斗时长: X秒" | 战斗结束UI（可选） |

---

#### Rule 8: Tooltip Alternative — Touch-Friendly Info Display

移动端无hover状态，数值显示系统提供替代信息展示方式：

| Context | Touch Alternative |
|---------|-------------------|
| 装备属性详情 | 点击装备图标 → 属性面板弹出 |
| 货币详情 | 点击金币区域 → 无详情（数值已直接显示） |
| 强化费用 | 强化按钮旁直接显示费用 |

---

### States and Transitions

数值显示系统是呈现层，**无游戏逻辑状态**。

| State | Description | Operations Available |
|-------|-------------|---------------------|
| **Inactive** | UI未加载或隐藏 | 无显示请求 |
| **Active** | UI可见 | 所有显示方法可用 |

**过渡**:
- Inactive → Active: UI场景加载完成
- Active → Inactive: UI场景卸载或面板关闭

---

### Interactions with Other Systems

| System | Direction | Interface | Data Flow |
|--------|-----------|-----------|-----------|
| **物品数据库** (Upstream) | Inbound | `get_rarity_color(rarity)`, `get_equipment(id)` | 提供稀有度颜色映射、装备基础属性 |
| **货币系统** (Upstream) | Inbound | Signal: `currency_changed` | 订阅货币变化，触发HUD更新动画 |
| **存档系统** (Upstream) | Inbound | `get_enhancement_level(equipment_id)` | 提供装备强化等级（用于计算显示属性） |
| **装备槽系统** (Downstream) | Outbound | `display_equipment_stats(id, level)` | 装备槽调用显示接口，渲染装备面板 |
| **强化系统** (Downstream) | Outbound | `display_enhancement_preview(id, current_level, new_level)` | 强化系统调用预览显示 |
| **视觉反馈系统** (Downstream) | Outbound | Animation triggers | 视觉反馈系统可能增强数值动画（粒子叠加） |

## Formulas

### Formula 1: Compact Number Formatting Threshold

紧凑格式阈值决定何时使用K/M格式：

| Threshold | Format | Formula |
|-----------|--------|---------|
| value < 1000 | 整数 | `str(value)` |
| 1000 ≤ value < 1000000 | K格式 | `str(floor(value / 1000)) + "K"` (if exact) or `str(round(value / 1000, 1)) + "K"` |
| value ≥ 1000000 | M格式 | `str(floor(value / 1000000)) + "M"` (if exact) or `str(round(value / 1000000, 1)) + "M"` |

**实现逻辑**:
```
func format_number(value: int) -> String:
    if value < 1000:
        return str(value)
    elif value < 1000000:
        var k_value = value / 1000.0
        if k_value == floor(k_value):
            return str(int(k_value)) + "K"
        else:
            return str(round(k_value, 1)) + "K"
    else:
        var m_value = value / 1000000.0
        if m_value == floor(m_value):
            return str(int(m_value)) + "M"
        else:
            return str(round(m_value, 1)) + "M"
```

**示例**:
- 500 → "500"
- 1000 → "1K" (不是"1.0K")
- 1200 → "1.2K"
- 3600000 → "3.6M"

---

### Formula 2: Animation Magnitude Classification

动画强度分类基于数值变化量：

| Magnitude | Change Amount | Animation Parameters |
|-----------|---------------|---------------------|
| Small | 1–50 | duration=0.2s, scale=1.05x |
| Medium | 51–500 | duration=0.4s, scale=1.15x, flash=true |
| Large | 501+ | duration=0.6s, scale=1.25x, fly_up=true |

**分类公式**:
```
magnitude = "small" if change <= 50
magnitude = "medium" if 51 <= change <= 500
magnitude = "large" if change > 500
```

**动画参数映射**:
```
ANIMATION_PARAMS = {
    "small": { duration: 0.2, scale: 1.05, flash: false, fly_up: false },
    "medium": { duration: 0.4, scale: 1.15, flash: true, fly_up: false },
    "large": { duration: 0.6, scale: 1.25, flash: true, fly_up: true }
}
```

---

### Formula 3: Enhanced Attribute Display Value

装备强化属性显示值计算（调用ItemDatabase公式并格式化）：

`display_attack = format_number(ItemDatabase.calculate_enhanced_attack(equipment_id, enhancement_level))`

**变量**:
| Variable | Source | Range |
|----------|--------|-------|
| equipment_id | 装备槽系统/存档 | String |
| enhancement_level | 存档系统 | 0–10 |

**显示值计算**: 数值显示系统**不计算属性**，只调用ItemDatabase的计算方法并格式化输出。

---

### Formula 4: Enhancement Delta (for Preview Display)

强化增量计算（用于强化预览显示）：

`attack_delta = ItemDatabase.calculate_enhanced_attack(equipment_id, new_level) - ItemDatabase.calculate_enhanced_attack(equipment_id, current_level)`

`defense_delta = ItemDatabase.calculate_enhanced_defense(equipment_id, new_level) - ItemDatabase.calculate_enhanced_defense(equipment_id, current_level)`

**增量显示格式**: `"+[delta]"` (绿色) 或 `"+0"` (灰色)

---

### Formula 5: Bounce Tween Curve

Bounce动画使用ease_out_back曲线：

**Godot Tween参数**:
```
tween.tween_property(label, "scale", Vector2(1.0, 1.0), duration)
      .from(Vector2(scale, scale))
      .set_ease(Tween.EASE_OUT)
      .set_trans(Tween.TRANS_BACK)
```

**曲线特性**:
- ease_out_back: 弹跳时轻微超过目标值后回弹，创造"弹性感"
- scale参数由动画强度决定（small=1.05, medium=1.15, large=1.25)

## Edge Cases

### Display Edge Cases

- **If `format_number()` is called with value = 0**: Return "0" (not empty string or special case). Rationale: Zero is a valid display value for currency or stats; hiding it would confuse players.

- **If `format_number()` is called with very large value (≥ 1,000,000,000)**: Use "M" format even for billions (e.g., 1.5B → "1500M"). MVP unlikely to reach this range, but formula handles it gracefully. Rationale: No need for "B" format in MVP scope.

- **If `format_number()` is called with negative value**: Return str(value) with minus sign (e.g., -50 → "-50"). Rationale: Defensive handling; negative values shouldn't occur in valid gameplay, but system doesn't crash.

### Animation Edge Cases

- **If bounce animation is triggered while previous animation is still running**: Cancel previous tween and start new animation. Rationale: Prevents animation stacking; ensures latest value change is visually represented.

- **If `display_currency_change()` is called with change = 0**: No animation triggered. Rationale: Zero change doesn't need visual feedback; prevents unnecessary animation calls.

- **If animation duration exceeds performance budget**: System logs warning but continues. MVP animation durations (0.2–0.6s) are within budget. Rationale: Performance budget is a soft constraint for UI; animations are critical to pillar 爽感反馈.

### Equipment Display Edge Cases

- **If `display_equipment_stats()` is called with invalid equipment_id**: Display "Unknown Equipment" with COMMON color and log warning. Rationale: Graceful degradation; UI shouldn't crash on data errors.

- **If `display_equipment_stats()` is called with enhancement_level outside 0–10**: Clamp to 0–10 range for display (ItemDatabase clamps anyway). Rationale: Invalid levels shouldn't exist, but display handles them gracefully.

- **If `display_enhancement_preview()` is called with current_level = new_level**: Display "无变化" (No Change) for delta, grayed out. Rationale: Edge case where player previews same level; should still show comparison.

### Rarity Color Edge Cases

- **If `get_rarity_color()` receives invalid Rarity enum**: Return COMMON color (#8B6914) and log warning. Rationale: UI must always have a color; fallback to most common tier.

- **If ItemDatabase is not loaded when rarity color is requested**: Return fallback COMMON color (#8B6914) and log error. Rationale: System remains usable during loading edge cases.

### Currency Display Edge Cases

- **If CurrencySystem emits `currency_changed` signal before StatDisplaySystem is initialized**: Signal ignored; no crash. Rationale: Signal subscription happens on initialization; early signals are safely discarded.

- **If `display_currency()` is called when CurrencySystem cache shows null**: Display "0" and log warning. Rationale: Null cache indicates uninitialized state; show safe default.

### Comparison Display Edge Cases

- **If `display_comparison()` is called with old_value > new_value**: Display delta with red color for negative change (装备切换时可能出现). Rationale: Valid scenario when comparing lower-tier equipment to current.

- **If `display_comparison()` is called with identical values**: Display "无差异" (No Difference) in gray. Rationale: Edge case for identical equipment comparison.

## Dependencies

### Upstream Dependencies (Required for StatDisplaySystem)

| System | Dependency Type | Interface | Critical? |
|--------|----------------|-----------|-----------|
| **物品数据库** | Hard | `get_rarity_color(rarity)`, `get_equipment(id)`, `calculate_enhanced_attack(id, level)` | Yes — StatDisplaySystem cannot display equipment stats without attribute definitions |
| **货币系统** | Hard | Signal: `currency_changed`, `get_balance(currency_id)` | Yes — HUD currency display depends on real-time updates |
| **存档系统** | Soft | `get_enhancement_level(equipment_id)` | Partial — StatDisplaySystem can use cached enhancement levels from caller |

### Horizontal Dependencies (Parallel systems)

| System | Dependency Type | Interface | Critical? |
|--------|----------------|-----------|-----------|
| **Godot Tween/AnimationPlayer** | Hard | Tween API, AnimationPlayer nodes | Yes — Built-in engine API, always available |

### Downstream Dependencies (Systems that depend on StatDisplaySystem)

| System | Dependency Type | Interface | Status |
|--------|----------------|-----------|--------|
| **装备槽系统** | Hard | `display_equipment_stats(id, level)` | Designed |
| **强化系统** | Hard | `display_enhancement_preview(id, current, new)` | Not yet designed |
| **视觉反馈系统** | Soft | Animation triggers (optional enhancement) | Not yet designed |
| **掉落系统** | Soft | `display_comparison(old, new)` for dropped equipment vs current | Not yet designed |

### Interface Contracts

StatDisplaySystem guarantees these contracts to downstream systems:

1. **Pure Display Functions**: All methods return formatted strings or trigger animations — no state modification.

2. **Null Safety**: All display methods return valid display strings even with invalid input — "Unknown" or "0" fallbacks.

3. **Animation Independence**: Bounce animations don't block caller execution; animations run asynchronously.

4. **Color Consistency**: Rarity colors are consistent with ItemDatabase Art Bible definition — no custom color overrides.

### Dependency Graph

```
    [ItemDatabase] ─────→ [StatDisplaySystem] ←──── [CurrencySystem]
           │                    │                      │
           │                    │                      │
           v                    v                      v
    [装备槽系统]           [强化系统]            [HUD Currency UI]
                               │
                               v
                        [视觉反馈系统] (optional)
```

### Dependency Notes

- **物品数据库**: StatDisplaySystem queries ItemDatabase for rarity colors and equipment attribute calculations. If ItemDatabase is unavailable, fallback colors are used (COMMON color).

- **货币系统**: StatDisplaySystem subscribes to `currency_changed` signal for real-time HUD updates. If signal connection fails, display can still query balance via `get_balance()`.

- **存档系统**: Enhancement levels are typically passed by caller (装备槽系统 or 强化系统), so StatDisplaySystem doesn't directly query SaveSystem.

- **视觉反馈系统**: Optional enhancement — Visual Feedback System may overlay particle effects on bounce animations for more impact. StatDisplaySystem provides animation triggers via signals.

## Tuning Knobs

| Knob | Type | Range | Default | Effect |
|------|------|-------|---------|--------|
| `ANIMATION_DURATION_SMALL` | float | 0.1–0.3s | 0.2s | Small value change bounce duration. Higher = slower feedback, lower = snappier. |
| `ANIMATION_DURATION_MEDIUM` | float | 0.3–0.6s | 0.4s | Medium value change bounce duration. |
| `ANIMATION_DURATION_LARGE` | float | 0.4–1.0s | 0.6s | Large value change bounce duration. |
| `ANIMATION_SCALE_SMALL` | float | 1.02–1.10 | 1.05 | Bounce scale multiplier for small changes. Higher = more pronounced bounce. |
| `ANIMATION_SCALE_MEDIUM` | float | 1.10–1.20 | 1.15 | Bounce scale multiplier for medium changes. |
| `ANIMATION_SCALE_LARGE` | float | 1.15–1.35 | 1.25 | Bounce scale multiplier for large changes. |
| `BOUNCE_CURVE` | String | ease_out_back, ease_out_elastic | ease_out_back | Tween curve type. ease_out_elastic = more bouncy/cartoonish. |
| `NUMBER_FLY_UP_DISTANCE` | int | 10–50px | 20px | Vertical offset for fly-up animation. Higher = more dramatic lift. |
| `SMALL_CHANGE_THRESHOLD` | int | 10–100 | 50 | Value change threshold for "small" classification. Higher = fewer small animations. |
| `MEDIUM_CHANGE_THRESHOLD` | int | 100–1000 | 500 | Value change threshold for "medium" classification. |
| `FORMAT_K_THRESHOLD` | int | 500–5000 | 1000 | Value threshold for K format display. |
| `FORMAT_M_THRESHOLD` | int | 500000–2000000 | 1000000 | Value threshold for M format display. |
| `INCREMENT_COLOR_POSITIVE` | Color | — | #7CB342 (Verdant Growth) | Color for positive attribute increments (enhancement preview). |
| `INCREMENT_COLOR_NEGATIVE` | Color | — | #CC3333 (Red) | Color for negative attribute changes (equipment comparison). |
| `INCREMENT_COLOR_ZERO` | Color | — | #666666 (Gray) | Color for zero/no change. |

### Tuning Knob Configuration File

All knobs defined in `assets/data/tuning/stat_display_config.json`:

```json
{
  "version": "1.0.0",
  "animation": {
    "duration_small": 0.2,
    "duration_medium": 0.4,
    "duration_large": 0.6,
    "scale_small": 1.05,
    "scale_medium": 1.15,
    "scale_large": 1.25,
    "bounce_curve": "ease_out_back",
    "fly_up_distance": 20
  },
  "thresholds": {
    "small_change": 50,
    "medium_change": 500,
    "format_k": 1000,
    "format_m": 1000000
  },
  "colors": {
    "increment_positive": "#7CB342",
    "increment_negative": "#CC3333",
    "increment_zero": "#666666"
  }
}
```

### Balance Impact Analysis

| Knob Group | Increased Value Effect | Decreased Value Effect |
|------------|----------------------|------------------------|
| Animation durations | More dramatic feedback, may feel sluggish on mobile | Snappier feedback, may miss the "pop" sensation |
| Animation scales | More pronounced bounce, cartoonish feel | Subtle bounce, may feel flat |
| Change thresholds | Fewer animations triggered, calmer UI | More animations triggered, more reactive feel |
| Format thresholds | Numbers stay numeric longer, more precise | Numbers compact sooner, cleaner UI |

### Safe Tuning Ranges

- **Animation durations**: Keep small ≤ 0.3s to maintain snappy feel on mobile.
- **Animation scales**: 1.05–1.25 range provides visible bounce without feeling broken.
- **Format thresholds**: 1000 for K, 1000000 for M are standard conventions.

## Visual/Audio Requirements

### Visual Feedback Owned by StatDisplaySystem

数值显示系统直接提供以下视觉反馈：

| Event | Visual Effect | Implementation |
|-------|---------------|----------------|
| **数值变化 (小)** | 数字微小bounce弹跳，scale 1.05x | Tween ease_out_back, 0.2s |
| **数值变化 (中)** | 数字bounce弹跳 + 颜色闪烁 | Tween + modulate color flash |
| **数值变化 (大)** | 数字bounce + 飞升动画 (向上20px) | Tween + position offset |
| **强化完成** | 属性对比面板弹出，增量闪烁 | Panel animation + label flash |
| **金币增加** | HUD数字bounce + 金色闪光 | Tween + gold color modulate |
| **金币减少** | HUD数字收缩动画 | Tween scale down to 0.8x then back |

### Visual Effects Delegated to Other Systems

以下视觉效果由其他系统提供，数值显示系统只提供触发信号：

| Effect | Owner System | StatDisplaySystem Role |
|--------|--------------|------------------------|
| **粒子爆发** | 粒子系统/视觉反馈系统 | 发射 `value_changed_large` 信号 |
| **屏幕震动** | 震动反馈系统 | 发射 `value_changed_large` 信号 |
| **金币飞出图标** | 视觉反馈系统 | 发射 `gold_added` 信号 |
| **强化成功庆祝特效** | 视觉反馈系统 | 发射 `enhancement_complete` 信号 |

### Audio Requirements

数值显示系统**不直接播放音效**。所有音效由音效系统负责：

| Event | Audio Effect | Owner System |
|-------|--------------|--------------|
| **金币增加 (小)** | Soft coin "clink" | 音效系统 |
| **金币增加 (大)** | Coin cascade / "Ka-ching" | 音效系统 |
| **强化完成** | Enhancement success sound | 音效系统 |
| **数值变化** | 通常无音效 (仅视觉反馈) | — |

**音效触发方式**: 数值显示系统发射信号 → 音效系统订阅并播放对应音效。

## UI Requirements

### HUD Currency Display

| Element | Position | Format | Behavior |
|---------|----------|--------|----------|
| **Gold Icon + Number** | HUD左上 | 图标 + 紧凑格式数值 | 始终可见，变化时bounce动画 |
| **Gem Icon + Number** | HUD右上 | 图标 + 数值 | 灰化图标（MVP Gem=0），tooltip "Coming Soon" |

### Equipment Attribute Panel

装备属性面板在以下场景显示：

| Context | Trigger | Panel Content |
|---------|---------|---------------|
| **装备槽点击** | 点击已装备槽位 | 当前装备属性 + 强化等级 |
| **装备切换选择** | 选择新装备 | 新装备属性 vs 当前装备对比 |
| **强化预览** | 强化按钮点击前 | 强化后属性预览 + 费用 |

**面板布局**:
```
┌─────────────────────────────┐
│ [装备名称] (稀有度颜色)       │
│ ─────────────────────────── │
│ 攻击力: [数值] (+[增量])     │
│ 防御力: [数值] (+[增量])     │
│ 强化等级: +[等级]            │
│ ─────────────────────────── │
│ [强化按钮]  费用: [金币]      │
└─────────────────────────────┘
```

### Enhancement Preview Panel

强化预览面板显示强化后属性变化：

| Element | Display Format |
|---------|----------------|
| **标题** | "强化预览 (+[新等级])" |
| **攻击力变化** | [旧值] → [新值] (+增量 绿色) |
| **防御力变化** | [旧值] → [新值] (+增量 绿色) |
| **费用** | 金币图标 + 费用数值 |
| **当前余额** | "当前金币: [余额]" |
| **差额提示** | "还需要 [差额] 金币" (红色，不足时) |
| **按钮状态** | 不足时禁用，显示 "金币不足" |

### Dungeon/Floor Stats

| Element | Position | Format |
|---------|----------|--------|
| **当前层级** | HUD中央或地牢入口UI | "第 [X] 层" |
| **敌人战力** | 战斗预览UI | "敌人战力: [数值]" |
| **战斗时长** | 战斗结束UI (可选) | "战斗时长: [X] 秒" |

### Touch-Friendly Information Display

移动端无hover状态，信息通过点击触发展示：

| Context | Touch Behavior |
|---------|----------------|
| **装备图标点击** | 弹出装备属性面板 |
| **金币区域点击** | 无详情面板（数值已直接显示） |
| **Gem图标点击** | Tooltip弹出 "Coming Soon" |
| **强化按钮点击** | 弹出强化预览面板（点击前） |

### UI Performance Constraints

| Constraint | Value | Rationale |
|------------|-------|-----------|
| **Bounce动画节点数** | ≤ 5个同时运行 | 防止UI层级过重，保持流畅 |
| **面板弹出动画时长** | 0.3s | 快速但不突兀 |
| **字体大小** | 基准16px，数值显示18–24px | 数值清晰可读 |

## Acceptance Criteria

### Number Formatting

**AC-F1-01: Format Small Value**
**GIVEN** value = 500, **WHEN** `format_number(500)` is called, **THEN** result = "500".

**AC-F1-02: Format K Value (Exact)**
**GIVEN** value = 1000, **WHEN** `format_number(1000)` is called, **THEN** result = "1K" (not "1.0K").

**AC-F1-03: Format K Value (Decimal)**
**GIVEN** value = 1200, **WHEN** `format_number(1200)` is called, **THEN** result = "1.2K".

**AC-F1-04: Format M Value**
**GIVEN** value = 3600000, **WHEN** `format_number(3600000)` is called, **THEN** result = "3.6M".

**AC-F1-05: Format Zero**
**GIVEN** value = 0, **WHEN** `format_number(0)` is called, **THEN** result = "0".

### Animation Classification

**AC-F2-01: Small Change Classification**
**GIVEN** change = 30, **WHEN** animation magnitude classified, **THEN** magnitude = "small", duration = 0.2s.

**AC-F2-02: Medium Change Classification**
**GIVEN** change = 200, **WHEN** animation magnitude classified, **THEN** magnitude = "medium", duration = 0.4s.

**AC-F2-03: Large Change Classification**
**GIVEN** change = 800, **WHEN** animation magnitude classified, **THEN** magnitude = "large", duration = 0.6s.

### Bounce Animation

**AC-R3-01: Bounce Scale Applied**
**GIVEN** medium change (200), **WHEN** bounce animation triggered, **THEN** label scale reaches 1.15x peak then returns to 1.0x.

**AC-R3-02: Bounce Curve Correct**
**GIVEN** any bounce animation, **WHEN** tween executed, **THEN** curve = ease_out_back (Godot TRANS_BACK + EASE_OUT).

**AC-R3-03: Fly-Up Animation**
**GIVEN** large change (800), **WHEN** animation triggered, **THEN** label position shifts +20px vertical then returns.

### Equipment Display

**AC-R4-01: Display Equipment Stats**
**GIVEN** Iron Blade (+3), base_attack = 10, **WHEN** `display_equipment_stats("equip_weapon_iron_blade", 3)` called, **THEN** display shows "攻击力: 13 (+3)".

**AC-R4-02: Rarity Color Applied**
**GIVEN** Dragon Slayer (RARE), **WHEN** equipment name displayed, **THEN** text color = #9B7BB8 (Soft Lavender).

**AC-R4-03: Invalid Equipment ID**
**GIVEN** invalid equipment_id "invalid_xyz", **WHEN** `display_equipment_stats()` called, **THEN** display shows "Unknown Equipment" in COMMON color, warning logged.

### Enhancement Preview

**AC-F4-01: Attack Delta Calculation**
**GIVEN** Iron Blade, current_level = 3, new_level = 4, **WHEN** enhancement preview displayed, **THEN** attack shows "13 → 14 (+1)" with green increment.

**AC-F4-02: Zero Delta Display**
**GIVEN** current_level = new_level, **WHEN** enhancement preview displayed, **THEN** delta shows "无变化" in gray.

### Currency Display

**AC-R5-01: Gold Display Format**
**GIVEN** balance = 5200, **WHEN** HUD currency displayed, **THEN** Gold shows "5.2K" with icon.

**AC-R5-02: Currency Changed Signal**
**GIVEN** CurrencySystem emits `currency_changed("mat_currency_gold", 100, 5200)`, **WHEN** StatDisplaySystem receives signal, **THEN** HUD Gold label bounce animation triggered.

**AC-R5-03: Gem Dormant Display**
**GIVEN** balance = 0, **WHEN** Gem displayed, **THEN** shows "0" with grayed icon.

### Comparison Display

**AC-R6-01: Positive Comparison**
**GIVEN** old_value = 10, new_value = 15, **WHEN** `display_comparison()` called, **THEN** shows "10 → 15 (+5)" with green +5.

**AC-R6-02: Negative Comparison**
**GIVEN** old_value = 20, new_value = 15, **WHEN** `display_comparison()` called, **THEN** shows "20 → 15 (-5)" with red -5.

**AC-R6-03: Identical Comparison**
**GIVEN** old_value = new_value = 15, **WHEN** `display_comparison()` called, **THEN** shows "无差异" in gray.

### Edge Cases

**AC-EC-01: Animation Overlap Handling**
**GIVEN** previous bounce animation running, **WHEN** new change triggered, **THEN** previous tween cancelled, new animation started.

**AC-EC-02: Zero Change No Animation**
**GIVEN** change = 0, **WHEN** `display_currency_change()` called, **THEN** no animation triggered.

**AC-EC-03: Negative Format**
**GIVEN** value = -50, **WHEN** `format_number(-50)` called, **THEN** result = "-50".

### Integration

**AC-INT-01: ItemDatabase Color Query**
**GIVEN** rarity = EPIC, **WHEN** `get_rarity_color(EPIC)` called from ItemDatabase, **THEN** StatDisplaySystem receives #F27D16.

**AC-INT-02: Signal Subscription**
**GIVEN** StatDisplaySystem initialized, **WHEN** CurrencySystem connects, **THEN** `currency_changed` signal subscribed correctly.

## Open Questions

| # | Question | Owner | Target Resolution | Status |
|---|----------|-------|-------------------|--------|
| 1 | Should bounce animations use scale or also modulate size for stronger visual impact? | Technical Director | Before UI implementation | Open |
| 2 | Should large value changes (>1000) trigger screen shake in addition to fly-up animation? | Systems Designer + 视觉反馈系统设计 | Before Visual Feedback System design | Open |
| 3 | Should compact format support "B" format for billions, or keep M-only for simplicity? | Systems Designer | Before production (unlikely MVP range) | Open |
| 4 | Should equipment comparison show percentage change in addition to absolute delta (e.g., "+5 (+50%)")? | UX Designer | Before UI implementation | Open |
| 5 | Should enhancement preview panel include material cost display in addition to gold cost? | Systems Designer | Before 强化系统 design | Open |
| 6 | Should StatDisplaySystem emit signals for Visual Feedback System to hook into, or direct call? | Technical Director | During architecture review | Open |
| 7 | Should localization affect number format (e.g., 1.2K vs 1200 in different regions)? | Localization Lead | Before localization sprint | Open |
| 8 | Should rare/epic equipment names have additional glow effects beyond color coding? | Art Director | Before Visual Feedback System design | Open |

### Resolution Notes

- **Q4 Decision Framework**: Percentage change adds complexity for low base values (e.g., +3 from base 5 is +60%). Absolute delta is clearer for MVP. Consider percentage only for enhancement preview where base is meaningful.

- **Q6 Needs Coordination**: This must be resolved before 视觉反馈系统 design to establish the signal contract between systems.

- **Q8 Defer to Art**: Visual effects beyond color coding belong to 视觉反馈系统 scope, but StatDisplaySystem should provide rarity as signal trigger.