# 项目进度报告 — 爽刷地牢 (Idle Dungeon Clicker)

*最后更新: 2026-04-30*

---

## 项目概况

| 属性 | 值 |
|-----|-----|
| **项目名称** | 爽刷地牢 (Idle Dungeon Clicker) |
| **游戏类型** | Idle RPG + Dungeon Crawler + Incremental |
| **目标平台** | Mobile (iOS / Android) |
| **引擎** | Godot 4.6 |
| **语言** | GDScript |
| **开发周期** | MVP 2周 (后续迭代扩展) |
| **团队规模** | Solo (单人开发) |
| **评审模式** | Solo (无评审) |

---

## 电梯简报

一款移动端放置RPG，玩家手动推进地牢获取装备，自动战斗但掌控节奏，装备强化必定成功带来稳定成长，离线时自动刷材料积累收益。

**核心卖点**: 必定成功强化 + 视觉爽感反馈 + 明亮卡通风格

---

## 已完成工作

### Session 1 (2026-04-30)

| 步骤 | 技能 | 状态 | 输出文件 |
|-----|------|------|----------|
| 入门引导 | `/start` | ✓ 完成 | `production/review-mode.txt` |
| 游戏概念开发 | `/brainstorm idle-rpg` | ✓ 完成 | `design/gdd/game-concept.md` |
| 引擎配置 | `/setup-engine` | ✓ 完成 | `CLAUDE.md`, `.claude/docs/technical-preferences.md` |

---

## 已创建文件

```
D:\code\my-game\
├── CLAUDE.md                              # Technology Stack已更新 (Godot 4.6 + GDScript)
├── production/
│   └── review-mode.txt                    # Solo模式配置
├── design/
│   └── gdd/
│       └── game-concept.md                # 完整游戏概念文档 (17 sections)
└── .claude/
    └── docs/
        └── technical-preferences.md       # 技术偏好完整配置
```

**引擎参考文档已存在** (预置):
```
docs/engine-reference/godot/
├── VERSION.md                             # Godot 4.6版本信息 + Knowledge Gap警告
```

---

## 游戏支柱 (Game Pillars)

| Pillar | 定义 |
|--------|------|
| **1. 爽感反馈** | 每次操作伴随强烈视觉/数字反馈，让"变强"可感知 |
| **2. 稳定成长** | 所有进步可预期，无失败风险，永远在前进 |
| **3. 掌控节奏** | 玩家可选择参与程度或放松观看 |
| **4. 多元成长** | 装备、属性等多条成长线，多种选择空间 |

**Anti-Pillars (明确不做)**:
- 不做成功率机制 (违反稳定成长)
- 不做复杂操作 (破坏放松体验)
- 不做PVP/竞争元素 (引入焦虑)
- 不做限时活动 (破坏放置本质)

---

## 视觉锚点

**方向**: 明亮卡通

**核心规则**: 所有反馈必须"跳"起来 — 数值飞升、粒子跳动、屏幕轻微晃动

**支撑原则**:
- 饱和色彩 (金色/橙色爆发)
- 圆润造型 (圆角UI、装备图标)
- 弹跳动画 (所有数值变化有bounce效果)

---

## MVP定义 (2周目标)

| 系统 | MVP范围 | 后续迭代 |
|-----|---------|----------|
| 地牢推进 | 手动点击推进，自动战斗，可跳过 | 随机地牢生成 |
| 装备掉落 | 简化掉落表，多装备切换 | 装备词缀系统 |
| 装备强化 | 必定成功，数值线性增长 | 属性系统、技能系统 |
| 视觉反馈 | 核心：粒子、震动、数字飞溅 | 更丰富动画、音效 |
| 离线收益 | 时间×基础收益率计算 | 指定挂机任务系统 |

**核心假设**: 手动推进+自动战斗+必定成功强化+视觉反馈的核心循环足够有趣

---

## 技术配置摘要

### Input & Platform
- Target Platforms: Mobile (iOS / Android)
- Primary Input: Touch
- Touch Support: Full

### Performance Budgets
- Target Framerate: 60 fps
- Frame Budget: 16.6 ms
- Draw Calls: 50-100 (mobile 2D)
- Memory Ceiling: 200 MB

### Naming Conventions (GDScript)
- Classes: `PascalCase`
- Variables/Functions: `snake_case`
- Signals: `snake_case` past tense
- Files: `snake_case.gd`
- Scenes: `PascalCase.tscn`
- Constants: `UPPER_SNAKE_CASE`

### Testing
- Framework: GUT (Godot Unit Test)
- Minimum Coverage: Core systems

---

## 知识风险警告

| 项目 | 说明 |
|-----|------|
| **引擎版本** | Godot 4.6 (January 2026) |
| **LLM训练截止** | May 2025 |
| **风险等级** | HIGH — 4.4, 4.5, 4.6 均超出训练数据 |
| **应对策略** | 使用 `docs/engine-reference/godot/` 中的参考文档验证API |

**关键变更** (详见 VERSION.md):
- 4.4: Jolt physics option, FileAccess return types
- 4.5: AccessKit, variadic args, @abstract
- 4.6: Jolt default, glow rework, D3D12 default on Windows

---

## 下一步计划

**下次Session按顺序执行**:

| 序号 | 命令 | 目的 | 预估时间 |
|-----|------|------|----------|
| 1 | `/art-bible` | 建立视觉身份规范 | 30-60 min |
| 2 | `/map-systems` | 分解概念为具体系统 | 20-30 min |
| 3 | `/design-system [first-system]` | 为每个系统写GDD | 每个系统30-60 min |
| 4 | `/create-architecture` | 产出架构蓝图 + ADR列表 | 30-60 min |
| 5 | `/architecture-decision (×N)` | 记录技术决策 | 每个ADR15-30 min |
| 6 | `/gate-check pre-production` | 验证生产准备度 | 10-20 min |
| 7 | `/prototype core-loop` | 验证核心假设 | 2周 |

---

## 参考游戏

| 游戏 | 学习点 |
|-----|--------|
| 暗黑破坏神 | 装备刷取、数值暴涨、强化爽感 |
| 梦幻西游手游 | 挂机收益、稳定成长、多系统 |
| Clicker Heroes | 放置收益、数值驱动 |
| Idle Slayer | 自动战斗+手动推进组合 |

---

## 如何继续

下次打开Claude Code时:
1. 进入项目目录 `D:\code\my-game`
2. 系统会自动检测进度并提示下一步
3. 或直接说: **"继续昨天的工作"**

---

*本文件由 `/start` → `/brainstorm` → `/setup-engine` 流程生成*
*下次更新在完成 `/art-bible` 或 `/map-systems` 后*