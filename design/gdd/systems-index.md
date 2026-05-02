# Systems Index: 爽刷地牢 (Idle Dungeon Clicker)

> **Status**: Draft
> **Created**: 2026-04-30
> **Last Updated**: 2026-04-30
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

本游戏是一款移动端放置RPG，核心循环是：手动点击推进地牢 → 自动战斗 → 获得装备掉落 → 强化装备(必定成功) → 数值暴涨视觉反馈 → 离线挂机积累收益。

需要24个系统（23个MVP + 1个Vertical Slice）。支柱"爽感反馈"要求视觉系统优先级高；支柱"稳定成长"要求强化/数值系统设计严谨；支柱"掌控节奏"允许跳过战斗；支柱"多元成长"为后续迭代预留扩展点。

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 存档系统 | Persistence | MVP | Approved | design/gdd/save-system.md | — |
| 2 | 物品数据库 | Economy | MVP | Approved | design/gdd/item-database.md | 存档系统 |
| 3 | 时间追踪系统 | Persistence | MVP | Approved | design/gdd/time-tracking-system.md | 存档系统 |
| 4 | 材料系统 | Economy | MVP | Approved | design/gdd/material-system.md | 存档系统, 物品数据库 |
| 5 | 货币系统 | Economy | MVP | Approved | design/gdd/currency-system.md | 存档系统 |
| 6 | 粒子系统 | Presentation | MVP | Approved | design/gdd/particle-system.md | — |
| 7 | 震动反馈系统 | Presentation | MVP | Approved | design/gdd/vibration-feedback-system.md | — |
| 8 | UI布局系统 | UI | MVP | Designed | design/gdd/ui-layout-system.md | — |
| 9 | 地牢结构系统 | Gameplay | MVP | Designed | design/gdd/dungeon-structure-system.md | 存档系统 |
| 10 | 敌人系统 | Gameplay | MVP | Designed | design/gdd/enemy-system.md | 物品数据库 |
| 11 | 战斗系统 | Gameplay | MVP | Designed | design/gdd/combat-system.md | 敌人系统, 物品数据库 |
| 12 | 装备槽系统 | Economy | MVP | Designed | design/gdd/equipment-slot-system.md | 物品数据库, 存档系统 |
| 13 | 强化公式系统 | Progression | MVP | Designed | design/gdd/enhancement-formula-system.md | 物品数据库 |
| 14 | 掉落表系统 | Economy | MVP | Designed | design/gdd/drop-table-system.md | 敌人系统, 物品数据库 |
| 15 | 收益计算系统 | Economy | MVP | Designed | design/gdd/yield-calculation-system.md | 战斗系统, 时间追踪系统 |
| 16 | 数值显示系统 | Presentation | MVP | Designed | design/gdd/stat-display-system.md | 物品数据库, 货币系统 |
| 17 | 触控输入系统 | UI | MVP | Designed | design/gdd/touch-input-system.md | UI布局系统 |
| 18 | 地牢推进系统 | Gameplay | MVP | Designed | design/gdd/dungeon-advancement-system.md | 地牢结构系统, 战斗系统, 敌人系统 |
| 19 | 装备掉落系统 | Economy | MVP | Designed | design/gdd/equipment-drop-system.md | 战斗系统, 掉落表系统, 物品数据库 |
| 20 | 装备强化系统 | Progression | MVP | Designed | design/gdd/equipment-enhancement-system.md | 装备槽系统, 材料系统, 货币系统, 强化公式系统 |
| 21 | 离线收益系统 | Persistence | MVP | Designed | design/gdd/offline-yield-system.md | 收益计算系统, 存档系统 |
| 22 | 视觉反馈系统 | Presentation | MVP | Designed | design/gdd/visual-feedback-system.md | 粒子系统, 数值显示系统, 震动反馈系统 |
| 23 | 音效系统 | Audio | Vertical Slice | Designed | design/gdd/audio-system.md | 战斗系统, 强化系统 |

---

## Categories

| Category | Description | Systems in This Game |
|----------|-------------|----------------------|
| **Persistence** | 存档和持续状态 | 存档系统, 时间追踪系统, 离线收益系统 |
| **Economy** | 物品、货币、掉落、收益计算 | 物品数据库, 材料系统, 货币系统, 装备槽系统, 掉落表系统, 收益计算系统, 装备掉落系统 |
| **Gameplay** | 核心玩法循环 | 地牢结构系统, 敌人系统, 战斗系统, 地牢推进系统 |
| **Progression** | 成长和强化 | 强化公式系统, 装备强化系统 |
| **Presentation** | 视觉反馈 | 粒子系统, 震动反馈系统, 数值显示系统, 视觉反馈系统 |
| **UI** | 用户界面和输入 | UI布局系统, 触控输入系统 |
| **Audio** | 音效和音乐 | 音效系统 |

---

## Priority Tiers

| Tier | Definition | Systems | Design Urgency |
|------|------------|---------|----------------|
| **MVP** | 核心循环必需，无则无法验证"有趣" | 23 | 设计 FIRST |
| **Vertical Slice** | 完整体验，后续迭代添加 | 1 (音效系统) | 设计 SECOND |

---

## Dependency Map

### Foundation Layer (无依赖)

1. **存档系统** — 所有进度持久化基础
2. **粒子系统** — 视觉反馈基础，独立于游戏逻辑
3. **震动反馈系统** — 视觉反馈基础，独立于游戏逻辑
4. **UI布局系统** — UI锚点和屏幕适配基础

### Core Layer (依赖 Foundation)

1. **物品数据库** — depends on: 存档系统
2. **时间追踪系统** — depends on: 存档系统
3. **材料系统** — depends on: 存档系统, 物品数据库
4. **货币系统** — depends on: 存档系统
5. **地牢结构系统** — depends on: 存档系统
6. **敌人系统** — depends on: 物品数据库
7. **装备槽系统** — depends on: 物品数据库, 存档系统
8. **强化公式系统** — depends on: 物品数据库
9. **数值显示系统** — depends on: 物品数据库, 货币系统
10. **触控输入系统** — depends on: UI布局系统

### Feature Layer (依赖 Core)

1. **战斗系统** — depends on: 敌人系统, 物品数据库
2. **掉落表系统** — depends on: 敌人系统, 物品数据库
3. **收益计算系统** — depends on: 战斗系统, 时间追踪系统
4. **地牢推进系统** — depends on: 地牢结构系统, 战斗系统, 敌人系统
5. **装备掉落系统** — depends on: 战斗系统, 掉落表系统, 物品数据库
6. **装备强化系统** — depends on: 装备槽系统, 材料系统, 货币系统, 强化公式系统
7. **离线收益系统** — depends on: 收益计算系统, 存档系统

### Presentation Layer (依赖 Feature)

1. **视觉反馈系统** — depends on: 粒子系统, 数值显示系统, 震动反馈系统

### Polish Layer (依赖全部)

1. **音效系统** — depends on: 战斗系统, 强化系统

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | 存档系统 | MVP | Foundation | systems-designer | M |
| 2 | 物品数据库 | MVP | Core | systems-designer | M |
| 3 | 时间追踪系统 | MVP | Core | systems-designer | S |
| 4 | 材料系统 | MVP | Core | systems-designer | S |
| 5 | 货币系统 | MVP | Core | systems-designer | S |
| 6 | 粒子系统 | MVP | Foundation | technical-artist + systems-designer | M |
| 7 | 震动反馈系统 | MVP | Foundation | systems-designer | S |
| 8 | UI布局系统 | MVP | Foundation | ux-designer | S |
| 9 | 地牢结构系统 | MVP | Core | level-designer + systems-designer | M |
| 10 | 敌人系统 | MVP | Core | systems-designer + ai-programmer | M |
| 11 | 战斗系统 | MVP | Feature | systems-designer + ai-programmer | L |
| 12 | 装备槽系统 | MVP | Core | systems-designer | S |
| 13 | 强化公式系统 | MVP | Core | systems-designer | S |
| 14 | 掉落表系统 | MVP | Core | systems-designer | S |
| 15 | 收益计算系统 | MVP | Core | systems-designer | S |
| 16 | 数值显示系统 | MVP | Core | systems-designer + ui-programmer | M |
| 17 | 触控输入系统 | MVP | Core | systems-designer | S |
| 18 | 地牢推进系统 | MVP | Feature | systems-designer + level-designer | M |
| 19 | 装备掉落系统 | MVP | Feature | systems-designer | M |
| 20 | 装备强化系统 | MVP | Feature | systems-designer | L |
| 21 | 离线收益系统 | MVP | Feature | systems-designer | M |
| 22 | 视觉反馈系统 | MVP | Presentation | systems-designer + technical-artist | M |
| 23 | 音效系统 | Vertical Slice | Polish | sound-designer + audio-director | M |

**Effort估算**: S=1session, M=2-3sessions, L=4+sessions

---

## Circular Dependencies

- **None found** ✓

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| **存档系统** | Technical | 移动端存档需要处理系统时间修改、存档损坏等边缘情况 | 早期原型验证存档持久化方案 |
| **物品数据库** | Scope | 装备定义需要足够丰富但不超出MVP时间预算 | MVP阶段简化装备种类(5-10种) |
| **战斗系统** | Design | 自动战斗的"跳过"机制需要平衡：跳过太快无聊，不跳过太慢 | 原型验证跳过节奏和视觉反馈强度 |
| **视觉反馈系统** | Technical | 移动端粒子性能限制，过多粒子会卡顿 | 性能预算: 50-100 draw calls，粒子数量控制 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 24 |
| Design docs started | 24 |
| Design docs reviewed | 0 |
| Design docs approved | 7 |
| MVP systems designed | 23/23 ✓ |
| Vertical Slice systems designed | 1/1 ✓ |

---

## Next Steps

- [x] 系统枚举完成
- [x] 依赖关系映射完成
- [x] 优先级分配完成
- [ ] 设计第一个系统: `/design-system 存档系统`
- [ ] 每个GDD完成后运行 `/design-review`
- [ ] MVP系统全部设计完成后运行 `/gate-check pre-production`
- [ ] 原型高风险系统: 存档系统、战斗系统