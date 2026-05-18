# Reelbound — 人生模拟器重设计 PRD（草稿）

**日期**：2026-05-17（爽感轴决策 2026-05-18 补登）
**状态**：定稿；尚未替换 `2026-03-24-slot-roguelike-prd.md`，等 M0 落地后再决定是否合并
**重大变化**：从 5×5 slot roguelike 转向 12 格生肖盘人生模拟器
**爽感主轴**：A 路线（cascade 主导 + 紧张次主）—— 见 [`2026-05-18-life-sim-fun-axes.md`](2026-05-18-life-sim-fun-axes.md)
**开发计划**：里程碑 M0–M7，见 [`2026-05-18-life-sim-dev-plan.md`](2026-05-18-life-sim-dev-plan.md)

> 本文取代旧 PRD 的核心循环、板子结构、失败模型部分。旧 PRD 的服务化原则、内容资源化、状态图骨架仍然适用。
> 本文描述**是什么游戏**；fun-axes 描述**要让玩家感觉什么**；dev-plan 描述**怎么逐步建出来**。三者冲突时：fun-axes > PRD > dev-plan。

## 立意

人生模拟器 roguelike：玩家出生、做选择、攒物品和关系，精神状态决定遭遇好事还是横祸，死于精神崩溃或寿命到顶，下一世带宿命值（福报 − 恶报）转世重来。

参考：幸运房东（cascade 结算）、Balatro（联动 / 数字膨胀）、人生重开模拟器（叙事密度）、60 Seconds（资源管理压力）。

## 三层时间结构

```
人生（Run）= ~7 阶段 → 死亡 → 转世
  人生阶段 = 12 生肖年 → 阶段结算
    生肖年 = 12 格转盘 → 结算 → 年末事件
```

## 维度

| 维度 | 范围 | 来源 | 消费 |
|---|---|---|---|
| Token 池（人生碎片） | 整局 | 事件 / 物品 / 转世起始 | 年初抽 12 张投盘 |
| 物品 | 整局 | 事件奖励 / 属性门槛 | 持续 modifier |
| 精神力 0–100 | 年内浮动 | 事件 / 物品 / 关系 | 加权年末事件抽取 |
| 寿命 60–110 | 整局 | 出生随机 / 物品 / 事件 | 每年 +1，到顶自然死 |
| 属性（智 / 体 / 魅 / 财） | 整局累加 | token 结算 / 事件 / 阶段 | 软门槛 + token scaling |
| 关系（家人 / 朋友 / 伴侣） | 整局 NPC 列表 | 事件 / 阶段 | 事件门槛 + 死亡叙事 |
| 宿命值（福 / 恶报） | **跨人生** | 选择 / 事件 / 长寿 / 关系 | 下一世开局滑块 |

## 生肖盘

- 12 固定槽位（鼠 / 牛 / 虎 / 兔 / 龙 / 蛇 / 马 / 羊 / 猴 / 鸡 / 狗 / 猪）
- **当年奖励格**：流动，每年顺时针推 1 位
- **本命年格**：玩家出生生肖位永久标记
- 本命年时，普通事件池被本命年独占池覆盖
- v1 自动投放 12 张 token；手动投放后议

## 结算（幸运房东风格 cascade）

- 每个 token 持 `current_score`，开局 = `base_score`
- 循环：取未结算中 `current_score` 最低者 → 触发 effect → 标记已结算
- effect 可：加自身、改邻居 / 同生肖 / 同类得分、消耗精神 / 属性、解锁联动
- 全部结算后，年收益 = Σ `current_score`，按规则换算为属性增减 / 物品获取 / token 增减

## 精神力 + 事件

- 事件 `sanity_weights` 三档：高 / 中 / 低
- 高精神段倾向良性事件（机遇 / 物品 / 关系 / 属性）
- 低精神段倾向恶性事件（疾病 / 破财 / 关系破裂 / **死亡触发**）
- 死亡事件仅低精神段非零权重
- 事件还有 stage_filter / zodiac_filter / 属性 prereq
- 本命年时覆盖普通池为本命年专属池

## 死亡（两种触发）

1. **恶性事件** 携带 `lethal_effect`（低精神高发，玩家可见概率提示）
2. **自然死**：年龄 ≥ 随机寿命（60–110，物品 / 事件可推）

死亡后 → 局外结算 → 累计 karma → 转世。

## 人生阶段（7 + endless）

| # | 阶段 | 起始年龄 | 特色 |
|---|---|---|---|
| 0 | 童年 | 0 | 父母决定多 / 教育 / 玩伴 |
| 1 | 少年 | 12 | 学业 / 友谊 / 初恋 |
| 2 | 青年 | 24 | 事业起步 / 恋爱 / 婚姻 |
| 3 | 壮年 | 36 | 家庭 / 事业巅峰 / 子女 |
| 4 | 中年 | 48 | 危机 / 转型 / 父母离世 |
| 5 | 老年 | 60 | 退休 / 病痛 / 子女独立 |
| 6 | 暮年 | 72+ | **endless**，循环至寿命耗尽 |

每阶段独立 event pool + 开场叙事 + 阶段结算快照。

## 转世 + 宿命值（局外）

- 每条人生输出 `karma_delta = Σ(事件 karma) + 长寿奖励 + 关系奖励 − 罪孽`
- 累计 `total_karma` 跨人生持久化（沿用 SaveService 扩展）
- 下一世生效：
  - 出生家庭品级（贫困 → 权贵）随 karma 偏置
  - 起始物品池 / 额外生肖 / 出生地随 karma 解锁
  - 负 karma 背宿业（开局负属性 / 强制恶性事件）
- 目标：不是成就墙，是真正影响下一局难度与可能性的滑块

## 服务拆分

```
RunScreen (orchestrator)
  ├─ ContentRegistry
  ├─ RunSession              // 加 sanity / age / lifespan / zodiac_birth /
  │                          //   stage_idx / stats / relationships /
  │                          //   karma_in_run；删 score
  ├─ ZodiacService           // 当年生肖 / 本命年 / 奖励格
  ├─ BoardService            // 12 ring 投放 / 邻接
  ├─ SettlementService       // cascade min-score 优先 + 联动
  ├─ EventDraftService       // sanity 加权 + 本命年覆盖池
  ├─ EventResolverService    // apply choice → mutate session
  ├─ SanityService           // 钳制 + 衰减
  ├─ AgeService              // +1/年 + 寿命检查
  ├─ LifeStageService        // 阶段切换 + 开场/结算
  ├─ RelationshipService     // NPC + 关系度 + 善终/孤独判定
  ├─ StatService             // 4 属性
  ├─ KarmaService            // run 内 karma 累加
  ├─ RunModifierService      // 属性 → token/item scaling
  ├─ DeathService            // 统一死亡入口
  └─ MetaProgressionService  // 跨人生持久化 + 转世应用
```

## 资源（.tres）

新增：
- `ZodiacDef` × 12
- `LifeStageDef` × 7
- `StatDef` × 4
- `NPCRoleDef`（家人 / 朋友 / 伴侣类型）
- `KarmaRule`
- `LifespanProfile`

改造：
- `TokenDef` 加 `base_score`, `effects: ScriptableEffect[]`, `zodiac_affinity`, `stat_scaling`
- `ItemDef` 加 hooks: `on_year_start` / `on_settle` / `on_event` / `on_death`
- `EventDef` 加 `sanity_weights`, `stage_filter`, `zodiac_filter`, `prereqs`, `choices`, `karma_delta`
- `RunStartProfile` 加 `zodiac_birth`, `lifespan_base`, `starting_stats`, `karma_seed`

## 任务分解（抽象阶段视图）

> 以下 A–F 是机制完整性视角的 checklist。**开发以 [`2026-05-18-life-sim-dev-plan.md`](2026-05-18-life-sim-dev-plan.md) 的 M0–M7 里程碑为准**，本节仅作机制覆盖参考。

**A 拆地基**
1. 摘掉 5×5 board / score_threshold 路径（文件先留，git 留底）
2. 新 `ZodiacDef` + 12 .tres + `ZodiacService`
3. 新 `BoardService` 12 ring + 邻接 API + 单测
4. `RunSession` 字段重写
5. smoke test 重写：出生 → 1 年转一圈 → stub 结算 → stub 事件 → 进第 2 年

**B 核心循环**
6. `SettlementService` cascade（min current_score 优先）+ 三类单测
7. `TokenDef` 加 effects + `ScriptableEffect` 基类（v1：加分 / 改邻居 / 同生肖联动）
8. `SanityService` + RunSession 集成

**C 事件 + 寿命**
9. `EventDef` schema 改造
10. `EventDraftService` 加权抽取 + 本命年池
11. `EventResolverService` apply choice
12. `AgeService` + `DeathService` 统一死亡入口

**D 维度补全**
13. `StatService` 4 属性 + token scaling 接入
14. `RelationshipService` NPC + 善终/孤独判定
15. `ItemDef` hooks + `RunModifierService` 适配

**E 阶段 + 转世**
16. `LifeStageService` 7 阶段切换
17. 暮年 endless（接 EndlessService 骨架）
18. `KarmaService` run 内累加
19. `MetaProgressionService` 转世应用 karma

**F 内容 + UI**
20. 内容铺量：12 生肖 × 3 token / 7 阶段 × 10 事件 / 20 item / 5 NPC 角色
21. RunScreen UI 改造（生肖盘 + 精神条 + 年龄 / 寿命 + 阶段标识）
22. 转世 meta UI（宿命值展示）

## 关键风险

1. **cascade 设计空间巨大**：v1 先用 ~15 token 验骨架，再铺量
2. **属性 / 关系要软不要硬**：影响概率而非硬屏蔽，否则事件链冗长
3. **暮年 endless 易枯燥**：善终叙事密度要够
4. **karma 滑块要温柔**：前几局差距小，长玩后才显著

## 与旧 PRD 关系

- 取代：核心循环 / 板子结构 / 失败模型 / 阶段含义
- 沿用：RefCounted 服务、Resource 内容、ContentRegistry、SaveService、状态图、GUT 流水线
- 待决：旧 hero / difficulty / event .tres 在新框架下如何重定义（B / C 阶段处理）

## 开放设计问题（PRD 之外）

- ~~玩家爽感主要轴~~ → 已选 A（连锁主导），见 fun-axes
- 手动投放 token 是否进 v1（暂定否，M3 后回看）
- 转世动画与 karma 揭示的具体节奏（M6 内决定）
- 多周目目标设计（解锁 vs 挑战 vs 自定义初始）（M6 后决定）
- CLAUDE.md "Hard constraints" 中"5×5 / 25 cells / periodic settlement"在 M0 完成后必须改写
