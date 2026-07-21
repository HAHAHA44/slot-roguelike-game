# Reelbound

Godot 4.7.1 prototype for a life-sim roguelike: a 12-slot zodiac ring, cascade settlement, and year-end events. See `CLAUDE.md` for the full agent reference.

Currently at **M0** — the yearly loop is wired end to end but cascade and events are still stubs. Milestones are tracked in `docs/2026-05-18-life-sim-dev-plan.md`.

## Requirements

- Godot `4.7.1-stable`
- GUT `9.6.0` (vendored in `addons/gut/`)
- Godot State Charts `0.22.3` (vendored in `addons/godot_state_charts/`)

## Project Layout

- `autoload/` — core session-scoped classes (`ContentRegistry`, `RunSession`, `SaveService`) and the `Localization` autoload.
- `scripts/` — services, value objects, UI controllers.
- `scenes/` — `app/`, `menu/`, `run/`.
- `content/` — `.tres` data resources (zodiac, life stages, tokens, events, items, …).
- `tests/` — GUT unit + integration tests.
- `docs/` — PRD and engineering notes.

## Run Tests (macOS / Linux / WSL)

```bash
scripts/dev/run-tests.sh unit          # all unit tests
scripts/dev/run-tests.sh integration   # all integration tests
scripts/dev/run-tests.sh smoke         # run_screen yearly-loop flow
scripts/dev/run-tests.sh one res://tests/unit/core/test_xxx.gd
scripts/dev/run-tests.sh shot res://scenes/run/run_screen.tscn  # screenshot
```

The script expects `GODOT_BIN` to point at a Godot 4.7.x binary (default `~/.local/bin/godot`). On macOS that is `/Applications/Godot.app/Contents/MacOS/Godot`. Screenshots need a real display (WSLg on WSL, the desktop session on macOS/Linux), so do not add `--headless` when taking them.

## Run Tests (Windows / PowerShell)

```powershell
$env:GODOT_BIN = "C:\path\to\Godot_v4.7.1-stable_win64.exe"
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -ginclude_subdirs -gexit
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

## Smoke Path

Every change must keep `test_smoke_yearly_loop_alive` green. It verifies the yearly loop:

1. The game boots into `RunScreen`, which builds the registry, session, and services.
2. Birth sets the zodiac and lifespan.
3. Each year: the 12-slot ring is populated, cascade settles, the year-end event resolves, and age advances.
4. The run ends at natural death once age reaches lifespan.

Steps 3's cascade and event are stubs until M1/M2 land — the test asserts the loop shape, not the payoff.
