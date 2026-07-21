# Cascade 结算规则（M1 实装状态）

**日期**：2026-07-21
**对应代码**：`scripts/core/services/settlement_service.gd` + `scripts/core/effects/`
**上位文档**：`2026-05-18-life-sim-fun-axes.md`（冲突时以 fun-axes 为准）

本文描述**当前真正跑起来的**游玩逻辑，不是设计意图。设计意图见 PRD 和 fun-axes；
两者不一致的地方在文末「已知缺口」列出。

---

## 一、年循环现状

`RunScreen.step_year()` 每年做五件事：

| 步骤 | 状态 | 实现 |
|---|---|---|
| 1. 查当年生肖 / 是否本命年 | ✅ 真实 | `ZodiacService` |
| 2. 洗牌投盘（12 格） | ✅ 真实 | `RunSession.token_pool` shuffle |
| 3. cascade 结算 | ✅ 真实 | `SettlementService.settle()` |
| 4. 年末事件 | ❌ stub | `_stub_event_skip()`，M2 实装 |
| 5. age++ / 寿命检查 | ✅ 真实 | RunScreen inline |

死法目前只有一种：**寿命到顶**。精神力恒为 50，karma / stats / relationships
初始化后无人改动——对应的服务都写好了但没接线（见「已知缺口」）。

---

## 二、投盘

出生时从 `content/run_start/default_pool.tres` 领一副「人生碎片」，拷进
`RunSession.token_pool`。**每年把整副牌洗一遍投满 12 格**，不抽牌、不弃牌。

默认池 12 张，重复份数即权重：

| token | 份数 | 稀有度 |
|---|---|---|
| 勤勉 diligence | 4 | Common |
| 挚友 close_friend | 4 | Common |
| 同乡 kinsman | 2 | Uncommon |
| 贵人 benefactor | 1 | Rare |
| 祖荫 ancestral_blessing | 1 | Legendary |

池子大小不必等于 12：多于 12 时每年只投前 12 张，少于 12 时剩余槽位留空
（`SettlementService` 会跳过空槽）。**M1 期间池子在一生中恒定不变**，
M3 事件经济接管后才会增减。

---

## 三、cascade 算法

```
1. 每个占用槽位的 current_score 初始化为 token 的 base_score
2. 反复挑「尚未结算、当前分最低」的槽位结算，同分取槽位索引小的
3. 结算 = 依次执行该 token 的 effects，effect 可改任意槽位的分（含已结算的）
4. 全部结算完 → 年收益 = Σ 各槽当前分数
```

**为什么最低分先结算**：低分 token 先跑，它们的加成落到还没结算的高分 token 上，
分数在 cascade 后段滚雪球。反过来（高分先）加成落在已定型的 token 上，曲线是平的。

**已结算的 token 仍可被后来者改分**，只是不再触发自己的 effect。这让「最后一个
token 反手把全场拉起来」成为可能。

**同分决胜取槽位索引小的**，保证同一盘面每次结算顺序一致——测试可断言，回放可复现。

---

## 四、effect 三型

所有联动的计分口径统一为：

```
delta = amount（定额） + 目标当前分 × percent%      ← CascadeContext.scaled_delta()
```

取整用 `roundi`，避免小分数时比例部分被抹成 0。

| effect | 作用 | 参数 | 算不算联动 |
|---|---|---|---|
| `AddSelfScore` | 加到自己身上 | `amount` | ❌ 不算 |
| `ModifyNeighbor` | 打 ring 上 radius 内的邻居（0 与 11 相邻） | `amount` / `percent` / `radius` | ✅ adjacent |
| `TriggerZodiacChain` | 打全场同 `zodiac_affinity` 的其他 token | `amount` / `percent` | ✅ zodiac |

两条硬规则：

- **空 `zodiac_affinity` 不参与同生肖联动**。否则无属性 token 会全场互相共鸣，
  同生肖联动退化成「全场联动」，红线失去意义。
- **chain 按 effect 计数，不按目标计数**：一个 effect 命中 ≥1 个目标记 1 次 chain。
  否则满盘同生肖一年能刷出上百 chain，3/5/7/12 的连击 banner 阈值就没意义了。

---

## 五、当前 5 个 token 的实际数值

| token | type | base | affinity | effects |
|---|---|---|---|---|
| 勤勉 diligence | virtue | 3 | — | 自加 +4 |
| 挚友 close_friend | bond | 4 | — | 邻居 +2 且 +70%（r1） |
| 同乡 kinsman | bond | 3 | rat | 同生肖 +110% |
| 贵人 benefactor | fortune | 5 | dragon | 自加 +3；邻居 +3 且 +80%（r2） |
| 祖荫 ancestral_blessing | fortune | 1 | dragon | 同生肖 +200%；邻居 +120%（r1） |

设计意图：

- **勤勉是种子**。全场唯一的「无中生有」——乘区需要有东西可乘，池子里没有足够
  定额来源的话，百分比全在小数字上打转。
- **祖荫 base 1 是刻意的**。它极早结算，此时全场分数还低，乘区看似浪费；但它给
  相邻两格挂上比例后，那两格随后会被反复放大。它和贵人同为 dragon，贵人被喂肥后
  这条红线翻倍收割。
- **同乡 2 份**才能互相成链；贵人 + 祖荫同为 dragon 同理。单份的生肖 token 在盘上
  找不到同类，红线不会亮。

`type` 目前有 virtue / bond / fortune 三类，**还没有任何机制读它**——是给将来
「同类绿线」留的位置。

---

## 六、实测手感（30 个年份采样）

```
最低 171   最高 232   均值 191   好坏年景倍差 1.36×
连击稳定在 9 次
```

- **年与年之间有差异**（±16%），来自洗牌后的排布不同。这是引入 percent 之后才有的：
  纯定额时满盘每个 token 的邻居数恒定、加法可交换，80 年全部是 cascade=123、连击 9。
- **一生之内不增长**。年 0 和年 79 是同一量级。这是 M1 的预期形态，因为池子静态。
  fun-axes P2 的「早期 3 位 → 中期 5 位 → endless 7 位」靠的是池子在一生中变大，
  那是 M3 的轴，不是 M1 能给的。
- **连击恒为 9**：挚友 ×4 各 1 次 + 同乡 ×2 各 1 次 + 贵人 1 次 + 祖荫 2 次
  （同生肖 + 邻接）。因为池子固定且满盘，命中数不随排布变化。

---

## 七、已知缺口

按优先级排：

1. **无视听层**（T1.6 / T1.7 未做）。fun-axes P1 要求 token 之间 300–500ms 微停顿、
   数字弹跳、连线高亮、连击 banner、音高递增。目前 cascade 是一次算完、只打一行日志。
   **M1 质量门在做完这层之前无法评估**——"我想看下一年吗"问的是视听节奏，不是数字。
   数据侧已经备好：`CascadeReport.steps` 可逐条回放，每步带 `chain_links`
   （含每条 link 的目标槽位和类型）供画线。
2. **连击恒定**。9 次不随排布变化，banner 阈值 3/5/7/12 里只有前三档会触发，
   而且每年都触发同样的档位。需要让命中数本身有方差（条件触发型 effect，或非满盘）。
3. **年末事件是 stub**，所以没有紧张感轴、没有第二种死法、精神力恒 50。M2。
4. **已建好但没接线的服务**：`SanityService` / `AgeService` / `DeathService` /
   `StatService` / `RelationshipService` / `KarmaService`。它们都有单测，但
   `RunScreen` 只接了 `ZodiacService` / `RingBoardService` / `LifeStageService` /
   `SettlementService`。age++ 和自然死目前是 RunScreen 里的 inline 逻辑，
   绕过了 `AgeService` / `DeathService`。
5. **`stat_scaling` 字段没人读**。`TokenDefinition` 上有，M4 才接。
6. **旧 5×5 内容仍在**：`content/tokens/` 里 17 个四元素 token、`content/events/`
   里 12 个科幻主题事件，都没有人生模拟字段。M7 清理。

---

## 八、调参入口

改手感优先动这三处，都不需要改代码：

| 想改什么 | 改哪里 |
|---|---|
| 池子构成（谁多谁少） | `content/run_start/default_pool.tres` 的 `token_ids` |
| 单个 token 的数值 | `content/tokens/<id>.tres` 的 `base_score` / `amount` / `percent` / `radius` |
| 联动种类 | 给 token 加减 `effects` 数组里的子资源 |

注意 `.tres` 里 `Array[ScriptableEffect]` 的正确序列化是
`Array[ExtResource("...")]([SubResource("...")])`，手写极易写成 `Array[Resource]`；
在编辑器里改或用 `ResourceSaver` 生成比手写安全。
