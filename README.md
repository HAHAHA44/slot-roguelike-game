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

```powershell
$env:GODOT_BIN="C:\path\to\Godot_v4.6.1-stable_win64_console.exe"
& $env:GODOT_BIN --headless --path . -d -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
