# Reelbound — 开发计划（A 路线）

**日期**：2026-05-18
**前置**：`2026-05-17-life-sim-prd.md` + `2026-05-18-life-sim-fun-axes.md`
**节奏**：垂直切片 + 每里程碑必须 playable + 每里程碑后做爽感评估

## 总览

| # | 名称 | 关键服务 | 验证什么 |
|---|---|---|---|
| M0 | Stub 编排 | RunScreen 改装 + stub 全服务 | 新结构跑得通 |
| M1 | **Cascade 活了** | SettlementService + TokenDef + 5 token | **cascade 爽不爽**（关键质量门） |
| M2 | 紧张感活了 | SanityService + DeathService + Event draft 雏形 | 单局会死 |
| M3 | 事件经济闭环 | EventResolverService + ItemDef hooks | 单局好玩 |
| M4 | 维度补全 | StatService + RelationshipService | 单局有深度 |
| M5 | 阶段切换 | LifeStageService + endless 暮年 | 完整一生 |
| M6 | 转世闭环 | KarmaService + MetaProgressionService | 多局有意义 |
| M7 | 内容 + 抛光 | content 铺量 + UI juice | 可发版 |

## 全局约束

- 每个任务遵循 TDD：先写 GUT 测试 → 失败 → 实现 → 通过 → 跑 smoke test 不挂
- 每个里程碑结束做 commit 边界，commit message 含里程碑标识（如 `feat(M1): cascade settlement`）
- 任何里程碑发现设计不对 → 停下来更新 PRD / fun-axes，再继续
- 服务一律 RefCounted + 数据流（PRD 已规定）

## 关键质量门（M1 后必停）

cascade 节奏 + 视觉 + 数字膨胀是否令人想"再玩一年"。
- 评估：自玩 10 次单年结算，问"我想看下一年吗"
- 不通过 → 改 cascade 公式 / 节奏 / 视觉反馈，**不准进 M2**
- 通过 → 进 M2，但记录"还想改的爽感细节"清单（M7 抛光时回填）

---

## M0  Stub 编排

**Done 标准**
- 新结构 smoke test 绿
- `_run_yearly_loop` 跑得通：出生 → 12 格转盘 stub 投放 → stub cascade（返回 0）→ stub event（跳过）→ age++ → 第 2 年
- 老 5×5 / score_threshold 路径从 RunScreen 摘掉（文件保留作历史）

**任务**
- T0.1 `RunSession` 改字段：加 `age / lifespan / sanity / zodiac_birth / stage_idx / stats: Dictionary / karma_in_run`；删 `score` 相关
- T0.2 `ZodiacDef.gd` + 12 .tres（鼠–猪）+ `ZodiacService`（`current_year_zodiac / is_birth_year / reward_slot_index`）+ 单测
- T0.3 `BoardService` 12 ring：`place(token, slot) / get(slot) / neighbors(slot, radius)` 纯数据 API + 单测
- T0.4 `RunScreen` 拆 5×5 路径 + 接入 stub yearly loop（年→年）
- T0.5 smoke test 重写为 `test_smoke_yearly_loop_alive`

**Demo state**：控制台输出 12 年的"年 X：当年生肖 Y，本命年命中: bool"

---

## M1  Cascade 活了（关键节点）

**Done 标准**
- 5 种 token type 上盘
- SettlementService cascade min-score-first 正确
- 至少 2 种联动模式（同生肖 / 邻接）工作
- 视觉：token 顺序点亮 + `current_score` 数字弹跳 + chain count 显示
- 听觉：基础音效 + 联动音高递增（占位资源也行）
- 通过爽感质量门

**任务**
- T1.1 `TokenDef` schema：`base_score / effects: Array[ScriptableEffect] / zodiac_affinity`
- T1.2 `ScriptableEffect` 基类 + 3 个具体 effect：`AddSelfScore / ModifyNeighbor / TriggerZodiacChain`
- T1.3 `SettlementService` cascade 主循环（min-score 选择 + effect 派发 + chain count 累计）
- T1.4 5 个示例 token .tres，覆盖 3 effect × 2 联动模式
- T1.5 单测：空盘 / 单 token / 同生肖联动 / 邻接联动 / 全场 12 连
- T1.6 RunScreen UI：12 格圆盘 + cascade 顺序点亮 + 数字弹跳（基础版）
- T1.7 音效占位 + chain count → 半音递增逻辑

**Demo state**：手玩 1 年，看到 12 token 依次结算，数字滚动，连击 banner 弹出

**Quality gate**：自玩 10 次 → 想再来 → 通过

---

## M2  紧张感活了

**Done 标准**
- 精神力 0–100 工作（年内变化）
- 事件按精神力加权抽取（无文案，能区分 良/中/恶/死 四类即可）
- 死亡事件能终结 run
- 寿命到顶能自然死

**任务**
- T2.1 `SanityService`（钳制 / 增减 API / 默认衰减规则）+ 单测
- T2.2 `EventDef` schema：`sanity_weights: Dictionary / lethal_flag / minimal effects`
- T2.3 `EventDraftService` 加权抽取 + 单测
- T2.4 `AgeService`（每年 +1 + 寿命检查）+ 单测
- T2.5 `DeathService` 统一入口（natural / lethal_event）+ 单测
- T2.6 10 个测试用 event（4 良 / 3 中 / 2 恶 / 1 死）
- T2.7 RunScreen UI：精神力环形条 + 死亡概率外露提示
- T2.8 集成测：高/低精神时抽取分布 / 死亡事件终局 / 寿命到顶终局

**Demo state**：玩到死。低精神时看到"恶性 60% 含死亡 15%"，然后死

---

## M3  事件经济闭环

**Done 标准**
- 事件 reward 能给 token / item / 精神 / 属性
- item modifier 能影响 cascade
- 年末事件 → 影响下一年 → 闭环

**任务**
- T3.1 `EventResolverService`（apply choice → mutate session）+ 单测
- T3.2 `ItemDef` schema + hooks：`on_year_start / on_settle / on_event / on_death`
- T3.3 `RunModifierService` 改造适配（item effect → cascade scaling）
- T3.4 10 个测试用 item
- T3.5 事件 reward 类型扩展（token+ / token- / item / stat / sanity）
- T3.6 集成测：item 影响 cascade / event 给 token 后下年生效 / 完整年循环

**Demo state**：玩 12 年，看到 token 池随事件变化，item 让 cascade 越炸越大

---

## M4  维度补全

**Done 标准**
- 4 属性累加 + 软门槛
- NPC 关系列表 + 善终/孤独死判定
- token scaling 接入属性

**任务**
- T4.1 `StatService` 4 属性 + 软门槛接口（影响概率而非屏蔽）+ 单测
- T4.2 token effect 加 `stat_scaling` 字段：`current_score *= (1 + stat / 100)`
- T4.3 `RelationshipService` NPC + 关系度 + 单测
- T4.4 死亡分类扩展：natural / lethal_event → 加 peaceful（高关系）/ lonely（低关系）/ illness（低精神长期）
- T4.5 集成测：属性 scaling 影响 cascade / NPC 死亡触发 / 死亡分类正确

---

## M5  阶段切换

**Done 标准**
- 7 阶段按年龄推进
- 每阶段独立 event pool
- 暮年 endless 直到死

**任务**
- T5.1 `LifeStageDef` × 7 .tres + `LifeStageService` + 单测
- T5.2 EventDraftService 加 `stage_filter`
- T5.3 阶段开场叙事（一行字 + 色卡）
- T5.4 暮年阶段循环逻辑 + endless 标记
- T5.5 集成测：年龄推进 / 阶段切换 / endless 循环

---

## M6  转世闭环

**Done 标准**
- 死亡后输出 `karma_delta`
- karma 累计持久化
- 下一局开局应用 karma → 出生家庭品级 / 起始物品 / 解锁内容

**任务**
- T6.1 `KarmaService` run 内累加 + 输出 + 单测
- T6.2 `MetaProgressionService` 持久化（SaveService 扩展）+ 单测
- T6.3 `RunStartProfile` 加 `karma_seed` 字段
- T6.4 转世界面（karma 揭示 + 走马灯 + 下一局参数预览）
- T6.5 端到端测：karma 累加 → 持久化 → 转世参数应用

---

## M7  内容 + 抛光

**Done 标准**
- ~50 token / ~70 event / ~20 item / 5 NPC 角色
- cascade 视觉特效完整（连线 / 慢镜头 / 屏震 / 数字颜色）
- 主菜单 + 转世 + 设置三屏完成

**任务**
- T7.1 内容铺量（按 fun-axes 准则）
- T7.2 cascade 视觉强化（M1 留下的爽感细节清单全部回填）
- T7.3 音效完整化
- T7.4 UI 整体抛光
- T7.5 本地化骨架（Localization autoload 已就位，按 key 铺）

---

## 并行机会

- M3 起：内容创作（token / event / item 设计）可与服务开发并行
- M4 起：UI 抛光可与逻辑并行
- M7 是收尾，不并行

## 风险与对策

| 风险 | 触发条件 | 对策 |
|---|---|---|
| M1 cascade 不爽 | 自玩 10 次没想再来 | 退回改 effect 公式 / 节奏 / 视觉，**不准进 M2** |
| token 联动设计无穷 | M1 之后还在加 token | v1 强制上限 15 token，剩下放 M7 |
| 紧张感喧宾夺主 | M2 后压力 > 爽感 | 调低死亡事件权重 / 加善终救济 |
| endless 暮年无聊 | M5 测试 70 岁后没动力 | 加暮年专属 token 联动 / "传承"事件 |
| karma 滑块太软或太硬 | M6 后多局差距不显著 / 过激 | A/B 调参数（首次玩 karma=0 时不该有压感） |

## 与 PRD 任务列表的关系

PRD 的 A–F 抽象阶段提供"机制完整性"视角；本文 M0–M7 提供"可玩切片"视角。
**开发以本文为准**，PRD 任务列表作为机制 checklist 参考。
