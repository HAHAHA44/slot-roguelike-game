# Reelbound — Agent Reference

**Engine:** Godot 4.6.1-stable / GDScript  
**Stage:** Playable Prototype (not yet MVP)

## What it is

A 5×5 slot roguelike deckbuilder. The **bag-roll loop**:

1. `RunSession.token_pool` is padded to 25 with `empty_token`, shuffled, and laid across the whole board.
2. Settlement auto-runs phase by phase; score accumulates.
3. Player picks one of three add-token offers.
4. Optional random event fires (copy / delete pool token, or pick up an item).
5. Repeat. Periodic score thresholds fail the run.

Manual placement exists only as a debug shortcut. References: 幸运房东, Balatro, Loop Hero.

## Hard constraints (never change)

- 5×5 board, 25 cells. No resizing the base game.
- Score pressure comes from **periodic settlement**, never real-time HP.
- Every round must offer add / remove / random token paths to the player.
- Endless mode is the reward for clearing standard runs.

## Architecture principles

- **Services are `RefCounted` with no scene dependencies.** Data in, data out. Instantiate with `ClassName.new()` from the caller.
- **Value objects are immutable.** Construct once; if a field needs to change, build a new object.
- **Content lives in `.tres`, never in code.** Tokens / events / items / heroes / anomalies / difficulty / meta all flow through `ContentRegistry.load_all()`. No id should be hard-coded outside the `.tres` it names.
- **The smoke test gates every commit.** `test_smoke_playable_path_still_works` proves the offer → event → roll → settle → result → offer loop is intact. If it goes red, stop and fix before doing anything else.
- **GUT treats GDScript warnings as test errors.** If a clean refactor triggers `integer_division`, `unused_variable`, `shadowed_variable`, etc., either fix the root cause or annotate with `@warning_ignore("…")` — don't leave warnings live.

## Layout

```
autoload/         ContentRegistry, RunSession, SaveService (class_name only);
                  Localization is the only real Godot autoload.
scripts/core/     services/ (pure logic) + value_objects/ (immutable carriers)
scripts/content/  Resource class definitions (data schemas only, no logic)
scripts/ui/       run_screen.gd (main orchestrator), main_menu.gd
content/          .tres game data (tokens, events, items, heroes, difficulty, anomalies, meta)
scenes/           app/, menu/, run/, endless/, meta/
tests/            unit/core/ (one file per service) + integration/test_run_screen_flow.gd
docs/             PRD + engineering notes — content-schema.md is the authoritative resource reference
```

`RunScreen._ready()` is the entry point: it `new()`s the registry / session / services, wires the state chart, and owns the per-run lifetime. Treat it as the orchestrator; push logic *out* of it into services rather than adding more responsibility.

## Tech

| Tool | Version |
|------|---------|
| Godot | 4.6.1-stable |
| GUT | 9.6.0 |
| Godot State Charts | 0.22.3 |

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
- Never `--no-verify`, never amend pushed commits, never force-push to main.
- Chinese comments are conventional here — don't translate them to English.

## Skeleton code (exists, no production caller)

These have working implementations but nothing in the live loop reaches them yet. They are the project's roadmap — don't delete without an explicit decision, and don't assume they work without testing first:

- `EndlessService` + `content/anomalies/` + `scenes/endless/`
- `TriggerScanner`
- `MetaProgressionService` + `scenes/meta/`
- `RunModifierService` (hero / difficulty effects not yet merged into settlement)
- `EventDefinition` `.tres` files (`EventDraftService` is procedural, ignores them)
- `run_failed` / `run_cleared` states (referenced but not driven by the main flow)

For resource field specs see `docs/engineering/content-schema.md`. For the product vision and design pillars see `docs/2026-03-24-slot-roguelike-prd.md`.
