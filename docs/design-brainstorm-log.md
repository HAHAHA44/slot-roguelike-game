# Slot Roguelike Brainstorm Log

## v0.1 - Event-Driven Build Prototype

### Round Theme
- 重点：让事件系统不只是随机打断，而是直接成为构筑引擎。

### Assumptions
- 保持基础 5x5 slot grid 不变，扩展能力作为事件或高稀有系统后续解锁。
- 首轮只设计能稳定落地的系统，不引入大量新 UI 层。
- 主题保持抽象标签化，便于未来换皮与 AI 生成内容。

### New Mechanics
1. Event Draft
   - 说明：每次租金结算后，从 3 个事件中选 1 个，事件分为即时、持续、危机三类。
   - 触发：达到结算节点或满足特定盘面条件。
   - 影响：玩家能围绕事件方向构筑，而不是被纯随机牵引。
   - 实现难度：低到中。
2. Tag Pulse
   - 说明：Token 拥有抽象标签，如 `Grow`、`Break`、`Link`、`Charge`，事件按标签统计并放大奖励。
   - 触发：结算时扫描全盘标签数量、相邻关系、行列覆盖情况。
   - 影响：事件和 Token 共享一套数据语言，后续内容扩展成本低。
   - 实现难度：低。
3. Risk Contract
   - 说明：部分事件提供“高压条件 + 高额回报”的契约，例如 3 轮内达成 4 次相邻触发，否则失去一个随机 Token。
   - 触发：事件选择时主动签订。
   - 影响：制造赌与稳的决策层，提升重开动力。
   - 实现难度：中。
4. Spatial Anomaly
   - 说明：超级稀有事件能短暂改写空间规则，例如开启一列临时格位，或生成占 2 格的巨型 Token 蓝图。
   - 触发：高稀有事件、Boss 结算、Ascension 特殊奖励。
   - 影响：为 6x6、双格 Token、版面规则改写保留扩展口。
   - 实现难度：中到高。

### Tokens
1. Pulse Seed
   - 稀有度：Common
   - 效果：若相邻有 `Grow` 或 `Charge` 标签，本轮额外 +1 充能；满 3 充能时本次结算得分翻倍并清空充能。
   - 联动：适合 `Charge`、连锁爆发、危机事件倒计时。
   - 平衡风险：否；爆发前需要回合积累。
2. Relay Prism
   - 稀有度：Uncommon
   - 效果：将自身所在行第一次触发的相邻效果复制到同列一个随机 Token。
   - 联动：适合行列触发、事件要求“单轮触发次数”时冲刺。
   - 平衡风险：是；复制高倍率效果时可能超额放大。
3. Hollow Shell
   - 稀有度：Common
   - 效果：被删除时生成 2 个 `Shard` 临时物；`Shard` 1 轮后消失，消失时若相邻有 `Break` 标签则给分。
   - 联动：配合删除选项、破坏流、危机事件的清盘要求。
   - 平衡风险：否；临时物自带衰减。
4. Anchor Glyph
   - 稀有度：Rare
   - 效果：相邻 Token 不会被随机删除或位移；每保护 1 次，自己永久 +1 基础分，最多 +5。
   - 联动：适合持续事件、保底玩法、主角偏防守技能。
   - 平衡风险：否；成长上限明确。
5. Wild Signal
   - 稀有度：Rare
   - 效果：结算时临时获得相邻 Token 中数量最多的标签，随后额外触发一次该标签相关事件计数。
   - 联动：可补关键标签数，适合事件契约与混合构筑。
   - 平衡风险：是；容易成为所有流派通用最优件。
6. Twin Monolith
   - 稀有度：Legendary
   - 效果：占据相邻 2 格；视作同一单位。若两端各自相邻到不同标签，则按两个标签各触发一次。
   - 联动：是空间扩展原型件，可直接测试多格 Token 系统。
   - 平衡风险：是；多次计数与占格成本需要精确校准。

### System Synergy
- Event System：事件牌按标签和盘面状态出牌，`Event Draft` 提供方向选择，`Risk Contract` 提供短期目标，`Spatial Anomaly` 提供稀有惊喜。
- Hero System：主角属性可影响事件刷新权重、契约成功奖励、空间异常概率。例：`Insight` 提高事件可见数，`Resolve` 降低危机惩罚，`Flux` 提升异常事件出现率。
- Difficulty System：Ascension 可以增加危机事件占比、降低事件刷新质量、给契约附加副作用；同时把空间异常从奖励变成“高风险高收益”。

### Player Experience
- 爽点：事件把散件拼成短期目标，`Relay Prism` 复制触发和 `Pulse Seed` 蓄爆会产生明显连锁高潮。
- 挫败点：坏事件连续出现、契约失败、关键盘面被随机破坏时会觉得被卡死。
- 重开动力：标签体系和事件契约让同一套基础 Token 也能走出不同路线，失败通常会让玩家觉得“这把如果早两轮转向另一事件就能成”。

### Numeric Risks
- 无限增长风险：复制触发、重复结算、永久成长叠加在同一单位上时容易形成闭环。
- 无解负面局：若危机事件要求删除、而盘面全是核心件，可能出现“删了输，不删也输”的死局。
- 需要限制：
  - 复制类效果每轮最多复制 1 次。
  - 永久成长必须设硬上限或软衰减。
  - 危机事件必须保留至少一个低收益保底选项。
  - 多格 Token 数量上限建议开局为 0，仅通过极稀有内容解锁。

### MVP Priority
1. Event Draft：最直接定义局内节奏与构筑方向。
2. Tag Pulse：统一 Token、事件、角色三端的数据语言。
3. Risk Contract：最低成本制造赌与稳决策。

### Summary
- 新增了可选事件牌结构，而不是纯随机事件。
- 建立了标签驱动的 Token 联动语言，便于后续批量扩展内容。
- 首次定义了“打破基础玩法”的原型入口：空间异常与双格 Token。

### Structured Record
```yaml
version: v0.1
theme: event-driven token builds
focus:
  - event_system
  - token_synergy
new_mechanics:
  - name: Event Draft
    trigger: settlement checkpoints or board conditions
    impact: gives build direction through event choice
    implementation: low_medium
  - name: Tag Pulse
    trigger: board scan on settlement
    impact: unified tag language for scalable content
    implementation: low
  - name: Risk Contract
    trigger: opt-in during event choice
    impact: adds gamble versus stability decisions
    implementation: medium
  - name: Spatial Anomaly
    trigger: ultra-rare events or boss rewards
    impact: opens future support for 6x6 or multi-cell tokens
    implementation: medium_high
tokens:
  - name: Pulse Seed
    rarity: Common
    tags: [Grow, Charge]
  - name: Relay Prism
    rarity: Uncommon
    tags: [Link]
  - name: Hollow Shell
    rarity: Common
    tags: [Break]
  - name: Anchor Glyph
    rarity: Rare
    tags: [Guard]
  - name: Wild Signal
    rarity: Rare
    tags: [Wildcard]
  - name: Twin Monolith
    rarity: Legendary
    tags: [Spatial, Link]
risks:
  - copy loops
  - permanent growth stacking
  - unwinnable crisis states
mvp:
  - Event Draft
  - Tag Pulse
  - Risk Contract
```
