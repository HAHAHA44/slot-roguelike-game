# Reelbound

Godot 4.6.1 prototype for a 5×5 slot roguelike. See `CLAUDE.md` for the full agent reference.

## Requirements

- Godot `4.6.1-stable`
- GUT `9.6.0` (vendored in `addons/gut/`)
- Godot State Charts `0.22.3` (vendored in `addons/godot_state_charts/`)

## Project Layout

- `autoload/` — core session-scoped classes (`ContentRegistry`, `RunSession`, `SaveService`) and the `Localization` autoload.
- `scripts/` — services, value objects, UI controllers.
- `scenes/` — `app/`, `menu/`, `run/`, `endless/`, `meta/`.
- `content/` — `.tres` data resources (tokens, events, items, heroes, …).
- `tests/` — GUT unit + integration tests.
- `docs/` — PRD and engineering notes.

## Run Tests (WSL / Linux, recommended)

```bash
scripts/dev/run-tests.sh unit          # all unit tests
scripts/dev/run-tests.sh integration   # all integration tests
scripts/dev/run-tests.sh smoke         # run_screen flow + bag-roll smoke
scripts/dev/run-tests.sh one res://tests/unit/core/test_xxx.gd
scripts/dev/run-tests.sh shot res://scenes/run/run_screen.tscn  # screenshot
```

The script expects `GODOT_BIN` to point at the Linux Godot 4.6.x binary (default `~/.local/bin/godot`). Screenshots rely on WSLg, so do not add `--headless` when taking them.

## Run Tests (Windows / PowerShell)

```powershell
$env:GODOT_BIN = "C:\path\to\Godot_v4.6.1-stable_win64.exe"
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -ginclude_subdirs -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

## Smoke Path

Every change must keep `test_smoke_playable_path_still_works` green. It verifies:

1. The game boots into `RunScreen` → `offer_choice`.
2. A reward offer and an event are selected.
3. The next-turn arrow rolls the board (25 tokens including injected `empty_token` padding).
4. Settlement resolves automatically through every phase.
5. The UI reaches `settlement_result`, then loops back to `offer_choice`.
