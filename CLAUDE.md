# Reelbound — Agent Reference

**Engine:** Godot 4.6.1-stable / GDScript  
**Stage:** M0 — stub yearly loop（人生模拟重设计）

## What it is

12 格生肖盘 + cascade 结算 + 紧张感事件的人生模拟 roguelike。**年-循环**：

1. 出生 → `RunSession` 初始化 age / lifespan / zodiac_birth / sanity 等。
2. 每年：`ZodiacService` 给出当年生肖 → 12 格 `RingBoardService` 投盘 →
   `SettlementService` 跑 cascade（M1 实装）→ 年末事件（M2 实装）→ age++。
3. 死亡：恶性事件 lethal 或寿命到顶 → 累 karma → 转世（M6 实装）。

旧 5×5 bag-roll 路径已 M0 退役，文件保留作 M1+ cascade 实现的参考蓝本。
设计文档：`docs/2026-05-17-life-sim-prd.md` + `docs/2026-05-18-life-sim-fun-axes.md`
开发计划：`docs/2026-05-18-life-sim-dev-plan.md`（M0–M7 里程碑）。
参考：幸运房东（cascade）、Balatro（联动）、人生重开模拟器、60 Seconds。

## Hard constraints (never change)

- 12 格生肖盘，固定槽位（鼠–猪 order 0-11）。不改 ring 大小。
- 紧张感来自**精神力 + 年末事件**，不是实时血量。
- 每年结算后必须给玩家**有意义的奖励路径**（cascade 收益 → token / item / stat 之一）。
- cascade 是最高优先级的视听事件 —— 见 `2026-05-18-life-sim-fun-axes.md` P1/P2。
- 暮年阶段（72+）endless 直到寿命耗尽。

## Architecture principles

- **Services are `RefCounted` with no scene dependencies.** Data in, data out. Instantiate with `ClassName.new()` from the caller.
- **Value objects are immutable.** Construct once; if a field needs to change, build a new object.
- **Content lives in `.tres`, never in code.** Tokens / events / items / heroes / zodiacs / anomalies / difficulty / meta all flow through `ContentRegistry.load_all()`. No id should be hard-coded outside the `.tres` it names.
- **The smoke test gates every commit.** `test_smoke_yearly_loop_alive` 证明出生 → 12 格 stub 投盘 → stub cascade → stub event → age++ → 自然死的年循环是通的。红了立刻停。
- **GUT treats GDScript warnings as test errors.** If a clean refactor triggers `integer_division`, `unused_variable`, `shadowed_variable`, etc., either fix the root cause or annotate with `@warning_ignore("…")` — don't leave warnings live.

## Layout

```
autoload/         ContentRegistry, RunSession, SaveService (class_name only);
                  Localization is the only real Godot autoload.
scripts/core/     services/ (pure logic) + value_objects/ (immutable carriers)
scripts/content/  Resource class definitions (data schemas only, no logic)
scripts/ui/       run_screen.gd (yearly loop orchestrator), main_menu.gd
content/          .tres game data (tokens, events, items, heroes, zodiac, difficulty, anomalies, meta)
scenes/           app/, menu/, run/, endless/, meta/
tests/            unit/core/ (one file per service) + integration/test_run_screen_flow.gd
docs/             PRD + engineering notes — content-schema.md is the authoritative resource reference
```

`RunScreen._ready()` 是入口：new() registry / session / services，然后跑 `autoplay_until_death`。它是 orchestrator，所有逻辑要 push 进 services，不要往 RunScreen 加责任。

## Tech

| Tool | Version |
|------|---------|
| Godot | 4.6.1-stable |
| GUT | 9.6.0 |
| Godot State Charts | 0.22.3（M0 起未使用；M2 事件状态机可能恢复）|

## Testing

```bash
scripts/dev/run-tests.sh unit          # all unit tests
scripts/dev/run-tests.sh integration   # all integration tests
scripts/dev/run-tests.sh smoke         # test_run_screen_flow.gd (includes the smoke test)
scripts/dev/run-tests.sh one res://tests/unit/core/test_xxx.gd
scripts/dev/run-tests.sh shot res://scenes/run/run_screen.tscn   # screenshot via WSLg
```

`GODOT_BIN` must point at Linux Godot 4.6.x (default `~/.local/bin/godot`). Screenshots need WSLg, so don't add `--headless` when taking them. Windows PowerShell equivalents live in `README.md`.

## Commit discipline

- **Small commits, one logical change each.** If the message wants to say "and …", split it.
- **Run the relevant tests before committing.** Red doesn't ship.
- Conventional types: `feat / fix / refactor / docs / test / chore / perf / ci`. Never `update / wip / misc`.
- 里程碑提交带 scope，如 `feat(M0): ...`。
- Never `--no-verify`, never amend pushed commits, never force-push to main.
- Chinese comments are conventional here — don't translate them to English.

## Active 服务（M0 新流程）

- `ZodiacService` —— 12 生肖查询 / 当年生肖 / 本命年 / 奖励格
- `RingBoardService` —— 12 槽位 ring 数据 API（place / token_at / neighbors）
- `RunSession` —— age / lifespan / sanity / zodiac_birth / stage_idx / stats / karma_in_run
- `ContentRegistry` —— 内容入口（含 zodiacs）

## 退役但仍在文件树（M1+ cascade 实现时清理或替换）

5×5 bag-roll 时代的服务，scripts/core/services/ 里仍能编译但 RunScreen 不再调用：

- `BoardService` (5×5 Vector2i) / `BoardRollService`
- `SettlementResolver` —— M1 替换为新 SettlementService
- `RewardOfferService` —— M3 EventResolverService 取代
- `EventDraftService`（旧版，过程式）—— M2 重写为 sanity 加权 + 本命年池
- `TriggerScanner` —— 看 M1 cascade 是否需要
- `ContractService` —— 旧合约系统，待决
- `RunModifierService` —— M3 item modifier 拿来用
- `EndlessService` + `content/anomalies/` + `scenes/endless/` —— M5 暮年 endless 接入
- `MetaProgressionService` + `scenes/meta/` —— M6 转世闭环
- `run_failed` / `run_cleared` 状态 —— 当前不在主流程

For resource field specs see `docs/engineering/content-schema.md`（注：仍描述 5×5 时代字段，M1 起逐步重写）。
