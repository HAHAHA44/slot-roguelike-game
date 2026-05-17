# Reelbound — Agent Reference

**Codename:** Project Reelbound  
**Engine:** Godot 4.6.1-stable  
**Language:** GDScript  
**Stage:** Playable Prototype / Early Vertical Slice (not yet MVP)

---

## What This Game Is

A 5×5 slot roguelike deckbuilder. Each run consists of rounds where:

1. The player's persistent **token pool** is expanded to 25 entries by injecting `empty_token` copies.
2. The 25 entries are shuffled and laid across the whole board.
3. Settlement runs automatically (triggers fire, score accumulates).
4. The player sees a result screen, then picks a reward (add/remove/swap a token in their pool).
5. Optionally an event fires, modifying the run state.
6. Repeat. Every N turns a score threshold check runs — fail it and the run ends.

Manual token placement is **not** the default loop. It exists only as a debug/future-ability path.

Reference games: 幸运房东, Balatro, Loop Hero.

---

## Hard Constraints (never change these)

- Board is always **5×5** (25 cells).
- Token interactions: adjacency, row/column, conditional triggers.
- Score pressure comes from **periodic settlement** every N rounds, not real-time HP.
- Every round the player must have access to: add token / remove token / random token.
- After clearing standard runs, **Endless mode** must be available.

---

## Tech Stack

| Tool | Version | Purpose |
|------|---------|---------|
| Godot | 4.6.1-stable | Engine |
| GUT | 9.6.0 | Unit + integration tests |
| Godot State Charts | 0.22.3 | UI state machine in RunScreen |

---

## Directory Map

```
autoload/
  content_registry.gd          # ContentRegistry: load_all() scans content/, indexes by id
  run_session.gd               # RunSession: persistent per-run state (token_pool, score, turn, modifiers)
  save_service.gd              # SaveService: RunSession ⇄ Dictionary, disk I/O
  localization_service.gd      # Localization (the only true Godot autoload — see project.godot)

scripts/
  app/
    app_root.gd                # Empty Control root for the application scene
  content/                     # Resource class definitions (data schemas)
    token_definition.gd
    event_definition.gd
    hero_definition.gd
    difficulty_modifier.gd
    anomaly_definition.gd
    meta_unlock_definition.gd
    item_definition.gd
    content_definition_validator.gd

  core/
    services/                  # Pure business logic, no scene deps
      board_roll_service.gd          # Builds round pool from token_pool + empties, shuffles
      board_service.gd               # Manages board state (BoardPos → TokenInstance)
      trigger_scanner.gd             # Tag/row/column scan helpers (skeleton — not yet wired)
      settlement_resolver.gd         # Runs phases, accumulates score, emits SettlementReport
      reward_offer_service.gd        # Generates 3 add-only token offers per round
      event_draft_service.gd         # Random copy/delete/item events (no weighted draft)
      contract_service.gd            # Tracks multi-round contract state & resolution
      endless_service.gd             # Score scaling for Endless mode (skeleton — not yet wired)
      run_modifier_service.gd        # Applies hero & difficulty modifiers (skeleton)

    value_objects/             # Immutable data carriers
      board_pos.gd
      token_instance.gd
      run_snapshot.gd
      settlement_step.gd
      settlement_report.gd

  meta/
    meta_progression_service.gd  # Unlocks, meta currency, cross-run state (skeleton)

  localization/
    l10n.gd                    # L10n: static text/format helpers backed by TranslationServer

  ui/
    run_screen.gd              # Main orchestrator: state charts + services + board
    main_menu.gd               # Start / settings / quit

content/                       # .tres resource files (game data)
  tokens/                      # 16 tokens (4 elements × 4 rarities) + empty_token
  events/                      # 12 events
  items/                       # 6 items (passive boosts + instant effects)
  heroes/                      # 3 heroes
  difficulty/                  # 3 difficulty modifiers
  anomalies/                   # 3 anomalies
  meta/                        # 3 meta unlocks

scenes/
  app/app_root.tscn            # Top-level shell
  menu/main_menu.tscn          # Title screen (entry point)
  run/
    run_screen.tscn            # Main playable scene (Godot State Charts root)
    board_grid.tscn            # 5×5 grid UI
    token_cell.tscn
    turn_controls.tscn         # Next-turn arrow + debug controls
    event_draft_panel.tscn
    settlement_log_panel.tscn
  endless/endless_summary_panel.tscn  # Not yet referenced by any flow
  meta/meta_screen.tscn               # Not yet referenced by any flow

locale/
  messages.csv                 # Translation table consumed by TranslationServer

tests/
  unit/core/                   # GUT unit tests per service
  integration/
    test_run_screen_flow.gd    # Smoke test: full bag-roll round trip
    test_meta_save_load.gd

docs/
  2026-03-24-slot-roguelike-prd.md   # Full PRD (Chinese)
  engineering/
    content-schema.md          # Resource field specs and registry rules
    balance-checklist.md
    plugin-decisions.md
```

---

## Core Architecture

### Long-lived singletons

The only true Godot autoload is `Localization` (registered in `project.godot`); it loads `locale/messages.csv` into `TranslationServer`. The other "session" objects are `class_name` types that `RunScreen._ready()` instantiates and owns:

- **`ContentRegistry`** — `tokens / events / items / heroes / difficulty_modifiers / meta_unlocks / anomalies` dictionaries indexed by `id`. `RunScreen` calls `load_all()` once at startup; it walks each `content/<kind>/` directory and validates every `.tres` via `ContentDefinitionValidator`.
- **`RunSession`** — single source of truth for an in-progress run. Key fields: `token_pool: Array[String]` (persistent multiset, duplicates meaningful), `current_turn`, `current_score`, `phase_index`, `phase_target`, `active_modifiers`. Pool mutation API: `pool_add(id)`, `pool_remove(id)`, `pool_count(id)`.
- **`SaveService`** — `RunSession.to_dict()` / `from_dict()` plus disk I/O. Not yet wired to a main-menu load button.
- **`L10n`** — static utility helpers (`L10n.text(key, fallback)`, `format_text`, `rarity_name`, `state_name`, `mode_name`, …) that call `TranslationServer.translate` under the hood. Used wherever UI strings need the locale layer.

### Service Layer (pure GDScript, `RefCounted`)

Services have **no scene dependencies**. They take data in, return data out. Instantiate with `ClassName.new()`.

| Service | Input | Output | Status |
|---------|-------|--------|--------|
| `BoardRollService` | `token_pool`, `board_capacity`, `empty_token_id`, `rng` | flat `Array` of token ids | live |
| `BoardService` | width, height | place/remove/query API | live |
| `SettlementResolver` | `BoardService`, `ContentRegistry`, active items | `SettlementReport` | live |
| `RewardOfferService` | `RunSession`, `ContentRegistry` | three add-only offers | live |
| `EventDraftService` | `RunSession`, `ContentRegistry`, seed | one random copy/delete/item event | live |
| `ContractService` | `RunSession` | contract status | live |
| `TriggerScanner` | board snapshot | tag/row/column counts | skeleton, no caller |
| `EndlessService` | loop index, anomaly | scaled target, expanded context | skeleton, no caller |
| `RunModifierService` | `RunSession`, hero/difficulty | aggregated modifiers | skeleton |
| `MetaProgressionService` | meta state, unlocks | persistent progression | skeleton |

### Value Objects (immutable data carriers)

Never mutate these after construction. Create new ones.

- `BoardPos` — `(col: int, row: int)`
- `TokenInstance` — `(definition: TokenDefinition, pos: BoardPos, state: Dictionary)`
- `RunSnapshot` — board map + session reference, input to settlement
- `SettlementStep` — one trigger event (token id, pos, delta)
- `SettlementReport` — full settlement result (steps array, total score delta)

---

## Default Game Loop (bag-roll)

```
[offer_choice state]
  → player picks one of three add_token offers → RunSession.pool_add(token_id)

[event_draft state]
  → EventDraftService.build_event(session, seed) → no_event / copy_token / delete_token / item
  → apply_event mutates pool or installs a passive/instant item

[roll_board state]
  → BoardRollService.build_round_pool(token_pool, 25, "empty_token", rng)
  → BoardService receives row-major map → auto-transition to settling

[settling state]
  → SettlementResolver.resolve_board(board, registry, active_items)
  → SettlementReport accumulated and animated step-by-step

[settlement_result state]
  → player reads the log, clicks continue

→ loops back to [offer_choice]
```

The **next-turn arrow** in `TurnControls` drives the `roll_board` transition.
Settlement phases (in order): `base_output → item_bonus → adjacency → row_column → conditional → copy_amplify → cleanup`. `adjacency / conditional / copy_amplify` are reserved phase slots — no token rules emit into them yet.

---

## Content Schema (key rules)

### TokenDefinition fields
`id`, `name`, `rarity`, `type`, `tags`, `base_value`, `trigger_rules`, `state_fields`, `spawn_rules`, `remove_rules`, `description`

Rarity values: `Common`, `Uncommon`, `Rare`, `Legendary`

### `empty_token`
- `id = "empty_token"`, `base_value = 0`, no tags, `spawn_rules = {"weight": 0.0}`
- Auto-injected to pad pool to 25. Never appears in reward offers.
- Participates in settlement but contributes 0 score.

### Token roster (4 elements × 4 rarities)

`fire / water / earth / wind` × `common / uncommon / rare / legendary` → 16 token files in `content/tokens/`, plus `empty_token`. Element rules implemented in `SettlementResolver`:

- **fire** — triangular bonus from fire tokens stacked *above* in the same column.
- **water** — triangular bonus from water tokens stacked *below* in the same column.
- **earth** — +1 per other earth token in the same row.
- **wind** — +1 per other wind token in the same column.

### Registry rules
- `ContentRegistry.load_all()` walks `content/<kind>/*.tres` for each kind (tokens / events / items / heroes / difficulty / meta / anomalies) and indexes by `id`.
- `id` must be globally unique within its kind.
- `spawn_rules.weight == 0` tokens are excluded from reward offers; `RewardOfferService` weights remaining tokens `Common 4 / Uncommon 3 / Rare 2 / Legendary 1`.

### ItemDefinition (active items)
`id`, `name`, `description`, `effect_type` (`passive` / `instant`), `effect_data` (Dictionary).
- `passive` items grant `item_bonus` phase points based on `effect_data.element`.
- `instant` items run `effect_data.action` once via `EventDraftService._apply_instant_item` (e.g. `upgrade_random`, `delete_random`).

### EventDefinition fields
`id`, `name`, `type` (`instant`/`lasting`/`crisis`), `tags_affected`, `duration`, `contract_template`, `reward_bundle`, `penalty_bundle` — defined but **not yet used** by the current `EventDraftService`, which generates events procedurally rather than drafting from the `.tres` pool.

---

## Testing

> **WSL / Linux 主路径**：用 `scripts/dev/run-tests.sh` 封装。
> **Windows 端**：保留下方 PowerShell 命令做对照。

### WSL / Linux（推荐，Claude 在用）

前置：`~/.local/bin/godot` 是 Linux 版 4.6.1，`$GODOT_BIN` 已在 `~/.bashrc` 配好。

```bash
scripts/dev/run-tests.sh unit          # 所有 unit
scripts/dev/run-tests.sh integration   # 所有 integration
scripts/dev/run-tests.sh smoke         # 仅 smoke test（每次提交前必跑）
scripts/dev/run-tests.sh one res://tests/unit/core/test_xxx.gd
scripts/dev/run-tests.sh shot res://scenes/run/run_screen.tscn  # 截图到 screenshots/
```

截图依赖 WSLg 提供的 display（WSL2 + Win11 默认开启），**不能** 加 `--headless`。

### Windows / PowerShell（手动跑 Godot 编辑器时备用）

```powershell
$env:GODOT_BIN="C:\Users\27391\Desktop\Godot_v4.6.1-stable_win64.exe"
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -ginclude_subdirs -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

**The smoke test verifies:**
- Game boots into `RunScreen` → `offer_choice` state
- A reward offer and event are selected
- The next-turn arrow rolls the board (25 tokens from pool)
- Settlement resolves automatically
- UI reaches `settlement_result`, then continues to `reward_choice`

Every task must keep this smoke path green before commit.

---

## GDScript Conventions

- **Services** extend `RefCounted`, not `Node`. No scene dependencies.
- **Value objects** are immutable — construct once, never mutate fields.
- **File-level comments** (first lines of each `.gd`) describe: what the class does, its invariants, and which other classes it typically interacts with.
- Class names use `PascalCase`, files use `snake_case`.
- Chinese comments are conventional in this codebase — do not convert them to English.
- Tests use GUT's `extends GutTest`. Prefix test methods with `test_`.
- Use `assert_eq`, `assert_true`, etc. from GUT — not `assert()`.
- TDD workflow: write the test first (RED), then implement (GREEN), then refactor.

---

## Commit Discipline（小步提交）

**每完成一个"能用一句话讲清楚"的改动就立刻 commit**，不要把多个无关改动堆到一次提交，也不要让未提交的改动跨过下一次对话回合。

判断"该提交了"的信号：
- 一个 service 实现 + 它的 GUT 测试都绿了 → 提交
- 加一个工具脚本/截图脚本 → 提交
- 一次 bugfix 修完 → 提交（不要顺手改无关 typo）
- 一段文档/CLAUDE.md 更新 → 提交

硬性要求：
- **提交前必须本地跑过相关测试**（service 改动跑 `scripts/dev/run-tests.sh unit`，流程改动跑 `smoke`），红的不提。
- Commit message 用 `<type>: <一句话描述>` 格式（`feat` / `fix` / `refactor` / `docs` / `test` / `chore` / `perf` / `ci`）。**禁止** `update` / `wip` / `misc` 这种空话。
- 一次 commit 只做一件事。如果 message 里出现 "and" 或 "顺便"，应该拆成两次提交。
- 永远不要 `--no-verify`、`--amend` 已经 push 的提交、或 `push --force` 到 main。

Claude 在执行任务时遵守此规则：每完成一个有意义节点就主动 commit，不需要每次再问。

---

## What Is NOT Yet Implemented (as of 2026-05-17)

Wired up:
- Main menu → run screen → bag-roll → settlement → reward loop.
- Item system (passive + instant) flowing through the event draft.
- Localization through `Localization` autoload + `L10n` static helpers.

Skeleton or unwired:
- `EndlessService` and `content/anomalies/` — code exists, no caller.
- `TriggerScanner` — class exists, settlement doesn't use it.
- `MetaProgressionService` and `scenes/meta/meta_screen.tscn` — class + scene exist, no caller.
- `RunModifierService` — exists, but hero / difficulty effects aren't merged into settlement yet.
- `scenes/endless/endless_summary_panel.tscn` — exists, never instantiated.
- Score-threshold run-end flow — `run_failed` / `run_cleared` referenced in `RunScreen` but not driven by the main loop.
- `EventDefinition` `.tres` files — exist as data, but `EventDraftService` is procedural; the data is unused.
- Save/load from main menu, sound, music, visual polish.

---

## Key Docs to Read Next

| Doc | When |
|-----|------|
| `docs/2026-03-24-slot-roguelike-prd.md` | Full product spec (note: token count predates current roster) |
| `docs/engineering/content-schema.md` | Resource field reference |
