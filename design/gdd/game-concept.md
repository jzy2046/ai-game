# Game Concept: 爽刷地牢 (Idle Dungeon Clicker)

*Created: 2026-04-30*
*Status: Draft*

---

## Elevator Pitch

> 一款移动端放置RPG，玩家手动推进地牢获取装备，自动战斗但掌控节奏，装备强化必定成功带来稳定成长，离线时自动刷材料积累收益。
>
> Like simplified Diablo, AND ALSO 放置收益系统 + 必定成功强化 + 明亮卡通视觉反馈。

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Idle RPG + Dungeon Crawler + Incremental |
| **Platform** | Mobile (iOS / Android) |
| **Target Audience** | Achievers who enjoy steady progression without stress |
| **Player Count** | Single-player |
| **Session Length** | 5-30 minutes (bite-sized, fits mobile habits) |
| **Monetization** | None (MVP) — potential ad-reward or IAP later |
| **Estimated Scope** | Small (2 weeks MVP, solo) |
| **Comparable Titles** | Clicker Heroes, Idle Slayer, 梦幻西游手游 |

---

## Core Fantasy

每次推进地牢都是一次期待 — 不知道会掉落什么装备，不知道强化后数值会涨多少。爽感来自于"变强"的可视化：数字飞溅、粒子爆发、屏幕震动。玩家是成长的主人，无需担心失败，只需要享受稳定的进步。

这是一个让玩家感到"我今天比昨天更强"的游戏。不需要紧张操作，不需要担心失败，只需要点击推进、观看战斗、收集装备、强化数值、设置挂机任务，然后离开时知道明天回来会更强。

---

## Unique Hook

**必定成功强化 + 视觉爽感反馈**

不同于暗黑破坏神的成功率机制，这里的强化永远成功。爽感来自于视觉反馈：强化成功时数字暴涨飞溅、屏幕震动、粒子爆发，而不是"终于成功了"的紧张释放。

**And Also**: 离线挂机有目标 — 离开前指定挂机任务（如"刷第一层地牢积累材料"），回来时有明确的"收菜"奖励。

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 1 (Primary) | 数值暴涨的视觉反馈：数字飞溅、粒子爆发、屏幕震动、bounce动画 |
| **Submission** (relaxation, comfort zone) | 2 (Primary) | 自动战斗、必定成功强化、离线收益 — 无需紧张操作 |
| **Fantasy** (make-believe, role-playing) | 3 (Supporting) | 角色成长、装备收集、地牢探索的英雄感 |
| **Discovery** (exploration, secrets) | 4 (Supporting) | 装备掉落的期待感、词缀组合的优化空间 |
| **Challenge** (obstacle course, mastery) | N/A | 不强调挑战，玩家可以跳过战斗 |
| **Narrative** (drama, story arc) | N/A | MVP阶段无叙事 |
| **Fellowship** (social connection) | N/A | 单机游戏 |
| **Expression** (self-expression, creativity) | N/A | MVP阶段无自定义 |

### Key Dynamics (Emergent player behaviors)

1. **"One more push"循环** — 玩家会想"再推进一层看看掉落"，然后"再强化一下装备"，然后"再推一层看看数值变化"
2. **挂机期待** — 玩家离开游戏时会设置挂机任务，回来时第一件事是检查"收菜"收益
3. **装备切换尝试** — 玩家会尝试不同装备，比较强化后的数值差异
4. **节奏选择** — 有些玩家会认真观看战斗动画，有些玩家会快速跳过推进更快层级

### Core Mechanics (Systems we build)

1. **手动地牢推进 + 自动战斗** — 点击进入下一个房间，战斗自动进行，可点击跳过或释放大招加速
2. **装备掉落 + 强化系统** — 地牢掉落装备，材料积累后强化装备（必定成功），数值线性增长
3. **视觉反馈系统** — 强化成功、数值变化、掉落获得都伴随粒子、震动、飞溅动画
4. **离线收益系统** — 记录离开时间，回来时计算离线期间自动刷第一层地牢的材料收益

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | 玩家可以决定推进速度、跳过战斗、选择装备强化优先级 | Supporting |
| **Competence** (mastery, skill growth) | 每次强化都带来可见的数值增长，玩家感受持续的进步 | Core |
| **Relatedness** (connection, belonging) | 无社交元素 | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — How: 数值增长、装备收集、地牢层级推进的成就感
- [ ] **Explorers** (discovery, understanding systems, secrets) — How: MVP阶段探索元素较弱
- [ ] **Socializers** (relationships, cooperation, community) — How: 无社交
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — How: 无竞争

### Flow State Design

- **Onboarding curve**: 第一次点击推进 → 自动战斗发生 → 获得第一件装备 → 第一次强化 → 看到数值暴涨的视觉反馈。整个过程在30秒内完成，玩家立即理解核心循环。
- **Difficulty scaling**: 地牢层级越高，敌人越强，需要更高数值的装备才能推进。但因为是自动战斗，"难度"体现为"需要更强的装备"，而不是"需要更熟练的操作"。
- **Feedback clarity**: 所有进步都有清晰的视觉反馈：数值变化、粒子效果、屏幕震动。
- **Recovery from failure**: 无失败机制（必定成功强化），玩家永远在前进。

---

## Core Loop

### Moment-to-Moment (30 seconds)

点击推进 → 自动战斗开始（可跳过） → 战斗结束显示掉落 → 点击返回或继续推进

核心爽感点：
- 推进时的点击反馈
- 战斗胜利时的掉落展示（装备图标弹出）
- 点击装备时的属性预览

### Short-Term (5-15 minutes)

完成一个地牢区域（5-10个房间） → 返回主界面强化装备 → 数值暴涨的视觉反馈 → 再次进入地牢，推进更快层级

"One more layer"循环在这里发生：玩家刚强化完装备，会想"试试能不能推更深层"，然后推了一层又想"再强化一下看看"。

### Session-Level (30-60 minutes)

推进多个地牢层级 → 强化装备多次 → 设置离线挂机任务（刷第一层积累材料） → 离开游戏，期待明天回来时的收益

玩家离开时应该有满足感：今天进步明显，明天回来会更强。

### Long-Term Progression

- 地牢层级上升：第一层 → 第二层 → ... → 最终层
- 装备品质提升：普通 → 稀有 → 史诗 → 传说（MVP可能简化为1-2级）
- 数值增长：攻击力、防御力、生命值等持续上升
- 挂机收益增加：更高层级的地牢提供更好的材料（后续迭代）

### Retention Hooks

- **Curiosity**: 下一个层级有什么敌人？下一件装备是什么？
- **Investment**: 已经强化的装备数值不想放弃，想看看最终能推到哪里
- **Social**: 无社交元素（MVP）
- **Mastery**: 优化装备强化顺序、选择最佳挂机任务

---

## Game Pillars

### Pillar 1: 爽感反馈

每次玩家操作都伴随强烈的视觉/数字反馈，让"变强"成为可感知的体验。强化成功时屏幕震动、数字飞溅、粒子爆发。

*Design test*: 如果我们选择在强化成功时添加一个简单的提示还是添加震动+粒子效果，这个支柱说：选择后者。

### Pillar 2: 稳定成长

所有进步都是可预期的，没有失败风险，玩家永远在前进。装备强化必定成功，地牢推进只需要数值足够。

*Design test*: 如果我们选择添加成功率机制还是必定成功机制，这个支柱说：选择必定成功。

### Pillar 3: 掌控节奏

玩家可以选择参与程度：手动推进有掌控感，跳过战斗有放松感。两者都是正确的玩法。

*Design test*: 如果我们选择强制观看战斗动画还是允许跳过，这个支柱说：选择允许跳过。

### Pillar 4: 多元成长

装备、属性等多条成长线让玩家有多种选择和优化空间。（MVP阶段只有装备强化，后续迭代扩展）

*Design test*: 如果我们选择只有一件装备还是多装备切换，这个支柱说：选择多装备切换。

### Anti-Pillars (What This Game Is NOT)

- **NOT 成功率机制**: 会引入挫败感，违反"稳定成长"支柱
- **NOT 复杂操作**: 会破坏"放松与心流"的目标体验
- **NOT PVP或竞争元素**: 会引入焦虑，违反"掌控节奏"支柱
- **NOT 限时活动**: 会破坏"玩家可以随时离开"的放置本质

---

## Visual Identity Anchor

**Selected Direction**: 明亮卡通

**One-line Visual Rule**: 所有反馈必须"跳"起来 — 数值飞升、粒子跳动、屏幕轻微晃动，爽感是动态的。

**Supporting Visual Principles**:

| Principle | Definition | Design Test |
| ---- | ---- | ---- |
| **饱和色彩** | 不灰暗，强化成功时有金色/橙色爆发 | 选择颜色时优先饱和色而非灰暗色 |
| **圆润造型** | UI元素、角色、装备图标都是圆润的 | 选择UI形状时优先圆角而非尖锐边角 |
| **弹跳动画** | 所有数值变化都有bounce效果 | 数值跳变时添加弹性动画而非冷冰冰的数字跳变 |

**Color Philosophy**:
- 主色调：明亮暖色（金色、橙色）传达进步和温暖
- 强调色：紫色/蓝色用于稀有装备，创造对比
- 背景：柔和的暖灰或浅蓝，不干扰前景元素

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| **暗黑破坏神** | 装备刷取、数值暴涨、强化爽感 | 必定成功强化 + 明亮卡通风格而非哥特 | 证明了数值成长的核心吸引力 |
| **梦幻西游手游** | 挂机收益、稳定成长、多系统 | 简化系统、手动推进而非纯自动 | 证明了"必定成功"的市场可行性 |
| **Clicker Heroes** | 放置收益、数值驱动 | 地牢推进 + 装备收集而非纯点击 | 证明了"数值暴涨"是足够的吸引力 |
| **Idle Slayer** | 自动战斗 + 手动推进结合 | 明亮卡通风格而非像素暗黑 | 证明了自动战斗+手动推进的组合可行 |

**Non-game inspirations**: 
- 手机通知的"小红点"心理 — 玩家回来时看到挂机收益的心理满足
- 抽卡游戏的"出货"动画 — 强化成功时的视觉爆发感

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18-35 |
| **Gaming experience** | Mid-core — 玩过一些游戏但不追求硬核挑战 |
| **Time availability** | 碎片化时间 — 通勤、午休、睡前5-30分钟 |
| **Platform preference** | Mobile (手机为主) |
| **Current games they play** | 梦幻西游手游、放置类游戏、消消乐等休闲游戏 |
| **What they're looking for** | 稳定的进步感，不需要紧张操作，可以随时离开 |
| **What would turn them away** | 失败率机制、复杂操作、限时活动、需要长时间在线 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.x — 免费、开源、支持移动端导出、适合2D游戏 |
| **Key Technical Challenges** | 移动端导出配置、离线收益计算持久化、视觉反馈性能优化 |
| **Art Style** | 2D明亮卡通风格 |
| **Art Pipeline Complexity** | Low (MVP阶段使用简单图形或免费素材) |
| **Audio Needs** | Minimal (MVP阶段可暂时无声效，后续迭代添加) |
| **Networking** | None (单机) |
| **Content Volume** | MVP: 1个地牢(多层)、5-10件装备、强化系统、离线收益 |
| **Procedural Systems** | 无随机生成(MVP)，后续迭代可能添加随机词缀 |

---

## Risks and Open Questions

### Design Risks

- **视觉反馈可能不够爽**: MVP阶段的粒子/动画可能不够丰富，需要迭代优化
- **核心循环可能过快单调**: 30秒循环如果不够有趣，玩家可能很快流失
- **装备系统可能不够有吸引力**: 简化版可能缺乏收集动力

### Technical Risks

- **移动端导出配置复杂**: iOS需要Xcode，Android需要SDK，可能超出时间预算
- **视觉反馈性能**: 移动端可能有性能限制，粒子数量需要控制
- **离线收益持久化**: 需要正确处理玩家修改系统时间等边缘情况

### Market Risks

- **放置类市场竞争激烈**: Clicker Heroes、Idle Slayer等已有成熟产品
- **目标受众可能太小**: 只喜欢必定成功+放松的玩家可能不够多

### Scope Risks

- **2周可能不够**: MVP功能虽简化，但移动端导出和视觉反馈可能超出预期
- **视觉反馈时间预算**: 粒子系统和动画可能需要更多调试时间

### Open Questions

- **强化时的视觉反馈具体是什么样的?**: 需要原型验证 — 具体的粒子效果、震动幅度、动画时长
- **离线收益的计算方式**: 简化为"时间×基础收益率"还是需要模拟战斗? 需要原型验证
- **装备掉落表的深度**: MVP需要多少种装备? 词缀系统是否需要?

---

## MVP Definition

**Core hypothesis**: 玩家在2周内会觉得手动推进+自动战斗+必定成功强化+视觉反馈的核心循环足够有趣，愿意多次返回游戏。

**Required for MVP**:
1. 地牢推进系统：手动点击推进，自动战斗，可跳过
2. 装备掉落系统：地牢掉落装备，多装备切换
3. 装备强化系统：材料积累，必定成功强化，数值增长
4. 视觉反馈系统：强化成功时的粒子、震动、数字飞溅
5. 离线收益系统：记录离开时间，回来时计算材料收益
6. 移动端适配：UI锚点、基本屏幕适配

**Explicitly NOT in MVP** (defer to later):
- 属性系统（力量、敏捷等）
- 技能系统
- 装备词缀（随机属性）
- 音效系统
- 多地牢区域
- 随机地牢生成
- 详细动画（角色、敌人）

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 1个地牢(多层)、5-10件装备 | 核心循环 + 强化 + 离线收益 | 2 weeks |
| **Vertical Slice** | 1个完整地牢区域 | MVP + 音效 + 更丰富视觉反馈 | 4 weeks |
| **Alpha** | 2-3个地牢区域 | VS + 属性系统 + 技能系统基础 | 8 weeks |
| **Full Vision** | 多地牢、完整系统 | Alpha + 装备词缀 + 多系统联动 | 12+ weeks |

---

## Next Steps

1. [ ] Run `/setup-engine` — configure Godot engine and populate version-aware reference docs
2. [ ] Run `/art-bible` — establish visual identity before writing any GDDs
3. [ ] Run `/map-systems` — decompose concept into individual systems with dependencies
4. [ ] Run `/design-system [first-system]` — author per-system GDDs in dependency order
5. [ ] Run `/create-architecture` — produce the master architecture blueprint
6. [ ] Run `/architecture-decision (×N)` — record key technical decisions
7. [ ] Run `/gate-check pre-production` — validate readiness before committing to production
8. [ ] Run `/prototype core-loop` — validate core hypothesis in 2 weeks
9. [ ] Run `/playtest-report` — document prototype results
10. [ ] If validated, run `/sprint-plan new` — plan first production sprint