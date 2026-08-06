# Reelbound — Agent Reference

**Engine:** Godot 4.7.1-stable / GDScript
**Stage:** 成长闭环已实装（原 M1–M6 的机制部分）；未做：转世闭环、配方合成、暮年 endless 专属内容

## What it is

12 格生肖盘 + cascade 结算的人生模拟 roguelike。**年-循环**：

```
每一年：
  三选一抽碎片（可跳过）→ 自动合成升星        ← 玩家路径上这步在「下一年」按钮**之前**
  → 洗牌投 12 格 → cascade 结算 → 年收益 → 购买力
  → 年末事件（流水年金句 / 转折年弹窗）
  → 属性漂移 → age++ → 死亡判定

每 12 年（= 一个人生阶段 = 一次生肖轮回）：
  阶段末那一年多一步「道具商店」（4 件，买掉的置灰留在架上，逛完剩余购买力作废）
  → 阶段考核（没过扣精神力）→ 满星者传承 → 当期碎片清空
```

三选一**不在** `_advance_year_interactive()` 协程里：它在出生后与上一年收尾后自己弹出来，
玩家选完再按「下一年」直接开转。它走**常驻信号连接 + `_modal_mode` 开关**而不是 `await`——
`await` 会在 `begin_run()` 打断时留下一条永远停在等信号处的协程（重开一局就打断了）。

**术语一律以根目录 [`CONTEXT.md`](CONTEXT.md) 为准**（人生碎片 / 命盘 / 行囊 / 传承物 / 年度规则…）。
写代码前先读它，别自己造词。

设计文档：
- [`docs/2026-05-17-life-sim-prd.md`](docs/2026-05-17-life-sim-prd.md) —— 是什么游戏（部分已被下面那份取代）
- [`docs/2026-05-18-life-sim-fun-axes.md`](docs/2026-05-18-life-sim-fun-axes.md) —— 要让玩家感觉什么（**冲突时它最大**）
- [`docs/2026-07-31-growth-loop-design.md`](docs/2026-07-31-growth-loop-design.md) —— 成长闭环的 23 条决策与理由
- [`docs/adr/`](docs/adr/) —— 三条不可轻易推翻的架构决策

参考：幸运房东（cascade）、自走棋（三合一升星）、Balatro（相对计价）、人生重开模拟器（叙事密度）。

## Hard constraints (never change)

- **12 格生肖盘**，固定槽位（鼠–猪 order 0-11）。不改 ring 大小。
- **命盘恒 12 张**，另有行囊 6 格。不做牌库膨胀（见 ADR-0001）。
- **每个生肖必须带一条年度规则**。生肖盘一旦退回装饰，这游戏的骨架就空了（ADR-0002）。
- **碎片按阶段分池**，阶段末清空，唯满星者传承（ADR-0003）。
- 紧张感只走**精神力 + 年末事件**这一条管道。别再开第二条失败线。
- **致死事件只在低精神档**。这条由 `ContentDefinitionValidator` 在加载期强制。
- cascade 是最高优先级的视听事件 —— 见 fun-axes P1/P2。
- 暮年阶段（72+）endless 直到寿命耗尽。

## Architecture principles

- **Services are `RefCounted` with no scene dependencies.** Data in, data out. Instantiate with `ClassName.new()` from the caller.
- **Value objects are immutable.** Construct once; if a field needs to change, build a new object.
- **Content lives in `.tres`, never in code.** 所有内容走 `ContentRegistry.load_all()`。
  没有任何 id 该硬编码在它所属的 `.tres` 之外。
- **所有放大集中在 `CascadeContext`。** 星级 / 年度规则 / 六维 / 道具四路修正全部折进
  `add_self` / `link` / `neighbors` 三个出口，所以写新 effect 时不必知道它们存在，
  查「今年为什么炸这么大」也只有一个地方要看。
- **`YearModifiers` 是四路修正的唯一汇合点**，各路一律**加法叠加**、不连乘——
  连乘会让来源之间指数耦合，平衡表就没法维护了。
- **The smoke test gates every commit.** `test_smoke_yearly_loop_runs_to_death` 证明
  出生 → 逐年循环 → 收场是通的。红了立刻停。
- **GUT treats GDScript warnings as test errors.** 触发 `integer_division` / `unused_variable` /
  `shadowed_variable` 时，要么修根因，要么 `@warning_ignore("…")`，别留着。
- **GDScript lambda 按值捕获局部变量。** 要在闭包里改外层状态，用数组/字典当可变容器
  （`run_screen.gd::_first_of` 有一条血的教训）。

## Layout

```
autoload/         ContentRegistry, RunSession, SaveService (class_name only);
                  Localization 是本项目唯一的业务 autoload。
                  （project.godot 里还有 _mcp_game_helper，是 godot_ai 插件的开发工具
                    钩子，非游戏逻辑 —— 不要往它上面挂东西。）
scripts/core/     services/ (纯逻辑) + value_objects/ (不可变载体) + effects/ (ScriptableEffect)
scripts/content/  Resource 类定义（只有数据 schema，没有逻辑）
scripts/ui/       run_screen.gd (年循环编排器) + 各面板 + zodiac_ring
scripts/dev/      generate_content.gd + content_tables.gd —— **一次性铺量工具，已用完**
content/          .tres 游戏数据（tokens / items / events / flavor / zodiac / buffs / …）
scenes/           app/, menu/, run/, endless/, meta/
tests/            unit/core/ (一服务一文件) + integration/test_run_screen_flow.gd
docs/             PRD + fun-axes + growth-loop-design + adr/
```

`RunScreen` 是 orchestrator：所有规则都在 services 里，它只负责按顺序调用与呈现。
`step_year()`（同步全自动，测试与 autoplay 走）和 `_advance_year_interactive()`（协程，玩家走）
**共用同一批 `_year_*` 私有方法** —— 别让两条路径分叉。

## 内容怎么改

`content/` 下的 `.tres` 是**唯一事实源**。`scripts/dev/generate_content.gd` 只是第一次铺量用的，
**改数值请直接改 `.tres`，不要回去改生成器再重跑**（重跑会覆盖手改）。

新增碎片时至少要填：`stage_id`（可抽碎片必填）、`domain`、`base_score`、`effects`、
`zodiac_affinity`；想让它可传承再填 `legacy_into`。跨资源引用的完整性由
`tests/unit/core/test_content_registry.gd` 兜底。

## Tech

| Tool | Version |
|------|---------|
| Godot | 4.7.1-stable |
| GUT | 9.6.0 |
| Godot State Charts | 0.22.3（当前未使用）|

## Testing

```bash
scripts/dev/run-tests.sh unit          # all unit tests
scripts/dev/run-tests.sh integration   # all integration tests
scripts/dev/run-tests.sh smoke         # test_run_screen_flow.gd (includes the smoke test)
scripts/dev/run-tests.sh one res://tests/unit/core/test_xxx.gd
scripts/dev/run-tests.sh shot res://scenes/run/run_screen.tscn   # screenshot (needs a display)
```

截图脚本支持 `--steps=N`，先跑 N 年再截 —— 出生态盘面几乎全是「凡庸」，
看成长曲线至少要 `--steps=30`。

`GODOT_BIN` must point at Godot 4.7.x（默认 `~/.local/bin/godot`；macOS 用
`/Applications/Godot.app/Contents/MacOS/Godot`）。截图需要真实 display，别加 `--headless`。

**新增 `class_name` 后首次运行**：全局类缓存可能还没收录它，会报
`Could not find type "X"`。跑一次 `godot --headless --path . --editor --quit` 重建缓存即可。

## Active 服务

| 服务 | 职责 |
|---|---|
| `RingBoardService` | 12 槽位 ring 数据 API + 洗牌投盘 |
| `SettlementService` | cascade 主循环（进盘 → min-score-first → 收尾） |
| `DraftService` | 三选一投注池（阶段分池 + 已持有/领域双重加权） |
| `MergeService` | 三张→二星、两个二星→满星，自动触发 |
| `DeckService` | 命盘/行囊增删换 + 阶段清空 + 传承链升格 |
| `EconomyService` | 阶段门槛（兼计价基准）+ 购买力 |
| `ShopService` | 道具上架与购买 |
| `YearModifierService` | 四路修正 → `YearModifiers` |
| `SpiritService` | 精神力读写与三档分级（住在六维里） |
| `EventDraftService` | 转折年触发密度 + 事件/金句加权抽取 + 明牌概率 |
| `EventResolverService` | 选项后果结算 |
| `AttributeService` | 六维出生分配 + 年龄漂移 |
| `BuffService` | 开局 Buff 抽取 + 出生时一次性施加 |
| `ZodiacService` / `LifeStageService` / `AgeService` / `DeathService` | 查询与判定 |

**待接线**（文件在，主流程没调）：`RelationshipService`、`KarmaService`、
`EndlessService` + `content/anomalies/`、`RunModifierService`、`content/heroes|difficulty|meta/`。
它们分别对应关系系统、转世闭环、暮年 endless —— 都还没做。

## Commit discipline

- **Small commits, one logical change each.** If the message wants to say "and …", split it.
- **Run the relevant tests before committing.** Red doesn't ship.
- Conventional types: `feat / fix / refactor / docs / test / chore / perf / ci`. Never `update / wip / misc`.
- Never `--no-verify`, never amend pushed commits, never force-push to main.
- Chinese comments are conventional here — don't translate them to English.
