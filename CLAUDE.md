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
  content_registry.gd   # Scans content/ and indexes resources by id
  run_session.gd         # Persistent per-run state (token_pool, score, turn, modifiers)
  save_service.gd        # Serialise/deserialise RunSession to disk

scripts/
  content/               # Resource class definitions (data schemas)
    token_definition.gd
    event_definition.gd
    hero_definition.gd
    difficulty_modifier.gd
    anomaly_definition.gd
    meta_unlock_definition.gd
    content_definition_validator.gd

  core/
    services/            # Pure business logic, no scene deps
      board_roll_service.gd      # Builds round pool from token_pool + empties, shuffles
      board_service.gd           # Manages board state (BoardPos → TokenInstance)
      trigger_scanner.gd         # Evaluates token trigger rules against the board
      settlement_resolver.gd     # Runs triggers, accumulates score, emits SettlementReport
      reward_offer_service.gd    # Generates reward offers from ContentRegistry + RunSession
      event_draft_service.gd     # Drafts event choices weighted by tags/hero
      contract_service.gd        # Tracks multi-round contract state & resolution
      endless_service.gd         # Manages score scaling in Endless mode
      run_modifier_service.gd    # Applies hero & difficulty modifiers to run state

    value_objects/        # Immutable data carriers
      board_pos.gd        # (col, row) wrapper
      token_instance.gd   # Runtime token state on the board
      run_snapshot.gd     # Snapshot of board + session for settlement
      settlement_step.gd  # One trigger firing within a settlement
      settlement_report.gd# Full result of one settlement pass

  meta/
    meta_progression_service.gd  # Unlocks, meta currency, cross-run state

  ui/
    run_screen.gd         # Main orchestrator: reads state charts, calls services, updates board

content/                  # .tres resource files (game data)
  tokens/                 # 7 tokens: anchor_glyph, empty_token, hollow_shell,
                          #           pulse_seed, relay_prism, twin_monolith, wild_signal
  events/                 # 12 events
  heroes/                 # 3 heroes
  difficulty/             # 3 difficulty modifiers
  anomalies/              # 3 anomalies
  meta/                   # 3 meta unlocks

scenes/
  run/
    run_screen.tscn       # Main playable scene (Godot State Charts root)
    board_grid.tscn       # 5×5 grid UI
    token_cell.tscn       # Individual cell
    turn_controls.tscn    # Next-turn arrow + debug controls
    event_draft_panel.tscn
    settlement_log_panel.tscn

tests/
  unit/core/              # GUT unit tests for each service
  integration/
    test_run_screen_flow.gd   # Smoke test: full bag-roll round trip
    test_meta_save_load.gd

docs/
  2026-03-24-slot-roguelike-prd.md      # Full PRD (Chinese)
  engineering/
    content-schema.md    # Resource field specs and registry rules
    balance-checklist.md
    plugin-decisions.md
  superpowers/
    plans/               # Implementation plans (task-by-task checklists)
    specs/               # Design specs
  status/
    2026-03-24-stage-report.md  # Current milestone assessment
```

---

## Core Architecture

### Autoloads (singletons, always available)

- **`ContentRegistry`** — call `ContentRegistry.get_token(id)` to get a `TokenDefinition`. Populated at startup by scanning `res://content/`.
- **`RunSession`** — the single source of truth for a run in progress. Passed by reference to services. Key fields:
  - `token_pool: Array[String]` — the persistent multiset (duplicates are meaningful).
  - `current_turn`, `current_score`, `phase_index`, `phase_target`.
  - `active_modifiers: Array` — hero + difficulty modifier refs.
  - Pool mutation API: `pool_add(id)`, `pool_remove(id)`, `pool_count(id)`.
- **`SaveService`** — wraps `RunSession.to_dict()` / `from_dict()` for disk I/O.

### Service Layer (pure GDScript, `RefCounted`)

Services have **no scene dependencies**. They take data in, return data out. Instantiate with `ClassName.new()`.

| Service | Input | Output |
|---------|-------|--------|
| `BoardRollService` | `token_pool`, `board_capacity`, `empty_token_id`, `rng` | flat `Array` of token ids |
| `BoardService` | board map dict | board state queries |
| `TriggerScanner` | `RunSnapshot` | `Array[SettlementStep]` |
| `SettlementResolver` | `RunSnapshot` | `SettlementReport` |
| `RewardOfferService` | `RunSession`, `ContentRegistry` | offer options |
| `EventDraftService` | `RunSession`, `ContentRegistry` | event choices |
| `ContractService` | `RunSession` | contract status |

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
[reward_choice state]
  → player selects reward → pool_add / pool_remove mutates RunSession.token_pool

[event_draft state]  (optional)
  → player selects event option → modifier applied to RunSession

[roll_board state]
  → BoardRollService.build_round_pool(token_pool, 25, "empty_token", rng)
  → BoardService.set_board(pool_to_board_map(round_pool, 5))
  → auto-trigger SettlementResolver

[settling state]
  → SettlementReport accumulated

[settlement_result state]
  → player views log, clicks continue

→ loops back to [reward_choice]
```

The **next-turn arrow** in `TurnControls` drives the `roll_board` transition.

---

## Content Schema (key rules)

### TokenDefinition fields
`id`, `name`, `rarity`, `type`, `tags`, `base_value`, `trigger_rules`, `state_fields`, `spawn_rules`, `remove_rules`, `description`

Rarity values: `Common`, `Uncommon`, `Rare`, `Legendary`

### `empty_token`
- `id = "empty_token"`, `base_value = 0`, no tags, `spawn_rules = {"weight": 0.0}`
- Auto-injected to pad pool to 25. Never appears in reward offers.
- Participates in settlement but contributes 0 score.

### Registry rules
- `ContentRegistry` scans `res://content/tokens/*.tres` on startup.
- `id` must be globally unique.
- `spawn_rules.weight == 0` tokens are excluded from player-facing offer pools.

### EventDefinition fields
`id`, `name`, `type` (`instant`/`lasting`/`crisis`), `tags_affected`, `duration`, `contract_template`, `reward_bundle`, `penalty_bundle`

---

## Testing

### Run unit tests
```powershell
$env:GODOT_BIN="C:\path\to\Godot_v4.6.1-stable_win64_console.exe"
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/core -ginclude_subdirs -gexit
```

### Run integration tests
```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -ginclude_subdirs -gexit
```

### Smoke test (must always pass)
```powershell
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

## What Is NOT Yet Implemented (as of 2026-03-25)

- Score threshold failure / run-end flow
- Endless mode progression
- Full hero passive system wired into settlement
- Full difficulty modifier UI
- Meta progression unlock screen
- Save/load from main menu
- Sound, music, visual polish

---

## Key Docs to Read Next

| Doc | When |
|-----|------|
| `docs/2026-03-24-slot-roguelike-prd.md` | Full product spec |
| `docs/engineering/content-schema.md` | Resource field reference |
| `docs/superpowers/plans/2026-03-25-bag-roll-core-loop-plan.md` | Current active implementation plan |
| `docs/superpowers/specs/2026-03-25-bag-roll-core-loop-design.md` | Design rationale for bag-roll |
| `docs/status/2026-03-24-stage-report.md` | What's done vs. what's missing |
