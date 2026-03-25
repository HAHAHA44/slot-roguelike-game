# Reelbound

Godot 4.6.1 prototype for a 5x5 slot roguelike.

## Requirements

- Godot `4.6.1-stable`
- GUT `9.6.0`
- Godot State Charts `0.22.3`

## Project Layout

- `addons/` third-party plugins vendored into the repo
- `tests/` GUT unit and integration tests
- `docs/engineering/` implementation notes and tooling decisions

## Run Tests

Unit tests:

```powershell
$env:GODOT_BIN="C:\path\to\Godot_v4.6.1-stable_win64_console.exe"
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/core -ginclude_subdirs -gexit
```

Integration tests:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -ginclude_subdirs -gexit
```

Playable smoke check:

```powershell
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_run_screen_flow.gd -gexit
```

During the current playable-vertical-slice phase, every task must keep the smoke path green:
- the game boots into `RunScreen`
- a token can be placed
- settlement can be triggered
- the UI advances to the next playable state
