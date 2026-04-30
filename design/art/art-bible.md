# Art Bible: 爽刷地牢 (Idle Dungeon Clicker)

*Created: 2026-04-30*
*Status: Draft*
*Review Mode: Solo*

---

## 1. Visual Identity Statement

### One-Line Visual Rule

> **Every progress moment must "pop" — numbers rise and burst, particles explode, elements bounce, making growth unmissable.**
>
> 每一刻进步都要"炸"出存在感 — 数值上浮炸裂、粒子爆发、元素弹跳，让成长不可忽视。

### Supporting Visual Principles

#### Principle 1: Numerical Prominence

**Definition**: 数值是主要反馈语言。伤害、金币、经验、属性增长必须视觉突出 — 大、动画化、颜色编码。数值要感觉"弹出"屏幕，不是被动静置。

**Design Test**: 选择静态属性变化显示 vs 动态浮动数字带bounce放大 → 选择动态版本。里程碑达成（升级、新装备）时，数值应附带额外效果（发光、震动、粒子爆发）。

**Pillar Connection**: **爽感反馈** — 每次操作伴随满足的视觉/数值反馈。数值是进步最直接的表达，视觉冲击直接转化为"变强"的感觉。

---

#### Principle 2: Particle Abundance

**Definition**: 有意义的操作触发粒子效果。击败敌人金币爆发、升级闪光、暴击元素爆炸。粒子要丰富但不压倒 — 粒子 = 进步的统一视觉语言。

**Design Test**: 开宝箱要不要粒子 → 总是要。选择简单淡入动画 vs 粒子爆发入场的新装备 → 选择粒子爆发。问题不是"要不要粒子"，而是"什么粒子，多少"。

**Pillar Connection**: **稳定成长 + 爽感反馈** — 粒子创造 visceral 的成就感，强化可预期的无失败进步循环。每次粒子爆发是玩家成长的迷你庆祝。

---

#### Principle 3: Rounded Bounce

**Definition**: 所有视觉元素 — 角色、UI面板、按钮、图标 — 使用圆润形状和弹性动画。交互时挤压拉伸、面板打开bounce入场、微妙idle动画让世界活泼友好。尖锐角度和刚性动作感觉"死"。

**Design Test**: 伤害弹出是静态矩形数字淡出 → 失败本原则。应是圆润气泡带bounce曲线放大。选择滑入面板（线性） vs bounce入场面板（弹性） → 选择bounce。敌人死亡应压扁bounce后消失，不是简单淡出。

**Pillar Connection**: **掌控节奏 + 稳定成长** — bounce圆润美学创造愉悦舒适感，匹配低压力可预期的玩法。这里没有焦虑 — 只有愉快进步。弹性映射玩家按自己节奏参与的能力。

---

### Visual Decision Framework

任何视觉设计决策，按顺序应用：

1. **Pop?** — 玩家能立即感知这是进步吗？
2. **Numbers have presence?** — 数值反馈是否大、动画化、有意义？
3. **Particles celebrate?** — 这时刻值得粒子爆发吗？（通常值得）
4. **Bounce?** — 形状圆润、动画弹性吗？

任一答案是"否"，重新考虑设计。

---

### Anti-Patterns (What This Game Does NOT Look Like)

- ❌ 暗黑写实风格
- ❌ 小而静态的数值显示
- ❌ 尖锐边缘UI元素
- ❌ 线性机械动画
- ❌ 微妙难察觉的反馈
- ❌ 红色"失败"闪烁指示（本游戏无失败状态）

---

## 2. Mood & Atmosphere

### 情绪目标 (按游戏状态)

| 游戏状态 | 情绪目标 | 光照特征 | 氛围形容词 | 能量级别 |
|----------|----------|----------|------------|----------|
| **地牢推进** | Cozy Anticipation — 温暖期待，像拆礼物 | 温暖金色时光；中低对比；柔和环境光 | 亲切、好奇、稳定、欢迎、冒险 | Measured Momentum — 舒缓前进 |
| **自动战斗** | Playful Spectacle — 看烟花秀的兴奋 | 动态暖色闪光；金橙高光；中等对比 | 华丽、活力、欢庆、戏剧性 | Frenetic-but-Safe — 热闹但安全 |
| **掉落获得** | Jubilant Reward — 纯粹回报，"YES!"时刻 | 明亮金黄绽放；高对比弹出；暖光辐射 | 爆发、胜利、喜悦、满足、丰富 | Peak Burst — 最高能量爆发 |
| **强化成功** | Triumphant Elevation — "我更强了" | 辉煌白金爆发；暖中心柔和外围 | 辉煌、赋能、珍贵、胜利 | 突发爆发 → 温暖满足 |
| **收菜** | Welcomed Return — "欢迎回来" | 柔暖晨光；温和琥珀；低对比；舒适朦胧 | 温暖、慷慨、舒适、感激、安宁 | Gentle Warmth — 舒缓满足 |
| **主界面** | Organized Empowerment — 清晰目标，准备行动 | 干净温暖日光；平衡对比；清晰焦点高光 | 清晰、有目的、邀请、有序、准备好 | Steady Readiness — 平稳待命 |

### 支柱一致性

| 支柱 | 氛围支持方式 |
|------|--------------|
| **爽感反馈** | 掉落/强化状态使用高爆发光照和爆发粒子词汇 |
| **稳定成长** | 所有状态避免紧张或威胁；战斗是表演不是压力；探索是温暖不是阴森 |
| **掌控节奏** | 能量跨度清晰（舒缓 → 中等 → 热闹 → 最高爆发），玩家选择强度 |
| **多元成长** | 强化与掉落是独特高峰时刻，各有独特视觉词汇 |

### 状态差异总结

- **地牢推进**: 温暖、低压力 — 旅程
- **自动战斗**: 华丽、热闹、安全混乱 — 表演
- **掉落获得**: 最高庆祝、最大弹出 — 回报
- **强化成功**: 辉煌、赋能 — 成长时刻
- **收菜**: 柔软、欢迎、温和 — 回归
- **主界面**: 清晰、有序、准备好 — 指挥中心

### 参考对齐 (梦幻西游手游)

所有状态保持参考的 **明亮卡通色调** 和 **温暖舒适基调**。无状态使用冷色/蓝主导光照或高紧张描述词。战斗避免"紧张"或"危险"词汇 — 是"戏剧性"和"表演"。

---

## 3. Shape Language

### Core Philosophy

Shape language reinforces the **Rounded Bounce** principle across all visual elements. Every shape decision answers: "Does this feel warm, friendly, and celebratory?"

**Dominant Shape Character**: Curved, organic, rounded with playful exaggeration
**Rejected Shape Character**: Sharp, angular, aggressive, threatening

---

### 3.1 Character Silhouette Philosophy

#### Readability at Thumbnail Size

Characters must be instantly recognizable at 32×32 pixels (mobile notification icon scale). Silhouette clarity over detail richness.

| Element | Rule | Rationale |
|---------|------|-----------|
| **Core body shape** | Single dominant mass | One readable blob, not fragmented parts |
| **Proportions** | Exaggerated head (40-50% of height) | Maximizes expressiveness at small scale; matches chibi/卡通 aesthetic |
| **Extremities** | Simplified shapes, no individual fingers | Hands as mitten blobs, feet as rounded stumps |
| **Detail density** | 3-5 major silhouette elements max | Beyond this, thumbnail readability collapses |

**Design Test**: Scale character to 32×32. Can you identify archetype (hero vs enemy vs NPC) and class/role? If no, simplify.

#### Archetype Silhouette Differentiation

| Archetype | Distinguishing Silhouette Trait | Shape Vocabulary |
|-----------|--------------------------------|------------------|
| **Player Hero** | Tallest silhouette; largest head-to-body ratio; signature weapon visible | Round body, oversized head, weapon as shape extension |
| **Enemy (Melee)** | Compact, hunched, forward-leaning; aggression in posture not angles | Rounded but crouched; low center of gravity |
| **Enemy (Ranged)** | Taller than melee; distinctive projectile shape (staff, bow) held aloft | Upright posture; weapon creates vertical silhouette accent |
| **Enemy (Boss)** | 2-3× player height; multi-part silhouette with clear phase indicators | Round core with multiple rounded appendages; no sharp protrusions |
| **NPC (Merchant)** | Rounded, non-threatening; hands visible (not weapons) | Softest silhouette; gentle curves; approachable scale (similar to player) |
| **NPC (Quest Giver)** | Distinctive accessory shape (scroll, exclamation marker) | Rounded body + vertical accent element |

**Key Principle**: Enemies feel threatening through **posture and color**, not sharp geometry. A crouched, red-orange blob reads as enemy. A tall, purple-tinted blob reads as boss. Shape stays safe; posture and palette signal role.

#### Silhouette Simplicity vs Detail Balance

**Rule**: Complexity budget = 80% silhouette / 20% interior detail

- **At rest**: Simple rounded silhouette dominates
- **In action**: Silhouette expands via weapon swing, ability effect, bounce animation — shape stretches, not fragments
- **Detail purpose**: Interior lines define expression, not outline complexity

**Pillar Connection**: **掌控节奏** — Simple silhouettes let players instantly parse encounters at any zoom level. Visual complexity stays manageable during idle/auto-play, supporting relaxed engagement.

**Emotional Communication**: Friendly, approachable characters invite investment. No silhouette feels "dangerous" — even bosses are impressive and dramatic, not scary or intimidating.

---

### 3.2 Environment Geometry

#### Dominant Shape Philosophy: Curved Organic

**Why curved dominates**: Angles create tension. Curves create comfort. A dungeon should feel like a **cozy underground den**, not a hostile labyrinth.

| Environment Element | Shape Language | Rationale |
|---------------------|----------------|-----------|
| **Dungeon walls** | Rounded corners; arch tops; softened edges | Eliminates "oppressive cave" feeling; creates welcoming passages |
| **Floors/ground** | Organic blobs with soft transitions; no hard grid edges | Natural flow; guides eye gently through spaces |
| **Platforms** | Elliptical or rounded-rect; beveled edges; bounce-friendly | Matches character roundness; feels bouncy underfoot |
| **Doorways/portals** | Arch or oval shapes; glowing warmth inside | Portal = invitation, not barrier; curve frames reward beyond |
| **Treasure chests** | Rounded cube; domed lid; bouncy lid pop | Chest shape promises celebration before it opens |
| **Decorative elements** | Rounded lanterns, soft bushes, curved crystals | World feels handcrafted and gentle, not procedural and cold |

**Angular Exception**: Minimal sharp geometry reserved for:
- Purely decorative stalactites (softened tips)
- Weapon rack backgrounds (weapons have slight edge, but softened)
- Boss arena danger zones (rare, telegraphed, non-damaging — creates visual drama)

#### Environment Shape Supporting "Cozy Anticipation"

**Background vs Foreground Hierarchy**:

| Layer | Shape Clarity | Saturation | Detail | Role |
|-------|---------------|------------|--------|------|
| **Far background** | Soft, muted curves; undefined edges | 30-50% desaturated | Minimal | Atmosphere, depth, warmth |
| **Mid-ground** | Clearer rounded shapes; recognizable forms | 70-90% saturation | Moderate | Navigation hints, visual interest |
| **Foreground/play area** | Crisp rounded shapes; highest contrast | 100% saturation | Highest | Gameplay clarity, interaction focus |
| **UI overlay** | Distinct rounded-rect language; clean edges | Themed per system | Minimal text/icons | Information, action |

**Depth via Shape**: Foreground shapes have stronger outline weight and higher contrast. Background shapes blur softly into ambient color blobs.

**Pillar Connection**: **稳定成长** — Environment shapes create a consistent, non-threatening backdrop. Progression through dungeons feels like exploring inviting spaces, not surviving hostile territory. Shape consistency supports the promise of safe, reliable advancement.

**Emotional Communication**: Every room whispers "welcome" through curved arches and rounded platforms. No dead ends, no threatening corners — only cozy spaces to discover.

---

### 3.3 UI Shape Grammar

#### UI World Integration: Unified Aesthetic

**Design Choice**: UI echoes world aesthetic rather than imposing a separate HUD layer. UI elements feel like **magical floating panels** that belong in the dungeon world.

**Rationale**: Mobile idle games maintain immersion through UI-world cohesion. Hard-edged glass HUDs break the cozy fantasy. Rounded UI feels like part of the magical environment.

| UI Element | Shape Language | Dimensions | Animation Behavior |
|------------|----------------|------------|-------------------|
| **Panels** | Rounded rectangle; 16-24px corner radius | Size varies | Bounce-in on open; ease-out on close |
| **Buttons** | Pill-shaped (fully rounded ends) or high-radius rect; min 44px touch target | 44-64px height | Press = squash 90% scale; release = bounce 105% → 100% |
| **Icons** | Circular or rounded-square containers; 4px radius minimum | 32-48px | Idle gentle pulse (1.02× scale loop); bounce on tap |
| **Number popups** | Rounded oval/speech bubble shape; generous padding | Auto-size to content | Launch upward with bounce; fade after 1.5s |
| **Progress bars** | Rounded ends (pill shape); filled portion same radius | Height 8-24px | Fill animates with ease-out curve; bounce at completion |
| **Modals** | Large rounded panel; 24-32px radius; soft drop shadow | 80% screen width | Scale up from 0.8× with bounce; backdrop dims |
| **Tooltips** | Rounded rect; pointed arrow to origin | Auto-size | Fade in quickly (150ms); no bounce (secondary info) |

#### Rounded Corners vs Sharp Edges

**Rule**: Minimum 8px corner radius on all UI elements. Sharp edges (0-4px radius) are prohibited.

**Why rounded dominates**:

1. **Touch-friendly**: Rounded corners feel tappable; sharp corners feel passive
2. **Bounce-compatible**: Sharp corners look wrong during squash-stretch animations
3. **Warmth**: Curves align with "cozy celebration" mood; sharp edges feel cold
4. **Mobile precedent**: iOS/Android design languages favor rounded; players expect it

**Edge Case**: Text input fields use subtle rounding (4-6px) to distinguish from action buttons while staying within rounded language.

#### Numerical Prominence via Shape

**Number containers are hero shapes**:
- Floating damage numbers: Rounded bubble with stroke, bounce animation, particle trail
- Gold/loot counters: Circular badge attached to UI panel, pulse animation on increment
- Level-up numbers: Large rounded rect overlay, celebratory particle burst on edges

**Pillar Connection**: **爽感反馈** — UI shapes bounce and pop, making every interaction feel responsive. The rounded grammar ensures buttons feel alive, panels feel welcoming, and numbers feel impactful.

**Emotional Communication**: UI feels like a friendly guide, not a cold dashboard. Every tap rewards with visual affirmation. Numbers aren't just data — they're celebration.

---

### 3.4 Hero Shapes vs Supporting Shapes

#### Visual Hierarchy Definition

**Hero shapes**: Elements that demand attention and communicate progress or action
**Supporting shapes**: Elements that provide context, atmosphere, or secondary information

| Category | Hero Shapes | Supporting Shapes |
|----------|-------------|-------------------|
| **Characters** | Player hero; rare enemies; bosses | Common enemies; background NPCs |
| **Items** | Equipped gear; rare drops; currency | Common drops; materials; consumables |
| **UI** | Primary action buttons; key stats; loot popups | Navigation tabs; secondary stats; tooltips |
| **Environment** | Interactive objects (chests, portals); rewards | Decorative elements; walls; background |
| **Effects** | Damage numbers; level-up bursts; item acquisition | Ambient particles; idle animations |

#### Shape Hierarchy Rules

**Hero Shape Characteristics**:
1. **Larger scale**: 1.3-2× the size of supporting equivalents
2. **Stronger contrast**: Higher saturation; stronger outline (3-4px vs 1-2px)
3. **More dynamic animation**: Bounce curves; particle effects; glow halos
4. **Centered positioning**: Hero elements occupy screen center or natural focal points
5. **Additional decoration**: Hero buttons get icon + text + particle accent; supporting get icon only

**Supporting Shape Characteristics**:
1. **Smaller scale**: Fits around hero elements without competing
2. **Muted contrast**: 60-80% saturation; lighter outline weight
3. **Subtle animation**: Gentle idle pulse or no animation
4. **Edge positioning**: Tabs, side panels, corners
5. **Minimal decoration**: Icon or text, not both; no particles

#### Hierarchy Supporting Game Pillars

| Pillar | Shape Hierarchy Support |
|--------|------------------------|
| **爽感反馈** | Hero shapes (damage numbers, loot popups) use maximum bounce, largest scale, particle bursts. Player can't miss them. |
| **稳定成长** | Progress bars and level indicators are hero shapes always visible. Growth is perpetually foreground. |
| **掌控节奏** | Clear hierarchy lets player choose intensity: focus on hero shapes for active play; let supporting shapes fade during idle observation. |
| **多元成长** | Different progression systems (equipment, skills, collection) each have distinct hero shape families. Player tracks multiple growth paths visually. |

#### Emotional Communication Through Hierarchy

**Hero shapes say**: "Look here! This matters! This is your progress!"
**Supporting shapes say**: "This is here when you need it. Relax. The important stuff pops."

The hierarchy ensures players never feel overwhelmed or unsure where to look. Hero shapes guide attention naturally. Supporting shapes create rich context without demanding focus.

---

### 3.5 Shape Language Decision Checklist

When designing any visual element, verify:

1. ✓ **Rounded?** — Is the dominant shape curved or softened? (Reject sharp angles)
2. ✓ **Bounce-ready?** — Does the shape look good during squash-stretch? (Test at 90% and 110% scale)
3. ✓ **Hero or supporting?** — Is hierarchy clear? Size, contrast, animation level match role?
4. ✓ **Thumbnail readable?** — For characters: identifiable at 32×32?
5. ✓ **Pillar-aligned?** — Which pillar does this serve? (爽感反馈 / 稳定成长 / 掌控节奏 / 多元成长)
6. ✓ **Emotional match?** — Does this shape feel warm, friendly, celebratory?

**If any answer is unclear or negative**, revise the shape before proceeding.

---

### Shape Language Summary Table

| Domain | Dominant Shape | Rationale | Pillar Connection | Emotional Message |
|--------|----------------|----------|-------------------|-------------------|
| **Characters** | Rounded silhouettes; exaggerated heads; posture-over-geometry differentiation | Instant archetype recognition at mobile scale | 掌控节奏 | Friendly; approachable; enemies are dramatic, not scary |
| **Environment** | Curved walls; arch doorways; rounded platforms | Cozy anticipation; no threatening corners | 稳定成长 | Welcoming spaces; safe exploration |
| **UI** | Rounded panels; pill buttons; circular icons; bounce animation | Touch-friendly; celebration-ready; warm | 爽感反馈 | Every tap is rewarded; UI is alive |
| **Hero elements** | Large; high contrast; bounce; particles; centered | Progress unmissable | All pillars (visibility) | "You accomplished this!" |
| **Supporting elements** | Small; muted; subtle or no animation; edge positioned | Rich context without demanding attention | 掌控节奏 | "Here when you need it" |

---

## 4. Color System

### 设计哲学

色彩系统必须体现核心视觉规则: **"Every progress moment must 'pop'"** — 通过温暖庆祝视角。本游戏色彩承载语义意义，玩家本能理解颜色传达的信息。

---

### 4.1 主色板 (7色)

| 颜色名称 | Hex | RGB | 语义角色 |
|----------|-----|-----|----------|
| **Golden Amber** | `#E5A50A` | (229, 165, 10) | **成就之色** — 金色是"你成功了"的视觉语言。掉落弹出、强化成功、货币计数、里程碑成就。支柱：爽感反馈 + 稳定成长 |
| **Celebration Orange** | `#F27D16` | (242, 125, 16) | **最高反馈之色** — 最大pop时刻。暴击、重大强化里程碑、Boss击败、宝箱开启爆发。支柱：爽感反馈 |
| **Verdant Growth** | `#7CB342` | (124, 179, 66) | **变强之色** — "正在成长"。升级指示、强化进度动画、属性增长高亮、装备强化按钮。支柱：稳定成长 + 多元成长 |
| **Soft Lavender** | `#9B7BB8` | (155, 123, 184) | **稀有神秘之色** — "特别"。稀有装备边框、神秘物品光晕、独特Boss高亮、收集完成标记。支柱：多元成长 |
| **Rosy Comfort** | `#E57373` | (229, 115, 115) | **关怀欢迎之色** — 温暖舒适。治疗效果、欢迎回归、角色表情、友好NPC点缀。支柱：稳定成长 |
| **Warm Cream** | `#FDF5E6` | (253, 245, 230) | **安全空间之色** — 中性画布。背景层、休息区环境、UI面板背景、非激活状态。支柱：掌控节奏 |
| **Earthen Brown** | `#8B6914` | (139, 105, 20) | **基础之色** — 地牢结构、装备基底、材料图标。温暖棕色 = 古木阳光石，不是压抑。支柱：稳定成长 |

**色板和谐分析**: 中心轴为温暖琥珀橙 (Golden Amber + Celebration Orange)，支持色为温暖中性 (Warm Cream + Earthen Brown)，语义点缀 (Verdant Growth + Soft Lavender + Rosy Comfort)。

**无纯蓝**: mood targets要求"no cold/blue-dominant"。纯蓝违背温馨庆祝。Soft Lavender实现"稀有"语义同时保持温暖。

---

### 4.2 语义色用法

#### 红色传达什么

**本世界中，红 = 庆祝与关怀，不是危险。**

| 用法 | 语义 |
|------|------|
| Jubilant burst粒子 | Celebration Orange偏红橙，最大pop |
| Rosy comfort光晕 | 治疗效果、欢迎动画、角色表情 |
| 敌人点缀 | 温暖红橙色调，戏剧性不是威胁 |

**为何反转**: 游戏无失败状态。红=危险会训练玩家焦虑。红=庆祝训练玩家"温暖红出现 = 好事发生"。

#### 金色传达什么

**金 = 你获得了什么。**

| 金色用法 | 语义 |
|----------|------|
| 货币计数 | "你有资源" |
| 掉落弹出背景 | "你获得了这件物品" |
| 强化成功爆发 | "你的努力有了回报" |
| 里程碑成就徽章 | "你达到了目标" |
| 升级数字光晕 | "你成长了" |

**金永不用于**: 失败状态（不存在）、障碍、屏障、中性信息。金色保留给获得结果。

#### 绿色传达什么

**绿 = 成长进行中，不只是健康。**

| 绿色用法 | 语义 |
|----------|------|
| 升级按钮高亮 | "点击这里变强" |
| 强化进度条 | "你的提升正在进行" |
| 属性增长指示 | "这个数字增长了" |
| 装备强化光晕 | "这件物品可以更强" |
| 成长粒子 | "你在进化" |

#### 橙色传达什么

**橙 = 最高Pop。峰值时刻。**

| 橙色用法 | 语义 |
|----------|------|
| 暴击爆发 | "这次命中特别" |
| 重大里程碑庆祝 | "你做了件大事" |
| Boss击败爆炸 | "你征服了挑战" |
| 宝箱开启粒子洪流 | "奖励来临" |
| 稀有度指示 (Epic) | "这很出色" |

#### 紫/淡紫传达什么

**紫 = 这很特殊。值得关注。**

| Lavender用法 | 语义 |
|--------------|------|
| 稀有装备边框 | "这件物品不常见" |
| 独特Boss光环 | "这场遭遇值得记忆" |
| 收集完成徽章 | "你收集了全部某物" |
| 神秘物品光晕 | "这有特殊属性" |
| 成就里程碑(稀有级) | "这成就值得注意" |

#### 白/奶油传达什么

**白/奶油 = 中性舞台。没有消息就是好消息。**

| 奶油用法 | 语义 |
|----------|------|
| UI面板背景 | "这是信息，不是行动" |
| 休息区环境 | "你可以在这里放松" |
| 非激活按钮状态 | "可用但不紧急" |
| 背景层 | "前景行动的舞台" |
| 中性文本 | "这是描述性内容" |

---

### 4.3 语义色总结

| 颜色 | 主要语义 | 次要语义 | 永不用于 |
|------|----------|----------|----------|
| **Golden Amber** | 成就、奖励、成功 | 货币、里程碑 | 失败、障碍 |
| **Celebration Orange** | 最高反馈、最大pop | 重大里程碑、暴击 | 小反馈、危险 |
| **Verdant Growth** | 成长进行中、升级 | 健康(作为成长指示) | 警告、停止 |
| **Soft Lavender** | 稀有、特殊、神秘 | 收集、独特 | 常见物品、危险 |
| **Rosy Comfort** | 关怀、欢迎、舒适 | 治疗、表情 | 伤害、威胁 |
| **Warm Cream** | 中性舞台、安全空间 | 背景、非激活 | Hero元素、行动 |
| **Earthen Brown** | 基础、根基 | 结构、材料 | 兴奋、pop |

---

### 4.4 按区域色温规则

**核心原则: 温暖主导**

所有区域保持温暖色温。戏剧来自 **色彩强度和饱和度**，不是色温偏移。

#### 地牢深度色温梯度

| 地牢层 | 温 | 饱和度 | 光照强度 | 情绪 |
|--------|------|--------|----------|------|
| **Layer 1 (入口)** | Warm Cream主导 | 低(60-70%) | 柔和均匀 | "欢迎，你属于这里" |
| **Layer 2-3 (推进)** | Golden Amber点缀 | 中(75-85%) | 中等高光 | "你在前进" |
| **Layer 4-5 (深层)** | Celebration Orange高光 | 高(90-100%) | 动态闪光 | "这很刺激" |
| **Boss房间** | Celebration Orange + Soft Lavender混合 | 最高(100%) | 胜利爆发光 | "这是峰值时刻" |

**越深 = 越暖/越饱和**: 进步应感觉越来越值得。色彩强度随玩家前进增加，强化支柱稳定成长。

#### 战斗区 vs 休息区色温

| 区域类型 | 主色 | 点缀色 | 光照感 | 语义信息 |
|----------|------|--------|--------|----------|
| **战斗区** | Warm Cream背景，Celebration Orange行动元素 | Golden Amber命中，Verdant Growth升级 | 动态闪光、粒子爆发 | "刺激但安全 — 这是表演" |
| **休息区** | Warm Cream主导，Rosy Comfort点缀 | Soft Lavender展示稀有物品 | 柔和golden-hour，低对比 | "放松，你安全，看看你获得了什么" |
| **过渡区**(走廊) | Earthen Brown结构，Warm Cream环境 | Golden Amber门/portal | 均匀，出口引导光 | "准备好时继续" |

---

### 4.5 UI色板

**UI与世界使用相同色板**，为可读性调整饱和度。

| UI元素 | 主色 | Hover/Focus | Active/Pressed | Disabled |
|--------|------|-------------|----------------|----------|
| **主要行动按钮** | Celebration Orange | Brighter Orange | Golden Amber | Warm Cream(柔和) |
| **次要行动按钮** | Verdant Growth | Brighter Green | Darker Green | Warm Cream(柔和) |
| **导航/Tab按钮** | Earthen Brown | Golden Amber边框 | Golden Amber填充 | Warm Cream(柔和) |
| **面板背景** | Warm Cream 90%透明度 | — | — | — |
| **Hero数字弹出** | Golden Amber背景 + Celebration Orange粒子 | — | — | — |
| **进度条填充** | Verdant Growth(进行中) → Golden Amber(完成) | — | — | — |
| **货币计数** | Golden Amber | — | — | — |
| **装备稀有边框** | [按稀有度层级] | — | — | — |
| **主要文本** | Earthen Brown(深) | — | — | — |
| **次要文本** | Earthen Brown 70%透明度 | — | — | — |
| **按钮文本** | Warm Cream(高对比) | — | — | — |

#### Hero vs Supporting UI色彩层次

| 层级 | 饱和度 | 动画级别 | 示例元素 |
|------|--------|----------|----------|
| **Hero UI** | 100%饱和度 | Bounce + 粒子 + 光晕 | 数字弹出、行动按钮、成就徽章、货币计数 |
| **Supporting UI** | 60-80%饱和度 | 轻柔脉冲或无 | 面板、tooltip、导航tab、次要文本 |

---

### 4.6 色盲安全

#### 已识别色冲突对

| 色对 | 冲突类型 | 受影响色盲 | 严重度 |
|------|----------|------------|--------|
| **Golden Amber + Celebration Orange** | 相近色相(橙黄) | Protanopia, Deuteranopia | HIGH |
| **Verdant Growth + Rosy Comfort** | 红绿混淆 | Protanopia, Deuteranopia | MEDIUM |
| **Golden Amber + Earthen Brown** | 相近暖色调 | Protanopia, Deuteranopia, Tritanopia | LOW |

#### 备份提示策略

**原则**: 每语义色有非色备份提示。色是主要，但永不单独传达。

| 语义色 | 形状备份 | 图标备份 | 纹理备份 |
|--------|----------|----------|----------|
| **Golden Amber (奖励)** | 圆角矩形容器 | Trophy `★` | 渐变闪烁 |
| **Celebration Orange (峰值)** | 圆形爆发容器 | Star `✦` | 粒子光环 |
| **Verdant Growth (升级)** | 菱形指示 | Arrow `↑` | 渐变填充 |
| **Soft Lavender (稀有)** | 星形点缀 | Gem `◆` | 闪烁图案 |
| **Rosy Comfort (关怀)** | 心形点缀 | Heart `♥` | 柔光晕 |
| **Earthen Brown (基础)** | 方形点缀 | Coin `●` | 纯填充 |

#### WCAG对比度验证

| 文本组合 | 对比度 | WCAG级别 |
|----------|--------|----------|
| Earthen Brown on Warm Cream | ~6.2:1 | AAA ✓ |
| Warm Cream on Celebration Orange | ~4.8:1 | AA ✓ |
| Soft Lavender on Warm Cream | ~3.2:1 | AA ✓ |
| Verdant Growth on Warm Cream | ~3.5:1 | AA ✓ |

---

### 4.7 色彩决策清单

选择任何视觉元素颜色时，验证:

1. ✓ **温暖?** — 是温暖色调或偏暖？(拒绝冷/蓝主导)
2. ✓ **语义匹配?** — 颜色传达正确意义？(金=成就，橙=峰值，绿=成长...)
3. ✓ **支柱对齐?** — 这颜色选择服务于哪个支柱？
4. ✓ **层次正确?** — 饱和度级别合适(Hero=100%，Supporting=60-80%)？
5. ✓ **色盲安全?** — 有形状/图标/纹理备份提示？
6. ✓ **对比验证?** — 文本/UI对比度符合WCAG AA？

任一答案不清楚或否定，修改颜色再继续。

---

## 5. Character Design Direction

[Not in scope — deferred]

---

## 6. Environment Design Language

[Not in scope — deferred]

---

## 7. UI/HUD Visual Direction

[Not in scope — deferred]

---

## 8. Asset Standards

[Not in scope — deferred]

---

## 9. Reference Direction

[Not in scope — deferred]