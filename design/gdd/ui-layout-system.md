# UI布局系统

> **Status**: Designed
> **Author**: [user + agents]
> **Last Updated**: 2026-05-01
> **Implements Pillar**: 爽感反馈、掌控节奏

## Overview

UI布局系统是游戏的屏幕适配和UI锚点基础设施，为所有HUD元素、菜单屏幕和触控交互提供统一的定位规则。它定义了锚点系统、安全区域处理、容器层级结构，确保游戏在不同尺寸的移动设备屏幕上（竖屏）保持一致的视觉呈现和可触控区域。

玩家每次点击、每次查看数值显示、每次进入菜单，都在与这个系统交互。虽然玩家不会意识到"锚点"或"安全区域"，但他们能感受到：按钮始终在预期位置、数值显示不会超出屏幕、横竖屏切换不会导致UI错位。这个系统让"点击哪里都能正确响应"成为可能。

**技术边界**：本GDD定义布局规则和行为规范。具体的Godot节点结构、锚点配置方式、容器实现模式属于架构决策，将在ADR中记录。

## Player Fantasy

玩家的手指每一次触碰屏幕都应该得到即时、准确的响应。UI布局让交互变得自然：按钮大小适合手指、位置符合直觉、没有任何"找不到按钮"的困惑。玩家感受到的是"我想做什么，就能做什么"的流畅掌控感，而非与界面斗争的挫败感。

这种掌控感服务于游戏支柱"掌控节奏" — 玩家可以选择快速跳过战斗或认真观看，无论哪种选择，UI都应该支持而非阻碍。圆润的造型和弹跳动画让每次点击都有愉悦的触感反馈，强化"爽感反馈"支柱。

## Detailed Design

### Core Rules

**1. Anchor System Rules**

| Rule ID | Rule | Specification |
|---------|------|---------------|
| ANCHOR-01 | HUD固定元素锚定屏幕边缘 | 顶部数值显示锚定 top-left/top-right；底部主操作按钮锚定 bottom-center |
| ANCHOR-02 | 弹出面板锚定屏幕中心 | 菜单、强化面板、掉落展示使用 center anchor，随屏幕比例自动居中 |
| ANCHOR-03 | 全屏背景使用 stretch | 背景图层覆盖整个屏幕，使用 left-top-right-bottom stretch |
| ANCHOR-04 | 动态元素使用相对定位 | 战斗区域内的敌人、掉落物相对于战斗容器定位，不锚定屏幕 |

**2. Safe Area Handling**

| Rule ID | Rule | Specification |
|---------|------|---------------|
| SAFE-01 | 使用 Godot 的 Safe Area API | 调用 `DisplayServer.get_safe_area()` 获取实际可用区域 |
| SAFE-02 | 顶部避开状态栏/刘海 | 顶部 44pt (iOS) / 48dp (Android) 预留为 safe area inset |
| SAFE-03 | 底部避开手势区域 | 底部 34pt (iOS Home indicator) / 48dp (Android navigation) 预留 |
| SAFE-04 | 侧边全屏使用 | 竖屏下左右侧边无特殊安全区域，可全屏使用 |

**3. Container Hierarchy**

```
CanvasLayer (UI Root)
├─ BackgroundLayer (z_index: -10)
│  └─ FullScreenBackground (stretch)
├─ GameplayLayer (z_index: 0)
│  ├─ DungeonView (center, 80% screen height)
│  └─ EnemySpawnArea (relative to DungeonView)
├─ HUDLayer (z_index: 10)
│  ├─ TopBar (top anchor, safe area aware)
│  │  ├─ CurrencyDisplay
│  │  ├─ SettingsButton
│  ├─ BottomBar (bottom anchor, safe area aware)
│  │  ├─ MainActionButton
│  │  ├─ QuickMenuButtons
├─ ModalLayer (z_index: 20)
│  ├─ MenuPanels (center anchor)
│  ├─ EnhancementPanel
│  ├─ DropDisplayPanel
├─ ToastLayer (z_index: 30)
│  ├─ NotificationPopups
│  ├─ NumberSplashEffects
```

**4. Screen Resolution Adaptation**

| Rule ID | Rule | Specification |
|---------|------|---------------|
| RES-01 | 设计基准分辨率 | 1080×1920 (9:16 竖屏比例) 作为设计基准 |
| RES-02 | 宽度适配策略 | 使用 `width-based scaling`：UI元素宽度按屏幕宽度比例缩放 |
| RES-03 | 高度适配策略 | 使用 `anchor + offset`：高度通过锚点定位，不依赖比例缩放 |
| RES-04 | 宽高比变化处理 | 9:16 → 9:19.5 (iPhone) 时，战斗区域高度增加，HUD保持边缘锚定 |
| RES-05 | 极端比例处理 | 如遇 9:20+ 超长屏，战斗区域不超出 85% 高度，底部留白给视觉舒适 |

### States and Transitions

UI布局系统本身无状态，但管理UI层级的显示/隐藏状态：

| Layer | Visible States | Hidden States | Transition Trigger |
|-------|---------------|---------------|-------------------|
| BackgroundLayer | Always | Never | — |
| GameplayLayer | 地牢探索、战斗进行 | 菜单全屏、强化面板全屏 | 进入/退出菜单 |
| HUDLayer | 地牢探索、战斗、掉落展示 | 菜单全屏、强化全屏 | 进入/退出菜单 |
| ModalLayer | 菜单打开、强化进行、掉落查看 | 地牢探索、战斗进行 | 用户点击菜单/强化按钮 |
| ToastLayer | 有通知时 | 无通知时 | 事件触发 |

**Modal Layer Priority** (多个面板同时请求显示时):
- DropDisplayPanel > EnhancementPanel > MenuPanels (掉落展示优先级最高，玩家必须看到)

### Interactions with Other Systems

| System | Data Flow | Interface Owner |
|--------|-----------|-----------------|
| **触控输入系统** | Touch events → 坐标映射 → UI元素响应 | 触控输入系统发送坐标，UI布局系统返回命中元素 |
| **数值显示系统** | 数值数据 → HUD TopBar 显示 | 数值显示系统调用 HUDLayer API 更新数值 |
| **粒子系统** | ToastLayer 定位 → 粒子效果锚定 | 粒子系统查询 ToastLayer 当前锚点位置 |
| **震动反馈系统** | Touch event → 触发震动 | 震动反馈系统监听 TouchLayer 点击事件 |
| **视觉反馈系统** | NumberSplash → ToastLayer 定位 | 视觉反馈系统调用 ToastLayer 定位 API |

**接口规范** (定义给下游系统使用):
- `get_hud_top_bar_safe_rect() → Rect2` 返回顶部安全区域的矩形
- `get_hud_bottom_bar_safe_rect() → Rect2` 返回底部安全区域的矩形
- `get_modal_center_position() → Vector2` 返回模态面板应居中的位置
- `get_gameplay_area_rect() → Rect2` 返回战斗/地牢显示区域
- `show_modal(panel_id: String) → void` 显示指定模态面板
- `hide_modal(panel_id: String) → void` 隐藏指定模态面板

## Formulas

**1. Safe Area Offset Calculation**

`safe_area_top_offset = DisplayServer.get_safe_area().position.y`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| safe_area_top_offset | `sa_top` | float | 0–100 px | 顶部安全区域偏移（状态栏/刘海） |

**Output Range:** 0 (无刘海设备) to ~100px (大刘海设备)
**Example:** iPhone 14 Pro: `sa_top = 59px` (Dynamic Island)

---

**2. Safe Area Bottom Offset**

`safe_area_bottom_offset = screen_height - DisplayServer.get_safe_area().end.y`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| screen_height | `sh` | float | 1920–2532 px | 屏幕实际高度 |
| safe_area_bottom_offset | `sa_bot` | float | 0–50 px | 底部安全区域偏移（Home指示条） |

**Output Range:** 0 (无手势条设备) to ~34px (iPhone Home indicator)
**Example:** iPhone 14: `sa_bot = 34px`

---

**3. Width-Based UI Scaling**

`ui_scale_factor = screen_width / design_base_width`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| screen_width | `sw` | float | 1080–1440 px | 屏幕实际宽度 |
| design_base_width | `dbw` | float | 1080 px | 设计基准宽度（常量） |
| ui_scale_factor | `scale` | float | 1.0–1.33 | UI元素缩放比例 |

**Output Range:** 1.0 (基准1080p) to ~1.33 (1440p宽屏手机)
**Example:** 1440px宽度设备: `scale = 1440 / 1080 = 1.333`

---

**4. Gameplay Area Height Calculation**

`gameplay_area_height = min(screen_height - sa_top - sa_bot, screen_height * max_gameplay_ratio)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| screen_height | `sh` | float | 1920–2532 px | 屏幕高度 |
| sa_top | — | float | 0–100 px | 顶部安全区偏移 |
| sa_bot | — | float | 0–50 px | 底部安全区偏移 |
| max_gameplay_ratio | `max_ratio` | float | 0.85 | 战斗区域最大占比（常量） |
| gameplay_area_height | `gah` | float | 1400–2200 px | 战斗显示区域高度 |

**Output Range:** 正常比例设备约 80% 屏幕高度；超长屏设备限制在 85%
**Example:** iPhone 14 Pro Max (2796×1290 portrait):
- `sh = 2796`, `sa_top = 59`, `sa_bot = 34`
- `gah = min(2796 - 59 - 34, 2796 * 0.85) = min(2703, 2367) = 2367px`

---

**5. Touch Target Size Validation**

`effective_touch_size = element_size * ui_scale_factor`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| element_size | `es` | float | 设计尺寸 px | 元素在设计分辨率下的尺寸 |
| ui_scale_factor | `scale` | float | 1.0–1.33 | UI缩放比例 |
| effective_touch_size | `ets` | float | 实际尺寸 px | 元素在当前屏幕上的实际尺寸 |

**Validation Rule:** `ets >= min_touch_target` (44pt iOS / 48dp Android)
**Example:** 按钮 `es = 100px`, `scale = 1.0` → `ets = 100px` ✓ (满足最小要求)

## Edge Cases

**1. Screen Resolution Edge Cases**

- **If screen_width < design_base_width (如 720p 低端设备)**: `ui_scale_factor < 1.0`，元素缩小但保持最小触摸尺寸。强制 `ets >= min_touch_target`，若不足则扩大元素实际渲染尺寸。
- **If screen ratio > 9:20 (超长屏如 Samsung Fold)**: 战斗区域高度限制在 85%，剩余空间显示渐变背景或装饰元素，不留纯黑区域。
- **If screen ratio < 9:16 (宽屏如平板横屏)**: 游戏强制竖屏，此情况不应出现。若检测到横屏，显示"请旋转手机至竖屏"提示。

**2. Safe Area Edge Cases**

- **If DisplayServer.get_safe_area() 返回全屏 (无刘海设备)**: `sa_top = 0`, `sa_bot = 0`，正常布局无偏移。
- **If safe_area 数据异常 (API返回空或负值)**: fallback 使用预设值 `sa_top = 44`, `sa_bot = 34`，保证基础安全。

**3. Modal Layer Edge Cases**

- **If 多个 Modal 同时请求显示**: 按优先级 DropDisplayPanel > EnhancementPanel > MenuPanels 排序，高优先级覆盖低优先级，低优先级进入等待队列。
- **If Modal 显示时用户点击 HUD 按钮**: HUD 按钮 ignore input（`mouse_filter = MOUSE_FILTER_IGNORE`），只有 Modal 内按钮可响应。
- **If Modal 关闭时有等待队列中的面板**: 自动弹出队列首个面板，动画过渡 0.3s fade-in。

**4. Touch Target Edge Cases**

- **If 设计元素尺寸 < min_touch_target / ui_scale_factor**: 强制扩大渲染尺寸至满足最小触摸要求，但视觉设计尺寸不变（外观可能略大于设计稿）。
- **If 两个相邻按钮间距 < 8px**: 自动调整间距至 8px，防止误触。若空间不足，缩小按钮尺寸但不低于触摸最小值。

**5. Layer Visibility Edge Cases**

- **If GameplayLayer 应隐藏但仍有粒子效果在播放**: 粒子效果继续播放完毕，不强制中断（视觉反馈完整性）。
- **If ToastLayer 已有 5 个通知堆叠**: 新通知覆盖旧通知，旧通知 fade-out 0.2s 后移除。最多同时显示 3 个通知。

## Dependencies

**Upstream Dependencies (本系统依赖)**

| System | Type | Interface | Notes |
|--------|------|-----------|-------|
| None | — | — | Foundation layer，无上游依赖 |

UI布局系统是 Foundation 层，不依赖其他游戏系统。仅依赖 Godot Engine 的 `DisplayServer` API。

**Downstream Dependencies (依赖本系统)**

| System | Type | Interface Used | Notes |
|--------|------|---------------|-------|
| **触控输入系统** | Hard | `get_hud_top_bar_safe_rect()`, `get_hud_bottom_bar_safe_rect()` | 触控需要知道安全区域来正确映射点击坐标 |
| **数值显示系统** | Hard | `get_hud_top_bar_safe_rect()` | 数值显示定位在 TopBar 区域 |
| **粒子系统** | Soft | `get_modal_center_position()`, `get_gameplay_area_rect()` | 粒子效果锚定到特定区域 |
| **震动反馈系统** | Soft | — | 无直接接口依赖，通过触控间接关联 |
| **视觉反馈系统** | Hard | `get_gameplay_area_rect()`, ToastLayer 定位 | 数值飞溅效果定位 |
| **战斗系统** | Soft | `get_gameplay_area_rect()` | 战斗动画在战斗区域内渲染 |
| **地牢推进系统** | Soft | `get_gameplay_area_rect()` | 地牢视图在战斗区域内 |
| **装备掉落系统** | Hard | `show_modal("DropDisplayPanel")` | 掉落展示需要 ModalLayer |
| **装备强化系统** | Hard | `show_modal("EnhancementPanel")` | 强化面板需要 ModalLayer |

**External Dependencies (非游戏系统)**

| Dependency | Type | Usage |
|------------|------|-------|
| **Godot DisplayServer API** | Hard | 获取屏幕尺寸、安全区域、分辨率 |
| **Godot CanvasLayer** | Hard | UI层级管理的基础节点 |
| **Godot Control anchors** | Hard | 锚点定位系统 |

## Tuning Knobs

| Knob | Default | Safe Range | Unit | What It Affects | Extreme Behavior |
|------|---------|------------|------|-----------------|------------------|
| **design_base_width** | 1080 | 720–1440 | px | 所有 UI 元素缩放基准 | 太低：元素过大，粗糙；太高：元素过小，可能低于触摸最小值 |
| **max_gameplay_ratio** | 0.85 | 0.70–0.90 | ratio | 战斗区域最大高度占比 | 太低：战斗区域太小，视觉压抑；太高：HUD 太窄，信息拥挤 |
| **min_touch_target_ios** | 44 | 44–60 | pt | iOS 最小触摸尺寸 | 低于 44：违反 Apple HIG，可能审核拒绝 |
| **min_touch_target_android** | 48 | 48–64 | dp | Android 最小触摸尺寸 | 低于 48：违反 Material Design，误触率高 |
| **modal_animation_duration** | 0.3 | 0.15–0.5 | seconds | Modal 面板动画时长 | 太短：动画不明显，体验突兀；太长：响应慢，打断心流 |
| **toast_stack_limit** | 3 | 2–5 | count | 同时显示的通知数量上限 | 太少：信息显示不及时；太多：屏幕拥挤，干扰游戏 |
| **button_min_spacing** | 8 | 4–16 | px | 相邻按钮最小间距 | 太小：误触率高；太大：按钮分布稀疏，空间浪费 |
| **hud_top_bar_height** | 120 | 80–160 | px | 顶部 HUD 区域高度 | 太低：数值显示拥挤；太高：战斗区域被压缩 |
| **hud_bottom_bar_height** | 140 | 100–180 | px | 底部 HUD 区域高度 | 太低：主按钮太小；太高：战斗区域被压缩 |

## Visual/Audio Requirements

**Visual Requirements**

| Requirement | Specification | Alignment |
|-------------|---------------|-----------|
| **圆润造型** | 所有 UI 元素使用圆角：按钮 `corner_radius >= 12px`，面板 `corner_radius >= 16px` | 对齐 Art Bible Section 2 |
| **饱和色彩** | HUD 背景使用半透明深色 (`#333333` alpha 0.8)，按钮使用明亮暖色（金色 `#FFD700`，橙色 `#FF8C00`） | 对齐 Art Bible Section 3 |
| **弹跳动画** | Modal 面板打开使用 `bounce` easing（`Tween.EASE_OUT` + `Tween.TRANS_BACK`），入场动画有轻微 overshoot | 对齐 Art Bible Section 4 |
| **层级视觉区分** | 每层使用不同 opacity：Background 100%，Gameplay 100%，HUD 90%，Modal 95%，Toast 100% | 确保层级可读性 |
| **安全区域渐变** | 超长屏底部留白使用渐变填充（暖灰 `#F5F5F5` → 白色 `#FFFFFF`），不使用纯黑 | 避免视觉突兀 |

**Audio Requirements**

| Requirement | Specification | Notes |
|-------------|---------------|-------|
| None | UI布局系统是纯视觉基础设施，不产生音效 | 音效由触控输入系统、视觉反馈系统负责 |

## UI Requirements

| Requirement | Specification | Priority |
|-------------|---------------|----------|
| **系统无自有UI** | UI布局系统是基础设施，不直接向玩家展示任何界面 | — |
| **调试可视化工具** | 开发阶段提供 `UILayoutDebugOverlay` 显示：safe area 边界、anchor 点位置、layer 边界框 | Dev-only |
| **配置面板预留** | 为后续迭代预留"UI布局调试"开发者选项：显示/隐藏层级边界、测试不同分辨率模拟 | Post-MVP |

**下游系统 UI 约束** (由本系统定义，其他系统遵守):
- 所有 HUD 元素必须使用本系统提供的 `get_hud_*_rect()` 定位
- 所有 Modal 必须通过 `show_modal()` / `hide_modal()` 管理，不自行控制可见性
- 所有 Toast 必须添加到 ToastLayer，不创建独立 CanvasLayer

## Acceptance Criteria

**Screen Adaptation Criteria**

- **GIVEN** 设备屏幕宽度 1080px，**WHEN** 游戏启动，**THEN** `ui_scale_factor = 1.0` 且所有 UI 元素尺寸等于设计尺寸。
- **GIVEN** 设备屏幕宽度 720px (低端设备)，**WHEN** 游戏启动，**THEN** UI 元素缩放至 0.67 倍，但所有按钮 `effective_touch_size >= 44pt`。
- **GIVEN** iPhone 14 Pro Max (2796×1290 portrait)，**WHEN** 游戏启动，**THEN** `safe_area_top_offset = 59px`, `safe_area_bottom_offset = 34px`，HUD 正确避开刘海和手势区域。

**Safe Area Criteria**

- **GIVEN** 设备无刘海 (如 iPhone SE)，**WHEN** 获取 safe area，**THEN** `sa_top = 0`, `sa_bot = 0`，HUD 贴边显示。
- **GIVEN** safe_area API 返回异常值 (负数或空)，**WHEN** 初始化布局，**THEN** fallback 使用 `sa_top = 44`, `sa_bot = 34`，布局不崩溃。

**Anchor System Criteria**

- **GIVEN** 用户点击主操作按钮，**WHEN** 按钮锚定 bottom-center，**THEN** 按钮始终在屏幕底部水平居中，不受屏幕比例影响。
- **GIVEN** 强化面板打开，**WHEN** 面板锚定 center，**THEN** 面板在屏幕正中央，四周边距相等。

**Modal Layer Criteria**

- **GIVEN** 装备掉落发生，**WHEN** DropDisplayPanel 请求显示，**THEN** `show_modal("DropDisplayPanel")` 成功，ModalLayer 显示掉落面板，HUDLayer 输入被阻断。
- **GIVEN** DropDisplayPanel 已显示且强化面板请求显示，**WHEN** 处理优先级，**THEN** 强化面板进入等待队列，掉落面板关闭后自动弹出。

**Touch Target Criteria**

- **GIVEN** 设计按钮尺寸 100px，**WHEN** ui_scale_factor = 1.0，**THEN** `effective_touch_size = 100px >= 44pt` ✓。
- **GIVEN** 设计按钮尺寸 60px，ui_scale_factor = 0.67，**WHEN** 计算有效尺寸，**THEN** `ets = 40px < 44pt`，强制扩大渲染尺寸至 66px以满足触摸最小值。

**Layer Visibility Criteria**

- **GIVEN** 菜单面板打开，**WHEN** 用户点击 HUD 按钮，**THEN** HUD 按钮 `mouse_filter = MOUSE_FILTER_IGNORE`，点击穿透到 ModalLayer，HUD 按钮无响应。

## Open Questions

| Question | Owner | Target Resolution | Status |
|----------|-------|-------------------|--------|
| **是否需要横屏适配？** | Game Designer | MVP 后评估 | Open — MVP 阶段强制竖屏 |
| **动态岛 (Dynamic Island) 处理方式？** | UI Programmer | Godot 4.6 实现验证时 | Open — 需真机测试 safe_area API |
| **低端设备 (720p) 是否降低粒子数量？** | Technical Artist | 原型验证时 | Open — 性能预算相关 |
| **Foldable 设备 (如 Samsung Fold) 是否特殊处理？** | Game Designer | Post-MVP 评估 | Open — MVP 不支持 |